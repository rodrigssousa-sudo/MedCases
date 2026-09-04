import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String providerSource;
  late String aiScreenSource;
  late String homeSource;
  late String firestoreSource;
  late String openHistoryRegion;

  setUpAll(() {
    providerSource = File(
      'lib/providers/app_provider.dart',
    ).readAsStringSync();

    aiScreenSource = File(
      'lib/screens/ai_screen.dart',
    ).readAsStringSync();

    homeSource = File(
      'lib/screens/home_screen.dart',
    ).readAsStringSync();

    firestoreSource = File(
      'lib/services/firestore_service.dart',
    ).readAsStringSync();

    final start = aiScreenSource.indexOf(
      'void _openHistory(AppProvider p) {',
    );

    final end = aiScreenSource.indexOf(
      'void _restoreFromSummary',
      start,
    );

    if (start < 0 || end <= start) {
      throw StateError(
        '_openHistory não pôde ser extraído.',
      );
    }

    openHistoryRegion = aiScreenSource.substring(
      start,
      end,
    );
  });

  group(
    'R18.6W-R1 — hidratação canônica do histórico',
    () {
      test(
        'modal solicita exatamente uma hidratação V1 mais V2',
        () {
          expect(
            RegExp(
              r'loadAndMergeAiSessionSummaries\s*\(',
            ).allMatches(
              aiScreenSource,
            ),
            hasLength(1),
          );

          expect(
            openHistoryRegion,
            contains(
              'history_summary_hydration',
            ),
          );

          expect(
            openHistoryRegion.indexOf(
              'loadAndMergeAiSessionSummaries(historyUid)',
            ),
            lessThan(
              openHistoryRegion.indexOf(
                'showModalBottomSheet(',
              ),
            ),
          );
        },
      );

      test(
        'modal continua ligado ao read model canônico',
        () {
          for (final token in const [
            'showModalBottomSheet(',
            'Selector<AppProvider, List<AiSessionSummary>>',
            'selector: (_, prov) => prov.visibleAiSessionSummaries',
            'return ChatHistorySheet(',
            'sessions: sessions',
          ]) {
            expect(
              openHistoryRegion,
              contains(token),
              reason: 'Contrato visual ausente: $token',
            );
          }
        },
      );

      test(
        'AppProvider permanece proprietário da leitura e merge',
        () {
          for (final token in const [
            'AI-RECONSTRUCTION-R18.6W:',
            '_aiSummaryLoadInFlight',
            '_aiSummaryLoadUid',
            '_aiSummaryLoadGeneration',
            'FirestoreService.loadCanonicalAiSessionSummariesTyped(uid)',
            'FirestoreService.loadLegacyAiSessionsTyped(uid)',
            'AiSessionSummary.fromCanonicalJson',
            'AiSessionSummary.fromLegacyJson',
            '_mergeIntoSummaries(serverSummaries)',
            'notifyListeners()',
          ]) {
            expect(
              providerSource,
              contains(token),
              reason: 'Contrato ausente: $token',
            );
          }
        },
      );

      test(
        'loader rejeita geração stale e UID trocado',
        () {
          for (final token in const [
            '_aiSummaryLoadGeneration != generation',
            '_aiSummaryLoadUid != uid',
            'FirebaseAuth.instance.currentUser?.uid',
            'reason=stale_generation',
            'reason=auth_uid_changed',
            'identical(_aiSummaryLoadInFlight, future)',
          ]) {
            expect(
              providerSource,
              contains(token),
              reason: 'Barreira ausente: $token',
            );
          }
        },
      );

      test(
        'Home e Firestore permanecem fora da ativação',
        () {
          expect(
            homeSource,
            isNot(
              contains(
                'loadAndMergeAiSessionSummaries(',
              ),
            ),
          );

          expect(
            firestoreSource,
            isNot(
              contains(
                'AI-RECONSTRUCTION-R18.6W:',
              ),
            ),
          );

          expect(
            firestoreSource,
            contains(
              'loadCanonicalAiSessionSummariesTyped(',
            ),
          );

          expect(
            firestoreSource,
            contains(
              'loadLegacyAiSessionsTyped(',
            ),
          );
        },
      );

      test(
        'persistência restauração e exclusão permanecem intactas',
        () {
          expect(
            RegExp(
              r'await\s+persistAiExchangeOnce\s*\(',
            ).allMatches(
              providerSource,
            ),
            hasLength(6),
          );

          expect(
            openHistoryRegion,
            contains(
              'FirestoreService.deleteLegacyAiSession',
            ),
          );

          expect(
            openHistoryRegion,
            contains(
              '_restoreFromSummary(summary, p)',
            ),
          );
        },
      );
    },
  );
}
