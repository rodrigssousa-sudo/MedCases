import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'clinical_content_contract.dart';

abstract class ClinicalSnapshotStore {
  Future<Map<String, dynamic>?> read();

  /// Must commit durably and atomically, or throw without changing ACTIVE.
  Future<void> activate(Map<String, dynamic> snapshot);
}

class MemoryClinicalSnapshotStore implements ClinicalSnapshotStore {
  Map<String, dynamic>? _active;
  @override
  Future<Map<String, dynamic>?> read() async => _active;
  @override
  Future<void> activate(Map<String, dynamic> snapshot) async {
    _active = freezeContent(snapshot) as Map<String, dynamic>;
  }
}

class ContentSyncResult {
  const ContentSyncResult(this.activated, this.code, this.downloadedItems);
  final bool activated;
  final String code;
  final int downloadedItems;
}

class ClinicalContentGateway {
  ClinicalContentGateway({
    required this.baseUri,
    required this.store,
    required this.sessionScope,
    required this.currentSessionScope,
    required this.canReadDomain,
    required this.tokenProvider,
    this.canaryAllowed = false,
    this.appSchema = 1,
    this.timeout = const Duration(seconds: 10),
    this.maximumBytes = 8 * 1024 * 1024,
    this.telemetry,
    http.Client? client,
  })  : client = client ?? http.Client(),
        _ownsClient = client == null {
    requireContent(
        baseUri.scheme == 'https' &&
            baseUri.userInfo.isEmpty &&
            !baseUri.hasQuery &&
            !baseUri.hasFragment &&
            baseUri.path.endsWith('/'),
        'INVALID_ORIGIN');
    requireContent(sessionScope.isNotEmpty, 'SESSION_REQUIRED');
  }
  final Uri baseUri;
  final ClinicalSnapshotStore store;
  final String sessionScope;
  final String Function() currentSessionScope;
  final bool Function(String domain) canReadDomain;
  final Future<String> Function() tokenProvider;
  final bool canaryAllowed;
  final int appSchema, maximumBytes;
  final Duration timeout;
  final http.Client client;
  final bool _ownsClient;

  /// Only fixed codes/counters/versions; never clinical payload or request text.
  final void Function(Map<String, Object?> event)? telemetry;
  Map<String, dynamic>? _active;
  Future<ContentSyncResult>? _sync;
  bool _closed = false;
  final _changes = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;
  void Function(String, Map<String, dynamic>)? _modelValidator;
  void registerModelValidator(
      void Function(String, Map<String, dynamic>) validator) {
    final previous = _modelValidator;
    _modelValidator = validator;
    try {
      if (_active != null) _validateSnapshot(_active!);
    } catch (_) {
      _modelValidator = previous;
      rethrow;
    }
  }

  bool hasDomain(String domain) =>
      _active != null &&
      contentObject(contentObject(_active!['manifest'])['domains'])
          .containsKey(domain);
  List<ClinicalContentItem> activeItems(String domain) {
    if (!hasDomain(domain)) return const [];
    return List.unmodifiable(
        contentObject(contentObject(_active!['items'])[domain])
            .keys
            .map((id) => lookup(domain, id))
            .whereType<ClinicalContentItem>());
  }

  void _session() => requireContent(
      !_closed && currentSessionScope() == sessionScope, 'SESSION_CHANGED');
  void _event(String code, {int? count}) {
    final version = activeVersion;
    final activated = DateTime.tryParse('${_active?['activatedAt']}');
    try {
      telemetry?.call({
        'code': code,
        if (count != null) 'itemCount': count,
        if (version != null &&
            RegExp(r'^[a-zA-Z0-9_.-]{1,100}$').hasMatch(version))
          'contentVersion': version,
        if (activated != null)
          'cacheAgeSeconds': DateTime.now()
              .toUtc()
              .difference(activated)
              .inSeconds
              .clamp(0, 2147483647)
      });
    } catch (_) {/* telemetry cannot change safety */}
  }

  bool _eligible(Map<String, dynamic> data) =>
      data['publicationStatus'] == 'PRODUCTION' ||
      (canaryAllowed && data['publicationStatus'] == 'CANARY');

  Future<Map<String, dynamic>> _get(String path) async {
    _session();
    final relative = Uri.tryParse(path);
    requireContent(
        relative != null &&
            !relative.hasScheme &&
            !relative.hasAuthority &&
            !relative.hasQuery &&
            !relative.hasFragment &&
            !path.startsWith('/') &&
            !relative.pathSegments.any((s) => s == '..' || s == '.') &&
            !path.contains('\\'),
        'UNSAFE_PATH');
    final uri = baseUri.resolve(path);
    requireContent(
        uri.origin == baseUri.origin && uri.path.startsWith(baseUri.path),
        'UNSAFE_PATH');
    final token = await tokenProvider().timeout(timeout);
    requireContent(token.trim().isNotEmpty, 'AUTH_REQUIRED');
    _session();
    final request = http.Request('GET', uri)
      ..followRedirects = false
      ..headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Cache-Control': 'no-cache'
      });
    final response = await client.send(request).timeout(timeout);
    _session();
    if (response.statusCode != 200) {
      await response.stream.listen((_) {}).cancel();
      throw ContentFailure(
          response.statusCode == 401 || response.statusCode == 403
              ? 'UNAUTHORIZED'
              : 'HTTP_FAILURE');
    }
    final bytes = <int>[];
    final complete = Completer<void>();
    final subscription = response.stream.listen((chunk) {
      if (complete.isCompleted) return;
      if (bytes.length + chunk.length > maximumBytes) {
        complete.completeError(const ContentFailure('PAYLOAD_TOO_LARGE'));
      } else {
        bytes.addAll(chunk);
      }
    }, onDone: () {
      if (!complete.isCompleted) complete.complete();
    }, onError: (Object error, StackTrace stack) {
      if (!complete.isCompleted) complete.completeError(error, stack);
    });
    try {
      await complete.future.timeout(timeout);
    } finally {
      await subscription.cancel();
    }
    _session();
    return contentObject(jsonDecode(utf8.decode(bytes)));
  }

  void _validateSnapshot(Map<String, dynamic> snapshot) {
    requireContent(snapshot['sessionScopeHash'] == contentHash(sessionScope),
        'CACHE_SCOPE_MISMATCH');
    final manifest = contentObject(snapshot['manifest']);
    validateVersionedContent(manifest, appSchema);
    requireContent(_eligible(manifest), 'UNAUTHORIZED_PUBLICATION');
    requireContent(manifest['sequence'] is int && manifest['sequence'] >= 0,
        'SEQUENCE_INVALID');
    final domains = contentObject(manifest['domains']);
    requireContent(
        manifest['itemCount'] == domains.length &&
            manifest['contentHash'] == contentHash(domains),
        'MANIFEST_HASH_MISMATCH');
    final indexes = contentObject(snapshot['indexes']);
    final items = contentObject(snapshot['items']);
    requireContent(
        indexes.length == domains.length && items.length == domains.length,
        'INCOMPLETE_SNAPSHOT');
    for (final domain in domains.keys) {
      final meta = contentObject(domains[domain]);
      requireContent(
          clinicalDomains[domain] != null &&
              meta['owner'] == clinicalDomains[domain],
          'OWNER_MISMATCH');
      validateVersionedContent(meta, appSchema);
      requireContent(!meta.containsKey('enabled') || meta['enabled'] is bool,
          'INVALID_FEATURE_FLAG');
      requireContent(_eligible(meta), 'UNAUTHORIZED_PUBLICATION');
      final index = contentObject(indexes[domain]);
      requireContent(
          contentHash(index) == meta['contentHash'], 'INDEX_HASH_MISMATCH');
      final rows = index['items'];
      requireContent(
          index['schemaVersion'] == '1.0' &&
              rows is List &&
              rows.length == meta['itemCount'],
          'INCOMPLETE_INDEX');
      final documents = contentObject(items[domain]);
      requireContent(
          documents.length == (rows as List).length, 'INCOMPLETE_SNAPSHOT');
      final seen = <String>{};
      for (final raw in rows) {
        final entry = contentObject(raw);
        validateVersionedContent(entry, appSchema, item: true);
        final id = entry['canonicalId'] as String;
        requireContent(seen.add(id), 'DUPLICATE_CANONICAL_ID');
        final item = contentObject(documents[id]);
        validateVersionedContent(item, appSchema, item: true);
        for (final field in [
          'canonicalId',
          'schemaVersion',
          'contentVersion',
          'contentHash',
          'updatedAt',
          'publicationStatus'
        ]) {
          requireContent(item[field] == entry[field], 'ITEM_INDEX_MISMATCH');
        }
        requireContent(
            itemContentHash(item) == item['contentHash'], 'ITEM_HASH_MISMATCH');
        requireContent(
            _eligible(item) || item['publicationStatus'] == 'REVOKED',
            'UNAUTHORIZED_PUBLICATION');
        validateLanguageParity(contentObject(item['payload']));
        if (item['publicationStatus'] != 'REVOKED') {
          try {
            _modelValidator?.call(domain, item);
          } on ContentFailure {
            rethrow;
          } catch (_) {
            throw const ContentFailure('MODEL_SCHEMA_MISMATCH');
          }
        }
      }
    }
  }

  Future<void> restore() async {
    _session();
    final snapshot = await store.read();
    if (snapshot == null) return;
    _validateSnapshot(snapshot);
    _session();
    _active = freezeContent(snapshot) as Map<String, dynamic>;
    _event('LAST_KNOWN_GOOD_RESTORED');
    if (!_closed) _changes.add(null);
  }

  Future<ContentSyncResult> sync() {
    final pending = _sync;
    if (pending != null) return pending;
    final future = _synchronize();
    _sync = future;
    return future.whenComplete(() => _sync = null);
  }

  Future<ContentSyncResult> _synchronize() async {
    var downloaded = 0;
    try {
      _session();
      if (_active == null) await restore();
      final manifest = await _get('manifest.json');
      validateVersionedContent(manifest, appSchema);
      requireContent(_eligible(manifest), 'UNAUTHORIZED_PUBLICATION');
      final domains = contentObject(manifest['domains']);
      requireContent(manifest['contentHash'] == contentHash(domains),
          'MANIFEST_HASH_MISMATCH');
      if (_active != null) {
        final oldManifest = contentObject(_active!['manifest']);
        requireContent(
            manifest['sequence'] is int &&
                manifest['sequence'] >=
                    (_active!['sequenceFloor'] ?? oldManifest['sequence']),
            'ROLLBACK_REPLAY');
        if (manifest['sequence'] == oldManifest['sequence']) {
          requireContent(contentHash(manifest) == contentHash(oldManifest),
              'SEQUENCE_REUSED');
          return const ContentSyncResult(false, 'UNCHANGED', 0);
        }
        requireContent(
            contentObject(oldManifest['domains'])
                .keys
                .every(domains.containsKey),
            'DOMAIN_REMOVED_WITHOUT_REVOCATION');
      }
      final indexes = <String, dynamic>{}, items = <String, dynamic>{};
      _event('STAGED');
      for (final domain in domains.keys) {
        requireContent(canReadDomain(domain), 'ENTITLEMENT_REQUIRED');
        final meta = contentObject(domains[domain]);
        requireContent(
            meta['owner'] == clinicalDomains[domain] &&
                clinicalDomains.containsKey(domain),
            'OWNER_MISMATCH');
        validateVersionedContent(meta, appSchema);
        requireContent(!meta.containsKey('enabled') || meta['enabled'] is bool,
            'INVALID_FEATURE_FLAG');
        requireContent(_eligible(meta), 'UNAUTHORIZED_PUBLICATION');
        final index = await _get(meta['indexPath'] as String);
        requireContent(
            contentHash(index) == meta['contentHash'], 'INDEX_HASH_MISMATCH');
        requireContent(index['items'] is List, 'INCOMPLETE_INDEX');
        indexes[domain] = index;
        final oldItems = _active == null
            ? <String, dynamic>{}
            : contentObject(contentObject(_active!['items'])[domain] ??
                <String, dynamic>{});
        final docs = <String, dynamic>{};
        for (final raw in index['items']) {
          final entry = contentObject(raw);
          validateVersionedContent(entry, appSchema, item: true);
          final id = entry['canonicalId'] as String;
          requireContent(!docs.containsKey(id), 'DUPLICATE_CANONICAL_ID');
          final old = oldItems[id];
          requireContent(
              (old == null || old['publicationStatus'] != 'REVOKED') &&
                      !((_active?['revocationFloor'] as List? ?? [])
                          .contains('$domain/$id')) ||
                  entry['publicationStatus'] == 'REVOKED',
              'REVOKED_ID_REACTIVATION');
          if (old != null &&
              old['contentVersion'] == entry['contentVersion'] &&
              old['contentHash'] == entry['contentHash']) {
            docs[id] = old;
          } else {
            docs[id] = await _get(entry['path'] as String);
            downloaded++;
          }
        }
        requireContent(
            oldItems.keys.every(docs.containsKey), 'MISSING_TOMBSTONE');
        items[domain] = docs;
      }
      final staged = <String, dynamic>{
        'manifest': manifest,
        'sessionScopeHash': contentHash(sessionScope),
        'indexes': indexes,
        'items': items,
        'activatedAt': DateTime.now().toUtc().toIso8601String()
      };
      _validateSnapshot(staged);
      _event('VALIDATED');
      _session();
      requireContent(domains.keys.every(canReadDomain), 'ENTITLEMENT_REQUIRED');
      await store.activate(staged);
      _session();
      _active = freezeContent(staged) as Map<String, dynamic>;
      _event('ACTIVE', count: downloaded);
      if (!_closed) _changes.add(null);
      return ContentSyncResult(true, 'ACTIVE', downloaded);
    } catch (error) {
      final code = error is ContentFailure
          ? error.code
          : error is TimeoutException
              ? 'TIMEOUT'
              : 'TRANSPORT_OR_STORAGE_FAILURE';
      _event(code);
      if (_active != null) _event('ROLLBACK');
      _event('RETAIN_LAST_KNOWN_GOOD');
      return ContentSyncResult(false, code, downloaded);
    }
  }

  ClinicalContentItem? lookup(String domain, String id) {
    try {
      _session();
      requireContent(canReadDomain(domain), 'ENTITLEMENT_REQUIRED');
      requireContent(canonicalContentId.hasMatch(id), 'INVALID_CANONICAL_ID');
      final active = _active;
      if (active == null) return null;
      final meta =
          contentObject(contentObject(active['manifest'])['domains'])[domain];
      if (meta == null || meta['enabled'] == false) return null;
      if ((active['revocationFloor'] as List? ?? []).contains('$domain/$id')) {
        return null;
      }
      final item = contentObject(active['items'])[domain]?[id];
      if (item == null || item['publicationStatus'] == 'REVOKED') return null;
      requireContent(
          _eligible(contentObject(item)), 'UNAUTHORIZED_PUBLICATION');
      return ClinicalContentItem(contentObject(item));
    } on ContentFailure catch (error) {
      _event(error.code);
      return null;
    }
  }

  String? get activeVersion =>
      _active?['manifest']['contentVersion'] as String?;
  void close() {
    if (_closed) return;
    _closed = true;
    _changes.close();
    if (_ownsClient) client.close();
    _active = null;
  }
}

class ClinicalDomainResolver {
  const ClinicalDomainResolver(this.gateway, this.domain);
  final ClinicalContentGateway gateway;
  final String domain;
  ClinicalContentItem? lookup(String canonicalId) =>
      gateway.lookup(domain, canonicalId);
  List<ClinicalContentItem> relevantItems(Iterable<String> exactIds,
      {int limit = 8}) {
    requireContent(limit >= 0 && limit <= 32, 'RETRIEVAL_LIMIT');
    return List.unmodifiable(exactIds
        .toSet()
        .take(limit)
        .map(lookup)
        .whereType<ClinicalContentItem>());
  }
}

class GuideResolver extends ClinicalDomainResolver {
  const GuideResolver(ClinicalContentGateway gateway)
      : super(gateway, 'guides');
}

class ProtocolResolver extends ClinicalDomainResolver {
  const ProtocolResolver(ClinicalContentGateway gateway)
      : super(gateway, 'protocols');
}

class CaseResolver extends ClinicalDomainResolver {
  const CaseResolver(ClinicalContentGateway gateway) : super(gateway, 'cases');
}

class ReferenceResolver extends ClinicalDomainResolver {
  const ReferenceResolver(ClinicalContentGateway gateway)
      : super(gateway, 'references');
}

// Serialize writers sharing a store inside one runtime/isolate. Each generation
// and pointer is also flushed by durable stores before becoming visible.
final _contentStoreWrites = <String, Future<void>>{};
Future<void> serializedContentStoreWrite(
    String key, Future<void> Function() write) async {
  final previous = _contentStoreWrites[key];
  final done = Completer<void>();
  _contentStoreWrites[key] = done.future;
  try {
    if (previous != null) await previous;
    await write();
  } finally {
    done.complete();
    if (identical(_contentStoreWrites[key], done.future)) {
      _contentStoreWrites.remove(key);
    }
  }
}
