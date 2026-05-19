// lib/features/auth/data/auth_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repositorio de autenticación.
///
/// Encapsula las operaciones de login, logout y acceso al estado actual
/// de autenticación usando Supabase.
///
/// Mantener Supabase aislado acá evita que la UI dependa directamente
/// de `SupabaseClient`.
class AuthRepository {
  final SupabaseClient _sb;

  AuthRepository(this._sb);

  /// Sesión actual.
  ///
  /// Devuelve `null` si no hay usuario autenticado.
  Session? get session => _sb.auth.currentSession;

  /// Usuario actual.
  ///
  /// Devuelve `null` si no hay sesión activa.
  User? get user => _sb.auth.currentUser;

  /// Indica si hay una sesión activa.
  bool get isLoggedIn => session != null;

  /// Stream de cambios de autenticación.
  ///
  /// Sirve para reaccionar ante login, logout, refresh de token, etc.
  Stream<AuthState> get onAuthStateChange => _sb.auth.onAuthStateChange;

  /// Inicia sesión con email y contraseña.
  ///
  /// Lanza [AuthException] si Supabase rechaza las credenciales.
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _sb.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } on AuthException {
      rethrow;
    } catch (e) {
      throw Exception('No se pudo iniciar sesión: $e');
    }
  }

  /// Cierra la sesión actual.
  Future<void> signOut() async {
    try {
      await _sb.auth.signOut();
    } on AuthException {
      rethrow;
    } catch (e) {
      throw Exception('No se pudo cerrar sesión: $e');
    }
  }
}
