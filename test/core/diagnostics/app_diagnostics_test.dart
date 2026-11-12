import 'dart:io';
import 'package:app_horas/core/diagnostics/app_diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rota el archivo y no guarda mensajes con datos sensibles', () async {
    final directory =
        await Directory.systemTemp.createTemp('hesm-diagnostics-test-');
    addTearDown(() => directory.delete(recursive: true));
    final diagnostics = AppDiagnostics(directory, maxBytes: 1);
    await diagnostics.record(
        'login', StateError('password: no-exportar; DNI: 12345678'));
    await diagnostics.record('horas', StateError('token: no-exportar'));
    final contents = await Future.wait(
        directory.listSync().whereType<File>().map((f) => f.readAsString()));
    expect(contents, hasLength(2));
    expect(contents.join(), isNot(contains('no-exportar')));
    expect(contents.join(), isNot(contains('12345678')));
  });
}
