// lib/features/shell/presentation/main_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../../horas/presentation/cargar/cargar_horas_page.dart';
import '../../horas/presentation/informe/informe_page.dart';
import '../../horas/presentation/ver/ver_horas_page.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;
  bool _signingOut = false;

  static const _pages = <Widget>[
    CargarHorasPage(),
    VerHorasPage(),
    InformePage(),
  ];

  static const _destinations = <_ShellDestination>[
    _ShellDestination(
      icon: Icons.add_circle_outline,
      selectedIcon: Icons.add_circle,
      label: 'Cargar',
      title: 'Cargar horas',
    ),
    _ShellDestination(
      icon: Icons.list_alt_outlined,
      selectedIcon: Icons.list_alt,
      label: 'Ver',
      title: 'Ver horas',
    ),
    _ShellDestination(
      icon: Icons.analytics_outlined,
      selectedIcon: Icons.analytics,
      label: 'Informe',
      title: 'Informe de horas',
    ),
  ];

  Future<void> _signOut() async {
    if (_signingOut) return;

    setState(() => _signingOut = true);

    try {
      await ref.read(authRepoProvider).signOut();
    } catch (e) {
      if (!mounted) return;

      setState(() => _signingOut = false);

      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text('No se pudo cerrar sesión: ${_cleanError(e)}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  String _cleanError(Object e) {
    final msg = e.toString().trim();
    if (msg.isEmpty) return 'error desconocido';

    return msg.replaceFirst('Exception: ', '');
  }

  void _setIndex(int value) {
    if (value == _index) return;
    setState(() => _index = value);
  }

  @override
  Widget build(BuildContext context) {
    final destination = _destinations[_index];

    return Scaffold(
      appBar: AppBar(
        title: Text(destination.title),
        actions: [
          IconButton(
            tooltip: 'Salir',
            onPressed: _signingOut ? null : _signOut,
            icon: _signingOut
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout),
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _setIndex,
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}

class _ShellDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String title;

  const _ShellDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.title,
  });
}
