import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/ai_service.dart';


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
  bool _thinking  = false;
  bool _hasFocus  = false;
  bool _aiError   = false; // true quando a última resposta foi um erro de chave

  // Sugestões ficam visíveis apenas no estado vazio + sem foco
  bool get _showSuggestions => _messages.isEmpty && !_hasFocus;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) setState(() => _hasFocus = _focusNode.hasFocus);
    });
    _queryCtrl.addListener(() {
      // Esconde sugestões assim que o usuário começa a digitar
      if (mounted && _queryCtrl.text.isNotEmpty && _hasFocus) {
        setState(() {});
      }
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
    final isKeyError = answer.startsWith('❌') && answer.contains('API');
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
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      ),
    );
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _aiError = false;
    });
    _queryCtrl.clear();
    _focusNode.unfocus();
    context.read<AppProvider>().clearAiHistory();
  }

  // ── Sheet de configuração da API key ────────────────────────────────────
  void _openAiSettings() {
    final p = context.read<AppProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AiSettingsSheet(
        initialKey:  p.openAiKey,
        userEmail:   p.userEmail,
        userName:    p.userName,
        lang:        p.lang,
        dark:        p.darkMode,
        onSave: (key) async {
          await context.read<AppProvider>().setAiKey(key);
        },
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
    final chatBg = dark ? const Color(0xFF0B1410) : const Color(0xFFECE5DD);

    return Column(children: [
      // ── Header fino estilo WhatsApp ──────────────────────────────────────
      _WaHeader(
        dark: dark,
        hasMessages: _messages.isNotEmpty,
        onClear: _clearChat,
        onSettings: _openAiSettings,
        lang: p.lang,
        hasRealAi: p.hasAiKey,
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
  const _WaHeader({
    required this.dark,
    required this.hasMessages,
    required this.onClear,
    required this.onSettings,
    required this.lang,
    required this.hasRealAi,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF07110d), Color(0xFF123326), Color(0xFF075f45)],
        ),
      ),
      child: SafeArea(
        bottom: false,
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
                  Container(
                    width: 6, height: 6,
                    margin: const EdgeInsets.only(right: 5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasRealAi
                          ? const Color(0xFF4ADE80)   // verde = IA real ativa
                          : Colors.white.withValues(alpha: 0.35), // cinza = modo local
                    ),
                  ),
                  Text(
                    hasRealAi
                        ? (lang == 'es' ? 'GPT-4o mini activo' : 'GPT-4o mini ativo')
                        : (lang == 'es' ? 'Modo local • sin clave API' : 'Modo local • sem chave API'),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.55),
                      fontWeight: FontWeight.w500,
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
                  hasRealAi ? Icons.key_rounded : Icons.key_off_rounded,
                  size: 18,
                  color: hasRealAi
                      ? const Color(0xFF4ADE80)
                      : Colors.white.withValues(alpha: 0.6)),
              ),
            ),
            const SizedBox(width: 6),
            // Limpar conversa
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
            if (!hasMessages) ...[  
              // Botão menu
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
            ],
          ]),
        ),
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
        if (line.startsWith('🧠') || line.startsWith('##')) {
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
                          color: const Color(0xFF075f45).withValues(alpha: 0.6),
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
        ? const Color(0xFF075f45)
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
                color: Color(0xFF075f45),
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
// Banner de erro de chave — aparece abaixo do header quando chave inválida
// ─────────────────────────────────────────────────────────────────────────────
class _AiErrorBanner extends StatelessWidget {
  final bool dark;
  final String lang;
  final VoidCallback onFix;
  const _AiErrorBanner({required this.dark, required this.lang, required this.onFix});

  @override
  Widget build(BuildContext context) {
    final isEs = lang == 'es';
    return GestureDetector(
      onTap: onFix,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: const Color(0xFFB91C1C).withValues(alpha: 0.12),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isEs
                  ? 'Clave API inválida — toca para configurar'
                  : 'Chave API inválida — toque para configurar',
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
// Sheet de configuração da API key — conta vinculada ao usuário logado
// ─────────────────────────────────────────────────────────────────────────────
class _AiSettingsSheet extends StatefulWidget {
  final String initialKey;
  final String userEmail;   // e-mail da conta Firebase (já logada)
  final String userName;    // nome do usuário (já logado)
  final String lang;
  final bool dark;
  final Future<void> Function(String key) onSave;
  const _AiSettingsSheet({
    required this.initialKey,
    required this.userEmail,
    required this.userName,
    required this.lang,
    required this.dark,
    required this.onSave,
  });

  @override
  State<_AiSettingsSheet> createState() => _AiSettingsSheetState();
}

class _AiSettingsSheetState extends State<_AiSettingsSheet> {
  late final TextEditingController _ctrl;
  bool _obscure    = true;
  bool _validating = false;
  bool _saved      = false;
  bool _showField  = false; // começa escondido se já tem chave
  String? _error;

  bool get _hasKey   => widget.initialKey.isNotEmpty;
  bool get _isEs     => widget.lang == 'es';

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialKey);
    // Se ainda não tem chave, mostra o campo direto
    _showField = !_hasKey;
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    final key = _ctrl.text.trim();
    if (key.isEmpty) {
      await widget.onSave('');
      if (mounted) {
        setState(() => _saved = true);
        await Future.delayed(const Duration(milliseconds: 700));
        if (mounted) Navigator.pop(context);
      }
      return;
    }
    setState(() { _validating = true; _error = null; });
    final valid = await AiService.validateKey(key);
    if (!mounted) return;
    if (valid) {
      await widget.onSave(key);
      setState(() { _validating = false; _saved = true; });
      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) Navigator.pop(context);
    } else {
      setState(() {
        _validating = false;
        _error = _isEs
            ? 'Clave inválida o sin conexión. Verifica y vuelve a intentar.'
            : 'Chave inválida ou sem conexão. Verifique e tente novamente.';
      });
    }
  }

  Future<void> _disconnect() async {
    await widget.onSave('');
    if (mounted) Navigator.pop(context);
  }

  void _showInstructions() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_isEs
          ? 'Ve a platform.openai.com → API keys → Create new secret key'
          : 'Acesse platform.openai.com → API keys → Create new secret key'),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      duration: const Duration(seconds: 6),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final dark   = widget.dark;
    final bg     = dark ? const Color(0xFF0F1A14) : Colors.white;
    final cardBg = dark ? const Color(0xFF1A2820) : const Color(0xFFF5F7F5);
    final divCol = dark ? Colors.white12 : Colors.black.withValues(alpha: 0.08);
    final text   = dark ? Colors.white : const Color(0xFF1A1A1A);
    final sub    = dark ? Colors.white54 : Colors.black54;
    final green  = const Color(0xFF075f45);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 28),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [

          // ── Drag handle ──────────────────────────────────────────────────
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: dark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2)),
          ),

          // ── Card de conta vinculada ──────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _hasKey
                    ? [const Color(0xFF064E35), const Color(0xFF075f45)]
                    : [
                        dark ? const Color(0xFF1A2820) : const Color(0xFFF0F4F1),
                        dark ? const Color(0xFF1E2E22) : const Color(0xFFE8F0EA),
                      ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Avatar + info da conta
              Row(children: [
                // Avatar com inicial do nome
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _hasKey
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
                        fontSize: 18, fontWeight: FontWeight.w800,
                        color: _hasKey ? Colors.white : green),
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
                          color: _hasKey ? Colors.white : text),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(
                      widget.userEmail.isNotEmpty
                          ? widget.userEmail
                          : (_isEs ? 'Sin cuenta' : 'Sem conta'),
                      style: TextStyle(
                        fontSize: 12,
                        color: _hasKey
                            ? Colors.white.withValues(alpha: 0.7)
                            : sub),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                )),
                // Badge de status
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: _hasKey
                        ? Colors.white.withValues(alpha: 0.15)
                        : green.withValues(alpha: 0.1),
                    border: Border.all(
                      color: _hasKey
                          ? Colors.white.withValues(alpha: 0.3)
                          : green.withValues(alpha: 0.25)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 6, height: 6,
                      margin: const EdgeInsets.only(right: 5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _hasKey
                            ? const Color(0xFF4ADE80)
                            : (dark ? Colors.white38 : Colors.black26),
                      ),
                    ),
                    Text(
                      _hasKey
                          ? (_isEs ? 'IA activa' : 'IA ativa')
                          : (_isEs ? 'Sin clave' : 'Sem chave'),
                      style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: _hasKey ? Colors.white : sub),
                    ),
                  ]),
                ),
              ]),

              if (_hasKey) ...[
                const SizedBox(height: 14),
                Divider(color: Colors.white.withValues(alpha: 0.15), height: 1),
                const SizedBox(height: 12),
                // Chave mascarada
                Row(children: [
                  Icon(Icons.key_rounded, size: 13,
                    color: Colors.white.withValues(alpha: 0.6)),
                  const SizedBox(width: 6),
                  Text(
                    _isEs ? 'Clave OpenAI vinculada' : 'Chave OpenAI vinculada',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.6))),
                  const Spacer(),
                  // Últimos 4 chars da chave
                  Text(
                    '••••${widget.initialKey.length > 4 ? widget.initialKey.substring(widget.initialKey.length - 4) : "••••"}',
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.8),
                      fontFamily: 'monospace')),
                ]),
                const SizedBox(height: 4),
                // Modelo ativo
                Row(children: [
                  Icon(Icons.psychology_rounded, size: 13,
                    color: Colors.white.withValues(alpha: 0.6)),
                  const SizedBox(width: 6),
                  Text('GPT-4o mini',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.6))),
                  const Spacer(),
                  Text(
                    _isEs ? 'Sincronizado con tu cuenta' : 'Sync com sua conta',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.5))),
                ]),
              ],
            ]),
          ),

          const SizedBox(height: 16),

          // ── Se tem chave: ações de gerenciamento ─────────────────────────
          if (_hasKey && !_showField) ...[
            // Trocar chave
            _ActionTile(
              dark: dark,
              icon: Icons.edit_rounded,
              iconColor: green,
              label: _isEs ? 'Cambiar clave API' : 'Trocar chave API',
              sub: _isEs
                  ? 'Vincular una nueva clave a tu cuenta'
                  : 'Vincular uma nova chave à sua conta',
              onTap: () => setState(() { _showField = true; _ctrl.clear(); }),
            ),
            const SizedBox(height: 8),
            // Desconectar
            _ActionTile(
              dark: dark,
              icon: Icons.link_off_rounded,
              iconColor: const Color(0xFFEF4444),
              label: _isEs ? 'Desconectar IA' : 'Desconectar IA',
              sub: _isEs
                  ? 'Volver al modo local (reglas clínicas integradas)'
                  : 'Voltar ao modo local (regras clínicas integradas)',
              onTap: _disconnect,
              danger: true,
            ),
          ],

          // ── Campo de chave (primeira vez ou ao trocar) ───────────────────
          if (_showField) ...[
            // Info rápida
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: divCol)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.info_outline_rounded, size: 13, color: Color(0xFF075f45)),
                  const SizedBox(width: 6),
                  Text(
                    _isEs ? 'Clave vinculada a tu cuenta' : 'Chave vinculada à sua conta',
                    style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: Color(0xFF075f45))),
                ]),
                const SizedBox(height: 5),
                Text(
                  _isEs
                      ? 'La clave se guarda en tu perfil de Firebase — disponible en todos tus dispositivos automáticamente.'
                      : 'A chave fica salva no seu perfil Firebase — disponível em todos os dispositivos automaticamente.',
                  style: TextStyle(fontSize: 11, color: sub, height: 1.55)),
              ]),
            ),
            const SizedBox(height: 12),

            // Campo
            TextField(
              controller: _ctrl,
              obscureText: _obscure,
              autofocus: true,
              style: TextStyle(
                fontSize: 13, color: text, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: 'sk-...',
                hintStyle: TextStyle(
                  color: sub, fontFamily: 'monospace', fontSize: 13),
                labelText: _isEs
                    ? 'Clave OpenAI (sk-...)'
                    : 'Chave OpenAI (sk-...)',
                labelStyle: TextStyle(color: sub, fontSize: 13),
                filled: true, fillColor: cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: green, width: 1.5)),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: 18, color: sub),
                  onPressed: () => setState(() => _obscure = !_obscure)),
                errorText: _error,
                errorMaxLines: 2,
              ),
            ),
            const SizedBox(height: 10),

            // Link para obter chave
            GestureDetector(
              onTap: _showInstructions,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.open_in_new_rounded, size: 12, color: green),
                const SizedBox(width: 4),
                Text(
                  _isEs
                      ? 'Obtener clave en platform.openai.com'
                      : 'Obter chave em platform.openai.com',
                  style: TextStyle(
                    fontSize: 11, color: green,
                    fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(height: 16),

            // Botões
            Row(children: [
              if (_hasKey) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _validating
                        ? null
                        : () => setState(() { _showField = false; _error = null; }),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: sub,
                      side: BorderSide(color: dark ? Colors.white24 : Colors.black12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 13)),
                    child: Text(_isEs ? 'Cancelar' : 'Cancelar',
                      style: const TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _validating ? null : _save,
                  icon: _saved
                      ? const Icon(Icons.check_rounded, size: 16)
                      : _validating
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.link_rounded, size: 16),
                  label: Text(
                    _saved
                        ? (_isEs ? '¡Conectado!' : 'Conectado!')
                        : _validating
                            ? (_isEs ? 'Validando...' : 'Validando...')
                            : (_isEs ? 'Conectar IA' : 'Conectar IA'),
                    style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _saved
                        ? const Color(0xFF16A34A)
                        : green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tile de ação reutilizável dentro do settings sheet
// ─────────────────────────────────────────────────────────────────────────────
class _ActionTile extends StatelessWidget {
  final bool dark;
  final IconData icon;
  final Color iconColor;
  final String label;
  final String sub;
  final VoidCallback onTap;
  final bool danger;
  const _ActionTile({
    required this.dark,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.sub,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg   = dark ? const Color(0xFF1A2820) : const Color(0xFFF5F7F5);
    final text = dark ? Colors.white : const Color(0xFF1A1A1A);
    final subC = dark ? Colors.white54 : Colors.black45;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: danger
                ? const Color(0xFFEF4444).withValues(alpha: 0.25)
                : (dark ? Colors.white10 : Colors.black.withValues(alpha: 0.08))),
        ),
        child: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withValues(alpha: 0.12)),
            child: Center(child: Icon(icon, size: 17, color: iconColor)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600,
                  color: danger ? const Color(0xFFEF4444) : text)),
              Text(sub,
                style: TextStyle(fontSize: 11, color: subC)),
            ],
          )),
          Icon(Icons.chevron_right_rounded, size: 18,
            color: danger
                ? const Color(0xFFEF4444).withValues(alpha: 0.6)
                : subC),
        ]),
      ),
    );
  }
}
