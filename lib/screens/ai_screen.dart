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
  final _queryCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_ChatMsg> _messages = [];
  bool _thinking = false;

  // Prompts rápidos bilíngues: (label_pt, prompt_pt, label_es, prompt_es)
  static const _quickPrompts = [
    // Cardiovascular
    ('IAM / dor torácica',   'Paciente com dor torácica intensa, diaforese e irradiação para braço esquerdo. Suspeita de IAM.',
     'IAM / dolor torácico', 'Paciente con dolor torácico intenso, diaforesis e irradiación al brazo izquierdo. Sospecha de IAM.'),
    ('Choque + hipotensão',  'Paciente em choque com hipotensão, taquicardia e pele fria.',
     'Choque + hipotensión', 'Paciente en choque con hipotensión, taquicardia y piel fría.'),
    ('TPSV / taquicardia',   'Taquicardia paroxística supraventricular, QRS estreito, FC 180.',
     'TPSV / taquicardia',   'Taquicardia paroxística supraventricular, QRS estrecho, FC 180.'),
    ('FA / fibrilação atrial','Fibrilação atrial com resposta ventricular rápida, FC 145 irregular.',
     'FA / fibrilación atrial','Fibrilación auricular con respuesta ventricular rápida, FC 145 irregular.'),
    ('Crise hipertensiva',   'PA 210/120 com cefaleia intensa e confusão mental.',
     'Crisis hipertensiva',  'PA 210/120 con cefalea intensa y confusión mental.'),
    // Emergência
    ('Anafilaxia',           'Reação anafilática aguda após contraste. PA 80/50, broncoespasmo.',
     'Anafilaxia',           'Reacción anafiláctica aguda tras contraste. PA 80/50, broncoespasmo.'),
    ('PCR / parada cardíaca','Parada cardiorrespiratória. Sem pulso. Monitor: fibrilação ventricular.',
     'PCR / parada cardíaca','Parada cardiorrespiratoria. Sin pulso. Monitor: fibrilación ventricular.'),
    ('K\u207a alto / hipercalemia','Hipercalemia grave K+ 7,1 com ondas T apiculadas no ECG.',
     'K\u207a alto / hipercalemia','Hipercalemia grave K+ 7,1 con ondas T picudas en el ECG.'),
    // Respiratório
    ('Sepse / febre',        'Febre alta, hipotensão, taquicardia e suspeita de sepse.',
     'Sepsis / fiebre',      'Fiebre alta, hipotensión, taquicardia y sospecha de sepsis.'),
    ('TEP / embolia',        'Embolia pulmonar com dispneia súbita, PA 85/50, SatO2 85%.',
     'TEP / embolia',        'Embolia pulmonar con disnea súbita, PA 85/50, SatO2 85%.'),
    ('DPOC exacerbação',     'DPOC com piora de dispneia, PaCO2 68, pH 7,28.',
     'EPOC exacerbación',    'EPOC con empeoramiento de disnea, PaCO2 68, pH 7,28.'),
    ('Asma grave',           'Crise de asma grave, silêncio auscultório, SpO2 88%.',
     'Asma grave',           'Crisis de asma grave, silencio auscultatorio, SpO2 88%.'),
    // Neurologia
    ('AVC isquêmico',        'AVC isquêmico agudo, hemiplegia direita, NIHSS 14, 1h45 de evolução.',
     'ACV isquémico',        'ACV isquémico agudo, hemiplejía derecha, NIHSS 14, 1h45 de evolución.'),
    ('Convulsão / status',   'Convulsão há 8 min sem pausa. Estado de mal epiléptico.',
     'Convulsión / status',  'Convulsión de 8 min sin pausa. Estado epiléptico.'),
    ('Delirium / confusão',  'Confusão mental aguda, agitação, rebaixamento. Idoso de 78 anos.',
     'Delirium / confusión', 'Confusión mental aguda, agitación, bradipsiquia. Anciano de 78 años.'),
    // Endocrinologia
    ('Cetoacidose / CAD',    'Cetoacidose diabética. Glicemia 480, pH 7,18, K+ 3,2.',
     'Cetoacidosis / CAD',   'Cetoacidosis diabética. Glucemia 480, pH 7,18, K+ 3,2.'),
    ('Hipoglicemia grave',   'Hipoglicemia grave, Glasgow 8, glicemia 28 mg/dL.',
     'Hipoglucemia grave',   'Hipoglucemia grave, Glasgow 8, glucemia 28 mg/dL.'),
    // Gastro / outros
    ('Hemorragia digestiva', 'Hematêmese, Hb 7,2, instabilidade hemodinâmica.',
     'Hemorragia digestiva', 'Hematemesis, Hb 7,2, inestabilidad hemodinámica.'),
    ('Meningite',            'Febre, cefaleia em trovoada, rigidez de nuca, petéquias.',
     'Meningitis',           'Fiebre, cefalea en trueno, rigidez de nuca, petequias.'),
    ('Insuf. cardíaca',      'IC descompensada, ortopneia, SatO2 91%, crepitações bibasais.',
     'Insuf. cardíaca',      'IC descompensada, ortopnea, SatO2 91%, crepitantes bibasales.'),
  ];

  @override
  void dispose() {
    _queryCtrl.dispose();
    _scrollCtrl.dispose();
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
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add(_ChatMsg(role: 'user', text: text.trim()));
      _thinking = true;
    });
    _queryCtrl.clear();
    _scrollDown();

    // Simulate slight delay for UX
    await Future.delayed(const Duration(milliseconds: 600));

    final answer = p.buildAIAnswer(text.trim());
    setState(() {
      _messages.add(_ChatMsg(role: 'ai', text: answer));
      _thinking = false;
    });
    _scrollDown();
  }

  void _copyMsg(String text) {
    Clipboard.setData(ClipboardData(text: text));
    final p = context.read<AppProvider>();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(p.t('copied')), duration: const Duration(seconds: 1)),
    );
  }

  void _clearChat() => setState(() => _messages.clear());

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final dark = p.darkMode;
    final bubbleBg = dark ? const Color(0xFF0E1A14) : Colors.white;

    return Column(children: [
      // Header
      Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: PremiumCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: Colors.white.withValues(alpha: 0.1)),
              child: const Icon(Icons.psychology_rounded, color: Color(0xFFFFE8A6), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.t('ai'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
              Text(p.t('ai_subtitle'),
                style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.6), fontWeight: FontWeight.w600)),
            ])),
            if (_messages.isNotEmpty)
              GestureDetector(
                onTap: _clearChat,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.white.withValues(alpha: 0.1), border: Border.all(color: Colors.white.withValues(alpha: 0.2))),
                  child: Text(p.t('clear'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFFFFE8A6))),
                ),
              ),
          ]),
        ),
      ),

      // Chat messages or empty state
      Expanded(
        child: _messages.isEmpty ? _emptyState(p) : ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          itemCount: _messages.length + (_thinking ? 1 : 0),
          itemBuilder: (context, i) {
            if (_thinking && i == _messages.length) {
              return _ThinkingBubble(dark: dark, bubbleBg: bubbleBg);
            }
            final msg = _messages[i];
            return msg.role == 'user'
              ? _UserBubble(text: msg.text)
              : _AiBubble(text: msg.text, dark: dark, bubbleBg: bubbleBg, onCopy: () => _copyMsg(msg.text));
          },
        ),
      ),

      // Input area
      _InputBar(
        ctrl: _queryCtrl,
        dark: dark,
        onSend: (t) => _send(t, p),
        label: p.t('send'),
        hint: p.t('ai_placeholder'),
      ),
    ]);
  }

  Widget _emptyState(AppProvider p) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(children: [
        // Safety disclaimer
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xFFFFF8E7),
            border: Border.all(color: const Color(0xFFFFE0A0)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('⚠️', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
            Expanded(child: Text(
              p.t('ai_disclaimer'),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF7A5F00), height: 1.45),
            )),
          ]),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            p.t('quick_suggestions'),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: Color(0xFF888888)),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _quickPrompts.map((q) {
            final isEs = p.lang == 'es';
            final label  = isEs ? q.$3 : q.$1;
            final prompt = isEs ? q.$4 : q.$2;
            return GestureDetector(
              onTap: () {
                _queryCtrl.text = prompt;
                final prov = context.read<AppProvider>();
                _send(prompt, prov);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: const Color(0xFF07110d),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFFFE8A6))),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: kBorder), color: kCream),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.t('ai_provides').toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: kGold)),
            const SizedBox(height: 10),
            ...[
              p.t('ai_feat_dx'),
              p.t('ai_feat_protocol'),
              p.t('ai_feat_doses'),
              p.t('ai_feat_flags'),
              p.t('ai_feat_exams'),
            ].map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(s, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kDark, height: 1.4)),
            )),
          ]),
        ),
      ]),
    );
  }
}

class _ChatMsg {
  final String role;
  final String text;
  const _ChatMsg({required this.role, required this.text});
}

class _UserBubble extends StatelessWidget {
  final String text;
  const _UserBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 40),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(4),
            ),
            gradient: const LinearGradient(
              colors: [Color(0xFF07110d), Color(0xFF075f45)],
            ),
          ),
          child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white, height: 1.45)),
        ),
      ),
    );
  }
}

class _AiBubble extends StatelessWidget {
  final String text;
  final bool dark;
  final Color bubbleBg;
  final VoidCallback onCopy;
  const _AiBubble({required this.text, required this.dark, required this.bubbleBg, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    final textColor = dark ? Colors.white : kDark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 20),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 32, height: 32,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF07110d), Color(0xFF075f45)]),
            shape: BoxShape.circle,
          ),
          child: const Center(child: Text('AI', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFFFFE8A6)))),
        ),
        const SizedBox(width: 8),
        Expanded(child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
            color: bubbleBg,
            border: Border.all(color: dark ? const Color(0xFF1A2E20) : kBorder),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildText(text, textColor),
            const SizedBox(height: 10),
            Row(children: [
              const Spacer(),
              GestureDetector(
                onTap: onCopy,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: const Color(0xFF07110d)),
                  child: Row(children: [
                    const Icon(Icons.copy_rounded, size: 11, color: Color(0xFFFFE8A6)),
                    const SizedBox(width: 4),
                    Builder(builder: (ctx) { final prov = ctx.read<AppProvider>(); return Text(prov.t('copy'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFFFFE8A6))); }),
                  ]),
                ),
              ),
            ]),
          ]),
        )),
      ]),
    );
  }

  Widget _buildText(String text, Color textColor) {
    final lines = text.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        if (line.startsWith('🧠') || line.startsWith('##')) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(line, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: textColor, height: 1.3)),
          );
        } else if (line.startsWith('•') || line.startsWith('-')) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(line, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor, height: 1.45)),
          );
        } else if (line.trim().isEmpty) {
          return const SizedBox(height: 6);
        } else {
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(line, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor, height: 1.45)),
          );
        }
      }).toList(),
    );
  }
}

class _ThinkingBubble extends StatefulWidget {
  final bool dark;
  final Color bubbleBg;
  const _ThinkingBubble({required this.dark, required this.bubbleBg});

  @override
  State<_ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<_ThinkingBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _anim = Tween(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF07110d), Color(0xFF075f45)]),
            shape: BoxShape.circle,
          ),
          child: const Center(child: Text('AI', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFFFFE8A6)))),
        ),
        const SizedBox(width: 8),
        FadeTransition(
          opacity: _anim,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: widget.bubbleBg,
              border: Border.all(color: widget.dark ? const Color(0xFF1A2E20) : kBorder),
            ),
            child: Row(children: [
              for (int i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Container(width: 7, height: 7, decoration: const BoxDecoration(color: kGold, shape: BoxShape.circle)),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController ctrl;
  final bool dark;
  final ValueChanged<String> onSend;
  final String label;
  final String hint;
  const _InputBar({required this.ctrl, required this.dark, required this.onSend, required this.label, required this.hint});

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF0E1A14) : Colors.white;
    final border = dark ? const Color(0xFF1A2E20) : const Color(0xFFE8E1D2);
    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: border)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -4))],
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      child: SafeArea(
        top: false,
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: ctrl,
              maxLines: 3,
              minLines: 1,
              textInputAction: TextInputAction.newline,
              spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
              autocorrect: false,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: dark ? Colors.white : kDark),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: dark ? Colors.white38 : Colors.grey[400], fontWeight: FontWeight.w500),
                filled: true,
                fillColor: dark ? const Color(0xFF0A1510) : const Color(0xFFFAF8F4),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kGold, width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                isDense: true,
              ),
              onSubmitted: (t) {
                if (t.trim().isNotEmpty) onSend(t);
              },
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              if (ctrl.text.trim().isNotEmpty) onSend(ctrl.text);
            },
            child: Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF07110d), Color(0xFF075f45)],
                ),
                boxShadow: [BoxShadow(color: const Color(0xFF07110d).withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: const Center(child: Icon(Icons.send_rounded, color: Color(0xFFFFE8A6), size: 20)),
            ),
          ),
        ]),
      ),
    );
  }
}
