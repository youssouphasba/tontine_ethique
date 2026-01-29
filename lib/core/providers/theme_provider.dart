import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme Mode Provider - Manages app theme preference
/// 
/// Stores user preference in SharedPreferences for persistence

const String _themeModeKey = 'theme_mode';

/// Notifier that manages theme state
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.light) {
    _loadThemeMode();
  }

  /// Load saved theme preference from storage
  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString(_themeModeKey);
      
      if (savedMode != null) {
        switch (savedMode) {
          case 'light':
            state = ThemeMode.light;
            break;
          case 'dark':
            state = ThemeMode.dark;
            break;
          default:
            state = ThemeMode.system;
        }
      }
      debugPrint('THEME: Loaded theme mode: $state');
    } catch (e) {
      debugPrint('THEME: Error loading theme: $e');
    }
  }

  /// Set theme mode and persist to storage
  void setThemeMode(ThemeMode mode) {
    // Update state synchronously first
    state = mode;
    
    // Save to storage asynchronously (fire and forget)
    _saveThemeMode(mode);
  }

  /// Save theme to SharedPreferences (async, non-blocking)
  Future<void> _saveThemeMode(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String modeString;
      switch (mode) {
        case ThemeMode.light:
          modeString = 'light';
          break;
        case ThemeMode.dark:
          modeString = 'dark';
          break;
        default:
          modeString = 'system';
      }
      await prefs.setString(_themeModeKey, modeString);
      debugPrint('THEME: Saved theme mode: $modeString');
    } catch (e) {
      debugPrint('THEME: Error saving theme: $e');
    }
  }

  /// Toggle between light and dark (skips system)
  void toggle() {
    if (state == ThemeMode.light) {
      setThemeMode(ThemeMode.dark);
    } else {
      setThemeMode(ThemeMode.light);
    }
  }
}

/// Provider for theme mode
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});
