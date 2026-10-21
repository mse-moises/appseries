import 'package:flutter/material.dart';

import '../navegacao/titulo_ref.dart';

/// Stub created by the foundation task (AP-108).
///
/// Whoever takes **AP-47** replaces the body and keeps the signature: the screen
/// reads the [TituloRef] from the route arguments, so callers already send the
/// pair `(tipo, id)` — the TMDB numbers movie and series separately.
class DetalhePage extends StatelessWidget {
  const DetalhePage({super.key});

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
