import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/common_widgets.dart';

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
  int  _selGroup  = 0;

  static const _groups = [
    (
      'Cardio',
      [
        ('IAM / dor torácica',   'IAM / dolor torácico',
         'Paciente com dor torácica intensa, diaforese e irradiação para braço esquerdo. Suspeita de IAM.',
         'Paciente con dolor torácico intenso, diaforesis e irradiación al brazo izquierdo. Sospecha de IAM.'),
        ('Choque + hipotensão',  'Choque + hipotensión',
         'Paciente em choque com hipotensão, taquicardia e pele fria.',
         'Paciente en choque con hipotensión, taquicardia y piel fría.'),
        ('TPSV / taquicardia',   'TPSV / taquicardia',
         'Taquicardia paroxística supraventricular, QRS estreito, FC 180.',
         'Taquicardia paroxística supraventricular, QRS estrecho, FC 180.'),
        ('FA / fibrilação',      'FA / fibrilación',
         'Fibrilação atrial com resposta ventricular rápida, FC 145 irregular.',
         'Fibrilación auricular con respuesta ventricular rápida, FC 145 irregular.'),
        ('Crise hipertensiva',   'Crisis hipertensiva',
         'PA 210/120 com cefaleia intensa e confusão mental.',
         'PA 210/120 con cefalea intensa y confusión mental.'),
        ('Insuf. cardíaca',      'Insuf. cardíaca',
         'IC descompensada, ortopneia, SatO2 91%, crepitações bibasais.',
         'IC descompensada, ortopnea, SatO2 91%, crepitantes bibasales.'),
      ]
    ),
    (
      'Emergência',
      [
        ('Anafilaxia',           'Anafilaxia',
         'Reação anafilática aguda após contraste. PA 80/50, broncoespasmo.',
         'Reacción anafiláctica aguda tras contraste. PA 80/50, broncoespasmo.'),
        ('PCR / parada',         'PCR / parada',
         'Parada cardiorrespiratória. Sem pulso. Monitor: fibrilação ventricular.',
         'Parada cardiorrespiratoria. Sin pulso. Monitor: fibrilación ventricular.'),
        ('K⁺ alto',              'K⁺ alto',
         'Hipercalemia grave K+ 7,1 com ondas T apiculadas no ECG.',
         'Hipercalemia grave K+ 7,1 con ondas T picudas en el ECG.'),
        ('Sepse / febre',        'Sepsis / fiebre',
         'Febre alta, hipotensão, taquicardia e suspeita de sepse.',
         'Fiebre alta, hipotensión, taquicardia y sospecha de sepsis.'),
        ('Hemorragia digestiva', 'Hemorragia digestiva',
         'Hematêmese, Hb 7,2, instabilidade hemodinâmica.',
         'Hematemesis, Hb 7,2, inestabilidad hemodinámica.'),
      ]
    ),
    (
      'Resp.',
      [
        ('TEP / embolia',     'TEP / embolia',
         'Embolia pulmonar com dispneia súbita, PA 85/50, SatO2 85%.',
         'Embolia pulmonar con disnea súbita, PA 85/50, SatO2 85%.'),
        ('DPOC exacerbação',  'EPOC exacerbación',
         'DPOC com piora de dispneia, PaCO2 68, pH 7,28.',
         'EPOC con empeoramiento de disnea, PaCO2 68, pH 7,28.'),
        ('Asma grave',        'Asma grave',
         'Crise de asma grave, silêncio auscultório, SpO2 88%.',
         'Crisis de asma grave, silencio auscultatorio, SpO2 88%.'),
      ]
    ),
    (
      'Neuro',
      [
        ('AVC isquêmico',      'ACV isquémico',
         'AVC isquêmico agudo, hemiplegia direita, NIHSS 14, 1h45 de evolução.',
         'ACV isquémico agudo, hemiplejía derecha, NIHSS 14, 1h45 de evolución.'),
        ('Convulsão / status', 'Convulsión / status',
         'Convulsão há 8 min sem pausa. Estado de mal epiléptico.',
         'Convulsión de 8 min sin pausa. Estado epiléptico.'),
        ('Delirium',           'Delirium',
         'Confusão mental aguda, agitação, rebaixamento. Idoso de 78 anos.',
         'Confusión mental aguda, agitación. Anciano de 78 años.'),
        ('Meningite',          'Meningitis',
         'Febre, cefaleia em trovoada, rigidez de nuca, petéquias.',
         'Fiebre, cefalea en trueno, rigidez de nuca, petequias.'),
      ]
    ),
    (
      'Endócrino',
      [
        ('Cetoacidose',       'Cetoacidosis',
         'Cetoacidose diabética. Glicemia 480, pH 7,18, K+ 3,2.',
         'Cetoacidosis diabética. Glucemia 480, pH 7,18, K+ 3,2.'),
        ('Hipoglicemia',      'Hipoglucemia',
         'Hipoglicemia grave, Glasgow 8, glicemia 28 mg/dL.',
         'Hipoglucemia grave, Glasgow 8, glucemia 28 mg/dL.'),
      ]
    ),
  ];

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _hasFocus = _focusNode.hasFocus);
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
      ),
    );
  }

  void _clearChat() {
    setState(() => _messages.clear());
    _focusNode.unfocus();
  }

  // Insere chip no campo (sem enviar)
  void _insertChip(String prompt) {
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
    final isEs = p.lang == 'es';
    final bg   = dark ? const Color(0xFF070F0A) : const Color(0xFFF5F3EE);

    return Column(children: [
      // ── Header ──────────────────────────────────────────────────────────
      PremiumCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.white.withValues(alpha: 0.12),
            ),
            child: const Center(
              child: Icon(Icons.psychology_rounded, color: Color(0xFFFFE8A6), size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.t('ai'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
              Text(p.t('ai_subtitle'),
                style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.55), fontWeight: FontWeight.w500)),
            ],
          )),
          if (_messages.isNotEmpty)
            GestureDetector(
              onTap: _clearChat,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white.withValues(alpha: 0.1),
                ),
                child: Text(p.t('clear'),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFFFE8A6))),
              ),
            ),
        ]),
      ),

      // ── Corpo principal ─────────────────────────────────────────────────
      Expanded(
        child: Container(
          color: bg,
          child: _messages.isEmpty
              ? _buildEmptyWithInput(p, dark, isEs)
              : _buildChatWithInput(p, dark, isEs),
        ),
      ),
    ]);
  }

  // ── Estado vazio: input NO TOPO + sugestões embaixo ──────────────────────
  Widget _buildEmptyWithInput(AppProvider p, bool dark, bool isEs) {
    final border   = dark ? const Color(0xFF1A2820) : const Color(0xFFDDD8CE);
    final fieldBg  = dark ? const Color(0xFF0D1A12) : Colors.white;
    final textCol  = dark ? Colors.white : const Color(0xFF1A1A1A);
    final hintCol  = dark ? Colors.white30 : Colors.black26;

    return Column(children: [
      // ── Campo de texto FIXO NO TOPO ──────────────────────────────────
      Container(
        color: dark ? const Color(0xFF0A150E) : Colors.white,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: fieldBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _hasFocus ? const Color(0xFF0D5C3A) : border,
                  width: _hasFocus ? 1.5 : 1.0,
                ),
              ),
              child: TextField(
                controller: _queryCtrl,
                focusNode: _focusNode,
                maxLines: 4,
                minLines: 2,
                textInputAction: TextInputAction.newline,
                spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
                autocorrect: false,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: textCol,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  hintText: p.t('ai_placeholder'),
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: hintCol,
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Botão enviar
          GestureDetector(
            onTap: () {
              final p2 = context.read<AppProvider>();
              _send(_queryCtrl.text, p2);
            },
            child: Container(
              width: 44, height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0B2318), Color(0xFF0D5C3A)],
                ),
              ),
              child: const Center(
                child: Icon(Icons.arrow_upward_rounded, color: Color(0xFFFFE8A6), size: 18),
              ),
            ),
          ),
        ]),
      ),

      // Divisor
      Divider(height: 1, color: dark ? const Color(0xFF1A2820) : const Color(0xFFE5E0D8)),

      // ── Sugestões abaixo do campo ────────────────────────────────────
      Expanded(
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 14),

            // Label sugestões
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                isEs ? 'SUGERENCIAS RÁPIDAS' : 'SUGESTÕES RÁPIDAS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: dark ? Colors.white30 : Colors.black38,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Abas de categoria
            SizedBox(
              height: 34,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _groups.length,
                itemBuilder: (context, i) {
                  final sel = i == _selGroup;
                  return GestureDetector(
                    onTap: () => setState(() => _selGroup = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: sel
                            ? const Color(0xFF0E3624)
                            : (dark ? const Color(0xFF1A2820) : Colors.white),
                        border: Border.all(
                          color: sel
                              ? const Color(0xFF0E3624)
                              : (dark ? const Color(0xFF2A3830) : const Color(0xFFDDD8CE)),
                        ),
                      ),
                      child: Text(
                        _groups[i].$1,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: sel
                              ? const Color(0xFFFFE8A6)
                              : (dark ? Colors.white54 : Colors.black54),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 10),

            // Chips do grupo selecionado
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _groups[_selGroup].$2.map((item) {
                  final label  = isEs ? item.$2 : item.$1;
                  final prompt = isEs ? item.$4 : item.$3;
                  return GestureDetector(
                    onTap: () => _insertChip(prompt),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        color: dark ? const Color(0xFF1A2820) : Colors.white,
                        border: Border.all(
                          color: dark ? const Color(0xFF2A3830) : const Color(0xFFDDD8CE),
                        ),
                        boxShadow: dark ? null : [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1)),
                        ],
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: dark ? Colors.white70 : const Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.north_east_rounded,
                          size: 12,
                          color: dark ? Colors.white24 : Colors.black26),
                      ]),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 20),
          ]),
        ),
      ),
    ]);
  }

  // ── Chat com input fixo no rodapé ────────────────────────────────────────
  Widget _buildChatWithInput(AppProvider p, bool dark, bool isEs) {
    final border  = dark ? const Color(0xFF1A2820) : const Color(0xFFE5E0D8);
    final fieldBg = dark ? const Color(0xFF0D1A12) : Colors.white;
    final barBg   = dark ? const Color(0xFF0A150E) : Colors.white;
    final textCol = dark ? Colors.white : const Color(0xFF1A1A1A);
    final hintCol = dark ? Colors.white30 : Colors.black26;

    return Column(children: [
      // Lista de mensagens
      Expanded(
        child: ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          itemCount: _messages.length + (_thinking ? 1 : 0),
          itemBuilder: (context, i) {
            if (_thinking && i == _messages.length) {
              return _ThinkingBubble(dark: dark);
            }
            final msg = _messages[i];
            return msg.role == 'user'
                ? _UserBubble(text: msg.text)
                : _AiBubble(
                    text: msg.text,
                    dark: dark,
                    onCopy: () => _copyMsg(msg.text),
                  );
          },
        ),
      ),

      // Barra de input fixa no rodapé
      Container(
        decoration: BoxDecoration(
          color: barBg,
          border: Border(top: BorderSide(color: border)),
        ),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: SafeArea(
          top: false,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: fieldBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _hasFocus ? const Color(0xFF0D5C3A) : border,
                    width: _hasFocus ? 1.5 : 1.0,
                  ),
                ),
                child: TextField(
                  controller: _queryCtrl,
                  focusNode: _focusNode,
                  maxLines: 4,
                  minLines: 1,
                  textInputAction: TextInputAction.newline,
                  spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
                  autocorrect: false,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: textCol,
                    height: 1.5,
                  ),
                  decoration: InputDecoration(
                    hintText: p.t('ai_placeholder'),
                    hintStyle: TextStyle(fontSize: 13, color: hintCol, fontWeight: FontWeight.w400),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _send(_queryCtrl.text, p),
              child: Container(
                width: 42, height: 42,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0B2318), Color(0xFF0D5C3A)],
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.arrow_upward_rounded, color: Color(0xFFFFE8A6), size: 18),
                ),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _ChatMsg {
  final String role;
  final String text;
  const _ChatMsg({required this.role, required this.text});
}

// ─────────────────────────────────────────────────────────────────────────────
class _UserBubble extends StatelessWidget {
  final String text;
  const _UserBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 48),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(4),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0B2318), Color(0xFF0D5C3A)],
            ),
          ),
          child: Text(text,
            style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w500,
              color: Colors.white, height: 1.5)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _AiBubble extends StatelessWidget {
  final String text;
  final bool dark;
  final VoidCallback onCopy;
  const _AiBubble({required this.text, required this.dark, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    final bubbleBg  = dark ? const Color(0xFF111D16) : Colors.white;
    final textColor = dark ? Colors.white : const Color(0xFF1A1A1A);
    final borderCol = dark ? const Color(0xFF1E2E23) : const Color(0xFFE8E3DA);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14, right: 24),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 28, height: 28,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF0B2318), Color(0xFF0D5C3A)]),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text('AI',
              style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Color(0xFFFFE8A6))),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
            color: bubbleBg,
            border: Border.all(color: borderCol),
            boxShadow: dark ? null : [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildFormattedText(text, textColor),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: onCopy,
                child: Icon(Icons.copy_rounded, size: 15,
                  color: dark ? Colors.white24 : Colors.black26),
              ),
            ),
          ]),
        )),
      ]),
    );
  }

  Widget _buildFormattedText(String text, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: text.split('\n').map((line) {
        if (line.startsWith('🧠') || line.startsWith('##')) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6, top: 2),
            child: Text(line,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textColor, height: 1.35)),
          );
        } else if (line.startsWith('•') || line.startsWith('-')) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(line,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textColor, height: 1.5)),
          );
        } else if (line.trim().isEmpty) {
          return const SizedBox(height: 5);
        } else {
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(line,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textColor, height: 1.5)),
          );
        }
      }).toList(),
    );
  }
}

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
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.25, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final bg = widget.dark ? const Color(0xFF111D16) : Colors.white;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Container(
          width: 28, height: 28,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF0B2318), Color(0xFF0D5C3A)]),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text('AI',
              style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Color(0xFFFFE8A6))),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: bg,
            border: Border.all(
              color: widget.dark ? const Color(0xFF1E2E23) : const Color(0xFFE8E3DA)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) => Padding(
              padding: EdgeInsets.only(left: i > 0 ? 5 : 0),
              child: FadeTransition(
                opacity: _anim,
                child: Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D5C3A).withValues(alpha: 0.6 + i * 0.15),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ))),
        ),
      ]),
    );
  }
}
