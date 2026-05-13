// auth_service.dart — Firebase Auth + Firestore via REST (Web) e SDK (nativo)
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart' show ValueNotifier;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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
          final expiresIn  = int.tryParse(body['expires_in']?.toString() ?? '3600') ?? 3600;
          _tokenExpiresAt  = DateTime.now().add(Duration(seconds: expiresIn - 300));
          return _cachedIdToken;
        }
      } catch (_) {}
    }
    // Sem token válido — retorna vazio
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
  // SESSION PERSISTENCE — "Manter conectado"
  // ─────────────────────────────────────────────────────────────────────────
  // Chaves SharedPreferences usadas para persistência de sessão entre reloads.
  // Armazenamos apenas o refreshToken (nunca o idToken — ele expira em 1h).
  // Na próxima abertura, trocamos o refreshToken por um idToken novo via
  // securetoken.googleapis.com/v1/token antes de exibir qualquer UI.
  // ═══════════════════════════════════════════════════════════════════════════

  static const _kRefreshToken = 'session_refresh_token';
  static const _kUserJson     = 'session_user_json';
  static const _kKeepLoggedIn = 'session_keep_logged_in';

  /// Persiste a sessão no SharedPreferences.
  /// Chamado pelo LoginScreen imediatamente após login bem-sucedido,
  /// apenas quando o usuário marcou "Manter conectado".
  static Future<void> saveSession(UserModel user) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kKeepLoggedIn, true);
      await p.setString(_kRefreshToken, _cachedRefreshTk);
      await p.setString(_kUserJson, jsonEncode(user.toJson()));
    } catch (_) {}
  }

  /// Lê a sessão persistida e, se válida, renova o idToken silenciosamente.
  /// Retorna o [UserModel] restaurado, ou null se não há sessão salva.
  /// Deve ser chamado em main() antes de runApp(), no contexto de um Future.
  ///
  /// Após restaurar o cache local, re-lê o documento users/{uid} no Firestore
  /// para obter o status atual (ex: aprovado pelo admin desde o último login).
  static Future<UserModel?> restoreSession() async {
    try {
      final p = await SharedPreferences.getInstance();
      final keepLoggedIn = p.getBool(_kKeepLoggedIn) ?? false;
      if (!keepLoggedIn) return null;

      final refreshToken = p.getString(_kRefreshToken) ?? '';
      final userJson     = p.getString(_kUserJson)     ?? '';
      if (refreshToken.isEmpty || userJson.isEmpty) return null;

      // Troca o refreshToken por um novo idToken
      final resp = await http.post(
        Uri.parse('https://securetoken.googleapis.com/v1/token?key=$_webApiKey'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'grant_type=refresh_token&refresh_token=$refreshToken',
      ).timeout(const Duration(seconds: 8));

      if (resp.statusCode != 200) {
        // Token inválido/expirado — limpa sessão e força novo login
        await clearSession();
        return null;
      }

      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final newIdToken      = body['id_token']      as String? ?? '';
      final newRefreshToken = body['refresh_token'] as String? ?? refreshToken;
      final expiresIn       = int.tryParse(body['expires_in']?.toString() ?? '3600') ?? 3600;
      final uid             = body['user_id']       as String? ?? '';

      // Atualiza cache em memória
      _cachedIdToken   = newIdToken;
      _cachedRefreshTk = newRefreshToken;
      _tokenExpiresAt  = DateTime.now().add(Duration(seconds: expiresIn - 300));

      // Persiste o novo refreshToken
      await p.setString(_kRefreshToken, newRefreshToken);

      // ── Re-lê o documento Firestore para obter o status ATUAL ──────────────
      // O JSON em cache pode ter status:'pending' do momento do cadastro.
      // Se o admin aprovou o usuário entre sessões, precisamos refletir isso.
      UserModel? freshUser;
      if (uid.isNotEmpty && newIdToken.isNotEmpty) {
        try {
          final fsResp = await http.get(
            Uri.parse('$_fsBase/users/$uid'),
            headers: {'Authorization': 'Bearer $newIdToken'},
          ).timeout(const Duration(seconds: 6));

          if (fsResp.statusCode == 200) {
            final fsBody = jsonDecode(fsResp.body) as Map<String, dynamic>;
            final data   = _firestoreDocToMap(fsBody);
            data['uid']  = uid;
            freshUser    = UserModel.fromMap(data);
            // Atualiza o JSON em cache com os dados frescos
            await p.setString(_kUserJson, jsonEncode(freshUser.toJson()));
          }
        } catch (_) {
          // Falha de rede ao re-ler Firestore — usa JSON em cache como fallback
        }
      }

      // Fallback: reconstrói a partir do JSON salvo se Firestore falhou
      final user = freshUser ?? UserModel.fromJson(
        jsonDecode(userJson) as Map<String, dynamic>,
      );

      // Seta webUser para que _AuthGate roteie direto ao MainShell
      if (kIsWeb) webUser.value = user;

      return user;
    } catch (_) {
      return null;
    }
  }

  /// Remove todos os dados de sessão persistida (logout explícito ou token expirado).
  static Future<void> clearSession() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(_kKeepLoggedIn);
      await p.remove(_kRefreshToken);
      await p.remove(_kUserJson);
    } catch (_) {}
  }

  /// Verifica se o usuário marcou "Manter conectado" anteriormente.
  static Future<bool> isKeepLoggedInEnabled() async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getBool(_kKeepLoggedIn) ?? false;
    } catch (_) {
      return false;
    }
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
        return AuthResult.error('Erro ao carregar perfil (HTTP ${fsResp.statusCode}). Tente novamente.');
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

    // Limpa sessão persistida (SharedPreferences)
    await clearSession();

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
  static Stream<List<UserModel>> _allUsersStreamRest() {
    // StreamController com auto-cancel para não vazar quando não há listeners
    late StreamController<List<UserModel>> ctrl;
    Timer? timer;

    Future<void> fetch() async {
      try {
        final token = await _getAdminToken();

        // Token vazio: emite lista vazia para tirar o loading e agenda retry
        if (token.isEmpty) {
          if (!ctrl.isClosed) ctrl.add([]);
          return;
        }

        final resp = await http.get(
          Uri.parse('$_fsBase/users?pageSize=500'),
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 10));

        if (resp.statusCode != 200) {
          // HTTP erro (403, 401, etc.) — emite lista vazia para sair do loading
          if (!ctrl.isClosed) ctrl.add([]);
          return;
        }

        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final docs  = body['documents'] as List<dynamic>? ?? [];

        final users = <UserModel>[];
        for (final doc in docs) {
          try {
            final docMap = doc as Map<String, dynamic>;
            final data   = _firestoreDocToMap(docMap);
            final name   = docMap['name'] as String? ?? '';
            // name = "projects/.../documents/users/{uid}"
            final uid    = name.split('/').last;
            if (uid.isEmpty) continue;
            data['uid']  = uid;
            final u      = UserModel.fromMap(data);
            users.add(u);
          } catch (_) {
            // doc malformado — ignora e continua
          }
        }

        // Ordena por createdAt decrescente (equivalente ao orderBy SDK)
        users.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (!ctrl.isClosed) ctrl.add(users);
      } catch (_) {
        // Falha de rede / timeout — emite lista vazia para sair do loading;
        // o timer periódico tentará novamente em 8 s.
        if (!ctrl.isClosed) ctrl.add([]);
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

  /// Aprova um usuário pendente. Lança [Exception] em caso de falha.
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

  /// Bloqueia um usuário. Lança [Exception] em caso de falha.
  static Future<void> blockUser(String uid) async {
    if (kIsWeb) {
      await _patchUserRest(uid, {'status': UserStatus.blocked.name});
      return;
    }
    await _db.collection('users').doc(uid).update({'status': UserStatus.blocked.name});
  }

  /// Desbloqueia um usuário. Lança [Exception] em caso de falha.
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

  /// Promove usuário a admin. Lança [Exception] em caso de falha.
  static Future<void> promoteToAdmin(String uid) async {
    if (kIsWeb) {
      await _patchUserRest(uid, {'role': UserRole.admin.name});
      return;
    }
    await _db.collection('users').doc(uid).update({'role': UserRole.admin.name});
  }

  /// Promove usuário a supervisor. Lança [Exception] em caso de falha.
  static Future<void> promoteToSupervisor(String uid) async {
    if (kIsWeb) {
      await _patchUserRest(uid, {'role': UserRole.supervisor.name});
      return;
    }
    await _db.collection('users').doc(uid).update({'role': UserRole.supervisor.name});
  }

  /// Rebaixa usuário para role comum. Lança [Exception] em caso de falha.
  static Future<void> demoteToUser(String uid) async {
    if (kIsWeb) {
      await _patchUserRest(uid, {'role': UserRole.user.name});
      return;
    }
    await _db.collection('users').doc(uid).update({'role': UserRole.user.name});
  }

  /// Deleta o documento do usuário na coleção users. Lança [Exception] em caso de falha.
  /// Web: usa HTTP DELETE REST com token de admin (contorna permission-denied).
  /// Nativo: SDK Firestore autenticado via Firebase Auth.
  static Future<void> deleteUser(String uid) async {
    if (uid.isEmpty) return;
    if (kIsWeb) {
      final token = await _getAdminToken();
      if (token.isEmpty) {
        throw Exception('Token de autenticação não disponível. Faça login novamente.');
      }
      final resp = await http.delete(
        Uri.parse('$_fsBase/users/$uid'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        String detail = '';
        try {
          final body = jsonDecode(resp.body) as Map<String, dynamic>;
          detail = (body['error']?['message'] as String?) ?? '';
        } catch (_) {}
        throw Exception(
          'Erro ao excluir usuário (HTTP ${resp.statusCode})'
          '${detail.isNotEmpty ? ': $detail' : '.'}',
        );
      }
      return;
    }
    // Nativo — SDK autenticado
    await _db.collection('users').doc(uid).delete();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS REST INTERNOS
  // ═══════════════════════════════════════════════════════════════════════════

  /// PATCH genérico para atualizar campos de um documento users/{uid} via REST.
  ///
  /// Suporta valores String, bool, int, double e null.
  /// Usa updateMask para atualizar apenas os campos informados (não sobrescreve
  /// o documento inteiro — equivalente ao SDK update()).
  /// Lança [Exception] se o token estiver vazio ou se o servidor retornar erro.
  static Future<void> _patchUserRest(
    String uid,
    Map<String, dynamic> fields,
  ) async {
    final token = await _getAdminToken();
    if (token.isEmpty) {
      throw Exception('Token de autenticação não disponível. Faça login novamente.');
    }

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

    final resp = await http.patch(
      Uri.parse('$_fsBase/users/$uid?$maskParams'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'fields': fsFields}),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      // Extrai mensagem de erro do Firestore se disponível
      String detail = '';
      try {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        detail = (body['error']?['message'] as String?) ?? '';
      } catch (_) {}
      throw Exception(
        'Erro ao atualizar usuário (HTTP ${resp.statusCode})'
        '${detail.isNotEmpty ? ': $detail' : '.'}',
      );
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

  /// Converte resposta REST do Firestore para Map compatível com UserModel.fromMap.
  ///
  /// Campos de data (createdAt, approvedAt e qualquer campo com sufixo 'At'/'Date')
  /// são sempre convertidos para [Timestamp], independente de virem como
  /// `timestampValue` (cadastro via SDK) ou `stringValue` ISO8601
  /// (atualização via _patchUserRest). Isso evita ClassCastException no fromMap.
  static Map<String, dynamic> _firestoreDocToMap(Map<String, dynamic> doc) {
    final fields = doc['fields'] as Map<String, dynamic>? ?? {};
    final result = <String, dynamic>{};

    // Campos que devem sempre ser tratados como Timestamp
    const dateFields = {'createdAt', 'approvedAt', 'updatedAt', 'deletedAt'};

    fields.forEach((key, value) {
      final v = value as Map<String, dynamic>;
      if (v.containsKey('timestampValue')) {
        // Timestamp nativo do Firestore → converte para Timestamp do SDK
        result[key] = Timestamp.fromDate(
          DateTime.parse(v['timestampValue'] as String),
        );
      } else if (v.containsKey('stringValue')) {
        final str = v['stringValue'] as String;
        // Se é um campo de data salvo como ISO8601 string (ex: via _patchUserRest)
        // converte para Timestamp para manter compatibilidade com UserModel.fromMap.
        // O _patchUserRest salva o approvedAt como ISO8601 com 'Z' no final,
        // ex: "2026-05-10T14:08:10.162Z" — DateTime.parse() aceita esse formato.
        // Tentamos também substituir espaço por 'T' para robustez extra.
        if (dateFields.contains(key)) {
          DateTime? parsed;
          // Tentativa 1: parse direto
          try { parsed = DateTime.parse(str); } catch (_) {}
          // Tentativa 2: substitui espaço por T (formato alternativo do Firestore)
          if (parsed == null) {
            try { parsed = DateTime.parse(str.replaceFirst(' ', 'T')); } catch (_) {}
          }
          // Tentativa 3: remove milissegundos e tenta de novo
          if (parsed == null) {
            try {
              final clean = str.replaceAll(RegExp(r'\.\d+'), '');
              parsed = DateTime.parse(clean);
            } catch (_) {}
          }
          result[key] = parsed != null
              ? Timestamp.fromDate(parsed)
              : null; // campo de data inválido → null (UserModel._parseDate aceita null)
        } else {
          result[key] = str;
        }
      } else if (v.containsKey('booleanValue')) {
        result[key] = v['booleanValue'];
      } else if (v.containsKey('integerValue')) {
        result[key] = int.tryParse(v['integerValue'].toString());
      } else if (v.containsKey('doubleValue')) {
        result[key] = v['doubleValue'];
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
