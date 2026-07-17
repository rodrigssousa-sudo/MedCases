import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../theme/app_theme.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/common_widgets.dart' show MedBreakpoints, PharmacologicalDisclaimer, EvidenceCardWidget, EvidenceBadgesRow;
import '../models/drug_model.dart' show DrugEvidenceModel;
import '../models/clinical_structured_output.dart';
import '../models/chat_message.dart';
import '../widgets/clinical/structured_clinical_output_view.dart';
import 'ai/widgets/prompt_composer.dart';
import 'ai/widgets/message_render_policy.dart';
import 'ai/widgets/drug_evidence_detector.dart';
import 'ai/widgets/action_buttons_row.dart';
import 'ai/widgets/user_bubble.dart';
import 'ai/widgets/suggestion_carousel.dart';
import 'ai/widgets/empty_chat.dart';
import 'ai/widgets/ai_error_banner.dart';
import 'ai/widgets/info_row.dart';
import '../widgets/error_state_widget.dart'
    show InlineConnectionBanner;
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:convert';
import '../providers/app_provider.dart';
import '../providers/ai_chat_provider.dart'; // BUILD 326: granular rebuild durante streaming

import '../services/stt_helper.dart';
import '../services/firestore_service.dart';
import '../services/ai/ai_finalization_transaction.dart'
    show AiSessionSummary, AiSessionSource;
import '../services/activity_service.dart';
import 'package:url_launcher/url_launcher.dart'; // BUILD 310: WhatsApp share Ambassador
import '../models/user_model.dart'; // BUILD 310: UserModel.isPartner access
import '../services/referral_service.dart'; // BUILD 310: referral count for Ambassador panel
import '../services/external_tool_link_engine.dart'; // Build 185: Deep Link Router
import 'calculadora_screen.dart'; // Build 189: ExternalToolButton abre tela interna
import '../services/plantao_pipeline.dart'; // Build 193: PlantaoResponse + pipeline
import '../services/ai_smart_router.dart'; // BUILD 247: AiSmartRouter.shouldFallback()
import '../widgets/ecg_loading.dart'; // BUILD 276: ECG loading indicator
import '../services/app_resume_coordinator.dart'; // ORDEM 53 M2/M3: backgroundSaveSignal + contextTimeoutSignal
import '../services/auth_service.dart'; // BUILD 338: contingency UID when currentUser==null


// ─────────────────────────────────────────────────────────────────────────────
/// Alias privado temporário para preservar os call sites do monólito durante a extração.
typedef _ChatMsg = ChatMessage;

// ─────────────────────────────────────────────────────────────────────────────
// Modelo de sessão de chat salva no histórico
// ─────────────────────────────────────────────────────────────────────────────
class _ChatSession {
  final String id;           // timestamp ISO como ID único
  final DateTime savedAt;    // quando foi salva
  final String summary;      // primeira mensagem do usuário (resumo)
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
    'messages': messages.map((m) => {'id': m.id, 'role': m.role, 'text': m.text}).toList(),
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
        final map = m is Map ? Map<String, dynamic>.from(m) : <String, dynamic>{};
        final msgId = map['id']?.toString()
            ?? '${map['role'] ?? 'unknown'}_${DateTime.now().microsecondsSinceEpoch}';
        final role = map['role']?.toString() ?? 'user';
        final text = map['text']?.toString() ?? '';
        parsedMessages.add(_ChatMsg.withId(id: msgId, role: role, text: text));
      } catch (e) {
        // Mensagem individual corrompida — descarta silenciosamente sem crashar.
        if (kDebugMode) {
          debugPrint('[MIGRATION] Skipped corrupt message entry in session $id: $e');
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
  static final pendingHistory =
      ValueNotifier<List<Map<String, String>>>([]);

}

class _AiScreenState extends State<AiScreen> {
  final _queryCtrl  = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode  = FocusNode();

  // Referência obtida enquanto o BuildContext está ativo.
  // Usada no dispose() sem consultar ancestrais de um elemento desativado.
  AppProvider? _appProviderRef;
  final List<_ChatMsg> _messages = [];
  bool _thinking      = false;
  bool _hasFocus      = false;
  bool _aiError       = false;
  // Task 11 — network error banner: true quando a última chamada da IA falhou
  // por problema de conexão (timeout, socket, etc.) vs. erro de chave API.
  bool _networkError  = false;
  // Motor de Partida (Build 149): false=Plantão (≤12 linhas) | true=Estudos (22-24)
  // SUPER ORDEM MASTER 14 M5: Estudos é o modo PADRÃO — evita custo Plantão automático
  bool _longResponse  = true;
  bool _greetingDone  = false; // garante saudação só uma vez por sessão
  int  _lastAiIndex  = -1;   // índice da última resposta da IA (para animar só ela)
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

  // ── BUILD 232: ExtTool deduplication cache ───────────────────────────────
  // Key: messageId + ':' + textHash
  // Garante que ExternalToolLinkEngine.build() execute no máximo 1 vez por
  // (messageId, textHash) por sessão. PlantatoPipelineCache removido (ORDEM 56).
  final Map<String, ExternalToolLink?> _extToolCache = {};
  // BUILD 244B / ORDEM 56: log-dedup sets — SAFE_CARD_GUARD e EVIDENCE_GUARD
  // são disparados no ListView item builder, que reconstrói muitas vezes.
  // _loggedPlantaoIds removido junto com _PlantaoRenderer (ORDEM 56).
  // BUILD 246: _loggedEvidenceIds — dedup EVIDENCE_GUARD por messageId+textHash.
  final Set<String> _loggedSafeCardIds  = {};
  final Set<String> _loggedEvidenceIds  = {};
  // BUILD 308 [EXT_TOOL_DEDUP]: log-dedup set para EXT_TOOL_DEDUP.
  // Evita spam de 18+ debugPrints/s no console durante rebuilds de streaming.
  // Registra apenas a 1ª ocorrência de cada extKey por sessão.
  final Set<String> _loggedExtToolKeys  = {};
  // ──────────────────────────────────────────────────────────────────────────

  // ── TTS (Text-to-Speech) ─────────────────────────────────────────────────
  late final FlutterTts _tts;
  bool _ttsReady        = false;
  int  _ttsPlayingIndex = -1; // índice da mensagem sendo reproduzida (-1 = nenhuma)

  // ── STT (Speech-to-Text via Web Speech API) ──────────────────────────────
  bool   _sttListening    = false; // microfone ativo
  double _sttSoundLevel   = 0.0;   // nível de som normalizado 0.0–1.0 (onda de áudio)
  // Buffer de texto parcial — acumulamos aqui durante o reconhecimento e só
  // comprometemos no TextEditingController quando isFinal=true (evita eco "eu eu eu").
  // Na web (isFinal guard no stt_helper_web.dart) este buffer não é usado
  // para parciais — onResult já chega como final. No mobile, o buffer também
  // não é necessário pois _handleResult só chama onResult quando isFinal.
  // Mantido aqui como salvaguarda de estado para futuros refactors.
  String _sttPartialBuffer = '';

  // Sugestões ficam visíveis apenas no estado vazio + sem foco
  bool get _showSuggestions => _messages.isEmpty && !_hasFocus;

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
    final bool es   = lang != 'pt';
    final int  hour = DateTime.now().hour;
    final String period;
    if (es) {
      if (hour < 6)       period = 'Buena madrugada';
      else if (hour < 12) period = 'Buenos días';
      else if (hour < 18) period = 'Buenas tardes';
      else                period = 'Buenas noches';
    } else {
      if (hour < 6)       period = 'Boa madrugada';
      else if (hour < 12) period = 'Bom dia';
      else if (hour < 18) period = 'Boa tarde';
      else                period = 'Boa noite';
    }
    final firstName = userName.trim().split(' ').first;
    final nameStr   = firstName.isNotEmpty ? ', $firstName' : '';
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
      debugPrint('[AI_SCREEN][BUILD_285] ORDEM_56 init — '
          'unifiedMarkdownRender=true plasticPipelineExterminated=true');
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
    AppResumeCoordinator.instance.backgroundSaveSignal.addListener(_onBackgroundSave);
    // ORDEM 53 M3: escuta sinal de context timeout → hard reset de UI + sessão.
    AppResumeCoordinator.instance.contextTimeoutSignal.addListener(_onContextTimeout);
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
    AiScreen.clearChatCallback.value   = _clearChat;
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
          debugPrint('[PROACTIVE_GATE] Tela de IA sem conexão — modal disparado.');
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
        debugPrint('[BUILD452_TTL] elapsed=${elapsed ~/ 60000}min > 30min '
            '— limpando thread visual e reiniciando sessão limpa.');
      }
      // Limpa mensagens em memória; _greetingDone=false força nova saudação
      if (mounted) {
        setState(() {
          _messages.clear();
          _greetingDone        = false;
          _chatEpoch++;           // invalida cache gráfico do ListView
          _activeSessionId     = null;
          _restoredSessionId   = null;
          _hasNewMessageAfterRestore = false;
          _aiError             = false;
          _networkError        = false;
          _userScrolledUp      = false;
        });
        // Limpa histórico de transporte da IA (context do Gemini)
        final p = context.read<AppProvider>();
        p.clearAiHistory();
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
      await prefs.setInt(_kLastActiveKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  // ── Inicialização TTS ───────────────────────────────────────────────────
  Future<void> _initTts() async {
    _tts = FlutterTts();
    try {
      await _tts.setVolume(1.0);
      await _tts.setSpeechRate(0.95);
      await _tts.setPitch(1.0);
      _tts.setCompletionHandler(() {
        if (mounted) setState(() => _ttsPlayingIndex = -1);
      });
      _tts.setCancelHandler(() {
        if (mounted) setState(() => _ttsPlayingIndex = -1);
      });
      _tts.setErrorHandler((_) {
        if (mounted) setState(() => _ttsPlayingIndex = -1);
      });
      if (mounted) setState(() => _ttsReady = true);
    } catch (_) {}
  }

  /// Reproduz ou para o áudio de uma mensagem da IA.
  Future<void> _toggleTts(int msgIndex, String text, String lang) async {
    if (!_ttsReady) return;
    // TTS-GUARD: flutter_tts pode lançar PlatformException em dispositivos
    // onde o TTS engine está ausente ou corrompido. Captura para evitar crash.
    try {
      if (_ttsPlayingIndex == msgIndex) {
        // Já tocando esta mensagem → para
        await _tts.stop();
        if (!mounted) return;
        setState(() => _ttsPlayingIndex = -1);
        return;
      }
      // Para qualquer reprodução anterior
      await _tts.stop();
      if (!mounted) return;
      setState(() => _ttsPlayingIndex = msgIndex);
      // Configura idioma
      final locale = lang == 'es' ? 'es-ES' : 'pt-BR';
      await _tts.setLanguage(locale);
      // Remove caracteres especiais de markdown antes de falar
      final cleaned = _cleanForSpeech(text);
      await _tts.speak(cleaned);
    } catch (e, st) {
      debugPrint('[AiScreen][_toggleTts] TTS exception: $e\n$st');
      if (mounted) setState(() => _ttsPlayingIndex = -1);
    }
  }

  /// Limpa texto para reprodução de voz (remove asteriscos, hifens de lista, etc.)
  String _cleanForSpeech(String text) {
    return text
        .replaceAll(RegExp(r'\*+'), '')
        .replaceAll(RegExp(r'^-\s+', multiLine: true), '')
        .replaceAll(RegExp(r'^#{1,3}\s*', multiLine: true), '')
        .replaceAll('---', '. ')
        .replaceAll('--', '. ')
        .trim();
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
      _sttListening     = true;
      _sttSoundLevel    = 0.0;
      _sttPartialBuffer = '';
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
          _sttListening     = false;
          _sttSoundLevel    = 0.0;
          _sttPartialBuffer = '';
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
          _sttListening     = false;
          _sttSoundLevel    = 0.0;
          _sttPartialBuffer = '';
        });
        _showSttErrorSnack(code);
      },

      // ── onEnd: limpa estado ao encerrar normalmente
      onEnd: () {
        if (!mounted) return;
        setState(() {
          _sttListening  = false;
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
      if (mounted) setState(() {
        _sttListening  = false;
        _sttSoundLevel = 0.0;
      });
    }
  }

  Future<void> _sttStop() async {
    await SttHelper.stop();
    if (mounted) setState(() {
      _sttListening     = false;
      _sttSoundLevel    = 0.0;
      _sttPartialBuffer = '';
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
    ));
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
      setState(() {
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
      debugPrint('[ORDEM53_M2] Auto-save silencioso — app foi para background '
          'msgs=${_messages.length}');
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
        debugPrint('[ORDEM53_M3][BUILD432] Context Timeout detectado mas '
            'Modo Estudo ativo → hard reset SUPRIMIDO. '
            'UI preservada; contexto será re-alimentado via '
            'rebuildAiHistoryFromMessages() na próxima interação.');
      }
      // Reconstrói _aiHistory no Provider a partir das mensagens visíveis na UI
      // para resgatar a âncora cognitiva antes do próximo envio.
      final historyPayload = _messages
          .where((m) => m.role == 'user' || m.role == 'assistant')
          .map((m) => {'role': m.role, 'content': m.text})
          .toList();
      if (historyPayload.isNotEmpty) {
        p.rebuildAiHistoryFromMessages(historyPayload);
        debugPrint('[ORDEM53_M3][BUILD432] rebuildAiHistoryFromMessages '
            'executado silenciosamente — ${historyPayload.length} entradas '
            'restauradas no contexto da API (Modo Estudo)');
      }
      return; // ← SUPRIME o hard reset abaixo
    }

    // ── Modo Plantão: hard reset completo (comportamento original) ───────────
    if (kDebugMode) {
      debugPrint('[ORDEM53_M3] Context Timeout ativado — ≥30 min de background '
          '→ hard reset de sessão clínica (Modo Plantão)');
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
      _chatEpoch++;          // força rebuild completo da árvore de chat
      _messages.clear();
      _greetingDone = false;
      _restoredSessionId = null;
      _activeSessionId   = null;
      _hasNewMessageAfterRestore = false;
      _thinking  = false;
      _aiError   = false;
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

    debugPrint('[ORDEM53_M3] Hard reset concluído — nova sessão clínica pronta');
  }
  void _consumePendingQuery() {
    final q = AiScreen.pendingQuery.value;
    if (q.isEmpty || !mounted) return;

    // Captura o provider enquanto o BuildContext ainda está ativo.
    // O callback atrasado não pode consultar ancestrais após a tela ser desativada.
    final p = context.read<AppProvider>();

    AiScreen.pendingQuery.value = '';  // limpa imediatamente para não re-disparar
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      _send(q, p);
    });
  }

  void _injectGreeting() {
    if (_greetingDone || !mounted) return;
    _greetingDone = true;
    final p = context.read<AppProvider>();
    setState(() {
      _messages.add(_ChatMsg(role: 'ai', text: _buildGreeting(p.userName, p.lang)));
    });
  }

  double _lastScrollOffset = 0.0; // Build 158: rastreia offset anterior para detectar direção

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
    // ⚡ Sem setState aqui — usa variável simples para evitar rebuild no scroll
    final wasUp = _userScrolledUp;
    _userScrolledUp = !nearBottom;
    // Só reconstrói se o estado mudou (botão scroll-to-bottom aparece/desaparece)
    if (wasUp != _userScrolledUp && mounted) {
      setState(() {});
    }

    // Build 158 — Hide-on-scroll: detecta direção do scroll para hide/show bottom nav.
    // Scroll para BAIXO (ler histórico, aumentando pixels) → oculta barra
    // Scroll para CIMA (voltar ao presente) → mostra barra
    // Atualiza apenas quando há mudança real (evita churn de notifier).
    final currentOffset = pos.pixels;
    final isScrollingDown = currentOffset > _lastScrollOffset + 4; // threshold anti-bounce
    final isScrollingUp   = currentOffset < _lastScrollOffset - 4;
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
        debugPrint('[BUILD300][AI_SCREEN] Safe dispose session save dispatched successfully.');
      } else {
        debugPrint('[BUILD300][AI_SCREEN] Safe dispose session save skipped: provider cache empty.');
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
    AppResumeCoordinator.instance.backgroundSaveSignal.removeListener(_onBackgroundSave);  // ORDEM 53 M2
    AppResumeCoordinator.instance.contextTimeoutSignal.removeListener(_onContextTimeout);  // ORDEM 53 M3

    // ── 3. TTS: para reprodução e limpa handlers antes de liberar ──────────
    // Guard: _tts é late final — inicializado de forma async em _initTts().
    // Se dispose() disparar antes de _initTts() completar (ex: navigação rápida),
    // acessar _tts causaria LateInitializationError. Usamos _ttsReady como sentinela.
    if (_ttsReady) {
      _tts.stop();
      // Build 133: limpa handlers com no-ops (flutter_tts não aceita null em 3.32+)
      _tts.setCompletionHandler(() {});
      _tts.setCancelHandler(() {});
      _tts.setErrorHandler((_) {});
    }

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
          final existingIdx = _chatHistory.indexWhere((s) => s.id == disposeSessionId);
          final session = _ChatSession(
            id: disposeSessionId,
            savedAt: now,
            summary: summary.length > 100 ? summary.substring(0, 100) : summary,
            messages: msgsToSave,
          );
          // Persiste localmente (SharedPreferences) — Firestore requer context
          SharedPreferences.getInstance().then((prefs) {
            try {
              // Insere no snapshot do histórico atual
              final histSnapshot = List<_ChatSession>.from(_chatHistory);
              if (existingIdx >= 0) histSnapshot.removeAt(existingIdx);
              histSnapshot.insert(0, session);
              if (histSnapshot.length > 10) {
                histSnapshot.removeRange(10, histSnapshot.length);
              }
              final key = '\$_kHistKey';
              final json = jsonEncode(histSnapshot.map((s) => s.toJson()).toList());
              prefs.setString(key, json);
            } catch (_) {}
          }).catchError((_) {});
        }
      }
    } catch (_) {}

    // ── 5. Limpa ValueNotifiers estáticos do shell AppBar ──────────────────
    // Callbacks do widget desmontado — evita referências mortas no shell.
    AiScreen.clearChatCallback.value       = null;
    AiScreen.openHistoryCallback.value     = null;
    AiScreen.openSettingsCallback.value    = null;
    AiScreen.ambassadorPanelCallback.value = null; // BUILD 310
    AiScreen.hasMessagesNotifier.value  = false;
    AiScreen.historyCountNotifier.value = 0;
    AiScreen.aiConnectedNotifier.value  = false;
    AiScreen.chatKeyboardOpen.value     = false;
    AiScreen.scrollingDown.value        = false; // Build 158: reset hide-on-scroll

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
    debugPrint('[BUILD430] post-OAuth uid=$uid — recarregando histórico de chat.');
    _loadChatHistory();
  }

  String? _resolveUid(AppProvider p) {
    final sdkUid = p.currentUser?.uid;
    if (sdkUid != null && sdkUid.isNotEmpty) return sdkUid;
    // Contingência: token REST presente mas SDK ainda não propagou o usuário
    final contingencyUid = AuthService.webUser.value?.uid;
    if (contingencyUid != null && contingencyUid.isNotEmpty) return contingencyUid;
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

        final outcome = await p.loadAiSessionsTypedForUi(uid, caller: '_loadChatHistory');

        // UI-side stale-epoch guard: if this widget was rebuilt and a new
        // _loadChatHistory() started while we awaited, discard silently.
        if (!mounted || _sessionsLoadGeneration != myGeneration) {
          debugPrint('[AI_SESSIONS_LOAD] uid=$uid STALE_EPOCH discarded '
              'myGen=$myGeneration currentGen=$_sessionsLoadGeneration');
          return;
        }

        // ── Outer: UiLoadOutcome routing ────────────────────────────────────
        if (outcome is UiLoadDiscarded<List<Map<String, dynamic>>>) {
          // Provider-side stale generation: a newer UID took ownership while
          // we were awaiting.  No state-tree mutation of any kind.
          debugPrint('[AI_SESSIONS_LOAD] uid=$uid result=discarded '
              'reason=${outcome.reason}');
          return;
        }

        // outcome is UiLoadApplied — extract the inner FirestoreLoadResult.
        final typedResult = (outcome as UiLoadApplied<List<Map<String, dynamic>>>).result;

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

          debugPrint('[AI_SESSIONS_LOAD] uid=$uid result=success '
              'action=hydrate count=${sessions.length} writeBack=false');

          // ORDEM 27 — TELEMETRIA DE MIGRAÇÃO (Firestore path):
          if (kDebugMode) {
            for (final s in sessions) {
              final fmt = _detectSessionFormat(s.messages);
              switch (fmt) {
                case 'pharma_card':
                  debugPrint('[MIGRATION] Loaded pharma_card chat session format. id=${s.id}');
                case 'plantao_structured':
                  debugPrint('[MIGRATION] Loaded plantao_structured chat session format. id=${s.id}');
                default:
                  debugPrint('[MIGRATION] Loaded legacy chat session format. id=${s.id}');
              }
            }
          }

          if (mounted) setState(() {
            _chatHistory.clear();
            _chatHistory.addAll(sessions);
          });
          _persistHistoryLocal(p);
          return;

        } else if (typedResult.isEmpty) {
          // EMPTY: Server-authoritative — user has no sessions. This is the
          // ONLY path that may physically clear _chatHistory.
          debugPrint('[AI_SESSIONS_LOAD] uid=$uid result=empty '
              'action=authoritative_clear writeBack=false');
          if (mounted) setState(() => _chatHistory.clear());
          return;

        } else if (typedResult.isAuthDenied) {
          // AUTH_DENIED: Firebase returned permission-denied (real auth breach).
          // Freeze local state — _chatHistory is NOT touched.
          debugPrint('[AI_SESSIONS_LOAD] uid=$uid result=authDenied '
              'action=freeze writeBack=false');
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
          debugPrint('[AI_SESSIONS_LOAD] uid=$uid result=offline '
              'action=freeze writeBack=false');
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
          debugPrint('[AI_SESSIONS_LOAD] uid=$uid result=failure '
              'action=freeze writeBack=false '
              'error=${typedResult.runtimeType}');
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
              debugPrint('[MIGRATION] Loaded pharma_card chat session format. id=${s.id}');
            case 'plantao_structured':
              debugPrint('[MIGRATION] Loaded plantao_structured chat session format. id=${s.id}');
            default:
              debugPrint('[MIGRATION] Loaded legacy chat session format. id=${s.id}');
          }
        }
      }

      if (mounted) setState(() {
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
      debugPrint('[AI_SCREEN][DISPOSE_SAVE] skipped reason=missing_context_or_empty '
          'session=$currentSession uid=$currentUid msgCount=${_messages.length}');
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
      debugPrint('[LEGACY_WRITE][SKIPPED] '
          'reason=canonical_session_owned '
          'requestId=${p.currentRequestId}');
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
      debugPrint('[BUILD274][SessionDedup] Nova sessão iniciada id=$sessionId historyLen=${_chatHistory.length}');
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
        if (_chatHistory.length > 10) {
          _chatHistory.removeRange(10, _chatHistory.length);
        }
      });
    } else {
      // Dispose path: atualiza lista diretamente sem setState (widget já morto)
      if (existingIdx >= 0) _chatHistory.removeAt(existingIdx);
      _chatHistory.insert(0, session);
      if (_chatHistory.length > 10) {
        _chatHistory.removeRange(10, _chatHistory.length);
      }
    }

    debugPrint('[BUILD274][SessionDedup] save sessionId=$sessionId msgs=${session.messages.length} existingIdx=$existingIdx');

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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => Selector<AppProvider, List<AiSessionSummary>>(
        selector: (_, prov) => prov.visibleAiSessionSummaries,
        builder: (_, sessions, __) {
          // Emit reactive render trace (safe — no user content in metrics).
          debugPrint('[HISTORY_MODAL][RENDER] '
              'visibleCount=${sessions.length} '
              'topSource=${sessions.isEmpty ? "none" : sessions.first.source.name} '
              'topSessionIdHash=${sessions.isEmpty ? "none" : sessions.first.sessionId.hashCode} '
              'topTitleLen=${sessions.isEmpty ? 0 : sessions.first.title.length}');
          return _ChatHistorySheet(
            dark: p.darkMode,
            lang: p.lang,
            onRestoreSummary: (summary) {
              Navigator.pop(modalCtx);
              _restoreFromSummary(summary, p);
            },
            onDelete: (sessionId) async {
              // Remove from legacy chat history if present.
              setState(() => _chatHistory.removeWhere((s) => s.id == sessionId));
              // Remove do Firestore (legacy path)
              final uid = _resolveUid(p);
              if (uid != null && uid.isNotEmpty) {
                FirestoreService.deleteAiSession(uid, sessionId).catchError((_) {});
              }
              _persistHistoryLocal(p);
            },
            sessions: sessions,
          );
        },
      ),
    );
  }

  /// Restaura uma sessão do histórico para o chat atual.
  void _restoreSession(_ChatSession session, AppProvider p) {
    // Build 107: cancela streaming ativo para liberar os guards
    p.cancelAiStream();
    // Build 188: descarta notifier de streaming ao restaurar sessão
    _streamingTextNotifier?.dispose();
    _streamingTextNotifier = null;
    // BUILD 244B/246: limpa sets de log-dedup ao restaurar sessão
    _loggedSafeCardIds.clear();
    _loggedEvidenceIds.clear();
      _loggedExtToolKeys.clear(); // BUILD 308
    setState(() {
      _messages.clear();
      _messages.addAll(session.messages);
      _lastAiIndex = -1;
      _greetingDone = true;
      _userScrolledUp = false;
      _restoredSessionId = session.id;
      _activeSessionId = null;         // BUILD 274: sessão restaurada usa _restoredSessionId, não _activeSessionId
      _hasNewMessageAfterRestore = false;
      _thinking   = false;
      _isStreaming = false;
      _sendGuard  = false;
    });
    // Build 110 FIX: reconstrói _aiHistory a partir das mensagens restauradas.
    // clearAiHistory() limpava o histórico sem repopular — a próxima mensagem
    // enviada após restaurar uma sessão chegava ao Gemini sem nenhum contexto.
    p.rebuildAiHistoryFromMessages(session.messages
        .where((m) => m.role == 'user' || m.role == 'ai')
        .map((m) => {
              'role':    m.role == 'ai' ? 'assistant' : 'user',
              'content': m.text,
            })
        .toList());

    // ORDEM 56: _plantaoPipelineCache removido — _AiBubble renderiza tudo via
    // MarkdownBody diretamente. Sem cache de pipeline a pré-popular na restauração.

    _scrollDown(force: true);
  }

  // ── MICRO-BUILD 462E-A.5.3.7.3.2.5.2 [PILLAR 4]: Source-aware restore ─────
  // Restores a session selected from the history modal timeline.
  // Strategy is determined by AiSessionSummary.source:
  //   legacyInline  → messages are embedded; repopulate directly.
  //   canonicalV2   → fire async exchange loader, expand to chat bubbles.
  //   localMemory   → treat as canonicalV2 if sessionId matches; fallback to empty.
  void _restoreFromSummary(AiSessionSummary summary, AppProvider p) {
    debugPrint('[SESSION_RESTORE][START] '
        'source=${summary.source.name} '
        'sessionIdHash=${summary.sessionId.hashCode}');

    p.cancelAiStream();
    _streamingTextNotifier?.dispose();
    _streamingTextNotifier = null;
    _loggedSafeCardIds.clear();
    _loggedEvidenceIds.clear();
    _loggedExtToolKeys.clear();

    switch (summary.source) {
      case AiSessionSource.legacyInline:
        // ── Legacy inline path: messages embedded in the summary ─────────────
        final inlineMsgs = summary.legacyMessages ?? [];
        final chatMsgs = inlineMsgs.map((m) {
          final role = (m['role'] as String?) ?? 'user';
          final text = (m['text'] as String?) ?? (m['content'] as String?) ?? '';
          return _ChatMsg(role: role, text: text);
        }).toList();

        setState(() {
          _messages.clear();
          _messages.addAll(chatMsgs.isNotEmpty ? chatMsgs : []);
          _lastAiIndex   = -1;
          _greetingDone  = true;
          _userScrolledUp = false;
          _restoredSessionId = summary.sessionId;
          _activeSessionId   = null;
          _hasNewMessageAfterRestore = false;
          _thinking   = false;
          _isStreaming = false;
          _sendGuard  = false;
        });

        p.rebuildAiHistoryFromMessages(chatMsgs
            .where((m) => m.role == 'user' || m.role == 'ai')
            .map((m) => {'role': m.role == 'ai' ? 'assistant' : 'user',
                          'content': m.text})
            .toList());

        debugPrint('[SESSION_RESTORE][COMPLETED] '
            'source=legacyInline '
            'messageCount=${chatMsgs.length}');
        _scrollDown(force: true);

      case AiSessionSource.canonicalV2:
      case AiSessionSource.localMemory:
        // ── Canonical v2 path: load exchanges from Firestore sub-collection ───
        setState(() {
          _messages.clear();
          _lastAiIndex   = -1;
          _greetingDone  = true;
          _userScrolledUp = false;
          _restoredSessionId = summary.sessionId;
          _activeSessionId   = null;
          _hasNewMessageAfterRestore = false;
          _thinking   = true;   // show loading indicator during fetch
          _isStreaming = false;
          _sendGuard  = false;
        });

        final uid = _resolveUid(p) ?? '';
        if (uid.isEmpty) {
          // No UID — abort restore, retain empty state.
          if (mounted) setState(() { _thinking = false; });
          return;
        }

        // Fire background async exchange loader — NEVER await in a lifecycle cb.
        () async {
          try {
            final result = await FirestoreService.loadAiSessionExchangesTyped(
                uid, summary.sessionId);

            if (result.isSuccess) {
              final exchanges = result.dataOrElse([]);
              debugPrint('[SESSION_EXCHANGES_LOAD][SUCCESS] '
                  'sessionIdHash=${summary.sessionId.hashCode} '
                  'exchangeCount=${exchanges.length} '
                  'messageCount=${exchanges.length * 2}');

              // Expand each exchange into two chat bubbles (user + assistant).
              final chatMsgs = <_ChatMsg>[];
              for (final ex in exchanges) {
                final userInput = (ex['userInput'] as String?) ?? '';
                final aiOutput  = (ex['assistantOutput'] as String?) ?? '';
                if (userInput.isNotEmpty) {
                  chatMsgs.add(_ChatMsg(role: 'user', text: userInput));
                }
                if (aiOutput.isNotEmpty) {
                  chatMsgs.add(_ChatMsg(role: 'ai', text: aiOutput));
                }
              }

              if (!mounted) return;
              setState(() {
                _messages.clear();
                _messages.addAll(chatMsgs);
                _thinking = false;
              });

              p.rebuildAiHistoryFromMessages(chatMsgs
                  .where((m) => m.role == 'user' || m.role == 'ai')
                  .map((m) => {'role': m.role == 'ai' ? 'assistant' : 'user',
                                'content': m.text})
                  .toList());

              debugPrint('[SESSION_RESTORE][COMPLETED] '
                  'source=${summary.source.name} '
                  'messageCount=${chatMsgs.length}');
              _scrollDown(force: true);
            } else if (result.isEmpty) {
              // Session exists but no exchanges yet — safe empty state.
              if (!mounted) return;
              setState(() { _thinking = false; });
              debugPrint('[SESSION_RESTORE][COMPLETED] '
                  'source=${summary.source.name} messageCount=0');
            } else if (result.isAuthDenied) {
              // Permission denied — freeze current layout, abort restore.
              if (!mounted) return;
              setState(() {
                _thinking = false;
                _restoredSessionId = null;  // clear the restore anchor
              });
              debugPrint('[SESSION_RESTORE][ABORTED] reason=auth_denied '
                  'sessionIdHash=${summary.sessionId.hashCode}');
            } else if (result.isOffline) {
              // Network error — freeze current layout, do not render empty.
              if (!mounted) return;
              setState(() { _thinking = false; });
              debugPrint('[SESSION_RESTORE][ABORTED] reason=offline '
                  'sessionIdHash=${summary.sessionId.hashCode}');
            } else {
              // Unrecoverable error — freeze current layout, never empty.
              if (!mounted) return;
              setState(() { _thinking = false; });
              debugPrint('[SESSION_RESTORE][ABORTED] reason=failure '
                  'sessionIdHash=${summary.sessionId.hashCode}');
            }
          } catch (err) {
            if (!mounted) return;
            setState(() { _thinking = false; });
            debugPrint('[SESSION_RESTORE][ABORTED] reason=exception '
                'sessionIdHash=${summary.sessionId.hashCode} err=$err');
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

      final pos    = _scrollCtrl.position;
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

  /// Chamado pelo _AiBubble a cada bloco revelado durante streaming.
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
  void _sendDebounced(String text, AppProvider p, {bool fromButton = false}) {
    _submitDebounceTimer?.cancel();
    _submitDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      _send(text, p, fromButton: fromButton);
    });
  }

  Future<void> _send(String text, AppProvider p, {bool fromButton = false}) async {
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
      debugPrint('[BUILD303_LAYER0] Bloqueio pré-guarda: '
          'currentUser=${p.currentUser?.uid ?? "NULL"} '
          'geminiConnected=${p.geminiConnected} '
          'openAiKey=${p.openAiKey.isNotEmpty} → return imediato, zero bytes ao backend.');
      return;
    }

    final trimmed = text.trim();
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
      debugPrint('[HARD_BLOCKER_V2] Factor2 acionado — geminiConnected=${p.geminiConnected} '
          'openAiKey=${p.openAiKey.isNotEmpty} → bloqueio total, modal levantado.');
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
      _messages.add(_ChatMsg(role: 'user', text: trimmed));
      _thinking = true;
      _aiError  = false;
      _networkError = false; // limpa banner de rede ao enviar nova mensagem
      _userScrolledUp = false; // reset ao enviar — desce para mostrar "pensando"
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
    // O notifier nunca era criado → _AiBubble recebia null → streaming ultra-localizado
    // (sem rebuild da árvore inteira) não funcionava → cada chunk reconstruía
    // toda a lista via setState() → GC pressure aumentada + UI jitter em respostas longas.
    //
    // SOLUÇÃO: criar o notifier aqui (pré-streaming), passá-lo para _AiBubble via
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
    int  chunksSinceStart = 0;

    try {
      // ── Streaming V2 via sendAiMessage ────────────────────────────────────
      // Retorna true se usou streaming (Gemini conectado), false se usou fallback.
      await p.sendAiMessage(
        trimmed,
        longResponse:  _longResponse,  // Motor de Partida (Build 149)
        fromButton:    fromButton,      // BUILD 262: preserves thread on action buttons
        onChunk: (accumulated) {
          if (!mounted || uiRequestGeneration != _aiUiRequestGeneration) return;

          // ── BUILD 276: SUPPRESSED CHUNK RENDERING ─────────────────────────
          // Arquitectura: mantém _thinking=true e EcgLoadingBlock visível
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
          if (streamingMsgIdx != -1 &&
              nowMs - _lastChunkRenderMs < 25) return;
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
                _streamingTextNotifier?.value = cleanedChunk;
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
                  _streamingTextNotifier?.value = cleanedChunk;
                }
              }
            }
          } catch (_) {
            // Chunk malformado: descartado silenciosamente.
          }
        },
        onDone: (finalText) {
          if (!mounted || uiRequestGeneration != _aiUiRequestGeneration) return;
          // ── Detecta tipo de resultado ─────────────────────────────────────
          final isKeyError = finalText.startsWith('ERRO') && finalText.contains('API');
          // Detecta erro de rede — NÃO usa finalText.contains('🚨') como critério
          // pois 🚨 é também marcador de seção clínica válida (ex: "🚨 INFARTO AGUDO DO MIOCÁRDIO").
          // Usamos apenas keywords textuais específicas de mensagens de erro de rede.
          final _ft = finalText.toLowerCase();
          final isNetErr = _ft.contains('sem conex') ||
              _ft.contains('sin conex') ||
              _ft.contains('timeout') ||
              _ft.contains('falha na conex') ||
              _ft.contains('falla de red') ||
              _ft.contains('conexão necessária') ||
              _ft.contains('conexión requerida') ||
              _ft.contains('verifique sua conex') ||
              _ft.contains('verifique sua rede') ||
              _ft.contains('ia indisponível') ||
              _ft.contains('ia indisponible');

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
            if (kDebugMode) debugPrint('[SAFE_CARD_GUARD] onDone safeCard=true removing partial streamingMsgIdx=$streamingMsgIdx');
            _streamingTextNotifier?.dispose();
            _streamingTextNotifier = null;
            setState(() {
              _thinking     = false;
              _isStreaming   = false;
              _aiError       = false;
              _networkError  = false;
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
          // texto final em um único setState. Isso fazia o _AiBubble receber
          // isStreaming=false e texto final SIMULTANEAMENTE no mesmo frame —
          // o _computeBlocks() removia o cursor ▌ e potencialmente produzia
          // um número diferente de blocos. Com layout ainda incompleto, o
          // jumpTo no onDone saltava para um maxScrollExtent MENOR que o real,
          // congelando o scroll antes do último bloco aparecer na tela.
          //
          // SOLUÇÃO: 2 setStates separados:
          // setState #1 (agora): comita texto final COM _isStreaming=true ainda
          //   → _AiBubble já recebe o texto completo mas mantém o cursor ▌
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
              _thinking    = false;
              _isStreaming  = false;
              _aiError      = isKeyError;
              _networkError = isNetErr;
              // ── NETWORK SAFETY: erro de rede no onDone ───────────────────
              if (streamingMsgIdx >= 0 && streamingMsgIdx < _messages.length) {
                _messages.removeAt(streamingMsgIdx);
                streamingMsgIdx = -1;
              }
              if (_messages.isNotEmpty && _messages.last.role == 'user' &&
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
                ? finalText  // Modo Estudo: texto sem modificação
                : _enforceMedicalFormat(
                    finalText,
                    p.lang,
                  );

            // ── Build 226: Plantão Truncation Guard ──────────────────────────
            // Detecta resposta truncada no Modo Plantão (ex: 503 mid-stream)
            // e substitui por fallback seguro em vez de renderizar texto parcial.
            // Critério: Modo Plantão + pipeline válida estrutura? Se não, fallback.
            if (!_longResponse) {
              safeFinalText = _plantaoTruncationGuard(
                safeFinalText,
                p.lang,
                userQuery: trimmed, // BUILD 248B: passa query para detecção de intent
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
                .map((line) => line.trimLeft().isEmpty ? line : (
                  line.trimLeft().startsWith('*') ? line.trimLeft() : line
                ))
                .join('\n');

            // ── SUPER ORDEM 41 M3: AESTHETIC GUARD ───────────────────────────
            // Higienização estética exclusiva do Modo Plantão (após todos os
            // guards de segurança): remove **bold** residuais, normaliza ALLCAPS
            // de labels → Title Case, aplica teto de 12 linhas não-vazias.
            // Executado ANTES do pipeline lock para que o texto cacheado já seja
            // o texto esteticamente finalizado.
            if (!_longResponse) {
              safeFinalText = _applyPlantaoAestheticGuard(safeFinalText);
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
            // COMPATIBILIDADE BUILD 101: _visibleCount no _AiBubbleState já garante
            // visibilidade total ao receber isStreaming=false → old.isStreaming=true
            // (linha ~5904 de ai_screen). O cursor ▌ é removido corretamente pela
            // transição isStreaming true→false no didUpdateWidget.

            // Descarta notifier ANTES do setState — sem listener pendurado no rebuild.
            _streamingTextNotifier?.dispose();
            _streamingTextNotifier = null;

            // ORDEM 56: POST-STREAM PIPELINE LOCK removido — sem _plantaoPipelineCache.
            // _AiBubble renderiza safeFinalText via MarkdownBody diretamente.

            // BUILD 276: resolve which msgId will be the new AI bubble so we
            // can attach the fade-in to it in ListView.builder.
            String? newBubbleMsgId;
            if (streamingMsgIdx >= 0 && streamingMsgIdx < _messages.length) {
              newBubbleMsgId = _messages[streamingMsgIdx].id;
            }

            // ÚNICO setState de fechamento: texto final + fim de stream em um frame.
            setState(() {
              _thinking     = false;
              _isStreaming   = false;   // BUILD 254: síncrono — sem postFrameCallback
              _aiError      = isKeyError;
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
                // causando fallback para _AiBubble cru em vez de _PlantaoRenderer.
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
              // BUILD 276: register fade-in target
              _fadingInMsgId = newBubbleMsgId;
            });

            // BUILD 276: auto-clear _fadingInMsgId after animation completes (400ms)
            // so the AnimatedOpacity wrapper is removed on the next rebuild.
            Future.delayed(const Duration(milliseconds: 450), () {
              if (!mounted) return;
              setState(() { _fadingInMsgId = null; });
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
          if (!mounted ||
              uiRequestGeneration != _aiUiRequestGeneration ||
              clinicalOutput == null) {
            return;
          }

          final messageId = committedAiMessageId;
          final committedText = committedAiMessageText;

          // O Structured Output descreve literalmente o displayText validado
          // pelo backend. Qualquer transformação posterior da UI invalida a
          // associação e exige descarte fail-closed.
          if (messageId == null ||
              committedText == null ||
              committedText != finalText) {
            if (kDebugMode) {
              debugPrint(
                '[STRUCTURED_UI][DISCARDED] '
                'reason=final_text_changed '
                'backendLen=${finalText.length} '
                'uiLen=${committedText?.length ?? 0}',
              );
            }
            return;
          }

          final messageIndex =
              _messages.indexWhere((message) => message.id == messageId);
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
          if (currentMessage.text != finalText) {
            if (kDebugMode) {
              debugPrint(
                '[STRUCTURED_UI][DISCARDED] '
                'reason=bubble_text_mismatch',
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
          if (!mounted || uiRequestGeneration != _aiUiRequestGeneration) return;
          // Build 188: descarta notifier de streaming no onError
          _streamingTextNotifier?.dispose();
          _streamingTextNotifier = null;
          // ── BUILD 309 M4: AUTH_REQUIRED — NUNCA renderizar como bubble ────
          // Provider emite AUTH_REQUIRED quando o Factor3 guard bloqueia.
          // Suprimimos a bolha vermelha e abrimos o modal de conexão.
          if (errorMsg == 'AUTH_REQUIRED') {
            setState(() {
              _thinking    = false;
              _isStreaming  = false;
              // Remove a pergunta do usuário sem resposta
              if (_messages.isNotEmpty && _messages.last.role == 'user' &&
                  _messages.last.text == trimmed) {
                _messages.removeLast();
              }
            });
            // Abre modal de autenticação — convida o médico a conectar
            Future.microtask(() { if (mounted) _openAiSettings(); });
            return;
          }
          // Guard do provider retornou '' — ignora (não adiciona bubble vazia)
          if (errorMsg.isEmpty) {
            setState(() {
              _thinking    = false;
              _isStreaming  = false;
              // Remove mensagem do usuário sem resposta
              if (_messages.isNotEmpty && _messages.last.role == 'user' &&
                  _messages.last.text == trimmed) {
                _messages.removeLast();
              }
            });
            return;
          }
          final isKeyError = errorMsg.startsWith('ERRO') && errorMsg.contains('API');
          // Detecta erro de rede — NÃO usa errorMsg.contains('🚨') como critério
          // pois 🚨 é também marcador de seção clínica válida.
          // Usamos apenas keywords textuais específicas de mensagens de erro de rede.
          final _em = errorMsg.toLowerCase();
          final isNetErr = _em.contains('sem conex') ||
              _em.contains('sin conex') ||
              _em.contains('timeout') ||
              _em.contains('falha na conex') ||
              _em.contains('falla de red') ||
              _em.contains('conexão necessária') ||
              _em.contains('conexión requerida') ||
              _em.contains('verifique sua conex') ||
              _em.contains('verifique sua rede') ||
              _em.contains('ia indisponível') ||
              _em.contains('ia indisponible');
          setState(() {
            _thinking    = false;
            _isStreaming  = false;
            _aiError      = isKeyError;
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
              if (_messages.isNotEmpty && _messages.last.role == 'user' &&
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
      // Build 188: descarta notifier de streaming em exceção não tratada
      _streamingTextNotifier?.dispose();
      _streamingTextNotifier = null;
      final errStr = e.toString().toLowerCase();
      final isNetworkException = errStr.contains('socket') ||
          errStr.contains('timeout') ||
          errStr.contains('connection') ||
          errStr.contains('network') ||
          errStr.contains('unreachable');
      setState(() {
        _thinking     = false;
        _isStreaming   = false;
        _networkError = isNetworkException;
        _aiError      = !isNetworkException;
        if (isNetworkException) {
          // Remove mensagem do usuário se não houve resposta
          if (_messages.isNotEmpty && _messages.last.role == 'user' &&
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
        .map((m) => {
              'role': m.role == 'ai' ? 'assistant' : 'user',
              'content': m.text,
            })
        .toList();
    p.rebuildAiHistoryFromMessages(historyPayload);

    setState(() {
      // Remove mensagens a partir do índice editado (inclusive)
      if (msgIndex < _messages.length) {
        _messages.removeRange(msgIndex, _messages.length);
      }
      // Reseta estados de streaming
      _thinking    = false;
      _isStreaming  = false;
      _aiError     = false;
      _networkError = false;
    });
    // Re-dispara o envio com o texto editado
    _send(newText, p);
  }

  void _clearChat() {
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
      _aiError      = false;
      _networkError = false;
      _userScrolledUp = false;
      _restoredSessionId = null;
      _activeSessionId = null;   // BUILD 274: reset para próxima sessão gerar novo ID
      _hasNewMessageAfterRestore = false;
      // Build 107 FIX: reseta guards para desbloquear _send() após limpar
      _thinking   = false;
      _isStreaming = false;
      _sendGuard  = false;
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
    p.cancelAiStream();  // cancela _aiStreamSub no AppProvider
    _aiUiRequestGeneration++;

    // PHASE 4 — fechamento local soberano:
    // remove imediatamente o listener da bolha ativa e impede que deltas
    // tardios continuem atualizando uma resposta já cancelada.
    _streamingTextNotifier?.dispose();
    _streamingTextNotifier = null;

    setState(() {
      _thinking    = false;
      _isStreaming  = false;
      _sendGuard    = false;
    });
    // Devolve foco ao campo de texto — médico pode editar imediatamente
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  // ── Nuevo Chat — salva sessão atual e abre nova sessão limpa ─────────────
  // Diferente de _clearChat: NÃO deleta histórico. Salva em background e
  // cria nova sessão com ID diferente (timestamp) para consulta fresca.
  void _startNewChat() {
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
      _aiError      = false;
      _networkError = false;
      _userScrolledUp = false;
      _restoredSessionId = null;
      _activeSessionId = null;   // BUILD 274: reset para nova sessão gerar novo ID
      _hasNewMessageAfterRestore = false;
      _greetingDone = true;
      // Build 107 FIX: garante que _send() não fique bloqueado após novo chat
      _thinking   = false;
      _isStreaming = false;
      _sendGuard  = false;
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
        child: _AiStatusSheet(
          userEmail:        p.userEmail,
          userName:         p.userName,
          lang:             p.lang,
          dark:             p.darkMode,
          hasAi:            p.hasAnyAi,
          geminiConnected:  p.geminiConnected,
          geminiEmail:      p.geminiEmail,
          geminiLoading:    p.geminiLoading,
          keyLoading:       p.aiKeyLoading,
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
      builder: (_) => _AmbassadorPanel(
        user:     user,
        lang:     p.lang,
        messages: List.of(_messages),
        onSecondOpinion: (prompt) async {
          // Delegated via callback — streaming happens inside modal
          return p.sendAiMessage(
            prompt,
            onChunk: (_) {},
            onDone:  (_) {},
            onError: (_) {},
          );
        },
        provider: p,
      ),
    );
  }

  // Insere sugestão no campo sem enviar — usuário pode editar
  void _insertSuggestion(String prompt) {
    _queryCtrl.text = prompt;
    _queryCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: prompt.length),
    );
    _focusNode.requestFocus();
  }


  @override
  Widget build(BuildContext context) {
    final p    = context.watch<AppProvider>();
    final dark = p.darkMode;
    final bp   = MedBreakpoints.of(context);
    // ORDEM VISUAL 04 M1: canvas premium absoluto
    // Dark: grafite noturno ultra-profundo 0xFF121418
    // Light: branco gelo ultra-limpo 0xFFFCFDFD
    final chatBg = dark ? const Color(0xFF121418) : const Color(0xFFFCFDFD);

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
          (_) => AiScreen.chatKeyboardOpen.value = kbOpen);
    }

    // No desktop: centraliza o chat com largura máxima elegante
    final double? chatMaxWidth = bp.isDesktop ? 960 : null;
    final hPad = bp.isDesktop ? 0.0 : 12.0;

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
    final bool showDisconnectCard = !isConnected &&
        _messages.where((m) => m.role == 'user').isEmpty;

    // BUILD 275: para usuários não-admin/não-master sem conexão, forçar badge
    // 'Desconectado' (vermelho) em vez de 'Conectar IA' — sinaliza que chat está bloqueado.
    // BUILD 339-UI-DEBUGGER: isPrivilegedUser mantido para outros usos; forceDisconnectedLabel
    // agora depende EXCLUSIVAMENTE de p.geminiConnected — Admin/Master passó pelo fluxo idêntico
    // ao usuário comum, ativando _GoogleAuthBarrierCard + _DisconnectedInputLock para QA.
    final bool isPrivilegedUser = p.isAdmin || p.isMaster;
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
            cacheExtent: 2500,
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
                // BUILD 276: EcgLoadingBlock replaces the old 3-dot ThinkingBubble.
                // RepaintBoundary isolates the animated CustomPainter so it does NOT
                // trigger full-list repaints on every animation frame.
                return RepaintBoundary(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 52, 8),
                    child: EcgLoadingBlock(dark: dark, lang: p.lang),
                  ),
                );
              }
              final msg = _messages[i];
              if (msg.role == 'user') {
                // Build 170: passa callbacks de cópia e edição para o balão
                final msgIndex = i; // captura o índice para edição
                return RepaintBoundary(
                  child: KeyedSubtree(
                    key: ValueKey('msg_${msg.id}'),
                    child: UserBubble(
                      text: msg.text,
                      dark: dark,
                      onCopy: () => _copyMsg(msg.text),
                      onEdit: (newText) => _editUserMessage(msgIndex, newText, p),
                      // Fix 5: ícone de edição desabilitado durante streaming
                      isAiStreaming: _isStreaming || _thinking,
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
              final bool _isSafeCard =
                  MessageRenderPolicy.isSafeCard(msg.text);
              if (kDebugMode && _isSafeCard && !_loggedSafeCardIds.contains(msg.id)) {
                _loggedSafeCardIds.add(msg.id);
                debugPrint('[SAFE_CARD_GUARD] messageId=${msg.id} isSafeCard=true');
              }

              // Evidência farmacológica: só detectar se NÃO for safe-card
              final detectedEv =
                  _isSafeCard ? null : DrugEvidenceDetector.detect(msg.text);

              // ── BUILD 301: tag dupla — extrai LABEL + PROMPT, limpa bolha ────
              // A IA gera ao final de cada resposta de Modo Estudo:
              //   [NEXT_ACTION_LABEL: Rótulo Curto]    → texto exato do botão azul
              //   [NEXT_ACTION_PROMPT: Query Avançada] → query disparada no clique
              // Ambas são extraídas e removidas do texto visível na bolha.
              // msg.text original é preservado intacto (hash estável para cache).
              final studyAction = MessageRenderPolicy.parseStudyAction(
                text: msg.text,
                isStudyMode: _longResponse,
              );
              final String _nextActionPrompt = studyAction.prompt;
              final String _nextActionLabel = studyAction.label;
              final bool _hasStudyTags = studyAction.hasAction;
              final String _cleanDisplayText = studyAction.displayText;

              // ── ORDEM 56 M1: RENDER UNIFICADO ────────────────────────────────
              // SUPER ORDEM 56: PlantatoPipeline, _PlantaoRenderer e _PlantaoFallbackCard
              // foram descontinuados. 100% das bolhas AI — 1º turno, follow-ups e
              // histórico restaurado — fluem diretamente para _AiBubble (MarkdownBody).
              // Ultra-Plantão Build 260: o design (🟥/💊/⛔/📌 + bullets) é gerado
              // nativamente pelos prompts. Não há parsing nem slicing necessário.
              // Elimina duplicação de cards pós-refresh e alivia o rebuild do histórico.
              if (kDebugMode) {
                debugPrint('[RENDER_56] msgId=${msg.id} → _AiBubble unificado'
                    '${_hasStudyTags ? " [BUILD301] label=\"$_nextActionLabel\"" : ""}');
              }

              // BUILD 276: Fade-in wrapper — applied only to the freshly committed
              // AI bubble (msg.id == _fadingInMsgId). Starts at opacity 0 and
              // animates to 1 over 380ms. After 450ms _fadingInMsgId is cleared
              // via a delayed setState, removing the AnimatedOpacity overhead.
              final bool isFadingIn = _fadingInMsgId != null && msg.id == _fadingInMsgId;
              Widget bubbleContent = RepaintBoundary(
                child: KeyedSubtree(
                key: ValueKey('msg_${msg.id}'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Bubble unificada: _AiBubble (MarkdownBody agnostico) ────
                    // BUILD 300: usa _cleanDisplayText — tag [NEXT_ACTION_PROMPT]
                    // removida do texto visível. msg.text permanece intacto no modelo.
                    _AiBubble(
                      key: ValueKey('ai_${msg.id}'),
                      text: _cleanDisplayText,
                      dark: dark,
                      animate: i == _lastAiIndex,
                      lang: p.lang,
                      onCopy: () => _copyMsg(_cleanDisplayText),
                      ttsPlaying: _ttsPlayingIndex == i,
                      ttsReady: _ttsReady,
                      onTts: _ttsReady
                          ? () => _toggleTts(i, _cleanDisplayText, p.lang)
                          : null,
                      scrollGeneration: _scrollGeneration,
                      onBlockRevealed: _onBlockRevealed,
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
                      onChipTap: _isStreaming ? null : (chipText) {
                        // Build 187: Detallar... uses sentinel '__DETAIL__:<question>'
                        // → focus TextField + prefill context prefix (no auto-send)
                        if (chipText.startsWith('__DETAIL__:')) {
                          final rawQ = chipText.substring('__DETAIL__:'.length).trim();
                          // Build context prefix from the question text
                          final prefix = rawQ.isNotEmpty
                              ? '$rawQ: '
                              : '';
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
                        _sendDebounced(sendText, context.read<AppProvider>());
                      },
                    ),

                    // ── PHASE 4: Structured Clinical Output tipado ─────────────
                    // Renderizado somente após associação fail-closed ao texto
                    // definitivo. Nunca aparece durante streaming, em safe-cards
                    // ou em respostas legadas sem structuredOutput.
                    if (msg.clinicalOutput != null &&
                        !isActiveStreamingBubble &&
                        !_isSafeCard) ...[
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
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
                    if (i == _lastAiIndex && !_isStreaming && _messages.length >= 2 && !_isSafeCard)
                      Builder(builder: (_) {
                        final lastUser = _messages
                            .lastWhere((m) => m.role == 'user',
                                orElse: () => _ChatMsg(role: 'user', text: ''))
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
                                : (completedResolution != null && completedResolution.isAllowed
                                    ? completedResolution.link
                                    : null);
                        // BUILD 301: label 100% dinâmico — vem direto da tag [NEXT_ACTION_LABEL]
                        // gerada pela IA. Sem inferência local, sem fallbacks engessados.
                        if (kDebugMode && _hasStudyTags) {
                          debugPrint('[BUILD301][NEXT_ACTION] msgId=${msg.id} '
                              'label="$_nextActionLabel" '
                              'promptChars=${_nextActionPrompt.length}');
                        }
                        return ActionButtonsRow(
                          lastUserMessage: lastUser,
                          lastAiResponse: _cleanDisplayText,
                          isPlantaoMode: !_longResponse,
                          lang: p.lang,
                          dark: dark,
                          chatHistory: _messages.map((m) => m.text).toList(),
                          cachedLink: resolvedLink,
                          studyNextPrompt: _nextActionPrompt,
                          studyNextLabel: _nextActionLabel,
                          lastSentStudyPrompt: _lastSentStudyPrompt,
                          onActionTap: (prompt, {bool isStudyNext = false}) {
                            if (_isStreaming) return;
                            _userScrolledUp = false;
                            _scrollDown(force: true);
                            // BUILD 308 [FISIOP_DEDUP]: Registra o prompt do botão azul
                            // de Estudo para detecção de loop de Fisiopatologia no turno seguinte.
                            if (isStudyNext) _lastSentStudyPrompt = prompt;
                            // BUILD 262: fromButton=true — preserves thread history,
                            // prevents HARD RESET on clinical follow-up actions.
                            _sendDebounced(prompt, context.read<AppProvider>(), fromButton: true);
                          },
                        );
                      }),
                    // ── Evidência farmacológica (card colapsível) ────────────────
                    // Build 192: 20px gap entre botões e evidência
                    // ORDEM 56: _PlantaoRenderer removido — evidência sempre visível
                    // quando detectada e não for safe-card. Sem risco de duplicação.
                    // BUILD 246: dedup por messageId+textHash — evita loop de log.
                    if (detectedEv != null && !_isSafeCard)
                      Builder(builder: (_) {
                        if (kDebugMode) {
                          final evKey = '${msg.id}_${msg.text.hashCode}';
                          if (!_loggedEvidenceIds.contains(evKey)) {
                            _loggedEvidenceIds.add(evKey);
                            debugPrint('[EVIDENCE_GUARD] messageId=${msg.id} isSafeCard=$_isSafeCard showing=true');
                          }
                        }
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(12, 20, 12, 0),
                          child: _CollapsibleEvidenceBlock(ev: detectedEv, dark: dark),
                        );
                      }),

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
        if (notification.metrics.axisDirection != AxisDirection.down) return false;

        if (notification is ScrollStartNotification) {
          // Gesto manual do usuário (dragDetails != null) → bloqueia auto-scroll
          if (notification.dragDetails != null && !_userScrolledUp) {
            _userScrolledUp = true;
            // Sem setState: a flag é lida pelo _scrollDown() que roda no próximo frame.
            // O rebuild pelo scroll-to-bottom indicator acontece via _onScroll listener.
          }
        } else if (notification is ScrollEndNotification) {
          // Usuário soltou o dedo → verifica posição para re-ativar auto-scroll
          if (_scrollCtrl.hasClients) {
            final pos = _scrollCtrl.position;
            final nearBottom = pos.pixels >= pos.maxScrollExtent - 100; // BUILD 308: 80→100px
            if (nearBottom && _userScrolledUp) {
              _userScrolledUp = false;
              if (mounted) setState(() {}); // atualiza botão scroll-to-bottom
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
    chatList = SelectionArea(
      child: chatList,
    );

    // Desktop: sem shell AppBar → mostra _WaHeader próprio.
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
            // forceDisconnectedLabel (= !isPrivilegedUser && !isConnected).
            // Não depende mais de _messages.any(). O overlay cobre TODA a timeline
            // independente de haver mensagens — proteção financeira de API absoluta.
            if (forceDisconnectedLabel)
              _GoogleAuthBarrierCard(
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
                            horizontal: 14, vertical: 7),
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
                              color: Colors.black.withOpacity(dark ? 0.35 : 0.10),
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

    return Column(children: [
      // ── Header fino estilo WhatsApp (desktop only) ───────────────────────
      if (showWaHeader)
      _WaHeader(
        dark: dark,
        hasMessages: _messages.isNotEmpty,
        onClear: _clearChat,
        onSettings: _openAiSettings,
        onHistory: () => _openHistory(p),
        onNewChat: _startNewChat,
        historyCount: _chatHistory.length,
        lang: p.lang,
        hasRealAi:       p.hasAnyAi,
        geminiConnected: p.geminiConnected,
        keyLoading: p.aiKeyLoading || p.geminiLoading,
        forceDisconnectedLabel: forceDisconnectedLabel, // BUILD 275
        isConnected: isMplusConnected, // SUPER ORDEM MASTER 15 M2: M+ verde estrito — apenas sessão de IA real
        // BUILD 310: Ambassador golden button — Apple Safe
        isPartner:    p.currentUser?.isPartner ?? false,
        partnerTitle: p.currentUser?.partnerTitle ?? '',
        onAmbassador: (p.currentUser?.isPartner ?? false) ? _openAmbassadorPanel : null,
      ),

      // ── Mini barra de ações mobile — SEMPRE visível mesmo com teclado aberto
      // Histórico + Limpar ficam acessíveis sem depender do scroll-reveal AppBar.
      if (showMobileActions)
        _MobileAiActionBar(
          dark: dark,
          lang: p.lang,
          historyCount: _chatHistory.length,
          hasMessages: _messages.where((m) => m.role == 'user').isNotEmpty,
          hasRealAi: p.hasAnyAi || p.geminiConnected,
          keyLoading: p.aiKeyLoading || p.geminiLoading,
          onHistory: () => _openHistory(p),
          onClear: _clearChat,
          onSettings: _openAiSettings,
          onNewChat: _startNewChat,
          forceDisconnectedLabel: forceDisconnectedLabel, // BUILD 275
          isConnected: isMplusConnected, // SUPER ORDEM MASTER 15 M2: M+ verde estrito — apenas sessão de IA real
          // BUILD 310: Ambassador golden button — invisible to non-partners
          isPartner:    p.currentUser?.isPartner ?? false,
          partnerTitle: p.currentUser?.partnerTitle ?? '',
          onAmbassador: (p.currentUser?.isPartner ?? false) ? _openAmbassadorPanel : null,
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
            // ── ORDEM 36: Seletor de modo flutuante — fixo acima do InputBar ────
            // ORDEM 44 M1: visível enquanto NÃO há mensagens do médico na sessão.
            if (!forceDisconnectedLabel &&
                !_messages.any((m) => m.role == 'user'))
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 0),
                child: _ResponseModeToggle(
                  value: _longResponse,
                  dark: dark,
                  lang: p.lang,
                  onChanged: (newValue) {
                    if (newValue == _longResponse) return;
                    // ORDEM 49 M1 / ORDEM 56: Atomic mode-sync ao alternar toggle.
                    setState(() {
                      _longResponse = newValue;
                      _loggedSafeCardIds.clear();
                      _loggedEvidenceIds.clear();
      _loggedExtToolKeys.clear(); // BUILD 308
                    });
                    p.clearAiHistory();
                    if (kDebugMode) {
                      debugPrint('[ORDEM49_TOGGLE] mode=${newValue ? "ESTUDO" : "PLANTÃO"} '
                          'logSets=cleared history=clearing');
                    }
                  },
                ),
              ),
            const SizedBox(height: 25), // 25px gap antes do TextField

            // ── Carrossel de sugestões — some quando foca ─────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              child: _showSuggestions
                  ? SuggestionCarousel(
                      lang: p.lang,
                      dark: dark,
                      onTap: _insertSuggestion,
                    )
                  : const SizedBox.shrink(),
            ),

            // ── BUILD 277: INPUT LOCKOUT for disconnected non-privileged users
            if (forceDisconnectedLabel)
              _DisconnectedInputLock(dark: dark, lang: p.lang, onConnect: _openAiSettings),

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
                          onSend: () => _sendDebounced(_queryCtrl.text, context.read<AppProvider>()),
                          onCancel: _cancelActiveStream,  // BUILD 327+: abort stream
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
                      builder: (_, kbOpenVal, __) =>
                          ValueListenableBuilder<bool>(
                        valueListenable: AiScreen.scrollingDown,
                        builder: (_, scrollingDown, child) {
                          final mq = MediaQuery.of(context);
                          final nativeBottom = mq.padding.bottom;
                          final keyboardH    = mq.viewInsets.bottom;
                          // Com teclado → sem gap extra (o sistema já reposiciona o layout).
                          // Sem teclado, sem scroll → eleva 95px acima do Dock + safe area.
                          // BUILD 332 Fix 4: Remove scrollingDown from dynamicBottom.
                          // A barra de input permanece fixa — não se oculta com scroll.
                          final dynamicBottom = kbOpenVal
                              ? 0.0
                              : (nativeBottom + 95.0).clamp(95.0, 160.0);
                          // Congelamento durante streaming: evita AnimatedPadding
                          // rebuildando a cada chunk e sobrecarregando o UI Thread.
                          final _ = keyboardH; // referenciado para suprimir warning
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
                          onSend: () => _sendDebounced(_queryCtrl.text, context.read<AppProvider>()),
                          onCancel: _cancelActiveStream,  // BUILD 327+: abort stream
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
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mini barra de ações mobile — SEMPRE visível no topo da tela de IA no celular.
// Garante acesso a Histórico e Limpar mesmo com teclado aberto ou sem scroll.
// ─────────────────────────────────────────────────────────────────────────────
class _MobileAiActionBar extends StatelessWidget {
  final bool dark;
  final String lang;
  final int historyCount;
  final bool hasMessages;
  final bool hasRealAi;
  final bool keyLoading;
  final bool forceDisconnectedLabel; // BUILD 275: show 'Desconectado' for non-admin
  final bool isConnected; // SUPER ORDEM ESTRUTURAL 11: M+ vivo
  final bool isPartner; // BUILD 310: Ambassador golden button
  final String partnerTitle; // BUILD 310: partner badge label
  final VoidCallback onHistory;
  final VoidCallback onClear;
  final VoidCallback onSettings;
  final VoidCallback? onNewChat;
  final VoidCallback? onAmbassador; // BUILD 310

  const _MobileAiActionBar({
    super.key,
    required this.dark,
    required this.lang,
    required this.historyCount,
    required this.hasMessages,
    required this.hasRealAi,
    required this.keyLoading,
    required this.onHistory,
    required this.onClear,
    required this.onSettings,
    this.forceDisconnectedLabel = false,
    this.isConnected = false,
    this.isPartner = false,
    this.partnerTitle = '',
    this.onNewChat,
    this.onAmbassador,
  });

  @override
  Widget build(BuildContext context) {
    // ═══════════════════════════════════════════════════════════════════
    // BUILD 331 IA — TOPBAR CORRIGIDA: Stack com ordem Z explícita
    //
    // Fundo: SEMPRE #111622 dark sólido — sem adaptação ao tema do sistema.
    //
    // ORDEM DOS FILHOS DA STACK (Z-order, último = acima):
    //   1. IgnorePointer → RichText bicolor no centro geométrico
    //      Envolvido em IgnorePointer para que toques NÃO sejam absorvidos
    //      pelo texto — passam para widgets abaixo (área vazia do centro).
    //   2. Align(centerLeft) → GestureDetector → botão de conexão IA
    //      Renderizado por último → Z-order acima do título → recebe
    //      todos os eventos de toque na zona esquerda sem interferência.
    //   3. Align(centerRight) → SizedBox(40×40) completamente vazia
    //      Simetria visual: balanceia o peso horizontal da barra.
    //
    // MOTIVO DO DESCARTE DO NavigationToolbar:
    //   NavigationToolbar mede seu 'leading' antes de posicionar o 'middle'.
    //   O Container da pílula "Conectar IA" tem largura intrínseca ~95px;
    //   o toolbar tratou isso como ocupação do terço esquerdo e o title ficou
    //   deslocado / invisível. Stack com IgnorePointer resolve sem ambiguidade.
    // ═══════════════════════════════════════════════════════════════════
    // ═══════════════════════════════════════════════════════════════════
    // TOPBAR GEOMETRY — View.of(context) bypass
    //
    // PROBLEMA RAIZ: MainShell usa MediaQuery.removePadding(removeTop:true)
    // antes do IndexedStack. Qualquer SafeArea(top:true) ou
    // MediaQuery.of(ctx).padding.top dentro das telas recebe 0 — o inset
    // já foi consumido. O bypass correto é ler o padding FÍSICO diretamente
    // da FlutterView, que é imune ao removePadding do MediaQuery.
    //
    // View.of(context).padding.top → padding em logical pixels físicos
    // (já normalizado pelo devicePixelRatio internamente pelo Flutter).
    //
    // ESTRUTURA RESULTANTE:
    //   Container (fundo #111622, altura = topPad + 56)
    //     └── Padding(top: topPad)          ← empurra conteúdo abaixo do notch
    //           └── SizedBox(height: 56)    ← área interativa fixa
    //                 └── Stack (botão esq + título + espaço dir)
    // ═══════════════════════════════════════════════════════════════════
    final double topPad = View.of(context).padding.top /
        View.of(context).devicePixelRatio;

    return Container(
      width: double.infinity,
      height: topPad + 56,
      decoration: BoxDecoration(
        color: const Color(0xFF111622), // dark sólido — sangra até o topo físico
        border: const Border(
          bottom: BorderSide(color: Color(0xFF2D3340), width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        // Empurra o conteúdo interativo para baixo da Dynamic Island / Notch.
        // Não usa SafeArea aqui — o padding físico real já foi capturado acima.
        padding: EdgeInsets.only(top: topPad),
        child: SizedBox(
          height: 56,
          child: Stack(
            children: [

              // ── 1. BOTÃO DA ESQUERDA — POSIÇÃO ABSOLUTA, NUNCA SOBREPÕE O TÍTULO ──
              Positioned(
                left: 17, // BUILD 339: +5px de respiro em relação à quina física
                top: 0,
                bottom: 0,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: onSettings,
                    behavior: HitTestBehavior.opaque,
                    child: isConnected
                        // Conectado: avatar M+ verde pulsante
                        ? const _MplusPulse()
                        // Desconectado: pílula ciana com borda e texto branco
                        : Container(
                            height: 30,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(7),
                              color: const Color(0xFF00E5FF).withOpacity(0.10),
                              border: Border.all(
                                color: const Color(0xFF00E5FF).withOpacity(0.60),
                                width: 1.2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              'Conectar IA',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ),
                  ),
                ),
              ),

              // ── 2. TÍTULO — CENTRO GEOMÉTRICO ABSOLUTO ──────────────────
              Align(
                alignment: Alignment.center,
                child: RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(
                        text: 'MEDCASES ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: Colors.white,
                        ),
                      ),
                      TextSpan(
                        text: 'IA',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: Color(0xFFD4AF37), // DOURADO PREMIUM
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── BUILD 310: AMBASSADOR GOLDEN BUTTON (RIGHT) ─────────────
              // Invisible to non-partners — Apple Safe.
              if (isPartner && onAmbassador != null)
                Positioned(
                  right: 12,
                  top: 0,
                  bottom: 0,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: onAmbassador,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        height: 30,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(7),
                          color: const Color(0xFFD4AF37).withOpacity(0.15),
                          border: Border.all(
                            color: const Color(0xFFD4AF37).withOpacity(0.70),
                            width: 1.2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('👑', style: TextStyle(fontSize: 13)),
                            const SizedBox(width: 4),
                            Text(
                              partnerTitle.isNotEmpty ? partnerTitle : 'Embaixador',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFD4AF37),
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

            ],
          ),
        ),
      ),
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// SUPER ORDEM ESTRUTURAL 11 — M+ VIVO
// Widget de respiração: AnimationController loop forward↔reverse (1.5s).
// Usado em _MobileAiActionBar e _WaHeader quando IA está conectada.
// Dispose automático pelo ciclo de vida StatefulWidget — sem memory leak.
// ─────────────────────────────────────────────────────────────────────────────
class _MplusPulse extends StatefulWidget {
  final double opacity; // ignorado internamente — mantido para compatibilidade de chamada
  const _MplusPulse({this.opacity = 1.0});
  @override
  State<_MplusPulse> createState() => _MplusPulseState();
}

class _MplusPulseState extends State<_MplusPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..addStatusListener((status) {
        if (!mounted) return;
        if (status == AnimationStatus.completed) _ctrl.reverse();
        if (status == AnimationStatus.dismissed) _ctrl.forward();
      });
    _anim = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: const Text(
          'M+',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF10B981), // Verde Clínico — IA conectada
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header fino — estilo WhatsApp
// ─────────────────────────────────────────────────────────────────────────────
class _WaHeader extends StatelessWidget {
  final bool dark;
  final bool hasMessages;
  final VoidCallback onClear;
  final VoidCallback onSettings;
  final VoidCallback onHistory;
  final VoidCallback onNewChat;
  final int historyCount;
  final String lang;
  final bool hasRealAi;
  final bool geminiConnected;
  final bool keyLoading;
  final bool forceDisconnectedLabel; // BUILD 275: 'Desconectado' for non-admin
  final bool isConnected; // SUPER ORDEM ESTRUTURAL 11: M+ vivo
  final bool isPartner; // BUILD 310: Ambassador golden button
  final String partnerTitle; // BUILD 310
  final VoidCallback? onAmbassador; // BUILD 310
  const _WaHeader({
    required this.dark,
    required this.hasMessages,
    required this.onClear,
    required this.onSettings,
    required this.onHistory,
    required this.onNewChat,
    required this.historyCount,
    required this.lang,
    required this.hasRealAi,
    this.geminiConnected = false,
    this.keyLoading = false,
    this.forceDisconnectedLabel = false,
    this.isConnected = false,
    this.isPartner = false,
    this.partnerTitle = '',
    this.onAmbassador,
  });

  @override
  Widget build(BuildContext context) {
    // SUPER ORDEM MASTER 12 M1: BLACK TOPBAR FIXO — mesmo preto absoluto em qualquer modo
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0C0E12),
        border: Border(bottom: BorderSide(
          color: Color(0xFF1E2128),
          width: 0.5,
        )),
      ),
      child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 10, 8), // SUPER ORDEM MASTER 308 M2: 52px (+5px)
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Linha 1: seta voltar + título + ações ──────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Back arrow — consistência com todas as telas secundárias
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white, size: 20),
                    onPressed: () => Navigator.maybePop(context),
                    padding: const EdgeInsets.all(8),
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),

                  // Título bicolor MEDCASES (branco) + IA (ouro) + subtítulo split
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RichText(
                          text: const TextSpan(
                            children: [
                              TextSpan(
                                text: 'MEDCASES',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              TextSpan(
                                text: ' IA',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFD4AF37),
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // SUPER ORDEM ESTRUTURAL 11: subtítulo MEDCASES PRO
                        // destruído — substituído pelo M+ vivo como leading direito.
                      ],
                    ),
                  ),

                  // ── BUILD 310: AMBASSADOR GOLDEN BUTTON — Apple Safe ─────
                  if (isPartner && onAmbassador != null) ...[
                    GestureDetector(
                      onTap: onAmbassador,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        height: 28,
                        padding: const EdgeInsets.symmetric(horizontal: 9),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(7),
                          color: const Color(0xFFD4AF37).withOpacity(0.13),
                          border: Border.all(
                            color: const Color(0xFFD4AF37).withOpacity(0.60),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('👑', style: TextStyle(fontSize: 11)),
                            const SizedBox(width: 4),
                            Text(
                              partnerTitle.isNotEmpty ? partnerTitle : 'Embaixador',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFD4AF37),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],

                  // ── M+ VIVO — status da IA — SUPER ORDEM ESTRUTURAL 11 ────
                  GestureDetector(
                    onTap: onSettings,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      child: isConnected
                          ? _MplusPulse(opacity: 1.0) // animação gerenciada internamente
                          : const Text(
                              'Conectar IA',
                              style: TextStyle(
                                fontSize: 13, // SUPER ORDEM MASTER 12 M2: 12→13
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF00E5FF),
                                letterSpacing: -0.2,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 4),

                  // ── Ações direita — M308 M2: botões mais finos/delicados ──
                  // Botão histórico
                  GestureDetector(
                    onTap: onHistory,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.white.withOpacity(0.06),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.08),
                              width: 0.8,
                            ),
                          ),
                          child: Icon(Icons.history_rounded, size: 14,
                            color: Colors.white.withOpacity(0.70)),
                        ),
                        if (historyCount > 0)
                          Positioned(
                            top: -3, right: -3,
                            child: Container(
                              width: 12, height: 12,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFFC5A365),
                              ),
                              child: Center(
                                child: Text(
                                  '$historyCount',
                                  style: const TextStyle(
                                    fontSize: 6.5,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1A1D23),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 5),

                  // ── Botão Novo Chat — ícone minimalista ───────────────────
                  GestureDetector(
                    onTap: onNewChat,
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: const Color(0xFF00E5FF).withOpacity(0.10),
                        border: Border.all(
                          color: const Color(0xFF00E5FF).withOpacity(0.28),
                          width: 0.8,
                        ),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        size: 15,
                        color: Color(0xFF00E5FF),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),

                  // Botão menu
                  GestureDetector(
                    onTap: () => Scaffold.of(context).openEndDrawer(),
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white.withOpacity(0.06),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                          width: 0.8,
                        ),
                      ),
                      child: Icon(Icons.menu_rounded, size: 14,
                        color: Colors.white.withOpacity(0.70)),
                    ),
                  ),
                ],
              ),

              // Linha 2 removida — badge movido para a linha do título
            ],
          ),
        ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _GoogleAuthBarrierCard — SUPER ORDEM 42 M4
// Card proeminente centralizado para usuários não autenticados.
// Exibido quando forceDisconnectedLabel=true && _messages.isEmpty.
// Substitui o WiFi-off overlay com CTA de Google Sign-In.
// ─────────────────────────────────────────────────────────────────────────────
class _GoogleAuthBarrierCard extends StatelessWidget {
  final bool dark;
  final String lang;
  final VoidCallback? onConnect;
  const _GoogleAuthBarrierCard({
    required this.dark,
    required this.lang,
    this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    final isEs = lang == 'es';
    final cardBg = dark
        ? const Color(0xFF1E2128)
        : Colors.white;
    final borderColor = dark
        ? const Color(0xFF2D3340)
        : const Color(0xFFE5E0D8);
    final titleColor = dark ? Colors.white : const Color(0xFF1A1D23);
    final subtitleColor = dark
        ? Colors.white.withOpacity(0.55)
        : Colors.black.withOpacity(0.45);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28.0),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(dark ? 0.40 : 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Google logo icon ─────────────────────────────────────────
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dark
                      ? const Color(0xFF252930)
                      : const Color(0xFFF5F3EE),
                  border: Border.all(
                    color: borderColor,
                    width: 1.0,
                  ),
                ),
                child: const Center(
                  child: Text(
                    'G',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4285F4), // Google blue
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Headline ─────────────────────────────────────────────────
              Text(
                isEs
                    ? 'Conecta tu cuenta Google'
                    : 'Conecte sua conta Google',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: titleColor,
                  letterSpacing: -0.3,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),

              // ── Subtitle / value prop ─────────────────────────────────────
              Text(
                isEs
                    ? 'para activar la Inteligencia Artificial Gratuita'
                    : 'para ativar a Inteligência Artificial Gratuita',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: subtitleColor,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),

              // ── CTA Button ───────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onConnect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4285F4),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '🔑',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isEs
                            ? 'Conectar con Google'
                            : 'Conectar com o Google',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
      .map((line) => line.replaceAllMapped(
            RegExp(r'\*\*([^*]+)\*\*'),
            (m) => m.group(1) ?? '',
          ))
      .toList();

  // ── 2. ALLCAPS label → Title Case ────────────────────────────────────────
  // Only matches standalone label tokens (WORD:) in all-caps.
  // Preserves clinical acronyms (IAM, PCR, mg/kg…) that are mid-sentence.
  const _kLabels = [
    'DOSE', 'DOSAGEM', 'ALERTA', 'ALERTAS', 'ALTERNATIVA',
    'CONDUTA', 'EVITAR', 'MONITORAR', 'MONITORAMENTO',
    'CONTRAINDICACAO', 'CONTRAINDICAÇÕES', 'CONTRAINDICACION',
    'DILUICAO', 'DILUIÇÃO', 'PREPARO', 'INFUSAO', 'INFUSÃO',
    'TITULACAO', 'TITULAÇÃO', 'VELOCIDADE', 'CALCULO', 'CÁLCULO',
    'INTERPRETACAO', 'INTERPRETAÇÃO', 'PROXIMO', 'PRÓXIMO',
    'OBSERVAR', 'OBSERVACAO', 'OBSERVAÇÃO', 'VIGILAR',
  ];
  lines = lines.map((line) {
    for (final label in _kLabels) {
      if (line.contains('$label:')) {
        final titled = label[0].toUpperCase() +
            label.substring(1).toLowerCase();
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
      debugPrint('[BUILD315_JSON_STRIP] action=fence_stripped '
          'originalLen=${trimmed.length} strippedLen=${stripped.length}');
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
  final lastBrace  = text.lastIndexOf('}');
  if (firstBrace < 0 || lastBrace <= firstBrace) return text;

  // Preserva texto antes do '{' como possível cabeçalho/prefixo
  final prefix    = text.substring(0, firstBrace).trim();
  final jsonSlice = text.substring(firstBrace, lastBrace + 1);

  Map<String, dynamic>? jsonMap;
  try {
    jsonMap = jsonDecode(jsonSlice) as Map<String, dynamic>?;
  } catch (_) {
    // JSON inválido → pass-through com fence já removido
    debugPrint('[BUILD315_JSON_STRIP] action=json_parse_failed '
        'slice_len=${jsonSlice.length}');
    return text;
  }
  if (jsonMap == null || jsonMap.isEmpty) return text;

  debugPrint('[BUILD315_JSON_STRIP] action=json_decoded '
      'keys=${jsonMap.keys.toList()} prefix="${prefix.length > 30 ? prefix.substring(0, 30) : prefix}"');

  // ── Estratégia B: JSON com chaves-emoji (🟥, 💊, etc.) ─────────────────
  // Verifica se alguma chave é um emoji-âncora canônico
  const _kAnchors = [
    '🟥', '💊', '🔄', '⛔', '📌', '⚠️',
    '📈', '✅', '❌', '🔎', '🧪', '🧮', '📖',
  ];
  const _kAnchorOrder = [
    '🟥', '💊', '🔄', '⛔', '🔎', '🧪', '🧮', '📖', '📈', '❌', '📌', '✅', '⚠️',
  ];

  final hasEmojiKeys = jsonMap.keys.any(
    (k) => _kAnchors.any((a) => k.contains(a)),
  );

  if (hasEmojiKeys) {
    final sb = StringBuffer();
    // Usa prefixo como linha extra se não começar com emoji
    if (prefix.isNotEmpty && !_kAnchors.any((a) => prefix.startsWith(a))) {
      sb.writeln(prefix);
    }
    // Itera em ordem canônica para garantir sequência correta
    for (final anchor in _kAnchorOrder) {
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
      debugPrint('[BUILD315_JSON_STRIP] action=emoji_keys_converted '
          'outputLen=${result.length}');
      return result;
    }
  }

  // ── Estratégia C: JSON com campos semânticos em texto ─────────────────────
  // Mapeia campos conhecidos para âncoras canônicas
  final _fieldToAnchor = <String, String>{
    // 🟥 conduta / título
    'conduta':        '🟥',
    'conducta':       '🟥',
    'titulo':         '🟥',
    'título':         '🟥',
    'title':          '🟥',
    'conduta_titulo': '🟥',
    'conduta_título': '🟥',
    // 💊 dose / primeira linha
    'dose':           '💊',
    'dosis':          '💊',
    'primeira_linha': '💊',
    'primera_linea':  '💊',
    'medicacao':      '💊',
    'medicación':     '💊',
    'tratamento':     '💊',
    'tratamiento':    '💊',
    // 🔄 alternativa
    'alternativa':    '🔄',
    'segunda_linha':  '🔄',
    'segunda_linea':  '🔄',
    // ⛔ evitar
    'evitar':         '⛔',
    'contraindicado': '⛔',
    'contraindicação':'⛔',
    'contraindicacion':'⛔',
    // 📌 monitorar
    'monitorar':      '📌',
    'monitorizar':    '📌',
    'monitoramento':  '📌',
    'observar':       '📌',
    // ⚠️ alerta
    'alerta':         '⚠️',
    'atencao':        '⚠️',
    'atencion':       '⚠️',
    'aviso':          '⚠️',
  };

  // Constrói saída na ordem canônica mapeando campos
  final anchorLines = <String, String>{};
  for (final entry in jsonMap.entries) {
    final keyNorm = entry.key
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^a-záéíóúàãõâêîôûçñü_0-9]', unicode: true), '');
    final anchor = _fieldToAnchor[keyNorm];
    if (anchor == null) continue;
    final val = entry.value?.toString().trim() ?? '';
    if (val.isEmpty) continue;
    anchorLines.putIfAbsent(anchor, () => val);
  }

  if (anchorLines.isNotEmpty) {
    final sb = StringBuffer();
    if (prefix.isNotEmpty) sb.writeln(prefix);
    for (final anchor in _kAnchorOrder) {
      final val = anchorLines[anchor];
      if (val == null) continue;
      sb.writeln('$anchor $val');
    }
    final result = sb.toString().trim();
    if (result.isNotEmpty) {
      debugPrint('[BUILD315_JSON_STRIP] action=semantic_fields_converted '
          'anchorsFound=${anchorLines.keys.toList()} outputLen=${result.length}');
      return result;
    }
  }

  // Nenhuma estratégia funcionou — retorna o texto com fences removidas
  debugPrint('[BUILD315_JSON_STRIP] action=pass_through_no_mapping '
      'jsonKeys=${jsonMap.keys.toList()}');
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
String _plantaoTruncationGuard(String text, String lang,
    {String userQuery = ''}) {
  if (text.trim().isEmpty) return text;

  // Pass-through se for mensagem de erro de rede (já tratada pelo bloco isNetErr)
  final lower = text.toLowerCase();
  final isErrorMsg = lower.startsWith('erro') ||
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
  print('================================================= '
      'len=${text.length} chars');
  if (text.trim().length < 100) {
    // Resposta suspeita (< 100 chars) — loga alerta explícito sem mascarar
    // ignore: avoid_print
    print('[RAW_AI_OUTPUT] ⚠️  ALERTA: resposta abaixo de 100 caracteres '
        '(len=${text.trim().length}). Possível recusa, erro ou truncamento grave do modelo.');
  }

  // ── Camada 1: PlantaoOrganizer via PlantatoPipeline ──────────────────────
  // Organiza, repara, detecta sinais clínicos. Não bloqueia.
  final pipelineResult = PlantatoPipeline.run(text);
  final parserValid    = pipelineResult.response != null;
  final hasClinical    = pipelineResult.hasClinicalContent;
  final isTruncated    = pipelineResult.isTruncated;
  final hasMetaLeak    = pipelineResult.hasMetaLeak;

  // ── Camada 2: ResponseValidator.shouldFallback() ─────────────────────────
  // ÚNICA fonte de decisão de bloqueio/fallback (BUILD 247).
  final (:fallback, :reason) = AiSmartRouter.shouldFallback(
    parserValid:       parserValid,
    hasClinicalContent: hasClinical,
    isTruncated:       isTruncated,
    hasMetaLeak:       hasMetaLeak,
    repaired:          pipelineResult.repaired,
    orderFixed:        pipelineResult.orderFixed,
    hiddenFields:      pipelineResult.hiddenFields,
    removedLines:      pipelineResult.removedLines,
  );

  // ── Log [RESPONSE_VALIDATOR] ─────────────────────────────────────────────
  debugPrint('[RESPONSE_VALIDATOR] '
      'fallback=$fallback '
      'reason=$reason '
      'parserValid=$parserValid '
      'hasClinical=$hasClinical '
      'isTruncated=$isTruncated '
      'hasMetaLeak=$hasMetaLeak '
      'repaired=${pipelineResult.repaired} '
      'orderFixed=${pipelineResult.orderFixed}');

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
        debugPrint('[PLANTAO_ORGANIZER] action=preserve '
            'reason=has_inline_bold_bypass '
            'hiddenFields=${pipelineResult.hiddenFields}');
        return text;
      }

      // Detecta intenção localmente a partir da query do usuário
      final analysis = PlantaoIntentEngine.analyze(userQuery);
      final intent = analysis.primaryIntent;

      // Aplica template preservando conteúdo clínico
      final reformatted =
          ResponseReformatter.applyTemplate(text, lang, intent, userQuery);

      // Verifica se o reformatter produziu estrutura válida (sanidade)
      final isReformattedStructured =
          ResponseReformatter.isAlreadyStructured(reformatted);

      if (isReformattedStructured && reformatted.length >= text.length * 0.6) {
        debugPrint('[PLANTAO_ORGANIZER] intent=${intent.name} '
            'action=template_applied '
            'preserved=true '
            'reason=$reason '
            'hiddenFields=${pipelineResult.hiddenFields}');
        return reformatted;
      }
      // Se reformatter falhou na sanidade → preserva original com log
      debugPrint('[PLANTAO_ORGANIZER] intent=${intent.name} '
          'action=preserve '
          'reason=reformatter_sanity_failed '
          'hiddenFields=${pipelineResult.hiddenFields}');
      return text;
    }

    final organizeAction = (pipelineResult.repaired || pipelineResult.orderFixed)
        ? 'organize'
        : 'preserve';
    debugPrint('[PLANTAO_ORGANIZER] action=$organizeAction '
        'reason=$reason '
        'hiddenFields=${pipelineResult.hiddenFields}');
    return text; // pass-through — renderer estruturado ou texto plano
  }

  // ── Caminho FALLBACK: ResponseValidator decidiu bloquear ─────────────────
  // Só chega aqui para: meta-leak, truncado sem clínico, sem valor clínico.
  debugPrint('[SAFETY_FALLBACK] fallback=true '
      'reason=$reason '
      'hasClinical=$hasClinical '
      'isTruncated=$isTruncated '
      'hasMetaLeak=$hasMetaLeak');

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
  final isErrorMsg = lower.contains('sem conex') ||
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
    RegExp(r'<think>.*?</think>', caseSensitive: false, dotAll: true), '');
  accumulated = accumulated.replaceAll(
    RegExp(r'</?think[^>]*>', caseSensitive: false), '');

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
      r'^[|\s*]*(?:'                                                          // prefixo: pipe, espaço, asterisco
      r'Confian[zç]a\s*(?:Cl[íi]nica)?\s*(?:[:–—]|Alta|M[eé]dia|Baixa)'    // "Confianza Clínica: Alta"
      r'|Confianza\s+Clinica\s*[:\s]'                                        // sem acento
      r'|Confianca\s+Clinica\s*[:\s]'                                        // PT sem acento
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
//   MAINTAINED FOR: Estudo mode streaming chunks | legacy history _AiBubble display.
//   NÃO REMOVER: remoção causaria regressão no Modo Estudo e no histórico retroativo.
// ─────────────────────────────────────────────────────────────────────────────
String _cleanAiText(String raw) {
  String s = raw;

  // ── 1. Blocos XML de raciocínio interno (qualquer tag de CoT) ────────────
  // Remove tudo entre <thinking>...</thinking>, <scratchpad>...</scratchpad>,
  // <clinical_thinking>...</clinical_thinking>, etc. (greedy=false, dotAll)
  s = s.replaceAll(
    RegExp(
      r'<(thinking|scratchpad|internal|clinical_thinking|reasoning|planning|reflection|analysis|chain_of_thought|cot|thought|inner_monologue)>.*?<\/\1>',
      caseSensitive: false,
      dotAll: true,
    ),
    '',
  );
  // Remove tags órfãs (abertas sem fechar ou vice-versa)
  s = s.replaceAll(
    RegExp(
      r'<\/?(?:thinking|scratchpad|internal|clinical_thinking|reasoning|planning|reflection|analysis|chain_of_thought|cot|thought|inner_monologue)[^>]*>',
      caseSensitive: false,
    ),
    '',
  );

  // ── 2. Blocos de revisão interna com colchetes ────────────────────────────
  // Ex: [REVISAO_INTERNA...FIM_REVISAO_INTERNA] / [REVISION_INTERNA...]
  s = s.replaceAll(
    RegExp(
      r'\[(?:REVISAO_INTERNA|REVISION_INTERNA|FIM_REVISAO_INTERNA|FIN_REVISION_INTERNA|INTERNAL_REVIEW)[^\]]*\]',
      caseSensitive: false,
    ),
    '',
  );
  // Linhas isoladas que comecem com [REVISAO ou [REVISION ou [FIM
  s = s.replaceAll(
    RegExp(
      r'^\[(?:REVISAO|REVISION|FIM|FIN|INTERNAL|CHECKING|REVIEW)[^\]\n]*\]\s*$',
      caseSensitive: false,
      multiLine: true,
    ),
    '',
  );

  // ── 2b. Rótulos de modo interno vazados (Build 126 — PREFIX-ANCHORED) ─────
  // Build 126: cada alternativa agora usa prefixo EXATO de início de linha.
  // REMOVIDAS as alternativas perigosas: CAMADA\s+\d+.* e CAPA\s+\d+.* pois
  // produzem falsos-positivos em texto clínico como "CAMADA MUSCULAR CARDÍACA".
  // Mantidos apenas rótulos do sistema absolutamente inequívocos.
  s = s.replaceAll(
    RegExp(
      r'^(?:'
      r'MODO\s+ACTIVO\s*:?'                     // "MODO ACTIVO:" — rótulo interno
      r'|MODO\s+\[.\]\s+'                        // "MODO [A] ..." — rótulo interno
      r'|MODO\s+CONDUCTA\s'                      // "MODO CONDUCTA DIRECTA"
      r'|MODO\s+CONVERSACIONAL\s'                // "MODO CONVERSACIONAL ..."
      r'|MODO\s+GUARDIA\s'                       // "MODO GUARDIA ..."
      r'|MODO\s+PLANTAO\s'                       // "MODO PLANTAO ..."
      r'|\[REVISIÓN\s+INTERNA\]'                 // tag literal colchete
      r'|\[REVISION_INTERNA\]'
      r'|\[REVISAO_INTERNA\]'
      r'|VERIFICACAO\s+INTERNA\s*:'              // "VERIFICACAO INTERNA:"
      r'|VERIFICACIÓN\s+INTERNA\s*:'
      r'|Confianza\s+Cl[íi]nica\s*:'            // "Confianza Clínica:"
      r'|Confian[çc]a\s+Cl[íi]nica\s*:'         // "Confiança Clínica:"
      r'|Nivel\s+de\s+Confianza\s*:'
      r'|Confianza\s+Clinica\s*:'                // sem acento
      r'|Confianca\s+Clinica\s*:'
      r'|Motivos?\s*(?:\([^)]*\))?\s*:'          // "Motivo:" "Motivos:"
      r'|Motivo\s+del\s+(?:modo|activaci[oó]n)\s*:'
      r'|▶▶▶'                                    // marcador interno do selfCheck
      r').*$',
      caseSensitive: false,
      multiLine: true,
    ),
    '',
  );

  // ── 3. Prefixos de planning/estruturação vazados (Build 126 — TIGHTENED) ──
  // Build 126: removidos prefixos ambíguos curtos ("I need to", "Let me",
  // "Para responder", "Deixe-me") que geravam falsos-positivos em texto clínico.
  // Mantidos apenas os inequívocos e longos.
  final _cotPhrases = RegExp(
    r"^(My response should\s|I will structure\s|Let me think\s|I'll organize\s|"
    r"I should focus on\s|I'm going to\s|Vou estruturar\s|Devo focar\s|"
    r"Mi respuesta debe\s|Voy a estructurar\s|Estructurando la respuesta|"
    r"Pensando en la respuesta|Analizando el caso cl[íi]nico|Analisando o caso cl[íi]nico|"
    r"Antes de responder a\s|Before responding to\s|"
    r"Step \d+:|Paso \d+:|Etapa \d+:|Planning:|Reasoning:|Chain of thought:).*",
    caseSensitive: false,
    multiLine: true,
  );
  s = s.replaceAll(_cotPhrases, '');

  // ── 4. Linhas de meta-comentário (Build 126 — removidos "Let me"/"Deixe-me") ──
  // "Let me" é ambíguo: "Let me clarify the dose..." é texto clínico legítimo.
  // "Deixe-me ver os critérios de Framingham..." também é legítimo.
  // Mantidos apenas os padrões mais longos e inequívocos.
  s = s.replaceAll(
    RegExp(
      r'^(Agora vou\s|Now I will\s|I will now\s|Vou agora\s|Ahora voy a\s|'
      r'Deixa eu pensar\s|Thinking\.\.\.|Analyzing\.\.\.|Processing\.\.\.).*$',
      caseSensitive: false,
      multiLine: true,
    ),
    '',
  );

  // ── 4c. PURGA PROFUNDA — Monólogo em 3ª pessoa multi-linha ──────────────
  // Captura blocos/sentenças iniciados por padrões de meta-raciocínio em 3ª pessoa.
  // Exemplos reais vazados do TestFlight:
  //   "O usuário solicitou um diagnóstico diferencial. O prompt é muito vago..."
  //   "Para fornecer uma resposta útil, preciso de mais informações..."
  //   "A base de dados local não possui um mapeamento específico..."
  //   "Portanto, a melhor abordagem é solicitar mais detalhes ao usuário..."

  // Padrão PT — linhas inteiras que começam com meta-raciocínio em 3ª pessoa
  s = s.replaceAll(
    RegExp(
      r'^(?:'
      r'O\s+usu[aá]rio\s+(?:solicitou|pediu|informou|forneceu|indicou|est[aá])'
      r'|O\s+m[eé]dico\s+(?:solicita|pergunta|pediu|quer|solicitou)'
      r'|Para\s+fornecer\s+uma\s+resposta\s+(?:[uú]til|adequada|completa)'
      r'|Para\s+(?:poder\s+)?(?:dar|fornecer|oferecer)\s+(?:uma\s+)?(?:resposta|conduta|informa)'
      r'|A\s+base\s+de\s+dados\s+(?:local\s+)?n[aã]o\s+(?:possui|cont[eé]m|tem|encontrou)'
      r'|Portanto,?\s+a\s+melhor\s+(?:abordagem|estrategia|opcao)'
      r'|O\s+prompt\s+(?:[eé]|parece|est[aá])\s+(?:muito\s+)?(?:vago|incompleto|ambiguo|curto|insuficiente)'
      r'|N[aã]o\s+(?:encontrei|tenho|possuo)\s+(?:dados|informacoes|contexto)\s+suficientes'
      r'|Precisaria\s+de\s+mais\s+(?:informacoes|dados|contexto|detalhes)'
      r'|Com\s+base\s+no\s+que\s+o\s+usu[aá]rio'
      r'|Baseado\s+(?:no|na|em)\s+(?:contexto|conversa|solicitacao|que\s+foi)'
      r'|A\s+seguir\s+(?:apresentarei|descrevo|apresento|fornecerei)'
      r'|O\s+(?:pedido|contexto|prompt|input)\s+(?:[eé]|est[aá]|foi|parece)'
      r').*$',
      caseSensitive: false,
      multiLine: true,
    ),
    '',
  );

  // Padrão ES — equivalente espanhol
  s = s.replaceAll(
    RegExp(
      r'^(?:'
      r'El\s+usuario\s+(?:solicit[oó]|pidi[oó]|indic[oó]|ha\s+(?:pedido|indicado|solicitado))'
      r'|El\s+m[eé]dico\s+(?:solicita|pregunta|ha\s+pedido|quiere)'
      r'|Para\s+proporcionar\s+una\s+respuesta\s+(?:[uú]til|adecuada|completa)'
      r'|Para\s+(?:poder\s+)?(?:dar|proporcionar|ofrecer)\s+(?:una\s+)?(?:respuesta|conducta|informa)'
      r'|La\s+base\s+de\s+datos\s+(?:local\s+)?no\s+(?:contiene|tiene|posee|encontr[oó])'
      r'|Por\s+lo\s+tanto,?\s+la\s+mejor\s+(?:estrategia|opci[oó]n|abordaje|aproximaci[oó]n)'
      r'|El\s+prompt\s+(?:es|parece|est[aá])\s+(?:muy\s+)?(?:vago|incompleto|ambiguo|corto|insuficiente)'
      r'|No\s+(?:encontr[eé]|tengo|poseo)\s+(?:datos|informaci[oó]n|contexto)\s+suficientes?'
      r'|Necesitar[ií]a\s+(?:m[aá]s\s+)?(?:informaci[oó]n|datos|contexto|detalles)'
      r'|Con\s+base\s+en\s+(?:lo\s+que\s+el\s+usuario|la\s+solicitud)'
      r'|Basado\s+en\s+(?:el\s+contexto|la\s+conversaci[oó]n|la\s+solicitud|lo\s+que)'
      r'|A\s+continuaci[oó]n\s+(?:presento|presentar[eé]|describir[eé]|proporcionar[eé])'
      r'|La\s+(?:pregunta|solicitud|consulta|query)\s+(?:es|parece|est[aá]|resulta)'
      r').*$',
      caseSensitive: false,
      multiLine: true,
    ),
    '',
  );

  // ── 4b. EXPURGO DE METADADOS (Build 126 — PREFIX-ANCHORED, SEM GREEDY) ────
  //
  // Build 126 FIX CRÍTICO: substituída regex `^.*Confian[zç]a.*$` (catch-all
  // destrutivo) por match de prefixo exato. A versão anterior apagava linhas
  // clínicas legítimas que continham "confiança" como parte do texto médico,
  // gerando o artefato "ElEl" em produção.
  //
  // NOVA POLÍTICA: eliminar SOMENTE linhas que COMEÇAM com o metadado.
  // Uma linha como "IAM — diagnóstico com alta confiança clínica" passa intacta.
  s = s.replaceAll(
    RegExp(
      r'^[|\s*]*(?:'
      r'Confian[zç]a\s*(?:Cl[íi]nica)?\s*(?:[:–—]|Alta|M[eé]dia|Baixa)'    // "Confiança Clínica: Alta"
      r'|Confianza\s+Clinica\s*[:\s]'
      r'|Confianca\s+Clinica\s*[:\s]'
      r'|Clinical\s+Confidence\s*:'
      r'|Nivel\s+de\s+Confianza\s*:'
      r'|N[íi]vel\s+de\s+Confian[çc]a\s*:'
      r'|El\s+usuario\s+(?:solicita|proporciona|pregunta|pide|quiere|busca|ha\s+(?:indicado|pedido|proporcionado|solicitado)|solicit[oó])'
      r'|O\s+usu[aá]rio\s+(?:solicita|fornece|pergunta|pede|quer|busca|indicou|solicitou|informou|est[aá]\s+perguntando)'
      r'|The\s+user\s+(?:is\s+asking|asks|wants|requests|provides|has\s+indicated|has\s+asked)'
      r'|El\s+m[eé]dico\s+(?:solicita|pregunta|pide|ha\s+pedido)'
      r'|O\s+m[eé]dico\s+(?:solicita|pergunta|pede|solicitou)'
      r'|Baseado\s+(?:no|na|em)\s+(?:contexto|conversa|solicitac|que\s+(?:o\s+usu|foi))'
      r'|Basado\s+en\s+(?:el\s+contexto|la\s+conversaci[oó]n|la\s+solicitud|lo\s+que)'
      r'|Para\s+proporcionar\s+una\s+respuesta'
      r'|Para\s+fornecer\s+uma\s+resposta'
      r'|La\s+base\s+de\s+datos\s+(?:local\s+)?no\s+(?:contiene|tiene|posee)'
      r'|A\s+base\s+de\s+dados\s+(?:local\s+)?n[aã]o\s+(?:possui|cont[eé]m|tem)'
      r'|Por\s+lo\s+tanto,\s+(?:la\s+mejor|el\s+mejor)'
      r'|Portanto,\s+a\s+melhor\s+abordagem'
      r'|(?:El|La)\s+prompt\s+(?:es|parece)\s+(?:vago|incompleto)'
      r'|O\s+prompt\s+(?:[eé]|parece)\s+(?:vago|incompleto)'
      r'|A\s+seguir\s+(?:apresentarei|descrevo|apresento)'
      r'|A\s+continuaci[oó]n\s+(?:presento|presentar[eé])'
      r'|Motivos?\s*(?:\([^)]*\))?\s*:'
      r'|Motivo\s+del\s+(?:modo|activaci[oó]n)\s*:'
      r').*$',
      caseSensitive: false,
      multiLine: true,
    ),
    '',
  );

  // ── 5. Sanitização final de formatação ───────────────────────────────────
  s = s
      // ## e ### NÃO são removidos aqui — MarkdownBody renderiza H2/H3
      // nativamente via MarkdownStyleSheet (h2/h3 com tipografia clínica)
      .replaceAll('---', '')                                     // separadores HR
      .replaceAll('--', '')                                      // traços duplos
      .replaceAll(RegExp(r'\*{3,}'), '');                        // *** ou mais

  // ── 5b. FALLBACK ANTI-ASTERISCO — camada de segurança Flutter ────────────
  // Build 115 FIX CRÍTICO: A regex original '(?<!\*)\*(?!\*)' destruía
  // marcadores de lista como '* Levodopa:' → ' Levodopa:' ANTES de
  // _isListItem() ter chance de detectá-los. Isso causava dois bugs:
  //   1. Asteriscos visíveis: o texto escapava sem ser detectado como lista
  //   2. Fragmentação: sem detecção de lista, _splitIntoBlocks() criava
  //      um _AiBlockBubble por parágrafo separado por \n\n
  //
  // NOVA ESTRATÉGIA: Processamento linha a linha para PRESERVAR marcadores
  // de lista ('* texto', '* **Negrito') e remover apenas asteriscos realmente
  // soltos (itálico Markdown não suportado, asteriscos ornamentais, etc.).
  final lines5b = s.split('\n');
  final fixed5b = lines5b.map((line) {
    final t = line.trimLeft();
    // Linha que começa com '* ' (bullet clássico) — PRESERVAR INTACTA
    if (t.startsWith('* ')) return line;
    // Linha que começa com '* **' (bullet + negrito) — PRESERVAR INTACTA
    if (RegExp(r'^\*\s*\*\*').hasMatch(t)) return line;
    // Linha que começa com '*Texto' sem espaço (Gemini Flash-Lite) — PRESERVAR
    if (RegExp(r'^\*[^*\s]').hasMatch(t)) return line;
    // Para todas as outras linhas: remove * simples não-duplos (itálico/ornamental)
    return line.replaceAll(RegExp(r'(?<!\*)\*(?!\*)'), '');
  }).toList();
  s = fixed5b.join('\n');

  // ── 6. Normaliza linhas em branco excessivas (≥3 → 2) ────────────────────
  s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');

  // ── 7. NORMALIZADOR DE ACENTUAÇÃO MÉDICA — Safety Net Unicode ─────────────
  // Restaura acentuação correta em termos médicos estruturais que o modelo
  // às vezes emite sem acento (copiando labels do system prompt interno).
  //
  // ESTRATÉGIA: substituição por palavra inteira (word-boundary via look-ahead/
  // look-behind de não-letra) para não afetar substrings de outras palavras.
  // Opera somente em UPPERCASE para não alterar texto clínico em minúsculo.
  //
  // PORTUGUÊS — termos estruturais de saída (§ sections e emoji-headers):
  s = s
    // § section labels — Anatomia Fármaco
    .replaceAll(RegExp(r'\bDEFINICAO\b'), 'DEFINIÇÃO')
    .replaceAll(RegExp(r'\bINDICACAO\b'), 'INDICAÇÃO')
    .replaceAll(RegExp(r'\bINDICACOES\b'), 'INDICAÇÕES')
    .replaceAll(RegExp(r'\bPOSOLOGIA\b'), 'POSOLOGIA')   // já correto, garante
    .replaceAll(RegExp(r'\bADMINISTRACAO\b'), 'ADMINISTRAÇÃO')
    .replaceAll(RegExp(r'\bMONITORIZACAO\b'), 'MONITORIZAÇÃO')
    .replaceAll(RegExp(r'\bMONITORIZACOES\b'), 'MONITORIZAÇÕES')
    .replaceAll(RegExp(r'\bCONTRAINDICACAO\b'), 'CONTRAINDICAÇÃO')
    .replaceAll(RegExp(r'\bCONTRAINDICACAOES\b'), 'CONTRAINDICAÇÕES')
    .replaceAll(RegExp(r'\bCONTRAINDICACOES\b'), 'CONTRAINDICAÇÕES')
    .replaceAll(RegExp(r'\bPRESCRICAO\b'), 'PRESCRIÇÃO')
    .replaceAll(RegExp(r'\bINTERACAO\b'), 'INTERAÇÃO')
    .replaceAll(RegExp(r'\bINTERACOES\b'), 'INTERAÇÕES')
    .replaceAll(RegExp(r'\bAVALIACAO\b'), 'AVALIAÇÃO')
    .replaceAll(RegExp(r'\bEFEITOS ADVERSOS\b'), 'EFEITOS ADVERSOS') // já OK
    // emoji-header section titles
    .replaceAll(RegExp(r'\bMEDICACAO\b'), 'MEDICAÇÃO')
    .replaceAll(RegExp(r'\bMEDICACOES\b'), 'MEDICAÇÕES')
    .replaceAll(RegExp(r'\bESCALONAMENTO\b'), 'ESCALONAMENTO')       // já OK
    .replaceAll(RegExp(r'\bFARMACO\b'), 'FÁRMACO')
    .replaceAll(RegExp(r'\bFARMACOS\b'), 'FÁRMACOS')
    // ESPANHOL — termos estruturais de saída:
    .replaceAll(RegExp(r'\bDEFINICION\b'), 'DEFINICIÓN')
    .replaceAll(RegExp(r'\bINDICACION\b'), 'INDICACIÓN')
    .replaceAll(RegExp(r'\bINDICACIONES\b'), 'INDICACIONES')          // já OK
    .replaceAll(RegExp(r'\bDOSIFICACION\b'), 'DOSIFICACIÓN')
    .replaceAll(RegExp(r'\bADMINISTRACION\b'), 'ADMINISTRACIÓN')
    .replaceAll(RegExp(r'\bMONITORIZACION\b'), 'MONITORIZACIÓN')
    .replaceAll(RegExp(r'\bINTERACCION\b'), 'INTERACCIÓN')
    .replaceAll(RegExp(r'\bINTERACCIONES\b'), 'INTERACCIONES')        // já OK
    .replaceAll(RegExp(r'\bCONTRAINDICACION\b'), 'CONTRAINDICACIÓN')
    .replaceAll(RegExp(r'\bCONTRAINDICACIONES\b'), 'CONTRAINDICACIONES')
    .replaceAll(RegExp(r'\bPRESCRIPCION\b'), 'PRESCRIPCIÓN')
    .replaceAll(RegExp(r'\bINDICACION\b'), 'INDICACIÓN')
    .replaceAll(RegExp(r'\bREACCION\b'), 'REACCIÓN')
    .replaceAll(RegExp(r'\bREACCIONES ADVERSAS\b'), 'REACCIONES ADVERSAS')
    .replaceAll(RegExp(r'\bFARMACOLOGIA\b'), 'FARMACOLOGÍA')
    .replaceAll(RegExp(r'\bINTERACCIONES FARMACOLOGICAS\b'), 'INTERACCIONES FARMACOLÓGICAS')
    // ── Build 100: Expansão Step 7 — seções clínicas de alta frequência ──────
    // Camada 2 do modelo emite esses títulos sem acento quando copia do
    // _responseFormatPt/_responseFormatEs que por segurança usa texto sem acentos.
    // PORTUGUÊS — seções adicionais da Camada 2:
    .replaceAll(RegExp(r'\bHIDRATACAO\b'), 'HIDRATAÇÃO')
    .replaceAll(RegExp(r'\bVENTILACAO\b'), 'VENTILAÇÃO')
    .replaceAll(RegExp(r'\bINTUBACAO\b'), 'INTUBAÇÃO')
    .replaceAll(RegExp(r'\bCOAGULACAO\b'), 'COAGULAÇÃO')
    .replaceAll(RegExp(r'\bINTOXICACAO\b'), 'INTOXICAÇÃO')
    .replaceAll(RegExp(r'\bFIBRILACAO ATRIAL\b'), 'FIBRILAÇÃO ATRIAL')
    .replaceAll(RegExp(r'\bFIBRILACAO VENTRICULAR\b'), 'FIBRILAÇÃO VENTRICULAR')
    .replaceAll(RegExp(r'\bFIBRILACAO\b'), 'FIBRILAÇÃO')
    .replaceAll(RegExp(r'\bDISFUNCAO\b'), 'DISFUNÇÃO')
    .replaceAll(RegExp(r'\bHIPOGLICEMIA\b'), 'HIPOGLICEMIA')   // já correto
    .replaceAll(RegExp(r'\bHIPERGLICEMIA\b'), 'HIPERGLICEMIA') // já correto
    .replaceAll(RegExp(r'\bINSUFICIENCIA CARDIACA\b'), 'INSUFICIÊNCIA CARDÍACA')
    .replaceAll(RegExp(r'\bINSUFICIENCIA RENAL\b'), 'INSUFICIÊNCIA RENAL')
    .replaceAll(RegExp(r'\bINSUFICIENCIA RESPIRATORIA\b'), 'INSUFICIÊNCIA RESPIRATÓRIA')
    .replaceAll(RegExp(r'\bINSUFICIENCIA HEPATICA\b'), 'INSUFICIÊNCIA HEPÁTICA')
    .replaceAll(RegExp(r'\bTROMBOEMBOLISMO PULMONAR\b'), 'TROMBOEMBOLISMO PULMONAR') // já OK
    .replaceAll(RegExp(r'\bACIDENTE VASCULAR CEREBRAL\b'), 'ACIDENTE VASCULAR CEREBRAL') // já OK
    .replaceAll(RegExp(r'\bPROFILAXIA\b'), 'PROFILAXIA')         // já correto
    .replaceAll(RegExp(r'\bDIAGNOSTICO DIFERENCIAL\b'), 'DIAGNÓSTICO DIFERENCIAL')
    .replaceAll(RegExp(r'\bDIAGNOSTICO\b'), 'DIAGNÓSTICO')
    .replaceAll(RegExp(r'\bEMERGENCIA\b'), 'EMERGÊNCIA')
    .replaceAll(RegExp(r'\bTRATAMENTO EMPIRICO\b'), 'TRATAMENTO EMPÍRICO')
    .replaceAll(RegExp(r'\bTRATAMENTO FARMACOLOGICO\b'), 'TRATAMENTO FARMACOLÓGICO')
    .replaceAll(RegExp(r'\bESTABILIZACAO\b'), 'ESTABILIZAÇÃO')
    .replaceAll(RegExp(r'\bEVOLUCAO\b'), 'EVOLUÇÃO')
    .replaceAll(RegExp(r'\bSEDASAO\b'), 'SEDAÇÃO')
    .replaceAll(RegExp(r'\bSEDASAO E ANALGESIA\b'), 'SEDAÇÃO E ANALGESIA')
    .replaceAll(RegExp(r'\bANALGESIA\b'), 'ANALGESIA')           // já correto
    .replaceAll(RegExp(r'\bANTICOAGULACAO\b'), 'ANTICOAGULAÇÃO')
    .replaceAll(RegExp(r'\bTRANSFUSAO\b'), 'TRANSFUSÃO')
    .replaceAll(RegExp(r'\bINFECCAO\b'), 'INFECÇÃO')
    .replaceAll(RegExp(r'\bINFECCAO DO TRATO\b'), 'INFECÇÃO DO TRATO')
    .replaceAll(RegExp(r'\bCOMPLICACAO\b'), 'COMPLICAÇÃO')
    .replaceAll(RegExp(r'\bCOMPLICACOES\b'), 'COMPLICAÇÕES')
    .replaceAll(RegExp(r'\bATENCAO\b'), 'ATENÇÃO')
    .replaceAll(RegExp(r'\bRECOMENDACAO\b'), 'RECOMENDAÇÃO')
    .replaceAll(RegExp(r'\bRECOMENDACOES\b'), 'RECOMENDAÇÕES')
    .replaceAll(RegExp(r'\bINFUSOES\b'), 'INFUSÕES')
    .replaceAll(RegExp(r'\bINFUSAO\b'), 'INFUSÃO')
    .replaceAll(RegExp(r'\bASSICIACAO\b'), 'ASSOCIAÇÃO')
    .replaceAll(RegExp(r'\bASSOCIACAO\b'), 'ASSOCIAÇÃO')
    // ESPANHOL — seções adicionais da Capa 2:
    .replaceAll(RegExp(r'\bHIDRATACION\b'), 'HIDRATACIÓN')
    .replaceAll(RegExp(r'\bVENTILACION\b'), 'VENTILACIÓN')
    .replaceAll(RegExp(r'\bINTUBACION\b'), 'INTUBACIÓN')
    .replaceAll(RegExp(r'\bCOAGULACION\b'), 'COAGULACIÓN')
    .replaceAll(RegExp(r'\bINTOXICACION\b'), 'INTOXICACIÓN')
    .replaceAll(RegExp(r'\bFIBRILACION AURICULAR\b'), 'FIBRILACIÓN AURICULAR')
    .replaceAll(RegExp(r'\bFIBRILACION VENTRICULAR\b'), 'FIBRILACIÓN VENTRICULAR')
    .replaceAll(RegExp(r'\bFIBRILACION\b'), 'FIBRILACIÓN')
    .replaceAll(RegExp(r'\bDISFUNCION\b'), 'DISFUNCIÓN')
    .replaceAll(RegExp(r'\bINSUFICIENCIA CARDIACA\b'), 'INSUFICIENCIA CARDÍACA')
    .replaceAll(RegExp(r'\bINSUFICIENCIA RENAL\b'), 'INSUFICIENCIA RENAL')       // já OK
    .replaceAll(RegExp(r'\bINSUFICIENCIA RESPIRATORIA\b'), 'INSUFICIENCIA RESPIRATORIA') // já OK
    .replaceAll(RegExp(r'\bDIAGNOSTICO DIFERENCIAL\b'), 'DIAGNÓSTICO DIFERENCIAL')
    .replaceAll(RegExp(r'\bEMERGENCIA\b'), 'EMERGENCIA')         // sem acento em ES — já OK
    .replaceAll(RegExp(r'\bESTABILIZACION\b'), 'ESTABILIZACIÓN')
    .replaceAll(RegExp(r'\bEVOLUCION\b'), 'EVOLUCIÓN')
    .replaceAll(RegExp(r'\bSEDACION\b'), 'SEDACIÓN')
    .replaceAll(RegExp(r'\bANTICOAGULACION\b'), 'ANTICOAGULACIÓN')
    .replaceAll(RegExp(r'\bTRANSFUSION\b'), 'TRANSFUSIÓN')
    .replaceAll(RegExp(r'\bINFECCION\b'), 'INFECCIÓN')
    .replaceAll(RegExp(r'\bCOMPLICACION\b'), 'COMPLICACIÓN')
    .replaceAll(RegExp(r'\bCOMPLICACIONES\b'), 'COMPLICACIONES')  // já OK
    .replaceAll(RegExp(r'\bATENCION\b'), 'ATENCIÓN')
    .replaceAll(RegExp(r'\bINFUSION\b'), 'INFUSIÓN')
    .replaceAll(RegExp(r'\bINFUSIONES\b'), 'INFUSIONES')
    .replaceAll(RegExp(r'\bASSOCIACION\b'), 'ASOCIACIÓN')
    .replaceAll(RegExp(r'\bASOCIACION\b'), 'ASOCIACIÓN');

  return s.trim();
}

/// Divide o texto em blocos lógicos separados por linha(s) em branco.
/// Cada bloco vai virar uma bolha independente.
///
/// REGRA ANTI-ORFÃO: se um bloco consiste apenas de uma linha que é um
/// section-header (começa com 🚨 💊 ⛔ 📌 ### ou palavras-chave clínicas),
/// ele é fundido com o bloco seguinte. Isso evita que o AI emita uma linha
/// em branco entre o cabeçalho e os bullets e os dois apareçam em cards
/// separados (ex: "🚨 **TRATAMENTO FARMACOLÓGICO DO IAM** —" num card sozinho
/// e os bullets de medicação num card separado).
///
/// ORDEM 27 — DEPRECATION STATUS:
///   DEPRECATED IN PLANTÃO MODE — _splitIntoBlocks() foi REMOVIDO do pipeline
///   de renderização do Plantão no Build 123. Modo Plantão envia texto único para
///   PlantatoPipeline.run() diretamente; este bloco NUNCA é chamado em Plantão.
///   MAINTAINED FOR: _AiBubble (Modo Estudo + histórico legado). Remoção causaria
///   regressão na renderização multi-bloco do Modo Estudo. NÃO REMOVER.
List<String> _splitIntoBlocks(String text) {
  // Normaliza quebras de linha múltiplas em duplas
  final normalized = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  // Divide por linha em branco
  final rawBlocks = normalized.split(RegExp(r'\n\n+'));
  final blocks = rawBlocks
      .map((b) => b.trim())
      .where((b) => b.isNotEmpty)
      .toList();

  // ── Passo de fusão de cabeçalhos orfãos ──────────────────────────────
  // Detector inline — replica a lógica de detecção de seção localmente
  // (função top-level, sem acesso a métodos de instância).
  // Build 100: expandido para cobrir todos os emojis clínicos de header e
  // linhas de blockquote (>) que o modelo emite isoladas antes dos bullets.
  bool looksLikeHeaderOnly(String block) {
    final lines = block.split('\n');
    if (lines.length != 1) return false; // bloco com múltiplas linhas já tem corpo
    final t = lines[0].trim();
    // 5 blocos premium oficiais + emojis clínicos adicionais frequentes (Build 106)
    if (t.startsWith('🚨') || t.startsWith('💊') ||
        t.startsWith('⛔') || t.startsWith('📌') ||
        t.startsWith('🟥') || t.startsWith('🏥') || t.startsWith('💉') ||
        t.startsWith('🔬') || t.startsWith('📋') ||
        t.startsWith('🫀') || t.startsWith('🫁') ||
        t.startsWith('🧬') || t.startsWith('💡')) return true;
    // Markdown headers
    if (t.startsWith('## ') || t.startsWith('### ')) return true;
    // Blockquote de alerta crítico isolado (linha "> 🔴 ALERTA...")
    if (t.startsWith('> ') && t.length < 120) return true;
    // Títulos de seção clínica conhecidos
    if (RegExp(r'^(Hipótese|Hipóteses|Hipotese|Hipoteses|'
               r'Hipotesis|Hipótesis|'
               r'Conduta|Conducta|'
               r'Exames|Examenes|'
               r'Monitoriz|Monitorizaç|'
               r'Evitar|'
               r'Escalonamento|Escalonamiento|'
               r'AGORA|AHORA|QUICK|CLINICAL|TEACH|'
               r'Primeira Escolha|Primera Elección|Primera Eleccion|'
               r'CONDUTA IMEDIATA|CONDUCTA INMEDIATA|'
               r'MEDICAÇÕES|MEDICACIONES|'
               r'HARD STOP|MONITORIZAÇÃO|MONITORIZACIÓN|'
               r'FÁRMACO DETALHADO|FÁRMACO DETALLADO)',
               caseSensitive: false).hasMatch(t)) return true;
    return false;
  }

  // ── Build 115: detector de bloco de lista ───────────────────────────────
  // Um bloco é "só lista" se TODAS as suas linhas não-vazias são bullets.
  // Padrão ampliado: '* ', '- ', '• ', '→ ', '▸ ', '1. ', '*texto', '* **'
  bool looksLikeListBlock(String block) {
    final lines = block.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return false;
    return lines.every((l) {
      final t = l.trimLeft();
      return t.startsWith('* ') || t.startsWith('- ') || t.startsWith('• ') ||
             t.startsWith('→ ') || t.startsWith('▸ ') ||
             RegExp(r'^\d+\.\s').hasMatch(t) ||
             RegExp(r'^\*\s*\*\*').hasMatch(t) ||   // * **Negrito**
             RegExp(r'^\*[^*\s]').hasMatch(t);       // *Texto
    });
  }

  final merged = <String>[];
  for (int i = 0; i < blocks.length; i++) {
    final b = blocks[i];

    // FIX: Funde cabeçalho orfão com bloco seguinte
    if (looksLikeHeaderOnly(b) && i + 1 < blocks.length) {
      merged.add('$b\n${blocks[i + 1]}');
      i++;

    // Build 115 FIX: Funde bloco de lista com bloco anterior (texto introdutório)
    // Evita que "Os principais grupos incluem:\n\n* Levodopa..." vire 2 containers.
    } else if (looksLikeListBlock(b) && merged.isNotEmpty) {
      merged[merged.length - 1] = '${merged.last}\n$b';

    } else {
      merged.add(b);
    }
  }
  return merged;
}

// ─────────────────────────────────────────────────────────────────────────────
// SMART TEXT-WRAP — Build 118
//
// Substitui o espaço simples entre número e unidade médica por NBSP (\u00A0)
// para que doses clínicas nunca quebrem de linha de forma separada.
//
// Exemplos protegidos:
//   "50 mg"        → "50\u00A0mg"
//   "0.5 mg/kg"    → "0.5\u00A0mg/kg"
//   "120 mg/kg/dia"→ "120\u00A0mg/kg/dia"
//   "120/80 mmHg"  → "120/80\u00A0mmHg"
//   "FC 98"        → "FC\u00A098"
//   "PA 120/80"    → "PA\u00A0120/80"
//   "SpO₂ 98%"     → "SpO₂\u00A098%"
//
// Regex cobre:
//   • Grupo 1 (número antes): dígitos (com fracionário / slash) + espaço + unidade
//   • Grupo 2 (sigla médica antes): FC|PA|SpO₂|PAS|PAD|FR|Sat|PaCO₂|PaO₂
//     seguido de espaço + número
// ─────────────────────────────────────────────────────────────────────────────
String _applyMedicalNbsp(String text) {
  const nbsp = '\u00A0';

  // Padrão 1: número [fracionário/slash] + ESPAÇO + unidade médica
  // Ex: 50 mg, 0.5 mcg/kg, 500 mg/m², 120/80 mmHg, 2 g/kg/dia
  text = text.replaceAllMapped(
    RegExp(
      r'(\b\d+(?:[.,/]\d+)*)\s'
      r'(mg(?:/kg(?:/(?:dia|day|d))?)?'
      r'|mcg(?:/kg(?:/(?:dia|day|d))?)?'
      r'|µg(?:/kg(?:/(?:dia|day|d))?)?'
      r'|g(?:/kg(?:/(?:dia|day|d))?)?'
      r'|kg(?:/m²)?'
      r'|ml(?:/kg(?:/h)?)?'
      r'|mEq(?:/L|/kg)?'
      r'|mmol(?:/L)?'
      r'|mmHg'
      r'|cmH₂O|cmH2O'
      r'|UI(?:/kg)?'
      r'|U(?:/kg)?'
      r'|%'
      r'|x\/min|\/min'
      r'|bpm'
      r'|h\b|hora[s]?\b'
      r'|min\b'
      r'|dias?\b|days?\b'
      r'|semanas?\b'
      r'|comprimidos?\b|comp\b'
      r'|amp\b|frascos?\b'
      r'|L(?:/min|/h)?'
      r')',
      caseSensitive: false,
    ),
    (m) => '${m.group(1)}$nbsp${m.group(2)}',
  );

  // Padrão 2: sigla clínica + ESPAÇO + número
  // Ex: FC 98, PA 120/80, SpO₂ 98, PAS 140, FR 18
  text = text.replaceAllMapped(
    RegExp(
      r'\b(FC|PA|PAS|PAD|FR|Sat|SpO[₂2]|PaCO[₂2]|PaO[₂2]|PCO[₂2]|PANI|HGT|GCS)\s'
      r'(\d)',
      caseSensitive: true,
    ),
    (m) => '${m.group(1)}$nbsp${m.group(2)}',
  );

  return text;
}

/// Renderiza uma linha de texto com suporte a negrito inline via **texto**.
/// Não exibe os asteriscos — converte para FontWeight.bold.
/// Build 115: strip defensivo de asteriscos isolados que escapam do parser.
/// Build 118: Smart Text-Wrap — NBSP entre número e unidade médica.
Widget _buildInlineText(String line, Color textColor, {bool isBold = false}) {
  // Build 115: sanitização defensiva — remove asteriscos de bullet isolados
  // que possam escapar do parser Markdown.
  String sanitized = line
      .replaceAll(RegExp(r'^\*\s+'), '')           // '* ' no início
      .replaceAll(RegExp(r'^\*(?=\S)'), '')         // '*texto' sem espaço
      .replaceAll(RegExp(r'\s\*\s'), ' ')           // asterisco isolado entre espaços
      .replaceAll(RegExp(r'(?<!\*)\*(?!\*)(?!\s)'), '') // asterisco solitário não-bold
      .trim();
  if (sanitized.isEmpty) sanitized = line.trim();

  // Build 118: aplica NBSP entre valores numéricos e unidades médicas
  sanitized = _applyMedicalNbsp(sanitized);

  // Detecta se toda a linha é um título (começa com negrito sem texto antes)
  // Padrão: **Título** ou **Título:** — ocupa a linha toda
  final fullBold = RegExp(r'^\*\*(.+?)\*\*:?\s*$');
  final fullMatch = fullBold.firstMatch(sanitized);
  if (fullMatch != null || isBold) {
    final label = fullMatch != null
        ? fullMatch.group(1)! + (sanitized.endsWith(':') ? ':' : '')
        : sanitized;
    return Text(
      label,
      style: TextStyle(
        fontSize: 15,             // Build 117: 13.5→15
        fontWeight: FontWeight.w700,
        color: textColor,
        height: 1.6,              // Build 117: 1.45→1.6
      ),
    );
  }

  // Inline bold: split por **...**
  final parts = <TextSpan>[];
  final regex = RegExp(r'\*\*(.+?)\*\*');
  int cursor = 0;
  for (final match in regex.allMatches(sanitized)) {
    if (match.start > cursor) {
      parts.add(TextSpan(text: sanitized.substring(cursor, match.start)));
    }
    parts.add(TextSpan(
      text: match.group(1),
      style: const TextStyle(fontWeight: FontWeight.w700),
    ));
    cursor = match.end;
  }
  if (cursor < sanitized.length) {
    parts.add(TextSpan(text: sanitized.substring(cursor)));
  }

  if (parts.isEmpty) return const SizedBox.shrink();

  return RichText(
    text: TextSpan(
      style: TextStyle(
        fontSize: 15,             // Build 117: 13.5→15
        fontWeight: FontWeight.w400,
        color: textColor,
        height: 1.6,              // Build 117: 1.5→1.6
      ),
      children: parts,
    ),
  );
}

/// Widget de um único bloco da IA — bolha hospitalar com hierarquia visual.
/// P4: Densidade hospitalar + leitura rápida de plantão.
class _AiBlockBubble extends StatelessWidget {
  final String block;
  final bool dark;
  final bool isLast;
  final VoidCallback? onCopy;
  final VoidCallback? onTts;
  final bool ttsPlaying;
  final bool ttsReady;
  final String lang;  // globalLanguageLock — controla textos da UI
  /// Build 120 — ActionChip: ao clicar, injeta texto no input e dispara _send()
  final void Function(String chipText)? onChipTap;

  const _AiBlockBubble({
    required this.block,
    required this.dark,
    this.isLast = false,
    this.onCopy,
    this.onTts,
    this.ttsPlaying = false,
    this.ttsReady = false,
    this.lang = 'pt',
    this.onChipTap,
  });

  // ── ORDEM VISUAL 01: detectores de linha individuais EXTINTOS ───────────
  // _isHardStop / _isH2 / _isSectionHeader / _isWarning / _isReference /
  // _isListItem foram todos removidos. O MarkdownBody único processa o texto
  // completo com softLineBreak:true — sem loop linha-a-linha na UI.

  // ── Build 122: Separa linhas do bloco de referências (📚) ────────────────
  // O bloco termina ao encontrar uma nova seção clínica estruturada.
  (List<String>, List<String>) _splitRefLines(List<String> lines) {
    bool inRef = false;
    final body = <String>[];
    final refs = <String>[];

    bool isReferenceHeader(String value) {
      final normalized = value
          .replaceAll(RegExp(r'^[#*\s]+'), '')
          .replaceAll(':', '')
          .trim()
          .toUpperCase();

      return normalized == '📚 REFERENCIAS' ||
          normalized == '📚 REFERÊNCIAS' ||
          normalized == 'REFERENCIAS' ||
          normalized == 'REFERÊNCIAS';
    }

    bool startsNewSection(String value) {
      if (value.isEmpty) return false;

      return value.startsWith('#') ||
          value.startsWith('🟥') ||
          value.startsWith('⛔') ||
          value.startsWith('📌') ||
          value.startsWith('🎯') ||
          value.startsWith('🚨') ||
          value.startsWith('💊') ||
          value.startsWith('📊') ||
          value.startsWith('⚠️') ||
          value.startsWith('✅') ||
          value.startsWith('🔴') ||
          value.startsWith('🟡') ||
          value.startsWith('🟢');
    }

    for (final line in lines) {
      final trimmed = line.trim();

      if (!inRef) {
        if (isReferenceHeader(trimmed)) {
          inRef = true;
        } else {
          body.add(line);
        }
        continue;
      }

      if (startsNewSection(trimmed) && !isReferenceHeader(trimmed)) {
        inRef = false;
        body.add(line);
        continue;
      }

      refs.add(line);
    }

    return (body, refs);
  }

  @override
  Widget build(BuildContext context) {
    // ── ORDEM VISUAL 01 — MarkdownBody ÚNICO, sem loop linha-a-linha ─────────
    // Toda a lógica de detecção manual de 🟥 / ⛔ / HARD STOP foi extinta.
    // O texto completo flui para um único MarkdownBody com softLineBreak:true.
    // Identidade visual: cor dos emojis nativos do modelo — 100% flat, sem
    // sub-containers, sem Row/Padding segregados por tipo de linha.

    const kGreen      = Color(0xFF008CA4);
    // B140: Vermelho Ferrari — títulos H2 e **strong** no light mode
    const kFerrariRed = Color(0xFFFF2400);

    final textColor = dark ? const Color(0xFFE8F2F5) : const Color(0xFF1A1D23);

    // ── M2: Normalização de soft-line-breaks ─────────────────────────────────
    // Converte cada \n isolado em \n\n para que o MarkdownBody quebre a linha
    // corretamente com softLineBreak:true, preservando parágrafos já duplos.
    // Algoritmo: substitui qualquer \n que NÃO esteja já precedido por \n
    // e NÃO esteja já seguido por \n → insere o segundo \n apenas onde falta.
    final normalizedText = block
        .replaceAll('\r\n', '\n')           // normaliza CRLF → LF
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')  // colapsa 3+ \n → 2
        .replaceAllMapped(
          RegExp(r'(?<!\n)\n(?!\n)'),       // \n isolado (não duplo)
          (_) => '\n\n',                    // → duplo para MD paragraph break
        );

    final lines = normalizedText.split('\n');
    final (bodyLines, refLines) = _splitRefLines(lines);
    final bool hasRefBlock = refLines.isNotEmpty;

    // Reconstrói o corpo normalizado para o MarkdownBody
    final mdText = bodyLines.join('\n').trim();

    // ── MarkdownStyleSheet premium — tipografia clínica flat ─────────────────
    final sheet = MarkdownStyleSheet(
      // p: height 1.55 — respiro clínico máximo para checklists de Plantão
      p: TextStyle(fontSize: 13.5, color: textColor, height: 1.55),
      // strong (**...**) = ÚNICO receptor de cor vibrante
      // Dark: cyan médico 0xFF00E5FF (contraste 12:1 sobre fundo escuro)
      // Light: Vermelho Ferrari 0xFFFF2400 (contraste 5.2:1 sobre branco)
      strong: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        color: dark ? const Color(0xFF00E5FF) : kFerrariRed,
      ),
      em: TextStyle(fontSize: 13.5, color: textColor, fontStyle: FontStyle.italic),
      listBullet: TextStyle(fontSize: 13.5, color: textColor),
      // H2: título principal — Vermelho Ferrari bold (B140)
      h2: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: kFerrariRed,
        letterSpacing: 0.1,
        height: 1.3,
      ),
      // H3: sub-seção clínica — cyan no dark, verde médico no light
      h3: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: dark ? const Color(0xFF00E5FF) : kGreen,
        height: 1.3,
      ),
      blockquote: TextStyle(fontSize: 13, color: textColor.withOpacity(0.8)),
      // Força fundos transparentes — evita herança de ThemeData.cardColor
      blockquoteDecoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          left: BorderSide(
            color: dark ? Colors.white24 : Colors.black26,
            width: 3,
          ),
        ),
      ),
      codeblockDecoration: const BoxDecoration(color: Colors.transparent),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: dark ? Colors.white12 : Colors.black12,
            width: 1,
          ),
        ),
      ),
      blockSpacing: 6,
      listIndent: 18,

      // ── Tabelas Comparativas GFM — Modo Estudo (Build TableMD) ───────────
      // Ativadas por _modeAnchorEstudo (ai_gateway_service.dart) para síntese
      // de classes farmacológicas, diferenciais e dados correlacionados.
      // Dark: fundo naval translúcido + borda ciano sutil
      // Light: fundo gelo + borda cinza elegante
      tableHead: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: dark ? const Color(0xFF00E5FF) : const Color(0xFF1A1D23),
        letterSpacing: 0.2,
      ),
      tableBody: TextStyle(
        fontSize: 12,
        color: textColor,
        height: 1.4,
      ),
      tablePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      tableCellsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      tableColumnWidth: const FlexColumnWidth(),
      tableBorder: TableBorder.all(
        color: dark
            ? const Color(0xFF00E5FF).withOpacity(0.18)
            : const Color(0xFF1A1D23).withOpacity(0.12),
        width: 0.5,
        borderRadius: BorderRadius.circular(6),
      ),
      tableHeadAlign: TextAlign.left,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0).copyWith(
        bottom: isLast ? 8 : 4,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          // mainAxisSize.min: crescimento ilimitado vertical sem disputar
          // altura máxima com o ListView pai (evita truncação de texto longo).
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── ÚNICO MarkdownBody — processa tudo (🟥 ⛔ ## ### bullets) ──
            if (mdText.isNotEmpty)
              MarkdownBody(
                data: mdText,
                selectable: false,
                softLineBreak: true,
                styleSheet: sheet,
                // BUILD 429-APPLE-COMPLIANCE: intercepta todos os links do chat
                // e abre na WebView interna (CalculadoraScreen) — NUNCA Safari.
                onTapLink: (text, href, title) {
                  if (href != null && href.contains('http')) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CalculadoraScreen(initialUrl: href),
                      ),
                    );
                  }
                },
              ),

            // ── Build 120: Bloco de Referências Colapsável ────────────────
            if (hasRefBlock)
              _CollapsibleReferencesBlock(
                lines: refLines,
                dark: dark,
                lang: lang,
              ),

            // ── Rodapé: hora + TTS + copiar (apenas última bolha) ────────
            if (isLast) ...[
              const SizedBox(height: 5),
              Row(children: [
                Text(
                  _fakeTime(),
                  style: TextStyle(
                    fontSize: 10,
                    color: dark ? Colors.white24 : Colors.black26,
                  ),
                ),
                const Spacer(),
                if (onTts != null && ttsReady) ...[
                  GestureDetector(
                    onTap: onTts,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: ttsPlaying
                            ? kGreen.withOpacity(0.15)
                            : Colors.transparent,
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                          ttsPlaying
                              ? Icons.stop_circle_rounded
                              : Icons.volume_up_rounded,
                          size: 13,
                          color: ttsPlaying
                              ? kGreen
                              : (dark ? Colors.white38 : Colors.black38),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          ttsPlaying
                              ? (lang == 'es' ? 'Detener' : 'Parar')
                              : (lang == 'es' ? 'Escuchar' : 'Ouvir'),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: ttsPlaying
                                ? kGreen
                                : (dark ? Colors.white38 : Colors.black38),
                          ),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (onCopy != null)
                  GestureDetector(
                    onTap: onCopy,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.copy_rounded, size: 12,
                        color: dark ? Colors.white24 : Colors.black26),
                      const SizedBox(width: 3),
                      Text(lang == 'es' ? 'Copiar' : 'Copiar',
                        style: TextStyle(
                          fontSize: 10,
                          color: dark ? Colors.white24 : Colors.black26)),
                    ]),
                  ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  String _fakeTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }
}

/// Widget pai que divide a resposta completa em múltiplas _AiBlockBubble.
class _AiBubble extends StatefulWidget {
  final String text;
  final bool dark;
  final VoidCallback onCopy;
  final bool animate;
  final String lang;  // globalLanguageLock — propagado para _AiBlockBubble
  // TTS
  final bool ttsPlaying;
  final bool ttsReady;
  final VoidCallback? onTts;
  /// Token de geração — invalida callbacks de bolhas antigas (anti-jump fix)
  final int scrollGeneration;
  /// Callback para notificar o pai que um bloco foi revelado
  final void Function(int generation)? onBlockRevealed;
  /// true enquanto esta bolha está sendo preenchida por streaming V2
  /// (exibe cursor piscante ▌ após o texto)
  final bool isStreaming;
  /// Build 120 — ActionChip: dispara _send() com o texto da pergunta de fechamento
  final void Function(String chipText)? onChipTap;
  /// Build 188 — ValueNotifier para streaming ultra-localizado:
  /// Quando não-nulo, a bolha escuta este notifier diretamente em vez de
  /// depender de widget.text para atualizar chunks — zero rebuild na tela pai.
  final ValueNotifier<String>? streamingTextNotifier;
  const _AiBubble({
    super.key,
    required this.text,
    required this.dark,
    required this.onCopy,
    this.animate = false,
    this.lang = 'pt',
    this.ttsPlaying = false,
    this.ttsReady = false,
    this.onTts,
    this.scrollGeneration = 0,
    this.onBlockRevealed,
    this.isStreaming = false,
    this.onChipTap,
    this.streamingTextNotifier,
  });

  @override
  State<_AiBubble> createState() => _AiBubbleState();
}

class _AiBubbleState extends State<_AiBubble> {
  // Quantos blocos já estão visíveis
  int _visibleCount = 0;
  bool _started = false;

  // ⚡ Cache dos blocos — computado UMA vez no initState/didUpdateWidget
  // Evita reprocessar _cleanAiText + _splitIntoBlocks em cada rebuild do scroll
  late List<String> _cachedBlocks;

  // Build 188: texto exibido — pode ser alimentado por widget.text (estático)
  // ou por _streamingNotifier (streaming ultra-localizado).
  String _displayText = '';

  // Referência ao notifier atual — para removeListener no dispose/update
  ValueNotifier<String>? _attachedNotifier;

  // ── BUILD 462-STREAMING-CORE: Batch Rendering Engine (40ms) ─────────────
  // Desacopla a chegada de chunks da rede (networkBuffer) da atualização
  // da UI (visibleTextNotifier). Limita rebuilds a 25/s (suavidade biológica).
  //
  // Ciclo de vida:
  //   1. Chunk chega em _onRawChunk() → escrito em _networkBuffer (zero setState)
  //   2. _renderTimer (40ms) → drena _networkBuffer → atualiza _displayText
  //      e _cachedBlocks em UM único setState por tick
  //   3. No onDone: _renderTimer cancelado → setState final com texto completo
  //      → _streamingComplete=true → build() usa MarkdownBody em vez de SelectableText
  //
  // Fase "Skeleton": quando widget.isStreaming=true mas _displayText está vazio
  //   (AiStarted recebido, nenhum AiTextDelta ainda), exibe linhas pulsantes.
  // ─────────────────────────────────────────────────────────────────────────

  /// Buffer de rede: recebe deltas brutos sem custo de setState.
  /// Drenado a cada 40ms pelo [_renderTimer].
  final StringBuffer _networkBuffer = StringBuffer();

  /// Timer periódico de 40ms — opera APENAS durante streaming ativo.
  Timer? _renderTimer;

  /// true após o evento de conclusão (AiCompleted / isDone) — troca
  /// SelectableText pelo MarkdownBody completo no próximo frame.
  bool _streamingComplete = false;

  // ── Drena o buffer de rede e atualiza UI a cada 40ms ─────────────────
  void _startRenderTimer() {
    _renderTimer?.cancel();
    _renderTimer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (!mounted) {
        _renderTimer?.cancel();
        _renderTimer = null;
        return;
      }
      final pending = _networkBuffer.toString();
      if (pending.isEmpty) return;
      _networkBuffer.clear();

      // Acumula no display text (o buffer contém o DELTA, não o acumulado)
      final newText = _displayText + pending;
      try {
        setState(() {
          _displayText  = newText;
          _cachedBlocks = _computeBlocksFromText(newText);
          if (_cachedBlocks.isNotEmpty && _visibleCount < 1) {
            _visibleCount = 1;
          }
          if (_cachedBlocks.length > _visibleCount) {
            _visibleCount = _cachedBlocks.length;
          }
        });
      } catch (_) {}

      if (widget.isStreaming && widget.onBlockRevealed != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          widget.onBlockRevealed!(widget.scrollGeneration);
        });
      }
    });
  }

  void _stopRenderTimer() {
    _renderTimer?.cancel();
    _renderTimer = null;
  }

  // ── Listener do notifier: recebe delta acumulado do provider ──────────
  // O notifier passa o texto ACUMULADO completo (comportamento legado).
  // Convertemos para delta (diff em relação ao _displayText anterior)
  // e empurramos apenas o novo fragmento para o _networkBuffer.
  void _onStreamingChunk() {
    if (!mounted) return;
    final notifier = _attachedNotifier;
    if (notifier == null) return;
    final fullAccumulated = notifier.value;

    // Extrai apenas o delta desde o último texto conhecido
    final prevLen = _displayText.length + _networkBuffer.length;
    if (fullAccumulated.length > prevLen) {
      final delta = fullAccumulated.substring(prevLen);
      _networkBuffer.write(delta);
    } else if (fullAccumulated.length < _displayText.length) {
      // Regressão rara (strip de metadata): reseta o buffer com o novo texto
      _networkBuffer.clear();
      _networkBuffer.write(fullAccumulated.substring(_displayText.length.clamp(0, fullAccumulated.length)));
    }

    // Garante que o timer está ativo durante o streaming
    if (_renderTimer == null || !_renderTimer!.isActive) {
      _startRenderTimer();
    }
  }

  void _attachNotifier(ValueNotifier<String>? notifier) {
    if (_attachedNotifier == notifier) return;
    _attachedNotifier?.removeListener(_onStreamingChunk);
    _attachedNotifier = notifier;
    _attachedNotifier?.addListener(_onStreamingChunk);
  }

  @override
  void initState() {
    super.initState();
    _displayText = widget.text;
    _cachedBlocks = _computeBlocksFromText(_displayText);
    _attachNotifier(widget.streamingTextNotifier);
    // Inicia a sequência de exibição após o primeiro frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _startSequence());
  }

  @override
  void dispose() {
    _stopRenderTimer();
    _attachedNotifier?.removeListener(_onStreamingChunk);
    _attachedNotifier = null;
    super.dispose();
  }

  @override
  void didUpdateWidget(_AiBubble old) {
    super.didUpdateWidget(old);

    // Build 188: atualiza o listener do notifier se mudou
    if (old.streamingTextNotifier != widget.streamingTextNotifier) {
      _attachNotifier(widget.streamingTextNotifier);
    }

    final textChanged      = old.text != widget.text;
    final streamingChanged = old.isStreaming != widget.isStreaming;

    // ── BUILD 462: Detecta conclusão do stream (true → false) ─────────────
    // Quando streaming termina: para o timer, drena qualquer delta residual
    // no buffer, comita o texto final definitivo e marca _streamingComplete=true
    // para que o build() substitua SelectableText → MarkdownBody.
    final streamingJustEnded = old.isStreaming && !widget.isStreaming;
    if (streamingJustEnded) {
      _stopRenderTimer();
      // Drena buffer residual sincronamente antes do setState final
      final residual = _networkBuffer.toString();
      _networkBuffer.clear();
      // Texto final definitivo: usa widget.text (commitado pelo provider) como
      // source-of-truth — descarta qualquer delta residual que possa ter chegado
      // fora de ordem nos últimos milissegundos do stream.
      try {
        setState(() {
          _displayText      = widget.text.isNotEmpty ? widget.text : (_displayText + residual);
          _cachedBlocks     = _computeBlocksFromText(_displayText);
          _streamingComplete = true;
          if (_cachedBlocks.isNotEmpty) _visibleCount = _cachedBlocks.length;
        });
      } catch (_) {}
    }

    if (!textChanged && !streamingChanged) return;

    // ── CORREÇÃO CRÍTICA DE REATIVIDADE ─────────────────────────────────────
    // Build 188: quando o notifier está ativo e streaming, os chunks chegam via
    // _onStreamingChunk() — não precisamos processar widget.text aqui.
    // Só processa widget.text quando: (a) não há notifier, ou (b) streaming acabou.
    final hasActiveNotifier = _attachedNotifier != null && widget.isStreaming;

    // Sempre atualiza _displayText a partir de widget.text quando streaming termina
    // ou quando não há notifier (bolha histórica).
    if (!hasActiveNotifier || streamingJustEnded) {
      try {
        setState(() {
          _displayText = widget.text;
          _cachedBlocks = _computeBlocksFromText(_displayText);

          // Durante streaming: garante que _visibleCount >= 1 assim que o
          // primeiro bloco existe, mesmo que _startSequence ainda não rodou.
          // Sem isso, o primeiro chunk ficava invisível (visibleCount=0).
          if (widget.isStreaming && _cachedBlocks.isNotEmpty && _visibleCount < 1) {
            _visibleCount = 1;
          }

          // Quando novos blocos aparecem (quebras de parágrafo no stream),
          // avança _visibleCount para revelar imediatamente — sem delay de animação.
          // A animação de "revelação em sequência" só se aplica à resposta final,
          // não ao texto chegando em tempo real.
          if (widget.isStreaming && _cachedBlocks.length > _visibleCount) {
            _visibleCount = _cachedBlocks.length;
          }

          // ── BUILD 101 FIX: garante visibilidade total ao fim do stream ────────
          // Quando isStreaming muda de true → false (cursor removido), o
          // _computeBlocksFromText() pode gerar um nº diferente de blocos (sem o ▌).
          // Garante que _visibleCount cobre TODOS os blocos finais — evita que
          // o último bloco fique invisível se o count anterior era para blocos-com-cursor.
          if (streamingJustEnded && _cachedBlocks.isNotEmpty) {
            _visibleCount = _cachedBlocks.length;
          }
        });
      } catch (_) {
        // Falha de render silenciosa: mantém estado anterior da bolha intacto.
        // O próximo chunk válido aciona novo didUpdateWidget e recupera a tela.
      }
    }

    // Scroll para o fim a cada chunk — texto cresce e médico acompanha
    if (widget.isStreaming && textChanged && widget.onBlockRevealed != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onBlockRevealed!(widget.scrollGeneration);
      });
    }

    // ── BUILD 101 FIX: scroll final quando streaming termina ──────────────
    // Quando isStreaming muda de true → false, o cursor ▌ é removido e o
    // _computeBlocks() recomputa os blocos sem ele. Este addPostFrameCallback
    // garante que o scroll se ajusta ao layout final DEPOIS que os blocos sem
    // cursor foram renderizados — eliminando o congelamento mid-screen.
    if (!widget.isStreaming && old.isStreaming && widget.onBlockRevealed != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onBlockRevealed!(widget.scrollGeneration);
      });
    }
  }

  /// Build 188: renomeado de _computeBlocks para aceitar texto como parâmetro
  /// explícito (em vez de sempre usar widget.text) — necessário para que
  /// _onStreamingChunk possa computar blocos do texto do notifier.
  ///
  /// BUILD 277-PATCH: bypass transparente de _cleanAiText para o caminho
  /// não-streaming (texto final commitado). O RAW_AI_OUTPUT é injetado
  /// diretamente sem mutação de string intermediária — preserva marcadores
  /// de negrito (**) e emojis adjacentes intactos.
  /// _cleanAiText é mantido APENAS para o caminho de streaming (chunks parciais)
  /// onde a sanitização de CoT/metadados ainda é necessária durante o stream.
  List<String> _computeBlocksFromText(String text) {
    // Build 123 — DESTRUIÇÃO DO SPLIT:
    // _splitIntoBlocks() foi removido do pipeline de renderização.
    // 100% do texto da IA é retornado como UM ÚNICO elemento de lista.
    // _AiBlockBubble recebe o texto completo e renderiza com MarkdownBody fluido.
    // ZERO fatiamento. ZERO containers escuros múltiplos. ZERO fallback de blocos.
    //
    // ORDEM 27 — ISOLAMENTO ABSOLUTO DO PIPELINE DO PLANTÃO:
    // _cleanAiText() É PROIBIDO para texto final do Plantão. O BUILD 277-PATCH
    // já garante o bypass pelo gate isStreaming==false (pass-through direto).
    // O único caminho legítimo para _cleanAiText() é o streaming parcial de chunks
    // (isStreaming==true) — onde a sanitização de CoT/metadados ainda é necessária.
    // Plantão finalizado (isPlantaoFinalBubble) nunca usa _AiBubble, portanto
    // este método NUNCA é chamado pelo render engine do Plantão pós-ORDEM 26.
    try {
      final displayText = widget.isStreaming ? '$text\u258c' : text;
      final safeText = widget.isStreaming
          ? _sanitizePartialMarkdown(displayText)
          : displayText;

      // BUILD 277-PATCH — BYPASS TRANSPARENTE (ORDEM 27: isolamento Plantão):
      // Caminho não-streaming (texto final commitado): pass-through RAW_AI_OUTPUT.
      //   → _cleanAiText() NUNCA chamada → zero CPU desperdiçado em regex pesado
      //     para texto já processado pelo PlantatoPipeline ou pelo Estudo renderer.
      // Caminho streaming (chunks parciais): _cleanAiText() APENAS aqui,
      //   filtrando CoT/metadados/asteriscos ornamentais durante o stream activo.
      final String result;
      if (widget.isStreaming) {
        // ORDEM 27: _cleanAiText() chamada SOMENTE neste branch (streaming chunk).
        // Confirma isolamento: se chegar aqui com isPlantaoFinalBubble=true seria
        // impossível pois _AiBubble não é instanciado para bolhas finais do Plantão.
        if (kDebugMode) debugPrint('[CPU_GUARD] _cleanAiText called — isStreaming=true (legítimo)');
        final cleaned = _cleanAiText(safeText);
        result = cleaned.isEmpty ? safeText.trim() : cleaned;
      } else {
        // Texto final: pass-through direto — preserva toda a formatação Markdown.
        // _cleanAiText() NÃO é chamada — isolamento CPU garantido.
        result = safeText.trim();
      }

      return result.isEmpty ? [] : [result];
    } catch (_) {
      if (_cachedBlocks.isNotEmpty) return _cachedBlocks;
      final fallback = text.trim();
      return fallback.isEmpty ? [] : [fallback];
    }
  }

  /// Sanitiza markdown incompleto durante o streaming chunk a chunk.
  ///
  /// Problemas comuns ao renderizar texto parcial:
  ///  • "* " sozinho no fim  → marcador de lista sem conteúdo ainda
  ///  • "- " sozinho no fim  → traço de lista sem texto
  ///  • "**texto" sem fechar → negrito não terminado quebra layout
  ///  • "### " sem título    → cabeçalho vazio
  ///  • "🟥" / "⛔" sozinho  → emoji de card sem texto ainda
  ///  • "🟥 AMO" incompleto  → card parcialmente digitado
  ///
  /// Estratégia: inspeciona apenas a ÚLTIMA linha (fragmento em construção).
  /// Linhas anteriores já chegaram completas e não são alteradas.
  ///
  /// Build 112 — REACTIVE CARD DETECTION (substitui supressão do Build 108):
  /// Ao detectar emoji de card (🟥 ⛔ 📌 📚 🚨 💊) na última linha, NÃO suprimir.
  /// Em vez disso, completar o token para que o _AiBlockBubble abra o container
  /// do card IMEDIATAMENTE, mesmo com texto parcial — eliminando o "vazamento cru".
  ///
  /// Estratégia v2:
  ///  • Emoji sozinho (sem texto) → preservar com placeholder mínimo "…"
  ///    para que o parser reconheça como header e abra o card colorido.
  ///  • Emoji + texto parcial curto → preservar como está (card abre imediatamente).
  ///  • Apenas texto de "thinking" interno (sem emoji de card) antes do \n → suprimir.
  static String _sanitizePartialMarkdown(String text) {
    if (text.isEmpty) return text;

    final lines   = text.split('\n');
    final lastIdx = lines.length - 1;
    String last   = lines[lastIdx];

    // Remove cursor ▌ para analisar o conteúdo real
    final hasCursor = last.endsWith('\u258c');
    if (hasCursor) last = last.substring(0, last.length - 1);

    final trimmedLast = last.trimLeft();

    // ── Build 112: tokens de card UI — detecção reativa imediata ────────────
    // Quando a última linha começa com um emoji de card, abrimos o container
    // do card imediatamente — sem threshold de supressão.
    // Se o emoji está totalmente sozinho (sem nenhum char após), injetamos
    // um placeholder mínimo para que o _AiBlockBubble reconheça como header
    // e instancie o card colorido antes do texto chegar.
    final cardEmojiRx = RegExp(r'^(🟥|⛔|📌|📚|🚨|💊)');
    if (cardEmojiRx.hasMatch(trimmedLast)) {
      final afterEmoji = trimmedLast.replaceFirst(cardEmojiRx, '').trim();
      if (afterEmoji.isEmpty) {
        // Emoji sozinho → preserva a linha com um espaço após o emoji para que
        // o _AiBlockBubble reconheça o token e instancie o container do card.
        // O texto real substituirá o espaço nos próximos chunks do stream.
        // Não há artefato visual: o container aparece imediatamente mas vazio.
        last = '$trimmedLast ';
      }
      // Se já tem qualquer texto após o emoji, deixa passar normalmente.
      // O _AiBlockBubble já abre o card com conteúdo parcial disponível.
    }
    // ── Supressão de pensamento interno vazado (linha sem emoji de card) ────
    // Padrões de CoT que ainda podem aparecer na última linha durante streaming:
    // ex: "Let me think", "I'll structure", "Okay, I need to"
    else if (_looksLikeLeakedThought(trimmedLast)) {
      last = ''; // suprimir linha — CoT não deve aparecer na UI
    }
    // Marcador de lista sozinho ("* ", "- ", "• " sem texto após)
    else if (RegExp(r'^[\*\-•]\s*$').hasMatch(trimmedLast)) {
      last = '';
    }
    // Cabeçalho markdown vazio ("## ", "### " sem título ainda)
    else if (RegExp(r'^#{1,3}\s*$').hasMatch(trimmedLast)) {
      last = '';
    }
    // Negrito não fechado: conta pares de "**" — se ímpar, está aberto
    else {
      final pairs = RegExp(r'\*\*').allMatches(last).length;
      if (pairs.isOdd) {
        // Fecha provisoriamente para não quebrar o RichText inline
        last = '$last**';
      }
    }

    if (hasCursor) last = '$last\u258c';
    lines[lastIdx] = last;
    return lines.join('\n');
  }

  /// Detecta padrões de "pensamento interno" (CoT leaked) na última linha
  /// do stream — expressões que indicam o modelo "pensando em voz alta".
  /// Usado por _sanitizePartialMarkdown() para suprimir antes da exibição.
  static bool _looksLikeLeakedThought(String line) {
    if (line.isEmpty) return false;
    final lower = line.toLowerCase();
    // Padrões em inglês (vazamento de CoT interno do modelo)
    if (lower.startsWith("let me ") ||
        lower.startsWith("okay, ") ||
        lower.startsWith("i'll ") ||
        lower.startsWith("i need to ") ||
        lower.startsWith("i should ") ||
        lower.startsWith("i will ") ||
        lower.startsWith("first, i") ||
        lower.startsWith("the user ") ||
        lower.startsWith("the user's ") ||
        lower.startsWith("the doctor ") ||
        lower.startsWith("this is a ") ||
        lower.startsWith("this implies") ||
        lower.startsWith("looking at ") ||
        lower.startsWith("user input analysis") ||
        lower.startsWith("assumed patient") ||
        lower.startsWith("constructing ") ||
        lower.startsWith("since the user") ||
        lower.startsWith("as the previous") ||
        lower.startsWith("given the context") ||
        lower.startsWith("given the previous") ||
        lower.startsWith("interpreting ") ||
        lower.startsWith("the previous response") ||
        lower.startsWith("my task ") ||
        lower.startsWith("to address ") ||
        lower.startsWith("the question asked") ||
        lower.startsWith("based on the previous") ||
        // Padrão "< DIAGNÓSTICO. texto análise..."
        (line.startsWith('<') && lower.contains(" the ") && lower.contains("response"))) {
      return true;
    }
    // Padrões em português (meta-comentário de intenção)
    if (lower.startsWith("o usuário ") ||
        lower.startsWith("o médico ") ||
        lower.startsWith("preciso ") ||
        lower.startsWith("vou ") ||
        lower.startsWith("deixa eu ") ||
        lower.startsWith("primeiro, ") ||
        lower.startsWith("pensando ") ||
        lower.startsWith("analisando ")) {
      return true;
    }
    return false;
  }

  void _startSequence() {
    if (_started || !mounted) return;
    _started = true;

    final total = _cachedBlocks.isEmpty ? 1 : _cachedBlocks.length;

    if (!widget.animate || total <= 1) {
      // Sem animação (histórico) ou bloco único → mostra tudo imediatamente
      if (mounted) setState(() => _visibleCount = total);
      // Notifica o pai mesmo para bloco único (para scroll até o fundo)
      if (widget.animate && widget.onBlockRevealed != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onBlockRevealed!(widget.scrollGeneration);
        });
      }
      return;
    }

    // ── Revelar blocos sequencialmente ──────────────────────────────────────
    // Delay: 80ms primeiro bloco, 450ms subsequentes (mais rápido = menos conflito)
    // CRÍTICO: cada Future captura o `gen` no momento do agendamento.
    // Quando o pai incrementa `_scrollGeneration`, os Futures antigos passam
    // a enviar um gen desatualizado → _onBlockRevealed ignora. Zero jumps.
    final gen = widget.scrollGeneration;
    for (int i = 0; i < total; i++) {
      final delayMs = i == 0 ? 80 : (80 + i * 420).clamp(0, 3000);
      Future.delayed(Duration(milliseconds: delayMs), () {
        if (!mounted) return;
        // Se a geração mudou (nova resposta chegou), não revela mais blocos.
        if (widget.scrollGeneration != gen) return;

        setState(() => _visibleCount = i + 1);

        // Delega scroll ao pai — apenas uma chamada, sem animateTo aqui.
        // O pai (_AiScreenState._onBlockRevealed) decide o que fazer.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (widget.scrollGeneration != gen) return;
          widget.onBlockRevealed?.call(gen);
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── BUILD 462: SKELETON SCREEN — fase AiStarted (antes do 1º delta) ─────
    // Quando streaming está ativo mas nenhum texto chegou ainda (conexão
    // estabelecida, aguardando primeiro AiTextDelta), exibe 3 linhas pulsantes.
    // Transição natural: skeleton → SelectableText (primeiros chars) → MarkdownBody.
    if (widget.isStreaming && _displayText.isEmpty && _networkBuffer.isEmpty) {
      return RepaintBoundary(
        child: _AiSkeletonLines(dark: widget.dark),
      );
    }

    // Build 123: _visibleCount não bloqueia mais — sempre exibe se há texto.
    if (_visibleCount == 0) return const SizedBox.shrink();

    // ── BUILD 462: DIPARO ÚNICO DO MARKDOWN ─────────────────────────────────
    // DURANTE streaming ativo (!_streamingComplete):
    //   → SelectableText com estilo limpo (height: 1.45) — zero overhead de parse
    //   → texto bruto do _displayText acumulado pelo batch timer (40ms)
    //   → SelectionArea do pai permanece 100% funcional
    //
    // APÓS conclusão (_streamingComplete = true):
    //   → MarkdownBody substitui SelectableText EM UM ÚNICO FRAME
    //   → aplica negritos, listas, emojis de card 🟥, hierarquia clínica
    //   → usuário vivencia velocidade do texto cru + layout premium na finalização
    if (widget.isStreaming && !_streamingComplete) {
      // ── Texto em fluxo: SelectableText cru, máxima velocidade ──────────────
      final rawText = _displayText.isNotEmpty ? _displayText : '';
      // Remove cursor ▌ do texto bruto (adicionado pelo _computeBlocksFromText)
      final displayRaw = rawText.replaceAll('\u258c', '');
      final textColor  = widget.dark
          ? Colors.white.withOpacity(0.88)
          : const Color(0xFF1A202C);
      return RepaintBoundary(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: SelectableText(
            displayRaw,
            style: TextStyle(
              fontSize: 14.5,
              color: textColor,
              height: 1.45,
              fontFamily: 'Roboto',
              letterSpacing: 0.01,
            ),
          ),
        ),
      );
    }

    // ── Streaming concluído ou bolha histórica: _AiBlockBubble com MarkdownBody
    // Build 123 — texto único direto: sem join, sem fragmentação.
    // Build 188: usa _displayText (pode vir do notifier) em vez de widget.text.
    final unified = _cachedBlocks.isNotEmpty
        ? _cachedBlocks.first
        : _displayText.trim();

    if (unified.isEmpty) return const SizedBox.shrink();

    return RepaintBoundary(
      child: _AiBlockBubble(
        block: unified,
        dark: widget.dark,
        isLast: true,
        onCopy: widget.onCopy,
        onTts: widget.onTts,
        ttsPlaying: widget.ttsPlaying,
        ttsReady: widget.ttsReady,
        lang: widget.lang,
        onChipTap: widget.onChipTap,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AiSkeletonLines — BUILD 462-STREAMING-CORE
//
// Skeleton screen exibido durante a fase "AiStarted": quando a conexão com o
// backend foi estabelecida mas o primeiro AiTextDelta ainda não chegou.
//
// Implementação: 3 linhas de larguras diferentes animadas com shimmer pulsante
// via AnimationController. Segue a paleta dark/light do app.
// ─────────────────────────────────────────────────────────────────────────────
class _AiSkeletonLines extends StatefulWidget {
  final bool dark;
  const _AiSkeletonLines({required this.dark});

  @override
  State<_AiSkeletonLines> createState() => _AiSkeletonLinesState();
}

class _AiSkeletonLinesState extends State<_AiSkeletonLines>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.25, end: 0.65).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.dark
        ? const Color(0xFF2A3040)
        : const Color(0xFFE2E8F0);

    return AnimatedBuilder(
      animation: _opacity,
      builder: (_, __) => Opacity(
        opacity: _opacity.value,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _skeletonBar(baseColor, double.infinity),
              const SizedBox(height: 8),
              _skeletonBar(baseColor, double.infinity),
              const SizedBox(height: 8),
              _skeletonBar(baseColor, 180),
            ],
          ),
        ),
      ),
    );
  }

  Widget _skeletonBar(Color color, double width) => Container(
    height: 13,
    width: width,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(6),
    ),
  );
}



// ─────────────────────────────────────────────────────────────────────────────
// Typing indicator
// ─────────────────────────────────────────────────────────────────────────────
class _ThinkingBubble extends StatefulWidget {
  final bool dark;
  const _ThinkingBubble({required this.dark});
  @override
  State<_ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<_ThinkingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    // Build 125 — flat indicator: zero bg, zero shadow, flutuates on scaffold
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, right: 52),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              return AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) {
                  final offset = ((_ctrl.value * 3) - i).clamp(0.0, 1.0);
                  final bounce = (offset < 0.5 ? offset : 1.0 - offset) * 2;
                  return Padding(
                    padding: EdgeInsets.only(left: i > 0 ? 5 : 0),
                    child: Transform.translate(
                      offset: Offset(0, -4 * bounce),
                      child: Container(
                        width: 7, height: 7,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TypingIndicator — 3 pontos animados (alias de _ThinkingBubble)
//
// Exibido enquanto a IA está processando (fase de "pensando" antes do
// primeiro chunk chegar). Transição natural: ThinkingBubble → streaming bubble.
// ─────────────────────────────────────────────────────────────────────────────
typedef _TypingIndicator = _ThinkingBubble;

// ─────────────────────────────────────────────────────────────────────────────
// _DisconnectedInputLock — BUILD 277
//
// Replaces the InputBar for non-admin/non-master users when no AI connection
// is active. Shows:
//   • A ghosted, locked text field (AbsorbPointer + opacity 0.28)
//   • "Acesso Restrito à IA" label in muted text
//   • Premium ElevatedButton in MedCases crimson (#AC2A2A) to trigger Google Auth
//
// Design principle: the obstruction is intentional — it communicates clearly
// that connecting is required, without being alarmist (no red banners).
// ─────────────────────────────────────────────────────────────────────────────
class _DisconnectedInputLock extends StatelessWidget {
  final bool dark;
  final String lang;
  final VoidCallback onConnect;

  const _DisconnectedInputLock({
    required this.dark,
    required this.lang,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    final isEs = lang == 'es';
    final bg   = dark ? const Color(0xFF1A1D23) : const Color(0xFFF5F5F5);
    final borderColor = dark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.08);
    final labelColor = dark
        ? Colors.white.withOpacity(0.38)
        : Colors.black.withOpacity(0.42);

    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Ghosted text field (visual only) ──────────────────────────────
          Opacity(
            opacity: 0.28,
            child: AbsorbPointer(
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                  color: dark ? const Color(0xFF252930) : Colors.white,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.centerLeft,
                child: Text(
                  // ORDEM 47 M1: 🔒 prefix reforça o bloqueio visualmente
                  isEs ? '🔒 Conecta Google para usar la IA...'
                       : '🔒 Conecte o Google para usar a IA...',
                  style: TextStyle(
                    fontSize: 14,
                    color: dark ? Colors.white54 : Colors.black38,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // ── Access restricted label ─────────────────────────────────────
          Text(
            isEs ? 'Acceso Restringido a la IA'
                 : 'Acesso Restrito à IA',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: labelColor,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 10),
          // ── Premium connect button ───────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onConnect,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFAC2A2A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                elevation: 0,
              ),
              child: Text(
                isEs ? '🔑 Conectar via Google para activar IA'
                     : '🔑 Conectar via Google para ativar IA',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
class _ResponseModeToggle extends StatelessWidget {
  final bool value;        // Build 152: renamed from longResponse → value (state-binding fix)
  final bool dark;
  final String lang;
  final ValueChanged<bool> onChanged;

  const _ResponseModeToggle({
    required this.value,
    required this.dark,
    required this.lang,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bool isEs = lang == 'es';

    // Build 158.2 — Labels texto puro, sem emojis/ícones (visual sóbrio e profissional)
    final labelGuardia = isEs ? 'Guardia' : 'Plantão';
    final labelEstudio = isEs ? 'Estudio'  : 'Estudos';

    // Build 158.2 — Pills minimalistas:
    // Ativo: fundo transparente + borda ciano fina e nítida (SEM glow/sombra)
    // Inativo: fundo cinza sólido discreto, sem borda especial
    const neonCyan   = Color(0xFF00E5FF);
    final inactiveText = dark
        ? Colors.white.withOpacity(0.55)
        : Colors.black.withOpacity(0.45);
    final inactiveBg   = dark
        ? const Color(0xFF374151)
        : const Color(0xFFE0E0E0);

    Widget _pill({
      required String label,
      required bool isActive,
      required VoidCallback onTap,
    }) {
      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
          decoration: BoxDecoration(
            // Ativo: transparente + borda ciano sólida e nítida (sem glow)
            // Inativo: cinza sólido sem borda especial
            color: isActive ? Colors.transparent : inactiveBg,
            borderRadius: BorderRadius.circular(24),
            border: isActive
                ? Border.all(color: neonCyan, width: 1.5)
                : Border.all(color: Colors.transparent, width: 1.5),
            // Build 158.2: sem boxShadow — eliminado glow neon por completo
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? neonCyan : inactiveText,
              letterSpacing: 0.2,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 16, right: 16),
      child: Align(
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          // BUILD 283 ORDEM 10.4: Estudos ESQUERDA (gratuito/padrão) | Plantão DIREITA
          children: [
            _pill(
              label: labelEstudio,
              isActive: value,
              onTap: () => onChanged(true),
            ),
            const SizedBox(width: 8),
            _pill(
              label: labelGuardia,
              isActive: !value,
              onTap: () => onChanged(false),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet de status da IA — mostra estado atual + botão "Conectar com Google"
// ─────────────────────────────────────────────────────────────────────────────
class _AiStatusSheet extends StatefulWidget {
  final String userEmail;
  final String userName;
  final String lang;
  final bool dark;
  final bool hasAi;
  final bool geminiConnected;
  final String geminiEmail;
  final bool geminiLoading;
  final bool keyLoading;

  const _AiStatusSheet({
    required this.userEmail,
    required this.userName,
    required this.lang,
    required this.dark,
    required this.hasAi,
    this.geminiConnected = false,
    this.geminiEmail = '',
    this.geminiLoading = false,
    this.keyLoading = false,
  });

  @override
  State<_AiStatusSheet> createState() => _AiStatusSheetState();
}

class _AiStatusSheetState extends State<_AiStatusSheet> {
  bool get _isEs => widget.lang == 'es';
  bool _connectTriggeredByUser = false; // guard: só mostra erro se o usuário tocou

  Future<void> _handleGoogleConnect() async {
    // Marca que esta conexão foi iniciada explicitamente pelo usuário.
    // Isso impede que qualquer chamada interna/acidental mostre o banner.
    _connectTriggeredByUser = true;
    final p = context.read<AppProvider>();

    // connectGemini() retorna:
    //   true  → conectou com sucesso
    //   false → falha real (cancelou, erro de rede)
    //   null  → redirect OAuth iniciado (Safari/web) — página vai recarregar
    final result = await p.connectGemini();
    if (!mounted) return;

    if (result == null) {
      // Redirect iniciado — mostra feedback e aguarda o reload
      // O modal HTML já está visível; o usuário está vendo "Entrar com Google"
      // Não mostramos SnackBar de erro aqui — a página vai recarregar em breve
      // Build 188: debugPrint removido do hot path
    } else if (result == false && _connectTriggeredByUser) {
      // Falha real — mostra erro
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEs
              ? 'No se pudo conectar con Google. Intente de nuevo.'
              : 'Não foi possível conectar com o Google. Tente novamente.'),
          backgroundColor: const Color(0xFFB91C1C),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        ),
      );
    }
    _connectTriggeredByUser = false;
  }

  Future<void> _handleGoogleDisconnect() async {
    final p = context.read<AppProvider>();
    await p.disconnectGemini();
  }

  @override
  Widget build(BuildContext context) {
    // BUILD 326: Consumer<AiChatProvider> em vez de Consumer<AppProvider>.
    // Apenas este widget reconstrói quando Gemini conecta/desconecta —
    // o restante da ai_screen NÃO é afetado.
    return Consumer<AiChatProvider>(
      builder: (context, aiChat, _) {
        final dark           = widget.dark;
        final isEs           = _isEs;
        final geminiConn     = aiChat.geminiConnected;
        final geminiEmail    = aiChat.geminiEmail;
        final geminiLoading  = aiChat.geminiLoading;
        final hasAnyAi       = aiChat.hasAnyAi;

        final bg     = dark ? const Color(0xFF0F1A14) : Colors.white;
        final cardBg = dark ? const Color(0xFF2D3340) : const Color(0xFFF5F7F5);
        final divCol = dark ? Colors.white12 : Colors.black.withOpacity(0.08);
        final sub    = dark ? Colors.white54 : Colors.black54;
        final text   = dark ? Colors.white : const Color(0xFF1A1D23);
        const green  = Color(0xFF10B981);
        const blue   = Color(0xFF1A73E8); // cor Google azul

        // BUILD 337-AI-TEXTS: Badge do monitor de servidor
        // Ativo → pílula verde 'Servidor Activo' (Es) / 'Servidor Ativo' (Pt)
        // Offline → pílula vermelha 'Servidor Offline'
        final String badgeLabel;
        if (geminiLoading || widget.keyLoading) {
          badgeLabel = isEs ? 'Conectando...' : 'Conectando...';
        } else if (hasAnyAi) {
          badgeLabel = isEs ? 'Servidor Activo' : 'Servidor Ativo';
        } else {
          badgeLabel = 'Servidor Offline';
        }
        // Cor da pílula: verde quando ativo, vermelho quando offline
        final bool serverActive = !geminiLoading && !widget.keyLoading && hasAnyAi;

        // BUILD 337-AI-TEXTS: Linha 1 — cabeçalho unificado de servidor
        // Fixo em todos os estados: descreve a integração do servidor
        const String modeLabel =
            'SERVIDOR MEDCASES IA — INTEGRADO A GOOGLE GEMINI';

        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.fromLTRB(
              20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [

            // Drag handle
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: dark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2)),
            ),

            // ── Card principal — conta + status da IA ────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: hasAnyAi
                      ? [const Color(0xFF064E35), const Color(0xFF1B5E3B), const Color(0xFF10B981)]
                      : [dark ? const Color(0xFF2D3340) : const Color(0xFFF0F4F1),
                         dark ? const Color(0xFF1E2E22) : const Color(0xFFE8F0EA)],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // SUPER ORDEM MASTER 12 M3: Logo M+ dourado premium substitui avatar de letra/ícone de cérebro
                Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1A1100), Color(0xFF2C1E00)],
                      ),
                      border: Border.all(
                        color: const Color(0xFFD4AF37).withOpacity(0.40),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD4AF37).withOpacity(0.18),
                          blurRadius: 10, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'M+',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFD4AF37), // ouro premium
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.userName.isNotEmpty)
                        Text(widget.userName,
                          style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700,
                            color: hasAnyAi ? Colors.white : text),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(
                        widget.userEmail.isNotEmpty ? widget.userEmail
                            : (isEs ? 'Sin cuenta' : 'Sem conta'),
                        style: TextStyle(
                          fontSize: 12,
                          color: hasAnyAi
                              ? Colors.white.withOpacity(0.65)
                              : sub),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  )),
                  // Badge status
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      // BUILD 337: verde=ativo, vermelho=offline (pílula do monitor)
                      color: (geminiLoading || widget.keyLoading)
                          ? Colors.white.withOpacity(0.08)
                          : (serverActive
                              ? Colors.white.withOpacity(0.15)
                              : const Color(0xFFB91C1C).withOpacity(0.18)),
                      border: Border.all(
                        color: (geminiLoading || widget.keyLoading)
                            ? Colors.white.withOpacity(0.15)
                            : (serverActive
                                ? Colors.white.withOpacity(0.3)
                                : const Color(0xFFEF4444).withOpacity(0.40))),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (geminiLoading || widget.keyLoading)
                        SizedBox(
                          width: 8, height: 8,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.2,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        )
                      else
                        Container(
                          width: 6, height: 6,
                          margin: const EdgeInsets.only(right: 5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            // Verde quando ativo, vermelho quando offline
                            color: serverActive
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444)),
                        ),
                      const SizedBox(width: 5),
                      Text(
                        badgeLabel,
                        style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: (geminiLoading || widget.keyLoading)
                              ? Colors.white.withOpacity(0.5)
                              : (serverActive
                                  ? Colors.white
                                  : const Color(0xFFEF4444)))),
                    ]),
                  ),
                ]),

                const SizedBox(height: 16),
                Divider(
                  color: hasAnyAi
                      ? Colors.white.withOpacity(0.15)
                      : divCol,
                  height: 1),
                const SizedBox(height: 14),

                // Linha: modo de operação
                Row(children: [
                  Icon(Icons.psychology_rounded, size: 14,
                    color: hasAnyAi
                        ? Colors.white.withOpacity(0.7)
                        : sub),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    modeLabel,
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: hasAnyAi ? Colors.white : text))),
                ]),
                const SizedBox(height: 8),

                // BUILD 337 Linha 2: +1000 fármacos · modos (acréscimo/fármacos)
                Row(children: [
                  Icon(Icons.medication_rounded, size: 14,
                    color: hasAnyAi
                        ? Colors.white.withOpacity(0.6)
                        : sub),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    isEs
                        ? '+1000 FÁRMACOS — MODO ESTUDIO — MODO GUARDIA'
                        : '+1000 FÁRMACOS — MODO ESTUDO — MODO PLANTÃO',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 0.3,
                      color: hasAnyAi
                          ? Colors.white.withOpacity(0.7)
                          : sub))),
                ]),

                // BUILD 337 Linha 3: modelo unificado LLM — sempre visível
                const SizedBox(height: 8),
                Row(children: [
                  Icon(
                    geminiConn
                        ? Icons.account_circle_rounded
                        : Icons.cloud_done_rounded,
                    size: 14,
                    color: const Color(0xFF10B981).withOpacity(0.8)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    geminiConn && geminiEmail.isNotEmpty
                        ? geminiEmail
                        : 'SERVIDOR MEDCASES IA — INTEGRADO AO GOOGLE GEMINI — GPT MINI 4',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: geminiConn && geminiEmail.isNotEmpty
                          ? 0.0
                          : 0.2,
                      color: hasAnyAi
                          ? Colors.white.withOpacity(0.65)
                          : sub),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
              ]),
            ),

            const SizedBox(height: 14),

            // ── Botão principal: Conectar com Google / Desconectar ────────
            if (geminiConn)
              // Conectado — mostra email + botão desconectar
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF1A73E8).withOpacity(0.25)),
                ),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: blue.withOpacity(0.12),
                    ),
                    child: const Center(
                      child: Icon(Icons.account_circle_rounded,
                        color: blue, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEs ? 'Google conectado' : 'Google conectado',
                        style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: text)),
                      if (geminiEmail.isNotEmpty)
                        Text(
                          geminiEmail,
                          style: TextStyle(fontSize: 11, color: sub),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  )),
                  GestureDetector(
                    onTap: geminiLoading ? null : _handleGoogleDisconnect,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: const Color(0xFFB91C1C).withOpacity(0.1),
                        border: Border.all(
                          color: const Color(0xFFB91C1C).withOpacity(0.25)),
                      ),
                      child: geminiLoading
                          ? SizedBox(
                              width: 12, height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: const Color(0xFFEF4444).withOpacity(0.7),
                              ),
                            )
                          : Text(
                              isEs ? 'Desconectar' : 'Desconectar',
                              style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700,
                                color: Color(0xFFEF4444))),
                    ),
                  ),
                ]),
              )
            else
              // Não conectado — botão proeminente "Conectar com Google"
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: geminiLoading ? null : _handleGoogleConnect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: blue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: blue.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    elevation: 0),
                  child: geminiLoading
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.account_circle_rounded, size: 20),
                            const SizedBox(width: 8),
                            // BUILD 337: botão de gatilho OAuth — texto canônico
                            Text(
                              'Conectar con Google ➔ IA Clínica',
                              style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700)),
                          ],
                        ),
                ),
              ),

            const SizedBox(height: 2),

            // BUILD 337: subtexto do botão OAuth
            // '3 clics · usa tu propria cuenta Google' — sem mencionar clave API
            if (!geminiConn)
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 4),
                child: Text(
                  '3 clics · usa tu propria cuenta Google',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: sub,
                    fontWeight: FontWeight.w500)),
              ),

            const SizedBox(height: 14),

            // ── Explicação do modo híbrido ─────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: divCol)),
              // BUILD 337-AI-TEXTS: cards de benefícios — arquitetura de mensagem definitiva
              child: Column(children: [
                // Card 1 — Base clínica ativa (ícone de faísca)
                InfoRow(
                  icon: Icons.auto_awesome_rounded,
                  iconColor: green,
                  dark: dark,
                  label: isEs
                      ? 'Base clínica activa'
                      : 'Base clínica ativa',
                  sub: 'Protocolos e fármacos respondem instantaneamente.',
                ),
                const SizedBox(height: 10),
                // Card 2 — Gemini · GPT enriquece (ícone de hub/IA)
                InfoRow(
                  icon: Icons.hub_rounded,
                  iconColor: hasAnyAi ? green : sub,
                  dark: dark,
                  label: isEs
                      ? 'Gemini · GPT enriquece lo que la base no cubre'
                      : 'Gemini · GPT enriquece o que a base não cobre',
                  sub: 'Perguntas fora da base são respondidas com conhecimento médico global.',
                  dimmed: !hasAnyAi,
                ),
              ]),
            ),

            const SizedBox(height: 16),

            // ── Botão fechar ────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  elevation: 0),
                child: Text(
                  isEs ? 'Entendido' : 'Entendido',
                  style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HISTÓRICO DE CHATS — bottom sheet com até 10 sessões salvas
// ─────────────────────────────────────────────────────────────────────────────
// MICRO-BUILD 462E-A.5.3.7.3.2.5.2 [PILLAR 3]:
// _ChatHistorySheet no longer holds sessions as a constructor parameter.
// Instead, sessions are injected by the Selector builder in _openHistory()
// and passed as a typed List<AiSessionSummary> — pure data, reactive.
class _ChatHistorySheet extends StatelessWidget {
  // sessions is passed from the Selector builder — no manual param tracking.
  final List<AiSessionSummary> sessions;
  final bool dark;
  final String lang;
  final void Function(AiSessionSummary) onRestoreSummary;
  final void Function(String) onDelete;

  const _ChatHistorySheet({
    required this.sessions,
    required this.dark,
    required this.lang,
    required this.onRestoreSummary,
    required this.onDelete,
  });

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return 'Hoje às $h:$m';
    } else if (diff.inDays == 1) {
      return 'Ontem';
    } else if (diff.inDays < 7) {
      const days = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
      return days[dt.weekday % 7];
    } else {
      final d = dt.day.toString().padLeft(2, '0');
      final mo = dt.month.toString().padLeft(2, '0');
      return '$d/$mo/${dt.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg    = dark ? const Color(0xFF1A1D23) : Colors.white;
    final textP = dark ? Colors.white : const Color(0xFF1A1D23);
    final textS = dark ? Colors.white54 : Colors.black45;
    final divC  = dark ? Colors.white10 : const Color(0xFFEEEEEE);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Container(
          margin: const EdgeInsets.only(top: 10, bottom: 4),
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: dark ? Colors.white24 : Colors.black12,
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: const Color(0xFF10B981).withOpacity(0.15),
              ),
              child: const Icon(Icons.history_rounded,
                size: 16, color: Color(0xFF10B981)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                lang == 'es' ? 'Historial de consultas' : 'Histórico de consultas',
                style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: textP),
              ),
              Text(
                '${sessions.length} ${lang == 'es' ? 'sesiones guardadas' : 'sessões salvas'} (máx. 10)',
                style: TextStyle(fontSize: 11, color: textS),
              ),
            ])),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dark ? Colors.white10 : Colors.black.withOpacity(0.06),
                ),
                child: Icon(Icons.close_rounded, size: 16, color: textS),
              ),
            ),
          ]),
        ),

        // Divisor
        Container(height: 1, color: divC, margin: const EdgeInsets.only(bottom: 4)),

        // Lista de sessões — driven by Selector<AppProvider, List<AiSessionSummary>>
        sessions.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(40),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.chat_bubble_outline_rounded,
                    size: 40, color: dark ? Colors.white24 : Colors.black26),
                  const SizedBox(height: 12),
                  Text(
                    lang == 'es'
                        ? 'Aún no hay consultas guardadas.\nInicia un "Nuevo Chat" para crear una sesión.'
                        : 'Nenhuma consulta salva ainda.\nInicie um "Novo Chat" para criar uma sessão.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13, color: textS, height: 1.5),
                  ),
                ]),
              )
            : Flexible(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(0, 4, 0, 20),
                  itemCount: sessions.length,
                  separatorBuilder: (_, __) =>
                    Container(height: 1, color: divC, margin: const EdgeInsets.symmetric(horizontal: 18)),
                  itemBuilder: (context, i) {
                    final s = sessions[i];
                    // Source badge colour: green=v2, amber=legacy, grey=local.
                    final sourceDot = s.source == AiSessionSource.canonicalV2
                        ? const Color(0xFF10B981)
                        : s.source == AiSessionSource.legacyInline
                            ? const Color(0xFFF59E0B)
                            : Colors.grey;
                    // Date from millisecond epoch.
                    final updatedDt = DateTime.fromMillisecondsSinceEpoch(s.updatedAt);
                    return Dismissible(
                      key: ValueKey(s.sessionId),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: const Color(0xFFCC2222).withOpacity(0.1),
                        child: const Icon(Icons.delete_outline_rounded,
                          color: Color(0xFFCC2222), size: 22),
                      ),
                      onDismissed: (_) => onDelete(s.sessionId),
                      child: InkWell(
                        onTap: () => onRestoreSummary(s),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          child: Row(children: [
                            // Session icon with source-coloured index badge.
                            Container(
                              width: 38, height: 38,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: sourceDot.withOpacity(0.1),
                              ),
                              child: Center(
                                child: Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w800,
                                    color: sourceDot),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.title.isNotEmpty ? s.title : '(sem resumo)',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600,
                                    color: textP, height: 1.3),
                                ),
                                const SizedBox(height: 3),
                                Row(children: [
                                  Icon(Icons.cloud_done_outlined,
                                    size: 10, color: sourceDot),
                                  const SizedBox(width: 4),
                                  Text(
                                    s.source == AiSessionSource.canonicalV2
                                        ? 'v2'
                                        : s.source == AiSessionSource.legacyInline
                                            ? 'legacy'
                                            : 'local',
                                    style: TextStyle(fontSize: 10, color: textS)),
                                  const SizedBox(width: 10),
                                  Icon(Icons.access_time_rounded,
                                    size: 10, color: textS),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatDate(updatedDt),
                                    style: TextStyle(fontSize: 10, color: textS)),
                                ]),
                              ],
                            )),
                            const SizedBox(width: 8),
                            Icon(Icons.chevron_right_rounded,
                              size: 18, color: textS),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BUILD 310 — _AmbassadorPanel: VIP ModalBottomSheet for partners
// Apple Safe: rendered only when isPartner==true. Zero exposure to App Review.
// ─────────────────────────────────────────────────────────────────────────────
class _AmbassadorPanel extends StatefulWidget {
  final UserModel user;
  final String lang;
  final List<_ChatMsg> messages;
  final Future<bool> Function(String prompt) onSecondOpinion;
  final AppProvider provider;

  const _AmbassadorPanel({
    required this.user,
    required this.lang,
    required this.messages,
    required this.onSecondOpinion,
    required this.provider,
  });

  @override
  State<_AmbassadorPanel> createState() => _AmbassadorPanelState();
}

class _AmbassadorPanelState extends State<_AmbassadorPanel> {
  static const _kGold      = Color(0xFFD4AF37);
  static const _kGoldLight = Color(0xFFFFE8A6);
  static const _kBg        = Color(0xFF0E1218);

  // Second Opinion state
  bool   _soLoading = false;
  bool   _soStreamed = false;
  String _soResult  = '';

  // Referral count
  int  _referralCount = 0;
  bool _countLoading  = true;

  @override
  void initState() {
    super.initState();
    _loadReferralCount();
  }

  Future<void> _loadReferralCount() async {
    try {
      final link   = widget.user.referralLink ?? '';
      final slug   = link.isNotEmpty ? link.split('/').last : widget.user.uid;
      final count  = await ReferralService.getConversionCount(slug);
      if (mounted) setState(() { _referralCount = count; _countLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _countLoading = false);
    }
  }

  void _copyLink() {
    final link = widget.user.referralLink ?? '';
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(widget.lang == 'es' ? 'Link copiado 📋' : 'Link copiado 📋'),
      backgroundColor: _kGold.withOpacity(0.9),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _shareWhatsApp() async {
    final link = widget.user.referralLink ?? '';
    final msg  = widget.lang == 'es'
        ? '¡Hola! Te invito a usar MedCases Pro, la mejor IA clínica para médicos. '
          'Accede con mi link exclusivo: $link'
        : 'Olá! Te convido a usar o MedCases Pro, a melhor IA clínica para médicos. '
          'Acesse com meu link exclusivo: $link';
    final encoded = Uri.encodeComponent(msg);
    final uri = Uri.parse('https://wa.me/?text=$encoded');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _runSecondOpinion() async {
    if (_soLoading || widget.messages.isEmpty) return;
    setState(() { _soLoading = true; _soStreamed = false; _soResult = ''; });

    // BUILD 313 — Prompt VIP humanizado: frase orgânica de médico,
    // sem estrutura de comando de sistema que dispara guardrail.
    // O contexto da conversa é injetado como histórico natural da sessão.
    final lang = widget.lang;

    final humanizedPrompt = lang == 'es'
        ? '¿Puede hacer un análisis clínico profundo y avanzado de este caso, '
          'basado en las últimas evidencias científicas disponibles? '
          'Me gustaría una segunda opinión estructurada que incluya: '
          'una evaluación del riesgo del paciente, '
          'la justificación fisiopatológica de la conducta adoptada, '
          'y si la misma está alineada con los guidelines internacionales vigentes.'
        : 'Pode fazer uma análise clínica aprofundada e avançada deste caso, '
          'baseada nas últimas evidências científicas disponíveis? '
          'Gostaria de uma segunda opinião estruturada que inclua: '
          'uma avaliação do risco do paciente, '
          'a justificativa fisiopatológica da conduta adotada, '
          'e se a mesma está alinhada com os guidelines internacionais vigentes.';

    // Injeta o histórico da conversa como contexto natural da mensagem
    final history = widget.messages
        .where((m) => m.role == 'user' || m.role == 'ai')
        .map((m) => '${m.role == 'user' ? '[Médico]' : '[IA]'}: ${m.text}')
        .join('\n\n');

    final fullPrompt = '$humanizedPrompt\n\n--- Contexto da consulta ---\n$history';

    // Stream via provider
    await widget.provider.sendAiMessage(
      fullPrompt,
      onChunk: (accumulated) {
        if (mounted) setState(() => _soResult = accumulated);
      },
      onDone: (finalText) {
        if (mounted) setState(() {
          _soResult  = finalText.isNotEmpty ? finalText : _soResult;
          _soLoading = false;
          _soStreamed = true;
        });
      },
      onError: (err) {
        if (mounted) setState(() {
          _soLoading = false;
          _soResult  = widget.lang == 'es'
              ? '⚠️ Error al generar el informe. Intente nuevamente.'
              : '⚠️ Erro ao gerar o relatório. Tente novamente.';
          _soStreamed = true;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang  = widget.lang;
    final user  = widget.user;
    final link  = user.referralLink ?? '';
    final title = user.partnerTitle ?? (lang == 'es' ? 'Embajador' : 'Embaixador');

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        decoration: BoxDecoration(
          color: _kBg.withOpacity(0.97),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: const Border(
            top:   BorderSide(color: _kGold, width: 1.5),
            left:  BorderSide(color: Color(0x44D4AF37), width: 0.8),
            right: BorderSide(color: Color(0x44D4AF37), width: 0.8),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Handle bar ──────────────────────────────────────────────
                Center(child: Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: _kGold.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                )),

                // ── Header ──────────────────────────────────────────────────
                Row(children: [
                  const Text('👑', style: TextStyle(fontSize: 26)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: _kGold,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                      ),
                      Text(
                        user.displayName,
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ],
                  )),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                ]),
                const SizedBox(height: 24),

                // ═══════════════════════════════════════════════════════════
                // SEÇÃO A — Crescimento: Referral Link + Share + Count
                // ═══════════════════════════════════════════════════════════
                _SectionHeader(
                  icon: Icons.link_rounded,
                  label: lang == 'es' ? 'Su red de crecimiento' : 'Sua rede de crescimento',
                ),
                const SizedBox(height: 12),

                // Link display
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: _kGold.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kGold.withOpacity(0.25)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.link_rounded, color: _kGold, size: 16),
                    const SizedBox(width: 10),
                    Expanded(child: Text(
                      link.isNotEmpty ? link : '—',
                      style: const TextStyle(color: Colors.white, fontSize: 13,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    )),
                  ]),
                ),
                const SizedBox(height: 10),

                // Action buttons row
                Row(children: [
                  // Copy button
                  Expanded(child: _GoldButton(
                    icon: Icons.copy_rounded,
                    label: lang == 'es' ? 'Copiar link' : 'Copiar link',
                    onTap: _copyLink,
                  )),
                  const SizedBox(width: 10),
                  // WhatsApp share button
                  Expanded(child: _GoldButton(
                    icon: Icons.share_rounded,
                    label: 'WhatsApp',
                    onTap: _shareWhatsApp,
                    color: const Color(0xFF25D366),
                  )),
                ]),
                const SizedBox(height: 14),

                // Referral count badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.group_rounded, color: _kGold, size: 22),
                    const SizedBox(width: 12),
                    _countLoading
                        ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: _kGold))
                        : Expanded(child: Text(
                            lang == 'es'
                                ? 'Su red: $_referralCount médico${_referralCount != 1 ? 's' : ''} integrado${_referralCount != 1 ? 's' : ''}'
                                : 'Sua rede: $_referralCount médico${_referralCount != 1 ? 's' : ''} integrado${_referralCount != 1 ? 's' : ''}',
                            style: const TextStyle(
                                color: _kGoldLight, fontSize: 14, fontWeight: FontWeight.w700),
                          )),
                  ]),
                ),
                const SizedBox(height: 28),

                // ═══════════════════════════════════════════════════════════
                // SEÇÃO B — Segunda Opinião
                // ═══════════════════════════════════════════════════════════
                _SectionHeader(
                  icon: Icons.auto_awesome_rounded,
                  label: lang == 'es' ? 'Superpoder Clínico' : 'Superpoder Clínico',
                ),
                const SizedBox(height: 12),

                // If Second Opinion not yet triggered → show button
                if (!_soStreamed && !_soLoading) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: widget.messages.isEmpty ? null : _runSecondOpinion,
                      icon: const Text('🪄', style: TextStyle(fontSize: 18)),
                      label: Text(
                        lang == 'es'
                            ? 'Generar Informe de Segunda Opinión'
                            : 'Gerar Relatório de Segunda Opinião',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A1D28),
                        foregroundColor: _kGoldLight,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: _kGold, width: 1.2),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  if (widget.messages.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        lang == 'es'
                            ? 'Inicie una consulta para generar la segunda opinión.'
                            : 'Inicie uma consulta para gerar a segunda opinião.',
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],

                // Loading spinner while streaming
                if (_soLoading && !_soStreamed) ...[
                  const Center(child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Column(children: [
                      CircularProgressIndicator(color: _kGold),
                      SizedBox(height: 12),
                      Text('Gerando relatório clínico...',
                          style: TextStyle(color: Colors.white54, fontSize: 12)),
                    ]),
                  )),
                  // Live streaming preview
                  if (_soResult.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: MarkdownBody(
                        data: _soResult,
                        styleSheet: MarkdownStyleSheet(
                          p: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
                          h1: const TextStyle(color: _kGoldLight, fontSize: 15, fontWeight: FontWeight.w900),
                          h2: const TextStyle(color: _kGoldLight, fontSize: 14, fontWeight: FontWeight.w800),
                          h3: const TextStyle(color: _kGold, fontSize: 13, fontWeight: FontWeight.w700),
                          strong: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                ],

                // Final Markdown result
                if (_soStreamed && _soResult.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _kGold.withOpacity(0.20)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.check_circle_rounded, color: _kGold, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            lang == 'es' ? 'Informe de Segunda Opinión' : 'Relatório de Segunda Opinião',
                            style: const TextStyle(
                                color: _kGoldLight, fontSize: 13, fontWeight: FontWeight.w800),
                          ),
                        ]),
                        const SizedBox(height: 12),
                        MarkdownBody(
                          data: _soResult,
                          styleSheet: MarkdownStyleSheet(
                            p: const TextStyle(color: Colors.white, fontSize: 13, height: 1.6),
                            h1: const TextStyle(color: _kGoldLight, fontSize: 16, fontWeight: FontWeight.w900),
                            h2: const TextStyle(color: _kGoldLight, fontSize: 14, fontWeight: FontWeight.w800),
                            h3: const TextStyle(color: _kGold, fontSize: 13, fontWeight: FontWeight.w700),
                            strong: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                            blockquote: const TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Copy result button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _soResult));
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(lang == 'es'
                                    ? 'Informe copiado al portapapeles'
                                    : 'Relatório copiado para a área de transferência'),
                                backgroundColor: _kGold.withOpacity(0.9),
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ));
                            },
                            icon: const Icon(Icons.copy_rounded, size: 15, color: _kGold),
                            label: Text(
                              lang == 'es' ? 'Copiar informe' : 'Copiar relatório',
                              style: const TextStyle(color: _kGold, fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: _kGold.withOpacity(0.4)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Regenerate
                        Center(child: TextButton(
                          onPressed: () => setState(() {
                            _soStreamed = false; _soResult = ''; _soLoading = false;
                          }),
                          child: Text(
                            lang == 'es' ? '↺ Regenerar informe' : '↺ Regenerar relatório',
                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                        )),
                      ],
                    ),
                  ),
                ],

              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Ambassador Panel helpers ──────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, color: const Color(0xFFD4AF37), size: 16),
    const SizedBox(width: 8),
    Text(label, style: const TextStyle(
        color: Color(0xFFFFE8A6), fontSize: 13, fontWeight: FontWeight.w800)),
    const SizedBox(width: 8),
    Expanded(child: Container(height: 0.5, color: const Color(0x44D4AF37))),
  ]);
}

class _GoldButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  const _GoldButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = const Color(0xFFD4AF37),
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// _CollapsibleReferencesBlock — Build 120
// Chip colapsável para o bloco "📚 REFERENCIAS / REFERÊNCIAS" gerado pela IA.
// Padrão: chip "📚 Ver Referencias Médicas ▾" (collapsed)
// Expandido: lista de bullets de referência em texto compacto cinza
// ─────────────────────────────────────────────────────────────────────────────
class _CollapsibleReferencesBlock extends StatefulWidget {
  final List<String> lines; // linhas de referência (sem o cabeçalho 📚)
  final bool dark;
  final String lang; // 'es' ou 'pt'
  const _CollapsibleReferencesBlock({
    required this.lines,
    required this.dark,
    this.lang = 'pt',
  });

  @override
  State<_CollapsibleReferencesBlock> createState() =>
      _CollapsibleReferencesBlockState();
}

class _CollapsibleReferencesBlockState
    extends State<_CollapsibleReferencesBlock> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final isEs = widget.lang == 'es';

    // Build 127 — Flat UI: sem fundo sólido, apenas label sutil flutuando no scaffold
    final labelColor = dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final textColor  = dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    // Label localizado
    final chipLabel = isEs ? 'Ver Referencias Médicas' : 'Ver Referências Médicas';

    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Chip colapsável ────────────────────────────────────────────────
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
              decoration: const BoxDecoration(
                color: Colors.transparent,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('📚', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 6),
                  Text(
                    chipLabel,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: labelColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 220),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        size: 16, color: labelColor),
                  ),
                ],
              ),
            ),
          ),

          // ── Conteúdo expandido: texto simples e compacto ────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOut,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 8, left: 2, right: 4),
                    child: Builder(
                      builder: (context) {
                        final references = widget.lines
                            .map((line) => line
                                .trim()
                                .replaceFirst(
                                  RegExp(r'^(?:[-*•]|\d+[.)])\s*'),
                                  '',
                                )
                                .replaceAll(RegExp(r'^[#]+\s*'), '')
                                .trim())
                            .where((line) => line.isNotEmpty)
                            .where((line) {
                              final normalized = line
                                  .replaceAll(':', '')
                                  .trim()
                                  .toUpperCase();
                              return normalized != 'REFERENCIAS' &&
                                  normalized != 'REFERÊNCIAS' &&
                                  normalized != '📚 REFERENCIAS' &&
                                  normalized != '📚 REFERÊNCIAS';
                            })
                            .toSet()
                            .toList();

                        return Text(
                          references.join('\n'),
                          style: TextStyle(
                            fontSize: 10.5,
                            color: textColor,
                            fontStyle: FontStyle.italic,
                            height: 1.5,
                          ),
                        );
                      },
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CollapsibleEvidenceBlock — chip colapsável de evidência no chat da IA
// Padrão: 1 linha "📊 EVIDENCIA CIENTÍFICA ▾"
// Expandido: EvidenceBadgesRow + EvidenceCardWidget + PharmacologicalDisclaimer
// ─────────────────────────────────────────────────────────────────────────────
class _CollapsibleEvidenceBlock extends StatefulWidget {
  final DrugEvidenceModel ev;
  final bool dark;
  const _CollapsibleEvidenceBlock({required this.ev, required this.dark});

  @override
  State<_CollapsibleEvidenceBlock> createState() => _CollapsibleEvidenceBlockState();
}

class _CollapsibleEvidenceBlockState extends State<_CollapsibleEvidenceBlock> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;

    // Build 127 — Flat UI total: sem fundo sólido, label colorido flutuante no scaffold
    final labelColor = dark
        ? const Color(0xFF34D399)
        : const Color(0xFF059669);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Trigger: label flutuante, zero container fill ────────────────────
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('📊',
                    style: TextStyle(
                        fontSize: 12,
                        color: labelColor.withOpacity(0.8))),
                const SizedBox(width: 5),
                Text(
                  'EVIDÊNCIA CIENTÍFICA',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: labelColor,
                    letterSpacing: 0.65,
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 220),
                  child: Icon(Icons.expand_more_rounded,
                      size: 14, color: labelColor.withOpacity(0.65)),
                ),
              ],
            ),
          ),
        ),

        // ── Conteúdo expandido — flat, sem borda ou fundo ────────────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: _expanded
              ? Container(
                  margin: const EdgeInsets.only(top: 2, bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      EvidenceBadgesRow(ev: widget.ev, compact: true),
                      const SizedBox(height: 6),
                      EvidenceCardWidget(ev: widget.ev),
                      const SizedBox(height: 6),
                      const PharmacologicalDisclaimer(),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
