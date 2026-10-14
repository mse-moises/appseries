import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/repositories/health_repository.dart';
import 'data/repositories/health_repository_impl.dart';
import 'data/services/rest_client.dart';
import 'ui/view_model/home_view_model.dart';
import 'utils/env.dart';

void main() => runApp(const AppSeries());

/// Wires the whole dependency graph.
///
/// This is the only place that knows how objects are built: every ViewModel is
/// created here and read on the screen with `context.watch`.
class AppSeries extends StatelessWidget {
  const AppSeries({super.key});

  @override
  Widget build(BuildContext context) => MultiProvider(
        providers: [
          Provider<Dio>(create: (_) => buildDio()),
          Provider<RestClient>(
            create: (ctx) => RestClient(ctx.read<Dio>(), baseUrl: Env.apiBaseUrl),
          ),
          Provider<HealthRepository>(
            create: (ctx) => HealthRepositoryImpl(ctx.read<RestClient>()),
          ),
          ChangeNotifierProvider<HomeViewModel>(
            create: (ctx) => HomeViewModel(ctx.read<HealthRepository>())..load(),
          ),
        ],
        child: const App(),
      );
}

/// The shared Dio instance: base URL, timeouts and (in debug) the request log.
///
/// The auth interceptor (Firebase id token per request + logout on 401) is added
/// here in AP-24.
Dio buildDio() {
  final Dio dio = Dio(
    BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );

  if (kDebugMode) {
    dio.interceptors.add(PrettyDioLogger(requestBody: true, responseBody: true, compact: true));
  }

  return dio;
}
