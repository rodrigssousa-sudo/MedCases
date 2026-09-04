import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const homeV2Path = 'lib/home_v2/home_screen_v2.dart';
  const previewPath = 'lib/home_v2/preview/home_v2_preview_screen.dart';
  const inlineChatPath = 'lib/home_v2/components/chat/inline_chat.dart';
  const legacyHomePath = 'lib/screens/home_screen.dart';
  const mainPath = 'lib/main.dart';

  late String homeV2Source;
  late String previewSource;
  late String inlineChatSource;
  late String legacyHomeSource;
  late String mainSource;

  setUpAll(() {
    homeV2Source = File(homeV2Path).readAsStringSync();
    previewSource = File(previewPath).readAsStringSync();
    inlineChatSource = File(inlineChatPath).readAsStringSync();
    legacyHomeSource = File(legacyHomePath).readAsStringSync();
    mainSource = File(mainPath).readAsStringSync();
  });

  group('Cutover oficial da Home V2', () {
    test('HomeScreenV2 permanece como entrada oficial', () {
      expect(mainSource, contains('child: HomeScreenV2('));
      expect(mainSource, isNot(contains('HomeV2PreviewScreen(')));
      expect(mainSource, isNot(contains('HomeScreenV3(')));
    });

    test('árvore oficial não depende de flags de preview', () {
      expect(homeV2Source, isNot(contains('HOME_V2_PREVIEW')));
      expect(homeV2Source, isNot(contains('HOME_V2_LIGHT_PREVIEW')));
      expect(homeV2Source, isNot(contains('HomeV2PreviewScreen(')));
      expect(
        homeV2Source,
        isNot(
          contains(
            "import 'preview/home_v2_preview_screen.dart';",
          ),
        ),
      );
      expect(
        homeV2Source,
        isNot(contains('bool.fromEnvironment(')),
      );
    });

    test('Home V2 possui shell visual oficial próprio', () {
      expect(
        homeV2Source,
        contains(
          'class _HomeV2VisualShell extends StatelessWidget',
        ),
      );
      expect(
        homeV2Source,
        contains(
          'class _HomeV2ClinicalCluster extends StatelessWidget',
        ),
      );
      expect(
        homeV2Source,
        contains(
          'class _HomeV2UtilityCluster extends StatelessWidget',
        ),
      );
    });

    test('shell oficial não cria superfícies externas redundantes', () {
      expect(
        homeV2Source,
        isNot(
          contains(
            'class _HomeV2SectionSurface extends StatelessWidget',
          ),
        ),
      );
      expect(
        homeV2Source,
        isNot(contains('_HomeV2SectionSurface(')),
      );
    });

    test('scroll oficial permanece pertencendo à Home V2', () {
      expect(homeV2Source, contains('SingleChildScrollView('));
      expect(
        homeV2Source,
        contains(
          "key: const PageStorageKey<String>('home-v2-scroll')",
        ),
      );
      expect(
        homeV2Source,
        contains(
          'ScrollViewKeyboardDismissBehavior.onDrag',
        ),
      );
      expect(homeV2Source, contains('bottomContentPadding'));
      expect(homeV2Source, contains('ConstrainedBox('));
    });
  });

  group('Módulos canônicos conectados', () {
    test('seis adaptadores aparecem exatamente uma vez', () {
      const adapters = <String>[
        'InlineChat(',
        'HomeCalculatorDrugsCard(',
        'HomePatientPediatricsRow(',
        'HomeLibraryHistoryRow(',
        'HomeAssessmentNotesTimerCard(',
        'HomeMiGuardiaSection(',
      ];

      for (final adapter in adapters) {
        expect(
          RegExp(RegExp.escape(adapter)).allMatches(homeV2Source).length,
          1,
          reason: 'Adaptador ausente ou duplicado: $adapter',
        );
      }
    });

    test('ordem funcional permanece estável', () {
      const adapters = <String>[
        'InlineChat(',
        'HomeCalculatorDrugsCard(',
        'HomePatientPediatricsRow(',
        'HomeLibraryHistoryRow(',
        'HomeAssessmentNotesTimerCard(',
        'HomeMiGuardiaSection(',
      ];

      var previousIndex = -1;

      for (final adapter in adapters) {
        final index = homeV2Source.indexOf(adapter);

        expect(
          index,
          greaterThan(previousIndex),
          reason: 'Ordem inválida: $adapter',
        );

        previousIndex = index;
      }
    });

    test('callbacks reais continuam repassados', () {
      expect(
        homeV2Source,
        contains('onNavigateToAi: onTabChange'),
      );
      expect(
        homeV2Source,
        contains('openProtocol: openProtocol'),
      );
      expect(
        homeV2Source,
        contains('onTabChange: onTabChange'),
      );
      expect(
        homeV2Source,
        contains('onOpenNotes: onOpenNotes'),
      );
      expect(
        homeV2Source,
        contains('onCheckUpdate: onCheckUpdate'),
      );
    });
  });

  group('Proibição de mocks e motores paralelos', () {
    test('produção não usa elementos demonstrativos', () {
      const forbidden = <String>[
        '_MockConversation',
        '_MockConversationState',
        '_feedback(',
        'onFeedback:',
        'Preview visual:',
        'VALIDAÇÃO VISUAL',
        'REFERÊNCIA DEMONSTRATIVA',
        'Microfone será conectado',
        '_fullResponse',
        '_visibleCharacters',
        '_cursorTimer',
        '_streamTimer',
        'Timer.periodic',
        "import 'dart:async';",
      ];

      for (final token in forbidden) {
        expect(
          homeV2Source,
          isNot(contains(token)),
          reason: 'Elemento demonstrativo encontrado: $token',
        );
      }
    });

    test('produção não importa motores paralelos da Home V2', () {
      const forbiddenImports = <String>[
        'components/chat/chat_controller.dart',
        'components/chat/chat_storage.dart',
        'components/chat/chat_stream.dart',
        'components/navigation/home_actions.dart',
        'components/navigation/home_navigator.dart',
        'components/navigation/home_routes.dart',
        'webviews/webview_router.dart',
      ];

      for (final path in forbiddenImports) {
        expect(
          homeV2Source,
          isNot(contains(path)),
          reason: 'Motor paralelo importado: $path',
        );
      }
    });

    test('Home V2 não assume responsabilidades clínicas', () {
      const forbidden = <String>[
        'SharedPreferences',
        'NotificationService',
        'FirebaseFirestore',
        'FirestoreService',
        'GeminiService',
        'sendAiMessage(',
        'Navigator.of(',
        'Navigator.push',
        'MaterialPageRoute(',
        'PageRouteBuilder(',
        'MeuPlantaoDashboard(',
        'PacienteSession',
      ];

      for (final token in forbidden) {
        expect(
          homeV2Source,
          isNot(contains(token)),
          reason: 'Responsabilidade paralela: $token',
        );
      }
    });
  });

  group('Proprietários canônicos preservados', () {
    test('InlineChat continua delegando ao chat real', () {
      expect(
        inlineChatSource,
        contains('return HomeInlineChat('),
      );
      expect(
        inlineChatSource,
        isNot(contains('SharedPreferences')),
      );
      expect(
        inlineChatSource,
        isNot(contains('Timer.periodic')),
      );
    });

    test('timer permanece no proprietário canônico', () {
      expect(
        legacyHomeSource,
        contains(
          'class _HistorialCompactCardState '
          'extends State<_HistorialCompactCard>',
        ),
      );
      expect(
        legacyHomeSource,
        contains('startFromShiftConsumer('),
      );
      expect(
        legacyHomeSource,
        contains('cancelFromVisualConsumer()'),
      );
    });
  });

  group('Preview permanece somente como referência', () {
    test('preview não entra na árvore oficial', () {
      expect(
        previewSource,
        contains('class HomeV2PreviewScreen'),
      );
      expect(
        homeV2Source,
        isNot(contains('HomeV2PreviewScreen')),
      );
      expect(
        mainSource,
        isNot(contains('HomeV2PreviewScreen')),
      );
    });
  });
}
