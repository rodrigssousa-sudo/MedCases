import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/models/canonical_clinical_snapshot.dart';
import 'package:medcases/models/plantao_presentation_contract.dart';
import 'package:medcases/services/ai/r8/plantao_presentation_catalog.dart';
import 'package:medcases/services/clinical_catalog/clinical_catalog_presentation_remote.dart';
import '../fixtures/r15_ux_fixtures.dart';

class _Catalog implements ClinicalCatalogRemote {
  _Catalog(this.source, this.locale) {
    final presentation = source['presentationEnvelope'];
    identity = jsonEncode([
      {
        'canonicalKey': 'fixture_only',
        'enabled': true,
        'version': 'TEST_ONLY',
        'approvedClinicalPayloadSha256': source['payloadSha256']
      }
    ]);
    manifestValue = {
      'clinicalReleaseRegistry': {
        'approvedSources': [
          {
            'owner': 'fixture_only',
            'version': 'TEST_ONLY',
            'payloadSha256': source['payloadSha256'],
            'languages': ['pt', 'es']
          }
        ],
        'executives': [
          {
            'owner': 'fixture_only',
            'locale': locale,
            'sourceVersion': 'TEST_ONLY',
            'contentHash': presentation['contentHash'],
            'presentation': presentation['presentation'],
            'review': {
              'status': 'APPROVED',
              'contentHash': presentation['contentHash'],
              'recordId': 'SYNTHETIC_NOT_MEDICAL_APPROVAL',
              'reviewerId': 'TEST_ONLY',
              'reviewedAt': '2026-10-20',
              'evidenceSha256': '0' * 64
            }
          }
        ]
      },
      'chunks': [
        {
          'id': 'identity',
          'collection': 'clinical_identity_registry',
          'sha256': PlantaoPresentationContract.textHash(identity)
        }
      ]
    };
  }
  final Map<String, dynamic> source;
  final String locale;
  late String identity;
  late Map<String, dynamic> manifestValue;
  int reads = 0;
  bool fail = false, changePointer = false;
  @override
  Future<Map<String, dynamic>> pointer() async {
    reads++;
    if (fail) throw StateError('synthetic offline');
    return {
      'status': 'ACTIVE',
      'activeVersion': changePointer && reads > 1 ? 'CHANGED' : 'TEST_ONLY',
      'manifestSha256': CanonicalClinicalSnapshot.hash(manifestValue)
    };
  }

  @override
  Future<Map<String, dynamic>> manifest(String version) async => manifestValue;
  @override
  Future<String> chunk(String version, String id) async => identity;
}

void main() {
  for (final locale in ['pt', 'es']) {
    test('history uses current catalog authority, not its own approval $locale',
        () async {
      final source = r15ProtocolFixture(locale);
      final full = CanonicalClinicalSnapshot.fromApprovedProtocol(
              source, source['payloadSha256'])
          .blocks(locale)
          .join();
      final exchange = <String, dynamic>{
        'mode': 'plantao',
        'locale': locale,
        'assistantOutput': full,
        'clinicalProtocol': {
          'owner': 'fixture_only',
          'version': 'TEST_ONLY',
          'payloadSha256': source['payloadSha256']
        },
        'clinicalPresentation': source['presentationEnvelope']
      };
      final remote = _Catalog(source, locale);
      await PlantaoPresentationCatalog.restoreHistoryPresentations(
          [exchange], remote);
      expect(PlantaoPresentationCatalog.resolve(full, locale)?.isExecutive,
          isTrue);
      expect(remote.reads, 2);
      remote.fail = true;
      await PlantaoPresentationCatalog.restoreHistoryPresentations(
          [exchange], remote);
      expect(PlantaoPresentationCatalog.resolve(full, locale), isNull);
      expect(exchange['assistantOutput'], full);
    });
    test(
        'changed manifest, pending review and tampering cannot revive executive $locale',
        () async {
      final source = r15ProtocolFixture(locale);
      final full = CanonicalClinicalSnapshot.fromApprovedProtocol(
              source, source['payloadSha256'])
          .blocks(locale)
          .join();
      final exchange = <String, dynamic>{
        'mode': 'plantao',
        'locale': locale,
        'assistantOutput': full,
        'clinicalProtocol': {
          'owner': 'fixture_only',
          'version': 'TEST_ONLY',
          'payloadSha256': source['payloadSha256']
        },
        'clinicalPresentation': source['presentationEnvelope']
      };
      final remote = _Catalog(source, locale)..changePointer = true;
      await PlantaoPresentationCatalog.restoreHistoryPresentations(
          [exchange], remote);
      expect(PlantaoPresentationCatalog.resolve(full, locale), isNull);
      remote.changePointer = false;
      remote.manifestValue['clinicalReleaseRegistry']['executives'][0]['review']
          ['status'] = 'PENDING';
      await PlantaoPresentationCatalog.restoreHistoryPresentations(
          [exchange], remote);
      expect(PlantaoPresentationCatalog.resolve(full, locale), isNull);
      remote.manifestValue['clinicalReleaseRegistry']['executives'][0]['review']
          ['status'] = 'APPROVED';
      remote.identity += ' ';
      await PlantaoPresentationCatalog.restoreHistoryPresentations(
          [exchange], remote);
      expect(PlantaoPresentationCatalog.resolve(full, locale), isNull);
    });
  }
}
