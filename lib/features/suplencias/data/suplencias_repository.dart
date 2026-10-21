import 'package:supabase_flutter/supabase_flutter.dart';

class SuplenciasRepository {
  SuplenciasRepository(this._sb);

  final SupabaseClient _sb;

  Future<List<Map<String, dynamic>>> listar({
    String buscar = '',
    String ordenarPor = 'id',
    bool ascendente = false,
  }) async {
    final response = await _sb
        .rpc('rpc_suplencias_listado', params: {'p_buscar': buscar})
        .order(ordenarPor, ascending: ascendente)
        .limit(5000);
    return (response as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }
}
