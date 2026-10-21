import 'dart:convert';
import 'dart:typed_data';

import 'package:app_horas/features/medicos/application/cola_impresion_provider.dart';
import 'package:app_horas/features/medicos/domain/parte_medico.dart';
import 'package:app_horas/features/medicos/presentation/cola_impresion_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printing/src/interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Impresora extends PrintingPlatform {
  bool aceptar = true;
  bool fallar = false;
  int trabajos = 0;
  Uint8List? pdf;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #layoutPdf) {
      return _imprimir(invocation);
    }
    return super.noSuchMethod(invocation);
  }

  Future<bool> _imprimir(Invocation invocation) async {
    trabajos++;
    if (fallar) throw StateError('Impresora no disponible');
    final callback = invocation.positionalArguments[1] as dynamic;
    pdf = await callback(invocation.positionalArguments[3]) as Uint8List;
    return aceptar;
  }
}

ParteMedico _parte(int id) => ParteMedico.fromJson({
      'id': id,
      'dni': 12345670 + id,
      'fecha': '2026-10-21',
      'tipo': 'CONSULTORIO',
      'empleado_apellido': 'Empleado$id',
      'empleado_nombre': 'Prueba',
    });

void main() {
  late PrintingPlatform original;
  late _Impresora impresora;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    original = PrintingPlatform.instance;
    impresora = _Impresora();
    PrintingPlatform.instance = impresora;
  });
  tearDown(() => PrintingPlatform.instance = original);

  Future<ProviderContainer> abrir(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(colaImpresionProvider.notifier)
      ..agregar(_parte(1))
      ..agregar(_parte(2));
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: ColaImpresionDialog())),
    ));
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('envía todos en un único trabajo y vacía la bandeja al aceptar',
      (tester) async {
    final container = await abrir(tester);
    await tester.tap(find.text('Imprimir todos (2)'));
    await tester.pumpAndSettle();
    expect(impresora.trabajos, 1);
    expect(RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(impresora.pdf!)),
        hasLength(2));
    expect(container.read(colaImpresionProvider), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelar conserva todos los partes para reintentar',
      (tester) async {
    impresora.aceptar = false;
    final container = await abrir(tester);
    await tester.tap(find.text('Imprimir todos (2)'));
    await tester.pumpAndSettle();
    expect(container.read(colaImpresionProvider), hasLength(2));
    expect(find.text('Impresión cancelada. Los partes siguen en la bandeja.'),
        findsOneWidget);
  });

  testWidgets('un error de impresión permite reintentar sin perder partes',
      (tester) async {
    impresora.fallar = true;
    final container = await abrir(tester);
    await tester.tap(find.text('Imprimir todos (2)'));
    await tester.pumpAndSettle();
    expect(container.read(colaImpresionProvider), hasLength(2));
    expect(find.textContaining('No se pudo imprimir:'), findsOneWidget);
    impresora.fallar = false;
    await tester.tap(find.text('Imprimir todos (2)'));
    await tester.pumpAndSettle();
    expect(container.read(colaImpresionProvider), isEmpty);
  });

  testWidgets('imprime un solo parte y conserva el resto', (tester) async {
    final container = await abrir(tester);
    await tester.tap(find.byTooltip('Imprimir este parte').first);
    await tester.pumpAndSettle();
    expect(container.read(colaImpresionProvider).map((p) => p.id), [2]);
    expect(impresora.trabajos, 1);
    expect(RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(impresora.pdf!)),
        hasLength(1));
  });

  testWidgets('quitar de la bandeja conserva los demás sin imprimir',
      (tester) async {
    final container = await abrir(tester);
    await tester.tap(find.byTooltip('Quitar de la bandeja').first);
    await tester.pumpAndSettle();
    expect(container.read(colaImpresionProvider).map((p) => p.id), [2]);
    expect(impresora.trabajos, 0);
  });
}
