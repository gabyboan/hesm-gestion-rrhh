// lib/features/horas/application/informe_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/hora_registro.dart';
import '../domain/persona.dart';
import 'horas_providers.dart';

//// ====== INFORME ======

enum InformeFiltro {
  soloConUso,
  particulares,
  enfermedad,
  oficiales,
  excedidos
}

final informeFiltrosProvider = StateProvider<Set<InformeFiltro>>((ref) => {});

String _k(int dni, int carreraId) => '$dni|$carreraId';
DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

class InformeRow {
  final Persona persona;

  /// día -> minutos (por tipo)
  final Map<DateTime, int> particularesPorDia;

  /// enfermedad: solo marca día (valor 1)
  final Map<DateTime, int> enfermedadPorDia;

  /// oficiales: minutos reales por día
  final Map<DateTime, int> oficialesPorDia;

  InformeRow({
    required this.persona,
    required this.particularesPorDia,
    required this.enfermedadPorDia,
    required this.oficialesPorDia,
  });
}

class _Flags {
  bool tienePart = false;
  bool tieneEnf = false;
  bool tieneOfi = false;
  bool tieneExc = false;
}

List<InformeRow> _buildInforme({
  required List<HoraRegistro> registros,
  required Map<String, Persona> byKey,
  required Set<InformeFiltro> filtros,
  required bool ignoreFiltros, // export = true
}) {
  bool allowExcedidos(HoraRegistro r) {
    if (!filtros.contains(InformeFiltro.excedidos)) return true;
    return (r.excedido == true) || ((r.minutosExcedidos ?? 0) > 0);
  }

  final part = <String, Map<DateTime, int>>{};
  final enf = <String, Map<DateTime, int>>{};
  final ofi = <String, Map<DateTime, int>>{};
  final flags = <String, _Flags>{};

  void addMin(
    Map<String, Map<DateTime, int>> bucket,
    String key,
    DateTime d,
    int m,
  ) {
    bucket.putIfAbsent(key, () => <DateTime, int>{});
    bucket[key]![d] = (bucket[key]![d] ?? 0) + m;
  }

  for (final r in registros) {
    if (!ignoreFiltros) {
      if (!allowExcedidos(r)) continue;
    }

    final tipo = (r.tipo ?? '').toUpperCase();
    final key = _k(r.dni, r.carreraId);
    final d = _day(r.fecha);

    flags.putIfAbsent(key, () => _Flags());

    // ✅ ENFERMEDAD: solo fecha (no depende de minutos)
    if (tipo == 'ENFERMEDAD') {
      enf.putIfAbsent(key, () => <DateTime, int>{});
      enf[key]![d] = 1;
      flags[key]!.tieneEnf = true;

      if ((r.excedido == true) || ((r.minutosExcedidos ?? 0) > 0)) {
        flags[key]!.tieneExc = true;
      }
      continue;
    }

    // ✅ PARTICULAR: usar aplicados (o excedidos si aplicados=0 y hubo excedido)
    if (tipo == 'PARTICULAR') {
      final aplicados = (r.minutosAplicados ?? r.minutos ?? 0);
      final exc = (r.minutosExcedidos ?? 0);
      final m = (aplicados > 0) ? aplicados : (exc > 0 ? exc : 0);

      if (m > 0) {
        addMin(part, key, d, m);
        flags[key]!.tienePart = true;
      }

      if ((r.excedido == true) || ((r.minutosExcedidos ?? 0) > 0)) {
        flags[key]!.tieneExc = true;
      }

      continue;
    }

    // ✅ OFICIAL: usar minutos reales (porque en DB minutos_aplicados suele ser 0)
    if (tipo == 'OFICIAL') {
      final m = (r.minutos ?? 0);

      if (m > 0) {
        addMin(ofi, key, d, m);
        flags[key]!.tieneOfi = true;
      }

      if ((r.excedido == true) || ((r.minutosExcedidos ?? 0) > 0)) {
        flags[key]!.tieneExc = true;
      }

      continue;
    }

    // Otros tipos: ignorar
  }

  final out = <InformeRow>[];

  for (final entry in byKey.entries) {
    final key = entry.key;
    final p = entry.value;

    final partDia = part[key] ?? <DateTime, int>{};
    final enfDia = enf[key] ?? <DateTime, int>{};
    final ofiDia = ofi[key] ?? <DateTime, int>{};
    final f = flags[key] ?? _Flags();

    final tieneUso =
        partDia.isNotEmpty || enfDia.isNotEmpty || ofiDia.isNotEmpty;

    if (!ignoreFiltros) {
      // Solo con uso
      if (filtros.contains(InformeFiltro.soloConUso) && !tieneUso) continue;

      // filtros por tipo
      final wantPart = filtros.contains(InformeFiltro.particulares);
      final wantEnf = filtros.contains(InformeFiltro.enfermedad);
      final wantOfi = filtros.contains(InformeFiltro.oficiales);
      if (wantPart && !f.tienePart) continue;
      if (wantEnf && !f.tieneEnf) continue;
      if (wantOfi && !f.tieneOfi) continue;

      // excedidos
      if (filtros.contains(InformeFiltro.excedidos) && !f.tieneExc) continue;
    }

    out.add(
      InformeRow(
        persona: p,
        particularesPorDia: partDia,
        enfermedadPorDia: enfDia,
        oficialesPorDia: ofiDia,
      ),
    );
  }

  // orden: apellido, nombre, dni, carrera
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

/// ✅ Provider para PANTALLA (respeta filtros)
final informeRowsProvider = FutureProvider<List<InformeRow>>((ref) async {
  final registros = await ref.watch(registrosPeriodoProvider.future);
  final byKey = ref.watch(personasByKeyProvider);
  final filtros = ref.watch(informeFiltrosProvider);

  return _buildInforme(
    registros: registros,
    byKey: byKey,
    filtros: filtros,
    ignoreFiltros: false,
  );
});

/// ✅ Provider para EXPORT (ignora filtros y devuelve TODOS siempre)
final informeRowsExportProvider = FutureProvider<List<InformeRow>>((ref) async {
  final registros = await ref.watch(registrosPeriodoProvider.future);

  // ✅ Esperar listados completos (evita valueOrNull vacío)
  final normales = await ref.watch(listadoProvider.future);
  final oficiales = await ref.watch(listadoOficialesProvider.future);

  final byKey = <String, Persona>{
    for (final p in [...normales, ...oficiales]) p.key: p,
  };

  return _buildInforme(
    registros: registros,
    byKey: byKey,
    filtros: const <InformeFiltro>{},
    ignoreFiltros: true,
  );
});
