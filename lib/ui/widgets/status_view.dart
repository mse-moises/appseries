import 'package:flutter/material.dart';

/// Centered progress — used while a ViewModel is loading.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.mensagem});

  final String? mensagem;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const CircularProgressIndicator(),
            if (mensagem != null) ...<Widget>[
              const SizedBox(height: 16),
              Text(mensagem!),
            ],
          ],
        ),
      );
}

/// Centered error with an optional retry action.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.mensagem, this.onRetry});

  final String mensagem;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(Icons.cloud_off_outlined, size: 48),
              const SizedBox(height: 12),
              Text(mensagem, textAlign: TextAlign.center),
              if (onRetry != null) ...<Widget>[
                const SizedBox(height: 16),
                FilledButton.tonal(onPressed: onRetry, child: const Text('Tentar de novo')),
              ],
            ],
          ),
        ),
      );
}
