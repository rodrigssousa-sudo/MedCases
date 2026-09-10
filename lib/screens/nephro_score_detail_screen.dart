import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../providers/tools_state_provider.dart';
import '../services/nephro/nephro_score_engine_2026.dart';
import 'calculadora_screen.dart';

const _green = Color(0xFF009C3B);
const _darkPage = Color(0xFF171B21);
const _darkSurface = Color(0xFF20252D);
const _darkField = Color(0xFF222A35);
const _darkBorder = Color(0xFF374151);
const _lightPage = Color(0xFFECF0F4);
const _lightBorder = Color(0xFFE2E7EC);

enum NephroScoreId {
  ckdEpi2021,
  ckdGa,
  cockcroftGault,
  kfre4,
  kdigoAki,
  fena,
  feUrea,
}

class NephroScoreDetailScreen extends StatefulWidget {
  final NephroScoreId scoreId;

  const NephroScoreDetailScreen({
    super.key,
    required this.scoreId,
  });

  @override
  State<NephroScoreDetailScreen> createState() =>
      _NephroScoreDetailScreenState();
}

class _NephroScoreDetailScreenState extends State<NephroScoreDetailScreen> {
  final _age = TextEditingController(text: '50');
  final _weight = TextEditingController(text: '70');
  final _creatinine = TextEditingController(text: '1.0');
  final _egfr = TextEditingController(text: '45');
  final _acr = TextEditingController(text: '30');
  final _baselineCr = TextEditingController(text: '1.0');
  final _currentCr = TextEditingController(text: '1.5');
  final _urineRate = TextEditingController();
  final _urineHours = TextEditingController();
  final _anuriaHours = TextEditingController();
  final _uNa = TextEditingController(text: '20');
  final _pNa = TextEditingController(text: '140');
  final _uCr = TextEditingController(text: '100');
  final _pCr = TextEditingController(text: '2');
  final _uUrea = TextEditingController(text: '300');
  final _pUrea = TextEditingController(text: '80');

  bool _female = false;
  bool _rise03 = false;
  bool _krt = false;
  KfreCalibration _kfreCalibration = KfreCalibration.nonNorthAmerica;

  String? _value;
  String? _band;
  String? _interpretation;
  Map<String, String> _payload = const {};

  @override
  void dispose() {
    for (final c in [
      _age,
      _weight,
      _creatinine,
      _egfr,
      _acr,
      _baselineCr,
      _currentCr,
      _urineRate,
      _urineHours,
      _anuriaHours,
      _uNa,
      _pNa,
      _uCr,
      _pCr,
      _uUrea,
      _pUrea,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _isEs => context.read<AppProvider>().lang == 'es';

  String get _name => switch (widget.scoreId) {
        NephroScoreId.ckdEpi2021 => 'CKD-EPI 2021',
        NephroScoreId.ckdGa => 'KDIGO G/A',
        NephroScoreId.cockcroftGault => 'Cockcroft-Gault',
        NephroScoreId.kfre4 => 'KFRE 4 variables',
        NephroScoreId.kdigoAki => 'KDIGO AKI',
        NephroScoreId.fena => 'FENa',
        NephroScoreId.feUrea => 'FEUrea',
      };

  String get _eyebrow => switch (widget.scoreId) {
        NephroScoreId.ckdEpi2021 ||
        NephroScoreId.ckdGa ||
        NephroScoreId.cockcroftGault =>
          _isEs ? 'FUNCIÓN RENAL · ERC' : 'FUNÇÃO RENAL · DRC',
        NephroScoreId.kfre4 =>
          _isEs ? 'PROGRESIÓN · FALLA RENAL' : 'PROGRESSÃO · FALÊNCIA RENAL',
        NephroScoreId.kdigoAki =>
          _isEs ? 'LESIÓN RENAL AGUDA' : 'LESÃO RENAL AGUDA',
        NephroScoreId.fena ||
        NephroScoreId.feUrea =>
          _isEs ? 'ÍNDICES URINARIOS' : 'ÍNDICES URINÁRIOS',
      };

  String get _explanation => switch (widget.scoreId) {
        NephroScoreId.ckdEpi2021 => _isEs
            ? 'Estima TFG en adultos con creatinina, edad y sexo usando CKD-EPI 2021 sin coeficiente de raza.'
            : 'Estima TFG em adultos com creatinina, idade e sexo usando CKD-EPI 2021 sem coeficiente de raça.',
        NephroScoreId.ckdGa => _isEs
            ? 'Clasifica ERC por categoría de TFG (G1–G5) y albuminuria (A1–A3).'
            : 'Classifica DRC por categoria de TFG (G1–G5) e albuminúria (A1–A3).',
        NephroScoreId.cockcroftGault => _isEs
            ? 'Estima aclaramiento de creatinina no indexado, usado en algunos contextos de ajuste farmacológico.'
            : 'Estima clearance de creatinina não indexado, usado em alguns contextos de ajuste farmacológico.',
        NephroScoreId.kfre4 => _isEs
            ? 'Predice riesgo de falla renal a 2 y 5 años en adultos con ERC usando edad, sexo, eGFR y ACR.'
            : 'Prediz risco de falência renal em 2 e 5 anos em adultos com DRC usando idade, sexo, eGFR e ACR.',
        NephroScoreId.kdigoAki => _isEs
            ? 'Estadia AKI por creatinina y diuresis según KDIGO final 2012. El borrador AKI/AKD 2026 no se trata como guía final.'
            : 'Estagia LRA por creatinina e diurese segundo KDIGO final 2012. O draft AKI/AKD 2026 não é tratado como guia final.',
        NephroScoreId.fena => _isEs
            ? 'Fracción excretada de sodio. Puede apoyar la interpretación fisiológica, pero no define etiología por sí sola.'
            : 'Fração excretada de sódio. Pode apoiar a interpretação fisiológica, mas não define etiologia isoladamente.',
        NephroScoreId.feUrea => _isEs
            ? 'Fracción excretada de urea. Puede ser útil como complemento, especialmente cuando FENa es menos interpretable.'
            : 'Fração excretada de ureia. Pode ser útil como complemento, especialmente quando a FENa é menos interpretável.',
      };

  String get _limitations => switch (widget.scoreId) {
        NephroScoreId.ckdEpi2021 => _isEs
            ? 'Usar creatinina estandarizada. La eGFR es una estimación y puede ser menos fiable en situaciones con creatinina no estable.'
            : 'Usar creatinina padronizada. A eGFR é uma estimativa e pode ser menos confiável com creatinina não estável.',
        NephroScoreId.ckdGa => _isEs
            ? 'G1/G2 aislados no confirman ERC sin marcadores persistentes de daño renal.'
            : 'G1/G2 isolados não confirmam DRC sem marcadores persistentes de dano renal.',
        NephroScoreId.cockcroftGault => _isEs
            ? 'La elección del peso corporal puede cambiar el resultado. No sustituye eGFR para clasificación de ERC.'
            : 'A escolha do peso corporal pode alterar o resultado. Não substitui eGFR para classificação de DRC.',
        NephroScoreId.kfre4 => _isEs
            ? 'Aplicar en adultos con ERC y eGFR <60. Elegir la calibración correspondiente a la población; no usar en AKI/AKD.'
            : 'Aplicar em adultos com DRC e eGFR <60. Escolher a calibração correspondente à população; não usar em LRA/AKD.',
        NephroScoreId.kdigoAki => _isEs
            ? 'Usar el peor criterio entre creatinina y diuresis. Requiere cronología clínica fiable.'
            : 'Usar o pior critério entre creatinina e diurese. Exige cronologia clínica confiável.',
        NephroScoreId.fena => _isEs
            ? 'Diuréticos, ERC, sepsis, pigmentos y otras condiciones pueden limitar su interpretación.'
            : 'Diuréticos, DRC, sepse, pigmentos e outras condições podem limitar sua interpretação.',
        NephroScoreId.feUrea => _isEs
            ? 'No es un marcador etiológico absoluto; interpretar junto a sedimento, historia, volumen y contexto.'
            : 'Não é marcador etiológico absoluto; interpretar junto com sedimento, história, volume e contexto.',
      };

  String get _reference => switch (widget.scoreId) {
        NephroScoreId.ckdEpi2021 =>
          'NIDDK / NKF · CKD-EPI Creatinine Equation 2021 · KDIGO CKD 2024',
        NephroScoreId.ckdGa => 'KDIGO Clinical Practice Guideline for CKD 2024',
        NephroScoreId.cockcroftGault =>
          'Cockcroft-Gault · drug-label / pharmacokinetic context',
        NephroScoreId.kfre4 =>
          'Tangri KFRE 4-variable · JAMA 2011/2016 · KDIGO CKD 2024',
        NephroScoreId.kdigoAki =>
          'KDIGO AKI 2012 final guideline · 2026 AKI/AKD public-review draft noted separately',
        NephroScoreId.fena ||
        NephroScoreId.feUrea =>
          'Physiologic urinary fractional excretion calculation · clinical-context interpretation',
      };

  int _i(TextEditingController c, int fallback) =>
      int.tryParse(c.text.trim()) ?? fallback;
  double _d(TextEditingController c, double fallback) =>
      double.tryParse(c.text.trim().replaceAll(',', '.')) ?? fallback;
  double? _dn(TextEditingController c) {
    final t = c.text.trim().replaceAll(',', '.');
    return t.isEmpty ? null : double.tryParse(t);
  }

  void _importPatient() {
    final tools = context.read<ToolsStateProvider>();
    setState(() {
      if (tools.ageCtrl.text.trim().isNotEmpty) {
        _age.text = tools.ageCtrl.text.trim();
      }
      if (tools.weightCtrl.text.trim().isNotEmpty) {
        _weight.text = tools.weightCtrl.text.trim();
      }
      if (tools.crCtrl.text.trim().isNotEmpty) {
        _creatinine.text = tools.crCtrl.text.trim();
      }
      if (tools.naCtrl.text.trim().isNotEmpty) {
        _pNa.text = tools.naCtrl.text.trim();
      }
      _female = tools.isFemale;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isEs
              ? 'Datos disponibles importados.'
              : 'Dados disponíveis importados.',
        ),
        duration: const Duration(milliseconds: 1100),
      ),
    );
  }

  void _set({
    required String value,
    required String band,
    required String interpretation,
    required Map<String, String> payload,
  }) {
    setState(() {
      _value = value;
      _band = band;
      _interpretation = interpretation;
      _payload = payload;
    });
  }

  void _calculate() {
    try {
      switch (widget.scoreId) {
        case NephroScoreId.ckdEpi2021:
          final e = NephroScoreEngine2026.ckdEpi2021Creatinine(
            ageYears: _i(_age, 50),
            female: _female,
            serumCreatinineMgDl: _d(_creatinine, 1),
          );
          final ga = NephroScoreEngine2026.ckdGa(
            egfrMlMin173: e,
            acrMgG: _d(_acr, 0),
          );
          _set(
            value: '${e.toStringAsFixed(1)} mL/min/1.73m²',
            band: ga.gCategory,
            interpretation: _isEs
                ? 'Resultado CKD-EPI 2021. La categoría G debe integrarse con albuminuria y persistencia para evaluar ERC.'
                : 'Resultado CKD-EPI 2021. A categoria G deve ser integrada à albuminúria e persistência para avaliar DRC.',
            payload: {
              'score': 'ckd_epi_2021',
              'egfr': e.toStringAsFixed(1),
            },
          );
        case NephroScoreId.ckdGa:
          final r = NephroScoreEngine2026.ckdGa(
            egfrMlMin173: _d(_egfr, 45),
            acrMgG: _d(_acr, 30),
          );
          _set(
            value: r.combined,
            band: '${r.gCategory} · ${r.aCategory}',
            interpretation: _isEs
                ? 'Clasificación combinada de filtrado y albuminuria.'
                : 'Classificação combinada de filtração e albuminúria.',
            payload: {
              'score': 'kdigo_ckd_ga',
              'ckdG': r.gCategory,
              'ckdA': r.aCategory,
            },
          );
        case NephroScoreId.cockcroftGault:
          final r = NephroScoreEngine2026.cockcroftGault(
            ageYears: _i(_age, 50),
            female: _female,
            weightKg: _d(_weight, 70),
            serumCreatinineMgDl: _d(_creatinine, 1),
          );
          _set(
            value: '${r.toStringAsFixed(1)} mL/min',
            band: _isEs ? 'CrCl estimado' : 'CrCl estimado',
            interpretation: _isEs
                ? 'Usar solo cuando el fármaco/protocolo requiera CrCl Cockcroft-Gault.'
                : 'Usar apenas quando o fármaco/protocolo exigir CrCl Cockcroft-Gault.',
            payload: {
              'score': 'cockcroft_gault',
              'crcl': r.toStringAsFixed(1),
            },
          );
        case NephroScoreId.kfre4:
          final r = NephroScoreEngine2026.kfre4(
            ageYears: _i(_age, 50),
            male: !_female,
            egfrMlMin173: _d(_egfr, 45),
            acrMgG: _d(_acr, 30),
            calibration: _kfreCalibration,
          );
          _set(
            value:
                '2a ${r.risk2YearPercent.toStringAsFixed(1)}% · 5a ${r.risk5YearPercent.toStringAsFixed(1)}%',
            band: _kfreCalibration == KfreCalibration.northAmerica
                ? 'North America'
                : 'Non-North America',
            interpretation: _isEs
                ? 'Riesgo estimado de falla renal con KFRE 4 variables; usar para planificación y seguimiento, no como orden automática de terapia renal.'
                : 'Risco estimado de falência renal pelo KFRE 4 variáveis; usar para planejamento e seguimento, não como ordem automática de terapia renal.',
            payload: {
              'score': 'kfre4',
              'kfre2y': r.risk2YearPercent.toStringAsFixed(1),
              'kfre5y': r.risk5YearPercent.toStringAsFixed(1),
            },
          );
        case NephroScoreId.kdigoAki:
          final r = NephroScoreEngine2026.kdigoAki(
            baselineCreatinineMgDl: _d(_baselineCr, 1),
            currentCreatinineMgDl: _d(_currentCr, 1.5),
            creatinineRiseAtLeast03Within48h: _rise03,
            urineMlKgH: _dn(_urineRate),
            urineDurationHours: _dn(_urineHours),
            anuriaHours: _dn(_anuriaHours),
            kidneyReplacementTherapy: _krt,
          );
          _set(
            value: r.stage == 0 ? 'Sem estágio' : 'KDIGO ${r.stage}',
            band: 'Cr ${r.creatinineStage} · Diurese ${r.urineStage}',
            interpretation: _isEs
                ? 'Se usa el estadio más alto entre creatinina y diuresis.'
                : 'Usa-se o estágio mais alto entre creatinina e diurese.',
            payload: {
              'score': 'kdigo_aki',
              'kdigoAkiStage': '${r.stage}',
            },
          );
        case NephroScoreId.fena:
          final r = NephroScoreEngine2026.fenaPercent(
            urineSodium: _d(_uNa, 20),
            plasmaSodium: _d(_pNa, 140),
            urineCreatinine: _d(_uCr, 100),
            plasmaCreatinine: _d(_pCr, 2),
          );
          _set(
            value: '${r.toStringAsFixed(2)}%',
            band: 'FENa',
            interpretation: _isEs
                ? 'Interpretar como índice fisiológico, no como diagnóstico etiológico aislado.'
                : 'Interpretar como índice fisiológico, não como diagnóstico etiológico isolado.',
            payload: {'score': 'fena', 'fena': r.toStringAsFixed(2)},
          );
        case NephroScoreId.feUrea:
          final r = NephroScoreEngine2026.feUreaPercent(
            urineUrea: _d(_uUrea, 300),
            plasmaUrea: _d(_pUrea, 80),
            urineCreatinine: _d(_uCr, 100),
            plasmaCreatinine: _d(_pCr, 2),
          );
          _set(
            value: '${r.toStringAsFixed(2)}%',
            band: 'FEUrea',
            interpretation: _isEs
                ? 'Usar como complemento fisiológico; no define etiología por sí sola.'
                : 'Usar como complemento fisiológico; não define etiologia isoladamente.',
            payload: {'score': 'feurea', 'feUrea': r.toStringAsFixed(2)},
          );
      }
    } on Object catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEs ? 'Revise los datos.' : 'Revise os dados.'),
        ),
      );
    }
  }

  void _openCalculator() {
    final tools = context.read<ToolsStateProvider>();
    final lang = _isEs ? 'es' : 'pt';
    final baseQuery = tools.buildQueryStringForSpecialty('nefro', lang);
    final basePayload =
        baseQuery.startsWith('?') ? baseQuery.substring(1) : baseQuery;
    final scorePayload = _payload.entries
        .map(
          (e) =>
              '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
        )
        .join('&');
    final parts = <String>[
      if (basePayload.isNotEmpty) basePayload,
      if (scorePayload.isNotEmpty) scorePayload,
    ];
    final url =
        'https://medcasescalcu.com/?modulo=nefrologia&${parts.join('&')}';

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CalculadoraScreen(initialUrl: url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final dark = app.darkMode;
    final bg = dark ? _darkPage : _lightPage;
    final title = dark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    final sub = dark ? const Color(0xFFAEB9CC) : const Color(0xFF64748B);
    final border = dark ? _darkBorder : _lightBorder;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Topbar(dark: dark, title: _isEs ? 'NEFROLOGÍA' : 'NEFROLOGIA'),
            const SizedBox(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 7, 16, 0),
              child:
                  _ImportButton(dark: dark, isEs: _isEs, onTap: _importPatient),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _eyebrow,
                      style: const TextStyle(
                        color: _green,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.9,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _name,
                      style: TextStyle(
                        color: title,
                        fontSize: 24,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.45,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      _explanation,
                      style: TextStyle(
                        color: sub,
                        fontSize: 12.5,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 17),
                    Divider(color: border, height: 1, thickness: 0.7),
                    const SizedBox(height: 17),
                    _inputs(dark),
                    const SizedBox(height: 18),
                    _ActionButton(
                        label: _isEs ? 'CALCULAR' : 'CALCULAR',
                        onTap: _calculate),
                    if (_value != null) ...[
                      const SizedBox(height: 22),
                      _Result(
                        dark: dark,
                        value: _value!,
                        band: _band ?? '',
                        interpretation: _interpretation ?? '',
                      ),
                      const SizedBox(height: 18),
                      _Explanation(
                        dark: dark,
                        isEs: _isEs,
                        limitations: _limitations,
                        reference: _reference,
                      ),
                      const SizedBox(height: 16),
                      _CalculatorButton(
                          dark: dark, isEs: _isEs, onTap: _openCalculator),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputs(bool dark) {
    switch (widget.scoreId) {
      case NephroScoreId.ckdEpi2021:
        return Column(children: [
          Row(children: [
            Expanded(
                child: _Field(
                    dark: dark,
                    controller: _age,
                    label: _isEs ? 'Edad' : 'Idade')),
            const SizedBox(width: 8),
            Expanded(
                child: _Field(
                    dark: dark,
                    controller: _creatinine,
                    label: 'Creatinina mg/dL')),
          ]),
          const SizedBox(height: 10),
          _Sex(
              dark: dark,
              isEs: _isEs,
              female: _female,
              onChanged: (v) => setState(() => _female = v)),
          const SizedBox(height: 10),
          _Field(
              dark: dark,
              controller: _acr,
              label: 'ACR mg/g (opcional p/ G/A)'),
        ]);
      case NephroScoreId.ckdGa:
        return Column(children: [
          _Field(dark: dark, controller: _egfr, label: 'eGFR mL/min/1.73m²'),
          const SizedBox(height: 10),
          _Field(dark: dark, controller: _acr, label: 'ACR mg/g'),
        ]);
      case NephroScoreId.cockcroftGault:
        return Column(children: [
          Row(children: [
            Expanded(
                child: _Field(
                    dark: dark,
                    controller: _age,
                    label: _isEs ? 'Edad' : 'Idade')),
            const SizedBox(width: 8),
            Expanded(
                child:
                    _Field(dark: dark, controller: _weight, label: 'Peso kg')),
          ]),
          const SizedBox(height: 10),
          _Field(
              dark: dark, controller: _creatinine, label: 'Creatinina mg/dL'),
          const SizedBox(height: 10),
          _Sex(
              dark: dark,
              isEs: _isEs,
              female: _female,
              onChanged: (v) => setState(() => _female = v)),
        ]);
      case NephroScoreId.kfre4:
        return Column(children: [
          Row(children: [
            Expanded(
                child: _Field(
                    dark: dark,
                    controller: _age,
                    label: _isEs ? 'Edad' : 'Idade')),
            const SizedBox(width: 8),
            Expanded(
                child: _Field(dark: dark, controller: _egfr, label: 'eGFR')),
          ]),
          const SizedBox(height: 10),
          _Field(dark: dark, controller: _acr, label: 'ACR mg/g'),
          const SizedBox(height: 10),
          _Sex(
              dark: dark,
              isEs: _isEs,
              female: _female,
              onChanged: (v) => setState(() => _female = v)),
          const SizedBox(height: 10),
          _Choice(
            dark: dark,
            label: _isEs ? 'Calibración' : 'Calibração',
            value: _kfreCalibration == KfreCalibration.northAmerica ? 0 : 1,
            options: const {0: 'North America', 1: 'Non-North America'},
            onChanged: (v) => setState(() {
              _kfreCalibration = v == 0
                  ? KfreCalibration.northAmerica
                  : KfreCalibration.nonNorthAmerica;
            }),
          ),
        ]);
      case NephroScoreId.kdigoAki:
        return Column(children: [
          Row(children: [
            Expanded(
                child: _Field(
                    dark: dark,
                    controller: _baselineCr,
                    label: _isEs ? 'Cr basal' : 'Cr basal')),
            const SizedBox(width: 8),
            Expanded(
                child: _Field(
                    dark: dark,
                    controller: _currentCr,
                    label: _isEs ? 'Cr actual' : 'Cr atual')),
          ]),
          const SizedBox(height: 8),
          _Toggle(
              dark: dark,
              label: _isEs
                  ? 'Aumento ≥0,3 mg/dL en 48 h'
                  : 'Aumento ≥0,3 mg/dL em 48 h',
              value: _rise03,
              onChanged: (v) => setState(() => _rise03 = v)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: _Field(
                    dark: dark,
                    controller: _urineRate,
                    label: 'Diurese mL/kg/h')),
            const SizedBox(width: 8),
            Expanded(
                child: _Field(
                    dark: dark,
                    controller: _urineHours,
                    label: _isEs ? 'Duración h' : 'Duração h')),
          ]),
          const SizedBox(height: 10),
          _Field(
              dark: dark,
              controller: _anuriaHours,
              label: _isEs
                  ? 'Anuria — horas (opcional)'
                  : 'Anúria — horas (opcional)'),
          const SizedBox(height: 8),
          _Toggle(
              dark: dark,
              label: _isEs
                  ? 'Terapia de reemplazo renal iniciada'
                  : 'Terapia renal substitutiva iniciada',
              value: _krt,
              onChanged: (v) => setState(() => _krt = v)),
        ]);
      case NephroScoreId.fena:
        return _fractionInputs(dark, urea: false);
      case NephroScoreId.feUrea:
        return _fractionInputs(dark, urea: true);
    }
  }

  Widget _fractionInputs(bool dark, {required bool urea}) {
    return Column(children: [
      Row(children: [
        Expanded(
            child: _Field(
                dark: dark,
                controller: urea ? _uUrea : _uNa,
                label: urea ? 'Ureia urinária' : 'Na urinário')),
        const SizedBox(width: 8),
        Expanded(
            child: _Field(
                dark: dark,
                controller: urea ? _pUrea : _pNa,
                label: urea ? 'Ureia plasmática' : 'Na plasmático')),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
            child: _Field(dark: dark, controller: _uCr, label: 'Cr urinária')),
        const SizedBox(width: 8),
        Expanded(
            child:
                _Field(dark: dark, controller: _pCr, label: 'Cr plasmática')),
      ]),
    ]);
  }
}

class _Topbar extends StatelessWidget {
  final bool dark;
  final String title;

  const _Topbar({
    required this.dark,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final text = dark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    final border = dark ? _darkBorder : _lightBorder;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: border, width: 0.7),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 40,
              height: 40,
              child: IconButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(context).maybePop(),
                icon: Icon(
                  Icons.chevron_left_rounded,
                  size: 30,
                  color: text,
                ),
              ),
            ),
          ),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: text,
              fontSize: 16,
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportButton extends StatelessWidget {
  final bool dark, isEs;
  final VoidCallback onTap;
  const _ImportButton(
      {required this.dark, required this.isEs, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final surface = dark ? _darkSurface : Colors.white;
    final border = dark ? _darkBorder : _lightBorder;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('nephro_import_patient'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border, width: 0.7),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.person_add_alt_1_outlined,
                size: 17, color: _green),
            const SizedBox(width: 8),
            Text(
              isEs
                  ? 'Importar datos del paciente'
                  : 'Importar dados do paciente',
              style: const TextStyle(
                  color: _green, fontSize: 11.5, fontWeight: FontWeight.w800),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final bool dark;
  final TextEditingController controller;
  final String label;
  const _Field(
      {required this.dark, required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    final text = dark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    final sub = dark ? const Color(0xFFAEB9CC) : const Color(0xFF64748B);
    final border = dark ? _darkBorder : _lightBorder;
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: sub, fontSize: 11.5),
        filled: true,
        fillColor: dark ? _darkField : Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: border, width: 0.7),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _green, width: 1),
        ),
      ),
    );
  }
}

class _Sex extends StatelessWidget {
  final bool dark, isEs, female;
  final ValueChanged<bool> onChanged;
  const _Sex({
    required this.dark,
    required this.isEs,
    required this.female,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final border = dark ? _darkBorder : _lightBorder;
    final text = dark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    final muted = dark ? const Color(0xFFAEB9CC) : const Color(0xFF64748B);

    Widget option(bool selected, String label, VoidCallback tap) => Expanded(
          child: InkWell(
            onTap: tap,
            borderRadius: BorderRadius.circular(9),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? _green.withValues(alpha: dark ? 0.20 : 0.09)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: selected ? _green : Colors.transparent,
                  width: 0.8,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? (dark ? text : _green) : muted,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: dark ? _darkField : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border, width: 0.7),
      ),
      child: Row(children: [
        option(!female, 'Masculino', () => onChanged(false)),
        option(female, isEs ? 'Femenino' : 'Feminino', () => onChanged(true)),
      ]),
    );
  }
}

class _Choice extends StatelessWidget {
  final bool dark;
  final String label;
  final int value;
  final Map<int, String> options;
  final ValueChanged<int> onChanged;
  const _Choice({
    required this.dark,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final text = dark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    final border = dark ? _darkBorder : _lightBorder;
    return DropdownButtonFormField<int>(
      initialValue: value,
      dropdownColor: dark ? _darkField : Colors.white,
      style: TextStyle(color: text, fontSize: 13, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: dark ? _darkField : Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: border, width: 0.7),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _green, width: 1),
        ),
      ),
      items: options.entries
          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
          .toList(growable: false),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class _Toggle extends StatelessWidget {
  final bool dark, value;
  final String label;
  final ValueChanged<bool> onChanged;
  const _Toggle({
    required this.dark,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final text = dark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    final border = dark ? _darkBorder : _lightBorder;
    return Container(
      constraints: const BoxConstraints(minHeight: 50),
      padding: const EdgeInsets.fromLTRB(13, 4, 8, 4),
      decoration: BoxDecoration(
        color: dark ? _darkField : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border, width: 0.7),
      ),
      child: Row(children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
                color: text, fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: _green,
          activeTrackColor: _green.withValues(alpha: 0.30),
        ),
      ]),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ActionButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 50,
        child: FilledButton(
          key: const Key('nephro_calculate'),
          style: FilledButton.styleFrom(
            backgroundColor: _green,
            foregroundColor: Colors.white,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: onTap,
          child: Text(label,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
        ),
      );
}

class _Result extends StatelessWidget {
  final bool dark;
  final String value, band, interpretation;
  const _Result({
    required this.dark,
    required this.value,
    required this.band,
    required this.interpretation,
  });

  @override
  Widget build(BuildContext context) {
    final text = dark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    final sub = dark ? const Color(0xFFAEB9CC) : const Color(0xFF64748B);
    final border = dark ? _darkBorder : _lightBorder;
    return Container(
      key: const Key('nephro_result'),
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: dark ? _darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 0.7),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('RESULTADO',
            style: TextStyle(
                color: _green,
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 1)),
        const SizedBox(height: 6),
        Text(value,
            style: TextStyle(
                color: text, fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(band,
            style: TextStyle(
                color: text, fontSize: 12.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Text(interpretation,
            style: TextStyle(color: sub, fontSize: 11.5, height: 1.4)),
      ]),
    );
  }
}

class _Explanation extends StatelessWidget {
  final bool dark, isEs;
  final String limitations, reference;
  const _Explanation({
    required this.dark,
    required this.isEs,
    required this.limitations,
    required this.reference,
  });

  @override
  Widget build(BuildContext context) {
    final title = dark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    final sub = dark ? const Color(0xFFAEB9CC) : const Color(0xFF64748B);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(isEs ? 'USO Y LIMITACIONES' : 'USO E LIMITAÇÕES',
          style: TextStyle(
              color: title,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8)),
      const SizedBox(height: 7),
      Text(limitations,
          style: TextStyle(color: sub, fontSize: 11, height: 1.45)),
      const SizedBox(height: 13),
      Text(isEs ? 'REFERENCIA' : 'REFERÊNCIA',
          style: TextStyle(
              color: title,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8)),
      const SizedBox(height: 5),
      Text(reference,
          style: TextStyle(color: sub, fontSize: 10.5, height: 1.4)),
    ]);
  }
}

class _CalculatorButton extends StatelessWidget {
  final bool dark, isEs;
  final VoidCallback onTap;
  const _CalculatorButton({
    required this.dark,
    required this.isEs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final border = dark ? _darkBorder : _lightBorder;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('nephro_open_calculator'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: dark ? _darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border, width: 0.7),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.open_in_new_rounded, color: _green, size: 17),
            const SizedBox(width: 7),
            Text(
              isEs ? 'Abrir en Calculadora' : 'Abrir na Calculadora',
              style: const TextStyle(
                  color: _green, fontSize: 11.5, fontWeight: FontWeight.w800),
            ),
          ]),
        ),
      ),
    );
  }
}
