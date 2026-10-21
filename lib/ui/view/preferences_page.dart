import 'package:flutter/material.dart';

/// Stub da fundação (AP-108): a rota, o endpoint e o repositório estão abertos. The route already exists so
/// the real screen does not have to touch `routes_config.dart`.
///
/// Whoever takes **AP-38** replaces the body below and nothing else; the route,
/// the endpoint and the repository are already open. The ViewModel and the
/// screen are yours: `main.dart` still needs one line for your provider.
class PreferencesPage extends StatelessWidget {
  const PreferencesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('O que eu gosto')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Tela em construção (AP-38).',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
