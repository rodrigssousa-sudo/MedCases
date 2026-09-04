import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final main = File('lib/main.dart').readAsStringSync();

  group('startup true minimum duration 4520ms', () {
    test('minimum gate is exactly 4520ms', () {
      expect(RegExp(r'\b_kMinMs\s*=\s*4520\s*;').allMatches(main).length, 1);
      expect(RegExp(r'\b_kMinMs\s*=\s*3200\s*;').allMatches(main), isEmpty);
    });

    test('premium animation timing remains present', () {
      expect(main, contains('1450'));
      expect(main, contains('2400'));
    });

    test('boot/minimum gate remains present', () {
      expect(main, contains('_minTimeDone'));
      expect(main, contains('_bootDone'));
    });

    test('native anti-flash handoff remains present', () {
      expect(main, contains('FlutterNativeSplash.remove()'));
      expect(main, contains('addPostFrameCallback'));
    });
  });
}
