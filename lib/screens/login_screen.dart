import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/social_auth_service.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const LoginScreen({super.key, this.onBack});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum _Mode { login, register, reset }

class _LoginScreenState extends State<LoginScreen> {
  // MEDCASES_LOGIN_V3_CANONICAL_DARK_VISUAL_CUTOVER_V1_B_R3
  // Canonical MedCases dark auth palette — no legacy green background.
  static const kAuthBg = Color(0xFF0F1116);
  static const kAuthBgTop = Color(0xFF151A22);
  static const kAuthSurface = Color(0xFF181D25);
  static const kAuthSurfaceSoft = Color(0xFF141920);
  static const kAuthBorder = Color(0xFF374151);
  static const kAuthAccent = Color(0xFF0E8000);
  static const kAuthAccentDeep = Color(0xFF0E8000);
  static const kAuthText = Color(0xFFF8FAFC);
  static const kAuthMuted = Color(0xFF94A3B8);

  _Mode _mode = _Mode.login;
  bool _loading = false;
  String? _socialLoadingProvider;
  bool _obscure = true;
  bool _rememberEmail = true; // SUPER ORDEM MASTER 14 M4: ativo por padrão
  bool _keepLoggedIn =
      true; // SUPER ORDEM MASTER 14 M4: "Conectar Automaticamente" pré-marcado
  String? _error;
  String? _success;

  // ── Task 3: Disclaimer médico obrigatório ─────────────────────────────────
  // Deve ser aceito no cadastro unificado em tela única.
  bool _disclaimerAccepted = false;
  bool _disclaimerError = false;

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _profCtrl = TextEditingController();
  final _instCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _studyCtrl = TextEditingController();

  String? _registerAvatarBase64;
  bool _registerPhotoLoading = false;
  final _formKey = GlobalKey<FormState>();

  // ── Nova paleta ────────────────────────────────────────────────────────────
  // Verde profundo diferente do anterior (#0F1C14 → #061A12)
  static const kBg = Color(0xFF1A1D23); // fundo hero — verde bem escuro
  // MEDCASES_AUTH_FLAT_SINGLE_SURFACE_CREATE_ACCOUNT_V1_B_R0_R4
  // MEDCASES_LOGIN_SIGNUP_AUTH_UI_V2_B_R1
  static const kForest = Color(0xFF17382D); // camada intermediária
  static const kGreen = Color(0xFF0E8000); // verde clínico canônico
  static const kGreenMid = Color(0xFF0E8000); // mesmo acento: superfície flat
  static const kPanel = Color(0x00000000); // transparente: sem painel/sheet
  static const kText = Color(0xFFF1F5F9); // texto primário sobre dark
  static const kTextMid = Color(0xFF94A3B8); // texto secundário canônico
  static const kGold = Color(0xFFC5A365); // dourado MedCases
  static const kGoldL = Color(0xFFFFE8A6); // dourado claro

  static const _kPrefEmail = 'login_saved_email';
  static const _kPrefRemember = 'login_remember_email';
  static const _kKeepLoggedIn = 'session_keep_logged_in';

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
  }

  Future<void> _loadSavedEmail() async {
    try {
      final p = await SharedPreferences.getInstance();
      // SUPER ORDEM MASTER 14 M4: default true — primeiro uso já vem marcado
      final remember = p.getBool(_kPrefRemember) ?? true;
      final keepLoggedIn = p.getBool(_kKeepLoggedIn) ?? true;
      final email = p.getString(_kPrefEmail) ?? '';
      if (mounted)
        setState(() {
          _keepLoggedIn = keepLoggedIn;
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
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    _profCtrl.dispose();
    _instCtrl.dispose();
    _confirmPassCtrl.dispose();
    _studyCtrl.dispose();
    super.dispose();
  }

  void _switchMode(_Mode m) {
    setState(() {
      _mode = m;
      _error = null;
      _success = null;
      _disclaimerAccepted = false;
      _disclaimerError = false;

      if (m != _Mode.register) {
        _confirmPassCtrl.clear();
        _studyCtrl.clear();
        _registerAvatarBase64 = null;
      }
    });
  }

  Future<void> _pickRegisterPhoto() async {
    if (_registerPhotoLoading) return;

    setState(() {
      _registerPhotoLoading = true;
      _error = null;
    });

    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() => _registerAvatarBase64 = base64Encode(bytes));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = _isEs
            ? 'No fue posible seleccionar la foto.'
            : 'Não foi possível selecionar a foto.';
      });
    } finally {
      if (mounted) {
        setState(() => _registerPhotoLoading = false);
      }
    }
  }

  Future<void> _persistPendingRegistrationExtras() async {
    // UI/UX phase only.
    // Firebase/profile synchronization for these two new fields is intentionally
    // deferred to the next phase, after physical visual homologation.
    try {
      final prefs = await SharedPreferences.getInstance();
      final normalizedEmail = _emailCtrl.text.trim().toLowerCase();
      final safeKey = normalizedEmail.replaceAll(RegExp(r'[^a-z0-9@._-]'), '_');

      final study = _studyCtrl.text.trim();
      if (study.isNotEmpty) {
        await prefs.setString(
          'medcases_registration_study_pending_$safeKey',
          study,
        );
      }

      final avatar = _registerAvatarBase64;
      if (avatar != null && avatar.isNotEmpty) {
        await prefs.setString(
          'medcases_registration_avatar_pending_$safeKey',
          avatar,
        );
      }
    } catch (_) {
      // These extras never block canonical Firebase account creation.
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_mode == _Mode.register && !_disclaimerAccepted) {
      setState(() => _disclaimerError = true);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    AuthResult result;

    if (_mode == _Mode.login) {
      await _persistEmail(_emailCtrl.text.trim());
      result = await AuthService.login(
        email: _emailCtrl.text,
        password: _passCtrl.text,
      );
      if (result.success) {
        await _saveSessionIfRequested(result);
      }
    } else if (_mode == _Mode.register) {
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

      if (result.success) {
        await _persistPendingRegistrationExtras();

        if (_keepLoggedIn && result.user != null) {
          await AuthService.saveSession(result.user!);
        }

        if (!mounted) return;
        setState(() => _loading = false);
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

  // MEDCASES_LOGIN_V3_GOOGLE_APPLE_PERSISTENT_SESSION_MODERN_UI_V1_B_R0
  Future<void> _submitSocial(String provider) async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _socialLoadingProvider = provider;
      _error = null;
      _success = null;
    });

    final AuthResult result = provider == 'google'
        ? await SocialAuthService.signInWithGoogle(isEs: _isEs)
        : await SocialAuthService.signInWithApple(isEs: _isEs);

    if (!mounted) return;

    if (!result.success &&
        result.error == SocialAuthService.cancelledResultCode) {
      setState(() {
        _loading = false;
        _socialLoadingProvider = null;
      });
      return;
    }

    if (result.success) {
      // AuthService.completeSocialSignIn() already persisted the session and
      // the canonical AuthGate owns navigation.
      setState(() {
        _loading = false;
        _socialLoadingProvider = null;
      });
      return;
    }

    setState(() {
      _loading = false;
      _socialLoadingProvider = null;
      _error = result.error;
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
    // MEDCASES_LOGIN_V3_UIUX_SUPER_CORRECTION_SINGLE_SCREEN_REGISTER_V1_B_R2
    // MEDCASES_LOGIN_V3_CANONICAL_DARK_VISUAL_CUTOVER_V1_B_R3
    final media = MediaQuery.of(context);
    final isLogin = _mode == _Mode.login;
    final keyboardOpen = media.viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: kAuthBg,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    kAuthBgTop,
                    kAuthBg,
                    Color(0xFF0B0E13),
                  ],
                  stops: [0.0, 0.42, 1.0],
                ),
              ),
            ),
          ),
          if (widget.onBack != null)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 8, top: 2),
                child: IconButton(
                  tooltip: _isEs ? 'Volver' : 'Voltar',
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  color: kAuthMuted,
                ),
              ),
            ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final horizontal = constraints.maxWidth >= 700 ? 34.0 : 24.0;
                final top = isLogin ? (keyboardOpen ? 10.0 : 26.0) : 16.0;
                final bottom = keyboardOpen ? 18.0 : (isLogin ? 104.0 : 16.0);

                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    top,
                    horizontal,
                    bottom,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildModeHeader(),
                            SizedBox(height: isLogin ? 26 : 16),
                            if (_success != null) ...[
                              _banner(_success!, isError: false),
                              const SizedBox(height: 10),
                            ],
                            if (isLogin) ...[
                              _buildSocialLoginSection(),
                              const SizedBox(height: 18),
                              ..._loginFields(),
                            ],
                            if (_mode == _Mode.register) ..._registerFields(),
                            if (_mode == _Mode.reset) ..._resetFields(),
                            if (_error != null) ...[
                              const SizedBox(height: 10),
                              _banner(_error!, isError: true),
                            ],
                            SizedBox(height: isLogin ? 18 : 16),
                            _submitBtn(),
                            SizedBox(height: isLogin ? 10 : 10),
                            _buildLinks(),
                            if (!isLogin) ...[
                              const SizedBox(height: 18),
                              _buildDisclaimer(),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (isLogin && !keyboardOpen)
            Positioned(
              left: 24,
              right: 24,
              bottom: 10,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: _buildDisclaimer(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Cabeçalho do modo ─────────────────────────────────────────────────────
  Widget _buildModeHeader() {
    // MEDCASES_LOGIN_V4_BREATHING_BRANDED_SOCIAL_KEYBOARD_FLOW_V1_B_R13A
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    if (_mode == _Mode.login) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(height: keyboardOpen ? 0 : 8),
          Image.asset(
            'assets/icon/splash_mplus_premium.png',
            width: keyboardOpen ? 64 : 78,
            height: keyboardOpen ? 64 : 78,
            fit: BoxFit.contain,
          ),
          SizedBox(height: keyboardOpen ? 8 : 14),
          Text(
            'MedCases Pro',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: keyboardOpen ? 24 : 28,
              fontWeight: FontWeight.w800,
              color: kText,
              letterSpacing: -0.8,
              height: 1.05,
            ),
          ),
          SizedBox(height: keyboardOpen ? 5 : 8),
          Text(
            _isEs
                ? 'Tu práctica clínica, más simple y conectada'
                : 'Sua prática clínica, mais simples e conectada',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              color: kTextMid,
              fontWeight: FontWeight.w500,
              height: 1.40,
              letterSpacing: 0.05,
            ),
          ),
          SizedBox(height: keyboardOpen ? 18 : 28),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: kGreen,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: kGreen.withOpacity(0.30),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Icon(_modeIcon, size: 24, color: Colors.white),
        ),
        const SizedBox(height: 16),
        Text(
          _modeTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: kText,
            letterSpacing: -0.4,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          _modeSubtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12.5,
            color: kTextMid,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialLoginSection() {
    Widget socialButton({
      required String provider,
      required String label,
    }) {
      final isGoogle = provider == 'google';
      final background = isGoogle ? Colors.white : const Color(0xFF000000);
      final foreground = isGoogle ? const Color(0xFF202124) : Colors.white;
      final border =
          isGoogle ? const Color(0xFFDADCE0) : const Color(0xFF2A2A2A);

      return SizedBox(
        height: 46,
        child: FilledButton(
          onPressed: _loading ? null : () => _submitSocial(provider),
          style: FilledButton.styleFrom(
            backgroundColor: background,
            disabledBackgroundColor: background.withOpacity(0.62),
            foregroundColor: foreground,
            disabledForegroundColor: foreground.withOpacity(0.62),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: border, width: 1),
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: isGoogle
                    ? SvgPicture.asset(
                        'assets/icons/home_v2/auth_google_g.svg',
                        width: 23,
                        height: 23,
                      )
                    : const Icon(
                        Icons.apple,
                        size: 27,
                        color: Colors.white,
                      ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: socialButton(
                provider: 'google',
                label: 'Google',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: socialButton(
                provider: 'apple',
                label: 'Apple',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Divider(
                height: 1,
                thickness: 1,
                color: Colors.white.withOpacity(0.14),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _isEs ? 'o' : 'ou',
                style: const TextStyle(
                  color: kTextMid,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: Divider(
                height: 1,
                thickness: 1,
                color: Colors.white.withOpacity(0.14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _socialAuthButton({
    required String provider,
    required String label,
    required Widget leading,
  }) {
    final busy = _loading && _socialLoadingProvider == provider;

    return SizedBox(
      height: 39,
      child: FilledButton(
        onPressed: _loading ? null : () => _submitSocial(provider),
        style: FilledButton.styleFrom(
          backgroundColor: kAuthSurface,
          disabledBackgroundColor: kAuthSurface.withValues(alpha: 0.58),
          foregroundColor: kAuthText,
          disabledForegroundColor: kAuthMuted,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(
              color: kAuthBorder,
              width: 0.8,
            ),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: kAuthText,
                      ),
                    )
                  : leading,
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
                color: kAuthText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step indicator ────────────────────────────────────────────────────────
  // ── Campos login ──────────────────────────────────────────────────────────
  List<Widget> _loginFields() => [
        _field(_emailLabel, _emailCtrl, Icons.alternate_email_rounded,
            keyboard: TextInputType.emailAddress, validator: (v) {
          if (v?.trim().isEmpty ?? true) return _emailRequiredMsg;
          if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w+$').hasMatch(v!.trim()))
            return _emailInvalidMsg;
          return null;
        }),
        const SizedBox(height: 12),
        _fieldPassword(),
        const SizedBox(height: 12),
        _checkRow(
          value: _keepLoggedIn,
          label: _keepLoggedInLabel,
          onChanged: (v) => setState(() {
            _keepLoggedIn = v ?? false;
            if (_keepLoggedIn) _rememberEmail = true;
          }),
        ),
      ];

  // ── Campos registro ───────────────────────────────────────────────────────
  Widget _registerPhotoPicker() {
    final avatar = _registerAvatarBase64;

    return Center(
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(34),
            onTap: _registerPhotoLoading ? null : _pickRegisterPhoto,
            child: Container(
              width: 62,
              height: 62,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kAuthSurfaceSoft,
                border: Border.all(
                  color: kAuthAccentDeep,
                  width: 1,
                ),
              ),
              child: _registerPhotoLoading
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: kAuthAccent,
                      ),
                    )
                  : avatar != null
                      ? Image.memory(
                          base64Decode(avatar),
                          fit: BoxFit.cover,
                        )
                      : const Icon(
                          Icons.add_a_photo_outlined,
                          color: kAuthAccentDeep,
                          size: 23,
                        ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _isEs ? 'Foto de perfil · opcional' : 'Foto de perfil · opcional',
            style: const TextStyle(
              color: kAuthMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _confirmPasswordField() {
    return TextFormField(
      scrollPadding: const EdgeInsets.only(bottom: 96),
      controller: _confirmPassCtrl,
      obscureText: _obscure,
      textInputAction: TextInputAction.next,
      enableSuggestions: false,
      autocorrect: false,
      validator: (v) {
        if (v?.isEmpty ?? true) {
          return _isEs ? 'Confirma tu contraseña' : 'Confirme sua senha';
        }
        if (v != _passCtrl.text) {
          return _isEs
              ? 'Las contraseñas no coinciden'
              : 'As senhas não coincidem';
        }
        return null;
      },
      style: const TextStyle(
        fontSize: 13.5,
        color: kAuthText,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: _isEs ? 'Confirmar contraseña' : 'Confirmar senha',
        labelStyle: const TextStyle(
          fontSize: 11.5,
          color: kAuthMuted,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: const TextStyle(
          fontSize: 11.5,
          color: kAuthMuted,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: const Icon(
          Icons.lock_reset_rounded,
          size: 18,
          color: kAuthAccentDeep,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 18,
            color: kAuthMuted,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
        filled: true,
        fillColor: kAuthSurfaceSoft,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: kAuthBorder, width: 0.9),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: kAuthBorder, width: 0.9),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: kAuthAccent, width: 1.3),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.3),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 12,
        ),
      ),
    );
  }

  // REGISTER_V3_SINGLE_SCREEN
  List<Widget> _registerFields() {
    return [
      _registerPhotoPicker(),
      const SizedBox(height: 11),
      _field(
        _fullNameLabel,
        _nameCtrl,
        Icons.badge_outlined,
        validator: (v) => (v?.trim().isEmpty ?? true) ? _nameRequiredMsg : null,
      ),
      const SizedBox(height: 9),
      _field(
        _emailLabel,
        _emailCtrl,
        Icons.alternate_email_rounded,
        keyboard: TextInputType.emailAddress,
        validator: (v) {
          if (v?.trim().isEmpty ?? true) return _emailRequiredMsg;
          if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w+$').hasMatch(v!.trim())) {
            return _emailInvalidMsg;
          }
          return null;
        },
      ),
      const SizedBox(height: 9),
      _fieldPassword(),
      const SizedBox(height: 9),
      _confirmPasswordField(),
      const SizedBox(height: 9),
      _field(
        _professionLabel,
        _profCtrl,
        Icons.medical_services_outlined,
      ),
      const SizedBox(height: 9),
      _field(
        _institutionLabel,
        _instCtrl,
        Icons.apartment_rounded,
      ),
      const SizedBox(height: 9),
      _field(
        _isEs
            ? 'Estudios / formación · opcional'
            : 'Estudos / formação · opcional',
        _studyCtrl,
        Icons.school_outlined,
      ),
      const SizedBox(height: 12),
      _MedicalDisclaimerCheckbox(
        isEs: _isEs,
        accepted: _disclaimerAccepted,
        hasError: _disclaimerError,
        onChanged: (v) => setState(() {
          _disclaimerAccepted = v ?? false;
          if (_disclaimerAccepted) {
            _disclaimerError = false;
          }
        }),
      ),
    ];
  }

  // ── Campos reset ──────────────────────────────────────────────────────────
  List<Widget> _resetFields() => [
        _field(_emailLabel, _emailCtrl, Icons.alternate_email_rounded,
            keyboard: TextInputType.emailAddress, validator: (v) {
          if (v?.trim().isEmpty ?? true) return _emailRequiredMsg;
          if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w+$').hasMatch(v!.trim()))
            return _emailInvalidMsg;
          return null;
        }),
      ];

  // ── Campo genérico — borda 8px (sharp, diferente do 12px anterior) ─────
  Widget _field(
    String label,
    TextEditingController ctrl,
    IconData icon, {
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      scrollPadding: const EdgeInsets.only(bottom: 96),
      controller: ctrl,
      keyboardType: keyboard,
      textInputAction: TextInputAction.next,
      validator: validator,
      enableSuggestions: false,
      spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
      autocorrect: false,
      style: const TextStyle(
        fontSize: 13.5,
        color: kAuthText,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          fontSize: 11.5,
          color: kAuthMuted,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: const TextStyle(
          fontSize: 11.5,
          color: kAuthMuted,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: Icon(
          icon,
          size: 18,
          color: kAuthAccentDeep,
        ),
        filled: true,
        fillColor: kAuthSurfaceSoft,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: kAuthBorder, width: 0.9),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: kAuthBorder, width: 0.9),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: kAuthAccent, width: 1.3),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.3),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _fieldPassword() {
    return TextFormField(
      scrollPadding: const EdgeInsets.only(bottom: 96),
      controller: _passCtrl,
      obscureText: _obscure,
      textInputAction:
          _mode == _Mode.register ? TextInputAction.next : TextInputAction.done,
      enableSuggestions: false,
      spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
      autocorrect: false,
      validator: _mode == _Mode.register
          ? (v) => (v?.length ?? 0) < 6 ? _passwordMinMsg : null
          : (v) => (v?.isEmpty ?? true) ? _passwordRequiredMsg : null,
      style: const TextStyle(
        fontSize: 13.5,
        color: kAuthText,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: _passwordLabel,
        labelStyle: const TextStyle(
          fontSize: 11.5,
          color: kAuthMuted,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: const TextStyle(
          fontSize: 11.5,
          color: kAuthMuted,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: const Icon(
          Icons.lock_outline_rounded,
          size: 18,
          color: kAuthAccentDeep,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 18,
            color: kAuthMuted,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
        filled: true,
        fillColor: kAuthSurfaceSoft,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: kAuthBorder, width: 0.9),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: kAuthBorder, width: 0.9),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: kAuthAccent, width: 1.3),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.3),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _checkRow({
    required bool value,
    required String label,
    required ValueChanged<bool?> onChanged,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 21,
              height: 21,
              child: Checkbox(
                value: value,
                onChanged: onChanged,
                activeColor: kAuthAccentDeep,
                checkColor: kAuthText,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
                side: const BorderSide(
                  color: kAuthBorder,
                  width: 1.2,
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: kAuthText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _banner(String msg, {required bool isError}) {
    final color = isError ? Colors.red.shade700 : kGreen;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(
            isError
                ? Icons.warning_amber_rounded
                : Icons.check_circle_outline_rounded,
            size: 16,
            color: color),
        const SizedBox(width: 8),
        Expanded(
            child: Text(msg,
                style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w600,
                    height: 1.4))),
      ]),
    );
  }

  // ── Botão principal — borda 10px, gradiente verde direto (não preto) ────
  Widget _submitBtn() {
    final btnLabel = _modeBtn;
    final isLogin = _mode == _Mode.login;
    final widthFactor = isLogin ? 0.60 : 0.82;
    final height = isLogin ? 42.0 : 45.0;

    return Align(
      alignment: Alignment.center,
      child: FractionallySizedBox(
        widthFactor: widthFactor,
        child: SizedBox(
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: _loading
                  ? null
                  : const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        kAuthAccentDeep,
                        Color(0xFF0E8000),
                      ],
                    ),
            ),
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                disabledBackgroundColor: kAuthSurface,
                foregroundColor: kAuthText,
                shadowColor: Colors.transparent,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: kAuthText,
                      ),
                    )
                  : Text(
                      btnLabel,
                      style: TextStyle(
                        fontSize: isLogin ? 13.5 : 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                        color: kAuthText,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Links ─────────────────────────────────────────────────────────────────
  Widget _buildLinks() {
    if (_mode == _Mode.login) {
      return Column(
        children: [
          SizedBox(
            height: 30,
            child: TextButton(
              onPressed: () => _switchMode(_Mode.reset),
              child: Text(
                _forgotPasswordLabel,
                style: const TextStyle(
                  fontSize: 11.2,
                  color: kGreenMid,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 1),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _noAccountLabel,
                style: const TextStyle(
                  fontSize: 11.2,
                  color: kTextMid,
                ),
              ),
              GestureDetector(
                onTap: () => _switchMode(_Mode.register),
                child: Text(
                  _signUpLabel,
                  style: const TextStyle(
                    fontSize: 11.2,
                    color: kGreen,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (_mode == _Mode.register) {
      return TextButton(
        onPressed: () => _switchMode(_Mode.login),
        child: Text(
          _isEs
              ? '¿Ya tienes cuenta? Iniciar sesión'
              : 'Já tem uma conta? Entrar',
          style: const TextStyle(
            fontSize: 11.2,
            color: kGreen,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return TextButton(
      onPressed: () => _switchMode(_Mode.login),
      child: Text(
        _backToLoginLabel,
        style: const TextStyle(
          fontSize: 11.2,
          color: kGreen,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.health_and_safety_outlined,
            size: 18,
            color: kAuthAccentDeep,
          ),
          const SizedBox(height: 6),
          Text(
            _legalDisclaimer,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 9.8,
              color: kAuthMuted,
              fontWeight: FontWeight.w400,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  // ── Strings i18n ──────────────────────────────────────────────────────────
  IconData get _modeIcon {
    switch (_mode) {
      case _Mode.login:
        return Icons.fingerprint_rounded;
      case _Mode.register:
        return Icons.person_add_outlined;
      case _Mode.reset:
        return Icons.lock_reset_rounded;
    }
  }

  String get _modeTitle {
    switch (_mode) {
      case _Mode.login:
        return _isEs ? 'Acceder a mi cuenta' : 'Acessar minha conta';
      case _Mode.register:
        return _isEs ? 'Crear cuenta' : 'Criar conta';
      case _Mode.reset:
        return _isEs ? 'Recuperar contraseña' : 'Recuperar senha';
    }
  }

  String get _modeSubtitle {
    switch (_mode) {
      case _Mode.login:
        return _isEs
            ? 'Plataforma exclusiva para profesionales'
            : 'Plataforma exclusiva para profissionais';
      case _Mode.register:
        return _isEs
            ? 'Crea tu cuenta para acceder a MedCases Pro'
            : 'Crie sua conta para acessar o MedCases Pro';
      case _Mode.reset:
        return _isEs
            ? 'Te enviamos un enlace de recuperación por email'
            : 'Enviaremos um link de recuperação por e-mail';
    }
  }

  String get _modeBtn {
    switch (_mode) {
      case _Mode.login:
        return _isEs ? 'Iniciar sesión' : 'Entrar';
      case _Mode.register:
        return _isEs ? 'Crear cuenta' : 'Criar conta';
      case _Mode.reset:
        return _isEs ? 'Enviar enlace' : 'Enviar link';
    }
  }

  String get _keepLoggedInLabel =>
      _isEs ? 'Mantener sesión activa' : 'Manter sessão ativa';
  String get _fullNameLabel => _isEs ? 'Nombre completo' : 'Nome completo';
  String get _nameRequiredMsg =>
      _isEs ? 'Ingresa tu nombre' : 'Informe seu nome';
  String get _emailLabel =>
      _isEs ? 'E-mail institucional' : 'E-mail institucional';
  String get _emailRequiredMsg =>
      _isEs ? 'Ingresa el correo' : 'Informe o e-mail';
  String get _emailInvalidMsg => _isEs ? 'Correo inválido' : 'E-mail inválido';
  String get _professionLabel =>
      _isEs ? 'Especialidad / Cargo' : 'Especialidade / Cargo';
  String get _institutionLabel =>
      _isEs ? 'Hospital / Institución' : 'Hospital / Instituição';
  String get _forgotPasswordLabel =>
      _isEs ? '¿Olvidaste tu contraseña?' : 'Esqueceu a senha?';
  String get _noAccountLabel => _isEs ? '¿Sin cuenta?  ' : 'Sem conta?  ';
  String get _signUpLabel => _isEs ? 'Crear cuenta' : 'Criar conta';
  String get _backToLoginLabel =>
      _isEs ? '← Volver al inicio' : '← Voltar ao início';
  String get _passwordLabel => _isEs ? 'Contraseña' : 'Senha';
  String get _passwordMinMsg =>
      _isEs ? 'Mínimo 6 caracteres' : 'Mínimo 6 caracteres';
  String get _passwordRequiredMsg =>
      _isEs ? 'Ingresa la contraseña' : 'Informe a senha';
  String get _legalDisclaimer => _isEs
      ? 'Herramienta de apoyo clínico educativo. No sustituye el juicio clínico individual ni las guías institucionales vigentes.'
      : 'Ferramenta de apoio clínico educacional. Não substitui o julgamento clínico individual nem as diretrizes institucionais vigentes.';

  String _registerSuccessMsg() =>
      _isEs ? 'Cuenta creada correctamente.' : 'Conta criada com sucesso.';

  String _resetSuccessMsg(String email) => _isEs
      ? 'Enlace de recuperación enviado a $email. Revisa tu bandeja de entrada.'
      : 'Link de recuperação enviado para $email. Verifique sua caixa de entrada.';
}

// ══════════════════════════════════════════════════════════════════════════════
// HERO GEOMÉTRICO ANIMADO — formas vazadas (sem preenchimento sólido)
// ══════════════════════════════════════════════════════════════════════════════
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

  // BUILD 431: palette constants — Canvas Premium dark
  static const _kAccent = Color(0xFF0D6B57);
  static const _kSurface = Color(0xFF252930);
  static const _kBorder = Color(0x1AFFFFFF); // 10% white
  static const _kTextSec = Color(0xB3FFFFFF); // white70
  static const _kTextHint = Color(0xFF8B9BB4);

  @override
  Widget build(BuildContext context) {
    final disclaimerText = isEs ? _textEs : _textPt;
    final labelAccept =
        isEs ? 'Acepto los términos anteriores' : 'Li e aceito os termos acima';
    final errorMsg = isEs
        ? 'Es necesario aceptar el término para continuar.'
        : 'É necessário aceitar o termo para continuar.';

    const accent = Color(0xFF0E8000);
    const surface = Color(0xFF181D25);
    const border = Color(0xFF374151);
    const text = Color(0xFFF8FAFC);
    const muted = Color(0xFF94A3B8);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 11),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: hasError ? const Color(0xFFEF4444) : border,
              width: hasError ? 1.1 : 0.8,
            ),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.health_and_safety_outlined,
                      color: accent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEs
                              ? 'Declaración de uso profesional'
                              : 'Declaração de uso profissional',
                          style: const TextStyle(
                            color: accent,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          disclaimerText,
                          style: const TextStyle(
                            color: muted,
                            fontSize: 10.2,
                            fontWeight: FontWeight.w400,
                            height: 1.32,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(!accepted),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: accepted,
                        onChanged: onChanged,
                        activeColor: accent,
                        checkColor: text,
                        side: const BorderSide(color: border, width: 1.1),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        labelAccept,
                        style: const TextStyle(
                          color: text,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 5),
          Text(
            errorMsg,
            style: const TextStyle(
              color: Color(0xFFEF4444),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
