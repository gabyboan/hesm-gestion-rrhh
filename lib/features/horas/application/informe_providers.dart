// lib/features/horas/application/informe_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/hora_registro.dart';
import '../domain/persona.dart';
import 'horas_providers.dart';

/// ====== INFORME ======
///
/// Construye las filas del informe de horas agrupando registros por persona
/// y carrera.
///
/// Clave de agrupación:
///   dni|carreraId
///
/// Reglas principales:
/// - PARTICULAR: suma minutos aplicados. Si no hay aplicados pero sí excedidos,
///   usa minutos excedidos.
/// - ENFERMEDAD: solo marca el día. No suma minutos.
/// - OFICIAL: suma minutos reales, porque `minutosAplicados` puede venir en 0.
/// - Otros tipos de registros se ignoran.
///
/// Providers:
/// - [informeRowsProvider]: usado por pantalla, respeta filtros.
/// - [informeRowsExportProvider]: usado por exportación, ignora filtros visuales.
enum InformeFiltro {
  soloConUso,
  particulares,
  enfermedad,
  oficiales,
  excedidos,
}

final informeFiltrosProvider = StateProvider<Set<InformeFiltro>>((ref) => {});

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

Map<String, Persona> _personasByKey(Iterable<Persona> personas) {
  return {
    for (final p in personas) p.key: p,
  };
}

class InformeRow {
  final Persona persona;

  /// Día -> minutos particulares.
  final Map<DateTime, int> particularesPorDia;

  /// Día -> marca de enfermedad.
  ///
  /// El valor es siempre 1 porque ENFERMEDAD no consume minutos en el informe.
  /// Solo interesa saber que ese día hubo registro de enfermedad.
  final Map<DateTime, int> enfermedadPorDia;

  /// Día -> minutos oficiales reales.
  final Map<DateTime, int> oficialesPorDia;

  const InformeRow({
    required this.persona,
    required this.particularesPorDia,
    required this.enfermedadPorDia,
    required this.oficialesPorDia,
  });

  bool get tieneParticulares => particularesPorDia.isNotEmpty;

  bool get tieneEnfermedad => enfermedadPorDia.isNotEmpty;

  bool get tieneOficiales => oficialesPorDia.isNotEmpty;

  bool get tieneUso => tieneParticulares || tieneEnfermedad || tieneOficiales;
}

class _Flags {
  bool tienePart = false;
  bool tieneEnf = false;
  bool tieneOfi = false;
  bool tieneExc = false;
}

/// Construye las filas del informe.
///
/// [aplicarFiltros]:
/// - true: respeta los filtros activos de pantalla.
/// - false: ignora filtros. Usado para exportar todo el período.
///
/// Importante:
/// Los filtros se combinan de forma acumulativa.
///
/// Ejemplo:
/// Si están activos `particulares` y `enfermedad`, la persona debe tener ambos
/// tipos para aparecer.
///
/// El filtro `excedidos`, cuando está activo, considera únicamente registros
/// excedidos. No muestra todos los registros de una persona que tuvo al menos
/// un excedente.
List<InformeRow> _buildInforme({
  required List<HoraRegistro> registros,
  required Map<String, Persona> byKey,
  required Set<InformeFiltro> filtros,
  required bool aplicarFiltros,
}) {
  final part = <String, Map<DateTime, int>>{};
  final enf = <String, Map<DateTime, int>>{};
  final ofi = <String, Map<DateTime, int>>{};
  final flags = <String, _Flags>{};

  final filtrarExcedidos =
      aplicarFiltros && filtros.contains(InformeFiltro.excedidos);

  void addMin(
    Map<String, Map<DateTime, int>> bucket,
    String key,
    DateTime d,
    int minutos,
  ) {
    bucket.putIfAbsent(key, () => <DateTime, int>{});
    bucket[key]![d] = (bucket[key]![d] ?? 0) + minutos;
  }

  for (final r in registros) {
    if (filtrarExcedidos && !r.tieneExcedente) {
      continue;
    }

    final key = r.personaKey;
    final d = _day(r.fecha);

    flags.putIfAbsent(key, () => _Flags());

    // ENFERMEDAD:
    // Solo marca fecha. No depende de minutos.
    if (r.esEnfermedad) {
      enf.putIfAbsent(key, () => <DateTime, int>{});
      enf[key]![d] = 1;

      flags[key]!.tieneEnf = true;
      flags[key]!.tieneExc = flags[key]!.tieneExc || r.tieneExcedente;

      continue;
    }

    // PARTICULAR:
    // Prioriza minutos aplicados. Si aplicados es 0 pero hubo excedente,
    // se muestran los minutos excedidos.
    if (r.esParticular) {
      final aplicados = r.minutosAplicados;
      final excedidos = r.minutosExcedidos;
      final minutos =
          aplicados > 0 ? aplicados : (excedidos > 0 ? excedidos : 0);

      if (minutos > 0) {
        addMin(part, key, d, minutos);
        flags[key]!.tienePart = true;
      }

      flags[key]!.tieneExc = flags[key]!.tieneExc || r.tieneExcedente;

      continue;
    }

    // OFICIAL:
    // Usa minutos reales, porque en base de datos `minutosAplicados`
    // suele venir en 0.
    if (r.esOficial) {
      final minutos = r.minutos ?? 0;

      if (minutos > 0) {
        addMin(ofi, key, d, minutos);
        flags[key]!.tieneOfi = true;
      }

      flags[key]!.tieneExc = flags[key]!.tieneExc || r.tieneExcedente;

      continue;
    }

    // Otros tipos: ignorar.
  }

  final out = <InformeRow>[];

  for (final entry in byKey.entries) {
    final key = entry.key;
    final persona = entry.value;

    final row = InformeRow(
      persona: persona,
      particularesPorDia: part[key] ?? <DateTime, int>{},
      enfermedadPorDia: enf[key] ?? <DateTime, int>{},
      oficialesPorDia: ofi[key] ?? <DateTime, int>{},
    );

    final f = flags[key] ?? _Flags();

    if (aplicarFiltros) {
      // Solo con uso:
      // oculta personas sin registros en el período.
      if (filtros.contains(InformeFiltro.soloConUso) && !row.tieneUso) {
        continue;
      }

      // Filtros por tipo:
      // son acumulativos, no alternativos.
      final wantPart = filtros.contains(InformeFiltro.particulares);
      final wantEnf = filtros.contains(InformeFiltro.enfermedad);
      final wantOfi = filtros.contains(InformeFiltro.oficiales);

      if (wantPart && !f.tienePart) continue;
      if (wantEnf && !f.tieneEnf) continue;
      if (wantOfi && !f.tieneOfi) continue;

      // Excedidos:
      // muestra solo personas con al menos un registro excedido considerado.
      if (filtros.contains(InformeFiltro.excedidos) && !f.tieneExc) {
        continue;
      }
    }

    out.add(row);
  }

  // Orden estable del informe:
  // apellido, nombre, dni, carrera.
  out.sort((a, b) {
    final ap = a.persona.apellido
        .toLowerCase()
        .compareTo(b.persona.apellido.toLowerCase());
    if (ap != 0) return ap;

    final no = a.persona.nombre
        .toLowerCase()
        .compareTo(b.persona.nombre.toLowerCase());
    if (no != 0) return no;

    final dn = a.persona.dni.compareTo(b.persona.dni);
    if (dn != 0) return dn;

    return a.persona.carreraId.compareTo(b.persona.carreraId);
  });

  return out;
}

/// Provider para PANTALLA.
///
/// Respeta los filtros activos en [informeFiltrosProvider].
///
/// Se esperan los listados completos para evitar un informe vacío temporal
/// cuando `personasByKeyProvider` todavía no terminó de cargar.
final informeRowsProvider = FutureProvider<List<InformeRow>>((ref) async {
  final registrosFuture = ref.watch(registrosPeriodoProvider.future);
  final normalesFuture = ref.watch(listadoProvider.future);
  final oficialesFuture = ref.watch(listadoOficialesProvider.future);

  final registros = await registrosFuture;
  final filtros = ref.watch(informeFiltrosProvider);

  final normales = await normalesFuture;
  final oficiales = await oficialesFuture;

  final byKey = _personasByKey([
    ...normales,
    ...oficiales,
  ]);

  return _buildInforme(
    registros: registros,
    byKey: byKey,
    filtros: filtros,
    aplicarFiltros: true,
  );
});

/// Provider para EXPORTACIÓN.
///
/// Ignora los filtros visuales activos y devuelve todas las personas
/// correspondientes al período seleccionado.
final informeRowsExportProvider = FutureProvider<List<InformeRow>>((ref) async {
  final registrosFuture = ref.watch(registrosPeriodoProvider.future);
  final normalesFuture = ref.watch(listadoProvider.future);
  final oficialesFuture = ref.watch(listadoOficialesProvider.future);

  final registros = await registrosFuture;
  final normales = await normalesFuture;
  final oficiales = await oficialesFuture;

  final byKey = _personasByKey([
    ...normales,
    ...oficiales,
  ]);

  return _buildInforme(
    registros: registros,
    byKey: byKey,
    filtros: const <InformeFiltro>{},
    aplicarFiltros: false,
  );
});
