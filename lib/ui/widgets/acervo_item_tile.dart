import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../data/api_models/acervo_item.dart';
import '../../utils/routes_config.dart';
import '../../utils/tmdb_image.dart';
import '../navegacao/titulo_ref.dart';

/// One line of the shelf: poster, title, year and type (AP-59).
///
/// A widget of its own because the shelf tabs, the state change on the list
/// (AP-63) and the history (AP-73) show the same line. [abaixo] is what each
/// screen adds under the title; [acao] goes at the end of the line.
///
/// The line opens the detail when it knows the pair `(tipo, id)`. An old line
/// without `tipo` does not: the id alone could be the movie or the series.
class AcervoItemTile extends StatelessWidget {
  const AcervoItemTile({required this.item, this.abaixo, this.acao, super.key});

  final AcervoItem item;
  final Widget? abaixo;
  final Widget? acao;

  static const double _larguraPoster = 56;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cores = Theme.of(context).colorScheme;
    final TextTheme texto = Theme.of(context).textTheme;
    final String? url = urlDoPoster(item.posterPath);
    final TipoMidia? tipo = item.tipo;
    final bool abre = tipo == TipoMidia.movie || tipo == TipoMidia.tv;
    final String? titulo = item.titulo;
    final String linha = <String>[
      if (item.ano != null && item.ano!.isNotEmpty) item.ano!,
      ?switch (tipo) {
        TipoMidia.tv => 'Série',
        TipoMidia.movie => 'Filme',
        TipoMidia.desconhecido || null => null,
      },
    ].join(' · ');

    return InkWell(
      onTap: abre
          ? () => Routes.abrirDetalhe(context, TituloRef(tipo: tipo!, id: item.tmdbId))
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: _larguraPoster,
                height: _larguraPoster * 1.5,
                color: cores.surfaceContainerHighest,
                child: url == null
                    ? Icon(Icons.movie_outlined, color: cores.onSurfaceVariant)
                    : CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        errorWidget: (BuildContext context, String _, Object __) =>
                            Icon(Icons.movie_outlined, color: cores.onSurfaceVariant),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    titulo == null || titulo.isEmpty ? 'Sem título' : titulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: texto.titleSmall,
                  ),
                  if (linha.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(linha, style: texto.bodySmall?.copyWith(color: cores.onSurfaceVariant)),
                  ],
                  if (abaixo != null) ...<Widget>[
                    const SizedBox(height: 4),
                    abaixo!,
                  ],
                ],
              ),
            ),
            if (acao != null) ...<Widget>[
              const SizedBox(width: 8),
              acao!,
            ],
          ],
        ),
      ),
    );
  }
}
