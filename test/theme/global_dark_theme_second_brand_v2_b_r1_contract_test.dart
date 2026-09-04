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

    test('light theme remains intentionally unchanged', () {
      final root = slice(
        main,
        'static ThemeData _buildTheme(bool dark) => ThemeData(',
        'static ThemeData get _authTheme => ThemeData(',
      );

      for (final token in <String>[
        'primary: Color(0xFF0F172A)',
        'secondary: Color(0xFF059669)',
        'surface: Color(0xFFFFFFFF)',
        'color: Color(0xFF059669)',
      ]) {
        expect(root, contains(token), reason: token);
      }
    });

    test('mobile topbar dark branding uses canonical green only', () {
      final topbar = slice(
        main,
        'class _MobileAppBar',
        'class _DesktopSidebar',
      );

      expect(
        topbar,
        contains('MEDCASES_GLOBAL_DARK_THEME_SECOND_BRAND_V2_B_R1_TOPBAR'),
      );
      expect(
        RegExp(r'\? const Color\(0xFF0D6B57\)').allMatches(topbar).length,
        greaterThanOrEqualTo(2),
      );
      expect(topbar, isNot(contains('Color(0xFF00C781)')));
      expect(topbar, isNot(contains('Color(0xFF10B981)')));
      expect(topbar, contains('Color(0xFF059669)'));
    });

    test('desktop sidebar dark navigation removes cyan and legacy active green',
        () {
      final sidebar = slice(
        main,
        'class _DesktopSidebar',
        'class _SidebarItem',
      );

      expect(
        sidebar,
        contains('MEDCASES_GLOBAL_DARK_THEME_SECOND_BRAND_V2_B_R1_SIDEBAR'),
      );
      expect(
        sidebar,
        contains(
          'final activeCol = dark ? const Color(0xFF0D6B57) : const Color(0xFF0A7C4E)',
        ),
      );
      expect(
        sidebar,
        contains('const Color(0xFF0D6B57).withOpacity(0.12)'),
      );
      expect(
        sidebar,
        contains(
          'dark ? const Color(0xFF0D6B57) : const Color(0xFF008CA4)',
        ),
      );
      expect(
        sidebar,
        contains('activeBg: const Color(0xFF0D6B57).withOpacity(0.10)'),
      );

      // Premium M+ gold and light palette are not part of this dark-only cleanup.
      expect(sidebar, contains('Color(0xFFFFE8A6)'));
      expect(sidebar, contains('Color(0xFF0A7C4E)'));
      expect(sidebar, contains('Color(0xFF008CA4)'));
    });

    test('profile controls use the canonical brand accent', () {
      final field = classBlock(main, '_ProfileAccountField');
      final button = classBlock(main, '_ProfileAccountButton');

      expect(
        field,
        contains('MEDCASES_GLOBAL_DARK_THEME_SECOND_BRAND_V2_B_R1_PROFILE'),
      );
      expect(field, contains('cursorColor: const Color(0xFF0D6B57)'));
      expect(
        field,
        contains(
          'BorderSide(color: Color(0xFF0D6B57), width: 1.1)',
        ),
      );
      expect(
        button,
        contains('backgroundColor: const Color(0xFF0D6B57)'),
      );
      expect(
        button,
        contains(
          'disabledBackgroundColor: const Color(0xFF0D6B57).withValues(alpha: 0.45)',
        ),
      );
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

    test('semantic and premium colors are not globally flattened', () {
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
      final success = slice(
        main,
        'class _SuccessView',
        'class _NotesAudioWorkspaceState',
      );

      expect(pending, contains('Color(0xFFC5A365)'));
      expect(update, contains('Color(0xFFC5A365)'));
      expect(success, contains('Color(0xFF7C3AED)'));
    });
  });
}
