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

  test('M+ remains 150px using the canonical splash asset', () {
    expect(splash, contains("'assets/icon/splash_mplus_premium.png'"));
    expect(splash, contains('dimension: 150,'));
    expect(splash, contains('width: 150,'));
    expect(splash, contains('height: 150,'));
  });

  test('horizontal spin is exactly one full Y-axis turn', () {
    expect(splash, contains('Tween<double>(begin: 0.0, end: 1.0)'));
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

  test('one complete 360 degree turn ends at original orientation', () {
    const beginTurns = 0.0;
    const endTurns = 1.0;
    const tau = 6.283185307179586;

    final beginAngle = beginTurns * tau;
    final endAngle = endTurns * tau;
    final normalizedEnd = endAngle % tau;

    expect(beginAngle, 0.0);
    expect(endAngle, tau);
    expect(normalizedEnd.abs(), lessThan(1e-12));
  });

  test('premium zoom and timing remain preserved', () {
    expect(splash, contains('Tween<double>(begin: 0.92, end: 1.10)'));
    expect(splash, contains('Tween<double>(begin: 1.10, end: 1.00)'));
    expect(splash, contains('duration: const Duration(milliseconds: 1450)'));
    expect(splash, contains('duration: const Duration(milliseconds: 2400)'));
    expect(splash, contains('_pulseCtrl.repeat(reverse: true);'));
  });

  test('no-gray handoff remains preserved', () {
    expect(timed, contains('static const _kMinMs = 4520;'));
    expect(timed, contains('splash-cover-until-rendered'));
    expect(timed, contains('ready-content-behind-splash'));
    expect(timed, contains('WidgetsBinding.instance.endOfFrame'));
    expect(timed, contains('Duration(milliseconds: 180)'));
    expect(
      timed,
      isNot(contains('Duration(milliseconds: 350)')),
    );
  });
}
