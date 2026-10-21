import 'package:app_horas/features/medicos/domain/parte_medico.dart';
import 'package:app_horas/features/medicos/domain/medico_domicilio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lee y conserva un parte de suplente sin legajo', () {
    final parte = ParteMedico.fromJson({
      'id': 2,
      'dni': 23456789,
      'fecha': '2026-10-16',
      'tipo': 'DOMICILIO',
      'empleado_apellido': 'Perez',
      'empleado_nombre': 'Ana',
      'empleado_legajo': null,
    });

    expect(parte.empleadoLegajo, isNull);
    expect(parte.conDomicilio(const MedicoDomicilio()).empleadoLegajo, isNull);
    expect(parte.descripcionRegistro, 'Perez, Ana');
  });

  test('identifica los tipos con AD, PC y AC', () {
    expect(TipoParteMedico.domicilio.codigo, 'AD');
    expect(TipoParteMedico.domicilioFamiliar.codigo, 'AD');
    expect(TipoParteMedico.canje.codigo, 'PC');
    expect(TipoParteMedico.consultorio.codigo, 'AC');
  });

  test('muestra agente, familiar completo y aclaración en ese orden', () {
    final parte = ParteMedico(
      id: 1,
      dni: 12345678,
      fecha: DateTime(2026, 10, 14),
      tipo: TipoParteMedico.domicilioFamiliar,
      empleadoApellido: 'Perez',
      empleadoNombre: 'Juan',
      empleadoLegajo: 123,
      familiarApellidoNombre: ' Gomez Lopez, Ana Maria Beatriz ',
      familiarEdad: 8,
      familiarParentesco: 'Hija',
      aclaracionFechaTurno: ' Turno tarde ',
    );
    expect(parte.descripcionRegistro,
        'Perez, Juan - IF: Gomez Lopez, Ana Maria Beatriz - Turno tarde');
  });

  test('consultorio no requiere tachar el domicilio', () {
    expect(TipoParteMedico.consultorio.tachaConsultorio, isFalse);
  });

  test('ofrece los cuatro tipos de solicitud esperados', () {
    expect(TipoParteMedico.values, hasLength(4));
    expect(
      TipoParteMedico.values.map((tipo) => tipo.label),
      [
        'Medico a domicilio',
        'Medico a consultorio',
        'Medico para canje',
        'Medico por un familiar',
      ],
    );
  });

  test('indica canje y ART en la aclaración superior', () {
    final parteCanjeArt = ParteMedico(
      id: 1,
      dni: 12345678,
      fecha: DateTime(2026, 10, 8),
      tipo: TipoParteMedico.canje,
      empleadoApellido: 'Perez',
      empleadoNombre: 'Juan',
      empleadoLegajo: 123,
      familiarApellidoNombre: null,
      familiarEdad: null,
      familiarParentesco: null,
      esArt: true,
    );

    expect(parteCanjeArt.textoSolicitudAdicional, 'Para canje [ART]');
  });

  test('el parte por familiar usa los datos del familiar', () {
    final parte = ParteMedico(
      id: 1,
      dni: 12345678,
      fecha: DateTime(2026, 10, 8),
      tipo: TipoParteMedico.domicilioFamiliar,
      empleadoApellido: 'Perez',
      empleadoNombre: 'Juan',
      empleadoLegajo: 123,
      familiarApellidoNombre: 'Perez, Ana',
      familiarDni: 40123456,
      familiarEdad: 8,
      familiarParentesco: 'Hija',
      esArt: false,
    );

    expect(parte.tipo.requiereFamiliar, isTrue);
    expect(parte.familiarDni, 40123456);
    expect(parte.esArt, isFalse);
  });

  test('acorta el nombre familiar a un apellido y hasta dos nombres', () {
    final parte = ParteMedico(
      id: 1,
      dni: 12345678,
      fecha: DateTime(2026, 10, 8),
      tipo: TipoParteMedico.domicilioFamiliar,
      empleadoApellido: 'Perez',
      empleadoNombre: 'Juan',
      empleadoLegajo: 123,
      familiarApellidoNombre: 'Gomez Lopez, Ana Maria Beatriz',
      familiarEdad: 8,
      familiarParentesco: 'Hija',
    );

    expect(parte.familiarNombreParaImprimir, 'Gomez, Ana Maria');
  });

  test('lee la aclaración de fecha y turno del registro', () {
    final parte = ParteMedico.fromJson({
      'id': 2,
      'dni': 12345678,
      'fecha': '2026-10-08',
      'tipo': 'DOMICILIO',
      'empleado_apellido': 'Perez',
      'empleado_nombre': 'Juan',
      'empleado_legajo': 123,
      'familiar_apellido_nombre': null,
      'familiar_dni': null,
      'familiar_edad': null,
      'familiar_parentesco': null,
      'es_art': false,
      'aclaracion_fecha_turno': '7/10 t.t',
    });

    expect(parte.aclaracionFechaTurno, '7/10 t.t');
  });

  test('lee los meses de edad del familiar del registro', () {
    final parte = ParteMedico.fromJson({
      'id': 2,
      'dni': 12345678,
      'fecha': '2026-10-08',
      'tipo': 'DOMICILIO_FAMILIAR',
      'empleado_apellido': 'Perez',
      'empleado_nombre': 'Juan',
      'empleado_legajo': 123,
      'familiar_apellido_nombre': 'Perez, Ana',
      'familiar_edad': 0,
      'familiar_edad_meses': 8,
      'familiar_parentesco': 'Hija',
    });

    expect(parte.familiarEdad, 0);
    expect(parte.familiarEdadMeses, 8);
    expect(parte.conDomicilio(const MedicoDomicilio()).familiarEdadMeses, 8);
  });

  test('lee la marca ART del registro', () {
    final parte = ParteMedico.fromJson({
      'id': 2,
      'dni': 12345678,
      'fecha': '2026-10-08',
      'tipo': 'DOMICILIO',
      'empleado_apellido': 'Perez',
      'empleado_nombre': 'Juan',
      'empleado_legajo': 123,
      'familiar_apellido_nombre': null,
      'familiar_dni': null,
      'familiar_edad': null,
      'familiar_parentesco': null,
      'es_art': true,
    });

    expect(parte.esArt, isTrue);
  });

  test('interpreta los campos del domicilio vigente', () {
    final domicilio = MedicoDomicilio.fromJson({
      'calle': 'San Martin',
      'numero': '123',
      'barrio': 'Centro',
      'torre': 'B2',
      'casa': '4',
      'localidad_nombre': 'Resistencia',
      'provincia_nombre': 'Chaco',
    });

    expect(domicilio.calle, 'San Martin');
    expect(domicilio.numero, '123');
    expect(domicilio.barrio, 'Centro');
    expect(domicilio.torre, 'B2');
    expect(domicilio.casa, '4');
    expect(domicilio.estaVacio, isFalse);
    expect(const MedicoDomicilio().estaVacio, isTrue);
  });

  test('solo indica localidad si el domicilio no es de Paraná', () {
    expect(
      const MedicoDomicilio(localidad: 'Paraná', provincia: 'Entre Ríos')
          .localidadExterna,
      isNull,
    );
    expect(
      const MedicoDomicilio(localidad: 'Resistencia', provincia: 'Chaco')
          .localidadExterna,
      'Resistencia, Chaco',
    );
  });
}
