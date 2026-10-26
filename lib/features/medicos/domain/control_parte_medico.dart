import 'parte_medico.dart';

class ControlParteMedico {
  const ControlParteMedico({
    required this.version,
    required this.fechaDesde,
    required this.diasAprobados,
    required this.fechaHasta,
    required this.medicoNombre,
    required this.medicoMatricula,
    required this.usuarioRegistro,
    required this.registradoAt,
    this.motivoRectificacion,
  });

  final int version;
  final DateTime fechaDesde;
  final int diasAprobados;
  final DateTime? fechaHasta;
  final String medicoNombre;
  final String medicoMatricula;
  final String usuarioRegistro;
  final DateTime registradoAt;
  final String? motivoRectificacion;

  factory ControlParteMedico.fromJson(Map<String, dynamic> json) =>
      ControlParteMedico(
        version: (json['version'] as num).toInt(),
        fechaDesde: DateTime.parse(json['fecha_desde'] as String),
        diasAprobados: (json['dias_aprobados'] as num).toInt(),
        fechaHasta: json['fecha_hasta'] == null
            ? null
            : DateTime.parse(json['fecha_hasta'] as String),
        medicoNombre: json['medico_nombre'] as String,
        medicoMatricula: json['medico_matricula'] as String,
        usuarioRegistro: json['usuario_registro'] as String,
        registradoAt: DateTime.parse(json['registrado_at'] as String),
        motivoRectificacion: json['motivo_rectificacion'] as String?,
      );
}

class DocumentoParteMedico {
  const DocumentoParteMedico({
    required this.parte,
    required this.anulado,
    required this.controles,
  });

  final ParteMedico parte;
  final bool anulado;
  final List<ControlParteMedico> controles;

  ControlParteMedico? get ultimoControl =>
      controles.isEmpty ? null : controles.first;

  factory DocumentoParteMedico.fromJson(Map<String, dynamic> json) {
    final parte = Map<String, dynamic>.from(json['parte'] as Map);
    final controles = (json['controles'] as List)
        .map((item) =>
            ControlParteMedico.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList()
      ..sort((a, b) => b.version.compareTo(a.version));
    return DocumentoParteMedico(
      parte: ParteMedico.fromJson(parte),
      anulado: parte['anulado_at'] != null,
      controles: controles,
    );
  }
}
