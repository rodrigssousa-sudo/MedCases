import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

String classSlice(String source, String className) {
  final start = source.indexOf('class $className');
  expect(start, greaterThanOrEqualTo(0), reason: 'Classe ausente: $className');
  final next = source.indexOf('\nclass ', start + 10);
  return source.substring(start, next < 0 ? source.length : next);
}

void main() {
  late String mainSource;
  late String history;

  setUpAll(() {
    mainSource = File('lib/main.dart').readAsStringSync();
    history = File('lib/screens/history_screen.dart').readAsStringSync();
  });

  test(
      'editor mode colors the real MainShell top inset without rebuilding IndexedStack child',
      () {
    expect(
        mainSource,
        contains(
            'HISTORY_CLINICAL_V1_C_R14_R4_EDITOR_TOP_INSET_LIGHT_CONTINUITY'));
    expect(mainSource, contains('valueListenable: HistoryScreen.editorActive'));
    expect(mainSource, contains('historyEditorOpen'));
    expect(mainSource, contains('const Color(0xFFECF1F3)'));
    expect(mainSource, contains('child: child!'));
    expect(mainSource, contains('MediaQuery.of(context).padding.top'));
    expect(mainSource, contains('IndexedStack('));
  });

  test(
      'MicControlBar exposes light dock, panel and text while retaining original dark values',
      () {
    final mic = classSlice(history, '_MicControlBar');
    for (final token in <String>[
      'HISTORY_CLINICAL_V1_C_R14_R4_MIC_DOCK_LIGHT_CLOSURE',
      'final micDockDark = Theme.of(context).brightness == Brightness.dark',
      'const Color(0xFFECF1F3)',
      'const Color(0xFF05070A)',
      'const Color(0xFF4B5563)',
      'const Color(0xFFD8E0E7)',
      'const Color(0xFF1A1D23)',
      'const Color(0xFF14213D)',
      'color: micDockBackground',
      'color: micPanelBackground',
    ]) {
      expect(mic, contains(token), reason: 'Contrato ausente: $token');
    }
  });

  test('callbacks, keyboard toolbar and clinical flows remain present', () {
    final mic = classSlice(history, '_MicControlBar');
    for (final token in <String>[
      'onToggleExpand',
      'onTapSmart',
      'onTapRelato',
      'onOrganizarIA',
      'onPrevField',
      'onNextField',
      'numericKeyboardMode',
      'keyboardTextMode',
      "'Próximo'",
      "'OK'",
    ]) {
      expect(mic, contains(token), reason: 'Fluxo removido: $token');
    }
    expect(history, contains('_toggleSmartDictaphone'));
    expect(history, contains('_toggleRelatoLivre'));
    expect(history, contains('_showOrganizarIASheet'));
    expect(history, contains('_openOcrPicker'));
    expect(history, contains('saveHistory('));
  });

  test('global footer and navigation ownership remain in MainShell', () {
    expect(
        mainSource, contains('class _FloatingFooter extends StatefulWidget'));
    expect(mainSource, contains('AiScreen.chatKeyboardOpen'));
    expect(RegExp(r'\bHistoryScreen\s*\(').allMatches(mainSource).length, 1);
    expect(history, isNot(contains('_FloatingFooter(')));
  });
}
