import 'medcases_feature_authorization.dart';
import 'canonical_catalog_cipher_native.dart'
    if (dart.library.html) 'canonical_catalog_cipher_web.dart';
import 'canonical_catalog_cipher.dart';
import 'canonical_secure_cache.dart';
import 'canonical_free_discovery.dart';
import 'free_drug_catalog.dart';
import '../models/drug_model.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'clinical_content/clinical_content_contract.dart';
import 'entitlement_service.dart';

/// A transport/cache projection. All authored data comes from the existing
/// canonical resolver. Every read rechecks the sovereign access policy.
class CanonicalDrugLibrary {
  CanonicalDrugLibrary(
      {required this.entitlement,
      required this.loadIndex,
      required this.loadDocument,
      required this.preferences,
      CanonicalCatalogCipher? cipher})
      : cipher = cipher ?? createCatalogCipher();
  static CanonicalDrugLibrary? _runtime;
  static CanonicalDrugLibrary? get currentRuntime => _runtime;
  factory CanonicalDrugLibrary.runtime(
          {required EntitlementService entitlement,
          required Future<Map<String, Map<String, Object?>>> Function()
              loadIndex,
          required Future<Map<String, Object?>?> Function(String) loadDocument,
          required SharedPreferences preferences}) =>
      _runtime ??= CanonicalDrugLibrary(
          entitlement: entitlement,
          loadIndex: loadIndex,
          loadDocument: loadDocument,
          preferences: preferences);
  final EntitlementService entitlement;
  final Future<Map<String, Map<String, Object?>>> Function() loadIndex;
  final Future<Map<String, Object?>?> Function(String) loadDocument;
  final SharedPreferences preferences;
  final CanonicalCatalogCipher cipher;
  String? _documentsOwner;
  late final _secure = CanonicalSecureCache(
      preferences: preferences,
      cipher: cipher,
      uid: () => entitlement.current.resolvedUid,
      authorized: () => entitlement.isPremium);
  static const _publicKey = 'canonical.drug.public.v2';
  static const _key = 'canonical.drug.library.v1';
  Map<String, Map<String, Object?>> _index = Map.from(canonicalFreeDiscovery);
  Map<String, Map<String, Object?>> _documents = {};
  int _generation = 0;
  Future<void> _writes = Future.value();
  Map<String, Map<String, Object?>> get index => Map.unmodifiable(_index);
  List<DrugModel> discovery(String language) => [
        for (final entry in _index.entries)
          DrugModel(
            id: entry.key,
            name: entry.value['name'] is Map
                ? ((entry.value['name'] as Map)[language] ?? entry.key)
                    .toString()
                : (entry.value['name'] ?? entry.key).toString(),
            group: '',
            className: const {},
            category: const {},
            route: '',
            doseType: '',
          ),
      ];
  bool allowed(String id) =>
      _index.containsKey(id) &&
      MedCasesFeatureAuthorization(entitlement).allows(FeatureTarget.drug(id));

  Future<void> restore() async {
    _documents.removeWhere((id, _) => !freeDrugCanonicalIds.contains(id));
    try {
      final raw =
          preferences.getString(_publicKey) ?? preferences.getString(_key);
      if (raw != null) {
        final envelope = jsonDecode(raw) as Map<String, dynamic>;
        final data = envelope['data'] as Map<String, dynamic>;
        if (contentHash(data) == envelope['hash']) {
          final index = _maps(data['index']);
          final docs = _maps(data['documents']);
          _index = _identities(index);
          _documents = {
            for (final e in docs.entries)
              if (freeDrugCanonicalIds.contains(e.key) &&
                  index.containsKey(e.key) &&
                  e.value['id'] == e.key)
                e.key: e.value
          };
        }
      }
    } catch (_) {/* Invalid public cache never grants access. */}
    // Legacy unowned plaintext cannot be attributed safely to a logged-in UID.
    // Keep only public Free60 values, remove the vulnerable legacy envelope.
    await preferences.remove(_key);
    final owner = entitlement.current.resolvedUid;
    final secure = await _secure.restore();
    if (owner == entitlement.current.resolvedUid && entitlement.isPremium) {
      _documents.addAll({
        for (final e in secure.entries)
          if (_index.containsKey(e.key) && e.value['id'] == e.key)
            e.key: e.value
      });
      _documentsOwner = owner;
    }
    _generation++;
  }

  static Map<String, Map<String, Object?>> _maps(Object? raw) {
    final result = <String, Map<String, Object?>>{};
    for (final e in (raw as Map).entries) {
      final id = e.key as String;
      if (!RegExp(r'^[a-z0-9_]+$').hasMatch(id))
        throw const FormatException('CANONICAL_ID');
      result[id] = Map<String, Object?>.from(e.value as Map);
    }
    return result;
  }

  static Map<String, Map<String, Object?>> _identities(
          Map<String, Map<String, Object?>> rows) =>
      {
        for (final entry in rows.entries)
          entry.key: {'id': entry.key, 'name': entry.value['name']}
      };

  Future<void> _persist() {
    final publicDocs = {
      for (final e in _documents.entries)
        if (freeDrugCanonicalIds.contains(e.key)) e.key: e.value
    };
    final premiumDocs = {
      for (final e in _documents.entries)
        if (!freeDrugCanonicalIds.contains(e.key)) e.key: e.value
    };
    final data = {'index': _index, 'documents': publicDocs};
    final encoded = jsonEncode({'data': data, 'hash': contentHash(data)});
    final owner = entitlement.current.resolvedUid;
    final generation = _generation;
    final op = _writes.then((_) async {
      if (!await preferences.setString(_publicKey, encoded))
        throw StateError('CATALOG_CACHE_WRITE');
      await preferences.remove(_key);
      if (entitlement.isPremium && owner == entitlement.current.resolvedUid) {
        await _secure.save(premiumDocs, generation);
      }
    });
    _writes = op.catchError((Object _) {});
    return op;
  }

  Future<void> refresh() async {
    if (_documentsOwner != entitlement.current.resolvedUid) {
      _documents.removeWhere((id, _) => !freeDrugCanonicalIds.contains(id));
      _documentsOwner = entitlement.current.resolvedUid;
    }
    final fresh = await loadIndex(); // Resolver validates exact IDs and schema.
    if (fresh.isEmpty) throw const FormatException('EMPTY_CANONICAL_INDEX');
    _index = _identities(fresh);
    _documents.removeWhere((id, _) => !_index.containsKey(id));
    _generation++;
    // Persist removals before downloading: no old snapshot resurrection.
    await _persist();
  }

  Future<Map<String, Object?>?> lookup(String id) async {
    if (_documentsOwner != entitlement.current.resolvedUid) {
      _documents.removeWhere((id, _) => !freeDrugCanonicalIds.contains(id));
      _documentsOwner = entitlement.current.resolvedUid;
    }
    if (!allowed(id)) throw StateError('ENTITLEMENT_REQUIRED');
    final generation = _generation;
    final owner = entitlement.current.resolvedUid;
    try {
      final doc = await loadDocument(id);
      if (owner != entitlement.current.resolvedUid ||
          generation != _generation ||
          !allowed(id)) throw StateError('STALE_CATALOG_REQUEST');
      if (doc == null) {
        _documents.remove(id);
        _index.remove(id);
        await _persist();
        return null;
      }
      if (doc['id'] != id) throw const FormatException('CANONICAL_ID_MISMATCH');
      _documents[id] = Map.from(doc);
      await _persist();
      return Map.unmodifiable(doc);
    } on FormatException {
      rethrow;
    } catch (_) {
      if (owner != entitlement.current.resolvedUid ||
          generation != _generation ||
          !allowed(id)) rethrow;
      final cached = _documents[id];
      if (cached == null) rethrow;
      return Map.unmodifiable(cached);
    }
  }

  Future<void> prepareOffline() async {
    await refresh();
    final generation = _generation;
    final owner = entitlement.current.resolvedUid;
    final ids = _index.keys.where(allowed).toList();
    final staged = <String, Map<String, Object?>>{};
    for (var start = 0; start < ids.length; start += 4) {
      await Future.wait(ids.skip(start).take(4).map((id) async {
        if (owner != entitlement.current.resolvedUid ||
            !allowed(id) ||
            generation != _generation)
          throw StateError('CATALOG_SESSION_CHANGED');
        final doc = await loadDocument(id);
        if (doc == null || doc['id'] != id)
          throw const FormatException('INCOMPLETE_CANONICAL_SNAPSHOT');
        staged[id] = Map.from(doc);
      }));
    }
    if (owner != entitlement.current.resolvedUid ||
        generation != _generation ||
        ids.any((id) => !allowed(id)))
      throw StateError('CATALOG_SESSION_CHANGED');
    final previous = _documents;
    _documents = {..._documents, ...staged};
    try {
      await _persist();
    } catch (_) {
      _documents = previous;
      rethrow;
    }
  }
}
