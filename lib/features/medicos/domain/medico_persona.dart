class MedicoPersona {
  final int dni;
  final String apellido;
  final String nombre;
  final int legajo;

  const MedicoPersona({
    required this.dni,
    required this.apellido,
    required this.nombre,
    required this.legajo,
  });

  String get nombreCompleto => [apellido.trim(), nombre.trim()]
      .where((part) => part.isNotEmpty)
      .join(', ');

  String get label => '$nombreCompleto - Legajo $legajo';

  factory MedicoPersona.fromJson(Map<String, dynamic> json) {
    return MedicoPersona(
      dni: _asInt(json['dni'], 'dni'),
      apellido: (json['apellido'] ?? '').toString().trim(),
      nombre: (json['nombre'] ?? '').toString().trim(),
      legajo: _asInt(json['legajo'], 'legajo'),
    );
  }

  static int _asInt(dynamic value, String field) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
    throw FormatException('Campo entero requerido ausente: $field');
  }
}
