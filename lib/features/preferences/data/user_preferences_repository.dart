import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/current_user_profile.dart';
import '../domain/user_preferences.dart';

class UserPreferencesRepository {
  final SupabaseClient _sb;

  UserPreferencesRepository(this._sb);

  Future<UserPreferences> fetch(String userId) async {
    final row = await _sb
        .from('usuario_preferencias')
        .select('tema, inactividad_minutos')
        .eq('usuario_id', userId)
        .maybeSingle();

    if (row == null) return UserPreferences.defaults;

    return UserPreferences.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> save({
    required String userId,
    required UserPreferences preferences,
  }) async {
    final normalized = preferences.normalized;

    await _sb.from('usuario_preferencias').upsert(
      {
        'usuario_id': userId,
        'tema': normalized.databaseTheme,
        'inactividad_minutos': normalized.idleMinutes,
      },
      onConflict: 'usuario_id',
    );
  }

  Future<CurrentUserProfile?> fetchCurrentProfile() async {
    final result = await _sb.rpc('rpc_mi_perfil');

    if (result is! List || result.isEmpty) return null;

    final firstRow = result.first;
    if (firstRow is! Map) return null;

    return CurrentUserProfile.fromJson(Map<String, dynamic>.from(firstRow));
  }
}
