import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String history;
  late String tools;

  setUpAll(() {
    history = File('lib/screens/history_screen.dart').readAsStringSync();
    tools = File('lib/screens/tools_screen.dart').readAsStringSync();
  });

  test('Batch 2C marker and canonical accent are present', () {
    expect(
      history,
      contains(
        'MEDCASES_PRODUCTIVE_SECOND_BRAND_BATCH_2C_V2_B_R1_R1_LINE_SCOPED_ALLOWLIST',
      ),
    );
    expect(
      tools,
      contains(
        'MEDCASES_PRODUCTIVE_SECOND_BRAND_BATCH_2C_V2_B_R1_R1_LINE_SCOPED_ALLOWLIST',
      ),
    );
    expect(history, contains('0xFF0D6B57'));
    expect(tools, contains('0xFF0D6B57'));
  });

  test('History generic actions use canonical MedCases accent', () {
    expect(
      history,
      matches(
        RegExp(
          r'_dateFilter\s*!=\s*null[\s\S]{0,220}\?\s*const Color\(0xFF0D6B57\)',
        ),
      ),
    );
    expect(
      history,
      matches(
        RegExp(
          r'Icons\.check_circle_outline_rounded[\s\S]{0,160}Color\(0xFF0D6B57\)',
        ),
      ),
    );
    expect(
      history,
      matches(
        RegExp(
          r'Icons\.edit_rounded[\s\S]{0,160}Color\(0xFF0D6B57\)',
        ),
      ),
    );
    expect(
      history,
      contains('static const _kGreen = Color(0xFF0D6B57);'),
    );
  });

  test('History editor CTA and public-state controls are canonicalized', () {
    expect(
      history,
      matches(
        RegExp(
          r"Color\(0xFF0D6B57\)[\s\S]{0,220}_hcT\(widget\.p\.lang,\s*'save_btn'\)",
        ),
      ),
    );
    expect(
      history,
      matches(
        RegExp(
          r'_draft\.isPublic[\s\S]{0,180}Color\(0xFF0D6B57\)\.withOpacity\(0\.52\)',
        ),
      ),
    );
    expect(
      history,
      matches(
        RegExp(
          r'WidgetState\.selected[\s\S]{0,140}Color\(0xFF0D6B57\)',
        ),
      ),
    );
    expect(
      history,
      matches(
        RegExp(
          r'Icons\.add_circle_outline_rounded[\s\S]{0,160}Color\(0xFF0D6B57\)',
        ),
      ),
    );
  });

  test('Tools generic tab backgrounds and infusion border are canonical', () {
    final lightTint = RegExp(
      r'const Color\(0xFF0D6B57\)\.withValues\(alpha:\s*0\.06\)',
    );
    expect(lightTint.allMatches(tools).length, 2);

    expect(
      tools,
      matches(
        RegExp(
          r'Border\.all\([\s\S]{0,140}Color\(0xFF0D6B57\)\.withOpacity\(0\.6\)',
        ),
      ),
    );
  });

  test('History clinical outcome and completion semantics are preserved', () {
    expect(
      history,
      matches(
        RegExp(
          r'success\s*\?\s*const Color\(0xFF10B981\)\s*:\s*const Color\(0xFFB91C1C\)',
        ),
      ),
    );
    expect(
      history,
      matches(
        RegExp(
          r"case 'alta':[\s\S]{0,100}return const Color\(0xFF10B981\)",
        ),
      ),
    );
    expect(
      history,
      matches(
        RegExp(
          r'completion\s*>=\s*1\.0[\s\S]{0,120}\?\s*const Color\(0xFF10B981\)',
        ),
      ),
    );
    expect(
      history,
      contains(
        "'alta': (_hcT(lang, 'pdf_out_alta'), const Color(0xFF10B981))",
      ),
    );
  });

  test('Tools score, prescription, result and taxonomy semantics stay intact',
      () {
    expect(
      tools,
      matches(
        RegExp(
          r'if\s*\(score\s*<=\s*1\)\s*return const Color\(0xFF059669\)',
        ),
      ),
    );
    expect(tools, contains("case 'Diretriz':"));
    expect(tools, contains('0xFF7C3AED'));
    expect(tools, contains('0xFF34D399'));
    expect(tools, contains('0xFFD97706'));
    expect(tools, contains('0xFFDC2626'));
  });
}
