import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  String block(String startToken, String endToken) {
    final start = source.indexOf(startToken);
    final end = source.indexOf(endToken, start + 1);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    return source.substring(start, end);
  }

  setUpAll(() {
    source = File('lib/screens/vaccines_screen.dart').readAsStringSync();
  });

  test('final square geometry marker is present', () {
    expect(
      source,
      contains('MEDCASES_VACCINES_SQUARE_1PX_GUTTER_3PX_GAP_V1_B_R0_R1'),
    );
  });

  test('root navigation cards are square, 1px inset and 3px apart', () {
    final b = block(
      'class _ClinicalNavigationRow',
      'class _AgeGroupBlock',
    );

    expect(b, contains('margin: const EdgeInsets.fromLTRB(1, 0, 1, 3)'));
    expect(b, contains('borderRadius: BorderRadius.zero'));
    expect(b, isNot(contains('BorderRadius.circular(14)')));
  });

  test('routine age cards are square, 1px inset and 3px apart', () {
    final b = block(
      'class _AgeGroupBlock',
      'class _DoseRow',
    );

    expect(b, contains('margin: const EdgeInsets.fromLTRB(1, 0, 1, 3)'));
    expect(b, contains('borderRadius: BorderRadius.zero'));
    expect(b, isNot(contains('BorderRadius.circular(14)')));
  });

  test('seasonal pregnancy and special cards use final geometry', () {
    final b = block(
      'class _VaccineListRow',
      'class _VaccineDetail',
    );

    expect(b, contains('margin: const EdgeInsets.fromLTRB(1, 0, 1, 3)'));
    expect(b, contains('borderRadius: BorderRadius.zero'));
    expect(b, isNot(contains('BorderRadius.circular(14)')));
  });

  test('detail surface has maximum 1px lateral inset', () {
    final b = block(
      'class _VaccineDetail',
      'class _ClinicalGate',
    );

    expect(b, contains('padding: const EdgeInsets.fromLTRB(1, 18, 1, 150)'));
    expect(b, contains('borderRadius: BorderRadius.zero'));
    expect(
      b,
      contains(
        'const SizedBox(height: 3),\n        _DetailSection(',
      ),
    );
  });

  test('detail and bullet cards are square with 3px vertical gap', () {
    final detail = block(
      'class _DetailSection',
      'class _BulletSection',
    );
    final bullet = block(
      'class _BulletSection',
      'class _ReferenceSection',
    );

    for (final b in [detail, bullet]) {
      expect(b, contains('margin: const EdgeInsets.only(bottom: 3)'));
      expect(b, contains('borderRadius: BorderRadius.zero'));
      expect(b, isNot(contains('BorderRadius.circular(14)')));
    }
  });

  test('reference and assessment cards are square', () {
    final reference = block(
      'class _ReferenceSection',
      'Color _vaccineCardSurface',
    );
    final assessment = block(
      'class _AssessmentNotice',
      'class _PageHeading',
    );

    expect(reference, contains('borderRadius: BorderRadius.zero'));
    expect(
        assessment, contains('margin: const EdgeInsets.fromLTRB(1, 0, 1, 0)'));
    expect(assessment, contains('borderRadius: BorderRadius.zero'));
  });

  test('root last-card to assessment notice spacing is 3px', () {
    expect(
      source,
      contains(
        'const SizedBox(height: 3),\n        _AssessmentNotice(dark: dark, isEs: isEs),',
      ),
    );
  });

  test('card palette remains unchanged from approved R0', () {
    expect(
      source,
      contains('dark ? const Color(0xFF252930) : const Color(0xFFFFFFFF)'),
    );
    expect(
      source,
      contains('dark ? const Color(0xFF374151) : const Color(0xFFDCE3E8)'),
    );
    expect(
      source,
      contains('dark ? const Color(0xFF2A2F37) : const Color(0xFFF7F9FA)'),
    );
  });

  test('obsolete flat divider and deprecated opacity calls are gone', () {
    expect(source, isNot(contains('class _ClinicalDivider')));
    expect(source, isNot(contains('.withOpacity(')));
    expect(source, contains('.withValues(alpha: 0.70)'));
  });

  test('canonical vaccine navigation and PT ES remain intact', () {
    expect(source, contains('enum _VaccinesView'));
    expect(source, contains('_VaccinesView.root'));
    expect(source, contains('_VaccinesView.routine'));
    expect(source, contains('_VaccinesView.seasonal'));
    expect(source, contains('_VaccinesView.pregnancy'));
    expect(source, contains('_VaccinesView.special'));
    expect(source, contains('_VaccinesView.detail'));
    expect(source, contains("isEs ? 'VACUNA' : 'VACINA'"));
    expect(source, contains('vaccineCatalogForLanguage(lang)'));
  });
}
