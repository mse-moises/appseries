import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../view_model/home_view_model.dart';
import '../widgets/status_view.dart';

/// Home shell.
///
/// Proves the whole chain works against the real backend (View → ViewModel →
/// Repository → RestClient → Result). The carousels land in AP-31.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final HomeViewModel vm = context.watch<HomeViewModel>();

    if (vm.isLoading) {
      return const Scaffold(body: LoadingView(mensagem: 'Falando com o backend...'));
    }

    if (vm.error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('AppSeries')),
        body: ErrorView(mensagem: vm.error!, onRetry: vm.load),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('AppSeries')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(Icons.check_circle_outline, size: 48),
              const SizedBox(height: 12),
              Text('Backend respondeu: ${vm.status?.status ?? '-'}'),
              const SizedBox(height: 8),
              Text(
                'Os carrosséis da home entram em AP-31',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              FilledButton.tonal(onPressed: vm.load, child: const Text('Testar de novo')),
            ],
          ),
        ),
      ),
    );
  }
}
