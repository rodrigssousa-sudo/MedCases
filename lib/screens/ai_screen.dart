import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:convert';
import '../providers/app_provider.dart';
import '../data/drugs_database.dart';
import '../services/stt_helper.dart';


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
  final String role;
  final String text;
  const _ChatMsg({required this.role, required this.text});
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'savedAt': savedAt.toIso8601String(),
    'summary': summary,
    'messages': messages.map((m) => {'role': m.role, 'text': m.text}).toList(),
  };

  factory _ChatSession.fromJson(Map<String, dynamic> j) => _ChatSession(
    id: j['id'] as String,
    savedAt: DateTime.parse(j['savedAt'] as String),
    summary: j['summary'] as String? ?? '',
    messages: (j['messages'] as List? ?? []).map((m) =>
      _ChatMsg(role: m['role'] as String, text: m['text'] as String)
    ).toList(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
class AiScreen extends StatefulWidget {
  const AiScreen({super.key});
  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  final _queryCtrl  = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode  = FocusNode();
  final List<_ChatMsg> _messages = [];
  bool _thinking     = false;
  bool _hasFocus     = false;
  bool _aiError      = false;
  bool _greetingDone = false; // garante saudação só uma vez por sessão
  int  _lastAiIndex  = -1;   // índice da última resposta da IA (para animar só ela)
  // Auto-scroll: só desce automaticamente se usuário estiver perto do fundo
  bool _userScrolledUp = false; // true quando usuário scrollou para cima
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
  bool _sttListening    = false; // microfone ativo

  // Sugestões ficam visíveis apenas no estado vazio + sem foco
  bool get _showSuggestions => _messages.isEmpty && !_hasFocus;

  // ── Saudação padronizada por horário — SEMPRE em espanhol conforme spec ──
  // 00–06: "Buena madrugada"  |  06–12: "Buenos días"
  // 12–18: "Buenas tardes"    |  18–24: "Buenas noches"
  String _buildGreeting(String userName, String lang) {
    final hour = DateTime.now().hour;
    final String period;
    if (hour < 6) {
      period = 'Buena madrugada';
    } else if (hour < 12) {
      period = 'Buenos días';
    } else if (hour < 18) {
      period = 'Buenas tardes';
    } else {
      period = 'Buenas noches';
    }
    final firstName = userName.trim().split(' ').first;
    final nameStr   = firstName.isNotEmpty ? ', $firstName' : '';
    // Saudação estrita: só as duas frases definidas, sem listas nem extras
    return '$period$nameStr.\n\nSoy tu IA MedCases. ¿Cómo te puedo ayudar hoy?';
  }

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) setState(() => _hasFocus = _focusNode.hasFocus);
    });
    _queryCtrl.addListener(() {
      if (mounted && _queryCtrl.text.isNotEmpty && _hasFocus) {
        setState(() {});
      }
    });
    // Listener de scroll: detecta se usuário scrollou para cima
    _scrollCtrl.addListener(_onScroll);
    // Injeta saudação após o primeiro frame (AppProvider já disponível)
    WidgetsBinding.instance.addPostFrameCallback((_) => _injectGreeting());
    // Carrega histórico de chats do SharedPrefs
    _loadChatHistory();
    // Inicializa TTS
    _initTts();

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
      setState(() => _ttsPlayingIndex = -1);
      return;
    }
    // Para qualquer reprodução anterior
    await _tts.stop();
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

  // ── Voice-to-Text (Web Speech API via dart:html) ────────────────────────
  /// Inicia/para o reconhecimento de voz.
  /// No web: usa Web Speech API via SttHelper (dart:html condicionado).
  /// No mobile: exibe snack informativo.
  void _toggleStt() {
    if (!kIsWeb) {
      _showSttUnavailableSnack();
      return;
    }
    if (_sttListening) {
      _sttStop();
    } else {
      _sttStart();
    }
  }

  void _showSttUnavailableSnack() {
    final lang = context.read<AppProvider>().lang;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(lang == 'es'
          ? 'Dictado por voz disponible en la versión web'
          : 'Ditado por voz disponível na versão web'),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
    ));
  }

  void _sttStart() {
    setState(() => _sttListening = true);
    final lang = context.read<AppProvider>().lang;
    SttHelper.start(
      locale: lang == 'es' ? 'es-ES' : 'pt-BR',
      onResult: (text) {
        if (!mounted) return;
        setState(() {
          _sttListening = false;
          final current = _queryCtrl.text.trim();
          _queryCtrl.text = current.isEmpty ? text : '$current $text';
          _queryCtrl.selection = TextSelection.fromPosition(
            TextPosition(offset: _queryCtrl.text.length));
        });
        _focusNode.requestFocus();
      },
      onError: (_) {
        if (mounted) setState(() => _sttListening = false);
      },
      onEnd: () {
        if (mounted) setState(() => _sttListening = false);
      },
    );
  }

  void _sttStop() {
    SttHelper.stop();
    setState(() => _sttListening = false);
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
    _queryCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    _tts.stop();
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

    // Persiste no SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(_chatHistory.map((s) => s.toJson()).toList());
      await prefs.setString(_histKey(p), json);
    } catch (_) {}
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
          try {
            final prefs = await SharedPreferences.getInstance();
            final json = jsonEncode(_chatHistory.map((s) => s.toJson()).toList());
            await prefs.setString(_histKey(p), json);
          } catch (_) {}
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
  /// [force] = true: ignora a flag _userScrolledUp (usado apenas ao ENVIAR mensagem própria).
  /// Durante a resposta da IA (_thinking) nunca interrompe leitura do usuário.
  void _scrollDown({bool force = false}) {
    // Regra: se o usuário scrollou para cima E não é um envio forçado → não interrompe
    if (_userScrolledUp && !force) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) return;
      // Verificação extra: se o usuário voltou a scrollar para cima enquanto
      // aguardávamos o frame, ainda assim não interrompemos
      if (_userScrolledUp && !force) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send(String text, AppProvider p) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _thinking) return;
    _focusNode.unfocus();
    setState(() {
      _messages.add(_ChatMsg(role: 'user', text: trimmed));
      _thinking = true;
      _aiError  = false;
      _userScrolledUp = false; // reset ao enviar — desce para mostrar "pensando"
      // Marca que o usuário enviou nova mensagem (relevante ao restaurar sessão)
      _hasNewMessageAfterRestore = true;
    });
    _queryCtrl.clear();
    _scrollDown(force: true); // força scroll ao enviar mensagem do usuário

    // Chamada real (ou fallback local se sem chave)
    final answer = await p.buildAIAnswer(trimmed);

    if (!mounted) return;
    // Detecta se foi erro de chave inválida para mostrar banner
    final isKeyError = answer.startsWith('ERRO') && answer.contains('API');
    setState(() {
      _lastAiIndex = _messages.length; // índice que será inserido
      _messages.add(_ChatMsg(role: 'ai', text: answer));
      _thinking = false;
      _aiError  = isKeyError;
    });
    _scrollDown(); // scroll suave ao receber resposta (respeita _userScrolledUp)
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
      _aiError = false;
      _userScrolledUp = false;
      // Reseta flags de sessão restaurada para o novo chat em branco
      _restoredSessionId = null;
      _hasNewMessageAfterRestore = false;
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
    // Fundo estilo WhatsApp — levíssimo padrão
    final chatBg = dark ? const Color(0xFF101E16) : const Color(0xFFECE5DD);

    return Column(children: [
      // ── Header fino estilo WhatsApp ──────────────────────────────────────
      _WaHeader(
        dark: dark,
        hasMessages: _messages.isNotEmpty,
        onClear: _clearChat,
        onSettings: _openAiSettings,
        onHistory: () => _openHistory(p),
        historyCount: _chatHistory.length,
        lang: p.lang,
        hasRealAi:       p.hasAnyAi,
        geminiConnected: p.geminiConnected,
        keyLoading: p.aiKeyLoading || p.geminiLoading,
      ),

      // ── Banner de erro de chave ───────────────────────────────────────────
      if (_aiError)
        _AiErrorBanner(
          dark: dark,
          lang: p.lang,
          onFix: _openAiSettings,
        ),

      // ── Área de chat ─────────────────────────────────────────────────────
      Expanded(
        child: Container(
          color: chatBg,
          child: _messages.isEmpty
              ? _EmptyChat(dark: dark, lang: p.lang)
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  // ⚡ cacheExtent alto: mantém bubbles renderizados fora da viewport
                  // evita reconstituição ao scrollar — elimina o "salto" entre mensagens
                  cacheExtent: 2000,
                  physics: const ClampingScrollPhysics(),
                  itemCount: _messages.length + (_thinking ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (_thinking && i == _messages.length) {
                      return _ThinkingBubble(dark: dark);
                    }
                    final msg = _messages[i];
                    // ⚡ key por índice garante que Flutter reutilize o widget
                    // ao invés de destruir e recriar ao sair/entrar da viewport
                    return KeyedSubtree(
                      key: ValueKey('msg_$i'),
                      child: msg.role == 'user'
                          ? _UserBubble(text: msg.text, dark: dark)
                          : _AiBubble(
                              key: ValueKey('ai_$i'),
                              text: msg.text,
                              dark: dark,
                              animate: i == _lastAiIndex,
                              onCopy: () => _copyMsg(msg.text),
                              ttsPlaying: _ttsPlayingIndex == i,
                              ttsReady: _ttsReady,
                              onTts: _ttsReady
                                  ? () => _toggleTts(i, msg.text, p.lang)
                                  : null,
                            ),
                    );
                  },
                ),
        ),
      ),

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

      // ── Barra de input ─────────────────────────────────────────────────
      _InputBar(
        ctrl: _queryCtrl,
        focusNode: _focusNode,
        dark: dark,
        hasFocus: _hasFocus,
        thinking: _thinking,
        onSend: () => _send(_queryCtrl.text, context.read<AppProvider>()),
        hint: p.t('ai_placeholder'),
        onVoice: _toggleStt,
        sttListening: _sttListening,
        lang: p.lang,
      ),
    ]);
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
    required this.historyCount,
    required this.lang,
    required this.hasRealAi,
    this.geminiConnected = false,
    this.keyLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F1C14), Color(0xFF1B3D2A), Color(0xFF1F6B48)],
        ),
      ),
      child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            // Avatar
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
              ),
              child: const Center(
                child: Icon(Icons.psychology_rounded,
                  color: Color(0xFFFFE8A6), size: 20),
              ),
            ),
            const SizedBox(width: 10),
            // Nome + status
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('MedCases IA',
                  style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800,
                    color: Colors.white, letterSpacing: -0.2)),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  if (keyLoading)
                    // Indicador pulsante enquanto chave carrega do Firestore
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
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hasRealAi
                            ? const Color(0xFF4ADE80)   // verde = GPT ativo
                            : Colors.white.withValues(alpha: 0.35), // cinza = local
                      ),
                    ),
                  const SizedBox(width: 5),
                  Text(
                    keyLoading
                        ? 'Conectando...'
                        : (geminiConnected
                            ? 'Gemini 1.5 Flash • online'
                            : (hasRealAi
                                ? 'GPT-4o mini • online'
                                : (lang == 'es'
                                    ? 'Base clínica local • activo siempre'
                                    : 'Base clínica local • sempre ativa'))),
                    style: TextStyle(
                      fontSize: 10,
                      color: keyLoading
                          ? Colors.white.withValues(alpha: 0.40)
                          : (hasRealAi
                              ? const Color(0xFF4ADE80)
                              : Colors.white.withValues(alpha: 0.55)),
                      fontWeight: FontWeight.w600,
                    )),
                ]),
              ],
            )),
            // Botão Conectar IA / Conectado
            GestureDetector(
              onTap: onSettings,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: geminiConnected
                      ? const Color(0xFF4ADE80).withValues(alpha: 0.18)
                      : hasRealAi
                          ? const Color(0xFF4ADE80).withValues(alpha: 0.12)
                          : Colors.white.withValues(alpha: 0.10),
                  border: Border.all(
                    color: geminiConnected
                        ? const Color(0xFF4ADE80).withValues(alpha: 0.55)
                        : hasRealAi
                            ? const Color(0xFF4ADE80).withValues(alpha: 0.35)
                            : Colors.white.withValues(alpha: 0.20),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (keyLoading)
                      SizedBox(
                        width: 9, height: 9,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.4,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      )
                    else
                      Icon(
                        geminiConnected
                            ? Icons.check_circle_rounded
                            : hasRealAi
                                ? Icons.check_circle_outline_rounded
                                : Icons.link_rounded,
                        size: 13,
                        color: (geminiConnected || hasRealAi)
                            ? const Color(0xFF4ADE80)
                            : Colors.white.withValues(alpha: 0.55),
                      ),
                    const SizedBox(width: 5),
                    Text(
                      keyLoading
                          ? 'Conectando...'
                          : (geminiConnected || hasRealAi)
                              ? (lang == 'es' ? 'Conectado' : 'Conectado')
                              : (lang == 'es' ? 'Conectar IA' : 'Conectar IA'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: (geminiConnected || hasRealAi)
                            ? const Color(0xFF4ADE80)
                            : Colors.white.withValues(alpha: 0.75),
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Botão histórico — sempre visível, badge com número de sessões
            GestureDetector(
              onTap: onHistory,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    child: Icon(Icons.history_rounded, size: 18,
                      color: Colors.white.withValues(alpha: 0.8)),
                  ),
                  if (historyCount > 0)
                    Positioned(
                      top: -4, right: -4,
                      child: Container(
                        width: 14, height: 14,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFFFE8A6),
                        ),
                        child: Center(
                          child: Text(
                            '$historyCount',
                            style: const TextStyle(
                              fontSize: 8, fontWeight: FontWeight.w900,
                              color: Color(0xFF0F1C14)),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            // Limpar conversa — só aparece quando há mensagens
            if (hasMessages)
              GestureDetector(
                onTap: onClear,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                  child: Text(
                    lang == 'es' ? 'Limpiar' : 'Limpar',
                    style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: Color(0xFFFFE8A6))),
                ),
              ),
            const SizedBox(width: 4),
            // Botão menu — sempre visível
            GestureDetector(
              onTap: () => Scaffold.of(context).openEndDrawer(),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white.withValues(alpha: 0.1),
                ),
                child: Icon(Icons.menu_rounded, size: 18,
                  color: Colors.white.withValues(alpha: 0.8)),
              ),
            ),
          ]),
        ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Estado vazio — mensagem central minimalista
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyChat extends StatelessWidget {
  final bool dark;
  final String lang;
  const _EmptyChat({required this.dark, required this.lang});

  @override
  Widget build(BuildContext context) {
    final isEs = lang == 'es';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
            ),
            child: Center(
              child: Icon(Icons.psychology_outlined,
                size: 32,
                color: dark ? Colors.white24 : Colors.black26),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            isEs ? 'Describa el caso clínico' : 'Descreva o caso clínico',
            style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700,
              color: dark ? Colors.white60 : const Color(0xFF3A3A3A)),
          ),
          const SizedBox(height: 6),
          Text(
            isEs
              ? 'Use las sugerencias de abajo o escriba libremente'
              : 'Use as sugestões abaixo ou escreva livremente',
            style: TextStyle(
              fontSize: 12,
              color: dark ? Colors.white30 : Colors.black38,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
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
    final bg     = dark ? const Color(0xFF0A150E) : Colors.white;
    final border = dark ? const Color(0xFF1A2820) : const Color(0xFFE5E0D8);
    final chipBg = dark ? const Color(0xFF141F18) : const Color(0xFFF5F3EE);
    final chipBorder = dark ? const Color(0xFF253020) : const Color(0xFFDAD5CC);
    final textCol = dark ? Colors.white70 : const Color(0xFF2A2A2A);

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
            color: Color(0xFF005C4B),
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
String _cleanAiText(String raw) {
  return raw
      .replaceAll(RegExp(r'^#{1,3}\s*', multiLine: true), '')   // ## ### títulos
      .replaceAll('---', '')                                      // separadores
      .replaceAll('--', '')                                       // traços duplos
      .replaceAll(RegExp(r'\*{3,}'), '')                         // *** ou mais
      .trim();
}

/// Divide o texto em blocos lógicos separados por linha(s) em branco.
/// Cada bloco vai virar uma bolha independente.
List<String> _splitIntoBlocks(String text) {
  // Normaliza quebras de linha múltiplas em duplas
  final normalized = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  // Divide por linha em branco
  final rawBlocks = normalized.split(RegExp(r'\n\n+'));
  return rawBlocks
      .map((b) => b.trim())
      .where((b) => b.isNotEmpty)
      .toList();
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

/// Widget de um único bloco da IA — uma bolha WhatsApp.
class _AiBlockBubble extends StatelessWidget {
  final String block;
  final bool dark;
  final bool isLast;
  final VoidCallback? onCopy;
  final VoidCallback? onTts;
  final bool ttsPlaying;
  final bool ttsReady;

  const _AiBlockBubble({
    required this.block,
    required this.dark,
    this.isLast = false,
    this.onCopy,
    this.onTts,
    this.ttsPlaying = false,
    this.ttsReady = false,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleBg  = dark ? const Color(0xFF1F2E26) : Colors.white;
    final textColor = dark ? const Color(0xFFE8E8E8) : const Color(0xFF1A1A1A);

    final lines = block.split('\n');

    return Padding(
      padding: EdgeInsets.only(
        bottom: isLast ? 6 : 3,   // última bolha tem mais espaço abaixo
        right: 52,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.fromLTRB(13, 10, 13, 8),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              topLeft:     Radius.circular(4),
              topRight:    Radius.circular(16),
              bottomLeft:  Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            color: bubbleBg,
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
              // Linhas do bloco com suporte a negrito inline
              ...lines.map((line) {
                if (line.trim().isEmpty) return const SizedBox(height: 3);
                // Item de lista: começa com - ou •
                final isList = line.trimLeft().startsWith('-') ||
                               line.trimLeft().startsWith('•');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: _buildInlineText(
                    isList ? line : line,
                    textColor,
                  ),
                );
              }),

              // Rodapé só na última bolha: horário + áudio + copiar
              if (isLast) ...[
                const SizedBox(height: 6),
                Row(children: [
                  Text(
                    _fakeTime(),
                    style: TextStyle(
                      fontSize: 10,
                      color: dark ? Colors.white24 : Colors.black26,
                    ),
                  ),
                  const Spacer(),
                  // Botão TTS — ouvir resposta em áudio
                  if (onTts != null && ttsReady) ...[
                    GestureDetector(
                      onTap: onTts,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: ttsPlaying
                              ? const Color(0xFF1F6B48).withValues(alpha: 0.15)
                              : Colors.transparent,
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(
                            ttsPlaying
                                ? Icons.stop_circle_rounded
                                : Icons.volume_up_rounded,
                            size: 13,
                            color: ttsPlaying
                                ? const Color(0xFF1F6B48)
                                : (dark ? Colors.white38 : Colors.black38),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            ttsPlaying ? 'Parar' : 'Ouvir',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: ttsPlaying
                                  ? const Color(0xFF1F6B48)
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
                        Text('Copiar',
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
  // TTS
  final bool ttsPlaying;
  final bool ttsReady;
  final VoidCallback? onTts;
  const _AiBubble({
    super.key,
    required this.text,
    required this.dark,
    required this.onCopy,
    this.animate = false,
    this.ttsPlaying = false,
    this.ttsReady = false,
    this.onTts,
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
    // Atualiza cache apenas se o texto mudou
    if (old.text != widget.text) {
      _cachedBlocks = _computeBlocks(widget.text);
    }
  }

  List<String> _computeBlocks(String text) {
    final cleaned = _cleanAiText(text);
    return _splitIntoBlocks(cleaned.isEmpty ? text.trim() : cleaned);
  }

  void _startSequence() {
    if (_started || !mounted) return;
    _started = true;

    final total = _cachedBlocks.isEmpty ? 1 : _cachedBlocks.length;

    if (!widget.animate || total <= 1) {
      // Sem animação (histórico) ou bloco único → mostra tudo imediatamente
      if (mounted) setState(() => _visibleCount = total);
      return;
    }

    // Delay entre blocos: 120ms para o primeiro, depois 600ms por bloco
    // Cap: 2s máximo por bloco (mais rápido — melhora UX e scroll)
    for (int i = 0; i < total; i++) {
      final delayMs = i == 0 ? 120 : (i * 600).clamp(0, 2000);
      Future.delayed(Duration(milliseconds: delayMs), () {
        if (mounted) setState(() => _visibleCount = i + 1);
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
    final bg = widget.dark ? const Color(0xFF1F2E26) : Colors.white;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, right: 52),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                          color: const Color(0xFF1F6B48).withValues(alpha: 0.6),
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
// Input bar — ENTER envia (web/desktop), botão microfone STT, botão enviar
// ─────────────────────────────────────────────────────────────────────────────
class _InputBar extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode focusNode;
  final bool dark;
  final bool hasFocus;
  final bool thinking;
  final VoidCallback onSend;
  final VoidCallback onVoice;
  final bool sttListening;
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
    required this.hint,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    final barBg   = dark ? const Color(0xFF0A150E) : const Color(0xFFF0EBE3);
    final fieldBg = dark ? const Color(0xFF1A2820) : Colors.white;
    final borderCol = hasFocus
        ? const Color(0xFF1F6B48)
        : (dark ? const Color(0xFF253020) : const Color(0xFFD8D3CA));
    final textCol = dark ? Colors.white : const Color(0xFF1A1A1A);
    final hintCol = dark ? Colors.white30 : Colors.black38;
    final micCol  = sttListening ? const Color(0xFFEF4444) : (dark ? Colors.white54 : Colors.black45);

    // Tooltip do microfone
    final micTip = sttListening
        ? (lang == 'es' ? 'Detener dictado' : 'Parar ditado')
        : (lang == 'es' ? 'Dictar mensaje' : 'Ditar mensagem');

    return Container(
      color: barBg,
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      child: SafeArea(
        top: false,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [

          // ── Botão microfone ─────────────────────────────────────────────
          Tooltip(
            message: micTip,
            child: GestureDetector(
              onTap: onVoice,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40, height: 40,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: sttListening
                      ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                      : (dark
                          ? Colors.white.withValues(alpha: 0.07)
                          : Colors.black.withValues(alpha: 0.05)),
                  border: Border.all(
                    color: sttListening
                        ? const Color(0xFFEF4444).withValues(alpha: 0.6)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Icon(
                    sttListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                    size: 19,
                    color: micCol,
                  ),
                ),
              ),
            ),
          ),

          // ── Campo de texto com ENTER para enviar ────────────────────────
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: fieldBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: borderCol, width: hasFocus ? 1.5 : 1.0),
              ),
              child: KeyboardListener(
                focusNode: FocusNode(), // FocusNode separado para capturar teclas
                onKeyEvent: (event) {
                  // ENTER (sem Shift) em web/desktop → envia
                  if (kIsWeb &&
                      event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.enter &&
                      !HardwareKeyboard.instance.isShiftPressed &&
                      !HardwareKeyboard.instance.isControlPressed &&
                      !thinking) {
                    onSend();
                  }
                },
                child: TextField(
                  controller: ctrl,
                  focusNode: focusNode,
                  maxLines: 5,
                  minLines: 1,
                  // Mantém newline em mobile; no web ENTER envia via KeyboardListener
                  textInputAction: TextInputAction.newline,
                  spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
                  autocorrect: false,
                  style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w400,
                    color: textCol, height: 1.5),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(
                      fontSize: 14, color: hintCol, fontWeight: FontWeight.w400),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // ── Botão enviar — círculo verde ────────────────────────────────
          GestureDetector(
            onTap: thinking ? null : onSend,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 44, height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: thinking
                    ? const Color(0xFF1F6B48).withValues(alpha: 0.45)
                    : const Color(0xFF1F6B48),
              ),
              child: Center(
                child: thinking
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.arrow_upward_rounded,
                        color: Colors.white, size: 20),
              ),
            ),
          ),
        ]),
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
        final cardBg = dark ? const Color(0xFF1A2820) : const Color(0xFFF5F7F5);
        final divCol = dark ? Colors.white12 : Colors.black.withValues(alpha: 0.08);
        final sub    = dark ? Colors.white54 : Colors.black54;
        final text   = dark ? Colors.white : const Color(0xFF1A1A1A);
        const green  = Color(0xFF1F6B48);
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
                      ? [const Color(0xFF064E35), const Color(0xFF1B5E3B), const Color(0xFF1F6B48)]
                      : [dark ? const Color(0xFF1A2820) : const Color(0xFFF0F4F1),
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
                                ? const Color(0xFF4ADE80)
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
                      color: const Color(0xFF4ADE80).withValues(alpha: 0.8)),
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
                      color: const Color(0xFF4ADE80).withValues(alpha: 0.8)),
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
                      ? 'Sem internet, a base local responde normalmente'
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
    final textC = (dark ? Colors.white : const Color(0xFF1A1A1A))
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
    final bg    = dark ? const Color(0xFF1A1A1A) : Colors.white;
    final textP = dark ? Colors.white : const Color(0xFF1A1A1A);
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
                color: const Color(0xFF1F6B48).withValues(alpha: 0.15),
              ),
              child: const Icon(Icons.history_rounded,
                size: 16, color: Color(0xFF1F6B48)),
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
                        ? 'Aún no hay consultas guardadas.\nUsa "Limpiar" para guardar una sesión.'
                        : 'Nenhuma consulta salva ainda.\nUse "Limpar" para salvar uma sessão.',
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
                                color: const Color(0xFF1F6B48).withValues(alpha: 0.1),
                              ),
                              child: Center(
                                child: Text(
                                  '${i + 1}',
                                  style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w800,
                                    color: Color(0xFF1F6B48)),
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
