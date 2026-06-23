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
  // Build 1558: aceita chatHistory para deduplicação histórico-baseada.
  // ──────────────────────────────────────────────────────────────────────────
  static SmartNextAction build({
    required String lastUserMessage,
    required String lastAiResponse,
    required bool isPlantaoMode,
    required String currentLanguage,
    List<String> chatHistory = const [],   // ← NOVO — lista de textos do chat
  }) {
    // 1. Resolver idioma
    final lang = _resolveLanguage(currentLanguage, lastUserMessage, lastAiResponse);

    // 2. Detectar tema clínico (user message tem prioridade sobre resposta)
    final corpus = '${lastUserMessage.toLowerCase()} ${lastAiResponse.toLowerCase()}';
    final topic = _detectTopic(corpus);

    // 3. Selecionar ação com deduplicação histórico-baseada
    return _selectAction(topic: topic, isPlantaoMode: isPlantaoMode, lang: lang, chatHistory: chatHistory);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // DEDUPLICAÇÃO — _pickAction
  // Build 1558: Varre a lista de opções e retorna a primeira cujo
  // promptToSend (primeiros 60 chars) NÃO aparece no histórico do chat.
  // Fallback: sempre retorna a última opção se todas já foram usadas.
  // ──────────────────────────────────────────────────────────────────────────
  static SmartNextAction _pickAction(
    List<SmartNextAction> options,
    List<String> history,
  ) {
    assert(options.isNotEmpty, '_pickAction: lista de opções não pode ser vazia');
    final histLower = history.map((h) => h.toLowerCase()).toList();
    for (final opt in options) {
      final key = opt.promptToSend.toLowerCase();
      final snippet = key.length > 60 ? key.substring(0, 60) : key;
      final alreadyUsed = histLower.any((h) => h.contains(snippet));
      if (!alreadyUsed) return opt;
    }
    // Todas as opções já aparecem no histórico → retorna a última (mais avançada)
    return options.last;
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
    List<String> chatHistory = const [],   // ← NOVO — passado para _pickAction
  }) {
    final es = lang == 'es';

    switch (topic) {
      // ── 1. SCA / IAM ──────────────────────────────────────────────────────
      // Build 236 fix: Plantão → conduta operacional imediata (ECG + Troponina),
      // NÃO comparação acadêmica IAMCSST × IAMSSST (movida para Modo Estudo).
      case ClinicalTopic.sca:
        if (isPlantaoMode) {
          return _pickAction([
            SmartNextAction(
              label: es ? 'ECG + Troponina urgente' : 'ECG + Troponina urgente',
              promptToSend: es
                  ? 'Paciente con dolor torácico agudo: protocolo de ECG de 12 derivaciones (tiempo puerta-ECG ≤10min), troponina ultrasensible, acceso venoso, monitorización y AAS 300mg.'
                  : 'Paciente com dor torácica aguda: protocolo de ECG de 12 derivações (tempo porta-ECG ≤10min), troponina ultrassensível, acesso venoso, monitorização e AAS 300mg.',
            ),
            SmartNextAction(
              label: es ? 'Dupla antiagregação: doses' : 'Dupla antiagregação: doses',
              promptToSend: es
                  ? 'Protocolo de doble antiagregación en SCA: AAS 300mg ataque + clopidogrel 600mg o ticagrelor 180mg — cuándo preferir cada uno, interacciones y contraindicaciones.'
                  : 'Protocolo de dupla antiagregação no SCA: AAS 300mg ataque + clopidogrel 600mg ou ticagrelor 180mg — quando preferir cada um, interações e contraindicações.',
            ),
            SmartNextAction(
              label: es ? 'Fibrinólisis: criterios' : 'Fibrinólise: critérios',
              promptToSend: es
                  ? 'Criterios y contraindicaciones de fibrinólisis en IAMCSST: ventana de 12h, alteplase vs tenecteplase, contraindicaciones absolutas/relativas y criterios de reperfusión.'
                  : 'Critérios e contraindicações de fibrinólise no IAMCSST: janela de 12h, alteplase vs tenecteplase, contraindicações absolutas/relativas e critérios de reperfusão.',
            ),
            SmartNextAction(
              label: es ? 'Heparina en IAM: esquema' : 'Heparina no IAM: esquema',
              promptToSend: es
                  ? 'Anticoagulación en IAM: HNF versus enoxaparina en IAMCSST e IAMSSST — dosis, ajuste por peso/renal, cuándo suspender y manejo peri-ICP.'
                  : 'Anticoagulação no IAM: HNF versus enoxaparina no IAMCSST e IAMSSST — doses, ajuste por peso/renal, quando suspender e manejo peri-ICP.',
            ),
          ], chatHistory);
        } else {
          return _pickAction([
            SmartNextAction(
              label: es ? 'IAMCSST × IAMSSST' : 'IAMCSST × IAMSSST',
              promptToSend: es
                  ? '¿Cuál es la diferencia en el manejo inicial entre IAMCSST y IAMSSST? Incluya tiempos puerta-balón, antiagregación y fisiopatología de la ruptura de placa.'
                  : 'Qual a diferença no manejo inicial entre IAMCSST e IAMSSST? Inclua tempos porta-balão, antiagregação e fisiopatologia da ruptura de placa.',
            ),
            SmartNextAction(
              label: es ? 'Fisiopatología de la placa' : 'Fisiopatologia da placa',
              promptToSend: es
                  ? 'Explica la fisiopatología de la rotura de placa aterosclerótica en SCA: vulnerabilidad, erosión, trombosis coronaria y papel de la inflamación.'
                  : 'Explique a fisiopatologia da ruptura da placa aterosclerótica no SCA: vulnerabilidade, erosão, trombose coronária e papel da inflamação.',
            ),
            SmartNextAction(
              label: es ? 'Estratificación de riesgo' : 'Estratificação de risco',
              promptToSend: es
                  ? 'Escores de riesgo en SCA: TIMI, GRACE y HEART — variables, puntuación, indicación de cateterismo urgente vs diferido y valor pronóstico.'
                  : 'Escores de risco no SCA: TIMI, GRACE e HEART — variáveis, pontuação, indicação de cateterismo urgente vs diferido e valor prognóstico.',
            ),
            SmartNextAction(
              label: es ? 'Manejo post-IAM: crónico' : 'Manejo pós-IAM: crônico',
              promptToSend: es
                  ? 'Tratamiento a largo plazo post-IAM: betabloqueador, IECA/ARA-II, estatina de alta intensidad, DAPT duración y cuando agregar eplerenona.'
                  : 'Tratamento a longo prazo pós-IAM: betabloqueador, IECA/BRA, estatina de alta intensidade, DAPT duração e quando adicionar eplerenona.',
            ),
          ], chatHistory);
        }

      // ── 2. Sepse ───────────────────────────────────────────────────────────
      case ClinicalTopic.sepse:
        if (isPlantaoMode) {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Vasopressores e doses' : 'Vasopressores e doses',
              promptToSend: es
                  ? '¿Cuál es el esquema de vasopresores en choque séptico? Noradrenalina: dosis de inicio, titulación y cuándo agregar vasopresina.'
                  : 'Qual o esquema de vasopressores no choque séptico? Noradrenalina: dose de início, titulação e quando adicionar vasopressina.',
            ),
            SmartNextAction(
              label: es ? 'Bundle hora 1 sepsis' : 'Bundle hora 1 sepse',
              promptToSend: es
                  ? 'Detalla el bundle de la hora 1 en sepsis: hemocultivos × 2, antibiótico amplio espectro, lactato, cristaloides 30ml/kg y cuándo vasopresores.'
                  : 'Detalhe o bundle da hora 1 na sepse: hemoculturas × 2, antibiótico amplo espectro, lactato, cristaloides 30ml/kg e quando vasopressores.',
            ),
            SmartNextAction(
              label: es ? 'Antibiótico empírico sepsis' : 'Antibiótico empírico sepse',
              promptToSend: es
                  ? 'Esquemas antibióticos empíricos en sepsis según foco: pulmonar (pip-tazo), urinario (ceftriaxona), abdominal (cefepime+metronidazol) y desescalada.'
                  : 'Esquemas antibióticos empíricos na sepse por foco: pulmonar (pip-tazo), urinário (ceftriaxona), abdominal (cefepime+metronidazol) e desescalonamento.',
            ),
            SmartNextAction(
              label: es ? 'Corticoide en choque séptico' : 'Corticoide no choque séptico',
              promptToSend: es
                  ? 'Uso de hidrocortisona en choque séptico refractario: dosis 200mg/día IV continua, criterios de indicación, ADRENAL trial y cuándo suspender.'
                  : 'Uso de hidrocortisona no choque séptico refratário: dose 200mg/dia IV contínua, critérios de indicação, trial ADRENAL e quando suspender.',
            ),
          ], chatHistory);
        } else {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Criterios Sepsis-3' : 'Critérios Sepsis-3',
              promptToSend: es
                  ? 'Explícame los criterios de Sepsis-3: definición de sepsis, choque séptico, qSOFA y SOFA.'
                  : 'Explique os critérios do Sepsis-3: definição de sepse, choque séptico, qSOFA e SOFA.',
            ),
            SmartNextAction(
              label: es ? 'Fisiopatología del choque séptico' : 'Fisiopatologia do choque séptico',
              promptToSend: es
                  ? 'Fisiopatología del choque séptico: vasodilatación, disfunción miocárdica, alteraciones de la microcirculación y disfunción mitocondrial.'
                  : 'Fisiopatologia do choque séptico: vasodilatação, disfunção miocárdica, alterações da microcirculação e disfunção mitocondrial.',
            ),
            SmartNextAction(
              label: es ? 'Lactato: significado clínico' : 'Lactato: significado clínico',
              promptToSend: es
                  ? 'Interpretación del lactato en sepsis: causas de elevación, aclaramiento de lactato como meta terapéutica y diferencia lactato tipo A vs tipo B.'
                  : 'Interpretação do lactato na sepse: causas de elevação, clareamento de lactato como meta terapêutica e diferença lactato tipo A vs tipo B.',
            ),
            SmartNextAction(
              label: es ? 'Manejo post-sepsis: secuelas' : 'Manejo pós-sepse: sequelas',
              promptToSend: es
                  ? 'Síndrome post-sepsis: disfunción cognitiva, debilidad adquirida en UCI, fatiga crónica — prevalencia, fisiopatología y estrategias de rehabilitación.'
                  : 'Síndrome pós-sepse: disfunção cognitiva, fraqueza adquirida na UTI, fadiga crônica — prevalência, fisiopatologia e estratégias de reabilitação.',
            ),
          ], chatHistory);
        }

      // ── 3. Potássio / Hipocalemia ──────────────────────────────────────────
      case ClinicalTopic.potassio:
        if (isPlantaoMode) {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Reposición EV de K⁺' : 'Reposição EV de K⁺',
              promptToSend: es
                  ? 'Protocolo de reposición endovenosa de potasio en hipopotasemia severa: velocidad máxima, dilución y monitorización.'
                  : 'Protocolo de reposição endovenosa de potássio na hipocalemia grave: velocidade máxima, diluição e monitorização.',
            ),
            SmartNextAction(
              label: es ? 'K⁺ oral vs EV: cuándo' : 'K⁺ oral vs EV: quando',
              promptToSend: es
                  ? 'Criterios para reposición oral versus endovenosa de potasio: umbrales de K⁺, capacidad de vía oral, absorción GI y fórmulas de reposición total.'
                  : 'Critérios para reposição oral versus endovenosa de potássio: limiares de K⁺, capacidade de via oral, absorção GI e fórmulas de reposição total.',
            ),
            SmartNextAction(
              label: es ? 'Causas de hipopotasemia' : 'Causas de hipocalemia',
              promptToSend: es
                  ? 'Diagnóstico diferencial de hipopotasemia: pérdidas renales (diuréticos, hiperaldosteronismo), pérdidas GI (vómitos, diarrea), redistribución (insulina, alcalosis).'
                  : 'Diagnóstico diferencial de hipocalemia: perdas renais (diuréticos, hiperaldosteronismo), perdas GI (vômitos, diarreia), redistribuição (insulina, alcalose).',
            ),
          ], chatHistory);
        } else {
          return _pickAction([
            SmartNextAction(
              label: es ? 'ECG e hipopotasemia' : 'ECG e hipocalemia',
              promptToSend: es
                  ? 'Describe las alteraciones electrocardiográficas de la hipopotasemia: onda U, aplanamiento de T, prolongación QT y riesgo arrítmico.'
                  : 'Descreva as alterações eletrocardiográficas da hipocalemia: onda U, achatamento de T, prolongamento de QT e risco arrítmico.',
            ),
            SmartNextAction(
              label: es ? 'Hipopotasemia y arritmias' : 'Hipocalemia e arritmias',
              promptToSend: es
                  ? 'Mecanismo por el que la hipopotasemia predispone a arritmias: reducción del umbral de fibrilación ventricular, interacción con digitálicos y factores de riesgo adicionales.'
                  : 'Mecanismo pelo qual a hipocalemia predispõe a arritmias: redução do limiar de fibrilação ventricular, interação com digitálicos e fatores de risco adicionais.',
            ),
            SmartNextAction(
              label: es ? 'Aldosteronismo primario' : 'Aldosteronismo primário',
              promptToSend: es
                  ? 'Hiperaldosteronismo primario como causa de hipopotasemia crónica: fisiopatología, relación aldosterona/renina, adenoma de Conn y tratamiento quirúrgico vs médico.'
                  : 'Hiperaldosteronismo primário como causa de hipocalemia crônica: fisiopatologia, relação aldosterona/renina, adenoma de Conn e tratamento cirúrgico vs médico.',
            ),
          ], chatHistory);
        }

      // ── 4. Antidepressivos / ISRS ──────────────────────────────────────────
      case ClinicalTopic.antidepressivos:
        if (isPlantaoMode) {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Síndrome serotoninérgico' : 'Síndrome serotoninérgica',
              promptToSend: es
                  ? 'Síndrome serotoninérgico: triada clínica, criterios de Hunter, manejo agudo con ciproheptadina y cuándo intubar.'
                  : 'Síndrome serotoninérgica: tríade clínica, critérios de Hunter, manejo agudo com ciproeptadina e quando intubar.',
            ),
            SmartNextAction(
              label: es ? 'Interacciones ISRS urgentes' : 'Interações ISRS urgentes',
              promptToSend: es
                  ? 'Interacciones farmacológicas graves con ISRS/IRSN: tramadol, linezolida, metileno azul, triptanes y IMAO — mecanismo y manejo en urgencias.'
                  : 'Interações farmacológicas graves com ISRS/IRSN: tramadol, linezolida, azul de metileno, triptanos e IMAO — mecanismo e manejo na emergência.',
            ),
            SmartNextAction(
              label: es ? 'Sobredosis ISRS: manejo' : 'Superdosagem ISRS: manejo',
              promptToSend: es
                  ? 'Manejo de sobredosis por ISRS: descontaminación GI, monitorización de QTc, benzodiazepinas para convulsiones, síndrome serotoninérgico y criterios de UCI.'
                  : 'Manejo de superdosagem por ISRS: descontaminação GI, monitorização de QTc, benzodiazepínicos para convulsões, síndrome serotoninérgica e critérios de UTI.',
            ),
          ], chatHistory);
        } else {
          return _pickAction([
            SmartNextAction(
              label: es ? 'ISRS × IRSN: comparativo' : 'ISRS × IRSN: comparativo',
              promptToSend: es
                  ? 'Compara ISRS versus IRSN en mecanismo de acción, perfil de efectos adversos, interacciones y elección clínica.'
                  : 'Compare ISRS versus IRSN em mecanismo de ação, perfil de efeitos adversos, interações e escolha clínica.',
            ),
            SmartNextAction(
              label: es ? 'Inicio y titulación: ISRS' : 'Início e titulação: ISRS',
              promptToSend: es
                  ? 'Protocolos de inicio y titulación de ISRS en depresión mayor: fluoxetina, sertralina, escitalopram — dosis iniciales, escalada, tiempo hasta efecto y manejo de efectos adversos.'
                  : 'Protocolos de início e titulação de ISRS na depressão maior: fluoxetina, sertralina, escitalopram — doses iniciais, escalonamento, tempo até efeito e manejo de efeitos adversos.',
            ),
            SmartNextAction(
              label: es ? 'Depresión resistente: alternativas' : 'Depressão resistente: alternativas',
              promptToSend: es
                  ? 'Estrategias para depresión resistente al tratamiento: potenciación con litio, antipsicóticos atípicos, ketamina IV, esketamina intranasal y ECT.'
                  : 'Estratégias para depressão resistente ao tratamento: potenciação com lítio, antipsicóticos atípicos, cetamina IV, escetamina intranasal e ECT.',
            ),
          ], chatHistory);
        }

      // ── 5. Parkinson ───────────────────────────────────────────────────────
      case ClinicalTopic.parkinson:
        if (isPlantaoMode) {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Crisis dopaminérgica' : 'Crise dopaminérgica',
              promptToSend: es
                  ? 'Manejo de la crisis en Parkinson avanzado: síndrome de abstinencia dopaminérgica, fiebre, rigidez y protocolo de emergencia.'
                  : 'Manejo da crise no Parkinson avançado: síndrome de abstinência dopaminérgica, febre, rigidez e protocolo de emergência.',
            ),
            SmartNextAction(
              label: es ? 'Fármacos contraindicados: Parkinson' : 'Fármacos contraindicados: Parkinson',
              promptToSend: es
                  ? 'Fármacos contraindicados en Parkinson: metoclopramida, haloperidol, droperidol, prometazina — riesgo de empeoramiento, alternativas seguras antieméticas y antipsicóticos.'
                  : 'Fármacos contraindicados no Parkinson: metoclopramida, haloperidol, droperidol, prometazina — risco de piora, alternativas seguras antieméticas e antipsicóticos.',
            ),
            SmartNextAction(
              label: es ? 'Parkinson: perioperatorio' : 'Parkinson: perioperatório',
              promptToSend: es
                  ? 'Manejo perioperatorio del Parkinson: no suspender levodopa, continuar horarios fijos, sonda nasogástrica si necesario, evitar antagonistas dopaminérgicos y despertar tardío.'
                  : 'Manejo perioperatório do Parkinson: não suspender levodopa, manter horários fixos, sonda nasogástrica se necessário, evitar antagonistas dopaminérgicos e despertar tardio.',
            ),
          ], chatHistory);
        } else {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Levodopa × Agonistas' : 'Levodopa × Agonistas',
              promptToSend: es
                  ? 'Compara levodopa versus agonistas dopaminérgicos en Parkinson: eficacia, discinesias, fenómeno on-off y perfil de paciente ideal para cada uno.'
                  : 'Compare levodopa versus agonistas dopaminérgicos no Parkinson: eficácia, discinesias, fenômeno on-off e perfil de paciente ideal para cada um.',
            ),
            SmartNextAction(
              label: es ? 'Estadios de Hoehn y Yahr' : 'Estadios de Hoehn e Yahr',
              promptToSend: es
                  ? 'Escala de Hoehn y Yahr en Parkinson: estadios 1-5, correlato funcional, progresión esperada y cómo guía decisiones terapéuticas y cirugía DBS.'
                  : 'Escala de Hoehn e Yahr no Parkinson: estágios 1-5, correlato funcional, progressão esperada e como guia decisões terapêuticas e cirurgia DBS.',
            ),
            SmartNextAction(
              label: es ? 'DBS: estimulación cerebral' : 'DBS: estimulação cerebral',
              promptToSend: es
                  ? 'Estimulación cerebral profunda (DBS) en Parkinson: criterios de selección, núcleos-diana (NST vs GPi), eficacia, riesgos y impacto en calidad de vida.'
                  : 'Estimulação cerebral profunda (DBS) no Parkinson: critérios de seleção, núcleos-alvo (NST vs GPi), eficácia, riscos e impacto na qualidade de vida.',
            ),
          ], chatHistory);
        }

      // ── 6. Anticoagulação ──────────────────────────────────────────────────
      case ClinicalTopic.anticoagulacao:
        if (isPlantaoMode) {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Revertir anticoagulación' : 'Reverter anticoagulação',
              promptToSend: es
                  ? 'Protocolo urgente de reversión de anticoagulación: warfarina (vitamina K + CCP), heparina (protamina), DOACs (idarucizumab, andexanet).'
                  : 'Protocolo urgente de reversão de anticoagulação: varfarina (vitamina K + CCP), heparina (protamina), DOACs (idarucizumab, andexanet alfa).',
            ),
            SmartNextAction(
              label: es ? 'Sangrado bajo DOAC: urgente' : 'Sangramento sob DOAC: urgente',
              promptToSend: es
                  ? 'Manejo urgente de sangrado mayor bajo DOAC: idarucizumab para dabigatrán, andexanet alfa para Xa-inhibidores, CCP de 4 factores como alternativa y criterios de transfusión.'
                  : 'Manejo urgente de sangramento maior sob DOAC: idarucizumab para dabigatrana, andexanet alfa para inibidores de Xa, CCP de 4 fatores como alternativa e critérios de transfusão.',
            ),
            SmartNextAction(
              label: es ? 'Puente heparina: indicaciones' : 'Ponte heparina: indicações',
              promptToSend: es
                  ? 'Anticoagulación puente peri-procedimiento: cuándo indicar heparina bridge, riesgo tromboembólico vs hemorrágico, esquemas y suspensión de DOACs pre-cirugía.'
                  : 'Anticoagulação ponte peri-procedimento: quando indicar heparina bridge, risco tromboembólico vs hemorrágico, esquemas e suspensão de DOACs pré-cirurgia.',
            ),
          ], chatHistory);
        } else {
          return _pickAction([
            SmartNextAction(
              label: es ? 'ACO × DOAC × Heparina' : 'ACO × DOAC × Heparina',
              promptToSend: es
                  ? 'Compara anticoagulantes clásicos (warfarina, heparina) versus DOACs: mecanismo, monitorización, reversión y elección por indicación.'
                  : 'Compare anticoagulantes clássicos (varfarina, heparina) versus DOACs: mecanismo, monitorização, reversão e escolha por indicação.',
            ),
            SmartNextAction(
              label: es ? 'FA y anticoagulación: CHA₂DS₂' : 'FA e anticoagulação: CHA₂DS₂',
              promptToSend: es
                  ? 'Score CHA₂DS₂-VASc para indicación de anticoagulación en FA: variables, umbral de inicio (≥2 H, ≥1 M), elección de DOAC vs warfarina y score HAS-BLED.'
                  : 'Escore CHA₂DS₂-VASc para indicação de anticoagulação na FA: variáveis, limiar de início (≥2 H, ≥1 M), escolha de DOAC vs varfarina e escore HAS-BLED.',
            ),
            SmartNextAction(
              label: es ? 'Heparina: tipos y mecanismo' : 'Heparina: tipos e mecanismo',
              promptToSend: es
                  ? 'Diferencia HNF versus HBPM: mecanismo (anti-IIa vs anti-Xa), monitorización (TTPa vs anti-Xa), reversión con protamina, ajuste renal y HIT.'
                  : 'Diferença HNF versus HBPM: mecanismo (anti-IIa vs anti-Xa), monitorização (TTPa vs anti-Xa), reversão com protamina, ajuste renal e TITH.',
            ),
          ], chatHistory);
        }

      // ── 7. Arritmias ───────────────────────────────────────────────────────
      case ClinicalTopic.arritmia:
        if (isPlantaoMode) {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Cardioversión: dosis' : 'Cardioversão: doses',
              promptToSend: es
                  ? 'Protocolo de cardioversión eléctrica sincronizada: joules para FA, flutter, TPSV y TV estable. Sedación previa.'
                  : 'Protocolo de cardioversão elétrica sincronizada: joules para FA, flutter, TPSV e TV estável. Sedação prévia.',
            ),
            SmartNextAction(
              label: es ? 'Amiodarona IV: protocolo' : 'Amiodarona IV: protocolo',
              promptToSend: es
                  ? 'Uso de amiodarona IV en urgencias: dosis de carga 300mg en 30min, mantenimiento 900mg/24h, indicaciones (TV, FA con respuesta ventricular rápida) y efectos adversos agudos.'
                  : 'Uso de amiodarona IV na emergência: dose de ataque 300mg em 30min, manutenção 900mg/24h, indicações (TV, FA com resposta ventricular rápida) e efeitos adversos agudos.',
            ),
            SmartNextAction(
              label: es ? 'FV/TVSP: algoritmo RCP' : 'FV/TVSP: algoritmo RCP',
              promptToSend: es
                  ? 'Algoritmo ACLS para fibrilación ventricular y TV sin pulso: desfibrilación 200J (bifásico), RCP 2min, adrenalina 1mg IV cada 3-5min y amiodarona 300mg.'
                  : 'Algoritmo ACLS para fibrilação ventricular e TV sem pulso: desfibrilação 200J (bifásico), RCP 2min, adrenalina 1mg IV cada 3-5min e amiodarona 300mg.',
            ),
            SmartNextAction(
              label: es ? 'Bradicardia sintomática' : 'Bradicardia sintomática',
              promptToSend: es
                  ? 'Manejo de bradicardia sintomática: atropina 0,5mg IV (repetir hasta 3mg), marcapaso transcutáneo de urgencia, dopamina/adrenalina en infusión y causas reversibles.'
                  : 'Manejo de bradicardia sintomática: atropina 0,5mg IV (repetir até 3mg), marcapasso transcutâneo de urgência, dopamina/adrenalina em infusão e causas reversíveis.',
            ),
          ], chatHistory);
        } else {
          return _pickAction([
            SmartNextAction(
              label: es ? 'FA: ritmo × frecuencia' : 'FA: ritmo × frequência',
              promptToSend: es
                  ? 'Estrategia de control de ritmo versus control de frecuencia en FA: indicaciones, fármacos de elección y evidencia AFFIRM.'
                  : 'Estratégia de controle de ritmo versus controle de frequência na FA: indicações, fármacos de escolha e evidência AFFIRM.',
            ),
            SmartNextAction(
              label: es ? 'Mecanismos de arritmias' : 'Mecanismos das arritmias',
              promptToSend: es
                  ? 'Mecanismos electrofisiológicos de las arritmias: automatismo anormal, actividad desencadenada (posdespolarizaciones) y reentrada — bases del tratamiento.'
                  : 'Mecanismos eletrofisiológicos das arritmias: automatismo anormal, atividade deflagrada (pós-despolarizações) e reentrada — bases do tratamento.',
            ),
            SmartNextAction(
              label: es ? 'Ablación y marcapaso: indicaciones' : 'Ablação e marcapasso: indicações',
              promptToSend: es
                  ? 'Indicaciones de ablación por catéter (TPSV, flutter, FA paroxística) versus implante de marcapaso (BAV 3°, BAV 2° Mobitz II) y criterios de desfibrilador ICD.'
                  : 'Indicações de ablação por cateter (TPSV, flutter, FA paroxística) versus implante de marcapasso (BAV 3°, BAV 2° Mobitz II) e critérios de CDI.',
            ),
          ], chatHistory);
        }

      // ── 8. TEP ─────────────────────────────────────────────────────────────
      case ClinicalTopic.tep:
        if (isPlantaoMode) {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Trombólisis en TEP' : 'Trombólise no TEP',
              promptToSend: es
                  ? 'Indicaciones absolutas de trombólisis sistémica en TEP masivo: alteplase 100mg IV, contraindicaciones absolutas y rescate con embolectomía.'
                  : 'Indicações absolutas de trombólise sistêmica no TEP maciço: alteplase 100mg IV, contraindicações absolutas e resgate com embolectomia.',
            ),
            SmartNextAction(
              label: es ? 'Anticoagular TEP: cuándo' : 'Anticoagular TEP: quando',
              promptToSend: es
                  ? 'Inicio de anticoagulación en TEP: heparina no fraccionada vs HBPM vs DOACs (rivaroxabán, apixabán) — dosis iniciales, duración mínima y transición a anticoagulación oral.'
                  : 'Início da anticoagulação no TEP: heparina não fracionada vs HBPM vs DOACs (rivaroxabana, apixabana) — doses iniciais, duração mínima e transição para anticoagulação oral.',
            ),
            SmartNextAction(
              label: es ? 'TEP submasivo: estrategia' : 'TEP submaciço: estratégia',
              promptToSend: es
                  ? 'Manejo del TEP submasivo (disfunción VD sin hipotensión): escala PESI, trombolisis a dosis reducida, EKOS, ecocardiografía y criterios de monitorización en UCI.'
                  : 'Manejo do TEP submaciço (disfunção VD sem hipotensão): escore PESI, trombólise em dose reduzida, EKOS, ecocardiografia e critérios de monitorização em UTI.',
            ),
          ], chatHistory);
        } else {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Escore de Wells' : 'Escore de Wells',
              promptToSend: es
                  ? 'Describe el escore de Wells para TEP: variables, puntuación, estratificación de riesgo y algoritmo diagnóstico con D-dímero y angiotomografía.'
                  : 'Descreva o escore de Wells para TEP: variáveis, pontuação, estratificação de risco e algoritmo diagnóstico com D-dímero e angiotomografia.',
            ),
            SmartNextAction(
              label: es ? 'TEP: fisiopatología VD' : 'TEP: fisiopatologia VD',
              promptToSend: es
                  ? 'Fisiopatología del TEP masivo: obstrucción vascular, hipertensión pulmonar aguda, disfunción y fallo del VD, interdependencia ventricular y colapso hemodinámico.'
                  : 'Fisiopatologia do TEP maciço: obstrução vascular, hipertensão pulmonar aguda, disfunção e falência do VD, interdependência ventricular e colapso hemodinâmico.',
            ),
            SmartNextAction(
              label: es ? 'Duración anticoagulación TEP' : 'Duração anticoagulação TEP',
              promptToSend: es
                  ? 'Duración óptima de anticoagulación en TEP: factores provocados (3 meses) vs no provocados (≥6 meses vs indefinido), TEP recurrente, cáncer y score HERDOO2.'
                  : 'Duração ótima de anticoagulação no TEP: fatores provocados (3 meses) vs não provocados (≥6 meses vs indefinido), TEP recorrente, câncer e escore HERDOO2.',
            ),
          ], chatHistory);
        }

      // ── 9. Asma ────────────────────────────────────────────────────────────
      case ClinicalTopic.asma:
        if (isPlantaoMode) {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Asma grave: protocolo' : 'Asma grave: protocolo',
              promptToSend: es
                  ? 'Protocolo de asma grave en urgencias: salbutamol nebulizado dosis-respuesta, corticoide IV, ipratropio, magnesio IV y criterios de intubación.'
                  : 'Protocolo de asma grave na emergência: salbutamol nebulizado dose-resposta, corticoide IV, ipratrópio, magnésio IV e critérios de intubação.',
            ),
            SmartNextAction(
              label: es ? 'Magnesio IV: dosis en asma' : 'Magnésio IV: dose na asma',
              promptToSend: es
                  ? 'Uso de sulfato de magnesio IV en asma grave: mecanismo broncodilatador, dosis 2g en 20min, evidencia (3MgSO4 trial), contraindicaciones y monitorización de toxicidad.'
                  : 'Uso de sulfato de magnésio IV na asma grave: mecanismo broncodilatador, dose 2g em 20min, evidência (trial 3MgSO4), contraindicações e monitorização de toxicidade.',
            ),
            SmartNextAction(
              label: es ? 'Intubación en asma: peligros' : 'Intubação na asma: perigos',
              promptToSend: es
                  ? 'Intubación en asma grave: peligros del broncoespasmo post-intubación, ketamina como inductora, parámetros ventilatorios (FR baja, Ti/Te 1:3-1:4) y auto-PEEP.'
                  : 'Intubação na asma grave: perigos do broncoespasmo pós-intubação, cetamina como indutora, parâmetros ventilatórios (FR baixa, Ti/Te 1:3-1:4) e auto-PEEP.',
            ),
          ], chatHistory);
        } else {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Asma × EPOC diferencial' : 'Asma × DPOC diferencial',
              promptToSend: es
                  ? 'Diferencia clínica, funcional e histológica entre asma y EPOC: reversibilidad, eosinófilos, prueba broncodilatadora y síndrome de solapamiento.'
                  : 'Diferença clínica, funcional e histológica entre asma e DPOC: reversibilidade, eosinófilos, prova broncodilatadora e síndrome de sobreposição.',
            ),
            SmartNextAction(
              label: es ? 'Escalonamiento GINA: asma' : 'Escalonamento GINA: asma',
              promptToSend: es
                  ? 'Tratamiento escalonado GINA 2024 en asma: degraus 1-5, ICS-formoterol como rescate, biológicos (mepolizumab, dupilumab) y cuándo referir al especialista.'
                  : 'Tratamento escalonado GINA 2024 na asma: degraus 1-5, ICS-formoterol como resgate, biológicos (mepolizumab, dupilumab) e quando referenciar ao especialista.',
            ),
            SmartNextAction(
              label: es ? 'Asma eosinofílica: biológicos' : 'Asma eosinofílica: biológicos',
              promptToSend: es
                  ? 'Biológicos en asma eosinofílica grave: mepolizumab, benralizumab, reslizumab (anti-IL-5), dupilumab (anti-IL-4/13) — criterios de elegibilidad, respuesta y monitorización.'
                  : 'Biológicos na asma eosinofílica grave: mepolizumabe, benralizumabe, reslizumabe (anti-IL-5), dupilumabe (anti-IL-4/13) — critérios de elegibilidade, resposta e monitorização.',
            ),
          ], chatHistory);
        }

      // ── 10. Pneumonia ──────────────────────────────────────────────────────
      case ClinicalTopic.pneumonia:
        if (isPlantaoMode) {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Antibiótico NAC: escalar' : 'Antibiótico NAC: escalar',
              promptToSend: es
                  ? 'Escalada antibiótica en neumonía adquirida en la comunidad: ambulatorio, hospitalizado sin UCI, UCI grave. Duración de tratamiento.'
                  : 'Escalonamento antibiótico na pneumonia adquirida na comunidade: ambulatorial, internado sem UTI, UTI grave. Duração do tratamento.',
            ),
            SmartNextAction(
              label: es ? 'HAP/VAP: antibiótico' : 'HAP/PAV: antibiótico',
              promptToSend: es
                  ? 'Tratamiento antibiótico en neumonía nosocomial (HAP) y asociada a ventilador (VAP): factores de riesgo para multirresistentes, pip-tazo vs cefepime vs meropenem y duración.'
                  : 'Tratamento antibiótico na pneumonia nosocomial (PAH) e associada à ventilação (PAV): fatores de risco para multirresistentes, pip-tazo vs cefepime vs meropenem e duração.',
            ),
            SmartNextAction(
              label: es ? 'Corticoide en NAC grave' : 'Corticoide na NAC grave',
              promptToSend: es
                  ? 'Uso de corticoide en neumonía grave: dexametasona 6mg/día × 5 días (CAPE COD trial), criterios de indicación, riesgo en inmunosuprimidos y beneficio en neumonía gripal.'
                  : 'Uso de corticoide na pneumonia grave: dexametasona 6mg/dia × 5 dias (trial CAPE COD), critérios de indicação, risco em imunossuprimidos e benefício na pneumonia gripal.',
            ),
          ], chatHistory);
        } else {
          return _pickAction([
            SmartNextAction(
              label: es ? 'CURB-65 × PSI' : 'CURB-65 × PSI',
              promptToSend: es
                  ? 'Compara CURB-65 versus PSI/PORT en neumonía: variables, puntuación, decisión de hospitalización y limitaciones de cada escore.'
                  : 'Compare CURB-65 versus PSI/PORT na pneumonia: variáveis, pontuação, decisão de internação e limitações de cada escore.',
            ),
            SmartNextAction(
              label: es ? 'Neumonía atípica: agentes' : 'Pneumonia atípica: agentes',
              promptToSend: es
                  ? 'Neumonía atípica: Mycoplasma, Chlamydophila, Legionella — presentación clínica, diagnóstico (antigenuria, PCR), tratamiento con macrólidos o fluoroquinolonas y epidemiología.'
                  : 'Pneumonia atípica: Mycoplasma, Chlamydophila, Legionella — apresentação clínica, diagnóstico (antigenúria, PCR), tratamento com macrolídeos ou fluoroquinolonas e epidemiologia.',
            ),
            SmartNextAction(
              label: es ? 'Derrame paraneumónico' : 'Derrame paraneumônico',
              promptToSend: es
                  ? 'Manejo del derrame paraneumónico: criterios de drenaje (Light, pH < 7,2, glucosa < 60), técnica de toracocentesis diagnóstica, empiema y fibrinolíticos intrapleurales.'
                  : 'Manejo do derrame parapneumônico: critérios de drenagem (Light, pH < 7,2, glicose < 60), técnica de toracocentese diagnóstica, empiema e fibrinolíticos intrapleurais.',
            ),
          ], chatHistory);
        }

      // ── 11. Diabetes / DKA / HHS ───────────────────────────────────────────
      case ClinicalTopic.diabetes:
        if (isPlantaoMode) {
          return _pickAction([
            SmartNextAction(
              label: es ? 'CAD: insulina e K⁺' : 'CAD: insulina e K⁺',
              promptToSend: es
                  ? 'Protocolo de insulinoterapia en cetoacidosis diabética: velocidad de infusión, cuándo iniciar, monitorización de K⁺ y criterios de resolución.'
                  : 'Protocolo de insulinoterapia na cetoacidose diabética: velocidade de infusão, quando iniciar, monitorização de K⁺ e critérios de resolução.',
            ),
            SmartNextAction(
              label: es ? 'Hipoglucemia grave: manejo' : 'Hipoglicemia grave: manejo',
              promptToSend: es
                  ? 'Manejo urgente de hipoglucemia grave: glucagón 1mg IM/SC, dextrosa 50% IV (25-50mL), regla 15-15 para leve-moderada y causas a investigar (sulfonilureia, insulina).'
                  : 'Manejo urgente de hipoglicemia grave: glucagon 1mg IM/SC, glicose 50% IV (25-50mL), regra 15-15 para leve-moderada e causas a investigar (sulfonilureia, insulina).',
            ),
            SmartNextAction(
              label: es ? 'Insulina hospitalar: protocolo' : 'Insulina hospitalar: protocolo',
              promptToSend: es
                  ? 'Protocolo de insulinoterapia hospitalar: meta glicêmica 140-180mg/dL em UTI (140-200 em enfermaria), insulina basal-bolus, correções e ajuste diário.'
                  : 'Protocolo de insulinoterapia hospitalar: meta glicêmica 140-180mg/dL em UTI (140-200 na enfermaria), insulina basal-bolus, correções e ajuste diário.',
            ),
          ], chatHistory);
        } else {
          return _pickAction([
            SmartNextAction(
              label: es ? 'CAD × HHS: diferencial' : 'CAD × HHS: diferencial',
              promptToSend: es
                  ? 'Diferencias fisiopatológicas y clínicas entre cetoacidosis diabética y estado hiperosmolar hiperglucémico: fisiopatología, laboratorio, manejo.'
                  : 'Diferenças fisiopatológicas e clínicas entre cetoacidose diabética e estado hiperosmolar hiperglicêmico: fisiopatologia, laboratório, manejo.',
            ),
            SmartNextAction(
              label: es ? 'Antidiabéticos: clases y mecanismo' : 'Antidiabéticos: classes e mecanismo',
              promptToSend: es
                  ? 'Mecanismos de acción de los antidiabéticos orales e inyectables: metformina, SGLT2i, GLP-1 RA, iDPP-4, sulfonilureas — eficacia, efectos CV/renales y elección por perfil.'
                  : 'Mecanismos de ação dos antidiabéticos orais e injetáveis: metformina, iSGLT2, aGLP-1, iDPP-4, sulfonilureias — eficácia, efeitos CV/renais e escolha por perfil.',
            ),
            SmartNextAction(
              label: es ? 'Diabetes y enfermedad CV' : 'Diabetes e doença CV',
              promptToSend: es
                  ? 'Manejo del paciente diabético con alto riesgo cardiovascular: evidencia EMPA-REG, LEADER, CREDENCE — cuándo preferir SGLT2i vs GLP-1 RA y metas de HbA1c.'
                  : 'Manejo do paciente diabético com alto risco cardiovascular: evidência EMPA-REG, LEADER, CREDENCE — quando preferir iSGLT2 vs aGLP-1 e metas de HbA1c.',
            ),
          ], chatHistory);
        }

      // ── 12. Renal / IRA ────────────────────────────────────────────────────
      case ClinicalTopic.renal:
        if (isPlantaoMode) {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Indicaciones de diálisis' : 'Indicações de diálise',
              promptToSend: es
                  ? 'Indicaciones urgentes de terapia de reemplazo renal en IRA: AEIOU mnemónico (acidosis, electrolitos, intoxicación, sobrecarga, uremia).'
                  : 'Indicações urgentes de terapia renal substitutiva na IRA: mnemônico AEIOU (acidose, eletrólitos, intoxicação, sobrecarga volêmica, uremia).',
            ),
            SmartNextAction(
              label: es ? 'Nefrotóxicos: prevenir IRA' : 'Nefrotóxicos: prevenir IRA',
              promptToSend: es
                  ? 'Prevención de IRA por nefrotóxicos: ajuste de dosis en insuficiencia renal (aminoglucósidos, vancomicina, AINE), hidratación pre-contraste, suspensión de IECA/BRA peri-procedimiento.'
                  : 'Prevenção de IRA por nefrotóxicos: ajuste de dose na insuficiência renal (aminoglicosídeos, vancomicina, AINE), hidratação pré-contraste, suspensão de IECA/BRA peri-procedimento.',
            ),
            SmartNextAction(
              label: es ? 'IRA × IRS: diferencial clínico' : 'IRA × DRC: diferencial clínico',
              promptToSend: es
                  ? 'Diferenciación clínica entre IRA sobre DRC: tamaño renal, ecogenicidad, anemia crónica, calcio-fósforo, paratohormona y urea elevada desproporcionalmente.'
                  : 'Diferenciação clínica entre IRA sobre DRC: tamanho renal, ecogenicidade, anemia crônica, cálcio-fósforo, paratormônio e ureia elevada desproporcionalmente.',
            ),
          ], chatHistory);
        } else {
          return _pickAction([
            SmartNextAction(
              label: es ? 'KDIGO IRA: estadios' : 'KDIGO IRA: estágios',
              promptToSend: es
                  ? 'Criterios KDIGO para lesión renal aguda: estadios 1-3 por creatinina y diuresis, fisiopatología prerrenal vs intrínseca vs posrenal.'
                  : 'Critérios KDIGO para lesão renal aguda: estágios 1-3 por creatinina e diurese, fisiopatologia pré-renal vs intrínseca vs pós-renal.',
            ),
            SmartNextAction(
              label: es ? 'Síndrome nefrótico × nefrítico' : 'Síndrome nefrótico × nefrítico',
              promptToSend: es
                  ? 'Diferencia fisiopatológica y clínica entre síndrome nefrótico (proteinuria masiva, edema, hipoalbuminemia) y nefrítico (hematuria, HTA, cilindros hemáticos).'
                  : 'Diferença fisiopatológica e clínica entre síndrome nefrótico (proteinúria maciça, edema, hipoalbuminemia) e nefrítico (hematúria, HTA, cilindros hemáticos).',
            ),
            SmartNextAction(
              label: es ? 'DRC: manejo crónico' : 'DRC: manejo crônico',
              promptToSend: es
                  ? 'Manejo crónico de la DRC: control de PA (< 130/80), IECA/BRA en proteinúria, SGLT2i (dapagliflozina), corrección de anemia (EPO), y cuándo derivar a nefrología.'
                  : 'Manejo crônico da DRC: controle de PA (< 130/80), IECA/BRA na proteinúria, iSGLT2 (dapagliflozina), correção de anemia (EPO), e quando encaminhar à nefrologia.',
            ),
          ], chatHistory);
        }

      // ── 13. AVC ────────────────────────────────────────────────────────────
      case ClinicalTopic.avc:
        if (isPlantaoMode) {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Trombólisis: criterios' : 'Trombólise: critérios',
              promptToSend: es
                  ? 'Criterios de inclusión y exclusión para trombólisis IV con alteplase en ACV isquémico: ventana, NIHSS, PA máxima y contraindicaciones absolutas.'
                  : 'Critérios de inclusão e exclusão para trombólise IV com alteplase no AVC isquêmico: janela, NIHSS, PA máxima e contraindicações absolutas.',
            ),
            SmartNextAction(
              label: es ? 'Control PA en ACV agudo' : 'Controle PA no AVC agudo',
              promptToSend: es
                  ? 'Manejo de la presión arterial en ACV agudo: isquémico (no tratar < 220/120 salvo trombolisis), hemorrágico (meta < 140mmHg), fármacos IV de elección y monitorización.'
                  : 'Manejo da pressão arterial no AVC agudo: isquêmico (não tratar < 220/120 salvo trombólise), hemorrágico (meta < 140mmHg), fármacos IV de escolha e monitorização.',
            ),
            SmartNextAction(
              label: es ? 'Trombectomía mecánica: criterios' : 'Trombectomia mecânica: critérios',
              promptToSend: es
                  ? 'Criterios de trombectomía mecánica en ACV isquémico: oclusión de gran vaso, NIHSS ≥ 6, ASPECTS ≥ 6, ventana de 24h con imagen perfusión y evidence DAWN/DEFUSE-3.'
                  : 'Critérios de trombectomia mecânica no AVC isquêmico: oclusão de grande vaso, NIHSS ≥ 6, ASPECTS ≥ 6, janela de 24h com imagem perfusão e evidência DAWN/DEFUSE-3.',
            ),
            SmartNextAction(
              label: es ? 'ACV hemorrágico: manejo' : 'AVC hemorrágico: manejo',
              promptToSend: es
                  ? 'Manejo del hematoma intracerebral: reversión anticoagulación, PA < 140mmHg, cirugía (criterios STICH), monitoreo de PIC e hidrocefalia obstructiva.'
                  : 'Manejo do hematoma intracerebral: reversão anticoagulação, PA < 140mmHg, cirurgia (critérios STICH), monitoramento de PIC e hidrocefalia obstrutiva.',
            ),
          ], chatHistory);
        } else {
          return _pickAction([
            SmartNextAction(
              label: es ? 'ACV isquémico × hemorrágico' : 'AVC isquêmico × hemorrágico',
              promptToSend: es
                  ? 'Diferencias clínicas y de imagen entre ACV isquémico y hemorrágico: presentación, TC sin contraste, manejo inicial diferencial.'
                  : 'Diferenças clínicas e de imagem entre AVC isquêmico e hemorrágico: apresentação, TC sem contraste, manejo inicial diferencial.',
            ),
            SmartNextAction(
              label: es ? 'Territorios vasculares cerebrales' : 'Territórios vasculares cerebrais',
              promptToSend: es
                  ? 'Síndromes vasculares cerebrales: ACA (paresia miembro inferior), ACM (afasia, hemiparesia braquiocefálica), ACP (hemianopsia) y territorio posterior (PICA, AICA).'
                  : 'Síndromes vasculares cerebrais: ACA (paresia membro inferior), ACM (afasia, hemiparesia braquiocefálica), ACP (hemianopsia) e território posterior (PICA, AICA).',
            ),
            SmartNextAction(
              label: es ? 'Prevención secundaria ACV' : 'Prevenção secundária AVC',
              promptToSend: es
                  ? 'Prevención secundaria del ACV isquémico: antiagregación (aspirina, clopidogrel, DAPT inicial), estatina alta intensidad, anticoagulación en FA y control de factores de riesgo.'
                  : 'Prevenção secundária do AVC isquêmico: antiagregação (aspirina, clopidogrel, DAPT inicial), estatina alta intensidade, anticoagulação na FA e controle de fatores de risco.',
            ),
          ], chatHistory);
        }

      // ── 14. Hipertensão ────────────────────────────────────────────────────
      case ClinicalTopic.hipertensao:
        if (isPlantaoMode) {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Emergencia × urgencia HTA' : 'Emergência × urgência HAS',
              promptToSend: es
                  ? 'Diferencia emergencia versus urgencia hipertensiva: definición, ejemplos de daño de órgano, fármaco IV de elección para cada situación.'
                  : 'Diferença emergência versus urgência hipertensiva: definição, exemplos de lesão de órgão-alvo, fármaco IV de escolha para cada situação.',
            ),
            SmartNextAction(
              label: es ? 'Nitroprussiato: titulação' : 'Nitroprussiato: titulação',
              promptToSend: es
                  ? 'Uso de nitroprusiato de sodio en crisis hipertensiva: dosis inicial 0,3mcg/kg/min, titulación, toxicidad por tiocianato/cianuro, cuándo evitar y alternativas (nicardipino, labetalol).'
                  : 'Uso de nitroprussiato de sódio na crise hipertensiva: dose inicial 0,3mcg/kg/min, titulação, toxicidade por tiocianato/cianeto, quando evitar e alternativas (nicardipino, labetalol).',
            ),
            SmartNextAction(
              label: es ? 'HTA en ACV: particularidades' : 'HAS no AVC: particularidades',
              promptToSend: es
                  ? 'Manejo de HTA en contexto de ACV: no tratar agresivamente en isquémico (< 220/120 sin trombolisis), meta estricta < 140 en hemorrágico y fármacos permitidos IV.'
                  : 'Manejo de HAS no contexto de AVC: não tratar agressivamente no isquêmico (< 220/120 sem trombólise), meta estrita < 140 no hemorrágico e fármacos permitidos IV.',
            ),
          ], chatHistory);
        } else {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Anti-HTA: mecanismos' : 'Anti-HAS: mecanismos',
              promptToSend: es
                  ? 'Mecanismos de acción de los antihipertensivos: IECA, ARA-II, bloqueadores de calcio, betabloqueadores y diuréticos tiazídicos.'
                  : 'Mecanismos de ação dos anti-hipertensivos: IECA, BRA, bloqueadores de canal de cálcio, betabloqueadores e tiazídicos.',
            ),
            SmartNextAction(
              label: es ? 'HTA resistente: definición' : 'HAS resistente: definição',
              promptToSend: es
                  ? 'Hipertensión arterial resistente: definición (PA no controlada con 3 fármacos incluyendo diurético), causas secundarias a descartar y opciones (espironolactona, denervación renal).'
                  : 'Hipertensão arterial resistente: definição (PA não controlada com 3 fármacos incluindo diurético), causas secundárias a descartar e opções (espironolactona, denervação renal).',
            ),
            SmartNextAction(
              label: es ? 'Metas de PA: evidencia' : 'Metas de PA: evidência',
              promptToSend: es
                  ? 'Metas de presión arterial según evidencia: SPRINT (< 120/80 en alto riesgo), AHA 2024, diabéticos, enfermedad renal crónica — beneficio vs riesgo de hipotensión.'
                  : 'Metas de pressão arterial por evidência: SPRINT (< 120/80 em alto risco), AHA 2024, diabéticos, doença renal crônica — benefício vs risco de hipotensão.',
            ),
          ], chatHistory);
        }

      // ── 15. IC ─────────────────────────────────────────────────────────────
      case ClinicalTopic.ic:
        if (isPlantaoMode) {
          return _pickAction([
            SmartNextAction(
              label: es ? 'IC descompensada: diuresis' : 'IC descompensada: diurese',
              promptToSend: es
                  ? 'Protocolo de diuresis forzada en IC aguda descompensada: furosemida IV bolo versus infusión, metas de diuresis, resistencia a diuréticos.'
                  : 'Protocolo de diurese forçada na IC aguda descompensada: furosemida IV em bolus versus infusão, metas de diurese, resistência a diurético.',
            ),
            SmartNextAction(
              label: es ? 'Vasodiladores IV en IC' : 'Vasodilatadores IV na IC',
              promptToSend: es
                  ? 'Uso de vasodilatadores IV en IC aguda: nitroglicerina (congestión, EAP), nitroprusiato (IC avanzada, alta poscarga), nesiritida — dosis, indicaciones y contraindicaciones.'
                  : 'Uso de vasodilatadores IV na IC aguda: nitroglicerina (congestão, EAP), nitroprussiato (IC avançada, alta pós-carga), nesiritida — doses, indicações e contraindicações.',
            ),
            SmartNextAction(
              label: es ? 'IC con FE preservada' : 'IC com FE preservada',
              promptToSend: es
                  ? 'Manejo de la insuficiencia cardíaca con fracción de eyección preservada (ICFEp): SGLT2i (empagliflozina EMPEROR-Preserved), diuréticos, control de comorbilidades y evidencia actual.'
                  : 'Manejo da insuficiência cardíaca com fração de ejeção preservada (ICFEp): iSGLT2 (empagliflozina EMPEROR-Preserved), diuréticos, controle de comorbidades e evidência atual.',
            ),
          ], chatHistory);
        } else {
          return _pickAction([
            SmartNextAction(
              label: es ? 'IC: tratamento DAPA-HF' : 'IC: tratamento base DAPA',
              promptToSend: es
                  ? 'Pilares del tratamiento modificador de pronóstico en ICFEr: betabloqueadores, IECA/sacubitrilo-valsartán, espironolactona y SGLT2 (evidencia DAPA-HF).'
                  : 'Pilares do tratamento modificador de prognóstico na ICFEr: betabloqueadores, IECA/sacubitril-valsartana, espironolactona e SGLT2 (evidência DAPA-HF).',
            ),
            SmartNextAction(
              label: es ? 'Clasificación NYHA: IC' : 'Classificação NYHA: IC',
              promptToSend: es
                  ? 'Clasificación NYHA en IC: clases I-IV, correlato con fracción de eyección, pronóstico y cómo guía la escalada terapéutica incluyendo resincronización y asistencia ventricular.'
                  : 'Classificação NYHA na IC: classes I-IV, correlato com fração de ejeção, prognóstico e como guia a escalada terapêutica incluindo ressincronização e assistência ventricular.',
            ),
            SmartNextAction(
              label: es ? 'Trasplante cardíaco: criterios' : 'Transplante cardíaco: critérios',
              promptToSend: es
                  ? 'Criterios de trasplante cardíaco en IC terminal: INTERMACS, puntaje SHFM, contraindicaciones (HTP irreversible, cáncer activo), lista de espera y soporte con LVAD como puente.'
                  : 'Critérios de transplante cardíaco na IC terminal: INTERMACS, pontuação SHFM, contraindicações (HAP irreversível, câncer ativo), lista de espera e suporte com LVAD como ponte.',
            ),
          ], chatHistory);
        }

      // ── 16. DPOC ───────────────────────────────────────────────────────────
      case ClinicalTopic.dpoc:
        if (isPlantaoMode) {
          return _pickAction([
            SmartNextAction(
              label: es ? 'EPOC: VNI ou intubação?' : 'DPOC: VNI ou IOT?',
              promptToSend: es
                  ? 'Criterios de ventilación no invasiva versus intubación en exacerbación grave de EPOC: indicaciones, contraindicaciones y parámetros de fallo de VNI.'
                  : 'Critérios de ventilação não invasiva versus intubação na exacerbação grave de DPOC: indicações, contraindicações e parâmetros de falha de VNI.',
            ),
            SmartNextAction(
              label: es ? 'EPOC: corticoide sistémico' : 'DPOC: corticoide sistêmico',
              promptToSend: es
                  ? 'Uso de corticoide sistémico en exacerbación de EPOC: prednisolona 40mg/día × 5 días (REDUCE trial), cuándo nebulizar, impacto en tiempo de hospitalización y efectos adversos.'
                  : 'Uso de corticoide sistêmico na exacerbação de DPOC: prednisolona 40mg/dia × 5 dias (trial REDUCE), quando nebulizar, impacto no tempo de internação e efeitos adversos.',
            ),
            SmartNextAction(
              label: es ? 'O₂ en EPOC: cuánto dar' : 'O₂ no DPOC: quanto dar',
              promptToSend: es
                  ? 'Oxigenoterapia controlada en exacerbación de EPOC: meta SpO₂ 88-92%, riesgo de narcosis por CO₂, mascarilla Venturi vs gafas nasales y cuándo pasar a VNI.'
                  : 'Oxigenioterapia controlada na exacerbação de DPOC: meta SpO₂ 88-92%, risco de narcose por CO₂, máscara Venturi vs óculos nasais e quando passar para VNI.',
            ),
          ], chatHistory);
        } else {
          return _pickAction([
            SmartNextAction(
              label: es ? 'GOLD: estadios EPOC' : 'GOLD: estadiamento DPOC',
              promptToSend: es
                  ? 'Estadiamento GOLD del EPOC: espirometría (GOLD 1-4), grupos ABCD por síntomas/exacerbaciones y tratamiento escalonado por grupo.'
                  : 'Estadiamento GOLD do DPOC: espirometria (GOLD 1-4), grupos ABCD por sintomas/exacerbações e tratamento escalonado por grupo.',
            ),
            SmartNextAction(
              label: es ? 'EPOC: triple terapia inhalada' : 'DPOC: tríplice terapia inalatória',
              promptToSend: es
                  ? 'Triple terapia inhalada en EPOC (LABA+LAMA+ICS): indicaciones (eosinófilos ≥ 300), evidencia IMPACT trial, comparación con doble broncodilatación y efectos adversos.'
                  : 'Tríplice terapia inalatória no DPOC (LABA+LAMA+ICS): indicações (eosinófilos ≥ 300), evidência trial IMPACT, comparação com dupla broncodilatação e efeitos adversos.',
            ),
            SmartNextAction(
              label: es ? 'Espirometría: interpretación' : 'Espirometria: interpretação',
              promptToSend: es
                  ? 'Interpretación espirométrica en EPOC: VEF1/CVF < 0,7, patrón obstructivo, reversibilidad (< 12% y < 200mL), severidad GOLD y limitaciones de la técnica.'
                  : 'Interpretação espirométrica no DPOC: VEF1/CVF < 0,7, padrão obstrutivo, reversibilidade (< 12% e < 200mL), severidade GOLD e limitações da técnica.',
            ),
          ], chatHistory);
        }

      // ── 17. Anafilaxia ─────────────────────────────────────────────────────
      case ClinicalTopic.anafilaxia:
        if (isPlantaoMode) {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Adrenalina: dosis y vía' : 'Adrenalina: dose e via',
              promptToSend: es
                  ? 'Protocolo de anafilaxia: adrenalina 0,3-0,5mg IM vasto lateral, posición, volumen IV, corticoide, antihistamínico y cuándo repetir adrenalina.'
                  : 'Protocolo de anafilaxia: adrenalina 0,3-0,5mg IM vasto lateral, posição, volume IV, corticoide, anti-histamínico e quando repetir adrenalina.',
            ),
            SmartNextAction(
              label: es ? 'Anafilaxia refractaria a epinefrina' : 'Anafilaxia refratária à adrenalina',
              promptToSend: es
                  ? 'Anafilaxia refractaria a la epinefrina: uso de glucagón en pacientes con betabloqueadores (1-5mg IV), vasopresores IV (noradrenalina), metilazul de metileno y criterios de UCI.'
                  : 'Anafilaxia refratária à adrenalina: uso de glucagon em pacientes com betabloqueadores (1-5mg IV), vasopressores IV (noradrenalina), azul de metileno e critérios de UTI.',
            ),
            SmartNextAction(
              label: es ? 'Prescripción de EpiPen' : 'Prescrição de EpiPen',
              promptToSend: es
                  ? 'Prescripción de autoinyector de epinefrina: indicaciones (anafilaxia previa, alergia grave), instrucción al paciente, caducidad, 2 dispositivos y plan de acción de emergencia.'
                  : 'Prescrição de autoinjetor de epinefrina: indicações (anafilaxia prévia, alergia grave), instrução ao paciente, prazo de validade, 2 dispositivos e plano de ação de emergência.',
            ),
          ], chatHistory);
        } else {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Fisiopatología anafilaxia' : 'Fisiopatologia anafilaxia',
              promptToSend: es
                  ? 'Fisiopatología de la anafilaxia: IgE, mastocitos, mediadores vasoactivos, colapso cardiovascular y diferencia con reacción anafilactoide.'
                  : 'Fisiopatologia da anafilaxia: IgE, mastócitos, mediadores vasoativos, colapso cardiovascular e diferença com reação anafilactoide.',
            ),
            SmartNextAction(
              label: es ? 'Diagnóstico diferencial anafilaxia' : 'Diagnóstico diferencial anafilaxia',
              promptToSend: es
                  ? 'Diagnóstico diferencial de anafilaxia: angioedema hereditario (C1-inhibidor), síncope vasovagal, urticaria aislada, carcinoide e hipoglucemia — diferencias y abordaje.'
                  : 'Diagnóstico diferencial de anafilaxia: angioedema hereditário (C1-inibidor), síncope vasovagal, urticária isolada, carcinoide e hipoglicemia — diferenças e abordagem.',
            ),
            SmartNextAction(
              label: es ? 'Alergia a medicamentos: clasificación' : 'Alergia a medicamentos: classificação',
              promptToSend: es
                  ? 'Clasificación de reacciones adversas a medicamentos: tipo A (previsibles, dosis-dependientes) vs tipo B (imprevisibles, alérgicas) — mecanismos IgE, celular, inmune complejo.'
                  : 'Classificação de reações adversas a medicamentos: tipo A (previsíveis, dose-dependentes) vs tipo B (imprevisíveis, alérgicas) — mecanismos IgE, celular, imunocomplexo.',
            ),
          ], chatHistory);
        }

      // ── 18. Convulsão ──────────────────────────────────────────────────────
      case ClinicalTopic.convulsao:
        if (isPlantaoMode) {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Status epiléptico: escalar' : 'Status epiléptico: escalar',
              promptToSend: es
                  ? 'Escalada farmacológica en status epiléptico: 1ª línea benzodiazepinas IV/IM, 2ª línea fenitoína o levetiracetam IV, 3ª línea propofol o midazolam IV.'
                  : 'Escalonamento farmacológico no estado de mal epiléptico: 1ª linha benzodiazepínicos IV/IM, 2ª linha fenitoína ou levetiracetam IV, 3ª linha propofol ou midazolam IV.',
            ),
            SmartNextAction(
              label: es ? 'Status refractario: protocolo' : 'Status refratário: protocolo',
              promptToSend: es
                  ? 'Status epiléptico refractario: definición (> 30 min o fallo de 2ª línea), ketamina IV, propofol en infusión, pentobarbital anestésico y monitorización EEG continuo.'
                  : 'Status epiléptico refratário: definição (> 30 min ou falha de 2ª linha), cetamina IV, propofol em infusão, pentobarbital anestésico e monitorização EEG contínuo.',
            ),
            SmartNextAction(
              label: es ? 'Anticonvulsivante: 1ª crise' : 'Anticonvulsivante: 1ª crise',
              promptToSend: es
                  ? 'Decisión de iniciar anticonvulsivante tras la primera crisis: factores de riesgo de recurrencia (lesión cerebral, EEG anormal, imagen patológica) y elección del fármaco por tipo de epilepsia.'
                  : 'Decisão de iniciar anticonvulsivante após a primeira crise: fatores de risco de recorrência (lesão cerebral, EEG anormal, imagem patológica) e escolha do fármaco por tipo de epilepsia.',
            ),
          ], chatHistory);
        } else {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Crisis focal × generalizada' : 'Crise focal × generalizada',
              promptToSend: es
                  ? 'Clasificación ILAE de las crisis epilépticas: focal vs generalizada vs inicio desconocido, semiología y correlato electroencefalográfico.'
                  : 'Classificação ILAE das crises epilépticas: focal vs generalizada vs início desconhecido, semiologia e correlato eletroencefalográfico.',
            ),
            SmartNextAction(
              label: es ? 'Mecanismo de los antiepilépticos' : 'Mecanismo dos antiepilépticos',
              promptToSend: es
                  ? 'Mecanismos de los antiepilépticos: bloqueadores de canales de Na⁺ (fenitoína, lamotrigina), potenciación GABAérgica (benzodiazepinas, valproato), SV2A (levetiracetam) y anti-Ca²⁺.'
                  : 'Mecanismos dos antiepilépticos: bloqueadores de canais de Na⁺ (fenitoína, lamotrigina), potenciação GABAérgica (benzodiazepínicos, valproato), SV2A (levetiracetam) e anti-Ca²⁺.',
            ),
            SmartNextAction(
              label: es ? 'Epilepsia y embarazo' : 'Epilepsia e gravidez',
              promptToSend: es
                  ? 'Manejo de epilepsia en el embarazo: riesgo de malformaciones (valproato > carbamazepina > lamotrigina), suplemento de folato, monitoreo de niveles y parto planificado.'
                  : 'Manejo da epilepsia na gravidez: risco de malformações (valproato > carbamazepina > lamotrigina), suplemento de folato, monitoramento de níveis e parto planejado.',
            ),
          ], chatHistory);
        }

      // ── 19. Meningite ──────────────────────────────────────────────────────
      case ClinicalTopic.meningite:
        if (isPlantaoMode) {
          return _pickAction([
            SmartNextAction(
              label: es ? 'ATB + dexametasona' : 'ATB + dexametasona',
              promptToSend: es
                  ? 'Protocolo de meningitis bacteriana aguda: ceftriaxona 2g IV 12/12h, dexametasona 0,15mg/kg antes do ATB, cobertura para listeria e cuándo aciclovir.'
                  : 'Protocolo de meningite bacteriana aguda: ceftriaxona 2g IV 12/12h, dexametasona 0,15mg/kg antes do ATB, cobertura para listeria e quando aciclovir.',
            ),
            SmartNextAction(
              label: es ? 'Punción lumbar: cuándo hacer' : 'Punção lombar: quando fazer',
              promptToSend: es
                  ? 'Indicaciones y contraindicaciones de punción lumbar en sospecha de meningitis: cuándo hacer TC previo (focal, papiledema, Glasgow < 14), técnica y posición segura.'
                  : 'Indicações e contraindicações de punção lombar na suspeita de meningite: quando fazer TC prévia (focal, papiledema, Glasgow < 14), técnica e posição segura.',
            ),
            SmartNextAction(
              label: es ? 'Profilaxis meningocócica' : 'Profilaxia meningocócica',
              promptToSend: es
                  ? 'Quimioprofilaxis de contactos en meningitis meningocócica: rifampicina 600mg 12/12h × 2 dias, ciprofloxacina monodosis, ceftriaxona IM — definición de contacto íntimo.'
                  : 'Quimioprofilaxia de contatos na meningite meningocócica: rifampicina 600mg 12/12h × 2 dias, ciprofloxacina monodose, ceftriaxona IM — definição de contato íntimo.',
            ),
          ], chatHistory);
        } else {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Líquido cefalorraquídeo' : 'Análise do líquor',
              promptToSend: es
                  ? 'Interpretación del LCR en meningitis: patrón bacteriano vs viral vs fúngico vs tuberculosa — células, glucosa, proteínas, tinciones y cultivos.'
                  : 'Interpretação do líquor na meningite: padrão bacteriano vs viral vs fúngico vs tuberculosa — células, glicose, proteínas, colorações e culturas.',
            ),
            SmartNextAction(
              label: es ? 'Meningitis viral: manejo' : 'Meningite viral: manejo',
              promptToSend: es
                  ? 'Manejo de meningitis viral (aséptica): LCR con linfocitos, glucosa normal, agentes más frecuentes (enterovirus, HSV-2), indicación de aciclovir y pronóstico.'
                  : 'Manejo da meningite viral (asséptica): líquor com linfócitos, glicose normal, agentes mais frequentes (enterovírus, HSV-2), indicação de aciclovir e prognóstico.',
            ),
            SmartNextAction(
              label: es ? 'Meningitis por Criptococo' : 'Meningite por Criptococo',
              promptToSend: es
                  ? 'Meningitis criptocócica en HIV: diagnóstico (antígeno criptocócico, tinta china), inducción con anfotericina B + flucitosina × 2 semanas, consolidación con fluconazol y profilaxis secundaria.'
                  : 'Meningite criptocócica no HIV: diagnóstico (antígeno criptocócico, tinta da China), indução com anfotericina B + flucitosina × 2 semanas, consolidação com fluconazol e profilaxia secundária.',
            ),
          ], chatHistory);
        }

      // ── 20. Endocardite ────────────────────────────────────────────────────
      case ClinicalTopic.endocardite:
        if (isPlantaoMode) {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Antibiótico endocarditis' : 'Antibiótico endocardite',
              promptToSend: es
                  ? 'Esquema antibiótico empírico en endocarditis infecciosa: válvula nativa (oxacilina + gentamicina) vs válvula protésica (vancomicina + rifampicina) y duración.'
                  : 'Esquema antibiótico empírico na endocardite infecciosa: válvula nativa (oxacilina + gentamicina) vs válvula protética (vancomicina + rifampicina) e duração.',
            ),
            SmartNextAction(
              label: es ? 'Cirugía en endocarditis: cuándo' : 'Cirurgia na endocardite: quando',
              promptToSend: es
                  ? 'Indicaciones urgentes de cirugía en endocarditis infecciosa: IC refractaria, vegetación > 10mm + embolismo, absceso perivalvular y fallo del tratamiento antibiótico.'
                  : 'Indicações urgentes de cirurgia na endocardite infecciosa: IC refratária, vegetação > 10mm + embolismo, abscesso perivalvular e falha do tratamento antibiótico.',
            ),
            SmartNextAction(
              label: es ? 'Endocarditis en ADVP' : 'Endocardite em usuário de drogas',
              promptToSend: es
                  ? 'Endocarditis en adictos a drogas por vía parenteral: S. aureus en válvulas derechas, presentación clínica, imagen (EP séptica), antibioticoterapia y controversia de cirugía.'
                  : 'Endocardite em usuários de drogas intravenosas: S. aureus em válvulas direitas, apresentação clínica, imagem (TEP séptica), antibioticoterapia e controvérsia de cirurgia.',
            ),
          ], chatHistory);
        } else {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Criterios de Duke' : 'Critérios de Duke',
              promptToSend: es
                  ? 'Criterios de Duke modificados para endocarditis infecciosa: criterios mayores y menores, definición de diagnóstico definitivo, posible y rechazado.'
                  : 'Critérios de Duke modificados para endocardite infecciosa: critérios maiores e menores, definição de diagnóstico definitivo, possível e rejeitado.',
            ),
            SmartNextAction(
              label: es ? 'Agentes más frecuentes EI' : 'Agentes mais frequentes EI',
              promptToSend: es
                  ? 'Agentes etiológicos de endocarditis infecciosa: Streptococcus viridans (válvula nativa, dentaria), S. aureus (nosocomial, ADVP), Enterococcus (GI/urinario) y hongos.'
                  : 'Agentes etiológicos da endocardite infecciosa: Streptococcus viridans (válvula nativa, dentária), S. aureus (nosocomial, drogas IV), Enterococcus (GI/urinário) e fungos.',
            ),
            SmartNextAction(
              label: es ? 'Profilaxis antibiótica dental' : 'Profilaxia antibiótica dental',
              promptToSend: es
                  ? 'Indicaciones de profilaxis antibiótica para procedimientos dentales en endocarditis: válvulas protésicas, EI previa, cardiopatía congénita cianótica — amoxicilina 2g oral 1h antes.'
                  : 'Indicações de profilaxia antibiótica para procedimentos dentários na endocardite: válvulas protéticas, EI prévia, cardiopatia congênita cianótica — amoxicilina 2g oral 1h antes.',
            ),
          ], chatHistory);
        }

      // ── 21. Hiponatremia ───────────────────────────────────────────────────
      case ClinicalTopic.hiponatremia:
        if (isPlantaoMode) {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Corrección de sodio' : 'Correção do sódio',
              promptToSend: es
                  ? 'Protocolo de corrección de hiponatremia grave (Na < 120): velocidad máxima 8-10mEq/24h, solución salina hipertónica 3%, riesgo de mielinólisis pontina.'
                  : 'Protocolo de correção de hiponatremia grave (Na < 120): velocidade máxima 8-10mEq/24h, solução salina hipertônica 3%, risco de mielinólise pontina.',
            ),
            SmartNextAction(
              label: es ? 'Hiponatremia sintomática: bolus' : 'Hiponatremia sintomática: bolus',
              promptToSend: es
                  ? 'Corrección aguda de hiponatremia con síntomas graves (convulsión, coma): bolus de NaCl 3% 150mL IV en 20min, repetir hasta 3x, meta de elevación de Na 5mEq/L en 1ª hora.'
                  : 'Correção aguda de hiponatremia com sintomas graves (convulsão, coma): bolus de NaCl 3% 150mL IV em 20min, repetir até 3x, meta de elevação de Na 5mEq/L na 1ª hora.',
            ),
            SmartNextAction(
              label: es ? 'Tolvaptán en SIADH' : 'Tolvaptana no SIADH',
              promptToSend: es
                  ? 'Uso de vaptanes (tolvaptán) en SIADH crónica: mecanismo (antagonista V2), dosis, monitorización de sodio (riesgo de corrección rápida), contraindicaciones y costo-efectividad.'
                  : 'Uso de vaptanas (tolvaptana) no SIADH crônica: mecanismo (antagonista V2), dose, monitorização de sódio (risco de correção rápida), contraindicações e custo-efetividade.',
            ),
          ], chatHistory);
        } else {
          return _pickAction([
            SmartNextAction(
              label: es ? 'SIADH × otras causas' : 'SIADH × outras causas',
              promptToSend: es
                  ? 'Diagnóstico diferencial de hiponatremia: SIADH, polidipsia, hipotiroidismo, insuficiencia adrenal — osmolalidad plasmática y urinaria.'
                  : 'Diagnóstico diferencial de hiponatremia: SIADH, polidipsia, hipotireoidismo, insuficiência adrenal — osmolalidade plasmática e urinária.',
            ),
            SmartNextAction(
              label: es ? 'Criterios SIADH: diagnóstico' : 'Critérios SIADH: diagnóstico',
              promptToSend: es
                  ? 'Criterios diagnósticos de SIADH: Na < 135, osmolalidad plasmática < 275, osmolalidad urinaria > 100, Na urinario > 40, función renal/adrenal/tiroidea normales.'
                  : 'Critérios diagnósticos de SIADH: Na < 135, osmolalidade plasmática < 275, osmolalidade urinária > 100, Na urinário > 40, função renal/adrenal/tireoidiana normais.',
            ),
            SmartNextAction(
              label: es ? 'Hiponatremia y encefalopatía' : 'Hiponatremia e encefalopatia',
              promptToSend: es
                  ? 'Encefalopatía hiponatrémica: mecanismo de edema cerebral, síntomas de herniación, factores de riesgo (menstruación, cirugía hipofisaria) y urgencia de corrección.'
                  : 'Encefalopatia hiponatrêmica: mecanismo de edema cerebral, sintomas de herniação, fatores de risco (menstruação, cirurgia hipofisária) e urgência de correção.',
            ),
          ], chatHistory);
        }

      // ── 22. Hipernatremia ──────────────────────────────────────────────────
      case ClinicalTopic.hipernatremia:
        if (isPlantaoMode) {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Hidratación: cálculo déficit' : 'Reidratação: déficit',
              promptToSend: es
                  ? 'Cálculo del déficit de agua libre en hipernatremia y protocolo de corrección: velocidad máxima de reducción del sodio para evitar edema cerebral.'
                  : 'Cálculo do déficit de água livre na hipernatremia e protocolo de correção: velocidade máxima de redução do sódio para evitar edema cerebral.',
            ),
            SmartNextAction(
              label: es ? 'Hipernatremia en UCI: causas' : 'Hipernatremia na UTI: causas',
              promptToSend: es
                  ? 'Causas de hipernatremia adquirida en UCI: pérdidas insensibles (fiebre, ventilación mecânica), diuresis osmótica (manitol, hiperglucemia), restricción de agua libre.'
                  : 'Causas de hipernatremia adquirida na UTI: perdas insensíveis (febre, ventilação mecânica), diurese osmótica (manitol, hiperglicemia), restrição de água livre.',
            ),
            SmartNextAction(
              label: es ? 'Desmopresina: indicaciones' : 'Desmopressina: indicações',
              promptToSend: es
                  ? 'Uso de desmopresina (DDAVP) en diabetes insípida central: vía intranasal vs IV/SC, dosis, monitorización de sodio y diuresis, y cuándo no usar (DI nefrogénica).'
                  : 'Uso de desmopressina (DDAVP) na diabetes insipidus central: via intranasal vs IV/SC, dose, monitorização de sódio e diurese, e quando não usar (DI nefrogênica).',
            ),
          ], chatHistory);
        } else {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Diabetes insípida' : 'Diabetes insipidus',
              promptToSend: es
                  ? 'Diferencia diabetes insípida central versus nefrogénica: fisiopatología, prueba de deshidratación, desmopresina y manejo diferencial.'
                  : 'Diferença diabetes insipidus central versus nefrogênica: fisiopatologia, teste de desidratação, desmopressina e manejo diferencial.',
            ),
            SmartNextAction(
              label: es ? 'Regulación del sodio: fisiología' : 'Regulação do sódio: fisiologia',
              promptToSend: es
                  ? 'Fisiología de la regulación del sodio y agua: ADH (osmorregulación vs volorregulación), aldosterona, péptido natriurético auricular y sed — interacciones en estados patológicos.'
                  : 'Fisiologia da regulação do sódio e água: ADH (osmorregulação vs volorregulação), aldosterona, peptídeo natriurético atrial e sede — interações em estados patológicos.',
            ),
            SmartNextAction(
              label: es ? 'Hipernatremia crónica vs aguda' : 'Hipernatremia crônica vs aguda',
              promptToSend: es
                  ? 'Diferencia en el manejo de hipernatremia aguda (< 48h: corrección rápida posible) versus crónica (> 48h: corrección máxima 10mEq/24h para evitar edema cerebral de rebote).'
                  : 'Diferença no manejo de hipernatremia aguda (< 48h: correção rápida possível) versus crônica (> 48h: correção máxima 10mEq/24h para evitar edema cerebral de rebote).',
            ),
          ], chatHistory);
        }

      // ── 23. Acidose ────────────────────────────────────────────────────────
      case ClinicalTopic.acidose:
        if (isPlantaoMode) {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Bicarbonato: cuándo usar' : 'Bicarbonato: quando usar',
              promptToSend: es
                  ? 'Indicaciones de bicarbonato IV en acidosis metabólica severa: pH < 7.1, hipercalemia refractaria, intoxicación por tricíclicos. Cuándo NO usar en acidosis láctica.'
                  : 'Indicações de bicarbonato IV na acidose metabólica grave: pH < 7,1, hipercalemia refratária, intoxicação por tricíclicos. Quando NÃO usar na acidose lática.',
            ),
            SmartNextAction(
              label: es ? 'Acidosis láctica: causas' : 'Acidose lática: causas',
              promptToSend: es
                  ? 'Causas de acidosis láctica tipo A (hipoxia tisular: sepsis, shock) vs tipo B (metformina, alcohol, cianuro, isquemia intestinal) y enfoque terapéutico diferencial.'
                  : 'Causas de acidose lática tipo A (hipóxia tissular: sepse, choque) vs tipo B (metformina, álcool, cianeto, isquemia intestinal) e abordagem terapêutica diferencial.',
            ),
            SmartNextAction(
              label: es ? 'Anion gap: cálculo e interpretação' : 'Ânion gap: cálculo e interpretação',
              promptToSend: es
                  ? 'Cálculo e interpretación del anion gap en acidosis metabólica: valor normal (8-12), correccion por albumina, causas de AG elevado (MUDPILES) vs AG normal (HARDUPS).'
                  : 'Cálculo e interpretação do ânion gap na acidose metabólica: valor normal (8-12), correção por albumina, causas de AG elevado (MUDPILES) vs AG normal (HARDUPS).',
            ),
          ], chatHistory);
        } else {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Análisis de gases: pasos' : 'Análise gasométrica: passos',
              promptToSend: es
                  ? 'Metodología de interpretación de gasometría en 6 pasos: acidosis vs alcalosis, metabólica vs respiratoria, compensación esperada y trastornos mixtos.'
                  : 'Metodologia de interpretação da gasometria em 6 passos: acidose vs alcalose, metabólica vs respiratória, compensação esperada e distúrbios mistos.',
            ),
            SmartNextAction(
              label: es ? 'Compensaciones esperadas: fórmulas' : 'Compensações esperadas: fórmulas',
              promptToSend: es
                  ? 'Fórmulas de compensación en trastornos ácido-base: acidosis metabólica (Winter), alcalosis metabólica (PCO₂ esperado), acidosis respiratoria aguda/crónica y alcalosis respiratoria.'
                  : 'Fórmulas de compensação nos distúrbios ácido-base: acidose metabólica (Winter), alcalose metabólica (PCO₂ esperado), acidose respiratória aguda/crônica e alcalose respiratória.',
            ),
            SmartNextAction(
              label: es ? 'Acidosis tubular renal: tipos' : 'Acidose tubular renal: tipos',
              promptToSend: es
                  ? 'Acidosis tubular renal tipos I (distal), II (proximal) y IV (hipercalémica): fisiopatología, diagnóstico con pH urinario y anion gap urinario, causas y tratamiento.'
                  : 'Acidose tubular renal tipos I (distal), II (proximal) e IV (hipercalêmica): fisiopatologia, diagnóstico com pH urinário e ânion gap urinário, causas e tratamento.',
            ),
          ], chatHistory);
        }

      // ── 24. Alcalose ───────────────────────────────────────────────────────
      case ClinicalTopic.alcalose:
        if (isPlantaoMode) {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Alcalosis: causas urgentes' : 'Alcalose: causas urgentes',
              promptToSend: es
                  ? 'Manejo urgente de alcalosis metabólica severa (pH > 7.6): causas (vómitos, diuréticos, Cl urinario), corrección con cloruro y reposición de K⁺.'
                  : 'Manejo urgente de alcalose metabólica grave (pH > 7,6): causas (vômitos, diuréticos, Cl urinário), correção com cloreto e reposição de K⁺.',
            ),
            SmartNextAction(
              label: es ? 'Alcalosis en ventilación mecánica' : 'Alcalose na ventilação mecânica',
              promptToSend: es
                  ? 'Alcalosis respiratoria iatrogénica en ventilación mecánica: causas (hiperventilación, dolor, ansiedad), consecuencias (vasoconstricción cerebral, tetania) y ajuste de parámetros.'
                  : 'Alcalose respiratória iatrogênica na ventilação mecânica: causas (hiperventilação, dor, ansiedade), consequências (vasoconstrição cerebral, tetania) e ajuste de parâmetros.',
            ),
            SmartNextAction(
              label: es ? 'Síndrome de Bartter × Gitelman' : 'Síndrome de Bartter × Gitelman',
              promptToSend: es
                  ? 'Tubulopatías con alcalosis metabólica hipocalémica: Bartter (semeja furosemida, hipercalciuria) vs Gitelman (semeja tiazida, hipomagnesia) — diagnóstico y tratamiento.'
                  : 'Tubulopatias com alcalose metabólica hipocalêmica: Bartter (semelhante furosemida, hipercalciúria) vs Gitelman (semelhante tiazida, hipomagnesemia) — diagnóstico e tratamento.',
            ),
          ], chatHistory);
        } else {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Alcalosis: fisiopatología' : 'Alcalose: fisiopatologia',
              promptToSend: es
                  ? 'Fisiopatología de la alcalosis metabólica: factores de generación y mantenimiento, rol del cloro urinario y clasificación cloro-sensible versus resistente.'
                  : 'Fisiopatologia da alcalose metabólica: fatores de geração e manutenção, papel do cloro urinário e classificação cloro-sensível versus resistente.',
            ),
            SmartNextAction(
              label: es ? 'Alcalosis respiratoria: causas' : 'Alcalose respiratória: causas',
              promptToSend: es
                  ? 'Causas de alcalosis respiratoria: ansiedad/hiperventilación, hipoxemia (TEP, altitud), cirrosis hepática, sepsis precoz, embarazo, salicilatos y ventilación mecánica.'
                  : 'Causas de alcalose respiratória: ansiedade/hiperventilação, hipoxemia (TEP, altitude), cirrose hepática, sepse precoce, gravidez, salicilatos e ventilação mecânica.',
            ),
            SmartNextAction(
              label: es ? 'Trastornos mixtos: interpretación' : 'Distúrbios mistos: interpretação',
              promptToSend: es
                  ? 'Identificación de trastornos ácido-base mixtos: delta-delta ratio en acidosis metabólica, compensación inadecuada como pista y casos clínicos típicos (cirrosis, overdose, diarrea+vómitos).'
                  : 'Identificação de distúrbios ácido-base mistos: relação delta-delta na acidose metabólica, compensação inadequada como pista e casos clínicos típicos (cirrose, overdose, diarreia+vômitos).',
            ),
          ], chatHistory);
        }

      // ── 25. Choque ─────────────────────────────────────────────────────────
      case ClinicalTopic.choque:
        if (isPlantaoMode) {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Clasificar el tipo de shock' : 'Classificar o tipo de choque',
              promptToSend: es
                  ? 'Clasificación del shock y enfoque hemodinámico: hipovolémico, distributivo, cardiogénico y obstructivo — perfil clínico, ecocardiografía point-of-care.'
                  : 'Classificação do choque e abordagem hemodinâmica: hipovolêmico, distributivo, cardiogênico e obstrutivo — perfil clínico, ecocardiografia point-of-care.',
            ),
            SmartNextAction(
              label: es ? 'Fluidoterapia en shock: cuándo parar' : 'Fluidoterapia no choque: quando parar',
              promptToSend: es
                  ? 'Evaluación de la responsividad a fluidos en shock: PLR (passive leg raising), VPP (variación de presión de pulso), VVC vs PAP, ecocardiografía funcional y cuándo pasar a vasopresores.'
                  : 'Avaliação da responsividade a fluidos no choque: PLR (passive leg raising), VPP (variação de pressão de pulso), PVC vs PAP, ecocardiografia funcional e quando passar a vasopressores.',
            ),
            SmartNextAction(
              label: es ? 'Shock cardiogénico: manejo' : 'Choque cardiogênico: manejo',
              promptToSend: es
                  ? 'Manejo del shock cardiogénico: dobutamina, norradrenalina, balón intraaórtico de contrapulsación, Impella, ECMO VA — criterios de soporte mecánico y trasplante urgente.'
                  : 'Manejo do choque cardiogênico: dobutamina, noradrenalina, balão intraaórtico de contrapulsação, Impella, ECMO VA — critérios de suporte mecânico e transplante urgente.',
            ),
          ], chatHistory);
        } else {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Fisiopatología del shock' : 'Fisiopatologia do choque',
              promptToSend: es
                  ? 'Fisiopatología del shock: DO₂, VO₂, extracción de O₂, disfunción mitocondrial y cascada de falla multiorgánica.'
                  : 'Fisiopatologia do choque: DO₂, VO₂, extração de O₂, disfunção mitocondrial e cascata de falência de múltiplos órgãos.',
            ),
            SmartNextAction(
              label: es ? 'Monitoreo hemodinámico avanzado' : 'Monitorização hemodinâmica avançada',
              promptToSend: es
                  ? 'Monitoreo hemodinámico en shock: catéter de Swan-Ganz (GC, PCWP, RVS), PICCO (GEDVI, EVLWI), ecocardiografía funcional — indicaciones, limitaciones e interpretación.'
                  : 'Monitorização hemodinâmica no choque: cateter de Swan-Ganz (DC, PCWP, RVS), PICCO (GEDVI, EVLWI), ecocardiografia funcional — indicações, limitações e interpretação.',
            ),
            SmartNextAction(
              label: es ? 'Shock: microcirculación y SDMO' : 'Choque: microcirculação e DMOS',
              promptToSend: es
                  ? 'Disfunción de la microcirculación en shock: heterogeneidad de flujo, shunt AV, deuda de oxígeno, marcadores de disfunción orgánica (lactato, ScvO₂) y progresión a SDMO.'
                  : 'Disfunção da microcirculação no choque: heterogeneidade de fluxo, shunt AV, dívida de oxigênio, marcadores de disfunção orgânica (lactato, ScvO₂) e progressão para DMOS.',
            ),
          ], chatHistory);
        }

      // ── 26. Intubação ──────────────────────────────────────────────────────
      case ClinicalTopic.intubacao:
        if (isPlantaoMode) {
          return _pickAction([
            SmartNextAction(
              label: es ? 'SIR: secuencia completa' : 'SRI: sequência completa',
              promptToSend: es
                  ? 'Secuencia de intubación rápida completa: premedicación, ketamina/propofol + succinilcolina o rocurônio, dosis, posición y verificación con capnografía.'
                  : 'Sequência de intubação de sequência rápida completa: pré-medicação, quetamina/propofol + succinilcolina ou rocurônio, doses, posição e verificação com capnografia.',
            ),
            SmartNextAction(
              label: es ? 'Succinilcolina × Rocurônio' : 'Succinilcolina × Rocurônio',
              promptToSend: es
                  ? 'Comparación succinilcolina vs rocurônio en SIR: tiempo de inicio, duración, contraindicaciones (succinilcolina: quemaduras, hiperkalemia, miopatias) y reversión con sugamadex.'
                  : 'Comparação succinilcolina vs rocurônio na SRI: tempo de início, duração, contraindicações (succinilcolina: queimaduras, hipercalemia, miopatias) e reversão com sugamadex.',
            ),
            SmartNextAction(
              label: es ? 'FONA: cricotirotomía' : 'FONA: cricotireoidostomia',
              promptToSend: es
                  ? 'Técnica de cricotirotomía de emergencia (FONA): indicación (no se puede intubar/oxigenar), técnica con bisturí y sonda, kit comerciales y formación para la emergencia.'
                  : 'Técnica de cricotireoidostomia de emergência (FONA): indicação (não consegue intubar/oxigenar), técnica com bisturi e cânula, kits comerciais e formação para a emergência.',
            ),
          ], chatHistory);
        } else {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Vía aérea difícil: algoritmo' : 'Via aérea difícil: algoritmo',
              promptToSend: es
                  ? 'Algoritmo de vía aérea difícil: predictores (LEMON), videolaringoscopia, bougie, mascara laríngea de rescate y cricotirotomía de emergencia.'
                  : 'Algoritmo de via aérea difícil: preditores (LEMON), videolaringoscopia, bougie, máscara laríngea de resgate e cricotireoidostomia de emergência.',
            ),
            SmartNextAction(
              label: es ? 'Predictores de vía aérea difícil' : 'Preditores de via aérea difícil',
              promptToSend: es
                  ? 'Predictores de vía aérea difícil: LEMON (Look, Evaluate 3-3-2, Mallampati, Obstruction, Neck mobility), RODS para VML, SMART para mascarilla laríngea y criterios de despertar.'
                  : 'Preditores de via aérea difícil: LEMON (Look, Evaluate 3-3-2, Mallampati, Obstruction, Neck mobility), RODS para MLV, SMART para máscara laríngea e critérios de despertar.',
            ),
            SmartNextAction(
              label: es ? 'Capnografía: interpretación' : 'Capnografia: interpretação',
              promptToSend: es
                  ? 'Capnografía en emergencias: confirmación de intubación (curva cuadrada, EtCO₂ > 20), monitoreo de RCP (meta EtCO₂ > 10), ROAS y broncoespasmo (curva en tiburón).'
                  : 'Capnografia na emergência: confirmação de intubação (curva quadrada, EtCO₂ > 20), monitoramento de RCP (meta EtCO₂ > 10), ROAS e broncoespasmo (curva em tubarão).',
            ),
          ], chatHistory);
        }

      // ── 27. Ventilação Mecânica ─────────────────────────────────────────────
      case ClinicalTopic.ventilacao:
        if (isPlantaoMode) {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Parámetros iniciales VM' : 'Parâmetros iniciais VM',
              promptToSend: es
                  ? 'Configuración inicial del ventilador mecánico: volumen tidal 6ml/kg IBW, PEEP inicial, FiO₂ 100% luego titular, frecuencia y alarmas de meseta.'
                  : 'Configuração inicial do ventilador mecânico: volume corrente 6ml/kg PI, PEEP inicial, FiO₂ 100% depois titular, frequência e alarmes de platô.',
            ),
            SmartNextAction(
              label: es ? 'Auto-PEEP: identificar y resolver' : 'Auto-PEEP: identificar e resolver',
              promptToSend: es
                  ? 'Auto-PEEP en ventilación mecánica: detección (maniobra de pausa espiratoria), consecuencias hemodinámicas, causas (broncoespasmo, frecuencia elevada) y ajuste de I:E para resolución.'
                  : 'Auto-PEEP na ventilação mecânica: detecção (manobra de pausa expiratória), consequências hemodinâmicas, causas (broncoespasmo, frequência elevada) e ajuste de I:E para resolução.',
            ),
            SmartNextAction(
              label: es ? 'Desmame ventilatório: protocolo' : 'Desmame ventilatório: protocolo',
              promptToSend: es
                  ? 'Protocolo de weaning ventilatório: criterios de elegibilidad (SBT), prueba de respiración espontánea (PSV 5/5), criterios de éxito/fracaso, extubación y riesgo de re-intubación.'
                  : 'Protocolo de desmame ventilatório: critérios de elegibilidade (TRE), teste de respiração espontânea (PSV 5/5), critérios de sucesso/falha, extubação e risco de re-intubação.',
            ),
          ], chatHistory);
        } else {
          return _pickAction([
            SmartNextAction(
              label: es ? 'SDRA: estrategia protectora' : 'SDRA: estratégia protetora',
              promptToSend: es
                  ? 'Ventilación protectora en SDRA: volumen tidal 6ml/kg, presión meseta < 30cmH₂O, driving pressure < 15cmH₂O, PEEP tabla ARDSnet y posición prona.'
                  : 'Ventilação protetora no SDRA: volume corrente 6ml/kg, pressão de platô < 30cmH₂O, driving pressure < 15cmH₂O, PEEP tabela ARDSnet e pronação.',
            ),
            SmartNextAction(
              label: es ? 'Pronación en SDRA: protocolo' : 'Pronação no SDRA: protocolo',
              promptToSend: es
                  ? 'Posición prona en SDRA moderado-grave (PaO₂/FiO₂ < 150): ciclos de 16h, criterios de respuesta, complicaciones (úlceras por presión, desplazamiento de sonda) y evidencia PROSEVA.'
                  : 'Posição prona no SDRA moderado-grave (PaO₂/FiO₂ < 150): ciclos de 16h, critérios de resposta, complicações (úlceras por pressão, deslocamento de sonda) e evidência PROSEVA.',
            ),
            SmartNextAction(
              label: es ? 'Modos ventilatorios: comparación' : 'Modos ventilatórios: comparação',
              promptToSend: es
                  ? 'Comparación de modos ventilatorios: VCV (volumen control), PCV (presión control), PRVC, SIMV y PSV — ventajas, limitaciones, asincronias y elección por situación clínica.'
                  : 'Comparação de modos ventilatórios: VCV (volume controlado), PCV (pressão controlada), PRVC, SIMV e PSV — vantagens, limitações, assincronias e escolha por situação clínica.',
            ),
          ], chatHistory);
        }

      // ── 28. Sedação ────────────────────────────────────────────────────────
      case ClinicalTopic.sedacao:
        if (isPlantaoMode) {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Protocolo ABCDEF UCI' : 'Protocolo ABCDEF UTI',
              promptToSend: es
                  ? 'Bundle ABCDEF en UCI: Awaken + Breathing + Coordination + Delirium + Early mobility + Family — impacto en mortalidad y días de ventilación.'
                  : 'Bundle ABCDEF na UTI: Awaken + Breathing + Coordination + Delirium + Early mobility + Family — impacto em mortalidade e dias de ventilação.',
            ),
            SmartNextAction(
              label: es ? 'Escala RASS: objetivo sedación' : 'Escala RASS: objetivo sedação',
              promptToSend: es
                  ? 'Escala RASS en UCI: niveles (-5 a +4), meta de sedación ligera (RASS -1 a 0), interrupción diaria y criterios para profundizar (SDRA grave, status epiléptico, ECMO).'
                  : 'Escala RASS na UTI: níveis (-5 a +4), meta de sedação leve (RASS -1 a 0), interrupção diária e critérios para aprofundar (SDRA grave, status epiléptico, ECMO).',
            ),
            SmartNextAction(
              label: es ? 'Síndrome de abstinencia: sedación' : 'Síndrome de abstinência: sedação',
              promptToSend: es
                  ? 'Síndrome de abstinencia a sedoanalgesia en UCI: manifestaciones (agitación, fiebre, taquicardia), diagnóstico diferencial con delirium, protocolo de retirada gradual y clonidina.'
                  : 'Síndrome de abstinência à sedoanalgesia na UTI: manifestações (agitação, febre, taquicardia), diagnóstico diferencial com delirium, protocolo de retirada gradual e clonidina.',
            ),
          ], chatHistory);
        } else {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Propofol × Dexmedetomidina' : 'Propofol × Dexmedetomidina',
              promptToSend: es
                  ? 'Compara propofol versus dexmedetomidina para sedación en UCI: mecanismo, profundidad, ventajas, toxicidad y cuándo preferir uno sobre el otro.'
                  : 'Compare propofol versus dexmedetomidina para sedação em UTI: mecanismo, profundidade, vantagens, toxicidade e quando preferir um sobre o outro.',
            ),
            SmartNextAction(
              label: es ? 'Analgesia-first: sedación' : 'Analgesia-first: sedação',
              promptToSend: es
                  ? 'Estrategia analgesia-first en UCI: priorizar el control del dolor antes de sedación, fentanilo vs remifentanilo en infusión, reducción de benzodiacepinas y resultados clínicos.'
                  : 'Estratégia analgesia-first na UTI: priorizar controle da dor antes da sedação, fentanil vs remifentanil em infusão, redução de benzodiazepínicos e resultados clínicos.',
            ),
            SmartNextAction(
              label: es ? 'Ketamina en UCI: usos' : 'Cetamina na UTI: usos',
              promptToSend: es
                  ? 'Usos de ketamina en UCI: analgesia (0,1-0,5mg/kg/h), sedación en broncoespasmo, inducción en SIR, status epiléptico refractario — mecanismo NMDA, efectos disociativos y alucinaciones.'
                  : 'Usos de cetamina na UTI: analgesia (0,1-0,5mg/kg/h), sedação no broncoespasmo, indução na SRI, status epiléptico refratário — mecanismo NMDA, efeitos dissociativos e alucinações.',
            ),
          ], chatHistory);
        }

      // ── 29. Analgesia ──────────────────────────────────────────────────────
      case ClinicalTopic.analgesia:
        if (isPlantaoMode) {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Equianalgesia: conversión' : 'Equianalgesia: conversão',
              promptToSend: es
                  ? 'Tabla de equianalgesia opiácea: morfina IV como referencia, conversión a fentanilo, oxicodona, tramadol y metadona. Cálculo de dosis de rescate.'
                  : 'Tabela de equianalgesia opiácea: morfina IV como referência, conversão para fentanil, oxicodona, tramadol e metadona. Cálculo de dose de resgate.',
            ),
            SmartNextAction(
              label: es ? 'Naloxona: protocolo urgente' : 'Naloxona: protocolo urgente',
              promptToSend: es
                  ? 'Uso de naloxona en sobredosis por opioides: dosis 0,4-0,8mg IV/IM/SC/intranasal, titulación hasta respuesta, duración de acción vs opioides de larga duración y re-sedación.'
                  : 'Uso de naloxona na superdosagem por opioides: dose 0,4-0,8mg IV/IM/SC/intranasal, titulação até resposta, duração de ação vs opioides de longa duração e re-sedação.',
            ),
            SmartNextAction(
              label: es ? 'Opioides: efectos adversos' : 'Opioides: efeitos adversos',
              promptToSend: es
                  ? 'Manejo de efectos adversos de opioides: náuseas (ondansetrón, metoclopramida), constipación (naloxegol, metilnaltrexona), prurito (naloxona baixa dose) e depresión respiratoria.'
                  : 'Manejo de efeitos adversos de opioides: náuseas (ondansetrona, metoclopramida), constipação (naloxegol, metilnaltrexona), prurido (naloxona baixa dose) e depressão respiratória.',
            ),
          ], chatHistory);
        } else {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Escala analgésica OMS' : 'Escada analgésica OMS',
              promptToSend: es
                  ? 'Escalera analgésica de la OMS: degrau 1 (AINE/paracetamol), degrau 2 (tramadol), degrau 3 (opioides fuertes), adjuvantes y principio de tratamento.'
                  : 'Escada analgésica da OMS: degrau 1 (AINE/paracetamol), degrau 2 (tramadol), degrau 3 (opioides fortes), adjuvantes e princípio do tratamento.',
            ),
            SmartNextAction(
              label: es ? 'Dolor neuropático: tratamiento' : 'Dor neuropática: tratamento',
              promptToSend: es
                  ? 'Tratamiento del dolor neuropático: gabapentina, pregabalina, duloxetina, amitriptilina (dosis analgésicas < 75mg), lidocaína tópica — mecanismos, dosis y perfil de paciente.'
                  : 'Tratamento da dor neuropática: gabapentina, pregabalina, duloxetina, amitriptilina (doses analgésicas < 75mg), lidocaína tópica — mecanismos, doses e perfil de paciente.',
            ),
            SmartNextAction(
              label: es ? 'Analgesia multimodal: concepto' : 'Analgesia multimodal: conceito',
              promptToSend: es
                  ? 'Analgesia multimodal perioperatoria: combinación de paracetamol, AINE, gabapentinoides, ketamina, opioides (ERAS protocol) — sinergismo, reducción de opioides y resultados.'
                  : 'Analgesia multimodal perioperatória: combinação de paracetamol, AINE, gabapentinoides, cetamina, opioides (protocolo ERAS) — sinergismo, redução de opioides e resultados.',
            ),
          ], chatHistory);
        }

      // ── 30. Antibióticos ───────────────────────────────────────────────────
      case ClinicalTopic.antibioticos:
        if (isPlantaoMode) {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Desescalar antibiótico' : 'Desescalar antibiótico',
              promptToSend: es
                  ? 'Criterios y timing para desescalada antibiótica en UTI: cuándo hacer, cultivos definitivos, PK/PD, duración óptima y impacto en resistencia bacteriana.'
                  : 'Critérios e timing para desescalonamento antibiótico em UTI: quando fazer, culturas definitivas, PK/PD, duração ótima e impacto em resistência bacteriana.',
            ),
            SmartNextAction(
              label: es ? 'Vancomicina: dosificación AUC' : 'Vancomicina: dosagem AUC',
              promptToSend: es
                  ? 'Monitoreo de vancomicina por AUC/MIC (meta 400-600 mg·h/L): ventajas sobre tropos, dosis de carga, ajuste por función renal, riesgo de nefrotoxicidad y duración óptima.'
                  : 'Monitoramento de vancomicina por AUC/MIC (meta 400-600 mg·h/L): vantagens sobre troughs, dose de ataque, ajuste por função renal, risco de nefrotoxicidade e duração ótima.',
            ),
            SmartNextAction(
              label: es ? 'MRSA: opciones terapéuticas' : 'MRSA: opções terapêuticas',
              promptToSend: es
                  ? 'Opciones terapéuticas para infecciones por MRSA: vancomicina, daptomicina (bacteriemia, endocarditis), linezolida (pneumonia), ceftarolina — espectro, dosificación y resistencias emergentes.'
                  : 'Opções terapêuticas para infecções por MRSA: vancomicina, daptomicina (bacteriemia, endocardite), linezolida (pneumonia), ceftarolina — espectro, dosagem e resistências emergentes.',
            ),
          ], chatHistory);
        } else {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Carbapenemes × colistina' : 'Carbapenemes × colistina',
              promptToSend: es
                  ? 'Comparación carbapenemes versus colistina en infecciones por gram-negativos multirresistentes: mecanismo, KPC, OXA-48, dosificación renal y toxicidades.'
                  : 'Comparação carbapenemes versus colistina em infecções por gram-negativos multirresistentes: mecanismo, KPC, OXA-48, dosagem renal e toxicidades.',
            ),
            SmartNextAction(
              label: es ? 'PK/PD antibióticos: principios' : 'PK/PD antibióticos: princípios',
              promptToSend: es
                  ? 'Principios PK/PD en antibioticoterapia: tiempo-dependientes (betalactámicos: T>MIC), concentración-dependientes (aminoglucósidos: Cmax/MIC), AUC-dependientes (quinolonas, vancomicina).'
                  : 'Princípios PK/PD na antibioticoterapia: tempo-dependentes (betalactâmicos: T>MIC), concentração-dependentes (aminoglicosídeos: Cmax/MIC), AUC-dependentes (quinolonas, vancomicina).',
            ),
            SmartNextAction(
              label: es ? 'Resistencia antibiótica: mecanismos' : 'Resistência antibiótica: mecanismos',
              promptToSend: es
                  ? 'Mecanismos de resistencia bacteriana: producción de betalactamasas (ESBL, KPC), bombas de eflujo, alteración de porinas, modificación de diana — implicaciones clínicas y ESKAPE.'
                  : 'Mecanismos de resistência bacteriana: produção de betalactamases (ESBL, KPC), bombas de efluxo, alteração de porinas, modificação de alvo — implicações clínicas e ESKAPE.',
            ),
          ], chatHistory);
        }

      // ── 31. Obstetrícia ────────────────────────────────────────────────────
      case ClinicalTopic.obstetricia:
        if (isPlantaoMode) {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Eclampsia: sulfato Mg' : 'Eclâmpsia: sulfato Mg',
              promptToSend: es
                  ? 'Protocolo de eclampsia: sulfato de magnesio dosis de ataque 4-6g IV + mantenimiento 1-2g/h, control de PA, parto de urgencia y manejo de toxicidad por Mg.'
                  : 'Protocolo de eclâmpsia: sulfato de magnésio dose de ataque 4-6g IV + manutenção 1-2g/h, controle de PA, parto de urgência e manejo de toxicidade por Mg.',
            ),
            SmartNextAction(
              label: es ? 'Antihipertensivos en embarazo' : 'Anti-hipertensivos na gravidez',
              promptToSend: es
                  ? 'Antihipertensivos seguros en el embarazo: alfametildopa, nifedipino, hidralazina (urgencias) — cuáles evitar (IECA, BRA, atenolol) y meta de PA en preeclampsia.'
                  : 'Anti-hipertensivos seguros na gravidez: alfametildopa, nifedipino, hidralazina (urgências) — quais evitar (IECA, BRA, atenolol) e meta de PA na pré-eclâmpsia.',
            ),
            SmartNextAction(
              label: es ? 'HELLP: diagnóstico y manejo' : 'HELLP: diagnóstico e manejo',
              promptToSend: es
                  ? 'Síndrome HELLP: criterios diagnósticos (hemólisis, enzimas hepáticas elevadas, plaquetas < 100k), manejo con MgSO4, corticoide, parto urgente y complicaciones (hematoma hepático).'
                  : 'Síndrome HELLP: critérios diagnósticos (hemólise, enzimas hepáticas elevadas, plaquetas < 100k), manejo com MgSO4, corticoide, parto urgente e complicações (hematoma hepático).',
            ),
          ], chatHistory);
        } else {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Pré-eclâmpsia × eclampsia' : 'Pré-eclâmpsia × eclâmpsia',
              promptToSend: es
                  ? 'Fisiopatología y criterios diagnósticos de preeclampsia con y sin características graves, versus eclampsia y síndrome HELLP.'
                  : 'Fisiopatologia e critérios diagnósticos de pré-eclâmpsia com e sem características graves, versus eclâmpsia e síndrome HELLP.',
            ),
            SmartNextAction(
              label: es ? 'Fármacos seguros en embarazo' : 'Fármacos seguros na gravidez',
              promptToSend: es
                  ? 'Clasificación de fármacos en el embarazo: categorías FDA A/B/C/D/X (antiguas) y el nuevo sistema PLLR — ejemplos prácticos de antibióticos, analgésicos y anticoagulantes seguros.'
                  : 'Classificação de fármacos na gravidez: categorias FDA A/B/C/D/X (antigas) e o novo sistema PLLR — exemplos práticos de antibióticos, analgésicos e anticoagulantes seguros.',
            ),
            SmartNextAction(
              label: es ? 'Sepsis en el puerperio' : 'Sepse no puerpério',
              promptToSend: es
                  ? 'Sepsis puerperal: agentes más frecuentes (S. pyogenes, E. coli, S. aureus), fuentes (endometritis, mastitis, herida quirúrgica), antibioticoterapia y factores de riesgo.'
                  : 'Sepse puerperal: agentes mais frequentes (S. pyogenes, E. coli, S. aureus), fontes (endometrite, mastite, ferida cirúrgica), antibioticoterapia e fatores de risco.',
            ),
          ], chatHistory);
        }

      // ── 32. Pediatria ──────────────────────────────────────────────────────
      case ClinicalTopic.pediatria:
        if (isPlantaoMode) {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Dosis pediátrica: cálculo' : 'Dose pediátrica: cálculo',
              promptToSend: es
                  ? 'Principios de cálculo de dosis pediátricas por peso: mg/kg, dosis máxima del adulto como techo, fármacos contraindicados por edad y ajuste por función renal.'
                  : 'Princípios de cálculo de doses pediátricas por peso: mg/kg, dose máxima do adulto como teto, fármacos contraindicados por idade e ajuste por função renal.',
            ),
            SmartNextAction(
              label: es ? 'Sepsis pediátrica: protocolo' : 'Sepse pediátrica: protocolo',
              promptToSend: es
                  ? 'Reconocimiento y manejo de sepsis pediátrica: criterios SIRS adaptados por edad, acceso IV/IO, bolo de cristaloides 10-20ml/kg, antibiótico ≤ 1h y vasopresores si refractario.'
                  : 'Reconhecimento e manejo da sepse pediátrica: critérios SIRS adaptados por idade, acesso IV/IO, bolus de cristaloides 10-20ml/kg, antibiótico ≤ 1h e vasopressores se refratário.',
            ),
            SmartNextAction(
              label: es ? 'RCP pediátrica: PALS' : 'RCP pediátrica: PALS',
              promptToSend: es
                  ? 'Algoritmo PALS de paro cardiorrespiratorio pediátrico: RCP 15:2 (2 reanimadores), adrenalina 0,01mg/kg IV/IO cada 3-5min, desfibrilación 2-4J/kg y causas reversibles 6H6T.'
                  : 'Algoritmo PALS de parada cardiorrespiratória pediátrica: RCP 15:2 (2 reanimadores), adrenalina 0,01mg/kg IV/IO cada 3-5min, desfibrilação 2-4J/kg e causas reversíveis 6H6T.',
            ),
          ], chatHistory);
        } else {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Desarrollo pediátrico' : 'Desenvolvimento pediátrico',
              promptToSend: es
                  ? 'Hitos del desarrollo neuropsicomotor: motor grueso, fino, lenguaje y social en los primeros 5 años — señales de alarma y derivación.'
                  : 'Marcos do desenvolvimento neuropsicomotor: motor grosso, fino, linguagem e social nos primeiros 5 anos — sinais de alarme e encaminhamento.',
            ),
            SmartNextAction(
              label: es ? 'Bronquiolitis: manejo' : 'Bronquiolite: manejo',
              promptToSend: es
                  ? 'Manejo de bronquiolitis en lactantes: soporte (hidratación, O₂ nasal de alto flujo), evidencia CONTRA broncodilatadores y corticoides, criterios de UCI e indicaciones de adrenalina nebulizada.'
                  : 'Manejo da bronquiolite em lactentes: suporte (hidratação, O₂ nasal de alto fluxo), evidência CONTRA broncodilatadores e corticoides, critérios de UTI e indicações de adrenalina nebulizada.',
            ),
            SmartNextAction(
              label: es ? 'Fiebre sin foco: estratificación' : 'Febre sem foco: estratificação',
              promptToSend: es
                  ? 'Estratificación de lactante con fiebre sin foco: algoritmos Step-by-Step y PECARN, edad (< 28d, 28-90d, > 90d), procalcitonina, punción lumbar y criterios de hospitalización.'
                  : 'Estratificação do lactente com febre sem foco: algoritmos Step-by-Step e PECARN, faixa etária (< 28d, 28-90d, > 90d), procalcitonina, punção lombar e critérios de internação.',
            ),
          ], chatHistory);
        }

      // ── 33. Trauma ─────────────────────────────────────────────────────────
      case ClinicalTopic.trauma:
        if (isPlantaoMode) {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Control de hemorragia' : 'Controle de hemorragia',
              promptToSend: es
                  ? 'Damage control resuscitation en trauma: transfusión hemostática 1:1:1 (CH:PFC:plaquetas), ácido tranexámico, hipotensión permisiva y cuándo ir al quirófano.'
                  : 'Damage control resuscitation no trauma: transfusão hemostática 1:1:1 (CH:PFC:plaquetas), ácido tranexâmico, hipotensão permissiva e quando ir ao centro cirúrgico.',
            ),
            SmartNextAction(
              label: es ? 'TCE grave: manejo PIC' : 'TCE grave: manejo PIC',
              promptToSend: es
                  ? 'Manejo del traumatismo craneoencefálico grave: osmoterapia (manitol vs solución hipertónica), PPC meta 60-70mmHg, monitoreo de PIC, ventilación normocápnica y craniectomía descompresiva.'
                  : 'Manejo do traumatismo cranioencefálico grave: osmoterapia (manitol vs solução hipertônica), PPC meta 60-70mmHg, monitoramento de PIC, ventilação normocápnica e craniectomia descompressiva.',
            ),
            SmartNextAction(
              label: es ? 'Trauma torácico: urgencias' : 'Trauma torácico: urgências',
              promptToSend: es
                  ? 'Urgencias en trauma torácico: neumotórax a tensión (descompresión inmediata), hemotórax masivo (toracostomía + drenaje), taponamiento (pericardiocentesis) y criterios de toracotomía.'
                  : 'Urgências no trauma torácico: pneumotórax hipertensivo (descompressão imediata), hemotórax maciço (toracostomia + drenagem), tamponamento (pericardiocentese) e critérios de toracotomia.',
            ),
          ], chatHistory);
        } else {
          return _pickAction([
            SmartNextAction(
              label: es ? 'ATLS: ABCDE del trauma' : 'ATLS: ABCDE do trauma',
              promptToSend: es
                  ? 'Protocolo ATLS de atención primaria en trauma: A (vía aérea), B (respiración), C (circulación), D (neurológico), E (exposición) — hallazgos y acciones en cada etapa.'
                  : 'Protocolo ATLS de atendimento primário no trauma: A (via aérea), B (respiração), C (circulação), D (neurológico), E (exposição) — achados e ações em cada etapa.',
            ),
            SmartNextAction(
              label: es ? 'Clasificación del trauma: escores' : 'Classificação do trauma: escores',
              promptToSend: es
                  ? 'Escores de gravidade en trauma: ISS (Injury Severity Score), RTS (Revised Trauma Score), TRISS — cálculo, interpretación, predicción de mortalidad y triage de activación.'
                  : 'Escores de gravidade no trauma: ISS (Injury Severity Score), RTS (Revised Trauma Score), TRISS — cálculo, interpretação, predição de mortalidade e triagem de ativação.',
            ),
            SmartNextAction(
              label: es ? 'Trauma abdominal: decisión quirúrgica' : 'Trauma abdominal: decisão cirúrgica',
              promptToSend: es
                  ? 'FAST extendido e indicaciones de laparotomía en trauma abdominal: trauma penetrante (laparotomía directa), contuso (FAST, TC según estabilidad) y damage control abdominal.'
                  : 'FAST estendido e indicações de laparotomia no trauma abdominal: penetrante (laparotomia direta), contuso (FAST, TC conforme estabilidade) e damage control abdominal.',
            ),
          ], chatHistory);
        }

      // ── 34. Queimadura ─────────────────────────────────────────────────────
      case ClinicalTopic.queimadura:
        if (isPlantaoMode) {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Parkland: volumen IV' : 'Parkland: volume IV',
              promptToSend: es
                  ? 'Fórmula de Parkland para reposición hídrica en quemaduras: 4ml × kg × %SCQ, volumen 1ª mitad nas 8h, 2ª mitad nas 16h y monitorización por diuresis.'
                  : 'Fórmula de Parkland para reposição hídrica em queimaduras: 4ml × kg × %SCQ, volume 1ª metade nas 8h, 2ª metade nas 16h e monitorização por diurese.',
            ),
            SmartNextAction(
              label: es ? 'Quemadura de vía aérea: manejo' : 'Queimadura de via aérea: manejo',
              promptToSend: es
                  ? 'Lesión inhalatoria en quemaduras: signos clínicos (estridor, carbonilla, quemadura facial), indicación de intubación precoz, broncoscopia diagnóstica y manejo de intoxicación por CO.'
                  : 'Lesão inalatória em queimaduras: sinais clínicos (estridor, fuligem, queimadura facial), indicação de intubação precoce, broncoscopia diagnóstica e manejo de intoxicação por CO.',
            ),
            SmartNextAction(
              label: es ? 'Escarotomía: indicaciones' : 'Escarotomia: indicações',
              promptToSend: es
                  ? 'Indicaciones de escarotomía en quemaduras circunferenciales: síndrome compartimental, quemaduras de 3° en extremidades o tórax, técnica incisional y criterios de fasciotomía adicional.'
                  : 'Indicações de escarotomia em queimaduras circunferenciais: síndrome compartimental, queimaduras de 3° em extremidades ou tórax, técnica incisional e critérios de fasciotomia adicional.',
            ),
          ], chatHistory);
        } else {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Clasificación quemaduras' : 'Classificação queimaduras',
              promptToSend: es
                  ? 'Clasificación de quemaduras por profundidad: 1° (epidermis), 2° superficial y profunda (dermis), 3° (hipodermis) — características clínicas y cicatrización.'
                  : 'Classificação de queimaduras por profundidade: 1° (epiderme), 2° superficial e profunda (derme), 3° (hipoderme) — características clínicas e cicatrização.',
            ),
            SmartNextAction(
              label: es ? 'SCQ: regla de los 9' : 'SCQ: regra dos 9',
              promptToSend: es
                  ? 'Estimación de la superficie corporal quemada: regla de los 9 (adultos), regla de Lund-Browder (niños), palma del paciente = 1% — precisión, limitaciones y referencia a centro de quemados.'
                  : 'Estimativa da superfície corporal queimada: regra dos 9 (adultos), regra de Lund-Browder (crianças), palma do paciente = 1% — precisão, limitações e referência a centro de queimados.',
            ),
            SmartNextAction(
              label: es ? 'Infección en quemaduras' : 'Infecção em queimaduras',
              promptToSend: es
                  ? 'Infección de quemaduras: Pseudomonas aeruginosa, S. aureus, Candida — diagnóstico (cultivo cuantitativo > 10⁵/g), antibioticoterapia, antisépticos tópicos y criterios de sepsis por quemadura.'
                  : 'Infecção em queimaduras: Pseudomonas aeruginosa, S. aureus, Candida — diagnóstico (cultura quantitativa > 10⁵/g), antibioticoterapia, antissépticos tópicos e critérios de sepse por queimadura.',
            ),
          ], chatHistory);
        }

      // ── 35. Toxicologia ─────────────────────────────────────────────────────
      case ClinicalTopic.toxicologia:
        if (isPlantaoMode) {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Antídoto por síndrome' : 'Antídoto por síndrome',
              promptToSend: es
                  ? 'Tabla de toxidromes y antídotos urgentes: opioide (naloxona), benzo (flumazenil), organofosforado (atropina), paracetamol (NAC), digitálico (anticuerpos Fab).'
                  : 'Tabela de toxíndromes e antídotos urgentes: opioide (naloxona), benzo (flumazenil), organofosforado (atropina), paracetamol (NAC), digitálico (anticorpos Fab).',
            ),
            SmartNextAction(
              label: es ? 'Descontaminación GI: indicaciones' : 'Descontaminação GI: indicações',
              promptToSend: es
                  ? 'Descontaminación gastrointestinal en intoxicaciones: carbón activado (indicaciones, dosis, cuándo NO usar), lavado gástrico (< 1h, raro), catártico y diuresis forzada alcalina (salicilatos).'
                  : 'Descontaminação gastrointestinal nas intoxicações: carvão ativado (indicações, dose, quando NÃO usar), lavagem gástrica (< 1h, raro), catártico e diurese forçada alcalina (salicilatos).',
            ),
            SmartNextAction(
              label: es ? 'Intoxicación organofosforado' : 'Intoxicação organofosforado',
              promptToSend: es
                  ? 'Intoxicación por organofosforados: síndrome muscarínico (SLUDGE+BB), nicotínico y central, atropina (titular hasta secar secreciones), pralidoxima (reactivador) y criterios de ventilación.'
                  : 'Intoxicação por organofosforados: síndrome muscarínico (SLUDGE+BB), nicotínico e central, atropina (titular até secar secreções), pralidoxima (reativador) e critérios de ventilação.',
            ),
          ], chatHistory);
        } else {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Intoxicación paracetamol' : 'Intoxicação paracetamol',
              promptToSend: es
                  ? 'Fisiopatología de la intoxicación por paracetamol: metabolismo NAPQI, necrosis hepática, nomograma de Rumack-Matthew y protocolo de N-acetilcisteína IV.'
                  : 'Fisiopatologia da intoxicação por paracetamol: metabolismo NAPQI, necrose hepática, nomograma de Rumack-Matthew e protocolo de N-acetilcisteína IV.',
            ),
            SmartNextAction(
              label: es ? 'Toxidromes: clasificación' : 'Toxíndromes: classificação',
              promptToSend: es
                  ? 'Clasificación de toxidromes: simpaticomimético, anticolinérgico, colinérgico, opiáceo, sedante-hipnótico y serotoninérgico — signos vitales, pupilas, piel y tratamiento de cada uno.'
                  : 'Classificação de toxíndromes: simpaticomimético, anticolinérgico, colinérgico, opiáceo, sedativo-hipnótico e serotoninérgico — sinais vitais, pupilas, pele e tratamento de cada um.',
            ),
            SmartNextAction(
              label: es ? 'Intoxicación por digitálico' : 'Intoxicação por digitálico',
              promptToSend: es
                  ? 'Intoxicación digitálica: síntomas (bradiarritmias, xantopsia, náuseas), niveles de digoxina, hipercalemia como marcador de gravedad, anticuerpos anti-Fab y criterios de marcapasso.'
                  : 'Intoxicação digitálica: sintomas (bradiarritmias, xantopsia, náuseas), níveis de digoxina, hipercalemia como marcador de gravidade, anticorpos anti-Fab e critérios de marcapasso.',
            ),
          ], chatHistory);
        }

      // ── 36. Psiquiatria ─────────────────────────────────────────────────────
      case ClinicalTopic.psiquiatria:
        if (isPlantaoMode) {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Agitación psicomotora' : 'Agitação psicomotora',
              promptToSend: es
                  ? 'Protocolo de contención farmacológica en agitación psicomotora: haloperidol + midazolam, droperidol, olanzapina IM — dosis, vías, monitorización y seguridad.'
                  : 'Protocolo de contenção farmacológica na agitação psicomotora: haloperidol + midazolam, droperidol, olanzapina IM — doses, vias, monitorização e segurança.',
            ),
            SmartNextAction(
              label: es ? 'SNM: diagnóstico y tratamiento' : 'SNM: diagnóstico e tratamento',
              promptToSend: es
                  ? 'Síndrome neuroléptico maligno: triada (rigidez, fiebre, disautonomía) + CPK elevada, diagnóstico diferencial con serotonínérgico, tratamiento (bromocriptina, dantroleno, soporte).'
                  : 'Síndrome neuroléptica maligna: tríade (rigidez, febre, disautonomia) + CPK elevada, diagnóstico diferencial com serotoninérgico, tratamento (bromocriptina, dantroleno, suporte).',
            ),
            SmartNextAction(
              label: es ? 'Riesgo de suicidio: evaluación' : 'Risco de suicídio: avaliação',
              promptToSend: es
                  ? 'Evaluación del riesgo suicida en urgencias: Columbia Suicide Severity Rating Scale (C-SSRS), factores de riesgo (intentos previos, plan, medio disponible) y criterios de internación involuntaria.'
                  : 'Avaliação do risco suicida na emergência: Columbia Suicide Severity Rating Scale (C-SSRS), fatores de risco (tentativas prévias, plano, meio disponível) e critérios de internação involuntária.',
            ),
          ], chatHistory);
        } else {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Antipsicóticos: mecanismo' : 'Antipsicóticos: mecanismo',
              promptToSend: es
                  ? 'Mecanismo de acción de los antipsicóticos: bloqueo D2, receptores 5-HT2A, efectos extrapiramidales, síndrome neuroléptico maligno y diferencia típicos × atípicos.'
                  : 'Mecanismo de ação dos antipsicóticos: bloqueio D2, receptores 5-HT2A, efeitos extrapiramidais, síndrome neuroléptica maligna e diferença típicos × atípicos.',
            ),
            SmartNextAction(
              label: es ? 'Litio: monitoreo y toxicidad' : 'Lítio: monitoramento e toxicidade',
              promptToSend: es
                  ? 'Monitorización y toxicidad del litio: nivel terapéutico (0,6-1,2 mEq/L), signos de toxicidad leve/moderada/grave, factores precipitantes (AINE, diuréticos, deshidratación) y manejo urgente.'
                  : 'Monitoramento e toxicidade do lítio: nível terapêutico (0,6-1,2 mEq/L), sinais de toxicidade leve/moderada/grave, fatores precipitantes (AINE, diuréticos, desidratação) e manejo urgente.',
            ),
            SmartNextAction(
              label: es ? 'Esquizofrenia: tratamiento' : 'Esquizofrenia: tratamento',
              promptToSend: es
                  ? 'Tratamiento de la esquizofrenia: antipsicóticos de 1ª línea (risperidona, olanzapina, quetiapina), clozapina en refractaria, monitoreo metabólico y adherencia con inyectables de depósito.'
                  : 'Tratamento da esquizofrenia: antipsicóticos de 1ª linha (risperidona, olanzapina, quetiapina), clozapina na refratária, monitoramento metabólico e adesão com injetáveis de depósito.',
            ),
          ], chatHistory);
        }

      // ── 37. Hematologia ─────────────────────────────────────────────────────
      case ClinicalTopic.hematologia:
        if (isPlantaoMode) {
          return _pickAction([
            SmartNextAction(
              label: es ? 'CID: tratamiento urgente' : 'CIVD: tratamento urgente',
              promptToSend: es
                  ? 'Manejo de CID aguda: plasma fresco, crioprecipitado (fibrinógeno < 1,5g/L), plaquetas (< 50k + sangrado activo) y tratar causa desencadenante.'
                  : 'Manejo da CIVD aguda: plasma fresco, crioprecipitado (fibrinogênio < 1,5g/L), plaquetas (< 50k + sangramento ativo) e tratar causa desencadeante.',
            ),
            SmartNextAction(
              label: es ? 'Transfusión: umbrales y criterios' : 'Transfusão: limiares e critérios',
              promptToSend: es
                  ? 'Estrategia restrictiva de transfusión: umbral Hb < 7g/dL (ICU no cardiológica), < 8g/dL (cirugía, cardiopatía), consentimiento, complicaciones transfusionales y TACO vs TRALI.'
                  : 'Estratégia restritiva de transfusão: limiar Hb < 7g/dL (UTI não cardiológica), < 8g/dL (cirurgia, cardiopatia), consentimento, complicações transfusionais e TACO vs TRALI.',
            ),
            SmartNextAction(
              label: es ? 'Neutropenia febril: urgente' : 'Neutropenia febril: urgente',
              promptToSend: es
                  ? 'Manejo de neutropenia febril: definición (neutrófilos < 500 + fiebre ≥ 38,3°C), cultivos urgentes, antibiótico en < 60 min (cefepime, pip-tazo), MASCC score y cuándo agregar cobertura fúngica.'
                  : 'Manejo da neutropenia febril: definição (neutrófilos < 500 + febre ≥ 38,3°C), culturas urgentes, antibiótico em < 60 min (cefepime, pip-tazo), escore MASCC e quando adicionar cobertura fúngica.',
            ),
          ], chatHistory);
        } else {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Anemias: clasificación' : 'Anemias: classificação',
              promptToSend: es
                  ? 'Clasificación de anemias por VCM: microcítica (ferropénica, talasemia), normocítica (hemolítica, crónica) y macrocítica (B12, folato) — enfoque diagnóstico.'
                  : 'Classificação das anemias por VCM: microcítica (ferropriva, talassemia), normocítica (hemolítica, doença crônica) e macrocítica (B12, folato) — abordagem diagnóstica.',
            ),
            SmartNextAction(
              label: es ? 'Anemia hemolítica: diagnóstico' : 'Anemia hemolítica: diagnóstico',
              promptToSend: es
                  ? 'Diagnóstico de anemia hemolítica: LDH elevada, bilirrubina indirecta, haptoglobina baja, reticulocitosis, esquistocitos — clasificación intravascular vs extravascular y causas principales.'
                  : 'Diagnóstico de anemia hemolítica: LDH elevada, bilirrubina indireta, haptoglobina baixa, reticulocitose, esquistócitos — classificação intravascular vs extravascular e causas principais.',
            ),
            SmartNextAction(
              label: es ? 'Hemostasia: cascade coagulación' : 'Hemostasia: cascata de coagulação',
              promptToSend: es
                  ? 'Fisiología de la hemostasia: hemostasia primaria (plaquetas), secundaria (cascada VIA/VII), fibrinólisis — cómo los tests (TP, TTPa, fibrinógeno) detectan defectos específicos.'
                  : 'Fisiologia da hemostasia: hemostasia primária (plaquetas), secundária (cascata VIA/VII), fibrinólise — como os testes (TP, TTPa, fibrinogênio) detectam defeitos específicos.',
            ),
          ], chatHistory);
        }

      // ── 38. Gastro ─────────────────────────────────────────────────────────
      case ClinicalTopic.gastro:
        if (isPlantaoMode) {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Hemorragia digestiva alta' : 'Hemorragia digestiva alta',
              promptToSend: es
                  ? 'Manejo urgente de HDA: estabilización, IBP IV, endoscopia en 24h, escore de Rockall/Blatchford, band ligation y cuándo cirugía de resgate.'
                  : 'Manejo urgente de HDA: estabilização, IBP IV, endoscopia em 24h, escore de Rockall/Blatchford, ligadura elástica de varizes e quando cirurgia de resgate.',
            ),
            SmartNextAction(
              label: es ? 'Ascitis: manejo y paracentesis' : 'Ascite: manejo e paracentese',
              promptToSend: es
                  ? 'Manejo de ascitis en cirrosis: restricción de sodio, espironolactona + furosemida, paracentesis evacuadora (> 5L: albúmina 6-8g/L extraído), criterios de TIPS y peritonitis bacteriana espontánea.'
                  : 'Manejo de ascite na cirrose: restrição de sódio, espironolactona + furosemida, paracentese evacuatória (> 5L: albumina 6-8g/L extraído), critérios de TIPS e peritonite bacteriana espontânea.',
            ),
            SmartNextAction(
              label: es ? 'Pancreatitis aguda: severidad' : 'Pancreatite aguda: severidade',
              promptToSend: es
                  ? 'Estratificación de pancreatitis aguda: Bedside Index of Severity (BISAP), Ranson y APACHE II — diferenciación leve/moderada/grave, indicaciones de UCI y manejo de complicaciones locales.'
                  : 'Estratificação da pancreatite aguda: Bedside Index of Severity (BISAP), Ranson e APACHE II — diferenciação leve/moderada/grave, indicações de UTI e manejo de complicações locais.',
            ),
          ], chatHistory);
        } else {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Child-Pugh × MELD' : 'Child-Pugh × MELD',
              promptToSend: es
                  ? 'Comparación Child-Pugh versus MELD en cirrosis hepática: variables, puntuación, pronóstico, indicación de trasplante y limitaciones de cada escala.'
                  : 'Comparação Child-Pugh versus MELD na cirrose hepática: variáveis, pontuação, prognóstico, indicação de transplante e limitações de cada escala.',
            ),
            SmartNextAction(
              label: es ? 'Encefalopatía hepática: tratamiento' : 'Encefalopatia hepática: tratamento',
              promptToSend: es
                  ? 'Tratamiento de la encefalopatía hepática: lactulosa (meta 2-4 deposiciones/día), rifaximina 550mg 2x (profilaxis secundaria), corregir factores precipitantes y trasplante en refractaria.'
                  : 'Tratamento da encefalopatia hepática: lactulose (meta 2-4 evacuações/dia), rifaximina 550mg 2x (profilaxia secundária), corrigir fatores precipitantes e transplante na refratária.',
            ),
            SmartNextAction(
              label: es ? 'Síndrome hepatorrenal: tipos' : 'Síndrome hepatorrenal: tipos',
              promptToSend: es
                  ? 'Síndrome hepatorrenal: tipo 1 (IRA rápida, supervivencia < 2 semanas) vs tipo 2 (más crónico) — criterios ICA-AKI 2015, terlipresina + albúmina, TIPS y trasplante como tratamiento definitivo.'
                  : 'Síndrome hepatorrenal: tipo 1 (IRA rápida, sobrevida < 2 semanas) vs tipo 2 (mais crônico) — critérios ICA-AKI 2015, terlipressina + albumina, TIPS e transplante como tratamento definitivo.',
            ),
          ], chatHistory);
        }

      // ── 39. Endocrinologia ─────────────────────────────────────────────────
      case ClinicalTopic.endocrino:
        if (isPlantaoMode) {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Crise tireotóxica: manejo' : 'Crise tireotóxica: manejo',
              promptToSend: es
                  ? 'Protocolo urgente de crisis tirotóxica: Burch-Wartofsky, propiltiouracilo × metimazol, betabloqueador, corticoide, iodo e resfriamento ativo.'
                  : 'Protocolo urgente de crise tireotóxica: Burch-Wartofsky, propiltiouracil × metimazol, betabloqueador, corticoide, iodo e resfriamento ativo.',
            ),
            SmartNextAction(
              label: es ? 'Crisis adrenal: hidrocortisona' : 'Crise adrenal: hidrocortisona',
              promptToSend: es
                  ? 'Crisis adrenal aguda: hidrocortisona 100mg IV inmediato, luego 50mg IV cada 6h, solución salina 1L rápida, identificar precipitante (infección, cirugía, omisión de corticoide) y mineralocorticoide post-agudo.'
                  : 'Crise adrenal aguda: hidrocortisona 100mg IV imediato, depois 50mg IV a cada 6h, solução salina 1L rápida, identificar precipitante (infecção, cirurgia, omissão de corticoide) e mineralocorticoide pós-agudo.',
            ),
            SmartNextAction(
              label: es ? 'Feocromocitoma: urgencias' : 'Feocromocitoma: urgências',
              promptToSend: es
                  ? 'Crisis hipertensiva por feocromocitoma: fentolamina IV (bloqueador alfa) o nicardipino, NUNCA betabloqueador sin alfa-bloqueo previo, diagnóstico (catecolaminas/metanefrinas urinarias) y cirugía.'
                  : 'Crise hipertensiva por feocromocitoma: fentolamina IV (bloqueador alfa) ou nicardipino, NUNCA betabloqueador sem alfa-bloqueio prévio, diagnóstico (catecolaminas/metanefrinas urinárias) e cirurgia.',
            ),
          ], chatHistory);
        } else {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Hipotiroidismo × Mixedema' : 'Hipotireoidismo × Mixedema',
              promptToSend: es
                  ? 'Diferencia clínica entre hipotiroidismo subclínico, hipotiroidismo clínico y coma mixedematoso: TSH, T4 libre, diagnóstico y tratamiento de emergencia.'
                  : 'Diferença clínica entre hipotireoidismo subclínico, hipotireoidismo clínico e coma mixedematoso: TSH, T4 livre, diagnóstico e tratamento de emergência.',
            ),
            SmartNextAction(
              label: es ? 'Hipertiroidismo: diagnóstico y manejo' : 'Hipertireoidismo: diagnóstico e manejo',
              promptToSend: es
                  ? 'Hipertiroidismo: causas (Graves, bocio multinodular tóxico, adenoma), diagnóstico (TSH suprimido, T4/T3 elevados, anticuerpos), tratamiento médico vs radioyodo vs cirugía.'
                  : 'Hipertireoidismo: causas (Graves, bócio multinodular tóxico, adenoma), diagnóstico (TSH suprimido, T4/T3 elevados, anticorpos), tratamento médico vs radioiodo vs cirurgia.',
            ),
            SmartNextAction(
              label: es ? 'Síndrome de Cushing: diagnóstico' : 'Síndrome de Cushing: diagnóstico',
              promptToSend: es
                  ? 'Diagnóstico de síndrome de Cushing: cortisol libre urinario 24h, cortisol salival nocturno, supresión nocturna con 1mg de dexametasona y diferenciación ACTH-dependiente vs independiente.'
                  : 'Diagnóstico da síndrome de Cushing: cortisol livre urinário 24h, cortisol salivar noturno, supressão noturna com 1mg de dexametasona e diferenciação ACTH-dependente vs independente.',
            ),
          ], chatHistory);
        }

      // ── 40. Infectologia ───────────────────────────────────────────────────
      case ClinicalTopic.infectologia:
        if (isPlantaoMode) {
          return _pickAction([
            SmartNextAction(
              label: es ? 'HIV: infecciones oportunistas' : 'HIV: infecções oportunistas',
              promptToSend: es
                  ? 'Infecciones oportunistas más frecuentes en HIV según CD4: < 200 (pneumocistis, toxoplasma), < 100 (CMV, MAC) — profilaxis y tratamiento de primera línea.'
                  : 'Infecções oportunistas mais frequentes no HIV por CD4: < 200 (pneumocistis, toxoplasma), < 100 (CMV, MAC) — profilaxia e tratamento de primeira linha.',
            ),
            SmartNextAction(
              label: es ? 'Pneumocistosis (PCP): urgente' : 'Pneumocistose (PCP): urgente',
              promptToSend: es
                  ? 'Neumonía por Pneumocystis jirovecii en HIV: presentación (disnea progresiva, LDH elevada, hipoxemia), diagnóstico (LBA), TMP-SMX IV, corticoide si PaO₂ < 70mmHg y profilaxis con CD4 < 200.'
                  : 'Pneumonia por Pneumocystis jirovecii no HIV: apresentação (dispneia progressiva, LDH elevada, hipoxemia), diagnóstico (LBA), TMP-SMX IV, corticoide se PaO₂ < 70mmHg e profilaxia com CD4 < 200.',
            ),
            SmartNextAction(
              label: es ? 'Tuberculosis: manejo inicial' : 'Tuberculose: manejo inicial',
              promptToSend: es
                  ? 'Tratamiento de tuberculosis pulmonar sensible: fase intensiva 2 meses RHZE, fase de mantenimiento 4 meses RH, notificación, aislamiento, DOTS y interacciones con TARV en co-infectados.'
                  : 'Tratamento da tuberculose pulmonar sensível: fase intensiva 2 meses RHZE, fase de manutenção 4 meses RH, notificação, isolamento, DOTS e interações com TARV nos co-infectados.',
            ),
          ], chatHistory);
        } else {
          return _pickAction([
            SmartNextAction(
              label: es ? 'TARV: primera línea' : 'TARV: primeira linha',
              promptToSend: es
                  ? 'Esquema de TARV de primera línea en HIV: 2 ITIAN + 1 INSTI (TDF/FTC + DTG), cuándo iniciar, resistencia primaria y monitorización virológica.'
                  : 'Esquema de TARV de primeira linha no HIV: 2 ITRN + 1 INSTI (TDF/FTC + DTG), quando iniciar, resistência primária e monitorização virológica.',
            ),
            SmartNextAction(
              label: es ? 'Síndrome de reconstitución inmune' : 'Síndrome de reconstituição imune',
              promptToSend: es
                  ? 'IRIS (Immune Reconstitution Inflammatory Syndrome): fisiopatología, presentaciones clínicas (TB-IRIS, criptococo-IRIS), cuándo ocurre, diagnóstico diferencial y manejo con corticoide.'
                  : 'IRIS (Immune Reconstitution Inflammatory Syndrome): fisiopatologia, apresentações clínicas (TB-IRIS, criptococo-IRIS), quando ocorre, diagnóstico diferencial e manejo com corticoide.',
            ),
            SmartNextAction(
              label: es ? 'Dengue: estadificación y manejo' : 'Dengue: estadificação e manejo',
              promptToSend: es
                  ? 'Estadificación OMS 2009 del dengue: fases febril/crítica/recuperación, señales de alarma (plaquetas < 100k, ascitis, sangrado), manejo con hidratación, cuándo hospitalizar y criterios de UCI.'
                  : 'Estadificação OMS 2009 da dengue: fases febril/crítica/recuperação, sinais de alarme (plaquetas < 100k, ascite, sangramento), manejo com hidratação, quando internar e critérios de UTI.',
            ),
          ], chatHistory);
        }

      // ── 41. Hipercalemia ───────────────────────────────────────────────────
      case ClinicalTopic.hipercalemia:
        if (isPlantaoMode) {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Hipercalemia: protocolo K⁺' : 'Hipercalemia: protocolo K⁺',
              promptToSend: es
                  ? 'Protocolo urgente de hipercalemia grave (K⁺ > 6,5): gluconato de calcio IV (estabilizar membrana), insulina + glucosa, salbutamol nebulizado, bicarbonato y diálisis.'
                  : 'Protocolo urgente de hipercalemia grave (K⁺ > 6,5): gluconato de cálcio IV (estabilizar membrana), insulina + glicose, salbutamol nebulizado, bicarbonato e diálise.',
            ),
            SmartNextAction(
              label: es ? 'Gluconato de calcio: cuándo usar' : 'Gluconato de cálcio: quando usar',
              promptToSend: es
                  ? 'Indicaciones de gluconato de calcio en hipercalemia: K⁺ > 6,5 mEq/L o cambios en ECG — dosis (1g IV en 5-10min), mecanismo de estabilización de membrana, repetición y duración del efecto.'
                  : 'Indicações de gluconato de cálcio na hipercalemia: K⁺ > 6,5 mEq/L ou alterações no ECG — dose (1g IV em 5-10min), mecanismo de estabilização de membrana, repetição e duração do efeito.',
            ),
            SmartNextAction(
              label: es ? 'Causas de hipercalemia en UCI' : 'Causas de hipercalemia na UTI',
              promptToSend: es
                  ? 'Causas de hipercalemia en UCI: IRA oligúrica, succinilcolina en quemados/denervados, IECA/BRA/espironolactona, acidosis metabólica, hemólisis/rabdomiólisis y transfusiones masivas.'
                  : 'Causas de hipercalemia na UTI: IRA oligúrica, succinilcolina em queimados/denervados, IECA/BRA/espironolactona, acidose metabólica, hemólise/rabdomiólise e transfusões maciças.',
            ),
          ], chatHistory);
        } else {
          return _pickAction([
            SmartNextAction(
              label: es ? 'ECG e hipercalemia' : 'ECG e hipercalemia',
              promptToSend: es
                  ? 'Progresión de alteraciones electrocardiográficas en hipercalemia: onda T picuda, PR prolongado, onda P aplanada, QRS ancho, sine wave y FV.'
                  : 'Progressão das alterações eletrocardiográficas na hipercalemia: onda T apiculada, PR alargado, onda P achatada, QRS largo, onda sinus e FV.',
            ),
            SmartNextAction(
              label: es ? 'Fisiopatología de la hipercalemia' : 'Fisiopatologia da hipercalemia',
              promptToSend: es
                  ? 'Fisiopatología de la hipercalemia: potencial de acción cardíaco, umbral de despolarización, repolarización precoz, riesgo de reentrada y diferencia entre hipercalemia aguda vs crónica.'
                  : 'Fisiopatologia da hipercalemia: potencial de ação cardíaco, limiar de despolarização, repolarização precoce, risco de reentrada e diferença entre hipercalemia aguda vs crônica.',
            ),
            SmartNextAction(
              label: es ? 'Quelantes de potasio: nuevas opciones' : 'Quelantes de potássio: novas opções',
              promptToSend: es
                  ? 'Quelantes de potasio de nueva generación: patiromer y zirconio ciclosilicato de sodio (ZS-9) — mecanismo de acción, inicio de efecto, indicaciones crónicas vs agudas e hipercalemia en DRC.'
                  : 'Quelantes de potássio de nova geração: patiromer e zircônio ciclosilicato de sódio (ZS-9) — mecanismo de ação, início de efeito, indicações crônicas vs agudas e hipercalemia na DRC.',
            ),
          ], chatHistory);
        }

      // ── 42. Delirium ───────────────────────────────────────────────────────
      case ClinicalTopic.delirium:
        if (isPlantaoMode) {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Delirium: manejo no fármaco' : 'Delirium: manejo não-farmacol.',
              promptToSend: es
                  ? 'Medidas no farmacológicas para delirium en UTI: orientación temporal, movilización precoz, ciclos sueño-vigilia, reducción de fármacos anticolin y protocolo HELP.'
                  : 'Medidas não-farmacológicas para delirium na UTI: reorientação temporal, mobilização precoce, ciclos sono-vigília, redução de fármacos anticolinérgicos e protocolo HELP.',
            ),
            SmartNextAction(
              label: es ? 'Delirium hiperactivo: farmacología' : 'Delirium hiperativo: farmacologia',
              promptToSend: es
                  ? 'Tratamiento farmacológico del delirium hiperactivo en UTI: haloperidol 2,5-5mg IV, quetiapina oral como alternativa, limitaciones de la evidencia (Hope-ICU, Mind-USA) y benzodiacepinas solo en abstinencia.'
                  : 'Tratamento farmacológico do delirium hiperativo na UTI: haloperidol 2,5-5mg IV, quetiapina oral como alternativa, limitações da evidência (Hope-ICU, Mind-USA) e benzodiazepínicos apenas na abstinência.',
            ),
            SmartNextAction(
              label: es ? 'Causas reversibles de delirium' : 'Causas reversíveis de delirium',
              promptToSend: es
                  ? 'Mnemónico I-WATCH-DEATH para causas de delirium: Infección, Withdrawal, Acute metabolic, Trauma, CNS pathology, Hypoxia, Déficits (B12/tiamina), Endocrine, Acute vascular, Toxins/drugs, Heavy metals.'
                  : 'Mnemônico I-WATCH-DEATH para causas de delirium: Infecção, Withdrawal, Agudo metabólico, Trauma, Patologia SNC, Hipóxia, Déficits (B12/tiamina), Endócrino, Vascular agudo, Tóxicos/drogas, Metais pesados.',
            ),
          ], chatHistory);
        } else {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Delirium: diagnóstico CAM' : 'Delirium: diagnóstico CAM',
              promptToSend: es
                  ? 'Instrumento CAM para diagnóstico de delirium: 4 características (inicio agudo, inatención, pensamiento desorganizado, alteración conciencia), sensibilidad y especificidad.'
                  : 'Instrumento CAM para diagnóstico de delirium: 4 características (início agudo, desatenção, pensamento desorganizado, alteração da consciência), sensibilidade e especificidade.',
            ),
            SmartNextAction(
              label: es ? 'Delirium: fisiopatología' : 'Delirium: fisiopatologia',
              promptToSend: es
                  ? 'Fisiopatología del delirium: hipótesis neuroinfllamatoria (IL-6, TNF-α), déficit colinérgico central, exceso dopaminérgico, disrupción de la barrera hematoencefálica y neuroinflamación sistémica.'
                  : 'Fisiopatologia do delirium: hipótese neuroinflamatória (IL-6, TNF-α), déficit colinérgico central, excesso dopaminérgico, disrupção da barreira hematoencefálica e neuroinflamação sistêmica.',
            ),
            SmartNextAction(
              label: es ? 'Delirium: pronóstico y secuelas' : 'Delirium: prognóstico e sequelas',
              promptToSend: es
                  ? 'Consecuencias del delirium en UTI: mayor mortalidad, disfunción cognitiva post-UCI (PICS), prolongación de ventilación mecánica, institucionalización y estrategias de prevención a largo plazo.'
                  : 'Consequências do delirium na UTI: maior mortalidade, disfunção cognitiva pós-UTI (PICS), prolongamento da ventilação mecânica, institucionalização e estratégias de prevenção a longo prazo.',
            ),
          ], chatHistory);
        }

      // ── 43. Fallback — nenhum tema identificado ────────────────────────────
      case ClinicalTopic.nenhum:
        if (isPlantaoMode) {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Revisar próximos pasos' : 'Revisar próximos passos',
              promptToSend: es
                  ? 'Con base en la discusión anterior, ¿cuáles son los próximos pasos clínicos prioritarios?'
                  : 'Com base na discussão anterior, quais são os próximos passos clínicos prioritários?',
            ),
            SmartNextAction(
              label: es ? 'Alertas clínicas a monitorar' : 'Alertas clínicos a monitorar',
              promptToSend: es
                  ? 'Con base en la discusión, ¿cuáles son las alertas clínicas clave que debo monitorar en las próximas horas?'
                  : 'Com base na discussão, quais são os alertas clínicos chave que devo monitorar nas próximas horas?',
            ),
            SmartNextAction(
              label: es ? 'Comunicación con el equipo' : 'Comunicação com a equipe',
              promptToSend: es
                  ? 'Con base en la discusión, ¿cómo comunicar este caso al equipo multidisciplinario de manera concisa y efectiva?'
                  : 'Com base na discussão, como comunicar este caso à equipe multidisciplinar de forma concisa e efetiva?',
            ),
          ], chatHistory);
        } else {
          return _pickAction([
            SmartNextAction(
              label: es ? 'Profundizar este tema' : 'Aprofundar este tema',
              promptToSend: es
                  ? 'Con base en lo anterior, ¿puedes profundizar en los aspectos más relevantes para la práctica clínica?'
                  : 'Com base no anterior, pode aprofundar nos aspectos mais relevantes para a prática clínica?',
            ),
            SmartNextAction(
              label: es ? 'Evidencia reciente: actualización' : 'Evidência recente: atualização',
              promptToSend: es
                  ? 'Con base en la discusión, ¿cuáles son las evidencias más recientes y los cambios de práctica clínica relevantes en este tema?'
                  : 'Com base na discussão, quais são as evidências mais recentes e as mudanças de prática clínica relevantes neste tema?',
            ),
            SmartNextAction(
              label: es ? 'Caso clínico: aplica lo aprendido' : 'Caso clínico: aplica o aprendido',
              promptToSend: es
                  ? 'Con base en lo que discutimos, preséntame un caso clínico desafiador para que yo pueda aplicar el razonamiento diagnóstico y terapéutico aprendido.'
                  : 'Com base no que discutimos, apresente-me um caso clínico desafiador para que eu possa aplicar o raciocínio diagnóstico e terapêutico aprendido.',
            ),
          ], chatHistory);
        }
    }
  }
}
