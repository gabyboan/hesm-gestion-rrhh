import 'dart:convert';
import 'dart:typed_data';

import 'package:app_horas/core/updates/lan_release.dart';
import 'package:app_horas/core/updates/windows_update_service.dart';
import 'package:crypto/crypto.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final keys = ed.generateKey();
  final publicKey = base64Encode(keys.publicKey.bytes);
  final installer = Uint8List.fromList(utf8.encode('signed installer fixture'));
  Map<String, Object> metadata({String version = '1.0.1.2'}) => {
        'schema': 1,
        'version': version,
        'file': 'HESM-Gestion-RRHH-$version-Setup.exe',
        'length': installer.length,
        'sha256': sha256.convert(installer).toString(),
        'signature': base64Encode(ed.sign(keys.privateKey, installer)),
      };
  Uint8List envelope(Map<String, Object> data) {
    final payload = Uint8List.fromList(utf8.encode(jsonEncode(data)));
    return Uint8List.fromList(utf8.encode(jsonEncode({
      'payload': base64Encode(payload),
      'signature': base64Encode(ed.sign(keys.privateKey, payload)),
    })));
  }

  test('authenticates version metadata and installer independently', () {
    final release = LanRelease.fromEnvelope(envelope(metadata()), publicKey);
    expect(release.isNewerThan('1.0.0.1'), isTrue);
    expect(release.verifyInstaller(installer, publicKey), isTrue);
    final changed = Uint8List.fromList(installer)..[0] ^= 1;
    expect(release.verifyInstaller(changed, publicKey), isFalse);
  });
  test('authenticates the required backend version and accepts older manifests',
      () {
    expect(
        LanRelease.fromEnvelope(envelope(metadata()), publicKey).requiredSchema,
        1);
    final data = metadata()..['required_schema'] = 2;
    expect(
        LanRelease.fromEnvelope(envelope(data), publicKey).requiredSchema, 2);
    data['required_schema'] = -1;
    expect(() => LanRelease.fromEnvelope(envelope(data), publicKey),
        throwsFormatException);
  });
  test('rejects tampered metadata even if the installer signature is unchanged',
      () {
    final data =
        jsonDecode(utf8.decode(envelope(metadata()))) as Map<String, dynamic>;
    data['payload'] =
        base64Encode(utf8.encode(jsonEncode(metadata(version: '99.0.0.1'))));
    expect(
        () => LanRelease.fromEnvelope(
            Uint8List.fromList(utf8.encode(jsonEncode(data))), publicKey),
        throwsFormatException);
  });
  test('rejects a release from another signing key', () {
    expect(
        () => LanRelease.fromEnvelope(envelope(metadata()),
            base64Encode(ed.generateKey().publicKey.bytes)),
        throwsFormatException);
  });
  test('never offers an equal or older release', () {
    final release = LanRelease.fromEnvelope(envelope(metadata()), publicKey);
    expect(release.isNewerThan('1.0.1.2'), isFalse);
    expect(release.isNewerThan('1.0.1.3'), isFalse);
    expect(release.isNewerThan('2.0.0.1'), isFalse);
    expect(release.isNewerThan('1.0.1.1'), isTrue);
  });
  test('rejects traversal and unexpected executable names in signed manifests',
      () {
    for (final file in ['../evil.exe', r'\\other\share\evil.exe', 'cmd.exe']) {
      expect(
          () => LanRelease.fromEnvelope(
              envelope({...metadata(), 'file': file}), publicKey),
          throwsFormatException);
    }
  });
  test('rejects oversized installers and invalid versions', () {
    expect(
        () => LanRelease.fromEnvelope(
            envelope(
                {...metadata(), 'length': LanRelease.maxInstallerBytes + 1}),
            publicKey),
        throwsFormatException);
    for (final version in ['1.2.3', '1.2.3.-1', '1.2.3.65536']) {
      expect(() => LanRelease.versionParts(version), throwsFormatException);
    }
  });
  test('only accepts UNC shares and rejects Windows device and admin paths',
      () {
    expect(LanRelease.validateShare('\\\\PC-RRHH\\Actualizaciones\\'),
        r'\\PC-RRHH\Actualizaciones');
    expect(LanRelease.validateShare(r'\\PC-RRHH\Actualizaciones'),
        r'\\PC-RRHH\Actualizaciones');
    for (final path in [
      r'C:\updates',
      r'Z:\updates',
      r'\\?\C:\updates',
      r'\\.\pipe\updates',
      r'\\PC\C$',
      r'\\PC\share\..\other',
      'https://example.org/updates'
    ]) {
      expect(() => LanRelease.validateShare(path), throwsFormatException);
    }
  });
  test('starts unconfigured and persists the chosen share without passwords',
      () async {
    SharedPreferences.setMockInitialValues({});
    final service = WindowsUpdateService();
    await service.initialize();
    expect(service.share, isNull);
    expect(await service.checkForUpdates(), isNull);
    await service.configure(r'\\PC-RRHH\Actualizaciones');
    final next = WindowsUpdateService();
    await next.initialize();
    expect(next.share, r'\\PC-RRHH\Actualizaciones');
  });
}
