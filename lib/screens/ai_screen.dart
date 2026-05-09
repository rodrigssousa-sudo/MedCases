import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';


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
    if (trimmed.isEmpty) return;
    _focusNode.unfocus();
    setState(() {
      _messages.add(_ChatMsg(role: 'user', text: trimmed));
      _thinking = true;
    });
    _queryCtrl.clear();
    _scrollDown();
    await Future.delayed(const Duration(milliseconds: 600));
    final answer = p.buildAIAnswer(trimmed);
    setState(() {
      _messages.add(_ChatMsg(role: 'ai', text: answer));
      _thinking = false;
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
    setState(() => _messages.clear());
    _queryCtrl.clear();
    _focusNode.unfocus();
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
        lang: p.lang,
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
  final String lang;
  const _WaHeader({
    required this.dark,
    required this.hasMessages,
    required this.onClear,
    required this.lang,
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
                Text(
                  lang == 'es'
                    ? 'Razonamiento clínico • apoyo educativo'
                    : 'Raciocínio clínico • apoio educacional',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w500,
                  )),
              ],
            )),
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
