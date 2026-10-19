import 'package:appseries/data/api_models/user.dart';
import 'package:appseries/data/services/auth_service.dart';
import 'package:appseries/utils/app_error.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart' show MissingPluginException, PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart'
    show GoogleSignInException, GoogleSignInExceptionCode;
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart'
    show
        AuthenticateParameters,
        AuthenticationResults,
        AuthenticationTokenData,
        GoogleSignInPlatform,
        GoogleSignInUserData,
        InitParameters,
        SignOutParams;
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockUserCredential extends Mock implements UserCredential {}

class _MockUser extends Mock implements User {}

class _MockGoogleSignInPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements GoogleSignInPlatform {}

class _FakeInitParameters extends Fake implements InitParameters {}

class _FakeAuthenticateParameters extends Fake implements AuthenticateParameters {}

class _FakeSignOutParams extends Fake implements SignOutParams {}

class _FakeAuthCredential extends Fake implements AuthCredential {}

void main() {
  late _MockFirebaseAuth auth;
  late _MockGoogleSignInPlatform google;

  setUpAll(() {
    registerFallbackValue(_FakeInitParameters());
    registerFallbackValue(_FakeAuthenticateParameters());
    registerFallbackValue(_FakeSignOutParams());
    registerFallbackValue(_FakeAuthCredential());
  });

  setUp(() {
    auth = _MockFirebaseAuth();
    google = _MockGoogleSignInPlatform();
    GoogleSignInPlatform.instance = google;
    when(() => google.init(any())).thenAnswer((_) async {});
    when(() => google.signOut(any())).thenAnswer((_) async {});
  });

  _MockUserCredential credentialComUsuario() {
    final user = _MockUser();
    when(() => user.uid).thenReturn('u1');
    when(() => user.email).thenReturn('livia@exemplo.com');
    final credential = _MockUserCredential();
    when(() => credential.user).thenReturn(user);
    return credential;
  }

  void autenticaGoogle({String? idToken}) {
    when(() => google.authenticate(any())).thenAnswer(
      (_) async => AuthenticationResults(
        user: const GoogleSignInUserData(email: 'livia@exemplo.com', id: 'g1'),
        authenticationTokens: AuthenticationTokenData(idToken: idToken),
      ),
    );
  }

  group('FirebaseAuthService', () {
    test('signIn traduz a falha do Firebase na frase certa', () async {
      when(
        () => auth.signInWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(FirebaseAuthException(code: 'invalid-credential'));
      final service = FirebaseAuthService(auth);

      await expectLater(
        service.signIn('livia@exemplo.com', 'errada'),
        throwsA(isA<CredenciaisInvalidasError>()),
      );
    });

    test('signUp traduz e-mail já em uso', () async {
      when(
        () => auth.createUserWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(FirebaseAuthException(code: 'email-already-in-use'));
      final service = FirebaseAuthService(auth);

      await expectLater(
        service.signUp('livia@exemplo.com', 'segredo123'),
        throwsA(isA<EmailJaEmUsoError>()),
      );
    });

    test('signInWithGoogle inicializa, autentica e troca o token por sessão', () async {
      autenticaGoogle(idToken: 'token-do-google');
      when(() => auth.signInWithCredential(any())).thenAnswer(
        (_) async => credentialComUsuario(),
      );
      final service = FirebaseAuthService(auth);

      final AppUser user = await service.signInWithGoogle();

      expect(user.id, 'u1');
      expect(user.email, 'livia@exemplo.com');
      verify(() => google.init(any())).called(1);
      verify(() => google.authenticate(any())).called(1);
      verify(() => auth.signInWithCredential(any())).called(1);
    });

    test('authenticate sem id token vira falha do Google, sem tocar o Firebase', () async {
      autenticaGoogle(idToken: null);
      final service = FirebaseAuthService(auth);

      await expectLater(
        service.signInWithGoogle(),
        throwsA(isA<GoogleFalhouError>()),
      );
      verifyNever(() => auth.signInWithCredential(any()));
    });

    test('fechar o seletor vira frase de cancelamento', () async {
      when(() => google.authenticate(any())).thenThrow(
        const GoogleSignInException(code: GoogleSignInExceptionCode.canceled),
      );
      final service = FirebaseAuthService(auth);

      await expectLater(
        service.signInWithGoogle(),
        throwsA(isA<GoogleCanceladoError>()),
      );
    });

    test('sem implementação nativa, a falha de plataforma vira "não disponível"', () async {
      when(() => google.authenticate(any())).thenThrow(
        PlatformException(code: 'google_sign_in'),
      );
      final service = FirebaseAuthService(auth);

      await expectLater(
        service.signInWithGoogle(),
        throwsA(isA<GoogleIndisponivelError>()),
      );
    });

    test('plugin ausente também vira "não disponível"', () async {
      when(() => google.authenticate(any())).thenThrow(MissingPluginException());
      final service = FirebaseAuthService(auth);

      await expectLater(
        service.signInWithGoogle(),
        throwsA(isA<GoogleIndisponivelError>()),
      );
    });

    test('initialize roda uma vez por processo, mesmo com dois toques', () async {
      autenticaGoogle(idToken: 'token-do-google');
      when(() => auth.signInWithCredential(any())).thenAnswer(
        (_) async => credentialComUsuario(),
      );
      final service = FirebaseAuthService(auth);

      await service.signInWithGoogle();
      await service.signInWithGoogle();

      verify(() => google.init(any())).called(1);
    });

    test('initialize que falha é re-tentado na próxima tentativa', () async {
      when(() => google.init(any())).thenAnswer(
        (_) async => throw const GoogleSignInException(
          code: GoogleSignInExceptionCode.clientConfigurationError,
        ),
      );
      final service = FirebaseAuthService(auth);

      await expectLater(
        service.signInWithGoogle(),
        throwsA(isA<GoogleIndisponivelError>()),
      );

      // O tropeço não fica memoizado: a próxima tentativa inicializa de novo.
      when(() => google.init(any())).thenAnswer((_) async {});
      autenticaGoogle(idToken: 'token-do-google');
      when(() => auth.signInWithCredential(any())).thenAnswer(
        (_) async => credentialComUsuario(),
      );

      await service.signInWithGoogle();

      verify(() => google.init(any())).called(2);
    });

    test('signOut encerra a sessão do Google e a do Firebase', () async {
      when(() => auth.signOut()).thenAnswer((_) async {});
      final service = FirebaseAuthService(auth);

      await service.signOut();

      verify(() => google.signOut(any())).called(1);
      verify(() => auth.signOut()).called(1);
    });
  });
}
