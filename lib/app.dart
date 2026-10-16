import 'package:flutter/material.dart';

import 'ui/theme/app_theme.dart';
import 'ui/view/auth_gate.dart';
import 'utils/routes_config.dart';

/// Root widget: theme, named routes and the `AuthGate` deciding the screen.
///
/// The gate is the `home`, so which screen appears (login or home) comes from
/// the session state, never from a navigation call.
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final ({ThemeData light, ThemeData dark, ThemeMode mode}) temas = temasDoApp();
    return MaterialApp(
      title: 'AppSeries',
      theme: temas.light,
      darkTheme: temas.dark,
      themeMode: temas.mode,
      home: const AuthGate(),
      routes: Routes.mapa,
      debugShowCheckedModeBanner: false,
    );
  }
}
