import 'package:flutter/foundation.dart';

import '../../data/api_models/user.dart';
import '../../data/repositories/auth_repository.dart';
import '../../utils/app_error.dart';
import '../../utils/result.dart';

/// State of the login screen: is a request in flight, and which sentence the
/// screen has to show. It never navigates — signing in changes the app state
/// and the `AuthGate` does the swapping.
class LoginViewModel extends ChangeNotifier {
  LoginViewModel(this._repository);

  final AuthRepository _repository;

  bool _isSubmitting = false;
  AppError? _error;
  bool _viaGoogle = false;

  bool get isSubmitting => _isSubmitting;

  /// Which button started the request in flight, so the right one shows the
  /// spinner: whoever pressed "Entrar com Google" should not watch the e-mail
  /// button spin (and the screen reader gets a label on the right control).
  bool get isGoogleInFlight => _isSubmitting && _viaGoogle;
  bool get isEmailInFlight => _isSubmitting && !_viaGoogle;

  /// The sentence the screen shows.
  String? get error => _error?.mensagem;

  /// The error itself: the screen needs the kind (not the sentence) to react to
  /// "this e-mail already has an account" with the right button under it.
  AppError? get typedError => _error;

  Future<void> signIn(String email, String password) =>
      _run(() => _repository.signIn(email, password));

  Future<void> signUp(String email, String password) =>
      _run(() => _repository.signUp(email, password));

  Future<void> signInWithGoogle() => _run(_repository.signInWithGoogle, viaGoogle: true);

  /// Called when the user starts typing again: the old error is stale.
  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<void> _run(
    Future<Result<AppUser>> Function() action, {
    bool viaGoogle = false,
  }) async {
    // Reentrancy guard: a second tap while the first request is in flight would
    // fire a second sign-in attempt (the button is only disabled on the next
    // build) and the loser would overwrite the winner's state.
    if (_isSubmitting) return;

    _isSubmitting = true;
    _viaGoogle = viaGoogle;
    _error = null;
    notifyListeners();

    try {
      final Result<AppUser> result = await action();
      _error = result.errorOrNull;
    } on Exception catch (error) {
      // The contract says a repository always answers a `Result` and never throws.
      // This catches the exceptions that contract implies and answers a sentence.
      //
      // `Error` is left to bubble on purpose: a `TypeError` here is a bug in this
      // code, and dressing it as "the server slipped" would blame the server for
      // our mistake. The `finally` below releases the screen either way.
      // Logged unconditionally, like the other places that report a failure in
      // this app: `debugPrint` reaches release on purpose, and a contract violation
      // with no trace is undebuggable in the field.
      debugPrint('[AppSeries] login fora do contrato: $error');
      _error = const ServerError();
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
