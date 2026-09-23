import '../plantao_knowledge/remote_knowledge.dart';
import '../../models/protocol_model.dart';
import '../../models/clinical_case_model.dart';
import 'clinical_content_contract.dart';

/// Structural conversion only. No missing identity, patient fact or clinical
/// section is synthesized by permissive legacy model constructors.
class ClinicalContentModels {
  static Map<String, dynamic> protocolPayload(ProtocolModel protocol) => {
        'id': protocol.id,
        'canonicalFamilyId': protocol.canonicalFamilyId,
        'canonicalProtocolId': protocol.canonicalProtocolId,
        'title': protocol.title,
        'severity': protocol.severity,
        'recognize': protocol.recognize,
        'actions': protocol.actions,
        'avoid': protocol.avoid,
        'drugs': protocol.drugs,
        'definition': protocol.definition,
        'classification': protocol.classification,
        'severityCriteria': protocol.severityCriteria,
        'physiopathology': protocol.physiopathology,
        'redFlags': protocol.redFlags,
        'differentialDiagnosis': protocol.differentialDiagnosis,
        'exams': protocol.exams,
        'objectives': protocol.objectives,
        'drugsFirstLine': protocol.drugsFirstLine,
        'drugsSecondLine': protocol.drugsSecondLine,
        'drugsConditional': protocol.drugsConditional,
        'drugsContraindicated': protocol.drugsContraindicated,
        'scenarios': protocol.scenarios,
        'monitoring': protocol.monitoring,
        'complications': protocol.complications,
        'doNotDo': protocol.doNotDo,
        'pearls': protocol.pearls,
        'references': protocol.references,
      };

  static ProtocolModel protocol(ClinicalContentItem item) {
    final p = item.payload;
    requireContent(p['id'] == item.canonicalId, 'MODEL_ID_MISMATCH');
    Map<String, String> text(String key) =>
        contentObject(p[key]).map((k, value) {
          requireContent(value is String, 'PROTOCOL_TEXT_TYPE');
          return MapEntry(k, value as String);
        });
    Map<String, String>? optionalText(String key) =>
        p[key] == null ? null : text(key);
    Map<String, List<String>>? lists(String key) => p[key] == null
        ? null
        : contentObject(p[key])
            .map((k, v) => MapEntry(k, List<String>.from(v as List)));
    Map<String, dynamic>? object(String key) =>
        p[key] == null ? null : contentObject(p[key]);
    return ProtocolModel(
        id: item.canonicalId,
        canonicalFamilyId: p['canonicalFamilyId'] as String?,
        canonicalProtocolId: p['canonicalProtocolId'] as String?,
        title: text('title'),
        severity: text('severity'),
        recognize: text('recognize'),
        actions: contentObject(p['actions']),
        avoid: text('avoid'),
        drugs: List<String>.from(p['drugs'] as List),
        definition: optionalText('definition'),
        classification: object('classification'),
        severityCriteria: object('severityCriteria'),
        physiopathology: optionalText('physiopathology'),
        redFlags: lists('redFlags'),
        differentialDiagnosis: lists('differentialDiagnosis'),
        exams: lists('exams'),
        objectives: lists('objectives'),
        drugsFirstLine: lists('drugsFirstLine'),
        drugsSecondLine: lists('drugsSecondLine'),
        drugsConditional: lists('drugsConditional'),
        drugsContraindicated: lists('drugsContraindicated'),
        scenarios: lists('scenarios'),
        monitoring: lists('monitoring'),
        complications: lists('complications'),
        doNotDo: lists('doNotDo'),
        pearls: lists('pearls'),
        references: lists('references'));
  }

  static ClinicalCaseModel clinicalCase(ClinicalContentItem item) {
    final p = item.payload;
    requireContent(p['id'] == item.canonicalId, 'MODEL_ID_MISMATCH');
    for (final key in [
      'id',
      'title',
      'patientAge',
      'patientSex',
      'patientWeight',
      'history',
      'diagnosis',
      'plan',
      'notes',
      'category'
    ]) {
      requireContent(p[key] is String, 'CASE_FIELD_MISSING');
    }
    requireContent(
        p['drugIds'] is List &&
            (p['drugIds'] as List).every((v) => v is String),
        'CASE_DRUG_IDS_INVALID');
    requireContent(
        p['isCustom'] == false, 'CUSTOM_PATIENT_CASE_NOT_PUBLISHABLE');
    requireContent(p['createdAt'] == null || p['createdAt'] is String,
        'CASE_TIMESTAMP_TYPE');
    return ClinicalCaseModel.fromJson(p);
  }

  static void validate(String domain, Map<String, dynamic> envelope) {
    final item = ClinicalContentItem(envelope);
    if (domain == therapeuticProtocolDomain) {
      final protocol = RemoteKnowledgeProtocol.parse(item.payload);
      requireContent(protocol.id == item.canonicalId, 'MODEL_ID_MISMATCH');
    }
    if (domain == 'protocols') protocol(item);
    if (domain == 'cases') clinicalCase(item);
    if (domain == 'guides') {
      requireContent(
          item.payload['id'] == null || item.payload['id'] == item.canonicalId,
          'GUIDE_ID_MISMATCH');
      requireContent(
          item.payload['title'] is String &&
              item.payload['bodyBlocks'] is List &&
              item.payload['references'] is List,
          'GUIDE_MODEL_SCHEMA');
      for (final block in item.payload['bodyBlocks']) {
        contentObject(block);
      }
    }
    if (domain == 'drugs') {
      requireContent(
          item.payload['id'] == item.canonicalId &&
              RegExp(r'^[a-z0-9_]+$').hasMatch(item.canonicalId),
          'DRUG_ID_MISMATCH');
      final names = contentObject(item.payload['name']);
      requireContent(
          names['pt'] is String && names['es'] is String, 'DRUG_NAME_SCHEMA');
    }
  }
}
