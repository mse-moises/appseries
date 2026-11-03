import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../view_model/auth_view_model.dart';
import 'status_view.dart';

/// Holds a screen opened straight from the URL (F5, a pasted link) until the
/// session is known.
///
/// Right after a reload the SDK has not restored the session yet: a request
/// sent then goes out without `Authorization`, the API answers 401 and the
/// interceptor signs the person out. So the screen is only built once the
/// session is [SessionState.signedIn]. Without a session it goes back to the
/// first route, where the `AuthGate` shows the login: "no login, no passing"
/// holds for a link too.
///
/// Screens opened by a tap inside the app do not need it: they are reached
/// from a signed-in screen.
class AguardaSessao extends StatelessWidget {
  const AguardaSessao({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    switch (context.watch<AuthViewModel>().state) {
      case SessionState.signedIn:
        return child;
      case SessionState.signedOut:
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst);
        });
        return const Scaffold(body: LoadingView());
      case SessionState.unknown:
        return const Scaffold(body: LoadingView(mensagem: 'Só um instante...'));
    }
  }
}
