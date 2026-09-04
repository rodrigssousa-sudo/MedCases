import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

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

String _topLevelClassSection(
  String source,
  String classToken,
  String label,
) {
  final start = source.indexOf(classToken);
  expect(start, greaterThanOrEqualTo(0), reason: '$label start missing');

  final nextClass = source.indexOf('\nclass ', start + classToken.length);
  expect(nextClass, greaterThan(start),
      reason: '$label next class boundary missing');

  return source.substring(start, nextClass);
}

void main() {
  late String library;
  late String mainSource;
  late String guideModel;
  late String guidesTab;
  late String guideCard;
  late String topbarBg;

  setUpAll(() {
    library = _read('lib/screens/library_screen.dart');
    mainSource = _read('lib/main.dart');
    guideModel = _read('lib/models/guide_model.dart');

    guidesTab = _between(
      library,
      'class _GuidesTab extends StatelessWidget',
      'class _GuidePortalSearchDelegate',
      '_GuidesTab current owner',
    );

    guideCard = _between(
      library,
      'class _GuideCard extends StatelessWidget',
      'class _LibraryTabEmptyState',
      '_GuideCard current owner',
    );

    topbarBg = _topLevelClassSection(
      library,
      'class _LibraryTopbarBg extends StatelessWidget',
      '_LibraryTopbarBg current owner',
    );
  });

  group('Guia Clínica compact hub current productive owner', () {
    test('MainShell guide route and current liquid-glass topbar remain present',
        () {
      expect(mainSource, contains('ClinicalGuideScreen'));
      expect(
        topbarBg,
        contains('MEDCASES_GUIA_CLINICO_TRUE_LIQUID_GLASS_V1_B_R1'),
      );
      expect(topbarBg, contains('ImageFilter.blur(sigmaX: 16, sigmaY: 16)'));
      expect(topbarBg, contains('withValues(alpha: 0.58)'));
      expect(topbarBg, contains('withValues(alpha: 0.56)'));
    });

    test('guide body remains keyboard-safe with current search ownership', () {
      expect(
        guidesTab,
        contains(
          'keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag',
        ),
      );
      expect(guidesTab, contains('CustomScrollView('));
      expect(
        guidesTab,
        contains('MEDCASES_GUIDES_COUNT_HEADER_REMOVED_V1_B_R3'),
      );
      expect(guidesTab, contains('const SizedBox'));
      expect(guidesTab, contains('.shrink()'));

      // Search is no longer owned by an obsolete 42 px field inside _GuidesTab.
      expect(guidesTab, isNot(contains('height: 42')));
    });

    test('guide cards use current full-bleed editorial cover architecture', () {
      expect(guideCard, contains('final imageUrl = item.coverUrl.trim()'));
      expect(guideCard, contains('CachedNetworkImage('));
      expect(guideCard, contains('fit: BoxFit.cover'));
      expect(guideCard, contains('width: double.infinity'));
      expect(guideCard, contains('height: double.infinity'));
      expect(guideCard, contains('fallbackBackground()'));
      expect(guideCard, contains('const railHeight = 356.0'));
      expect(
        guideCard,
        contains(
          'final cardWidth = viewportWidth > 720 ? 620.0 : viewportWidth - 6.0',
        ),
      );

      // Obsolete compact 72 px thumbnail geometry must not return.
      expect(guideCard, isNot(contains('width: 72')));
    });

    test('cover model pipeline keeps all current aliases', () {
      expect(guideModel, contains('final String coverUrl'));
      expect(guideModel, contains("'coverUrl'"));
      expect(guideModel, contains("'imageUrl'"));
      expect(guideModel, contains("'thumbnailUrl'"));
      expect(guideModel, contains("'coverImageUrl'"));
      expect(
        guideModel,
        contains("final coverUrl = _firstNonEmpty(json, ["),
      );
    });

    test(
        'current visual density and action-bar footer clearance remain present',
        () {
      expect(
        guidesTab,
        contains('EdgeInsets.fromLTRB(4, 4, 4, 114 + safeBottom)'),
      );
      expect(guideCard, contains('BorderRadius.circular(20)'));
      expect(
        guideCard,
        contains('padding: const EdgeInsets.only(top: 8, bottom: 18)'),
      );
      expect(
        guideCard,
        contains('padding: const EdgeInsets.symmetric(horizontal: 3)'),
      );
      expect(guideCard, contains('if (index != guides.length - 1)'));
      expect(guideCard, contains('const SizedBox(height: 12)'));

      // Obsolete compact-card rhythm must not be restored.
      expect(guideCard, isNot(contains('EdgeInsets.only(bottom: 3)')));
    });

    test('current vertical portal architecture remains the productive owner',
        () {
      expect(guidesTab, contains('portalGuides: filtered'));
      expect(guidesTab, contains('featured: i == 0'));
      expect(guidesTab, contains('childCount: filtered.isEmpty ? 0 : 1'));
      expect(
        guideCard,
        contains(
          'for (var index = 0; index < guides.length; index++)',
        ),
      );
      expect(guideCard, contains('child: portalCard(guides[index])'));
      expect(guideCard, isNot(contains('scrollDirection: Axis.horizontal')));
    });
  });
}
