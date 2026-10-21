import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/theme_mode_provider.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../auth/application/session_timeout_provider.dart';
import '../data/user_preferences_repository.dart';
import '../domain/current_user_profile.dart';
import '../domain/user_preferences.dart';

final userPreferencesRepositoryProvider =
    Provider<UserPreferencesRepository>((ref) {
  return UserPreferencesRepository(ref.watch(supabaseClientProvider));
});

final userPreferencesProvider = FutureProvider<UserPreferences>((ref) async {
  final userId = ref.watch(supabaseClientProvider).auth.currentUser?.id;
  if (userId == null) return UserPreferences.defaults;

  return ref.watch(userPreferencesRepositoryProvider).fetch(userId);
});

final currentUserProfileProvider =
    FutureProvider<CurrentUserProfile?>((ref) async {
  final userId = ref.watch(supabaseClientProvider).auth.currentUser?.id;
  if (userId == null) return null;

  return ref.watch(userPreferencesRepositoryProvider).fetchCurrentProfile();
});

final userPreferencesControllerProvider =
    Provider<UserPreferencesController>((ref) {
  return UserPreferencesController(
    repository: ref.watch(userPreferencesRepositoryProvider),
    currentUserId: () => ref.read(supabaseClientProvider).auth.currentUser?.id,
    applyTheme: (themeMode) {
      ref.read(themeModeProvider.notifier).state = themeMode;
    },
    configureIdleTimeout: (timeout) {
      ref.read(sessionTimeoutProvider).configure(timeout);
    },
    invalidatePreferences: () => ref.invalidate(userPreferencesProvider),
  );
});

class UserPreferencesController {
  final UserPreferencesRepository _repository;
  final String? Function() _currentUserId;
  final ValueChanged<ThemeMode> _applyTheme;
  final ValueChanged<Duration> _configureIdleTimeout;
  final VoidCallback _invalidatePreferences;

  UserPreferencesController({
    required UserPreferencesRepository repository,
    required String? Function() currentUserId,
    required ValueChanged<ThemeMode> applyTheme,
    required ValueChanged<Duration> configureIdleTimeout,
    required VoidCallback invalidatePreferences,
  })  : _repository = repository,
        _currentUserId = currentUserId,
        _applyTheme = applyTheme,
        _configureIdleTimeout = configureIdleTimeout,
        _invalidatePreferences = invalidatePreferences;

  Future<void> save(UserPreferences preferences) async {
    final userId = _currentUserId();
    if (userId == null) {
      throw StateError(
          'No hay una sesión activa para guardar la configuración.');
    }

    final normalized = preferences.normalized;
    await _repository.save(userId: userId, preferences: normalized);

    _applyTheme(normalized.themeMode);
    _configureIdleTimeout(normalized.idleTimeout);
    _invalidatePreferences();
  }
}
