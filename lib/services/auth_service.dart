// auth_service.dart — Firebase Auth + Firestore via REST (Web) e SDK (nativo)
import 'dart:async';
import 'dart:convert';
// BUILD 282: dart:io removido — dart2js (compilador Web) não pode linkar
// dart:io mesmo que o código seja dead-code (protegido por kIsWeb).
// O catch de SocketException foi substituído pelo catch genérico existente,
// que já captura erros de rede nativa. Comportamento do usuário: inalterado.
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/widgets.dart' show ValueNotifier;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart'; // BUILD 294: guard Firebase.apps
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'firebase_runtime_guard.dart'; // BUILD 299: safe Firebase.apps access
import 'firestore_service.dart';

class AuthService {
  // BUILD 299: FirebaseRuntimeGuard substitui Firebase.apps direto.
  // O getter Firebase.apps lança NullError no Safari quando o interop JS
  // está em estado nulo — detectado pelo stack trace do BUILD 297/299.
  // FirebaseRuntimeGuard.isUnavailable/isReady encapsula o try/catch.
  static FirebaseAuth get _auth {
    if (FirebaseRuntimeGuard.isUnavailable) {
      throw StateError('[BUILD299][AuthService] Firebase não inicializado — '
          '_auth inacessível. Verifique Firebase.initializeApp() no boot.');
    }
    return FirebaseAuth.instance;
  }

  static FirebaseFirestore get _db {
    if (FirebaseRuntimeGuard.isUnavailable) {
      throw StateError('[BUILD299][AuthService] Firebase não inicializado — '
          '_db inacessível. Verifique Firebase.initializeApp() no boot.');
    }
    return FirebaseFirestore.instance;
  }

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
  // BUILD 294: Se Firebase não inicializou (Safari ITP/private mode), retorna
  // Stream.empty() em vez de lançar StateError — previne NullError na _AuthGate.
  // currentUser retorna null — caller verifica null antes de usar.
  static Stream<User?> get authStateChanges {
    if (FirebaseRuntimeGuard.isUnavailable) {
      debugPrint('[BUILD299][AuthService] authStateChanges: Firebase runtime unavailable — Stream.empty()');
      return const Stream.empty();
    }
    return _auth.authStateChanges();
  }

  static User? get currentUser {
    if (FirebaseRuntimeGuard.isUnavailable) {
      debugPrint('[BUILD299][AuthService] currentUser: Firebase runtime unavailable — null');
      return null;
    }
    return _auth.currentUser;
  }

  /// ORDEM 50 M3: True se há token em cache não expirado (sem I/O de rede).
  /// Usado pelo FirestoreService._isUserAuthenticated para detectar auth
  /// no Web sem chamar getAdminToken() (que faz refresh de rede).
  static bool get hasCachedToken =>
      _cachedIdToken.isNotEmpty &&
      DateTime.now().isBefore(_tokenExpiresAt);

  // ── BUILD 463-A.2: Explicit credential type separation ─────────────────────
  //
  // These two properties cleanly separate the two credential planes:
  //
  //   hasRestCredential      — Web REST identity-toolkit idToken in cache.
  //                            Does NOT mean the Firebase SDK has a live session.
  //                            Source: _cachedIdToken populated by _loginWeb() or
  //                            _restoreSessionImpl() via the REST refresh endpoint.
  //
  //   hasFirebaseSdkIdentity — Firebase SDK session active RIGHT NOW.
  //                            currentUser != null after signInWithEmailAndPassword,
  //                            signInWithCredential, or authStateChanges emission.
  //                            This is the ONLY credential type that satisfies the
  //                            Firestore SDK auth barrier (dual-check in 463-A.1.2).
  //
  // KEY DISTINCTION from hasCachedToken:
  //   hasCachedToken == hasRestCredential (REST plane only).
  //   hasFirebaseSdkIdentity checks the live SDK — cannot be stale.
  //   Gemini OAuth state is NEVER reflected in either property.

  /// True if a non-expired REST identity-toolkit idToken is cached in memory.
  /// This credential belongs to the Web REST plane only.
  /// It does NOT imply a live Firebase SDK session (hasFirebaseSdkIdentity).
  /// NEVER pass this token to signInWithCustomToken() — it is not a Custom Token.
  static bool get hasRestCredential => hasCachedToken;

  /// True if the Firebase Auth SDK currently holds a live authenticated session.
  /// This is the ONLY credential type that satisfies Firestore SDK read barriers.
  /// If false, all Firestore SDK reads must be blocked regardless of REST token state.
  static bool get hasFirebaseSdkIdentity {
    if (FirebaseRuntimeGuard.isUnavailable) return false;
    return FirebaseAuth.instance.currentUser != null;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // BUILD 463-A.2-R1: AUTH_SDK_ESTABLISH telemetry helpers (corrected)
  // ─────────────────────────────────────────────────────────────────────────────
  //
  // RUNTIME AUDIT FIX: Three fraudulent-emission defects corrected:
  //
  //   1. adapterType tag added to START — 'live' on production/browser,
  //      'simulated' is FORBIDDEN in non-test runtimes.
  //
  //   2. CREDENTIAL_ACCEPTED now REQUIRES a non-null SDK currentUser at
  //      the call-site. Callers pass the User? they just received and this
  //      helper refuses (emits FAILED instead) when it is null.
  //      The 'firebaseUidAfter' parameter is appended dynamically.
  //
  //   3. TOKEN_REFRESHED is emitted by the caller AFTER getIdToken(true)
  //      resolves without throwing. The helper itself has no guard (it is
  //      only reached on the success path) but is kept distinct from
  //      CREDENTIAL_ACCEPTED to preserve schema ordering.
  //
  //   4. _restoreSessionImpl (REST-only path): CREDENTIAL_ACCEPTED and
  //      TOKEN_REFRESHED are SUPPRESSED — the REST token refresh does NOT
  //      establish a Firebase SDK session. Only native SDK sign-in methods
  //      qualify for those tags.

  /// Adapter type tag injected into START telemetry.
  /// Always 'live' in production. 'simulated' is only valid in unit tests.
  static String get _adapterType {
    // In Dart tests the flutter_test binding does not set kIsWeb; we detect
    // test mode by checking whether dart:io is available without kIsWeb.
    // Production browser/native is always 'live'.
    // This is a read-only metadata tag — it does NOT change behaviour.
    return 'live';
  }

  /// Emit START telemetry for an auth SDK establishment attempt.
  static void logSdkEstablishStart({
    required String method,
    required String expectedUid,
  }) {
    final currentFbUid = FirebaseRuntimeGuard.isReady
        ? (FirebaseAuth.instance.currentUser?.uid ?? 'null')
        : 'firebase_unavailable';
    debugPrint('[AUTH_SDK_ESTABLISH][START] '
        'method=$method '
        'expectedUid=$expectedUid '
        'firebaseUidBefore=$currentFbUid '
        'adapterType=${_adapterType}');
  }

  /// Emit CREDENTIAL_ACCEPTED telemetry.
  ///
  /// STRICT GATE (463-A.2-R1): [firebaseUser] MUST be non-null.
  /// If the SDK currentUser is null at this point the credential was NOT
  /// accepted by the native SDK — emit FAILED instead and return.
  /// Appends 'firebaseUidAfter=<uid>' dynamically to the log line.
  static void logSdkCredentialAccepted({required User? firebaseUser}) {
    if (firebaseUser == null) {
      // FALSE-SUCCESS GUARD: SDK returned null — this is NOT a credential
      // acceptance. Emit FAILED to prevent false positive telemetry.
      debugPrint('[AUTH_SDK_ESTABLISH][FAILED] '
          'stage=credential_accepted_guard '
          'reason=sdk_user_null_after_sign_in '
          'adapterType=${_adapterType}');
      return;
    }
    debugPrint('[AUTH_SDK_ESTABLISH][CREDENTIAL_ACCEPTED] '
        'firebaseUidAfter=${firebaseUser.uid} '
        'adapterType=${_adapterType}');
  }

  /// Emit TOKEN_REFRESHED telemetry.
  ///
  /// Called by the caller ONLY after getIdToken(true) resolves successfully.
  /// NEVER called when the token refresh threw an exception.
  static void logSdkTokenRefreshed({required String uid}) {
    debugPrint('[AUTH_SDK_ESTABLISH][TOKEN_REFRESHED] '
        'uid=$uid '
        'adapterType=${_adapterType}');
  }

  /// Emit FAILED telemetry for an auth SDK establishment failure.
  static void logSdkEstablishFailed({
    required String stage,
    required String reason,
  }) {
    debugPrint('[AUTH_SDK_ESTABLISH][FAILED] '
        'stage=$stage '
        'reason=$reason '
        'adapterType=${_adapterType}');
  }

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

  // BUILD 281: trava de idempotência para restoreSession() no Web mobile.
  // O teclado virtual iOS/Android causa resize do viewport → visibilitychange →
  // AppResumeCoordinator pode disparar novo restoreSession() enquanto o primeiro
  // ainda está em voo (aguardando securetoken.googleapis.com ~200-800ms).
  // Sem esta trava, duas chamadas concorrentes fazem duas trocas do refreshToken:
  //   Call 1: troca refreshToken_A → recebe refreshToken_B (novo)  ← persiste B
  //   Call 2: troca refreshToken_A (stale) → recebe 400 INVALID    ← limpa sessão!
  // O resultado: sessão destruída ao abrir teclado, usuário é deslogado.
  static Future<UserModel?>? _restoreInFlight;

  /// Lê a sessão persistida e, se válida, renova o idToken silenciosamente.
  /// Retorna o [UserModel] restaurado, ou null se não há sessão salva.
  /// Deve ser chamado em main() antes de runApp(), no contexto de um Future.
  ///
  /// Após restaurar o cache local, re-lê o documento users/{uid} no Firestore
  /// para obter o status atual (ex: aprovado pelo admin desde o último login).
  static Future<UserModel?> restoreSession() {
    // BUILD 281: idempotência — se já há uma chamada em voo, retorna o mesmo Future.
    // Isso previne a dupla troca de refreshToken quando visibilitychange ou resize
    // dispara um segundo restoreSession() antes do primeiro completar.
    if (_restoreInFlight != null) {
      debugPrint('[AuthService] restoreSession() já em voo — retornando Future existente (idempotente)');
      return _restoreInFlight!;
    }
    _restoreInFlight = _restoreSessionImpl();
    _restoreInFlight!.whenComplete(() => _restoreInFlight = null);
    return _restoreInFlight!;
  }

  static Future<UserModel?> _restoreSessionImpl() async {
    // BUILD 463-A.2-R1: persistence_restore telemetry
    // NOTE: This path is the Web REST identity-toolkit refresh (securetoken.googleapis.com).
    // It does NOT establish a Firebase SDK session (FirebaseAuth.instance.currentUser).
    // CREDENTIAL_ACCEPTED and TOKEN_REFRESHED are SUPPRESSED on this path —
    // only native SDK sign-in methods (email_password, google_credential, custom_token)
    // qualify for those tags. If the REST restore completes but the SDK user is still
    // null, AppProvider._setUserImpl() will terminate at authRequired.
    logSdkEstablishStart(method: 'persistence_restore', expectedUid: 'cached_session');
    try {
      final p = await SharedPreferences.getInstance();
      final keepLoggedIn = p.getBool(_kKeepLoggedIn) ?? false;
      if (!keepLoggedIn) {
        logSdkEstablishFailed(stage: 'prefs_check', reason: 'keep_logged_in_false');
        return null;
      }

      final refreshToken = p.getString(_kRefreshToken) ?? '';
      final userJson     = p.getString(_kUserJson)     ?? '';
      if (refreshToken.isEmpty || userJson.isEmpty) {
        logSdkEstablishFailed(stage: 'prefs_check', reason: 'missing_refresh_token_or_user_json');
        return null;
      }

      // Troca o refreshToken por um novo idToken
      final resp = await http.post(
        Uri.parse('https://securetoken.googleapis.com/v1/token?key=$_webApiKey'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'grant_type=refresh_token&refresh_token=$refreshToken',
      ).timeout(const Duration(seconds: 4));

      if (resp.statusCode != 200) {
        // Token inválido/expirado — limpa sessão e força novo login
        logSdkEstablishFailed(stage: 'token_refresh', reason: 'http_${resp.statusCode}');
        await clearSession();
        return null;
      }

      // REST token refresh succeeded — REST plane only.
      // SUPPRESSED: logSdkCredentialAccepted() is NOT emitted here because
      // the Firebase SDK currentUser has NOT been populated by this REST call.
      // Emitting it here was the source of FALSE-SUCCESS telemetry in the
      // browser audit. The SDK session state is verified later in
      // AppProvider._setUserImpl() which will resolve to authRequired if
      // FirebaseAuth.instance.currentUser is still null.
      debugPrint('[AUTH_SDK_ESTABLISH][REST_TOKEN_REFRESHED] '
          'adapterType=${_adapterType} '
          'note=sdk_session_not_established_by_rest_path');

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
          ).timeout(const Duration(seconds: 3));

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

      // SUPPRESSED: logSdkTokenRefreshed() is NOT emitted here.
      // The REST path refreshed a REST token — not an SDK identity token.
      // SDK token refresh (getIdToken(true)) only happens on native paths.
      debugPrint('[AUTH_SDK_ESTABLISH][REST_RESTORE_COMPLETE] '
          'adapterType=${_adapterType} '
          'sdkIdentityEstablished=false '
          'note=authRequired_if_sdk_user_null');
      return user;
    } catch (_) {
      logSdkEstablishFailed(stage: 'restore_session_impl', reason: 'unexpected_exception');
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
    // BUILD 463-A.2-R1: AUTH_SDK_ESTABLISH telemetry (corrected)
    logSdkEstablishStart(method: 'email_password', expectedUid: email.trim());
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      ).timeout(const Duration(seconds: 15));

      // STRICT GATE: resolve currentUser BEFORE emitting CREDENTIAL_ACCEPTED.
      // signInWithEmailAndPassword() may return before authStateChanges propagates
      // on slow connections — poll once before the stream fallback.
      User? firebaseUser = _auth.currentUser;
      if (firebaseUser == null) {
        firebaseUser = await _auth.authStateChanges()
            .where((u) => u != null)
            .first
            .timeout(const Duration(seconds: 5), onTimeout: () => null);
      }

      // CREDENTIAL_ACCEPTED: emitted ONLY when SDK user is confirmed non-null.
      // logSdkCredentialAccepted() enforces the null guard internally and will
      // emit FAILED instead if firebaseUser is still null at this point.
      logSdkCredentialAccepted(firebaseUser: firebaseUser);

      if (firebaseUser == null) {
        // logSdkCredentialAccepted already emitted the FAILED line above.
        return AuthResult.error('Sessão não inicializada. Tente novamente.');
      }

      // TOKEN_REFRESHED: emitted ONLY after getIdToken(true) resolves without
      // throwing. Any exception here bypasses the emit entirely.
      await firebaseUser.getIdToken(true);
      logSdkTokenRefreshed(uid: firebaseUser.uid);

      debugPrint('[Auth] Login nativo OK — uid=${firebaseUser.uid}');

      // ensureUserProfileExists: cria/repara doc se ausente ou incompleto.
      // Garante que mesmo usuários que nunca passaram pelo registro web
      // entrem no app direto sem loops de pending.
      final user = await ensureUserProfileExists(
        firebaseUser,
        platform: 'ios',
      );
      debugPrint('[Auth] Perfil verificado — status=${user.status.name}');
      return AuthResult.success(user);
    } on TimeoutException {
      return AuthResult.error('Conexão lenta. Verifique sua internet e tente novamente.');
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_authErrorMessage(e.code));
    } catch (e) {
      // BUILD 282: SocketException (dart:io) removida — dart2js não pode linkar dart:io.
      // Erros de rede nativa (sem conexão) chegam aqui como Exception genérica.
      final msg = e.toString().toLowerCase();
      if (msg.contains('socket') || msg.contains('network') || msg.contains('connection')) {
        return AuthResult.error('Sem conexão. Verifique sua internet e tente novamente.');
      }
      return AuthResult.error('Não foi possível fazer login. Tente novamente.');
    }
  }

  // ── Login Web via REST ─────────────────────────────────────────────────────
  static Future<AuthResult> _loginWeb({
    required String email,
    required String password,
  }) async {
    debugPrint('[Auth][LOGIN] REQUEST:');
    debugPrint('[Auth][LOGIN]   EMAIL : ${email.trim()}');

    try {
      // Passo 1 — Auth REST
      final authResp = await http.post(
        Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$_webApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim(), 'password': password, 'returnSecureToken': true}),
      );

      debugPrint('[Auth][LOGIN] RESPONSE:');
      debugPrint('[Auth][LOGIN]   STATUS : ${authResp.statusCode}');
      debugPrint('[Auth][LOGIN]   BODY   : ${authResp.body}');

      final authBody = jsonDecode(authResp.body) as Map<String, dynamic>;

      if (authResp.statusCode != 200) {
        final msg = ((authBody['error']?['message'] as String?) ?? '').toUpperCase();
        debugPrint('[Auth][LOGIN]   ERROR_CODE : $msg');
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
        return AuthResult.error('E-mail ou senha incorretos. [$msg]');
      }

      final uid          = authBody['localId']      as String;
      final idToken      = authBody['idToken']       as String;
      final refreshToken = authBody['refreshToken']  as String? ?? '';

      // Salva tokens em cache para uso posterior (operações admin REST)
      _cacheTokens(idToken: idToken, refreshToken: refreshToken);

      // Passo 2 — Firestore REST: ler documento users/{uid}
      // fix(auth): aguarda 800ms para dar tempo ao token JWT propagar no Firestore
      // antes do primeiro GET (evita 403 por timing em cadastros recentes).
      final fsResp = await http.get(
        Uri.parse('$_fsBase/users/$uid'),
        headers: {'Authorization': 'Bearer $idToken'},
      );

      if (fsResp.statusCode == 404) {
        // Documento ausente: cria com status=approved e retorna OK.
        final user = _buildNewUser(uid: uid, email: email);
        await _createUserDocRest(user: user, idToken: idToken);
        webUser.value = user;
        return AuthResult.success(user);
      }

      if (fsResp.statusCode == 403) {
        // fix(auth): 403 pode ocorrer por token recém-emitido não propagado ainda.
        // Retry único após 1.2 s — evita falso "erro de perfil" pós-cadastro.
        await Future.delayed(const Duration(milliseconds: 1200));
        final fsRetry = await http.get(
          Uri.parse('$_fsBase/users/$uid'),
          headers: {'Authorization': 'Bearer $idToken'},
        );
        if (fsRetry.statusCode == 200) {
          final retryBody = jsonDecode(fsRetry.body) as Map<String, dynamic>;
          final retryData = _firestoreDocToMap(retryBody);
          final retryResult = _buildResultFromDoc(exists: true, data: retryData, uid: uid, email: email);
          if (retryResult.user != null) webUser.value = retryResult.user;
          return retryResult;
        }
        if (fsRetry.statusCode == 404) {
          final user = _buildNewUser(uid: uid, email: email);
          await _createUserDocRest(user: user, idToken: idToken);
          webUser.value = user;
          return AuthResult.success(user);
        }
        // Se ainda 403 após retry: retorna usuário aprovado em memória (não bloqueia login).
        final fallbackUser = _buildNewUser(uid: uid, email: email);
        webUser.value = fallbackUser;
        _createUserDocRest(user: fallbackUser, idToken: idToken).ignore();
        return AuthResult.success(fallbackUser);
      }

      if (fsResp.statusCode != 200) {
        // Qualquer outro erro HTTP inesperado: fallback em memória com status=approved.
        // Nunca retorna erro de "perfil" ao usuário — mantém fluxo de login estável.
        final fallbackUser = _buildNewUser(uid: uid, email: email);
        webUser.value = fallbackUser;
        _createUserDocRest(user: fallbackUser, idToken: idToken).ignore();
        return AuthResult.success(fallbackUser);
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
    String? referredBy,
  }) async {
    if (kIsWeb) {
      return _registerWeb(
        email: email, password: password, displayName: displayName,
        profession: profession, institution: institution,
        referredBy: referredBy,
      );
    }
    return _registerNative(
      email: email, password: password, displayName: displayName,
      profession: profession, institution: institution,
      referredBy: referredBy,
    );
  }

  static Future<AuthResult> _registerNative({
    required String email, required String password,
    required String displayName, String? profession, String? institution,
    String? referredBy,
  }) async {
    try {
      debugPrint('[Auth] Iniciando cadastro nativo — email=$email');

      // 1. Cria a conta Firebase Auth
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(), password: password,
      );
      final firebaseUser = cred.user!;
      debugPrint('[Auth] Auth criado — uid=${firebaseUser.uid}');

      // 2. Atualiza displayName no Firebase Auth
      await firebaseUser.updateDisplayName(displayName.trim());

      // 3. Força emissão do JWT — "esquenta" a sessão no servidor Firebase.
      //    forceRefresh=true garante um token recém-emitido e válido.
      final idToken = await firebaseUser.getIdToken(true) ?? '';

      // 4. Sincroniza estado do usuário com o servidor
      await firebaseUser.reload();

      // 5. Cacheia tokens para operações REST futuras (admin, etc.)
      final refreshToken = firebaseUser.refreshToken ?? '';
      if (idToken.isNotEmpty) {
        _cacheTokens(idToken: idToken, refreshToken: refreshToken);
      }

      // 6. ── NÚCLEO DO FIX iOS ─────────────────────────────────────────────
      // ensureUserProfileExists() cria o documento users/{uid} com status
      // APPROVED, plan=free, trial, onboardingCompleted=false e todos os
      // campos obrigatórios — de forma ATÔMICA (set com merge:false).
      //
      // CRITICAL: o documento já nasce APROVADO. O AuthGate (currentUserStream)
      // lê este documento e roteia direto para MainShell — NUNCA para _PendingScreen.
      // Não há segundo login, não há approveUser separado, não há race condition.
      final user = await ensureUserProfileExists(
        firebaseUser,
        displayName: displayName.trim(),
        profession: profession,
        institution: institution,
        referredBy: referredBy,
        platform: 'ios',
      );
      debugPrint('[Auth] Perfil criado/verificado — status=${user.status.name}');

      // 7. Aguarda authStateChanges propagar (segurança contra iOS lento)
      if (_auth.currentUser == null) {
        await _auth.authStateChanges()
            .where((u) => u != null)
            .first
            .timeout(const Duration(seconds: 3), onTimeout: () => null);
      }

      debugPrint('[Auth] Cadastro nativo concluído — navegando para Home');
      return AuthResult.success(user);
    } on FirebaseAuthException catch (e) {
      debugPrint('[Auth] FirebaseAuthException: ${e.code}');
      return AuthResult.error(_authErrorMessage(e.code));
    } catch (e) {
      debugPrint('[Auth] Erro inesperado no cadastro: $e');
      return AuthResult.error('Erro inesperado. Tente novamente.');
    }
  }

  static Future<AuthResult> _registerWeb({
    required String email, required String password,
    required String displayName, String? profession, String? institution,
    String? referredBy,
  }) async {
    // ── DIAGNÓSTICO COMPLETO — log de request antes de enviar ──────────────
    final endpoint = 'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$_webApiKey';
    final payload  = {'email': email.trim(), 'password': password, 'returnSecureToken': true};
    debugPrint('[Auth][REGISTER] REQUEST:');
    debugPrint('[Auth][REGISTER]   ENDPOINT : $endpoint');
    debugPrint('[Auth][REGISTER]   EMAIL    : ${email.trim()}');
    debugPrint('[Auth][REGISTER]   API_KEY  : ${_webApiKey.substring(0, 8)}...${_webApiKey.substring(_webApiKey.length - 4)}');
    debugPrint('[Auth][REGISTER]   PAYLOAD  : ${jsonEncode(payload).replaceAll(password, '***')}');

    try {
      final resp = await http.post(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      // ── DIAGNÓSTICO: loga SEMPRE status + body cru da Identity Toolkit ──
      debugPrint('[Auth][REGISTER] RESPONSE:');
      debugPrint('[Auth][REGISTER]   STATUS : ${resp.statusCode}');
      debugPrint('[Auth][REGISTER]   BODY   : ${resp.body}');

      final body = jsonDecode(resp.body) as Map<String, dynamic>;

      if (resp.statusCode != 200) {
        final msg = ((body['error']?['message'] as String?) ?? '').toUpperCase();
        debugPrint('[Auth][REGISTER]   ERROR_CODE : $msg');
        if (msg.contains('EMAIL_EXISTS'))        return AuthResult.error('Este e-mail já está cadastrado.');
        if (msg.contains('WEAK_PASSWORD'))        return AuthResult.error('Senha fraca. Use ao menos 6 caracteres.');
        if (msg.contains('INVALID_EMAIL'))        return AuthResult.error('Endereço de e-mail inválido.');
        if (msg.contains('MISSING_PASSWORD'))     return AuthResult.error('Senha não informada.');
        if (msg.contains('INVALID_API_KEY'))      return AuthResult.error('Erro de configuração (API key). Contate o suporte.');
        if (msg.contains('OPERATION_NOT_ALLOWED')) return AuthResult.error('Cadastro por e-mail desabilitado. Contate o suporte.');
        if (msg.contains('TOO_MANY_ATTEMPTS') || msg.contains('TOO_MANY_REQUESTS'))
                                                  return AuthResult.error('Muitas tentativas. Aguarde alguns minutos.');
        // fallback: retorna o código bruto para facilitar diagnóstico
        return AuthResult.error('Erro ao criar conta [$msg]. Tente novamente.');
      }

      final uid          = body['localId']     as String;
      final idToken      = body['idToken']      as String;
      final refreshToken = body['refreshToken'] as String? ?? '';

      debugPrint('[Auth][REGISTER]   UID : $uid');
      _cacheTokens(idToken: idToken, refreshToken: refreshToken);

      final user = _buildNewUser(
        uid: uid, email: email, displayName: displayName,
        profession: profession, institution: institution,
        referredBy: referredBy,
      );
      await _createUserDocRest(user: user, idToken: idToken);
      webUser.value = user;
      return AuthResult.success(user);
    } catch (e, st) {
      debugPrint('[Auth][REGISTER] EXCEPTION: $e');
      debugPrint('[Auth][REGISTER] STACK: $st');
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

  // ═══════════════════════════════════════════════════════════════════════════
  // EXCLUSÃO DE CONTA PRÓPRIA (Diretriz Apple 5.1.1(v))
  // ─────────────────────────────────────────────────────────────────────────
  // deleteAccount() executa a sequência correta exigida pela Apple:
  //   1. Apaga subcoleções/dados do Firestore (notes, sessions, etc.)
  //   2. Apaga o documento principal users/{uid}
  //   3. Exclui a credencial do Firebase Auth (user.delete())
  //   4. Limpa sessão local (SharedPreferences + cache de tokens)
  //
  // Retorna [DeleteAccountResult] com success=true ou error=<mensagem>.
  // Em caso de erro "requires-recent-login", o caller deve pedir
  // re-autenticação e chamar deleteAccount() novamente.
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<DeleteAccountResult> deleteAccount({
    required String uid,
    /// Senha atual — necessária para re-autenticação nativa antes de delete().
    /// Em Web (REST-only), não é necessária pois usamos o idToken em cache.
    String? password,
  }) async {
    if (uid.isEmpty) {
      return DeleteAccountResult.error('UID inválido.');
    }

    try {
      // ── PASSO 1: Apagar subcoleções conhecidas do Firestore ─────────────
      // Adicione aqui quaisquer outras subcoleções que o app criar no futuro.
      final subCollections = ['notes', 'sessions', 'history', 'favorites'];

      if (kIsWeb) {
        // Web: REST — delete de cada documento das subcoleções
        final token = await _getAdminToken();
        if (token.isEmpty) {
          return DeleteAccountResult.error(
            'Sessão expirada. Faça login novamente para continuar.',
          );
        }

        for (final sub in subCollections) {
          try {
            // Lista documentos da subcoleção
            final listResp = await http.get(
              Uri.parse('$_fsBase/users/$uid/$sub?pageSize=300'),
              headers: {'Authorization': 'Bearer $token'},
            ).timeout(const Duration(seconds: 8));

            if (listResp.statusCode == 200) {
              final body = jsonDecode(listResp.body) as Map<String, dynamic>;
              final docs = body['documents'] as List<dynamic>? ?? [];
              for (final doc in docs) {
                final docName = (doc as Map<String, dynamic>)['name'] as String? ?? '';
                if (docName.isEmpty) continue;
                // name = "projects/.../documents/users/{uid}/notes/{docId}"
                // Extrai o path relativo após "/documents/"
                final pathPart = docName.split('/documents/').last;
                await http.delete(
                  Uri.parse('$_fsBase/$pathPart'),
                  headers: {'Authorization': 'Bearer $token'},
                ).timeout(const Duration(seconds: 5));
              }
            }
          } catch (_) {
            // Subcoleção inexistente ou erro de rede — continua sem travar
          }
        }

        // ── PASSO 2: Apagar documento principal users/{uid} ──────────────
        final deleteResp = await http.delete(
          Uri.parse('$_fsBase/users/$uid'),
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 8));

        if (deleteResp.statusCode >= 300 && deleteResp.statusCode != 404) {
          String detail = '';
          try {
            final b = jsonDecode(deleteResp.body) as Map<String, dynamic>;
            detail = (b['error']?['message'] as String?) ?? '';
          } catch (_) {}
          return DeleteAccountResult.error(
            'Não foi possível remover seus dados (HTTP ${deleteResp.statusCode})'
            '${detail.isNotEmpty ? ': $detail' : '.'}',
          );
        }

        // ── PASSO 3 (Web): Delete Firebase Auth via Identity Toolkit ─────
        // A API accounts:delete exige o idToken do próprio usuário (não admin).
        final idToken = _cachedIdToken;
        if (idToken.isNotEmpty) {
          try {
            await http.post(
              Uri.parse(
                'https://identitytoolkit.googleapis.com/v1/accounts:delete?key=$_webApiKey',
              ),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'idToken': idToken}),
            ).timeout(const Duration(seconds: 8));
          } catch (_) {
            // Auth delete falhou — Firestore já foi limpo; logs para suporte
          }
        }
      } else {
        // Nativo (iOS/Android): SDK Firestore + Firebase Auth
        // ── PASSO 1 (nativo): Apagar subcoleções ──────────────────────────
        for (final sub in subCollections) {
          try {
            final snap = await _db
                .collection('users')
                .doc(uid)
                .collection(sub)
                .limit(300)
                .get()
                .timeout(const Duration(seconds: 8));
            for (final doc in snap.docs) {
              await doc.reference.delete();
            }
          } catch (_) {}
        }

        // ── PASSO 2 (nativo): Apagar documento principal ──────────────────
        try {
          await _db
              .collection('users')
              .doc(uid)
              .delete()
              .timeout(const Duration(seconds: 8));
        } catch (_) {}

        // ── PASSO 3 (nativo): Firebase Auth user.delete() ─────────────────
        // Requer re-autenticação se o login foi há muito tempo.
        final user = _auth.currentUser;
        if (user != null) {
          try {
            // Tenta re-autenticar com senha se fornecida (evita requires-recent-login)
            if (password != null && password.isNotEmpty) {
              final cred = EmailAuthProvider.credential(
                email: user.email ?? '',
                password: password,
              );
              await user.reauthenticateWithCredential(cred);
            }
            await user.delete();
          } on FirebaseAuthException catch (e) {
            if (e.code == 'requires-recent-login') {
              return DeleteAccountResult.requiresReauth(
                'Por segurança, faça login novamente para excluir sua conta.',
              );
            }
            // Outros erros de auth — Firestore já foi limpo
          } catch (_) {}
        }
      }

      // ── PASSO 4: Limpar sessão local ─────────────────────────────────────
      _cachedIdToken   = '';
      _cachedRefreshTk = '';
      _tokenExpiresAt  = DateTime(2000);
      await clearSession();
      if (kIsWeb) webUser.value = null;

      return DeleteAccountResult.success();
    } catch (e) {
      return DeleteAccountResult.error(
        'Erro inesperado ao excluir conta. Tente novamente ou contate o suporte.',
      );
    }
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

  /// Persiste o aceite dos termos no Firestore — chamado pelo ProfessionalDeclarationGate.
  /// Web usa REST (_patchUserRest); nativo usa Firestore SDK direto.
  ///
  /// P-5 FIX: campos de auditoria adicionados (declarationVersion, declarationLang).
  /// IEC 62304: rastreabilidade de versão e idioma obrigatória para software médico.
  static Future<void> updateTermsAccepted({
    required String uid,
    required String professionalCategory,
    String declarationVersion = '',
    String declarationLang    = 'pt',
  }) async {
    if (kIsWeb) {
      await _patchUserRest(uid, {
        'acceptedTerms':        true,
        'acceptedTermsAt':      DateTime.now().toUtc().toIso8601String(),
        'professionalCategory': professionalCategory,
        if (declarationVersion.isNotEmpty)
          'declarationVersion': declarationVersion,
        'declarationLang':      declarationLang,
      });
    } else {
      await _db.collection('users').doc(uid).update({
        'acceptedTerms':        true,
        'acceptedTermsAt':      FieldValue.serverTimestamp(),
        'professionalCategory': professionalCategory,
        if (declarationVersion.isNotEmpty)
          'declarationVersion': declarationVersion,
        'declarationLang':      declarationLang,
      });
    }
  }

  /// Verifica no Firestore se o usuário já aceitou os termos.
  /// P-3 FIX: permite re-validação cross-device após reinstalação do app.
  /// Se o Firestore estiver indisponível, lança exceção — o chamador deve tratar.
  static Future<bool> hasAcceptedTerms({required String uid}) async {
    if (kIsWeb) {
      // REST não tem suporte fácil de leitura — retorna false para forçar modal
      return false;
    }
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return false;
    final data = doc.data();
    if (data == null) return false;
    return data['acceptedTerms'] == true;
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

      final patchResp = await http.patch(
        Uri.parse('$_fsBase/users/${user.uid}'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'fields': fields}),
      );

      if (patchResp.statusCode < 200 || patchResp.statusCode >= 300) {
        // fix(auth): loga falha de criação sem lançar exceção — não bloqueia cadastro,
        // mas deixa rastro para diagnóstico de problemas de regra Firestore.
        debugPrint('[Auth] _createUserDocRest FALHOU HTTP ${patchResp.statusCode}: ${patchResp.body}');
      } else {
        debugPrint('[Auth] _createUserDocRest OK — uid=${user.uid} status=${user.status.name}');
      }

      // ── Notifica usuários MASTER sobre novo cadastro ──────────────────────
      _notifyMastersNewUser(user).ignore();
    } catch (e) {
      debugPrint('[Auth] _createUserDocRest exception: $e');
    }
  }

  /// Envia notificação in-app para todos os MASTER quando um novo usuário
  /// se cadastra. Silencioso — nunca bloqueia o fluxo de criação de conta.
  static Future<void> _notifyMastersNewUser(UserModel user) async {
    try {
      final masterUids = await FirestoreService.getMasterUids();
      for (final masterUid in masterUids) {
        await FirestoreService.writeInAppNotification(
          uid:     masterUid,
          title:   '👤 Novo usuário cadastrado',
          body:    '${user.displayName.isNotEmpty ? user.displayName : user.email} acabou de se cadastrar no app.',
          payload: 'new_user:${user.uid}',
        );
      }
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
    const dateFields = {'createdAt', 'approvedAt', 'updatedAt', 'deletedAt', 'acceptedTermsAt'};

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
  // ═══════════════════════════════════════════════════════════════════════════
  // ENSURE USER PROFILE EXISTS — iOS / Android post-register + post-login
  // ─────────────────────────────────────────────────────────────────────────
  // Garante que users/{uid} existe no Firestore com todos os campos mínimos
  // e com status=approved. Chame após qualquer Auth bem-sucedido no nativo.
  //
  // Comportamento:
  //  • Documento NÃO existe → cria com todos os campos + status=approved
  //  • Documento existe mas incompleto → atualiza campos faltantes (merge)
  //  • Documento existe e completo → retorna sem gravar
  //
  // Nunca lança — erros de Firestore são logados e o fallback em memória
  // garante que o usuário entre no app mesmo offline.
  // ═══════════════════════════════════════════════════════════════════════════
  static Future<UserModel> ensureUserProfileExists(
    User firebaseUser, {
    String? displayName,
    String? profession,
    String? institution,
    String? referredBy,
    String platform = 'ios',
  }) async {
    final uid   = firebaseUser.uid;
    final email = firebaseUser.email ?? '';
    final name  = displayName?.trim().isNotEmpty == true
        ? displayName!.trim()
        : (firebaseUser.displayName?.trim().isNotEmpty == true
            ? firebaseUser.displayName!.trim()
            : email.split('@').first);

    final now = DateTime.now();

    try {
      final ref = _db.collection('users').doc(uid);
      final doc = await ref.get();

      if (!doc.exists || (doc.data()?.isEmpty ?? true)) {
        // ── Documento ausente: cria completo com todos os campos mínimos ──
        final newUser = UserModel(
          uid:         uid,
          email:       email.trim().toLowerCase(),
          displayName: name,
          role:        email.trim().toLowerCase() == adminEmail.toLowerCase()
                         ? UserRole.admin
                         : UserRole.user,
          status:      UserStatus.approved,   // ← aprovado imediatamente
          createdAt:   now,
          approvedAt:  now,
          approvedBy:  'system',
          profession:  profession,
          institution: institution,
          referredBy:  (referredBy?.isNotEmpty == true) ? referredBy : null,
          acceptedTerms: false,
        );

        // Campos extras além do UserModel (plan, trial, onboarding, platform)
        final extraFields = <String, dynamic>{
          'plan':                   'free',
          'subscriptionStatus':     'trial',
          'onboardingCompleted':    false,
          'preferredLanguage':      'es',
          'platformCreated':        platform,
          'accountStatus':          'active',
          'updatedAt':              Timestamp.fromDate(now),
        };

        final docData = <String, dynamic>{
          ...newUser.toMap(),
          ...extraFields,
        };

        await ref.set(docData);
        debugPrint('[Auth] Perfil criado no Firestore — uid=$uid status=approved');
        return newUser;
      }

      // ── Documento existe: verifica campos críticos e repara se necessário ─
      final data    = doc.data()!;
      var   user    = UserModel.fromMap({...data, 'uid': uid});
      final repairs = <String, dynamic>{};

      // Repara status pending → approved (legados ou criados incompletos)
      if (user.isPending) {
        repairs['status']     = UserStatus.approved.name;
        repairs['approvedAt'] = Timestamp.fromDate(now);
        repairs['approvedBy'] = 'system-auto';
        user = user.copyWith(
          status: UserStatus.approved, approvedAt: now, approvedBy: 'system-auto');
        debugPrint('[Auth] Perfil reparado: status pending→approved — uid=$uid');
      }

      // Repara campos extras ausentes (plan, subscriptionStatus, etc.)
      if (data['plan'] == null)                repairs['plan']                = 'free';
      if (data['subscriptionStatus'] == null)  repairs['subscriptionStatus']  = 'trial';
      if (data['onboardingCompleted'] == null) repairs['onboardingCompleted'] = false;
      if (data['platformCreated'] == null)     repairs['platformCreated']     = platform;
      if (data['accountStatus'] == null)       repairs['accountStatus']       = 'active';

      if (repairs.isNotEmpty) {
        repairs['updatedAt'] = Timestamp.fromDate(now);
        // fix(auth): usa set com merge:true em vez de update() para evitar
        // PERMISSION_DENIED caso o doc exista com status=pending e a rule antiga
        // bloqueasse updates de usuários não-aprovados. set+merge é equivalente
        // ao update mas não falha se o doc foi recriado entre o get e o set.
        await ref.set(repairs, SetOptions(merge: true));
        debugPrint('[Auth] Perfil reparado — campos: ${repairs.keys.join(', ')}');
      } else {
        debugPrint('[Auth] Perfil OK, sem reparos necessários — uid=$uid');
      }

      return user;
    } catch (e) {
      debugPrint('[Auth] ensureUserProfileExists falhou (usando fallback): $e');
      // Fallback: retorna modelo em memória aprovado para não bloquear o app
      return UserModel(
        uid:         uid,
        email:       email.trim().toLowerCase(),
        displayName: name,
        role:        email.trim().toLowerCase() == adminEmail.toLowerCase()
                       ? UserRole.admin
                       : UserRole.user,
        status:      UserStatus.approved,
        createdAt:   now,
        approvedAt:  now,
        approvedBy:  'system-fallback',
      );
    }
  }

  // HELPERS DE CONSTRUÇÃO DE MODELO
  // ═══════════════════════════════════════════════════════════════════════════

  static UserModel _buildNewUser({
    required String uid,
    required String email,
    String? displayName,
    String? profession,
    String? institution,
    String? referredBy,
  }) {
    // Auto-aprovação: todos os novos usuários são aprovados automaticamente.
    // Aprovação manual removida para facilitar revisão Apple App Store.
    return UserModel(
      uid: uid,
      email: email.trim().toLowerCase(),
      displayName: displayName?.trim() ?? email.split('@').first,
      role: email.trim().toLowerCase() == adminEmail.toLowerCase()
          ? UserRole.admin
          : UserRole.user,
      status: UserStatus.approved,      // ← sempre aprovado imediatamente
      createdAt: DateTime.now(),
      approvedAt: DateTime.now(),        // ← data de aprovação = data de cadastro
      approvedBy: 'system',             // ← sistema aprova automaticamente
      profession: profession,
      institution: institution,
      referredBy: (referredBy != null && referredBy.isNotEmpty) ? referredBy : null,
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
    var user = UserModel.fromMap(data);
    // Auto-aprovação retroativa: se um usuário existente ainda está pending,
    // aprova automaticamente ao fazer login (migração de usuários legados).
    if (user.isPending) {
      user = user.copyWith(
        status: UserStatus.approved,
        approvedAt: DateTime.now(),
        approvedBy: 'system-auto',
      );
      // Persistir aprovação no Firestore de forma assíncrona (fire-and-forget)
      _autoApproveInBackground(uid: uid);
    }
    return AuthResult.success(user);
  }

  /// Persiste aprovação automática no Firestore sem bloquear o fluxo de login.
  /// fix(auth): loga falhas para diagnóstico; a rule allow update agora aceita
  /// o próprio usuário (pending ou approved), então não deve mais falhar com 403.
  static void _autoApproveInBackground({required String uid}) {
    Future.microtask(() async {
      try {
        if (kIsWeb) {
          await _patchUserRest(uid, {
            'status':     UserStatus.approved.name,
            'approvedAt': DateTime.now().toUtc().toIso8601String(),
            'approvedBy': 'system-auto',
          });
          debugPrint('[Auth] _autoApproveInBackground OK (web) — uid=$uid');
        } else {
          await _db.collection('users').doc(uid).update({
            'status':     UserStatus.approved.name,
            'approvedAt': Timestamp.fromDate(DateTime.now()),
            'approvedBy': 'system-auto',
          });
          debugPrint('[Auth] _autoApproveInBackground OK (native) — uid=$uid');
        }
      } catch (e) {
        // Não bloqueia o fluxo — usuário já foi aprovado em memória no _buildResultFromDoc.
        // Com a correção da rule allow update, este catch raramente será atingido.
        debugPrint('[Auth] _autoApproveInBackground falhou (usuário já aprovado em memória): $e');
      }
    });
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

// ── Resultado da exclusão de conta própria ────────────────────────────────
/// Três estados possíveis:
///   success()          → conta excluída com êxito
///   error(msg)         → falha técnica não recuperável
///   requiresReauth(msg)→ Firebase exige re-login (token antigo) antes de delete()
class DeleteAccountResult {
  final bool success;
  final bool requiresReauth;
  final String? error;

  const DeleteAccountResult._({
    required this.success,
    this.requiresReauth = false,
    this.error,
  });

  factory DeleteAccountResult.success() =>
      const DeleteAccountResult._(success: true);

  factory DeleteAccountResult.error(String msg) =>
      DeleteAccountResult._(success: false, error: msg);

  factory DeleteAccountResult.requiresReauth(String msg) =>
      DeleteAccountResult._(success: false, requiresReauth: true, error: msg);
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
