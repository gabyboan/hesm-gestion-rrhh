import 'dart:async';
import 'dart:convert';

import 'package:app_horas/core/cache/session_data_cache.dart';
import 'package:app_horas/core/cache/session_cache_provider.dart';
import 'package:app_horas/features/auth/application/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Session session(String user, String sid, int counter) => Session(
    accessToken: 'fixture.${base64Url.encode(utf8.encode(jsonEncode({
          'session_id': sid,
          'iat': counter
        })))}.fixture',
    refreshToken: 'fixture',
    tokenType: 'bearer',
    user: User(
        id: user,
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-01-01T00:00:00Z'));

void main() {
  test('reutiliza resultados y agrupa lecturas concurrentes', () async {
    final cache = SessionDataCache();
    final pending = Completer<int>();
    var calls = 0;
    Future<int> load() {
      calls++;
      return pending.future;
    }

    final first = cache.read('padron', 'q', load);
    final second = cache.read('padron', 'q', load);
    expect(identical(first, second), isTrue);
    pending.complete(7);
    expect(await first, 7);
    expect(await cache.read('padron', 'q', load), 7);
    expect(calls, 1);
  });

  test('vence por tiempo y no conserva errores', () async {
    var now = DateTime(2026);
    final cache = SessionDataCache(now: () => now);
    var calls = 0;
    Future<int> load() async => ++calls;
    expect(await cache.read('a', 1, load), 1);
    now = now.add(const Duration(seconds: 31));
    expect(await cache.read('a', 1, load), 2);
    await expectLater(
        cache.read<int>('a', 2, () async => throw StateError('fixture')),
        throwsStateError);
    expect(await cache.read('a', 2, load), 3);
  });

  test('invalidar durante una consulta no repuebla datos anteriores', () async {
    final cache = SessionDataCache(maxEntries: 2);
    final pending = Completer<int>();
    final old = cache.read('horas', 1, () => pending.future);
    cache.invalidate('horas');
    expect(await cache.read('horas', 1, () async => 2), 2);
    pending.complete(1);
    await old;
    expect(await cache.read('horas', 1, () async => 3), 2);
    await cache.read('horas', 2, () async => 4);
    await cache.read('horas', 3, () async => 5);
    expect(cache.length, 2);
    cache.dispose();
    expect(cache.length, 0);
  });

  test('renovar el JWT conserva la caché; salir y cambiar de cuenta la elimina',
      () async {
    final events = StreamController<Session?>();
    final container = ProviderContainer(
        overrides: [authSessionProvider.overrideWith((ref) => events.stream)]);
    addTearDown(() async {
      container.dispose();
      await events.close();
    });
    container.listen(sessionDataCacheProvider, (_, __) {});
    events.add(session('a', 'session-a', 1));
    await Future<void>.delayed(Duration.zero);
    final first = container.read(sessionDataCacheProvider);
    await first.read('datos', 1, () async => 'persona a');
    events.add(session('a', 'session-a', 2));
    await Future<void>.delayed(Duration.zero);
    expect(identical(container.read(sessionDataCacheProvider), first), isTrue);
    events.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(first.length, 0);
    events.add(session('b', 'session-b', 1));
    await Future<void>.delayed(Duration.zero);
    final other = container.read(sessionDataCacheProvider);
    expect(identical(other, first), isFalse);
    expect(await other.read('datos', 1, () async => 'persona b'), 'persona b');
  });
}
