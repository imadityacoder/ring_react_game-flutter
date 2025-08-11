import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Async provider to load SharedPreferences
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return await SharedPreferences.getInstance();
});

/// State model for preferences
class PrefsState {
  final int highScore;
  final ThemeMode themeMode;
  final bool musicOn;

  const PrefsState({
    required this.highScore,
    required this.themeMode,
    required this.musicOn,
  });

  factory PrefsState.initial() => const PrefsState(
        highScore: 0,
        themeMode: ThemeMode.system,
        musicOn: true,
      );

  PrefsState copyWith({
    int? highScore,
    ThemeMode? themeMode,
    bool? musicOn,
  }) {
    return PrefsState(
      highScore: highScore ?? this.highScore,
      themeMode: themeMode ?? this.themeMode,
      musicOn: musicOn ?? this.musicOn,
    );
  }
}

/// Notifier for managing preferences
class PrefsNotifier extends StateNotifier<PrefsState> {
  final SharedPreferences _prefs;

  PrefsNotifier(this._prefs) : super(PrefsState.initial()) {
    _loadPrefs();
  }

  void _loadPrefs() {
    final highScore = _prefs.getInt('highScore') ?? 0;
    final themeIndex = _prefs.getInt('themeMode') ?? ThemeMode.system.index;
    final themeMode = ThemeMode.values[themeIndex];
    final musicOn = _prefs.getBool('musicOn') ?? true;

    state = state.copyWith(
      highScore: highScore,
      themeMode: themeMode,
      musicOn: musicOn,
    );
  }

  // Save High Score
  void setHighScore(int value) {
    state = state.copyWith(highScore: value);
    _prefs.setInt('highScore', value);
  }

  // Save Theme Mode
  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    _prefs.setInt('themeMode', mode.index);
  }

  // Save Music Toggle
  void setMusicOn(bool value) {
    state = state.copyWith(musicOn: value);
    _prefs.setBool('musicOn', value);
  }

  // Toggle theme between Light and Dark (ignore system)
  void toggleTheme() {
    final current = state.themeMode;
    final next = current == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    setThemeMode(next);
  }
}

/// Provider for PrefsNotifier
final prefsNotifierProvider =
    StateNotifierProvider<PrefsNotifier, PrefsState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).maybeWhen(
        data: (prefs) => prefs,
        orElse: () => throw Exception('Prefs not loaded yet'),
      );
  return PrefsNotifier(prefs);
});
