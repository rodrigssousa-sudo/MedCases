import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../providers/tools_state_provider.dart';
import '../services/cardio/cardio_acute_risk_engine_2026.dart';
import '../services/cardio/cardio_chronic_score_engine_2026.dart';
import 'calculadora_screen.dart';

const _mcGreen = Color(0xFF009C3B);
const _darkPage = Color(0xFF171B21);
const _darkSurface = Color(0xFF20252D);
const _darkField = Color(0xFF222A35);
const _darkBorder = Color(0xFF374151);
const _lightPage = Color(0xFFECF0F4);
const _lightSurface = Colors.white;
const _lightBorder = Color(0xFFE2E7EC);

enum CardioScoreId {
  heart,
  timiUaNstemi,
  grace,
  killip,
  cha2Ds2Va,
  cha2Ds2Vasc,
  hasBled,
  qtcBazett,
  qtcFridericia,
  prevent,
}

class CardioScoreDetailScreen extends StatefulWidget {
  final CardioScoreId scoreId;

  const CardioScoreDetailScreen({
    super.key,
    required this.scoreId,
  });

  @override
  State<CardioScoreDetailScreen> createState() =>
      _CardioScoreDetailScreenState();
}

class _CardioScoreDetailScreenState extends State<CardioScoreDetailScreen> {
  final _ageCtrl = TextEditingController(text: '50');
  final _sbpCtrl = TextEditingController(text: '120');
  final _hrCtrl = TextEditingController(text: '75');
  final _qtCtrl = TextEditingController(text: '400');
  final _creatinineCtrl = TextEditingController(text: '1.0');
  final _riskCountCtrl = TextEditingController(text: '0');

  bool _female = false;

  bool _heartFailure = false;
  bool _hypertension = false;
  bool _diabetes = false;
  bool _strokeTia = false;
  bool _vascularDisease = false;

  bool _renalAbnormal = false;
  bool _liverAbnormal = false;
  bool _bleedHistory = false;
  bool _labileInr = false;
  bool _bleedingDrugs = false;
  bool _alcohol = false;

  int _heartHistory = 0;
  int _heartEcg = 0;
  int _heartTroponin = 0;
  bool _knownAtherosclerosis = false;

  bool _timiAge65 = false;
  bool _timiThreeRiskFactors = false;
  bool _timiKnownCad = false;
  bool _timiAspirin = false;
  bool _timiAngina = false;
  bool _timiStDeviation = false;
  bool _timiMarkers = false;

  int _graceKillip = 1;
  bool _graceArrest = false;
  bool _graceStDeviation = false;
  bool _graceMarkers = false;

  int _killip = 1;

  String? _resultValue;
  String? _resultBand;
  String? _resultInterpretation;
  Map<String, String> _resultPayload = const {};

  @override
  void dispose() {
    _ageCtrl.dispose();
    _sbpCtrl.dispose();
    _hrCtrl.dispose();
    _qtCtrl.dispose();
    _creatinineCtrl.dispose();
    _riskCountCtrl.dispose();
    super.dispose();
  }

  bool get _isEs => context.read<AppProvider>().lang == 'es';

  String get _scoreName {
    return switch (widget.scoreId) {
      CardioScoreId.heart => 'HEART',
      CardioScoreId.timiUaNstemi => 'TIMI UA/NSTEMI',
      CardioScoreId.grace => 'GRACE',
      CardioScoreId.killip => 'Killip',
      CardioScoreId.cha2Ds2Va => 'CHA₂DS₂-VA',
      CardioScoreId.cha2Ds2Vasc => 'CHA₂DS₂-VASc',
      CardioScoreId.hasBled => 'HAS-BLED',
      CardioScoreId.qtcBazett => 'QTc Bazett',
      CardioScoreId.qtcFridericia => 'QTc Fridericia',
      CardioScoreId.prevent => 'PREVENT-ASCVD',
    };
  }

  String get _eyebrow {
    return switch (widget.scoreId) {
      CardioScoreId.heart => _isEs
          ? 'DOLOR TORÁCICO · ESTRATIFICACIÓN INICIAL'
          : 'DOR TORÁCICA · ESTRATIFICAÇÃO INICIAL',
      CardioScoreId.timiUaNstemi => 'SCA · UA/NSTEMI',
      CardioScoreId.grace => _isEs
          ? 'SCA · PRONÓSTICO EN ADMISIÓN'
          : 'SCA · PROGNÓSTICO NA ADMISSÃO',
      CardioScoreId.killip =>
        _isEs ? 'IAM · CLASIFICACIÓN CLÍNICA' : 'IAM · CLASSIFICAÇÃO CLÍNICA',
      CardioScoreId.cha2Ds2Va ||
      CardioScoreId.cha2Ds2Vasc =>
        _isEs ? 'FA · RIESGO TROMBOEMBÓLICO' : 'FA · RISCO TROMBOEMBÓLICO',
      CardioScoreId.hasBled =>
        _isEs ? 'FA · RIESGO HEMORRÁGICO' : 'FA · RISCO HEMORRÁGICO',
      CardioScoreId.qtcBazett ||
      CardioScoreId.qtcFridericia =>
        _isEs ? 'ECG · REPOLARIZACIÓN' : 'ECG · REPOLARIZAÇÃO',
      CardioScoreId.prevent => _isEs
          ? 'PREVENCIÓN PRIMARIA · RIESGO CV'
          : 'PREVENÇÃO PRIMÁRIA · RISCO CV',
    };
  }

  String get _shortExplanation {
    return switch (widget.scoreId) {
      CardioScoreId.heart => _isEs
          ? 'Integra historia, ECG, edad, factores de riesgo y troponina. Debe usarse dentro de una vía estructurada con hs-cTn.'
          : 'Integra história, ECG, idade, fatores de risco e troponina. Deve ser usado dentro de uma via estruturada com hs-cTn.',
      CardioScoreId.timiUaNstemi => _isEs
          ? 'Estratifica riesgo isquémico en UA/NSTEMI mediante siete criterios clínicos.'
          : 'Estratifica risco isquêmico em UA/NSTEMI por sete critérios clínicos.',
      CardioScoreId.grace => _isEs
          ? 'Score original de puntos de admisión. GRACE >140 sigue siendo una característica de alto riesgo en ESC ACS.'
          : 'Score original de pontos na admissão. GRACE >140 segue como característica de alto risco na ESC ACS.',
      CardioScoreId.killip => _isEs
          ? 'Clasificación pronóstica clínica de insuficiencia cardíaca en el contexto de infarto agudo.'
          : 'Classificação prognóstica clínica de insuficiência cardíaca no contexto de infarto agudo.',
      CardioScoreId.cha2Ds2Va => _isEs
          ? 'Herramienta ESC 2024 para estimar riesgo tromboembólico en fibrilación auricular sin usar sexo como punto.'
          : 'Ferramenta ESC 2024 para estimar risco tromboembólico na fibrilação atrial sem usar sexo como ponto.',
      CardioScoreId.cha2Ds2Vasc => _isEs
          ? 'Score histórico de riesgo tromboembólico en FA, mantenido en paralelo para interoperabilidad.'
          : 'Score histórico de risco tromboembólico na FA, mantido em paralelo para interoperabilidade.',
      CardioScoreId.hasBled => _isEs
          ? 'Identifica factores de sangrado modificables y necesidad de seguimiento. No debe usarse para negar anticoagulación por sí solo.'
          : 'Identifica fatores de sangramento modificáveis e necessidade de seguimento. Não deve ser usado sozinho para negar anticoagulação.',
      CardioScoreId.qtcBazett => _isEs
          ? 'Corrige QT por frecuencia cardíaca con Bazett. Puede sobrecorregir con FC alta y subcorregir con FC baja.'
          : 'Corrige QT pela frequência cardíaca com Bazett. Pode supercorrigir em FC alta e subcorrigir em FC baixa.',
      CardioScoreId.qtcFridericia => _isEs
          ? 'Corrige QT por frecuencia cardíaca con Fridericia, menos dependiente de la FC que Bazett en muchos escenarios.'
          : 'Corrige QT pela frequência cardíaca com Fridericia, menos dependente da FC que Bazett em muitos cenários.',
      CardioScoreId.prevent => _isEs
          ? 'PREVENT-ASCVD requiere el conjunto oficial de variables y la ecuación validada. MedCases no muestra una estimación aproximada.'
          : 'PREVENT-ASCVD exige o conjunto oficial de variáveis e a equação validada. O MedCases não mostra estimativa aproximada.',
    };
  }

  String get _limitations {
    return switch (widget.scoreId) {
      CardioScoreId.heart => _isEs
          ? 'No sustituye ECG seriado, hs-cTn seriada, diagnóstico clínico ni una vía local validada.'
          : 'Não substitui ECG seriado, hs-cTn seriada, diagnóstico clínico nem uma via local validada.',
      CardioScoreId.timiUaNstemi => _isEs
          ? 'Es específico de UA/NSTEMI; no debe extrapolarse a otras poblaciones.'
          : 'É específico de UA/NSTEMI; não deve ser extrapolado para outras populações.',
      CardioScoreId.grace => _isEs
          ? 'Este es el modelo original por puntos; no equivale a probabilidades GRACE 2.0.'
          : 'Este é o modelo original por pontos; não equivale às probabilidades do GRACE 2.0.',
      CardioScoreId.killip => _isEs
          ? 'Es una clasificación clínica pronóstica, no una herramienta diagnóstica aislada.'
          : 'É uma classificação clínica prognóstica, não uma ferramenta diagnóstica isolada.',
      CardioScoreId.cha2Ds2Va => _isEs
          ? 'Aplicar en FA y reevaluar el riesgo de forma dinámica; integrar contexto clínico y contraindicaciones.'
          : 'Aplicar em FA e reavaliar o risco dinamicamente; integrar contexto clínico e contraindicações.',
      CardioScoreId.cha2Ds2Vasc => _isEs
          ? 'ESC 2024 prioriza CHA₂DS₂-VA; VASc se mantiene aquí como referencia/interoperabilidad.'
          : 'ESC 2024 prioriza CHA₂DS₂-VA; VASc permanece aqui como referência/interoperabilidade.',
      CardioScoreId.hasBled => _isEs
          ? 'Una puntuación alta obliga a corregir factores modificables y aumentar vigilancia; no implica suspender OAC automáticamente.'
          : 'Pontuação alta exige corrigir fatores modificáveis e aumentar vigilância; não implica suspender OAC automaticamente.',
      CardioScoreId.qtcBazett || CardioScoreId.qtcFridericia => _isEs
          ? 'QRS ancho requiere ajuste específico. Interpretar junto con ECG, fármacos, electrolitos y contexto clínico.'
          : 'QRS largo exige ajuste específico. Interpretar junto com ECG, fármacos, eletrólitos e contexto clínico.',
      CardioScoreId.prevent => _isEs
          ? 'No se calcula hasta disponer del motor oficial validado y todas las variables requeridas.'
          : 'Não é calculado até existir motor oficial validado e todas as variáveis requeridas.',
    };
  }

  String get _reference {
    return switch (widget.scoreId) {
      CardioScoreId.heart =>
        'AHA/ACC Chest Pain 2021 · ACC ED Chest Pain ECDP 2022',
      CardioScoreId.timiUaNstemi => 'ACC/AHA/ACEP/NAEMSP/SCAI ACS 2025',
      CardioScoreId.grace =>
        'ESC Acute Coronary Syndromes 2023 · GRACE original admission score',
      CardioScoreId.killip =>
        'ACC/AHA/ACEP/NAEMSP/SCAI ACS 2025 · prognostic classification context',
      CardioScoreId.cha2Ds2Va => 'ESC Atrial Fibrillation 2024',
      CardioScoreId.cha2Ds2Vasc =>
        'ACC/AHA/ACCP/HRS Atrial Fibrillation 2023 · interoperability',
      CardioScoreId.hasBled =>
        'ESC Atrial Fibrillation 2024 · HAS-BLED original construct',
      CardioScoreId.qtcBazett ||
      CardioScoreId.qtcFridericia =>
        'AHA/ACCF/HRS ECG standardization · ESC long-QT context',
      CardioScoreId.prevent =>
        'AHA PREVENT · ACC/AHA Dyslipidemia Guideline 2026',
    };
  }

  void _importPatient() {
    final tools = context.read<ToolsStateProvider>();

    setState(() {
      final age = tools.ageCtrl.text.trim();
      final sbp = tools.pasCtrl.text.trim();
      final hr = tools.fcCtrl.text.trim();

      if (age.isNotEmpty) _ageCtrl.text = age;
      if (sbp.isNotEmpty) _sbpCtrl.text = sbp;
      if (hr.isNotEmpty) _hrCtrl.text = hr;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isEs
              ? 'Datos disponibles del paciente importados.'
              : 'Dados disponíveis do paciente importados.',
        ),
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }

  int _int(TextEditingController ctrl, {required int fallback}) {
    return int.tryParse(ctrl.text.trim()) ?? fallback;
  }

  double _double(TextEditingController ctrl, {required double fallback}) {
    return double.tryParse(ctrl.text.trim().replaceAll(',', '.')) ?? fallback;
  }

  void _setResult({
    required String value,
    required String band,
    required String interpretation,
    required Map<String, String> payload,
  }) {
    setState(() {
      _resultValue = value;
      _resultBand = band;
      _resultInterpretation = interpretation;
      _resultPayload = payload;
    });
  }

  void _calculate() {
    try {
      switch (widget.scoreId) {
        case CardioScoreId.heart:
          final result = CardioAcuteRiskEngine2026.heart(
            HeartScoreInput(
              historyPoints: _heartHistory,
              ecgPoints: _heartEcg,
              ageYears: _int(_ageCtrl, fallback: 50),
              riskFactorCount: _int(_riskCountCtrl, fallback: 0),
              knownAtheroscleroticDisease: _knownAtherosclerosis,
              troponinPoints: _heartTroponin,
            ),
          );
          _setResult(
            value: '${result.score} / 10',
            band: _isEs ? result.bandEs : result.bandPt,
            interpretation: _isEs
                ? 'Integrar con vía de dolor torácico y hs-cTn; no usar el número de forma aislada.'
                : 'Integrar com via de dor torácica e hs-cTn; não usar o número isoladamente.',
            payload: {
              'score': 'heart',
              'heartScore': '${result.score}',
            },
          );

        case CardioScoreId.timiUaNstemi:
          final result = CardioAcuteRiskEngine2026.timiUaNstemi(
            TimiUaNstemiInput(
              age65OrMore: _timiAge65,
              threeOrMoreCadRiskFactors: _timiThreeRiskFactors,
              knownCadStenosis50OrMore: _timiKnownCad,
              aspirinWithin7Days: _timiAspirin,
              twoOrMoreAnginaEpisodes24h: _timiAngina,
              stDeviation: _timiStDeviation,
              elevatedCardiacMarkers: _timiMarkers,
            ),
          );
          _setResult(
            value: '${result.score} / 7',
            band: _isEs ? result.bandEs : result.bandPt,
            interpretation: _isEs
                ? 'Mayor puntuación identifica mayor carga de factores de riesgo isquémico dentro del contexto UA/NSTEMI.'
                : 'Maior pontuação identifica maior carga de fatores de risco isquêmico no contexto UA/NSTEMI.',
            payload: {
              'score': 'timi_nstemi',
              'timiScore': '${result.score}',
            },
          );

        case CardioScoreId.grace:
          final result = CardioAcuteRiskEngine2026.graceAdmission(
            GraceAdmissionInput(
              ageYears: _int(_ageCtrl, fallback: 50),
              heartRateBpm: _int(_hrCtrl, fallback: 75),
              systolicBpMmHg: _int(_sbpCtrl, fallback: 120),
              creatinineMgDl: _double(_creatinineCtrl, fallback: 1.0),
              killipClass: _graceKillip,
              cardiacArrestAtAdmission: _graceArrest,
              stSegmentDeviation: _graceStDeviation,
              elevatedCardiacMarkers: _graceMarkers,
            ),
          );
          _setResult(
            value: '${result.points}',
            band: result.escHighRiskAbove140
                ? (_isEs ? '>140 · alto riesgo ESC' : '>140 · alto risco ESC')
                : (_isEs ? result.bandEs : result.bandPt),
            interpretation: _isEs
                ? 'Es el score original de puntos de admisión. No convertir este total en probabilidades GRACE 2.0.'
                : 'É o score original de pontos na admissão. Não converter este total em probabilidades GRACE 2.0.',
            payload: {
              'score': 'grace',
              'gracePoints': '${result.points}',
              'graceEscHighRisk': result.escHighRiskAbove140 ? '1' : '0',
            },
          );

        case CardioScoreId.killip:
          final result = CardioAcuteRiskEngine2026.killip(_killip);
          _setResult(
            value: _isEs ? result.labelEs : result.labelPt,
            band: _isEs ? result.meaningEs : result.meaningPt,
            interpretation: _isEs
                ? 'Clasificación pronóstica clínica en IAM.'
                : 'Classificação prognóstica clínica no IAM.',
            payload: {
              'score': 'killip',
              'killipClass': '${result.killipClass}',
            },
          );

        case CardioScoreId.cha2Ds2Va:
          final result = CardioChronicScoreEngine2026.cha2Ds2Va(
            ageYears: _int(_ageCtrl, fallback: 50),
            heartFailure: _heartFailure,
            hypertension: _hypertension,
            diabetes: _diabetes,
            priorStrokeTiaTe: _strokeTia,
            vascularDisease: _vascularDisease,
          );
          _setResult(
            value: '${result.score} / 8',
            band: _isEs ? result.bandEs : result.bandPt,
            interpretation: _isEs
                ? 'ESC 2024: 1 punto favorece considerar OAC; ≥2 favorece OAC si no hay contraindicación, integrado al contexto clínico.'
                : 'ESC 2024: 1 ponto favorece considerar OAC; ≥2 favorece OAC se não houver contraindicação, integrado ao contexto clínico.',
            payload: {
              'score': 'cha2ds2_va',
              'cha2ds2Va': '${result.score}',
            },
          );

        case CardioScoreId.cha2Ds2Vasc:
          final result = CardioChronicScoreEngine2026.cha2Ds2Vasc(
            ageYears: _int(_ageCtrl, fallback: 50),
            femaleSex: _female,
            heartFailure: _heartFailure,
            hypertension: _hypertension,
            diabetes: _diabetes,
            priorStrokeTiaTe: _strokeTia,
            vascularDisease: _vascularDisease,
          );
          _setResult(
            value: '${result.score} / 9',
            band: _isEs ? result.bandEs : result.bandPt,
            interpretation: _isEs
                ? 'Mantener como referencia/interoperabilidad; ESC 2024 prioriza CHA₂DS₂-VA.'
                : 'Manter como referência/interoperabilidade; ESC 2024 prioriza CHA₂DS₂-VA.',
            payload: {
              'score': 'cha2ds2_vasc',
              'cha2ds2Vasc': '${result.score}',
            },
          );

        case CardioScoreId.hasBled:
          final result = CardioChronicScoreEngine2026.hasBled(
            ageYears: _int(_ageCtrl, fallback: 50),
            systolicBpMmHg: _double(_sbpCtrl, fallback: 120),
            abnormalRenalFunction: _renalAbnormal,
            abnormalLiverFunction: _liverAbnormal,
            priorStroke: _strokeTia,
            bleedingHistoryOrPredisposition: _bleedHistory,
            labileInr: _labileInr,
            bleedingRiskDrugs: _bleedingDrugs,
            highAlcoholUse: _alcohol,
          );
          _setResult(
            value: '${result.score} / 9',
            band: _isEs ? result.bandEs : result.bandPt,
            interpretation: _isEs
                ? 'Corregir factores modificables y aumentar seguimiento. No usar el score para negar o retirar OAC de forma automática.'
                : 'Corrigir fatores modificáveis e aumentar seguimento. Não usar o score para negar ou retirar OAC automaticamente.',
            payload: {
              'score': 'has_bled',
              'hasBled': '${result.score}',
            },
          );

        case CardioScoreId.qtcBazett:
          final result = CardioChronicScoreEngine2026.bazett(
            qtMs: _double(_qtCtrl, fallback: 400),
            heartRateBpm: _double(_hrCtrl, fallback: 75),
            femaleSex: _female,
          );
          _setResult(
            value: '${result.milliseconds.round()} ms',
            band: _isEs ? result.bandEs : result.bandPt,
            interpretation: _isEs
                ? 'Bazett es sensible a la frecuencia cardíaca; interpretar con ECG y contexto clínico.'
                : 'Bazett é sensível à frequência cardíaca; interpretar com ECG e contexto clínico.',
            payload: {
              'score': 'qtc_bazett',
              'qtcBazettMs': '${result.milliseconds.round()}',
            },
          );

        case CardioScoreId.qtcFridericia:
          final result = CardioChronicScoreEngine2026.fridericia(
            qtMs: _double(_qtCtrl, fallback: 400),
            heartRateBpm: _double(_hrCtrl, fallback: 75),
            femaleSex: _female,
          );
          _setResult(
            value: '${result.milliseconds.round()} ms',
            band: _isEs ? result.bandEs : result.bandPt,
            interpretation: _isEs
                ? 'Fridericia suele ser menos dependiente de la FC que Bazett, pero sigue requiriendo interpretación clínica.'
                : 'Fridericia costuma ser menos dependente da FC que Bazett, mas ainda exige interpretação clínica.',
            payload: {
              'score': 'qtc_fridericia',
              'qtcFridericiaMs': '${result.milliseconds.round()}',
            },
          );

        case CardioScoreId.prevent:
          _setResult(
            value: _isEs ? 'No calculado' : 'Não calculado',
            band:
                _isEs ? 'Motor oficial requerido' : 'Motor oficial necessário',
            interpretation: _isEs
                ? 'MedCases no fabrica una estimación PREVENT incompleta.'
                : 'O MedCases não fabrica uma estimativa PREVENT incompleta.',
            payload: const {
              'score': 'prevent_ascvd',
              'preventNativeValidated': '0',
            },
          );
      }
    } on Object catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEs
                ? 'Revise los datos ingresados.'
                : 'Revise os dados informados.',
          ),
        ),
      );
    }
  }

  void _openCalculator() {
    final tools = context.read<ToolsStateProvider>();
    final lang = _isEs ? 'es' : 'pt';
    final baseQuery = tools.buildQueryStringForSpecialty('cardio', lang);
    final basePayload =
        baseQuery.startsWith('?') ? baseQuery.substring(1) : baseQuery;

    final scorePayload = _resultPayload.entries
        .map(
          (entry) => '${Uri.encodeQueryComponent(entry.key)}='
              '${Uri.encodeQueryComponent(entry.value)}',
        )
        .join('&');

    final parts = <String>[
      if (basePayload.isNotEmpty) basePayload,
      if (scorePayload.isNotEmpty) scorePayload,
    ];

    final url =
        'https://medcasescalcu.com/?modulo=cardiologia&${parts.join('&')}';

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CalculadoraScreen(initialUrl: url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final isEs = app.lang == 'es';
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
            _ScoreTopbar(
              dark: dark,
              title: isEs ? 'CARDIOLOGÍA' : 'CARDIOLOGIA',
            ),
            const SizedBox(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 7, 16, 0),
              child: _ImportPatientButton(
                dark: dark,
                isEs: isEs,
                onTap: _importPatient,
              ),
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
                        color: _mcGreen,
                        fontSize: 9.5,
                        height: 1.2,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.9,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _scoreName,
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
                      _shortExplanation,
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
                    _buildInputs(dark, isEs),
                    const SizedBox(height: 18),
                    _CalculateButton(
                      dark: dark,
                      label: widget.scoreId == CardioScoreId.prevent
                          ? (isEs ? 'VER ESTADO PREVENT' : 'VER STATUS PREVENT')
                          : (isEs
                              ? 'CALCULAR ${_scoreName.toUpperCase()}'
                              : 'CALCULAR ${_scoreName.toUpperCase()}'),
                      onTap: _calculate,
                    ),
                    if (_resultValue != null) ...[
                      const SizedBox(height: 22),
                      _ResultSection(
                        dark: dark,
                        isEs: isEs,
                        scoreName: _scoreName,
                        value: _resultValue!,
                        band: _resultBand ?? '',
                        interpretation: _resultInterpretation ?? '',
                      ),
                      const SizedBox(height: 18),
                      _ExplanationSection(
                        dark: dark,
                        isEs: isEs,
                        limitations: _limitations,
                        reference: _reference,
                      ),
                      const SizedBox(height: 16),
                      _CalculatorLinkButton(
                        dark: dark,
                        isEs: isEs,
                        onTap: _openCalculator,
                      ),
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

  Widget _buildInputs(bool dark, bool isEs) {
    return switch (widget.scoreId) {
      CardioScoreId.heart => _heartInputs(dark, isEs),
      CardioScoreId.timiUaNstemi => _timiInputs(dark, isEs),
      CardioScoreId.grace => _graceInputs(dark, isEs),
      CardioScoreId.killip => _killipInputs(dark, isEs),
      CardioScoreId.cha2Ds2Va => _chaInputs(dark, isEs, includeSex: false),
      CardioScoreId.cha2Ds2Vasc => _chaInputs(dark, isEs, includeSex: true),
      CardioScoreId.hasBled => _hasBledInputs(dark, isEs),
      CardioScoreId.qtcBazett ||
      CardioScoreId.qtcFridericia =>
        _qtcInputs(dark, isEs),
      CardioScoreId.prevent => _preventInputs(dark, isEs),
    };
  }

  Widget _heartInputs(bool dark, bool isEs) {
    return Column(
      children: [
        _NumberField(
          dark: dark,
          controller: _ageCtrl,
          label: isEs ? 'Edad (años)' : 'Idade (anos)',
        ),
        const SizedBox(height: 10),
        _ScoreDropdown(
          dark: dark,
          label: isEs ? 'Historia' : 'História',
          value: _heartHistory,
          options: const {
            0: '0 — poco sospechosa',
            1: '1 — moderadamente sospechosa',
            2: '2 — muy sospechosa',
          },
          onChanged: (value) => setState(() => _heartHistory = value),
        ),
        const SizedBox(height: 10),
        _ScoreDropdown(
          dark: dark,
          label: 'ECG',
          value: _heartEcg,
          options: const {
            0: '0 — normal',
            1: '1 — alteración inespecífica',
            2: '2 — depresión ST significativa',
          },
          onChanged: (value) => setState(() => _heartEcg = value),
        ),
        const SizedBox(height: 10),
        _NumberField(
          dark: dark,
          controller: _riskCountCtrl,
          label: isEs ? 'Nº factores de riesgo' : 'Nº fatores de risco',
        ),
        const SizedBox(height: 8),
        _ToggleLine(
          dark: dark,
          label: isEs ? 'Aterosclerosis conocida' : 'Aterosclerose conhecida',
          value: _knownAtherosclerosis,
          onChanged: (value) => setState(() => _knownAtherosclerosis = value),
        ),
        const SizedBox(height: 10),
        _ScoreDropdown(
          dark: dark,
          label: 'Troponina vs LSN/ULN',
          value: _heartTroponin,
          options: const {
            0: '0 — ≤ límite superior',
            1: '1 — >1–3× límite',
            2: '2 — >3× límite',
          },
          onChanged: (value) => setState(() => _heartTroponin = value),
        ),
      ],
    );
  }

  Widget _timiInputs(bool dark, bool isEs) {
    return _ToggleGroup(
      dark: dark,
      children: [
        _ToggleLine(
          dark: dark,
          label: isEs ? 'Edad ≥65 años' : 'Idade ≥65 anos',
          value: _timiAge65,
          onChanged: (v) => setState(() => _timiAge65 = v),
        ),
        _ToggleLine(
          dark: dark,
          label: isEs ? '≥3 factores de riesgo CAD' : '≥3 fatores de risco DAC',
          value: _timiThreeRiskFactors,
          onChanged: (v) => setState(() => _timiThreeRiskFactors = v),
        ),
        _ToggleLine(
          dark: dark,
          label: isEs ? 'CAD conocida ≥50%' : 'DAC conhecida ≥50%',
          value: _timiKnownCad,
          onChanged: (v) => setState(() => _timiKnownCad = v),
        ),
        _ToggleLine(
          dark: dark,
          label: isEs ? 'AAS en últimos 7 días' : 'AAS nos últimos 7 dias',
          value: _timiAspirin,
          onChanged: (v) => setState(() => _timiAspirin = v),
        ),
        _ToggleLine(
          dark: dark,
          label: isEs
              ? '≥2 episodios de angina/24 h'
              : '≥2 episódios de angina/24 h',
          value: _timiAngina,
          onChanged: (v) => setState(() => _timiAngina = v),
        ),
        _ToggleLine(
          dark: dark,
          label: isEs ? 'Desviación del ST' : 'Desvio de ST',
          value: _timiStDeviation,
          onChanged: (v) => setState(() => _timiStDeviation = v),
        ),
        _ToggleLine(
          dark: dark,
          label: isEs
              ? 'Marcadores cardíacos elevados'
              : 'Marcadores cardíacos elevados',
          value: _timiMarkers,
          onChanged: (v) => setState(() => _timiMarkers = v),
        ),
      ],
    );
  }

  Widget _graceInputs(bool dark, bool isEs) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _NumberField(
                dark: dark,
                controller: _ageCtrl,
                label: isEs ? 'Edad' : 'Idade',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _NumberField(
                dark: dark,
                controller: _hrCtrl,
                label: 'FC (bpm)',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _NumberField(
                dark: dark,
                controller: _sbpCtrl,
                label: 'PAS (mmHg)',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _NumberField(
                dark: dark,
                controller: _creatinineCtrl,
                label: isEs ? 'Creatinina mg/dL' : 'Creatinina mg/dL',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _ScoreDropdown(
          dark: dark,
          label: 'Killip',
          value: _graceKillip,
          options: const {
            1: 'I',
            2: 'II',
            3: 'III',
            4: 'IV',
          },
          onChanged: (v) => setState(() => _graceKillip = v),
        ),
        const SizedBox(height: 8),
        _ToggleLine(
          dark: dark,
          label:
              isEs ? 'Paro cardíaco al ingreso' : 'Parada cardíaca na admissão',
          value: _graceArrest,
          onChanged: (v) => setState(() => _graceArrest = v),
        ),
        _ToggleLine(
          dark: dark,
          label: isEs ? 'Desviación del ST' : 'Desvio de ST',
          value: _graceStDeviation,
          onChanged: (v) => setState(() => _graceStDeviation = v),
        ),
        _ToggleLine(
          dark: dark,
          label: isEs
              ? 'Marcadores cardíacos elevados'
              : 'Marcadores cardíacos elevados',
          value: _graceMarkers,
          onChanged: (v) => setState(() => _graceMarkers = v),
        ),
      ],
    );
  }

  Widget _killipInputs(bool dark, bool isEs) {
    return _ScoreDropdown(
      dark: dark,
      label: 'Killip',
      value: _killip,
      options: const {
        1: 'I — sin IC clínica',
        2: 'II — congestión / B3 / yugulares',
        3: 'III — edema agudo de pulmón',
        4: 'IV — shock cardiogénico',
      },
      onChanged: (v) => setState(() => _killip = v),
    );
  }

  Widget _chaInputs(
    bool dark,
    bool isEs, {
    required bool includeSex,
  }) {
    return Column(
      children: [
        _NumberField(
          dark: dark,
          controller: _ageCtrl,
          label: isEs ? 'Edad (años)' : 'Idade (anos)',
        ),
        if (includeSex) ...[
          const SizedBox(height: 10),
          _SexSelector(
            dark: dark,
            isEs: isEs,
            female: _female,
            onChanged: (v) => setState(() => _female = v),
          ),
        ],
        const SizedBox(height: 8),
        _ToggleLine(
          dark: dark,
          label: isEs ? 'Insuficiencia cardíaca' : 'Insuficiência cardíaca',
          value: _heartFailure,
          onChanged: (v) => setState(() => _heartFailure = v),
        ),
        _ToggleLine(
          dark: dark,
          label: 'HTA',
          value: _hypertension,
          onChanged: (v) => setState(() => _hypertension = v),
        ),
        _ToggleLine(
          dark: dark,
          label: 'Diabetes',
          value: _diabetes,
          onChanged: (v) => setState(() => _diabetes = v),
        ),
        _ToggleLine(
          dark: dark,
          label: isEs ? 'ACV/AIT/TE previo' : 'AVC/AIT/TE prévio',
          value: _strokeTia,
          onChanged: (v) => setState(() => _strokeTia = v),
        ),
        _ToggleLine(
          dark: dark,
          label: isEs ? 'Enfermedad vascular' : 'Doença vascular',
          value: _vascularDisease,
          onChanged: (v) => setState(() => _vascularDisease = v),
        ),
      ],
    );
  }

  Widget _hasBledInputs(bool dark, bool isEs) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _NumberField(
                dark: dark,
                controller: _ageCtrl,
                label: isEs ? 'Edad' : 'Idade',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _NumberField(
                dark: dark,
                controller: _sbpCtrl,
                label: 'PAS (mmHg)',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _ToggleLine(
          dark: dark,
          label: isEs ? 'Función renal anormal' : 'Função renal anormal',
          value: _renalAbnormal,
          onChanged: (v) => setState(() => _renalAbnormal = v),
        ),
        _ToggleLine(
          dark: dark,
          label: isEs ? 'Función hepática anormal' : 'Função hepática anormal',
          value: _liverAbnormal,
          onChanged: (v) => setState(() => _liverAbnormal = v),
        ),
        _ToggleLine(
          dark: dark,
          label: isEs ? 'ACV previo' : 'AVC prévio',
          value: _strokeTia,
          onChanged: (v) => setState(() => _strokeTia = v),
        ),
        _ToggleLine(
          dark: dark,
          label: isEs
              ? 'Sangrado previo/predisposición'
              : 'Sangramento prévio/predisposição',
          value: _bleedHistory,
          onChanged: (v) => setState(() => _bleedHistory = v),
        ),
        _ToggleLine(
          dark: dark,
          label: isEs ? 'INR lábil' : 'INR lábil',
          value: _labileInr,
          onChanged: (v) => setState(() => _labileInr = v),
        ),
        _ToggleLine(
          dark: dark,
          label: isEs ? 'Antiagregante/AINE' : 'Antiagregante/AINE',
          value: _bleedingDrugs,
          onChanged: (v) => setState(() => _bleedingDrugs = v),
        ),
        _ToggleLine(
          dark: dark,
          label: isEs ? 'Alcohol ≥8/sem' : 'Álcool ≥8/sem',
          value: _alcohol,
          onChanged: (v) => setState(() => _alcohol = v),
        ),
        const SizedBox(height: 8),
        _SubtleNote(
          dark: dark,
          text: isEs
              ? 'HAS-BLED suma automáticamente 1 punto por PAS >160 mmHg y 1 punto por edad >65 años.'
              : 'HAS-BLED soma automaticamente 1 ponto por PAS >160 mmHg e 1 ponto por idade >65 anos.',
        ),
      ],
    );
  }

  Widget _qtcInputs(bool dark, bool isEs) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _NumberField(
                dark: dark,
                controller: _qtCtrl,
                label: isEs ? 'QT medido (ms)' : 'QT medido (ms)',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _NumberField(
                dark: dark,
                controller: _hrCtrl,
                label: 'FC (bpm)',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _SexSelector(
          dark: dark,
          isEs: isEs,
          female: _female,
          onChanged: (v) => setState(() => _female = v),
        ),
      ],
    );
  }

  Widget _preventInputs(bool dark, bool isEs) {
    return _SubtleNote(
      dark: dark,
      text: isEs
          ? 'La implementación nativa requiere edad, sexo, PAS, colesterol total y HDL, eGFR, IMC, diabetes, tabaquismo y tratamientos relevantes; UACR/HbA1c/SDI son variables opcionales del modelo oficial.'
          : 'A implementação nativa exige idade, sexo, PAS, colesterol total e HDL, eGFR, IMC, diabetes, tabagismo e tratamentos relevantes; UACR/HbA1c/SDI são variáveis opcionais do modelo oficial.',
    );
  }
}

class _ScoreTopbar extends StatelessWidget {
  final bool dark;
  final String title;

  const _ScoreTopbar({
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

class _ImportPatientButton extends StatelessWidget {
  final bool dark;
  final bool isEs;
  final VoidCallback onTap;

  const _ImportPatientButton({
    required this.dark,
    required this.isEs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final border = dark ? _darkBorder : _lightBorder;
    final surface = dark ? _darkSurface : _lightSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('cardio_import_patient'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border, width: 0.7),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.person_add_alt_1_outlined,
                size: 17,
                color: _mcGreen,
              ),
              const SizedBox(width: 8),
              Text(
                isEs
                    ? 'Importar datos del paciente'
                    : 'Importar dados do paciente',
                style: const TextStyle(
                  color: _mcGreen,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final bool dark;
  final TextEditingController controller;
  final String label;

  const _NumberField({
    required this.dark,
    required this.controller,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final text = dark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    final sub = dark ? const Color(0xFFAEB9CC) : const Color(0xFF64748B);
    final border = dark ? _darkBorder : _lightBorder;
    final fill = dark ? _darkField : _lightSurface;

    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(
        color: text,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: sub, fontSize: 11.5),
        filled: true,
        fillColor: fill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 13,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: border, width: 0.7),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _mcGreen, width: 1),
        ),
      ),
    );
  }
}

class _ScoreDropdown extends StatelessWidget {
  final bool dark;
  final String label;
  final int value;
  final Map<int, String> options;
  final ValueChanged<int> onChanged;

  const _ScoreDropdown({
    required this.dark,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final text = dark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    final sub = dark ? const Color(0xFFAEB9CC) : const Color(0xFF64748B);
    final border = dark ? _darkBorder : _lightBorder;
    final fill = dark ? _darkField : _lightSurface;

    return DropdownButtonFormField<int>(
      initialValue: value,
      dropdownColor: fill,
      style: TextStyle(
        color: text,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: sub, fontSize: 11.5),
        filled: true,
        fillColor: fill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 11,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: border, width: 0.7),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _mcGreen, width: 1),
        ),
      ),
      items: options.entries
          .map(
            (entry) => DropdownMenuItem<int>(
              value: entry.key,
              child: Text(
                entry.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(growable: false),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class _ToggleGroup extends StatelessWidget {
  final bool dark;
  final List<Widget> children;

  const _ToggleGroup({
    required this.dark,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: children
          .expand(
            (child) => <Widget>[
              child,
              const SizedBox(height: 8),
            ],
          )
          .toList()
        ..removeLast(),
    );
  }
}

class _ToggleLine extends StatelessWidget {
  final bool dark;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleLine({
    required this.dark,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final text = dark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    final border = dark ? _darkBorder : _lightBorder;
    final surface = dark ? _darkField : _lightSurface;

    return Container(
      constraints: const BoxConstraints(minHeight: 50),
      padding: const EdgeInsets.fromLTRB(13, 4, 8, 4),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border, width: 0.7),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: text,
                fontSize: 12.5,
                height: 1.25,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: _mcGreen,
            activeTrackColor: _mcGreen.withValues(alpha: 0.30),
          ),
        ],
      ),
    );
  }
}

class _SexSelector extends StatelessWidget {
  final bool dark;
  final bool isEs;
  final bool female;
  final ValueChanged<bool> onChanged;

  const _SexSelector({
    required this.dark,
    required this.isEs,
    required this.female,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final border = dark ? _darkBorder : _lightBorder;
    final surface = dark ? _darkField : _lightSurface;
    final text = dark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    final muted = dark ? const Color(0xFFAEB9CC) : const Color(0xFF64748B);

    Widget option({
      required bool selected,
      required String label,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? _mcGreen.withValues(alpha: dark ? 0.20 : 0.09)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: selected ? _mcGreen : Colors.transparent,
                width: 0.8,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? (dark ? text : _mcGreen) : muted,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border, width: 0.7),
      ),
      child: Row(
        children: [
          option(
            selected: !female,
            label: 'Masculino',
            onTap: () => onChanged(false),
          ),
          option(
            selected: female,
            label: isEs ? 'Femenino' : 'Feminino',
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _CalculateButton extends StatelessWidget {
  final bool dark;
  final String label;
  final VoidCallback onTap;

  const _CalculateButton({
    required this.dark,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton(
        key: const Key('cardio_score_calculate'),
        style: FilledButton.styleFrom(
          backgroundColor: _mcGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onTap,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _ResultSection extends StatelessWidget {
  final bool dark;
  final bool isEs;
  final String scoreName;
  final String value;
  final String band;
  final String interpretation;

  const _ResultSection({
    required this.dark,
    required this.isEs,
    required this.scoreName,
    required this.value,
    required this.band,
    required this.interpretation,
  });

  @override
  Widget build(BuildContext context) {
    final text = dark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    final sub = dark ? const Color(0xFFAEB9CC) : const Color(0xFF64748B);
    final surface = dark ? _darkSurface : _lightSurface;
    final border = dark ? _darkBorder : _lightBorder;

    return Container(
      key: const Key('cardio_score_result'),
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 0.7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEs ? 'RESULTADO' : 'RESULTADO',
            style: const TextStyle(
              color: _mcGreen,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: text,
              fontSize: 26,
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            band,
            style: TextStyle(
              color: text,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            interpretation,
            style: TextStyle(
              color: sub,
              fontSize: 11.5,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExplanationSection extends StatelessWidget {
  final bool dark;
  final bool isEs;
  final String limitations;
  final String reference;

  const _ExplanationSection({
    required this.dark,
    required this.isEs,
    required this.limitations,
    required this.reference,
  });

  @override
  Widget build(BuildContext context) {
    final title = dark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    final sub = dark ? const Color(0xFFAEB9CC) : const Color(0xFF64748B);
    final border = dark ? _darkBorder : _lightBorder;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: border, height: 1, thickness: 0.7),
        const SizedBox(height: 15),
        Text(
          isEs ? 'USO Y LIMITACIONES' : 'USO E LIMITAÇÕES',
          style: TextStyle(
            color: title,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          limitations,
          style: TextStyle(
            color: sub,
            fontSize: 11,
            height: 1.45,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 13),
        Text(
          isEs ? 'REFERENCIA' : 'REFERÊNCIA',
          style: TextStyle(
            color: title,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          reference,
          style: TextStyle(
            color: sub,
            fontSize: 10.5,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _CalculatorLinkButton extends StatelessWidget {
  final bool dark;
  final bool isEs;
  final VoidCallback onTap;

  const _CalculatorLinkButton({
    required this.dark,
    required this.isEs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final border = dark ? _darkBorder : _lightBorder;
    final surface = dark ? _darkSurface : _lightSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('cardio_score_open_calculator'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border, width: 0.7),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.open_in_new_rounded,
                color: _mcGreen,
                size: 17,
              ),
              const SizedBox(width: 7),
              Text(
                isEs ? 'Abrir en Calculadora' : 'Abrir na Calculadora',
                style: const TextStyle(
                  color: _mcGreen,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubtleNote extends StatelessWidget {
  final bool dark;
  final String text;

  const _SubtleNote({
    required this.dark,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final sub = dark ? const Color(0xFFAEB9CC) : const Color(0xFF64748B);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline_rounded,
          color: sub,
          size: 15,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: sub,
              fontSize: 10.8,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
