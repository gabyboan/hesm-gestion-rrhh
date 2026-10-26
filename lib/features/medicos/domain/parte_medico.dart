import 'medico_domicilio.dart';
import 'parte_medico_qr.dart';

enum TipoParteMedico {
  domicilio('DOMICILIO', 'Medico a domicilio'),
  consultorio('CONSULTORIO', 'Medico a consultorio'),
  canje('CANJE', 'Medico para canje'),
  domicilioFamiliar(
    'DOMICILIO_FAMILIAR',
    'Medico por un familiar',
  );

  final String dbValue;
  final String label;

  const TipoParteMedico(this.dbValue, this.label);

  bool get requiereFamiliar => this == TipoParteMedico.domicilioFamiliar;
  bool get tachaConsultorio =>
      this == TipoParteMedico.domicilio ||
      this == TipoParteMedico.domicilioFamiliar;

  String get codigo => switch (this) {
        TipoParteMedico.domicilio || TipoParteMedico.domicilioFamiliar => 'AD',
        TipoParteMedico.canje => 'PC',
        TipoParteMedico.consultorio => 'AC',
      };

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
  final int? empleadoLegajo;
  final String? familiarApellidoNombre;
  final int? familiarDni;
  final int? familiarEdad;
  final int? familiarEdadMeses;
  final String? familiarParentesco;
  final bool esArt;
  final MedicoDomicilio? domicilio;
  final String? aclaracionFechaTurno;
  final ParteMedicoQr? qr;
  final String? carreraNombre;
  final bool esEnfermeria;

  const ParteMedico({
    required this.id,
    required this.dni,
    required this.fecha,
    required this.tipo,
    required this.empleadoApellido,
    required this.empleadoNombre,
    required this.empleadoLegajo,
    required this.familiarApellidoNombre,
    this.familiarDni,
    required this.familiarEdad,
    this.familiarEdadMeses,
    required this.familiarParentesco,
    this.esArt = false,
    this.domicilio,
    this.aclaracionFechaTurno,
    this.qr,
    this.carreraNombre,
    this.esEnfermeria = false,
  });

  String get empleadoCompleto => [
        empleadoApellido.trim(),
        empleadoNombre.trim()
      ].where((part) => part.isNotEmpty).join(', ');

  String get descripcionRegistro => [
        empleadoCompleto,
        if (tipo.requiereFamiliar &&
            familiarApellidoNombre?.trim().isNotEmpty == true)
          'IF: ${familiarApellidoNombre!.trim()}',
        if (aclaracionFechaTurno?.trim().isNotEmpty == true)
          aclaracionFechaTurno!.trim(),
      ].join(' - ');

  ParteMedico conDomicilio(MedicoDomicilio? value) => ParteMedico(
        id: id,
        dni: dni,
        fecha: fecha,
        tipo: tipo,
        empleadoApellido: empleadoApellido,
        empleadoNombre: empleadoNombre,
        empleadoLegajo: empleadoLegajo,
        familiarApellidoNombre: familiarApellidoNombre,
        familiarDni: familiarDni,
        familiarEdad: familiarEdad,
        familiarEdadMeses: familiarEdadMeses,
        familiarParentesco: familiarParentesco,
        esArt: esArt,
        domicilio: value,
        aclaracionFechaTurno: aclaracionFechaTurno,
        qr: qr,
        carreraNombre: carreraNombre,
        esEnfermeria: esEnfermeria,
      );

  ParteMedico conCarrera({String? nombre, required bool esEnfermeria}) =>
      ParteMedico(
        id: id,
        dni: dni,
        fecha: fecha,
        tipo: tipo,
        empleadoApellido: empleadoApellido,
        empleadoNombre: empleadoNombre,
        empleadoLegajo: empleadoLegajo,
        familiarApellidoNombre: familiarApellidoNombre,
        familiarDni: familiarDni,
        familiarEdad: familiarEdad,
        familiarEdadMeses: familiarEdadMeses,
        familiarParentesco: familiarParentesco,
        esArt: esArt,
        domicilio: domicilio,
        aclaracionFechaTurno: aclaracionFechaTurno,
        qr: qr,
        carreraNombre: nombre,
        esEnfermeria: esEnfermeria,
      );

  String? get familiarNombreParaImprimir {
    final nombreCompleto = familiarApellidoNombre?.trim();
    if (nombreCompleto == null || nombreCompleto.isEmpty) return null;

    final partes = nombreCompleto.split(',');
    final apellidos = partes.first.trim().split(RegExp(r'\s+'));
    final apellido = apellidos.isEmpty ? '' : apellidos.first;
    final nombres = (partes.length > 1
            ? partes.skip(1).join(' ')
            : partes.first.split(RegExp(r'\s+')).skip(1).join(' '))
        .trim()
        .split(RegExp(r'\s+'))
        .where((nombre) => nombre.isNotEmpty)
        .take(2);

    return [
      if (apellido.isNotEmpty) apellido,
      if (nombres.isNotEmpty) nombres.join(' '),
    ].join(', ');
  }

  String get textoSolicitudAdicional => [
        if (tipo == TipoParteMedico.canje) 'Para canje',
        if (esArt) '[ART]',
      ].join(' ');

  factory ParteMedico.fromJson(Map<String, dynamic> json) {
    return ParteMedico(
      id: _asInt(json['id'], 'id'),
      dni: _asInt(json['dni'], 'dni'),
      fecha: DateTime.parse(json['fecha'].toString()),
      tipo: TipoParteMedico.fromDb(json['tipo'].toString()),
      empleadoApellido: (json['empleado_apellido'] ?? '').toString().trim(),
      empleadoNombre: (json['empleado_nombre'] ?? '').toString().trim(),
      empleadoLegajo: json['empleado_legajo'] == null
          ? null
          : _asInt(json['empleado_legajo'], 'empleado_legajo'),
      familiarApellidoNombre: _asNullableString(
        json['familiar_apellido_nombre'],
      ),
      familiarDni: json['familiar_dni'] == null
          ? null
          : _asInt(json['familiar_dni'], 'familiar_dni'),
      familiarEdad: json['familiar_edad'] == null
          ? null
          : _asInt(json['familiar_edad'], 'familiar_edad'),
      familiarEdadMeses: json['familiar_edad_meses'] == null
          ? null
          : _asInt(json['familiar_edad_meses'], 'familiar_edad_meses'),
      familiarParentesco: _asNullableString(json['familiar_parentesco']),
      esArt: json['es_art'] == true,
      carreraNombre: _asNullableString(json['carrera_nombre']),
      esEnfermeria: json['es_enfermeria'] == true,
      aclaracionFechaTurno: _asNullableString(json['aclaracion_fecha_turno']),
      qr: json['codigo_qr'] == null
          ? null
          : ParteMedicoQr.parse(json['codigo_qr'].toString()),
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
