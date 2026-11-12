import 'dart:async';

import 'package:app_horas/core/cache/session_cache_provider.dart';
import 'package:app_horas/core/cache/session_data_cache.dart';
import 'package:app_horas/features/horas/application/horas_providers.dart';
import 'package:app_horas/features/horas/data/horas_repository.dart';
import 'package:app_horas/features/horas/domain/persona.dart';
import 'package:app_horas/features/horas/domain/tipo_hora.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class DelayedHours implements HorasRepository {
  Completer<void> pending = Completer<void>();
  final operations = <String?>[];
  @override
  Future<void> cargarHora(
      {String? operacionId,
      required int dni,
      required int carreraId,
      required DateTime fecha,
      required String tipoDb,
      int? minutos}) {
    operations.add(operacionId);
    return pending.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('una respuesta anterior al logout no limpia el formulario siguiente',
      () async {
    final repository = DelayedHours();
    final container = ProviderContainer(overrides: [
      horasRepoProvider.overrideWithValue(repository),
      sessionDataCacheProvider.overrideWithValue(SessionDataCache()),
    ]);
    addTearDown(container.dispose);
    await container.read(cargarHoraControllerProvider.future);
    container.read(selectedPersonaProvider.notifier).state = const Persona(
        apellido: 'DEMO',
        nombre: 'Prueba',
        dni: 1001,
        carreraId: 17,
        carrera: 'Cualquiera');
    container.read(tipoHoraProvider.notifier).state = TipoHora.gremial;
    container.read(minutosProvider.notifier).state = 60;
    final old = container.read(cargarHoraControllerProvider.notifier).submit();
    container.invalidate(cargarHoraControllerProvider);
    await container.read(cargarHoraControllerProvider.future);
    container.read(minutosProvider.notifier).state = 120;
    repository.pending.complete();
    await old;
    expect(container.read(minutosProvider), 120);
    expect(container.read(cargarHoraControllerProvider).isLoading, isFalse);
  });

  test('dos pulsaciones comparten envío, errores y clave de reintento',
      () async {
    final repository = DelayedHours();
    final container = ProviderContainer(overrides: [
      horasRepoProvider.overrideWithValue(repository),
      sessionDataCacheProvider.overrideWithValue(SessionDataCache()),
    ]);
    addTearDown(container.dispose);
    await container.read(cargarHoraControllerProvider.future);
    container.read(selectedPersonaProvider.notifier).state = const Persona(
        apellido: 'DEMO',
        nombre: 'Prueba',
        dni: 1001,
        carreraId: 17,
        carrera: 'Cualquiera');
    container.read(tipoHoraProvider.notifier).state = TipoHora.gremial;
    container.read(minutosProvider.notifier).state = 60;
    final controller = container.read(cargarHoraControllerProvider.notifier);
    final first = controller.submit();
    final second = controller.submit();
    expect(identical(first, second), isTrue);
    expect(repository.operations, hasLength(1));
    expect(container.read(cargarHoraControllerProvider).isLoading, isTrue);
    final failed = expectLater(first, throwsStateError);
    repository.pending.completeError(StateError('Respuesta perdida'));
    await failed;
    repository.pending = Completer<void>();
    final retry = controller.submit();
    expect(repository.operations[1], repository.operations[0]);
    expect(repository.operations[1], isNotNull);
    repository.pending.complete();
    await retry;
    expect(container.read(minutosProvider), isNull);
    container.read(minutosProvider.notifier).state = 60;
    repository.pending = Completer<void>();
    final legitimate = controller.submit();
    expect(repository.operations[2], isNot(repository.operations[1]));
    repository.pending.complete();
    await legitimate;
  });
}
