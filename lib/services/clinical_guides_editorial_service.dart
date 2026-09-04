import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';
import '../models/clinical_guide_article.dart';

class ClinicalGuidesEditorialService {
  ClinicalGuidesEditorialService._();

  static CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance.collection('clinical_guides');

  static Future<List<ClinicalGuideArticle>> loadPublished({
    String? language,
  }) async {
    final snapshot =
        await _collection.where('isPublished', isEqualTo: true).get();

    final guides = snapshot.docs
        .map(
          (doc) =>
              ClinicalGuideArticle.fromJson(doc.data(), documentId: doc.id),
        )
        .where((guide) => _matchesLanguage(guide, language))
        .toList(growable: false);

    return _sortNewestFirst(guides);
  }

  static Stream<List<ClinicalGuideArticle>> watchPublished({String? language}) {
    return _collection.where('isPublished', isEqualTo: true).snapshots().map(
          (snapshot) => _sortNewestFirst(
            snapshot.docs
                .map(
                  (doc) => ClinicalGuideArticle.fromJson(
                    doc.data(),
                    documentId: doc.id,
                  ),
                )
                .where((guide) => _matchesLanguage(guide, language))
                .toList(growable: false),
          ),
        );
  }

  // MEDCASES_WEB_GUIAS_OPEN_RELEASE_REST_BRIDGE_V1_B_R0
  // Web sessions can be valid in the REST auth plane while
  // FirebaseAuth.instance.currentUser is still null. clinical_guides requires
  // request.auth, so a direct Firestore SDK get() can be permission-denied
  // even though the Web user is authenticated. Native keeps the SDK path.
  static Future<ClinicalGuideArticle?> loadById(String id) async {
    if (kIsWeb) {
      return _loadByIdRestWeb(id);
    }

    final doc = await _collection.doc(id).get();
    if (!doc.exists) return null;

    final data = doc.data();
    if (data == null) return null;

    return ClinicalGuideArticle.fromJson(data, documentId: doc.id);
  }

  static Future<ClinicalGuideArticle?> _loadByIdRestWeb(String id) async {
    final cleanId = id.trim();
    if (cleanId.isEmpty) return null;

    final token = await AuthService.getAdminToken();
    if (token.isEmpty) {
      throw StateError(
        'clinical_guides/$cleanId: token REST indisponível para abertura Web.',
      );
    }

    final app = FirebaseFirestore.instance.app;
    final projectId = app.options.projectId;
    final apiKey = app.options.apiKey;

    final encodedId = Uri.encodeComponent(cleanId);
    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/'
      '$projectId/databases/(default)/documents/clinical_guides/$encodedId',
    ).replace(queryParameters: <String, String>{'key': apiKey});

    final response = await http.get(
      uri,
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 12));

    if (response.statusCode == 404) return null;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final snippet = response.body.length > 240
          ? response.body.substring(0, 240)
          : response.body;
      throw StateError(
        'clinical_guides/$cleanId REST HTTP ${response.statusCode}: $snippet',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Resposta REST de clinical_guides inválida.');
    }

    final rawFields = decoded['fields'];
    if (rawFields is! Map) return null;

    final data = <String, dynamic>{};
    for (final entry in rawFields.entries) {
      data[entry.key.toString()] = _decodeFirestoreRestValue(entry.value);
    }

    return ClinicalGuideArticle.fromJson(data, documentId: cleanId);
  }

  static dynamic _decodeFirestoreRestValue(dynamic raw) {
    if (raw is! Map) return null;

    if (raw.containsKey('nullValue')) return null;
    if (raw.containsKey('stringValue'))
      return raw['stringValue']?.toString() ?? '';
    if (raw.containsKey('booleanValue')) return raw['booleanValue'] == true;

    if (raw.containsKey('integerValue')) {
      return int.tryParse(raw['integerValue']?.toString() ?? '') ?? 0;
    }

    if (raw.containsKey('doubleValue')) {
      final value = raw['doubleValue'];
      return value is num ? value.toDouble() : double.tryParse('$value') ?? 0.0;
    }

    if (raw.containsKey('timestampValue')) {
      return raw['timestampValue']?.toString();
    }

    if (raw.containsKey('referenceValue')) {
      return raw['referenceValue']?.toString() ?? '';
    }

    final arrayValue = raw['arrayValue'];
    if (arrayValue is Map) {
      final values = arrayValue['values'];
      if (values is! List) return <dynamic>[];
      return values.map(_decodeFirestoreRestValue).toList(growable: false);
    }

    final mapValue = raw['mapValue'];
    if (mapValue is Map) {
      final fields = mapValue['fields'];
      if (fields is! Map) return <String, dynamic>{};
      return <String, dynamic>{
        for (final entry in fields.entries)
          entry.key.toString(): _decodeFirestoreRestValue(entry.value),
      };
    }

    final geoValue = raw['geoPointValue'];
    if (geoValue is Map) {
      return <String, dynamic>{
        'latitude': geoValue['latitude'],
        'longitude': geoValue['longitude'],
      };
    }

    return null;
  }

  static Future<Map<String, dynamic>?> loadAdminDocument(String id) async {
    final cleanId = id.trim();
    if (cleanId.isEmpty) return null;

    final doc = await _collection.doc(cleanId).get();
    if (!doc.exists) return null;
    return doc.data();
  }

  static Future<String> saveBilingualGuide({
    String id = '',
    required String specialty,
    required String authors,
    required String year,
    required int version,
    required String heroImageUrl,
    required Map<String, dynamic> pt,
    required Map<String, dynamic> es,
    required bool published,
    required String adminName,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final cleanPt = _cleanLocalePayload(pt, 'pt');
    final cleanEs = _cleanLocalePayload(es, 'es');

    if (published && (!_localeReady(cleanPt) || !_localeReady(cleanEs))) {
      throw StateError(
        'Guia editorial requer PT e ES completos antes de publicar.',
      );
    }

    final compatibility =
        _text(cleanPt['title']).isNotEmpty ? cleanPt : cleanEs;

    final compatibilityBlocks = compatibility['bodyBlocks'] is List
        ? List<dynamic>.of(compatibility['bodyBlocks'] as List)
        : const <dynamic>[];
    final compatibilityReferences = compatibility['references'] is List
        ? List<dynamic>.of(compatibility['references'] as List)
        : const <dynamic>[];

    final localizations = <String, dynamic>{'pt': cleanPt, 'es': cleanEs};

    final searchPrefixes = _buildSearchPrefixes(
      <String>[
        _text(cleanPt['title']),
        _text(cleanPt['subtitle']),
        _text(cleanPt['summary']),
        _text(cleanEs['title']),
        _text(cleanEs['subtitle']),
        _text(cleanEs['summary']),
        specialty,
        authors,
        year,
      ].join(' '),
    );

    final data = <String, dynamic>{
      'title': _text(compatibility['title']),
      'description': _text(compatibility['summary']),
      'summary': _text(compatibility['summary']),
      'subtitle': _text(compatibility['subtitle']),
      'category': specialty,
      'specialty': specialty,
      'authors': authors,
      'year': year,
      'version': version,
      'heroImageUrl': heroImageUrl,
      'coverUrl': heroImageUrl,
      'pdfUrl': _text(compatibility['pdfUrl']),
      'bodyBlocks': compatibilityBlocks,
      'references': compatibilityReferences,
      'language': 'multilingual',
      'localizations': localizations,
      'hasEditorialContent': _hasBody(cleanPt) || _hasBody(cleanEs),
      'status': published ? 'published' : 'draft',
      'isPublished': published,
      'uploadedAt': now,
      'updatedAt': now,
      'uploadedBy': adminName,
      'searchPrefixes': searchPrefixes,
      'searchIndexVersion': 2,
      if (published) 'publishedAt': now,
    };

    final cleanId = id.trim();
    if (cleanId.isEmpty) {
      final ref = await _collection.add(data);
      return ref.id;
    }

    await _collection.doc(cleanId).set(data, SetOptions(merge: true));
    return cleanId;
  }

  static Map<String, dynamic> _cleanLocalePayload(
    Map<String, dynamic> raw,
    String language,
  ) {
    final rawBlocks = raw['bodyBlocks'];
    final rawReferences = raw['references'];

    return <String, dynamic>{
      'language': language,
      'title': _text(raw['title']),
      'subtitle': _text(raw['subtitle']),
      'summary': _text(raw['summary']),
      'bodyBlocks':
          rawBlocks is List ? List<dynamic>.of(rawBlocks) : const <dynamic>[],
      'references': rawReferences is List
          ? List<dynamic>.of(rawReferences)
          : const <dynamic>[],
      if (_text(raw['pdfUrl']).isNotEmpty) 'pdfUrl': _text(raw['pdfUrl']),
    };
  }

  static bool _hasBody(Map<String, dynamic> locale) {
    final body = locale['bodyBlocks'];
    return body is List && body.isNotEmpty;
  }

  static bool _localeReady(Map<String, dynamic> locale) {
    return _text(locale['title']).isNotEmpty &&
        _text(locale['summary']).isNotEmpty &&
        _hasBody(locale);
  }

  static String _text(Object? value) => value?.toString().trim() ?? '';

  static List<String> _buildSearchPrefixes(String raw) {
    var normalized = raw.toLowerCase().trim();
    const from = 'áàãâäéèêëíìîïóòõôöúùûüçñ';
    const to = 'aaaaaeeeeiiiiooooouuuucn';

    for (var i = 0; i < from.length; i++) {
      normalized = normalized.replaceAll(from[i], to[i]);
    }

    normalized = normalized
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final prefixes = <String>{};
    for (final word in normalized.split(' ')) {
      if (word.length < 3) continue;
      final capped = word.length > 20 ? word.substring(0, 20) : word;

      for (var length = 3; length <= capped.length; length++) {
        prefixes.add(capped.substring(0, length));
        if (prefixes.length >= 420) {
          return prefixes.toList(growable: false);
        }
      }
    }

    return prefixes.toList(growable: false);
  }

  static bool _matchesLanguage(ClinicalGuideArticle guide, String? language) {
    final wanted = language?.trim().toLowerCase() ?? '';
    if (wanted.isEmpty) return true;

    if (guide.localizations.isNotEmpty) {
      return guide.localizations.containsKey(
        wanted.startsWith('es') ? 'es' : 'pt',
      );
    }

    final current = guide.language.trim().toLowerCase();

    // Legacy documents without an explicit language remain visible so the
    // migration does not make existing guides disappear.
    if (current.isEmpty) return true;

    return current == wanted;
  }

  static List<ClinicalGuideArticle> _sortNewestFirst(
    List<ClinicalGuideArticle> guides,
  ) {
    final copy = List<ClinicalGuideArticle>.of(guides);

    copy.sort((a, b) {
      final aDate = a.publishedAt ?? a.updatedAt;
      final bDate = b.publishedAt ?? b.updatedAt;

      if (aDate == null && bDate == null) {
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      }
      if (aDate == null) return 1;
      if (bDate == null) return -1;

      return bDate.compareTo(aDate);
    });

    return copy;
  }
}
