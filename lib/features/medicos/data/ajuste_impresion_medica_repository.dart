import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/ajuste_impresion_medica.dart';

class AjusteImpresionMedicaRepository {
  const AjusteImpresionMedicaRepository();

  static const _key = 'medicos.ajuste_impresion.v1';

  String _clave(String? impresora) => impresora == null
      ? _key
      : 'medicos.ajuste_impresion.impresora.v1.${Uri.encodeComponent(impresora)}';

  Future<AjusteImpresionMedica> cargar({String? impresora}) async {
    final prefs = await SharedPreferences.getInstance();
    // Conservamos el ajuste anterior como punto de partida, sin sobrescribirlo
    // al calibrar una impresora diferente.
    final value = prefs.getString(_clave(impresora)) ?? prefs.getString(_key);
    if (value == null) return const AjusteImpresionMedica();
    return AjusteImpresionMedica.fromJson(
      jsonDecode(value) as Map<String, dynamic>,
    );
  }

  Future<void> guardar(AjusteImpresionMedica ajuste,
      {String? impresora}) async {
    if (!ajuste.esValido) {
      throw ArgumentError('El ajuste debe estar entre -10 y 10 mm.');
    }
    final prefs = await SharedPreferences.getInstance();
    final saved =
        await prefs.setString(_clave(impresora), jsonEncode(ajuste.toJson()));
    if (!saved) throw StateError('No se pudo guardar el ajuste de impresión.');
  }
}
