/// MedCases data-driven post-provider compliance profiles.
///
/// The application code is generic. Clinical constraints live in these
/// evidence-ID keyed profiles selected by the existing curated resolver.
// MEDCASES_REQUIRED_ASSERTION_RULES_PROFILE_V1
class ClinicalCrosscuttingRequiredAssertionRule {
  final String id;
  final List<List<String>> queryAllOfGroups;
  final List<List<String>> requiredOutputGroups;

  const ClinicalCrosscuttingRequiredAssertionRule({
    required this.id,
    required this.queryAllOfGroups,
    required this.requiredOutputGroups,
  });
}

class ClinicalCrosscuttingComplianceProfile {
  final String evidenceId;
  final List<String> forbiddenNeedles;
  final List<String> classificationNeedles;
  final List<ClinicalCrosscuttingRequiredAssertionRule> requiredAssertionRules;
  final String ptReplacement;
  final String esReplacement;
  final String? ptClassificationReplacement;
  final String? esClassificationReplacement;
  final double? perKgDayMin;
  final double? perKgDayMax;

  const ClinicalCrosscuttingComplianceProfile({
    required this.evidenceId,
    required this.forbiddenNeedles,
    this.classificationNeedles = const <String>[],
    this.requiredAssertionRules =
        const <ClinicalCrosscuttingRequiredAssertionRule>[],
    required this.ptReplacement,
    required this.esReplacement,
    this.ptClassificationReplacement,
    this.esClassificationReplacement,
    this.perKgDayMin,
    this.perKgDayMax,
  });
}

const clinicalCrosscuttingComplianceProfiles =
    <ClinicalCrosscuttingComplianceProfile>[
      ClinicalCrosscuttingComplianceProfile(
        evidenceId: 'adult_iv_fluid_therapy',
        forbiddenNeedles: <String>[
          'holliday-segar',
          'holliday segar',
          '4-2-1',
          '4 ml/kg',
          '2 ml/kg',
          '1 ml/kg',
          'classificacao do paciente: estavel',
          'sem sinais de desidratacao ou sobrecarga',
          'estavel e adequado para fluidos de manutencao',
          'clasificacion del paciente: estable',
          'sin signos de deshidratacion o sobrecarga',
          'estable y adecuado para fluidos de mantenimiento',
        ],
        classificationNeedles: <String>[
          'classificacao',
          'classificar',
          'clasificacion',
          'clasificar',
        ],
        perKgDayMin: 25,
        perKgDayMax: 30,
        ptReplacement: '''
🟥 FLUIDO DE MANUTENÇÃO — ADULTO

🚨 Conduta:
• Para manutenção IV rotineira em adulto, usar inicialmente 25–30 mL/kg/dia de água e ajustar pela clínica, perdas, ingestão, balanço e exames.
{WEIGHT_CALC_PT}
• Considerar 20–25 mL/kg/dia em situações como fragilidade/idade avançada, insuficiência renal ou cardíaca e risco de realimentação, conforme avaliação clínica.
• A regra pediátrica de Holliday–Segar/4-2-1 não deve ser usada como fórmula padrão de manutenção no adulto.

📌 Reavaliar eletrólitos, função renal, balanço, perfusão e evolução clínica.''',
        esReplacement: '''
🟥 FLUIDO DE MANTENIMIENTO — ADULTO

🚨 Conducta:
• Para mantenimiento IV rutinario en adultos, usar inicialmente 25–30 mL/kg/día de agua y ajustar según clínica, pérdidas, ingesta, balance y laboratorio.
{WEIGHT_CALC_ES}
• Considerar 20–25 mL/kg/día en situaciones como fragilidad/edad avanzada, insuficiencia renal o cardíaca y riesgo de realimentación, según evaluación clínica.
• La regla pediátrica de Holliday–Segar/4-2-1 no debe usarse como fórmula estándar de mantenimiento en adultos.

📌 Reevaluar electrolitos, función renal, balance, perfusión y evolución clínica.''',
        ptClassificationReplacement: '''
🟥 FLUIDOTERAPIA

🚨 Conduta imediata:
• Categoria terapêutica: manutenção IV rotineira.
• Estado volêmico: dados insuficientes para classificar como euvolêmico, hipovolêmico ou hipervolêmico apenas com peso e ausência de comorbidades.

📌 Para classificar o estado volêmico, integrar história, pressão/FC/perfusão, JVP/edema, balanço e tendências, peso e exames.''',
        esClassificationReplacement: '''
🟥 FLUIDOTERAPIA

🚨 Conducta inmediata:
• Categoría terapéutica: mantenimiento IV rutinario.
• Estado de volumen: datos insuficientes para clasificar como euvolémico, hipovolémico o hipervolémico solo con peso y ausencia de comorbilidades.

📌 Para clasificar el estado de volumen, integrar historia, presión/FC/perfusión, JVP/edema, balance y tendencias, peso y laboratorio.''',
      ),
      ClinicalCrosscuttingComplianceProfile(
        evidenceId: 'norepinephrine_preparation_and_access',
        forbiddenNeedles: <String>[
          'acesso venoso central e ideal',
          'acesso central e ideal',
          'acesso venoso central e preferivel',
          'acesso central e preferivel',
          'acesso venoso central preferivel',
          'acesso central preferivel',
          'acceso venoso central es ideal',
          'acceso central es ideal',
          'acceso venoso central es preferible',
          'acceso central es preferible',
          'acceso venoso central preferible',
          'acceso central preferible',
          'evitar acesso venoso periferico',
          'evitar acesso periferico',
          'evitar siempre la via periferica',
          'hiperglicemia grave nao tratada',
          'hiperglucemia grave no tratada',
          'choque hipovolemico nao corrigido',
          'shock hipovolemico no corregido',
          'diluir em solucao salina ou dextrose',
          'diluir em solucao salina',
          'diluir em dextrose',
          'diluir en solucion salina o dextrosa',
          'diluir en solucion salina',
          'diluir en dextrosa',

          // MEDCASES_NOREPI_PHYSICAL_FAIL_CLOSED_NEEDLES_V1
          // Physical false-negative coverage, profile-only; engine stays generic.
          'veia central ou periferica',
          'cateter 16-18g em veia central ou periferica',
          'diluindo 4 mg em 250 ml',
          'reavaliar resposta apos 30 minutos',
          'nao iniciar se houver ausencia de acesso venoso adequado',
          'contrarreacao grave',
          'vena central o periferica',
          'cateter 16-18g en vena central o periferica',
          'diluyendo 4 mg en 250 ml',
          'reevaluar respuesta despues de 30 minutos',
          'reevaluar respuesta a los 30 minutos',
          'no iniciar si no hay acceso venoso adecuado',
          'contrarreaccion grave',

          // MEDCASES_NOREPI_PREFERRED_CENTRAL_FALSE_NEGATIVE_V1
          // Physical wording variants only; generic engine remains frozen.
          'preferencialmente veia central',
          'preferencialmente via central',
          'preferencialmente acesso central',
          'de preferencia veia central',
          'de preferencia via central',
          'de preferencia acesso central',
          'via central preferencial',
          'acesso central preferencial',
          'preferentemente vena central',
          'preferentemente via central',
          'preferentemente acceso central',
          'de preferencia vena central',
          'de preferencia acceso central',
        ],
        requiredAssertionRules: <ClinicalCrosscuttingRequiredAssertionRule>[
          ClinicalCrosscuttingRequiredAssertionRule(
            id: 'norepi_access_core',
            queryAllOfGroups: <List<String>>[
              <String>[
                'acesso',
                'via venosa',
                'por qual acesso',
                'access',
                'acceso',
              ],
            ],
            requiredOutputGroups: <List<String>>[
              <String>[
                'nao atrasar o inicio aguardando acesso venoso central',
                'no retrasar el inicio esperando un acceso venoso central',
              ],
              <String>['acesso periferico adequado', 'via periferica adequada'],
              <String>[
                'preferencialmente proximal',
                'preferentemente proximal',
              ],
              <String>['extravasamento', 'extravasacion'],
              <String>['migrar para acesso central', 'migrar a acceso central'],
            ],
          ),
          ClinicalCrosscuttingRequiredAssertionRule(
            id: 'norepi_preparation_core',
            queryAllOfGroups: <List<String>>[
              <String>[
                'preparar',
                'preparo',
                'preparacao',
                'diluicao',
                'diluir',
                'concentracao',
                'preparacion',
                'dilucion',
                'concentracion',
              ],
            ],
            requiredOutputGroups: <List<String>>[
              <String>[
                'confirmar sempre a apresentacao e a concentracao reais',
                'confirmar siempre la presentacion y concentracion reales',
              ],
              <String>['apresentacao premisturada', 'presentacion premezclada'],
              <String>['pronta para administrar', 'lista para administrar'],
              <String>[
                'nao requer diluicao adicional',
                'no requiere dilucion adicional',
              ],
              <String>[
                'formulacoes manipuladas ou institucionais',
                'formulaciones preparadas o institucionales',
              ],
            ],
          ),
        ],
        ptReplacement: '''
NORADRENALINA — CHOQUE SÉPTICO

Conduta imediata:
• Noradrenalina é vasopressor de primeira linha no choque séptico.
• Não atrasar o início aguardando acesso venoso central. Pode ser iniciada por acesso periférico adequado, preferencialmente proximal, com inspeção frequente do sítio e vigilância de extravasamento.
• Se a infusão se prolongar, migrar para acesso central conforme duração, necessidade e protocolo local.

Tratamento farmacológico:
• Confirmar sempre a apresentação e a concentração reais antes de programar a bomba.
• Na apresentação premisturada Baxter/DailyMed 2026 contemplada pela base:\n• 4 mg/250 mL = 16 mcg/mL\n• 8 mg/250 mL = 32 mcg/mL\n• 16 mg/250 mL = 64 mcg/mL
• Essa apresentação é pronta para administrar e não requer diluição adicional.
• Formulações manipuladas ou institucionais podem usar concentrações diferentes.

Pontos-chave:
• Na bula premisturada citada, contraindicações listadas: nenhuma.
• Corrigir hipovolemia antes da terapia é uma precaução/instrução de administração, não uma contraindicação absoluta.
• A hiperglicemia não é contraindicação absoluta listada.

Red flags:
• Extravasamento: risco de isquemia/necrose local.
''',
        esReplacement: '''
NORADRENALINA — SHOCK SÉPTICO

Conducta inmediata:
• La noradrenalina es el vasopresor de primera línea en el shock séptico.
• No retrasar el inicio esperando un acceso venoso central. Puede iniciarse por una vía periférica adecuada, preferentemente proximal, con inspección frecuente del sitio y vigilancia de extravasación.
• Si la infusión se prolonga, migrar a acceso central según duración, necesidad y protocolo local.

Tratamiento farmacológico:
• Confirmar siempre la presentación y concentración reales antes de programar la bomba.
• En la presentación premezclada Baxter/DailyMed 2026 contemplada por la base:\n• 4 mg/250 mL = 16 mcg/mL\n• 8 mg/250 mL = 32 mcg/mL\n• 16 mg/250 mL = 64 mcg/mL
• Esa presentación está lista para administrar y no requiere dilución adicional.
• Formulaciones preparadas o institucionales pueden usar concentraciones diferentes.

Puntos clave:
• En la ficha de la presentación premezclada citada, contraindicaciones listadas: ninguna.
• Corregir la hipovolemia antes de la terapia es una precaución/instrucción de administración, no una contraindicación absoluta.
• La hiperglucemia no figura como contraindicación absoluta.

Red flags:
• Extravasación: riesgo de isquemia/necrosis local.
''',
      ),
    ];

ClinicalCrosscuttingComplianceProfile? clinicalCrosscuttingComplianceProfileFor(
  String evidenceId,
) {
  for (final profile in clinicalCrosscuttingComplianceProfiles) {
    if (profile.evidenceId == evidenceId) return profile;
  }
  return null;
}
