import 'dart:convert';

import 'parte_medico.dart';

class ConflictoParteMedico {
  ConflictoParteMedico.fromJson(Map<String, dynamic> datos)
      : id = (datos['id'] as num).toInt(),
        tipo = TipoParteMedico.fromDb(datos['tipo'] as String),
        desde = DateTime.parse(datos['fecha_desde'] as String),
        hasta = DateTime.parse(datos['fecha_hasta'] as String),
        version = (datos['version'] as num).toInt(),
        duplicado = datos['duplicado'] == true;

  final int id;
  final TipoParteMedico tipo;
  final DateTime desde;
  final DateTime hasta;
  final int version;
  final bool duplicado;
}

class ConflictosPartesMedicos implements Exception {
  const ConflictosPartesMedicos(this.conflictos);
  final List<ConflictoParteMedico> conflictos;

  factory ConflictosPartesMedicos.fromDetails(String details) {
    final rows = jsonDecode(details) as List;
    if (rows.isEmpty) {
      throw const FormatException('Faltan los partes coincidentes.');
    }
    return ConflictosPartesMedicos(rows
        .map((row) => ConflictoParteMedico.fromJson(
            Map<String, dynamic>.from(row as Map)))
        .toList());
  }

  @override
  String toString() =>
      'Hay partes médicos duplicados o con fechas superpuestas.';
}
