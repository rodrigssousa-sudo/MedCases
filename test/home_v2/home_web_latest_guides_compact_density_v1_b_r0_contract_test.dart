import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Home Web latest guides compact density V1-B-R0', () {
    late String source;

    setUpAll(() {
      source = File(
        'lib/home_v2/components/home_web_latest_guides_grid.dart',
      ).readAsStringSync();
    });

    test('real and loading grids use the compact matching aspect ratio', () {
      expect(
        RegExp(r'childAspectRatio:\s*1\.08').allMatches(source).length,
        2,
      );
      expect(source, isNot(contains('childAspectRatio: 0.86')));
    });

    test('card gives more height to cover and less to text surface', () {
      expect(
        RegExp(r'Expanded\(\s*flex:\s*60,').allMatches(source).length,
        1,
      );
      expect(
        RegExp(r'Expanded\(\s*flex:\s*40,').allMatches(source).length,
        1,
      );
      expect(source, isNot(contains('flex: 53')));
      expect(source, isNot(contains('flex: 47')));
    });

    test('clinical guide information remains present', () {
      expect(source, contains('category.toUpperCase()'));
      expect(
          source, contains('final title = guide.localizedTitle(isEs).trim();'));
      expect(
        source,
        contains(
            'final description = guide.localizedDescription(isEs).trim();'),
      );
      expect(RegExp(r'title,\s*maxLines:\s*2').hasMatch(source), isTrue);
      expect(RegExp(r'description,\s*maxLines:\s*2').hasMatch(source), isTrue);
    });

    test('physically approved cover runtime remains frozen', () {
      expect(source, contains('Duration(seconds: 20)'));
      expect(source, contains('Image.network('));
      expect(source, contains('WebHtmlElementStrategy.prefer'));
      expect(source, contains('fit: BoxFit.cover'));
      expect(source, contains('imageUrl.isEmpty'));
      expect(source, contains('errorBuilder:'));
    });
  });
}
