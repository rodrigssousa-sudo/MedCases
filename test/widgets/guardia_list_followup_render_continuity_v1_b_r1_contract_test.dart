import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Guardia list follow-up render continuity V1-B-R1-R1', () {
    late String source;
    late String redBranch;
    late String immediateSection;
    late String visualBlock;

    setUpAll(() {
      source = File(
        'lib/screens/ai/widgets/guardia_clinical_response_view.dart',
      ).readAsStringSync();

      final redStart = source.indexOf(
        "if (trimmed.startsWith('🟥') || trimmed.startsWith('🔴'))",
      );
      final redEnd = source.indexOf(
        'final inline = _inlineSectionFor(trimmed);',
        redStart,
      );

      final sectionStart = source.indexOf(
        "if (value == 'conducta' ||",
      );
      final sectionEnd = source.indexOf(
        "if (value == 'tratamiento' ||",
        sectionStart,
      );

      final visualStart = source.indexOf(
        'if (displayImmediate.isNotEmpty) ...[',
      );
      final visualEnd = source.indexOf(
        'if (allowMedicationPresentation && useTypedTreatmentVisual) ...[',
        visualStart,
      );

      expect(redStart, greaterThanOrEqualTo(0));
      expect(redEnd, greaterThan(redStart));
      expect(sectionStart, greaterThanOrEqualTo(0));
      expect(sectionEnd, greaterThan(sectionStart));
      expect(visualStart, greaterThanOrEqualTo(0));
      expect(visualEnd, greaterThan(visualStart));

      redBranch = source.substring(redStart, redEnd);
      immediateSection = source.substring(sectionStart, sectionEnd);
      visualBlock = source.substring(visualStart, visualEnd);
    });

    test('generic red immediate heading is routed before diagnosis fallback', () {
      expect(
        redBranch,
        contains('final redHeadingSection = _sectionFor(candidate);'),
      );
      expect(
        redBranch,
        contains('redHeadingSection == _RawSection.immediate'),
      );
      expect(
        redBranch,
        contains('section = _RawSection.immediate;'),
      );

      final route = redBranch.indexOf(
        'redHeadingSection == _RawSection.immediate',
      );
      final diagnosis = redBranch.indexOf('diagnosis = candidate;');

      expect(route, greaterThanOrEqualTo(0));
      expect(diagnosis, greaterThan(route));
    });

    test('full generic ES/PT labels are aliases of immediate section', () {
      expect(
        immediateSection,
        contains("value == 'conducta clinica inmediata'"),
      );
      expect(
        immediateSection,
        contains("value == 'conduta clinica imediata'"),
      );
    });

    test('immediate body remains rendered as clinical content', () {
      expect(
        visualBlock,
        contains('for (final item in displayImmediate)'),
      );
      expect(
        visualBlock,
        contains('_BulletLine('),
      );
      expect(
        visualBlock,
        contains('text: item,'),
      );
    });

    test('non-differential immediate section keeps current localized title contract', () {
      expect(
        visualBlock,
        contains("'guardia_immediate_conduct_section'"),
      );
      expect(
        visualBlock,
        contains("'Conducta inmediata'"),
      );
      expect(
        visualBlock,
        contains("'Conduta imediata'"),
      );
    });

    test('differential initial evaluation remains visible', () {
      expect(
        visualBlock,
        contains('if (content.isDifferential ||'),
      );
      expect(
        visualBlock,
        contains('titleProjection.demoteDiagnosisToHypothesis) ...['),
      );
      expect(
        visualBlock,
        contains("'Evaluación inicial'"),
      );
      expect(
        visualBlock,
        contains("'Avaliação inicial'"),
      );
    });

    test('fallback safety behavior remains untouched', () {
      expect(
        source,
        contains('content.fallbackLines.isNotEmpty &&'),
      );
      expect(
        source,
        contains('(widget.isStreaming || !content.hasStructuredContent)'),
      );
    });
  });
}
