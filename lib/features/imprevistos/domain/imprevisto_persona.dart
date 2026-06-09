class ImprevistoPersona {
  final int dni;
  final String apellido;
  final String nombre;
  final int carreraId;
  final String carrera;
  final int usados;
  final int restantes;

  const ImprevistoPersona({
    required this.dni,
    required this.apellido,
    required this.nombre,
    required this.carreraId,
    required this.carrera,
    required this.usados,
    required this.restantes,
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

  factory ImprevistoPersona.fromJson(Map<String, dynamic> json) {
    return ImprevistoPersona(
      dni: _asInt(json['dni'], field: 'dni'),
      apellido: _asString(json['apellido']),
      nombre: _asString(json['nombre']),
      carreraId: _asInt(json['carrera_id'], field: 'carrera_id'),
      carrera: _asString(json['carrera']),
      usados: _asInt(json['usados'], field: 'usados'),
      restantes: _asInt(json['restantes'], field: 'restantes'),
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
}
