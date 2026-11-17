import 'hora_registro.dart';

/// Cupo mensual calculado con la duración completa de cada carga.
class CupoParticular {
  static const limiteMinutos = 180;

  final int aplicados;
  final int excedidos;
  final Map<int, int> excedidoPorId;

  const CupoParticular._({
    required this.aplicados,
    required this.excedidos,
    required this.excedidoPorId,
  });

  int get total => aplicados + excedidos;
  int get disponibles => limiteMinutos - aplicados;

  int excedidoConCarga(int minutos) {
    final excedente = total + minutos - limiteMinutos;
    return excedente > 0 ? excedente : 0;
  }

  factory CupoParticular.desdeRegistros(Iterable<HoraRegistro> registros) {
    final particulares = registros.where((r) => r.esParticular).toList()
      ..sort((a, b) {
        final fecha = a.fecha.compareTo(b.fecha);
        return fecha != 0 ? fecha : a.id.compareTo(b.id);
      });
    var aplicados = 0;
    var excedidos = 0;
    final excedidoPorId = <int, int>{};
    for (final registro in particulares) {
      final minutos = registro.minutos ?? 0;
      if (minutos <= 0) continue;
      final disponible = limiteMinutos - aplicados;
      final aplicado = minutos < disponible ? minutos : disponible;
      final excedente = minutos - aplicado;
      aplicados += aplicado;
      excedidos += excedente;
      excedidoPorId[registro.id] = excedente;
    }
    return CupoParticular._(
      aplicados: aplicados,
      excedidos: excedidos,
      excedidoPorId: Map.unmodifiable(excedidoPorId),
    );
  }
}
