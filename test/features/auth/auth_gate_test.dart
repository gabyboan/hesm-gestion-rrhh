import 'dart:async';

import 'package:app_horas/core/startup/backend_capabilities.dart';
import 'package:app_horas/core/supabase/supabase_provider.dart';
import 'package:app_horas/features/auth/application/auth_providers.dart';
import 'package:app_horas/features/auth/application/mfa_providers.dart';
import 'package:app_horas/features/auth/application/session_timeout_provider.dart';
import 'package:app_horas/features/auth/application/session_timeout_service.dart';
import 'package:app_horas/features/auth/data/mfa_repository.dart';
import 'package:app_horas/features/auth/presentation/auth_gate.dart';
import 'package:app_horas/features/auth/presentation/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'periodic_mfa_guard_test.dart' show fixtureSession;

class _Timeout implements SessionTimeoutService {
  int stops = 0;

  @override
  void stop() => stops++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('abre el login sin sesión y detiene el control de inactividad',
      (tester) async {
    final timeout = _Timeout();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authSessionProvider.overrideWith((ref) => Stream<Session?>.value(null)),
        sessionTimeoutProvider.overrideWithValue(timeout),
      ],
      child: const MaterialApp(home: AuthGate()),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.byType(LoginPage), findsOneWidget);
    expect(timeout.stops, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'puede iniciar la sesión y volver al login si la base no es compatible',
      (tester) async {
    final timeout = _Timeout();
    final sessions = StreamController<Session?>.broadcast();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authSessionProvider.overrideWith((ref) async* {
          yield fixtureSession(DateTime.now().millisecondsSinceEpoch ~/ 1000);
          yield* sessions.stream;
        }),
        sessionTimeoutProvider.overrideWithValue(timeout),
        mfaStatusProvider.overrideWith((ref) async =>
            const MfaStatus(factors: [], sessionVerified: false)),
        supabaseClientProvider
            .overrideWith((ref) => throw const BackendUpdateRequired()),
      ],
      child: const MaterialApp(home: AuthGate()),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Actualización de la base pendiente'), findsOneWidget);

    sessions.add(null);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.byType(LoginPage), findsOneWidget);
    expect(timeout.stops, 2);

    await tester.pumpWidget(const SizedBox());
    unawaited(sessions.close());
    await tester.pump();
  });
}
