import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import 'plus_scores_mb1_engine.dart';

enum PlusScoresMb1Specialty {
  thromboembolism,
  neurology,
  emergencyIcu,
  pulmonology,
  surgeryGastro,
  pediatrics,
  infectiousDiseases,
  obstetrics,
  oncology,
  traumaOrthopedics
}

String _spName(PlusScoresMb1Specialty s, bool es) => switch (s) {
      PlusScoresMb1Specialty.thromboembolism => 'Tromboembolismo',
      PlusScoresMb1Specialty.neurology => es ? 'Neurología' : 'Neurologia',
      PlusScoresMb1Specialty.emergencyIcu =>
        es ? 'Emergencias / UCI' : 'Emergência / UTI',
      PlusScoresMb1Specialty.pulmonology => es ? 'Neumología' : 'Pneumologia',
      PlusScoresMb1Specialty.surgeryGastro =>
        es ? 'Cirugía / Gastro' : 'Cirurgia / Gastro',
      PlusScoresMb1Specialty.pediatrics => es ? 'Pediatría' : 'Pediatria',
      PlusScoresMb1Specialty.infectiousDiseases =>
        es ? 'Infectología' : 'Infectologia',
      PlusScoresMb1Specialty.obstetrics => es ? 'Obstetricia' : 'Obstetrícia',
      PlusScoresMb1Specialty.oncology => es ? 'Oncología' : 'Oncologia',
      PlusScoresMb1Specialty.traumaOrthopedics => 'Trauma / Ortopedia',
    };
IconData _spIcon(PlusScoresMb1Specialty s) => switch (s) {
      PlusScoresMb1Specialty.thromboembolism => Icons.air_rounded,
      PlusScoresMb1Specialty.neurology => Icons.psychology_outlined,
      PlusScoresMb1Specialty.emergencyIcu => Icons.monitor_heart_outlined,
      PlusScoresMb1Specialty.pulmonology => Icons.air_rounded,
      PlusScoresMb1Specialty.surgeryGastro => Icons.local_hospital_outlined,
      PlusScoresMb1Specialty.pediatrics => Icons.child_care_outlined,
      PlusScoresMb1Specialty.infectiousDiseases => Icons.bug_report_outlined,
      PlusScoresMb1Specialty.obstetrics => Icons.pregnant_woman_outlined,
      PlusScoresMb1Specialty.oncology => Icons.biotech_outlined,
      PlusScoresMb1Specialty.traumaOrthopedics =>
        Icons.health_and_safety_outlined,
    };
List<PlusScoresMb1Id> _ids(PlusScoresMb1Specialty s) => switch (s) {
      PlusScoresMb1Specialty.thromboembolism => [PlusScoresMb1Id.years],
      PlusScoresMb1Specialty.neurology => [PlusScoresMb1Id.nihss],
      PlusScoresMb1Specialty.emergencyIcu => [
          PlusScoresMb1Id.sofa,
          PlusScoresMb1Id.qsofa
        ],
      PlusScoresMb1Specialty.pulmonology => [PlusScoresMb1Id.curb65],
      PlusScoresMb1Specialty.surgeryGastro => [
          PlusScoresMb1Id.alvarado,
          PlusScoresMb1Id.bisap,
          PlusScoresMb1Id.hinchey,
          PlusScoresMb1Id.caprini2013,
          PlusScoresMb1Id.rcri
        ],
      PlusScoresMb1Specialty.pediatrics => [
          PlusScoresMb1Id.silvermanAndersen,
          PlusScoresMb1Id.westley,
          PlusScoresMb1Id.pediatricAppendicitis
        ],
      PlusScoresMb1Specialty.infectiousDiseases => [
          PlusScoresMb1Id.lrinec,
          PlusScoresMb1Id.mcIsaac,
          PlusScoresMb1Id.dukeIscvid2023
        ],
      PlusScoresMb1Specialty.obstetrics => [
          PlusScoresMb1Id.bishop,
          PlusScoresMb1Id.hellpTennessee
        ],
      PlusScoresMb1Specialty.oncology => [
          PlusScoresMb1Id.ecog,
          PlusScoresMb1Id.mascc
        ],
      PlusScoresMb1Specialty.traumaOrthopedics => [
          PlusScoresMb1Id.ottawaAnkleFoot,
          PlusScoresMb1Id.ottawaKnee,
          PlusScoresMb1Id.nexus,
          PlusScoresMb1Id.canadianCSpine,
          PlusScoresMb1Id.gustiloAnderson,
          PlusScoresMb1Id.mess
        ],
    };

class PlusScoresMb1SpecialtyGrid extends StatelessWidget {
  const PlusScoresMb1SpecialtyGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final es = p.lang == 'es';
    final dark = p.darkMode;
    final text = dark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    final sub = dark ? const Color(0xFFAEB9CC) : const Color(0xFF64748B);
    final surf = dark ? const Color(0xFF252930) : Colors.white;
    final border = dark ? const Color(0xFF374151) : const Color(0xFFDDE3E9);
    const accent = Color(0xFF009C3B);

    return LayoutBuilder(
      builder: (context, c) {
        const gap = 10.0;
        final cols = c.maxWidth >= 760 ? 3 : 2;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              es ? 'Más especialidades' : 'Mais especialidades',
              style: TextStyle(
                color: text,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              es
                  ? 'Scores actualizados y funcionales, organizados por área clínica.'
                  : 'Scores atualizados e funcionais, organizados por área clínica.',
              style: TextStyle(color: sub, fontSize: 11.5),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: gap,
              runSpacing: gap,
              children: PlusScoresMb1Specialty.values.map((specialty) {
                return SizedBox(
                  width: w,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PlusScoresMb1WorkspaceScreen(
                              specialty: specialty,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 88),
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: surf,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: border, width: 0.7),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: Icon(
                                    _spIcon(specialty),
                                    size: 18,
                                    color: accent,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${_ids(specialty).length}',
                                  style: const TextStyle(
                                    color: accent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _spName(specialty, es),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: text,
                                fontSize: 11.6,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }
}

class PlusScoresMb1WorkspaceScreen extends StatelessWidget {
  final PlusScoresMb1Specialty specialty;
  const PlusScoresMb1WorkspaceScreen({super.key, required this.specialty});
  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final es = p.lang == 'es', dark = p.darkMode;
    final bg = dark ? const Color(0xFF1A1D23) : const Color(0xFFECF0F4),
        text = dark ? const Color(0xFFF8FAFC) : const Color(0xFF111827),
        sub = dark ? const Color(0xFFAEB9CC) : const Color(0xFF64748B),
        surf = dark ? const Color(0xFF252930) : Colors.white,
        border = dark ? const Color(0xFF374151) : const Color(0xFFDDE3E9);
    const accent = Color(0xFF009C3B);
    final list = _ids(specialty);
    return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
            backgroundColor: dark ? const Color(0xFF111622) : Colors.white,
            foregroundColor: text,
            elevation: 0,
            title:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('+SCORES',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
              Text(_spName(specialty, es),
                  style: TextStyle(color: sub, fontSize: 10))
            ])),
        body: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 120),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 9),
            itemBuilder: (context, i) {
              final m = _meta(list[i]);
              return Material(
                  color: Colors.transparent,
                  child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) =>
                                  PlusScoresMb1DetailScreen(id: m.id))),
                      child: Container(
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                              color: surf,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: border, width: .7)),
                          child: Row(children: [
                            Container(
                                width: 40,
                                height: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                    color: accent.withValues(alpha: .10),
                                    borderRadius: BorderRadius.circular(11)),
                                child: Icon(m.icon, color: accent, size: 21)),
                            const SizedBox(width: 11),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(m.name,
                                      style: TextStyle(
                                          color: text,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900)),
                                  const SizedBox(height: 4),
                                  Text(es ? m.purposeEs : m.purposePt,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: sub,
                                          fontSize: 10.5,
                                          height: 1.25))
                                ])),
                            const Icon(Icons.chevron_right_rounded,
                                color: accent)
                          ]))));
            }));
  }
}

enum _K { toggle, number, choice }

class _C {
  final int v;
  final String es, pt;
  const _C(this.v, this.es, this.pt);
}

class _F {
  final String k, es, pt;
  final _K kind;
  final String? unit;
  final double? min, max;
  final bool initB;
  final int? initC;
  final List<_C> choices;
  const _F._(this.k, this.es, this.pt, this.kind,
      {this.unit,
      this.min,
      this.max,
      this.initB = false,
      this.initC,
      this.choices = const []});
  const _F.t(String k, String es, String pt, {bool init = false})
      : this._(k, es, pt, _K.toggle, initB: init);
  const _F.n(String k, String es, String pt,
      {String? unit, double? min, double? max})
      : this._(k, es, pt, _K.number, unit: unit, min: min, max: max);
  const _F.c(String k, String es, String pt, List<_C> choices, {int? init})
      : this._(k, es, pt, _K.choice, choices: choices, initC: init);
}

class _M {
  final PlusScoresMb1Id id;
  final String name, purposeEs, purposePt, limitEs, limitPt, ref;
  final IconData icon;
  final List<_F> fields;
  const _M(this.id, this.name, this.icon, this.purposeEs, this.purposePt,
      this.limitEs, this.limitPt, this.ref, this.fields);
}

class _O {
  final String value, bandEs, bandPt, interpEs, interpPt;
  const _O(this.value, this.bandEs, this.bandPt, this.interpEs, this.interpPt);
}

class PlusScoresMb1DetailScreen extends StatefulWidget {
  final PlusScoresMb1Id id;
  const PlusScoresMb1DetailScreen({super.key, required this.id});
  @override
  State<PlusScoresMb1DetailScreen> createState() => _DetailState();
}

class _DetailState extends State<PlusScoresMb1DetailScreen> {
  late final _M m;
  final ctrls = <String, TextEditingController>{};
  final bs = <String, bool>{};
  final cs = <String, int>{};
  _O? out;
  @override
  void initState() {
    super.initState();
    m = _meta(widget.id);
    for (final f in m.fields) {
      switch (f.kind) {
        case _K.number:
          ctrls[f.k] = TextEditingController();
          break;
        case _K.toggle:
          bs[f.k] = f.initB;
          break;
        case _K.choice:
          cs[f.k] = f.initC ?? (f.choices.isEmpty ? 0 : f.choices.first.v);
          break;
      }
    }
  }

  @override
  void dispose() {
    for (final c in ctrls.values) c.dispose();
    super.dispose();
  }

  bool b(String k) => bs[k] ?? false;
  int c(String k) => cs[k] ?? 0;
  double n(String k) =>
      double.parse((ctrls[k]?.text ?? '').trim().replaceAll(',', '.'));
  bool validate(bool es) {
    for (final f in m.fields.where((e) => e.kind == _K.number)) {
      final v =
          double.tryParse((ctrls[f.k]?.text ?? '').trim().replaceAll(',', '.'));
      if (v == null ||
          (f.min != null && v < f.min!) ||
          (f.max != null && v > f.max!)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(es ? 'Revise: ${f.es}' : 'Revise: ${f.pt}')));
        return false;
      }
    }
    return true;
  }

  void calc(bool es) {
    if (!validate(es)) return;
    try {
      setState(() => out = _calculate(widget.id));
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(es
              ? 'Revise los datos ingresados.'
              : 'Revise os dados informados.')));
    }
  }

  _O _calculate(PlusScoresMb1Id id) {
    switch (id) {
      case PlusScoresMb1Id.years:
        {
          final r = PlusScoresMb1Engine.years(
              dvtSigns: b('dvt'),
              hemoptysis: b('hemoptysis'),
              peMostLikely: b('peLikely'),
              dDimerNgMlFeu: n('ddimer'));
          return _O(
              '${r.criteria} YEARS · ${r.cutoffNgMlFeu.toStringAsFixed(0)} ng/mL FEU',
              r.ruleOut ? 'Regla negativa' : 'Regla no negativa',
              r.ruleOut ? 'Regra negativa' : 'Regra não negativa',
              r.ruleOut
                  ? 'Dímero D por debajo del umbral YEARS adaptado.'
                  : 'YEARS no excluye TEP con estos datos.',
              r.ruleOut
                  ? 'Dímero D abaixo do limiar YEARS adaptado.'
                  : 'YEARS não exclui TEP com estes dados.');
        }
      case PlusScoresMb1Id.nihss:
        {
          final s = PlusScoresMb1Engine.nihss([
            c('loc'),
            c('questions'),
            c('commands'),
            c('gaze'),
            c('visual'),
            c('facial'),
            c('armL'),
            c('armR'),
            c('legL'),
            c('legR'),
            c('ataxia'),
            c('sensory'),
            c('language'),
            c('dysarthria'),
            c('extinction')
          ]);
          final i = s == 0
              ? 0
              : s <= 4
                  ? 1
                  : s <= 15
                      ? 2
                      : s <= 20
                          ? 3
                          : 4;
          const es = [
            'Sin déficit puntuable',
            'Déficit menor',
            'Déficit moderado',
            'Moderado-grave',
            'Déficit grave'
          ];
          const pt = [
            'Sem déficit pontuável',
            'Déficit menor',
            'Déficit moderado',
            'Moderado-grave',
            'Déficit grave'
          ];
          return _O(
              '$s / 42',
              es[i],
              pt[i],
              'Cuantifica el déficit observado; no decide reperfusión de forma aislada.',
              'Quantifica o déficit observado; não decide reperfusão isoladamente.');
        }
      case PlusScoresMb1Id.sofa:
        {
          final s = PlusScoresMb1Engine.sofa([
            c('resp'),
            c('coag'),
            c('liver'),
            c('cardio'),
            c('cns'),
            c('renal')
          ]);
          return _O(
              '$s / 24',
              s >= 2 ? 'Disfunción orgánica relevante' : 'Puntaje bajo',
              s >= 2 ? 'Disfunção orgânica relevante' : 'Pontuação baixa',
              'Comparar con SOFA basal; aumento agudo ≥2 en infección sospechada integra Sepsis-3.',
              'Comparar ao SOFA basal; aumento agudo ≥2 em suspeita de infecção integra Sepsis-3.');
        }
      case PlusScoresMb1Id.qsofa:
        {
          final s = PlusScoresMb1Engine.qsofa(
              systolicBp: n('sbp'),
              respiratoryRate: n('rr'),
              alteredMentalStatus: b('ams'));
          return _O(
              '$s / 3',
              s >= 2 ? 'Riesgo aumentado' : '<2 criterios',
              s >= 2 ? 'Risco aumentado' : '<2 critérios',
              'No usar qSOFA como herramienta única de screening de sepsis.',
              'Não usar qSOFA como ferramenta única de triagem de sepse.');
        }
      case PlusScoresMb1Id.curb65:
        {
          final s = PlusScoresMb1Engine.curb65(
              confusion: b('confusion'),
              ureaMmolL: n('urea'),
              respiratoryRate: n('rr'),
              systolicBp: n('sbp'),
              diastolicBp: n('dbp'),
              ageYears: n('age'));
          final i = s <= 1
              ? 0
              : s == 2
                  ? 1
                  : 2;
          const es = ['Riesgo bajo', 'Riesgo intermedio', 'Riesgo alto'];
          const pt = ['Risco baixo', 'Risco intermediário', 'Risco alto'];
          return _O(
              '$s / 5',
              es[i],
              pt[i],
              'Pronóstico en neumonía adquirida en la comunidad.',
              'Prognóstico na pneumonia adquirida na comunidade.');
        }
      case PlusScoresMb1Id.alvarado:
        {
          final s = PlusScoresMb1Engine.alvarado(
              migration: b('migration'),
              anorexia: b('anorexia'),
              nauseaVomiting: b('nv'),
              rlqTenderness: b('rlq'),
              rebound: b('rebound'),
              fever: b('fever'),
              leukocytosis: b('leuko'),
              leftShift: b('leftShift'));
          final i = s <= 3
              ? 0
              : s <= 6
                  ? 1
                  : 2;
          const es = ['Baja probabilidad', 'Intermedia', 'Alta probabilidad'];
          const pt = [
            'Baixa probabilidade',
            'Intermediária',
            'Alta probabilidade'
          ];
          return _O(
              '$s / 10',
              es[i],
              pt[i],
              'Integrar con evaluación seriada, laboratorio e imagen.',
              'Integrar com avaliação seriada, laboratório e imagem.');
        }
      case PlusScoresMb1Id.bisap:
        {
          final s = PlusScoresMb1Engine.bisap(
              bunMgDl: n('bun'),
              gcs: n('gcs').round(),
              sirsAtLeast2: b('sirs'),
              ageYears: n('age'),
              pleuralEffusion: b('effusion'));
          return _O(
              '$s / 5',
              s >= 3 ? 'Mayor riesgo' : 'Menor riesgo',
              s >= 3 ? 'Maior risco' : 'Menor risco',
              'Estimación temprana de gravedad en pancreatitis aguda.',
              'Estimativa precoce de gravidade na pancreatite aguda.');
        }
      case PlusScoresMb1Id.hinchey:
        {
          final s = PlusScoresMb1Engine.hincheyStage(c('stage'));
          const es = [
            '',
            'Absceso pericólico',
            'Absceso distante',
            'Peritonitis purulenta',
            'Peritonitis fecal'
          ];
          const pt = [
            '',
            'Abscesso pericólico',
            'Abscesso distante',
            'Peritonite purulenta',
            'Peritonite fecal'
          ];
          return _O(
              'Hinchey $s',
              es[s],
              pt[s],
              'Clasificación anatómica de diverticulitis complicada.',
              'Classificação anatômica da diverticulite complicada.');
        }
      case PlusScoresMb1Id.silvermanAndersen:
        {
          final s = PlusScoresMb1Engine.silvermanAndersen([
            c('thoraco'),
            c('intercostal'),
            c('xiphoid'),
            c('nasal'),
            c('grunt')
          ]);
          final i = s == 0
              ? 0
              : s <= 3
                  ? 1
                  : s <= 6
                      ? 2
                      : 3;
          const es = ['Sin dificultad', 'Leve', 'Moderada', 'Grave'];
          const pt = ['Sem desconforto', 'Leve', 'Moderado', 'Grave'];
          return _O(
              '$s / 10',
              es[i],
              pt[i],
              'A mayor puntaje, mayor trabajo respiratorio neonatal.',
              'Quanto maior a pontuação, maior o trabalho respiratório neonatal.');
        }
      case PlusScoresMb1Id.westley:
        {
          final s = PlusScoresMb1Engine.westley(
              stridor: c('stridor'),
              retractions: c('retractions'),
              airEntry: c('air'),
              cyanosis: c('cyanosis'),
              consciousness: c('consciousness'));
          final i = s <= 2
              ? 0
              : s <= 5
                  ? 1
                  : s <= 11
                      ? 2
                      : 3;
          const es = ['Leve', 'Moderado', 'Grave', 'Muy grave'];
          const pt = ['Leve', 'Moderado', 'Grave', 'Muito grave'];
          return _O(
              '$s / 17',
              es[i],
              pt[i],
              'Evaluar al niño tranquilo para evitar sobreestimación.',
              'Avaliar a criança calma para evitar superestimação.');
        }
      case PlusScoresMb1Id.pediatricAppendicitis:
        {
          final s = PlusScoresMb1Engine.pediatricAppendicitis(
              coughPercussionHopTenderness: b('hop'),
              anorexia: b('anorexia'),
              fever: b('fever'),
              nauseaVomiting: b('nv'),
              rlqTenderness: b('rlq'),
              migration: b('migration'),
              leukocytosis: b('leuko'),
              neutrophilia: b('neutro'));
          final i = s <= 3
              ? 0
              : s <= 7
                  ? 1
                  : 2;
          const es = ['Baja probabilidad', 'Intermedio', 'Alta probabilidad'];
          const pt = [
            'Baixa probabilidade',
            'Intermediário',
            'Alta probabilidade'
          ];
          return _O(
              '$s / 10',
              es[i],
              pt[i],
              'No diagnosticar apendicitis pediátrica por score aislado.',
              'Não diagnosticar apendicite pediátrica por score isolado.');
        }
      case PlusScoresMb1Id.lrinec:
        {
          final s = PlusScoresMb1Engine.lrinec(
              crpMgL: n('crp'),
              wbcK: n('wbc'),
              hemoglobinGDl: n('hb'),
              sodiumMmolL: n('na'),
              creatinineMgDl: n('cr'),
              glucoseMgDl: n('glucose'));
          final i = s < 6
              ? 0
              : s <= 7
                  ? 1
                  : 2;
          const es = ['Menor puntuación', 'Intermedio', 'Mayor puntuación'];
          const pt = ['Menor pontuação', 'Intermediário', 'Maior pontuação'];
          return _O(
              '$s / 13',
              es[i],
              pt[i],
              'Un LRINEC bajo no excluye infección necrosante.',
              'LRINEC baixo não exclui infecção necrosante.');
        }
      case PlusScoresMb1Id.mcIsaac:
        {
          final s = PlusScoresMb1Engine.mcIsaac(
              feverOver38: b('fever'),
              absentCough: b('noCough'),
              tenderAnteriorCervicalNodes: b('nodes'),
              tonsillarExudateOrSwelling: b('tonsil'),
              ageBandPoints: c('ageBand'));
          final i = s <= 1
              ? 0
              : s <= 3
                  ? 1
                  : 2;
          const es = ['Baja probabilidad', 'Intermedia', 'Mayor probabilidad'];
          const pt = [
            'Baixa probabilidade',
            'Intermediária',
            'Maior probabilidade'
          ];
          return _O(
              '$s',
              es[i],
              pt[i],
              'Orienta probabilidad pretest; confirmar según estrategia de testeo vigente.',
              'Orienta probabilidade pré-teste; confirmar segundo estratégia de testagem vigente.');
        }
      case PlusScoresMb1Id.dukeIscvid2023:
        {
          final r = PlusScoresMb1Engine.dukeIscvid2023(
              majorMicrobiology: b('majorMicro'),
              majorImaging: b('majorImaging'),
              majorSurgical: b('majorSurgical'),
              minorPredisposition: b('minorPred'),
              minorFever: b('minorFever'),
              minorVascular: b('minorVascular'),
              minorImmunologic: b('minorImmunologic'),
              minorMicrobiology: b('minorMicro'),
              minorImaging: b('minorImaging'),
              minorPhysicalExam: b('minorPhysical'));
          final d = r == 'definite', p = r == 'possible';
          return _O(
              r.toUpperCase(),
              d
                  ? 'Endocarditis clínica definida'
                  : p
                      ? 'Endocarditis clínica posible'
                      : 'Criterios insuficientes',
              d
                  ? 'Endocardite clínica definida'
                  : p
                      ? 'Endocardite clínica possível'
                      : 'Critérios insuficientes',
              'Aplicar las definiciones formales 2023 de cada criterio.',
              'Aplicar as definições formais 2023 de cada critério.');
        }
      case PlusScoresMb1Id.caprini2013:
        {
          final pts = <int>[];
          final age = c('agePoints');
          if (age > 0) pts.add(age);
          for (final k in [
            'minorSurgery',
            'majorSurgeryLastMonth',
            'varicose',
            'ibd',
            'swollenLegs',
            'bmi25',
            'mi',
            'chf',
            'seriousInfection',
            'lungDisease',
            'reducedMobilityLt72',
            'hormone',
            'pregnancyPostpartum',
            'obstetricHistory',
            'bmi40',
            'smoking',
            'insulinDiabetes',
            'chemotherapy',
            'transfusion',
            'surgeryOver2h'
          ]) {
            if (b(k)) pts.add(1);
          }
          for (final k in [
            'malignancy',
            'plannedMajorSurgery',
            'cast',
            'centralVenous',
            'bed72'
          ]) {
            if (b(k)) pts.add(2);
          }
          for (final k in ['priorVte', 'familyVte', 'thrombophilia']) {
            if (b(k)) pts.add(3);
          }
          for (final k in [
            'arthroplasty',
            'hipPelvisLegFracture',
            'seriousTrauma',
            'spinalCord',
            'stroke'
          ]) {
            if (b(k)) pts.add(5);
          }
          final s = PlusScoresMb1Engine.caprini2013(pts);
          final i = s == 0
              ? 0
              : s <= 2
                  ? 1
                  : s <= 4
                      ? 2
                      : 3;
          const es = ['Muy bajo', 'Bajo', 'Moderado', 'Alto'];
          const pt = ['Muito baixo', 'Baixo', 'Moderado', 'Alto'];
          return _O(
              '$s',
              es[i],
              pt[i],
              'Estratificación de TEV perioperatorio; no prescribe profilaxis automáticamente.',
              'Estratificação de TEV perioperatório; não prescreve profilaxia automaticamente.');
        }
      case PlusScoresMb1Id.rcri:
        {
          final s = PlusScoresMb1Engine.rcri(
              highRiskSurgery: b('highRiskSurgery'),
              ischemicHeartDisease: b('ihd'),
              heartFailure: b('hf'),
              cerebrovascularDisease: b('cvd'),
              insulinTherapy: b('insulin'),
              creatinineOver2: b('cr2'));
          final cls = s == 0
              ? 'I'
              : s == 1
                  ? 'II'
                  : s == 2
                      ? 'III'
                      : 'IV';
          return _O(
              '$s / 6',
              'Clase $cls',
              'Classe $cls',
              'Integrar al algoritmo perioperatorio contemporáneo.',
              'Integrar ao algoritmo perioperatório contemporâneo.');
        }
      case PlusScoresMb1Id.bishop:
        {
          final s = PlusScoresMb1Engine.bishop(
              dilationPoints: c('dilation'),
              effacementPoints: c('effacement'),
              consistencyPoints: c('consistency'),
              positionPoints: c('position'),
              stationPoints: c('station'));
          final i = s <= 5
              ? 0
              : s <= 7
                  ? 1
                  : 2;
          const es = ['Cuello desfavorable', 'Intermedio', 'Cuello favorable'];
          const pt = ['Colo desfavorável', 'Intermediário', 'Colo favorável'];
          return _O(
              '$s / 13',
              es[i],
              pt[i],
              'Predice madurez cervical; existe variabilidad interobservador.',
              'Prediz maturidade cervical; há variabilidade interobservador.');
        }
      case PlusScoresMb1Id.hellpTennessee:
        {
          final ok = PlusScoresMb1Engine.hellpTennessee(
              ldhUL: n('ldh'),
              astUL: n('ast'),
              plateletsPerMm3: n('platelets'),
              indirectBilirubinMgDl: n('bili'),
              schistocytesOrHemolysisEvidence: b('hemolysis'));
          return _O(
              ok ? 'COMPATÍVEL' : 'NÃO COMPLETO',
              ok ? 'Cumple Tennessee clásico' : 'No cumple los 3 dominios',
              ok ? 'Preenche Tennessee clássico' : 'Não preenche os 3 domínios',
              'HELLP parcial sigue siendo posible si el conjunto no es completo.',
              'HELLP parcial continua possível se o conjunto não for completo.');
        }
      case PlusScoresMb1Id.ecog:
        {
          final g = PlusScoresMb1Engine.ecog(c('grade'));
          const es = [
            'Totalmente activo',
            'Restricción para esfuerzo',
            'Ambulatorio, autocuidado',
            'Autocuidado limitado',
            'Totalmente dependiente',
            'Fallecido'
          ];
          const pt = [
            'Totalmente ativo',
            'Restrição para esforço',
            'Ambulatorial, autocuidado',
            'Autocuidado limitado',
            'Totalmente dependente',
            'Óbito'
          ];
          return _O(
              'ECOG $g',
              es[g],
              pt[g],
              'Registrar el estado funcional basal relevante.',
              'Registrar o estado funcional basal relevante.');
        }
      case PlusScoresMb1Id.mascc:
        {
          final s = PlusScoresMb1Engine.mascc(
              burdenPoints: c('burden'),
              noHypotension: b('noHypotension'),
              noCopd: b('noCopd'),
              solidTumorOrHemeNoPriorFungal: b('tumor'),
              noDehydration: b('noDehydration'),
              outpatientOnset: b('outpatient'),
              ageUnder60: b('under60'));
          return _O(
              '$s / 26',
              s >= 21 ? 'Bajo riesgo por MASCC' : 'No bajo riesgo',
              s >= 21 ? 'Baixo risco pelo MASCC' : 'Não baixo risco',
              'MASCC ≥21 no sustituye estabilidad clínica ni criterios institucionales.',
              'MASCC ≥21 não substitui estabilidade clínica nem critérios institucionais.');
        }
      case PlusScoresMb1Id.ottawaAnkleFoot:
        {
          final r = PlusScoresMb1Engine.ottawaAnkleFoot(
              malleolarZonePain: b('malleolarPain'),
              midfootZonePain: b('midfootPain'),
              posteriorLateralMalleolusTenderness: b('latMalleolus'),
              posteriorMedialMalleolusTenderness: b('medMalleolus'),
              fifthMetatarsalTenderness: b('fifth'),
              navicularTenderness: b('navicular'),
              unableFourSteps: b('fourSteps'));
          final pos = r.ankleImaging || r.footImaging;
          return _O(
              'Tornozelo ${r.ankleImaging ? 'SIM' : 'NÃO'} · Pé ${r.footImaging ? 'SIM' : 'NÃO'}',
              pos ? 'Criterio de radiografía' : 'Regla negativa',
              pos ? 'Critério de radiografia' : 'Regra negativa',
              'Aplicar solo en trauma agudo con examen confiable.',
              'Aplicar apenas em trauma agudo com exame confiável.');
        }
      case PlusScoresMb1Id.ottawaKnee:
        {
          final x = PlusScoresMb1Engine.ottawaKnee(
              age55OrOlder: b('age55'),
              isolatedPatellarTenderness: b('patella'),
              fibularHeadTenderness: b('fibula'),
              unableFlex90: b('flex90'),
              unableFourSteps: b('fourSteps'));
          return _O(
              x ? 'POSITIVA' : 'NEGATIVA',
              x ? 'Criterio de radiografía' : 'Regla negativa',
              x ? 'Critério de radiografia' : 'Regra negativa',
              'Evalúa fractura, no menisco o ligamentos.',
              'Avalia fratura, não menisco ou ligamentos.');
        }
      case PlusScoresMb1Id.nexus:
        {
          final low = PlusScoresMb1Engine.nexusLowRisk(
              midlineTenderness: b('midline'),
              focalNeurologicDeficit: b('neuro'),
              alteredAlertness: b('alertness'),
              intoxication: b('intoxication'),
              distractingInjury: b('distracting'));
          return _O(
              low ? 'NEXUS NEGATIVO' : 'NEXUS POSITIVO',
              low ? '5 criterios de bajo riesgo' : 'No cumple bajo riesgo',
              low ? '5 critérios de baixo risco' : 'Não preenche baixo risco',
              'Usar en población apropiada de trauma cervical contuso.',
              'Usar em população apropriada de trauma cervical contuso.');
        }
      case PlusScoresMb1Id.canadianCSpine:
        {
          final x = PlusScoresMb1Engine.canadianCSpineNeedsImaging(
              applicableAlertStable: b('applicable'),
              age65OrOlder: b('age65'),
              dangerousMechanism: b('dangerous'),
              extremityParesthesias: b('paresthesia'),
              simpleRearEnd: b('rearEnd'),
              sittingInEd: b('sitting'),
              ambulatoryAnyTime: b('ambulatory'),
              delayedNeckPain: b('delayed'),
              noMidlineTenderness: b('noMidline'),
              canRotate45BothWays: b('rotate45'));
          return _O(
              x ? 'IMAGEM PELA REGRA' : 'REGRA NEGATIVA',
              x ? 'No puede depurarse clínicamente' : 'Bajo riesgo por CCR',
              x ? 'Não pode ser liberado clinicamente' : 'Baixo risco pela CCR',
              'Válida en pacientes alertas y estables dentro de criterios de inclusión.',
              'Válida em pacientes alertas e estáveis dentro dos critérios de inclusão.');
        }
      case PlusScoresMb1Id.gustiloAnderson:
        {
          final g = PlusScoresMb1Engine.gustiloAnderson(c('grade'));
          const l = ['', 'I', 'II', 'IIIA', 'IIIB', 'IIIC'];
          return _O(
              'Gustilo ${l[g]}',
              'Fractura expuesta',
              'Fratura exposta',
              'Clasificación definitiva tras exploración y desbridamiento.',
              'Classificação definitiva após exploração e desbridamento.');
        }
      case PlusScoresMb1Id.mess:
        {
          final s = PlusScoresMb1Engine.mess(
              skeletalSoftTissuePoints: c('skeletal'),
              limbIschemiaPoints: c('ischemia'),
              ischemiaOver6Hours: b('ischemia6h'),
              shockPoints: c('shock'),
              agePoints: c('agePoints'));
          return _O(
              '$s',
              s >= 7 ? 'Umbral histórico ≥7' : 'Debajo del umbral histórico',
              s >= 7 ? 'Limiar histórico ≥7' : 'Abaixo do limiar histórico',
              'No usar MESS como indicación automática de amputación.',
              'Não usar MESS como indicação automática de amputação.');
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final es = p.lang == 'es', dark = p.darkMode;
    final bg = dark ? const Color(0xFF1A1D23) : const Color(0xFFECF0F4),
        text = dark ? const Color(0xFFF8FAFC) : const Color(0xFF111827),
        sub = dark ? const Color(0xFFAEB9CC) : const Color(0xFF64748B),
        surf = dark ? const Color(0xFF252930) : Colors.white,
        border = dark ? const Color(0xFF374151) : const Color(0xFFDDE3E9);
    const accent = Color(0xFF009C3B);
    Widget card(Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
            color: surf,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: .7)),
        child: child);
    return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
            backgroundColor: dark ? const Color(0xFF111622) : Colors.white,
            foregroundColor: text,
            elevation: 0,
            title: Text(m.name,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w900))),
        body: ListView(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 120),
            children: [
              card(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(es ? m.purposeEs : m.purposePt,
                        style: TextStyle(
                            color: text,
                            fontSize: 13,
                            height: 1.4,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(
                        es
                            ? 'Use las unidades indicadas.'
                            : 'Use as unidades indicadas.',
                        style: TextStyle(color: sub, fontSize: 10.5))
                  ])),
              const SizedBox(height: 10),
              ...m.fields.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: _field(f, es, text, sub, surf, border))),
              SizedBox(
                  height: 46,
                  child: FilledButton(
                      onPressed: () => calc(es),
                      style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: Text(
                          es
                              ? 'CALCULAR / CLASIFICAR'
                              : 'CALCULAR / CLASSIFICAR',
                          style:
                              const TextStyle(fontWeight: FontWeight.w900)))),
              if (out != null) ...[
                const SizedBox(height: 12),
                card(Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('RESULTADO',
                          style: TextStyle(
                              color: accent,
                              fontSize: 10,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Text(out!.value,
                          style: TextStyle(
                              color: text,
                              fontSize: 21,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(es ? out!.bandEs : out!.bandPt,
                          style: const TextStyle(
                              color: accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Text(es ? out!.interpEs : out!.interpPt,
                          style:
                              TextStyle(color: text, fontSize: 11, height: 1.4))
                    ]))
              ],
              const SizedBox(height: 10),
              card(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(es ? 'LIMITACIONES' : 'LIMITAÇÕES',
                        style: const TextStyle(
                            color: accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Text(es ? m.limitEs : m.limitPt,
                        style: TextStyle(
                            color: text, fontSize: 10.5, height: 1.4)),
                    const SizedBox(height: 10),
                    Text(es ? 'REFERENCIA' : 'REFERÊNCIA',
                        style: const TextStyle(
                            color: accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Text(m.ref,
                        style:
                            TextStyle(color: sub, fontSize: 10, height: 1.35))
                  ])),
              const SizedBox(height: 10),
              Text(
                  es
                      ? 'Herramienta educativa de apoyo. No reemplaza juicio clínico ni protocolos locales.'
                      : 'Ferramenta educacional de apoio. Não substitui julgamento clínico nem protocolos locais.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: sub, fontSize: 9.5))
            ]));
  }

  Widget _field(
      _F f, bool es, Color text, Color sub, Color surf, Color border) {
    final label = es ? f.es : f.pt;
    switch (f.kind) {
      case _K.toggle:
        return Container(
            decoration: BoxDecoration(
                color: surf,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: border, width: .7)),
            child: SwitchListTile.adaptive(
                value: bs[f.k] ?? false,
                onChanged: (v) => setState(() => bs[f.k] = v),
                dense: true,
                title: Text(label,
                    style: TextStyle(
                        color: text,
                        fontSize: 11,
                        fontWeight: FontWeight.w700))));
      case _K.number:
        return TextField(
            controller: ctrls[f.k],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,-]'))
            ],
            style: TextStyle(color: text, fontSize: 12),
            decoration: InputDecoration(
                filled: true,
                fillColor: surf,
                labelText: f.unit == null ? label : '$label · ${f.unit}',
                labelStyle: TextStyle(color: sub, fontSize: 10.5),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: border, width: .7)),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12))));
      case _K.choice:
        return DropdownButtonFormField<int>(
            value: cs[f.k],
            dropdownColor: surf,
            style: TextStyle(color: text, fontSize: 11),
            decoration: InputDecoration(
                filled: true,
                fillColor: surf,
                labelText: label,
                labelStyle: TextStyle(color: sub, fontSize: 10.5),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: border, width: .7)),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12))),
            items: f.choices
                .map((x) => DropdownMenuItem<int>(
                    value: x.v, child: Text(es ? x.es : x.pt)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => cs[f.k] = v);
            });
    }
  }
}

_M _meta(PlusScoresMb1Id id) {
  switch (id) {
    case PlusScoresMb1Id.years:
      return _M(
          id,
          'YEARS',
          Icons.air_rounded,
          'Algoritmo diagnóstico de TEP con dímero D adaptado.',
          'Algoritmo diagnóstico de TEP com dímero D adaptado.',
          'Usar dímero D en ng/mL FEU; anticoagulación terapéutica iniciada y embarazo requieren contexto/algoritmo específico.',
          'Usar dímero D em ng/mL FEU; anticoagulação terapêutica iniciada e gestação exigem contexto/algoritmo específico.',
          'van der Hulle et al., Lancet 2017 · YEARS', [
        const _F.t('dvt', 'Signos clínicos de TVP', 'Sinais clínicos de TVP'),
        const _F.t('hemoptysis', 'Hemoptisis', 'Hemoptise'),
        const _F.t('peLikely', 'TEP es el diagnóstico más probable',
            'TEP é o diagnóstico mais provável'),
        const _F.n('ddimer', 'Dímero D', 'Dímero D',
            unit: 'ng/mL FEU', min: 0, max: 100000)
      ]);
    case PlusScoresMb1Id.nihss:
      return _M(
          id,
          'NIHSS',
          Icons.psychology_outlined,
          'Cuantifica déficit neurológico agudo en ictus.',
          'Quantifica déficit neurológico agudo no AVC.',
          'Puntuar lo observado; seguir reglas NIHSS para ítems no testables.',
          'Pontuar o observado; seguir regras NIHSS para itens não testáveis.',
          'Brott et al., Stroke 1989 · Lyden NIHSS training', [
        const _F.c(
            'loc', '1a. Nivel de conciencia', '1a. Nível de consciência', [
          _C(0, '0 · Alerta', '0 · Alerta'),
          _C(1, '1 · Somnolento', '1 · Sonolento'),
          _C(2, '2 · Estímulo repetido', '2 · Estímulo repetido'),
          _C(3, '3 · Respuesta refleja/ninguna', '3 · Resposta reflexa/nenhuma')
        ]),
        const _F.c('questions', '1b. Preguntas', '1b. Perguntas', [
          _C(0, '0 · Ambas', '0 · Ambas'),
          _C(1, '1 · Una', '1 · Uma'),
          _C(2, '2 · Ninguna', '2 · Nenhuma')
        ]),
        const _F.c('commands', '1c. Órdenes', '1c. Comandos', [
          _C(0, '0 · Ambos', '0 · Ambos'),
          _C(1, '1 · Uno', '1 · Um'),
          _C(2, '2 · Ninguno', '2 · Nenhum')
        ]),
        const _F.c('gaze', '2. Mirada', '2. Olhar', [
          _C(0, '0 · Normal', '0 · Normal'),
          _C(1, '1 · Parcial', '1 · Parcial'),
          _C(2, '2 · Forzada', '2 · Forçado')
        ]),
        const _F.c('visual', '3. Campos visuales', '3. Campos visuais', [
          _C(0, '0', '0'),
          _C(1, '1 · Parcial', '1 · Parcial'),
          _C(2, '2 · Completa', '2 · Completa'),
          _C(3, '3 · Bilateral', '3 · Bilateral')
        ]),
        const _F.c('facial', '4. Parálisis facial', '4. Paralisia facial', [
          _C(0, '0', '0'),
          _C(1, '1', '1'),
          _C(2, '2', '2'),
          _C(3, '3', '3')
        ]),
        const _F.c('armL', '5a. Brazo izquierdo', '5a. Braço esquerdo', [
          _C(0, '0', '0'),
          _C(1, '1', '1'),
          _C(2, '2', '2'),
          _C(3, '3', '3'),
          _C(4, '4', '4')
        ]),
        const _F.c('armR', '5b. Brazo derecho', '5b. Braço direito', [
          _C(0, '0', '0'),
          _C(1, '1', '1'),
          _C(2, '2', '2'),
          _C(3, '3', '3'),
          _C(4, '4', '4')
        ]),
        const _F.c('legL', '6a. Pierna izquierda', '6a. Perna esquerda', [
          _C(0, '0', '0'),
          _C(1, '1', '1'),
          _C(2, '2', '2'),
          _C(3, '3', '3'),
          _C(4, '4', '4')
        ]),
        const _F.c('legR', '6b. Pierna derecha', '6b. Perna direita', [
          _C(0, '0', '0'),
          _C(1, '1', '1'),
          _C(2, '2', '2'),
          _C(3, '3', '3'),
          _C(4, '4', '4')
        ]),
        const _F.c('ataxia', '7. Ataxia', '7. Ataxia',
            [_C(0, '0', '0'), _C(1, '1', '1'), _C(2, '2', '2')]),
        const _F.c('sensory', '8. Sensibilidad', '8. Sensibilidade',
            [_C(0, '0', '0'), _C(1, '1', '1'), _C(2, '2', '2')]),
        const _F.c('language', '9. Lenguaje', '9. Linguagem', [
          _C(0, '0', '0'),
          _C(1, '1', '1'),
          _C(2, '2', '2'),
          _C(3, '3', '3')
        ]),
        const _F.c('dysarthria', '10. Disartria', '10. Disartria',
            [_C(0, '0', '0'), _C(1, '1', '1'), _C(2, '2', '2')]),
        const _F.c(
            'extinction',
            '11. Extinción/inatención',
            '11. Extinção/desatenção',
            [_C(0, '0', '0'), _C(1, '1', '1'), _C(2, '2', '2')])
      ]);
    case PlusScoresMb1Id.sofa:
      return _M(
          id,
          'SOFA',
          Icons.monitor_heart_outlined,
          'Disfunción de seis sistemas orgánicos.',
          'Disfunção de seis sistemas orgânicos.',
          'El total aislado no diagnostica sepsis; comparar con basal.',
          'O total isolado não diagnostica sepse; comparar com basal.',
          'Vincent 1996 · Sepsis-3 · Surviving Sepsis Campaign 2026', [
        const _F.c(
            'resp', 'Respiratorio · PaO₂/FiO₂', 'Respiratório · PaO₂/FiO₂', [
          _C(0, '≥400 · 0', '≥400 · 0'),
          _C(1, '<400 · 1', '<400 · 1'),
          _C(2, '<300 · 2', '<300 · 2'),
          _C(3, '<200 + soporte · 3', '<200 + suporte · 3'),
          _C(4, '<100 + soporte · 4', '<100 + suporte · 4')
        ]),
        const _F.c('coag', 'Plaquetas', 'Plaquetas', [
          _C(0, '≥150k · 0', '≥150k · 0'),
          _C(1, '<150k · 1', '<150k · 1'),
          _C(2, '<100k · 2', '<100k · 2'),
          _C(3, '<50k · 3', '<50k · 3'),
          _C(4, '<20k · 4', '<20k · 4')
        ]),
        const _F.c('liver', 'Bilirrubina', 'Bilirrubina', [
          _C(0, '<1.2 · 0', '<1,2 · 0'),
          _C(1, '1.2–1.9 · 1', '1,2–1,9 · 1'),
          _C(2, '2–5.9 · 2', '2–5,9 · 2'),
          _C(3, '6–11.9 · 3', '6–11,9 · 3'),
          _C(4, '≥12 · 4', '≥12 · 4')
        ]),
        const _F.c('cardio', 'Cardiovascular', 'Cardiovascular', [
          _C(0, 'PAM ≥70 · 0', 'PAM ≥70 · 0'),
          _C(1, 'PAM <70 · 1', 'PAM <70 · 1'),
          _C(2, 'Vasopresor bajo · 2', 'Vasopressor baixo · 2'),
          _C(3, 'Vasopresor medio · 3', 'Vasopressor médio · 3'),
          _C(4, 'Vasopresor alto · 4', 'Vasopressor alto · 4')
        ]),
        const _F.c('cns', 'SNC · Glasgow', 'SNC · Glasgow', [
          _C(0, '15 · 0', '15 · 0'),
          _C(1, '13–14 · 1', '13–14 · 1'),
          _C(2, '10–12 · 2', '10–12 · 2'),
          _C(3, '6–9 · 3', '6–9 · 3'),
          _C(4, '<6 · 4', '<6 · 4')
        ]),
        const _F.c('renal', 'Renal · creatinina/diuresis',
            'Renal · creatinina/diurese', [
          _C(0, '0', '0'),
          _C(1, '1', '1'),
          _C(2, '2', '2'),
          _C(3, '3', '3'),
          _C(4, '4', '4')
        ])
      ]);
    case PlusScoresMb1Id.qsofa:
      return _M(
          id,
          'qSOFA',
          Icons.speed_outlined,
          'Marcador pronóstico rápido en infección sospechada.',
          'Marcador prognóstico rápido em infecção suspeita.',
          'SSC 2026 recomienda NEWS/NEWS2, MEWS o SIRS sobre qSOFA como screening único.',
          'SSC 2026 recomenda NEWS/NEWS2, MEWS ou SIRS em vez de qSOFA como triagem única.',
          'Sepsis-3 · Surviving Sepsis Campaign 2026', [
        const _F.n('sbp', 'PAS', 'PAS', unit: 'mmHg', min: 0, max: 300),
        const _F.n('rr', 'Frecuencia respiratoria', 'Frequência respiratória',
            unit: 'irpm', min: 0, max: 100),
        const _F.t(
            'ams', 'Alteración del estado mental', 'Alteração do estado mental')
      ]);
    case PlusScoresMb1Id.curb65:
      return _M(
          id,
          'CURB-65',
          Icons.air_rounded,
          'Estratifica mortalidad en neumonía adquirida en la comunidad.',
          'Estratifica mortalidade em pneumonia adquirida na comunidade.',
          'Urea en mmol/L; criterio >7 mmol/L. Integrar juicio clínico.',
          'Ureia em mmol/L; critério >7 mmol/L. Integrar julgamento clínico.',
          'Lim et al. 2003 · NICE NG250 Pneumonia 2025', [
        const _F.t('confusion', 'Confusión nueva', 'Confusão nova'),
        const _F.n('urea', 'Urea', 'Ureia', unit: 'mmol/L', min: 0, max: 100),
        const _F.n('rr', 'Frecuencia respiratoria', 'Frequência respiratória',
            unit: 'irpm', min: 0, max: 100),
        const _F.n('sbp', 'PAS', 'PAS', unit: 'mmHg', min: 0, max: 300),
        const _F.n('dbp', 'PAD', 'PAD', unit: 'mmHg', min: 0, max: 200),
        const _F.n('age', 'Edad', 'Idade', unit: 'años/anos', min: 0, max: 130)
      ]);
    case PlusScoresMb1Id.alvarado:
      return _M(
          id,
          'Alvarado · MANTRELS',
          Icons.local_hospital_outlined,
          'Estratifica probabilidad de apendicitis aguda.',
          'Estratifica probabilidade de apendicite aguda.',
          'No sustituye examen seriado ni imagen; AIR/AAS tienen mejor desempeño adulto en WSES.',
          'Não substitui exame seriado nem imagem; AIR/AAS têm melhor desempenho adulto no WSES.',
          'Alvarado 1986 · WSES 2020', [
        const _F.t('migration', 'Migración a FID', 'Migração para FID'),
        const _F.t('anorexia', 'Anorexia', 'Anorexia'),
        const _F.t('nv', 'Náuseas/vómitos', 'Náuseas/vômitos'),
        const _F.t('rlq', 'Dolor FID · 2', 'Dor FID · 2'),
        const _F.t('rebound', 'Rebote', 'Descompressão dolorosa'),
        const _F.t('fever', 'Fiebre', 'Febre'),
        const _F.t('leuko', 'Leucocitosis · 2', 'Leucocitose · 2'),
        const _F.t('leftShift', 'Desviación a izquierda', 'Desvio à esquerda')
      ]);
    case PlusScoresMb1Id.bisap:
      return _M(
          id,
          'BISAP',
          Icons.analytics_outlined,
          'Gravedad temprana en pancreatitis aguda.',
          'Gravidade precoce na pancreatite aguda.',
          'Calcular en primeras 24 h; criterio original usa BUN >25 mg/dL.',
          'Calcular nas primeiras 24 h; critério original usa BUN >25 mg/dL.',
          'Wu et al., Gut 2008 · ACG acute pancreatitis guidance', [
        const _F.n('bun', 'BUN', 'BUN', unit: 'mg/dL', min: 0, max: 300),
        const _F.n('gcs', 'Glasgow', 'Glasgow', unit: '3–15', min: 3, max: 15),
        const _F.t('sirs', 'SIRS ≥2', 'SIRS ≥2'),
        const _F.n('age', 'Edad', 'Idade', unit: 'años/anos', min: 0, max: 130),
        const _F.t('effusion', 'Derrame pleural', 'Derrame pleural')
      ]);
    case PlusScoresMb1Id.hinchey:
      return _M(
          id,
          'Hinchey',
          Icons.layers_outlined,
          'Clasifica diverticulitis complicada/perforada.',
          'Classifica diverticulite complicada/perfurada.',
          'Distinguir clasificación original quirúrgica de variantes por TC.',
          'Diferenciar classificação original cirúrgica de variantes por TC.',
          'Hinchey 1978 · WSES 2020', [
        const _F.c(
            'stage',
            'Estadio',
            'Estágio',
            [
              _C(1, 'I · Absceso pericólico', 'I · Abscesso pericólico'),
              _C(2, 'II · Absceso distante', 'II · Abscesso distante'),
              _C(3, 'III · Peritonitis purulenta',
                  'III · Peritonite purulenta'),
              _C(4, 'IV · Peritonitis fecal', 'IV · Peritonite fecal')
            ],
            init: 1)
      ]);
    case PlusScoresMb1Id.silvermanAndersen:
      {
        const q = [
          _C(0, '0 · Ausente/normal', '0 · Ausente/normal'),
          _C(1, '1 · Leve', '1 · Leve'),
          _C(2, '2 · Marcado', '2 · Acentuado')
        ];
        return _M(
            id,
            'Silverman-Andersen',
            Icons.child_care_outlined,
            'Dificultad respiratoria neonatal.',
            'Desconforto respiratório neonatal.',
            'No sustituye oxigenación, gasometría ni evaluación neonatal completa.',
            'Não substitui oxigenação, gasometria nem avaliação neonatal completa.',
            'Silverman & Andersen, Pediatrics 1956', [
          const _F.c('thoraco', 'Movimiento toracoabdominal',
              'Movimento toracoabdominal', q),
          const _F.c(
              'intercostal', 'Tiraje intercostal', 'Tiragem intercostal', q),
          const _F.c('xiphoid', 'Retracción xifoidea', 'Retração xifoide', q),
          const _F.c('nasal', 'Aleteo nasal', 'Batimento de asa nasal', q),
          const _F.c('grunt', 'Quejido espiratorio', 'Gemido expiratório', q)
        ]);
      }
    case PlusScoresMb1Id.westley:
      return _M(
          id,
          'Westley · Crupe',
          Icons.air_rounded,
          'Clasifica gravedad clínica del crup.',
          'Classifica gravidade clínica do crupe.',
          'Evaluar al niño tranquilo; la agitación puede sobreestimar.',
          'Avaliar a criança calma; agitação pode superestimar.',
          'Westley et al. · contemporary croup guidance', [
        const _F.c('stridor', 'Estridor', 'Estridor', [
          _C(0, 'Ausente · 0', 'Ausente · 0'),
          _C(1, 'Con agitación · 1', 'Com agitação · 1'),
          _C(2, 'En reposo · 2', 'Em repouso · 2')
        ]),
        const _F.c('retractions', 'Retracciones', 'Retrações', [
          _C(0, 'Ausentes · 0', 'Ausentes · 0'),
          _C(1, 'Leves · 1', 'Leves · 1'),
          _C(2, 'Moderadas · 2', 'Moderadas · 2'),
          _C(3, 'Graves · 3', 'Graves · 3')
        ]),
        const _F.c('air', 'Entrada de aire', 'Entrada de ar', [
          _C(0, 'Normal · 0', 'Normal · 0'),
          _C(1, 'Disminuida · 1', 'Diminuída · 1'),
          _C(2, 'Muy disminuida · 2', 'Muito diminuída · 2')
        ]),
        const _F.c('cyanosis', 'Cianosis', 'Cianose', [
          _C(0, 'Ausente · 0', 'Ausente · 0'),
          _C(4, 'Con agitación · 4', 'Com agitação · 4'),
          _C(5, 'En reposo · 5', 'Em repouso · 5')
        ]),
        const _F.c('consciousness', 'Conciencia', 'Consciência', [
          _C(0, 'Normal · 0', 'Normal · 0'),
          _C(5, 'Alterada · 5', 'Alterada · 5')
        ])
      ]);
    case PlusScoresMb1Id.pediatricAppendicitis:
      return _M(
          id,
          'PAS · Pediatric Appendicitis Score',
          Icons.child_care_outlined,
          'Estratifica sospecha de apendicitis en niños.',
          'Estratifica suspeita de apendicite em crianças.',
          'No diagnosticar apendicitis pediátrica por score aislado.',
          'Não diagnosticar apendicite pediátrica por score isolado.',
          'Samuel 2002 · WSES 2020', [
        const _F.t('hop', 'Dolor con tos/salto/percusión · 2',
            'Dor com tosse/salto/percussão · 2'),
        const _F.t('anorexia', 'Anorexia', 'Anorexia'),
        const _F.t('fever', 'Fiebre', 'Febre'),
        const _F.t('nv', 'Náuseas/vómitos', 'Náuseas/vômitos'),
        const _F.t('rlq', 'Dolor FID · 2', 'Dor FID · 2'),
        const _F.t('migration', 'Migración a FID', 'Migração para FID'),
        const _F.t('leuko', 'Leucocitosis', 'Leucocitose'),
        const _F.t('neutro', 'Neutrofilia', 'Neutrofilia')
      ]);
    case PlusScoresMb1Id.lrinec:
      return _M(
          id,
          'LRINEC',
          Icons.biotech_outlined,
          'Score laboratorial asociado a infección necrosante.',
          'Score laboratorial associado à infecção necrosante.',
          'Sensibilidad insuficiente para excluir fascitis necrosante; creatinina original >1,6 mg/dL.',
          'Sensibilidade insuficiente para excluir fasciíte necrosante; creatinina original >1,6 mg/dL.',
          'Wong 2004 · Fernando 2019', [
        const _F.n('crp', 'PCR', 'PCR', unit: 'mg/L', min: 0, max: 1000),
        const _F.n('wbc', 'Leucocitos', 'Leucócitos',
            unit: '10³/µL', min: 0, max: 100),
        const _F.n('hb', 'Hemoglobina', 'Hemoglobina',
            unit: 'g/dL', min: 0, max: 30),
        const _F.n('na', 'Sodio', 'Sódio', unit: 'mmol/L', min: 80, max: 200),
        const _F.n('cr', 'Creatinina', 'Creatinina',
            unit: 'mg/dL', min: 0, max: 30),
        const _F.n('glucose', 'Glucosa', 'Glicose',
            unit: 'mg/dL', min: 0, max: 2000)
      ]);
    case PlusScoresMb1Id.mcIsaac:
      return _M(
          id,
          'McIsaac · Centor modificado',
          Icons.medical_services_outlined,
          'Probabilidad pretest de faringitis estreptocócica.',
          'Probabilidade pré-teste de faringite estreptocócica.',
          'No aplicar <3 años; no confirma etiología por sí solo.',
          'Não aplicar <3 anos; não confirma etiologia isoladamente.',
          'McIsaac et al. · streptococcal pharyngitis guidance', [
        const _F.t('fever', 'Fiebre >38 °C', 'Febre >38 °C'),
        const _F.t('noCough', 'Ausencia de tos', 'Ausência de tosse'),
        const _F.t('nodes', 'Adenopatía cervical anterior dolorosa',
            'Adenopatia cervical anterior dolorosa'),
        const _F.t('tonsil', 'Exudado/inflamación amigdalina',
            'Exsudato/inflamação tonsilar'),
        const _F.c(
            'ageBand',
            'Edad',
            'Idade',
            [
              _C(1, '3–14 · +1', '3–14 · +1'),
              _C(0, '15–44 · 0', '15–44 · 0'),
              _C(-1, '≥45 · -1', '≥45 · -1')
            ],
            init: 0)
      ]);
    case PlusScoresMb1Id.dukeIscvid2023:
      return _M(
          id,
          'Duke-ISCVID 2023',
          Icons.favorite_border_rounded,
          'Clasifica endocarditis infecciosa con criterios clínicos 2023.',
          'Classifica endocardite infecciosa pelos critérios clínicos 2023.',
          'Cada opción presupone verificación de la definición formal.',
          'Cada opção pressupõe verificação da definição formal.',
          'Fowler et al., Clin Infect Dis 2023 · ESC 2023', [
        const _F.t(
            'majorMicro', 'Mayor · microbiología', 'Maior · microbiologia'),
        const _F.t('majorImaging', 'Mayor · imagen', 'Maior · imagem'),
        const _F.t('majorSurgical', 'Mayor · hallazgo quirúrgico',
            'Maior · achado cirúrgico'),
        const _F.t(
            'minorPred', 'Menor · predisposición', 'Menor · predisposição'),
        const _F.t(
            'minorFever', 'Menor · fiebre >38 °C', 'Menor · febre >38 °C'),
        const _F.t('minorVascular', 'Menor · fenómeno vascular',
            'Menor · fenômeno vascular'),
        const _F.t('minorImmunologic', 'Menor · fenómeno inmunológico',
            'Menor · fenômeno imunológico'),
        const _F.t(
            'minorMicro', 'Menor · microbiología', 'Menor · microbiologia'),
        const _F.t('minorImaging', 'Menor · PET/CT precoz posimplante',
            'Menor · PET/CT precoce pós-implante'),
        const _F.t(
            'minorPhysical',
            'Menor · nueva regurgitación auscultatoria sin eco',
            'Menor · nova regurgitação auscultatória sem eco')
      ]);
    case PlusScoresMb1Id.caprini2013:
      return _M(
          id,
          'Caprini RAM 2013',
          Icons.shield_outlined,
          'Estratifica riesgo perioperatorio de tromboembolismo venoso.',
          'Estratifica risco perioperatório de tromboembolismo venoso.',
          'Usar el formulario 2013 completo; el puntaje no prescribe profilaxis por sí solo.',
          'Usar o formulário 2013 completo; a pontuação não prescreve profilaxia isoladamente.',
          'Caprini RAM 2013 · Cronin et al., completion guide 2019', [
        const _F.c('agePoints', 'Edad', 'Idade', [
          _C(0, '≤40 · 0', '≤40 · 0'),
          _C(1, '41–60 · 1', '41–60 · 1'),
          _C(2, '61–74 · 2', '61–74 · 2'),
          _C(3, '≥75 · 3', '≥75 · 3')
        ]),
        const _F.t('minorSurgery', 'Cirugía menor planificada <45 min · 1',
            'Cirurgia menor planejada <45 min · 1'),
        const _F.t(
            'majorSurgeryLastMonth',
            'Cirugía mayor en el último mes · 1',
            'Cirurgia maior no último mês · 1'),
        const _F.t('varicose', 'Várices visibles · 1', 'Varizes visíveis · 1'),
        const _F.t('ibd', 'Enfermedad inflamatoria intestinal · 1',
            'Doença inflamatória intestinal · 1'),
        const _F.t('swollenLegs', 'Edema de miembros inferiores · 1',
            'Edema de membros inferiores · 1'),
        const _F.t('bmi25', 'IMC ≥25 kg/m² · 1', 'IMC ≥25 kg/m² · 1'),
        const _F.t(
            'mi', 'Infarto de miocardio · 1', 'Infarto do miocárdio · 1'),
        const _F.t(
            'chf', 'Insuficiencia cardíaca · 1', 'Insuficiência cardíaca · 1'),
        const _F.t(
            'seriousInfection', 'Infección grave · 1', 'Infecção grave · 1'),
        const _F.t(
            'lungDisease', 'Enfermedad pulmonar · 1', 'Doença pulmonar · 1'),
        const _F.t('reducedMobilityLt72', 'Movilidad reducida <72 h · 1',
            'Mobilidade reduzida <72 h · 1'),
        const _F.t('hormone', 'ACO/TRH · 1', 'ACO/TRH · 1'),
        const _F.t('pregnancyPostpartum', 'Embarazo o puerperio <1 mes · 1',
            'Gestação ou puerpério <1 mês · 1'),
        const _F.t(
            'obstetricHistory',
            'Antecedente obstétrico asociado a trombosis · 1',
            'Antecedente obstétrico associado à trombose · 1'),
        const _F.t('bmi40', 'IMC >40 · adicional 2013 · 1',
            'IMC >40 · adicional 2013 · 1'),
        const _F.t('smoking', 'Tabaquismo · adicional 2013 · 1',
            'Tabagismo · adicional 2013 · 1'),
        const _F.t(
            'insulinDiabetes',
            'Diabetes con insulina · adicional 2013 · 1',
            'Diabetes com insulina · adicional 2013 · 1'),
        const _F.t('chemotherapy', 'Quimioterapia · adicional 2013 · 1',
            'Quimioterapia · adicional 2013 · 1'),
        const _F.t('transfusion', 'Transfusión sanguínea · adicional 2013 · 1',
            'Transfusão sanguínea · adicional 2013 · 1'),
        const _F.t('surgeryOver2h', 'Cirugía >2 h · adicional 2013 · 1',
            'Cirurgia >2 h · adicional 2013 · 1'),
        const _F.t('malignancy', 'Neoplasia actual o previa · 2',
            'Neoplasia atual ou prévia · 2'),
        const _F.t(
            'plannedMajorSurgery',
            'Cirugía mayor planificada >45 min · 2',
            'Cirurgia maior planejada >45 min · 2'),
        const _F.t('cast', 'Yeso/inmovilización reciente · 2',
            'Gesso/imobilização recente · 2'),
        const _F.t('centralVenous', 'Acceso venoso central · 2',
            'Acesso venoso central · 2'),
        const _F.t(
            'bed72', 'Reposo en cama ≥72 h · 2', 'Repouso no leito ≥72 h · 2'),
        const _F.t('priorVte', 'TEV previo · 3', 'TEV prévio · 3'),
        const _F.t('familyVte', 'Historia familiar de TEV · 3',
            'História familiar de TEV · 3'),
        const _F.t('thrombophilia', 'Trombofilia conocida · 3',
            'Trombofilia conhecida · 3'),
        const _F.t(
            'arthroplasty',
            'Artroplastia electiva de cadera/rodilla · 5',
            'Artroplastia eletiva de quadril/joelho · 5'),
        const _F.t(
            'hipPelvisLegFracture',
            'Fractura de cadera/pelvis/pierna · 5',
            'Fratura de quadril/pelve/perna · 5'),
        const _F.t('seriousTrauma', 'Trauma grave · 5', 'Trauma grave · 5'),
        const _F.t('spinalCord', 'Lesión medular con parálisis · 5',
            'Lesão medular com paralisia · 5'),
        const _F.t('stroke', 'ACV reciente · 5', 'AVC recente · 5')
      ]);
    case PlusScoresMb1Id.rcri:
      return _M(
          id,
          'RCRI · Índice de Lee',
          Icons.monitor_heart_outlined,
          'Estima riesgo cardíaco perioperatorio en cirugía no cardíaca.',
          'Estima risco cardíaco perioperatório em cirurgia não cardíaca.',
          'Integrar con riesgo del procedimiento, capacidad funcional y evaluación perioperatoria contemporánea.',
          'Integrar ao risco do procedimento, capacidade funcional e avaliação perioperatória contemporânea.',
          'Lee et al., Circulation 1999 · ACC/AHA perioperative guideline 2024',
          [
            const _F.t('highRiskSurgery', 'Cirugía de alto riesgo según RCRI',
                'Cirurgia de alto risco segundo RCRI'),
            const _F.t('ihd', 'Cardiopatía isquémica', 'Cardiopatia isquêmica'),
            const _F.t(
                'hf', 'Insuficiencia cardíaca', 'Insuficiência cardíaca'),
            const _F.t(
                'cvd', 'Enfermedad cerebrovascular', 'Doença cerebrovascular'),
            const _F.t('insulin', 'Diabetes tratada con insulina',
                'Diabetes tratada com insulina'),
            const _F.t('cr2', 'Creatinina >2,0 mg/dL', 'Creatinina >2,0 mg/dL')
          ]);
    case PlusScoresMb1Id.bishop:
      return _M(
          id,
          'Bishop',
          Icons.pregnant_woman_outlined,
          'Evalúa madurez cervical antes de inducción del trabajo de parto.',
          'Avalia maturidade cervical antes da indução do trabalho de parto.',
          'Examen dependiente del observador; integrar indicación obstétrica y contexto materno-fetal.',
          'Exame dependente do observador; integrar indicação obstétrica e contexto materno-fetal.',
          'Bishop 1964 · contemporary induction-of-labor guidance', [
        const _F.c('dilation', 'Dilatación', 'Dilatação', [
          _C(0, 'Cerrado · 0', 'Fechado · 0'),
          _C(1, '1–2 cm · 1', '1–2 cm · 1'),
          _C(2, '3–4 cm · 2', '3–4 cm · 2'),
          _C(3, '≥5 cm · 3', '≥5 cm · 3')
        ]),
        const _F.c('effacement', 'Borramiento', 'Apagamento', [
          _C(0, '0–30% · 0', '0–30% · 0'),
          _C(1, '40–50% · 1', '40–50% · 1'),
          _C(2, '60–70% · 2', '60–70% · 2'),
          _C(3, '≥80% · 3', '≥80% · 3')
        ]),
        const _F.c('consistency', 'Consistencia', 'Consistência', [
          _C(0, 'Firme · 0', 'Firme · 0'),
          _C(1, 'Media · 1', 'Média · 1'),
          _C(2, 'Blanda · 2', 'Macia · 2')
        ]),
        const _F.c('position', 'Posición cervical', 'Posição cervical', [
          _C(0, 'Posterior · 0', 'Posterior · 0'),
          _C(1, 'Media · 1', 'Média · 1'),
          _C(2, 'Anterior · 2', 'Anterior · 2')
        ]),
        const _F.c('station', 'Estación fetal', 'Altura da apresentação', [
          _C(0, '-3 · 0', '-3 · 0'),
          _C(1, '-2 · 1', '-2 · 1'),
          _C(2, '-1/0 · 2', '-1/0 · 2'),
          _C(3, '+1/+2 · 3', '+1/+2 · 3')
        ])
      ]);
    case PlusScoresMb1Id.hellpTennessee:
      return _M(
          id,
          'HELLP · Tennessee',
          Icons.warning_amber_rounded,
          'Evalúa los tres dominios clásicos de síndrome HELLP.',
          'Avalia os três domínios clássicos da síndrome HELLP.',
          'HELLP puede ser parcial; no cumplir el conjunto completo no excluye enfermedad obstétrica grave.',
          'HELLP pode ser parcial; não preencher o conjunto completo não exclui doença obstétrica grave.',
          'Weinstein · Sibai · Tennessee HELLP criteria · contemporary hypertensive-disorders guidance',
          [
            const _F.n('ldh', 'LDH', 'LDH', unit: 'U/L', min: 0, max: 10000),
            const _F.n('ast', 'AST/TGO', 'AST/TGO',
                unit: 'U/L', min: 0, max: 10000),
            const _F.n('platelets', 'Plaquetas', 'Plaquetas',
                unit: '/mm³', min: 0, max: 1000000),
            const _F.n('bili', 'Bilirrubina indirecta', 'Bilirrubina indireta',
                unit: 'mg/dL', min: 0, max: 50),
            const _F.t(
                'hemolysis',
                'Esquistocitos/u otra evidencia de hemólisis',
                'Esquizócitos/outra evidência de hemólise')
          ]);
    case PlusScoresMb1Id.ecog:
      return _M(
          id,
          'ECOG Performance Status',
          Icons.accessibility_new_outlined,
          'Clasifica estado funcional en oncología.',
          'Classifica estado funcional em oncologia.',
          'Registrar el estado funcional basal relevante y el momento de evaluación; una descompensación aguda reversible puede distorsionar la clasificación.',
          'Registrar o estado funcional basal relevante e o momento da avaliação; descompensação aguda reversível pode distorcer a classificação.',
          'Oken et al., Am J Clin Oncol 1982', [
        const _F.c('grade', 'Grado ECOG', 'Grau ECOG', [
          _C(0, '0 · Totalmente activo', '0 · Totalmente ativo'),
          _C(1, '1 · Restricción de actividad intensa',
              '1 · Restrição de atividade intensa'),
          _C(2, '2 · Ambulatorio/autocuidado', '2 · Ambulatorial/autocuidado'),
          _C(3, '3 · Cama/silla >50%', '3 · Leito/cadeira >50%'),
          _C(4, '4 · Totalmente dependiente', '4 · Totalmente dependente'),
          _C(5, '5 · Fallecido', '5 · Óbito')
        ])
      ]);
    case PlusScoresMb1Id.mascc:
      return _M(
          id,
          'MASCC · Neutropenia febril',
          Icons.shield_outlined,
          'Identifica pacientes con neutropenia febril de menor riesgo por MASCC.',
          'Identifica pacientes com neutropenia febril de menor risco pelo MASCC.',
          'No sustituye estabilidad clínica, foco, función orgánica, soporte social ni criterios específicos de hematología/transplante.',
          'Não substitui estabilidade clínica, foco, função orgânica, suporte social nem critérios específicos de hematologia/transplante.',
          'Klastersky et al., J Clin Oncol 2000 · contemporary febrile-neutropenia guidance',
          [
            const _F.c(
                'burden',
                'Carga de enfermedad',
                'Carga da doença',
                [
                  _C(5, 'Leve/asintomática · 5', 'Leve/assintomática · 5'),
                  _C(3, 'Moderada · 3', 'Moderada · 3'),
                  _C(0, 'Grave · 0', 'Grave · 0')
                ],
                init: 5),
            const _F.t(
                'noHypotension', 'Sin hipotensión · 5', 'Sem hipotensão · 5'),
            const _F.t('noCopd', 'Sin EPOC · 4', 'Sem DPOC · 4'),
            const _F.t(
                'tumor',
                'Tumor sólido o hematológico sin infección fúngica previa · 4',
                'Tumor sólido ou hematológico sem infecção fúngica prévia · 4'),
            const _F.t(
                'noDehydration',
                'Sin deshidratación que requiera IV · 3',
                'Sem desidratação que exija IV · 3'),
            const _F.t('outpatient', 'Inicio ambulatorio · 3',
                'Início ambulatorial · 3'),
            const _F.t('under60', 'Edad <60 · 2', 'Idade <60 · 2')
          ]);
    case PlusScoresMb1Id.ottawaAnkleFoot:
      return _M(
          id,
          'Ottawa · Tobillo y Pie',
          Icons.directions_walk_rounded,
          'Regla de decisión para radiografía tras trauma de tobillo o mediopié.',
          'Regra de decisão para radiografia após trauma de tornozelo ou médio-pé.',
          'No aplicar cuando el examen no es confiable o fuera de la población validada. La incapacidad para 4 pasos debe considerar el momento inmediato y la evaluación.',
          'Não aplicar quando o exame não é confiável ou fora da população validada. A incapacidade para 4 passos deve considerar o momento imediato e a avaliação.',
          'Stiell et al., JAMA 1994 · Ottawa Ankle Rules', [
        const _F.t(
            'malleolarPain', 'Dolor en zona maleolar', 'Dor em zona maleolar'),
        const _F.t('midfootPain', 'Dolor en mediopié', 'Dor no médio-pé'),
        const _F.t('latMalleolus', 'Dolor óseo borde posterior maléolo lateral',
            'Dor óssea borda posterior maléolo lateral'),
        const _F.t('medMalleolus', 'Dolor óseo borde posterior maléolo medial',
            'Dor óssea borda posterior maléolo medial'),
        const _F.t('fifth', 'Dolor base del 5º metatarsiano',
            'Dor na base do 5º metatarso'),
        const _F.t('navicular', 'Dolor en navicular', 'Dor no navicular'),
        const _F.t(
            'fourSteps',
            'No puede dar 4 pasos inmediatamente y en evaluación',
            'Não consegue dar 4 passos imediatamente e na avaliação')
      ]);
    case PlusScoresMb1Id.ottawaKnee:
      return _M(
          id,
          'Ottawa · Rodilla',
          Icons.accessibility_new_outlined,
          'Regla de decisión para radiografía en trauma agudo de rodilla.',
          'Regra de decisão para radiografia no trauma agudo de joelho.',
          'Evalúa riesgo de fractura, no lesión meniscal o ligamentaria.',
          'Avalia risco de fratura, não lesão meniscal ou ligamentar.',
          'Stiell et al., JAMA 1996 · Ottawa Knee Rule', [
        const _F.t('age55', 'Edad ≥55 años', 'Idade ≥55 anos'),
        const _F.t(
            'patella', 'Dolor aislado de rótula', 'Dor isolada na patela'),
        const _F.t(
            'fibula', 'Dolor en cabeza de fíbula', 'Dor na cabeça da fíbula'),
        const _F.t(
            'flex90', 'No puede flexionar 90°', 'Não consegue flexionar 90°'),
        const _F.t(
            'fourSteps', 'No puede dar 4 pasos', 'Não consegue dar 4 passos')
      ]);
    case PlusScoresMb1Id.nexus:
      return _M(
          id,
          'NEXUS · Columna cervical',
          Icons.health_and_safety_outlined,
          'Identifica pacientes de bajo riesgo de lesión cervical tras trauma contuso.',
          'Identifica pacientes de baixo risco de lesão cervical após trauma contuso.',
          'Aplicar en población apropiada y con examen confiable; edad avanzada puede reducir el desempeño.',
          'Aplicar em população apropriada e com exame confiável; idade avançada pode reduzir o desempenho.',
          'Hoffman et al., N Engl J Med 2000', [
        const _F.t('midline', 'Dolor cervical en línea media',
            'Dor cervical em linha média'),
        const _F.t(
            'neuro', 'Déficit neurológico focal', 'Déficit neurológico focal'),
        const _F.t('alertness', 'Alteración del estado de alerta',
            'Alteração do estado de alerta'),
        const _F.t('intoxication', 'Intoxicación', 'Intoxicação'),
        const _F.t('distracting', 'Lesión dolorosa distractora',
            'Lesão dolorosa distratora')
      ]);
    case PlusScoresMb1Id.canadianCSpine:
      return _M(
          id,
          'Canadian C-Spine Rule',
          Icons.rule_rounded,
          'Regla para imagen cervical en trauma contuso de pacientes alertas y estables.',
          'Regra para imagem cervical no trauma contuso em pacientes alertas e estáveis.',
          'Aplicar solo dentro de criterios de inclusión; la rotación debe ser activa, nunca forzada por el examinador.',
          'Aplicar apenas dentro dos critérios de inclusão; rotação deve ser ativa, nunca forçada pelo examinador.',
          'Stiell et al., JAMA 2001', [
        const _F.t('applicable', 'Paciente alerta y estable · regla aplicable',
            'Paciente alerta e estável · regra aplicável',
            init: true),
        const _F.t('age65', 'Alto riesgo · edad ≥65', 'Alto risco · idade ≥65'),
        const _F.t('dangerous', 'Alto riesgo · mecanismo peligroso',
            'Alto risco · mecanismo perigoso'),
        const _F.t('paresthesia', 'Alto riesgo · parestesias',
            'Alto risco · parestesias'),
        const _F.t('rearEnd', 'Bajo riesgo · colisión trasera simple',
            'Baixo risco · colisão traseira simples'),
        const _F.t('sitting', 'Bajo riesgo · sentado en urgencias',
            'Baixo risco · sentado na emergência'),
        const _F.t('ambulatory', 'Bajo riesgo · caminó en algún momento',
            'Baixo risco · caminhou em algum momento'),
        const _F.t('delayed', 'Bajo riesgo · dolor cervical tardío',
            'Baixo risco · dor cervical tardia'),
        const _F.t('noMidline', 'Bajo riesgo · sin dolor en línea media',
            'Baixo risco · sem dor em linha média'),
        const _F.t('rotate45', 'Rotación activa 45° a ambos lados',
            'Rotação ativa 45° para ambos os lados')
      ]);
    case PlusScoresMb1Id.gustiloAnderson:
      return _M(
          id,
          'Gustilo-Anderson',
          Icons.medical_services_outlined,
          'Clasifica fracturas expuestas por daño de partes blandas y lesión vascular.',
          'Classifica fraturas expostas por dano de partes moles e lesão vascular.',
          'La clasificación definitiva se establece tras exploración y desbridamiento; la herida inicial puede subestimar la lesión.',
          'A classificação definitiva é estabelecida após exploração e desbridamento; a ferida inicial pode subestimar a lesão.',
          'Gustilo & Anderson 1976 · Gustilo et al. 1984', [
        const _F.c(
            'grade',
            'Tipo',
            'Tipo',
            [
              _C(1, 'I', 'I'),
              _C(2, 'II', 'II'),
              _C(3, 'IIIA', 'IIIA'),
              _C(4, 'IIIB', 'IIIB'),
              _C(5, 'IIIC', 'IIIC')
            ],
            init: 1)
      ]);
    case PlusScoresMb1Id.mess:
      return _M(
          id,
          'MESS',
          Icons.warning_amber_rounded,
          'Resume gravedad fisiológica y anatómica de una extremidad severamente lesionada.',
          'Resume gravidade fisiológica e anatômica de extremidade gravemente lesionada.',
          'El umbral histórico ≥7 no debe usarse como indicación automática de amputación en la práctica moderna.',
          'O limiar histórico ≥7 não deve ser usado como indicação automática de amputação na prática moderna.',
          'Johansen et al., J Trauma 1990 · LEAP/Bosse modern validation context',
          [
            const _F.c(
                'skeletal',
                'Lesión esquelética/partes blandas',
                'Lesão esquelética/partes moles',
                [
                  _C(1, 'Baja energía · 1', 'Baixa energia · 1'),
                  _C(2, 'Media energía · 2', 'Média energia · 2'),
                  _C(3, 'Alta energía · 3', 'Alta energia · 3'),
                  _C(4, 'Aplastamiento masivo · 4', 'Esmagamento maciço · 4')
                ],
                init: 1),
            const _F.c(
                'ischemia', 'Isquemia del miembro', 'Isquemia do membro', [
              _C(0, 'Perfusión normal · 0', 'Perfusão normal · 0'),
              _C(1, 'Pulso reducido sin isquemia · 1',
                  'Pulso reduzido sem isquemia · 1'),
              _C(2, 'Sin pulso/llenado lento · 2',
                  'Sem pulso/enchimento lento · 2'),
              _C(3, 'Frío/paralizado/insensible · 3',
                  'Frio/paralisado/insensível · 3')
            ]),
            const _F.t('ischemia6h', 'Isquemia >6 h · duplica componente',
                'Isquemia >6 h · duplica componente'),
            const _F.c('shock', 'Choque', 'Choque', [
              _C(0, 'Normotenso · 0', 'Normotenso · 0'),
              _C(1, 'Hipotensión transitoria · 1',
                  'Hipotensão transitória · 1'),
              _C(2, 'Hipotensión persistente · 2', 'Hipotensão persistente · 2')
            ]),
            const _F.c('agePoints', 'Edad', 'Idade', [
              _C(0, '<30 · 0', '<30 · 0'),
              _C(1, '30–50 · 1', '30–50 · 1'),
              _C(2, '>50 · 2', '>50 · 2')
            ])
          ]);
  }
}
