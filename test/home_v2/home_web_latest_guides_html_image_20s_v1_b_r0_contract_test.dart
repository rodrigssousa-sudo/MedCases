import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Home Web guide covers HTML image + 20s V1-B-R0', () {
    late String source;

    setUpAll(() {
      source = File(
        'lib/home_v2/components/home_web_latest_guides_grid.dart',
      ).readAsStringSync();
    });

    test('guide rotation is stable for 20 seconds', () {
      expect(source, contains('Duration(seconds: 20)'));
      expect(source, isNot(contains('Duration(seconds: 8)')));
    });

    test('Home guide cover no longer uses CachedNetworkImage runtime path', () {
      expect(source, isNot(contains('CachedNetworkImage(')));
    });

    test('network cover prefers HTML image element on Web', () {
      expect(source, contains('Image.network('));
      expect(
        source,
        contains('webHtmlElementStrategy:'),
      );
      expect(
        source,
        contains('WebHtmlElementStrategy.prefer'),
      );
    });

    test('existing visual behavior remains cover + error fallback', () {
      expect(source, contains('fit: BoxFit.cover'));
      expect(source, contains('errorBuilder:'));
      expect(source, contains('_GuideCoverFallback(dark: dark)'));
      expect(source, isNot(contains('_GuideCoverSkeleton')));
    });

    test('empty cover metadata fallback remains guarded', () {
      expect(source, contains('imageUrl.isEmpty'));
      expect(source, contains('final imageUrl = guide.coverUrl.trim();'));
    });
  });
}
