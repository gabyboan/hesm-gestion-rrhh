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
  StackTrace? _stackTrace;
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
      setState(() {
        _error = error;
        _stackTrace = stackTrace;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) {
      return const ProviderScope(child: App());
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: BootstrapStatusPage(
        error: _error,
        stackTrace: _stackTrace,
      ),
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

  final loadedEnv = definedSupabaseUrl.isEmpty || definedSupabaseAnonKey.isEmpty
      ? await _loadEnv()
      : const EnvLoadResult(env: <String, String>{}, searchedPaths: <String>[]);

  final supabaseUrl = definedSupabaseUrl.isNotEmpty
      ? definedSupabaseUrl
      : loadedEnv.env['SUPABASE_URL'];
  final supabaseAnonKey = definedSupabaseAnonKey.isNotEmpty
      ? definedSupabaseAnonKey
      : loadedEnv.env['SUPABASE_ANON_KEY'];

  if (supabaseUrl == null || supabaseUrl.isEmpty) {
    throw Exception(
      _missingCredentialMessage('SUPABASE_URL', loadedEnv.searchedPaths),
    );
  }
  if (supabaseAnonKey == null || supabaseAnonKey.isEmpty) {
    throw Exception(
      _missingCredentialMessage('SUPABASE_ANON_KEY', loadedEnv.searchedPaths),
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

String _missingCredentialMessage(String key, List<String> searchedPaths) {
  final buffer = StringBuffer()
    ..write('Falta $key. Crea un archivo llamado credenciales.env junto a ')
    ..write('app_horas.exe o inicia la app con --dart-define.');

  if (searchedPaths.isNotEmpty) {
    buffer
      ..write('\n\nUbicaciones revisadas:\n')
      ..write(searchedPaths.map((path) => '- $path').join('\n'));
  }

  return buffer.toString();
}

class EnvLoadResult {
  final Map<String, String> env;
  final List<String> searchedPaths;

  const EnvLoadResult({
    required this.env,
    required this.searchedPaths,
  });
}

Future<EnvLoadResult> _loadEnv() async {
  try {
    await dotenv.load(fileName: 'credenciales.env');
    return EnvLoadResult(env: dotenv.env, searchedPaths: const <String>[]);
  } catch (_) {
    return _loadEnvFromFileSystem();
  }
}

Future<EnvLoadResult> _loadEnvFromFileSystem() async {
  final candidates = <String>{
    '${Directory.current.path}${Platform.pathSeparator}credenciales.env',
    '${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}credenciales.env',
  };

  void addParents(Directory start) {
    var current = start;
    for (var i = 0; i < 8; i++) {
      candidates.add(
        '${current.path}${Platform.pathSeparator}credenciales.env',
      );

      final parent = current.parent;
      if (parent.path == current.path) break;
      current = parent;
    }
  }

  addParents(Directory.current);
  addParents(File(Platform.resolvedExecutable).parent);

  for (final path in candidates) {
    final file = File(path);
    if (!await file.exists()) continue;

    final env = <String, String>{};
    final lines = await file.readAsLines();

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      final separator = trimmed.indexOf('=');
      if (separator <= 0) continue;

      final key = trimmed.substring(0, separator).trim();
      var value = trimmed.substring(separator + 1).trim();

      if (value.length >= 2 &&
          ((value.startsWith('"') && value.endsWith('"')) ||
              (value.startsWith("'") && value.endsWith("'")))) {
        value = value.substring(1, value.length - 1);
      }

      env[key] = value;
    }

    if (env.isNotEmpty) {
      return EnvLoadResult(env: env, searchedPaths: candidates.toList());
    }
  }

  return EnvLoadResult(env: const {}, searchedPaths: candidates.toList());
}

class BootstrapStatusPage extends StatelessWidget {
  final Object? error;
  final StackTrace? stackTrace;

  const BootstrapStatusPage({
    super.key,
    required this.error,
    required this.stackTrace,
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
                  : _BootstrapError(
                      error: error!,
                      stackTrace: stackTrace,
                    ),
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
  final StackTrace? stackTrace;

  const _BootstrapError({
    required this.error,
    required this.stackTrace,
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
        if (stackTrace != null) ...[
          const SizedBox(height: 12),
          SelectableText(
            stackTrace.toString().split('\n').take(8).join('\n'),
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ],
    );
  }
}
