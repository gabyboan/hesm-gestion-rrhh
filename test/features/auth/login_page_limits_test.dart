import 'package:app_horas/features/auth/application/auth_providers.dart';
import 'package:app_horas/features/auth/application/login_attempt_limiter.dart';
import 'package:app_horas/features/auth/application/login_attempt_provider.dart';
import 'package:app_horas/features/auth/application/session_timeout_provider.dart';
import 'package:app_horas/features/auth/application/session_timeout_service.dart';
import 'package:app_horas/features/auth/data/auth_repository.dart';
import 'package:app_horas/features/auth/presentation/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:app_horas/core/diagnostics/app_diagnostics.dart';

class LoginFixture implements AuthRepository {
  Object failure = const AuthException('Invalid login credentials',
      code: 'invalid_credentials');
  int requests = 0;
  @override
  Future<void> signIn({required String email, required String password}) async {
    requests++;
    throw failure;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TimeoutFixture implements SessionTimeoutService {
  @override
  Future<void> prepareForLogin() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DiagnosticsFixture extends AppDiagnostics {
  DiagnosticsFixture() : super(Directory.systemTemp);
  @override
  Future<void> record(String component, Object error) async {}
}

void main() {
  Future<void> open(WidgetTester tester, LoginFixture repository,
      LoginAttemptLimiter limiter) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ProviderScope(overrides: [
      authRepoProvider.overrideWithValue(repository),
      sessionTimeoutProvider.overrideWithValue(TimeoutFixture()),
      loginAttemptLimiterProvider.overrideWithValue(limiter),
    ], child: MaterialApp(home: LoginPage(diagnostics: DiagnosticsFixture()))));
    await tester.enterText(
        find.byType(TextFormField).at(0), 'fixture@example.invalid');
    await tester.enterText(
        find.byType(TextFormField).at(1), 'fixture-password');
  }

  testWidgets('cinco contraseñas incorrectas deshabilitan el botón y Enter',
      (tester) async {
    final repository = LoginFixture();
    final limiter = LoginAttemptLimiter();
    await open(tester, repository, limiter);
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('Ingresar'));
      await tester.pump();
      await tester.pump();
    }
    expect(repository.requests, 5);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(find.textContaining('30 segundos'), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(repository.requests, 5);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      '429 informa espera; los errores de red no cuentan como contraseña',
      (tester) async {
    final repository = LoginFixture()
      ..failure = StateError('fixture network private-token');
    final limiter = LoginAttemptLimiter();
    await open(tester, repository, limiter);
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.text('Ingresar'));
      await tester.pump();
      await tester.pump();
    }
    expect(limiter.remaining('fixture@example.invalid'), Duration.zero);
    expect(find.textContaining('private-token'), findsNothing);
    repository.failure = const AuthException('fixture rate',
        statusCode: '429', code: 'over_request_rate_limit');
    await tester.tap(find.text('Ingresar'));
    await tester.pump();
    await tester.pump();
    expect(limiter.remaining('fixture@example.invalid').inSeconds, 60);
    expect(find.textContaining('demasiados intentos'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
