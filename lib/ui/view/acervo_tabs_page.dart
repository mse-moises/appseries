import 'package:flutter/material.dart';

/// Stub da fundação (AP-108): a rota, o endpoint e o repositório estão abertos. The route already exists so
/// the real screen does not have to touch `routes_config.dart`.
///
/// Whoever takes **AP-60** replaces the body below and nothing else; the route,
/// the endpoint and the repository are already open. The ViewModel and the
/// screen are yours. Here `AcervoViewModel` and its provider already exist: the
/// work is adding `marcar`/`remover` to it and writing the screen.
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
