import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';

class CurrentRoles {
  final Set<String> codes;

  const CurrentRoles(this.codes);

  bool has(String code) => codes.contains(code);

  bool any(Iterable<String> values) => values.any(has);
}

final currentRolesProvider = FutureProvider<CurrentRoles>((ref) async {
  final sb = ref.watch(supabaseClientProvider);
  final userId = sb.auth.currentUser?.id;

  if (userId == null) {
    return const CurrentRoles(<String>{});
  }

  final res = await sb
      .from('vw_usuario_roles')
      .select('rol')
      .eq('usuario_id', userId);

  final codes = <String>{};

  for (final row in res) {
    final role = row['rol'];
    if (role != null) {
      codes.add(role.toString().trim());
    }
  }

  return CurrentRoles(codes);
});
