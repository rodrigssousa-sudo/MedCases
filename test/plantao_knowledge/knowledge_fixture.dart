import 'dart:convert';
import 'package:medcases/services/plantao_knowledge/remote_knowledge.dart';
import 'package:medcases/services/clinical_content/clinical_content_contract.dart';
import 'package:medcases/services/clinical_content/clinical_content_release_builder.dart';

Map<String, String> bilingual(String value) => {'pt': value, 'es': 'ES_$value'};
Map<String, dynamic> syntheticProtocol() {
  final p = <String, dynamic>{
    'schemaVersion': 1,
    'contentType': 'prescription_protocol',
    'protocolId': 'TEST_PROTOCOL',
    'version': 'v1',
    'languages': ['pt', 'es'],
    'title': bilingual('TEST_TITLE'),
    'clinicalContext': bilingual('TEST_CONTEXT'),
    'canonicalContextIds': ['TEST_CONTEXT_ID'],
    'clinicalReview': {
      'approved': true,
      'reviewer': 'TECHNICAL_TEST_ONLY',
      'reviewedAt': '2026-09-22',
      'result': 'SYNTHETIC_FIXTURE'
    },
    'publication': {'status': 'PUBLISHED', 'publishedAt': '2026-09-22'},
    'references': [
      {
        'referenceId': 'TEST_REF',
        'title': bilingual('TEST_REFERENCE'),
        'url': 'https://example.invalid/test-evidence'
      }
    ],
    'therapeuticOptions': [
      for (var i = 0; i < 3; i++)
        {
          'optionId': 'TEST_OPTION_$i',
          'priority': i,
          'prescriptionKind': 'single_administration',
          'type': i == 0 ? 'PRIMARY' : 'ALTERNATIVE',
          'label': bilingual('TEST_OPTION_$i'),
          'indication': bilingual('TEST_INDICATION'),
          'whenToConsider': bilingual('TEST_CONSIDER'),
          'references': ['TEST_REF'],
          'drugs': [
            {
              'drugId': 'test_drug_$i',
              'drugName': bilingual('TEST_DRUG_$i'),
              'presentation': bilingual('TEST_PRESENTATION'),
              'dose': {'value': 'TEST_VALUE_$i', 'unit': 'TEST_UNIT'},
              'route': bilingual('TEST_ROUTE'),
              'frequency': bilingual('TEST_FREQUENCY'),
              'preparation': bilingual('TEST_PREPARATION'),
              'warnings': bilingual('TEST_WARNING'),
              'references': ['TEST_REF']
            }
          ]
        }
    ],
    'metadata': {'fixtureOnly': true}
  };
  p['clinicalContentSha256'] = clinicalKnowledgeHash(p);
  return p;
}

Map<String, dynamic> cloneProtocol(Map<String, dynamic> p) =>
    jsonDecode(jsonEncode(p)) as Map<String, dynamic>;
Map<String, Map<String, dynamic>> fixtureRelease(Map<String, dynamic> p,
    {int sequence = 1, bool revoked = false}) {
  final item = <String, dynamic>{
    'canonicalId': p['protocolId'],
    'schemaVersion': '1.0',
    'contentVersion': 'v$sequence',
    'updatedAt': '2026-09-22',
    'publicationStatus': revoked ? 'REVOKED' : 'PRODUCTION',
    'payload': p
  };
  item['contentHash'] = itemContentHash(item);
  return ClinicalContentReleaseBuilder.build(
      domains: {
        therapeuticProtocolDomain: [item]
      },
      sequence: sequence,
      contentVersion: 'v$sequence',
      generatedAt: DateTime.utc(2026, 9, 22),
      publicationStatus: 'PRODUCTION');
}
