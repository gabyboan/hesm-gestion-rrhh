import 'dart:async';
import 'dart:convert';

import 'package:app_horas/core/startup/startup_checks.dart';
import 'package:app_horas/core/startup/startup_config.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeStartupNetwork implements StartupNetwork {
  StartupCheck? failAt;
  final calls = <StartupCheck>[];
  Future<void> _run(StartupCheck check) async {
    calls.add(check);
    if (failAt == check) throw TimeoutException('private technical details');
  }

  @override
  Future<void> resolveDns(StartupConfig config) => _run(StartupCheck.dns);
  @override
  Future<void> checkInternet(StartupConfig config) =>
      _run(StartupCheck.internet);
  @override
  Future<void> checkAuthentication(StartupConfig config) =>
      _run(StartupCheck.authentication);
  @override
  Future<void> checkData(StartupConfig config) => _run(StartupCheck.data);
}

void main() {
  final config = StartupConfig.validate(
      'https://example.supabase.co', 'sb_publishable_test_client_key');
  test('stops at each failure without marking later checks successful',
      () async {
    for (final failure in StartupCheck.values) {
      final network = FakeStartupNetwork()..failAt = failure;
      var initialized = false;
      final checks = StartupChecks(
          network: network,
          ensureInstance: () async {},
          loadConfig: () async {
            if (failure == StartupCheck.configuration) {
              throw const StartupIssue('Configuración faltante.');
            }
            return config;
          },
          prepareApplication: (_) async {
            if (failure == StartupCheck.application) {
              throw StateError('SDK failure');
            }
            initialized = true;
          });
      final states = <StartupCheck, StartupCheckState>{};
      expect(await checks.run((state) => states[state.check] = state), isFalse);
      expect(initialized, isFalse);
      for (final check in StartupCheck.values) {
        expect(
            states[check]!.status,
            check.index < failure.index
                ? CheckStatus.passed
                : check == failure
                    ? CheckStatus.failed
                    : CheckStatus.pending);
      }
      expect(states[failure]!.message,
          isNot(contains('private technical details')));
    }
  });
  test(
      'retry resets the failed checks and initializes only after network passes',
      () async {
    final network = FakeStartupNetwork()..failAt = StartupCheck.dns;
    var initialized = 0;
    final checks = StartupChecks(
        network: network,
        ensureInstance: () async {},
        loadConfig: () async => config,
        prepareApplication: (_) async {
          initialized++;
        });
    expect(await checks.run((_) {}), isFalse);
    expect(initialized, 0);
    network.failAt = null;
    final events = <StartupCheckState>[];
    expect(await checks.run(events.add), isTrue);
    expect(initialized, 1);
    expect(events.take(6).every((event) => event.status == CheckStatus.pending),
        isTrue);
    expect(
        events.where((event) => event.status == CheckStatus.passed).length, 6);
  });
  test(
      'data probe distinguishes expected authorization from errors and outages',
      () {
    IoStartupNetwork.validateDataProbe(200, '[]');
    IoStartupNetwork.validateDataProbe(401, '{"code":"42501"}');
    IoStartupNetwork.validateDataProbe(403, '{"code":"42501"}');
    IoStartupNetwork.validateDataProbe(401, '{"code":"PT401"}');
    for (final response in [
      (401, '{"message":"Invalid API key"}'),
      (503, '{"code":"PGRST002"}'),
      (404, '{"code":"PGRST205"}'),
      (200, '[{"unexpected":"row"}]')
    ]) {
      expect(() => IoStartupNetwork.validateDataProbe(response.$1, response.$2),
          throwsA(isA<StartupIssue>()));
    }
  });
  test(
      'configuration rejects missing values, unsafe URLs and administrative keys',
      () {
    for (final url in [
      '',
      'http://example.org',
      'https://user:password@example.org',
      'https://example.org/?token=value'
    ]) {
      expect(() => StartupConfig.validate(url, config.clientKey),
          throwsA(isA<StartupIssue>()));
    }
    final payload = base64Url.encode(utf8.encode('{"role":"service_role"}'));
    for (final key in ['', 'sb_secret_private', 'header.$payload.signature']) {
      expect(() => StartupConfig.validate(config.endpoint.toString(), key),
          throwsA(isA<StartupIssue>()));
    }
  });
}
