import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../view_model/auth_view_model.dart';
import '../view_model/preferences_view_model.dart';
import '../widgets/status_view.dart';
import 'home_page.dart';
import 'login_page.dart';
import 'preferences_page.dart';

/// Decides which screen the app shows, from the session state alone.
///
/// It is the root of the app (see `app.dart`) and the only place that knows
/// the login/home pair: no screen navigates between them, so "no login, no
/// passing" is a property of the design instead of a rule to remember.
///
/// Signed in, the first access (AP-38) sits between the two: the genre chips
/// show once, before the home.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthViewModel auth = context.watch<AuthViewModel>();

    return switch (auth.state) {
      SessionState.unknown => const _Carregando(),
      SessionState.signedIn => _PrimeiroAcesso(
          // A new account is a new decision: the key remounts the state.
          key: ValueKey<String?>(auth.user?.id),
          uid: auth.user?.id ?? '',
        ),
      SessionState.signedOut => const LoginPage(),
    };
  }
}

class _Carregando extends StatelessWidget {
  const _Carregando();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: LoadingView(mensagem: 'Só um instante...'));
}

/// Chips on the first access, home otherwise.
///
/// It is a widget of the gate and not a route: the home is not a route either,
/// so saving or skipping swaps the screen by state, with no back to return to.
class _PrimeiroAcesso extends StatefulWidget {
  const _PrimeiroAcesso({super.key, required this.uid});

  final String uid;

  @override
  State<_PrimeiroAcesso> createState() => _PrimeiroAcessoState();
}

class _PrimeiroAcessoState extends State<_PrimeiroAcesso> {
  @override
  void initState() {
    super.initState();
    // Created once at the root: without the reset the first frame would show
    // the previous session's decision.
    context.read<PreferencesViewModel>().resetSessao();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PreferencesViewModel>().verificarPrimeiroAcesso(widget.uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AcessoInicial acesso = context.select<PreferencesViewModel, AcessoInicial>(
      (PreferencesViewModel vm) => vm.acesso,
    );

    return switch (acesso) {
      AcessoInicial.verificando => const _Carregando(),
      AcessoInicial.escolher => const PreferencesPage(primeiroAcesso: true),
      AcessoInicial.liberado => const HomePage(),
    };
  }
}
