import 'package:flutter/material.dart';

import 'ui/theme/app_theme.dart';
import 'utils/routes_config.dart';

/// Root widget: theme, named routes and the `AuthGate` deciding the screen.
///
/// Every route goes through [Routes.gerar] (no `routes:` map here), so a tap,
/// a pasted link and an F5 all get the same session wait and the same pair.
///
/// The gate is the first route (`/`), built by [Routes.iniciais] and
/// [Routes.gerar] instead of `home:` (Flutter refuses `home` together with
/// `onGenerateInitialRoutes`). Which screen appears (login or home) still comes
/// from the session state, never from a navigation call.
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
      onGenerateRoute: Routes.gerar,
      onGenerateInitialRoutes: Routes.iniciais,
      debugShowCheckedModeBanner: false,
    );
  }
}
