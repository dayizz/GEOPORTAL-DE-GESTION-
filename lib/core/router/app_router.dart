import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/mapa/presentation/mapa_screen.dart';
import '../../features/predios/presentation/predios_list_screen.dart';
import '../../features/predios/presentation/predio_detail_screen.dart';
import '../../features/predios/presentation/predio_form_screen.dart';
import '../../features/predios/presentation/proyectos_screen.dart';
import '../../features/propietarios/presentation/propietarios_list_screen.dart';
import '../../features/propietarios/presentation/propietario_form_screen.dart';
import '../../features/propietarios/presentation/propietario_detail_screen.dart';
import '../../features/reportes/presentation/balance_screen.dart';
import '../../features/reportes/presentation/generar_reporte_screen.dart';
import '../../features/carga/presentation/carga_archivo_screen.dart';
import '../../features/tabla/presentation/tabla_screen.dart';
import '../../features/perfil/presentation/perfil_screen.dart';
import '../../features/estructura/presentation/estructura_screen.dart';
import 'router_redirect_logic.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Observar cambios de auth para refrescar el redirect
  ref.watch(authStateProvider);
  final localSession = ref.watch(localAuthSessionProvider);
  final currentIsAdminAsync = ref.watch(currentUserIsAdminProvider);
  final currentPerfil = ref.watch(currentUserPerfilProvider);
  final currentProfileAsync = ref.watch(currentUserProfileProvider);
  final registrationInProgress = ref.watch(registrationInProgressProvider);

  return GoRouter(
    initialLocation: '/mapa',
    redirect: (context, state) {
      final user = FirebaseAuth.instance.currentUser;
      final canUseLocalSession = localOnlyAuthMode && localSession;
      // Mientras un registro está en curso, Firebase ya autenticó la cuenta
      // recién creada aunque el código de aprobación aún no se validó — no
      // tratar esa sesión transitoria como un login válido.
      final isLoggedIn =
          !registrationInProgress && (user != null || canUseLocalSession);
      final authRedirect = resolveAuthRedirect(
        isLoggedIn: isLoggedIn,
        matchedLocation: state.matchedLocation,
        allowLocalOnlyAuthBypass: localOnlyAuthMode,
      );

      if (authRedirect != null) {
        return authRedirect;
      }

      if (currentIsAdminAsync.isLoading) {
        return null;
      }

      final isAdmin = currentIsAdminAsync.valueOrNull == true;
      if (isAdmin) {
        return null;
      }

      if (!currentProfileAsync.isLoading &&
          !canAccessRouteByPerfil(state.matchedLocation, currentPerfil)) {
        return '/mapa';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/',
        redirect: (_, __) => '/mapa',
      ),
      GoRoute(
        path: '/mapa',
        pageBuilder: (_, __) => const NoTransitionPage(
          child: MapaScreen(),
        ),
      ),
      GoRoute(
        path: '/predios',
        builder: (_, __) => const PrediosListScreen(),
        routes: [
          GoRoute(
            path: 'nuevo',
            builder: (_, __) => const PredioFormScreen(),
          ),
          GoRoute(
            path: ':id',
            builder: (_, state) => PredioDetailScreen(id: state.pathParameters['id']!),
            routes: [
              GoRoute(
                path: 'editar',
                builder: (_, state) => PredioFormScreen(
                  id: state.pathParameters['id'],
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/propietarios',
        builder: (_, __) => const PropietariosListScreen(),
        routes: [
          GoRoute(
            path: 'nuevo',
            builder: (_, __) => const PropietarioFormScreen(),
          ),
          GoRoute(
            path: ':id',
            builder: (_, state) =>
                PropietarioDetailScreen(id: state.pathParameters['id']!),
            routes: [
              GoRoute(
                path: 'editar',
                builder: (_, state) => PropietarioFormScreen(
                  id: state.pathParameters['id'],
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/reportes',
        pageBuilder: (_, __) => const NoTransitionPage(
          child: GenerarReporteScreen(),
        ),
      ),
      GoRoute(
        path: '/balance',
        pageBuilder: (_, __) => const NoTransitionPage(
          child: BalanceScreen(),
        ),
      ),
      GoRoute(
        path: '/balance/generar',
        redirect: (_, __) => '/reportes',
      ),
      GoRoute(
        path: '/carga',
        pageBuilder: (_, __) => const NoTransitionPage(
          child: CargaArchivoScreen(),
        ),
      ),
      GoRoute(
        path: '/tabla',
        pageBuilder: (_, __) => const NoTransitionPage(
          child: TablaScreen(),
        ),
      ),
      GoRoute(
        path: '/proyectos',
        builder: (_, __) => const ProyectosScreen(),
      ),
      GoRoute(
        path: '/perfil',
        pageBuilder: (_, __) => const NoTransitionPage(
          child: PerfilScreen(),
        ),
      ),
      GoRoute(
        path: '/estructura',
        pageBuilder: (_, __) => const NoTransitionPage(
          child: EstructuraScreen(),
        ),
      ),
    ],
  );
});
