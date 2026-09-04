import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('R13 Study continuation stable action contract', () {
    late String screen;
    setUpAll(() => screen = File('lib/screens/ai_screen.dart').readAsStringSync());

    test('same AI message freezes one tuple', () {
      expect(screen, contains('_stableStudyContinuationByMessageId'));
      expect(screen, contains('_resolveStableStudyContinuationForMessage('));
      expect(screen, contains('[STUDY_CONTINUATION][FROZEN]'));
      expect(screen, contains('_stableStudyContinuationByMessageId[message.id] = resolved;'));
    });

    test('button dispatches direct execution only as provider override', () {
      expect(screen, contains('_buildStudyContinuationDispatchPrompt('));
      expect(screen, contains('[CONTINUACIÓN DE ESTUDIO — EJECUTAR AHORA]'));
      expect(screen, contains('[CONTINUAÇÃO DE ESTUDO — EXECUTAR AGORA]'));
      expect(screen, contains('No hagas preguntas de confirmación'));
      expect(
        screen,
        isNot(contains('No preguntes si el usuario desea dosis')),
      );
      expect(screen, contains('Não faça perguntas de confirmação'));
      expect(
        screen,
        isNot(contains('Não pergunte se o usuário deseja doses')),
      );
      expect(screen, contains('providerInputOverride: dispatchPrompt'));
      expect(screen, contains('rawPrompt: prompt'));
      expect(screen, contains('visibleLabel: studyButtonLabel.trim()'));
      expect(screen, contains('_lastSentStudyPrompt = prompt;'));
    });

    test('override survives debounce and pending queue', () {
      final n = RegExp('providerInputOverride: providerInputOverride').allMatches(screen).length;
      expect(n, greaterThanOrEqualTo(2));
      expect(
        RegExp(
          r'final\s+transportOverride\s*=\s*'
          r'providerInputOverride\?\.trim\(\)\s*;',
          multiLine: true,
        ).hasMatch(screen),
        isTrue,
      );
    });

    test('Plantao case anchor remains fallback', () {
      expect(screen, contains('_bindPlantaoCaseAnchorForButton(trimmed)'));
      expect(screen, contains('fromButton && !_longResponse'));
    });
  });
}
