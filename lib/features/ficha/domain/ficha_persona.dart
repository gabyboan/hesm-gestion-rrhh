import '../../licencias/domain/licencia.dart';

class FichaPersona extends LicenciaPersona {
  const FichaPersona({
    required super.dni,
    required super.nombre,
    super.legajo,
    super.carrera,
    super.situacion,
    super.funcion,
    super.activo,
    this.reloj,
    this.fechaIngreso,
    this.fechaNacimiento,
    this.telefono = '',
    this.domicilio = '',
  });

  final int? reloj;
  final DateTime? fechaIngreso;
  final DateTime? fechaNacimiento;
  final String telefono;
  final String domicilio;

  factory FichaPersona.fromJson(Map<String, dynamic> json) {
    final persona = LicenciaPersona.fromJson(json);
    return FichaPersona(
      dni: persona.dni,
      nombre: persona.nombre,
      legajo: persona.legajo,
      carrera: persona.carrera,
      situacion: persona.situacion,
      funcion: persona.funcion,
      activo: persona.activo,
      reloj: (json['reloj'] as num?)?.toInt(),
      fechaIngreso: json['fecha_ingreso'] == null
          ? null
          : DateTime.parse(json['fecha_ingreso'] as String),
      fechaNacimiento: json['fecha_nacimiento'] == null
          ? null
          : DateTime.parse(json['fecha_nacimiento'] as String),
      telefono: json['telefono'] as String? ?? '',
      domicilio: json['domicilio'] as String? ?? '',
    );
  }
}
