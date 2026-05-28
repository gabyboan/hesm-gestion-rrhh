import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../data/francos_repository.dart';
import '../domain/franco_movimiento.dart';
import '../domain/franco_persona.dart';

final francosRepoProvider = Provider<FrancosRepository>((ref) {
  final sb = ref.watch(supabaseClientProvider);
  return FrancosRepository(sb);
});

final francosSearchProvider = StateProvider<String>((ref) => '');

final selectedFrancoPersonaProvider = StateProvider<FrancoPersona?>(
  (ref) => null,
);

final francosListadoProvider = FutureProvider<List<FrancoPersona>>((ref) {
  final buscar = ref.watch(francosSearchProvider).trim();
  return ref.watch(francosRepoProvider).listado(
        buscar: buscar.isEmpty ? null : buscar,
      );
});

final francosMovimientosProvider =
    FutureProvider<List<FrancoMovimiento>>((ref) {
  final persona = ref.watch(selectedFrancoPersonaProvider);
  if (persona == null) return Future.value(<FrancoMovimiento>[]);

  return ref.watch(francosRepoProvider).movimientos(
        dni: persona.dni,
        carreraId: persona.carreraId,
      );
});

void invalidateFrancos(Ref ref) {
  ref.invalidate(francosListadoProvider);
  ref.invalidate(francosMovimientosProvider);
}

class FrancoFormData {
  final int dni;
  final int carreraId;
  final DateTime fecha;
  final int cantidad;
  final String motivo;
  final String? observacion;

  const FrancoFormData({
    required this.dni,
    required this.carreraId,
    required this.fecha,
    required this.cantidad,
    required this.motivo,
    this.observacion,
  });
}

class GuardarFrancoController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> crear(FrancoFormData data) async {
    state = const AsyncLoading();

    try {
      await ref.read(francosRepoProvider).crear(
            dni: data.dni,
            carreraId: data.carreraId,
            fecha: data.fecha,
            cantidad: data.cantidad,
            motivo: data.motivo,
            observacion: data.observacion,
          );

      invalidateFrancos(ref);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> modificar({
    required int id,
    required FrancoFormData data,
  }) async {
    state = const AsyncLoading();

    try {
      await ref.read(francosRepoProvider).modificar(
            id: id,
            fecha: data.fecha,
            cantidad: data.cantidad,
            motivo: data.motivo,
            observacion: data.observacion,
          );

      invalidateFrancos(ref);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final guardarFrancoControllerProvider =
    AsyncNotifierProvider<GuardarFrancoController, void>(
  GuardarFrancoController.new,
);

class EliminarFrancoController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async => false;

  Future<bool> eliminar({
    required int id,
    String? motivo,
  }) async {
    state = const AsyncLoading();

    try {
      final ok = await ref.read(francosRepoProvider).eliminar(
            id: id,
            motivo: motivo,
          );

      invalidateFrancos(ref);
      state = AsyncData(ok);
      return ok;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final eliminarFrancoControllerProvider =
    AsyncNotifierProvider<EliminarFrancoController, bool>(
  EliminarFrancoController.new,
);
