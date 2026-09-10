import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../providers/tools_state_provider.dart';
import '../services/hepato/hepato_score_engine_2026.dart';
import 'calculadora_screen.dart';

const _green = Color(0xFF009C3B);
const _darkPage = Color(0xFF171B21);
const _darkSurface = Color(0xFF20252D);
const _darkField = Color(0xFF222A35);
const _darkBorder = Color(0xFF374151);
const _lightPage = Color(0xFFECF0F4);
const _lightBorder = Color(0xFFE2E7EC);

enum HepatoScoreId {
  meld30,
  childPugh,
  fib4,
  maddrey,
  lille,
}

class HepatoScoreDetailScreen extends StatefulWidget {
  final HepatoScoreId scoreId;

  const HepatoScoreDetailScreen({
    super.key,
    required this.scoreId,
  });

  @override
  State<HepatoScoreDetailScreen> createState() =>
      _HepatoScoreDetailScreenState();
}

class _HepatoScoreDetailScreenState extends State<HepatoScoreDetailScreen> {
  final _age = TextEditingController(text: '50');
  final _bilirubin = TextEditingController(text: '3.0');
  final _inr = TextEditingController(text: '1.8');
  final _creatinine = TextEditingController(text: '1.2');
  final _sodium = TextEditingController(text: '132');
  final _albumin = TextEditingController(text: '2.8');
  final _ast = TextEditingController(text: '80');
  final _alt = TextEditingController(text: '60');
  final _platelets = TextEditingController(text: '150');
  final _ptPatient = TextEditingController(text: '20');
  final _ptControl = TextEditingController(text: '12');
  final _bilirubinFollow = TextEditingController(text: '2.0');

  bool _female = false;
  bool _dialysisCriterion = false;
  ChildAscites _ascites = ChildAscites.none;
  ChildEncephalopathy _encephalopathy = ChildEncephalopathy.none;
  int _lilleDay = 7;

  String? _value;
  String? _band;
  String? _interpretation;
  Map<String, String> _payload = const {};

  @override
  void dispose() {
    for (final c in [
      _age,
      _bilirubin,
      _inr,
      _creatinine,
      _sodium,
      _albumin,
      _ast,
      _alt,
      _platelets,
      _ptPatient,
      _ptControl,
      _bilirubinFollow,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _isEs => context.read<AppProvider>().lang == 'es';

  String get _name => switch (widget.scoreId) {
        HepatoScoreId.meld30 => 'MELD 3.0',
        HepatoScoreId.childPugh => 'Child-Pugh',
        HepatoScoreId.fib4 => 'FIB-4',
        HepatoScoreId.maddrey => 'Maddrey mDF',
        HepatoScoreId.lille => 'Lille',
      };

  String get _eyebrow => switch (widget.scoreId) {
        HepatoScoreId.meld30 ||
        HepatoScoreId.childPugh =>
          _isEs ? 'CIRROSIS · PRONÓSTICO' : 'CIRROSE · PROGNÓSTICO',
        HepatoScoreId.fib4 =>
          _isEs ? 'FIBROSIS · ESTRATIFICACIÓN' : 'FIBROSE · ESTRATIFICAÇÃO',
        HepatoScoreId.maddrey || HepatoScoreId.lille => _isEs
            ? 'HEPATITIS ASOCIADA AL ALCOHOL'
            : 'HEPATITE ASSOCIADA AO ÁLCOOL',
      };

  String get _explanation => switch (widget.scoreId) {
        HepatoScoreId.meld30 => _isEs
            ? 'Implementa la ecuación MELD 3.0 de OPTN/HRSA con límites oficiales para bilirrubina, INR, creatinina, sodio y albúmina.'
            : 'Implementa a equação MELD 3.0 da OPTN/HRSA com limites oficiais para bilirrubina, INR, creatinina, sódio e albumina.',
        HepatoScoreId.childPugh => _isEs
            ? 'Estratifica cirrosis con bilirrubina, albúmina, INR, ascitis y encefalopatía.'
            : 'Estratifica cirrose com bilirrubina, albumina, INR, ascite e encefalopatia.',
        HepatoScoreId.fib4 => _isEs
            ? 'Índice no invasivo basado en edad, AST, ALT y plaquetas para estimar probabilidad de fibrosis avanzada.'
            : 'Índice não invasivo baseado em idade, AST, ALT e plaquetas para estimar probabilidade de fibrose avançada.',
        HepatoScoreId.maddrey => _isEs
            ? 'La mDF estima gravedad en hepatitis asociada al alcohol usando TP del paciente, TP control y bilirrubina.'
            : 'A mDF estima gravidade na hepatite associada ao álcool usando TP do paciente, TP controle e bilirrubina.',
        HepatoScoreId.lille => _isEs
            ? 'Evalúa respuesta a corticoides en hepatitis alcohólica grave. Día 7 es el modelo original; día 4 es una adaptación posteriormente validada.'
            : 'Avalia resposta a corticoide na hepatite alcoólica grave. Dia 7 é o modelo original; dia 4 é uma adaptação posteriormente validada.',
      };

  String get _whatChanges => switch (widget.scoreId) {
        HepatoScoreId.meld30 => _isEs
            ? 'Aporta una medida estandarizada de gravedad y, en el sistema OPTN, participa de la priorización de trasplante.'
            : 'Fornece medida padronizada de gravidade e, no sistema OPTN, participa da priorização para transplante.',
        HepatoScoreId.childPugh => _isEs
            ? 'Ayuda a comunicar reserva hepática y riesgo, pero no debe reemplazar decisiones específicas de trasplante o procedimiento.'
            : 'Ajuda a comunicar reserva hepática e risco, mas não substitui decisões específicas de transplante ou procedimento.',
        HepatoScoreId.fib4 => _isEs
            ? 'Puede seleccionar quién requiere evaluación no invasiva adicional o derivación según la población y la guía aplicable.'
            : 'Pode selecionar quem precisa avaliação não invasiva adicional ou encaminhamento conforme população e diretriz aplicável.',
        HepatoScoreId.maddrey => _isEs
            ? 'mDF ≥32 identifica enfermedad grave; la decisión sobre corticoides exige revisar contraindicaciones y contexto clínico.'
            : 'mDF ≥32 identifica doença grave; a decisão sobre corticoide exige revisar contraindicações e contexto clínico.',
        HepatoScoreId.lille => _isEs
            ? 'Lille ≥0,45 identifica no respuesta y apoya reevaluar la continuidad de corticoides.'
            : 'Lille ≥0,45 identifica não resposta e apoia reavaliar a continuidade do corticoide.',
      };

  String get _limitations => switch (widget.scoreId) {
        HepatoScoreId.meld30 => _isEs
            ? 'Aplicar exactamente las reglas de política vigentes. El score no sustituye evaluación de trasplante ni captura todas las complicaciones de la cirrosis.'
            : 'Aplicar exatamente as regras de política vigentes. O score não substitui avaliação para transplante nem captura todas as complicações da cirrose.',
        HepatoScoreId.childPugh => _isEs
            ? 'Ascitis y encefalopatía tienen componente clínico subjetivo; existen pequeñas variaciones históricas de umbrales.'
            : 'Ascite e encefalopatia têm componente clínico subjetivo; existem pequenas variações históricas de limiares.',
        HepatoScoreId.fib4 => _isEs
            ? 'Rendimiento depende de edad y etiología. En mayores de 65 años y menores de 35 años la interpretación requiere cautela específica.'
            : 'O desempenho depende de idade e etiologia. Em maiores de 65 anos e menores de 35 anos a interpretação requer cautela específica.',
        HepatoScoreId.maddrey => _isEs
            ? 'El TP control debe corresponder al laboratorio. No usar mDF aislada para indicar tratamiento.'
            : 'O TP controle deve corresponder ao laboratório. Não usar a mDF isoladamente para indicar tratamento.',
        HepatoScoreId.lille => _isEs
            ? 'Sólo es aplicable tras iniciar corticoides en hepatitis alcohólica grave; día 7 es el modelo derivado originalmente.'
            : 'Só é aplicável após início de corticoide na hepatite alcoólica grave; dia 7 é o modelo originalmente derivado.',
      };

  String get _reference => switch (widget.scoreId) {
        HepatoScoreId.meld30 =>
          'OPTN Policies · Table 9-17 MELD 3.0 · effective 10 Dec 2025',
        HepatoScoreId.childPugh =>
          'Child-Turcotte-Pugh conventional cirrhosis classification',
        HepatoScoreId.fib4 =>
          'AASLD noninvasive liver disease assessment · FIB-4',
        HepatoScoreId.maddrey =>
          'AASLD alcohol-associated hepatitis · modified Maddrey DF',
        HepatoScoreId.lille =>
          'Louvet et al. Hepatology 2007 · AASLD alcohol-associated hepatitis',
      };

  int _i(TextEditingController c, int fallback) =>
      int.tryParse(c.text.trim()) ?? fallback;

  double _d(TextEditingController c, double fallback) =>
      double.tryParse(c.text.trim().replaceAll(',', '.')) ?? fallback;

  void _importPatient() {
    final tools = context.read<ToolsStateProvider>();
    setState(() {
      if (tools.ageCtrl.text.trim().isNotEmpty) {
        _age.text = tools.ageCtrl.text.trim();
      }
      if (tools.crCtrl.text.trim().isNotEmpty) {
        _creatinine.text = tools.crCtrl.text.trim();
      }
      if (tools.naCtrl.text.trim().isNotEmpty) {
        _sodium.text = tools.naCtrl.text.trim();
      }
      _female = tools.isFemale;
    });
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
        case HepatoScoreId.meld30:
          final r = HepatoScoreEngine2026.meld30(
            bilirubinMgDl: _d(_bilirubin, 3),
            inr: _d(_inr, 1.8),
            creatinineMgDl: _d(_creatinine, 1.2),
            sodiumMmolL: _d(_sodium, 132),
            albuminGDl: _d(_albumin, 2.8),
            female: _female,
            dialysisCriterionLast7Days: _dialysisCriterion,
          );
          _set(
            value: '${r.score}',
            band: 'MELD 3.0',
            interpretation: _isEs
                ? 'Puntaje MELD 3.0 calculado con límites oficiales OPTN.'
                : 'Escore MELD 3.0 calculado com os limites oficiais OPTN.',
            payload: {
              'score': 'meld30',
              'meld30': '${r.score}',
              'bilirubin': r.bilirubinUsed.toStringAsFixed(2),
              'inr': r.inrUsed.toStringAsFixed(2),
              'creatinine': r.creatinineUsed.toStringAsFixed(2),
              'sodium': r.sodiumUsed.toStringAsFixed(1),
              'albumin': r.albuminUsed.toStringAsFixed(2),
            },
          );

        case HepatoScoreId.childPugh:
          final r = HepatoScoreEngine2026.childPugh(
            bilirubinMgDl: _d(_bilirubin, 3),
            albuminGDl: _d(_albumin, 2.8),
            inr: _d(_inr, 1.8),
            ascites: _ascites,
            encephalopathy: _encephalopathy,
          );
          _set(
            value: '${r.score}',
            band: 'Child-Pugh ${r.childClass}',
            interpretation: _isEs
                ? 'Clase ${r.childClass}, puntaje ${r.score}/15.'
                : 'Classe ${r.childClass}, escore ${r.score}/15.',
            payload: {
              'score': 'child_pugh',
              'childPugh': '${r.score}',
              'childClass': r.childClass,
            },
          );

        case HepatoScoreId.fib4:
          final r = HepatoScoreEngine2026.fib4(
            ageYears: _i(_age, 50),
            astUL: _d(_ast, 80),
            altUL: _d(_alt, 60),
            platelets10e9L: _d(_platelets, 150),
          );
          final band = r < 1.3
              ? (_isEs ? 'Bajo' : 'Baixo')
              : r <= 2.67
                  ? (_isEs ? 'Intermedio' : 'Intermediário')
                  : (_isEs ? 'Elevado' : 'Elevado');
          _set(
            value: r.toStringAsFixed(2),
            band: band,
            interpretation: _isEs
                ? 'Interpretar el umbral según edad, etiología y algoritmo de la guía aplicable.'
                : 'Interpretar o limiar conforme idade, etiologia e algoritmo da diretriz aplicável.',
            payload: {'score': 'fib4', 'fib4': r.toStringAsFixed(2)},
          );

        case HepatoScoreId.maddrey:
          final r = HepatoScoreEngine2026.maddreyDiscriminantFunction(
            patientPtSeconds: _d(_ptPatient, 20),
            controlPtSeconds: _d(_ptControl, 12),
            bilirubinMgDl: _d(_bilirubin, 3),
          );
          _set(
            value: r.toStringAsFixed(1),
            band: r >= 32
                ? (_isEs ? 'Grave · ≥32' : 'Grave · ≥32')
                : (_isEs ? '<32' : '<32'),
            interpretation: r >= 32
                ? (_isEs
                    ? 'mDF ≥32: hepatitis asociada al alcohol grave; evaluar elegibilidad terapéutica en contexto.'
                    : 'mDF ≥32: hepatite associada ao álcool grave; avaliar elegibilidade terapêutica no contexto.')
                : (_isEs
                    ? 'mDF <32: no alcanza el umbral clásico de gravedad por este modelo.'
                    : 'mDF <32: não atinge o limiar clássico de gravidade por este modelo.'),
            payload: {'score': 'maddrey', 'maddrey': r.toStringAsFixed(1)},
          );

        case HepatoScoreId.lille:
          final r = HepatoScoreEngine2026.lille(
            ageYears: _i(_age, 50),
            albuminDay0GDl: _d(_albumin, 2.8),
            bilirubinDay0MgDl: _d(_bilirubin, 3),
            bilirubinFollowUpMgDl: _d(_bilirubinFollow, 2),
            creatinineMgDl: _d(_creatinine, 1.2),
            prothrombinTimeSeconds: _d(_ptPatient, 20),
            followUpDay: _lilleDay,
          );
          _set(
            value: r.score.toStringAsFixed(3),
            band: r.nonResponder
                ? (_isEs ? 'No respondedor · ≥0,45' : 'Não respondedor · ≥0,45')
                : (_isEs ? 'Respondedor · <0,45' : 'Respondedor · <0,45'),
            interpretation: r.nonResponder
                ? (_isEs
                    ? 'Resultado compatible con no respuesta a corticoides; reevaluar continuidad del tratamiento.'
                    : 'Resultado compatível com não resposta ao corticoide; reavaliar continuidade do tratamento.')
                : (_isEs
                    ? 'Resultado compatible con respuesta al corticoide.'
                    : 'Resultado compatível com resposta ao corticoide.'),
            payload: {
              'score': 'lille',
              'lille': r.score.toStringAsFixed(3),
              'day': '${r.followUpDay}',
            },
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
    final baseQuery = tools.buildQueryStringForSpecialty('hepato', lang);
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
        'https://medcasescalcu.com/?modulo=hepatologia&${parts.join('&')}';

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CalculadoraScreen(initialUrl: url),
      ),
    );
  }

  List<Widget> _inputs(bool dark) {
    final isEs = _isEs;
    switch (widget.scoreId) {
      case HepatoScoreId.meld30:
        return [
          _NumberField(
              c: _bilirubin,
              label: isEs ? 'Bilirrubina (mg/dL)' : 'Bilirrubina (mg/dL)',
              dark: dark),
          _NumberField(c: _inr, label: 'INR', dark: dark),
          _NumberField(
              c: _creatinine,
              label: isEs ? 'Creatinina (mg/dL)' : 'Creatinina (mg/dL)',
              dark: dark),
          _NumberField(
              c: _sodium,
              label: isEs ? 'Sodio (mmol/L)' : 'Sódio (mmol/L)',
              dark: dark),
          _NumberField(
              c: _albumin,
              label: isEs ? 'Albúmina (g/dL)' : 'Albumina (g/dL)',
              dark: dark),
          _ToggleRow(
            value: _female,
            onChanged: (v) => setState(() => _female = v),
            label: isEs ? 'Sexo femenino' : 'Sexo feminino',
            dark: dark,
          ),
          _ToggleRow(
            value: _dialysisCriterion,
            onChanged: (v) => setState(() => _dialysisCriterion = v),
            label: isEs
                ? 'Criterio OPTN de diálisis/CVVHD en 7 días'
                : 'Critério OPTN de diálise/CVVHD em 7 dias',
            dark: dark,
          ),
        ];

      case HepatoScoreId.childPugh:
        return [
          _NumberField(c: _bilirubin, label: 'Bilirrubina (mg/dL)', dark: dark),
          _NumberField(
              c: _albumin,
              label: isEs ? 'Albúmina (g/dL)' : 'Albumina (g/dL)',
              dark: dark),
          _NumberField(c: _inr, label: 'INR', dark: dark),
          _ChoiceRow<ChildAscites>(
            label: isEs ? 'Ascitis' : 'Ascite',
            value: _ascites,
            dark: dark,
            items: [
              _Choice(ChildAscites.none, isEs ? 'Ausente' : 'Ausente'),
              _Choice(ChildAscites.mild,
                  isEs ? 'Leve/controlada' : 'Leve/controlada'),
              _Choice(ChildAscites.moderateSevere,
                  isEs ? 'Moderada-grave' : 'Moderada-grave'),
            ],
            onChanged: (v) => setState(() => _ascites = v),
          ),
          _ChoiceRow<ChildEncephalopathy>(
            label: isEs ? 'Encefalopatía' : 'Encefalopatia',
            value: _encephalopathy,
            dark: dark,
            items: [
              _Choice(ChildEncephalopathy.none, isEs ? 'Ausente' : 'Ausente'),
              _Choice(ChildEncephalopathy.grade12, 'Grau I–II'),
              _Choice(ChildEncephalopathy.grade34, 'Grau III–IV'),
            ],
            onChanged: (v) => setState(() => _encephalopathy = v),
          ),
        ];

      case HepatoScoreId.fib4:
        return [
          _NumberField(
              c: _age,
              label: isEs ? 'Edad (años)' : 'Idade (anos)',
              dark: dark),
          _NumberField(c: _ast, label: 'AST (U/L)', dark: dark),
          _NumberField(c: _alt, label: 'ALT (U/L)', dark: dark),
          _NumberField(
              c: _platelets,
              label: isEs ? 'Plaquetas (10⁹/L)' : 'Plaquetas (10⁹/L)',
              dark: dark),
        ];

      case HepatoScoreId.maddrey:
        return [
          _NumberField(
              c: _ptPatient,
              label: isEs ? 'TP paciente (s)' : 'TP paciente (s)',
              dark: dark),
          _NumberField(
              c: _ptControl,
              label: isEs ? 'TP control (s)' : 'TP controle (s)',
              dark: dark),
          _NumberField(c: _bilirubin, label: 'Bilirrubina (mg/dL)', dark: dark),
        ];

      case HepatoScoreId.lille:
        return [
          _NumberField(
              c: _age,
              label: isEs ? 'Edad (años)' : 'Idade (anos)',
              dark: dark),
          _NumberField(
              c: _albumin,
              label: isEs ? 'Albúmina día 0 (g/dL)' : 'Albumina dia 0 (g/dL)',
              dark: dark),
          _NumberField(
              c: _bilirubin,
              label: isEs
                  ? 'Bilirrubina día 0 (mg/dL)'
                  : 'Bilirrubina dia 0 (mg/dL)',
              dark: dark),
          _NumberField(
              c: _bilirubinFollow,
              label: isEs
                  ? 'Bilirrubina seguimiento (mg/dL)'
                  : 'Bilirrubina seguimento (mg/dL)',
              dark: dark),
          _NumberField(c: _creatinine, label: 'Creatinina (mg/dL)', dark: dark),
          _NumberField(
              c: _ptPatient, label: isEs ? 'TP (s)' : 'TP (s)', dark: dark),
          _ChoiceRow<int>(
            label: isEs ? 'Día de seguimiento' : 'Dia de seguimento',
            value: _lilleDay,
            dark: dark,
            items: const [
              _Choice(7, 'Dia 7'),
              _Choice(4, 'Dia 4'),
            ],
            onChanged: (v) => setState(() => _lilleDay = v),
          ),
        ];
    }
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
            _Topbar(
              dark: dark,
              title: _isEs ? 'HEPATOLOGÍA' : 'HEPATOLOGIA',
            ),
            const SizedBox(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 120),
                children: [
                  _ImportButton(
                    key: const Key('hepato_import_patient'),
                    dark: dark,
                    isEs: _isEs,
                    onTap: _importPatient,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _eyebrow,
                    style: TextStyle(
                      color: sub,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.9,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _name,
                    style: TextStyle(
                      color: title,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    _explanation,
                    style: TextStyle(color: sub, fontSize: 11, height: 1.45),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: dark ? _darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: border, width: 0.7),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        for (final field in _inputs(dark)) ...[
                          field,
                          const SizedBox(height: 9),
                        ],
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: FilledButton(
                            key: const Key('hepato_calculate'),
                            style: FilledButton.styleFrom(
                              backgroundColor: _green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: _calculate,
                            child: Text(
                              _isEs ? 'CALCULAR' : 'CALCULAR',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_value != null) ...[
                    const SizedBox(height: 12),
                    _ResultCard(
                      key: const Key('hepato_result'),
                      dark: dark,
                      isEs: _isEs,
                      value: _value!,
                      band: _band!,
                      interpretation: _interpretation!,
                      whatChanges: _whatChanges,
                      limitations: _limitations,
                      reference: _reference,
                    ),
                    const SizedBox(height: 10),
                    _CalculatorButton(
                      dark: dark,
                      isEs: _isEs,
                      onTap: _openCalculator,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
  final bool dark;
  final bool isEs;
  final VoidCallback onTap;

  const _ImportButton({
    super.key,
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
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            color: dark ? _darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border, width: 0.7),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_search_outlined, size: 16, color: _green),
              const SizedBox(width: 6),
              Text(
                isEs ? 'Importar paciente' : 'Importar paciente',
                style: const TextStyle(
                  color: _green,
                  fontSize: 11,
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
  final TextEditingController c;
  final String label;
  final bool dark;

  const _NumberField({
    required this.c,
    required this.label,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final border = dark ? _darkBorder : _lightBorder;
    final text = dark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(color: text, fontSize: 12),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: dark ? const Color(0xFFAEB9CC) : const Color(0xFF64748B),
          fontSize: 10.5,
        ),
        filled: true,
        fillColor: dark ? _darkField : const Color(0xFFF8FAFC),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(color: border, width: 0.7),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: _green, width: 1),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;
  final bool dark;

  const _ToggleRow({
    required this.value,
    required this.onChanged,
    required this.label,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final text = dark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    return Row(
      children: [
        Expanded(
            child: Text(label, style: TextStyle(color: text, fontSize: 11))),
        Switch(
          value: value,
          activeThumbColor: _green,
          activeTrackColor: _green.withValues(alpha: 0.30),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _Choice<T> {
  final T value;
  final String label;
  const _Choice(this.value, this.label);
}

class _ChoiceRow<T> extends StatelessWidget {
  final String label;
  final T value;
  final bool dark;
  final List<_Choice<T>> items;
  final ValueChanged<T> onChanged;

  const _ChoiceRow({
    required this.label,
    required this.value,
    required this.dark,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final border = dark ? _darkBorder : _lightBorder;
    final text = dark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 3),
      decoration: BoxDecoration(
        color: dark ? _darkField : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: border, width: 0.7),
      ),
      child: Row(
        children: [
          Expanded(
              child:
                  Text(label, style: TextStyle(color: text, fontSize: 10.5))),
          DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              dropdownColor: dark ? _darkSurface : Colors.white,
              style: TextStyle(color: text, fontSize: 10.5),
              items: items
                  .map(
                    (x) => DropdownMenuItem<T>(
                      value: x.value,
                      child: Text(x.label),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  onChanged(v);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final bool dark;
  final bool isEs;
  final String value;
  final String band;
  final String interpretation;
  final String whatChanges;
  final String limitations;
  final String reference;

  const _ResultCard({
    super.key,
    required this.dark,
    required this.isEs,
    required this.value,
    required this.band,
    required this.interpretation,
    required this.whatChanges,
    required this.limitations,
    required this.reference,
  });

  @override
  Widget build(BuildContext context) {
    final border = dark ? _darkBorder : _lightBorder;
    final title = dark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    final sub = dark ? const Color(0xFFAEB9CC) : const Color(0xFF64748B);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: dark ? _darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 0.7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isEs ? 'RESULTADO' : 'RESULTADO',
              style: const TextStyle(
                  color: _green,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.9)),
          const SizedBox(height: 5),
          Text(value,
              style: TextStyle(
                  color: title, fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(band,
              style: const TextStyle(
                  color: _green, fontSize: 11, fontWeight: FontWeight.w800)),
          const SizedBox(height: 13),
          Text(isEs ? 'SIGNIFICADO' : 'SIGNIFICADO',
              style: TextStyle(
                  color: title,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8)),
          const SizedBox(height: 5),
          Text(interpretation,
              style: TextStyle(color: sub, fontSize: 11, height: 1.45)),
          const SizedBox(height: 13),
          Text(isEs ? 'QUÉ CAMBIA' : 'O QUE MUDA',
              style: TextStyle(
                  color: title,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8)),
          const SizedBox(height: 5),
          Text(whatChanges,
              style: TextStyle(color: sub, fontSize: 11, height: 1.45)),
          const SizedBox(height: 13),
          Text(isEs ? 'LIMITACIONES' : 'LIMITAÇÕES',
              style: TextStyle(
                  color: title,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8)),
          const SizedBox(height: 5),
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
        ],
      ),
    );
  }
}

class _CalculatorButton extends StatelessWidget {
  final bool dark;
  final bool isEs;
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
        key: const Key('hepato_open_calculator'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: dark ? _darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border, width: 0.7),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.open_in_new_rounded, color: _green, size: 17),
              const SizedBox(width: 7),
              Text(
                isEs ? 'Abrir en Calculadora' : 'Abrir na Calculadora',
                style: const TextStyle(
                  color: _green,
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
