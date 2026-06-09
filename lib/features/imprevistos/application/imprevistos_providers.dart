import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../data/imprevistos_repository.dart';
import '../domain/imprevisto_persona.dart';
import '../domain/imprevisto_registro.dart';

final imprevistosRepoProvider = Provider<ImprevistosRepository>((ref) {
  final sb = ref.watch(supabaseClientProvider);
  return ImprevistosRepository(sb);
});

final imprevistosAnioProvider = StateProvider<int>((ref) {
  return DateTime.now().year;
});

final imprevistosSearchProvider = StateProvider<String>((ref) => '');

final selectedImprevistoPersonaProvider = StateProvider<ImprevistoPersona?>(
  (ref) => null,
);

final puedeLeerImprevistosProvider = FutureProvider<bool>((ref) async {
  final sb = ref.watch(supabaseClientProvider);
  final res = await sb.rpc('can_imprevistos_read');
  return res == true;
});

final puedeCargarImprevistosProvider = FutureProvider<bool>((ref) async {
  final sb = ref.watch(supabaseClientProvider);
  final res = await sb.rpc('can_imprevistos_create');
  return res == true;
});

final puedeAdministrarImprevistosProvider = FutureProvider<bool>((ref) async {
  final sb = ref.watch(supabaseClientProvider);
  final res = await sb.rpc('can_imprevistos_admin');
  return res == true;
});

final imprevistosListadoProvider =
    FutureProvider<List<ImprevistoPersona>>((ref) {
  final puedeLeer = ref.watch(puedeLeerImprevistosProvider).valueOrNull;
  if (puedeLeer != true) return Future.value(<ImprevistoPersona>[]);

  final anio = ref.watch(imprevistosAnioProvider);
  final buscar = ref.watch(imprevistosSearchProvider).trim();

  return ref.watch(imprevistosRepoProvider).listado(
        anio: anio,
        buscar: buscar.isEmpty ? null : buscar,
      );
});

final imprevistosRegistrosProvider =
    FutureProvider<List<ImprevistoRegistro>>((ref) {
  final puedeLeer = ref.watch(puedeLeerImprevistosProvider).valueOrNull;
  if (puedeLeer != true) return Future.value(<ImprevistoRegistro>[]);

  final persona = ref.watch(selectedImprevistoPersonaProvider);
  if (persona == null) return Future.value(<ImprevistoRegistro>[]);

  final anio = ref.watch(imprevistosAnioProvider);

  return ref.watch(imprevistosRepoProvider).registros(
        dni: persona.dni,
        carreraId: persona.carreraId,
        anio: anio,
      );
});

void invalidateImprevistos(Ref ref) {
  ref.invalidate(imprevistosListadoProvider);
  ref.invalidate(imprevistosRegistrosProvider);
}

class ImprevistoFormData {
  final int dni;
  final int carreraId;
  final DateTime fecha;
  final String? observacion;

  const ImprevistoFormData({
    required this.dni,
    required this.carreraId,
    required this.fecha,
    required this.observacion,
  });
}

class GuardarImprevistoController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> crear(ImprevistoFormData data) async {
    state = const AsyncLoading();

    try {
      await ref.read(imprevistosRepoProvider).crear(
            dni: data.dni,
            carreraId: data.carreraId,
            fecha: data.fecha,
            observacion: data.observacion,
          );

      invalidateImprevistos(ref);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<bool> modificar({
    required int id,
    required ImprevistoFormData data,
  }) async {
    state = const AsyncLoading();

    try {
      final ok = await ref.read(imprevistosRepoProvider).modificar(
            id: id,
            fecha: data.fecha,
            observacion: data.observacion,
          );

      invalidateImprevistos(ref);
      state = const AsyncData(null);
      return ok;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final guardarImprevistoControllerProvider =
    AsyncNotifierProvider<GuardarImprevistoController, void>(
  GuardarImprevistoController.new,
);

class EliminarImprevistoController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async => false;

  Future<bool> eliminar({required int id}) async {
    state = const AsyncLoading();

    try {
      final ok = await ref.read(imprevistosRepoProvider).eliminar(id: id);

      invalidateImprevistos(ref);
      state = AsyncData(ok);
      return ok;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final eliminarImprevistoControllerProvider =
    AsyncNotifierProvider<EliminarImprevistoController, bool>(
  EliminarImprevistoController.new,
);
