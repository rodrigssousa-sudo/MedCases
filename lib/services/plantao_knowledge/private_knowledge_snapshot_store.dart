import 'dart:convert';
import '../private_user_cache.dart';
import '../clinical_content/clinical_content_gateway.dart';
import '../clinical_content/clinical_content_contract.dart';

/// Adapter to the existing encrypted UID cache and snapshot transaction API.
class PrivateKnowledgeSnapshotStore implements ClinicalSnapshotStore {
  PrivateKnowledgeSnapshotStore(this.uid, {PrivateUserCache? cache})
      : cache = cache ?? PrivateUserCache.instance;
  final String uid;
  final PrivateUserCache cache;
  static const _domain = 'clinical_knowledge_snapshot_v1';
  Future<Map<String, dynamic>?> _read() async {
    final value = await cache.read(uid, _domain);
    return value == null ? null : contentObject(jsonDecode(value));
  }

  @override
  Future<Map<String, dynamic>?> read() async {
    final journal = await _read();
    if (journal == null) return null;
    for (final key in ['active', 'previous']) {
      final raw = journal[key];
      if (raw == null) continue;
      final item = contentObject(raw);
      if (item['hash'] == contentHash(item['snapshot']))
        return {
          ...contentObject(item['snapshot']),
          'revocationFloor': journal['revocations'],
          'sequenceFloor': journal['sequence'],
          'recoveredPrevious': key == 'previous'
        };
    }
    throw const ContentFailure('CACHE_CORRUPT');
  }

  @override
  Future<void> activate(Map<String, dynamic> snapshot) =>
      serializedContentStoreWrite('private-knowledge:$uid', () async {
        final old = await _read();
        final sequence = contentObject(snapshot['manifest'])['sequence'];
        requireContent(old == null || sequence > old['sequence'],
            'STORAGE_SEQUENCE_REPLAY');
        final clean = {...snapshot}
          ..remove('revocationFloor')
          ..remove('sequenceFloor')
          ..remove('recoveredPrevious');
        final revoked = <String>{
          ...(old?['revocations'] as List? ?? []).cast<String>()
        };
        final domains = contentObject(snapshot['items']);
        for (final domain in domains.keys) {
          for (final raw in contentObject(domains[domain]).values) {
            final item = contentObject(raw);
            if (item['publicationStatus'] == 'REVOKED')
              revoked.add('$domain/${item['canonicalId']}');
          }
        }
        await cache.write(
            uid,
            _domain,
            jsonEncode({
              'active': {'snapshot': clean, 'hash': contentHash(clean)},
              'previous': old?['active'],
              'sequence': sequence,
              'revocations': revoked.toList()..sort()
            }));
      });
}
