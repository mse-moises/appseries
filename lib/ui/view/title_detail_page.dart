import 'package:flutter/material.dart';

import '../navegacao/titulo_ref.dart';

/// Stub da fundação (AP-108): a rota, o endpoint e o repositório estão abertos.
///
/// Quem pegar **AP-47** troca o corpo e mantém a assinatura: a tela lê o
/// [TituloRef] dos argumentos da rota, então quem chama já manda o par
/// `(tipo, id)` — o TMDB numera filme e série em espaços separados.
class TitleDetailPage extends StatelessWidget {
  const TitleDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final Object? argumentos = ModalRoute.of(context)?.settings.arguments;
    final String alvo = argumentos is TituloRef
        ? '${argumentos.tipo.name} ${argumentos.id}'
        : 'sem título na rota';

    return Scaffold(
      appBar: AppBar(title: const Text('Detalhe do título')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Tela em construção (AP-47).\nRecebi: $alvo',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
