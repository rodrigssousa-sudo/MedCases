import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'retrieval adapter uses the canonical local protocol corpus without external parallel retrieval',
    () {
      final source = File(
        'lib/services/ai_pipeline/plantao/shadow/'
        'plantao_retrieval_shadow_adapter.dart',
      ).readAsStringSync();

      expect(
        source,
        contains("import '../../../../data/protocols_database.dart';"),
      );
      expect(
        source,
        contains(
          'PlantaoProtocolMatcherEvidenceAdapter.toEvidenceItem',
        ),
      );
      expect(
        source,
        contains('protocol.id: protocol'),
      );
      expect(
        source,
        contains("match.metadata['legacyProtocolId']"),
      );
      expect(
        source,
        contains('metadataId != documentIdValue'),
      );
      expect(
        source,
        contains('protocol_identity_missing'),
      );
      expect(
        source,
        contains('protocol_identity_mismatch'),
      );
      expect(
        source,
        contains('protocol_model_not_found'),
      );

      expect(
        source,
        isNot(contains('FirebaseFirestore')),
      );
      expect(
        source,
        isNot(contains('http.get')),
      );
      expect(
        source,
        isNot(contains('http.post')),
      );
      expect(
        source,
        isNot(contains('Dio(')),
      );
      expect(
        source,
        isNot(contains('package:http/')),
      );
      expect(
        source,
        isNot(contains('package:dio/')),
      );
    },
  );

  test(
    'drug and dedicated clinical retrieval remain explicitly disconnected',
    () {
      final source = File(
        'lib/services/ai_pipeline/plantao/shadow/'
        'plantao_retrieval_shadow_adapter.dart',
      ).readAsStringSync();

      expect(
        source,
        contains('dedicated_clinical_document_retrieval_not_connected'),
      );
      expect(source, contains('drug_retrieval_not_connected'));
      expect(source, contains('external_grounding_not_bound'));
      expect(source, contains('PlantaoRetrievalStatus.partial'));
      expect(source, contains('PlantaoRetrievalStatus.empty'));
    },
  );
}
