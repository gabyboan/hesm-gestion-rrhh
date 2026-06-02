import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:windows_single_instance/windows_single_instance.dart';

import 'app/app.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Evita doble instancia en Windows.
  if (Platform.isWindows) {
    await WindowsSingleInstance.ensureSingleInstance(
      args,
      'hesm_gestion_rrhh',
      onSecondWindow: (args) {},
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
      'Falta SUPABASE_URL. Usá --dart-define o credenciales.env.',
    );
  }
  if (supabaseAnonKey == null || supabaseAnonKey.isEmpty) {
    throw Exception(
      'Falta SUPABASE_ANON_KEY. Usá --dart-define o credenciales.env.',
    );
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      localStorage: EmptyLocalStorage(),
    ),
  );

  runApp(const ProviderScope(child: App()));
}
