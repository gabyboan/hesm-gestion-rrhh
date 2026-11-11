import 'package:app_horas/features/ficha/application/ficha_providers.dart';
import 'package:app_horas/features/imprevistos/application/imprevistos_providers.dart';
import 'package:app_horas/features/imprevistos/data/imprevistos_repository.dart';
import 'package:app_horas/features/licencias/application/licencias_providers.dart';
import 'package:app_horas/features/licencias/data/licencias_repository.dart';
import 'package:app_horas/features/licencias/domain/licencia.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('guardar un imprevisto actualiza Licencias y ambas consultas de Ficha',
      () async {
    final client = SupabaseClient('http://127.0.0.1:1', 'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false));
    final licencias = _Licencias(client);
    final imprevistos = _Imprevistos(client, licencias);
    final container = ProviderContainer(overrides: [
      licenciasRepoProvider.overrideWithValue(licencias),
      imprevistosRepoProvider.overrideWithValue(imprevistos),
      puedeLeerFichaProvider.overrideWith((ref) async => true),
      licenciasPermisosProvider
          .overrideWith((ref) async => const LicenciasPermisos(leer: true)),
      licenciasAnioProvider.overrideWith((ref) => 2026),
    ]);
    addTearDown(container.dispose);
    addTearDown(client.dispose);
    final anual = fichaLicenciasProvider((dni: 12345678, anio: 2026));
    final acumulada = fichaLicenciasAcumuladasProvider(12345678);
    container.listen(anual, (_, __) {});
    container.listen(acumulada, (_, __) {});
    container.listen(licenciasRegistrosProvider, (_, __) {});
    expect(await container.read(anual.future), isEmpty);
    expect(await container.read(acumulada.future), isEmpty);
    expect(await container.read(licenciasRegistrosProvider.future), isEmpty);
    await container.read(guardarImprevistoControllerProvider.notifier).crear(
        ImprevistoFormData(
            dni: 12345678,
            carreraId: 1,
            fecha: DateTime(2026, 7, 1),
            observacion: null,
            numeroOrden: 42));
    for (final rows in [
      await container.read(anual.future),
      await container.read(acumulada.future),
      await container.read(licenciasRegistrosProvider.future),
    ]) {
      expect(rows.single.esImprevisto, isTrue);
      expect(rows.single.codigo, '43');
      expect(rows.single.numeroOrden, 42);
    }
  });
}

class _Licencias extends LicenciasRepository {
  _Licencias(super.sb);
  bool guardado = false;
  List<LicenciaRegistro> get rows => [
        if (guardado)
          LicenciaRegistro(
              id: -1,
              imprevistoId: 1,
              dni: 12345678,
              nombre: 'PERSONA DE PRUEBA',
              tipoId: 143,
              tipo: 'Imprevisto',
              codigo: '43',
              columnaFicha: 'ART8',
              desde: DateTime(2026, 7, 1),
              hasta: DateTime(2026, 7, 1),
              dias: 1,
              numeroOrden: 42),
      ];
  @override
  Future<List<LicenciaRegistro>> registros(int anio, {int? personaDni}) async =>
      rows;
  @override
  Future<List<LicenciaRegistro>> registrosDesde2026(
          {required int personaDni}) async =>
      rows;
}

class _Imprevistos extends ImprevistosRepository {
  _Imprevistos(super.sb, this.licencias);
  final _Licencias licencias;
  @override
  Future<void> crear(
      {required int dni,
      required int carreraId,
      required DateTime fecha,
      String? observacion,
      int? numeroOrden}) async {
    licencias.guardado = true;
  }
}
