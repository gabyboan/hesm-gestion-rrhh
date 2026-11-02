import 'dart:async';
import 'dart:convert';

import 'package:app_horas/features/auth/application/auth_providers.dart';
import 'package:app_horas/features/auth/application/mfa_providers.dart';
import 'package:app_horas/features/auth/data/auth_repository.dart';
import 'package:app_horas/features/auth/presentation/periodic_mfa_guard.dart';
import 'package:app_horas/features/auth/domain/session_verification_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'mfa_widgets_test.dart' show FakeMfaRepository;

Session fixtureSession(int timestamp, {bool mfa = true, int iat = 1}) {
  String part(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final token = '${part({'alg': 'HS256'})}.${part({
        'amr': [
          {
            'method': 'password',
            'timestamp': mfa ? timestamp - 100 : timestamp
          },
          if (mfa) {'method': 'totp', 'timestamp': timestamp},
        ],
        'iat': iat,
        'exp': iat + 3600
      })}.fixture';
  return Session(
      accessToken: token,
      tokenType: 'bearer',
      user: User.fromJson({
        'id': '00000000-0000-4000-8000-000000000011',
        'aud': 'authenticated',
        'role': 'authenticated',
        'created_at': '2026-01-01T00:00:00Z',
        'app_metadata': <String, Object>{},
        'user_metadata': <String, Object>{},
      })!);
}

class FixtureAuth extends AuthRepository {
  FixtureAuth(this.current)
      : super(SupabaseClient('http://127.0.0.1:1', 'fixture',
            authOptions: const AuthClientOptions(autoRefreshToken: false)));
  Session? current;
  int logouts = 0;
  final bus = StreamController<Session?>.broadcast();
  @override
  Session? get session => current;
  @override
  Future<void> signOut() async {
    logouts++;
    current = null;
    bus.add(null);
  }

  void renew() {
    current = fixtureSession(DateTime.now().millisecondsSinceEpoch ~/ 1000);
    bus.add(current);
  }
}

class FixtureMfa extends FakeMfaRepository {
  FixtureMfa(this.auth) {
    enabled = verified = true;
  }
  final FixtureAuth auth;
  bool confirmFails = false;
  @override
  Future<void> verify(String factorId, String code) async {
    await super.verify(factorId, code);
    auth.renew();
  }

  @override
  Future<void> confirmSessionAccess() async {
    if (confirmFails) throw StateError('fixture server rejects');
  }
}

class WorkPane extends ConsumerWidget {
  const WorkPane({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(authSessionProvider).valueOrNull == null
          ? const Text('LOGIN')
          : Scaffold(
              body: Column(children: [
              const TextField(
                  key: ValueKey('work'),
                  decoration: InputDecoration(labelText: 'Trabajo')),
              TextButton(
                  onPressed: () => showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                              title: const Text('DIÁLOGO ORIGINAL'),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Volver al trabajo'))
                              ])),
                  child: const Text('Abrir diálogo')),
            ]));
}

Future<(FixtureAuth, FixtureMfa)> mount(WidgetTester tester,
    {bool mfa = true}) async {
  final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final auth = FixtureAuth(fixtureSession(ts - 3580, mfa: mfa));
  final repo = FixtureMfa(auth);
  if (!mfa) repo.enabled = repo.verified = false;
  await tester.pumpWidget(ProviderScope(
      overrides: [
        authRepoProvider.overrideWithValue(auth),
        authSessionProvider.overrideWith((ref) async* {
          yield auth.current;
          yield* auth.bus.stream;
        }),
        mfaRepositoryProvider.overrideWithValue(repo),
        mfaStatusProvider.overrideWith((ref) => repo.loadStatus()),
      ],
      child: MaterialApp(
          builder: (context, child) => PeriodicMfaGuard(child: child!),
          home: const WorkPane())));
  await tester.pumpAndSettle();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    unawaited(auth.bus.close());
    await tester.pump();
  });
  return (auth, repo);
}

void main() {
  test('el refresh no cambia la hora de verificación firmada', () {
    final a = fixtureSession(1700000000, iat: 1).accessToken;
    final b = fixtureSession(1700000000, iat: 99999).accessToken;
    expect(sessionVerificationDeadline(a, mfaEnabled: true),
        sessionVerificationDeadline(b, mfaEnabled: true));
    expect(sessionVerificationDeadline('invalido', mfaEnabled: true), isNull);
  });
  testWidgets(
      'bloquea diálogos y conserva el borrador después del código válido',
      (tester) async {
    await mount(tester);
    await tester.enterText(find.byKey(const ValueKey('work')), 'BORRADOR');
    await tester.tap(find.text('Abrir diálogo'));
    await tester.pumpAndSettle();
    expect(find.text('DIÁLOGO ORIGINAL'), findsOneWidget);
    await tester.pump(const Duration(seconds: 21));
    await tester.pumpAndSettle();
    expect(find.text('Verificá tu identidad para continuar'), findsOneWidget);
    expect(find.text('DIÁLOGO ORIGINAL'), findsNothing);
    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text('Verificar código'));
    await tester.pumpAndSettle();
    expect(find.text('Verificá tu identidad para continuar'), findsNothing);
    expect(find.text('DIÁLOGO ORIGINAL'), findsOneWidget);
    await tester.tap(find.text('Volver al trabajo'));
    await tester.pumpAndSettle();
    expect(find.text('BORRADOR'), findsOneWidget);
  });
  testWidgets(
      'código incorrecto, Escape y clic exterior no habilitan el trabajo',
      (tester) async {
    final (auth, _) = await mount(tester);
    await tester.pump(const Duration(seconds: 21));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '000000');
    await tester.tap(find.text('Verificar código'));
    await tester.pumpAndSettle();
    expect(find.textContaining('El código no es válido'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('work')), findsNothing);
    expect(find.text('Verificar código'), findsOneWidget);
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
    expect(auth.logouts, 1);
    expect(find.text('LOGIN'), findsOneWidget);
  });
  testWidgets('no desbloquea si el servidor rechaza y permite reintentar',
      (tester) async {
    final (_, repo) = await mount(tester);
    repo.confirmFails = true;
    await tester.pump(const Duration(seconds: 21));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text('Verificar código'));
    await tester.pumpAndSettle();
    expect(find.text('Verificá tu identidad para continuar'), findsOneWidget);
    repo.confirmFails = false;
    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text('Verificar código'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('work')), findsOneWidget);
  });
  testWidgets('sin MFA cierra al vencer y no inscribe ningún factor',
      (tester) async {
    final (auth, repo) = await mount(tester, mfa: false);
    await tester.pump(const Duration(seconds: 21));
    await tester.pumpAndSettle();
    expect(auth.logouts, 1);
    expect(repo.enrollments, 0);
    expect(find.text('LOGIN'), findsOneWidget);
  });

  testWidgets('un error al recargar el estado no retira un bloqueo activo',
      (tester) async {
    final (_, repo) = await mount(tester);
    await tester.pump(const Duration(seconds: 21));
    await tester.pumpAndSettle();
    repo.failStatus = true;
    ProviderScope.containerOf(tester.element(find.byType(PeriodicMfaGuard)),
            listen: false)
        .invalidate(mfaStatusProvider);
    await tester.pumpAndSettle();
    expect(find.text('Verificá tu identidad para continuar'), findsOneWidget);
    expect(find.byKey(const ValueKey('work')), findsNothing);
  });
}
