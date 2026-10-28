import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/repositories/acervo_repository.dart';
import 'data/repositories/acervo_repository_impl.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'data/repositories/feedback_repository.dart';
import 'data/repositories/feedback_repository_impl.dart';
import 'data/repositories/preferencias_repository.dart';
import 'data/repositories/preferencias_repository_impl.dart';
import 'data/repositories/titulo_repository.dart';
import 'data/repositories/titulo_repository_impl.dart';
import 'data/services/auth_interceptor.dart';
import 'data/services/auth_service.dart';
import 'data/services/rest_client.dart';
import 'firebase_options.dart';
import 'ui/view/startup_error_page.dart';
import 'ui/view_model/acervo_view_model.dart';
import 'ui/view_model/auth_view_model.dart';
import 'ui/view_model/home_view_model.dart';
import 'ui/view_model/login_view_model.dart';
import 'ui/view_model/search_view_model.dart';
import 'ui/view_model/title_detail_view_model.dart';
import 'utils/env.dart';

Future<void> main() async {
  // `DefaultFirebaseOptions` is written by hand in `lib/firebase_options.dart`
  // (the FlutterFire CLI is not installed here): Android values from
  // `android/app/google-services.json`, web values from the app registered in
  // the console. See `constitution.md` §7.
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (error, stack) {
    // No Firebase there is no app to draw: without this the app dies before the
    // first frame and the person gets a blank window. The screen says what
    // happened in product words; the detail goes to the log.
    debugPrint('[AppSeries] falha ao iniciar o Firebase: $error\n$stack');
    runApp(StartupErrorApp(mensagem: startupFailureMessage(error)));
    return;
  }
  runApp(const AppSeries());
}

/// Wires the whole dependency graph.
///
/// This is the only place that knows how objects are built: every ViewModel is
/// created here and read on the screen with `context.watch`.
class AppSeries extends StatelessWidget {
  const AppSeries({super.key});

  @override
  Widget build(BuildContext context) => MultiProvider(
        providers: [
          Provider<AuthService>(create: (_) => FirebaseAuthService()),
          Provider<AuthRepository>(
            create: (ctx) => AuthRepositoryImpl(ctx.read<AuthService>()),
          ),
          ChangeNotifierProvider<AuthViewModel>(
            create: (ctx) => AuthViewModel(ctx.read<AuthRepository>()),
          ),
          ChangeNotifierProvider<LoginViewModel>(
            create: (ctx) => LoginViewModel(ctx.read<AuthRepository>()),
          ),
          Provider<Dio>(create: (ctx) => buildDio(ctx.read<AuthService>())),
          Provider<RestClient>(
            create: (ctx) => RestClient(ctx.read<Dio>(), baseUrl: Env.apiBaseUrl),
          ),
          Provider<TituloRepository>(
            create: (ctx) => TituloRepositoryImpl(ctx.read<RestClient>()),
          ),
          // No `..load()` here: the `HomePage` is what loads, and it is mounted
          // anew on every login (the provider's `create` runs once).
          ChangeNotifierProvider<HomeViewModel>(
            create: (ctx) => HomeViewModel(ctx.read<TituloRepository>()),
          ),
          // AP-44: the search page resets it on open (the `create` runs once).
          ChangeNotifierProvider<SearchViewModel>(
            create: (ctx) => SearchViewModel(ctx.read<TituloRepository>()),
          ),
          // AP-28: the shelf lives on the server, so the app only reads it.
          Provider<AcervoRepository>(
            create: (ctx) => AcervoRepositoryImpl(ctx.read<RestClient>()),
          ),
          ChangeNotifierProvider<AcervoViewModel>(
            create: (ctx) => AcervoViewModel(ctx.read<AcervoRepository>()),
          ),
          // AP-108: the taste lives on the server too; the onboarding screen
          // (AP-37) is the first consumer.
          Provider<PreferenciasRepository>(
            create: (ctx) => PreferenciasRepositoryImpl(ctx.read<RestClient>()),
          ),
          // AP-109: 👍/👎 mora no servidor, preso à conta e ao par (tipo, tmdbId).
          Provider<FeedbackRepository>(
            create: (ctx) => FeedbackRepositoryImpl(ctx.read<RestClient>()),
          ),
          // AP-47: the detail page resets it on open (the `create` runs once).
          ChangeNotifierProvider<TitleDetailViewModel>(
            create: (ctx) => TitleDetailViewModel(
              ctx.read<TituloRepository>(),
              ctx.read<FeedbackRepository>(),
            ),
          ),
        ],
        child: const App(),
      );
}

/// The shared Dio instance: base URL, timeouts, the auth interceptor (id token
/// per request + logout on 401) and, in debug, the request log.
Dio buildDio(AuthService auth) {
  final Dio dio = Dio(
    BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );

  dio.interceptors.add(authInterceptor(auth));

  if (kDebugMode) {
    dio.interceptors.add(PrettyDioLogger(requestBody: true, responseBody: true, compact: true));
  }

  return dio;
}
