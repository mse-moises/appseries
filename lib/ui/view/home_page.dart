import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../view_model/acervo_view_model.dart';
import '../view_model/auth_view_model.dart';
import '../view_model/home_view_model.dart';
import '../widgets/status_view.dart';

/// Home shell.
///
/// Proves the whole chain works against the real backend (View → ViewModel →
/// Repository → RestClient → Result). The carousels land in AP-31.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    // The ViewModel is created once, at the root, so its `create` ran a single
    // time: after a sign-out and a new sign-in the screen showed the previous
    // account's answer, error screen included, without asking the backend again.
    // Loading from here — and this widget is mounted anew on every login — is
    // what makes the second account start clean.
    //
    // The shelf is cleared synchronously (no notify: this is inside the build
    // phase) so its count never appears for a frame before the request.
    context.read<AcervoViewModel>().reset();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<HomeViewModel>().load();
      // AP-28: the shelf comes from the server too, and it loads on its own so a
      // failure there does not take the whole home down.
      context.read<AcervoViewModel>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final HomeViewModel vm = context.watch<HomeViewModel>();
    final AuthViewModel auth = context.watch<AuthViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('AppSeries'),
        actions: <Widget>[
          if (auth.isSigningOut)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Center(
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              onPressed: auth.signOut,
              icon: const Icon(Icons.logout),
              tooltip: 'Sair',
            ),
        ],
      ),
      body: Column(
        children: <Widget>[
          // A sign-out that failed has to say so: otherwise the icon looks dead
          // and she stays signed in without knowing why.
          if (auth.signOutError != null)
            MaterialBanner(
              content: Text(auth.signOutError!),
              actions: <Widget>[
                TextButton(
                  onPressed: auth.clearSignOutError,
                  child: const Text('Fechar'),
                ),
              ],
            ),
          Expanded(child: _corpo(context, vm, auth)),
          _AcervoResumo(acervo: context.watch<AcervoViewModel>()),
        ],
      ),
    );
  }

  Widget _corpo(BuildContext context, HomeViewModel vm, AuthViewModel auth) {
    if (vm.isLoading) {
      return const LoadingView(mensagem: 'Falando com o backend...');
    }

    if (vm.error != null) {
      return ErrorView(mensagem: vm.error!, onRetry: vm.load);
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) =>
          SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Icon(Icons.check_circle_outline, size: 48),
                  const SizedBox(height: 12),
                  Text('Backend respondeu: ${vm.status?.status ?? '-'}'),
                  const SizedBox(height: 8),
                  if (auth.user?.email != null) Text(auth.user!.email!),
                  const SizedBox(height: 24),
                  FilledButton.tonal(onPressed: vm.load, child: const Text('Tentar de novo')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One line about the shelf.
///
/// It is the visible proof that AP-28 works (the number comes from the server)
/// and the place that says the shelf could not be read, without hiding the
/// health answer above — a shelf that fails is a block of the screen, not the
/// screen.
class _AcervoResumo extends StatelessWidget {
  const _AcervoResumo({required this.acervo});

  final AcervoViewModel acervo;

  @override
  Widget build(BuildContext context) {
    final Widget conteudo;
    if (acervo.isLoading) {
      conteudo = const Text('Carregando seu acervo...');
    } else if (acervo.error != null) {
      conteudo = Row(
        children: <Widget>[
          Expanded(child: Text(acervo.error!)),
          TextButton(onPressed: acervo.load, child: const Text('Tentar de novo')),
        ],
      );
    } else {
      final int total = acervo.total;
      conteudo = Text('Seu acervo: ${total == 1 ? '1 título' : '$total títulos'}');
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: <Widget>[
            const Icon(Icons.video_library_outlined, size: 18),
            const SizedBox(width: 8),
            Expanded(child: conteudo),
          ],
        ),
      ),
    );
  }
}
