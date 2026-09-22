import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medcases/services/ai/safety/clinical_request_safety.dart';
import 'package:medcases/services/ai_pipeline/ai_request_contract.dart';
import 'package:medcases/services/ai_pipeline/plantao/adapters/plantao_canonical_catalog_readonly_resolver.dart';
import 'package:medcases/services/clinical_content/clinical_content_contract.dart';
import 'package:medcases/services/clinical_content/clinical_content_gateway.dart';
import 'package:medcases/services/clinical_content/clinical_content_platform.dart';
import 'package:medcases/services/clinical_content/clinical_content_release_builder.dart';

Map<String, dynamic> readFixture(String path) =>
    jsonDecode(File('test/fixtures/$path.json').readAsStringSync())
        as Map<String, dynamic>;

void expectReadOnly(PlantaoReadOnlyCatalogDocument document) {
  expect(document.catalogVisible, isTrue);
  expect(document.calculationAuthorized, isFalse);
  expect(document.clinicalAuthority, isFalse);
  expect(document.infusionAuthority, isFalse);
  expect(document.derivedClinicalValues, isEmpty);
}

void main() {
  final bindings = readFixture('infusion_binding_source/presets')['bindings']
      as List<dynamic>;
  final catalog = readFixture('ai_canonical_catalog/catalog');
  final insulin = readFixture('ai_canonical_catalog/insulina_regular');
  // A real catalog index projection exercises transport without rewriting
  // the full source document, which currently fails remote parity validation.
  final insulinIndex = (catalog['drugs'] as List)
      .singleWhere((row) => row['id'] == 'insulina_regular') as Map;
  final snapshotPayload = <String, dynamic>{
    'id': insulinIndex['id'],
    'name': insulinIndex['name'],
  };
  var canonicalCalls = 0;
  final canonical =
      PlantaoCanonicalCatalogReadOnlyResolver(loadObject: (path) async {
    canonicalCalls++;
    if (path == '/api/drug-catalog') return catalog;
    if (path == '/api/drugs/insulina_regular') {
      return {'ok': true, 'drug': insulin};
    }
    throw StateError('Unexpected document lookup: $path');
  });

  // These tests prove non-authorization. They do not assert that missing
  // clinical fields match, or turn display names into canonical candidates.
  for (final raw in bindings) {
    final row = raw as Map<String, dynamic>;
    final source = row['fallback'] as Map<String, dynamic>;
    test('${row['bindingId']} ${source['nome']}: unresolved stays fail-closed',
        () async {
      for (final key in [
        'id',
        'drugId',
        'canonicalDrugId',
        'route',
        'formulation',
        'concentration'
      ]) {
        expect(source[key], isNull,
            reason: 'No canonical $key assertion exists');
      }
      expect(source['doseInicial'], isNull);
      for (final prep in row['preparations'] as List) {
        expect(prep['canonicalDrugId'], isNull);
        expect(prep['unitDefault'], source['unidade']);
        expect(prep['amountUnit'], source['amountUnit']);
      }
      expect(await canonical.lookup(source['nome'] as String), isNull);
      expect(await canonical.lookup(row['bindingId'] as String), isNull);
      final normalized = row['recognizedNormalization'] as Map;
      final index = await canonical.loadIndex();
      expect(index.containsKey(normalized['normalized']),
          normalized['canonicalExists']);
      if (normalized['canonicalExists'] == true) {
        final document = PlantaoReadOnlyCatalogDocument.fromCanonicalSource(
          normalized['normalized'] as String,
          row['canonicalDocument'] as Map<String, Object?>,
        );
        expectReadOnly(document);
        expect(
            (document.source['mc_gold_standard_v1']
                as Map)['calculationAuthorized'],
            isFalse);
        // Reference prose cannot prove a structured operational field match.
        expect(document.source['infusion'], isNull);
      }
      expect(canonical.infusionAuthorityForFallback(source['nome'] as String),
          'FAIL_CLOSED_UNRESOLVED_BINDING');
    });
  }

  test('no alias, normalization, prefix, brand or preparation ID promotion',
      () async {
    for (final id in [
      'Insulina Regular',
      'insulina regular',
      'insulina',
      'insulina_regular ',
      'INSULINA_REGULAR',
      'prep_14',
      'unregistered_alias',
      'not_a_drug'
    ]) {
      expect(await canonical.lookup(id), isNull);
    }
    expectReadOnly((await canonical.lookup('insulina_regular'))!);
  });

  test(
      'full current insulin source fails parity without editing clinical content',
      () {
    expect(
        () => validateLanguageParity(insulin),
        throwsA(isA<ContentFailure>()
            .having((e) => e.code, 'code', 'PT_ES_EMPTY')));
  });

  test('conflicting route/concentration or source flags cannot grant authority',
      () {
    for (final field in [
      'route',
      'formulation',
      'concentration',
      'doseUnit',
      'infusionUnit',
      'dilution',
      'speed'
    ]) {
      final original = {...insulin};
      final conflicting = {
        ...original,
        field: 'incompatible_test_value',
        'calculationAuthorized': true,
        'infusionAuthority': true
      };
      expectReadOnly(PlantaoReadOnlyCatalogDocument.fromCanonicalSource(
          'insulina_regular', original));
      expectReadOnly(PlantaoReadOnlyCatalogDocument.fromCanonicalSource(
          'insulina_regular', conflicting));
    }
    expect(
        () => PlantaoReadOnlyCatalogDocument.fromCanonicalSource(
            'insulina_regular', {...insulin, 'id': 'other'}),
        throwsFormatException);
  });

  group('existing deterministic arithmetic, independent of drug authority', () {
    test('g/mg/mcg and mg/mL/mcg/mL retain 1000x scale', () {
      expect(ClinicalArithmetic.convertMass(1, MassUnit.g, MassUnit.mg), 1000);
      expect(
          ClinicalArithmetic.convertMass(1, MassUnit.mg, MassUnit.mcg), 1000);
      expect(
          ClinicalArithmetic.convertMass(1000000, MassUnit.mcg, MassUnit.g), 1);
      expect(ClinicalArithmetic.concentration(mass: 1, volumeMl: 1), 1);
      expect(
          ClinicalArithmetic.concentration(
              mass:
                  ClinicalArithmetic.convertMass(1, MassUnit.mg, MassUnit.mcg),
              volumeMl: 1),
          1000);
      expect(ClinicalArithmetic.validateMassEquations('1 mg = 1 mcg'), isFalse);
      expect(
          ClinicalArithmetic.validateMassEquations('1 mg = 1000 mcg'), isTrue);
    });
    test('mcg/kg/min to mL/h dimensional arithmetic, not a prescribed dose',
        () {
      expect(
          ClinicalArithmetic.infusionMlHour(
              mcgKgMinute: 1, weightKg: 1, mcgMl: 1),
          60);
    });
    for (final invalid in [0.0, -1.0, double.nan, double.infinity]) {
      test('reject invalid numeric operand $invalid', () {
        expect(
            () => ClinicalArithmetic.infusionMlHour(
                mcgKgMinute: 1, weightKg: invalid, mcgMl: 1),
            throwsFormatException);
        expect(
            () => ClinicalArithmetic.infusionMlHour(
                mcgKgMinute: 1, weightKg: 1, mcgMl: invalid),
            throwsFormatException);
        expect(
            () => ClinicalArithmetic.infusionMlHour(
                mcgKgMinute: invalid, weightKg: 1, mcgMl: 1),
            throwsFormatException);
        expect(
            () => ClinicalArithmetic.concentration(mass: 1, volumeMl: invalid),
            throwsFormatException);
      });
    }
    test('pediatric infusion with missing weight cannot reach model', () {
      const query =
          'Calcular dose de infusão pediátrica em mcg/kg/min; idade: 5 anos';
      final request = ClinicalRequestContext(
          requestId: 'test',
          sessionId: 'test',
          uid: 'test',
          mode: AiRequestMode.plantao,
          language: 'pt',
          userQuery: query,
          memory: ClinicalSafetyMemory()
              .capture(uid: 'test', sessionId: 'test', userQuery: query),
          evidence: ClinicalEvidenceBundle(),
          createdAt: DateTime.utc(2026, 9, 21));
      expect(request.unknownCriticalFacts, contains('weightKg'));
      expect(request.answerability, Answerability.askForMissingData);
      expect(request.mayGenerate, isFalse);
      expect(() => request.requireTransport(mode: 'plantao', language: 'pt'),
          throwsStateError);
    });
  });

  group(
      'same infusion boundary through current source, remote, LKG and revocation',
      () {
    late Map<String, Map<String, dynamic>> server;
    late MemoryClinicalSnapshotStore store;
    late ClinicalContentGateway gateway;
    late DrugResolver bridge;
    var offline = false;

    Map<String, Map<String, dynamic>> release(int sequence,
        {bool revoked = false}) {
      final envelope = <String, dynamic>{
        'canonicalId': 'insulina_regular',
        'schemaVersion': '1.0',
        'contentVersion': '$sequence',
        'updatedAt': '2026-09-21T00:00:00Z',
        'publicationStatus': revoked ? 'REVOKED' : 'PRODUCTION',
        'payload': revoked ? <String, dynamic>{} : snapshotPayload,
      };
      envelope['contentHash'] = itemContentHash(envelope);
      return ClinicalContentReleaseBuilder.build(
          domains: {
            'drugs': [envelope]
          },
          sequence: sequence,
          contentVersion: '$sequence',
          generatedAt: DateTime.utc(2026, 9, 21),
          publicationStatus: 'PRODUCTION');
    }

    ClinicalContentGateway makeGateway() => ClinicalContentGateway(
        baseUri: Uri.parse('https://content.example/'),
        store: store,
        sessionScope: 'test-account',
        currentSessionScope: () => 'test-account',
        canReadDomain: (_) => true,
        tokenProvider: () async => 'test-token',
        client: MockClient((request) async {
          if (offline) throw const SocketException('offline');
          final value = server[request.url.path.replaceFirst('/', '')];
          return http.Response(jsonEncode(value), value == null ? 404 : 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }));

    void assertAllBlocked() {
      for (final row in bindings) {
        expect(
            bridge.infusionAuthorityForFallback(
                row['fallback']['nome'] as String),
            'FAIL_CLOSED_UNRESOLVED_BINDING');
      }
    }

    setUp(() {
      server = release(1);
      store = MemoryClinicalSnapshotStore();
      offline = false;
      canonicalCalls = 0;
      gateway = makeGateway();
      bridge = DrugResolver(gateway, canonical);
    });
    tearDown(() {
      gateway.close();
      gateway.client.close();
    });

    test('current canonical fallback is read-only before a drugs snapshot',
        () async {
      expectReadOnly((await bridge.lookup('insulina_regular'))!);
      expect(canonicalCalls, 2);
      assertAllBlocked();
    });
    test(
        'ACTIVE and restarted offline LKG keep source payload and deny authority',
        () async {
      expect((await gateway.sync()).activated, isTrue);
      expectReadOnly((await bridge.lookup('insulina_regular'))!);
      assertAllBlocked();
      gateway.close();
      gateway.client.close();
      offline = true;
      gateway = makeGateway();
      bridge = DrugResolver(gateway, canonical);
      expect((await gateway.sync()).activated, isFalse);
      final doc = (await bridge.lookup('insulina_regular'))!;
      expect(doc.source, snapshotPayload);
      expectReadOnly(doc);
      assertAllBlocked();
      expect(canonicalCalls, 0);
    });
    test('invalid remote hash retains LKG without a canonical fallback',
        () async {
      expect((await gateway.sync()).activated, isTrue);
      server = release(2);
      server['manifest.json']!['contentHash'] = '0' * 64;
      expect((await gateway.sync()).activated, isFalse);
      expect(gateway.activeVersion, '1');
      expectReadOnly((await bridge.lookup('insulina_regular'))!);
      assertAllBlocked();
      expect(canonicalCalls, 0);
    });
    test('REVOKED survives restart and invalid resurrection attempt', () async {
      await gateway.sync();
      server = release(2, revoked: true);
      expect((await gateway.sync()).activated, isTrue);
      expect(await bridge.lookup('insulina_regular'), isNull);
      assertAllBlocked();
      gateway.close();
      gateway.client.close();
      offline = true;
      gateway = makeGateway();
      bridge = DrugResolver(gateway, canonical);
      await gateway.sync();
      expect(await bridge.lookup('insulina_regular'), isNull);
      assertAllBlocked();
      offline = false;
      server = release(3);
      expect((await gateway.sync()).activated, isFalse);
      expect(await bridge.lookup('insulina_regular'), isNull);
      expect(await bridge.lookup('missing_id'), isNull);
      expect(canonicalCalls, 0);
    });
    test(
        'invalid first snapshot permits only original read-only canonical fallback',
        () async {
      server['manifest.json']!['schemaVersion'] = '999.0';
      expect((await gateway.sync()).activated, isFalse);
      expectReadOnly((await bridge.lookup('insulina_regular'))!);
      assertAllBlocked();
      expect(canonicalCalls, 2);
    });
  });
}
