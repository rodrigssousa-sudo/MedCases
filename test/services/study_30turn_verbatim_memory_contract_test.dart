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

      expect(
        source,
        contains(
          'if (isPlantaoMode && _activeTopic.isNotEmpty && '
          '_lastActivityMs > 0 && '
          '(now - _lastActivityMs) > kThreadTimeoutMs) {',
        ),
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

    test('source contract preserves Plantao minimal policy', () {
      final source =
          File('lib/services/clinical_thread_manager.dart').readAsStringSync();

      expect(source, contains('static const int kMaxStudyTurns = 30;'));
      expect(source, contains('strategy=verbatim_30_exchanges'));
      expect(source, isNot(contains('strategy=micro_window_4turns')));
      expect(source, isNot(contains('_lastStudyActivityMs')));
      expect(source, isNot(contains('_lastTaskLabel')));
      expect(source, contains('static String _lastDrugTarget'));
      expect(source, contains('static const int kMaxContinuationTurns = 2;'));
      expect(source, contains('strategy=thread_minimal'));
      expect(
        source,
        contains(
          'if (isPlantaoMode && _activeTopic.isNotEmpty && '
          '_lastActivityMs > 0 && '
          '(now - _lastActivityMs) > kThreadTimeoutMs) {',
        ),
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
