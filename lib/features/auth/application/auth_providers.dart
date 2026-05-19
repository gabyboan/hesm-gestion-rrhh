import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../data/auth_repository.dart';

/// Repositorio de autenticación.
///
/// Centraliza el acceso a Supabase Auth desde la capa de aplicación.
/// La UI no debería crear repositorios directamente.
final authRepoProvider = Provider<AuthRepository>((ref) {
  final sb = ref.watch(supabaseClientProvider);
  return AuthRepository(sb);
});

/// Sesión actual de Supabase.
///
/// Emite primero la sesión actualmente disponible y luego escucha los cambios
/// futuros de autenticación.
///
/// Esto evita depender de que Supabase emita inmediatamente un evento inicial.
final authSessionProvider = StreamProvider<Session?>((ref) async* {
  final repo = ref.watch(authRepoProvider);

  yield repo.session;

  yield* repo.onAuthStateChange.map((state) => state.session);
});
