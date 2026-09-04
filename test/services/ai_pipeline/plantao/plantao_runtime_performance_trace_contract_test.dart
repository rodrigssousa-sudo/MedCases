import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('Phase3K-C5A-R11 bounded runtime performance trace', () {
    test('provider and UI chunk traces use the same bounded sampler', () {
      final provider = _read('lib/providers/app_provider.dart');
      final screen = _read('lib/screens/ai_screen.dart');

      expect(
        provider,
        contains('guardiaTraceProviderChunkIndex <= 3'),
      );
      expect(
        provider,
        contains('guardiaTraceProviderChunkIndex % 25 == 0'),
      );
      expect(
        screen,
        contains('guardiaTraceUiChunkIndex <= 3'),
      );
      expect(
        screen,
        contains('guardiaTraceUiChunkIndex % 25 == 0'),
      );

      expect(
        provider,
        contains('[GUARDIA_TRACE] stage=I1_provider_chunk'),
      );
      expect(
        screen,
        contains('[GUARDIA_TRACE] stage=I2_ui_chunk_in'),
      );
    });

    test('final handoff exposes closed non-clinical timing stages', () {
      final provider = _read('lib/providers/app_provider.dart');

      const stages = <String>[
        '[GUARDIA_PERF] stage=handoff_start ',
        '[GUARDIA_PERF] stage=on_done_return ',
        '[GUARDIA_PERF] stage=structured_return ',
      ];

      for (final stage in stages) {
        expect(provider, contains(stage));
        expect(
          RegExp(RegExp.escape(stage)).allMatches(provider),
          hasLength(1),
        );
      }

      expect(
        RegExp(
          r'\[GUARDIA_PERF\].*prompt',
        ).allMatches(provider),
        isEmpty,
      );
      expect(
        RegExp(
          r'\[GUARDIA_PERF\].*finalText',
        ).allMatches(provider),
        isEmpty,
      );
      expect(
        RegExp(
          r'\[GUARDIA_PERF\].*clinical',
        ).allMatches(provider),
        isEmpty,
      );
    });

    test('onDone still precedes structured callback', () {
      final provider = _read('lib/providers/app_provider.dart');
      final committedStart = provider.indexOf(
        'case PlantaoBufferedCutoverDisposition.committed:',
      );
      final rejectedStart = provider.indexOf(
        'case PlantaoBufferedCutoverDisposition.rejectedAfterStart:',
        committedStart,
      );

      expect(committedStart, isNonNegative);
      expect(rejectedStart, isNonNegative);

      final committed = provider.substring(
        committedStart,
        rejectedStart,
      );

      final onDone = committed.indexOf(
        'onDone(phase3kResult.finalText);',
      );
      final structured = committed.indexOf(
        'onStructuredDone(',
      );

      expect(onDone, isNonNegative);
      expect(structured, isNonNegative);
      expect(onDone, lessThan(structured));
    });

    test('retained final stages expose microsecond timestamps', () {
      final provider = _read('lib/providers/app_provider.dart');
      final screen = _read('lib/screens/ai_screen.dart');
      final renderer = _read(
        'lib/screens/ai/widgets/guardia_clinical_response_view.dart',
      );

      expect(
        provider,
        contains('[GUARDIA_TRACE] stage=I3_provider_final'),
      );
      expect(
        screen,
        contains('[GUARDIA_TRACE] stage=I4_ui_final'),
      );
      expect(
        screen,
        contains('[GUARDIA_TRACE] stage=I4_ui_structured'),
      );
      expect(
        renderer,
        contains('[GUARDIA_TRACE] stage=I5_renderer_final'),
      );

      expect(
        provider,
        contains('tsUs=\${DateTime.now().microsecondsSinceEpoch}'),
      );
      expect(
        screen
            .split('tsUs=\${DateTime.now().microsecondsSinceEpoch}')
            .length,
        greaterThanOrEqualTo(3),
      );
      expect(
        renderer,
        contains('tsUs=\${DateTime.now().microsecondsSinceEpoch}'),
      );
    });
  });
}
