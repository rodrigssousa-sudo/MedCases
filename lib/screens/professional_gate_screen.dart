// ── ProfessionalDeclarationGate ───────────────────────────────────────────────
// Tela de blindagem jurídica: exibida uma única vez por usuário após o login.
// Persiste o aceite em SharedPreferences com a chave 'has_declared_professional'.
// Suporta PT (padrão) e ES via Localizations.localeOf(context).languageCode.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:firebase_auth/firebase_auth.dart';
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
  String get checkboxLabel => es ? 'Leí y acepto los términos anteriores' : 'Li e aceito os termos acima';

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

  /// Resolve o uid do usuário atual com múltiplas camadas de fallback.
  /// Ordem: AppProvider → FirebaseAuth.currentUser → null
  /// NUNCA retorna string vazia ('') — retorna null se indisponível.
  static String? _resolveUid(BuildContext context) {
    // Camada 1: AppProvider (definido via setUser após authStateChanges)
    final providerUid = Provider.of<AppProvider>(context, listen: false).currentUser?.uid;
    if (providerUid != null && providerUid.isNotEmpty) return providerUid;

    // Camada 2: FirebaseAuth.instance.currentUser (sempre disponível após login nativo)
    final firebaseUid = FirebaseAuth.instance.currentUser?.uid;
    if (firebaseUid != null && firebaseUid.isNotEmpty) return firebaseUid;

    // Uid indisponível — não salvar
    return null;
  }

  /// Salva a declaração profissional com uid resolvido e validado.
  /// Lança [StateError] se o uid não puder ser resolvido — nunca salva com uid vazio.
  static Future<void> saveDeclaration({
    required String uid,
    required String professionalCategory,
  }) async {
    // Guarda de segurança: bloqueia uid vazio antes de qualquer IO
    assert(uid.isNotEmpty, 'saveDeclaration: uid não pode ser vazio');
    if (uid.isEmpty) {
      debugPrint('[ProfGate] ERRO: tentativa de salvar declaração com uid vazio — abortado');
      throw StateError('uid inválido: não foi possível identificar o usuário para salvar a declaração');
    }

    // 1. Firestore — persiste entre dispositivos e reinstalações (Apple-safe)
    try {
      await AuthService.updateTermsAccepted(
        uid: uid,
        professionalCategory: professionalCategory,
      );
      debugPrint('[ProfGate] Declaração salva no Firestore — uid=$uid');
    } catch (e) {
      // Firestore indisponível — cache local garante que o usuário não bloqueie
      debugPrint('[ProfGate] Firestore indisponível (${e.runtimeType}) — salvo apenas localmente');
    }

    // 2. Cache local — verificação rápida no mesmo dispositivo
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kProfKey, true);
    debugPrint('[ProfGate] Declaração salva em SharedPreferences — uid=$uid');
  }
}

// ── Widget de Gate ────────────────────────────────────────────────────────────
/// Envolve [child] com o gate de declaração profissional.
/// Se o usuário já declarou anteriormente, exibe [child] diretamente.
/// Caso contrário, exibe o aviso legal obrigatório em fullscreen sobre [child].
///
/// Build 103 — Fix uid vazio:
/// O uid é resolvido com múltiplas camadas de fallback (AppProvider →
/// FirebaseAuth.currentUser) e NUNCA salvo como string vazia. Se o uid
/// não estiver disponível imediatamente (addPostFrameCallback de setUser ainda
/// pendente), o gate aguarda até 3s até que o AppProvider ou o FirebaseAuth
/// SDK o forneça. Se após todas as tentativas o uid permanecer nulo,
/// exibe mensagem de erro clara sem salvar nada.
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

  // uid resolvido — definido antes de exibir o modal
  String? _resolvedUid;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final ok = await ProfessionalDeclarationGate.hasDeclared();
    if (!mounted) return;

    if (ok) {
      // Já declarou — não precisa resolver uid
      setState(() => _declared = true);
      return;
    }

    // Precisa declarar — resolve uid antes de exibir o modal.
    // setUser() é chamado via addPostFrameCallback (um frame após o render),
    // portanto AppProvider.currentUser pode ser null no primeiro frame.
    // Tenta até 3x com 500ms de intervalo antes de usar FirebaseAuth direto.
    String? uid = ProfessionalDeclarationGate._resolveUid(context);
    if (uid == null) {
      // Aguarda até 3 frames (1.5s) para que o AppProvider complete setUser()
      for (int i = 0; i < 3 && uid == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        uid = ProfessionalDeclarationGate._resolveUid(context);
      }
    }

    if (!mounted) return;
    setState(() {
      _resolvedUid = uid; // pode ser null se ambas as camadas falharam
      _declared = false;
    });
  }

  void _onAccepted() => setState(() => _declared = true);

  @override
  Widget build(BuildContext context) {
    // Enquanto verifica o SharedPreferences / resolve uid, exibe splash mínimo
    if (_declared == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF075f45)),
        ),
      );
    }

    // Já declarou → exibe o app normalmente
    if (_declared!) return widget.child;

    // Uid completamente indisponível após todas as tentativas — erro claro.
    // Não deve ocorrer em condições normais: FirebaseAuth sempre tem currentUser
    // quando o usuário chegou até este ponto do fluxo.
    if (_resolvedUid == null || _resolvedUid!.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 48, color: Color(0xFFE53E3E)),
                const SizedBox(height: 16),
                const Text(
                  'Não foi possível identificar sua conta.\n'
                  'Faça logout e entre novamente.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15, height: 1.5, color: Color(0xFF333333)),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    await AuthService.logout();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF075f45)),
                  child: const Text('Fazer logout',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Precisa declarar → exibe aviso obrigatório sobre o app.
    // AbsorbPointer no backdrop: intercepta 100% dos toques antes de
    // chegar ao widget.child — hard-lock impossível de contornar (iOS + Android).
    final lang = Localizations.localeOf(context).languageCode;
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: AbsorbPointer(
            child: ColoredBox(color: Colors.black.withOpacity(0.80)),
          ),
        ),
        Positioned.fill(
          child: _ProfessionalDeclarationModal(
            lang: lang == 'es' ? 'es' : 'pt',
            uid: _resolvedUid!, // ← uid validado — nunca vazio aqui
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
  late String _localLang; // PT/ES toggle local
  String? _selectedCategory;
  bool _checked = false;
  bool _saving = false;

  // Animação de entrada
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  // ── Paleta branca — design documento real (Apple-friendly) ────────────────
  static const _bg        = Colors.white;
  static const _surface   = Color(0xFFF7F9F8);
  static const _green     = Color(0xFF075f45);
  static const _greenLt   = Color(0xFF2E8A62);
  static const _border    = Color(0xFFDDE3E0);
  static const _textPri   = Color(0xFF0D1611);   // quase-preto
  static const _textSec   = Color(0xFF3D4A44);   // cinza escuro
  static const _textHint  = Color(0xFF8A9890);
  static const _disabled  = Color(0xFFCDD6D2);

  // Vermelho para o bloco de aviso (versão light)
  static const _redBg     = Color(0xFFFFF1F1);
  static const _redBorder = Color(0xFFE53E3E);
  static const _redText   = Color(0xFFB91C1C);
  static const _redIcon   = Color(0xFFDC2626);

  @override
  void initState() {
    super.initState();
    _localLang = widget.lang; // inicializa com lang detectado pelo sistema
    _s = _S(_localLang == 'es');

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
                  _buildLangToggle(),
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

  // ── 0. Toggle de idioma PT / ES ──────────────────────────────────────────
  Widget _buildLangToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: ['pt', 'es'].map((lang) {
          final selected = _localLang == lang;
          return GestureDetector(
            onTap: () => setState(() {
              _localLang = lang;
              _s = _S(lang == 'es');
              // Resetar seleção ao trocar idioma (labels mudam)
              _selectedCategory = null;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: selected ? _green : Colors.transparent,
                border: Border.all(
                  color: selected ? _green : _border,
                  width: 1,
                ),
              ),
              child: Text(
                lang == 'pt' ? 'PT' : 'ES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : _textHint,
                  letterSpacing: 0.8,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── 1. Cabeçalho ─────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 18),
      decoration: const BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
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
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: _redIcon.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _redIcon.withOpacity(0.25),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: _redIcon,
                  size: 20,
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
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: _redBg,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: _redBorder.withOpacity(0.35),
                            width: 1),
                      ),
                      child: Text(
                        _s.warningBadge,
                        style: const TextStyle(
                          color: _redText,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _s.title,
                      style: const TextStyle(
                        color: _textPri,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.1,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _s.subtitle,
            style: const TextStyle(
              color: _textSec,
              fontSize: 13,
              height: 1.5,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. Bloco de Disclaimer Obrigatório (destaque máximo) ──────────────────
  Widget _buildDisclaimerBlock() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      decoration: BoxDecoration(
        color: _redBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _redBorder.withOpacity(0.55), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Barra de título vermelha
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: _redBorder.withOpacity(0.12),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                const Icon(Icons.gpp_bad_rounded,
                    size: 14, color: _redIcon),
                const SizedBox(width: 8),
                Text(
                  _localLang == 'es'
                      ? 'AVISO IMPORTANTE — LEA ANTES DE CONTINUAR'
                      : 'AVISO IMPORTANTE — LEIA ANTES DE CONTINUAR',
                  style: const TextStyle(
                    color: _redText,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),

          // Texto principal do disclaimer — bold para ênfase, sem underline
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Text(
              _s.disclaimerMain,
              style: const TextStyle(
                color: _textPri,
                fontSize: 13.5,
                height: 1.65,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.none,
              ),
            ),
          ),

          // Divisor
          Container(
            height: 1,
            color: _redBorder.withOpacity(0.20),
          ),

          // Bullets de reforço
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
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
                          style: const TextStyle(
                            color: _textSec,
                            fontSize: 12.5,
                            height: 1.5,
                            decoration: TextDecoration.none,
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label da seleção — texto escuro, sem underline
          Text(
            _s.dropdownLabel,
            style: const TextStyle(
              color: _textSec,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 10),

          // Radio chips — fundo branco, borda verde quando selecionado
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
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: selected
                      ? _green.withOpacity(0.06)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? _greenLt.withOpacity(0.80)
                        : _border,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Radio button visual
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
                          color: _textPri,
                          fontSize: 14,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w400,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 16),

          // Checkbox de consentimento
          GestureDetector(
            onTap: () => setState(() => _checked = !_checked),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _checked
                    ? _green.withOpacity(0.06)
                    : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _checked
                      ? _greenLt.withOpacity(0.75)
                      : _border,
                  width: _checked ? 1.5 : 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Checkbox visual
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
                          _localLang == 'es'
                              ? 'Leí y acepto los términos anteriores'
                              : 'Li e aceito os termos acima',
                          style: TextStyle(
                            color: _textPri,
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _s.checkboxText,
                          style: const TextStyle(
                            color: _textSec,
                            fontSize: 12,
                            height: 1.55,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),
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
          // Nota legal — sem underline, sem fundo ouro escuro
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: const Color(0xFFD0D0D0), width: 1),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline_rounded,
                    size: 13, color: Color(0xFF888888)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _s.legalNote,
                    style: const TextStyle(
                      color: Color(0xFF555555),
                      fontSize: 11.5,
                      height: 1.4,
                      decoration: TextDecoration.none,
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
                        color: _green.withOpacity(0.30),
                        blurRadius: 12,
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
                                decoration: TextDecoration.none,
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
              _localLang == 'es'
                  ? 'Seleccione su categoría y marque la casilla para continuar.'
                  : 'Selecione sua categoria e marque o checkbox para continuar.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _textHint,
                fontSize: 11.5,
                height: 1.4,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
