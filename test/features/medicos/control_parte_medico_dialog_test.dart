import 'package:app_horas/features/medicos/application/medicos_providers.dart';
import 'package:app_horas/features/medicos/data/medicos_repository.dart';
import 'package:app_horas/features/medicos/domain/control_parte_medico.dart';
import 'package:app_horas/features/medicos/domain/parte_medico_qr.dart';
import 'package:app_horas/features/medicos/presentation/control_parte_medico_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repositorio extends Fake implements MedicosRepository {
  bool anulado = false;
  int guardados = 0;
  String? codigoConsultado;
  final controles = <ControlParteMedico>[];
  int? diasGuardados;
  int? versionEsperada;
  bool rechazar = false;

  @override
  Future<DocumentoParteMedico> documento({int? id, String? codigo}) async {
    codigoConsultado = codigo;
    return DocumentoParteMedico.fromJson({
      'parte': {
        'id': 42,
        'dni': 12345678,
        'fecha': '2026-10-23',
        'tipo': 'CONSULTORIO',
        'empleado_apellido': 'Demo',
        'empleado_nombre': 'Persona',
        'codigo_qr': '00000422',
        'anulado_at': anulado ? '2026-10-23T12:00:00Z' : null,
      },
      'controles': [],
    }).conControles(controles);
  }

  @override
  Future<ControlParteMedico> guardarControl({
    required ParteMedicoQr qr,
    required DateTime fechaDesde,
    required int diasAprobados,
    required String medicoNombre,
    required String medicoMatricula,
    required int versionEsperada,
    String? motivoRectificacion,
  }) async {
    guardados++;
    if (rechazar) {
      throw StateError('El control cambio. Volve a consultar el parte.');
    }
    diasGuardados = diasAprobados;
    this.versionEsperada = versionEsperada;
    final control = ControlParteMedico(
      version: versionEsperada + 1,
      fechaDesde: fechaDesde,
      diasAprobados: diasAprobados,
      fechaHasta: diasAprobados == 0
          ? null
          : fechaDesde.add(Duration(days: diasAprobados - 1)),
      medicoNombre: medicoNombre,
      medicoMatricula: medicoMatricula,
      usuarioRegistro: 'usuario-de-prueba',
      registradoAt: DateTime.utc(2026, 10, 23, 12),
      motivoRectificacion: motivoRectificacion,
    );
    controles.insert(0, control);
    return control;
  }
}

extension on DocumentoParteMedico {
  DocumentoParteMedico conControles(List<ControlParteMedico> value) =>
      DocumentoParteMedico(
          parte: parte, anulado: anulado, controles: [...value]);
}

Finder campo(String label) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label);

void main() {
  Future<void> abrir(WidgetTester tester, _Repositorio repo,
      {bool controlar = true, bool admin = false, int? id}) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        medicosRepoProvider.overrideWithValue(repo),
        puedeControlarMedicosProvider.overrideWith((ref) async => controlar),
        puedeAdministrarMedicosProvider.overrideWith((ref) async => admin),
      ],
      child: MaterialApp(
          home: Scaffold(body: ControlParteMedicoDialog(parteId: id))),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> completar(WidgetTester tester) async {
    await tester.enterText(campo('Inicio (dd/mm/aaaa)'), '23/10/2026');
    await tester.enterText(campo('Días corridos aprobados'), '3');
    await tester.enterText(campo('Médico del papel'), 'Médico ficticio');
    await tester.enterText(campo('Matrícula'), 'DEMO-123');
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
  }

  testWidgets('consulta el QR, confirma el papel y guarda una sola devolución',
      (tester) async {
    final repo = _Repositorio();
    await abrir(tester, repo);
    await tester.enterText(
        campo('Código del parte o contenido del QR'), 'HESM:PM:1:00000422');
    await tester.tap(find.text('Consultar parte'));
    await tester.pumpAndSettle();
    expect(repo.codigoConsultado, 'HESM:PM:1:00000422');
    expect(find.text('Pendiente de devolución'), findsOneWidget);
    final boton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Registrar devolución'));
    expect(boton.onPressed, isNull);
    await completar(tester);
    await tester.tap(find.text('Registrar devolución'));
    await tester.pumpAndSettle();
    expect(repo.guardados, 1);
    expect(repo.diasGuardados, 3);
    expect(repo.versionEsperada, 0);
    expect(find.text('Registrar devolución'), findsNothing);
    expect(
        find.text('Devolución registrada · 3 días aprobados'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('un parte anulado y un usuario de lectura no ofrecen guardar',
      (tester) async {
    final repo = _Repositorio()..anulado = true;
    await abrir(tester, repo, id: 42, controlar: false);
    expect(find.text('PARTE ANULADO · No admite devolución.'), findsOneWidget);
    expect(find.text('Registrar devolución'), findsNothing);
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(repo.guardados, 0);
  });

  testWidgets('valida días y fechas y no reintenta una escritura rechazada',
      (tester) async {
    final repo = _Repositorio()..rechazar = true;
    await abrir(tester, repo, id: 42);
    await completar(tester);
    await tester.enterText(campo('Días corridos aprobados'), '-2');
    await tester.enterText(campo('Inicio (dd/mm/aaaa)'), '31/02/2026');
    await tester.tap(find.text('Registrar devolución'));
    await tester.pumpAndSettle();
    expect(repo.guardados, 0);
    expect(find.text('Ingresá una cantidad entera entre 0 y 3650.'),
        findsOneWidget);
    await tester.enterText(campo('Días corridos aprobados'), '3');
    await tester.enterText(campo('Inicio (dd/mm/aaaa)'), '23/10/2026');
    await tester.tap(find.text('Registrar devolución'));
    await tester.pumpAndSettle();
    expect(repo.guardados, 1);
    expect(find.textContaining('El control cambio.'), findsOneWidget);
  });
}
