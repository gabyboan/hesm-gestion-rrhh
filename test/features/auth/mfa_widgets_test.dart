import 'dart:async';

import 'package:app_horas/features/auth/application/mfa_providers.dart';
import 'package:app_horas/features/auth/application/auth_providers.dart';
import 'package:app_horas/features/auth/data/mfa_repository.dart';
import 'package:app_horas/features/auth/presentation/mfa_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeMfaRepository implements MfaRepository {
  bool enabled = false;
  bool verified = false;
  bool failStatus = false;
  int enrollments = 0;
  final removed = <String>[];
  Completer<void>? verification;
  @override
  bool get sessionVerified => verified;
  @override
  Future<MfaStatus> loadStatus() async {
    if (failStatus) throw StateError('fixture error');
    return MfaStatus(
        factors: enabled
            ? [const MfaFactorInfo('fixture-factor', 'Autenticadora 1')]
            : [],
        sessionVerified: verified);
  }

  @override
  Future<MfaEnrollment> enroll() async {
    enrollments++;
    return const MfaEnrollment(
        id: 'fixture-factor',
        secret: 'JBSWY3DPEHPK3PXP',
        uri: 'otpauth://totp/Fixture?secret=JBSWY3DPEHPK3PXP&issuer=Fixture');
  }

  @override
  Future<void> verify(String factorId, String code) async {
    if (code != '123456') {
      throw const AuthException('fixture invalid',
          code: 'mfa_verification_failed');
    }
    await verification?.future;
    enabled = verified = true;
  }

  @override
  Future<void> confirmSessionAccess() async {}

  @override
  Future<void> unenroll(String factorId) async {
    removed.add(factorId);
    enabled = false;
  }
}

Widget app(FakeMfaRepository repository, Widget child,
        {Stream<Session?>? sessions}) =>
    ProviderScope(
      overrides: [
        authSessionProvider
            .overrideWith((ref) => sessions ?? Stream.value(null)),
        mfaRepositoryProvider.overrideWithValue(repository),
        mfaStatusProvider.overrideWith((ref) => repository.loadStatus()),
      ],
      child: MaterialApp(home: child),
    );

void main() {
  testWidgets('no exige alta MFA a quien no la eligió', (tester) async {
    final repo = FakeMfaRepository();
    await tester.pumpWidget(app(repo, const MfaGate(child: Text('MODULO'))));
    await tester.pumpAndSettle();
    expect(find.text('MODULO'), findsOneWidget);
    expect(repo.enrollments, 0);
  });

  testWidgets('AAL1 con factor activo bloquea el módulo hasta verificar',
      (tester) async {
    final repo = FakeMfaRepository()..enabled = true;
    await tester.pumpWidget(app(repo, const MfaGate(child: Text('MODULO'))));
    await tester.pumpAndSettle();
    expect(find.text('MODULO'), findsNothing);
    await tester.enterText(find.byType(TextField), '000000');
    await tester.tap(find.text('Verificar código'));
    await tester.pumpAndSettle();
    expect(find.text('MODULO'), findsNothing);
    expect(find.textContaining('El código no es válido'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text('Verificar código'));
    await tester.pumpAndSettle();
    expect(find.text('MODULO'), findsOneWidget);
  });

  testWidgets('una sesión AAL2 con MFA puede entrar', (tester) async {
    final repo = FakeMfaRepository()
      ..enabled = true
      ..verified = true;
    await tester.pumpWidget(app(repo, const MfaGate(child: Text('MODULO'))));
    await tester.pumpAndSettle();
    expect(find.text('MODULO'), findsOneWidget);
  });

  testWidgets('un error al consultar factores no permite saltear MFA',
      (tester) async {
    final repo = FakeMfaRepository()..failStatus = true;
    await tester.pumpWidget(app(repo, const MfaGate(child: Text('MODULO'))));
    await tester.pumpAndSettle();
    expect(find.text('MODULO'), findsNothing);
    expect(find.text('Reintentar'), findsOneWidget);
    repo.failStatus = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('MODULO'), findsOneWidget);
  });

  Future<void> openSettings(WidgetTester tester, FakeMfaRepository repo) async {
    await tester.binding.setSurfaceSize(const Size(1100, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(repo, const Scaffold(body: MfaSettingsTile())));
    await tester.tap(find.text('Verificación en dos pasos'));
    await tester.pumpAndSettle();
  }

  testWidgets('cancelar el alta elimina el factor pendiente sin activar MFA',
      (tester) async {
    final repo = FakeMfaRepository();
    await openSettings(tester, repo);
    await tester.tap(find.text('Configurar autenticadora'));
    await tester.pumpAndSettle();
    expect(repo.enabled, isFalse);
    expect(repo.enrollments, 1);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(repo.removed, ['fixture-factor']);
    expect(repo.enabled, isFalse);
  });

  testWidgets('confirmar el código activa MFA y cerrar no lo elimina',
      (tester) async {
    final repo = FakeMfaRepository();
    await openSettings(tester, repo);
    await tester.tap(find.text('Configurar autenticadora'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text('Activar con código'));
    await tester.pumpAndSettle();
    expect(find.text('Doble factor activado.'), findsOneWidget);
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
    expect(repo.enabled, isTrue);
    expect(repo.removed, isEmpty);
  });

  testWidgets('desmontar durante la verificación no borra un factor activado',
      (tester) async {
    final repo = FakeMfaRepository()..verification = Completer<void>();
    await openSettings(tester, repo);
    await tester.tap(find.text('Configurar autenticadora'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text('Activar con código'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    repo.verification!.complete();
    await tester.pumpAndSettle();
    expect(repo.enabled, isTrue);
    expect(repo.removed, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desactivar requiere confirmación y conserva la cuenta',
      (tester) async {
    final repo = FakeMfaRepository()
      ..enabled = true
      ..verified = true;
    await openSettings(tester, repo);
    await tester.tap(find.text('Desactivar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(repo.enabled, isTrue);
    await tester.tap(find.text('Desactivar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desactivar').last);
    await tester.pumpAndSettle();
    expect(repo.enabled, isFalse);
    expect(repo.removed, ['fixture-factor']);
    expect(find.text('Configurar autenticadora'), findsOneWidget);
  });

  testWidgets('cerrar sesión retira el diálogo con QR y su factor pendiente',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final bus = StreamController<Session?>();
    final session = Session(
      accessToken: 'fixture-token',
      tokenType: 'bearer',
      user: User.fromJson({
        'id': '00000000-0000-4000-8000-000000000011',
        'aud': 'authenticated',
        'role': 'authenticated',
        'created_at': '2026-01-01T00:00:00Z',
        'app_metadata': <String, Object>{},
        'user_metadata': <String, Object>{},
      })!,
    );
    Stream<Session?> sessions() async* {
      yield session;
      yield* bus.stream;
    }

    final repo = FakeMfaRepository();
    await tester.pumpWidget(app(repo, const Scaffold(body: MfaSettingsTile()),
        sessions: sessions()));
    await tester.tap(find.text('Verificación en dos pasos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Configurar autenticadora'));
    await tester.pumpAndSettle();
    expect(find.text('Activar con código'), findsOneWidget);
    bus.add(null);
    await tester.pumpAndSettle();
    expect(find.text('Activar con código'), findsNothing);
    expect(repo.removed, ['fixture-factor']);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    unawaited(bus.close());
    await tester.pump();
  });
}
