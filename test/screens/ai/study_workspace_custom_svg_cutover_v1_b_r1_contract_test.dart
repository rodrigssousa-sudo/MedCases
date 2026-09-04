import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const assets = <String>[
    'assets/icons/study_workspace/study_record_lecture.svg',
    'assets/icons/study_workspace/study_import_audio.svg',
    'assets/icons/study_workspace/study_import_pdf.svg',
    'assets/icons/study_workspace/study_import_image.svg',
    'assets/icons/study_workspace/study_add_text.svg',
  ];

  test('Criar Resumo references exactly the five custom SVG assets', () {
    final src =
        File('lib/screens/study_workspace_screen.dart').readAsStringSync();

    expect(
      src.contains(
        'MEDCASES_STUDY_SOURCE_ACTION_CUSTOM_SVG_CUTOVER_V1_B_R1',
      ),
      isTrue,
    );
    expect(src.contains('final String svgAsset;'), isTrue);
    expect(src.contains('SvgPicture.asset('), isTrue);
    expect(src.contains('fit: BoxFit.contain'), isTrue);

    for (final asset in assets) {
      expect(src.contains(asset), isTrue, reason: asset);
      final file = File(asset);
      expect(file.existsSync(), isTrue, reason: 'missing $asset');
      expect(
        file.readAsStringSync().toLowerCase().contains('<svg'),
        isTrue,
        reason: asset,
      );
    }
  });

  test('functional callbacks remain wired after SVG cutover', () {
    final src =
        File('lib/screens/study_workspace_screen.dart').readAsStringSync();

    expect(src.contains('_busy ? null : _recordLecture'), isTrue);
    expect(src.contains('StudySourceType.uploadedAudio'), isTrue);
    expect(src.contains('StudySourceType.pdf'), isTrue);
    expect(src.contains('StudySourceType.image'), isTrue);
    expect(src.contains('_busy ? null : _addText'), isTrue);
  });

  test('canonical Home visual contract remains intact', () {
    final src =
        File('lib/screens/study_workspace_screen.dart').readAsStringSync();

    expect(src.contains('HomeV2PressSurface('), isTrue);
    expect(src.contains('HomeV2Palette.resolve(dark)'), isTrue);
    expect(src.contains('height: 104'), isTrue);
    expect(src.contains('width: 54'), isTrue);
    expect(src.contains('height: 54'), isTrue);
    expect(src.contains('fontSize: 11'), isTrue);
    expect(src.contains('FontWeight.w800'), isTrue);
    expect(src.contains('const gap = 3.0'), isTrue);
  });

  for (final asset in assets) {
    testWidgets('flutter_svg decodes $asset', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SvgPicture.asset(
                asset,
                width: 54,
                height: 54,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: asset);
      expect(find.byType(SvgPicture), findsOneWidget);
    });
  }
}
