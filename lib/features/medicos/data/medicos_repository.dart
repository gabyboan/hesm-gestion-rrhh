import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/medico_domicilio.dart';
import '../domain/medico_persona.dart';
import '../domain/medico_familiar.dart';
import '../domain/parte_medico.dart';
import '../domain/parte_medico_qr.dart';
import '../domain/control_parte_medico.dart';
import '../../../core/utils/date_fmt.dart';

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

  Future<List<ParteMedico>> registros({String? buscar, DateTime? fecha}) async {
    final res = await _sb.rpc(
      fecha == null ? 'rpc_medicos_registros' : 'rpc_medicos_registros_dia',
      params: {
        'p_buscar': buscar,
        if (fecha != null) 'p_fecha': DateFmt.yyyymmdd(fecha),
      },
    );
    final partes = _asRows(res).map(ParteMedico.fromJson).toList();
    if (partes.isEmpty) return partes;
    // La pertenencia se consulta en la ficha; nunca se deduce del tipo AD/AC/PC.
    final carreras = await _sb.rpc('rpc_medicos_carreras', params: {
      'p_dnis': partes.map((p) => p.dni).toSet().toList(),
    });
    final porDni = {
      for (final row in _asRows(carreras)) row['dni'].toString(): row
    };
    return partes.map((parte) {
      final carrera = porDni[parte.dni.toString()];
      return parte.conCarrera(
          nombre: carrera?['carrera_nombre']?.toString(),
          esEnfermeria: carrera?['es_enfermeria'] == true);
    }).toList();
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

  Future<DocumentoParteMedico> documento({int? id, String? codigo}) async {
    if ((id == null) == (codigo == null)) {
      throw ArgumentError('Indicá el número de parte o su código.');
    }
    final res = await _sb.rpc('rpc_medicos_documento', params: {
      if (id != null) 'p_id': id,
      if (codigo != null) 'p_codigo': ParteMedicoQr.parse(codigo).codigo,
    });
    return DocumentoParteMedico.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<ControlParteMedico> guardarControl({
    required ParteMedicoQr qr,
    required DateTime fechaDesde,
    required int diasAprobados,
    required String medicoNombre,
    required String medicoMatricula,
    required int versionEsperada,
    String? motivoRectificacion,
  }) async {
    final res = await _sb.rpc('rpc_medicos_control_guardar', params: {
      'p_codigo': qr.codigo,
      'p_fecha_desde': DateFmt.yyyymmdd(fechaDesde),
      'p_dias_aprobados': diasAprobados,
      'p_medico_nombre': medicoNombre.trim(),
      'p_medico_matricula': medicoMatricula.trim(),
      'p_version_esperada': versionEsperada,
      'p_motivo_rectificacion': motivoRectificacion?.trim(),
    });
    return ControlParteMedico.fromJson(Map<String, dynamic>.from(res as Map));
  }

  List<Map<String, dynamic>> _asRows(dynamic res) {
    if (res == null) return <Map<String, dynamic>>[];
    if (res is! List) {
      throw StateError('La RPC debia devolver una lista.');
    }
    return res.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }
}
