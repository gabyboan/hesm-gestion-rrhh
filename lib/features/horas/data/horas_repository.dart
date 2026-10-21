// lib/features/horas/data/horas_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/hora_registro.dart';
import '../domain/persona.dart';

/// Repositorio de horas.
///
/// Encapsula las llamadas RPC a Supabase relacionadas con:
/// - listados de personas;
/// - registros de horas;
/// - carga de horas;
/// - borrado de horas.
///
/// La UI y los providers no deberían conocer los nombres concretos de las RPC.
class HorasRepository {
  final SupabaseClient _sb;

  HorasRepository(this._sb);

  static const _rpcListadoHorasMes = 'rpc_listado_horas_mes';
  static const _rpcListadoHorasOficiales =
      'rpc_listado_horas_oficiales_activas';
  static const _rpcHorasRegistrosMes = 'rpc_horas_registros_mes';
  static const _rpcHorasRegistrosPeriodo = 'rpc_horas_registros_periodo';
  static const _rpcCargarHora = 'rpc_cargar_hora';
  static const _rpcBorrarHora = 'rpc_borrar_hora';

  /// Listado mensual principal.
  ///
  /// Según la estructura actual del sistema, esta RPC trae el listado usado
  /// para horas comunes/particulares.
  Future<List<Persona>> listadoMes() async {
    final res = await _sb.rpc(_rpcListadoHorasMes);
    final rows = _asRows(res);

    return rows.map(Persona.fromListadoJson).toList();
  }

  /// Listado de personas disponibles para horas oficiales.
  ///
  /// Incluye a toda persona activa con una carrera asignada. La exclusión de
  /// bajas (jubilación, renuncia, fallecimiento, etc.) se resuelve en la RPC
  /// `rpc_listado_horas_oficiales_activas` en Postgres.
  Future<List<Persona>> listadoHorasOficiales() async {
    final res = await _sb.rpc(_rpcListadoHorasOficiales);
    final rows = _asRows(res);

    return rows.map(Persona.fromListadoJson).toList();
  }

  /// Registros del mes/período para una persona y carrera.
  ///
  /// La combinación DNI + carrera es necesaria porque una misma persona puede
  /// estar asociada a más de una carrera.
  Future<List<HoraRegistro>> registrosMes({
    required int dni,
    required int carreraId,
    required DateTime periodo,
  }) async {
    final res = await _sb.rpc(
      _rpcHorasRegistrosMes,
      params: {
        'p_dni': dni,
        'p_carrera_id': carreraId,
        'p_periodo': _toYmd(periodo),
      },
    );

    final rows = await _completarUsuarioCarga(_asRows(res));

    return rows.map(HoraRegistro.fromJson).toList();
  }

  /// Registros del período para todas las personas.
  ///
  /// Requiere que exista en Postgres la función:
  ///
  /// ```sql
  /// rpc_horas_registros_periodo(p_periodo date)
  /// ```
  ///
  /// La RPC debe devolver las columnas esperadas por
  /// [HoraRegistro.fromJson], por ejemplo:
  ///
  /// - id
  /// - dni
  /// - carrera_id
  /// - fecha
  /// - periodo
  /// - tipo
  /// - minutos
  /// - minutos_aplicados
  /// - minutos_excedidos
  /// - excedido
  Future<List<HoraRegistro>> registrosPeriodo({
    required DateTime periodo,
  }) async {
    final res = await _sb.rpc(
      _rpcHorasRegistrosPeriodo,
      params: {
        'p_periodo': _toYmd(periodo),
      },
    );

    final rows = await _completarUsuarioCarga(_asRows(res));

    return rows.map(HoraRegistro.fromJson).toList();
  }

  /// Periodos con registros cargados.
  ///
  /// Se usa para mostrar meses sin datos deshabilitados, sin ocultar huecos
  /// entre meses cargados.
  Future<Set<DateTime>> periodosConRegistros() async {
    final res = await _sb
        .from('horas_registros')
        .select('periodo')
        .order('periodo', ascending: false);

    final rows = _asRows(res);

    return {
      for (final row in rows)
        _monthStart(_asDate(row['periodo'], field: 'periodo')),
    };
  }

  /// Carga un registro de hora.
  ///
  /// [tipoDb] debe coincidir con el valor esperado por la RPC/Postgres.
  ///
  /// [minutos] puede ser `null` para tipos que no consumen minutos, por ejemplo
  /// enfermedad, si así está definido en la lógica de base de datos.
  Future<void> cargarHora({
    required int dni,
    required int carreraId,
    required DateTime fecha,
    required String tipoDb,
    int? minutos,
  }) async {
    await _sb.rpc(
      _rpcCargarHora,
      params: {
        'p_dni': dni,
        'p_carrera_id': carreraId,
        'p_fecha': _toYmd(fecha),
        'p_tipo': tipoDb,
        'p_minutos': minutos,
      },
    );
  }

  /// Borra un registro de hora por ID.
  ///
  /// Devuelve `true` solo si la RPC confirma explícitamente el borrado.
  Future<bool> borrarHora({required int id}) async {
    final res = await _sb.rpc(
      _rpcBorrarHora,
      params: {
        'p_id': id,
      },
    );

    return res == true;
  }

  Future<List<Map<String, dynamic>>> _completarUsuarioCarga(
    List<Map<String, dynamic>> rows,
  ) async {
    final ids = <String>{};
    for (final row in rows) {
      if ((row['usuario_carga_nombre'] ?? '').toString().trim().isNotEmpty &&
          (row['usuario_carga_apellido'] ?? '').toString().trim().isNotEmpty) {
        continue;
      }
      final key = _normalizarClave(row['usuario_carga']);
      if (key.isNotEmpty) ids.add(key);
    }

    if (ids.isEmpty) return rows;

    final lookup = <String, ({String nombre, String apellido})>{};
    final List<Map<String, dynamic>> profileRows;
    try {
      final values = ids.join(',');
      profileRows = _asRows(
        await _sb
            .from('usuarios')
            .select('id, auth_user_id, nombre, apellido')
            .or('id.in.($values),auth_user_id.in.($values)'),
      );
    } on PostgrestException catch (error) {
      // La autoria es complementaria: un rol sin acceso a perfiles debe
      // conservar los registros que la RPC ya le permitio consultar.
      if (error.code != '42501') rethrow;
      return rows;
    }

    for (final profile in profileRows) {
      final nombre = (profile['nombre'] ?? '').toString().trim();
      final apellido = (profile['apellido'] ?? '').toString().trim();
      final identityKeys = <String>{
        _normalizarClave(profile['auth_user_id']),
        _normalizarClave(profile['id']),
      }..removeWhere((key) => key.isEmpty);

      for (final key in identityKeys) {
        lookup[key] = (nombre: nombre, apellido: apellido);
      }
    }

    for (final row in rows) {
      final raw = row['usuario_carga'];
      final key = _normalizarClave(raw);
      if (key.isEmpty) continue;

      final user = lookup[key];
      if (user == null) continue;

      if ((row['usuario_carga_nombre'] ?? '').toString().trim().isEmpty) {
        row['usuario_carga_nombre'] = user.nombre;
      }
      if ((row['usuario_carga_apellido'] ?? '').toString().trim().isEmpty) {
        row['usuario_carga_apellido'] = user.apellido;
      }
    }

    return rows;
  }

  static String _normalizarClave(dynamic value) {
    var text = (value ?? '').toString().trim().toLowerCase();
    if (text.isEmpty) return '';

    text = text
        .replaceAll('{', '')
        .replaceAll('}', '')
        .replaceAll('"', '')
        .replaceAll("'", '')
        .replaceFirst(RegExp(r'^uuid\s*'), '')
        .replaceAll('-', '')
        .trim();

    // Solo UUID canonicos en el filtro PostgREST; no interpolar texto arbitrario.
    if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(text)) return '';
    return '${text.substring(0, 8)}-${text.substring(8, 12)}-'
        '${text.substring(12, 16)}-${text.substring(16, 20)}-'
        '${text.substring(20)}';
  }

  /// Convierte una respuesta RPC de Supabase en una lista de mapas tipados.
  ///
  /// Supabase devuelve `dynamic`, por lo que centralizar la conversión evita
  /// repetir casts inseguros en cada método.
  List<Map<String, dynamic>> _asRows(dynamic res) {
    if (res == null) {
      return <Map<String, dynamic>>[];
    }

    if (res is! List) {
      throw StateError(
        'La RPC debía devolver una lista, pero devolvió: ${res.runtimeType}',
      );
    }

    return res.map((row) {
      if (row is! Map) {
        throw StateError(
          'La RPC debía devolver filas tipo Map, pero devolvió: ${row.runtimeType}',
        );
      }

      return Map<String, dynamic>.from(row);
    }).toList();
  }

  /// Formatea una fecha como `yyyy-MM-dd` para enviarla a Postgres como date.
  String _toYmd(DateTime d) {
    final year = d.year.toString().padLeft(4, '0');
    final month = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  DateTime _asDate(
    dynamic value, {
    required String field,
  }) {
    if (value == null) {
      throw FormatException('Campo fecha requerido ausente: $field');
    }

    if (value is DateTime) {
      return DateTime(value.year, value.month, value.day);
    }

    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) {
      throw FormatException('No se pudo convertir a DateTime el campo $field');
    }

    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  DateTime _monthStart(DateTime d) => DateTime(d.year, d.month, 1);
}
