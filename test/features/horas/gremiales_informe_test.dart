import 'package:app_horas/core/export/export_informe_xlsx.dart';
import 'package:app_horas/features/horas/application/horas_providers.dart';
import 'package:app_horas/features/horas/application/informe_providers.dart';
import 'package:app_horas/features/horas/domain/hora_registro.dart';
import 'package:app_horas/features/horas/domain/persona.dart';
import 'package:app_horas/features/horas/domain/tipo_hora.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));
  const person = Persona(
      apellido: 'DEMO',
      nombre: 'Persona',
      dni: 1001,
      carreraId: 17,
      carrera: 'Cualquiera');

  test('Gremial usa duración extendida y tiene su tipo propio', () {
    expect(TipoHora.gremial.db, 'GREMIAL');
    expect(TipoHoraParser.fromDb(' gremial '), TipoHora.gremial);
    expect(TipoHora.gremial.usaDuracionExtendida, isTrue);
  });

  test('Gremiales aparecen en informes y Excel sin contarse como oficiales',
      () async {
    final container = ProviderContainer(overrides: [
      listadoProvider.overrideWith((ref) async => []),
      listadoOficialesProvider.overrideWith((ref) async => [person]),
      registrosPeriodoProvider.overrideWith((ref) async => [
            HoraRegistro.fromJson({
              'id': 1,
              'dni': 1001,
              'carrera_id': 17,
              'fecha': '2026-11-12',
              'periodo': '2026-11-01',
              'tipo': 'GREMIAL',
              'minutos': 90,
            })
          ]),
    ]);
    addTearDown(container.dispose);
    container.read(informeFiltrosProvider.notifier).state = {
      InformeFiltro.gremiales
    };
    final rows = await container.read(informeRowsProvider.future);
    expect(rows.single.gremialesPorDia.values.single, 90);
    expect(rows.single.oficialesPorDia, isEmpty);
    expect(rows.single.particularesPorDia, isEmpty);
    expect(rows.single.tieneUso, isTrue);
    final excel = buildInformeExcel(
        periodo: DateTime(2026, 11),
        rows: rows,
        filtros: {InformeFiltro.gremiales});
    final texts = excel.tables.values
        .expand((sheet) => sheet.rows)
        .expand((row) => row)
        .map((cell) => cell?.value.toString() ?? '')
        .join('|');
    expect(texts, contains('HORAS GREMIALES'));
    expect(texts, contains('DEMO, Persona'));
    container.read(informeFiltrosProvider.notifier).state = {
      InformeFiltro.oficiales
    };
    expect(await container.read(informeRowsProvider.future), isEmpty);
  });
}
