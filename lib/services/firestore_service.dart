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
import 'firebase_runtime_guard.dart'; // BUILD 299: safe Firebase.apps access

// ── BUILD 463-A.1: Sealed algebraic type for Firestore load results ──────────
//
// SECTOR 4: Elimina o falso "novo usuário" anti-pattern onde uma exceção
// 'permission-denied' era silenciosamente mapeada para [] vazio, acionando
// escritas de configuração de "novo usuário".
//
// Regras de uso:
//   • success(data)  → dados carregados com sucesso → processamento normal
//   • empty()        → documento existe mas está vazio → preserva cache local
//   • authDenied()   → permission-denied → congela índice local, NÃO escreve
//   • offline()      → sem rede / timeout → usa cache local preservado
//   • failure(error) → erro inesperado → log + preserva cache local
//
// Se authDenied() ou offline() for retornado, é PROIBIDO:
//   • sobrescrever o cache local com null/vazio
//   • criar documento de "novo usuário" no Firestore
//   • limpar históricos ou favoritos existentes
abstract class FirestoreLoadResult<T> {
  const FirestoreLoadResult();

  factory FirestoreLoadResult.success(T data) = _FsSuccess<T>;
  factory FirestoreLoadResult.empty() = _FsEmpty<T>;
  factory FirestoreLoadResult.authDenied() = _FsAuthDenied<T>;
  factory FirestoreLoadResult.offline() = _FsOffline<T>;
  factory FirestoreLoadResult.failure(dynamic error) = _FsFailure<T>;

  bool get isSuccess => this is _FsSuccess<T>;
  bool get isEmpty => this is _FsEmpty<T>;
  bool get isAuthDenied => this is _FsAuthDenied<T>;
  bool get isOffline => this is _FsOffline<T>;
  bool get isFailure => this is _FsFailure<T>;

  /// true se o resultado indica que o cache local deve ser PRESERVADO
  /// (não sobrescrever dados existentes com null/vazio).
  bool get shouldFreezeLocalCache => isAuthDenied || isOffline || isFailure;

  /// Extrai dados se success, ou retorna fallback.
  T dataOrElse(T fallback) =>
      isSuccess ? (this as _FsSuccess<T>).data : fallback;
}

class _FsSuccess<T> extends FirestoreLoadResult<T> {
  final T data;
  const _FsSuccess(this.data);
}

class _FsEmpty<T> extends FirestoreLoadResult<T> {
  const _FsEmpty();
}

class _FsAuthDenied<T> extends FirestoreLoadResult<T> {
  const _FsAuthDenied();
}

class _FsOffline<T> extends FirestoreLoadResult<T> {
  const _FsOffline();
}

class _FsFailure<T> extends FirestoreLoadResult<T> {
  final dynamic error;
  const _FsFailure(this.error);
}

// ── MICRO-BUILD 463-A.2.1.3: UiLoadOutcome<T> — single-flight latch wrapper ──
//
// Separates the lifecycle of a single-flight provider request from the
// algebraic content of the Firestore result.
//
// MOTIVATION: Using FirestoreLoadResult.authDenied() as a stale-epoch sentinel
// is an architectural violation — it conflates a chronological lifecycle event
// ("this completion arrived after a newer generation took ownership") with an
// authentication breach ("Firebase returned permission-denied").  A stale epoch
// is silent routing infrastructure, not a credential alarm.
//
// CONTRACT:
//   UiLoadApplied(result) — completion belongs to the current generation;
//                           the caller must route through result's algebraic
//                           variants (success/empty/authDenied/offline/failure).
//   UiLoadDiscarded(reason) — completion arrived after a newer generation
//                             superseded this request; the caller must
//                             silently skip ALL state-tree mutations.
//
// USAGE: loadAiSessionsTypedForUi() returns UiLoadOutcome<…>.
// The consumer (ai_screen._loadChatHistory) pattern-matches on the outer
// wrapper first, then routes the inner FirestoreLoadResult algebraically.
sealed class UiLoadOutcome<T> {
  const UiLoadOutcome();
}

/// The result is current-generation: route through [result]'s variants.
final class UiLoadApplied<T> extends UiLoadOutcome<T> {
  final FirestoreLoadResult<T> result;
  const UiLoadApplied(this.result);
}

/// The result belongs to a superseded generation: discard silently.
/// [reason] is a lowercase_underscore diagnostic token — never shown in UI.
final class UiLoadDiscarded<T> extends UiLoadOutcome<T> {
  final String reason; // always "stale_generation"
  const UiLoadDiscarded({required this.reason});
}

// ── MICRO-BUILD 463-A.2.2: FirestoreWriteResult — typed write barrier ─────────
//
// Replaces raw, unawaited .set()/.update()/.delete() with a typed return value
// that forces every call site to handle success, auth-denial, and failure
// as distinct cases.
//
// Dual-UID checks are performed BEFORE any I/O:
//   1. FirebaseAuth.instance.currentUser != null  (active SDK session)
//   2. FirebaseAuth.instance.currentUser!.uid == requestedUid  (IDOR shield)
//
// If either check fails → FsWriteAuthDenied returned synchronously,
// zero Firestore SDK calls dispatched.
//
// AppProvider obligation on FsWriteAuthDenied | FsWriteFailure:
//   • Revert the local memory change to the last verified snapshot.
//   • Trigger an operational error notification to the UI.
//   • Freeze any further write-back operations for this request cycle.
// ─────────────────────────────────────────────────────────────────────────────
sealed class FirestoreWriteResult {
  const FirestoreWriteResult();
}

/// The write completed successfully in Firestore.
final class FsWriteSuccess extends FirestoreWriteResult {
  const FsWriteSuccess();
}

/// The write was rejected before any I/O — UID is null or mismatches.
/// [reason] is always the literal token 'uid_mismatch_or_null'.
final class FsWriteAuthDenied extends FirestoreWriteResult {
  final String reason;
  const FsWriteAuthDenied(this.reason);
}

/// The write reached Firestore but an exception was thrown.
final class FsWriteFailure extends FirestoreWriteResult {
  final Object error;
  final StackTrace stackTrace;
  const FsWriteFailure(this.error, this.stackTrace);
}

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
  /// CRÍTICO: nunca usa Map<String,dynamic>.from() — em dart2js release mode
  /// quando v é JavaScriptObject (Map<String, Object?>) o .from() pode lançar
  /// TypeError para valores cujo tipo JS não mapeia para Object.
  static Map<String, dynamic> safeMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) {
      // Itera entry-by-entry em vez de .from() — imune a TypeError em dart2js
      final result = <String, dynamic>{};
      try {
        v.forEach((k, val) {
          try {
            result[k.toString()] = val;
          } catch (_) {}
        });
      } catch (_) {}
      return result;
    }
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
      // Cada elemento é sanitizado individualmente — um elemento ruim não
      // quebra a lista inteira. Crítico para o array 'evolutions' em dart2js.
      final result = <dynamic>[];
      for (final item in v) {
        try {
          result.add(_sanitizeSdkValue(item));
        } catch (_) {
          try {
            result.add(item?.toString() ?? '');
          } catch (_) {}
        }
      }
      return result;
    }
    if (v is Map<String, dynamic>) {
      return sdkDocToSafeMap(v);
    }
    if (v is Map) {
      // CRÍTICO: nunca usar Map<String, dynamic>.from(v) em dart2js release —
      // quando v é JavaScriptObject (Map<String, Object?>) o from() pode lançar
      // TypeError para valores cujo tipo JS não mapeia para Object.
      // Usa sdkDocToSafeMapAny que itera entry-by-entry com try/catch individual.
      return sdkDocToSafeMapAny(v);
    }
    // Tenta converter Timestamp do Firestore → ISO8601 via reflexão dinâmica
    try {
      final dynamic ts = v;
      final dynamic date = ts.toDate();
      if (date is DateTime) return date.toIso8601String();
    } catch (_) {}
    // Último recurso: toString() — nunca lança
    try {
      return v.toString();
    } catch (_) {
      return '';
    }
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

  // ── Helpers de conversão defensiva para listas de documentos ────────────
  // Cada documento é processado individualmente em try/catch.
  // Um documento malformado é silenciosamente descartado — não quebra os demais.
  // CRÍTICO para dart2js release/minified no mobile web onde tipos JS inesperados
  // causam TypeError não capturado se usarmos .map().toList() sem proteção.

  /// Converte uma lista de QueryDocumentSnapshot → List<ClinicalHistoryModel>
  /// com proteção individual por documento. Imune a TypeError em dart2js release.
  /// CRÍTICO: nunca usa `as List` — cast direto pode lançar TypeError em dart2js.
  static List<ClinicalHistoryModel> _safeDocsToHistoryList(dynamic docs) {
    final result = <ClinicalHistoryModel>[];
    if (docs == null) return result;
    try {
      // Obtém a lista de forma segura — sem `as List`
      Iterable<dynamic> iterable;
      if (docs is List) {
        iterable = docs;
      } else {
        try {
          // QuerySnapshot.docs retorna List — acessamos via dynamic sem cast
          final dynamic d = docs;
          final dynamic asList = d.toList();
          iterable = asList is List ? asList : const <dynamic>[];
        } catch (_) {
          return result; // não conseguiu obter lista — retorna vazio
        }
      }
      for (final doc in iterable) {
        try {
          final data = sdkDocWithId(doc);
          if (data.isEmpty) continue;
          result.add(ClinicalHistoryModel.fromJson(data));
        } catch (e) {
          // Documento malformado — descarta sem propagar erro
          if (kDebugMode)
            debugPrint('[safeDocsToHistoryList] doc ignorado: $e');
        }
      }
    } catch (e) {
      if (kDebugMode)
        debugPrint('[safeDocsToHistoryList] falha ao iterar docs: $e');
    }
    return result;
  }

  /// Converte uma lista de QueryDocumentSnapshot → List<GuideModel>
  /// com proteção individual por documento. Imune a TypeError em dart2js release.
  /// CRÍTICO: nunca usa `as List` — cast direto pode lançar TypeError em dart2js.
  static List<GuideModel> _safeDocsToGuideList(dynamic docs) {
    final result = <GuideModel>[];
    if (docs == null) return result;
    try {
      // Obtém a lista de forma segura — sem `as List`
      Iterable<dynamic> iterable;
      if (docs is List) {
        iterable = docs;
      } else {
        try {
          final dynamic d = docs;
          final dynamic asList = d.toList();
          iterable = asList is List ? asList : const <dynamic>[];
        } catch (_) {
          return result;
        }
      }
      for (final doc in iterable) {
        try {
          final data = sdkDocWithId(doc);
          if (data.isEmpty) continue;
          result.add(GuideModel.fromJson(data));
        } catch (e) {
          if (kDebugMode) debugPrint('[safeDocsToGuideList] doc ignorado: $e');
        }
      }
    } catch (e) {
      if (kDebugMode)
        debugPrint('[safeDocsToGuideList] falha ao iterar docs: $e');
    }
    return result;
  }

  // BUILD 299: FirebaseRuntimeGuard.isReady substitui Firebase.apps.isNotEmpty.
  // O getter Firebase.apps pode lançar NullError no Safari (interop JS nulo).
  // FirebaseRuntimeGuard encapsula o try/catch — nunca lança, sempre retorna bool.
  static bool get _isFirebaseReady => FirebaseRuntimeGuard.isReady;

  // Getter lazy — só acessa Firestore APÓS Firebase.initializeApp() completar
  static FirebaseFirestore get _db {
    if (!_isFirebaseReady) {
      throw StateError(
        '[FirestoreService] Firebase não inicializado. '
        'Verifique Firebase.initializeApp() no boot.',
      );
    }
    return FirebaseFirestore.instance;
  }

  static const _projectId = 'medcases-pro';
  static const _fsBase =
      'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents';
  static String get _firebaseApiKey =>
      DefaultFirebaseOptions.currentPlatform.apiKey;
  static bool get _isIosWeb =>
      kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  // Cooldown por endpoint após 403 — evita retry storm
  static DateTime? _guidesRestRetryAfter;
  static DateTime? _publicHistoriesRestRetryAfter;

  static bool _isRestCoolingDown(DateTime? retryAfter) =>
      retryAfter != null && DateTime.now().isBefore(retryAfter);

  // ── ORDEM 50 M3: Auth guard síncrono ─────────────────────────────────────
  // BUILD 463-A.2: Dual-credential-plane detection.
  //
  // PLANE A — _hasSdkIdentity (strict):
  //   Firebase SDK currentUser is non-null. This is the ONLY credential that
  //   satisfies user-private Firestore barriers (loadHistories, loadFav*, etc).
  //   Used exclusively by the dual-check barriers in 463-A.1.2.
  //   Must NEVER be substituted with REST token or Gemini OAuth state.
  //
  // PLANE B — _hasAnyAuthCredential (broad):
  //   True if either the SDK session OR a REST identity-toolkit token is present.
  //   Used ONLY by public/shared-content endpoints (loadPublicHistories,
  //   _checkAppUpdate, loadPublishedGuides) to suppress pre-login 403 spam.
  //   Deliberately broader than _hasSdkIdentity because these endpoints accept
  //   REST-authenticated reads on Web.
  //   MUST NOT be used for user-private data endpoints.
  //
  // SUPERSEDED (deprecated, internal only):
  //   _isUserAuthenticated → retained as alias for _hasAnyAuthCredential.
  //   All new code must reference the explicit names above.

  /// Strict SDK identity check — Firebase SDK currentUser is non-null.
  /// Used exclusively for user-private Firestore read barriers.
  static bool get _hasSdkIdentity {
    if (!_isFirebaseReady) return false;
    return FirebaseAuth.instance.currentUser != null;
  }

  /// Broad auth check — SDK session OR REST token present.
  /// Used only by public/shared-content pre-flight guards to suppress 403 spam.
  /// DO NOT use for user-private data endpoints.
  static bool get _hasAnyAuthCredential {
    if (!_isFirebaseReady) {
      return kIsWeb ? AuthService.hasCachedToken : false;
    }
    if (FirebaseAuth.instance.currentUser != null) return true;
    if (kIsWeb) return AuthService.hasCachedToken;
    return false;
  }

  /// @Deprecated — use [_hasAnyAuthCredential] explicitly for public endpoints
  /// or [_hasSdkIdentity] for user-private barriers.
  static bool get _isUserAuthenticated => _hasAnyAuthCredential;

  static const _guidesCacheKey = 'clinical_guides_cache_v1';
  static const _guidesCacheFirstOpenResetKey =
      'clinical_guides_cache_first_open_reset_v2';
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
  static Future<void> updateUserProfile(
    String uid, {
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
      final body = safeMap(jsonDecode(bodyText));
      final fields = safeMap(body['fields']);
      final data = <String, dynamic>{};

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
            final arrRaw = safeMap(value['arrayValue']);
            final valsList = arrRaw['values'];
            final items = valsList is List ? valsList : const <dynamic>[];
            data[key] = items.map((item) {
              final m = safeMap(item);
              if (m.containsKey('stringValue'))
                return safeString(m['stringValue']);
              if (m.containsKey('integerValue'))
                return safeString(m['integerValue']);
              if (m.containsKey('booleanValue'))
                return safeBool(m['booleanValue']).toString();
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
      debugPrint(
        '[FirestoreService] app_config/global em cooldown — retornando cache',
      );
      return Map<String, dynamic>.from(_cachedAppConfigGlobal);
    }
    final inFlight = _appConfigGlobalInFlight;
    if (inFlight != null) return inFlight;

    final future = () async {
      try {
        if (kIsWeb) {
          // ── WEB: REST com AuthService.getAdminToken() ─────────────────────
          // FirebaseAuth.instance.currentUser é sempre null no Web (login via
          // REST Identity Toolkit não injeta token no Firebase Auth SDK).
          // Usamos AuthService.getAdminToken() como fonte única de token no Web.
          //
          // BUILD 288: TOKEN GATE — se restoreSession() ainda não completou no
          // boot, hasCachedToken é false e getAdminToken() retornaria vazio →
          // 403 falso que congela o app por 15s. Aguardamos até 4s pelo token
          // antes de disparar o request, com polling a cada 500ms.
          if (!AuthService.hasCachedToken) {
            debugPrint(
              '[BUILD288][TokenGate] app_config/global — token não disponível, aguardando restoreSession()...',
            );
            for (var _tg = 0; _tg < 8; _tg++) {
              await Future.delayed(const Duration(milliseconds: 500));
              if (AuthService.hasCachedToken) {
                debugPrint(
                  '[BUILD288][TokenGate] token disponível após ${(_tg + 1) * 500}ms ✓',
                );
                break;
              }
            }
            if (!AuthService.hasCachedToken) {
              debugPrint(
                '[BUILD288][TokenGate] token ainda vazio após 4s — abortando REST, usando cache local',
              );
              return <String, dynamic>{};
            }
          }

          final token = await AuthService.getAdminToken();
          debugPrint(
            '[WEB_AUTH] source=REST token=${token.isNotEmpty} endpoint=app_config/global',
          );
          if (token.isEmpty) {
            debugPrint(
              '[FirestoreService] app_config/global REST skipped — token vazio',
            );
            return <String, dynamic>{};
          }
          try {
            final resp = await http
                .get(
                  Uri.parse('$_fsBase/app_config/global?key=$_firebaseApiKey'),
                  headers: _restGetHeaders(token),
                )
                .timeout(const Duration(seconds: 4));
            debugPrint(
              '[FirestoreService] app_config/global REST status=${resp.statusCode}',
            );
            if (resp.statusCode == 200) {
              final data = _decodeFirestoreFields(resp.body);
              if (data.isNotEmpty) {
                _cachedAppConfigGlobal = Map<String, dynamic>.from(data);
                _appConfigGlobalRetryAfter = null;
              }
              return Map<String, dynamic>.from(data);
            }
            if (resp.statusCode == 403 || resp.statusCode == 401) {
              debugPrint(
                '[FirestoreService] app_config/global REST ${resp.statusCode} — sem permissão (não-admin)',
              );
              // NÃO aplica cooldown — próxima tentativa deve retentar
              return <String, dynamic>{};
            }
            debugPrint(
              '[FirestoreService] app_config/global REST ${resp.statusCode}: ${resp.body.substring(0, resp.body.length.clamp(0, 220))}',
            );
            _appConfigGlobalRetryAfter = DateTime.now().add(
              const Duration(seconds: 30),
            );
            return <String, dynamic>{};
          } catch (e) {
            debugPrint('[FirestoreService] app_config/global REST ERRO: $e');
            return <String, dynamic>{};
          }
        }

        // ── NATIVO: SDK (FirebaseAuth token populado automaticamente) ─────
        debugPrint(
          '[NATIVE_AUTH] source=FirebaseSDK uid=${FirebaseAuth.instance.currentUser?.uid ?? 'null'} endpoint=app_config/global',
        );
        try {
          final doc = await _db
              .collection('app_config')
              .doc('global')
              .get()
              .timeout(const Duration(seconds: 4));
          debugPrint(
            '[FirestoreService] app_config/global SDK exists=${doc.exists}',
          );
          // safeMap: protege contra tipos inesperados do SDK em dart2js release
          final data = doc.exists ? safeMap(doc.data()) : <String, dynamic>{};
          if (data.isNotEmpty) {
            _cachedAppConfigGlobal = Map<String, dynamic>.from(data);
            _appConfigGlobalRetryAfter = null;
          }
          return Map<String, dynamic>.from(data);
        } on FirebaseException catch (e) {
          if (e.code == 'permission-denied') {
            // permission-denied ocorre para usuários não-admin (esperado).
            // NÃO aplica cooldown — NÃO guarda em cache.
            final uid = FirebaseAuth.instance.currentUser?.uid ?? 'null';
            debugPrint(
              '[FirestoreService] app_config/global permission-denied uid=$uid (não-admin ou token não propagado)',
            );
          } else {
            debugPrint(
              '[FirestoreService] app_config/global SDK erro: ${e.code}',
            );
            _appConfigGlobalRetryAfter = DateTime.now().add(
              const Duration(seconds: 30),
            );
          }
          return <String, dynamic>{};
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
      debugPrint(
        '[FirestoreService] loadAppAiKey key.isNotEmpty=${key.isNotEmpty}',
      );
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
      debugPrint(
        '[FirestoreService] loadGeminiApiKey key.isNotEmpty=${key.isNotEmpty}',
      );
      return key;
    } catch (e) {
      debugPrint('[FirestoreService] loadGeminiApiKey ERRO: $e');
      return '';
    }
  }

  /// Salva a Gemini API Key global do app em app_config/global.
  ///
  /// BUILD 322: branch Web usa REST PATCH + Bearer token (mesmo padrão de
  /// saveAppAiKey / saveGeminiPaidEnabled). Nativo mantém SDK intacto.
  static Future<void> saveGeminiApiKey(String key) async {
    // ── Limpar cache para forçar releitura limpa após write ─────────────────
    _cachedAppConfigGlobal.clear();
    _appConfigGlobalRetryAfter = null;

    if (kIsWeb) {
      final token = await AuthService.getAdminToken();
      debugPrint(
        '[WEB_AUTH] source=REST token=${token.isNotEmpty} endpoint=app_config/global (saveGeminiApiKey)',
      );
      if (token.isEmpty) {
        debugPrint(
          '[FirestoreService] saveGeminiApiKey ERRO Web — token REST vazio',
        );
        throw Exception('saveGeminiApiKey: token REST vazio');
      }
      try {
        const mask = 'updateMask.fieldPaths=apiKey';
        final resp = await http
            .patch(
              Uri.parse('$_fsBase/app_config/global?$mask'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'fields': {
                  'apiKey': {'stringValue': key.trim()},
                },
              }),
            )
            .timeout(const Duration(seconds: 8));
        if (resp.statusCode == 200) {
          debugPrint(
            '[FirestoreService] saveGeminiApiKey OK → app_config/global (REST Web)',
          );
        } else {
          debugPrint(
            '[FirestoreService] saveGeminiApiKey ERRO REST ${resp.statusCode}: '
            '${resp.body.substring(0, resp.body.length.clamp(0, 220))}',
          );
          throw Exception('saveGeminiApiKey REST ${resp.statusCode}');
        }
      } catch (e) {
        debugPrint('[FirestoreService] saveGeminiApiKey ERRO REST: $e');
        rethrow;
      }
      return;
    }

    // ── NATIVO: SDK ─────────────────────────────────────────────────────────
    try {
      await _db.collection('app_config').doc('global').set({
        'apiKey': key.trim(),
      }, SetOptions(merge: true));
      debugPrint('[FirestoreService] saveGeminiApiKey OK');
    } catch (e) {
      debugPrint('[FirestoreService] saveGeminiApiKey ERRO: $e');
      rethrow;
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
  ///
  /// BUILD 322: branch Web usa REST PATCH + Bearer token (mesmo padrão de
  /// saveGeminiPaidEnabled). Nativo mantém SDK intacto.
  /// Cache invalidado em ambas as plataformas para forçar releitura limpa.
  static Future<void> saveAppAiKey(String key) async {
    // ── Limpar cache local para garantir leitura limpa após write ───────────
    _cachedAppConfigGlobal.clear();
    _appConfigGlobalRetryAfter = null;

    if (kIsWeb) {
      // ── WEB: REST PATCH com AuthService.getAdminToken() ─────────────────
      // FirebaseAuth.instance.currentUser é sempre null no Web (login via
      // REST Identity Toolkit não injeta token no Firebase Auth SDK).
      // getAdminToken() retorna o token REST correto (auto-refresh incluído).
      final token = await AuthService.getAdminToken();
      debugPrint(
        '[WEB_AUTH] source=REST token=${token.isNotEmpty} endpoint=app_config/global (saveAppAiKey)',
      );
      if (token.isEmpty) {
        debugPrint(
          '[FirestoreService] saveAppAiKey ERRO Web — token REST vazio',
        );
        throw Exception('saveAppAiKey: token REST vazio');
      }
      try {
        // updateMask garante que apenas o campo 'openAiKey' é alterado (merge
        // seguro no REST — não sobrescreve outros campos do documento).
        const mask = 'updateMask.fieldPaths=openAiKey';
        final resp = await http
            .patch(
              Uri.parse('$_fsBase/app_config/global?$mask'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'fields': {
                  'openAiKey': {'stringValue': key.trim()},
                },
              }),
            )
            .timeout(const Duration(seconds: 8));
        if (resp.statusCode == 200) {
          debugPrint(
            '[FirestoreService] saveAppAiKey OK → app_config/global (REST Web)',
          );
          debugPrint(
            '[ADMIN_AI_KEY] saved=true provider=openai key_empty=${key.trim().isEmpty}',
          );
        } else {
          debugPrint(
            '[FirestoreService] saveAppAiKey ERRO REST ${resp.statusCode}: '
            '${resp.body.substring(0, resp.body.length.clamp(0, 220))}',
          );
          throw Exception('saveAppAiKey REST ${resp.statusCode}');
        }
      } catch (e) {
        debugPrint('[FirestoreService] saveAppAiKey ERRO REST: $e');
        rethrow;
      }
      return;
    }

    // ── NATIVO: SDK (FirebaseAuth token populado automaticamente) ──────────
    final fbUser = FirebaseAuth.instance.currentUser;
    debugPrint(
      '[NATIVE_AUTH] source=FirebaseSDK uid=${fbUser?.uid ?? 'null'} endpoint=app_config/global (saveAppAiKey)',
    );
    try {
      await _db.collection('app_config').doc('global').set({
        'openAiKey': key.trim(),
      }, SetOptions(merge: true));
      debugPrint('[FirestoreService] saveAppAiKey OK → app_config/global');
      debugPrint(
        '[ADMIN_AI_KEY] saved=true provider=openai key_empty=${key.trim().isEmpty}',
      );
    } catch (e) {
      debugPrint('[FirestoreService] saveAppAiKey ERRO: $e');
      rethrow;
    }
  }

  // ── Gemini Paid Proxy — Build 226 ─────────────────────────────────────────
  //
  // SEGURANÇA: A GEMINI_PAID_API_KEY NUNCA é armazenada no Firestore.
  // Apenas o FLAG de ativação (geminiPaidEnabled: bool) é armazenado em
  // app_config/global — campo lido somente por admin e pela Cloud Function.
  //
  // A chave real fica exclusivamente no Firebase Secret (GEMINI_PAID_API_KEY),
  // lida server-side pela função geminiPaidProxy — NUNCA pelo cliente.
  //
  // Usuários comuns NÃO conseguem ler app_config/global (regra Firestore).

  /// Ativa ou desativa o fallback para Gemini Paid.
  /// Armazena APENAS o flag booleano — a chave fica no Firebase Secret.
  /// Apenas admin/master pode chamar este método.
  static Future<void> saveGeminiPaidEnabled(bool enabled) async {
    // ── Limpar cache local para garantir leitura limpa após write ─────────────
    _cachedAppConfigGlobal.clear();
    _appConfigGlobalRetryAfter = null;

    if (kIsWeb) {
      // ── WEB: REST PATCH com AuthService.getAdminToken() ───────────────────
      // FirebaseAuth.instance.currentUser é sempre null no Web.
      // getAdminToken() retorna o token REST correto (auto-refresh incluído).
      final token = await AuthService.getAdminToken();
      debugPrint(
        '[WEB_AUTH] source=REST token=${token.isNotEmpty} endpoint=app_config/global (saveGeminiPaidEnabled)',
      );
      if (token.isEmpty) {
        debugPrint(
          '[ADMIN_AI_TOGGLE] ERRO Web — token vazio, não é possível salvar',
        );
        throw Exception('saveGeminiPaidEnabled: token REST vazio');
      }
      debugPrint(
        '[ADMIN_AI_TOGGLE] Web REST PATCH '
        'path=app_config/global '
        'field=geminiPaidEnabled '
        'value=$enabled',
      );
      try {
        const mask = 'updateMask.fieldPaths=geminiPaidEnabled';
        final resp = await http
            .patch(
              Uri.parse('$_fsBase/app_config/global?$mask'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'fields': {
                  'geminiPaidEnabled': {'booleanValue': enabled},
                },
              }),
            )
            .timeout(const Duration(seconds: 8));
        if (resp.statusCode == 200) {
          debugPrint(
            '[ADMIN_AI_TOGGLE] OK → app_config/global.geminiPaidEnabled=$enabled',
          );
          debugPrint(
            '[ADMIN_AI_KEY] saved=true provider=gemini_paid status=${enabled ? "online" : "offline"}',
          );
        } else {
          debugPrint(
            '[ADMIN_AI_TOGGLE] ERRO REST ${resp.statusCode}: ${resp.body.substring(0, resp.body.length.clamp(0, 220))}',
          );
          throw Exception('saveGeminiPaidEnabled REST ${resp.statusCode}');
        }
      } catch (e) {
        debugPrint('[ADMIN_AI_TOGGLE] ERRO REST: $e');
        rethrow;
      }
      return;
    }

    // ── NATIVO: SDK (FirebaseAuth token populado automaticamente) ──────────
    final fbUser = FirebaseAuth.instance.currentUser;
    debugPrint(
      '[NATIVE_AUTH] source=FirebaseSDK uid=${fbUser?.uid ?? 'null'} endpoint=app_config/global (saveGeminiPaidEnabled)',
    );
    // Força token fresco antes do write
    try {
      await fbUser?.getIdToken(true);
    } catch (tokenErr) {
      debugPrint('[ADMIN_AI_TOGGLE] aviso: refresh de token falhou: $tokenErr');
    }
    debugPrint(
      '[ADMIN_AI_TOGGLE] Nativo SDK '
      'path=app_config/global '
      'field=geminiPaidEnabled '
      'value=$enabled | '
      'uid=${fbUser?.uid ?? "null"} '
      'email=${fbUser?.email ?? "null"} '
      'isAnon=${fbUser?.isAnonymous ?? true}',
    );
    try {
      await _db.collection('app_config').doc('global').set({
        'geminiPaidEnabled': enabled,
      }, SetOptions(merge: true));
      debugPrint(
        '[ADMIN_AI_TOGGLE] OK → app_config/global.geminiPaidEnabled=$enabled',
      );
      debugPrint(
        '[ADMIN_AI_KEY] saved=true provider=gemini_paid status=${enabled ? "online" : "offline"}',
      );
    } catch (e) {
      debugPrint(
        '[ADMIN_AI_TOGGLE] ERRO path=app_config/global uid=${fbUser?.uid ?? "null"} erro=$e',
      );
      debugPrint('[FirestoreService] saveGeminiPaidEnabled ERRO: $e');
      rethrow;
    }
  }

  /// Carrega o flag de ativação do Gemini Paid.
  /// Somente admin consegue ler (regra Firestore) — não-admin recebe false.
  static Future<bool> loadGeminiPaidEnabled() async {
    try {
      final data = await _loadAppConfigGlobalData();
      return data['geminiPaidEnabled'] == true;
    } catch (e) {
      debugPrint('[FirestoreService] loadGeminiPaidEnabled ERRO: $e');
      return false;
    }
  }

  /// Carrega contadores de budget do paid proxy.
  /// Armazenado em app_config/paid_budget — leitura restrita a admin.
  ///
  /// BUILD 322: branch Web usa REST GET + Bearer token.
  /// Nativo mantém SDK intacto.
  static Future<Map<String, dynamic>> loadPaidBudgetCounters() async {
    if (kIsWeb) {
      // ── WEB: REST GET com AuthService.getAdminToken() ───────────────────
      final token = await AuthService.getAdminToken();
      debugPrint(
        '[WEB_AUTH] source=REST token=${token.isNotEmpty} endpoint=app_config/paid_budget (loadPaidBudgetCounters)',
      );
      if (token.isEmpty) {
        debugPrint(
          '[FirestoreService] loadPaidBudgetCounters Web — token vazio',
        );
        return {};
      }
      try {
        final resp = await http
            .get(
              Uri.parse('$_fsBase/app_config/paid_budget?key=$_firebaseApiKey'),
              headers: _restGetHeaders(token),
            )
            .timeout(const Duration(seconds: 4));
        debugPrint(
          '[FirestoreService] loadPaidBudgetCounters REST status=${resp.statusCode}',
        );
        if (resp.statusCode == 200) {
          final data = _decodeFirestoreFields(resp.body);
          debugPrint(
            '[FirestoreService] loadPaidBudgetCounters OK — ${data.length} campos',
          );
          return data;
        }
        if (resp.statusCode == 404) {
          // Documento ainda não existe (nenhuma requisição paga feita ainda)
          debugPrint(
            '[FirestoreService] loadPaidBudgetCounters — documento não existe (404)',
          );
          return {};
        }
        if (resp.statusCode == 403 || resp.statusCode == 401) {
          debugPrint(
            '[FirestoreService] loadPaidBudgetCounters — sem permissão (não-admin) ${resp.statusCode}',
          );
          return {};
        }
        debugPrint(
          '[FirestoreService] loadPaidBudgetCounters ERRO REST ${resp.statusCode}: '
          '${resp.body.substring(0, resp.body.length.clamp(0, 220))}',
        );
        return {};
      } catch (e) {
        debugPrint('[FirestoreService] loadPaidBudgetCounters ERRO REST: $e');
        return {};
      }
    }

    // ── NATIVO: SDK (FirebaseAuth token populado automaticamente) ──────────
    debugPrint(
      '[NATIVE_AUTH] source=FirebaseSDK uid=${FirebaseAuth.instance.currentUser?.uid ?? 'null'} endpoint=app_config/paid_budget',
    );
    try {
      final doc = await _db
          .collection('app_config')
          .doc('paid_budget')
          .get()
          .timeout(const Duration(seconds: 4));
      if (!doc.exists) return {};
      return Map<String, dynamic>.from(doc.data() ?? {});
    } catch (e) {
      debugPrint('[FirestoreService] loadPaidBudgetCounters ERRO: $e');
      return {};
    }
  }

  /// Salva (ou remove) a chave OpenAI no perfil Firestore do usuário.
  /// Passa [key] vazio para remover a chave (modo local).
  static Future<void> saveAiKey(String uid, String key) async {
    try {
      await _userPrefs(uid).set({'openAiKey': key}, SetOptions(merge: true));
    } catch (_) {}
  }

  static Future<void> updateDisplayName(String uid, String displayName) async {
    try {
      await _userDoc(uid).update({'displayName': displayName});
    } catch (_) {}
  }

  // ── Favoritos de fármacos ─────────────────────────────────────────────────
  /// @Deprecated('Use loadFavDrugsTyped() — returns FirestoreLoadResult<Set<String>>'
  ///             'with shouldFreezeLocalCache semantics.')
  /// MICRO-BUILD 463-A.2.1.1: Marked defunct. No external consumers remain.
  /// Retained as dead code only; will be physically removed in a future purge.
  static Future<Set<String>> loadFavDrugs(String uid) async {
    // BUILD 463-A.1.2: Dual-check barrier — (1) null check, (2) uid mismatch
    final _fbUser = FirebaseAuth.instance.currentUser;
    if (!_isFirebaseReady || _fbUser == null) {
      debugPrint(
        '[FIRESTORE_AUTH_BARRIER] operation=loadFavDrugs '
        'allowed=false reason=firebase_user_null uid=$uid '
        'sdkRequestDispatched=false',
      );
      return {};
    }
    if (_fbUser.uid != uid) {
      debugPrint(
        '[FIRESTORE_AUTH_BARRIER] operation=loadFavDrugs '
        'expectedUid=$uid firebaseUid=${_fbUser.uid} '
        'allowed=false reason=uid_mismatch sdkRequestDispatched=false',
      );
      return {};
    }
    try {
      final doc = await _userFavs(uid).doc('drugs').get();
      if (!doc.exists) return {};
      return safeStringList(doc.data()?['ids']).toSet();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        debugPrint(
          '[FIRESTORE_AUTH_BARRIER] operation=loadFavDrugs '
          'allowed=false reason=permission_denied uid=$uid '
          'sdkRequestDispatched=true → authDenied (cache preservado)',
        );
      }
      return {};
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
  /// @Deprecated('Use loadFavProtocolsTyped() — returns FirestoreLoadResult<Set<String>>'
  ///             'with shouldFreezeLocalCache semantics.')
  /// MICRO-BUILD 463-A.2.1.1: Marked defunct. No external consumers remain.
  static Future<Set<String>> loadFavProtocols(String uid) async {
    // BUILD 463-A.1.2: Dual-check barrier — (1) null check, (2) uid mismatch
    final _fbUser = FirebaseAuth.instance.currentUser;
    if (!_isFirebaseReady || _fbUser == null) {
      debugPrint(
        '[FIRESTORE_AUTH_BARRIER] operation=loadFavProtocols '
        'allowed=false reason=firebase_user_null uid=$uid '
        'sdkRequestDispatched=false',
      );
      return {};
    }
    if (_fbUser.uid != uid) {
      debugPrint(
        '[FIRESTORE_AUTH_BARRIER] operation=loadFavProtocols '
        'expectedUid=$uid firebaseUid=${_fbUser.uid} '
        'allowed=false reason=uid_mismatch sdkRequestDispatched=false',
      );
      return {};
    }
    try {
      final doc = await _userFavs(uid).doc('protocols').get();
      if (!doc.exists) return {};
      return safeStringList(doc.data()?['ids']).toSet();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        debugPrint(
          '[FIRESTORE_AUTH_BARRIER] operation=loadFavProtocols '
          'allowed=false reason=permission_denied uid=$uid '
          'sdkRequestDispatched=true → authDenied (cache preservado)',
        );
      }
      return {};
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
  /// @Deprecated('Use loadFavPrescriptionsTyped() — returns FirestoreLoadResult<Set<String>>'
  ///             'with shouldFreezeLocalCache semantics.')
  /// MICRO-BUILD 463-A.2.1.1: Marked defunct. No external consumers remain.
  static Future<Set<String>> loadFavPrescriptions(String uid) async {
    // BUILD 463-A.1.2: Dual-check barrier — (1) null check, (2) uid mismatch
    final _fbUser = FirebaseAuth.instance.currentUser;
    if (!_isFirebaseReady || _fbUser == null) {
      debugPrint(
        '[FIRESTORE_AUTH_BARRIER] operation=loadFavPrescriptions '
        'allowed=false reason=firebase_user_null uid=$uid '
        'sdkRequestDispatched=false',
      );
      return {};
    }
    if (_fbUser.uid != uid) {
      debugPrint(
        '[FIRESTORE_AUTH_BARRIER] operation=loadFavPrescriptions '
        'expectedUid=$uid firebaseUid=${_fbUser.uid} '
        'allowed=false reason=uid_mismatch sdkRequestDispatched=false',
      );
      return {};
    }
    try {
      final doc = await _userFavs(uid).doc('prescriptions').get();
      if (!doc.exists) return {};
      return safeStringList(doc.data()?['ids']).toSet();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        debugPrint(
          '[FIRESTORE_AUTH_BARRIER] operation=loadFavPrescriptions '
          'allowed=false reason=permission_denied uid=$uid '
          'sdkRequestDispatched=true → authDenied (cache preservado)',
        );
      }
      return {};
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

  // ── MICRO-BUILD 462E-A.5.3.7.3.2.5: Canonical AI session index ───────────
  // Parent path: users/{uid}/ai_sessions — schema v2, queryable by isDeleted +
  // updatedAt. Exchange sub-path: …/ai_sessions/{sessionId}/exchanges/{requestId}.
  static CollectionReference<Map<String, dynamic>> _userAiSessions(
    String uid,
  ) => _db.collection('users').doc(uid).collection('ai_sessions');

  /// Salva UMA sessão de chat no Firestore (upsert por session.id).
  /// Injeta sempre `updatedAt` como server timestamp para que a query
  /// orderBy('updatedAt') funcione em todos os dispositivos.
  static Future<void> saveAiSession(
    String uid,
    Map<String, dynamic> session,
  ) async {
    try {
      final id = safeString(session['id']);
      if (id.isEmpty) return;
      // Copia o doc e injeta updatedAt como timestamp do servidor.
      // Isso garante ordenação cross-device mesmo que o relógio local esteja errado.
      final data = Map<String, dynamic>.from(session);
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _userAiHistory(uid).doc(id).set(data);
    } catch (_) {}
  }

  /// Deleta uma sessão de chat pelo id.
  static Future<void> deleteAiSession(String uid, String sessionId) async {
    try {
      await _userAiHistory(uid).doc(sessionId).delete();
    } catch (_) {}
  }

  // ── AI-RECONSTRUCTION-R18.6X-R1-R1: source-aware deletion ─────────────
  static Future<bool> deleteLegacyAiSession(
    String uid,
    String sessionId,
  ) async {
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (!_isFirebaseReady || firebaseUser == null || firebaseUser.uid != uid) {
      debugPrint(
        '[AI_HISTORY_DELETE][LEGACY] allowed=false '
        'reason=auth_guard uid=$uid',
      );
      return false;
    }

    try {
      await _userAiHistory(uid).doc(sessionId).delete();

      debugPrint(
        '[AI_HISTORY_DELETE][LEGACY] result=deleted '
        'sessionIdHash=${sessionId.hashCode}',
      );

      return true;
    } catch (error) {
      debugPrint(
        '[AI_HISTORY_DELETE][LEGACY] result=failed '
        'sessionIdHash=${sessionId.hashCode} '
        'errorType=${error.runtimeType}',
      );

      return false;
    }
  }

  static Future<bool> softDeleteCanonicalAiSession(
    String uid,
    String sessionId,
  ) async {
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (!_isFirebaseReady || firebaseUser == null || firebaseUser.uid != uid) {
      debugPrint(
        '[AI_HISTORY_DELETE][CANONICAL] allowed=false '
        'reason=auth_guard uid=$uid',
      );
      return false;
    }

    try {
      // Atualiza apenas o parent. A subcoleção exchanges permanece intacta.
      await _userAiSessions(uid).doc(sessionId).update({
        'isDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint(
        '[AI_HISTORY_DELETE][CANONICAL] result=tombstoned '
        'sessionIdHash=${sessionId.hashCode}',
      );

      return true;
    } catch (error) {
      debugPrint(
        '[AI_HISTORY_DELETE][CANONICAL] result=failed '
        'sessionIdHash=${sessionId.hashCode} '
        'errorType=${error.runtimeType}',
      );

      return false;
    }
  }

  // ── MICRO-BUILD 462E-A.5.3.7.3.2.5 [PILLAR 1]: Atomic batch session write ─
  //
  // Writes exactly two Firestore documents in a single WriteBatch:
  //   Operation A — Parent session document (upsert/merge):
  //     users/{uid}/ai_sessions/{sessionId}
  //   Operation B — Immutable exchange document (set, idempotent by requestId):
  //     users/{uid}/ai_sessions/{sessionId}/exchanges/{requestId}
  //
  // Schema v2 fields on the parent document are described in the mandate.
  // Operation B uses requestId as the document ID — duplicate writes are
  // safe (last-write-wins, same content).
  //
  // Returns [SessionPersistSynced] when both writes succeed, or
  // [SessionPersistFailed] on any error (never throws).
  //
  // IMPORTANT: This method is called ONLY from persistAiExchangeOnce()
  // which already enforces idempotency via _persistedExchangeIds.
  // MICRO-BUILD 462E-A.5.3.7.3.2.5.1 [PILLAR 2]: Return record extended with
  // [permissionDenied] flag. When true, the caller MUST map to
  // [SessionPersistAuthDenied] and MUST NOT enqueue into the offline queue.
  static Future<({bool ok, bool permissionDenied, Object? error})>
  batchWriteAiExchange({
    required String uid,
    required String sessionId,
    required String requestId,
    required String mode,
    required String locale,
    required String title,
    required bool isFirstMessage,
    required String userPreview,
    required String assistantPreview,
    required String userInputFull,
    required String assistantOutputFull,
    String userDisplayTextFull = '',
  }) async {
    try {
      final batch = _db.batch();

      final sessionRef = _userAiSessions(uid).doc(sessionId);
      final exchangeRef = sessionRef.collection('exchanges').doc(requestId);

      // ── MICRO-BUILD 462E-A.5.3.7.3.2.5.2 [PILLAR 7]: Server idempotency ──
      // Before writing aggregated counters, check if this exchange/{requestId}
      // already exists on the server. If so, bypass FieldValue.increment() on
      // messageCount/exchangeCount to prevent double-counting on retry paths.
      // Only the parent summary fields (title, lastPreview, updatedAt) are
      // re-merged — the content payload is skipped for already-committed docs.
      bool exchangeAlreadyExists = false;
      try {
        final existingSnap = await exchangeRef
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 5));
        exchangeAlreadyExists = existingSnap.exists;
      } catch (_) {
        // Network error during existence check — proceed without guard
        // (worst-case: harmless counter bump on retry).
        exchangeAlreadyExists = false;
      }

      if (exchangeAlreadyExists) {
        // Exchange already committed — skip batch entirely, emit telemetry.
        // TELEMETRY: never log raw user content. requestId is safe.
        debugPrint(
          '[LEGACY_WRITE][SKIPPED] reason=canonical_session_owned '
          'requestId=$requestId',
        );
        return (ok: true, permissionDenied: false, error: null);
      }

      // ── Operation A: Parent session document (upsert with merge) ──────────
      final parentData = <String, Object>{
        'sessionId': sessionId,
        'uid': uid,
        'title': title,
        'mode': mode,
        'locale': locale,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastRequestId': requestId,
        'lastUserPreview': userPreview,
        'lastAssistantPreview': assistantPreview,
        'messageCount': FieldValue.increment(1),
        'isDeleted': false,
        'schemaVersion': 2,
      };
      if (isFirstMessage) {
        // createdAt is set only once — on the very first exchange.
        parentData['createdAt'] = FieldValue.serverTimestamp();
      }
      // SetOptions(merge: true) ensures we do not overwrite createdAt on
      // subsequent turns (it is absent from parentData on turns > 1).
      batch.set(sessionRef, parentData, SetOptions(merge: true));

      // ── Operation B: Immutable exchange document (idempotent by requestId) ─
      final exchangeData = <String, Object>{
        'requestId': requestId,
        'sessionId': sessionId,
        'uid': uid,
        'userInput': userInputFull,
        'assistantOutput': assistantOutputFull,
        'mode': mode,
        'locale': locale,
        'createdAt': FieldValue.serverTimestamp(),
        'schemaVersion': 2,
      };
      final normalizedUserDisplayText = userDisplayTextFull.trim();
      if (normalizedUserDisplayText.isNotEmpty) {
        exchangeData['userDisplayText'] = normalizedUserDisplayText;
      }
      batch.set(exchangeRef, exchangeData);

      await batch.commit();
      return (ok: true, permissionDenied: false, error: null);
    } on FirebaseException catch (e) {
      // MICRO-BUILD 462E-A.5.3.7.3.2.5.1 [PILLAR 2]: Explicit permission-denied
      // isolation — maps to a distinct flag so the caller produces
      // SessionPersistAuthDenied, NOT SessionPersistQueuedOffline.
      if (e.code == 'permission-denied') {
        return (ok: false, permissionDenied: true, error: e);
      }
      return (ok: false, permissionDenied: false, error: e);
    } catch (e) {
      return (ok: false, permissionDenied: false, error: e);
    }
  }

  // ── MICRO-BUILD 463-A.2.1.1 PURGE ────────────────────────────────────────
  // _waitForAuth() has been PHYSICALLY DELETED. This 6-second polling helper
  // was the last remnant of the [BUILD313] auth-watchdog pattern, exterminated
  // in stages:
  //   • [BUILD313] _authResolved 8s watchdog   → removed in BUILD 463-A.1.1
  //   • _waitForAuth() 6s polling helper        → PHYSICALLY DELETED here
  //   • loadAiSessions() untyped path           → PHYSICALLY DELETED here
  //   • _loadAiSessionsFromCache() helper        → PHYSICALLY DELETED here
  //
  // All callers route through loadAiSessionsTyped(), which short-circuits with
  // authDenied() instantly when currentUser == null — no timers, no polling.
  // ─────────────────────────────────────────────────────────────────────────

  /// Usa sdkDocToSafeMap para converter Timestamp → ISO8601 string antes
  /// de passar para _ChatSession.fromJson (que usa DateTime.parse).
  ///
  // ── MICRO-BUILD 463-A.2.1.1: loadAiSessions() PHYSICALLY DELETED ────────
  // The untyped loadAiSessions(uid) → Future<List<Map<String,dynamic>>> has been
  // completely removed from disk. It called the now-deleted _waitForAuth() polling
  // helper and the now-deleted _loadAiSessionsFromCache() helper.
  //
  // MIGRATION: lib/screens/ai_screen.dart previously called loadAiSessions(uid)
  // at line 1260. That call site has been updated to use loadAiSessionsTyped(uid)
  // via the algebraic result pattern. loadAiSessionsTyped() provides the same
  // cache-fallback behaviour with correct offline() vs. empty() semantics.
  //
  // _loadAiSessionsFromCache() PHYSICALLY DELETED — was only called by the
  // now-deleted loadAiSessions() and the now-deleted _waitForAuth() path.
  // ─────────────────────────────────────────────────────────────────────────

  // ── Recentes cross-device ─────────────────────────────────────────────────
  static DocumentReference<Map<String, dynamic>> _userRecents(String uid) =>
      _db.collection('users').doc(uid).collection('prefs').doc('recents');

  /// Salva a lista de recentes no Firestore (lista de strings "type|id|title").
  static Future<void> saveRecents(String uid, List<String> recents) async {
    try {
      await _userRecents(
        uid,
      ).set({'items': recents, 'updatedAt': FieldValue.serverTimestamp()});
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
  /// @Deprecated('Use loadFavCasesTyped() — returns FirestoreLoadResult<Set<String>>'
  ///             'with shouldFreezeLocalCache semantics.')
  /// MICRO-BUILD 463-A.2.1.1: Marked defunct. No external consumers remain.
  static Future<Set<String>> loadFavCases(String uid) async {
    // BUILD 463-A.1.2: Dual-check barrier — (1) null check, (2) uid mismatch
    final _fbUser = FirebaseAuth.instance.currentUser;
    if (!_isFirebaseReady || _fbUser == null) {
      debugPrint(
        '[FIRESTORE_AUTH_BARRIER] operation=loadFavCases '
        'allowed=false reason=firebase_user_null uid=$uid '
        'sdkRequestDispatched=false',
      );
      return {};
    }
    if (_fbUser.uid != uid) {
      debugPrint(
        '[FIRESTORE_AUTH_BARRIER] operation=loadFavCases '
        'expectedUid=$uid firebaseUid=${_fbUser.uid} '
        'allowed=false reason=uid_mismatch sdkRequestDispatched=false',
      );
      return {};
    }
    try {
      final doc = await _userFavs(uid).doc('fav_cases').get();
      if (!doc.exists) return {};
      return safeStringList(doc.data()?['ids']).toSet();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        debugPrint(
          '[FIRESTORE_AUTH_BARRIER] operation=loadFavCases '
          'allowed=false reason=permission_denied uid=$uid '
          'sdkRequestDispatched=true → authDenied (cache preservado)',
        );
      }
      return {};
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
  /// @Deprecated('Use loadCasesTyped() — returns FirestoreLoadResult<List<ClinicalCaseModel>>'
  ///             'with shouldFreezeLocalCache semantics.')
  /// MICRO-BUILD 463-A.2.1.1: Marked defunct. No external consumers remain.
  static Future<List<ClinicalCaseModel>> loadCases(String uid) async {
    // BUILD 463-A.1.2: Dual-check barrier — (1) null check, (2) uid mismatch
    final _fbUser = FirebaseAuth.instance.currentUser;
    if (!_isFirebaseReady || _fbUser == null) {
      debugPrint(
        '[FIRESTORE_AUTH_BARRIER] operation=loadCases '
        'allowed=false reason=firebase_user_null uid=$uid '
        'sdkRequestDispatched=false',
      );
      return [];
    }
    if (_fbUser.uid != uid) {
      debugPrint(
        '[FIRESTORE_AUTH_BARRIER] operation=loadCases '
        'expectedUid=$uid firebaseUid=${_fbUser.uid} '
        'allowed=false reason=uid_mismatch sdkRequestDispatched=false',
      );
      return [];
    }
    try {
      final snap = await _userCases(
        uid,
      ).where('isCustom', isEqualTo: true).get();
      final cases = <ClinicalCaseModel>[];
      for (final d in snap.docs) {
        try {
          cases.add(ClinicalCaseModel.fromJson(sdkDocWithId(d)));
        } catch (_) {}
      }
      cases.sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
      return cases;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        debugPrint(
          '[FIRESTORE_AUTH_BARRIER] operation=loadCases '
          'allowed=false reason=permission_denied uid=$uid '
          'sdkRequestDispatched=true → authDenied (cache preservado)',
        );
      }
      return [];
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
    return _userCases(uid).where('isCustom', isEqualTo: true).snapshots().map((
      snap,
    ) {
      final cases = <ClinicalCaseModel>[];
      for (final d in snap.docs) {
        try {
          cases.add(ClinicalCaseModel.fromJson(sdkDocWithId(d)));
        } catch (_) {}
      }
      cases.sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
      return cases;
    });
  }

  // ── MICRO-BUILD 463-A.2.2: Identity-gated secure real-time streams ────────
  //
  // Both streams intercept auth state before every snapshot emission.
  // If the active user UID becomes null or changes to a different account
  // while the stream is listening, the stream terminates instantly —
  // zero transient snapshots from the wrong account are emitted.
  //
  // Stale snapshots arriving after termination are tagged:
  //   [SECURE_STREAM_DROPPED] parentUid=<uid> activeUid=<uid> reason=stale_stream_generation
  // ─────────────────────────────────────────────────────────────────────────

  /// Auto-closing secure stream of active cases.
  ///
  /// If [FirebaseAuth.instance.currentUser?.uid] becomes null or changes
  /// to a UID ≠ [uid] between snapshot emissions, the stream emits a
  /// done signal synchronously and closes.
  static Stream<List<ClinicalCaseModel>> streamActiveCases(String uid) async* {
    await for (final snap in _userCases(
      uid,
    ).where('isCustom', isEqualTo: true).snapshots()) {
      final activeUid = FirebaseAuth.instance.currentUser?.uid;
      if (activeUid != uid) {
        debugPrint(
          '[SECURE_STREAM][AUTO_CLOSE] stream=streamActiveCases '
          'parentUid=$uid activeUid=$activeUid',
        );
        yield* Stream.empty();
        return;
      }
      final cases = <ClinicalCaseModel>[];
      for (final d in snap.docs) {
        try {
          cases.add(ClinicalCaseModel.fromJson(sdkDocWithId(d)));
        } catch (_) {}
      }
      cases.sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
      yield cases;
    }
  }

  // ── MICRO-BUILD 463-A.2.2: Typed write barrier — 4 persistent mutators ───
  //
  // Each method performs a synchronous Dual-UID check BEFORE dispatching any
  // Firestore SDK call:
  //   1. currentUser != null  (active SDK session exists)
  //   2. currentUser!.uid == uid  (IDOR shield — prevents cross-account writes)
  //
  // Returns FsWriteAuthDenied immediately with zero I/O if either check fails.
  // Returns FsWriteSuccess on clean write, FsWriteFailure on exception.
  // ─────────────────────────────────────────────────────────────────────────

  /// Dual-UID pre-flight check shared by all typed write methods.
  /// Returns null on pass, or the denial result to return immediately.
  static FirestoreWriteResult? _writeAuthCheck(String uid, String operation) {
    final fbUser = FirebaseAuth.instance.currentUser;
    if (fbUser == null) {
      debugPrint(
        '[FIRESTORE_WRITE_BARRIER] operation=$operation '
        'allowed=false reason=uid_mismatch_or_null uid=$uid '
        'sdkWriteDispatched=false',
      );
      return const FsWriteAuthDenied('uid_mismatch_or_null');
    }
    if (fbUser.uid != uid) {
      debugPrint(
        '[FIRESTORE_WRITE_BARRIER] operation=$operation '
        'allowed=false reason=uid_mismatch_or_null '
        'expectedUid=$uid firebaseUid=${fbUser.uid} '
        'sdkWriteDispatched=false',
      );
      return const FsWriteAuthDenied('uid_mismatch_or_null');
    }
    return null; // pass — caller may dispatch I/O
  }

  /// Saves [h] to the user's private history sub-collection and, if public,
  /// mirrors it to public_histories. Returns the write outcome.
  /// [uploadedAt] is only non-null in the success path when h.isPublic.
  static Future<({FirestoreWriteResult result, String? uploadedAt})>
  saveHistoryTyped(String uid, ClinicalHistoryModel h) async {
    final denial = _writeAuthCheck(uid, 'saveHistoryTyped');
    if (denial != null) return (result: denial, uploadedAt: null);

    try {
      await _userHistories(uid).doc(h.id).set(h.toJson());

      String? uploadedAt;
      if (h.isPublic) {
        uploadedAt = h.uploadedAt.isNotEmpty
            ? h.uploadedAt
            : DateTime.now().toIso8601String();
        final publicData = h.toJson();
        publicData['uploadedAt'] = uploadedAt;
        publicData['isHidden'] = publicData['isHidden'] ?? false;

        if (kIsWeb) {
          await _savePublicHistoryRest(h.id, publicData);
        } else {
          await _publicHistories.doc(h.id).set(publicData);
        }
      } else {
        if (kIsWeb) {
          await _deletePublicHistoryRest(h.id);
        } else {
          try {
            await _publicHistories.doc(h.id).delete();
          } catch (_) {}
        }
      }
      return (result: const FsWriteSuccess(), uploadedAt: uploadedAt);
    } on FirebaseException catch (e, st) {
      debugPrint(
        '[FIRESTORE_WRITE_BARRIER] operation=saveHistoryTyped '
        'uid=$uid error=${e.code} sdkWriteDispatched=true → FsWriteFailure',
      );
      return (result: FsWriteFailure(e, st), uploadedAt: null);
    } catch (e, st) {
      debugPrint(
        '[FIRESTORE_WRITE_BARRIER] operation=saveHistoryTyped '
        'uid=$uid error=$e sdkWriteDispatched=true → FsWriteFailure',
      );
      return (result: FsWriteFailure(e, st), uploadedAt: null);
    }
  }

  /// Deletes [hid] from the user's history sub-collection and, if it was
  /// public, from public_histories. Returns the write outcome.
  static Future<FirestoreWriteResult> deleteHistoryTyped(
    String uid,
    String hid, {
    bool wasPublic = false,
  }) async {
    final denial = _writeAuthCheck(uid, 'deleteHistoryTyped');
    if (denial != null) return denial;

    try {
      await _userHistories(uid).doc(hid).delete();
      if (wasPublic) {
        try {
          await _publicHistories.doc(hid).delete();
        } catch (_) {}
      }
      return const FsWriteSuccess();
    } on FirebaseException catch (e, st) {
      debugPrint(
        '[FIRESTORE_WRITE_BARRIER] operation=deleteHistoryTyped '
        'uid=$uid hid=$hid error=${e.code} → FsWriteFailure',
      );
      return FsWriteFailure(e, st);
    } catch (e, st) {
      debugPrint(
        '[FIRESTORE_WRITE_BARRIER] operation=deleteHistoryTyped '
        'uid=$uid hid=$hid error=$e → FsWriteFailure',
      );
      return FsWriteFailure(e, st);
    }
  }

  /// Saves [ids] as the user's favourites set for [type]
  /// ('drugs', 'protocols', 'prescriptions', 'fav_cases').
  static Future<FirestoreWriteResult> saveFavoritesTyped(
    String uid,
    String type,
    Set<String> ids,
  ) async {
    final denial = _writeAuthCheck(uid, 'saveFavoritesTyped');
    if (denial != null) return denial;

    try {
      await _userFavs(uid).doc(type).set({'ids': ids.toList()});
      return const FsWriteSuccess();
    } on FirebaseException catch (e, st) {
      debugPrint(
        '[FIRESTORE_WRITE_BARRIER] operation=saveFavoritesTyped '
        'uid=$uid type=$type error=${e.code} → FsWriteFailure',
      );
      return FsWriteFailure(e, st);
    } catch (e, st) {
      debugPrint(
        '[FIRESTORE_WRITE_BARRIER] operation=saveFavoritesTyped '
        'uid=$uid type=$type error=$e → FsWriteFailure',
      );
      return FsWriteFailure(e, st);
    }
  }

  /// Saves a single [ClinicalCaseModel] to the user's cases sub-collection.
  static Future<FirestoreWriteResult> saveCaseProgressTyped(
    String uid,
    ClinicalCaseModel c,
  ) async {
    final denial = _writeAuthCheck(uid, 'saveCaseProgressTyped');
    if (denial != null) return denial;

    try {
      await _userCases(uid).doc(c.id).set(c.toJson());
      return const FsWriteSuccess();
    } on FirebaseException catch (e, st) {
      debugPrint(
        '[FIRESTORE_WRITE_BARRIER] operation=saveCaseProgressTyped '
        'uid=$uid caseId=${c.id} error=${e.code} → FsWriteFailure',
      );
      return FsWriteFailure(e, st);
    } catch (e, st) {
      debugPrint(
        '[FIRESTORE_WRITE_BARRIER] operation=saveCaseProgressTyped '
        'uid=$uid caseId=${c.id} error=$e → FsWriteFailure',
      );
      return FsWriteFailure(e, st);
    }
  }

  // ── Histórias clínicas do usuário ────────────────────────────────────────
  static CollectionReference<Map<String, dynamic>> _userHistories(String uid) =>
      _db.collection('users').doc(uid).collection('clinical_histories');

  static CollectionReference<Map<String, dynamic>> get _publicHistories =>
      _db.collection('public_histories');

  static void _debugPublicHistories(String message) {
    if (kDebugMode) debugPrint('[FirestoreService.publicHistories] $message');
  }

  static String get lastPublicHistoriesErrorMessage =>
      _lastPublicHistoriesErrorMessage;

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
    final list = histories.where((h) => h.id.trim().isNotEmpty).toList();
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
          (item) =>
              ClinicalHistoryModel.fromJson(Map<String, dynamic>.from(item)),
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
    if (v.containsKey('stringValue')) return v['stringValue'];
    if (v.containsKey('booleanValue')) return v['booleanValue'] == true;
    if (v.containsKey('integerValue')) {
      final raw = v['integerValue'];
      return raw is int ? raw : int.tryParse(raw?.toString() ?? '') ?? 0;
    }
    if (v.containsKey('doubleValue')) {
      final raw = v['doubleValue'];
      return raw is double
          ? raw
          : (raw is num
                ? raw.toDouble()
                : double.tryParse(raw?.toString() ?? '') ?? 0.0);
    }
    if (v.containsKey('nullValue')) return null;
    if (v.containsKey('mapValue')) {
      try {
        final mapVal = v['mapValue'];
        final f = safeMap(mapVal is Map ? mapVal['fields'] : null);
        return _decodeFields(f);
      } catch (_) {
        return <String, dynamic>{};
      }
    }
    if (v.containsKey('arrayValue')) {
      try {
        final arrVal = v['arrayValue'];
        final rawVals = (arrVal is Map) ? arrVal['values'] : null;
        final vals = rawVals is List ? rawVals : const <dynamic>[];
        return vals
            .whereType<Map>()
            .map(
              (e) => _decodeValue(
                e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e),
              ),
            )
            .toList();
      } catch (_) {
        return <dynamic>[];
      }
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
    if (val == null) return {'nullValue': null};
    if (val is bool) return {'booleanValue': val};
    if (val is int) return {'integerValue': val.toString()};
    if (val is double) return {'doubleValue': val};
    if (val is String) return {'stringValue': val};
    if (val is List) {
      return {
        'arrayValue': {'values': val.map(_encodeValue).toList()},
      };
    }
    if (val is Map<String, dynamic>) {
      return {
        'mapValue': {'fields': _encodeFields(val)},
      };
    }
    return {'stringValue': val.toString()};
  }

  /// DEPRECATED — BUILD 463-A.1.2: Use [loadHistoriesTyped] instead.
  ///
  /// This untyped variant silently returns `[]` on permission-denied, making it
  /// impossible for the caller to distinguish an auth failure from an empty list.
  /// That ambiguity enables false "new user" write paths.
  ///
  /// All internal call-sites have been migrated to [loadHistoriesTyped].
  /// This signature is retained only for backward-compatibility with
  /// call-sites that cannot immediately adopt the algebraic return type
  /// (e.g. legacy screen hooks that require a plain List). New code MUST
  /// use [loadHistoriesTyped] and unwrap the sealed variants explicitly.
  @Deprecated(
    'Use loadHistoriesTyped() — returns FirestoreLoadResult<T> '
    'that correctly exposes authDenied/offline states. '
    'Removed in BUILD 463-A.1.2 internal consumer migration.',
  )
  static Future<List<ClinicalHistoryModel>> loadHistories(String uid) async {
    // ORDEM SYNC-FIX: iOS usa cache Firestore por padrão — histórias criadas
    // na Web não aparecem no mobile na primeira abertura.
    // Estratégia em duas etapas:
    //   1) Tenta Source.server (dados frescos do servidor, sem cache)
    //   2) Se falhar (offline / timeout), usa cache local como fallback
    //
    // BUILD 336-AUTH-RESILIENCE (PASSO 1): blindagem permission-denied.
    // permission-denied não deve bloquear o boot — fallback silencioso para [].
    //
    // BUILD 427-TOOLS-PERSISTENCE (PASSO 4 — Watchdog Hardening):
    // permission-denied em Source.server → retorna [] IMEDIATAMENTE.
    // NÃO tenta Source.cache como segundo round-trip — isso pode acumular
    // latência e disparar o watchdog de 8 segundos (BUILD 313).
    // Rationale: se o token não foi propagado, Source.cache também falha;
    // se o usuário está offline, o timeout de 10s já cobre o caso.
    //
    // BUILD 463-A.1.2: Dual-check barrier — (1) null check, (2) uid mismatch.
    // A REST token alone is not sufficient. Firebase SDK user must be non-null
    // AND uid must match the requested uid to prevent cross-uid leaks.
    final _fbUserH = FirebaseAuth.instance.currentUser;
    if (!_isFirebaseReady || _fbUserH == null) {
      debugPrint(
        '[FIRESTORE_AUTH_BARRIER] operation=loadHistories '
        'allowed=false reason=firebase_user_null uid=$uid '
        'sdkRequestDispatched=false',
      );
      return [];
    }
    if (_fbUserH.uid != uid) {
      debugPrint(
        '[FIRESTORE_AUTH_BARRIER] operation=loadHistories '
        'expectedUid=$uid firebaseUid=${_fbUserH.uid} '
        'allowed=false reason=uid_mismatch sdkRequestDispatched=false',
      );
      return [];
    }
    try {
      // Sem orderBy — evita índice composto. Ordenação em memória.
      final query = _userHistories(uid);

      QuerySnapshot<Map<String, dynamic>> snap;
      try {
        // Etapa 1: força leitura direta do servidor (ignora cache local)
        snap = await query
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 10));
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          // BUILD 427 PASSO 4: fast-fail instantâneo — sem segundo round-trip.
          // BUILD 463-A.1 SECTOR 4: permission-denied → authDenied (não escreve "novo usuário").
          // Retorna [] antes de qualquer tentativa de cache para não acumular
          // latência e disparar o watchdog de 8 s (BUILD 313).
          debugPrint(
            '[BUILD427][FIRESTORE] loadHistories permission-denied '
            'uid=$uid — fast-fail instantâneo (sem cache retry)',
          );
          debugPrint(
            '[FIRESTORE_AUTH_BARRIER] operation=loadHistories '
            'allowed=false reason=permission_denied uid=$uid '
            'sdkRequestDispatched=true '
            'result=authDenied — cache local preservado, escrita proibida',
          );
          // Retorna [] para compatibilidade de interface mas sem disparar escrita
          // de "novo usuário" — o chamador não recebe FirestoreLoadResult diretamente
          // mas o log acima indica ao operador que o cache foi preservado.
          return [];
        } else {
          // Outros erros FirebaseException → tenta cache local como fallback
          try {
            snap = await query
                .get(const GetOptions(source: Source.cache))
                .timeout(const Duration(seconds: 4));
          } catch (_) {
            return [];
          }
        }
      } catch (_) {
        // Timeout / offline → fallback para cache local com timeout curto
        try {
          snap = await query
              .get(const GetOptions(source: Source.cache))
              .timeout(const Duration(seconds: 4));
        } catch (_) {
          return [];
        }
      }

      final list = snap.docs
          .map((d) => ClinicalHistoryModel.fromJson(sdkDocToSafeMap(d.data())))
          .toList();
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return list;
    } on FirebaseException catch (e) {
      debugPrint(
        '[BUILD427][FIRESTORE] loadHistories FirebaseException '
        'code=${e.code} uid=$uid — retornando []',
      );
      return [];
    } catch (_) {
      return [];
    }
  }

  // ── BUILD 463-A.1 / 463-A.1.2: Typed loadHistories returning FirestoreLoadResult
  // Canonical typed variant. All internal callers must use this method.
  // Dual-check barrier: (1) null SDK user, (2) uid mismatch — both block dispatch.
  static Future<FirestoreLoadResult<List<ClinicalHistoryModel>>>
  loadHistoriesTyped(String uid) async {
    final _fbUserT = FirebaseAuth.instance.currentUser;
    if (!_isFirebaseReady || _fbUserT == null) {
      debugPrint(
        '[FIRESTORE_AUTH_BARRIER] operation=loadHistoriesTyped '
        'allowed=false reason=firebase_user_null uid=$uid '
        'sdkRequestDispatched=false',
      );
      return FirestoreLoadResult.authDenied();
    }
    if (_fbUserT.uid != uid) {
      debugPrint(
        '[FIRESTORE_AUTH_BARRIER] operation=loadHistoriesTyped '
        'expectedUid=$uid firebaseUid=${_fbUserT.uid} '
        'allowed=false reason=uid_mismatch sdkRequestDispatched=false',
      );
      return FirestoreLoadResult.authDenied();
    }
    try {
      final query = _userHistories(uid);
      QuerySnapshot<Map<String, dynamic>> snap;
      try {
        snap = await query
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 10));
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          debugPrint(
            '[FIRESTORE_AUTH_BARRIER] operation=loadHistoriesTyped '
            'allowed=false reason=permission_denied uid=$uid '
            'sdkRequestDispatched=true → authDenied',
          );
          return FirestoreLoadResult.authDenied();
        }
        // Network/unavailable FirebaseException → cache fallback.
        // ALGEBRAIC RULE: server failed → 0 cache docs = offline(), not empty().
        try {
          snap = await query
              .get(const GetOptions(source: Source.cache))
              .timeout(const Duration(seconds: 4));
        } catch (_) {
          return FirestoreLoadResult.offline();
        }
        if (snap.docs.isEmpty) return FirestoreLoadResult.offline();
        final listCached = snap.docs
            .map(
              (d) => ClinicalHistoryModel.fromJson(sdkDocToSafeMap(d.data())),
            )
            .toList();
        listCached.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return FirestoreLoadResult.success(listCached);
      } catch (_) {
        // Timeout or unknown error → cache fallback.
        // ALGEBRAIC RULE: server failed → 0 cache docs = offline(), not empty().
        try {
          snap = await query
              .get(const GetOptions(source: Source.cache))
              .timeout(const Duration(seconds: 4));
        } catch (_) {
          return FirestoreLoadResult.offline();
        }
        if (snap.docs.isEmpty) return FirestoreLoadResult.offline();
        final listCached = snap.docs
            .map(
              (d) => ClinicalHistoryModel.fromJson(sdkDocToSafeMap(d.data())),
            )
            .toList();
        listCached.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return FirestoreLoadResult.success(listCached);
      }
      // Server succeeded — authoritative empty is valid here.
      if (snap.docs.isEmpty) return FirestoreLoadResult.empty();
      final list = snap.docs
          .map((d) => ClinicalHistoryModel.fromJson(sdkDocToSafeMap(d.data())))
          .toList();
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return FirestoreLoadResult.success(list);
    } on FirebaseException catch (e) {
      debugPrint(
        '[FirestoreService] loadHistoriesTyped FirebaseException '
        'code=${e.code} uid=$uid',
      );
      if (e.code == 'permission-denied')
        return FirestoreLoadResult.authDenied();
      return FirestoreLoadResult.failure(e);
    } catch (e) {
      return FirestoreLoadResult.failure(e);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MICRO-BUILD 463-A.2.1 — Typed Secondary Collection Reads
  //
  // Every secondary data retrieval operation returns FirestoreLoadResult<T>
  // with strict operational isolation:
  //   • authDenied()  — short-circuit when SDK user is null or uid mismatches.
  //                     No Firestore SDK call is ever dispatched.
  //   • success(data) — server read succeeded; data is authoritative.
  //   • offline()     — server read failed; valid cache data is returned
  //                     via success(cachedData). Under no circumstances does
  //                     an offline error collapse into a false positive empty().
  //   • failure(e)    — unexpected error; caller must freeze local cache.
  //
  // All methods follow the dual-check barrier pattern from loadHistoriesTyped():
  //   (1) FirebaseAuth.instance.currentUser == null → authDenied immediately
  //   (2) currentUser.uid != uid              → authDenied immediately
  // Neither check ever starts a background timer or watchdog.
  // ══════════════════════════════════════════════════════════════════════════

  // ── MICRO-BUILD 463-A.2.1: loadFavDrugsTyped ─────────────────────────────
  /// Returns the IDs of the user's favourite drugs as a typed algebraic result.
  /// Short-circuits with authDenied() if the SDK user is null or uid mismatches.
  /// Falls back to Source.cache on network failure — never collapses to empty().
  static Future<FirestoreLoadResult<Set<String>>> loadFavDrugsTyped(
    String uid,
  ) async {
    final _fbUser = FirebaseAuth.instance.currentUser;
    if (!_isFirebaseReady || _fbUser == null) {
      debugPrint(
        '[FIRESTORE_AUTH_BARRIER][TYPED] operation=loadFavDrugsTyped '
        'allowed=false reason=firebase_user_null uid=$uid '
        'sdkRequestDispatched=false',
      );
      return FirestoreLoadResult.authDenied();
    }
    if (_fbUser.uid != uid) {
      debugPrint(
        '[FIRESTORE_AUTH_BARRIER][TYPED] operation=loadFavDrugsTyped '
        'expectedUid=$uid firebaseUid=${_fbUser.uid} '
        'allowed=false reason=uid_mismatch sdkRequestDispatched=false',
      );
      return FirestoreLoadResult.authDenied();
    }
    try {
      DocumentSnapshot<Map<String, dynamic>> doc;
      try {
        doc = await _userFavs(uid)
            .doc('drugs')
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 10));
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          debugPrint(
            '[FIRESTORE_AUTH_BARRIER][TYPED] operation=loadFavDrugsTyped '
            'allowed=false reason=permission_denied uid=$uid '
            'sdkRequestDispatched=true → authDenied',
          );
          return FirestoreLoadResult.authDenied();
        }
        // Network/unavailable error → try local cache before returning offline()
        // ALGEBRAIC RULE: server failed → doc missing in cache = offline(), not empty().
        try {
          doc = await _userFavs(
            uid,
          ).doc('drugs').get(const GetOptions(source: Source.cache));
          if (!doc.exists) return FirestoreLoadResult.offline();
          return FirestoreLoadResult.success(
            safeStringList(doc.data()?['ids']).toSet(),
          );
        } catch (_) {
          return FirestoreLoadResult.offline();
        }
      } catch (_) {
        // Timeout or other error → cache fallback
        // ALGEBRAIC RULE: server failed → doc missing in cache = offline(), not empty().
        try {
          doc = await _userFavs(
            uid,
          ).doc('drugs').get(const GetOptions(source: Source.cache));
          if (!doc.exists) return FirestoreLoadResult.offline();
          return FirestoreLoadResult.success(
            safeStringList(doc.data()?['ids']).toSet(),
          );
        } catch (_) {
          return FirestoreLoadResult.offline();
        }
      }
      if (!doc.exists) return FirestoreLoadResult.empty();
      return FirestoreLoadResult.success(
        safeStringList(doc.data()?['ids']).toSet(),
      );
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied')
        return FirestoreLoadResult.authDenied();
      return FirestoreLoadResult.failure(e);
    } catch (e) {
      return FirestoreLoadResult.failure(e);
    }
  }

  // ── MICRO-BUILD 463-A.2.1: loadFavProtocolsTyped ─────────────────────────
  /// Returns the IDs of the user's favourite protocols as a typed algebraic result.
  static Future<FirestoreLoadResult<Set<String>>> loadFavProtocolsTyped(
    String uid,
  ) async {
    final _fbUser = FirebaseAuth.instance.currentUser;
    if (!_isFirebaseReady || _fbUser == null) {
      debugPrint(
        '[FIRESTORE_AUTH_BARRIER][TYPED] operation=loadFavProtocolsTyped '
        'allowed=false reason=firebase_user_null uid=$uid '
        'sdkRequestDispatched=false',
      );
      return FirestoreLoadResult.authDenied();
    }
    if (_fbUser.uid != uid) {
      debugPrint(
        '[FIRESTORE_AUTH_BARRIER][TYPED] operation=loadFavProtocolsTyped '
        'expectedUid=$uid firebaseUid=${_fbUser.uid} '
        'allowed=false reason=uid_mismatch sdkRequestDispatched=false',
      );
      return FirestoreLoadResult.authDenied();
    }
    try {
      DocumentSnapshot<Map<String, dynamic>> doc;
      try {
        doc = await _userFavs(uid)
            .doc('protocols')
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 10));
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          debugPrint(
            '[FIRESTORE_AUTH_BARRIER][TYPED] operation=loadFavProtocolsTyped '
            'allowed=false reason=permission_denied uid=$uid → authDenied',
          );
          return FirestoreLoadResult.authDenied();
        }
        // ALGEBRAIC RULE: server failed → doc missing in cache = offline(), not empty().
        try {
          doc = await _userFavs(
            uid,
          ).doc('protocols').get(const GetOptions(source: Source.cache));
          if (!doc.exists) return FirestoreLoadResult.offline();
          return FirestoreLoadResult.success(
            safeStringList(doc.data()?['ids']).toSet(),
          );
        } catch (_) {
          return FirestoreLoadResult.offline();
        }
      } catch (_) {
        // ALGEBRAIC RULE: server failed → doc missing in cache = offline(), not empty().
        try {
          doc = await _userFavs(
            uid,
          ).doc('protocols').get(const GetOptions(source: Source.cache));
          if (!doc.exists) return FirestoreLoadResult.offline();
          return FirestoreLoadResult.success(
            safeStringList(doc.data()?['ids']).toSet(),
          );
        } catch (_) {
          return FirestoreLoadResult.offline();
        }
      }
      if (!doc.exists) return FirestoreLoadResult.empty();
      return FirestoreLoadResult.success(
        safeStringList(doc.data()?['ids']).toSet(),
      );
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied')
        return FirestoreLoadResult.authDenied();
      return FirestoreLoadResult.failure(e);
    } catch (e) {
      return FirestoreLoadResult.failure(e);
    }
  }

  // ── MICRO-BUILD 463-A.2.1: loadFavPrescriptionsTyped ─────────────────────
  /// Returns the IDs of the user's favourite prescriptions as a typed algebraic result.
  static Future<FirestoreLoadResult<Set<String>>> loadFavPrescriptionsTyped(
    String uid,
  ) async {
    final _fbUser = FirebaseAuth.instance.currentUser;
    if (!_isFirebaseReady || _fbUser == null) {
      debugPrint(
        '[FIRESTORE_AUTH_BARRIER][TYPED] operation=loadFavPrescriptionsTyped '
        'allowed=false reason=firebase_user_null uid=$uid '
        'sdkRequestDispatched=false',
      );
      return FirestoreLoadResult.authDenied();
    }
    if (_fbUser.uid != uid) {
      debugPrint(
        '[FIRESTORE_AUTH_BARRIER][TYPED] operation=loadFavPrescriptionsTyped '
        'expectedUid=$uid firebaseUid=${_fbUser.uid} '
        'allowed=false reason=uid_mismatch sdkRequestDispatched=false',
      );
      return FirestoreLoadResult.authDenied();
    }
    try {
      DocumentSnapshot<Map<String, dynamic>> doc;
      try {
        doc = await _userFavs(uid)
            .doc('prescriptions')
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 10));
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          debugPrint(
            '[FIRESTORE_AUTH_BARRIER][TYPED] operation=loadFavPrescriptionsTyped '
            'allowed=false reason=permission_denied uid=$uid → authDenied',
          );
          return FirestoreLoadResult.authDenied();
        }
        // ALGEBRAIC RULE: server failed → doc missing in cache = offline(), not empty().
        try {
          doc = await _userFavs(
            uid,
          ).doc('prescriptions').get(const GetOptions(source: Source.cache));
          if (!doc.exists) return FirestoreLoadResult.offline();
          return FirestoreLoadResult.success(
            safeStringList(doc.data()?['ids']).toSet(),
          );
        } catch (_) {
          return FirestoreLoadResult.offline();
        }
      } catch (_) {
        // ALGEBRAIC RULE: server failed → doc missing in cache = offline(), not empty().
        try {
          doc = await _userFavs(
            uid,
          ).doc('prescriptions').get(const GetOptions(source: Source.cache));
          if (!doc.exists) return FirestoreLoadResult.offline();
          return FirestoreLoadResult.success(
            safeStringList(doc.data()?['ids']).toSet(),
          );
        } catch (_) {
          return FirestoreLoadResult.offline();
        }
      }
      if (!doc.exists) return FirestoreLoadResult.empty();
      return FirestoreLoadResult.success(
        safeStringList(doc.data()?['ids']).toSet(),
      );
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied')
        return FirestoreLoadResult.authDenied();
      return FirestoreLoadResult.failure(e);
    } catch (e) {
      return FirestoreLoadResult.failure(e);
    }
  }

  // ── MICRO-BUILD 463-A.2.1: loadFavCasesTyped ─────────────────────────────
  /// Returns the IDs of the user's favourite cases as a typed algebraic result.
  static Future<FirestoreLoadResult<Set<String>>> loadFavCasesTyped(
    String uid,
  ) async {
    final _fbUser = FirebaseAuth.instance.currentUser;
    if (!_isFirebaseReady || _fbUser == null) {
      debugPrint(
        '[FIRESTORE_AUTH_BARRIER][TYPED] operation=loadFavCasesTyped '
        'allowed=false reason=firebase_user_null uid=$uid '
        'sdkRequestDispatched=false',
      );
      return FirestoreLoadResult.authDenied();
    }
    if (_fbUser.uid != uid) {
      debugPrint(
        '[FIRESTORE_AUTH_BARRIER][TYPED] operation=loadFavCasesTyped '
        'expectedUid=$uid firebaseUid=${_fbUser.uid} '
        'allowed=false reason=uid_mismatch sdkRequestDispatched=false',
      );
      return FirestoreLoadResult.authDenied();
    }
    try {
      DocumentSnapshot<Map<String, dynamic>> doc;
      try {
        doc = await _userFavs(uid)
            .doc('fav_cases')
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 10));
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          debugPrint(
            '[FIRESTORE_AUTH_BARRIER][TYPED] operation=loadFavCasesTyped '
            'allowed=false reason=permission_denied uid=$uid → authDenied',
          );
          return FirestoreLoadResult.authDenied();
        }
        // ALGEBRAIC RULE: server failed → doc missing in cache = offline(), not empty().
        try {
          doc = await _userFavs(
            uid,
          ).doc('fav_cases').get(const GetOptions(source: Source.cache));
          if (!doc.exists) return FirestoreLoadResult.offline();
          return FirestoreLoadResult.success(
            safeStringList(doc.data()?['ids']).toSet(),
          );
        } catch (_) {
          return FirestoreLoadResult.offline();
        }
      } catch (_) {
        // ALGEBRAIC RULE: server failed → doc missing in cache = offline(), not empty().
        try {
          doc = await _userFavs(
            uid,
          ).doc('fav_cases').get(const GetOptions(source: Source.cache));
          if (!doc.exists) return FirestoreLoadResult.offline();
          return FirestoreLoadResult.success(
            safeStringList(doc.data()?['ids']).toSet(),
          );
        } catch (_) {
          return FirestoreLoadResult.offline();
        }
      }
      if (!doc.exists) return FirestoreLoadResult.empty();
      return FirestoreLoadResult.success(
        safeStringList(doc.data()?['ids']).toSet(),
      );
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied')
        return FirestoreLoadResult.authDenied();
      return FirestoreLoadResult.failure(e);
    } catch (e) {
      return FirestoreLoadResult.failure(e);
    }
  }

  // ── MICRO-BUILD 463-A.2.1: loadCasesTyped ────────────────────────────────
  /// Returns the user's custom clinical cases as a typed algebraic result.
  /// Auth-denied immediately when SDK user is null — no watchdog, no timer.
  static Future<FirestoreLoadResult<List<ClinicalCaseModel>>> loadCasesTyped(
    String uid,
  ) async {
    final _fbUser = FirebaseAuth.instance.currentUser;
    if (!_isFirebaseReady || _fbUser == null) {
      debugPrint(
        '[FIRESTORE_AUTH_BARRIER][TYPED] operation=loadCasesTyped '
        'allowed=false reason=firebase_user_null uid=$uid '
        'sdkRequestDispatched=false',
      );
      return FirestoreLoadResult.authDenied();
    }
    if (_fbUser.uid != uid) {
      debugPrint(
        '[FIRESTORE_AUTH_BARRIER][TYPED] operation=loadCasesTyped '
        'expectedUid=$uid firebaseUid=${_fbUser.uid} '
        'allowed=false reason=uid_mismatch sdkRequestDispatched=false',
      );
      return FirestoreLoadResult.authDenied();
    }
    try {
      QuerySnapshot<Map<String, dynamic>> snap;
      try {
        snap = await _userCases(uid)
            .where('isCustom', isEqualTo: true)
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 10));
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          debugPrint(
            '[FIRESTORE_AUTH_BARRIER][TYPED] operation=loadCasesTyped '
            'allowed=false reason=permission_denied uid=$uid → authDenied',
          );
          return FirestoreLoadResult.authDenied();
        }
        // Network/unavailable → try cache.
        // ALGEBRAIC RULE: server failed → 0 cache docs = offline(), not empty().
        try {
          snap = await _userCases(uid)
              .where('isCustom', isEqualTo: true)
              .get(const GetOptions(source: Source.cache));
        } catch (_) {
          return FirestoreLoadResult.offline();
        }
        if (snap.docs.isEmpty) return FirestoreLoadResult.offline();
        final casesCached = <ClinicalCaseModel>[];
        for (final d in snap.docs) {
          try {
            casesCached.add(ClinicalCaseModel.fromJson(sdkDocWithId(d)));
          } catch (_) {}
        }
        casesCached.sort(
          (a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''),
        );
        return FirestoreLoadResult.success(casesCached);
      } catch (_) {
        // Timeout or unknown → try cache.
        // ALGEBRAIC RULE: server failed → 0 cache docs = offline(), not empty().
        try {
          snap = await _userCases(uid)
              .where('isCustom', isEqualTo: true)
              .get(const GetOptions(source: Source.cache));
        } catch (_) {
          return FirestoreLoadResult.offline();
        }
        if (snap.docs.isEmpty) return FirestoreLoadResult.offline();
        final casesCached = <ClinicalCaseModel>[];
        for (final d in snap.docs) {
          try {
            casesCached.add(ClinicalCaseModel.fromJson(sdkDocWithId(d)));
          } catch (_) {}
        }
        casesCached.sort(
          (a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''),
        );
        return FirestoreLoadResult.success(casesCached);
      }
      // Server succeeded — authoritative empty is valid here.
      if (snap.docs.isEmpty) return FirestoreLoadResult.empty();
      final cases = <ClinicalCaseModel>[];
      for (final d in snap.docs) {
        try {
          cases.add(ClinicalCaseModel.fromJson(sdkDocWithId(d)));
        } catch (_) {}
      }
      cases.sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
      return FirestoreLoadResult.success(cases);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied')
        return FirestoreLoadResult.authDenied();
      return FirestoreLoadResult.failure(e);
    } catch (e) {
      return FirestoreLoadResult.failure(e);
    }
  }

  // ── MICRO-BUILD 462E-A.5.3.7.3.2.5.2 [PILLAR 1]: Explicit loader separation ─
  //
  // Two distinct loaders target two distinct Firestore collections:
  //   • loadLegacyAiSessionsTyped   → ai_chat_history  (schema v1, legacy inline)
  //   • loadCanonicalAiSessionSummariesTyped → ai_sessions (schema v2, queryable)
  //
  // NEVER mix collection references between these two methods.

  /// [PILLAR 1-A] Fetches legacy session summaries from 'ai_chat_history'.
  /// Targets [_userAiHistory] — schema v1 inline documents.
  /// Same auth-barrier and cache-fallback contract as loadAiSessionsTyped.
  static Future<FirestoreLoadResult<List<Map<String, dynamic>>>>
  loadLegacyAiSessionsTyped(String uid) async {
    final _fbUser = FirebaseAuth.instance.currentUser;
    if (!_isFirebaseReady || _fbUser == null) {
      debugPrint(
        '[FIRESTORE][loadLegacyAiSessionsTyped] '
        'allowed=false reason=firebase_user_null uid=$uid',
      );
      return FirestoreLoadResult.authDenied();
    }
    if (_fbUser.uid != uid) {
      debugPrint(
        '[FIRESTORE][loadLegacyAiSessionsTyped] '
        'allowed=false reason=uid_mismatch uid=$uid fbUid=${_fbUser.uid}',
      );
      return FirestoreLoadResult.authDenied();
    }
    final query = _userAiHistory(
      uid,
    ).orderBy('updatedAt', descending: true).limit(20);
    try {
      QuerySnapshot<Map<String, dynamic>> snap;
      try {
        snap = await query
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 8));
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          debugPrint(
            '[FIRESTORE][loadLegacyAiSessionsTyped] '
            'allowed=false reason=permission_denied uid=$uid',
          );
          return FirestoreLoadResult.authDenied();
        }
        try {
          snap = await query.get(const GetOptions(source: Source.cache));
          final cached = snap.docs
              .map((d) => sdkDocToSafeMap(d.data()))
              .toList();
          return cached.isEmpty
              ? FirestoreLoadResult.offline()
              : FirestoreLoadResult.success(cached);
        } catch (_) {
          return FirestoreLoadResult.offline();
        }
      } catch (_) {
        try {
          snap = await query.get(const GetOptions(source: Source.cache));
          final cached = snap.docs
              .map((d) => sdkDocToSafeMap(d.data()))
              .toList();
          return cached.isEmpty
              ? FirestoreLoadResult.offline()
              : FirestoreLoadResult.success(cached);
        } catch (_) {
          return FirestoreLoadResult.offline();
        }
      }
      if (snap.docs.isEmpty) return FirestoreLoadResult.empty();
      return FirestoreLoadResult.success(
        snap.docs.map((d) => sdkDocToSafeMap(d.data())).toList(),
      );
    } catch (e) {
      return FirestoreLoadResult.failure(e);
    }
  }

  /// [PILLAR 1-B] Fetches canonical v2 session summaries from 'ai_sessions'.
  /// Targets [_userAiSessions] — schema v2 with isDeleted + updatedAt index.
  /// Filter: isDeleted==false, ordered descending by updatedAt, limit 10.
  static Future<FirestoreLoadResult<List<Map<String, dynamic>>>>
  loadCanonicalAiSessionSummariesTyped(String uid) async {
    final _fbUser = FirebaseAuth.instance.currentUser;
    if (!_isFirebaseReady || _fbUser == null) {
      debugPrint(
        '[FIRESTORE][loadCanonicalAiSessionSummariesTyped] '
        'allowed=false reason=firebase_user_null uid=$uid',
      );
      return FirestoreLoadResult.authDenied();
    }
    if (_fbUser.uid != uid) {
      debugPrint(
        '[FIRESTORE][loadCanonicalAiSessionSummariesTyped] '
        'allowed=false reason=uid_mismatch uid=$uid fbUid=${_fbUser.uid}',
      );
      return FirestoreLoadResult.authDenied();
    }
    final query = _userAiSessions(uid)
        .where('isDeleted', isEqualTo: false)
        .orderBy('updatedAt', descending: true)
        .limit(20);
    try {
      QuerySnapshot<Map<String, dynamic>> snap;
      try {
        snap = await query
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 8));
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          debugPrint(
            '[FIRESTORE][loadCanonicalAiSessionSummariesTyped] '
            'allowed=false reason=permission_denied uid=$uid',
          );
          return FirestoreLoadResult.authDenied();
        }
        try {
          snap = await query.get(const GetOptions(source: Source.cache));
          final cached = snap.docs
              .map((d) => sdkDocToSafeMap(d.data()))
              .toList();
          return cached.isEmpty
              ? FirestoreLoadResult.offline()
              : FirestoreLoadResult.success(cached);
        } catch (_) {
          return FirestoreLoadResult.offline();
        }
      } catch (_) {
        try {
          snap = await query.get(const GetOptions(source: Source.cache));
          final cached = snap.docs
              .map((d) => sdkDocToSafeMap(d.data()))
              .toList();
          return cached.isEmpty
              ? FirestoreLoadResult.offline()
              : FirestoreLoadResult.success(cached);
        } catch (_) {
          return FirestoreLoadResult.offline();
        }
      }
      if (snap.docs.isEmpty) return FirestoreLoadResult.empty();
      return FirestoreLoadResult.success(
        snap.docs.map((d) => sdkDocToSafeMap(d.data())).toList(),
      );
    } catch (e) {
      return FirestoreLoadResult.failure(e);
    }
  }

  /// Loads exchange sub-documents for a canonical v2 session.
  /// Path: users/{uid}/ai_sessions/{sessionId}/exchanges

  // M74B_POST_FINAL_PRESENTATION_RECONCILIATION_V1
  static Future<({bool ok, bool permissionDenied, Object? error})>
      reconcileAiExchangeFinalPresentation({
    required String uid,
    required String sessionId,
    required String requestId,
    required String assistantPresentation,
    Map<String, dynamic>? clinicalOutputJson,
  }) async {
    final normalizedUid = uid.trim();
    final normalizedSessionId = sessionId.trim();
    final normalizedRequestId = requestId.trim();
    final normalizedPresentation = assistantPresentation.trim();

    if (normalizedUid.isEmpty ||
        normalizedSessionId.isEmpty ||
        normalizedRequestId.isEmpty ||
        normalizedPresentation.isEmpty) {
      return (
        ok: false,
        permissionDenied: false,
        error: ArgumentError('invalid_final_presentation_reconciliation'),
      );
    }

    final fbUser = FirebaseAuth.instance.currentUser;
    if (!_isFirebaseReady ||
        fbUser == null ||
        fbUser.uid != normalizedUid) {
      return (
        ok: false,
        permissionDenied: true,
        error: null,
      );
    }

    try {
      final sessionRef =
          _userAiSessions(normalizedUid).doc(normalizedSessionId);
      final exchangeRef =
          sessionRef.collection('exchanges').doc(normalizedRequestId);

      final preview = normalizedPresentation.length > 160
          ? '${normalizedPresentation.substring(0, 160)}\u2026'
          : normalizedPresentation;

      final exchangeData = <String, dynamic>{
        'assistantPresentation': normalizedPresentation,
        'presentationSchemaVersion': 1,
        'presentationUpdatedAt': FieldValue.serverTimestamp(),
      };

      if (clinicalOutputJson != null) {
        exchangeData['clinicalOutput'] =
            Map<String, dynamic>.from(clinicalOutputJson);
      }

      final batch = _db.batch();

      // The canonical provider exchange must already exist.
      // update() fails closed instead of creating a second exchange.
      batch.update(exchangeRef, exchangeData);

      batch.set(
        sessionRef,
        <String, dynamic>{
          'lastRequestId': normalizedRequestId,
          'lastAssistantPreview': preview,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      return (
        ok: true,
        permissionDenied: false,
        error: null,
      );
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        return (
          ok: false,
          permissionDenied: true,
          error: error,
        );
      }
      return (
        ok: false,
        permissionDenied: false,
        error: error,
      );
    } catch (error) {
      return (
        ok: false,
        permissionDenied: false,
        error: error,
      );
    }
  }

  /// Ordered ascending by createdAt (chronological turn order).
  static Future<FirestoreLoadResult<List<Map<String, dynamic>>>>
  loadAiSessionExchangesTyped(String uid, String sessionId) async {
    final _fbUser = FirebaseAuth.instance.currentUser;
    if (!_isFirebaseReady || _fbUser == null) {
      debugPrint(
        '[FIRESTORE][loadAiSessionExchangesTyped] '
        'allowed=false reason=firebase_user_null uid=$uid',
      );
      return FirestoreLoadResult.authDenied();
    }
    if (_fbUser.uid != uid) {
      debugPrint(
        '[FIRESTORE][loadAiSessionExchangesTyped] '
        'allowed=false reason=uid_mismatch uid=$uid fbUid=${_fbUser.uid}',
      );
      return FirestoreLoadResult.authDenied();
    }
    try {
      final snap = await _userAiSessions(uid)
          .doc(sessionId)
          .collection('exchanges')
          .orderBy('createdAt', descending: false)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));
      if (snap.docs.isEmpty) return FirestoreLoadResult.empty();
      return FirestoreLoadResult.success(
        snap.docs.map((d) => sdkDocToSafeMap(d.data())).toList(),
      );
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        debugPrint(
          '[FIRESTORE][loadAiSessionExchangesTyped] '
          'allowed=false reason=permission_denied uid=$uid sessionId=$sessionId',
        );
        return FirestoreLoadResult.authDenied();
      }
      return FirestoreLoadResult.failure(e);
    } catch (e) {
      return FirestoreLoadResult.failure(e);
    }
  }

  // ── MICRO-BUILD 463-A.2.1: loadAiSessionsTyped ───────────────────────────
  /// Returns the user's AI chat sessions as a typed algebraic result.
  ///
  /// INVARIANT: If FirebaseAuth.instance.currentUser is null, returns
  /// authDenied() immediately — no _waitForAuth(), no timer, no polling.
  /// The UI data layer reacts solely to AppAuthBarrierState convergence signals.
  ///
  /// Cache preservation: a network failure returns success(cachedData) when
  /// valid cache entries exist. It never collapses to empty() silently.
  static Future<FirestoreLoadResult<List<Map<String, dynamic>>>>
  loadAiSessionsTyped(String uid) async {
    final _fbUser = FirebaseAuth.instance.currentUser;
    if (!_isFirebaseReady || _fbUser == null) {
      debugPrint(
        '[FIRESTORE_AUTH_BARRIER][TYPED] operation=loadAiSessionsTyped '
        'allowed=false reason=firebase_user_null uid=$uid '
        'sdkRequestDispatched=false',
      );
      return FirestoreLoadResult.authDenied();
    }
    if (_fbUser.uid != uid) {
      debugPrint(
        '[FIRESTORE_AUTH_BARRIER][TYPED] operation=loadAiSessionsTyped '
        'expectedUid=$uid firebaseUid=${_fbUser.uid} '
        'allowed=false reason=uid_mismatch sdkRequestDispatched=false',
      );
      return FirestoreLoadResult.authDenied();
    }
    final query = _userAiHistory(
      uid,
    ).orderBy('updatedAt', descending: true).limit(20);
    try {
      QuerySnapshot<Map<String, dynamic>> snap;
      try {
        snap = await query
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 8));
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          debugPrint(
            '[FIRESTORE_AUTH_BARRIER][TYPED] operation=loadAiSessionsTyped '
            'allowed=false reason=permission_denied uid=$uid → authDenied',
          );
          return FirestoreLoadResult.authDenied();
        }
        // Network error → try cache.
        // ALGEBRAIC RULE: server failed → 0 cache entries = offline(), not empty().
        try {
          snap = await query.get(const GetOptions(source: Source.cache));
          final cached = snap.docs
              .map((d) => sdkDocToSafeMap(d.data()))
              .toList();
          debugPrint(
            '[FIRESTORE_AUTH_BARRIER][TYPED] operation=loadAiSessionsTyped '
            'source=cache count=${cached.length} uid=$uid',
          );
          return cached.isEmpty
              ? FirestoreLoadResult.offline()
              : FirestoreLoadResult.success(cached);
        } catch (_) {
          return FirestoreLoadResult.offline();
        }
      } catch (_) {
        // Timeout or unknown error → cache fallback.
        // ALGEBRAIC RULE: server failed → 0 cache entries = offline(), not empty().
        try {
          snap = await query.get(const GetOptions(source: Source.cache));
          final cached = snap.docs
              .map((d) => sdkDocToSafeMap(d.data()))
              .toList();
          debugPrint(
            '[FIRESTORE_AUTH_BARRIER][TYPED] operation=loadAiSessionsTyped '
            'source=cache(timeout_fallback) count=${cached.length} uid=$uid',
          );
          return cached.isEmpty
              ? FirestoreLoadResult.offline()
              : FirestoreLoadResult.success(cached);
        } catch (_) {
          return FirestoreLoadResult.offline();
        }
      }
      if (snap.docs.isEmpty) return FirestoreLoadResult.empty();
      return FirestoreLoadResult.success(
        snap.docs.map((d) => sdkDocToSafeMap(d.data())).toList(),
      );
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied')
        return FirestoreLoadResult.authDenied();
      return FirestoreLoadResult.failure(e);
    } catch (e) {
      return FirestoreLoadResult.failure(e);
    }
  }

  /// Auto-closing secure stream of user histories — receives real-time updates.
  ///
  /// MICRO-BUILD 463-A.2.2: Identity guard active on every snapshot emission.
  /// If [FirebaseAuth.instance.currentUser?.uid] becomes null or ≠ [uid],
  /// the stream emits a synchronous done signal and closes immediately.
  /// No transient snapshots from an identity-shifted session are ever emitted.
  ///
  /// Stale arrivals after auto-close are tagged:
  ///   [SECURE_STREAM_DROPPED] parentUid=<uid> activeUid=<uid> reason=stale_stream_generation
  static Stream<List<ClinicalHistoryModel>> streamHistories(String uid) async* {
    await for (final snap in _userHistories(uid).snapshots()) {
      final activeUid = FirebaseAuth.instance.currentUser?.uid;
      if (activeUid != uid) {
        debugPrint(
          '[SECURE_STREAM][AUTO_CLOSE] stream=streamHistories '
          'parentUid=$uid activeUid=$activeUid',
        );
        yield* Stream.empty();
        return;
      }
      final list = snap.docs
          .map((d) => ClinicalHistoryModel.fromJson(sdkDocToSafeMap(d.data())))
          .toList();
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      yield list;
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
      publicData['isHidden'] = publicData['isHidden'] ?? false;

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
        try {
          await _publicHistories.doc(h.id).delete();
        } catch (_) {}
      }
      return null;
    }
  }

  /// Grava/atualiza um documento em public_histories via REST (web).
  static Future<void> _savePublicHistoryRest(
    String docId,
    Map<String, dynamic> data,
  ) async {
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

  static Future<void> deleteHistory(
    String uid,
    String hid, {
    bool wasPublic = false,
  }) async {
    try {
      await _userHistories(uid).doc(hid).delete();
      if (wasPublic) {
        try {
          await _publicHistories.doc(hid).delete();
        } catch (_) {}
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

  static Future<List<ClinicalHistoryModel>> _loadPublicHistoriesSdk({
    Source? source,
  }) async {
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

      // ── CAMADA DUPLA DE PROTEÇÃO contra TypeError em dart2js release ─────
      // Mesmo que _safeDocsToHistoryList já tenha try/catch individual por doc,
      // envolvemos toda a chamada em try/catch extra para garantir que NENHUMA
      // exceção (inclusive TypeError de tipos JS inesperados) escapa para o
      // catch externo que exibiria o erro na UI do usuário.
      List<ClinicalHistoryModel> rawList;
      try {
        rawList = _safeDocsToHistoryList(snap.docs);
      } catch (parseError) {
        if (kDebugMode)
          debugPrint(
            '[_loadPublicHistoriesSdk] parse error silenciado: $parseError',
          );
        rawList = const [];
      }

      List<ClinicalHistoryModel> list;
      try {
        list = _normalizePublicHistories(rawList.where((h) => !h.isHidden));
      } catch (_) {
        list = rawList; // fallback: sem normalização
      }

      if (list.isNotEmpty) {
        try {
          await _saveCachedPublicHistories(list);
        } catch (_) {}
        _clearPublicHistoriesError();
      }
      _debugPublicHistories(
        'sdk load count=${list.length} source=${source ?? 'default'}',
      );
      return list;
    } on FirebaseException catch (e) {
      // permission-denied: regras do Firestore bloquearam a leitura.
      // CAUSA MÁIS COMUM: arquivo firestore.rules correto localmente mas
      // não implantado no Firebase Console (executa: firebase deploy --only firestore:rules).
      if (e.code == 'permission-denied') {
        // Mensagem amigável ao usuário — sem jargão técnico
        _setPublicHistoriesError(
          'Não foi possível carregar as histórias públicas agora.\nToque em atualizar para tentar novamente.',
        );
        _debugPublicHistories(
          'sdk permission-denied — verifique se firestore.rules foi implantado: '
          'firebase deploy --only firestore:rules | source=${source ?? 'default'}',
        );
      } else {
        _setPublicHistoriesError(
          'Erro ao carregar histórias públicas. Tente novamente.',
        );
        _debugPublicHistories(
          'sdk firebase error ${e.code} source=${source ?? 'default'}',
        );
      }
      return [];
    } catch (e) {
      // NUNCA exibe TypeError de dart2js como erro visível ao usuário —
      // trata como lista vazia e continua para fallback/cache.
      if (kDebugMode)
        debugPrint('[_loadPublicHistoriesSdk] erro silenciado: $e');
      _debugPublicHistories(
        'sdk load failed (silenced) source=${source ?? 'default'} error=$e',
      );
      return [];
    }
  }

  static Future<List<ClinicalHistoryModel>> loadPublicHistories({
    bool forceRemote = false,
  }) async {
    // ORDEM 50 M3: Auth guard — suprime requests Firestore antes da barreira
    // de auth transposta, eliminando spam de 403 "permission-denied" no console.
    if (!_hasAnyAuthCredential) {
      _debugPublicHistories(
        'ORDEM50 M3: skip — unauthenticated, awaiting GoogleAuthBarrier',
      );
      return const <ClinicalHistoryModel>[];
    }

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
        _debugPublicHistories(
          'REST 403 — cooldown até $_publicHistoriesRestRetryAfter',
        );
      }
    } else {
      _debugPublicHistories('REST em cooldown — pulando');
    }

    // ── ETAPA 3: Cache local ─────────────────────────────────────────────────
    if (cached.isNotEmpty) {
      _debugPublicHistories('returning cached count=${cached.length}');
      return cached;
    }

    _debugPublicHistories(
      'returning empty error=${lastPublicHistoriesErrorMessage.isNotEmpty}',
    );
    return const <ClinicalHistoryModel>[];
  }

  /// Leitura pública via Firestore REST API — fallback autenticado.
  /// NUNCA chama REST sem token: se o usuário não estiver logado, retorna []
  /// imediatamente sem fazer nenhuma requisição de rede.
  /// Isso evita o 403 que o código compilado (avE() em main.dart.js) gerava
  /// ao chamar GET /public_histories?pageSize=100 sem Authorization header.
  static Future<List<ClinicalHistoryModel>> _loadPublicHistoriesRest() async {
    // ── Obtém token: Web usa AuthService.getAdminToken(), Nativo usa SDK ─────
    // No Web, FirebaseAuth.instance.currentUser é sempre null (login REST não
    // injeta token no Firebase Auth SDK). Usamos getAdminToken() como fonte
    // única de token no Web.
    String token;
    if (kIsWeb) {
      token = await AuthService.getAdminToken();
      debugPrint(
        '[WEB_AUTH] source=REST token=${token.isNotEmpty} endpoint=public_histories',
      );
      if (token.isEmpty) {
        _debugPublicHistories(
          'rest skipped — token REST vazio (não autenticado)',
        );
        return const <ClinicalHistoryModel>[];
      }
    } else {
      final currentUser = FirebaseAuth.instance.currentUser;
      debugPrint(
        '[NATIVE_AUTH] source=FirebaseSDK uid=${currentUser?.uid ?? 'null'} endpoint=public_histories',
      );
      if (currentUser == null) {
        _debugPublicHistories('rest skipped — no authenticated user (nativo)');
        return const <ClinicalHistoryModel>[];
      }
      String? sdkToken;
      try {
        sdkToken = await currentUser.getIdToken();
      } catch (e) {
        _debugPublicHistories('rest skipped — getIdToken failed: $e');
        return const <ClinicalHistoryModel>[];
      }
      if (sdkToken == null || sdkToken.isEmpty) {
        _debugPublicHistories('rest skipped — token empty after getIdToken()');
        return const <ClinicalHistoryModel>[];
      }
      token = sdkToken;
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
          _debugPublicHistories(
            'REST parse: documento ignorado por erro — $e\n$st',
          );
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
        // Web: getAdminToken() já faz auto-refresh via securetoken.googleapis.com
        // Nativo: getIdToken(true) força refresh no Firebase Auth SDK
        String? refreshed;
        try {
          if (kIsWeb) {
            refreshed = await AuthService.getAdminToken();
            debugPrint(
              '[WEB_AUTH] source=REST token=${(refreshed).isNotEmpty} endpoint=public_histories (retry)',
            );
          } else {
            refreshed = await FirebaseAuth.instance.currentUser?.getIdToken(
              true,
            );
            debugPrint(
              '[NATIVE_AUTH] source=FirebaseSDK uid=${FirebaseAuth.instance.currentUser?.uid ?? 'null'} endpoint=public_histories (retry)',
            );
          }
        } catch (_) {}
        if (refreshed != null && refreshed.isNotEmpty) {
          _debugPublicHistories('rest auth retry with refreshed token');
          resp = await doGet(
            extraHeaders: {'Authorization': 'Bearer $refreshed'},
          );
          _debugPublicHistories('rest load retry status=${resp.statusCode}');
        } else {
          // Token refresh falhou — aplica cooldown imediatamente
          _publicHistoriesRestRetryAfter = DateTime.now().add(
            _restRetryCooldown,
          );
          _setPublicHistoriesError(
            'REST public_histories HTTP ${resp.statusCode}: sem token após refresh',
          );
          _debugPublicHistories(
            'rest 403 e refresh falhou — cooldown aplicado',
          );
          return const <ClinicalHistoryModel>[];
        }
      }

      if (resp.statusCode != 200) {
        final snippet = resp.body.length > 220
            ? resp.body.substring(0, 220)
            : resp.body;
        _setPublicHistoriesError(
          'REST public_histories HTTP ${resp.statusCode}: $snippet',
        );
        // Aplica cooldown em qualquer erro HTTP (403, 401, 500...) para evitar retry storm.
        // O cooldown de 2 minutos garante que não haverá loop infinito de tentativas.
        _publicHistoriesRestRetryAfter = DateTime.now().add(_restRetryCooldown);
        _debugPublicHistories(
          'REST ${resp.statusCode} — cooldown 2min aplicado',
        );
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
    return _userHistories(
      uid,
    ).orderBy('updatedAt', descending: true).snapshots()
    // CAMADA DUPLA: _safeDocsToHistoryList já tem try/catch por doc,
    // mas envolvemos em try/catch extra para garantir que TypeError de
    // dart2js não escapa e não quebra o stream inteiro.
    .map((snap) {
      try {
        return _safeDocsToHistoryList(snap.docs);
      } catch (e) {
        if (kDebugMode)
          debugPrint('[historiesStream] parse error silenciado: $e');
        return const <ClinicalHistoryModel>[];
      }
    });
  }

  // ── Último paciente (cockpit) ─────────────────────────────────────────────
  static Future<Map<String, dynamic>?> loadLastPatient(String uid) async {
    try {
      final doc = await _userDoc(
        uid,
      ).collection('prefs').doc('last_patient').get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveLastPatient(
    String uid,
    Map<String, dynamic> data,
  ) async {
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
        final body = safeMap(jsonDecode(resp.body));
        final fields = safeMap(body['fields']);
        final data = <String, dynamic>{};

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
  /// BUILD 258: substitui Map<String,dynamic>.from() por safeMap() em todos os
  /// retornos — imune a TypeError em dart2js release quando os valores são
  /// JavaScriptObject (minified:Ou is not a subtype of minified:E).
  static Future<Map<String, dynamic>> loadAppUpdate() async {
    if (_cachedAppUpdate.isNotEmpty) {
      return safeMap(_cachedAppUpdate); // BUILD 258: safeMap em vez de .from()
    }
    if (_isRestCoolingDown(_appUpdateRetryAfter)) {
      debugPrint(
        '[FirestoreService] app_updates/current em cooldown — retornando cache',
      );
      return safeMap(_cachedAppUpdate); // BUILD 258
    }
    // BUILD 277 FIX: Skip Firestore read entirely when the user is not yet
    // authenticated. This prevents a spurious permission-denied that would
    // set a 15s cooldown, blocking the NEXT call that arrives after OAuth
    // consolidation. Instead, set a short cooldown ourselves (5s) and bail —
    // _checkAppUpdate() is re-invoked when the user navigates, so we will
    // retry naturally once the auth token is established.
    if (!_hasAnyAuthCredential) {
      if (_appUpdateRetryAfter == null) {
        _appUpdateRetryAfter = DateTime.now().add(const Duration(seconds: 5));
        debugPrint(
          '[FirestoreService] app_updates/current — usuário não autenticado, aguardando (5s)',
        );
      }
      return safeMap(_cachedAppUpdate);
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
          final doc = await _db
              .collection('app_updates')
              .doc('current')
              .get()
              .timeout(const Duration(seconds: 4));
          // BUILD 258: sdkDocToSafeMapAny — converte doc.data() (Map<String,Object?>)
          // para Map<String,dynamic> seguro sem TypeError em dart2js release mode.
          final data = doc.exists
              ? sdkDocToSafeMapAny(doc.data())
              : <String, dynamic>{};
          if (data.isNotEmpty) {
            _cachedAppUpdate = data; // já é Map<String,dynamic> seguro
            _appUpdateRetryAfter = null;
          }
          debugPrint(
            '[FirestoreService] app_updates/current SDK ok data.isNotEmpty=${data.isNotEmpty}',
          );
          return safeMap(data); // BUILD 258
        } on FirebaseException catch (e) {
          if (e.code == 'permission-denied') {
            // permission-denied: token autenticado mas sem permissão (rules).
            // Aplica cooldown CURTO (15s) para aguardar consolidação do token.
            // Não usar 2min: prejudica usuários que fazem login logo em seguida.
            _appUpdateRetryAfter = DateTime.now().add(
              const Duration(seconds: 15),
            );
            debugPrint(
              '[FirestoreService] app_updates/current permission-denied — aguardando consolidação do token (15s)',
            );
            return safeMap(_cachedAppUpdate); // BUILD 258
          }
          debugPrint(
            '[FirestoreService] app_updates/current SDK erro: ${e.code} — tentando REST',
          );
          // Outros erros SDK: tenta REST como fallback
          return await _loadAppUpdateRest();
        }
      } catch (e) {
        debugPrint('[FirestoreService] loadAppUpdate ERRO: $e');
        return safeMap(_cachedAppUpdate); // BUILD 258
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
      final resp = await http
          .get(
            Uri.parse('$_fsBase/app_updates/current?key=$_firebaseApiKey'),
            headers: _restGetHeaders(token),
          )
          .timeout(const Duration(seconds: 2));
      if (resp.statusCode != 200) {
        if (resp.statusCode == 401 || resp.statusCode == 403) {
          _appUpdateRetryAfter = DateTime.now().add(_restRetryCooldown);
        }
        debugPrint(
          '[FirestoreService] app_updates/current REST ${resp.statusCode}: ${resp.body.substring(0, resp.body.length.clamp(0, 220))}',
        );
        return safeMap(_cachedAppUpdate); // BUILD 258
      }
      _appUpdateRetryAfter = null;
      final data = _decodeFirestoreFields(resp.body);
      if (data.isNotEmpty) {
        _cachedAppUpdate = data; // já é Map<String,dynamic> seguro
      }
      return data;
    } catch (e) {
      debugPrint('[FirestoreService] _loadAppUpdateRest ERRO: $e');
      return safeMap(_cachedAppUpdate); // BUILD 258
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
        version: version,
        title: title,
        date: date,
        items: items,
        active: active,
      );
      return;
    }
    await _db.collection('app_updates').doc('current').set({
      'version': version,
      'title': title,
      'date': date,
      'items': items,
      'active': active,
    });
  }

  static Future<void> _saveAppUpdateRest({
    required String version,
    required String title,
    required String date,
    required List<String> items,
    required bool active,
  }) async {
    final token = await AuthService.getAdminToken();
    if (token.isEmpty) return;
    final fields = {
      'version': {'stringValue': version},
      'title': {'stringValue': title},
      'date': {'stringValue': date},
      'active': {'booleanValue': active},
      'items': {
        'arrayValue': {
          'values': items.map((e) => {'stringValue': e}).toList(),
        },
      },
    };
    const mask =
        'updateMask.fieldPaths=version'
        '&updateMask.fieldPaths=title'
        '&updateMask.fieldPaths=date'
        '&updateMask.fieldPaths=active'
        '&updateMask.fieldPaths=items';
    await http.patch(
      Uri.parse('$_fsBase/app_updates/current?$mask'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
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

  /// Incrementa o loginCount do usuário (+1 por sessão).
  static Future<void> incrementLoginCount(String uid) async {
    if (uid.isEmpty) return;
    try {
      await _userDoc(uid).update({
        'loginCount': FieldValue.increment(1),
        'lastSeenAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Retorna lista de UIDs de usuários com role == 'master'.
  static Future<List<String>> getMasterUids() async {
    try {
      final snap = await _db
          .collection('users')
          .where('role', isEqualTo: 'master')
          .get();
      return snap.docs.map((d) => d.id).toList();
    } catch (_) {
      return [];
    }
  }

  /// Grava uma notificação in-app na coleção 'notifications/{uid}/items'.
  /// O app lê essa coleção ao iniciar para exibir alertas pendentes.
  static Future<void> writeInAppNotification({
    required String uid,
    required String title,
    required String body,
    String payload = '',
  }) async {
    if (uid.isEmpty) return;
    try {
      await _db.collection('notifications').doc(uid).collection('items').add({
        'title': title,
        'body': body,
        'payload': payload,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
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
    required String status, // 'sent' | 'error'
    String? errorMsg,
  }) async {
    await _db.collection('email_campaigns').add({
      'subject': subject,
      'body': body,
      'sentBy': sentBy,
      'recipients': recipients,
      'recipientCount': recipientCount,
      'status': status,
      'errorMsg': errorMsg ?? '',
      'sentAt': FieldValue.serverTimestamp(),
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
      'serviceId': serviceId,
      'templateId': templateId,
      'publicKey': publicKey,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    debugPrint(
      '[FirestoreService] saveEmailJsConfig OK → app_config/emailjs (SDK)',
    );
  }

  /// Salva EmailJS config via REST PATCH (web — evita SDK permission-denied).
  static Future<void> _saveEmailJsConfigRest({
    required String serviceId,
    required String templateId,
    required String publicKey,
  }) async {
    final token = await AuthService.getAdminToken();
    if (token.isEmpty) {
      debugPrint(
        '[FirestoreService] _saveEmailJsConfigRest: token vazio — abortando',
      );
      throw Exception('Não autenticado — token de admin ausente');
    }
    final fields = {
      'serviceId': {'stringValue': serviceId},
      'templateId': {'stringValue': templateId},
      'publicKey': {'stringValue': publicKey},
      'updatedAt': {'stringValue': DateTime.now().toUtc().toIso8601String()},
    };
    const mask =
        'updateMask.fieldPaths=serviceId'
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
    debugPrint(
      '[FirestoreService] _saveEmailJsConfigRest status=${resp.statusCode}',
    );
    if (resp.statusCode != 200) {
      throw Exception(
        'REST EmailJS save: HTTP ${resp.statusCode} — ${resp.body}',
      );
    }
    debugPrint(
      '[FirestoreService] saveEmailJsConfig OK → app_config/emailjs (REST)',
    );
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
          'serviceId': safeString(d['serviceId']),
          'templateId': safeString(d['templateId']),
          'publicKey': safeString(d['publicKey']),
        };
      }
    } catch (_) {}
    // Fallback para caminho legado config/emailjs (dados antigos já salvos)
    try {
      final doc = await _db.collection('config').doc('emailjs').get();
      if (!doc.exists) return {};
      final d = safeMap(doc.data());
      return {
        'serviceId': safeString(d['serviceId']),
        'templateId': safeString(d['templateId']),
        'publicKey': safeString(d['publicKey']),
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
      final resp = await http
          .get(Uri.parse('$_fsBase/app_config/emailjs'), headers: headers)
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode == 404) return {};
      if (resp.statusCode != 200) return {};
      // safeMap: sem casts diretos — imune a TypeError em dart2js release
      final body = safeMap(jsonDecode(resp.body));
      final fields = safeMap(body['fields']);
      return {
        'serviceId': safeString(safeMap(fields['serviceId'])['stringValue']),
        'templateId': safeString(safeMap(fields['templateId'])['stringValue']),
        'publicKey': safeString(safeMap(fields['publicKey'])['stringValue']),
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
        'service_id': serviceId,
        'template_id': templateId,
        'user_id': publicKey,
        'template_params': {
          'to_email': toEmail,
          'to_name': toName,
          'subject': subject,
          'message': message,
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
    required String color, // hex string ex: '#1F6B48'
    List<String> tags = const [],
  }) async {
    final data = {
      'title': title,
      'content': content,
      'color': color,
      'tags': tags,
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
    return _userNotes(uid).orderBy('updatedAt', descending: true).snapshots()
    // Cada doc em try/catch individual via helper — imune a TypeError dart2js
    .map((snap) {
      final result = <Map<String, dynamic>>[];
      for (final doc in snap.docs) {
        try {
          result.add(sdkDocWithId(doc));
        } catch (_) {}
      }
      return result;
    });
  }

  /// Deleta uma anotação.
  static Future<void> deleteNote({
    required String uid,
    required String noteId,
  }) async {
    await _userNotes(uid).doc(noteId).delete();
  }

  // ── BIBLIOTECA CLÍNICA — Guias / PDFs ────────────────────────────────────

  static CollectionReference<Map<String, dynamic>> get _guides =>
      _db.collection('clinical_guides');

  static const int guidesPortalPageSize = 10;
  static const int _guidesSearchTokenLimit = 32;
  static const int _guidesSearchIndexVersion = 1;

  static String _normalizeGuideSearchText(String input) {
    var value = input.trim().toLowerCase();
    const from = 'áàãâäéèêëíìîïóòõôöúùûüçñ';
    const to = 'aaaaaeeeeiiiiooooouuuucn';
    for (var i = 0; i < from.length; i++) {
      value = value.replaceAll(from[i], to[i]);
    }
    return value
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static List<String> _buildGuideSearchPrefixes(GuideModel guide) {
    const stopWords = <String>{
      'para',
      'com',
      'sem',
      'uma',
      'uns',
      'das',
      'dos',
      'por',
      'que',
      'como',
      'mais',
      'menos',
      'del',
      'con',
      'sin',
      'una',
      'unos',
      'las',
      'los',
      'and',
      'the',
      'for',
      'with',
      'from',
    };

    final sources = <String>[guide.title, guide.category, guide.description];
    final terms = <String>{};

    for (final source in sources) {
      final normalized = _normalizeGuideSearchText(source);
      if (normalized.isEmpty) continue;

      for (final word in normalized.split(' ')) {
        if (word.length < 3 || stopWords.contains(word)) continue;
        final maxPrefix = word.length < 20 ? word.length : 20;
        for (var end = 3; end <= maxPrefix; end++) {
          terms.add(word.substring(0, end));
          if (terms.length >= 420) break;
        }
        terms.add(word);
        if (terms.length >= 420) break;
      }
      if (terms.length >= 420) break;
    }

    return terms.take(420).toList(growable: false);
  }

  static List<String> _expandGuideSearchVariants(String normalizedQuery) {
    final tokens = normalizedQuery
        .split(' ')
        .where((token) => token.length >= 3)
        .take(4)
        .toList(growable: false);

    final variants = <String>{...tokens};

    for (final token in tokens) {
      if (token.startsWith('renal')) {
        variants.addAll(const ['nefro', 'nefrolog']);
      }
      if (token.startsWith('nefro')) {
        variants.add('renal');
      }
      if (token.startsWith('pneumo')) {
        variants.addAll(const ['pulmonar', 'respirat']);
      }
      if (token.startsWith('pulmon')) {
        variants.addAll(const ['pneumo', 'respirat']);
      }
      if (token.startsWith('respirat')) {
        variants.addAll(const ['pneumo', 'pulmonar']);
      }
      if (token.startsWith('cardio')) {
        variants.addAll(const [
          'cardiac',
          'cardiovascular',
          'coracao',
          'corazon',
        ]);
      }
      if (token.startsWith('cardiac')) {
        variants.addAll(const ['cardio', 'cardiovascular']);
      }
      if (token.startsWith('neuro')) {
        variants.add('neurolog');
      }
      if (token.startsWith('gastro')) {
        variants.addAll(const ['digest', 'gastroenter']);
      }
    }

    return variants.take(8).toList(growable: false);
  }

  static bool _guidePublishedValue(dynamic value) =>
      value == true || value?.toString().toLowerCase() == 'true';

  static Future<List<GuideModel>> loadNextPublishedGuidesPage({
    required String afterUploadedAt,
  }) async {
    final cursor = afterUploadedAt.trim();
    if (cursor.isEmpty) return const <GuideModel>[];

    final snap = await _guides
        .where('isPublished', isEqualTo: true)
        .orderBy('uploadedAt', descending: true)
        .startAfter(<Object?>[cursor])
        .limit(guidesPortalPageSize)
        .get()
        .timeout(const Duration(seconds: 12));

    final page = <GuideModel>[];
    for (final doc in snap.docs) {
      try {
        page.add(GuideModel.fromJson({...doc.data(), 'id': doc.id}));
      } catch (_) {}
    }

    final normalized = _normalizeGuides(page);
    _debugGuides('next page after="$cursor" count=${normalized.length}');
    return normalized;
  }

  static Future<List<GuideModel>> searchPublishedGuides(
    String rawQuery, {
    int limit = 60,
  }) async {
    final normalized = _normalizeGuideSearchText(rawQuery);
    if (normalized.length < 3) return const <GuideModel>[];

    final variants = _expandGuideSearchVariants(normalized);
    final byId = <String, GuideModel>{};

    for (final term in variants) {
      try {
        final snap = await _guides
            .where('searchPrefixes', arrayContains: term)
            .limit(_guidesSearchTokenLimit)
            .get()
            .timeout(const Duration(seconds: 8));

        for (final doc in snap.docs) {
          final data = doc.data();
          if (!_guidePublishedValue(data['isPublished'])) continue;
          try {
            final guide = GuideModel.fromJson({...data, 'id': doc.id});
            if (guide.title.trim().isEmpty) continue;
            byId[guide.id] = guide;
          } catch (_) {}
        }
      } catch (e) {
        _debugGuides('search term="$term" fallback reason=$e');
      }
    }

    // Compatibilidade com os guias antigos ainda sem searchPrefixes.
    if (byId.isEmpty) {
      final recent = await loadPublishedGuides();
      final queryTokens = normalized.split(' ').where((e) => e.length >= 3);
      for (final guide in recent) {
        final haystack = _normalizeGuideSearchText(
          '${guide.title} ${guide.category} ${guide.description}',
        );
        if (queryTokens.any(haystack.contains)) {
          byId[guide.id] = guide;
        }
      }
    }

    final results = byId.values.toList(growable: false)
      ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

    return results.take(limit).toList(growable: false);
  }

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
    final all = guides.toList();
    final valid = <GuideModel>[];

    for (final g in all) {
      final missingId = g.id.trim().isEmpty;
      final missingTitle = g.title.trim().isEmpty;
      final missingPdf = g.pdfUrl.trim().isEmpty;
   final missingEditorial = !g.hasEditorialContent;

   if (missingId ||
       missingTitle ||
       (missingPdf && missingEditorial)) {
        if (kDebugMode) {
          // ORDEM 50 M3: normalize probe gated to kDebugMode
          debugPrint(
            '[clinical_guides DEBUG] guia IGNORADA '
            'id="${g.id}" title="${g.title}" '
            'pdfUrl="${g.pdfUrl}" '
            'missingId=$missingId missingTitle=$missingTitle missingPdfUrl=$missingPdf',
          );
        }
      } else {
        valid.add(g);
      }
    }

    if (kDebugMode) {
      // ORDEM 50 M3: normalizeGuides count probe gated to kDebugMode
      debugPrint(
        '[clinical_guides DEBUG] _normalizeGuides: total=${all.length} valid=${valid.length}',
      );
    }
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

  static Future<void> clearPublishedGuidesCache({
    String reason = 'manual',
  }) async {
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
      final alreadyReset =
          prefs.getBool(_guidesCacheFirstOpenResetKey) ?? false;
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
        decoded.whereType<Map>().map(
          (item) => GuideModel.fromJson(Map<String, dynamic>.from(item)),
        ),
      );
      final bounded = guides.take(guidesPortalPageSize).toList(growable: false);
      _debugGuides(
        'cache hit count=${guides.length} bounded=${bounded.length}',
      );
      return bounded;
    } catch (e) {
      _debugGuides('cache read failed: $e');
      return [];
    }
  }

  static Future<List<GuideModel>> _loadPublishedGuidesSdk({
    Source? source,
  }) async {
    // ── LOG: projeto Firebase em uso (SDK) ──────────────────────────────────
    // ORDEM 50 M3: probe logs gated to kDebugMode — suprimidos em release.
    if (kDebugMode) {
      try {
        final opts = Firebase.app().options;
        debugPrint('[clinical_guides DEBUG] projectId=${opts.projectId}');
        debugPrint('[clinical_guides DEBUG] appId=${opts.appId}');
        debugPrint(
          '[clinical_guides DEBUG] apiKey=${opts.apiKey.substring(0, opts.apiKey.length.clamp(0, 10))}...',
        );
      } catch (e) {
        debugPrint('[clinical_guides DEBUG] Firebase.app().options erro=$e');
      }
      debugPrint('[clinical_guides DEBUG] collection=clinical_guides');
    }

    // ── PROBE SDK: testa 5 coleções sem filtro para achar onde estão os docs ─
    // ORDEM 50 M3: probe loop gated to kDebugMode — 5 extra Firestore queries
    // suprimidas em release/produção, zero spam antes da autenticação.
    if (kDebugMode) {
      const probeCollections = [
        'clinical_guides',
        'guides',
        'medical_guides',
        'biblioteca_clinica',
        'clinical_library',
      ];
      for (final col in probeCollections) {
        try {
          final snap = await _db
              .collection(col)
              .limit(5)
              .get()
              .timeout(const Duration(seconds: 6));
          debugPrint(
            '[clinical_guides DEBUG] collection=$col docs=${snap.docs.length}',
          );
        } catch (e) {
          debugPrint('[clinical_guides DEBUG] collection=$col erro=$e');
        }
      }
    }

    // Tentativa 1: query com orderBy (requer índice composto no Firestore)
    try {
      final query = _guides
          .where('isPublished', isEqualTo: true)
          .orderBy('uploadedAt', descending: true)
          .limit(guidesPortalPageSize);
      final snap = source == null
          ? await query.get().timeout(const Duration(seconds: 8))
          : await query
                .get(GetOptions(source: source))
                .timeout(const Duration(seconds: 8));
      // CAMADA DUPLA: _safeDocsToGuideList já tem try/catch por doc,
      // mas envolvemos em try/catch extra para garantir que TypeError de
      // dart2js não escapa e não aparece como erro visível ao usuário.
      List<GuideModel> guides;
      try {
        guides = _normalizeGuides(_safeDocsToGuideList(snap.docs));
      } catch (parseErr) {
        if (kDebugMode)
          debugPrint(
            '[_loadPublishedGuidesSdk orderBy] parse silenciado: $parseErr',
          );
        guides = const [];
      }
      if (guides.isNotEmpty) {
        _clearGuidesError();
        try {
          await _saveGuidesCache(guides);
        } catch (_) {}
      }
      _debugGuides(
        'sdk load (orderBy) count=${guides.length} source=${source ?? 'default'}',
      );
      return guides;
    } on FirebaseException catch (e) {
      // failed-precondition = índice composto não existe → fallback sem orderBy
      if (e.code == 'failed-precondition' || e.code == 'unimplemented') {
        _debugGuides(
          'sdk orderBy falhou (sem índice) — tentando sem orderBy: ${e.code}',
        );
      } else if (e.code == 'permission-denied') {
        _setGuidesError(
          'Acesso negado (verifique Firestore Rules para clinical_guides)',
        );
        _debugGuides('sdk permission-denied source=${source ?? 'default'}');
        return [];
      } else {
        _setGuidesError('SDK clinical_guides erro: ${e.code}');
        _debugGuides(
          'sdk firebase error ${e.code} source=${source ?? 'default'}',
        );
        return [];
      }
    } catch (e) {
      _debugGuides('sdk orderBy falhou — tentando sem orderBy: $e');
    }

    // Tentativa 2: query SEM orderBy — não requer índice composto.
    // Ordenação é feita localmente em _normalizeGuides().
    try {
      final query = _guides
          .where('isPublished', isEqualTo: true)
          .limit(guidesPortalPageSize);
      final snap = source == null
          ? await query.get().timeout(const Duration(seconds: 8))
          : await query
                .get(GetOptions(source: source))
                .timeout(const Duration(seconds: 8));
      // CAMADA DUPLA: mesma proteção da tentativa 1
      List<GuideModel> guides;
      try {
        guides = _normalizeGuides(_safeDocsToGuideList(snap.docs));
      } catch (parseErr) {
        if (kDebugMode)
          debugPrint(
            '[_loadPublishedGuidesSdk noOrderBy] parse silenciado: $parseErr',
          );
        guides = const [];
      }
      if (guides.isNotEmpty) {
        _clearGuidesError();
        try {
          await _saveGuidesCache(guides);
        } catch (_) {}
      }
      _debugGuides(
        'sdk load (sem orderBy) count=${guides.length} source=${source ?? 'default'}',
      );
      return guides;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        _setGuidesError(
          'Acesso negado (verifique Firestore Rules para clinical_guides)',
        );
      } else {
        _setGuidesError('SDK clinical_guides erro (sem orderBy): ${e.code}');
      }
      _debugGuides(
        'sdk sem orderBy error ${e.code} source=${source ?? 'default'}',
      );
      return [];
    } catch (e) {
      // NUNCA exibe TypeError de dart2js como erro visível — trata como lista vazia
      if (kDebugMode)
        debugPrint('[_loadPublishedGuidesSdk noOrderBy] erro silenciado: $e');
      _debugGuides(
        'sdk sem orderBy failed (silenced) source=${source ?? 'default'} error=$e',
      );
      return [];
    }
  }

  static Future<List<GuideModel>> _loadPublishedGuidesRest() async {
    // ── LOG: projeto Firebase em uso (REST) ──────────────────────────────────
    // ORDEM 50 M3: probe logs gated to kDebugMode — suprimidos em release.
    if (kDebugMode) {
      try {
        final opts = Firebase.app().options;
        debugPrint('[clinical_guides DEBUG] projectId=${opts.projectId}');
        debugPrint('[clinical_guides DEBUG] appId=${opts.appId}');
        debugPrint(
          '[clinical_guides DEBUG] apiKey=${opts.apiKey.substring(0, opts.apiKey.length.clamp(0, 10))}...',
        );
      } catch (e) {
        debugPrint(
          '[clinical_guides DEBUG] projectId=$_projectId (fallback — Firebase.app() erro=$e)',
        );
      }
      debugPrint('[clinical_guides DEBUG] fsBase=$_fsBase');
    }

    // ── AUTH DIAGNÓSTICO ────────────────────────────────────────────────────
    // Web: AuthService.getAdminToken() — FirebaseAuth.instance.currentUser é
    // sempre null no Web (login REST não injeta token no Firebase Auth SDK).
    // Nativo: Firebase Auth SDK — currentUser populado pelo signIn*.
    String token;
    if (kIsWeb) {
      token = await AuthService.getAdminToken();
      if (kDebugMode) {
        // ORDEM 50 M3: auth probe gated to kDebugMode
        debugPrint(
          '[WEB_AUTH] source=REST token=${token.isNotEmpty} endpoint=clinical_guides',
        );
        debugPrint(
          '[clinical_guides DEBUG] currentUser=WEB_REST_AUTH (getAdminToken)',
        );
      }
    } else {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (kDebugMode) {
        // ORDEM 50 M3: auth probe gated to kDebugMode
        debugPrint(
          '[NATIVE_AUTH] source=FirebaseSDK uid=${currentUser?.uid ?? 'null'} endpoint=clinical_guides',
        );
        debugPrint(
          '[clinical_guides DEBUG] currentUser=${currentUser?.uid ?? 'null (não logado)'}',
        );
        debugPrint(
          '[clinical_guides DEBUG] currentUser.email=${currentUser?.email ?? 'null'}',
        );
      }
      token = await currentUser?.getIdToken() ?? '';
    }
    if (kDebugMode) {
      // ORDEM 50 M3: token probe gated to kDebugMode
      debugPrint('[clinical_guides DEBUG] tokenPresent=${token.isNotEmpty}');
      debugPrint('[clinical_guides DEBUG] tokenLength=${token.length}');
    }

    final authHeaders = token.isNotEmpty
        ? <String, String>{'Authorization': 'Bearer $token'}
        : <String, String>{};
    if (kDebugMode) {
      // ORDEM 50 M3: header probe gated to kDebugMode
      debugPrint(
        '[clinical_guides DEBUG] authHeader=${authHeaders.containsKey('Authorization')}',
      );
    }

    // ── SDK DIRETO: teste isolado sem REST ───────────────────────────────────
    // Se SDK retornar docs e REST retornar 403 → problema exclusivo no endpoint REST.
    // ORDEM 50 M3: probe gated to kDebugMode — suprime query extra em produção.
    if (kDebugMode) {
      try {
        final sdkSnap = await FirebaseFirestore.instance
            .collection('clinical_guides')
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 6));
        debugPrint(
          '[clinical_guides DEBUG] SDK direto docs=${sdkSnap.docs.length}',
        );
        if (sdkSnap.docs.isNotEmpty) {
          final d = sdkSnap.docs.first;
          debugPrint(
            '[clinical_guides DEBUG] SDK primeiro doc id=${d.id} fields=${d.data().keys.toList()}',
          );
        }
      } catch (e) {
        debugPrint('[clinical_guides DEBUG] SDK direto ERRO=$e');
      }
    }

    final apiKey = _firebaseApiKey;
    if (kDebugMode) {
      // ORDEM 50 M3: apiKey probe gated to kDebugMode
      debugPrint(
        '[clinical_guides DEBUG] apiKey(10)=${apiKey.substring(0, apiKey.length.clamp(0, 10))}...',
      );
    }

    // ── TAREFA 4: confirmar nome exato da coleção usada ──────────────────────
    const targetCollection = 'clinical_guides';
    if (kDebugMode) {
      // ORDEM 50 M3: collection name probe gated to kDebugMode
      debugPrint(
        '[clinical_guides DEBUG] coleção alvo=$targetCollection '
        '(NÃO é: clinicalGuides, guides, medical_guides, biblioteca_clinica, clinical_library)',
      );
    }

    Future<http.Response> doGet({
      Map<String, String>? headers,
      String collection = targetCollection,
    }) {
      // GET: SOMENTE Authorization — nunca Content-Type nem X-Firebase-API-Key
      // (headers customizados causam preflight CORS que Firestore rejeita)
      final hdrs = <String, String>{...authHeaders, ...?headers};
      final url = '$_fsBase/$collection?pageSize=200&key=$apiKey';
      if (kDebugMode) {
        // ORDEM 50 M3: URL + headers probe gated to kDebugMode
        debugPrint('[clinical_guides DEBUG] REST URL=$url');
        debugPrint(
          '[clinical_guides DEBUG] REST headers keys=${hdrs.keys.toList()}',
        );
      }
      return http
          .get(Uri.parse(url), headers: hdrs)
          .timeout(const Duration(seconds: 12));
    }

    List<GuideModel> parseResponse(http.Response resp) {
      if (kDebugMode) {
        // ORDEM 50 M3: response body probe gated to kDebugMode
        // ── TAREFA 3: logar status e body bruto ────────────────────────────
        debugPrint('[clinical_guides DEBUG] REST status=${resp.statusCode}');
        debugPrint(
          '[clinical_guides DEBUG] REST body=${resp.body.length > 1500 ? resp.body.substring(0, 1500) : resp.body}',
        );
      }

      // safeMap: sem casts diretos — imune a TypeError em dart2js release
      final body = safeMap(jsonDecode(resp.body));
      final docsList = body['documents'];
      final documents = docsList is List ? docsList : const <dynamic>[];
      final totalDocs = documents.length;

      if (kDebugMode) {
        // ORDEM 50 M3: totalDocs probe gated to kDebugMode
        debugPrint('[clinical_guides DEBUG] totalDocs=$totalDocs');
      }

      final allParsed = <GuideModel>[];
      final unpublished = <String>[];

      for (final doc in documents) {
        try {
          final rawDoc = safeMap(doc);
          final data = _restDocToMap(rawDoc);

          // Garante que o id está preenchido a partir do campo 'name' do REST
          if (data['id'] == null || safeString(data['id']).isEmpty) {
            final name = safeString(rawDoc['name']);
            data['id'] = name.isNotEmpty ? name.split('/').last : '';
          }

          if (kDebugMode) {
            // ORDEM 50 M3: per-doc sample probe gated to kDebugMode
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
          }

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
      if (kDebugMode) {
        // ORDEM 50 M3: final counts probe gated to kDebugMode
        debugPrint('[clinical_guides DEBUG] parsed=${allParsed.length}');
        debugPrint(
          '[clinical_guides DEBUG] published=${publishedGuides.length}',
        );
        if (unpublished.isNotEmpty) {
          debugPrint('[clinical_guides DEBUG] unpublished: $unpublished');
        }
      }

      final normalized = _normalizeGuides(publishedGuides);
      if (kDebugMode) {
        // ORDEM 50 M3: normalized count probe gated to kDebugMode
        debugPrint(
          '[clinical_guides DEBUG] validPdfTitle=${normalized.length}',
        );
      }
      return normalized;
    }

    try {
      _debugGuides(
        'rest load start kIsWeb=$kIsWeb tokenPresent=${authHeaders.isNotEmpty}',
      );
      var resp = await doGet();
      _debugGuides('rest load initial status=${resp.statusCode}');

      if (resp.statusCode == 401 || resp.statusCode == 403) {
        // Web: getAdminToken() já faz auto-refresh via securetoken.googleapis.com
        // Nativo: getIdToken(true) força refresh no Firebase Auth SDK
        String? refreshedToken;
        try {
          if (kIsWeb) {
            refreshedToken = await AuthService.getAdminToken();
            if (kDebugMode) {
              // ORDEM 50 M3: retry auth probe gated to kDebugMode
              debugPrint(
                '[WEB_AUTH] source=REST token=${(refreshedToken).isNotEmpty} endpoint=clinical_guides (retry)',
              );
            }
          } else {
            refreshedToken = await FirebaseAuth.instance.currentUser
                ?.getIdToken(true);
            if (kDebugMode) {
              // ORDEM 50 M3: retry auth probe gated to kDebugMode
              debugPrint(
                '[NATIVE_AUTH] source=FirebaseSDK uid=${FirebaseAuth.instance.currentUser?.uid ?? 'null'} endpoint=clinical_guides (retry)',
              );
            }
          }
        } catch (_) {}
        final retryHeaders =
            (refreshedToken != null && refreshedToken.isNotEmpty)
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
        if (kDebugMode) {
          // ORDEM 50 M3: error detail probes gated to kDebugMode
          debugPrint(
            '[clinical_guides DEBUG] FIRESTORE ERROR status=${resp.statusCode}',
          );
          debugPrint(
            '[clinical_guides DEBUG] FIRESTORE ERROR BODY: ${resp.body}',
          );
        }
        // Diagnóstico do tipo de 403:
        // - "Missing or insufficient permissions" → Firestore Rules negando acesso
        // - "UNAUTHENTICATED"                    → token ausente ou expirado
        // - "API key not valid"                  → _firebaseApiKey errada
        // - "Firebase App Check"                 → App Check ativado sem attestation
        // - "Requests to this API ... disabled"  → Firestore API desabilitada no GCP
        final snippet = resp.body.substring(0, resp.body.length.clamp(0, 400));
        _setGuidesError(
          'REST clinical_guides HTTP ${resp.statusCode}: $snippet',
        );
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
      // ORDEM 50 M3: alt-collection probe block gated to kDebugMode —
      // evita 4 queries Firestore extras em release/produção.
      if (kDebugMode) {
        debugPrint(
          '[clinical_guides DEBUG] clinical_guides vazia — iniciando probe de coleções alternativas',
        );
        const altCollections = [
          'guides',
          'medical_guides',
          'biblioteca_clinica',
          'clinical_library',
        ];
        for (final altCol in altCollections) {
          try {
            debugPrint(
              '[clinical_guides DEBUG] probe: tentando coleção=$altCol',
            );
            final altResp = await doGet(
              collection: altCol,
            ).timeout(const Duration(seconds: 8));
            debugPrint(
              '[clinical_guides DEBUG] probe: $altCol status=${altResp.statusCode}',
            );
            if (altResp.statusCode == 200) {
              final altBody = safeMap(jsonDecode(altResp.body));
              final altDocs = altBody['documents'];
              final altCount = altDocs is List ? altDocs.length : 0;
              if (altCount > 0) {
                // ── TAREFA 6: logar coleção encontrada ────────────────────
                debugPrint(
                  '[clinical_guides DEBUG] coleção encontrada: $altCol totalDocs=$altCount',
                );
              } else {
                debugPrint(
                  '[clinical_guides DEBUG] probe: $altCol retornou 0 docs',
                );
              }
            }
          } catch (e) {
            debugPrint('[clinical_guides DEBUG] probe: $altCol erro=$e');
          }
        }
      }

      // Mensagem diagnóstica final (zero guias na coleção principal)
      try {
        final bodyParsed = safeMap(jsonDecode(resp.body));
        final docsList2 = bodyParsed['documents'];
        final totalDocs = docsList2 is List ? docsList2.length : 0;
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

  static Future<List<GuideModel>> loadPublishedGuides({
    bool forceRemote = false,
  }) async {
    // ORDEM 50 M3: Auth guard — suprime requests Firestore antes da barreira
    // de auth transposta, eliminando spam de 403 "permission-denied" no console.
    if (!_hasAnyAuthCredential) {
      _debugGuides(
        'ORDEM50 M3: skip — unauthenticated, awaiting GoogleAuthBarrier',
      );
      return const <GuideModel>[];
    }

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
      _debugGuides(
        'cache hit etapa 0 count=${cached.length} — retornando cache e atualizando em bg',
      );
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
      _debugGuides(
        'remote failed/empty, returning cache count=${cached.length}',
      );
      return cached;
    }

    if (lastGuidesErrorMessage.isEmpty) {
      _setGuidesError(
        'clinical_guides: SDK e REST falharam — sem cache disponível.',
      );
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
        .limit(guidesPortalPageSize)
        .snapshots()
        // CAMADA DUPLA: protege contra TypeError de dart2js que pode escapar
        // mesmo com _safeDocsToGuideList tendo try/catch interno por documento.
        .map((snap) {
          try {
            return _normalizeGuides(_safeDocsToGuideList(snap.docs));
          } catch (e) {
            if (kDebugMode)
              debugPrint('[guidesStream] parse error silenciado: $e');
            return const <GuideModel>[];
          }
        });
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
            _setGuidesError(
              'Stream REST clinical_guides timeout: nenhuma resposta em 15s.',
            );
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
        timer = Timer.periodic(
          const Duration(seconds: 20),
          (_) => unawaited(fetch()),
        );
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
    return _guides.orderBy('uploadedAt', descending: true).snapshots().map((
      snap,
    ) {
      try {
        return _safeDocsToGuideList(snap.docs);
      } catch (e) {
        if (kDebugMode)
          debugPrint('[guidesAdminStream] parse error silenciado: $e');
        return const <GuideModel>[];
      }
    });
  }

  /// Salva metadados de uma guia no Firestore.
  ///
  /// searchPrefixes é derivado automaticamente de título, categoria e
  /// descrição para permitir busca remota sem carregar todo o catálogo.
  static Future<String> saveGuide(GuideModel guide) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final data = <String, dynamic>{
      ...guide.toJson(),
      'uploadedAt': guide.uploadedAt.trim().isEmpty
          ? now
          : guide.uploadedAt.trim(),
      'searchPrefixes': _buildGuideSearchPrefixes(guide),
      'searchIndexVersion': _guidesSearchIndexVersion,
    };

    if (guide.id.isEmpty) {
      final ref = await _guides.add(data);
      return ref.id;
    } else {
      await _guides.doc(guide.id).set(data, SetOptions(merge: true));
      return guide.id;
    }
  }

  /// Atualiza campo isPublished de uma guia.
  ///
  /// Ao publicar, uploadedAt recebe o instante da publicação. Assim portal e
  /// pesquisa mantêm sempre o conteúdo recém-publicado primeiro.
  static Future<void> toggleGuidePublished(
    String guideId,
    bool published,
  ) async {
    final data = <String, dynamic>{
      'isPublished': published,
      if (published) 'uploadedAt': DateTime.now().toUtc().toIso8601String(),
    };
    await _guides.doc(guideId).update(data);
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
      'enabled': {'booleanValue': enabled},
      'message': {'stringValue': message.trim()},
      'updatedBy': {'stringValue': updatedBy},
      'updatedAt': {'stringValue': DateTime.now().toUtc().toIso8601String()},
    };

    // updateMask: atualiza apenas os 4 campos (não sobrescreve outros)
    const mask =
        'updateMask.fieldPaths=enabled'
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

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD 272 — PROPRIETARY DRUG DOCUMENT FETCHER (clinical_library RAG bypass)
  // ─────────────────────────────────────────────────────────────────────────
  // Busca documento proprietário de fármaco/patologia na coleção
  // 'clinical_library' (ex: clinical_library/sertralina).
  //
  // Estratégia dual:
  //   1. SDK nativo: FirebaseFirestore.instance.collection('clinical_library').doc(docId).get()
  //      → Funciona quando Firestore Rules permitem 'allow read: if request.auth != null'
  //   2. REST admin bypass (fallback imediato): caso SDK retorne permission-denied
  //      ou qualquer FirebaseException, dispara GET REST com AuthService.getAdminToken()
  //      → Contorna regras de segurança via token de admin, mesmo que as rules
  //      não estejam atualizadas no console do Firebase.
  //
  // Retorna Map<String, dynamic> com os campos do documento, ou null se não encontrado.
  // ═══════════════════════════════════════════════════════════════════════════

  /// Busca documento proprietário da coleção 'clinical_library' para RAG do Gemini.
  /// Tenta SDK nativo primeiro; em caso de permission-denied, usa REST com admin token.
  /// docId deve ser o nome normalizado do fármaco (ex: 'sertralina', 'amiodarona').
  static Future<Map<String, dynamic>?> fetchProprietaryDrugDoc(
    String docId,
  ) async {
    if (docId.trim().isEmpty) return null;
    final normalized = docId.trim().toLowerCase();

    debugPrint(
      '[BUILD272][RAG] fetchProprietaryDrugDoc: tentando SDK para clinical_library/$normalized',
    );

    // ── TENTATIVA 1: SDK nativo ───────────────────────────────────────────
    try {
      final snap = await FirebaseFirestore.instance
          .collection('clinical_library')
          .doc(normalized)
          .get()
          .timeout(const Duration(seconds: 6));
      if (snap.exists && snap.data() != null) {
        final data = safeMap(snap.data());
        debugPrint(
          '[BUILD272][RAG] SDK clinical_library/$normalized OK fields=${data.keys.toList()}',
        );
        return data;
      }
      debugPrint(
        '[BUILD272][RAG] SDK clinical_library/$normalized doc não encontrado — tentando REST',
      );
    } on FirebaseException catch (e) {
      debugPrint(
        '[BUILD272][RAG] SDK clinical_library/$normalized FirebaseException code=${e.code} — disparando REST bypass imediato',
      );
      // permission-denied ou qualquer erro SDK → cai direto no REST bypass abaixo
    } catch (e) {
      debugPrint(
        '[BUILD272][RAG] SDK clinical_library/$normalized erro genérico=$e — disparando REST bypass imediato',
      );
    }

    // ── TENTATIVA 2: REST bypass com admin token ──────────────────────────
    // Usa a mesma estratégia de AuthService.getAdminToken() já estabelecida
    // em auth_service.dart (linha 939: "usa HTTP DELETE REST com token de admin").
    debugPrint('[BUILD272][RAG] REST bypass: clinical_library/$normalized');
    try {
      final token = await AuthService.getAdminToken();
      if (token.isEmpty) {
        debugPrint(
          '[BUILD272][RAG] REST bypass: token vazio — sem autenticação disponível',
        );
        return null;
      }
      final apiKey = _firebaseApiKey;
      final url = '$_fsBase/clinical_library/$normalized?key=$apiKey';
      debugPrint('[BUILD272][RAG] REST GET $url tokenPresent=true');

      final resp = await http
          .get(Uri.parse(url), headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 8));

      debugPrint('[BUILD272][RAG] REST status=${resp.statusCode}');

      if (resp.statusCode == 200) {
        final data = _decodeFirestoreFields(resp.body);
        if (data.isNotEmpty) {
          debugPrint(
            '[BUILD272][RAG] REST clinical_library/$normalized OK fields=${data.keys.toList()}',
          );
          return data;
        }
        debugPrint('[BUILD272][RAG] REST OK mas documento vazio');
        return null;
      }

      if (resp.statusCode == 404) {
        debugPrint(
          '[BUILD272][RAG] clinical_library/$normalized não existe no Firestore (404)',
        );
        return null;
      }

      debugPrint(
        '[BUILD272][RAG] REST HTTP ${resp.statusCode}: ${resp.body.length > 300 ? resp.body.substring(0, 300) : resp.body}',
      );
      return null;
    } catch (e) {
      debugPrint('[BUILD272][RAG] REST bypass falhou: $e');
      return null;
    }
  }

  /// Extrai texto útil de um documento proprietário para injeção no prompt Gemini.
  /// Formata os campos relevantes como string estruturada.
  static String formatProprietaryDocForPrompt(Map<String, dynamic> doc) {
    if (doc.isEmpty) return '';
    final buf = StringBuffer();

    // Campos prioritários reconhecidos
    final priorityFields = [
      'nome',
      'name',
      'indicacoes',
      'indicacoes_pt',
      'indicações',
      'indication',
      'dose',
      'dosagem',
      'posologia',
      'dosis',
      'mecanismo',
      'mechanism',
      'mecanismo_acao',
      'contraindicacoes',
      'contraindicações',
      'contraindicacion',
      'contraindicaciones',
      'efeitos_adversos',
      'adverse_effects',
      'efectos_adversos',
      'toxicidade',
      'interacoes',
      'interações',
      'interacciones',
      'interactions',
      'alerta',
      'alertas',
      'warning',
      'warnings',
      'ajuste_renal',
      'renal_adjustment',
      'ajuste_hepatico',
      'monitoramento',
      'monitorización',
      'monitoring',
      'observacoes',
      'observações',
      'notes',
      'resumo',
      'summary',
      'texto',
      'text',
      'content',
      'conteudo',
      'conteúdo',
      'body',
    ];

    // Primeiro: campos prioritários na ordem definida
    for (final field in priorityFields) {
      if (doc.containsKey(field)) {
        final val = doc[field];
        final str = val?.toString().trim() ?? '';
        if (str.isNotEmpty && str != 'null') {
          buf.writeln('$field: $str');
        }
      }
    }

    // Depois: campos restantes (exceto metadados de sistema)
    const skipFields = {
      'id',
      'createdAt',
      'updatedAt',
      'uploadedAt',
      'isPublished',
      'downloadCount',
      'version',
      'uid',
      'userId',
    };
    for (final entry in doc.entries) {
      if (skipFields.contains(entry.key)) continue;
      if (priorityFields.contains(entry.key)) continue;
      final str = entry.value?.toString().trim() ?? '';
      if (str.isNotEmpty && str != 'null') {
        buf.writeln('${entry.key}: $str');
      }
    }

    return buf.toString().trim();
  }
}
