import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../../../core/utils/date_fmt.dart';
import '../data/horas_repository.dart';
import '../domain/persona.dart';
import '../domain/hora_registro.dart';
import '../domain/tipo_hora.dart';

final horasRepoProvider = Provider<HorasRepository>((ref) {
  final sb = ref.watch(supabaseClientProvider);
  return HorasRepository(sb);
});

/// Personas (listado del mes)  -> viene de vw_listado_horas (carreras 1 y 3)
final listadoProvider = FutureProvider<List<Persona>>((ref) async {
  return ref.watch(horasRepoProvider).listadoMes();
});

/// Personas (listado HORAS OFICIALES) -> carrera 2 (y/o todas según tu RPC)
final listadoOficialesProvider = FutureProvider<List<Persona>>((ref) async {
  return ref.watch(horasRepoProvider).listadoHorasOficiales();
});

/// Selector de listado según tipo (para CargarHorasPage)
final listadoSegunTipoProvider = FutureProvider<List<Persona>>((ref) async {
  final tipo = ref.watch(tipoHoraProvider);
  if (tipo == TipoHora.oficial) {
    return ref.watch(listadoOficialesProvider.future);
  }
  return ref.watch(listadoProvider.future);
});

/// ✅ NUEVO (CORRECTO): index por key (dni|carreraId) incluyendo normales + oficiales
final personasByKeyProvider = Provider<Map<String, Persona>>((ref) {
  final normales = ref.watch(listadoProvider).valueOrNull ?? <Persona>[];
  final oficiales =
      ref.watch(listadoOficialesProvider).valueOrNull ?? <Persona>[];

  final all = <Persona>[
    ...normales,
    ...oficiales,
  ];

  return {for (final p in all) p.key: p};
});

/// (opcional) Mantengo tu dni->Persona por si lo usa otra pantalla.
/// ⚠️ Ojo: si una persona está en varias carreras, este map pisa.
final personasByDniProvider = Provider<Map<int, Persona>>((ref) {
  final all = ref.watch(personasByKeyProvider).values.toList();
  final map = <int, Persona>{};
  for (final p in all) {
    map[p.dni] = p;
  }
  return map;
});

/// UI state
final selectedPersonaProvider = StateProvider<Persona?>((ref) => null);
final fechaProvider = StateProvider<DateTime>((ref) => DateTime.now());
final tipoHoraProvider = StateProvider<TipoHora>((ref) => TipoHora.particular);
final minutosProvider = StateProvider<int?>((ref) => null);

/// Periodo
final periodoProvider = StateProvider<DateTime>(
  (ref) => DateFmt.periodoActual(),
);

/// Registros del mes de UNA persona
final registrosProvider = FutureProvider<List<HoraRegistro>>((ref) async {
  final persona = ref.watch(selectedPersonaProvider);
  final periodo = ref.watch(periodoProvider);
  if (persona == null) return [];

  return ref.watch(horasRepoProvider).registrosMes(
        dni: persona.dni,
        carreraId: persona.carreraId,
        periodo: periodo,
      );
});

/// Registros del periodo para TODOS
final registrosPeriodoProvider =
    FutureProvider<List<HoraRegistro>>((ref) async {
  final periodo = ref.watch(periodoProvider);
  return ref.watch(horasRepoProvider).registrosPeriodo(periodo: periodo);
});

/// ====== Buscador + ORDEN ======
final searchProvider = StateProvider<String>((ref) => '');

enum OrdenHoras { dni, apellido, carrera }

final ordenProvider = StateProvider<OrdenHoras>((ref) => OrdenHoras.apellido);
final ordenAscProvider = StateProvider<bool>((ref) => true);

final registrosFiltradosProvider =
    Provider<AsyncValue<List<HoraRegistro>>>((ref) {
  final registrosAsync = ref.watch(registrosPeriodoProvider);

  // ✅ cambiamos a byKey
  final byKey = ref.watch(personasByKeyProvider);

  final q = ref.watch(searchProvider).trim().toLowerCase();
  final orden = ref.watch(ordenProvider);
  final asc = ref.watch(ordenAscProvider);

  bool containsCI(String a, String b) =>
      a.toLowerCase().contains(b.toLowerCase());

  int cmpInt(int a, int b) => a.compareTo(b);
  int cmpStr(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());

  Persona? personaDe(HoraRegistro r) => byKey['${r.dni}|${r.carreraId}'];

  int compare(HoraRegistro a, HoraRegistro b) {
    final pa = personaDe(a);
    final pb = personaDe(b);

    switch (orden) {
      case OrdenHoras.dni:
        return cmpInt(a.dni, b.dni);

      case OrdenHoras.carrera:
        final c = cmpInt(a.carreraId, b.carreraId);
        return c != 0 ? c : cmpInt(a.dni, b.dni);

      case OrdenHoras.apellido:
        final aa = (pa?.apellido ?? '');
        final ab = (pb?.apellido ?? '');
        final c = cmpStr(aa, ab);
        return c != 0 ? c : cmpInt(a.dni, b.dni);
    }
  }

  return registrosAsync.whenData((rows) {
    final out = <HoraRegistro>[];

    for (final r in rows) {
      final p = personaDe(r);
      final apellido = (p?.apellido ?? '');
      final nombre = (p?.nombre ?? '');

      if (q.isNotEmpty) {
        final ok = r.dni.toString().contains(q) ||
            containsCI(apellido, q) ||
            containsCI(nombre, q) ||
            r.carreraId.toString().contains(q);
        if (!ok) continue;
      }

      out.add(r);
    }

    out.sort((a, b) => asc ? compare(a, b) : compare(b, a));
    return out;
  });
});

class CargarHoraController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> submit() async {
    final persona = ref.read(selectedPersonaProvider);
    if (persona == null) throw Exception('Seleccioná una persona');

    final fecha = ref.read(fechaProvider);
    final tipo = ref.read(tipoHoraProvider);
    final minutos = ref.read(minutosProvider);

    if (tipo.requiereMinutos && minutos == null) {
      throw Exception('Seleccioná minutos');
    }

    await ref.read(horasRepoProvider).cargarHora(
          dni: persona.dni,
          carreraId: persona.carreraId,
          fecha: fecha,
          tipoDb: tipo.db,
          minutos: tipo.requiereMinutos ? minutos : null,
        );

    ref.read(minutosProvider.notifier).state = null;

    ref.invalidate(listadoProvider);
    ref.invalidate(listadoOficialesProvider);
    ref.invalidate(listadoSegunTipoProvider);

    ref.invalidate(registrosProvider);
    ref.invalidate(registrosPeriodoProvider);
  }
}

final cargarHoraControllerProvider =
    AsyncNotifierProvider<CargarHoraController, void>(CargarHoraController.new);

class BorrarHoraController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async => false;

  Future<bool> borrar(int id) async {
    state = const AsyncLoading();
    try {
      final ok = await ref.read(horasRepoProvider).borrarHora(id: id);
      state = AsyncData(ok);

      ref.invalidate(registrosProvider);
      ref.invalidate(registrosPeriodoProvider);

      return ok;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final borrarHoraControllerProvider =
    AsyncNotifierProvider<BorrarHoraController, bool>(BorrarHoraController.new);
