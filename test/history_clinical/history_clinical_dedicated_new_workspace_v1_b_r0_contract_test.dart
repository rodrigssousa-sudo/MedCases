import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();

String between(
  String source,
  String start,
  String end,
  String label,
) {
  final a = source.indexOf(start);
  final b = source.indexOf(end, a + start.length);
  expect(a, greaterThanOrEqualTo(0), reason: '$label start');
  expect(b, greaterThan(a), reason: '$label end');
  return source.substring(a, b);
}

String topLevelClassSection(
  String source,
  String classDeclaration,
  String label,
) {
  final start = source.indexOf(classDeclaration);
  expect(start, greaterThanOrEqualTo(0), reason: '$label start');

  final nextClass = RegExp(
    r'^class\s+',
    multiLine: true,
  ).firstMatch(source.substring(start + classDeclaration.length));

  final end = nextClass == null
      ? source.length
      : start + classDeclaration.length + nextClass.start;

  expect(end, greaterThan(start), reason: '$label end');
  return source.substring(start, end);
}

void main() {
  late String history;
  late String recorder;
  late String state;
  late String workspace;
  late String emptyState;
  late String card;

  setUpAll(() {
    history = read('lib/screens/history_screen.dart');
    recorder = read('lib/screens/clinical_recorder_sheet.dart');

    state = between(
      history,
      'class _HistoryScreenState extends State<HistoryScreen>',
      'class _HcTopbarBg',
      '_HistoryScreenState',
    );
    workspace = between(
      history,
      'class _NewHistoryWorkspace extends StatelessWidget',
      'class _NewHistoryFlowCard extends StatelessWidget',
      '_NewHistoryWorkspace',
    );
    emptyState = topLevelClassSection(
      history,
      'class _EmptyHistoryState extends StatelessWidget',
      '_EmptyHistoryState',
    );
    card = between(
      history,
      'class _HistoryCard extends StatelessWidget',
      'class _HistoryDetail extends StatefulWidget',
      '_HistoryCard',
    );
  });

  group('Historia Clinica +NUEVA inline supersedes old dedicated route', () {
    test('old dedicated route is gone and third inline tab is productive', () {
      expect(state, contains('length: 3'));
      expect(state, contains('initialIndex: 2'));
      expect(state, contains('newHistoryTab,'));
      expect(
        state,
        isNot(
          matches(
            RegExp(
              r'_startNewHistory[\s\S]{0,700}Navigator\.of\(context\)\.push',
            ),
          ),
        ),
      );
      expect(workspace, isNot(contains('Scaffold(')));
    });

    test('workspace exposes exact three creation flows without false info card',
        () {
      expect(
        RegExp(r'\b_NewHistoryFlowCard\(').allMatches(workspace).length,
        3,
      );

      for (final token in <String>[
        'Grabar consulta y transcribir todo',
        'Gravar consulta e transcrever tudo',
        'Completar manualmente',
        'Preencher manualmente',
        'Grabar por bloques SOAP',
        'Gravar por blocos SOAP',
        'ClinicalRecorderSheet.openContinuousRecorder(',
        'onTap: _openManual',
        'ClinicalRecorderSheet.openSoapBlocksRecorder(',
      ]) {
        expect(workspace, contains(token), reason: token);
      }

      expect(workspace, isNot(contains('Icons.note_add_outlined')));
      expect(workspace, isNot(contains('LinearGradient(')));
      expect(workspace, isNot(contains('BoxShadow(')));
    });

    test('legacy empty state still has no orange central creation CTA', () {
      for (final token in <String>[
        'Color(0xFFF27405)',
        'Color(0xFFFF9A3C)',
        'Color(0xFFD46500)',
        "'new_history_btn'",
        'final VoidCallback onNew',
      ]) {
        expect(emptyState, isNot(contains(token)), reason: token);
      }
      expect(emptyState, contains('Use + NUEVA para comenzar.'));
      expect(emptyState, contains('Use + NOVA para começar.'));
    });

    test('recorder route APIs and productive recorder page remain preserved',
        () {
      for (final token in <String>[
        'MEDCASES_HC_NEW_HISTORY_WORKSPACE_V1_B_R0_RECORDER_ROUTE_API',
        'static Future<void> openContinuousRecorder(',
        'static Future<void> openSoapBlocksRecorder(',
        'mode: RecorderMode.continuous',
        'mode: RecorderMode.soapBlocks',
        'builder: (_) => _RecorderPage(',
        'onSoapData: onSoapData',
        'static Future<void> showFlowSelection(',
      ]) {
        expect(recorder, contains(token), reason: token);
      }
    });

    test('retained history card polish remains unchanged', () {
      expect(card, contains('margin: const EdgeInsets.fromLTRB(16, 0, 16, 8)'));
      expect(card, contains('borderRadius: BorderRadius.circular(12)'));
      expect(
        card,
        contains(
          'color: isDark ? const Color(0xFF252930) : const Color(0xFFFFFFFF)',
        ),
      );
      expect(card, isNot(contains('BoxShadow(')));
    });
  });
}
