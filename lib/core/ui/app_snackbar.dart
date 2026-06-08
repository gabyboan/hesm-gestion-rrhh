import 'package:flutter/material.dart';

class AppSnackBar {
  const AppSnackBar._();

  static OverlayEntry? _currentEntry;

  static void success(
    BuildContext context,
    String message,
  ) {
    show(
      context,
      message,
      color: Colors.green.shade700,
      icon: Icons.check_circle_outline,
    );
  }

  static void error(
    BuildContext context,
    String message,
  ) {
    show(
      context,
      message,
      color: Theme.of(context).colorScheme.error,
      icon: Icons.error_outline,
    );
  }

  static void show(
    BuildContext context,
    String message, {
    Color? color,
    IconData icon = Icons.info_outline,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _currentEntry?.remove();

    final entry = OverlayEntry(
      builder: (context) {
        final effectiveColor = color ?? Theme.of(context).colorScheme.primary;

        return Positioned.fill(
          child: IgnorePointer(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.scale(
                    scale: 0.92 + (value * 0.08),
                    child: child,
                  ),
                );
              },
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 420,
                    maxWidth: 560,
                  ),
                  child: Material(
                    elevation: 18,
                    color: effectiveColor,
                    shadowColor: Colors.black.withValues(alpha: 0.36),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 24,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icon,
                            color: Colors.white,
                            size: 38,
                          ),
                          const SizedBox(width: 18),
                          Flexible(
                            child: Text(
                              message,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    _currentEntry = entry;
    overlay.insert(entry);

    Future.delayed(const Duration(seconds: 3), () {
      if (_currentEntry != entry) return;

      entry.remove();
      _currentEntry = null;
    });
  }
}
