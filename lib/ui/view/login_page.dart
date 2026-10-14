import 'package:flutter/material.dart';

import '../../utils/routes_config.dart';

/// Login screen shell.
///
/// The real login (Firebase Auth: e-mail/password and Google) lands in AP-23 and
/// AP-24. Until then the button only navigates to the home shell, so the
/// skeleton is navigable end to end and nothing here pretends to authenticate.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text('AppSeries', textAlign: TextAlign.center, style: tema.textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Seu catálogo de séries e filmes',
                    textAlign: TextAlign.center,
                    style: tema.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    enabled: false,
                    decoration: InputDecoration(labelText: 'E-mail', border: const OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    enabled: false,
                    obscureText: true,
                    decoration: InputDecoration(labelText: 'Senha', border: const OutlineInputBorder()),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, Routes.home),
                    child: const Text('Entrar'),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'O login de verdade (Firebase Auth) entra na fatia AP-24',
                    textAlign: TextAlign.center,
                    style: tema.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
