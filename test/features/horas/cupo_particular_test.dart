import 'package:app_horas/features/horas/domain/cupo_particular.dart';
import 'package:app_horas/features/horas/domain/hora_registro.dart';
import 'package:flutter_test/flutter_test.dart';

HoraRegistro registro(int id, int minutos, {String tipo = 'PARTICULAR'}) =>
    HoraRegistro.fromJson({
      'id': id,
      'dni': 1001,
      'carrera_id': 1,
      'fecha': '2026-11-${id.toString().padLeft(2, '0')}',
      'periodo': '2026-11-01',
      'tipo': tipo,
      'minutos': minutos,
    });

void main() {
  test('cuenta toda la duración y distribuye el excedente por fecha', () {
    final cupo = CupoParticular.desdeRegistros([
      registro(3, 30),
      registro(2, 120),
      registro(1, 120),
      registro(4, 600, tipo: 'OFICIAL'),
      registro(5, 600, tipo: 'GREMIAL'),
    ]);
    expect(cupo.total, 270);
    expect(cupo.aplicados, 180);
    expect(cupo.excedidos, 90);
    expect(cupo.disponibles, 0);
    expect(cupo.excedidoPorId, {1: 0, 2: 60, 3: 30});
  });

  test('avisa solo al superar el cupo y recalcula tras borrar', () {
    final cupo = CupoParticular.desdeRegistros([registro(2, 120)]);
    expect(cupo.excedidoConCarga(60), 0);
    expect(cupo.excedidoConCarga(90), 30);
    expect(cupo.disponibles, 60);
    expect(CupoParticular.desdeRegistros([]).disponibles, 180);
  });
}
