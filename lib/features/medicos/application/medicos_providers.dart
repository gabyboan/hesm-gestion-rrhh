import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../data/medicos_repository.dart';
import '../domain/medico_domicilio.dart';
import '../domain/medico_familiar.dart';
import '../domain/medico_persona.dart';
import '../domain/parte_medico.dart';

final medicosRepoProvider = Provider<MedicosRepository>((ref) {
  return MedicosRepository(ref.watch(supabaseClientProvider));
});

final medicosSearchProvider = StateProvider<String>((ref) => '');
final partesMedicosSearchProvider = StateProvider<String>((ref) => '');
// Coincide con la fecha de emisión del servidor en Buenos Aires (UTC-3).
final medicosHoyProvider = Provider.autoDispose<DateTime>((ref) {
  final ahoraUtc = DateTime.now().toUtc();
  final ahora = ahoraUtc.subtract(const Duration(hours: 3));
  final siguienteDia = DateTime.utc(ahora.year, ahora.month, ahora.day + 1, 3);
  final timer = Timer(siguienteDia.difference(ahoraUtc), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return DateTime(ahora.year, ahora.month, ahora.day);
});

// null sigue el día de hoy, incluso si la pantalla queda abierta a medianoche.
final partesMedicosFechaElegidaProvider =
    StateProvider.autoDispose<DateTime?>((ref) => null);
final partesMedicosFechaProvider = Provider.autoDispose<DateTime>((ref) {
  return ref.watch(partesMedicosFechaElegidaProvider) ??
      ref.watch(medicosHoyProvider);
});
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

final puedeControlarMedicosProvider = FutureProvider<bool>((ref) async {
  return await ref.watch(supabaseClientProvider).rpc('can_medicos_control') ==
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

final partesMedicosProvider =
    FutureProvider.autoDispose<List<ParteMedico>>((ref) {
  if (ref.watch(puedeLeerMedicosProvider).valueOrNull != true) {
    return Future.value(<ParteMedico>[]);
  }
  final buscar = ref.watch(partesMedicosSearchProvider).trim();
  return ref.watch(medicosRepoProvider).registros(
        buscar: buscar.isEmpty ? null : buscar,
        fecha: ref.watch(partesMedicosFechaProvider),
      );
});

final partesMedicosPorDiaProvider =
    Provider.autoDispose<AsyncValue<List<ParteMedico>>>((ref) {
  final fecha = ref.watch(partesMedicosFechaProvider);
  return ref.watch(partesMedicosProvider).whenData((partes) {
    // Evita mostrar datos del día anterior mientras se actualiza la consulta.
    return partes
        .where((parte) =>
            parte.fecha.year == fecha.year &&
            parte.fecha.month == fecha.month &&
            parte.fecha.day == fecha.day)
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
  });
});

final medicosFamiliaresProvider =
    FutureProvider.family<List<MedicoFamiliar>, int>((ref, dni) {
  if (ref.watch(puedeLeerMedicosProvider).valueOrNull != true) {
    return Future.value(<MedicoFamiliar>[]);
  }
  return ref.watch(medicosRepoProvider).familiares(dni);
});

final medicosDomicilioProvider =
    FutureProvider.family<MedicoDomicilio?, int>((ref, dni) {
  if (ref.watch(puedeLeerMedicosProvider).valueOrNull != true) {
    return Future.value(null);
  }
  return ref.watch(medicosRepoProvider).domicilio(dni);
});

class ParteMedicoFormData {
  final int dni;
  final DateTime fecha;
  final TipoParteMedico tipo;
  final String? familiarApellidoNombre;
  final int? familiarDni;
  final int? familiarEdad;
  final int? familiarEdadMeses;
  final String? familiarParentesco;
  final bool esArt;
  final MedicoDomicilio? domicilio;
  final String? aclaracionFechaTurno;

  const ParteMedicoFormData({
    required this.dni,
    required this.fecha,
    required this.tipo,
    required this.familiarApellidoNombre,
    required this.familiarDni,
    required this.familiarEdad,
    this.familiarEdadMeses,
    required this.familiarParentesco,
    required this.esArt,
    required this.domicilio,
    required this.aclaracionFechaTurno,
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
            familiarDni: data.familiarDni,
            familiarEdad: data.familiarEdad,
            familiarEdadMeses: data.familiarEdadMeses,
            familiarParentesco: data.familiarParentesco,
            esArt: data.esArt,
            aclaracionFechaTurno: data.aclaracionFechaTurno,
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
