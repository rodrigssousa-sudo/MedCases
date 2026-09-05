import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Home Web latest guide covers — editorial hero image alias V1-B-R0',
      () {
    late String guideModel;
    late String homeGrid;

    setUpAll(() {
      guideModel = File('lib/models/guide_model.dart').readAsStringSync();
      homeGrid = File(
        'lib/home_v2/components/home_web_latest_guides_grid.dart',
      ).readAsStringSync();
    });

    test('GuideModel consumes editorial heroImageUrl as cover fallback', () {
      final aliasBlock = RegExp(
        r'final\s+coverUrl\s*=\s*_firstNonEmpty\s*\(\s*json\s*,\s*\[(.*?)\]\s*\)',
        dotAll: true,
      ).firstMatch(guideModel);

      expect(aliasBlock, isNotNull);
      final block = aliasBlock!.group(1)!;

      expect(block, contains("'coverUrl'"));
      expect(block, contains("'imageUrl'"));
      expect(block, contains("'thumbnailUrl'"));
      expect(block, contains("'coverImageUrl'"));
      expect(block, contains("'heroImageUrl'"));

      // Backward compatibility: existing canonical/legacy cover keys retain
      // precedence; heroImageUrl is only the missing editorial fallback.
      expect(block.indexOf("'coverUrl'"),
          lessThan(block.indexOf("'heroImageUrl'")));
      expect(
        block.indexOf("'coverImageUrl'"),
        lessThan(block.indexOf("'heroImageUrl'")),
      );
    });

    test('wide Web Home still renders GuideModel.coverUrl via network image',
        () {
      expect(
        homeGrid,
        contains('final imageUrl = guide.coverUrl.trim();'),
      );
      expect(homeGrid, contains('Image.network('));
      expect(homeGrid, contains('imageUrl,'));
      expect(homeGrid, contains('fit: BoxFit.cover'));
    });

    test('fix does not add a second guide image/network owner to Home', () {
      expect(
        RegExp(r'final\s+imageUrl\s*=\s*guide\.coverUrl\.trim\(\)')
            .allMatches(homeGrid)
            .length,
        1,
      );
      expect(
        RegExp(r'Image.network\s*\(').allMatches(homeGrid).length,
        1,
      );
    });
  });
}
