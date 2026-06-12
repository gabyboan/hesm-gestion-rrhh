// lib/features/shell/presentation/main_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/app_snackbar.dart';
import '../../../core/utils/error_text.dart';
import '../../auth/application/auth_providers.dart';
import '../../francos/application/francos_providers.dart';
import '../../francos/presentation/francos_page.dart';
import '../../horas/presentation/cargar/cargar_horas_page.dart';
import '../../horas/presentation/informe/informe_page.dart';
import '../../horas/presentation/ver/ver_horas_page.dart';
import '../../imprevistos/application/imprevistos_providers.dart';
import '../../imprevistos/presentation/imprevistos_page.dart';
import '../../medicos/application/medicos_providers.dart';
import '../../medicos/presentation/medicos_page.dart';

enum _AppModule {
  horas,
  francos,
  imprevisto,
  medicos,
  capacitacion,
}

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  _AppModule? _selectedModule;
  int _horasIndex = 0;
  bool _signingOut = false;

  static const _horasPages = <Widget>[
    CargarHorasPage(),
    VerHorasPage(),
    InformePage(),
  ];

  static const _horasDestinations = <_ShellDestination>[
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

      AppSnackBar.error(
        context,
        'No se pudo cerrar sesión: ${cleanError(e)}',
      );
    }
  }

  void _openModule(_AppModule module) {
    if (module == _AppModule.francos) {
      ref.invalidate(puedeLeerFrancosProvider);
      ref.invalidate(puedeUsarBancoFrancosProvider);
      ref.invalidate(puedeAdministrarBancoFrancosProvider);
      ref.invalidate(francosListadoProvider);
      ref.invalidate(francosMovimientosProvider);
      ref.read(selectedFrancoPersonaProvider.notifier).state = null;
    }

    if (module == _AppModule.imprevisto) {
      ref.invalidate(puedeLeerImprevistosProvider);
      ref.invalidate(puedeCargarImprevistosProvider);
      ref.invalidate(puedeAdministrarImprevistosProvider);
      ref.invalidate(imprevistosListadoProvider);
      ref.invalidate(imprevistosRegistrosProvider);
      ref.read(selectedImprevistoPersonaProvider.notifier).state = null;
    }

    if (module == _AppModule.medicos) {
      ref.invalidate(puedeLeerMedicosProvider);
      ref.invalidate(puedeCrearMedicosProvider);
      ref.invalidate(puedeAdministrarMedicosProvider);
      ref.invalidate(medicosPersonasProvider);
      ref.invalidate(partesMedicosProvider);
      ref.read(selectedMedicoPersonaProvider.notifier).state = null;
    }

    setState(() => _selectedModule = module);
  }

  void _backToModules() {
    setState(() => _selectedModule = null);
  }

  void _setHorasIndex(int value) {
    if (value == _horasIndex) return;
    setState(() => _horasIndex = value);
  }

  @override
  Widget build(BuildContext context) {
    final selectedModule = _selectedModule;

    if (selectedModule == null) {
      return _ModulesDashboard(
        signingOut: _signingOut,
        onSignOut: _signOut,
        onOpenModule: _openModule,
      );
    }

    return switch (selectedModule) {
      _AppModule.horas => _HorasShell(
          index: _horasIndex,
          destinations: _horasDestinations,
          pages: _horasPages,
          signingOut: _signingOut,
          onBackToModules: _backToModules,
          onSignOut: _signOut,
          onDestinationSelected: _setHorasIndex,
        ),
      _AppModule.francos => _SinglePageModuleShell(
          title: 'Francos',
          body: const FrancosPage(),
          signingOut: _signingOut,
          onBackToModules: _backToModules,
          onSignOut: _signOut,
        ),
      _AppModule.imprevisto => _SinglePageModuleShell(
          title: 'Imprevisto',
          body: const ImprevistosPage(),
          signingOut: _signingOut,
          onBackToModules: _backToModules,
          onSignOut: _signOut,
        ),
      _AppModule.medicos => _SinglePageModuleShell(
          title: 'Médicos',
          body: const MedicosPage(),
          signingOut: _signingOut,
          onBackToModules: _backToModules,
          onSignOut: _signOut,
        ),
      _AppModule.capacitacion => _PlaceholderModuleShell(
          title: 'Capacitación',
          message: 'Módulo de capacitación en preparación',
          signingOut: _signingOut,
          onBackToModules: _backToModules,
          onSignOut: _signOut,
        ),
    };
  }
}

class _ModulesDashboard extends StatelessWidget {
  final bool signingOut;
  final VoidCallback onSignOut;
  final ValueChanged<_AppModule> onOpenModule;

  const _ModulesDashboard({
    required this.signingOut,
    required this.onSignOut,
    required this.onOpenModule,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Servicios'),
        actions: [
          IconButton(
            tooltip: 'Salir',
            onPressed: signingOut ? null : onSignOut,
            icon: signingOut
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 760;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Módulos',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Seleccioná el área de trabajo',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 24),
                    GridView.count(
                      crossAxisCount: isCompact ? 1 : 3,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: isCompact ? 2.5 : 1.85,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _ModuleHeroCard(
                          icon: Icons.schedule,
                          title: 'Horas',
                          detail: 'Cargar, consultar y exportar informes',
                          color: const Color(0xFF4F46E5),
                          onTap: () => onOpenModule(_AppModule.horas),
                        ),
                        _ModuleHeroCard(
                          icon: Icons.event_available,
                          title: 'Francos',
                          detail: 'Gestión de francos del personal',
                          color: const Color(0xFF0891B2),
                          onTap: () => onOpenModule(_AppModule.francos),
                        ),
                        _ModuleHeroCard(
                          icon: Icons.warning_amber_outlined,
                          title: 'Imprevisto',
                          detail: 'Registro y seguimiento de imprevistos',
                          color: const Color(0xFFDC2626),
                          onTap: () => onOpenModule(_AppModule.imprevisto),
                        ),
                        _ModuleHeroCard(
                          icon: Icons.medical_services_outlined,
                          title: 'Médicos',
                          detail: 'Gestión de novedades médicas',
                          color: const Color(0xFF16A34A),
                          onTap: () => onOpenModule(_AppModule.medicos),
                        ),
                        _ModuleHeroCard(
                          icon: Icons.school_outlined,
                          title: 'Capacitación',
                          detail: 'Capacitaciones y actividades formativas',
                          color: const Color(0xFF7C3AED),
                          onTap: () => onOpenModule(_AppModule.capacitacion),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HorasShell extends StatelessWidget {
  final int index;
  final List<_ShellDestination> destinations;
  final List<Widget> pages;
  final bool signingOut;
  final VoidCallback onBackToModules;
  final VoidCallback onSignOut;
  final ValueChanged<int> onDestinationSelected;

  const _HorasShell({
    required this.index,
    required this.destinations,
    required this.pages,
    required this.signingOut,
    required this.onBackToModules,
    required this.onSignOut,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final destination = destinations[index];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Módulos',
          onPressed: onBackToModules,
          icon: const Icon(Icons.apps),
        ),
        title: Text(destination.title),
        actions: [
          IconButton(
            tooltip: 'Salir',
            onPressed: signingOut ? null : onSignOut,
            icon: signingOut
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
        index: index,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: onDestinationSelected,
        destinations: [
          for (final d in destinations)
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

class _PlaceholderModuleShell extends StatelessWidget {
  final String title;
  final String message;
  final bool signingOut;
  final VoidCallback onBackToModules;
  final VoidCallback onSignOut;

  const _PlaceholderModuleShell({
    required this.title,
    required this.message,
    required this.signingOut,
    required this.onBackToModules,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Módulos',
          onPressed: onBackToModules,
          icon: const Icon(Icons.apps),
        ),
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Salir',
            onPressed: signingOut ? null : onSignOut,
            icon: signingOut
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: Text(message),
      ),
    );
  }
}

class _SinglePageModuleShell extends StatelessWidget {
  final String title;
  final Widget body;
  final bool signingOut;
  final VoidCallback onBackToModules;
  final VoidCallback onSignOut;

  const _SinglePageModuleShell({
    required this.title,
    required this.body,
    required this.signingOut,
    required this.onBackToModules,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Módulos',
          onPressed: onBackToModules,
          icon: const Icon(Icons.apps),
        ),
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Salir',
            onPressed: signingOut ? null : onSignOut,
            icon: signingOut
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout),
          ),
        ],
      ),
      body: body,
    );
  }
}

class _ModuleHeroCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final Color color;
  final VoidCallback onTap;

  const _ModuleHeroCard({
    required this.icon,
    required this.title,
    required this.detail,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final onColor =
        color.computeLuminance() > 0.5 ? Colors.black : Colors.white;

    return Card(
      elevation: 0,
      color: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 32,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: onColor,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: onColor.withValues(alpha: 0.86),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: onColor),
            ],
          ),
        ),
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
