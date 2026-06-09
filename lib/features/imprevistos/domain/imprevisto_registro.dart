class ImprevistoRegistro {
  final int id;
  final int dni;
  final int carreraId;
  final DateTime fecha;
  final int anio;
  final String observacion;
  final DateTime createdAt;

  const ImprevistoRegistro({
    required this.id,
    required this.dni,
    required this.carreraId,
    required this.fecha,
    required this.anio,
    required this.observacion,
    required this.createdAt,
  });

  factory ImprevistoRegistro.fromJson(Map<String, dynamic> json) {
    return ImprevistoRegistro(
      id: _asInt(json['id'], field: 'id'),
      dni: _asInt(json['dni'], field: 'dni'),
      carreraId: _asInt(json['carrera_id'], field: 'carrera_id'),
      fecha: _asDate(json['fecha'], field: 'fecha'),
      anio: _asInt(json['anio'], field: 'anio'),
      observacion: _asString(json['observacion']),
      createdAt: _asDateTime(json['created_at'], field: 'created_at'),
    );
  }

  static String _asString(dynamic value) {
    return (value ?? '').toString().trim();
  }

  static int _asInt(
    dynamic value, {
    required String field,
  }) {
    if (value == null) {
      throw FormatException('Campo entero requerido ausente: $field');
    }

    if (value is int) return value;
    if (value is num) return value.toInt();

    final parsed = int.tryParse(value.toString().trim());
    if (parsed != null) return parsed;

    throw FormatException('No se pudo convertir a int el campo $field: $value');
  }

  static DateTime _asDate(
    dynamic value, {
    required String field,
  }) {
    final parsed = _asDateTime(value, field: field);
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static DateTime _asDateTime(
    dynamic value, {
    required String field,
  }) {
    if (value == null) {
      throw FormatException('Campo fecha requerido ausente: $field');
    }

    if (value is DateTime) return value;

    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) {
      throw FormatException('No se pudo convertir a DateTime el campo $field');
    }

    return parsed;
  }
}
