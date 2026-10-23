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
import '../widgets/filtro_tipo_chips.dart';
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

  @override
  void initState() {
    super.initState();
    // Lives at the root: without this the screen opens on the last search.
    context.read<SearchViewModel>().reset();
  }

  @override
  void dispose() {
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

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          key: const Key('campo-busca'),
          controller: _texto,
          autofocus: true,
          onChanged: busca.setConsulta,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FiltroTipoChips(filtro: busca.filtro, onFiltro: busca.setFiltro),
            ),
          ),
          Expanded(child: _corpo(busca)),
          const _Atribuicao(),
        ],
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
        EstadoBusca.vazio => _Aviso(
            icone: Icons.search_off,
            mensagem: _semResultado(busca),
          ),
        EstadoBusca.resultados => ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            itemCount: busca.resultados.length,
            separatorBuilder: (BuildContext context, int _) => const SizedBox(height: 12),
            itemBuilder: (BuildContext context, int i) => _ResultadoTile(item: busca.resultados[i]),
          ),
      };

  /// Says what was searched, and the filter when it is the one hiding results.
  static String _semResultado(SearchViewModel busca) {
    final String termo = '"${busca.consulta.trim()}"';
    return switch (busca.filtro) {
      FiltroTipo.todos => 'Nada encontrado para $termo. Tente outro nome.',
      FiltroTipo.series => 'Nenhuma série encontrada para $termo.',
      FiltroTipo.filmes => 'Nenhum filme encontrado para $termo.',
    };
  }
}

/// One result: poster, title, year and kind — what the card asks for.
class _ResultadoTile extends StatelessWidget {
  const _ResultadoTile({required this.item});

  final TmdbItem item;

  static const double _larguraPoster = 64;

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
        ],
      ),
    );
  }
}

/// Centered icon and sentence: the hint and the "nothing found" screens.
class _Aviso extends StatelessWidget {
  const _Aviso({required this.icone, required this.mensagem});

  final IconData icone;
  final String mensagem;

  @override
  Widget build(BuildContext context) => Center(
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
      );
}

/// Results come from the TMDB, so the credit goes on this screen too.
class _Atribuicao extends StatelessWidget {
  const _Atribuicao();

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Text(
            'This product uses the TMDB API but is not endorsed or certified by TMDB.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      );
}
