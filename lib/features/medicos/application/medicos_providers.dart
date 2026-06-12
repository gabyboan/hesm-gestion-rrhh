import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../data/medicos_repository.dart';
import '../domain/medico_persona.dart';
import '../domain/parte_medico.dart';

final medicosRepoProvider = Provider<MedicosRepository>((ref) {
  return MedicosRepository(ref.watch(supabaseClientProvider));
});

final medicosSearchProvider = StateProvider<String>((ref) => '');
final selectedMedicoPersonaProvider = StateProvider<MedicoPersona?>(
  (ref) => null,
);

final puedeLeerMedicosProvider = FutureProvider<bool>((ref) async {
  return await ref.watch(supabaseClientProvider).rpc('can_medicos_read') ==
      true;
});

final puedeCrearMedicosProvider = FutureProvider<bool>((ref) async {
  return await ref.watch(supabaseClientProvider).rpc('can_medicos_create') ==
      true;
});

final puedeAdministrarMedicosProvider = FutureProvider<bool>((ref) async {
  return await ref.watch(supabaseClientProvider).rpc('can_medicos_admin') ==
      true;
});

final medicosPersonasProvider = FutureProvider<List<MedicoPersona>>((ref) {
  if (ref.watch(puedeLeerMedicosProvider).valueOrNull != true) {
    return Future.value(<MedicoPersona>[]);
  }
  final buscar = ref.watch(medicosSearchProvider).trim();
  return ref.watch(medicosRepoProvider).personas(
        buscar: buscar.isEmpty ? null : buscar,
      );
});

final partesMedicosProvider = FutureProvider<List<ParteMedico>>((ref) {
  if (ref.watch(puedeLeerMedicosProvider).valueOrNull != true) {
    return Future.value(<ParteMedico>[]);
  }
  final buscar = ref.watch(medicosSearchProvider).trim();
  return ref.watch(medicosRepoProvider).registros(
        buscar: buscar.isEmpty ? null : buscar,
      );
});

class ParteMedicoFormData {
  final int dni;
  final TipoParteMedico tipo;
  final String? familiarApellidoNombre;
  final int? familiarEdad;
  final String? familiarParentesco;

  const ParteMedicoFormData({
    required this.dni,
    required this.tipo,
    required this.familiarApellidoNombre,
    required this.familiarEdad,
    required this.familiarParentesco,
  });
}

class GuardarParteMedicoController extends AsyncNotifier<int?> {
  @override
  Future<int?> build() async => null;

  Future<int> crear(ParteMedicoFormData data) async {
    state = const AsyncLoading();
    try {
      final id = await ref.read(medicosRepoProvider).crear(
            dni: data.dni,
            tipo: data.tipo,
            familiarApellidoNombre: data.familiarApellidoNombre,
            familiarEdad: data.familiarEdad,
            familiarParentesco: data.familiarParentesco,
          );
      ref.invalidate(partesMedicosProvider);
      state = AsyncData(id);
      return id;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final guardarParteMedicoControllerProvider =
    AsyncNotifierProvider<GuardarParteMedicoController, int?>(
  GuardarParteMedicoController.new,
);

class AnularParteMedicoController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async => false;

  Future<bool> anular(int id) async {
    state = const AsyncLoading();
    try {
      final result = await ref.read(medicosRepoProvider).anular(id);
      ref.invalidate(partesMedicosProvider);
      state = AsyncData(result);
      return result;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final anularParteMedicoControllerProvider =
    AsyncNotifierProvider<AnularParteMedicoController, bool>(
  AnularParteMedicoController.new,
);
