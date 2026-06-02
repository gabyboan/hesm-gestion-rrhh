import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/franco_movimiento.dart';
import '../domain/franco_persona.dart';

class FrancosRepository {
  final SupabaseClient _sb;

  FrancosRepository(this._sb);

  static const _rpcListado = 'rpc_francos_listado';
  static const _rpcMovimientos = 'rpc_francos_movimientos';
  static const _rpcCrear = 'rpc_francos_crear';
  static const _rpcModificar = 'rpc_francos_modificar';
  static const _rpcEliminar = 'rpc_francos_eliminar';

  Future<List<FrancoPersona>> listado({String? buscar}) async {
    final res = await _sb.rpc(
      _rpcListado,
      params: {
        'p_buscar': buscar,
      },
    );

    return _asRows(res).map(FrancoPersona.fromJson).toList();
  }

  Future<List<FrancoMovimiento>> movimientos({
    required int dni,
    required int carreraId,
  }) async {
    final res = await _sb.rpc(
      _rpcMovimientos,
      params: {
        'p_dni': dni,
        'p_carrera_id': carreraId,
      },
    );

    return _asRows(res).map(FrancoMovimiento.fromJson).toList();
  }

  Future<void> crear({
    required int dni,
    required int carreraId,
    required DateTime fecha,
    required int minutos,
    required String motivo,
    String? observacion,
  }) async {
    await _sb.rpc(
      _rpcCrear,
      params: {
        'p_dni': dni,
        'p_carrera_id': carreraId,
        'p_fecha': _toYmd(fecha),
        'p_minutos': minutos,
        'p_motivo': motivo,
        'p_observacion': observacion,
      },
    );
  }

  Future<void> modificar({
    required int id,
    required DateTime fecha,
    required int minutos,
    required String motivo,
    String? observacion,
  }) async {
    await _sb.rpc(
      _rpcModificar,
      params: {
        'p_id': id,
        'p_fecha': _toYmd(fecha),
        'p_minutos': minutos,
        'p_motivo': motivo,
        'p_observacion': observacion,
      },
    );
  }

  Future<bool> eliminar({
    required int id,
    String? motivo,
  }) async {
    final res = await _sb.rpc(
      _rpcEliminar,
      params: {
        'p_id': id,
        'p_anulacion_motivo': motivo,
      },
    );

    return res == true;
  }

  List<Map<String, dynamic>> _asRows(dynamic res) {
    if (res == null) return <Map<String, dynamic>>[];

    if (res is! List) {
      throw StateError(
        'La RPC debia devolver una lista, pero devolvio: ${res.runtimeType}',
      );
    }

    return res.map((row) {
      if (row is! Map) {
        throw StateError(
          'La RPC debia devolver filas tipo Map, pero devolvio: ${row.runtimeType}',
        );
      }

      return Map<String, dynamic>.from(row);
    }).toList();
  }

  String _toYmd(DateTime d) {
    final year = d.year.toString().padLeft(4, '0');
    final month = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }
}
