import 'package:flutter/material.dart';

class UserPreferences {
  static const minIdleMinutes = 1;
  static const maxIdleMinutes = 10;

  final ThemeMode themeMode;
  final int idleMinutes;

  const UserPreferences({
    required this.themeMode,
    required this.idleMinutes,
  });

  static const defaults = UserPreferences(
    themeMode: ThemeMode.dark,
    idleMinutes: 5,
  );

  Duration get idleTimeout => Duration(minutes: idleMinutes);

  String get databaseTheme => themeMode == ThemeMode.light ? 'claro' : 'oscuro';

  UserPreferences get normalized => UserPreferences(
        themeMode:
            themeMode == ThemeMode.light ? ThemeMode.light : ThemeMode.dark,
        idleMinutes: idleMinutes.clamp(minIdleMinutes, maxIdleMinutes).toInt(),
      );

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    final theme = json['tema']?.toString().trim().toLowerCase();
    final rawMinutes = json['inactividad_minutos'];
    final minutes = rawMinutes is int
        ? rawMinutes
        : int.tryParse(rawMinutes?.toString() ?? '') ?? defaults.idleMinutes;

    return UserPreferences(
      themeMode: theme == 'claro' ? ThemeMode.light : ThemeMode.dark,
      idleMinutes: minutes,
    ).normalized;
  }
}
