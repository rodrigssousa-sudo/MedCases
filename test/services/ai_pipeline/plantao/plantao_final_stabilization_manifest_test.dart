import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('Phase3K-C5A-R13 final stabilization manifest', () {
    test('manifest closes architecture without authorizing broad rollout', () {
      final manifest = _read(
        'docs/ai_pipeline/phase3k_c5a_final_stabilization_manifest.md',
      );

      expect(manifest, contains('ARCHITECTURE_STATUS=COMPLETE'));
      expect(manifest, contains('CUTOVER_APPROVED=YES'));
      expect(manifest, contains('FULL_TERMINAL_OWNERSHIP=YES'));
      expect(manifest, contains('REMAINING_RESTRUCTURING_PERCENT=0'));
      expect(
        manifest,
        contains('PRODUCTION_ROLLOUT_AUTHORIZED=NO'),
      );
      expect(
        manifest,
        contains('OPEN_WORKSTREAM=CLINICAL_CONTENT_VALIDATION'),
      );
    });

    test('manifest pins the retained R12-V7 productive owners', () {
      final manifest = _read(
        'docs/ai_pipeline/phase3k_c5a_final_stabilization_manifest.md',
      );

      const expectedHashes = <String>[
        '19895eedfac57dc6e3feb014bb12d3506761f93084115f4953937a2c6c88eeed',
        '4df108c16c2da4b257f3398020ce581acd62bbffdd8cc000d60ded62e614bbc2',
        'e533dea08f81734b4d9df18f64b55192eb5475142621caef46c2ae6aac2702da',
        '33db68c6ee2ec408fe682ee6476207531630fa9a694c2dcf991d3b792c9ab1d5',
        'db40182b23abb009bd1fd5a6f231d671ca672f72119e7821f913a083638f1c33',
      ];

      for (final hash in expectedHashes) {
        expect(manifest, contains(hash));
      }
    });

    test('productive source retains progressive and terminal owners', () {
      final provider = _read('lib/providers/app_provider.dart');
      final screen = _read('lib/screens/ai_screen.dart');
      final controller = _read(
        'lib/services/ai_pipeline/plantao/'
        'plantao_buffered_cutover_controller.dart',
      );

      expect(
        controller,
        contains(
          'void Function(String accumulatedText)? onProvisionalText',
        ),
      );
      expect(controller, contains('if (event is AiResponseDelta)'));
      expect(
        provider,
        contains('onProvisionalText: (provisionalText) {'),
      );
      expect(
        provider,
        contains('onChunk(phase3kResult.displayText);'),
      );
      expect(
        provider,
        contains('onDone(phase3kResult.finalText);'),
      );
      expect(screen, contains('Timer? terminalGapIndicatorTimer;'));
      expect(
        screen,
        contains('const Duration(milliseconds: 450)'),
      );
    });

    test('renderer still withholds HARD STOP while streaming', () {
      final renderer = _read(
        'lib/screens/ai/widgets/guardia_clinical_response_view.dart',
      );

      expect(
        renderer,
        contains('if (!isStreaming || rawText.isEmpty) return rawText;'),
      );
      expect(
        renderer,
        contains(
          'return rawText.substring(0, boundary.start).trimRight();',
        ),
      );
      expect(renderer, contains("'Red flags/escalamiento'"));
      expect(renderer, contains("'Red flags/escalonamento'"));
    });
  });
}
