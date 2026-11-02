import 'dart:async';

import 'package:app_horas/features/auth/application/auth_providers.dart';
import 'package:app_horas/features/auth/application/mfa_providers.dart';
import 'package:app_horas/features/auth/data/gestion_session_repository.dart';
import 'package:app_horas/features/auth/presentation/gestion_session_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mfa_widgets_test.dart' show FakeMfaRepository;
import 'periodic_mfa_guard_test.dart'
    show FixtureAuth, WorkPane, fixtureSession;

class _Reservation implements GestionSessionRepository {
  bool allowed = true;
  bool renewAllowed = true;
  bool fail = false;
  int acquisitions = 0;
  int renewals = 0;
  Completer<bool>? pending;

  @override
  Future<bool> acquire() async {
    acquisitions++;
    if (fail) throw StateError('Fixture unavailable');
    if (pending != null) return pending!.future;
    return allowed;
  }

  @override
  Future<bool> renew() async {
    renewals++;
    if (fail) throw StateError('Fixture unavailable');
    return renewAllowed;
  }

  @override
  Future<void> release() async {}
}

Future<FixtureAuth> _mount(WidgetTester tester, _Reservation reservation,
    {bool mfa = false, FakeMfaRepository? mfaRepository}) async {
  final auth = FixtureAuth(
      fixtureSession(DateTime.now().millisecondsSinceEpoch ~/ 1000, mfa: mfa));
  final factor = (mfaRepository ?? FakeMfaRepository())
    ..enabled = mfa
    ..verified = mfa;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authRepoProvider.overrideWithValue(auth),
      authSessionProvider.overrideWith((ref) async* {
        yield auth.current;
        yield* auth.bus.stream;
      }),
      mfaStatusProvider.overrideWith((ref) => factor.loadStatus()),
      gestionSessionRepositoryProvider.overrideWithValue(reservation),
    ],
    child: MaterialApp(
      builder: (context, child) => GestionSessionGuard(child: child!),
      home: const WorkPane(),
    ),
  ));
  await tester.pump();
  await tester.pump();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    unawaited(auth.bus.close());
    await tester.pump();
  });
  return auth;
}

void main() {
  testWidgets('espera la reserva del servidor antes de cargar los módulos',
      (tester) async {
    final reservation = _Reservation()..pending = Completer<bool>();
    await _mount(tester, reservation);
    expect(find.text('Comprobando sesión de Gestión…'), findsOneWidget);
    expect(find.byKey(const ValueKey('work')), findsNothing);
    reservation.pending!.complete(true);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('work')), findsOneWidget);
  });

  testWidgets('rechaza la segunda Gestión sin cerrar otra sesión de la cuenta',
      (tester) async {
    final reservation = _Reservation()..allowed = false;
    final auth = await _mount(tester, reservation, mfa: true);
    await tester.pumpAndSettle();
    expect(
        find.text('Esta cuenta ya tiene una Gestión abierta'), findsOneWidget);
    expect(find.byKey(const ValueKey('work')), findsNothing);
    expect(auth.logouts, 0);
    await tester.tap(find.text('Volver al inicio de sesión'));
    await tester.pumpAndSettle();
    expect(auth.logouts, 1);
    expect(find.text('LOGIN'), findsOneWidget);
  });

  testWidgets(
      'perder la reserva bloquea también diálogos y conserva el trabajo',
      (tester) async {
    final reservation = _Reservation();
    await _mount(tester, reservation);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('work')), 'Trabajo pendiente');
    await tester.tap(find.text('Abrir diálogo'));
    await tester.pumpAndSettle();
    reservation.renewAllowed = false;
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();
    expect(reservation.renewals, 1);
    expect(
        find.text('Esta cuenta ya tiene una Gestión abierta'), findsOneWidget);
    await tester.tap(find.text('Volver al trabajo'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('DIÁLOGO ORIGINAL'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Esta cuenta ya tiene una Gestión abierta'), findsNothing);
    await tester.tap(find.text('Volver al trabajo'));
    await tester.pumpAndSettle();
    expect(find.text('Trabajo pendiente'), findsOneWidget);
  });

  testWidgets(
      'una falla de red bloquea hasta volver a comprobar con el servidor',
      (tester) async {
    final reservation = _Reservation();
    await _mount(tester, reservation);
    await tester.pumpAndSettle();
    reservation.fail = true;
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();
    expect(find.text('No se pudo comprobar la sesión'), findsOneWidget);
    reservation.fail = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('No se pudo comprobar la sesión'), findsNothing);
  });

  testWidgets('renovar el JWT conserva la reserva y el formulario',
      (tester) async {
    final reservation = _Reservation();
    final auth = await _mount(tester, reservation, mfa: true);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('work')), 'Borrador');
    auth.renew();
    await tester.pumpAndSettle();
    expect(reservation.acquisitions, 1);
    expect(find.text('Borrador'), findsOneWidget);
  });

  testWidgets('revalidar MFA conserva el Navigator y el trabajo pendiente',
      (tester) async {
    final reservation = _Reservation();
    final factor = FakeMfaRepository();
    await _mount(tester, reservation, mfa: true, mfaRepository: factor);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('work')), 'Borrador MFA');
    await tester.tap(find.text('Abrir diálogo'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
        tester.element(find.byType(GestionSessionGuard)));
    factor.verified = false;
    container.invalidate(mfaStatusProvider);
    await tester.pumpAndSettle();
    expect(find.text('DIÁLOGO ORIGINAL'), findsOneWidget);
    factor.verified = true;
    container.invalidate(mfaStatusProvider);
    await tester.pumpAndSettle();
    expect(reservation.acquisitions, 2);
    expect(find.text('DIÁLOGO ORIGINAL'), findsOneWidget);
    await tester.tap(find.text('Volver al trabajo'));
    await tester.pumpAndSettle();
    expect(find.text('Borrador MFA'), findsOneWidget);
  });
}
