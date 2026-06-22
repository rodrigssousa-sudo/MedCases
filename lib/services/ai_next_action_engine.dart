// ══════════════════════════════════════════════════════════════════════════════
// ai_next_action_engine.dart — Smart Next Action Engine v1  (Build 233)
//
// MOTOR 100% LOCAL — DETERMINÍSTICO — SEM IA — SEM REDE — SEM RAG
//
// Responsabilidade exclusiva:
//   • Detectar o tema clínico da conversa (lastUserMessage + lastAiResponse)
//   • Selecionar a continuação mais relevante daquele tema
//   • Retornar label + promptToSend prontos para uso imediato
//   • Respeitar modo (Plantão/Estudo) e idioma (PT-BR/ES) com rigor absoluto
//
// NÃO FAZ:
//   • Chamadas de rede, Gemini, Firestore, RAG, API externa
//   • Embeddings, WebViews, rotas externas
//   • Texto para pacientes (sempre fala como profissional → profissional)
//
// ARQUITETURA:
//   SmartNextAction   → DTO (label + promptToSend)
//   ClinicalTopic     → enum de 43 áreas clínicas
//   NextActionEngine  → motor estático de detecção + seleção
//
// IDIOMA:
//   Prioridade 1: currentLanguage ('pt' | 'es')
//   Prioridade 2: tokens do lastUserMessage
//   Prioridade 3: tokens do lastAiResponse
//   Prioridade 4: fallback PT-BR
//
// PROIBIÇÕES:
//   ✗ "Procure atendimento médico" / "Consulte um médico"
//   ✗ Texto voltado para pacientes leigos
//   ✗ Mistura de idiomas (portunhol)
// ══════════════════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────────────────────
// SmartNextAction — DTO de saída do motor
// ─────────────────────────────────────────────────────────────────────────────
class SmartNextAction {
  final String label;
  final String promptToSend;

  const SmartNextAction({
    required this.label,
    required this.promptToSend,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// ClinicalTopic — 43 grandes áreas clínicas detectáveis
// ─────────────────────────────────────────────────────────────────────────────
enum ClinicalTopic {
  sca,              //  1. Síndrome Coronariana
  sepse,            //  2. Sepse / Choque Séptico
  potassio,         //  3. Distúrbios do Potássio
  antidepressivos,  //  4. Antidepressivos (ISRS/IRSN)
  parkinson,        //  5. Parkinson
  anticoagulacao,   //  6. Anticoagulação
  arritmia,         //  7. Arritmias
  tep,              //  8. TEP / Embolia Pulmonar
  asma,             //  9. Asma
  pneumonia,        // 10. Pneumonia / NAC
  diabetes,         // 11. Diabetes / CAD / HHS
  renal,            // 12. Doença Renal / IRA / IRC
  avc,              // 13. AVC / Neurologia Vascular
  hipertensao,      // 14. Hipertensão
  ic,               // 15. Insuficiência Cardíaca
  dpoc,             // 16. DPOC / EPOC
  anafilaxia,       // 17. Anafilaxia
  convulsao,        // 18. Convulsão / Status Epiléptico
  meningite,        // 19. Meningite
  endocardite,      // 20. Endocardite
  hiponatremia,     // 21. Hiponatremia
  hipernatremia,    // 22. Hipernatremia
  acidose,          // 23. Acidose / Gasometria
  alcalose,         // 24. Alcalose
  choque,           // 25. Choque (geral)
  intubacao,        // 26. Intubação / Via Aérea
  ventilacao,       // 27. Ventilação Mecânica
  sedacao,          // 28. Sedação / Analgossedação
  analgesia,        // 29. Analgesia / Opioides
  antibioticos,     // 30. Antibióticos de amplo espectro
  obstetricia,      // 31. Obstetrícia / Pré-Eclâmpsia
  pediatria,        // 32. Pediatria / Neonatologia
  trauma,           // 33. Trauma / Politrauma
  queimadura,       // 34. Queimaduras
  toxicologia,      // 35. Toxicologia / Intoxicação
  psiquiatria,      // 36. Psiquiatria / Crise Psiquiátrica
  hematologia,      // 37. Hematologia / Coagulopatia
  gastro,           // 38. Gastroenterologia / Cirrose
  endocrino,        // 39. Endocrinologia / Tireoide
  infectologia,     // 40. Infectologia / HIV / TB
  hipercalemia,     // 41. Hipercalemia (separada de potássio)
  delirium,         // 42. Delirium / Confusão Mental
  nenhum,           // 43. Fallback — nenhum tema identificado
}

// ─────────────────────────────────────────────────────────────────────────────
// NextActionEngine — motor principal (100% local, sem rede, sem IA)
// ─────────────────────────────────────────────────────────────────────────────
class NextActionEngine {
  NextActionEngine._(); // utilitário 100% estático

  // ──────────────────────────────────────────────────────────────────────────
  // PONTO DE ENTRADA PÚBLICO
  // ──────────────────────────────────────────────────────────────────────────
  static SmartNextAction build({
    required String lastUserMessage,
    required String lastAiResponse,
    required bool isPlantaoMode,
    required String currentLanguage,
  }) {
    // 1. Resolver idioma
    final lang = _resolveLanguage(currentLanguage, lastUserMessage, lastAiResponse);

    // 2. Detectar tema clínico (user message tem prioridade sobre resposta)
    final corpus = '${lastUserMessage.toLowerCase()} ${lastAiResponse.toLowerCase()}';
    final topic = _detectTopic(corpus);

    // 3. Selecionar ação e montar SmartNextAction
    return _selectAction(topic: topic, isPlantaoMode: isPlantaoMode, lang: lang);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 1. RESOLUÇÃO DE IDIOMA
  // Prioridade: currentLanguage → tokens user msg → tokens AI resp → fallback PT
  // ──────────────────────────────────────────────────────────────────────────
  static String _resolveLanguage(String current, String userMsg, String aiResp) {
    // Prioridade 1: currentLanguage explícito
    if (current == 'pt' || current == 'es') return current;

    // Prioridade 2: tokens inequívocos na mensagem do usuário
    final userLower = userMsg.toLowerCase();
    final esScore2 = _esTokens.where((t) => userLower.contains(t)).length;
    final ptScore2 = _ptTokens.where((t) => userLower.contains(t)).length;
    if (esScore2 > ptScore2) return 'es';
    if (ptScore2 > esScore2) return 'pt';

    // Prioridade 3: tokens na resposta da IA
    final aiLower = aiResp.toLowerCase();
    final esScore3 = _esTokens.where((t) => aiLower.contains(t)).length;
    final ptScore3 = _ptTokens.where((t) => aiLower.contains(t)).length;
    if (esScore3 > ptScore3) return 'es';
    if (ptScore3 > esScore3) return 'pt';

    // Prioridade 4: fallback PT-BR
    return 'pt';
  }

  static const _esTokens = [
    '¿', '¡', 'dosis', 'tratamiento', 'ampolla', 'contraindicación',
    'embarazo', 'manejo', 'solución', 'dilución', 'administrar',
    ' el ', ' la ', ' los ', ' las ', 'qué', 'cómo', 'cuál',
    'paciente ', 'medicamento', 'infusión',
  ];

  static const _ptTokens = [
    'ção', 'ões', 'não', 'também', 'então', 'conduta', 'ampola',
    'tratamento', 'gestação', 'dilua', 'correr', 'prescrever',
    ' do ', ' da ', ' para ', 'medicamento', ' com ',
  ];

  // ──────────────────────────────────────────────────────────────────────────
  // 2. DETECÇÃO DE TEMA CLÍNICO
  // Usa corpus = lastUserMessage + lastAiResponse (lowercased)
  // Retorna o primeiro match de maior especificidade
  // ──────────────────────────────────────────────────────────────────────────
  static ClinicalTopic _detectTopic(String corpus) {
    // Verificar em ordem de especificidade (temas mais raros primeiro)
    //
    // Build 236 — Reordenamento anti-colisão léxica:
    // ISRS/IRSN e Parkinson sobem para o TOPO da função, antes de Sepse e Choque.
    // Isso impede que 'norepinefrina' (neurotransmissor em venlafaxina/duloxetina)
    // acione o bloco de vasopressores/sepse. Adicionalmente, 'noradrenalina' e
    // 'norepinefrina' foram removidos do bloco de Sepse; substituídos por tokens
    // exclusivamente septêmicos com contexto clínico ('noradrenalina iv',
    // 'vasopressor iv', etc.) — impossíveis de ocorrer em contexto psiquiátrico.

    // ★ PRIORIDADE 0-A: Antidepressivos / ISRS / IRSN
    // (DEVE vir antes de Sepse: 'norepinefrina' e 'noradrenalina' são usadas
    //  nesses textos como NEUROTRANSMISSORES, não vasopressores sistêmicos)
    if (_any(corpus, ['isrs', 'irsn', 'snri', 'ssri', 'fluoxetina',
        'sertralina', 'escitalopram', 'paroxetina', 'venlafaxina',
        'duloxetina', 'antidepressivo', 'antidepresivo', 'depressão',
        'depresión', 'síndrome serotoninérgica', 'sindrome serotonergico',
        'mirtazapina', 'desvenlafaxina', 'fluvoxamina'])) {
      return ClinicalTopic.antidepressivos;
    }

    // ★ PRIORIDADE 0-B: Parkinson
    // (DEVE vir antes de Sepse: 'dopaminergíco' pode aparecer em contextos
    //  de choque, mas levodopa/pramipexol são exclusivos de neurologia)
    if (_any(corpus, ['parkinson', 'levodopa', 'carbidopa', 'benserazida',
        'pramipexol', 'rotigotina', 'rasagilina', 'discinesia',
        'fenômeno on-off', 'fenomeno on-off', 'agonista dopaminérgico',
        'agonista dopaminergico'])) {
      return ClinicalTopic.parkinson;
    }

    // 41. Hipercalemia (antes de potássio genérico)
    if (_any(corpus, ['hipercalemia', 'hipercalcemia', 'k+ 6', 'k+ 7',
        'k+6', 'k+7', 'potássio alto', 'potasio alto', 'k elevado'])) {
      return ClinicalTopic.hipercalemia;
    }

    // 1. SCA / IAM
    // NOTA: 'iam' → ' iam' (evita match em "estadiamento", "exame")
    // NOTA: 'sca' → ' sca' (evita match em "escalada", "muscarinico")
    if (_any(corpus, [' iam', 'iamcsst', 'iamssst', ' sca ', 'sca sem supra',
        'infarto', 'stemi', 'nstemi', 'troponina', 'supra de st', 'supradesnível',
        'angina instável', 'angina inestable',
        'síndrome coronariana', 'sindrome coronaria', 'dor torácica',
        'dolor torácico'])) {
      return ClinicalTopic.sca;
    }

    // 2. Sepse
    // Build 236: removidos 'noradrenalina' e 'norepinefrina' — tokens ambíguos
    // que colidiam com contextos de IRSN (venlafaxina, duloxetina).
    // Substituídos por variantes com contexto exclusivamente septêmico.
    if (_any(corpus, ['sepse', 'sepsis', 'choque séptico', 'choque septico',
        'lactato', 'noradrenalina iv', 'vasopressor iv', 'vasopressor em bolo',
        'vasopressor sistêmico', 'pressores iv', 'pressores vasopressor',
        'bundle de sepse', 'bundle sepsis', 'qsofa', 'sofa',
        'critério de sepse', 'critério de sepsis', 'pac sepse',
        'drenagem de foco', 'antibiotico sepse', 'antibiótico sepse'])) {
      return ClinicalTopic.sepse;
    }

    // 3. Potássio / Hipocalemia
    // NOTA: 'k+' foi REMOVIDO intencionalmente — token genérico demais.
    // Aparece em contextos de DKA, trauma, etc. como "K+ 3.2" (valor laboratorial).
    // Usar apenas tokens específicos de hipocalemia/reposição de K.
    if (_any(corpus, ['potássio', 'potasio', 'hipocalemia', 'hipopotasemia',
        'hipocaliemia', 'kcl', 'cloreto de potássio', 'cloruro de potasio',
        'reposição de k', 'reposicion de k', 'k baixo', 'k bajo',
        'k⁺ baixo', 'k⁺ bajo', 'potássio baixo', 'potasio bajo',
        'hipocalemia grave', 'hipopotasemia grave'])) {
      return ClinicalTopic.potassio;
    }

    // 6. Anticoagulação
    // (Antidepressivos #4 e Parkinson #5 movidos para PRIORIDADE 0-A/0-B acima)
    if (_any(corpus, ['heparina', 'warfarina', 'apixabana', 'apixaban',
        'rivaroxabana', 'rivaroxaban', 'dabigatrana', 'dabigatran',
        'enoxaparina', 'hbpm', 'anticoagulação', 'anticoagulacion',
        'coagulação', 'coagulacion', 'reverter anticoagulação',
        'inr elevado', 'sangramento sob anticoagulante'])) {
      return ClinicalTopic.anticoagulacao;
    }

    // 7. Arritmias
    if (_any(corpus, ['fibrilação atrial', 'fibrilacion auricular',
        'fa ', ' fa,', 'flutter atrial', 'amiodarona',
        'taquicardia supraventricular', 'taquicardia ventricular',
        'tv ', 'fv ', 'tpsv', 'bradicardia', 'bloqueio av',
        'bloqueio de ramo', 'wpw', 'síndrome de wolff'])) {
      return ClinicalTopic.arritmia;
    }

    // 8. TEP
    // NOTA: 'tep' → ' tep' (evita match em "alteplase" = al-tep-lase)
    if (_any(corpus, [' tep', ' tep,', ' tep.', 'tromboembolismo pulmonar', 'embolia pulmonar',
        'wells', 'pesi', 'troponina e tep', 'anticoagular tep',
        'hbpm tep', 'alteplase tep', 'trombolise tep'])) {
      return ClinicalTopic.tep;
    }

    // 9. Asma
    if (_any(corpus, ['asma', 'broncoespasmo', 'salbutamol', 'albuterol',
        'ipratrópio', 'ipratropio', 'crise asmática', 'crisis asmática',
        'sibilância', 'sibilancia', 'pico de fluxo'])) {
      return ClinicalTopic.asma;
    }

    // 10. Pneumonia
    if (_any(corpus, ['pneumonia', 'nac', 'pac', 'ceftriaxona', 'azitromicina',
        'amoxicilina', 'pneumonia adquirida', 'pneumonia nosocomial',
        'hap', 'vap', 'pneumonia atípica', 'atypical pneumonia',
        'curb-65', 'psi escore'])) {
      return ClinicalTopic.pneumonia;
    }

    // 11. Diabetes / DKA / HHS
    if (_any(corpus, ['diabetes', 'insulina', 'dka', 'cetoacidose',
        'hhs', 'hipoglicemia', 'hipoglucemia', 'glicemia', 'glucemia',
        'hemoglobina glicada', 'hba1c', 'bomba de insulina',
        'cetose', 'cetosis'])) {
      return ClinicalTopic.diabetes;
    }

    // 12. Renal / IRA / IRC
    if (_any(corpus, ['ira ', 'irc ', 'lesão renal aguda', 'lesion renal aguda',
        'creatinina', 'clcr', 'clearance de creatinina', 'hemodiálise',
        'hemodialisis', 'diálise', 'dialisis', 'trs', 'kdigo',
        'injúria renal', 'injuria renal'])) {
      return ClinicalTopic.renal;
    }

    // 13. AVC / AVE
    // NOTA: 'ave' → ' ave' (evita match em "grave", "suave", "chave")
    if (_any(corpus, ['avc', ' ave', 'acidente vascular', 'acidente cerebral',
        'trombólise', 'trombolisis', 'nihss',
        'hemiplegia', 'hemiplejia', 'afasia', 'window terapêutica',
        'janela terapêutica', 'penumbra', 'acv ', 'ictus'])) {
      return ClinicalTopic.avc;
    }

    // 14. Hipertensão
    if (_any(corpus, ['hipertensão', 'hipertension', 'hta', 'pressão alta',
        'presión alta', 'crise hipertensiva', 'urgência hipertensiva',
        'emergência hipertensiva', 'ieca', 'bra', 'losartana',
        'enalapril', 'anlodipino', 'anti-hipertensivo'])) {
      return ClinicalTopic.hipertensao;
    }

    // 15. IC / ICC
    if (_any(corpus, ['insuficiência cardíaca', 'insuficiencia cardiaca',
        'ic ', 'icc', 'fração de ejeção', 'fraccion de eyeccion',
        'fey', 'fe reduzida', 'diurético', 'furosemida',
        'betabloqueador e ic', 'spironolactona', 'sacubitril',
        'congestão pulmonar', 'congestion pulmonar'])) {
      return ClinicalTopic.ic;
    }

    // 16. DPOC / EPOC
    if (_any(corpus, ['dpoc', 'epoc', 'doença pulmonar obstrutiva',
        'enfermedad pulmonar obstructiva', 'exacerbação de dpoc',
        'exacerbacion de epoc', 'broncodilatador', 'ipratrópio dpoc',
        'corticoide dpoc', 'vni dpoc', 'hipercapnia'])) {
      return ClinicalTopic.dpoc;
    }

    // 17. Anafilaxia
    if (_any(corpus, ['anafilaxia', 'anafilaxis', 'adrenalina', 'epinefrina',
        'adrenalina im', 'reação alérgica grave', 'reaccion alergica grave',
        'angioedema', 'urticária gigante'])) {
      return ClinicalTopic.anafilaxia;
    }

    // 18. Convulsão / Status Epiléptico
    if (_any(corpus, ['convulsão', 'convulsion', 'status epilepticus',
        'estado de mal epiléptico', 'estado epileptico',
        'diazepam', 'midazolam convulsão', 'levetiracetam',
        'fenitoína', 'fenitoina', 'epilepsia', 'crise epiléptica'])) {
      return ClinicalTopic.convulsao;
    }

    // 19. Meningite
    if (_any(corpus, ['meningite', 'meningitis', 'cefaleia em trovoada',
        'cefalea en trueno', 'rigidez de nuca', 'rigidez nucal',
        'petéquias meningite', 'liquor', 'líquor', 'lp ', 'punção lombar',
        'puncion lumbar', 'kernig', 'brudzinski'])) {
      return ClinicalTopic.meningite;
    }

    // 20. Endocardite
    if (_any(corpus, ['endocardite', 'endocarditis', 'hemocultura',
        'hemocultivo', 'critérios de duke', 'criterios de duke',
        'vegetação cardíaca', 'vegetacion cardiaca'])) {
      return ClinicalTopic.endocardite;
    }

    // 21. Hiponatremia
    if (_any(corpus, ['hiponatremia', 'sódio baixo', 'sodio bajo',
        'na baixo', 'na+ baixo', 'ssiadh', 'siadh',
        'correção de sódio', 'corrección de sodio', 'soluto hipertônico',
        'solución salina hipertónica'])) {
      return ClinicalTopic.hiponatremia;
    }

    // 22. Hipernatremia
    if (_any(corpus, ['hipernatremia', 'sódio alto', 'sodio alto',
        'na alto', 'na+ elevado', 'desidratação hipernatrêmica',
        'deshidratación hipernatrémica'])) {
      return ClinicalTopic.hipernatremia;
    }

    // 23. Acidose / Gasometria
    if (_any(corpus, ['acidose', 'acidosis', 'gasometria', 'gasometría',
        'ph baixo', 'ph bajo', 'bicarbonato baixo', 'bicarbonato bajo',
        'acidose metabólica', 'acidosis metabolica', 'acidose respiratória',
        'lactato elevado', 'base excess', 'anion gap'])) {
      return ClinicalTopic.acidose;
    }

    // 24. Alcalose
    if (_any(corpus, ['alcalose', 'alcalosis', 'ph alto', 'ph elevado',
        'bicarbonato alto', 'alcalose metabólica', 'alcalosis metabolica',
        'alcalose respiratória', 'alcalosis respiratoria'])) {
      return ClinicalTopic.alcalose;
    }

    // 25. Choque (genérico — deve vir DEPOIS de sepse/anafilaxia)
    if (_any(corpus, ['choque ', 'shock ', 'hipovolêmico', 'hipovolemico',
        'cardiogênico', 'cardiogenico', 'obstrutivo', 'obstrutivo',
        'distributivo', 'hipoperfusão', 'hipoperfusion',
        'pressão arterial baixa', 'hipotensão refratária'])) {
      return ClinicalTopic.choque;
    }

    // 26. Intubação / Via Aérea
    if (_any(corpus, ['intubação', 'intubacion', 'via aérea', 'via aerea',
        'iot ', 'sequência rápida', 'sequencia rapida', 'rsi',
        'laringoscopia', 'videolaringoscopia', 'bougie',
        'cormack', 'cricotireoidostomia', 'cricotireoidotomia',
        'máscara laríngea', 'mascara laringea'])) {
      return ClinicalTopic.intubacao;
    }

    // 27. Ventilação Mecânica
    if (_any(corpus, ['ventilação mecânica', 'ventilacion mecanica',
        'vm ', 'peep', 'fio2', 'volume corrente', 'volume tidal',
        'pressão de platô', 'plateau', 'driving pressure',
        'modo ventilatório', 'desmame ventilatório',
        'desmame ventilatorio'])) {
      return ClinicalTopic.ventilacao;
    }

    // 28. Sedação / Analgossedação
    if (_any(corpus, ['propofol', 'midazolam', 'dexmedetomidina',
        'dexmedetomidine', 'ketamina', 'ketamine', 'analgossedação',
        'analgosedacion', 'escala de sedação', 'rass', 'cam-icu',
        'despertar diário', 'despertar diario', 'protocolo de sedação'])) {
      return ClinicalTopic.sedacao;
    }

    // 29. Analgesia / Opioides
    if (_any(corpus, ['fentanil', 'morfina', 'tramadol', 'opioide',
        'opiáceo', 'opioideo', 'analgesia', 'dor crônica', 'dolor cronico',
        'equianalgesia', 'equivalência de opioides', 'naloxona'])) {
      return ClinicalTopic.analgesia;
    }

    // 30. Antibióticos de amplo espectro
    if (_any(corpus, ['cefepime', 'meropenem', 'imipenem', 'piperacilina',
        'tazobactam', 'pip-tazo', 'vancomicina', 'linezolida',
        'polimixina', 'colistina', 'anfotericina', 'carbapenem',
        'espectro ampliado', 'desescalonamento antibiótico'])) {
      return ClinicalTopic.antibioticos;
    }

    // 31. Obstetrícia
    if (_any(corpus, ['pré-eclâmpsia', 'preeclampsia', 'eclampsia',
        'ocitocina', 'oxitocina', 'gestante', 'grávida', 'embarazada',
        'parto', 'puerpério', 'puerperio', 'magnesio obstetrico',
        'sulfato de magnésio obs', 'dilatação cervical',
        'dilatacion cervical'])) {
      return ClinicalTopic.obstetricia;
    }

    // 32. Pediatria / Neonatologia
    if (_any(corpus, ['pediatria', 'pediátrico', 'pediatrico',
        'recém-nascido', 'recien nacido', 'neonato', 'criança',
        'niño', 'peso ao nascer', 'apgar', 'prematuro',
        'dose pediátrica', 'dose pediatrica'])) {
      return ClinicalTopic.pediatria;
    }

    // 33. Trauma
    if (_any(corpus, ['politrauma', 'trauma', 'abcde', 'atls',
        'hemorragia traumática', 'hemorragia traumatica',
        'fratura', 'fractura', 'tcce', 'tce ', 'pressão intracraniana',
        'pic ', 'damage control'])) {
      return ClinicalTopic.trauma;
    }

    // 34. Queimaduras
    if (_any(corpus, ['queimadura', 'quemadura', 'parkland',
        'superfície corporal queimada', 'superficie corporal quemada',
        'grau de queimadura', 'grado de quemadura',
        'debridamento queimadura', 'reposição volêmica queimadura'])) {
      return ClinicalTopic.queimadura;
    }

    // 35. Toxicologia
    if (_any(corpus, ['intoxicação', 'intoxicacion', 'overdose',
        'toxicologia', 'toxicidad', 'naloxona', 'flumazenil',
        'atropina intox', 'carvão ativado', 'carbon activado',
        'paracetamol intox', 'acetaminofeno intox', 'n-acetilcisteína',
        'nacetilcisteina', 'antídoto'])) {
      return ClinicalTopic.toxicologia;
    }

    // 36. Psiquiatria
    if (_any(corpus, ['esquizofrenia', 'esquizofrenia', 'bipolar',
        'transtorno bipolar', 'clozapina', 'haloperidol',
        'risperidona', 'olanzapina', 'crise psiquiátrica', 'crisis psiquiatrica',
        'agitação psicomotora', 'agitacion psicomotora',
        'contenção química', 'contencion quimica'])) {
      return ClinicalTopic.psiquiatria;
    }

    // 37. Hematologia
    if (_any(corpus, ['anemia', 'plaquetas', 'hemoglobina', 'hematócrito',
        'hematocrito', 'coagulopatia', 'coagulopatia', 'cid',
        'coagulação intravascular', 'coagulacion intravascular',
        'transfusão', 'transfusion', 'plasma fresco', 'ffp ',
        'plaquetopenia', 'trombocitopenia'])) {
      return ClinicalTopic.hematologia;
    }

    // 38. Gastro / Cirrose / Hemorragia Digestiva
    if (_any(corpus, ['cirrose', 'cirrosis', 'pancreatite', 'pancreatitis',
        'hemorragia digestiva', 'hemorragia digestiva',
        'varizes esofágicas', 'varices esofagicas', 'hda', 'hdb',
        'pbb ', 'ascite', 'ascitis', 'encefalopatia hepática',
        'encefalopatia hepatica', 'ranson', 'apache pâncreas'])) {
      return ClinicalTopic.gastro;
    }

    // 39. Endocrinologia
    if (_any(corpus, ['hipotireoidismo', 'hipotiroidismo', 'hipertireoidismo',
        'hipertiroidismo', 'cushing', 'addison', 'feocromocitoma',
        'crise tireotóxica', 'crise tireotoxica', 'mixedema',
        'insuficiência adrenal', 'insuficiencia adrenal', 'acromegalia'])) {
      return ClinicalTopic.endocrino;
    }

    // 40. Infectologia
    if (_any(corpus, ['hiv', 'aids', 'tuberculose', 'tuberculosis',
        'sífilis', 'sifilis', 'malária', 'malaria', 'dengue',
        'leptospirose', 'leptospirosis', 'antirretroviral', 'tarv',
        'opportunistic infection', 'infecção oportunista',
        'cd4', 'carga viral'])) {
      return ClinicalTopic.infectologia;
    }

    // 42. Delirium
    if (_any(corpus, ['delirium', 'confusão mental', 'confusion mental',
        'síndrome confusional', 'sindrome confusional', 'rebaixamento',
        'alteração do nível de consciência', 'encefalopatia aguda',
        'cam ', 'escala de confusão'])) {
      return ClinicalTopic.delirium;
    }

    return ClinicalTopic.nenhum;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Helper: retorna true se corpus contém QUALQUER dos tokens
  // ──────────────────────────────────────────────────────────────────────────
  static bool _any(String corpus, List<String> tokens) =>
      tokens.any((t) => corpus.contains(t));

  // ──────────────────────────────────────────────────────────────────────────
  // 3. SELEÇÃO DA AÇÃO — bilíngue (PT/ES), modo-consciente
  //
  // Cada tópico tem uma sequência de ações smart em dois modos:
  //   Plantão → conduta rápida, dose, manejo imediato
  //   Estudo  → mecanismo, comparativo, síndrome, aprofundamento
  //
  // A seleção é sempre a continuação MAIS IMPORTANTE do tema.
  // ──────────────────────────────────────────────────────────────────────────
  static SmartNextAction _selectAction({
    required ClinicalTopic topic,
    required bool isPlantaoMode,
    required String lang,
  }) {
    final es = lang == 'es';

    switch (topic) {
      // ── 1. SCA / IAM ──────────────────────────────────────────────────────
      case ClinicalTopic.sca:
        if (isPlantaoMode) {
          return SmartNextAction(
            label: es ? 'IAMCSST × IAMSSST' : 'IAMCSST × IAMSSST',
            promptToSend: es
                ? '¿Cuál es la diferencia en el manejo inicial entre IAMCSST y IAMSSST? Incluya tiempos puerta-balón y antiagregación.'
                : 'Qual a diferença no manejo inicial entre IAMCSST e IAMSSST? Inclua tempos porta-balão e antiagregação.',
          );
        } else {
          return SmartNextAction(
            label: es ? 'Fisiopatologia SCA' : 'Fisiopatologia SCA',
            promptToSend: es
                ? 'Explícame la fisiopatología del síndrome coronario agudo: ruptura de placa, trombosis y cascada isquémica.'
                : 'Explique a fisiopatologia da síndrome coronariana aguda: ruptura de placa, trombose e cascata isquêmica.',
          );
        }

      // ── 2. Sepse ───────────────────────────────────────────────────────────
      case ClinicalTopic.sepse:
        if (isPlantaoMode) {
          return SmartNextAction(
            label: es ? 'Vasopressores e doses' : 'Vasopressores e doses',
            promptToSend: es
                ? '¿Cuál es el esquema de vasopresores en choque séptico? Noradrenalina: dosis de inicio, titulación y cuándo agregar vasopresina.'
                : 'Qual o esquema de vasopressores no choque séptico? Noradrenalina: dose de início, titulação e quando adicionar vasopressina.',
          );
        } else {
          return SmartNextAction(
            label: es ? 'Criterios Sepsis-3' : 'Critérios Sepsis-3',
            promptToSend: es
                ? 'Explícame los criterios de Sepsis-3: definición de sepsis, choque séptico, qSOFA y SOFA.'
                : 'Explique os critérios do Sepsis-3: definição de sepse, choque séptico, qSOFA e SOFA.',
          );
        }

      // ── 3. Potássio / Hipocalemia ──────────────────────────────────────────
      case ClinicalTopic.potassio:
        if (isPlantaoMode) {
          return SmartNextAction(
            label: es ? 'Reposición EV de K⁺' : 'Reposição EV de K⁺',
            promptToSend: es
                ? 'Protocolo de reposición endovenosa de potasio en hipopotasemia severa: velocidad máxima, dilución y monitorización.'
                : 'Protocolo de reposição endovenosa de potássio na hipocalemia grave: velocidade máxima, diluição e monitorização.',
          );
        } else {
          return SmartNextAction(
            label: es ? 'ECG e hipopotasemia' : 'ECG e hipocalemia',
            promptToSend: es
                ? 'Describe las alteraciones electrocardiográficas de la hipopotasemia: onda U, aplanamiento de T, prolongación QT y riesgo arrítmico.'
                : 'Descreva as alterações eletrocardiográficas da hipocalemia: onda U, achatamento de T, prolongamento de QT e risco arrítmico.',
          );
        }

      // ── 4. Antidepressivos / ISRS ──────────────────────────────────────────
      case ClinicalTopic.antidepressivos:
        if (isPlantaoMode) {
          return SmartNextAction(
            label: es ? 'Síndrome serotoninérgico' : 'Síndrome serotoninérgica',
            promptToSend: es
                ? 'Síndrome serotoninérgico: triada clínica, criterios de Hunter, manejo agudo con ciproheptadina y cuándo intubar.'
                : 'Síndrome serotoninérgica: tríade clínica, critérios de Hunter, manejo agudo com ciproeptadina e quando intubar.',
          );
        } else {
          return SmartNextAction(
            label: es ? 'ISRS × IRSN: comparativo' : 'ISRS × IRSN: comparativo',
            promptToSend: es
                ? 'Compara ISRS versus IRSN en mecanismo de acción, perfil de efectos adversos, interacciones y elección clínica.'
                : 'Compare ISRS versus IRSN em mecanismo de ação, perfil de efeitos adversos, interações e escolha clínica.',
          );
        }

      // ── 5. Parkinson ───────────────────────────────────────────────────────
      case ClinicalTopic.parkinson:
        if (isPlantaoMode) {
          return SmartNextAction(
            label: es ? 'Crisis dopaminérgica' : 'Crise dopaminérgica',
            promptToSend: es
                ? 'Manejo de la crisis en Parkinson avanzado: síndrome de abstinencia dopaminérgica, fiebre, rigidez y protocolo de emergencia.'
                : 'Manejo da crise no Parkinson avançado: síndrome de abstinência dopaminérgica, febre, rigidez e protocolo de emergência.',
          );
        } else {
          return SmartNextAction(
            label: es ? 'Levodopa × Agonistas' : 'Levodopa × Agonistas',
            promptToSend: es
                ? 'Compara levodopa versus agonistas dopaminérgicos en Parkinson: eficacia, discinesias, fenómeno on-off y perfil de paciente ideal para cada uno.'
                : 'Compare levodopa versus agonistas dopaminérgicos no Parkinson: eficácia, discinesias, fenômeno on-off e perfil de paciente ideal para cada um.',
          );
        }

      // ── 6. Anticoagulação ──────────────────────────────────────────────────
      case ClinicalTopic.anticoagulacao:
        if (isPlantaoMode) {
          return SmartNextAction(
            label: es ? 'Revertir anticoagulación' : 'Reverter anticoagulação',
            promptToSend: es
                ? 'Protocolo urgente de reversión de anticoagulación: warfarina (vitamina K + CCP), heparina (protamina), DOACs (idarucizumab, andexanet).'
                : 'Protocolo urgente de reversão de anticoagulação: varfarina (vitamina K + CCP), heparina (protamina), DOACs (idarucizumab, andexanet alfa).',
          );
        } else {
          return SmartNextAction(
            label: es ? 'ACO × DOAC × Heparina' : 'ACO × DOAC × Heparina',
            promptToSend: es
                ? 'Compara anticoagulantes clásicos (warfarina, heparina) versus DOACs: mecanismo, monitorización, reversión y elección por indicación.'
                : 'Compare anticoagulantes clássicos (varfarina, heparina) versus DOACs: mecanismo, monitorização, reversão e escolha por indicação.',
          );
        }

      // ── 7. Arritmias ───────────────────────────────────────────────────────
      case ClinicalTopic.arritmia:
        if (isPlantaoMode) {
          return SmartNextAction(
            label: es ? 'Cardioversión: dosis' : 'Cardioversão: doses',
            promptToSend: es
                ? 'Protocolo de cardioversión eléctrica sincronizada: joules para FA, flutter, TPSV y TV estable. Sedación previa.'
                : 'Protocolo de cardioversão elétrica sincronizada: joules para FA, flutter, TPSV e TV estável. Sedação prévia.',
          );
        } else {
          return SmartNextAction(
            label: es ? 'FA: ritmo × frecuencia' : 'FA: ritmo × frequência',
            promptToSend: es
                ? 'Estrategia de control de ritmo versus control de frecuencia en FA: indicaciones, fármacos de elección y evidencia AFFIRM.'
                : 'Estratégia de controle de ritmo versus controle de frequência na FA: indicações, fármacos de escolha e evidência AFFIRM.',
          );
        }

      // ── 8. TEP ─────────────────────────────────────────────────────────────
      case ClinicalTopic.tep:
        if (isPlantaoMode) {
          return SmartNextAction(
            label: es ? 'Trombólisis en TEP' : 'Trombólise no TEP',
            promptToSend: es
                ? 'Indicaciones absolutas de trombólisis sistémica en TEP masivo: alteplase 100mg IV, contraindicaciones absolutas y rescate con embolectomía.'
                : 'Indicações absolutas de trombólise sistêmica no TEP maciço: alteplase 100mg IV, contraindicações absolutas e resgate com embolectomia.',
          );
        } else {
          return SmartNextAction(
            label: es ? 'Escore de Wells' : 'Escore de Wells',
            promptToSend: es
                ? 'Describe el escore de Wells para TEP: variables, puntuación, estratificación de riesgo y algoritmo diagnóstico con D-dímero y angiotomografía.'
                : 'Descreva o escore de Wells para TEP: variáveis, pontuação, estratificação de risco e algoritmo diagnóstico com D-dímero e angiotomografia.',
          );
        }

      // ── 9. Asma ────────────────────────────────────────────────────────────
      case ClinicalTopic.asma:
        if (isPlantaoMode) {
          return SmartNextAction(
            label: es ? 'Asma grave: protocolo' : 'Asma grave: protocolo',
            promptToSend: es
                ? 'Protocolo de asma grave en urgencias: salbutamol nebulizado dosis-respuesta, corticoide IV, ipratropio, magnesio IV y criterios de intubación.'
                : 'Protocolo de asma grave na emergência: salbutamol nebulizado dose-resposta, corticoide IV, ipratrópio, magnésio IV e critérios de intubação.',
          );
        } else {
          return SmartNextAction(
            label: es ? 'Asma × EPOC diferencial' : 'Asma × DPOC diferencial',
            promptToSend: es
                ? 'Diferencia clínica, funcional e histológica entre asma y EPOC: reversibilidad, eosinófilos, prueba broncodilatadora y síndrome de solapamiento.'
                : 'Diferença clínica, funcional e histológica entre asma e DPOC: reversibilidade, eosinófilos, prova broncodilatadora e síndrome de sobreposição.',
          );
        }

      // ── 10. Pneumonia ──────────────────────────────────────────────────────
      case ClinicalTopic.pneumonia:
        if (isPlantaoMode) {
          return SmartNextAction(
            label: es ? 'Antibiótico NAC: escalar' : 'Antibiótico NAC: escalar',
            promptToSend: es
                ? 'Escalada antibiótica en neumonía adquirida en la comunidad: ambulatorio, hospitalizado sin UCI, UCI grave. Duración de tratamiento.'
                : 'Escalonamento antibiótico na pneumonia adquirida na comunidade: ambulatorial, internado sem UTI, UTI grave. Duração do tratamento.',
          );
        } else {
          return SmartNextAction(
            label: es ? 'CURB-65 × PSI' : 'CURB-65 × PSI',
            promptToSend: es
                ? 'Compara CURB-65 versus PSI/PORT en neumonía: variables, puntuación, decisión de hospitalización y limitaciones de cada escore.'
                : 'Compare CURB-65 versus PSI/PORT na pneumonia: variáveis, pontuação, decisão de internação e limitações de cada escore.',
          );
        }

      // ── 11. Diabetes / DKA / HHS ───────────────────────────────────────────
      case ClinicalTopic.diabetes:
        if (isPlantaoMode) {
          return SmartNextAction(
            label: es ? 'CAD: insulina e K⁺' : 'CAD: insulina e K⁺',
            promptToSend: es
                ? 'Protocolo de insulinoterapia en cetoacidosis diabética: velocidad de infusión, cuándo iniciar, monitorización de K⁺ y criterios de resolución.'
                : 'Protocolo de insulinoterapia na cetoacidose diabética: velocidade de infusão, quando iniciar, monitorização de K⁺ e critérios de resolução.',
          );
        } else {
          return SmartNextAction(
            label: es ? 'CAD × HHS: diferencial' : 'CAD × HHS: diferencial',
            promptToSend: es
                ? 'Diferencias fisiopatológicas y clínicas entre cetoacidosis diabética y estado hiperosmolar hiperglucémico: fisiopatología, laboratorio, manejo.'
                : 'Diferenças fisiopatológicas e clínicas entre cetoacidose diabética e estado hiperosmolar hiperglicêmico: fisiopatologia, laboratório, manejo.',
          );
        }

      // ── 12. Renal / IRA ────────────────────────────────────────────────────
      case ClinicalTopic.renal:
        if (isPlantaoMode) {
          return SmartNextAction(
            label: es ? 'Indicaciones de diálisis' : 'Indicações de diálise',
            promptToSend: es
                ? 'Indicaciones urgentes de terapia de reemplazo renal en IRA: AEIOU mnemónico (acidosis, electrolitos, intoxicación, sobrecarga, uremia).'
                : 'Indicações urgentes de terapia renal substitutiva na IRA: mnemônico AEIOU (acidose, eletrólitos, intoxicação, sobrecarga volêmica, uremia).',
          );
        } else {
          return SmartNextAction(
            label: es ? 'KDIGO IRA: estadios' : 'KDIGO IRA: estágios',
            promptToSend: es
                ? 'Criterios KDIGO para lesión renal aguda: estadios 1-3 por creatinina y diuresis, fisiopatología prerrenal vs intrínseca vs posrenal.'
                : 'Critérios KDIGO para lesão renal aguda: estágios 1-3 por creatinina e diurese, fisiopatologia pré-renal vs intrínseca vs pós-renal.',
          );
        }

      // ── 13. AVC ────────────────────────────────────────────────────────────
      case ClinicalTopic.avc:
        if (isPlantaoMode) {
          return SmartNextAction(
            label: es ? 'Trombólisis: criterios' : 'Trombólise: critérios',
            promptToSend: es
                ? 'Criterios de inclusión y exclusión para trombólisis IV con alteplase en ACV isquémico: ventana, NIHSS, PA máxima y contraindicaciones absolutas.'
                : 'Critérios de inclusão e exclusão para trombólise IV com alteplase no AVC isquêmico: janela, NIHSS, PA máxima e contraindicações absolutas.',
          );
        } else {
          return SmartNextAction(
            label: es ? 'ACV isquémico × hemorrágico' : 'AVC isquêmico × hemorrágico',
            promptToSend: es
                ? 'Diferencias clínicas y de imagen entre ACV isquémico y hemorrágico: presentación, TC sin contraste, manejo inicial diferencial.'
                : 'Diferenças clínicas e de imagem entre AVC isquêmico e hemorrágico: apresentação, TC sem contraste, manejo inicial diferencial.',
          );
        }

      // ── 14. Hipertensão ────────────────────────────────────────────────────
      case ClinicalTopic.hipertensao:
        if (isPlantaoMode) {
          return SmartNextAction(
            label: es ? 'Emergencia × urgencia HTA' : 'Emergência × urgência HAS',
            promptToSend: es
                ? 'Diferencia emergencia versus urgencia hipertensiva: definición, ejemplos de daño de órgano, fármaco IV de elección para cada situación.'
                : 'Diferença emergência versus urgência hipertensiva: definição, exemplos de lesão de órgão-alvo, fármaco IV de escolha para cada situação.',
          );
        } else {
          return SmartNextAction(
            label: es ? 'Anti-HTA: mecanismos' : 'Anti-HAS: mecanismos',
            promptToSend: es
                ? 'Mecanismos de acción de los antihipertensivos: IECA, ARA-II, bloqueadores de calcio, betabloqueadores y diuréticos tiazídicos.'
                : 'Mecanismos de ação dos anti-hipertensivos: IECA, BRA, bloqueadores de canal de cálcio, betabloqueadores e tiazídicos.',
          );
        }

      // ── 15. IC ─────────────────────────────────────────────────────────────
      case ClinicalTopic.ic:
        if (isPlantaoMode) {
          return SmartNextAction(
            label: es ? 'IC descompensada: diuresis' : 'IC descompensada: diurese',
            promptToSend: es
                ? 'Protocolo de diuresis forzada en IC aguda descompensada: furosemida IV bolo versus infusión, metas de diuresis, resistencia a diuréticos.'
                : 'Protocolo de diurese forçada na IC aguda descompensada: furosemida IV em bolus versus infusão, metas de diurese, resistência a diurético.',
          );
        } else {
          return SmartNextAction(
            label: es ? 'IC: tratamento DAPA-HF' : 'IC: tratamento base DAPA',
            promptToSend: es
                ? 'Pilares del tratamiento modificador de pronóstico en ICFEr: betabloqueadores, IECA/sacubitrilo-valsartán, espironolactona y SGLT2 (evidencia DAPA-HF).'
                : 'Pilares do tratamento modificador de prognóstico na ICFEr: betabloqueadores, IECA/sacubitril-valsartana, espironolactona e SGLT2 (evidência DAPA-HF).',
          );
        }

      // ── 16. DPOC ───────────────────────────────────────────────────────────
      case ClinicalTopic.dpoc:
        if (isPlantaoMode) {
          return SmartNextAction(
            label: es ? 'EPOC: VNI ou intubação?' : 'DPOC: VNI ou IOT?',
            promptToSend: es
                ? 'Criterios de ventilación no invasiva versus intubación en exacerbación grave de EPOC: indicaciones, contraindicaciones y parámetros de fallo de VNI.'
                : 'Critérios de ventilação não invasiva versus intubação na exacerbação grave de DPOC: indicações, contraindicações e parâmetros de falha de VNI.',
          );
        } else {
          return SmartNextAction(
            label: es ? 'GOLD: estadios EPOC' : 'GOLD: estadiamento DPOC',
            promptToSend: es
                ? 'Estadiamento GOLD del EPOC: espirometría (GOLD 1-4), grupos ABCD por síntomas/exacerbaciones y tratamiento escalonado por grupo.'
                : 'Estadiamento GOLD do DPOC: espirometria (GOLD 1-4), grupos ABCD por sintomas/exacerbações e tratamento escalonado por grupo.',
          );
        }

      // ── 17. Anafilaxia ─────────────────────────────────────────────────────
      case ClinicalTopic.anafilaxia:
        if (isPlantaoMode) {
          return SmartNextAction(
            label: es ? 'Adrenalina: dosis y vía' : 'Adrenalina: dose e via',
            promptToSend: es
                ? 'Protocolo de anafilaxia: adrenalina 0,3-0,5mg IM vasto lateral, posición, volumen IV, corticoide, antihistamínico y cuándo repetir adrenalina.'
                : 'Protocolo de anafilaxia: adrenalina 0,3-0,5mg IM vasto lateral, posição, volume IV, corticoide, anti-histamínico e quando repetir adrenalina.',
          );
        } else {
          return SmartNextAction(
            label: es ? 'Fisiopatología anafilaxia' : 'Fisiopatologia anafilaxia',
            promptToSend: es
                ? 'Fisiopatología de la anafilaxia: IgE, mastocitos, mediadores vasoactivos, colapso cardiovascular y diferencia con reacción anafilactoide.'
                : 'Fisiopatologia da anafilaxia: IgE, mastócitos, mediadores vasoativos, colapso cardiovascular e diferença com reação anafilactoide.',
          );
        }

      // ── 18. Convulsão ──────────────────────────────────────────────────────
      case ClinicalTopic.convulsao:
        if (isPlantaoMode) {
          return SmartNextAction(
            label: es ? 'Status epiléptico: escalar' : 'Status epiléptico: escalar',
            promptToSend: es
                ? 'Escalada farmacológica en status epiléptico: 1ª línea benzodiazepinas IV/IM, 2ª línea fenitoína o levetiracetam IV, 3ª línea propofol o midazolam IV.'
                : 'Escalonamento farmacológico no estado de mal epiléptico: 1ª linha benzodiazepínicos IV/IM, 2ª linha fenitoína ou levetiracetam IV, 3ª linha propofol ou midazolam IV.',
          );
        } else {
          return SmartNextAction(
            label: es ? 'Crisis focal × generalizada' : 'Crise focal × generalizada',
            promptToSend: es
                ? 'Clasificación ILAE de las crisis epilépticas: focal vs generalizada vs inicio desconocido, semiología y correlato electroencefalográfico.'
                : 'Classificação ILAE das crises epilépticas: focal vs generalizada vs início desconhecido, semiologia e correlato eletroencefalográfico.',
          );
        }

      // ── 19. Meningite ──────────────────────────────────────────────────────
      case ClinicalTopic.meningite:
        if (isPlantaoMode) {
          return SmartNextAction(
            label: es ? 'ATB + dexametasona' : 'ATB + dexametasona',
            promptToSend: es
                ? 'Protocolo de meningitis bacteriana aguda: ceftriaxona 2g IV 12/12h, dexametasona 0,15mg/kg antes do ATB, cobertura para listeria e cuándo aciclovir.'
                : 'Protocolo de meningite bacteriana aguda: ceftriaxona 2g IV 12/12h, dexametasona 0,15mg/kg antes do ATB, cobertura para listeria e quando aciclovir.',
          );
        } else {
          return SmartNextAction(
            label: es ? 'Líquido cefalorraquídeo' : 'Análise do líquor',
            promptToSend: es
                ? 'Interpretación del LCR en meningitis: patrón bacteriano vs viral vs fúngico vs tuberculosa — células, glucosa, proteínas, tinciones y cultivos.'
                : 'Interpretação do líquor na meningite: padrão bacteriano vs viral vs fúngico vs tuberculosa — células, glicose, proteínas, colorações e culturas.',
          );
        }

      // ── 20. Endocardite ────────────────────────────────────────────────────
      case ClinicalTopic.endocardite:
        if (isPlantaoMode) {
          return SmartNextAction(
            label: es ? 'Antibiótico endocarditis' : 'Antibiótico endocardite',
            promptToSend: es
                ? 'Esquema antibiótico empírico en endocarditis infecciosa: válvula nativa (oxacilina + gentamicina) vs válvula protésica (vancomicina + rifampicina) y duración.'
                : 'Esquema antibiótico empírico na endocardite infecciosa: válvula nativa (oxacilina + gentamicina) vs válvula protética (vancomicina + rifampicina) e duração.',
          );
        } else {
          return SmartNextAction(
            label: es ? 'Criterios de Duke' : 'Critérios de Duke',
            promptToSend: es
                ? 'Criterios de Duke modificados para endocarditis infecciosa: criterios mayores y menores, definición de diagnóstico definitivo, posible y rechazado.'
                : 'Critérios de Duke modificados para endocardite infecciosa: critérios maiores e menores, definição de diagnóstico definitivo, possível e rejeitado.',
          );
        }

      // ── 21. Hiponatremia ───────────────────────────────────────────────────
      case ClinicalTopic.hiponatremia:
        if (isPlantaoMode) {
          return SmartNextAction(
            label: es ? 'Corrección de sodio' : 'Correção do sódio',
            promptToSend: es
                ? 'Protocolo de corrección de hiponatremia grave (Na < 120): velocidad máxima 8-10mEq/24h, solución salina hipertónica 3%, riesgo de mielinólisis pontina.'
                : 'Protocolo de correção de hiponatremia grave (Na < 120): velocidade máxima 8-10mEq/24h, solução salina hipertônica 3%, risco de mielinólise pontina.',
          );
        } else {
          return SmartNextAction(
            label: es ? 'SIADH × otras causas' : 'SIADH × outras causas',
            promptToSend: es
                ? 'Diagnóstico diferencial de hiponatremia: SIADH, polidipsia, hipotiroidismo, insuficiencia adrenal — osmolalidad plasmática y urinaria.'
                : 'Diagnóstico diferencial de hiponatremia: SIADH, polidipsia, hipotireoidismo, insuficiência adrenal — osmolalidade plasmática e urinária.',
          );
        }

      // ── 22. Hipernatremia ──────────────────────────────────────────────────
      case ClinicalTopic.hipernatremia:
        if (isPlantaoMode) {
          return SmartNextAction(
            label: es ? 'Hidratación: cálculo déficit' : 'Reidratação: déficit',
            promptToSend: es
                ? 'Cálculo del déficit de agua libre en hipernatremia y protocolo de corrección: velocidad máxima de reducción del sodio para evitar edema cerebral.'
                : 'Cálculo do déficit de água livre na hipernatremia e protocolo de correção: velocidade máxima de redução do sódio para evitar edema cerebral.',
          );
        } else {
          return SmartNextAction(
            label: es ? 'Diabetes insípida' : 'Diabetes insipidus',
            promptToSend: es
                ? 'Diferencia diabetes insípida central versus nefrogénica: fisiopatología, prueba de deshidratación, desmopresina y manejo diferencial.'
                : 'Diferença diabetes insipidus central versus nefrogênica: fisiopatologia, teste de desidratação, desmopressina e manejo diferencial.',
          );
        }

      // ── 23. Acidose ────────────────────────────────────────────────────────
      case ClinicalTopic.acidose:
        if (isPlantaoMode) {
          return SmartNextAction(
            label: es ? 'Bicarbonato: cuándo usar' : 'Bicarbonato: quando usar',
            promptToSend: es
                ? 'Indicaciones de bicarbonato IV en acidosis metabólica severa: pH < 7.1, hipercalemia refractaria, intoxicación por tricíclicos. Cuándo NO usar en acidosis láctica.'
                : 'Indicações de bicarbonato IV na acidose metabólica grave: pH < 7,1, hipercalemia refratária, intoxicação por tricíclicos. Quando NÃO usar na acidose lática.',
          );
        } else {
          return SmartNextAction(
            label: es ? 'Análisis de gases: pasos' : 'Análise gasométrica: passos',
            promptToSend: es
                ? 'Metodología de interpretación de gasometría en 6 pasos: acidosis vs alcalosis, metabólica vs respiratoria, compensación esperada y trastornos mixtos.'
                : 'Metodologia de interpretação da gasometria em 6 passos: acidose vs alcalose, metabólica vs respiratória, compensação esperada e distúrbios mistos.',
          );
        }

      // ── 24. Alcalose ───────────────────────────────────────────────────────
      case ClinicalTopic.alcalose:
        if (isPlantaoMode) {
          return SmartNextAction(
            label: es ? 'Alcalosis: causas urgentes' : 'Alcalose: causas urgentes',
            promptToSend: es
                ? 'Manejo urgente de alcalosis metabólica severa (pH > 7.6): causas (vómitos, diuréticos, Cl urinario), corrección con cloruro y reposición de K⁺.'
                : 'Manejo urgente de alcalose metabólica grave (pH > 7,6): causas (vômitos, diuréticos, Cl urinário), correção com cloreto e reposição de K⁺.',
          );
        } else {
          return SmartNextAction(
            label: es ? 'Alcalosis: fisiopatología' : 'Alcalose: fisiopatologia',
            promptToSend: es
                ? 'Fisiopatología de la alcalosis metabólica: factores de generación y mantenimiento, rol del cloro urinario y clasificación cloro-sensible versus resistente.'
                : 'Fisiopatologia da alcalose metabólica: fatores de geração e manutenção, papel do cloro urinário e classificação cloro-sensível versus resistente.',
          );
        }

      // ── 25. Choque ─────────────────────────────────────────────────────────
      case ClinicalTopic.choque:
        if (isPlantaoMode) {
          return SmartNextAction(
            label: es ? 'Clasificar el tipo de shock' : 'Classificar o tipo de choque',
            promptToSend: es
                ? 'Clasificación del shock y enfoque hemodinámico: hipovolémico, distributivo, cardiogénico y obstructivo — perfil clínico, ecocardiografía point-of-care.'
                : 'Classificação do choque e abordagem hemodinâmica: hipovolêmico, distributivo, cardiogênico e obstrutivo — perfil clínico, ecocardiografia point-of-care.',
          );
        } else {
          return SmartNextAction(
            label: es ? 'Fisiopatología del shock' : 'Fisiopatologia do choque',
            promptToSend: es
                ? 'Fisiopatología del shock: DO₂, VO₂, extracción de O₂, disfunción mitocondrial y cascada de falla multiorgánica.'
                : 'Fisiopatologia do choque: DO₂, VO₂, extração de O₂, disfunção mitocondrial e cascata de falência de múltiplos órgãos.',
          );
        }

      // ── 26. Intubação ──────────────────────────────────────────────────────
      case ClinicalTopic.intubacao:
        if (isPlantaoMode) {
          return SmartNextAction(
            label: es ? 'SIR: secuencia completa' : 'SRI: sequência completa',
            promptToSend: es
                ? 'Secuencia de intubación rápida completa: premedicación, ketamina/propofol + succinilcolina o rocurônio, dosis, posición y verificación con capnografía.'
                : 'Sequência de intubação de sequência rápida completa: pré-medicação, quetamina/propofol + succinilcolina ou rocurônio, doses, posição e verificação com capnografia.',
          );
        } else {
          return SmartNextAction(
            label: es ? 'Vía aérea difícil: algoritmo' : 'Via aérea difícil: algoritmo',
            promptToSend: es
                ? 'Algoritmo de vía aérea difícil: predictores (LEMON), videolaringoscopia, bougie, mascara laríngea de rescate y cricotirotomía de emergencia.'
                : 'Algoritmo de via aérea difícil: preditores (LEMON), videolaringoscopia, bougie, máscara laríngea de resgate e cricotireoidostomia de emergência.',
          );
        }

      // ── 27. Ventilação Mecânica ─────────────────────────────────────────────
      case ClinicalTopic.ventilacao:
        if (isPlantaoMode) {
          return SmartNextAction(
            label: es ? 'Parámetros iniciales VM' : 'Parâmetros iniciais VM',
            promptToSend: es
                ? 'Configuración inicial del ventilador mecánico: volumen tidal 6ml/kg IBW, PEEP inicial, FiO₂ 100% luego titular, frecuencia y alarmas de meseta.'
                : 'Configuração inicial do ventilador mecânico: volume corrente 6ml/kg PI, PEEP inicial, FiO₂ 100% depois titular, frequência e alarmes de platô.',
          );
        } else {
          return SmartNextAction(
            label: es ? 'SDRA: estrategia protectora' : 'SDRA: estratégia protetora',
            promptToSend: es
                ? 'Ventilación protectora en SDRA: volumen tidal 6ml/kg, presión meseta < 30cmH₂O, driving pressure < 15cmH₂O, PEEP tabla ARDSnet y posición prona.'
                : 'Ventilação protetora no SDRA: volume corrente 6ml/kg, pressão de platô < 30cmH₂O, driving pressure < 15cmH₂O, PEEP tabela ARDSnet e pronação.',
          );
        }

      // ── 28. Sedação ────────────────────────────────────────────────────────
      case ClinicalTopic.sedacao:
        if (isPlantaoMode) {
          return SmartNextAction(
            label: es ? 'Protocolo ABCDEF UCI' : 'Protocolo ABCDEF UTI',
            promptToSend: es
                ? 'Bundle ABCDEF en UCI: Awaken + Breathing + Coordination + Delirium + Early mobility + Family — impacto en mortalidad y días de ventilación.'
                : 'Bundle ABCDEF na UTI: Awaken + Breathing + Coordination + Delirium + Early mobility + Family — impacto em mortalidade e dias de ventilação.',
          );
        } else {
          return SmartNextAction(
            label: es ? 'Propofol × Dexmedetomidina' : 'Propofol × Dexmedetomidina',
            promptToSend: es
                ? 'Compara propofol versus dexmedetomidina para sedación en UCI: mecanismo, profundidad, ventajas, toxicidad y cuándo preferir uno sobre el otro.'
                : 'Compare propofol versus dexmedetomidina para sedação em UTI: mecanismo, profundidade, vantagens, toxicidade e quando preferir um sobre o outro.',
          );
        }

      // ── 29. Analgesia ──────────────────────────────────────────────────────
      case ClinicalTopic.analgesia:
        if (isPlantaoMode) {
          return SmartNextAction(
            label: es ? 'Equianalgesia: conversión' : 'Equianalgesia: conversão',
            promptToSend: es
                ? 'Tabla de equianalgesia opiácea: morfina IV como referencia, conversión a fentanilo, oxicodona, tramadol y metadona. Cálculo de dosis de rescate.'
                : 'Tabela de equianalgesia opiácea: morfina IV como referência, conversão para fentanil, oxicodona, tramadol e metadona. Cálculo de dose de resgate.',
          );
        } else {
          return SmartNextAction(
            label: es ? 'Escala analgésica OMS' : 'Escada analgésica OMS',
            promptToSend: es
                ? 'Escalera analgésica de la OMS: degrau 1 (AINE/paracetamol), degrau 2 (tramadol), degrau 3 (opioides fuertes), adjuvantes y principio de tratamento.'
                : 'Escada analgésica da OMS: degrau 1 (AINE/paracetamol), degrau 2 (tramadol), degrau 3 (opioides fortes), adjuvantes e princípio do tratamento.',
          );
        }

      // ── 30. Antibióticos ───────────────────────────────────────────────────
      case ClinicalTopic.antibioticos:
        if (isPlantaoMode) {
          return SmartNextAction(
            label: es ? 'Desescalar antibiótico' : 'Desescalar antibiótico',
            promptToSend: es
                ? 'Criterios y timing para desescalada antibiótica en UTI: cuándo hacer, cultivos definitivos, PK/PD, duración óptima y impacto en resistencia bacteriana.'
                : 'Critérios e timing para desescalonamento antibiótico em UTI: quando fazer, culturas definitivas, PK/PD, duração ótima e impacto em resistência bacteriana.',
          );
        } else {
          return SmartNextAction(
            label: es ? 'Carbapenemes × colistina' : 'Carbapenemes × colistina',
            promptToSend: es
                ? 'Comparación carbapenemes versus colistina en infecciones por gram-negativos multirresistentes: mecanismo, KPC, OXA-48, dosificación renal y toxicidades.'
                : 'Comparação carbapenemes versus colistina em infecções por gram-negativos multirresistentes: mecanismo, KPC, OXA-48, dosagem renal e toxicidades.',
          );
        }

      // ── 31. Obstetrícia ────────────────────────────────────────────────────
      case ClinicalTopic.obstetricia:
        if (isPlantaoMode) {
          return SmartNextAction(
            label: es ? 'Eclampsia: sulfato Mg' : 'Eclâmpsia: sulfato Mg',
            promptToSend: es
                ? 'Protocolo de eclampsia: sulfato de magnesio dosis de ataque 4-6g IV + mantenimiento 1-2g/h, control de PA, parto de urgencia y manejo de toxicidad por Mg.'
                : 'Protocolo de eclâmpsia: sulfato de magnésio dose de ataque 4-6g IV + manutenção 1-2g/h, controle de PA, parto de urgência e manejo de toxicidade por Mg.',
          );
        } else {
          return SmartNextAction(
            label: es ? 'Pré-eclâmpsia × eclampsia' : 'Pré-eclâmpsia × eclâmpsia',
            promptToSend: es
                ? 'Fisiopatología y criterios diagnósticos de preeclampsia con y sin características graves, versus eclampsia y síndrome HELLP.'
                : 'Fisiopatologia e critérios diagnósticos de pré-eclâmpsia com e sem características graves, versus eclâmpsia e síndrome HELLP.',
          );
        }

      // ── 32. Pediatria ──────────────────────────────────────────────────────
      case ClinicalTopic.pediatria:
        if (isPlantaoMode) {
          return SmartNextAction(
            label: es ? 'Dosis pediátrica: cálculo' : 'Dose pediátrica: cálculo',
            promptToSend: es
                ? 'Principios de cálculo de dosis pediátricas por peso: mg/kg, dosis máxima del adulto como techo, fármacos contraindicados por edad y ajuste por función renal.'
                : 'Princípios de cálculo de doses pediátricas por peso: mg/kg, dose máxima do adulto como teto, fármacos contraindicados por idade e ajuste por função renal.',
          );
        } else {
          return SmartNextAction(
            label: es ? 'Desarrollo pediátrico' : 'Desenvolvimento pediátrico',
            promptToSend: es
                ? 'Hitos del desarrollo neuropsicomotor: motor grueso, fino, lenguaje y social en los primeros 5 años — señales de alarma y derivación.'
                : 'Marcos do desenvolvimento neuropsicomotor: motor grosso, fino, linguagem e social nos primeiros 5 anos — sinais de alarme e encaminhamento.',
          );
        }

      // ── 33. Trauma ─────────────────────────────────────────────────────────
      case ClinicalTopic.trauma:
        if (isPlantaoMode) {
          return SmartNextAction(
            label: es ? 'Control de hemorragia' : 'Controle de hemorragia',
            promptToSend: es
                ? 'Damage control resuscitation en trauma: transfusión hemostática 1:1:1 (CH:PFC:plaquetas), ácido tranexámico, hipotensión permisiva y cuándo ir al quirófano.'
                : 'Damage control resuscitation no trauma: transfusão hemostática 1:1:1 (CH:PFC:plaquetas), ácido tranexâmico, hipotensão permissiva e quando ir ao centro cirúrgico.',
          );
        } else {
          return SmartNextAction(
            label: es ? 'ATLS: ABCDE del trauma' : 'ATLS: ABCDE do trauma',
            promptToSend: es
                ? 'Protocolo ATLS de atención primaria en trauma: A (vía aérea), B (respiración), C (circulación), D (neurológico), E (exposición) — hallazgos y acciones en cada etapa.'
                : 'Protocolo ATLS de atendimento primário no trauma: A (via aérea), B (respiração), C (circulação), D (neurológico), E (exposição) — achados e ações em cada etapa.',
          );
        }

      // ── 34. Queimadura ─────────────────────────────────────────────────────
      case ClinicalTopic.queimadura:
        if (isPlantaoMode) {
          return SmartNextAction(
            label: es ? 'Parkland: volumen IV' : 'Parkland: volume IV',
            promptToSend: es
                ? 'Fórmula de Parkland para reposición hídrica en quemaduras: 4ml × kg × %SCQ, volumen 1ª mitad nas 8h, 2ª mitad nas 16h y monitorización por diuresis.'
                : 'Fórmula de Parkland para reposição hídrica em queimaduras: 4ml × kg × %SCQ, volume 1ª metade nas 8h, 2ª metade nas 16h e monitorização por diurese.',
          );
        } else {
          return SmartNextAction(
            label: es ? 'Clasificación quemaduras' : 'Classificação queimaduras',
            promptToSend: es
                ? 'Clasificación de quemaduras por profundidad: 1° (epidermis), 2° superficial y profunda (dermis), 3° (hipodermis) — características clínicas y cicatrización.'
                : 'Classificação de queimaduras por profundidade: 1° (epiderme), 2° superficial e profunda (derme), 3° (hipoderme) — características clínicas e cicatrização.',
          );
        }

      // ── 35. Toxicologia ─────────────────────────────────────────────────────
      case ClinicalTopic.toxicologia:
        if (isPlantaoMode) {
          return SmartNextAction(
            label: es ? 'Antídoto por síndrome' : 'Antídoto por síndrome',
            promptToSend: es
                ? 'Tabla de toxidromes y antídotos urgentes: opioide (naloxona), benzo (flumazenil), organofosforado (atropina), paracetamol (NAC), digitálico (anticuerpos Fab).'
                : 'Tabela de toxíndromes e antídotos urgentes: opioide (naloxona), benzo (flumazenil), organofosforado (atropina), paracetamol (NAC), digitálico (anticorpos Fab).',
          );
        } else {
          return SmartNextAction(
            label: es ? 'Intoxicación paracetamol' : 'Intoxicação paracetamol',
            promptToSend: es
                ? 'Fisiopatología de la intoxicación por paracetamol: metabolismo NAPQI, necrosis hepática, nomograma de Rumack-Matthew y protocolo de N-acetilcisteína IV.'
                : 'Fisiopatologia da intoxicação por paracetamol: metabolismo NAPQI, necrose hepática, nomograma de Rumack-Matthew e protocolo de N-acetilcisteína IV.',
          );
        }

      // ── 36. Psiquiatria ─────────────────────────────────────────────────────
      case ClinicalTopic.psiquiatria:
        if (isPlantaoMode) {
          return SmartNextAction(
            label: es ? 'Agitación psicomotora' : 'Agitação psicomotora',
            promptToSend: es
                ? 'Protocolo de contención farmacológica en agitación psicomotora: haloperidol + midazolam, droperidol, olanzapina IM — dosis, vías, monitorización y seguridad.'
                : 'Protocolo de contenção farmacológica na agitação psicomotora: haloperidol + midazolam, droperidol, olanzapina IM — doses, vias, monitorização e segurança.',
          );
        } else {
          return SmartNextAction(
            label: es ? 'Antipsicóticos: mecanismo' : 'Antipsicóticos: mecanismo',
            promptToSend: es
                ? 'Mecanismo de acción de los antipsicóticos: bloqueo D2, receptores 5-HT2A, efectos extrapiramidales, síndrome neuroléptico maligno y diferencia típicos × atípicos.'
                : 'Mecanismo de ação dos antipsicóticos: bloqueio D2, receptores 5-HT2A, efeitos extrapiramidais, síndrome neuroléptica maligna e diferença típicos × atípicos.',
          );
        }

      // ── 37. Hematologia ─────────────────────────────────────────────────────
      case ClinicalTopic.hematologia:
        if (isPlantaoMode) {
          return SmartNextAction(
            label: es ? 'CID: tratamiento urgente' : 'CIVD: tratamento urgente',
            promptToSend: es
                ? 'Manejo de CID aguda: plasma fresco, crioprecipitado (fibrinógeno < 1,5g/L), plaquetas (< 50k + sangrado activo) y tratar causa desencadenante.'
                : 'Manejo da CIVD aguda: plasma fresco, crioprecipitado (fibrinogênio < 1,5g/L), plaquetas (< 50k + sangramento ativo) e tratar causa desencadeante.',
          );
        } else {
          return SmartNextAction(
            label: es ? 'Anemias: clasificación' : 'Anemias: classificação',
            promptToSend: es
                ? 'Clasificación de anemias por VCM: microcítica (ferropénica, talasemia), normocítica (hemolítica, crónica) y macrocítica (B12, folato) — enfoque diagnóstico.'
                : 'Classificação das anemias por VCM: microcítica (ferropriva, talassemia), normocítica (hemolítica, doença crônica) e macrocítica (B12, folato) — abordagem diagnóstica.',
          );
        }

      // ── 38. Gastro ─────────────────────────────────────────────────────────
      case ClinicalTopic.gastro:
        if (isPlantaoMode) {
          return SmartNextAction(
            label: es ? 'Hemorragia digestiva alta' : 'Hemorragia digestiva alta',
            promptToSend: es
                ? 'Manejo urgente de HDA: estabilización, IBP IV, endoscopia en 24h, escore de Rockall/Blatchford, band ligation y cuándo cirugía de resgate.'
                : 'Manejo urgente de HDA: estabilização, IBP IV, endoscopia em 24h, escore de Rockall/Blatchford, ligadura elástica de varizes e quando cirurgia de resgate.',
          );
        } else {
          return SmartNextAction(
            label: es ? 'Child-Pugh × MELD' : 'Child-Pugh × MELD',
            promptToSend: es
                ? 'Comparación Child-Pugh versus MELD en cirrosis hepática: variables, puntuación, pronóstico, indicación de trasplante y limitaciones de cada escala.'
                : 'Comparação Child-Pugh versus MELD na cirrose hepática: variáveis, pontuação, prognóstico, indicação de transplante e limitações de cada escala.',
          );
        }

      // ── 39. Endocrinologia ─────────────────────────────────────────────────
      case ClinicalTopic.endocrino:
        if (isPlantaoMode) {
          return SmartNextAction(
            label: es ? 'Crise tireotóxica: manejo' : 'Crise tireotóxica: manejo',
            promptToSend: es
                ? 'Protocolo urgente de crisis tirotóxica: Burch-Wartofsky, propiltiouracilo × metimazol, betabloqueador, corticoide, iodo e resfriamento ativo.'
                : 'Protocolo urgente de crise tireotóxica: Burch-Wartofsky, propiltiouracil × metimazol, betabloqueador, corticoide, iodo e resfriamento ativo.',
          );
        } else {
          return SmartNextAction(
            label: es ? 'Hipotiroidismo × Mixedema' : 'Hipotireoidismo × Mixedema',
            promptToSend: es
                ? 'Diferencia clínica entre hipotiroidismo subclínico, hipotiroidismo clínico y coma mixedematoso: TSH, T4 libre, diagnóstico y tratamiento de emergencia.'
                : 'Diferença clínica entre hipotireoidismo subclínico, hipotireoidismo clínico e coma mixedematoso: TSH, T4 livre, diagnóstico e tratamento de emergência.',
          );
        }

      // ── 40. Infectologia ───────────────────────────────────────────────────
      case ClinicalTopic.infectologia:
        if (isPlantaoMode) {
          return SmartNextAction(
            label: es ? 'HIV: infecciones oportunistas' : 'HIV: infecções oportunistas',
            promptToSend: es
                ? 'Infecciones oportunistas más frecuentes en HIV según CD4: < 200 (pneumocistis, toxoplasma), < 100 (CMV, MAC) — profilaxis y tratamiento de primera línea.'
                : 'Infecções oportunistas mais frequentes no HIV por CD4: < 200 (pneumocistis, toxoplasma), < 100 (CMV, MAC) — profilaxia e tratamento de primeira linha.',
          );
        } else {
          return SmartNextAction(
            label: es ? 'TARV: primera línea' : 'TARV: primeira linha',
            promptToSend: es
                ? 'Esquema de TARV de primera línea en HIV: 2 ITIAN + 1 INSTI (TDF/FTC + DTG), cuándo iniciar, resistencia primaria y monitorización virológica.'
                : 'Esquema de TARV de primeira linha no HIV: 2 ITRN + 1 INSTI (TDF/FTC + DTG), quando iniciar, resistência primária e monitorização virológica.',
          );
        }

      // ── 41. Hipercalemia ───────────────────────────────────────────────────
      case ClinicalTopic.hipercalemia:
        if (isPlantaoMode) {
          return SmartNextAction(
            label: es ? 'Hipercalemia: protocolo K⁺' : 'Hipercalemia: protocolo K⁺',
            promptToSend: es
                ? 'Protocolo urgente de hipercalemia grave (K⁺ > 6,5): gluconato de calcio IV (estabilizar membrana), insulina + glucosa, salbutamol nebulizado, bicarbonato y diálisis.'
                : 'Protocolo urgente de hipercalemia grave (K⁺ > 6,5): gluconato de cálcio IV (estabilizar membrana), insulina + glicose, salbutamol nebulizado, bicarbonato e diálise.',
          );
        } else {
          return SmartNextAction(
            label: es ? 'ECG e hipercalemia' : 'ECG e hipercalemia',
            promptToSend: es
                ? 'Progresión de alteraciones electrocardiográficas en hipercalemia: onda T picuda, PR prolongado, onda P aplanada, QRS ancho, sine wave y FV.'
                : 'Progressão das alterações eletrocardiográficas na hipercalemia: onda T apiculada, PR alargado, onda P achatada, QRS largo, onda sinus e FV.',
          );
        }

      // ── 42. Delirium ───────────────────────────────────────────────────────
      case ClinicalTopic.delirium:
        if (isPlantaoMode) {
          return SmartNextAction(
            label: es ? 'Delirium: manejo no fármaco' : 'Delirium: manejo não-farmacol.',
            promptToSend: es
                ? 'Medidas no farmacológicas para delirium en UTI: orientación temporal, movilización precoz, ciclos sueño-vigilia, reducción de fármacos anticolin y protocolo HELP.'
                : 'Medidas não-farmacológicas para delirium na UTI: reorientação temporal, mobilização precoce, ciclos sono-vigília, redução de fármacos anticolinérgicos e protocolo HELP.',
          );
        } else {
          return SmartNextAction(
            label: es ? 'Delirium: diagnóstico CAM' : 'Delirium: diagnóstico CAM',
            promptToSend: es
                ? 'Instrumento CAM para diagnóstico de delirium: 4 características (inicio agudo, inatención, pensamiento desorganizado, alteración conciencia), sensibilidad y especificidad.'
                : 'Instrumento CAM para diagnóstico de delirium: 4 características (início agudo, desatenção, pensamento desorganizado, alteração da consciência), sensibilidade e especificidade.',
          );
        }

      // ── 43. Fallback — nenhum tema identificado ────────────────────────────
      case ClinicalTopic.nenhum:
        if (isPlantaoMode) {
          return SmartNextAction(
            label: es ? 'Revisar próximos pasos' : 'Revisar próximos passos',
            promptToSend: es
                ? 'Con base en la discusión anterior, ¿cuáles son los próximos pasos clínicos prioritarios?'
                : 'Com base na discussão anterior, quais são os próximos passos clínicos prioritários?',
          );
        } else {
          return SmartNextAction(
            label: es ? 'Profundizar este tema' : 'Aprofundar este tema',
            promptToSend: es
                ? 'Con base en lo anterior, ¿puedes profundizar en los aspectos más relevantes para la práctica clínica?'
                : 'Com base no anterior, pode aprofundar nos aspectos mais relevantes para a prática clínica?',
          );
        }
    }
  }
}
