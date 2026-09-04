import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const legacyHomePath = 'lib/screens/home_screen.dart';
  const homeV2Path = 'lib/home_v2/home_screen_v2.dart';

  late String legacyHomeSource;
  late String homeV2Source;

  setUpAll(() {
    legacyHomeSource = File(legacyHomePath).readAsStringSync();
    homeV2Source = File(homeV2Path).readAsStringSync();
  });

  group('HomeAssessmentNotesTimerCard', () {
    test('é um adaptador público sem motor de timer próprio', () {
      expect(
        legacyHomeSource,
        contains(
          'class HomeAssessmentNotesTimerCard extends StatefulWidget',
        ),
      );

      expect(
        legacyHomeSource,
        isNot(
          contains(
            'class HomeAssessmentNotesTimerCard extends StatelessWidget',
          ),
        ),
      );
    });

    test('mantém o proprietário canônico montado e projeta a view V2', () {
      final start = legacyHomeSource.indexOf(
        'class HomeAssessmentNotesTimerCard extends StatefulWidget',
      );
      final end = legacyHomeSource.indexOf(
        'class _HomeInlineChatGate extends StatelessWidget',
        start,
      );

      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));

      final adapterSource = legacyHomeSource.substring(start, end);

      expect(
        adapterSource,
        contains('return Column('),
      );
      expect(
        adapterSource,
        contains('Offstage('),
      );
      expect(
        adapterSource,
        contains('offstage: true'),
      );
      expect(
        adapterSource,
        contains('child: _HistorialCompactCard('),
      );
      expect(
        adapterSource,
        contains('key: _ownerKey'),
      );
      expect(
        adapterSource,
        contains('visualState: _visualState'),
      );
      expect(
        adapterSource,
        contains('HomeV2UtilityRow('),
      );
      expect(
        adapterSource,
        contains('HomeScreen._openAvaliacao(context)'),
      );
      expect(
        adapterSource,
        contains('widget.onOpenNotes()'),
      );
      expect(
        adapterSource,
        contains('_ownerKey.currentState?._openTimerSheet()'),
      );
    });

    test('não agenda, persiste ou restaura timer paralelamente', () {
      final start = legacyHomeSource.indexOf(
        'class HomeAssessmentNotesTimerCard extends StatefulWidget',
      );
      final end = legacyHomeSource.indexOf(
        'class _HomeInlineChatGate extends StatelessWidget',
        start,
      );

      final adapterSource = legacyHomeSource.substring(start, end);

      const forbiddenTokens = <String>[
        'Timer.periodic',
        'SharedPreferences.getInstance',
        'NotificationService',
        'scheduleTimerNotification',
        'cancelTimerNotification',
        'WidgetsBindingObserver',
        '_endAt',
        '_remainingSecs',
        '_notificationId',
      ];

      for (final token in forbiddenTokens) {
        expect(
          adapterSource,
          isNot(contains(token)),
          reason: 'Responsabilidade paralela encontrada: $token',
        );
      }
    });

    test('preserva callbacks reais de Avaliação, Notas e Timer', () {
      final start = legacyHomeSource.indexOf(
        'class HomeAssessmentNotesTimerCard extends StatefulWidget',
      );
      final end = legacyHomeSource.indexOf(
        'class _HomeInlineChatGate extends StatelessWidget',
        start,
      );

      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));

      final adapterSource = legacyHomeSource.substring(start, end);

      expect(
        adapterSource,
        contains('HomeScreen._openAvaliacao(context)'),
      );
      expect(
        adapterSource,
        contains('widget.onOpenNotes()'),
      );
      expect(
        adapterSource,
        contains('_ownerKey.currentState?._openTimerSheet()'),
      );
    });

    test('preserva _HistorialCompactCardState como proprietário real', () {
      expect(
        legacyHomeSource,
        contains(
          'class _HistorialCompactCardState extends State<_HistorialCompactCard>',
        ),
      );

      expect(
        legacyHomeSource,
        matches(RegExp(r'(?:Future<void>|void)\s+_startTimer\s*\(')),
      );
      expect(
        legacyHomeSource,
        contains('_cancelTimer()'),
      );
    });
  });

  group('Injeção do adaptador na Home V2', () {
    test('HomeScreen possui slot opcional específico', () {
      expect(
        legacyHomeSource,
        contains('final Widget? assessmentNotesTimerCard;'),
      );
      expect(
        legacyHomeSource,
        contains('this.assessmentNotesTimerCard,'),
      );
    });

    test('árvore mobile mantém fallback canônico', () {
      expect(
        legacyHomeSource,
        contains('widget.assessmentNotesTimerCard ??'),
      );
      expect(
        legacyHomeSource,
        contains('_HistorialCompactCard('),
      );
    });

    test('HomeScreenV2 monta diretamente o adaptador oficial', () {
      expect(
        RegExp(
          r'\bHomeAssessmentNotesTimerCard\s*\(',
        ).allMatches(homeV2Source).length,
        1,
      );
      expect(
        homeV2Source,
        isNot(contains('assessmentNotesTimerCard:')),
      );
      expect(
        homeV2Source,
        contains('onOpenNotes: onOpenNotes,'),
      );
      expect(
        homeV2Source,
        contains('onCheckUpdate: onCheckUpdate,'),
      );
    });

    test('Home V2 não implementa timer ou navegação paralelos', () {
      const forbiddenTokens = <String>[
        'Timer.periodic',
        'SharedPreferences',
        'NotificationService',
        'Navigator.of(',
        'PageRouteBuilder(',
        'AvaliacaoScreen(',
      ];

      for (final token in forbiddenTokens) {
        expect(
          homeV2Source,
          isNot(contains(token)),
          reason: 'Responsabilidade proibida na Home V2: $token',
        );
      }
    });
  });
}
