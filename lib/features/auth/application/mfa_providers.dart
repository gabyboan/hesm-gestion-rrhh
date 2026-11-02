import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../data/mfa_repository.dart';
import 'auth_providers.dart';

/// La demostración sin conexión no ofrece operaciones de cuenta reales.
final mfaUiEnabledProvider = Provider<bool>((ref) => true);

final mfaRepositoryProvider = Provider<MfaRepository>(
    (ref) => SupabaseMfaRepository(ref.watch(supabaseClientProvider)));

final mfaStatusProvider = FutureProvider.autoDispose<MfaStatus>((ref) {
  final repository = ref.watch(mfaRepositoryProvider);
  // Una renovación ordinaria no debe desmontar módulos ni perder formularios.
  // Reconsultar si cambian cuenta, nivel de verificación o factores conocidos.
  ref.watch(authSessionProvider.select((value) => (
        value.valueOrNull?.user.id,
        repository.sessionVerified,
        value.valueOrNull?.user.factors
                ?.map((factor) => '${factor.id}:${factor.status.name}')
                .join('|') ??
            '',
      )));
  return repository.loadStatus();
});
