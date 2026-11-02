import 'dart:convert';

/// Orienta el bloqueo de la interfaz. La autorización real se valida en Postgres.
DateTime? sessionVerificationDeadline(String token,
    {required bool mfaEnabled}) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    final claims = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
    if (claims is! Map || claims['amr'] is! List) return null;
    final timestamps = <int>[];
    for (final entry in claims['amr'] as List) {
      if (entry is! Map || entry['timestamp'] is! int) continue;
      final method = entry['method'];
      if (method is! String || (mfaEnabled && method != 'totp')) continue;
      final timestamp = entry['timestamp'] as int;
      if (timestamp > 0 && timestamp < 1000000000000) timestamps.add(timestamp);
    }
    if (timestamps.isEmpty) return null;
    timestamps.sort();
    // Un refresh modifica iat/exp, pero no constituye una nueva verificación.
    final verifiedAt = mfaEnabled ? timestamps.last : timestamps.first;
    return DateTime.fromMillisecondsSinceEpoch(verifiedAt * 1000, isUtc: true)
        .add(const Duration(hours: 1));
  } catch (_) {
    return null;
  }
}
