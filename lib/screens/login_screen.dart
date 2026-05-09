import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/brand_mark.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum _Mode { login, register, reset }

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  _Mode _mode = _Mode.login;
  bool _loading = false;
  bool _obscure = true;
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
  static const kGold   = Color(0xFFC5A365);
  static const kGoldL  = Color(0xFFFFE8A6);
  static const kCream  = Color(0xFFFFFDF8);

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _anim.forward();
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
      result = await AuthService.login(
        email: _emailCtrl.text,
        password: _passCtrl.text,
      );
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
          _success = '✅ Cadastro realizado!\n\nSua conta está aguardando aprovação do administrador. Você receberá acesso em breve.';
          _mode = _Mode.login;
        });
        return;
      }
    } else {
      result = await AuthService.resetPassword(_emailCtrl.text);
      if (result.success) {
        setState(() {
          _loading = false;
          _success = '✅ E-mail de redefinição enviado para ${_emailCtrl.text}.\n\nVerifique sua caixa de entrada.';
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
                          _field('Nome completo', _nameCtrl, Icons.person_outline_rounded,
                            validator: (v) => (v?.trim().isEmpty ?? true) ? 'Informe seu nome' : null),
                          const SizedBox(height: 12),
                        ],

                        // E-mail
                        _field('E-mail profissional', _emailCtrl, Icons.email_outlined,
                          keyboard: TextInputType.emailAddress,
                          validator: (v) {
                            if (v?.trim().isEmpty ?? true) return 'Informe o e-mail';
                            if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w+$').hasMatch(v!.trim())) return 'E-mail inválido';
                            return null;
                          }),
                        const SizedBox(height: 12),

                        // Senha (não no reset)
                        if (_mode != _Mode.reset) ...[
                          _fieldPassword(),
                          const SizedBox(height: 12),
                        ],

                        // Profissão + Instituição (só no cadastro)
                        if (_mode == _Mode.register) ...[
                          _field('Profissão (ex: Médico, Residente)', _profCtrl, Icons.work_outline_rounded),
                          const SizedBox(height: 12),
                          _field('Instituição / Hospital', _instCtrl, Icons.local_hospital_outlined),
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
                  'Uso educacional e de apoio clínico. Não substitui avaliação médica individual nem diretrizes institucionais.',
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
        const BrandMark(small: false),
        const SizedBox(height: 16),
        Text(
          'MedCases Pro',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kGold.withValues(alpha: 0.4)),
            color: kGold.withValues(alpha: 0.1),
          ),
          child: Text(
            'Cockpit Clínico  •  Doses  •  Protocolos',
            style: TextStyle(fontSize: 11, color: kGoldL.withValues(alpha: 0.85), fontWeight: FontWeight.w700, letterSpacing: 0.3),
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
          ? (v) => (v?.length ?? 0) < 6 ? 'Mínimo 6 caracteres' : null
          : (v) => (v?.isEmpty ?? true) ? 'Informe a senha' : null,
      style: const TextStyle(fontSize: 14, color: kDark, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: 'Senha',
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
            child: Text('Esqueceu a senha?', style: TextStyle(fontSize: 12, color: kGreen, fontWeight: FontWeight.w700)),
          ),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('Não tem conta?  ', style: TextStyle(fontSize: 12, color: kDark.withValues(alpha: 0.55))),
            GestureDetector(
              onTap: () => _switchMode(_Mode.register),
              child: const Text('Cadastrar-se', style: TextStyle(fontSize: 12, color: kGreen, fontWeight: FontWeight.w900)),
            ),
          ]),
        ],
      );
    } else {
      return TextButton(
        onPressed: () => _switchMode(_Mode.login),
        child: Text('← Voltar para o login', style: TextStyle(fontSize: 12, color: kGreen, fontWeight: FontWeight.w700)),
      );
    }
  }

  String get _modeTitle {
    switch (_mode) {
      case _Mode.login:    return 'Entrar na sua conta';
      case _Mode.register: return 'Criar conta';
      case _Mode.reset:    return 'Redefinir senha';
    }
  }

  String get _modeSubtitle {
    switch (_mode) {
      case _Mode.login:    return 'Use seu e-mail e senha cadastrados';
      case _Mode.register: return 'Cadastro sujeito à aprovação do administrador';
      case _Mode.reset:    return 'Enviaremos um link para seu e-mail';
    }
  }

  String get _modeBtn {
    switch (_mode) {
      case _Mode.login:    return 'Entrar';
      case _Mode.register: return 'Solicitar acesso';
      case _Mode.reset:    return 'Enviar link';
    }
  }
}
