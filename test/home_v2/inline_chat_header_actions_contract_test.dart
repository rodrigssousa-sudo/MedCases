import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const homePath = 'lib/screens/home_screen.dart';
  const adapterPath = 'lib/home_v2/components/chat/inline_chat.dart';
  const viewPath = 'lib/home_v2/components/chat/inline_chat_view.dart';
  const homeV2Path = 'lib/home_v2/home_screen_v2.dart';
  const aiScreenPath = 'lib/screens/ai_screen.dart';

  late String homeSource;
  late String adapterSource;
  late String viewSource;
  late String homeV2Source;
  late String aiScreenSource;

  setUpAll(() {
    homeSource = File(homePath).readAsStringSync();
    adapterSource = File(adapterPath).readAsStringSync();
    homeV2Source = File(homeV2Path).readAsStringSync();
    aiScreenSource = File(aiScreenPath).readAsStringSync();

    final viewFile = File(viewPath);
    viewSource = viewFile.existsSync() ? viewFile.readAsStringSync() : '';
  });

  group('Proprietário canônico preservado', () {
    test('estado, envio e cache local continuam na Home canônica', () {
      expect(
        homeSource,
        contains(
          'class _HomeInlineChatState '
          'extends State<_HomeInlineChat>',
        ),
      );
      expect(homeSource, contains('Future<void> _send('));
      expect(
        homeSource,
        contains('Future<void> _homePersistTurn()'),
      );
      expect(
        homeSource,
        contains('Future<void> _loadChatHistory()'),
      );
      expect(homeSource, contains('SharedPreferences'));
      expect(
        homeSource,
        isNot(
          contains(
            'FirestoreService.saveAiSession',
          ),
        ),
      );
      expect(homeSource, contains('sendAiMessage('));
    });

    test('controllers continuam pertencendo ao estado canônico', () {
      expect(
        homeSource,
        contains('final _ctrl = TextEditingController();'),
      );
      expect(homeSource, contains('final _focus = FocusNode();'));
      expect(
        homeSource,
        contains(
          'final _scrollCtrl = ScrollController();',
        ),
      );
      expect(homeSource, contains('_ctrl.dispose();'));
      expect(homeSource, contains('_focus.dispose();'));
      expect(homeSource, contains('_scrollCtrl.dispose();'));
    });
  });

  group('Adaptador oficial permanece fino', () {
    test('InlineChat continua delegando ao HomeInlineChat', () {
      expect(adapterSource, contains('return HomeInlineChat('));
      expect(homeV2Source, contains('InlineChat('));
    });

    test('adaptador não recebe motor ou persistência próprios', () {
      const forbidden = <String>[
        'ChangeNotifier',
        'ChatController',
        'ChatStorage',
        'ChatStream',
        'SharedPreferences',
        'Timer.periodic',
        'FirebaseFirestore',
        'FirestoreService',
        'GeminiService',
        'sendAiMessage(',
        'Navigator.push',
        'setState(',
      ];

      for (final token in forbidden) {
        expect(
          adapterSource,
          isNot(contains(token)),
          reason: 'Responsabilidade paralela: $token',
        );
      }
    });
  });

  group('View real do InlineChat V2', () {
    test('arquivo visual oficial existe', () {
      expect(
        File(viewPath).existsSync(),
        isTrue,
        reason: 'inline_chat_view.dart ainda não foi criado.',
      );
    });

    test('view pública oficial está declarada', () {
      expect(
        viewSource,
        contains(
          'class HomeInlineChatV2View extends StatelessWidget',
        ),
      );
    });

    test('view recebe estado projetado, sem possuir o motor', () {
      const required = <String>[
        'final List<Map<String, dynamic>> messages;',
        'final String streaming;',
        'final bool thinking;',
        'final bool expanded;',
        'final bool hasExpandableContent;',
        'final TextEditingController controller;',
        'final FocusNode focusNode;',
        'final ScrollController scrollController;',
        'final VoidCallback onSend;',
        'final VoidCallback onHistory;',
        'final VoidCallback onNewChat;',
        'final VoidCallback onToggleExpanded;',
      ];

      for (final token in required) {
        expect(
          viewSource,
          contains(token),
          reason: 'Projeção visual ausente: $token',
        );
      }
    });

    test('view não possui infraestrutura paralela', () {
      const forbidden = <String>[
        'SharedPreferences',
        'FirestoreService',
        'FirebaseFirestore',
        'GeminiService',
        'sendAiMessage(',
        'Timer.periodic',
        'ChatController',
        'ChatStorage',
        'ChatStream',
        'Navigator.push',
        'AiScreen.pendingHistory',
        'AiScreen.pendingQuery',
      ];

      for (final token in forbidden) {
        expect(
          viewSource,
          isNot(contains(token)),
          reason: 'Infraestrutura proibida na view: $token',
        );
      }
    });
  });

  group('Injeção da view V2 no estado canônico', () {
    test('Home canônica importa a view oficial', () {
      expect(
        homeSource,
        contains(
          "import '../home_v2/components/chat/"
          "inline_chat_view.dart';",
        ),
      );
    });

    test('_buildChatContent retorna a view V2', () {
      expect(
        homeSource,
        contains('return HomeInlineChatV2View('),
      );
    });

    test('estado real é projetado para a view', () {
      const required = <String>[
        'messages: _messages',
        'streaming: _streaming',
        'thinking: _thinking',
        'controller: _ctrl',
        'focusNode: _focus',
        'scrollController: _scrollCtrl',
        'onSend: _onSendPressed',
      ];

      for (final token in required) {
        expect(
          homeSource,
          contains(token),
          reason: 'Ligação canônica ausente: $token',
        );
      }
    });
  });

  group('Header minimalista', () {
    test('histórico usa callback canônico', () {
      expect(
        homeSource,
        contains(
          'AiScreen.openHistoryCallback.value?.call();',
        ),
      );
      expect(
        aiScreenSource,
        contains(
          'static final openHistoryCallback = '
          'ValueNotifier<VoidCallback?>(null)',
        ),
      );
    });

    test('novo chat limpa a sessão real da Home', () {
      const required = <String>[
        '_messages.clear();',
        "_streaming = '';",
        '_thinking = false;',
        '_sessionId = null;',
        '_ctrl.clear();',
        '_focus.unfocus();',
        'AiScreen.clearChatCallback.value?.call();',
      ];

      for (final token in required) {
        expect(homeSource, contains(token));
      }
    });

    test('view apresenta histórico e novo chat', () {
      expect(viewSource, contains('Icons.history_rounded'));
      expect(viewSource, contains('Icons.add_rounded'));
      expect(viewSource, contains('onHistory'));
      expect(viewSource, contains('onNewChat'));
    });
  });

  group('Expansão local e contextual', () {
    test('estado canônico possui expansão local', () {
      expect(
        homeSource,
        contains('bool _isInlineExpanded = false;'),
      );
      expect(
        homeSource,
        contains('void _toggleInlineExpansion()'),
      );
      expect(
        homeSource,
        contains(
          '_isInlineExpanded = !_isInlineExpanded;',
        ),
      );
    });

    test('existência do controle depende de conteúdo real', () {
      expect(
        homeSource,
        contains(
          'final hasExpandableContent = '
          'hasHistory || hasStream || hasThinking;',
        ),
      );
      expect(
        homeSource,
        contains(
          'hasExpandableContent: hasExpandableContent',
        ),
      );
    });

    test('view só habilita expansão quando há conteúdo', () {
      expect(
        viewSource,
        matches(
          RegExp(
            r'onDoubleTap:\s*hasExpandableContent\s*'
            r'\?\s*onToggleExpanded\s*'
            r':\s*null',
            dotAll: true,
          ),
        ),
        reason: 'O duplo toque só deve expandir quando houver conteúdo real.',
      );

      expect(
        viewSource,
        contains('final bool hasExpandableContent;'),
      );

      expect(
        viewSource,
        contains('onToggleExpanded'),
      );
    });

    test('expandir não navega para a tela completa de IA', () {
      expect(
        homeSource,
        isNot(
          contains(
            'onExpand: () => _goToAiTab(null, true)',
          ),
        ),
      );
      expect(
        homeSource,
        isNot(
          contains(
            'onExpand: isLast '
            '? () => _goToAiTab(null, true) '
            ': null',
          ),
        ),
      );
      expect(viewSource, isNot(contains('onNavigateToAi')));
      expect(viewSource, isNot(contains('_goToAiTab')));
    });
  });

  group('Identidade visual V2', () {
    test('view não reutiliza azul e ciano antigos', () {
      const forbidden = <String>[
        '0xFF00E5FF',
        '0xFF008CA4',
        '0xFF1B6FD8',
        '0xFF1F78FF',
        '0xFF38BDF8',
        '0xFF60A5FA',
        '0xFF6B8ABE',
        '0xFF0F2340',
        '0xFFEFF6FF',
      ];

      for (final token in forbidden) {
        expect(
          viewSource,
          isNot(contains(token)),
          reason: 'Azul legado encontrado: $token',
        );
      }
    });

    test('view consome exclusivamente a paleta compartilhada', () {
      expect(
        viewSource,
        contains("../../theme/home_v2_palette.dart"),
        reason: 'A view deve importar a paleta oficial compartilhada.',
      );

      expect(
        viewSource,
        contains('final palette = HomeV2Palette.resolve(dark);'),
        reason: 'Dark e Light devem ser resolvidos pela HomeV2Palette.',
      );

      expect(
        viewSource,
        isNot(contains('class _InlineChatV2Palette')),
        reason: 'A antiga paleta privada não pode reaparecer.',
      );

      for (final sharedToken in const [
        'palette.surface',
        'palette.surfaceActive',
        'palette.surfaceSoft',
        'palette.surfaceStrong',
        'palette.border',
        'palette.textPrimary',
        'palette.textSecondary',
        'palette.accent',
      ]) {
        expect(
          viewSource,
          contains(sharedToken),
          reason: 'Token compartilhado ausente: $sharedToken',
        );
      }

      for (final obsoletePrivateToken in const [
        'static const accent',
        'static const background',
        'static const surface',
        'static const border',
        'static const textPrimary',
        'static const textSecondary',
      ]) {
        expect(
          viewSource,
          isNot(contains(obsoletePrivateToken)),
          reason: 'Token privado obsoleto encontrado: '
              '$obsoletePrivateToken',
        );
      }
    });

    test('árvore oficial não importa motores provisórios', () {
      const forbiddenImports = <String>[
        'chat_controller.dart',
        'chat_storage.dart',
        'chat_stream.dart',
        'chat_navigation.dart',
      ];

      for (final token in forbiddenImports) {
        expect(homeSource, isNot(contains(token)));
        expect(adapterSource, isNot(contains(token)));
        expect(homeV2Source, isNot(contains(token)));
        expect(viewSource, isNot(contains(token)));
      }
    });
  });
}
