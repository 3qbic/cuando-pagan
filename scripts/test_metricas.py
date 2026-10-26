import io
import json
import os
import sys
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
import metricas  # noqa: E402


class FakeResp:
    def __init__(self, payload):
        self._b = json.dumps(payload).encode('utf-8')

    def read(self):
        return self._b

    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False


class ConsultasTest(unittest.TestCase):
    def test_aperturas_dia(self):
        q = metricas.consultas(30)['aperturas_dia']
        for frag in ["FROM cuandopagan_uso", "index1 = 'apertura'",
                     "SUM(_sample_interval)", "INTERVAL '30' DAY",
                     "sumIf(_sample_interval, blob4 = '1')", "con_push",
                     "toStartOfDay(timestamp - INTERVAL '5' HOUR)"]:
            self.assertIn(frag, q)
        self.assertTrue(q.rstrip().endswith('FORMAT JSON'))

    def test_dias_en_las_cuatro(self):
        qs = metricas.consultas(7)
        self.assertEqual(set(qs), {'aperturas_dia', 'por_version',
                                   'push_altas_bajas', 'envios'})
        for q in qs.values():
            self.assertIn("INTERVAL '7' DAY", q)
            self.assertTrue(q.rstrip().endswith('FORMAT JSON'))

    def test_dias_fuera_de_rango(self):
        for v in ('0', '91'):
            with redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
                metricas.build_parser().parse_args(['--dias', v])


class TablaTest(unittest.TestCase):
    def test_tabla(self):
        t = metricas.formatear_tabla(['dia', 'aperturas'],
                                     [{'dia': '2026-10-26', 'aperturas': 3}])
        lines = t.splitlines()
        self.assertEqual(len(lines), 3)
        self.assertEqual(lines[0], 'dia         aperturas')
        self.assertEqual(lines[1], '----------  ---------')
        self.assertEqual(lines[2], '2026-10-26          3')

    def test_vacia(self):
        self.assertEqual(metricas.formatear_tabla(['a'], []), '(sin datos)')


class MainTest(unittest.TestCase):
    def test_sin_env(self):
        out, err = io.StringIO(), io.StringIO()
        with mock.patch.dict(os.environ, {}, clear=True), \
                redirect_stdout(out), redirect_stderr(err):
            rc = metricas.main([])
        self.assertEqual(rc, 2)
        self.assertIn('CF_METRICAS_TOKEN', out.getvalue() + err.getvalue())

    def test_run_mockeado(self):
        env = {'CLOUDFLARE_ACCOUNT_ID': 'acc123', 'CF_METRICAS_TOKEN': 'tok-fake'}
        reqs = []

        def fake(req, timeout=None):
            reqs.append(req)
            return FakeResp({'data': [{'dia': '2026-10-26', 'aperturas': 3,
                                       'con_push': 1}]})

        out = io.StringIO()
        with mock.patch.dict(os.environ, env, clear=True), \
                mock.patch('urllib.request.urlopen', fake), redirect_stdout(out):
            rc = metricas.main([])
        self.assertEqual(rc, 0)
        self.assertEqual(len(reqs), 4)
        r = reqs[0]
        self.assertTrue(r.full_url.endswith(
            '/accounts/acc123/analytics_engine/sql'))
        self.assertEqual(r.get_header('Authorization'), 'Bearer tok-fake')
        self.assertIn(b'FORMAT JSON', r.data)
        text = out.getvalue()
        self.assertNotIn('tok-fake', text)
        self.assertIn('Días en hora de Panamá', text)
        for title in metricas.TITULOS.values():
            self.assertIn(title, text)

    def test_error_http_no_filtra_token(self):
        import urllib.error
        env = {'CLOUDFLARE_ACCOUNT_ID': 'acc123', 'CF_METRICAS_TOKEN': 'tok-fake'}

        def boom(req, timeout=None):
            raise urllib.error.HTTPError(req.full_url, 403, 'Forbidden', {},
                                         io.BytesIO(b'{"errors":"denegado"}'))

        out, err = io.StringIO(), io.StringIO()
        with mock.patch.dict(os.environ, env, clear=True), \
                mock.patch('urllib.request.urlopen', boom), \
                redirect_stdout(out), redirect_stderr(err):
            rc = metricas.main([])
        self.assertEqual(rc, 1)
        both = out.getvalue() + err.getvalue()
        self.assertIn('403', both)
        self.assertNotIn('tok-fake', both)


if __name__ == '__main__':
    unittest.main()
