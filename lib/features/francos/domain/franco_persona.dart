class FrancoPersona {
  final int dni;
  final String apellido;
  final String nombre;
  final int carreraId;
  final String carrera;
  final int saldoMinutos;
  final bool tieneHorasCargadas;

  const FrancoPersona({
    required this.dni,
    required this.apellido,
    required this.nombre,
    required this.carreraId,
    required this.carrera,
    required this.saldoMinutos,
    required this.tieneHorasCargadas,
  });

  String get key => '$dni|$carreraId';

  String get label {
    final persona = [apellido.trim(), nombre.trim()]
        .where((part) => part.isNotEmpty)
        .join(', ');
    final car = carrera.trim();

    if (car.isEmpty) return '$persona ($dni)';
    return '$persona ($dni) - $car';
  }

  factory FrancoPersona.fromJson(Map<String, dynamic> json) {
    return FrancoPersona(
      dni: _asInt(json['dni'], field: 'dni'),
      apellido: _asString(json['apellido']),
      nombre: _asString(json['nombre']),
      carreraId: _asInt(json['carrera_id'], field: 'carrera_id'),
      carrera: _asString(json['carrera']),
      saldoMinutos: _asInt(json['saldo_minutos'], field: 'saldo_minutos'),
      tieneHorasCargadas: json.containsKey('tiene_horas_cargadas')
          ? _asBool(
              json['tiene_horas_cargadas'],
              field: 'tiene_horas_cargadas',
            )
          : true,
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

  static bool _asBool(
    dynamic value, {
    required String field,
  }) {
    if (value == null) {
      throw FormatException('Campo booleano requerido ausente: $field');
    }

    if (value is bool) return value;

    final text = value.toString().trim().toLowerCase();
    if (text == 'true' || text == 't' || text == '1') return true;
    if (text == 'false' || text == 'f' || text == '0') return false;

    throw FormatException(
      'No se pudo convertir a bool el campo $field: $value',
    );
  }
}
