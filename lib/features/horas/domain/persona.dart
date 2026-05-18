class Persona {
  final String apellido;
  final String nombre;
  final int dni;
  final int carreraId;
  final String carrera;

  Persona({
    required this.apellido,
    required this.nombre,
    required this.dni,
    required this.carreraId,
    required this.carrera,
  });

  // ✅ clave única estable para dropdown/selección
  String get key => '$dni|$carreraId';

  String get label => '$apellido, $nombre ($dni) - $carrera';

  factory Persona.fromListadoJson(Map<String, dynamic> j) {
    return Persona(
      apellido: (j['apellido'] ?? '').toString(),
      nombre: (j['nombre'] ?? '').toString(),
      dni: (j['dni'] as num).toInt(),
      carreraId: (j['carrera_id'] as num).toInt(),
      carrera: (j['carrera'] ?? '').toString(),
    );
  }
}
