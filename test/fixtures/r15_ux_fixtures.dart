// Technical approval-shaped fixture only. Never a real medical authorization.
import 'dart:convert';
import 'package:medcases/models/canonical_clinical_snapshot.dart';
import 'package:medcases/models/plantao_presentation_contract.dart';

Map<String, dynamic> r15ProtocolFixture(String locale,
    {bool executive = true}) {
  final es = locale == 'es';
  final body = '# ${es ? 'Patología de prueba' : 'Patologia de teste'}\n\n'
      '${es ? 'Texto integral técnico; no usar clínicamente.' : 'Texto integral técnico; não usar clinicamente.'}\n\n'
      'FULL_SENTINEL 10 mg VO q8h — TEST ONLY.\n\n'
      '## ${es ? 'Referencias' : 'Referências'}\n\n'
      '- [Fonte técnica](https://example.org/reference)\n'
      '- [Fonte técnica](https://example.org/reference)';
  final payload = <String, dynamic>{
    'owner': 'fixture_only',
    'version': 'TEST_ONLY',
    'pt': {'plantao': body},
    'es': {'plantao': body},
    'references': <dynamic>[]
  };
  // Canonical serialization makes the shared source digest byte-exact.
  String sorted(Object? value) {
    Object? normalize(Object? v) {
      if (v is Map) {
        final keys = v.keys.cast<String>().toList()..sort();
        return {for (final k in keys) k: normalize(v[k])};
      }
      if (v is List) return v.map(normalize).toList();
      return v;
    }

    return jsonEncode(normalize(value));
  }

  final source = <String, dynamic>{
    'owner': 'fixture_only',
    'version': 'TEST_ONLY',
    'activeVersion': 'TEST_ONLY',
    'approvedClinicalPayloadJson': sorted(payload),
    'payloadSha256': CanonicalClinicalSnapshot.hash(payload),
    'scope': 'UNCHANGED_GENERAL_PROTOCOL_NOT_INDIVIDUAL_PRESCRIPTION',
    'review': {
      'recordId': 'SYNTHETIC_NOT_MEDICAL_APPROVAL',
      'reviewerId': 'TEST_ONLY',
      'reviewedAt': '2026-10-20',
      'evidenceSha256': '0' * 64
    }
  };
  if (!executive) return source;
  final full = CanonicalClinicalSnapshot.fromApprovedProtocol(
          source, source['payloadSha256'])
      .blocks(locale)
      .join();
  Map<String, dynamic> drug(String name, String relation) => {
        'name': name,
        'dose': '10',
        'unit': 'mg',
        'route': 'VO',
        'frequency': 'q8h',
        'duration': 'TEST_DURATION',
        'strategy': 'TEST_STRATEGY',
        'conditions': ['TEST_CONDITION'],
        'alternatives': <String>[],
        'clinicalLimits': ['TEST_LIMIT'],
        'relation': relation
      };
  final presentation = <String, dynamic>{
    'schemaVersion': 1,
    'level': 'EXECUTIVE',
    'locale': locale,
    'clinicalTitle': es ? 'Patología de prueba' : 'Patologia de teste',
    'sourceVersion': 'TEST_ONLY',
    'immediateActions': [
      es ? 'Acción técnica inicial.' : 'Ação técnica inicial.'
    ],
    'monitoring': [es ? 'Monitorización técnica.' : 'Monitorização técnica.'],
    'criticalAlerts': [
      es
          ? 'Alerta técnico; no usar clínicamente.'
          : 'Alerta técnico; não usar clinicamente.'
    ],
    'references': ['https://example.org/reference'],
    'medications': [
      drug('FIXTURE_MAIN', 'conditional'),
      drug('FIXTURE_ASSOCIATED', 'concomitant'),
      drug('FIXTURE_ALTERNATIVE', 'alternative')
    ],
    'clinicalApproval': {
      'status': 'APPROVED',
      'level': 'EXECUTIVE',
      'recordId': 'SYNTHETIC_NOT_MEDICAL_APPROVAL',
      'sourceHash': PlantaoPresentationContract.textHash(full)
    },
    'fullProtocolRef': {
      'id': 'fixture_only',
      'locale': locale,
      'sourceVersion': 'TEST_ONLY',
      'text': full,
      'contentHash': PlantaoPresentationContract.textHash(full)
    },
  };
  presentation['contentHash'] =
      PlantaoPresentationContract.digest(presentation);
  source['presentationEnvelope'] = {
    'presentation': presentation,
    'contentHash': presentation['contentHash']
  };
  return source;
}

CanonicalClinicalSnapshot r15ProtocolSnapshot(String locale,
    {bool executive = true}) {
  final source = r15ProtocolFixture(locale, executive: executive);
  return CanonicalClinicalSnapshot.fromApprovedProtocol(
      source, source['payloadSha256']);
}
