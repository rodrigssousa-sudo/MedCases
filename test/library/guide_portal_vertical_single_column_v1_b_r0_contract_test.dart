import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read() => File('lib/screens/library_screen.dart').readAsStringSync();

String _between(
  String source,
  String start,
  String end,
  String label,
) {
  final a = source.indexOf(start);
  final b = source.indexOf(end, a + start.length);
  expect(a, greaterThanOrEqualTo(0), reason: '$label start missing');
  expect(b, greaterThan(a), reason: '$label end missing');
  return source.substring(a, b);
}

void main() {
  late String source;
  late String guideCard;

  setUpAll(() {
    source = _read();
    guideCard = _between(
      source,
      'class _GuideCard extends StatelessWidget',
      'class _LibraryTabEmptyState',
      '_GuideCard current owner',
    );
  });

  test('guide portal keeps one SliverList wrapper and delegates all guides',
      () {
    expect(source, contains('SliverList('));
    expect(source, contains('portalGuides: filtered'));
    expect(source, contains('featured: i == 0'));
    expect(source, contains('childCount: filtered.isEmpty ? 0 : 1'));
  });

  test('current guide card renders portal guides vertically', () {
    expect(
      guideCard,
      contains(
        'final guides = portalGuides.isEmpty ? <GuideModel>[guide] : portalGuides;',
      ),
    );
    expect(guideCard, contains('const railHeight = 356.0'));
    expect(guideCard, contains('child: Column('));
    expect(
      guideCard,
      contains('for (var index = 0; index < guides.length; index++)'),
    );
    expect(guideCard, contains('height: railHeight'));
    expect(guideCard, contains('child: portalCard(guides[index])'));
    expect(guideCard, contains('const SizedBox(height: 12)'));
  });

  test('guide portal remains single-column rather than horizontal rail', () {
    expect(guideCard, isNot(contains('scrollDirection: Axis.horizontal')));
    expect(guideCard, isNot(contains('ListView.separated(')));
    expect(guideCard, isNot(contains('PageView(')));
  });

  test('current portal geometry and bottom safety are preserved', () {
    expect(source, contains('EdgeInsets.fromLTRB(4, 4, 4, 114 + safeBottom)'));
    expect(guideCard,
        contains('viewportWidth > 720 ? 620.0 : viewportWidth - 6.0'));
    expect(guideCard, contains('EdgeInsets.symmetric(horizontal: 3)'));
  });
}
