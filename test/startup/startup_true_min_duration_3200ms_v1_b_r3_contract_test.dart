import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;
  late String timedSplash;

  setUpAll(() {
    source = File('lib/main.dart').readAsStringSync();
    final start = source.indexOf('class _TimedSplashState');
    expect(start, greaterThanOrEqualTo(0));
    final nextClass = source.indexOf('\nclass ', start + 1);
    timedSplash = source.substring(
      start,
      nextClass >= 0 ? nextClass : source.length,
    );
  });

  test('TimedSplash minimum is exactly 4520ms', () {
    expect(
      RegExp(r'static const _kMinMs\s*=\s*4520\s*;')
          .allMatches(timedSplash)
          .length,
      1,
    );
    expect(
      RegExp(r'static const _kMinMs\s*=\s*1200\s*;')
          .allMatches(timedSplash)
          .length,
      0,
    );
  });

  test('minimum timer remains the owner of _minTimeDone normal release', () {
    expect(
      timedSplash,
      contains(
        'Future<void>.delayed(const Duration(milliseconds: _kMinMs), () {',
      ),
    );
    expect(
      timedSplash,
      contains('if (mounted) setState(() => _minTimeDone = true);'),
    );
  });

  test('normal boot completion cannot bypass the 4520ms minimum', () {
    final bootStart =
        timedSplash.indexOf('widget.bootFuture.whenComplete(() {');
    expect(bootStart, greaterThanOrEqualTo(0));

    final coordinator = timedSplash.indexOf(
      'AppResumeCoordinator.instance.completeBootstrap();',
      bootStart,
    );
    expect(coordinator, greaterThan(bootStart));

    final bootBlock = timedSplash.substring(bootStart, coordinator);

    expect(bootBlock, contains('_bootDone = true;'));
    expect(bootBlock, isNot(contains('_minTimeDone = true;')));
  });

  test('20-second watchdog safety behavior remains intact', () {
    expect(timedSplash, contains('static const _kWatchdogMs = 20000;'));

    final coordinatorStart = timedSplash.indexOf(
      'AppResumeCoordinator.instance.registerBootstrap(',
    );
    expect(coordinatorStart, greaterThanOrEqualTo(0));

    final localWatchdogStart = timedSplash.indexOf(
      'Future<void>.delayed(const Duration(milliseconds: _kWatchdogMs), () {',
    );
    expect(localWatchdogStart, greaterThan(coordinatorStart));

    final coordinatorBlock = timedSplash.substring(
      coordinatorStart,
      localWatchdogStart,
    );
    expect(coordinatorBlock, contains('onTimeout: () {'));
    expect(coordinatorBlock, contains('_bootDone = true;'));
    expect(coordinatorBlock, contains('_minTimeDone = true;'));

    final localWatchdogEnd = timedSplash.indexOf(
      '// BUILD 463-A.1.1:',
      localWatchdogStart,
    );
    expect(localWatchdogEnd, greaterThan(localWatchdogStart));

    final localWatchdogBlock = timedSplash.substring(
      localWatchdogStart,
      localWatchdogEnd,
    );
    expect(localWatchdogBlock, contains('_bootDone = true;'));
    expect(localWatchdogBlock, contains('_minTimeDone = true;'));
    expect(
      localWatchdogBlock,
      contains('AppResumeCoordinator.instance.completeBootstrap();'),
    );
  });

  test('startup visual transition remains unchanged', () {
    expect(source, contains('class _SplashScreen'));
    expect(source, contains('assets/icon/app_icon.png'));
    expect(source, contains('IA Clínica de bolso'));
    expect(
      source,
      contains('duration: const Duration(milliseconds: 350)'),
    );
  });
}
