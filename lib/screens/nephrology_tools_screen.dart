// ══════════════════════════════════════════════════════════════════════════════
// nephrology_tools_screen.dart — BUILD 408-NATIVE
//
// CENTRAL DE FUNÇÃO RENAL / NEFROLOGÍA — Interface nativa minimalista.
//
// CONFORMIDADE APPLE STORE:
//   • Exibe APENAS resultados numéricos, cálculos matemáticos e estadiamentos.
//   • ZERO condutas terapêuticas, doses ou prescrições nativas.
//   • Toda a conduta clínica final é delegada ao WebView via Deeplink estruturado.
//
// MOTORES MATEMÁTICOS:
//   1. CKD-EPI 2021 (sem fator racial)
//   2. Cockcroft-Gault
//   3. KDIGO LRA (estadiamento)
//   4. FeNa (Fração de Excreção de Sódio)
//
// INTERNACIONALIZAÇÃO: isEs (Português / Espanhol) em todas as strings.
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/app_provider.dart';
import 'tools_patient_import.dart';
import 'internacion/services/internacion_persistence.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Paleta canônica MedCases Pro (dark-first)
// ─────────────────────────────────────────────────────────────────────────────
const _kBg        = Color(0xFF0F1116);
const _kSurface   = Color(0xFF1A1D23);
const _kBorder    = Color(0xFF2D3340);
const _kCyan      = Color(0xFF00E5FF);
const _kGreen     = Color(0xFF10B981);
const _kAmber     = Color(0xFFF59E0B);
const _kRed       = Color(0xFFEF4444);
const _kTextSub   = Color(0xFF8B9BB4);

// ─────────────────────────────────────────────────────────────────────────────
// NephrologyToolsScreen — ponto de entrada público
// ─────────────────────────────────────────────────────────────────────────────
class NephrologyToolsScreen extends StatelessWidget {
  const NephrologyToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p    = context.watch<AppProvider>();
    final isEs = p.lang == 'es';
    final dark = p.darkMode;
    return _NephrologyBody(isEs: isEs, dark: dark);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _NephrologyBody — StatefulWidget principal
// ─────────────────────────────────────────────────────────────────────────────
class _NephrologyBody extends StatefulWidget {
  final bool isEs;
  final bool dark;
  const _NephrologyBody({required this.isEs, required this.dark});

  @override
  State<_NephrologyBody> createState() => _NephrologyBodyState();
}

class _NephrologyBodyState extends State<_NephrologyBody>
    with SingleTickerProviderStateMixin {
  // ── Controllers ────────────────────────────────────────────────────────────
  final _ageCtrl         = TextEditingController();
  final _weightCtrl      = TextEditingController();
  final _heightCtrl      = TextEditingController();
  final _creatBaseCtrl   = TextEditingController();
  final _creatCurrCtrl   = TextEditingController();
  final _naUrineCtrl     = TextEditingController();
  final _naSerumCtrl     = TextEditingController();
  final _creatUrineCtrl  = TextEditingController();

  // ── Sexo ───────────────────────────────────────────────────────────────────
  bool _isFemale = false; // false = Masculino / Hombre

  // ── Resultados ─────────────────────────────────────────────────────────────
  _NephroResult? _result;

  // ── Animação fade/slide ─────────────────────────────────────────────────────
  late final AnimationController _animCtrl;
  late final Animation<double>   _fadeAnim;
  late final Animation<Offset>   _slideAnim;

  // ── Form key ───────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();

  // ── Error message ──────────────────────────────────────────────────────────
  String? _errorMsg;

  // ── BUILD 426: Patient autofill ──────────────────────────────────────────────
  /// Abre o modal de seleção de paciente e faz autofill dos controllers demográficos.
  Future<void> _showPatientSelectionSheet(BuildContext context, AppProvider p) async {
    await showToolsPatientSelectionSheet(
      context: context,
      isEs: widget.isEs,
      dark: widget.dark,
      onSelected: (session) => _autofillFromSession(session),
    );
  }

  /// Mapeamento demográfico seguro: idade → _ageCtrl, sexo → _isFemale.
  /// Labs são free-text em internacion → NÃO mapeados (0 crashes garantido).
  void _autofillFromSession(PacienteSession session) {
    try {
      final paciente = session.paciente;

      // Idade → _ageCtrl
      final age = parseAgeFromString(paciente.idade);
      if (age != null) _ageCtrl.text = age.toString();

      // Sexo → _isFemale
      final female = paciente.sexo.trim().toUpperCase() == 'F';

      setState(() {
        _isFemale = female;
      });
    } catch (_) {
      // Falha silenciosa — nunca quebra a UI clínica
    }
  }

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _ageCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _creatBaseCtrl.dispose();
    _creatCurrCtrl.dispose();
    _naUrineCtrl.dispose();
    _naSerumCtrl.dispose();
    _creatUrineCtrl.dispose();
    super.dispose();
  }

  // ── Helper: parse double seguro ─────────────────────────────────────────────
  double? _pd(String v) {
    final s = v.trim().replaceAll(',', '.');
    return double.tryParse(s);
  }

  // ── Calcular ────────────────────────────────────────────────────────────────
  void _calculate() {
    HapticFeedback.lightImpact();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final age        = int.tryParse(_ageCtrl.text.trim());
    final weight     = _pd(_weightCtrl.text);
    final creatBase  = _pd(_creatBaseCtrl.text);
    final creatCurr  = _pd(_creatCurrCtrl.text);

    // Opcionais para FeNa
    final naUrine    = _pd(_naUrineCtrl.text);
    final naSerum    = _pd(_naSerumCtrl.text);
    final creatUrine = _pd(_creatUrineCtrl.text);

    if (age == null || weight == null || creatBase == null || creatCurr == null) {
      setState(() => _errorMsg = widget.isEs
          ? 'Verifica los valores ingresados.'
          : 'Verifique os valores inseridos.');
      return;
    }

    setState(() {
      _errorMsg = null;
      _result   = _NephroEngine.compute(
        age:        age,
        isFemale:   _isFemale,
        weight:     weight,
        creatBase:  creatBase,
        creatCurr:  creatCurr,
        naUrine:    naUrine,
        naSerum:    naSerum,
        creatUrine: creatUrine,
      );
    });

    _animCtrl
      ..reset()
      ..forward();
  }

  // ── Deeplink conduta ────────────────────────────────────────────────────────
  Future<void> _launchDeeplink() async {
    final r = _result;
    if (r == null) return;
    HapticFeedback.mediumImpact();

    // BUILD 410-URL: payload completo para injeção na aba Dados do Paciente
    // Chaves e tipos exatos exigidos pela Calculadora Web de produção.
    final payload = jsonEncode({
      'idade':        int.tryParse(_ageCtrl.text.trim()) ?? 0,
      'sexo':         _isFemale ? 'F' : 'M',
      'peso':         _pd(_weightCtrl.text)      ?? 0.0,
      'altura':       _pd(_heightCtrl.text)      ?? 0.0,
      'creat_basal':  _pd(_creatBaseCtrl.text)   ?? 0.0,
      'creat_atual':  _pd(_creatCurrCtrl.text)   ?? 0.0,
      'na_serico':    _pd(_naSerumCtrl.text)     ?? 0.0,
      'na_urinario':  _pd(_naUrineCtrl.text)     ?? 0.0,
      'kdigo':        r.kdigoStage,
      'ckd_epi':      r.ckdEpi,
      'cockcroft':    r.cockcroft,
    });

    // BUILD 410-URL: URL base GitHub Pages + query string segura
    const baseUrl =
        'https://rodrigssousa-sudo.github.io/medcases-calculadora/';
    final encodedPayload = Uri.encodeComponent(payload);
    final uri = Uri.parse(
      '$baseUrl?screen=patient_data&payload=$encodedPayload',
    );

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isEs
                ? 'No se pudo abrir el Soporte de Decisión Clínica.'
                : 'Não foi possível abrir o Suporte de Decisão Clínica.'),
            backgroundColor: _kSurface,
          ),
        );
      }
    }
  }

  // ── Validator genérico ──────────────────────────────────────────────────────
  String? _validatePositive(String? v) {
    if (v == null || v.trim().isEmpty) {
      return widget.isEs ? 'Requerido' : 'Obrigatório';
    }
    final n = _pd(v);
    if (n == null || n <= 0) {
      return widget.isEs ? 'Valor inválido' : 'Valor inválido';
    }
    return null;
  }

  String? _validateNonZero(String? v) {
    if (v == null || v.trim().isEmpty) return null; // opcional
    final n = _pd(v);
    if (n == null || n <= 0) {
      return widget.isEs ? 'Valor inválido' : 'Valor inválido';
    }
    return null;
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isEs = widget.isEs;
    final dark = widget.dark;
    final bg     = dark ? _kBg     : const Color(0xFFF1F5F9);
    final surf   = dark ? _kSurface : Colors.white;
    final txt    = dark ? Colors.white : const Color(0xFF0F1116);
    final sub    = dark ? _kTextSub  : const Color(0xFF64748B);
    final border = dark ? _kBorder   : const Color(0xFFCBD5E1);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Header ────────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: _Header(isEs: isEs, dark: dark, txt: txt, sub: sub),
              ),

              // ── BUILD 426: Chip de importação de paciente ─────────────────
              SliverToBoxAdapter(
                child: ToolsPatientImportChip(
                  isEs: isEs,
                  dark: dark,
                  onTap: () {
                    final p = context.read<AppProvider>();
                    _showPatientSelectionSheet(context, p);
                  },
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 4)),

              // ── Inputs ────────────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _InputSection(
                    isEs:          isEs,
                    dark:          dark,
                    surf:          surf,
                    txt:           txt,
                    sub:           sub,
                    border:        border,
                    ageCtrl:       _ageCtrl,
                    weightCtrl:    _weightCtrl,
                    heightCtrl:    _heightCtrl,
                    creatBaseCtrl: _creatBaseCtrl,
                    creatCurrCtrl: _creatCurrCtrl,
                    naUrineCtrl:   _naUrineCtrl,
                    naSerumCtrl:   _naSerumCtrl,
                    creatUrineCtrl:_creatUrineCtrl,
                    isFemale:      _isFemale,
                    onSexChange:   (v) => setState(() => _isFemale = v),
                    validatePos:   _validatePositive,
                    validateNonZ:  _validateNonZero,
                  ),
                ),
              ),

              // ── Error ─────────────────────────────────────────────────────
              if (_errorMsg != null)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      _errorMsg!,
                      style: const TextStyle(
                        color: _kRed, fontSize: 12, fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

              // ── Botão Calcular ─────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _CalcButton(isEs: isEs, onTap: _calculate),
                ),
              ),

              // ── Resultados animados ────────────────────────────────────────
              if (_result != null)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: SlideTransition(
                        position: _slideAnim,
                        child: _ResultsSection(
                          result: _result!,
                          isEs:   isEs,
                          dark:   dark,
                          surf:   surf,
                          txt:    txt,
                          sub:    sub,
                          border: border,
                          onDeeplink: _launchDeeplink,
                        ),
                      ),
                    ),
                  ),
                ),

              const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final bool isEs, dark;
  final Color txt, sub;
  const _Header({
    required this.isEs,
    required this.dark,
    required this.txt,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: dark ? _kSurface : Colors.white,
        border: Border(
          bottom: BorderSide(color: dark ? _kBorder : const Color(0xFFE2E8F0)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _kCyan.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.water_drop_rounded, color: _kCyan, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEs ? 'FUNCIÓN RENAL' : 'FUNÇÃO RENAL',
                  style: TextStyle(
                    color: txt,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isEs
                      ? 'CKD-EPI · Cockcroft-Gault · KDIGO · FeNa'
                      : 'CKD-EPI · Cockcroft-Gault · KDIGO · FeNa',
                  style: TextStyle(color: sub, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Input Section
// ─────────────────────────────────────────────────────────────────────────────
class _InputSection extends StatelessWidget {
  final bool isEs, dark;
  final Color surf, txt, sub, border;
  final TextEditingController ageCtrl, weightCtrl, heightCtrl;
  final TextEditingController creatBaseCtrl, creatCurrCtrl;
  final TextEditingController naUrineCtrl, naSerumCtrl, creatUrineCtrl;
  final bool isFemale;
  final ValueChanged<bool> onSexChange;
  final FormFieldValidator<String> validatePos;
  final FormFieldValidator<String> validateNonZ;

  const _InputSection({
    required this.isEs,
    required this.dark,
    required this.surf,
    required this.txt,
    required this.sub,
    required this.border,
    required this.ageCtrl,
    required this.weightCtrl,
    required this.heightCtrl,
    required this.creatBaseCtrl,
    required this.creatCurrCtrl,
    required this.naUrineCtrl,
    required this.naSerumCtrl,
    required this.creatUrineCtrl,
    required this.isFemale,
    required this.onSexChange,
    required this.validatePos,
    required this.validateNonZ,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),

        // ── Grupo 1: Dados Demográficos ──────────────────────────────────────
        _SectionLabel(isEs ? 'DATOS DEMOGRÁFICOS' : 'DADOS DEMOGRÁFICOS', sub),
        const SizedBox(height: 8),
        _InputCard(
          dark: dark, surf: surf, border: border,
          child: Column(
            children: [
              // Idade + Sexo
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _FieldBox(
                      ctrl:  ageCtrl,
                      label: isEs ? 'Edad (años)' : 'Idade (anos)',
                      type:  TextInputType.number,
                      dark:  dark, txt: txt, sub: sub,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return isEs ? 'Requerido' : 'Obrigatório';
                        }
                        final n = int.tryParse(v.trim());
                        if (n == null || n < 1 || n > 120) {
                          return isEs ? 'Inválido' : 'Inválido';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SexToggle(
                      isEs:     isEs,
                      dark:     dark,
                      txt:      txt,
                      sub:      sub,
                      isFemale: isFemale,
                      onChange: onSexChange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Peso + Altura
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _FieldBox(
                      ctrl:  weightCtrl,
                      label: isEs ? 'Peso (kg)' : 'Peso (kg)',
                      type:  const TextInputType.numberWithOptions(decimal: true),
                      dark:  dark, txt: txt, sub: sub,
                      validator: validatePos,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FieldBox(
                      ctrl:  heightCtrl,
                      label: isEs ? 'Altura (cm)' : 'Altura (cm)',
                      type:  const TextInputType.numberWithOptions(decimal: true),
                      dark:  dark, txt: txt, sub: sub,
                      validator: validateNonZ,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // ── Grupo 2: Creatinina ──────────────────────────────────────────────
        _SectionLabel(
          isEs ? 'CREATININA SÉRICA' : 'CREATININA SÉRICA',
          sub,
        ),
        const SizedBox(height: 8),
        _InputCard(
          dark: dark, surf: surf, border: border,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _FieldBox(
                  ctrl:  creatBaseCtrl,
                  label: isEs ? 'Basal (mg/dL)' : 'Basal (mg/dL)',
                  type:  const TextInputType.numberWithOptions(decimal: true),
                  dark:  dark, txt: txt, sub: sub,
                  validator: validatePos,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _FieldBox(
                  ctrl:  creatCurrCtrl,
                  label: isEs ? 'Actual (mg/dL)' : 'Atual (mg/dL)',
                  type:  const TextInputType.numberWithOptions(decimal: true),
                  dark:  dark, txt: txt, sub: sub,
                  validator: validatePos,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // ── Grupo 3: FeNa (opcional) ─────────────────────────────────────────
        _SectionLabel(
          isEs
              ? 'FeNa — OPCIONAL (Sodio + Cr. Urinarios)'
              : 'FeNa — OPCIONAL (Sódio + Cr. Urinários)',
          sub,
        ),
        const SizedBox(height: 8),
        _InputCard(
          dark: dark, surf: surf, border: border,
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _FieldBox(
                      ctrl:  naUrineCtrl,
                      label: isEs ? 'Na Urinario (mEq/L)' : 'Na Urinário (mEq/L)',
                      type:  const TextInputType.numberWithOptions(decimal: true),
                      dark:  dark, txt: txt, sub: sub,
                      validator: validateNonZ,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FieldBox(
                      ctrl:  naSerumCtrl,
                      label: isEs ? 'Na Sérico (mEq/L)' : 'Na Sérico (mEq/L)',
                      type:  const TextInputType.numberWithOptions(decimal: true),
                      dark:  dark, txt: txt, sub: sub,
                      validator: validateNonZ,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _FieldBox(
                ctrl:  creatUrineCtrl,
                label: isEs ? 'Creatinina Urinaria (mg/dL)' : 'Creatinina Urinária (mg/dL)',
                type:  const TextInputType.numberWithOptions(decimal: true),
                dark:  dark, txt: txt, sub: sub,
                validator: validateNonZ,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section label
// ─────────────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionLabel(this.label, this.color);

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: TextStyle(
          color:       color,
          fontSize:    10,
          fontWeight:  FontWeight.w700,
          letterSpacing: 0.8,
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Input Card container
// ─────────────────────────────────────────────────────────────────────────────
class _InputCard extends StatelessWidget {
  final bool dark;
  final Color surf, border;
  final Widget child;
  const _InputCard({
    required this.dark,
    required this.surf,
    required this.border,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        padding: const EdgeInsets.all(12),
        child: child,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Text field box
// ─────────────────────────────────────────────────────────────────────────────
class _FieldBox extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final TextInputType type;
  final bool dark;
  final Color txt, sub;
  final FormFieldValidator<String>? validator;

  const _FieldBox({
    required this.ctrl,
    required this.label,
    required this.type,
    required this.dark,
    required this.txt,
    required this.sub,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final fill   = dark ? const Color(0xFF2A2F3A) : const Color(0xFFF8FAFC);
    final border = dark ? _kBorder : const Color(0xFFCBD5E1);
    final errCol = _kRed;

    return TextFormField(
      controller:  ctrl,
      keyboardType: type,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
      ],
      validator: validator,
      style: TextStyle(
        color: txt, fontSize: 13, fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText:        label,
        labelStyle:       TextStyle(color: sub, fontSize: 11),
        filled:           true,
        fillColor:        fill,
        contentPadding:   const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        isDense:          true,
        enabledBorder:    OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:   BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:   const BorderSide(color: _kCyan, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:   BorderSide(color: errCol),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:   BorderSide(color: errCol, width: 1.5),
        ),
        errorStyle: TextStyle(color: errCol, fontSize: 9),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sex Toggle
// ─────────────────────────────────────────────────────────────────────────────
class _SexToggle extends StatelessWidget {
  final bool isEs, dark, isFemale;
  final Color txt, sub;
  final ValueChanged<bool> onChange;

  const _SexToggle({
    required this.isEs,
    required this.dark,
    required this.isFemale,
    required this.txt,
    required this.sub,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final fill = dark ? const Color(0xFF2A2F3A) : const Color(0xFFF8FAFC);
    final bd   = dark ? _kBorder : const Color(0xFFCBD5E1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isEs ? 'Sexo' : 'Sexo',
          style: TextStyle(color: sub, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Container(
          height: 38,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: bd),
          ),
          child: Row(
            children: [
              _SexOption(
                label: isEs ? 'Hombre' : 'Masc.',
                active: !isFemale,
                onTap: () => onChange(false),
                dark: dark,
                left: true,
              ),
              Container(width: 1, height: 22, color: bd),
              _SexOption(
                label: isEs ? 'Mujer' : 'Fem.',
                active: isFemale,
                onTap: () => onChange(true),
                dark: dark,
                left: false,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SexOption extends StatelessWidget {
  final String label;
  final bool active, dark, left;
  final VoidCallback onTap;

  const _SexOption({
    required this.label,
    required this.active,
    required this.dark,
    required this.left,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: active ? _kCyan.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.only(
              topLeft:     left  ? const Radius.circular(8) : Radius.zero,
              bottomLeft:  left  ? const Radius.circular(8) : Radius.zero,
              topRight:    !left ? const Radius.circular(8) : Radius.zero,
              bottomRight: !left ? const Radius.circular(8) : Radius.zero,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize:   11,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              color:      active ? _kCyan : (dark ? Colors.white54 : Colors.black45),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Botão Calcular
// ─────────────────────────────────────────────────────────────────────────────
class _CalcButton extends StatelessWidget {
  final bool isEs;
  final VoidCallback onTap;
  const _CalcButton({required this.isEs, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 46,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: _kCyan,
            foregroundColor: const Color(0xFF0F1116),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: Text(
            isEs ? 'CALCULAR' : 'CALCULAR',
            style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.0,
            ),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Results Section
// ─────────────────────────────────────────────────────────────────────────────
class _ResultsSection extends StatelessWidget {
  final _NephroResult result;
  final bool isEs, dark;
  final Color surf, txt, sub, border;
  final VoidCallback onDeeplink;

  const _ResultsSection({
    required this.result,
    required this.isEs,
    required this.dark,
    required this.surf,
    required this.txt,
    required this.sub,
    required this.border,
    required this.onDeeplink,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(isEs ? 'RESULTADOS' : 'RESULTADOS', sub),
        const SizedBox(height: 10),

        // CKD-EPI
        _ResultCard(
          dark: dark, surf: surf, border: border,
          icon: Icons.science_rounded,
          iconColor: _kCyan,
          title: 'CKD-EPI 2021',
          valueRow: Row(
            children: [
              Text(
                '${result.ckdEpi.toStringAsFixed(1)} mL/min/1.73m²',
                style: TextStyle(
                  color: txt, fontSize: 18, fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              _GfRBadge(gfr: result.ckdEpi, isEs: isEs),
            ],
          ),
          sub: isEs
              ? _ckdStageLabel(result.ckdEpi, es: true)
              : _ckdStageLabel(result.ckdEpi, es: false),
          subColor: _ckdColor(result.ckdEpi),
          formula: isEs
              ? 'Ecuación CKD-EPI (2021): TFG basada em Creatinina Sérica sin factor de raza.'
              : 'Equação CKD-EPI (2021): TFG baseada em Creatinina Sérica sem fator de raça.',
        ),

        const SizedBox(height: 10),

        // Cockcroft-Gault
        _ResultCard(
          dark: dark, surf: surf, border: border,
          icon: Icons.medication_liquid_rounded,
          iconColor: _kGreen,
          title: 'Cockcroft-Gault',
          valueRow: Text(
            '${result.cockcroft.toStringAsFixed(1)} mL/min',
            style: TextStyle(
              color: txt, fontSize: 18, fontWeight: FontWeight.w700,
            ),
          ),
          sub: isEs
              ? 'Utilizar para ajuste de dosis de prospecto'
              : 'Utilize para ajuste de dose de bula',
          subColor: sub,
          formula: isEs
              ? 'Fórmula: CLcr = ((140 − Edad) × Peso) / (72 × CrS) [× 0.85 si Femenino]'
              : 'Fórmula: CLcr = ((140 − Idade) × Peso) / (72 × CrS) [× 0.85 se Feminino]',
        ),

        const SizedBox(height: 10),

        // KDIGO LRA
        _ResultCard(
          dark: dark, surf: surf, border: border,
          icon: Icons.warning_amber_rounded,
          iconColor: _kdigoColor(result.kdigoStage),
          title: isEs ? 'KDIGO — LRA' : 'KDIGO — LRA',
          valueRow: Text(
            result.kdigoStage == 0
                ? (isEs ? 'Ausente' : 'Ausente')
                : 'Estágio ${result.kdigoStage}',
            style: TextStyle(
              color:      _kdigoColor(result.kdigoStage),
              fontSize:   18,
              fontWeight: FontWeight.w700,
            ),
          ),
          sub: isEs
              ? _kdigoSubEs(result.kdigoStage)
              : _kdigoSubPt(result.kdigoStage),
          subColor: _kdigoColor(result.kdigoStage).withOpacity(0.85),
          formula: 'Fórmula: Proporção = CrAtual / CrBasal  |  Δ = CrAtual − CrBasal',
        ),

        const SizedBox(height: 10),

        // FeNa
        if (result.fena != null)
          _ResultCard(
            dark: dark, surf: surf, border: border,
            icon: Icons.water_rounded,
            iconColor: _kAmber,
            title: 'FeNa',
            valueRow: Row(
              children: [
                Text(
                  '${result.fena!.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: txt, fontSize: 18, fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isEs
                      ? _fenaLabelEs(result.fena!)
                      : _fenaLabelPt(result.fena!),
                  style: const TextStyle(
                    color: _kAmber, fontSize: 11, fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            sub: isEs
                ? 'Fracción de Excreción de Sodio'
                : 'Fração de Excreção de Sódio',
            subColor: sub,
            formula: 'Fórmula: FeNa = ((NaU × CrS) / (NaS × CrU)) × 100',
          ),

        if (result.fena == null)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: surf,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Icon(Icons.water_rounded, color: _kAmber.withOpacity(0.4), size: 18),
                const SizedBox(width: 10),
                Text(
                  isEs
                      ? 'FeNa: campos opcionales vacíos'
                      : 'FeNa: campos opcionais não preenchidos',
                  style: TextStyle(color: sub, fontSize: 12),
                ),
              ],
            ),
          ),

        const SizedBox(height: 20),

        // ── Deeplink Conduta ───────────────────────────────────────────────
        _DeeplinkButton(isEs: isEs, onTap: onDeeplink),

        const SizedBox(height: 8),

        // Disclaimer Apple-compliant
        Text(
          isEs
              ? '⚕ Los resultados son de uso clínico exclusivo. La conducta terapéutica se abre en el módulo especializado.'
              : '⚕ Resultados de uso clínico exclusivo. A conduta terapêutica é aberta no módulo especializado.',
          style: TextStyle(color: sub, fontSize: 10, height: 1.4),
        ),
      ],
    );
  }

  Color _kdigoColor(int stage) {
    switch (stage) {
      case 1: return _kAmber;
      case 2: return const Color(0xFFf97316); // orange
      case 3: return _kRed;
      default: return _kGreen;
    }
  }

  String _kdigoSubEs(int stage) {
    switch (stage) {
      case 0: return 'Sin criterios de LRA (KDIGO 2012)';
      case 1: return 'Δ Cr ≥ 0.3 mg/dL en 48h ó proporción 1.5–1.9×';
      case 2: return 'Proporción creatinina 2.0–2.9× basal';
      case 3: return 'Proporción ≥ 3.0× ó Cr ≥ 4.0 mg/dL con Δ ≥ 0.5';
      default: return '';
    }
  }

  String _kdigoSubPt(int stage) {
    switch (stage) {
      case 0: return 'Sem critérios de LRA (KDIGO 2012)';
      case 1: return 'Δ Cr ≥ 0,3 mg/dL em 48h ou proporção 1,5–1,9×';
      case 2: return 'Proporção creatinina 2,0–2,9× basal';
      case 3: return 'Proporção ≥ 3,0× ou Cr ≥ 4,0 mg/dL com Δ ≥ 0,5';
      default: return '';
    }
  }

  Color _ckdColor(double gfr) {
    if (gfr >= 90) return _kGreen;
    if (gfr >= 60) return _kGreen;
    if (gfr >= 45) return _kAmber;
    if (gfr >= 30) return const Color(0xFFf97316);
    if (gfr >= 15) return _kRed;
    return const Color(0xFF7C3AED);
  }

  String _ckdStageLabel(double gfr, {required bool es}) {
    if (es) {
      if (gfr >= 90) return 'G1 — Función normal o alta';
      if (gfr >= 60) return 'G2 — Levemente disminuida';
      if (gfr >= 45) return 'G3a — Leve a moderada';
      if (gfr >= 30) return 'G3b — Moderada a grave';
      if (gfr >= 15) return 'G4 — Gravemente disminuida';
      return 'G5 — Falla renal';
    } else {
      if (gfr >= 90) return 'G1 — Função normal ou aumentada';
      if (gfr >= 60) return 'G2 — Levemente diminuída';
      if (gfr >= 45) return 'G3a — Leve a moderada';
      if (gfr >= 30) return 'G3b — Moderada a grave';
      if (gfr >= 15) return 'G4 — Gravemente diminuída';
      return 'G5 — Falência renal';
    }
  }

  String _fenaLabelEs(double fena) {
    if (fena < 1.0) return '(Etiología Prerrenal)';
    if (fena > 2.0) return '(Etiología Renal/NTA)';
    return '(Zona de transición)';
  }

  String _fenaLabelPt(double fena) {
    if (fena < 1.0) return '(Etiologia Pré-Renal)';
    if (fena > 2.0) return '(Etiologia Renal/NTA)';
    return '(Zona de transição)';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Result Card
// ─────────────────────────────────────────────────────────────────────────────
class _ResultCard extends StatelessWidget {
  final bool dark;
  final Color surf, border, iconColor, subColor;
  final IconData icon;
  final String title, sub;
  final Widget valueRow;
  final String? formula; // BUILD 409-COMPLIANCE: rodapé científico discreto

  const _ResultCard({
    required this.dark,
    required this.surf,
    required this.border,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.sub,
    required this.valueRow,
    required this.subColor,
    this.formula,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 17),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color:      iconColor,
                      fontSize:   10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  valueRow,
                  if (sub.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      sub,
                      style: TextStyle(color: subColor, fontSize: 11, height: 1.3),
                    ),
                  ],
                  if (formula != null && formula!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      formula!,
                      style: const TextStyle(
                        fontSize:  11,
                        color:     Colors.white54,
                        height:    1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// GFR Badge (G1–G5)
// ─────────────────────────────────────────────────────────────────────────────
class _GfRBadge extends StatelessWidget {
  final double gfr;
  final bool isEs;
  const _GfRBadge({required this.gfr, required this.isEs});

  String get _stage {
    if (gfr >= 90) return 'G1';
    if (gfr >= 60) return 'G2';
    if (gfr >= 45) return 'G3a';
    if (gfr >= 30) return 'G3b';
    if (gfr >= 15) return 'G4';
    return 'G5';
  }

  Color get _color {
    if (gfr >= 90) return _kGreen;
    if (gfr >= 60) return _kGreen;
    if (gfr >= 45) return _kAmber;
    if (gfr >= 30) return const Color(0xFFf97316);
    if (gfr >= 15) return _kRed;
    return const Color(0xFF7C3AED);
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color:        _color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border:       Border.all(color: _color.withOpacity(0.4)),
        ),
        child: Text(
          _stage,
          style: TextStyle(
            color: _color, fontSize: 11, fontWeight: FontWeight.w700,
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Deeplink Button
// ─────────────────────────────────────────────────────────────────────────────
class _DeeplinkButton extends StatelessWidget {
  final bool isEs;
  final VoidCallback onTap;
  const _DeeplinkButton({required this.isEs, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 50,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00B4CC), Color(0xFF00E5FF)],
              begin: Alignment.centerLeft,
              end:   Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor:     Colors.transparent,
              foregroundColor: const Color(0xFF0F1116),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isEs
                      ? 'Acceder al Soporte de Decisión Clínica'
                      : 'Acessar Suporte de Decisão Clínica',
                  style: const TextStyle(
                    fontSize:   13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward_rounded, size: 16),
              ],
            ),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// _NephroResult — resultado tipado imutável
// ─────────────────────────────────────────────────────────────────────────────
class _NephroResult {
  final double ckdEpi;
  final double cockcroft;
  final int    kdigoStage;
  final double? fena;

  const _NephroResult({
    required this.ckdEpi,
    required this.cockcroft,
    required this.kdigoStage,
    this.fena,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// _NephroEngine — motores matemáticos puros e sem efeitos colaterais
// ─────────────────────────────────────────────────────────────────────────────
class _NephroEngine {
  _NephroEngine._();

  // ── CKD-EPI 2021 (sem fator racial) ─────────────────────────────────────
  static double _ckdEpi({
    required int    age,
    required bool   isFemale,
    required double creatCurr,
  }) {
    double kappa, alpha, sexFactor;

    if (isFemale) {
      kappa     = 0.7;
      alpha     = -0.241;
      sexFactor = 1.012;
    } else {
      kappa     = 0.9;
      alpha     = -0.302;
      sexFactor = 1.0;
    }

    final ratio = creatCurr / kappa;
    final double power = creatCurr <= kappa ? alpha : -1.200;
    final gfr = 142.0 *
        math.pow(ratio, power) *
        math.pow(0.9938, age.toDouble()) *
        sexFactor;

    return _round1(gfr);
  }

  // ── Cockcroft-Gault ───────────────────────────────────────────────────────
  static double _cockcroftGault({
    required int    age,
    required bool   isFemale,
    required double weight,
    required double creatCurr,
  }) {
    double cl = ((140.0 - age) * weight) / (72.0 * creatCurr);
    if (isFemale) cl *= 0.85;
    return _round1(cl);
  }

  // ── KDIGO LRA ─────────────────────────────────────────────────────────────
  static int _kdigo({
    required double creatBase,
    required double creatCurr,
  }) {
    final delta      = creatCurr - creatBase;
    final proportion = creatCurr / creatBase;

    // Estágio 3
    if (proportion >= 3.0) return 3;
    if (creatCurr >= 4.0 && delta >= 0.5) return 3;

    // Estágio 2
    if (proportion >= 2.0) return 2;

    // Estágio 1
    if (delta >= 0.3) return 1;
    if (proportion >= 1.5) return 1;

    return 0; // Ausente
  }

  // ── FeNa ──────────────────────────────────────────────────────────────────
  // Retorna null se qualquer parâmetro for inválido (divisão por zero segura).
  static double? _fena({
    required double? naUrine,
    required double? naSerum,
    required double? creatUrine,
    required double  creatCurr,
  }) {
    if (naUrine == null || naSerum == null || creatUrine == null) return null;
    if (naSerum <= 0 || creatUrine <= 0) return null;

    final fena = (naUrine * creatCurr) / (naSerum * creatUrine) * 100.0;
    return _round1(fena);
  }

  // ── Arredondamento para 1 casa decimal ───────────────────────────────────
  static double _round1(double v) => (v * 10).round() / 10;

  // ── Fachada pública ───────────────────────────────────────────────────────
  static _NephroResult compute({
    required int     age,
    required bool    isFemale,
    required double  weight,
    required double  creatBase,
    required double  creatCurr,
    double? naUrine,
    double? naSerum,
    double? creatUrine,
  }) {
    return _NephroResult(
      ckdEpi: _ckdEpi(
        age:       age,
        isFemale:  isFemale,
        creatCurr: creatCurr,
      ),
      cockcroft: _cockcroftGault(
        age:       age,
        isFemale:  isFemale,
        weight:    weight,
        creatCurr: creatCurr,
      ),
      kdigoStage: _kdigo(
        creatBase: creatBase,
        creatCurr: creatCurr,
      ),
      fena: _fena(
        naUrine:    naUrine,
        naSerum:    naSerum,
        creatUrine: creatUrine,
        creatCurr:  creatCurr,
      ),
    );
  }
}
