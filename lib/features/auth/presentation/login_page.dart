// lib/features/auth/presentation/login_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme/theme_mode_provider.dart';
//import 'auth_gate.dart';
import '../application/auth_providers.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();

  final _email = TextEditingController();
  final _pass = TextEditingController();

  bool _loading = false;
  bool _showPass = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    if (_loading) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref.read(authRepoProvider).signIn(
            email: _email.text,
            password: _pass.text,
          );

      ref.invalidate(authSessionProvider);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = _authErrorMessage(e));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _genericErrorMessage(e));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) {
      return 'Ingresá tu email';
    }

    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    if (!ok) {
      return 'Ingresá un email válido';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';

    if (password.isEmpty) {
      return 'Ingresá tu contraseña';
    }

    return null;
  }

  String _authErrorMessage(AuthException e) {
    final msg = e.message.trim();

    if (msg.isEmpty) {
      return 'No se pudo iniciar sesión.';
    }

    final lower = msg.toLowerCase();

    if (lower.contains('invalid login credentials')) {
      return 'Email o contraseña incorrectos.';
    }

    if (lower.contains('email not confirmed')) {
      return 'El email todavía no fue confirmado.';
    }

    return msg;
  }

  String _genericErrorMessage(Object e) {
    final msg = e.toString().trim();

    if (msg.isEmpty) {
      return 'No se pudo iniciar sesión.';
    }

    return msg.replaceFirst('Exception: ', '');
  }

  void _toggleTheme() {
    final current = ref.read(themeModeProvider);

    ref.read(themeModeProvider.notifier).state =
        current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }

  void _togglePasswordVisibility() {
    setState(() => _showPass = !_showPass);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: mode == ThemeMode.dark ? 'Tema claro' : 'Tema oscuro',
            icon: Icon(
              mode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: _loading ? null : _toggleTheme,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: AutofillGroup(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Ingreso',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _email,
                            enabled: !_loading,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [
                              AutofillHints.username,
                              AutofillHints.email,
                            ],
                            autocorrect: false,
                            enableSuggestions: false,
                            validator: _validateEmail,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _pass,
                            enabled: !_loading,
                            obscureText: !_showPass,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [
                              AutofillHints.password,
                            ],
                            validator: _validatePassword,
                            onFieldSubmitted: (_) => _login(),
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                onPressed:
                                    _loading ? null : _togglePasswordVisibility,
                                icon: Icon(
                                  _showPass
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                tooltip: _showPass
                                    ? 'Ocultar contraseña'
                                    : 'Mostrar contraseña',
                              ),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: cs.error,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton(
                              onPressed: _loading ? null : _login,
                              child: _loading
                                  ? SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: cs.onPrimary,
                                      ),
                                    )
                                  : const Text(
                                      'Entrar',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
