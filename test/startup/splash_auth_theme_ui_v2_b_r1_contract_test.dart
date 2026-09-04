import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String sliceBetween(String source, String start, String end) {
  final a = source.indexOf(start);
  expect(a, greaterThanOrEqualTo(0), reason: start);
  final b = source.indexOf(end, a + start.length);
  expect(b, greaterThan(a), reason: end);
  return source.substring(a, b);
}

void main() {
  final main = File('lib/main.dart').readAsStringSync();
  final pubspec = File('pubspec.yaml').readAsStringSync();

  group('Splash Auth Theme UI V2 B R1', () {
    test('auth theme uses canonical MedCases Pro dark identity', () {
      final auth = sliceBetween(
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

      for (final stale in <String>[
        'primary: Color(0xFFC5A365)',
        'secondary: Color(0xFF10B981)',
        'surface: Color(0xFF0F1116)',
      ]) {
        expect(auth, isNot(contains(stale)), reason: stale);
      }
    });

    test('dynamic splash preserves native-safe background and one accent', () {
      final splash = sliceBetween(
        main,
        'class _SplashScreenState',
        'class _SplashLoadingIndicator',
      );

      expect(
        splash,
        contains('MEDCASES_SPLASH_AUTH_THEME_UI_V2_B_R1_SPLASH'),
      );
      expect(
        splash,
        contains('backgroundColor: const Color(0xFF0F1116)'),
      );
      expect(splash, contains('Color(0xFF0D6B57)'));
      expect(splash, isNot(contains('Color(0xFF0E7C52)')));
      expect(splash, isNot(contains('Color(0xFF13A06A)')));
      expect(pubspec, contains('color: "#0F1116"'));
      expect(pubspec, contains('icon_background_color: "#0F1116"'));
    });

    test('premium animation timing and pulse remain byte-contract compatible',
        () {
      final splash = sliceBetween(
        main,
        'class _SplashScreenState',
        'class _SplashLoadingIndicator',
      );

      for (final token in <String>[
        'duration: const Duration(milliseconds: 1450)',
        '_pulseOpacity = Tween<double>(begin: 1.0, end: 0.55)',
        '_pulseScale = Tween<double>(begin: 1.0, end: 1.06)',
        '_logoTurns = Tween<double>(begin: 0.0, end: 1.0)',
        '_pulseCtrl.repeat(reverse: true)',
      ]) {
        expect(splash, contains(token), reason: token);
      }
    });

    test('splash asset size title and tagline remain intact', () {
      final splash = sliceBetween(
        main,
        'class _SplashScreenState',
        'class _SplashLoadingIndicator',
      );

      for (final token in <String>[
        "'assets/icon/splash_mplus_premium.png'",
        'dimension: 150',
        'width: 150',
        'height: 150',
        "'MedCases Pro'",
        "'IA Clínica de bolso'",
      ]) {
        expect(splash, contains(token), reason: token);
      }
    });

    test('loading indicator uses canonical accent', () {
      final indicator = sliceBetween(
        main,
        'class _SplashLoadingIndicator',
        'class _TimedSplash',
      );

      expect(indicator, contains('CircularProgressIndicator('));
      expect(indicator, contains('Color(0xFF0D6B57)'));
      expect(indicator, isNot(contains('Color(0xFF13A06A)')));
      expect(indicator, isNot(contains('Color(0xFF0E7C52)')));
    });

    test('timed splash behavior and no-flash handoff remain intact', () {
      final timed = sliceBetween(
        main,
        'class _TimedSplashState',
        'class _PendingScreen',
      );

      for (final token in <String>[
        'static const _kMinMs = 4520',
        'static const _kWatchdogMs = 20000',
        "const AssetImage('assets/icon/splash_mplus_premium.png')",
        'await WidgetsBinding.instance.endOfFrame;',
        'FlutterNativeSplash.remove();',
        'duration: const Duration(milliseconds: 350)',
        'Future<void>.delayed(const Duration(milliseconds: 180))',
        'bool get _ready => _minTimeDone && _bootDone;',
      ]) {
        expect(timed, contains(token), reason: token);
      }
    });

    test('auth wrapper still applies only the auth theme', () {
      final gate = sliceBetween(
        main,
        'class _AuthGateState',
        'class _ConsentGate',
      );

      expect(gate, contains('data: MedCasesApp._authTheme'));
      expect(gate, contains('splash: _wrapAuth(const _SplashScreen())'));
      expect(
        gate,
        contains('readyBuilder: (context) => _buildAuthFlow(context)'),
      );
    });
  });
}
