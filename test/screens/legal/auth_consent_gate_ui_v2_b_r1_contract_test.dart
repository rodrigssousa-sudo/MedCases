import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String classSlice(String source, String start, String end) {
  final a = source.indexOf(start);
  expect(a, greaterThanOrEqualTo(0), reason: start);
  final b = source.indexOf(end, a + start.length);
  expect(b, greaterThan(a), reason: end);
  return source.substring(a, b);
}

void main() {
  final main = File('lib/main.dart').readAsStringSync();
  final legal = File('lib/screens/legal_screen.dart').readAsStringSync();

  group('Auth Consent Gate UI V2 B R1', () {
    test('native consent gate loading state uses canonical auth identity', () {
      final gate = classSlice(
        main,
        'class _ConsentGateState',
        'class _SplashScreen',
      );

      expect(
        gate,
        contains('MEDCASES_AUTH_CONSENT_GATE_UI_V2_B_R1'),
      );
      expect(gate, contains('backgroundColor: Color(0xFF1A1D23)'));
      expect(
        gate,
        contains(
          'CircularProgressIndicator(color: Color(0xFF0D6B57))',
        ),
      );
      expect(gate, isNot(contains('Color(0xFF00E5FF)')));
      expect(gate, contains('Colors.black.withValues(alpha: 0.50)'));
    });

    test('native consent gate behavior remains unchanged', () {
      final gate = classSlice(
        main,
        'class _ConsentGateState',
        'class _SplashScreen',
      );

      for (final token in <String>[
        'final ok = await ConsentGate.hasConsented();',
        'if (mounted) setState(() => _hasConsented = ok);',
        'if (_hasConsented!) return const LoginScreen();',
        'const LoginScreen(),',
        'ConsentModal(',
        'onAccepted: _onAccepted,',
      ]) {
        expect(gate, contains(token), reason: token);
      }
    });

    test('consent modal uses one canonical MedCases accent', () {
      final state = classSlice(
        legal,
        'class _ConsentModalState',
        'class _ConsentCheck',
      );

      for (final token in <String>[
        'MEDCASES_AUTH_CONSENT_MODAL_UI_V2_B_R1',
        'static const _kAccent = Color(0xFF0D6B57);',
        'static const _kLink = Color(0xFF0D6B57);',
        'static const _kDark = Color(0xFF1A1D23);',
        'static const _kDivider = Color(0xFF374151);',
        'static const _kTextSecondary = Color(0xFF94A3B8);',
        'static const _kTextMuted = Color(0xFF7C8797);',
        'disabledBackgroundColor: const Color(0xFF252930)',
      ]) {
        expect(state, contains(token), reason: token);
      }

      for (final stale in <String>[
        'Color(0xFF10B981)',
        'Color(0xFF0F1116)',
        'Color(0xFF2D3340)',
        'Color(0xFFA8B2C1)',
      ]) {
        expect(state, isNot(contains(stale)), reason: stale);
      }
    });

    test('consent remains four explicit required items', () {
      final state = classSlice(
        legal,
        'class _ConsentModalState',
        'class _ConsentCheck',
      );

      for (final token in <String>[
        'bool _c1 = false;',
        'bool _c2 = false;',
        'bool _c3 = false;',
        'bool _c4 = false;',
        'bool get _allChecked => _c1 && _c2 && _c3 && _c4;',
        'Widget divider() => const Divider(',
      ]) {
        expect(state, contains(token), reason: token);
      }
      expect(RegExp(r'\bdivider\(\),').allMatches(state).length, 3);
    });

    test('consent persistence and acceptance remain intact', () {
      // ConsentGate is declared after enum LegalType in legal_screen.dart.
      // Persistence validation must not depend on declaration ordering.
      final gate = legal;
      final state = classSlice(
        legal,
        'class _ConsentModalState',
        'class _ConsentCheck',
      );

      for (final token in <String>[
        "static const _kConsentKey = 'consent_v3';",
        "static const _kConsentTimestamp = 'consent_timestamp';",
        "p.setBool(_kConsentKey, true)",
        "p.setString(_kConsentTimestamp, now)",
        "p.setString(_kConsentVersion, _kTermsVersion)",
        "p.setString(_kConsentLang, lang)",
      ]) {
        expect(gate, contains(token), reason: token);
      }

      expect(
        state,
        contains('await ConsentGate.saveConsent(lang: widget.lang);'),
      );
      expect(state, contains('widget.onAccepted();'));
    });

    test('legal links remain wired in-app', () {
      final state = classSlice(
        legal,
        'class _ConsentModalState',
        'class _ConsentCheck',
      );

      for (final token in <String>[
        'showLegalSheet(context, LegalType.terms, widget.lang)',
        'showLegalSheet(context, LegalType.privacy, widget.lang)',
        'context, LegalType.disclaimer, widget.lang',
        "'Termos de Uso'",
        "'Términos de Uso'",
        "'Política de Privacidade'",
        "'Política de Privacidad'",
        "'ver Aviso Médico'",
      ]) {
        expect(state, contains(token), reason: token);
      }
    });

    test('individual checkbox stays flat and accessible', () {
      final check = legal.substring(
        legal.indexOf('class _ConsentCheck extends StatelessWidget'),
      );

      for (final token in <String>[
        'static const _kAccent = Color(0xFF0D6B57);',
        'static const _kLink = Color(0xFF0D6B57);',
        'static const _kTextPrimary = Color(0xFFF1F5F9);',
        'static const _kCheckboxIdle = Color(0xFF7C8797);',
        'onTap: () => onChanged(!value)',
        'AnimatedContainer(',
        'onTap: onLinkTap',
        'TextDecoration.underline',
      ]) {
        expect(check, contains(token), reason: token);
      }
    });
  });
}
