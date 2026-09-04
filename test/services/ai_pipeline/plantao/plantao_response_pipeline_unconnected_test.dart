import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'PlantaoResponsePipeline remains isolated while the buffered controller owns cutover',
    () {
      final appProvider = File(
        'lib/providers/app_provider.dart',
      ).readAsStringSync();
      final facade = File(
        'lib/services/ai_pipeline/plantao/plantao_response_pipeline.dart',
      ).readAsStringSync();

      expect(
        appProvider,
        isNot(
          contains(
            "import '../services/ai_pipeline/plantao/"
            "plantao_response_pipeline.dart';",
          ),
        ),
      );
      expect(
        appProvider,
        contains(
          "import '../services/ai_pipeline/plantao/"
          "plantao_buffered_cutover_controller.dart';",
        ),
      );
      expect(
        appProvider,
        isNot(contains('PlantaoResponsePipeline()')),
      );
      expect(
        appProvider,
        isNot(contains('.drain<void>()')),
      );
      expect(
        appProvider,
        contains(
          'const PlantaoBufferedCutoverController.disabled()',
        ),
      );
      expect(
        facade,
        contains('class PlantaoResponsePipeline'),
      );
    },
  );
}
