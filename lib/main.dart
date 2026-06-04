import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:windows_single_instance/windows_single_instance.dart';

import 'app/app.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  runApp(BootstrapApp(args: args));
}

class BootstrapApp extends StatefulWidget {
  final List<String> args;

  const BootstrapApp({
    super.key,
    required this.args,
  });

  @override
  State<BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<BootstrapApp> {
  Object? _error;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      await _bootstrap(widget.args);
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'bootstrap',
        ),
      );

      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) {
      return const ProviderScope(child: App());
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: BootstrapStatusPage(error: _error),
    );
  }
}

Future<void> _bootstrap(List<String> args) async {
  // Evita doble instancia en Windows.
  if (Platform.isWindows) {
    await WindowsSingleInstance.ensureSingleInstance(
      args,
      'hesm_gestion_rrhh',
      onSecondWindow: (args) {},
    ).timeout(
      const Duration(seconds: 5),
      onTimeout: () => throw TimeoutException(
        'No se pudo validar la instancia unica de Windows en 5 segundos.',
      ),
    );
  }

  const definedSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const definedSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  if (definedSupabaseUrl.isEmpty || definedSupabaseAnonKey.isEmpty) {
    try {
      await dotenv.load(fileName: 'credenciales.env');
    } catch (_) {}
  }

  final supabaseUrl = definedSupabaseUrl.isNotEmpty
      ? definedSupabaseUrl
      : dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = definedSupabaseAnonKey.isNotEmpty
      ? definedSupabaseAnonKey
      : dotenv.env['SUPABASE_ANON_KEY'];

  if (supabaseUrl == null || supabaseUrl.isEmpty) {
    throw Exception(
      'Falta SUPABASE_URL. Usa --dart-define o credenciales.env.',
    );
  }
  if (supabaseAnonKey == null || supabaseAnonKey.isEmpty) {
    throw Exception(
      'Falta SUPABASE_ANON_KEY. Usa --dart-define o credenciales.env.',
    );
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      localStorage: EmptyLocalStorage(),
    ),
  ).timeout(
    const Duration(seconds: 20),
    onTimeout: () => throw TimeoutException(
      'No se pudo iniciar Supabase en 20 segundos.',
    ),
  );
}

class BootstrapStatusPage extends StatelessWidget {
  final Object? error;

  const BootstrapStatusPage({
    super.key,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: const Color(0xFF4F46E5),
    );

    return Theme(
      data: theme,
      child: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: error == null
                  ? const _BootstrapLoading()
                  : _BootstrapError(error: error!),
            ),
          ),
        ),
      ),
    );
  }
}

class _BootstrapLoading extends StatelessWidget {
  const _BootstrapLoading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text(
          'Iniciando HESM - Gestion RRHH...',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _BootstrapError extends StatelessWidget {
  final Object error;

  const _BootstrapError({
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'No se pudo iniciar la app',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        SelectableText(
          error.toString(),
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }
}
