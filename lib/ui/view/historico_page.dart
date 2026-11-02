import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/api_models/acervo_item.dart';
import '../../utils/data_curta.dart';
import '../view_model/acervo_view_model.dart';
import '../widgets/acervo_item_tile.dart';
import '../widgets/status_view.dart';

/// What she watched, the most recent first, with the day (AP-73).
///
/// Reads the [AcervoViewModel] the home already loaded, like the shelf tabs:
/// there is no history endpoint, and the order and the date come from the
/// shelf lines themselves ([AcervoViewModel.historico]).
class HistoricoPage extends StatelessWidget {
  const HistoricoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AcervoViewModel acervo = context.watch<AcervoViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Histórico')),
      body: switch (acervo) {
        AcervoViewModel(isLoading: true) => const LoadingView(
          mensagem: 'Carregando seu histórico...',
        ),
        AcervoViewModel(:final String error) => ErrorView(mensagem: error, onRetry: acervo.load),
        _ => _Lista(itens: acervo.historico),
      },
    );
  }
}

class _Lista extends StatelessWidget {
  const _Lista({required this.itens});

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
            'Nada assistido ainda. Marque um título como "Assistido" e ele aparece aqui.',
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
        final DateTime? quando = item.atualizadoEm;
        return AcervoItemTile(
          key: ValueKey<String>('historico-${item.tipo?.name}-${item.tmdbId}'),
          item: item,
          abaixo: Text(
            quando == null ? 'Assistido, sem data' : 'Assistido em ${dataCurta(quando)}',
            style: texto.bodySmall?.copyWith(color: discreto),
          ),
        );
      },
    );
  }
}
