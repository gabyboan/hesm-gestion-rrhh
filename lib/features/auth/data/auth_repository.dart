import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  final SupabaseClient _sb;
  AuthRepository(this._sb);

  Session? get session => _sb.auth.currentSession;

  Stream<AuthState> get onAuthStateChange => _sb.auth.onAuthStateChange;

  Future<void> signIn({required String email, required String password}) async {
    await _sb.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _sb.auth.signOut();
  }
}
