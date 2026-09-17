import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/app_provider.dart';
import 'plus_scores_mb2_engine.dart';

enum PlusScoresMb2Specialty {
  psychiatry,
  endocrinology,
  traumaSeverity,
  rheumatology,
  geriatrics,
  hematology,
  urology,
  neonatology,
}

class PlusScoresMb2SpecialtyGrid extends StatelessWidget {
  const PlusScoresMb2SpecialtyGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final isEs = p.lang == 'es';
    final dark = p.darkMode;
    final text = dark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    final sub = dark ? const Color(0xFFAEB9CC) : const Color(0xFF64748B);
    final surface = dark ? const Color(0xFF252930) : Colors.white;
    final border = dark ? const Color(0xFF374151) : const Color(0xFFDDE3E9);
    const accent = Color(0xFF009C3B);

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final columns = constraints.maxWidth >= 760 ? 3 : 2;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEs ? 'Otras especialidades' : 'Outras especialidades',
              style: TextStyle(
                color: text,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              isEs
                  ? 'Segunda expansión del catálogo +SCORES, con 25 herramientas adicionales.'
                  : 'Segunda expansão do catálogo +SCORES, com 25 ferramentas adicionais.',
              style: TextStyle(
                color: sub,
                fontSize: 11.5,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: gap,
              runSpacing: gap,
              children: PlusScoresMb2Specialty.values.map((specialty) {
                return SizedBox(
                  width: width,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PlusScoresMb2WorkspaceScreen(
                              specialty: specialty,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 92),
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: surface,
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
                                    _specialtyIcon(specialty),
                                    size: 18,
                                    color: accent,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${_idsForSpecialty(specialty).length}',
                                  style: const TextStyle(
                                    color: accent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 9),
                            Text(
                              _specialtyName(specialty, isEs),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: text,
                                fontSize: 11.8,
                                height: 1.1,
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

class PlusScoresMb2WorkspaceScreen extends StatelessWidget {
  final PlusScoresMb2Specialty specialty;

  const PlusScoresMb2WorkspaceScreen({
    super.key,
    required this.specialty,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final isEs = p.lang == 'es';
    final dark = p.darkMode;
    final bg = dark ? const Color(0xFF1A1D23) : const Color(0xFFECF0F4);
    final text = dark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    final sub = dark ? const Color(0xFFAEB9CC) : const Color(0xFF64748B);
    final surface = dark ? const Color(0xFF252930) : Colors.white;
    final border = dark ? const Color(0xFF374151) : const Color(0xFFDDE3E9);
    const accent = Color(0xFF009C3B);
    final ids = _idsForSpecialty(specialty);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: dark ? const Color(0xFF111622) : Colors.white,
        foregroundColor: text,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '+SCORES',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
            Text(
              _specialtyName(specialty, isEs),
              style: TextStyle(
                color: sub,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 120),
        itemCount: ids.length,
        separatorBuilder: (_, __) => const SizedBox(height: 9),
        itemBuilder: (context, index) {
          final meta = _meta(ids[index]);
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PlusScoresMb2DetailScreen(id: meta.id),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: border, width: 0.7),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(meta.icon, color: accent, size: 21),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            meta.name,
                            style: TextStyle(
                              color: text,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isEs ? meta.purposeEs : meta.purposePt,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: sub,
                              height: 1.25,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right_rounded, color: accent),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class PlusScoresMb2DetailScreen extends StatefulWidget {
  final PlusScoresMb2Id id;

  const PlusScoresMb2DetailScreen({
    super.key,
    required this.id,
  });

  @override
  State<PlusScoresMb2DetailScreen> createState() =>
      _PlusScoresMb2DetailScreenState();
}

class _PlusScoresMb2DetailScreenState extends State<PlusScoresMb2DetailScreen> {
  late final _ScoreMeta meta;
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _toggles = {};
  final Map<String, int> _choices = {};
  _Outcome? _outcome;

  @override
  void initState() {
    super.initState();
    meta = _meta(widget.id);
    for (final field in meta.fields) {
      switch (field.kind) {
        case _FieldKind.number:
          _controllers[field.key] = TextEditingController(
            text: field.initialNumber?.toString() ?? '',
          );
          break;
        case _FieldKind.toggle:
          _toggles[field.key] = field.initialBool;
          break;
        case _FieldKind.choice:
          _choices[field.key] = field.initialChoice ??
              (field.choices.isEmpty ? 0 : field.choices.first.value);
          break;
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _b(String key) => _toggles[key] ?? false;
  int _c(String key) => _choices[key] ?? 0;

  double _n(String key) {
    final raw = _controllers[key]?.text.trim().replaceAll(',', '.') ?? '';
    return double.parse(raw);
  }

  bool _validateNumbers(bool isEs) {
    for (final field in meta.fields.where((f) => f.kind == _FieldKind.number)) {
      final raw =
          _controllers[field.key]?.text.trim().replaceAll(',', '.') ?? '';
      final value = double.tryParse(raw);
      if (value == null ||
          (field.min != null && value < field.min!) ||
          (field.max != null && value > field.max!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEs
                  ? 'Revise el campo: ${field.labelEs}.'
                  : 'Revise o campo: ${field.labelPt}.',
            ),
          ),
        );
        return false;
      }
    }
    return true;
  }

  Future<void> _openFrax(bool isEs) async {
    final uri = Uri.parse(isEs
        ? 'https://fraxplus.org/es/calculation-tool'
        : 'https://fraxplus.org/calculation-tool');
    final ok = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEs
                ? 'No fue posible abrir FRAXplus.'
                : 'Não foi possível abrir o FRAXplus.',
          ),
        ),
      );
    }
  }

  void _calculate(bool isEs) {
    if (!_validateNumbers(isEs)) return;
    try {
      final out = _calculateOutcome(widget.id);
      setState(() => _outcome = out);
    } on Object {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEs
                ? 'No fue posible calcular. Revise los datos ingresados.'
                : 'Não foi possível calcular. Revise os dados informados.',
          ),
        ),
      );
    }
  }

  _Outcome _calculateOutcome(PlusScoresMb2Id id) {
    switch (id) {
      case PlusScoresMb2Id.phq9:
        final items = List<int>.generate(9, (i) => _c('q${i + 1}'));
        final score = PlusScoresMb2Engine.phq9(items);
        final bandIndex = score <= 4
            ? 0
            : score <= 9
                ? 1
                : score <= 14
                    ? 2
                    : score <= 19
                        ? 3
                        : 4;
        const bandsEs = [
          'Mínima',
          'Leve',
          'Moderada',
          'Moderadamente grave',
          'Grave'
        ];
        const bandsPt = [
          'Mínima',
          'Leve',
          'Moderada',
          'Moderadamente grave',
          'Grave'
        ];
        final item9 = items[8];
        return _Outcome(
          value: '$score / 27',
          bandEs: bandsEs[bandIndex],
          bandPt: bandsPt[bandIndex],
          interpretationEs: item9 > 0
              ? 'El ítem 9 fue positivo. El puntaje no sustituye una evaluación directa e inmediata de seguridad, ideación, intención, plan y medios.'
              : 'Cuantifica síntomas depresivos en las últimas 2 semanas. Confirmar diagnóstico y repercusión funcional clínicamente.',
          interpretationPt: item9 > 0
              ? 'O item 9 foi positivo. A pontuação não substitui avaliação direta e imediata de segurança, ideação, intenção, plano e meios.'
              : 'Quantifica sintomas depressivos nas últimas 2 semanas. Confirmar diagnóstico e repercussão funcional clinicamente.',
        );

      case PlusScoresMb2Id.sadPersonsHistorical:
        final keys = [
          'sex',
          'age',
          'depression',
          'previous',
          'ethanol',
          'rational',
          'social',
          'organized',
          'spouse',
          'sickness',
        ];
        final score = PlusScoresMb2Engine.sadPersonsHistorical(
          keys.map(_b).toList(),
        );
        return _Outcome(
          value: '$score / 10',
          bandEs: 'Registro histórico · NO estratificar riesgo',
          bandPt: 'Registro histórico · NÃO estratificar risco',
          interpretationEs:
              'No utilice este resultado para predecir suicidio, etiquetar riesgo bajo/medio/alto, decidir tratamiento, ingreso o alta. Realice formulación clínica y evaluación de seguridad.',
          interpretationPt:
              'Não use este resultado para prever suicídio, rotular risco baixo/médio/alto, decidir tratamento, internação ou alta. Faça formulação clínica e avaliação de segurança.',
        );

      case PlusScoresMb2Id.fraxOfficial:
        return const _Outcome(
          value: 'FRAXplus®',
          bandEs: 'Calculadora oficial',
          bandPt: 'Calculadora oficial',
          interpretationEs:
              'El cálculo se realiza únicamente en el motor oficial FRAXplus para preservar el modelo validado por país.',
          interpretationPt:
              'O cálculo é realizado apenas no motor oficial FRAXplus para preservar o modelo validado por país.',
        );

      case PlusScoresMb2Id.findrisc:
        final score = PlusScoresMb2Engine.findrisc(
          ageYears: _n('age'),
          bmi: _n('bmi'),
          waistCm: _n('waist'),
          female: _c('sex') == 1,
          physicalActivity30MinDaily: _b('activity'),
          dailyFruitVegetables: _b('produce'),
          antihypertensiveMedication: _b('bpMeds'),
          priorHighGlucose: _b('highGlucose'),
          familyHistoryPoints: _c('family'),
        );
        final band = score <= 6
            ? 0
            : score <= 11
                ? 1
                : score <= 14
                    ? 2
                    : score <= 20
                        ? 3
                        : 4;
        const es = [
          'Bajo · ~1%',
          'Ligeramente elevado · ~4%',
          'Moderado · ~17%',
          'Alto · ~33%',
          'Muy alto · ~50%'
        ];
        const pt = [
          'Baixo · ~1%',
          'Levemente elevado · ~4%',
          'Moderado · ~17%',
          'Alto · ~33%',
          'Muito alto · ~50%'
        ];
        return _Outcome(
          value: '$score / 26',
          bandEs: es[band],
          bandPt: pt[band],
          interpretationEs:
              'Estimación poblacional del riesgo de diabetes tipo 2 a 10 años. No diagnostica diabetes ni reemplaza glucemia/HbA1c.',
          interpretationPt:
              'Estimativa populacional do risco de diabetes tipo 2 em 10 anos. Não diagnostica diabetes nem substitui glicemia/HbA1c.',
        );

      case PlusScoresMb2Id.burchWartofsky:
        final score = PlusScoresMb2Engine.burchWartofsky(
          temperatureC: _n('temp'),
          heartRate: _n('hr'),
          giHepaticPoints: _c('gi'),
          cnsPoints: _c('cns'),
          chfPoints: _c('chf'),
          atrialFibrillation: _b('af'),
          precipitatingEvent: _b('precip'),
        );
        final band = score >= 45
            ? 2
            : score >= 25
                ? 1
                : 0;
        return _Outcome(
          value: '$score',
          bandEs: [
            'Tormenta poco probable',
            'Tormenta inminente/posible',
            'Altamente sugestivo'
          ][band],
          bandPt: [
            'Tempestade pouco provável',
            'Tempestade iminente/possível',
            'Altamente sugestivo'
          ][band],
          interpretationEs:
              'BWPS es una ayuda clínica. El diagnóstico de tormenta tiroidea sigue siendo clínico y puede requerir tratamiento antes de confirmación laboratorial.',
          interpretationPt:
              'BWPS é auxílio clínico. O diagnóstico de tempestade tireotóxica continua clínico e pode exigir tratamento antes da confirmação laboratorial.',
        );

      case PlusScoresMb2Id.revisedTraumaScore:
        final r = PlusScoresMb2Engine.revisedTraumaScore(
          gcs: _n('gcs').round(),
          systolicBp: _n('sbp'),
          respiratoryRate: _n('rr'),
        );
        return _Outcome(
          value: r.weighted.toStringAsFixed(3),
          bandEs: 'RTS ponderado · máximo 7,841',
          bandPt: 'RTS ponderado · máximo 7,841',
          interpretationEs:
              'Códigos: GCS ${r.gcsCode}, PAS ${r.sbpCode}, FR ${r.rrCode}. Un valor menor refleja mayor alteración fisiológica; no sustituye triage anatómico ni juicio de trauma.',
          interpretationPt:
              'Códigos: GCS ${r.gcsCode}, PAS ${r.sbpCode}, FR ${r.rrCode}. Valor menor reflete maior alteração fisiológica; não substitui triagem anatômica nem julgamento em trauma.',
        );

      case PlusScoresMb2Id.injurySeverityScore:
        final score = PlusScoresMb2Engine.injurySeverityScore(
          topAisRegion1: _c('ais1'),
          topAisRegion2: _c('ais2'),
          topAisRegion3: _c('ais3'),
        );
        return _Outcome(
          value: '$score / 75',
          bandEs:
              score > 15 ? 'Trauma mayor por umbral convencional' : 'ISS ≤15',
          bandPt:
              score > 15 ? 'Trauma maior pelo limiar convencional' : 'ISS ≤15',
          interpretationEs:
              'Ingrese las tres mayores puntuaciones AIS de tres regiones corporales distintas. AIS 6 asigna ISS 75 automáticamente.',
          interpretationPt:
              'Informe as três maiores pontuações AIS de três regiões corporais distintas. AIS 6 atribui ISS 75 automaticamente.',
        );

      case PlusScoresMb2Id.atlsHemorrhagicShock:
        final cls =
            PlusScoresMb2Engine.atlsHemorrhagicShockClass(_n('bloodLoss'));
        return _Outcome(
          value: 'Classe $cls',
          bandEs: 'Clasificación fisiológica histórica ATLS',
          bandPt: 'Classificação fisiológica histórica ATLS',
          interpretationEs:
              'La clase resume pérdida hemática estimada. ATLS 11 enfatiza evaluación fisiológica y reanimación individualizada; no convierta la clase en un protocolo rígido de volumen.',
          interpretationPt:
              'A classe resume perda sanguínea estimada. ATLS 11 enfatiza avaliação fisiológica e ressuscitação individualizada; não converta a classe em protocolo rígido de volume.',
        );

      case PlusScoresMb2Id.das28:
        final useCrp = _c('method') == 1;
        final score = useCrp
            ? PlusScoresMb2Engine.das28Crp(
                tenderJointCount28: _n('tjc').round(),
                swollenJointCount28: _n('sjc').round(),
                crpMgL: _n('marker'),
                patientGlobalMm: _n('global'),
              )
            : PlusScoresMb2Engine.das28Esr(
                tenderJointCount28: _n('tjc').round(),
                swollenJointCount28: _n('sjc').round(),
                esrMmH: _n('marker'),
                patientGlobalMm: _n('global'),
              );
        final band = score < 2.6
            ? 0
            : score < 3.2
                ? 1
                : score <= 5.1
                    ? 2
                    : 3;
        return _Outcome(
          value: score.toStringAsFixed(2),
          bandEs: [
            'Remisión',
            'Actividad baja',
            'Actividad moderada',
            'Actividad alta'
          ][band],
          bandPt: [
            'Remissão',
            'Atividade baixa',
            'Atividade moderada',
            'Atividade alta'
          ][band],
          interpretationEs:
              'Versión ${useCrp ? 'CRP' : 'ESR'} seleccionada. No mezcle fórmulas entre seguimientos del mismo paciente.',
          interpretationPt:
              'Versão ${useCrp ? 'CRP' : 'ESR'} selecionada. Não misture fórmulas entre acompanhamentos do mesmo paciente.',
        );

      case PlusScoresMb2Id.sledai2k:
        final score = PlusScoresMb2Engine.sledai2k(
          weight8: List.generate(8, (i) => _b('w8_$i')),
          weight4: List.generate(6, (i) => _b('w4_$i')),
          weight2: List.generate(7, (i) => _b('w2_$i')),
          weight1: List.generate(3, (i) => _b('w1_$i')),
        );
        return _Outcome(
          value: '$score',
          bandEs: 'SLEDAI-2K total',
          bandPt: 'SLEDAI-2K total',
          interpretationEs:
              'Mayor puntaje indica mayor actividad acumulada. Los umbrales de actividad y respuesta dependen del protocolo/estudio; no automatizamos una conducta terapéutica.',
          interpretationPt:
              'Pontuação maior indica maior atividade acumulada. Limiares de atividade e resposta dependem do protocolo/estudo; não automatizamos conduta terapêutica.',
        );

      case PlusScoresMb2Id.basdai:
        final score = PlusScoresMb2Engine.basdai(
          List.generate(6, (i) => _n('b${i + 1}')),
        );
        return _Outcome(
          value: score.toStringAsFixed(2),
          bandEs: score >= 4
              ? 'Actividad elevada por umbral clásico'
              : 'Por debajo de 4',
          bandPt: score >= 4
              ? 'Atividade elevada pelo limiar clássico'
              : 'Abaixo de 4',
          interpretationEs:
              'BASDAI es autorreportado. Interpretar con ASDAS, función, inflamación objetiva y contexto terapéutico cuando corresponda.',
          interpretationPt:
              'BASDAI é autorrelatado. Interpretar com ASDAS, função, inflamação objetiva e contexto terapêutico quando aplicável.',
        );

      case PlusScoresMb2Id.beighton:
        final score = PlusScoresMb2Engine.beighton(
          List.generate(9, (i) => _b('m$i')),
        );
        final threshold = _c('ageBand');
        return _Outcome(
          value: '$score / 9',
          bandEs: score >= threshold
              ? 'Hipermovilidad generalizada por umbral etario'
              : 'Por debajo del umbral etario',
          bandPt: score >= threshold
              ? 'Hipermobilidade generalizada pelo limiar etário'
              : 'Abaixo do limiar etário',
          interpretationEs:
              'El Beighton no diagnostica por sí solo un trastorno hereditario del tejido conectivo y no evalúa todas las articulaciones sintomáticas.',
          interpretationPt:
              'O Beighton não diagnostica isoladamente transtorno hereditário do tecido conjuntivo e não avalia todas as articulações sintomáticas.',
        );

      case PlusScoresMb2Id.katzAdl:
        final score = PlusScoresMb2Engine.katzAdl(
          List.generate(6, (i) => _b('k$i')),
        );
        return _Outcome(
          value: '$score / 6',
          bandEs: score == 6
              ? 'Independencia alta'
              : score >= 3
                  ? 'Dependencia parcial'
                  : 'Dependencia importante',
          bandPt: score == 6
              ? 'Independência alta'
              : score >= 3
                  ? 'Dependência parcial'
                  : 'Dependência importante',
          interpretationEs:
              'Registrar la función habitual, no solo el desempeño durante una enfermedad aguda transitoria.',
          interpretationPt:
              'Registrar a função habitual, não apenas o desempenho durante doença aguda transitória.',
        );

      case PlusScoresMb2Id.lawtonBrody:
        final score = PlusScoresMb2Engine.lawtonBrody(
          List.generate(8, (i) => _b('l$i')),
        );
        return _Outcome(
          value: '$score / 8',
          bandEs: 'Mayor puntaje = mayor independencia instrumental',
          bandPt: 'Maior pontuação = maior independência instrumental',
          interpretationEs:
              'Se evalúan los 8 dominios en cualquier sexo; no se utiliza la puntuación histórica diferenciada por rol de género.',
          interpretationPt:
              'Os 8 domínios são avaliados em qualquer sexo; não usamos a pontuação histórica diferenciada por papel de gênero.',
        );

      case PlusScoresMb2Id.mmseScoreRecord:
        final score = PlusScoresMb2Engine.mmseRecord(_n('score').round());
        return _Outcome(
          value: '$score / 30',
          bandEs: 'Puntaje registrado de versión autorizada',
          bandPt: 'Pontuação registrada de versão autorizada',
          interpretationEs:
              'No se aplica un corte universal automático. Interpretar con edad, escolaridad, idioma, versión validada y contexto clínico.',
          interpretationPt:
              'Não aplicamos corte universal automático. Interpretar com idade, escolaridade, idioma, versão validada e contexto clínico.',
        );

      case PlusScoresMb2Id.isthDic2025:
        final score = PlusScoresMb2Engine.isthDic2025(
          plateletsX109L: _n('platelets'),
          dDimerTimesUln: _n('ddimer'),
          ptProlongationSeconds: _n('pt'),
          fibrinogenMgDl: _n('fibrinogen'),
        );
        final associated = _b('associated');
        return _Outcome(
          value: '$score / 8',
          bandEs: !associated
              ? 'No aplicar sin condición subyacente asociada'
              : score >= 5
                  ? 'Compatible con DIC manifiesta'
                  : 'No alcanza umbral de DIC manifiesta',
          bandPt: !associated
              ? 'Não aplicar sem condição subjacente associada'
              : score >= 5
                  ? 'Compatível com CIVD manifesta'
                  : 'Não atinge limiar de CIVD manifesta',
          interpretationEs:
              'Criterios ISTH overt DIC actualizados en 2025. La evolución seriada y la fisiopatología de la enfermedad subyacente son esenciales.',
          interpretationPt:
              'Critérios ISTH overt DIC atualizados em 2025. Evolução seriada e fisiopatologia da doença subjacente são essenciais.',
        );

      case PlusScoresMb2Id.fourTs:
        final score = PlusScoresMb2Engine.fourTs(
          thrombocytopenia: _c('thrombocytopenia'),
          timing: _c('timing'),
          thrombosis: _c('thrombosis'),
          otherCauses: _c('other'),
        );
        final band = score <= 3
            ? 0
            : score <= 5
                ? 1
                : 2;
        return _Outcome(
          value: '$score / 8',
          bandEs: [
            'Probabilidad baja',
            'Probabilidad intermedia',
            'Probabilidad alta'
          ][band],
          bandPt: [
            'Probabilidade baixa',
            'Probabilidade intermediária',
            'Probabilidade alta'
          ][band],
          interpretationEs:
              '4Ts estima probabilidad pretest de HIT. La confirmación depende de estrategia laboratorial y contexto de exposición a heparina.',
          interpretationPt:
              '4Ts estima probabilidade pré-teste de HIT. Confirmação depende de estratégia laboratorial e contexto de exposição à heparina.',
        );

      case PlusScoresMb2Id.plasmic:
        final score = PlusScoresMb2Engine.plasmic(
          plateletsX109L: _n('platelets'),
          hemolysis: _b('hemolysis'),
          noActiveCancer: _b('noCancer'),
          noSolidOrganOrStemCellTransplant: _b('noTransplant'),
          mcvFl: _n('mcv'),
          inr: _n('inr'),
          creatinineMgDl: _n('creatinine'),
        );
        final band = score <= 4
            ? 0
            : score == 5
                ? 1
                : 2;
        return _Outcome(
          value: '$score / 7',
          bandEs: ['Bajo riesgo', 'Riesgo intermedio', 'Alto riesgo'][band],
          bandPt: ['Baixo risco', 'Risco intermediário', 'Alto risco'][band],
          interpretationEs:
              'Estima probabilidad de deficiencia grave de ADAMTS13 en adultos con sospecha de microangiopatía trombótica; no sustituye actividad ADAMTS13.',
          interpretationPt:
              'Estima probabilidade de deficiência grave de ADAMTS13 em adultos com suspeita de microangiopatia trombótica; não substitui atividade ADAMTS13.',
        );

      case PlusScoresMb2Id.ipssR:
        final score = PlusScoresMb2Engine.ipssR(
          cytogeneticPoints: _c('cyto'),
          boneMarrowBlastsPercent: _n('blasts'),
          hemoglobinGDl: _n('hb'),
          plateletsX109L: _n('platelets'),
          ancX109L: _n('anc'),
        );
        final band = score <= 1.5
            ? 0
            : score <= 3
                ? 1
                : score <= 4.5
                    ? 2
                    : score <= 6
                        ? 3
                        : 4;
        return _Outcome(
          value: score.toStringAsFixed(score % 1 == 0 ? 0 : 1),
          bandEs: ['Muy bajo', 'Bajo', 'Intermedio', 'Alto', 'Muy alto'][band],
          bandPt: [
            'Muito baixo',
            'Baixo',
            'Intermediário',
            'Alto',
            'Muito alto'
          ][band],
          interpretationEs:
              'IPSS-R estratifica SMD con citogenética, blastos y citopenias. IPSS-M puede mejorar la estratificación cuando hay datos moleculares disponibles.',
          interpretationPt:
              'IPSS-R estratifica SMD com citogenética, blastos e citopenias. IPSS-M pode melhorar a estratificação quando há dados moleculares disponíveis.',
        );

      case PlusScoresMb2Id.ipssProstate:
        final r = PlusScoresMb2Engine.ipssProstate(
          sevenSymptoms: List.generate(7, (i) => _c('u$i')),
          qualityOfLife: _c('qol'),
        );
        final band = r.total <= 7
            ? 0
            : r.total <= 19
                ? 1
                : 2;
        return _Outcome(
          value: '${r.total} / 35 · QoL ${r.qualityOfLife}/6',
          bandEs: [
            'Síntomas leves',
            'Síntomas moderados',
            'Síntomas graves'
          ][band],
          bandPt: [
            'Sintomas leves',
            'Sintomas moderados',
            'Sintomas graves'
          ][band],
          interpretationEs:
              'Cuantifica síntomas urinarios y calidad de vida. No determina etiología ni sustituye evaluación de retención, infección, hematuria o cáncer.',
          interpretationPt:
              'Quantifica sintomas urinários e qualidade de vida. Não determina etiologia nem substitui avaliação de retenção, infecção, hematúria ou câncer.',
        );

      case PlusScoresMb2Id.gleasonIsup:
        final r = PlusScoresMb2Engine.gleasonIsup(
          primaryPattern: _c('primary'),
          secondaryPattern: _c('secondary'),
        );
        return _Outcome(
          value: '${r.gleason} · Grade Group ${r.gradeGroup}',
          bandEs: 'Conversión desde patrones histológicos informados',
          bandPt: 'Conversão a partir de padrões histológicos informados',
          interpretationEs:
              'Los patrones 3–5 deben provenir del informe anatomopatológico. Esta herramienta no clasifica imágenes ni sustituye al patólogo.',
          interpretationPt:
              'Os padrões 3–5 devem vir do laudo anatomopatológico. Esta ferramenta não classifica imagens nem substitui o patologista.',
        );

      case PlusScoresMb2Id.bosniak2019:
        final cls = PlusScoresMb2Engine.bosniak2019(
          enhancingNodule: _b('nodule'),
          irregularEnhancingWallOrSepta: _b('irregular'),
          thickEnhancingWallOrSepta4MmOrMore: _b('thick4'),
          minimallyThickenedEnhancingWallOrSepta3Mm: _b('thick3'),
          enhancingSeptaCount: _n('septa').round(),
          simpleThinWallFluidMass: _b('simple'),
          heterogeneousT1HyperintenseNonenhancingMri: _b('t1'),
        );
        return _Outcome(
          value: 'Bosniak $cls',
          bandEs: 'Clasificación morfológica v2019',
          bandPt: 'Classificação morfológica v2019',
          interpretationEs:
              'Resultado guiado por descriptores radiológicos seleccionados. La categoría definitiva exige TC/RM renal técnicamente adecuada e interpretación radiológica completa.',
          interpretationPt:
              'Resultado guiado pelos descritores radiológicos selecionados. A categoria definitiva exige TC/RM renal tecnicamente adequada e interpretação radiológica completa.',
        );

      case PlusScoresMb2Id.snappe2:
        final score = PlusScoresMb2Engine.snappe2(
          meanArterialPressure: _n('map'),
          lowestTemperatureC: _n('temp'),
          pao2Fio2RatioUsingFio2Percent: _n('ratio'),
          lowestPh: _n('ph'),
          multipleSeizures: _b('seizures'),
          urineMlKgH: _n('urine'),
          apgar5Minutes: _n('apgar').round(),
          birthWeightG: _n('weight'),
          smallForGestationalAgeBelow3rdPercentile: _b('sga'),
        );
        return _Outcome(
          value: '$score / 162',
          bandEs: 'Mayor puntaje = mayor gravedad fisiológica',
          bandPt: 'Maior pontuação = maior gravidade fisiológica',
          interpretationEs:
              'SNAPPE-II es un índice de gravedad/mortalidad neonatal poblacional, no una orden terapéutica individual.',
          interpretationPt:
              'SNAPPE-II é índice de gravidade/mortalidade neonatal populacional, não uma ordem terapêutica individual.',
        );

      case PlusScoresMb2Id.newBallard:
        final total = _n('total').round();
        final weeks = PlusScoresMb2Engine.newBallardCompletedWeeks(total);
        return _Outcome(
          value: '$weeks semanas completas',
          bandEs: 'Estimación desde puntaje total New Ballard',
          bandPt: 'Estimativa a partir da pontuação total New Ballard',
          interpretationEs:
              'Conversión de la grilla publicada a semanas completas (-10 a 50 = 20 a 44). Para valores intermedios se informa la semana completa inferior; confirme el puntaje en una hoja New Ballard autorizada/validada.',
          interpretationPt:
              'Conversão da grade publicada para semanas completas (-10 a 50 = 20 a 44). Para valores intermediários informamos a semana completa inferior; confirme a pontuação em folha New Ballard autorizada/validada.',
        );

      case PlusScoresMb2Id.modifiedBell:
        final stage = PlusScoresMb2Engine.modifiedBell(
          grossRectalBlood: _b('blood'),
          pneumatosisIntestinalis: _b('pneumatosis'),
          portalVenousGasOrAscites: _b('portal'),
          mildMetabolicAcidosisOrThrombocytopenia: _b('mildLab'),
          severeSystemicDeterioration: _b('severe'),
          pneumoperitoneum: _b('freeAir'),
        );
        return _Outcome(
          value: 'Bell $stage',
          bandEs: 'Estadio modificado orientativo',
          bandPt: 'Estágio modificado orientativo',
          interpretationEs:
              'La clasificación combina clínica, laboratorio y radiología. No use el estadio aislado para decidir cirugía o alimentación sin evaluación neonatal completa.',
          interpretationPt:
              'A classificação combina clínica, laboratório e radiologia. Não use o estágio isolado para decidir cirurgia ou alimentação sem avaliação neonatal completa.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final isEs = p.lang == 'es';
    final dark = p.darkMode;
    final bg = dark ? const Color(0xFF1A1D23) : const Color(0xFFECF0F4);
    final text = dark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    final sub = dark ? const Color(0xFFAEB9CC) : const Color(0xFF64748B);
    final surface = dark ? const Color(0xFF252930) : Colors.white;
    final border = dark ? const Color(0xFF374151) : const Color(0xFFDDE3E9);
    const accent = Color(0xFF009C3B);
    final isFrax = widget.id == PlusScoresMb2Id.fraxOfficial;
    final isSad = widget.id == PlusScoresMb2Id.sadPersonsHistorical;
    final isMmse = widget.id == PlusScoresMb2Id.mmseScoreRecord;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: dark ? const Color(0xFF111622) : Colors.white,
        foregroundColor: text,
        elevation: 0,
        title: Text(
          meta.name,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 120),
        children: [
          _InfoCard(
            surface: surface,
            border: border,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEs ? meta.purposeEs : meta.purposePt,
                  style: TextStyle(
                    color: text,
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isEs
                      ? 'Ingrese los datos exactamente en las unidades indicadas.'
                      : 'Informe os dados exatamente nas unidades indicadas.',
                  style: TextStyle(color: sub, fontSize: 10.5, height: 1.35),
                ),
              ],
            ),
          ),
          if (isSad) ...[
            const SizedBox(height: 10),
            _SafetyCard(
              text: isEs
                  ? 'NO UTILIZAR PARA PREDECIR SUICIDIO, CLASIFICAR RIESGO NI DECIDIR ALTA/INGRESO. NICE recomienda no usar escalas de riesgo para estas decisiones.'
                  : 'NÃO USAR PARA PREVER SUICÍDIO, CLASSIFICAR RISCO OU DECIDIR ALTA/INTERNAÇÃO. NICE recomenda não usar escalas de risco para essas decisões.',
            ),
          ],
          if (isMmse) ...[
            const SizedBox(height: 10),
            _SafetyCard(
              text: isEs
                  ? 'El MMSE/MMSE-2 es material protegido. MedCases registra únicamente el puntaje obtenido con una versión autorizada; no reproduce los ítems.'
                  : 'O MMSE/MMSE-2 é material protegido. O MedCases registra apenas a pontuação obtida com versão autorizada; não reproduz os itens.',
            ),
          ],
          const SizedBox(height: 10),
          ...meta.fields.map(
            (field) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _buildField(
                field: field,
                isEs: isEs,
                surface: surface,
                border: border,
                text: text,
                sub: sub,
              ),
            ),
          ),
          if (isFrax)
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: () => _openFrax(isEs),
                icon: const Icon(Icons.open_in_new_rounded),
                label: Text(
                  isEs ? 'ABRIR FRAXPLUS OFICIAL' : 'ABRIR FRAXPLUS OFICIAL',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 46,
              child: FilledButton(
                onPressed: () => _calculate(isEs),
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  isEs ? 'CALCULAR / CLASIFICAR' : 'CALCULAR / CLASSIFICAR',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          if (_outcome != null) ...[
            const SizedBox(height: 12),
            _InfoCard(
              surface: surface,
              border: border,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEs ? 'RESULTADO' : 'RESULTADO',
                    style: const TextStyle(
                      color: accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _outcome!.value,
                    style: TextStyle(
                      color: text,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    isEs ? _outcome!.bandEs : _outcome!.bandPt,
                    style: const TextStyle(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isEs
                        ? _outcome!.interpretationEs
                        : _outcome!.interpretationPt,
                    style: TextStyle(color: text, fontSize: 11, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          _InfoCard(
            surface: surface,
            border: border,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEs ? 'LIMITACIONES' : 'LIMITAÇÕES',
                  style: const TextStyle(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isEs ? meta.limitationsEs : meta.limitationsPt,
                  style: TextStyle(color: text, fontSize: 10.5, height: 1.4),
                ),
                const SizedBox(height: 10),
                Text(
                  isEs ? 'REFERENCIA' : 'REFERÊNCIA',
                  style: const TextStyle(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  meta.reference,
                  style: TextStyle(color: sub, fontSize: 10, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isEs
                ? 'Herramienta educativa de apoyo. No reemplaza evaluación clínica, protocolos locales ni juicio profesional.'
                : 'Ferramenta educacional de apoio. Não substitui avaliação clínica, protocolos locais nem julgamento profissional.',
            textAlign: TextAlign.center,
            style: TextStyle(color: sub, fontSize: 9.5, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required _FieldSpec field,
    required bool isEs,
    required Color surface,
    required Color border,
    required Color text,
    required Color sub,
  }) {
    final label = isEs ? field.labelEs : field.labelPt;
    switch (field.kind) {
      case _FieldKind.toggle:
        return Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: 0.7),
          ),
          child: SwitchListTile.adaptive(
            value: _toggles[field.key] ?? false,
            onChanged: (value) => setState(() => _toggles[field.key] = value),
            title: Text(
              label,
              style: TextStyle(
                color: text,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            dense: true,
          ),
        );
      case _FieldKind.number:
        return TextField(
          controller: _controllers[field.key],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,-]')),
          ],
          style: TextStyle(color: text, fontSize: 12),
          decoration: InputDecoration(
            filled: true,
            fillColor: surface,
            labelText: field.unit == null ? label : '$label · ${field.unit}',
            labelStyle: TextStyle(color: sub, fontSize: 10.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: border, width: 0.7),
            ),
          ),
        );
      case _FieldKind.choice:
        return DropdownButtonFormField<int>(
          value: _choices[field.key],
          dropdownColor: surface,
          style: TextStyle(color: text, fontSize: 11),
          decoration: InputDecoration(
            filled: true,
            fillColor: surface,
            labelText: label,
            labelStyle: TextStyle(color: sub, fontSize: 10.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: border, width: 0.7),
            ),
          ),
          items: field.choices
              .map(
                (choice) => DropdownMenuItem<int>(
                  value: choice.value,
                  child: Text(isEs ? choice.labelEs : choice.labelPt),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _choices[field.key] = value);
            }
          },
        );
    }
  }
}

class _InfoCard extends StatelessWidget {
  final Color surface;
  final Color border;
  final Widget child;

  const _InfoCard({
    required this.surface,
    required this.border,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 0.7),
      ),
      child: child,
    );
  }
}

class _SafetyCard extends StatelessWidget {
  final String text;

  const _SafetyCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFB45309).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFB45309).withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFB45309),
          fontSize: 10.5,
          height: 1.35,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

enum _FieldKind { toggle, number, choice }

class _ChoiceSpec {
  final int value;
  final String labelEs;
  final String labelPt;

  const _ChoiceSpec(this.value, this.labelEs, this.labelPt);
}

class _FieldSpec {
  final String key;
  final _FieldKind kind;
  final String labelEs;
  final String labelPt;
  final String? unit;
  final double? min;
  final double? max;
  final double? initialNumber;
  final bool initialBool;
  final int? initialChoice;
  final List<_ChoiceSpec> choices;

  const _FieldSpec._({
    required this.key,
    required this.kind,
    required this.labelEs,
    required this.labelPt,
    this.unit,
    this.min,
    this.max,
    this.initialNumber,
    this.initialBool = false,
    this.initialChoice,
    this.choices = const [],
  });

  const _FieldSpec.toggle(
    String key,
    String es,
    String pt, {
    bool initial = false,
  }) : this._(
          key: key,
          kind: _FieldKind.toggle,
          labelEs: es,
          labelPt: pt,
          initialBool: initial,
        );

  const _FieldSpec.number(
    String key,
    String es,
    String pt, {
    String? unit,
    double? min,
    double? max,
    double? initial,
  }) : this._(
          key: key,
          kind: _FieldKind.number,
          labelEs: es,
          labelPt: pt,
          unit: unit,
          min: min,
          max: max,
          initialNumber: initial,
        );

  const _FieldSpec.choice(
    String key,
    String es,
    String pt,
    List<_ChoiceSpec> choices, {
    int? initial,
  }) : this._(
          key: key,
          kind: _FieldKind.choice,
          labelEs: es,
          labelPt: pt,
          choices: choices,
          initialChoice: initial,
        );
}

class _Outcome {
  final String value;
  final String bandEs;
  final String bandPt;
  final String interpretationEs;
  final String interpretationPt;

  const _Outcome({
    required this.value,
    required this.bandEs,
    required this.bandPt,
    required this.interpretationEs,
    required this.interpretationPt,
  });
}

class _ScoreMeta {
  final PlusScoresMb2Id id;
  final PlusScoresMb2Specialty specialty;
  final String name;
  final IconData icon;
  final String purposeEs;
  final String purposePt;
  final String limitationsEs;
  final String limitationsPt;
  final String reference;
  final List<_FieldSpec> fields;

  const _ScoreMeta({
    required this.id,
    required this.specialty,
    required this.name,
    required this.icon,
    required this.purposeEs,
    required this.purposePt,
    required this.limitationsEs,
    required this.limitationsPt,
    required this.reference,
    required this.fields,
  });
}

String _specialtyName(PlusScoresMb2Specialty specialty, bool isEs) {
  return switch (specialty) {
    PlusScoresMb2Specialty.psychiatry => isEs ? 'Psiquiatría' : 'Psiquiatria',
    PlusScoresMb2Specialty.endocrinology =>
      isEs ? 'Endocrinología' : 'Endocrinologia',
    PlusScoresMb2Specialty.traumaSeverity =>
      isEs ? 'Trauma · Gravedad' : 'Trauma · Gravidade',
    PlusScoresMb2Specialty.rheumatology =>
      isEs ? 'Reumatología' : 'Reumatologia',
    PlusScoresMb2Specialty.geriatrics => isEs ? 'Geriatría' : 'Geriatria',
    PlusScoresMb2Specialty.hematology => isEs ? 'Hematología' : 'Hematologia',
    PlusScoresMb2Specialty.urology => isEs ? 'Urología' : 'Urologia',
    PlusScoresMb2Specialty.neonatology =>
      isEs ? 'Neonatología' : 'Neonatologia',
  };
}

IconData _specialtyIcon(PlusScoresMb2Specialty specialty) {
  return switch (specialty) {
    PlusScoresMb2Specialty.psychiatry => Icons.psychology_outlined,
    PlusScoresMb2Specialty.endocrinology => Icons.monitor_weight_outlined,
    PlusScoresMb2Specialty.traumaSeverity => Icons.emergency_outlined,
    PlusScoresMb2Specialty.rheumatology => Icons.accessibility_new_outlined,
    PlusScoresMb2Specialty.geriatrics => Icons.elderly_outlined,
    PlusScoresMb2Specialty.hematology => Icons.bloodtype_outlined,
    PlusScoresMb2Specialty.urology => Icons.water_drop_outlined,
    PlusScoresMb2Specialty.neonatology => Icons.child_friendly_outlined,
  };
}

List<PlusScoresMb2Id> _idsForSpecialty(PlusScoresMb2Specialty specialty) {
  return switch (specialty) {
    PlusScoresMb2Specialty.psychiatry => const [
        PlusScoresMb2Id.phq9,
        PlusScoresMb2Id.sadPersonsHistorical,
      ],
    PlusScoresMb2Specialty.endocrinology => const [
        PlusScoresMb2Id.fraxOfficial,
        PlusScoresMb2Id.findrisc,
        PlusScoresMb2Id.burchWartofsky,
      ],
    PlusScoresMb2Specialty.traumaSeverity => const [
        PlusScoresMb2Id.revisedTraumaScore,
        PlusScoresMb2Id.injurySeverityScore,
        PlusScoresMb2Id.atlsHemorrhagicShock,
      ],
    PlusScoresMb2Specialty.rheumatology => const [
        PlusScoresMb2Id.das28,
        PlusScoresMb2Id.sledai2k,
        PlusScoresMb2Id.basdai,
        PlusScoresMb2Id.beighton,
      ],
    PlusScoresMb2Specialty.geriatrics => const [
        PlusScoresMb2Id.katzAdl,
        PlusScoresMb2Id.lawtonBrody,
        PlusScoresMb2Id.mmseScoreRecord,
      ],
    PlusScoresMb2Specialty.hematology => const [
        PlusScoresMb2Id.isthDic2025,
        PlusScoresMb2Id.fourTs,
        PlusScoresMb2Id.plasmic,
        PlusScoresMb2Id.ipssR,
      ],
    PlusScoresMb2Specialty.urology => const [
        PlusScoresMb2Id.ipssProstate,
        PlusScoresMb2Id.gleasonIsup,
        PlusScoresMb2Id.bosniak2019,
      ],
    PlusScoresMb2Specialty.neonatology => const [
        PlusScoresMb2Id.snappe2,
        PlusScoresMb2Id.newBallard,
        PlusScoresMb2Id.modifiedBell,
      ],
  };
}

_ScoreMeta _meta(PlusScoresMb2Id id) {
  switch (id) {
    case PlusScoresMb2Id.phq9:
      const response = [
        _ChoiceSpec(0, '0 · Ningún día', '0 · Nenhum dia'),
        _ChoiceSpec(1, '1 · Varios días', '1 · Vários dias'),
        _ChoiceSpec(2, '2 · Más de la mitad de los días',
            '2 · Mais da metade dos dias'),
        _ChoiceSpec(3, '3 · Casi todos los días', '3 · Quase todos os dias'),
      ];
      return _ScoreMeta(
        id: id,
        specialty: PlusScoresMb2Specialty.psychiatry,
        name: 'PHQ-9',
        icon: Icons.psychology_outlined,
        purposeEs:
            'Cuantifica síntomas depresivos durante las últimas 2 semanas.',
        purposePt: 'Quantifica sintomas depressivos nas últimas 2 semanas.',
        limitationsEs:
            'Es una herramienta de tamizaje/severidad, no un diagnóstico aislado. Cualquier respuesta positiva al ítem 9 exige evaluación directa de seguridad.',
        limitationsPt:
            'É ferramenta de triagem/gravidade, não diagnóstico isolado. Qualquer resposta positiva ao item 9 exige avaliação direta de segurança.',
        reference: 'Kroenke, Spitzer & Williams · PHQ-9 validation.',
        fields: const [
          _FieldSpec.choice('q1', '1 · Poco interés/placer',
              '1 · Pouco interesse/prazer', response),
          _FieldSpec.choice(
              'q2', '2 · Ánimo deprimido', '2 · Humor deprimido', response),
          _FieldSpec.choice('q3', '3 · Sueño', '3 · Sono', response),
          _FieldSpec.choice('q4', '4 · Energía', '4 · Energia', response),
          _FieldSpec.choice('q5', '5 · Apetito', '5 · Apetite', response),
          _FieldSpec.choice('q6', '6 · Autoevaluación negativa',
              '6 · Autoavaliação negativa', response),
          _FieldSpec.choice(
              'q7', '7 · Concentración', '7 · Concentração', response),
          _FieldSpec.choice('q8', '8 · Agitación/enlentecimiento',
              '8 · Agitação/lentificação', response),
          _FieldSpec.choice('q9', '9 · Pensamientos de muerte/autolesión',
              '9 · Pensamentos de morte/autoagressão', response),
        ],
      );

    case PlusScoresMb2Id.sadPersonsHistorical:
      return _ScoreMeta(
        id: id,
        specialty: PlusScoresMb2Specialty.psychiatry,
        name: 'SAD PERSONS · histórico',
        icon: Icons.history_edu_outlined,
        purposeEs:
            'Registro educativo del checklist histórico SAD PERSONS, sin estratificación de riesgo.',
        purposePt:
            'Registro educacional do checklist histórico SAD PERSONS, sem estratificação de risco.',
        limitationsEs:
            'NICE indica no usar escalas de riesgo para predecir suicidio/autolesión ni decidir tratamiento, ingreso o alta. El resultado se muestra solo como suma histórica.',
        limitationsPt:
            'NICE orienta não usar escalas de risco para prever suicídio/autoagressão nem decidir tratamento, internação ou alta. O resultado é exibido apenas como soma histórica.',
        reference: 'NICE NG225 · Risk assessment tools and scales.',
        fields: const [
          _FieldSpec.toggle('sex', 'Sexo masculino · ítem histórico',
              'Sexo masculino · item histórico'),
          _FieldSpec.toggle('age', 'Edad fuera de rango medio · ítem histórico',
              'Idade fora da faixa intermediária · item histórico'),
          _FieldSpec.toggle(
              'depression', 'Depresión/desesperanza', 'Depressão/desesperança'),
          _FieldSpec.toggle('previous', 'Intento previo', 'Tentativa prévia'),
          _FieldSpec.toggle('ethanol', 'Uso problemático de alcohol/sustancias',
              'Uso problemático de álcool/substâncias'),
          _FieldSpec.toggle('rational', 'Pérdida de pensamiento racional',
              'Perda de pensamento racional'),
          _FieldSpec.toggle(
              'social', 'Apoyo social limitado', 'Suporte social limitado'),
          _FieldSpec.toggle('organized', 'Plan organizado', 'Plano organizado'),
          _FieldSpec.toggle('spouse', 'Sin pareja', 'Sem parceiro'),
          _FieldSpec.toggle('sickness', 'Enfermedad médica', 'Doença médica'),
        ],
      );

    case PlusScoresMb2Id.fraxOfficial:
      return _ScoreMeta(
        id: id,
        specialty: PlusScoresMb2Specialty.endocrinology,
        name: 'FRAX® / FRAXplus®',
        icon: Icons.balance_outlined,
        purposeEs:
            'Calcula probabilidad a 10 años de fractura de cadera y fractura osteoporótica mayor mediante el motor oficial por país.',
        purposePt:
            'Calcula probabilidade em 10 anos de fratura de quadril e fratura osteoporótica maior pelo motor oficial por país.',
        limitationsEs:
            'MedCases no replica el algoritmo propietario/validado por país. El botón abre el calculador oficial FRAXplus.',
        limitationsPt:
            'O MedCases não replica o algoritmo proprietário/validado por país. O botão abre a calculadora oficial FRAXplus.',
        reference: 'FRAXplus® official calculation tool · FRAX 1.4.9.',
        fields: const [],
      );

    case PlusScoresMb2Id.findrisc:
      return _ScoreMeta(
        id: id,
        specialty: PlusScoresMb2Specialty.endocrinology,
        name: 'FINDRISC',
        icon: Icons.monitor_weight_outlined,
        purposeEs:
            'Estima riesgo de diabetes tipo 2 a 10 años sin laboratorio.',
        purposePt:
            'Estima risco de diabetes tipo 2 em 10 anos sem laboratório.',
        limitationsEs:
            'Herramienta poblacional europea; el rendimiento depende de la población. No diagnostica diabetes.',
        limitationsPt:
            'Ferramenta populacional europeia; desempenho depende da população. Não diagnostica diabetes.',
        reference: 'Lindström & Tuomilehto · Finnish Diabetes Risk Score.',
        fields: const [
          _FieldSpec.number('age', 'Edad', 'Idade',
              unit: 'años/anos', min: 18, max: 130),
          _FieldSpec.choice('sex', 'Sexo para punto de corte de cintura',
              'Sexo para ponto de corte da cintura', [
            _ChoiceSpec(0, 'Masculino', 'Masculino'),
            _ChoiceSpec(1, 'Femenino', 'Feminino'),
          ]),
          _FieldSpec.number('bmi', 'IMC', 'IMC',
              unit: 'kg/m²', min: 10, max: 100),
          _FieldSpec.number(
              'waist', 'Circunferencia de cintura', 'Circunferência da cintura',
              unit: 'cm', min: 30, max: 250),
          _FieldSpec.toggle('activity', 'Actividad física ≥30 min/día',
              'Atividade física ≥30 min/dia'),
          _FieldSpec.toggle('produce', 'Frutas/verduras diariamente',
              'Frutas/verduras diariamente'),
          _FieldSpec.toggle('bpMeds', 'Uso regular de antihipertensivos',
              'Uso regular de anti-hipertensivos'),
          _FieldSpec.toggle('highGlucose', 'Glucosa elevada previa',
              'Glicose elevada prévia'),
          _FieldSpec.choice('family', 'Historia familiar de diabetes',
              'História familiar de diabetes', [
            _ChoiceSpec(0, 'Ninguna · 0', 'Nenhuma · 0'),
            _ChoiceSpec(3, 'Segundo grado · 3', 'Segundo grau · 3'),
            _ChoiceSpec(5, 'Primer grado · 5', 'Primeiro grau · 5'),
          ]),
        ],
      );

    case PlusScoresMb2Id.burchWartofsky:
      return _ScoreMeta(
        id: id,
        specialty: PlusScoresMb2Specialty.endocrinology,
        name: 'Burch-Wartofsky',
        icon: Icons.thermostat_outlined,
        purposeEs: 'Apoya el reconocimiento clínico de tormenta tiroidea.',
        purposePt: 'Apoia o reconhecimento clínico de tempestade tireotóxica.',
        limitationsEs:
            'Puede sobreestimar en enfermedades críticas no tiroideas. El diagnóstico es clínico y no debe esperar confirmación laboratorial si la sospecha es alta.',
        limitationsPt:
            'Pode superestimar em doenças críticas não tireoidianas. O diagnóstico é clínico e não deve aguardar confirmação laboratorial se a suspeita for alta.',
        reference: 'Burch & Wartofsky · Endocrine storm scoring system.',
        fields: const [
          _FieldSpec.number('temp', 'Temperatura', 'Temperatura',
              unit: '°C', min: 30, max: 45),
          _FieldSpec.number('hr', 'Frecuencia cardíaca', 'Frequência cardíaca',
              unit: 'bpm', min: 0, max: 300),
          _FieldSpec.choice(
              'gi', 'Disfunción GI/hepática', 'Disfunção GI/hepática', [
            _ChoiceSpec(0, 'Ausente · 0', 'Ausente · 0'),
            _ChoiceSpec(10, 'Moderada · 10', 'Moderada · 10'),
            _ChoiceSpec(20, 'Ictericia · 20', 'Icterícia · 20'),
          ]),
          _FieldSpec.choice('cns', 'Disfunción SNC', 'Disfunção SNC', [
            _ChoiceSpec(0, 'Ausente · 0', 'Ausente · 0'),
            _ChoiceSpec(10, 'Leve · 10', 'Leve · 10'),
            _ChoiceSpec(20, 'Moderada · 20', 'Moderada · 20'),
            _ChoiceSpec(30, 'Grave · 30', 'Grave · 30'),
          ]),
          _FieldSpec.choice(
              'chf', 'Insuficiencia cardíaca', 'Insuficiência cardíaca', [
            _ChoiceSpec(0, 'Ausente · 0', 'Ausente · 0'),
            _ChoiceSpec(5, 'Leve · 5', 'Leve · 5'),
            _ChoiceSpec(10, 'Moderada · 10', 'Moderada · 10'),
            _ChoiceSpec(15, 'Grave · 15', 'Grave · 15'),
          ]),
          _FieldSpec.toggle(
              'af', 'Fibrilación auricular · 10', 'Fibrilação atrial · 10'),
          _FieldSpec.toggle(
              'precip', 'Evento precipitante · 10', 'Evento precipitante · 10'),
        ],
      );

    case PlusScoresMb2Id.revisedTraumaScore:
      return _ScoreMeta(
        id: id,
        specialty: PlusScoresMb2Specialty.traumaSeverity,
        name: 'Revised Trauma Score · RTS',
        icon: Icons.emergency_outlined,
        purposeEs:
            'Resume alteración fisiológica en trauma mediante GCS, PAS y frecuencia respiratoria.',
        purposePt:
            'Resume alteração fisiológica no trauma por GCS, PAS e frequência respiratória.',
        limitationsEs:
            'Es un índice fisiológico y no sustituye evaluación anatómica ni triage integral.',
        limitationsPt:
            'É índice fisiológico e não substitui avaliação anatômica nem triagem integral.',
        reference: 'Champion et al. · Revised Trauma Score.',
        fields: const [
          _FieldSpec.number('gcs', 'Glasgow', 'Glasgow',
              unit: '3–15', min: 3, max: 15),
          _FieldSpec.number('sbp', 'PAS', 'PAS',
              unit: 'mmHg', min: 0, max: 300),
          _FieldSpec.number(
              'rr', 'Frecuencia respiratoria', 'Frequência respiratória',
              unit: 'irpm', min: 0, max: 100),
        ],
      );

    case PlusScoresMb2Id.injurySeverityScore:
      const ais = [
        _ChoiceSpec(0, '0 · Sin lesión', '0 · Sem lesão'),
        _ChoiceSpec(1, '1 · Menor', '1 · Menor'),
        _ChoiceSpec(2, '2 · Moderada', '2 · Moderada'),
        _ChoiceSpec(3, '3 · Grave', '3 · Grave'),
        _ChoiceSpec(4, '4 · Severa', '4 · Severa'),
        _ChoiceSpec(5, '5 · Crítica', '5 · Crítica'),
        _ChoiceSpec(
            6, '6 · Máxima/no sobrevivible', '6 · Máxima/não sobrevivível'),
      ];
      return _ScoreMeta(
        id: id,
        specialty: PlusScoresMb2Specialty.traumaSeverity,
        name: 'Injury Severity Score · ISS',
        icon: Icons.calculate_outlined,
        purposeEs:
            'Calcula ISS a partir de las tres mayores AIS de regiones corporales distintas.',
        purposePt:
            'Calcula ISS a partir das três maiores AIS de regiões corporais distintas.',
        limitationsEs:
            'Requiere codificación AIS válida y regiones distintas. No derive AIS a partir de descripciones improvisadas.',
        limitationsPt:
            'Exige codificação AIS válida e regiões distintas. Não derive AIS a partir de descrições improvisadas.',
        reference: 'Baker et al. · Injury Severity Score / AIS framework.',
        fields: const [
          _FieldSpec.choice(
              'ais1', 'Mayor AIS · región 1', 'Maior AIS · região 1', ais),
          _FieldSpec.choice(
              'ais2', 'Mayor AIS · región 2', 'Maior AIS · região 2', ais),
          _FieldSpec.choice(
              'ais3', 'Mayor AIS · región 3', 'Maior AIS · região 3', ais),
        ],
      );

    case PlusScoresMb2Id.atlsHemorrhagicShock:
      return _ScoreMeta(
        id: id,
        specialty: PlusScoresMb2Specialty.traumaSeverity,
        name: 'Choque hemorrágico · ATLS 11',
        icon: Icons.bloodtype_outlined,
        purposeEs:
            'Clasifica pérdida hemática estimada en clases I–IV como marco educativo de trauma.',
        purposePt:
            'Classifica perda sanguínea estimada em classes I–IV como estrutura educacional de trauma.',
        limitationsEs:
            'La respuesta fisiológica varía con edad, embarazo, fármacos y comorbilidades. ATLS 11 no debe reducirse a un protocolo rígido basado solo en porcentajes.',
        limitationsPt:
            'A resposta fisiológica varia com idade, gestação, fármacos e comorbidades. ATLS 11 não deve ser reduzido a protocolo rígido baseado apenas em percentuais.',
        reference: 'ACS Advanced Trauma Life Support · ATLS 11, 2025.',
        fields: const [
          _FieldSpec.number('bloodLoss', 'Pérdida sanguínea estimada',
              'Perda sanguínea estimada',
              unit: '% volemia', min: 0, max: 100),
        ],
      );

    case PlusScoresMb2Id.das28:
      return _ScoreMeta(
        id: id,
        specialty: PlusScoresMb2Specialty.rheumatology,
        name: 'DAS28 · ESR/CRP',
        icon: Icons.accessibility_new_outlined,
        purposeEs:
            'Cuantifica actividad de artritis reumatoide con 28 articulaciones.',
        purposePt:
            'Quantifica atividade da artrite reumatoide com 28 articulações.',
        limitationsEs:
            'DAS28-ESR y DAS28-CRP no son idénticos. Mantener la misma fórmula en seguimientos seriados.',
        limitationsPt:
            'DAS28-ESR e DAS28-CRP não são idênticos. Manter a mesma fórmula em acompanhamentos seriados.',
        reference:
            'Prevoo et al. · DAS28 validation / EULAR activity thresholds.',
        fields: const [
          _FieldSpec.choice('method', 'Fórmula', 'Fórmula', [
            _ChoiceSpec(0, 'DAS28-ESR/VSG', 'DAS28-ESR/VHS'),
            _ChoiceSpec(1, 'DAS28-CRP', 'DAS28-PCR'),
          ]),
          _FieldSpec.number(
              'tjc', 'Articulaciones dolorosas 28', 'Articulações dolorosas 28',
              min: 0, max: 28),
          _FieldSpec.number('sjc', 'Articulaciones tumefactas 28',
              'Articulações edemaciadas 28',
              min: 0, max: 28),
          _FieldSpec.number('marker', 'VSG mm/h o PCR mg/L según fórmula',
              'VHS mm/h ou PCR mg/L segundo fórmula',
              min: 0, max: 1000),
          _FieldSpec.number('global', 'Evaluación global del paciente',
              'Avaliação global do paciente',
              unit: '0–100 mm', min: 0, max: 100),
        ],
      );

    case PlusScoresMb2Id.sledai2k:
      return _ScoreMeta(
        id: id,
        specialty: PlusScoresMb2Specialty.rheumatology,
        name: 'SLEDAI-2K',
        icon: Icons.auto_awesome_outlined,
        purposeEs:
            'Suma descriptores ponderados de actividad de lupus en los últimos 10 días.',
        purposePt:
            'Soma descritores ponderados de atividade do lúpus nos últimos 10 dias.',
        limitationsEs:
            'Cada descriptor requiere su definición formal. El total no reemplaza evaluación por órgano ni juicio de actividad atribuible a LES.',
        limitationsPt:
            'Cada descritor exige definição formal. O total não substitui avaliação por órgão nem julgamento de atividade atribuível ao LES.',
        reference: 'Gladman et al. · SLEDAI-2K.',
        fields: const [
          _FieldSpec.toggle('w8_0', 'Convulsión · 8', 'Convulsão · 8'),
          _FieldSpec.toggle('w8_1', 'Psicosis · 8', 'Psicose · 8'),
          _FieldSpec.toggle('w8_2', 'Síndrome cerebral orgánico · 8',
              'Síndrome cerebral orgânica · 8'),
          _FieldSpec.toggle(
              'w8_3', 'Alteración visual · 8', 'Alteração visual · 8'),
          _FieldSpec.toggle('w8_4', 'Trastorno de nervio craneal · 8',
              'Alteração de nervo craniano · 8'),
          _FieldSpec.toggle(
              'w8_5', 'Cefalea lúpica · 8', 'Cefaleia lúpica · 8'),
          _FieldSpec.toggle('w8_6', 'ACV · 8', 'AVC · 8'),
          _FieldSpec.toggle('w8_7', 'Vasculitis · 8', 'Vasculite · 8'),
          _FieldSpec.toggle('w4_0', 'Artritis · 4', 'Artrite · 4'),
          _FieldSpec.toggle('w4_1', 'Miositis · 4', 'Miosite · 4'),
          _FieldSpec.toggle(
              'w4_2', 'Cilindros urinarios · 4', 'Cilindros urinários · 4'),
          _FieldSpec.toggle('w4_3', 'Hematuria · 4', 'Hematúria · 4'),
          _FieldSpec.toggle('w4_4', 'Proteinuria · 4', 'Proteinúria · 4'),
          _FieldSpec.toggle('w4_5', 'Piuria · 4', 'Piúria · 4'),
          _FieldSpec.toggle('w2_0', 'Rash · 2', 'Rash · 2'),
          _FieldSpec.toggle('w2_1', 'Alopecia · 2', 'Alopecia · 2'),
          _FieldSpec.toggle(
              'w2_2', 'Úlceras mucosas · 2', 'Úlceras mucosas · 2'),
          _FieldSpec.toggle('w2_3', 'Pleuritis · 2', 'Pleurite · 2'),
          _FieldSpec.toggle('w2_4', 'Pericarditis · 2', 'Pericardite · 2'),
          _FieldSpec.toggle(
              'w2_5', 'Complemento bajo · 2', 'Complemento baixo · 2'),
          _FieldSpec.toggle(
              'w2_6', 'Anti-dsDNA elevado · 2', 'Anti-dsDNA elevado · 2'),
          _FieldSpec.toggle('w1_0', 'Fiebre · 1', 'Febre · 1'),
          _FieldSpec.toggle('w1_1', 'Leucopenia · 1', 'Leucopenia · 1'),
          _FieldSpec.toggle(
              'w1_2', 'Trombocitopenia · 1', 'Trombocitopenia · 1'),
        ],
      );

    case PlusScoresMb2Id.basdai:
      return _ScoreMeta(
        id: id,
        specialty: PlusScoresMb2Specialty.rheumatology,
        name: 'BASDAI',
        icon: Icons.straighten_outlined,
        purposeEs:
            'Índice autorreportado de actividad en espondiloartritis axial.',
        purposePt:
            'Índice autorrelatado de atividade na espondiloartrite axial.',
        limitationsEs:
            'Interpretar junto con ASDAS, función, inflamación objetiva y contexto terapéutico.',
        limitationsPt:
            'Interpretar com ASDAS, função, inflamação objetiva e contexto terapêutico.',
        reference: 'Garrett et al. · BASDAI.',
        fields: const [
          _FieldSpec.number('b1', 'Fatiga', 'Fadiga',
              unit: '0–10', min: 0, max: 10),
          _FieldSpec.number('b2', 'Dolor axial', 'Dor axial',
              unit: '0–10', min: 0, max: 10),
          _FieldSpec.number(
              'b3', 'Dolor/inflamación periférica', 'Dor/inchaço periférico',
              unit: '0–10', min: 0, max: 10),
          _FieldSpec.number(
              'b4', 'Entesitis/molestia al tacto', 'Entesite/dor ao toque',
              unit: '0–10', min: 0, max: 10),
          _FieldSpec.number('b5', 'Intensidad rigidez matinal',
              'Intensidade da rigidez matinal',
              unit: '0–10', min: 0, max: 10),
          _FieldSpec.number(
              'b6', 'Duración rigidez matinal', 'Duração da rigidez matinal',
              unit: '0–10', min: 0, max: 10),
        ],
      );

    case PlusScoresMb2Id.beighton:
      return _ScoreMeta(
        id: id,
        specialty: PlusScoresMb2Specialty.rheumatology,
        name: 'Beighton',
        icon: Icons.accessibility_outlined,
        purposeEs:
            'Cuantifica hipermovilidad articular generalizada mediante 9 maniobras.',
        purposePt:
            'Quantifica hipermobilidade articular generalizada por 9 manobras.',
        limitationsEs:
            'No diagnostica síndrome de Ehlers-Danlos ni otras enfermedades del tejido conectivo.',
        limitationsPt:
            'Não diagnostica síndrome de Ehlers-Danlos nem outras doenças do tecido conjuntivo.',
        reference:
            'Beighton score · Ehlers-Danlos Society age-adjusted thresholds.',
        fields: const [
          _FieldSpec.choice(
              'ageBand',
              'Umbral por edad',
              'Limiar por idade',
              [
                _ChoiceSpec(6, 'Prepuberal · ≥6', 'Pré-púbere · ≥6'),
                _ChoiceSpec(5, 'Adulto ≤50 · ≥5', 'Adulto ≤50 · ≥5'),
                _ChoiceSpec(4, 'Adulto >50 · ≥4', 'Adulto >50 · ≥4'),
              ],
              initial: 5),
          _FieldSpec.toggle(
              'm0', '5º dedo derecho >90°', '5º dedo direito >90°'),
          _FieldSpec.toggle(
              'm1', '5º dedo izquierdo >90°', '5º dedo esquerdo >90°'),
          _FieldSpec.toggle('m2', 'Pulgar derecho al antebrazo',
              'Polegar direito ao antebraço'),
          _FieldSpec.toggle('m3', 'Pulgar izquierdo al antebrazo',
              'Polegar esquerdo ao antebraço'),
          _FieldSpec.toggle('m4', 'Codo derecho hiperextensión >10°',
              'Cotovelo direito hiperextensão >10°'),
          _FieldSpec.toggle('m5', 'Codo izquierdo hiperextensión >10°',
              'Cotovelo esquerdo hiperextensão >10°'),
          _FieldSpec.toggle('m6', 'Rodilla derecha hiperextensión >10°',
              'Joelho direito hiperextensão >10°'),
          _FieldSpec.toggle('m7', 'Rodilla izquierda hiperextensión >10°',
              'Joelho esquerdo hiperextensão >10°'),
          _FieldSpec.toggle('m8', 'Palmas al piso con rodillas extendidas',
              'Palmas no chão com joelhos estendidos'),
        ],
      );

    case PlusScoresMb2Id.katzAdl:
      return _ScoreMeta(
        id: id,
        specialty: PlusScoresMb2Specialty.geriatrics,
        name: 'Katz ADL',
        icon: Icons.elderly_outlined,
        purposeEs:
            'Registra independencia en seis actividades básicas de la vida diaria.',
        purposePt:
            'Registra independência em seis atividades básicas de vida diária.',
        limitationsEs:
            'Debe reflejar función habitual y contexto basal; una enfermedad aguda puede producir dependencia transitoria.',
        limitationsPt:
            'Deve refletir função habitual e contexto basal; doença aguda pode produzir dependência transitória.',
        reference:
            'Katz et al. · Index of Independence in Activities of Daily Living.',
        fields: const [
          _FieldSpec.toggle(
              'k0', 'Independiente para baño', 'Independente para banho'),
          _FieldSpec.toggle('k1', 'Independiente para vestirse',
              'Independente para vestir-se'),
          _FieldSpec.toggle('k2', 'Independiente para usar baño',
              'Independente para usar banheiro'),
          _FieldSpec.toggle('k3', 'Independiente para transferencias',
              'Independente para transferências'),
          _FieldSpec.toggle(
              'k4', 'Continencia independiente', 'Continência independente'),
          _FieldSpec.toggle('k5', 'Independiente para alimentación',
              'Independente para alimentação'),
        ],
      );

    case PlusScoresMb2Id.lawtonBrody:
      return _ScoreMeta(
        id: id,
        specialty: PlusScoresMb2Specialty.geriatrics,
        name: 'Lawton-Brody IADL',
        icon: Icons.home_work_outlined,
        purposeEs: 'Registra independencia en ocho actividades instrumentales.',
        purposePt: 'Registra independência em oito atividades instrumentais.',
        limitationsEs:
            'Factores culturales, oportunidades previas y roles sociales pueden afectar el desempeño. Se puntúan los 8 dominios sin distinción por sexo.',
        limitationsPt:
            'Fatores culturais, oportunidades prévias e papéis sociais podem afetar o desempenho. Pontuamos os 8 domínios sem distinção por sexo.',
        reference: 'Lawton & Brody · Instrumental Activities of Daily Living.',
        fields: const [
          _FieldSpec.toggle('l0', 'Independiente con teléfono/comunicación',
              'Independente com telefone/comunicação'),
          _FieldSpec.toggle(
              'l1', 'Independiente para compras', 'Independente para compras'),
          _FieldSpec.toggle('l2', 'Independiente para preparar comida',
              'Independente para preparar comida'),
          _FieldSpec.toggle('l3', 'Independiente para tareas domésticas',
              'Independente para tarefas domésticas'),
          _FieldSpec.toggle('l4', 'Independiente para lavado de ropa',
              'Independente para lavar roupas'),
          _FieldSpec.toggle('l5', 'Independiente para transporte',
              'Independente para transporte'),
          _FieldSpec.toggle('l6', 'Independiente para medicación',
              'Independente para medicações'),
          _FieldSpec.toggle('l7', 'Independiente para finanzas',
              'Independente para finanças'),
        ],
      );

    case PlusScoresMb2Id.mmseScoreRecord:
      return _ScoreMeta(
        id: id,
        specialty: PlusScoresMb2Specialty.geriatrics,
        name: 'MMSE · registro de puntaje',
        icon: Icons.fact_check_outlined,
        purposeEs:
            'Registra el puntaje total obtenido con una versión MMSE/MMSE-2 autorizada.',
        purposePt:
            'Registra a pontuação total obtida com versão MMSE/MMSE-2 autorizada.',
        limitationsEs:
            'MedCases no reproduce ítems ni normas protegidas. Interpretar únicamente con una versión autorizada y normas adecuadas a idioma, edad y escolaridad.',
        limitationsPt:
            'O MedCases não reproduz itens nem normas protegidas. Interpretar apenas com versão autorizada e normas adequadas a idioma, idade e escolaridade.',
        reference: 'PAR · MMSE / MMSE-2 authorized materials and licensing.',
        fields: const [
          _FieldSpec.number(
              'score', 'Puntaje total autorizado', 'Pontuação total autorizada',
              unit: '0–30', min: 0, max: 30),
        ],
      );

    case PlusScoresMb2Id.isthDic2025:
      return _ScoreMeta(
        id: id,
        specialty: PlusScoresMb2Specialty.hematology,
        name: 'ISTH overt DIC · 2025',
        icon: Icons.bloodtype_outlined,
        purposeEs:
            'Calcula los criterios actualizados de DIC manifiesta de ISTH 2025.',
        purposePt:
            'Calcula os critérios atualizados de CIVD manifesta da ISTH 2025.',
        limitationsEs:
            'Aplicar solo en presencia de una condición subyacente asociada a DIC. El dímero D debe ingresarse como múltiplo del límite superior normal del ensayo local.',
        limitationsPt:
            'Aplicar apenas na presença de condição subjacente associada à CIVD. Dímero D deve ser informado como múltiplo do limite superior normal do ensaio local.',
        reference: 'ISTH SSC DIC 2025 · J Thromb Haemost 2025.',
        fields: const [
          _FieldSpec.toggle('associated', 'Condición subyacente asociada a DIC',
              'Condição subjacente associada à CIVD'),
          _FieldSpec.number('platelets', 'Plaquetas', 'Plaquetas',
              unit: '×10⁹/L', min: 0, max: 1000),
          _FieldSpec.number('ddimer', 'Dímero D / LSN', 'Dímero D / LSN',
              unit: '× límite superior normal', min: 0, max: 1000),
          _FieldSpec.number('pt', 'Prolongación de TP', 'Prolongamento do TP',
              unit: 'segundos sobre control', min: 0, max: 100),
          _FieldSpec.number('fibrinogen', 'Fibrinógeno', 'Fibrinogênio',
              unit: 'mg/dL', min: 0, max: 2000),
        ],
      );

    case PlusScoresMb2Id.fourTs:
      return _ScoreMeta(
        id: id,
        specialty: PlusScoresMb2Specialty.hematology,
        name: '4Ts · HIT',
        icon: Icons.medication_outlined,
        purposeEs:
            'Estima probabilidad pretest de trombocitopenia inducida por heparina.',
        purposePt:
            'Estima probabilidade pré-teste de trombocitopenia induzida por heparina.',
        limitationsEs:
            'La precisión depende de datos temporales correctos y de considerar causas alternativas de trombocitopenia.',
        limitationsPt:
            'A precisão depende de dados temporais corretos e de considerar causas alternativas de trombocitopenia.',
        reference: 'Warkentin et al. · 4Ts pretest clinical score for HIT.',
        fields: const [
          _FieldSpec.choice(
              'thrombocytopenia', 'Trombocitopenia', 'Trombocitopenia', [
            _ChoiceSpec(2, '>50% y nadir ≥20 · 2', '>50% e nadir ≥20 · 2'),
            _ChoiceSpec(
                1, '30–50% o nadir 10–19 · 1', '30–50% ou nadir 10–19 · 1'),
            _ChoiceSpec(0, '<30% o nadir <10 · 0', '<30% ou nadir <10 · 0'),
          ]),
          _FieldSpec.choice('timing', 'Tiempo de caída plaquetaria',
              'Tempo da queda plaquetária', [
            _ChoiceSpec(2, 'Días 5–10 o ≤1 día con exposición reciente · 2',
                'Dias 5–10 ou ≤1 dia com exposição recente · 2'),
            _ChoiceSpec(1, 'Compatible pero no claro · 1',
                'Compatível, porém não claro · 1'),
            _ChoiceSpec(0, '≤4 días sin exposición reciente · 0',
                '≤4 dias sem exposição recente · 0'),
          ]),
          _FieldSpec.choice(
              'thrombosis', 'Trombosis/secuela', 'Trombose/sequela', [
            _ChoiceSpec(2, 'Nueva trombosis/necrosis/reacción sistémica · 2',
                'Nova trombose/necrose/reação sistêmica · 2'),
            _ChoiceSpec(1, 'Progresiva/recurrente o sospecha · 1',
                'Progressiva/recorrente ou suspeita · 1'),
            _ChoiceSpec(0, 'Ninguna · 0', 'Nenhuma · 0'),
          ]),
          _FieldSpec.choice('other', 'Otras causas de trombocitopenia',
              'Outras causas de trombocitopenia', [
            _ChoiceSpec(2, 'Ninguna evidente · 2', 'Nenhuma evidente · 2'),
            _ChoiceSpec(1, 'Posible · 1', 'Possível · 1'),
            _ChoiceSpec(0, 'Definida · 0', 'Definida · 0'),
          ]),
        ],
      );

    case PlusScoresMb2Id.plasmic:
      return _ScoreMeta(
        id: id,
        specialty: PlusScoresMb2Specialty.hematology,
        name: 'PLASMIC',
        icon: Icons.science_outlined,
        purposeEs:
            'Estima probabilidad de deficiencia grave de ADAMTS13 en adultos con sospecha de PTT.',
        purposePt:
            'Estima probabilidade de deficiência grave de ADAMTS13 em adultos com suspeita de PTT.',
        limitationsEs:
            'Validado como score pretest. Hemólisis debe cumplir definición; no sustituye dosaje de ADAMTS13 ni evaluación de microangiopatía.',
        limitationsPt:
            'Validado como score pré-teste. Hemólise deve cumprir definição; não substitui dosagem de ADAMTS13 nem avaliação de microangiopatia.',
        reference: 'Bendapudi et al. · PLASMIC score.',
        fields: const [
          _FieldSpec.number('platelets', 'Plaquetas', 'Plaquetas',
              unit: '×10⁹/L', min: 0, max: 1000),
          _FieldSpec.toggle(
              'hemolysis',
              'Hemólisis: retic >2,5% o bilirrubina indirecta >2 mg/dL o haptoglobina indetectable',
              'Hemólise: retic >2,5% ou bilirrubina indireta >2 mg/dL ou haptoglobina indetectável'),
          _FieldSpec.toggle(
              'noCancer', 'Sin cáncer activo', 'Sem câncer ativo'),
          _FieldSpec.toggle(
              'noTransplant',
              'Sin trasplante sólido/células madre',
              'Sem transplante sólido/células-tronco'),
          _FieldSpec.number('mcv', 'VCM', 'VCM', unit: 'fL', min: 40, max: 150),
          _FieldSpec.number('inr', 'INR', 'INR', min: 0, max: 10),
          _FieldSpec.number('creatinine', 'Creatinina', 'Creatinina',
              unit: 'mg/dL', min: 0, max: 30),
        ],
      );

    case PlusScoresMb2Id.ipssR:
      return _ScoreMeta(
        id: id,
        specialty: PlusScoresMb2Specialty.hematology,
        name: 'IPSS-R · SMD',
        icon: Icons.analytics_outlined,
        purposeEs:
            'Estratifica síndrome mielodisplásico con citogenética, blastos y citopenias.',
        purposePt:
            'Estratifica síndrome mielodisplásica com citogenética, blastos e citopenias.',
        limitationsEs:
            'La categoría citogenética debe venir de clasificación válida. IPSS-M incorpora datos moleculares y puede refinar riesgo cuando están disponibles.',
        limitationsPt:
            'A categoria citogenética deve vir de classificação válida. IPSS-M incorpora dados moleculares e pode refinar risco quando disponíveis.',
        reference:
            'Greenberg et al. · Revised International Prognostic Scoring System for MDS.',
        fields: const [
          _FieldSpec.choice(
              'cyto', 'Citogenética IPSS-R', 'Citogenética IPSS-R', [
            _ChoiceSpec(0, 'Muy buena · 0', 'Muito boa · 0'),
            _ChoiceSpec(1, 'Buena · 1', 'Boa · 1'),
            _ChoiceSpec(2, 'Intermedia · 2', 'Intermediária · 2'),
            _ChoiceSpec(3, 'Mala · 3', 'Ruim · 3'),
            _ChoiceSpec(4, 'Muy mala · 4', 'Muito ruim · 4'),
          ]),
          _FieldSpec.number(
              'blasts', 'Blastos médula ósea', 'Blastos medula óssea',
              unit: '%', min: 0, max: 100),
          _FieldSpec.number('hb', 'Hemoglobina', 'Hemoglobina',
              unit: 'g/dL', min: 0, max: 30),
          _FieldSpec.number('platelets', 'Plaquetas', 'Plaquetas',
              unit: '×10⁹/L', min: 0, max: 2000),
          _FieldSpec.number(
              'anc', 'Neutrófilos absolutos', 'Neutrófilos absolutos',
              unit: '×10⁹/L', min: 0, max: 100),
        ],
      );

    case PlusScoresMb2Id.ipssProstate:
      const symptoms = [
        _ChoiceSpec(0, '0', '0'),
        _ChoiceSpec(1, '1', '1'),
        _ChoiceSpec(2, '2', '2'),
        _ChoiceSpec(3, '3', '3'),
        _ChoiceSpec(4, '4', '4'),
        _ChoiceSpec(5, '5', '5'),
      ];
      return _ScoreMeta(
        id: id,
        specialty: PlusScoresMb2Specialty.urology,
        name: 'IPSS · síntomas prostáticos',
        icon: Icons.water_drop_outlined,
        purposeEs:
            'Cuantifica siete dominios de síntomas urinarios bajos y calidad de vida.',
        purposePt:
            'Quantifica sete domínios de sintomas urinários baixos e qualidade de vida.',
        limitationsEs:
            'El IPSS describe gravedad de síntomas, no su etiología. Señales de alarma requieren evaluación específica.',
        limitationsPt:
            'O IPSS descreve gravidade dos sintomas, não sua etiologia. Sinais de alarme exigem avaliação específica.',
        reference: 'International Prostate Symptom Score / AUA Symptom Index.',
        fields: const [
          _FieldSpec.choice('u0', 'Vaciamiento incompleto',
              'Esvaziamento incompleto', symptoms),
          _FieldSpec.choice('u1', 'Frecuencia', 'Frequência', symptoms),
          _FieldSpec.choice('u2', 'Intermitencia', 'Intermitência', symptoms),
          _FieldSpec.choice('u3', 'Urgencia', 'Urgência', symptoms),
          _FieldSpec.choice('u4', 'Chorro débil', 'Jato fraco', symptoms),
          _FieldSpec.choice('u5', 'Esfuerzo', 'Esforço', symptoms),
          _FieldSpec.choice('u6', 'Nicturia', 'Noctúria', symptoms),
          _FieldSpec.choice('qol', 'Calidad de vida', 'Qualidade de vida', [
            _ChoiceSpec(0, '0 · Encantado', '0 · Muito satisfeito'),
            _ChoiceSpec(1, '1', '1'),
            _ChoiceSpec(2, '2', '2'),
            _ChoiceSpec(3, '3', '3'),
            _ChoiceSpec(4, '4', '4'),
            _ChoiceSpec(5, '5', '5'),
            _ChoiceSpec(6, '6 · Terrible', '6 · Péssimo'),
          ]),
        ],
      );

    case PlusScoresMb2Id.gleasonIsup:
      const patterns = [
        _ChoiceSpec(3, 'Patrón 3', 'Padrão 3'),
        _ChoiceSpec(4, 'Patrón 4', 'Padrão 4'),
        _ChoiceSpec(5, 'Patrón 5', 'Padrão 5'),
      ];
      return _ScoreMeta(
        id: id,
        specialty: PlusScoresMb2Specialty.urology,
        name: 'Gleason → ISUP Grade Group',
        icon: Icons.biotech_outlined,
        purposeEs:
            'Convierte patrones histológicos prostáticos informados en suma Gleason y Grade Group ISUP.',
        purposePt:
            'Converte padrões histológicos prostáticos informados em soma Gleason e Grade Group ISUP.',
        limitationsEs:
            'Los patrones deben ser asignados por anatomía patológica. Esta herramienta no interpreta imágenes ni biopsias.',
        limitationsPt:
            'Os padrões devem ser atribuídos pela anatomia patológica. Esta ferramenta não interpreta imagens nem biópsias.',
        reference:
            'ISUP prostate cancer grading consensus / WHO grading framework.',
        fields: const [
          _FieldSpec.choice(
              'primary', 'Patrón primario', 'Padrão primário', patterns,
              initial: 3),
          _FieldSpec.choice(
              'secondary', 'Patrón secundario', 'Padrão secundário', patterns,
              initial: 3),
        ],
      );

    case PlusScoresMb2Id.bosniak2019:
      return _ScoreMeta(
        id: id,
        specialty: PlusScoresMb2Specialty.urology,
        name: 'Bosniak v2019',
        icon: Icons.image_search_outlined,
        purposeEs:
            'Clasifica una masa renal quística con descriptores seleccionados de Bosniak 2019.',
        purposePt:
            'Classifica massa renal cística com descritores selecionados de Bosniak 2019.',
        limitationsEs:
            'Es una ayuda estructurada, no una lectura radiológica. Debe existir TC/RM renal técnicamente adecuada y evaluarse todos los descriptores aplicables.',
        limitationsPt:
            'É auxílio estruturado, não leitura radiológica. Deve haver TC/RM renal tecnicamente adequada e todos os descritores aplicáveis devem ser avaliados.',
        reference:
            'Silverman et al. · Bosniak Classification of Cystic Renal Masses, Version 2019.',
        fields: const [
          _FieldSpec.toggle('nodule', 'Nódulo realzante', 'Nódulo com realce'),
          _FieldSpec.toggle('irregular', 'Pared/septos realzantes irregulares',
              'Parede/septos com realce irregulares'),
          _FieldSpec.toggle('thick4', 'Pared/septos realzantes ≥4 mm',
              'Parede/septos com realce ≥4 mm'),
          _FieldSpec.toggle('thick3', 'Engrosamiento liso realzante de 3 mm',
              'Espessamento liso com realce de 3 mm'),
          _FieldSpec.number('septa', 'Número de septos finos realzantes',
              'Número de septos finos com realce',
              min: 0, max: 30),
          _FieldSpec.toggle('simple', 'Masa líquida simple de pared fina',
              'Massa líquida simples de parede fina'),
          _FieldSpec.toggle(
              't1',
              'RM: T1 heterogéneamente hiperintensa sin realce',
              'RM: T1 heterogeneamente hiperintensa sem realce'),
        ],
      );

    case PlusScoresMb2Id.snappe2:
      return _ScoreMeta(
        id: id,
        specialty: PlusScoresMb2Specialty.neonatology,
        name: 'SNAPPE-II',
        icon: Icons.child_friendly_outlined,
        purposeEs:
            'Índice neonatal de gravedad fisiológica y riesgo poblacional.',
        purposePt:
            'Índice neonatal de gravidade fisiológica e risco populacional.',
        limitationsEs:
            'El cociente PaO₂/FiO₂ original usa FiO₂ expresada en porcentaje, no fracción decimal. No usar como indicación terapéutica individual.',
        limitationsPt:
            'A relação PaO₂/FiO₂ original usa FiO₂ expressa em porcentagem, não fração decimal. Não usar como indicação terapêutica individual.',
        reference:
            'Richardson et al. · SNAP-II / SNAPPE-II neonatal severity score.',
        fields: const [
          _FieldSpec.number('map', 'Presión arterial media mínima',
              'Pressão arterial média mínima',
              unit: 'mmHg', min: 0, max: 200),
          _FieldSpec.number('temp', 'Temperatura mínima', 'Temperatura mínima',
              unit: '°C', min: 20, max: 45),
          _FieldSpec.number('ratio', 'PaO₂ / FiO₂ (%)', 'PaO₂ / FiO₂ (%)',
              unit: 'ratio con FiO₂ 21–100', min: 0, max: 10),
          _FieldSpec.number('ph', 'pH mínimo', 'pH mínimo', min: 5, max: 8),
          _FieldSpec.toggle(
              'seizures', 'Convulsiones múltiples', 'Convulsões múltiplas'),
          _FieldSpec.number('urine', 'Diuresis', 'Diurese',
              unit: 'mL/kg/h', min: 0, max: 20),
          _FieldSpec.number('apgar', 'Apgar 5 min', 'Apgar 5 min',
              unit: '0–10', min: 0, max: 10),
          _FieldSpec.number('weight', 'Peso al nacer', 'Peso ao nascer',
              unit: 'g', min: 0, max: 10000),
          _FieldSpec.toggle('sga', 'Pequeño para edad gestacional <p3',
              'Pequeno para idade gestacional <p3'),
        ],
      );

    case PlusScoresMb2Id.newBallard:
      return _ScoreMeta(
        id: id,
        specialty: PlusScoresMb2Specialty.neonatology,
        name: 'New Ballard · conversión',
        icon: Icons.calendar_month_outlined,
        purposeEs:
            'Convierte un puntaje total New Ballard ya obtenido en edad gestacional estimada.',
        purposePt:
            'Converte pontuação total New Ballard já obtida em idade gestacional estimada.',
        limitationsEs:
            'MedCases no reproduce la hoja completa. La conversión sigue la grilla publicada; confirmar el puntaje mediante una hoja autorizada/validada.',
        limitationsPt:
            'O MedCases não reproduz a folha completa. A conversão segue a grade publicada; confirmar a pontuação em folha autorizada/validada.',
        reference: 'Ballard et al. · New Ballard Score official scoring grid.',
        fields: const [
          _FieldSpec.number('total', 'Puntaje total New Ballard',
              'Pontuação total New Ballard',
              unit: '-10 a 50', min: -10, max: 50),
        ],
      );

    case PlusScoresMb2Id.modifiedBell:
      return _ScoreMeta(
        id: id,
        specialty: PlusScoresMb2Specialty.neonatology,
        name: 'Bell Modificado · NEC',
        icon: Icons.warning_amber_outlined,
        purposeEs:
            'Clasifica enterocolitis necrosante por hallazgos clínicos, laboratoriales y radiológicos seleccionados.',
        purposePt:
            'Classifica enterocolite necrosante por achados clínicos, laboratoriais e radiológicos selecionados.',
        limitationsEs:
            'Esta versión guiada asigna el estadio más alto respaldado por los hallazgos seleccionados; la clasificación completa exige evaluación neonatal/radiológica integral.',
        limitationsPt:
            'Esta versão guiada atribui o estágio mais alto sustentado pelos achados selecionados; a classificação completa exige avaliação neonatal/radiológica integral.',
        reference: 'Bell staging · Walsh & Kliegman modified Bell criteria.',
        fields: const [
          _FieldSpec.toggle('blood', 'Sangre macroscópica rectal',
              'Sangue macroscópico retal'),
          _FieldSpec.toggle(
              'pneumatosis', 'Neumatosis intestinal', 'Pneumatose intestinal'),
          _FieldSpec.toggle(
              'portal', 'Gas portal y/o ascitis', 'Gás portal e/ou ascite'),
          _FieldSpec.toggle(
              'mildLab',
              'Acidosis metabólica leve y/o trombocitopenia',
              'Acidose metabólica leve e/ou trombocitopenia'),
          _FieldSpec.toggle(
              'severe',
              'Deterioro sistémico grave sin aire libre',
              'Deterioração sistêmica grave sem ar livre'),
          _FieldSpec.toggle('freeAir', 'Neumoperitoneo', 'Pneumoperitônio'),
        ],
      );
  }
}
