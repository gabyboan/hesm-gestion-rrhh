import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_gate.dart';
import 'cargar/cargar_horas_page.dart';
import 'ver/ver_horas_page.dart';
import 'informe/informe_page.dart'; // ✅ NUEVO

class HorasShell extends ConsumerStatefulWidget {
  const HorasShell({super.key});

  @override
  ConsumerState<HorasShell> createState() => _HorasShellState();
}

class _HorasShellState extends ConsumerState<HorasShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = const [
      CargarHorasPage(),
      VerHorasPage(),
      InformePage(), // ✅ NUEVO
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Horas'),
        actions: [
          IconButton(
            tooltip: 'Salir',
            onPressed: () => ref.read(authRepoProvider).signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            label: 'Cargar',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt),
            label: 'Ver',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            label: 'Informe', // ✅ NUEVO
          ),
        ],
      ),
    );
  }
}
