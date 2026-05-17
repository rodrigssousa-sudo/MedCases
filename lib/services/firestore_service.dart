// firestore_service.dart — dados por usuário no Firestore
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../models/clinical_case_model.dart';
import '../models/clinical_history_model.dart';
import '../models/guide_model.dart';
import 'auth_service.dart';

class FirestoreService {
  // Getter lazy — só acessa Firestore APÓS Firebase.initializeApp() completar
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static const _projectId = 'medcases-pro';
  static const _fsBase    = 'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents';

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

  // ── Chave OpenAI do APP (compartilhada) ──────────────────────────────────
  /// Carrega a chave OpenAI global do app, salva pelo administrador.
  /// Armazenada em app_config/global campo 'openAiKey'.
  /// Todos os usuários aprovados usam essa chave — nenhuma configuração manual.
  static Future<String> loadAppAiKey() async {
    try {
      final doc = await _db.collection('app_config').doc('global').get();
      debugPrint('[FirestoreService] loadAppAiKey doc.exists=${doc.exists} fields=${doc.data()?.keys.toList()}');
      if (!doc.exists) return '';
      return (doc.data()?['openAiKey'] as String?) ?? '';
    } catch (e) {
      debugPrint('[FirestoreService] loadAppAiKey ERRO: $e');
      return '';
    }
  }

  // ── Chave Gemini API do APP (compartilhada) ───────────────────────────────
  /// Carrega a Gemini API Key global do app, salva pelo administrador.
  /// Armazenada em app_config/global campo 'apiKey'.
  /// Usada diretamente nas chamadas à API do Gemini (sem OAuth token).
  ///
  /// Web: usa REST HTTP puro (firestore.googleapis.com) para bypassar o
  /// flutter_service_worker.js que intercepta e rejeita fetch do SDK Firestore.
  /// Nativo: SDK Firestore direto (sem restrições).
  static Future<String> loadGeminiApiKey() async {
    if (kIsWeb) return _loadGeminiApiKeyRest();
    try {
      final doc = await _db.collection('app_config').doc('global').get();
      debugPrint('[FirestoreService] loadGeminiApiKey (SDK) doc.exists=${doc.exists} fields=${doc.data()?.keys.toList()}');
      if (!doc.exists) return '';
      final data = doc.data()!;
      // 'apiKey' é o nome real no banco; 'geminiApiKey' mantido como fallback legado
      final key = (data['apiKey'] as String?)?.trim() ??
                  (data['geminiApiKey'] as String?)?.trim() ?? '';
      debugPrint('[FirestoreService] loadGeminiApiKey (SDK) key.isNotEmpty=${key.isNotEmpty}');
      return key;
    } catch (e) {
      debugPrint('[FirestoreService] loadGeminiApiKey (SDK) ERRO: $e');
      return '';
    }
  }

  /// Lê app_config/global.apiKey via Firestore REST API.
  /// Usa idToken do usuário autenticado para authorização (regras de segurança).
  /// O token é obtido via securetoken.googleapis.com — domínio externo,
  /// não interceptado pelo service worker de medcasespro.com.
  static Future<String> _loadGeminiApiKeyRest() async {
    try {
      final token = await AuthService.getAdminToken();
      debugPrint('[FirestoreService] REST token.isNotEmpty=${token.isNotEmpty}');
      final headers = token.isNotEmpty
          ? {'Authorization': 'Bearer $token'}
          : <String, String>{};

      final url = '$_fsBase/app_config/global';
      debugPrint('[FirestoreService] REST GET $url');
      final resp = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(const Duration(seconds: 8));

      debugPrint('[FirestoreService] REST status=${resp.statusCode} body=${resp.body.substring(0, resp.body.length.clamp(0, 400))}');

      if (resp.statusCode != 200) {
        debugPrint('[FirestoreService] REST ERRO ${resp.statusCode}: ${resp.body}');
        return '';
      }

      final body   = jsonDecode(resp.body) as Map<String, dynamic>;
      final fields = body['fields'] as Map<String, dynamic>? ?? {};
      debugPrint('[FirestoreService] REST campos disponíveis: ${fields.keys.toList()}');

      // Tenta 'apiKey' (nome real), depois 'geminiApiKey' (legado)
      final apiKeyField    = fields['apiKey']      as Map<String, dynamic>?;
      final geminiKeyField = fields['geminiApiKey'] as Map<String, dynamic>?;
      final key = (apiKeyField?['stringValue'] as String?)?.trim() ??
                  (geminiKeyField?['stringValue'] as String?)?.trim() ?? '';
      debugPrint('[FirestoreService] REST key.isNotEmpty=${key.isNotEmpty}');
      return key;
    } catch (e) {
      debugPrint('[FirestoreService] _loadGeminiApiKeyRest ERRO: $e');
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
      return (doc.data()?['openAiKey'] as String?) ?? '';
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
      final list = doc.data()?['ids'] as List<dynamic>?;
      return list?.map((e) => e.toString()).toSet() ?? {};
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
      final list = doc.data()?['ids'] as List<dynamic>?;
      return list?.map((e) => e.toString()).toSet() ?? {};
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
      final list = doc.data()?['ids'] as List<dynamic>?;
      return list?.map((e) => e.toString()).toSet() ?? {};
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveFavPrescriptions(String uid, Set<String> ids) async {
    try {
      await _userFavs(uid).doc('prescriptions').set({'ids': ids.toList()});
    } catch (_) {}
  }

  // ── Favoritos de casos clínicos ───────────────────────────────────────────
  static Future<Set<String>> loadFavCases(String uid) async {
    try {
      final doc = await _userFavs(uid).doc('fav_cases').get();
      if (!doc.exists) return {};
      final list = doc.data()?['ids'] as List<dynamic>?;
      return list?.map((e) => e.toString()).toSet() ?? {};
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
          .map((d) => ClinicalCaseModel.fromJson(d.data()))
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
          .map((d) => ClinicalCaseModel.fromJson(d.data()))
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

  // ── Helpers REST para public_histories ───────────────────────────────────

  /// Converte um documento Firestore REST em Map<String, dynamic> Dart.
  static Map<String, dynamic> _restDocToMap(Map<String, dynamic> doc) {
    final fields = doc['fields'] as Map<String, dynamic>? ?? {};
    return _decodeFields(fields);
  }

  static Map<String, dynamic> _decodeFields(Map<String, dynamic> fields) {
    final result = <String, dynamic>{};
    fields.forEach((key, val) {
      result[key] = _decodeValue(val as Map<String, dynamic>);
    });
    return result;
  }

  static dynamic _decodeValue(Map<String, dynamic> v) {
    if (v.containsKey('stringValue'))  return v['stringValue'];
    if (v.containsKey('booleanValue')) return v['booleanValue'];
    if (v.containsKey('integerValue')) return int.tryParse(v['integerValue'].toString()) ?? 0;
    if (v.containsKey('doubleValue'))  return (v['doubleValue'] as num).toDouble();
    if (v.containsKey('nullValue'))    return null;
    if (v.containsKey('mapValue')) {
      final f = v['mapValue']['fields'] as Map<String, dynamic>? ?? {};
      return _decodeFields(f);
    }
    if (v.containsKey('arrayValue')) {
      final vals = v['arrayValue']['values'] as List<dynamic>? ?? [];
      return vals.map((e) => _decodeValue(e as Map<String, dynamic>)).toList();
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
          .map((d) => ClinicalHistoryModel.fromJson(d.data()))
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

  static Future<List<ClinicalHistoryModel>> loadPublicHistories() async {
    // Web: usa REST puro (HTTP GET sem auth).
    // O SDK Firestore usa WebSocket que falha com CORS em domínios não
    // cadastrados no Firebase Console — a REST API não tem essa limitação.
    // Nativo (Android/iOS): SDK direto, sem restrições CORS.
    if (kIsWeb) {
      return _loadPublicHistoriesRest();
    }
    // Nativo — SDK funciona normalmente
    try {
      final snap = await _publicHistories
          .limit(100)
          .get(const GetOptions(source: Source.server));
      final list = snap.docs
          .map((d) => ClinicalHistoryModel.fromJson(d.data()))
          .toList();
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return list.take(50).toList();
    } catch (_) {
      final snap = await _publicHistories.limit(100).get();
      final list = snap.docs
          .map((d) => ClinicalHistoryModel.fromJson(d.data()))
          .toList();
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return list.take(50).toList();
    }
  }

  /// Leitura pública via Firestore REST API — sem token, sem SDK, sem CORS.
  /// Funciona em qualquer domínio web porque é HTTP GET simples.
  static Future<List<ClinicalHistoryModel>> _loadPublicHistoriesRest() async {
    const url = '$_fsBase/public_histories?pageSize=100';
    final resp = await http.get(
      Uri.parse(url),
    ).timeout(const Duration(seconds: 15));

    if (resp.statusCode != 200) {
      throw Exception('REST public_histories: HTTP ${resp.statusCode} — ${resp.body}');
    }

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final documents = body['documents'] as List<dynamic>? ?? [];

    final list = documents
        .map((doc) => _restDocToMap(doc as Map<String, dynamic>))
        .map((data) => ClinicalHistoryModel.fromJson(data))
        .toList();

    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list.take(50).toList();
  }

  static Stream<List<ClinicalHistoryModel>> historiesStream(String uid) {
    return _userHistories(uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ClinicalHistoryModel.fromJson(d.data()))
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

        final resp = await http.get(
          Uri.parse('$_fsBase/app_config/maintenance'),
          headers: {'Authorization': 'Bearer $token'},
        );

        if (resp.statusCode == 404) {
          if (!ctrl.isClosed) ctrl.add({'enabled': false});
          return;
        }

        if (resp.statusCode != 200) return;

        final body   = jsonDecode(resp.body) as Map<String, dynamic>;
        final fields = body['fields'] as Map<String, dynamic>? ?? {};
        final data   = <String, dynamic>{};

        fields.forEach((key, value) {
          final v = value as Map<String, dynamic>;
          if (v.containsKey('booleanValue')) {
            data[key] = v['booleanValue'];
          } else if (v.containsKey('stringValue')) {
            data[key] = v['stringValue'];
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
    if (kIsWeb) return _loadAppUpdateRest();
    try {
      final doc = await _db.collection('app_updates').doc('current').get();
      if (!doc.exists) return {};
      return doc.data() ?? {};
    } catch (_) { return {}; }
  }

  static Future<Map<String, dynamic>> _loadAppUpdateRest() async {
    try {
      final token = await AuthService.getAdminToken();
      final headers = token.isNotEmpty
          ? {'Authorization': 'Bearer $token'}
          : <String, String>{};
      final resp = await http.get(
        Uri.parse('$_fsBase/app_updates/current'),
        headers: headers,
      );
      if (resp.statusCode != 200) return {};
      final body   = jsonDecode(resp.body) as Map<String, dynamic>;
      final fields = body['fields'] as Map<String, dynamic>? ?? {};
      final data   = <String, dynamic>{};
      fields.forEach((k, v) {
        final val = v as Map<String, dynamic>;
        if (val.containsKey('stringValue'))  data[k] = val['stringValue'];
        if (val.containsKey('booleanValue')) data[k] = val['booleanValue'];
        if (val.containsKey('arrayValue')) {
          final arr = (val['arrayValue']['values'] as List<dynamic>? ?? []);
          data[k] = arr.map((e) => (e as Map)['stringValue'] as String? ?? '').toList();
        }
      });
      return data;
    } catch (_) { return {}; }
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
        final d = doc.data()!;
        return {
          'serviceId':  (d['serviceId']  as String?) ?? '',
          'templateId': (d['templateId'] as String?) ?? '',
          'publicKey':  (d['publicKey']  as String?) ?? '',
        };
      }
    } catch (_) {}
    // Fallback para caminho legado config/emailjs (dados antigos já salvos)
    try {
      final doc = await _db.collection('config').doc('emailjs').get();
      if (!doc.exists) return {};
      final d = doc.data()!;
      return {
        'serviceId':  (d['serviceId']  as String?) ?? '',
        'templateId': (d['templateId'] as String?) ?? '',
        'publicKey':  (d['publicKey']  as String?) ?? '',
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
      final body   = jsonDecode(resp.body) as Map<String, dynamic>;
      final fields = body['fields'] as Map<String, dynamic>? ?? {};
      return {
        'serviceId':  (fields['serviceId']?['stringValue']  as String?) ?? '',
        'templateId': (fields['templateId']?['stringValue'] as String?) ?? '',
        'publicKey':  (fields['publicKey']?['stringValue']  as String?) ?? '',
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
        .map((snap) => snap.docs.map((d) {
              final data = Map<String, dynamic>.from(d.data());
              data['id'] = d.id;
              return data;
            }).toList());
  }

  /// Deleta uma anotação.
  static Future<void> deleteNote({required String uid, required String noteId}) async {
    await _userNotes(uid).doc(noteId).delete();
  }

  // ── BIBLIOTECA CLÍNICA — Guias / PDFs ────────────────────────────────────

  static CollectionReference<Map<String, dynamic>> get _guides =>
      _db.collection('clinical_guides');

  /// Stream de todas as guias publicadas (ordenadas por data).
  static Stream<List<GuideModel>> guidesStream() {
    return _guides
        .where('isPublished', isEqualTo: true)
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => GuideModel.fromJson({...d.data(), 'id': d.id}))
            .toList());
  }

  /// Stream de TODAS as guias para o admin (incluindo não publicadas).
  static Stream<List<GuideModel>> guidesAdminStream() {
    return _guides
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => GuideModel.fromJson({...d.data(), 'id': d.id}))
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
