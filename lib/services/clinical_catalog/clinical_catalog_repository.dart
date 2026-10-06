import 'clinical_catalog_functional_baseline.dart';
import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';

const clinicalRegistryCollections = <String>[
  'clinical_identity_registry',
  'clinical_protocols',
  'clinical_classification_registry',
  'clinical_management_rules',
  'clinical_action_registry',
  'clinical_content_registry',
];

String clinicalCanonicalJson(Object? value) {
  Object? canonical(Object? v) {
    if (v is Map) {
      final keys = v.keys.cast<String>().toList()..sort();
      return {for (final k in keys) k: canonical(v[k])};
    }
    if (v is List) return v.map(canonical).toList();
    return v;
  }

  return jsonEncode(canonical(value));
}

String clinicalHash(Object? value) =>
    sha256.convert(utf8.encode(clinicalCanonicalJson(value))).toString();

class ClinicalCatalogInvalid implements Exception {
  const ClinicalCatalogInvalid(this.code);
  final String code;
}

abstract interface class ClinicalCatalogRemote {
  Future<Map<String, dynamic>> pointer();
  Future<Map<String, dynamic>> manifest(String version);
  Future<String> chunk(String version, String id);
}

abstract interface class ClinicalCatalogCache {
  Future<Map<String, dynamic>?> read();
  Future<void> write(Map<String, dynamic> envelope);
}

const clinicalFunctionalCollections = [...clinicalRegistryCollections, 'clinical_projection_registry', 'clinical_legacy_protocols'];

enum ClinicalCatalogOrigin { remote, cache, bundled }

/// Immutable lease: a request keeps this exact version across all async reads.
class ClinicalCatalogSnapshot {
  ClinicalCatalogSnapshot._(this.version, this.schemaVersion,
      this.manifestSha256, this.origin, Map<String, dynamic> data)
      : _data = _freeze(data) as Map<String, dynamic>;
  ClinicalCatalogSnapshot._validated(this.version, this.schemaVersion,
      this.manifestSha256, this.origin, this._data);
  ClinicalCatalogSnapshot _withOrigin(ClinicalCatalogOrigin source) =>
      ClinicalCatalogSnapshot._validated(
          version, schemaVersion, manifestSha256, source, _data);
  factory ClinicalCatalogSnapshot.bundled() => ClinicalCatalogSnapshot._(
      'bundled', 1, '', ClinicalCatalogOrigin.bundled, const {});
  final String version;
  final int schemaVersion;
  final String manifestSha256;
  final ClinicalCatalogOrigin origin;
  final Map<String, dynamic> _data;
  bool get isBundled => origin == ClinicalCatalogOrigin.bundled;
  List<Map<String, dynamic>> rows(String collection) =>
      ((_data[collection] as List?) ?? const []).cast<Map<String, dynamic>>();

  bool isInheritedOwner(String owner) {
    final matches=rows('clinical_projection_registry').where((r)=>r['canonicalPathologyKey']==owner);
    return matches.isNotEmpty && matches.every((r)=>r['migrationStatus']=='MIGRATION_BASELINE_INHERITED');
  }
  String projectionRoute(String query, String mode, String language) {
    final owner = matchOwner(query);
    if (owner == null) return 'absent';
    final p = projections(mode, language, owner: owner);
    if (p.isEmpty) return 'absent';
    return p.every((x) => x['format'] == 'legacy_source') ? 'legacy_source_context' : 'authored_projection';
  }
  bool usesAuthoredProjection(String query, String mode, String language) => projectionRoute(query, mode, language) == 'authored_projection';
  List<Map<String,dynamic>> get legacyProtocolPayloads => rows('clinical_legacy_protocols').map((r)=>(r['payload'] as Map).cast<String,dynamic>()).toList(growable:false);
  Set<String> surfaceOwners(String mode,String locale) => {for(final row in rows(schemaVersion==2?'clinical_projection_registry':'clinical_content_registry')) if((row['payload'] as Map?)?[locale]?[mode+'Projection'] is Map) row['canonicalPathologyKey'] as String};

  List<Map<String, dynamic>> projections(String mode, String language,
      {String? owner}) {
    if (!const ['study', 'plantao'].contains(mode)) {
      throw ArgumentError.value(mode);
    }
    final locale = language.toLowerCase().startsWith('pt') ? 'pt' : 'es';
    return [
      for (final row in rows(schemaVersion == 2 ? 'clinical_projection_registry' : 'clinical_content_registry'))
        if ((owner == null || row['canonicalPathologyKey'] == owner) && row['payload'][locale]['${mode}Projection'] is Map)
          (row['payload'][locale]['${mode}Projection'] as Map)
              .cast<String, dynamic>()
    ];
  }

  /// Uses remote identities, including new aliases, without a compiled owner list.
  String? matchOwner(String query) {
    String fold(String s) {
      var out = s.toLowerCase();
      const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
      const to = 'aaaaaeeeeiiiiooooouuuucn';
      for (var i = 0; i < from.length; i++) {
        out = out.replaceAll(from[i], to[i]);
      }
      return out.replaceAll(RegExp('[^a-z0-9]+'), ' ').trim();
    }

    Iterable<String> strings(Object? v) sync* {
      if (v is String) yield v;
      if (v is List) {
        for (final x in v) {
          yield* strings(x);
        }
      }
      if (v is Map) {
        for (final x in v.values) {
          yield* strings(x);
        }
      }
    }

    final q = ' ${fold(query)} ';
    var score = 0;
    final owners = <String>{};
    for (final row in rows('clinical_identity_registry')) {
      final owner = row['canonicalKey'] as String;
      final aliases = [
        owner,
        ...strings(row['aliases']),
        ...strings(row['strongAliases']),
        ...strings(row['displayLabel'])
      ];
      for (final alias in aliases) {
        final a = fold(alias);
        if (a.length < 3 || !q.contains(' $a ')) continue;
        if (a.length > score) {
          owners.clear();
          score = a.length;
        }
        if (a.length == score) owners.add(owner);
      }
    }
    return owners.length == 1 ? owners.single : null;
  }

  String context(String query, String mode, String language) {
    final owner = matchOwner(query);
    if (owner == null) return '';
    return projections(mode, language, owner: owner)
        .where((p) => p['format'] != 'legacy_source').map(clinicalCanonicalJson)
        .join('\n');
  }

  /// Display fallback uses authored text, never internal JSON or inferred facts.
  String displayText(String query, String mode, String language) {
    final owner = matchOwner(query);
    if (owner == null) return '';
    return projections(mode, language, owner: owner)
        .map((p) {
          if (p['format'] == 'markdown') return p['markdown'] as String;
          if (p['format'] == 'legacy_source') return '';
          final sections = p['sections'] as List;
          if (sections.any((s) => s['text'] is! String)) return '';
          return [
            '# ${p['title']}',
            for (final s in sections)
              s['type'] == 'heading' ? '## ${s['text']}' : s['text'] as String
          ].join('\n\n');
        })
        .where((s) => s.isNotEmpty)
        .join('\n\n');
  }

  List<String> references(String query, String mode, String language) {
    final owner = matchOwner(query);
    if (owner == null) return const [];
    return [
      for (final p in projections(mode, language, owner: owner))
        for (final r in (p['references'] as List))
          if (r is String) r else if (r is Map)
            [
              r['title'],
              r['organization_or_authors'],
              r['year'],
              r['url'],
              r['doi']
            ].whereType<String>().where((s) => s.isNotEmpty).join(' — ')
    ];
  }
}

Object? _freeze(Object? v) => v is Map
    ? Map<String, dynamic>.unmodifiable(
        v.map((k, x) => MapEntry(k as String, _freeze(x))))
    : v is List
        ? List<Object?>.unmodifiable(v.map(_freeze))
        : v;

/// Only schema is compiled. Content versions are opaque remote identifiers.
class ClinicalCatalogValidator {
  static void require(bool condition, String code) {
    if (!condition) throw ClinicalCatalogInvalid(code);
  }

  static ClinicalCatalogSnapshot validate(
      Map<String, dynamic> envelope, ClinicalCatalogOrigin origin) {
    final pointer = envelope['pointer'] as Map;
    final manifest = envelope['manifest'] as Map;
    final chunks = envelope['chunks'] as Map;
    require(pointer['status'] == 'ACTIVE', 'pointer_not_active');
    require(const [1,2].contains(pointer['schemaVersion']) && pointer['schemaVersion'] == manifest['schemaVersion'],
        'schema_unsupported');
    final version = pointer['activeVersion'];
    require(
        version is String &&
            RegExp(r'^[A-Za-z0-9._-]{1,120}$').hasMatch(version),
        'invalid_version');
    require(
        manifest['contentVersion'] == version && manifest['status'] == 'ACTIVE',
        'version_not_active');
    require(
        clinicalHash(manifest) == pointer['manifestSha256'], 'manifest_hash');
    final schema = manifest['schemaVersion'] as int;
    final collections = schema == 2 ? clinicalFunctionalCollections : clinicalRegistryCollections;
    if (schema == 2) require(manifest['minimumClientBuild'] == 1717, 'client_build');
    final descriptors = manifest['chunks'] as List;
    require(
        descriptors.isNotEmpty && descriptors.length <= 5000, 'chunk_count');
    final data = <String, dynamic>{
      for (final c in collections) c: <Map<String, dynamic>>[]
    };
    final ids = <String>{};
    for (final raw in descriptors) {
      final d = raw as Map;
      final id = d['id'];
      require(
          id is String &&
              RegExp(r'^[A-Za-z0-9._-]{1,120}$').hasMatch(id) &&
              ids.add(id),
          'chunk_id');
      require(collections.contains(d['collection']),
          'unknown_collection');
      final text = chunks[id];
      require(
          text is String && utf8.encode(text).length <= 800000, 'chunk_size');
      require(
          sha256.convert(utf8.encode(text as String)).toString() == d['sha256'],
          'chunk_hash');
      final rows = jsonDecode(text) as List;
      require(rows.length == d['count'], 'row_count');
      (data[d['collection']] as List).addAll(rows.cast<Map<String, dynamic>>());
    }
    require(chunks.length == ids.length, 'extra_chunks');
    final ownerRows = data['clinical_identity_registry'] as List;
    final owners = <String>{};
    for (final row in ownerRows) {
      require(
          row['enabled'] != false &&
              row['canonicalKey'] is String &&
              owners.add(row['canonicalKey']),
          'owner_identity');
    }
    require(owners.isNotEmpty && owners.length == manifest['ownerCount'],
        'owner_count');
    for (final collection in collections) {
      final rows = data[collection] as List;
      require((manifest['counts'] as Map)[collection] == rows.length,
          'collection_count');
      for (final row in rows) {
        final owner = collection == 'clinical_identity_registry'
            ? row['canonicalKey']
            : collection == 'clinical_action_registry'
                ? (((row['match'] as Map?) ??
                        const {})['canonicalPathologyKey'] ??
                    row['canonicalPathologyKey'])
                : row['canonicalPathologyKey'];
        require(owners.contains(owner) && row['enabled'] != false,
            'orphan_or_disabled_owner');
      }
    }
    final contentOwners = <String>{};
    for (final row in data[schema == 2 ? 'clinical_projection_registry' : 'clinical_content_registry'] as List) {
      contentOwners.add(row['canonicalPathologyKey'] as String);
      final payload = row['payload'] as Map;
      if (schema == 2 && row['migrationStatus'] == 'MIGRATION_BASELINE_INHERITED') {
        require(row['historicalApprovalHash'] == null && clinicalHash(payload) == row['migrationBaselineHash'] && row['sourceRuntimeHash'] == row['migrationBaselineHash'], 'migration_hash');
        final owner = row['canonicalPathologyKey'] as String;
        require(payload['ownerId'] == owner, 'projection_owner');
        var count = 0;
        for (final mode in ['study','plantao']) for (final locale in ['pt','es']) {
          final x = (payload[locale] as Map?)?['${mode}Projection'];
          if (x == null) continue;
          count++;
          require(x is Map && x['format'] == 'legacy_source' && x['ownerId'] == owner && x['mode'] == mode && x['locale'] == locale, 'mode_locale_owner');
          final source = x['sourcePayload'];
          require(source is Map && clinicalHash(source) == x['sourcePayloadHash'] && clinicalInheritedSourceHashes['$owner.$mode.$locale'] == x['sourcePayloadHash'] && clinicalInheritedSourceHashes['$owner.$mode.$locale.projection'] == clinicalHash(x), 'unproven_legacy_baseline');
          final references = x['references'];
          final state = row['referenceState']?[mode]?[locale];
          require(references is List && ['present','legacy_missing','legacy_locale_divergence'].contains(state), 'legacy_reference_state');
          require(references.isNotEmpty || state == 'legacy_missing', 'legacy_reference_missing');
          require(state != 'legacy_missing' || references.isEmpty, 'legacy_reference_state_mismatch');
          if (mode == 'study') {
            final models = (data['clinical_legacy_protocols'] as List).where((r)=>r['canonicalPathologyKey'] == owner).toList();
            require(models.length == 1 && clinicalCanonicalJson(models.single['payload']) == clinicalCanonicalJson(source) && source['id'] == owner && source['title']?[locale] is String && source['actions']?[locale] != null, 'legacy_protocol_source_binding');
          } else {
            require(source['providerPrompt'] is String && (source['providerPrompt'] as String).isNotEmpty, 'legacy_context_missing');
          }
        }
        require(count > 0, 'owner_has_no_projection');
        continue;
      }
      final approved = payload['approvedClinicalPayloadJson'];
      final approvedHash = payload['approvedClinicalPayloadSha256'];
      require(
          approved is String &&
              approvedHash is String &&
              row['approvedClinicalPayloadSha256'] == approvedHash,
          'approved_hash_missing');
      require(
          sha256.convert(utf8.encode(approved as String)).toString() ==
              approvedHash,
          'approved_payload_hash');
      for (final mode in ['study', 'plantao']) {
        final pt = (payload['pt'] as Map?)?['${mode}Projection'];
        final es = (payload['es'] as Map?)?['${mode}Projection'];
        require(pt is Map && es is Map, 'projection_missing');
        if ((pt as Map)['format'] == 'markdown' ||
            (es as Map)['format'] == 'markdown') {
          for (final p in [pt, es]) {
            require(
                p['format'] == 'markdown' &&
                    p['markdown'] is String &&
                    (p['markdown'] as String).trim().isNotEmpty &&
                    p['references'] is List &&
                    (p['references'] as List).isNotEmpty,
                'markdown_projection');
            require(
                clinicalCanonicalJson(p['references']) ==
                    clinicalCanonicalJson(payload['references']),
                'reference_parity');
          }
          require(
              pt['markdown'] == (payload['pt'] as Map)['${mode}Markdown'] &&
                  es['markdown'] == (payload['es'] as Map)['${mode}Markdown'],
              'markdown_source_binding');
          continue;
        }
        for (final p in [pt, es]) {
          require(
              p['title'] is String &&
                  (p['title'] as String).isNotEmpty &&
                  p['sections'] is List &&
                  (p['sections'] as List).isNotEmpty &&
                  p['references'] is List &&
                  (p['references'] as List).isNotEmpty,
              'projection_schema');
        }
        for (final projection in [pt, es]) {
          final sectionIds = <String>{};
          for (final section in projection['sections'] as List) {
            require(
                section is Map &&
                    section['id'] is String &&
                    (section['id'] as String).isNotEmpty &&
                    sectionIds.add(section['id']) &&
                    section['type'] is String,
                'section_schema');
          }
          final referenceIds = <String>{};
          for (final reference in projection['references'] as List) {
            require(
                reference is Map &&
                    reference['id'] is String &&
                    (reference['id'] as String).isNotEmpty &&
                    referenceIds.add(reference['id']),
                'reference_schema');
          }
        }
        final ptIds = (pt['sections'] as List).map((s) => s['id']).toList();
        final esIds = (es['sections'] as List).map((s) => s['id']).toList();
        require(clinicalCanonicalJson(ptIds) == clinicalCanonicalJson(esIds),
            'locale_section_parity');
        require(
            clinicalCanonicalJson(
                    (pt['references'] as List).map((r) => r['id']).toList()) ==
                clinicalCanonicalJson(
                    (es['references'] as List).map((r) => r['id']).toList()),
            'reference_parity');
      }
    }
    require(
        owners.length == contentOwners.length &&
            owners.containsAll(contentOwners),
        'mode_owner_parity');
    if (schema == 2) _validateFunctionalManifest(manifest, data, owners);
    final snapshot = ClinicalCatalogSnapshot._(version as String, schema,
        pointer['manifestSha256'] as String, origin, data);
    return snapshot;
  }
  static void _validateFunctionalManifest(Map manifest, Map data, Set<String> owners) {
    final sorted = owners.toList()..sort();
    require(clinicalHash(sorted) == manifest['ownerSetHash'], 'owner_set_hash');
    final projectedRows = data['clinical_projection_registry'] as List;
    final metadata = manifest['owners'] as List;
    require(metadata.length == owners.length && metadata.map((x)=>x['ownerId']).toSet().length == owners.length, 'manifest_owners');
    final actualSets = <String,List<String>>{};
    for(final mode in ['study','plantao']) for(final locale in ['pt','es']) {
      final current = <String>{for(final r in projectedRows) if(r['payload']?[locale]?['${mode}Projection'] is Map) r['canonicalPathologyKey'] as String}.toList()..sort();
      actualSets['${mode}_$locale'] = current;
      require(clinicalCanonicalJson(current) == clinicalCanonicalJson(manifest['surfaceOwnerIds']?['${mode}_$locale']) && clinicalHash(current) == manifest['surfaceSetHashes']?['${mode}_$locale'], 'manifest_surface_sets');
      require(current.length == manifest['${mode}${locale == 'pt' ? 'Pt' : 'Es'}Count'], 'manifest_surface_counts');
    }
    for(final entry in metadata) {
      final owner = entry['ownerId']; require(owners.contains(owner), 'manifest_owner_unknown');
      final rows = projectedRows.where((r)=>r['canonicalPathologyKey']==owner).toList();
      require(rows.isNotEmpty, 'owner_projection_record_missing');
      final inherited = rows.every((r)=>r['migrationStatus']=='MIGRATION_BASELINE_INHERITED');
      require(entry['routeKind'] == (inherited?'legacy_source_context':'authored_projection'), 'manifest_route_kind');
      for(final mode in ['study','plantao']) for(final locale in ['pt','es']) {
        final available = actualSets['${mode}_$locale']!.contains(owner);
        require(entry['availableModes']?[mode]?[locale] == available, 'manifest_availability');
        final state = !available ? 'not_available' : inherited ? (rows.first['referenceState']?[mode]?[locale]) : 'present';
        require(entry['referenceState']?[mode]?[locale] == state, 'manifest_reference_state');
      }
    }
  }

}

class ClinicalCatalogRepository {
  ClinicalCatalogRepository(
      {required this.remote,
      required this.cache,
      this.pointerTtl = const Duration(seconds: 30),
      this.minimumRemoteOwnerCount = 0,
      this.requiredSurfaceOwners = const {},
      this.onRead,
      DateTime Function()? clock})
      : clock = clock ?? DateTime.now;
  final ClinicalCatalogRemote remote;
  final ClinicalCatalogCache cache;
  final Duration pointerTtl;
  final int minimumRemoteOwnerCount;
  final Map<String,List<String>> requiredSurfaceOwners;

  void _requireCoverage(ClinicalCatalogSnapshot snapshot) {
    {
      for(final e in requiredSurfaceOwners.entries) {
        final parts=e.key.split('_');
        ClinicalCatalogValidator.require(snapshot.surfaceOwners(parts[0],parts[1]).containsAll(e.value), 'remote_surface_coverage_regression');
      }
      if (snapshot.schemaVersion == 2) return;
    }
    ClinicalCatalogValidator.require(
        snapshot.rows('clinical_identity_registry').length >=
            minimumRemoteOwnerCount,
        'remote_coverage_regression');
  }

  final void Function(Map<String, Object?>)? onRead;
  final DateTime Function() clock;
  ClinicalCatalogSnapshot? _current;
  Map<String, dynamic>? _envelope;
  DateTime? _checked;
  Future<ClinicalCatalogSnapshot>? _flight;
  String? fallbackReason;
  Future<ClinicalCatalogSnapshot> acquire({bool refresh = false}) {
    if (_flight != null) return _flight!;
    if (!refresh &&
        _current != null &&
        _checked != null &&
        clock().difference(_checked!) < pointerTtl) {
      return Future.value(_current!);
    }
    return _flight = _load().whenComplete(() => _flight = null);
  }

  Future<ClinicalCatalogSnapshot> _load() async {
    try {
      final pointer = await remote.pointer();
      ClinicalCatalogValidator.require(
          pointer['status'] == 'ACTIVE', 'pointer_not_active');
      if (_envelope != null &&
          (_envelope!['pointer'] as Map)['activeVersion'] ==
              pointer['activeVersion'] &&
          (_envelope!['pointer'] as Map)['manifestSha256'] ==
              pointer['manifestSha256']) {
        ClinicalCatalogValidator.require(
            pointer['schemaVersion'] == _current?.schemaVersion,
            'schema_unsupported');
        // The immutable lease was already fully validated. Checking an unchanged
        // pointer must not rehash/decode the full catalogue on the UI isolate.
        final result = _current!._withOrigin(ClinicalCatalogOrigin.remote);
        _checked = clock();
        _current = result;
        fallbackReason = null;
        return result;
      }
      final version = pointer['activeVersion'];
      ClinicalCatalogValidator.require(
          version is String &&
              RegExp(r'^[A-Za-z0-9._-]{1,120}$').hasMatch(version),
          'invalid_version');
      final manifest = await remote.manifest(version as String);
      ClinicalCatalogValidator.require(
          clinicalHash(manifest) == pointer['manifestSha256'] &&
              manifest['status'] == 'ACTIVE' &&
              const [1,2].contains(manifest['schemaVersion']),
          'manifest_gate');
      final descriptors = manifest['chunks'] as List;
      ClinicalCatalogValidator.require(
          descriptors.length <= 5000, 'chunk_count');
      final chunks = <String, String>{};
      for (var offset = 0; offset < descriptors.length; offset += 8) {
        final batch = descriptors.skip(offset).take(8);
        final received = await Future.wait(batch.map((d) async {
          final id = d['id'];
          ClinicalCatalogValidator.require(
              id is String && RegExp(r'^[A-Za-z0-9._-]{1,120}$').hasMatch(id),
              'chunk_id');
          return MapEntry(id as String, await remote.chunk(version, id));
        }));
        chunks.addEntries(received);
        ClinicalCatalogValidator.require(
            chunks.values.fold<int>(
                    0, (size, text) => size + utf8.encode(text).length) <=
                64 * 1024 * 1024,
            'snapshot_size');
      }
      final after = await remote.pointer();
      ClinicalCatalogValidator.require(
          clinicalCanonicalJson(after) == clinicalCanonicalJson(pointer),
          'pointer_changed');
      final envelope = <String, dynamic>{
        'activeVersion': version,
        'contentVersion': manifest['contentVersion'],
        'schemaVersion': manifest['schemaVersion'],
        'manifestSha256': pointer['manifestSha256'],
        'pointer': pointer,
        'manifest': manifest,
        'chunks': chunks,
        'fetchedAt': clock().toUtc().toIso8601String(),
        'validatedAt': clock().toUtc().toIso8601String()
      };
      final result = ClinicalCatalogValidator.validate(
          envelope, ClinicalCatalogOrigin.remote);
      _requireCoverage(result);
      // Failure to persist must not discard a valid remote lease.
      try {
        await cache.write(envelope);
      } catch (_) {/* retain in memory */}
      _envelope = envelope;
      _current = result;
      fallbackReason = null;
    } catch (error) {
      fallbackReason =
          error is ClinicalCatalogInvalid ? error.code : 'remote_unavailable';
      try {
        final envelope = _envelope ?? await cache.read();
        if (envelope != null) {
          _current = ClinicalCatalogValidator.validate(
              envelope, ClinicalCatalogOrigin.cache);
          _requireCoverage(_current!);
          _envelope = envelope;
        } else {
          _current = ClinicalCatalogSnapshot.bundled();
        }
      } catch (_) {
        _current = ClinicalCatalogSnapshot.bundled();
      }
    }
    _checked = clock();
    onRead?.call({
      'activeVersion': _current!.version,
      'contentVersion': _current!.version,
      'schemaVersion': _current!.schemaVersion,
      'source': _current!.origin.name,
      'validationResult': _current!.isBundled ? 'fallback' : 'valid',
      'fallbackReason': fallbackReason
    });
    return _current!;
  }
}
