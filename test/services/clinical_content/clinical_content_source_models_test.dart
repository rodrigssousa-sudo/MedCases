import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/data/protocols_database.dart';
import 'package:medcases/data/cases_database.dart';
import 'package:medcases/services/clinical_content/clinical_content_contract.dart';
import 'package:medcases/services/clinical_content/clinical_content_models.dart';

void main() {
  test(
      'all active protocol models roundtrip without rewriting clinical sections',
      () {
    for (final source in protocolsDatabase) {
      final payload = ClinicalContentModels.protocolPayload(source);
      final restored = ClinicalContentModels.protocol(
          ClinicalContentItem({'canonicalId': source.id, 'payload': payload}));
      expect(contentHash(ClinicalContentModels.protocolPayload(restored)),
          contentHash(payload));
    }
  });
  test('all shipped cases preserve original payload and identifiers', () {
    for (final source in casesDatabase) {
      final payload = source.toJson();
      final restored = ClinicalContentModels.clinicalCase(
          ClinicalContentItem({'canonicalId': source.id, 'payload': payload}));
      expect(restored.toJson(), payload);
    }
  });
  test('invalid protocol scalar is rejected before model activation', () {
    final payload =
        ClinicalContentModels.protocolPayload(protocolsDatabase.first);
    payload['title'] = {'pt': 42, 'es': 'reference'};
    expect(
        () => ClinicalContentModels.protocol(ClinicalContentItem(
            {'canonicalId': protocolsDatabase.first.id, 'payload': payload})),
        throwsA(isA<ContentFailure>()));
  });
  test('missing case ID cannot trigger legacy automatic ID generation', () {
    final payload = casesDatabase.first.toJson()..remove('id');
    expect(
        () => ClinicalContentModels.clinicalCase(ClinicalContentItem(
            {'canonicalId': casesDatabase.first.id, 'payload': payload})),
        throwsA(isA<ContentFailure>()));
  });
  test('custom patient case is not eligible as publisher content', () {
    final payload = casesDatabase.first.toJson()..['isCustom'] = true;
    expect(
        () => ClinicalContentModels.clinicalCase(ClinicalContentItem(
            {'canonicalId': casesDatabase.first.id, 'payload': payload})),
        throwsA(isA<ContentFailure>()));
  });
}
