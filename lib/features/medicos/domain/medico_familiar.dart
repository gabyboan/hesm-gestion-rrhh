class MedicoFamiliar {
  final int id;
  final String apellidoNombre;
  final DateTime? fechaNacimiento;
  final int? dni;
  final int? edad;
  final String parentesco;

  const MedicoFamiliar({
    required this.id,
    required this.apellidoNombre,
    required this.fechaNacimiento,
    required this.dni,
    required this.edad,
    required this.parentesco,
  });

  String get label {
    final partes = <String>[apellidoNombre, parentesco];
    if (dni != null) partes.add('DNI $dni');
    return partes.join(' - ');
  }

  factory MedicoFamiliar.fromJson(Map<String, dynamic> json) {
    return MedicoFamiliar(
      id: _asInt(json['id'], 'id'),
      apellidoNombre: (json['apellido_nombre'] ?? '').toString().trim(),
      fechaNacimiento: json['fecha_nacimiento'] == null
          ? null
          : DateTime.parse(json['fecha_nacimiento'].toString()),
      dni: json['dni'] == null ? null : _asInt(json['dni'], 'dni'),
      edad: json['edad'] == null ? null : _asInt(json['edad'], 'edad'),
      parentesco: (json['parentesco'] ?? '').toString().trim(),
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
