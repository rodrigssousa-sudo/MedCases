// ignore_for_file: curly_braces_in_flow_control_structures
// Historical owner lint containment: 116 pre-existing infos surfaced when this file is reanalyzed.

// ══════════════════════════════════════════════════════════════════════════════
// ai_next_action_engine.dart — Smart Next Action Engine v3 (Build 286)
//
// MOTOR 100% LOCAL — DETERMINÍSTICO — SEM IA — SEM REDE — SEM RAG
//
// Responsabilidade exclusiva:
//   • Detectar o tema clínico da conversa entre 150 patologias mapeadas.
//   • Selecionar a continuação mais relevante através de uma esteira temporal.
//   • Deduplicar e eliminar loops visuais confrontando sugestões com chatHistory.
//   • Respeitar modo (Plantão/Estudo) e idioma (PT-BR/ES) com rigor absoluto.
// ══════════════════════════════════════════════════════════════════════════════

import 'ai_pipeline/plantao/contracts/plantao_continuation_type.dart';
import 'ai_pipeline/plantao/contracts/plantao_section.dart';

import 'dkahhs/dkahhs_runtime_safety_contract.dart';
class SmartNextAction {
  final String label;
  final String promptToSend;
  final PlantaoContinuationType continuationType;
  final List<PlantaoSection> requestedSections;

  const SmartNextAction({
    required this.label,
    required this.promptToSend,
    this.continuationType = PlantaoContinuationType.freeFollowUp,
    this.requestedSections = const <PlantaoSection>[],
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
    if (isPlantaoMode && DkahhsRuntimeSafetyContract.isScAlternativeRequest(lastUserMessage)) return _emptyGuardiaAction;
    final lang = _resolveLanguage(currentLanguage, lastUserMessage, lastAiResponse);
    final corpus =
        '${_withoutHypotheticalSepsisAnchors(_withoutNegatedSepsisAnchors(lastUserMessage.toLowerCase()))}} '
        '${_withoutHypotheticalSepsisAnchors(_withoutNegatedSepsisAnchors(lastAiResponse.toLowerCase()))}}';
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

  // ── BUILD 262: Extrai nome da patologia da linha 🟥 da resposta da IA ─────────
  // Prioridade 1: PRIMEIRO 🟥 da resposta que NÃO seja termo genérico de layout.
  //   Apenas a PRIMEIRA linha 🟥 é o título clínico real (ex: "🟥 AVC ISQUÊMICO").
  //   Linhas subsequentes (ex: "🟥 CONDUTA CLÍNICA IMEDIATA") são subtítulos
  //   de template visual — NÃO representam a patologia.
  // Prioridade 2: lastUserMessage (query que gerou o chat).
  // Prioridade 3: primeira mensagem do usuário em chatHistory (âncora absoluta).
  // Prioridade 4: string vazia (prompt genérico será usado).
  //
  // BLOCKLIST de termos genéricos de layout que NÃO são nomes de patologia:
  static const _kLayoutTerms = [
    'conduta', 'tratamento', 'imediata', 'imediato', 'alerta', 'crítico',
    'critico', 'farmacológico', 'farmacologico', 'manejo', 'diagnóstico',
    'diagnostico', 'protocolo', 'conduta clínica', 'monitorar', 'monitoramento',
    'evolução', 'evolucao', 'exames', 'resumo', 'orientações', 'orientacoes',
    'seguimento', 'internação', 'internacao', 'alta', 'conduta imediata',
    'causas prováveis', 'causas provaveis', 'causas possíveis',
    'causas possiveis',
    // ES/EN equivalents
    'conducta', 'tratamiento', 'inmediata', 'inmediato', 'monitoreo',
    'diagnóstico', 'diagnostico', 'protocolo', 'manejo', 'seguimiento',
    'causas probables', 'causas posibles', 'probable causes',
    'possible causes',
  ];

  static bool _isLayoutTerm(String name) {
    final lower = name.toLowerCase();
    // Exact match or starts-with against any layout term
    return _kLayoutTerms.any((t) => lower == t || lower.startsWith('$t ') || lower.startsWith('$t:'));
  }

  static String _topicFromUserQuery(String value) {
    final compact = value.replaceAll('\n', ' ').trim();

    if (compact.isEmpty) {
      return '';
    }

    final stripped = compact
        .replaceFirst(
          RegExp(
            r'^(?:tratamento|tratamiento|conduta|conducta|manejo|terapia|'
            r'como tratar|cómo tratar|qual o tratamento|cuál es el tratamiento)'
            r'\s*(?:de|do|da|del|para)?\s*[:\-—–]?\s*',
            caseSensitive: false,
          ),
          '',
        )
        .trim();

    final candidate = stripped.isNotEmpty ? stripped : compact;

    if (_isLayoutTerm(candidate)) {
      return '';
    }

    return candidate.length > 80
        ? '${candidate.substring(0, 80)}…'
        : candidate;
  }

  static String _stripTrailingIntentSuffix(String value) {
    final compact = value.trim();
    final stripped = compact
        .replaceFirst(
          RegExp(
            r'\s*(?:[-—–:]\s*)?'
            r'(?:tratamento|tratamiento|manejo|conduta|conducta|terapia|'
            r'diferenciais?\s+priorit[aá]rios|diferenciales?\s+prioritarios)'
            r'\s*$',
            caseSensitive: false,
          ),
          '',
        )
        .trim();

    return stripped.isNotEmpty ? stripped : compact;
  }

  static String _extractPathologyName(
    String lastAiResponse,
    String lastUserMessage, {
    List<String> chatHistory = const [],
  }) {
    // ── Priority 1: first 🟥 line that is NOT a layout term ──────────────────
    final lines = lastAiResponse.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('🟥')) {
        final rawName = trimmed
            .replaceFirst('🟥', '')
            .trim()
            .replaceFirst(RegExp(r'^[\-—–:\s]+'), '')
            .trim();
        final name = _stripTrailingIntentSuffix(rawName);
        // Skip empty, too-short, or layout/template sub-headings
        if (name.isNotEmpty && name.length >= 3 && !_isLayoutTerm(name)) {
          return name;
        }
        // BUILD 262: stop after first 🟥 — subsequent ones are sub-titles, not the topic
        break;
      }
    }

    // ── Priority 2: tema lexical da pergunta que gerou a resposta ─────────
    final userTopic = _topicFromUserQuery(lastUserMessage);
    if (userTopic.isNotEmpty) {
      return userTopic;
    }

    // ── Priority 3: FIRST user message in chatHistory (session anchor) ────────
    // chatHistory contains all messages (user + AI) in order.
    // The FIRST user-authored message (odd index or detected by content) is the
    // original clinical query that anchors this entire session.
    // We scan until we find a non-empty, non-AI entry with clinical content.
    for (final msg in chatHistory) {
      final t = msg.replaceAll('\n', ' ').trim();
      // Skip AI responses (they contain 🟥 or are long clinical texts)
      if (t.startsWith('🟥') || t.length > 300) continue;
      // Skip empty or layout terms
      if (t.isEmpty || _isLayoutTerm(t)) continue;
      // Skip greetings / bot opening messages
      if (t.startsWith('Olá') || t.startsWith('Hola') || t.startsWith('👋')) continue;
      return t.length > 80 ? '${t.substring(0, 80)}…' : t;
    }

    return ''; // prompt genérico will be used (hasTopicName = false)
  }

  static SmartNextAction _pickAction(List<SmartNextAction> options, List<String> history) {
    if (options.isEmpty) {
      return const SmartNextAction(
        label: 'Próximo passo clínico',
        promptToSend: 'Próximos passos no manejo deste caso.',
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

  static const SmartNextAction _emptyGuardiaAction = SmartNextAction(
    label: '',
    promptToSend: '',
  );

  static const Set<String> _progressionIntentTokens = {
    'management',
    'dose',
    'studies',
    'monitoring',
    'questions',
    'pathophysiology',
  };

  static const Set<String> _progressionStopWords = {
    'a',
    'al',
    'as',
    'caso',
    'clinica',
    'clinicas',
    'clinico',
    'clinicos',
    'com',
    'como',
    'con',
    'cual',
    'cuales',
    'da',
    'das',
    'de',
    'debo',
    'del',
    'deve',
    'devem',
    'do',
    'dos',
    'e',
    'el',
    'em',
    'en',
    'esta',
    'este',
    'imediata',
    'imediatas',
    'inmediata',
    'inmediatas',
    'la',
    'las',
    'los',
    'mais',
    'maneira',
    'o',
    'os',
    'paciente',
    'para',
    'por',
    'protocolo',
    'qual',
    'quais',
    'que',
    'recomendada',
    'recomendadas',
    'recomendado',
    'recomendados',
    'segun',
    'se',
    'si',
    'tema',
    'un',
    'uma',
    'um',
    'una',
    'urgencia',
    'urgente',
    'y',
  };

  static SmartNextAction _pickGuardiaAction({
    required List<SmartNextAction> options,
    required List<String> history,
    required String lastUserMessage,
    required String lastAiResponse,
  }) {
    if (options.isEmpty) return _emptyGuardiaAction;

    final visibleResponse = _visibleResponseForProgression(
      lastAiResponse,
    );

    final comparisonHistory = history
        .map(_visibleResponseForProgression)
        .where((item) => item.trim().isNotEmpty)
        .toList(growable: false);

    for (final option in options) {
      if (_isSameClinicalRequest(
        option.promptToSend,
        lastUserMessage,
      )) {
        continue;
      }

      if (_candidateCoveredByText(
        option,
        visibleResponse,
      )) {
        continue;
      }

      final alreadyUsed = comparisonHistory.any((item) {
        final repeatedQuestion = item.length <= 280 &&
            _isSameClinicalRequest(
              option.promptToSend,
              item,
            );

        return repeatedQuestion ||
            _candidateCoveredByText(
              option,
              item,
            );
      });

      if (!alreadyUsed) return option;
    }

    return _emptyGuardiaAction;
  }

  static bool _isSameClinicalRequest(
    String candidate,
    String original,
  ) {
    final candidateKey = _progressionComparisonKey(candidate);
    final originalKey = _progressionComparisonKey(original);

    if (candidateKey.isEmpty || originalKey.isEmpty) {
      return false;
    }

    if (candidateKey == originalKey) return true;

    final candidateTokens = _progressionTokens(candidate);
    final originalTokens = _progressionTokens(original);

    final candidateFocus = _progressionFocusIntents(
      candidateTokens,
    );
    final originalFocus = _progressionFocusIntents(
      originalTokens,
    );
    final sharedFocus = candidateFocus.intersection(
      originalFocus,
    );

    const minimumEmbeddedLength = 12;

    if (sharedFocus.isNotEmpty) {
      if (candidateKey.length >= minimumEmbeddedLength &&
          originalKey.contains(candidateKey)) {
        return true;
      }

      if (originalKey.length >= minimumEmbeddedLength &&
          candidateKey.contains(originalKey)) {
        return true;
      }
    }

    if (sharedFocus.isEmpty) {
      return false;
    }

    final candidateClinical = candidateTokens.difference(
      _progressionIntentTokens,
    );
    final originalClinical = originalTokens.difference(
      _progressionIntentTokens,
    );

    return candidateClinical
        .intersection(originalClinical)
        .isNotEmpty;
  }

  static Set<String> _progressionFocusIntents(
    Set<String> tokens,
  ) {
    final intents = tokens.intersection(
      _progressionIntentTokens,
    );

    if (intents.contains('questions')) {
      return const {'questions'};
    }

    if (intents.contains('studies') ||
        intents.contains('monitoring')) {
      return {
        if (intents.contains('studies')) 'studies',
        if (intents.contains('monitoring')) 'monitoring',
      };
    }

    if (intents.contains('pathophysiology')) {
      return const {'pathophysiology'};
    }

    return intents;
  }

  static bool _candidateCoveredByText(
    SmartNextAction candidate,
    String text,
  ) {
    if (text.trim().isEmpty) return false;

    final candidateTokens = _progressionTokens(
      '${candidate.label} ${candidate.promptToSend}',
    );
    final textTokens = _progressionTokens(text);

    if (candidateTokens.isEmpty || textTokens.isEmpty) {
      return false;
    }

    final candidateIntents = candidateTokens.intersection(
      _progressionIntentTokens,
    );
    final candidateClinical = candidateTokens.difference(
      _progressionIntentTokens,
    );
    final sharedClinical = candidateClinical.intersection(
      textTokens,
    );

    if (candidateIntents.isNotEmpty) {
      return textTokens.containsAll(candidateIntents) &&
          (candidateClinical.isEmpty ||
              sharedClinical.isNotEmpty);
    }

    if (candidateClinical.length < 2 ||
        sharedClinical.length < 2) {
      return false;
    }

    final coverage =
        sharedClinical.length / candidateClinical.length;

    return coverage >= 0.30;
  }

  static Set<String> _progressionTokens(String value) {
    final result = <String>{};
    final normalized = _progressionComparisonText(value);

    for (final rawToken in normalized.split(' ')) {
      if (rawToken.isEmpty) continue;

      final token = _canonicalProgressionToken(rawToken);

      if (token.isEmpty ||
          _progressionStopWords.contains(token)) {
        continue;
      }

      final numeric = RegExp(r'^\d+$').hasMatch(token);

      if (token.length < 3 && !numeric) continue;

      result.add(token);
    }

    if (RegExp(
      r'\b\d+(?:[.,]\d+)?\s*'
      r'(?:mg|mcg|ug|g|ui|u|ml|meq|mmol)'
      r'(?:\s*/\s*(?:kg|h|min))?\b',
      caseSensitive: false,
    ).hasMatch(value)) {
      result.add('dose');
    }

    return result;
  }

  static String _canonicalProgressionToken(
    String token,
  ) {
    const management = {
      'conduta',
      'condutas',
      'conducta',
      'conductas',
      'manejo',
      'tratamento',
      'tratamientos',
      'tratamiento',
      'tratamentos',
      'terapeutica',
      'terapeutico',
    };

    const doses = {
      'dose',
      'doses',
      'dosagem',
      'dosagens',
      'dosis',
      'posologia',
      'titulacao',
      'titulacion',
    };

    const studies = {
      'estudio',
      'estudios',
      'exame',
      'exames',
      'examen',
      'examenes',
      'investigacao',
      'investigacion',
    };

    const monitoring = {
      'evolucao',
      'evolucion',
      'monitoramento',
      'monitorear',
      'monitoreo',
      'monitorar',
      'monitorizacao',
      'monitorizacion',
    };

    const questions = {
      'anamnese',
      'anamnesis',
      'pergunta',
      'perguntas',
      'pregunta',
      'preguntas',
    };

    const pathophysiology = {
      'fisiopatologia',
      'fisiopatologica',
      'fisiopatologico',
    };

    if (management.contains(token)) return 'management';
    if (doses.contains(token)) return 'dose';
    if (studies.contains(token)) return 'studies';
    if (monitoring.contains(token)) return 'monitoring';
    if (questions.contains(token)) return 'questions';
    if (pathophysiology.contains(token)) {
      return 'pathophysiology';
    }

    return token;
  }

  static String _progressionComparisonKey(
    String value,
  ) {
    return _progressionComparisonText(value).replaceAll(
      ' ',
      '',
    );
  }

  static String _progressionComparisonText(
    String value,
  ) {
    var normalized = value.toLowerCase();

    const replacements = {
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'ó': 'o',
      'ò': 'o',
      'ô': 'o',
      'õ': 'o',
      'ö': 'o',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ç': 'c',
      'ñ': 'n',
    };

    replacements.forEach((source, target) {
      normalized = normalized.replaceAll(
        source,
        target,
      );
    });

    return normalized
        .replaceAll(
          RegExp(r'[^a-z0-9]+'),
          ' ',
        )
        .replaceAll(
          RegExp(r'\s+'),
          ' ',
        )
        .trim();
  }

  static String _visibleResponseForProgression(
    String value,
  ) {
    final visible = <String>[];

    for (final line in value.split('\n')) {
      final normalized = _progressionComparisonText(line);

      if (RegExp(
        r'^(?:proximo\s+(?:paso|passo)|'
        r'siguiente\s+paso|resumo|resumen)\b',
      ).hasMatch(normalized)) {
        break;
      }

      visible.add(line);
    }

    return visible.join('\n');
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

  /// Removes only sepsis/shock anchors that are explicitly negated.
  ///
  /// Positive evidence outside the negated clause remains untouched.
  static String _withoutNegatedSepsisAnchors(String text) {
    var sanitized = text;
    final negatedSepsisClauses = <RegExp>[
      RegExp(
        r'\b(?:'
        r'sem(?:\s+sinais?)?(?:\s+de)?|'
        r'sem\s+evid[eê]ncias?\s+de|'
        r'aus[eê]ncia\s+de|'
        r'n[aã]o\s+h[aá](?:\s+sinais?\s+de)?|'
        r'n[aã]o\s+apresenta(?:\s+sinais?\s+de)?|'
        r'nega(?:\s+sinais?\s+de)?|'
        r'sin(?:\s+signos?)?(?:\s+de)?|'
        r'sin\s+evidencias?\s+de|'
        r'ausencia\s+de|'
        r'no\s+hay(?:\s+signos?\s+de)?|'
        r'no\s+presenta(?:\s+signos?\s+de)?|'
        r'niega(?:\s+signos?\s+de)?'
        r')\s+'
        r'(?:'
        r'sepse|sepsis|'
        r'choque(?:\s+s[eé]ptico)?|'
        r'shock(?:\s+s[eé]ptico)?|'
        r'instabilidade\s+hemodin[aâ]mica|'
        r'inestabilidad\s+hemodin[aá]mica'
        r')'
        r'(?:\s*(?:,|e|ou|nem|y|o|ni)\s*'
        r'(?:'
        r'sepse|sepsis|'
        r'choque(?:\s+s[eé]ptico)?|'
        r'shock(?:\s+s[eé]ptico)?|'
        r'instabilidade\s+hemodin[aâ]mica|'
        r'inestabilidad\s+hemodin[aá]mica'
        r'))*',
        caseSensitive: false,
      ),
    ];

    for (final pattern in negatedSepsisClauses) {
      sanitized = sanitized.replaceAll(pattern, ' ');
    }

    return sanitized
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Removes explicit hypothetical sepsis/shock mentions.
  ///
  /// Active evidence outside the hypothetical phrase remains untouched.
  static String _withoutHypotheticalSepsisAnchors(String text) {
    var sanitized = text;
    final hypotheticalSepsisClauses = <RegExp>[
      RegExp(
        r'\b(?:'
        r'considerar|'
        r'considera-se|'
        r'considerar\s+a\s+possibilidade\s+de|'
        r'evaluar\s+a\s+possibilidade\s+de|'
        r'avaliar\s+a\s+possibilidade\s+de|'
        r'considerar\s+la\s+posibilidad\s+de|'
        r'evaluar\s+la\s+posibilidad\s+de'
        r')\s+'
        r'(?:'
        r'sepse|sepsis|'
        r'choque(?:\s+s[eé]ptico)?|'
        r'shock(?:\s+s[eé]ptico)?'
        r')',
        caseSensitive: false,
      ),
    ];

    for (final pattern in hypotheticalSepsisClauses) {
      sanitized = sanitized.replaceAll(pattern, ' ');
    }

    return sanitized
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

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

  static String _normalizedStageText(String value) =>
      _progressionComparisonText(value);

  static bool _containsDifferentialAnchor(String value) {
    final normalized = _normalizedStageText(value);
    return normalized.contains('diferenciais prioritarios') ||
        normalized.contains('diferenciales prioritarios');
  }

  static bool _containsQuestionsStage(String value) {
    final normalized = _normalizedStageText(value);
    return normalized.contains('perguntas chave') ||
        normalized.contains('perguntas clinicas chave') ||
        normalized.contains('perguntas importantes') ||
        normalized.contains('preguntas clave') ||
        normalized.contains('preguntas clinicas clave') ||
        normalized.contains('preguntas importantes');
  }

  static bool _containsExamsStage(String value) {
    final normalized = _normalizedStageText(value);
    return normalized.contains('exames complementares') ||
        normalized.contains('examenes complementarios') ||
        normalized.contains('exames e imagens') ||
        normalized.contains('estudos e imagens') ||
        normalized.contains('estudios e imagenes');
  }

  static bool _containsTherapeuticStage(String value) {
    final normalized = _normalizedStageText(value);
    return normalized.contains('tratamento farmacologico') ||
        normalized.contains('tratamiento farmacologico') ||
        normalized.contains('conduta terapeutica') ||
        normalized.contains('conducta terapeutica');
  }

  static SmartNextAction? _adaptiveUndifferentiatedAction({
    required bool isPlantaoMode,
    required String lang,
    required String lastUserMessage,
    required String lastAiResponse,
    required List<String> chatHistory,
  }) {
    if (!isPlantaoMode) return null;

    final currentIsDifferential = _containsDifferentialAnchor(lastAiResponse);
    final currentIsQuestions = _containsQuestionsStage(lastAiResponse);
    final currentIsExams = _containsExamsStage(lastAiResponse);
    final requestedQuestionsNow = _containsQuestionsStage(lastUserMessage);
    final requestedExamsNow = _containsExamsStage(lastUserMessage);
    final currentIsTherapeutic = _containsTherapeuticStage(lastAiResponse);
    final priorDifferential = chatHistory.any(_containsDifferentialAnchor);
    final inDifferentialFlow = currentIsDifferential ||
        (priorDifferential &&
            (currentIsQuestions ||
                currentIsExams ||
                requestedQuestionsNow ||
                requestedExamsNow));

    if (!inDifferentialFlow || currentIsTherapeutic) return null;

    final es = lang == 'es';
    final historyHasQuestions = chatHistory.any(_containsQuestionsStage);
    final historyHasExams = chatHistory.any(_containsExamsStage);

    // Depois que o botão pediu perguntas/exames, espera os dados do usuário.
    if (currentIsQuestions ||
        currentIsExams ||
        requestedQuestionsNow ||
        requestedExamsNow) {
      return _emptyGuardiaAction;
    }

    final topicName = _extractPathologyName(
      lastAiResponse,
      lastUserMessage,
      chatHistory: chatHistory,
    );
    final suffix = topicName.isEmpty ? '' : ' de $topicName';

    if (!historyHasQuestions) {
      return SmartNextAction(
        label: es ? 'Preguntas clave' : 'Perguntas-chave',
        promptToSend: es
            ? 'Enumera solamente las preguntas clínicas clave que debo hacer al paciente para discriminar los diagnósticos diferenciales$suffix. No inventes respuestas del paciente.'
            : 'Liste somente as perguntas clínicas-chave que devo fazer ao paciente para discriminar os diagnósticos diferenciais$suffix. Não invente respostas do paciente.',
      );
    }

    if (!historyHasExams) {
      return SmartNextAction(
        label: es ? 'Estudios e imágenes' : 'Exames e imagens',
        continuationType: PlantaoContinuationType.examsEvolution,
        requestedSections: const <PlantaoSection>[
          PlantaoSection.exams,
          PlantaoSection.monitoring,
        ],
        promptToSend: es
            ? 'Indica solamente los estudios complementarios e imágenes que mejor discriminan los diagnósticos diferenciales$suffix, priorizados por utilidad clínica. No asumas resultados.'
            : 'Indique somente os exames complementares e imagens que melhor discriminam os diagnósticos diferenciais$suffix, priorizados por utilidade clínica. Não presuma resultados.',
      );
    }

    return SmartNextAction(
      label: es ? 'Conducta y tratamiento' : 'Conduta e tratamento',
      continuationType: PlantaoContinuationType.treatmentExpansion,
      requestedSections: const <PlantaoSection>[
        PlantaoSection.immediateActions,
        PlantaoSection.fullTreatment,
        PlantaoSection.dosageClarification,
      ],
      promptToSend: es
          ? 'Con los datos clínicos y resultados ya aportados en esta conversación, define la conducta y tratamiento solo si el diagnóstico o la indicación están suficientemente sustentados. Si aún faltan datos, dilo sin inventarlos.'
          : 'Com os dados clínicos e resultados já fornecidos nesta conversa, defina a conduta e o tratamento somente se o diagnóstico ou a indicação estiverem suficientemente sustentados. Se ainda faltarem dados, informe isso sem inventá-los.',
    );
  }

  static bool _isConfirmedStElevationMi(String userText, String aiText) {
    final normalized = _normalizedStageText('$userText $aiText');
    final hasStElevationMi = normalized.contains('iamcsst') ||
        normalized.contains('iamcest') ||
        normalized.contains('stemi') ||
        normalized.contains('infarto com supra') ||
        normalized.contains('infarto con elevacion');
    final confirmed = normalized.contains('confirmado') ||
        normalized.contains('confirmada') ||
        normalized.contains('confirmed');
    return hasStElevationMi && confirmed;
  }

  static bool _isTherapeuticAcuteCoronaryStage(
    String userText,
    String aiText,
  ) {
    final normalized = _normalizedStageText('$userText $aiText');
    final hasScaIdentity = normalized.contains('infarto agudo do miocardio') ||
        normalized.contains('infarto agudo de miocardio') ||
        normalized.contains('sindrome coronaria aguda') ||
        normalized.contains('iamcsst') ||
        normalized.contains('iamcest') ||
        normalized.contains('iamssst') ||
        normalized.contains('iamsest') ||
        normalized.contains('stemi') ||
        normalized.contains('nstemi') ||
        RegExp(r'(^| )iam( |$)').hasMatch(normalized);

    if (!hasScaIdentity || !_containsTherapeuticStage(aiText)) {
      return false;
    }

    final hasAdvancedTherapy = <String>[
      'clopidogrel',
      'ticagrelor',
      'prasugrel',
      'heparina',
      'enoxaparina',
      'anticoagul',
      'nitroglicerina',
      'nitrato',
    ].any(normalized.contains);

    final hasInvasivePlan = <String>[
      'cateter',
      'hemodinam',
      'angioplast',
      'intervencao coronaria',
      'intervencion coronaria',
    ].any(normalized.contains);

    return hasAdvancedTherapy || hasInvasivePlan;
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

    final adaptiveAction = _adaptiveUndifferentiatedAction(
      isPlantaoMode: isPlantaoMode,
      lang: lang,
      lastUserMessage: lastUserMessage,
      lastAiResponse: lastAiResponse,
      chatHistory: chatHistory,
    );
    if (adaptiveAction != null) return adaptiveAction;

    if (isPlantaoMode &&
        topic == ClinicalTopic.sca &&
        _isConfirmedStElevationMi(lastUserMessage, lastAiResponse)) {
      return SmartNextAction(
        label: es ? 'Estrategia de reperfusión' : 'Estratégia de reperfusão',
        continuationType: PlantaoContinuationType.treatmentExpansion,
        requestedSections: const <PlantaoSection>[
          PlantaoSection.immediateActions,
          PlantaoSection.fullTreatment,
          PlantaoSection.monitoring,
        ],
        promptToSend: es
            ? 'IAMCEST confirmado: detalla la estrategia de reperfusión inmediata, tiempos objetivo, ICP primaria y cuándo considerar fibrinólisis si la ICP no está disponible a tiempo. No repitas ECG/troponina como siguiente paso diagnóstico.'
            : 'IAMCSST confirmado: detalhe a estratégia de reperfusão imediata, tempos-alvo, ICP primária e quando considerar fibrinólise se a ICP não estiver disponível em tempo adequado. Não repita ECG/troponina como próximo passo diagnóstico.',
      );
    }

    if (isPlantaoMode &&
        topic == ClinicalTopic.sca &&
        _isTherapeuticAcuteCoronaryStage(
          lastUserMessage,
          lastAiResponse,
        )) {
      return SmartNextAction(
        label: es
            ? 'Estrategia terapéutica y monitorización'
            : 'Estratégia terapêutica e monitorização',
        continuationType: PlantaoContinuationType.treatmentExpansion,
        requestedSections: const <PlantaoSection>[
          PlantaoSection.immediateActions,
          PlantaoSection.fullTreatment,
          PlantaoSection.monitoring,
        ],
        promptToSend: es
            ? 'IAM/SCA ya en etapa terapéutica: detalla estratificación de riesgo, estrategia invasiva cuando esté indicada, monitorización y manejo de complicaciones. No repitas ECG/troponina ni la antiagregación ya informada como siguiente paso diagnóstico.'
            : 'IAM/SCA já em etapa terapêutica: detalhe estratificação de risco, estratégia invasiva quando indicada, monitorização e manejo de complicações. Não repita ECG/troponina ou a antiagregação já fornecida como próximo passo diagnóstico.',
      );
    }

    final Map<ClinicalTopic, List<SmartNextAction>> plantaoMap = {
      ClinicalTopic.sca: [
        SmartNextAction(label: 'ECG + Troponina urgente', promptToSend: es ? 'ECG de 12 derivaciones en ≤10min y troponina ultrasensible en SCA: protocolo.' : 'ECG de 12 derivações em ≤10min e troponina ultrassensível no SCA: protocolo.'),
        SmartNextAction(label: es ? 'Doble antiagregación: dosis' : 'Dupla antiagregação: doses', promptToSend: es ? 'Dosis de AAS más Clopidogrel o Ticagrelor en la doble antiagregación inmediata del SCA.' : 'Doses de AAS + Clopidogrel ou Ticagrelor na dupla antiagregação imediata do SCA.'),
        SmartNextAction(label: es ? 'Fibrinólisis: dosis por peso' : 'Fibrinólise: dose por peso', promptToSend: es ? 'Dosis según peso de Tenecteplasa o Alteplasa IV en el SCA con elevación del ST.' : 'Doses por peso de Tenecteplase ou Alteplase IV no SCA com supradesnivelamento.'),
      ],
      ClinicalTopic.sepse: [
        SmartNextAction(label: es ? 'Titulación de vasopresores' : 'Titulação de vasopressores', promptToSend: es ? 'Dosis y titulación de Noradrenalina IV en el shock séptico; cuándo asociar Vasopresina.' : 'Dose e titulação de Noradrenalina IV no choque séptico; quando associar Vasopressina.'),
        SmartNextAction(label: es ? 'Paquete de la primera hora: estudios' : 'Bundle da hora 1: exames', promptToSend: es ? 'Paquete de la primera hora: cultivos, lactato sérico y cristaloides según peso en la sepsis.' : 'Bundle hora 1: culturas, lactato sérico e cristaloides por peso na sepse.'),
      ],
      ClinicalTopic.pcr: [
        SmartNextAction(label: es ? 'Algoritmo ACLS desfibrilable' : 'Algoritmo ACLS Chocável', promptToSend: es ? 'PCR en FV/TVSP: dosis de Adrenalina, Amiodarona y protocolo de desfibrilación.' : 'PCR em FV/TVSP: doses de Adrenalina, Amiodarona e protocolo de desfibrilação.'),
        SmartNextAction(label: es ? 'Manejo de causas: 5H y 5T' : 'Manejo de causas: 5Hs e 5Ts', promptToSend: es ? 'Causas reversibles de PCR: diagnóstico y tratamiento inmediato de las 5H y 5T.' : 'Causas reversíveis de PCR — diagnóstico e tratamento imediato das 5Hs e 5Ts.'),
      ],
      ClinicalTopic.intubacao: [
        SmartNextAction(label: es ? 'Dosis de secuencia rápida' : 'Doses da Sequência Rápida', promptToSend: es ? 'SRI: dosis de inductores (Etomidato/Cetamina) y bloqueantes neuromusculares (Rocuronio/Succinilcolina).' : 'SRI: doses de indutores (Etomidato/Cetamina) e bloqueadores (Rocurônio/Succinilcolina).'),
      ],
    };

    final Map<ClinicalTopic, List<SmartNextAction>> estudoMap = {
      ClinicalTopic.sca: [
        SmartNextAction(label: es ? 'IAMCEST × IAMSEST: diagnóstico' : 'IAMCSST × IAMSSST: diagnóstico', promptToSend: es ? 'Diferencia fisiopatológica y diagnóstico diferencial entre IAMCEST e IAMSEST.' : 'Diferença fisiopatológica e diagnóstico diferencial entre IAMCSST e IAMSSST.'),
        SmartNextAction(label: es ? 'Escalas de riesgo y pronóstico' : 'Escores de risco e prognóstico', promptToSend: es ? 'Variables y valor pronóstico de las escalas GRACE, TIMI y HEART en el SCA.' : 'Variáveis e valor prognóstico dos escores GRACE, TIMI e HEART no SCA.'),
      ],
      ClinicalTopic.sepse: [
        SmartNextAction(label: es ? 'Criterios Sepsis-3 y SOFA' : 'Critérios Sepsis-3 e SOFA', promptToSend: es ? 'Criterios Sepsis-3 y puntuación completa del SOFA: revisión objetiva.' : 'Critérios Sepsis-3 e pontuação completa do SOFA: revisão objetiva.'),
      ],
      ClinicalTopic.antidepressivos: [
        SmartNextAction(label: es ? 'ISRS × IRSN: farmacodinámica' : 'ISRS × IRSN: farmacodinâmica', promptToSend: es ? 'Comparación entre ISRS e IRSN: receptores, diferencias clínicas e interacciones del CYP.' : 'Comparativo entre ISRS e IRSN: receptores, diferenças clínicas e interações de CYP.'),
      ],
    };

    final targetList = isPlantaoMode ? plantaoMap[topic] : estudoMap[topic];

    if (targetList != null) {
      if (isPlantaoMode) {
        return _pickGuardiaAction(
          options: targetList,
          history: chatHistory,
          lastUserMessage: lastUserMessage,
          lastAiResponse: lastAiResponse,
        );
      }

      return _pickAction(targetList, chatHistory);
    }

    // ── Fallback Master: Plantão vs Estudo ─────────────────────────────────────
    // BUILD 256: topicName extraído dinamicamente do título 🟥 da resposta da IA
    // ou do texto da query do usuário — elimina o "este tema" estático que
    // causava respostas inválidas (Card Roxo) quando o histórico estava limpo.
    // BUILD 262: pass chatHistory so fallback can anchor to first user message
    final topicName = _extractPathologyName(
      lastAiResponse,
      lastUserMessage,
      chatHistory: chatHistory,
    );
    final hasTopicName = topicName.isNotEmpty;

    if (isPlantaoMode) {
      // BUILD 313 — Plantão: prompts humanizados — frases orgânicas de médico,
      // nunca comandos de sistema rígidos que disparam guardrails de segurança.
      return _pickGuardiaAction(
        options: [
        SmartNextAction(
          label: es ? 'Conductas y dosis' : 'Condutas e dosagens',
          continuationType: PlantaoContinuationType.treatmentExpansion,
          requestedSections: const <PlantaoSection>[
            PlantaoSection.immediateActions,
            PlantaoSection.fullTreatment,
            PlantaoSection.dosageClarification,
          ],
          promptToSend: es
              ? (hasTopicName
                  ? '¿Cuáles son las conductas clínicas inmediatas y las dosis recomendadas para este caso de $topicName?'
                  : '¿Cuáles son las conductas clínicas inmediatas y las dosis recomendadas para este caso de urgencia?')
              : (hasTopicName
                  ? 'Quais são as condutas clínicas imediatas e as dosagens recomendadas para este caso de $topicName?'
                  : 'Quais são as condutas clínicas imediatas e as dosagens recomendadas para este caso de urgência?'),
        ),
        SmartNextAction(
          label: es ? 'Estudios y evolución' : 'Exames e evolução',
          continuationType: PlantaoContinuationType.examsEvolution,
          requestedSections: const <PlantaoSection>[
            PlantaoSection.exams,
            PlantaoSection.monitoring,
            PlantaoSection.evolution,
            PlantaoSection.responseCriteria,
            PlantaoSection.worseningCriteria,
          ],
          promptToSend: es
              ? (hasTopicName
                  ? '¿Qué exámenes complementarios solicitar y cómo monitorear la evolución en $topicName?'
                  : '¿Qué exámenes y parámetros debo monitorear en este caso?')
              : (hasTopicName
                  ? 'Quais exames complementares solicitar e como monitorar a evolução em $topicName?'
                  : 'Quais exames e parâmetros devo monitorar neste caso?'),
        ),
        SmartNextAction(
          label: es ? 'Preguntas importantes' : 'Perguntas importantes',
          promptToSend: es
              ? (hasTopicName
                  ? '¿Qué preguntas clave debo hacer al paciente para orientar el manejo de $topicName?'
                  : '¿Qué preguntas clave debo hacer para orientar este caso clínico?')
              : (hasTopicName
                  ? 'Quais perguntas-chave devo fazer ao paciente para orientar o manejo de $topicName?'
                  : 'Quais perguntas-chave devo fazer para orientar este caso clínico?'),
        ),
        ],
        history: chatHistory,
        lastUserMessage: lastUserMessage,
        lastAiResponse: lastAiResponse,
      );
    } else {
      // BUILD 313 — Estudo: prompts humanizados para fins acadêmicos,
      // soam como perguntas naturais de um médico em contexto educacional.
      return _pickAction([
        SmartNextAction(
          label: es ? '✨ Profundizar Fisiopatología >' : '✨ Aprofundar Fisiopatologia >',
          promptToSend: es
              ? (hasTopicName
                  ? '¿Puede explicarme la fisiopatología de $topicName de forma detallada, con los mecanismos moleculares y celulares relevantes?'
                  : '¿Puede explicarme la fisiopatología de esta condición de forma detallada para fines académicos?')
              : (hasTopicName
                  ? 'Pode me explicar a fisiopatologia de $topicName de forma detalhada, com os mecanismos moleculares e celulares relevantes?'
                  : 'Pode me explicar a fisiopatologia desta condição de forma detalhada para fins acadêmicos?'),
        ),
        SmartNextAction(
          label: es ? '✨ Alternativas de 2ª Línea >' : '✨ Alternativas de 2ª Linha >',
          promptToSend: es
              ? (hasTopicName
                  ? '¿Cuáles son las alternativas terapéuticas de segunda línea para $topicName cuando el tratamiento inicial no es suficiente?'
                  : '¿Cuáles son las alternativas terapéuticas de segunda línea en este caso?')
              : (hasTopicName
                  ? 'Quais são as alternativas terapêuticas de segunda linha para $topicName quando o tratamento inicial não é suficiente?'
                  : 'Quais são as alternativas terapêuticas de segunda linha neste caso?'),
        ),
        SmartNextAction(
          label: es ? '✨ Comorbilidades y Alertas >' : '✨ Comorbidades e Alertas >',
          promptToSend: es
              ? (hasTopicName
                  ? '¿Qué comorbilidades y alertas clínicos debo considerar en el manejo de $topicName?'
                  : '¿Qué comorbilidades y alertas clínicos son relevantes en este caso?')
              : (hasTopicName
                  ? 'Quais comorbidades e alertas clínicos devo considerar no manejo de $topicName?'
                  : 'Quais comorbidades e alertas clínicos são relevantes neste caso?'),
        ),
      ], chatHistory);
    }
  }
}
