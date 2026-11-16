import 'package:app_horas/features/ficha/data/ficha_licencias_printer.dart';
import 'package:app_horas/features/ficha/domain/ficha_persona.dart';
import 'package:app_horas/features/licencias/domain/licencia.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  LicenciaRegistro fila(
    int id,
    String desde, {
    int? orden,
    bool anulada = false,
  }) =>
      LicenciaRegistro.fromJson({
        'id': id,
        'dni': 12345678,
        'apellido_nombre': 'AGENTE FICTICIO',
        'tipo_id': 101,
        'tipo': {'nombre': 'Anual', 'codigo': '01', 'columna_ficha': 'ANUAL'},
        'desde': desde,
        'hasta': desde,
        'dias': 1,
        if (orden != null) 'orden_ficha_por_anio': {'2026': orden},
        if (anulada) 'anulado_at': '2026-11-16',
      });
  List<int> orden(List<LicenciaRegistro> rows, int? anio) =>
      FichaLicenciasPrinter.paginar(
        persona: const FichaPersona(
          dni: 12345678,
          nombre: 'AGENTE FICTICIO',
        ),
        registros: rows,
        anio: anio,
      )
          .expand((page) => page)
          .where((row) => !row.continuacion)
          .map((row) => row.registroId)
          .toList();
  test('planilla y acumulada respetan las filas insertadas arriba o abajo', () {
    final rows = [
      fila(10, '2026-01-01', orden: 2),
      fila(11, '2026-12-01', orden: 1),
      fila(12, '2026-02-01', orden: 3),
    ];
    expect(orden(rows, 2026), [11, 10, 12]);
    expect(orden(rows, null), [11, 10, 12]);
  });
  test('sin disposición previa mantiene la cronología y excluye anuladas', () {
    expect(
      orden([
        fila(2, '2026-02-01'),
        fila(1, '2026-01-01'),
        fila(3, '2026-01-02', anulada: true),
      ], 2026),
      [1, 2],
    );
  });
  test(
    'cargas posteriores sin posición se agregan al final y no mezclan años',
    () {
      final rows = [
        fila(1, '2026-02-01', orden: 1),
        fila(2, '2026-01-01'),
        fila(3, '2027-01-01'),
      ];
      expect(orden(rows, 2026), [1, 2]);
      expect(orden(rows, null), [1, 2, 3]);
    },
  );
}
