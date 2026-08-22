import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/common_widgets.dart' show MedBreakpoints;
import '../models/chat_message.dart';
import '../widgets/clinical/structured_clinical_output_view.dart';
import 'ai/widgets/guardia_clinical_response_view.dart';
import '../services/ai_pipeline/structured_output_text_equivalence.dart';
import '../services/ai_pipeline/plantao/contracts/plantao_continuation_type.dart';
import '../services/ai_pipeline/plantao/contracts/plantao_section.dart';
import 'ai/widgets/prompt_composer.dart';
import 'ai/widgets/message_render_policy.dart';
import 'ai/widgets/clinical_reference_resolver.dart';
import 'ai/widgets/action_buttons_row.dart';
import 'ai/widgets/study_continuation_button.dart';
import 'ai/widgets/user_bubble.dart';
import 'ai/widgets/user_message_display_policy.dart';
import 'ai/widgets/mobile_ai_action_bar.dart';
import 'ai/widgets/collapsible_content_blocks.dart';
import 'ai/widgets/ambassador_panel.dart';
import 'ai/widgets/ai_bubble.dart';
import 'ai/widgets/ai_shimmer_dots.dart';
import 'ai/widgets/response_mode_toggle.dart';
import 'ai/widgets/chat_history_sheet.dart';
import 'ai/widgets/ai_status_sheet.dart';
import 'ai/widgets/disconnected_input_lock.dart';
import 'ai/widgets/google_auth_barrier_card.dart';
import 'ai/widgets/wa_header.dart';
import 'ai/widgets/empty_chat.dart';
import 'ai/widgets/ai_error_banner.dart';
import '../widgets/error_state_widget.dart' show InlineConnectionBanner;
import '../services/clinical_tts_service.dart';
import 'dart:convert';
import '../providers/app_provider.dart';

import '../services/stt_helper.dart';
import '../services/firestore_service.dart';
import '../services/ai/ai_finalization_transaction.dart'
    show AiSessionSummary, AiSessionSource;
import '../services/activity_service.dart';
import '../home_v2/theme/home_v2_palette.dart';
import '../services/external_tool_link_engine.dart'; // Build 185: Deep Link Router
import '../services/plantao_pipeline.dart'; // Build 193: PlantaoResponse + pipeline
import '../services/ai_smart_router.dart';
import '../services/study_continuation_resolver.dart'; // BUILD 247: AiSmartRouter.shouldFallback()
import '../services/app_resume_coordinator.dart'; // ORDEM 53 M2/M3: backgroundSaveSignal + contextTimeoutSignal
import '../services/auth_service.dart'; // BUILD 338: contingency UID when currentUser==null

// ─────────────────────────────────────────────────────────────────────────────
/// Alias privado temporário para preservar os call sites do monólito durante a extração.
typedef _ChatMsg = ChatMessage;

// ─────────────────────────────────────────────────────────────────────────────
// Modelo de sessão de chat salva no histórico
// ─────────────────────────────────────────────────────────────────────────────
class _ChatSession {
  final String id; // timestamp ISO como ID único
  final DateTime savedAt; // quando foi salva
  final String summary; // primeira mensagem do usuário (resumo)
  final List<_ChatMsg> messages; // até 20 mensagens da sessão

  const _ChatSession({
    required this.id,
    required this.savedAt,
    required this.summary,
    required this.messages,
  });

  /// Serializa para JSON/Firestore.
  /// NOTA: o campo `updatedAt` NÃO é incluído aqui — é injetado como
  /// FieldValue.serverTimestamp() pelo FirestoreService.saveAiSession,
  /// garantindo timestamp do servidor (cross-device) sem risco de clock skew.
  Map<String, dynamic> toJson() => {
    'id': id,
    // savedAt como ISO8601 — fallback para leitura offline (SharedPreferences)
    'savedAt': savedAt.toIso8601String(),
    'summary': summary,
    'messages': messages
        .map(
          (m) => {
            'id': m.id,
            'role': m.role,
            'text': m.text,
            if (m.userDisplayText?.trim().isNotEmpty == true)
              'userDisplayText': m.userDisplayText!.trim(),
          },
        )
        .toList(),
  };

  /// Desserializa de JSON (SharedPreferences) ou de documento Firestore
  /// (já passado por sdkDocToSafeMap → todos os Timestamps vieram como ISO8601).
  ///
  /// ORDEM 27 — PARSER RESILIENTE:
  /// Aceita retroativamente 3 formatos de payload sem quebrar a timeline:
  ///   1. Legado (texto cru Markdown/bula gerado antes de ORDEM 22).
  ///   2. Plantão estruturado T01-T20 (emoji-anchor 🟥 + seções clínicas).
  ///   3. T-FARMACO-CARD (fármaco isolado — 🟥 + 💊🧠💉⛔⚠️🚨📌).
  /// Cada mensagem é parseada em try/catch individual — uma mensagem corrompida
  /// não interrompe o carregamento das demais. App nunca estoura Exception.
  factory _ChatSession.fromJson(Map<String, dynamic> j) {
    // ID: obrigatório. Se vier vazio usa timestamp local como fallback.
    final id = j['id']?.toString() ?? DateTime.now().toIso8601String();

    // savedAt: aceita ISO8601 string. Fallback para updatedAt (campo do Firestore)
    // e depois para now() para nunca explodir com parse exception.
    DateTime savedAt;
    final rawDate = j['savedAt'] ?? j['updatedAt'];
    try {
      savedAt = rawDate != null
          ? DateTime.parse(rawDate.toString())
          : DateTime.now();
    } catch (_) {
      savedAt = DateTime.now();
    }

    // ORDEM 27 — PARSER POR MENSAGEM COM ISOLAMENTO DE EXCEÇÃO:
    // Cada elemento da lista é parseado individualmente — se um entry estiver
    // corrompido (campo ausente, tipo errado, null inesperado), apenas esse
    // elemento é descartado; os demais são carregados normalmente.
    final rawMessages = j['messages'] as List? ?? [];
    final List<_ChatMsg> parsedMessages = [];
    for (final m in rawMessages) {
      try {
        final map = m is Map
            ? Map<String, dynamic>.from(m)
            : <String, dynamic>{};
        final msgId =
            map['id']?.toString() ??
            '${map['role'] ?? 'unknown'}_${DateTime.now().microsecondsSinceEpoch}';
        final role = map['role']?.toString() ?? 'user';
        final text = map['text']?.toString() ?? '';
        final displayCandidate =
            (map['userDisplayText'] as String?)?.trim() ?? '';
        parsedMessages.add(
          _ChatMsg.withId(
            id: msgId,
            role: role,
            text: text,
            userDisplayText: displayCandidate.isNotEmpty
                ? displayCandidate
                : null,
          ),
        );
      } catch (e) {
        // Mensagem individual corrompida — descarta silenciosamente sem crashar.
        if (kDebugMode) {
          debugPrint(
            '[MIGRATION] Skipped corrupt message entry in session $id: $e',
          );
        }
      }
    }

    return _ChatSession(
      id: id,
      savedAt: savedAt,
      summary: j['summary']?.toString() ?? '',
      messages: parsedMessages,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _detectSessionFormat — ORDEM 27: Classificador retroativo de payloads
//
// Analisa as mensagens de uma sessão e retorna o formato dominante:
//   'pharma_card'        — Resposta T-FARMACO-CARD: 🟥 + tokens 💊🧠💉⛔⚠️🚨📌
//                          (fármaco isolado sem contexto de emergência)
//   'plantao_structured' — Resposta T01-T20 clínica: 🟥 + seções multi-emoji
//                          (template de emergência/conduta clínica)
//   'legacy'             — Markdown cru / bula enciclopédica / builds anteriores
//
// Decisão: lê APENAS a última mensagem AI (role='model') da sessão — que é
// a mais recente e define o "tipo" da sessão para fins de telemetria.
// Nunca lança exceção — qualquer erro retorna 'legacy' como fallback seguro.
// ─────────────────────────────────────────────────────────────────────────────
String _detectSessionFormat(List<_ChatMsg> messages) {
  try {
    // Pega a última mensagem AI da sessão
    final aiMessages = messages.where((m) => m.role == 'model').toList();
    if (aiMessages.isEmpty) return 'legacy';
    final lastAi = aiMessages.last.text;
    if (lastAi.isEmpty) return 'legacy';

    final firstLine = lastAi.trim().split('\n').first.trim();
    final hasRedAnchor = firstLine.startsWith('🟥');

    if (!hasRedAnchor) return 'legacy';

    // Conta tokens semânticos do T-FARMACO-CARD no corpo
    final pharmaTokens = ['💊', '🧠', '💉', '⛔', '⚠️', '🚨', '📌'];
    // Um T-FARMACO-CARD tem todos os 7 tokens
    int tokenCount = 0;
    for (final tok in pharmaTokens) {
      if (lastAi.contains(tok)) tokenCount++;
    }

    // T-FARMACO-CARD: tem 🟥 E pelo menos 5 dos 7 tokens farmacológicos
    // E o corpo é curto (≤ 30 linhas — fármaco isolado, sem conduta multi-bloco)
    final lineCount = lastAi.trim().split('\n').length;
    if (tokenCount >= 5 && lineCount <= 30) return 'pharma_card';

    // Plantão estruturado T01-T20: tem 🟥 + múltiplos tokens clínicos (conduta)
    if (tokenCount >= 2) return 'plantao_structured';

    // 🟥 presente mas poucos tokens semânticos — legado com 🟥 manual
    return 'legacy';
  } catch (_) {
    return 'legacy';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class AiScreen extends StatefulWidget {
  const AiScreen({super.key});
  @override
  State<AiScreen> createState() => _AiScreenState();

  // ── Notifiers estáticos para comunicação com o shell mobile ──────────────
  // O shell AppBar lê estes valores para injetar botões contextuais quando
  // a aba da IA está ativa, sem prop drilling nem InheritedWidget extra.
  /// true quando há mensagens no chat (além da saudação automática)
  static final hasMessagesNotifier = ValueNotifier<bool>(false);

  /// quantidade de sessões no histórico de chat
  static final historyCountNotifier = ValueNotifier<int>(0);

  /// callback para limpar o chat (null quando o widget não está montado)
  static final clearChatCallback = ValueNotifier<VoidCallback?>(null);

  /// callback para abrir o histórico (null quando o widget não está montado)
  static final openHistoryCallback = ValueNotifier<VoidCallback?>(null);

  /// true quando IA está conectada (Gemini ou chave OpenAI configurada)
  static final aiConnectedNotifier = ValueNotifier<bool>(false);

  /// callback para abrir as configurações de IA (null quando não montado)
  static final openSettingsCallback = ValueNotifier<VoidCallback?>(null);

  /// BUILD 310 — Ambassador Panel callback (null para não-parceiros)
  static final ambassadorPanelCallback = ValueNotifier<VoidCallback?>(null);

  /// true quando o teclado virtual está aberto no chat — usado pelo FAB central
  /// em main.dart para sumir suavemente durante a digitação (Fix #5 PR #65).
  static final chatKeyboardOpen = ValueNotifier<bool>(false);

  /// Build 158 — Hide-on-scroll: true quando o usuário está scrollando para
  /// baixo (lendo histórico). O shell main.dart usa este notifier para ocultar
  /// a bottom nav bar e liberar espaço máximo para leitura dos casos clínicos.
  static final scrollingDown = ValueNotifier<bool>(false);

  // ── Home V2: Injeção de query a partir da Home ─────────────────────────
  /// Query pendente para ser disparada automaticamente ao montar a tela de IA.
  /// A HomeScreen seta este valor antes de navegar para a aba 2.
  /// O _AiScreenState consome e limpa no initState/didUpdateWidget.
  static final pendingQuery = ValueNotifier<String>('');

  // ── Home V2: Injeção de histórico do mini-chat inline ──────────────────
  /// Histórico pendente do mini-chat da Home para restaurar no AiScreen.
  ///
  /// Quando o usuário clica "Ver respuesta completa" / "Ver mais" no mini-chat
  /// da Home, este notifier recebe os pares de mensagens já trocados
  /// (lista de {role: 'user'/'ai', text: '...'}).
  ///
  /// O _AiScreenState consome no listener e:
  ///   1. Limpa o chat atual (saudação)
  ///   2. Injeta os pares como _ChatMsg existentes
  ///   3. Limpa o notifier para não re-disparar
  ///
  /// Formato: [{'role': 'user', 'text': '...'}, {'role': 'ai', 'text': '...'}]
  static final pendingHistory = ValueNotifier<List<Map<String, String>>>([]);
}

class _AiScreenState extends State<AiScreen> {
  final _queryCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();

  // Referência obtida enquanto o BuildContext está ativo.
  // Usada no dispose() sem consultar ancestrais de um elemento desativado.
  AppProvider? _appProviderRef;
  final List<_ChatMsg> _messages = [];
  bool _thinking = false;
  bool _hasFocus = false;
  bool _aiError = false;
  // Task 11 — network error banner: true quando a última chamada da IA falhou
  // por problema de conexão (timeout, socket, etc.) vs. erro de chave API.
  bool _networkError = false;
  // Motor de Partida (Build 149): false=Plantão (≤12 linhas) | true=Estudos (22-24)
  // SUPER ORDEM MASTER 14 M5: Estudos é o modo PADRÃO — evita custo Plantão automático
  bool _longResponse = true;

  // AI-VIS-B.2.6-R1 — confirmação visual do modo.
  //
  // _longResponse continua sendo o único estado funcional real:
  // true = Estudo | false = Guardia/Plantão.
  //
  // Estes dois flags controlam somente onde o seletor é exibido.
  bool _modeConfirmed = false;
  bool _modeReselectionPending = false;
  bool _greetingDone = false; // garante saudação só uma vez por sessão
  int _lastAiIndex = -1; // índice da última resposta da IA (para animar só ela)
  // Auto-scroll: só desce automaticamente se usuário estiver perto do fundo
  bool _userScrolledUp = false; // true quando usuário scrollou para cima
  // BUILD 308 [FISIOP_DEDUP]: Último studyNextPrompt enviado via botão azul.
  // Usado para detectar loop de Fisiopatologia: se o prompt enviado contém
  // o mesmo quadrante da IA anterior, o botão é substituído por avanço linear.
  String _lastSentStudyPrompt = '';
  // Anti-jump: token gerado a cada nova resposta da IA — bloqueia callbacks
  // de reveals de bolhas antigas que ficaram pendentes.
  int _scrollGeneration = 0;
  // Throttle de scroll suave (Build 96): substitui flag bool por timestamp.
  // Garante que animateTo só dispara a cada ≥80ms — alinha com ~60fps sem
  // sobrecarregar a engine de layout durante o streaming de chunks.
  bool _scrollPending = false;
  int _lastScrollMs = 0; // epoch ms da última chamada de scroll animado
  // Fix 4 — Chunk Cadence: limita renders do notifier a ≥25ms entre atualizações.
  // Cadencia a digitação visual e absorve picos de rede sem tremer a UI.
  int _lastChunkRenderMs = 0;
  // Sentinela no fim da lista — Scrollable.ensureVisible garante layout calculado
  final _bottomKey = GlobalKey();

  // ORDEM 54 M2: chave de epoch do chat — incrementada no context timeout para
  // invalidar completamente o cache gráfico do Flutter Web e forçar rebuild zero.
  // ValueKey(_chatEpoch) no ListView.builder garante que o Flutter descarte a
  // árvore antiga e redesenhe do absoluto zero, eliminando o Stale UI.
  int _chatEpoch = 0;
  // Histórico de sessões de chat (até 10)
  final List<_ChatSession> _chatHistory = [];

  // BUILD 430 PASSO 1: guarda o UID para o qual o histórico já foi carregado.
  // Evita reload duplicado quando geminiConnected muda múltiplas vezes.
  String? _historyLoadedForUid;
  static const _kHistKey = 'medcases_ia_chat_history_v1';

  // MICRO-BUILD 463-A.2.1.2: UI-side session load generation counter.
  // Incremented each time _loadChatHistory() starts a new Firestore fetch.
  // Any completion arriving after a newer generation has started is discarded
  // without touching _chatHistory — prevents stale async writes post-rebuild.
  int _sessionsLoadGeneration = 0;

  // BUILD 452-1: TTL de volatilidade de tela — 30 minutos.
  // Se o médico retornar à tela após 30+ min de inatividade,
  // a conversa anterior é descartada e a UI abre totalmente limpa.
  // A chave SharedPreferences 'ai_screen_last_active_ms' persiste o
  // timestamp epoch (ms) da última atividade registrada.
  static const _kScreenTtlMs = 30 * 60 * 1000; // 30 min em ms
  static const _kLastActiveKey = 'ai_screen_last_active_ms';

  /// ID da sessão restaurada do histórico (se a sessão atual veio do histórico
  /// sem nenhuma mensagem nova do usuário, não deve ser re-salva ao limpar).
  String? _restoredSessionId;

  // BUILD 274: _activeSessionId — ID único gerado na 1ª mensagem da sessão
  // e reutilizado em TODOS os saves subsequentes do mesmo chat.
  // Sem isso, cada _saveCurrentSessionToHistory() gerava novo DateTime.now()
  // como ID, criando múltiplos docs Firestore para o mesmo chat (duplication).
  String? _activeSessionId;

  /// Indica se o usuário enviou ao menos 1 mensagem nova após restaurar uma sessão.
  bool _hasNewMessageAfterRestore = false;

  /// Geração da restauração histórica atualmente válida.
  int _historyRestoreGeneration = 0;

  /// Última sessão explicitamente selecionada no histórico.
  String? _selectedHistorySessionId;

  /// Última resposta cuja pintura visual foi concluída.
  /// Formato: <scrollGeneration>:<messageId>.
  String? _studyContinuationVisualReadyIdentity;

  /// Permite adotar o modo de uma sessão histórica sem reiniciá-la.
  bool _restoredModeSelectionPending = false;

  // ── BUILD 232: ExtTool deduplication cache ───────────────────────────────
  // Key: messageId + ':' + textHash
  // Garante que ExternalToolLinkEngine.build() execute no máximo 1 vez por
  // (messageId, textHash) por sessão. PlantatoPipelineCache removido (ORDEM 56).
  final Map<String, ExternalToolLink?> _extToolCache = {};
  // BUILD 244B / ORDEM 56: log-dedup sets — SAFE_CARD_GUARD e EVIDENCE_GUARD
  // são disparados no ListView item builder, que reconstrói muitas vezes.
  // _loggedPlantaoIds removido junto com _PlantaoRenderer (ORDEM 56).
  // BUILD 246: _loggedEvidenceIds — dedup EVIDENCE_GUARD por messageId+textHash.
  final Set<String> _loggedSafeCardIds = {};
  final Set<String> _loggedEvidenceIds = {};
  // BUILD 308 [EXT_TOOL_DEDUP]: log-dedup set para EXT_TOOL_DEDUP.
  // Evita spam de 18+ debugPrints/s no console durante rebuilds de streaming.
  // Registra apenas a 1ª ocorrência de cada extKey por sessão.
  final Set<String> _loggedExtToolKeys = {};
  // ──────────────────────────────────────────────────────────────────────────

  // ── TTS (Text-to-Speech) ─────────────────────────────────────────────────
  final ClinicalTtsService _clinicalTts = ClinicalTtsService();
  bool _ttsReady = false;
  int _ttsPlayingIndex =
      -1; // índice da mensagem sendo reproduzida (-1 = nenhuma)

  // ── STT (Speech-to-Text via Web Speech API) ──────────────────────────────
  bool _sttListening = false; // microfone ativo
  double _sttSoundLevel =
      0.0; // nível de som normalizado 0.0–1.0 (onda de áudio)

  /// Sincroniza os ValueNotifiers estáticos com o estado atual.
  /// Chamado automaticamente a cada setState via [_setState].
  void _syncShellNotifiers() {
    // hasMessages: true se existem mensagens além da saudação automática de IA
    final hasReal = _messages.any((m) => m.role == 'user');
    if (AiScreen.hasMessagesNotifier.value != hasReal) {
      AiScreen.hasMessagesNotifier.value = hasReal;
    }
    final cnt = _chatHistory.length;
    if (AiScreen.historyCountNotifier.value != cnt) {
      AiScreen.historyCountNotifier.value = cnt;
    }
    // aiConnected: gemini ou chave OpenAI configurada.
    // Callback pós-frame: nunca consulta ancestrais por um context desativado.
    final p = _appProviderRef;
    if (p == null) return;
    final connected = p.geminiConnected || p.hasAnyAi;
    if (AiScreen.aiConnectedNotifier.value != connected) {
      AiScreen.aiConnectedNotifier.value = connected;
    }
  }

  /// setState que também sincroniza o shell AppBar.
  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    // Agenda sync pós-frame para garantir que _messages/_chatHistory
    // já foram atualizados antes de notificar o shell.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncShellNotifiers();
    });
  }

  // ── Saudação por horário — bilíngue ES/PT hermeticamente isolado ──
  // ES  00–06: "Buena madrugada"  |  06–12: "Buenos días"
  //     12–18: "Buenas tardes"    |  18–24: "Buenas noches"
  // PT  00–06: "Boa madrugada"    |  06–12: "Bom dia"
  //     12–18: "Boa tarde"        |  18–24: "Boa noite"
  String _buildGreeting(String userName, String lang) {
    final bool es = lang != 'pt';
    final int hour = DateTime.now().hour;
    final String period;
    if (es) {
      if (hour < 6)
        period = 'Buena madrugada';
      else if (hour < 12)
        period = 'Buenos días';
      else if (hour < 18)
        period = 'Buenas tardes';
      else
        period = 'Buenas noches';
    } else {
      if (hour < 6)
        period = 'Boa madrugada';
      else if (hour < 12)
        period = 'Bom dia';
      else if (hour < 18)
        period = 'Boa tarde';
      else
        period = 'Boa noite';
    }
    final firstName = userName.trim().split(' ').first;
    final nameStr = firstName.isNotEmpty ? ', $firstName' : '';
    return es
        ? '$period$nameStr.\n\nSoy MedCases IA. ¿Cómo puedo ayudarte hoy?'
        : '$period$nameStr.\n\nSou o MedCases IA. Como posso te ajudar hoje?';
  }

  // ── Named listener refs — necessários para removeListener() no dispose() ──
  // Build 118: listeners anônimos (lambdas) não podem ser removidos via
  // removeListener() porque cada closure é uma instância diferente.
  // Convertidos para métodos nomeados para remoção determinística.
  void _onFocusChange() {
    if (mounted) {
      setState(() => _hasFocus = _focusNode.hasFocus);
      // Fix #5: propaga foco ao FAB central (main.dart oculta o botão)
      AiScreen.chatKeyboardOpen.value = _focusNode.hasFocus;
      // AUDIT 3.1 — Keyboard auto-scroll:
      // Quando o teclado abre (campo ganha foco), rola para o fundo do chat
      // para que a última mensagem e o campo de input permaneçam visíveis.
      // Usa addPostFrameCallback para aguardar o layout ser recalculado pelo
      // sistema APÓS o teclado ser mostrado (viewInsets atualizado).
      // Não dispara durante streaming (_isStreaming) para não interromper leitura.
      // Guideline Apple 4.0: elementos interativos nunca devem ser cortados.
      if (_focusNode.hasFocus && !_isStreaming && !_thinking) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_userScrolledUp) {
            _scrollDown(force: true);
          }
        });
      }
    }
  }

  void _onQueryChange() {
    if (mounted && _queryCtrl.text.isNotEmpty && _hasFocus) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    // ORDEM 56 M3 — BUILD 285: cache-buster no init log.
    // Incrementar este número em cada release força service-workers e CDNs
    // a invalidar o cache da versão anterior.
    if (kDebugMode) {
      debugPrint(
        '[AI_SCREEN][BUILD_285] ORDEM_56 init — '
        'unifiedMarkdownRender=true plasticPipelineExterminated=true',
      );
    }
    _focusNode.addListener(_onFocusChange);
    _queryCtrl.addListener(_onQueryChange);
    // Listener de scroll: detecta se usuário scrollou para cima
    _scrollCtrl.addListener(_onScroll);
    // Home V2: escuta pendingQuery em tempo real — dispara sempre que a Home
    // injeta uma nova query, mesmo que o AiScreen já esteja montado no IndexedStack.
    AiScreen.pendingQuery.addListener(_onPendingQuery);
    // Home V2: escuta pendingHistory — restaura o mini-chat da Home no AiScreen.
    // Disparado quando o usuário clica "Ver respuesta completa" / "Ver mais".
    AiScreen.pendingHistory.addListener(_onPendingHistory);
    // ORDEM 53 M2: escuta sinal de background → auto-salva sessão silenciosamente.
    AppResumeCoordinator.instance.backgroundSaveSignal.addListener(
      _onBackgroundSave,
    );
    // ORDEM 53 M3: escuta sinal de context timeout → hard reset de UI + sessão.
    AppResumeCoordinator.instance.contextTimeoutSignal.addListener(
      _onContextTimeout,
    );
    // Injeta saudação após o primeiro frame (AppProvider já disponível)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _injectGreeting();
      // Consome query que possa ter sido setada antes do listener estar ativo
      _consumePendingQuery();
      // Consome histórico pendente (caso injetado antes do listener ativo)
      _onPendingHistory();
    });
    // BUILD 452-1: TTL de volatilidade — verifica se expirou 30 min.
    // Deve rodar ANTES de _loadChatHistory() para que, em caso de expiração,
    // o histórico local já esteja limpo quando as sessões forem carregadas.
    _checkScreenTtl();
    // Carrega histórico de chats do SharedPrefs
    _loadChatHistory();

    // BUILD 430 PASSO 1: re-trigger pós-OAuth.
    // Na Web, após redirect OAuth o AppProvider dispara notifyListeners() com
    // geminiConnected=true. Se no primeiro _loadChatHistory() o UID ainda era
    // nulo (pré-auth), re-carregamos agora que o UID real está disponível.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _appProviderRef?.addListener(_onAuthStateChanged);
    });

    // Inicializa TTS
    _initTts();
    // Registra callbacks no shell AppBar via notifiers estáticos.
    // O shell lê estes valores para exibir botões contextuais na aba da IA.
    AiScreen.clearChatCallback.value = _clearChat;
    AiScreen.openHistoryCallback.value = () {
      if (!mounted) return;
      final p = _appProviderRef;
      if (p == null) return;
      _openHistory(p);
    };
    AiScreen.openSettingsCallback.value = () {
      if (!mounted) return;
      _openAiSettings();
    };
    // BUILD 310: Ambassador Panel callback (only for partners)
    AiScreen.ambassadorPanelCallback.value = () {
      if (!mounted) return;
      _openAmbassadorPanel();
    };

    // Verifica sessão Gemini ao montar — captura token de redirect OAuth
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final p = _appProviderRef;
        if (p == null) return;
        if (!p.geminiConnected) {
          p.checkGeminiSession();
        }
      });
    }

    // SUPER ORDEM MASTER 12 M3: PROACTIVE AUTH GATE
    // Se o usuário entrar na tela sem IA conectada, abre o modal de
    // conexão automaticamente — aviso acolhedor antes de qualquer interação.
    // Micro-delay de 2 frames garante que a UI já está renderizada.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Future.delayed(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        final p = _appProviderRef;
        if (p == null) return;
        final bool connected = p.geminiConnected || p.hasAnyAi;
        if (!connected) {
          _openAiSettings(); // abre modal de conexão automaticamente
          debugPrint(
            '[PROACTIVE_GATE] Tela de IA sem conexão — modal disparado.',
          );
        }
      });
    });
  }

  // ── BUILD 452-1: TTL de volatilidade de tela (30 minutos) ─────────────
  /// Ao montar a tela, lê o timestamp da última atividade.
  /// Se a diferença for > 30 min, limpa a thread em memória e o _messages[]
  /// apresentando a tela totalmente em branco com saudação fresca.
  /// Registra também o timestamp atual como "última abertura".
  Future<void> _checkScreenTtl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final lastMs = prefs.getInt(_kLastActiveKey) ?? 0;
      // Persiste o novo timestamp imediatamente (próxima abertura vai comparar)
      await prefs.setInt(_kLastActiveKey, nowMs);

      if (lastMs == 0) return; // primeira abertura — sem histórico para limpar

      final elapsed = nowMs - lastMs;
      if (elapsed <= _kScreenTtlMs) return; // dentro do TTL — mantém histórico

      // Expirado: reset silencioso — descarta thread visual (sem salvar)
      if (kDebugMode) {
        debugPrint(
          '[BUILD452_TTL] elapsed=${elapsed ~/ 60000}min > 30min '
          '— limpando thread visual e reiniciando sessão limpa.',
        );
      }
      // Limpa mensagens em memória; _greetingDone=false força nova saudação
      if (mounted) {
        setState(() {
          _messages.clear();
          _greetingDone = false;
          _chatEpoch++; // invalida cache gráfico do ListView
          _activeSessionId = null;
          _restoredSessionId = null;
          _hasNewMessageAfterRestore = false;
          _aiError = false;
          _networkError = false;
          _userScrolledUp = false;
        });
        // Limpa histórico de transporte da IA (context do Gemini)
        final p = context.read<AppProvider>();
        p.clearAiHistory();

        // AI-VIS-B.5-R5: o reset por TTL deve terminar no mesmo
        // estado vazio canônico das demais entradas da IA.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _injectGreeting();
        });
      }
    } catch (e) {
      // Falha silenciosa — TTL nunca quebra o fluxo principal
      if (kDebugMode) debugPrint('[BUILD452_TTL] erro: $e');
    }
  }

  /// Atualiza o timestamp de última atividade no SharedPreferences.
  /// Chamado sempre que o usuário envia uma mensagem.
  Future<void> _updateLastActive() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _kLastActiveKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {}
  }

  // ── Leitura clínica TTS ─────────────────────────────────────────────────
  Future<void> _initTts() async {
    try {
      await _clinicalTts.initialize();
      if (!mounted) {
        await _clinicalTts.dispose();
        return;
      }
      setState(() => _ttsReady = true);
    } catch (e, st) {
      debugPrint('[AiScreen][_initTts] Clinical TTS exception: $e\n$st');
      if (mounted) {
        setState(() {
          _ttsReady = false;
          _ttsPlayingIndex = -1;
        });
      }
    }
  }

  /// Reproduz ou interrompe a leitura clínica de uma mensagem da IA.
  ///
  /// A AiScreen preserva apenas o estado visual do botão. Voz, locale,
  /// velocidade, normalização, segmentação e fila pertencem ao serviço.
  Future<void> _toggleTts(int msgIndex, String text, String lang) async {
    if (!_ttsReady) return;

    try {
      if (_ttsPlayingIndex == msgIndex) {
        await _clinicalTts.stop();
        if (!mounted) return;
        setState(() => _ttsPlayingIndex = -1);
        return;
      }

      await _clinicalTts.stop();
      if (!mounted) return;

      setState(() => _ttsPlayingIndex = msgIndex);

      await _clinicalTts.speak(text, languageCode: lang);

      if (!mounted || _ttsPlayingIndex != msgIndex) return;
      setState(() => _ttsPlayingIndex = -1);
    } catch (e, st) {
      debugPrint('[AiScreen][_toggleTts] Clinical TTS exception: $e\n$st');
      if (mounted && _ttsPlayingIndex == msgIndex) {
        setState(() => _ttsPlayingIndex = -1);
      }
    }
  }

  // ── Voice-to-Text — Web + iOS + Android ─────────────────────────────────
  // Web    : Web Speech API via dart:html (stt_helper_web.dart)
  // Mobile : speech_to_text plugin nativo (stt_helper_mobile.dart)
  // Sem restricao de plataforma — funciona em todos os targets.

  void _toggleStt() {
    if (_sttListening) {
      _sttStop();
    } else {
      _sttStart();
    }
  }

  void _sttStart() {
    setState(() {
      _sttListening = true;
      _sttSoundLevel = 0.0;
    });
    final lang = context.read<AppProvider>().lang;
    // STT-GUARD: proteção extra no call-site — stt_helper_mobile já captura
    // erros internos do plugin, mas esta camada adicional protege contra
    // exceções síncronas antes de chegar ao plugin (ex: permissão negada via
    // PlatformException antes do init, ou ambiente não suportado).
    try {
      SttHelper.start(
        locale: lang == 'es' ? 'es-ES' : 'pt-BR',

        // ── onResult: só chamado com texto FINAL (isFinal=true em ambas plataformas)
        // Limpa o buffer parcial e compromete o texto final no controller.
        // NÃO usa '$current $text' acumulativo — substitui apenas o buffer parcial
        // para evitar o eco "eu eu eu" de chunks parciais duplicados.
        onResult: (text) {
          if (!mounted) return;
          setState(() {
            _sttListening = false;
            _sttSoundLevel = 0.0;
            // Preserva qualquer texto que o usuário tenha digitado manualmente
            // antes de iniciar o ditado, anexando o resultado ao final.
            final existing = _queryCtrl.text.trim();
            final combined = existing.isEmpty ? text : '$existing $text';
            _queryCtrl.text = combined;
            _queryCtrl.selection = TextSelection.fromPosition(
              TextPosition(offset: _queryCtrl.text.length),
            );
          });
          _focusNode.requestFocus();
        },

        // ── onError: garante limpeza total do estado antes do snackbar
        onError: (code) {
          if (!mounted) return;
          // Fecha o canal de áudio antes de limpar o estado — evita que o
          // microfone permaneça aberto em caso de erro no_speech/audio_session
          SttHelper.stop();
          setState(() {
            _sttListening = false;
            _sttSoundLevel = 0.0;
          });
          _showSttErrorSnack(code);
        },

        // ── onEnd: limpa estado ao encerrar normalmente
        onEnd: () {
          if (!mounted) return;
          setState(() {
            _sttListening = false;
            _sttSoundLevel = 0.0;
          });
        },

        // ── onSoundLevelChange: atualiza nível para a onda de áudio animada
        onSoundLevelChange: (level) {
          if (!mounted || !_sttListening) return;
          // Usa setState apenas se a mudança for perceptível (evita rebuilds desnecessários)
          if ((level - _sttSoundLevel).abs() > 0.02) {
            setState(() => _sttSoundLevel = level);
          }
        },
      );
    } catch (e, st) {
      // STT-GUARD: erro síncrono inesperado — reseta estado sem crashar o app.
      debugPrint('[AiScreen][_sttStart] SttHelper.start exception: $e\n$st');
      if (mounted)
        setState(() {
          _sttListening = false;
          _sttSoundLevel = 0.0;
        });
    }
  }

  Future<void> _sttStop() async {
    await SttHelper.stop();
    if (mounted)
      setState(() {
        _sttListening = false;
        _sttSoundLevel = 0.0;
      });
  }

  /// Exibe feedback de erro do STT ao usuario (nao bloqueia — e opcional).
  void _showSttErrorSnack(String code) {
    final lang = context.read<AppProvider>().lang;
    final bool isEs = lang == 'es';
    String msg;
    switch (code) {
      case 'permission_denied':
        msg = isEs
            ? 'Permiso de microfono denegado. Habilitalo en Ajustes.'
            : 'Permissao de microfone negada. Habilite em Configuracoes.';
      case 'not_available':
        msg = isEs
            ? 'Dictado no disponible. Verifica que el Reconocimiento de Voz esté activo en Ajustes → Accesibilidad → Texto introducido.'
            : 'Ditado indisponível. Verifique se o Reconhecimento de Voz está ativo em Ajustes → Acessibilidade → Texto Digitado.';
      case 'no_speech':
        return; // silencioso — usuario simplesmente nao falou
      case 'network':
        msg = isEs
            ? 'Verifica tu conexion a internet para el dictado.'
            : 'Verifique sua conexao com a internet para o ditado.';
      case 'audio_session':
        msg = isEs
            ? 'Error de sesión de audio. Cierra y vuelve a abrir la app.'
            : 'Erro na sessão de áudio. Feche e reabra o app.';
      default:
        return; // outros erros tecnicos — silencioso
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      ),
    );
  }

  /// Home V2 — Consome a query pendente setada pelo _HomeIaCard antes de
  /// navegar para a aba de IA. O pequeno delay garante que o greeting já
  /// foi injetado e os providers estão prontos antes do envio.
  /// Chamado pelo listener do pendingQuery — funciona mesmo com AiScreen já montado.
  void _onPendingQuery() {
    _consumePendingQuery();
  }

  /// Chamado pelo listener do pendingHistory.
  /// Restaura os pares de mensagens do mini-chat da Home como conversa real.
  void _onPendingHistory() {
    final pairs = AiScreen.pendingHistory.value;
    if (pairs.isEmpty || !mounted) return;
    // Limpa imediatamente para não re-disparar em rebuilds
    AiScreen.pendingHistory.value = [];

    // Post-frame: garante que o widget está completamente montado
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // BUILD 244B/246: limpa sets de log-dedup ao injetar histórico
      _loggedSafeCardIds.clear();
      _loggedEvidenceIds.clear();
      _loggedExtToolKeys.clear(); // BUILD 308
      final p = context.read<AppProvider>();

      setState(() {
        // Home → IA é uma continuação pedagógica e entra diretamente em Estudo.
        // O modo já nasce confirmado: sem seletor, sem reset e sem limpar o chat.
        _longResponse = true;
        _modeConfirmed = true;
        _modeReselectionPending = false;
        _restoredModeSelectionPending = false;

        // Build 236: marca saudação como feita para evitar dupla injeção
        // se _injectGreeting() for chamado após a restauração do histórico.
        _greetingDone = true;

        // Preserva apenas a saudação automática (primeiro msg de 'ai')
        // e acrescenta os pares do mini-chat logo depois.
        final greeting = _messages.isNotEmpty && _messages.first.role == 'ai'
            ? [_messages.first]
            : <_ChatMsg>[];
        _messages.clear();
        _messages.addAll(greeting);

        // Injeta cada par {role, text} como _ChatMsg com ID estável
        for (final m in pairs) {
          final role = m['role'] ?? 'user';
          final text = m['text'] ?? '';
          if (text.isNotEmpty) {
            _messages.add(_ChatMsg(role: role, text: text));
          }
        }
      });
      // A UI e o provider precisam possuir o MESMO histórico. O mini-chat usa
      // role='ai'; o provider canônico exige role='assistant'.
      p.rebuildAiHistoryFromMessages(
        pairs
            .where(
              (message) => message['role'] == 'user' || message['role'] == 'ai',
            )
            .map(
              (message) => <String, String>{
                'role': message['role'] == 'ai' ? 'assistant' : 'user',
                'content': message['text'] ?? '',
              },
            )
            .where((message) => message['content']!.trim().isNotEmpty)
            .toList(growable: false),
      );

      // Scroll para o fim após injetar as mensagens
      Future.delayed(const Duration(milliseconds: 120), () {
        if (!mounted || !_scrollCtrl.hasClients) return;
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
      _syncShellNotifiers();
    });
  }

  // ── ORDEM 53 M2: Auto-Save silencioso no background ─────────────────────
  /// Chamado quando AppProvider detecta que o app foi para background.
  /// Salva a sessão atual no SharedPrefs + Firestore sem interromper o médico.
  /// Fire-and-forget: o médico não vê nada — apenas a sessão é persistida.
  void _onBackgroundSave() {
    if (!mounted) return;
    final hasRealMsgs = _messages.any((m) => m.role == 'user');
    if (!hasRealMsgs) return; // nada a salvar — chat vazio ou só saudação
    if (kDebugMode) {
      debugPrint(
        '[ORDEM53_M2] Auto-save silencioso — app foi para background '
        'msgs=${_messages.length}',
      );
    }
    // Usa post-frame para garantir que o context ainda é válido
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final p = context.read<AppProvider>();
      _saveCurrentSessionToHistory(p);
    });
  }

  // ── ORDEM 53 M3: Context Timeout — Hard Reset após 30 min de background ──
  /// Chamado quando AppProvider detecta retorno do background após ≥ 30 min.
  ///
  /// BUILD 432 — MODO ESTUDO PROTEGIDO:
  ///   Se _longResponse == true (Modo Estudo), o hard reset destrutivo é
  ///   SUPRIMIDO. Em vez disso, a UI é preservada intacta e o contexto da
  ///   API é re-alimentado silenciosamente via rebuildAiHistoryFromMessages()
  ///   na próxima interação do usuário. Isso impede perda de raciocínio clínico
  ///   durante sessões pedagógicas longas (casos complexos, residência).
  ///
  /// MODO PLANTÃO: mantém hard reset completo — pacientes diferentes requerem
  ///   contexto limpo para evitar cross-contamination clínica.
  void _onContextTimeout() {
    if (!mounted) return;
    final p = context.read<AppProvider>();

    // ── BUILD 432: Modo Estudo → bloqueio do hard reset destrutivo ────────────────
    if (_longResponse) {
      if (kDebugMode) {
        debugPrint(
          '[ORDEM53_M3][BUILD432] Context Timeout detectado mas '
          'Modo Estudo ativo → hard reset SUPRIMIDO. '
          'UI preservada; contexto será re-alimentado via '
          'rebuildAiHistoryFromMessages() na próxima interação.',
        );
      }
      // Reconstrói _aiHistory no Provider a partir das mensagens visíveis na UI
      // para resgatar a âncora cognitiva antes do próximo envio.
      final historyPayload = _messages
          .where((m) => m.role == 'user' || m.role == 'assistant')
          .map((m) => {'role': m.role, 'content': m.text})
          .toList();
      if (historyPayload.isNotEmpty) {
        p.rebuildAiHistoryFromMessages(historyPayload);
        debugPrint(
          '[ORDEM53_M3][BUILD432] rebuildAiHistoryFromMessages '
          'executado silenciosamente — ${historyPayload.length} entradas '
          'restauradas no contexto da API (Modo Estudo)',
        );
      }
      return; // ← SUPRIME o hard reset abaixo
    }

    // ── Modo Plantão: hard reset completo (comportamento original) ───────────
    if (kDebugMode) {
      debugPrint(
        '[ORDEM53_M3] Context Timeout ativado — ≥30 min de background '
        '→ hard reset de sessão clínica (Modo Plantão)',
      );
    }

    // 1. Salva sessão anterior antes de destruir
    final hasRealMsgs = _messages.any((m) => m.role == 'user');
    if (hasRealMsgs && _hasNewMessageAfterRestore) {
      _saveCurrentSessionToHistory(p); // fire-and-forget
    }

    // 2. Hard reset de UI + IDs de sessão + estado interno
    // ORDEM 54 M2: _chatEpoch++ invalida o ValueKey do ListView.builder,
    // forçando o Flutter a descartar a árvore gráfica antiga e redesenhar
    // do zero — elimina o Stale UI no Flutter Web após context timeout.
    setState(() {
      _chatEpoch++; // força rebuild completo da árvore de chat
      _messages.clear();
      _greetingDone = false;
      _restoredSessionId = null;
      _activeSessionId = null;
      _hasNewMessageAfterRestore = false;
      _thinking = false;
      _aiError = false;
      _networkError = false;
      _userScrolledUp = false;
      _loggedSafeCardIds.clear();
      _loggedEvidenceIds.clear();
      _loggedExtToolKeys.clear(); // BUILD 308
    });

    // 3. Hard reset do contexto Gemini no AppProvider
    p.resetAiSessionFull();

    // 4. Reinicia saudação para o novo chat limpo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _injectGreeting();
    });

    debugPrint(
      '[ORDEM53_M3] Hard reset concluído — nova sessão clínica pronta',
    );
  }

  void _consumePendingQuery() {
    final q = AiScreen.pendingQuery.value;
    if (q.isEmpty || !mounted) return;

    // Captura o provider enquanto o BuildContext ainda está ativo.
    // O callback atrasado não pode consultar ancestrais após a tela ser desativada.
    final p = context.read<AppProvider>();

    AiScreen.pendingQuery.value =
        ''; // limpa imediatamente para não re-disparar
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      _send(q, p);
    });
  }

  bool _isOpeningHomeGreeting(int index, _ChatMsg msg) {
    if (index != 0 || msg.role != 'ai') {
      return false;
    }

    final normalized = msg.text.trim();

    return normalized.contains(
          'Sou o MedCases IA. Como posso te ajudar hoje?',
        ) ||
        normalized.contains('Soy MedCases IA. ¿Cómo puedo ayudarte hoy?');
  }

  void _openResponseModeSelector() {
    if (!mounted || !_modeConfirmed) {
      return;
    }

    setState(() {
      _modeConfirmed = false;
      _modeReselectionPending = true;
    });
  }

  void _commitResponseMode(bool newValue) {
    if (!mounted) {
      return;
    }

    final p = context.read<AppProvider>();

    final adoptingRestoredMode =
        _restoredModeSelectionPending && _restoredSessionId != null;

    final shouldRestart =
        !adoptingRestoredMode &&
        (_modeReselectionPending ||
            _messages.any((message) => message.role == 'user'));

    setState(() {
      _longResponse = newValue;
      _modeConfirmed = true;
      _modeReselectionPending = false;
      _restoredModeSelectionPending = false;

      _loggedSafeCardIds.clear();
      _loggedEvidenceIds.clear();
      _loggedExtToolKeys.clear();
    });

    if (shouldRestart) {
      // Troca manual de modo em conversa ativa.
      _startNewChat(preserveConfirmedMode: true);
    } else if (!adoptingRestoredMode) {
      // Primeira escolha em um chat realmente vazio.
      p.clearAiHistory();
    } else {
      // Sessão histórica sem modo reconhecido:
      // adota a escolha sem apagar mensagens ou gerar outro ID.
      debugPrint(
        '[AI_MODE_SELECTOR][RESTORED_ADOPTION] '
        'sessionIdHash=${_restoredSessionId.hashCode} '
        'mode=${newValue ? "ESTUDO" : "PLANTÃO"}',
      );
    }

    if (kDebugMode) {
      debugPrint(
        '[AI_MODE_SELECTOR] '
        'mode=${newValue ? "ESTUDO" : "PLANTÃO"} '
        'restart=$shouldRestart '
        'restoredAdoption=$adoptingRestoredMode '
        'confirmed=true',
      );
    }
  }

  void _injectGreeting() {
    if (_greetingDone || !mounted) return;
    _greetingDone = true;
    final p = context.read<AppProvider>();
    setState(() {
      _messages.add(
        _ChatMsg(role: 'ai', text: _buildGreeting(p.userName, p.lang)),
      );
    });
  }

  double _lastScrollOffset =
      0.0; // Build 158: rastreia offset anterior para detectar direção

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    // Build 145 — threshold reduzido 120 → 80px; BUILD 308 — elevado 80 → 100px:
    // 100px detecta intenção de leitura com margem maior que o cursor ▌ (≈20px).
    // Elimina o jitter residual em Estudo: SSE longo empurra maxScrollExtent
    // frame a frame; com 80px a zona dead era muito estreita → auto-scroll
    // ainda disparava enquanto o usuário tentava subir. Com 100px a zona de
    // congelamento é confortável para tablets/iPad sem falsos positivos no fundo.
    final nearBottom = pos.pixels >= pos.maxScrollExtent - 100;
    // AI-RECONSTRUCTION-R18.6Y-R2-R2:
    // nearBottom permanece exclusivamente como leitura geométrica para
    // a barra inferior. Crescimento do Markdown ou mudança de maxScrollExtent
    // não pode criar, remover ou simular intenção manual do usuário.

    // Build 158 — Hide-on-scroll: detecta direção do scroll para hide/show bottom nav.
    // Scroll para BAIXO (ler histórico, aumentando pixels) → oculta barra
    // Scroll para CIMA (voltar ao presente) → mostra barra
    // Atualiza apenas quando há mudança real (evita churn de notifier).
    final currentOffset = pos.pixels;
    final isScrollingDown =
        currentOffset > _lastScrollOffset + 4; // threshold anti-bounce
    final isScrollingUp = currentOffset < _lastScrollOffset - 4;
    if (isScrollingDown && !AiScreen.scrollingDown.value) {
      AiScreen.scrollingDown.value = true;
    } else if ((isScrollingUp || nearBottom) && AiScreen.scrollingDown.value) {
      AiScreen.scrollingDown.value = false;
    }
    _lastScrollOffset = currentOffset;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appProviderRef = context.read<AppProvider>();
  }

  @override
  void dispose() {
    // BUILD 300: Garante a persistência do snapshot da sessão ativa ao fechar ou desempilhar a tela de IA.
    // Dispara _saveCurrentSessionToHistory via Provider antes de qualquer limpeza de controllers/streams,
    // pois após o cancelamento dos listeners o contexto pode estar inacessível.
    try {
      final provider = _appProviderRef;
      if (provider != null) {
        _saveCurrentSessionToHistory(provider);
        debugPrint(
          '[BUILD300][AI_SCREEN] Safe dispose session save dispatched successfully.',
        );
      } else {
        debugPrint(
          '[BUILD300][AI_SCREEN] Safe dispose session save skipped: provider cache empty.',
        );
      }
    } catch (e) {
      debugPrint('[BUILD300][AI_SCREEN] Safe dispose session save skipped: $e');
    }

    // ── Build 118: dispose() hardening — Zero Memory Leak ─────────────────
    //
    // ORDEM CRÍTICA:
    //   1. Cancelar streams/STT ativos (fecha canal de áudio do microfone)
    //   2. Remover todos os listeners por referência nomeada
    //   3. Parar e liberar TTS com guard de inicialização
    //   4. Dispose de controllers e FocusNodes
    //   5. Limpar ValueNotifiers estáticos do shell
    //   6. super.dispose() sempre por último

    // ── 1. STT: fecha canal de áudio se microfone ainda ativo ──────────────
    // Evita que o microfone fique aberto em celulares antigos após trocar de tela.
    if (_sttListening) {
      SttHelper.stop(); // fire-and-forget — não awaita em dispose()
    }

    // ── 2. Remover listeners por referência nomeada ─────────────────────────
    // Build 118: antes usavam lambdas anônimas que NÃO podiam ser removidas.
    // Agora usam _onFocusChange / _onQueryChange (métodos nomeados).
    _focusNode.removeListener(_onFocusChange);
    _queryCtrl.removeListener(_onQueryChange);
    _scrollCtrl.removeListener(_onScroll);
    AiScreen.pendingQuery.removeListener(_onPendingQuery);
    AiScreen.pendingHistory.removeListener(_onPendingHistory);
    AppResumeCoordinator.instance.backgroundSaveSignal.removeListener(
      _onBackgroundSave,
    ); // ORDEM 53 M2
    AppResumeCoordinator.instance.contextTimeoutSignal.removeListener(
      _onContextTimeout,
    ); // ORDEM 53 M3

    // ── 3. TTS: invalida toda a fila clínica anterior ───────────────────────
    // dispose() não pode aguardar Futures. O serviço invalida a geração
    // imediatamente e solicita stop ao adaptador nativo em fire-and-forget.
    _clinicalTts.dispose();

    // ── 4. Dispose de controllers e FocusNode ─────────────────────────────
    // Build 135: cancela timer de debounce pendente — evita callback após dispose
    _submitDebounceTimer?.cancel();
    _submitDebounceTimer = null;
    _queryCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    // Build 188: descarta ValueNotifier de streaming se ainda ativo
    _streamingTextNotifier?.dispose();
    _streamingTextNotifier = null;

    // BUILD 430 PASSO 1: remove listener de auth sem consultar context no dispose.
    try {
      _appProviderRef?.removeListener(_onAuthStateChanged);
    } catch (_) {}

    // ── Fix 1: Interceptação de Saída (Lifecycle) ─────────────────────────
    // Quando o widget é destruído (troca de aba, navegação para Home, etc.),
    // força o descarregamento da sessão ativa da RAM para o disco antes de morrer.
    // Usa AppProvider via estáticos de Build — sem dependência de context morto.
    // Fire-and-forget: não awaita (dispose() é síncrono no Flutter).
    try {
      // Somente persiste se há mensagens reais (não apenas saudação)
      final hasRealMsgs = _messages.any((m) => m.role == 'user');
      if (hasRealMsgs && _hasNewMessageAfterRestore) {
        // Snapshot das mensagens para persistir sem depender do widget vivo
        final msgsSnapshot = List<_ChatMsg>.from(_messages);
        final now = DateTime.now();
        final userMsgs = msgsSnapshot.where((m) => m.role == 'user').toList();
        if (userMsgs.isNotEmpty) {
          final summary = userMsgs.first.text;
          final msgsToSave = msgsSnapshot.length > 20
              ? msgsSnapshot.sublist(msgsSnapshot.length - 20)
              : msgsSnapshot;
          // BUILD 274: usa o mesmo ID já fixado em _activeSessionId/_restoredSessionId
          final String disposeSessionId;
          if (_restoredSessionId != null) {
            disposeSessionId = _restoredSessionId!;
          } else if (_activeSessionId != null) {
            disposeSessionId = _activeSessionId!;
          } else {
            disposeSessionId = now.toIso8601String();
          }
          final existingIdx = _chatHistory.indexWhere(
            (s) => s.id == disposeSessionId,
          );
          final session = _ChatSession(
            id: disposeSessionId,
            savedAt: now,
            summary: summary.length > 100 ? summary.substring(0, 100) : summary,
            messages: msgsToSave,
          );
          // Persiste localmente (SharedPreferences) — Firestore requer context
          SharedPreferences.getInstance()
              .then((prefs) {
                try {
                  // Insere no snapshot do histórico atual
                  final histSnapshot = List<_ChatSession>.from(_chatHistory);
                  if (existingIdx >= 0) histSnapshot.removeAt(existingIdx);
                  histSnapshot.insert(0, session);
                  if (histSnapshot.length > 20) {
                    histSnapshot.removeRange(20, histSnapshot.length);
                  }
                  final key = '\$_kHistKey';
                  final json = jsonEncode(
                    histSnapshot.map((s) => s.toJson()).toList(),
                  );
                  prefs.setString(key, json);
                } catch (_) {}
              })
              .catchError((_) {});
        }
      }
    } catch (_) {}

    // ── 5. Limpa ValueNotifiers estáticos do shell AppBar ──────────────────
    // Callbacks do widget desmontado — evita referências mortas no shell.
    AiScreen.clearChatCallback.value = null;
    AiScreen.openHistoryCallback.value = null;
    AiScreen.openSettingsCallback.value = null;
    AiScreen.ambassadorPanelCallback.value = null; // BUILD 310
    AiScreen.hasMessagesNotifier.value = false;
    AiScreen.historyCountNotifier.value = 0;
    AiScreen.aiConnectedNotifier.value = false;
    AiScreen.chatKeyboardOpen.value = false;
    AiScreen.scrollingDown.value = false; // Build 158: reset hide-on-scroll

    super.dispose();
  }

  /// Desce apenas se usuário não scrollou para cima intencionalmente.
  /// [force] = true força scroll independente (usado ao enviar mensagem do usuário).
  // ── Histórico de chats ───────────────────────────────────────────────────────────────────────

  /// BUILD 338-HISTORY-ECONOMY: Resolve UID com fallback de contingência.
  /// Quando FirebaseAuth.currentUser==null (Web com persistência REST),
  /// usa AuthService.webUser.value?.uid para evitar que _histKey() caia em 'anon'.
  // BUILD 430 PASSO 1: callback disparado quando AppProvider notifica mudanças de estado.
  // Detecta a transição geminiConnected false→true (post-OAuth) e re-carrega o histórico
  // se ainda não foi carregado com o UID autenticado.
  void _onAuthStateChanged() {
    if (!mounted) return;

    // O ChangeNotifier pode disparar enquanto o Element já está desativado,
    // embora mounted ainda seja true. Usa a referência previamente cacheada.
    final p = _appProviderRef;
    if (p == null) return;

    final uid = _resolveUid(p);
    if (uid == null || uid.isEmpty) return;
    // Só recarrega se o histórico foi carregado com UID nulo/anon ou com UID diferente
    if (_historyLoadedForUid == uid) return;
    debugPrint(
      '[BUILD430] post-OAuth uid=$uid — recarregando histórico de chat.',
    );
    _loadChatHistory();
  }

  String? _resolveUid(AppProvider p) {
    final sdkUid = p.currentUser?.uid;
    if (sdkUid != null && sdkUid.isNotEmpty) return sdkUid;
    // Contingência: token REST presente mas SDK ainda não propagou o usuário
    final contingencyUid = AuthService.webUser.value?.uid;
    if (contingencyUid != null && contingencyUid.isNotEmpty)
      return contingencyUid;
    return null;
  }

  String _histKey(AppProvider p) {
    final uid = _resolveUid(p) ?? 'anon';
    return '${uid}_$_kHistKey';
  }

  Future<void> _loadChatHistory() async {
    try {
      // Pode ser chamado pelo listener de auth durante uma transição de rota.
      // Não consulta ancestrais usando um BuildContext potencialmente desativado.
      final p = _appProviderRef;
      if (p == null) return;

      // BUILD 338: usa UID resiliente (SDK ou contingência REST)
      final uid = _resolveUid(p);

      // BUILD 430 PASSO 1: marca o UID para evitar reload duplicado pós-OAuth.
      if (uid != null && uid.isNotEmpty) _historyLoadedForUid = uid;

      // ── MICRO-BUILD 463-A.2.1.3: Two-layer algebraic routing ────────────────
      // Outer layer: UiLoadOutcome — separates latch lifecycle from content.
      //   UiLoadDiscarded → silent return; NO state-tree mutation.
      //   UiLoadApplied   → inner FirestoreLoadResult routing.
      // Inner layer: FirestoreLoadResult — exhaustive content routing.
      //   success(data)  → hydrate _chatHistory
      //   empty()        → authoritative clear (ONLY valid clear path)
      //   authDenied()   → freeze + auth SnackBar  (real Firebase permission-denied)
      //   offline()      → freeze + offline SnackBar
      //   failure(e)     → freeze + log
      // NO dataOrElse([]) semantic collapse anywhere in this block.
      if (uid != null && uid.isNotEmpty) {
        // UI-side generation counter: lets the screen detect its own stale
        // completions independently of the provider-side latch.
        _sessionsLoadGeneration++;
        final int myGeneration = _sessionsLoadGeneration;

        final outcome = await p.loadAiSessionsTypedForUi(
          uid,
          caller: '_loadChatHistory',
        );

        // UI-side stale-epoch guard: if this widget was rebuilt and a new
        // _loadChatHistory() started while we awaited, discard silently.
        if (!mounted || _sessionsLoadGeneration != myGeneration) {
          debugPrint(
            '[AI_SESSIONS_LOAD] uid=$uid STALE_EPOCH discarded '
            'myGen=$myGeneration currentGen=$_sessionsLoadGeneration',
          );
          return;
        }

        // ── Outer: UiLoadOutcome routing ────────────────────────────────────
        if (outcome is UiLoadDiscarded<List<Map<String, dynamic>>>) {
          // Provider-side stale generation: a newer UID took ownership while
          // we were awaiting.  No state-tree mutation of any kind.
          debugPrint(
            '[AI_SESSIONS_LOAD] uid=$uid result=discarded '
            'reason=${outcome.reason}',
          );
          return;
        }

        // outcome is UiLoadApplied — extract the inner FirestoreLoadResult.
        final typedResult =
            (outcome as UiLoadApplied<List<Map<String, dynamic>>>).result;

        // ── Inner: FirestoreLoadResult algebraic routing ─────────────────────
        if (typedResult.isSuccess) {
          // SUCCESS: Hydrate the UI session list from authoritative server data.
          // BUILD 274: de-dup by ID — Firestore may return stale docs written
          // before the session-ID fix. Keep first occurrence (desc by updatedAt).
          final raw = typedResult.dataOrElse(<Map<String, dynamic>>[]);
          final seen = <String>{};
          final sessions = raw
              .map((e) => _ChatSession.fromJson(e))
              .where((s) => seen.add(s.id))
              .toList();

          debugPrint(
            '[AI_SESSIONS_LOAD] uid=$uid result=success '
            'action=hydrate count=${sessions.length} writeBack=false',
          );

          // ORDEM 27 — TELEMETRIA DE MIGRAÇÃO (Firestore path):
          if (kDebugMode) {
            for (final s in sessions) {
              final fmt = _detectSessionFormat(s.messages);
              switch (fmt) {
                case 'pharma_card':
                  debugPrint(
                    '[MIGRATION] Loaded pharma_card chat session format. id=${s.id}',
                  );
                case 'plantao_structured':
                  debugPrint(
                    '[MIGRATION] Loaded plantao_structured chat session format. id=${s.id}',
                  );
                default:
                  debugPrint(
                    '[MIGRATION] Loaded legacy chat session format. id=${s.id}',
                  );
              }
            }
          }

          if (mounted)
            setState(() {
              _chatHistory.clear();
              _chatHistory.addAll(sessions);
            });
          _persistHistoryLocal(p);
          return;
        } else if (typedResult.isEmpty) {
          // EMPTY: Server-authoritative — user has no sessions. This is the
          // ONLY path that may physically clear _chatHistory.
          debugPrint(
            '[AI_SESSIONS_LOAD] uid=$uid result=empty '
            'action=authoritative_clear writeBack=false',
          );
          if (mounted) setState(() => _chatHistory.clear());
          return;
        } else if (typedResult.isAuthDenied) {
          // AUTH_DENIED: Firebase returned permission-denied (real auth breach).
          // Freeze local state — _chatHistory is NOT touched.
          debugPrint(
            '[AI_SESSIONS_LOAD] uid=$uid result=authDenied '
            'action=freeze writeBack=false',
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Sessão expirada — reconectando…'),
                duration: Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        } else if (typedResult.isOffline) {
          // OFFLINE: No connectivity. Retain currently loaded sessions.
          // _chatHistory is NOT touched — existing data remains in-memory.
          debugPrint(
            '[AI_SESSIONS_LOAD] uid=$uid result=offline '
            'action=freeze writeBack=false',
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Sem conexão — usando dados locais'),
                duration: Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        } else {
          // FAILURE: Unexpected error. Freeze local state; log for diagnostics.
          debugPrint(
            '[AI_SESSIONS_LOAD] uid=$uid result=failure '
            'action=freeze writeBack=false '
            'error=${typedResult.runtimeType}',
          );
          return;
        }
      }

      // Fallback: SharedPreferences (offline)
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_histKey(p));
      if (json == null || json.isEmpty) return;
      final list = jsonDecode(json) as List;
      // BUILD 274: de-dup local cache too
      final seenLocal = <String>{};
      final sessions = list
          .map((e) => _ChatSession.fromJson(e as Map<String, dynamic>))
          .where((s) => seenLocal.add(s.id))
          .toList();

      // ORDEM 27 — TELEMETRIA DE MIGRAÇÃO (SharedPreferences offline path):
      // Classifica cada sessão carregada e emite log por tipo de payload.
      if (kDebugMode) {
        for (final s in sessions) {
          final fmt = _detectSessionFormat(s.messages);
          switch (fmt) {
            case 'pharma_card':
              debugPrint(
                '[MIGRATION] Loaded pharma_card chat session format. id=${s.id}',
              );
            case 'plantao_structured':
              debugPrint(
                '[MIGRATION] Loaded plantao_structured chat session format. id=${s.id}',
              );
            default:
              debugPrint(
                '[MIGRATION] Loaded legacy chat session format. id=${s.id}',
              );
          }
        }
      }

      if (mounted)
        setState(() {
          _chatHistory.clear();
          _chatHistory.addAll(sessions);
        });

      // Migra para Firestore se ainda não sincronizou
      if (uid != null && uid.isNotEmpty) {
        for (final s in _chatHistory) {
          FirestoreService.saveAiSession(uid, s.toJson()).catchError((_) {});
        }
      }
    } catch (_) {}
  }

  /// Cache local auxiliar (SharedPreferences) — fallback offline.
  Future<void> _persistHistoryLocal(AppProvider p) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(_chatHistory.map((s) => s.toJson()).toList());
      await prefs.setString(_histKey(p), json);
    } catch (_) {}
  }

  /// Salva a sessão atual no histórico antes de limpar.
  /// Só salva se houver ao menos 1 mensagem do usuário.
  /// Se a sessão foi restaurada do histórico e o usuário não enviou nenhuma
  /// mensagem nova, ela NÃO é re-salva (já estava salva, nada mudou).
  ///
  /// BUILD 274 — SESSION ID REUSE:
  /// O ID da sessão é fixado em _activeSessionId na primeira chamada e
  /// reutilizado em TODOS os saves seguintes do mesmo chat. Sem isso,
  /// user-send save e AI-response save geravam IDs diferentes (timestamps
  /// distintos), resultando em dois documentos Firestore para o mesmo chat.
  Future<void> _saveCurrentSessionToHistory(AppProvider p) async {
    // MICRO-BUILD 462E-A.5.3.7.3 — DISPOSE GUARD:
    // Resolve active session identity and uid defensively before any access.
    // This replaces scattered null-assertion flow control with a single clean
    // early-return that covers the dispose lifecycle path, where widget state
    // may be partially torn down and context may no longer be reliable.
    //
    // currentSession: the active session id — either the restored session or the
    //   in-flight session that has already been assigned an id.
    // currentUid:     the Firebase user id — resolved via _resolveUid() which
    //   checks both the SDK user and the REST contingency user.
    final String? currentSession = _restoredSessionId ?? _activeSessionId;
    final String? currentUid = _resolveUid(p);
    if (currentSession == null || currentUid == null || _messages.isEmpty) {
      debugPrint(
        '[AI_SCREEN][DISPOSE_SAVE] skipped reason=missing_context_or_empty '
        'session=$currentSession uid=$currentUid msgCount=${_messages.length}',
      );
      return;
    }

    // ── MICRO-BUILD 462E-A.5.3.7.3.2.5.2 [PILLAR 5]: Dual-write termination ─
    // If the active conversation is a canonical v2 session (schemaVersion == 2),
    // skip the legacy saveAiSession() write entirely. Canonical sessions are
    // persisted atomically via persistAiExchangeOnce() → batchWriteAiExchange()
    // and must NEVER be duplicated into ai_chat_history.
    // The provider's stable _currentConversationSessionId is the v2 session anchor.
    final String providerSessionId = p.currentConversationSessionId;
    if (providerSessionId.isNotEmpty) {
      // This screen's current conversation is owned by the canonical v2 pipeline.
      debugPrint(
        '[LEGACY_WRITE][SKIPPED] '
        'reason=canonical_session_owned '
        'requestId=${p.currentRequestId}',
      );
      return;
    }

    // Filtra só mensagens reais (exclui saudação inicial)
    final userMsgs = _messages.where((m) => m.role == 'user').toList();
    if (userMsgs.isEmpty) return;

    // Sessão restaurada sem novas mensagens → não re-salva
    if (_restoredSessionId != null && !_hasNewMessageAfterRestore) return;

    final now = DateTime.now();
    final summary = userMsgs.first.text;
    // Salva até 20 mensagens na sessão
    final msgsToSave = _messages.length > 20
        ? _messages.sublist(_messages.length - 20)
        : List<_ChatMsg>.from(_messages);

    // BUILD 274: resolução de ID com prioridade:
    //   1. Sessão restaurada do histórico → mantém ID original
    //   2. Sessão nova com _activeSessionId já fixado → reutiliza o mesmo ID
    //   3. Primeira save de sessão nova → gera ID único e fixa em _activeSessionId
    final String sessionId;
    if (_restoredSessionId != null) {
      sessionId = _restoredSessionId!;
    } else if (_activeSessionId != null) {
      // Reutiliza ID gerado na primeira save — evita duplicação multi-save
      sessionId = _activeSessionId!;
    } else {
      // BUILD 338: guard contra criação de sessão virgem quando histórico já existe.
      // Se _chatHistory tem sessões (carregadas do Firestore/cache) e o usuário
      // está enviando a primeira mensagem desta visita (sem _activeSessionId fixado),
      // NÃO geramos um ID de timestamp que resultaria em existingIdx=-1 e ocultaria
      // o histórico real. Em vez disso, fixamos o ID como nova sessão distinta mas
      // logamos o contexto para rastreamento.
      sessionId = now.toIso8601String();
      _activeSessionId = sessionId;
      debugPrint(
        '[BUILD274][SessionDedup] Nova sessão iniciada id=$sessionId historyLen=${_chatHistory.length}',
      );
    }

    // Se é uma sessão restaurada com novas mensagens, encontra a entrada existente
    final existingIdx = _chatHistory.indexWhere((s) => s.id == sessionId);

    final session = _ChatSession(
      id: sessionId,
      savedAt: now,
      summary: summary.length > 100 ? summary.substring(0, 100) : summary,
      messages: msgsToSave,
    );

    // BUILD 309 [DISPOSE]: Guard contra setState() após dispose().
    // _saveCurrentSessionToHistory() é chamada no dispose() do widget.
    // Nesse momento mounted=false e setState() lançaria
    // "setState() called after dispose()" — capturado silenciosamente pelo
    // try/catch do dispose() e logado como aviso. Com o guard, a mutação
    // local do _chatHistory ocorre diretamente (sem rebuild) quando desmontado.
    if (mounted) {
      setState(() {
        if (existingIdx >= 0) _chatHistory.removeAt(existingIdx);
        _chatHistory.insert(0, session);
        if (_chatHistory.length > 20) {
          _chatHistory.removeRange(20, _chatHistory.length);
        }
      });
    } else {
      // Dispose path: atualiza lista diretamente sem setState (widget já morto)
      if (existingIdx >= 0) _chatHistory.removeAt(existingIdx);
      _chatHistory.insert(0, session);
      if (_chatHistory.length > 20) {
        _chatHistory.removeRange(20, _chatHistory.length);
      }
    }

    debugPrint(
      '[BUILD274][SessionDedup] save sessionId=$sessionId msgs=${session.messages.length} existingIdx=$existingIdx',
    );

    // Persiste em dual-write: Firestore (primário) + SharedPreferences (offline)
    // saveAiSession usa .doc(id).set(data) — upsert seguro, sem duplicação Firestore
    // BUILD 338: usa UID resiliente (SDK ou contingência REST)
    final uid = _resolveUid(p);
    if (uid != null && uid.isNotEmpty) {
      FirestoreService.saveAiSession(uid, session.toJson()).catchError((_) {});
      // Remove sessões que saíram do limite (>10) do Firestore
      if (_chatHistory.length == 10) {
        // Não precisamos deletar — loadAiSessions usa limit(20)
      }
    }
    _persistHistoryLocal(p);
  }

  /// Abre o bottom sheet de histórico de chats.
  // MICRO-BUILD 462E-A.5.3.7.3.2.5.2 [PILLAR 3]:
  // No longer passes 'sessions' as a constructor parameter — the sheet binds
  // reactively to p.visibleAiSessionSummaries via Selector inside its builder.
  void _openHistory(AppProvider p) {
    // ── AI-RECONSTRUCTION-R18.6W: history_summary_hydration ─────────────
    // O modal abre imediatamente e permanece reativo ao mesmo Selector.
    // A leitura, o merge e a deduplicação pertencem ao AppProvider.
    final historyUid = _resolveUid(p);
    if (historyUid != null && historyUid.isNotEmpty) {
      unawaited(p.loadAndMergeAiSessionSummaries(historyUid));
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => Selector<AppProvider, List<AiSessionSummary>>(
        selector: (_, prov) => prov.visibleAiSessionSummaries,
        builder: (_, sessions, __) {
          // Emit reactive render trace (safe — no user content in metrics).
          debugPrint(
            '[HISTORY_MODAL][RENDER] '
            'visibleCount=${sessions.length} '
            'topSource=${sessions.isEmpty ? "none" : sessions.first.source.name} '
            'topSessionIdHash=${sessions.isEmpty ? "none" : sessions.first.sessionId.hashCode} '
            'topTitleLen=${sessions.isEmpty ? 0 : sessions.first.title.length}',
          );
          return ChatHistorySheet(
            dark: p.darkMode,
            lang: p.lang,
            onRestoreSummary: (summary) {
              Navigator.pop(modalCtx);
              _restoreFromSummary(summary, p);
            },
            onDelete: (summary) async {
              final uid = _resolveUid(p);
              var deleted = false;

              switch (summary.source) {
                case AiSessionSource.legacyInline:
                  if (uid != null && uid.isNotEmpty) {
                    deleted = await FirestoreService.deleteLegacyAiSession(
                      uid,
                      summary.sessionId,
                    );
                  }
                  break;

                case AiSessionSource.canonicalV2:
                  if (uid != null && uid.isNotEmpty) {
                    deleted =
                        await FirestoreService.softDeleteCanonicalAiSession(
                          uid,
                          summary.sessionId,
                        );
                  }
                  break;

                case AiSessionSource.localMemory:
                  deleted = true;
                  break;
              }

              if (!deleted) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        p.lang == 'es'
                            ? 'No fue posible eliminar la consulta.'
                            : 'Não foi possível excluir a consulta.',
                      ),
                    ),
                  );
                }

                return false;
              }

              if (mounted) {
                setState(
                  () => _chatHistory.removeWhere(
                    (session) => session.id == summary.sessionId,
                  ),
                );
              } else {
                _chatHistory.removeWhere(
                  (session) => session.id == summary.sessionId,
                );
              }

              await _persistHistoryLocal(p);

              p.removeVisibleAiSessionSummary(summary.sessionId);

              return true;
            },
            sessions: sessions,
          );
        },
      ),
    );
  }

  bool? _decodeStoredHistoryMode(String rawMode) {
    final normalized = rawMode.trim().toLowerCase();

    switch (normalized) {
      case 'study':
      case 'estudo':
      case 'estudio':
      case 'estudos':
        return true;

      case 'guardia':
      case 'plantao':
      case 'plantão':
      case 'on_call':
      case 'oncall':
      case 'on-call':
        return false;
    }

    return null;
  }

  void _adoptRestoredSessionIdentity(
    AiSessionSummary summary,
    AppProvider provider,
  ) {
    provider.adoptRestoredAiConversation(
      sessionId: summary.sessionId,
      title: summary.title,
    );

    debugPrint(
      '[SESSION_RESTORE][IDENTITY_ADOPTED] '
      'source=${summary.source.name} '
      'sessionIdHash=${summary.sessionId.hashCode} '
      'mode=${summary.mode}',
    );
  }

  // ── MICRO-BUILD 462E-A.5.3.7.3.2.5.2 [PILLAR 4]: Source-aware restore ─────
  // Restores a session selected from the history modal timeline.
  // Strategy is determined by AiSessionSummary.source:
  //   legacyInline  → messages are embedded; repopulate directly.
  //   canonicalV2   → fire async exchange loader, expand to chat bubbles.
  //   localMemory   → treat as canonicalV2 if sessionId matches; fallback to empty.
  void _restoreFromSummary(AiSessionSummary summary, AppProvider p) {
    final restoreGeneration = ++_historyRestoreGeneration;

    _selectedHistorySessionId = summary.sessionId;

    final restoredMode = _decodeStoredHistoryMode(summary.mode);

    debugPrint(
      '[SESSION_RESTORE][START] '
      'source=${summary.source.name} '
      'sessionIdHash=${summary.sessionId.hashCode} '
      'storedMode=${summary.mode} '
      'modeRecognized=${restoredMode != null} '
      'generation=$restoreGeneration',
    );

    p.cancelAiStream();
    _streamingTextNotifier?.dispose();
    _streamingTextNotifier = null;
    _loggedSafeCardIds.clear();
    _loggedEvidenceIds.clear();
    _loggedExtToolKeys.clear();

    switch (summary.source) {
      case AiSessionSource.legacyInline:
        final inlineMsgs = summary.legacyMessages ?? [];

        final chatMsgs = inlineMsgs.map((message) {
          final role = (message['role'] as String?) ?? 'user';

          final text =
              (message['text'] as String?) ??
              (message['content'] as String?) ??
              '';
          final userDisplayText = (message['userDisplayText'] as String?)
              ?.trim();

          return _ChatMsg(
            role: role,
            text: text,
            userDisplayText: userDisplayText?.isNotEmpty == true
                ? userDisplayText
                : null,
          );
        }).toList();

        setState(() {
          _messages.clear();
          _messages.addAll(chatMsgs);
          _lastAiIndex = -1;
          _greetingDone = true;
          _userScrolledUp = false;
          _restoredSessionId = summary.sessionId;
          _activeSessionId = null;
          _hasNewMessageAfterRestore = false;

          if (restoredMode != null) {
            _longResponse = restoredMode;
          }

          _modeConfirmed = restoredMode != null;
          _modeReselectionPending = false;
          _restoredModeSelectionPending = restoredMode == null;

          _thinking = false;
          _isStreaming = false;
          _sendGuard = false;
        });

        _adoptRestoredSessionIdentity(summary, p);

        p.rebuildAiHistoryFromMessages(
          chatMsgs
              .where(
                (message) => message.role == 'user' || message.role == 'ai',
              )
              .map(
                (message) => {
                  'role': message.role == 'ai' ? 'assistant' : 'user',
                  'content': message.text,
                },
              )
              .toList(),
        );

        debugPrint(
          '[SESSION_RESTORE][COMPLETED] '
          'source=legacyInline '
          'messageCount=${chatMsgs.length} '
          'mode=${restoredMode == true
              ? "estudo"
              : restoredMode == false
              ? "plantao"
              : "unknown"}',
        );

        _scrollDown(force: true);

      case AiSessionSource.canonicalV2:
      case AiSessionSource.localMemory:
        setState(() {
          _messages.clear();
          _lastAiIndex = -1;
          _greetingDone = true;
          _userScrolledUp = false;
          _restoredSessionId = summary.sessionId;
          _activeSessionId = null;
          _hasNewMessageAfterRestore = false;

          if (restoredMode != null) {
            _longResponse = restoredMode;
          }

          _modeConfirmed = restoredMode != null;
          _modeReselectionPending = false;
          _restoredModeSelectionPending = restoredMode == null;

          _thinking = true;
          _isStreaming = false;
          _sendGuard = false;
        });

        final uid = _resolveUid(p) ?? '';

        if (uid.isEmpty) {
          if (mounted) {
            setState(() {
              _thinking = false;
            });
          }

          return;
        }

        () async {
          try {
            final result = await FirestoreService.loadAiSessionExchangesTyped(
              uid,
              summary.sessionId,
            );

            if (!mounted ||
                restoreGeneration != _historyRestoreGeneration ||
                _selectedHistorySessionId != summary.sessionId) {
              debugPrint(
                '[SESSION_RESTORE][STALE_DROP] '
                'sessionIdHash=${summary.sessionId.hashCode} '
                'restoreGeneration=$restoreGeneration '
                'currentGeneration=$_historyRestoreGeneration',
              );

              return;
            }

            if (result.isSuccess) {
              final exchanges = result.dataOrElse([]);

              debugPrint(
                '[SESSION_EXCHANGES_LOAD][SUCCESS] '
                'sessionIdHash=${summary.sessionId.hashCode} '
                'exchangeCount=${exchanges.length} '
                'messageCount=${exchanges.length * 2}',
              );

              final chatMsgs = <_ChatMsg>[];

              for (final exchange in exchanges) {
                final userInput = (exchange['userInput'] as String?) ?? '';
                final userDisplayText = (exchange['userDisplayText'] as String?)
                    ?.trim();

                final aiOutput = (exchange['assistantOutput'] as String?) ?? '';

                if (userInput.isNotEmpty) {
                  chatMsgs.add(
                    _ChatMsg(
                      role: 'user',
                      text: userInput,
                      userDisplayText: userDisplayText?.isNotEmpty == true
                          ? userDisplayText
                          : null,
                    ),
                  );
                }

                if (aiOutput.isNotEmpty) {
                  chatMsgs.add(_ChatMsg(role: 'ai', text: aiOutput));
                }
              }

              _adoptRestoredSessionIdentity(summary, p);

              setState(() {
                _messages.clear();
                _messages.addAll(chatMsgs);
                _thinking = false;
              });

              p.rebuildAiHistoryFromMessages(
                chatMsgs
                    .where(
                      (message) =>
                          message.role == 'user' || message.role == 'ai',
                    )
                    .map(
                      (message) => {
                        'role': message.role == 'ai' ? 'assistant' : 'user',
                        'content': message.text,
                      },
                    )
                    .toList(),
              );

              debugPrint(
                '[SESSION_RESTORE][COMPLETED] '
                'source=${summary.source.name} '
                'messageCount=${chatMsgs.length} '
                'mode=${restoredMode == true
                    ? "estudo"
                    : restoredMode == false
                    ? "plantao"
                    : "unknown"}',
              );

              _scrollDown(force: true);
            } else if (result.isEmpty) {
              _adoptRestoredSessionIdentity(summary, p);

              setState(() {
                _thinking = false;
              });

              debugPrint(
                '[SESSION_RESTORE][COMPLETED] '
                'source=${summary.source.name} '
                'messageCount=0',
              );
            } else if (result.isAuthDenied) {
              setState(() {
                _thinking = false;
                _restoredSessionId = null;
                _restoredModeSelectionPending = false;
              });

              debugPrint(
                '[SESSION_RESTORE][ABORTED] '
                'reason=auth_denied '
                'sessionIdHash=${summary.sessionId.hashCode}',
              );
            } else if (result.isOffline) {
              setState(() {
                _thinking = false;
              });

              debugPrint(
                '[SESSION_RESTORE][ABORTED] '
                'reason=offline '
                'sessionIdHash=${summary.sessionId.hashCode}',
              );
            } else {
              setState(() {
                _thinking = false;
              });

              debugPrint(
                '[SESSION_RESTORE][ABORTED] '
                'reason=failure '
                'sessionIdHash=${summary.sessionId.hashCode}',
              );
            }
          } catch (error) {
            if (!mounted ||
                restoreGeneration != _historyRestoreGeneration ||
                _selectedHistorySessionId != summary.sessionId) {
              return;
            }

            setState(() {
              _thinking = false;
            });

            debugPrint(
              '[SESSION_RESTORE][ABORTED] '
              'reason=exception '
              'sessionIdHash=${summary.sessionId.hashCode} '
              'err=$error',
            );
          }
        }();
    }
  }

  /// Desce para o fundo do chat.
  /// [force] = true: ignora a flag _userScrolledUp (usado ao ENVIAR mensagem própria).
  /// [instant] = true: animação rápida para envio de mensagem (150ms easeOutQuad).
  ///
  /// Build 96 — Smooth Rolling:
  ///   • force=true  → 220ms easeOutCubic (resposta imediata ao envio do usuário)
  ///   • force=false → throttle 80ms + 150ms easeOutQuad (scroll de streaming suave)
  void _scrollDown({bool force = false}) {
    // Regra: se o usuário scrollou para cima E não é um envio forçado → não interrompe
    if (_userScrolledUp && !force) return;

    // Throttle para scroll de streaming (não-forçado): evita stutter
    if (!force) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (nowMs - _lastScrollMs < 80) return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_userScrolledUp && !force) return;
      if (!_scrollCtrl.hasClients) return;

      final pos = _scrollCtrl.position;
      final target = pos.maxScrollExtent;

      // Sem movimento necessário
      if (!force && pos.pixels >= target - 4) return;

      _lastScrollMs = DateTime.now().millisecondsSinceEpoch;

      if (force) {
        // Envio de mensagem pelo usuário: scroll imediato mas suave (220ms)
        _scrollCtrl.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      } else {
        // Scroll durante streaming: fluido e leve (150ms easeOutQuad)
        _scrollCtrl.animateTo(
          target,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutQuad,
        );
      }
    });
  }

  /// Chamado pelo AiBubble a cada bloco revelado durante streaming.
  /// Lógica centralizada aqui — ÚNICA fonte de verdade para scroll durante streaming.
  /// [gen] é o token de geração: se não bater com _scrollGeneration, ignora.
  ///
  /// Build 96 — Smooth Rolling: throttle de 80ms + animateTo(150ms, easeOutQuad)
  /// elimina o efeito "saltitante" causado por múltiplos jumpTo/ensureVisible
  /// em frames consecutivos durante o streaming de chunks.
  void _onBlockRevealed(int gen) {
    // Bloco pertence a uma resposta antiga (geração diferente) → ignora completamente.
    if (gen != _scrollGeneration) return;
    if (!mounted) return;
    // Usuário scrollou para cima intencionalmente → não interrompe leitura.
    if (_userScrolledUp) return;

    // Throttle temporal: no máximo 1 scroll animado a cada 80ms.
    // Evita sobrecarregar a engine de animação com calls a cada chunk/caractere.
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastScrollMs < 80) return;

    // Debounce por frame: agrupa várias revelações no mesmo frame em uma só animação.
    if (_scrollPending) return;
    _scrollPending = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollPending = false;
      if (!mounted) return;
      if (gen != _scrollGeneration) return;
      if (_userScrolledUp) return;
      if (!_scrollCtrl.hasClients) return;

      // Registra timestamp APÓS confirmação de execução
      _lastScrollMs = DateTime.now().millisecondsSinceEpoch;

      final pos = _scrollCtrl.position;
      final target = pos.maxScrollExtent;

      // Já está no fundo (ou quase) → sem animação desnecessária
      if (pos.pixels >= target - 4) return;

      // Fix 4 — Scroll suave: 120ms + easeOut — cadenciado pelo debounce 80ms.
      // animateTo aguarda o layout estar calculado (addPostFrameCallback já garante isso)
      // e produz transição fluida tipo WhatsApp/Telegram sem saltos por letra.
      _scrollCtrl.animateTo(
        target,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    });
  }

  void _onStudyContinuationVisualComplete(String messageId, int generation) {
    if (!mounted ||
        _isStreaming ||
        generation != _scrollGeneration ||
        _lastAiIndex < 0 ||
        _lastAiIndex >= _messages.length) {
      return;
    }

    final lastAiMessage = _messages[_lastAiIndex];

    if (lastAiMessage.role != 'ai' || lastAiMessage.id != messageId) {
      return;
    }

    final identity = '$generation:$messageId';

    if (_studyContinuationVisualReadyIdentity == identity) {
      return;
    }

    setState(() {
      _studyContinuationVisualReadyIdentity = identity;
    });
  }

  // Guard local de envio: complementa o guard no provider.
  // Evita que ENTER + click simultâneo no botão dispare 2 envios.
  bool _sendGuard = false;

  // Streaming V2: true enquanto chunks chegam (controla cursor ▌ na bolha ativa)
  bool _isStreaming = false;

  // PHASE 4 — geração soberana da requisição visível.
  // Todo cancelamento/reset incrementa este token. Callbacks pertencentes
  // a uma geração anterior são descartados antes de tocar na árvore da UI.
  int _aiUiRequestGeneration = 0;

  // Build 188 — ValueNotifier para streaming ultra-localizado:
  // Atualiza APENAS o widget da bolha ativa em vez de reconstruir toda a tela.
  // Criado ao iniciar streaming, descartado ao terminar.
  ValueNotifier<String>? _streamingTextNotifier;

  // BUILD 276 — Fade-in tracker: msgId of the bubble currently fading in.
  // Set to the new AI message's id in onDone; cleared after the animation ends.
  // Used by ListView.builder to wrap the bubble in AnimatedOpacity.
  String? _fadingInMsgId;

  // ── Build 135: Debounce de 300ms no submit ─────────────────────────────────
  // Fecha a janela residual (~50ms) entre finally() e listen() registration
  // em que um clique ultra-rápido poderia passar pelo _aiCallInFlight.
  //
  // REGRA: atua SOMENTE no submit (botão + Enter) — não afeta digitação.
  // O debounce NÃO atrasa o primeiro envio perceptivelmente (300ms < threshold
  // de percepção humana de latência em tap rápido). Em dispositivos médicos
  // (tablet de plantão), 300ms é imperceptível e seguro.
  //
  // Cadeia de proteção (3 camadas):
  //   Layer 1: _submitDebounceTimer (300ms, aqui)
  //   Layer 2: _sendGuard (local, nesta screen)
  //   Layer 3: _aiCallInFlight (provider, app_provider.dart Build 134)
  Timer? _submitDebounceTimer;

  // Wrapper de debounce: agenda _send com 300ms de delay.
  // Chamadas repetidas dentro da janela reiniciam o timer (último vence).
  void _sendDebounced(
    String text,
    AppProvider p, {
    bool fromButton = false,
    String? userDisplayText,
    PlantaoContinuationType continuationType =
        PlantaoContinuationType.freeFollowUp,
    List<PlantaoSection> requestedSections = const <PlantaoSection>[],
  }) {
    _submitDebounceTimer?.cancel();
    _submitDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      _send(
        text,
        p,
        fromButton: fromButton,
        userDisplayText: userDisplayText,
        continuationType: continuationType,
        requestedSections: requestedSections,
      );
    });
  }

  // PHASE3I-J2D1: bind canonical user case anchor to Plantão button actions.
  //
  // The visible action stays short in the chat. Only the productive provider
  // input receives the original clinical case, derived exclusively from a
  // prior user message. AI-generated text is never used as factual case evidence.
  String _bindPlantaoCaseAnchorForButton(String actionText) {
    final normalizedAction = actionText.trim();
    if (normalizedAction.isEmpty || _longResponse) return actionText;

    String? canonicalUserCase;
    for (final message in _messages) {
      if (message.role != 'user') continue;
      final candidate = message.text.trim();
      if (candidate.isEmpty || candidate == normalizedAction) continue;
      canonicalUserCase = candidate;
      break;
    }

    if (canonicalUserCase == null || canonicalUserCase.isEmpty) {
      return actionText;
    }

    if (kDebugMode) {
      debugPrint(
        '[PHASE3I_J2D1][CASE_ANCHOR_BOUND] '
        'caseChars=${canonicalUserCase.length} '
        'actionChars=${normalizedAction.length}',
      );
    }

    return '$normalizedAction\n\n'
        'CONTEXTO CLÍNICO OBRIGATÓRIO DESTE MESMO CASO, '
        'FORNECIDO PELO USUÁRIO:\n'
        '$canonicalUserCase\n\n'
        'Responda à ação solicitada preservando explicitamente os dados '
        'clínicos acima. Não substitua o caso por uma orientação genérica.';
  }

  Future<void> _send(
    String text,
    AppProvider p, {
    bool fromButton = false,
    String? userDisplayText,
    PlantaoContinuationType continuationType =
        PlantaoContinuationType.freeFollowUp,
    List<PlantaoSection> requestedSections = const <PlantaoSection>[],
  }) async {
    // ── BUILD 303 SECURITY PATCH: PRÉ-GUARDA ABSOLUTA (LAYER 0) ──────────────
    // Interceptação SÍNCRONA antes de qualquer outra lógica — cobre TODAS as
    // rotas de entrada: botão, Enter (KeyboardListener), onSubmitted, chip tap,
    // retry de erro, consumePendingQuery, edição de mensagem, etc.
    // Condição ESTRITA: sessionToken (currentUser Firebase) + auth real de IA.
    // Qualquer ausência → teclado fecha, modal sobe, return IMEDIATO.
    // Complementar ao Factor 2 abaixo — Layer 0 dispara antes de trimmed.trim().
    if (p.currentUser == null || (!p.geminiConnected && p.openAiKey.isEmpty)) {
      FocusScope.of(context).unfocus();
      _openAiSettings();
      debugPrint(
        '[BUILD303_LAYER0] Bloqueio pré-guarda: '
        'currentUser=${p.currentUser?.uid ?? "NULL"} '
        'geminiConnected=${p.geminiConnected} '
        'openAiKey=${p.openAiKey.isNotEmpty} → return imediato, zero bytes ao backend.',
      );
      return;
    }

    final trimmed = text.trim();
    final normalizedUserDisplayText = userDisplayText?.trim() ?? '';
    // Bloqueia: texto vazio, IA pensando/streaming, ou guard ativo (duplo envio)
    if (trimmed.isEmpty || _thinking || _isStreaming || _sendGuard) return;

    // ── ADENDO SEGURANÇA Factor 2: HARD BLOCKER ABSOLUTO — verificação ESTRITA ─
    // REGRA DE NEGÓCIO SOBERANA: nenhuma query pode chegar ao backend sem
    // autenticação real do usuário. Condição estrita exclui GeminiService.hasApiKey
    // (chave do servidor compartilhada) que antes permitia bypass silencioso.
    // Condição válida: geminiConnected (OAuth Google real) OU openAiKey pessoal.
    // NÃO: hasAnyAi (inclui chave servidor → brechaconfirmada nos logs de produção).
    final bool hasRealAuth = p.geminiConnected || p.openAiKey.isNotEmpty;
    if (!hasRealAuth) {
      // 1. Return SÍNCRONO e IMEDIATO — engine bloqueada antes de qualquer await
      // 2. Fecha o teclado
      FocusScope.of(context).unfocus();
      // 3. SnackBar de aviso claro
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Text('⚠️ ', style: TextStyle(fontSize: 16)),
                Expanded(
                  child: Text(
                    p.lang == 'es'
                        ? 'Conecta tu cuenta Google para usar la IA.'
                        : 'Conecte sua conta Google para usar a IA.',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1A1D23),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      // 4. Modal de conexão — oportunidade clara de autenticação
      _openAiSettings();
      debugPrint(
        '[HARD_BLOCKER_V2] Factor2 acionado — geminiConnected=${p.geminiConnected} '
        'openAiKey=${p.openAiKey.isNotEmpty} → bloqueio total, modal levantado.',
      );
      return; // ← BARREIRA ABSOLUTA: nenhum código abaixo executa
    }

    // BUILD 258: limpa _extToolCache na nova query para evitar stale drug slots.
    // O cache acumula entradas de mensagens anteriores (old=amiodarona, etc.).
    // Ao iniciar nova query, a resposta AI anterior gera novo extKey — o cache
    // antigo é inócuo, mas limpar aqui previne crescimento ilimitado e garante
    // que novos extKeys não colisão com chaves de sessões anteriores reutilizadas.
    _extToolCache.clear();
    _loggedExtToolKeys.clear(); // BUILD 308: reset log-dedup junto com cache

    _sendGuard = true;
    _focusNode.unfocus();
    // BUILD 452-1: atualiza timestamp de última atividade (para TTL 30 min)
    _updateLastActive();
    // Registra no histórico de atividades recentes
    ActivityService.log(
      type: ActivityType.ia,
      title: trimmed.length > 60 ? '${trimmed.substring(0, 60)}…' : trimmed,
      subtitle: 'IA Clínica',
    );
    setState(() {
      _messages.add(
        _ChatMsg(
          role: 'user',
          text: trimmed,
          userDisplayText: normalizedUserDisplayText.isNotEmpty
              ? normalizedUserDisplayText
              : null,
        ),
      );
      _thinking = true;
      _aiError = false;
      _networkError = false; // limpa banner de rede ao enviar nova mensagem
      _userScrolledUp =
          false; // reset ao enviar — desce para mostrar "pensando"
      // Marca que o usuário enviou nova mensagem (relevante ao restaurar sessão)
      _hasNewMessageAfterRestore = true;
    });
    // ── Fix 1: Persistência Imediata por Turno (pós-envio do usuário) ─────────
    // Salva o estado corrente (incluindo a pergunta do usuário) ANTES de aguardar
    // a resposta da IA. Garante que a mensagem não se perde se o usuário sair da
    // aba imediatamente após enviar — o histórico já está no disco.
    _saveCurrentSessionToHistory(p);
    _queryCtrl.clear();
    _scrollDown(force: true); // força scroll ao enviar mensagem do usuário

    // PHASE 4 — captura a propriedade desta requisição na UI.
    final int uiRequestGeneration = ++_aiUiRequestGeneration;

    // ── Índice da bolha de streaming (-1 = não iniciada ainda) ──────────────
    int streamingMsgIdx = -1;

    // ── AUDIT 4.1 — StreamingTextNotifier lifecycle ────────────────────────
    // Inicializa o ValueNotifier<String> ANTES de sendAiMessage() para garantir
    // que ele exista quando o primeiro chunk chegar (onChunk callback).
    //
    // PROBLEMA ANTERIOR: _streamingTextNotifier era apenas null; as chamadas
    // `_streamingTextNotifier?.value = cleanedChunk` eram todas no-ops silenciosos.
    // O notifier nunca era criado → AiBubble recebia null → streaming ultra-localizado
    // (sem rebuild da árvore inteira) não funcionava → cada chunk reconstruía
    // toda a lista via setState() → GC pressure aumentada + UI jitter em respostas longas.
    //
    // SOLUÇÃO: criar o notifier aqui (pré-streaming), passá-lo para AiBubble via
    // `streamingTextNotifier`, e descartá-lo no onDone/onError como antes.
    // Garante repaint cirúrgico localizado na bolha ativa.
    _streamingTextNotifier?.dispose(); // descarta eventual notifier órfão
    _streamingTextNotifier = ValueNotifier<String>('');

    // Associação volátil do Structured Output à bolha final.
    // Só será preenchida quando o texto definitivo da UI permanecer exatamente
    // igual ao displayText validado pelo backend.
    String? committedAiMessageId;
    String? committedAiMessageText;

    // ── Build 230: Anti-Freezing — trava de header strip após chunk 12 ────────
    // _stripMetadataHeaders() usa RegEx pesado com dotAll=true e múltiplas
    // alternâncias — rodar em CADA chunk bloqueia o main thread e congela o
    // stream visual. Estratégia: rodar apenas nos primeiros 12 chunks onde
    // prompt-leak pode aparecer (primeiras linhas da resposta, ~600 chars).
    // Após 12 chunks sem leak, _metaHeadersConfirmedClean=true: fast path.
    bool metaHeadersConfirmedClean = false;
    int chunksSinceStart = 0;
    int guardiaTraceUiChunkIndex = 0;
    String? guardiaFrozenVisibleText;

    // PHASE3K-C5A-R12-V5: mantém feedback animado quando os deltas
    // terminam, mas o commit terminal ainda está validando/persistindo.
    // O indicador não altera texto, histórico, DTO ou persistência.
    Timer? terminalGapIndicatorTimer;
    var terminalGapIndicatorVisible = false;

    void clearTerminalGapIndicator({
      required String reason,
      bool rebuild = true,
    }) {
      terminalGapIndicatorTimer?.cancel();
      terminalGapIndicatorTimer = null;
      if (!terminalGapIndicatorVisible) return;

      terminalGapIndicatorVisible = false;
      if (rebuild && mounted && uiRequestGeneration == _aiUiRequestGeneration) {
        setState(() {
          _thinking = false;
        });
      }

      assert(() {
        debugPrint(
          '[GUARDIA_TERMINAL_GAP] stage=indicator_off '
          'reason=$reason '
          'tsUs=${DateTime.now().microsecondsSinceEpoch}',
        );
        return true;
      }());
    }

    void armTerminalGapIndicator() {
      terminalGapIndicatorTimer?.cancel();
      terminalGapIndicatorTimer = Timer(const Duration(milliseconds: 450), () {
        if (!mounted ||
            uiRequestGeneration != _aiUiRequestGeneration ||
            !_isStreaming ||
            terminalGapIndicatorVisible) {
          return;
        }

        terminalGapIndicatorVisible = true;
        setState(() {
          _thinking = true;
        });

        assert(() {
          debugPrint(
            '[GUARDIA_TERMINAL_GAP] stage=indicator_on '
            'tsUs=${DateTime.now().microsecondsSinceEpoch}',
          );
          return true;
        }());
      });
    }

    try {
      // ── Streaming V2 via sendAiMessage ────────────────────────────────────
      // Retorna true se usou streaming (Gemini conectado), false se usou fallback.
      final providerInput = fromButton && !_longResponse
          ? _bindPlantaoCaseAnchorForButton(trimmed)
          : trimmed;

      await p.sendAiMessage(
        providerInput,
        visibleUserInput: trimmed,
        userDisplayText: normalizedUserDisplayText.isNotEmpty
            ? normalizedUserDisplayText
            : null,
        longResponse: _longResponse, // Motor de Partida (Build 149)
        fromButton: fromButton, // BUILD 262: preserves thread on action buttons
        shadowContinuationType: continuationType,
        shadowRequestedSections: requestedSections,
        onChunk: (accumulated) {
          if (!mounted || uiRequestGeneration != _aiUiRequestGeneration) return;

          clearTerminalGapIndicator(reason: 'next_chunk');
          armTerminalGapIndicator();

          guardiaTraceUiChunkIndex++;
          final guardiaTraceNotifierBefore =
              _streamingTextNotifier?.value.length ?? 0;
          assert(() {
            if (!_longResponse &&
                (guardiaTraceUiChunkIndex <= 3 ||
                    guardiaTraceUiChunkIndex % 25 == 0)) {
              debugPrint(
                '[GUARDIA_TRACE] stage=I2_ui_chunk_in '
                'uiGeneration=$uiRequestGeneration '
                'chunkIndex=$guardiaTraceUiChunkIndex '
                'incomingLen=${accumulated.length} '
                'notifierBefore=$guardiaTraceNotifierBefore',
              );
            }
            return true;
          }());

          // ── BUILD 276: SUPPRESSED CHUNK RENDERING ─────────────────────────
          // Arquitectura: mantém _thinking=true e AiShimmerDots visível
          // durante todo o streaming. Chunks são bufferizados internamente
          // no slot de _messages (criado no primeiro chunk) SEM nenhuma
          // mudança de estado de UI. A resposta é commitada em único setState
          // no onDone — experiência de bloco sólido + fade-in.
          //
          // Isso elimina o "typewriter artefact" (asteriscos brutos renderizados
          // como <pre> pelo Flutter Markdown em saída de stream parcial).
          // O indicador ECG permanece até a resposta completa estar pronta.
          if (!mounted) return;

          // ── BUILD 318: CHUNK THROTTLE ─────────────────────────────────────
          // Limita a frequência de atualização do buffer interno.
          // BUILD 276 já suprime setState/notifier em onChunk — apenas o
          // buffer de _messages é atualizado. Mesmo assim, cada chamada
          // executa _stripMetadataHeaders + _ChatMsg.withId (alocação).
          // Throttle de 25ms: agrupa tokens rápidos (< 40ms inter-chunk)
          // em uma única atualização — reduz GC pressure em dispositivos
          // com Dart VM compactante (Android / iOS).
          // EXCEPÇÃO: primeiro chunk (streamingMsgIdx == -1) passa sempre
          // para criar o slot sem atraso perceptível.
          final nowMs = DateTime.now().millisecondsSinceEpoch;
          if (streamingMsgIdx != -1 && nowMs - _lastChunkRenderMs < 25) return;
          _lastChunkRenderMs = nowMs;

          try {
            chunksSinceStart++;

            // ── BUILD 318: METADATA STRIP SAFE WINDOW ─────────────────────
            // PROBLEMA RAIZ da duplicação/truncamento:
            //   _stripMetadataHeaders(accumulated) recebia o texto ACUMULADO
            //   crescente (ex: chunk 8 = 400 chars). Se o regex do strip
            //   casar no meio do acumulado (falso positivo), retorna texto
            //   menor — sobrescreve o buffer com versão truncada. Chunk
            //   seguinte restaura o texto, que parece "duplicado" visualmente.
            //
            // SOLUÇÃO BUILD 318: aplicar strip APENAS nos primeiros 600 chars
            //   do acumulado (janela de header leak). Texto após 600 chars
            //   nunca contém prompt leak — fast path sem regex.
            //   Isso garante que o buffer cresce monotonicamente (sem regressão
            //   de comprimento entre chunks consecutivos).
            final String cleanedChunk;
            if (metaHeadersConfirmedClean) {
              // Fast path: sem regex após confirmar limpeza
              cleanedChunk = accumulated;
            } else {
              // Aplica strip apenas na janela inicial segura (≤ 600 chars)
              // para evitar corte acidental em texto clínico longo
              final safeWindow = accumulated.length <= 600
                  ? accumulated
                  : accumulated.substring(0, 600);
              final strippedWindow = _stripMetadataHeaders(safeWindow);
              // Reconstrói: janela stripada + resto original intacto
              cleanedChunk = accumulated.length <= 600
                  ? strippedWindow
                  : strippedWindow + accumulated.substring(600);
              if (chunksSinceStart >= 12) metaHeadersConfirmedClean = true;
            }

            final String visibleStreamingChunk;
            if (_longResponse) {
              visibleStreamingChunk = cleanedChunk;
            } else if (guardiaFrozenVisibleText != null) {
              visibleStreamingChunk = guardiaFrozenVisibleText!;
            } else {
              final stableGuardiaText =
                  GuardiaStreamingPresentation.stableBeforeHardStop(
                    rawText: cleanedChunk,
                    isStreaming: true,
                  );
              final previousVisibleText = _streamingTextNotifier?.value ?? '';
              final hardStopBoundaryDetected =
                  stableGuardiaText.length < cleanedChunk.length;

              if (hardStopBoundaryDetected) {
                final canPreservePreviousVisible =
                    previousVisibleText.isNotEmpty &&
                    previousVisibleText.length >= stableGuardiaText.length &&
                    cleanedChunk.startsWith(previousVisibleText);
                final monotonicFrozenText = canPreservePreviousVisible
                    ? previousVisibleText
                    : stableGuardiaText;

                guardiaFrozenVisibleText = monotonicFrozenText;
                visibleStreamingChunk = monotonicFrozenText;

                assert(() {
                  debugPrint(
                    '[GUARDIA_STREAM_FREEZE] hardStopTailHidden=true '
                    'monotonic=true '
                    'previousVisibleLen=${previousVisibleText.length} '
                    'stableLen=${stableGuardiaText.length} '
                    'visibleLen=${monotonicFrozenText.length} '
                    'bufferLen=${cleanedChunk.length}',
                  );
                  return true;
                }());
              } else {
                visibleStreamingChunk = stableGuardiaText;
              }
            }

            // ── Atualização do buffer interno ─────────────────────────────
            // Invariante: buffer só cresce ou permanece igual entre chunks.
            // (cleanedChunk = texto acumulado completo do provider, nunca truncado)
            if (streamingMsgIdx == -1) {
              // Primeiro chunk: cria o slot no buffer e dispara primeiro render.
              // BUILD 332 Fix 2: _streamingTextNotifier ativado para chunk-by-chunk.
              _messages.add(_ChatMsg(role: 'ai', text: cleanedChunk));
              streamingMsgIdx = _messages.length - 1;

              // PHASE 4 — transição soberana:
              // aguardando/ECG → primeiro delta → bolha de streaming.
              //
              // O primeiro delta encerra o estado de espera, ativa a bolha
              // corrente e conecta o ValueNotifier ao streaming visível.
              if (mounted) {
                setState(() {
                  _thinking = false;
                  _isStreaming = true;
                  _lastAiIndex = streamingMsgIdx;
                });
                if (_streamingTextNotifier?.value != visibleStreamingChunk) {
                  _streamingTextNotifier?.value = visibleStreamingChunk;
                }
                assert(() {
                  if (!_longResponse) {
                    debugPrint(
                      '[GUARDIA_TRACE] stage=I2_ui_notifier_out '
                      'uiGeneration=$uiRequestGeneration '
                      'chunkIndex=$guardiaTraceUiChunkIndex '
                      'incomingLen=${accumulated.length} '
                      'cleanedLen=${cleanedChunk.length} '
                      'notifierBefore=$guardiaTraceNotifierBefore '
                      'notifierAfter='
                      '${_streamingTextNotifier?.value.length ?? 0}',
                    );
                  }
                  return true;
                }());
              }
            } else {
              // Chunks subsequentes: atualiza buffer E notifier para render em tempo real.
              if (streamingMsgIdx >= 0 && streamingMsgIdx < _messages.length) {
                final prevLen = _messages[streamingMsgIdx].text.length;
                if (cleanedChunk.length >= prevLen) {
                  _messages[streamingMsgIdx] = _ChatMsg.withId(
                    id: _messages[streamingMsgIdx].id,
                    role: 'ai',
                    text: cleanedChunk,
                    clinicalOutput: _messages[streamingMsgIdx].clinicalOutput,
                  );
                  // BUILD 332 Fix 2: notifier → repaint localizado na bolha de streaming
                  // sem rebuild de toda a árvore (economia de UI thread).
                  if (_streamingTextNotifier?.value != visibleStreamingChunk) {
                    _streamingTextNotifier?.value = visibleStreamingChunk;
                  }
                  assert(() {
                    if (!_longResponse) {
                      debugPrint(
                        '[GUARDIA_TRACE] stage=I2_ui_notifier_out '
                        'uiGeneration=$uiRequestGeneration '
                        'chunkIndex=$guardiaTraceUiChunkIndex '
                        'incomingLen=${accumulated.length} '
                        'cleanedLen=${cleanedChunk.length} '
                        'notifierBefore=$guardiaTraceNotifierBefore '
                        'notifierAfter='
                        '${_streamingTextNotifier?.value.length ?? 0}',
                      );
                    }
                    return true;
                  }());
                }
              }
            }
          } catch (_) {
            // Chunk malformado: descartado silenciosamente.
          }
        },
        onDone: (finalText) {
          clearTerminalGapIndicator(reason: 'done', rebuild: false);
          if (!mounted || uiRequestGeneration != _aiUiRequestGeneration) return;

          // PHASE3I-J2B1: terminal ownership reached the active UI request.
          // Release the synchronous double-submit latch on terminal delivery.
          _sendGuard = false;
          final guardiaTraceCurrentMessageLen =
              streamingMsgIdx >= 0 && streamingMsgIdx < _messages.length
              ? _messages[streamingMsgIdx].text.length
              : -1;

          // MEDCASES_IA_PLANTAO_FINAL_TEXT_CONTINUITY_V1_B_R0_R1
          // Snapshot terminal do texto acumulado que o usuário já viu durante
          // o streaming. É somente um fallback de continuidade: nunca substitui
          // uma resposta final normal/mais rica.
          final guardiaProvisionalText =
              !_longResponse &&
                  streamingMsgIdx >= 0 &&
                  streamingMsgIdx < _messages.length
              ? _messages[streamingMsgIdx].text.trim()
              : '';
          assert(() {
            if (!_longResponse) {
              debugPrint(
                '[GUARDIA_TRACE] stage=I4_ui_final '
                'tsUs=${DateTime.now().microsecondsSinceEpoch} '
                'uiGeneration=$uiRequestGeneration '
                'chunkIndex=$guardiaTraceUiChunkIndex '
                'finalTextLen=${finalText.length} '
                'notifierLen=${_streamingTextNotifier?.value.length ?? 0} '
                'messageLen=$guardiaTraceCurrentMessageLen',
              );
            }
            return true;
          }());
          // ── Detecta tipo de resultado ─────────────────────────────────────
          final isKeyError =
              finalText.startsWith('ERRO') && finalText.contains('API');
          // Detecta erro de rede — NÃO usa finalText.contains('🚨') como critério
          // pois 🚨 é também marcador de seção clínica válida (ex: "🚨 INFARTO AGUDO DO MIOCÁRDIO").
          // Usamos apenas keywords textuais específicas de mensagens de erro de rede.
          final normalizedFinalText = finalText.toLowerCase();
          final isNetErr =
              normalizedFinalText.contains('sem conex') ||
              normalizedFinalText.contains('sin conex') ||
              normalizedFinalText.contains('timeout') ||
              normalizedFinalText.contains('falha na conex') ||
              normalizedFinalText.contains('falla de red') ||
              normalizedFinalText.contains('conexão necessária') ||
              normalizedFinalText.contains('conexión requerida') ||
              normalizedFinalText.contains('verifique sua conex') ||
              normalizedFinalText.contains('verifique sua rede') ||
              normalizedFinalText.contains('ia indisponível') ||
              normalizedFinalText.contains('ia indisponible');

          // ── BUILD 244B: safe-card path — caminho limpo antes de isNetErr ─────
          // Detecta safe-card de timeout pelo prefixo canônico (AppProvider).
          // Remove bolha parcial de streaming se existir, injeta uma única bolha
          // limpa com o texto do safe-card, e retorna sem passar por:
          //   _enforceMedicalFormat, _plantaoTruncationGuard, EvidenceBox,
          //   ActionButtons, ExternalToolLink, PlantaoRenderer.
          final isSafeCardDone =
              finalText.startsWith(AppProvider.kSafeCardMarkerPt) ||
              finalText.startsWith(AppProvider.kSafeCardMarkerEs);

          if (isSafeCardDone) {
            if (kDebugMode)
              debugPrint(
                '[SAFE_CARD_GUARD] onDone safeCard=true removing partial streamingMsgIdx=$streamingMsgIdx',
              );
            _streamingTextNotifier?.dispose();
            _streamingTextNotifier = null;
            setState(() {
              _thinking = false;
              _isStreaming = false;
              _aiError = false;
              _networkError = false;
              // Remove bolha parcial do mesmo request (se já havia chunks)
              if (streamingMsgIdx >= 0 && streamingMsgIdx < _messages.length) {
                _messages.removeAt(streamingMsgIdx);
                streamingMsgIdx = -1;
              }
              // Injeta safe-card como única bolha final — sem 2ª bolha
              _scrollGeneration++;
              _lastAiIndex = _messages.length;
              _messages.add(_ChatMsg(role: 'ai', text: finalText));
            });
            _scrollDown(force: true);
            // BUILD 320: guard !mounted antes de ler context.read e chamar save.
            // O onDone pode chegar após o widget ser desmontado (navegação rápida
            // ou timeout de resume que descarta o contexto antes do stream concluir).
            if (!mounted) return;
            // Persiste o turno (pergunta + safe-card) imediatamente
            _saveCurrentSessionToHistory(p);
            return; // pula _enforceMedicalFormat, _plantaoTruncationGuard e renderers
          }

          // ── BUILD 101 FIX: Desacopla texto final do flag _isStreaming ─────
          // PROBLEMA RAIZ: o setState anterior combinava _isStreaming=false +
          // texto final em um único setState. Isso fazia o AiBubble receber
          // isStreaming=false e texto final SIMULTANEAMENTE no mesmo frame —
          // o _computeBlocks() removia o cursor ▌ e potencialmente produzia
          // um número diferente de blocos. Com layout ainda incompleto, o
          // jumpTo no onDone saltava para um maxScrollExtent MENOR que o real,
          // congelando o scroll antes do último bloco aparecer na tela.
          //
          // SOLUÇÃO: 2 setStates separados:
          // setState #1 (agora): comita texto final COM _isStreaming=true ainda
          //   → AiBubble já recebe o texto completo mas mantém o cursor ▌
          //   → os novos blocos são adicionados ao layout enquanto streaming=true
          // setState #2 (no próximo frame via addPostFrameCallback): remove cursor
          //   → layout dos blocos finais já está calculado
          //   → _isStreaming=false pode ser setado com segurança
          // _scrollFinalAfterStream() (após setState #2): 3 frames encadeados
          //   garantem que o maxScrollExtent está totalmente estabilizado
          //   antes do scroll final — elimina o congelamento mid-screen.

          if (isNetErr) {
            // Casos de erro: mantenha comportamento original para evitar regressão
            // Build 188: descarta notifier de streaming no caso de erro de rede
            _streamingTextNotifier?.dispose();
            _streamingTextNotifier = null;
            setState(() {
              _thinking = false;
              _isStreaming = false;
              _aiError = isKeyError;
              _networkError = isNetErr;
              // ── NETWORK SAFETY: erro de rede no onDone ───────────────────
              if (streamingMsgIdx >= 0 && streamingMsgIdx < _messages.length) {
                _messages.removeAt(streamingMsgIdx);
                streamingMsgIdx = -1;
              }
              if (_messages.isNotEmpty &&
                  _messages.last.role == 'user' &&
                  _messages.last.text == trimmed) {
                _messages.removeLast();
              }
              _scrollGeneration++;
              _lastAiIndex = _messages.length;
              _messages.add(_ChatMsg(role: 'ai', text: finalText));
            });
            _scrollDown(force: true);
          } else {
            // ── Build 134: enforceMedicalFormat — camada final de segurança ──
            // Aplicado AQUI, no texto final definitivo, antes de commitar na UI.
            // Não aplicado em onChunk (streaming parcial) para evitar artefatos.
            // Build 230: _enforceMedicalFormat SOMENTE no Modo Plantão.
            // No Modo Estudo, o texto começa com ## e não com 🟥 — injetar
            // o cabeçalho 🟥 CONDUTA quebraria a hierarquia didática.
            String safeFinalText = _longResponse
                ? finalText // Modo Estudo: texto sem modificação
                : _enforceMedicalFormat(finalText, p.lang);

            // ── Build 226: Plantão Truncation Guard ──────────────────────────
            // Detecta resposta truncada no Modo Plantão (ex: 503 mid-stream)
            // e substitui por fallback seguro em vez de renderizar texto parcial.
            // Critério: Modo Plantão + pipeline válida estrutura? Se não, fallback.
            if (!_longResponse) {
              safeFinalText = _plantaoTruncationGuard(
                safeFinalText,
                p.lang,
                userQuery:
                    trimmed, // BUILD 248B: passa query para detecção de intent
              );
            }

            // ── BUILD 276: CLIENT-SIDE BULLET STRIP (safety net) ─────────────
            // Final defence against Gemini emitting " * bullet" (ASCII-32 before *).
            // Strips any leading whitespace from lines that start with optional
            // spaces then `*` — the same pattern that causes Flutter Markdown to
            // render as a <pre> code block instead of a bullet list.
            // Runs once on the definitive final text (not on chunks) — zero cost.
            safeFinalText = safeFinalText
                .split('\n')
                .map(
                  (line) => line.trimLeft().isEmpty
                      ? line
                      : (line.trimLeft().startsWith('*')
                            ? line.trimLeft()
                            : line),
                )
                .join('\n');

            // ── SUPER ORDEM 41 M3: AESTHETIC GUARD ───────────────────────────
            // Higienização estética exclusiva do Modo Plantão (após todos os
            // guards de segurança): remove **bold** residuais, normaliza ALLCAPS
            // de labels → Title Case, aplica teto de 12 linhas não-vazias.
            // Executado ANTES do pipeline lock para que o texto cacheado já seja
            // o texto esteticamente finalizado.
            if (!_longResponse) {
              safeFinalText = _applyPlantaoAestheticGuard(safeFinalText);

              // V1-B-R0-R1 — terminal continuity hardening.
              //
              // Problema físico reproduzido no iPhone:
              //   conteúdo clínico rico aparece durante streaming;
              //   onDone recebe/processa um payload terminal degenerado;
              //   o mesmo slot é sobrescrito e sobra apenas um cabeçalho.
              //
              // Fail-safe extremamente estreito:
              // - só no Modo Plantão;
              // - exige uma fonte rica (provider final OU snapshot do stream);
              // - exige >=160 chars e >=3 linhas nessa fonte;
              // - o candidato terminal deve estar vazio ou <=120 chars,
              //   <=2 linhas e ter menos de 1/3 do conteúdo rico.
              //
              // Assim respostas finais normais, mesmo concisas, continuam
              // soberanas. Apenas um colapso terminal evidente é bloqueado.
              final providerFinalText = finalText.trim();
              final continuityFallbackText =
                  providerFinalText.length >= guardiaProvisionalText.length
                  ? providerFinalText
                  : guardiaProvisionalText;

              final candidate = safeFinalText.trim();
              final fallbackLineCount = continuityFallbackText
                  .split('\n')
                  .where((line) => line.trim().isNotEmpty)
                  .length;
              final candidateLineCount = candidate
                  .split('\n')
                  .where((line) => line.trim().isNotEmpty)
                  .length;

              final bool finalPayloadCollapsed =
                  continuityFallbackText.length >= 160 &&
                  fallbackLineCount >= 3 &&
                  (candidate.isEmpty ||
                      (candidate.length <= 120 &&
                          candidateLineCount <= 2 &&
                          candidate.length * 3 <
                              continuityFallbackText.length));

              if (finalPayloadCollapsed) {
                safeFinalText = continuityFallbackText
                    .split('\n')
                    .map(
                      (line) => line.trimLeft().startsWith('*')
                          ? line.trimLeft()
                          : line,
                    )
                    .join('\n');

                assert(() {
                  debugPrint(
                    '[GUARDIA_FINAL_CONTINUITY] preserved=true '
                    'candidateLen=${candidate.length} '
                    'fallbackLen=${continuityFallbackText.length} '
                    'candidateLines=$candidateLineCount '
                    'fallbackLines=$fallbackLineCount',
                  );
                  return true;
                }());
              }
            }

            // ── BUILD 254: SINCRONIZAÇÃO IMEDIATA DO TÉRMINO DO STREAM ────────
            // PROBLEMA: o layout 2-passos do BUILD 101 (texto em setState#1 com
            // _isStreaming=true, cursor removido em setState#2 via postFrameCallback)
            // causava "Turn Lag": _isStreaming=false chegava apenas 1 frame tarde,
            // impedindo o _PlantaoRenderer de montar até o próximo user-action.
            //
            // SOLUÇÃO BUILD 254: estado de término commitado em UM ÚNICO setState
            // síncrono — texto final + _isStreaming=false + dispose do notifier —
            // tudo no mesmo frame. O scroll final é delegado para o postFrameCallback
            // (sem setState — apenas animateTo), preservando a estabilidade de layout.
            //
            // COMPATIBILIDADE BUILD 101: _visibleCount no AiBubbleState já garante
            // visibilidade total ao receber isStreaming=false → old.isStreaming=true
            // (linha ~5904 de ai_screen). O cursor ▌ é removido corretamente pela
            // transição isStreaming true→false no didUpdateWidget.

            // Descarta notifier ANTES do setState — sem listener pendurado no rebuild.
            _streamingTextNotifier?.dispose();
            _streamingTextNotifier = null;

            // ORDEM 56: POST-STREAM PIPELINE LOCK removido — sem _plantaoPipelineCache.
            // AiBubble renderiza safeFinalText via MarkdownBody diretamente.

            // BUILD 276: resolve which msgId will be the new AI bubble so we
            // can attach the fade-in to it in ListView.builder.
            String? newBubbleMsgId;
            if (streamingMsgIdx >= 0 && streamingMsgIdx < _messages.length) {
              newBubbleMsgId = _messages[streamingMsgIdx].id;
            }

            // ÚNICO setState de fechamento: texto final + fim de stream em um frame.
            setState(() {
              _thinking = false;
              _isStreaming =
                  false; // BUILD 254: síncrono — sem postFrameCallback
              _aiError = isKeyError;
              _networkError = false;
              if (streamingMsgIdx >= 0) {
                // Caminho normal: atualiza bolha com texto definitivo
                _messages[streamingMsgIdx] = _ChatMsg.withId(
                  id: _messages[streamingMsgIdx].id,
                  role: 'ai',
                  text: safeFinalText,
                );
                newBubbleMsgId = _messages[streamingMsgIdx].id;
                committedAiMessageId = newBubbleMsgId;
                committedAiMessageText = safeFinalText;
                // ORDEM 29 FIX: _lastAiIndex DEVE apontar para streamingMsgIdx.
                // No caminho de streaming normal (streamingMsgIdx >= 0), a bolha é
                // atualizada in-place — mas _lastAiIndex nunca era sincronizado,
                // permanecendo -1 ou apontando para o turno anterior.
                // Isso tornava isPlantaoFinalBubble=false (i == _lastAiIndex falso),
                // causando fallback para AiBubble cru em vez de _PlantaoRenderer.
                _lastAiIndex = streamingMsgIdx;
              } else {
                // Fallback legado (sem streaming prévia de buffer)
                _scrollGeneration++;
                _lastAiIndex = _messages.length;
                final newMsg = _ChatMsg(role: 'ai', text: safeFinalText);
                _messages.add(newMsg);
                newBubbleMsgId = newMsg.id;
                committedAiMessageId = newMsg.id;
                committedAiMessageText = safeFinalText;
              }
              // AI-STREAM-VISUAL-I.1-R4: uma bolha já visível durante
              // o streaming não recebe uma segunda animação ao concluir.
              _fadingInMsgId = streamingMsgIdx >= 0 ? null : newBubbleMsgId;
            });

            // BUILD 276: auto-clear _fadingInMsgId after animation completes (400ms)
            // so the AnimatedOpacity wrapper is removed on the next rebuild.
            Future.delayed(const Duration(milliseconds: 450), () {
              if (!mounted) return;
              setState(() {
                _fadingInMsgId = null;
              });
            });

            // ── Fix 1: Persistência Imediata por Turno (pós-resposta da IA) ──
            // Salva o par (pergunta + resposta) no histórico imediatamente após
            // o stream finalizar. Garante que ao trocar de aba, o histórico
            // completo do turno já está persistido no disco/Firestore.
            // BUILD 320: guard !mounted — context.read<AppProvider>() em widget
            // desmontado lança FlutterError (DiagnosticsProperty<void>). O onDone
            // pode chegar tarde (Paid Proxy 60-75s) após navegação ou timeout.
            if (!mounted) return;
            _saveCurrentSessionToHistory(p);

            // ── BUILD 318: Scroll final (4 frames encadeados) ────────────────
            // 4 frames em vez de 3: garante que o _PlantaoRenderer (que monta
            // seus cards via AnimatedSize em múltiplos setStates internos)
            // tenha tempo suficiente para estabilizar o maxScrollExtent antes
            // do animateTo final — evita o freeze mid-screen em dispositivos
            // lentos (Android entry-level, GPU compactante).
            //
            // Guard _isStreaming: previne scroll espúrio se o usuário interrompeu
            // o stream manualmente (clearChat) após o onDone mas antes dos frames.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || _userScrolledUp || _isStreaming) return;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || _userScrolledUp || _isStreaming) return;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted || _userScrolledUp || _isStreaming) return;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    // Frame 4: maxScrollExtent totalmente estabilizado
                    if (!mounted || _userScrolledUp) return;
                    if (!_scrollCtrl.hasClients) return;
                    final pos = _scrollCtrl.position;
                    if (pos.pixels >= pos.maxScrollExtent - 4) return;
                    // animateTo suave 200ms — evita teleporte no layout tardio
                    _scrollCtrl.animateTo(
                      pos.maxScrollExtent,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                    );
                  });
                });
              });
            });
          }
        },
        onStructuredDone: (finalText, clinicalOutput) {
          if (mounted && uiRequestGeneration == _aiUiRequestGeneration) {
            _sendGuard = false;
          }
          assert(() {
            if (!_longResponse) {
              debugPrint(
                '[GUARDIA_TRACE] stage=I4_ui_structured '
                'tsUs=${DateTime.now().microsecondsSinceEpoch} '
                'uiGeneration=$uiRequestGeneration '
                'finalTextLen=${finalText.length} '
                'notifierLen=${_streamingTextNotifier?.value.length ?? 0} '
                'dto=${clinicalOutput != null} '
                'rx=${clinicalOutput?.prescricao.length ?? 0} '
                'first=${clinicalOutput?.primeiraLinha.length ?? 0} '
                'second=${clinicalOutput?.segundaLinha.length ?? 0} '
                'keys=${clinicalOutput?.pontosChave.length ?? 0} '
                'hard=${clinicalOutput?.hardStops.length ?? 0}',
              );
            }
            return true;
          }());

          if (!mounted ||
              uiRequestGeneration != _aiUiRequestGeneration ||
              clinicalOutput == null) {
            return;
          }

          final messageId = committedAiMessageId;
          final committedText = committedAiMessageText;

          // O backend entrega o texto clínico validado; a UI pode remover
          // somente apresentação Markdown antes de commitar a bolha final.
          // A associação continua fail-closed para qualquer diferença clínica.
          final bool isEquivalentFinalText =
              messageId != null &&
              committedText != null &&
              StructuredOutputTextEquivalence.matches(
                backendText: finalText,
                uiText: committedText,
              );

          if (!isEquivalentFinalText) {
            if (kDebugMode) {
              debugPrint(
                '[STRUCTURED_UI][DISCARDED] '
                'reason=final_text_not_equivalent '
                'backendLen=${finalText.length} '
                'uiLen=${committedText?.length ?? 0}',
              );
            }
            return;
          }

          final messageIndex = _messages.indexWhere(
            (message) => message.id == messageId,
          );
          if (messageIndex < 0) {
            if (kDebugMode) {
              debugPrint(
                '[STRUCTURED_UI][DISCARDED] '
                'reason=final_bubble_not_found',
              );
            }
            return;
          }

          final currentMessage = _messages[messageIndex];
          if (currentMessage.text != committedText) {
            if (kDebugMode) {
              debugPrint(
                '[STRUCTURED_UI][DISCARDED] '
                'reason=bubble_text_mismatch '
                'bubbleLen=${currentMessage.text.length} '
                'committedLen=${committedText.length}',
              );
            }
            return;
          }

          setState(() {
            _messages[messageIndex] = _ChatMsg.withId(
              id: currentMessage.id,
              role: currentMessage.role,
              text: currentMessage.text,
              clinicalOutput: clinicalOutput,
            );
          });

          if (kDebugMode) {
            debugPrint(
              '[STRUCTURED_UI][ATTACHED] '
              'messageId=$messageId '
              'prescriptionCount=${clinicalOutput.prescricao.length}',
            );
          }
        },
        onError: (errorMsg) {
          clearTerminalGapIndicator(reason: 'error', rebuild: false);
          if (!mounted || uiRequestGeneration != _aiUiRequestGeneration) return;

          _sendGuard = false;
          // Build 188: descarta notifier de streaming no onError
          _streamingTextNotifier?.dispose();
          _streamingTextNotifier = null;
          // ── BUILD 309 M4: AUTH_REQUIRED — NUNCA renderizar como bubble ────
          // Provider emite AUTH_REQUIRED quando o Factor3 guard bloqueia.
          // Suprimimos a bolha vermelha e abrimos o modal de conexão.
          if (errorMsg == 'AUTH_REQUIRED') {
            setState(() {
              _thinking = false;
              _isStreaming = false;
              // Remove a pergunta do usuário sem resposta
              if (_messages.isNotEmpty &&
                  _messages.last.role == 'user' &&
                  _messages.last.text == trimmed) {
                _messages.removeLast();
              }
            });
            // Abre modal de autenticação — convida o médico a conectar
            Future.microtask(() {
              if (mounted) _openAiSettings();
            });
            return;
          }
          // Guard do provider retornou '' — ignora (não adiciona bubble vazia)
          if (errorMsg.isEmpty) {
            setState(() {
              _thinking = false;
              _isStreaming = false;
              // Remove mensagem do usuário sem resposta
              if (_messages.isNotEmpty &&
                  _messages.last.role == 'user' &&
                  _messages.last.text == trimmed) {
                _messages.removeLast();
              }
            });
            return;
          }
          final isKeyError =
              errorMsg.startsWith('ERRO') && errorMsg.contains('API');
          // Detecta erro de rede — NÃO usa errorMsg.contains('🚨') como critério
          // pois 🚨 é também marcador de seção clínica válida.
          // Usamos apenas keywords textuais específicas de mensagens de erro de rede.
          final normalizedErrorMessage = errorMsg.toLowerCase();
          final isNetErr =
              normalizedErrorMessage.contains('sem conex') ||
              normalizedErrorMessage.contains('sin conex') ||
              normalizedErrorMessage.contains('timeout') ||
              normalizedErrorMessage.contains('falha na conex') ||
              normalizedErrorMessage.contains('falla de red') ||
              normalizedErrorMessage.contains('conexão necessária') ||
              normalizedErrorMessage.contains('conexión requerida') ||
              normalizedErrorMessage.contains('verifique sua conex') ||
              normalizedErrorMessage.contains('verifique sua rede') ||
              normalizedErrorMessage.contains('ia indisponível') ||
              normalizedErrorMessage.contains('ia indisponible');
          setState(() {
            _thinking = false;
            _isStreaming = false;
            _aiError = isKeyError;
            _networkError = isNetErr;
            _scrollGeneration++;

            if (isNetErr) {
              // ── NETWORK SAFETY: erro de rede no onError ──────────────────
              // Remove bolha parcial de streaming — nunca exibir dados antigos
              if (streamingMsgIdx >= 0 && streamingMsgIdx < _messages.length) {
                _messages.removeAt(streamingMsgIdx);
                streamingMsgIdx = -1;
              }
              // Remove mensagem do usuário — não deixar pergunta sem resposta
              if (_messages.isNotEmpty &&
                  _messages.last.role == 'user' &&
                  _messages.last.text == trimmed) {
                _messages.removeLast();
              }
              // Injeta Alerta Clínico como bolha da IA
              _lastAiIndex = _messages.length;
              _messages.add(_ChatMsg(role: 'ai', text: errorMsg));
            } else {
              // Erro não-rede (API key, quota, etc.) — substitui ou adiciona bolha
              if (streamingMsgIdx >= 0 && streamingMsgIdx < _messages.length) {
                _messages[streamingMsgIdx] = _ChatMsg.withId(
                  id: _messages[streamingMsgIdx].id,
                  role: 'ai',
                  text: errorMsg,
                );
              } else {
                _lastAiIndex = _messages.length;
                _messages.add(_ChatMsg(role: 'ai', text: errorMsg));
              }
            }
          });
          _scrollDown(force: true);
        },
      );
    } on Exception catch (e) {
      // Captura exceções não tratadas (ex: TimeoutException, SocketException)
      if (!mounted || uiRequestGeneration != _aiUiRequestGeneration) return;
      _sendGuard = false;
      // Build 188: descarta notifier de streaming em exceção não tratada
      _streamingTextNotifier?.dispose();
      _streamingTextNotifier = null;
      final errStr = e.toString().toLowerCase();
      final isNetworkException =
          errStr.contains('socket') ||
          errStr.contains('timeout') ||
          errStr.contains('connection') ||
          errStr.contains('network') ||
          errStr.contains('unreachable');
      setState(() {
        _thinking = false;
        _isStreaming = false;
        _networkError = isNetworkException;
        _aiError = !isNetworkException;
        if (isNetworkException) {
          // Remove mensagem do usuário se não houve resposta
          if (_messages.isNotEmpty &&
              _messages.last.role == 'user' &&
              _messages.last.text == trimmed) {
            _messages.removeLast();
          }
        }
      });
    } finally {
      // Libera o guard após a resposta chegar (ou em erro)
      // Pequeno delay para absorver double-tap acidental
      Future.delayed(const Duration(milliseconds: 300), () {
        _sendGuard = false;
      });
    }
  }

  void _copyMsg(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.read<AppProvider>().t('copied')),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      ),
    );
  }

  /// Build 184 — Editar mensagem do usuário
  /// Remove todas as mensagens a partir do índice [msgIndex] (a mensagem editada
  /// e todas as respostas subsequentes), substitui pelo novo texto e re-dispara
  /// o stream como se o usuário tivesse enviado [newText] diretamente.
  ///
  /// Fix 2 Build 184: após removeRange() na lista visual, reconstrói o
  /// _aiHistory interno do AppProvider com APENAS as mensagens sobreviventes.
  /// Isso garante que o gateway (GeminiServiceV2) não envie turnos podados
  /// como contexto poluído — o histórico da API fica sincronizado com a UI.
  void _editUserMessage(int msgIndex, String newText, AppProvider p) {
    if (!mounted) return;
    // Cancela qualquer stream ativo
    p.cancelAiStream();

    // ── Fix 2: captura as msgs sobreviventes ANTES do setState ──────────────
    // Apenas mensagens anteriores ao índice editado são válidas como histórico.
    final survivingMsgs = msgIndex > 0
        ? _messages.sublist(0, msgIndex)
        : <_ChatMsg>[];

    // Reconstrói _aiHistory com apenas as mensagens que restaram na UI.
    // rebuildAiHistoryFromMessages() aceita [{role, content}] e limita a 10
    // entradas (5 pares) — gateway nunca receberá turnos podados.
    final historyPayload = survivingMsgs
        .where((m) => m.role == 'user' || m.role == 'ai')
        .map(
          (m) => {
            'role': m.role == 'ai' ? 'assistant' : 'user',
            'content': m.text,
          },
        )
        .toList();
    p.rebuildAiHistoryFromMessages(historyPayload);

    setState(() {
      // Remove mensagens a partir do índice editado (inclusive)
      if (msgIndex < _messages.length) {
        _messages.removeRange(msgIndex, _messages.length);
      }
      // Reseta estados de streaming
      _thinking = false;
      _isStreaming = false;
      _aiError = false;
      _networkError = false;
    });
    // Re-dispara o envio com o texto editado
    _send(newText, p);
  }

  void _clearChat() {
    _historyRestoreGeneration++;
    _restoredModeSelectionPending = false;
    final p = context.read<AppProvider>();
    // Salva sessão atual no histórico antes de limpar
    // (não-op se foi sessão restaurada sem novas mensagens)
    _saveCurrentSessionToHistory(p);
    // Build 107 — cancela streaming ativo antes de limpar
    p.cancelAiStream();
    _aiUiRequestGeneration++;

    // PHASE 4 — encerra também o canal local da bolha ativa.
    _streamingTextNotifier?.dispose();
    _streamingTextNotifier = null;

    setState(() {
      _messages
        ..clear()
        ..add(_ChatMsg(role: 'ai', text: _buildGreeting(p.userName, p.lang)));
      _aiError = false;
      _networkError = false;
      _userScrolledUp = false;
      _restoredSessionId = null;
      _activeSessionId =
          null; // BUILD 274: reset para próxima sessão gerar novo ID
      _hasNewMessageAfterRestore = false;
      _selectedHistorySessionId = null;
      _longResponse = true;
      _modeConfirmed = false;
      _modeReselectionPending = false;
      _restoredModeSelectionPending = false;
      // Build 107 FIX: reseta guards para desbloquear _send() após limpar
      _thinking = false;
      _isStreaming = false;
      _sendGuard = false;
    });
    _queryCtrl.clear();
    _focusNode.unfocus();
    p.clearAiHistory();
  }

  // ── BUILD 327+: Abort AI Stream ──────────────────────────────────────────
  // Chamado pelo botão de cancelar na InputBar enquanto thinking=true.
  // Interrompe imediatamente a StreamSubscription ativa no AppProvider,
  // reseta todos os flags de loading e devolve o foco ao campo de texto.
  void _cancelActiveStream() {
    final p = context.read<AppProvider>();
    p.cancelAiStream(); // cancela _aiStreamSub no AppProvider
    _aiUiRequestGeneration++;

    // PHASE 4 — fechamento local soberano:
    // remove imediatamente o listener da bolha ativa e impede que deltas
    // tardios continuem atualizando uma resposta já cancelada.
    _streamingTextNotifier?.dispose();
    _streamingTextNotifier = null;

    setState(() {
      _thinking = false;
      _isStreaming = false;
      _sendGuard = false;
    });
    // Devolve foco ao campo de texto — médico pode editar imediatamente
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  // ── Nuevo Chat — salva sessão atual e abre nova sessão limpa ─────────────
  // Diferente de _clearChat: NÃO deleta histórico. Salva em background e
  // cria nova sessão com ID diferente (timestamp) para consulta fresca.
  void _startNewChat({bool preserveConfirmedMode = false}) {
    _historyRestoreGeneration++;
    _restoredModeSelectionPending = false;
    final p = context.read<AppProvider>();
    // 1. Persiste sessão atual em background (dual-write Firestore + prefs)
    _saveCurrentSessionToHistory(p);
    // Build 107 — cancela streaming ativo antes de abrir novo chat
    p.cancelAiStream();
    _aiUiRequestGeneration++;

    // PHASE 4 — impede que deltas tardios alcancem a sessão nova.
    _streamingTextNotifier?.dispose();
    _streamingTextNotifier = null;

    // 2. Limpa UI e reseta flags de sessão — novo chat em branco
    setState(() {
      _messages
        ..clear()
        ..add(_ChatMsg(role: 'ai', text: _buildGreeting(p.userName, p.lang)));
      _aiError = false;
      _networkError = false;
      _userScrolledUp = false;
      _restoredSessionId = null;
      _activeSessionId =
          null; // BUILD 274: reset para nova sessão gerar novo ID
      _hasNewMessageAfterRestore = false;
      _selectedHistorySessionId = null;

      if (preserveConfirmedMode) {
        _modeConfirmed = true;
      } else {
        _longResponse = true;
        _modeConfirmed = false;
      }

      _modeReselectionPending = false;
      _restoredModeSelectionPending = false;
      _greetingDone = true;
      // Build 107 FIX: garante que _send() não fique bloqueado após novo chat
      _thinking = false;
      _isStreaming = false;
      _sendGuard = false;
    });
    _queryCtrl.clear();
    _focusNode.unfocus();
    p.clearAiHistory();
  }

  // ── Sheet de status da IA ────────────────────────────────────────────────
  void _openAiSettings() {
    final p = context.read<AppProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: p,
        child: AiStatusSheet(
          userEmail: p.userEmail,
          userName: p.userName,
          lang: p.lang,
          dark: p.darkMode,
          hasAi: p.hasAnyAi,
          geminiConnected: p.geminiConnected,
          geminiEmail: p.geminiEmail,
          geminiLoading: p.geminiLoading,
          keyLoading: p.aiKeyLoading,
        ),
      ),
    );
  }

  // BUILD 310 — Abre o painel VIP do Embaixador
  void _openAmbassadorPanel() {
    final p = context.read<AppProvider>();
    final user = p.currentUser;
    if (user == null || !user.isPartner) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AmbassadorPanel(
        user: user,
        lang: p.lang,
        messages: List.of(_messages),
        onSecondOpinion: (prompt) async {
          // Delegated via callback — streaming happens inside modal
          return p.sendAiMessage(
            prompt,
            onChunk: (_) {},
            onDone: (_) {},
            onError: (_) {},
          );
        },
        provider: p,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final dark = p.darkMode;
    final bp = MedBreakpoints.of(context);
    // ORDEM VISUAL 04 M1: canvas premium absoluto
    // Dark: grafite noturno ultra-profundo 0xFF121418
    // Light: branco gelo ultra-limpo 0xFFFCFDFD
    final palette = dark ? HomeV2Palette.dark : HomeV2Palette.light;
    final chatBg = palette.background;

    // Fix #5: detecta teclado via viewInsets (cobre Web Mobile onde focus events
    // podem não ser confiáveis). Propaga ao ValueNotifier para o FAB em main.dart.
    //
    // ORDEM 33 — MANDATO 1: CONGELAMENTO SÍNCRONO DO KEYBOARD_FIX NO PATH DE STREAMING.
    // DIAGNÓSTICO: durante streaming cada chunk dispara setState → build() →
    // releitura de viewInsets.bottom → se valor oscilou → addPostFrameCallback →
    // ValueNotifier update → ValueListenableBuilder rebuild → AnimatedPadding
    // reanimation em cascata a cada chunk → UI Thread sobrecarregada → chunks
    // perdidos / truncamento da resposta (bug da Sertralina cortada em "hasta 200 mg/").
    //
    // SOLUÇÃO — TRAVA SÍNCRONA:
    // Enquanto _isStreaming=true OU _thinking=true → CONGELAR o ValueNotifier
    // de teclado no valor que tinha ao início do envio. Zero mutações de padding
    // durante produção de texto. O sistema de insets do SO continua gerenciando
    // o espaço do teclado; só o ValueNotifier (que aciona AnimatedPadding) é
    // bloqueado. Após onDone() fechar o stream, a próxima build não-streaming
    // sincroniza o valor normalmente.
    final kbOpen = MediaQuery.of(context).viewInsets.bottom > 50;
    // ORDEM 33: bypass completo de mutação quando streaming ativo.
    // _isStreaming e _thinking são os sinais soberanos — ambos cobertos.
    final bool streamingActive = _isStreaming || _thinking;
    if (AiScreen.chatKeyboardOpen.value != kbOpen && !streamingActive) {
      // Schedula fora do build para evitar setState-during-build.
      // NUNCA executa enquanto streamingActive=true → padding congelado.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => AiScreen.chatKeyboardOpen.value = kbOpen,
      );
    }

    // No desktop: centraliza o chat com largura máxima elegante
    final double? chatMaxWidth = bp.isDesktop ? 960 : null;

    // SUPER ORDEM MASTER 15 M2: Estado de conexão da IA com verificação ESTRITA.
    // isConnected = estado geral para lógica interna (ex: forceDisconnectedLabel)
    // isMplusConnected = exibição do M+ verde — SOMENTE quando o usuário tem
    //   autenticação real de IA: geminiConnected (OAuth Google) OU chave OpenAI própria.
    //   NÃO acende para GeminiService.hasApiKey (chave do servidor compartilhada).
    final bool isConnected = p.geminiConnected || p.hasAnyAi;
    // M+ Verde apenas com sessão de IA autêntica do usuário
    // geminiConnected = OAuth Google real | openAiKey.isNotEmpty = chave pessoal
    // Exclui GeminiService.hasApiKey (chave servidor compartilhada) que fazia M+ acender falsamente
    final bool isMplusConnected = p.geminiConnected || p.openAiKey.isNotEmpty;
    // Mostra card de desconexão quando IA não está conectada E usuário
    // ainda não enviou nenhuma mensagem (só greeting automática existe)
    final bool showDisconnectCard =
        !isConnected && _messages.where((m) => m.role == 'user').isEmpty;

    // AI-VIS-B.2.5-R1 — a presença de pergunta real controla
    // apenas a projeção visual da saudação.
    final bool hasConversation = _messages.any((m) => m.role == 'user');

    // BUILD 275: para usuários não-admin/não-master sem conexão, forçar badge
    // 'Desconectado' (vermelho) em vez de 'Conectar IA' — sinaliza que chat está bloqueado.
    // BUILD 339-UI-DEBUGGER: força o mesmo fluxo de conexão para todos os usuários.
    // Admin e Master também exibem GoogleAuthBarrierCard + DisconnectedInputLock para QA.
    final bool forceDisconnectedLabel = !p.geminiConnected;

    Widget chatList = ListView.builder(
      // ORDEM 54 M2: ValueKey(_chatEpoch) — quando _chatEpoch é incrementado
      // pelo context timeout, o Flutter descarta a árvore de widgets antiga
      // e reconstrói do zero (zero Stale UI no Flutter Web).
      key: ValueKey(_chatEpoch),
      controller: _scrollCtrl,
      // BUILD 283 ORDEM 10.5: mobile padding 12→16 para respiração lateral
      padding: EdgeInsets.fromLTRB(
        bp.isDesktop ? 24 : 6,
        12,
        bp.isDesktop ? 24 : 6,
        8,
      ),
      // Build 145 — cacheExtent aumentado 2000 → 2500:
      // Mantém ~3 telas extras de cards pré-renderizados acima e abaixo
      // da viewport. Elimina o re-layout de MarkdownBody que causava o
      // "scroll stutter" ao subir no histórico durante o streaming.
      // Impacto de memória negligenciável: ~5 bolhas fora da viewport.
      scrollCacheExtent: const ScrollCacheExtent.pixels(2500),
      physics: const ClampingScrollPhysics(),
      // Fecha o teclado ao arrastar o chat (comportamento nativo mobile)
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      // Build 188: isolamento de repaint e keep-alive explícitos
      addRepaintBoundaries: true,
      addAutomaticKeepAlives: true,
      itemCount: _messages.length + (_thinking ? 1 : 0) + 1, // +1 sentinela
      itemBuilder: (context, i) {
        // Sentinela invisível — âncora para Scrollable.ensureVisible
        if (i == _messages.length + (_thinking ? 1 : 0)) {
          return SizedBox(key: _bottomKey, height: 1);
        }
        if (_thinking && i == _messages.length) {
          // Indicador premium desacoplado enquanto a IA prepara a resposta.
          // RepaintBoundary isolates the animated CustomPainter so it does NOT
          // trigger full-list repaints on every animation frame.
          return RepaintBoundary(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 52, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AiResponseIdentityHeader(
                    dark: dark,
                    isEs: p.lang.trim().toLowerCase().startsWith('es'),
                    isStreaming: true,
                  ),
                  const SizedBox(height: 8),
                  AiShimmerDots(dark: dark),
                ],
              ),
            ),
          );
        }
        final msg = _messages[i];
        if (msg.role == 'user') {
          // MEDCASES_IA_PLANTAO_BUTTON_USER_BUBBLE_COMPACT_V1_B_R0
          // Somente a projeção visual pode ser compactada. msg.text continua
          // canônico para histórico, thread, dedup, case-anchor e provider.
          final displayCandidate = msg.userDisplayText?.trim() ?? '';
          final policyVisibleText = UserMessageDisplayPolicy.visibleText(
            msg.text,
          );
          final userVisibleText = displayCandidate.isNotEmpty
              ? displayCandidate
              : policyVisibleText;
          final hasAutomaticVisibleProjection =
              displayCandidate.isNotEmpty ||
              policyVisibleText.trim() != msg.text.trim();

          // Questions button is a continuation trigger, not clinical content.
          // Keep canonical prompt/history/provenance, but do not render a user
          // bubble before the generated questions.
          final normalizedDisplayCandidate =
              displayCandidate.toLowerCase().replaceAll('-', ' ');
          final isQuestionsButtonProjection =
              normalizedDisplayCandidate == 'preguntas clave' ||
                  normalizedDisplayCandidate == 'preguntas importantes' ||
                  normalizedDisplayCandidate == 'perguntas chave' ||
                  normalizedDisplayCandidate == 'perguntas importantes';
          if (!_longResponse && isQuestionsButtonProjection) {
            return SizedBox.shrink(
              key: ValueKey(
                'msg_${msg.id}_plantao_questions_button_hidden',
              ),
            );
          }

          // Plantão final presentation: user turns remain canonical in the
          // message model/history/provider pipeline but are not repeated above
          // the answer. This includes automatic continuation triggers such as
          // "Conductas y dosis"; Estudo keeps normal user-message rendering.
          if (!_longResponse && hasAutomaticVisibleProjection) {
            return SizedBox.shrink(
              key: ValueKey(
                'msg_${msg.id}_plantao_automatic_user_hidden',
              ),
            );
          }

          if (!_longResponse && !hasAutomaticVisibleProjection) {
            return SizedBox.shrink(
              key: ValueKey('msg_${msg.id}_plantao_direct_user_hidden'),
            );
          }

          // Build 170: passa callbacks de cópia e edição para o balão
          final msgIndex = i; // captura o índice para edição
          return RepaintBoundary(
            child: KeyedSubtree(
              key: ValueKey('msg_${msg.id}'),
              child: UserBubble(
                text: userVisibleText,
                editText: msg.text,
                dark: dark,
                onCopy: () => _copyMsg(userVisibleText),
                onEdit: (newText) => _editUserMessage(msgIndex, newText, p),
                // Fix 5: ícone de edição desabilitado durante streaming
                isAiStreaming: _isStreaming || _thinking,
                cleanPlantaoPresentation: !_longResponse,
              ),
            ),
          );
        }
        if (_isOpeningHomeGreeting(i, msg)) {
          // Greeting belongs only to the empty IA state.
          // Once a real conversation exists, keep the canonical greeting
          // message but remove only its visual projection from the timeline.
          if (hasConversation) {
            return SizedBox.shrink(
              key: ValueKey('msg_${msg.id}_greeting_hidden_after_start'),
            );
          }

          return RepaintBoundary(
            child: KeyedSubtree(
              key: ValueKey('msg_${msg.id}'),
              child: _AiHomeGreeting(
                dark: dark,
                lang: p.lang,
                text: msg.text,
                compact: false,
                animate: false,
              ),
            ),
          );
        }

        // ── AI message — detectar fármaco en texto ──────────────────
        final isActiveStreamingBubble = _isStreaming && i == _lastAiIndex;

        // ── BUILD 244B SAFE_CARD_GUARD: detectar safe-card por prefixo canônico ──
        // BUILD 244: usa AppProvider.kSafeCardMarker* (prefixo estável) em vez
        // de text-matching frágil em .toLowerCase(). Mantém legado para mensagens
        // salvas no histórico com texto antigo.
        // Safe-cards NÃO renderizam: EvidenceBox, ActionButtons, ExternalToolLink,
        // PlantaoRenderer. Log limitado a 1x por messageId — sem spam em rebuilds.
        final bool isSafeCard = MessageRenderPolicy.isSafeCard(msg.text);
        if (kDebugMode && isSafeCard && !_loggedSafeCardIds.contains(msg.id)) {
          _loggedSafeCardIds.add(msg.id);
          debugPrint('[SAFE_CARD_GUARD] messageId=${msg.id} isSafeCard=true');
        }

        // Referências clínicas: associa a resposta à pergunta anterior.
        // Safe-cards e bolha ainda em streaming não recebem o bloco.
        String precedingUserText = '';
        bool precedingUserWasAction = false;
        for (var previous = i - 1; previous >= 0; previous--) {
          if (_messages[previous].role == 'user') {
            precedingUserText = _messages[previous].text;
            precedingUserWasAction =
                (_messages[previous].userDisplayText?.trim().isNotEmpty ??
                false);
            break;
          }
        }
        final clinicalReference = isSafeCard || isActiveStreamingBubble
            ? null
            : ClinicalReferenceResolver.resolve(
                userText: precedingUserText,
                aiText: msg.text,
                lang: p.lang,
              );

        // AI-RECONSTRUCTION-R18.6AA-R1F-R3:
        // Um único proprietário resolve texto e continuação pedagógica.
        // Gemini Free, GPT e Gemini pago convergem nesta fronteira.
        final studyContinuation = StudyContinuationResolver.resolve(
          rawText: msg.text,
          isStudyMode: _longResponse,
          isSafeCard: isSafeCard,
          isStreaming: isActiveStreamingBubble,
          lastUserMessage: precedingUserText,
          languageCode: p.lang,
          chatHistory: _messages
              .map((message) => message.text)
              .toList(growable: false),
          lastSentPrompt: _lastSentStudyPrompt,
        );

        final String nextActionPrompt = studyContinuation.question;

        final String cleanDisplayText = studyContinuation.displayText;

        final bool useGuardiaPresentation = !_longResponse && !isSafeCard;

        final bool hasStudyContinuation = studyContinuation.hasContinuation;

        final studyContinuationVisualIdentity = '$_scrollGeneration:${msg.id}';

        final bool showStudyContinuation =
            hasStudyContinuation &&
            !isActiveStreamingBubble &&
            i == _lastAiIndex &&
            _studyContinuationVisualReadyIdentity ==
                studyContinuationVisualIdentity;

        // ── ORDEM 56 M1: RENDER UNIFICADO ────────────────────────────────
        // SUPER ORDEM 56: PlantatoPipeline, _PlantaoRenderer e _PlantaoFallbackCard
        // foram descontinuados. 100% das bolhas AI — 1º turno, follow-ups e
        // histórico restaurado — fluem diretamente para AiBubble (MarkdownBody).
        // Ultra-Plantão Build 260: o design (🟥/💊/⛔/📌 + bullets) é gerado
        // nativamente pelos prompts. Não há parsing nem slicing necessário.
        // Elimina duplicação de cards pós-refresh e alivia o rebuild do histórico.
        if (kDebugMode) {
          debugPrint(
            '[RENDER_56] msgId=${msg.id} → AiBubble unificado '
            'continuation=${studyContinuation.source.name}',
          );
        }

        // BUILD 276: Fade-in wrapper — applied only to the freshly committed
        // AI bubble (msg.id == _fadingInMsgId). Starts at opacity 0 and
        // animates to 1 over 380ms. After 450ms _fadingInMsgId is cleared
        // via a delayed setState, removing the AnimatedOpacity overhead.
        final bool isFadingIn =
            (_longResponse || isSafeCard) &&
            _fadingInMsgId != null &&
            msg.id == _fadingInMsgId;
        Widget bubbleContent = RepaintBoundary(
          child: KeyedSubtree(
            key: ValueKey('msg_${msg.id}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_longResponse || isActiveStreamingBubble) ...[
                  _AiResponseIdentityHeader(
                    dark: dark,
                    isEs: p.lang.trim().toLowerCase().startsWith('es'),
                    isStreaming: isActiveStreamingBubble,
                  ),
                  const SizedBox(height: 10),
                ],
                // ── Superfície estável: Guardia próprio; Estudo/safe-card em AiBubble ──
                // BUILD 300: usa cleanDisplayText — tag [NEXT_ACTION_PROMPT]
                // removida do texto visível. msg.text permanece intacto no modelo.
                if (useGuardiaPresentation)
                  GuardiaClinicalResponseView(
                    key: ValueKey('guardia_${msg.id}'),
                    rawText: cleanDisplayText,
                    output: msg.clinicalOutput,
                    dark: dark,
                    languageCode: p.lang,
                    userText: precedingUserText,
                    userInitiatedByAction: precedingUserWasAction,
                    onCopy: () => _copyMsg(cleanDisplayText),
                    ttsPlaying: _ttsPlayingIndex == i,
                    ttsReady: _ttsReady,
                    onTts: _ttsReady
                        ? () => _toggleTts(i, cleanDisplayText, p.lang)
                        : null,
                    isStreaming: isActiveStreamingBubble,
                    streamingTextNotifier: isActiveStreamingBubble
                        ? _streamingTextNotifier
                        : null,
                    scrollGeneration: _scrollGeneration,
                    onTextRevealed: _onBlockRevealed,
                  )
                else
                  AiBubble(
                    key: ValueKey('ai_${msg.id}'),
                    text: cleanDisplayText,
                    dark: dark,
                    animate: i == _lastAiIndex,
                    lang: p.lang,
                    onCopy: () => _copyMsg(cleanDisplayText),
                    ttsPlaying: _ttsPlayingIndex == i,
                    ttsReady: _ttsReady,
                    onTts: _ttsReady
                        ? () => _toggleTts(i, cleanDisplayText, p.lang)
                        : null,
                    scrollGeneration: _scrollGeneration,
                    onBlockRevealed: _onBlockRevealed,
                    onVisualComplete: i == _lastAiIndex
                        ? (generation) => _onStudyContinuationVisualComplete(
                            msg.id,
                            generation,
                          )
                        : null,
                    // Mostra cursor ▌ apenas na bolha que está sendo preenchida
                    isStreaming: isActiveStreamingBubble,
                    // Build 188: passa o notifier APENAS para a bolha ativa —
                    // chunks chegam diretamente nela sem reconstruir a tela.
                    streamingTextNotifier: isActiveStreamingBubble
                        ? _streamingTextNotifier
                        : null,
                    // Build 184 — Auto-Submit: chip tap → direto para _send().
                    // Remove o pre-fill; o médico toca o chip e a resposta é enviada
                    // imediatamente sem precisar clicar no botão de envio.
                    onChipTap: _isStreaming
                        ? null
                        : (chipText) {
                            // Build 187: Detallar... uses sentinel '__DETAIL__:<question>'
                            // → focus TextField + prefill context prefix (no auto-send)
                            if (chipText.startsWith('__DETAIL__:')) {
                              final rawQ = chipText
                                  .substring('__DETAIL__:'.length)
                                  .trim();
                              // Build context prefix from the question text
                              final prefix = rawQ.isNotEmpty ? '$rawQ: ' : '';
                              _queryCtrl.text = prefix;
                              // Move cursor to end of pre-filled text
                              _queryCtrl.selection = TextSelection.fromPosition(
                                TextPosition(offset: _queryCtrl.text.length),
                              );
                              _focusNode.requestFocus();
                              return;
                            }
                            // Clean up the text for auto-sending
                            String sendText = chipText.trim();
                            if (sendText.startsWith('📌')) {
                              sendText = sendText.substring('📌'.length).trim();
                            }
                            if (sendText.isEmpty) return;
                            // AUTO-SUBMIT: scroll + send immediately — no prefill
                            _userScrolledUp = false;
                            _scrollDown(force: true);
                            _sendDebounced(
                              sendText,
                              context.read<AppProvider>(),
                            );
                          },
                  ),

                // ── PHASE 4: Structured Clinical Output tipado ─────────────
                // Renderizado somente após associação fail-closed ao texto
                // definitivo. Nunca aparece durante streaming, em safe-cards
                // ou em respostas legadas sem structuredOutput.
                if (_longResponse &&
                    msg.clinicalOutput != null &&
                    !isActiveStreamingBubble &&
                    !isSafeCard) ...[
                  SizedBox(height: _longResponse ? 12 : 6),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: _longResponse ? 12 : 8,
                    ),
                    child: StructuredClinicalOutputView(
                      key: ValueKey('clinical_output_${msg.id}'),
                      output: msg.clinicalOutput!,
                      isPlantaoMode: !_longResponse,
                      languageCode: p.lang,
                    ),
                  ),
                ],

                // ── Build 192 / BUILD 232: ActionButtonsRow + EXT_TOOL cache ───
                // Aparece apenas na última bolha AI sem streaming.
                // BUILD 238 SAFE_CARD_GUARD: safe-cards NÃO mostram ActionButtons
                // nem ExternalToolLink — evita botões inválidos em respostas de fallback.
                // BUILD 232: ExternalToolLink é resolvido aqui (no pai) com cache.
                // Assim _ActionButtonsRow.build() nunca chama ExternalToolLinkEngine
                // mais de 1 vez por (messageId, textHash) independente de rebuilds.
                // ORDEM 29 V2 — SUBORDINAÇÃO TEMPORAL (MÉTODO BRUNO):
                // !_isStreaming é o sinal soberano. Enquanto stream ativo, este bloco
                // NUNCA executa → sem injeção de botões durante produção de texto.
                // Só após onDone fechar o stream E _lastAiIndex ser sincronizado
                // (ORDEM 29 fix) é que ExternalToolLinkEngine.build() é chamado
                // com metadados completos do response final. Sem race condition.
                if (i == _lastAiIndex &&
                    !_isStreaming &&
                    _messages.length >= 2 &&
                    !isSafeCard)
                  Builder(
                    builder: (_) {
                      final lastUser = _messages
                          .lastWhere(
                            (m) => m.role == 'user',
                            orElse: () => _ChatMsg(role: 'user', text: ''),
                          )
                          .text;
                      // ── MICRO-BUILD 462E-A.5.3.7.3.2: Pure renderer — zero engine calls ──
                      // ExternalToolLinkEngine.build() is STRICTLY FORBIDDEN here.
                      // The tool resolution was computed exactly once inside the canonical
                      // finalizer (sendAiMessage → chunk_isDone → EXT_TOOL_GATE) and stored
                      // in AppProvider._lastCompletedToolLink.
                      //
                      // Re-rendering this widget 100 times produces:
                      //   • ZERO ExternalToolLinkEngine invocations
                      //   • ZERO [EXT_TOOL_GATE] log emissions
                      //   • ZERO state changes
                      //
                      // The _extToolCache is kept for reading historical sessions loaded from
                      // Firestore (which do not go through sendAiMessage). It is never written
                      // during the current live request lifecycle.
                      final extKey = '${msg.id}:${msg.text.hashCode}';
                      // ── MICRO-BUILD 462E-A.5.3.7.3.2.1: Request-correlated read ──
                      // Read the pre-computed resolution from the provider map.
                      // The UI asserts that the payload's requestId matches the
                      // active request before rendering a tool calculator.
                      // Mismatch (stale async write from prior request) → null → no card.
                      final completedResolution = p.activeCompletedResolution;
                      final ExternalToolLink? resolvedLink =
                          _extToolCache.containsKey(extKey)
                          ? _extToolCache[extKey]
                          : (completedResolution != null &&
                                    completedResolution.isAllowed
                                ? completedResolution.link
                                : null);
                      if (kDebugMode && showStudyContinuation) {
                        debugPrint(
                          '[STUDY_CONTINUATION][RESOLVED] '
                          'msgId=${msg.id} '
                          'source=${studyContinuation.source.name} '
                          'promptChars=${nextActionPrompt.length}',
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showStudyContinuation)
                            StudyContinuationButton(
                              question: nextActionPrompt.trim(),
                              dark: dark,
                              onTap: () {
                                if (_isStreaming) return;

                                final prompt = nextActionPrompt.trim();

                                if (prompt.isEmpty) return;

                                _lastSentStudyPrompt = prompt;
                                _userScrolledUp = false;
                                _scrollDown(force: true);
                                _sendDebounced(
                                  prompt,
                                  context.read<AppProvider>(),
                                  fromButton: true,
                                );
                              },
                            ),
                          ActionButtonsRow(
                            lastUserMessage: lastUser,
                            lastAiResponse: cleanDisplayText,
                            isPlantaoMode: !_longResponse,
                            lang: p.lang,
                            dark: dark,
                            chatHistory: _messages.map((m) => m.text).toList(),
                            cachedLink: resolvedLink,
                            suppressAiAction: _longResponse,
                            studyNextPrompt: '',
                            studyNextLabel: '',
                            lastSentStudyPrompt: _lastSentStudyPrompt,
                            onActionTap:
                                (
                                  prompt, {
                                  required String visibleLabel,
                                  required bool isStudyNext,
                                  required PlantaoContinuationType
                                  continuationType,
                                  required List<PlantaoSection>
                                  requestedSections,
                                }) {
                                  if (_isStreaming) return;
                                  _userScrolledUp = false;
                                  _scrollDown(force: true);
                                  // BUILD 308 [FISIOP_DEDUP]: Registra o prompt do botão azul
                                  // de Estudo para detecção de loop de Fisiopatologia no turno seguinte.
                                  if (isStudyNext)
                                    _lastSentStudyPrompt = prompt;
                                  // PHASE 3C: preserve typed continuation metadata before
                                  // the text reaches AppProvider. The productive response
                                  // still uses the legacy path unchanged.
                                  _sendDebounced(
                                    prompt,
                                    context.read<AppProvider>(),
                                    fromButton: true,
                                    userDisplayText: visibleLabel,
                                    continuationType: continuationType,
                                    requestedSections: requestedSections,
                                  );
                                },
                          ),
                        ],
                      );
                    },
                  ),
                // ── Referência clínica textual e colapsável ───────────────
                // Um fármaco usa sua ficha específica; polifarmácia usa
                // referências do protocolo temático; sem match usa livros-base.
                if (clinicalReference != null)
                  Builder(
                    builder: (_) {
                      if (kDebugMode) {
                        final evKey = '${msg.id}_${msg.text.hashCode}';
                        if (!_loggedEvidenceIds.contains(evKey)) {
                          _loggedEvidenceIds.add(evKey);
                          debugPrint(
                            '[REFERENCE_RESOLVER] messageId=${msg.id} '
                            'source=${clinicalReference.sourceType} '
                            'protocol=${clinicalReference.protocolId ?? "none"} '
                            'drugs=${clinicalReference.drugKeys.length}',
                          );
                        }
                      }
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(12, 20, 12, 18),
                        child: CollapsibleClinicalReferenceBlock(
                          lines: clinicalReference.lines,
                          dark: dark,
                          lang: p.lang,
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
        // BUILD 276: wrap new bubble in TweenAnimationBuilder for smooth
        // fade-in from 0→1 (380ms easeOut). AnimatedOpacity cannot tween
        // from 0→1 on first build (it starts at whatever opacity it had
        // before). TweenAnimationBuilder always animates from `begin` to
        // `end` the first time it renders, guaranteeing the fade effect.
        if (isFadingIn) {
          return TweenAnimationBuilder<double>(
            key: ValueKey('fadein_${msg.id}'),
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOut,
            builder: (_, opacity, child) =>
                Opacity(opacity: opacity, child: child),
            child: bubbleContent,
          );
        }
        return bubbleContent;
      },
    );

    // Build 145 — NotificationListener de scroll-up com prioridade imediata:
    //
    // PROBLEMA RAIZ DO STUTTER:
    //   O _onScroll listener (via _scrollCtrl.addListener) é chamado DEPOIS
    //   que o frame de animação já foi agendado. Na janela entre o início
    //   do gesto de scroll-up e a atualização de _userScrolledUp, _scrollDown()
    //   ainda achava que o usuário estava no fundo e acionava animateTo().
    //   O resultado: o ListView subia (gesto do usuário) E descia (auto-scroll)
    //   no mesmo frame → "salto" visual / stutter.
    //
    // SOLUÇÃO:
    //   NotificationListener<ScrollStartNotification> captura o INÍCIO do gesto
    //   de scroll do usuário no Flutter dispatch cycle, ANTES de qualquer
    //   animação ser calculada. Ao detectar um ScrollStartNotification com
    //   dragDetails != null (gesto manual, não animação programática),
    //   setamos _userScrolledUp = true IMEDIATAMENTE — bloqueando o próximo
    //   _scrollDown() antes que ele dispare.
    //
    //   ScrollEndNotification: quando o usuário solta o dedo, verificamos
    //   se voltou ao fundo — se sim, re-ativa o auto-scroll.
    //
    // COMPATIBILIDADE: não afeta o comportamento de outros scrolláveis aninhados
    // (sugestões, histórico) pois usam ScrollControllers diferentes.
    chatList = NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // Só processa notificações do ScrollController principal do chat
        if (notification.metrics.axisDirection != AxisDirection.down)
          return false;

        if (notification is ScrollStartNotification) {
          // Gesto manual do usuário (dragDetails != null) → bloqueia auto-scroll
          if (notification.dragDetails != null && !_userScrolledUp) {
            _userScrolledUp = true;
            // O gesto físico é o único evento que suspende o auto-follow.
            // Atualiza o indicador fora do dispatch de scroll.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() {});
            });
          }
        } else if (notification is ScrollEndNotification) {
          // Usuário soltou o dedo → verifica posição para re-ativar auto-scroll
          if (_scrollCtrl.hasClients) {
            final pos = _scrollCtrl.position;
            final nearBottom =
                pos.pixels >= pos.maxScrollExtent - 100; // BUILD 308: 80→100px
            if (nearBottom && _userScrolledUp) {
              _userScrolledUp = false;
              // PHASE3K-C5A-R9A: ScrollEndNotification pode ser emitida
              // durante performLayout. A atualização visual deve ocorrer
              // somente depois do frame atual.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() {});
              });
            }
          }
        }
        return false; // não consume a notificação — deixa o scroll funcionar
      },
      child: chatList,
    );

    // No desktop: envolve o chat em coluna centralizada com max-width
    if (chatMaxWidth != null) {
      chatList = Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: chatMaxWidth),
          child: chatList,
        ),
      );
    }

    // BUILD 457-FRENTE2: SelectionArea envolve chatList inteiro — habilita seleção
    // nativa de qualquer trecho de texto no chat (médico pode copiar dose/conduta
    // parcial com long-press). Posicionado APÓS o wrap de desktop para que
    // ConstrainedBox e NotificationListener já estejam em ordem.
    // MarkdownBody permanece com selectable: false (SelectionArea é a âncora única
    // de seleção — evitar conflito de dois sistemas de seleção sobrepostos).
    chatList = SelectionArea(child: chatList);

    // Desktop: sem shell AppBar → mostra WaHeader próprio.
    // Mobile/tablet: mostra mini barra de ações inline (histórico + limpar)
    // para garantir acesso MESMO com teclado aberto (shell AppBar não está visível).
    final showWaHeader = bp.isDesktop;
    final showMobileActions = !bp.isDesktop;

    // Fecha teclado ao tocar fora do input (área do chat)
    final chatArea = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => _focusNode.unfocus(),
      child: Container(
        color: chatBg,
        child: Stack(
          children: [
            // ORDEM 47 M1: blur da timeline quando usuário não autenticado.
            // ImageFilter.blur oculta o conteúdo da timeline visualmente,
            // reforçando que a IA está bloqueada até a conexão Google ser feita.
            if (forceDisconnectedLabel)
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
                child: IgnorePointer(child: chatList),
              )
            else
              chatList,
            // ORDEM 47 M1: Auth barrier SOBERANA — baseada EXCLUSIVAMENTE em
            // forceDisconnectedLabel (= !p.geminiConnected).
            // Não depende mais de _messages.any(). O overlay cobre TODA a timeline
            // independente de haver mensagens — proteção financeira de API absoluta.
            if (forceDisconnectedLabel)
              GoogleAuthBarrierCard(
                dark: dark,
                lang: p.lang,
                onConnect: _openAiSettings,
              )
            // Card "IA Desconectada" — sobreposto quando IA não está conectada
            // e o médico ainda não enviou nenhuma mensagem (usuário privilegiado)
            else if (showDisconnectCard)
              EmptyChat(
                dark: dark,
                lang: p.lang,
                isConnected: false,
                onConnectApi: _openAiSettings,
              ),

            // ORDEM 36: mode toggle movido para posição fixa acima do InputBar

            // ── Build 116: Smart Scroll Indicator ─────────────────────────
            // Aparece quando o usuário subiu para revisar o histórico E a IA
            // está gerando uma resposta. Indica que o auto-scroll está pausado
            // e oferece botão para retomar acompanhamento do stream.
            if (_userScrolledUp && _isStreaming)
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _userScrolledUp = false);
                      _scrollDown(force: true);
                    },
                    child: AnimatedOpacity(
                      opacity: 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: dark
                              ? const Color(0xFF00E5FF).withOpacity(0.15)
                              : const Color(0xFF008CA4).withOpacity(0.12),
                          border: Border.all(
                            color: dark
                                ? const Color(0xFF00E5FF).withOpacity(0.45)
                                : const Color(0xFF008CA4).withOpacity(0.35),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(
                                dark ? 0.35 : 0.10,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.arrow_downward_rounded,
                              size: 14,
                              color: dark
                                  ? const Color(0xFF00E5FF)
                                  : const Color(0xFF008CA4),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              p.lang == 'es'
                                  ? 'IA escribiendo — toca para seguir'
                                  : 'IA respondendo — toque para acompanhar',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: dark
                                    ? const Color(0xFF00E5FF)
                                    : const Color(0xFF008CA4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return Column(
      children: [
        // ── Header fino estilo WhatsApp (desktop only) ───────────────────────
        if (showWaHeader)
          WaHeader(
            onSettings: _openAiSettings,
            onHistory: () => _openHistory(p),
            onNewChat: () => _startNewChat(),
            historyCount: _chatHistory.length,
            lang: p.lang,
            modeConfirmed: _modeConfirmed,
            studyMode: _longResponse,
            onModeTap: _openResponseModeSelector,
            isConnected:
                isMplusConnected, // SUPER ORDEM MASTER 15 M2: M+ verde estrito — apenas sessão de IA real
            // BUILD 310: Ambassador golden button — Apple Safe
            isPartner: p.currentUser?.isPartner ?? false,
            partnerTitle: p.currentUser?.partnerTitle ?? '',
            onAmbassador: (p.currentUser?.isPartner ?? false)
                ? _openAmbassadorPanel
                : null,
          ),

        // ── Mini barra de ações mobile — SEMPRE visível mesmo com teclado aberto
        // Histórico + Limpar ficam acessíveis sem depender do scroll-reveal AppBar.
        if (showMobileActions)
          MobileAiActionBar(
            dark: dark,
            lang: p.lang,
            historyCount: _chatHistory.length,
            hasMessages: _messages.where((m) => m.role == 'user').isNotEmpty,
            hasRealAi: p.hasAnyAi || p.geminiConnected,
            keyLoading: p.aiKeyLoading || p.geminiLoading,
            modeConfirmed: _modeConfirmed,
            studyMode: _longResponse,
            onModeTap: _openResponseModeSelector,
            onHistory: () => _openHistory(p),
            onClear: _clearChat,
            onSettings: _openAiSettings,
            onNewChat: () => _startNewChat(),
            forceDisconnectedLabel: forceDisconnectedLabel, // BUILD 275
            isConnected:
                isMplusConnected, // SUPER ORDEM MASTER 15 M2: M+ verde estrito — apenas sessão de IA real
            // BUILD 310: Ambassador golden button — invisible to non-partners
            isPartner: p.currentUser?.isPartner ?? false,
            partnerTitle: p.currentUser?.partnerTitle ?? '',
            onAmbassador: (p.currentUser?.isPartner ?? false)
                ? _openAmbassadorPanel
                : null,
          ),

        // ── Banner de erro de chave ───────────────────────────────────────────
        if (_aiError)
          AiErrorBanner(
            lang: p.lang,
            isGeminiError: p.geminiConnected,
            onFix: _openAiSettings,
          ),

        // ── Banner de erro de rede/conexão ───────────────────────────────────
        if (_networkError)
          InlineConnectionBanner(
            lang: p.lang,
            isAiError: true,
            onRetry: () {
              final last = _messages.lastWhere(
                (m) => m.role == 'user',
                orElse: () => _ChatMsg(role: '', text: ''),
              );
              if (last.text.isNotEmpty) {
                _send(last.text, p);
              } else {
                setState(() => _networkError = false);
              }
            },
          ),

        // ── Área de chat ─────────────────────────────────────────────────────
        Expanded(child: chatArea),

        // ── SUPER ORDEM MASTER 15 M1: CANVAS PLANO — painel inferior MESMO chatBg ──
        // ColoredBox garante que mode-toggle + sugestões + InputBar compartilhem
        // o MESMO fundo que o chatArea acima. Elimina a divisão de dois tons de preto
        // (grafite do chat vs preto do shell IndexedStack herdado pelo painel inferior).
        ColoredBox(
          color: chatBg,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // AI-VIS-B.2.6-R1 — escolha inicial simples.
              //
              // Depois da confirmação, o seletor deixa a área do chat e o modo
              // passa a ser exibido na topbar. Tocar na topbar reabre este bloco.
              if (!forceDisconnectedLabel && !_modeConfirmed)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 0),
                  child: ResponseModeToggle(
                    value: _longResponse,
                    dark: dark,
                    lang: p.lang,
                    onChanged: _commitResponseMode,
                  ),
                ),
              const SizedBox(height: 25), // 25px gap antes do TextField
              // ── BUILD 277: INPUT LOCKOUT for disconnected non-privileged users
              if (forceDisconnectedLabel)
                DisconnectedInputLock(
                  dark: dark,
                  lang: p.lang,
                  onConnect: _openAiSettings,
                ),

              // ── Barra de input — centralizada no desktop ───────────────────
              // Build 158.3: Padding inferior DINÂMICO sincronizado com scrollingDown.
              if (!forceDisconnectedLabel)
                chatMaxWidth != null
                    ? Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: chatMaxWidth),
                          child: PromptComposer(
                            ctrl: _queryCtrl,
                            focusNode: _focusNode,
                            dark: dark,
                            hasFocus: _hasFocus,
                            // BUILD 327+: thinking=true enquanto IA processa (thinking OU streaming)
                            // garante que o botão de abort esteja visível em ambas as fases.
                            thinking: _thinking || _isStreaming,
                            onSend: () => _sendDebounced(
                              _queryCtrl.text,
                              context.read<AppProvider>(),
                            ),
                            onCancel:
                                _cancelActiveStream, // BUILD 327+: abort stream
                            hint: p.t('ai_placeholder'),
                            onVoice: _toggleStt,
                            sttListening: _sttListening,
                            sttSoundLevel: _sttSoundLevel,
                            lang: p.lang,
                            // ADENDO SEGURANÇA: Factor 1 — trava interface quando desconectado
                            isConnected: isMplusConnected,
                            // UX INTERCEPT: toque no campo bloqueado abre modal de conexão
                            onConnectTap: _openAiSettings,
                          ),
                        ),
                      )
                    // Fix #1: padding inferior dinâmico sincronizado com teclado + Dock.
                    // Teclado aberto → gruda na borda superior do teclado (0px extra).
                    // Teclado fechado → eleva acima do Dock flutuante com bottomPadding nativo.
                    // Bloqueio de streaming: AnimatedPadding congelado durante _isStreaming.
                    : ValueListenableBuilder<bool>(
                        valueListenable: AiScreen.chatKeyboardOpen,
                        builder: (_, kbOpenVal, __) => ValueListenableBuilder<bool>(
                          valueListenable: AiScreen.scrollingDown,
                          builder: (_, scrollingDown, child) {
                            final mq = MediaQuery.of(context);
                            final nativeBottom = mq.padding.bottom;
                            final keyboardH = mq.viewInsets.bottom;
                            // Com teclado → sem gap extra (o sistema já reposiciona o layout).
                            // Sem teclado, sem scroll → eleva 95px acima do Dock + safe area.
                            // BUILD 332 Fix 4: Remove scrollingDown from dynamicBottom.
                            // A barra de input permanece fixa — não se oculta com scroll.
                            final dynamicBottom = kbOpenVal
                                ? 0.0
                                : (nativeBottom + 95.0).clamp(95.0, 160.0);
                            // Congelamento durante streaming: evita AnimatedPadding
                            // rebuildando a cada chunk e sobrecarregando o UI Thread.
                            final _ =
                                keyboardH; // referenciado para suprimir warning
                            return AnimatedPadding(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              padding: EdgeInsets.only(bottom: dynamicBottom),
                              child: child,
                            );
                          },
                          child: PromptComposer(
                            ctrl: _queryCtrl,
                            focusNode: _focusNode,
                            dark: dark,
                            hasFocus: _hasFocus,
                            // BUILD 327+: thinking=true enquanto IA processa (thinking OU streaming)
                            thinking: _thinking || _isStreaming,
                            onSend: () => _sendDebounced(
                              _queryCtrl.text,
                              context.read<AppProvider>(),
                            ),
                            onCancel:
                                _cancelActiveStream, // BUILD 327+: abort stream
                            hint: p.t('ai_placeholder'),
                            onVoice: _toggleStt,
                            sttListening: _sttListening,
                            sttSoundLevel: _sttSoundLevel,
                            lang: p.lang,
                            // ADENDO SEGURANÇA: Factor 1 — trava interface quando desconectado
                            isConnected: isMplusConnected,
                            // UX INTERCEPT: toque no campo bloqueado abre modal de conexão
                            onConnectTap: _openAiSettings,
                          ),
                        ),
                      ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mini barra de ações mobile — SEMPRE visível no topo da tela de IA no celular.
// Garante acesso a Histórico e Limpar mesmo com teclado aberto ou sem scroll.
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// SUPER ORDEM ESTRUTURAL 11 — M+ VIVO
// Widget de respiração: AnimationController loop forward↔reverse (1.5s).
// Usado nas barras mobile e desktop quando IA está conectada.
// Dispose automático pelo ciclo de vida StatefulWidget — sem memory leak.
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Header fino — estilo WhatsApp
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// GoogleAuthBarrierCard — SUPER ORDEM 42 M4
// Card proeminente centralizado para usuários não autenticados.
// Exibido quando forceDisconnectedLabel=true && _messages.isEmpty.
// Substitui o WiFi-off overlay com CTA de Google Sign-In.
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// SUPER ORDEM 41 M3 — _applyPlantaoAestheticGuard
//
// Higienização estética do texto final do Modo Plantão:
//   1. Remove marcadores **bold** residuais (Gemini às vezes emite '**Label:**')
//      → extrai apenas o conteúdo interno (emojis âncora já presentes).
//   2. Normaliza ALLCAPS de labels de matriz (DOSE:, ALERTA:, etc.)
//      → Title Case canônico para consistência visual nativa iOS/Android.
//   3. Preserva integralmente todas as linhas clínicas produzidas.
//
// NUNCA inventa, limita ou descarta conteúdo clínico. Apenas normaliza forma visual.
// Executado APÓS todos os guards de segurança e ANTES do POST-STREAM LOCK.
// ─────────────────────────────────────────────────────────────────────────────
String _applyPlantaoAestheticGuard(String text) {
  if (text.trim().isEmpty) return text;

  // ── 1. Strip **bold** markers (preserve content between **) ─────────────
  // Regex strips **anything** → anything throughout the text.
  // Safe: only strips the ** wrappers, never the content.
  var lines = text
      .split('\n')
      .map(
        (line) => line.replaceAllMapped(
          RegExp(r'\*\*([^*]+)\*\*'),
          (m) => m.group(1) ?? '',
        ),
      )
      .toList();

  // ── 2. ALLCAPS label → Title Case ────────────────────────────────────────
  // Only matches standalone label tokens (WORD:) in all-caps.
  // Preserves clinical acronyms (IAM, PCR, mg/kg…) that are mid-sentence.
  const labels = [
    'DOSE',
    'DOSAGEM',
    'ALERTA',
    'ALERTAS',
    'ALTERNATIVA',
    'CONDUTA',
    'EVITAR',
    'MONITORAR',
    'MONITORAMENTO',
    'CONTRAINDICACAO',
    'CONTRAINDICAÇÕES',
    'CONTRAINDICACION',
    'DILUICAO',
    'DILUIÇÃO',
    'PREPARO',
    'INFUSAO',
    'INFUSÃO',
    'TITULACAO',
    'TITULAÇÃO',
    'VELOCIDADE',
    'CALCULO',
    'CÁLCULO',
    'INTERPRETACAO',
    'INTERPRETAÇÃO',
    'PROXIMO',
    'PRÓXIMO',
    'OBSERVAR',
    'OBSERVACAO',
    'OBSERVAÇÃO',
    'VIGILAR',
  ];
  lines = lines.map((line) {
    for (final label in labels) {
      if (line.contains('$label:')) {
        final titled =
            label[0].toUpperCase() + label.substring(1).toLowerCase();
        line = line.replaceAll('$label:', '$titled:');
      }
    }
    return line;
  }).toList();

  // ── 3. Preservação clínica integral ──────────────────────────────────────
  // Limites de tamanho pertencem ao prompt/provedor, nunca à camada visual.
  // Cortar por quantidade de linhas pode remover contraindicações, alertas,
  // doses ou próximos passos já recebidos corretamente do modelo.
  return lines.join('\n');
}

// ─────────────────────────────────────────────────────────────────────────────
// BUILD 315 — _stripCodeFencesAndExtractJson
// ─────────────────────────────────────────────────────────────────────────────
// PROBLEMA: a LLM ocasionalmente retorna a resposta envolta em code fences
// de markdown (```json … ``` ou ``` … ```) ou com um bloco JSON bruto em vez
// do template emoji-âncora esperado. Quando isso acontece, o PlantaoParser
// falha em detectar qualquer âncora (🟥, 💊, etc.) e o app renderiza o JSON
// ou o bloco de código em monoespaçado bruto em vez dos cards clínicos nativos.
//
// SOLUÇÃO: pré-processamento resiliente em 3 estratégias em cascata:
//
//   Estratégia A — Code-fence strip (``` json ou ``` puro):
//     Remove as marcações de markdown. Se o conteúdo interno já tem emojis
//     âncora ou é texto clínico normal, o pipeline continua normalmente.
//
//   Estratégia B — JSON bruto com emojis-âncora como chaves:
//     A IA às vezes retorna { "🟥": "Conduta...", "💊": "Dose..." }.
//     Extrai cada chave-emoji e converte para o formato de linha canônico:
//     "🟥 Conduta...\n💊 Dose...\n"
//
//   Estratégia C — JSON bruto sem emojis (campos semânticos):
//     A IA pode retornar { "conduta": "...", "dose": "...", "monitorar": "..." }.
//     Mapeia os campos conhecidos para as âncoras canônicas e constrói o
//     template emoji manualmente.
//
// PRINCÍPIO: NUNCA altera texto que já está no formato emoji-âncora correto.
//            NUNCA descarta conteúdo clínico — transforma, não substitui.
//            Idempotente: passar texto já correto retorna o texto sem mudança.
// ─────────────────────────────────────────────────────────────────────────────
String _stripCodeFencesAndExtractJson(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return text;

  // ── Estratégia A: remove code fences de markdown ─────────────────────────
  // Padrões cobertos (todos case-insensitive, com ou sem espaço após ```):
  //   ```json   ```JSON   ``` json   ```   (fence de abertura)
  //   ```        (fence de fechamento)
  // A regex abrange variações reais observadas em Gemini 2.5-flash:
  //   "🟥 CONDUCTA CLÍNICA INMEDIATA\n```json\n{...}\n```"
  //   "```json\n🟥 CONDUTA...\n💊 ...\n```"
  //   "```\n🟥 ...\n```"
  final hasFence = RegExp(r'`{3}', multiLine: true).hasMatch(trimmed);
  if (hasFence) {
    // Remove TODAS as ocorrências de ``` seguidas de identificador opcional
    String stripped = trimmed
        .replaceAll(RegExp(r'```[a-zA-Z]*\s*', multiLine: true), '')
        .replaceAll(RegExp(r'`{3}', multiLine: true), '')
        .trim();

    // Se após o strip o texto tem âncoras ou é clínico → retorna direto
    // (Estratégias B/C só são necessárias se ainda for JSON puro)
    final looksLikeJson = stripped.trimLeft().startsWith('{');
    if (!looksLikeJson) {
      debugPrint(
        '[BUILD315_JSON_STRIP] action=fence_stripped '
        'originalLen=${trimmed.length} strippedLen=${stripped.length}',
      );
      return stripped;
    }
    // Continua com o JSON limpo para Estratégias B/C
    text = stripped;
  }

  // ── Detecta se é JSON puro: primeira chave não-espaço é '{' ─────────────
  final bodyStart = text.trimLeft();
  if (!bodyStart.startsWith('{')) return text; // não é JSON — pass-through

  // ── Encontra primeiro '{' e último '}' para extrair JSON válido ───────────
  // Resiliente a cabeçalhos antes do JSON (ex: "🟥 CONDUCTA CLÍNICA\n{...")
  final firstBrace = text.indexOf('{');
  final lastBrace = text.lastIndexOf('}');
  if (firstBrace < 0 || lastBrace <= firstBrace) return text;

  // Preserva texto antes do '{' como possível cabeçalho/prefixo
  final prefix = text.substring(0, firstBrace).trim();
  final jsonSlice = text.substring(firstBrace, lastBrace + 1);

  Map<String, dynamic>? jsonMap;
  try {
    jsonMap = jsonDecode(jsonSlice) as Map<String, dynamic>?;
  } catch (_) {
    // JSON inválido → pass-through com fence já removido
    debugPrint(
      '[BUILD315_JSON_STRIP] action=json_parse_failed '
      'slice_len=${jsonSlice.length}',
    );
    return text;
  }
  if (jsonMap == null || jsonMap.isEmpty) return text;

  debugPrint(
    '[BUILD315_JSON_STRIP] action=json_decoded '
    'keys=${jsonMap.keys.toList()} prefix="${prefix.length > 30 ? prefix.substring(0, 30) : prefix}"',
  );

  // ── Estratégia B: JSON com chaves-emoji (🟥, 💊, etc.) ─────────────────
  // Verifica se alguma chave é um emoji-âncora canônico
  const anchors = [
    '🟥',
    '💊',
    '🔄',
    '⛔',
    '📌',
    '⚠️',
    '📈',
    '✅',
    '❌',
    '🔎',
    '🧪',
    '🧮',
    '📖',
  ];
  const anchorOrder = [
    '🟥',
    '💊',
    '🔄',
    '⛔',
    '🔎',
    '🧪',
    '🧮',
    '📖',
    '📈',
    '❌',
    '📌',
    '✅',
    '⚠️',
  ];

  final hasEmojiKeys = jsonMap.keys.any(
    (k) => anchors.any((a) => k.contains(a)),
  );

  if (hasEmojiKeys) {
    final sb = StringBuffer();
    // Usa prefixo como linha extra se não começar com emoji
    if (prefix.isNotEmpty && !anchors.any((a) => prefix.startsWith(a))) {
      sb.writeln(prefix);
    }
    // Itera em ordem canônica para garantir sequência correta
    for (final anchor in anchorOrder) {
      // Busca chave que contenha o emoji (tolerante a sufixos de texto)
      final matchKey = jsonMap.keys
          .where((k) => k.contains(anchor))
          .firstOrNull;
      if (matchKey == null) continue;
      final val = jsonMap[matchKey]?.toString().trim() ?? '';
      if (val.isEmpty) continue;
      sb.writeln('$anchor $val');
    }
    final result = sb.toString().trim();
    if (result.isNotEmpty) {
      debugPrint(
        '[BUILD315_JSON_STRIP] action=emoji_keys_converted '
        'outputLen=${result.length}',
      );
      return result;
    }
  }

  // ── Estratégia C: JSON com campos semânticos em texto ─────────────────────
  // Mapeia campos conhecidos para âncoras canônicas
  final fieldToAnchor = <String, String>{
    // 🟥 conduta / título
    'conduta': '🟥',
    'conducta': '🟥',
    'titulo': '🟥',
    'título': '🟥',
    'title': '🟥',
    'conduta_titulo': '🟥',
    'conduta_título': '🟥',
    // 💊 dose / primeira linha
    'dose': '💊',
    'dosis': '💊',
    'primeira_linha': '💊',
    'primera_linea': '💊',
    'medicacao': '💊',
    'medicación': '💊',
    'tratamento': '💊',
    'tratamiento': '💊',
    // 🔄 alternativa
    'alternativa': '🔄',
    'segunda_linha': '🔄',
    'segunda_linea': '🔄',
    // ⛔ evitar
    'evitar': '⛔',
    'contraindicado': '⛔',
    'contraindicação': '⛔',
    'contraindicacion': '⛔',
    // 📌 monitorar
    'monitorar': '📌',
    'monitorizar': '📌',
    'monitoramento': '📌',
    'observar': '📌',
    // ⚠️ alerta
    'alerta': '⚠️',
    'atencao': '⚠️',
    'atencion': '⚠️',
    'aviso': '⚠️',
  };

  // Constrói saída na ordem canônica mapeando campos
  final anchorLines = <String, String>{};
  for (final entry in jsonMap.entries) {
    final keyNorm = entry.key
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^a-záéíóúàãõâêîôûçñü_0-9]', unicode: true), '');
    final anchor = fieldToAnchor[keyNorm];
    if (anchor == null) continue;
    final val = entry.value?.toString().trim() ?? '';
    if (val.isEmpty) continue;
    anchorLines.putIfAbsent(anchor, () => val);
  }

  if (anchorLines.isNotEmpty) {
    final sb = StringBuffer();
    if (prefix.isNotEmpty) sb.writeln(prefix);
    for (final anchor in anchorOrder) {
      final val = anchorLines[anchor];
      if (val == null) continue;
      sb.writeln('$anchor $val');
    }
    final result = sb.toString().trim();
    if (result.isNotEmpty) {
      debugPrint(
        '[BUILD315_JSON_STRIP] action=semantic_fields_converted '
        'anchorsFound=${anchorLines.keys.toList()} outputLen=${result.length}',
      );
      return result;
    }
  }

  // Nenhuma estratégia funcionou — retorna o texto com fences removidas
  debugPrint(
    '[BUILD315_JSON_STRIP] action=pass_through_no_mapping '
    'jsonKeys=${jsonMap.keys.toList()}',
  );
  return text;
}

// BUILD 248B — _plantaoTruncationGuard (ARQUITETURA CONSOLIDADA + REFORMATTER)
//
// ARQUITETURA:
//   Camada 1 — PlantaoOrganizer (via PlantatoPipeline.run()):
//     organiza, repara, detecta sinais clínicos — NUNCA bloqueia
//   Camada 2 — ResponseValidator (AiSmartRouter.shouldFallback()):
//     ÚNICA fonte de decisão de bloqueio/fallback clínico
//   Camada 2.5 — ResponseReformatter (BUILD 248B):
//     quando !fallback e resposta é prosa → aplica template emoji canônico
//     preserva conteúdo, reorganiza forma. Modo Estudo → pass-through.
//   Camada 3 — SafetyFallback:
//     substitui SOMENTE quando ResponseValidator decide fallback=true
//
// REGRA PRINCIPAL:
//   Se a resposta contém conteúdo clínico útil → PRESERVAR.
//   Se estiver mal formatada → REORGANIZAR via PlantaoRepair.
//   Se for prosa → REFORMATAR via ResponseReformatter (BUILD 248B).
//   NUNCA substituir por fallback para conteúdo útil.
//
// PARÂMETROS:
//   text      — texto da resposta (pós-enforceMedicalFormat)
//   lang      — 'pt' ou 'es'
//   userQuery — mensagem original do usuário (para detecção de intent)
//
// BLOQUEAR/FALLBACK somente quando ResponseValidator decide:
//   1. meta-leak irrecuperável
//   2. truncada E sem conteúdo clínico
//   3. sem nenhum valor clínico
//
// NUNCA BLOQUEAR POR:
//   - resposta curta com conteúdo clínico
//   - sigla médica (IAM, TEP, PCR…)
//   - repaired=true, orderFixed=true, hiddenFields > 0
//   - ausência de emoji/subtítulo/estrutura perfeita
//   - falha parcial do parser
//
// LOG: [PLANTAO_ORGANIZER] action=organize/preserve/template_applied/fallback
//      [RESPONSE_VALIDATOR] fallback=false/true reason=...
//      [SAFETY_FALLBACK] fallback=true reason=... (somente quando bloqueia)
// ─────────────────────────────────────────────────────────────────────────────
String _plantaoTruncationGuard(
  String text,
  String lang, {
  String userQuery = '',
}) {
  if (text.trim().isEmpty) return text;

  // Pass-through se for mensagem de erro de rede (já tratada pelo bloco isNetErr)
  final lower = text.toLowerCase();
  final isErrorMsg =
      lower.startsWith('erro') ||
      lower.startsWith('error') ||
      lower.contains('sem conex') ||
      lower.contains('sin conex') ||
      lower.contains('ia indisponível') ||
      lower.contains('ia indisponible');
  if (isErrorMsg) return text;

  // ── BUILD 315: JSON fence strip + extração robusta ────────────────────────
  // Pré-processamento ANTES do RAW_AI_OUTPUT e do PlantatoPipeline.
  // Remove code fences (```json, ```) e converte JSON bruto para o formato
  // emoji-âncora que o PlantaoParser entende. Pass-through se já estruturado.
  text = _stripCodeFencesAndExtractJson(text);

  // ── BUILD 252: RAW_AI_OUTPUT — print do texto bruto ANTES de qualquer parser ─
  // Expõe o que a IA realmente retornou, desmascarando o auto-reparo do Organizer.
  // ignore: avoid_print
  print('================ [RAW_AI_OUTPUT] ================');
  // ignore: avoid_print
  print(text);
  // ignore: avoid_print
  print(
    '================================================= '
    'len=${text.length} chars',
  );
  if (text.trim().length < 100) {
    // Resposta suspeita (< 100 chars) — loga alerta explícito sem mascarar
    // ignore: avoid_print
    print(
      '[RAW_AI_OUTPUT] ⚠️  ALERTA: resposta abaixo de 100 caracteres '
      '(len=${text.trim().length}). Possível recusa, erro ou truncamento grave do modelo.',
    );
  }

  // ── Camada 1: PlantaoOrganizer via PlantatoPipeline ──────────────────────
  // Organiza, repara, detecta sinais clínicos. Não bloqueia.
  final pipelineResult = PlantatoPipeline.run(text);
  final parserValid = pipelineResult.response != null;
  final hasClinical = pipelineResult.hasClinicalContent;
  final isTruncated = pipelineResult.isTruncated;
  final hasMetaLeak = pipelineResult.hasMetaLeak;

  // ── Camada 2: ResponseValidator.shouldFallback() ─────────────────────────
  // ÚNICA fonte de decisão de bloqueio/fallback (BUILD 247).
  final (:fallback, :reason) = AiSmartRouter.shouldFallback(
    parserValid: parserValid,
    hasClinicalContent: hasClinical,
    isTruncated: isTruncated,
    hasMetaLeak: hasMetaLeak,
    repaired: pipelineResult.repaired,
    orderFixed: pipelineResult.orderFixed,
    hiddenFields: pipelineResult.hiddenFields,
    removedLines: pipelineResult.removedLines,
  );

  // ── Log [RESPONSE_VALIDATOR] ─────────────────────────────────────────────
  debugPrint(
    '[RESPONSE_VALIDATOR] '
    'fallback=$fallback '
    'reason=$reason '
    'parserValid=$parserValid '
    'hasClinical=$hasClinical '
    'isTruncated=$isTruncated '
    'hasMetaLeak=$hasMetaLeak '
    'repaired=${pipelineResult.repaired} '
    'orderFixed=${pipelineResult.orderFixed}',
  );

  // ── Caminho PRESERVE: ResponseValidator decidiu manter resposta ───────────
  if (!fallback) {
    // ── BUILD 248B — ResponseReformatter ─────────────────────────────────────
    // Se a resposta é prosa (sem emojis âncora) e temos a query do usuário,
    // aplicar o template canônico para a intenção detectada.
    // Modo Estudo (longResponse=true) é protegido na chamada — não chega aqui.
    final alreadyStructured = ResponseReformatter.isAlreadyStructured(text);

    if (!alreadyStructured && userQuery.isNotEmpty && hasClinical) {
      // BUILD 277-PATCH — GUARD hasInlineBold:
      // Se a IA já emitiu marcadores de negrito ** no texto, significa que
      // o RAW_AI_OUTPUT já possui formatação Markdown inline intacta.
      // Nesse caso, NÃO aplicar ResponseReformatter.applyTemplate() — ele
      // reconstrói a resposta do zero e pode perder os ** markers.
      // Só reformatar quando o texto é prosa pura sem nenhum ** bold marker.
      final hasInlineBold = text.contains('**');
      if (hasInlineBold) {
        debugPrint(
          '[PLANTAO_ORGANIZER] action=preserve '
          'reason=has_inline_bold_bypass '
          'hiddenFields=${pipelineResult.hiddenFields}',
        );
        return text;
      }

      // Detecta intenção localmente a partir da query do usuário
      final analysis = PlantaoIntentEngine.analyze(userQuery);
      final intent = analysis.primaryIntent;

      // Aplica template preservando conteúdo clínico
      final reformatted = ResponseReformatter.applyTemplate(
        text,
        lang,
        intent,
        userQuery,
      );

      // Verifica se o reformatter produziu estrutura válida (sanidade)
      final isReformattedStructured = ResponseReformatter.isAlreadyStructured(
        reformatted,
      );

      if (isReformattedStructured && reformatted.length >= text.length * 0.6) {
        debugPrint(
          '[PLANTAO_ORGANIZER] intent=${intent.name} '
          'action=template_applied '
          'preserved=true '
          'reason=$reason '
          'hiddenFields=${pipelineResult.hiddenFields}',
        );
        return reformatted;
      }
      // Se reformatter falhou na sanidade → preserva original com log
      debugPrint(
        '[PLANTAO_ORGANIZER] intent=${intent.name} '
        'action=preserve '
        'reason=reformatter_sanity_failed '
        'hiddenFields=${pipelineResult.hiddenFields}',
      );
      return text;
    }

    final organizeAction =
        (pipelineResult.repaired || pipelineResult.orderFixed)
        ? 'organize'
        : 'preserve';
    debugPrint(
      '[PLANTAO_ORGANIZER] action=$organizeAction '
      'reason=$reason '
      'hiddenFields=${pipelineResult.hiddenFields}',
    );
    return text; // pass-through — renderer estruturado ou texto plano
  }

  // ── Caminho FALLBACK: ResponseValidator decidiu bloquear ─────────────────
  // Só chega aqui para: meta-leak, truncado sem clínico, sem valor clínico.
  debugPrint(
    '[SAFETY_FALLBACK] fallback=true '
    'reason=$reason '
    'hasClinical=$hasClinical '
    'isTruncated=$isTruncated '
    'hasMetaLeak=$hasMetaLeak',
  );

  // Mantém o 🟥 do título se disponível para contexto
  final titleLine = text.split('\n').first.trim();
  final hasTitleLine = titleLine.startsWith('🟥') && titleLine.length > 3;

  final fallbackBody = lang == 'es'
      ? 'No pude completar la respuesta clínica ahora.\n'
            'Esto puede ocurrir por sobrecarga momentánea del servidor.\n'
            'Intente nuevamente en algunos segundos.'
      : 'Não consegui completar a resposta clínica agora.\n'
            'Isso pode ocorrer por sobrecarga momentânea do servidor.\n'
            'Tente novamente em alguns segundos.';

  if (hasTitleLine) {
    return '$titleLine\n📌 $fallbackBody';
  }
  return '🟥 —\n📌 $fallbackBody';
}

// Build 134 — enforceMedicalFormat
//
// CAMADA FINAL DE SEGURANÇA CLÍNICA — última barreira antes da renderização.
//
// OBJETIVO: garantir que TODA resposta clínica exibida ao usuário inicie com
// 🟥 ou 🚨. Essa camada NÃO substitui o System Prompt (fonte primária), mas
// age como proteção visual de último recurso para outliers de temperatura alta
// ou chunks de edge-case que passem pelo firewall de streaming.
//
// DESIGN PRINCIPLES:
//   1. NON-DESTRUCTIVE: resposta já conforme (começa com 🟥/🚨) → pass-through zero-cost
//   2. NON-GREEDY: apenas prefixo; jamais transforma o corpo clínico
//   3. ERROR BYPASS: mensagens de erro de rede/API → pass-through (detectadas pela
//      camada onDone existente, não devem ser modificadas)
//   4. PARTIAL BYPASS: chunks parciais em streaming → pass-through (não aplicar
//      durante streaming, apenas no texto final de onDone)
//   5. EMPTY BYPASS: string vazia → pass-through
//
// QUANDO APLICAR:
//   Apenas em onDone(finalText) — texto completo e definitivo.
//   NÃO aplicar em onChunk — modificar parciais causa artefatos visuais.
//
// PREFIXO INJETADO: linha em branco não é adicionada — o 🟥 em si é o separador.
// ─────────────────────────────────────────────────────────────────────────────
String _enforceMedicalFormat(String text, String lang) {
  if (text.isEmpty) return text;

  // Respeita erros de rede/API — são strings de suporte, não respostas clínicas.
  // Identificadas pelo prefixo 'ERRO', pela ausência de 🟥/🚨, e pela presença
  // de keywords de suporte. Qualquer modificação aqui produziria UX confusa.
  final lower = text.toLowerCase();
  final isErrorMsg =
      lower.contains('sem conex') ||
      lower.contains('sin conex') ||
      lower.contains('timeout') ||
      lower.contains('falha na conex') ||
      lower.contains('falla de red') ||
      lower.contains('ia indisponível') ||
      lower.contains('ia indisponible') ||
      lower.contains('limite de consultas') ||
      lower.contains('límite de consultas') ||
      lower.contains('apoio educacional') ||
      lower.contains('apoyo educacional') ||
      lower.startsWith('erro') ||
      lower.startsWith('error');
  if (isErrorMsg) return text;

  // Verifica se a resposta já está em conformidade (começa com 🟥 ou 🚨).
  // Trim de whitespace/newlines iniciais para lidar com leading whitespace do SSE.
  final trimmed = text.trimLeft();
  if (trimmed.startsWith('🟥') || trimmed.startsWith('🚨')) return text;

  // Resposta não conforme: injeta cabeçalho de conduta imediata.
  // O prefixo é bilíngue e clinicamente neutro — adiciona contexto sem inventar conduta.
  // O corpo original da resposta é preservado integralmente após o prefixo.
  final header = lang == 'es'
      ? '🟥 CONDUCTA CLÍNICA INMEDIATA\n'
      : '🟥 CONDUTA CLÍNICA IMEDIATA\n';

  return '$header$text';
}

// ─────────────────────────────────────────────────────────────────────────────
// Bolha da IA — múltiplas bolhas por bloco, com negrito inline e sem markdown
// ─────────────────────────────────────────────────────────────────────────────

/// Limpa marcadores markdown da resposta da IA antes de exibir.
/// Remove ##, **, --, --- e formata hifens de lista.
// ─────────────────────────────────────────────────────────────────────────────
// STREAM SANITIZER — Expurgo de metadados no buffer acumulado (Build 94)
//
// Chamado em CADA onChunk (texto acumulado parcial) antes de ser armazenado.
// Remove linhas de metadados internos que vazam como primeiras linhas, ex:
//   "Confianza Clínica: Alta — El usuario solicita..."
//   "Confiança Clínica: Alta — O usuário solicita..."
//   "El usuario proporciona síntomas específicos..."
//
// É intencalmente LEVE e sem RegExp pesado — só remove linhas inteiras que
// começam com esses padrões, preservando o restante do texto médico.
// A _cleanAiText() (CAMADA 2) faz a limpeza profunda na renderização.
// ─────────────────────────────────────────────────────────────────────────────
String _stripMetadataHeaders(String accumulated) {
  if (accumulated.isEmpty) return accumulated;

  // ── CAMADA -1 — Build 226: Prompt Leak Emergency Filter ──────────────────
  // Barreira de último recurso contra qualquer eco de mandato estrutural que
  // vaze do system_instruction para o stream de resposta. Cobre:
  //   • Blocos [MANDATO CRÍTICO: ...] e [MANDATO DE INTENT PARA ESTE TURNO]
  //   • Âncoras de modo: [MANDATO CRÍTICO: MODO PLANTÃO...]
  //   • Blocos [INÍCIO DO CONTEXTO CLÍNICO...] e [REFORÇO MANDATÓRIO...]
  //   • Qualquer bloco entre colchetes que contenha MANDATO, SOBERANIA, MONOPÓLIO
  accumulated = accumulated.replaceAll(
    RegExp(
      r'\[(?:MANDATO(?:\s+CR[IÍ]TICO)?|MANDATO\s+DE\s+INTENT|REFOR[ÇC]O\s+MANDAT[ÓO]RIO|'
      r'IN[IÍ]CIO\s+DO\s+CONTEXTO|SOBERANIA\s+ESTRUTURAL|MONOP[ÓO]LIO\s+DE\s+SA[IÍ]DA)'
      r'[^\]]{0,2000}\]',
      caseSensitive: false,
      dotAll: true,
    ),
    '',
  );
  // Remove também linhas que comecem com os cabeçalhos de âncora em texto plano
  accumulated = accumulated.replaceAll(
    RegExp(
      r'^(?:'
      r'\[MANDATO\s+CR[IÍ]TICO.*'
      r'|\[SOBERANIA\s+ESTRUTURAL.*'
      r'|\[MONOP[ÓO]LIO\s+DE\s+SA[IÍ]DA.*'
      r'|\[IN[IÍ]CIO\s+DO\s+CONTEXTO.*'
      r'|\[REFOR[ÇC]O\s+MANDAT[ÓO]RIO.*'
      r'|\[MANDATO\s+DE\s+INTENT.*'
      r'|DIRETRIZ\s+DE\s+IDIOMA\s+\(MANDAT[ÓO]RIA\).*'
      r'|HIERARQUIA\s+DE\s+FORMATO\s+DE\s+SA[IÍ]DA\s+OBRIGAT[ÓO]RIA.*'
      r'|TABELA\s+DE\s+CONVERS[ÃA]O\s+DE\s+MERCADO.*'
      r').*$',
      caseSensitive: false,
      multiLine: true,
    ),
    '',
  );

  // ── CAMADA 0 — Build 117: filtro <think>...</think> e tags órfãs ─────────
  // Bloco delimitado inequívoco — seguro remover com dotAll.
  accumulated = accumulated.replaceAll(
    RegExp(r'<think>.*?</think>', caseSensitive: false, dotAll: true),
    '',
  );
  accumulated = accumulated.replaceAll(
    RegExp(r'</?think[^>]*>', caseSensitive: false),
    '',
  );

  // ── CAMADA 1a v7.0 (Build 126) — PREFIX-ANCHORED, SEM GREEDY ────────────
  //
  // MUDANÇA CRÍTICA: substituímos `^.*Confian....*$` por matches de PREFIXO
  // que só disparam quando a linha COMEÇA com o metadado.
  // Uma linha como "IAM — dose com confiança clínica alta" NÃO é removida.
  // Uma linha como "Confianza Clínica: Alta — El usuario..." É removida.
  //
  // Padrões capturados (linha começa com):
  //   "Confianza Clínica: ..."  / "Confiança Clínica: ..."
  //   "| Confianza Clínica: ..." (com pipe de tabela)
  //   "Nivel de Confianza: ..."  / "Nível de Confiança: ..."
  //   "El usuario solicita/proporciona/pregunta..." (abertura em 3ª pessoa)
  //   "O usuário solicita/fornece/pergunta..." (idem PT)
  //   "The user is asking / asks / wants / requests..."
  //   "Let me think/analyze..."  / "I'll provide/address..."
  //   "Okay, so / First, I..."
  //   "El médico solicita/pregunta..." / "O médico solicita/pergunta..."
  //   "Para proporcionar una respuesta..." / "Para fornecer uma resposta..."
  //   "La base de datos local no contiene..." / "A base de dados local não possui..."
  //   "Por lo tanto, la mejor..." / "Portanto, a melhor abordagem..."
  //   "El/La prompt es vago/incompleto..." / "O prompt é vago/incompleto..."
  //   "A continuación presento..." / "A seguir apresentarei..."
  //   "Baseado no contexto..." / "Basado en el contexto..."
  //   "Vou estruturar/organizar/responder..." / "Preciso analisar..."
  //   "Analisando o caso..." / "Pensando sobre isso..."
  //   "Motivo: ..." / "Motivos: ..." / "Motivo (...): ..."
  //   "Motivo del modo: ..." / "Motivo del activación: ..."
  String result = accumulated.replaceAll(
    RegExp(
      r'^[|\s*]*(?:' // prefixo: pipe, espaço, asterisco
      r'Confian[zç]a\s*(?:Cl[íi]nica)?\s*(?:[:–—]|Alta|M[eé]dia|Baixa)' // "Confianza Clínica: Alta"
      r'|Confianza\s+Clinica\s*[:\s]' // sem acento
      r'|Confianca\s+Clinica\s*[:\s]' // PT sem acento
      r'|Clinical\s+Confidence\s*:'
      r'|Nivel\s+de\s+Confianza\s*:'
      r'|N[íi]vel\s+de\s+Confian[çc]a\s*:'
      r'|El\s+usuario\s+(?:solicita|proporciona|pregunta|pide|quiere|busca|ha\s+(?:pedido|indicado|proporcionado|solicitado)|solicit[oó])'
      r'|O\s+usu[aá]rio\s+(?:solicita|fornece|pergunta|pede|quer|busca|indicou|solicitou|informou|forneceu|est[aá]\s+perguntando)'
      r'|The\s+user\s+(?:is\s+asking|asks|wants|requests|provides|has\s+indicated|has\s+asked)'
      r"|The\s+user(?:'s|s)\s+input\s+(?:is|was)\s"
      r'|The\s+(?:doctor|physician|clinician)\s+(?:is\s+asking|asks|wants|requests)'
      r'|The\s+previous\s+(?:turn|response|message)\s+(?:ended|was|contained)'
      r'|This\s+implies?\s+(?:the\s+user|that\s+the)\s'
      r'|User\s+Input\s+Analysis\s*:'
      r'|Assumed\s+Patient\s+Data\s*:'
      r'|Constructing\s+(?:the\s+)?(?:response|answer)\s*:'
      r'|Since\s+the\s+(?:user|question|prompt)\s+(?:is|was|has)\s'
      r'|As\s+the\s+previous\s+(?:turn|response)\s'
      r'|Given\s+(?:the\s+)?(?:context|previous)\s'
      r'|Let\s+me\s+(?:think|analyze|structure|break|consider|address|provide|help)'
      r"|I(?:'ll|'m|\s+will|\s+should|\s+need\s+to|\s+can)\s+(?:provide|address|help|structure|analyze|respond|answer|focus)"
      r'|Okay[,.]?\s+(?:so|the|I|let|this)\s'
      r'|First[,.]?\s+(?:I|let|the|this)\s'
      r'|Looking\s+at\s+(?:the|this)\s'
      r'|Based\s+on\s+(?:the|this|my)\s'
      r'|El\s+m[eé]dico\s+(?:solicita|pregunta|pide|quiere|ha\s+(?:pedido|indicado))'
      r'|O\s+m[eé]dico\s+(?:solicita|pergunta|pede|quer|solicitou)'
      r'|Para\s+proporcionar\s+una\s+respuesta'
      r'|Para\s+fornecer\s+uma\s+resposta'
      r'|La\s+base\s+de\s+datos\s+(?:local\s+)?no\s+(?:contiene|tiene|posee)'
      r'|A\s+base\s+de\s+dados\s+(?:local\s+)?n[aã]o\s+(?:possui|cont[eé]m|tem)'
      r'|Por\s+lo\s+tanto,\s+(?:la\s+mejor|el\s+mejor)'
      r'|Portanto,\s+a\s+melhor\s+abordagem'
      r'|(?:El|La)\s+prompt\s+(?:es|parece)\s+(?:vago|incompleto|ambiguo)'
      r'|O\s+prompt\s+(?:[eé]|parece)\s+(?:vago|incompleto|ambiguo)'
      r'|A\s+continuaci[oó]n\s+(?:presento|presentar[eé]|describir[eé])'
      r'|A\s+seguir\s+(?:apresentarei|descrevo|apresento|fornecerei)'
      r'|Baseado\s+(?:no|na|em)\s+(?:contexto|conversa|solicitac|que\s+(?:o\s+usu|foi))'
      r'|Basado\s+en\s+(?:el\s+contexto|la\s+conversaci[oó]n|la\s+solicitud|lo\s+que)'
      r'|Vou\s+(?:estruturar|organizar|formatar|abordar|analisar)\s'
      r'|Preciso\s+(?:analisar|considerar|estruturar|organizar|fornecer)\s'
      r'|Analisando\s+(?:o|a|os|as|esta|este|esse)\s+(?:caso|consulta|pedido|pergunta)'
      r'|Pensando\s+(?:sobre|em|na|no)\s+(?:isso|esta|este|essa)'
      r'|Motivos?\s*(?:\([^)]*\))?\s*:'
      r'|Motivo\s+del\s+(?:modo|activaci[oó]n)\s*:'
      r').*$',
      caseSensitive: false,
      multiLine: true,
    ),
    '',
  );

  // Build 112: remove linhas que COMEÇAM com frases de "thinking"
  result = result.replaceAll(
    RegExp(
      r'^(?:This\s+is\s+(?:a\s+case|an?\s+(?:urgent|emergency|case))\s+of\s'
      r'|Here\s+is\s+(?:the|a|my)\s+(?:response|answer|clinical)\s'
      r'|The\s+(?:response|answer|clinical\s+response)\s+(?:below|is|will)\s'
      r'|I\s+have\s+(?:analyzed|reviewed|considered|structured)\s).*$',
      caseSensitive: false,
      multiLine: true,
    ),
    '',
  );

  // ── Build 175: CAMADA EXTRA — padrões de CoT vazado observados em produção ─
  // Padrões confirmados por screenshots (8.06–8.08 AM, 2026-06-21):
  //   "< IAM. The previous response ended with..."
  //   "User Input Analysis:"
  //   "The user's input is ..."
  //   "The previous response ended with..."
  //   "I need to provide a response that..."
  //   "This implies the user is providing..."
  //   Linhas em inglês que começam com análise de contexto
  result = result.replaceAll(
    RegExp(
      r'^(?:'
      // Padrão "<" de raciocínio semi-oculto: "< IAM. The previous..."
      r'<\s*[A-Za-z\s,\.]+\.\s+(?:The|I|This|Based)\s'
      // Rótulos de análise em inglês
      r'|User\s+Input\s+Analysis\s*:'
      r"|The\s+user(?:'s|s)?\s+input\s+is\s"
      r'|The\s+previous\s+response\s+(?:ended|was|contained|had)\s'
      r'|This\s+implies?\s+(?:the\s+user|that\s+the)\s'
      r'|I\s+need\s+to\s+provide\s+a\s+response\s'
      r'|Assumed\s+Patient\s+Data\s*:'
      r'|Constructing\s+(?:the\s+)?(?:response|answer)\s'
      r'|Since\s+the\s+(?:user|question|prompt)\s+(?:is|was|has)\s'
      r'|As\s+the\s+previous\s+(?:turn|response|message)\s'
      r'|Given\s+(?:the\s+)?(?:context|previous\s+turn|user\s+input)\s'
      r'|Interpreting\s+(?:the\s+)?(?:user|input|query)\s'
      r'|The\s+question\s+(?:asked|posed|is)\s'
      r'|My\s+task\s+(?:is|here)\s'
      r'|To\s+address\s+(?:the\s+)?(?:user|question|this)\s'
      r').*$',
      caseSensitive: false,
      multiLine: true,
    ),
    '',
  );

  // Bloco completo de raciocínio em inglês delimitado por texto em MAIÚSCULAS:
  // "User Input Analysis:\n...\nConstructing the Response:\n" etc.
  // Remove o bloco inteiro se aparecer antes do conteúdo clínico real.
  result = result.replaceAll(
    RegExp(
      r'(?:^|\n)(?:User\s+Input\s+Analysis|Assumed\s+Patient\s+Data|Constructing\s+the\s+Response)\s*:.*?(?=\n(?:🟥|⛔|💊|🔄|📌|##\s|\*\*[A-Z])|$)',
      caseSensitive: false,
      dotAll: true,
    ),
    '',
  );

  // Build 235 Step 5B — second-line defence: strip bracket system tags
  // that may leak through as first line of the streamed response.
  result = result.replaceAll(
    RegExp(
      r'^\s*\[(?:MODO|PLANT[ÃA]O|PLANTAO|ESTUDO|DIRETRIZ|SOBERANIA|CONTEXTO|TRAVA|SYSTEM)[^\]]*\]\s*',
      caseSensitive: false,
      multiLine: true,
    ),
    '',
  );

  // Build 236 Step 5 — terceira linha de defesa: remove linhas fantasmas que
  // contenham '⚡' ou terminem em '>' (botões textuais gerados acidentalmente
  // pelo modelo ao tentar imitar a UI de sugestões do app).
  final lines = result.split('\n');
  final filtered = lines.where((line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return true; // preserva linhas em branco (espaçamento)
    return !trimmed.contains('⚡') && !trimmed.endsWith('>');
  }).toList();
  result = filtered.join('\n');

  return result.trimLeft();
}

// ─────────────────────────────────────────────────────────────────────────────
// HARD-FILTER: Camada de proteção de renderização — P1 Anti-CoT
//
// Remove QUALQUER fragmento de chain-of-thought, scratchpad, planning interno,
// hidden prompts ou meta-comentários do modelo antes de exibir ao usuário.
// O usuário vê APENAS a resposta clínica final, limpa e estruturada.
//
// Padrões eliminados:
//   1. Blocos XML/tag de raciocínio: <thinking>...</thinking>, <scratchpad>
//   2. Prefixos de planning vazados: "My response should focus on:"
//   3. Tags de revisão interna: [REVISAO_INTERNA], [REVISION_INTERNA], [FIM_...]
//   4. Cabeçalhos Markdown desnecessários: ## ### (mantém estrutura via negrito)
//   5. Separadores decorativos: ---, --
//   6. Asteriscos triplos ou mais: ***
//   7. Comentários de auto-avaliação: "Let me think", "I'll structure", etc.
//
// ORDEM 27 — DEPRECATION STATUS:
//   DEPRECATED IN PLANTÃO MODE — chamada activa APENAS no caminho de streaming
//   parcial (isStreaming=true dentro de _computeBlocksFromText). Para texto
//   final commitado o BUILD 277-PATCH já aplica bypass transparente (pass-through).
//   MAINTAINED FOR: Estudo mode streaming chunks | legacy history AiBubble display.
//   NÃO REMOVER: remoção causaria regressão no Modo Estudo e no histórico retroativo.
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// _AudioWave — 5 barras verticais finas animadas pelo nível do microfone.
//
// • Quando level > 0: as barras crescem proporcionalmente ao volume captado.
// • Quando level = 0: reduzem a pontos estáticos (2×2 px) indicando standby.
// • Usa AnimatedContainer para transições fluidas sem AnimationController externo.
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Motor de Partida — toggle de modo de resposta (Build 149, atualizado B156)
//
// Dois modos mutuamente exclusivos exibidos como pill-toggle compacto:
//   🏥 Plantão  → longResponse=false → ModeAnchorEngine injeta MODE_ANCHOR_PLANTAO
//                  → flashcard ≤14 linhas, 🟥 obrigatório, zero enciclopédia
//   📖 Estudos  → longResponse=true  → ModeAnchorEngine injeta MODE_ANCHOR_ESTUDO
//                  → revisão técnica ≤24 linhas, RAG Override Rule ativa
//
// Build 156: os motores vivem no Dart (ModeAnchorEngine em ai_gateway_service.dart),
// não mais em rotas separadas do servidor Node.js.
// Design: pill com dois segmentos, estado ativo em gradiente teal.
// Posicionado entre o carrossel de sugestões e a barra de input.
// Mantém estado em _AiScreenState._longResponse e passa ao sendAiMessage().
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Sheet de status da IA — mostra estado atual + botão "Conectar com Google"
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// HISTÓRICO DE CHATS — bottom sheet com até 20 sessões salvas
// ─────────────────────────────────────────────────────────────────────────────
// MICRO-BUILD 462E-A.5.3.7.3.2.5.2 [PILLAR 3]:
// ChatHistorySheet no longer holds sessions as a constructor parameter.
// Instead, sessions are injected by the Selector builder in _openHistory()
// and passed as a typed List<AiSessionSummary> — pure data, reactive.

// ─────────────────────────────────────────────────────────────────────────────
// BUILD 310 — AmbassadorPanel: VIP ModalBottomSheet for partners
// Apple Safe: rendered only when isPartner==true. Zero exposure to App Review.
// ─────────────────────────────────────────────────────────────────────────────

class _AiResponseIdentityHeader extends StatelessWidget {
  const _AiResponseIdentityHeader({
    required this.dark,
    required this.isEs,
    required this.isStreaming,
  });

  final bool dark;
  final bool isEs;
  final bool isStreaming;

  @override
  Widget build(BuildContext context) {
    final palette = HomeV2Palette.resolve(dark);
    final accent = dark ? const Color(0xFF00E59B) : palette.accent;
    final title = isStreaming
        ? (isEs ? 'GENERANDO RESPUESTA' : 'GERANDO RESPOSTA')
        : (isEs ? 'RESPUESTA COMPLETADA' : 'RESPOSTA CONCLUÍDA');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.psychology_alt_rounded, color: accent, size: 16),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 10.2,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class _AiHomeGreeting extends StatelessWidget {
  const _AiHomeGreeting({
    required this.dark,
    required this.lang,
    required this.text,
    required this.compact,
    required this.animate,
  });

  final bool dark;
  final String lang;
  final String text;

  /// false: estado vazio centralizado, equivalente ao _InlineEmptyGreeting.
  /// true: conversa ativa à esquerda, equivalente ao
  /// _InlineConversationGreeting da Home.
  final bool compact;

  /// A animação ocorre somente quando o usuário envia uma mensagem nova.
  /// Histórico restaurado recebe o estado final sem repetir a animação.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final palette = HomeV2Palette.resolve(dark);
    final greeting = text.split('\n\n').first.trim();
    final commaIndex = greeting.indexOf(',');

    final greetingLead = commaIndex < 0
        ? greeting
        : greeting.substring(0, commaIndex + 1);

    final greetingName = commaIndex < 0
        ? ''
        : greeting.substring(commaIndex + 1);

    final subtitle = lang == 'es'
        ? 'Describe el caso o la duda clínica.'
        : 'Descreva o caso ou a dúvida clínica.';

    final motionDuration = animate
        ? const Duration(milliseconds: 320)
        : Duration.zero;

    Widget greetingLine({
      required double fontSize,
      required FontWeight fontWeight,
      required TextAlign textAlign,
    }) {
      return Text.rich(
        TextSpan(
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: fontSize,
            height: 1.2,
            fontWeight: fontWeight,
            letterSpacing: compact ? -0.1 : -0.3,
          ),
          children: [
            TextSpan(
              text: greetingLead,
              style: TextStyle(color: palette.accent),
            ),
            TextSpan(
              text: greetingName,
              style: TextStyle(color: palette.textPrimary),
            ),
          ],
        ),
        textAlign: textAlign,
      );
    }

    Widget openingGreeting() {
      return Padding(
        key: const ValueKey<String>('ai-greeting-opening'),
        padding: const EdgeInsets.fromLTRB(16, 34, 16, 22),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                greetingLine(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 7),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 12.5,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget conversationGreeting() {
      return Padding(
        key: const ValueKey<String>('ai-greeting-compact'),
        padding: const EdgeInsets.fromLTRB(12, 8, 16, 18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              greetingLine(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                textAlign: TextAlign.left,
              ),
            ],
          ),
        ),
      );
    }

    return AnimatedAlign(
      duration: motionDuration,
      curve: Curves.easeOutCubic,
      alignment: compact ? Alignment.topLeft : Alignment.center,
      child: AnimatedSwitcher(
        duration: motionDuration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: compact ? conversationGreeting() : openingGreeting(),
      ),
    );
  }
}
