import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/clinical_thread_manager.dart';

void main() {
  group('M77 clinical new-thread session rotation contract', () {
    test('AppProvider rotates persistence identity only at proven clinical boundary', () {
      final source = File('lib/providers/app_provider.dart').readAsStringSync();

      expect(source, contains('M77_CLINICAL_NEW_THREAD_SESSION_ROTATION_V1'));
      expect(source, contains('var activeSessionCtx = ActiveAiSessionContext('));
      expect(source, contains('!m77ConversationIdentityRotated'));
      expect(source, contains('phase3kHadActiveSession'));
      expect(source, contains('status.action == ThreadAction.newThread'));
      expect(source, contains("status.reason != 'first_message'"));
      expect(source, contains("_currentConversationSessionId = '';"));
      expect(source, contains("_currentConversationTitle = '';"));
      expect(source, contains('_isFirstMessageOfSession = true;'));
      expect(source, contains('sessionId: null,'));

      final helperStart = source.indexOf(
        '// M77_CLINICAL_NEW_THREAD_SESSION_ROTATION_V1',
      );
      final helperEnd = source.indexOf(
        'final qaThreadStatus = _threadManager.evaluate(',
        helperStart,
      );
      expect(helperStart, isNonNegative);
      expect(helperEnd, greaterThan(helperStart));
      final helper = source.substring(helperStart, helperEnd);
      expect(helper, isNot(contains('phase3kResolvedSessionId')));
      expect(source, contains('[M77_SESSION_ROTATION]'));

      final qaEval = source.indexOf('final qaThreadStatus = _threadManager.evaluate(');
      final qaRotate = source.indexOf(
        'm77RotateConversationIdentityOnClinicalBoundary(\n          qaThreadStatus,',
        qaEval,
      );
      final qaClear = source.indexOf('_aiHistory.clear();', qaEval);
      expect(qaEval, isNonNegative);
      expect(qaRotate, greaterThan(qaEval));
      expect(qaClear, greaterThan(qaRotate));

      final mainEval = source.indexOf('final threadStatus = _threadManager.evaluate(');
      final mainRotate = source.indexOf(
        'm77RotateConversationIdentityOnClinicalBoundary(\n        threadStatus,',
        mainEval,
      );
      final mainClear = source.indexOf('_aiHistory.clear();', mainEval);
      expect(mainEval, isNonNegative);
      expect(mainRotate, greaterThan(mainEval));
      expect(mainClear, greaterThan(mainRotate));
    });

    test('thread manager still separates an unrelated explicit pathology', () {
      final manager = ClinicalThreadManager();
      manager.evaluate(
        currentUserText: 'Paciente con IAMCEST confirmado y elevación persistente del ST.',
        isPlantaoMode: true,
      );
      final next = manager.evaluate(
        currentUserText: 'Paciente con hemotórax masivo traumático e hipotensión.',
        isPlantaoMode: true,
      );
      expect(next.action, ThreadAction.newThread);
      expect(next.reason, isNot('first_message'));
    });

    test('dependent IAM follow-up remains in the active thread', () {
      final manager = ClinicalThreadManager();
      manager.evaluate(
        currentUserText: 'Paciente con IAMCEST confirmado y elevación persistente del ST.',
        isPlantaoMode: true,
      );
      final next = manager.evaluate(
        currentUserText: '¿Y cuál es la clasificación?',
        isPlantaoMode: true,
      );
      expect(next.action, ThreadAction.continueThread);
    });
  });
}
