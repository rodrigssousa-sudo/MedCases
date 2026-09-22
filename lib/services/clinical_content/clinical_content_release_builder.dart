import 'clinical_content_contract.dart';

/// Packaging only. Caller must supply publication state from its reviewed
/// publishing workflow. Never writes to a server or changes clinical payloads.
class ClinicalContentReleaseBuilder {
  static Map<String, Map<String, dynamic>> build({
    required Map<String, List<Map<String, dynamic>>> domains,
    required int sequence,
    required String contentVersion,
    required DateTime generatedAt,
    String publicationStatus = 'DRAFT',
    int minimumAppSchema = 1,
  }) {
    requireContent(sequence >= 0, 'SEQUENCE_INVALID');
    requireContent(
        publicationStates.contains(publicationStatus), 'PUBLICATION_INVALID');
    final files = <String, Map<String, dynamic>>{},
        descriptors = <String, dynamic>{};
    for (final domain in domains.keys) {
      requireContent(clinicalDomains.containsKey(domain), 'OWNER_MISMATCH');
      final rows = <Map<String, dynamic>>[];
      final seen = <String>{};
      for (final source in domains[domain]!) {
        final doc = contentObject(canonicalJson(source));
        validateVersionedContent(doc, minimumAppSchema, item: true);
        requireContent(
            seen.add(doc['canonicalId'] as String), 'DUPLICATE_CANONICAL_ID');
        requireContent(
            itemContentHash(doc) == doc['contentHash'], 'ITEM_HASH_MISMATCH');
        validateLanguageParity(contentObject(doc['payload']));
        final path = 'snapshots/$sequence/$domain/${doc['contentHash']}.json';
        files[path] = doc;
        rows.add({
          for (final key in [
            'canonicalId',
            'schemaVersion',
            'contentVersion',
            'contentHash',
            'updatedAt',
            'publicationStatus'
          ])
            key: doc[key],
          'path': path
        });
      }
      rows.sort((a, b) =>
          (a['canonicalId'] as String).compareTo(b['canonicalId'] as String));
      final index = <String, dynamic>{'schemaVersion': '1.0', 'items': rows};
      final path = 'snapshots/$sequence/$domain/index.json';
      files[path] = index;
      descriptors[domain] = {
        'owner': clinicalDomains[domain],
        'schemaVersion': '1.0',
        'contentVersion': contentVersion,
        'contentHash': contentHash(index),
        'generatedAt': generatedAt.toUtc().toIso8601String(),
        'minimumAppSchema': minimumAppSchema,
        'itemCount': rows.length,
        'publicationStatus': publicationStatus,
        'indexPath': path
      };
    }
    files['manifest.json'] = {
      'schemaVersion': '1.0',
      'contentVersion': contentVersion,
      'sequence': sequence,
      'contentHash': contentHash(descriptors),
      'generatedAt': generatedAt.toUtc().toIso8601String(),
      'minimumAppSchema': minimumAppSchema,
      'itemCount': descriptors.length,
      'publicationStatus': publicationStatus,
      'domains': descriptors
    };
    return files;
  }
}
