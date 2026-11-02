import 'dart:async';

import 'package:flutter/material.dart';

import 'lan_release.dart';
import 'windows_update_service.dart';

Future<void> offerLanUpdate(BuildContext context, LanRelease release,
    {bool confirm = true}) async {
  final accepted = !confirm ||
      await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                    title: const Text('Nueva versión disponible'),
                    content: Text(
                        'Está disponible la versión ${release.version}. Guardá tu trabajo antes de continuar. '
                        'La aplicación se cerrará y volverá a abrirse después de instalar.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Más tarde')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Instalar y reiniciar')),
                    ],
                  )) ==
          true;
  if (accepted != true || !context.mounted) return;
  // Keep the dialog open during copying and signature verification.
  unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Expanded(
                  child: Text('Preparando y verificando la actualización…'))
            ]),
          ))));
  try {
    await WindowsUpdateService.instance.install(release);
  } catch (_) {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('No se pudo instalar'),
              content: const Text(
                  'No se pudo copiar, verificar o abrir el instalador. '
                  'Revisá la conexión con la carpeta del hospital e intentá nuevamente.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cerrar'))
              ],
            ));
  }
}

class LanUpdateGate extends StatefulWidget {
  const LanUpdateGate(
      {super.key,
      required this.child,
      this.checkOnStart = true,
      this.offeredVersion});
  final Widget child;
  final bool checkOnStart;
  final String? offeredVersion;
  @override
  State<LanUpdateGate> createState() => _LanUpdateGateState();
}

class _LanUpdateGateState extends State<LanUpdateGate> {
  Timer? _timer;
  String? _offered;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _offered = widget.offeredVersion;
    if (WindowsUpdateService.enabled) {
      if (widget.checkOnStart) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _check());
      }
      _timer = Timer.periodic(const Duration(hours: 4), (_) => _check());
    }
  }

  Future<void> _check() async {
    if (_checking || WindowsUpdateService.instance.installing) return;
    _checking = true;
    try {
      final release = await WindowsUpdateService.instance.checkForUpdates();
      if (!mounted || release == null || release.version == _offered) return;
      // A modal or an active module should not be interrupted by another modal.
      if (ModalRoute.of(context)?.isCurrent != true) return;
      _offered = release.version;
      await offerLanUpdate(context, release);
    } catch (_) {
      // An offline share or invalid signature never blocks the application.
    } finally {
      _checking = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
