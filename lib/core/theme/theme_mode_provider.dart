import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeModeNotifier extends StateNotifier<bool> {
  ThemeModeNotifier() : super(false) {
    _loadSavedPreference();
  }

  static const _preferenceKey = 'geoportal_dark_theme';

  Future<void> _loadSavedPreference() async {
    final preferences = await SharedPreferences.getInstance();
    if (mounted) state = preferences.getBool(_preferenceKey) ?? false;
  }

  Future<void> setDarkMode(bool enabled) async {
    state = enabled;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_preferenceKey, enabled);
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, bool>((ref) => ThemeModeNotifier());
