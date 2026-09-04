class GlobalScoresBatch01Contract {
  static const String marker = '[GLOBAL_SCORES_BATCH01_P0_EXPLAINABILITY_V1]';

  static String build({required String lang, required String context}) {
    final topic = _topicFor(context);
    if (topic == null) return '';

    final isEs = lang.toLowerCase().startsWith('es');
    final specific = isEs ? _es[topic] : _pt[topic];
    if (specific == null) return '';

    return '${isEs ? _baseEs : _basePt}\n$specific\n';
  }

  static String? topicForTesting(String context) => _topicFor(context);

  static String? _topicFor(String input) {
    final value = ' ${_fold(input).trim()} ';

    bool hasAny(List<String> terms) => terms.any(value.contains);

    if (hasAny(const <String>[
      ' sepsis neonatal ',
      ' sepse neonatal ',
      ' infeccao neonatal ',
      ' neonatal sepsis ',
      ' neonatal infection ',
      ' early onset sepsis ',
      ' neonatal infection nice 2026 ',
    ])) {
      return 'neonatal_sepsis';
    }

    if (hasAny(const <String>[
      ' cetoacidose diabetica ',
      ' cetoacidosis diabetica ',
      ' diabetic ketoacidosis ',
      ' hyperglycemic crisis ',
      ' dka ',
    ])) {
      return 'dka';
    }

    if (hasAny(const <String>[
      ' hemorragia intracerebral ',
      ' intracerebral hemorrhage ',
      ' intracerebral haemorrhage ',
      ' avc hemorragico ',
      ' acv hemorragico ',
    ])) {
      return 'ich';
    }

    if (hasAny(const <String>[
      ' avc isquemico ',
      ' acv isquemico ',
      ' ictus isquemico ',
      ' ischemic stroke ',
      ' ischaemic stroke ',
      ' acute ischemic stroke ',
    ])) {
      return 'ais';
    }

    if (hasAny(const <String>[
      ' status epilepticus ',
      ' estado de mal epileptico ',
      ' estatus epileptico ',
    ])) {
      return 'status';
    }

    if (hasAny(const <String>[
      ' purpura trombocitopenica trombotica ',
      ' thrombotic thrombocytopenic purpura ',
      ' ptt ',
      ' ttp ',
    ])) {
      return 'ttp';
    }

    if (hasAny(const <String>[
      ' sindrome do desconforto respiratorio agudo ',
      ' sindrome de dificultad respiratoria aguda ',
      ' acute respiratory distress syndrome ',
      ' sdra ',
      ' ards ',
    ])) {
      return 'ards';
    }

    if (hasAny(const <String>[
      ' pre eclampsia ',
      ' preeclampsia ',
      ' pre-eclampsia ',
    ])) {
      return 'preeclampsia';
    }

    if (hasAny(const <String>[
      ' coagulacao intravascular disseminada ',
      ' coagulacion intravascular diseminada ',
      ' disseminated intravascular coagulation ',
      ' civd ',
      ' cid ',
      ' dic ',
    ])) {
      return 'dic';
    }

    if (hasAny(const <String>[
      ' septic shock ',
      ' choque septico ',
      ' shock septico ',
      ' sepsis ',
      ' sepse ',
    ])) {
      return 'sepsis';
    }

    // GLOBAL_SCORES_2026_BATCH02_P1
    // Specific secondary-hypertension and pulmonary terms must precede
    // generic systemic hypertension to avoid cross-topic contamination.
    if (hasAny(const <String>[
      ' hipertensao pulmonar ',
      ' hipertension pulmonar ',
      ' pulmonary hypertension ',
    ])) {
      return 'pulmonary_hypertension';
    }

    if (hasAny(const <String>[
      ' hiperaldosteronismo primario ',
      ' hiperaldosteronismo primario ',
      ' primary aldosteronism ',
      ' primary hyperaldosteronism ',
    ])) {
      return 'primary_aldosteronism';
    }

    if (hasAny(const <String>[
      ' feocromocitoma ',
      ' pheochromocytoma ',
      ' paraganglioma ',
      ' ppgl ',
    ])) {
      return 'ppgl';
    }

    if (hasAny(const <String>[
      ' sindrome de cushing ',
      ' cushing syndrome ',
      ' cushing s syndrome ',
      ' hipercortisolismo ',
      ' hypercortisolism ',
    ])) {
      return 'cushing';
    }

    if (hasAny(const <String>[
      ' disseccao aortica ',
      ' diseccion aortica ',
      ' aortic dissection ',
    ])) {
      return 'aortic_dissection';
    }

    if (hasAny(const <String>[
      ' cirrose e hipertensao portal ',
      ' cirrosis e hipertension portal ',
      ' cirrosis y hipertension portal ',
      ' cirrhosis and portal hypertension ',
      ' cirrose ',
      ' cirrosis ',
      ' cirrhosis ',
    ])) {
      return 'cirrhosis_portal';
    }

    if (hasAny(const <String>[' osteoporose ', ' osteoporosis '])) {
      return 'osteoporosis';
    }

    if (hasAny(const <String>[
      ' dpoc ',
      ' epoc ',
      ' copd ',
      ' chronic obstructive pulmonary disease ',
      ' doenca pulmonar obstrutiva cronica ',
      ' enfermedad pulmonar obstructiva cronica ',
    ])) {
      return 'copd';
    }

    if (hasAny(const <String>[' asma ', ' asthma '])) {
      return 'asthma';
    }

    if (hasAny(const <String>[
      ' hipertensao arterial ',
      ' hipertension arterial ',
      ' systemic hypertension ',
      ' systemic arterial hypertension ',
      ' high blood pressure ',
    ])) {
      return 'hypertension';
    }

    return null;
  }

  static String _fold(String value) => value
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('à', 'a')
      .replaceAll('â', 'a')
      .replaceAll('ã', 'a')
      .replaceAll('ä', 'a')
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('ë', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ì', 'i')
      .replaceAll('î', 'i')
      .replaceAll('ï', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ò', 'o')
      .replaceAll('ô', 'o')
      .replaceAll('õ', 'o')
      .replaceAll('ö', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ù', 'u')
      .replaceAll('û', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ç', 'c')
      .replaceAll('ñ', 'n')
      .replaceAll('_', ' ')
      .replaceAll('-', ' ');

  static const String _baseEs =
      '$marker\n'
      'CONTRATO DE EXPLICABILIDAD DE SCORE/CLASIFICACION:\n'
      'RESULTADO: clasificar primero al paciente actual.\n'
      'SIGNIFICADO: explicar que significa la categoria o puntuacion.\n'
      'POR QUE ESTE PACIENTE: usar solo datos concretos presentes en el caso.\n'
      'SISTEMA: escribir nombre completo y finalidad exacta: diagnostico, probabilidad pretest, gravedad, pronostico, tratamiento o disposicion.\n'
      'ORIGEN / ESTADO ACTUAL: separar origen historico de la guia vigente; nunca convertir el ano de la guia en el ano de una clasificacion antigua.\n'
      'IMPLICACION CLINICA / LIMITACIONES: indicar que cambia y que no puede concluirse.\n'
      'DATOS FALTANTES: si faltan variables obligatorias, NO calcular ni inferir; decir que no puede determinarse con seguridad y enumerar las variables faltantes.\n'
      'NO mezclar diagnostico, probabilidad pretest, gravedad, pronostico, decision terapeutica y disposicion.\n'
      'Este bloque CURRENT prevalece sobre texto historico conflictivo del mismo tema en el contexto local.\n';

  static const String _basePt =
      '$marker\n'
      'CONTRATO DE EXPLICABILIDADE DE SCORE/CLASSIFICACAO:\n'
      'RESULTADO: classificar primeiro o paciente atual.\n'
      'SIGNIFICADO: explicar o que significa a categoria ou pontuacao.\n'
      'POR QUE ESTE PACIENTE: usar apenas dados concretos presentes no caso.\n'
      'SISTEMA: escrever nome completo e finalidade exata: diagnostico, probabilidade pre-teste, gravidade, prognostico, tratamento ou disposicao.\n'
      'ORIGEM / ESTADO ATUAL: separar origem historica da diretriz vigente; nunca transformar o ano da diretriz no ano de uma classificacao antiga.\n'
      'IMPLICACAO CLINICA / LIMITACOES: indicar o que muda e o que nao pode ser concluido.\n'
      'DADOS FALTANTES: se faltarem variaveis obrigatorias, NAO calcular nem inferir; dizer que nao pode ser determinado com seguranca e enumerar as variaveis faltantes.\n'
      'NAO misturar diagnostico, probabilidade pre-teste, gravidade, prognostico, decisao terapeutica e disposicao.\n'
      'Este bloco CURRENT prevalece sobre texto historico conflitante do mesmo tema no contexto local.\n';

  static const Map<String, String> _es = <String, String>{
    'dka':
        '[GS26B01_DKA_CURRENT]\n'
        'SISTEMA/CURRENT_STATUS: consenso ADA/EASD/JBDS/AACE/DTS 2024 — ACTIVE_WITH_MODIFICATIONS.\n'
        'Diagnostico D-K-A exige los tres componentes: diabetes previa O glucosa >=200 mg/dL; cetosis, preferir beta-hidroxibutirato >=3,0 mmol/L; y acidosis pH <7,30 y/o bicarbonato <18 mmol/L. La brecha anionica no es criterio primario cuando hay medicion de cetonas.\n'
        'Gravedad: leve = beta-hidroxibutirato 3–6, pH >7,25 a <7,30 o HCO3 15–18, alerta; moderada = 3–6, pH 7,0–7,25 o HCO3 10–<15, alerta/somnoliento; grave = >6, pH <7,0 o HCO3 <10, estupor/coma. Nivel sugerido: sala/observacion, intermedio, UCI; la disposicion final es clinica.\n'
        'No inferir diagnostico o gravedad si faltan historia de diabetes/glucosa, cetonas/beta-hidroxibutirato y pH/bicarbonato.\n'
        'FUENTE: https://diabetesjournals.org/care/article/47/8/1257/156808/Hyperglycemic-Crises-in-Adults-With-Diabetes-A',
    'ais':
        '[GS26B01_AIS_CURRENT]\n'
        'SISTEMAS/CURRENT_STATUS: NIHSS, ASPECTS/PC-ASPECTS y mRS siguen activos en la guia AHA/ASA 2026.\n'
        'NIHSS cuantifica deficit neurologico/gravedad; ASPECTS/PC-ASPECTS cuantifican cambio isquemico por imagen y apoyan seleccion de reperfusion; mRS describe discapacidad funcional. Ninguno confirma el diagnostico de ACV isquemico por si solo.\n'
        'No calcular NIHSS sin sus items ni ASPECTS sin imagen/territorio correspondiente.\n'
        'FUENTE: https://www.ahajournals.org/doi/10.1161/STR.0000000000000513',
    'sepsis':
        '[GS26B01_SEPSIS_CURRENT]\n'
        'SISTEMA/CURRENT_STATUS: Sepsis-3/SOFA permanece marco diagnostico contemporaneo; SSC 2026 modifica la politica de screening.\n'
        'Sepsis: infeccion sospechada/confirmada con disfuncion organica aguda representada por aumento SOFA >=2. Shock septico: vasopresor para mantener PAM >=65 mmHg y lactato >2 mmol/L pese a reanimacion adecuada.\n'
        'qSOFA NO diagnostica sepsis. SSC 2026 recomienda NEWS/NEWS2, MEWS o SIRS sobre qSOFA como herramienta unica de cribado hospitalario. No confirmar ni excluir sepsis por un score aislado.\n'
        'FUENTE: https://sccm.org/clinical-resources/guidelines/guidelines/surviving-sepsis-campaign-international-guidelines-for-management-of-sepsis-and-septic-shock-2026',
    'status':
        '[GS26B01_STATUS_CURRENT]\n'
        'SISTEMA/ORIGEN/CURRENT_STATUS: definicion y clasificacion ILAE 2015 — HISTORIC_BUT_STILL_USED.\n'
        'Para status tonico-clonico convulsivo: t1=5 min y t2=30 min. Clasificar por semiologia, etiologia, correlato EEG y edad.\n'
        'STESS/EMSE, si se usan, son pronosticos: NO diagnostican status ni justifican por si solos limitar tratamiento. No inferir refractariedad, etiologia o eje EEG sin datos.\n'
        'FUENTE: https://www.ilae.org/guidelines/definition-and-classification/status-epilepticus-2015',
    'ttp':
        '[GS26B01_TTP_CURRENT]\n'
        'SISTEMA/CURRENT_STATUS: estrategia diagnostica ISTH — ACTIVE.\n'
        'PLASMIC y French score estiman probabilidad pretest de deficiencia grave de ADAMTS13; NO confirman TTP. Obtener ADAMTS13 antes de plasma/TPE cuando sea posible sin retrasar tratamiento urgente.\n'
        'ADAMTS13 <10% apoya fuertemente iTTP; >20% orienta a diagnostico alternativo; 10–20% es zona equivoca dependiente del contexto.\n'
        'FUENTE: https://www.jthjournal.org/article/S1538-7836%2822%2901178-3/fulltext',
    'ards':
        '[GS26B01_ARDS_CURRENT]\n'
        'SISTEMA/CURRENT_STATUS: Global Definition of ARDS 2024 — ACTIVE_WITH_MODIFICATIONS; Berlin 2012 = HISTORIC_BUT_STILL_USED.\n'
        'La definicion global amplia Berlin e incorpora soporte no invasivo/HFNO en condiciones definidas, relacion SpO2/FiO2 en contexto apropiado y ecografia como modalidad de imagen aceptada.\n'
        'En ARDS intubado, gravedad por PaO2/FiO2: leve >200–300, moderado >100–200, grave <=100 mmHg bajo las condiciones definidas. No inferir P/F o S/F sin FiO2 y oxigenacion validas.\n'
        'FUENTE: https://doi.org/10.1164/rccm.202303-0558WS',
    'preeclampsia':
        '[GS26B01_PREECLAMPSIA_CURRENT]\n'
        'DIVERGENCIA/CURRENT_STATUS: ACOG usa “preeclampsia with severe features”; ISSHP 2021 recomienda que la preeclampsia NO se clasifique como mild/severe durante un embarazo en curso. Nombrar siempre la sociedad; no universalizar la nomenclatura ACOG.\n'
        'ACOG severe features incluyen PA >=160 sistolica o >=110 diastolica, plaquetas <100.000, insuficiencia renal, disfuncion hepatica, edema pulmonar o sintomas neurologicos/visuales compatibles. No inferir severe features si faltan esas variables.\n'
        'FUENTES: https://www.acog.org/clinical/clinical-guidance/practice-bulletin/articles/2020/06/gestational-hypertension-and-preeclampsia | https://isshp.org/wp-content/uploads/2023/09/ISSHP-2021-guidelines.pdf',
    'neonatal_sepsis':
        '[GS26B01_NEONATAL_SEPSIS_CURRENT]\n'
        'SISTEMA/CURRENT_STATUS: WHO 0–59 dias serious bacterial infection 2024/2025 — ACTIVE.\n'
        'No existe un score universal de sepsis neonatal aplicable a todo recien nacido. La clasificacion WHO se basa en la evaluacion clinica de infeccion bacteriana grave; el EOS calculator solo es valido en poblacion/escenario elegibles y no debe extrapolarse a prematuros fuera de criterio, late-onset o toda sepsis neonatal.\n'
        'No inventar categoria sin edad posnatal, edad gestacional, momento de inicio y variables clinicas requeridas por el sistema elegido.\n'
        'FUENTE: https://www.who.int/publications/i/item/9789240102903',
    'ich':
        '[GS26B01_ICH_CURRENT]\n'
        'SISTEMA/ORIGEN/CURRENT_STATUS: ICH Score, escala pronostica historica aun usada; AHA/ASA 2022 mantiene el safeguard contemporaneo.\n'
        'ICH Score integra GCS, edad >=80, volumen >=30 mL, localizacion infratentorial y hemorragia intraventricular. Es gravedad/pronostico, NO diagnostico etiologico.\n'
        'Una escala basal NO debe ser la unica base para limitar tratamientos de soporte vital. No calcular si faltan componentes.\n'
        'FUENTE: https://www.ahajournals.org/doi/10.1161/STR.0000000000000407',
    'dic':
        '[GS26B01_DIC_CURRENT]\n'
        'SISTEMA/CURRENT_STATUS: ISTH SSC overt DIC 2025 — ACTIVE_WITH_MODIFICATIONS.\n'
        'Overt DIC: plaquetas <50=2; 50–<100=1; D-dimero >7x ULN=3; >3x ULN=2; prolongacion de PT >=6 s=2; >=3–<6 s=1; fibrinogeno <100 mg/dL=1; total >=5.\n'
        'SIC: plaquetas + PT-INR + SOFA; total >=4 y suma plaquetas+PT-INR >2. Para early-phase DIC no aplicar criterio universal: adaptar a la etiologia.\n'
        'FUENTE: https://www.jthjournal.org/article/S1538-7836%2825%2900220-X/fulltext',

    'asthma':
        '[GS26B02_ASTHMA_CURRENT]\n'
        'SISTEMA/CURRENT_STATUS: GINA 2026 — ACTIVE_WITH_MODIFICATIONS. Control de sintomas y riesgo futuro son dominios distintos; control NO equivale a gravedad.\n'
        'Control en las ultimas 4 semanas: preguntar sintomas diurnos >2/semana, despertares nocturnos por asma, uso de SABA de rescate >2/semana y limitacion de actividad. 0 criterios = bien controlada; 1–2 = parcialmente controlada; 3–4 = no controlada. El criterio >2/semana se aplica a SABA, no debe trasladarse automaticamente a un reliever antiinflamatorio ICS-formoterol.\n'
        'Asma dificil de tratar = no controlada pese a ICS dosis media/alta + segundo controlador o que requiere dosis alta para mantener control. Asma grave = subconjunto retrospectivo, no controlada pese a buena adherencia a tratamiento optimizado con ICS-LABA dosis alta y manejo de factores contribuyentes, o empeora al reducirlo. GINA 2026 sugiere evitar si es posible el rotulo “asma leve” en practica clinica.\n'
        'No inferir nivel de control si faltan los cuatro dominios o no se conoce el tipo de reliever.\n'
        'FUENTE: https://ginasthma.org/2026-gina-strategy-report/',
    'copd':
        '[GS26B02_COPD_CURRENT]\n'
        'SISTEMAS/CURRENT_STATUS: GOLD 2026 — ACTIVE_WITH_MODIFICATIONS. Diagnostico, grado espirometrico y grupo ABE son ejes diferentes.\n'
        'Confirmacion espirometrica en contexto clinico compatible: FEV1/FVC post-broncodilatador <0,70. Solo en COPD confirmado, grado de limitacion: GOLD 1 FEV1 >=80%; GOLD 2 50–<80%; GOLD 3 30–<50%; GOLD 4 <30% del predicho.\n'
        'ABE 2026: cualquier >=1 exacerbacion moderada o grave en los 12 meses previos = Grupo E, independientemente de sintomas. Si no hubo exacerbacion moderada/grave: Grupo A si CAAT (antes CAT) <10 Y mMRC <2; Grupo B si CAAT >=10 O mMRC >=2. ABE no sustituye el grado GOLD 1–4.\n'
        'No asignar ABE sin historia de exacerbaciones y evaluacion de sintomas; no asignar GOLD 1–4 sin FEV1 post-BD en COPD confirmado.\n'
        'FUENTE: https://goldcopd.org/2026-gold-report-and-pocket-guide/',
    'hypertension':
        '[GS26B02_HTN_CURRENT]\n'
        'DIVERGENCIA/CURRENT_STATUS: ACC/AHA 2025 y ESC 2024 usan umbrales diferentes; siempre nombrar la sociedad. No existe una unica etiqueta universal para 130–139/80–89 mmHg.\n'
        'ACC/AHA 2025: normal <120 y <80; elevada 120–129 y <80; HTA estadio 1 = 130–139 O 80–89; estadio 2 = >=140 O >=90 mmHg.\n'
        'ESC 2024: PA no elevada <120/70; PA elevada 120–139 sistolica O 70–89 diastolica; hipertension de consultorio >=140/90 mmHg. Para PA 120–139/70–89 se estratifica riesgo cardiovascular para decisiones terapeuticas.\n'
        'PA >180/120 sin dano agudo de organo diana = hipertension grave, NO “emergencia hipertensiva” por el numero aislado. Emergencia exige dano agudo de organo diana. ACC/AHA 2025 usa PREVENT-CVD para decisiones de tratamiento en ciertos pacientes; no inferir riesgo sin variables del modelo.\n'
        'FUENTES: https://professional.heart.org/en/science-news/2025-high-blood-pressure-guideline/top-things-to-know | https://academic.oup.com/eurheartj/article/45/38/3912/7741010',
    'aortic_dissection':
        '[GS26B02_AORTA_CURRENT]\n'
        'SISTEMAS/CURRENT_STATUS: Stanford y DeBakey = HISTORIC_BUT_STILL_USED; SVS/STS temporal y TEM son marcos contemporaneos; EACTS/STS 2024 recomienda considerar TEM en sindrome aortico agudo.\n'
        'Stanford A = cualquier compromiso de aorta ascendente; B = sin compromiso ascendente. DeBakey I = desgarro en ascendente con propagacion al arco/descendente; II = confinado a ascendente; III = origen en descendente, IIIa solo toracica, IIIb se extiende bajo el diafragma.\n'
        'SVS/STS chronicity: hiperaguda <24 h; aguda 1–14 dias; subaguda 15–90 dias; cronica >90 dias desde inicio de sintomas.\n'
        'TEM: T=A/B/non-A non-B; E0 sin entry visible, E1 ascendente, E2 arco, E3 descendente; M0 sin malperfusion, M1 coronaria, M2 supra-aortica, M3 espinal/visceral/renal/iliaca, con (-)/(+) segun ausencia/presencia de sintomas clinicos. GERAADA es pronostico de mortalidad a 30 dias en cirugia de diseccion aguda tipo A, NO diagnostico.\n'
        'FUENTES: https://academic.oup.com/ejcts/article/65/2/ezad426/7614462 | https://pmc.ncbi.nlm.nih.gov/articles/PMC9876736/',
    'cirrhosis_portal':
        '[GS26B02_CIRRHOSIS_CURRENT]\n'
        'SISTEMAS/CURRENT_STATUS: Child-Turcotte-Pugh (CTP) = HISTORIC_BUT_STILL_USED para reserva/severidad; OPTN MELD 3.0 = ACTIVE para prioridad de trasplante en su contexto; Baveno VII = ACTIVE para cACLD/CSPH.\n'
        'CTP: 5–6=A, 7–9=B, 10–15=C. Puntua 1/2/3: bilirrubina <2 / 2–3 / >3 mg/dL; albumina >3,5 / 2,8–3,5 / <2,8 g/dL; INR <1,7 / 1,7–2,3 / >2,3; ascitis ninguna / leve-controlada / moderada-grave-refractaria; encefalopatia ninguna / grado I–II / grado III–IV. No calcular si falta un componente.\n'
        'OPTN MELD 3.0 adulto usa bilirrubina, INR, creatinina, sodio, albumina y sexo con formula/caps especificos; MELD-Na fue reemplazado para asignacion OPTN, pero no debe declararse obsoleto en todo contexto mundial.\n'
        'Baveno VII CSPH en cACLD: LSM <=15 kPa + plaquetas >=150x10^9/L descarta CSPH; LSM >=25 kPa confirma CSPH en etiologias validadas (viral/alcohol y NASH no obeso), con cautela fuera de ellas. LSM 20–25 + plaquetas <150 o LSM 15–20 + plaquetas <110 implica riesgo >=60% en el contexto ANTICIPATE validado.\n'
        'FUENTES: https://www.hcvguidelines.org/resource-library/ | https://pmc.ncbi.nlm.nih.gov/articles/PMC11090185/ | https://www.hrsa.gov/sites/default/files/hrsa/optn/optn_policies.pdf',
    'cushing':
        '[GS26B02_CUSHING_CURRENT]\n'
        'SISTEMA/CURRENT_STATUS: Endocrine Society 2008 — HISTORIC_BUT_STILL_USED como guideline diagnostico oficial; no existe un score universal de gravedad de sindrome de Cushing.\n'
        'Primero excluir exposicion exogena a glucocorticoides. Testing inicial con una prueba de alta precision: UFC al menos 2 mediciones, cortisol salival nocturno 2 mediciones, DST 1 mg overnight o DST baja dosis 2 mg/48 h. Tras DST 1 mg, cortisol serico >1,8 mcg/dL (50 nmol/L) sugiere Cushing; UFC y salival dependen del rango/ensayo.\n'
        'Un resultado anormal requiere otra prueba recomendada; dos pruebas concordantemente positivas llevan a estudio etiologico; dos negativas suelen detener estudio salvo sospecha ciclica/alta probabilidad. Cortisol serico aleatorio o ACTH aleatoria NO son pruebas de screening.\n'
        'Clasificacion etiologica: exogeno vs endogeno; endogeno ACTH-dependiente vs ACTH-independiente. No inferir etiologia antes de confirmar hipercortisolismo endogeno.\n'
        'FUENTE: https://www.endocrine.org/clinical-practice-guidelines/diagnosis-of-cushing-syndrome',
    'primary_aldosteronism':
        '[GS26B02_PA_CURRENT]\n'
        'SISTEMA/CURRENT_STATUS: Endocrine Society 2025 — ACTIVE_WITH_MODIFICATIONS. Sugiere screening de PA en todas las personas con hipertension, recomendacion condicional dependiente de recursos/contexto.\n'
        'Screening = aldosterona + renina (actividad o concentracion) y ARR; potasio se mide para interpretar, no es requisito de screening. Orientacion habitual: PRA <=1 ng/mL/h o DRC <=8,2 mU/L Y aldosterona >=10 ng/dL por inmunoensayo o >=7,5 ng/dL por LC-MS/MS; ARR >20 con aldosterona ng/dL/PRA o >70 con aldosterona pmol/L/DRC por inmunoensayo. Los cutoffs son dependientes de ensayo, unidades, medicacion y probabilidad pretest: NO son diagnostico absoluto.\n'
        'Si se busca cirugia, el testing de supresion se reserva sobre todo para probabilidad intermedia de PA lateralizante; CT + muestreo venoso adrenal (AVS) se usa para lateralizacion cuando corresponde. Clasificar lateralizante/unilateral vs bilateral solo con evaluacion apropiada; no inferir por CT aislada.\n'
        'FUENTE: https://www.endocrine.org/clinical-practice-guidelines/primary-aldosteronism-2',
    'ppgl':
        '[GS26B02_PPGL_CURRENT]\n'
        'SISTEMAS/CURRENT_STATUS: Endocrine Society recomienda metanefrinas plasmaticas libres o metanefrinas urinarias fraccionadas para evaluacion bioquimica inicial; WHO 2022 abandono la dicotomia simple benigno/maligno porque todo PPGL tiene potencial metastasico.\n'
        'Metastasis se diagnostica por tumor en tejidos no cromafines (p. ej. hueso, pulmon, higado, ganglios), no por un PASS/GAPP alto aislado. PASS, GAPP/COPPS pueden apoyar estimacion de riesgo pero tienen LIMITED_USE y no son clasificadores definitivos de malignidad.\n'
        'Evaluar riesgo con contexto clinico, localizacion/tamano, histopatologia y genetica (incluido SDHB cuando corresponda). No materializar “feocromocitoma benigno” como certeza actual ni llamar metastasico a un tumor solo por score histologico.\n'
        'FUENTES: https://academic.oup.com/jcem/article/99/6/1915/2537399 | https://pmc.ncbi.nlm.nih.gov/articles/PMC12819074/',
    'osteoporosis':
        '[GS26B02_OSTEOPOROSIS_CURRENT]\n'
        'SISTEMAS/CURRENT_STATUS: T-score WHO/IOF = definicion densitometrica HISTORIC_BUT_STILL_USED; FRAX = ACTIVE para probabilidad de fractura; NOGG 2024 usa estratos bajo/intermedio/alto/muy alto en su marco nacional.\n'
        'T-score: normal >=-1; osteopenia entre -1 y -2,5; osteoporosis <=-2,5; “osteoporosis severa/establecida” clasica = <=-2,5 + al menos una fractura por fragilidad. El umbral diagnostico NO es automaticamente umbral de tratamiento.\n'
        'FRAX estima riesgo a 10 anos de fractura osteoporotica mayor y de cadera. Los modelos y umbrales de intervencion son pais-especificos: NO copiar umbral de Reino Unido/EE.UU. a Argentina, Brasil u otro pais.\n'
        'NOGG 2024: muy alto riesgo puede incluir fractura vertebral reciente <2 anos, >=2 fracturas vertebrales, T-score <=-3,5, glucocorticoide >=7,5 mg/dia prednisolona equivalente durante >=3 meses, multiples factores o fractura reciente. Sus umbrales numericos FRAX son del Reino Unido.\n'
        'FUENTES: https://www.osteoporosis.foundation/health-professionals/diagnosis | https://www.nogg.org.uk/full-guideline/summary-main-recommendations | https://www.osteoporosis.foundation/health-professionals/diagnosis/other-diagnostic-tools',
    'pulmonary_hypertension':
        '[GS26B02_PH_CURRENT]\n'
        'SISTEMAS/CURRENT_STATUS: ESC/ERS 2022, reafirmado por 7th World Symposium — ACTIVE. Hemodinamica por cateterismo derecho: PH mPAP >20 mmHg; precapilar = mPAP >20 + PAWP <=15 + PVR >2 WU; postcapilar aislada = mPAP >20 + PAWP >15 + PVR <=2; combinada = mPAP >20 + PAWP >15 + PVR >2. Exercise PH = pendiente mPAP/CO >3 mmHg/L/min.\n'
        'Clasificacion clinica mantiene 5 grupos etiologicos. WHO-FC I–IV describe limitacion funcional.\n'
        'IMPORTANTE: el modelo de riesgo de 3 estratos al diagnostico y 4 estratos en seguimiento es para PAH/HAP (grupo 1), NO para toda PH. Seguimiento 4 estratos: WHO-FC I/II=1, III=3, IV=4; 6MWD >440=1, 320–440=2, 165–319=3, <165=4; BNP <50/50–199/200–800/>800 o NT-proBNP <300/300–649/650–1100/>1100 = 1/2/3/4. Preferir al menos las 3 variables; si faltan, no inventarlas y declarar la limitacion.\n'
        'FUENTE: https://publications.ersnet.org/content/erj/61/1/2200879',
  };

  static const Map<String, String> _pt = <String, String>{
    'dka':
        '[GS26B01_DKA_CURRENT]\n'
        'SISTEMA/CURRENT_STATUS: consenso ADA/EASD/JBDS/AACE/DTS 2024 — ACTIVE_WITH_MODIFICATIONS.\n'
        'Diagnostico D-K-A exige os tres componentes: diabetes previa OU glicose >=200 mg/dL; cetose, preferir beta-hidroxibutirato >=3,0 mmol/L; e acidose pH <7,30 e/ou bicarbonato <18 mmol/L. Anion gap nao e criterio primario quando ha medida de cetonas.\n'
        'Gravidade: leve = beta-hidroxibutirato 3–6, pH >7,25 a <7,30 ou HCO3 15–18, alerta; moderada = 3–6, pH 7,0–7,25 ou HCO3 10–<15, alerta/sonolento; grave = >6, pH <7,0 ou HCO3 <10, estupor/coma. Nivel sugerido: enfermaria/observacao, intermediario, UTI; disposicao final e clinica.\n'
        'Nao inferir diagnostico ou gravidade se faltarem historia de diabetes/glicose, cetonas/beta-hidroxibutirato e pH/bicarbonato.\n'
        'FONTE: https://diabetesjournals.org/care/article/47/8/1257/156808/Hyperglycemic-Crises-in-Adults-With-Diabetes-A',
    'ais':
        '[GS26B01_AIS_CURRENT]\n'
        'SISTEMAS/CURRENT_STATUS: NIHSS, ASPECTS/PC-ASPECTS e mRS seguem ativos na diretriz AHA/ASA 2026.\n'
        'NIHSS quantifica deficit neurologico/gravidade; ASPECTS/PC-ASPECTS quantificam alteracao isquemica por imagem e apoiam selecao de reperfusao; mRS descreve incapacidade funcional. Nenhum confirma diagnostico de AVC isquemico isoladamente.\n'
        'Nao calcular NIHSS sem seus itens nem ASPECTS sem imagem/territorio correspondente.\n'
        'FONTE: https://www.ahajournals.org/doi/10.1161/STR.0000000000000513',
    'sepsis':
        '[GS26B01_SEPSIS_CURRENT]\n'
        'SISTEMA/CURRENT_STATUS: Sepsis-3/SOFA permanece marco diagnostico contemporaneo; SSC 2026 modifica a politica de screening.\n'
        'Sepse: infeccao suspeita/confirmada com disfuncao organica aguda representada por aumento SOFA >=2. Choque septico: vasopressor para manter PAM >=65 mmHg e lactato >2 mmol/L apesar de ressuscitacao adequada.\n'
        'qSOFA NAO diagnostica sepse. SSC 2026 recomenda NEWS/NEWS2, MEWS ou SIRS em vez de qSOFA como ferramenta unica de triagem hospitalar. Nao confirmar nem excluir sepse por score isolado.\n'
        'FONTE: https://sccm.org/clinical-resources/guidelines/guidelines/surviving-sepsis-campaign-international-guidelines-for-management-of-sepsis-and-septic-shock-2026',
    'status':
        '[GS26B01_STATUS_CURRENT]\n'
        'SISTEMA/ORIGEM/CURRENT_STATUS: definicao e classificacao ILAE 2015 — HISTORIC_BUT_STILL_USED.\n'
        'Para status tonico-clonico convulsivo: t1=5 min e t2=30 min. Classificar por semiologia, etiologia, correlato EEG e idade.\n'
        'STESS/EMSE, se usados, sao prognosticos: NAO diagnosticam status nem justificam isoladamente limitar tratamento. Nao inferir refratariedade, etiologia ou eixo EEG sem dados.\n'
        'FONTE: https://www.ilae.org/guidelines/definition-and-classification/status-epilepticus-2015',
    'ttp':
        '[GS26B01_TTP_CURRENT]\n'
        'SISTEMA/CURRENT_STATUS: estrategia diagnostica ISTH — ACTIVE.\n'
        'PLASMIC e French score estimam probabilidade pre-teste de deficiencia grave de ADAMTS13; NAO confirmam TTP. Colher ADAMTS13 antes de plasma/TPE quando possivel sem atrasar tratamento urgente.\n'
        'ADAMTS13 <10% apoia fortemente iTTP; >20% orienta diagnostico alternativo; 10–20% e zona equivoca dependente do contexto.\n'
        'FONTE: https://www.jthjournal.org/article/S1538-7836%2822%2901178-3/fulltext',
    'ards':
        '[GS26B01_ARDS_CURRENT]\n'
        'SISTEMA/CURRENT_STATUS: Global Definition of ARDS 2024 — ACTIVE_WITH_MODIFICATIONS; Berlin 2012 = HISTORIC_BUT_STILL_USED.\n'
        'A definicao global amplia Berlin e incorpora suporte nao invasivo/HFNO em condicoes definidas, relacao SpO2/FiO2 em contexto apropriado e ultrassom como modalidade de imagem aceita.\n'
        'Em ARDS intubada, gravidade por PaO2/FiO2: leve >200–300, moderada >100–200, grave <=100 mmHg sob as condicoes definidas. Nao inferir P/F ou S/F sem FiO2 e oxigenacao validas.\n'
        'FONTE: https://doi.org/10.1164/rccm.202303-0558WS',
    'preeclampsia':
        '[GS26B01_PREECLAMPSIA_CURRENT]\n'
        'DIVERGENCIA/CURRENT_STATUS: ACOG usa “preeclampsia with severe features”; ISSHP 2021 recomenda que pre-eclampsia NAO seja classificada como mild/severe em gestacao em curso. Nomear sempre a sociedade; nao universalizar a nomenclatura ACOG.\n'
        'ACOG severe features incluem PA >=160 sistolica ou >=110 diastolica, plaquetas <100.000, insuficiencia renal, disfuncao hepatica, edema pulmonar ou sintomas neurologicos/visuais compativeis. Nao inferir severe features se faltarem essas variaveis.\n'
        'FONTES: https://www.acog.org/clinical/clinical-guidance/practice-bulletin/articles/2020/06/gestational-hypertension-and-preeclampsia | https://isshp.org/wp-content/uploads/2023/09/ISSHP-2021-guidelines.pdf',
    'neonatal_sepsis':
        '[GS26B01_NEONATAL_SEPSIS_CURRENT]\n'
        'SISTEMA/CURRENT_STATUS: WHO 0–59 dias serious bacterial infection 2024/2025 — ACTIVE.\n'
        'Nao existe score universal de sepse neonatal aplicavel a todo recem-nascido. A classificacao WHO parte da avaliacao clinica de infeccao bacteriana grave; EOS calculator so e valido em populacao/cenario elegiveis e nao deve ser extrapolado a prematuros fora do criterio, late-onset ou toda sepse neonatal.\n'
        'Nao inventar categoria sem idade pos-natal, idade gestacional, momento de inicio e variaveis clinicas exigidas pelo sistema escolhido.\n'
        'FONTE: https://www.who.int/publications/i/item/9789240102903',
    'ich':
        '[GS26B01_ICH_CURRENT]\n'
        'SISTEMA/ORIGEM/CURRENT_STATUS: ICH Score, escala prognostica historica ainda usada; AHA/ASA 2022 mantem o safeguard contemporaneo.\n'
        'ICH Score integra GCS, idade >=80, volume >=30 mL, localizacao infratentorial e hemorragia intraventricular. E gravidade/prognostico, NAO diagnostico etiologico.\n'
        'Uma escala basal NAO deve ser a unica base para limitar suporte de vida. Nao calcular se faltarem componentes.\n'
        'FONTE: https://www.ahajournals.org/doi/10.1161/STR.0000000000000407',
    'dic':
        '[GS26B01_DIC_CURRENT]\n'
        'SISTEMA/CURRENT_STATUS: ISTH SSC overt DIC 2025 — ACTIVE_WITH_MODIFICATIONS.\n'
        'Overt DIC: plaquetas <50=2; 50–<100=1; D-dimero >7x ULN=3; >3x ULN=2; prolongamento de PT >=6 s=2; >=3–<6 s=1; fibrinogenio <100 mg/dL=1; total >=5.\n'
        'SIC: plaquetas + PT-INR + SOFA; total >=4 e soma plaquetas+PT-INR >2. Para early-phase DIC nao aplicar criterio universal: adaptar a etiologia.\n'
        'FONTE: https://www.jthjournal.org/article/S1538-7836%2825%2900220-X/fulltext',

    'asthma':
        '[GS26B02_ASTHMA_CURRENT]\n'
        'SISTEMA/CURRENT_STATUS: GINA 2026 — ACTIVE_WITH_MODIFICATIONS. Controle de sintomas e risco futuro sao dominios distintos; controle NAO equivale a gravidade.\n'
        'Controle nas ultimas 4 semanas: perguntar sintomas diurnos >2/semana, despertar noturno por asma, uso de SABA de resgate >2/semana e limitacao de atividade. 0 criterios = bem controlada; 1–2 = parcialmente controlada; 3–4 = nao controlada. O criterio >2/semana se aplica a SABA, nao deve ser transferido automaticamente a um reliever anti-inflamatorio ICS-formoterol.\n'
        'Asma dificil de tratar = nao controlada apesar de ICS dose media/alta + segundo controlador ou que exige dose alta para manter controle. Asma grave = subconjunto retrospectivo, nao controlada apesar de boa adesao a tratamento otimizado com ICS-LABA dose alta e manejo de fatores contribuintes, ou piora ao reduzir. GINA 2026 sugere evitar se possivel o rotulo “asma leve” na pratica clinica.\n'
        'Nao inferir nivel de controle se faltarem os quatro dominios ou nao se souber o tipo de reliever.\n'
        'FONTE: https://ginasthma.org/2026-gina-strategy-report/',
    'copd':
        '[GS26B02_COPD_CURRENT]\n'
        'SISTEMAS/CURRENT_STATUS: GOLD 2026 — ACTIVE_WITH_MODIFICATIONS. Diagnostico, grau espirometrico e grupo ABE sao eixos diferentes.\n'
        'Confirmacao espirometrica em contexto clinico compativel: FEV1/FVC pos-broncodilatador <0,70. Apenas em DPOC confirmado, grau de limitacao: GOLD 1 FEV1 >=80%; GOLD 2 50–<80%; GOLD 3 30–<50%; GOLD 4 <30% do previsto.\n'
        'ABE 2026: qualquer >=1 exacerbacao moderada ou grave nos 12 meses previos = Grupo E, independentemente dos sintomas. Se nao houve exacerbacao moderada/grave: Grupo A se CAAT (antes CAT) <10 E mMRC <2; Grupo B se CAAT >=10 OU mMRC >=2. ABE nao substitui o grau GOLD 1–4.\n'
        'Nao atribuir ABE sem historia de exacerbacoes e avaliacao de sintomas; nao atribuir GOLD 1–4 sem FEV1 pos-BD em DPOC confirmado.\n'
        'FONTE: https://goldcopd.org/2026-gold-report-and-pocket-guide/',
    'hypertension':
        '[GS26B02_HTN_CURRENT]\n'
        'DIVERGENCIA/CURRENT_STATUS: ACC/AHA 2025 e ESC 2024 usam limiares diferentes; sempre nomear a sociedade. Nao existe uma unica etiqueta universal para 130–139/80–89 mmHg.\n'
        'ACC/AHA 2025: normal <120 e <80; elevada 120–129 e <80; HAS estagio 1 = 130–139 OU 80–89; estagio 2 = >=140 OU >=90 mmHg.\n'
        'ESC 2024: PA nao elevada <120/70; PA elevada 120–139 sistolica OU 70–89 diastolica; hipertensao de consultorio >=140/90 mmHg. Para PA 120–139/70–89, estratificar risco cardiovascular para decisoes terapeuticas.\n'
        'PA >180/120 sem lesao aguda de orgao-alvo = hipertensao grave, NAO “emergencia hipertensiva” pelo numero isolado. Emergencia exige lesao aguda de orgao-alvo. ACC/AHA 2025 usa PREVENT-CVD para decisoes de tratamento em certos pacientes; nao inferir risco sem variaveis do modelo.\n'
        'FONTES: https://professional.heart.org/en/science-news/2025-high-blood-pressure-guideline/top-things-to-know | https://academic.oup.com/eurheartj/article/45/38/3912/7741010',
    'aortic_dissection':
        '[GS26B02_AORTA_CURRENT]\n'
        'SISTEMAS/CURRENT_STATUS: Stanford e DeBakey = HISTORIC_BUT_STILL_USED; SVS/STS temporal e TEM sao marcos contemporaneos; EACTS/STS 2024 recomenda considerar TEM em sindrome aortica aguda.\n'
        'Stanford A = qualquer envolvimento de aorta ascendente; B = sem envolvimento ascendente. DeBakey I = tear na ascendente com propagacao ao arco/descendente; II = confinada a ascendente; III = origem na descendente, IIIa apenas toracica, IIIb estende abaixo do diafragma.\n'
        'SVS/STS chronicity: hiperaguda <24 h; aguda 1–14 dias; subaguda 15–90 dias; cronica >90 dias desde inicio dos sintomas.\n'
        'TEM: T=A/B/non-A non-B; E0 sem entry visivel, E1 ascendente, E2 arco, E3 descendente; M0 sem malperfusao, M1 coronaria, M2 supra-aortica, M3 espinal/visceral/renal/iliaca, com (-)/(+) conforme ausencia/presenca de sintomas clinicos. GERAADA e prognostico de mortalidade em 30 dias em cirurgia de disseccao aguda tipo A, NAO diagnostico.\n'
        'FONTES: https://academic.oup.com/ejcts/article/65/2/ezad426/7614462 | https://pmc.ncbi.nlm.nih.gov/articles/PMC9876736/',
    'cirrhosis_portal':
        '[GS26B02_CIRRHOSIS_CURRENT]\n'
        'SISTEMAS/CURRENT_STATUS: Child-Turcotte-Pugh (CTP) = HISTORIC_BUT_STILL_USED para reserva/gravidade; OPTN MELD 3.0 = ACTIVE para prioridade de transplante em seu contexto; Baveno VII = ACTIVE para cACLD/CSPH.\n'
        'CTP: 5–6=A, 7–9=B, 10–15=C. Pontua 1/2/3: bilirrubina <2 / 2–3 / >3 mg/dL; albumina >3,5 / 2,8–3,5 / <2,8 g/dL; INR <1,7 / 1,7–2,3 / >2,3; ascite nenhuma / leve-controlada / moderada-grave-refrataria; encefalopatia nenhuma / grau I–II / grau III–IV. Nao calcular se faltar componente.\n'
        'OPTN MELD 3.0 adulto usa bilirrubina, INR, creatinina, sodio, albumina e sexo com formula/caps especificos; MELD-Na foi substituido para alocacao OPTN, mas nao deve ser declarado obsoleto em todo contexto mundial.\n'
        'Baveno VII CSPH em cACLD: LSM <=15 kPa + plaquetas >=150x10^9/L exclui CSPH; LSM >=25 kPa confirma CSPH em etiologias validadas (viral/alcool e NASH nao obeso), com cautela fora delas. LSM 20–25 + plaquetas <150 ou LSM 15–20 + plaquetas <110 implica risco >=60% no contexto ANTICIPATE validado.\n'
        'FONTES: https://www.hcvguidelines.org/resource-library/ | https://pmc.ncbi.nlm.nih.gov/articles/PMC11090185/ | https://www.hrsa.gov/sites/default/files/hrsa/optn/optn_policies.pdf',
    'cushing':
        '[GS26B02_CUSHING_CURRENT]\n'
        'SISTEMA/CURRENT_STATUS: Endocrine Society 2008 — HISTORIC_BUT_STILL_USED como guideline diagnostico oficial; nao existe score universal de gravidade da sindrome de Cushing.\n'
        'Primeiro excluir exposicao exogena a glicocorticoides. Teste inicial com uma prova de alta precisao: UFC pelo menos 2 medidas, cortisol salivar noturno 2 medidas, DST 1 mg overnight ou DST baixa dose 2 mg/48 h. Apos DST 1 mg, cortisol serico >1,8 mcg/dL (50 nmol/L) sugere Cushing; UFC e salivar dependem do limite/ensaio.\n'
        'Um resultado anormal exige outra prova recomendada; duas provas concordantemente positivas levam a investigacao etiologica; duas negativas geralmente encerram investigacao, salvo suspeita ciclica/alta probabilidade. Cortisol serico aleatorio ou ACTH aleatorio NAO sao testes de screening.\n'
        'Classificacao etiologica: exogeno vs endogeno; endogeno ACTH-dependente vs ACTH-independente. Nao inferir etiologia antes de confirmar hipercortisolismo endogeno.\n'
        'FONTE: https://www.endocrine.org/clinical-practice-guidelines/diagnosis-of-cushing-syndrome',
    'primary_aldosteronism':
        '[GS26B02_PA_CURRENT]\n'
        'SISTEMA/CURRENT_STATUS: Endocrine Society 2025 — ACTIVE_WITH_MODIFICATIONS. Sugere screening de PA em todas as pessoas com hipertensao, recomendacao condicional dependente de recursos/contexto.\n'
        'Screening = aldosterona + renina (atividade ou concentracao) e ARR; potassio e medido para interpretar, nao e requisito de screening. Orientacao usual: PRA <=1 ng/mL/h ou DRC <=8,2 mU/L E aldosterona >=10 ng/dL por imunoensaio ou >=7,5 ng/dL por LC-MS/MS; ARR >20 com aldosterona ng/dL/PRA ou >70 com aldosterona pmol/L/DRC por imunoensaio. Os cutoffs dependem de ensaio, unidades, medicacoes e probabilidade pre-teste: NAO sao diagnostico absoluto.\n'
        'Se cirurgia estiver em consideracao, teste de supressao e usado sobretudo em probabilidade intermediaria de PA lateralizante; CT + amostragem venosa adrenal (AVS) e usada para lateralizacao quando indicado. Classificar lateralizante/unilateral vs bilateral apenas com avaliacao apropriada; nao inferir por CT isolada.\n'
        'FONTE: https://www.endocrine.org/clinical-practice-guidelines/primary-aldosteronism-2',
    'ppgl':
        '[GS26B02_PPGL_CURRENT]\n'
        'SISTEMAS/CURRENT_STATUS: Endocrine Society recomenda metanefrinas plasmaticas livres ou metanefrinas urinarias fracionadas para avaliacao bioquimica inicial; WHO 2022 abandonou a dicotomia simples benigno/maligno porque todo PPGL tem potencial metastatico.\n'
        'Metastase e diagnosticada por tumor em tecidos nao cromafins (p. ex. osso, pulmao, figado, linfonodos), nao por PASS/GAPP alto isolado. PASS, GAPP/COPPS podem apoiar estimativa de risco, mas tem LIMITED_USE e nao sao classificadores definitivos de malignidade.\n'
        'Avaliar risco com contexto clinico, localizacao/tamanho, histopatologia e genetica (incluindo SDHB quando apropriado). Nao materializar “feocromocitoma benigno” como certeza atual nem chamar metastatico apenas por score histologico.\n'
        'FONTES: https://academic.oup.com/jcem/article/99/6/1915/2537399 | https://pmc.ncbi.nlm.nih.gov/articles/PMC12819074/',
    'osteoporosis':
        '[GS26B02_OSTEOPOROSIS_CURRENT]\n'
        'SISTEMAS/CURRENT_STATUS: T-score WHO/IOF = definicao densitometrica HISTORIC_BUT_STILL_USED; FRAX = ACTIVE para probabilidade de fratura; NOGG 2024 usa estratos baixo/intermediario/alto/muito alto no seu marco nacional.\n'
        'T-score: normal >=-1; osteopenia entre -1 e -2,5; osteoporose <=-2,5; “osteoporose grave/estabelecida” classica = <=-2,5 + pelo menos uma fratura por fragilidade. O limiar diagnostico NAO e automaticamente limiar de tratamento.\n'
        'FRAX estima risco em 10 anos de fratura osteoporotica maior e de quadril. Modelos e limiares de intervencao sao especificos por pais: NAO copiar limiar do Reino Unido/EUA para Argentina, Brasil ou outro pais.\n'
        'NOGG 2024: muito alto risco pode incluir fratura vertebral recente <2 anos, >=2 fraturas vertebrais, T-score <=-3,5, glicocorticoide >=7,5 mg/dia prednisolona equivalente por >=3 meses, multiplos fatores ou fratura recente. Seus limiares numericos FRAX sao do Reino Unido.\n'
        'FONTES: https://www.osteoporosis.foundation/health-professionals/diagnosis | https://www.nogg.org.uk/full-guideline/summary-main-recommendations | https://www.osteoporosis.foundation/health-professionals/diagnosis/other-diagnostic-tools',
    'pulmonary_hypertension':
        '[GS26B02_PH_CURRENT]\n'
        'SISTEMAS/CURRENT_STATUS: ESC/ERS 2022, reafirmado pelo 7th World Symposium — ACTIVE. Hemodinamica por cateterismo direito: PH mPAP >20 mmHg; pre-capilar = mPAP >20 + PAWP <=15 + PVR >2 WU; pos-capilar isolada = mPAP >20 + PAWP >15 + PVR <=2; combinada = mPAP >20 + PAWP >15 + PVR >2. Exercise PH = inclinacao mPAP/CO >3 mmHg/L/min.\n'
        'Classificacao clinica mantem 5 grupos etiologicos. WHO-FC I–IV descreve limitacao funcional.\n'
        'IMPORTANTE: modelo de risco em 3 estratos no diagnostico e 4 estratos no seguimento e para PAH/HAP (grupo 1), NAO para toda PH. Seguimento 4 estratos: WHO-FC I/II=1, III=3, IV=4; 6MWD >440=1, 320–440=2, 165–319=3, <165=4; BNP <50/50–199/200–800/>800 ou NT-proBNP <300/300–649/650–1100/>1100 = 1/2/3/4. Preferir pelo menos as 3 variaveis; se faltarem, nao inventar e declarar limitacao.\n'
        'FONTE: https://publications.ersnet.org/content/erj/61/1/2200879',
  };
}
