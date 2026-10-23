import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../data/api_models/tmdb_item.dart';
import '../../utils/tmdb_image.dart';

/// One poster of a carousel: image, title in two lines and the year.
///
/// The image goes through [CachedNetworkImage] so scrolling down and back does
/// not download the same poster again. A title without a poster (or an image
/// that fails) shows a grey box — it never throws.
///
/// With a mouse, the poster under the pointer grows a little so she sees which
/// one she is about to pick. Hover is screen state, so it lives here and not in
/// a ViewModel; on touch there is no hover and the card stays still.
class PosterCard extends StatefulWidget {
  const PosterCard({required this.item, this.largura = 110, super.key});

  final TmdbItem item;
  final double largura;

  /// How much the poster grows under the pointer. Small on purpose: the
  /// carousel gap (12 px) has to hold the growth without covering the neighbour.
  static const double escalaHover = 1.06;

  static const Duration duracaoHover = Duration(milliseconds: 150);

  @override
  State<PosterCard> createState() => _PosterCardState();
}

class _PosterCardState extends State<PosterCard> {
  bool _emFoco = false;

  void _hover(bool emFoco) {
    if (emFoco != _emFoco) setState(() => _emFoco = emFoco);
  }

  @override
  Widget build(BuildContext context) {
    final TmdbItem item = widget.item;
    final String? url = urlDoPoster(item.posterPath);
    // Whoever asked the system for less motion gets the zoom without the animation.
    final Duration duracao =
        MediaQuery.of(context).disableAnimations ? Duration.zero : PosterCard.duracaoHover;

    return MouseRegion(
      onEnter: (_) => _hover(true),
      onExit: (_) => _hover(false),
      child: SizedBox(
        width: widget.largura,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: AnimatedScale(
                key: const Key('poster-zoom'),
                scale: _emFoco ? PosterCard.escalaHover : 1,
                duration: duracao,
                curve: Curves.easeOut,
                child: AnimatedContainer(
                  duration: duracao,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: _emFoco
                        ? const <BoxShadow>[
                            BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 4)),
                          ]
                        : const <BoxShadow>[],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: double.infinity,
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: url == null
                          ? const _SemPoster()
                          : CachedNetworkImage(
                              imageUrl: url,
                              fit: BoxFit.cover,
                              placeholder: (BuildContext context, String _) => const Center(
                                child: SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                              errorWidget: (BuildContext context, String _, Object __) =>
                                  const _SemPoster(),
                            ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.titulo.isEmpty ? 'Sem título' : item.titulo,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            // O backend manda `""` (não null) quando o título não tem data.
            if (item.ano != null && item.ano!.isNotEmpty)
              Text(
                item.ano!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SemPoster extends StatelessWidget {
  const _SemPoster();

  @override
  Widget build(BuildContext context) => Icon(
        Icons.movie_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );
}
