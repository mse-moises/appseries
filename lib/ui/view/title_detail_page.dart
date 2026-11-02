import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/api_models/feedback_item.dart';
import '../../data/api_models/titulo_detalhe.dart';
import '../../utils/app_error.dart';
import '../../utils/tmdb_image.dart';
import '../navegacao/titulo_ref.dart';
import '../theme/app_theme.dart';
import '../view_model/acervo_view_model.dart';
import '../view_model/title_detail_view_model.dart';
import '../widgets/acervo_action_button.dart';
import '../widgets/status_view.dart';

/// The sheet of a title (AP-46 / AP-47 / AP-48): poster, title, year, rating,
/// genres, synopsis, the shelf controls and 👍/👎.
///
/// Reads the [TituloRef] from the route arguments: whoever opens it sends the
/// pair `(tipo, id)`, because the TMDB numbers movies and series separately.
class TitleDetailPage extends StatefulWidget {
  const TitleDetailPage({super.key});

  @override
  State<TitleDetailPage> createState() => _TitleDetailPageState();
}

class _TitleDetailPageState extends State<TitleDetailPage> {
  @override
  void initState() {
    super.initState();
    // Lives at the root: without this the first frame shows the last title.
    context.read<TitleDetailViewModel>().reset();

    // The route arguments are only readable once the page is in the tree.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final Object? argumentos = ModalRoute.of(context)?.settings.arguments;
      context.read<TitleDetailViewModel>().load(argumentos is TituloRef ? argumentos : null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final TitleDetailViewModel vm = context.watch<TitleDetailViewModel>();
    final TituloDetalhe? detalhe = vm.detalhe;

    return Scaffold(
      appBar: AppBar(title: Text(detalhe?.titulo ?? '')),
      body: switch ((vm.carregando, vm.erro, detalhe)) {
        (true, _, _) => const LoadingView(),
        (_, final String erro, _) => ErrorView(
            mensagem: erro,
            onRetry: vm.podeTentarDeNovo ? vm.tentarDeNovo : null,
          ),
        (_, _, final TituloDetalhe d) => _Ficha(detalhe: d),
        // Not loading, no error and no title cannot happen; if it ever does,
        // the spinner is still better than a blank page.
        _ => const LoadingView(),
      },
    );
  }
}

/// The loaded sheet. Side by side on a wide window, stacked on a phone.
class _Ficha extends StatelessWidget {
  const _Ficha({required this.detalhe});

  final TituloDetalhe detalhe;

  static const double _larguraLado = 700;
  static const double _larguraMaxima = 1000;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool lado = constraints.maxWidth >= _larguraLado;
          final Widget poster = _Poster(posterPath: detalhe.posterPath, largura: lado ? 280 : 200);
          final Widget info = _Informacoes(detalhe: detalhe);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _larguraMaxima),
                child: lado
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[poster, const SizedBox(width: 24), Expanded(child: info)],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[Center(child: poster), const SizedBox(height: 16), info],
                      ),
              ),
            ),
          );
        },
      );
}

class _Poster extends StatelessWidget {
  const _Poster({required this.posterPath, required this.largura});

  final String? posterPath;
  final double largura;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cores = Theme.of(context).colorScheme;
    // w500: the sheet shows the poster large, and w342 would look soft.
    final String? url = urlDoPoster(posterPath, tamanho: 'w500');
    final Widget semPoster = Icon(Icons.movie_outlined, size: 48, color: cores.onSurfaceVariant);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: largura,
        height: largura * 1.5,
        color: cores.surfaceContainerHighest,
        child: url == null
            ? semPoster
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: (BuildContext context, String _, Object __) => semPoster,
              ),
      ),
    );
  }
}

class _Informacoes extends StatelessWidget {
  const _Informacoes({required this.detalhe});

  final TituloDetalhe detalhe;

  @override
  Widget build(BuildContext context) {
    final TextTheme texto = Theme.of(context).textTheme;
    final Color discreto = Theme.of(context).colorScheme.onSurfaceVariant;
    final double? nota = detalhe.notaExibivel;
    final String linha = <String>[
      // O backend manda `""` (não null) quando o título não tem data.
      if (detalhe.ano != null && detalhe.ano!.isNotEmpty) detalhe.ano!,
      ?switch (detalhe.tipo) {
        TipoMidia.tv => 'Série',
        TipoMidia.movie => 'Filme',
        TipoMidia.desconhecido => null,
      },
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(detalhe.titulo.isEmpty ? 'Sem título' : detalhe.titulo, style: texto.headlineSmall),
        const SizedBox(height: 6),
        // Wrap, not Row: with a large font the rating goes to the next line
        // instead of overflowing.
        Wrap(
          spacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            if (linha.isNotEmpty) Text(linha, style: texto.bodyMedium?.copyWith(color: discreto)),
            // Nota 0 is "no rating" on the TMDB, never "0.0".
            if (nota != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.star, size: 18, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(nota.toStringAsFixed(1), style: texto.bodyMedium),
                ],
              ),
          ],
        ),
        if (detalhe.generos.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final String genero in detalhe.generos)
                Chip(label: Text(genero), visualDensity: VisualDensity.compact),
            ],
          ),
        ],
        const SizedBox(height: 16),
        AcervoAcao(
          tipo: detalhe.tipo,
          tmdbId: detalhe.id,
          titulo: detalhe.titulo,
          ano: detalhe.ano,
          posterPath: detalhe.posterPath,
        ),
        _AssistidoEm(tipo: detalhe.tipo, id: detalhe.id),
        _Gosto(tipo: detalhe.tipo, id: detalhe.id),
        const SizedBox(height: 16),
        Text('Sinopse', style: texto.titleMedium),
        const SizedBox(height: 6),
        _Sinopse(texto: detalhe.sinopse),
        const SizedBox(height: 24),
        Text(
          'This product uses the TMDB API but is not endorsed or certified by TMDB.',
          style: texto.labelSmall?.copyWith(color: discreto),
        ),
      ],
    );
  }
}

/// "Assistido em 28/10/2026" under the shelf button (AP-54). Nothing when the
/// title is not "Assistido" or the server sent no date.
class _AssistidoEm extends StatelessWidget {
  const _AssistidoEm({required this.tipo, required this.id});

  final TipoMidia tipo;
  final int id;

  @override
  Widget build(BuildContext context) {
    final DateTime? quando = context.watch<AcervoViewModel>().assistidoEm(tipo, id);
    if (quando == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        'Assistido em ${dataCurta(quando)}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

/// The default conversion of [dataCurta]: the same instant, in the device's
/// time zone (a local `DateTime`, never a UTC one).
DateTime paraLocalDoAparelho(DateTime quando) => quando.toLocal();

/// `dd/mm/aaaa` in the device's time zone: the server sends UTC, and a title
/// watched at 22h in Brazil is already the next day in UTC.
///
/// [paraLocal] is the conversion to the device's zone; a test passes a fixed
/// one, because the zone of the machine running the tests is not Brazil's.
String dataCurta(
  DateTime quando, {
  DateTime Function(DateTime) paraLocal = paraLocalDoAparelho,
}) {
  final DateTime local = paraLocal(quando);
  String doisDigitos(int n) => n.toString().padLeft(2, '0');
  return '${doisDigitos(local.day)}/${doisDigitos(local.month)}/${local.year}';
}

/// 👍/👎, shown once she closed the title ("Assistido" or "Abandonei") or
/// already gave a signal (AP-48).
class _Gosto extends StatelessWidget {
  const _Gosto({required this.tipo, required this.id});

  final TipoMidia tipo;
  final int id;

  @override
  Widget build(BuildContext context) {
    final TitleDetailViewModel vm = context.watch<TitleDetailViewModel>();
    final EstadoAcervo? estado = context.watch<AcervoViewModel>().estadoDe(tipo, id);
    final bool fechou = estado == EstadoAcervo.watched || estado == EstadoAcervo.dropped;
    if (!fechou && vm.sinal == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: <Widget>[
          Text(estado == EstadoAcervo.dropped ? 'Por que parou?' : 'O que achou?'),
          if (vm.enviandoSinal)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else ...<Widget>[
            _BotaoSinal(sinal: SinalGosto.like, rotulo: '👍 Curti', estado: estado),
            _BotaoSinal(sinal: SinalGosto.dislike, rotulo: '👎 Não curti', estado: estado),
          ],
        ],
      ),
    );
  }
}

class _BotaoSinal extends StatelessWidget {
  const _BotaoSinal({required this.sinal, required this.rotulo, required this.estado});

  final SinalGosto sinal;
  final String rotulo;
  final EstadoAcervo? estado;

  @override
  Widget build(BuildContext context) {
    final TitleDetailViewModel vm = context.watch<TitleDetailViewModel>();
    final bool escolhido = vm.sinal == sinal;

    return ChoiceChip(
      label: Text(rotulo),
      selected: escolhido,
      showCheckmark: false,
      selectedColor: AppTheme.destaque,
      labelStyle: TextStyle(color: escolhido ? Colors.white : null),
      tooltip: escolhido ? 'Tocar de novo desfaz' : null,
      onSelected: (_) async {
        final AppError? erro = await vm.darSinal(sinal, estado: estado);
        // Gone from the tree (left the page or signed out): nothing to warn.
        if (erro == null || !context.mounted) return;
        ScaffoldMessenger.maybeOf(context)
          ?..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('Não salvou seu gosto. ${erro.mensagem}')));
      },
    );
  }
}

/// The synopsis, cut at [linhas] lines with "Ler mais" when it is longer.
///
/// The backend allows an empty synopsis: then the page says so instead of
/// leaving a heading over nothing.
class _Sinopse extends StatefulWidget {
  const _Sinopse({required this.texto});

  final String? texto;

  static const int linhas = 6;

  @override
  State<_Sinopse> createState() => _SinopseState();
}

class _SinopseState extends State<_Sinopse> {
  bool _aberta = false;

  @override
  Widget build(BuildContext context) {
    final String texto = widget.texto?.trim() ?? '';
    final TextStyle? estilo = Theme.of(context).textTheme.bodyMedium;
    if (texto.isEmpty) {
      return Text(
        'Sem sinopse disponível.',
        style: estilo?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Measures before deciding: the "Ler mais" only shows when the text
        // really passes the limit at this width and font size.
        final TextPainter medida = TextPainter(
          text: TextSpan(text: texto, style: estilo),
          maxLines: _Sinopse.linhas,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final bool passa = medida.didExceedMaxLines;
        medida.dispose();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              texto,
              style: estilo,
              maxLines: _aberta ? null : _Sinopse.linhas,
              overflow: _aberta ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
            if (passa)
              TextButton(
                onPressed: () => setState(() => _aberta = !_aberta),
                child: Text(_aberta ? 'Ler menos' : 'Ler mais'),
              ),
          ],
        );
      },
    );
  }
}
