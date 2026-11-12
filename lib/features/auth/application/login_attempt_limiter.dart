/// Espera local complementaria al límite de Supabase Auth, compartida por
/// reconstrucciones del formulario. No almacena contraseñas ni datos en disco.
class LoginAttemptLimiter {
  LoginAttemptLimiter({DateTime Function()? now}) : _now = now ?? DateTime.now;
  final DateTime Function() _now;
  final _attempts = <String, _Attempts>{};
  static const window = Duration(minutes: 15);
  DateTime? _serverUntil;

  String _key(String email) => email.trim().toLowerCase();

  Duration remaining(String email) {
    final now = _now();
    final entry = _attempts[_key(email)];
    final dates = [
      if (_serverUntil != null) _serverUntil!,
      if (entry?.until != null) entry!.until!
    ];
    final seconds = dates.fold<int>(0, (result, until) {
      final delta = until.difference(now).inMilliseconds;
      final value = delta <= 0 ? 0 : (delta / 1000).ceil();
      return value > result ? value : result;
    });
    return Duration(seconds: seconds);
  }

  void invalidCredentials(String email) {
    final now = _now();
    final key = _key(email);
    _attempts.removeWhere((_, value) => now.difference(value.started) > window);
    final entry = _attempts.putIfAbsent(key, () => _Attempts(now));
    entry.failures++;
    if (entry.failures >= 5) {
      final wait = entry.failures == 5
          ? 30
          : entry.failures == 6
              ? 60
              : 300;
      entry.until = now.add(Duration(seconds: wait));
    }
    while (_attempts.length > 64) {
      _attempts.remove(_attempts.keys.first);
    }
  }

  void serverLimited({Duration retryAfter = const Duration(minutes: 1)}) {
    final until = _now().add(retryAfter);
    if (_serverUntil == null || until.isAfter(_serverUntil!)) {
      _serverUntil = until;
    }
  }

  void success(String email) {
    _attempts.remove(_key(email));
    _serverUntil = null;
  }
}

class _Attempts {
  _Attempts(this.started);
  final DateTime started;
  int failures = 0;
  DateTime? until;
}
