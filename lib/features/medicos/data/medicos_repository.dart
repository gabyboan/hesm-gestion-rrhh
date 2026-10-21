import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/medico_domicilio.dart';
import '../domain/medico_persona.dart';
import '../domain/medico_familiar.dart';
import '../domain/parte_medico.dart';

class MedicosRepository {
  final SupabaseClient _sb;

  MedicosRepository(this._sb);

  Future<List<MedicoPersona>> personas({String? buscar}) async {
    final res = await _sb.rpc(
      'rpc_medicos_personas',
      params: {'p_buscar': buscar},
    );
    return _asRows(res).map(MedicoPersona.fromJson).toList();
  }

  Future<List<ParteMedico>> registros({String? buscar}) async {
    final res = await _sb.rpc(
      'rpc_medicos_registros',
      params: {'p_buscar': buscar},
    );
    return _asRows(res).map(ParteMedico.fromJson).toList();
  }

  Future<List<MedicoFamiliar>> familiares(int dni) async {
    final res = await _sb.rpc(
      'rpc_medicos_familiares',
      params: {'p_dni': dni},
    );
    return _asRows(res).map(MedicoFamiliar.fromJson).toList();
  }

  Future<MedicoDomicilio?> domicilio(int dni) async {
    final res = await _sb.rpc(
      'rpc_medicos_domicilio',
      params: {'p_dni': dni},
    );
    final rows = _asRows(res);
    if (rows.isEmpty) return null;
    if (rows.length > 1) {
      throw StateError(
          'Se recibieron varios domicilios vigentes para la persona.');
    }
    return MedicoDomicilio.fromJson(rows.single);
  }

  Future<int> crear({
    required int dni,
    required TipoParteMedico tipo,
    String? familiarApellidoNombre,
    int? familiarDni,
    int? familiarEdad,
    int? familiarEdadMeses,
    String? familiarParentesco,
    required bool esArt,
    String? aclaracionFechaTurno,
  }) async {
    final res = await _sb.rpc(
      'rpc_medicos_crear',
      params: {
        'p_dni': dni,
        'p_tipo': tipo.dbValue,
        'p_familiar_apellido_nombre': familiarApellidoNombre,
        'p_familiar_dni': familiarDni,
        'p_familiar_edad': familiarEdad,
        // Omitir el parámetro opcional cuando no se usa permite trabajar
        // también con bases que aún tienen la firma anterior de la RPC.
        if (familiarEdadMeses != null)
          'p_familiar_edad_meses': familiarEdadMeses,
        'p_familiar_parentesco': familiarParentesco,
        'p_es_art': esArt,
        'p_aclaracion_fecha_turno': aclaracionFechaTurno,
      },
    );
    if (res is num) return res.toInt();
    throw StateError('No se recibio el identificador del parte medico.');
  }

  Future<bool> anular(int id) async {
    final res = await _sb.rpc('rpc_medicos_anular', params: {'p_id': id});
    return res == true;
  }

  List<Map<String, dynamic>> _asRows(dynamic res) {
    if (res == null) return <Map<String, dynamic>>[];
    if (res is! List) {
      throw StateError('La RPC debia devolver una lista.');
    }
    return res.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }
}
