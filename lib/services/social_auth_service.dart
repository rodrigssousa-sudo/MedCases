// MEDCASES_LOGIN_V3_GOOGLE_APPLE_PERSISTENT_SESSION_MODERN_UI_V1_B_R0
//
// Provider-specific authentication only.
// Account/profile/session convergence remains owned by AuthService.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'auth_service.dart';

class SocialAuthService {
  SocialAuthService._();

  static const String cancelledResultCode = '__SOCIAL_AUTH_CANCELLED__';

  static Future<AuthResult> signInWithGoogle({
    required bool isEs,
  }) async {
    try {
      UserCredential credential;

      if (kIsWeb) {
        final provider = GoogleAuthProvider()
          ..addScope('email')
          ..addScope('profile');
        credential = await FirebaseAuth.instance.signInWithPopup(provider);
      } else {
        final googleSignIn = GoogleSignIn(
          scopes: const <String>['email', 'profile'],
        );
        final GoogleSignInAccount? account = await googleSignIn.signIn();
        if (account == null) {
          return AuthResult.error(cancelledResultCode);
        }

        final GoogleSignInAuthentication googleAuth =
            await account.authentication;

        final oauthCredential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        credential =
            await FirebaseAuth.instance.signInWithCredential(oauthCredential);
      }

      return AuthService.completeSocialSignIn(
        credential: credential,
        provider: 'google',
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(
        _firebaseMessage(e, isEs: isEs, provider: 'Google'),
      );
    } catch (_) {
      return AuthResult.error(
        isEs
            ? 'No fue posible iniciar sesión con Google. Inténtalo nuevamente.'
            : 'Não foi possível entrar com Google. Tente novamente.',
      );
    }
  }

  static Future<AuthResult> signInWithApple({
    required bool isEs,
  }) async {
    try {
      final provider = AppleAuthProvider()
        ..addScope('email')
        ..addScope('name');

      final UserCredential credential = kIsWeb
          ? await FirebaseAuth.instance.signInWithPopup(provider)
          : await FirebaseAuth.instance.signInWithProvider(provider);

      return AuthService.completeSocialSignIn(
        credential: credential,
        provider: 'apple',
      );
    } on FirebaseAuthException catch (e) {
      if (_isCancellation(e.code)) {
        return AuthResult.error(cancelledResultCode);
      }
      return AuthResult.error(
        _firebaseMessage(e, isEs: isEs, provider: 'Apple'),
      );
    } catch (_) {
      return AuthResult.error(
        isEs
            ? 'No fue posible iniciar sesión con Apple. Inténtalo nuevamente.'
            : 'Não foi possível entrar com Apple. Tente novamente.',
      );
    }
  }

  static bool _isCancellation(String code) {
    return code == 'web-context-canceled' ||
        code == 'popup-closed-by-user' ||
        code == 'canceled' ||
        code == 'cancelled';
  }

  static String _firebaseMessage(
    FirebaseAuthException e, {
    required bool isEs,
    required String provider,
  }) {
    if (_isCancellation(e.code)) {
      return cancelledResultCode;
    }

    switch (e.code) {
      case 'operation-not-allowed':
        return isEs
            ? 'El acceso con $provider aún no está habilitado en Firebase.'
            : 'O acesso com $provider ainda não está habilitado no Firebase.';
      case 'account-exists-with-different-credential':
      case 'credential-already-in-use':
        return isEs
            ? 'Este correo ya está vinculado a otro método de acceso. Entra con el método original y vuelve a intentarlo.'
            : 'Este e-mail já está vinculado a outro método de acesso. Entre pelo método original e tente novamente.';
      case 'network-request-failed':
        return isEs
            ? 'Sin conexión. Verifica internet e inténtalo nuevamente.'
            : 'Sem conexão. Verifique a internet e tente novamente.';
      case 'popup-blocked':
        return isEs
            ? 'El navegador bloqueó la ventana de acceso. Permite pop-ups e inténtalo nuevamente.'
            : 'O navegador bloqueou a janela de acesso. Permita pop-ups e tente novamente.';
      default:
        return isEs
            ? 'No fue posible iniciar sesión con $provider. Inténtalo nuevamente.'
            : 'Não foi possível entrar com $provider. Tente novamente.';
    }
  }
}
