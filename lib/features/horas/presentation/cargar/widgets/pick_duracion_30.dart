// lib/shared/widgets/duracion_picker.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const int _minMinutes = 30;
const int _maxMinutes = 600; // 10 horas.
const int _stepMinutes = 30;

/// Devuelve una etiqueta legible para una duración expresada en minutos.
///
/// Ejemplos:
/// - 30  -> 30'
/// - 60  -> 1hs
/// - 90  -> 1hs 30'
/// - 600 -> 10hs
String labelMinutos30(int minutes) {
  if (minutes <= 0) return "0'";
  if (minutes < 60) return "$minutes'";

  final hours = minutes ~/ 60;
  final rest = minutes % 60;

  if (rest == 0) return '${hours}hs';

  return "$hours hs $rest'";
}

bool _isDesktopPlatform(TargetPlatform platform) {
  return platform == TargetPlatform.windows ||
      platform == TargetPlatform.macOS ||
      platform == TargetPlatform.linux;
}

/// Ajusta los minutos al rango permitido y al múltiplo de 30 superior.
///
/// Ejemplos:
/// - 10  -> 30
/// - 31  -> 60
/// - 61  -> 90
/// - 700 -> 600
int _clampToRangeAndStep(int minutes) {
  var value = minutes;

  if (value < _minMinutes) value = _minMinutes;
  if (value > _maxMinutes) value = _maxMinutes;

  final remainder = value % _stepMinutes;
  if (remainder != 0) {
    value += _stepMinutes - remainder;
  }

  if (value > _maxMinutes) value = _maxMinutes;

  return value;
}

List<int> _durationItems() {
  return [
    for (int m = _minMinutes; m <= _maxMinutes; m += _stepMinutes) m,
  ];
}

/// Abre un selector de duración entre 30 minutos y 10 horas.
///
/// En web/escritorio se muestra como diálogo.
/// En mobile se muestra como bottom sheet.
///
/// Devuelve:
/// - minutos seleccionados si el usuario confirma;
/// - `null` si cancela o cierra el picker.
Future<int?> pickDuracion30Hasta10hs(
  BuildContext context, {
  int initialMinutes = 60,
}) async {
  final items = _durationItems();
  final init = _clampToRangeAndStep(initialMinutes);

  var selected = init;

  final rawInitialIndex = items.indexOf(init);
  final initialIndex = rawInitialIndex < 0 ? 0 : rawInitialIndex;

  final controller = FixedExtentScrollController(
    initialItem: initialIndex,
  );

  final platform = Theme.of(context).platform;
  final useDialog = kIsWeb || _isDesktopPlatform(platform);

  Widget content(BuildContext ctx) {
    final theme = Theme.of(ctx);

    return SizedBox(
      height: 340,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Text(
            "Duración (30' a 10hs)",
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: CupertinoPicker(
              scrollController: controller,
              itemExtent: 44,
              magnification: 1.12,
              useMagnifier: true,
              selectionOverlay: const CupertinoPickerDefaultSelectionOverlay(),
              onSelectedItemChanged: (index) {
                selected = items[index];
              },
              children: [
                for (final minutes in items)
                  Center(
                    child: Text(labelMinutos30(minutes)),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(selected),
                    child: const Text('OK'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  try {
    if (useDialog) {
      return await showDialog<int>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) {
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: content(ctx),
            ),
          );
        },
      );
    }

    return await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: content,
    );
  } finally {
    controller.dispose();
  }
}
