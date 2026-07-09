import 'package:flutter_test/flutter_test.dart';
import 'package:geoportal_predios/core/router/router_redirect_logic.dart';

void main() {
  group('resolveAuthRedirect', () {
    test('redirects unauthenticated users to login for protected routes', () {
      final redirect = resolveAuthRedirect(
        isLoggedIn: false,
        matchedLocation: '/mapa',
        allowLocalOnlyAuthBypass: true,
      );

      expect(redirect, '/login');
    });

    test('allows unauthenticated access to tabla in local-only mode', () {
      final redirect = resolveAuthRedirect(
        isLoggedIn: false,
        matchedLocation: '/tabla',
        allowLocalOnlyAuthBypass: true,
      );

      expect(redirect, isNull);
    });

    test('keeps tabla protected when local-only bypass is disabled', () {
      final redirect = resolveAuthRedirect(
        isLoggedIn: false,
        matchedLocation: '/tabla',
        allowLocalOnlyAuthBypass: false,
      );

      expect(redirect, '/login');
    });

    test('redirects authenticated users away from login', () {
      final redirect = resolveAuthRedirect(
        isLoggedIn: true,
        matchedLocation: '/login',
        allowLocalOnlyAuthBypass: true,
      );

      expect(redirect, '/mapa');
    });
  });
}