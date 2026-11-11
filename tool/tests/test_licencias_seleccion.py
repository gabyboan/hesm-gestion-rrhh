import sys
from pathlib import Path
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from licencias_seleccion import nombre_compatible, seleccionar, codigo_importado


class SeleccionLicenciasTest(unittest.TestCase):
    def registro(self, fila=2, dni=10000001, nombre='PÉREZ, JUAN CARLOS', desde='2026-01-01'):
        return dict(fila=fila, dni=dni, apellido_nombre=nombre, tipo='Lic. Anual',
                    desde=desde, hasta='2026-01-02', dias=2)

    def test_normaliza_escritura_y_exige_apellido_y_nombre(self):
        self.assertTrue(nombre_compatible('PEREZ JUAN', 'Pérez', 'Juan Carlos'))
        self.assertTrue(nombre_compatible('PÉREZ, JUAN CARLOS', 'Pérez', 'Juan Carlos'))
        self.assertFalse(nombre_compatible('JUAN CARLOS', 'Pérez', 'Juan Carlos'))
        self.assertFalse(nombre_compatible('PEREZ LUIS', 'Pérez', 'Juan Carlos'))
        self.assertFalse(nombre_compatible('PEREZ JUAN', 'Pérez Gómez', 'Juan'))

    def test_no_busca_otro_dni_por_nombre(self):
        personas = {10000001: dict(apellido='Gómez', nombre='Luis'),
                    10000002: dict(apellido='Pérez', nombre='Juan Carlos')}
        incluidos, pendientes = seleccionar([self.registro()], personas)
        self.assertEqual(incluidos, [])
        self.assertEqual(pendientes[0]['motivo'], 'DNI_Y_NOMBRE_NO_COINCIDEN')
        self.assertEqual(pendientes[0]['datos']['dni'], 10000001)

    def test_repeticion_no_oculta_una_fila_correcta_tras_otra_erronea(self):
        personas = {10000001: dict(apellido='Pérez', nombre='Juan Carlos')}
        incluidos, pendientes = seleccionar([
            self.registro(nombre='OTRA PERSONA'), self.registro(3), self.registro(4)], personas)
        self.assertEqual([r['fila'] for r in incluidos], [3])
        self.assertEqual([r['motivo'] for r in pendientes],
                         ['DNI_Y_NOMBRE_NO_COINCIDEN', 'REPETICION_MISMO_TIPO_Y_PERIODO'])

    def test_excluye_sin_ficha_y_anteriores_a_2026(self):
        personas = {10000001: dict(apellido='Pérez', nombre='Juan Carlos')}
        incluidos, pendientes = seleccionar([
            self.registro(dni=10000003), self.registro(3, desde='2025-12-31')], personas)
        self.assertEqual(incluidos, [])
        self.assertEqual({r['motivo'] for r in pendientes}, {'DNI_SIN_FICHA', 'ANTERIOR_2026'})

    def test_preserva_tipos_ambiguos_en_lugar_de_inventar_codigos(self):
        for tipo in ['Cuidado de Fliar. Enfermo',
                     'Enf. de LARGO Tratamiento', 'Lic. por Duelo', 'Imprevisto']:
            self.assertIsNone(codigo_importado(tipo, 2))
        self.assertEqual(codigo_importado('Lic. Anual', 20), '01')
        self.assertEqual(codigo_importado('Lic. Profiláctica', 15), '03')
        self.assertEqual(codigo_importado('Franco', 2), '60')
        self.assertEqual(codigo_importado('Lic. por Estudio', 2), '29')
        self.assertEqual(codigo_importado('Enf. de Corto Tratamiento', 20), '04')
        self.assertIsNone(codigo_importado('Enf. de Corto Tratamiento', 21))


if __name__ == '__main__':
    unittest.main()
