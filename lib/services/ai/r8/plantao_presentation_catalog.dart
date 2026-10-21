import 'dart:convert';
import '../../../models/canonical_clinical_snapshot.dart';
import '../../../models/plantao_presentation_contract.dart';
import '../../../models/plantao_catalog_presentation.dart';
import '../../clinical_catalog/clinical_catalog_presentation_remote.dart';

/// Display-only, exact immutable document matching. Never used for admission,
/// clinical inference, request binding, entitlement or persistence authorization.
abstract final class PlantaoPresentationCatalog {
  static final Map<String, PlantaoPresentationContract> _remote = {};
  static final Map<String, String> _ownerHashes = {};

  /// History is only a lookup hint. Approval and presentation come exclusively
  /// from the current hash-verified catalog, never from stored message fields.
  static Future<void> restoreHistoryPresentations(
      List<Map<String, dynamic>> exchanges,
      ClinicalCatalogRemote remote) async {
    // An older integral-only exchange must not inherit another conversation's
    // cached compact view merely because its source bytes are identical.
    for (final e in exchanges) {
      if (e['mode'] == 'plantao' && e['assistantOutput'] is String) {
        _remote
            .remove(PlantaoPresentationContract.textHash(e['assistantOutput']));
      }
    }
    final candidates = exchanges
        .where((e) =>
            e['mode'] == 'plantao' &&
            e['clinicalProtocol'] is Map &&
            e['clinicalPresentation'] is Map &&
            e['assistantOutput'] is String)
        .toList();
    if (candidates.isEmpty) return;
    // Invalidate cached executive authority even if the fresh read fails.
    for (final e in candidates) {
      _remote
          .remove(PlantaoPresentationContract.textHash(e['assistantOutput']));
    }
    try {
      final pointer = await remote.pointer();
      final version = pointer['activeVersion'];
      if (pointer['status'] != 'ACTIVE' || version is! String) return;
      final manifest = await remote.manifest(version);
      if (CanonicalClinicalSnapshot.hash(manifest) != pointer['manifestSha256']) {
        return;
      }
      final registry = manifest['clinicalReleaseRegistry'];
      if (registry is! Map ||
          registry['executives'] is! List ||
          registry['approvedSources'] is! List ||
          manifest['chunks'] is! List) {
        return;
      }
      final identities = <Map>[];
      for (final chunk in manifest['chunks']) {
        if (chunk['collection'] != 'clinical_identity_registry') continue;
        final raw = await remote.chunk(version, chunk['id']);
        if (PlantaoPresentationContract.textHash(raw) != chunk['sha256']) {
          return;
        }
        identities.addAll((jsonDecode(raw) as List).cast<Map>());
      }
      final accepted = <String, PlantaoPresentationContract>{};
      final integralOnly = exchanges
          .where((e) =>
              e['mode'] == 'plantao' &&
              e['assistantOutput'] is String &&
              e['clinicalPresentation'] is! Map)
          .map(
              (e) => PlantaoPresentationContract.textHash(e['assistantOutput']))
          .toSet();
      for (final exchange in candidates) {
        final ref = exchange['clinicalProtocol'] as Map;
        final locale = exchange['locale'];
        final fullText = exchange['assistantOutput'] as String;
        if (integralOnly
            .contains(PlantaoPresentationContract.textHash(fullText))) {
          continue;
        }
        final matches = (registry['executives'] as List)
            .where((e) =>
                e is Map && e['owner'] == ref['owner'] && e['locale'] == locale)
            .toList();
        final sources = (registry['approvedSources'] as List)
            .where((s) => s is Map && s['owner'] == ref['owner'])
            .toList();
        final owners = identities
            .where((i) =>
                (i['canonicalKey'] ?? i['canonicalPathologyKey']) ==
                ref['owner'])
            .toList();
        if (sources.length != 1 || owners.length != 1) continue;
        final source = sources.single as Map;
        final recorded = exchange['clinicalPresentation'];
        if (recorded is! Map) continue;
        final identity = owners.single;
        if (identity['enabled'] != true ||
            identity['version'] != ref['version'] ||
            identity['approvedClinicalPayloadSha256'] != ref['payloadSha256'] ||
            source['version'] != ref['version'] ||
            source['payloadSha256'] != ref['payloadSha256'] ||
            source['languages'] is! List ||
            !(source['languages'] as List).contains(locale)) {
          continue;
        }
        if (recorded['kind'] == 'LOSSLESS_AUTHORIZED_SOURCE_LAYOUT') {
          // Re-derive only from the current authenticated source. Stored text
          // and metadata are lookup hints, never a new approval authority.
          final descriptors = (manifest['chunks'] as List)
              .where((c) =>
                  c['id'] == source['chunkId'] &&
                  c['collection'] == 'clinical_projection_registry')
              .toList();
          if (descriptors.length != 1) continue;
          final raw = await remote.chunk(version, source['chunkId']);
          if (PlantaoPresentationContract.textHash(raw) !=
              descriptors.single['sha256']) {
            continue;
          }
          final rows = (jsonDecode(raw) as List)
              .where((r) =>
                  r['contentKey'] == source['sourceKey'] &&
                  r['enabled'] == true &&
                  r['canonicalPathologyKey'] == ref['owner'] &&
                  r['version'] == ref['version'] &&
                  r['approvedClinicalPayloadSha256'] == ref['payloadSha256'])
              .toList();
          if (rows.length != 1) continue;
          final payload = rows.single['payload'];
          try {
            final protocol = <String, dynamic>{
              ...Map<String, dynamic>.from(source),
              'scope': 'UNCHANGED_GENERAL_PROTOCOL_NOT_INDIVIDUAL_PRESCRIPTION',
              'approvedClinicalPayloadJson':
                  payload['approvedClinicalPayloadJson'],
              'approvedProjections': {
                for (final l in ['pt', 'es'])
                  l: payload[l]['plantaoProjection']['markdown']
              },
            };
            final selected = PlantaoPresentationContract.fromApprovedSource(
                protocol,
                expectedSourceHash: ref['payloadSha256'],
                locale: locale,
                allowLosslessLayout: true);
            if (!selected.hasLosslessSourceLayout ||
                selected.fullText != fullText ||
                selected.contentHash != recorded['contentHash'] ||
                CanonicalClinicalSnapshot.hash(selected.data) !=
                    CanonicalClinicalSnapshot.hash(recorded['presentation'])) {
              continue;
            }
            accepted[PlantaoPresentationContract.textHash(fullText)] = selected;
          } on FormatException {
            /* Keep immutable integral on invalid source. */
          }
          continue;
        }
        if (matches.length != 1) continue;
        final e = matches.single as Map;
        // Reopening must not silently substitute a newer executive.
        if (recorded['contentHash'] != e['contentHash'] ||
            e['sourceVersion'] != ref['version']) {
          continue;
        }
        final review = e['review'], presentation = e['presentation'];
        if (review is! Map ||
            presentation is! Map ||
            review['status'] != 'APPROVED' ||
            review['contentHash'] != e['contentHash'] ||
            !['recordId', 'reviewerId', 'reviewedAt'].every((k) =>
                review[k] is String &&
                (review[k] as String).trim().isNotEmpty) ||
            !RegExp(r'^[a-f0-9]{64}$')
                .hasMatch(review['evidenceSha256']?.toString() ?? '')) {
          continue;
        }
        try {
          final selected = PlantaoPresentationContract.fromCatalog(
              Map<String, dynamic>.from(presentation),
              expectedHash: e['contentHash'] as String);
          if (!selected.isExecutive ||
              selected.locale != locale ||
              selected.fullText != fullText ||
              selected.data['sourceVersion'] != ref['version'] ||
              selected.data['fullProtocolRef']['id'] != ref['owner'] ||
              selected.data['clinicalApproval']['recordId'] !=
                  review['recordId']) {
            continue;
          }
          accepted[PlantaoPresentationContract.textHash(fullText)] = selected;
        } on FormatException {
          /* Preserve original history, never repair approval. */
        }
      }
      final after = await remote.pointer();
      if (after['status'] != 'ACTIVE' ||
          after['activeVersion'] != version ||
          after['manifestSha256'] != pointer['manifestSha256']) {
        return;
      }
      _remote.addAll(accepted);
    } catch (_) {
      // Read failures never discard messages or promote unverified history data.
    }
  }

  /// Called only after authenticated transport, exact text and request ownership
  /// checks in Provider. History strings cannot register their own approval.
  static PlantaoPresentationContract? acceptValidatedProtocol(
      CanonicalClinicalSnapshot snapshot, String locale) {
    final source = snapshot.approvedProtocolData;
    // Authenticated external evidence remains a reference, never an approved
    // MedCases presentation. Do not register it in the protocol/hash cache.
    if (source == null && snapshot.isReferenceDocument) return null;
    if (source == null) throw const FormatException('not_approved_protocol');
    final envelope = source['presentationEnvelope'];
    var full = PlantaoPresentationContract.fromApprovedSource(source,
        expectedSourceHash: snapshot.factsHash,
        locale: locale,
        allowLosslessLayout: envelope is Map &&
            envelope['kind'] == 'LOSSLESS_AUTHORIZED_SOURCE_LAYOUT');
    if (full.hasLosslessSourceLayout &&
        (envelope is! Map ||
            envelope['contentHash'] != full.contentHash ||
            CanonicalClinicalSnapshot.hash(envelope['presentation']) !=
                CanonicalClinicalSnapshot.hash(full.data))) {
      full = PlantaoPresentationContract.fromApprovedSource(source,
          expectedSourceHash: snapshot.factsHash, locale: locale);
    }
    var selected = full;
    if (envelope is Map &&
        envelope['presentation'] is Map &&
        envelope['contentHash'] is String) {
      try {
        selected = const PlantaoCatalogPresentation().select(
            full: full.data,
            fullCatalogHash: full.contentHash,
            executive: Map<String, dynamic>.from(envelope['presentation']),
            executiveCatalogHash: envelope['contentHash'] as String);
      } on FormatException {
        /* Keep verified FULL, never repair an executive. */
      }
    }
    final key = '${source['owner']}:$locale';
    final content = PlantaoPresentationContract.textHash(full.fullText);
    final old = _ownerHashes[key];
    if (old != null && old != content) _remote.remove(old);
    _ownerHashes[key] = content;
    _remote[content] = selected;
    return selected;
  }

  static PlantaoPresentationContract? resolve(String text, String locale) {
    if (!['pt', 'es'].contains(locale)) return null;
    final hash = PlantaoPresentationContract.textHash(text);
    final remote = _remote[hash];
    if (remote != null && remote.locale == locale) return remote;
    return null; // No unreviewed local pins or saved-history approvals.
  }
}
