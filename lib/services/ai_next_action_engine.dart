// ══════════════════════════════════════════════════════════════════════════════
// ai_next_action_engine.dart — Smart Next Action Engine v3 (Build 1560)
//
// MOTOR 100% LOCAL — DETERMINÍSTICO — SEM IA — SEM REDE — SEM RAG
//
// Responsabilidade exclusiva:
//   • Detectar o tema clínico da conversa entre 150 patologias mapeadas.
//   • Selecionar a continuação mais relevante através de uma esteira temporal.
//   • Deduplicar e eliminar loops visuais confrontando sugestões com chatHistory.
//   • Respeitar modo (Plantão/Estudo) e idioma (PT-BR/ES) com rigor absoluto.
// ══════════════════════════════════════════════════════════════════════════════


class SmartNextAction {
  final String label;
  final String promptToSend;

  const SmartNextAction({
    required this.label,
    required this.promptToSend,
  });
}

enum ClinicalTopic {
  sca,                       //  1. Síndrome Coronariana
  sepse,                     //  2. Sepse / Choque Séptico
  potassio,                  //  3. Distúrbios do Potássio
  antidepressivos,           //  4. Antidepressivos (ISRS/IRSN)
  parkinson,                 //  5. Parkinson
  anticoagulacao,            //  6. Anticoagulação
  arritmia,                  //  7. Arritmias
  tep,                       //  8. TEP / Embolia Pulmonar
  asma,                      //  9. Asma
  pneumonia,                 // 10. Pneumonia / NAC
  diabetes,                  // 11. Diabetes / CAD / HHS
  renal,                     // 12. Doença Renal / IRA / IRC
  avc,                       // 13. AVC / Neurologia Vascular
  hipertensao,               // 14. Hipertensão
  ic,                        // 15. Insuficiência Cardíaca
  dpoc,                      // 16. DPOC / EPOC
  anafilaxia,                // 17. Anafilaxia
  convulsao,                 // 18. Convulsão / Status Epiléptico
  meningite,                 // 19. Meningite
  endocardite,               // 20. Endocardite
  hiponatremia,              // 21. Hiponatremia
  hipernatremia,             // 22. Hipernatremia
  acidose,                   // 23. Acidose / Gasometria
  alcalose,                  // 24. Alcalose
  choque,                    // 25. Choque (geral)
  intubacao,                 // 26. Intubação / Via Aérea
  ventilacao,                // 27. Ventilação Mecânica
  sedacao,                   // 28. Sedação / Analgossedação
  analgesia,                 // 29. Analgesia / Opioides
  antibioticos,              // 30. Antibióticos de amplo espectro
  obstetricia,               // 31. Obstetrícia / Pré-Eclâmpsia
  pediatria,                 // 32. Pediatria / Neonatologia
  trauma,                    // 33. Trauma / Politrauma
  queimadura,                // 34. Queimaduras
  toxicologia,               // 35. Toxicologia / Intoxicação
  psiquiatria,               // 36. Psiquiatria / Crise Psiquiátrica
  hematologia,               // 37. Hematologia / Coagulopatia
  gastro,                    // 38. Gastroenterologia / Cirrose
  endocrino,                 // 39. Endocrinologia / Tireoide
  infectologia,              // 40. Infectologia / HIV / TB
  hipercalemia,              // 41. Hipercalemia (separada de potássio)
  delirium,                  // 42. Delirium / Confusão Mental
  pcr,                       // 43. Parada Cardiorrespiratória (ACLS)
  disseccaoAorta,            // 44. Dissecção Aguda de Aorta
  tamponamentoCardiaco,      // 45. Tamponamento Cardíaco
  choqueCardiogenico,        // 46. Choque Cardiogênico Refratário
  pericarditeAguda,          // 47. Pericardite Aguda / Miocardite
  pneumotorax,               // 48. Pneumotórax Hipertensivo / Espontâneo
  edemaAgudoPulmao,          // 49. Edema Agudo de Pulmão (EAP) Cardiogênico
  sdra,                      // 50. Síndrome do Desconforto Respiratório Agudo
  hemoptiseMacica,           // 51. Hemoptise Maciça / Via Aérea Sangrante
  pancreatiteGrave,          // 52. Pancreatite Aguda Grave / Critérios Ranson
  hdaVaricosa,               // 53. Hemorragia Digestiva Alta Varicosa (Cirrose)
  hdbMacica,                 // 54. Hemorragia Digestiva Baixa Maciça
  encefalopatiaHepatica,     // 55. Encefalopatia Hepática Aguda
  pbeCirrose,                // 56. Peritonite Bacteriana Espontânea
  abdomeAgudoCirurgico,      // 57. Abdome Agudo Perfurativo / Obstrutivo / Isquêmico
  tceGrave,                  // 58. Traumatismo Cranioencefálico Grave / HIC
  hsaAneurismatica,          // 59. Hemorragia Subaracnoide (HSA)
  hematomaIntracraniano,     // 60. Hematomas Subdural / Extradural
  morteEncefalica,           // 61. Protocolo de Determinação de Morte Encefálica
  criseMiastenica,           // 62. Crise Miastênica (Myasthenia Gravis)
  guillainBarreGrave,        // 63. Síndrome de Guillain-Barré com Falência Ventilatória
  hipocalemiaGrave,          // 64. Hipocalemia Grave (Separada do Potássio base)
  hipercalcemiaMaligna,      // 65. Hipercalcemia Maligna / Crise Hipercalcêmica
  hipocalcemiaSintomatica,   // 66. Hipocalcemia Sintomática / Sinal Trousseau
  hipomagnesemiaGrave,       // 67. Hipomagnesemia Grave / Torsades de Pointes
  hipermagnesemiaIatrogenica,// 68. Hipermagnesemia Iatrogênica / Perda de Reflexo
  rabdomioliseCrush,         // 69. Rabdomiólise / Síndrome de Esmagamento / NTA
  choqueSepticoRefratario,   // 70. Choque Séptico Refratário a Vasopressores
  choqueNeurogenicoTrauma,   // 71. Choque Neurogênico / Lesão Medular Alta
  choqueAnafilaticoGrave,    // 72. Choque Anafilático Refratário
  neutropeniaFebrilOnco,     // 73. Neutropenia Febril Oncológica
  pielonefriteUrossepse,     // 74. Pielonefrite Aguda / Urossepse Obstrutiva
  fasciteNecrotizanteFournier,// 75. Fascite Necrotizante / Síndrome de Fournier
  criseAddisoniana,          // 76. Crise Adrenal / Addisoniana Refratária
  tempestadeTireoidea,       // 77. Tempestade Tireoidea / Crise Tireotóxica
  comaMixedematosoGrave,     // 78. Coma Mixedematoso
  criseFeocromocitoma,       // 79. Crise Adrenérgica por Feocromocitoma
  cetoacidoseDiabeticaGranular,// 80. Cetoacidose Diabética (Manejo avançado)
  estadoHiperosmolarGlicemico,// 81. Estado Hiperosmolar Hiperglicêmico (EHH)
  intoxicacaoOpioides,       // 82. Intoxicação Aguda e Depressão por Opioides
  intoxicacaoBenzodiazepinas,// 83. Intoxicação por Benzodiazepínicos / Flumazenil
  intoxicacaoCocaina,        // 84. Síndrome Adrenérgica por Cocaína / Anfetaminas
  intoxicacaoParacetamolAguda,// 85. Intoxicação por Paracetamol / N-Acetilcisteína
  intoxicacaoDigoxinaCardio, // 86. Intoxicação Digitálica / Anticorpos Fab
  intoxicacaoAlcoolicaComa,  // 87. Intoxicação Alcoólica Aguda / Coma Alcoólico
  abstinenciaDeliriumTremens,// 88. Síndrome de Abstinência Alcoólica / Delirium Tremens
  criseAnemiaFalciforme,     // 89. Crise Vaso-Oclusiva na Anemia Falciforme
  pttEsquizocitos,           // 90. Púrpura Trombocitopênica Trombótica (PTT) / SHU
  tvpMembroInferior,         // 91. Trombose Venosa Profunda (TVP)
  coagulopatiaTraumaAtc,     // 92. Coagulopatia Induzida pelo Trauma (Tríade Letal)
  malariaGraveFalciparum,    // 93. Malária Grave / Plasmodium falciparum
  dengueGraveChoque,         // 94. Dengue Grave / Choque por Dengue
  acidentesPeconhentosOfidico,// 95. Ofidismo / Escorpionismo / Araneísmo
  hipotermiaAcidental,       // 96. Hipotermia Acidental Grave
  hipertermiaMalignaAnestesia,// 97. Hipertermia Maligna Anestésica
  afogamentoAsfixia,         // 98. Afogamento / Quase-Afogamento
  criseSuicidaIdeacao,       // 99. Ideação Suicida Grave / Abordagem de Crise
  sangramentoUterinoAbnormal,// 100. Sangramento Uterino Abnormal Agudo (SUA)
  torcaoAnexoOvariano,       // 101. Torção de Anexo / Ovário
  dipPelveInfecciosa,        // 102. Doença Inflamatória Pélvica (DIP) Grave
  gravidezEctopicaRota,      // 103. Gravidez Ectópica Rota / Choque Hemorrágico
  nefrolitiaseObstrutiva,    // 104. Nefrolitíase Obstrutiva Anúrica / Com Infecção
  retencaoUrinariaAguda,     // 105. Retenção Urinária Aguda / Bexigoma
  priapismoIsquemico,        // 106. Priapismo Isquêmico / Baixo Fluxo
  parafimoseUrgente,         // 107. Parafimose / Estrangulamento Glandar
  artriteSepticaAguda,       // 108. Artrite Séptica Aguda / Piartrose
  criseLupicaRenal,          // 109. Atividade Lúpica Grave / Nefrite / Neurolúpus
  esclerodermiaCriseRenal,   // 110. Crise Renal da Esclerodermia
  vasculiteAncaPositiva,     // 111. Vasculites Sistêmicas ANCA-Positivas
  sindromeLiseTumoral,       // 112. Síndrome de Lise Tumoral (SLT)
  sindromeVeiaCavaSuperior,  // 113. Síndrome da Veia Cava Superior (SVCS)
  compressaoMedularMaligna,  // 114. Compressão Medular Neoplásica / Maligna
  hiperviscosidadeSanguinea, // 115. Síndrome de Hiperviscosidade Plasmática
  glaucomaAgudoAngulo,       // 116. Glaucoma Agudo de Ângulo Fechado
  oclusaoArteriaCentralRetina,// 117. Oclusão da Artéria Central da Retina (OACR)
  descolamentoRetinaUrgente, // 118. Descolamento de Retina Agudo
  celuliteOrbitalSeptal,     // 119. Celulite Orbitária / Pós-septal
  epistaxeMacicaPosterior,   // 120. Epistaxe Posterior Grave / Tamponamento
  anginaLudwigViaAerea,      // 121. Angina de Ludwig / Abscesso Cervical Profundo
  abscessoPeriamigdaliano,   // 122. Abscesso Periamigdalino / Retrofaríngeo
  corpoEstranhoViaAerea,     // 123. Corpo Estranho Obstrutivo / Aspiração
  stevensJohnsonNet,         // 124. Síndrome de Stevens-Johnson / NET
  eritrodermiaEsfoliativa,   // 125. Eritrodermia Esfoliativa Aguda
  farmacodermiaDress,        // 126. Síndrome DRESS / Farmacodermia Grave
  penfigoVulgarAgudo,        // 127. Pênfigo Vulgar Descompensated
  intoxicacaoTriciclicos,    // 128. Intoxicação por Antidepressivos Tricíclicos
  intoxicacaoInibidoresCholinesterase, // 129. Intoxicação por Organofosforados
  intoxicacaoLitioAguda,     // 130. Intoxicação por Lítio / Neurotoxicidade Aguda
  intoxicacaoMonoxidoCarbono,// 131. Intoxicação por Monóxido de Carbono (CO)
  intoxicacaoMetanolEtilenoglicol, // 132. Intoxicação por Álcoois Tóxicos
  intoxicacaoMetanfetaminas, // 133. Intoxicação por Estimulantes (MDMA)
  abstinenciaOpioidesGrave,  // 134. Síndrome de Abstinência de Opioides
  oclusaoArterialAgudaMembro,// 135. Oclusão Arterial Aguda de Membro / Isquemia
  isquemiaMesentericaAguda,  // 136. Isquemia Mesentérica Aguda
  tromboseVenosaCerebral,    // 137. Trombose Venosa Cerebral (TVC)
  aneurismaAortaAbdominalRoto,// 138. Aneurisma de Aorta Abdominal (AAA) Roto
  hemotoraxMacicoTrauma,     // 139. Hemotórax Maciço Traumático
  pneumotoraxAbertoSutura,   // 140. Pneumotórax Aberto / Ferida Aspirante
  fraturaExpostaManejo,      // 141. Fratura Exposta (Protocolo ATB)
  sindromeCompartimentalMembro,// 142. Síndrome Compartimental de Membro
  choqueHipovolemicoNaoTrauma,// 143. Choque Hipovolêmico Não-Traumático
  deliriumHipoativoIdoso,    // 144. Delirium Hipoativo no Idoso Frágil
  dispneiaPaliativaTerminal, // 145. Dispneia em Cuidados Paliativos
  criseAgitacaoDemencia,     // 146. Sintomas Neuropsiquiátricos na Demência
  sindromeAbstinenciaBenzodiazepinas, // 147. Abstinência de Benzodiazepínicos
  choqueEspinalChoque,       // 148. Choque Espinal / Trauma Medular Agudo
  tempestadeCitocinasHlh,    // 149. Síndrome de Tempestade de Citocinas / HLH
  nenhum                     // 150. Fallback Master — Tema não identificado
}

class NextActionEngine {
  NextActionEngine._();

  static SmartNextAction build({
    required String lastUserMessage,
    required String lastAiResponse,
    required bool isPlantaoMode,
    required String currentLanguage,
    List<String> chatHistory = const [],
  }) {
    final lang = _resolveLanguage(currentLanguage, lastUserMessage, lastAiResponse);
    final corpus = '${lastUserMessage.toLowerCase()} ${lastAiResponse.toLowerCase()}';
    final topic = _detectTopic(corpus);

    return _selectAction(
      topic: topic,
      isPlantaoMode: isPlantaoMode,
      lang: lang,
      chatHistory: chatHistory,
      lastUserMessage: lastUserMessage,
      lastAiResponse: lastAiResponse,
    );
  }

  // ── BUILD 256: Extrai nome da patologia da linha 🟥 da resposta da IA ─────────
  // Prioridade 1: título 🟥 do BUILD 255 (ex: "🟥 INFARTO AGUDO DO MIOCÁRDIO")
  // Prioridade 2: primeira linha da resposta da IA (sem emoji)
  // Prioridade 3: texto da query do usuário (trimmed, max 60 chars)
  // Prioridade 4: string vazia (prompt genérico será usado)
  static String _extractPathologyName(String lastAiResponse, String lastUserMessage) {
    // Busca linha que começa com 🟥 e extrai o nome após o emoji
    final lines = lastAiResponse.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('🟥')) {
        // Remove o emoji 🟥 e espaços/hífens iniciais
        final name = trimmed
            .replaceFirst('🟥', '')
            .trim()
            .replaceFirst(RegExp(r'^[\-—–:\s]+'), '')
            .trim();
        if (name.isNotEmpty && name.length >= 3) return name;
      }
    }
    // Fallback: usa a query do usuário (trimmed, max 80 chars, sem quebras de linha)
    final userQuery = lastUserMessage
        .replaceAll('\n', ' ')
        .trim();
    if (userQuery.isNotEmpty) {
      return userQuery.length > 80 ? '${userQuery.substring(0, 80)}…' : userQuery;
    }
    return '';
  }

  static SmartNextAction _pickAction(List<SmartNextAction> options, List<String> history) {
    if (options.isEmpty) {
      return const SmartNextAction(
        label: 'Próximo passo clínico',
        promptToSend: 'Com base na discussão clínica anterior, forneça os próximos passos lógicos e detalhados para o manejo do caso.',
      );
    }
    final histLower = history.map((h) => h.toLowerCase()).toList();
    for (final opt in options) {
      final key = opt.promptToSend.toLowerCase();
      final snippet = key.length > 50 ? key.substring(0, 50) : key;
      final alreadyUsed = histLower.any((h) => h.contains(snippet));
      if (!alreadyUsed) return opt;
    }
    return options.last;
  }

  static String _resolveLanguage(String current, String userMsg, String aiResp) {
    if (current == 'pt' || current == 'es') return current;
    final userLower = userMsg.toLowerCase();
    final esScore = _esTokens.where((t) => userLower.contains(t)).length;
    final ptScore = _ptTokens.where((t) => userLower.contains(t)).length;
    return (esScore > ptScore) ? 'es' : 'pt';
  }

  static const _esTokens = ['¿', '¡', 'dosis', 'tratamiento', 'ampolla', 'contraindicación', 'embarazo', 'manejo', 'solución', 'infusión'];
  static const _ptTokens = ['ção', 'ões', 'não', 'também', 'então', 'conduta', 'ampola', 'tratamento', 'gestação', 'dilua'];

  static bool _any(String corpus, List<String> tokens) => tokens.any((t) => corpus.contains(t));

  static ClinicalTopic _detectTopic(String corpus) {
    if (_any(corpus, ['isrs', 'irsn', 'fluoxetina', 'sertralina', 'escitalopram', 'venlafaxina', 'duloxetina', 'síndrome serotoninérgica'])) return ClinicalTopic.antidepressivos;
    if (_any(corpus, ['parkinson', 'levodopa', 'carbidopa', 'pramipexol', 'discinesia', 'fenômeno on-off'])) return ClinicalTopic.parkinson;
    if (_any(corpus, ['hipercalemia', 'k+ 6', 'k+6', 'k+ 7', 'potássio alto', 'gluconato de cálcio'])) return ClinicalTopic.hipercalemia;
    if (_any(corpus, ['hipocalemia grave', 'k+ 2', 'k+2', 'potássio <'])) return ClinicalTopic.hipocalemiaGrave;
    if (_any(corpus, [' iam', 'iamcsst', 'iamssst', ' sca ', 'infarto', 'supra de st', 'troponina'])) return ClinicalTopic.sca;
    if (_any(corpus, ['parada cardiorrespiratória', 'pcr ', 'acls', 'massagem cardíaca', 'assintolia', 'fv/tvsp'])) return ClinicalTopic.pcr;
    if (_any(corpus, ['dissecção aguda de aorta', 'dissecção de aorta', 'stanford a', 'stanford b', 'dor dilacerante'])) return ClinicalTopic.disseccaoAorta;
    if (_any(corpus, ['tamponamento cardíaco', 'tríade de beck', 'pericardiocentese', 'abafamento de bulhas'])) return ClinicalTopic.tamponamentoCardiaco;
    if (_any(corpus, ['choque cardiogênico', 'choque cardiogenico', 'dobutamina infuso', 'balão intra-aórtico'])) return ClinicalTopic.choqueCardiogenico;
    if (_any(corpus, ['pericardite', 'miocardite', 'dor pleurítica', 'infra de pr'])) return ClinicalTopic.pericarditeAguda;
    if (_any(corpus, ['sepse', 'sepsis', 'choque séptico', 'lactato', 'noradrenalina iv', 'qsofa', 'sofa'])) return ClinicalTopic.sepse;
    if (_any(corpus, ['choque séptico refratário', 'noradrenalina alta', 'adicionar vasopressina'])) return ClinicalTopic.choqueSepticoRefratario;
    if (_any(corpus, ['choque neurogênico', 'choque neurogenico', 'lesão medular', 'bradicardia e hipotensão'])) return ClinicalTopic.choqueNeurogenicoTrauma;
    if (_any(corpus, ['choque anafilático grave', 'adrenalina iv contínua', 'glucagon anafilaxia'])) return ClinicalTopic.choqueAnafilaticoGrave;
    if (_any(corpus, [' tep', 'tromboembolismo pulmonar', 'embolia pulmonar', 'wells', 'pesi'])) return ClinicalTopic.tep;
    if (_any(corpus, ['asma', 'broncoespasmo', 'salbutamol', 'albuterol', 'ipratrópio', 'crise asmática'])) return ClinicalTopic.asma;
    if (_any(corpus, ['dpoc', 'epoc', 'exacerbação de dpoc', 'hipercapnia', 'vni dpoc'])) return ClinicalTopic.dpoc;
    if (_any(corpus, ['pneumonia', 'nac', 'pac', 'ceftriaxona', 'curb-65'])) return ClinicalTopic.pneumonia;
    if (_any(corpus, ['pneumotórax', 'pneumotorax', 'hipertensivo', 'toracocentese', 'dreno de tórax'])) return ClinicalTopic.pneumotorax;
    if (_any(corpus, ['edema agudo de pulmão', 'eap ', 'congestão sistêmica', 'furosemida iv bolo'])) return ClinicalTopic.edemaAgudoPulmao;
    if (_any(corpus, ['sdra', 'distresse respiratório', 'pêep alta', 'ardsnet', 'posição prona'])) return ClinicalTopic.sdra;
    if (_any(corpus, ['hemoptise maciça', 'hemoptise macica', 'via aérea sangrante', 'broncoscopia urgente'])) return ClinicalTopic.hemoptiseMacica;
    if (_any(corpus, ['diabetes', 'insulina', 'dka', 'cetoacidose', 'hhs', 'hipoglicemia'])) return ClinicalTopic.diabetes;
    if (_any(corpus, ['ira ', 'irc ', 'lesão renal aguda', 'creatinina', 'hemodiálise', 'kdigo'])) return ClinicalTopic.renal;
    if (_any(corpus, ['hiponatremia', 'sódio baixo', 'siadh', 'salina hipertônica 3%'])) return ClinicalTopic.hiponatremia;
    if (_any(corpus, ['hipernatremia', 'sódio alto', 'déficit de agua livre'])) return ClinicalTopic.hipernatremia;
    if (_any(corpus, ['acidose', 'acidosis', 'gasometria', 'ph baixo', 'anion gap'])) return ClinicalTopic.acidose;
    if (_any(corpus, ['alcalose', 'ph alto', 'bicarbonato alto'])) return ClinicalTopic.alcalose;
    if (_any(corpus, ['potássio', 'potasio', 'hipocalemia', 'kcl', 'reposição de k'])) return ClinicalTopic.potassio;
    if (_any(corpus, ['intubação', 'iot ', 'sequência rápida', 'rsi', 'bougie'])) return ClinicalTopic.intubacao;
    if (_any(corpus, ['ventilação mecânica', 'vm ', 'peep', 'fio2', 'volume corrente'])) return ClinicalTopic.ventilacao;
    if (_any(corpus, ['propofol', 'midazolam', 'dexmedetomidina', 'analgossedação', 'rass'])) return ClinicalTopic.sedacao;
    if (_any(corpus, ['fentanil', 'morfina', 'tramadol', 'opioide', 'analgesia'])) return ClinicalTopic.analgesia;
    if (_any(corpus, ['cefepime', 'meropenem', 'piperacilina', 'vancomicina'])) return ClinicalTopic.antibioticos;
    if (_any(corpus, ['pré-eclâmpsia', 'eclampsia', 'ocitocina', 'sulfato de magnésio'])) return ClinicalTopic.obstetricia;
    if (_any(corpus, ['sangramento uterino abnormal', 'sua agudo', 'hemorragia uterina'])) return ClinicalTopic.sangramentoUterinoAbnormal;
    if (_any(corpus, ['torção de anexo', 'torção ovariana', 'isquemia ovariana'])) return ClinicalTopic.torcaoAnexoOvariano;
    if (_any(corpus, ['doença inflamatória pélvica', 'dip grave', 'abscesso tubo-ovariano'])) return ClinicalTopic.dipPelveInfecciosa;
    if (_any(corpus, ['gravidez ectópica rota', 'ectópica rota', 'β-hcg positivo + choque'])) return ClinicalTopic.gravidezEctopicaRota;
    if (_any(corpus, ['cirrose', 'pancreatite', 'varizes esofágicas', 'hda', 'ascite', 'meld'])) return ClinicalTopic.gastro;
    if (_any(corpus, ['pancreatite aguda grave', 'critérios de ranson', 'balthazar'])) return ClinicalTopic.pancreatiteGrave;
    if (_any(corpus, ['hda varicosa', 'terlipressina', 'octreotida', 'ligadura elástica'])) return ClinicalTopic.hdaVaricosa;
    if (_any(corpus, ['hemorragia digestiva baixa', 'hdb maciça', 'colonoscopia urgente'])) return ClinicalTopic.hdbMacica;
    if (_any(corpus, ['encefalopatia hepática', 'lactulona', 'rifaximina', 'flapping'])) return ClinicalTopic.encefalopatiaHepatica;
    if (_any(corpus, ['peritonite bacteriana espontânea', 'pbe ', 'pbe cirrose'])) return ClinicalTopic.pbeCirrose;
    if (_any(corpus, ['abdome agudo', 'perfurativo', 'obstrutivo', 'isquemia mesentérica'])) return ClinicalTopic.abdomeAgudoCirurgico;
    if (_any(corpus, ['avc', ' ave', 'acidente vascular', 'trombólise', 'nihss'])) return ClinicalTopic.avc;
    if (_any(corpus, ['convulsão', 'status epilepticus', 'diazepam', 'fenitoína'])) return ClinicalTopic.convulsao;
    if (_any(corpus, ['meningite', 'meningitis', 'rigidez de nuca', 'punção lombar'])) return ClinicalTopic.meningite;
    if (_any(corpus, ['tce grave', 'hipertensão intracraniana', 'manitol 20%', 'pic '])) return ClinicalTopic.tceGrave;
    if (_any(corpus, ['hsa ', 'hemorragia subaracnoide', 'aneurisma roto', 'escala hunt-hess'])) return ClinicalTopic.hsaAneurismatica;
    if (_any(corpus, ['hematoma subdural', 'hematoma extradural', 'desvio de linha média'])) return ClinicalTopic.hematomaIntracraniano;
    if (_any(corpus, ['morte encefálica', 'morte encefalica', 'protocolo de me', 'teste de apneia'])) return ClinicalTopic.morteEncefalica;
    if (_any(corpus, ['crise miastênica', 'myasthenia gravis', 'plasmaférese crise'])) return ClinicalTopic.criseMiastenica;
    if (_any(corpus, ['guillain-barré', 'guillain barre', 'imunoglobulina iv'])) return ClinicalTopic.guillainBarreGrave;
    if (_any(corpus, ['hipercalcemia maligna', 'crise hipercalcêmica', 'ácido zoledrônico'])) return ClinicalTopic.hipercalcemiaMaligna;
    if (_any(corpus, ['hipocalcemia sintomática', 'sinal de trousseau', 'sinal de chvostek'])) return ClinicalTopic.hipocalcemiaSintomatica;
    if (_any(corpus, ['hipomagnesemia', 'torsades de pointes', 'sulfato de magnésio arritmia'])) return ClinicalTopic.hipomagnesemiaGrave;
    if (_any(corpus, ['hipermagnesemia iatrogênica', 'perda de reflexo patelar'])) return ClinicalTopic.hipermagnesemiaIatrogenica;
    if (_any(corpus, ['rabdomiolise', 'rabdomiólise', 'síndrome de esmagamento', 'cpk alta'])) return ClinicalTopic.rabdomioliseCrush;
    if (_any(corpus, ['artrite séptica', 'piartrose', 'artrocentese urgente'])) return ClinicalTopic.artriteSepticaAguda;
    if (_any(corpus, ['nefrite lúpica', 'neurolúpus', 'pulsoterapia metilprednisolona'])) return ClinicalTopic.criseLupicaRenal;
    if (_any(corpus, ['crise renal da esclerodermia', 'esclerodermia renal', 'captopril dose'])) return ClinicalTopic.esclerodermiaCriseRenal;
    if (_any(corpus, ['vasculite anca', 'anca positiva', 'granulomatose wegener'])) return ClinicalTopic.vasculiteAncaPositiva;
    if (_any(corpus, ['síndrome de lise tumoral', 'slt ', 'rasburicase', 'hiperuricemia'])) return ClinicalTopic.sindromeLiseTumoral;
    if (_any(corpus, ['veia cava superior', 'svcs', 'edema em cacique'])) return ClinicalTopic.sindromeVeiaCavaSuperior;
    if (_any(corpus, ['compressão medular maligna', 'neoplásica', 'dexametasona 10mg iv'])) return ClinicalTopic.compressaoMedularMaligna;
    if (_any(corpus, ['hiperviscosidade sanguínea', 'plasmaphérèse urgência'])) return ClinicalTopic.hiperviscosidadeSanguinea;
    if (_any(corpus, ['glaucoma agudo', 'ângulo fechado', 'dor ocular + midríase'])) return ClinicalTopic.glaucomaAgudoAngulo;
    if (_any(corpus, ['artéria central da retina', 'oacr', 'perda visual súbita indolor'])) return ClinicalTopic.oclusaoArteriaCentralRetina;
    if (_any(corpus, ['descolamento de retina', 'fotopsia', 'miodopsias'])) return ClinicalTopic.descolamentoRetinaUrgente;
    if (_any(corpus, ['celulite orbitária', 'celulite orbital', 'proptose'])) return ClinicalTopic.celuliteOrbitalSeptal;
    if (_any(corpus, ['epistaxe posterior', 'tamponamento posterior', 'balão de brighton'])) return ClinicalTopic.epistaxeMacicaPosterior;
    if (_any(corpus, ['angina de ludwig', 'abscesso cervical profundo', 'edema de assoalho bucal'])) return ClinicalTopic.anginaLudwigViaAerea;
    if (_any(corpus, ['abscesso periamigdalino', 'abscesso retrofaríngeo', 'trismo'])) return ClinicalTopic.abscessoPeriamigdaliano;
    if (_any(corpus, ['corpo estranho obstrutivo', 'aspiração de corpo estranho'])) return ClinicalTopic.corpoEstranhoViaAerea;
    if (_any(corpus, ['stevens-johnson', ' net ', 'necrólise epidérmica', 'sinal de nikolsky'])) return ClinicalTopic.stevensJohnsonNet;
    if (_any(corpus, ['eritrodermia esfoliativa', 'eritrodermia aguda', 'descamação >90%'])) return ClinicalTopic.eritrodermiaEsfoliativa;
    if (_any(corpus, ['síndrome dress', 'dress ', 'eosinofilia + farmacodermia'])) return ClinicalTopic.farmacodermiaDress;
    if (_any(corpus, ['pênfigo vulgar', 'penfigo vulgar', 'bolhas flácidas acantólise'])) return ClinicalTopic.penfigoVulgarAgudo;
    if (_any(corpus, ['intoxicação por tricíclicos', 'amitriptilina overdose', 'qrs largo tc'])) return ClinicalTopic.intoxicacaoTriciclicos;
    if (_any(corpus, ['organofosforados', 'carbamatos', 'chumbinho', 'síndrome colinérgica'])) return ClinicalTopic.intoxicacaoInibidoresCholinesterase;
    if (_any(corpus, ['intoxicação por lítio', 'lítio alto', 'neurologia lítio'])) return ClinicalTopic.intoxicacaoLitioAguda;
    if (_any(corpus, ['monóxido de carbono', 'intoxicação por co', 'carboxihemoglobina'])) return ClinicalTopic.intoxicacaoMonoxidoCarbono;
    if (_any(corpus, ['metanol', 'etilenoglicol', 'álcoois tóxicos', 'hiato osmolar'])) return ClinicalTopic.intoxicacaoMetanolEtilenoglicol;
    if (_any(corpus, ['metanfetaminas', 'intoxicação por mdma', 'síndrome simpaticomimética'])) return ClinicalTopic.intoxicacaoMetanfetaminas;
    if (_any(corpus, ['abstinência de opioides', 'abstinencia opioide', 'piloereção clonidina'])) return ClinicalTopic.abstinenciaOpioidesGrave;
    if (_any(corpus, ['oclusão arterial aguda', 'isquemia aguda de membro', '6 ps da isquemia'])) return ClinicalTopic.oclusaoArterialAgudaMembro;
    if (_any(corpus, ['isquemia mesentérica', 'dor desproporcional ao exame físico'])) return ClinicalTopic.isquemiaMesentericaAguda;
    if (_any(corpus, ['trombose venosa cerebral', 'tvc ', 'cefaleia holocraniana papiledema'])) return ClinicalTopic.tromboseVenosaCerebral;
    if (_any(corpus, ['aneurisma de aorta abdominal roto', 'aaa roto', 'massa pulsátil'])) return ClinicalTopic.aneurismaAortaAbdominalRoto;
    if (_any(corpus, ['hemotórax maciço', 'hemotorax macico', 'dreno >1500ml'])) return ClinicalTopic.hemotoraxMacicoTrauma;
    if (_any(corpus, ['pneumotórax aberto', 'ferida aspirante torácica'])) return ClinicalTopic.pneumotoraxAbertoSutura;
    if (_any(corpus, ['fratura exposta', 'protocolo gustilo', 'antibiótico fratura'])) return ClinicalTopic.fraturaExpostaManejo;
    if (_any(corpus, ['síndrome compartimental', 'pressão intracompartimental'])) return ClinicalTopic.sindromeCompartimentalMembro;
    if (_any(corpus, ['choque hipovolêmico não-traumático', 'desidratação choque'])) return ClinicalTopic.choqueHipovolemicoNaoTrauma;
    if (_any(corpus, ['delirium hipoativo', 'idoso prostrado flutuante'])) return ClinicalTopic.deliriumHipoativoIdoso;
    if (_any(corpus, ['dispneia paliativa', 'terminalidade respiratória', 'morfina paliativa'])) return ClinicalTopic.dispneiaPaliativaTerminal;
    if (_any(corpus, ['agitação na demência', 'bpsd', 'risperidona idoso demência'])) return ClinicalTopic.criseAgitacaoDemencia;
    if (_any(corpus, ['abstinência de benzodiazepínicos', 'desmame diazepam'])) return ClinicalTopic.sindromeAbstinenciaBenzodiazepinas;
    if (_any(corpus, ['choque espinal', 'trauma medular agudo', 'arreflexia flácida'])) return ClinicalTopic.choqueEspinalChoque;
    if (_any(corpus, ['tempestade de citocinas', 'hlh ', 'linfo-histiocitose hemofagocítica'])) return ClinicalTopic.tempestadeCitocinasHlh;
    if (_any(corpus, ['endocardite', 'critérios de duke'])) return ClinicalTopic.endocardite;
    if (_any(corpus, ['pediatria', 'neonatologia', 'pals'])) return ClinicalTopic.pediatria;
    if (_any(corpus, ['trauma', 'politrauma', 'atls', 'abcde'])) return ClinicalTopic.trauma;
    if (_any(corpus, ['queimadura', 'parkland'])) return ClinicalTopic.queimadura;
    if (_any(corpus, ['toxicologia', 'antídoto', 'overdose'])) return ClinicalTopic.toxicologia;
    if (_any(corpus, ['esquizofrenia', 'crise psiquiátrica'])) return ClinicalTopic.psiquiatria;
    if (_any(corpus, ['anemia', 'plaquetopenia', 'coagulopatia'])) return ClinicalTopic.hematologia;
    if (_any(corpus, ['hipertermia maligna', 'síndrome neuroléptica'])) return ClinicalTopic.hipertermiaMalignaAnestesia;
    if (_any(corpus, ['afogamento', 'asfixia por submersão'])) return ClinicalTopic.afogamentoAsfixia;
    if (_any(corpus, ['ideação suicida', 'crise suicida'])) return ClinicalTopic.criseSuicidaIdeacao;
    if (_any(corpus, ['nefrolitíase obstrutiva', 'cólica renal anúrica'])) return ClinicalTopic.nefrolitiaseObstrutiva;
    if (_any(corpus, ['retenção urinária aguda', 'bexigoma'])) return ClinicalTopic.retencaoUrinariaAguda;
    if (_any(corpus, ['priapismo', 'parafimose'])) return ClinicalTopic.priapismoIsquemico;

    return ClinicalTopic.nenhum;
  }

  static SmartNextAction _selectAction({
    required ClinicalTopic topic,
    required bool isPlantaoMode,
    required String lang,
    List<String> chatHistory = const [],
    String lastUserMessage = '',
    String lastAiResponse = '',
  }) {
    final es = lang == 'es';

    final Map<ClinicalTopic, List<SmartNextAction>> plantaoMap = {
      ClinicalTopic.sca: [
        SmartNextAction(label: 'ECG + Troponina urgente', promptToSend: es ? 'Especifique el protocolo de monitorización y ECG de 12 derivaciones en ≤10min junto con troponina ultrasensible.' : 'Especifique a monitorização contínua e o protocolo de ECG de 12 derivações em ≤10min junto com coleta de troponina ultrassensível.'),
        SmartNextAction(label: 'Dupla antiagregação: doses', promptToSend: es ? 'Detalle el protocolo de doble antiagregación plaquetaria inmediata en SCA: dosis de AAS + Clopidogrel ou Ticagrelor.' : 'Detalhe o protocolo de dupla antiagregação plaquetária imediata no SCA: doses de AAS + Clopidogrel ou Ticagrelor.'),
        SmartNextAction(label: 'Fibrinólise: dose por peso', promptToSend: es ? 'Especifique las dosis ajustadas por peso de Tenecteplase IV en bolo o Alteplase, con contraindicaciones.' : 'Especifique as doses ajustadas por peso de Tenecteplase IV em bolus ou Alteplase, com contraindicações.'),
      ],
      ClinicalTopic.sepse: [
        SmartNextAction(label: 'Titulação de vasopressores', promptToSend: es ? 'Choque séptico: detalle la dosis inicial y titulación fina de Noradrenalina IV, y cuándo asociar Vasopressina.' : 'Choque séptico: detalhe a dose inicial e titulação fina de Noradrenalina IV, e quando associar Vasopressina.'),
        SmartNextAction(label: 'Bundle da hora 1: exames', promptToSend: es ? 'Especifique los cultivos a pedir, recolección de lactato sérico y volumen de cristaloides por peso.' : 'Especifique as culturas a pedir, coleta de lactato sérico e volume de cristaloides por peso.'),
      ],
      ClinicalTopic.pcr: [
        SmartNextAction(label: 'Algoritmo ACLS Chocável', promptToSend: es ? 'Paro cardíaco en ritmo chocable (FV/TVSP): desfibrilación, dosis de Adrenalina y Amiodarona.' : 'Parada cardíaca em ritmo chocável (FV/TVSP): desfibrilação, doses de Adrenalina e Amiodarona.'),
        SmartNextAction(label: 'Manejo de causas: 5Hs e 5Ts', promptToSend: es ? '¿Cómo diagnosticar y tratar de inmediato las causas reversibles de PCR por el mnemónico de Hs y Ts?' : 'Como diagnosticar e tratar imediatamente as causas reversíveis de PCR pelo mnemônico de Hs e Ts.'),
      ],
      ClinicalTopic.intubacao: [
        SmartNextAction(label: 'Doses da Sequência Rápida', promptToSend: es ? 'SIR completa: especifique dosis de inductores (Etomidato/Ketamina) y bloqueadores (Rocuronio/Succinilcolina).' : 'SRI completa: especifique doses de indutores (Etomidato/Cetamina) e bloqueadores (Rocurônio/Succinilcolina).'),
      ],
    };

    final Map<ClinicalTopic, List<SmartNextAction>> estudoMap = {
      ClinicalTopic.sca: [
        SmartNextAction(label: 'IAMCSST × IAMSSST: diagnóstico', promptToSend: es ? 'Explique la diferencia fisiopatológica y de diagnóstico diferencial entre IAMCSST e IAMSSST.' : 'Explique a diferença fisiopatológica e de diagnóstico diferencial entre IAMCSST e IAMSSST.'),
        SmartNextAction(label: 'Escores de risco e prognóstico', promptToSend: es ? '¿Cuáles son las variables y el valor pronóstico de los escores GRACE, TIMI e HEART no SCA?' : 'Quais são as variáveis e o valor prognóstico dos escores GRACE, TIMI e HEART no SCA?'),
      ],
      ClinicalTopic.sepse: [
        SmartNextAction(label: 'Critérios Sepsis-3 e SOFA', promptToSend: es ? 'Realice una revisión académica sobre los criterios Sepsis-3 e la puntuación completa del score SOFA.' : 'Realize uma revisão acadêmica sobre os critérios Sepsis-3 e a pontuação completa do score SOFA.'),
      ],
      ClinicalTopic.antidepressivos: [
        SmartNextAction(label: 'ISRS × IRSN: farmacodinâmica', promptToSend: es ? 'Análisis comparativo enciclopédico entre ISRS e IRSN: receptores e interacciones de CYP3A4.' : 'Análise comparativa enciclopédica entre ISRS e IRSN: receptores e interações de CYP3A4.'),
      ],
    };

    final targetList = isPlantaoMode ? plantaoMap[topic] : estudoMap[topic];

    if (targetList != null) {
      return _pickAction(targetList, chatHistory);
    }

    // ── Fallback Master: Plantão vs Estudo ─────────────────────────────────────
    // BUILD 256: topicName extraído dinamicamente do título 🟥 da resposta da IA
    // ou do texto da query do usuário — elimina o "este tema" estático que
    // causava respostas inválidas (Card Roxo) quando o histórico estava limpo.
    final topicName = _extractPathologyName(lastAiResponse, lastUserMessage);
    final hasTopicName = topicName.isNotEmpty;

    if (isPlantaoMode) {
      // Plantão: esteira de condutas clínicas progressivas com patologia específica
      return _pickAction([
        SmartNextAction(
          label: es ? 'Condutas e dosagens' : 'Condutas e dosagens',
          promptToSend: es
              ? (hasTopicName
                  ? 'Detalle el tratamiento de primera línea para $topicName, especificando dosis por peso, alternativas de fármacos y monitorización de efectos adversos.'
                  : 'Detalle el tratamiento de primera línea de esta patología, especificando dosis por peso, alternativas de fármacos y monitorización de efectos adversos.')
              : (hasTopicName
                  ? 'Detalhe o tratamento de primeira linha para $topicName, especificando doses por peso, alternativas de fármacos e monitorização de efeitos adversos.'
                  : 'Detalhe o tratamento de primeira linha desta patologia, especificando doses por peso, alternativas de fármacos e monitorização de efeitos adversos.'),
        ),
        SmartNextAction(
          label: es ? 'Exames e evolução' : 'Exames e evolução',
          promptToSend: es
              ? (hasTopicName
                  ? '¿Cuáles son los exámenes diagnósticos primarios para evaluar la evolución en $topicName y las interacciones de fármacos críticas?'
                  : '¿Cuáles son los exámenes diagnósticos primarios para evaluar la evolución del paciente y las interacciones de fármacos críticas?')
              : (hasTopicName
                  ? 'Quais são os exames diagnósticos primários para avaliar a evolução em $topicName e as interações de fármacos críticas?'
                  : 'Quais são os exames diagnósticos primários para avaliar a evolução do paciente e as interações de fármacos críticas?'),
        ),
        SmartNextAction(
          label: es ? 'Perguntas importantes' : 'Perguntas importantes',
          promptToSend: es
              ? (hasTopicName
                  ? '¿Cuáles son las preguntas críticas de la historia clínica para guiar el manejo de $topicName y evitar complicaciones?'
                  : '¿Cuáles son las preguntas críticas que se deben hacer en la historia clínica para guiar este caso y evitar complicaciones?')
              : (hasTopicName
                  ? 'Quais são as perguntas críticas da história clínica para guiar o manejo de $topicName e evitar complicações?'
                  : 'Quais são as perguntas críticas que devem ser feitas na história clínica para guiar este caso e evitar complicações?'),
        ),
      ], chatHistory);
    } else {
      // Estudo: esteira cronológica real de 3 passos — avança consultando chatHistory
      return _pickAction([
        SmartNextAction(
          label: es ? '✨ Profundizar Fisiopatología >' : '✨ Aprofundar Fisiopatologia >',
          promptToSend: es
              ? (hasTopicName
                  ? 'Detalla de forma resumida (máx 15 líneas) el mecanismo de acción molecular y la fisiopatología de $topicName.'
                  : 'Detalla de forma resumida (máx 15 líneas) el mecanismo de acción molecular y la fisiopatología de esta condición.')
              : (hasTopicName
                  ? 'Aprofunde de forma resumida (máx 15 linhas) o mecanismo de ação molecular e a fisiopatologia de $topicName.'
                  : 'Aprofunde de forma resumida (máx 15 linhas) o mecanismo de ação molecular e a fisiopatologia desta condição.'),
        ),
        SmartNextAction(
          label: es ? '✨ Alternativas de 2ª Línea >' : '✨ Alternativas de 2ª Linha >',
          promptToSend: es
              ? (hasTopicName
                  ? 'Detalla directamente (máx 15 líneas) las alternativas terapéuticas cuando falla el tratamiento inicial de $topicName.'
                  : 'Detalla directamente (máx 15 líneas) las alternativas terapéuticas cuando falla el tratamiento inicial.')
              : (hasTopicName
                  ? 'Detalhe de forma direta (máx 15 linhas) as alternativas terapêuticas quando falha o tratamento inicial de $topicName.'
                  : 'Detalhe de forma direta (máx 15 linhas) quais são as alternativas terapêuticas quando falha o tratamento inicial.'),
        ),
        SmartNextAction(
          label: es ? '✨ Comorbilidades y Alertas >' : '✨ Comorbidades e Alertas >',
          promptToSend: es
              ? (hasTopicName
                  ? 'Indica las preguntas clínicas de descarte cruciales y el manejo de comorbilidades en $topicName (máx 15 líneas).'
                  : 'Indica las preguntas clínicas de descarte cruciales y el manejo de comorbilidades asociadas (máx 15 líneas).')
              : (hasTopicName
                  ? 'Indique as perguntas clínicas de descarte cruciais e o manejo de comorbidades em $topicName (máx 15 linhas).'
                  : 'Indique as perguntas clínicas de descarte cruciais e o manejo de comorbidades associadas (máx 15 linhas).'),
        ),
      ], chatHistory);
    }
  }
}
