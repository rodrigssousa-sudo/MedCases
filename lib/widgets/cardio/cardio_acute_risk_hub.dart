import 'package:flutter/material.dart';

import '../../services/cardio/cardio_acute_risk_engine_2026.dart';

typedef CardioScoreDeeplinkCallback = void Function(
  String scoreKey,
  Map<String, String> params,
);

enum _CardioAcuteTool { heart, timi, grace, killip }

class CardioAcuteRiskHub extends StatefulWidget {
  final bool isEs;
  final bool dark;
  final int initialAge;
  final int initialSbp;
  final int initialHeartRate;
  final CardioScoreDeeplinkCallback onOpenCalculator;

  const CardioAcuteRiskHub({
    super.key,
    required this.isEs,
    required this.dark,
    required this.initialAge,
    required this.initialSbp,
    required this.initialHeartRate,
    required this.onOpenCalculator,
  });

  @override
  State<CardioAcuteRiskHub> createState() => _CardioAcuteRiskHubState();
}

class _CardioAcuteRiskHubState extends State<CardioAcuteRiskHub> {
  @override
  Widget build(BuildContext context) {
    final title =
        widget.dark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final sub = widget.dark ? const Color(0xFFAEB9CC) : const Color(0xFF64748B);

    return Column(
      key: const Key('cardio_acute_risk_hub'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.isEs ? 'Estratificación de SCA' : 'Estratificação de SCA',
          style: TextStyle(
            color: title,
            fontSize: 20,
            height: 1.15,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.35,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.isEs
              ? 'Seleccione un score. Se abrirá en una pantalla propia.'
              : 'Selecione um score. Ele abrirá em uma tela própria.',
          style: TextStyle(
            color: sub,
            fontSize: 12.5,
            height: 1.35,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 14),
        GridView.count(
          key: const Key('cardio_score_grid'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          crossAxisCount: 2,
          crossAxisSpacing: 5,
          mainAxisSpacing: 5,
          childAspectRatio: 1.42,
          children: [
            _ScoreHomeCard(
              key: const Key('score_card_heart'),
              dark: widget.dark,
              selected: false,
              icon: Icons.favorite_outline_rounded,
              title: 'HEART',
              subtitle:
                  widget.isEs ? 'Dolor torácico · CDP' : 'Dor torácica · CDP',
              badge: '0–10',
              onTap: () => _openTool(_CardioAcuteTool.heart),
            ),
            _ScoreHomeCard(
              key: const Key('score_card_timi'),
              dark: widget.dark,
              selected: false,
              icon: Icons.stacked_line_chart_rounded,
              title: 'TIMI',
              subtitle: 'UA / NSTEMI',
              badge: '0–7',
              onTap: () => _openTool(_CardioAcuteTool.timi),
            ),
            _ScoreHomeCard(
              key: const Key('score_card_grace'),
              dark: widget.dark,
              selected: false,
              icon: Icons.monitor_heart_outlined,
              title: 'GRACE',
              subtitle:
                  widget.isEs ? 'Admisión · >140 ESC' : 'Admissão · >140 ESC',
              badge: 'ACS',
              onTap: () => _openTool(_CardioAcuteTool.grace),
            ),
            _ScoreHomeCard(
              key: const Key('score_card_killip'),
              dark: widget.dark,
              selected: false,
              icon: Icons.air_rounded,
              title: 'Killip',
              subtitle: widget.isEs ? 'IC en infarto' : 'IC no infarto',
              badge: 'I–IV',
              onTap: () => _openTool(_CardioAcuteTool.killip),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          widget.isEs
              ? 'HEART debe integrarse a una vía estructurada con hs-cTn. GRACE mostrado aquí es el score original de puntos; no equivale a las probabilidades GRACE 2.0.'
              : 'HEART deve integrar uma via estruturada com hs-cTn. O GRACE mostrado aqui é o score original por pontos; não equivale às probabilidades do GRACE 2.0.',
          style: TextStyle(
            color: sub,
            fontSize: 10.5,
            height: 1.35,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  void _openTool(_CardioAcuteTool tool) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _CardioAcuteScoreScreen(
          dark: widget.dark,
          title: _titleFor(tool),
          child: _panelFor(tool),
        ),
      ),
    );
  }

  String _titleFor(_CardioAcuteTool tool) {
    switch (tool) {
      case _CardioAcuteTool.heart:
        return 'HEART';
      case _CardioAcuteTool.timi:
        return 'TIMI UA/NSTEMI';
      case _CardioAcuteTool.grace:
        return 'GRACE';
      case _CardioAcuteTool.killip:
        return 'KILLIP';
    }
  }

  Widget _panelFor(_CardioAcuteTool tool) {
    switch (tool) {
      case _CardioAcuteTool.heart:
        return _HeartPanel(
          key: const ValueKey('heart_panel'),
          isEs: widget.isEs,
          dark: widget.dark,
          initialAge: widget.initialAge,
          onOpenCalculator: widget.onOpenCalculator,
        );
      case _CardioAcuteTool.timi:
        return _TimiPanel(
          key: const ValueKey('timi_panel'),
          isEs: widget.isEs,
          dark: widget.dark,
          initialAge: widget.initialAge,
          onOpenCalculator: widget.onOpenCalculator,
        );
      case _CardioAcuteTool.grace:
        return _GracePanel(
          key: const ValueKey('grace_panel'),
          isEs: widget.isEs,
          dark: widget.dark,
          initialAge: widget.initialAge,
          initialSbp: widget.initialSbp,
          initialHeartRate: widget.initialHeartRate,
          onOpenCalculator: widget.onOpenCalculator,
        );
      case _CardioAcuteTool.killip:
        return _KillipPanel(
          key: const ValueKey('killip_panel'),
          isEs: widget.isEs,
          dark: widget.dark,
          onOpenCalculator: widget.onOpenCalculator,
        );
    }
  }
}

class _CardioAcuteScoreScreen extends StatelessWidget {
  final bool dark;
  final String title;
  final Widget child;

  const _CardioAcuteScoreScreen({
    required this.dark,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF1A1D23) : const Color(0xFFECF0F4);
    final text = dark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    final border = dark ? const Color(0xFF374151) : const Color(0xFFE2E7EC);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: border, width: 0.7)),
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
                        icon: Icon(Icons.chevron_left_rounded,
                            size: 30, color: text),
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
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreHomeCard extends StatelessWidget {
  final bool dark;
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback onTap;

  const _ScoreHomeCard({
    super.key,
    required this.dark,
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF009C3B);
    final surface = dark ? const Color(0xFF252930) : Colors.white;
    final border = selected
        ? accent
        : (dark ? const Color(0xFF374151) : const Color(0xFFE2E7EC));
    final titleColor = dark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final subColor = dark ? const Color(0xFFAEB9CC) : const Color(0xFF64748B);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: 0.7),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, size: 24, color: accent),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: accent,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: titleColor,
                  fontSize: 12.5,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: subColor,
                  fontSize: 9.2,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScorePanelShell extends StatelessWidget {
  final bool dark;
  final String title;
  final String subtitle;
  final Widget child;

  const _ScorePanelShell({
    required this.dark,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = dark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final subColor = dark ? const Color(0xFFAEB9CC) : const Color(0xFF64748B);

    return Column(
      key: const Key('score_detail_panel'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: titleColor,
            fontSize: 20,
            height: 1.15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: subColor,
            fontSize: 12,
            height: 1.35,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 14),
        child,
      ],
    );
  }
}

class _HeartPanel extends StatefulWidget {
  final bool isEs;
  final bool dark;
  final int initialAge;
  final CardioScoreDeeplinkCallback onOpenCalculator;

  const _HeartPanel({
    super.key,
    required this.isEs,
    required this.dark,
    required this.initialAge,
    required this.onOpenCalculator,
  });

  @override
  State<_HeartPanel> createState() => _HeartPanelState();
}

class _HeartPanelState extends State<_HeartPanel> {
  late final TextEditingController _age;
  late final TextEditingController _riskCount;
  int _history = 0;
  int _ecg = 0;
  int _troponin = 0;
  bool _knownAscvd = false;
  HeartScoreResult? _result;

  @override
  void initState() {
    super.initState();
    _age = TextEditingController(text: '${widget.initialAge}');
    _riskCount = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    _age.dispose();
    _riskCount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ScorePanelShell(
      dark: widget.dark,
      title: 'HEART',
      subtitle: widget.isEs
          ? 'Historia + ECG + Edad + Factores de riesgo + Troponina. Usar dentro de una vía validada con hs-cTn, no de forma aislada.'
          : 'História + ECG + Idade + Fatores de risco + Troponina. Usar dentro de uma via validada com hs-cTn, não isoladamente.',
      child: Column(
        children: [
          _ChoiceField(
            dark: widget.dark,
            label: widget.isEs ? 'Historia' : 'História',
            value: _history,
            options: widget.isEs
                ? const [
                    '0 — poco sospechosa',
                    '1 — moderada',
                    '2 — muy sospechosa',
                  ]
                : const [
                    '0 — pouco suspeita',
                    '1 — moderada',
                    '2 — altamente suspeita',
                  ],
            onChanged: (value) => setState(() => _history = value),
          ),
          const SizedBox(height: 8),
          _ChoiceField(
            dark: widget.dark,
            label: 'ECG',
            value: _ecg,
            options: widget.isEs
                ? const [
                    '0 — normal',
                    '1 — repolarización inespecífica',
                    '2 — depresión ST significativa',
                  ]
                : const [
                    '0 — normal',
                    '1 — repolarização inespecífica',
                    '2 — depressão ST significativa',
                  ],
            onChanged: (value) => setState(() => _ecg = value),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _NumberField(
                  key: const Key('heart_age'),
                  dark: widget.dark,
                  label: widget.isEs ? 'Edad' : 'Idade',
                  controller: _age,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _NumberField(
                  key: const Key('heart_risk_count'),
                  dark: widget.dark,
                  label: widget.isEs ? 'Nº factores' : 'Nº fatores',
                  controller: _riskCount,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _CompactSwitch(
            dark: widget.dark,
            label: widget.isEs
                ? 'Aterosclerosis conocida'
                : 'Aterosclerose conhecida',
            value: _knownAscvd,
            onChanged: (value) => setState(() => _knownAscvd = value),
          ),
          const SizedBox(height: 5),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              widget.isEs
                  ? 'Factores HEART: HTA, hipercolesterolemia, diabetes, obesidad, tabaquismo y antecedente familiar de CAD.'
                  : 'Fatores HEART: HAS, hipercolesterolemia, diabetes, obesidade, tabagismo e história familiar de DAC.',
              style: TextStyle(
                color: widget.dark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B),
                fontSize: 8.7,
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _ChoiceField(
            dark: widget.dark,
            label: 'Troponina vs LSN/ULN',
            value: _troponin,
            options: widget.isEs
                ? const [
                    '0 — ≤ límite superior',
                    '1 — >1 a 3× límite',
                    '2 — >3× límite',
                  ]
                : const [
                    '0 — ≤ limite superior',
                    '1 — >1 a 3× limite',
                    '2 — >3× limite',
                  ],
            onChanged: (value) => setState(() => _troponin = value),
          ),
          const SizedBox(height: 10),
          _CalculateButton(
            key: const Key('heart_calculate'),
            label: 'CALCULAR HEART',
            onPressed: _calculate,
          ),
          if (_result != null) ...[
            const SizedBox(height: 8),
            _ScoreResultBox(
              dark: widget.dark,
              title: 'HEART ${_result!.score}/10',
              band: widget.isEs ? _result!.bandEs : _result!.bandPt,
              interpretation: widget.isEs
                  ? 'Estratificación de dolor torácico. El resultado no sustituye algoritmos seriados de hs-cTn ni la evaluación de características de alto riesgo.'
                  : 'Estratificação de dor torácica. O resultado não substitui algoritmos seriados de hs-cTn nem a avaliação de características de alto risco.',
              reference: CardioAcuteGuidelineMatrix2026.chestPain,
              onOpen: () => widget.onOpenCalculator('heart', {
                'heartScore': '${_result!.score}',
                'heartHistory': '$_history',
                'heartEcg': '$_ecg',
                'heartAge': _age.text,
                'heartRiskFactors': _riskCount.text,
                'heartKnownAscvd': _knownAscvd ? '1' : '0',
                'heartTroponin': '$_troponin',
              }),
              isEs: widget.isEs,
            ),
          ],
        ],
      ),
    );
  }

  void _calculate() {
    final age = int.tryParse(_age.text.trim());
    final riskCount = int.tryParse(_riskCount.text.trim());
    if (age == null || riskCount == null) return;
    setState(() {
      _result = CardioAcuteRiskEngine2026.heart(
        HeartScoreInput(
          historyPoints: _history,
          ecgPoints: _ecg,
          ageYears: age,
          riskFactorCount: riskCount,
          knownAtheroscleroticDisease: _knownAscvd,
          troponinPoints: _troponin,
        ),
      );
    });
  }
}

class _TimiPanel extends StatefulWidget {
  final bool isEs;
  final bool dark;
  final int initialAge;
  final CardioScoreDeeplinkCallback onOpenCalculator;

  const _TimiPanel({
    super.key,
    required this.isEs,
    required this.dark,
    required this.initialAge,
    required this.onOpenCalculator,
  });

  @override
  State<_TimiPanel> createState() => _TimiPanelState();
}

class _TimiPanelState extends State<_TimiPanel> {
  late bool _age65;
  bool _risk3 = false;
  bool _knownCad = false;
  bool _aspirin = false;
  bool _angina = false;
  bool _st = false;
  bool _markers = false;
  TimiUaNstemiResult? _result;

  @override
  void initState() {
    super.initState();
    _age65 = widget.initialAge >= 65;
  }

  @override
  Widget build(BuildContext context) {
    final items = <(String, bool, ValueChanged<bool>)>[
      (
        widget.isEs ? 'Edad ≥65' : 'Idade ≥65',
        _age65,
        (v) => setState(() => _age65 = v)
      ),
      (
        widget.isEs ? '≥3 factores CAD' : '≥3 fatores DAC',
        _risk3,
        (v) => setState(() => _risk3 = v)
      ),
      (
        widget.isEs ? 'CAD ≥50% conocida' : 'DAC ≥50% conhecida',
        _knownCad,
        (v) => setState(() => _knownCad = v)
      ),
      (
        widget.isEs ? 'AAS últimos 7 días' : 'AAS últimos 7 dias',
        _aspirin,
        (v) => setState(() => _aspirin = v)
      ),
      (
        widget.isEs ? '≥2 anginas/24 h' : '≥2 anginas/24 h',
        _angina,
        (v) => setState(() => _angina = v)
      ),
      (
        widget.isEs ? 'Desviación ST' : 'Desvio de ST',
        _st,
        (v) => setState(() => _st = v)
      ),
      (
        widget.isEs ? 'Marcadores elevados' : 'Marcadores elevados',
        _markers,
        (v) => setState(() => _markers = v)
      ),
    ];

    return _ScorePanelShell(
      dark: widget.dark,
      title: 'TIMI UA/NSTEMI',
      subtitle: widget.isEs
          ? 'Siete variables binarias para riesgo isquémico. No diagnostica SCA y no debe decidir estrategia invasiva por sí solo.'
          : 'Sete variáveis binárias para risco isquêmico. Não diagnostica SCA e não deve decidir estratégia invasiva isoladamente.',
      child: Column(
        children: [
          for (final item in items) ...[
            _CompactSwitch(
              dark: widget.dark,
              label: item.$1,
              value: item.$2,
              onChanged: item.$3,
            ),
            const SizedBox(height: 5),
          ],
          const SizedBox(height: 5),
          _CalculateButton(
            key: const Key('timi_calculate'),
            label: 'CALCULAR TIMI',
            onPressed: _calculate,
          ),
          if (_result != null) ...[
            const SizedBox(height: 8),
            _ScoreResultBox(
              dark: widget.dark,
              title: 'TIMI ${_result!.score}/7',
              band: widget.isEs ? _result!.bandEs : _result!.bandPt,
              interpretation: widget.isEs
                  ? 'Complementa la estratificación de NSTE-ACS. La guía ACS 2025 prioriza la evaluación global del riesgo isquémico y características clínicas de alto riesgo.'
                  : 'Complementa a estratificação de NSTE-ACS. A diretriz ACS 2025 prioriza avaliação global do risco isquêmico e características clínicas de alto risco.',
              reference: CardioAcuteGuidelineMatrix2026.acsUs,
              onOpen: () => widget.onOpenCalculator('timi_nstemi', {
                'timiScore': '${_result!.score}',
                'timiAge65': _age65 ? '1' : '0',
                'timiRisk3': _risk3 ? '1' : '0',
                'timiKnownCad50': _knownCad ? '1' : '0',
                'timiAspirin7d': _aspirin ? '1' : '0',
                'timiAngina24h': _angina ? '1' : '0',
                'timiStDeviation': _st ? '1' : '0',
                'timiMarkers': _markers ? '1' : '0',
              }),
              isEs: widget.isEs,
            ),
          ],
        ],
      ),
    );
  }

  void _calculate() {
    setState(() {
      _result = CardioAcuteRiskEngine2026.timiUaNstemi(
        TimiUaNstemiInput(
          age65OrMore: _age65,
          threeOrMoreCadRiskFactors: _risk3,
          knownCadStenosis50OrMore: _knownCad,
          aspirinWithin7Days: _aspirin,
          twoOrMoreAnginaEpisodes24h: _angina,
          stDeviation: _st,
          elevatedCardiacMarkers: _markers,
        ),
      );
    });
  }
}

class _GracePanel extends StatefulWidget {
  final bool isEs;
  final bool dark;
  final int initialAge;
  final int initialSbp;
  final int initialHeartRate;
  final CardioScoreDeeplinkCallback onOpenCalculator;

  const _GracePanel({
    super.key,
    required this.isEs,
    required this.dark,
    required this.initialAge,
    required this.initialSbp,
    required this.initialHeartRate,
    required this.onOpenCalculator,
  });

  @override
  State<_GracePanel> createState() => _GracePanelState();
}

class _GracePanelState extends State<_GracePanel> {
  late final TextEditingController _age;
  late final TextEditingController _hr;
  late final TextEditingController _sbp;
  late final TextEditingController _creatinine;
  int _killip = 1;
  bool _arrest = false;
  bool _st = false;
  bool _markers = false;
  GraceAdmissionResult? _result;

  @override
  void initState() {
    super.initState();
    _age = TextEditingController(text: '${widget.initialAge}');
    _hr = TextEditingController(text: '${widget.initialHeartRate}');
    _sbp = TextEditingController(text: '${widget.initialSbp}');
    _creatinine = TextEditingController();
  }

  @override
  void dispose() {
    _age.dispose();
    _hr.dispose();
    _sbp.dispose();
    _creatinine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ScorePanelShell(
      dark: widget.dark,
      title: widget.isEs
          ? 'GRACE — score de admisión'
          : 'GRACE — score de admissão',
      subtitle: widget.isEs
          ? 'Score original por puntos. ESC 2023 mantiene GRACE >140 como característica de alto riesgo en NSTE-ACS. No confundir con probabilidades GRACE 2.0.'
          : 'Score original por pontos. A ESC 2023 mantém GRACE >140 como característica de alto risco em NSTE-ACS. Não confundir com probabilidades GRACE 2.0.',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _NumberField(
                  key: const Key('grace_age'),
                  dark: widget.dark,
                  label: widget.isEs ? 'Edad' : 'Idade',
                  controller: _age,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _NumberField(
                  key: const Key('grace_hr'),
                  dark: widget.dark,
                  label: 'FC',
                  controller: _hr,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _NumberField(
                  key: const Key('grace_sbp'),
                  dark: widget.dark,
                  label: 'PAS',
                  controller: _sbp,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _NumberField(
                  key: const Key('grace_creatinine'),
                  dark: widget.dark,
                  label: 'Creat. mg/dL',
                  controller: _creatinine,
                  decimal: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ChoiceField(
            dark: widget.dark,
            label: 'Killip',
            value: _killip - 1,
            options: widget.isEs
                ? const [
                    'I — sin IC',
                    'II — congestión/S3',
                    'III — edema pulmonar',
                    'IV — shock cardiogénico',
                  ]
                : const [
                    'I — sem IC',
                    'II — congestão/B3',
                    'III — edema pulmonar',
                    'IV — choque cardiogênico',
                  ],
            onChanged: (value) => setState(() => _killip = value + 1),
          ),
          const SizedBox(height: 8),
          _CompactSwitch(
            dark: widget.dark,
            label: widget.isEs
                ? 'Paro cardíaco al ingreso'
                : 'Parada cardíaca na admissão',
            value: _arrest,
            onChanged: (v) => setState(() => _arrest = v),
          ),
          const SizedBox(height: 5),
          _CompactSwitch(
            dark: widget.dark,
            label: widget.isEs ? 'Desviación ST' : 'Desvio de ST',
            value: _st,
            onChanged: (v) => setState(() => _st = v),
          ),
          const SizedBox(height: 5),
          _CompactSwitch(
            dark: widget.dark,
            label: widget.isEs
                ? 'Marcadores cardíacos elevados'
                : 'Marcadores cardíacos elevados',
            value: _markers,
            onChanged: (v) => setState(() => _markers = v),
          ),
          const SizedBox(height: 10),
          _CalculateButton(
            key: const Key('grace_calculate'),
            label: 'CALCULAR GRACE',
            onPressed: _calculate,
          ),
          if (_result != null) ...[
            const SizedBox(height: 8),
            _ScoreResultBox(
              dark: widget.dark,
              title: 'GRACE ${_result!.points} pts',
              band: widget.isEs ? _result!.bandEs : _result!.bandPt,
              interpretation: _result!.escHighRiskAbove140
                  ? (widget.isEs
                      ? 'GRACE >140: característica de alto riesgo en NSTE-ACS según ESC 2023; integrar con diagnóstico, ECG, hs-cTn y estabilidad clínica.'
                      : 'GRACE >140: característica de alto risco em NSTE-ACS segundo ESC 2023; integrar com diagnóstico, ECG, hs-cTn e estabilidade clínica.')
                  : (widget.isEs
                      ? 'No supera el umbral >140. El riesgo no debe considerarse bajo solo por este dato.'
                      : 'Não ultrapassa o limiar >140. O risco não deve ser considerado baixo apenas por este dado.'),
              reference:
                  '${CardioAcuteGuidelineMatrix2026.acsEsc} · ${CardioAcuteGuidelineMatrix2026.grace2}',
              onOpen: () => widget.onOpenCalculator('grace', {
                'gracePoints': '${_result!.points}',
                'graceEscHighRisk': _result!.escHighRiskAbove140 ? '1' : '0',
                'graceAge': _age.text,
                'graceHr': _hr.text,
                'graceSbp': _sbp.text,
                'graceCreatinine': _creatinine.text,
                'graceKillip': '$_killip',
                'graceArrest': _arrest ? '1' : '0',
                'graceStDeviation': _st ? '1' : '0',
                'graceMarkers': _markers ? '1' : '0',
              }),
              isEs: widget.isEs,
            ),
          ],
        ],
      ),
    );
  }

  void _calculate() {
    final age = int.tryParse(_age.text.trim());
    final hr = int.tryParse(_hr.text.trim());
    final sbp = int.tryParse(_sbp.text.trim());
    final creatinine =
        double.tryParse(_creatinine.text.trim().replaceAll(',', '.'));
    if (age == null || hr == null || sbp == null || creatinine == null) return;
    setState(() {
      _result = CardioAcuteRiskEngine2026.graceAdmission(
        GraceAdmissionInput(
          ageYears: age,
          heartRateBpm: hr,
          systolicBpMmHg: sbp,
          creatinineMgDl: creatinine,
          killipClass: _killip,
          cardiacArrestAtAdmission: _arrest,
          stSegmentDeviation: _st,
          elevatedCardiacMarkers: _markers,
        ),
      );
    });
  }
}

class _KillipPanel extends StatefulWidget {
  final bool isEs;
  final bool dark;
  final CardioScoreDeeplinkCallback onOpenCalculator;

  const _KillipPanel({
    super.key,
    required this.isEs,
    required this.dark,
    required this.onOpenCalculator,
  });

  @override
  State<_KillipPanel> createState() => _KillipPanelState();
}

class _KillipPanelState extends State<_KillipPanel> {
  int _killip = 1;

  @override
  Widget build(BuildContext context) {
    final result = CardioAcuteRiskEngine2026.killip(_killip);
    return _ScorePanelShell(
      dark: widget.dark,
      title: 'Killip-Kimball',
      subtitle: widget.isEs
          ? 'Clasificación clínica pronóstica en infarto agudo de miocardio. No es un criterio diagnóstico de IAM.'
          : 'Classificação clínica prognóstica no infarto agudo do miocárdio. Não é critério diagnóstico de IAM.',
      child: Column(
        children: [
          _ChoiceField(
            dark: widget.dark,
            label: widget.isEs ? 'Clase' : 'Classe',
            value: _killip - 1,
            options: widget.isEs
                ? const [
                    'I — sin IC',
                    'II — congestión/S3',
                    'III — edema pulmonar',
                    'IV — shock cardiogénico',
                  ]
                : const [
                    'I — sem IC',
                    'II — congestão/B3',
                    'III — edema pulmonar',
                    'IV — choque cardiogênico',
                  ],
            onChanged: (value) => setState(() => _killip = value + 1),
          ),
          const SizedBox(height: 8),
          _ScoreResultBox(
            dark: widget.dark,
            title: widget.isEs ? result.labelEs : result.labelPt,
            band: widget.isEs ? 'Pronóstico' : 'Prognóstico',
            interpretation: widget.isEs ? result.meaningEs : result.meaningPt,
            reference: CardioAcuteGuidelineMatrix2026.acsUs,
            onOpen: () => widget.onOpenCalculator('killip', {
              'killipClass': '$_killip',
            }),
            isEs: widget.isEs,
          ),
        ],
      ),
    );
  }
}

class _ChoiceField extends StatelessWidget {
  final bool dark;
  final String label;
  final int value;
  final List<String> options;
  final ValueChanged<int> onChanged;

  const _ChoiceField({
    required this.dark,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final text = dark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final border = dark ? const Color(0xFF374151) : const Color(0xFFE2E7EC);
    return DropdownButtonFormField<int>(
      key: ValueKey<String>('choice-$label-$value'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: text, fontSize: 10),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(color: border, width: 0.7),
        ),
      ),
      dropdownColor: dark ? const Color(0xFF1F2937) : Colors.white,
      style: TextStyle(color: text, fontSize: 10),
      items: List.generate(
        options.length,
        (index) => DropdownMenuItem<int>(
          value: index,
          child: Text(
            options[index],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }
}

class _NumberField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool dark;
  final bool decimal;

  const _NumberField({
    super.key,
    required this.label,
    required this.controller,
    required this.dark,
    this.decimal = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = dark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final border = dark ? const Color(0xFF374151) : const Color(0xFFE2E7EC);
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      style: TextStyle(color: text, fontSize: 11, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: text, fontSize: 9.5),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(color: border, width: 0.7),
        ),
      ),
    );
  }
}

class _CompactSwitch extends StatelessWidget {
  final bool dark;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CompactSwitch({
    required this.dark,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final text = dark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final border = dark ? const Color(0xFF374151) : const Color(0xFFE2E7EC);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: border, width: 0.7),
        borderRadius: BorderRadius.circular(9),
      ),
      padding: const EdgeInsets.fromLTRB(9, 4, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: text,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            activeThumbColor: const Color(0xFF009C3B),
            activeTrackColor: const Color(0x33009C3B),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _CalculateButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _CalculateButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 40,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF009C3B),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.35,
          ),
        ),
      ),
    );
  }
}

class _ScoreResultBox extends StatelessWidget {
  final bool dark;
  final bool isEs;
  final String title;
  final String band;
  final String interpretation;
  final String reference;
  final VoidCallback onOpen;

  const _ScoreResultBox({
    required this.dark,
    required this.isEs,
    required this.title,
    required this.band,
    required this.interpretation,
    required this.reference,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF111827) : const Color(0xFFF8FAFC);
    final text = dark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final sub = dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    return Container(
      key: const Key('score_result_box'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: text,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x1A009C3B),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  band,
                  style: const TextStyle(
                    color: Color(0xFF009C3B),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            interpretation,
            style: TextStyle(color: sub, fontSize: 9.8, height: 1.35),
          ),
          const SizedBox(height: 6),
          Text(
            reference,
            style: TextStyle(
              color: sub,
              fontSize: 8.7,
              height: 1.25,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 36,
            child: OutlinedButton.icon(
              key: const Key('score_open_calculator'),
              onPressed: onOpen,
              icon: const Icon(Icons.open_in_new_rounded, size: 15),
              label: Text(
                isEs ? 'ABRIR SOPORTE CLÍNICO' : 'ABRIR SUPORTE CLÍNICO',
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF009C3B),
                side: const BorderSide(color: Color(0xFF009C3B), width: 0.8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
