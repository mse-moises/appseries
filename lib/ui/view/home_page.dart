import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../view_model/acervo_view_model.dart';
import '../view_model/auth_view_model.dart';
import '../view_model/home_view_model.dart';
import '../widgets/carousel_section.dart';

/// Home: the entry point of the product.
///
/// Two carousels with real titles from our backend (never from the TMDB
/// directly: the key stays on the server) and the shelf count. Each section owns
/// its loading/error, so one failing does not take the screen down.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    // Both ViewModels are created once at the root, so their `create` ran a
    // single time: after a sign-out and a new sign-in they still hold the
    // previous account's data. Clearing here is synchronous (no notify: this is
    // the build phase) and is what keeps the old titles off the first frame;
    // the load below is what notifies.
    context.read<HomeViewModel>().reset();
    context.read<AcervoViewModel>().reset();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // They load on their own: a failure in one does not take the other down.
      context.read<HomeViewModel>().load();
      context.read<AcervoViewModel>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final HomeViewModel home = context.watch<HomeViewModel>();
    final AuthViewModel auth = context.watch<AuthViewModel>();
    final AcervoViewModel acervo = context.watch<AcervoViewModel>();

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
          Expanded(child: _corpo(home, acervo)),
        ],
      ),
    );
  }

  Widget _corpo(HomeViewModel home, AcervoViewModel acervo) => ListView(
        children: <Widget>[
          const SizedBox(height: 8),
          CarouselSection(
            titulo: 'Em alta',
            secao: home.emAlta,
            onRetry: home.recarregarEmAlta,
          ),
          const SizedBox(height: 20),
          CarouselSection(
            titulo: 'Populares',
            secao: home.populares,
            onRetry: home.recarregarPopulares,
          ),
          const SizedBox(height: 12),
          _AcervoResumo(acervo: acervo),
          const SizedBox(height: 8),
          const _AtribuicaoTmdb(),
          const SizedBox(height: 16),
        ],
      );
}

/// One line about the shelf.
///
/// The visible proof that AP-28 works (the number comes from the server) and the
/// place that says the shelf could not be read, without hiding the carousels: a
/// shelf that fails is a block of the screen, not the screen.
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
          TextButton(
            key: const Key('acervo-retry'),
            onPressed: acervo.load,
            child: const Text('Tentar de novo'),
          ),
        ],
      );
    } else {
      final int total = acervo.total;
      conteudo = Text('Seu acervo: ${total == 1 ? '1 título' : '$total títulos'}');
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: <Widget>[
          const Icon(Icons.video_library_outlined, size: 18),
          const SizedBox(width: 8),
          Expanded(child: conteudo),
        ],
      ),
    );
  }
}

/// TMDB attribution: required by their terms, and a criterion of the card.
class _AtribuicaoTmdb extends StatelessWidget {
  const _AtribuicaoTmdb();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'This product uses the TMDB API but is not endorsed or certified by TMDB.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
}
