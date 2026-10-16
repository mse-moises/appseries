import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../utils/app_error.dart';
import 'auth_service.dart';

/// Puts the Firebase id token on every request and signs out on 401.
///
/// The token is asked for **per request** (`constitution.md` §7): the SDK
/// caches it and refreshes it by itself, so a long session never sends a stale
/// one. A 401 signs the user out, and the `AuthGate` reacts by showing the
/// login again.
///
/// [timeLimit] bounds the two waits this interceptor does on the auth SDK: the
/// token of each request and the best-effort sign-out on 401. It is injectable so
/// a test can prove both deadlines without waiting ten seconds.
Interceptor authInterceptor(
  AuthService auth, {
  Duration timeLimit = const Duration(seconds: 10),
}) =>
    InterceptorsWrapper(
      onRequest: (
        RequestOptions options,
        RequestInterceptorHandler handler,
      ) async {
        final String? token;
        try {
          token = await auth.idToken().timeout(timeLimit);
        } on TimeoutException {
          // The SDK is refreshing the token (they do expire) and went quiet. The
          // request has to fail as a slow connection instead of going out without
          // the header: without `Authorization` the API answers 401 and this very
          // interceptor would sign the person out over a slow refresh. Proceeding
          // is no option either, because the dio timeouts do not reach here — the
          // request never left.
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
              // Carries the typed error so the mapper can say "Demorou demais"
              // (a slow token refresh) instead of "Confira sua rede", which
              // would blame the person's connection for a provider problem.
              error: const TempoEsgotadoError(),
              message: 'id token took longer than ${timeLimit.inMilliseconds}ms',
            ),
            // `true`: let the following error interceptors see this failure. Without
            // it the request that never left is invisible in the logger, which sits
            // after this one — exactly the failure the deadline exists to reveal.
            true,
          );
          return;
        }
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (DioException e, ErrorInterceptorHandler handler) async {
        if (e.response?.statusCode == 401) {
          // Best effort: a failing sign-out must not swallow the 401, or the
          // screen would report a server error and the session would stay
          // alive (the AuthGate only swaps screens when the stream emits).
          //
          // The deadline is part of that: a sign-out that never answers swallows
          // the 401 just like one that throws, because `handler.next(e)` below
          // waits for this `await`. It is shorter than the repository's 30s on
          // purpose: this one is best-effort and the 401 is already waiting.
          try {
            await auth.signOut().timeout(timeLimit);
          } catch (error) {
            // The 401 still has to go up; the failed sign-out leaves a trace.
            debugPrint('[AppSeries] falha ao sair depois de um 401: $error');
          }
        }
        handler.next(e);
      },
    );
