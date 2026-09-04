import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String emptyChat;
  late String waHeader;
  late String userBubble;
  late String actionRow;
  late String chatHistory;
  late String sharedTheme;

  setUpAll(() {
    emptyChat =
        File('lib/screens/ai/widgets/empty_chat.dart').readAsStringSync();
    waHeader = File('lib/screens/ai/widgets/wa_header.dart').readAsStringSync();
    userBubble =
        File('lib/screens/ai/widgets/user_bubble.dart').readAsStringSync();
    actionRow = File('lib/screens/ai/widgets/action_buttons_row.dart')
        .readAsStringSync();
    chatHistory = File('lib/screens/ai/widgets/chat_history_sheet.dart')
        .readAsStringSync();
    sharedTheme = File('lib/theme/app_theme.dart').readAsStringSync();
  });

  test('Batch 4A markers retained in all five AI widget owners', () {
    const marker =
        'MEDCASES_PRODUCTIVE_SECOND_BRAND_BATCH_4A_V2_B_R1_AI_WIDGETS';
    for (final source in [
      emptyChat,
      waHeader,
      userBubble,
      actionRow,
      chatHistory
    ]) {
      expect(source, contains(marker));
    }
  });

  test('AI widgets no longer expose legacy cyan or teal second-brand literals',
      () {
    for (final source in [
      emptyChat,
      waHeader,
      userBubble,
      actionRow,
      chatHistory
    ]) {
      expect(source, isNot(contains('0xFF00E5FF')));
      expect(source, isNot(contains('0xFF008CA4')));
    }
  });

  test('EmptyChat and WaHeader generic brand controls use canonical accent',
      () {
    expect(emptyChat, contains('0xFF0D6B57'));
    expect(waHeader, contains('0xFF0D6B57'));
    expect(waHeader, contains('0xFFC5A365'));
  });

  test('UserBubble copy action uses canonical accent', () {
    expect(userBubble, contains('iconColor: const Color(0xFF0D6B57)'));
  });

  test('ActionButtonsRow tool identity uses canonical accent', () {
    expect(actionRow, contains('static const _kToolBtn = Color(0xFF0E8000);'));
    expect(actionRow, isNot(contains('0xFF10B981')));
  });

  test('ChatHistorySheet brand identity uses canonical accent', () {
    expect(chatHistory, contains('const brandColor = Color(0xFF0D6B57);'));
    expect(chatHistory, isNot(contains('0xFF10B981')));
  });

  test(
      'Shared theme can advance later without regressing Batch 4A widget semantics',
      () {
    expect(sharedTheme, contains('const kBorderActive = Color(0xFF0D6B57);'));
    expect(sharedTheme, contains('const kAccentBrand'));
    expect(sharedTheme, isNot(contains('00E5FF')));
    expect(sharedTheme, contains('const kAccentGreen'));
    expect(sharedTheme, contains('Color(0xFF10B981)'));
  });
}
