import 'package:app_horas/features/medicos/data/parte_medico_printer.dart';
import 'package:app_horas/features/medicos/domain/parte_medico.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('genera un PDF imprimible para un parte familiar', () async {
    final parte = ParteMedico(
      id: 1,
      dni: 12345678,
      fecha: DateTime(2026, 6, 12),
      tipo: TipoParteMedico.domicilioFamiliar,
      empleadoApellido: 'Perez',
      empleadoNombre: 'Maria',
      empleadoLegajo: 123,
      familiarApellidoNombre: 'Perez, Juan',
      familiarEdad: 8,
      familiarParentesco: 'Hijo',
    );

    final bytes = await ParteMedicoPrinter.generar(parte);

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('solo consultorio conserva sin tachar la frase del formulario', () {
    expect(TipoParteMedico.consultorio.tachaConsultorio, isFalse);
    expect(TipoParteMedico.domicilio.tachaConsultorio, isTrue);
    expect(TipoParteMedico.canje.tachaConsultorio, isTrue);
    expect(TipoParteMedico.domicilioFamiliar.tachaConsultorio, isTrue);
  });
}
