import 'package:app_horas/features/medicos/domain/medico_persona.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('acepta suplentes sin legajo y los identifica por nombre', () {
    final persona = MedicoPersona.fromJson({
      'dni': 23456789,
      'apellido': 'Perez',
      'nombre': 'Ana',
      'legajo': null,
    });

    expect(persona.legajo, isNull);
    expect(persona.label, 'Perez, Ana - Sin legajo');
    expect(persona.dni, 23456789);
  });

  test('conserva el legajo de quienes lo tienen asignado', () {
    final persona = MedicoPersona.fromJson({
      'dni': 23456789,
      'apellido': 'Perez',
      'nombre': 'Ana',
      'legajo': '123',
    });

    expect(persona.legajo, 123);
    expect(persona.label, 'Perez, Ana - Legajo 123');
  });
}
