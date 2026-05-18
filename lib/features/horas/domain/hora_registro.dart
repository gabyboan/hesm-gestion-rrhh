class HoraRegistro {
  final int id;
  final int dni;
  final int carreraId;
  final DateTime fecha;
  final DateTime periodo;
  final String tipo;
  final int? minutos;
  final int minutosAplicados;
  final int minutosExcedidos;
  final bool excedido;

  HoraRegistro({
    required this.id,
    required this.dni,
    required this.carreraId,
    required this.fecha,
    required this.periodo,
    required this.tipo,
    required this.minutos,
    required this.minutosAplicados,
    required this.minutosExcedidos,
    required this.excedido,
  });

  factory HoraRegistro.fromJson(Map<String, dynamic> j) {
    DateTime parseDate(dynamic v) => DateTime.parse(v.toString());

    return HoraRegistro(
      id: (j['id'] as num).toInt(),
      dni: (j['dni'] as num).toInt(),
      carreraId: (j['carrera_id'] as num).toInt(),
      fecha: parseDate(j['fecha']),
      periodo: parseDate(j['periodo']),
      tipo: (j['tipo'] ?? '').toString(),
      minutos: j['minutos'] == null ? null : (j['minutos'] as num).toInt(),
      minutosAplicados: (j['minutos_aplicados'] as num).toInt(),
      minutosExcedidos: (j['minutos_excedidos'] as num).toInt(),
      excedido: j['excedido'] == true,
    );
  }
}
