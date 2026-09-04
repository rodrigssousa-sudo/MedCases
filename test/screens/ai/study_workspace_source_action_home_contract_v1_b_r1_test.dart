import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Criar Resumo source actions use canonical Home V2 visual owner', () {
    final src =
        File('lib/screens/study_workspace_screen.dart').readAsStringSync();

    expect(
      src.contains(
        'MEDCASES_STUDY_SOURCE_ACTION_HOME_V2_SHARED_SURFACE_V1_B_R1',
      ),
      isTrue,
    );
    expect(
      src.contains(
        "import '../home_v2/components/common/home_v2_press_surface.dart';",
      ),
      isTrue,
    );
    expect(
      src.contains("import '../home_v2/theme/home_v2_palette.dart';"),
      isTrue,
    );

    expect(src.contains('HomeV2PressSurface('), isTrue);
    expect(src.contains('HomeV2Palette.resolve(dark)'), isTrue);
    expect(src.contains('height: 104'), isTrue);
    expect(src.contains('width: 54'), isTrue);
    expect(src.contains('height: 54'), isTrue);
    expect(src.contains('fit: BoxFit.contain'), isTrue);
    expect(src.contains('fontSize: 11'), isTrue);
    expect(src.contains('FontWeight.w800'), isTrue);
    expect(src.contains('letterSpacing: 0.15'), isTrue);
    expect(src.contains('const gap = 3.0'), isTrue);
    expect(src.contains('spacing: gap'), isTrue);
    expect(src.contains('runSpacing: gap'), isTrue);
    expect(src.contains('constraints.maxWidth >= 720 ? 5 : 3'), isTrue);

    expect(src.contains('study_record_lecture.svg'), isTrue);
    expect(src.contains('study_import_audio.svg'), isTrue);
    expect(src.contains('study_import_pdf.svg'), isTrue);
    expect(src.contains('study_import_image.svg'), isTrue);
    expect(src.contains('study_add_text.svg'), isTrue);

    expect(src.contains('_busy ? null : _recordLecture'), isTrue);
    expect(src.contains('StudySourceType.uploadedAudio'), isTrue);
    expect(src.contains('StudySourceType.pdf'), isTrue);
    expect(src.contains('StudySourceType.image'), isTrue);
    expect(src.contains('_busy ? null : _addText'), isTrue);
  });
}
