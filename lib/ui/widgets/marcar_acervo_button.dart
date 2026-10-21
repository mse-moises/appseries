import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../view_model/acervo_view_model.dart';
import '../view_model/marcar_acervo_view_model.dart';
import 'acervo_action_button.dart';
import 'motivo_abandono.dart';

/// O botão de marcar **com** o fluxo do abandono: o que as telas montam.
///
/// Toque em "Abandonei" → o estado começa a ser salvo na hora e os chips de
/// motivo aparecem por cima (AP-57). A folha é descartável, então nada trava: se
/// ela fechar sem escolha, o abandono fica salvo e o motivo simplesmente não
/// existe. A escolha vira peso do feedback (AP-56), nunca texto no acervo.
///
/// A View só repassa o toque e mostra o aviso; quem salva é o ViewModel.
class MarcarAcervoButton extends StatefulWidget {
  const MarcarAcervoButton({super.key, required this.tipo, required this.tmdbId});

  final TipoMidia tipo;
  final int tmdbId;

  @override
  State<MarcarAcervoButton> createState() => _MarcarAcervoButtonState();
}

class _MarcarAcervoButtonState extends State<MarcarAcervoButton> {
  Future<void> _escolher(EstadoAcervo estado) async {
    final MarcarAcervoViewModel marcarVm = context.read<MarcarAcervoViewModel>();
    final AcervoViewModel acervoVm = context.read<AcervoViewModel>();

    marcarVm.limparAvisos();

    // O toque já vale: a gravação do estado sai antes dos chips, para o motivo
    // (opcional) não segurar o abandono.
    final Future<bool> acervoSalvo =
        marcarVm.marcarAcervo(widget.tipo, widget.tmdbId, estado);

    MotivoAbandono? motivo;
    if (estado == EstadoAcervo.dropped) {
      motivo = await perguntarMotivoAbandono(context);
    }

    final bool salvou = await acervoSalvo;
    if (!mounted) return;

    if (!salvou) {
      // `erro` nulo = já havia uma gravação em curso (reentrância): ignora.
      final String? mensagem = marcarVm.erro;
      if (mensagem != null) _avisar(mensagem);
      return;
    }

    if (motivo != null) {
      await marcarVm.registrarMotivo(widget.tipo, widget.tmdbId, motivo);
      if (!mounted) return;
      if (marcarVm.motivoNaoRegistrado) {
        _avisar('Abandono salvo. O motivo não foi registrado.');
      }
    }

    // A lista (e o mapa de estados) é do outro ViewModel: recarrega para o
    // rótulo e o selo refletirem o que o servidor gravou.
    unawaited(acervoVm.load());
  }

  void _avisar(String mensagem) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensagem)));
  }

  @override
  Widget build(BuildContext context) {
    final AcervoViewModel acervoVm = context.watch<AcervoViewModel>();

    return AcervoActionButton(
      atual: acervoVm.estadoDe(widget.tipo, widget.tmdbId),
      onEscolher: _escolher,
    );
  }
}
