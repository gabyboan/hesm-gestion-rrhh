// lib/features/auth/presentation/auth_gate.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/theme_mode_provider.dart';
import '../../medicos/application/cola_impresion_provider.dart';
import '../../preferences/application/user_preferences_providers.dart';
import '../../preferences/domain/user_preferences.dart';
import '../../shell/presentation/main_shell.dart';
import '../application/auth_providers.dart';
import '../application/session_timeout_provider.dart';
import 'auth_activity_listener.dart';
import 'login_page.dart';

/// Sesión actual de Supabase.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(authSessionProvider);

    return sessionAsync.when(
      data: (session) {
        if (session == null) {
          return const _LoggedOutGate();
        }

        return _LoggedInGate(
          key: ValueKey(session.user.id),
        );
      },
      loading: () => const _AuthLoading(),
      error: (e, _) => _AuthError(error: e),
    );
  }
}

/// Estado no autenticado.
///
/// Detiene el control de inactividad y muestra login.
class _LoggedOutGate extends ConsumerStatefulWidget {
  const _LoggedOutGate();

  @override
  ConsumerState<_LoggedOutGate> createState() => _LoggedOutGateState();
}

class _LoggedOutGateState extends ConsumerState<_LoggedOutGate> {
  @override
  void initState() {
    super.initState();
    ref.read(sessionTimeoutProvider).stop();
  }

  @override
  Widget build(BuildContext context) {
    return const LoginPage();
  }
}

/// Estado autenticado.
///
/// Antes de entrar a la app valida/arranca el control de inactividad.
/// Si la sesión estaba vencida por inactividad persistente, `start()` ejecuta
/// logout y el stream de auth termina reconstruyendo el gate hacia LoginPage.
class _LoggedInGate extends ConsumerStatefulWidget {
  const _LoggedInGate({super.key});

  @override
  ConsumerState<_LoggedInGate> createState() => _LoggedInGateState();
}

class _LoggedInGateState extends ConsumerState<_LoggedInGate> {
  late final Future<void> _startTimeoutFuture;

  @override
  void initState() {
    super.initState();
    ref.invalidate(userPreferencesProvider);
    ref.invalidate(currentUserProfileProvider);
    _startTimeoutFuture = _startAuthenticatedSession();
  }

  Future<void> _startAuthenticatedSession() async {
    var preferences = UserPreferences.defaults;

    try {
      preferences = await ref.read(userPreferencesProvider.future);
    } catch (_) {
      // La app sigue funcionando con valores seguros si la migración todavía
      // no fue aplicada o hay una falla temporal al cargar preferencias.
    }

    ref.read(themeModeProvider.notifier).state = preferences.themeMode;
    final timeoutService = ref.read(sessionTimeoutProvider)
      ..configure(preferences.idleTimeout);
    await timeoutService.start();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _startTimeoutFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _AuthLoading();
        }

        if (snapshot.hasError) {
          return _AuthError(error: snapshot.error!);
        }

        return ProviderScope(
          overrides: [
            colaImpresionProvider
                .overrideWith((ref) => ColaImpresionController()),
          ],
          child: const AuthActivityListener(child: MainShell()),
        );
      },
    );
  }
}

class _AuthLoading extends StatelessWidget {
  const _AuthLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _AuthError extends ConsumerStatefulWidget {
  final Object error;

  const _AuthError({
    required this.error,
  });

  @override
  ConsumerState<_AuthError> createState() => _AuthErrorState();
}

class _AuthErrorState extends ConsumerState<_AuthError> {
  @override
  void initState() {
    super.initState();
    ref.read(sessionTimeoutProvider).stop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Auth error: ${widget.error}'),
      ),
    );
  }
}
