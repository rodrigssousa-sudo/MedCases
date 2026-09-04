import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AI greeting is visible only in the empty state', () {
    final source = File('lib/screens/ai_screen.dart').readAsStringSync();

    expect(source, contains('if (_isOpeningHomeGreeting(i, msg))'));
    expect(source, contains('if (hasConversation)'));
    expect(
      source,
      contains("'msg_\${msg.id}_greeting_hidden_after_start'"),
    );
    expect(source, contains('child: _AiHomeGreeting('));
    expect(source, contains('compact: false'));
    expect(source, contains('animate: false'));

    expect(source, contains('void _injectGreeting()'));
    expect(source, contains('_buildGreeting(p.userName, p.lang)'));
    expect(source, contains('bool _isOpeningHomeGreeting('));
    expect(
      source,
      contains("_messages.any((m) => m.role == 'user')"),
    );

    // Prior physical Plantão cleanup remains intact.
    expect(
      source,
      contains('if (!_longResponse && !hasAutomaticVisibleProjection)'),
    );
  });
}
