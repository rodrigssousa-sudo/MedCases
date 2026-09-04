/// MedCases cross-cutting clinical evidence database.
///
/// Scope: high-frequency cross-cutting clinical intents that may not map cleanly
/// to one of the 270 pathology identities but still need authoritative context.
///
/// This database is intentionally data-only. Matching logic lives in
/// ClinicalCrosscuttingEvidenceResolver.
class ClinicalEvidenceSource {
  final String id;
  final String organization;
  final String title;
  final String sourceType;
  final String publicationDate;
  final String url;
  final String? doi;

  const ClinicalEvidenceSource({
    required this.id,
    required this.organization,
    required this.title,
    required this.sourceType,
    required this.publicationDate,
    required this.url,
    this.doi,
  });
}

class ClinicalCrosscuttingEvidenceEntry {
  final String id;
  final String version;
  final List<String> aliases;
  final List<String> ptFacts;
  final List<String> esFacts;
  final List<String> sourceIds;

  const ClinicalCrosscuttingEvidenceEntry({
    required this.id,
    required this.version,
    required this.aliases,
    required this.ptFacts,
    required this.esFacts,
    required this.sourceIds,
  });
}

const clinicalCrosscuttingEvidenceSources = <ClinicalEvidenceSource>[
  ClinicalEvidenceSource(
    id: 'NICE_CG174',
    organization: 'NICE',
    title: 'Intravenous fluid therapy in adults in hospital — Recommendations',
    sourceType: 'official_guideline',
    publicationDate: '2013-12-10; updated 2017-05-05',
    url: 'https://www.nice.org.uk/guidance/cg174/chapter/recommendations',
  ),
  ClinicalEvidenceSource(
    id: 'NICE_CG174_NCBI',
    organization: 'NICE / NCBI Bookshelf',
    title: 'Intravenous fluid therapy in adults in hospital — full guideline',
    sourceType: 'official_guideline_archive',
    publicationDate: '2013; updated 2017',
    url: 'https://www.ncbi.nlm.nih.gov/books/NBK554180/',
  ),
  ClinicalEvidenceSource(
    id: 'ESICM_FLUID_PART1_2024',
    organization: 'ESICM',
    title:
        'Clinical practice guideline on fluid therapy in adult critically ill patients: Part 1 — choice of resuscitation fluids',
    sourceType: 'practice_guideline',
    publicationDate: '2024-05-21',
    url: 'https://pubmed.ncbi.nlm.nih.gov/38771364/',
    doi: '10.1007/s00134-024-07369-9',
  ),
  ClinicalEvidenceSource(
    id: 'ESICM_FLUID_PART2_2025',
    organization: 'ESICM',
    title:
        'Clinical practice guideline on fluid therapy in adult critically ill patients: Part 2 — volume of resuscitation fluids',
    sourceType: 'practice_guideline',
    publicationDate: '2025-03-31',
    url: 'https://pubmed.ncbi.nlm.nih.gov/40163133/',
    doi: '10.1007/s00134-025-07840-1',
  ),
  ClinicalEvidenceSource(
    id: 'SSC_2026',
    organization: 'Surviving Sepsis Campaign / SCCM',
    title:
        'International Guidelines for Management of Sepsis and Septic Shock 2026',
    sourceType: 'international_guideline',
    publicationDate: '2026',
    url:
        'https://sccm.org/clinical-resources/guidelines/guidelines/surviving-sepsis-campaign-international-guidelines-for-management-of-sepsis-and-septic-shock-2026',
    doi: '10.1007/s00134-026-08361-1',
  ),
  ClinicalEvidenceSource(
    id: 'ACC_AHA_ACS_2025',
    organization: 'ACC/AHA/ACEP/NAEMSP/SCAI',
    title:
        '2025 Guideline for the Management of Patients With Acute Coronary Syndromes',
    sourceType: 'multisociety_guideline',
    publicationDate: '2025-02-27',
    url: 'https://www.jacc.org/doi/10.1016/j.jacc.2024.11.009',
    doi: '10.1016/j.jacc.2024.11.009',
  ),
  ClinicalEvidenceSource(
    id: 'AHA_ACS_TOP_2025',
    organization: 'American Heart Association',
    title: 'Top Things to Know: 2025 Guideline for Acute Coronary Syndromes',
    sourceType: 'official_guideline_summary',
    publicationDate: '2025-02-27',
    url:
        'https://professional.heart.org/en/science-news/2025-guideline-for-the-management-of-patients-with-acute-coronary-syndromes/top-things-to-know',
  ),
  ClinicalEvidenceSource(
    id: 'ESC_ACS_2023',
    organization: 'European Society of Cardiology',
    title: '2023 ESC Guidelines for the management of acute coronary syndromes',
    sourceType: 'society_guideline',
    publicationDate: '2023-08-25',
    url: 'https://pubmed.ncbi.nlm.nih.gov/37622654/',
    doi: '10.1093/eurheartj/ehad191',
  ),
  ClinicalEvidenceSource(
    id: 'CLARITY_TIMI28',
    organization: 'TIMI Study Group / NEJM',
    title:
        'Addition of Clopidogrel to Aspirin and Fibrinolytic Therapy for STEMI',
    sourceType: 'randomized_controlled_trial',
    publicationDate: '2005-03-24',
    url: 'https://www.nejm.org/doi/full/10.1056/NEJMoa050522',
    doi: '10.1056/NEJMoa050522',
  ),
  ClinicalEvidenceSource(
    id: 'PCI_CLARITY',
    organization: 'TIMI Study Group / JAMA',
    title:
        'Effect of clopidogrel pretreatment before PCI after fibrinolysis: PCI-CLARITY',
    sourceType: 'randomized_trial_analysis',
    publicationDate: '2005-09-14',
    url: 'https://pubmed.ncbi.nlm.nih.gov/16143698/',
    doi: '10.1001/jama.294.10.1224',
  ),
  ClinicalEvidenceSource(
    id: 'COMMIT_CLOPIDOGREL',
    organization: 'COMMIT Collaborative Group / Lancet',
    title:
        'Addition of clopidogrel to aspirin in 45,852 patients with acute myocardial infarction',
    sourceType: 'randomized_controlled_trial',
    publicationDate: '2005-11-05',
    url: 'https://pubmed.ncbi.nlm.nih.gov/16271642/',
    doi: '10.1016/S0140-6736(05)67660-X',
  ),
  ClinicalEvidenceSource(
    id: 'DAILYMED_CLOPIDOGREL',
    organization: 'U.S. National Library of Medicine / FDA label',
    title: 'Clopidogrel tablets — prescribing information',
    sourceType: 'drug_label',
    publicationDate: 'current label accessed 2026-09-03',
    url:
        'https://www.dailymed.nlm.nih.gov/dailymed/fda/fdaDrugXsl.cfm?setid=2619ccc2-02de-09ba-e063-6394a90a7f2d',
  ),
  ClinicalEvidenceSource(
    id: 'DAILYMED_NOREPINEPHRINE_2026',
    organization: 'U.S. National Library of Medicine / FDA label',
    title: 'Norepinephrine Bitartrate injection — prescribing information',
    sourceType: 'drug_label',
    publicationDate: '2026-02-06',
    url:
        'https://www.dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=6363e9b4-29df-4553-904d-a563e5adda6e',
  ),
];

const clinicalCrosscuttingEvidenceEntries = <ClinicalCrosscuttingEvidenceEntry>[
  ClinicalCrosscuttingEvidenceEntry(
    id: 'adult_iv_fluid_therapy',
    version: '2026.09.04.v2',
    aliases: <String>[
      'fluidoterapia',
      'fluido intravenoso',
      'fluidos intravenosos',
      'fluido de manutencao',
      'fluidos de manutencao',
      'manutencao iv',
      'manutencao intravenosa',
      'manutencao rotineira',
      'fluido de manutencao iv',
      'fluido intravenoso de manutencao',
      'manutencao hidrica',
      'volume de manutencao',
      'hidratação intravenosa',
      'hidratacao intravenosa',
      'fluidoterapia intravenosa',
      'mantenimiento de fluidos',
      'fluidos intravenosos de mantenimiento',
      'volumen de mantenimiento',
      'hidratacion intravenosa',
    ],
    ptFacts: <String>[
      'Separar sempre as 5 categorias funcionais da fluidoterapia: Ressuscitação, Manutenção rotineira, Reposição, Redistribuição e Reavaliação.',
      'Para manutenção IV rotineira isolada em adulto, a referência NICE usa inicialmente 25–30 mL/kg/dia de água, cerca de 1 mmol/kg/dia de sódio, potássio e cloreto e 50–100 g/dia de glicose; ajustar pela clínica, perdas, ingestão e exames.',
      'Considerar volumes menores, por exemplo 20–25 mL/kg/dia, em idosos/frágeis, insuficiência renal ou cardíaca e pacientes desnutridos com risco de realimentação.',
      'Peso isolado NÃO classifica estado volêmico, hidratação adequada nem peso ideal. Estado volêmico exige história, exame, tendências hemodinâmicas, balanço, peso e laboratório.',
      'Se o usuário já pediu explicitamente “manutenção”, a categoria terapêutica é manutenção rotineira; isso NÃO autoriza inferir euvolemia/hipovolemia/hipervolemia sem dados.',
      'Se perguntarem “qual a classificação?” no contexto de fluidos, responder primeiro qual eixo é sustentado pelos dados; se o eixo não estiver definido, explicitar a limitação e pedir o eixo desejado em vez de criar uma classificação.',
      'Se faltarem dados clínicos de estado volêmico (por exemplo pressão/FC/perfusão, JVP/edema, balanço/tendências e laboratório), a classificação do estado volêmico deve ser “dados insuficientes”; NÃO preencher como euvolêmico, hipovolêmico ou hipervolêmico apenas para satisfazer um template. Ausência de comorbidades NÃO é evidência de euvolemia.',
      'Não aplicar fórmula de manutenção a ressuscitação de choque/hipoperfusão. Ressuscitação usa avaliação dinâmica e reavaliação frequente.',
    ],
    esFacts: <String>[
      'Separar siempre las 5 categorías funcionales de fluidoterapia: Reanimación, Mantenimiento rutinario, Reposición, Redistribución y Reevaluación.',
      'Para mantenimiento IV rutinario aislado en adultos, NICE usa inicialmente 25–30 mL/kg/día de agua, aproximadamente 1 mmol/kg/día de sodio, potasio y cloro y 50–100 g/día de glucosa; ajustar según clínica, pérdidas, ingesta y laboratorio.',
      'Considerar volúmenes menores, por ejemplo 20–25 mL/kg/día, en adultos mayores/frágiles, insuficiencia renal o cardíaca y desnutrición con riesgo de realimentación.',
      'El peso aislado NO clasifica el estado de volumen, hidratación adecuada ni peso ideal. El estado de volumen requiere historia, examen, tendencias hemodinámicas, balance, peso y laboratorio.',
      'Si el usuario pidió explícitamente “mantenimiento”, la categoría terapéutica es mantenimiento rutinario; esto NO permite inferir euvolemia/hipovolemia/hipervolemia sin datos.',
      'Si preguntan “¿cuál es la clasificación?” en contexto de fluidos, responder primero qué eje está sustentado por los datos; si el eje no está definido, explicitar la limitación y pedir el eje deseado en vez de inventar una clasificación.',
      'Si faltan datos clínicos del estado de volumen (por ejemplo presión/FC/perfusión, JVP/edema, balance/tendencias y laboratorio), la clasificación del estado de volumen debe ser “datos insuficientes”; NO completar como euvolémico, hipovolémico o hipervolémico solo para satisfacer una plantilla. La ausencia de comorbilidades NO demuestra euvolemia.',
      'No aplicar la fórmula de mantenimiento a la reanimación de shock/hipoperfusión. La reanimación requiere evaluación dinámica y reevaluación frecuente.',
    ],
    sourceIds: <String>[
      'NICE_CG174',
      'NICE_CG174_NCBI',
      'ESICM_FLUID_PART1_2024',
      'ESICM_FLUID_PART2_2025',
      'SSC_2026',
    ],
  ),
  ClinicalCrosscuttingEvidenceEntry(
    id: 'acs_stemi_reperfusion_antiplatelet',
    version: '2026.09.03.v1',
    aliases: <String>[
      'iamcest',
      'stemi',
      'infarto com supra',
      'infarto agudo do miocardio com supra',
      'infarto agudo do miocárdio com supra',
      'elevacao do st',
      'elevação do st',
      'supra de st',
      'sindrome coronariana aguda',
      'síndrome coronariana aguda',
      'infarto con elevacion del st',
      'infarto con elevación del st',
      'elevacion del st',
      'elevación del st',
      'sindrome coronario agudo',
      'síndrome coronario agudo',
    ],
    ptFacts: <String>[
      'No IAMCEST, definir a estratégia de reperfusão antes de transformar um esquema dependente da estratégia em dose universal.',
      'Em pacientes com SCA submetidos a PCI, ticagrelor ou prasugrel são preferidos ao clopidogrel quando apropriado segundo ACC/AHA 2025.',
      'Clopidogrel 600 mg pertence ao contexto de estratégia invasiva/PCI e NÃO deve ser apresentado como carga universal se fibrinólise ainda é uma possibilidade.',
      'Quando fibrinólise é a estratégia de reperfusão, ACC/AHA 2025 recomenda clopidogrel 300 mg de carga e depois 75 mg/dia em pacientes com menos de 75 anos; a partir de 75 anos inicia 75 mg/dia sem carga.',
      'ESC 2023 usa linguagem ligeiramente diferente no limiar etário da fibrinólise: 300 mg inicialmente e 75 mg para pacientes >75 anos. Registrar a diferença de redação; para 68 anos ambas as diretrizes convergem em 300 mg com fibrinólise.',
      'Se a estratégia de reperfusão não foi informada, dizer que a escolha/carga do P2Y12 depende de PCI versus fibrinólise em vez de fixar uma carga conflitante.',
      'Não misturar simultaneamente uma carga própria de PCI com a recomendação de “considerar trombólise” como se fossem o mesmo regime.',
    ],
    esFacts: <String>[
      'En IAMCEST, definir la estrategia de reperfusión antes de convertir un esquema dependiente de la estrategia en una dosis universal.',
      'En pacientes con SCA sometidos a PCI, ticagrelor o prasugrel se prefieren a clopidogrel cuando sean apropiados según ACC/AHA 2025.',
      'Clopidogrel 600 mg pertenece al contexto de estrategia invasiva/PCI y NO debe presentarse como carga universal si la fibrinólisis todavía es una posibilidad.',
      'Cuando la fibrinólisis es la estrategia de reperfusión, ACC/AHA 2025 recomienda clopidogrel 300 mg de carga y luego 75 mg/día en pacientes menores de 75 años; desde 75 años inicia 75 mg/día sin carga.',
      'ESC 2023 usa una redacción levemente diferente para el umbral etario en fibrinólisis: 300 mg inicialmente y 75 mg para pacientes >75 años. Registrar la diferencia; para 68 años ambas guías convergen en 300 mg con fibrinólisis.',
      'Si no se informó la estrategia de reperfusión, explicar que la elección/carga del P2Y12 depende de PCI versus fibrinólisis en vez de fijar una carga conflictiva.',
      'No mezclar simultáneamente una carga propia de PCI con la recomendación de “considerar trombólisis” como si fueran el mismo régimen.',
    ],
    sourceIds: <String>[
      'ACC_AHA_ACS_2025',
      'AHA_ACS_TOP_2025',
      'ESC_ACS_2023',
      'CLARITY_TIMI28',
      'PCI_CLARITY',
      'COMMIT_CLOPIDOGREL',
      'DAILYMED_CLOPIDOGREL',
    ],
  ),
  ClinicalCrosscuttingEvidenceEntry(
    id: 'norepinephrine_preparation_and_access',
    version: '2026.09.04.v2',
    aliases: <String>[
      'noradrenalina',
      'norepinefrina',
      'norepinephrine',
      'preparo de noradrenalina',
      'preparacao de noradrenalina',
      'preparação de noradrenalina',
      'diluicao de noradrenalina',
      'diluição de noradrenalina',
      'dilucion de noradrenalina',
      'dilución de noradrenalina',
      'velocidade de infusao de noradrenalina',
      'velocidad de infusion de norepinefrina',
    ],
    ptFacts: <String>[
      'Noradrenalina é vasopressor de primeira linha no choque séptico segundo SSC 2026.',
      'No choque séptico, iniciar vasopressor por acesso periférico é aceitável para restaurar PAM e é preferível a atrasar o início aguardando acesso venoso central; exige acesso de boa qualidade, inspeção frequente e vigilância de extravasamento.',
      'Acesso central continua útil quando a necessidade se prolonga ou conforme protocolo local, mas “evitar periférico sempre” é uma regra excessiva e desatualizada.',
      'No choque séptico, NÃO apresentar acesso venoso central como pré-requisito nem como motivo para atrasar o vasopressor: a SSC 2026 sugere iniciar perifericamente para restaurar PAM em vez de esperar acesso central.',
      'Formulações premixadas atuais de norepinefrina incluem 4 mg/250 mL = 16 mcg/mL, 8 mg/250 mL = 32 mcg/mL e 16 mg/250 mL = 64 mcg/mL. Confirmar sempre apresentação real e concentração antes de programar a bomba.',
      'Na apresentação premixada Baxter/DailyMed 2026 citada nesta base, o produto é pronto para administrar e não requer diluição adicional antes da infusão.',
      'Na bula Baxter/DailyMed 2026 citada nesta base, CONTRAINDICAÇÕES listadas: nenhuma. Hiperglicemia não é uma contraindicação absoluta listada; corrigir hipovolemia antes da terapia é instrução/precaução de administração, não uma contraindicação absoluta da bula.',
      'Concentrações manipuladas/institucionais podem diferir; não tratar uma única diluição como padrão universal sem conhecer produto e protocolo local.',
      'Extravasamento pode causar isquemia/necrose; monitorar o sítio e tratar imediatamente conforme protocolo se ocorrer.',
    ],
    esFacts: <String>[
      'La norepinefrina es el vasopresor de primera línea en shock séptico según SSC 2026.',
      'En shock séptico, iniciar vasopresor por acceso periférico es aceptable para restaurar la PAM y es preferible a retrasar el inicio esperando un acceso venoso central; requiere un acceso de buena calidad, inspección frecuente y vigilancia de extravasación.',
      'El acceso central sigue siendo útil si la necesidad se prolonga o según protocolo local, pero “evitar siempre la vía periférica” es una regla excesiva y desactualizada.',
      'En shock séptico, NO presentar el acceso venoso central como requisito previo ni como motivo para retrasar el vasopresor: SSC 2026 sugiere iniciarlo por vía periférica para restaurar la PAM en lugar de esperar un acceso central.',
      'Presentaciones premezcladas actuales incluyen 4 mg/250 mL = 16 mcg/mL, 8 mg/250 mL = 32 mcg/mL y 16 mg/250 mL = 64 mcg/mL. Confirmar siempre la presentación y concentración reales antes de programar la bomba.',
      'En la presentación premezclada Baxter/DailyMed 2026 citada en esta base, el producto está listo para administrar y no requiere dilución adicional antes de la infusión.',
      'En la ficha Baxter/DailyMed 2026 citada en esta base, CONTRAINDICACIONES listadas: ninguna. La hiperglucemia no es una contraindicación absoluta listada; corregir la hipovolemia antes del tratamiento es una instrucción/precaución de administración, no una contraindicación absoluta de la ficha.',
      'Las concentraciones preparadas institucionalmente pueden diferir; no tratar una única dilución como estándar universal sin conocer producto y protocolo local.',
      'La extravasación puede causar isquemia/necrosis; monitorizar el sitio y tratar inmediatamente según protocolo si ocurre.',
    ],
    sourceIds: <String>['SSC_2026', 'DAILYMED_NOREPINEPHRINE_2026'],
  ),
];
