import 'package:flutter/foundation.dart';
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

/// Notifica a GoRouter que debe reevaluar `redirect` sin recrear el router.
///
/// `routerProvider` solía usar `ref.watch` sobre los providers de auth, lo
/// que reconstruía por completo el `GoRouter` (y ese `GoRouter` nuevo vuelve
/// a `initialLocation`, perdiendo la ruta real del usuario) cada vez que
/// cambiaba la sesión. Firebase autentica la cuenta apenas se crea, antes de
/// validar el código de aprobación, así que esa reconstrucción sacaba al
/// usuario de `/login` a mitad del registro. Con un `GoRouter` estable +
/// `refreshListenable`, `redirect` se reevalúa in-place sobre la ubicación
/// real, sin tirar el router.
class _RouterRefreshNotifier extends ChangeNotifier {
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // `ref.listen` puede disparar refresh() de forma síncrona mientras
  // Riverpod todavía está iterando sus propios listeners internos
  // (p. ej. al autenticarse durante el registro). Notificar en el mismo
  // stack causaba "Concurrent modification during iteration". Diferir a
  // un microtask deja que ese ciclo termine antes de reevaluar el redirect.
  void refresh() {
    Future.microtask(() {
      if (!_disposed) notifyListeners();
    });
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier();
  ref.onDispose(refreshNotifier.dispose);

  ref.listen(authStateProvider, (_, __) => refreshNotifier.refresh());
  ref.listen(localAuthSessionProvider, (_, __) => refreshNotifier.refresh());
  ref.listen(currentUserIsAdminProvider, (_, __) => refreshNotifier.refresh());
  ref.listen(currentUserPerfilProvider, (_, __) => refreshNotifier.refresh());
  ref.listen(currentUserProfileProvider, (_, __) => refreshNotifier.refresh());
  ref.listen(registrationInProgressProvider, (_, __) => refreshNotifier.refresh());

  return GoRouter(
    initialLocation: '/mapa',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final user = FirebaseAuth.instance.currentUser;
      final canUseLocalSession = localOnlyAuthMode && ref.read(localAuthSessionProvider);
      // Mientras un registro está en curso, Firebase ya autenticó la cuenta
      // recién creada aunque el código de aprobación aún no se validó — no
      // tratar esa sesión transitoria como un login válido.
      final registrationInProgress = ref.read(registrationInProgressProvider);
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

      final currentIsAdminAsync = ref.read(currentUserIsAdminProvider);
      if (currentIsAdminAsync.isLoading) {
        return null;
      }

      final isAdmin = currentIsAdminAsync.valueOrNull == true;
      if (isAdmin) {
        return null;
      }

      final currentProfileAsync = ref.read(currentUserProfileProvider);
      final currentPerfil = ref.read(currentUserPerfilProvider);
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
