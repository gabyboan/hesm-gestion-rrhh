import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/network/internet_connection_gate.dart';
import '../features/auth/application/session_timeout_provider.dart';
import '../features/auth/presentation/auth_gate.dart';
import 'theme/theme_mode_provider.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HESM - Gestión RRHH',
      themeMode: themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: const Color(0xFF4F46E5),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF4F46E5),
      ),
      locale: const Locale('es', 'AR'),
      supportedLocales: const [
        Locale('es', 'AR'),
        Locale('es', 'ES'),
        Locale('es'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: InternetConnectionGate(
        applicationEndpoint: Uri.parse(Supabase.instance.client.rest.url),
        onConnectionChanged: (hasInternet) {
          final sessionTimeout = ref.read(sessionTimeoutProvider);
          if (hasInternet) {
            unawaited(sessionTimeout.resume());
          } else {
            sessionTimeout.pause();
          }
        },
        child: const AuthGate(),
      ),
    );
  }
}
