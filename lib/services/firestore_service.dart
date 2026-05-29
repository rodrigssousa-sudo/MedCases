// firestore_service.dart — dados por usuário no Firestore
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart'
    show kDebugMode, kIsWeb, debugPrint, defaultTargetPlatform, TargetPlatform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../firebase_options.dart';
import '../models/clinical_case_model.dart';
import '../models/clinical_history_model.dart';
import '../models/guide_model.dart';
import 'auth_service.dart';

class FirestoreService {
  // ── Safe type helpers — imunes a TypeError em dart2js release mode ───────
  /// Converte qualquer valor para String sem lançar TypeError.
  static String safeString(dynamic v) => v?.toString() ?? '';

  /// Converte qualquer valor para bool sem lançar TypeError.
  static bool safeBool(dynamic v) => v == true || v?.toString() == 'true';

  /// Converte qualquer valor para int sem lançar TypeError.
  static int safeInt(dynamic v) =>
      v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;

  /// Converte qualquer valor para Map<String,dynamic> sem lançar TypeError.
  static Map<String, dynamic> safeMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

  /// Converte qualquer valor para List<String> sem lançar TypeError.
  static List<String> safeStringList(dynamic v) {
    if (v == null) return const [];
    if (v is! List) return const [];
    return v
        .map((e) => e?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Converte Firestore Timestamp → ISO8601 String, ou retorna string direta.
  /// Necessário porque o SDK Flutter retorna Timestamp para campos de data,
  /// não String — e o toString() de Timestamp não é ISO8601.
  static String safeTimestampToString(dynamic v) {
    if (v == null) return '';
    if (v is String) return v;
    // Firestore Timestamp — acessado via reflexão segura para evitar import circular
    try {
      // Tenta acessar .toDate() se disponível (Timestamp do Firestore)
      final dynamic ts = v;
      final dynamic date = (ts as dynamic).toDate();
      if (date != null) {
        return (date as DateTime).toIso8601String();
      }
    } catch (_) {}
    // Fallback: toString() (pode retornar "Timestamp(seconds=..., nanoseconds=...)")
    return v.toString();
  }

  /// Converte Map do SDK Firestore para Map<String, dynamic> seguro para fromJson.
  /// Converte Timestamp → ISO8601, List<Object> → List<dynamic>, etc.
  /// Protege contra TypeError em dart2js release mode.
  static Map<String, dynamic> sdkDocToSafeMap(Map<String, dynamic> data) {
    final result = <String, dynamic>{};
    data.forEach((key, value) {
      try {
        result[key] = _sanitizeSdkValue(value);
      } catch (_) {
        result[key] = value?.toString() ?? '';
      }
    });
    return result;
  }

  static dynamic _sanitizeSdkValue(dynamic v) {
    if (v == null) return null;
    if (v is String) return v;
    if (v is bool) return v;
    if (v is int) return v;
    if (v is double) return v;
    if (v is List) {
      return v.map(_sanitizeSdkValue).toList();
    }
    if (v is Map<String, dynamic>) {
      return sdkDocToSafeMap(v);
    }
    if (v is Map) {
      return sdkDocToSafeMap(Map<String, dynamic>.from(v));
    }
    // Tenta converter Timestamp do Firestore para ISO8601
    try {
      final dynamic ts = v;
      final dynamic date = ts.toDate();
      if (date is DateTime) return date.toIso8601String();
    } catch (_) {}
    // Qualquer outro tipo: converte para string
    return v.toString();
  }

  /// Versão que aceita qualquer Map — necessário em dart2js release onde
  /// d.data() retorna Map<String, Object?> em vez de Map<String, dynamic>.
  /// Nunca usa cast direto — imune a TypeError.
  static Map<String, dynamic> sdkDocToSafeMapAny(dynamic data) {
    if (data == null) return <String, dynamic>{};
    try {
      if (data is Map<String, dynamic>) return sdkDocToSafeMap(data);
      if (data is Map) {
        final result = <String, dynamic>{};
        data.forEach((key, value) {
          try {
            result[key.toString()] = _sanitizeSdkValue(value);
          } catch (_) {
            result[key.toString()] = value?.toString() ?? '';
          }
        });
        return result;
      }
    } catch (_) {}
    return <String, dynamic>{};
  }

  /// Converte um DocumentSnapshot do SDK em Map<String, dynamic> seguro,
  /// garantindo que o campo 'id' está presente — sem spread literal que
  /// quebra em dart2js release mode (Map<String,Object?> vs Map<String,dynamic>).
  static Map<String, dynamic> sdkDocWithId(dynamic docSnapshot) {
    try {
      final data = sdkDocToSafeMapAny((docSnapshot as dynamic).data());
      data['id'] = (docSnapshot as dynamic).id?.toString() ?? '';
      return data;
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  // Getter lazy — só acessa Firestore APÓS Firebase.initializeApp() completar
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static const _projectId = 'medcases-pro';
  static const _fsBase    = 'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents';
  static String get _firebaseApiKey => DefaultFirebaseOptions.currentPlatform.apiKey;
  static bool get _isIosWeb => kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  // Cooldown por endpoint após 403 — evita retry storm
  static DateTime? _guidesRestRetryAfter;
  static DateTime? _publicHistoriesRestRetryAfter;

  static bool _isRestCoolingDown(DateTime? retryAfter) =>
      retryAfter != null && DateTime.now().isBefore(retryAfter);

  static const _guidesCacheKey = 'clinical_guides_cache_v1';
  static const _guidesCacheFirstOpenResetKey = 'clinical_guides_cache_first_open_reset_v2';
  static const _publicHistoriesCacheKey = 'public_histories_cache_v1';
  static const _restRetryCooldown = Duration(minutes: 2);
  static String _lastGuidesErrorMessage = '';
  static String _lastPublicHistoriesErrorMessage = '';
  static Map<String, dynamic> _cachedAppConfigGlobal = <String, dynamic>{};
  static Future<Map<String, dynamic>>? _appConfigGlobalInFlight;
  static DateTime? _appConfigGlobalRetryAfter;
  static Map<String, dynamic> _cachedAppUpdate = <String, dynamic>{};
  static Future<Map<String, dynamic>>? _appUpdateInFlight;
  static DateTime? _appUpdateRetryAfter;

  // ── Referências por usuário ───────────────────────────────────────────────
  static DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  static CollectionReference<Map<String, dynamic>> _userCases(String uid) =>
      _db.collection('users').doc(uid).collection('cases');

  static CollectionReference<Map<String, dynamic>> _userFavs(String uid) =>
      _db.collection('users').doc(uid).collection('favorites');

  static DocumentReference<Map<String, dynamic>> _userPrefs(String uid) =>
      _db.collection('users').doc(uid).collection('prefs').doc('settings');

  // ── Preferências do usuário ───────────────────────────────────────────────
  static Future<Map<String, dynamic>> loadPrefs(String uid) async {
    try {
      final doc = await _userPrefs(uid).get();
      if (!doc.exists) return {};
      return doc.data() ?? {};
    } catch (_) {
      return {};
    }
  }

  static Future<void> savePrefs(String uid, Map<String, dynamic> prefs) async {
    try {
      await _userPrefs(uid).set(prefs, SetOptions(merge: true));
    } catch (_) {}
  }

  // ── Atualizar perfil do usuário ───────────────────────────────────────────
  static Future<void> updateUserProfile(String uid, {
    String? lang,
    bool? darkMode,
    String? profession,
    String? institution,
    String? displayName,
  }) async {
    final data = <String, dynamic>{};
    if (lang != null) data['lang'] = lang;
    if (darkMode != null) data['darkMode'] = darkMode;
    if (profession != null) data['profession'] = profession;
    if (institution != null) data['institution'] = institution;
    if (displayName != null) data['displayName'] = displayName;
    if (data.isEmpty) return;
    try {
      await _userDoc(uid).update(data);
    } catch (_) {}
  }

  // _isRetryBlocked removido: idêntico a _isRestCoolingDown (consolidado)

  // ── REST headers helpers ──────────────────────────────────────────────────
  //
  // CORS NOTE: Firestore REST aceita `key=<apiKey>` na URL E/OU
  // `Authorization: Bearer <idToken>` no header.
  //
  // Nunca enviar `X-Firebase-API-Key` ou `Content-Type` em requisições GET:
  //   • X-Firebase-API-Key é header customizado → força preflight OPTIONS que
  //     o Firestore CORS não autoriza → "No 'Access-Control-Allow-Origin' header"
  //   • Content-Type em GET body=null também pode provocar preflight desnecessário.
  // Regra: GET usa SOMENTE Authorization; POST/PATCH usa Authorization+Content-Type.

  /// Headers para requisições GET ao Firestore REST (sem corpo).
  /// Inclui Authorization apenas se o token for não-vazio.
  static Map<String, String> _restGetHeaders(String token) {
    if (token.isNotEmpty) return {'Authorization': 'Bearer $token'};
    return const {};
  }

  // Nota: _restHeaders() foi removido — todas as chamadas de escrita (PATCH/POST/DELETE)
  // usam headers inline: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}.
  // Isso torna cada chamada explícita e evita confusão sobre quando Content-Type é enviado.

  /// Decodifica o payload REST do Firestore para Map<String, dynamic>.
  /// USA APENAS safe helpers — zero casts diretos — imune a TypeError em release.
  static Map<String, dynamic> _decodeFirestoreFields(String bodyText) {
    try {
      final body   = safeMap(jsonDecode(bodyText));
      final fields = safeMap(body['fields']);
      final data   = <String, dynamic>{};

      fields.forEach((key, rawValue) {
        try {
          final value = safeMap(rawValue);
          if (value.containsKey('stringValue')) {
            data[key] = safeString(value['stringValue']);
          } else if (value.containsKey('booleanValue')) {
            data[key] = safeBool(value['booleanValue']);
          } else if (value.containsKey('integerValue')) {
            data[key] = safeInt(value['integerValue']);
          } else if (value.containsKey('doubleValue')) {
            final raw = value['doubleValue'];
            data[key] = raw is double
                ? raw
                : (raw is num
                    ? raw.toDouble()
                    : double.tryParse(raw?.toString() ?? '') ?? 0.0);
          } else if (value.containsKey('arrayValue')) {
            final arrRaw  = safeMap(value['arrayValue']);
            final valsList = arrRaw['values'];
            final items   = valsList is List ? valsList : const <dynamic>[];
            data[key] = items.map((item) {
              final m = safeMap(item);
              if (m.containsKey('stringValue'))  return safeString(m['stringValue']);
              if (m.containsKey('integerValue')) return safeString(m['integerValue']);
              if (m.containsKey('booleanValue')) return safeBool(m['booleanValue']).toString();
              return safeString(m.isNotEmpty ? m.values.first : '');
            }).toList();
          } else if (value.containsKey('mapValue')) {
            data[key] = safeMap(safeMap(value['mapValue'])['fields']);
          } else if (value.containsKey('nullValue')) {
            data[key] = null;
          }
        } catch (_) {
          data[key] = null; // campo malformado — não quebra os demais
        }
      });

      return data;
    } catch (e) {
      debugPrint('[FirestoreService] _decodeFirestoreFields ERRO: $e');
      return <String, dynamic>{};
    }
  }

  static Future<Map<String, dynamic>> _loadAppConfigGlobalData() async {
    if (_cachedAppConfigGlobal.isNotEmpty) {
      return Map<String, dynamic>.from(_cachedAppConfigGlobal);
    }
    if (_isRestCoolingDown(_appConfigGlobalRetryAfter)) {
      debugPrint('[FirestoreService] app_config/global em cooldown — retornando cache');
      return Map<String, dynamic>.from(_cachedAppConfigGlobal);
    }
    final inFlight = _appConfigGlobalInFlight;
    if (inFlight != null) return inFlight;

    final future = () async {
      try {
        // SDK sempre — web e nativo. app_config/global requer admin token via rules.
        // Não usar REST neste endpoint: expõe a API Key do Gemini em logs de rede.
        // Se o SDK retornar permission-denied: comportamento esperado para não-admin,
        // NÃO aplica cooldown (ver tratamento abaixo).
        try {
          final doc = await _db.collection('app_config').doc('global').get()
              .timeout(const Duration(seconds: 4));
          debugPrint('[FirestoreService] app_config/global SDK exists=${doc.exists}');
          // safeMap: protege contra tipos inesperados do SDK em dart2js release
          final data = doc.exists ? safeMap(doc.data()) : <String, dynamic>{};
          if (data.isNotEmpty) {
            _cachedAppConfigGlobal = Map<String, dynamic>.from(data);
            _appConfigGlobalRetryAfter = null;
          }
          return Map<String, dynamic>.from(data);
        } on FirebaseException catch (e) {
          // permission-denied = regras bloquearam (usuário não é admin).
          // NÃO aplica cooldown para permission-denied: esse erro ocorre SEMPRE
          // para usuários não-admin e aplicar cooldown impede retentativas após
          // eventual elevação de privilégio ou mudança de conta.
          // O cooldown é aplicado apenas para erros de rede/timeout.
          if (e.code == 'permission-denied') {
            debugPrint('[FirestoreService] app_config/global permission-denied (usuário não é admin — comportamento esperado)');
          } else {
            debugPrint('[FirestoreService] app_config/global SDK erro: ${e.code}');
            // Erros de rede/quota: aplica cooldown curto para evitar retry storm
            _appConfigGlobalRetryAfter = DateTime.now().add(const Duration(seconds: 30));
          }
          return Map<String, dynamic>.from(_cachedAppConfigGlobal);
        }
      } catch (e) {
        debugPrint('[FirestoreService] _loadAppConfigGlobalData ERRO: $e');
        return Map<String, dynamic>.from(_cachedAppConfigGlobal);
      } finally {
        _appConfigGlobalInFlight = null;
      }
    }();

    _appConfigGlobalInFlight = future;
    return future;
  }

  // ── Chave OpenAI do APP (compartilhada) ──────────────────────────────────
  /// Carrega a chave OpenAI global do app, salva pelo administrador.
  /// Armazenada em app_config/global campo 'openAiKey'.
  /// Todos os usuários aprovados usam essa chave — nenhuma configuração manual.
  static Future<String> loadAppAiKey() async {
    try {
      final data = await _loadAppConfigGlobalData();
      final key = safeString(data['openAiKey']).trim();
      debugPrint('[FirestoreService] loadAppAiKey key.isNotEmpty=${key.isNotEmpty}');
      return key;
    } catch (e) {
      debugPrint('[FirestoreService] loadAppAiKey ERRO: $e');
      return '';
    }
  }

  // ── Chave Gemini API do APP (compartilhada) ───────────────────────────────
  /// Carrega a Gemini API Key global do app, salva pelo administrador.
  /// Armazenada em app_config/global campo 'apiKey'.
  /// Usada diretamente nas chamadas à API do Gemini (sem OAuth token).
  static Future<String> loadGeminiApiKey() async {
    try {
      final data = await _loadAppConfigGlobalData();
      final key = safeString(data['apiKey']).trim().isNotEmpty
          ? safeString(data['apiKey']).trim()
          : safeString(data['geminiApiKey']).trim();
      debugPrint('[FirestoreService] loadGeminiApiKey key.isNotEmpty=${key.isNotEmpty}');
      return key;
    } catch (e) {
      debugPrint('[FirestoreService] loadGeminiApiKey ERRO: $e');
      return '';
    }
  }

  /// Salva a Gemini API Key global do app em app_config/global.
  static Future<void> saveGeminiApiKey(String key) async {
    try {
      await _db.collection('app_config').doc('global').set(
        {'apiKey': key.trim()},
        SetOptions(merge: true),
      );
      debugPrint('[FirestoreService] saveGeminiApiKey OK');
    } catch (e) {
      debugPrint('[FirestoreService] saveGeminiApiKey ERRO: $e');
    }
  }

  // ── Chave OpenAI — vinculada ao perfil do usuário no Firestore ────────────
  /// Carrega a chave OpenAI do perfil do usuário (fallback individual).
  /// Armazenada em users/{uid}/prefs/settings campo 'openAiKey'.
  static Future<String> loadAiKey(String uid) async {
    try {
      final doc = await _userPrefs(uid).get();
      if (!doc.exists) return '';
      return safeString(doc.data()?['openAiKey']);
    } catch (_) {
      return '';
    }
  }

  /// Salva a chave OpenAI global do app em app_config/global.
  /// Todos os usuários aprovados passam a usar essa chave automaticamente.
  static Future<void> saveAppAiKey(String key) async {
    try {
      await _db.collection('app_config').doc('global').set(
        {'openAiKey': key.trim()},
        SetOptions(merge: true),
      );
      debugPrint('[FirestoreService] saveAppAiKey OK → app_config/global');
    } catch (e) {
      debugPrint('[FirestoreService] saveAppAiKey ERRO: $e');
    }
  }

  /// Salva (ou remove) a chave OpenAI no perfil Firestore do usuário.
  /// Passa [key] vazio para remover a chave (modo local).
  static Future<void> saveAiKey(String uid, String key) async {
    try {
      await _userPrefs(uid).set(
        {'openAiKey': key},
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  static Future<void> updateDisplayName(String uid, String displayName) async {
    try {
      await _userDoc(uid).update({'displayName': displayName});
    } catch (_) {}
  }

  // ── Favoritos de fármacos ─────────────────────────────────────────────────
  static Future<Set<String>> loadFavDrugs(String uid) async {
    try {
      final doc = await _userFavs(uid).doc('drugs').get();
      if (!doc.exists) return {};
      return safeStringList(doc.data()?['ids']).toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveFavDrugs(String uid, Set<String> ids) async {
    try {
      await _userFavs(uid).doc('drugs').set({'ids': ids.toList()});
    } catch (_) {}
  }

  // ── Favoritos de protocolos ───────────────────────────────────────────────
  static Future<Set<String>> loadFavProtocols(String uid) async {
    try {
      final doc = await _userFavs(uid).doc('protocols').get();
      if (!doc.exists) return {};
      return safeStringList(doc.data()?['ids']).toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveFavProtocols(String uid, Set<String> ids) async {
    try {
      await _userFavs(uid).doc('protocols').set({'ids': ids.toList()});
    } catch (_) {}
  }

  // ── Favoritos de prescrições ──────────────────────────────────────────────
  static Future<Set<String>> loadFavPrescriptions(String uid) async {
    try {
      final doc = await _userFavs(uid).doc('prescriptions').get();
      if (!doc.exists) return {};
      return safeStringList(doc.data()?['ids']).toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveFavPrescriptions(String uid, Set<String> ids) async {
    try {
      await _userFavs(uid).doc('prescriptions').set({'ids': ids.toList()});
    } catch (_) {}
  }

  // ── Histórico de sessões IA ───────────────────────────────────────────────
  static CollectionReference<Map<String, dynamic>> _userAiHistory(String uid) =>
      _db.collection('users').doc(uid).collection('ai_chat_history');

  /// Salva UMA sessão de chat no Firestore (upsert por session.id).
  static Future<void> saveAiSession(String uid, Map<String, dynamic> session) async {
    try {
      final id = safeString(session['id']);
      if (id.isEmpty) return;
      await _userAiHistory(uid).doc(id).set(session);
    } catch (_) {}
  }

  /// Deleta uma sessão de chat pelo id.
  static Future<void> deleteAiSession(String uid, String sessionId) async {
    try {
      await _userAiHistory(uid).doc(sessionId).delete();
    } catch (_) {}
  }

  /// Carrega as últimas 20 sessões, ordenadas por updatedAt desc.
  static Future<List<Map<String, dynamic>>> loadAiSessions(String uid) async {
    try {
      final snap = await _userAiHistory(uid)
          .orderBy('updatedAt', descending: true)
          .limit(20)
          .get();
      return snap.docs.map((d) => d.data()).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Recentes cross-device ─────────────────────────────────────────────────
  static DocumentReference<Map<String, dynamic>> _userRecents(String uid) =>
      _db.collection('users').doc(uid).collection('prefs').doc('recents');

  /// Salva a lista de recentes no Firestore (lista de strings "type|id|title").
  static Future<void> saveRecents(String uid, List<String> recents) async {
    try {
      await _userRecents(uid).set({'items': recents, 'updatedAt': FieldValue.serverTimestamp()});
    } catch (_) {}
  }

  /// Carrega a lista de recentes do Firestore.
  static Future<List<String>> loadRecents(String uid) async {
    try {
      final doc = await _userRecents(uid).get();
      if (!doc.exists) return [];
      return safeStringList(doc.data()?['items']);
    } catch (_) {
      return [];
    }
  }

  // ── Favoritos de casos clínicos ───────────────────────────────────────────
  static Future<Set<String>> loadFavCases(String uid) async {
    try {
      final doc = await _userFavs(uid).doc('fav_cases').get();
      if (!doc.exists) return {};
      return safeStringList(doc.data()?['ids']).toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveFavCases(String uid, Set<String> ids) async {
    try {
      await _userFavs(uid).doc('fav_cases').set({'ids': ids.toList()});
    } catch (_) {}
  }

  // ── Casos clínicos do usuário ─────────────────────────────────────────────
  static Future<List<ClinicalCaseModel>> loadCases(String uid) async {
    try {
      final snap = await _userCases(uid)
          .where('isCustom', isEqualTo: true)
          .get();
      final cases = snap.docs
          .map((d) => ClinicalCaseModel.fromJson(sdkDocToSafeMap(d.data())))
          .toList();
      cases.sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
      return cases;
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveCase(String uid, ClinicalCaseModel c) async {
    try {
      await _userCases(uid).doc(c.id).set(c.toJson());
    } catch (_) {}
  }

  static Future<void> deleteCase(String uid, String caseId) async {
    try {
      await _userCases(uid).doc(caseId).delete();
    } catch (_) {}
  }

  // ── Stream em tempo real dos casos ───────────────────────────────────────
  static Stream<List<ClinicalCaseModel>> casesStream(String uid) {
    return _userCases(uid)
        .where('isCustom', isEqualTo: true)
        .snapshots()
        .map((snap) {
      final cases = snap.docs
          .map((d) => ClinicalCaseModel.fromJson(sdkDocToSafeMap(d.data())))
          .toList();
      cases.sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
      return cases;
    });
  }

  // ── Histórias clínicas do usuário ────────────────────────────────────────
  static CollectionReference<Map<String, dynamic>> _userHistories(String uid) =>
      _db.collection('users').doc(uid).collection('clinical_histories');

  static CollectionReference<Map<String, dynamic>> get _publicHistories =>
      _db.collection('public_histories');

  static void _debugPublicHistories(String message) {
    if (kDebugMode) debugPrint('[FirestoreService.publicHistories] $message');
  }

  static String get lastPublicHistoriesErrorMessage => _lastPublicHistoriesErrorMessage;

  static void _setPublicHistoriesError(String message) {
    _lastPublicHistoriesErrorMessage = message.trim();
    if (_lastPublicHistoriesErrorMessage.isNotEmpty) {
      _debugPublicHistories('error=$_lastPublicHistoriesErrorMessage');
    }
  }

  static void _clearPublicHistoriesError() {
    _lastPublicHistoriesErrorMessage = '';
  }

  static List<ClinicalHistoryModel> _normalizePublicHistories(
    Iterable<ClinicalHistoryModel> histories,
  ) {
    final list = histories
        .where((h) => h.id.trim().isNotEmpty)
        .toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list.take(50).toList();
  }

  static Future<List<ClinicalHistoryModel>> loadCachedPublicHistories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_publicHistoriesCacheKey);
      if (raw == null || raw.trim().isEmpty) {
        return const <ClinicalHistoryModel>[];
      }

      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <ClinicalHistoryModel>[];
      }

      final cached = _normalizePublicHistories(
        decoded.whereType<Map>().map(
          (item) => ClinicalHistoryModel.fromJson(
            Map<String, dynamic>.from(item),
          ),
        ),
      );
      _debugPublicHistories('cache read count=${cached.length}');
      return cached;
    } catch (e) {
      _debugPublicHistories('cache read failed error=$e');
      return const <ClinicalHistoryModel>[];
    }
  }

  static Future<void> _saveCachedPublicHistories(
    List<ClinicalHistoryModel> histories,
  ) async {
    if (histories.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _publicHistoriesCacheKey,
        jsonEncode(histories.map((h) => h.toJson()).toList()),
      );
      _debugPublicHistories('cache write count=${histories.length}');
    } catch (e) {
      _debugPublicHistories('cache write failed error=$e');
    }
  }

  // ── Helpers REST para public_histories ───────────────────────────────────

  /// Converte um documento Firestore REST em Map<String, dynamic> Dart.
  static Map<String, dynamic> _restDocToMap(Map<String, dynamic> doc) {
    final fields = safeMap(doc['fields']);
    return _decodeFields(fields);
  }

  static Map<String, dynamic> _decodeFields(Map<String, dynamic> fields) {
    final result = <String, dynamic>{};
    fields.forEach((key, val) {
      try {
        if (val is Map<String, dynamic>) {
          result[key] = _decodeValue(val);
        } else if (val is Map) {
          result[key] = _decodeValue(Map<String, dynamic>.from(val));
        } else {
          // Valor inesperado — usa direto sem decodificação Firestore
          result[key] = val;
        }
      } catch (_) {
        result[key] = null; // campo malformado — não quebra o documento inteiro
      }
    });
    return result;
  }

  static dynamic _decodeValue(Map<String, dynamic> v) {
    if (v.containsKey('stringValue'))  return v['stringValue'];
    if (v.containsKey('booleanValue')) return v['booleanValue'] == true;
    if (v.containsKey('integerValue')) {
      final raw = v['integerValue'];
      return raw is int ? raw : int.tryParse(raw?.toString() ?? '') ?? 0;
    }
    if (v.containsKey('doubleValue')) {
      final raw = v['doubleValue'];
      return raw is double ? raw : (raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '') ?? 0.0);
    }
    if (v.containsKey('nullValue'))    return null;
    if (v.containsKey('mapValue')) {
      try {
        final mapVal = v['mapValue'];
        final f = safeMap(mapVal is Map ? mapVal['fields'] : null);
        return _decodeFields(f);
      } catch (_) { return <String, dynamic>{}; }
    }
    if (v.containsKey('arrayValue')) {
      try {
        final arrVal = v['arrayValue'];
        final rawVals = (arrVal is Map) ? arrVal['values'] : null;
        final vals = rawVals is List ? rawVals : const <dynamic>[];
        return vals
            .whereType<Map>()
            .map((e) => _decodeValue(
                  e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e),
                ))
            .toList();
      } catch (_) { return <dynamic>[]; }
    }
    return null;
  }

  /// Converte Map<String, dynamic> Dart em payload de campos REST Firestore.
  static Map<String, dynamic> _encodeFields(Map<String, dynamic> data) {
    final result = <String, dynamic>{};
    data.forEach((key, val) {
      result[key] = _encodeValue(val);
    });
    return result;
  }

  static Map<String, dynamic> _encodeValue(dynamic val) {
    if (val == null)          return {'nullValue': null};
    if (val is bool)          return {'booleanValue': val};
    if (val is int)           return {'integerValue': val.toString()};
    if (val is double)        return {'doubleValue': val};
    if (val is String)        return {'stringValue': val};
    if (val is List) {
      return {'arrayValue': {'values': val.map(_encodeValue).toList()}};
    }
    if (val is Map<String, dynamic>) {
      return {'mapValue': {'fields': _encodeFields(val)}};
    }
    return {'stringValue': val.toString()};
  }

  static Future<List<ClinicalHistoryModel>> loadHistories(String uid) async {
    try {
      // Sem orderBy — evita índice composto. Ordenação em memória.
      final snap = await _userHistories(uid).get();
      final list = snap.docs
          .map((d) => ClinicalHistoryModel.fromJson(sdkDocToSafeMap(d.data())))
          .toList();
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return list;
    } catch (_) {
      return [];
    }
  }

  /// Salva a história do usuário e, se pública, espelha em public_histories.
  /// Usa REST no web e SDK no nativo para máxima compatibilidade.
  /// Retorna o uploadedAt definitivo.
  static Future<String?> saveHistory(String uid, ClinicalHistoryModel h) async {
    // 1 — Salva na sub-coleção privada do usuário (SDK — sempre funciona)
    await _userHistories(uid).doc(h.id).set(h.toJson());

    if (h.isPublic) {
      final uploadedAt = h.uploadedAt.isNotEmpty
          ? h.uploadedAt
          : DateTime.now().toIso8601String();

      final publicData = h.toJson();
      publicData['uploadedAt'] = uploadedAt;
      publicData['isHidden']   = publicData['isHidden'] ?? false;

      if (kIsWeb) {
        // Web: REST PATCH (não depende de WebSocket do SDK)
        await _savePublicHistoryRest(h.id, publicData);
      } else {
        await _publicHistories.doc(h.id).set(publicData);
      }
      return uploadedAt;
    } else {
      // Não é mais pública: remove da coleção global
      if (kIsWeb) {
        await _deletePublicHistoryRest(h.id);
      } else {
        try { await _publicHistories.doc(h.id).delete(); } catch (_) {}
      }
      return null;
    }
  }

  /// Grava/atualiza um documento em public_histories via REST (web).
  static Future<void> _savePublicHistoryRest(
      String docId, Map<String, dynamic> data) async {
    try {
      final token = await AuthService.getAdminToken();
      if (token.isEmpty) return;
      final fields = _encodeFields(data);
      // Monta updateMask com todos os campos
      final mask = data.keys
          .map((k) => 'updateMask.fieldPaths=${Uri.encodeComponent(k)}')
          .join('&');
      await http.patch(
        Uri.parse('$_fsBase/public_histories/$docId?$mask'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'fields': fields}),
      );
    } catch (_) {}
  }

  /// Remove um documento de public_histories via REST (web).
  static Future<void> _deletePublicHistoryRest(String docId) async {
    try {
      final token = await AuthService.getAdminToken();
      if (token.isEmpty) return;
      await http.delete(
        Uri.parse('$_fsBase/public_histories/$docId'),
        headers: {'Authorization': 'Bearer $token'},
      );
    } catch (_) {}
  }

  static Future<void> deleteHistory(String uid, String hid, {bool wasPublic = false}) async {
    try {
      await _userHistories(uid).doc(hid).delete();
      if (wasPublic) {
        try { await _publicHistories.doc(hid).delete(); } catch (_) {}
      }
    } catch (_) {}
  }

  // ── Moderação: ocultar HC pública (reversível) ──────────────────────────
  static Future<void> hideHistory(String historyId, String moderatorUid) async {
    try {
      final now = DateTime.now().toIso8601String();
      await _publicHistories.doc(historyId).update({
        'isHidden': true,
        'hiddenBy': moderatorUid,
        'hiddenAt': now,
      });
    } catch (_) {}
  }

  // ── Moderação: desocultar HC pública ─────────────────────────────────────
  static Future<void> unhideHistory(String historyId) async {
    try {
      await _publicHistories.doc(historyId).update({
        'isHidden': false,
        'hiddenBy': null,
        'hiddenAt': null,
      });
    } catch (_) {}
  }

  // ── Moderação: admin/supervisor excluir HC pública de outro usuário ───────
  static Future<void> adminDeletePublicHistory(String historyId) async {
    try {
      await _publicHistories.doc(historyId).delete();
    } catch (_) {}
  }

  static Future<List<ClinicalHistoryModel>> _loadPublicHistoriesSdk({Source? source}) async {
    try {
      // Filtra isPublic=true via query SDK — reduz transferência e respeita rules.
      // isHidden é filtrado em memória (campo opcional, pode estar ausente).
      final query = _publicHistories
          .where('isPublic', isEqualTo: true)
          .limit(100);
      final snap = source == null
          ? await query.get().timeout(const Duration(seconds: 8))
          : await query
              .get(GetOptions(source: source))
              .timeout(const Duration(seconds: 8));
      final list = _normalizePublicHistories(
        snap.docs
            .map((d) => ClinicalHistoryModel.fromJson(sdkDocWithId(d)))
            .where((h) => !h.isHidden),
      );
      if (list.isNotEmpty) {
        await _saveCachedPublicHistories(list);
        _clearPublicHistoriesError();
      }
      _debugPublicHistories('sdk load count=${list.length} source=${source ?? 'default'}');
      return list;
    } on FirebaseException catch (e) {
      // permission-denied: rules bloquearam — não logar como erro crítico
      if (e.code == 'permission-denied') {
        _setPublicHistoriesError('Acesso negado (verifique Firestore Rules para public_histories)');
        _debugPublicHistories('sdk permission-denied source=${source ?? 'default'}');
      } else {
        _setPublicHistoriesError('SDK public_histories erro: ${e.code}');
        _debugPublicHistories('sdk firebase error ${e.code} source=${source ?? 'default'}');
      }
      return [];
    } catch (e) {
      _setPublicHistoriesError('SDK public_histories falhou (${source ?? 'default'}): $e');
      _debugPublicHistories('sdk load failed source=${source ?? 'default'} error=$e');
      return [];
    }
  }

  static Future<List<ClinicalHistoryModel>> loadPublicHistories({bool forceRemote = false}) async {
    final cached = await loadCachedPublicHistories();
    _debugPublicHistories(
      'loadPublicHistories start forceRemote=$forceRemote kIsWeb=$kIsWeb cached=${cached.length}',
    );

    // ── ETAPA 1: SDK Firestore (Chrome, Firefox, Safari — qualquer browser) ──
    // O SDK funciona em todos os browsers quando as Firestore Rules permitem.
    // Antes só era tentado fora do iOS Web — erro: Safari também tem SDK funcional
    // se as rules estiverem corretas. iOS Web usava REST direto → 403 inevitável
    // quando public_histories exige autenticação nas rules.
    final sdkServer = await _loadPublicHistoriesSdk(source: Source.server);
    if (sdkServer.isNotEmpty) return sdkServer;

    final sdkDefault = await _loadPublicHistoriesSdk();
    if (sdkDefault.isNotEmpty) return sdkDefault;

    _debugPublicHistories('sdk failed — trying REST fallback');

    // ── ETAPA 2: REST fallback — apenas se SDK falhou E cooldown não ativo ──
    if (!_isRestCoolingDown(_publicHistoriesRestRetryAfter)) {
      final rest = await _loadPublicHistoriesRest();
      if (rest.isNotEmpty) return rest;
      // Se REST retornou 403, aplica cooldown para evitar retry storm
      final restError = lastPublicHistoriesErrorMessage;
      if (restError.contains('HTTP 403') || restError.contains('403')) {
        _publicHistoriesRestRetryAfter = DateTime.now().add(_restRetryCooldown);
        _debugPublicHistories('REST 403 — cooldown até $_publicHistoriesRestRetryAfter');
      }
    } else {
      _debugPublicHistories('REST em cooldown — pulando');
    }

    // ── ETAPA 3: Cache local ─────────────────────────────────────────────────
    if (cached.isNotEmpty) {
      _debugPublicHistories('returning cached count=${cached.length}');
      return cached;
    }

    _debugPublicHistories('returning empty error=${lastPublicHistoriesErrorMessage.isNotEmpty}');
    return const <ClinicalHistoryModel>[];
  }

  /// Leitura pública via Firestore REST API — fallback autenticado.
  /// NUNCA chama REST sem token: se o usuário não estiver logado, retorna []
  /// imediatamente sem fazer nenhuma requisição de rede.
  /// Isso evita o 403 que o código compilado (avE() em main.dart.js) gerava
  /// ao chamar GET /public_histories?pageSize=100 sem Authorization header.
  static Future<List<ClinicalHistoryModel>> _loadPublicHistoriesRest() async {
    // ── GUARD: sem usuário logado → sem REST → evita 403 garantido ───────────
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _debugPublicHistories('rest skipped — no authenticated user');
      // Não define erro: ausência de login não é um erro de rede
      return const <ClinicalHistoryModel>[];
    }

    // Obtém token — se falhar, aborta (não faz REST sem auth)
    String? token;
    try {
      token = await currentUser.getIdToken();
    } catch (e) {
      _debugPublicHistories('rest skipped — getIdToken failed: $e');
      return const <ClinicalHistoryModel>[];
    }

    if (token == null || token.isEmpty) {
      _debugPublicHistories('rest skipped — token empty after getIdToken()');
      return const <ClinicalHistoryModel>[];
    }

    final apiKey = _firebaseApiKey;
    final authHeaders = <String, String>{'Authorization': 'Bearer $token'};

    Future<http.Response> doGet({Map<String, String>? extraHeaders}) {
      // GET: SOMENTE Authorization — nunca Content-Type nem X-Firebase-API-Key
      // (headers customizados causam preflight CORS que Firestore rejeita)
      final hdrs = <String, String>{...authHeaders, ...?extraHeaders};
      return http
          .get(
            Uri.parse('$_fsBase/public_histories?pageSize=100&key=$apiKey'),
            headers: hdrs,
          )
          .timeout(const Duration(seconds: 12));
    }

    List<ClinicalHistoryModel> parseResponse(http.Response resp) {
      // safeMap/safeString: sem casts diretos \u2014 imune a TypeError em dart2js release
      final body = safeMap(jsonDecode(resp.body));
      final docsList = body['documents'];
      final documents = docsList is List ? docsList : const <dynamic>[];
      final parsed = <ClinicalHistoryModel>[];
      for (final doc in documents) {
        try {
          final rawDoc = safeMap(doc);
          final data = _restDocToMap(rawDoc);
          // Garante que o id est\u00e1 presente (REST usa o campo 'name' como path)
          if (data['id'] == null || safeString(data['id']).isEmpty) {
            final name = safeString(rawDoc['name']);
            data['id'] = name.isNotEmpty ? name.split('/').last : '';
          }
          parsed.add(ClinicalHistoryModel.fromJson(data));
        } catch (e, st) {
          // Documento malformado — loga e pula; não quebra os demais
          _debugPublicHistories('REST parse: documento ignorado por erro — $e\n$st');
        }
      }
      return _normalizePublicHistories(parsed);
    }

    try {
      _debugPublicHistories('rest load start kIsWeb=$kIsWeb');
      var resp = await doGet();
      _debugPublicHistories('rest load initial status=${resp.statusCode}');

      // 401/403: tenta refresh do token UMA vez
      if (resp.statusCode == 401 || resp.statusCode == 403) {
        String? refreshed;
        try {
          refreshed = await FirebaseAuth.instance.currentUser?.getIdToken(true);
        } catch (_) {}
        if (refreshed != null && refreshed.isNotEmpty) {
          _debugPublicHistories('rest auth retry with refreshed token');
          resp = await doGet(extraHeaders: {'Authorization': 'Bearer $refreshed'});
          _debugPublicHistories('rest load retry status=${resp.statusCode}');
        } else {
          // Token refresh falhou — aplica cooldown imediatamente
          _publicHistoriesRestRetryAfter = DateTime.now().add(_restRetryCooldown);
          _setPublicHistoriesError('REST public_histories HTTP ${resp.statusCode}: sem token após refresh');
          _debugPublicHistories('rest 403 e refresh falhou — cooldown aplicado');
          return const <ClinicalHistoryModel>[];
        }
      }

      if (resp.statusCode != 200) {
        final snippet = resp.body.length > 220 ? resp.body.substring(0, 220) : resp.body;
        _setPublicHistoriesError('REST public_histories HTTP ${resp.statusCode}: $snippet');
        // Aplica cooldown em qualquer erro HTTP (403, 401, 500...) para evitar retry storm.
        // O cooldown de 2 minutos garante que não haverá loop infinito de tentativas.
        _publicHistoriesRestRetryAfter = DateTime.now().add(_restRetryCooldown);
        _debugPublicHistories('REST ${resp.statusCode} — cooldown 2min aplicado');
        return const <ClinicalHistoryModel>[];
      }

      final list = parseResponse(resp);
      if (list.isNotEmpty) {
        await _saveCachedPublicHistories(list);
        _clearPublicHistoriesError();
      }
      _debugPublicHistories('rest load count=${list.length}');
      return list;
    } on TimeoutException catch (e) {
      _setPublicHistoriesError('REST public_histories timeout: $e');
      _debugPublicHistories('rest load timeout error=$e');
      return const <ClinicalHistoryModel>[];
    } catch (e) {
      _setPublicHistoriesError('REST public_histories falhou: $e');
      _debugPublicHistories('rest load failed error=$e');
      return const <ClinicalHistoryModel>[];
    }
  }

  static Stream<List<ClinicalHistoryModel>> historiesStream(String uid) {
    return _userHistories(uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ClinicalHistoryModel.fromJson(sdkDocToSafeMap(d.data())))
            .toList());
  }

  // ── Último paciente (cockpit) ─────────────────────────────────────────────
  static Future<Map<String, dynamic>?> loadLastPatient(String uid) async {
    try {
      final doc = await _userDoc(uid)
          .collection('prefs')
          .doc('last_patient')
          .get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveLastPatient(String uid, Map<String, dynamic> data) async {
    try {
      await _userDoc(uid)
          .collection('prefs')
          .doc('last_patient')
          .set(data, SetOptions(merge: true));
    } catch (_) {}
  }

  // ── Manutenção do sistema ─────────────────────────────────────────────────
  static DocumentReference<Map<String, dynamic>> get _maintenanceDoc =>
      _db.collection('app_config').doc('maintenance');

  /// Stream unificado do estado de manutenção.
  /// Web  → REST polling a cada 10 s (sem WebSocket/SDK)
  /// Nativo → SDK Firestore com snapshots() em tempo real
  /// Emite Map com: { enabled: bool, message: String, updatedBy: String, updatedAt: String }
  static Stream<Map<String, dynamic>> maintenanceStream() {
    if (kIsWeb) return _maintenanceStreamRest();
    return _maintenanceDoc.snapshots().map((snap) {
      if (!snap.exists) return {'enabled': false};
      return snap.data() ?? {'enabled': false};
    });
  }

  /// REST polling para manutenção — busca app_config/maintenance a cada 10 s.
  static Stream<Map<String, dynamic>> _maintenanceStreamRest() {
    late StreamController<Map<String, dynamic>> ctrl;
    Timer? timer;

    Future<void> fetch() async {
      try {
        final token = await AuthService.getAdminToken();
        if (token.isEmpty) {
          if (!ctrl.isClosed) ctrl.add({'enabled': false});
          return;
        }

        // GET: apenas Authorization (sem Content-Type/custom headers — evita preflight CORS)
        final resp = await http.get(
          Uri.parse('$_fsBase/app_config/maintenance'),
          headers: _restGetHeaders(token),
        );

        if (resp.statusCode == 404) {
          if (!ctrl.isClosed) ctrl.add({'enabled': false});
          return;
        }

        if (resp.statusCode != 200) return;

        // safeMap: sem casts diretos — imune a TypeError em dart2js release
        final body   = safeMap(jsonDecode(resp.body));
        final fields = safeMap(body['fields']);
        final data   = <String, dynamic>{};

        fields.forEach((key, value) {
          final v = safeMap(value);
          if (v.containsKey('booleanValue')) {
            data[key] = safeBool(v['booleanValue']);
          } else if (v.containsKey('stringValue')) {
            data[key] = safeString(v['stringValue']);
          } else if (v.containsKey('nullValue')) {
            data[key] = null;
          }
        });

        if (!ctrl.isClosed) ctrl.add(data.isEmpty ? {'enabled': false} : data);
      } catch (_) {
        if (!ctrl.isClosed) ctrl.add({'enabled': false});
      }
    }

    ctrl = StreamController<Map<String, dynamic>>(
      onListen: () {
        fetch();
        timer = Timer.periodic(const Duration(seconds: 10), (_) => fetch());
      },
      onCancel: () {
        timer?.cancel();
        timer = null;
      },
    );

    return ctrl.stream;
  }

  /// Ativa ou desativa o modo de manutenção.
  /// Web  → REST PATCH (sem SDK)
  /// Nativo → SDK Firestore set()
  static Future<void> setMaintenance({
    required bool enabled,
    required String updatedBy,
    String message = '',
  }) async {
    if (kIsWeb) {
      await _setMaintenanceRest(
        enabled: enabled,
        updatedBy: updatedBy,
        message: message,
      );
      return;
    }
    await _maintenanceDoc.set({
      'enabled': enabled,
      'message': message.trim(),
      'updatedBy': updatedBy,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // APP UPDATES — notificação de novidades
  // ═══════════════════════════════════════════════════════════════════════════

  /// Lê o documento app_updates/current via REST (web) ou SDK (nativo).
  static Future<Map<String, dynamic>> loadAppUpdate() async {
    if (_cachedAppUpdate.isNotEmpty) {
      return Map<String, dynamic>.from(_cachedAppUpdate);
    }
    if (_isRestCoolingDown(_appUpdateRetryAfter)) {
      debugPrint('[FirestoreService] app_updates/current em cooldown — retornando cache');
      return Map<String, dynamic>.from(_cachedAppUpdate);
    }
    final inFlight = _appUpdateInFlight;
    if (inFlight != null) return inFlight;

    final future = () async {
      try {
        // ── SDK primeiro (web e nativo) ──────────────────────────────────────
        // Rules: allow read if isAuthed() — qualquer usuário logado pode ler.
        // Usar SDK evita o 403 do REST que aparecia nos logs quando as rules
        // exigiam autenticação mas o REST não enviava token corretamente.
        try {
          final doc = await _db.collection('app_updates').doc('current').get()
              .timeout(const Duration(seconds: 4));
          // safeMap: protege contra tipos inesperados do SDK em dart2js release
          final data = doc.exists ? safeMap(doc.data()) : <String, dynamic>{};
          if (data.isNotEmpty) {
            _cachedAppUpdate = Map<String, dynamic>.from(data);
            _appUpdateRetryAfter = null;
          }
          debugPrint('[FirestoreService] app_updates/current SDK ok data.isNotEmpty=${data.isNotEmpty}');
          return Map<String, dynamic>.from(data);
        } on FirebaseException catch (e) {
          if (e.code == 'permission-denied') {
            // permission-denied: usuário não está autenticado ainda ou token expirou.
            // Aplica cooldown CURTO (15s) para aguardar conclusão do login antes de retentar.
            // Não usar 2min: prejudica usuários que fazem login logo em seguida.
            _appUpdateRetryAfter = DateTime.now().add(const Duration(seconds: 15));
            debugPrint('[FirestoreService] app_updates/current permission-denied — aguardando autenticação (15s)');
            return Map<String, dynamic>.from(_cachedAppUpdate);
          }
          debugPrint('[FirestoreService] app_updates/current SDK erro: ${e.code} — tentando REST');
          // Outros erros SDK: tenta REST como fallback
          return await _loadAppUpdateRest();
        }
      } catch (e) {
        debugPrint('[FirestoreService] loadAppUpdate ERRO: $e');
        return Map<String, dynamic>.from(_cachedAppUpdate);
      } finally {
        _appUpdateInFlight = null;
      }
    }();

    _appUpdateInFlight = future;
    return future;
  }

  static Future<Map<String, dynamic>> _loadAppUpdateRest() async {
    try {
      final token = await AuthService.getAdminToken();
      // GET: usa _restGetHeaders (sem Content-Type nem X-Firebase-API-Key)
      final resp = await http.get(
        Uri.parse('$_fsBase/app_updates/current?key=$_firebaseApiKey'),
        headers: _restGetHeaders(token),
      ).timeout(const Duration(seconds: 2));
      if (resp.statusCode != 200) {
        if (resp.statusCode == 401 || resp.statusCode == 403) {
          _appUpdateRetryAfter = DateTime.now().add(_restRetryCooldown);
        }
        debugPrint('[FirestoreService] app_updates/current REST ${resp.statusCode}: ${resp.body.substring(0, resp.body.length.clamp(0, 220))}');
        return Map<String, dynamic>.from(_cachedAppUpdate);
      }
      _appUpdateRetryAfter = null;
      final data = _decodeFirestoreFields(resp.body);
      if (data.isNotEmpty) {
        _cachedAppUpdate = Map<String, dynamic>.from(data);
      }
      return data;
    } catch (e) {
      debugPrint('[FirestoreService] _loadAppUpdateRest ERRO: $e');
      return Map<String, dynamic>.from(_cachedAppUpdate);
    }
  }

  /// Salva nova atualização em app_updates/current (admin only).
  static Future<void> saveAppUpdate({
    required String version,
    required String title,
    required String date,
    required List<String> items,
    required bool active,
  }) async {
    if (kIsWeb) {
      await _saveAppUpdateRest(
        version: version, title: title,
        date: date, items: items, active: active,
      );
      return;
    }
    await _db.collection('app_updates').doc('current').set({
      'version': version, 'title': title,
      'date': date, 'items': items, 'active': active,
    });
  }

  static Future<void> _saveAppUpdateRest({
    required String version, required String title,
    required String date, required List<String> items, required bool active,
  }) async {
    final token = await AuthService.getAdminToken();
    if (token.isEmpty) return;
    final fields = {
      'version': {'stringValue': version},
      'title':   {'stringValue': title},
      'date':    {'stringValue': date},
      'active':  {'booleanValue': active},
      'items':   {'arrayValue': {'values': items.map((e) => {'stringValue': e}).toList()}},
    };
    const mask = 'updateMask.fieldPaths=version'
        '&updateMask.fieldPaths=title'
        '&updateMask.fieldPaths=date'
        '&updateMask.fieldPaths=active'
        '&updateMask.fieldPaths=items';
    await http.patch(
      Uri.parse('$_fsBase/app_updates/current?$mask'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({'fields': fields}),
    );
  }

  // ── Rastreamento de tempo de uso ──────────────────────────────────────────

  /// Incrementa o tempo de uso do usuário e atualiza lastSeenAt.
  /// Usa FieldValue.increment para evitar conflito de concorrência.
  static Future<void> incrementUsage(String uid, int seconds) async {
    if (uid.isEmpty || seconds <= 0) return;
    try {
      await _userDoc(uid).update({
        'totalUsageSeconds': FieldValue.increment(seconds),
        'lastSeenAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Silencioso — não interrompe o app se falhar
    }
  }

  /// Deleta o documento do usuário na coleção users.
  /// Não remove a conta do Firebase Auth (requer Admin SDK server-side),
  /// mas remove o perfil — o usuário ficará sem acesso ao app.
  static Future<void> deleteUser(String uid) async {
    if (uid.isEmpty) return;
    await _userDoc(uid).delete();
  }

  // ── Campanhas de Email ────────────────────────────────────────────────────

  /// Salva uma campanha enviada no histórico do Firestore.
  static Future<void> saveEmailCampaign({
    required String subject,
    required String body,
    required String sentBy,
    required String recipients, // 'all' | 'approved'
    required int recipientCount,
    required String status,     // 'sent' | 'error'
    String? errorMsg,
  }) async {
    await _db.collection('email_campaigns').add({
      'subject':        subject,
      'body':           body,
      'sentBy':         sentBy,
      'recipients':     recipients,
      'recipientCount': recipientCount,
      'status':         status,
      'errorMsg':       errorMsg ?? '',
      'sentAt':         FieldValue.serverTimestamp(),
    });
  }

  /// Carrega as últimas 20 campanhas enviadas (ordem desc).
  static Future<List<Map<String, dynamic>>> loadEmailCampaigns() async {
    try {
      final snap = await _db
          .collection('email_campaigns')
          .orderBy('sentAt', descending: true)
          .limit(20)
          .get();
      return snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data['id'] = d.id;
        return data;
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Salva/atualiza a configuração do EmailJS (serviceId, templateId, publicKey).
  /// Web  → REST PATCH com token (evita permission-denied do SDK no web)
  /// Nativo → SDK Firestore direto
  /// Destino: app_config/emailjs
  static Future<void> saveEmailJsConfig({
    required String serviceId,
    required String templateId,
    required String publicKey,
  }) async {
    if (kIsWeb) {
      await _saveEmailJsConfigRest(
        serviceId: serviceId,
        templateId: templateId,
        publicKey: publicKey,
      );
      return;
    }
    // Nativo — SDK funciona normalmente
    await _db.collection('app_config').doc('emailjs').set({
      'serviceId':   serviceId,
      'templateId':  templateId,
      'publicKey':   publicKey,
      'updatedAt':   FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    debugPrint('[FirestoreService] saveEmailJsConfig OK → app_config/emailjs (SDK)');
  }

  /// Salva EmailJS config via REST PATCH (web — evita SDK permission-denied).
  static Future<void> _saveEmailJsConfigRest({
    required String serviceId,
    required String templateId,
    required String publicKey,
  }) async {
    final token = await AuthService.getAdminToken();
    if (token.isEmpty) {
      debugPrint('[FirestoreService] _saveEmailJsConfigRest: token vazio — abortando');
      throw Exception('Não autenticado — token de admin ausente');
    }
    final fields = {
      'serviceId':  {'stringValue': serviceId},
      'templateId': {'stringValue': templateId},
      'publicKey':  {'stringValue': publicKey},
      'updatedAt':  {'stringValue': DateTime.now().toUtc().toIso8601String()},
    };
    const mask = 'updateMask.fieldPaths=serviceId'
        '&updateMask.fieldPaths=templateId'
        '&updateMask.fieldPaths=publicKey'
        '&updateMask.fieldPaths=updatedAt';
    final resp = await http.patch(
      Uri.parse('$_fsBase/app_config/emailjs?$mask'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'fields': fields}),
    );
    debugPrint('[FirestoreService] _saveEmailJsConfigRest status=${resp.statusCode}');
    if (resp.statusCode != 200) {
      throw Exception('REST EmailJS save: HTTP ${resp.statusCode} — ${resp.body}');
    }
    debugPrint('[FirestoreService] saveEmailJsConfig OK → app_config/emailjs (REST)');
  }

  /// Carrega a configuração do EmailJS.
  /// Web: REST GET → app_config/emailjs (sem SDK, evita CORS/permission)
  /// Nativo: SDK → app_config/emailjs, fallback para config/emailjs (legado)
  static Future<Map<String, String>> loadEmailJsConfig() async {
    if (kIsWeb) return _loadEmailJsConfigRest();
    // Nativo: tenta novo caminho
    try {
      final doc = await _db.collection('app_config').doc('emailjs').get();
      if (doc.exists) {
        final d = safeMap(doc.data());
        return {
          'serviceId':  safeString(d['serviceId']),
          'templateId': safeString(d['templateId']),
          'publicKey':  safeString(d['publicKey']),
        };
      }
    } catch (_) {}
    // Fallback para caminho legado config/emailjs (dados antigos já salvos)
    try {
      final doc = await _db.collection('config').doc('emailjs').get();
      if (!doc.exists) return {};
      final d = safeMap(doc.data());
      return {
        'serviceId':  safeString(d['serviceId']),
        'templateId': safeString(d['templateId']),
        'publicKey':  safeString(d['publicKey']),
      };
    } catch (_) {
      return {};
    }
  }

  /// Lê EmailJS config via REST (web).
  static Future<Map<String, String>> _loadEmailJsConfigRest() async {
    try {
      final token = await AuthService.getAdminToken();
      final headers = token.isNotEmpty
          ? {'Authorization': 'Bearer $token'}
          : <String, String>{};
      final resp = await http.get(
        Uri.parse('$_fsBase/app_config/emailjs'),
        headers: headers,
      ).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 404) return {};
      if (resp.statusCode != 200) return {};
      // safeMap: sem casts diretos — imune a TypeError em dart2js release
      final body   = safeMap(jsonDecode(resp.body));
      final fields = safeMap(body['fields']);
      return {
        'serviceId':  safeString(safeMap(fields['serviceId'])['stringValue']),
        'templateId': safeString(safeMap(fields['templateId'])['stringValue']),
        'publicKey':  safeString(safeMap(fields['publicKey'])['stringValue']),
      };
    } catch (_) {
      return {};
    }
  }

  /// Envia e-mail via EmailJS REST API (sem servidor, funciona no Flutter Web).
  static Future<void> sendEmailViaEmailJs({
    required String serviceId,
    required String templateId,
    required String publicKey,
    required String toEmail,
    required String toName,
    required String subject,
    required String message,
    required String fromName,
  }) async {
    final response = await http.post(
      Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'service_id':  serviceId,
        'template_id': templateId,
        'user_id':     publicKey,
        'template_params': {
          'to_email':  toEmail,
          'to_name':   toName,
          'subject':   subject,
          'message':   message,
          'from_name': fromName,
        },
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('EmailJS error ${response.statusCode}: ${response.body}');
    }
  }

  // ── Anotações pessoais do usuário ────────────────────────────────────────

  static CollectionReference<Map<String, dynamic>> _userNotes(String uid) =>
      _db.collection('users').doc(uid).collection('notes');

  /// Cria ou atualiza uma anotação.
  static Future<String> saveNote({
    required String uid,
    String? noteId, // null = nova nota
    required String title,
    required String content,
    required String color,  // hex string ex: '#1F6B48'
    List<String> tags = const [],
  }) async {
    final data = {
      'title':     title,
      'content':   content,
      'color':     color,
      'tags':      tags,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (noteId == null) {
      data['createdAt'] = FieldValue.serverTimestamp();
      final ref = await _userNotes(uid).add(data);
      return ref.id;
    } else {
      await _userNotes(uid).doc(noteId).set(data, SetOptions(merge: true));
      return noteId;
    }
  }

  /// Carrega todas as anotações do usuário, ordenadas por updatedAt desc.
  static Stream<List<Map<String, dynamic>>> notesStream(String uid) {
    return _userNotes(uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        // sdkDocWithId: evita Map<String,dynamic>.from() que lança em dart2js release
        // quando o SDK retorna Map<String,Object?> em vez de Map<String,dynamic>.
        .map((snap) => snap.docs.map(sdkDocWithId).toList());
  }

  /// Deleta uma anotação.
  static Future<void> deleteNote({required String uid, required String noteId}) async {
    await _userNotes(uid).doc(noteId).delete();
  }

  // ── BIBLIOTECA CLÍNICA — Guias / PDFs ────────────────────────────────────

  static CollectionReference<Map<String, dynamic>> get _guides =>
      _db.collection('clinical_guides');

  static void _debugGuides(String message) {
    if (kDebugMode) debugPrint('[FirestoreService.guides] $message');
  }

  static String get lastGuidesErrorMessage => _lastGuidesErrorMessage;

  static void _setGuidesError(String message) {
    _lastGuidesErrorMessage = message.trim();
    if (_lastGuidesErrorMessage.isNotEmpty) {
      _debugGuides('error=$_lastGuidesErrorMessage');
    }
  }

  static void _clearGuidesError() {
    _lastGuidesErrorMessage = '';
  }

  static List<GuideModel> _normalizeGuides(Iterable<GuideModel> guides) {
    final all   = guides.toList();
    final valid = <GuideModel>[];

    for (final g in all) {
      final missingId    = g.id.trim().isEmpty;
      final missingTitle = g.title.trim().isEmpty;
      final missingPdf   = g.pdfUrl.trim().isEmpty;

      if (missingId || missingTitle || missingPdf) {
        // LOG diagnóstico: informa qual campo faltou para cada guia descartada
        debugPrint(
          '[clinical_guides DEBUG] guia IGNORADA '
          'id="${g.id}" title="${g.title}" '
          'pdfUrl="${g.pdfUrl}" '
          'missingId=$missingId missingTitle=$missingTitle missingPdfUrl=$missingPdf',
        );
      } else {
        valid.add(g);
      }
    }

    debugPrint('[clinical_guides DEBUG] _normalizeGuides: total=${all.length} valid=${valid.length}');
    valid.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
    return valid;
  }

  static Future<void> _saveGuidesCache(List<GuideModel> guides) async {
    if (guides.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = guides.map((g) => g.toJson()).toList();
      await prefs.setString(_guidesCacheKey, jsonEncode(raw));
      _debugGuides('cache saved count=${guides.length}');
    } catch (e) {
      _debugGuides('cache save failed: $e');
    }
  }

  static Future<void> clearPublishedGuidesCache({String reason = 'manual'}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_guidesCacheKey);
      _debugGuides('cache cleared reason=$reason');
    } catch (e) {
      _debugGuides('cache clear failed reason=$reason error=$e');
    }
  }

  static Future<bool> clearPublishedGuidesCacheOnFirstOpen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alreadyReset = prefs.getBool(_guidesCacheFirstOpenResetKey) ?? false;
      if (alreadyReset) {
        _debugGuides('first-open cache reset already done');
        return false;
      }
      await prefs.remove(_guidesCacheKey);
      await prefs.setBool(_guidesCacheFirstOpenResetKey, true);
      _debugGuides('first-open cache reset executed');
      return true;
    } catch (e) {
      _debugGuides('first-open cache reset failed: $e');
      return false;
    }
  }

  static Future<List<GuideModel>> loadCachedPublishedGuides() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_guidesCacheKey) ?? '';
      if (raw.isEmpty) return [];
      final rawDecoded = jsonDecode(raw);
      final decoded = rawDecoded is List ? rawDecoded : const <dynamic>[];
      final guides = _normalizeGuides(
        decoded.whereType<Map>().map((item) => GuideModel.fromJson(
              Map<String, dynamic>.from(item),
            )),
      );
      _debugGuides('cache hit count=${guides.length}');
      return guides;
    } catch (e) {
      _debugGuides('cache read failed: $e');
      return [];
    }
  }

  static Future<List<GuideModel>> _loadPublishedGuidesSdk({Source? source}) async {
    // ── LOG: projeto Firebase em uso (SDK) ──────────────────────────────────
    try {
      final opts = Firebase.app().options;
      debugPrint('[clinical_guides DEBUG] projectId=${opts.projectId}');
      debugPrint('[clinical_guides DEBUG] appId=${opts.appId}');
      debugPrint('[clinical_guides DEBUG] apiKey=${opts.apiKey.substring(0, opts.apiKey.length.clamp(0, 10))}...');
    } catch (e) {
      debugPrint('[clinical_guides DEBUG] Firebase.app().options erro=$e');
    }
    debugPrint('[clinical_guides DEBUG] collection=clinical_guides');

    // ── PROBE SDK: testa 5 coleções sem filtro para achar onde estão os docs ─
    const probeCollections = [
      'clinical_guides',
      'guides',
      'medical_guides',
      'biblioteca_clinica',
      'clinical_library',
    ];
    for (final col in probeCollections) {
      try {
        final snap = await _db.collection(col)
            .limit(5)
            .get()
            .timeout(const Duration(seconds: 6));
        debugPrint('[clinical_guides DEBUG] collection=$col docs=${snap.docs.length}');
      } catch (e) {
        debugPrint('[clinical_guides DEBUG] collection=$col erro=$e');
      }
    }

    // Tentativa 1: query com orderBy (requer índice composto no Firestore)
    try {
      final query = _guides
          .where('isPublished', isEqualTo: true)
          .orderBy('uploadedAt', descending: true);
      final snap = source == null
          ? await query.get().timeout(const Duration(seconds: 8))
          : await query
              .get(GetOptions(source: source))
              .timeout(const Duration(seconds: 8));
      final guides = _normalizeGuides(
        snap.docs.map((d) => GuideModel.fromJson(sdkDocWithId(d))),
      );
      if (guides.isNotEmpty) {
        _clearGuidesError();
        await _saveGuidesCache(guides);
      }
      _debugGuides('sdk load (orderBy) count=${guides.length} source=${source ?? 'default'}');
      return guides;
    } on FirebaseException catch (e) {
      // failed-precondition = índice composto não existe → fallback sem orderBy
      if (e.code == 'failed-precondition' || e.code == 'unimplemented') {
        _debugGuides('sdk orderBy falhou (sem índice) — tentando sem orderBy: ${e.code}');
      } else if (e.code == 'permission-denied') {
        _setGuidesError('Acesso negado (verifique Firestore Rules para clinical_guides)');
        _debugGuides('sdk permission-denied source=${source ?? 'default'}');
        return [];
      } else {
        _setGuidesError('SDK clinical_guides erro: ${e.code}');
        _debugGuides('sdk firebase error ${e.code} source=${source ?? 'default'}');
        return [];
      }
    } catch (e) {
      _debugGuides('sdk orderBy falhou — tentando sem orderBy: $e');
    }

    // Tentativa 2: query SEM orderBy — não requer índice composto.
    // Ordenação é feita localmente em _normalizeGuides().
    try {
      final query = _guides.where('isPublished', isEqualTo: true);
      final snap = source == null
          ? await query.get().timeout(const Duration(seconds: 8))
          : await query
              .get(GetOptions(source: source))
              .timeout(const Duration(seconds: 8));
      final guides = _normalizeGuides(
        snap.docs.map((d) => GuideModel.fromJson(sdkDocWithId(d))),
      );
      if (guides.isNotEmpty) {
        _clearGuidesError();
        await _saveGuidesCache(guides);
      }
      _debugGuides('sdk load (sem orderBy) count=${guides.length} source=${source ?? 'default'}');
      return guides;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        _setGuidesError('Acesso negado (verifique Firestore Rules para clinical_guides)');
      } else {
        _setGuidesError('SDK clinical_guides erro (sem orderBy): ${e.code}');
      }
      _debugGuides('sdk sem orderBy error ${e.code} source=${source ?? 'default'}');
      return [];
    } catch (e) {
      _setGuidesError('SDK clinical_guides falhou (sem orderBy): $e');
      _debugGuides('sdk sem orderBy failed source=${source ?? 'default'} error=$e');
      return [];
    }
  }

  static Future<List<GuideModel>> _loadPublishedGuidesRest() async {
    // ── LOG: projeto Firebase em uso (REST) ──────────────────────────────────
    try {
      final opts = Firebase.app().options;
      debugPrint('[clinical_guides DEBUG] projectId=${opts.projectId}');
      debugPrint('[clinical_guides DEBUG] appId=${opts.appId}');
      debugPrint('[clinical_guides DEBUG] apiKey=${opts.apiKey.substring(0, opts.apiKey.length.clamp(0, 10))}...');
    } catch (e) {
      debugPrint('[clinical_guides DEBUG] projectId=$_projectId (fallback — Firebase.app() erro=$e)');
    }
    debugPrint('[clinical_guides DEBUG] fsBase=$_fsBase');

    // ── AUTH DIAGNÓSTICO ────────────────────────────────────────────────────
    final currentUser = FirebaseAuth.instance.currentUser;
    debugPrint('[clinical_guides DEBUG] currentUser=${currentUser?.uid ?? 'null (não logado)'}');
    debugPrint('[clinical_guides DEBUG] currentUser.email=${currentUser?.email ?? 'null'}');

    final token = await currentUser?.getIdToken();
    debugPrint('[clinical_guides DEBUG] tokenPresent=${token != null && token.isNotEmpty}');
    debugPrint('[clinical_guides DEBUG] tokenLength=${token?.length ?? 0}');

    final authHeaders = (token != null && token.isNotEmpty)
        ? <String, String>{'Authorization': 'Bearer $token'}
        : <String, String>{};
    debugPrint('[clinical_guides DEBUG] authHeader=${authHeaders.containsKey('Authorization')}');

    // ── SDK DIRETO: teste isolado sem REST ───────────────────────────────────
    // Se SDK retornar docs e REST retornar 403 → problema exclusivo no endpoint REST.
    try {
      final sdkSnap = await FirebaseFirestore.instance
          .collection('clinical_guides')
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 6));
      debugPrint('[clinical_guides DEBUG] SDK direto docs=${sdkSnap.docs.length}');
      if (sdkSnap.docs.isNotEmpty) {
        final d = sdkSnap.docs.first;
        debugPrint('[clinical_guides DEBUG] SDK primeiro doc id=${d.id} fields=${d.data().keys.toList()}');
      }
    } catch (e) {
      debugPrint('[clinical_guides DEBUG] SDK direto ERRO=$e');
    }

    final apiKey = _firebaseApiKey;
    debugPrint('[clinical_guides DEBUG] apiKey(10)=${apiKey.substring(0, apiKey.length.clamp(0, 10))}...');

    // ── TAREFA 4: confirmar nome exato da coleção usada ──────────────────────
    const targetCollection = 'clinical_guides';
    debugPrint('[clinical_guides DEBUG] coleção alvo=$targetCollection '
        '(NÃO é: clinicalGuides, guides, medical_guides, biblioteca_clinica, clinical_library)');

    Future<http.Response> doGet({Map<String, String>? headers, String collection = targetCollection}) {
      // GET: SOMENTE Authorization — nunca Content-Type nem X-Firebase-API-Key
      // (headers customizados causam preflight CORS que Firestore rejeita)
      final hdrs = <String, String>{...authHeaders, ...?headers};
      final url = '$_fsBase/$collection?pageSize=200&key=$apiKey';
      debugPrint('[clinical_guides DEBUG] REST URL=$url');
      debugPrint('[clinical_guides DEBUG] REST headers keys=${hdrs.keys.toList()}');
      return http
          .get(Uri.parse(url), headers: hdrs)
          .timeout(const Duration(seconds: 12));
    }

    List<GuideModel> parseResponse(http.Response resp) {
      // ── TAREFA 3: logar status e body bruto ──────────────────────────────
      debugPrint('[clinical_guides DEBUG] REST status=${resp.statusCode}');
      debugPrint('[clinical_guides DEBUG] REST body=${resp.body.length > 1500 ? resp.body.substring(0, 1500) : resp.body}');

      // safeMap: sem casts diretos — imune a TypeError em dart2js release
      final body      = safeMap(jsonDecode(resp.body));
      final docsList  = body['documents'];
      final documents = docsList is List ? docsList : const <dynamic>[];
      final totalDocs = documents.length;

      debugPrint('[clinical_guides DEBUG] totalDocs=$totalDocs');

      final allParsed    = <GuideModel>[];
      final unpublished  = <String>[];

      for (final doc in documents) {
        try {
          final rawDoc = safeMap(doc);
          final data   = _restDocToMap(rawDoc);

          // Garante que o id está preenchido a partir do campo 'name' do REST
          if (data['id'] == null || safeString(data['id']).isEmpty) {
            final name = safeString(rawDoc['name']);
            data['id'] = name.isNotEmpty ? name.split('/').last : '';
          }

          // LOG amostra dos campos-chave de cada documento para diagnóstico
          debugPrint(
            '[clinical_guides DEBUG] sampleData: '
            'id=${data['id']} '
            'title=${data['title']} '
            'pdfUrl=${data['pdfUrl']} '
            'fileUrl=${data['fileUrl']} '
            'url=${data['url']} '
            'isPublished=${data['isPublished']} '
            'fields=${data.keys.toList()}',
          );

          final guide = GuideModel.fromJson(data);
          allParsed.add(guide);

          if (!guide.isPublished) {
            unpublished.add('id=${guide.id}');
          }
        } catch (e, st) {
          _debugGuides('REST parseResponse: guia ignorado por erro — $e\n$st');
        }
      }

      final publishedGuides = allParsed.where((g) => g.isPublished).toList();
      debugPrint('[clinical_guides DEBUG] parsed=${allParsed.length}');
      debugPrint('[clinical_guides DEBUG] published=${publishedGuides.length}');
      if (unpublished.isNotEmpty) {
        debugPrint('[clinical_guides DEBUG] unpublished: $unpublished');
      }

      final normalized = _normalizeGuides(publishedGuides);
      debugPrint('[clinical_guides DEBUG] validPdfTitle=${normalized.length}');
      return normalized;
    }

    try {
      _debugGuides('rest load start kIsWeb=$kIsWeb tokenPresent=${authHeaders.isNotEmpty}');
      var resp = await doGet();
      _debugGuides('rest load initial status=${resp.statusCode}');

      if (resp.statusCode == 401 || resp.statusCode == 403) {
        final refreshedToken = await FirebaseAuth.instance.currentUser?.getIdToken(true);
        final retryHeaders = (refreshedToken != null && refreshedToken.isNotEmpty)
            ? <String, String>{'Authorization': 'Bearer $refreshedToken'}
            : <String, String>{};
        _debugGuides('rest auth retry tokenPresent=${retryHeaders.isNotEmpty}');
        if (retryHeaders.isNotEmpty) {
          resp = await doGet(headers: retryHeaders);
          _debugGuides('rest load retry status=${resp.statusCode}');
        }
      }

      if (resp.statusCode != 200) {
        // ── LOG COMPLETO DO ERRO ─────────────────────────────────────────────
        debugPrint('[clinical_guides DEBUG] FIRESTORE ERROR status=${resp.statusCode}');
        debugPrint('[clinical_guides DEBUG] FIRESTORE ERROR BODY: ${resp.body}');
        // Diagnóstico do tipo de 403:
        // - "Missing or insufficient permissions" → Firestore Rules negando acesso
        // - "UNAUTHENTICATED"                    → token ausente ou expirado
        // - "API key not valid"                  → _firebaseApiKey errada
        // - "Firebase App Check"                 → App Check ativado sem attestation
        // - "Requests to this API ... disabled"  → Firestore API desabilitada no GCP
        final snippet = resp.body.substring(0, resp.body.length.clamp(0, 400));
        _setGuidesError('REST clinical_guides HTTP ${resp.statusCode}: $snippet');
        // Cooldown 2min em qualquer HTTP != 200 — evita retry storm
        _guidesRestRetryAfter = DateTime.now().add(_restRetryCooldown);
        _debugGuides('REST ${resp.statusCode} — cooldown 2min aplicado');
        return [];
      }

      final guides = parseResponse(resp);
      if (guides.isNotEmpty) {
        _clearGuidesError();
        await _saveGuidesCache(guides);
        return guides;
      }

      // ── TAREFA 5 & 6: clinical_guides vazia → probe coleções alternativas ──
      // Dispara apenas quando a coleção principal retornou 0 documentos.
      // Ordem de tentativa conforme especificado.
      debugPrint('[clinical_guides DEBUG] clinical_guides vazia — iniciando probe de coleções alternativas');
      const altCollections = [
        'guides',
        'medical_guides',
        'biblioteca_clinica',
        'clinical_library',
      ];
      for (final altCol in altCollections) {
        try {
          debugPrint('[clinical_guides DEBUG] probe: tentando coleção=$altCol');
          final altResp = await doGet(collection: altCol)
              .timeout(const Duration(seconds: 8));
          debugPrint('[clinical_guides DEBUG] probe: $altCol status=${altResp.statusCode}');
          if (altResp.statusCode == 200) {
            final altBody = safeMap(jsonDecode(altResp.body));
            final altDocs = altBody['documents'];
            final altCount = altDocs is List ? altDocs.length : 0;
            if (altCount > 0) {
              // ── TAREFA 6: logar coleção encontrada ──────────────────────
              debugPrint('[clinical_guides DEBUG] coleção encontrada: $altCol totalDocs=$altCount');
            } else {
              debugPrint('[clinical_guides DEBUG] probe: $altCol retornou 0 docs');
            }
          }
        } catch (e) {
          debugPrint('[clinical_guides DEBUG] probe: $altCol erro=$e');
        }
      }

      // Mensagem diagnóstica final (zero guias na coleção principal)
      try {
        final bodyParsed = safeMap(jsonDecode(resp.body));
        final docsList2  = bodyParsed['documents'];
        final totalDocs  = docsList2 is List ? docsList2.length : 0;
        _setGuidesError(
          totalDocs > 0
              ? 'Nenhuma guia publicada ($totalDocs docs sem isPublished=true ou pdfUrl vazio)'
              : 'Biblioteca clínica vazia no servidor',
        );
      } catch (_) {
        _setGuidesError('REST clinical_guides retornou 0 guias publicados.');
      }

      _debugGuides('rest load count=0 (probe completo — verifique logs acima)');
      return [];
    } on TimeoutException catch (e) {
      _setGuidesError('REST clinical_guides timeout: $e');
      _debugGuides('rest load timeout error=$e');
      return [];
    } catch (e) {
      _setGuidesError('REST clinical_guides falhou: $e');
      _debugGuides('rest load failed error=$e');
      return [];
    }
  }

  static Future<List<GuideModel>> loadPublishedGuides({bool forceRemote = false}) async {
    final cached = await loadCachedPublishedGuides();
    _debugGuides(
      'loadPublishedGuides start forceRemote=$forceRemote kIsWeb=$kIsWeb cached=${cached.length}',
    );

    // forceRemote (botão "Tentar novamente"): limpa cooldowns para nova tentativa
    if (forceRemote) {
      _guidesRestRetryAfter = null;
      _clearGuidesError();
      _debugGuides('forceRemote=true — cooldowns resetados');
    }

    // ── ETAPA 0: Cache imediato (quando não é forceRemote e há cache) ─────────
    // Retorna cache imediatamente para evitar tela em branco, atualiza em bg.
    if (!forceRemote && cached.isNotEmpty) {
      _debugGuides('cache hit etapa 0 count=${cached.length} — retornando cache e atualizando em bg');
      Future.microtask(() async {
        try {
          final fresh = await _loadPublishedGuidesSdk(source: Source.server);
          if (fresh.isNotEmpty) {
            _clearGuidesError();
            await _saveGuidesCache(fresh);
            _debugGuides('bg refresh ok count=${fresh.length}');
          }
        } catch (_) {}
      });
      return cached;
    }

    // ── ETAPA 1: SDK Firestore (todos os browsers — Safari incluído) ─────────
    // SDK funciona quando rules permitem read para isAuthed() ou read: if true.
    // Fix: SDK primeiro para todos. REST só como fallback final com cooldown.
    final sdkServer = await _loadPublishedGuidesSdk(source: Source.server);
    if (sdkServer.isNotEmpty) return sdkServer;

    final sdkDefault = await _loadPublishedGuidesSdk();
    if (sdkDefault.isNotEmpty) return sdkDefault;

    _debugGuides('sdk failed — trying REST fallback');

    // ── ETAPA 2: REST fallback — apenas se SDK falhou E cooldown não ativo ──
    if (!_isRestCoolingDown(_guidesRestRetryAfter)) {
      final rest = await _loadPublishedGuidesRest();
      if (rest.isNotEmpty) return rest;
      // Se REST retornou 403, aplica cooldown
      final restError = lastGuidesErrorMessage;
      if (restError.contains('HTTP 403') || restError.contains('403')) {
        _guidesRestRetryAfter = DateTime.now().add(_restRetryCooldown);
        _debugGuides('REST 403 — cooldown até $_guidesRestRetryAfter');
      }
    } else {
      _debugGuides('REST em cooldown — pulando');
    }

    // ── ETAPA 3: Cache local (fallback final) ────────────────────────────────
    if (cached.isNotEmpty) {
      _clearGuidesError(); // dados em cache — não exibe erro para o usuário
      _debugGuides('remote failed/empty, returning cache count=${cached.length}');
      return cached;
    }

    if (lastGuidesErrorMessage.isEmpty) {
      _setGuidesError('clinical_guides: SDK e REST falharam — sem cache disponível.');
    }
    _debugGuides('remote empty and cache empty');
    return const <GuideModel>[];
  }

  /// Stream de todas as guias publicadas (ordenadas por data).
  /// Web/PWA usa polling REST para evitar inconsistências do SDK no mobile web.
  /// Nativo mantém snapshots do SDK, com fallback local/remoto tratado pela tela.
  static Stream<List<GuideModel>> guidesStream() {
    // SDK stream para todos os browsers — Safari incluído.
    // Antes Safari usava _guidesStreamRest() que fazia REST polling → 403.
    // Com as Firestore Rules corretas (read: isAuthed()), o SDK funciona em Safari.
    // _guidesStreamRest() é mantido apenas como fallback de último recurso.
    return _guides
        .where('isPublished', isEqualTo: true)
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snap) => _normalizeGuides(
              snap.docs.map((d) => GuideModel.fromJson(sdkDocWithId(d))),
            ));
  }

  static Stream<List<GuideModel>> _guidesStreamRest() {
    late StreamController<List<GuideModel>> ctrl;
    Timer? timer;

    Future<void> fetch() async {
      try {
        _debugGuides('rest stream fetch start');
        final remote = await loadPublishedGuides(forceRemote: true).timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            _setGuidesError('Stream REST clinical_guides timeout: nenhuma resposta em 15s.');
            return const <GuideModel>[];
          },
        );
        if (ctrl.isClosed) return;
        if (remote.isNotEmpty) {
          ctrl.add(remote);
          _debugGuides('rest stream emitted count=${remote.length}');
          return;
        }

        final cached = await loadCachedPublishedGuides();
        if (ctrl.isClosed) return;
        if (cached.isNotEmpty) {
          ctrl.add(cached);
          _debugGuides('rest stream emitted cached count=${cached.length}');
          return;
        }

        final error = lastGuidesErrorMessage.isEmpty
            ? 'Stream REST clinical_guides retornou vazio sem cache.'
            : lastGuidesErrorMessage;
        ctrl.addError(StateError(error));
        _debugGuides('rest stream emitted error=$error');
      } catch (e) {
        final error = 'Stream REST clinical_guides falhou: $e';
        _setGuidesError(error);
        if (!ctrl.isClosed) ctrl.addError(StateError(error));
      }
    }

    ctrl = StreamController<List<GuideModel>>(
      onListen: () {
        _debugGuides('rest stream onListen');
        loadCachedPublishedGuides().then((cached) {
          if (!ctrl.isClosed && cached.isNotEmpty) {
            ctrl.add(cached);
            _debugGuides('rest stream preloaded cache count=${cached.length}');
          }
        });
        unawaited(fetch());
        timer = Timer.periodic(const Duration(seconds: 20), (_) => unawaited(fetch()));
      },
      onCancel: () {
        timer?.cancel();
        timer = null;
        _debugGuides('rest stream cancelled');
      },
    );

    return ctrl.stream;
  }

  /// Stream de TODAS as guias para o admin (incluindo não publicadas).
  static Stream<List<GuideModel>> guidesAdminStream() {
    return _guides
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => GuideModel.fromJson(sdkDocWithId(d)))
            .toList());
  }

  /// Salva metadados de uma guia no Firestore.
  static Future<String> saveGuide(GuideModel guide) async {
    if (guide.id.isEmpty) {
      final ref = await _guides.add(guide.toJson());
      return ref.id;
    } else {
      await _guides.doc(guide.id).set(guide.toJson(), SetOptions(merge: true));
      return guide.id;
    }
  }

  /// Atualiza campo isPublished de uma guia.
  static Future<void> toggleGuidePublished(String guideId, bool published) async {
    await _guides.doc(guideId).update({'isPublished': published});
  }

  /// Deleta uma guia do Firestore.
  static Future<void> deleteGuide(String guideId) async {
    await _guides.doc(guideId).delete();
  }

  /// Incrementa contador de downloads.
  static Future<void> incrementGuideDownload(String guideId) async {
    try {
      await _guides.doc(guideId).update({
        'downloadCount': FieldValue.increment(1),
      });
    } catch (_) {}
  }

  /// Escreve/atualiza app_config/maintenance via REST PATCH.
  static Future<void> _setMaintenanceRest({
    required bool enabled,
    required String updatedBy,
    String message = '',
  }) async {
    final token = await AuthService.getAdminToken();
    if (token.isEmpty) return;

    final fields = {
      'enabled':   {'booleanValue': enabled},
      'message':   {'stringValue': message.trim()},
      'updatedBy': {'stringValue': updatedBy},
      'updatedAt': {'stringValue': DateTime.now().toUtc().toIso8601String()},
    };

    // updateMask: atualiza apenas os 4 campos (não sobrescreve outros)
    const mask = 'updateMask.fieldPaths=enabled'
        '&updateMask.fieldPaths=message'
        '&updateMask.fieldPaths=updatedBy'
        '&updateMask.fieldPaths=updatedAt';

    await http.patch(
      Uri.parse('$_fsBase/app_config/maintenance?$mask'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'fields': fields}),
    );
  }
}
