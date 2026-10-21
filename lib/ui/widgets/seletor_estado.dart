import 'package:flutter/material.dart';

import '../../data/api_models/acervo_item.dart';

export '../../data/api_models/acervo_item.dart';

/// Product name of each shelf state. Lives next to the widget because it is the
/// only place that shows them; a second copy elsewhere would drift.
String rotuloEstado(EstadoAcervo estado) => switch (estado) {
      EstadoAcervo.planToWatch => 'Quero ver',
      EstadoAcervo.watching => 'Assistindo',
      EstadoAcervo.watched => 'Assistido',
      EstadoAcervo.dropped => 'Abandonei',
      EstadoAcervo.desconhecido => 'Sem estado',
    };

/// The four states, as a menu.
///
/// It is a widget — not a piece of each screen — because the same choice appears
/// in three places (home, search result and detail). The screen only tells which
/// state is current and what to do when the person picks another; saving is the
/// ViewModel's job, never the widget's.
class SeletorEstado extends StatelessWidget {
  const SeletorEstado({super.key, this.atual, required this.onEscolher});

  /// `null` when the title is not on the shelf yet.
  final EstadoAcervo? atual;

  final ValueChanged<EstadoAcervo> onEscolher;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final String rotulo = atual == null ? 'Marcar' : rotuloEstado(atual!);

    return PopupMenuButton<EstadoAcervo>(
      tooltip: 'Marcar no meu acervo',
      onSelected: onEscolher,
      itemBuilder: (BuildContext context) => <PopupMenuEntry<EstadoAcervo>>[
        for (final EstadoAcervo estado in const <EstadoAcervo>[
          EstadoAcervo.planToWatch,
          EstadoAcervo.watching,
          EstadoAcervo.watched,
          EstadoAcervo.dropped,
        ])
          PopupMenuItem<EstadoAcervo>(
            value: estado,
            child: Row(
              children: <Widget>[
                Icon(
                  estado == atual ? Icons.check : null,
                  size: 18,
                  color: tema.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(rotuloEstado(estado)),
              ],
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.bookmark_add_outlined, size: 18),
            const SizedBox(width: 6),
            Text(rotulo, style: tema.textTheme.labelLarge),
          ],
        ),
      ),
    );
  }
}
