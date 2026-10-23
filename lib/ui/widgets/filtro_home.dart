import 'package:flutter/material.dart';

import '../../utils/routes_config.dart';
import '../view_model/filtro_tipo.dart';
import 'filtro_tipo_chips.dart';

/// Top of the home: the search box and the Todos / Séries / Filmes chips.
///
/// The box does not filter the carousels: it opens the search screen, which
/// asks the server and so reaches the whole catalogue, not only the couple
/// dozen titles the home loaded.
class FiltroHome extends StatelessWidget {
  const FiltroHome({required this.filtro, required this.onFiltro, super.key});

  final FiltroTipo filtro;
  final ValueChanged<FiltroTipo> onFiltro;

  /// Wider than this the box stops growing: a search field across a 1900 px
  /// window reads as a second app bar.
  static const double larguraMaxima = 520;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cores = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: larguraMaxima),
            // A button dressed as a field, not a read-only `TextField`: it takes
            // focus by Tab and opens with Enter or Space, which a read-only
            // field only does on tap.
            child: Material(
              color: cores.surfaceContainerHighest,
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const Key('busca-home'),
                onTap: () => Navigator.pushNamed(context, Routes.busca),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.search, color: cores.onSurfaceVariant),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Buscar série ou filme',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(color: cores.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FiltroTipoChips(filtro: filtro, onFiltro: onFiltro),
        ],
      ),
    );
  }
}
