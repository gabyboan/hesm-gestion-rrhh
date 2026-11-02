import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:app_horas/features/medicos/data/ajuste_impresion_medica_repository.dart';
import 'package:app_horas/features/medicos/data/parte_medico_printer.dart';
import 'package:app_horas/features/medicos/domain/ajuste_impresion_medica.dart';
import 'package:app_horas/features/medicos/domain/parte_medico.dart';
import 'package:app_horas/features/medicos/presentation/ajuste_impresion_medica_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printing/printing.dart';
import 'package:printing/src/interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Impresion extends PrintingPlatform {
  List<Printer> impresoras = [];
  List<String> trabajos = [];
  List<Uint8List> documentos = [];
  Printer? destino;
  bool aceptar = true;
  bool fallar = false;

  @override
  Future<PrintingInfo> info() async => PrintingInfo(
      directPrint: impresoras.isNotEmpty,
      canListPrinters: impresoras.isNotEmpty);

  @override
  Future<List<Printer>> listPrinters() async => impresoras;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #layoutPdf) return _imprimir(invocation);
    return super.noSuchMethod(invocation);
  }

  Future<bool> _imprimir(Invocation invocation) async {
    if (fallar) throw StateError('Impresora no disponible');
    destino = invocation.positionalArguments[0] as Printer?;
    trabajos.add(invocation.positionalArguments[2] as String);
    final callback = invocation.positionalArguments[1] as LayoutCallback;
    documentos.add(await callback(invocation.positionalArguments[3]));
    return aceptar;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const repository = AjusteImpresionMedicaRepository();
  late PrintingPlatform original;
  late _Impresion printing;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    original = PrintingPlatform.instance;
    printing = _Impresion();
    PrintingPlatform.instance = printing;
  });
  tearDown(() => PrintingPlatform.instance = original);

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

  test('conserva el ajuste anterior y separa Brother de Canon', () async {
    await repository.guardar(const AjusteImpresionMedica(horizontalMm: 0.3));
    expect((await repository.cargar(impresora: 'Brother')).horizontalMm, 0.3);
    expect((await repository.cargar(impresora: 'Canon')).horizontalMm, 0.3);
    await repository.guardar(
      const AjusteImpresionMedica(horizontalMm: 2),
      impresora: 'Brother',
    );
    await repository.guardar(
      const AjusteImpresionMedica(verticalMm: -1),
      impresora: 'Canon',
    );
    expect((await repository.cargar(impresora: 'Brother')).horizontalMm, 2);
    expect((await repository.cargar(impresora: 'Canon')).horizontalMm, 0);
    expect((await repository.cargar(impresora: 'Canon')).verticalMm, -1);
    expect((await repository.cargar()).horizontalMm, 0.3);
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

  testWidgets('cada prueba usa el ajuste actual sin guardar ni acumular',
      (tester) async {
    printing.impresoras = [
      const Printer(url: 'Brother', name: 'Brother HL-1210W', isDefault: true),
      const Printer(url: 'Canon', name: 'Canon LBP6030/6040/6018L'),
    ];
    await repository.guardar(
      const AjusteImpresionMedica(horizontalMm: 0.5),
      impresora: 'Brother',
    );
    await abrir(tester);
    final parte = tester
        .widget<AjusteImpresionMedicaDialog>(
            find.byType(AjusteImpresionMedicaDialog))
        .parte;
    for (final ajuste in [
      const AjusteImpresionMedica(horizontalMm: 1, verticalMm: -1),
      const AjusteImpresionMedica(horizontalMm: 2, verticalMm: 0.5),
      const AjusteImpresionMedica(horizontalMm: -1, verticalMm: 2),
    ]) {
      await tester.enterText(
          find.byType(TextFormField).first, '${ajuste.horizontalMm}');
      await tester.enterText(
          find.byType(TextFormField).last, '${ajuste.verticalMm}');
      await tester.ensureVisible(find.text('Imprimir prueba'));
      await tester.tap(find.text('Imprimir prueba'));
      await tester.pumpAndSettle();
      final esperado = await ParteMedicoPrinter.generar(parte, ajuste: ajuste);
      expect(_contenidoPdf(printing.documentos.last), _contenidoPdf(esperado));
      expect(printing.destino?.url, 'Brother');
    }
    expect(printing.trabajos.toSet(), hasLength(3));
    expect((await repository.cargar(impresora: 'Brother')).horizontalMm, 0.5);

    await tester.tap(find.text('Guardar ajuste'));
    await tester.pumpAndSettle();
    expect((await repository.cargar(impresora: 'Brother')).horizontalMm, -1);
    await ParteMedicoPrinter.imprimir(parte,
        impresora: printing.impresoras.first);
    expect(_contenidoPdf(printing.documentos.last),
        _contenidoPdf(printing.documentos[2]));
  });

  testWidgets('cambiar de impresora carga su ajuste y guarda solo en ella',
      (tester) async {
    printing.impresoras = [
      const Printer(url: 'Brother', name: 'Brother HL-1210W', isDefault: true),
      const Printer(url: 'Canon', name: 'Canon LBP6030/6040/6018L'),
    ];
    await repository.guardar(
      const AjusteImpresionMedica(horizontalMm: 1),
      impresora: 'Brother',
    );
    await repository.guardar(
      const AjusteImpresionMedica(horizontalMm: -2),
      impresora: 'Canon',
    );
    await abrir(tester);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Canon LBP6030/6040/6018L').last);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        '-2,0');
    await tester.enterText(find.byType(TextFormField).first, '3');
    await tester.tap(find.text('Guardar ajuste'));
    await tester.pumpAndSettle();
    expect((await repository.cargar(impresora: 'Canon')).horizontalMm, 3);
    expect((await repository.cargar(impresora: 'Brother')).horizontalMm, 1);
  });

  testWidgets('permite volver a probar después de cancelar o fallar',
      (tester) async {
    await abrir(tester);
    printing.aceptar = false;
    await tester.tap(find.text('Imprimir prueba'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Prueba cancelada.'), findsOneWidget);
    printing.fallar = true;
    await tester.tap(find.text('Imprimir prueba'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No se pudo imprimir:'), findsOneWidget);
    printing.fallar = false;
    printing.aceptar = true;
    await tester.enterText(find.byType(TextFormField).last, '2');
    await tester.tap(find.text('Imprimir prueba'));
    await tester.pumpAndSettle();
    expect(find.textContaining('vertical 2.0 mm'), findsOneWidget);
  });

  testWidgets('restablecer recupera un ajuste guardado inválido',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'medicos.ajuste_impresion.v1': 'json inválido',
    });
    await abrir(tester);
    expect(find.textContaining('No se pudo cargar el ajuste'), findsOneWidget);
    await tester.ensureVisible(find.text('Restablecer'));
    await tester.tap(find.text('Restablecer'));
    await tester.pump();
    await tester.tap(find.text('Guardar ajuste'));
    await tester.pumpAndSettle();
    expect((await repository.cargar()).horizontalMm, 0);
    expect((await repository.cargar()).verticalMm, 0);
  });
}

String _contenidoPdf(List<int> bytes) => RegExp(
      r'stream\r?\n([\s\S]*?)\r?\nendstream',
    ).allMatches(latin1.decode(bytes)).map((match) {
      final stream = latin1.encode(match[1]!);
      try {
        return latin1.decode(zlib.decode(stream));
      } on FormatException {
        return latin1.decode(stream);
      }
    }).join('\n');
