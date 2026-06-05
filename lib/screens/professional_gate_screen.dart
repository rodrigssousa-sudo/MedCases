// ── ProfessionalDeclarationGate ───────────────────────────────────────────────
// Tela de blindagem jurídica: exibida uma única vez por usuário após o login.
// Persiste o aceite em SharedPreferences com a chave 'has_declared_professional'.
// Suporta PT (padrão) e ES via Localizations.localeOf(context).languageCode.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/app_provider.dart';
import '../services/auth_service.dart';

// ── Chave de persistência ──────────────────────────────────────────────────────
const _kProfKey = 'has_declared_professional';

// ── Strings bilíngues ──────────────────────────────────────────────────────────
class _S {
  final bool es;
  const _S(this.es);

  // ── Header ──────────────────────────────────────────────────────────────────
  String get title => es
      ? 'Aviso Legal Obligatorio'
      : 'Aviso Legal Obrigatório';

  String get subtitle => es
      ? 'Lea atentamente antes de acceder a MedCases Pro.'
      : 'Leia com atenção antes de acessar o MedCases Pro.';

  // ── Badge de aviso ──────────────────────────────────────────────────────────
  String get warningBadge => es ? 'USO EDUCATIVO EXCLUSIVO' : 'USO EDUCACIONAL EXCLUSIVO';

  // ── Bloco principal de disclaimer (texto exigido) ──────────────────────────
  String get disclaimerMain => es
      ? 'Esta aplicación es una plataforma de simulación clínica estrictamente educacional. El contenido no debe ser utilizado para guiar diagnósticos, tratamientos ni prescripciones en pacientes reales. La responsabilidad final sobre cualquier conducta médica es exclusiva del profesional de salud habilitado.'
      : 'Este aplicativo é uma plataforma de simulação clínica estritamente educacional. O conteúdo não deve ser utilizado para guiar diagnósticos, tratamentos ou prescrições em pacientes reais. A responsabilidade final sobre qualquer conduta médica é exclusiva do profissional de saúde habilitado.';

  // ── Itens do aviso (bullets visuais) ──────────────────────────────────────
  List<String> get warningItems => es
      ? [
          'No sustituye la consulta médica real ni el juicio clínico.',
          'Los datos y protocolos son para fines de estudio y simulación.',
          'Cualquier aplicación clínica es responsabilidad exclusiva del profesional.',
        ]
      : [
          'Não substitui consulta médica real nem julgamento clínico.',
          'Dados e protocolos são para fins de estudo e simulação.',
          'Qualquer aplicação clínica é de responsabilidade exclusiva do profissional.',
        ];

  // ── Seleção de categoria ───────────────────────────────────────────────────
  String get dropdownLabel => es
      ? 'Seleccione su categoría profesional'
      : 'Selecione sua categoria profissional';

  List<String> get categories => es
      ? ['Médico / Residente', 'Estudiante de Medicina', 'Otro Profesional de la Salud']
      : ['Médico / Residente', 'Estudante de Medicina', 'Outro Profissional de Saúde'];

  // ── Checkbox de consentimento ──────────────────────────────────────────────
  String get checkboxLabel => es ? 'Li e aceito os termos acima' : 'Li e aceito os termos acima';

  String get checkboxText => es
      ? 'Declaro que soy profesional o estudiante del área de la salud. Entiendo que esta aplicación es exclusivamente educacional y de simulación clínica, y que nunca utilizaré su contenido para tomar decisiones clínicas en pacientes reales sin el debido juicio profesional.'
      : 'Declaro que sou profissional ou estudante da área de saúde. Entendo que este aplicativo é exclusivamente educacional e de simulação clínica, e que jamais utilizarei seu conteúdo para tomar decisões clínicas em pacientes reais sem o devido julgamento profissional.';

  // ── Botão ──────────────────────────────────────────────────────────────────
  String get button => es ? 'Acepto — Acceder a la App' : 'Aceito — Acessar o App';

  // ── Rodapé legal ──────────────────────────────────────────────────────────
  String get legalNote => es
      ? 'Esta declaración tiene validez legal y quedará registrada en su dispositivo.'
      : 'Esta declaração tem validade legal e ficará registrada em seu dispositivo.';
}

// ── Serviço estático de persistência ──────────────────────────────────────────
class ProfessionalDeclarationGate {
  static Future<bool> hasDeclared() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kProfKey) ?? false;
  }

  static Future<void> saveDeclaration({
    required String uid,
    required String professionalCategory,
  }) async {
    // 1. Firestore — persiste entre dispositivos e reinstalações (Apple-safe)
    try {
      await AuthService.updateTermsAccepted(
        uid: uid,
        professionalCategory: professionalCategory,
      );
    } catch (_) {
      // Falha silenciosa — cache local é o fallback
    }
    // 2. Cache local — verificação rápida no mesmo dispositivo
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kProfKey, true);
  }
}

// ── Widget de Gate ────────────────────────────────────────────────────────────
/// Envolve [child] com o gate de declaração profissional.
/// Se o usuário já declarou anteriormente, exibe [child] diretamente.
/// Caso contrário, exibe o aviso legal obrigatório em fullscreen sobre [child].
class ProfessionalDeclarationGateWidget extends StatefulWidget {
  final Widget child;
  const ProfessionalDeclarationGateWidget({super.key, required this.child});

  @override
  State<ProfessionalDeclarationGateWidget> createState() =>
      _ProfessionalDeclarationGateWidgetState();
}

class _ProfessionalDeclarationGateWidgetState
    extends State<ProfessionalDeclarationGateWidget> {
  // null = ainda carregando; true = já declarou; false = precisa declarar
  bool? _declared;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final ok = await ProfessionalDeclarationGate.hasDeclared();
    if (mounted) setState(() => _declared = ok);
  }

  void _onAccepted() => setState(() => _declared = true);

  @override
  Widget build(BuildContext context) {
    // Enquanto verifica o SharedPreferences, exibe splash mínimo
    if (_declared == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF07110d),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFD4A96A)),
        ),
      );
    }

    // Já declarou → exibe o app normalmente
    if (_declared!) return widget.child;

    // Precisa declarar → exibe aviso obrigatório sobre o app
    // AbsorbPointer no backdrop: intercepta 100% dos toques antes de
    // chegar ao widget.child — hard-lock impossível de contornar (iOS + Android).
    final lang = Localizations.localeOf(context).languageCode;
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: AbsorbPointer(
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.80)),
          ),
        ),
        Positioned.fill(
          child: _ProfessionalDeclarationModal(
            lang: lang == 'es' ? 'es' : 'pt',
            uid: Provider.of<AppProvider>(context, listen: false).currentUser?.uid ?? '',
            onAccepted: _onAccepted,
          ),
        ),
      ],
    );
  }
}

// ── Modal de Aviso Legal Obrigatório ─────────────────────────────────────────
class _ProfessionalDeclarationModal extends StatefulWidget {
  final String lang;
  final String uid;
  final VoidCallback onAccepted;

  const _ProfessionalDeclarationModal({
    required this.lang,
    required this.uid,
    required this.onAccepted,
  });

  @override
  State<_ProfessionalDeclarationModal> createState() =>
      _ProfessionalDeclarationModalState();
}

class _ProfessionalDeclarationModalState
    extends State<_ProfessionalDeclarationModal>
    with SingleTickerProviderStateMixin {
  late _S _s;
  String? _selectedCategory;
  bool _checked = false;
  bool _saving = false;

  // Animação de entrada
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  // Paleta dark — coerente com o restante do app
  static const _bg       = Color(0xFF07110d);
  static const _surface  = Color(0xFF0F2419);
  static const _green    = Color(0xFF075f45);
  static const _greenLt  = Color(0xFF2E8A62);
  static const _gold     = Color(0xFFD4A96A);
  static const _goldBg   = Color(0xFF1A1200);
  static const _border   = Color(0xFF1A3828);
  static const _textPri  = Color(0xFFF7F7F7);
  static const _textSec  = Color(0xFFCCCCCC);
  static const _textHint = Color(0xFF888888);
  static const _disabled = Color(0xFF2A3A30);

  // Vermelho para o bloco de aviso
  static const _redBg    = Color(0xFF1A0A0A);
  static const _redBorder = Color(0xFF8B1A1A);
  static const _redText  = Color(0xFFFF6B6B);
  static const _redIcon  = Color(0xFFFF4444);

  @override
  void initState() {
    super.initState();
    _s = _S(widget.lang == 'es');

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fade  = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _canConfirm => _selectedCategory != null && _checked && !_saving;

  Future<void> _onConfirm() async {
    if (!_canConfirm) return;
    setState(() => _saving = true);
    await ProfessionalDeclarationGate.saveDeclaration(
      uid: widget.uid,
      professionalCategory: _selectedCategory!,
    );
    if (mounted) widget.onAccepted();
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final isWide  = screenW > 600;
    final cardW   = isWide ? 540.0 : screenW;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              vertical: 24,
              horizontal: isWide ? 0 : 0,
            ),
            child: Container(
              width: cardW,
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(isWide ? 20 : 0),
                border: isWide
                    ? Border.all(color: _border, width: 1)
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  _buildDisclaimerBlock(),
                  _buildBody(),
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── 1. Cabeçalho ─────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
      decoration: const BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(bottom: BorderSide(color: _border, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Ícone de aviso
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _redIcon.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _redIcon.withValues(alpha: 0.30),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: _redIcon,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _redBg,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: _redBorder.withValues(alpha: 0.5),
                            width: 1),
                      ),
                      child: Text(
                        _s.warningBadge,
                        style: const TextStyle(
                          color: _redText,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _s.title,
                      style: const TextStyle(
                        color: _textPri,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _s.subtitle,
            style: const TextStyle(
              color: _textSec,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. Bloco de Disclaimer Obrigatório (destaque máximo) ──────────────────
  Widget _buildDisclaimerBlock() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      decoration: BoxDecoration(
        color: _redBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _redBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Barra de título vermelha
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _redBorder.withValues(alpha: 0.25),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                const Icon(Icons.gpp_bad_rounded,
                    size: 15, color: _redIcon),
                const SizedBox(width: 8),
                Text(
                  widget.lang == 'es'
                      ? 'AVISO IMPORTANTE — LEA ANTES DE CONTINUAR'
                      : 'AVISO IMPORTANTE — LEIA ANTES DE CONTINUAR',
                  style: const TextStyle(
                    color: _redText,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),

          // Texto principal do disclaimer
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Text(
              _s.disclaimerMain,
              style: const TextStyle(
                color: _textPri,
                fontSize: 13.5,
                height: 1.65,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // Divisor
          Container(
            height: 1,
            color: _redBorder.withValues(alpha: 0.35),
          ),

          // Bullets de reforço
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _s.warningItems.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Icon(Icons.remove_circle_outline_rounded,
                            size: 13, color: _redText),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item,
                          style: TextStyle(
                            color: _textSec.withValues(alpha: 0.9),
                            fontSize: 12.5,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── 3. Corpo — Seleção de categoria + Checkbox ────────────────────────────
  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label da seleção
          Text(
            _s.dropdownLabel,
            style: const TextStyle(
              color: _gold,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),

          // Radio chips
          ...List.generate(_s.categories.length, (i) {
            final cat = _s.categories[i];
            final selected = _selectedCategory == cat;
            return GestureDetector(
              onTap: () => setState(() => _selectedCategory = cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: selected
                      ? _green.withValues(alpha: 0.14)
                      : _surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? _greenLt.withValues(alpha: 0.65)
                        : _border,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? _green : Colors.transparent,
                        border: Border.all(
                          color: selected ? _green : _textHint,
                          width: 1.5,
                        ),
                      ),
                      child: selected
                          ? const Icon(Icons.check_rounded,
                              size: 13, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        cat,
                        style: TextStyle(
                          color: selected ? _textPri : _textSec,
                          fontSize: 14,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 18),

          // Checkbox de consentimento
          GestureDetector(
            onTap: () => setState(() => _checked = !_checked),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _checked
                    ? _green.withValues(alpha: 0.10)
                    : _surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _checked
                      ? _greenLt.withValues(alpha: 0.55)
                      : _border,
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: _checked ? _green : Colors.transparent,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: _checked ? _green : _textHint,
                        width: 1.5,
                      ),
                    ),
                    child: _checked
                        ? const Icon(Icons.check_rounded,
                            size: 15, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.lang == 'es'
                              ? 'Leí y acepto los términos anteriores'
                          : 'Li e aceito os termos acima',
                          style: TextStyle(
                            color: _checked ? _textPri : _textSec,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _s.checkboxText,
                          style: TextStyle(
                            color: _checked
                                ? _textSec
                                : _textHint,
                            fontSize: 12,
                            height: 1.55,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ── 4. Rodapé — Botão ─────────────────────────────────────────────────────
  Widget _buildFooter() {
    final enabled = _canConfirm;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(
        children: [
          // Nota legal
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: _goldBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: _gold.withValues(alpha: 0.25), width: 1),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_outline_rounded,
                    size: 13, color: _gold.withValues(alpha: 0.8)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _s.legalNote,
                    style: TextStyle(
                      color: _gold.withValues(alpha: 0.85),
                      fontSize: 11.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Botão principal
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              gradient: enabled
                  ? const LinearGradient(
                      colors: [Color(0xFF075f45), Color(0xFF0D8A65)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : null,
              color: enabled ? null : _disabled,
              borderRadius: BorderRadius.circular(12),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: _green.withValues(alpha: 0.40),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: enabled ? _onConfirm : null,
                borderRadius: BorderRadius.circular(12),
                child: Center(
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              enabled
                                  ? Icons.check_circle_rounded
                                  : Icons.lock_rounded,
                              size: 18,
                              color: enabled
                                  ? Colors.white
                                  : _textHint,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _s.button,
                              style: TextStyle(
                                color: enabled
                                    ? Colors.white
                                    : _textHint,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),

          // Hint quando botão bloqueado
          if (!enabled) ...[
            const SizedBox(height: 10),
            Text(
              widget.lang == 'es'
                  ? 'Seleccione su categoría y marque la casilla para continuar.'
                  : 'Selecione sua categoria e marque o checkbox para continuar.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _textHint,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
