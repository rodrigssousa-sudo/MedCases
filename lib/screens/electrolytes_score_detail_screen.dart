import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../providers/tools_state_provider.dart';
import '../services/electrolytes/electrolytes_score_engine_2026.dart';
import 'calculadora_screen.dart';

const _green = Color(0xFF009C3B);
const _darkPage = Color(0xFF171B21);
const _darkSurface = Color(0xFF20252D);
const _darkField = Color(0xFF222A35);
const _darkBorder = Color(0xFF374151);
const _lightPage = Color(0xFFECF0F4);
const _lightBorder = Color(0xFFE2E7EC);

enum ElectrolytesScoreId {
  correctedSodium,
  osmolality,
  anionGap,
  deltaRatio,
  winter,
  correctedCalcium,
}

class ElectrolytesScoreDetailScreen extends StatefulWidget {
  final ElectrolytesScoreId scoreId;

  const ElectrolytesScoreDetailScreen({
    super.key,
    required this.scoreId,
  });

  @override
  State<ElectrolytesScoreDetailScreen> createState() =>
      _ElectrolytesScoreDetailScreenState();
}

class _ElectrolytesScoreDetailScreenState
    extends State<ElectrolytesScoreDetailScreen> {
  final _sodium = TextEditingController(text: '130');
  final _glucose = TextEditingController(text: '500');
  final _bun = TextEditingController(text: '14');
  final _chloride = TextEditingController(text: '104');
  final _bicarbonate = TextEditingController(text: '20');
  final _albumin = TextEditingController(text: '2.0');
  final _anionGapCorrected = TextEditingController(text: '21');
  final _pco2 = TextEditingController(text: '30');
  final _calcium = TextEditingController(text: '7.8');

  String? _value;
  String? _band;
  String? _interpretation;
  Map<String, String> _payload = const {};

  @override
  void dispose() {
    for (final c in [
      _sodium,
      _glucose,
      _bun,
      _chloride,
      _bicarbonate,
      _albumin,
      _anionGapCorrected,
      _pco2,
      _calcium,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _isEs => context.read<AppProvider>().lang == 'es';

  String get _name => switch (widget.scoreId) {
        ElectrolytesScoreId.correctedSodium =>
          _isEs ? 'Sodio corregido' : 'Sódio corrigido',
        ElectrolytesScoreId.osmolality =>
          _isEs ? 'Osmolalidad y tonicidad' : 'Osmolalidade e tonicidade',
        ElectrolytesScoreId.anionGap =>
          _isEs ? 'Anion gap corregido' : 'Ânion gap corrigido',
        ElectrolytesScoreId.deltaRatio => 'Delta ratio',
        ElectrolytesScoreId.winter =>
          _isEs ? 'Fórmula de Winter' : 'Fórmula de Winter',
        ElectrolytesScoreId.correctedCalcium =>
          _isEs ? 'Calcio corregido' : 'Cálcio corrigido',
      };

  String get _eyebrow => switch (widget.scoreId) {
        ElectrolytesScoreId.correctedSodium ||
        ElectrolytesScoreId.osmolality =>
          _isEs ? 'SODIO · OSMOLARIDAD' : 'SÓDIO · OSMOLALIDADE',
        ElectrolytesScoreId.anionGap ||
        ElectrolytesScoreId.deltaRatio ||
        ElectrolytesScoreId.winter =>
          _isEs ? 'ÁCIDO-BASE' : 'ÁCIDO-BASE',
        ElectrolytesScoreId.correctedCalcium =>
          _isEs ? 'CALCIO · ALBÚMINA' : 'CÁLCIO · ALBUMINA',
      };

  String get _explanation => switch (widget.scoreId) {
        ElectrolytesScoreId.correctedSodium => _isEs
            ? 'Corrige el sodio medido por el desplazamiento osmótico asociado a hiperglucemia usando 1,6 mmol/L por cada 100 mg/dL de glucosa sobre 100.'
            : 'Corrige o sódio medido pelo deslocamento osmótico associado à hiperglicemia usando 1,6 mmol/L para cada 100 mg/dL de glicose acima de 100.',
        ElectrolytesScoreId.osmolality => _isEs
            ? 'Calcula osmolalidad total estimada y tonicidad efectiva. La urea entra en osmolalidad total, pero no en tonicidad.'
            : 'Calcula osmolalidade total estimada e tonicidade efetiva. A ureia entra na osmolalidade total, mas não na tonicidade.',
        ElectrolytesScoreId.anionGap => _isEs
            ? 'Calcula anion gap sin potasio y ajusta por albúmina: AG corregido = AG + 2,5 × (4 − albúmina).'
            : 'Calcula ânion gap sem potássio e ajusta pela albumina: AG corrigido = AG + 2,5 × (4 − albumina).',
        ElectrolytesScoreId.deltaRatio => _isEs
            ? 'Compara el aumento del anion gap corregido con la caída del bicarbonato. Es una heurística para trastornos metabólicos mixtos.'
            : 'Compara o aumento do ânion gap corrigido com a queda do bicarbonato. É uma heurística para distúrbios metabólicos mistos.',
        ElectrolytesScoreId.winter => _isEs
            ? 'Estima la compensación respiratoria esperada en acidosis metabólica: PaCO₂ = 1,5 × HCO₃ + 8 ±2.'
            : 'Estima a compensação respiratória esperada na acidose metabólica: PaCO₂ = 1,5 × HCO₃ + 8 ±2.',
        ElectrolytesScoreId.correctedCalcium => _isEs
            ? 'Ajusta el calcio total por albúmina. Es una estimación; el calcio ionizado es preferible cuando la unión a proteínas es poco fiable.'
            : 'Ajusta o cálcio total pela albumina. É uma estimativa; o cálcio ionizado é preferível quando a ligação a proteínas é pouco confiável.',
      };

  String get _whatChanges => switch (widget.scoreId) {
        ElectrolytesScoreId.correctedSodium => _isEs
            ? 'Ayuda a diferenciar hiponatremia translocacional por hiperglucemia de un déficit real de sodio/agua.'
            : 'Ajuda a diferenciar hiponatremia translocacional por hiperglicemia de alteração real do balanço de sódio/água.',
        ElectrolytesScoreId.osmolality => _isEs
            ? 'La tonicidad orienta el efecto osmótico sobre el volumen celular; no equivale a osmolalidad medida.'
            : 'A tonicidade orienta o efeito osmótico sobre o volume celular; não equivale à osmolalidade medida.',
        ElectrolytesScoreId.anionGap => _isEs
            ? 'La corrección por albúmina reduce el riesgo de ocultar una acidosis con anion gap elevado en hipoalbuminemia.'
            : 'A correção pela albumina reduz o risco de ocultar acidose com ânion gap elevado na hipoalbuminemia.',
        ElectrolytesScoreId.deltaRatio => _isEs
            ? 'Puede sugerir un segundo trastorno metabólico, pero debe integrarse con historia, pH, PaCO₂ y evolución.'
            : 'Pode sugerir um segundo distúrbio metabólico, mas deve ser integrado com história, pH, PaCO₂ e evolução.',
        ElectrolytesScoreId.winter => _isEs
            ? 'Compara PaCO₂ medida con el rango esperado para identificar un trastorno respiratorio agregado.'
            : 'Compara a PaCO₂ medida com a faixa esperada para identificar distúrbio respiratório adicional.',
        ElectrolytesScoreId.correctedCalcium => _isEs
            ? 'Evita interpretar automáticamente calcio total bajo por hipoalbuminemia como hipocalcemia biológicamente activa.'
            : 'Evita interpretar automaticamente cálcio total baixo por hipoalbuminemia como hipocalcemia biologicamente ativa.',
      };

  String get _limitations => switch (widget.scoreId) {
        ElectrolytesScoreId.correctedSodium => _isEs
            ? 'La relación 1,6 es una aproximación clínica. No usar el valor aislado para definir velocidad o composición de fluidos.'
            : 'A relação 1,6 é uma aproximação clínica. Não usar o valor isolado para definir velocidade ou composição de fluidos.',
        ElectrolytesScoreId.osmolality => _isEs
            ? 'Es un cálculo, no una medición. Sustancias osmóticamente activas no incluidas pueden generar discrepancia.'
            : 'É um cálculo, não uma medição. Substâncias osmoticamente ativas não incluídas podem gerar discrepância.',
        ElectrolytesScoreId.anionGap => _isEs
            ? 'El rango normal depende del laboratorio y del método. La fórmula de corrección es una aproximación.'
            : 'A faixa normal depende do laboratório e do método. A fórmula de correção é uma aproximação.',
        ElectrolytesScoreId.deltaRatio => _isEs
            ? 'No aplicar mecánicamente cuando HCO₃ ≥24 o AG corregido ≤12. Los valores de referencia son aproximados.'
            : 'Não aplicar mecanicamente quando HCO₃ ≥24 ou AG corrigido ≤12. Os valores de referência são aproximados.',
        ElectrolytesScoreId.winter => _isEs
            ? 'Aplicable a acidosis metabólica. No sustituye la interpretación completa de la gasometría ni del contexto ventilatorio.'
            : 'Aplicável à acidose metabólica. Não substitui a interpretação completa da gasometria nem do contexto ventilatório.',
        ElectrolytesScoreId.correctedCalcium => _isEs
            ? 'La corrección por albúmina puede ser inexacta en enfermedad crítica, ERC avanzada y alteraciones importantes del pH; medir calcio ionizado cuando corresponda.'
            : 'A correção pela albumina pode ser inexata em doença crítica, DRC avançada e alterações importantes do pH; medir cálcio ionizado quando indicado.',
      };

  String get _reference => switch (widget.scoreId) {
        ElectrolytesScoreId.correctedSodium =>
          'ADA/EASD/JBDS/AACE/DTS · Hyperglycemic Crises Consensus Report 2024',
        ElectrolytesScoreId.osmolality =>
          'ADA · calculated osmolality / effective osmolality convention',
        ElectrolytesScoreId.anionGap =>
          'Figge et al. Crit Care Med 1998 · albumin-adjusted anion gap',
        ElectrolytesScoreId.deltaRatio =>
          'Conventional acid-base delta ratio · interpret as heuristic',
        ElectrolytesScoreId.winter =>
          'Winter respiratory compensation equation for metabolic acidosis',
        ElectrolytesScoreId.correctedCalcium =>
          'Endotext/NCBI · albumin-adjusted calcium; ionized calcium caveat',
      };

  double _d(TextEditingController c, double fallback) =>
      double.tryParse(c.text.trim().replaceAll(',', '.')) ?? fallback;

  void _importPatient() {
    final tools = context.read<ToolsStateProvider>();
    setState(() {
      if (tools.naCtrl.text.trim().isNotEmpty) {
        _sodium.text = tools.naCtrl.text.trim();
      }
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
        case ElectrolytesScoreId.correctedSodium:
          final r = ElectrolytesScoreEngine2026.correctedSodiumForHyperglycemia(
            measuredSodiumMmolL: _d(_sodium, 130),
            glucoseMgDl: _d(_glucose, 500),
          );
          _set(
            value: '${r.toStringAsFixed(1)} mmol/L',
            band: _isEs ? 'Sodio corregido' : 'Sódio corrigido',
            interpretation: _isEs
                ? 'Valor ajustado por hiperglucemia usando el factor 1,6.'
                : 'Valor ajustado pela hiperglicemia usando o fator 1,6.',
            payload: {
              'score': 'corrected_sodium',
              'sodiumCorrected': r.toStringAsFixed(1),
              'glucose': _d(_glucose, 500).toStringAsFixed(0),
            },
          );

        case ElectrolytesScoreId.osmolality:
          final r = ElectrolytesScoreEngine2026.calculatedOsmolalityAndTonicity(
            sodiumMmolL: _d(_sodium, 140),
            glucoseMgDl: _d(_glucose, 90),
            bunMgDl: _d(_bun, 14),
          );
          _set(
            value: '${r.effectiveTonicity.toStringAsFixed(1)} mOsm/kg',
            band: _isEs ? 'Tonicidad efectiva' : 'Tonicidade efetiva',
            interpretation: _isEs
                ? 'Osmolalidad total calculada: ${r.totalCalculated.toStringAsFixed(1)} mOsm/kg.'
                : 'Osmolalidade total calculada: ${r.totalCalculated.toStringAsFixed(1)} mOsm/kg.',
            payload: {
              'score': 'osmolality_tonicity',
              'tonicity': r.effectiveTonicity.toStringAsFixed(1),
              'osmolality': r.totalCalculated.toStringAsFixed(1),
            },
          );

        case ElectrolytesScoreId.anionGap:
          final r = ElectrolytesScoreEngine2026.anionGapWithAlbuminCorrection(
            sodiumMmolL: _d(_sodium, 140),
            chlorideMmolL: _d(_chloride, 104),
            bicarbonateMmolL: _d(_bicarbonate, 20),
            albuminGDl: _d(_albumin, 2),
          );
          _set(
            value: '${r.albuminCorrectedAnionGap.toStringAsFixed(1)} mEq/L',
            band: _isEs ? 'AG corregido' : 'AG corrigido',
            interpretation: _isEs
                ? 'AG sin corregir: ${r.anionGap.toStringAsFixed(1)} mEq/L.'
                : 'AG não corrigido: ${r.anionGap.toStringAsFixed(1)} mEq/L.',
            payload: {
              'score': 'anion_gap',
              'anionGap': r.anionGap.toStringAsFixed(1),
              'anionGapCorrected':
                  r.albuminCorrectedAnionGap.toStringAsFixed(1),
            },
          );

        case ElectrolytesScoreId.deltaRatio:
          final r = ElectrolytesScoreEngine2026.deltaRatio(
            albuminCorrectedAnionGap: _d(_anionGapCorrected, 21),
            bicarbonateMmolL: _d(_bicarbonate, 20),
          );
          if (!r.applicable || r.ratio == null) {
            _set(
              value: '—',
              band: _isEs ? 'No aplicable' : 'Não aplicável',
              interpretation: _isEs
                  ? 'Requiere HCO₃ <24 y AG corregido >12 para esta heurística.'
                  : 'Requer HCO₃ <24 e AG corrigido >12 para esta heurística.',
              payload: {'score': 'delta_ratio', 'applicable': 'false'},
            );
          } else {
            final ratio = r.ratio!;
            final band = ratio < 0.4
                ? (_isEs ? '<0,4' : '<0,4')
                : ratio < 0.8
                    ? '0,4–0,8'
                    : ratio <= 2
                        ? '0,8–2,0'
                        : '>2,0';
            _set(
              value: ratio.toStringAsFixed(2),
              band: band,
              interpretation: _deltaInterpretation(ratio),
              payload: {
                'score': 'delta_ratio',
                'deltaRatio': ratio.toStringAsFixed(2),
              },
            );
          }

        case ElectrolytesScoreId.winter:
          final r = ElectrolytesScoreEngine2026.winterCompensation(
            bicarbonateMmolL: _d(_bicarbonate, 12),
            measuredPco2MmHg: _d(_pco2, 30),
          );
          _set(
            value: '${r.expectedPco2.toStringAsFixed(1)} ±2 mmHg',
            band: _winterBand(r.status),
            interpretation: _isEs
                ? 'Rango esperado: ${r.lowerBound.toStringAsFixed(1)}–${r.upperBound.toStringAsFixed(1)} mmHg.'
                : 'Faixa esperada: ${r.lowerBound.toStringAsFixed(1)}–${r.upperBound.toStringAsFixed(1)} mmHg.',
            payload: {
              'score': 'winter',
              'expectedPco2': r.expectedPco2.toStringAsFixed(1),
              'lower': r.lowerBound.toStringAsFixed(1),
              'upper': r.upperBound.toStringAsFixed(1),
            },
          );

        case ElectrolytesScoreId.correctedCalcium:
          final r = ElectrolytesScoreEngine2026.albuminCorrectedCalcium(
            totalCalciumMgDl: _d(_calcium, 7.8),
            albuminGDl: _d(_albumin, 2),
          );
          _set(
            value: '${r.toStringAsFixed(2)} mg/dL',
            band: _isEs ? 'Calcio total ajustado' : 'Cálcio total ajustado',
            interpretation: _isEs
                ? 'Estimación por albúmina; si el resultado no concuerda con la clínica o hay enfermedad crítica/alteración de pH, priorizar calcio ionizado.'
                : 'Estimativa pela albumina; se o resultado não concordar com a clínica ou houver doença crítica/alteração de pH, priorizar cálcio ionizado.',
            payload: {
              'score': 'corrected_calcium',
              'calciumCorrected': r.toStringAsFixed(2),
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

  String _deltaInterpretation(double ratio) {
    if (ratio < 0.4) {
      return _isEs
          ? 'Sugiere componente importante de acidosis metabólica con anion gap normal.'
          : 'Sugere componente importante de acidose metabólica com ânion gap normal.';
    }
    if (ratio < 0.8) {
      return _isEs
          ? 'Puede sugerir mezcla de acidosis con anion gap elevado y acidosis hiperclorémica.'
          : 'Pode sugerir mistura de acidose com ânion gap elevado e acidose hiperclorêmica.';
    }
    if (ratio <= 2.0) {
      return _isEs
          ? 'Compatible, de forma aproximada, con acidosis metabólica predominante de anion gap elevado.'
          : 'Compatível, de forma aproximada, com acidose metabólica predominantemente de ânion gap elevado.';
    }
    return _isEs
        ? 'Puede sugerir alcalosis metabólica concomitante o bicarbonato basal elevado.'
        : 'Pode sugerir alcalose metabólica concomitante ou bicarbonato basal elevado.';
  }

  String _winterBand(WinterStatus status) => switch (status) {
        WinterStatus.expectedCompensation =>
          _isEs ? 'Compensación esperada' : 'Compensação esperada',
        WinterStatus.concomitantRespiratoryAlkalosis => _isEs
            ? 'Alcalosis respiratoria agregada'
            : 'Alcalose respiratória associada',
        WinterStatus.concomitantRespiratoryAcidosis => _isEs
            ? 'Acidosis respiratoria agregada'
            : 'Acidose respiratória associada',
      };

  void _openCalculator() {
    final tools = context.read<ToolsStateProvider>();
    final lang = _isEs ? 'es' : 'pt';
    final baseQuery = tools.buildQueryStringForSpecialty('eletrolitos', lang);
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
    final suffix = parts.isEmpty ? '' : '&${parts.join('&')}';
    final url = 'https://medcasescalcu.com/?modulo=eletrolitos$suffix';

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CalculadoraScreen(initialUrl: url),
      ),
    );
  }

  List<Widget> _inputs(bool dark) {
    switch (widget.scoreId) {
      case ElectrolytesScoreId.correctedSodium:
        return [
          _NumberField(
            c: _sodium,
            label: _isEs ? 'Sodio medido (mmol/L)' : 'Sódio medido (mmol/L)',
            dark: dark,
          ),
          _NumberField(
            c: _glucose,
            label: _isEs ? 'Glucosa (mg/dL)' : 'Glicose (mg/dL)',
            dark: dark,
          ),
        ];

      case ElectrolytesScoreId.osmolality:
        return [
          _NumberField(
            c: _sodium,
            label: _isEs ? 'Sodio (mmol/L)' : 'Sódio (mmol/L)',
            dark: dark,
          ),
          _NumberField(
            c: _glucose,
            label: _isEs ? 'Glucosa (mg/dL)' : 'Glicose (mg/dL)',
            dark: dark,
          ),
          _NumberField(c: _bun, label: 'BUN (mg/dL)', dark: dark),
        ];

      case ElectrolytesScoreId.anionGap:
        return [
          _NumberField(
            c: _sodium,
            label: _isEs ? 'Sodio (mmol/L)' : 'Sódio (mmol/L)',
            dark: dark,
          ),
          _NumberField(
            c: _chloride,
            label: _isEs ? 'Cloro (mmol/L)' : 'Cloreto (mmol/L)',
            dark: dark,
          ),
          _NumberField(c: _bicarbonate, label: 'HCO₃ (mmol/L)', dark: dark),
          _NumberField(
            c: _albumin,
            label: _isEs ? 'Albúmina (g/dL)' : 'Albumina (g/dL)',
            dark: dark,
          ),
        ];

      case ElectrolytesScoreId.deltaRatio:
        return [
          _NumberField(
            c: _anionGapCorrected,
            label: _isEs ? 'AG corregido (mEq/L)' : 'AG corrigido (mEq/L)',
            dark: dark,
          ),
          _NumberField(c: _bicarbonate, label: 'HCO₃ (mmol/L)', dark: dark),
        ];

      case ElectrolytesScoreId.winter:
        return [
          _NumberField(c: _bicarbonate, label: 'HCO₃ (mmol/L)', dark: dark),
          _NumberField(c: _pco2, label: 'PaCO₂ medida (mmHg)', dark: dark),
        ];

      case ElectrolytesScoreId.correctedCalcium:
        return [
          _NumberField(
            c: _calcium,
            label: _isEs ? 'Calcio total (mg/dL)' : 'Cálcio total (mg/dL)',
            dark: dark,
          ),
          _NumberField(
            c: _albumin,
            label: _isEs ? 'Albúmina (g/dL)' : 'Albumina (g/dL)',
            dark: dark,
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
              title: _isEs ? 'ELECTROLITOS' : 'ELETRÓLITOS',
            ),
            const SizedBox(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 120),
                children: [
                  _ImportButton(
                    key: const Key('electrolytes_import_patient'),
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
                            key: const Key('electrolytes_calculate'),
                            style: FilledButton.styleFrom(
                              backgroundColor: _green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: _calculate,
                            child: const Text(
                              'CALCULAR',
                              style: TextStyle(
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
                      key: const Key('electrolytes_result'),
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
              const Icon(
                Icons.person_search_outlined,
                size: 16,
                color: _green,
              ),
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 11,
          vertical: 12,
        ),
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
          const Text(
            'RESULTADO',
            style: TextStyle(
              color: _green,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              color: title,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            band,
            style: const TextStyle(
              color: _green,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 13),
          Text(
            isEs ? 'SIGNIFICADO' : 'SIGNIFICADO',
            style: TextStyle(
              color: title,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            interpretation,
            style: TextStyle(color: sub, fontSize: 11, height: 1.45),
          ),
          const SizedBox(height: 13),
          Text(
            isEs ? 'QUÉ CAMBIA' : 'O QUE MUDA',
            style: TextStyle(
              color: title,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            whatChanges,
            style: TextStyle(color: sub, fontSize: 11, height: 1.45),
          ),
          const SizedBox(height: 13),
          Text(
            isEs ? 'LIMITACIONES' : 'LIMITAÇÕES',
            style: TextStyle(
              color: title,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            limitations,
            style: TextStyle(color: sub, fontSize: 11, height: 1.45),
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
            style: TextStyle(color: sub, fontSize: 10.5, height: 1.4),
          ),
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
        key: const Key('electrolytes_open_calculator'),
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
              const Icon(
                Icons.open_in_new_rounded,
                color: _green,
                size: 17,
              ),
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
