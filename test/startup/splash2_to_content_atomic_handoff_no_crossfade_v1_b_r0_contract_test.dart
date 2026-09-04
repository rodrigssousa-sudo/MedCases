import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String classBlock(String source, String className) {
  final start = source.indexOf('class $className');
  expect(start, greaterThanOrEqualTo(0), reason: className);
  final next = source.indexOf('\nclass ', start + 7);
  return next < 0 ? source.substring(start) : source.substring(start, next);
}

void main() {
  final main = File('lib/main.dart').readAsStringSync();

  group('Splash2 to content atomic handoff no crossfade V1-B-R0', () {
    test('4520ms splash minimum remains unchanged', () {
      final timed = classBlock(main, '_TimedSplashState');
      expect(timed, contains('static const _kMinMs = 4520;'));
      expect(timed, contains('static const _kWatchdogMs = 20000;'));
    });

    test('real content stays mounted behind opaque splash cover', () {
      final timed = classBlock(main, '_TimedSplashState');
      expect(
        timed,
        contains("ValueKey('ready-content-behind-splash')"),
      );
      expect(
        timed,
        contains("ValueKey('splash-cover-until-rendered')"),
      );
      expect(
        timed,
        contains('if (_authResolved && !_handoffScheduled)'),
      );
      expect(timed, contains('Duration(milliseconds: 180)'));
    });

    test('handoff has no semitransparent crossfade', () {
      final timed = classBlock(main, '_TimedSplashState');
      expect(timed, isNot(contains('bool _handoffFade = false;')));
      expect(timed, isNot(contains('setState(() => _handoffFade = true);')));
      expect(timed, isNot(contains('AnimatedOpacity(')));
      expect(
        timed,
        isNot(contains('opacity: _handoffFade ? 0.0 : 1.0')),
      );
      expect(
        timed,
        isNot(
          contains(
            'await Future<void>.delayed(const Duration(milliseconds: 350));',
          ),
        ),
      );
    });

    test('release remains frame-gated and atomic', () {
      final timed = classBlock(main, '_TimedSplashState');
      final methodStart = timed.indexOf(
        'Future<void> _releaseSplashAfterContentPaint() async',
      );
      final buildStart = timed.indexOf(
        'Widget build(BuildContext context)',
        methodStart,
      );
      expect(methodStart, greaterThanOrEqualTo(0));
      expect(buildStart, greaterThan(methodStart));

      final method = timed.substring(methodStart, buildStart);
      expect(
        RegExp(r'await WidgetsBinding\.instance\.endOfFrame;')
            .allMatches(method)
            .length,
        2,
      );
      expect(method, contains('Duration(milliseconds: 180)'));
      expect(method, contains('setState(() => _handoffDone = true);'));
      expect(method, isNot(contains('_handoffFade')));
    });

    test('native splash owner remains separate and preserved', () {
      final timed = classBlock(main, '_TimedSplashState');
      expect(
        timed,
        contains(
          'Future<void> _releaseNativeSplashAfterVisualReady() async',
        ),
      );
      expect(timed, contains('FlutterNativeSplash.remove();'));
      expect(
        RegExp(
          r'^\s*FlutterNativeSplash\.remove\(\);\s*$',
          multiLine: true,
        ).allMatches(timed).length,
        1,
      );
    });
  });
}
