import 'package:supabase_flutter/supabase_flutter.dart';

class MfaFactorInfo {
  const MfaFactorInfo(this.id, this.name);
  final String id;
  final String name;
}

class MfaStatus {
  const MfaStatus({required this.factors, required this.sessionVerified});
  final List<MfaFactorInfo> factors;
  final bool sessionVerified;
  bool get enabled => factors.isNotEmpty;
  bool get requiresChallenge => enabled && !sessionVerified;
}

/// La clave y URI de alta viven solo en memoria mientras se configura el factor.
class MfaEnrollment {
  const MfaEnrollment(
      {required this.id, required this.secret, required this.uri});
  final String id;
  final String secret;
  final String uri;
}

abstract interface class MfaRepository {
  bool get sessionVerified;
  Future<MfaStatus> loadStatus();
  Future<MfaEnrollment> enroll();
  Future<void> verify(String factorId, String code);
  Future<void> confirmSessionAccess();
  Future<void> unenroll(String factorId);
}

class SupabaseMfaRepository implements MfaRepository {
  SupabaseMfaRepository(this._client);
  final SupabaseClient _client;

  @override
  bool get sessionVerified =>
      _client.auth.mfa.getAuthenticatorAssuranceLevel().currentLevel ==
      AuthenticatorAssuranceLevels.aal2;

  @override
  Future<MfaStatus> loadStatus() async {
    // GET /auth/v1/user consulta los factores actuales sin renovar la sesión.
    // listFactors() del SDK instalado renueva y emite eventos: evitar un bucle.
    final user = (await _client.auth.getUser()).user;
    if (user == null) throw const AuthException('Sesión no disponible.');
    final verified = (user.factors ?? [])
        .where((factor) => factor.status == FactorStatus.verified)
        .toList();
    if (verified.any((factor) => factor.factorType != FactorType.totp)) {
      throw const AuthException('Factor no compatible.',
          code: 'mfa_unsupported');
    }
    return MfaStatus(
      factors: [
        for (var i = 0; i < verified.length; i++)
          MfaFactorInfo(verified[i].id, 'Autenticadora ${i + 1}'),
      ],
      sessionVerified: sessionVerified,
    );
  }

  @override
  Future<MfaEnrollment> enroll() async {
    final result = await _client.auth.mfa.enroll(issuer: 'HESM RRHH');
    final totp = result.totp;
    if (totp == null) throw StateError('No se recibió la configuración TOTP.');
    return MfaEnrollment(id: result.id, secret: totp.secret, uri: totp.uri);
  }

  @override
  Future<void> verify(String factorId, String code) async {
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      throw const FormatException('Ingresá el código de seis dígitos.');
    }
    await _client.auth.mfa.challengeAndVerify(factorId: factorId, code: code);
  }

  @override
  Future<void> confirmSessionAccess() async {
    await _client.rpc('verificar_mfa_opcional');
  }

  @override
  Future<void> unenroll(String factorId) async {
    // Supabase requiere AAL2 para retirar un factor ya verificado.
    await _client.auth.mfa.unenroll(factorId);
  }
}

String mfaErrorText(Object error) {
  if (error is FormatException) return 'Ingresá el código de seis dígitos.';
  if (error is AuthException) {
    switch (error.code) {
      case 'mfa_verification_failed':
        return 'El código no es válido. Probá con el código actual de tu autenticadora.';
      case 'mfa_challenge_expired':
        return 'El código venció. Ingresá el código actual y volvé a intentar.';
      case 'over_request_rate_limit':
        return 'Esperá un momento antes de volver a intentar.';
      case 'mfa_unsupported':
        return 'Tu cuenta usa otro tipo de segundo factor. Contactá al administrador.';
    }
  }
  // Los errores no deben volcar tokens, códigos ni respuestas de alta en la UI.
  return 'No se pudo completar la verificación. Revisá la conexión y volvé a intentar.';
}
