import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

String slice(String s, String a, String b) {
  final x = s.indexOf(a);
  expect(x, greaterThanOrEqualTo(0), reason: a);
  final y = s.indexOf(b, x + a.length);
  expect(y, greaterThan(x), reason: b);
  return s.substring(x, y);
}

void main() {
  final main = File('lib/main.dart').readAsStringSync();

  group('Menu lateral Settings Shell UI V2 B R1', () {
    test('productive drawer behavior stays wired', () {
      final owner =
          slice(main, 'class _AppDrawerState', 'class _DeletingAccountOverlay');
      for (final token in <String>[
        'MEDCASES_MENU_LATERAL_SETTINGS_SHELL_UI_V2_B_R1',
        'ProfileAccountScreen(p: p)',
        'if (!kIsReviewMode)',
        'showUpgradeScreen(context, lang: p.lang)',
        "showFontesScreen(context, isEs: p.lang == 'es')",
        'builder: (_) => _FeedbackSheet(p: p, dark: dark)',
        'p.setLang(newLang)',
        "prefs.setString('lang', newLang)",
        'onTap: () => p.toggleDarkMode()',
        '_OfflineDrawerCard(p: p, dark: dark)',
        'showLegalSheet(context, LegalType.terms, p.lang)',
        'showLegalSheet(context, LegalType.privacy, p.lang)',
        '_showDeleteAccountDialog(context, p)',
        'await AuthService.logout()',
      ]) {
        expect(owner, contains(token), reason: token);
      }
    });

    test('drawer uses canonical palette and premium mobile width', () {
      final owner =
          slice(main, 'class _AppDrawerState', 'class _DeletingAccountOverlay');
      for (final token in <String>[
        'Color(0xFFECF0F4)',
        'Color(0xFFE2E7EC)',
        'Color(0xFF374151)',
        'Color(0xFF009C3B)',
        '(screenW * 0.672).clamp(224.0, 256.0)',
        'topLeft: Radius.circular(18)',
        'bottomLeft: Radius.circular(18)',
      ]) {
        expect(owner, contains(token), reason: token);
      }
    });

    test('profile drawer header has liquid glass material', () {
      final owner =
          slice(main, 'class _DrawerHeader', 'class _DrawerSectionLabel');
      for (final token in <String>[
        'static const _kGreen = Color(0xFF009C3B);',
        'BackdropFilter(',
        'ImageFilter.blur(sigmaX: 16, sigmaY: 16)',
        'Color(0xE6FFFFFF)',
        'Color(0xE6252930)',
        'Color(0xFFE2E7EC)',
        'onTap: onAvatarTap',
        'onTap: onEditProfile',
        'onPressed: onClose',
      ]) {
        expect(owner, contains(token), reason: token);
      }
    });

    test('section labels are cleaner without decorative rule', () {
      final owner =
          slice(main, 'class _DrawerSectionLabel', 'class _DrawerBlock');
      expect(owner, contains('Color(0xFF66717E)'));
      expect(owner, contains('EdgeInsets.fromLTRB(16, 14, 16, 5)'));
      expect(owner, isNot(contains('height: 0.55')));
    });

    test('preference controls keep fast behavior with canonical accent', () {
      final owner =
          slice(main, 'class _LangBadge', 'class _DeletingAccountOverlay');
      expect(owner, contains('Color(0xFF009C3B)'));
      expect(owner, contains('Duration(milliseconds: 90)'));
      expect(main,
          contains('context.select<AppProvider, bool>((p) => p.darkMode)'));
    });

    test('danger and offline semantics remain distinct', () {
      expect(main, contains('Color(0xFFCC3333)'));
      expect(main, contains('Color(0xFF1D4ED8)'));
      expect(main, contains('AuthService.deleteAccount('));
      expect(main, contains('p.setOfflineMode(!offline)'));
    });

    test('legal internal and external routes remain available', () {
      expect(main,
          contains('openAcademicSourceSecurely(context, title, externalUrl)'));
      expect(
          main, contains('showLegalSheet(context, LegalType.terms, p.lang)'));
      expect(
          main, contains('showLegalSheet(context, LegalType.privacy, p.lang)'));
    });
  });
}
