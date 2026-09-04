import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Study pending send queue contract', () {
    test('typed and button routes keep one canonical dispatcher', () {
      final source = File('lib/screens/ai_screen.dart').readAsStringSync();

      expect(source, contains('void _sendDebounced('));
      expect(source, contains('_send(\n        text,\n        p,'));
      expect(source, contains('StudyContinuationButton('));
      expect(
        source,
        contains('_sendDebounced(\n                                  prompt,'),
      );
    });

    test('busy Study action queues before history/UI mutation', () {
      final source = File('lib/screens/ai_screen.dart').readAsStringSync();
      final start = source.indexOf('Future<void> _send(');
      expect(start, greaterThanOrEqualTo(0));
      final providerCall = source.indexOf('await p.sendAiMessage(', start);
      expect(providerCall, greaterThan(start));
      final body = source.substring(start, providerCall);

      expect(body, contains('final studyRequestBusy ='));
      expect(body, contains('p.aiRequestBusy'));
      expect(body, contains('if (_longResponse)'));
      expect(body, contains('_queueStudySend('));
      expect(
        body.indexOf('_queueStudySend('),
        lessThan(body.indexOf('_saveCurrentSessionToHistory(p)')),
      );

      for (final token in const <String>[
        'fromButton: fromButton',
        'userDisplayText: userDisplayText',
        'continuationType: continuationType',
        'requestedSections: requestedSections',
      ]) {
        expect(body, contains(token), reason: token);
      }
    });

    test('queue is one-slot and generation-bound', () {
      final source = File('lib/screens/ai_screen.dart').readAsStringSync();

      for (final token in const <String>[
        'Future<void> Function()? _pendingStudySend;',
        'bool _studyPendingDrainScheduled = false;',
        'int _pendingStudySendGeneration = 0;',
        'if (_pendingStudySend != null)',
        'generation != _aiUiRequestGeneration',
        '_thinking || _isStreaming || _sendGuard || p.aiRequestBusy',
        '_pendingStudySend = null;',
      ]) {
        expect(source, contains(token), reason: token);
      }
    });

    test('local restored windows retain 60 messages', () {
      final source = File('lib/screens/ai_screen.dart').readAsStringSync();

      expect(source, contains('msgsSnapshot.length - 60'));
      expect(source, contains('_messages.length - 60'));
      expect(source, isNot(contains('msgsSnapshot.length - 20')));
      expect(source, isNot(contains('_messages.length - 20')));
    });
  });
}
