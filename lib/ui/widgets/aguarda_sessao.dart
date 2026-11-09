import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../view_model/auth_view_model.dart';
import 'status_view.dart';

/// Shows an internal screen only while there is a session. Every route of
/// `Routes.gerar` goes through it: a tap, a pasted link, an F5.
///
/// - Right after a reload the SDK has not restored the session yet: a request
///   sent then goes out without `Authorization`, the API answers 401 and the
///   interceptor signs the person out. So the screen is only built once the
///   session is [SessionState.signedIn].
/// - Without a session (never had one, or it ended with the screen open, like
///   the 401 sign-out) it goes back to the first route, where the `AuthGate`
///   shows the login: "no login, no passing" holds for every screen.
///
/// For a tap from a signed-in screen the session is already there, so the
/// screen shows at once.
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
