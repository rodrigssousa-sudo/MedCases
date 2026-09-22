import 'dart:convert';
import 'dart:io';
import 'package:medcases/services/clinical_content/clinical_content_platform.dart';
import 'package:medcases/services/clinical_guides_editorial_service.dart';
import 'package:medcases/services/ai_pipeline/plantao/adapters/plantao_canonical_catalog_readonly_resolver.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medcases/services/clinical_content/clinical_snapshot_preferences_store.dart';
import 'package:medcases/services/clinical_content/clinical_content_release_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medcases/services/clinical_content/clinical_content_contract.dart';
import 'package:medcases/services/clinical_content/clinical_content_gateway.dart';
import 'package:medcases/services/clinical_content/clinical_snapshot_file_store.dart';

Map<String, dynamic> item(String id,
    {String version = '1', String status = 'PRODUCTION'}) {
  final x = <String, dynamic>{
    'canonicalId': id,
    'schemaVersion': '1.0',
    'contentVersion': version,
    'updatedAt': '2026-09-21T00:00:00Z',
    'publicationStatus': status,
    'payload': status == 'REVOKED'
        ? <String, dynamic>{}
        : {
            'pt': {
              'sections': ['reference'],
              'references': ['ref']
            },
            'es': {
              'sections': ['referencia'],
              'references': ['ref']
            },
            'calculationAuthorized': false
          }
  };
  x['contentHash'] = itemContentHash(x);
  return x;
}

Map<String, Map<String, dynamic>> release(
    Map<String, List<Map<String, dynamic>>> domains,
    {int sequence = 1,
    String status = 'PRODUCTION'}) {
  final responses = <String, Map<String, dynamic>>{},
      meta = <String, dynamic>{};
  for (final domain in domains.keys) {
    final rows = <Map<String, dynamic>>[];
    for (final doc in domains[domain]!) {
      final path = 'snapshots/$sequence/$domain/${doc['canonicalId']}.json';
      responses[path] = doc;
      rows.add({...doc}
        ..remove('payload')
        ..['path'] = path);
    }
    final index = {'schemaVersion': '1.0', 'items': rows};
    final path = 'snapshots/$sequence/$domain/index.json';
    responses[path] = index;
    meta[domain] = {
      'owner': clinicalDomains[domain],
      'schemaVersion': '1.0',
      'contentVersion': '$sequence',
      'contentHash': contentHash(index),
      'itemCount': rows.length,
      'generatedAt': '2026-09-21T00:00:00Z',
      'minimumAppSchema': 1,
      'publicationStatus': status,
      'indexPath': path
    };
  }
  responses['manifest.json'] = {
    'schemaVersion': '1.0',
    'contentVersion': '$sequence',
    'sequence': sequence,
    'contentHash': contentHash(meta),
    'generatedAt': '2026-09-21T00:00:00Z',
    'minimumAppSchema': 1,
    'publicationStatus': status,
    'itemCount': meta.length,
    'domains': meta
  };
  return responses;
}

class BrokenStore extends MemoryClinicalSnapshotStore {
  bool fail = false;
  @override
  Future<void> activate(Map<String, dynamic> snapshot) async {
    if (fail) throw StateError('disk');
    await super.activate(snapshot);
  }
}

void main() {
  late Map<String, Map<String, dynamic>> server;
  late List<String> requests;
  late List<Map<String, Object?>> events;
  late String session;
  late bool entitled;
  late ClinicalContentGateway gateway;
  ClinicalContentGateway make(
          {ClinicalSnapshotStore? store,
          bool canary = false,
          Duration? timeout,
          http.Client? client}) =>
      ClinicalContentGateway(
          baseUri: Uri.parse('https://content.example/v1/'),
          store: store ?? MemoryClinicalSnapshotStore(),
          sessionScope: 'user_a',
          currentSessionScope: () => session,
          canReadDomain: (_) => entitled,
          tokenProvider: () async => 'token',
          canaryAllowed: canary,
          telemetry: events.add,
          timeout: timeout ?? const Duration(seconds: 1),
          client: client ??
              MockClient((req) async {
                expect(req.headers['Authorization'], 'Bearer token');
                final path = req.url.path.substring('/v1/'.length);
                requests.add(path);
                final data = server[path];
                return http.Response(jsonEncode(data), data == null ? 404 : 200,
                    headers: {
                      'content-type': 'application/json; charset=utf-8'
                    });
              }));
  setUp(() {
    server = release({
      'guides': [item('a')]
    });
    requests = [];
    events = [];
    session = 'user_a';
    entitled = true;
    gateway = make();
  });
  tearDown(() => gateway.close());
  test('valid manifest, compatible schema, correct hash activates', () async {
    expect((await gateway.sync()).activated, isTrue);
    expect(gateway.activeVersion, '1');
  });
  for (final mutation in [
    'schema',
    'minimum',
    'hash',
    'count',
    'id',
    'draft',
    'owner'
  ]) {
    test('reject $mutation without replacing last known good', () async {
      await gateway.sync();
      server = release({
        'guides': [item('a', version: '2')]
      }, sequence: 2);
      final manifest = server['manifest.json']!;
      switch (mutation) {
        case 'schema':
          manifest['schemaVersion'] = '2.0';
        case 'minimum':
          manifest['minimumAppSchema'] = 2;
        case 'hash':
          manifest['contentHash'] = '0' * 64;
        case 'count':
          manifest['itemCount'] = 99;
        case 'id':
          server = release({
            'guides': [item('../bad')]
          }, sequence: 2);
        case 'draft':
          server = release({
            'guides': [item('a', status: 'DRAFT')]
          }, sequence: 2);
        case 'owner':
          manifest['domains']['guides']['owner'] = 'other';
          manifest['contentHash'] = contentHash(manifest['domains']);
      }
      expect((await gateway.sync()).activated, isFalse);
      expect(gateway.activeVersion, '1');
      expect(gateway.lookup('guides', 'a'), isNotNull);
    });
  }
  test('partial snapshot cannot activate; automatic rollback retains prior',
      () async {
    await gateway.sync();
    server = release({
      'guides': [item('a'), item('b')]
    }, sequence: 2);
    server.remove('snapshots/2/guides/b.json');
    expect((await gateway.sync()).activated, isFalse);
    expect(gateway.lookup('guides', 'b'), isNull);
    expect(gateway.activeVersion, '1');
  });
  test('delta downloads only new and changed items', () async {
    await gateway.sync();
    requests.clear();
    server = release({
      'guides': [item('a'), item('b')]
    }, sequence: 2);
    expect((await gateway.sync()).downloadedItems, 1);
    expect(requests.contains('snapshots/2/guides/a.json'), isFalse);
    server = release({
      'guides': [item('a', version: '2'), item('b')]
    }, sequence: 3);
    expect((await gateway.sync()).downloadedItems, 1);
  });
  test('revocation hides and prevents resurrection', () async {
    await gateway.sync();
    server = release({
      'guides': [item('a', version: '2', status: 'REVOKED')]
    }, sequence: 2);
    expect((await gateway.sync()).activated, isTrue);
    expect(gateway.lookup('guides', 'a'), isNull);
    server = release({
      'guides': [item('a', version: '3')]
    }, sequence: 3);
    expect((await gateway.sync()).code, 'REVOKED_ID_REACTIVATION');
  });
  test('deletion requires tombstone', () async {
    await gateway.sync();
    server = release({'guides': []}, sequence: 2);
    expect((await gateway.sync()).code, 'MISSING_TOMBSTONE');
  });
  test('replay rejected, forward rollback release supported', () async {
    await gateway.sync();
    server = release({
      'guides': [item('a', version: '2')]
    }, sequence: 2);
    await gateway.sync();
    server = release({
      'guides': [item('a')]
    });
    expect((await gateway.sync()).code, 'ROLLBACK_REPLAY');
    server = release({
      'guides': [item('a')]
    }, sequence: 3);
    expect((await gateway.sync()).activated, isTrue);
  });
  test('network failure retains last known good', () async {
    await gateway.sync();
    server.clear();
    expect((await gateway.sync()).activated, isFalse);
    expect(gateway.lookup('guides', 'a'), isNotNull);
  });
  test('timeout produces structured failure', () async {
    final slow = make(
        timeout: const Duration(milliseconds: 1),
        client: MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return http.Response('{}', 200);
        }));
    expect((await slow.sync()).code, 'TIMEOUT');
    slow.close();
  });
  test('atomic storage error cannot activate in memory', () async {
    final store = BrokenStore();
    final g = make(store: store);
    await g.sync();
    store.fail = true;
    server = release({
      'guides': [item('a', version: '2')]
    }, sequence: 2);
    expect((await g.sync()).activated, isFalse);
    expect(g.activeVersion, '1');
    g.close();
  });
  for (final domain in [
    'guides',
    'drugs',
    'protocols',
    'cases',
    'references'
  ]) {
    test('$domain exact lookup; bounded relevant retrieval; no authority',
        () async {
      server = release({
        domain: [item('a')]
      });
      await gateway.sync();
      final resolver = ClinicalDomainResolver(gateway, domain);
      final doc = resolver.lookup('a')!;
      expect(doc.catalogVisible, isTrue);
      expect(doc.clinicalAuthority, isFalse);
      expect(doc.doseAuthority, isFalse);
      expect(doc.calculationAuthorized, isFalse);
      expect(doc.infusionAuthority, isFalse);
      expect(doc.infusionBindingStatus, 'FAIL_CLOSED_UNRESOLVED_BINDING');
      expect(resolver.lookup('A'), isNull);
      expect(resolver.lookup(' a'), isNull);
      expect(resolver.relevantItems(['a', 'a', 'unknown']).length, 1);
    });
  }
  test('PT ES structural parity rejects missing clinical section', () async {
    final bad = item('a');
    bad['payload']['es'].remove('sections');
    bad['contentHash'] = itemContentHash(bad);
    server = release({
      'guides': [bad]
    });
    expect((await gateway.sync()).code, 'PT_ES_STRUCTURE');
  });
  test('PT ES references must agree', () async {
    final bad = item('a');
    bad['payload']['es']['references'] = ['other'];
    bad['contentHash'] = itemContentHash(bad);
    server = release({
      'guides': [bad]
    });
    expect((await gateway.sync()).code, 'PT_ES_references');
  });
  test('payload tampering fails hash verification', () async {
    server['snapshots/1/guides/a.json']!['payload']['extra'] = 'tampered';
    expect((await gateway.sync()).code, 'ITEM_HASH_MISMATCH');
  });
  test('remote flags cannot disable mandatory safety', () async {
    final raw = item('a');
    raw['payload']['safetyDisabled'] = true;
    raw['payload']['calculationAuthorized'] = true;
    raw['contentHash'] = itemContentHash(raw);
    server = release({
      'guides': [raw]
    });
    await gateway.sync();
    expect(gateway.lookup('guides', 'a')!.calculationAuthorized, isFalse);
  });
  test('canary excluded from general release; explicit cohort required',
      () async {
    server = release({
      'guides': [item('a', status: 'CANARY')]
    }, status: 'CANARY');
    expect((await gateway.sync()).activated, isFalse);
    final canary = make(canary: true);
    expect((await canary.sync()).activated, isTrue);
    canary.close();
  });
  test('entitlement checked at sync and offline lookup', () async {
    await gateway.sync();
    entitled = false;
    expect(gateway.lookup('guides', 'a'), isNull);
    server = release({
      'guides': [item('a')]
    }, sequence: 2);
    expect((await gateway.sync()).code, 'ENTITLEMENT_REQUIRED');
  });
  test('account switch cannot reuse cache', () async {
    await gateway.sync();
    session = 'user_b';
    expect(gateway.lookup('guides', 'a'), isNull);
    expect((await gateway.sync()).code, 'SESSION_CHANGED');
  });
  test('last known good survives new gateway instance', () async {
    final store = MemoryClinicalSnapshotStore();
    final a = make(store: store);
    await a.sync();
    a.close();
    final b = make(store: store);
    server.clear();
    await b.restore();
    expect(b.lookup('guides', 'a'), isNotNull);
    b.close();
  });
  test('disk activation and corruption rollback never resurrect revocation',
      () async {
    final dir =
        await Directory.systemTemp.createTemp('clinical_snapshot_test_');
    try {
      final store = FileClinicalSnapshotStore(dir);
      final a = make(store: store);
      await a.sync();
      server = release({
        'guides': [item('a', version: '2', status: 'REVOKED')]
      }, sequence: 2);
      await a.sync();
      a.close();
      final pointer =
          jsonDecode(await File('${dir.path}/active.json').readAsString());
      await File('${dir.path}/${pointer['active']}.json')
          .writeAsString('corrupt');
      final b = make(store: store);
      await b.restore();
      expect(b.lookup('guides', 'a'), isNull);
      b.close();
    } finally {
      await dir.delete(recursive: true);
    }
  });
  test('telemetry contains no payload or request text', () async {
    await gateway.sync();
    expect(
        events.every((e) => e.keys.every([
              'code',
              'itemCount',
              'contentVersion',
              'cacheAgeSeconds'
            ].contains)),
        isTrue);
  });
  test(
      'publication builder derives counts; future additions need no app migration',
      () async {
    server = ClinicalContentReleaseBuilder.build(
        domains: {
          'guides': [item('a')]
        },
        sequence: 1,
        contentVersion: 'one',
        generatedAt: DateTime.utc(2026),
        publicationStatus: 'PRODUCTION');
    expect((await gateway.sync()).activated, isTrue);
    server = ClinicalContentReleaseBuilder.build(
        domains: {
          'guides': [item('a'), item('new_compatible_id')]
        },
        sequence: 2,
        contentVersion: 'two',
        generatedAt: DateTime.utc(2026),
        publicationStatus: 'PRODUCTION');
    expect(server['manifest.json']!['domains']['guides']['itemCount'], 2);
    expect((await gateway.sync()).downloadedItems, 1);
    expect(gateway.lookup('guides', 'new_compatible_id'), isNotNull);
  });
  test('publication builder defaults to draft and does not rewrite payload',
      () {
    final original = item('a');
    final before = jsonEncode(original);
    final files = ClinicalContentReleaseBuilder.build(domains: {
      'guides': [original]
    }, sequence: 1, contentVersion: 'one', generatedAt: DateTime.utc(2026));
    expect(files['manifest.json']!['publicationStatus'], 'DRAFT');
    expect(jsonEncode(original), before);
  });
  test('portable cache restores offline and rejects scope reuse', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store =
        PreferencesClinicalSnapshotStore(preferences, 'account_scope');
    final a = make(store: store);
    await a.sync();
    a.close();
    final b = make(store: store);
    await b.restore();
    expect(b.lookup('guides', 'a'), isNotNull);
    b.close();
    session = 'user_b';
    final other = ClinicalContentGateway(
        baseUri: Uri.parse('https://content.example/v1/'),
        store: store,
        sessionScope: 'user_b',
        currentSessionScope: () => session,
        canReadDomain: (_) => true,
        tokenProvider: () async => 'token');
    await expectLater(other.restore(), throwsA(isA<ContentFailure>()));
    other.close();
  });
  test('remote content disable does not alter authority gates', () async {
    final manifest = server['manifest.json']!;
    manifest['domains']['guides']['enabled'] = false;
    manifest['contentHash'] = contentHash(manifest['domains']);
    expect((await gateway.sync()).activated, isTrue);
    expect(gateway.lookup('guides', 'a'), isNull);
  });
  test('unauthorized response has no public downgrade', () async {
    final denied =
        make(client: MockClient((_) async => http.Response('{}', 403)));
    expect((await denied.sync()).code, 'UNAUTHORIZED');
    denied.close();
  });
  test('path traversal and external index cannot receive token', () async {
    final manifest = server['manifest.json']!;
    manifest['domains']['guides']['indexPath'] =
        'https://other.example/index.json';
    manifest['contentHash'] = contentHash(manifest['domains']);
    expect((await gateway.sync()).code, 'UNSAFE_PATH');
    expect(requests, ['manifest.json']);
  });
  test('redirect is rejected rather than forwarding credentials', () async {
    final redirect = make(client: MockClient((request) async {
      expect(request.followRedirects, isFalse);
      return http.Response('', 302,
          headers: {'location': 'https://other.example/'});
    }));
    expect((await redirect.sync()).code, 'HTTP_FAILURE');
    redirect.close();
  });
  test('closed gateway cannot reactivate or return cached content', () async {
    await gateway.sync();
    gateway.close();
    expect(gateway.lookup('guides', 'a'), isNull);
    expect((await gateway.sync()).code, 'SESSION_CHANGED');
  });
  test('drug bridge uses LKG and cannot resurrect revoked ID online', () async {
    final doc = item('insulina_regular');
    doc['payload'] = {
      'id': 'insulina_regular',
      'name': {'pt': 'Reference', 'es': 'Referencia'}
    };
    doc['contentHash'] = itemContentHash(doc);
    server = release({
      'drugs': [doc]
    });
    await gateway.sync();
    final bridge = DrugResolver(
        gateway,
        PlantaoCanonicalCatalogReadOnlyResolver(
            loadObject: (_) async => throw StateError('must not go online')));
    expect(
        (await bridge.lookup('insulina_regular'))!.infusionAuthority, isFalse);
    expect((await bridge.loadIndex()).length, 1);
    server = release({
      'drugs': [item('insulina_regular', version: '2', status: 'REVOKED')]
    }, sequence: 2);
    await gateway.sync();
    expect(await bridge.lookup('insulina_regular'), isNull);
    expect(await bridge.loadIndex(), isEmpty);
  });
  test(
      'guide service reads validated snapshot and honors revocation without Firebase fallback',
      () async {
    final doc = item('guide_a');
    doc['payload'] = {
      'title': 'Reference',
      'language': 'es',
      'bodyBlocks': [],
      'references': [],
      'isPublished': true
    };
    doc['contentHash'] = itemContentHash(doc);
    server = release({
      'guides': [doc]
    });
    await gateway.sync();
    ClinicalGuidesEditorialService.configureRemoteGateway(gateway);
    expect((await ClinicalGuidesEditorialService.loadPublished()).length, 1);
    expect((await ClinicalGuidesEditorialService.watchPublished().first).length,
        1);
    expect((await ClinicalGuidesEditorialService.loadById('guide_a'))!.id,
        'guide_a');
    server = release({
      'guides': [item('guide_a', version: '2', status: 'REVOKED')]
    }, sequence: 2);
    await gateway.sync();
    expect(await ClinicalGuidesEditorialService.loadPublished(), isEmpty);
    expect(await ClinicalGuidesEditorialService.loadById('guide_a'), isNull);
  });
  test('concurrent sync coalesces network work', () async {
    final results = await Future.wait([gateway.sync(), gateway.sync()]);
    expect(results.every((r) => r.activated), isTrue);
    expect(requests.where((p) => p == 'manifest.json').length, 1);
  });
}
