import sys
from datetime import date
from pathlib import Path
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from licencias_excel import dni_excel, entero, fecha_excel


class LicenciasExcelTest(unittest.TestCase):
    def test_dni_separadores_solo_miles(self):
        for raw in ['12,345,678', '12.345.678', '12345678', '12345678.0']:
            self.assertEqual(dni_excel(raw), 12345678)
        for raw in ['0', '', '12345678.5', '12,34,678', 'NaN']:
            with self.assertRaises(ValueError):
                dni_excel(raw)

    def test_fechas_excel_no_dependen_de_zona_horaria(self):
        self.assertEqual(fecha_excel('46023'), date(2026, 1, 1))
        self.assertEqual(fecha_excel('46318'), date(2026, 10, 23))
        with self.assertRaises(ValueError):
            fecha_excel('46318.5')

    def test_no_redondea_cantidad_ni_adivina_valores_vacios(self):
        for raw in ['', '1.5', 'Infinity', 'NaN']:
            with self.assertRaises(ValueError):
                entero(raw)


if __name__ == '__main__':
    unittest.main()
