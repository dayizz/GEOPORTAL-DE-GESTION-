import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/auth/session_cleanup.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'core/constants/app_colors.dart';
import 'features/auth/providers/auth_provider.dart';

class GeoportalApp extends ConsumerStatefulWidget {
  const GeoportalApp({super.key});

  @override
  ConsumerState<GeoportalApp> createState() => _GeoportalAppState();
}

class _GeoportalAppState extends ConsumerState<GeoportalApp>
    with WidgetsBindingObserver {
  static const _timeout = Duration(hours: 3);
  static const _preferenceWriteInterval = Duration(seconds: 30);

  Timer? _expiryTimer;
  DateTime? _lastActivity;
  DateTime? _lastPreferenceWrite;
  bool _authResolved = false;
  bool _sessionActive = false;
  bool _expirationInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (kIsWeb) unawaited(_restoreSessionActivity());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _expiryTimer?.cancel();
    super.dispose();
  }

  Future<void> _restoreSessionActivity() async {
    try {
      await ref.read(authStateProvider.future);
    } catch (_) {
      // Si Firebase falla, se conserva la posibilidad de sesión local.
    }
    if (!mounted) return;

    _authResolved = true;
    final isLoggedIn =
        FirebaseAuth.instance.currentUser != null ||
        (localOnlyAuthMode && ref.read(localAuthSessionProvider));
    if (!isLoggedIn) {
      _sessionActive = false;
      await _clearActivityTimestamp();
      return;
    }

    int? savedMilliseconds;
    try {
      final preferences = await SharedPreferences.getInstance();
      savedMilliseconds = preferences.getInt(sessionLastActivityKey);
    } catch (_) {
      // Si el navegador bloquea el almacenamiento, iniciar un contador local.
    }
    final now = DateTime.now();
    if (savedMilliseconds != null) {
      _lastActivity = DateTime.fromMillisecondsSinceEpoch(savedMilliseconds);
      if (now.difference(_lastActivity!) >= _timeout) {
        await _expireSession();
        return;
      }
    } else {
      _lastActivity = now;
      await _persistActivity(now, force: true);
    }
    _sessionActive = true;
    _scheduleExpiration();
  }

  Future<void> _clearActivityTimestamp() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(sessionLastActivityKey);
    } catch (_) {
      // No bloquear navegación si el almacenamiento local no está disponible.
    }
  }

  void _recordActivity() {
    if (!kIsWeb || !_authResolved || !_sessionActive || _expirationInProgress) {
      return;
    }
    final now = DateTime.now();
    final previousActivity = _lastActivity;
    if (previousActivity != null &&
        now.difference(previousActivity) >= _timeout) {
      unawaited(_expireSession());
      return;
    }
    _lastActivity = now;
    _scheduleExpiration();
    unawaited(_persistActivity(now));
  }

  Future<void> _persistActivity(DateTime time, {bool force = false}) async {
    if (!force &&
        _lastPreferenceWrite != null &&
        time.difference(_lastPreferenceWrite!) < _preferenceWriteInterval) {
      return;
    }
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setInt(
        sessionLastActivityKey,
        time.millisecondsSinceEpoch,
      );
      _lastPreferenceWrite = time;
    } catch (_) {
      // El timer en memoria sigue cubriendo la sesión abierta.
    }
  }

  void _scheduleExpiration() {
    _expiryTimer?.cancel();
    final lastActivity = _lastActivity;
    if (!_sessionActive || lastActivity == null) return;
    final remaining = _timeout - DateTime.now().difference(lastActivity);
    _expiryTimer = Timer(remaining.isNegative ? Duration.zero : remaining, () {
      final elapsed = DateTime.now().difference(_lastActivity ?? lastActivity);
      if (elapsed >= _timeout) {
        unawaited(_expireSession());
      } else {
        _scheduleExpiration();
      }
    });
  }

  Future<void> _expireSession() async {
    if (_expirationInProgress || !mounted) return;
    _expirationInProgress = true;
    _sessionActive = false;
    _expiryTimer?.cancel();
    await closeSessionAndClearState(ref);
    if (mounted) {
      ref.read(routerProvider).go('/login');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!kIsWeb || !_sessionActive) return;
    if (state == AppLifecycleState.resumed) {
      _recordActivity();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      final lastActivity = _lastActivity;
      if (lastActivity != null) {
        unawaited(_persistActivity(lastActivity, force: true));
      }
    }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      _recordActivity();
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<User?>>(authStateProvider, (previous, next) {
      if (!kIsWeb || !_authResolved) return;
      final user = next.valueOrNull;
      final localSession =
          localOnlyAuthMode && ref.read(localAuthSessionProvider);
      if (user != null || localSession) {
        if (!_sessionActive) {
          _sessionActive = true;
          _lastActivity = DateTime.now();
          unawaited(_persistActivity(_lastActivity!, force: true));
          _scheduleExpiration();
        }
      } else if (_sessionActive) {
        _sessionActive = false;
        _expiryTimer?.cancel();
        unawaited(_clearActivityTimestamp());
      }
    });
    ref.listen<bool>(localAuthSessionProvider, (previous, isLoggedIn) {
      if (!kIsWeb || !_authResolved || !localOnlyAuthMode) return;
      if (isLoggedIn && !_sessionActive) {
        _sessionActive = true;
        _lastActivity = DateTime.now();
        unawaited(_persistActivity(_lastActivity!, force: true));
        _scheduleExpiration();
      }
    });

    final router = ref.watch(routerProvider);
    final isDarkMode = ref.watch(themeModeProvider);
    AppColors.darkModeEnabled = isDarkMode;

    return MaterialApp.router(
      title: 'Geoportal Predios',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      locale: const Locale('es', 'MX'),
      supportedLocales: const [Locale('es', 'MX'), Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      routerConfig: router,
      builder: (context, child) => Focus(
        onKeyEvent: _handleKey,
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _recordActivity(),
          onPointerMove: (_) => _recordActivity(),
          onPointerSignal: (_) => _recordActivity(),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}
