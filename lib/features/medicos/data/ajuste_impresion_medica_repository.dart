import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/ajuste_impresion_medica.dart';

class AjusteImpresionMedicaRepository {
  const AjusteImpresionMedicaRepository();

  static const _key = 'medicos.ajuste_impresion.v1';

  Future<AjusteImpresionMedica> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    if (value == null) return const AjusteImpresionMedica();
    return AjusteImpresionMedica.fromJson(
      jsonDecode(value) as Map<String, dynamic>,
    );
  }

  Future<void> guardar(AjusteImpresionMedica ajuste) async {
    if (!ajuste.esValido) {
      throw ArgumentError('El ajuste debe estar entre -10 y 10 mm.');
    }
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(_key, jsonEncode(ajuste.toJson()));
    if (!saved) throw StateError('No se pudo guardar el ajuste de impresión.');
  }
}
