import '../../../core/cache/session_cache_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../../auth/application/auth_providers.dart';
import '../data/licencias_repository.dart';
import '../domain/licencia.dart';

class LicenciasPermisos {
  const LicenciasPermisos(
      {this.leer = false, this.cargar = false, this.administrar = false});
  final bool leer;
  final bool cargar;
  final bool administrar;
}

final licenciasRepoProvider = Provider<LicenciasRepository>((ref) {
  return LicenciasRepository(ref.watch(supabaseClientProvider),
      cache: ref.watch(sessionDataCacheProvider));
});

final licenciasPermisosProvider =
    FutureProvider.autoDispose<LicenciasPermisos>((ref) async {
  final userId =
      ref.watch(authSessionProvider.select((s) => s.valueOrNull?.user.id));
  if (userId == null) return const LicenciasPermisos();
  final sb = ref.watch(supabaseClientProvider);
  final result = await Future.wait([
    sb.rpc('can_licencias_read'),
    sb.rpc('can_licencias_create'),
    sb.rpc('can_licencias_admin'),
  ]);
  return LicenciasPermisos(
    leer: result[0] == true,
    cargar: result[1] == true,
    administrar: result[2] == true,
  );
});

final licenciasAnioProvider =
    StateProvider.autoDispose<int>((ref) => DateTime.now().year);
final licenciasRegistrosProvider =
    FutureProvider.autoDispose<List<LicenciaRegistro>>((ref) async {
  final permisos = await ref.watch(licenciasPermisosProvider.future);
  final anio = ref.watch(licenciasAnioProvider);
  if (!permisos.leer) return [];
  return ref.watch(licenciasRepoProvider).registros(anio);
});
final licenciasTiposProvider =
    FutureProvider.autoDispose<List<LicenciaTipo>>((ref) async {
  if (!(await ref.watch(licenciasPermisosProvider.future)).leer) return [];
  return ref.watch(licenciasRepoProvider).tipos();
});

typedef LicenciaEstudioCalculo = ({DateTime desde, int dias});
final licenciasEstudioHastaProvider = FutureProvider.autoDispose
    .family<DateTime, LicenciaEstudioCalculo>((ref, calculo) => ref
        .watch(licenciasRepoProvider)
        .hastaEstudio(calculo.desde, calculo.dias));
final licenciasPersonasProvider = FutureProvider.autoDispose
    .family<List<LicenciaPersona>, String>((ref, buscar) async {
  if (!(await ref.watch(licenciasPermisosProvider.future)).leer) return [];
  return ref.watch(licenciasRepoProvider).personas(buscar);
});
final licenciasPendientesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  if (!(await ref.watch(licenciasPermisosProvider.future)).administrar) {
    return [];
  }
  return ref.watch(licenciasRepoProvider).pendientes();
});

final licenciasImportadasResumenProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  if (!(await ref.watch(licenciasPermisosProvider.future)).administrar) {
    return [];
  }
  return ref.watch(licenciasRepoProvider).importadasResumen();
});
