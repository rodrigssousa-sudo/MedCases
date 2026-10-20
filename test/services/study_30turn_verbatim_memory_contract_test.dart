import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/clinical_thread_manager.dart';

void main() {
  group('Study 30-turn verbatim memory', () {
    test('keeps last 30 exchanges verbatim', () {
      final history = List<Map<String, String>>.generate(
        70,
        (i) => <String, String>{
          'role': i.isEven ? 'user' : 'assistant',
          'content': 'entry_$i',
        },
      );
      const status = ClinicalThreadStatus(
        action: ThreadAction.continueThread,
        reason: 'same_topic',
        topic: 'asma',
      );

      final result = ClinicalThreadManager.buildThreadHistory(
        fullHistory: history,
        status: status,
        isPlantaoMode: false,
        currentTaskLabel: 'geral',
      );

      expect(result, hasLength(60));
      expect(result.first['content'], 'entry_10');
      expect(result.last['content'], 'entry_69');
    });

    test('automatic inactivity timeout is Plantao-only', () {
      final source =
          File('lib/services/clinical_thread_manager.dart').readAsStringSync();

      // Match the condition, not dart format's physical line breaks.
      expect(
        RegExp(
          r'if\s*\(isPlantaoMode\s*&&\s*_activeTopic\.isNotEmpty\s*&&\s*'
          r'_lastActivityMs\s*>\s*0\s*&&\s*'
          r'\(now\s*-\s*_lastActivityMs\)\s*>\s*kThreadTimeoutMs\)',
        ).hasMatch(source),
        isTrue,
      );
    });

    test('task label changes do not wipe Study transport', () {
      const status = ClinicalThreadStatus(
        action: ThreadAction.continueThread,
        reason: 'same_topic',
        topic: 'asma',
      );
      final history = <Map<String, String>>[
        {'role': 'user', 'content': 'asma'},
        {'role': 'assistant', 'content': 'resumo'},
        {'role': 'user', 'content': 'e a fisiopatologia?'},
        {'role': 'assistant', 'content': 'fisiopatologia'},
        {'role': 'user', 'content': 'e a dose?'},
        {'role': 'assistant', 'content': 'dose'},
      ];

      final a = ClinicalThreadManager.buildThreadHistory(
        fullHistory: history,
        status: status,
        isPlantaoMode: false,
        currentTaskLabel: 'geral',
      );
      final b = ClinicalThreadManager.buildThreadHistory(
        fullHistory: history,
        status: status,
        isPlantaoMode: false,
        currentTaskLabel: 'dose',
      );

      expect(a, isNotEmpty);
      expect(b, hasLength(history.length));
    });

    test('preserves Study window and Plantao case anchor plus recent turns',
        () {
      final source =
          File('lib/services/clinical_thread_manager.dart').readAsStringSync();

      expect(source, contains('static const int kMaxStudyTurns = 30;'));
      expect(source, contains('strategy=verbatim_30_exchanges'));
      expect(source, isNot(contains('strategy=micro_window_4turns')));
      expect(source, isNot(contains('_lastStudyActivityMs')));
      expect(source, isNot(contains('_lastTaskLabel')));
      expect(source, contains('static String _lastDrugTarget'));
      expect(ClinicalThreadManager.kMaxContinuationTurns, 2);
      expect(source, contains('strategy=case_anchor_plus_recent'));

      final history = List<Map<String, String>>.generate(
        12,
        (i) => {'role': i.isEven ? 'user' : 'assistant', 'content': 'turn_$i'},
      );
      const continuation = ClinicalThreadStatus(
        action: ThreadAction.continueThread,
        reason: 'same_topic',
        topic: 'synthetic',
      );
      final plantao = ClinicalThreadManager.buildThreadHistory(
        fullHistory: history,
        status: continuation,
        isPlantaoMode: true,
      );
      expect(plantao, [...history.take(2), ...history.skip(8)]);
      expect(
        ClinicalThreadManager.buildThreadHistory(
          fullHistory: history,
          status: const ClinicalThreadStatus(
            action: ThreadAction.newThread,
            reason: 'new_case',
            topic: 'synthetic_other',
          ),
          isPlantaoMode: true,
        ),
        isEmpty,
      );

      final methodStart = source.indexOf(
        'static List<Map<String, String>> buildThreadHistory({',
      );
      expect(methodStart, greaterThanOrEqualTo(0));
      final bodyMarker = source.indexOf('}) {', methodStart);
      expect(bodyMarker, greaterThan(methodStart));
      final start = source.indexOf('if (!isPlantaoMode)', bodyMarker);
      final end = source.indexOf('if (!status.isContinuation)', start);
      expect(start, greaterThan(bodyMarker));
      expect(end, greaterThan(start));
      final studyBlock = source.substring(start, end);
      expect(studyBlock, isNot(contains('transport_history_cleared')));
      expect(studyBlock, isNot(contains('return <Map<String, String>>[];')));
    });
  });
}
