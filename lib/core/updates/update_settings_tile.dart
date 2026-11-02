import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'lan_update_gate.dart';
import 'windows_update_service.dart';

class UpdateSettingsTile extends StatefulWidget {
  const UpdateSettingsTile({super.key});
  @override
  State<UpdateSettingsTile> createState() => _UpdateSettingsTileState();
}

class _UpdateSettingsTileState extends State<UpdateSettingsTile> {
  final _path = TextEditingController();
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    if (WindowsUpdateService.enabled) _load();
  }

  Future<void> _load() async {
    try {
      await WindowsUpdateService.instance.initialize();
      if (mounted) {
        setState(() => _path.text = WindowsUpdateService.instance.share ?? '');
      }
    } catch (_) {
      if (mounted) {
        setState(() =>
            _message = 'No se pudo cargar la carpeta de actualizaciones.');
      }
    }
  }

  Future<void> _browse() async {
    final path = await getDirectoryPath(confirmButtonText: 'Usar esta carpeta');
    if (path != null && mounted) setState(() => _path.text = path);
  }

  Future<void> _saveAndCheck() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await WindowsUpdateService.instance.configure(_path.text);
      final release = await WindowsUpdateService.instance.checkForUpdates();
      if (!mounted) return;
      if (release == null) {
        setState(() => _message = 'La aplicación está actualizada.');
      } else {
        await offerLanUpdate(context, release);
      }
    } on FormatException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (_) {
      if (mounted) {
        setState(() =>
            _message = 'La carpeta quedó guardada, pero no se pudo consultar. '
                'Revisá que el equipo del hospital esté encendido y tengas permiso de lectura.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _path.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!WindowsUpdateService.enabled) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Divider(),
      Text('Actualizaciones del hospital',
          style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 4),
      const Text('Versión instalada: ${WindowsUpdateService.version}'),
      const SizedBox(height: 8),
      const Text(
          'Elegí la carpeta compartida que indique el responsable del sistema. '
          'Se consulta al iniciar y cada 4 horas.'),
      const SizedBox(height: 8),
      TextField(
          controller: _path,
          enabled: !_busy,
          decoration: InputDecoration(
              labelText: 'Carpeta de red',
              hintText: r'\\PC-RRHH\Actualizaciones',
              suffixIcon: IconButton(
                  onPressed: _busy ? null : _browse,
                  tooltip: 'Elegir carpeta',
                  icon: const Icon(Icons.folder_open)))),
      TextButton.icon(
          onPressed: _busy ? null : _saveAndCheck,
          icon: const Icon(Icons.system_update_alt),
          label: Text(_busy ? 'Consultando…' : 'Guardar carpeta y buscar')),
      if (_message != null) Text(_message!),
    ]);
  }
}
