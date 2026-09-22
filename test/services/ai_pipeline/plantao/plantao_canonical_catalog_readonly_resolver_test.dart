import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medcases/services/ai_pipeline/plantao/adapters/plantao_versioned_remote_drug_evidence_json_loader.dart';

void main() {
  const fixtures = 'test/fixtures/ai_canonical_catalog';
  Map<String, Object?> object(String name) =>
      jsonDecode(File('$fixtures/$name.json').readAsStringSync())
          as Map<String, Object?>;
  late Map<String, Object?> catalog;
  late List<String> requests;
  late PlantaoVersionedRemoteDrugEvidenceJsonLoader loader;
  setUp(() {
    catalog = object('catalog');
    requests = [];
    loader = PlantaoVersionedRemoteDrugEvidenceJsonLoader(
      authorizationTokenProvider: () async => 'test-session',
      client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer test-session');
        expect(request.headers['Cache-Control'], 'no-cache');
        expect(request.method, 'GET');
        requests.add(request.url.path);
        if (request.url.path == '/api/drug-catalog') {
          return http.Response(jsonEncode(catalog), 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }
        final id = request.url.path.split('/').last;
        final fixture = File('$fixtures/$id.json');
        final file = fixture.existsSync()
            ? fixture
            : File(
                '/private/tmp/medcases-calculadora-r1-canonical-20260921/data/drugs/$id.json');
        return http.Response(
            jsonEncode(
                {'ok': true, 'drug': jsonDecode(file.readAsStringSync())}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }),
    );
  });
  tearDown(() => loader.close());
  test('Free60 exact detail skips the Premium full index', () async {
    final result = await loader.canonicalCatalog.lookup('acetilcisteina');
    expect(result?.canonicalDrugId, 'acetilcisteina');
    expect(requests, ['/api/drugs/acetilcisteina']);
  });
  test('1018 canonical IDs, 838 retained, 180 added, zero removed or invented',
      () async {
    final index = await loader.canonicalCatalog.loadIndex();
    final old =
        (jsonDecode(File('$fixtures/before-ids.json').readAsStringSync())
                as List)
            .cast<String>()
            .toSet();
    final canonical =
        (catalog['drugs'] as List).map((r) => r['id'] as String).toSet();
    expect(index.keys.toSet(), canonical);
    expect(index.length, 1018);
    expect(old.length, 838);
    expect(old.difference(index.keys.toSet()), isEmpty);
    expect(index.keys.toSet().difference(old).length, 180);
    expect(requests, ['/api/drug-catalog']);
  });
  for (final id in ['insulina_regular', 'diclofenaco_gotas', 'noradrenalina']) {
    test('exact lookup $id preserves source; derives no clinical values',
        () async {
      final result = (await loader.canonicalCatalog.lookup(id))!;
      expect(result.canonicalDrugId, id);
      expect(result.source, object(id));
      expect(result.catalogVisible, isTrue);
      expect(result.calculationAuthorized, isFalse);
      expect(result.clinicalAuthority, isFalse);
      expect(result.infusionAuthority, isFalse);
      expect(result.derivedClinicalValues, isEmpty);
      expect(() => result.source['id'] = 'other', throwsUnsupportedError);
      final pt = result.source['pt'] as Map;
      expect(() => pt['dose'] = 'derived', throwsUnsupportedError);
    });
  }
  test('three deferred aliases not active; no document lookup', () async {
    for (final id in [
      'fenoterol_solucao_inalatoria',
      'ipratropio_solucao_inalatoria',
      'salbutamol_solucao_inalatoria'
    ]) {
      expect(await loader.canonicalCatalog.lookup(id), isNull);
    }
    expect(requests.every((p) => p == '/api/drug-catalog'), isTrue);
  });
  test('duplicate candidates remain separate', () async {
    final index = await loader.canonicalCatalog.loadIndex();
    for (final id in [
      'anfotericina_lipossomal',
      'anfotericina_b',
      'acidotranexamico',
      'acido_tranexamico'
    ]) {
      expect(index[id]!['id'], id);
    }
  });
  test('16 infusion names never bind; all authority requests fail closed',
      () async {
    const names = [
      'Noradrenalina',
      'Adrenalina',
      'Dobutamina',
      'Dopamina',
      'Milrinona',
      'Vasopressina',
      'Nitroprussiato',
      'Nitroglicerina',
      'Amiodarona',
      'Heparina',
      'Propofol',
      'Midazolam',
      'Morfina',
      'Fentanil',
      'Insulina Regular',
      'Vancomicina'
    ];
    for (final name in names) {
      expect(await loader.canonicalCatalog.lookup(name), isNull);
      expect(loader.canonicalCatalog.infusionAuthorityForFallback(name),
          'FAIL_CLOSED_UNRESOLVED_BINDING');
    }
    expect(requests, isEmpty);
  });
  test('future canonical rows appear without fixed bundle migration', () async {
    (catalog['drugs'] as List).add({
      'id': 'test_future_id',
      'name': {'pt': 'Fixture', 'es': 'Fixture'}
    });
    expect((await loader.canonicalCatalog.loadIndex()).length, 1019);
    (catalog['drugs'] as List).removeLast();
    expect((await loader.canonicalCatalog.loadIndex()).length, 1018);
  });
  test('duplicate index rejects entire projection', () async {
    (catalog['drugs'] as List).add((catalog['drugs'] as List).first);
    await expectLater(
        loader.canonicalCatalog.loadIndex(), throwsFormatException);
  });
  test('mismatched drug response fails closed', () async {
    final resolver = PlantaoCanonicalCatalogReadOnlyResolver(
        loadObject: (path) async => path == '/api/drug-catalog'
            ? catalog
            : {
                'ok': true,
                'drug': {'id': 'noradrenalina'}
              });
    await expectLater(
        resolver.lookup('insulina_regular'), throwsFormatException);
  });
  test('missing authentication never fetches catalog', () async {
    final missing = PlantaoVersionedRemoteDrugEvidenceJsonLoader(
        client:
            MockClient((_) async => throw StateError('network must not run')));
    await expectLater(missing.canonicalCatalog.loadIndex(), throwsStateError);
    missing.close();
  });
  test('HTTP failures never fall back to old bundle', () async {
    final denied = PlantaoVersionedRemoteDrugEvidenceJsonLoader(
        authorizationTokenProvider: () async => 'token',
        client: MockClient((_) async => http.Response('{}', 401)));
    await expectLater(denied.canonicalCatalog.loadIndex(), throwsStateError);
    denied.close();
  });
  test('source authorization metadata never grants resolver authority',
      () async {
    final raw = object('insulina_regular');
    (raw['mc_gold_standard_v1'] as Map)['calculationAuthorized'] = true;
    final resolver = PlantaoCanonicalCatalogReadOnlyResolver(
      loadObject: (path) async =>
          path == '/api/drug-catalog' ? catalog : {'ok': true, 'drug': raw},
    );
    final doc = (await resolver.lookup('insulina_regular'))!;
    expect((doc.source['mc_gold_standard_v1'] as Map)['calculationAuthorized'],
        isTrue);
    expect(doc.calculationAuthorized, isFalse);
    expect(doc.clinicalAuthority, isFalse);
    expect(doc.infusionAuthority, isFalse);
  });

  test('shadow and authority flags unchanged', () {
    expect(PlantaoVersionedRemoteDrugEvidenceJsonLoader.shadowOnly, isTrue);
    expect(
        PlantaoVersionedRemoteDrugEvidenceJsonLoader
            .productiveConnectionEnabled,
        isFalse);
    expect(PlantaoVersionedRemoteDrugEvidenceJsonLoader.promptMutationEnabled,
        isFalse);
    expect(
        PlantaoVersionedRemoteDrugEvidenceJsonLoader.deterministicDosingEnabled,
        isFalse);
  });
}
