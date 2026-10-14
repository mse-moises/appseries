import 'package:flutter/material.dart';

/// App theme. Material 3 throughout; light and dark follow the system.
class AppTheme {
  const AppTheme._();

  /// Provisional seed colour — the real palette is a prototype decision.
  static const Color seed = Color(0xFF6C5CE7);

  static ThemeData light() => _base(Brightness.light);

  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: brightness),
      );
}
