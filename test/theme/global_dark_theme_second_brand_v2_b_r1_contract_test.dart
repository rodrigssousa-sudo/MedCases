import 'current_theme_runtime_harness.dart';
import '../navigation/support_success_runtime_harness.dart';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String slice(String source, String start, String end) {
  final a = source.indexOf(start);
  expect(a, greaterThanOrEqualTo(0), reason: start);
  final b = source.indexOf(end, a + start.length);
  expect(b, greaterThan(a), reason: end);
  return source.substring(a, b);
}

String classBlock(String source, String className) {
  final start = source.indexOf('class $className');
  expect(start, greaterThanOrEqualTo(0), reason: className);

  final next = source.indexOf('\nclass ', start + 1);
  return next < 0 ? source.substring(start) : source.substring(start, next);
}

void main() {
  final main = File('lib/main.dart').readAsStringSync();

  group('Global Dark Theme Second Brand V2 B R1', () {
    test('root dark color scheme uses one MedCases accent', () {
      final root = slice(
        main,
        'static ThemeData _buildTheme(bool dark) => ThemeData(',
        'static ThemeData get _authTheme => ThemeData(',
      );
      final dark =
          slice(root, 'ColorScheme.dark(', ': const ColorScheme.light(');

      for (final token in <String>[
        'MEDCASES_GLOBAL_DARK_THEME_SECOND_BRAND_V2_B_R1_ROOT',
        'primary: const Color(0xFF0D6B57)',
        'secondary: const Color(0xFF0D6B57)',
        'onPrimary: const Color(0xFFFFFFFF)',
        'surface: const Color(0xFF252930)',
        'outline: const Color(0xFF374151)',
        'outlineVariant: const Color(0xFF374151)',
      ]) {
        expect(root, contains(token), reason: token);
      }

      for (final stale in <String>[
        'Color(0xFF00E5FF)',
        'Color(0xFF10B981)',
        'Color(0xFF2D3340)',
      ]) {
        expect(dark, isNot(contains(stale)), reason: stale);
      }
    });

    testWidgets('light theme remains intentionally unchanged', (tester) async {
      await verifyRootTheme(tester);
    });

    testWidgets('mobile topbar dark branding uses canonical green only',
        (tester) async {
      await verifyShellTheme(tester, desktop: false);
    });

    testWidgets(
        'desktop sidebar dark navigation removes cyan and legacy active green',
        (tester) async {
      await verifyShellTheme(tester, desktop: true);
    });

    testWidgets('profile controls use the canonical brand accent',
        (tester) async {
      await verifyProfileTheme(tester);
    });

    test('auth theme remains independently canonical', () {
      final auth = slice(
        main,
        'static ThemeData get _authTheme => ThemeData(',
        'class _MedCasesAppState',
      );

      for (final token in <String>[
        'MEDCASES_SPLASH_AUTH_THEME_UI_V2_B_R1_AUTH_THEME',
        'scaffoldBackgroundColor: const Color(0xFF1A1D23)',
        'primary: Color(0xFF0D6B57)',
        'secondary: Color(0xFF0D6B57)',
        'surface: Color(0xFF252930)',
        'outline: Color(0xFF374151)',
      ]) {
        expect(auth, contains(token), reason: token);
      }
    });

    testWidgets('semantic and premium colors are not globally flattened',
        (tester) async {
      await verifySupportSuccess(tester);
      final pending = slice(
        main,
        'class _PendingScreenState',
        'class _BlockedScreen',
      );
      final update = slice(
        main,
        'class _UpdateBanner',
        'class _AppUpdateDialog',
      );

      expect(pending, contains('Color(0xFFC5A365)'));
      expect(update, contains('Color(0xFFC5A365)'));
      // Real SupportTicketScreen success is verified above; premium gold is unchanged.
    });
  });
}
