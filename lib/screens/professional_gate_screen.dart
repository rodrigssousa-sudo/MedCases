// ── ProfessionalDeclarationGate ───────────────────────────────────────────────
// Tela de blindagem jurídica: exibida uma única vez por usuário após o login.
// Persiste o aceite em SharedPreferences com a chave 'has_declared_professional'.
// Suporta PT (padrão) e ES via Localizations.localeOf(context).languageCode.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Chave de persistência ──────────────────────────────────────────────────────
const _kProfKey = 'has_declared_professional';

// ── Strings bilíngues ──────────────────────────────────────────────────────────
class _S {
  final bool es;
  const _S(this.es);

  String get title   => es
      ? 'Declaración de Uso Profesional'
      : 'Declaração de Uso Profissional';

  String get subtitle => es
      ? 'MedCases Pro es un software de soporte para la toma de decisiones clínicas exclusivo para el área médica y de la salud.'
      : 'O MedCases Pro é um software de suporte à decisão clínica exclusivo para a área médica e de saúde.';

  String get dropdownLabel => es
      ? 'Seleccione su categoría'
      : 'Selecione sua categoria';

  List<String> get categories => es
      ? ['Médico / Residente', 'Estudiante de Medicina', 'Otro Profesional de la Salud']
      : ['Médico / Residente', 'Estudante de Medicina', 'Outro Profissional de Saúde'];

  String get checkboxText => es
      ? 'Declaro que la información anterior es verdadera. Soy consciente de que esta aplicación es una herramienta complementaria y educativa para ayudar en la consulta de conductas. MedCases Pro no toma decisiones clínicas de forma autónoma y no reemplaza el juicio profesional y soberano del médico tratante.'
      : 'Declaro que as informações acima são verdadeiras. Estou ciente de que este aplicativo é uma ferramenta complementar e educacional para auxiliar na consulta de condutas. O MedCases Pro não toma decisões clínicas de forma autônoma e não substitui o julgamento profissional e soberano do médico assistente.';

  String get button => es
      ? 'Confirmar y Acceder'
      : 'Confirmar e Acessar';
}

// ── Serviço estático de persistência ──────────────────────────────────────────
class ProfessionalDeclarationGate {
  static Future<bool> hasDeclared() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kProfKey) ?? false;
  }

  static Future<void> saveDeclaration() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kProfKey, true);
  }
}

// ── Widget de Gate ────────────────────────────────────────────────────────────
/// Envolve [child] com o gate de declaração profissional.
/// Se o usuário já declarou anteriormente, exibe [child] diretamente.
/// Caso contrário, exibe a tela de declaração em fullscreen sobre [child].
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

    // Precisa declarar → exibe modal sobre o app
    final lang = Localizations.localeOf(context).languageCode;
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: ColoredBox(color: Colors.black.withValues(alpha: 0.72)),
        ),
        Positioned.fill(
          child: _ProfessionalDeclarationModal(
            lang: lang == 'es' ? 'es' : 'pt',
            onAccepted: _onAccepted,
          ),
        ),
      ],
    );
  }
}

// ── Modal de Declaração ────────────────────────────────────────────────────────
class _ProfessionalDeclarationModal extends StatefulWidget {
  final String lang;
  final VoidCallback onAccepted;

  const _ProfessionalDeclarationModal({
    required this.lang,
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

  // Cores fixas (dark theme — mesma paleta de legal_screen.dart / ConsentModal)
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

  @override
  void initState() {
    super.initState();
    _s = _S(widget.lang == 'es');

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _fade  = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
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
    await ProfessionalDeclarationGate.saveDeclaration();
    if (mounted) widget.onAccepted();
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final isWide  = screenW > 600;
    final cardW   = isWide ? 520.0 : screenW;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 0 : 0,
              vertical: 24,
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

  // ── Cabeçalho ──────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      decoration: const BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(bottom: BorderSide(color: _border, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ícone + título
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _green.withValues(alpha: 0.35), width: 1),
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: _gold,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  _s.title,
                  style: const TextStyle(
                    color: _textPri,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Subtítulo
          Text(
            _s.subtitle,
            style: const TextStyle(
              color: _textSec,
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Corpo — Seleção de categoria (radio chips) + Checkbox ────────────────────
  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label da seleção
          Text(
            _s.dropdownLabel,
            style: const TextStyle(
              color: _gold,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),

          // Radio chips — uma opção por linha
          ...List.generate(_s.categories.length, (i) {
            final cat = _s.categories[i];
            final selected = _selectedCategory == cat;
            return GestureDetector(
              onTap: () => setState(() => _selectedCategory = cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
                    // Círculo radio
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

          const SizedBox(height: 22),

          // Checkbox de consentimento
          GestureDetector(
            onTap: () => setState(() => _checked = !_checked),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _checked
                    ? _green.withValues(alpha: 0.10)
                    : _surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _checked
                      ? _greenLt.withValues(alpha: 0.5)
                      : _border,
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Checkbox customizado
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
                  // Texto do checkbox
                  Expanded(
                    child: Text(
                      _s.checkboxText,
                      style: TextStyle(
                        color: _checked ? _textPri : _textSec,
                        fontSize: 13,
                        height: 1.55,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 22),
        ],
      ),
    );
  }

  // ── Rodapé — Botão ─────────────────────────────────────────────────────────
  Widget _buildFooter() {
    final enabled = _canConfirm;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Aviso legal mínimo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 16),
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
                    widget.lang == 'es'
                        ? 'Esta declaración tiene validez legal y quedará registrada en su dispositivo.'
                        : 'Esta declaração tem validade legal e ficará registrada em seu dispositivo.',
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

          // Botão de confirmação
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            height: 50,
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
                        color: _green.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
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
                      : Text(
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
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
