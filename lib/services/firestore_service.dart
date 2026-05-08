// firestore_service.dart — dados por usuário no Firestore
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/clinical_case_model.dart';

class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

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
  }) async {
    final data = <String, dynamic>{};
    if (lang != null) data['lang'] = lang;
    if (darkMode != null) data['darkMode'] = darkMode;
    if (profession != null) data['profession'] = profession;
    if (institution != null) data['institution'] = institution;
    if (data.isEmpty) return;
    try {
      await _userDoc(uid).update(data);
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
}
