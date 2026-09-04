import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'AppProvider captures typed retrieval in both productive route branches',
    () {
      final source = File('lib/providers/app_provider.dart').readAsStringSync();

      expect(source, contains('plantao_retrieval_shadow_adapter.dart'));
      expect(source, contains('PlantaoRetrievalShadowAdapter'));
      expect(source, contains('PlantaoRetrievalShadowSnapshot'));
      expect(source, contains('_capturePlantaoRetrievalShadow({'));
      expect(source, contains("documentId: 'protocol:\${protocol.id}'"));
      expect(source, contains("version: 'legacy_protocols_database_v1'"));
      expect(source, contains('matchedProtocols: qaMatchedProtocols'));
      expect(source, contains('matchedProtocols: matchedProtocolModels'));
      expect(
        '_capturePlantaoRetrievalShadow('.allMatches(source).length,
        greaterThanOrEqualTo(3),
      );
      expect(
        source,
        contains('evidenceBundle: retrievalSnapshot.evidenceBundle'),
      );
      expect(source, isNot(contains('PlantaoResponsePipeline().execute(')));
    },
  );
}
