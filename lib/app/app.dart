import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/presentation/auth_gate.dart';
import '../features/auth/application/session_timeout_provider.dart';

// ✅ nuevo
import 'theme/theme_mode_provider.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeout = ref.watch(sessionTimeoutProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => timeout.reset(),
      onPointerMove: (_) => timeout.reset(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Carga de Horas',

        // ✅ ahora se controla por provider
        themeMode: themeMode,

        // ✅ tema claro
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          colorSchemeSeed: const Color(0xFF4F46E5),
        ),

        // ✅ tema oscuro
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorSchemeSeed: const Color(0xFF4F46E5),
        ),

        // Español (Argentina)
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

        home: const AuthGate(),
      ),
    );
  }
}
