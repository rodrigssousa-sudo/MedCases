import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String classBlock(String source, String className) {
  final token = 'class $className';
  final start = source.indexOf(token);
  expect(start, greaterThanOrEqualTo(0), reason: className);
  final next = source.indexOf('\nclass ', start + token.length);
  return next < 0 ? source.substring(start) : source.substring(start, next);
}

void main() {
  final article =
      File('lib/screens/clinical_guide_article_screen.dart').readAsStringSync();

  group('Published clinical guide article topbar full-width back-left V1-B-R0',
      () {
    test('topbar owns the full available screen width', () {
      final topbar = classBlock(article, '_ArticleTopBar');

      expect(
        topbar,
        contains(
          'return Container(\n'
          '      width: double.infinity,\n'
          '      height: 48,',
        ),
      );
    });

    test('back button stays in canonical left slot', () {
      final topbar = classBlock(article, '_ArticleTopBar');

      expect(topbar, contains('Positioned('));
      expect(topbar, contains('left: 8,'));
      expect(topbar, contains('top: 6,'));
      expect(topbar, contains('width: 36,'));
      expect(topbar, contains('height: 36,'));
      expect(topbar, contains('Icons.arrow_back_ios_new_rounded'));
      expect(topbar, contains('onPressed: onBack'));
    });

    test('title remains independently centered', () {
      final topbar = classBlock(article, '_ArticleTopBar');

      expect(topbar, contains('child: Stack('));
      expect(topbar, contains('alignment: Alignment.center'));
      expect(
        topbar,
        contains('padding: const EdgeInsets.symmetric(horizontal: 52)'),
      );
      expect(topbar, contains('fontSize: 16'));
      expect(topbar, contains('fontWeight: FontWeight.w700'));
    });

    test('published-guide content and back callback remain wired', () {
      for (final token in <String>[
        "title: _isEs ? 'Guía clínica' : 'Guia clínico'",
        'onBack: () => Navigator.of(context).maybePop()',
        'guide.heroImageUrl',
        'guide.title',
        'guide.bodyBlocks',
        'guide.references',
      ]) {
        expect(article, contains(token), reason: token);
      }
    });
  });
}
