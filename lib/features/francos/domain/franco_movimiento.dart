class FrancoMovimiento {
  final int id;
  final int dni;
  final int carreraId;
  final DateTime fecha;
  final DateTime periodo;
  final int minutos;
  final String motivo;
  final String observacion;
  final String usuarioCarga;
  final String usuarioCargaNombre;
  final String usuarioCargaApellido;
  final String usuarioModifica;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FrancoMovimiento({
    required this.id,
    required this.dni,
    required this.carreraId,
    required this.fecha,
    required this.periodo,
    required this.minutos,
    required this.motivo,
    required this.observacion,
    required this.usuarioCarga,
    required this.usuarioCargaNombre,
    required this.usuarioCargaApellido,
    required this.usuarioModifica,
    required this.createdAt,
    required this.updatedAt,
  });

  String get usuarioCargaLabel {
    final nombre = [usuarioCargaNombre, usuarioCargaApellido]
        .where((part) => part.trim().isNotEmpty)
        .join(' ');

    return nombre.isEmpty ? usuarioCarga : nombre;
  }

  factory FrancoMovimiento.fromJson(Map<String, dynamic> json) {
    return FrancoMovimiento(
      id: _asInt(json['id'], field: 'id'),
      dni: _asInt(json['dni'], field: 'dni'),
      carreraId: _asInt(json['carrera_id'], field: 'carrera_id'),
      fecha: _asDate(json['fecha'], field: 'fecha'),
      periodo: _asDate(json['periodo'], field: 'periodo'),
      minutos: _asInt(json['minutos'], field: 'minutos'),
      motivo: _asString(json['motivo']),
      observacion: _asString(json['observacion']),
      usuarioCarga: _asString(json['usuario_carga']),
      usuarioCargaNombre: _asString(json['usuario_carga_nombre']),
      usuarioCargaApellido: _asString(json['usuario_carga_apellido']),
      usuarioModifica: _asString(json['usuario_modifica']),
      createdAt: _asDateTime(json['created_at'], field: 'created_at'),
      updatedAt: _asDateTime(json['updated_at'], field: 'updated_at'),
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
