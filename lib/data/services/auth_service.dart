import 'package:firebase_auth/firebase_auth.dart';

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
  Future<void> signOut() => _auth.signOut();

  @override
  Future<String?> idToken() async {
    final User? user = _auth.currentUser;
    return user?.getIdToken();
  }
}

AppUser? _toUser(User? user) =>
    user == null ? null : AppUser(id: user.uid, email: user.email);
