import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/app_snackbar.dart';
import '../../../core/utils/error_text.dart';
import '../application/user_preferences_providers.dart';
import '../domain/user_preferences.dart';

Future<void> showUserPreferencesDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const UserPreferencesDialog(),
  );
}

class UserPreferencesDialog extends ConsumerWidget {
  const UserPreferencesDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferencesAsync = ref.watch(userPreferencesProvider);

    return preferencesAsync.when(
      data: (preferences) => _PreferencesForm(preferences: preferences),
      loading: () => const AlertDialog(
        title: Text('Configuración'),
        content: SizedBox(
          height: 72,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, _) => AlertDialog(
        title: const Text('Configuración'),
        content: Text(
          'No se pudo cargar tu configuración. ${cleanError(error)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

class _PreferencesForm extends ConsumerStatefulWidget {
  final UserPreferences preferences;

  const _PreferencesForm({required this.preferences});

  @override
  ConsumerState<_PreferencesForm> createState() => _PreferencesFormState();
}

class _PreferencesFormState extends ConsumerState<_PreferencesForm> {
  late ThemeMode _themeMode;
  late int _idleMinutes;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.preferences.themeMode;
    _idleMinutes = widget.preferences.idleMinutes;
  }

  Future<void> _save() async {
    if (_saving) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref.read(userPreferencesControllerProvider).save(
            UserPreferences(
              themeMode: _themeMode,
              idleMinutes: _idleMinutes,
            ),
          );

      if (!mounted) return;
      AppSnackBar.success(context, 'Configuración guardada.');
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = cleanError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.tune),
      title: const Text('Configuración'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Apariencia',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            RadioGroup<ThemeMode>(
              groupValue: _themeMode,
              onChanged: (value) {
                if (value == null || _saving) return;
                setState(() => _themeMode = value);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.dark,
                    enabled: !_saving,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Modo oscuro'),
                    secondary: const Icon(Icons.dark_mode_outlined),
                  ),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.light,
                    enabled: !_saving,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Modo claro'),
                    secondary: const Icon(Icons.light_mode_outlined),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: _idleMinutes,
              decoration: const InputDecoration(
                labelText: 'Cerrar sesión por inactividad',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.timer_outlined),
              ),
              items: [
                for (var minute = UserPreferences.minIdleMinutes;
                    minute <= UserPreferences.maxIdleMinutes;
                    minute++)
                  DropdownMenuItem(
                    value: minute,
                    child:
                        Text('$minute ${minute == 1 ? 'minuto' : 'minutos'}'),
                  ),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _idleMinutes = value!),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
