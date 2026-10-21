import 'package:flutter/material.dart';

import '../view_model/secao_titulos.dart';
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
    super.key,
  });

  final String titulo;
  final SecaoTitulos secao;
  final VoidCallback onRetry;

  static const double altura = 236;

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
      return const Center(child: Text('Nada por aqui agora.'));
    }

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: secao.itens.length,
      separatorBuilder: (BuildContext context, int _) => const SizedBox(width: 12),
      itemBuilder: (BuildContext context, int i) => PosterCard(item: secao.itens[i]),
    );
  }
}
