import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/ai/widgets/clinical_markdown_presentation.dart';

void main() {
  group('Study gold premium reading density V1-B-R0', () {
    test('recuo de parágrafo é opt-out somente para Study', () {
      const input = 'Parágrafo clínico de estudo.';

      final legacy = ClinicalMarkdownPresentation.format(input);
      final study = ClinicalMarkdownPresentation.format(
        input,
        indentParagraphs: false,
      );

      expect(
        legacy.startsWith(ClinicalMarkdownPresentation.firstLineIndent),
        isTrue,
      );
      expect(
        study.startsWith(ClinicalMarkdownPresentation.firstLineIndent),
        isFalse,
      );
      expect(study, input);
    });

    test('AiScreen marca somente AiBubble com o modo Study atual', () {
      final source = File('lib/screens/ai_screen.dart').readAsStringSync();

      expect(
        'studyMode: _longResponse,'.allMatches(source).length,
        3,
      );

      final aiBubbleStart = source.indexOf('AiBubble(');
      expect(aiBubbleStart, greaterThanOrEqualTo(0));
      final aiBubbleTail = source.substring(
        aiBubbleStart,
        (aiBubbleStart + 1800).clamp(0, source.length),
      );
      expect(
        'studyMode: _longResponse,'.allMatches(aiBubbleTail).length,
        1,
      );

      expect(source, contains('visible: !_longResponse'));
      expect(source, contains('study_user_hidden'));
      expect(source, contains('GuardiaClinicalResponseView('));
    });

    test('AiBubble propaga studyMode sem bifurcar streaming', () {
      final source = File(
        'lib/screens/ai/widgets/ai_bubble.dart',
      ).readAsStringSync();

      expect(source, contains('final bool studyMode;'));
      expect(source, contains('this.studyMode = false,'));
      expect(source, contains('studyMode: widget.studyMode,'));
      expect(source, contains('streamingTextNotifier'));
      expect(source, contains('onVisualComplete'));
      expect(source, contains('StreamingTextDrain'));
    });

    test('AiBlockBubble usa densidade Study e preserva fallback legado', () {
      final source = File(
        'lib/screens/ai/widgets/ai_block_bubble.dart',
      ).readAsStringSync();

      for (final token in const <String>[
        'final bool studyMode;',
        'this.studyMode = false,',
        'indentParagraphs: false',
        'fontSize: studyMode ? 13.2 : 13.5',
        'height: studyMode ? 1.42 : 1.55',
        'fontSize: studyMode ? 13.7 : 13.9',
        'height: studyMode ? 1.30 : 1.35',
        'fontSize: studyMode ? 13.4 : 13.6',
        'height: studyMode ? 1.32 : 1.4',
        'blockSpacing: studyMode ? 8 : 12',
        'listIndent: studyMode ? 16 : 20',
        'ClinicalMarkdownPresentation.format(normalizedText)',
      ]) {
        expect(source, contains(token), reason: token);
      }

      // H1 principal permanece no padrão homologado.
      expect(source, contains('fontSize: 14.2'));
      expect(source, contains('height: 1.3'));
    });

    test('botão de continuidade fica compacto sem alterar comportamento', () {
      final source = File(
        'lib/screens/ai/widgets/study_continuation_button.dart',
      ).readAsStringSync();

      for (final token in const <String>[
        'EdgeInsets.fromLTRB(12, 8, 12, 0)',
        'BorderRadius.circular(12)',
        'BoxConstraints(minHeight: 44)',
        'EdgeInsets.symmetric(horizontal: 14, vertical: 8)',
        'fontSize: 13.0',
        'height: 1.25',
        'SizedBox(width: 8)',
        'size: 18',
        'Duration(milliseconds: 600)',
        '_cleanLabel',
        '_tapLocked',
      ]) {
        expect(source, contains(token), reason: token);
      }
    });

    test('não introduz regra clínica, prompt ou renderer Guardia', () {
      final block = File(
        'lib/screens/ai/widgets/ai_block_bubble.dart',
      ).readAsStringSync();
      final button = File(
        'lib/screens/ai/widgets/study_continuation_button.dart',
      ).readAsStringSync();

      for (final forbidden in const <String>[
        'FirebaseFirestore',
        'sendAiMessage(',
        'StudyContinuationResolver',
        'GuardiaClinicalResponseView',
      ]) {
        expect(block, isNot(contains(forbidden)), reason: forbidden);
        expect(button, isNot(contains(forbidden)), reason: forbidden);
      }
    });
  });
}
