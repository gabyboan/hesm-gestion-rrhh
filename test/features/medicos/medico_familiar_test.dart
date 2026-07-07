import 'package:app_horas/features/medicos/domain/medico_familiar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('convierte la respuesta del RPC de familiares', () {
    final familiar = MedicoFamiliar.fromJson({
      'id': 12,
      'apellido_nombre': 'Perez, Ana',
      'fecha_nacimiento': '2018-04-09',
      'dni': 55111222,
      'edad': 8,
      'parentesco': 'Hija',
    });

    expect(familiar.id, 12);
    expect(familiar.apellidoNombre, 'Perez, Ana');
    expect(familiar.fechaNacimiento, DateTime(2018, 4, 9));
    expect(familiar.dni, 55111222);
    expect(familiar.edad, 8);
    expect(familiar.parentesco, 'Hija');
    expect(familiar.label, 'Perez, Ana - Hija - DNI 55111222');
  });

  test('admite fecha, DNI y edad ausentes', () {
    final familiar = MedicoFamiliar.fromJson({
      'id': 4,
      'apellido_nombre': 'Gomez, Luis',
      'fecha_nacimiento': null,
      'dni': null,
      'edad': null,
      'parentesco': 'Conyuge',
    });

    expect(familiar.fechaNacimiento, isNull);
    expect(familiar.dni, isNull);
    expect(familiar.edad, isNull);
    expect(familiar.label, 'Gomez, Luis - Conyuge');
  });
}
