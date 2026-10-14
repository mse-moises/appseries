import 'package:flutter/material.dart';

import '../ui/view/home_page.dart';
import '../ui/view/login_page.dart';

/// Named routes for the whole app.
class Routes {
  const Routes._();

  static const String login = '/login';
  static const String home = '/home';

  static Map<String, WidgetBuilder> get mapa => <String, WidgetBuilder>{
        login: (_) => const LoginPage(),
        home: (_) => const HomePage(),
      };
}
