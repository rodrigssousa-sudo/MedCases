import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const LoginScreen({super.key, this.onBack});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum _Mode { login, register, reset }

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  _Mode _mode = _Mode.login;
  bool _loading = false;
  bool _obscure = true;
  bool _rememberEmail = false;
  bool _keepLoggedIn  = false;
  String? _error;
  String? _success;

  // ── Task 3: Disclaimer médico obrigatório ─────────────────────────────────
  // Deve ser aceito na etapa de perfil (regStep==1) do cadastro.
  bool _disclaimerAccepted = false;
  bool _disclaimerError    = false;

  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _nameCtrl  = TextEditingController();
  final _profCtrl  = TextEditingController();
  final _instCtrl  = TextEditingController();
  final _formKey   = GlobalKey<FormState>();

  late AnimationController _slideCtrl;
  late AnimationController _heroCtrl;
  late Animation<Offset>   _slideAnim;
  late Animation<double>   _heroRot;

  // ── Nova paleta ────────────────────────────────────────────────────────────
  // Verde profundo diferente do anterior (#0F1C14 → #061A12)
  static const kBg        = Color(0xFF0F1116);   // fundo hero — verde bem escuro
  static const kForest    = Color(0xFF0D3324);   // camada intermediária
  static const kGreen     = Color(0xFF0E7C52);   // verde principal (mais vivo)
  static const kGreenMid  = Color(0xFF13A06A);   // verde médio — novo acento
  static const kPanel     = Color(0xFFF0F4F0);   // painel inferior — gelo levemente verde
  static const kPanelCard = Color(0xFFFFFFFF);   // cartão interno
  static const kText      = Color(0xFF0D2B1E);   // texto escuro no painel
  static const kTextMid   = Color(0xFF4A6B58);   // texto médio
  static const kGold      = Color(0xFFD4A853);   // dourado — acento
  static const kGoldL     = Color(0xFFFFE8A6);   // dourado claro

  static const _kPrefEmail    = 'login_saved_email';
  static const _kPrefRemember = 'login_remember_email';
  static const _kKeepLoggedIn = 'session_keep_logged_in';

  // ── Onboarding steps (modo registro) ────────────────────────────────────
  int _regStep = 0; // 0=conta, 1=perfil

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 480));
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.35), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));

    _heroCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 18))
      ..repeat();
    _heroRot = Tween<double>(begin: 0, end: 2 * math.pi)
        .animate(_heroCtrl);

    _slideCtrl.forward();
    _loadSavedEmail();
  }

  Future<void> _loadSavedEmail() async {
    try {
      final p = await SharedPreferences.getInstance();
      final remember     = p.getBool(_kPrefRemember) ?? false;
      final keepLoggedIn = p.getBool(_kKeepLoggedIn) ?? false;
      final email        = p.getString(_kPrefEmail)  ?? '';
      if (mounted) setState(() {
        _keepLoggedIn  = keepLoggedIn;
        _rememberEmail = remember || keepLoggedIn;
        if (_rememberEmail && email.isNotEmpty) _emailCtrl.text = email;
      });
    } catch (_) {}
  }

  Future<void> _persistEmail(String email) async {
    try {
      final p = await SharedPreferences.getInstance();
      if (_rememberEmail && email.isNotEmpty) {
        await p.setBool(_kPrefRemember, true);
        await p.setString(_kPrefEmail, email);
      } else {
        await p.remove(_kPrefRemember);
        await p.remove(_kPrefEmail);
      }
      if (!_keepLoggedIn) await AuthService.clearSession();
    } catch (_) {}
  }

  Future<void> _saveSessionIfRequested(AuthResult result) async {
    if (_keepLoggedIn && result.user != null) {
      await AuthService.saveSession(result.user!);
    }
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _heroCtrl.dispose();
    _emailCtrl.dispose(); _passCtrl.dispose(); _nameCtrl.dispose();
    _profCtrl.dispose();  _instCtrl.dispose();
    super.dispose();
  }

  void _switchMode(_Mode m) {
    setState(() { _mode = m; _error = null; _success = null; _regStep = 0; _disclaimerAccepted = false; _disclaimerError = false; });
    _slideCtrl.forward(from: 0);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_mode == _Mode.register && _regStep < 1) {
      setState(() => _regStep++);
      _slideCtrl.forward(from: 0);
      return;
    }

    // ── Task 3: bloqueia envio se disclaimer não foi aceito ────────────────
    if (_mode == _Mode.register && !_disclaimerAccepted) {
      setState(() => _disclaimerError = true);
      return;
    }

    setState(() { _loading = true; _error = null; _success = null; });
    AuthResult result;

    if (_mode == _Mode.login) {
      await _persistEmail(_emailCtrl.text.trim());
      result = await AuthService.login(
        email: _emailCtrl.text, password: _passCtrl.text);
      if (result.success) await _saveSessionIfRequested(result);
    } else if (_mode == _Mode.register) {
      // Captura referral_code salvo na boot (capturado de ?ref= na URL)
      String? referredBy;
      try {
        final prefs = await SharedPreferences.getInstance();
        final code = prefs.getString('referral_code') ?? '';
        if (code.isNotEmpty) referredBy = code;
      } catch (_) {}

      result = await AuthService.register(
        email: _emailCtrl.text,
        password: _passCtrl.text,
        displayName: _nameCtrl.text,
        profession: _profCtrl.text.isNotEmpty ? _profCtrl.text : null,
        institution: _instCtrl.text.isNotEmpty ? _instCtrl.text : null,
        referredBy: referredBy,
      );

      // ── Auto-aprovação + auto-login após cadastro ────────────────────────
      // 1. Registra o usuário
      // 2. Aprova imediatamente (sem precisar de ação do admin)
      // 3. Faz login automático → usuario entra direto no app na primeira vez
      // Na segunda sessão o usuário já está aprovado e só digita email+senha.
      if (result.success) {
        // Aprova automaticamente antes do login para que o AuthGate não
        // roteie para _PendingScreen (o usuário entra direto no app)
        final newUid = result.user?.uid ?? '';
        if (newUid.isNotEmpty) {
          try {
            await AuthService.approveUser(newUid, 'system-auto');
          } catch (_) {
            // Silencioso — _PendingScreen tem fallback de auto-aprovação
          }
        }

        final loginResult = await AuthService.login(
          email: _emailCtrl.text,
          password: _passCtrl.text,
        );
        if (loginResult.success) {
          if (_keepLoggedIn && loginResult.user != null) {
            await AuthService.saveSession(loginResult.user!);
          }
          // AuthGate detecta o usuário aprovado e navega para o MainShell
          if (!mounted) return;
          setState(() { _loading = false; });
          return;
        }
        // Fallback: auto-login falhou → redireciona ao login com mensagem
        if (!mounted) return;
        setState(() {
          _loading = false;
          _success = _registerSuccessMsg();
          _mode = _Mode.login;
          _regStep = 0;
          _disclaimerAccepted = false;
        });
        return;
      }
    } else {
      result = await AuthService.resetPassword(_emailCtrl.text);
      if (result.success) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _success = _resetSuccessMsg(_emailCtrl.text);
        });
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      if (!result.success) _error = result.error;
    });
  }

  // ── idioma ────────────────────────────────────────────────────────────────
  String _currentLang = 'es';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    SharedPreferences.getInstance().then((p) {
      final lang = p.getString('lang') ?? 'es';
      if (mounted && lang != _currentLang) setState(() => _currentLang = lang);
    });
  }

  bool get _isEs => _currentLang == 'es';

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size   = MediaQuery.of(context).size;
    // Em tablets/iPad limita a largura para evitar layout de smartphone esticado.
    // Em phones usa a largura total.
    final isTablet  = size.width >= 600;
    final panelW    = isTablet ? 460.0 : size.width;
    // Proporção: 42% hero topo / 58% painel inferior
    final heroH  = size.height * 0.42;

    return Scaffold(
      backgroundColor: kBg,
      body: Stack(children: [
        // ── Hero ocupa sempre a tela inteira (fundo) ──────────────────────
        Positioned.fill(
          child: _HeroGeometric(rotAnim: _heroRot, lang: _currentLang),
        ),

        // ── Botão voltar — sempre no canto esquerdo da tela ───────────────
        if (widget.onBack != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 14,
            child: SafeArea(
              bottom: false,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onBack,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white.withValues(alpha: 0.12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white70, size: 18),
                  ),
                ),
              ),
            ),
          ),

        // ── Painel inferior centralizado (tablet: largura limitada) ───────
        Positioned(
          top: heroH - 20,
          left: 0, right: 0, bottom: 0,
          child: Center(
            child: SizedBox(
              width: panelW,
              child: SlideTransition(
                position: _slideAnim,
                child: Container(
                  decoration: const BoxDecoration(
                    color: kPanel,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      left: 28, right: 28,
                      top: 28, bottom: MediaQuery.of(context).padding.bottom + 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      // ── Handle visual ───────────────────────────────────
                      Center(
                        child: Container(
                          width: 40, height: 4,
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            color: kTextMid.withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      // ── Cabeçalho do modo ───────────────────────────────
                      _buildModeHeader(),
                      const SizedBox(height: 20),

                      // ── Step indicator (registro) ───────────────────────
                      if (_mode == _Mode.register) ...[
                        _buildStepIndicator(),
                        const SizedBox(height: 18),
                      ],

                      // ── Banner sucesso ──────────────────────────────────
                      if (_success != null) ...[
                        _banner(_success!, isError: false),
                        const SizedBox(height: 14),
                      ],

                      // ── Campos ──────────────────────────────────────────
                      if (_mode == _Mode.login)    ..._loginFields(),
                      if (_mode == _Mode.register) ..._registerFields(),
                      if (_mode == _Mode.reset)    ..._resetFields(),

                      // ── Banner erro ─────────────────────────────────────
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        _banner(_error!, isError: true),
                      ],

                      const SizedBox(height: 20),
                      _submitBtn(),
                      const SizedBox(height: 16),
                      _buildLinks(),
                      const SizedBox(height: 20),
                      _buildDisclaimer(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Cabeçalho do modo ─────────────────────────────────────────────────────
  Widget _buildModeHeader() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: kGreen,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(color: kGreen.withValues(alpha: 0.30),
                blurRadius: 12, offset: const Offset(0, 5)),
            ],
          ),
          child: Icon(_modeIcon, size: 24, color: Colors.white),
        ),
        const SizedBox(height: 12),
        Text(_modeTitle, textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22, fontWeight: FontWeight.w700,
            color: kText, letterSpacing: -0.4, height: 1.1)),
        const SizedBox(height: 4),
        Text(_modeSubtitle, textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12, color: kTextMid,
            fontWeight: FontWeight.w500)),
      ],
    );
  }

  // ── Step indicator ────────────────────────────────────────────────────────
  Widget _buildStepIndicator() {
    final steps = _isEs ? ['Cuenta', 'Perfil'] : ['Conta', 'Perfil'];
    return Row(children: List.generate(steps.length, (i) {
      final done   = i < _regStep;
      final active = i == _regStep;
      return Expanded(child: Row(children: [
        Expanded(child: Column(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(1.5),
              color: done || active ? kGreen : kTextMid.withValues(alpha: 0.20),
            ),
          ),
          const SizedBox(height: 5),
          Text(steps[i], style: TextStyle(
            fontSize: 10, fontWeight: active ? FontWeight.w800 : FontWeight.w500,
            color: active ? kGreen : (done ? kGreenMid : kTextMid))),
        ])),
        if (i < steps.length - 1) const SizedBox(width: 8),
      ]));
    }));
  }

  // ── Campos login ──────────────────────────────────────────────────────────
  List<Widget> _loginFields() => [
    _field(_emailLabel, _emailCtrl, Icons.alternate_email_rounded,
      keyboard: TextInputType.emailAddress,
      validator: (v) {
        if (v?.trim().isEmpty ?? true) return _emailRequiredMsg;
        if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w+$').hasMatch(v!.trim())) return _emailInvalidMsg;
        return null;
      }),
    const SizedBox(height: 12),
    _fieldPassword(),
    const SizedBox(height: 12),
    _checkRow(
      value: _keepLoggedIn,
      label: _keepLoggedInLabel,
      onChanged: (v) => setState(() {
        _keepLoggedIn  = v ?? false;
        if (_keepLoggedIn) _rememberEmail = true;
      }),
    ),
  ];

  // ── Campos registro ───────────────────────────────────────────────────────
  List<Widget> _registerFields() {
    if (_regStep == 0) {
      return [
        _field(_emailLabel, _emailCtrl, Icons.alternate_email_rounded,
          keyboard: TextInputType.emailAddress,
          validator: (v) {
            if (v?.trim().isEmpty ?? true) return _emailRequiredMsg;
            if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w+$').hasMatch(v!.trim())) return _emailInvalidMsg;
            return null;
          }),
        const SizedBox(height: 12),
        _fieldPassword(),
      ];
    }
    return [
      _field(_fullNameLabel, _nameCtrl, Icons.badge_outlined,
        validator: (v) => (v?.trim().isEmpty ?? true) ? _nameRequiredMsg : null),
      const SizedBox(height: 12),
      _field(_professionLabel, _profCtrl, Icons.medical_services_outlined),
      const SizedBox(height: 12),
      _field(_institutionLabel, _instCtrl, Icons.apartment_rounded),
      const SizedBox(height: 18),
      // ── Task 3: Disclaimer médico obrigatório ──────────────────────────────
      _MedicalDisclaimerCheckbox(
        isEs: _isEs,
        accepted: _disclaimerAccepted,
        hasError: _disclaimerError,
        onChanged: (v) => setState(() {
          _disclaimerAccepted = v ?? false;
          if (_disclaimerAccepted) _disclaimerError = false;
        }),
      ),
    ];
  }

  // ── Campos reset ──────────────────────────────────────────────────────────
  List<Widget> _resetFields() => [
    _field(_emailLabel, _emailCtrl, Icons.alternate_email_rounded,
      keyboard: TextInputType.emailAddress,
      validator: (v) {
        if (v?.trim().isEmpty ?? true) return _emailRequiredMsg;
        if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w+$').hasMatch(v!.trim())) return _emailInvalidMsg;
        return null;
      }),
  ];

  // ── Campo genérico — borda 8px (sharp, diferente do 12px anterior) ─────
  Widget _field(String label, TextEditingController ctrl, IconData icon, {
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      textInputAction: TextInputAction.next,
      validator: validator,
      enableSuggestions: false,
      spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
      autocorrect: false,
      style: const TextStyle(fontSize: 14, color: kText, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 12, color: kTextMid, fontWeight: FontWeight.w500),
        prefixIcon: Icon(icon, size: 18, color: kGreenMid),
        filled: true,
        fillColor: kPanelCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: kTextMid.withValues(alpha: 0.18))),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: kGreen, width: 2)),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red)),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _fieldPassword() {
    return TextFormField(
      controller: _passCtrl,
      obscureText: _obscure,
      textInputAction: TextInputAction.done,
      enableSuggestions: false,
      spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
      autocorrect: false,
      validator: _mode == _Mode.register
          ? (v) => (v?.length ?? 0) < 6 ? _passwordMinMsg : null
          : (v) => (v?.isEmpty ?? true) ? _passwordRequiredMsg : null,
      style: const TextStyle(fontSize: 14, color: kText, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: _passwordLabel,
        labelStyle: TextStyle(
          fontSize: 12, color: kTextMid, fontWeight: FontWeight.w500),
        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: kGreenMid),
        suffixIcon: IconButton(
          icon: Icon(
            _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 18, color: kTextMid),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
        filled: true,
        fillColor: kPanelCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: kTextMid.withValues(alpha: 0.18))),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: kGreen, width: 2)),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red)),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _checkRow({
    required bool value,
    required String label,
    required ValueChanged<bool?> onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Row(children: [
        SizedBox(width: 20, height: 20,
          child: Checkbox(
            value: value, onChanged: onChanged,
            activeColor: kGreen,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            side: BorderSide(color: kTextMid.withValues(alpha: 0.35), width: 1.5),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          )),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(
          fontSize: 12, color: kTextMid, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _banner(String msg, {required bool isError}) {
    final color = isError ? Colors.red.shade700 : kGreen;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(
          isError ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
          size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: TextStyle(
          fontSize: 12, color: color, fontWeight: FontWeight.w600, height: 1.4))),
      ]),
    );
  }

  // ── Botão principal — borda 10px, gradiente verde direto (não preto) ────
  Widget _submitBtn() {
    String btnLabel = _modeBtn;
    if (_mode == _Mode.register && _regStep == 0) {
      btnLabel = _isEs ? 'Continuar' : 'Continuar';
    }

    return SizedBox(
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: _loading ? null : LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [kGreenMid, kGreen, const Color(0xFF075A3A)],
          ),
          boxShadow: _loading ? null : [
            BoxShadow(
              color: kGreen.withValues(alpha: 0.38),
              blurRadius: 12, offset: const Offset(0, 5)),
          ],
        ),
        child: ElevatedButton(
          onPressed: _loading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
          child: _loading
              ? const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white))
              : Text(btnLabel, style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700,
                  letterSpacing: 0.2, color: Colors.white)),
        ),
      ),
    );
  }

  // ── Links ─────────────────────────────────────────────────────────────────
  Widget _buildLinks() {
    if (_mode == _Mode.register && _regStep > 0) {
      return TextButton(
        onPressed: () { setState(() => _regStep--); _slideCtrl.forward(from: 0); },
        child: Text(_isEs ? '← Volver' : '← Voltar',
          style: const TextStyle(
            fontSize: 12, color: kGreen, fontWeight: FontWeight.w700)),
      );
    }
    if (_mode == _Mode.login) {
      return Column(children: [
        TextButton(
          onPressed: () => _switchMode(_Mode.reset),
          child: Text(_forgotPasswordLabel,
            style: const TextStyle(
              fontSize: 12, color: kGreenMid, fontWeight: FontWeight.w600)),
        ),
        Divider(height: 1, color: kTextMid.withValues(alpha: 0.15)),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(_noAccountLabel,
            style: TextStyle(fontSize: 12, color: kTextMid)),
          GestureDetector(
            onTap: () => _switchMode(_Mode.register),
            child: Text(_signUpLabel,
              style: const TextStyle(
                fontSize: 12, color: kGreen, fontWeight: FontWeight.w800)),
          ),
        ]),
      ]);
    }
    return TextButton(
      onPressed: () => _switchMode(_Mode.login),
      child: Text(_backToLoginLabel,
        style: const TextStyle(
          fontSize: 12, color: kGreen, fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildDisclaimer() {
    return Text(
      _legalDisclaimer,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 9.5, color: kTextMid.withValues(alpha: 0.55),
        fontWeight: FontWeight.w400, height: 1.5),
    );
  }

  // ── Strings i18n ──────────────────────────────────────────────────────────
  IconData get _modeIcon {
    switch (_mode) {
      case _Mode.login:    return Icons.fingerprint_rounded;
      case _Mode.register: return Icons.person_add_outlined;
      case _Mode.reset:    return Icons.lock_reset_rounded;
    }
  }

  String get _modeTitle {
    switch (_mode) {
      case _Mode.login:    return _isEs ? 'Acceder a mi cuenta'        : 'Acessar minha conta';
      case _Mode.register: return _isEs ? 'Solicitar acceso'           : 'Solicitar acesso';
      case _Mode.reset:    return _isEs ? 'Recuperar contraseña'       : 'Recuperar senha';
    }
  }

  String get _modeSubtitle {
    switch (_mode) {
      case _Mode.login:    return _isEs ? 'Plataforma exclusiva para profesionales'         : 'Plataforma exclusiva para profissionais';
      case _Mode.register: return _isEs ? 'Acceso aprobado por el equipo MedCases'         : 'Acesso aprovado pela equipe MedCases';
      case _Mode.reset:    return _isEs ? 'Te enviamos un enlace de recuperación por email' : 'Enviaremos um link de recuperação por e-mail';
    }
  }

  String get _modeBtn {
    switch (_mode) {
      case _Mode.login:    return _isEs ? 'Iniciar sesión'    : 'Entrar';
      case _Mode.register: return _isEs ? 'Enviar solicitud'   : 'Enviar solicitação';
      case _Mode.reset:    return _isEs ? 'Enviar enlace'     : 'Enviar link';
    }
  }

  String get _keepLoggedInLabel   => _isEs ? 'Mantener sesión activa'                  : 'Manter-me conectado';
  String get _fullNameLabel       => _isEs ? 'Nombre completo'                         : 'Nome completo';
  String get _nameRequiredMsg     => _isEs ? 'Ingresa tu nombre'                       : 'Informe seu nome';
  String get _emailLabel          => _isEs ? 'E-mail institucional'                    : 'E-mail institucional';
  String get _emailRequiredMsg    => _isEs ? 'Ingresa el correo'                       : 'Informe o e-mail';
  String get _emailInvalidMsg     => _isEs ? 'Correo inválido'                         : 'E-mail inválido';
  String get _professionLabel     => _isEs ? 'Especialidad / Cargo'                    : 'Especialidade / Cargo';
  String get _institutionLabel    => _isEs ? 'Hospital / Institución'                  : 'Hospital / Instituição';
  String get _forgotPasswordLabel => _isEs ? '¿Olvidaste tu contraseña?'               : 'Esqueceu a senha?';
  String get _noAccountLabel      => _isEs ? '¿Sin cuenta?  '                          : 'Sem conta?  ';
  String get _signUpLabel         => _isEs ? 'Solicitar acceso'                         : 'Solicitar acesso';
  String get _backToLoginLabel    => _isEs ? '← Volver al inicio'                      : '← Voltar ao início';
  String get _passwordLabel       => _isEs ? 'Contraseña'                               : 'Senha';
  String get _passwordMinMsg      => _isEs ? 'Mínimo 6 caracteres'                      : 'Mínimo 6 caracteres';
  String get _passwordRequiredMsg => _isEs ? 'Ingresa la contraseña'                    : 'Informe a senha';
  String get _legalDisclaimer     => _isEs
      ? 'Herramienta de apoyo clínico educativo. No sustituye el juicio clínico individual ni las guías institucionales vigentes.'
      : 'Ferramenta de apoio clínico educacional. Não substitui o julgamento clínico individual nem as diretrizes institucionais vigentes.';

  String _registerSuccessMsg() => _isEs
      ? 'Solicitud enviada. Tu acceso será revisado y habilitado por el equipo MedCases en breve.'
      : 'Solicitação enviada. Seu acesso será revisado e habilitado pela equipe MedCases em breve.';

  String _resetSuccessMsg(String email) => _isEs
      ? 'Enlace de recuperación enviado a $email. Revisa tu bandeja de entrada.'
      : 'Link de recuperação enviado para $email. Verifique sua caixa de entrada.';
}

// ══════════════════════════════════════════════════════════════════════════════
// HERO GEOMÉTRICO ANIMADO — formas vazadas (sem preenchimento sólido)
// ══════════════════════════════════════════════════════════════════════════════
class _HeroGeometric extends StatelessWidget {
  final Animation<double> rotAnim;
  final String lang;
  const _HeroGeometric({required this.rotAnim, required this.lang});

  bool get _isEs => lang == 'es';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F1116),  // verde muito escuro
            Color(0xFF0D3324),  // verde floresta
            Color(0xFF0A2218),  // intermediário
          ],
          stops: [0.0, 0.60, 1.0],
        ),
      ),
      child: Stack(children: [
        // ── Formas geométricas vazadas (stroke apenas) ─────────────────
        AnimatedBuilder(
          animation: rotAnim,
          builder: (_, __) => CustomPaint(
            painter: _GeoPainter(rotAnim.value),
            size: Size.infinite,
          ),
        ),

        // ── Logo + texto hero — centralizado na tela ──────────────────
        Positioned.fill(
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Empurra para a metade superior (hero ocupa 42%)
                Expanded(
                  flex: 42,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Badge topo — centralizado
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF0E7C52).withValues(alpha: 0.45)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            width: 6, height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF13A06A),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isEs ? 'Para profesionales de salud' : 'Para profissionais de saúde',
                            style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600,
                              color: Color(0xFF13A06A), letterSpacing: 0.3),
                          ),
                        ]),
                      ),

                      const SizedBox(height: 20),

                      // Logo — centralizado com ícone maior
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/icon/app_icon.png',
                            width: 56, height: 56,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 14),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('MedCases Pro',
                              style: TextStyle(
                                fontSize: 26, fontWeight: FontWeight.w800,
                                color: Colors.white, letterSpacing: -0.5, height: 1.0)),
                            const SizedBox(height: 4),
                            Text(
                              _isEs ? 'Apoyo clínico educacional' : 'Apoio clínico educacional',
                              style: TextStyle(
                                fontSize: 12,
                                color: const Color(0xFF13A06A).withValues(alpha: 0.90),
                                fontWeight: FontWeight.w600, letterSpacing: 0.3)),
                          ]),
                        ],
                      ),
                    ],
                  ),
                ),
                // Espaço reservado para o painel inferior (58%)
                const Expanded(flex: 58, child: SizedBox()),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PAINTER — formas geométricas vazadas rotacionando lentamente
// ══════════════════════════════════════════════════════════════════════════════
class _GeoPainter extends CustomPainter {
  final double rotation;
  const _GeoPainter(this.rotation);

  @override
  void paint(Canvas canvas, Size size) {
    final paintStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Hexágono grande direito superior — stroke verde claro
    paintStroke.color = const Color(0xFF0E7C52).withValues(alpha: 0.22);
    _drawHexagon(canvas, Offset(size.width * 0.85, size.height * 0.15),
      size.width * 0.38, rotation * 0.3, paintStroke);

    // Hexágono médio esquerdo — stroke verde médio
    paintStroke.color = const Color(0xFF13A06A).withValues(alpha: 0.15);
    _drawHexagon(canvas, Offset(size.width * 0.10, size.height * 0.68),
      size.width * 0.22, rotation * 0.5, paintStroke);

    // Círculo grande — stroke fino muito suave
    paintStroke.color = Colors.white.withValues(alpha: 0.04);
    paintStroke.strokeWidth = 0.8;
    canvas.drawCircle(
      Offset(size.width * 0.72, size.height * 0.78),
      size.width * 0.30, paintStroke);

    // Losango pequeno — stroke verde
    paintStroke.color = const Color(0xFF0E7C52).withValues(alpha: 0.18);
    paintStroke.strokeWidth = 1.0;
    _drawDiamond(canvas, Offset(size.width * 0.22, size.height * 0.25),
      size.width * 0.09, rotation * 0.8, paintStroke);

    // Cruz/plus geométrico
    paintStroke.color = const Color(0xFF13A06A).withValues(alpha: 0.12);
    _drawPlus(canvas, Offset(size.width * 0.60, size.height * 0.50),
      size.width * 0.05, rotation, paintStroke);
  }

  void _drawHexagon(Canvas canvas, Offset center, double radius,
      double rot, Paint paint) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = rot + (i * math.pi / 3);
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawDiamond(Canvas canvas, Offset center, double r,
      double rot, Paint paint) {
    final path = Path();
    for (int i = 0; i < 4; i++) {
      final angle = rot + (i * math.pi / 2) + math.pi / 4;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawPlus(Canvas canvas, Offset center, double r,
      double rot, Paint paint) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rot);
    canvas.drawLine(Offset(-r, 0), Offset(r, 0), paint);
    canvas.drawLine(Offset(0, -r), Offset(0, r), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GeoPainter oldDelegate) =>
      oldDelegate.rotation != rotation;
}

// ══════════════════════════════════════════════════════════════════════════════
// TASK 3 — Widget de Disclaimer Médico Obrigatório
// Aceito via checkbox no momento do cadastro (regStep==1 — etapa Perfil).
// Exigência Apple Guideline 1.4.1 — ferramenta educacional, não substitui médico.
// ══════════════════════════════════════════════════════════════════════════════
class _MedicalDisclaimerCheckbox extends StatelessWidget {
  final bool isEs;
  final bool accepted;
  final bool hasError;
  final ValueChanged<bool?> onChanged;

  const _MedicalDisclaimerCheckbox({
    required this.isEs,
    required this.accepted,
    required this.hasError,
    required this.onChanged,
  });

  static const _textPt =
      'O MedCases Pro é uma ferramenta de apoio educacional e consulta clínica '
      'para profissionais de saúde. As informações não substituem o julgamento '
      'clínico, protocolos institucionais ou avaliação médica individualizada.';

  static const _textEs =
      'MedCases Pro es una herramienta de apoyo educativo y consulta clínica '
      'para profesionales de salud. La información no sustituye el juicio '
      'clínico, los protocolos institucionales ni la evaluación médica '
      'individualizada.';

  @override
  Widget build(BuildContext context) {
    final disclaimerText = isEs ? _textEs : _textPt;
    final labelAccept = isEs
        ? 'Li e aceito os termos acima'
        : 'Li e aceito os termos acima';
    final errorMsg = isEs
        ? 'É necessário aceitar o termo para continuar.'
        : 'É necessário aceitar o termo para continuar.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Caixa de texto do disclaimer ───────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: hasError
                ? Colors.red.withValues(alpha: 0.05)
                : const Color(0xFF0E7C52).withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasError
                  ? Colors.red.withValues(alpha: 0.45)
                  : const Color(0xFF0E7C52).withValues(alpha: 0.30),
              width: 1.3,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(
                  Icons.health_and_safety_rounded,
                  size: 16,
                  color: hasError ? Colors.red.shade700 : const Color(0xFF0E7C52),
                ),
                const SizedBox(width: 7),
                Text(
                  isEs ? 'Declaración de uso profesional' : 'Declaração de uso profissional',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: hasError ? Colors.red.shade700 : const Color(0xFF0D2B1E),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Text(
                disclaimerText,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF4A6B58),
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // ── Checkbox de aceite ─────────────────────────────────────────────
        GestureDetector(
          onTap: () => onChanged(!accepted),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 22, height: 22,
                child: Checkbox(
                  value: accepted,
                  onChanged: onChanged,
                  activeColor: const Color(0xFF0E7C52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
                  side: BorderSide(
                    color: hasError
                        ? Colors.red
                        : const Color(0xFF4A6B58).withValues(alpha: 0.40),
                    width: 1.5,
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    labelAccept,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: hasError
                          ? Colors.red.shade700
                          : const Color(0xFF4A6B58),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Mensagem de erro se não aceito ─────────────────────────────────
        if (hasError) ...[
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.warning_amber_rounded,
                size: 13, color: Colors.red.shade700),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                errorMsg,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ]),
        ],
      ],
    );
  }
}
