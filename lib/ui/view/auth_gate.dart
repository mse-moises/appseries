import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../view_model/auth_view_model.dart';
import '../widgets/status_view.dart';
import 'home_page.dart';
import 'login_page.dart';

/// Decides which screen the app shows, from the session state alone.
///
/// It is the root of the app (see `app.dart`) and the only place that knows
/// the login/home pair: no screen navigates between them, so "no login, no
/// passing" is a property of the design instead of a rule to remember.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthViewModel auth = context.watch<AuthViewModel>();

    return switch (auth.state) {
      SessionState.unknown =>
        const Scaffold(body: LoadingView(mensagem: 'Só um instante...')),
      SessionState.signedIn => const HomePage(),
      SessionState.signedOut => const LoginPage(),
    };
  }
}
