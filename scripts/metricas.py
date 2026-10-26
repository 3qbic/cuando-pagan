#!/usr/bin/env python3
"""Consulta las métricas de uso de «¿Cuándo Pagan?» en Cloudflare Analytics Engine.

Uso:  python scripts/metricas.py [--dias 30]
Solo biblioteca estándar. Funciona en Mac y Windows.
"""
import argparse
import json
import os
import platform
import sys
import urllib.error
import urllib.request

DATASET = 'cuandopagan_uso'
API = 'https://api.cloudflare.com/client/v4/accounts/{acc}/analytics_engine/sql'
SO = platform.system()  # 'Darwin', 'Windows', 'Linux'

TITULOS = {
    'aperturas_dia': 'Aperturas por día (Días en hora de Panamá)',
    'por_version': 'Aperturas por versión de la app',
    'push_altas_bajas': 'Push: altas, bajas y re-altas',
    'envios': 'Envíos de push por tema',
}

MENSAJE_ENV = """Faltan variables de entorno: {faltan}

Para crear el token de solo lectura:
  1. Cloudflare dashboard -> My Profile -> API Tokens -> Create Token -> Create Custom Token.
  2. Permiso: Account | Account Analytics | Read.
  3. Copia el token (solo se muestra una vez) y el Account ID de tu cuenta.

Luego define las variables:
  Mac / Linux (zsh, bash):
    export CLOUDFLARE_ACCOUNT_ID="<tu account id>"
    export CF_METRICAS_TOKEN="<tu token>"
  Windows (PowerShell, solo esta sesión):
    $env:CLOUDFLARE_ACCOUNT_ID = "<tu account id>"
    $env:CF_METRICAS_TOKEN = "<tu token>"
  Windows (permanente; abre una terminal nueva después):
    setx CLOUDFLARE_ACCOUNT_ID "<tu account id>"
    setx CF_METRICAS_TOKEN "<tu token>"
"""


def consultas(dias: int) -> dict:
    """SQL de cada sección. Conteos siempre con SUM(_sample_interval)."""
    # OJO: el peso manual con _sample_interval es correcto para el endpoint
    # legado /analytics_engine/sql que se usa aquí. Si se migra a la API SQL
    # nueva (events.analyticsEngine.*), que ya aplica los pesos por sí misma,
    # hay que quitarlo o se cuenta doble.
    ventana = f"timestamp > NOW() - INTERVAL '{int(dias)}' DAY"
    # Panamá es UTC-5 fijo (sin horario de verano): se agrupa por día local en SQL.
    dia_pa = "toStartOfDay(timestamp - INTERVAL '5' HOUR)"
    return {
        'aperturas_dia': (
            f"SELECT {dia_pa} AS dia, "
            "SUM(_sample_interval) AS aperturas, "
            "sumIf(_sample_interval, blob4 = '1') AS con_push "
            f"FROM {DATASET} "
            f"WHERE index1 = 'apertura' AND {ventana} "
            f"GROUP BY {dia_pa} ORDER BY dia DESC FORMAT JSON"
        ),
        'por_version': (
            "SELECT blob3 AS version, blob2 AS plataforma, "
            "SUM(_sample_interval) AS aperturas "
            f"FROM {DATASET} "
            f"WHERE index1 = 'apertura' AND {ventana} "
            "GROUP BY blob3, blob2 ORDER BY aperturas DESC FORMAT JSON"
        ),
        'push_altas_bajas': (
            "SELECT blob1 AS evento, blob2 AS categoria, blob3 AS anticipacion, "
            "SUM(_sample_interval) AS total "
            f"FROM {DATASET} "
            f"WHERE index1 IN ('push_alta', 'push_baja', 'push_realta') AND {ventana} "
            "GROUP BY blob1, blob2, blob3 ORDER BY evento, total DESC FORMAT JSON"
        ),
        'envios': (
            "SELECT blob2 AS tema, "
            "SUM(_sample_interval * double1) AS enviados, "
            "SUM(_sample_interval * double2) AS errores "
            f"FROM {DATASET} "
            f"WHERE index1 = 'push_envio' AND {ventana} "
            "GROUP BY blob2 ORDER BY enviados DESC FORMAT JSON"
        ),
    }


def formatear_tabla(columnas: list, filas: list) -> str:
    if not filas:
        return '(sin datos)'
    celdas = [[_texto(f.get(c)) for c in columnas] for f in filas]
    anchos = [max(len(c), *(len(r[i]) for r in celdas)) for i, c in enumerate(columnas)]
    # numéricos a la derecha, texto a la izquierda
    num = [all(_es_num(f.get(c)) for f in filas) for c in columnas]

    def fila(vals):
        return '  '.join(v.rjust(w) if n else v.ljust(w)
                         for v, w, n in zip(vals, anchos, num)).rstrip()

    cab = '  '.join(c.rjust(w) if n else c.ljust(w)
                    for c, w, n in zip(columnas, anchos, num)).rstrip()
    sep = '  '.join('-' * w for w in anchos)
    return '\n'.join([cab, sep] + [fila(r) for r in celdas])


def _es_num(v):
    if isinstance(v, (int, float)) and not isinstance(v, bool):
        return True
    try:
        float(v)
        return v is not None and str(v).strip() != ''
    except (TypeError, ValueError):
        return False


def _texto(v):
    if v is None:
        return ''
    if isinstance(v, float) and v.is_integer():
        return str(int(v))
    s = str(v)
    # AE devuelve números como cadenas ("3") o fechas "2026-10-26 00:00:00"
    if s.endswith(' 00:00:00'):
        s = s[:-9]
    return s


def build_parser():
    p = argparse.ArgumentParser(
        prog='metricas.py',
        description='Métricas de uso de ¿Cuándo Pagan? (Cloudflare Analytics Engine).')

    def dias(v):
        n = int(v)
        if not 1 <= n <= 90:
            raise argparse.ArgumentTypeError('debe estar entre 1 y 90 (AE guarda ~3 meses)')
        return n

    p.add_argument('--dias', type=dias, default=30,
                   help='ventana en días, 1 a 90 (por defecto 30)')
    return p


def ejecutar(acc, token, sql):
    req = urllib.request.Request(
        API.format(acc=acc), data=sql.encode('utf-8'), method='POST',
        headers={'Authorization': f'Bearer {token}'})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode('utf-8')).get('data', [])


COLUMNAS = {
    'aperturas_dia': ['dia', 'aperturas', 'con_push'],
    'por_version': ['version', 'plataforma', 'aperturas'],
    'push_altas_bajas': ['evento', 'categoria', 'anticipacion', 'total'],
    'envios': ['tema', 'enviados', 'errores'],
}


def main(argv=None) -> int:
    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf-8')
        sys.stderr.reconfigure(encoding='utf-8')
    args = build_parser().parse_args(argv)
    acc = os.environ.get('CLOUDFLARE_ACCOUNT_ID', '').strip()
    token = os.environ.get('CF_METRICAS_TOKEN', '').strip()
    faltan = [n for n, v in (('CLOUDFLARE_ACCOUNT_ID', acc), ('CF_METRICAS_TOKEN', token)) if not v]
    if faltan:
        print(MENSAJE_ENV.format(faltan=', '.join(faltan)))
        return 2
    print(f'Métricas de ¿Cuándo Pagan? - últimos {args.dias} días. '
          'Días en hora de Panamá (UTC-5).')
    for clave, sql in consultas(args.dias).items():
        print(f'\n== {TITULOS[clave]} ==')
        try:
            filas = ejecutar(acc, token, sql)
        except urllib.error.HTTPError as e:
            cuerpo = e.read().decode('utf-8', 'replace')[:300] if hasattr(e, 'read') else ''
            print(f'Error HTTP {e.code} al consultar «{clave}»: {cuerpo}', file=sys.stderr)
            return 1
        except (urllib.error.URLError, OSError, ValueError) as e:
            print(f'Error de red al consultar «{clave}»: {type(e).__name__}', file=sys.stderr)
            return 1
        print(formatear_tabla(COLUMNAS[clave], filas))
    return 0


if __name__ == '__main__':
    sys.exit(main())
