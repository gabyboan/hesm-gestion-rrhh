import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SessionTimeoutService {
  SessionTimeoutService(this._sb);

  final SupabaseClient _sb;

  // Ajustá a tu gusto (y que coincida con lo que vos "prometés" al usuario)
  static const idleTimeout = Duration(minutes: 5);

  static const _kLastActivityMs = 'last_activity_at_ms';

  Timer? _timer;
  DateTime? _lastSaved; // throttle

  /// Llamalo SOLO cuando hay sesión válida (logueado)
  Future<void> start() async {
    // ✅ No reiniciar si ya está corriendo
    if (_timer != null) return;

    // Si ya arrancó la app y está vencido, cerramos YA
    final expired = await isExpired();
    if (expired) {
      await forceLogout();
      return;
    }

    // Marca actividad inicial al empezar (importante al reabrir)
    await touch(force: true);

    _timer = Timer(idleTimeout, _logout);
  }

  /// Reset por actividad (touch + reiniciar timer)
  Future<void> reset() async {
    // Si no está corriendo, arrancalo (pero sin loops)
    if (_timer == null) {
      await start();
      return;
    }

    await touch(); // persistente + throttle

    _timer!.cancel();
    _timer = Timer(idleTimeout, _logout);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Guarda última actividad en disco (persistente).
  /// Throttle para no escribir en cada movimiento del mouse.
  Future<void> touch({bool force = false}) async {
    final now = DateTime.now();
    if (!force && _lastSaved != null) {
      final diff = now.difference(_lastSaved!);
      if (diff < const Duration(seconds: 15)) return; // throttle
    }
    _lastSaved = now;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastActivityMs, now.millisecondsSinceEpoch);
  }

  Future<DateTime?> getLastActivity() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_kLastActivityMs);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<bool> isExpired() async {
    final last = await getLastActivity();
    if (last == null) {
      // ✅ primera vez / no hay registro: crear registro y permitir
      await touch(force: true);
      return false;
    }
    return DateTime.now().difference(last) > idleTimeout;
  }

  Future<void> forceLogout() async {
    stop();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLastActivityMs);
    if (_sb.auth.currentSession != null) {
      await _sb.auth.signOut();
    }
  }

  Future<void> _logout() async {
    // Timer venció: si hay sesión, cerramos
    await forceLogout();
  }
}
