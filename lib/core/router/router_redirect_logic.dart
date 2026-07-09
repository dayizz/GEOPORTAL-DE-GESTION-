String? resolveAuthRedirect({
  required bool isLoggedIn,
  required String matchedLocation,
  required bool allowLocalOnlyAuthBypass,
}) {
  final isLoginRoute = matchedLocation == '/login';
  final isTablaRoute = matchedLocation == '/tabla' ||
      matchedLocation.startsWith('/tabla/');
  final allowLocalTablaWithoutLogin = allowLocalOnlyAuthBypass && isTablaRoute;

  if (!isLoggedIn && !isLoginRoute && !allowLocalTablaWithoutLogin) {
    return '/login';
  }
  if (isLoggedIn && isLoginRoute) return '/mapa';
  return null;
}