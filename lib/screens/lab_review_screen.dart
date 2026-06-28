// ── lib/screens/lab_review_screen.dart ───────────────────────────────────────
// Tela de revisão dos parâmetros laboratoriais extraídos por OCR/IA.
//
// Fluxo:
//   1. Recebe a lista de LabResult extraídos pelo LabParserService
//   2. Exibe cada parâmetro em card editável com indicação visual de confiança
//   3. Campos com confidence < 0.70 são esvaziados para inserção manual
//   4. Campos com confidence 0.70–0.85 recebem destaque amarelo de revisão
//   5. "Confirmar e Calcular" dispara LabInterpreter e exibe resultados
//
// Design: dark-first, alinhado ao design system do MedCases Pro.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/lab_result_model.dart';
import '../services/lab_interpreter.dart';

// ── Paleta interna ─────────────────────────────────────────────────────────

class _C {
  static const bg          = Color(0xFF07100D);
  static const surface     = Color(0xFF0F1A14);
  static const surfaceHigh = Color(0xFF17231C);
  static const border      = Color(0xFF1D3025);
  static const borderAmber = Color(0xFFF59E0B);
  static const borderRed   = Color(0xFF991B1B);
  static const green       = Color(0xFF46E28C);
  static const greenDark   = Color(0xFF10B981);
  static const amber       = Color(0xFFF59E0B);
  static const amberBg     = Color(0x1DF59E0B);
  static const red         = Color(0xFFEF4444);
  static const redBg       = Color(0x1DEF4444);
  static const orangeBg    = Color(0x1DFF8C00);
  static const textPrimary = Color(0xFFF0F4F1);
  static const textSec     = Color(0xFF8FA898);
  static const cardNormal  = Color(0xFF121C18);
  static const cardAmber   = Color(0xFF2A2112);
  static const cardRed     = Color(0xFF251515);
  static const cardOrange  = Color(0xFF221A0C);
}

// ── Tela principal ─────────────────────────────────────────────────────────────

class LabReviewScreen extends StatefulWidget {
  final List<LabResult> initialResults;
  final String locale;

  const LabReviewScreen({
    super.key,
    required this.initialResults,
    required this.locale,
  });

  @override
  State<LabReviewScreen> createState() => _LabReviewScreenState();
}

class _LabReviewScreenState extends State<LabReviewScreen> {
  late List<LabResult> _results;
  late List<TextEditingController> _ctls;
  bool _calculating = false;

  // ── Inicialização ─────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // Limpa campos de baixa confiança para forçar revisão manual
    _results = widget.initialResults.map((e) {
      return e.confidence < 0.70 ? e.copyWith(value: 0) : e;
    }).toList();

    _ctls = _results.map((e) {
      final text = e.confidence < 0.70 ? '' : _fmtValue(e.value);
      return TextEditingController(text: text);
    }).toList();
  }

  @override
  void dispose() {
    for (final c in _ctls) { c.dispose(); }
    super.dispose();
  }

  // ── Lógica principal ──────────────────────────────────────────────────────

  void _confirmAndCalculate() {
    final isEs = _isEs;
    final updated = <LabResult>[];

    for (int i = 0; i < _results.length; i++) {
      final raw   = _ctls[i].text.trim().replaceAll(',', '.');
      final value = double.tryParse(raw);

      if (value == null || (raw.isEmpty)) {
        // Campo obrigatório vazio — scroll até ele e avisa
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: _C.cardAmber,
            content: Row(children: [
              const Icon(Icons.warning_amber_rounded, color: _C.amber, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isEs
                      ? 'Complete el valor de "${_results[i].examName}".'
                      : 'Preencha o valor de "${_results[i].examName}".',
                  style: const TextStyle(color: _C.amber, fontSize: 13),
                ),
              ),
            ]),
          ));
        return;
      }
      updated.add(_results[i].copyWith(value: value));
    }

    setState(() => _calculating = true);

    // Roda em microtask para não bloquear o frame do spinner
    Future.microtask(() {
      final calculated = LabInterpreter.calculate(updated, widget.locale);
      final summary    = LabInterpreter.buildEducationalSummary(
          updated, calculated, widget.locale);

      if (!mounted) return;
      setState(() => _calculating = false);

      _showResultsSheet(updated, calculated, summary);
    });
  }

  // ── Sheet de resultados ───────────────────────────────────────────────────

  void _showResultsSheet(
    List<LabResult> labs,
    List<LabCalculatedResult> calculated,
    String summary,
  ) {
    final isEs = _isEs;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ResultsSheet(
        labs:       labs,
        calculated: calculated,
        summary:    summary,
        isEs:       isEs,
      ),
    );
  }

  // ── Helpers de UI ────────────────────────────────────────────────────────

  bool get _isEs => widget.locale.toLowerCase() == 'es';

  /// Formata valor evitando ".0" desnecessário para inteiros.
  String _fmtValue(double v) {
    if (v == v.roundToDouble() && v < 1000000) {
      return v.toStringAsFixed(0);
    }
    return v.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  Color _cardBg(LabResult lab) {
    if (lab.status == LabStatus.critical) return _C.cardRed;
    if (lab.confidence < 0.70)           return _C.cardOrange;
    if (lab.confidence < 0.85)           return _C.cardAmber;
    return _C.cardNormal;
  }

  Color _cardBorder(LabResult lab) {
    if (lab.status == LabStatus.critical) return _C.borderRed;
    if (lab.confidence < 0.85)           return _C.borderAmber.withOpacity(0.55);
    return _C.border;
  }

  Color _statusColor(LabStatus s) {
    switch (s) {
      case LabStatus.critical: return _C.red;
      case LabStatus.high:     return _C.amber;
      case LabStatus.low:      return const Color(0xFF60A5FA);
      case LabStatus.normal:   return _C.green;
    }
  }

  String _statusLabel(LabStatus s) {
    final isEs = _isEs;
    switch (s) {
      case LabStatus.critical: return isEs ? 'Crítico' : 'Crítico';
      case LabStatus.high:     return isEs ? 'Alto'    : 'Alto';
      case LabStatus.low:      return isEs ? 'Bajo'    : 'Baixo';
      case LabStatus.normal:   return isEs ? 'Normal'  : 'Normal';
    }
  }

  String _confidenceLabel(double conf, bool isEs) {
    if (conf >= 0.85) return isEs ? 'Alta confianza'    : 'Alta confiança';
    if (conf >= 0.70) return isEs ? 'Revisar valor'     : 'Revisar valor';
    return                   isEs ? 'Ingreso manual'    : 'Inserir manualmente';
  }

  Widget _confidenceBadge(LabResult lab) {
    final isEs = _isEs;
    final pct  = (lab.confidence * 100).toStringAsFixed(0);
    final col  = lab.confidence >= 0.85
        ? _C.green
        : (lab.confidence >= 0.70 ? _C.amber : const Color(0xFFFF8C00));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          lab.confidence >= 0.85
              ? Icons.verified_rounded
              : Icons.warning_amber_rounded,
          size: 12,
          color: col,
        ),
        const SizedBox(width: 4),
        Text(
          '${_confidenceLabel(lab.confidence, isEs)} · $pct%',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: col,
          ),
        ),
      ],
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isEs      = _isEs;
    final critCount = _results.where((r) => r.status == LabStatus.critical).length;
    final lowConf   = _results.where((r) => r.confidence < 0.70).length;

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.bg,
        foregroundColor: _C.textPrimary,
        elevation: 0,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEs ? 'Revisar Examen' : 'Revisar Exame',
              style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w800,
                color: _C.textPrimary,
              ),
            ),
            Text(
              '${_results.length} ${isEs ? "parámetros extraídos" : "parâmetros extraídos"}',
              style: const TextStyle(fontSize: 11, color: _C.textSec),
            ),
          ],
        ),
        actions: [
          // Botão reanalisar
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.refresh_rounded, size: 16, color: _C.green),
            label: Text(
              isEs ? 'Reanalisar' : 'Reanalisar',
              style: const TextStyle(fontSize: 12, color: _C.green),
            ),
          ),
        ],
      ),

      body: Column(
        children: [

          // ── Banner de avisos ─────────────────────────────────────────────
          _InfoBanner(
            critCount: critCount,
            lowConf:   lowConf,
            isEs:      isEs,
          ),

          // ── Lista de parâmetros ──────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              itemCount: _results.length,
              itemBuilder: (ctx, i) => _LabCard(
                lab:        _results[i],
                controller: _ctls[i],
                cardBg:     _cardBg(_results[i]),
                cardBorder: _cardBorder(_results[i]),
                statusColor:  _statusColor(_results[i].status),
                statusLabel:  _statusLabel(_results[i].status),
                confidenceBadge: _confidenceBadge(_results[i]),
                isEs: isEs,
              ),
            ),
          ),
        ],
      ),

      // ── Bottom bar ────────────────────────────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: _C.surface,
            border: const Border(top: BorderSide(color: _C.border, width: 0.5)),
          ),
          child: ElevatedButton(
            onPressed: _calculating ? null : _confirmAndCalculate,
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.green,
              foregroundColor: Colors.black,
              disabledBackgroundColor: _C.greenDark,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _calculating
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black54,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.science_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        isEs ? 'Confirmar y Calcular' : 'Confirmar e Calcular',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ── Card de parâmetro individual ───────────────────────────────────────────────

class _LabCard extends StatelessWidget {
  final LabResult lab;
  final TextEditingController controller;
  final Color cardBg;
  final Color cardBorder;
  final Color statusColor;
  final String statusLabel;
  final Widget confidenceBadge;
  final bool isEs;

  const _LabCard({
    required this.lab,
    required this.controller,
    required this.cardBg,
    required this.cardBorder,
    required this.statusColor,
    required this.statusLabel,
    required this.confidenceBadge,
    required this.isEs,
  });

  @override
  Widget build(BuildContext context) {
    final needsManual = lab.confidence < 0.70;
    final needsReview = lab.confidence < 0.85 && lab.confidence >= 0.70;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: needsManual || needsReview ? 1.0 : 0.6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Linha superior: nome + badge confiança ─────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nome + status badge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        // Indicador crítico
                        if (lab.status == LabStatus.critical)
                          Container(
                            width: 8, height: 8,
                            margin: const EdgeInsets.only(right: 6, top: 2),
                            decoration: const BoxDecoration(
                              color: _C.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        Flexible(
                          child: Text(
                            lab.examName,
                            style: TextStyle(
                              color: lab.status == LabStatus.critical
                                  ? _C.red
                                  : _C.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ]),

                      const SizedBox(height: 4),

                      // Badge confiança
                      confidenceBadge,

                      // Ref range
                      if (lab.referenceRange != null &&
                          lab.referenceRange!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            '${isEs ? "Ref" : "Ref"}: ${lab.referenceRange}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: _C.textSec,
                            ),
                          ),
                        ),

                      // Aviso inserção manual
                      if (needsManual)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            isEs
                                ? '⚠ Baja confianza — inserte el valor manualmente'
                                : '⚠ Baixa confiança — insira o valor manualmente',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFFFF8C00),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // ── Input de valor ────────────────────────────────────────
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: controller,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: false,
                        ),
                        inputFormatters: [
                          // Aceita dígitos, ponto e vírgula (vírgula convertida depois)
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[\d.,\-]'),
                          ),
                        ],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                        decoration: InputDecoration(
                          hintText: '—',
                          hintStyle: const TextStyle(
                            color: _C.textSec,
                            fontWeight: FontWeight.w400,
                          ),
                          suffixText: lab.unit,
                          suffixStyle: const TextStyle(
                            fontSize: 10,
                            color: _C.textSec,
                          ),
                          filled: true,
                          fillColor: Colors.black.withOpacity(0.20),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 9,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: statusColor.withOpacity(0.35),
                              width: 1.0,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: statusColor,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: statusColor.withOpacity(0.12),
                        border: Border.all(
                          color: statusColor.withOpacity(0.30),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // ── Texto original (expansível via tooltip) ───────────────────
            if (lab.originalText.isNotEmpty && lab.originalText != '0')
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '"${lab.originalText}"',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: _C.textSec,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Banner informativo (avisos de críticos + baixa confiança) ─────────────────

class _InfoBanner extends StatelessWidget {
  final int critCount;
  final int lowConf;
  final bool isEs;

  const _InfoBanner({
    required this.critCount,
    required this.lowConf,
    required this.isEs,
  });

  @override
  Widget build(BuildContext context) {
    final hasCrit = critCount > 0;
    final hasLow  = lowConf > 0;

    return Column(
      children: [
        // Banner segurança sempre visível
        Container(
          width: double.infinity,
          color: _C.amberBg,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            const Icon(Icons.shield_outlined, color: _C.amber, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isEs
                    ? 'Revise todos los valores antes de continuar. '
                      'Los campos resaltados requieren confirmación.'
                    : 'Revise todos os valores antes de continuar. '
                      'Campos destacados requerem confirmação.',
                style: const TextStyle(
                  color: _C.amber,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
          ]),
        ),

        // Banner críticos (se houver)
        if (hasCrit)
          Container(
            width: double.infinity,
            color: _C.redBg,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              const Icon(Icons.emergency_rounded, color: _C.red, size: 15),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isEs
                      ? '$critCount parámetro(s) con valor CRÍTICO detectado(s). '
                        'Evaluar urgentemente.'
                      : '$critCount parâmetro(s) com valor CRÍTICO detectado(s). '
                        'Avaliar com urgência.',
                  style: const TextStyle(
                    color: _C.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ]),
          ),

        // Banner baixa confiança (se houver)
        if (hasLow)
          Container(
            width: double.infinity,
            color: _C.orangeBg,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              const Icon(Icons.edit_note_rounded,
                  color: Color(0xFFFF8C00), size: 15),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isEs
                      ? '$lowConf campo(s) con baja confianza — inserta los '
                        'valores manualmente.'
                      : '$lowConf campo(s) com baixa confiança — insira os '
                        'valores manualmente.',
                  style: const TextStyle(
                    color: Color(0xFFFF8C00),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ]),
          ),
      ],
    );
  }
}

// ── Sheet de resultados calculados ────────────────────────────────────────────

class _ResultsSheet extends StatelessWidget {
  final List<LabResult> labs;
  final List<LabCalculatedResult> calculated;
  final String summary;
  final bool isEs;

  const _ResultsSheet({
    required this.labs,
    required this.calculated,
    required this.summary,
    required this.isEs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D1912),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          // Título
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Row(children: [
              const Icon(Icons.science_rounded, color: _C.green, size: 20),
              const SizedBox(width: 8),
              Text(
                isEs
                    ? 'Interpretación Clínica'
                    : 'Interpretação Clínica',
                style: const TextStyle(
                  color: _C.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: _C.textSec, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),

          // Conteúdo rolável
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Parâmetros calculados
                  if (calculated.isNotEmpty) ...{
                    Text(
                      isEs
                          ? 'PARÁMETROS CALCULADOS'
                          : 'PARÂMETROS CALCULADOS',
                      style: const TextStyle(
                        color: _C.textSec,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...calculated.map((c) => _CalcCard(calc: c, isEs: isEs)),
                    const SizedBox(height: 16),
                  },

                  // Resumo educacional
                  Text(
                    isEs ? 'RESUMO CLÍNICO' : 'RESUMO CLÍNICO',
                    style: const TextStyle(
                      color: _C.textSec,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _C.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _C.border, width: 0.8),
                    ),
                    child: Text(
                      summary,
                      style: const TextStyle(
                        color: _C.textPrimary,
                        fontSize: 13,
                        height: 1.55,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Aviso legal
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _C.amberBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _C.borderAmber.withOpacity(0.30),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            color: _C.amber, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isEs
                                ? 'Resultado extraído automáticamente. Cotejar con '
                                  'el examen original antes de cualquier decisión '
                                  'clínica.'
                                : 'Resultado extraído automaticamente. Conferir com '
                                  'o exame original antes de qualquer decisão '
                                  'clínica.',
                            style: const TextStyle(
                              color: _C.amber,
                              fontSize: 11.5,
                              height: 1.4,
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
          ),
        ],
      ),
    );
  }
}

// ── Card de parâmetro calculado ────────────────────────────────────────────────

class _CalcCard extends StatelessWidget {
  final LabCalculatedResult calc;
  final bool isEs;

  const _CalcCard({required this.calc, required this.isEs});

  Color get _statusColor {
    switch (calc.status) {
      case LabStatus.critical: return _C.red;
      case LabStatus.high:     return _C.amber;
      case LabStatus.low:      return const Color(0xFF60A5FA);
      case LabStatus.normal:   return _C.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _statusColor.withOpacity(0.28),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  calc.title,
                  style: const TextStyle(
                    color: _C.textSec,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${calc.value.toStringAsFixed(2)} ${calc.unit}',
                style: TextStyle(
                  color: _statusColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            calc.interpretation,
            style: const TextStyle(
              color: _C.textSec,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
