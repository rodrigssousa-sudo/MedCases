import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  /// Callback opcional — quando fornecido, exibe botão voltar (usado no preview inline).
  final VoidCallback? onBack;
  const LoginScreen({super.key, this.onBack});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum _Mode { login, register, reset }

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  _Mode _mode = _Mode.login;
  bool _loading = false;
  bool _obscure = true;
  bool _rememberEmail = false;
  bool _keepLoggedIn  = false;   // "Manter conectado" — persiste sessão completa
  String? _error;
  String? _success;

  final _emailCtrl       = TextEditingController();
  final _passCtrl        = TextEditingController();
  final _nameCtrl        = TextEditingController();
  final _profCtrl        = TextEditingController();
  final _instCtrl        = TextEditingController();
  final _formKey         = GlobalKey<FormState>();
  late AnimationController _anim;
  late Animation<double> _fade;

  static const kDark   = Color(0xFF07110d);
  static const kGreen  = Color(0xFF075f45);
  static const kGoldL  = Color(0xFFFFE8A6);
  static const kCream  = Color(0xFFFFFDF8);

  static const _kPrefEmail      = 'login_saved_email';
  static const _kPrefRemember   = 'login_remember_email';
  // _kKeepLoggedIn espelha AuthService._kKeepLoggedIn — lido aqui apenas para
  // inicializar o checkbox; a escrita real é feita pelo AuthService.saveSession().
  static const _kKeepLoggedIn   = 'session_keep_logged_in';

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _anim.forward();
    _loadSavedEmail();
  }

  Future<void> _loadSavedEmail() async {
    try {
      final p = await SharedPreferences.getInstance();
      final remember     = p.getBool(_kPrefRemember)  ?? false;
      final keepLoggedIn = p.getBool(_kKeepLoggedIn)  ?? false;
      final email        = p.getString(_kPrefEmail)   ?? '';
      setState(() {
        _keepLoggedIn  = keepLoggedIn;
        // Se "Manter conectado" está ativo, "Lembrar e-mail" também fica marcado
        _rememberEmail = remember || keepLoggedIn;
        if (_rememberEmail && email.isNotEmpty) {
          _emailCtrl.text = email;
        }
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
      // Se "Manter conectado" NÃO está marcado, garante que a chave de sessão
      // seja removida agora (antes do login bem-sucedido limpar qualquer resíduo).
      if (!_keepLoggedIn) {
        await AuthService.clearSession();
      }
    } catch (_) {}
  }

  /// Chamado APÓS login bem-sucedido com "Manter conectado" marcado.
  /// Persiste refreshToken + userMap no SharedPreferences via AuthService.
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
    setState(() { _mode = m; _error = null; _success = null; });
    _anim.forward(from: 0);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _loading = true; _error = null; _success = null; });

    AuthResult result;

    if (_mode == _Mode.login) {
      // Persiste email antes de fazer o login
      await _persistEmail(_emailCtrl.text.trim());
      result = await AuthService.login(
        email: _emailCtrl.text,
        password: _passCtrl.text,
      );
      // Se login OK e "Manter conectado" marcado → salva sessão completa
      if (result.success) await _saveSessionIfRequested(result);
      // Web inline: onBack não é necessário — _AuthGate troca o widget raiz
      // automaticamente quando webUser.value muda. Nada a fazer aqui.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDark,
      // Botão voltar quando LoginScreen está inline (preview pré-login)
      appBar: widget.onBack != null
          ? AppBar(
              backgroundColor: kDark,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
                onPressed: widget.onBack,
              ),
            )
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: FadeTransition(
            opacity: _fade,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ────────────────────────────────────────────────
                _buildHeader(),
                const SizedBox(height: 36),

                // ── Card do formulário ────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: kCream,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 32, offset: const Offset(0, 8))],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Título do modo
                        Text(
                          _modeTitle,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: kDark),
                        ),
                        Text(
                          _modeSubtitle,
                          style: TextStyle(fontSize: 12, color: kDark.withValues(alpha: 0.55), fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 20),

                        // Mensagem de sucesso
                        if (_success != null) ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: kGreen.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: kGreen.withValues(alpha: 0.3)),
                            ),
                            child: Text(_success!, style: const TextStyle(fontSize: 13, color: kGreen, fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Nome (só no cadastro)
                        if (_mode == _Mode.register) ...[
                          _field(_fullNameLabel, _nameCtrl, Icons.person_outline_rounded,
                            validator: (v) => (v?.trim().isEmpty ?? true) ? _nameRequiredMsg : null),
                          const SizedBox(height: 12),
                        ],

                        // E-mail
                        _field(_emailLabel, _emailCtrl, Icons.email_outlined,
                          keyboard: TextInputType.emailAddress,
                          validator: (v) {
                            if (v?.trim().isEmpty ?? true) return _emailRequiredMsg;
                            if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w+$').hasMatch(v!.trim())) return _emailInvalidMsg;
                            return null;
                          }),
                        const SizedBox(height: 12),

                        // Senha (não no reset)
                        if (_mode != _Mode.reset) ...[
                          _fieldPassword(),
                          const SizedBox(height: 8),
                        ],

                        // Checkbox "Manter conectado" — só no modo login
                        if (_mode == _Mode.login) ...[
                          GestureDetector(
                            onTap: () => setState(() {
                              _keepLoggedIn  = !_keepLoggedIn;
                              // "Manter conectado" implica "Lembrar e-mail"
                              if (_keepLoggedIn) _rememberEmail = true;
                            }),
                            child: Row(children: [
                              SizedBox(
                                width: 20, height: 20,
                                child: Checkbox(
                                  value: _keepLoggedIn,
                                  onChanged: (v) => setState(() {
                                    _keepLoggedIn  = v ?? false;
                                    if (_keepLoggedIn) _rememberEmail = true;
                                  }),
                                  activeColor: kGreen,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  side: BorderSide(color: kDark.withValues(alpha: 0.3), width: 1.5),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _keepLoggedInLabel,
                                style: TextStyle(fontSize: 12, color: kDark.withValues(alpha: 0.65), fontWeight: FontWeight.w600),
                              ),
                            ]),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Profissão + Instituição (só no cadastro)
                        if (_mode == _Mode.register) ...[
                          _field(_professionLabel, _profCtrl, Icons.work_outline_rounded),
                          const SizedBox(height: 12),
                          _field(_institutionLabel, _instCtrl, Icons.local_hospital_outlined),
                          const SizedBox(height: 12),
                        ],

                        // Mensagem de erro
                        if (_error != null) ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                            ),
                            child: Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Botão principal
                        _submitBtn(),

                        const SizedBox(height: 16),

                        // Links secundários
                        _buildLinks(),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                // Aviso legal
                Text(
                  _legalDisclaimer,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.35), fontWeight: FontWeight.w500, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Column(
      children: [
        // ── Ícone M+ grande ────────────────────────────────────────────────
        Image.asset(
          'assets/icon/app_icon.png',
          width: 110,
          height: 110,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 16),
        const Text(
          'MedCases Pro',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
        ),
        const SizedBox(height: 14),
        // ── Badge VERSÃO BETA ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: const Color(0xFFFFB800).withValues(alpha: 0.12),
            border: Border.all(color: const Color(0xFFFFB800).withValues(alpha: 0.55), width: 1.5),
          ),
          child: Text(
            'VERSÃO BETA — App em fase de testes',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFFFFCC44),
              letterSpacing: 0.4,
            ),
          ),
        ),
      ],
    );
  }

  // ── Campo de texto ────────────────────────────────────────────────────────
  Widget _field(String label, TextEditingController ctrl, IconData icon, {
    TextInputType keyboard = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      textInputAction: textInputAction,
      validator: validator,
      enableSuggestions: false,
      spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
      autocorrect: false,
      style: const TextStyle(fontSize: 14, color: kDark, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 12, color: kDark.withValues(alpha: 0.55), fontWeight: FontWeight.w600),
        prefixIcon: Icon(icon, size: 18, color: kGreen),
        filled: true,
        fillColor: const Color(0xFFF5F0E8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kDark.withValues(alpha: 0.1))),
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
        labelStyle: TextStyle(fontSize: 12, color: kDark.withValues(alpha: 0.55), fontWeight: FontWeight.w600),
        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: kGreen),
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: kDark.withValues(alpha: 0.4)),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
        filled: true,
        fillColor: const Color(0xFFF5F0E8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kDark.withValues(alpha: 0.1))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGreen, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  // ── Botão principal ───────────────────────────────────────────────────────
  Widget _submitBtn() {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: _loading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: kDark,
          foregroundColor: kGoldL,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: _loading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: kGoldL))
            : Text(_modeBtn, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.3)),
      ),
    );
  }

  // ── Links de navegação entre modos ───────────────────────────────────────
  Widget _buildLinks() {
    if (_mode == _Mode.login) {
      return Column(
        children: [
          TextButton(
            onPressed: () => _switchMode(_Mode.reset),
            child: Text(_forgotPasswordLabel, style: TextStyle(fontSize: 12, color: kGreen, fontWeight: FontWeight.w700)),
          ),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(_noAccountLabel, style: TextStyle(fontSize: 12, color: kDark.withValues(alpha: 0.55))),
            GestureDetector(
              onTap: () => _switchMode(_Mode.register),
              child: Text(_signUpLabel, style: const TextStyle(fontSize: 12, color: kGreen, fontWeight: FontWeight.w900)),
            ),
          ]),
        ],
      );
    } else {
      return TextButton(
        onPressed: () => _switchMode(_Mode.login),
        child: Text(_backToLoginLabel, style: TextStyle(fontSize: 12, color: kGreen, fontWeight: FontWeight.w700)),
      );
    }
  }

  // ── Helpers de idioma ────────────────────────────────────────────────────
  // LoginScreen não tem AppProvider (pré-auth); lê a pref salva localmente.
  String _currentLang = 'es';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    SharedPreferences.getInstance().then((prefs) {
      final lang = prefs.getString('lang') ?? 'es';
      if (mounted && lang != _currentLang) setState(() => _currentLang = lang);
    });
  }

  bool get _isEs => _currentLang == 'es';

  String get _modeTitle {
    switch (_mode) {
      case _Mode.login:    return _isEs ? 'Iniciar sesión'           : 'Entrar na sua conta';
      case _Mode.register: return _isEs ? 'Crear cuenta'             : 'Criar conta';
      case _Mode.reset:    return _isEs ? 'Restablecer contraseña'   : 'Redefinir senha';
    }
  }

  String get _modeSubtitle {
    switch (_mode) {
      case _Mode.login:    return _isEs ? 'Usa tu correo y contraseña registrados'                   : 'Use seu e-mail e senha cadastrados';
      case _Mode.register: return _isEs ? 'Registro sujeto a aprobación del administrador'           : 'Cadastro sujeito à aprovação do administrador';
      case _Mode.reset:    return _isEs ? 'Enviaremos un enlace a tu correo'                         : 'Enviaremos um link para seu e-mail';
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
  String get _fullNameLabel       => _isEs ? 'Nombre completo'                      : 'Nome completo';
  String get _nameRequiredMsg     => _isEs ? 'Ingresa tu nombre'                    : 'Informe seu nome';
  String get _emailLabel          => _isEs ? 'Correo profesional'                   : 'E-mail profissional';
  String get _emailRequiredMsg    => _isEs ? 'Ingresa el correo'                    : 'Informe o e-mail';
  String get _emailInvalidMsg     => _isEs ? 'Correo inválido'                      : 'E-mail inválido';
  String get _professionLabel     => _isEs ? 'Profesión (ej: Médico, Residente)'    : 'Profissão (ex: Médico, Residente)';
  String get _institutionLabel    => _isEs ? 'Institución / Hospital'               : 'Instituição / Hospital';
  String get _forgotPasswordLabel => _isEs ? '¿Olvidaste tu contraseña?'            : 'Esqueceu a senha?';
  String get _noAccountLabel      => _isEs ? '¿No tienes cuenta?  '                : 'Não tem conta?  ';
  String get _signUpLabel         => _isEs ? 'Registrarse'                          : 'Cadastrar-se';
  String get _backToLoginLabel    => _isEs ? '← Volver al inicio de sesión'        : '← Voltar para o login';
  String get _passwordLabel       => _isEs ? 'Contraseña'                           : 'Senha';
  String get _passwordMinMsg      => _isEs ? 'Mínimo 6 caracteres'                  : 'Mínimo 6 caracteres';
  String get _passwordRequiredMsg => _isEs ? 'Ingresa la contraseña'                : 'Informe a senha';
  String get _legalDisclaimer     => _isEs
      ? 'Uso educativo y de apoyo clínico. No reemplaza la evaluación médica individual ni las directrices institucionales.'
      : 'Uso educacional e de apoio clínico. Não substitui avaliação médica individual nem diretrizes institucionais.';

  String _registerSuccessMsg() => _isEs
      ? '✅ ¡Registro realizado!\n\nTu cuenta está pendiente de aprobación del administrador. Recibirás acceso en breve.'
      : '✅ Cadastro realizado!\n\nSua conta está aguardando aprovação do administrador. Você receberá acesso em breve.';

  String _resetSuccessMsg(String email) => _isEs
      ? '✅ Correo de restablecimiento enviado a $email.\n\nRevisa tu bandeja de entrada.'
      : '✅ E-mail de redefinição enviado para $email.\n\nVerifique sua caixa de entrada.';
}


