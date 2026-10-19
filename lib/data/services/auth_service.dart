import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import '../api_models/user.dart';

/// Access to Firebase Auth, the app's identity provider.
///
/// A Service is the boundary with the outside world and holds **no state**
/// (`constitution.md` §1). Everything above it (repository, ViewModel, View)
/// knows only [AppUser], so no Firebase type leaks into the app — and the
/// repository can be tested with a double of this contract.
abstract class AuthService {
  /// Emits on every sign-in/sign-out, starting with the current state.
  Stream<AppUser?> get sessionStream;

  Future<AppUser> signIn(String email, String password);

  Future<AppUser> signUp(String email, String password);

  /// Google sign-in. On Android it borrows the account picker from the Google
  /// SDK and trades its id token for a Firebase session; on web the flow is a
  /// popup driven by the Firebase SDK (the Google SDK requires *its own* button
  /// on web, so `google_sign_in` is not used there).
  Future<AppUser> signInWithGoogle();

  Future<void> signOut();

  /// The Firebase id token, asked for **every request** (the SDK caches it and
  /// refreshes it on its own). The Dio interceptor is the only reader.
  Future<String?> idToken();
}

class FirebaseAuthService implements AuthService {
  FirebaseAuthService([FirebaseAuth? auth]) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  Stream<AppUser?> get sessionStream => _auth.authStateChanges().map(_toUser);

  @override
  Future<AppUser> signIn(String email, String password) async {
    final UserCredential credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return _toUser(credential.user)!;
  }

  @override
  Future<AppUser> signUp(String email, String password) async {
    final UserCredential credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return _toUser(credential.user)!;
  }

  @override
  Future<void> signOut() async {
    // The Google session outlives the Firebase one. Without this, the next
    // `authenticate()` reuses the account that just "left" (shared device), and
    // the SDK's own docs say not to authenticate again before a sign-out.
    // Initialized lazily so a session restored after the app was killed still
    // signs the Google SDK out.
    if (!kIsWeb) {
      try {
        await _ensureGoogleInitialized();
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // A failed Google sign-out must not keep the Firebase session alive.
      }
    }
    await _auth.signOut();
  }

  /// `GoogleSignIn.initialize` must run exactly once per process, before any
  /// other call on the instance: the future is cached so concurrent taps share
  /// it. A failed initialization is NOT memoized — the next tap retries.
  Future<void>? _googleInitialized;

  Future<void> _ensureGoogleInitialized() async {
    final Future<void>? pending = _googleInitialized;
    if (pending != null) {
      await pending;
      return;
    }

    final Future<void> init = GoogleSignIn.instance.initialize();
    _googleInitialized = init;
    try {
      await init;
    } catch (_) {
      _googleInitialized = null;
      rethrow;
    }
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    final UserCredential credential = kIsWeb
        ? await _auth.signInWithPopup(GoogleAuthProvider())
        : await _auth.signInWithCredential(await _googleCredential());
    return _toUser(credential.user)!;
  }

  Future<OAuthCredential> _googleCredential() async {
    final GoogleSignIn google = GoogleSignIn.instance;
    await _ensureGoogleInitialized();

    final GoogleSignInAccount account = await google.authenticate();
    final String? idToken = account.authentication.idToken;
    if (idToken == null) {
      // Without an id token Firebase has nothing to trade: reported as a Google
      // failure so the error mapper tells the person what happened, instead of
      // the generic "server slipped" a raw exception would earn.
      throw const GoogleSignInException(
        code: GoogleSignInExceptionCode.unknownError,
        description: 'authenticate() returned no id token',
      );
    }
    return GoogleAuthProvider.credential(idToken: idToken);
  }

  @override
  Future<String?> idToken() async {
    final User? user = _auth.currentUser;
    return user?.getIdToken();
  }
}

AppUser? _toUser(User? user) =>
    user == null ? null : AppUser(id: user.uid, email: user.email);
