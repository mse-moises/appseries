import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/api_models/carta_rec.dart';
import '../../utils/tmdb_image.dart';
import '../view_model/rec_view_model.dart';
import '../widgets/status_view.dart';

/// "O que assistir agora": o momento num campo livre e até três cartas.
///
/// A tela abre **ociosa** (nada é pedido até a pessoa tocar em "Recomendar"):
/// o teto do servidor é de 20 recomendações por dia, e abrir a tela não pode
/// gastar uma delas.
class RecPage extends StatefulWidget {
  const RecPage({super.key});

  @override
  State<RecPage> createState() => _RecPageState();
}

class _RecPageState extends State<RecPage> {
  /// O texto do momento é estado de TELA (existe porque a tela existe), então
  /// mora aqui, não no ViewModel.
  final TextEditingController _momento = TextEditingController();

  @override
  void initState() {
    super.initState();
    // O provider é criado uma vez na raiz: sem este reset a próxima conta veria
    // as cartas da anterior. Síncrono e sem notificar (é fase de build).
    context.read<RecViewModel>().reset();
  }

  @override
  void dispose() {
    _momento.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final RecViewModel vm = context.watch<RecViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('O que assistir agora')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: <Widget>[
          TextField(
            key: const Key('rec-momento'),
            controller: _momento,
            maxLength: 200,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _gerar(vm),
            decoration: const InputDecoration(
              labelText: 'Como está o seu momento?',
              hintText: 'algo leve pra ver com a esposa',
              helperText: 'Deixe em branco para usar o momento que você já salvou.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 4),
          FilledButton.icon(
            key: const Key('rec-gerar'),
            onPressed: vm.carregando ? null : () => _gerar(vm),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Recomendar'),
          ),
          const SizedBox(height: 20),
          _Corpo(vm: vm, onOutra: () => _gerar(vm)),
        ],
      ),
    );
  }

  void _gerar(RecViewModel vm) => vm.gerar(momento: _momento.text);
}

/// Tudo o que muda com o estado da busca: convite, carregando, erro, vazio ou
/// as cartas.
class _Corpo extends StatelessWidget {
  const _Corpo({required this.vm, required this.onOutra});

  final RecViewModel vm;
  final VoidCallback onOutra;

  @override
  Widget build(BuildContext context) {
    if (vm.carregando) {
      return const SizedBox(
        height: 220,
        child: LoadingView(mensagem: 'Escolhendo pra você...'),
      );
    }

    if (vm.erro != null) {
      return SizedBox(
        height: 220,
        child: ErrorView(mensagem: vm.erro!, onRetry: onOutra),
      );
    }

    if (vm.semCartas) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'Não achei nada que combine com isso agora. Tente descrever outro '
          'momento, ou marque no acervo o que você já assistiu.',
          textAlign: TextAlign.center,
        ),
      );
    }

    final List<CartaRec> cartas = vm.cartas;
    if (cartas.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'Escreva o seu momento (ou deixe em branco) e toque em Recomendar.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // O fallback do servidor não é erro: a pessoa vê o que apareceu e sabe
        // de onde veio.
        if (vm.origem == OrigemRec.emAlta)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Em alta no TMDB',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        // O critério da AP-98: com menos de três, a tela explica em vez de
        // parecer quebrada.
        if (cartas.length < 3)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              cartas.length == 1
                  ? 'Só achei uma opção que combina com esse momento agora.'
                  : 'Só achei ${cartas.length} opções que combinam com esse momento agora.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        for (int i = 0; i < cartas.length; i++) ...<Widget>[
          _Carta(carta: cartas[i], recomendada: i == 0),
          const SizedBox(height: 12),
        ],
        OutlinedButton.icon(
          key: const Key('rec-outra'),
          onPressed: onOutra,
          icon: const Icon(Icons.refresh),
          label: const Text('Outra rodada'),
        ),
      ],
    );
  }
}

/// Uma carta: pôster, título, tipo e ano, e o porquê em uma linha.
class _Carta extends StatelessWidget {
  const _Carta({required this.carta, required this.recomendada});

  final CartaRec carta;
  final bool recomendada;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final String? url = urlDoPoster(carta.posterPath);
    final String tipo = switch (carta.tipo) {
      TipoMidia.movie => 'Filme',
      TipoMidia.tv => 'Série',
      TipoMidia.desconhecido => 'Título',
    };
    final String ano = carta.ano == null || carta.ano!.isEmpty ? '' : ' · ${carta.ano}';

    return Card(
      key: Key('rec-carta-${carta.tipo.name}-${carta.tmdbId}'),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 72,
                height: 108,
                child: Container(
                  color: tema.colorScheme.surfaceContainerHighest,
                  child: url == null
                      ? Icon(Icons.movie_outlined, color: tema.colorScheme.onSurfaceVariant)
                      : CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          placeholder: (BuildContext context, String _) => const Center(
                            child: SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (BuildContext context, String _, Object __) => Icon(
                            Icons.movie_outlined,
                            color: tema.colorScheme.onSurfaceVariant,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (recomendada)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'A recomendação pra você',
                        style: tema.textTheme.labelMedium?.copyWith(
                          color: tema.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  Text(
                    carta.titulo,
                    style: tema.textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '$tipo$ano',
                    style: tema.textTheme.labelSmall?.copyWith(
                      color: tema.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(carta.justificativa, style: tema.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
