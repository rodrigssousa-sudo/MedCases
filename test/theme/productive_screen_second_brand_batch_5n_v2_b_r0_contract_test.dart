import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String aiScreen;
  late String inlineChat;
  late String study;
  late String mainSource;
  late String aiStatus;
  late String library;
  late String meuPlantao;
  late String homePreview;

  setUpAll(() {
    aiScreen = File('lib/screens/ai_screen.dart').readAsStringSync();
    inlineChat = File(
      'lib/home_v2/components/chat/inline_chat_view.dart',
    ).readAsStringSync();
    study = File('lib/screens/study_workspace_screen.dart').readAsStringSync();

    mainSource = File('lib/main.dart').readAsStringSync();
    aiStatus =
        File('lib/screens/ai/widgets/ai_status_sheet.dart').readAsStringSync();
    library = File('lib/screens/library_screen.dart').readAsStringSync();
    meuPlantao =
        File('lib/widgets/meu_plantao_dashboard.dart').readAsStringSync();
    homePreview = File(
      'lib/home_v2/preview/home_v2_preview_screen.dart',
    ).readAsStringSync();
  });

  test('AI response identity uses canonical Home V2 palette accent', () {
    expect(aiScreen, contains('final accent = palette.accent;'));
    expect(aiScreen, isNot(contains('0xFF00E59B')));
  });

  test('Inline chat dark home accent no longer exposes second brand', () {
    expect(inlineChat, contains('const Color(0xFF0D6B57)'));
    expect(inlineChat, isNot(contains('0xFF00E59B')));
  });

  test(
      'Study mind-map SVG root uses canonical brand while branches stay multicolor',
      () {
    expect(
      study,
      contains(
        "item.isRoot ? '#0D6B57' : _svgBranchColor(item.branchIndex);",
      ),
    );
    expect(study, isNot(contains("item.isRoot ? '#008F66'")));
    for (final color in <String>[
      '#14B8A6',
      '#38BDF8',
      '#8B5CF6',
      '#22C55E',
      '#F59E0B',
      '#EC4899',
      '#06B6D4',
      '#6366F1',
    ]) {
      expect(study, contains("'$color'"));
    }
  });

  test('Known semantic taxonomy and preview residues remain preserved', () {
    expect(mainSource, contains('Nueva consulta iniciada'));
    expect(mainSource, contains('Nova consulta iniciada'));
    expect(
      RegExp(r'0xFF00C781').allMatches(mainSource).length,
      2,
    );
    expect(
      RegExp(r'0xFF008F66').allMatches(mainSource).length,
      2,
    );

    expect(
      aiStatus,
      contains(
        'dark ? const Color(0xFF00C781) : const Color(0xFF008F66);',
      ),
    );
    expect(
      library,
      contains(
        'return dark ? const Color(0xFF00C781) : const Color(0xFF008F66);',
      ),
    );
    expect(meuPlantao, contains("labelPt: 'Nefrologia',"));
    expect(meuPlantao, contains('color: Color(0xFF00E5FF)'));
    expect(homePreview, contains('Color(0xFF00C781)'));
    expect(homePreview, contains('Color(0xFF008F66)'));
  });
}
