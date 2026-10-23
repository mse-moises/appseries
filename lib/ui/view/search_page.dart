import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/api_models/tmdb_item.dart';
import '../../utils/app_error.dart';
import '../../utils/routes_config.dart';
import '../../utils/tmdb_image.dart';
import '../navegacao/titulo_ref.dart';
import '../theme/app_theme.dart';
import '../view_model/search_view_model.dart';
import '../widgets/tipo_filtro_chips.dart';
import '../widgets/acervo_action_button.dart';
import '../widgets/status_view.dart';

/// Search by name (AP-44 / AP-45), over the whole catalogue through `/busca`.
///
/// Every state has its own screen: hint, loading, results, nothing found and
/// error. None of them is a blank page.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _texto = TextEditingController();

  // Kept from `initState`: `dispose` cannot look it up in the tree.
  late final SearchViewModel _busca;

  @override
  void initState() {
    super.initState();
    _busca = context.read<SearchViewModel>();
    // Lives at the root: without this the screen opens on the last search.
    _busca.reset();
  }

  @override
  void dispose() {
    _busca.cancelar();
    _texto.dispose();
    super.dispose();
  }

  void _limpar(SearchViewModel busca) {
    _texto.clear();
    busca.setConsulta('');
  }

  @override
  Widget build(BuildContext context) {
    final SearchViewModel busca = context.watch<SearchViewModel>();

    // Cancels on the way out, not only in `dispose`: the page is disposed at
    // the end of the back animation, and the pending search would leave during
    // it for a screen nobody is looking at.
    return PopScope(
      onPopInvokedWithResult: (bool saiu, Object? _) {
        if (saiu) _busca.cancelar();
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: TextField(
            key: const Key('campo-busca'),
            controller: _texto,
            autofocus: true,
            onChanged: busca.setConsulta,
            onSubmitted: (_) => busca.buscarAgora(),
            textInputAction: TextInputAction.search,
            cursorColor: AppTheme.destaque,
            decoration: InputDecoration(
              hintText: 'Buscar série ou filme',
              border: InputBorder.none,
              suffixIcon: busca.consulta.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () => _limpar(busca),
                      icon: const Icon(Icons.close),
                      tooltip: 'Limpar busca',
                    ),
            ),
          ),
        ),
        body: Column(
          children: <Widget>[
            // One line that scrolls sideways: wrapping, the chips grew taller
            // with a large font and squeezed the results out.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TipoFiltroChips(filtro: busca.filtro, onFiltro: busca.setFiltro),
            ),
            Expanded(child: _corpo(busca)),
          ],
        ),
      ),
    );
  }

  Widget _corpo(SearchViewModel busca) => switch (busca.estado) {
    EstadoBusca.ocioso => const _Aviso(
      icone: Icons.search,
      mensagem: 'Digite pelo menos $kBuscaMin letras para buscar.',
    ),
    EstadoBusca.carregando => const LoadingView(),
    EstadoBusca.erro => ErrorView(
      mensagem: busca.erro!,
      onRetry: busca.podeTentarDeNovo ? busca.tentarDeNovo : null,
    ),
    EstadoBusca.vazio => _Aviso(icone: Icons.search_off, mensagem: _semResultado(busca)),
    // The TMDB credit goes with the TMDB data: last item of the list, so
    // it scrolls instead of taking fixed height over a keyboard.
    EstadoBusca.resultados => ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: busca.resultados.length + 1,
      separatorBuilder: (BuildContext context, int _) => const SizedBox(height: 12),
      itemBuilder: (BuildContext context, int i) => i == busca.resultados.length
          ? const _Atribuicao()
          : _ResultadoTile(item: busca.resultados[i]),
    ),
  };

  /// Says what was searched, and the filter when it is the one hiding results.
  ///
  /// With a filter on, the sentence talks about the results shown, not the
  /// catalogue: the server answers only the top titles, mixed, so a series may
  /// exist and just not be among them.
  static String _semResultado(SearchViewModel busca) {
    final String termo = '"${busca.consulta.trim()}"';
    return switch (busca.filtro) {
      TipoFiltro.todos => 'Nada encontrado para $termo. Confira o nome ou tente em inglês.',
      TipoFiltro.series => 'Nenhuma série entre os resultados para $termo.',
      TipoFiltro.filmes => 'Nenhum filme entre os resultados para $termo.',
    };
  }
}

/// One result: poster, title, year and kind — what the card asks for — and the
/// same shelf button as the home and the detail (AP-50).
class _ResultadoTile extends StatelessWidget {
  const _ResultadoTile({required this.item});

  final TmdbItem item;

  static const double _larguraPoster = 64;

  /// Logical width (font scale included) below which the result row uses the
  /// compact shelf button.
  static const double _larguraBotaoCompleto = 400;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cores = Theme.of(context).colorScheme;
    final TextTheme texto = Theme.of(context).textTheme;
    final String? url = urlDoPoster(item.posterPath);
    final String? tipo = switch (item.tipo) {
      TipoMidia.tv => 'Série',
      TipoMidia.movie => 'Filme',
      TipoMidia.desconhecido => null,
    };

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => Navigator.pushNamed(
        context,
        Routes.detalhe,
        arguments: TituloRef(tipo: item.tipo, id: item.id),
      ),
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
                  item.titulo.isEmpty ? 'Sem título' : item.titulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: texto.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  <String>[
                    // O backend manda `""` (não null) quando o título não tem data.
                    if (item.ano != null && item.ano!.isNotEmpty) item.ano!,
                    if (tipo != null) tipo,
                  ].join(' · '),
                  style: texto.bodySmall?.copyWith(color: cores.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Narrow screen or large font: the icon-only button, so the title
          // keeps its room instead of being squeezed out.
          AcervoAcao(
            tipo: item.tipo,
            tmdbId: item.id,
            compacto: MediaQuery.sizeOf(context).width / MediaQuery.textScalerOf(context).scale(1) <
                _larguraBotaoCompleto,
          ),
        ],
      ),
    );
  }
}

/// Centered icon and sentence: the hint and the "nothing found" screens.
///
/// Same layout as `LoadingView`/`ErrorView`: centered when there is room, and
/// scrollable when there is not (keyboard open, large font).
class _Aviso extends StatelessWidget {
  const _Aviso({required this.icone, required this.mensagem});

  final IconData icone;
  final String mensagem;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icone, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(height: 12),
                Text(mensagem, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Results come from the TMDB, so the credit goes on this screen too.
class _Atribuicao extends StatelessWidget {
  const _Atribuicao();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text(
      'This product uses the TMDB API but is not endorsed or certified by TMDB.',
      textAlign: TextAlign.center,
      style: Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}
