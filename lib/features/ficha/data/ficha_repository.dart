import '../../../core/cache/session_data_cache.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/ficha_persona.dart';

class FichaRepository {
  const FichaRepository(this.sb, {this.cache});
  final SessionDataCache? cache;
  Future<T> _cached<T>(Object key, Future<T> Function() load,
          {Duration ttl = const Duration(seconds: 25)}) =>
      cache?.read('ficha', key, load, ttl: ttl) ?? load();
  final SupabaseClient sb;

  Future<List<FichaPersona>> personas(String buscar) => _cached(
      ('personas', buscar.trim().toLowerCase()), () => _personas(buscar));

  Future<List<FichaPersona>> _personas(String buscar) async {
    final rows =
        await sb.rpc('rpc_ficha_personas', params: {'p_buscar': buscar.trim()});
    return (rows as List)
        .map((row) => FichaPersona.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }
}
