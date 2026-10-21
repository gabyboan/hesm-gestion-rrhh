import 'dart:async';

import 'package:app_horas/core/network/internet_connection_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('bloquea la pantalla sin internet y la habilita al reconectar', (
    tester,
  ) async {
    final monitor = _FakeInternetMonitor(hasInternet: false);
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: InternetConnectionGate(
          applicationEndpoint: Uri.parse('https://example.test'),
          monitor: monitor,
          child: Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => taps += 1,
                child: const Text('Acción'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Sin internet'), findsOneWidget);
    await tester.tap(find.text('Acción'), warnIfMissed: false);
    expect(taps, 0);

    monitor.update(true);
    await tester.pump();
    await tester.pump();

    expect(find.text('Sin internet'), findsNothing);
    await tester.tap(find.text('Acción'));
    expect(taps, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await monitor.dispose();
  });
}

class _FakeInternetMonitor implements InternetMonitor {
  _FakeInternetMonitor({required bool hasInternet})
      : _hasInternet = hasInternet;

  final _controller = StreamController<bool>.broadcast();
  bool _hasInternet;

  @override
  Future<bool> get hasInternet async => _hasInternet;

  @override
  Stream<bool> get onInternetChanged => _controller.stream;

  void update(bool hasInternet) {
    _hasInternet = hasInternet;
    _controller.add(hasInternet);
  }

  @override
  Future<void> dispose() => _controller.close();
}
