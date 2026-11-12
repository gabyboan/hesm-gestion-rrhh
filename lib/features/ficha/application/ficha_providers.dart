import '../../../core/cache/session_cache_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../../auth/application/auth_providers.dart';
import '../../licencias/application/licencias_providers.dart';
import '../../licencias/domain/licencia.dart';
import '../data/ficha_repository.dart';
import '../domain/ficha_persona.dart';

final fichaRepoProvider = Provider<FichaRepository>((ref) => FichaRepository(
    ref.watch(supabaseClientProvider),
    cache: ref.watch(sessionDataCacheProvider)));

final puedeLeerFichaProvider = FutureProvider.autoDispose<bool>((ref) async {
  final userId =
      ref.watch(authSessionProvider.select((s) => s.valueOrNull?.user.id));
  if (userId == null) return false;
  return await ref.watch(supabaseClientProvider).rpc('can_ficha_read') == true;
});

final fichaPersonasProvider = FutureProvider.autoDispose
    .family<List<FichaPersona>, String>((ref, buscar) async {
  if (!await ref.watch(puedeLeerFichaProvider.future)) return [];
  return ref.watch(fichaRepoProvider).personas(buscar);
});

typedef FichaConsulta = ({int dni, int anio});

final fichaLicenciasProvider = FutureProvider.autoDispose
    .family<List<LicenciaRegistro>, FichaConsulta>((ref, consulta) async {
  if (!await ref.watch(puedeLeerFichaProvider.future)) return [];
  return ref
      .watch(licenciasRepoProvider)
      .registros(consulta.anio, personaDni: consulta.dni);
});

final fichaLicenciasAcumuladasProvider = FutureProvider.autoDispose
    .family<List<LicenciaRegistro>, int>((ref, dni) async {
  if (!await ref.watch(puedeLeerFichaProvider.future)) return [];
  return ref.watch(licenciasRepoProvider).registrosDesde2026(personaDni: dni);
});
