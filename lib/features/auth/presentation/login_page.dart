// lib/features/auth/presentation/login_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme/theme_mode_provider.dart';
import '../../../core/widgets/startup_splash.dart';
import '../application/auth_providers.dart';
import '../application/session_timeout_provider.dart';

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
      await ref.read(sessionTimeoutProvider).prepareForLogin();
      await ref.read(authRepoProvider).signIn(
            email: _email.text,
            password: _pass.text,
          );
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
    final mode = ref.watch(themeModeProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final loginTheme = ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      colorSchemeSeed: const Color(0xFF045E63),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    return Theme(
      data: loginTheme,
      child: Scaffold(
        backgroundColor:
            dark ? const Color(0xFF101E29) : const Color(0xFFF0F4F6),
        body: SafeArea(
          child: LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth >= 960;
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: EdgeInsets.all(wide ? 40 : 20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Card(
                        margin: EdgeInsets.zero,
                        elevation: 0,
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                          side: BorderSide(
                              color: loginTheme.colorScheme.outlineVariant),
                        ),
                        child: _buildForm(context, mode, wide),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, ThemeMode mode, bool wide) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.all(wide ? 40 : 24),
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const HesmAnimatedMark(size: 60),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('HESM',
                            style: TextStyle(
                                fontSize: 24,
                                letterSpacing: 3,
                                color: cs.primary,
                                fontWeight: FontWeight.w800)),
                        Text('GESTIÓN RRHH',
                            style: TextStyle(
                                fontSize: 11,
                                letterSpacing: 1.5,
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip:
                        mode == ThemeMode.dark ? 'Tema claro' : 'Tema oscuro',
                    icon: Icon(mode == ThemeMode.dark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined),
                    onPressed: _loading ? null : _toggleTheme,
                  ),
                ],
              ),
              const SizedBox(height: 30),
              const Text('Iniciar sesión',
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.8)),
              const SizedBox(height: 10),
              Text(
                  'Ingresá con tu cuenta para acceder a tu espacio de trabajo.',
                  style: TextStyle(color: cs.onSurfaceVariant, height: 1.6)),
              const SizedBox(height: 32),
              TextFormField(
                controller: _email,
                enabled: !_loading,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [
                  AutofillHints.username,
                  AutofillHints.email
                ],
                autocorrect: false,
                enableSuggestions: false,
                validator: _validateEmail,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _pass,
                enabled: !_loading,
                obscureText: !_showPass,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                validator: _validatePassword,
                onFieldSubmitted: (_) => _login(),
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: _loading ? null : _togglePasswordVisibility,
                    icon: Icon(
                        _showPass ? Icons.visibility_off : Icons.visibility),
                    tooltip:
                        _showPass ? 'Ocultar contraseña' : 'Mostrar contraseña',
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Text(_error!, style: TextStyle(color: cs.error)),
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                height: 54,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _loading ? null : _login,
                  child: _loading
                      ? SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: cs.onPrimary))
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Ingresar',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600)),
                            SizedBox(width: 12),
                            Icon(Icons.arrow_forward, size: 19),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 28),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.fact_check_outlined, color: cs.primary, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Seguimiento operativo',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('Horas, novedades y partes médicos integrados.',
                          style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                              height: 1.5)),
                    ],
                  )),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.verified_user_outlined,
                      size: 18, color: cs.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text('Uso exclusivo del personal autorizado.',
                          style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                              height: 1.5))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
