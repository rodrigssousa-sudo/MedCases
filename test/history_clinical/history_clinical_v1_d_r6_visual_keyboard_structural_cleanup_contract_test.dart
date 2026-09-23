import 'dart:io';
import 'history_release_runtime_harness.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String history, common, recorder, home, homeV2;
  setUpAll(() {
    history = File('lib/screens/history_screen.dart').readAsStringSync();
    common = File('lib/widgets/common_widgets.dart').readAsStringSync();
    recorder =
        File('lib/screens/clinical_recorder_sheet.dart').readAsStringSync();
    home = File('lib/screens/home_screen.dart').readAsStringSync();
    homeV2 = File('lib/home_v2/home_screen_v2.dart').readAsStringSync();
  });

  test('route remains canonical and untouched', () {
    expect(home, contains('onTabChange(3);'));
    expect(homeV2, contains('onTabChange: onTabChange,'));
  });

  testWidgets('all exact visual owners are marked', (tester) async {
    await verifyHistoryPngCanvas(tester);
    for (final token in <String>[
      'HISTORY_CLINICAL_V1_D_R6_OCR_GRAPHITE',
      'HISTORY_CLINICAL_V1_D_R6_EVOLUTION_METHOD_OWNER',
      'HISTORY_CLINICAL_V1_D_R6_EVOLUTION_CARD_GRAPHITE',
      'HISTORY_CLINICAL_V1_D_R6_VITALS_GRAPHITE',
      'HISTORY_CLINICAL_V1_D_R14_SEX_SOLID_SEGMENTED',
      'HISTORY_CLINICAL_V1_D_R6_EDITOR_TABS',
      'HISTORY_CLINICAL_V1_C_R14_R4_MIC_DOCK_LIGHT_CLOSURE',
    ]) {
      expect(history, contains(token), reason: token);
    }
    expect(common, contains('HISTORY_CLINICAL_V1_D_R6_KEYBOARD_FLOW'));
    expect(recorder, contains('HISTORY_CLINICAL_V1_D_R6_RECORDER_GRAPHITE'));
    expect(history, contains('Color(0xFF1A1D23)'));
    expect(history, contains("'Ditado e IA'"));
    expect(history, contains('onTap: onTapSmart'));
    expect(history, contains('onTap: onTapRelato'));
    expect(history, contains('onTap: onOrganizarIA'));
  });

  testWidgets('Mic replacement structurally removes only unreachable helpers', (tester) async {
    await verifyHistoryKeyboard(tester);
    expect(history, contains('class _MicControlBar'));
    expect(history, isNot(contains('class _MicActionBtn')));
    expect(history, isNot(contains('class _MicStatusBadge')));
    expect(history, isNot(contains('_anyActive')));
  });

  testWidgets('keyboard uses next done and responsive scroll', (tester) async {
    await verifyHistoryKeyboard(tester);
    expect(common, contains('MediaQuery.of(context).viewInsets.bottom + 88'));
    expect(common, contains('FocusScope.of(context).nextFocus()'));
    expect(common, contains('FocusScope.of(context).unfocus()'));
    expect(history, contains('textInputAction: TextInputAction.next'));
  });

  test('clinical OCR dictation AI and recorder contracts remain', () {
    for (final token in <String>[
      'saveHistory(',
      'deleteHistory(',
      '_openOcrPicker',
      '_toggleSmartDictaphone',
      '_showOrganizarIASheet',
      'class _HistoryPreviewSheet',
      'class _EvolutionEditorCard',
    ]) {
      expect(history, contains(token), reason: token);
    }
    expect(recorder, contains('RecorderMode.continuous'));
    expect(recorder, contains('RecorderMode.soapBlocks'));
    expect(recorder, contains('onManual();'));
    expect(recorder, contains('onSoapData: onSoapData'));
  });
}
