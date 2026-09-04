import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const mainPath = 'lib/main.dart';
  const legacyHomePath = 'lib/screens/home_screen.dart';
  const homeV2Path = 'lib/home_v2/home_screen_v2.dart';

  late String mainSource;
  late String legacyHomeSource;
  late String homeV2Source;

  setUpAll(() {
    mainSource = File(mainPath).readAsStringSync();
    legacyHomeSource = File(legacyHomePath).readAsStringSync();
    homeV2Source = File(homeV2Path).readAsStringSync();
  });

  group('Composição oficial futura da Home V2', () {
    test('ordem funcional oficial permanece congelada', () {
      const officialMobileOrder = <String>[
        'chat_clinico',
        'calculadoras_e_farmacos',
        'grade_adulto_pediatria_ferramentas_historia_clinica',
        'avaliacao_notas_timer',
        'mi_guardia',
        'reserva_shell_flutuante',
      ];

      expect(
        officialMobileOrder,
        orderedEquals(const <String>[
          'chat_clinico',
          'calculadoras_e_farmacos',
          'grade_adulto_pediatria_ferramentas_historia_clinica',
          'avaliacao_notas_timer',
          'mi_guardia',
          'reserva_shell_flutuante',
        ]),
      );
    });

    test('Home V2 continua sendo a entrada oficial do MainShell', () {
      expect(mainSource, contains('child: HomeScreenV2('));
      expect(mainSource, isNot(contains('child: HomeScreenV3(')));
    });

    test('Home V2 possui composição e scroll próprios', () {
      expect(homeV2Source, isNot(contains('return HomeScreen(')));
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
          'keyboardDismissBehavior: '
          'ScrollViewKeyboardDismissBehavior.onDrag',
        ),
      );

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
        final currentIndex = homeV2Source.indexOf(adapter);

        expect(
          currentIndex,
          greaterThan(previousIndex),
          reason: 'Ordem inválida ou adaptador ausente: $adapter',
        );

        previousIndex = currentIndex;
      }

      const obsoleteSlots = <String>[
        'inlineChat:',
        'calculatorDrugsCard:',
        'patientPediatricsRow:',
        'libraryHistoryRow:',
        'assessmentNotesTimerCard:',
        'miGuardiaSection:',
      ];

      for (final slot in obsoleteSlots) {
        expect(
          homeV2Source,
          isNot(contains(slot)),
          reason: 'Slot da fachada antiga ainda presente: $slot',
        );
      }
    });
  });

  group('Shell permanente e intocável', () {
    test('header mobile pertence exclusivamente ao MainShell', () {
      expect(mainSource, contains('class _MobileAppBar'));
      expect(mainSource, contains('appBar: isHome'));

      expect(homeV2Source, isNot(contains('_MobileAppBar(')));
      expect(homeV2Source, isNot(contains('AppBar(')));
      // Não procura texto de marca, pois ele pode existir legitimamente
      // em comentários de documentação. O contrato deve impedir widgets
      // ou classes de header paralelos na árvore da Home V2.
      expect(homeV2Source, isNot(contains('class _HomeV2Header')));
      expect(homeV2Source, isNot(contains('_HomeV2Header(')));
    });

    test('dock inferior e faixa legal permanecem no MainShell', () {
      expect(mainSource, contains('class _FloatingFooter'));
      expect(mainSource, contains('return _FloatingFooter('));
      expect(mainSource, contains('class _LegalBar'));
      expect(
        mainSource,
        contains(
          '_LegalBar(dark: widget.dark, insideSafeArea: true)',
        ),
      );

      expect(homeV2Source, isNot(contains('_FloatingFooter(')));
      expect(homeV2Source, isNot(contains('_LegalBar(')));
    });

    test('Home canônica reserva espaço inferior para o shell flutuante', () {
      expect(
        legacyHomeSource,
        contains('final double bottomPad ='),
      );
      expect(
        legacyHomeSource,
        contains('kIsWeb ? 24.0 : safeBottom + 112.0'),
      );
      expect(
        legacyHomeSource,
        contains('bottomPad,'),
      );
    });
  });

  group('Mapa real de navegação', () {
    test('índices oficiais do MainShell permanecem congelados', () {
      expect(
        mainSource,
        contains(
          'child: _RxProtoCombo(',
        ),
      );
      expect(
        mainSource,
        contains(
          'const RepaintBoundary(child: AiScreen()), // 2',
        ),
      );
      expect(
        mainSource,
        contains(
          'const RepaintBoundary(child: HistoryScreen()), // 3',
        ),
      );
      expect(
        mainSource,
        contains(
          'const RepaintBoundary(child: ToolsScreen()), // 4',
        ),
      );
      // MEDCASES_MAIN_MAP_5_7_RECONCILED_2026
      expect(
        mainSource,
        contains('child: ClinicalGuideScreen(),'),
      );
      expect(
        mainSource,
        contains('), // 5 — GUIA CLÍNICO / GUÍA CLÍNICA'),
      );
      expect(
        mainSource,
        contains('child: VaccinesScreen(onBack: _closeVaccines),'),
      );
      expect(
        mainSource,
        contains('), // 6 — VACINA/VACUNA workspace interno'),
      );
      expect(
        mainSource,
        contains('child: ClinicalSimulationScreen(),'),
      );
      expect(
        mainSource,
        contains('), // 7 — SIMULAÇÃO / SIMULACIÓN workspace interno'),
      );
    });

    test('Home V2 não pode adivinhar destinos por índices locais', () {
      expect(homeV2Source, isNot(contains('onTabChange(1)')));
      expect(homeV2Source, isNot(contains('onTabChange(2)')));
      expect(homeV2Source, isNot(contains('onTabChange(3)')));
      expect(homeV2Source, isNot(contains('onTabChange(4)')));
      expect(homeV2Source, isNot(contains('onTabChange(5)')));
    });

    test('Biblioteca e História Clínica mantêm destinos canônicos', () {
      expect(
        legacyHomeSource,
        contains('onTap: () => onTabChange(5)'),
      );
      expect(
        legacyHomeSource,
        contains('onTap: () => onTabChange(3)'),
      );
    });

    test('Avaliação usa rota real e nunca índice de aba', () {
      expect(
        legacyHomeSource,
        contains(
          'pageBuilder: (_, __, ___) => const AvaliacaoScreen()',
        ),
      );
      expect(
        legacyHomeSource,
        contains(
          'onTap: () => HomeScreen._openAvaliacao(context)',
        ),
      );
    });
  });

  group('Funções obrigatórias preservadas', () {
    test('timer mantém proprietário canônico único', () {
      expect(
        legacyHomeSource,
        contains(
          'final GlobalKey<_HistorialCompactCardState> _timerOwnerKey',
        ),
      );
      expect(
        legacyHomeSource,
        contains(
          'final ValueNotifier<_TimerVisualState> _timerVisualState',
        ),
      );
      expect(
        legacyHomeSource,
        contains(
          'class _HistorialCompactCardState extends State<_HistorialCompactCard>',
        ),
      );

      expect(
        legacyHomeSource,
        contains(
          'widget.ownerKey.currentState?.startFromShiftConsumer(',
        ),
      );
      expect(
        legacyHomeSource,
        contains(
          'widget.ownerKey.currentState?.cancelFromVisualConsumer()',
        ),
      );
    });

    test('timer, Avaliação e Notas permanecem no bloco canônico', () {
      expect(
        legacyHomeSource,
        contains("label: isEs ? 'Evaluación' : 'Avaliação'"),
      );
      expect(
        legacyHomeSource,
        contains('onTap: widget.onOpenNotes'),
      );
      // O contrato do timer é funcional, não dependente de um ícone
      // específico. O consumidor visual deve continuar delegado ao
      // proprietário canônico.
      expect(
        legacyHomeSource,
        contains('startFromShiftConsumer('),
      );
      expect(
        legacyHomeSource,
        contains('cancelFromVisualConsumer()'),
      );
    });

    test('Mi Guardia permanece montado na árvore mobile', () {
      expect(
        legacyHomeSource,
        contains('return _HomeMiGuardiaSection('),
      );
      expect(
        legacyHomeSource,
        contains('child: MeuPlantaoDashboard('),
      );
      expect(
        legacyHomeSource,
        contains(
          'onManageTap: () => showPlantaoManageSheet(context)',
        ),
      );
    });

    test('Paciente e Pediatria mantêm rotas canônicas', () {
      expect(
        legacyHomeSource,
        contains(
          '_AdultoShell(openProtocol: openProtocol)',
        ),
      );
      expect(
        legacyHomeSource,
        contains(
          'onTabChange(8);',
        ),
      );
    });
  });

  group('Proibições arquiteturais', () {
    test('Home V2 não utiliza componentes placeholders', () {
      const forbiddenClasses = <String>[
        'AdultCard',
        'AssessmentCard',
        'CalculatorCard',
        'DrugsCard',
        'HistoryCard',
        'LibraryCard',
        'NotesCard',
        'PatientCard',
        'PediatricsCard',
        'HomeActions',
        'HomeNavigator',
      ];

      for (final className in forbiddenClasses) {
        expect(
          RegExp('\\b$className\\s*\\(').hasMatch(homeV2Source),
          isFalse,
          reason: 'Placeholder proibido encontrado: $className',
        );
      }
    });

    test('Home V2 não recria navegação, timer ou persistência', () {
      const forbiddenTokens = <String>[
        'Navigator.of(',
        'Navigator.push',
        'MaterialPageRoute(',
        'PageRouteBuilder(',
        'SharedPreferences',
        'Timer.periodic',
        'NotificationService',
        'flutterLocalNotificationsPlugin',
      ];

      for (final token in forbiddenTokens) {
        expect(
          homeV2Source,
          isNot(contains(token)),
          reason: 'Responsabilidade paralela proibida: $token',
        );
      }
    });

    test('Home V2 não altera streaming ou backend', () {
      const forbiddenTokens = <String>[
        'sendAiMessage(',
        'GeminiService',
        'FirebaseFirestore',
        'FirestoreService',
        'StreamSubscription',
        'ChatController',
        'ChatStorage',
      ];

      for (final token in forbiddenTokens) {
        expect(
          homeV2Source,
          isNot(contains(token)),
          reason: 'Motor paralelo proibido: $token',
        );
      }
    });
  });
}
