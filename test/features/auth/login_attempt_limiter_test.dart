import 'package:app_horas/features/auth/application/login_attempt_limiter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cinco errores generan espera y los siguientes la amplían', () {
    var now = DateTime(2026);
    final limiter = LoginAttemptLimiter(now: () => now);
    for (var i = 0; i < 4; i++) {
      limiter.invalidCredentials('a@example.invalid');
    }
    expect(limiter.remaining('a@example.invalid'), Duration.zero);
    limiter.invalidCredentials(' A@example.invalid ');
    expect(limiter.remaining('a@example.invalid').inSeconds, 30);
    now = now.add(const Duration(seconds: 30));
    limiter.invalidCredentials('a@example.invalid');
    expect(limiter.remaining('a@example.invalid').inSeconds, 60);
    now = now.add(const Duration(seconds: 60));
    limiter.invalidCredentials('a@example.invalid');
    expect(limiter.remaining('a@example.invalid').inSeconds, 300);
    limiter.success('a@example.invalid');
    expect(limiter.remaining('a@example.invalid'), Duration.zero);
  });

  test('el 429 aplica a todas las cuentas y los intentos viejos vencen', () {
    var now = DateTime(2026);
    final limiter = LoginAttemptLimiter(now: () => now);
    limiter.serverLimited();
    expect(limiter.remaining('otra@example.invalid').inSeconds, 60);
    now = now.add(const Duration(minutes: 16));
    for (var i = 0; i < 4; i++) {
      limiter.invalidCredentials('a@example.invalid');
    }
    now = now.add(const Duration(minutes: 16));
    limiter.invalidCredentials('a@example.invalid');
    expect(limiter.remaining('a@example.invalid'), Duration.zero);
  });
}
