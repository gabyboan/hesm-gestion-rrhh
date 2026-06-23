import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/imprevisto_persona.dart';
import '../domain/imprevisto_registro.dart';

class ImprevistosRepository {
  final SupabaseClient _sb;

  ImprevistosRepository(this._sb);

  static const _rpcListado = 'rpc_imprevistos_listado';
  static const _rpcRegistros = 'rpc_imprevistos_registros';
  static const _rpcCrear = 'rpc_imprevistos_crear';
  static const _rpcModificar = 'rpc_imprevistos_modificar';
  static const _rpcEliminar = 'rpc_imprevistos_eliminar';

  Future<List<ImprevistoPersona>> listado({
    required int anio,
    String? buscar,
  }) async {
    final res = await _sb.rpc(
      _rpcListado,
      params: {
        'p_anio': anio,
        'p_buscar': buscar,
      },
    );

    return _asRows(res).map(ImprevistoPersona.fromJson).toList();
  }

  Future<List<ImprevistoRegistro>> registros({
    required int dni,
    required int carreraId,
    required int anio,
  }) async {
    final res = await _sb.rpc(
      _rpcRegistros,
      params: {
        'p_dni': dni,
        'p_carrera_id': carreraId,
        'p_anio': anio,
      },
    );

    return _asRows(res).map(ImprevistoRegistro.fromJson).toList();
  }

  Future<void> crear({
    required int dni,
    required int carreraId,
    required DateTime fecha,
    String? observacion,
    int? numeroOrden,
  }) async {
    await _sb.rpc(
      _rpcCrear,
      params: {
        'p_dni': dni,
        'p_carrera_id': carreraId,
        'p_fecha': _toYmd(fecha),
        'p_observacion': observacion,
        'p_numero_orden': numeroOrden,
      },
    );
  }

  Future<bool> modificar({
    required int id,
    required DateTime fecha,
    String? observacion,
    int? numeroOrden,
  }) async {
    final res = await _sb.rpc(
      _rpcModificar,
      params: {
        'p_id': id,
        'p_fecha': _toYmd(fecha),
        'p_observacion': observacion,
        'p_numero_orden': numeroOrden,
      },
    );

    return res == true;
  }

  Future<bool> eliminar({required int id}) async {
    final res = await _sb.rpc(
      _rpcEliminar,
      params: {
        'p_id': id,
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
