import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/ficha_persona.dart';

class FichaRepository {
  const FichaRepository(this.sb);
  final SupabaseClient sb;

  Future<List<FichaPersona>> personas(String buscar) async {
    final rows =
        await sb.rpc('rpc_ficha_personas', params: {'p_buscar': buscar.trim()});
    return (rows as List)
        .map((row) => FichaPersona.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }
}
