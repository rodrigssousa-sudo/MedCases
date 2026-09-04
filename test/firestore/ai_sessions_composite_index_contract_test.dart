import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Map<String, dynamic> indexesJson;
  late List<dynamic> indexes;
  late String firestoreServiceSource;

  setUpAll(() {
    indexesJson = jsonDecode(
      File(
        'firestore.indexes.json',
      ).readAsStringSync(),
    ) as Map<String, dynamic>;

    indexes = indexesJson['indexes'] as List<dynamic>;

    firestoreServiceSource = File(
      'lib/services/firestore_service.dart',
    ).readAsStringSync();
  });

  bool isCanonicalHistoryIndex(
    Object? rawIndex,
  ) {
    if (rawIndex is! Map<String, dynamic>) {
      return false;
    }

    if (rawIndex['collectionGroup'] != 'ai_sessions') {
      return false;
    }

    if (rawIndex['queryScope'] != 'COLLECTION') {
      return false;
    }

    final rawFields = rawIndex['fields'];

    if (rawFields is! List<dynamic>) {
      return false;
    }

    final fields = <String, String>{};

    for (final rawField in rawFields) {
      if (rawField is! Map<String, dynamic>) {
        continue;
      }

      final fieldPath = rawField['fieldPath'];
      final order = rawField['order'];

      if (fieldPath is String && order is String) {
        fields[fieldPath] = order;
      }
    }

    return fields['isDeleted'] == 'ASCENDING' &&
        fields['updatedAt'] == 'DESCENDING';
  }

  group(
    'R18.6W-R3A-R1 — índice canônico do histórico',
    () {
      test(
        'firestore.indexes.json permanece estruturalmente válido',
        () {
          expect(
            indexesJson,
            contains('indexes'),
          );

          expect(
            indexesJson,
            contains('fieldOverrides'),
          );

          expect(
            indexesJson['indexes'],
            isA<List<dynamic>>(),
          );

          expect(
            indexesJson['fieldOverrides'],
            isA<List<dynamic>>(),
          );
        },
      );

      test(
        'existe exatamente um índice canônico do histórico',
        () {
          final matching = indexes.where(isCanonicalHistoryIndex).toList();

          expect(
            matching,
            hasLength(1),
          );
        },
      );

      test(
        'índice usa collectionGroup e queryScope corretos',
        () {
          final index = indexes.where(isCanonicalHistoryIndex).single
              as Map<String, dynamic>;

          expect(
            index['collectionGroup'],
            'ai_sessions',
          );

          expect(
            index['queryScope'],
            'COLLECTION',
          );
        },
      );

      test(
        'índice corresponde à query produtiva',
        () {
          expect(
            firestoreServiceSource,
            matches(
              RegExp(
                r'''\.where\(\s*['"]isDeleted['"]'''
                r'''\s*,\s*isEqualTo:\s*false\s*\)''',
              ),
            ),
          );

          expect(
            firestoreServiceSource,
            matches(
              RegExp(
                r'''\.orderBy\(\s*['"]updatedAt['"]'''
                r'''\s*,\s*descending:\s*true\s*\)''',
              ),
            ),
          );

          expect(
            firestoreServiceSource,
            matches(
              RegExp(
                r'''\.limit\(\s*20\s*\)''',
              ),
            ),
          );
        },
      );

      test(
        'mudança não exige alteração do loader produtivo',
        () {
          expect(
            firestoreServiceSource,
            contains(
              'loadCanonicalAiSessionSummariesTyped',
            ),
          );

          expect(
            firestoreServiceSource,
            contains(
              'batchWriteAiExchange',
            ),
          );

          expect(
            firestoreServiceSource,
            isNot(
              contains(
                'AI-RECONSTRUCTION-R18.6W-R3A',
              ),
            ),
          );
        },
      );
    },
  );
}
