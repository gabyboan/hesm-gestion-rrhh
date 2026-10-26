// Run with generate_demo_gallery.ps1. This renders the actual widgets with
// synthetic providers; it never initializes Supabase or signs in a user.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:app_horas/core/supabase/supabase_provider.dart';
import 'package:app_horas/features/auth/application/current_roles_provider.dart';
import 'package:app_horas/features/francos/application/francos_providers.dart';
import 'package:app_horas/features/francos/domain/franco_movimiento.dart';
import 'package:app_horas/features/francos/domain/franco_persona.dart';
import 'package:app_horas/features/horas/application/horas_providers.dart';
import 'package:app_horas/features/horas/domain/hora_registro.dart';
import 'package:app_horas/features/horas/domain/persona.dart';
import 'package:app_horas/features/imprevistos/application/imprevistos_providers.dart';
import 'package:app_horas/features/imprevistos/domain/imprevisto_persona.dart';
import 'package:app_horas/features/imprevistos/domain/imprevisto_registro.dart';
import 'package:app_horas/features/medicos/application/cola_impresion_provider.dart';
import 'package:app_horas/features/medicos/application/medicos_providers.dart';
import 'package:app_horas/features/medicos/data/parte_medico_printer.dart';
import 'package:app_horas/features/medicos/domain/medico_persona.dart';
import 'package:app_horas/features/medicos/domain/parte_medico.dart';
import 'package:app_horas/features/medicos/domain/parte_medico_qr.dart';
import 'package:app_horas/features/preferences/application/user_preferences_providers.dart';
import 'package:app_horas/features/preferences/domain/current_user_profile.dart';
import 'package:app_horas/features/shell/presentation/main_shell.dart';
import 'package:app_horas/features/suplencias/application/suplencias_providers.dart';
import 'package:app_horas/features/suplencias/data/suplencias_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printing/printing.dart';
import 'package:printing/src/interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _date = DateTime(2026, 10, 21);
final _period = DateTime(2026, 10);
final _part = ParteMedico(
  id: 1,
  qr: ParteMedicoQr.parse('00000018'),
  carreraNombre: 'Enfermería',
  esEnfermeria: true,
  dni: 1001,
  fecha: _date,
  tipo: TipoParteMedico.consultorio,
  empleadoApellido: 'DEMO',
  empleadoNombre: 'Persona Uno',
  empleadoLegajo: 1,
  familiarApellidoNombre: null,
  familiarEdad: null,
  familiarParentesco: null,
  aclaracionFechaTurno: 'Ejemplo ficticio - turno mañana',
);

class _DemoSuplencias implements SuplenciasRepository {
  const _DemoSuplencias();

  @override
  Future<List<Map<String, dynamic>>> listar({
    String buscar = '',
    String ordenarPor = 'id',
    bool ascendente = false,
  }) async =>
      [
        {
          'id': 1,
          'suplente_dni': 1002,
          'suplente_apellido': 'DEMO',
          'suplente_nombre': 'Persona Dos',
          'suplente_servicio': 'Servicio de ejemplo',
          'titular_dni': 1001,
          'titular_apellido': 'DEMO',
          'titular_nombre': 'Persona Uno',
          'titular_servicio': 'Servicio de ejemplo',
          'fecha_desde_fmt': '21/10/2026',
          'fecha_hasta_fmt': '23/10/2026',
          'dias_corridos': 3,
          'motivo': 'Cobertura ficticia',
        },
      ];
}

class _DemoRaster extends PdfRaster {
  _DemoRaster(super.width, super.height, super.pixels, this.png);
  final Uint8List png;
  @override
  Future<Uint8List> toPng() async => png;
}

class _DemoPrinting extends PrintingPlatform {
  _DemoPrinting(this.page);
  final _DemoRaster page;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Native printing is disabled in this demo.');
  @override
  Future<PrintingInfo> info() async => const PrintingInfo(canRaster: true);
  @override
  Stream<PdfRaster> raster(
      Uint8List document, List<int>? pages, double dpi) async* {
    yield page;
  }
}

void main() {
  testWidgets('render fictional gallery without a live session',
      (tester) async {
    // This artifact generator runs under flutter test, outside the CI suite.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    if (const bool.fromEnvironment('DEMO_PDF_ONLY')) {
      final bytes = await ParteMedicoPrinter.generarVistaPrevia(_part);
      await tester.runAsync(() async {
        await Directory('build/demo-gallery').create(recursive: true);
        await File('build/demo-gallery/parte-demo.pdf').writeAsBytes(bytes);
      });
      return;
    }

    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final originalPrinting = PrintingPlatform.instance;
    addTearDown(() => PrintingPlatform.instance = originalPrinting);
    await tester.runAsync(() async {
      const fontPath = String.fromEnvironment('DEMO_FONT',
          defaultValue: 'C:/Windows/Fonts/segoeui.ttf');
      final font = FontLoader('DemoUi')
        ..addFont(File(fontPath).readAsBytes().then(ByteData.sublistView));
      await font.load();
      await (FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
          .load();
      final png = await File('build/demo-gallery/parte-demo.png').readAsBytes();
      final codec = await ui.instantiateImageCodec(png);
      final frame = await codec.getNextFrame();
      final rgba = await frame.image.toByteData();
      PrintingPlatform.instance = _DemoPrinting(_DemoRaster(frame.image.width,
          frame.image.height, rgba!.buffer.asUint8List(), png));
      frame.image.dispose();
      codec.dispose();
    });

    final horas = [
      for (var index = 0; index < 3; index++)
        HoraRegistro(
          id: index + 1,
          dni: 1001,
          carreraId: 1,
          fecha: DateTime(2026, 10, 12 + index * 3),
          periodo: _period,
          tipo: index == 2 ? 'OFICIAL' : 'PARTICULAR',
          minutos: 60 + index * 30,
          minutosAplicados: 60 + index * 30,
          minutosExcedidos: 0,
          excedido: false,
          createdAt: DateTime(2026, 10, 12 + index * 3, 9, 30),
          usuarioCargaNombre: 'Cuenta',
          usuarioCargaApellido: 'DEMO',
        ),
    ];
    const screens = {
      'panel': null,
      'horas': 'Horas',
      'francos': 'Francos',
      'imprevistos': 'Imprevisto',
      'medicos': 'Médicos',
      'suplencias': 'Suplencias',
    };
    for (final entry in screens.entries) {
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(ProviderScope(
        key: ValueKey(entry.key),
        overrides: [
          supabaseClientProvider.overrideWith((ref) =>
              throw StateError('Live data is disabled in the demo gallery.')),
          currentRolesProvider.overrideWith((ref) async =>
              const CurrentRoles({'HORAS_LECTURA', 'HORAS_CARGA'})),
          currentUserProfileProvider.overrideWith((ref) async =>
              const CurrentUserProfile(apellido: 'DEMO', nombre: 'Cuenta')),
          puedeLeerFrancosProvider.overrideWith((ref) async => true),
          puedeUsarBancoFrancosProvider.overrideWith((ref) async => true),
          puedeAdministrarBancoFrancosProvider
              .overrideWith((ref) async => false),
          francosListadoProvider.overrideWith((ref) async => [
                for (var i = 1; i <= 3; i++)
                  FrancoPersona(
                      dni: 1000 + i,
                      apellido: 'DEMO',
                      nombre: 'Persona $i',
                      carreraId: 1,
                      carrera: 'Carrera de ejemplo',
                      saldoMinutos: 600 - i * 60,
                      tieneHorasCargadas: true),
              ]),
          francosMovimientosProvider.overrideWith((ref) async => [
                FrancoMovimiento(
                    id: 1,
                    dni: 1001,
                    carreraId: 1,
                    fecha: _date,
                    periodo: _period,
                    minutos: 60,
                    motivo: 'Franco de ejemplo',
                    observacion: 'Registro ficticio',
                    usuarioCarga: 'demo',
                    usuarioCargaNombre: 'Cuenta',
                    usuarioCargaApellido: 'DEMO',
                    usuarioModifica: '',
                    createdAt: _date,
                    updatedAt: _date),
              ]),
          puedeLeerImprevistosProvider.overrideWith((ref) async => true),
          puedeCargarImprevistosProvider.overrideWith((ref) async => true),
          puedeAdministrarImprevistosProvider
              .overrideWith((ref) async => false),
          imprevistosAnioProvider.overrideWith((ref) => 2026),
          imprevistosListadoProvider.overrideWith((ref) async => [
                for (var i = 1; i <= 3; i++)
                  ImprevistoPersona(
                      dni: 1000 + i,
                      apellido: 'DEMO',
                      nombre: 'Persona $i',
                      carreraId: 1,
                      carrera: 'Carrera de ejemplo',
                      usados: i,
                      restantes: 6 - i),
              ]),
          imprevistosRegistrosProvider.overrideWith((ref) async => [
                ImprevistoRegistro(
                    id: 1,
                    dni: 1001,
                    carreraId: 1,
                    fecha: _date,
                    anio: 2026,
                    observacion: 'Registro ficticio',
                    numeroOrden: 1,
                    createdAt: _date),
              ]),
          listadoProvider.overrideWith((ref) async => [
                const Persona(
                    apellido: 'DEMO',
                    nombre: 'Persona Uno',
                    dni: 1001,
                    carreraId: 1,
                    carrera: 'Carrera de ejemplo'),
              ]),
          listadoOficialesProvider.overrideWith((ref) async => []),
          periodoProvider.overrideWith((ref) => _period),
          fechaProvider.overrideWith((ref) => _date),
          registrosProvider.overrideWith((ref) async => horas),
          registrosPeriodoProvider.overrideWith((ref) async => horas),
          periodosConRegistrosProvider.overrideWith((ref) async => {_period}),
          puedeLeerMedicosProvider.overrideWith((ref) async => true),
          puedeCrearMedicosProvider.overrideWith((ref) async => true),
          puedeAdministrarMedicosProvider.overrideWith((ref) async => false),
          medicosPersonasProvider.overrideWith((ref) async => [
                const MedicoPersona(
                    dni: 1001,
                    apellido: 'DEMO',
                    nombre: 'Persona Uno',
                    legajo: 1),
                const MedicoPersona(
                    dni: 1002,
                    apellido: 'DEMO',
                    nombre: 'Persona Dos',
                    legajo: null),
              ]),
          medicosDomicilioProvider.overrideWith((ref, dni) async => null),
          partesMedicosProvider.overrideWith((ref) async => [_part]),
          medicosHoyProvider.overrideWith((ref) => _date),
          colaImpresionProvider
              .overrideWith((ref) => ColaImpresionController()),
          puedeLeerSuplenciasProvider.overrideWith((ref) async => true),
          suplenciasRepoProvider.overrideWith((ref) => const _DemoSuplencias()),
        ],
        child: RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
                useMaterial3: true,
                brightness: Brightness.dark,
                colorSchemeSeed: const Color(0xFF4F46E5),
                fontFamily: 'DemoUi'),
            locale: const Locale('es', 'AR'),
            supportedLocales: const [Locale('es', 'AR')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) => Column(children: [
              Material(
                  color: const Color(0xFF045E63),
                  child: const SizedBox(
                      height: 34,
                      child: Center(
                          child: Text(
                        'DEMOSTRACIÓN · DATOS FICTICIOS · SIN CONEXIÓN A DATOS REALES',
                        style: TextStyle(fontSize: 12, color: Colors.white),
                      )))),
              Expanded(child: child!),
            ]),
            home: const MainShell(),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      if (entry.value != null) {
        await tester.tap(find.text(entry.value!).first);
        await tester.pumpAndSettle();
      }
      if (entry.key == 'horas') {
        await tester.tap(find.text('Ver').first);
        await tester.pumpAndSettle();
      }
      if (entry.key == 'medicos') {
        await tester.tap(find.text('Partes registrados'));
        await tester.pumpAndSettle();
        // Image codecs finish outside the test clock. Wait for the actual PDF
        // image so that the screenshot cannot silently contain an empty sheet.
        for (var attempt = 0; attempt < 20; attempt++) {
          await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 50)));
          await tester.pump();
          if (tester
              .widgetList<RawImage>(find.byType(RawImage))
              .any((widget) => widget.image != null)) {
            break;
          }
        }
        expect(
            tester
                .widgetList<RawImage>(find.byType(RawImage))
                .any((widget) => widget.image != null),
            isTrue);
      }
      // Fail on unexpected UI errors instead of publishing broken captures.
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary = boundaryKey.currentContext!.findRenderObject()
            as RenderRepaintBoundary;
        final shot = await boundary.toImage();
        final png = await shot.toByteData(format: ui.ImageByteFormat.png);
        await Directory('docs/mockups/demo').create(recursive: true);
        await File('docs/mockups/demo/${entry.key}.png')
            .writeAsBytes(png!.buffer.asUint8List());
        shot.dispose();
      });
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
