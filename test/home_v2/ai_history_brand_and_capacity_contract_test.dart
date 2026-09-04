import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const sheetPath = 'lib/screens/ai/widgets/chat_history_sheet.dart';
  const providerPath = 'lib/providers/app_provider.dart';
  const firestorePath = 'lib/services/firestore_service.dart';
  const screenPath = 'lib/screens/ai_screen.dart';
  const modelPath = 'lib/services/ai/ai_finalization_transaction.dart';

  late String sheet;
  late String provider;
  late String firestore;
  late String screen;
  late String model;

  setUpAll(() {
    sheet = File(sheetPath).readAsStringSync();
    provider = File(providerPath).readAsStringSync();
    firestore = File(firestorePath).readAsStringSync();
    screen = File(screenPath).readAsStringSync();
    model = File(modelPath).readAsStringSync();
  });

  group('R18.6W-R5B-R4 — histórico M+ e capacidade 20', () {
    test('apresentação mostra M+, data e hora local', () {
      expect(sheet, contains("'M+'"));
      expect(sheet, contains('.toLocal();'));
      expect(
        sheet,
        contains(r"return '$day/$month/${dt.year}';"),
      );
      expect(
        sheet,
        contains(r"return '$hour:$minute';"),
      );
    });

    test('rótulos técnicos não aparecem na interface', () {
      expect(sheet, isNot(contains('AiSessionSource')));
      expect(sheet, isNot(contains('s.source')));
      expect(sheet, isNot(contains("'v2'")));
      expect(sheet, isNot(contains("'legacy'")));
      expect(sheet, isNot(contains("'local'")));
      expect(sheet, isNot(contains('(máx. 10)')));
      expect(sheet, isNot(contains('sesiones guardadas')));
      expect(sheet, isNot(contains('sessões salvas')));
    });

    test('AiSessionSource continua interno e source-aware', () {
      expect(model, contains('enum AiSessionSource'));
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
    });

    test('read model mantém no máximo 20 sessões', () {
      expect(
        provider,
        contains(
          'if (_localAiSessionSummaries.length > 20)',
        ),
      );
      expect(
        provider,
        contains(
          '_localAiSessionSummaries.removeRange('
          '20, _localAiSessionSummaries.length);',
        ),
      );
    });

    test('query canônica usa limit 20', () {
      expect(
        firestore,
        contains('''
    final query = _userAiSessions(uid)
        .where('isDeleted', isEqualTo: false)
        .orderBy('updatedAt', descending: true)
        .limit(20);
'''),
      );
    });

    test('cache local usa capacidade 20', () {
      expect(
        screen,
        contains('if (histSnapshot.length > 20)'),
      );

      expect(
        RegExp(r'if \(_chatHistory\.length > 20\)').allMatches(screen).length,
        2,
      );

      expect(
        RegExp(
          r'_chatHistory\.removeRange'
          r'\(20, _chatHistory\.length\);',
        ).allMatches(screen).length,
        2,
      );
    });

    test('ordenação e deduplicação continuam intactas', () {
      expect(
        provider,
        contains(
          '_localAiSessionSummaries.sort('
          '(a, b) => b.updatedAt.compareTo(a.updatedAt));',
        ),
      );

      expect(
        provider,
        matches(
          RegExp(
            r'\.indexWhere\s*\(\s*\(e\)\s*=>\s*'
            r'e\.sessionId\s*==\s*s\.sessionId',
            multiLine: true,
          ),
        ),
      );
    });
  });
}
