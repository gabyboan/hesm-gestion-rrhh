enum TipoParteMedico {
  domicilio('DOMICILIO', 'Medico a domicilio'),
  consultorio('CONSULTORIO', 'Medico a consultorio'),
  canje('CANJE', 'Medico para canje'),
  domicilioFamiliar(
    'DOMICILIO_FAMILIAR',
    'Medico a domicilio por indole familiar',
  );

  final String dbValue;
  final String label;

  const TipoParteMedico(this.dbValue, this.label);

  bool get requiereFamiliar => this == TipoParteMedico.domicilioFamiliar;
  bool get tachaConsultorio => this != TipoParteMedico.consultorio;

  static TipoParteMedico fromDb(String value) {
    return values.firstWhere(
      (tipo) => tipo.dbValue == value,
      orElse: () => throw FormatException('Tipo de parte medico invalido'),
    );
  }
}

class ParteMedico {
  final int id;
  final int dni;
  final DateTime fecha;
  final TipoParteMedico tipo;
  final String empleadoApellido;
  final String empleadoNombre;
  final int empleadoLegajo;
  final String? familiarApellidoNombre;
  final int? familiarEdad;
  final String? familiarParentesco;

  const ParteMedico({
    required this.id,
    required this.dni,
    required this.fecha,
    required this.tipo,
    required this.empleadoApellido,
    required this.empleadoNombre,
    required this.empleadoLegajo,
    required this.familiarApellidoNombre,
    required this.familiarEdad,
    required this.familiarParentesco,
  });

  String get empleadoCompleto => [
        empleadoApellido.trim(),
        empleadoNombre.trim()
      ].where((part) => part.isNotEmpty).join(', ');

  factory ParteMedico.fromJson(Map<String, dynamic> json) {
    return ParteMedico(
      id: _asInt(json['id'], 'id'),
      dni: _asInt(json['dni'], 'dni'),
      fecha: DateTime.parse(json['fecha'].toString()),
      tipo: TipoParteMedico.fromDb(json['tipo'].toString()),
      empleadoApellido: (json['empleado_apellido'] ?? '').toString().trim(),
      empleadoNombre: (json['empleado_nombre'] ?? '').toString().trim(),
      empleadoLegajo: _asInt(json['empleado_legajo'], 'empleado_legajo'),
      familiarApellidoNombre: _asNullableString(
        json['familiar_apellido_nombre'],
      ),
      familiarEdad: json['familiar_edad'] == null
          ? null
          : _asInt(json['familiar_edad'], 'familiar_edad'),
      familiarParentesco: _asNullableString(json['familiar_parentesco']),
    );
  }

  static String? _asNullableString(dynamic value) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? null : text;
  }

  static int _asInt(dynamic value, String field) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
    throw FormatException('Campo entero requerido ausente: $field');
  }
}
