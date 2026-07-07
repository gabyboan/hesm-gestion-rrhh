import 'package:supabase_flutter/supabase_flutter.dart';

class SuplenciasRepository {
  SuplenciasRepository(this._sb);

  final SupabaseClient _sb;

  Future<List<Map<String, dynamic>>> listar({
    String buscar = '',
    String ordenarPor = 'id',
    bool ascendente = false,
  }) async {
    dynamic query = _sb.from('vw_suplencias_detalle_servicio').select();
    final texto = buscar.replaceAll(',', ' ').trim();
    if (texto.isNotEmpty) {
      final filtros = <String>[
        'suplente_apellido.ilike.%$texto%',
        'suplente_nombre.ilike.%$texto%',
        'suplente_servicio.ilike.%$texto%',
        'titular_apellido.ilike.%$texto%',
        'titular_nombre.ilike.%$texto%',
        'titular_servicio.ilike.%$texto%',
        'motivo.ilike.%$texto%',
      ];
      final dni = int.tryParse(texto);
      if (dni != null) {
        filtros.addAll(['titular_dni.eq.$dni', 'suplente_dni.eq.$dni']);
      }
      query = query.or(filtros.join(','));
    }
    final response =
        await query.order(ordenarPor, ascending: ascendente).limit(5000);
    return (response as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }
}
