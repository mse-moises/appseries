import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../data/api_models/tmdb_item.dart';
import '../../utils/tmdb_image.dart';

/// One poster of a carousel: image, title in two lines and the year.
///
/// The image goes through [CachedNetworkImage] so scrolling down and back does
/// not download the same poster again. A title without a poster (or an image
/// that fails) shows a grey box — it never throws.
class PosterCard extends StatelessWidget {
  const PosterCard({required this.item, this.largura = 110, super.key});

  final TmdbItem item;
  final double largura;

  @override
  Widget build(BuildContext context) {
    final String? url = urlDoPoster(item.posterPath);

    return SizedBox(
      width: largura,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
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
          const SizedBox(height: 6),
          Text(
            item.titulo,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (item.ano != null)
            Text(
              item.ano!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
        ],
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
