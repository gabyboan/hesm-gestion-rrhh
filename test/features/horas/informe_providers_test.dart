import 'package:app_horas/features/horas/application/horas_providers.dart';
import 'package:app_horas/features/horas/application/informe_providers.dart';
import 'package:app_horas/features/horas/domain/hora_registro.dart';
import 'package:app_horas/features/horas/domain/persona.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const conUso = Persona(
    apellido: 'Alvarez',
    nombre: 'Ana',
    dni: 12345678,
    carreraId: 1,
    carrera: 'Titulares',
  );
  const sinUso = Persona(
    apellido: 'Benitez',
    nombre: 'Bruno',
    dni: 23456789,
    carreraId: 1,
    carrera: 'Titulares',
  );
  final registroParticular = HoraRegistro(
    id: 1,
    dni: conUso.dni,
    carreraId: conUso.carreraId,
    fecha: DateTime(2026, 10, 5),
    periodo: DateTime(2026, 10),
    tipo: 'PARTICULAR',
    minutos: 60,
    minutosAplicados: 60,
    minutosExcedidos: 0,
    excedido: false,
  );

  test('la exportación respeta el filtro Solo con uso', () async {
    final container = ProviderContainer(overrides: [
      registrosPeriodoProvider
          .overrideWith((ref) async => [registroParticular]),
      listadoProvider.overrideWith((ref) async => [conUso, sinUso]),
      listadoOficialesProvider.overrideWith((ref) async => []),
    ]);
    addTearDown(container.dispose);

    container.read(informeFiltrosProvider.notifier).state = {
      InformeFiltro.soloConUso,
    };

    final rows = await container.read(informeRowsExportProvider.future);

    expect(rows.map((row) => row.persona.dni), [conUso.dni]);
    expect(rows.single.particularesPorDia[DateTime(2026, 10, 5)], 60);
  });
}
