import 'dart:convert';
import 'dart:io';
import 'clinical_content_contract.dart';
import 'clinical_content_gateway.dart';

/// Native durable store. Use a per-account directory in application support.
/// Immutable generation files + a single atomically replaced journal pointer.
class FileClinicalSnapshotStore implements ClinicalSnapshotStore {
  FileClinicalSnapshotStore(this.directory);
  final Directory directory;
  Future<Map<String, dynamic>?> _pointer() async {
    final file = File('${directory.path}/active.json');
    if (!await file.exists()) return null;
    return contentObject(jsonDecode(await file.readAsString()));
  }

  Future<Map<String, dynamic>?> _generation(Object? hash) async {
    if (hash is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) {
      return null;
    }
    final file = File('${directory.path}/$hash.json');
    try {
      final result = contentObject(jsonDecode(await file.readAsString()));
      return contentHash(result) == hash ? result : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>?> read() async {
    final pointer = await _pointer();
    if (pointer == null) return null;
    final active = await _generation(pointer['active']);
    final snapshot = active ?? await _generation(pointer['previous']);
    requireContent(snapshot != null, 'CACHE_CORRUPT');
    return {
      ...snapshot!,
      'revocationFloor': pointer['revocations'] ?? <String>[],
      'sequenceFloor': pointer['sequence'],
      'recoveredPrevious': active == null
    };
  }

  @override
  Future<void> activate(Map<String, dynamic> snapshot) =>
      serializedContentStoreWrite(
          directory.absolute.path, () => _activate(snapshot));

  Future<void> _activate(Map<String, dynamic> snapshot) async {
    await directory.create(recursive: true);
    final old = await _pointer();
    requireContent(
        old == null || snapshot['manifest']['sequence'] > old['sequence'],
        'STORAGE_SEQUENCE_REPLAY');
    final clean = {...snapshot}
      ..remove('revocationFloor')
      ..remove('sequenceFloor')
      ..remove('recoveredPrevious');
    final hash = contentHash(clean);
    final bytes = jsonEncode(canonicalJson(clean));
    final stage = File('${directory.path}/staged.json');
    await stage.writeAsString(bytes, flush: true);
    requireContent(contentHash(jsonDecode(await stage.readAsString())) == hash,
        'STORAGE_HASH_MISMATCH');
    await stage.rename('${directory.path}/$hash.json');
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
    final pointer = {
      'active': hash,
      'previous': old?['active'],
      'sequence': snapshot['manifest']['sequence'],
      'revocations': revoked.toList()..sort()
    };
    final pending = File('${directory.path}/active.pending');
    await pending.writeAsString(jsonEncode(pointer), flush: true);
    await pending.rename('${directory.path}/active.json');
  }
}
