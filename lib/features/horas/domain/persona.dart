// lib/features/horas/domain/persona.dart

/// Persona disponible para carga, consulta o informe de horas.
///
/// La identidad operativa de una persona en este módulo no es solo el DNI,
/// porque una misma persona puede estar asociada a más de una carrera.
///
/// Por eso la clave estable usada en dropdowns, mapas e informes es:
///
///   dni|carreraId
class Persona {
  final String apellido;
  final String nombre;
  final int dni;
  final int carreraId;
  final String carrera;

  const Persona({
    required this.apellido,
    required this.nombre,
    required this.dni,
    required this.carreraId,
    required this.carrera,
  });

  /// Clave única estable para selección, dropdowns, mapas e informes.
  String get key => '$dni|$carreraId';

  /// Nombre completo en formato natural.
  String get nombreCompleto {
    final partes = [
      nombre.trim(),
      apellido.trim(),
    ].where((e) => e.isNotEmpty);

    return partes.join(' ');
  }

  /// Etiqueta visible para dropdowns o listados.
  String get label {
    final ap = apellido.trim();
    final no = nombre.trim();
    final car = carrera.trim();

    final persona = [ap, no].where((e) => e.isNotEmpty).join(', ');

    if (car.isEmpty) {
      return '$persona ($dni)';
    }

    return '$persona ($dni) - $car';
  }

  factory Persona.fromListadoJson(Map<String, dynamic> json) {
    return Persona(
      apellido: _asString(json['apellido']),
      nombre: _asString(json['nombre']),
      dni: _asInt(json['dni'], field: 'dni'),
      carreraId: _asInt(json['carrera_id'], field: 'carrera_id'),
      carrera: _asString(json['carrera']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'apellido': apellido,
      'nombre': nombre,
      'dni': dni,
      'carrera_id': carreraId,
      'carrera': carrera,
    };
  }

  Persona copyWith({
    String? apellido,
    String? nombre,
    int? dni,
    int? carreraId,
    String? carrera,
  }) {
    return Persona(
      apellido: apellido ?? this.apellido,
      nombre: nombre ?? this.nombre,
      dni: dni ?? this.dni,
      carreraId: carreraId ?? this.carreraId,
      carrera: carrera ?? this.carrera,
    );
  }

  @override
  String toString() {
    return 'Persona('
        'apellido: $apellido, '
        'nombre: $nombre, '
        'dni: $dni, '
        'carreraId: $carreraId, '
        'carrera: $carrera'
        ')';
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
