import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/auth/session_cleanup.dart';
import '../../features/auth/providers/auth_provider.dart';

class _NavItem {
  final IconData icon;
  final String label;
  final String route;
  final bool Function(String perfil) isVisible;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.isVisible,
  });
}

class AppScaffold extends ConsumerWidget {
  final Widget child;
  final int currentIndex;
  final String title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  const AppScaffold({
    super.key,
    required this.child,
    required this.currentIndex,
    required this.title,
    this.actions,
    this.floatingActionButton,
  });

  static final _navItems = [
    _NavItem(
      icon: Icons.map_outlined,
      label: AppStrings.mapa,
      route: '/mapa',
      isVisible: (perfil) => canAccessRouteByPerfil('/mapa', perfil),
    ),
    _NavItem(
      icon: Icons.analytics_outlined,
      label: 'Balance',
      route: '/balance',
      isVisible: (perfil) => canAccessRouteByPerfil('/balance', perfil),
    ),
    _NavItem(
      icon: Icons.upload_file_outlined,
      label: 'Archivos',
      route: '/carga',
      isVisible: (perfil) => canAccessRouteByPerfil('/carga', perfil),
    ),
    _NavItem(
      icon: Icons.folder_outlined,
      label: 'Gestion',
      route: '/tabla',
      isVisible: (perfil) => canAccessRouteByPerfil('/tabla', perfil),
    ),
    _NavItem(
      icon: Icons.receipt_long_outlined,
      label: 'Reportes',
      route: '/reportes',
      isVisible: (perfil) => canAccessRouteByPerfil('/reportes', perfil),
    ),
    _NavItem(
      icon: Icons.person_outlined,
      label: 'Perfil',
      route: '/perfil',
      isVisible: (perfil) => canAccessRouteByPerfil('/perfil', perfil),
    ),
    _NavItem(
      icon: Icons.account_tree_outlined,
      label: 'Estructura',
      route: '/estructura',
      isVisible: (perfil) => canAccessRouteByPerfil('/estructura', perfil),
    ),
    _NavItem(
      icon: Icons.image_outlined,
      label: 'Composiciones',
      route: '/composiciones',
      isVisible: (perfil) => canAccessRouteByPerfil('/composiciones', perfil),
    ),
  ];
  static const double _desktopRailWidth = 88;

  Future<void> _confirmarCierreSesion(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final isDarkMode =
            Theme.of(dialogContext).brightness == Brightness.dark;
        final dialogTextColor = isDarkMode ? Colors.white : null;
        return AlertDialog(
          title: Text(
            'Cerrar sesión',
            style: TextStyle(color: dialogTextColor),
          ),
          content: Text(
            '¿Deseas cerrar sesión?',
            style: TextStyle(color: dialogTextColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              style: TextButton.styleFrom(foregroundColor: dialogTextColor),
              child: Text('No', style: TextStyle(color: dialogTextColor)),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                foregroundColor: isDarkMode ? Colors.white : null,
              ),
              child: Text('Sí', style: TextStyle(color: dialogTextColor)),
            ),
          ],
        );
      },
    );
    if (confirmar != true) return;

    await closeSessionAndClearState(ref);

    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = MediaQuery.of(context).size.width > 768;
    final perfil = ref.watch(currentUserPerfilProvider);

    final visibleItems = _navItems
        .where((item) => item.isVisible(perfil))
        .toList(growable: false);
    final currentRoute = _navItems[currentIndex].route;
    final rawSelectedIndex = visibleItems.indexWhere(
      (item) => item.route == currentRoute,
    );
    final selectedIndex = rawSelectedIndex < 0 ? 0 : rawSelectedIndex;

    void onTapItem(int i) {
      context.go(visibleItems[i].route);
    }

    if (isWide) {
      return Scaffold(
        appBar: AppBar(title: Text(title), actions: actions),
        body: SafeArea(
          top: false,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: _desktopRailWidth,
                child: NavigationRail(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (index) {
                    if (index == visibleItems.length) {
                      _confirmarCierreSesion(context, ref);
                    } else {
                      onTapItem(index);
                    }
                  },
                  labelType: NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.map,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                  destinations:
                      visibleItems
                          .map(
                            (item) => NavigationRailDestination(
                              icon: Icon(item.icon),
                              selectedIcon: Icon(
                                item.icon,
                                color: AppColors.primary,
                              ),
                              label: Text(
                                item.label,
                                style: const TextStyle(fontSize: 10),
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList()
                        ..add(
                          const NavigationRailDestination(
                            icon: Icon(Icons.logout),
                            label: Text(
                              'Cerrar sesión',
                              style: TextStyle(fontSize: 10),
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                // Evita que widgets del contenido pinten encima del menú lateral.
                child: ClipRect(child: child),
              ),
            ],
          ),
        ),
        floatingActionButton: floatingActionButton,
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          if (index == visibleItems.length) {
            _confirmarCierreSesion(context, ref);
          } else {
            onTapItem(index);
          }
        },
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations:
            visibleItems
                .map(
                  (item) => NavigationDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.icon, color: AppColors.primary),
                    label: item.label,
                  ),
                )
                .toList()
              ..add(
                const NavigationDestination(
                  icon: Icon(Icons.logout),
                  label: 'Cerrar sesión',
                ),
              ),
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}
