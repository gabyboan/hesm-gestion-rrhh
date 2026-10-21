import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_horas/features/preferences/domain/current_user_profile.dart';
import 'package:app_horas/features/preferences/domain/user_preferences.dart';

void main() {
  group('CurrentUserProfile', () {
    test('saluda con apellido y solamente el primer nombre', () {
      const profile = CurrentUserProfile(
        apellido: 'Pérez',
        nombre: 'Ana María',
      );

      expect(profile.saludo, 'Bienvenido, Pérez Ana');
    });

    test('ignora espacios repetidos antes del primer nombre', () {
      const profile = CurrentUserProfile(
        apellido: 'Gómez',
        nombre: '   Juan   Carlos ',
      );

      expect(profile.saludo, 'Bienvenido, Gómez Juan');
    });
  });

  group('UserPreferences', () {
    test('limita la inactividad al rango permitido', () {
      final preferences = UserPreferences(
        themeMode: ThemeMode.light,
        idleMinutes: 25,
      ).normalized;

      expect(preferences.idleMinutes, UserPreferences.maxIdleMinutes);
      expect(preferences.databaseTheme, 'claro');
    });
  });
}
