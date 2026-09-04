import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String sharedTheme;
  late String primaryOwner;

  setUpAll(() {
    sharedTheme = File('lib/theme/app_theme.dart').readAsStringSync();
    primaryOwner = File(
      'lib/screens/ai/widgets/guardia_clinical_response_view.dart',
    ).readAsStringSync();
  });

  test('Shared theme brand tokens use the canonical MedCases accent', () {
    expect(
      sharedTheme,
      contains('const kBorderActive = Color(0xFF0D6B57);'),
    );
    expect(
      sharedTheme,
      contains('const kAccentBrand = Color(0xFF0D6B57);'),
    );
    expect(sharedTheme, isNot(contains('00E5FF')));
    expect(sharedTheme, isNot(contains('kAccentCyan')));
  });

  test('Floating brand shadow preserves alpha while removing cyan', () {
    expect(sharedTheme, contains('color: Color(0x4D0D6B57),'));
    expect(sharedTheme, isNot(contains('0x4D00E5FF')));
  });

  test('Success green remains semantically separate from brand green', () {
    expect(sharedTheme, contains('const kAccentGreen'));
    expect(sharedTheme, contains('Color(0xFF10B981)'));
    expect(sharedTheme, contains('const kSuccess = kAccentGreen;'));
    expect(sharedTheme, isNot(contains('const kSuccess = kAccentBrand;')));
  });

  test('Dark ColorScheme routes primary and secondary through brand token', () {
    expect(
      RegExp(r'primary:\s+kAccentBrand,').hasMatch(sharedTheme),
      isTrue,
    );
    expect(
      RegExp(r'secondary:\s+kAccentBrand,').hasMatch(sharedTheme),
      isTrue,
    );
  });

  test('Canonical dark brand surfaces use white foreground contrast', () {
    expect(
      RegExp(r'onPrimary:\s+Colors\.white,').hasMatch(sharedTheme),
      isTrue,
    );
    expect(
      RegExp(r'onSecondary:\s+Colors\.white,').hasMatch(sharedTheme),
      isTrue,
    );
    expect(
      RegExp(r'onPrimary:\s+Colors\.black,').hasMatch(sharedTheme),
      isFalse,
    );
    expect(
      RegExp(r'onSecondary:\s+Colors\.black,').hasMatch(sharedTheme),
      isFalse,
    );
  });

  test('Guardia table keeps theme-driven primary inheritance', () {
    expect(
      primaryOwner,
      contains('theme.colorScheme.primary.withOpacity('),
    );
    expect(primaryOwner, isNot(contains('0xFF00E5FF')));
  });
}
