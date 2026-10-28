import 'package:flutter/material.dart';

/// App theme. Material 3 throughout; light and dark follow the system.
class AppTheme {
  const AppTheme._();

  /// Provisional seed colour — the real palette is a prototype decision.
  static const Color seed = Color(0xFF6C5CE7);

  /// Accent for what must stand out next to the posters: the chosen filter and
  /// the search cursor.
  static const Color destaque = Color(0xFFE50914);

  static ThemeData light() => _base(Brightness.light);

  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: brightness),
      );
}

/// The theme pair and the mode every `MaterialApp` in this app shares — the real
/// one and the start-up failure screen. One source for the three, so a theme
/// change cannot silently miss the other tree.
({ThemeData light, ThemeData dark, ThemeMode mode}) temasDoApp() {
  final ThemeData light = AppTheme.light();
  final ThemeData dark = AppTheme.dark();
  return (light: light, dark: dark, mode: ThemeMode.system);
}
