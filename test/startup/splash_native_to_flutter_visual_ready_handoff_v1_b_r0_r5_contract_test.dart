import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String classBlock(String source, String className) {
  final start = source.indexOf('class $className');
  expect(start, greaterThanOrEqualTo(0), reason: className);
  final next = source.indexOf('\nclass ', start + 7);
  return next < 0 ? source.substring(start) : source.substring(start, next);
}

String methodBlock(String source, String signature, String nextSignature) {
  final start = source.indexOf(signature);
  expect(start, greaterThanOrEqualTo(0), reason: signature);
  final next = source.indexOf(nextSignature, start + signature.length);
  expect(next, greaterThan(start), reason: nextSignature);
  return source.substring(start, next);
}

void main() {
  final main = File('lib/main.dart').readAsStringSync();

  group('Splash native to Flutter visual-ready handoff V1-B-R0-R5', () {
    test('TimedSplash has one productive native remove owner', () {
      final timed = classBlock(main, '_TimedSplashState');
      final removeStatements = RegExp(
        r'^\s*FlutterNativeSplash\.remove\(\);\s*$',
        multiLine: true,
      ).allMatches(timed);

      expect(removeStatements.length, 1);
      expect(
        timed,
        isNot(contains('native splash removed after first Flutter frame')),
      );
      expect(
        timed,
        isNot(contains('[BUILD330] FlutterNativeSplash.remove()')),
      );
    });

    test('native release waits for premium M+ asset and two painted frames',
        () {
      final timed = classBlock(main, '_TimedSplashState');
      final method = methodBlock(
        timed,
        'Future<void> _releaseNativeSplashAfterVisualReady() async',
        'Future<void> _releaseSplashAfterContentPaint() async',
      );

      expect(
        method,
        contains(
          "const AssetImage('assets/icon/splash_mplus_premium.png')",
        ),
      );
      expect(method, contains('precacheImage('));
      expect(
        RegExp(r'await WidgetsBinding\.instance\.endOfFrame;')
            .allMatches(method)
            .length,
        2,
      );
      expect(method, contains('_splashRemoved = true;'));
      expect(method, contains('FlutterNativeSplash.remove();'));
    });

    test('initState schedules visual-ready release after first Flutter frame',
        () {
      final timed = classBlock(main, '_TimedSplashState');

      expect(
        timed,
        contains(
          'WidgetsBinding.instance.addPostFrameCallback((_) {',
        ),
      );
      expect(
        timed,
        contains('_releaseNativeSplashAfterVisualReady();'),
      );
    });

    test('obsolete BUILD330 native-ready getter is removed', () {
      final timed = classBlock(main, '_TimedSplashState');

      expect(timed, isNot(contains('bool get _nativeSplashReady')));
      expect(
        timed,
        isNot(contains('BUILD 330 — OTIMIZAÇÃO CRÍTICA iOS')),
      );
    });

    test('4520ms minimum and content handoff remain intact', () {
      final timed = classBlock(main, '_TimedSplashState');

      expect(timed, contains('static const _kMinMs = 4520;'));
      expect(timed, contains('static const _kWatchdogMs = 20000;'));
      expect(
        timed,
        contains('bool get _ready => _minTimeDone && _bootDone;'),
      );
      expect(
        timed,
        contains(
          'Future<void> _releaseSplashAfterContentPaint() async',
        ),
      );
      expect(
        timed,
        contains('duration: const Duration(milliseconds: 350)'),
      );
    });

    test('legacy R8 anti-flash marker is superseded by visual-ready owner', () {
      final r8 = File(
        'test/startup/splash_mplus_150_horizontal_y_no_gray_handoff_v1_b_r8_contract_test.dart',
      ).readAsStringSync();

      expect(
        r8,
        contains(
          'MEDCASES_SPLASH_NATIVE_TO_FLUTTER_VISUAL_READY_HANDOFF_V1_B_R0',
        ),
      );
      expect(
        r8,
        isNot(contains('MEDCASES_SPLASH_NATIVE_MATCH_SECOND_V1_B_R0')),
      );
    });

    test('Unified startup marker follows visual-ready handoff', () {
      final unified = File(
        'test/startup/unified_startup_surface_v1_b_r0_contract_test.dart',
      ).readAsStringSync();

      expect(
        unified,
        contains(
          'MEDCASES_SPLASH_NATIVE_TO_FLUTTER_VISUAL_READY_HANDOFF_V1_B_R0',
        ),
      );
      expect(
        unified,
        isNot(contains('MEDCASES_SPLASH_NATIVE_MATCH_SECOND_V1_B_R0')),
      );
      expect(
        unified,
        contains('flutter_native_splash remains blank dark native stage'),
      );
      expect(
        unified,
        contains('iOS launch fallback is the canonical dark background'),
      );
      expect(
        unified,
        contains('Android normal windows cannot flash system light background'),
      );
    });

    test('native launch preserve remains before runApp', () {
      final preserve = main.indexOf('FlutterNativeSplash.preserve(');
      final runApp = main.indexOf('runApp(');

      expect(preserve, greaterThanOrEqualTo(0));
      expect(runApp, greaterThan(preserve));
    });
  });
}
