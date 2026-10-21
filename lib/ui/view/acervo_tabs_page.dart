import 'package:flutter/material.dart';

/// Stub da fundação (AP-108): a rota, o endpoint e o repositório estão abertos.
///
/// Quem pegar **AP-60** troca o corpo abaixo e nada mais. O ViewModel e a tela
/// são da trilha; `main.dart` ainda precisa de uma linha para o provider.
class AcervoTabsPage extends StatelessWidget {
  const AcervoTabsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meu acervo')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Tela em construção (AP-60).',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
