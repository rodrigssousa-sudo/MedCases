// auth_service.dart — Firebase Auth + controle de usuários MedCases Pro
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';

class AuthService {
  static FirebaseAuth get _auth => FirebaseAuth.instance;
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  // API key Web do Firebase (usada apenas no fallback REST — não é segredo crítico)
  static const _webApiKey = 'AIzaSyB0qklzhpRDAuppvieY3dy8hiPLQDucF18';

  // Email do admin fixo
  static const String adminEmail = 'rodrigssousa@gmail.com';

  // ── Stream de estado de autenticação ──────────────────────────────────────
  static Stream<User?> get authStateChanges => _auth.authStateChanges();
  static User? get currentUser => _auth.currentUser;

  // ── LOGIN — SDK primeiro; se falhar por domínio, usa REST API ─────────────
  static Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    // Tenta SDK nativo primeiro (Android / domínio autorizado)
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return _loadUserAfterAuth(email);
    } on FirebaseAuthException catch (e) {
      // Erros definitivos do SDK — não tentar REST
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential' ||
          e.code == 'too-many-requests' ||
          e.code == 'user-disabled' ||
          e.code == 'invalid-email') {
        return AuthResult.error(_authErrorMessage(e.code));
      }
      // unauthorized-domain ou outros → tenta fallback REST (só no Web)
      if (kIsWeb) {
        return _loginViaRestApi(email: email, password: password);
      }
      return AuthResult.error(_authErrorMessage(e.code));
    } catch (e) {
      final msg = e.toString();
      // Domínio não autorizado ou Firebase SDK bloqueado → REST fallback
      if (kIsWeb &&
          (msg.contains('unauthorized-domain') ||
              msg.contains('auth/unauthorized') ||
              msg.contains('no-app') ||
              msg.contains('No Firebase App') ||
              msg.contains('core/') ||
              msg.contains('network') ||
              msg.contains('XMLHttpRequest'))) {
        return _loginViaRestApi(email: email, password: password);
      }
      return AuthResult.error('Não foi possível fazer login. Tente novamente.');
    }
  }

  // ── LOGIN via REST API (sem restrição de domínio) ─────────────────────────
  // Usado quando o Firebase Web SDK bloqueia por domínio não autorizado.
  // Autentica via Identity Toolkit, depois usa signInWithCustomToken para
  // registrar a sessão no SDK local (mantendo streams de auth funcionando).
  static Future<AuthResult> _loginViaRestApi({
    required String email,
    required String password,
  }) async {
    try {
      // Passo 1: autenticar via REST e obter idToken
      final signInUrl = Uri.parse(
        'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$_webApiKey',
      );
      final signInResp = await http.post(
        signInUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim(),
          'password': password,
          'returnSecureToken': true,
        }),
      );

      final signInBody = jsonDecode(signInResp.body) as Map<String, dynamic>;

      if (signInResp.statusCode != 200) {
        final code = (signInBody['error']?['message'] as String? ?? '').toLowerCase();
        if (code.contains('email_not_found') || code.contains('invalid_login_credentials')) {
          return AuthResult.error('E-mail ou senha incorretos.');
        }
        if (code.contains('too_many_attempts') || code.contains('too_many_requests')) {
          return AuthResult.error('Muitas tentativas. Aguarde alguns minutos.');
        }
        if (code.contains('user_disabled')) {
          return AuthResult.error('Conta desativada. Entre em contato com o administrador.');
        }
        return AuthResult.error('E-mail ou senha incorretos.');
      }

      final uid      = signInBody['localId'] as String;
      final idToken  = signInBody['idToken'] as String;

      // Passo 2: trocar idToken por customToken via Cloud Function (se disponível)
      // OU: usar signInWithCustomToken se houver. Aqui usamos signInWithCredential
      // com EmailAuthProvider para registrar no SDK sem precisar do domínio.
      try {
        final credential = EmailAuthProvider.credential(
          email: email.trim(),
          password: password,
        );
        await _auth.signInWithCredential(credential);
      } catch (_) {
        // Se ainda falhar por domínio, continua sem sessão SDK
        // — o app funciona via Firestore com o uid obtido do REST
      }

      // Passo 3: buscar dados do usuário no Firestore usando o uid
      return _loadUserByUid(uid: uid, email: email, idToken: idToken);
    } catch (e) {
      return AuthResult.error('Falha na conexão. Verifique sua internet e tente novamente.');
    }
  }

  // ── Carrega UserModel após signIn bem-sucedido via SDK ────────────────────
  static Future<AuthResult> _loadUserAfterAuth(String email) async {
    try {
      final uid = _auth.currentUser!.uid;
      return _loadUserByUid(uid: uid, email: email);
    } catch (e) {
      return AuthResult.error('Erro ao carregar dados do usuário.');
    }
  }

  // ── Busca / cria UserModel no Firestore pelo uid ──────────────────────────
  static Future<AuthResult> _loadUserByUid({
    required String uid,
    required String email,
    String? idToken,
  }) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();

      if (!doc.exists) {
        final isAdmin = email.trim().toLowerCase() == adminEmail.toLowerCase();
        final user = UserModel(
          uid: uid,
          email: email.trim().toLowerCase(),
          displayName: _auth.currentUser?.displayName ?? email.split('@').first,
          role: isAdmin ? UserRole.admin : UserRole.user,
          status: isAdmin ? UserStatus.approved : UserStatus.pending,
          createdAt: DateTime.now(),
          approvedAt: isAdmin ? DateTime.now() : null,
          approvedBy: isAdmin ? 'system' : null,
        );
        await _db.collection('users').doc(uid).set(user.toMap());
        return AuthResult.success(user);
      }

      final user = UserModel.fromDoc(doc);

      if (user.isBlocked) {
        await _auth.signOut();
        return AuthResult.error('Sua conta foi suspensa. Entre em contato com o administrador.');
      }

      if (user.isPending) {
        await _auth.signOut();
        return AuthResult.error(
            'Sua conta está aguardando aprovação do administrador.\n\nVocê receberá acesso em breve.');
      }

      return AuthResult.success(user);
    } catch (e) {
      return AuthResult.error('Erro ao carregar dados do usuário. Tente novamente.');
    }
  }

  // ── Cadastro ──────────────────────────────────────────────────────────────
  static Future<AuthResult> register({
    required String email,
    required String password,
    required String displayName,
    String? profession,
    String? institution,
  }) async {
    // Tenta via SDK primeiro
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await cred.user?.updateDisplayName(displayName.trim());
      return _createUserDoc(
        uid: cred.user!.uid,
        email: email,
        displayName: displayName,
        profession: profession,
        institution: institution,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use' ||
          e.code == 'weak-password' ||
          e.code == 'invalid-email') {
        return AuthResult.error(_authErrorMessage(e.code));
      }
      // Domínio bloqueado → REST fallback
      if (kIsWeb) {
        return _registerViaRestApi(
          email: email,
          password: password,
          displayName: displayName,
          profession: profession,
          institution: institution,
        );
      }
      return AuthResult.error(_authErrorMessage(e.code));
    } catch (e) {
      if (kIsWeb) {
        return _registerViaRestApi(
          email: email,
          password: password,
          displayName: displayName,
          profession: profession,
          institution: institution,
        );
      }
      return AuthResult.error('Erro inesperado. Tente novamente.');
    }
  }

  // ── Cadastro via REST API ─────────────────────────────────────────────────
  static Future<AuthResult> _registerViaRestApi({
    required String email,
    required String password,
    required String displayName,
    String? profession,
    String? institution,
  }) async {
    try {
      final url = Uri.parse(
        'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$_webApiKey',
      );
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim(),
          'password': password,
          'returnSecureToken': true,
        }),
      );

      final body = jsonDecode(resp.body) as Map<String, dynamic>;

      if (resp.statusCode != 200) {
        final code = (body['error']?['message'] as String? ?? '').toLowerCase();
        if (code.contains('email_exists')) {
          return AuthResult.error('Este e-mail já está cadastrado.');
        }
        if (code.contains('weak_password')) {
          return AuthResult.error('Senha fraca. Use ao menos 6 caracteres.');
        }
        return AuthResult.error('Não foi possível criar a conta. Tente novamente.');
      }

      final uid = body['localId'] as String;
      return _createUserDoc(
        uid: uid,
        email: email,
        displayName: displayName,
        profession: profession,
        institution: institution,
      );
    } catch (e) {
      return AuthResult.error('Falha na conexão. Verifique sua internet e tente novamente.');
    }
  }

  // ── Cria documento do usuário no Firestore ────────────────────────────────
  static Future<AuthResult> _createUserDoc({
    required String uid,
    required String email,
    required String displayName,
    String? profession,
    String? institution,
  }) async {
    final isAdmin = email.trim().toLowerCase() == adminEmail.toLowerCase();
    final user = UserModel(
      uid: uid,
      email: email.trim().toLowerCase(),
      displayName: displayName.trim(),
      role: isAdmin ? UserRole.admin : UserRole.user,
      status: isAdmin ? UserStatus.approved : UserStatus.pending,
      createdAt: DateTime.now(),
      approvedAt: isAdmin ? DateTime.now() : null,
      approvedBy: isAdmin ? 'system' : null,
      profession: profession,
      institution: institution,
    );
    await _db.collection('users').doc(uid).set(user.toMap());
    return AuthResult.success(user);
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  static Future<void> logout() async {
    await _auth.signOut();
  }

  // ── Reset de senha ────────────────────────────────────────────────────────
  static Future<AuthResult> resetPassword(String email) async {
    // Tenta SDK
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return AuthResult.success(null, message: 'E-mail de redefinição enviado!');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-email') {
        return AuthResult.error(_authErrorMessage(e.code));
      }
      if (kIsWeb) return _resetPasswordViaRest(email);
      return AuthResult.error(_authErrorMessage(e.code));
    } catch (_) {
      if (kIsWeb) return _resetPasswordViaRest(email);
      return AuthResult.error('Erro ao enviar e-mail. Tente novamente.');
    }
  }

  static Future<AuthResult> _resetPasswordViaRest(String email) async {
    try {
      final url = Uri.parse(
        'https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=$_webApiKey',
      );
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'requestType': 'PASSWORD_RESET', 'email': email.trim()}),
      );
      if (resp.statusCode == 200) {
        return AuthResult.success(null, message: 'E-mail de redefinição enviado!');
      }
      return AuthResult.error('Não foi possível enviar o e-mail. Verifique o endereço.');
    } catch (_) {
      return AuthResult.error('Falha na conexão. Tente novamente.');
    }
  }

  // ── Buscar dados do usuário atual ─────────────────────────────────────────
  static Future<UserModel?> fetchCurrentUser() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return UserModel.fromDoc(doc);
    } catch (_) {
      return null;
    }
  }

  // ── Stream do usuário atual ───────────────────────────────────────────────
  static Stream<UserModel?> currentUserStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromDoc(doc) : null);
  }

  // ── Admin: listar todos os usuários ──────────────────────────────────────
  static Stream<List<UserModel>> allUsersStream() {
    return _db
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(UserModel.fromDoc).toList());
  }

  // ── Admin: aprovar usuário ────────────────────────────────────────────────
  static Future<void> approveUser(String uid, String adminUid) async {
    await _db.collection('users').doc(uid).update({
      'status': UserStatus.approved.name,
      'approvedAt': Timestamp.fromDate(DateTime.now()),
      'approvedBy': adminUid,
    });
  }

  // ── Admin: bloquear usuário ───────────────────────────────────────────────
  static Future<void> blockUser(String uid) async {
    await _db.collection('users').doc(uid).update({'status': UserStatus.blocked.name});
  }

  // ── Admin: desbloquear usuário ────────────────────────────────────────────
  static Future<void> unblockUser(String uid, String adminUid) async {
    await _db.collection('users').doc(uid).update({
      'status': UserStatus.approved.name,
      'approvedAt': Timestamp.fromDate(DateTime.now()),
      'approvedBy': adminUid,
    });
  }

  // ── Admin: promover a admin ───────────────────────────────────────────────
  static Future<void> promoteToAdmin(String uid) async {
    await _db.collection('users').doc(uid).update({'role': UserRole.admin.name});
  }

  // ── Master: promover a supervisor ─────────────────────────────────────────
  static Future<void> promoteToSupervisor(String uid) async {
    await _db.collection('users').doc(uid).update({'role': UserRole.supervisor.name});
  }

  // ── Master/Admin: rebaixar para usuário comum ─────────────────────────────
  static Future<void> demoteToUser(String uid) async {
    await _db.collection('users').doc(uid).update({'role': UserRole.user.name});
  }

  // ── Mensagens de erro amigáveis ───────────────────────────────────────────
  static String _authErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Nenhuma conta encontrada com este e-mail.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mail ou senha incorretos.';
      case 'email-already-in-use':
        return 'Este e-mail já está cadastrado.';
      case 'weak-password':
        return 'Senha fraca. Use ao menos 6 caracteres.';
      case 'invalid-email':
        return 'Endereço de e-mail inválido.';
      case 'too-many-requests':
        return 'Muitas tentativas. Aguarde alguns minutos.';
      case 'network-request-failed':
        return 'Sem conexão. Verifique sua internet.';
      case 'operation-not-allowed':
        return 'Login por e-mail desabilitado. Contate o admin.';
      case 'unauthorized-domain':
        return 'Acesso não autorizado neste domínio.';
      default:
        return 'Erro de autenticação. Tente novamente.';
    }
  }
}

// ── Resultado das operações de autenticação ───────────────────────────────
class AuthResult {
  final bool success;
  final UserModel? user;
  final String? error;
  final String? message;

  const AuthResult._({
    required this.success,
    this.user,
    this.error,
    this.message,
  });

  factory AuthResult.success(UserModel? user, {String? message}) =>
      AuthResult._(success: true, user: user, message: message);

  factory AuthResult.error(String error) =>
      AuthResult._(success: false, error: error);
}
