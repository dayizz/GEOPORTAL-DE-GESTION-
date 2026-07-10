import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
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
  ];
  static const double _desktopRailWidth = 88;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = MediaQuery.of(context).size.width > 768;
    final perfil = ref.watch(currentUserPerfilProvider);

    void onTapItem(int i) {
      final item = _navItems[i];
      if (!item.isVisible(perfil)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No tienes permiso para acceder a esta seccion.')),
        );
        return;
      }
      context.go(item.route);
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
                  selectedIndex: currentIndex,
                  onDestinationSelected: onTapItem,
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
                          child: const Icon(Icons.map, color: Colors.white, size: 22),
                        ),
                      ],
                    ),
                  ),
                  destinations: _navItems
                      .map((item) => NavigationRailDestination(
                            icon: Icon(item.icon),
                            selectedIcon: Icon(
                              item.icon,
                              color: AppColors.primary,
                            ),
                            label: Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 11,
                                color: item.isVisible(perfil)
                                    ? null
                                    : Colors.grey,
                              ),
                            ),
                          ))
                      .toList(),
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
        selectedIndex: currentIndex,
        onDestinationSelected: onTapItem,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: _navItems
            .map((item) => NavigationDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.icon, color: AppColors.primary),
                  label: item.label,
                ))
            .toList(),
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}
