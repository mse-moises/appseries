import 'package:flutter/material.dart';

import 'ui/theme/app_theme.dart';
import 'utils/routes_config.dart';

/// Root widget: theme, named routes and the first screen.
///
/// The AuthGate (which decides between login and home from the Firebase auth
/// state) lands in AP-24, when the Firebase project config exists.
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'AppSeries',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        initialRoute: Routes.login,
        routes: Routes.mapa,
        debugShowCheckedModeBanner: false,
      );
}
