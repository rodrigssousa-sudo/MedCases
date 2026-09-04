import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

String block(String source, String owner) {
  final s = source.indexOf('class $owner');
  expect(s, isNonNegative, reason: owner);
  final n = source.indexOf('\nclass ', s + 1);
  return source.substring(s, n < 0 ? source.length : n);
}

void main() {
  late String history;
  late String tools;

  setUpAll(() {
    history = File('lib/screens/history_screen.dart').readAsStringSync();
    tools = File('lib/screens/tools_screen.dart').readAsStringSync();
  });

  test('Batch 2A canonicalizes audited generic History owners', () {
    for (final o in <String>[
      '_HcTabRow',
      '_HcFlatTabState',
      '_HistoryHeroHeader',
      '_SmartDictaphoneButton',
      '_MicControlBar',
      '_CentralMicButtonState',
      '_DetailCard',
      '_SectionBlock',
      '_EvolutionEditorCardState',
      '_VitalSignsWidgetState',
      '_EcgStructuredWidgetState',
      '_LabStructuredWidgetState',
      '_OcrExamButton',
    ]) {
      final b = block(history, o);
      expect(b, contains('0xFF0D6B57'), reason: o);
      expect(b, isNot(contains('0xFF10B981')), reason: o);
      expect(b, isNot(contains('0xFF34D399')), reason: o);
      expect(b, isNot(contains('0xFF047857')), reason: o);
    }
  });

  test('Batch 2A canonicalizes audited generic Tools owners', () {
    for (final o in <String>[
      '_ToolsFlatTabState',
      '_PediatTabRow',
      '_PrescriptionsTabState',
      '_PedCompactInput',
      '_PedFlatSection',
      '_PedSexSelector',
      '_PedGrowthIndicatorToggle',
      '_PedPewsSelectorFlat',
      '_PedCheckRow',
      '_SourcesButton',
      '_LabImportCard',
      '_VasoRefRow',
    ]) {
      final b = block(tools, o);
      expect(b, contains('0xFF0D6B57'), reason: o);
      expect(b, isNot(contains('0xFF10B981')), reason: o);
      expect(b, isNot(contains('0xFF34D399')), reason: o);
      expect(b, isNot(contains('0xFF047857')), reason: o);
      expect(b, isNot(contains('0xFF00E5FF')), reason: o);
      expect(b, isNot(contains('0xFF16A34A')), reason: o);
    }
  });

  test('History semantic outcome/success greens remain preserved', () {
    expect(
        history,
        contains(
          'success ? const Color(0xFF10B981) : const Color(0xFFB91C1C)',
        ));
    expect(
        history,
        contains(
          "case 'alta':\n        return const Color(0xFF10B981); // verde alta",
        ));
    expect(
        history,
        contains(
          'hasFinal ? const Color(0xFF10B981) : const Color(0xFF92400E)',
        ));
  });

  test('Tools semantic score/reference palettes remain preserved', () {
    expect(
        tools,
        contains(
          'if (score <= 1) return const Color(0xFF059669);',
        ));
    expect(tools, contains("case 'Diretriz':"));
    expect(tools, contains('0xFF7C3AED'));
    expect(tools, contains('0xFFD97706'));
    expect(tools, contains('0xFFDC2626'));
  });

  test('mixed semantic-heavy owners stay deferred', () {
    expect(block(history, '_HistoryEditorState'), contains('0xFF10B981'));
    expect(block(history, '_HistoryCard'), contains('0xFF10B981'));
    expect(block(history, '_OutcomeBadge'), contains('0xFFC5A365'));
    expect(block(tools, '_PediatricsTabContentState'), contains('0xFF059669'));
    expect(block(tools, '_PedGrowthChartPainter'), contains('0xFF10B981'));
  });
}
