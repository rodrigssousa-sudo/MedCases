import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ScrollEndNotification rebuild is deferred until post-frame', () {
    final source =
        File('lib/screens/ai_screen.dart').readAsStringSync();

    final start = source.indexOf(
      '} else if (notification is ScrollEndNotification) {',
    );
    expect(start, isNonNegative);

    final end = source.indexOf(
      '        return false; // não consume a notificação',
      start,
    );
    expect(end, isNonNegative);

    final block = source.substring(start, end);

    expect(block, contains('if (nearBottom && _userScrolledUp) {'));
    expect(
      block,
      contains('WidgetsBinding.instance.addPostFrameCallback((_) {'),
    );
    expect(block, contains('if (mounted) setState(() {});'));
    expect(
      block,
      isNot(
        contains(
          'if (mounted) setState(() {}); '
          '// atualiza botão scroll-to-bottom',
        ),
      ),
    );
    expect(
      block.indexOf('WidgetsBinding.instance.addPostFrameCallback'),
      lessThan(block.indexOf('if (mounted) setState(() {});')),
    );
  });

  test('HARD STOP remains withheld during streaming and final-only', () {
    final source = File(
      'lib/screens/ai/widgets/guardia_clinical_response_view.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('abstract final class GuardiaStreamingPresentation'),
    );
    expect(source, contains('stableBeforeHardStop'));
    expect(
      source,
      contains(
        'if (!isStreaming || rawText.isEmpty) return rawText;',
      ),
    );
    expect(
      source,
      contains(
        'return rawText.substring(0, boundary.start).trimRight();',
      ),
    );
    expect(
      source,
      contains(
        'if (!useTypedTreatmentVisual && content.hardStops.isNotEmpty)',
      ),
    );
    expect(source, contains("title: 'HARD STOP'"));
  });
}
