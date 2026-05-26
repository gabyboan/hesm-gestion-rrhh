import 'package:flutter/material.dart';

class AppSnackBar {
  const AppSnackBar._();

  static void success(
    BuildContext context,
    String message,
  ) {
    show(
      context,
      message,
      backgroundColor: Colors.green.shade700,
    );
  }

  static void error(
    BuildContext context,
    String message,
  ) {
    show(
      context,
      message,
      backgroundColor: Theme.of(context).colorScheme.error,
    );
  }

  static void show(
    BuildContext context,
    String message, {
    Color? backgroundColor,
  }) {
    final messenger = ScaffoldMessenger.of(context);

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: backgroundColor,
      ),
    );
  }
}
