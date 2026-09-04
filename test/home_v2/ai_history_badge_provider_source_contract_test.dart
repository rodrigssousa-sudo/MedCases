import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String mainSource;
  late String providerSource;
  late String screenSource;

  setUpAll(() {
    mainSource = File('lib/main.dart').readAsStringSync();
    providerSource = File(
      'lib/providers/app_provider.dart',
    ).readAsStringSync();
    screenSource = File(
      'lib/screens/ai_screen.dart',
    ).readAsStringSync();
  });

  group('R18.6W-R6B — history badge provider source', () {
    test('badge usa a mesma lista reativa do modal', () {
      expect(
        mainSource,
        contains('Selector<AppProvider, int>('),
      );

      expect(
        mainSource,
        contains(
          'provider.visibleAiSessionSummaries.length',
        ),
      );

      expect(
        mainSource,
        isNot(
          contains(
            'valueListenable: '
            'AiScreen.historyCountNotifier',
          ),
        ),
      );
    });

    test('callback de abertura do histórico permanece intacto', () {
      expect(
        mainSource,
        contains(
          'valueListenable: AiScreen.openHistoryCallback',
        ),
      );

      expect(
        mainSource,
        contains(
          'builder: (_, count, __) => GestureDetector(',
        ),
      );
    });

    test('AppProvider mantém o repositório tipado de até 20 sessões', () {
      expect(
        providerSource,
        contains(
          'List<AiSessionSummary> get '
          'visibleAiSessionSummaries',
        ),
      );

      expect(
        providerSource,
        contains(
          'List.unmodifiable(_localAiSessionSummaries)',
        ),
      );

      expect(
        providerSource,
        contains('.take(20)'),
      );
    });

    test('modal continua usando a mesma fonte do Provider', () {
      expect(
        screenSource,
        contains(
          'selector: (_, prov) => '
          'prov.visibleAiSessionSummaries',
        ),
      );
    });

    test('notifier local permanece apenas como legado interno', () {
      expect(
        screenSource,
        contains(
          'static final historyCountNotifier',
        ),
      );

      expect(
        mainSource,
        isNot(contains('historyCountNotifier')),
      );
    });
  });
}
