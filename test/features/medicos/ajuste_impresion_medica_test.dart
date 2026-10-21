import 'package:app_horas/features/medicos/data/ajuste_impresion_medica_repository.dart';
import 'package:app_horas/features/medicos/domain/ajuste_impresion_medica.dart';
import 'package:app_horas/features/medicos/domain/parte_medico.dart';
import 'package:app_horas/features/medicos/presentation/ajuste_impresion_medica_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const repository = AjusteImpresionMedicaRepository();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('sin ajustes guardados conserva la calibración inicial', () async {
    final ajuste = await repository.cargar();
    expect(ajuste.horizontalMm, 0);
    expect(ajuste.verticalMm, 0);
  });

  test('guarda ambos ejes y los recupera desde una nueva instancia', () async {
    await repository.guardar(const AjusteImpresionMedica(
      horizontalMm: -0.5,
      verticalMm: 0.2,
    ));
    final ajuste = await const AjusteImpresionMedicaRepository().cargar();
    expect(ajuste.horizontalMm, -0.5);
    expect(ajuste.verticalMm, 0.2);
  });

  test('rechaza valores no finitos o fuera de rango sin alterar lo guardado',
      () async {
    await repository.guardar(const AjusteImpresionMedica(horizontalMm: 0.5));
    for (final value in [double.nan, double.infinity, -10.1, 10.1]) {
      await expectLater(
        repository.guardar(AjusteImpresionMedica(verticalMm: value)),
        throwsArgumentError,
      );
    }
    expect((await repository.cargar()).horizontalMm, 0.5);
  });

  Future<void> abrir(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Builder(
          builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showDialog<bool>(
                    context: context,
                    builder: (_) => AjusteImpresionMedicaDialog(
                      parte: ParteMedico(
                        id: 0,
                        dni: 12345678,
                        fecha: DateTime(2026, 10, 14),
                        tipo: TipoParteMedico.domicilio,
                        empleadoApellido: 'Prueba',
                        empleadoNombre: 'Maria',
                        empleadoLegajo: 123,
                        familiarApellidoNombre: null,
                        familiarEdad: null,
                        familiarParentesco: null,
                      ),
                    ),
                  ),
                  child: const Text('Abrir'),
                ),
              )),
    ));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('admite coma decimal, pasos de 0,1 mm y guarda', (tester) async {
    await abrir(tester);
    await tester.enterText(find.byType(TextFormField).first, '0,5');
    await tester.enterText(find.byType(TextFormField).last, '-0,2');
    await tester.tap(find.byTooltip('Mover 0,1 mm a la derecha'));
    await tester.tap(find.byTooltip('Mover 0,1 mm hacia arriba'));
    await tester.tap(find.text('Guardar ajuste'));
    await tester.pumpAndSettle();
    expect(find.byType(AjusteImpresionMedicaDialog), findsNothing);
    final ajuste = await repository.cargar();
    expect(ajuste.horizontalMm, 0.6);
    expect(ajuste.verticalMm, -0.3);
  });

  testWidgets('cancelar conserva el ajuste guardado', (tester) async {
    await repository.guardar(const AjusteImpresionMedica(horizontalMm: 1));
    await abrir(tester);
    await tester.enterText(find.byType(TextFormField).first, '3');
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect((await repository.cargar()).horizontalMm, 1);
  });

  testWidgets('restablecer vuelve a cero en ambos ejes al guardar',
      (tester) async {
    await repository.guardar(const AjusteImpresionMedica(
      horizontalMm: 1.5,
      verticalMm: -2,
    ));
    await abrir(tester);
    await tester.tap(find.text('Restablecer'));
    await tester.pump();
    await tester.tap(find.text('Guardar ajuste'));
    await tester.pumpAndSettle();
    final ajuste = await repository.cargar();
    expect(ajuste.horizontalMm, 0);
    expect(ajuste.verticalMm, 0);
  });

  testWidgets('un valor fuera de rango no cierra el diálogo ni se guarda',
      (tester) async {
    await abrir(tester);
    await tester.enterText(find.byType(TextFormField).last, '20');
    await tester.tap(find.text('Guardar ajuste'));
    await tester.pumpAndSettle();
    expect(find.text('Ingresá un valor entre -10 y 10 mm.'), findsOneWidget);
    expect(find.byType(AjusteImpresionMedicaDialog), findsOneWidget);
    expect((await repository.cargar()).verticalMm, 0);
  });
}
