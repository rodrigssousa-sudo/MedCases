import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../data/drugs_database.dart';


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

  // Sugestões ficam visíveis apenas no estado vazio + sem foco
  bool get _showSuggestions => _messages.isEmpty && !_hasFocus;

  // ── Saudação contextual por hora e nome ─────────────────────────────────
  String _buildGreeting(String userName, String lang) {
    final hour = DateTime.now().hour;
    final isEs = lang == 'es';
    final String period = hour < 12
        ? (isEs ? 'Buenos días' : 'Bom dia')
        : hour < 18
            ? (isEs ? 'Buenas tardes' : 'Boa tarde')
            : (isEs ? 'Buenas noches' : 'Boa noite');
    final firstName = userName.trim().split(' ').first;
    final nameStr   = firstName.isNotEmpty ? ', $firstName' : '';
    if (isEs) {
      return '$period$nameStr! 👋\n\n'
          'Soy tu asistente de IA clínica. Puedo ayudarte con:\n'
          '• Protocolos y urgencias\n'
          '• Fármacos y dosis\n'
          '• Casos clínicos\n'
          '• Cualquier pregunta de medicina\n\n'
          '¿En qué puedo ayudarte hoy?';
    } else {
      return '$period$nameStr! 👋\n\n'
          'Sou sua assistente de IA clínica. Posso te ajudar com:\n'
          '• Protocolos e urgências\n'
          '• Fármacos e doses\n'
          '• Casos clínicos\n'
          '• Qualquer dúvida de medicina\n\n'
          'Como posso te ajudar hoje?';
    }
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
    // Injeta saudação após o primeiro frame (AppProvider já disponível)
    WidgetsBinding.instance.addPostFrameCallback((_) => _injectGreeting());
  }

  void _injectGreeting() {
    if (_greetingDone || !mounted) return;
    _greetingDone = true;
    final p = context.read<AppProvider>();
    setState(() {
      _messages.add(_ChatMsg(role: 'ai', text: _buildGreeting(p.userName, p.lang)));
    });
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
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
    });
    _queryCtrl.clear();
    _scrollDown();

    // Chamada real (ou fallback local se sem chave)
    final answer = await p.buildAIAnswer(trimmed);

    if (!mounted) return;
    // Detecta se foi erro de chave inválida para mostrar banner
    final isKeyError = answer.startsWith('ERRO') && answer.contains('API');
    setState(() {
      _messages.add(_ChatMsg(role: 'ai', text: answer));
      _thinking = false;
      _aiError  = isKeyError;
    });
    _scrollDown();
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
    setState(() {
      _messages
        ..clear()
        ..add(_ChatMsg(role: 'ai', text: _buildGreeting(p.userName, p.lang)));
      _aiError = false;
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
                  itemCount: _messages.length + (_thinking ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (_thinking && i == _messages.length) {
                      return _ThinkingBubble(dark: dark);
                    }
                    final msg = _messages[i];
                    return msg.role == 'user'
                        ? _UserBubble(text: msg.text, dark: dark)
                        : _AiBubble(
                            text: msg.text,
                            dark: dark,
                            onCopy: () => _copyMsg(msg.text),
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
        onSend: () => _send(_queryCtrl.text, context.read<AppProvider>()),
        hint: p.t('ai_placeholder'),
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
  final String lang;
  final bool hasRealAi;
  final bool geminiConnected;
  final bool keyLoading;
  const _WaHeader({
    required this.dark,
    required this.hasMessages,
    required this.onClear,
    required this.onSettings,
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
                const Text('IA Clínica',
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
            // Botão configurações da IA
            GestureDetector(
              onTap: onSettings,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white.withValues(alpha: 0.1),
                ),
                child: Icon(
                  geminiConnected
                      ? Icons.account_circle_rounded
                      : (hasRealAi ? Icons.key_rounded : Icons.key_off_rounded),
                  size: 18,
                  color: hasRealAi
                      ? const Color(0xFF4ADE80)
                      : Colors.white.withValues(alpha: 0.6)),
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
  const _UserBubble({required this.text, required this.dark});

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
// Bolha da IA — esquerda, branca/escura
// ─────────────────────────────────────────────────────────────────────────────
class _AiBubble extends StatelessWidget {
  final String text;
  final bool dark;
  final VoidCallback onCopy;
  const _AiBubble({required this.text, required this.dark, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    final bubbleBg  = dark ? const Color(0xFF1F2E26) : Colors.white;
    final textColor = dark ? const Color(0xFFE8E8E8) : const Color(0xFF1A1A1A);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6, right: 52),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.fromLTRB(13, 10, 13, 8),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            color: bubbleBg,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.3 : 0.08),
                blurRadius: 4, offset: const Offset(0, 1)),
            ],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildFormattedText(text, textColor),
            const SizedBox(height: 6),
            // Rodapé da bolha: horário fake + copiar
            Row(children: [
              Text(_fakeTime(),
                style: TextStyle(
                  fontSize: 10,
                  color: dark ? Colors.white24 : Colors.black26)),
              const Spacer(),
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
          ]),
        ),
      ),
    );
  }

  String _fakeTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildFormattedText(String text, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: text.split('\n').map((line) {
        if (line.startsWith('##')) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6, top: 2),
            child: Text(line,
              style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w800,
                color: textColor, height: 1.3)),
          );
        } else if (line.startsWith('•') || line.startsWith('-')) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(line,
              style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w400,
                color: textColor, height: 1.5)),
          );
        } else if (line.trim().isEmpty) {
          return const SizedBox(height: 5);
        } else {
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(line,
              style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w400,
                color: textColor, height: 1.5)),
          );
        }
      }).toList(),
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
// Input bar — idêntico ao WhatsApp
// ─────────────────────────────────────────────────────────────────────────────
class _InputBar extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode focusNode;
  final bool dark;
  final bool hasFocus;
  final VoidCallback onSend;
  final String hint;
  const _InputBar({
    required this.ctrl,
    required this.focusNode,
    required this.dark,
    required this.hasFocus,
    required this.onSend,
    required this.hint,
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

    return Container(
      color: barBg,
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      child: SafeArea(
        top: false,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          // Campo de texto
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: fieldBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: borderCol, width: hasFocus ? 1.5 : 1.0),
              ),
              child: TextField(
                controller: ctrl,
                focusNode: focusNode,
                maxLines: 5,
                minLines: 1,
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
          const SizedBox(width: 8),

          // Botão enviar — círculo verde, seta para cima
          GestureDetector(
            onTap: onSend,
            child: Container(
              width: 44, height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF1F6B48),
              ),
              child: const Center(
                child: Icon(Icons.arrow_upward_rounded,
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
    final ok = await p.connectGemini();
    if (!mounted) return;
    if (!ok && _connectTriggeredByUser) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEs
              ? 'No se pudo conectar con Google. En Safari, use Chrome o habilite ventanas emergentes.'
              : 'Não foi possível conectar com o Google. No Safari, use o Chrome ou habilite popups.'),
          backgroundColor: const Color(0xFFB91C1C),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
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
                        ? '${drugsDatabase.length} fármacos · protocolos de urgencias · siempre activo'
                        : '${drugsDatabase.length} fármacos · protocolos de urgência · sempre ativo',
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


