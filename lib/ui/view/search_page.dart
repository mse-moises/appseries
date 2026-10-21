import 'package:flutter/material.dart';

/// Stub criado pela fundação (AP-108); o corpo é da trilha. The route already exists so
/// the real screen does not have to touch `routes_config.dart`.
///
/// Whoever takes **AP-44** replaces the body below and nothing else; the route,
/// the endpoint and the repository are already open. The ViewModel and the
/// screen are yours: `main.dart` still needs one line for your provider.
class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Busca')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Tela em construção (AP-44).',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
