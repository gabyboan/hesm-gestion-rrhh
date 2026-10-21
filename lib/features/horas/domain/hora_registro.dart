// lib/features/horas/domain/hora_registro.dart

/// Registro de hora cargado en el sistema.
///
/// Representa una fila devuelta por las RPC de horas.
///
/// Campos esperados desde Supabase/Postgres:
/// - id
/// - dni
/// - carrera_id
/// - fecha
/// - periodo
/// - tipo
/// - minutos
/// - minutos_aplicados
/// - minutos_excedidos
/// - excedido
/// - usuario_carga
/// - usuario_carga_nombre
/// - usuario_carga_apellido
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
  final DateTime? createdAt;
  final String usuarioCarga;
  final String usuarioCargaNombre;
  final String usuarioCargaApellido;

  const HoraRegistro({
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
    this.createdAt,
    this.usuarioCarga = '',
    this.usuarioCargaNombre = '',
    this.usuarioCargaApellido = '',
  });

  String get usuarioCargaLabel {
    final nombre = [usuarioCargaNombre, usuarioCargaApellido]
        .where((part) => part.trim().isNotEmpty)
        .join(' ');

    return nombre.isEmpty ? usuarioCarga : nombre;
  }

  /// Clave compuesta usada para asociar el registro con una persona.
  ///
  /// Es necesaria porque una misma persona puede existir en más de una carrera.
  String get personaKey => '$dni|$carreraId';

  /// Tipo normalizado para comparaciones internas.
  String get tipoNormalizado => tipo.trim().toUpperCase();

  bool get esParticular => tipoNormalizado == 'PARTICULAR';

  bool get esEnfermedad => tipoNormalizado == 'ENFERMEDAD';

  bool get esOficial => tipoNormalizado == 'OFICIAL';

  bool get tieneExcedente => excedido || minutosExcedidos > 0;

  factory HoraRegistro.fromJson(Map<String, dynamic> json) {
    return HoraRegistro(
      id: _asInt(json['id'], field: 'id'),
      dni: _asInt(json['dni'], field: 'dni'),
      carreraId: _asInt(json['carrera_id'], field: 'carrera_id'),
      fecha: _asDate(json['fecha'], field: 'fecha'),
      periodo: _asDate(json['periodo'], field: 'periodo'),
      tipo: (json['tipo'] ?? '').toString().trim(),
      minutos: _asNullableInt(json['minutos']),
      minutosAplicados: _asInt(json['minutos_aplicados'], fallback: 0),
      minutosExcedidos: _asInt(json['minutos_excedidos'], fallback: 0),
      excedido: _asBool(json['excedido']),
      createdAt: json.containsKey('created_at') && json['created_at'] != null
          ? _asDateTime(json['created_at'], field: 'created_at')
          : null,
      usuarioCarga: _asString(json['usuario_carga']),
      usuarioCargaNombre: _asString(json['usuario_carga_nombre']),
      usuarioCargaApellido: _asString(json['usuario_carga_apellido']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dni': dni,
      'carrera_id': carreraId,
      'fecha': _toYmd(fecha),
      'periodo': _toYmd(periodo),
      'tipo': tipo,
      'minutos': minutos,
      'minutos_aplicados': minutosAplicados,
      'minutos_excedidos': minutosExcedidos,
      'excedido': excedido,
      'created_at': createdAt?.toIso8601String(),
      'usuario_carga': usuarioCarga,
      'usuario_carga_nombre': usuarioCargaNombre,
      'usuario_carga_apellido': usuarioCargaApellido,
    };
  }

  HoraRegistro copyWith({
    int? id,
    int? dni,
    int? carreraId,
    DateTime? fecha,
    DateTime? periodo,
    String? tipo,
    int? minutos,
    bool clearMinutos = false,
    int? minutosAplicados,
    int? minutosExcedidos,
    bool? excedido,
    DateTime? createdAt,
    String? usuarioCarga,
    String? usuarioCargaNombre,
    String? usuarioCargaApellido,
  }) {
    return HoraRegistro(
      id: id ?? this.id,
      dni: dni ?? this.dni,
      carreraId: carreraId ?? this.carreraId,
      fecha: fecha ?? this.fecha,
      periodo: periodo ?? this.periodo,
      tipo: tipo ?? this.tipo,
      minutos: clearMinutos ? null : (minutos ?? this.minutos),
      minutosAplicados: minutosAplicados ?? this.minutosAplicados,
      minutosExcedidos: minutosExcedidos ?? this.minutosExcedidos,
      excedido: excedido ?? this.excedido,
      createdAt: createdAt ?? this.createdAt,
      usuarioCarga: usuarioCarga ?? this.usuarioCarga,
      usuarioCargaNombre: usuarioCargaNombre ?? this.usuarioCargaNombre,
      usuarioCargaApellido: usuarioCargaApellido ?? this.usuarioCargaApellido,
    );
  }

  @override
  String toString() {
    return 'HoraRegistro('
        'id: $id, '
        'dni: $dni, '
        'carreraId: $carreraId, '
        'fecha: ${_toYmd(fecha)}, '
        'periodo: ${_toYmd(periodo)}, '
        'tipo: $tipo, '
        'minutos: $minutos, '
        'minutosAplicados: $minutosAplicados, '
        'minutosExcedidos: $minutosExcedidos, '
        'excedido: $excedido'
        ')';
  }

  static String _asString(dynamic value) {
    return (value ?? '').toString().trim();
  }

  static int _asInt(
    dynamic value, {
    String? field,
    int? fallback,
  }) {
    if (value == null) {
      if (fallback != null) return fallback;
      throw FormatException('Campo entero requerido ausente: ${field ?? '-'}');
    }

    if (value is int) return value;
    if (value is num) return value.toInt();

    final parsed = int.tryParse(value.toString());
    if (parsed != null) return parsed;

    if (fallback != null) return fallback;

    throw FormatException(
      'No se pudo convertir a int el campo ${field ?? '-'}: $value',
    );
  }

  static int? _asNullableInt(dynamic value) {
    if (value == null) return null;

    if (value is int) return value;
    if (value is num) return value.toInt();

    final text = value.toString().trim();
    if (text.isEmpty) return null;

    return int.tryParse(text);
  }

  static bool _asBool(dynamic value) {
    if (value == null) return false;

    if (value is bool) return value;

    if (value is num) return value != 0;

    final text = value.toString().trim().toLowerCase();

    return text == 'true' || text == 't' || text == '1' || text == 'yes';
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

    if (value is DateTime) {
      return value;
    }

    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) {
      throw FormatException('No se pudo convertir a DateTime el campo $field');
    }

    return parsed;
  }

  static String _toYmd(DateTime d) {
    final year = d.year.toString().padLeft(4, '0');
    final month = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }
}
