import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String homeSource;
  late String providerSource;
  late String firestoreSource;
  late String persistMethod;

  setUpAll(() {
    homeSource = File(
      'lib/screens/home_screen.dart',
    ).readAsStringSync();

    providerSource = File(
      'lib/providers/app_provider.dart',
    ).readAsStringSync();

    firestoreSource = File(
      'lib/services/firestore_service.dart',
    ).readAsStringSync();

    final persistStart = homeSource.indexOf(
      'Future<void> _homePersistTurn() async {',
    );

    final sendStart = homeSource.indexOf(
      'await p.sendAiMessage(',
      persistStart,
    );

    if (persistStart < 0 || sendStart <= persistStart) {
      throw StateError(
        '_homePersistTurn ou sendAiMessage não localizado.',
      );
    }

    persistMethod = homeSource.substring(
      persistStart,
      sendStart,
    );
  });

  group(
    'R18.6U-R3 — proprietário canônico da persistência da Home',
    () {
      test(
        'Home não produz documentos remotos de histórico',
        () {
          expect(
            persistMethod,
            isNot(
              contains(
                'FirestoreService.saveAiSession(',
              ),
            ),
          );

          expect(
            persistMethod,
            isNot(
              contains(
                'batchWriteAiExchange(',
              ),
            ),
          );

          expect(
            persistMethod,
            isNot(
              contains(
                'persistAiExchangeOnce(',
              ),
            ),
          );

          expect(
            persistMethod,
            contains(
              'canonical_remote_owned_by_app_provider',
            ),
          );
        },
      );

      test(
        'SharedPreferences permanece como espelho local aguardado',
        () {
          for (final token in const [
            'SharedPreferences.getInstance()',
            "final histKey = '\${uid ?? 'anon'}_\$_kHistKey';",
            'histList.removeWhere(',
            "e['id'] == stableSessionId",
            'histList.insert(0, session);',
            'if (histList.length > 10)',
            'histList = histList.sublist(0, 10);',
            'await prefs.setString(histKey, jsonEncode(histList));',
          ]) {
            expect(
              persistMethod,
              contains(token),
              reason: 'Contrato de cache ausente: $token',
            );
          }
        },
      );

      test(
        '_homePersistTurn aceita somente turno user mais ai válido',
        () {
          for (final token in const [
            "m['isError'] != true",
            'if (validMsgs.isEmpty) return;',
            'if (validMsgs.length < 2) return;',
            "final lastRole = validMsgs.last['role'];",
            "lastRole != 'ai'",
            "m['role'] == 'user'",
          ]) {
            expect(
              persistMethod,
              contains(token),
              reason: 'Guard ausente: $token',
            );
          }
        },
      );

      test(
        'chamadores visuais e envio permanecem preservados',
        () {
          expect(
            RegExp(
              r'_homePersistTurn\s*\(\s*\)\s*;',
            ).allMatches(
              homeSource,
            ),
            hasLength(2),
          );

          expect(
            RegExp(
              r'await\s+p\.sendAiMessage\s*\(',
            ).allMatches(
              homeSource,
            ),
            hasLength(1),
          );

          expect(
            homeSource,
            contains(
              'longResponse: true',
            ),
          );

          expect(
            homeSource,
            contains(
              'onDone: (fin) {',
            ),
          );

          expect(
            homeSource,
            contains(
              'onError: (err) {',
            ),
          );
        },
      );

      test(
        'AppProvider mantém seis costuras canônicas',
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
            RegExp(
              r'context:\s+activeSessionCtx',
            ).allMatches(
              providerSource,
            ),
            hasLength(5),
          );

          expect(
            providerSource,
            contains(
              'context: sessionCtx',
            ),
          );
        },
      );

      test(
        'APIs Firestore legada e canônica permanecem disponíveis',
        () {
          expect(
            firestoreSource,
            contains(
              'saveAiSession(',
            ),
          );

          expect(
            firestoreSource,
            contains(
              'batchWriteAiExchange(',
            ),
          );

          expect(
            firestoreSource,
            contains(
              ".collection('ai_chat_history')",
            ),
          );

          expect(
            firestoreSource,
            contains(
              ".collection('ai_sessions')",
            ),
          );

          expect(
            firestoreSource,
            contains(
              ".collection('exchanges')",
            ),
          );
        },
      );
    },
  );
}
