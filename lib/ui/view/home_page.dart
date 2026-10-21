import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../view_model/acervo_view_model.dart';
import '../view_model/auth_view_model.dart';
import '../view_model/home_view_model.dart';
import '../widgets/carousel_section.dart';

/// Home: the entry point of the product.
///
/// Two carousels with real titles from our backend (never from the TMDB
/// directly: the key stays on the server). Each section owns its loading/error,
/// so one failing does not take the screen down.
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
          Expanded(
            child: ListView(
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
              ],
            ),
          ),
          // Fora do scroll: quem está logado e a atribuição do TMDB têm de
          // estar visíveis sem rolar (a atribuição é exigência de uso da API).
          _Rodape(auth: auth, acervo: acervo),
        ],
      ),
    );
  }
}

/// Fixed footer: the signed-in account, the shelf count and the TMDB credit.
class _Rodape extends StatelessWidget {
  const _Rodape({required this.auth, required this.acervo});

  final AuthViewModel auth;
  final AcervoViewModel acervo;

  @override
  Widget build(BuildContext context) {
    final TextTheme texto = Theme.of(context).textTheme;
    final Color discreto = Theme.of(context).colorScheme.onSurfaceVariant;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
        children: <Widget>[
          // Whose account is this? Without it the only way to know was the
          // login screen.
          if (auth.user?.email != null)
            Row(
              children: <Widget>[
                Icon(Icons.person_outline, size: 18, color: discreto),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    auth.user!.email!,
                    style: texto.bodySmall?.copyWith(color: discreto),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 6),
          _AcervoResumo(
            isLoading: acervo.isLoading,
            erro: acervo.error,
            total: acervo.total,
            onRetry: acervo.load,
          ),
          const SizedBox(height: 6),
            Text(
              'This product uses the TMDB API but is not endorsed or certified by TMDB.',
              textAlign: TextAlign.center,
              style: texto.labelSmall?.copyWith(color: discreto),
            ),
          ],
        ),
      ),
    );
  }
}

/// One line about the shelf: the count, or the failure with a retry.
class _AcervoResumo extends StatelessWidget {
  const _AcervoResumo({
    required this.isLoading,
    required this.erro,
    required this.total,
    required this.onRetry,
  });

  final bool isLoading;
  final String? erro;
  final int total;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final Widget conteudo;
    if (isLoading) {
      conteudo = const Text('Carregando seu acervo...');
    } else if (erro != null) {
      conteudo = Row(
        children: <Widget>[
          Expanded(child: Text(erro!)),
          TextButton(
            key: const Key('acervo-retry'),
            onPressed: onRetry,
            child: const Text('Tentar de novo'),
          ),
        ],
      );
    } else {
      conteudo = Text('Seu acervo: ${total == 1 ? '1 título' : '$total títulos'}');
    }

    return Row(
      children: <Widget>[
        const Icon(Icons.video_library_outlined, size: 18),
        const SizedBox(width: 8),
        Expanded(child: conteudo),
      ],
    );
  }
}
