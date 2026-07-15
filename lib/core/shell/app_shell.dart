import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../main.dart';
import '../../core/utils/responsive_helper.dart';

class AppShell extends ConsumerStatefulWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _onDestinationSelected(int index) {
    setState(() => _selectedIndex = index);
    const routes = [
      '/dashboard',
      '/lessons-shell',
      '/relapse',
      '/money',
      '/health',
      '/activities',
      '/games',
      '/profile',
    ];
    context.go(routes[index]);
    // Cerrar drawer si está abierto
    if (_scaffoldKey.currentState?.isEndDrawerOpen ?? false) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = ResponsiveHelper(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (r.isDesktop) {
          return _DesktopLayout(
            theme: theme,
            selectedIndex: _selectedIndex,
            onSelect: _onDestinationSelected,
            child: widget.child,
          );
        }
        return _MobileDrawerLayout(
          theme: theme,
          scaffoldKey: _scaffoldKey,
          selectedIndex: _selectedIndex,
          onSelect: _onDestinationSelected,
          child: widget.child,
        );
      },
    );
  }
}

class _DesktopLayout extends ConsumerWidget {
  final ThemeData theme;
  final int selectedIndex;
  final void Function(int) onSelect;
  final Widget child;

  const _DesktopLayout({
    required this.theme,
    required this.selectedIndex,
    required this.onSelect,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: onSelect,
            backgroundColor: theme.colorScheme.surface,
            indicatorColor: theme.colorScheme.primary.withValues(alpha: 0.15),
            labelType: NavigationRailLabelType.all,
            minWidth: 80,
            groupAlignment: -0.85,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Icon(
                Icons.shield_outlined,
                color: theme.colorScheme.primary,
                size: 36,
              ),
            ),
            trailing: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: IconButton(
                icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: theme.colorScheme.primary,
                ),
                tooltip: isDark ? 'Tema claro' : 'Tema oscuro',
                onPressed: () {
                  ref.read(themeModeProvider.notifier).toggle();
                },
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: Text('Inicio'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.school_outlined),
                selectedIcon: Icon(Icons.school_rounded),
                label: Text('Aprender'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.warning_amber_outlined),
                selectedIcon: Icon(Icons.warning_amber_rounded),
                label: Text('Recaidas'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.savings_outlined),
                selectedIcon: Icon(Icons.savings_rounded),
                label: Text('Finanzas'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.fitness_center_outlined),
                selectedIcon: Icon(Icons.fitness_center),
                label: Text('Salud'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.checklist_outlined),
                selectedIcon: Icon(Icons.checklist_rounded),
                label: Text('Tareas'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.sports_esports_outlined),
                selectedIcon: Icon(Icons.sports_esports),
                label: Text('Juegos'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: Text('Perfil'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _MobileDrawerLayout extends ConsumerWidget {
  final ThemeData theme;
  final GlobalKey<ScaffoldState> scaffoldKey;
  final int selectedIndex;
  final void Function(int) onSelect;
  final Widget child;

  const _MobileDrawerLayout({
    required this.theme,
    required this.scaffoldKey,
    required this.selectedIndex,
    required this.onSelect,
    required this.child,
  });

  static const _navItems = [
    (Icons.home_outlined, Icons.home_rounded, 'Inicio'),
    (Icons.school_outlined, Icons.school_rounded, 'Aprender'),
    (Icons.warning_amber_outlined, Icons.warning_amber_rounded, 'Recaidas'),
    (Icons.savings_outlined, Icons.savings_rounded, 'Finanzas'),
    (Icons.fitness_center_outlined, Icons.fitness_center, 'Salud'),
    (Icons.checklist_outlined, Icons.checklist_rounded, 'Tareas'),
    (Icons.sports_esports_outlined, Icons.sports_esports, 'Juegos'),
    (Icons.person_outline, Icons.person, 'Perfil'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = theme.brightness == Brightness.dark;
    final neon = theme.colorScheme.primary;

    return Scaffold(
      key: scaffoldKey,
      endDrawer: Drawer(
        backgroundColor: theme.colorScheme.surface,
        width: 260,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header del drawer
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined, color: neon, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      'StopingYourself',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(),
              const SizedBox(height: 8),
              // Lista de navegación
              ...List.generate(_navItems.length, (i) {
                final (iconOutlined, iconFilled, label) = _navItems[i];
                final selected = selectedIndex == i;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  child: Material(
                    color: selected ? neon.withValues(alpha: 0.12) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onSelect(i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Icon(
                              selected ? iconFilled : iconOutlined,
                              color: selected ? neon : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                              size: 22,
                            ),
                            const SizedBox(width: 14),
                            Text(
                              label,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                                color: selected ? neon : theme.colorScheme.onSurface.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const Spacer(),
              // Toggle de tema
              const Divider(),
              ListTile(
                leading: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: neon,
                ),
                title: Text(
                  isDark ? 'Tema claro' : 'Tema oscuro',
                  style: GoogleFonts.inter(color: theme.colorScheme.onSurface),
                ),
                onTap: () {
                  ref.read(themeModeProvider.notifier).toggle();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          child,
          // Botón de menú hamburguesa (esquina superior derecha)
          Positioned(
            top: 8,
            right: 4,
            child: Material(
              color: theme.colorScheme.surface.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => scaffoldKey.currentState?.openEndDrawer(),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    Icons.menu_rounded,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
