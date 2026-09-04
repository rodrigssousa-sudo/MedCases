import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;
  late String splash;
  late String timed;

  setUpAll(() {
    source = File('lib/main.dart').readAsStringSync();

    final splashStart = source.indexOf('// ── Splash Screen');
    final splashEnd =
        source.indexOf('// ── Loading indicator ciclante', splashStart);
    expect(splashStart, greaterThanOrEqualTo(0));
    expect(splashEnd, greaterThan(splashStart));
    splash = source.substring(splashStart, splashEnd);

    final timedStart = source.indexOf('class _TimedSplashState');
    final timedEnd = source.indexOf('\nclass ', timedStart + 1);
    expect(timedStart, greaterThanOrEqualTo(0));
    timed = source.substring(
      timedStart,
      timedEnd >= 0 ? timedEnd : source.length,
    );
  });

  test('M+ uses new 150px geometry', () {
    expect(splash, contains("'assets/icon/splash_mplus_premium.png'"));
    expect(splash, contains('dimension: 150,'));
    expect(splash, contains('width: 150,'));
    expect(splash, contains('height: 150,'));
    expect(splash, isNot(contains('dimension: 134.4,')));
  });

  test('M+ performs horizontal 360 spin on Y axis, not planar Z spin', () {
    expect(splash, contains('Matrix4.identity()'));
    expect(splash, contains('..setEntry(3, 2, 0.0016)'));
    expect(splash, contains('..rotateY('));
    expect(
      splash,
      contains('_logoTurns.value * 6.283185307179586'),
    );

    expect(splash, isNot(contains('RotationTransition(')));
    expect(splash, isNot(contains('..rotateX(')));
    expect(splash, isNot(contains('..rotateZ(')));
  });

  test('premium zoom, entry and pulse remain intact', () {
    expect(splash, contains('Tween<double>(begin: 0.92, end: 1.10)'));
    expect(splash, contains('Tween<double>(begin: 1.10, end: 1.00)'));
    expect(splash, contains('duration: const Duration(milliseconds: 1450)'));
    expect(splash, contains('duration: const Duration(milliseconds: 2400)'));
    expect(splash, contains('_pulseCtrl.repeat(reverse: true);'));
  });

  test('splash remains covering until auth stable and real content painted',
      () {
    expect(timed, contains('bool _handoffScheduled = false;'));
    expect(
      timed,
      isNot(contains('bool _handoffFade = false;')),
    );
    expect(timed, contains('bool _handoffDone = false;'));

    expect(
      timed,
      contains('Future<void> _releaseSplashAfterContentPaint() async'),
    );
    expect(timed, contains('await WidgetsBinding.instance.endOfFrame;'));
    expect(
      timed,
      contains('Duration(milliseconds: 180)'),
    );

    expect(
      timed,
      contains('if (_authResolved && !_handoffScheduled)'),
    );
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
      isNot(contains('AnimatedOpacity(')),
    );
    expect(
      timed,
      isNot(contains('opacity: _handoffFade ? 0.0 : 1.0')),
    );
    expect(
      timed,
      isNot(contains('duration: const Duration(milliseconds: 350)')),
    );
  });

  test('true 4520ms minimum and watchdog remain preserved', () {
    expect(timed, contains('static const _kMinMs = 4520;'));
    expect(timed, contains('static const _kWatchdogMs = 20000;'));

    final bootStart = timed.indexOf('widget.bootFuture.whenComplete(() {');
    final bootEnd = timed.indexOf(
      'AppResumeCoordinator.instance.completeBootstrap();',
      bootStart,
    );
    expect(bootStart, greaterThanOrEqualTo(0));
    expect(bootEnd, greaterThan(bootStart));

    final bootBlock = timed.substring(bootStart, bootEnd);
    expect(bootBlock, contains('_bootDone = true;'));
    expect(bootBlock, isNot(contains('_minTimeDone = true;')));
  });

  test('native splash anti-flash behavior remains present', () {
    expect(
      timed,
      contains('MEDCASES_SPLASH_NATIVE_TO_FLUTTER_VISUAL_READY_HANDOFF_V1_B_R0'),
    );
    expect(timed, contains('FlutterNativeSplash.remove();'));
  });
}
