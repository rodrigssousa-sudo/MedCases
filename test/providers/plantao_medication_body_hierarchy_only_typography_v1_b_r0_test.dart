import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Plantao medication body hierarchy-only typography', () {
    late String source;
    late String medicationBlock;
    late String sectionTitleBlock;
    late String bulletBlock;

    setUpAll(() {
      source = File(
        'lib/screens/ai/widgets/guardia_clinical_response_view.dart',
      ).readAsStringSync();

      final medicationStart = source.indexOf(
        'class _MedicationLine extends StatelessWidget',
      );
      final medicationEnd = source.indexOf(
        'class _MedicationTextParts',
        medicationStart,
      );
      expect(medicationStart, greaterThanOrEqualTo(0));
      expect(medicationEnd, greaterThan(medicationStart));
      medicationBlock = source.substring(medicationStart, medicationEnd);

      final sectionStart = source.indexOf(
        'class _SectionTitle extends StatelessWidget',
      );
      final sectionEnd = source.indexOf(
        'class _MedicationLine extends StatelessWidget',
      );
      sectionTitleBlock = source.substring(sectionStart, sectionEnd);

      final bulletStart = source.indexOf(
        'class _BulletLine extends StatelessWidget',
      );
      final bulletEnd = source.indexOf(
        'class _PinnedLine extends StatelessWidget',
      );
      bulletBlock = source.substring(bulletStart, bulletEnd);
    });

    test('medication body has no w800 spans', () {
      expect(
        medicationBlock,
        contains('M78_MEDICATION_BODY_HIERARCHY_ONLY_V1'),
      );
      expect(
        medicationBlock,
        isNot(contains('M67_MEDICATION_CORE_FULL_BOLD_V1')),
      );
      expect(medicationBlock, isNot(contains('FontWeight.w800')));
    });

    test(
      'drug and qualifier stay regular while standalone dose rows may be emphasized',
      () {
        final regularCount = RegExp(
          r'fontWeight:\s*FontWeight\.w400',
        ).allMatches(medicationBlock).length;
        expect(regularCount, greaterThanOrEqualTo(3));
      },
    );

    test('section and subsection hierarchy remains emphasized', () {
      expect(sectionTitleBlock, contains('FontWeight.w700'));
      expect(sectionTitleBlock, contains('FontWeight.w600'));
    });

    test('ordinary bullet body remains regular', () {
      expect(bulletBlock, contains('fontWeight: FontWeight.w400'));
    });

    test('UTF16 final boundary and old divider contract remain intact', () {
      expect(source, contains('MEDCASES_TRUE_LAST_UTF16_RENDER_BOUNDARY_V1'));
      expect(source, isNot(contains('guardia_divider_before_medication')));
    });
  });
}
