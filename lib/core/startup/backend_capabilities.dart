import 'package:supabase_flutter/supabase_flutter.dart';

const requiredBackendSchema = 2;

Future<void> requireCompatibleBackend(SupabaseClient client) async {
  try {
    final result = await client
        .rpc('rpc_gestion_capacidades')
        .timeout(const Duration(seconds: 15));
    if (result is Map &&
        result['schema'] is int &&
        result['schema'] >= requiredBackendSchema &&
        result['horas_gremiales'] == true &&
        result['horas_idempotencia'] == true &&
        result['horas_periodos'] == true) {
      return;
    }
  } on PostgrestException catch (error) {
    if (error.code != 'PGRST202' && error.code != '42883') rethrow;
  }
  throw const BackendUpdateRequired();
}

class BackendUpdateRequired implements Exception {
  const BackendUpdateRequired();
  @override
  String toString() =>
      'La base necesita actualizarse para esta versión. Contactá al responsable del sistema.';
}
