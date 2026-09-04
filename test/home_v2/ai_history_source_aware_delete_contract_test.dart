import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String sheet;
  late String screen;
  late String provider;
  late String firestore;
  late String mainSource;

  setUpAll(() {
    sheet = File(
      'lib/screens/ai/widgets/chat_history_sheet.dart',
    ).readAsStringSync();

    screen = File(
      'lib/screens/ai_screen.dart',
    ).readAsStringSync();

    provider = File(
      'lib/providers/app_provider.dart',
    ).readAsStringSync();

    firestore = File(
      'lib/services/firestore_service.dart',
    ).readAsStringSync();

    mainSource = File(
      'lib/main.dart',
    ).readAsStringSync();
  });

  group('R18.6X-R1-R1 — source-aware history deletion', () {
    test('sheet entrega o resumo completo e aguarda confirmação', () {
      expect(
        sheet,
        contains(
          'Future<bool> Function(AiSessionSummary) onDelete',
        ),
      );

      expect(
        sheet,
        contains('confirmDismiss: (_) => onDelete(s)'),
      );

      expect(
        sheet,
        isNot(
          contains(
            'onDismissed: (_) => onDelete(s.sessionId)',
          ),
        ),
      );
    });

    test('AiScreen separa canonical legacy e localMemory', () {
      expect(screen, contains('switch (summary.source)'));
      expect(
        screen,
        contains('case AiSessionSource.legacyInline:'),
      );
      expect(
        screen,
        contains('case AiSessionSource.canonicalV2:'),
      );
      expect(
        screen,
        contains('case AiSessionSource.localMemory:'),
      );
      expect(
        screen,
        contains(
          'FirestoreService.deleteLegacyAiSession',
        ),
      );
      expect(
        screen,
        contains(
          'FirestoreService.softDeleteCanonicalAiSession',
        ),
      );
    });

    test('falha remota mantém o item', () {
      expect(screen, contains('if (!deleted)'));
      expect(
        screen,
        contains(
          'Não foi possível excluir a consulta.',
        ),
      );
      expect(screen, contains('return false;'));
    });

    test('sucesso atualiza modal e badge pelo Provider', () {
      expect(
        screen,
        contains('p.removeVisibleAiSessionSummary'),
      );
      expect(
        provider,
        contains(
          'bool removeVisibleAiSessionSummary(',
        ),
      );
      expect(provider, contains('notifyListeners();'));
      expect(
        mainSource,
        contains(
          'provider.visibleAiSessionSummaries.length',
        ),
      );
    });

    test('hidratação antiga não reinsere sessão removida', () {
      expect(
        provider,
        contains(
          'final Set<String> _deletedAiSessionIds',
        ),
      );
      expect(
        provider,
        contains(
          '_deletedAiSessionIds.contains(s.sessionId)',
        ),
      );
      expect(provider, contains('continue;'));
    });

    test('canonical usa tombstone e preserva exchanges', () {
      expect(
        firestore,
        contains('softDeleteCanonicalAiSession'),
      );
      expect(
        firestore,
        contains("'isDeleted': true"),
      );
      expect(
        firestore,
        contains(
          "'deletedAt': FieldValue.serverTimestamp()",
        ),
      );
      expect(
        firestore,
        contains(
          '_userAiSessions(uid).doc(sessionId).update',
        ),
      );
      expect(
        firestore,
        isNot(
          contains(
            '_userAiSessions(uid).doc(sessionId).delete()',
          ),
        ),
      );
    });

    test('legacy exclui somente ai_chat_history', () {
      expect(
        firestore,
        contains('deleteLegacyAiSession'),
      );
      expect(
        firestore,
        contains(
          '_userAiHistory(uid).doc(sessionId).delete()',
        ),
      );
    });

    test('loader continua ocultando tombstones', () {
      expect(
        firestore,
        contains(
          ".where('isDeleted', isEqualTo: false)",
        ),
      );
    });
  });
}
