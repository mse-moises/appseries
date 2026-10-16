import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/api_models/user.dart';
import '../../data/repositories/auth_repository.dart';
import '../../utils/app_error.dart';
import '../../utils/result.dart';

/// Who is signed in. This is **app state**, not screen state
/// (`constitution.md` §1): it lives at the root and the `AuthGate` watches it.
enum SessionState { unknown, signedIn, signedOut }

class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._repository) {
    // `authStateChanges()` starts by emitting the current state, so the app
    // goes from `unknown` to the real answer without a guess.
    //
    // The error and the done callbacks matter as much as the data: the screen is
    // chosen from `_estado`, so a session stream that dies without a value would
    // leave the app on the loading screen forever, with no button and no way out
    // but killing it. Falling back to `signedOut` always leaves a way forward (the
    // login screen), and a real problem still shows up there as a sentence.
    _subscription = _repository.sessionStream.listen(
      _onSessionChanged,
      onError: _onSessionLost,
      onDone: _onSessionLost,
    );
  }

  final AuthRepository _repository;
  late final StreamSubscription<AppUser?> _subscription;

  SessionState _state = SessionState.unknown;
  AppUser? _user;
  bool _isSigningOut = false;
  String? _signOutError;
  String? _notice;
  bool _signOutRequested = false;

  SessionState get state => _state;
  AppUser? get user => _user;

  /// A sign-out in flight: the screen shows a spinner instead of the icon.
  bool get isSigningOut => _isSigningOut;

  /// Why the sign-out failed. A sign-out that fails silently looks like a dead
  /// button.
  String? get signOutError => _signOutError;

  /// Why the session ended without her asking (an expired token, the 401 that
  /// made the interceptor sign out). Without it she lands on the login screen
  /// with no idea what happened, which reads as a bug.
  String? get notice => _notice;

  /// Signs out. The screen has nothing to do with the answer: the session
  /// stream changes and the `AuthGate` swaps the screen by itself.
  Future<void> signOut() async {
    if (_isSigningOut) return;

    _isSigningOut = true;
    _signOutError = null;
    // The stream will report the logout; this flag is what keeps that logout
    // from looking like a session taken away from her.
    _signOutRequested = true;
    notifyListeners();

    try {
      final Result<void> result = await _repository.signOut();
      _signOutError = result.errorOrNull?.mensagem;
      // The sign-out failed, so the session is still there: the next logout will
      // not be one she asked for.
      if (_signOutError != null) _signOutRequested = false;
    } on Exception catch (error) {
      // Same rule as `LoginViewModel._executar`: the contract is to answer a
      // `Result`, and this guards the day it breaks. Without the `finally` the
      // flag would stay true and the icon would be a spinner for good.
      debugPrint('[AppSeries] sair fora do contrato: $error');
      _signOutError = const ServerError().mensagem;
      _signOutRequested = false;
    } finally {
      _isSigningOut = false;
      notifyListeners();
    }
  }

  void clearSignOutError() {
    if (_signOutError == null) return;
    _signOutError = null;
    notifyListeners();
  }

  void clearNotice() {
    if (_notice == null) return;
    _notice = null;
    notifyListeners();
  }

  /// The session stream failed or closed: treat it as "nobody is signed in".
  void _onSessionLost([Object? error]) {
    if (error != null) {
      // The screen falls back to the login, so the reason has to survive
      // somewhere: without this the stream error would vanish without a trace.
      debugPrint('[AppSeries] canal de sessão falhou: $error');
    }
    final bool tinhaSessao = _state == SessionState.signedIn;
    _user = null;
    _state = SessionState.signedOut;
    if (tinhaSessao && !_signOutRequested) {
      _notice = const UnauthorizedError().mensagem;
    }
    // The reason a sign-out failed dies with the session it belonged to: the next
    // account must not open on a banner about someone else's logout.
    _signOutError = null;
    if (!_isSigningOut) _signOutRequested = false;
    notifyListeners();
  }

  void _onSessionChanged(AppUser? user) {
    final bool tinhaSessao = _state == SessionState.signedIn;
    // An event with the same person (a token refresh, say) is not a new session, so
    // it must not wipe anything she has not read yet.
    final bool userChanged = _user?.id != user?.id;
    _user = user;
    _state = user == null ? SessionState.signedOut : SessionState.signedIn;

    if (userChanged) {
      // A session that starts makes any previous warning old news, and the reason a
      // sign-out failed belonged to the old account: neither may reach the next one.
      // Clearing the warning here TOO — and not only on the screen, where the screen
      // also needs to clear it for a request that failed without changing the
      // session — is what covers a login screen that unmounts with the request in
      // flight and would otherwise leave the warning behind for the next visit.
      _notice = null;
      _signOutError = null;
    }
    // Going from signed in to signed out without her asking means the session was
    // taken away (the token expired and the next request got a 401, and the
    // interceptor signs out). She deserves the reason. It runs after the cleanup
    // above, so the warning of this very transition is not wiped in the same pass.
    if (user == null && tinhaSessao && !_signOutRequested) {
      _notice = const UnauthorizedError().mensagem;
    }
    // Only a finished sign-out disarms the flag: an event in the middle of one would
    // turn her own logout into "your session expired".
    if (!_isSigningOut) _signOutRequested = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
