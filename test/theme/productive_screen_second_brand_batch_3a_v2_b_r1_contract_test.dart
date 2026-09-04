import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

String classBlock(String source, String className) {
  final start = source.indexOf('class $className');
  expect(start, isNonNegative, reason: 'Missing class $className');
  final next = source.indexOf('\nclass ', start + 1);
  return next < 0 ? source.substring(start) : source.substring(start, next);
}

void main() {
  late String recorder;
  late String drugs;
  late String protocols;
  late String home;

  setUpAll(() {
    recorder =
        File('lib/screens/clinical_recorder_sheet.dart').readAsStringSync();
    drugs = File('lib/screens/drugs_screen.dart').readAsStringSync();
    protocols = File('lib/screens/protocols_screen.dart').readAsStringSync();
    home = File('lib/screens/home_screen.dart').readAsStringSync();
  });

  test('Batch 3A markers are retained in all four target files', () {
    const marker =
        'MEDCASES_PRODUCTIVE_SECOND_BRAND_BATCH_3A_V2_B_R1_GENERIC_CONTEXTS';
    expect(recorder, contains(marker));
    expect(drugs, contains(marker));
    expect(protocols, contains(marker));
    expect(home, contains(marker));
  });

  test('Recorder generic IA and confirmation UI uses canonical accent', () {
    final flow = classBlock(recorder, '_FlowOption');
    expect(flow, contains('0xFF0D6B57'));
    expect(flow, isNot(contains('0xFF10B981')));
    expect(flow, isNot(contains('0xFF059669')));

    final review = classBlock(recorder, '_SoapReviewPageState');
    expect(review, contains('0xFF0D6B57'));
    expect(review, isNot(contains('0xFF10B981')));

    final ocrSource = classBlock(recorder, '_OcrSourceBtn');
    expect(ocrSource, contains('0xFF0D6B57'));
  });

  test('Recorder state semantics remain distinct from brand accent', () {
    final page = classBlock(recorder, '_RecorderPageState');
    expect(page, contains('0xFF10B981'));
    expect(page, contains('0xFFEF4444'));
    expect(page, contains('0xFF0D6B57'));
  });

  test('Drugs generic navigation is canonical while clinical palettes remain',
      () {
    final tabs = classBlock(drugs, '_ClinicalTabCard');
    expect(tabs, contains('indicatorColor: const Color(0xFF0D6B57)'));
    expect(tabs, contains('0xFF059669'));

    final suggestions = classBlock(drugs, '_DrugSuggestionDropdown');
    expect(suggestions, contains('0x140D6B57'));
    expect(suggestions, isNot(contains('0xFFECFDF5')));

    expect(drugs, contains('0xFFFFE8A6'));
    expect(drugs, contains('return const Color(0xFF059669);'));
  });

  test(
      'Protocols generic section accents are canonical and severity is preserved',
      () {
    final refs =
        classBlock(protocols, '_SimulationReferencesEvidenceDisclosureState');
    expect(refs, contains('const accent = Color(0xFF0D6B57)'));

    final pearls = classBlock(protocols, '_PearlsCard');
    expect(pearls, contains('0xFF0D6B57'));
    expect(pearls, isNot(contains('0xFF10B981')));

    expect(protocols, contains('severityColor = const Color(0xFF10B981)'));
    expect(protocols, contains('return const Color(0xFF16A34A);'));
    expect(protocols, contains('iconColor: const Color(0xFF7C3AED)'));
  });

  test('Home removes cyan teal AI second-brand identity from selected owners',
      () {
    for (final owner in [
      '_AiBubbleAvatar',
      '_AiBubbleState',
      '_ThinkingDotsState',
      '_HomeIaCardState',
    ]) {
      final block = classBlock(home, owner);
      expect(block, contains('0xFF0D6B57'), reason: owner);
      expect(block, isNot(contains('0xFF00E5FF')), reason: owner);
      expect(block, isNot(contains('0xFF008CA4')), reason: owner);
    }
  });

  test(
      'Home timer and shell branding are canonical without flattening taxonomy',
      () {
    final timer = classBlock(home, '_ShiftTimerBarState');
    expect(timer, contains('0xFF0D6B57'));
    expect(timer, contains('0x140D6B57'));
    expect(timer, isNot(contains('0xFF10B981')));
    expect(timer, isNot(contains('0xFFECFDF5')));

    final timerSheet = classBlock(home, '_ShiftTimerSheetState');
    expect(timerSheet, contains('0xFF0D6B57'));

    final section = classBlock(home, '_HomeSectionHeader');
    expect(section, contains('0xFF0D6B57'));
    expect(section, isNot(contains('0xFF0A7C4E')));

    final searchTile = classBlock(home, '_GlobalSearchResultTile');
    expect(searchTile, contains('0xFF10B981'));
    expect(home, contains('0xFF7C3AED'));
    expect(home, contains('0xFFFFE8A6'));
  });
}
