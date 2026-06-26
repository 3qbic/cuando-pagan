# Calendario de Registro y Pago de Salarios 2026 - Datos Tabulados

Fuente: PDFs oficiales MEF / Contraloria General de la Republica
- `Calendario-de-Registro-y-Pago-de-Salario-Primer-semestre-del-2026-003.pdf`
- `Calendario-de-Registro-y-Pago-de-Salario-Segundo-semestre-del-2026.pdf`

Firmantes: Lcdo. Vladimir Saenz (Director Gral. de Tesoreria, MEF) y Lcdo. Felipe Almanza (Director Nacional de Metodos y Sistemas de Contabilidad, CGR).

## Archivos generados

| Archivo | Contenido |
|---------|-----------|
| `calendario_pago_salarios_2026.csv` | Tabla principal (tidy), 120 filas |
| `grupos_entidades.csv` | Leyenda Grupo -> Entidad, 33 entidades |
| `xiii_mes_2026.csv` | Fechas aprox. del Decimo Tercer Mes, 3 filas |
| `calendario_pago_2026.duckdb` | Base DuckDB con las 3 tablas y columnas DATE |

## Modelo de datos

### Tabla `calendario` (1 fila por mes x categoria x quincena)
- `anio` (2026), `semestre` (1=ene-jun, 2=jul-dic)
- `mes`, `mes_num` (1-12)
- `categoria`: `JUBILADOS`, `GASTOS DE REPRESENTACION`, `GRUPO 1`, `GRUPO 2`, `GRUPO 3`
- `quincena`: 1 (primera) o 2 (segunda)
- `inicio_registro`, `cierre_registro`, `retencion_ach`, `fecha_pago` (formato ISO `YYYY-MM-DD`)

> `retencion_ach` corresponde a "RETENCION ACH" (1er semestre) / "RETENCION ACH ENTIDADES" (2do semestre): es el mismo concepto.

### Tabla `grupos_entidades`
- `grupo`: `GRUPO 1` / `GRUPO 2` / `GRUPO 3`
- `entidad`: institucion que cobra en la fecha de ese grupo

La leyenda es identica en ambos semestres. **MIDES (Min. de Desarrollo Social) pertenece al GRUPO 3.**

### Tabla `xiii_mes`
- Fechas aproximadas del Decimo Tercer Mes: 20-feb-2026, 06-ago-2026, 04-dic-2026.

## Como consultar

### DuckDB CLI / Python
```python
import duckdb
con = duckdb.connect('calendario_pago_2026.duckdb')

# Proximos pagos de MIDES (Grupo 3) desde hoy
con.sql('''
  SELECT mes, quincena, fecha_pago
  FROM calendario
  WHERE categoria = 'GRUPO 3' AND fecha_pago >= current_date
  ORDER BY fecha_pago
''').show()
```

### En que grupo paga una entidad
```sql
SELECT grupo FROM grupos_entidades WHERE entidad ILIKE '%Desarrollo Social%';
```

### Fechas de pago de una entidad (join)
```sql
SELECT c.mes, c.quincena, c.fecha_pago
FROM calendario c
JOIN grupos_entidades g ON g.grupo = c.categoria
WHERE g.entidad = 'Min. de Desarrollo Social'
ORDER BY c.fecha_pago;
```

### Recargar desde los CSV (si se regeneran)
```sql
CREATE OR REPLACE TABLE calendario AS
SELECT * FROM read_csv_auto('calendario_pago_salarios_2026.csv', header=true);
```

## Notas
- Nota del PDF: "Las entidades a las que la Contraloria General de la Republica le presta el servicio de emision de pago, recibiran su beneficio en la fecha que corresponda al grupo que le preside el sector."
- Las fechas de ENERO 2026 inician su registro en diciembre 2025 (por eso aparecen fechas 2025 en inicio/cierre/retencion).
- Datos transcritos de los PDF; ante cualquier ajuste oficial, prevalece el documento del MEF/CGR.
