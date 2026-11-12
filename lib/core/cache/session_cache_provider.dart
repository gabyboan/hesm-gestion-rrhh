import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_providers.dart';
import 'session_data_cache.dart';

final sessionDataCacheProvider = Provider<SessionDataCache>((ref) {
  ref.watch(authSessionProvider.select((value) {
    final session = value.valueOrNull;
    if (session == null) return null;
    try {
      final claims = jsonDecode(utf8.decode(base64Url.decode(
          base64Url.normalize(session.accessToken.split('.')[1])))) as Map;
      final sid = claims['session_id'];
      if (sid is String && sid.isNotEmpty) return '${session.user.id}:$sid';
    } catch (_) {
      // Un token no estándar también queda separado del de otra sesión.
    }
    return '${session.user.id}:${session.accessToken}';
  }));
  final cache = SessionDataCache();
  ref.onDispose(cache.dispose);
  return cache;
});
