import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_provider.dart';

final gestionSessionRepositoryProvider = Provider<GestionSessionRepository>(
    (ref) => GestionSessionRepository(ref.watch(supabaseClientProvider)));

/// La identidad y el identificador de sesión se obtienen del JWT en el servidor.
class GestionSessionRepository {
  GestionSessionRepository(this._client);
  final SupabaseClient _client;

  Future<bool> acquire() async =>
      await _client.rpc('rpc_gestion_sesion_adquirir') == true;

  Future<bool> renew() async =>
      await _client.rpc('rpc_gestion_sesion_renovar') == true;

  Future<void> release() async {
    await _client.rpc('rpc_gestion_sesion_liberar');
  }
}
