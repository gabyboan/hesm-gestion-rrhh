import 'dart:convert';

import 'package:app_horas/features/medicos/application/medicos_providers.dart';
import 'package:app_horas/features/medicos/application/cola_impresion_provider.dart';
import 'package:app_horas/features/medicos/domain/medico_domicilio.dart';
import 'package:app_horas/features/medicos/domain/medico_persona.dart';
import 'package:app_horas/features/medicos/domain/parte_medico.dart';
import 'package:app_horas/features/medicos/domain/control_parte_medico.dart';
import 'package:app_horas/features/medicos/data/medicos_repository.dart';
import 'package:app_horas/features/medicos/presentation/medicos_page.dart';
import 'package:app_horas/features/medicos/presentation/parte_medico_vista_panel.dart';
import 'package:app_horas/features/medicos/presentation/parte_medico_vista_ampliada.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_horas/features/medicos/domain/parte_medico_qr.dart';
import 'package:app_horas/features/medicos/presentation/parte_medico_qr_widget.dart';
import 'package:app_horas/core/utils/search_query.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printing/printing.dart';
import 'package:printing/src/interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _GuardarPrueba extends GuardarParteMedicoController {
  int siguienteId = 100;
  @override
  Future<int> crear(ParteMedicoFormData data) async => siguienteId++;
}

class _RepositorioPrueba implements MedicosRepository {
  _RepositorioPrueba(this.partes);
  final List<ParteMedico> partes;

  @override
  Future<List<ParteMedico>> registros(
          {String? buscar, DateTime? fecha}) async =>
      partes;
  @override
  Future<DocumentoParteMedico> documento({int? id, String? codigo}) async =>
      DocumentoParteMedico(
        parte: ParteMedico.fromJson({
          'id': id,
          'dni': 23456789,
          'fecha': '2026-10-23',
          'tipo': 'DOMICILIO',
          'empleado_apellido': 'Nuevo',
          'empleado_nombre': 'Luis',
          'codigo_qr': id == 100 ? '00001008' : '00001016',
        }),
        anulado: false,
        controles: const [],
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RasterPrueba extends PdfRaster {
  _RasterPrueba() : super(1, 1, Uint8List.fromList([255, 255, 255, 255]));

  @override
  Future<Uint8List> toPng() async => base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=');
}

class _ImpresionPrueba extends PrintingPlatform {
  int impresiones = 0;
  int vistas = 0;
  bool aceptar = false;

  @override
  Future<PrintingInfo> info() async => const PrintingInfo(canRaster: true);

  @override
  Stream<PdfRaster> raster(
      Uint8List document, List<int>? pages, double dpi) async* {
    expect(String.fromCharCodes(document.take(4)), '%PDF');
    vistas++;
    yield _RasterPrueba();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #layoutPdf) {
      impresiones++;
      return Future.value(aceptar);
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  late _ImpresionPrueba printing;
  late PrintingPlatform original;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    original = PrintingPlatform.instance;
    printing = _ImpresionPrueba();
    PrintingPlatform.instance = printing;
  });
  tearDown(() => PrintingPlatform.instance = original);

  ParteMedico parte(int id, TipoParteMedico tipo,
          {DateTime? fecha,
          ParteMedicoQr? qr,
          bool esEnfermeria = false,
          String aclaracionFechaTurno = 'Turno tarde'}) =>
      ParteMedico(
        id: id,
        qr: qr,
        esEnfermeria: esEnfermeria,
        carreraNombre: esEnfermeria ? 'Enfermería' : 'Escalafón General',
        dni: 12345678,
        fecha: fecha ?? DateTime(2026, 10, 23),
        tipo: tipo,
        empleadoApellido: 'Perez',
        empleadoNombre: 'Ana $id',
        empleadoLegajo: 123,
        familiarApellidoNombre: tipo.requiereFamiliar ? 'Gomez, Juan' : null,
        familiarEdad: tipo.requiereFamiliar ? 8 : null,
        familiarParentesco: tipo.requiereFamiliar ? 'Hijo' : null,
        aclaracionFechaTurno: aclaracionFechaTurno,
      );

  const persona = MedicoPersona(
      dni: 23456789, apellido: 'Nuevo', nombre: 'Luis', legajo: 456);

  Future<void> abrir(WidgetTester tester, List<ParteMedico> registros,
      {Size size = const Size(1440, 900),
      DateTime? hoy,
      MedicoPersona agente = persona}) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        medicosHoyProvider.overrideWith((ref) => hoy ?? DateTime(2026, 10, 23)),
        medicosRepoProvider.overrideWithValue(_RepositorioPrueba(registros)),
        puedeLeerMedicosProvider.overrideWith((ref) async => true),
        puedeCrearMedicosProvider.overrideWith((ref) async => true),
        puedeAdministrarMedicosProvider.overrideWith((ref) async => false),
        medicosPersonasProvider.overrideWith((ref) async => [agente]),
        partesMedicosProvider.overrideWith((ref) async {
          final query = SearchQuery(ref.watch(partesMedicosSearchProvider));
          return registros
              .where((p) => query.matches([
                    p.empleadoCompleto,
                    p.dni,
                    p.empleadoLegajo,
                    p.aclaracionFechaTurno
                  ]))
              .toList();
        }),
        guardarParteMedicoControllerProvider.overrideWith(_GuardarPrueba.new),
        medicosDomicilioProvider.overrideWith((ref, dni) async =>
            const MedicoDomicilio(calle: 'Calle de prueba', numero: '123')),
      ],
      child: MaterialApp(
          home: ProviderScope(
        overrides: [
          colaImpresionProvider.overrideWith((ref) => ColaImpresionController())
        ],
        child: const Scaffold(body: MedicosPage()),
      )),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('carga varios partes sin imprimir y permite revisarlos juntos',
      (tester) async {
    await abrir(tester, []);
    for (var index = 0; index < 2; index++) {
      await tester.tap(find.byTooltip('Emitir parte'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cargar para imprimir después'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
    }
    expect(printing.impresiones, 0);
    expect(find.text('Bandeja de impresión (2)'), findsOneWidget);
    final container =
        ProviderScope.containerOf(tester.element(find.byType(MedicosPage)));
    expect(container.read(colaImpresionProvider).map((p) => p.qr!.codigo),
        ['00001008', '00001016']);
    await tester.tap(find.text('Bandeja de impresión (2)'));
    await tester.pumpAndSettle();
    expect(find.text('Imprimir todos (2)'), findsOneWidget);
    expect(find.byTooltip('Imprimir este parte'), findsNWidgets(2));
    await tester.tap(find.text('Imprimir todos (2)'));
    await tester.pumpAndSettle();
    expect(printing.impresiones, 1);
    expect(find.text('Impresión cancelada. Los partes siguen en la bandeja.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'conserva registrar e imprimir y guarda la cancelación en la bandeja',
      (tester) async {
    await abrir(tester, []);
    await tester.tap(find.byTooltip('Emitir parte'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar e imprimir'));
    await tester.pumpAndSettle();
    expect(printing.impresiones, 1);
    expect(find.text('Bandeja de impresión (1)'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('el historial agrega a la bandeja sin duplicar el mismo parte',
      (tester) async {
    await abrir(tester, [parte(1, TipoParteMedico.domicilio)]);
    await tester.tap(find.widgetWithText(Tab, 'Partes registrados'));
    await tester.pumpAndSettle();
    for (var index = 0; index < 2; index++) {
      await tester.tap(find.byTooltip('Agregar a la bandeja de impresión'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
    }
    final container =
        ProviderScope.containerOf(tester.element(find.byType(MedicosPage)));
    expect(container.read(colaImpresionProvider), hasLength(1));
    expect(container.read(colaImpresionProvider).single.domicilio?.calle,
        'Calle de prueba');
    expect(printing.impresiones, 0);
  });

  testWidgets(
      'imprimir desde el historial retira el parte de la bandeja solo al aceptar',
      (tester) async {
    final registro = parte(1, TipoParteMedico.consultorio);
    await abrir(tester, [registro]);
    final container =
        ProviderScope.containerOf(tester.element(find.byType(MedicosPage)));
    container.read(colaImpresionProvider.notifier).agregar(registro);
    await tester.tap(find.widgetWithText(Tab, 'Partes registrados'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Reimprimir'));
    await tester.pumpAndSettle();
    expect(container.read(colaImpresionProvider), hasLength(1));
    printing.aceptar = true;
    await tester.tap(find.byTooltip('Reimprimir'));
    await tester.pumpAndSettle();
    expect(container.read(colaImpresionProvider), isEmpty);
  });

  testWidgets('permite seleccionar y solicitar medico a un suplente sin legajo',
      (tester) async {
    const suplente = MedicoPersona(
        dni: 23456789, apellido: 'Suplente', nombre: 'Ana', legajo: null);
    await abrir(tester, [], agente: suplente);
    expect(find.text('Todo el personal'), findsOneWidget);
    expect(find.text('Sin legajo - DNI 23456789'), findsOneWidget);
    expect(find.byType(PdfPreview), findsOneWidget);

    await tester.tap(find.byTooltip('Emitir parte'));
    await tester.pumpAndSettle();
    expect(find.text('Emitir parte medico'), findsOneWidget);
    final registrar = tester.widget<FilledButton>(find.ancestor(
      of: find.text('Registrar e imprimir'),
      matching: find.byWidgetPredicate((widget) => widget is FilledButton),
    ));
    expect(registrar.onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('muestra el primer registro y cambia de selección sin imprimir',
      (tester) async {
    final familiar = parte(1, TipoParteMedico.domicilioFamiliar);
    final canje = parte(2, TipoParteMedico.canje);
    final consultorio = parte(3, TipoParteMedico.consultorio);
    await abrir(tester, [familiar, canje, consultorio]);
    expect(find.widgetWithText(ListTile, familiar.descripcionRegistro),
        findsNothing);
    await tester.tap(find.widgetWithText(Tab, 'Partes registrados'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, persona.nombreCompleto), findsNothing);
    expect(find.byType(PdfPreview), findsOneWidget);
    expect(
        tester
            .widget<ParteMedicoVistaPanel>(find.byType(ParteMedicoVistaPanel))
            .parte
            ?.id,
        1);
    expect(find.text('AD'), findsOneWidget);
    expect(find.text('PC'), findsOneWidget);
    expect(find.text('AC'), findsOneWidget);
    expect(find.text('Perez, Ana 1 - IF: Gomez, Juan - Turno tarde'),
        findsNWidgets(2));
    expect(printing.vistas, greaterThan(0));
    expect(printing.impresiones, 0);

    await tester.tap(find.widgetWithText(ListTile, canje.descripcionRegistro));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ParteMedicoVistaPanel>(find.byType(ParteMedicoVistaPanel))
            .parte
            ?.id,
        2);
    expect(find.byType(PdfPreview), findsOneWidget);
    expect(printing.impresiones, 0);

    await tester.tap(find.widgetWithText(Tab, 'Emitir parte'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, persona.nombreCompleto));
    await tester.pumpAndSettle();
    final panel = tester
        .widget<ParteMedicoVistaPanel>(find.byType(ParteMedicoVistaPanel));
    expect(panel.parte, isNull);
    expect(panel.persona?.dni, persona.dni);
    expect(find.byType(PdfPreview), findsOneWidget);
    expect(printing.impresiones, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inicia en hoy, filtra el día y conserva el orden de emisión',
      (tester) async {
    final primero =
        parte(1, TipoParteMedico.consultorio, fecha: DateTime(2026, 9, 30));
    final segundo =
        parte(2, TipoParteMedico.consultorio, fecha: DateTime(2026, 9, 30));
    final tercero =
        parte(3, TipoParteMedico.consultorio, fecha: DateTime(2026, 10, 1));
    final cuarto =
        parte(4, TipoParteMedico.consultorio, fecha: DateTime(2026, 10, 1));
    // El servidor puede devolver los registros del mas reciente al mas antiguo.
    final registros =
        List<ParteMedico>.unmodifiable([cuarto, tercero, segundo, primero]);
    await abrir(tester, registros,
        size: const Size(1600, 1200), hoy: DateTime(2026, 10, 1));
    await tester.tap(find.widgetWithText(Tab, 'Partes registrados'));
    await tester.pumpAndSettle();

    final filas = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    expect(filas.map((fila) => (fila.title! as Text).data), [
      tercero.descripcionRegistro,
      cuarto.descripcionRegistro,
    ]);
    expect(find.text('30/09/2026'), findsNothing);
    expect(
        tester
            .widget<IconButton>(find.byWidgetPredicate((widget) =>
                widget is IconButton && widget.tooltip == 'Día siguiente'))
            .onPressed,
        isNull);
    await tester.tap(find.byTooltip('Día anterior'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widgetList<ListTile>(find.byType(ListTile))
            .map((fila) => (fila.title! as Text).data),
        [primero.descripcionRegistro, segundo.descripcionRegistro]);
    expect(
        tester
            .widget<ParteMedicoVistaPanel>(find.byType(ParteMedicoVistaPanel))
            .parte
            ?.id,
        primero.id);
    expect(registros.first.id, cuarto.id);
    await tester.tap(find.text('Hoy'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, tercero.descripcionRegistro),
        findsOneWidget);
    expect(find.widgetWithText(ListTile, primero.descripcionRegistro),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'el calendario cambia de fecha sin borrar la búsqueda y admite un día vacío',
      (tester) async {
    final ayer =
        parte(1, TipoParteMedico.consultorio, fecha: DateTime(2026, 10, 22));
    final hoy = parte(2, TipoParteMedico.canje);
    await abrir(tester, [ayer, hoy]);
    await tester.tap(find.widgetWithText(Tab, 'Partes registrados'));
    await tester.pumpAndSettle();
    expect(
        find.widgetWithText(ListTile, hoy.descripcionRegistro), findsOneWidget);
    expect(
        find.widgetWithText(ListTile, ayer.descripcionRegistro), findsNothing);
    await tester.enterText(find.byType(TextField), 'Turno');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Elegir fecha de emisión'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('22'));
    await tester.tap(find.text('Ver partes'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, ayer.descripcionRegistro),
        findsOneWidget);
    expect(
        find.widgetWithText(ListTile, hoy.descripcionRegistro), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Turno');
    await tester.tap(find.byTooltip('Día anterior'));
    await tester.pumpAndSettle();
    expect(find.text('Sin partes registrados'), findsOneWidget);
    expect(
        tester
            .widget<ParteMedicoVistaPanel>(find.byType(ParteMedicoVistaPanel))
            .parte,
        isNull);
    expect(find.byType(PdfPreview), findsNothing);
    await tester.tap(find.text('Hoy'));
    await tester.pumpAndSettle();
    expect(
        find.widgetWithText(ListTile, hoy.descripcionRegistro), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sin registros ofrece la vista de la primera persona',
      (tester) async {
    await abrir(tester, []);
    expect(
        tester
            .widget<ParteMedicoVistaPanel>(find.byType(ParteMedicoVistaPanel))
            .persona
            ?.dni,
        persona.dni);
    expect(find.byType(PdfPreview), findsOneWidget);
    expect(printing.impresiones, 0);
    await tester.tap(find.widgetWithText(Tab, 'Partes registrados'));
    await tester.pumpAndSettle();
    expect(find.text('Sin partes registrados'), findsOneWidget);
    expect(find.byType(PdfPreview), findsNothing);
  });

  testWidgets('mantiene lista y vista visibles en una ventana más angosta',
      (tester) async {
    await abrir(tester, [parte(1, TipoParteMedico.domicilioFamiliar)],
        size: const Size(1024, 768));
    expect(find.text('Partes registrados'), findsOneWidget);
    expect(find.text('Vista preliminar'), findsOneWidget);
    expect(find.byType(PdfPreview), findsOneWidget);
    final size = tester.getSize(find.byType(ParteMedicoVistaPanel));
    expect(size.width, greaterThan(500));
    expect(size.height, greaterThan(500));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'la lupa permite ampliar y cerrar sin imprimir ni cambiar de persona',
      (tester) async {
    await abrir(tester, []);
    await tester.tap(find.byTooltip('Ampliar vista preliminar'));
    await tester.pumpAndSettle();
    expect(find.byType(ParteMedicoVistaAmpliada), findsOneWidget);
    expect(find.text('100 %'), findsOneWidget);
    final renders = printing.vistas;
    await tester.tap(find.byTooltip('Acercar'));
    await tester.pumpAndSettle();
    expect(find.text('125 %'), findsOneWidget);
    await tester.tap(find.byTooltip('Alejar'));
    await tester.pumpAndSettle();
    expect(find.text('100 %'), findsOneWidget);
    await tester.tap(find.byTooltip('Acercar'));
    await tester.tap(find.text('Ajustar al ancho'));
    await tester.pumpAndSettle();
    expect(find.text('100 %'), findsOneWidget);
    expect(printing.vistas, renders);
    expect(printing.impresiones, 0);
    await tester.tap(find.byTooltip('Cerrar vista ampliada'));
    await tester.pumpAndSettle();
    expect(find.byType(ParteMedicoVistaAmpliada), findsNothing);
    expect(
        tester
            .widget<ParteMedicoVistaPanel>(find.byType(ParteMedicoVistaPanel))
            .persona
            ?.dni,
        persona.dni);
    expect(tester.takeException(), isNull);
  });

  testWidgets('conserva búsquedas independientes al cambiar de pestaña',
      (tester) async {
    await abrir(tester, [parte(1, TipoParteMedico.canje)]);
    await tester.enterText(find.byType(TextField), 'Nuevo');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Partes registrados'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text, '');
    await tester.enterText(find.byType(TextField), 'Turno tarde');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Emitir parte'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Nuevo');
    await tester.tap(find.widgetWithText(Tab, 'Partes registrados'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Turno tarde');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'incluye automáticamente toda la carrera Enfermería aunque haya una búsqueda',
      (tester) async {
    final canje = parte(2, TipoParteMedico.canje, esEnfermeria: true);
    await abrir(tester, [
      parte(1, TipoParteMedico.domicilio, aclaracionFechaTurno: 'No incluido'),
      canje,
      parte(3, TipoParteMedico.consultorio, esEnfermeria: true)
    ]);
    String? copiado;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copiado = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.tap(find.widgetWithText(Tab, 'Partes registrados'));
    await tester.pumpAndSettle();
    expect(find.text('Seleccionar todos'), findsNothing);
    await tester.enterText(find.byType(TextField), 'No incluido');
    await tester.pumpAndSettle();
    expect(
        find.widgetWithText(ListTile, canje.descripcionRegistro), findsNothing);
    await tester.tap(find.text('Listado de Enfermería'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copiar listado'));
    await tester.pumpAndSettle();
    expect(copiado, contains('PC — Perez, Ana 2'));
    expect(copiado, contains('AC — Perez, Ana 3'));
    expect(copiado, contains('Total: 2'));
    expect(copiado, contains('Observaciones: Turno tarde'));
    expect(copiado, isNot(contains('Ana 1')));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('muestra y permite ampliar el QR real del parte emitido',
      (tester) async {
    await abrir(tester, [
      parte(42, TipoParteMedico.consultorio,
          qr: ParteMedicoQr.parse('00000422'))
    ]);
    await tester.tap(find.widgetWithText(Tab, 'Partes registrados'));
    await tester.pumpAndSettle();
    expect(find.byType(ParteMedicoQrWidget), findsOneWidget);
    await tester.tap(find.byTooltip('Ampliar QR del parte'));
    await tester.pumpAndSettle();
    expect(find.text('QR del parte'), findsOneWidget);
    expect(find.byType(ParteMedicoQrWidget), findsNWidgets(2));
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
