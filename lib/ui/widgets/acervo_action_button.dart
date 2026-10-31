import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/api_models/acervo_item.dart';
import '../../utils/app_error.dart';
import '../theme/app_theme.dart';
import '../view_model/acervo_view_model.dart';

export '../../data/api_models/acervo_item.dart';

/// Product name of each shelf state. Lives next to the widget because it is the
/// only place that shows them; a second copy elsewhere would drift.
String rotuloEstado(EstadoAcervo estado) => switch (estado) {
      EstadoAcervo.planToWatch => 'Quero ver',
      EstadoAcervo.watching => 'Assistindo',
      EstadoAcervo.watched => 'Assistido',
      EstadoAcervo.dropped => 'Abandonei',
      EstadoAcervo.desconhecido => 'Sem estado',
    };

/// The four states, as a menu — plus "Remover" when the title is on the shelf.
///
/// It is a widget — not a piece of each screen — because the same choice appears
/// in three places (home, search result and detail). The screen only tells which
/// state is current and what to do when the person picks another; saving is the
/// ViewModel's job, never the widget's. [AcervoAcao] is what wires it to the
/// shelf, so the three places behave the same.
///
/// A title not on the shelf yet takes **one tap** to "Quero ver" (AP-49); the
/// other states are one level down, in the arrow next to it. Once on the shelf,
/// the tap opens the menu to change or remove.
class AcervoActionButton extends StatelessWidget {
  const AcervoActionButton({
    super.key,
    this.atual,
    required this.onEscolher,
    this.onRemover,
    this.enviando = false,
    this.compacto = false,
  });

  /// `null` when the title is not on the shelf yet.
  final EstadoAcervo? atual;

  final ValueChanged<EstadoAcervo> onEscolher;

  /// Offered only when the title is on the shelf (there is nothing to remove
  /// otherwise).
  final VoidCallback? onRemover;

  /// A write on its way: the button shows progress and takes no tap.
  final bool enviando;

  /// Icon only, for the poster of a carousel.
  final bool compacto;

  static const double _tamanhoProgresso = 18;

  @override
  Widget build(BuildContext context) {
    if (enviando) {
      // Takes the tap itself: on the poster, a tap on the spinner would
      // otherwise fall through to the card and open the detail.
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: Semantics(
          label: 'Salvando no acervo',
          child: Padding(
            padding: EdgeInsets.all(compacto ? 6 : 10),
            child: const SizedBox(
              width: _tamanhoProgresso,
              height: _tamanhoProgresso,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }
    if (atual == null) return _foraDoAcervo(context);
    return _menu(context, child: compacto ? null : _rotulo(context, atual!));
  }

  /// Not on the shelf: the tap is "Quero ver"; the arrow has the other states.
  Widget _foraDoAcervo(BuildContext context) {
    if (compacto) {
      return IconButton(
        onPressed: () => onEscolher(EstadoAcervo.planToWatch),
        icon: const Icon(Icons.bookmark_add_outlined),
        tooltip: 'Quero ver',
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Flexible: with a large font the label shrinks instead of overflowing.
        Flexible(
          child: TextButton.icon(
            onPressed: () => onEscolher(EstadoAcervo.planToWatch),
            icon: const Icon(Icons.bookmark_add_outlined, size: 18),
            label: const Text('Quero ver', overflow: TextOverflow.ellipsis),
          ),
        ),
        _menu(context, icone: const Icon(Icons.arrow_drop_down), tooltip: 'Outros estados'),
      ],
    );
  }

  Widget _rotulo(BuildContext context, EstadoAcervo estado) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.bookmark, size: 18, color: AppTheme.destaque),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                rotuloEstado(estado),
                style: Theme.of(context).textTheme.labelLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      );

  Widget _menu(BuildContext context, {Widget? child, Widget? icone, String? tooltip}) {
    final ThemeData tema = Theme.of(context);

    return PopupMenuButton<_Opcao>(
      tooltip: tooltip ?? (atual == null ? 'Marcar no meu acervo' : rotuloEstado(atual!)),
      icon: child == null
          ? (icone ?? const Icon(Icons.bookmark, color: AppTheme.destaque))
          : null,
      onSelected: (_Opcao opcao) =>
          opcao.estado == null ? onRemover?.call() : onEscolher(opcao.estado!),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<_Opcao>>[
        for (final EstadoAcervo estado in const <EstadoAcervo>[
          EstadoAcervo.planToWatch,
          EstadoAcervo.watching,
          EstadoAcervo.watched,
          EstadoAcervo.dropped,
        ])
          PopupMenuItem<_Opcao>(
            value: _Opcao(estado),
            child: Row(
              children: <Widget>[
                Icon(
                  estado == atual ? Icons.check : null,
                  size: 18,
                  color: tema.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Flexible(child: Text(rotuloEstado(estado), overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
        if (atual != null && onRemover != null) ...<PopupMenuEntry<_Opcao>>[
          const PopupMenuDivider(),
          const PopupMenuItem<_Opcao>(
            value: _Opcao(null),
            child: Row(
              children: <Widget>[
                Icon(Icons.bookmark_remove_outlined, size: 18),
                SizedBox(width: 8),
                // Flexible: with a large font the line outgrows the menu's width.
                Flexible(child: Text('Remover do acervo', overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
        ],
      ],
      child: child,
    );
  }
}

/// A menu entry: one of the four states, or `null` for "Remover".
class _Opcao {
  const _Opcao(this.estado);

  final EstadoAcervo? estado;

  @override
  bool operator ==(Object other) => other is _Opcao && other.estado == estado;

  @override
  int get hashCode => estado.hashCode;
}

/// [AcervoActionButton] wired to the shelf: the same behaviour on the poster,
/// the search result and the detail (AP-50).
///
/// Reads the current state from [AcervoViewModel] and writes through it. A
/// failure comes back as a message on screen: the ViewModel has already put the
/// previous state back, and the button never pretends it saved.
class AcervoAcao extends StatelessWidget {
  const AcervoAcao({
    required this.tipo,
    required this.tmdbId,
    this.titulo,
    this.ano,
    this.posterPath,
    this.compacto = false,
    super.key,
  });

  final TipoMidia tipo;
  final int tmdbId;

  /// What the screen already shows about the title. It goes into the shelf line
  /// at once, so the line is not blank while the server answers.
  final String? titulo;
  final String? ano;
  final String? posterPath;

  final bool compacto;

  @override
  Widget build(BuildContext context) {
    // A type this app cannot translate cannot be written: no button at all
    // beats one that always fails.
    if (tipo == TipoMidia.desconhecido) return const SizedBox.shrink();

    final AcervoViewModel acervo = context.watch<AcervoViewModel>();

    // The shelf did not load, so the current state is unknown: a tap now
    // would overwrite a state she may already have (a "Quero ver" over an
    // "Assistido"). The button offers to read the shelf again instead.
    if (!acervo.isLoading && acervo.error != null) {
      const String dica = 'Não deu para ler seu acervo. Tocar para tentar de novo';
      return compacto
          ? IconButton(
              onPressed: acervo.load,
              icon: const Icon(Icons.sync_problem),
              tooltip: dica,
            )
          : TextButton.icon(
              onPressed: acervo.load,
              icon: const Icon(Icons.sync_problem, size: 18),
              label: const Text('Recarregar acervo'),
            );
    }

    final EstadoAcervo? atual = acervo.estadoDe(tipo, tmdbId);

    return AcervoActionButton(
      atual: atual,
      compacto: compacto,
      // While the shelf loads, the current state is unknown too.
      enviando: acervo.isLoading || acervo.enviando(tipo, tmdbId),
      onEscolher: (EstadoAcervo estado) {
        if (estado == atual) return;
        _avisarSeFalhar(
          context,
          acervo.marcar(
            tipo,
            tmdbId,
            estado,
            titulo: titulo,
            ano: ano,
            posterPath: posterPath,
          ),
        );
      },
      onRemover: acervo.podeRemover(tipo, tmdbId)
          ? () => _avisarSeFalhar(context, acervo.remover(tipo, tmdbId))
          : null,
    );
  }

  static Future<void> _avisarSeFalhar(BuildContext context, Future<AppError?> gravacao) async {
    // Taken before the wait, not after: on the shelf list (AP-63) a new state
    // moves the line to another tab, so this button leaves the tree before the
    // answer arrives — and the failure still has to be said. A sign-out in
    // between is handled elsewhere: the home resets the shelf when the session
    // ends (`HomePage.dispose`), and the ViewModel then answers `null`.
    final ScaffoldMessengerState? aviso = ScaffoldMessenger.maybeOf(context);
    final AppError? erro = await gravacao;
    if (erro == null || aviso == null || !aviso.mounted) return;
    aviso
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Não salvou no acervo. ${erro.mensagem}')));
  }
}
