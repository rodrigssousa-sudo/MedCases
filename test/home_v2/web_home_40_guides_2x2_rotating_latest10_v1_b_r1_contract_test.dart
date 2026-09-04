import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wide Web replaces only the redundant Home InlineChat slot', () {
    final home = File('lib/home_v2/home_screen_v2.dart').readAsStringSync();

    expect(
      home,
      contains('MEDCASES_WEB_HOME_40_GUIDES_2X2_ROTATING_LATEST10_V1_B_R1'),
    );
    expect(
      home,
      contains(
          'final useWebWideGuidesShowcase = kIsWeb && viewportWidth >= 1024;'),
    );
    expect(home, contains('? HomeWebLatestGuidesGrid('));
    expect(home, contains(': InlineChat('));
    expect(home, contains('onNavigateToAi: onTabChange'));

    // Native and narrow-Web still retain the canonical InlineChat implementation.
    expect(home, contains("import 'components/chat/inline_chat.dart';"));
  });

  test('showcase is exactly 2x2 over a pool of latest 10', () {
    final source = File(
      'lib/home_v2/components/home_web_latest_guides_grid.dart',
    ).readAsStringSync();

    expect(source, contains('static const int _poolLimit = 10;'));
    expect(source, contains('static const int _visibleCount = 4;'));
    expect(source, contains('crossAxisCount: 2'));
    expect(source, contains('itemCount: visible.length'));
    expect(
      source,
      contains('..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));'),
    );
    expect(source, contains('normalized.take(_poolLimit)'));
  });

  test('rotation deterministically exposes the entire ten-guide pool', () {
    final source = File(
      'lib/home_v2/components/home_web_latest_guides_grid.dart',
    ).readAsStringSync();

    expect(source, contains('Timer.periodic(_rotationInterval'));
    expect(source, contains('Duration(seconds: 8)'));
    expect(
      source,
      contains('_offset = (_offset + _visibleCount) % _guides.length;'),
    );

    // For pool=10 and step=4 the starts are 0,4,8,2,6 then repeat.
    final starts = <int>[];
    var offset = 0;
    for (var i = 0; i < 5; i++) {
      starts.add(offset);
      offset = (offset + 4) % 10;
    }
    expect(starts.toSet(), <int>{0, 2, 4, 6, 8});

    final exposed = <int>{};
    for (final start in starts) {
      for (var i = 0; i < 4; i++) {
        exposed.add((start + i) % 10);
      }
    }
    expect(exposed, <int>{0, 1, 2, 3, 4, 5, 6, 7, 8, 9});
  });

  test('guide cards mirror the canonical mobile editorial visual language', () {
    final source = File(
      'lib/home_v2/components/home_web_latest_guides_grid.dart',
    ).readAsStringSync();
    final library = File('lib/screens/library_screen.dart').readAsStringSync();

    expect(library, contains('class _GuideCard extends StatelessWidget'));
    expect(library, contains('guide.coverUrl.trim()'));
    expect(library, contains('Color(0xFF10B981)'));

    expect(source, contains('CachedNetworkImage('));
    expect(source, contains('guide.coverUrl.trim()'));
    expect(source, contains('guide.localizedTitle(isEs)'));
    expect(source, contains('guide.localizedDescription(isEs)'));
    expect(source, contains('Color(0xFF10B981)'));
    expect(source, contains('BorderRadius.circular(14)'));
    expect(source, contains('width: 0.7'));
  });

  test('Home guide opens through the same editorial reader bridge', () {
    final source = File(
      'lib/home_v2/components/home_web_latest_guides_grid.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('ClinicalGuidesEditorialService.loadById(guide.id)'),
    );
    expect(source, contains('article != null && article.hasEditorialBody'));
    expect(source, contains('ClinicalGuideArticleScreen('));
    expect(source, contains('article.forLanguage(lang)'));
    expect(source, contains('Navigator.of(context).push<void>('));
    expect(source, contains('openAcademicSourceSecurely('));
  });
}
