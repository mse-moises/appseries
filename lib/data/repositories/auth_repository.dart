import '../../utils/result.dart';
import '../api_models/user.dart';

/// Contract for the account operations the app needs.
///
/// The View and the ViewModel depend on **this contract**, never on the
/// implementation (`constitution.md` §1).
abstract class AuthRepository {
  /// Who is signed in right now, and every change after that.
  Stream<AppUser?> get sessionStream;

  Future<Result<AppUser>> signIn(String email, String password);

  Future<Result<AppUser>> signUp(String email, String password);

  Future<Result<AppUser>> signInWithGoogle();

  Future<Result<void>> signOut();
}
