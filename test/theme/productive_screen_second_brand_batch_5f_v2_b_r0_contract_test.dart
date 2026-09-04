import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String mainSource;
  late String admin;
  late String mobileAi;
  late String studyContinuation;
  late String cardio;
  late String avaliacao;

  setUpAll(() {
    mainSource = File('lib/main.dart').readAsStringSync();
    admin = File(
      'lib/screens/admin_clinical_guide_editor_screen.dart',
    ).readAsStringSync();
    mobileAi = File(
      'lib/screens/ai/widgets/mobile_ai_action_bar.dart',
    ).readAsStringSync();
    studyContinuation = File(
      'lib/screens/ai/widgets/study_continuation_button.dart',
    ).readAsStringSync();
    cardio = File('lib/screens/cardio_tools_screen.dart').readAsStringSync();
    avaliacao = File('lib/screens/avaliacao_screen.dart').readAsStringSync();
  });

  test('Notes audio workspace generic UI is canonical, success stays semantic',
      () {
    expect(
      mainSource,
      contains(
        'final text = dark ? const Color(0xFF0D6B57) : const Color(0xFF0D6B57);',
      ),
    );
    expect(mainSource, contains('const accent = Color(0xFF0D6B57);'));
    expect(
      mainSource,
      contains(
        'backgroundColor: error ? const Color(0xFFB91C1C) : const Color(0xFF047857)',
      ),
    );
    expect(
      mainSource,
      contains('static const _kGreen = Color(0xFF10B981);'),
    );
  });

  test('Admin editor splits generic brand from semantic ready status', () {
    expect(
      admin,
      contains('static const _accentBrand = Color(0xFF0D6B57);'),
    );
    expect(admin, isNot(contains('static const _green = Color(0xFF059669);')));
    expect(
      RegExp(r'backgroundColor: const Color\(0xFF0D6B57\),')
          .allMatches(admin)
          .length,
      greaterThanOrEqualTo(2),
    );

    // Ready state remains semantic green.
    expect(
      admin,
      contains('ready\n                          ? const Color(0xFF059669)'),
    );
  });

  test('Mobile IA label and Study continuation CTA are canonical', () {
    expect(mobileAi, isNot(contains('0xFF00C781')));
    expect(mobileAi, isNot(contains('0xFF059669')));
    expect(
      RegExp(r'Color\(0xFF0D6B57\)').allMatches(mobileAi).length,
      greaterThanOrEqualTo(2),
    );

    expect(studyContinuation, isNot(contains('0xFF34D399')));
    expect(studyContinuation, isNot(contains('0xFF0F8F6A')));
    expect(
      studyContinuation,
      contains(
        'widget.dark ? const Color(0xFF0D6B57) : const Color(0xFF0D6B57);',
      ),
    );
  });

  test('Cardio active selection light state is canonical', () {
    expect(
      cardio,
      contains(
        '? const Color(0xFF0D6B57)\n                                : const Color(0xFF111318))',
      ),
    );
  });

  test('Avaliacao active UI canonicalizes without flattening Geral taxonomy',
      () {
    expect(
      avaliacao,
      contains(
        'dark ? const Color(0xFF0D6B57) : const Color(0xFF0D6B57);',
      ),
    );
    expect(
      avaliacao,
      contains(
        'const Color(0xFF0D6B57).withValues(alpha: 0.10)',
      ),
    );
    expect(
      avaliacao,
      contains(
        "title: 'Geral',",
      ),
    );
    expect(
      avaliacao,
      contains(
        'color: Color(0xFF10B981),\n    questions:',
      ),
    );
  });
}
