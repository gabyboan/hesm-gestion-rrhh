// lib/features/horas/application/horas_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../../../core/utils/date_fmt.dart';
import '../data/horas_repository.dart';
import '../domain/hora_registro.dart';
import '../domain/persona.dart';
import '../domain/tipo_hora.dart';

/// ====== REPOSITORY ======

final horasRepoProvider = Provider<HorasRepository>((ref) {
  final sb = ref.watch(supabaseClientProvider);
  return HorasRepository(sb);
});

/// ====== LISTADOS DE PERSONAS ======
///
/// [listadoProvider]:
/// Listado mensual principal. Según el comentario original, viene de
/// `vw_listado_horas` y contempla carreras 1 y 3.
///
/// [listadoOficialesProvider]:
/// Listado para horas oficiales. Según el comentario original, contempla
/// carrera 2 y/o lo que devuelva la RPC correspondiente.
///
/// [listadoSegunTipoProvider]:
/// Selector usado por la pantalla de carga. Si el tipo seleccionado es oficial,
/// usa el listado de oficiales; en cualquier otro caso usa el listado principal.

final listadoProvider = FutureProvider<List<Persona>>((ref) async {
  return ref.watch(horasRepoProvider).listadoMes();
});

final listadoOficialesProvider = FutureProvider<List<Persona>>((ref) async {
  return ref.watch(horasRepoProvider).listadoHorasOficiales();
});

final listadoSegunTipoProvider = FutureProvider<List<Persona>>((ref) async {
  final tipo = ref.watch(tipoHoraProvider);

  if (tipo == TipoHora.oficial) {
    return ref.watch(listadoOficialesProvider.future);
  }

  return ref.watch(listadoProvider.future);
});

/// ====== ÍNDICES DE PERSONAS ======
///
/// Índice principal por `dni|carreraId`.
///
/// Es importante usar esta clave compuesta porque una misma persona puede
/// aparecer en más de una carrera. Indexar solo por DNI puede pisar datos.
final personasByKeyProvider = Provider<Map<String, Persona>>((ref) {
  final normales = ref.watch(listadoProvider).valueOrNull ?? <Persona>[];
  final oficiales =
      ref.watch(listadoOficialesProvider).valueOrNull ?? <Persona>[];

  final all = <Persona>[
    ...normales,
    ...oficiales,
  ];

  return {
    for (final p in all) p.key: p,
  };
});

/// Índice opcional por DNI.
///
/// Precaución:
/// Si una persona aparece en varias carreras, este mapa conserva solo una
/// entrada por DNI. La última ocurrencia pisa a las anteriores.
final personasByDniProvider = Provider<Map<int, Persona>>((ref) {
  final all = ref.watch(personasByKeyProvider).values;

  final map = <int, Persona>{};
  for (final p in all) {
    map[p.dni] = p;
  }

  return map;
});

/// ====== ESTADO DE UI ======

final selectedPersonaProvider = StateProvider<Persona?>((ref) => null);

final fechaProvider = StateProvider<DateTime>((ref) => DateTime.now());

final tipoHoraProvider = StateProvider<TipoHora>((ref) => TipoHora.particular);

final minutosProvider = StateProvider<int?>((ref) => null);

/// ====== PERÍODO ======

final periodoProvider = StateProvider<DateTime>(
  (ref) => DateFmt.periodoActual(),
);

/// ====== REGISTROS ======

/// Registros del mes para la persona seleccionada.
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

/// Registros del período seleccionado para todas las personas.
final registrosPeriodoProvider =
    FutureProvider<List<HoraRegistro>>((ref) async {
  final periodo = ref.watch(periodoProvider);

  return ref.watch(horasRepoProvider).registrosPeriodo(periodo: periodo);
});

final periodosConRegistrosProvider = FutureProvider<Set<DateTime>>((ref) {
  return ref.watch(horasRepoProvider).periodosConRegistros();
});

/// ====== BUSCADOR Y ORDEN ======

final searchProvider = StateProvider<String>((ref) => '');

enum OrdenHoras {
  dni,
  apellido,
  carrera,
}

final ordenProvider = StateProvider<OrdenHoras>((ref) => OrdenHoras.apellido);

final ordenAscProvider = StateProvider<bool>((ref) => true);

String _personaKeyFromRegistro(HoraRegistro r) => '${r.dni}|${r.carreraId}';

bool _containsCI(String source, String query) {
  return source.toLowerCase().contains(query.toLowerCase());
}

int _cmpInt(int a, int b) => a.compareTo(b);

int _cmpStr(String a, String b) {
  return a.toLowerCase().compareTo(b.toLowerCase());
}

/// Registros filtrados por búsqueda y ordenados según la opción activa.
///
/// La búsqueda compara contra:
/// - DNI.
/// - Apellido.
/// - Nombre.
/// - Carrera ID.
///
/// Para obtener apellido y nombre se usa [personasByKeyProvider], no DNI solo,
/// para evitar errores cuando una persona aparece en más de una carrera.
final registrosFiltradosProvider =
    Provider<AsyncValue<List<HoraRegistro>>>((ref) {
  final registrosAsync = ref.watch(registrosPeriodoProvider);
  final byKey = ref.watch(personasByKeyProvider);

  final q = ref.watch(searchProvider).trim().toLowerCase();
  final orden = ref.watch(ordenProvider);
  final asc = ref.watch(ordenAscProvider);

  Persona? personaDe(HoraRegistro r) => byKey[_personaKeyFromRegistro(r)];

  int compare(HoraRegistro a, HoraRegistro b) {
    final pa = personaDe(a);
    final pb = personaDe(b);

    switch (orden) {
      case OrdenHoras.dni:
        return _cmpInt(a.dni, b.dni);

      case OrdenHoras.carrera:
        final carrera = _cmpInt(a.carreraId, b.carreraId);
        if (carrera != 0) return carrera;

        return _cmpInt(a.dni, b.dni);

      case OrdenHoras.apellido:
        final apellidoA = pa?.apellido ?? '';
        final apellidoB = pb?.apellido ?? '';
        final apellido = _cmpStr(apellidoA, apellidoB);
        if (apellido != 0) return apellido;

        return _cmpInt(a.dni, b.dni);
    }
  }

  return registrosAsync.whenData((rows) {
    final out = <HoraRegistro>[];

    for (final r in rows) {
      final p = personaDe(r);
      final apellido = p?.apellido ?? '';
      final nombre = p?.nombre ?? '';

      if (q.isNotEmpty) {
        final matches = r.dni.toString().contains(q) ||
            _containsCI(apellido, q) ||
            _containsCI(nombre, q) ||
            r.carreraId.toString().contains(q);

        if (!matches) continue;
      }

      out.add(r);
    }

    out.sort((a, b) => asc ? compare(a, b) : compare(b, a));

    return out;
  });
});

/// ====== INVALIDACIONES ======

void _invalidateListados(Ref ref) {
  ref.invalidate(listadoProvider);
  ref.invalidate(listadoOficialesProvider);
  ref.invalidate(listadoSegunTipoProvider);
}

void _invalidateRegistros(Ref ref) {
  ref.invalidate(registrosProvider);
  ref.invalidate(registrosPeriodoProvider);
  ref.invalidate(periodosConRegistrosProvider);
}

/// ====== CARGA DE HORAS ======

class CargarHoraController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> submit() async {
    final persona = ref.read(selectedPersonaProvider);
    if (persona == null) {
      throw Exception('Seleccioná una persona');
    }

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

    _invalidateListados(ref);
    _invalidateRegistros(ref);
  }
}

final cargarHoraControllerProvider =
    AsyncNotifierProvider<CargarHoraController, void>(CargarHoraController.new);

/// ====== BORRADO DE HORAS ======

class BorrarHoraController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async => false;

  Future<bool> borrar(int id) async {
    state = const AsyncLoading();

    try {
      final ok = await ref.read(horasRepoProvider).borrarHora(id: id);

      state = AsyncData(ok);

      _invalidateRegistros(ref);

      return ok;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final borrarHoraControllerProvider =
    AsyncNotifierProvider<BorrarHoraController, bool>(BorrarHoraController.new);
