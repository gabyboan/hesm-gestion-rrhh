import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:windows_single_instance/windows_single_instance.dart';

import 'app/app.dart';
import 'core/startup/startup_checks.dart';
import 'core/startup/startup_config.dart';
import 'core/updates/lan_update_gate.dart';
import 'core/updates/startup_update.dart';
import 'core/updates/windows_update_service.dart';
import 'core/widgets/startup_splash.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = FlutterError.presentError;
  runApp(BootstrapApp(args: args));
}

class BootstrapApp extends StatefulWidget {
  const BootstrapApp(
      {super.key,
      required this.args,
      this.checks,
      this.checkUpdates,
      this.application,
      this.minimumSplashDuration = const Duration(seconds: 5)});
  final List<String> args;
  final StartupChecks? checks;
  final Future<StartupUpdateState> Function()? checkUpdates;
  final Widget? application;
  final Duration minimumSplashDuration;

  @override
  State<BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<BootstrapApp> {
  late final StartupChecks _checks;
  final Map<StartupCheck, StartupCheckState> _results = {};
  final _navigatorKey = GlobalKey<NavigatorState>();
  StartupUpdateState _updates =
      const StartupUpdateState(StartupUpdateStatus.disabled);
  Future<void>? _instanceInitialization;
  Future<void>? _supabaseInitialization;
  bool _ready = false;
  bool _running = false;
  bool _servicesReady = false;
  bool _installingUpdate = false;
  final Stopwatch _presentation = Stopwatch()..start();
  bool _hasStarted = false;

  @override
  void initState() {
    super.initState();
    _checks = widget.checks ??
        StartupChecks(
            loadConfig: loadStartupConfig,
            ensureInstance: _ensureInstance,
            prepareApplication: _prepareApplication);
  }

  Future<void> _ensureInstance() async {
    if (!Platform.isWindows) return;
    _instanceInitialization ??= WindowsSingleInstance.ensureSingleInstance(
        widget.args, 'hesm_gestion_rrhh',
        onSecondWindow: (args) {});
    await _instanceInitialization!.timeout(const Duration(seconds: 5));
  }

  Future<void> _prepareApplication(StartupConfig config) async {
    // Cache the underlying operation: retrying after a timeout must not start
    // another initialization while the first is still completing.
    _supabaseInitialization ??= Supabase.initialize(
      url: config.endpoint.toString(),
      anonKey: config.clientKey,
      authOptions:
          const FlutterAuthClientOptions(localStorage: EmptyLocalStorage()),
    ).then((_) {});
    await _supabaseInitialization!.timeout(const Duration(seconds: 20));
  }

  Future<void> _start() async {
    if (_running) return;
    setState(() {
      _running = true;
      _servicesReady = false;
      _results.clear();
      _updates = StartupUpdateState(
          widget.checkUpdates != null || WindowsUpdateService.enabled
              ? StartupUpdateStatus.checking
              : StartupUpdateStatus.disabled);
    });
    final updateCheck = _checkUpdates();
    final timer = _hasStarted ? (Stopwatch()..start()) : _presentation;
    _hasStarted = true;
    final passed = await _checks.run((result) {
      if (mounted) setState(() => _results[result.check] = result);
    });
    await updateCheck;
    if (!mounted) return;
    if (!passed) {
      setState(() => _running = false);
      return;
    }
    final remaining = widget.minimumSplashDuration - timer.elapsed;
    if (remaining > Duration.zero) await Future<void>.delayed(remaining);
    if (mounted) {
      setState(() {
        _servicesReady = true;
        _ready = _updates.status != StartupUpdateStatus.available;
        _running = false;
      });
    }
  }

  Future<void> _checkUpdates() async {
    StartupUpdateState result;
    try {
      result = await (widget.checkUpdates ?? checkStartupUpdates)()
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      result = const StartupUpdateState(StartupUpdateStatus.unavailable);
    }
    if (mounted) setState(() => _updates = result);
  }

  void _continueWithoutUpdate() {
    if (!_servicesReady || _installingUpdate) return;
    setState(() => _ready = true);
  }

  Future<void> _installUpdate() async {
    final release = _updates.release;
    final dialogContext = _navigatorKey.currentState?.overlay?.context;
    if (release == null || dialogContext == null || _installingUpdate) return;
    setState(() => _installingUpdate = true);
    await offerLanUpdate(dialogContext, release, confirm: false);
    if (mounted) setState(() => _installingUpdate = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) {
      return widget.application ??
          ProviderScope(
              child: App(
            checkUpdatesOnStart: false,
            offeredUpdateVersion: _updates.release?.version,
          ));
    }
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'HESM - Gestión RRHH',
      theme: ThemeData(
          useMaterial3: true, colorSchemeSeed: const Color(0xFF045E63)),
      home: StartupSplash(
        checks: [
          for (final check in StartupCheck.values)
            _results[check] ?? StartupCheckState(check, CheckStatus.pending)
        ],
        onRetry: _running ? null : _start,
        onReady: _start,
        updates: _updates,
        onInstallUpdate: _installingUpdate ? null : _installUpdate,
        onIgnoreUpdate: _servicesReady && !_installingUpdate
            ? _continueWithoutUpdate
            : null,
      ),
    );
  }
}
