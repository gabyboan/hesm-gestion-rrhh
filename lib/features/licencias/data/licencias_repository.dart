import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/licencia.dart';

class LicenciasRepository {
  const LicenciasRepository(this.sb);
  final SupabaseClient sb;

  Future<List<LicenciaTipo>> tipos() async {
    final rows = await sb
        .from('licencias_tipos_excel')
        .select()
        .order('categoria_excel_id', ascending: true)
        .order('codigo', ascending: true);
    return rows.map(LicenciaTipo.fromJson).toList();
  }

  Future<List<LicenciaPersona>> personas(String buscar) async {
    final rows = await sb.rpc('rpc_licencias_personas', params: {
      'p_buscar': buscar.trim(),
    });
    return (rows as List)
        .map((row) => LicenciaPersona.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<List<LicenciaRegistro>> registros(int anio, {int? personaDni}) async {
    if (anio < 2026) throw ArgumentError('Las consultas comienzan en 2026.');
    return _consultarRegistros(anio: anio, personaDni: personaDni);
  }

  Future<List<LicenciaRegistro>> registrosDesde2026(
          {required int personaDni}) =>
      _consultarRegistros(personaDni: personaDni);

  Future<List<LicenciaRegistro>> _consultarRegistros(
      {int? anio, int? personaDni}) async {
    final result = <LicenciaRegistro>[];
    // Supabase limita la respuesta por petición. El informe debe incluir todo.
    const pageSize = 500;
    for (var offset = 0;; offset += pageSize) {
      final rows = await sb.rpc('rpc_licencias_historial', params: {
        'p_anio': anio,
        'p_persona_dni': personaDni,
        'p_offset': offset,
        'p_limite': pageSize,
      }) as List;
      result.addAll(rows.map(
          (row) => LicenciaRegistro.fromJson(Map<String, dynamic>.from(row))));
      if (rows.length < pageSize) break;
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> pendientes() async => await sb
      .from('licencias_importacion_pendientes')
      .select('origen_fila,motivo,datos')
      .order('origen_fila');

  Future<DateTime> hastaEstudio(DateTime desde, int dias) async {
    final fecha = await sb.rpc('rpc_licencias_estudio_hasta', params: {
      'p_desde': _fecha(desde),
      'p_dias': dias,
    });
    return DateTime.parse(fecha as String);
  }

  Future<List<Map<String, dynamic>>> importadasResumen() async {
    final rows = await sb.rpc('rpc_licencias_importadas_resumen');
    return (rows as List).map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> guardar({
    int? id,
    required int dni,
    required int tipoId,
    required DateTime desde,
    required DateTime hasta,
    String? observacion,
    int? dniFamiliar,
    int? numeroOrden,
    String? cantidadFicha,
  }) async {
    await sb.rpc('rpc_licencias_guardar_con_datos', params: {
      'p_id': id,
      'p_dni': dni,
      'p_tipo_id': tipoId,
      'p_desde': _fecha(desde),
      'p_hasta': _fecha(hasta),
      'p_observacion': observacion,
      'p_dni_familiar': dniFamiliar,
      'p_numero_orden': numeroOrden,
      'p_cantidad_ficha': cantidadFicha,
    });
  }

  Future<bool> anular(int id) async =>
      await sb.rpc('rpc_licencias_anular', params: {'p_id': id}) == true;

  static String _fecha(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
