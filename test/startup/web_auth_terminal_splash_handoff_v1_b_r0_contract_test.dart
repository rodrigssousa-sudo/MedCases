import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Web auth terminal splash handoff V1-B-R0', () {
    late String source;
    late String webGate;

    setUpAll(() {
      source = File('lib/main.dart').readAsStringSync();

      final match = RegExp(
        r'Widget\s+_buildWebAuthGate\(BuildContext context\)\s*\{(.*?)\n\s*\}\n\s*\n\s*@override',
        dotAll: true,
      ).firstMatch(source);

      expect(match, isNotNull);
      webGate = match!.group(1)!;
    });

    test('outer TimedSplash handoff still requires authResolved', () {
      expect(
        source,
        contains('bool get _ready => _minTimeDone && _bootDone;'),
      );
      expect(
        source,
        contains('if (_authResolved && !_handoffScheduled)'),
      );
      expect(
        source,
        contains("key: const ValueKey('splash-cover-until-rendered')"),
      );
    });

    test('logged-out Web terminal state signals splash ready', () {
      final branch = RegExp(
        r'if\s*\(user\s*==\s*null\)\s*\{(.*?)return\s+_wrapAuth\(const\s+PreLoginPreview\(\)\);',
        dotAll: true,
      ).firstMatch(webGate);

      expect(branch, isNotNull);
      expect(branch!.group(1), contains('_signalSplashReady(context);'));
    });

    test('blocked Web terminal state signals splash ready', () {
      final branch = RegExp(
        r'if\s*\(user\.isBlocked\)\s*\{(.*?)return\s+_wrapAuth\(_BlockedScreen\(user:\s*user\)\);',
        dotAll: true,
      ).firstMatch(webGate);

      expect(branch, isNotNull);
      expect(branch!.group(1), contains('_signalSplashReady(context);'));
    });

    test('pending Web terminal state signals splash ready', () {
      final branch = RegExp(
        r'if\s*\(user\.isPending\)\s*\{(.*?)return\s+_wrapAuth\(_PendingScreen\(user:\s*user\)\);',
        dotAll: true,
      ).firstMatch(webGate);

      expect(branch, isNotNull);
      expect(branch!.group(1), contains('_signalSplashReady(context);'));
    });

    test('approved Web user path remains owned by _onUserResolved', () {
      expect(
        webGate,
        contains('_onUserResolved(user);'),
      );
      expect(
        webGate,
        contains('return _WebMainShellGate(user: user);'),
      );
    });

    test('no auth or splash timing constants are changed by this contract', () {
      expect(source, contains('static const _kMinMs = 4520;'));
      expect(source, contains('static const _kWatchdogMs = 20000;'));
      expect(source, contains('const Duration(seconds: 20)'));
    });
  });
}
