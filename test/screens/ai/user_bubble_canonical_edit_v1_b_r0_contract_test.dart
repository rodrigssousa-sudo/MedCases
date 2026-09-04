import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserBubble canonical edit V1-B-R0', () {
    late String userBubble;
    late String aiScreen;

    setUpAll(() {
      userBubble = File(
        'lib/screens/ai/widgets/user_bubble.dart',
      ).readAsStringSync();

      aiScreen = File(
        'lib/screens/ai_screen.dart',
      ).readAsStringSync();
    });

    test('UserBubble exposes separate optional canonical edit text', () {
      expect(
        userBubble,
        contains('final String? editText;'),
      );
      expect(
        userBubble,
        contains('this.editText,'),
      );
    });

    test('initial edit controller prefers canonical edit text', () {
      expect(
        userBubble,
        contains('text: widget.editText ?? widget.text,'),
      );
    });

    test('start edit uses canonical text and canonical selection length', () {
      expect(
        userBubble,
        contains(
          'final editableText = widget.editText ?? widget.text;',
        ),
      );
      expect(
        userBubble,
        contains('_editCtrl.text = editableText;'),
      );
      expect(
        userBubble,
        contains('extentOffset: editableText.length'),
      );
    });

    test('save comparison is against canonical text', () {
      expect(
        userBubble,
        contains(
          'final originalEditText = (widget.editText ?? widget.text).trim();',
        ),
      );
      expect(
        userBubble,
        contains('newText != originalEditText'),
      );
    });

    test('AI screen displays compact projection but edits canonical msg.text', () {
      expect(
        RegExp(
          r'UserMessageDisplayPolicy\.visibleText\(\s*msg\.text,\s*\)',
          multiLine: true,
        ).hasMatch(aiScreen),
        isTrue,
      );
      expect(
        aiScreen,
        contains('text: userVisibleText,'),
      );
      expect(
        aiScreen,
        contains('editText: msg.text,'),
      );
    });

    test('copy remains intentionally aligned with visible compact text', () {
      expect(
        aiScreen,
        contains(
          'onCopy: () => _copyMsg(userVisibleText),',
        ),
      );
    });

    test('canonical edit callback remains unchanged', () {
      expect(
        aiScreen,
        contains(
          'onEdit: (newText) => _editUserMessage(msgIndex, newText, p),',
        ),
      );
      expect(
        aiScreen,
        contains('_send(newText, p);'),
      );
    });
  });
}
