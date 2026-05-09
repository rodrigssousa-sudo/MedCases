// auth_service.dart — Firebase Auth + Firestore via REST (Web) e SDK (nativo)
import 'dart:async';
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
  static final ValueNotifier<UserModel?> webUser = ValueNotifier<UserModel?>(null);

  // ── Cache de idToken para operações admin REST ─────────────────────────────
  // O idToken do Firebase expira em 1h. Armazenamos token + refreshToken +
  // timestamp para fazer refresh automático antes de cada chamada admin.
  static String _cachedIdToken    = '';
  static String _cachedRefreshTk  = '';
  static DateTime _tokenExpiresAt = DateTime(2000); // forçar refresh na primeira chamada

  // ── Stream de estado de autenticação (Android/iOS via SDK nativo) ──────────
  static Stream<User?> get authStateChanges => _auth.authStateChanges();
  static User? get currentUser => _auth.currentUser;

  // ═══════════════════════════════════════════════════════════════════════════
  // TOKEN ADMIN — cache + refresh automático
  // ═══════════════════════════════════════════════════════════════════════════

  /// Retorna um idToken válido para chamadas admin REST.
  /// - Se o token ainda não expirou, devolve o cache.
  /// - Se expirou (ou nunca foi setado), usa o refreshToken para obter novo token.
  /// - Margem de segurança de 5 min antes do vencimento real (55 min de vida útil).
  /// Público para que FirestoreService possa reutilizar o mesmo cache.
  static Future<String> getAdminToken() => _getAdminToken();

  static Future<String> _getAdminToken() async {
    final now = DateTime.now();
    if (_cachedIdToken.isNotEmpty && now.isBefore(_tokenExpiresAt)) {
      return _cachedIdToken;
    }
    // Precisa de refresh
    if (_cachedRefreshTk.isNotEmpty) {
      try {
        final resp = await http.post(
          Uri.parse('https://securetoken.googleapis.com/v1/token?key=$_webApiKey'),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: 'grant_type=refresh_token&refresh_token=$_cachedRefreshTk',
        );
        if (resp.statusCode == 200) {
          final body = jsonDecode(resp.body) as Map<String, dynamic>;
          _cachedIdToken   = body['id_token']      as String? ?? '';
          _cachedRefreshTk = body['refresh_token'] as String? ?? _cachedRefreshTk;
          // expires_in vem em segundos; subtraímos 5 min como margem
          final expiresIn  = int.tryParse(body['expires_in']?.toString() ?? '3600') ?? 3600;
          _tokenExpiresAt  = DateTime.now().add(Duration(seconds: expiresIn - 300));
          return _cachedIdToken;
        }
      } catch (_) {}
    }
    // Sem token válido — retorna vazio; a chamada vai falhar com 401
    return _cachedIdToken;
  }

  /// Armazena o par idToken + refreshToken após login/registro bem-sucedido.
  static void _cacheTokens({required String idToken, required String refreshToken}) {
    _cachedIdToken   = idToken;
    _cachedRefreshTk = refreshToken;
    // idToken do Firebase tem vida de 1h; guardamos 55 min para ter margem
    _tokenExpiresAt  = DateTime.now().add(const Duration(minutes: 55));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LOGIN
  // ═══════════════════════════════════════════════════════════════════════════
  static Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    if (kIsWeb) return _loginWeb(email: email, password: password);
    return _loginNative(email: email, password: password);
  }

  // ── Login nativo (Android / iOS) ───────────────────────────────────────────
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

      final uid          = authBody['localId']      as String;
      final idToken      = authBody['idToken']       as String;
      final refreshToken = authBody['refreshToken']  as String? ?? '';

      // Salva tokens em cache para uso posterior (operações admin REST)
      _cacheTokens(idToken: idToken, refreshToken: refreshToken);

      // Passo 2 — Firestore REST: ler documento users/{uid}
      final fsResp = await http.get(
        Uri.parse('$_fsBase/users/$uid'),
        headers: {'Authorization': 'Bearer $idToken'},
      );

      if (fsResp.statusCode == 404) {
        final user = _buildNewUser(uid: uid, email: email);
        await _createUserDocRest(user: user, idToken: idToken);
        webUser.value = user;
        return AuthResult.success(user);
      }

      if (fsResp.statusCode != 200) {
        return AuthResult.error('Erro ao carregar perfil. Tente novamente.');
      }

      final fsBody = jsonDecode(fsResp.body) as Map<String, dynamic>;
      final data   = _firestoreDocToMap(fsBody);
      final result = _buildResultFromDoc(exists: true, data: data, uid: uid, email: email);

      if (result.user != null) webUser.value = result.user;

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

      final uid          = body['localId']     as String;
      final idToken      = body['idToken']      as String;
      final refreshToken = body['refreshToken'] as String? ?? '';

      _cacheTokens(idToken: idToken, refreshToken: refreshToken);

      final user = _buildNewUser(
        uid: uid, email: email, displayName: displayName,
        profession: profession, institution: institution,
      );
      await _createUserDocRest(user: user, idToken: idToken);
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
    // Limpa tokens em cache
    _cachedIdToken   = '';
    _cachedRefreshTk = '';
    _tokenExpiresAt  = DateTime(2000);

    if (kIsWeb) webUser.value = null;
    try { await _auth.signOut(); } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STREAMS — SDK nativo (Android / iOS)
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

  // ═══════════════════════════════════════════════════════════════════════════
  // ADMIN — STREAM DE USUÁRIOS
  // ─────────────────────────────────────────────────────────────────────────
  // Web → REST polling a cada 8 s (sem WebSocket/SDK)
  // Nativo → SDK Firestore com snapshots() em tempo real
  // ═══════════════════════════════════════════════════════════════════════════

  /// Stream unificado: escolhe REST (web) ou SDK (nativo) automaticamente.
  static Stream<List<UserModel>> allUsersStream() {
    if (kIsWeb) return _allUsersStreamRest();
    return _db
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(UserModel.fromDoc).toList());
  }

  /// REST polling — busca até 500 usuários a cada 8 segundos.
  /// Usa runZonedGuarded internamente para capturar exceções async.
  static Stream<List<UserModel>> _allUsersStreamRest() {
    // StreamController com auto-cancel para não vazar quando não há listeners
    late StreamController<List<UserModel>> ctrl;
    Timer? timer;

    Future<void> fetch() async {
      try {
        final token = await _getAdminToken();
        if (token.isEmpty) return; // sem token, aguarda próximo ciclo

        // Firestore REST — listar coleção users com pageSize máximo
        final resp = await http.get(
          Uri.parse('$_fsBase/users?pageSize=500'),
          headers: {'Authorization': 'Bearer $token'},
        );

        if (resp.statusCode != 200) return;

        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final docs  = body['documents'] as List<dynamic>? ?? [];

        final users = <UserModel>[];
        for (final doc in docs) {
          try {
            final data = _firestoreDocToMap(doc as Map<String, dynamic>);
            // Extrair uid do name: "projects/.../documents/users/{uid}"
            final name = doc['name'] as String? ?? '';
            final uid  = name.split('/').last;
            data['uid'] = uid;
            users.add(UserModel.fromMap(data));
          } catch (_) {
            // pula documento com formato inesperado
          }
        }

        // Ordena por createdAt decrescente (equivalente ao orderBy SDK)
        users.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (!ctrl.isClosed) ctrl.add(users);
      } catch (_) {
        // falha silenciosa — tenta novamente no próximo ciclo
      }
    }

    ctrl = StreamController<List<UserModel>>(
      onListen: () {
        fetch(); // chamada imediata ao abrir o stream
        timer = Timer.periodic(const Duration(seconds: 8), (_) => fetch());
      },
      onCancel: () {
        timer?.cancel();
        timer = null;
      },
    );

    return ctrl.stream;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ADMIN — OPERAÇÕES DE GESTÃO DE USUÁRIOS
  // ─────────────────────────────────────────────────────────────────────────
  // Cada operação roteia para REST (web) ou SDK (nativo) automaticamente.
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> approveUser(String uid, String adminUid) async {
    if (kIsWeb) {
      await _patchUserRest(uid, {
        'status':     UserStatus.approved.name,
        'approvedAt': DateTime.now().toUtc().toIso8601String(),
        'approvedBy': adminUid,
      });
      return;
    }
    await _db.collection('users').doc(uid).update({
      'status':     UserStatus.approved.name,
      'approvedAt': Timestamp.fromDate(DateTime.now()),
      'approvedBy': adminUid,
    });
  }

  static Future<void> blockUser(String uid) async {
    if (kIsWeb) {
      await _patchUserRest(uid, {'status': UserStatus.blocked.name});
      return;
    }
    await _db.collection('users').doc(uid).update({'status': UserStatus.blocked.name});
  }

  static Future<void> unblockUser(String uid, String adminUid) async {
    if (kIsWeb) {
      await _patchUserRest(uid, {
        'status':     UserStatus.approved.name,
        'approvedAt': DateTime.now().toUtc().toIso8601String(),
        'approvedBy': adminUid,
      });
      return;
    }
    await _db.collection('users').doc(uid).update({
      'status':     UserStatus.approved.name,
      'approvedAt': Timestamp.fromDate(DateTime.now()),
      'approvedBy': adminUid,
    });
  }

  static Future<void> promoteToAdmin(String uid) async {
    if (kIsWeb) {
      await _patchUserRest(uid, {'role': UserRole.admin.name});
      return;
    }
    await _db.collection('users').doc(uid).update({'role': UserRole.admin.name});
  }

  static Future<void> promoteToSupervisor(String uid) async {
    if (kIsWeb) {
      await _patchUserRest(uid, {'role': UserRole.supervisor.name});
      return;
    }
    await _db.collection('users').doc(uid).update({'role': UserRole.supervisor.name});
  }

  static Future<void> demoteToUser(String uid) async {
    if (kIsWeb) {
      await _patchUserRest(uid, {'role': UserRole.user.name});
      return;
    }
    await _db.collection('users').doc(uid).update({'role': UserRole.user.name});
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS REST INTERNOS
  // ═══════════════════════════════════════════════════════════════════════════

  /// PATCH genérico para atualizar campos de um documento users/{uid} via REST.
  ///
  /// Suporta valores String, bool, int, double e null.
  /// Usa updateMask para atualizar apenas os campos informados (não sobrescreve
  /// o documento inteiro — equivalente ao SDK update()).
  static Future<void> _patchUserRest(
    String uid,
    Map<String, dynamic> fields,
  ) async {
    try {
      final token = await _getAdminToken();
      if (token.isEmpty) return;

      // Monta os campos no formato Firestore REST
      final fsFields = <String, dynamic>{};
      fields.forEach((k, v) {
        if (v == null) {
          fsFields[k] = {'nullValue': null};
        } else if (v is bool) {
          fsFields[k] = {'booleanValue': v};
        } else if (v is int) {
          fsFields[k] = {'integerValue': v.toString()};
        } else if (v is double) {
          fsFields[k] = {'doubleValue': v};
        } else {
          // String (inclui timestamps ISO8601, status, role, etc.)
          fsFields[k] = {'stringValue': v.toString()};
        }
      });

      // updateMask: garante que apenas os campos informados são atualizados
      final maskParams = fields.keys
          .map((k) => 'updateMask.fieldPaths=${Uri.encodeComponent(k)}')
          .join('&');

      await http.patch(
        Uri.parse('$_fsBase/users/$uid?$maskParams'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'fields': fsFields}),
      );
    } catch (_) {
      // falha silenciosa — o stream de polling vai refletir o estado correto
    }
  }

  /// Cria documento de usuário no Firestore via REST (Web)
  static Future<void> _createUserDocRest({
    required UserModel user,
    required String idToken,
  }) async {
    try {
      final fields = <String, dynamic>{};
      final m = user.toMap();
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
    } catch (_) {}
  }

  /// Converte resposta REST do Firestore para Map compatível com UserModel.fromMap
  static Map<String, dynamic> _firestoreDocToMap(Map<String, dynamic> doc) {
    final fields = doc['fields'] as Map<String, dynamic>? ?? {};
    final result = <String, dynamic>{};

    fields.forEach((key, value) {
      final v = value as Map<String, dynamic>;
      if (v.containsKey('stringValue')) {
        result[key] = v['stringValue'];
      } else if (v.containsKey('booleanValue')) {
        result[key] = v['booleanValue'];
      } else if (v.containsKey('integerValue')) {
        result[key] = int.tryParse(v['integerValue'].toString());
      } else if (v.containsKey('doubleValue')) {
        result[key] = v['doubleValue'];
      } else if (v.containsKey('timestampValue')) {
        result[key] = Timestamp.fromDate(DateTime.parse(v['timestampValue'] as String));
      } else {
        result[key] = null;
      }
    });

    return result;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS DE CONSTRUÇÃO DE MODELO
  // ═══════════════════════════════════════════════════════════════════════════

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

  static AuthResult _buildResultFromDoc({
    required bool exists,
    required Map<String, dynamic> data,
    required String uid,
    required String email,
  }) {
    if (!exists || data.isEmpty) {
      final user = _buildNewUser(uid: uid, email: email);
      return AuthResult.success(user);
    }
    final user = UserModel.fromMap(data);
    return AuthResult.success(user);
  }

  // ── Mensagens de erro amigáveis ───────────────────────────────────────────
  static String _authErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':         return 'Nenhuma conta encontrada com este e-mail.';
      case 'wrong-password':
      case 'invalid-credential':     return 'E-mail ou senha incorretos.';
      case 'email-already-in-use':   return 'Este e-mail já está cadastrado.';
      case 'weak-password':          return 'Senha fraca. Use ao menos 6 caracteres.';
      case 'invalid-email':          return 'Endereço de e-mail inválido.';
      case 'too-many-requests':      return 'Muitas tentativas. Aguarde alguns minutos.';
      case 'network-request-failed': return 'Sem conexão. Verifique sua internet.';
      case 'operation-not-allowed':  return 'Login por e-mail desabilitado. Contate o admin.';
      case 'user-disabled':          return 'Conta desativada. Entre em contato com o administrador.';
      default:                       return 'Erro de autenticação. Tente novamente.';
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
