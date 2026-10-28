import 'package:flutter/material.dart';

import '../../data/api_models/tmdb_item.dart';
import '../../utils/routes_config.dart';
import '../navegacao/titulo_ref.dart';
import '../view_model/secao_titulos.dart';
import 'acervo_action_button.dart';
import 'poster_card.dart';

/// One home section: the title, the horizontal row of posters and its own
/// loading / error / empty state.
///
/// The retry is per section on purpose: "Populares" failing does not reload
/// "Em alta".
class CarouselSection extends StatelessWidget {
  const CarouselSection({
    required this.titulo,
    required this.secao,
    required this.onRetry,
    this.mensagemVazia = 'Nada por aqui agora.',
    super.key,
  });

  final String titulo;
  final SecaoTitulos secao;
  final VoidCallback onRetry;

  /// What an empty section says. The home passes the filter's sentence: with a
  /// filter on, "nothing here" would hide that the filter is the cause.
  final String mensagemVazia;

  /// Includes the room above the posters that the hover zoom grows into: without
  /// it the list clips the top of the poster under the pointer.
  static const double altura = 244;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(titulo, style: Theme.of(context).textTheme.titleMedium),
        ),
        SizedBox(height: altura, child: _conteudo(context)),
      ],
    );
  }

  Widget _conteudo(BuildContext context) {
    if (secao.carregando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (secao.erro != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(secao.erro!, textAlign: TextAlign.center),
              TextButton(onPressed: onRetry, child: const Text('Tentar de novo')),
            ],
          ),
        ),
      );
    }

    if (secao.vazio) {
      return Center(child: Text(mensagemVazia, textAlign: TextAlign.center));
    }

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      itemCount: secao.itens.length,
      separatorBuilder: (BuildContext context, int _) => const SizedBox(width: 12),
      itemBuilder: (BuildContext context, int i) {
        final TmdbItem item = secao.itens[i];
        return PosterCard(
          item: item,
          // The pair, not the id alone: movie 550 and series 550 are different titles.
          onTap: () => Navigator.pushNamed(
            context,
            Routes.detalhe,
            arguments: TituloRef(tipo: item.tipo, id: item.id),
          ),
          acao: AcervoAcao(tipo: item.tipo, tmdbId: item.id, compacto: true),
        );
      },
    );
  }
}
