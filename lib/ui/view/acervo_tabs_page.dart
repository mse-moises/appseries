import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/api_models/acervo_item.dart';
import '../../utils/routes_config.dart';
import '../view_model/acervo_view_model.dart';
import '../widgets/acervo_item_tile.dart';
import '../widgets/status_view.dart';

/// "Meu acervo" in three tabs: quero ver, assistindo, assistido (AP-59).
///
/// Reads the [AcervoViewModel] that the home already loaded: opening the
/// screen asks the server for nothing. The grouping lives in the ViewModel;
/// this screen only draws the three lists it hands over.
class AcervoTabsPage extends StatelessWidget {
  const AcervoTabsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AcervoViewModel acervo = context.watch<AcervoViewModel>();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Meu acervo'),
          actions: <Widget>[
            // AP-73: the history is the watched titles in the order she marked them.
            IconButton(
              onPressed: () => Navigator.pushNamed(context, Routes.historico),
              icon: const Icon(Icons.history),
              tooltip: 'Histórico',
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: <Widget>[
              Tab(text: _rotulo('Quero ver', acervo.queroVer, acervo)),
              Tab(text: _rotulo('Assistindo', acervo.assistindo, acervo)),
              Tab(text: _rotulo('Assistido', acervo.assistidos, acervo)),
            ],
          ),
        ),
        body: _corpo(acervo),
      ),
    );
  }

  /// The count goes next to the name only once the shelf is loaded: "(0)"
  /// while loading would be a lie.
  static String _rotulo(String nome, List<AcervoItem> itens, AcervoViewModel acervo) =>
      acervo.isLoading || acervo.error != null ? nome : '$nome (${itens.length})';

  Widget _corpo(AcervoViewModel acervo) {
    if (acervo.isLoading) return const LoadingView(mensagem: 'Carregando seu acervo...');
    if (acervo.error != null) return ErrorView(mensagem: acervo.error!, onRetry: acervo.load);
    return TabBarView(
      children: <Widget>[
        _Aba(itens: acervo.queroVer),
        _Aba(itens: acervo.assistindo),
        _Aba(itens: acervo.assistidos),
      ],
    );
  }
}

class _Aba extends StatelessWidget {
  const _Aba({required this.itens});

  final List<AcervoItem> itens;

  @override
  Widget build(BuildContext context) {
    final TextTheme texto = Theme.of(context).textTheme;
    final Color discreto = Theme.of(context).colorScheme.onSurfaceVariant;

    if (itens.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Nada aqui ainda.',
            textAlign: TextAlign.center,
            style: texto.bodyLarge?.copyWith(color: discreto),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      // The last row is the TMDB attribution: the list shows its posters.
      itemCount: itens.length + 1,
      itemBuilder: (BuildContext context, int i) {
        if (i == itens.length) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Text(
              'This product uses the TMDB API but is not endorsed or certified by TMDB.',
              style: texto.labelSmall?.copyWith(color: discreto),
            ),
          );
        }
        final AcervoItem item = itens[i];
        return AcervoItemTile(
          key: ValueKey<String>('acervo-${item.tipo?.name}-${item.tmdbId}'),
          item: item,
          // AP-58: the dropped titles share the tab with the watched ones, so
          // each one says so.
          abaixo: item.estado == EstadoAcervo.dropped ? const _MarcaAbandonado() : null,
        );
      },
    );
  }
}

class _MarcaAbandonado extends StatelessWidget {
  const _MarcaAbandonado();

  @override
  Widget build(BuildContext context) {
    final ColorScheme cores = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.block, size: 14, color: cores.error),
        const SizedBox(width: 4),
        // Flexible: with a large font on a narrow phone the word is wider than
        // the column, and it breaks instead of overflowing.
        Flexible(
          child: Text(
            'Abandonei',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cores.error),
          ),
        ),
      ],
    );
  }
}
