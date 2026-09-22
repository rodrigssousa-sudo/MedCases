import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'clinical_content_contract.dart';
import 'clinical_content_gateway.dart';

/// Portable durable store, including Web. Each generation is immutable and
/// visibility changes through one preference-key write. Quota failures retain
/// the previous pointer. Use a distinct key per authenticated principal.
class PreferencesClinicalSnapshotStore implements ClinicalSnapshotStore {
  PreferencesClinicalSnapshotStore(this.preferences, this.scopeKey);
  final SharedPreferences preferences;
  final String scopeKey;
  Map<String, dynamic>? _pointer() {
    final text = preferences.getString('$scopeKey.active');
    return text == null ? null : contentObject(jsonDecode(text));
  }

  Map<String, dynamic>? _generation(Object? hash) {
    if (hash is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) {
      return null;
    }
    try {
      final text = preferences.getString('$scopeKey.$hash');
      if (text == null) return null;
      final result = contentObject(jsonDecode(text));
      return contentHash(result) == hash ? result : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>?> read() async {
    await preferences.reload();
    final pointer = _pointer();
    if (pointer == null) return null;
    final active = _generation(pointer['active']);
    final result = active ?? _generation(pointer['previous']);
    requireContent(result != null, 'CACHE_CORRUPT');
    return {
      ...result!,
      'revocationFloor': pointer['revocations'],
      'sequenceFloor': pointer['sequence'],
      'recoveredPrevious': active == null
    };
  }

  @override
  Future<void> activate(Map<String, dynamic> snapshot) =>
      serializedContentStoreWrite(
          'preferences:$scopeKey', () => _activate(snapshot));
  Future<void> _activate(Map<String, dynamic> snapshot) async {
    await preferences.reload();
    final old = _pointer();
    requireContent(
        old == null || snapshot['manifest']['sequence'] > old['sequence'],
        'STORAGE_SEQUENCE_REPLAY');
    final clean = {...snapshot}
      ..remove('revocationFloor')
      ..remove('sequenceFloor')
      ..remove('recoveredPrevious');
    final hash = contentHash(clean);
    requireContent(
        await preferences.setString(
            '$scopeKey.$hash', jsonEncode(canonicalJson(clean))),
        'STORAGE_WRITE_FAILURE');
    requireContent(_generation(hash) != null, 'STORAGE_HASH_MISMATCH');
    final revoked = <String>{
      ...(old?['revocations'] as List? ?? []).cast<String>()
    };
    final items = contentObject(snapshot['items']);
    for (final domain in items.keys) {
      for (final raw in contentObject(items[domain]).values) {
        final item = contentObject(raw);
        if (item['publicationStatus'] == 'REVOKED') {
          revoked.add('$domain/${item['canonicalId']}');
        }
      }
    }
    requireContent(
        await preferences.setString(
            '$scopeKey.active',
            jsonEncode({
              'active': hash,
              'previous': old?['active'],
              'sequence': snapshot['manifest']['sequence'],
              'revocations': revoked.toList()..sort()
            })),
        'STORAGE_ACTIVATION_FAILURE');
  }
}
