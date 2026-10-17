import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../../utils/app_error.dart';
import '../../utils/result.dart';
import '../api_models/user.dart';
import '../services/auth_service.dart';
import 'auth_repository.dart';

/// Talks to Firebase Auth through [AuthService] and answers
/// `Future<Result<...>>`, like every repository in this project.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._auth, {Duration? timeLimit})
      : timeLimit = timeLimit ?? const Duration(seconds: 30);

  final AuthService _auth;

  /// How long THIS path waits for the provider before answering "took too long".
  /// Injectable so a test can prove the behaviour without waiting 30 seconds.
  /// The interceptor has its own, shorter deadline (see `auth_interceptor.dart`).
  final Duration timeLimit;

  @override
  Stream<AppUser?> get sessionStream => _auth.sessionStream;

  @override
  Future<Result<AppUser>> signIn(String email, String password) =>
      _attempt(() => _auth.signIn(email, password));

  @override
  Future<Result<AppUser>> signUp(String email, String password) =>
      _attempt(() => _auth.signUp(email, password));

  @override
  Future<Result<AppUser>> signInWithGoogle() => _attempt(_auth.signInWithGoogle);

  @override
  Future<Result<void>> signOut() async {
    try {
      await _auth.signOut().timeout(timeLimit);
      return const Result<void>.ok(null);
    } on TimeoutException {
      return const Result<void>.error(TempoEsgotadoError());
    } on FirebaseAuthException catch (e) {
      return Result<void>.error(appErrorFromFirebase(e.code));
    } catch (_) {
      // Same rule as the rest of the project: the contract of a repository is
      // to always answer a Result, so no screen has to guard against a raw
      // exception.
      return const Result<void>.error(ServerError());
    }
  }

  Future<Result<AppUser>> _attempt(Future<AppUser> Function() action) async {
    try {
      return Result.ok(await action().timeout(timeLimit));
    } on TimeoutException {
      // The provider accepted the request and went quiet: answering a sentence
      // beats leaving the person on a screen that never resolves.
      //
      // `.timeout` does not cancel what is behind it, so a sign-in that lands
      // after the deadline still signs the person in: the session stream is the
      // source of truth and the `AuthGate` will show the home while this sentence
      // is already on screen. Accepted — the alternative was waiting with no way
      // out, and Firebase Auth offers no cancellation.
      return const Result<AppUser>.error(TempoEsgotadoError());
    } on FirebaseAuthException catch (e) {
      // `e.code` is the raw code; the mapper turns it into the sentence the
      // screen shows.
      return Result.error(appErrorFromFirebase(e.code));
    } catch (_) {
      return const Result<AppUser>.error(ServerError());
    }
  }
}
