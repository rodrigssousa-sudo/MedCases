// auth_service.dart — Firebase Auth + Firestore via REST (Web) e SDK (Android)
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart' show ValueNotifier;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';

class AuthService {
  static FirebaseAuth get _auth => FirebaseAuth.instance;
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static const _webApiKey    = 'AIzaSyB0qklzhpRDAuppvieY3dy8hiPLQDucF18';
  static const _projectId    = 'medcases-pro';
  static const _fsBase       = 'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents';
  static const String adminEmail = 'rodrigssousa@gmail.com';

  // ── Estado de autenticação Web (ValueNotifier) ─────────────────────────────
  // StreamController broadcast perde eventos emitidos antes do subscriber
  // existir. ValueNotifier persiste o último valor — qualquer widget que
  // subscrever depois ainda recebe o estado atual imediatamente.
  static final ValueNotifier<UserModel?> webUser = ValueNotifier<UserModel?>(null);

  // ── Stream de estado de autenticação (usado no Android via SDK nativo) ────
  static Stream<User?> get authStateChanges => _auth.authStateChanges();
  static User? get currentUser => _auth.currentUser;

  // ═══════════════════════════════════════════════════════════════════════════
  // LOGIN
  // ═══════════════════════════════════════════════════════════════════════════
  static Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    if (kIsWeb) {
      // Web: sempre via REST para evitar bloqueio de domínio
      return _loginWeb(email: email, password: password);
    }
    // Android / iOS: SDK nativo
    return _loginNative(email: email, password: password);
  }

  // ── Login nativo (Android) ─────────────────────────────────────────────────
  static Future<AuthResult> _loginNative({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = _auth.currentUser!.uid;
      final doc = await _db.collection('users').doc(uid).get();
      return _buildResultFromDoc(
        exists: doc.exists,
        data: doc.exists ? (doc.data() ?? {}) : {},
        uid: uid,
        email: email,
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_authErrorMessage(e.code));
    } catch (e) {
      return AuthResult.error('Não foi possível fazer login. Tente novamente.');
    }
  }

  // ── Login Web via REST ─────────────────────────────────────────────────────
  static Future<AuthResult> _loginWeb({
    required String email,
    required String password,
  }) async {
    try {
      // Passo 1 — Auth REST
      final authResp = await http.post(
        Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$_webApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim(), 'password': password, 'returnSecureToken': true}),
      );
      final authBody = jsonDecode(authResp.body) as Map<String, dynamic>;

      if (authResp.statusCode != 200) {
        final msg = ((authBody['error']?['message'] as String?) ?? '').toUpperCase();
        if (msg.contains('EMAIL_NOT_FOUND') || msg.contains('INVALID_LOGIN_CREDENTIALS') ||
            msg.contains('WRONG_PASSWORD') || msg.contains('INVALID_PASSWORD')) {
          return AuthResult.error('E-mail ou senha incorretos.');
        }
        if (msg.contains('TOO_MANY_ATTEMPTS') || msg.contains('TOO_MANY_REQUESTS')) {
          return AuthResult.error('Muitas tentativas. Aguarde alguns minutos.');
        }
        if (msg.contains('USER_DISABLED')) {
          return AuthResult.error('Conta desativada. Entre em contato com o administrador.');
        }
        return AuthResult.error('E-mail ou senha incorretos.');
      }

      final uid     = authBody['localId'] as String;
      final idToken = authBody['idToken']  as String;

      // Passo 2 — Firestore REST: ler documento users/{uid}
      final fsResp = await http.get(
        Uri.parse('$_fsBase/users/$uid'),
        headers: {'Authorization': 'Bearer $idToken'},
      );

      if (fsResp.statusCode == 404) {
        // Usuário existe no Auth mas não no Firestore — criar documento
        final user = _buildNewUser(uid: uid, email: email);
        await _createUserDocRest(user: user, idToken: idToken);
        // Atualiza ValueNotifier ANTES de retornar
        webUser.value = user;
        return AuthResult.success(user);
      }

      if (fsResp.statusCode != 200) {
        return AuthResult.error('Erro ao carregar perfil. Tente novamente.');
      }

      final fsBody = jsonDecode(fsResp.body) as Map<String, dynamic>;
      final data   = _firestoreDocToMap(fsBody);

      final result = _buildResultFromDoc(exists: true, data: data, uid: uid, email: email);

      // ✅ CRITICAL FIX: publica no ValueNotifier para QUALQUER usuário autenticado
      // (approved, pending, blocked) — _buildWebAuthGate decide qual tela mostrar.
      // Antes só publicava se result.success → pending/blocked ficavam travados na
      // LoginScreen porque webUser.value permanecia null.
      if (result.user != null) {
        webUser.value = result.user;
      }

      return result;
    } catch (e) {
      return AuthResult.error('Falha na conexão. Verifique sua internet e tente novamente.');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CADASTRO
  // ═══════════════════════════════════════════════════════════════════════════
  static Future<AuthResult> register({
    required String email,
    required String password,
    required String displayName,
    String? profession,
    String? institution,
  }) async {
    if (kIsWeb) {
      return _registerWeb(
        email: email, password: password, displayName: displayName,
        profession: profession, institution: institution,
      );
    }
    return _registerNative(
      email: email, password: password, displayName: displayName,
      profession: profession, institution: institution,
    );
  }

  static Future<AuthResult> _registerNative({
    required String email, required String password,
    required String displayName, String? profession, String? institution,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(), password: password,
      );
      await cred.user?.updateDisplayName(displayName.trim());
      final user = _buildNewUser(
        uid: cred.user!.uid, email: email,
        displayName: displayName, profession: profession, institution: institution,
      );
      await _db.collection('users').doc(user.uid).set(user.toMap());
      return AuthResult.success(user);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_authErrorMessage(e.code));
    } catch (e) {
      return AuthResult.error('Erro inesperado. Tente novamente.');
    }
  }

  static Future<AuthResult> _registerWeb({
    required String email, required String password,
    required String displayName, String? profession, String? institution,
  }) async {
    try {
      final resp = await http.post(
        Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$_webApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim(), 'password': password, 'returnSecureToken': true}),
      );
      final body = jsonDecode(resp.body) as Map<String, dynamic>;

      if (resp.statusCode != 200) {
        final msg = ((body['error']?['message'] as String?) ?? '').toUpperCase();
        if (msg.contains('EMAIL_EXISTS')) return AuthResult.error('Este e-mail já está cadastrado.');
        if (msg.contains('WEAK_PASSWORD'))  return AuthResult.error('Senha fraca. Use ao menos 6 caracteres.');
        return AuthResult.error('Não foi possível criar a conta. Tente novamente.');
      }

      final uid     = body['localId'] as String;
      final idToken = body['idToken']  as String;
      final user    = _buildNewUser(
        uid: uid, email: email, displayName: displayName,
        profession: profession, institution: institution,
      );
      await _createUserDocRest(user: user, idToken: idToken);
      // Atualiza ValueNotifier (usuário recém-criado via REST)
      webUser.value = user;
      return AuthResult.success(user);
    } catch (e) {
      return AuthResult.error('Falha na conexão. Verifique sua internet e tente novamente.');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RESET DE SENHA
  // ═══════════════════════════════════════════════════════════════════════════
  static Future<AuthResult> resetPassword(String email) async {
    if (kIsWeb) return _resetPasswordWeb(email);
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return AuthResult.success(null, message: 'E-mail de redefinição enviado!');
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_authErrorMessage(e.code));
    }
  }

  static Future<AuthResult> _resetPasswordWeb(String email) async {
    try {
      final resp = await http.post(
        Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=$_webApiKey'),
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

  // ═══════════════════════════════════════════════════════════════════════════
  // LOGOUT
  // ═══════════════════════════════════════════════════════════════════════════
  static Future<void> logout() async {
    // Limpa o ValueNotifier Web PRIMEIRO (antes do signOut)
    if (kIsWeb) {
      webUser.value = null;
    }
    try { await _auth.signOut(); } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STREAMS — usados pelo _AuthGate (Android / Web com SDK OK)
  // ═══════════════════════════════════════════════════════════════════════════
  static Future<UserModel?> fetchCurrentUser() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return UserModel.fromDoc(doc);
    } catch (_) { return null; }
  }

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

  static Future<void> approveUser(String uid, String adminUid) async {
    await _db.collection('users').doc(uid).update({
      'status': UserStatus.approved.name,
      'approvedAt': Timestamp.fromDate(DateTime.now()),
      'approvedBy': adminUid,
    });
  }

  static Future<void> blockUser(String uid) async {
    await _db.collection('users').doc(uid).update({'status': UserStatus.blocked.name});
  }

  static Future<void> unblockUser(String uid, String adminUid) async {
    await _db.collection('users').doc(uid).update({
      'status': UserStatus.approved.name,
      'approvedAt': Timestamp.fromDate(DateTime.now()),
      'approvedBy': adminUid,
    });
  }

  static Future<void> promoteToAdmin(String uid) async {
    await _db.collection('users').doc(uid).update({'role': UserRole.admin.name});
  }

  static Future<void> promoteToSupervisor(String uid) async {
    await _db.collection('users').doc(uid).update({'role': UserRole.supervisor.name});
  }

  static Future<void> demoteToUser(String uid) async {
    await _db.collection('users').doc(uid).update({'role': UserRole.user.name});
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS INTERNOS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Cria um UserModel novo com as permissões corretas
  static UserModel _buildNewUser({
    required String uid,
    required String email,
    String? displayName,
    String? profession,
    String? institution,
  }) {
    final isAdmin = email.trim().toLowerCase() == adminEmail.toLowerCase();
    return UserModel(
      uid: uid,
      email: email.trim().toLowerCase(),
      displayName: displayName?.trim() ?? email.split('@').first,
      role: isAdmin ? UserRole.admin : UserRole.user,
      status: isAdmin ? UserStatus.approved : UserStatus.pending,
      createdAt: DateTime.now(),
      approvedAt: isAdmin ? DateTime.now() : null,
      approvedBy: isAdmin ? 'system' : null,
      profession: profession,
      institution: institution,
    );
  }

  /// Monta AuthResult a partir de um Map de campos Firestore.
  ///
  /// IMPORTANTE: sempre retorna o [user] no resultado, independente do status
  /// (approved, pending, blocked). Isso permite que o ValueNotifier webUser
  /// seja populado e o _buildWebAuthGate decida qual tela exibir.
  /// A distinção de tela fica 100% no _AuthGate — não aqui.
  static AuthResult _buildResultFromDoc({
    required bool exists,
    required Map<String, dynamic> data,
    required String uid,
    required String email,
  }) {
    if (!exists || data.isEmpty) {
      // Cria registro local sem ir ao Firestore (será criado pelo SDK/REST já chamado antes)
      final user = _buildNewUser(uid: uid, email: email);
      return AuthResult.success(user);
    }

    final user = UserModel.fromMap(data);

    // Sempre retorna success com o user — o _AuthGate filtra isBlocked / isPending.
    // Retornar error sem user impede webUser.value de ser setado e o _AuthGate
    // fica preso na LoginScreen para usuários pending/blocked.
    return AuthResult.success(user);
  }

  /// Cria documento de usuário no Firestore via REST (Web)
  static Future<void> _createUserDocRest({
    required UserModel user,
    required String idToken,
  }) async {
    try {
      final fields = <String, dynamic>{};
      final m = user.toMap();
      // Converter para formato Firestore REST
      m.forEach((k, v) {
        if (v == null) {
          fields[k] = {'nullValue': null};
        } else if (v is bool) {
          fields[k] = {'booleanValue': v};
        } else if (v is int) {
          fields[k] = {'integerValue': v.toString()};
        } else if (v is double) {
          fields[k] = {'doubleValue': v};
        } else if (v is Timestamp) {
          fields[k] = {'timestampValue': v.toDate().toUtc().toIso8601String()};
        } else {
          fields[k] = {'stringValue': v.toString()};
        }
      });

      await http.patch(
        Uri.parse('$_fsBase/users/${user.uid}'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'fields': fields}),
      );
    } catch (_) {
      // Falha silenciosa — o SDK vai tentar criar depois quando o domínio for autorizado
    }
  }

  /// Converte resposta REST do Firestore para Map<String, dynamic> compatível com UserModel.fromMap
  static Map<String, dynamic> _firestoreDocToMap(Map<String, dynamic> doc) {
    final fields = doc['fields'] as Map<String, dynamic>? ?? {};
    final result = <String, dynamic>{};

    fields.forEach((key, value) {
      final v = value as Map<String, dynamic>;
      if (v.containsKey('stringValue'))    result[key] = v['stringValue'];
      else if (v.containsKey('booleanValue')) result[key] = v['booleanValue'];
      else if (v.containsKey('integerValue')) result[key] = int.tryParse(v['integerValue'].toString());
      else if (v.containsKey('doubleValue'))  result[key] = v['doubleValue'];
      else if (v.containsKey('timestampValue')) {
        // Converte para Timestamp do Firestore SDK
        result[key] = Timestamp.fromDate(DateTime.parse(v['timestampValue'] as String));
      }
      else if (v.containsKey('nullValue'))  result[key] = null;
      else result[key] = null;
    });

    return result;
  }

  // ── Mensagens de erro amigáveis ───────────────────────────────────────────
  static String _authErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':        return 'Nenhuma conta encontrada com este e-mail.';
      case 'wrong-password':
      case 'invalid-credential':    return 'E-mail ou senha incorretos.';
      case 'email-already-in-use':  return 'Este e-mail já está cadastrado.';
      case 'weak-password':         return 'Senha fraca. Use ao menos 6 caracteres.';
      case 'invalid-email':         return 'Endereço de e-mail inválido.';
      case 'too-many-requests':     return 'Muitas tentativas. Aguarde alguns minutos.';
      case 'network-request-failed': return 'Sem conexão. Verifique sua internet.';
      case 'operation-not-allowed': return 'Login por e-mail desabilitado. Contate o admin.';
      case 'user-disabled':         return 'Conta desativada. Entre em contato com o administrador.';
      default: return 'Erro de autenticação. Tente novamente.';
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
