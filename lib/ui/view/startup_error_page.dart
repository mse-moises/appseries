import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The app's last resort, wrapped in its own [MaterialApp].
///
/// It runs before the Firebase is up, so it cannot use `App`, which lives behind
/// the providers. The `MaterialApp` is not decoration: without it there is no
/// `Directionality` above the text and the page throws instead of rendering —
/// the person would get a red screen (debug) or a grey one (release) instead of
/// the sentence. Proven by `startup_error_page_test.dart`, which pumps this
/// widget the same way `main()` does.
///
/// What the app shows when it cannot start (Firebase unreachable, platform not
/// registered). Without it the app dies before the first frame and the person
/// sees a blank window with no clue about what happened.
class StartupErrorPage extends StatelessWidget {
  const StartupErrorPage({super.key, required this.mensagem});

  final String mensagem;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);

    return Scaffold(
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) =>
            SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Icon(Icons.cloud_off_outlined, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Não deu para abrir o AppSeries',
                      textAlign: TextAlign.center,
                      style: tema.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(mensagem, textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.mensagem});

  final String mensagem;

  @override
  Widget build(BuildContext context) {
    final ({ThemeData light, ThemeData dark, ThemeMode mode}) temas = temasDoApp();
    return MaterialApp(
      title: 'AppSeries',
      theme: temas.light,
      darkTheme: temas.dark,
      themeMode: temas.mode,
      home: StartupErrorPage(mensagem: mensagem),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// The sentence the screen shows, from the error that stopped the start-up.
String startupFailureMessage(Object error) => error is UnsupportedError
    ? 'O AppSeries roda no Android e no navegador.'
    : 'Não deu para conectar. Confira sua internet e abra o app de novo.';
