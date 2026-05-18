import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/persona.dart';
import '../domain/hora_registro.dart';

class HorasRepository {
  final SupabaseClient _sb;
  HorasRepository(this._sb);

  Future<List<Persona>> listadoMes() async {
    final res = await _sb.rpc('rpc_listado_horas_mes');
    final list = (res as List).cast<Map<String, dynamic>>();
    return list.map(Persona.fromListadoJson).toList();
  }

  //es como el anterior pero trae todas las personas activas (para horas oficiales)
  Future<List<Persona>> listadoHorasOficiales() async {
    final res = await _sb.rpc('rpc_listado_horas_oficiales');
    final list = (res as List).cast<Map<String, dynamic>>();
    return list.map(Persona.fromListadoJson).toList();
  }

  /// Registros del mes de UNA persona (ya lo tenías)
  Future<List<HoraRegistro>> registrosMes({
    required int dni,
    required int carreraId,
    required DateTime periodo,
  }) async {
    final res = await _sb.rpc(
      'rpc_horas_registros_mes',
      params: {
        'p_dni': dni,
        'p_carrera_id': carreraId,
        'p_periodo': _toYmd(periodo),
      },
    );

    final list = (res as List).cast<Map<String, dynamic>>();
    return list.map(HoraRegistro.fromJson).toList();
  }

  /// ✅ NUEVO: registros del periodo para TODOS (sin filtrar por persona)
  ///
  /// Requiere que exista en Postgres la función RPC:
  ///   rpc_horas_registros_periodo(p_periodo date)
  ///
  /// Debe devolver las mismas columnas que HoraRegistro.fromJson espera:
  /// id, dni, carrera_id, fecha, periodo, tipo, minutos, minutos_aplicados, minutos_excedidos, excedido
  Future<List<HoraRegistro>> registrosPeriodo({
    required DateTime periodo,
  }) async {
    final res = await _sb.rpc(
      'rpc_horas_registros_periodo',
      params: {'p_periodo': _toYmd(periodo)},
    );

    final list = (res as List).cast<Map<String, dynamic>>();
    return list.map(HoraRegistro.fromJson).toList();
  }

  Future<void> cargarHora({
    required int dni,
    required int carreraId,
    required DateTime fecha,
    required String tipoDb,
    int? minutos,
  }) async {
    await _sb.rpc(
      'rpc_cargar_hora',
      params: {
        'p_dni': dni,
        'p_carrera_id': carreraId,
        'p_fecha': _toYmd(fecha),
        'p_tipo': tipoDb,
        'p_minutos': minutos,
      },
    );
  }

  Future<bool> borrarHora({required int id}) async {
    final res = await _sb.rpc('rpc_borrar_hora', params: {'p_id': id});
    return res == true;
  }

  String _toYmd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
