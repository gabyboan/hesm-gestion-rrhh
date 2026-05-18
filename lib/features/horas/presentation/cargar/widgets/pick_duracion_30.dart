import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

String labelMinutos30(int minutes) {
  if (minutes <= 30) return "30'";
  final h = minutes ~/ 60;
  final r = minutes % 60;
  if (r == 0) return "${h}hs";
  return "${h}hs 30'";
}

bool _isDesktopPlatform(TargetPlatform p) =>
    p == TargetPlatform.windows ||
    p == TargetPlatform.macOS ||
    p == TargetPlatform.linux;

Future<int?> pickDuracion30Hasta10hs(
  BuildContext context, {
  int initialMinutes = 60,
}) async {
  const minM = 30;
  const maxM = 600; // ✅ 10hs
  const step = 30;

  int clampToRangeAndStep(int m) {
    if (m < minM) m = minM;
    if (m > maxM) m = maxM;
    final rem = m % step;
    if (rem != 0) m = m + (step - rem);
    if (m > maxM) m = maxM;
    return m;
  }

  final init = clampToRangeAndStep(initialMinutes);

  final items = <int>[
    for (int m = minM; m <= maxM; m += step) m,
  ];

  int selected = init;

  final initialIndex = items.indexOf(init).clamp(0, items.length - 1);
  final controller = FixedExtentScrollController(initialItem: initialIndex);

  final platform = Theme.of(context).platform;
  final useDialog = kIsWeb || _isDesktopPlatform(platform);

  Widget content(BuildContext ctx) {
    return SizedBox(
      height: 340, // un poco más alto, opcional
      child: Column(
        children: [
          const SizedBox(height: 12),
          const Text(
            "Duración (30' a 10hs)",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: CupertinoPicker(
              scrollController: controller,
              itemExtent: 44,
              magnification: 1.12,
              useMagnifier: true,
              selectionOverlay: const CupertinoPickerDefaultSelectionOverlay(),
              onSelectedItemChanged: (i) => selected = items[i],
              children: [
                for (final m in items) Center(child: Text(labelMinutos30(m))),
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
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Cancelar"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, selected),
                    child: const Text("OK"),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  if (useDialog) {
    return showDialog<int>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: content(ctx),
        ),
      ),
    );
  }

  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(child: content(ctx)),
  );
}
