import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../data/suplencias_repository.dart';

final suplenciasRepoProvider = Provider<SuplenciasRepository>((ref) {
  return SuplenciasRepository(ref.watch(supabaseClientProvider));
});

final puedeLeerSuplenciasProvider = FutureProvider<bool>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);

  try {
    final resultado = await supabase.rpc(
      'has_role_code',
      params: const {'p_codigo': 'SUPLENCIAS_LECTURA'},
    );
    if (resultado == true) return true;
  } catch (_) {
    // Compatibilidad con bases donde la RPC aun no fue expuesta.
  }

  // El rol 31 es el permiso de lectura de Suplencias. RLS en usuario_roles
  // garantiza que cada usuario solo pueda encontrar sus propias asignaciones.
  final asignaciones = await supabase
      .from('usuario_roles')
      .select('rol_id')
      .eq('rol_id', 31)
      .limit(1);

  return asignaciones.isNotEmpty;
});
