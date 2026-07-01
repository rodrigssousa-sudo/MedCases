// ══════════════════════════════════════════════════════════════════════════════
// reference_screens.dart — Dashboard de Referências Clínicas
//
// Arquitetura: Dashboard Grid (2 colunas) + 4 telas filhas via Navigator.push.
// Dark/Light: 100% adaptativo via AppColors.of(context) — ZERO cores fixas escuras.
// i18n: ES / PT via AppProvider.lang — todas as strings passam por isEs.
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/common_widgets.dart';
import '../widgets/medcases_webview_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DASHBOARD GRID — tela raiz da aba REFERÊNCIAS
// ─────────────────────────────────────────────────────────────────────────────
class ReferenceDashboard extends StatelessWidget {
  const ReferenceDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final p   = context.watch<AppProvider>();
    final isEs = p.lang == 'es';
    final c   = AppColors.of(context);

    final cards = [
      _RefCardData(
        icon: Icons.biotech_outlined,
        titlePt: 'Valores de\nLaboratório',
        titleEs: 'Valores de\nLaboratorio',
        subtitlePt: 'Hemograma, bioquímica,\nurinálise e mais',
        subtitleEs: 'Hemograma, bioquímica,\nurinálisis y más',
        color: const Color(0xFFDC2626),
        screen: const LabsReferenceScreen(),
      ),
      _RefCardData(
        icon: Icons.monitor_heart_outlined,
        titlePt: 'Eletro-\ncardiograma',
        titleEs: 'Electro-\ncardiograma',
        subtitlePt: 'Intervalos, padrões\nde urgência e coronários',
        subtitleEs: 'Intervalos, patrones\nurgentes y coronarios',
        color: const Color(0xFF2563EB),
        screen: const EcgReferenceScreen(),
      ),
      _RefCardData(
        icon: Icons.medical_services_outlined,
        titlePt: 'Antídotos\ne Toxinas',
        titleEs: 'Antídotos\ny Toxinas',
        subtitlePt: 'Doses, indicações\ne prioridades clínicas',
        subtitleEs: 'Dosis, indicaciones\ny prioridades clínicas',
        color: const Color(0xFF059669),
        screen: const AntidotosReferenceScreen(),
      ),
      _RefCardData(
        icon: Icons.hub_outlined,
        titlePt: 'Acessos e\nProcedimentos',
        titleEs: 'Accesos y\nProcedimientos',
        subtitlePt: 'CVC, calibres e\npressões de referência',
        subtitleEs: 'CVC, calibres y\npresiones de referencia',
        color: const Color(0xFF7C3AED),
        screen: const AcessoReferenceScreen(),
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cabeçalho da seção ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEs ? 'Referencias Clínicas' : 'Referências Clínicas',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: c.textPrimary,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isEs
                      ? 'Seleccione una categoría para consultar'
                      : 'Selecione uma categoria para consultar',
                  style: TextStyle(
                    fontSize: 13,
                    color: c.textHint,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          // ── Grid 2 colunas ──────────────────────────────────────────────
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cards.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.88,
            ),
            itemBuilder: (context, i) {
              final card = cards[i];
              return _RefGridCard(
                data: card,
                isEs: isEs,
                onTap: () {
                  AppHaptics.selection(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => card.screen),
                  );
                },
              );
            },
          ),

          const SizedBox(height: 28),
          _SourcesButton(isEs: isEs),
        ],
      ),
    );
  }
}

// ── Modelo de dados do card do grid ────────────────────────────────────────
class _RefCardData {
  final IconData icon;
  final String titlePt, titleEs, subtitlePt, subtitleEs;
  final Color color;
  final Widget screen;
  const _RefCardData({
    required this.icon,
    required this.titlePt,
    required this.titleEs,
    required this.subtitlePt,
    required this.subtitleEs,
    required this.color,
    required this.screen,
  });
}

// ── Card individual do grid ─────────────────────────────────────────────────
class _RefGridCard extends StatelessWidget {
  final _RefCardData data;
  final bool isEs;
  final VoidCallback onTap;

  const _RefGridCard({
    required this.data,
    required this.isEs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final color = data.color;
    final title = isEs ? data.titleEs : data.titlePt;
    final subtitle = isEs ? data.subtitleEs : data.subtitlePt;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(c.dark ? 0.15 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ícone
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(data.icon, size: 22, color: color),
            ),
            const SizedBox(height: 14),

            // Título
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: c.textPrimary,
                height: 1.25,
                letterSpacing: -0.2,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),

            // Subtítulo
            Expanded(
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: c.textHint,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Chevron
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 15,
                  color: color.withOpacity(0.7),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BASE: AppBar limpa para todas as telas filhas
// extendBodyBehindAppBar: false — sem sobreposição, 100% do espaço para dados.
// ─────────────────────────────────────────────────────────────────────────────
class _RefAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String titlePt;
  final String titleEs;
  final bool isEs;
  final Color accentColor;

  const _RefAppBar({
    required this.titlePt,
    required this.titleEs,
    required this.isEs,
    required this.accentColor,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppBar(
      backgroundColor: c.cardBg,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: c.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      leading: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: c.textPrimary,
          ),
        ),
      ),
      title: Text(
        isEs ? titleEs : titlePt,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: c.textPrimary,
          letterSpacing: -0.3,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: c.border),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 1. LABS — Valores de Laboratório
// ══════════════════════════════════════════════════════════════════════════════
class LabsReferenceScreen extends StatelessWidget {
  const LabsReferenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p    = context.watch<AppProvider>();
    final isEs = p.lang == 'es';
    final c    = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffoldBg,
      appBar: _RefAppBar(
        titlePt: 'Valores de Laboratório',
        titleEs: 'Valores de Laboratorio',
        isEs: isEs,
        accentColor: const Color(0xFFDC2626),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── HEMOGRAMA ──────────────────────────────────────────────────
            _LabSection(
              title: isEs ? 'Hemograma' : 'Hemograma',
              icon: Icons.bloodtype_outlined,
              accent: const Color(0xFFDC2626),
              note: isEs
                  ? 'Los valores de referencia pueden variar según el laboratorio y la población.'
                  : 'Os valores de referência podem variar conforme o laboratório e a população.',
              items: [
                _LabItem('Hemoglobina',     'H: 13,5–17,5 / M: 12,0–15,5', 'g/dL', _LabSt.normal),
                _LabItem('Hematócrito',     'H: 41–53 / M: 36–46',           '%',   _LabSt.normal),
                _LabItem('Leucócitos',      '4.000–11.000',                  '/mm³', _LabSt.normal),
                _LabItem(isEs ? 'Neutrófilos'   : 'Neutrófilos',    '1.500–7.700',    '/mm³', _LabSt.alert,
                    note: '>70% → sepse?'),
                _LabItem('Linfócitos',      '1.000–4.800',  '/mm³', _LabSt.normal,
                    note: '<1000 linfopenia'),
                _LabItem('Plaquetas',       '150k–400k',    '/mm³', _LabSt.alert,
                    note: isEs ? '<50k riesgo sangrado' : '<50k risco sangrado'),
                _LabItem('VCM',             '80–100',        'fL',  _LabSt.normal,
                    note: '<80 micro; >100 macro'),
                _LabItem('RDW',             '<14,5',         '%',   _LabSt.normal,
                    note: isEs ? '>14,5%: anemia carencial' : '>14,5%: anemia carencial'),
              ],
            ),
            const SizedBox(height: 16),

            // ── BIOQUÍMICA ─────────────────────────────────────────────────
            _LabSection(
              title: isEs ? 'Bioquímica' : 'Bioquímica',
              icon: Icons.science_outlined,
              accent: const Color(0xFFD97706),
              items: [
                _LabItem(isEs ? 'Glicemia ayuno' : 'Glicemia jejum', '70–99', 'mg/dL', _LabSt.normal,
                    note: isEs ? '<70 hipoglucemia; >126 DM' : '<70 hipoglicemia; >126 DM'),
                _LabItem('Ureia',           '15–45',        'mg/dL', _LabSt.normal, note: '>45 azotemia'),
                _LabItem('Creatinina',      'H: 0,7–1,2 / M: 0,5–1,0', 'mg/dL', _LabSt.normal),
                _LabItem('Sódio (Na+)',     '135–145',      'mEq/L', _LabSt.alert,
                    note: '<135 hipo; >145 hiper'),
                _LabItem('Potássio (K+)',   '3,5–5,0',      'mEq/L', _LabSt.critical,
                    note: isEs ? '>5,5 EMERGENCIA' : '>5,5 EMERGÊNCIA'),
                _LabItem('Cálcio total',    '8,5–10,5',     'mg/dL', _LabSt.alert,
                    note: '<7 crise hipocalcêmica'),
                _LabItem('Magnésio',        '1,7–2,2',      'mg/dL', _LabSt.alert,
                    note: '<1,5 arritmias'),
                _LabItem('Bilirrubina tot.','<1,2',         'mg/dL', _LabSt.normal,
                    note: isEs ? '>5 ictericia' : '>5 icterícia'),
                _LabItem('TGO (AST)',       '<40',           'U/L',  _LabSt.normal,
                    note: '>3× LSN hepatocelular'),
                _LabItem('TGP (ALT)',       '<41',           'U/L',  _LabSt.normal,
                    note: '>10× LSN hepatite aguda'),
                _LabItem('PCR',             '<0,5',         'mg/dL', _LabSt.alert,
                    note: '>10 inflamação signif.'),
                _LabItem('Procalcitonina',  '<0,1',         'ng/mL', _LabSt.alert,
                    note: '>0,5 ATB; >2 bacteremia'),
                _LabItem('Lactato',         '<2,0',         'mmol/L', _LabSt.critical,
                    note: isEs ? '>4 crítico' : '>4 crítico'),
                _LabItem('Troponina I',     '<0,04',        'ng/mL', _LabSt.alert,
                    note: isEs ? 'SCA: ↑ + clínica' : 'SCA: ↑ + clínica'),
                _LabItem('D-Dímero',        '<500',         'ng/mL', _LabSt.alert,
                    note: isEs ? '>500 rastreo TEP/TVP' : '>500 rastreio TEP/TVP'),
                _LabItem('INR / TP',        '0,8–1,2',      '/ 11–14s', _LabSt.normal,
                    note: '>1,5 coagulopatia'),
                _LabItem('TSH',             '0,3–4,5',      'mUI/L', _LabSt.normal,
                    note: '<0,1 hiper; >10 hipo'),
                _LabItem('HbA1c',           '<5,7%',        '',      _LabSt.normal,
                    note: '≥6,5% = DM'),
              ],
            ),
            const SizedBox(height: 16),

            // ── URINÁLISE ──────────────────────────────────────────────────
            _LabSection(
              title: isEs ? 'Urinálisis' : 'Urinálise',
              icon: Icons.water_drop_outlined,
              accent: const Color(0xFF2563EB),
              items: [
                _LabItem('Leucócitos',  '<5/campo',    '', _LabSt.alert,
                    note: isEs ? '>5 piuria (ITU)' : '>5 piúria (ITU)'),
                _LabItem('Hemácias',    '<2/campo',    '', _LabSt.alert,
                    note: '>5 hematúria'),
                _LabItem('Proteína',    'Traços/neg.', '', _LabSt.normal,
                    note: '>300 mg/24h proteinúria'),
                _LabItem('Glicose',     isEs ? 'Negativo' : 'Negativo', '', _LabSt.normal,
                    note: isEs ? 'Positivo: hiperglucemia/SGLT2' : 'Positivo: hiperglicemia/SGLT2'),
                _LabItem('Nitrito',     isEs ? 'Negativo' : 'Negativo', '', _LabSt.alert,
                    note: 'Positivo: gram-neg (ITU)'),
                _LabItem('Densidade',   '1,001–1,035', '', _LabSt.normal,
                    note: '<1,005 hipost; >1,030 desidrat.'),
              ],
            ),

            const SizedBox(height: 28),
            _SourcesButton(isEs: isEs),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 2. ECG — Eletrocardiograma
// ══════════════════════════════════════════════════════════════════════════════
class EcgReferenceScreen extends StatelessWidget {
  const EcgReferenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p    = context.watch<AppProvider>();
    final isEs = p.lang == 'es';
    final c    = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffoldBg,
      appBar: _RefAppBar(
        titlePt: 'Eletrocardiograma',
        titleEs: 'Electrocardiograma',
        isEs: isEs,
        accentColor: const Color(0xFF2563EB),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Intervalos Normais ─────────────────────────────────────────
            _RefSectionCard(
              title: isEs ? 'Intervalos Normales' : 'Intervalos Normais',
              icon: Icons.monitor_heart_outlined,
              accentColor: const Color(0xFF2563EB),
              child: _EcgTable(isEs: isEs),
            ),
            const SizedBox(height: 16),

            // ── Padrões de Urgência ────────────────────────────────────────
            _RefSectionCard(
              title: isEs ? 'Patrones ECG Urgentes' : 'Padrões ECG de Urgência',
              icon: Icons.warning_amber_rounded,
              accentColor: const Color(0xFFDC2626),
              child: Column(children: [
                _EcgPatternCard(
                  pattern: 'IAMCSST',
                  desc: isEs
                      ? 'Supra ST ≥1mm em ≥2 derivações contíguas (≥2mm em V1–V4). Novo BCRE. Reperfusão emergente.'
                      : 'Supra ST ≥1mm em ≥2 derivações contíguas (≥2mm em V1–V4). Novo BCRE. Reperfusão emergente.',
                  severity: _EcgSeverity.critical,
                ),
                _EcgPatternCard(
                  pattern: 'Torsades de Pointes',
                  desc: isEs
                      ? 'TV polimórfica, QTc prolongado. Causa: hipocalemia, hipoMg, QT-prolongadores. Tto: MgSO4 2g IV.'
                      : 'TV polimórfica, QTc prolongado. Causa: hipocalemia, hipoMg, drogas. Tto: MgSO4 2g IV.',
                  severity: _EcgSeverity.critical,
                ),
                _EcgPatternCard(
                  pattern: 'Hiperpotassemia',
                  desc: isEs
                      ? 'Progressão: ondas T picudas → PR largo → QRS ancho → sinusoidal → FV. Gluconato Ca2+ urgente.'
                      : 'Progressão: T apiculadas → PR longo → QRS largo → padrão sinusoidal → FV. Gluconato Ca2+ urgente.',
                  severity: _EcgSeverity.critical,
                ),
                _EcgPatternCard(
                  pattern: isEs ? 'Fibrilación Auricular' : 'Fibrilação Atrial',
                  desc: isEs
                      ? 'Ritmo irregularmente irregular, sin ondas P. CHA2DS2-VASc para anticoagulación. FC objetivo <110 lpm.'
                      : 'Ritmo irregularmente irregular, sem ondas P. CHA2DS2-VASc para anticoagulação. FC alvo <110 bpm.',
                  severity: _EcgSeverity.alert,
                ),
                _EcgPatternCard(
                  pattern: isEs ? 'TEP (patrón S1Q3T3)' : 'TEP (padrão S1Q3T3)',
                  desc: isEs
                      ? 'S profunda em D1, Q e T invertida em D3. Taquicardia sinusal + BCRD novo = alta suspeita.'
                      : 'S profunda em D1, Q e T invertida em D3. Taquicardia sinusal + BCRD novo = alta suspeita.',
                  severity: _EcgSeverity.alert,
                ),
                _EcgPatternCard(
                  pattern: isEs ? 'BAV Total (3° grado)' : 'BAV Total (3° grau)',
                  desc: isEs
                      ? 'Dissociação AV completa. Escape juncional (FC 40–60) ou ventricular (FC 20–40). Atropina + MP urgente.'
                      : 'Dissociação AV completa. Escape juncional (FC 40–60) ou ventricular (FC 20–40). Atropina + MP urgente.',
                  severity: _EcgSeverity.critical,
                ),
                _EcgPatternCard(
                  pattern: isEs ? 'Hipocalemia' : 'Hipocalemia',
                  desc: isEs
                      ? 'Achatamiento/inversión onda T, ondas U prominentes, QTc prolongado. KCl IV urgente si K+ <2,5.'
                      : 'Achatamento/inversão onda T, ondas U proeminentes, QTc prolongado. KCl IV urgente se K+ <2,5.',
                  severity: _EcgSeverity.alert,
                ),
              ]),
            ),
            const SizedBox(height: 16),

            // ── Territórios Coronários ─────────────────────────────────────
            _RefSectionCard(
              title: isEs ? 'Territorios Coronarios' : 'Territórios Coronários',
              icon: Icons.favorite_outlined,
              accentColor: const Color(0xFFDC2626),
              child: Column(children: [
                _EcgRow(sigla: 'DA', ref: 'V1–V4 + aVL',
                    note: isEs ? 'ADA: paredes anterior e septal' : 'ADA: paredes anterior e septal'),
                _EcgRow(sigla: 'Cx', ref: 'I, aVL, V5–V6',
                    note: isEs ? 'Arteria circunfleja' : 'Artéria circunflexa'),
                _EcgRow(sigla: 'CD', ref: 'II, III, aVF',
                    note: isEs ? 'Considerar IAM VD: V3R-V4R' : 'Considerar IAM VD: V3R-V4R'),
                _EcgRow(sigla: isEs ? 'Post.' : 'Post.',
                    ref: isEs ? 'V7–V9 (espejo V1-V3)' : 'V7–V9 (espelho V1-V3)',
                    note: isEs ? 'Infra ST anterior = supra posterior' : 'Infra ST anterior = supra posterior'),
              ]),
            ),

            const SizedBox(height: 28),
            _SourcesButton(isEs: isEs),
          ],
        ),
      ),
    );
  }
}

// Tabela limpa de intervalos ECG
class _EcgTable extends StatelessWidget {
  final bool isEs;
  const _EcgTable({required this.isEs});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final rows = [
      ['FC',   '60–100 bpm',       isEs ? '<60 bradicardia; >100 taquicardia' : '<60 bradicardia; >100 taquicardia'],
      ['PR',   '120–200 ms',       isEs ? '>200 ms = BAV 1°' : '>200 ms = BAV 1°'],
      ['QRS',  '<120 ms',          isEs ? '>120 ms = bloqueio de ramo' : '>120 ms = bloqueio de ramo'],
      ['QTc',  'H <440 / M <460 ms', isEs ? '>500 ms = risco Torsades' : '>500 ms = risco Torsades'],
      ['Eixo', '-30° a +90°',      isEs ? 'Desvio E: HVE/BCRE; D: TEP/BCRD' : 'Desvio E: HVE/BCRE; D: TEP/BCRD'],
    ];

    return Column(
      children: rows.map((r) {
        final hasAlert = r[2].contains('>') || r[2].contains('risco') || r[2].contains('riesgo');
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: c.dark
                ? Colors.white.withOpacity(0.03)
                : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: hasAlert
                  ? const Color(0xFFD97706).withOpacity(0.25)
                  : c.border,
            ),
          ),
          child: Row(children: [
            // Sigla
            SizedBox(
              width: 48,
              child: Text(r[0],
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: c.textPrimary,
                )),
            ),
            // Valor
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r[1],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2563EB),
                  )),
                const SizedBox(height: 2),
                Text(r[2],
                  style: TextStyle(
                    fontSize: 11,
                    color: hasAlert ? const Color(0xFFB45309) : c.textSecondary,
                    height: 1.3,
                  )),
              ]),
            ),
            // Ícone alerta
            if (hasAlert)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    size: 13, color: Color(0xFFD97706)),
              ),
          ]),
        );
      }).toList(),
    );
  }
}

enum _EcgSeverity { critical, alert }

class _EcgPatternCard extends StatelessWidget {
  final String pattern, desc;
  final _EcgSeverity severity;
  const _EcgPatternCard({required this.pattern, required this.desc, required this.severity});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final color = severity == _EcgSeverity.critical
        ? const Color(0xFFCC2222)
        : const Color(0xFFB45309);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: c.dark
            ? color.withOpacity(0.06)
            : color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(
            severity == _EcgSeverity.critical
                ? Icons.error_outline_rounded
                : Icons.warning_amber_outlined,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(pattern,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: color,
              )),
          ),
        ]),
        const SizedBox(height: 6),
        Text(desc,
          style: TextStyle(
            fontSize: 11.5,
            color: c.textSecondary,
            height: 1.45,
          )),
      ]),
    );
  }
}

class _EcgRow extends StatelessWidget {
  final String sigla, ref, note;
  const _EcgRow({required this.sigla, required this.ref, required this.note});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.dark ? Colors.white.withOpacity(0.03) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Row(children: [
        SizedBox(
          width: 52,
          child: Text(sigla,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: c.textPrimary)),
        ),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ref,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.green)),
          const SizedBox(height: 2),
          Text(note,
            style: TextStyle(fontSize: 10.5, color: c.textSecondary, height: 1.3)),
        ])),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 3. ANTÍDOTOS — Antídotos e Toxinas
// ══════════════════════════════════════════════════════════════════════════════
class AntidotosReferenceScreen extends StatelessWidget {
  const AntidotosReferenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p    = context.watch<AppProvider>();
    final isEs = p.lang == 'es';
    final c    = AppColors.of(context);

    final antidotes = _antidoteData(isEs);

    return Scaffold(
      backgroundColor: c.scaffoldBg,
      appBar: _RefAppBar(
        titlePt: 'Antídotos e Toxinas',
        titleEs: 'Antídotos y Toxinas',
        isEs: isEs,
        accentColor: const Color(0xFF059669),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RefSectionCard(
              title: isEs ? 'Antídotos Clínicos Esenciales' : 'Antídotos Clínicos Essenciais',
              icon: Icons.medical_services_outlined,
              accentColor: const Color(0xFF059669),
              child: Column(
                children: antidotes
                    .map((a) => _AntidoteCard(
                          toxin: a[0],
                          antidote: a[1],
                          dose: a[2],
                          level: a[3],
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 28),
            _SourcesButton(isEs: isEs),
          ],
        ),
      ),
    );
  }

  static List<List<String>> _antidoteData(bool isEs) => [
    ['Paracetamol', 'N-Acetilcisteína',
     isEs ? '150 mg/kg IV em 60 min, depois 50 mg/kg em 4h, depois 100 mg/kg em 16h. Usar nomograma Rumack-Matthew.'
          : '150 mg/kg IV em 60 min, depois 50 mg/kg em 4h, depois 100 mg/kg em 16h. Nomograma Rumack-Matthew.',
     'MOD'],
    ['Opioides', 'Naloxona',
     isEs ? '0,4–2 mg IV/IM/SC a cada 2–3 min. Duração 30–90 min (< que morfina) — repetir ou infusão.'
          : '0,4–2 mg IV/IM/SC a cada 2–3 min. Duração 30–90 min (< que morfina) — repetir ou infusão contínua.',
     'ALTO'],
    ['Benzodiazepínicos', 'Flumazenil',
     isEs ? '0,2 mg IV em 30s; repetir 0,1 mg/min; máx. 1 mg. CUIDADO: convulsões em dependentes crônicos.'
          : '0,2 mg IV em 30s; repetir 0,1 mg/min; máx. 1 mg. CUIDADO: convulsões em dependentes crônicos.',
     'MOD'],
    ['Digoxina', 'Anticorpos anti-Digoxina (Digibind)',
     isEs ? '80 mg IV neutraliza 1 mg digoxina. Indicação: K+ >5, arritmias ameaçadoras.'
          : '80 mg IV neutraliza 1 mg digoxina. Indicação: K+ >5, arritmias ameaçadoras.',
     'ALTO'],
    ['Heparina NF', 'Sulfato de Protamina',
     isEs ? '1 mg neutraliza 100 UI HNF. IV lento em 10 min (hipotensão). Máx. 50 mg/dose.'
          : '1 mg neutraliza 100 UI HNF. IV lento em 10 min (hipotensão). Máx. 50 mg/dose.',
     'MOD'],
    ['Warfarina', 'Vitamina K + PFC/CCP',
     isEs ? 'INR >10 sem sangrado: Vit K 2,5–5 mg VO. Com sangrado grave: CCP 25–50 UI/kg IV + Vit K 5–10 mg IV.'
          : 'INR >10 sem sangrado: Vit K 2,5–5 mg VO. Com sangrado grave: CCP 25–50 UI/kg IV + Vit K 5–10 mg IV.',
     'ALTO'],
    ['Rivaroxabana/Apixabana', 'Andexanet alfa',
     isEs ? '400–800 mg IV bolo + infusão. Alto custo. Alternativa: CCP 4 fatores 25–50 UI/kg.'
          : '400–800 mg IV bolo + infusão. Alto custo. Alternativa: CCP 4 fatores 25–50 UI/kg.',
     'ALTO'],
    ['Dabigatrana', 'Idarucizumabe',
     isEs ? '5 g IV (2 frascos de 2,5 g). Reversão completa e imediata.'
          : '5 g IV (2 frascos de 2,5 g). Reversão completa e imediata.',
     'ALTO'],
    ['Organofosforados', 'Atropina + Pralidoxima',
     isEs ? 'Atropina 2–4 mg IV (titular pelos secretos). Pralidoxima 1–2 g IV em 30 min. Repetir atropina até secar secreções.'
          : 'Atropina 2–4 mg IV (titular pelos secretos). Pralidoxima 1–2 g IV em 30 min. Titular atropina até secar secreções.',
     'ALTO'],
    ['Metanol/Etilenoglicol', 'Fomepizole + Hemodiálise',
     isEs ? 'Fomepizol 15 mg/kg IV + hemodiálise urgente. Etanol 10% IV como alternativa.'
          : 'Fomepizol 15 mg/kg IV + hemodiálise urgente. Etanol 10% IV como alternativa.',
     'ALTO'],
    ['Cianeto', 'Hidroxocobalamina',
     isEs ? '5 g IV em 15 min. Alternativa: Nitrito de amila (inalação) + Tiosulfato de sódio 12,5 g IV.'
          : '5 g IV em 15 min. Alternativa: Nitrito de amila (inalação) + Tiosulfato de sódio 12,5 g IV.',
     'ALTO'],
    ['Monóxido de Carbono', 'O₂ 100% / Hiperbárica',
     isEs ? 'O2 100% máscara NRB até COHb <5%. Hiperbárica se: COHb >25%, gestante, inconsciente, cardíaco.'
          : 'O2 100% máscara NRB até COHb <5%. Câmara hiperbárica se: COHb >25%, gestante, coma, cardiopata.',
     'ALTO'],
    ['Antidepressivos Tricíclicos', 'Bicarbonato de Sódio',
     isEs ? 'NaHCO3 1–2 mEq/kg IV se QRS >120ms. Meta: pH 7,45–7,55. Diazepam nas convulsões.'
          : 'NaHCO3 1–2 mEq/kg IV se QRS >120ms. Meta: pH 7,45–7,55. Diazepam nas convulsões.',
     'ALTO'],
    ['Hiperpotassemia', 'Gluconato de Cálcio',
     isEs ? '1 g IV em 2 min (estabiliza membrana). Insulina 10 UI + Glicose 50% para shift intracelular.'
          : '1 g IV em 2 min (estabiliza membrana). Insulina 10 UI + Glicose 50% para shift intracelular.',
     'ALTO'],
    ['Hipoglicemia', 'Glicose 50% IV / Glucagon',
     isEs ? 'Glicose 50%: 50 mL IV. Glucagon 1 mg IM/SC se sem acesso. SNG: suco de laranja.'
          : 'Glicose 50%: 50 mL IV. Glucagon 1 mg IM/SC se sem acesso. VO: suco de laranja/mel.',
     'ALTO'],
    ['β-Bloqueadores', 'Glucagon + Emulsão Lipídica',
     isEs ? 'Glucagon 3–10 mg IV bolo + 3–10 mg/h infusão. Emulsão lipídica 20%: 1,5 mL/kg IV bolo.'
          : 'Glucagon 3–10 mg IV bolo + 3–10 mg/h infusão. Emulsão lipídica 20%: 1,5 mL/kg IV bolo.',
     'MOD'],
    ['Bloq. Canal de Cálcio', 'Cálcio IV + Insulina Alta Dose',
     isEs ? 'CaCl2 1–2 g IV. Insulina 1 UI/kg/h + Glicose. Emulsão lipídica 20% se refratário.'
          : 'CaCl2 1–2 g IV. Insulina 1 UI/kg/h + Glicose. Emulsão lipídica 20% se refratário.',
     'MOD'],
  ];
}

class _AntidoteCard extends StatelessWidget {
  final String toxin, antidote, dose, level;
  const _AntidoteCard({
    required this.toxin,
    required this.antidote,
    required this.dose,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isAlto = level == 'ALTO';
    final levelColor = isAlto ? const Color(0xFFCC2222) : const Color(0xFFC5A365);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: c.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          // Badge de prioridade padronizado (mesma largura)
          Container(
            width: 40,
            padding: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              color: levelColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Text(level,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
                color: levelColor,
              )),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(toxin,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: c.textPrimary,
              )),
          ),
        ]),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF059669).withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(antidote,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF059669),
            )),
        ),
        const SizedBox(height: 8),
        Text(dose,
          style: TextStyle(
            fontSize: 11.5,
            color: c.textSecondary,
            height: 1.5,
          )),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 4. ACESSO — Acessos e Procedimentos
// ══════════════════════════════════════════════════════════════════════════════
class AcessoReferenceScreen extends StatelessWidget {
  const AcessoReferenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p    = context.watch<AppProvider>();
    final isEs = p.lang == 'es';
    final c    = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffoldBg,
      appBar: _RefAppBar(
        titlePt: 'Acessos e Procedimentos',
        titleEs: 'Accesos y Procedimientos',
        isEs: isEs,
        accentColor: const Color(0xFF7C3AED),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── CVC ────────────────────────────────────────────────────────
            _RefSectionCard(
              title: isEs
                  ? 'Catéter Venoso Central — Localización'
                  : 'Acesso Venoso Central — Localização',
              icon: Icons.hub_outlined,
              accentColor: const Color(0xFF7C3AED),
              child: Column(children: [
                _AccessCardRow(
                  site: isEs ? 'Jugular Interna D' : 'Jugular Interna D',
                  pros: isEs ? 'Fácil, baixo PTX, pulmão D maior' : 'Fácil, baixo PTX, pulmão D maior',
                  cons: isEs ? 'Artéria carótida próxima' : 'Artéria carótida próxima',
                ),
                _AccessCardRow(
                  site: isEs ? 'Subclávio' : 'Subclávio',
                  pros: isEs ? 'Confortável, baixa infecção' : 'Confortável, baixa infecção',
                  cons: isEs ? 'Alto risco PTX, hemotórax' : 'Alto risco PTX, hemotórax',
                ),
                _AccessCardRow(
                  site: 'Femoral',
                  pros: isEs ? 'Fácil, rápido, sin PTX' : 'Fácil, rápido, sem PTX',
                  cons: isEs ? 'Alta infección, TVP, no ideal en RCP' : 'Alta infecção, TVP, não ideal PCR',
                  isLast: true,
                ),
                const SizedBox(height: 12),
                // Banner de aviso — cores adaptativas dark/light
                _AdvisoryBanner(
                  text: isEs
                      ? 'Confirmar posição com Rx tórax antes de usar. Ponta ideal: junção cava superior-átrio direito. Eco point-of-care facilita.'
                      : 'Confirmar posição com Rx tórax antes de usar. Ponta ideal: junção cava superior-átrio direito. Eco point-of-care facilita.',
                ),
              ]),
            ),
            const SizedBox(height: 16),

            // ── Calibre por Situação ───────────────────────────────────────
            _RefSectionCard(
              title: isEs ? 'Tamaño de Catéter por Situación' : 'Calibre de Cateter por Situação',
              icon: Icons.linear_scale_rounded,
              accentColor: const Color(0xFF7C3AED),
              child: Column(children: [
                _CvcRow(name: isEs ? 'Resucitación' : 'Ressuscitação',     ref: '14–16 G periférico',
                    note: isEs ? '2 accesos cortos y gruesos > 1 central' : '2 acessos curtos e grossos > 1 central'),
                _CvcRow(name: isEs ? 'Vasopressor' : 'Vasopressor',         ref: 'CVC (3 lumens)',
                    note: isEs ? 'Preferir subclavia/yugular interna' : 'Preferir subclávia/jugular interna'),
                _CvcRow(name: isEs ? 'Transfusão rápida' : 'Transfusão rápida', ref: '14–16 G + introdutor 8,5Fr',
                    note: isEs ? 'Introdutor = fluxo máximo' : 'Introdutor = maior fluxo'),
                _CvcRow(name: isEs ? 'Nutrição parenteral' : 'Nutrição parenteral', ref: 'PICC ou CVC',
                    note: isEs ? 'Osmolaridade > 900 mOsm = central' : 'Osmolaridade > 900 mOsm = central'),
                _CvcRow(name: isEs ? 'Hemodiálise' : 'Hemodiálise', ref: 'Cateter duplo-lúmen 11–13Fr',
                    note: isEs ? 'Jugular D > femoral > subclávia' : 'Jugular D > femoral > subclávia'),
              ]),
            ),
            const SizedBox(height: 16),

            // ── Pressões Invasivas ─────────────────────────────────────────
            _RefSectionCard(
              title: isEs ? 'Presiones de Referencia — Invasivo' : 'Pressões de Referência — Invasivo',
              icon: Icons.speed_outlined,
              accentColor: const Color(0xFF7C3AED),
              child: Column(children: [
                _CvcRow(name: 'PAM',       ref: '70–105 mmHg',  note: isEs ? 'Meta ≥65 no choque' : 'Meta ≥65 no choque'),
                _CvcRow(name: 'PVC',       ref: '2–8 mmHg',     note: isEs ? 'Isolado pouco confiável' : 'Isolado pouco confiável'),
                _CvcRow(name: 'PCP',       ref: '6–12 mmHg',    note: isEs ? '>18 = sobrecarga; <6 = hipovolemia' : '>18 = sobrecarga; <6 = hipovolemia'),
                _CvcRow(name: 'DC',        ref: '4–8 L/min',    note: 'IC: 2,5–4,0 L/min/m²'),
                _CvcRow(name: 'RVSP',      ref: '<30 mmHg',     note: isEs ? '>35 = hipertensão pulmonar' : '>35 = hipertensão pulmonar'),
                _CvcRow(name: 'SvO₂',     ref: '65–75%',        note: isEs ? '<65% = extração aumentada (baixo DC)' : '<65% = extração aumentada (baixo DC)'),
              ]),
            ),

            const SizedBox(height: 28),
            _SourcesButton(isEs: isEs),
          ],
        ),
      ),
    );
  }
}

class _AccessCardRow extends StatelessWidget {
  final String site, pros, cons;
  final bool isLast;
  const _AccessCardRow({
    required this.site,
    required this.pros,
    required this.cons,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(site,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: c.textPrimary,
            )),
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.check_circle_outline_rounded,
                    size: 13, color: Color(0xFF059669)),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(pros,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF059669),
                      height: 1.35,
                    )),
                ),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.info_outline_rounded,
                    size: 13, color: Color(0xFFB45309)),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(cons,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFFB45309),
                      height: 1.35,
                    )),
                ),
              ]),
            ),
          ]),
        ]),
      ),
      if (!isLast)
        Divider(height: 1, color: c.border, indent: 2, endIndent: 2),
    ]);
  }
}

class _CvcRow extends StatelessWidget {
  final String name, ref, note;
  const _CvcRow({required this.name, required this.ref, required this.note});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: c.dark ? Colors.white.withOpacity(0.03) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Row(children: [
        SizedBox(
          width: 110,
          child: Text(name,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: c.textPrimary,
            )),
        ),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ref,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.green)),
          if (note.isNotEmpty) ...[ 
            const SizedBox(height: 2),
            Text(note,
              style: TextStyle(fontSize: 10.5, color: c.textSecondary, height: 1.3)),
          ],
        ])),
      ]),
    );
  }
}

// Banner de aviso adaptativo dark/light — cor fosca suave
class _AdvisoryBanner extends StatelessWidget {
  final String text;
  const _AdvisoryBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    // Dark: fundo âmbar com baixa opacidade (fosco) + texto âmbar claro
    // Light: fundo âmbar suave + texto âmbar escuro
    final bgColor = c.dark
        ? const Color(0xFFD97706).withOpacity(0.08)
        : const Color(0xFFFFF8E7);
    final borderColor = c.dark
        ? const Color(0xFFD97706).withOpacity(0.20)
        : const Color(0xFFFFDFA0);
    final textColor = c.dark
        ? const Color(0xFFD97706)
        : const Color(0xFF7A5A00);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.info_outline_rounded, size: 14, color: textColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: textColor,
              height: 1.45,
            )),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS COMPARTILHADOS ENTRE AS TELAS FILHAS
// ─────────────────────────────────────────────────────────────────────────────

/// Card de seção reutilizável — dark/light via AppColors
class _RefSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final Widget child;

  const _RefSectionCard({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(c.dark ? 0.12 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: accentColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: c.textPrimary,
                  letterSpacing: -0.3,
                  height: 1.2,
                )),
            ),
          ]),
        ),
        Divider(height: 1, color: accentColor.withOpacity(0.12)),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: child,
        ),
      ]),
    );
  }
}

/// Seção de Labs com header colapsável e grid de cards
class _LabSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final List<_LabItem> items;
  final String? note;

  const _LabSection({
    required this.title,
    required this.icon,
    required this.accent,
    required this.items,
    this.note,
  });

  @override
  State<_LabSection> createState() => _LabSectionState();
}

class _LabSectionState extends State<_LabSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final accent = widget.accent;

    return Container(
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(c.dark ? 0.12 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header colapsável
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.icon, size: 16, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(widget.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                    letterSpacing: -0.2,
                  )),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${widget.items.length} parâm.',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: accent.withOpacity(0.8),
                  )),
              ),
              const SizedBox(width: 8),
              Icon(
                _expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: c.textHint,
              ),
            ]),
          ),
        ),

        if (_expanded) ...[
          Divider(height: 1, color: accent.withOpacity(0.12), indent: 14, endIndent: 14),
          const SizedBox(height: 12),

          // Grid de cards
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            child: LayoutBuilder(builder: (ctx, box) {
              final cols = box.maxWidth > 380 ? 2 : 2;
              final rows = <Widget>[];
              for (var i = 0; i < widget.items.length; i += cols) {
                final rowItems = widget.items.skip(i).take(cols).toList();
                rows.add(Row(
                  children: List.generate(rowItems.length, (j) {
                    final isLast = (j == rowItems.length - 1);
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: isLast ? 0 : 8, bottom: 8),
                        child: _LabValueTile(item: rowItems[j], accent: accent),
                      ),
                    );
                  }),
                ));
              }
              return Column(children: rows);
            }),
          ),

          // Nota de rodapé
          if (widget.note != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A).withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF1E3A8A).withOpacity(0.15)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.info_outline_rounded, size: 12, color: Color(0xFF1E3A8A)),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(widget.note!,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF1E3A8A),
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      )),
                  ),
                ]),
              ),
            ),
          ] else
            const SizedBox(height: 4),
        ],
      ]),
    );
  }
}

enum _LabSt { normal, alert, critical }

class _LabItem {
  final String name, value, unit;
  final _LabSt status;
  final String note;
  const _LabItem(this.name, this.value, this.unit, this.status, {this.note = ''});
}

class _LabValueTile extends StatelessWidget {
  final _LabItem item;
  final Color accent;
  const _LabValueTile({required this.item, required this.accent});

  Color get _statusColor {
    switch (item.status) {
      case _LabSt.critical: return const Color(0xFFDC2626);
      case _LabSt.alert:    return const Color(0xFFD97706);
      case _LabSt.normal:   return const Color(0xFF059669);
    }
  }

  String get _statusLabel {
    switch (item.status) {
      case _LabSt.critical: return 'CRÍTICO';
      case _LabSt.alert:    return 'ATENÇÃO';
      case _LabSt.normal:   return 'NORMAL';
    }
  }

  IconData get _statusIcon {
    switch (item.status) {
      case _LabSt.critical: return Icons.error_outline_rounded;
      case _LabSt.alert:    return Icons.warning_amber_rounded;
      case _LabSt.normal:   return Icons.check_circle_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final sc = _statusColor;

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: c.dark ? Colors.white.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(item.name,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: c.textSecondary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
        const SizedBox(height: 5),
        Text(item.value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: c.textPrimary,
            height: 1.2,
          ),
          maxLines: 2),
        if (item.unit.isNotEmpty)
          Text(item.unit,
            style: TextStyle(fontSize: 10, color: c.textHint)),
        if (item.note.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(item.note,
            style: TextStyle(
              fontSize: 10,
              color: c.textSecondary,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
        ],
        const SizedBox(height: 7),
        Row(children: [
          Icon(_statusIcon, size: 11, color: sc),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: sc.withOpacity(0.10),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(_statusLabel,
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                color: sc,
                letterSpacing: 0.6,
              )),
          ),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTÃO DE FONTES ACADÊMICAS (shared)
// ─────────────────────────────────────────────────────────────────────────────
class _SourcesButton extends StatelessWidget {
  final bool isEs;
  const _SourcesButton({required this.isEs});

  static const _kUrl   = 'https://www.promedcases.com/fontes-e-referencias';
  static const _kTitle = 'Fontes e Referências — MedCases Pro';
  static const _kTitleEs = 'Fuentes y Referencias — MedCases Pro';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AppHaptics.light(context);
        openAcademicSourceSecurely(
          context,
          isEs ? _kTitleEs : _kTitle,
          _kUrl,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withOpacity(0.07),
          border: Border.all(
            color: const Color(0xFF10B981).withOpacity(0.22),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.menu_book_rounded, size: 15, color: Color(0xFF10B981)),
            const SizedBox(width: 8),
            Text(
              isEs ? 'Ver Fuentes Académicas' : 'Ver Fontes Acadêmicas',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.open_in_new_rounded, size: 12, color: Color(0xFF10B981)),
          ],
        ),
      ),
    );
  }
}
