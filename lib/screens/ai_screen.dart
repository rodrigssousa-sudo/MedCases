import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/common_widgets.dart' show MedBreakpoints, PharmacologicalDisclaimer, EvidenceCardWidget, EvidenceBadgesRow;
import '../models/drug_model.dart' show DrugEvidenceModel;
import '../data/evidence_database.dart';
import '../widgets/error_state_widget.dart'
    show InlineConnectionBanner;
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:convert';
import '../providers/app_provider.dart';
import '../data/drugs_database.dart';
import '../services/stt_helper.dart';
import '../services/firestore_service.dart';
import '../services/activity_service.dart';


// ─────────────────────────────────────────────────────────────────────────────
// Dados das sugestões rápidas
// ─────────────────────────────────────────────────────────────────────────────
class _Suggestion {
  final String labelPt;
  final String labelEs;
  final String promptPt;
  final String promptEs;
  const _Suggestion(this.labelPt, this.labelEs, this.promptPt, this.promptEs);
}

const _suggestions = [
  _Suggestion('IAM / dor torácica', 'IAM / dolor torácico',
    'Paciente com dor torácica intensa, diaforese e irradiação para braço esquerdo. Suspeita de IAM.',
    'Paciente con dolor torácico intenso, diaforesis e irradiación al brazo izquierdo. Sospecha de IAM.'),
  _Suggestion('Choque + hipotensão', 'Choque + hipotensión',
    'Paciente em choque com hipotensão, taquicardia e pele fria.',
    'Paciente en choque con hipotensión, taquicardia y piel fría.'),
  _Suggestion('Anafilaxia', 'Anafilaxia',
    'Reação anafilática aguda após contraste. PA 80/50, broncoespasmo.',
    'Reacción anafiláctica aguda. PA 80/50, broncoespasmo.'),
  _Suggestion('PCR / parada', 'PCR / parada',
    'Parada cardiorrespiratória. Sem pulso. Monitor: fibrilação ventricular.',
    'Parada cardiorrespiratoria. Sin pulso. FV no monitor.'),
  _Suggestion('TPSV / taquicardia', 'TPSV / taquicardia',
    'Taquicardia paroxística supraventricular, QRS estreito, FC 180.',
    'Taquicardia paroxística supraventricular, QRS estrecho, FC 180.'),
  _Suggestion('FA com alta resposta', 'FA con alta respuesta',
    'Fibrilação atrial com resposta ventricular rápida, FC 145 irregular.',
    'Fibrilación auricular con respuesta ventricular rápida, FC 145 irregular.'),
  _Suggestion('Crise hipertensiva', 'Crisis hipertensiva',
    'PA 210/120 com cefaleia intensa e confusão mental.',
    'PA 210/120 con cefalea intensa y confusión mental.'),
  _Suggestion('Sepse / febre', 'Sepsis / fiebre',
    'Febre alta, hipotensão, taquicardia e suspeita de sepse.',
    'Fiebre alta, hipotensión, taquicardia y sospecha de sepsis.'),
  _Suggestion('TEP / embolia', 'TEP / embolia',
    'Embolia pulmonar com dispneia súbita, PA 85/50, SatO2 85%.',
    'Embolia pulmonar con disnea súbita, PA 85/50, SatO2 85%.'),
  _Suggestion('DPOC exacerbação', 'EPOC exacerbación',
    'DPOC com piora de dispneia, PaCO2 68, pH 7,28.',
    'EPOC con empeoramiento de disnea, PaCO2 68, pH 7,28.'),
  _Suggestion('Asma grave', 'Asma grave',
    'Crise de asma grave, silêncio auscultório, SpO2 88%.',
    'Crisis de asma grave, silencio auscultatorio, SpO2 88%.'),
  _Suggestion('AVC isquêmico', 'ACV isquémico',
    'AVC isquêmico agudo, hemiplegia direita, NIHSS 14, 1h45 de evolução.',
    'ACV isquémico agudo, hemiplejía derecha, NIHSS 14, evolución 1h45.'),
  _Suggestion('Convulsão / status', 'Convulsión / status',
    'Convulsão há 8 min sem pausa. Estado de mal epiléptico.',
    'Convulsión de 8 min sin pausa. Estado epiléptico.'),
  _Suggestion('Meningite', 'Meningitis',
    'Febre, cefaleia em trovoada, rigidez de nuca, petéquias.',
    'Fiebre, cefalea en trueno, rigidez de nuca, petequias.'),
  _Suggestion('Cetoacidose / CAD', 'Cetoacidosis / CAD',
    'Cetoacidose diabética. Glicemia 480, pH 7,18, K+ 3,2.',
    'Cetoacidosis diabética. Glucemia 480, pH 7,18, K+ 3,2.'),
  _Suggestion('Hipoglicemia grave', 'Hipoglucemia grave',
    'Hipoglicemia grave, Glasgow 8, glicemia 28 mg/dL.',
    'Hipoglucemia grave, Glasgow 8, glucemia 28 mg/dL.'),
  _Suggestion('Hemorragia digestiva', 'Hemorragia digestiva',
    'Hematêmese, Hb 7,2, instabilidade hemodinâmica.',
    'Hematemesis, Hb 7,2, inestabilidad hemodinámica.'),
  _Suggestion('Insuf. cardíaca', 'Insuf. cardíaca',
    'IC descompensada, ortopneia, SatO2 91%, crepitações bibasais.',
    'IC descompensada, ortopnea, SatO2 91%, crepitantes bibasales.'),
  _Suggestion('K⁺ alto / hipercalemia', 'K⁺ alto / hipercalemia',
    'Hipercalemia grave K+ 7,1 com ondas T apiculadas no ECG.',
    'Hipercalemia grave K+ 7,1 con ondas T picudas en ECG.'),
  _Suggestion('Delirium / confusão', 'Delirium / confusión',
    'Confusão mental aguda, agitação, rebaixamento. Idoso de 78 anos.',
    'Confusión mental aguda, agitación. Anciano de 78 años.'),
];

// ─────────────────────────────────────────────────────────────────────────────
class _ChatMsg {
  // ID único estável — garante que Keys do ListView nunca mudam para a mesma mensagem.
  // Evita que o Flutter destrua/recrie bubbles ao rebuild durante streaming.
  final String id;
  final String role;
  final String text;

  _ChatMsg({required this.role, required this.text})
      : id = '${role}_${DateTime.now().microsecondsSinceEpoch}';

  // Construtor para restauração do histórico JSON (pode não ter id)
  _ChatMsg.withId({required this.id, required this.role, required this.text});
}

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

    return _ChatSession(
      id: id,
      savedAt: savedAt,
      summary: j['summary']?.toString() ?? '',
      messages: (j['messages'] as List? ?? []).map((m) {
        final map = m is Map ? Map<String, dynamic>.from(m) : <String, dynamic>{};
        return _ChatMsg.withId(
          id: map['id']?.toString() ?? '${map['role']}_${DateTime.now().microsecondsSinceEpoch}',
          role: map['role']?.toString() ?? 'user',
          text: map['text']?.toString() ?? '',
        );
      }).toList(),
    );
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

  /// true quando o teclado virtual está aberto no chat — usado pelo FAB central
  /// em main.dart para sumir suavemente durante a digitação (Fix #5 PR #65).
  static final chatKeyboardOpen = ValueNotifier<bool>(false);

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
  final List<_ChatMsg> _messages = [];
  bool _thinking      = false;
  bool _hasFocus      = false;
  bool _aiError       = false;
  // Task 11 — network error banner: true quando a última chamada da IA falhou
  // por problema de conexão (timeout, socket, etc.) vs. erro de chave API.
  bool _networkError  = false;
  bool _greetingDone  = false; // garante saudação só uma vez por sessão
  int  _lastAiIndex  = -1;   // índice da última resposta da IA (para animar só ela)
  // Auto-scroll: só desce automaticamente se usuário estiver perto do fundo
  bool _userScrolledUp = false; // true quando usuário scrollou para cima
  // Anti-jump: token gerado a cada nova resposta da IA — bloqueia callbacks
  // de reveals de bolhas antigas que ficaram pendentes.
  int _scrollGeneration = 0;
  // Throttle de scroll suave (Build 96): substitui flag bool por timestamp.
  // Garante que animateTo só dispara a cada ≥80ms — alinha com ~60fps sem
  // sobrecarregar a engine de layout durante o streaming de chunks.
  bool _scrollPending = false;
  int _lastScrollMs = 0; // epoch ms da última chamada de scroll animado
  // Sentinela no fim da lista — Scrollable.ensureVisible garante layout calculado
  final _bottomKey = GlobalKey();
  // Histórico de sessões de chat (até 10)
  final List<_ChatSession> _chatHistory = [];
  static const _kHistKey = 'medcases_ia_chat_history_v1';

  /// ID da sessão restaurada do histórico (se a sessão atual veio do histórico
  /// sem nenhuma mensagem nova do usuário, não deve ser re-salva ao limpar).
  String? _restoredSessionId;

  /// Indica se o usuário enviou ao menos 1 mensagem nova após restaurar uma sessão.
  bool _hasNewMessageAfterRestore = false;

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
    // aiConnected: gemini ou chave OpenAI configurada
    final p = context.read<AppProvider>();
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

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) {
        setState(() => _hasFocus = _focusNode.hasFocus);
        // Fix #5: propaga foco ao FAB central (main.dart oculta o botão)
        AiScreen.chatKeyboardOpen.value = _focusNode.hasFocus;
      }
    });
    _queryCtrl.addListener(() {
      if (mounted && _queryCtrl.text.isNotEmpty && _hasFocus) {
        setState(() {});
      }
    });
    // Listener de scroll: detecta se usuário scrollou para cima
    _scrollCtrl.addListener(_onScroll);
    // Home V2: escuta pendingQuery em tempo real — dispara sempre que a Home
    // injeta uma nova query, mesmo que o AiScreen já esteja montado no IndexedStack.
    AiScreen.pendingQuery.addListener(_onPendingQuery);
    // Home V2: escuta pendingHistory — restaura o mini-chat da Home no AiScreen.
    // Disparado quando o usuário clica "Ver respuesta completa" / "Ver mais".
    AiScreen.pendingHistory.addListener(_onPendingHistory);
    // Injeta saudação após o primeiro frame (AppProvider já disponível)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _injectGreeting();
      // Consome query que possa ter sido setada antes do listener estar ativo
      _consumePendingQuery();
      // Consome histórico pendente (caso injetado antes do listener ativo)
      _onPendingHistory();
    });
    // Carrega histórico de chats do SharedPrefs
    _loadChatHistory();
    // Inicializa TTS
    _initTts();
    // Registra callbacks no shell AppBar via notifiers estáticos.
    // O shell lê estes valores para exibir botões contextuais na aba da IA.
    AiScreen.clearChatCallback.value   = _clearChat;
    AiScreen.openHistoryCallback.value = () {
      if (!mounted) return;
      _openHistory(context.read<AppProvider>());
    };
    AiScreen.openSettingsCallback.value = () {
      if (!mounted) return;
      _openAiSettings();
    };

    // Verifica sessão Gemini ao montar — captura token de redirect OAuth
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final p = context.read<AppProvider>();
        if (!p.geminiConnected) {
          p.checkGeminiSession();
        }
      });
    }
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
      setState(() {
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

  void _consumePendingQuery() {
    final q = AiScreen.pendingQuery.value;
    if (q.isEmpty || !mounted) return;
    AiScreen.pendingQuery.value = '';  // limpa imediatamente para não re-disparar
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      final p = context.read<AppProvider>();
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

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    // Considera "perto do fundo" se estiver a menos de 120px do máximo
    final nearBottom = pos.pixels >= pos.maxScrollExtent - 120;
    // ⚡ Sem setState aqui — usa variável simples para evitar rebuild no scroll
    final wasUp = _userScrolledUp;
    _userScrolledUp = !nearBottom;
    // Só reconstrói se o estado mudou (botão scroll-to-bottom aparece/desaparece)
    if (wasUp != _userScrolledUp && mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    AiScreen.pendingQuery.removeListener(_onPendingQuery);
    AiScreen.pendingHistory.removeListener(_onPendingHistory);
    _queryCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    _tts.stop();
    // Limpa callbacks do shell AppBar — widget desmontado
    AiScreen.clearChatCallback.value   = null;
    AiScreen.openHistoryCallback.value = null;
    AiScreen.openSettingsCallback.value = null;
    AiScreen.hasMessagesNotifier.value  = false;
    AiScreen.historyCountNotifier.value = 0;
    AiScreen.aiConnectedNotifier.value  = false;
    AiScreen.chatKeyboardOpen.value     = false; // Fix #5: limpa ao desmontar
    super.dispose();
  }

  /// Desce apenas se usuário não scrollou para cima intencionalmente.
  /// [force] = true força scroll independente (usado ao enviar mensagem do usuário).
  // ── Histórico de chats ───────────────────────────────────────────────────────────────────────
  String _histKey(AppProvider p) {
    final uid = p.currentUser?.uid ?? 'anon';
    return '${uid}_$_kHistKey';
  }

  Future<void> _loadChatHistory() async {
    try {
      final p = context.read<AppProvider>();
      final uid = p.currentUser?.uid;

      // 1º tenta Firestore (cross-device)
      if (uid != null && uid.isNotEmpty) {
        final remote = await FirestoreService.loadAiSessions(uid);
        if (remote.isNotEmpty) {
          final sessions = remote
              .map((e) => _ChatSession.fromJson(e))
              .toList();
          if (mounted) setState(() {
            _chatHistory.clear();
            _chatHistory.addAll(sessions);
          });
          // Atualiza cache local
          _persistHistoryLocal(p);
          return;
        }
      }

      // Fallback: SharedPreferences (offline)
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_histKey(p));
      if (json == null || json.isEmpty) return;
      final list = jsonDecode(json) as List;
      final sessions = list
          .map((e) => _ChatSession.fromJson(e as Map<String, dynamic>))
          .toList();
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
  Future<void> _saveCurrentSessionToHistory(AppProvider p) async {
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

    // Se é uma sessão restaurada com novas mensagens, atualiza a entrada
    // existente em vez de criar uma duplicata
    final existingIdx = _restoredSessionId != null
        ? _chatHistory.indexWhere((s) => s.id == _restoredSessionId)
        : -1;

    final session = _ChatSession(
      // Mantém o ID original se for atualização, senso gera novo
      id: existingIdx >= 0 ? _restoredSessionId! : now.toIso8601String(),
      savedAt: now,
      summary: summary.length > 100 ? summary.substring(0, 100) : summary,
      messages: msgsToSave,
    );

    setState(() {
      // Remove entrada antiga (se existia) antes de reinserir no topo
      if (existingIdx >= 0) {
        _chatHistory.removeAt(existingIdx);
      }
      _chatHistory.insert(0, session);
      // Mantém apenas as 10 sessões mais recentes
      if (_chatHistory.length > 10) {
        _chatHistory.removeRange(10, _chatHistory.length);
      }
    });

    // Persiste em dual-write: Firestore (primário) + SharedPreferences (offline)
    final uid = p.currentUser?.uid;
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
  void _openHistory(AppProvider p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChatHistorySheet(
        sessions: _chatHistory,
        dark: p.darkMode,
        lang: p.lang,
        onRestore: (session) {
          Navigator.pop(context);
          _restoreSession(session, p);
        },
        onDelete: (sessionId) async {
          setState(() => _chatHistory.removeWhere((s) => s.id == sessionId));
          // Remove do Firestore
          final uid = p.currentUser?.uid;
          if (uid != null && uid.isNotEmpty) {
            FirestoreService.deleteAiSession(uid, sessionId).catchError((_) {});
          }
          // Atualiza cache local
          _persistHistoryLocal(p);
        },
      ),
    );
  }

  /// Restaura uma sessão do histórico para o chat atual.
  void _restoreSession(_ChatSession session, AppProvider p) {
    setState(() {
      _messages.clear();
      _messages.addAll(session.messages);
      _lastAiIndex = -1;
      _greetingDone = true;
      _userScrolledUp = false;
      // Marca a sessão como restaurada para não re-salvar sem alteração
      _restoredSessionId = session.id;
      _hasNewMessageAfterRestore = false;
    });
    p.clearAiHistory();
    // Recria o contexto de IA a partir das mensagens restauradas
    for (final msg in session.messages) {
      if (msg.role != 'ai') continue; // contexto é construído internamente no provider
    }
    _scrollDown(force: true);
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

      // Scroll suave: 150ms + easeOutQuad — sem jumpTo, sem Scrollable.ensureVisible.
      // animateTo aguarda o layout estar calculado (addPostFrameCallback já garante isso)
      // e produz transição fluida tipo WhatsApp/Telegram.
      _scrollCtrl.animateTo(
        target,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutQuad,
      );
    });
  }

  // Guard local de envio: complementa o guard no provider.
  // Evita que ENTER + click simultâneo no botão dispare 2 envios.
  bool _sendGuard = false;

  // Streaming V2: true enquanto chunks chegam (controla cursor ▌ na bolha ativa)
  bool _isStreaming = false;

  Future<void> _send(String text, AppProvider p) async {
    final trimmed = text.trim();
    // Bloqueia: texto vazio, IA pensando/streaming, ou guard ativo (duplo envio)
    if (trimmed.isEmpty || _thinking || _isStreaming || _sendGuard) return;

    _sendGuard = true;
    _focusNode.unfocus();
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
    _queryCtrl.clear();
    _scrollDown(force: true); // força scroll ao enviar mensagem do usuário

    // ── Índice da bolha de streaming (-1 = não iniciada ainda) ──────────────
    int streamingMsgIdx = -1;

    try {
      // ── Streaming V2 via sendAiMessage ────────────────────────────────────
      // Retorna true se usou streaming (Gemini conectado), false se usou fallback.
      await p.sendAiMessage(
        trimmed,
        onChunk: (accumulated) {
          if (!mounted) return;
          // ── STREAM SANITIZER: expurga metadados antes de exibir ────────────
          // Remove "Confianza Clínica:", "El usuario solicita..." e variantes
          // que o modelo às vezes emite como primeiras linhas do stream.
          final cleanedChunk = _stripMetadataHeaders(accumulated);
          setState(() {
            if (streamingMsgIdx == -1) {
              // Primeiro chunk: substitui ThinkingBubble por bolha em streaming
              _thinking = false;
              _isStreaming = true;
              _scrollGeneration++;
              _lastAiIndex = _messages.length;
              _messages.add(_ChatMsg(role: 'ai', text: cleanedChunk));
              streamingMsgIdx = _messages.length - 1;
            } else {
              // Chunks subsequentes: atualiza texto da bolha existente in-place
              _isStreaming = true;
              _messages[streamingMsgIdx] = _ChatMsg.withId(
                id: _messages[streamingMsgIdx].id,
                role: 'ai',
                text: cleanedChunk,
              );
            }
          });
          _scrollDown();
        },
        onDone: (finalText) {
          if (!mounted) return;
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
            // ── PASSO 1: comita texto final mantendo _isStreaming=true ──────
            // O _AiBubble recebe o texto completo mas ainda não remove o cursor,
            // permitindo que o Flutter calcule o layout dos blocos finais primeiro.
            setState(() {
              _thinking     = false;
              _aiError      = isKeyError;
              _networkError = false;
              if (streamingMsgIdx >= 0) {
                // Caminho normal: atualiza bolha com texto definitivo
                _messages[streamingMsgIdx] = _ChatMsg.withId(
                  id: _messages[streamingMsgIdx].id,
                  role: 'ai',
                  text: finalText,
                );
              } else {
                // Fallback legado (sem streaming)
                _scrollGeneration++;
                _lastAiIndex = _messages.length;
                _messages.add(_ChatMsg(role: 'ai', text: finalText));
              }
            });

            // Scroll intermediário: avança para onde estamos agora
            _scrollDown();

            // ── PASSO 2: remove cursor no próximo frame ──────────────────
            // Após o Flutter calcular o layout dos blocos finais (com cursor),
            // remove o cursor setando _isStreaming=false. Neste ponto o
            // _computeBlocks() vai recomputar sem cursor — mas o maxScrollExtent
            // já está estável porque os blocos-base já foram medidos.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                _isStreaming = false;
              });

              // ── PASSO 3: scroll final após remoção do cursor (3 frames) ──
              // Frame 1: aguarda o rebuild do _AiBubble sem cursor (sem ▌)
              // Frame 2: aguarda o segundo layout pass (altura dos blocos finais)
              // Frame 3: maxScrollExtent totalmente estabilizado → scroll seguro
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || _userScrolledUp) return;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted || _userScrolledUp) return;
                  if (!_scrollCtrl.hasClients) return;
                  final pos = _scrollCtrl.position;
                  if (pos.pixels >= pos.maxScrollExtent - 4) return;
                  // animateTo (suave 200ms) em vez de jumpTo — evita "teleporte"
                  // caso o layout ainda esteja se estabilizando no último frame.
                  _scrollCtrl.animateTo(
                    pos.maxScrollExtent,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                  );
                });
              });
            });
          }
        },
        onError: (errorMsg) {
          if (!mounted) return;
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
      if (!mounted) return;
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

  /// Detecta si el texto de la IA menciona un fármaco y retorna su evidencia global.
  /// Busca las primeras 3 palabras de cada línea como posible nombre de fármaco.
  DrugEvidenceModel? _detectDrugEvidence(String text) {
    // Palabras clave que indican contenido farmacológico
    final pharmKeywords = RegExp(
      r'\b(dosis|dose|administr|mg\/kg|mcg\/kg|infus[ií]on|bolo|IV|IM|SC|ampollas?|comprimido|'
      r'antibi[oó]tico|analgésico|sedaci[oó]n|anticoagulante|vasopressor|broncodilatador)\b',
      caseSensitive: false,
    );
    if (!pharmKeywords.hasMatch(text)) return null;

    // Lista de fármacos de alta prioridad para detección
    const drugKeywords = [
      'adenosina', 'amiodarona', 'noradrenalina', 'adrenalina', 'epinefrina',
      'atropina', 'morfina', 'fentanil', 'fentanilo', 'ketamina',
      'midazolam', 'propofol', 'dexmedetomidina', 'haloperidol',
      'metoprolol', 'furosemida', 'dobutamina', 'dopamina', 'vasopresina',
      'nitroglicerina', 'heparina', 'enoxaparina', 'rivaroxabana', 'varfarina',
      'clopidogrel', 'salbutamol', 'dexametasona', 'insulina', 'metformina',
      'omeprazol', 'ondansetrona', 'enalapril', 'losartana', 'paracetamol',
      'ibuprofeno', 'tramadol', 'naloxona', 'succinilcolina', 'ceftriaxona',
      'vancomicina', 'meropenem', 'piperacilina', 'fluconazol', 'aciclovir',
      'sulfato de magnesio', 'ácido tranexámico', 'levetiracetam', 'fenitoína',
      'clonazepam',
    ];

    final textLower = text.toLowerCase();
    for (final keyword in drugKeywords) {
      if (textLower.contains(keyword)) {
        final ev = getGlobalEvidence(keyword);
        if (ev != null) return ev;
      }
    }
    return null;
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

  void _clearChat() {
    final p = context.read<AppProvider>();
    // Salva sessão atual no histórico antes de limpar
    // (não-op se foi sessão restaurada sem novas mensagens)
    _saveCurrentSessionToHistory(p);
    setState(() {
      _messages
        ..clear()
        ..add(_ChatMsg(role: 'ai', text: _buildGreeting(p.userName, p.lang)));
      _aiError      = false;
      _networkError = false;
      _userScrolledUp = false;
      // Reseta flags de sessão restaurada para o novo chat em branco
      _restoredSessionId = null;
      _hasNewMessageAfterRestore = false;
    });
    _queryCtrl.clear();
    _focusNode.unfocus();
    p.clearAiHistory();
  }

  // ── Nuevo Chat — salva sessão atual e abre nova sessão limpa ─────────────
  // Diferente de _clearChat: NÃO deleta histórico. Salva em background e
  // cria nova sessão com ID diferente (timestamp) para consulta fresca.
  void _startNewChat() {
    final p = context.read<AppProvider>();
    // 1. Persiste sessão atual em background (dual-write Firestore + prefs)
    _saveCurrentSessionToHistory(p);
    // 2. Limpa UI e reseta flags de sessão — novo chat em branco
    setState(() {
      _messages
        ..clear()
        ..add(_ChatMsg(role: 'ai', text: _buildGreeting(p.userName, p.lang)));
      _aiError      = false;
      _networkError = false;
      _userScrolledUp = false;
      // Força novo ID de sessão — próxima mensagem cria entrada separada
      _restoredSessionId = null;
      _hasNewMessageAfterRestore = false;
      _greetingDone = true;
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
    // Fundo estilo WhatsApp — levíssimo padrão
    final chatBg = dark ? const Color(0xFF1A1D23) : const Color(0xFFECE5DD);

    // Fix #5: detecta teclado via viewInsets (cobre Web Mobile onde focus events
    // podem não ser confiáveis). Propaga ao ValueNotifier para o FAB em main.dart.
    final kbOpen = MediaQuery.of(context).viewInsets.bottom > 50;
    if (AiScreen.chatKeyboardOpen.value != kbOpen) {
      // Schedula fora do build para evitar setState-during-build
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => AiScreen.chatKeyboardOpen.value = kbOpen);
    }

    // No desktop: centraliza o chat com largura máxima elegante
    final double? chatMaxWidth = bp.isDesktop ? 960 : null;
    final hPad = bp.isDesktop ? 0.0 : 12.0;

    // Estado de conexão da IA — controla exibição do card "IA Desconectada"
    final bool isConnected = p.hasAnyAi || p.geminiConnected;
    // Mostra card de desconexão quando IA não está conectada E usuário
    // ainda não enviou nenhuma mensagem (só greeting automática existe)
    final bool showDisconnectCard = !isConnected &&
        _messages.where((m) => m.role == 'user').isEmpty;

    Widget chatList = ListView.builder(
            controller: _scrollCtrl,
            padding: EdgeInsets.fromLTRB(
              bp.isDesktop ? 24 : 12,
              12,
              bp.isDesktop ? 24 : 12,
              8,
            ),
            cacheExtent: 2000,
            physics: const ClampingScrollPhysics(),
            // Fecha o teclado ao arrastar o chat (comportamento nativo mobile)
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            itemCount: _messages.length + (_thinking ? 1 : 0) + 1, // +1 sentinela
            itemBuilder: (context, i) {
              // Sentinela invisível — âncora para Scrollable.ensureVisible
              if (i == _messages.length + (_thinking ? 1 : 0)) {
                return SizedBox(key: _bottomKey, height: 1);
              }
              if (_thinking && i == _messages.length) {
                return _ThinkingBubble(dark: dark);
              }
              final msg = _messages[i];
              if (msg.role == 'user') {
                return KeyedSubtree(
                  key: ValueKey('msg_${msg.id}'),
                  child: _UserBubble(text: msg.text, dark: dark),
                );
              }
              // ── AI message — detectar fármaco en texto ──────────────────
              final detectedEv = _detectDrugEvidence(msg.text);
              return KeyedSubtree(
                key: ValueKey('msg_${msg.id}'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AiBubble(
                      key: ValueKey('ai_${msg.id}'),
                      text: msg.text,
                      dark: dark,
                      animate: i == _lastAiIndex,
                      lang: p.lang,
                      onCopy: () => _copyMsg(msg.text),
                      ttsPlaying: _ttsPlayingIndex == i,
                      ttsReady: _ttsReady,
                      onTts: _ttsReady
                          ? () => _toggleTts(i, msg.text, p.lang)
                          : null,
                      scrollGeneration: _scrollGeneration,
                      onBlockRevealed: _onBlockRevealed,
                      // Mostra cursor ▌ apenas na bolha que está sendo preenchida
                      isStreaming: _isStreaming && i == _lastAiIndex,
                    ),
                    // Tarjeta de evidencia si el mensaje menciona un fármaco
                    if (detectedEv != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                        child: _CollapsibleEvidenceBlock(ev: detectedEv, dark: dark),
                      ),
                  ],
                ),
              );
            },
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
            chatList,
            // Card "IA Desconectada" — sobreposto quando IA não está conectada
            // e o médico ainda não enviou nenhuma mensagem
            if (showDisconnectCard)
              _EmptyChat(
                dark: dark,
                lang: p.lang,
                isConnected: false,
                onConnectApi: _openAiSettings,
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
        ),

      // ── Banner de erro de chave ───────────────────────────────────────────
      if (_aiError)
        _AiErrorBanner(
          dark: dark,
          lang: p.lang,
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

      // ── Carrossel de sugestões — some quando foca ─────────────────────
      AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        child: _showSuggestions
            ? _SuggestionCarousel(
                lang: p.lang,
                dark: dark,
                onTap: _insertSuggestion,
              )
            : const SizedBox.shrink(),
      ),

      // ── Barra de input — centralizada no desktop ───────────────────────
      chatMaxWidth != null
          ? Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: chatMaxWidth),
                child: _InputBar(
                  ctrl: _queryCtrl,
                  focusNode: _focusNode,
                  dark: dark,
                  hasFocus: _hasFocus,
                  thinking: _thinking,
                  onSend: () => _send(_queryCtrl.text, context.read<AppProvider>()),
                  hint: p.t('ai_placeholder'),
                  onVoice: _toggleStt,
                  sttListening: _sttListening,
                  sttSoundLevel: _sttSoundLevel,
                  lang: p.lang,
                ),
              ),
            )
          : _InputBar(
              ctrl: _queryCtrl,
              focusNode: _focusNode,
              dark: dark,
              hasFocus: _hasFocus,
              thinking: _thinking,
              onSend: () => _send(_queryCtrl.text, context.read<AppProvider>()),
              hint: p.t('ai_placeholder'),
              onVoice: _toggleStt,
              sttListening: _sttListening,
              sttSoundLevel: _sttSoundLevel,
              lang: p.lang,
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
  final VoidCallback onHistory;
  final VoidCallback onClear;
  final VoidCallback onSettings;
  final VoidCallback? onNewChat;

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
    this.onNewChat,
  });

  // MedCases IA — palette
  static const _kGold  = Color(0xFFC5A365); // dourado (badge histórico)
  static const _kGreen = Color(0xFF00E5FF);
  static const _kBg1   = Color(0xFF1A1D23);
  static const _kBg2   = Color(0xFF252930);

  @override
  Widget build(BuildContext context) {
    final bgColor = dark ? _kBg2 : const Color(0xFFF5F5F5);
    final borderColor = dark ? const Color(0xFF374151) : const Color(0xFFE0E0E0);
    // MedCases IA palette — icon teal
    final iconColor = dark ? const Color(0xFF00E5FF) : const Color(0xFF008CA4);
    final iconBg = dark
        ? const Color(0xFF00E5FF).withValues(alpha: 0.07)
        : const Color(0xFF008CA4).withValues(alpha: 0.08);
    final iconBorder = dark
        ? const Color(0xFF00E5FF).withValues(alpha: 0.15)
        : const Color(0xFF008CA4).withValues(alpha: 0.22);

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: dark ? _kBg1 : const Color(0xFFF8F8F8),
        border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
        gradient: dark
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_kBg1, _kBg2],
              )
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            // ── Logo MedCases IA (mini) ──────────────────────────────────────
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF252930), Color(0xFF374151)],
                  ),
                  border: Border.all(
                    color: Color(0xFF00E5FF).withValues(alpha: 0.25),
                    width: 0.8,
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.psychology_alt_rounded, size: 13,
                    color: Color(0xFF00E5FF)),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                'MedCases IA',
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w800,
                  color: dark ? const Color(0xFF00E5FF) : const Color(0xFF252930),
                  letterSpacing: -0.2,
                ),
              ),
            ]),

            // ── Badge conexão ────────────────────────────────────────────────
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onSettings,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: hasRealAi
                      ? const Color(0xFF00E5FF).withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.07),
                  border: Border.all(
                    color: hasRealAi
                        ? const Color(0xFF00E5FF).withValues(alpha: 0.45)
                        : Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: keyLoading
                    ? SizedBox(
                        width: 10, height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: dark ? Colors.white54 : Colors.black38,
                        ),
                      )
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 6, height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: hasRealAi ? const Color(0xFF00E5FF) : Colors.white38,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          hasRealAi
                              ? (lang == 'es' ? 'Conectado' : 'Conectado')
                              : (lang == 'es' ? 'Conectar IA' : 'Conectar IA'),
                          style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: hasRealAi
                                ? const Color(0xFF00E5FF)
                                : (dark ? Colors.white54 : Colors.black45),
                          ),
                        ),
                      ]),
              ),
            ),

            const Spacer(),

            // ── Botão Histórico ──────────────────────────────────────────────
            GestureDetector(
              onTap: onHistory,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 34, height: 34,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: iconBg,
                      border: Border.all(color: iconBorder, width: 1),
                    ),
                    child: Icon(Icons.history_rounded, size: 18, color: iconColor),
                  ),
                  if (historyCount > 0)
                    Positioned(
                      top: -3, right: 5,
                      child: Container(
                        width: 14, height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFC5A365),
                        ),
                        child: Center(
                          child: Text(
                            '$historyCount',
                            style: const TextStyle(
                              fontSize: 8, fontWeight: FontWeight.w900,
                              color: Color(0xFF1A1100),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Botão Nuevo Chat ────────────────────────────────────────────────
            GestureDetector(
              onTap: onNewChat,
              child: Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: dark
                      ? const Color(0xFF00E5FF).withValues(alpha: 0.10)
                      : const Color(0xFF008CA4).withValues(alpha: 0.08),
                  border: Border.all(
                    color: dark
                        ? const Color(0xFF00E5FF).withValues(alpha: 0.30)
                        : const Color(0xFF008CA4).withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    Icons.add_rounded,
                    size: 14,
                    color: dark ? const Color(0xFF00E5FF) : const Color(0xFF008CA4),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    lang == 'es' ? 'Nuevo Chat' : 'Novo Chat',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: dark ? const Color(0xFF00E5FF) : const Color(0xFF008CA4),
                    ),
                  ),
                ]),
              ),
            ),
          ],
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
  });

  // ── Paleta MedCases IA ────────────────────────────────────────────────
  static const _kBg1   = Color(0xFF252930); // navy escuro
  static const _kBg2   = Color(0xFF252930); // navy médio
  static const _kBg3   = Color(0xFF374151); // navy claro
  static const _kGold  = Color(0xFFC5A365); // dourado (badges)
  static const _kGoldL = Color(0xFFFFE8A6); // dourado claro
  static const _kGreen = Color(0xFF00E5FF); // cyan MedCases IA (status)

  @override
  Widget build(BuildContext context) {
    final isConnected = geminiConnected || hasRealAi;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_kBg1, _kBg2, _kBg3],
        ),
        // Linha cyan MedCases IA na base do header
        border: Border(
          bottom: BorderSide(color: Color(0xFF005E9C), width: 1),
        ),
      ),
      child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Linha 1: avatar + título + ações principais ──────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar — só texto 'M+' dourado, sem fundo nem borda
                  SizedBox(
                    width: 38, height: 38,
                    child: Center(
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'M',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: _kGold,
                                letterSpacing: -1,
                              ),
                            ),
                            TextSpan(
                              text: '+',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: _kGoldL,
                                letterSpacing: 0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Título + badge conexão como subtítulo (Column)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'MedCases IA',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF00E5FF),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Badge Conectado / Conectar IA — subtítulo clicável
                        GestureDetector(
                          onTap: onSettings,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: isConnected
                                  ? const Color(0xFF00E5FF).withValues(alpha: 0.12)
                                  : Colors.white.withValues(alpha: 0.07),
                              border: Border.all(
                                color: isConnected
                                    ? const Color(0xFF00E5FF).withValues(alpha: 0.45)
                                    : Colors.white.withValues(alpha: 0.18),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (keyLoading)
                                  SizedBox(
                                    width: 8, height: 8,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.2,
                                      color: Colors.white.withValues(alpha: 0.5),
                                    ),
                                  )
                                else
                                  Icon(
                                    isConnected
                                        ? Icons.check_circle_rounded
                                        : Icons.link_rounded,
                                    size: 10,
                                    color: isConnected
                                        ? const Color(0xFF00E5FF)
                                        : Colors.white.withValues(alpha: 0.5),
                                  ),
                                const SizedBox(width: 4),
                                Text(
                                  keyLoading
                                      ? 'Conectando...'
                                      : isConnected
                                          ? (lang == 'es' ? 'Conectado' : 'Conectado')
                                          : (lang == 'es' ? 'Conectar IA' : 'Conectar IA'),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isConnected
                                        ? const Color(0xFF00E5FF)
                                        : Colors.white.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Ações direita ────────────────────────────────────
                  // Botão histórico
                  GestureDetector(
                    onTap: onHistory,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.white.withValues(alpha: 0.07),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.10)),
                          ),
                          child: Icon(Icons.history_rounded, size: 18,
                            color: Colors.white.withValues(alpha: 0.75)),
                        ),
                        if (historyCount > 0)
                          Positioned(
                            top: -4, right: -4,
                            child: Container(
                              width: 15, height: 15,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: _kGold,
                              ),
                              child: Center(
                                child: Text(
                                  '$historyCount',
                                  style: const TextStyle(
                                    fontSize: 8,
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
                  const SizedBox(width: 6),

                  // ── Botão Nuevo Chat ──────────────────────────────────────
                  GestureDetector(
                    onTap: onNewChat,
                    child: Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                        border: Border.all(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(
                          Icons.add_rounded,
                          size: 14,
                          color: Color(0xFF00E5FF),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          lang == 'es' ? 'Nuevo Chat' : 'Novo Chat',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF00E5FF),
                          ),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Botão menu
                  GestureDetector(
                    onTap: () => Scaffold.of(context).openEndDrawer(),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.white.withValues(alpha: 0.07),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.10)),
                      ),
                      child: Icon(Icons.menu_rounded, size: 18,
                        color: Colors.white.withValues(alpha: 0.75)),
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
// Card de desconexão — "IA Desconectada"
// Exibido como overlay centralizado quando a IA não está conectada.
// Some automaticamente ao conectar (isConnected = true).
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyChat extends StatelessWidget {
  final bool dark;
  final String lang;
  final bool isConnected;
  final VoidCallback? onConnectApi;
  const _EmptyChat({
    required this.dark,
    required this.lang,
    this.isConnected = false,
    this.onConnectApi,
  });

  @override
  Widget build(BuildContext context) {
    // Se a IA já está conectada, o card não é renderizado
    if (isConnected) return const SizedBox.shrink();

    final isEs = lang == 'es';

    // ── Paleta do card (combina com o _WaHeader escuro) ───────────────────
    // Fundo escuro #1E1E1E independente do darkMode — combina com o header preto
    const cardBg     = Color(0xFF252930);
    const amberColor = Color(0xFFF59E0B);
    const amberBg    = Color(0x1FF59E0B);   // âmbar 12% opacidade
    const amberBorder = Color(0x52F59E0B);  // âmbar 32% opacidade

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: amberBorder, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: amberColor.withValues(alpha: 0.06),
                blurRadius: 40,
                offset: const Offset(0, 0),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Ícone de link quebrado em âmbar ───────────────────────
              Container(
                width: 76, height: 76,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: amberBg,
                  border: Border.fromBorderSide(
                    BorderSide(color: amberBorder, width: 1.5),
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.link_off_rounded,
                    size: 36,
                    color: amberColor,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Título ────────────────────────────────────────────────
              Text(
                isEs ? 'IA Desconectada' : 'IA Desconectada',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 12),

              // ── Subtítulo ─────────────────────────────────────────────
              Text(
                isEs
                    ? "Por favor, haga clic en el botón 'Conectar IA' en el menú superior negro para activar las guías clínicas y garantizar el funcionamiento 100% de los diagnósticos."
                    : "Por favor, clique no botão 'Conectar IA' localizado no menu superior preto para ativar as diretrizes clínicas e garantir o funcionamento 100% dos diagnósticos.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withValues(alpha: 0.60),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 24),

              // ── Seta apontando para o botão "Conectar IA" no header ──
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.arrow_upward_rounded,
                      color: amberColor, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    isEs ? 'Botón en el menú superior' : 'Botão no menu acima',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: amberColor.withValues(alpha: 0.80),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Botão alternativo direto ──────────────────────────────
              GestureDetector(
                onTap: onConnectApi,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: amberColor,
                    boxShadow: [
                      BoxShadow(
                        color: amberColor.withValues(alpha: 0.30),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bolt_rounded,
                          color: Color(0xFF1A1100), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        isEs ? 'Conectar IA Ahora' : 'Conectar IA Agora',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1100),
                          letterSpacing: 0.2,
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
// Carrossel horizontal de sugestões
// ─────────────────────────────────────────────────────────────────────────────
class _SuggestionCarousel extends StatelessWidget {
  final String lang;
  final bool dark;
  final void Function(String) onTap;
  const _SuggestionCarousel({
    required this.lang,
    required this.dark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isEs   = lang == 'es';
    final bg     = dark ? const Color(0xFF1A1D23) : Colors.white;
    final border = dark ? const Color(0xFF2D3340) : const Color(0xFFE5E0D8);
    final chipBg = dark ? const Color(0xFF252930) : const Color(0xFFF5F3EE);
    final chipBorder = dark ? const Color(0xFF374151) : const Color(0xFFDAD5CC);
    final textCol = dark ? Colors.white70 : const Color(0xFF2D3340);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: border)),
      ),
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
      child: SizedBox(
        height: 34,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: _suggestions.length,
          itemBuilder: (context, i) {
            final s = _suggestions[i];
            final label = isEs ? s.labelEs : s.labelPt;
            final prompt = isEs ? s.promptEs : s.promptPt;
            return GestureDetector(
              onTap: () => onTap(prompt),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: chipBorder),
                ),
                child: Text(label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textCol,
                  )),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bolha do usuário — direita, verde escuro
// ─────────────────────────────────────────────────────────────────────────────
class _UserBubble extends StatelessWidget {
  final String text;
  final bool dark;
  const _UserBubble({super.key, required this.text, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 52),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
            // Verde WhatsApp característico
            color: Color(0xFF008CA4),
          ),
          child: Text(text,
            style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w400,
              color: Colors.white, height: 1.45)),
        ),
      ),
    );
  }
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

  // ── CAMADA 1a v6.0 — catch-all bilíngue (Build 96) ─────────────────────
  //
  // REGRA PRINCIPAL: qualquer linha que CONTENHA "Confian" + "Clínica/Clinica"
  // (independente de posição, prefixos pipe/espaço, idioma ou pontuação).
  // Exemplos reais capturados em produção (junho 2026):
  //   "Confianza Clínica: Alta — El usuario solicita..."
  //   "| Confiança Clínica: Alta — O usuário solicita..."
  //   "Confiança Clínica Alta"          ← sem dois-pontos
  //   "**Confianza Clínica**: Alta"     ← com markdown
  //   "Nivel de Confianza Clínica: ..."
  //
  // Regex 1: linha inteira com Confian[za|ça] ... Clínica em qualquer posição
  String result = accumulated.replaceAll(
    RegExp(
      r'^.*Confian[zç]a\s*(?:Cl[íi]nica)?.*$',
      caseSensitive: false,
      multiLine: true,
    ),
    '',
  );

  // Regex 2: padrões complementares de abertura de linha (3ª pessoa / metadados)
  result = result.replaceAll(
    RegExp(
      r'^[|\s]*(?:'
      r'Cl[íi]nica\s*[:–—]'
      r'|Clinical\s+Confidence\s*:'
      r'|Nivel\s+de\s+Confianza\s*:'
      r'|N[íi]vel\s+de\s+Confian[çc]a\s*:'
      r'|El\s+usuario\s+(?:solicita|proporciona|pregunta|pide|quiere|busca|ha\s+(?:pedido|indicado)|solicit[oó])'
      r'|O\s+usu[aá]rio\s+(?:solicita|fornece|pergunta|pede|quer|busca|indicou|solicitou|informou|forneceu|est[aá]\s+perguntando)'
      r'|The\s+user\s+(?:is\s+asking|asks|wants|requests|provides|has\s+indicated|has\s+asked)'
      r'|El\s+m[eé]dico\s+(?:solicita|pregunta|pide|quiere|ha\s+(?:pedido|indicado))'
      r'|O\s+m[eé]dico\s+(?:solicita|pergunta|pede|quer|solicitou)'
      r'|Para\s+proporcionar\s+una\s+respuesta'
      r'|Para\s+fornecer\s+uma\s+resposta'
      r'|La\s+base\s+de\s+datos\s+(?:local\s+)?(?:no\s+)?(?:contiene|tiene|posee)'
      r'|A\s+base\s+de\s+dados\s+(?:local\s+)?n[aã]o\s+(?:possui|cont[eé]m|tem)'
      r'|Por\s+lo\s+tanto,\s+(?:la\s+mejor|el\s+mejor)'
      r'|Portanto,\s+a\s+melhor\s+abordagem'
      r'|(?:El|La)\s+prompt\s+(?:es|parece)\s+(?:vago|incompleto|ambiguo)'
      r'|O\s+prompt\s+(?:é|parece)\s+(?:vago|incompleto|ambiguo)'
      r'|A\s+continuaci[oó]n\s+(?:presento|presentar[eé]|describir[eé])'
      r'|A\s+seguir\s+(?:apresentarei|descrevo|apresento)'
      r'|Baseado\s+(?:no|na|em)\s+(?:contexto|conversa|solicita|que\s+(?:o|foi))'
      r'|Basado\s+en\s+(?:el\s+contexto|la\s+conversaci[oó]n|la\s+solicitud|lo\s+que)'
      r').*$',
      caseSensitive: false,
      multiLine: true,
    ),
    '',
  );

  return result.trimLeft(); // Remove linhas em branco iniciais
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

  // ── 3. Prefixos de planning/estruturação vazados ──────────────────────────
  // Padrões comuns de CoT que o modelo deixa escapar:
  final _cotPhrases = RegExp(
    r"^(My response should|I will structure|I need to|Let me think|I'll organize|"
    r"I should focus|I'm going to|Para responder|Vou estruturar|Devo focar|"
    r"Mi respuesta debe|Voy a estructurar|Estructurando|Pensando en|"
    r"Analizando el caso|Analisando o caso|Antes de responder|Before responding|"
    r"Step \d+:|Paso \d+:|Etapa \d+:|Planning:|Reasoning:|Chain of thought:).*",
    caseSensitive: false,
    multiLine: true,
  );
  s = s.replaceAll(_cotPhrases, '');

  // ── 4. Linhas de meta-comentário sobre o processo de resposta ─────────────
  s = s.replaceAll(
    RegExp(
      r'^(Agora vou|Now I will|I will now|Vou agora|Ahora voy a|'
      r'Deixe-me|Let me|Permíteme|Deixa eu pensar|'
      r'Thinking\.\.\.|Analyzing\.\.\.|Processing\.\.\.).*$',
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

  // ── 4b. EXPURGO DE METADADOS — Confianza/Confiança Clínica (CAMADA 2 v6.0, Build 96)
  //
  // REGRA CATCH-ALL: qualquer linha que CONTENHA "Confian[za|ça]" + "Clínica"
  // é deletada por completo — independente de posição, prefixo ou pontuação.
  // Inclui variantes sem dois-pontos, com markdown (**), pipe, espaços extras.
  s = s.replaceAll(
    RegExp(
      r'^.*Confian[zç]a\s*(?:Cl[íi]nica)?.*$',
      caseSensitive: false,
      multiLine: true,
    ),
    '',
  );

  // Padrões complementares de metadados internos + 3ª pessoa
  s = s.replaceAll(
    RegExp(
      r'^[|\s]*(?:'
      r'Confianza\s*[:–—]'
      r'|Confiança\s*[:–—]'
      r'|Clinical\s+Confidence\s*:'
      r'|Nivel\s+de\s+Confianza\s*:'
      r'|N[íi]vel\s+de\s+Confian[çc]a\s*:'
      r'|El\s+usuario\s+(?:solicita|proporciona|pregunta|pide|quiere|busca|ha\s+(?:indicado|pedido)|solicit[oó])'
      r'|O\s+usu[aá]rio\s+(?:solicita|fornece|pergunta|pede|quer|busca|indicou|solicitou|informou|est[aá]\s+perguntando)'
      r'|The\s+user\s+(?:is\s+asking|asks|wants|requests|provides|has\s+indicated|has\s+asked)'
      r'|El\s+usuario\s+ha\s+pedido'
      r'|El\s+m[eé]dico\s+(?:solicita|pregunta|pide|ha\s+pedido)'
      r'|O\s+m[eé]dico\s+(?:solicita|pergunta|pede|solicitou)'
      r'|Baseado\s+(?:no|na|em)\s+(?:contexto|conversa|solicita|que\s+(?:o|foi))'
      r'|Basado\s+en\s+(?:el\s+contexto|la\s+conversaci[oó]n|la\s+solicitud|lo\s+que)'
      r'|Para\s+proporcionar\s+una\s+respuesta'
      r'|Para\s+fornecer\s+uma\s+resposta'
      r'|La\s+base\s+de\s+datos\s+(?:local\s+)?no\s+(?:contiene|tiene|posee)'
      r'|A\s+base\s+de\s+dados\s+(?:local\s+)?n[aã]o\s+(?:possui|cont[eé]m|tem)'
      r'|Por\s+lo\s+tanto,\s+(?:la\s+mejor|el\s+mejor)'
      r'|Portanto,\s+a\s+melhor\s+abordagem'
      r'|(?:El|La)\s+prompt\s+(?:es|parece)\s+(?:vago|incompleto)'
      r'|O\s+prompt\s+(?:é|parece)\s+(?:vago|incompleto)'
      r'|A\s+seguir\s+(?:apresentarei|descrevo|apresento)'
      r'|A\s+continuaci[oó]n\s+(?:presento|presentar[eé])'
      r').*$',
      caseSensitive: false,
      multiLine: true,
    ),
    '',
  );

  // ── 5. Sanitização final de formatação ───────────────────────────────────
  s = s
      // ## e ### NÃO são removidos aqui — _AiBlockBubble renderiza H2/H3 com
      // hierarquia visual própria (cyan para ##, barra lateral para ###)
      .replaceAll('---', '')                                     // separadores HR
      .replaceAll('--', '')                                      // traços duplos
      .replaceAll(RegExp(r'\*{3,}'), '');                        // *** ou mais

  // ── 5b. FALLBACK ANTI-ASTERISCO — camada de segurança Flutter ────────────
  // Remove asteriscos SIMPLES soltos (usados para itálico ou listas Markdown)
  // que vazam como literal na UI. Os pares ** são mantidos intactos aqui pois
  // _buildInlineText() os converte para negrito visual corretamente.
  // Remove * isolados (não-duplos) usados como listas ou itálico Markdown:
  s = s.replaceAll(RegExp(r'(?<!\*)\*(?!\*)'), '');

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
  // Detector inline (espelha _isSectionHeader e _isH2 do _AiBlockBubble).
  // Não temos acesso ao método de instância aqui (função top-level), então
  // replicamos a mesma lógica de detecção de forma simples.
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

  final merged = <String>[];
  for (int i = 0; i < blocks.length; i++) {
    final b = blocks[i];
    if (looksLikeHeaderOnly(b) && i + 1 < blocks.length) {
      // Funde o cabeçalho orfão com o bloco seguinte, separados por \n
      merged.add('$b\n${blocks[i + 1]}');
      i++; // pula o próximo bloco — já foi incorporado
    } else {
      merged.add(b);
    }
  }
  return merged;
}

/// Renderiza uma linha de texto com suporte a negrito inline via **texto**.
/// Não exibe os asteriscos — converte para FontWeight.bold.
Widget _buildInlineText(String line, Color textColor, {bool isBold = false}) {
  // Detecta se toda a linha é um título (começa com negrito sem texto antes)
  // Padrão: **Título** ou **Título:** — ocupa a linha toda
  final fullBold = RegExp(r'^\*\*(.+?)\*\*:?\s*$');
  final fullMatch = fullBold.firstMatch(line.trim());
  if (fullMatch != null || isBold) {
    final label = fullMatch != null
        ? fullMatch.group(1)! + (line.trim().endsWith(':') ? ':' : '')
        : line;
    return Text(
      label,
      style: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        color: textColor,
        height: 1.45,
      ),
    );
  }

  // Inline bold: split por **...**
  final parts = <TextSpan>[];
  final regex = RegExp(r'\*\*(.+?)\*\*');
  int cursor = 0;
  for (final match in regex.allMatches(line)) {
    if (match.start > cursor) {
      parts.add(TextSpan(text: line.substring(cursor, match.start)));
    }
    parts.add(TextSpan(
      text: match.group(1),
      style: const TextStyle(fontWeight: FontWeight.w700),
    ));
    cursor = match.end;
  }
  if (cursor < line.length) {
    parts.add(TextSpan(text: line.substring(cursor)));
  }

  if (parts.isEmpty) return const SizedBox.shrink();

  return RichText(
    text: TextSpan(
      style: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w400,
        color: textColor,
        height: 1.5,
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

  const _AiBlockBubble({
    required this.block,
    required this.dark,
    this.isLast = false,
    this.onCopy,
    this.onTts,
    this.ttsPlaying = false,
    this.ttsReady = false,
    this.lang = 'pt',
  });

  // ── Detectores de tipo de linha para hierarquia visual hospitalar ────────

  /// Linha HARD STOP — alerta de contraindicação crítica
  // UNICODE-SAFE: toUpperCase() em Dart é Unicode-aware (não degrada acentos).
  // As strings de comparação estão em UPPERCASE para match case-insensitive.
  // Adicionadas variações sem acento como fallback de safety net.
  bool _isHardStop(String line) {
    final tu = line.trim().toUpperCase();
    return tu.contains('HARD STOP') ||
           tu.contains('HARD_STOP') ||
           tu.contains('CONTRAINDICAÇÃO ABSOLUTA') ||  // com acento correto
           tu.contains('CONTRAINDICACAO ABSOLUTA') ||  // fallback sem acento
           tu.contains('CONTRAINDICACIÓN ABSOLUTA') || // espanhol com acento
           tu.contains('CONTRAINDICACION ABSOLUTA');   // espanhol fallback
  }

  /// Título H2 — linhas que começam com '## ' (dois sustenidos + espaço)
  /// Renderizado em cyan #38BDF8, fonte 13.5→15, bold — acima do _isSectionHeader
  bool _isH2(String line) {
    final t = line.trim();
    return t.startsWith('## ') && !t.startsWith('### ');
  }

  /// Linha de seção principal (### ou marcador clínico padrão ou 4-blocos emoji)
  bool _isSectionHeader(String line) {
    final t = line.trim();
    // Reconhece os 5 blocos oficiais premium: 🚨 💊 ⛔ 📌 🟥 (Build 106)
    if (t.startsWith('🚨') || t.startsWith('💊') ||
        t.startsWith('⛔') || t.startsWith('📌') ||
        t.startsWith('🟥')) return true;
    return t.startsWith('###') ||
           RegExp(
             // Aceita tanto versões acentuadas quanto não-acentuadas (safety net)
             r'^(Hipótese|Hipóteses|Hipotese|Hipoteses|'
             r'Hipotesis|Hipótesis|'
             r'Conduta|Conducta|'
             r'Exames|Examenes|'
             r'Monitoriz|Monitorizaç|'  // PT: Monitorização/Monitorização
             r'Evitar|'
             r'Escalonamento|Escalonamiento|'
             r'AGORA|AHORA|QUICK|CLINICAL|TEACH|'
             r'Primeira Escolha|Primera Elección|Primera Eleccion)',
             caseSensitive: false,
           ).hasMatch(t);
    // NOTA: 'Confiança|Confianza' removido — não deve renderizar como seção.
    // _cleanAiText() e _stripMetadataHeaders() já eliminam essas linhas antes
    // de chegar aqui. Manter no detector causava que linhas que escapassem das
    // purgas fossem exibidas com destaque visual como seção clínica.
  }

  /// Linha de alerta/atenção (mas não hard stop)
  // UNICODE-SAFE: não usa toUpperCase() antes de comparar com strings acentuadas
  // como 'ATENÇÃO'/'ATENCIÓN' — toUpperCase() em Dart preserva maiúsculas Unicode
  // corretas, mas a comparação com literal maiúsculo é segura. Checamos tanto
  // a versão original quanto a uppercase para capturar "Atenção", "ATENÇÃO", etc.
  bool _isWarning(String line) {
    final t = line.trim();
    final tu = t.toUpperCase();
    return (t.startsWith('⚠') ||
            tu.startsWith('ATENÇÃO') || tu.startsWith('ATENCIÓN') ||
            tu.startsWith('ATENCION') ||   // fallback sem acento
            tu.startsWith('ATENCAO') ||    // fallback sem acento
            tu.startsWith('ALERTA') ||
            tu.startsWith('CUIDADO') ||
            tu.startsWith('NOTA:') ||
            tu.startsWith('OBS:')) &&
           !_isHardStop(line);
  }

  /// Linha de referência bibliográfica
  bool _isReference(String line) {
    final t = line.trim();
    return t.startsWith('📚') || t.startsWith('Ref') || t.startsWith('Fonte') ||
           t.startsWith('Fuente') || t.startsWith('[ESC') || t.startsWith('[AHA') ||
           t.startsWith('[IDSA') || t.startsWith('[ACC') || t.startsWith('[GOLD') ||
           (t.startsWith('[') && t.endsWith(']') && t.length < 60);
  }

  /// Linha de item de lista (bullet) — inclui markdown asterisco `* `
  bool _isListItem(String line) {
    final t = line.trimLeft();
    return t.startsWith('* ') || t.startsWith('- ') || t.startsWith('• ') ||
           t.startsWith('→ ') || t.startsWith('▸ ') ||
           RegExp(r'^\d+\.\s').hasMatch(t);
  }

  @override
  Widget build(BuildContext context) {
    // ConnectMind AI — AI bubble background (navy in dark)
    final bubbleBg  = dark ? const Color(0xFF252930) : Colors.white;
    final textColor = dark ? const Color(0xFFE8F2F5) : const Color(0xFF1A1D23);

    // ConnectMind AI palette — section headers
    const kGreen      = Color(0xFF008CA4);
    const kGreenLight = Color(0xFF00E5FF);
    const kRed        = Color(0xFFB91C1C);
    const kRedLight   = Color(0xFFFFEEEE);
    const kRedDark    = Color(0xFF3A0000);
    const kAmber      = Color(0xFFB45309);
    const kRef        = Color(0xFF64748B);

    final lines = block.split('\n');

    // ── Detecta se o bloco inteiro é HARD STOP ────────────────────────────
    final bool isHardStopBlock = lines.any(_isHardStop);

    return Padding(
      padding: EdgeInsets.only(
        bottom: isLast ? 5 : 2,
        right: 48,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.fromLTRB(11, 8, 11, 6),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              topLeft:     Radius.circular(4),
              topRight:    Radius.circular(16),
              bottomLeft:  Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            color: isHardStopBlock
                ? (dark ? kRedDark : kRedLight)
                : bubbleBg,
            border: isHardStopBlock
                ? Border.all(color: kRed.withValues(alpha: 0.35), width: 1.0)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.3 : 0.08),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Renderização linha a linha com hierarquia visual ─────────
              ...lines.map((line) {
                final trimmed = line.trim();
                if (trimmed.isEmpty) return const SizedBox(height: 1);

                // HARD STOP — destaque vermelho máximo
                if (_isHardStop(line)) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 3, top: 2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: kRed.withValues(alpha: dark ? 0.25 : 0.12),
                        border: Border.all(color: kRed.withValues(alpha: 0.5)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.dangerous_rounded, size: 13, color: kRed),
                        const SizedBox(width: 6),
                        Expanded(child: _buildInlineText(
                          trimmed.replaceAll(RegExp(r'\*\*HARD.STOP[:\s]*', caseSensitive: false), '').trim(),
                          kRed, isBold: true,
                        )),
                      ]),
                    ),
                  );
                }

                // H2 — cabeçalho markdown '## Título' em cyan oficial
                if (_isH2(line)) {
                  final label = line.trim().replaceFirst(RegExp(r'^##\s+'), '');
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 3, top: 6),
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF38BDF8), // cyan oficial
                        letterSpacing: 0.1,
                        height: 1.35,
                      ),
                    ),
                  );
                }

                // ── 🟥 CARD VERMELHO — Conduta / Prescrição Medicamentosa (Build 106) ──
                // Widget especial com fundo vermelho tênue + ícone medicamento.
                // Renderizado ANTES do _isSectionHeader genérico para sobrepor o
                // estilo de barra lateral com um card completo (background + borda).
                if (trimmed.startsWith('🟥')) {
                  final label = trimmed
                      .replaceFirst('🟥', '')
                      .replaceFirst(RegExp(r'^[\s—\-:]+'), '')
                      .trim();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 3, top: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: kRed.withValues(alpha: dark ? 0.18 : 0.08),
                        border: Border.all(color: kRed.withValues(alpha: 0.40), width: 1.0),
                      ),
                      child: Row(children: [
                        const Icon(Icons.medication_rounded, size: 14, color: kRed),
                        const SizedBox(width: 7),
                        Expanded(child: _buildInlineText(
                          label.isEmpty ? trimmed : label,
                          dark ? const Color(0xFFFF8080) : kRed,
                          isBold: true,
                        )),
                      ]),
                    ),
                  );
                }

                // Linha de seção principal — hierarquia visual por emoji de bloco
                if (_isSectionHeader(line)) {
                  final label = trimmed.replaceFirst(RegExp(r'^###?\s*'), '');
                  // Cor da barra lateral baseada no bloco oficial
                  final Color barColor;
                  final Color labelColor;
                  if (trimmed.startsWith('🚨')) {
                    barColor   = kRed;
                    labelColor = dark ? const Color(0xFFFF8080) : kRed;
                  } else if (trimmed.startsWith('⛔')) {
                    barColor   = kAmber;
                    labelColor = dark ? const Color(0xFFFFD580) : kAmber;
                  } else if (trimmed.startsWith('📌')) {
                    barColor   = const Color(0xFF4A90D9);
                    labelColor = dark ? const Color(0xFF89C4FF) : const Color(0xFF2563EB);
                  } else {
                    // 💊 e padrão → ConnectMind cyan
                    barColor   = kGreenLight;
                    labelColor = dark ? const Color(0xFF00E5FF) : kGreen;
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2, top: 5),
                    child: Row(children: [
                      Container(
                        width: 3, height: 13,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: barColor,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: labelColor,
                          letterSpacing: 0.1,
                          height: 1.3,
                        ),
                      )),
                    ]),
                  );
                }

                // Linha de alerta/atenção — destaque âmbar
                if (_isWarning(line)) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2, top: 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        color: kAmber.withValues(alpha: dark ? 0.15 : 0.08),
                        border: Border.all(color: kAmber.withValues(alpha: 0.25)),
                      ),
                      child: _buildInlineText(trimmed, dark ? const Color(0xFFFFD580) : kAmber),
                    ),
                  );
                }

                // Linha de referência — texto compacto cinza
                if (_isReference(line)) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 1, top: 1),
                    child: Text(
                      trimmed,
                      style: TextStyle(
                        fontSize: 10,
                        color: dark ? Colors.white38 : kRef,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                  );
                }

                // Item de lista — bullet com indent (suporta '- ', '* ', '• ', '→', '▸', '1. ')
                if (_isListItem(line)) {
                  // Strip do marcador: remove '- ', '* ', '• ', '→ ', '▸ ' ou '1. '
                  final content = trimmed
                      .replaceFirst(RegExp(r'^[-\*•→▸]\s+'), '')
                      .replaceFirst(RegExp(r'^\d+\.\s+'), '')
                      .trimLeft();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2, left: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 6, right: 7),
                          child: Container(
                            width: 5, height: 5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF38BDF8).withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                        Expanded(child: _buildInlineText(content, textColor)),
                      ],
                    ),
                  );
                }

                // Texto normal
                return Padding(
                  padding: const EdgeInsets.only(bottom: 1),
                  child: _buildInlineText(trimmed, textColor),
                );
              }),

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
                              ? kGreen.withValues(alpha: 0.15)
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

  @override
  void initState() {
    super.initState();
    _cachedBlocks = _computeBlocks(widget.text);
    // Inicia a sequência de exibição após o primeiro frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _startSequence());
  }

  @override
  void didUpdateWidget(_AiBubble old) {
    super.didUpdateWidget(old);

    final textChanged      = old.text != widget.text;
    final streamingChanged = old.isStreaming != widget.isStreaming;

    if (!textChanged && !streamingChanged) return;

    // ── CORREÇÃO CRÍTICA DE REATIVIDADE ─────────────────────────────────────
    // BUG: didUpdateWidget atualizava _cachedBlocks mas NÃO chamava setState.
    // Flutter só executa build() quando setState é chamado. Sem setState aqui,
    // o widget recebia o novo texto do chunk mas a tela não se redesenhava —
    // a bolha ficava congelada até o usuário fechar e reabrir a tela.
    //
    // SOLUÇÃO: setState dentro de didUpdateWidget força o rebuild imediato
    // a cada chunk recebido, renderizando o texto crescente em tempo real.
    setState(() {
      _cachedBlocks = _computeBlocks(widget.text);

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
      // _computeBlocks() pode gerar um nº diferente de blocos (sem o ▌).
      // Garante que _visibleCount cobre TODOS os blocos finais — evita que
      // o último bloco fique invisível se o count anterior era para blocos-com-cursor.
      if (!widget.isStreaming && old.isStreaming && _cachedBlocks.isNotEmpty) {
        _visibleCount = _cachedBlocks.length;
      }
    });

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

  List<String> _computeBlocks(String text) {
    // Durante streaming: append cursor ▌ ao texto para feedback visual.
    // O cursor é removido automaticamente quando isStreaming vai para false
    // (didUpdateWidget regenera os blocos sem o cursor).
    final displayText = widget.isStreaming ? '$text\u258c' : text;

    // Durante streaming: sanitiza markdown parcial ANTES de processar.
    // Evita exibir asteriscos soltos e marcadores incompletos enquanto a IA digita.
    final safeText = widget.isStreaming
        ? _sanitizePartialMarkdown(displayText)
        : displayText;

    final cleaned = _cleanAiText(safeText);
    return _splitIntoBlocks(cleaned.isEmpty ? safeText.trim() : cleaned);
  }

  /// Sanitiza markdown incompleto durante o streaming chunk a chunk.
  ///
  /// Problemas comuns ao renderizar texto parcial:
  ///  • "* " sozinho no fim  → marcador de lista sem conteúdo ainda
  ///  • "- " sozinho no fim  → traço de lista sem texto
  ///  • "**texto" sem fechar → negrito não terminado quebra layout
  ///  • "### " sem título    → cabeçalho vazio
  ///
  /// Estratégia: inspeciona apenas a ÚLTIMA linha (fragmento em construção).
  /// Linhas anteriores já chegaram completas e não são alteradas.
  static String _sanitizePartialMarkdown(String text) {
    if (text.isEmpty) return text;

    final lines  = text.split('\n');
    final lastIdx = lines.length - 1;
    String last   = lines[lastIdx];

    // Remove cursor ▌ para analisar o conteúdo real
    final hasCursor = last.endsWith('\u258c');
    if (hasCursor) last = last.substring(0, last.length - 1);

    final trimmedLast = last.trimLeft();

    // Marcador de lista sozinho ("* ", "- ", "• " sem texto após)
    if (RegExp(r'^[\*\-•]\s*$').hasMatch(trimmedLast)) {
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
    final blocks = _cachedBlocks;

    if (blocks.isEmpty) {
      return _visibleCount > 0
          ? _AiBlockBubble(
              block: widget.text.trim(),
              dark: widget.dark,
              isLast: true,
              onCopy: widget.onCopy,
              onTts: widget.onTts,
              ttsPlaying: widget.ttsPlaying,
              ttsReady: widget.ttsReady,
              lang: widget.lang,
            )
          : const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(blocks.length, (i) {
        if (i >= _visibleCount) return const SizedBox.shrink();
        final isLast = i == blocks.length - 1;
        // ⚡ RepaintBoundary isola cada bolha em sua própria camada de renderização
        // O scroll não força repaint das bolhas que não mudaram
        return RepaintBoundary(
          child: _AiBlockBubble(
            block: blocks[i],
            dark: widget.dark,
            isLast: isLast,
            onCopy: isLast ? widget.onCopy : null,
            onTts:      isLast ? widget.onTts  : null,
            ttsPlaying: isLast && widget.ttsPlaying,
            ttsReady:   widget.ttsReady,
            lang: widget.lang,
          ),
        );
      }),
    );
  }
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
    final bg = widget.dark ? const Color(0xFF252930) : Colors.white;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, right: 52),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            color: bg,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: widget.dark ? 0.3 : 0.08),
                blurRadius: 4, offset: const Offset(0, 1)),
            ],
          ),
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
                          color: const Color(0xFF10B981).withValues(alpha: 0.6),
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
// _AudioWave — 5 barras verticais finas animadas pelo nível do microfone.
//
// • Quando level > 0: as barras crescem proporcionalmente ao volume captado.
// • Quando level = 0: reduzem a pontos estáticos (2×2 px) indicando standby.
// • Usa AnimatedContainer para transições fluidas sem AnimationController externo.
// ─────────────────────────────────────────────────────────────────────────────
class _AudioWave extends StatelessWidget {
  final double level;       // 0.0–1.0 normalizado
  final Color  activeColor; // cor das barras ativas
  const _AudioWave({required this.level, required this.activeColor});

  @override
  Widget build(BuildContext context) {
    // 5 fatores de altura distintos — cria perfil de onda orgânica
    const factors = [0.55, 0.80, 1.00, 0.80, 0.55];
    const maxH    = 22.0; // altura máxima de cada barra em px
    const minH    =  2.5; // altura mínima (ponto estático em silêncio)

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(factors.length, (i) {
        final targetH = level < 0.03
            ? minH
            : (minH + (maxH - minH) * level * factors[i]).clamp(minH, maxH);
        return Padding(
          padding: EdgeInsets.only(right: i < factors.length - 1 ? 3.0 : 0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            curve: Curves.easeOut,
            width: 2.0,
            height: targetH,
            decoration: BoxDecoration(
              color: level < 0.03
                  ? activeColor.withValues(alpha: 0.35)
                  : activeColor.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Input bar — glassmorphism flutuante premium
//
// Arquitetura: StatefulWidget para hospedar o FocusNode do KeyboardListener.
// Fundo: BackdropFilter blur + cor escura semitransparente (dark) /
//        branca semitransparente (light) + borda ultrafina + cantos 24px.
// Layout STT: enquanto sttListening=true, mostra _AudioWave centralizada em
//             vez do texto de status, com indicador de microfone vermelho.
// ─────────────────────────────────────────────────────────────────────────────
class _InputBar extends StatefulWidget {
  final TextEditingController ctrl;
  final FocusNode focusNode;
  final bool dark;
  final bool hasFocus;
  final bool thinking;
  final VoidCallback onSend;
  final VoidCallback onVoice;
  final bool sttListening;
  final double sttSoundLevel;
  final String hint;
  final String lang;
  const _InputBar({
    required this.ctrl,
    required this.focusNode,
    required this.dark,
    required this.hasFocus,
    required this.thinking,
    required this.onSend,
    required this.onVoice,
    required this.sttListening,
    required this.sttSoundLevel,
    required this.hint,
    required this.lang,
  });

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  // FocusNode dedicado para o KeyboardListener — separado do focusNode do TextField
  final FocusNode _keyboardListenerNode = FocusNode();

  @override
  void dispose() {
    _keyboardListenerNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool dark        = widget.dark;
    final bool isEs        = widget.lang == 'es';
    final bool isListening = widget.sttListening;
    final double level     = widget.sttSoundLevel;

    // ── Cores do campo de texto — ConnectMind AI palette
    final fieldBg = dark ? const Color(0xFF252930) : Colors.white;
    final borderCol = widget.hasFocus
        ? const Color(0xFF00E5FF)
        : (dark ? const Color(0xFF374151) : const Color(0xFFD1D6DC));
    final textCol = dark ? Colors.white : const Color(0xFF1A1D23);
    final hintCol = dark ? Colors.white30 : Colors.black38;

    // ── Cores do microfone
    final micCol    = isListening
        ? const Color(0xFFEF4444)
        : (dark ? Colors.white60 : Colors.black45);
    final micBgCol  = isListening
        ? const Color(0xFFEF4444).withValues(alpha: 0.15)
        : (dark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.black.withValues(alpha: 0.05));
    final micBorder = isListening
        ? const Color(0xFFEF4444).withValues(alpha: 0.55)
        : Colors.transparent;

    // ── Cor das barras de onda
    final waveColor = isListening
        ? const Color(0xFFEF4444)
        : (dark ? Colors.white54 : Colors.black38);

    // ── Tooltip do microfone — bilíngue
    final micTip = isListening
        ? (isEs ? 'Detener dictado' : 'Parar ditado')
        : (isEs ? 'Dictar mensaje' : 'Ditar mensagem');

    // ── Texto de status STT — bilíngue, peso leve, sutil
    final statusText = isListening
        ? (isEs ? 'Escuchando…' : 'Ouvindo…')
        : (isEs ? 'Micrófono listo. Toca para dictar.'
                : 'Microfone pronto. Toque para ditar.');

    // ── Glassmorphism: fundo semitransparente + blur ───────────────────────
    // O ClipRRect é necessário para que o BackdropFilter respeite o borderRadius
    // e não vaze para fora do card flutuante.
    // Build 99 — removido SafeArea(top: false) que causava espaço em branco duplo
    // entre o campo de input e o BottomAppBar. O BottomAppBar já lida com o
    // safe area do home indicator nativamente — adicionar SafeArea aqui causava
    // um segundo padding bottom que criava o grande vazio branco visível no screenshot.
    return Padding(
      // Padding vertical -50%: 8→4 top/bottom — barra mais compacta
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                // Fundo semitransparente — ConnectMind navy glassmorphism
                color: dark
                    ? const Color(0xFF252930).withValues(alpha: 0.82)
                    : Colors.white.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: dark
                      ? const Color(0xFF00E5FF).withValues(alpha: 0.12)
                      : const Color(0xFF008CA4).withValues(alpha: 0.18),
                  width: 0.8,
                ),
              ),
              // Padding interno vertical -50%: 8→4 — mantém mic+texto centrados
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  // ── Painel STT — onda de áudio ou campo de texto ─────────
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 220),
                    crossFadeState: isListening
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,

                    // ── Estado normal: campo de texto ──────────────────────
                    firstChild: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [

                        // Botão microfone — ícone outline delicado
                        Tooltip(
                          message: micTip,
                          child: GestureDetector(
                            onTap: widget.onVoice,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              // Mic -50% vertical: 38→32
                              width: 32, height: 32,
                              margin: const EdgeInsets.only(right: 6, bottom: 0),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: micBgCol,
                                border: Border.all(color: micBorder, width: 1.2),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.mic_none_outlined,
                                  size: 18,
                                  color: micCol,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Campo de texto
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: fieldBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: borderCol,
                                width: widget.hasFocus ? 1.4 : 0.9,
                              ),
                            ),
                            child: KeyboardListener(
                              focusNode: _keyboardListenerNode,
                              onKeyEvent: (event) {
                                if (kIsWeb &&
                                    event is KeyDownEvent &&
                                    event.logicalKey == LogicalKeyboardKey.enter &&
                                    !HardwareKeyboard.instance.isShiftPressed &&
                                    !HardwareKeyboard.instance.isControlPressed &&
                                    !widget.thinking) {
                                  widget.onSend();
                                }
                              },
                              child: TextField(
                                controller: widget.ctrl,
                                focusNode: widget.focusNode,
                                maxLines: 5,
                                minLines: 1,
                                textInputAction: TextInputAction.newline,
                                keyboardType: TextInputType.multiline,
                                autofillHints: const [],
                                enableSuggestions: true,
                                autocorrect: true,
                                textCapitalization: TextCapitalization.sentences,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: textCol,
                                  height: 1.5,
                                ),
                                decoration: InputDecoration(
                                  hintText: widget.hint,
                                  hintStyle: TextStyle(
                                    fontSize: 14,
                                    color: hintCol,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  border: InputBorder.none,
                                  // ContentPadding -50% vertical: 9→4
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 4,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),

                        // Botão enviar — ConnectMind cyan
                        GestureDetector(
                          onTap: widget.thinking ? null : widget.onSend,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            // Send btn -50% vertical: 42→34
                            width: 34, height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: widget.thinking
                                  ? const Color(0xFF008CA4).withValues(alpha: 0.45)
                                  : const Color(0xFF008CA4),
                            ),
                            child: Center(
                              child: widget.thinking
                                  ? const SizedBox(
                                      width: 17, height: 17,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.8,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.arrow_upward_rounded,
                                      color: Colors.white,
                                      size: 19,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // ── Estado STT ativo: onda de áudio centralizada ────────
                    secondChild: SizedBox(
                      height: 56,
                      child: Row(
                        children: [

                          // Botão parar ditado — ícone mic vermelho outline
                          Tooltip(
                            message: micTip,
                            child: GestureDetector(
                              onTap: widget.onVoice,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 38, height: 38,
                                margin: const EdgeInsets.only(right: 10),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                                  border: Border.all(
                                    color: const Color(0xFFEF4444).withValues(alpha: 0.50),
                                    width: 1.2,
                                  ),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.mic_off_outlined,
                                    size: 17,
                                    color: Color(0xFFEF4444),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Onda de áudio + texto de status
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Onda animada
                                _AudioWave(
                                  level: level,
                                  activeColor: waveColor,
                                ),
                                const SizedBox(height: 5),
                                // Texto de status — leve, sutil, bilíngue
                                Text(
                                  statusText,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: 0.5,
                                    color: dark
                                        ? Colors.white.withValues(alpha: 0.50)
                                        : Colors.black.withValues(alpha: 0.45),
                                    height: 1.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
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
        ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Banner de erro de IA — aparece abaixo do header quando IA retorna erro
// Cobre tanto erros de chave OpenAI quanto token Gemini expirado
// ─────────────────────────────────────────────────────────────────────────────
class _AiErrorBanner extends StatelessWidget {
  final bool dark;
  final String lang;
  final VoidCallback onFix;
  const _AiErrorBanner({required this.dark, required this.lang, required this.onFix});

  @override
  Widget build(BuildContext context) {
    final isEs = lang == 'es';
    // Detecta se o erro foi de token Gemini expirado para mensagem específica
    final p = context.read<AppProvider>();
    final isGeminiError = p.geminiConnected;

    final String msg;
    if (isGeminiError) {
      msg = isEs
          ? 'Sesión Google expirada — toca para reconectar'
          : 'Sessão Google expirada — toque para reconectar';
    } else {
      msg = isEs
          ? 'Clave API inválida — toca para configurar'
          : 'Chave API inválida — toque para configurar';
    }

    return GestureDetector(
      onTap: onFix,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: const Color(0xFFB91C1C).withValues(alpha: 0.12),
        child: Row(children: [
          Icon(
            isGeminiError
                ? Icons.account_circle_outlined
                : Icons.error_outline_rounded,
            color: const Color(0xFFEF4444), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: Color(0xFFEF4444)),
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFFEF4444), size: 16),
        ]),
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
      debugPrint('[_handleGoogleConnect] redirect OAuth iniciado — aguardando reload');
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
    // Lê estado atualizado em tempo real via Consumer
    return Consumer<AppProvider>(
      builder: (context, p, _) {
        final dark           = widget.dark;
        final isEs           = _isEs;
        final geminiConn     = p.geminiConnected;
        final geminiEmail    = p.geminiEmail;
        final geminiLoading  = p.geminiLoading;
        final hasAnyAi       = p.hasAnyAi;

        final bg     = dark ? const Color(0xFF0F1A14) : Colors.white;
        final cardBg = dark ? const Color(0xFF2D3340) : const Color(0xFFF5F7F5);
        final divCol = dark ? Colors.white12 : Colors.black.withValues(alpha: 0.08);
        final sub    = dark ? Colors.white54 : Colors.black54;
        final text   = dark ? Colors.white : const Color(0xFF1A1D23);
        const green  = Color(0xFF10B981);
        const blue   = Color(0xFF1A73E8); // cor Google azul

        // Determina qual label de status mostrar no badge
        final String badgeLabel;
        if (geminiLoading || widget.keyLoading) {
          badgeLabel = 'Conectando...';
        } else if (geminiConn) {
          badgeLabel = 'Gemini online';
        } else if (hasAnyAi) {
          badgeLabel = 'GPT online';
        } else {
          badgeLabel = 'Base local';
        }

        final String modeLabel;
        if (geminiConn) {
          modeLabel = isEs
              ? 'Modo híbrido — base clínica + Gemini 1.5 Flash'
              : 'Modo híbrido — base clínica + Gemini 1.5 Flash';
        } else if (hasAnyAi) {
          modeLabel = isEs
              ? 'Modo híbrido — base clínica + GPT-4o mini'
              : 'Modo híbrido — base clínica + GPT-4o mini';
        } else {
          modeLabel = isEs
              ? 'Modo local — base clínica integrada'
              : 'Modo local — base clínica integrada';
        }

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
                // Avatar + nome + badge
                Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasAnyAi
                          ? Colors.white.withValues(alpha: 0.15)
                          : green.withValues(alpha: 0.12),
                    ),
                    child: Center(
                      child: Text(
                        widget.userName.isNotEmpty
                            ? widget.userName[0].toUpperCase()
                            : (widget.userEmail.isNotEmpty
                                ? widget.userEmail[0].toUpperCase()
                                : '?'),
                        style: TextStyle(
                          fontSize: 19, fontWeight: FontWeight.w800,
                          color: hasAnyAi ? Colors.white : green),
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
                              ? Colors.white.withValues(alpha: 0.65)
                              : sub),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  )),
                  // Badge status
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: (geminiLoading || widget.keyLoading)
                          ? Colors.white.withValues(alpha: 0.08)
                          : (hasAnyAi
                              ? Colors.white.withValues(alpha: 0.15)
                              : green.withValues(alpha: 0.1)),
                      border: Border.all(
                        color: (geminiLoading || widget.keyLoading)
                            ? Colors.white.withValues(alpha: 0.15)
                            : (hasAnyAi
                                ? Colors.white.withValues(alpha: 0.3)
                                : green.withValues(alpha: 0.25))),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (geminiLoading || widget.keyLoading)
                        SizedBox(
                          width: 8, height: 8,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.2,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        )
                      else
                        Container(
                          width: 6, height: 6,
                          margin: const EdgeInsets.only(right: 5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: hasAnyAi
                                ? const Color(0xFF10B981)
                                : (dark ? Colors.white38 : Colors.black26)),
                        ),
                      const SizedBox(width: 5),
                      Text(
                        badgeLabel,
                        style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: (geminiLoading || widget.keyLoading)
                              ? Colors.white.withValues(alpha: 0.5)
                              : (hasAnyAi ? Colors.white : sub))),
                    ]),
                  ),
                ]),

                const SizedBox(height: 16),
                Divider(
                  color: hasAnyAi
                      ? Colors.white.withValues(alpha: 0.15)
                      : divCol,
                  height: 1),
                const SizedBox(height: 14),

                // Linha: modo de operação
                Row(children: [
                  Icon(Icons.psychology_rounded, size: 14,
                    color: hasAnyAi
                        ? Colors.white.withValues(alpha: 0.7)
                        : sub),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    modeLabel,
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: hasAnyAi ? Colors.white : text))),
                ]),
                const SizedBox(height: 8),

                // Linha: base local
                Row(children: [
                  Icon(Icons.local_hospital_rounded, size: 14,
                    color: hasAnyAi
                        ? Colors.white.withValues(alpha: 0.6)
                        : sub),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    isEs
                        ? '${uniqueDrugsCount} fármacos · protocolos de urgencias · siempre activo'
                        : '${uniqueDrugsCount} fármacos · protocolos de urgência · sempre ativo',
                    style: TextStyle(
                      fontSize: 11,
                      color: hasAnyAi
                          ? Colors.white.withValues(alpha: 0.6)
                          : sub))),
                ]),

                if (geminiConn) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.account_circle_rounded, size: 14,
                      color: const Color(0xFF10B981).withValues(alpha: 0.8)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      geminiEmail.isNotEmpty
                          ? geminiEmail
                          : (isEs
                              ? 'Google conectado — Gemini 1.5 Flash activo'
                              : 'Google conectado — Gemini 1.5 Flash ativo'),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.65)),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                ] else if (hasAnyAi) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.cloud_done_rounded, size: 14,
                      color: const Color(0xFF10B981).withValues(alpha: 0.8)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      isEs
                          ? 'GPT-4o mini conectado — enriquece con conocimiento global'
                          : 'GPT-4o mini conectado — enriquece com conhecimento global',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.6)))),
                  ]),
                ],
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
                    color: const Color(0xFF1A73E8).withValues(alpha: 0.25)),
                ),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: blue.withValues(alpha: 0.12),
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
                        color: const Color(0xFFB91C1C).withValues(alpha: 0.1),
                        border: Border.all(
                          color: const Color(0xFFB91C1C).withValues(alpha: 0.25)),
                      ),
                      child: geminiLoading
                          ? SizedBox(
                              width: 12, height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: const Color(0xFFEF4444).withValues(alpha: 0.7),
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
                    disabledBackgroundColor: blue.withValues(alpha: 0.4),
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
                            Text(
                              isEs
                                  ? 'Conectar con Google  →  IA gratuita'
                                  : 'Conectar com Google  →  IA gratuita',
                              style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700)),
                          ],
                        ),
                ),
              ),

            const SizedBox(height: 2),

            // Subtexto explicativo abaixo do botão
            if (!geminiConn)
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 4),
                child: Text(
                  isEs
                      ? '2 clics · usa tu propia cuenta Google · sin clave API'
                      : '2 cliques · usa sua conta Google · sem chave API',
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
              child: Column(children: [
                _InfoRow(
                  icon: Icons.auto_awesome_rounded,
                  iconColor: green,
                  dark: dark,
                  label: isEs
                      ? 'Base clínica sempre ativa'
                      : 'Base clínica sempre ativa',
                  sub: isEs
                      ? 'Protocolos e fármacos do app respondem instantaneamente, sem internet'
                      : 'Protocolos e fármacos do app respondem instantaneamente, sem internet',
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  icon: Icons.hub_rounded,
                  iconColor: hasAnyAi ? green : sub,
                  dark: dark,
                  label: geminiConn
                      ? (isEs
                          ? 'Gemini enriquece o que a base não cobre'
                          : 'Gemini enriquece o que a base não cobre')
                      : (isEs
                          ? 'IA enriquece o que a base não cobre'
                          : 'IA enriquece o que a base não cobre'),
                  sub: isEs
                      ? 'Perguntas fora da base são respondidas com conhecimento médico global'
                      : 'Perguntas fora da base são respondidas com conhecimento médico global',
                  dimmed: !hasAnyAi,
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  icon: Icons.wifi_off_rounded,
                  iconColor: sub,
                  dark: dark,
                  label: isEs ? 'Funciona offline' : 'Funciona offline',
                  sub: isEs
                      ? 'Sin internet, la base local responde normalmente'
                      : 'Sem internet, a base local responde normalmente',
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

// Widget auxiliar: linha de informação com ícone
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final bool dark;
  final String label;
  final String sub;
  final bool dimmed;
  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.dark,
    required this.label,
    required this.sub,
    this.dimmed = false,
  });
  @override
  Widget build(BuildContext context) {
    final textC = (dark ? Colors.white : const Color(0xFF1A1D23))
        .withValues(alpha: dimmed ? 0.4 : 1.0);
    final subC = (dark ? Colors.white54 : Colors.black45)
        .withValues(alpha: dimmed ? 0.4 : 1.0);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: iconColor.withValues(alpha: dimmed ? 0.06 : 0.1)),
        child: Center(child: Icon(icon, size: 15,
          color: iconColor.withValues(alpha: dimmed ? 0.4 : 1.0))),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
            style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: textC)),
          const SizedBox(height: 2),
          Text(sub,
            style: TextStyle(fontSize: 11, color: subC, height: 1.4)),
        ],
      )),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HISTÓRICO DE CHATS — bottom sheet com até 10 sessões salvas
// ─────────────────────────────────────────────────────────────────────────────
class _ChatHistorySheet extends StatelessWidget {
  final List<_ChatSession> sessions;
  final bool dark;
  final String lang;
  final void Function(_ChatSession) onRestore;
  final void Function(String) onDelete;

  const _ChatHistorySheet({
    required this.sessions,
    required this.dark,
    required this.lang,
    required this.onRestore,
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
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
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
                  color: dark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                ),
                child: Icon(Icons.close_rounded, size: 16, color: textS),
              ),
            ),
          ]),
        ),

        // Divisor
        Container(height: 1, color: divC, margin: const EdgeInsets.only(bottom: 4)),

        // Lista de sessões
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
                    final userCount = s.messages.where((m) => m.role == 'user').length;
                    return Dismissible(
                      key: ValueKey(s.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: const Color(0xFFCC2222).withValues(alpha: 0.1),
                        child: const Icon(Icons.delete_outline_rounded,
                          color: Color(0xFFCC2222), size: 22),
                      ),
                      onDismissed: (_) => onDelete(s.id),
                      child: InkWell(
                        onTap: () => onRestore(s),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          child: Row(children: [
                            // Ícone de sessão
                            Container(
                              width: 38, height: 38,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                              ),
                              child: Center(
                                child: Text(
                                  '${i + 1}',
                                  style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w800,
                                    color: Color(0xFF10B981)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.summary.isNotEmpty ? s.summary : '(sem resumo)',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600,
                                    color: textP, height: 1.3),
                                ),
                                const SizedBox(height: 3),
                                Row(children: [
                                  Icon(Icons.chat_bubble_outline_rounded,
                                    size: 10, color: textS),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$userCount ${lang == 'es' ? 'preguntas' : 'perguntas'}',
                                    style: TextStyle(fontSize: 10, color: textS)),
                                  const SizedBox(width: 10),
                                  Icon(Icons.access_time_rounded,
                                    size: 10, color: textS),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatDate(s.savedAt),
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

    // Cores
    final chipBg     = dark ? const Color(0xFF1A2E22) : const Color(0xFFE8F5EE);
    final chipBorder = dark ? const Color(0xFF2E7D52) : const Color(0xFF81C784);
    final labelColor = dark ? const Color(0xFF10B981) : const Color(0xFF2E7D52);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Chip colapsável ──────────────────────────────────────────────────
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: chipBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: chipBorder, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('📊', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  'EVIDENCIA CIENTÍFICA',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: labelColor,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: Icon(Icons.keyboard_arrow_down_rounded,
                      size: 18, color: labelColor),
                ),
              ],
            ),
          ),
        ),

        // ── Conteúdo expandido ───────────────────────────────────────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          child: _expanded
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
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
