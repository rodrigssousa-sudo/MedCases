import '../pediatrics/pediatric_navigation_runtime_harness.dart';
import '../history_clinical/history_release_runtime_harness.dart';
import '../architecture/architectural_runtime_harness.dart';
import '../tools/tools_hub_runtime_harness.dart';
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

  testWidgets("Batch 2A canonicalizes audited generic History owners",
      (tester) async {
    for (final dark in [false, true]) {
      await verifyHistoryNavigation(tester, dark: dark);
      await verifyHistoryExamPalette(tester, dark: dark);
      await verifyHistoryVitals(tester, dark: dark);
      await verifyHistoryOcrPicker(tester, dark: dark);
    }
    await verifyHistoryEvolution(tester);
    await verifyHistoryTopbar(tester);
  });

  testWidgets("Batch 2A canonicalizes audited generic Tools owners",
      (tester) async {
    for (final dark in [false, true]) {
      await verifyToolsHub(tester, dark: dark);
    }
    for (final o in <String>[
      '_PediatTabRow',
      '_PrescriptionsTabState',
      '_PedCompactInput',
      '_PedFlatSection',
      '_PedSexSelector',
      '_PedGrowthIndicatorToggle',
      '_PedPewsSelectorFlat',
      '_PedCheckRow',
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

    expect(tools, isNot(contains('class _SourcesButton')));
    await verifyPediatricGeometry(tester);
  });

  testWidgets("History semantic outcome/success greens remain preserved",
      (tester) async {
    expect(
        history,
        contains(
            'success ? const Color(0xFF10B981) : const Color(0xFFB91C1C)'));
    expect(
        history,
        contains(
            "case 'alta':\n        return const Color(0xFF10B981); // verde alta"));
    for (final dark in [false, true]) {
      await verifyHistoryOutcomePalette(tester, dark: dark);
    }
  });

  testWidgets("Tools semantic score/reference palettes remain preserved",
      (tester) async {
    expect(
        tools,
        contains(
          'if (score <= 1) return const Color(0xFF059669);',
        ));

    expect(tools, contains('0xFFD97706'));
    expect(tools, contains('0xFFDC2626'));

    await verifyPediatricNavigation(tester);
  });

  testWidgets("mixed semantic-heavy owners stay deferred", (tester) async {
    expect(block(history, '_HistoryEditorState'), contains('0xFF10B981'));
    expect(block(history, '_HistoryCard'), contains('0xFF10B981'));
    await verifyHistoryOutcomePalette(tester);
    expect(history, isNot(contains('class _OutcomeBadge')));
    expect(block(tools, '_PediatricsTabContentState'), contains('0xFF059669'));
    expect(block(tools, '_PedGrowthChartPainter'), contains('0xFF10B981'));
  });
}
