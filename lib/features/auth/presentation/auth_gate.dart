import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../application/session_timeout_provider.dart';
import '../data/auth_repository.dart';
import '../../horas/presentation/horas_shell.dart';
import 'login_page.dart';

final authRepoProvider = Provider<AuthRepository>((ref) {
  final sb = ref.watch(supabaseClientProvider);
  return AuthRepository(sb);
});

final authSessionProvider = StreamProvider<Session?>((ref) {
  final repo = ref.watch(authRepoProvider);

  // Emite señal de sesión actual y luego cambios
  return repo.onAuthStateChange.map((_) => repo.session);
});

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(authSessionProvider);
    final timeout = ref.read(sessionTimeoutProvider);

    return sessionAsync.when(
      data: (session) {
        if (session == null) {
          // No logueado => no corre el timer
          timeout.stop();
          return const LoginPage();
        }

        // Logueado => validar inactividad persistente antes de entrar
        return FutureBuilder<void>(
          future: timeout.start(),
          builder: (context, snap) {
            // Mientras valida/arranca el timer, mostramos loader
            if (snap.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // Si estaba vencido, start() hace logout y el stream va a emitir null,
            // por lo que en el próximo rebuild caerá a LoginPage.
            return const HorasShell();
          },
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) {
        // Ante error: por seguridad, destruimos timer
        timeout.stop();
        return Scaffold(body: Center(child: Text('Auth error: $e')));
      },
    );
  }
}
