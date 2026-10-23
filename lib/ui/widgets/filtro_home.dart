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
            child: TextField(
              key: const Key('busca-home'),
              readOnly: true,
              onTap: () => Navigator.pushNamed(context, Routes.busca),
              decoration: InputDecoration(
                hintText: 'Buscar série ou filme',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                filled: true,
                fillColor: cores.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
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
