// auth_service.dart — Firebase Auth + controle de usuários MedCases Pro
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Email do admin fixo — será promovido automaticamente no primeiro login
  static const String adminEmail = 'rodrigssousa@gmail.com'; // ← seu email

  // ── Stream de estado de autenticação ──────────────────────────────────────
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  static User? get currentUser => _auth.currentUser;

  // ── Cadastro ──────────────────────────────────────────────────────────────
  static Future<AuthResult> register({
    required String email,
    required String password,
    required String displayName,
    String? profession,
    String? institution,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await cred.user?.updateDisplayName(displayName.trim());

      final isAdmin = email.trim().toLowerCase() == adminEmail.toLowerCase();

      final user = UserModel(
        uid: cred.user!.uid,
        email: email.trim().toLowerCase(),
        displayName: displayName.trim(),
        role: isAdmin ? UserRole.admin : UserRole.user,
        // Admin é aprovado automaticamente; outros ficam pendentes
        status: isAdmin ? UserStatus.approved : UserStatus.pending,
        createdAt: DateTime.now(),
        approvedAt: isAdmin ? DateTime.now() : null,
        approvedBy: isAdmin ? 'system' : null,
        profession: profession,
        institution: institution,
      );

      await _db.collection('users').doc(user.uid).set(user.toMap());

      return AuthResult.success(user);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_authErrorMessage(e.code));
    } catch (e) {
      return AuthResult.error('Erro inesperado. Tente novamente.');
    }
  }

  // ── Login ─────────────────────────────────────────────────────────────────
  static Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final doc = await _db
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .get();

      if (!doc.exists) {
        // Usuário existe no Auth mas não no Firestore — criar registro
        final isAdmin = email.trim().toLowerCase() == adminEmail.toLowerCase();
        final user = UserModel(
          uid: _auth.currentUser!.uid,
          email: email.trim().toLowerCase(),
          displayName: _auth.currentUser!.displayName ?? email.split('@').first,
          role: isAdmin ? UserRole.admin : UserRole.user,
          status: isAdmin ? UserStatus.approved : UserStatus.pending,
          createdAt: DateTime.now(),
          approvedAt: isAdmin ? DateTime.now() : null,
          approvedBy: isAdmin ? 'system' : null,
        );
        await _db.collection('users').doc(user.uid).set(user.toMap());
        return AuthResult.success(user);
      }

      final user = UserModel.fromDoc(doc);

      if (user.isBlocked) {
        await _auth.signOut();
        return AuthResult.error(
            'Sua conta foi suspensa. Entre em contato com o administrador.');
      }

      if (user.isPending) {
        await _auth.signOut();
        return AuthResult.error(
            'Sua conta está aguardando aprovação do administrador.\n\nVocê receberá acesso em breve.');
      }

      return AuthResult.success(user);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_authErrorMessage(e.code));
    } catch (e) {
      return AuthResult.error('Erro ao fazer login. Verifique sua conexão.');
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  static Future<void> logout() async {
    await _auth.signOut();
  }

  // ── Reset de senha ────────────────────────────────────────────────────────
  static Future<AuthResult> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return AuthResult.success(null, message: 'E-mail de redefinição enviado!');
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_authErrorMessage(e.code));
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
    await _db.collection('users').doc(uid).update({
      'status': UserStatus.blocked.name,
    });
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
    await _db.collection('users').doc(uid).update({
      'role': UserRole.admin.name,
    });
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
      default:
        return 'Erro de autenticação ($code). Tente novamente.';
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
