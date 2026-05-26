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
    with SingleTickerProviderStateMixin {
  _Mode _mode = _Mode.login;
  bool _loading = false;
  bool _obscure = true;
  bool _rememberEmail = false;
  bool _keepLoggedIn  = false;
  String? _error;
  String? _success;

  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _nameCtrl  = TextEditingController();
  final _profCtrl  = TextEditingController();
  final _instCtrl  = TextEditingController();
  final _formKey   = GlobalKey<FormState>();
  late AnimationController _anim;
  late Animation<double>   _fade;

  // ── Paleta ────────────────────────────────────────────────────────────────
  static const kDark  = Color(0xFF0F1C14);
  static const kGreen = Color(0xFF075f45);
  static const kGold  = Color(0xFFC5A365);
  static const kGoldL = Color(0xFFFFE8A6);
  static const kCream = Color(0xFFFFFDF8);

  static const _kPrefEmail    = 'login_saved_email';
  static const _kPrefRemember = 'login_remember_email';
  static const _kKeepLoggedIn = 'session_keep_logged_in';

  // ── Onboarding steps (modo registro) ────────────────────────────────────
  int _regStep = 0; // 0=conta, 1=perfil, 2=confirmação

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _anim.forward();
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
    _anim.dispose();
    _emailCtrl.dispose(); _passCtrl.dispose(); _nameCtrl.dispose();
    _profCtrl.dispose();  _instCtrl.dispose();
    super.dispose();
  }

  void _switchMode(_Mode m) {
    setState(() { _mode = m; _error = null; _success = null; _regStep = 0; });
    _anim.forward(from: 0);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // No modo registro: avança steps antes de submeter
    if (_mode == _Mode.register && _regStep < 1) {
      setState(() => _regStep++);
      _anim.forward(from: 0);
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
      result = await AuthService.register(
        email: _emailCtrl.text,
        password: _passCtrl.text,
        displayName: _nameCtrl.text,
        profession: _profCtrl.text.isNotEmpty ? _profCtrl.text : null,
        institution: _instCtrl.text.isNotEmpty ? _instCtrl.text : null,
      );
      if (result.success && result.user != null && result.user!.isPending) {
        setState(() {
          _loading = false;
          _success = _registerSuccessMsg();
          _mode = _Mode.login;
          _regStep = 0;
        });
        return;
      }
    } else {
      result = await AuthService.resetPassword(_emailCtrl.text);
      if (result.success) {
        setState(() {
          _loading = false;
          _success = _resetSuccessMsg(_emailCtrl.text);
        });
        return;
      }
    }

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
    return Scaffold(
      backgroundColor: kDark,
      body: Stack(children: [
        // ── fundo decorativo ───────────────────────────────────────────────
        Positioned(
          top: -80, right: -60,
          child: Container(
            width: 280, height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kGreen.withValues(alpha: 0.07),
            ),
          ),
        ),
        Positioned(
          bottom: -60, left: -40,
          child: Container(
            width: 220, height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kGold.withValues(alpha: 0.05),
            ),
          ),
        ),

        // ── conteúdo ──────────────────────────────────────────────────────
        SafeArea(
          child: Column(children: [
            // Botão voltar
            if (widget.onBack != null)
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 0, 0),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onBack,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.white.withValues(alpha: 0.06),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white70, size: 18),
                      ),
                    ),
                  ),
                ),
              ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                child: FadeTransition(
                  opacity: _fade,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 28),
                      if (_mode == _Mode.register) _buildStepIndicator(),
                      if (_mode == _Mode.register) const SizedBox(height: 18),
                      _buildCard(),
                      const SizedBox(height: 20),
                      _buildDisclaimer(),
                    ],
                  ),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Column(children: [
      // Logo com glow dourado
      Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: kGold.withValues(alpha: 0.22), blurRadius: 44, spreadRadius: 8),
            BoxShadow(color: kGreen.withValues(alpha: 0.18), blurRadius: 60, spreadRadius: 4),
          ],
        ),
        child: Image.asset('assets/icon/app_icon.png', width: 88, height: 88, fit: BoxFit.contain),
      ),
      const SizedBox(height: 16),
      const Text('MedCases Pro', style: TextStyle(
        fontSize: 28, fontWeight: FontWeight.w900,
        color: Colors.white, letterSpacing: -0.8, height: 1.0)),
      const SizedBox(height: 5),
      Text(
        _isEs ? 'Apoyo clínico educativo' : 'Apoio clínico educacional',
        style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.40),
          fontWeight: FontWeight.w500, letterSpacing: 0.2)),
      const SizedBox(height: 8),
      // Linha de apoio educacional (substitui o badge beta — App Store 2.2.0)
      Text(
        _isEs
          ? 'Apoyo a la decisión clínica · Solo para profesionales de salud'
          : 'Apoio à decisão clínica · Exclusivo para profissionais de saúde',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w500,
          color: Colors.white.withValues(alpha: 0.32),
          letterSpacing: 0.3,
        ),
        textAlign: TextAlign.center,
      ),
    ]);
  }

  // ── Step indicator (registro) ─────────────────────────────────────────────
  Widget _buildStepIndicator() {
    final steps = _isEs
        ? ['Cuenta', 'Perfil']
        : ['Conta', 'Perfil'];
    return Row(children: List.generate(steps.length, (i) {
      final done   = i < _regStep;
      final active = i == _regStep;
      return Expanded(child: Row(children: [
        Expanded(child: Column(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: done || active ? kGold : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          const SizedBox(height: 5),
          Text(steps[i], style: TextStyle(
            fontSize: 10, fontWeight: active ? FontWeight.w800 : FontWeight.w500,
            color: active ? kGoldL : (done ? kGold : Colors.white.withValues(alpha: 0.3)))),
        ])),
        if (i < steps.length - 1) const SizedBox(width: 8),
      ]));
    }));
  }

  // ── Card do formulário ────────────────────────────────────────────────────
  Widget _buildCard() {
    return Container(
      decoration: BoxDecoration(
        color: kCream,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 40, offset: const Offset(0, 12)),
          BoxShadow(color: kGreen.withValues(alpha: 0.10), blurRadius: 60, offset: const Offset(0, 20)),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Título do modo
          Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                color: kGreen.withValues(alpha: 0.10),
                border: Border.all(color: kGreen.withValues(alpha: 0.25)),
              ),
              child: Icon(_modeIcon, size: 16, color: kGreen),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_modeTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kDark)),
              Text(_modeSubtitle, style: TextStyle(fontSize: 11, color: kDark.withValues(alpha: 0.45), fontWeight: FontWeight.w500)),
            ]),
          ]),
          const SizedBox(height: 18),

          // Banner sucesso
          if (_success != null) ...[
            _banner(_success!, isError: false),
            const SizedBox(height: 14),
          ],

          // ── Campos por modo / step ──────────────────────────────────────
          if (_mode == _Mode.login) ..._loginFields(),
          if (_mode == _Mode.register) ..._registerFields(),
          if (_mode == _Mode.reset)   ..._resetFields(),

          // Banner erro
          if (_error != null) ...[
            const SizedBox(height: 10),
            _banner(_error!, isError: true),
          ],

          const SizedBox(height: 16),
          _submitBtn(),
          const SizedBox(height: 14),
          _buildLinks(),
        ]),
      ),
    );
  }

  // ── Campos login ──────────────────────────────────────────────────────────
  List<Widget> _loginFields() => [
    _field(_emailLabel, _emailCtrl, Icons.email_outlined,
      keyboard: TextInputType.emailAddress,
      validator: (v) {
        if (v?.trim().isEmpty ?? true) return _emailRequiredMsg;
        if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w+$').hasMatch(v!.trim())) return _emailInvalidMsg;
        return null;
      }),
    const SizedBox(height: 10),
    _fieldPassword(),
    const SizedBox(height: 10),
    // Manter conectado
    _checkRow(
      value: _keepLoggedIn,
      label: _keepLoggedInLabel,
      onChanged: (v) => setState(() {
        _keepLoggedIn  = v ?? false;
        if (_keepLoggedIn) _rememberEmail = true;
      }),
    ),
  ];

  // ── Campos registro por step ───────────────────────────────────────────────
  List<Widget> _registerFields() {
    if (_regStep == 0) {
      // Step 0: e-mail + senha
      return [
        _field(_emailLabel, _emailCtrl, Icons.email_outlined,
          keyboard: TextInputType.emailAddress,
          validator: (v) {
            if (v?.trim().isEmpty ?? true) return _emailRequiredMsg;
            if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w+$').hasMatch(v!.trim())) return _emailInvalidMsg;
            return null;
          }),
        const SizedBox(height: 10),
        _fieldPassword(),
      ];
    }
    // Step 1: nome + profissão + instituição
    return [
      _field(_fullNameLabel, _nameCtrl, Icons.person_outline_rounded,
        validator: (v) => (v?.trim().isEmpty ?? true) ? _nameRequiredMsg : null),
      const SizedBox(height: 10),
      _field(_professionLabel, _profCtrl, Icons.work_outline_rounded),
      const SizedBox(height: 10),
      _field(_institutionLabel, _instCtrl, Icons.local_hospital_outlined),
    ];
  }

  // ── Campos reset ───────────────────────────────────────────────────────────
  List<Widget> _resetFields() => [
    _field(_emailLabel, _emailCtrl, Icons.email_outlined,
      keyboard: TextInputType.emailAddress,
      validator: (v) {
        if (v?.trim().isEmpty ?? true) return _emailRequiredMsg;
        if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w+$').hasMatch(v!.trim())) return _emailInvalidMsg;
        return null;
      }),
  ];

  // ── Campo genérico ─────────────────────────────────────────────────────────
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
      style: const TextStyle(fontSize: 14, color: kDark, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 12, color: kDark.withValues(alpha: 0.50), fontWeight: FontWeight.w600),
        prefixIcon: Icon(icon, size: 18, color: kGreen),
        filled: true,
        fillColor: const Color(0xFFF5F0E8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kDark.withValues(alpha: 0.09))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGreen, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
      style: const TextStyle(fontSize: 14, color: kDark, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: _passwordLabel,
        labelStyle: TextStyle(fontSize: 12, color: kDark.withValues(alpha: 0.50), fontWeight: FontWeight.w600),
        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: kGreen),
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 18, color: kDark.withValues(alpha: 0.35)),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
        filled: true,
        fillColor: const Color(0xFFF5F0E8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kDark.withValues(alpha: 0.09))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGreen, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _checkRow({required bool value, required String label, required ValueChanged<bool?> onChanged}) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Row(children: [
        SizedBox(width: 20, height: 20,
          child: Checkbox(
            value: value, onChanged: onChanged,
            activeColor: kGreen,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            side: BorderSide(color: kDark.withValues(alpha: 0.25), width: 1.5),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          )),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 12, color: kDark.withValues(alpha: 0.60), fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _banner(String msg, {required bool isError}) {
    final color = isError ? Colors.red : kGreen;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600, height: 1.4))),
      ]),
    );
  }

  // ── Botão principal ────────────────────────────────────────────────────────
  Widget _submitBtn() {
    // Label dinâmico por step
    String btnLabel = _modeBtn;
    if (_mode == _Mode.register && _regStep == 0) {
      btnLabel = _isEs ? 'Continuar →' : 'Continuar →';
    }

    return SizedBox(
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: _loading ? null : const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF162E1F), Color(0xFF0F1C14), Color(0xFF0A3022)],
          ),
          boxShadow: _loading ? null : [
            BoxShadow(color: const Color(0xFF0F1C14).withValues(alpha: 0.50), blurRadius: 14, offset: const Offset(0, 5)),
          ],
        ),
        child: ElevatedButton(
          onPressed: _loading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: kGoldL,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: _loading
              ? const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: kGoldL))
              : Text(btnLabel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.3, color: kGoldL)),
        ),
      ),
    );
  }

  // ── Links ─────────────────────────────────────────────────────────────────
  Widget _buildLinks() {
    if (_mode == _Mode.register && _regStep > 0) {
      return TextButton(
        onPressed: () { setState(() => _regStep--); _anim.forward(from: 0); },
        child: Text(_isEs ? '← Volver' : '← Voltar',
          style: TextStyle(fontSize: 12, color: kGreen, fontWeight: FontWeight.w700)),
      );
    }
    if (_mode == _Mode.login) {
      return Column(children: [
        TextButton(
          onPressed: () => _switchMode(_Mode.reset),
          child: Text(_forgotPasswordLabel,
            style: TextStyle(fontSize: 12, color: kGreen, fontWeight: FontWeight.w700)),
        ),
        const Divider(height: 1),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(_noAccountLabel,
            style: TextStyle(fontSize: 12, color: kDark.withValues(alpha: 0.50))),
          GestureDetector(
            onTap: () => _switchMode(_Mode.register),
            child: Text(_signUpLabel,
              style: const TextStyle(fontSize: 12, color: kGreen, fontWeight: FontWeight.w900)),
          ),
        ]),
      ]);
    }
    return TextButton(
      onPressed: () => _switchMode(_Mode.login),
      child: Text(_backToLoginLabel,
        style: TextStyle(fontSize: 12, color: kGreen, fontWeight: FontWeight.w700)),
    );
  }

  // ── Disclaimer ────────────────────────────────────────────────────────────
  Widget _buildDisclaimer() {
    return Text(
      _legalDisclaimer,
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 9.5, color: Colors.white.withValues(alpha: 0.28),
        fontWeight: FontWeight.w500, height: 1.5),
    );
  }

  // ── Strings i18n ──────────────────────────────────────────────────────────
  IconData get _modeIcon {
    switch (_mode) {
      case _Mode.login:    return Icons.login_rounded;
      case _Mode.register: return Icons.person_add_outlined;
      case _Mode.reset:    return Icons.lock_reset_rounded;
    }
  }

  String get _modeTitle {
    switch (_mode) {
      case _Mode.login:    return _isEs ? 'Iniciar sesión'          : 'Entrar na sua conta';
      case _Mode.register: return _isEs ? 'Crear cuenta'            : 'Criar conta';
      case _Mode.reset:    return _isEs ? 'Restablecer contraseña'  : 'Redefinir senha';
    }
  }

  String get _modeSubtitle {
    switch (_mode) {
      case _Mode.login:    return _isEs ? 'Usa tu correo y contraseña registrados'               : 'Use seu e-mail e senha cadastrados';
      case _Mode.register: return _isEs ? 'Registro sujeto a aprobación del administrador'       : 'Cadastro sujeito à aprovação do administrador';
      case _Mode.reset:    return _isEs ? 'Enviaremos un enlace a tu correo'                     : 'Enviaremos um link para seu e-mail';
    }
  }

  String get _modeBtn {
    switch (_mode) {
      case _Mode.login:    return _isEs ? 'Iniciar sesión'   : 'Entrar';
      case _Mode.register: return _isEs ? 'Solicitar acceso' : 'Solicitar acesso';
      case _Mode.reset:    return _isEs ? 'Enviar enlace'    : 'Enviar link';
    }
  }

  String get _keepLoggedInLabel   => _isEs ? 'Mantener sesión iniciada'              : 'Manter conectado';
  String get _fullNameLabel       => _isEs ? 'Nombre completo'                       : 'Nome completo';
  String get _nameRequiredMsg     => _isEs ? 'Ingresa tu nombre'                     : 'Informe seu nome';
  String get _emailLabel          => _isEs ? 'Correo profesional'                    : 'E-mail profissional';
  String get _emailRequiredMsg    => _isEs ? 'Ingresa el correo'                     : 'Informe o e-mail';
  String get _emailInvalidMsg     => _isEs ? 'Correo inválido'                       : 'E-mail inválido';
  String get _professionLabel     => _isEs ? 'Profesión (ej: Médico, Residente)'     : 'Profissão (ex: Médico, Residente)';
  String get _institutionLabel    => _isEs ? 'Institución / Hospital'                : 'Instituição / Hospital';
  String get _forgotPasswordLabel => _isEs ? '¿Olvidaste tu contraseña?'             : 'Esqueceu a senha?';
  String get _noAccountLabel      => _isEs ? '¿No tienes cuenta?  '                 : 'Não tem conta?  ';
  String get _signUpLabel         => _isEs ? 'Registrarse'                           : 'Cadastrar-se';
  String get _backToLoginLabel    => _isEs ? '← Volver al inicio de sesión'         : '← Voltar para o login';
  String get _passwordLabel       => _isEs ? 'Contraseña'                            : 'Senha';
  String get _passwordMinMsg      => _isEs ? 'Mínimo 6 caracteres'                   : 'Mínimo 6 caracteres';
  String get _passwordRequiredMsg => _isEs ? 'Ingresa la contraseña'                 : 'Informe a senha';
  String get _legalDisclaimer     => _isEs
      ? 'Uso educativo y de apoyo clínico. No reemplaza la evaluación médica individual ni las directrices institucionales.'
      : 'Uso educacional e de apoio clínico. Não substitui avaliação médica individual nem diretrizes institucionais.';

  String _registerSuccessMsg() => _isEs
      ? 'Registro realizado. Tu cuenta está pendiente de aprobación del administrador. Recibirás acceso en breve.'
      : 'Cadastro realizado. Sua conta está aguardando aprovação do administrador. Você receberá acesso em breve.';

  String _resetSuccessMsg(String email) => _isEs
      ? 'Enlace de restablecimiento enviado a $email. Revisa tu bandeja de entrada.'
      : 'Link de redefinição enviado para $email. Verifique sua caixa de entrada.';
}
