import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Portal loads ten newest guides per page', () {
    final firestore = File(
      'lib/services/firestore_service.dart',
    ).readAsStringSync();

    expect(firestore, contains('static const int guidesPortalPageSize = 10;'));
    expect(firestore, contains(".orderBy('uploadedAt', descending: true)"));
    expect(firestore, contains('.limit(guidesPortalPageSize)'));
    expect(firestore, contains('guides.take(guidesPortalPageSize)'));
  });

  test('Next page uses cursor and next ten only', () {
    final firestore = File(
      'lib/services/firestore_service.dart',
    ).readAsStringSync();
    final library = File('lib/screens/library_screen.dart').readAsStringSync();

    expect(firestore, contains('loadNextPublishedGuidesPage'));
    expect(firestore, contains('.startAfter(<Object?>[cursor])'));
    expect(
      library,
      contains('page.length >= FirestoreService.guidesPortalPageSize'),
    );
    expect(
      library,
      contains('notification.metrics.extentAfter < cardWidth * 0.75'),
    );
    expect(library, contains('onLoadMore: _loadMoreGuides'));
  });

  test('Pagination deduplicates and stays newest-first', () {
    final library = File('lib/screens/library_screen.dart').readAsStringSync();

    expect(library, contains('for (final guide in _guides) guide.id: guide'));
    expect(
      library,
      contains('..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt))'),
    );
    expect(library, contains('await _sub?.cancel()'));
  });

  test('New guides receive searchable prefixes automatically', () {
    final firestore = File(
      'lib/services/firestore_service.dart',
    ).readAsStringSync();

    expect(firestore, contains('_buildGuideSearchPrefixes'));
    expect(firestore, contains("'searchPrefixes'"));
    expect(firestore, contains("'searchIndexVersion'"));
    expect(firestore, contains('guide.title'));
    expect(firestore, contains('guide.category'));
    expect(firestore, contains('guide.description'));
  });

  test('Medical topic aliases are supported', () {
    final firestore = File(
      'lib/services/firestore_service.dart',
    ).readAsStringSync();

    expect(firestore, contains("'nefro'"));
    expect(firestore, contains("'renal'"));
    expect(firestore, contains("'pneumo'"));
    expect(firestore, contains("'pulmonar'"));
    expect(firestore, contains("'cardio'"));
    expect(firestore, contains("'cardiovascular'"));
    expect(
      firestore,
      contains(".where('searchPrefixes', arrayContains: term)"),
    );
  });

  test('Whole catalog search is remote and newest-first', () {
    final firestore = File(
      'lib/services/firestore_service.dart',
    ).readAsStringSync();
    final library = File('lib/screens/library_screen.dart').readAsStringSync();

    expect(
      library,
      contains('remoteSearch: FirestoreService.searchPublishedGuides'),
    );
    expect(library, contains('future: remoteSearch(query)'));
    expect(
      firestore,
      contains('..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt))'),
    );
    expect(
      firestore,
      contains("'uploadedAt': DateTime.now().toUtc().toIso8601String()"),
    );
  });
}
