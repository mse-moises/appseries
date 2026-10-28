import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../view_model/tipo_filtro.dart';

/// The Todos / Séries / Filmes pills.
///
/// Compact on purpose: a full-width segmented bar across a wide window read as
/// a second app bar, not as a filter.
class TipoFiltroChips extends StatelessWidget {
  const TipoFiltroChips({required this.filtro, required this.onFiltro, super.key});

  final TipoFiltro filtro;
  final ValueChanged<TipoFiltro> onFiltro;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        children: <Widget>[
          for (final (TipoFiltro valor, String rotulo) in const <(TipoFiltro, String)>[
            (TipoFiltro.todos, 'Todos'),
            (TipoFiltro.series, 'Séries'),
            (TipoFiltro.filmes, 'Filmes'),
          ])
            _Chip(
              rotulo: rotulo,
              selecionado: filtro == valor,
              onTap: () => onFiltro(valor),
            ),
        ],
      );
}

/// A compact pill: solid red when chosen, a thin outline otherwise.
class _Chip extends StatelessWidget {
  const _Chip({required this.rotulo, required this.selecionado, required this.onTap});

  final String rotulo;
  final bool selecionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cores = Theme.of(context).colorScheme;

    return ChoiceChip(
      label: Text(rotulo),
      selected: selecionado,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      shape: const StadiumBorder(),
      selectedColor: AppTheme.destaque,
      backgroundColor: Colors.transparent,
      side: BorderSide(color: selecionado ? AppTheme.destaque : cores.outlineVariant),
      labelStyle: TextStyle(
        color: selecionado ? Colors.white : cores.onSurfaceVariant,
        fontWeight: selecionado ? FontWeight.w600 : FontWeight.w500,
      ),
    );
  }
}
