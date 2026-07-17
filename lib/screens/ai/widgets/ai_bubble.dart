import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import 'ai_block_bubble.dart';
import 'ai_skeleton_lines.dart';

String _cleanAiText(String raw) {
  String s = raw;

  // ── 1. Blocos XML de raciocínio interno (qualquer tag de CoT) ────────────
  // Remove tudo entre <thinking>...</thinking>, <scratchpad>...</scratchpad>,
  // <clinical_thinking>...</clinical_thinking>, etc. (greedy=false, dotAll)
  s = s.replaceAll(
    RegExp(
      r'<(thinking|scratchpad|internal|clinical_thinking|reasoning|planning|reflection|analysis|chain_of_thought|cot|thought|inner_monologue)>.*?<\/\1>',
      caseSensitive: false,
      dotAll: true,
    ),
    '',
  );
  // Remove tags órfãs (abertas sem fechar ou vice-versa)
  s = s.replaceAll(
    RegExp(
      r'<\/?(?:thinking|scratchpad|internal|clinical_thinking|reasoning|planning|reflection|analysis|chain_of_thought|cot|thought|inner_monologue)[^>]*>',
      caseSensitive: false,
    ),
    '',
  );

  // ── 2. Blocos de revisão interna com colchetes ────────────────────────────
  // Ex: [REVISAO_INTERNA...FIM_REVISAO_INTERNA] / [REVISION_INTERNA...]
  s = s.replaceAll(
    RegExp(
      r'\[(?:REVISAO_INTERNA|REVISION_INTERNA|FIM_REVISAO_INTERNA|FIN_REVISION_INTERNA|INTERNAL_REVIEW)[^\]]*\]',
      caseSensitive: false,
    ),
    '',
  );
  // Linhas isoladas que comecem com [REVISAO ou [REVISION ou [FIM
  s = s.replaceAll(
    RegExp(
      r'^\[(?:REVISAO|REVISION|FIM|FIN|INTERNAL|CHECKING|REVIEW)[^\]\n]*\]\s*$',
      caseSensitive: false,
      multiLine: true,
    ),
    '',
  );

  // ── 2b. Rótulos de modo interno vazados (Build 126 — PREFIX-ANCHORED) ─────
  // Build 126: cada alternativa agora usa prefixo EXATO de início de linha.
  // REMOVIDAS as alternativas perigosas: CAMADA\s+\d+.* e CAPA\s+\d+.* pois
  // produzem falsos-positivos em texto clínico como "CAMADA MUSCULAR CARDÍACA".
  // Mantidos apenas rótulos do sistema absolutamente inequívocos.
  s = s.replaceAll(
    RegExp(
      r'^(?:'
      r'MODO\s+ACTIVO\s*:?' // "MODO ACTIVO:" — rótulo interno
      r'|MODO\s+\[.\]\s+' // "MODO [A] ..." — rótulo interno
      r'|MODO\s+CONDUCTA\s' // "MODO CONDUCTA DIRECTA"
      r'|MODO\s+CONVERSACIONAL\s' // "MODO CONVERSACIONAL ..."
      r'|MODO\s+GUARDIA\s' // "MODO GUARDIA ..."
      r'|MODO\s+PLANTAO\s' // "MODO PLANTAO ..."
      r'|\[REVISIÓN\s+INTERNA\]' // tag literal colchete
      r'|\[REVISION_INTERNA\]'
      r'|\[REVISAO_INTERNA\]'
      r'|VERIFICACAO\s+INTERNA\s*:' // "VERIFICACAO INTERNA:"
      r'|VERIFICACIÓN\s+INTERNA\s*:'
      r'|Confianza\s+Cl[íi]nica\s*:' // "Confianza Clínica:"
      r'|Confian[çc]a\s+Cl[íi]nica\s*:' // "Confiança Clínica:"
      r'|Nivel\s+de\s+Confianza\s*:'
      r'|Confianza\s+Clinica\s*:' // sem acento
      r'|Confianca\s+Clinica\s*:'
      r'|Motivos?\s*(?:\([^)]*\))?\s*:' // "Motivo:" "Motivos:"
      r'|Motivo\s+del\s+(?:modo|activaci[oó]n)\s*:'
      r'|▶▶▶' // marcador interno do selfCheck
      r').*$',
      caseSensitive: false,
      multiLine: true,
    ),
    '',
  );

  // ── 3. Prefixos de planning/estruturação vazados (Build 126 — TIGHTENED) ──
  // Build 126: removidos prefixos ambíguos curtos ("I need to", "Let me",
  // "Para responder", "Deixe-me") que geravam falsos-positivos em texto clínico.
  // Mantidos apenas os inequívocos e longos.
  final cotPhrases = RegExp(
    r"^(My response should\s|I will structure\s|Let me think\s|I'll organize\s|"
    r"I should focus on\s|I'm going to\s|Vou estruturar\s|Devo focar\s|"
    r"Mi respuesta debe\s|Voy a estructurar\s|Estructurando la respuesta|"
    r"Pensando en la respuesta|Analizando el caso cl[íi]nico|Analisando o caso cl[íi]nico|"
    r"Antes de responder a\s|Before responding to\s|"
    r"Step \d+:|Paso \d+:|Etapa \d+:|Planning:|Reasoning:|Chain of thought:).*",
    caseSensitive: false,
    multiLine: true,
  );
  s = s.replaceAll(cotPhrases, '');

  // ── 4. Linhas de meta-comentário (Build 126 — removidos "Let me"/"Deixe-me") ──
  // "Let me" é ambíguo: "Let me clarify the dose..." é texto clínico legítimo.
  // "Deixe-me ver os critérios de Framingham..." também é legítimo.
  // Mantidos apenas os padrões mais longos e inequívocos.
  s = s.replaceAll(
    RegExp(
      r'^(Agora vou\s|Now I will\s|I will now\s|Vou agora\s|Ahora voy a\s|'
      r'Deixa eu pensar\s|Thinking\.\.\.|Analyzing\.\.\.|Processing\.\.\.).*$',
      caseSensitive: false,
      multiLine: true,
    ),
    '',
  );

  // ── 4c. PURGA PROFUNDA — Monólogo em 3ª pessoa multi-linha ──────────────
  // Captura blocos/sentenças iniciados por padrões de meta-raciocínio em 3ª pessoa.
  // Exemplos reais vazados do TestFlight:
  //   "O usuário solicitou um diagnóstico diferencial. O prompt é muito vago..."
  //   "Para fornecer uma resposta útil, preciso de mais informações..."
  //   "A base de dados local não possui um mapeamento específico..."
  //   "Portanto, a melhor abordagem é solicitar mais detalhes ao usuário..."

  // Padrão PT — linhas inteiras que começam com meta-raciocínio em 3ª pessoa
  s = s.replaceAll(
    RegExp(
      r'^(?:'
      r'O\s+usu[aá]rio\s+(?:solicitou|pediu|informou|forneceu|indicou|est[aá])'
      r'|O\s+m[eé]dico\s+(?:solicita|pergunta|pediu|quer|solicitou)'
      r'|Para\s+fornecer\s+uma\s+resposta\s+(?:[uú]til|adequada|completa)'
      r'|Para\s+(?:poder\s+)?(?:dar|fornecer|oferecer)\s+(?:uma\s+)?(?:resposta|conduta|informa)'
      r'|A\s+base\s+de\s+dados\s+(?:local\s+)?n[aã]o\s+(?:possui|cont[eé]m|tem|encontrou)'
      r'|Portanto,?\s+a\s+melhor\s+(?:abordagem|estrategia|opcao)'
      r'|O\s+prompt\s+(?:[eé]|parece|est[aá])\s+(?:muito\s+)?(?:vago|incompleto|ambiguo|curto|insuficiente)'
      r'|N[aã]o\s+(?:encontrei|tenho|possuo)\s+(?:dados|informacoes|contexto)\s+suficientes'
      r'|Precisaria\s+de\s+mais\s+(?:informacoes|dados|contexto|detalhes)'
      r'|Com\s+base\s+no\s+que\s+o\s+usu[aá]rio'
      r'|Baseado\s+(?:no|na|em)\s+(?:contexto|conversa|solicitacao|que\s+foi)'
      r'|A\s+seguir\s+(?:apresentarei|descrevo|apresento|fornecerei)'
      r'|O\s+(?:pedido|contexto|prompt|input)\s+(?:[eé]|est[aá]|foi|parece)'
      r').*$',
      caseSensitive: false,
      multiLine: true,
    ),
    '',
  );

  // Padrão ES — equivalente espanhol
  s = s.replaceAll(
    RegExp(
      r'^(?:'
      r'El\s+usuario\s+(?:solicit[oó]|pidi[oó]|indic[oó]|ha\s+(?:pedido|indicado|solicitado))'
      r'|El\s+m[eé]dico\s+(?:solicita|pregunta|ha\s+pedido|quiere)'
      r'|Para\s+proporcionar\s+una\s+respuesta\s+(?:[uú]til|adecuada|completa)'
      r'|Para\s+(?:poder\s+)?(?:dar|proporcionar|ofrecer)\s+(?:una\s+)?(?:respuesta|conducta|informa)'
      r'|La\s+base\s+de\s+datos\s+(?:local\s+)?no\s+(?:contiene|tiene|posee|encontr[oó])'
      r'|Por\s+lo\s+tanto,?\s+la\s+mejor\s+(?:estrategia|opci[oó]n|abordaje|aproximaci[oó]n)'
      r'|El\s+prompt\s+(?:es|parece|est[aá])\s+(?:muy\s+)?(?:vago|incompleto|ambiguo|corto|insuficiente)'
      r'|No\s+(?:encontr[eé]|tengo|poseo)\s+(?:datos|informaci[oó]n|contexto)\s+suficientes?'
      r'|Necesitar[ií]a\s+(?:m[aá]s\s+)?(?:informaci[oó]n|datos|contexto|detalles)'
      r'|Con\s+base\s+en\s+(?:lo\s+que\s+el\s+usuario|la\s+solicitud)'
      r'|Basado\s+en\s+(?:el\s+contexto|la\s+conversaci[oó]n|la\s+solicitud|lo\s+que)'
      r'|A\s+continuaci[oó]n\s+(?:presento|presentar[eé]|describir[eé]|proporcionar[eé])'
      r'|La\s+(?:pregunta|solicitud|consulta|query)\s+(?:es|parece|est[aá]|resulta)'
      r').*$',
      caseSensitive: false,
      multiLine: true,
    ),
    '',
  );

  // ── 4b. EXPURGO DE METADADOS (Build 126 — PREFIX-ANCHORED, SEM GREEDY) ────
  //
  // Build 126 FIX CRÍTICO: substituída regex `^.*Confian[zç]a.*$` (catch-all
  // destrutivo) por match de prefixo exato. A versão anterior apagava linhas
  // clínicas legítimas que continham "confiança" como parte do texto médico,
  // gerando o artefato "ElEl" em produção.
  //
  // NOVA POLÍTICA: eliminar SOMENTE linhas que COMEÇAM com o metadado.
  // Uma linha como "IAM — diagnóstico com alta confiança clínica" passa intacta.
  s = s.replaceAll(
    RegExp(
      r'^[|\s*]*(?:'
      r'Confian[zç]a\s*(?:Cl[íi]nica)?\s*(?:[:–—]|Alta|M[eé]dia|Baixa)' // "Confiança Clínica: Alta"
      r'|Confianza\s+Clinica\s*[:\s]'
      r'|Confianca\s+Clinica\s*[:\s]'
      r'|Clinical\s+Confidence\s*:'
      r'|Nivel\s+de\s+Confianza\s*:'
      r'|N[íi]vel\s+de\s+Confian[çc]a\s*:'
      r'|El\s+usuario\s+(?:solicita|proporciona|pregunta|pide|quiere|busca|ha\s+(?:indicado|pedido|proporcionado|solicitado)|solicit[oó])'
      r'|O\s+usu[aá]rio\s+(?:solicita|fornece|pergunta|pede|quer|busca|indicou|solicitou|informou|est[aá]\s+perguntando)'
      r'|The\s+user\s+(?:is\s+asking|asks|wants|requests|provides|has\s+indicated|has\s+asked)'
      r'|El\s+m[eé]dico\s+(?:solicita|pregunta|pide|ha\s+pedido)'
      r'|O\s+m[eé]dico\s+(?:solicita|pergunta|pede|solicitou)'
      r'|Baseado\s+(?:no|na|em)\s+(?:contexto|conversa|solicitac|que\s+(?:o\s+usu|foi))'
      r'|Basado\s+en\s+(?:el\s+contexto|la\s+conversaci[oó]n|la\s+solicitud|lo\s+que)'
      r'|Para\s+proporcionar\s+una\s+respuesta'
      r'|Para\s+fornecer\s+uma\s+resposta'
      r'|La\s+base\s+de\s+datos\s+(?:local\s+)?no\s+(?:contiene|tiene|posee)'
      r'|A\s+base\s+de\s+dados\s+(?:local\s+)?n[aã]o\s+(?:possui|cont[eé]m|tem)'
      r'|Por\s+lo\s+tanto,\s+(?:la\s+mejor|el\s+mejor)'
      r'|Portanto,\s+a\s+melhor\s+abordagem'
      r'|(?:El|La)\s+prompt\s+(?:es|parece)\s+(?:vago|incompleto)'
      r'|O\s+prompt\s+(?:[eé]|parece)\s+(?:vago|incompleto)'
      r'|A\s+seguir\s+(?:apresentarei|descrevo|apresento)'
      r'|A\s+continuaci[oó]n\s+(?:presento|presentar[eé])'
      r'|Motivos?\s*(?:\([^)]*\))?\s*:'
      r'|Motivo\s+del\s+(?:modo|activaci[oó]n)\s*:'
      r').*$',
      caseSensitive: false,
      multiLine: true,
    ),
    '',
  );

  // ── 5. Sanitização final de formatação ───────────────────────────────────
  s = s
      // ## e ### NÃO são removidos aqui — MarkdownBody renderiza H2/H3
      // nativamente via MarkdownStyleSheet (h2/h3 com tipografia clínica)
      .replaceAll('---', '') // separadores HR
      .replaceAll('--', '') // traços duplos
      .replaceAll(RegExp(r'\*{3,}'), ''); // *** ou mais

  // ── 5b. FALLBACK ANTI-ASTERISCO — camada de segurança Flutter ────────────
  // Build 115 FIX CRÍTICO: A regex original '(?<!\*)\*(?!\*)' destruía
  // marcadores de lista como '* Levodopa:' → ' Levodopa:' ANTES de
  // _isListItem() ter chance de detectá-los. Isso causava dois bugs:
  //   1. Asteriscos visíveis: o texto escapava sem ser detectado como lista
  //   2. Fragmentação: sem detecção de lista, _splitIntoBlocks() criava
  //      um AiBlockBubble por parágrafo separado por \n\n
  //
  // NOVA ESTRATÉGIA: Processamento linha a linha para PRESERVAR marcadores
  // de lista ('* texto', '* **Negrito') e remover apenas asteriscos realmente
  // soltos (itálico Markdown não suportado, asteriscos ornamentais, etc.).
  final lines5b = s.split('\n');
  final fixed5b = lines5b.map((line) {
    final t = line.trimLeft();
    // Linha que começa com '* ' (bullet clássico) — PRESERVAR INTACTA
    if (t.startsWith('* ')) return line;
    // Linha que começa com '* **' (bullet + negrito) — PRESERVAR INTACTA
    if (RegExp(r'^\*\s*\*\*').hasMatch(t)) return line;
    // Linha que começa com '*Texto' sem espaço (Gemini Flash-Lite) — PRESERVAR
    if (RegExp(r'^\*[^*\s]').hasMatch(t)) return line;
    // Para todas as outras linhas: remove * simples não-duplos (itálico/ornamental)
    return line.replaceAll(RegExp(r'(?<!\*)\*(?!\*)'), '');
  }).toList();
  s = fixed5b.join('\n');

  // ── 6. Normaliza linhas em branco excessivas (≥3 → 2) ────────────────────
  s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');

  // ── 7. NORMALIZADOR DE ACENTUAÇÃO MÉDICA — Safety Net Unicode ─────────────
  // Restaura acentuação correta em termos médicos estruturais que o modelo
  // às vezes emite sem acento (copiando labels do system prompt interno).
  //
  // ESTRATÉGIA: substituição por palavra inteira (word-boundary via look-ahead/
  // look-behind de não-letra) para não afetar substrings de outras palavras.
  // Opera somente em UPPERCASE para não alterar texto clínico em minúsculo.
  //
  // PORTUGUÊS — termos estruturais de saída (§ sections e emoji-headers):
  s = s
      // § section labels — Anatomia Fármaco
      .replaceAll(RegExp(r'\bDEFINICAO\b'), 'DEFINIÇÃO')
      .replaceAll(RegExp(r'\bINDICACAO\b'), 'INDICAÇÃO')
      .replaceAll(RegExp(r'\bINDICACOES\b'), 'INDICAÇÕES')
      .replaceAll(RegExp(r'\bPOSOLOGIA\b'), 'POSOLOGIA') // já correto, garante
      .replaceAll(RegExp(r'\bADMINISTRACAO\b'), 'ADMINISTRAÇÃO')
      .replaceAll(RegExp(r'\bMONITORIZACAO\b'), 'MONITORIZAÇÃO')
      .replaceAll(RegExp(r'\bMONITORIZACOES\b'), 'MONITORIZAÇÕES')
      .replaceAll(RegExp(r'\bCONTRAINDICACAO\b'), 'CONTRAINDICAÇÃO')
      .replaceAll(RegExp(r'\bCONTRAINDICACAOES\b'), 'CONTRAINDICAÇÕES')
      .replaceAll(RegExp(r'\bCONTRAINDICACOES\b'), 'CONTRAINDICAÇÕES')
      .replaceAll(RegExp(r'\bPRESCRICAO\b'), 'PRESCRIÇÃO')
      .replaceAll(RegExp(r'\bINTERACAO\b'), 'INTERAÇÃO')
      .replaceAll(RegExp(r'\bINTERACOES\b'), 'INTERAÇÕES')
      .replaceAll(RegExp(r'\bAVALIACAO\b'), 'AVALIAÇÃO')
      .replaceAll(RegExp(r'\bEFEITOS ADVERSOS\b'), 'EFEITOS ADVERSOS') // já OK
      // emoji-header section titles
      .replaceAll(RegExp(r'\bMEDICACAO\b'), 'MEDICAÇÃO')
      .replaceAll(RegExp(r'\bMEDICACOES\b'), 'MEDICAÇÕES')
      .replaceAll(RegExp(r'\bESCALONAMENTO\b'), 'ESCALONAMENTO') // já OK
      .replaceAll(RegExp(r'\bFARMACO\b'), 'FÁRMACO')
      .replaceAll(RegExp(r'\bFARMACOS\b'), 'FÁRMACOS')
      // ESPANHOL — termos estruturais de saída:
      .replaceAll(RegExp(r'\bDEFINICION\b'), 'DEFINICIÓN')
      .replaceAll(RegExp(r'\bINDICACION\b'), 'INDICACIÓN')
      .replaceAll(RegExp(r'\bINDICACIONES\b'), 'INDICACIONES') // já OK
      .replaceAll(RegExp(r'\bDOSIFICACION\b'), 'DOSIFICACIÓN')
      .replaceAll(RegExp(r'\bADMINISTRACION\b'), 'ADMINISTRACIÓN')
      .replaceAll(RegExp(r'\bMONITORIZACION\b'), 'MONITORIZACIÓN')
      .replaceAll(RegExp(r'\bINTERACCION\b'), 'INTERACCIÓN')
      .replaceAll(RegExp(r'\bINTERACCIONES\b'), 'INTERACCIONES') // já OK
      .replaceAll(RegExp(r'\bCONTRAINDICACION\b'), 'CONTRAINDICACIÓN')
      .replaceAll(RegExp(r'\bCONTRAINDICACIONES\b'), 'CONTRAINDICACIONES')
      .replaceAll(RegExp(r'\bPRESCRIPCION\b'), 'PRESCRIPCIÓN')
      .replaceAll(RegExp(r'\bINDICACION\b'), 'INDICACIÓN')
      .replaceAll(RegExp(r'\bREACCION\b'), 'REACCIÓN')
      .replaceAll(RegExp(r'\bREACCIONES ADVERSAS\b'), 'REACCIONES ADVERSAS')
      .replaceAll(RegExp(r'\bFARMACOLOGIA\b'), 'FARMACOLOGÍA')
      .replaceAll(RegExp(r'\bINTERACCIONES FARMACOLOGICAS\b'),
          'INTERACCIONES FARMACOLÓGICAS')
      // ── Build 100: Expansão Step 7 — seções clínicas de alta frequência ──────
      // Camada 2 do modelo emite esses títulos sem acento quando copia do
      // _responseFormatPt/_responseFormatEs que por segurança usa texto sem acentos.
      // PORTUGUÊS — seções adicionais da Camada 2:
      .replaceAll(RegExp(r'\bHIDRATACAO\b'), 'HIDRATAÇÃO')
      .replaceAll(RegExp(r'\bVENTILACAO\b'), 'VENTILAÇÃO')
      .replaceAll(RegExp(r'\bINTUBACAO\b'), 'INTUBAÇÃO')
      .replaceAll(RegExp(r'\bCOAGULACAO\b'), 'COAGULAÇÃO')
      .replaceAll(RegExp(r'\bINTOXICACAO\b'), 'INTOXICAÇÃO')
      .replaceAll(RegExp(r'\bFIBRILACAO ATRIAL\b'), 'FIBRILAÇÃO ATRIAL')
      .replaceAll(
          RegExp(r'\bFIBRILACAO VENTRICULAR\b'), 'FIBRILAÇÃO VENTRICULAR')
      .replaceAll(RegExp(r'\bFIBRILACAO\b'), 'FIBRILAÇÃO')
      .replaceAll(RegExp(r'\bDISFUNCAO\b'), 'DISFUNÇÃO')
      .replaceAll(RegExp(r'\bHIPOGLICEMIA\b'), 'HIPOGLICEMIA') // já correto
      .replaceAll(RegExp(r'\bHIPERGLICEMIA\b'), 'HIPERGLICEMIA') // já correto
      .replaceAll(
          RegExp(r'\bINSUFICIENCIA CARDIACA\b'), 'INSUFICIÊNCIA CARDÍACA')
      .replaceAll(RegExp(r'\bINSUFICIENCIA RENAL\b'), 'INSUFICIÊNCIA RENAL')
      .replaceAll(RegExp(r'\bINSUFICIENCIA RESPIRATORIA\b'),
          'INSUFICIÊNCIA RESPIRATÓRIA')
      .replaceAll(
          RegExp(r'\bINSUFICIENCIA HEPATICA\b'), 'INSUFICIÊNCIA HEPÁTICA')
      .replaceAll(RegExp(r'\bTROMBOEMBOLISMO PULMONAR\b'),
          'TROMBOEMBOLISMO PULMONAR') // já OK
      .replaceAll(RegExp(r'\bACIDENTE VASCULAR CEREBRAL\b'),
          'ACIDENTE VASCULAR CEREBRAL') // já OK
      .replaceAll(RegExp(r'\bPROFILAXIA\b'), 'PROFILAXIA') // já correto
      .replaceAll(
          RegExp(r'\bDIAGNOSTICO DIFERENCIAL\b'), 'DIAGNÓSTICO DIFERENCIAL')
      .replaceAll(RegExp(r'\bDIAGNOSTICO\b'), 'DIAGNÓSTICO')
      .replaceAll(RegExp(r'\bEMERGENCIA\b'), 'EMERGÊNCIA')
      .replaceAll(RegExp(r'\bTRATAMENTO EMPIRICO\b'), 'TRATAMENTO EMPÍRICO')
      .replaceAll(
          RegExp(r'\bTRATAMENTO FARMACOLOGICO\b'), 'TRATAMENTO FARMACOLÓGICO')
      .replaceAll(RegExp(r'\bESTABILIZACAO\b'), 'ESTABILIZAÇÃO')
      .replaceAll(RegExp(r'\bEVOLUCAO\b'), 'EVOLUÇÃO')
      .replaceAll(RegExp(r'\bSEDASAO\b'), 'SEDAÇÃO')
      .replaceAll(RegExp(r'\bSEDASAO E ANALGESIA\b'), 'SEDAÇÃO E ANALGESIA')
      .replaceAll(RegExp(r'\bANALGESIA\b'), 'ANALGESIA') // já correto
      .replaceAll(RegExp(r'\bANTICOAGULACAO\b'), 'ANTICOAGULAÇÃO')
      .replaceAll(RegExp(r'\bTRANSFUSAO\b'), 'TRANSFUSÃO')
      .replaceAll(RegExp(r'\bINFECCAO\b'), 'INFECÇÃO')
      .replaceAll(RegExp(r'\bINFECCAO DO TRATO\b'), 'INFECÇÃO DO TRATO')
      .replaceAll(RegExp(r'\bCOMPLICACAO\b'), 'COMPLICAÇÃO')
      .replaceAll(RegExp(r'\bCOMPLICACOES\b'), 'COMPLICAÇÕES')
      .replaceAll(RegExp(r'\bATENCAO\b'), 'ATENÇÃO')
      .replaceAll(RegExp(r'\bRECOMENDACAO\b'), 'RECOMENDAÇÃO')
      .replaceAll(RegExp(r'\bRECOMENDACOES\b'), 'RECOMENDAÇÕES')
      .replaceAll(RegExp(r'\bINFUSOES\b'), 'INFUSÕES')
      .replaceAll(RegExp(r'\bINFUSAO\b'), 'INFUSÃO')
      .replaceAll(RegExp(r'\bASSICIACAO\b'), 'ASSOCIAÇÃO')
      .replaceAll(RegExp(r'\bASSOCIACAO\b'), 'ASSOCIAÇÃO')
      // ESPANHOL — seções adicionais da Capa 2:
      .replaceAll(RegExp(r'\bHIDRATACION\b'), 'HIDRATACIÓN')
      .replaceAll(RegExp(r'\bVENTILACION\b'), 'VENTILACIÓN')
      .replaceAll(RegExp(r'\bINTUBACION\b'), 'INTUBACIÓN')
      .replaceAll(RegExp(r'\bCOAGULACION\b'), 'COAGULACIÓN')
      .replaceAll(RegExp(r'\bINTOXICACION\b'), 'INTOXICACIÓN')
      .replaceAll(RegExp(r'\bFIBRILACION AURICULAR\b'), 'FIBRILACIÓN AURICULAR')
      .replaceAll(
          RegExp(r'\bFIBRILACION VENTRICULAR\b'), 'FIBRILACIÓN VENTRICULAR')
      .replaceAll(RegExp(r'\bFIBRILACION\b'), 'FIBRILACIÓN')
      .replaceAll(RegExp(r'\bDISFUNCION\b'), 'DISFUNCIÓN')
      .replaceAll(
          RegExp(r'\bINSUFICIENCIA CARDIACA\b'), 'INSUFICIENCIA CARDÍACA')
      .replaceAll(
          RegExp(r'\bINSUFICIENCIA RENAL\b'), 'INSUFICIENCIA RENAL') // já OK
      .replaceAll(RegExp(r'\bINSUFICIENCIA RESPIRATORIA\b'),
          'INSUFICIENCIA RESPIRATORIA') // já OK
      .replaceAll(
          RegExp(r'\bDIAGNOSTICO DIFERENCIAL\b'), 'DIAGNÓSTICO DIFERENCIAL')
      .replaceAll(
          RegExp(r'\bEMERGENCIA\b'), 'EMERGENCIA') // sem acento em ES — já OK
      .replaceAll(RegExp(r'\bESTABILIZACION\b'), 'ESTABILIZACIÓN')
      .replaceAll(RegExp(r'\bEVOLUCION\b'), 'EVOLUCIÓN')
      .replaceAll(RegExp(r'\bSEDACION\b'), 'SEDACIÓN')
      .replaceAll(RegExp(r'\bANTICOAGULACION\b'), 'ANTICOAGULACIÓN')
      .replaceAll(RegExp(r'\bTRANSFUSION\b'), 'TRANSFUSIÓN')
      .replaceAll(RegExp(r'\bINFECCION\b'), 'INFECCIÓN')
      .replaceAll(RegExp(r'\bCOMPLICACION\b'), 'COMPLICACIÓN')
      .replaceAll(RegExp(r'\bCOMPLICACIONES\b'), 'COMPLICACIONES') // já OK
      .replaceAll(RegExp(r'\bATENCION\b'), 'ATENCIÓN')
      .replaceAll(RegExp(r'\bINFUSION\b'), 'INFUSIÓN')
      .replaceAll(RegExp(r'\bINFUSIONES\b'), 'INFUSIONES')
      .replaceAll(RegExp(r'\bASSOCIACION\b'), 'ASOCIACIÓN')
      .replaceAll(RegExp(r'\bASOCIACION\b'), 'ASOCIACIÓN');

  return s.trim();
}

/// Widget de um único bloco da IA — bolha hospitalar com hierarquia visual.
/// P4: Densidade hospitalar + leitura rápida de plantão.

/// Widget pai que divide a resposta completa em múltiplas AiBlockBubble.
class AiBubble extends StatefulWidget {
  final String text;
  final bool dark;
  final VoidCallback onCopy;
  final bool animate;
  final String lang; // globalLanguageLock — propagado para AiBlockBubble
  // TTS
  final bool ttsPlaying;
  final bool ttsReady;
  final VoidCallback? onTts;

  /// Token de geração — invalida callbacks de bolhas antigas (anti-jump fix)
  final int scrollGeneration;

  /// Callback para notificar o pai que um bloco foi revelado
  final void Function(int generation)? onBlockRevealed;

  /// true enquanto esta bolha está sendo preenchida por streaming V2
  /// (exibe cursor piscante ▌ após o texto)
  final bool isStreaming;

  /// Build 120 — ActionChip: dispara _send() com o texto da pergunta de fechamento
  final void Function(String chipText)? onChipTap;

  /// Build 188 — ValueNotifier para streaming ultra-localizado:
  /// Quando não-nulo, a bolha escuta este notifier diretamente em vez de
  /// depender de widget.text para atualizar chunks — zero rebuild na tela pai.
  final ValueNotifier<String>? streamingTextNotifier;
  const AiBubble({
    super.key,
    required this.text,
    required this.dark,
    required this.onCopy,
    this.animate = false,
    this.lang = 'pt',
    this.ttsPlaying = false,
    this.ttsReady = false,
    this.onTts,
    this.scrollGeneration = 0,
    this.onBlockRevealed,
    this.isStreaming = false,
    this.onChipTap,
    this.streamingTextNotifier,
  });

  @override
  State<AiBubble> createState() => AiBubbleState();
}

class AiBubbleState extends State<AiBubble> {
  // Quantos blocos já estão visíveis
  int _visibleCount = 0;
  bool _started = false;

  // ⚡ Cache dos blocos — computado UMA vez no initState/didUpdateWidget
  // Evita reprocessar _cleanAiText + _splitIntoBlocks em cada rebuild do scroll
  late List<String> _cachedBlocks;

  // Build 188: texto exibido — pode ser alimentado por widget.text (estático)
  // ou por _streamingNotifier (streaming ultra-localizado).
  String _displayText = '';

  // Referência ao notifier atual — para removeListener no dispose/update
  ValueNotifier<String>? _attachedNotifier;

  // ── BUILD 462-STREAMING-CORE: Batch Rendering Engine (40ms) ─────────────
  // Desacopla a chegada de chunks da rede (networkBuffer) da atualização
  // da UI (visibleTextNotifier). Limita rebuilds a 25/s (suavidade biológica).
  //
  // Ciclo de vida:
  //   1. Chunk chega em _onRawChunk() → escrito em _networkBuffer (zero setState)
  //   2. _renderTimer (40ms) → drena _networkBuffer → atualiza _displayText
  //      e _cachedBlocks em UM único setState por tick
  //   3. No onDone: _renderTimer cancelado → setState final com texto completo
  //      → _streamingComplete=true → build() usa MarkdownBody em vez de SelectableText
  //
  // Fase "Skeleton": quando widget.isStreaming=true mas _displayText está vazio
  //   (AiStarted recebido, nenhum AiTextDelta ainda), exibe linhas pulsantes.
  // ─────────────────────────────────────────────────────────────────────────

  /// Buffer de rede: recebe deltas brutos sem custo de setState.
  /// Drenado a cada 40ms pelo [_renderTimer].
  final StringBuffer _networkBuffer = StringBuffer();

  /// Timer periódico de 40ms — opera APENAS durante streaming ativo.
  Timer? _renderTimer;

  /// true após o evento de conclusão (AiCompleted / isDone) — troca
  /// SelectableText pelo MarkdownBody completo no próximo frame.
  bool _streamingComplete = false;

  // ── Drena o buffer de rede e atualiza UI a cada 40ms ─────────────────
  void _startRenderTimer() {
    _renderTimer?.cancel();
    _renderTimer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (!mounted) {
        _renderTimer?.cancel();
        _renderTimer = null;
        return;
      }
      final pending = _networkBuffer.toString();
      if (pending.isEmpty) return;
      _networkBuffer.clear();

      // Acumula no display text (o buffer contém o DELTA, não o acumulado)
      final newText = _displayText + pending;
      try {
        setState(() {
          _displayText = newText;
          _cachedBlocks = _computeBlocksFromText(newText);
          if (_cachedBlocks.isNotEmpty && _visibleCount < 1) {
            _visibleCount = 1;
          }
          if (_cachedBlocks.length > _visibleCount) {
            _visibleCount = _cachedBlocks.length;
          }
        });
      } catch (_) {}

      if (widget.isStreaming && widget.onBlockRevealed != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          widget.onBlockRevealed!(widget.scrollGeneration);
        });
      }
    });
  }

  void _stopRenderTimer() {
    _renderTimer?.cancel();
    _renderTimer = null;
  }

  // ── Listener do notifier: recebe delta acumulado do provider ──────────
  // O notifier passa o texto ACUMULADO completo (comportamento legado).
  // Convertemos para delta (diff em relação ao _displayText anterior)
  // e empurramos apenas o novo fragmento para o _networkBuffer.
  void _onStreamingChunk() {
    if (!mounted) return;
    final notifier = _attachedNotifier;
    if (notifier == null) return;
    final fullAccumulated = notifier.value;

    // Extrai apenas o delta desde o último texto conhecido
    final prevLen = _displayText.length + _networkBuffer.length;
    if (fullAccumulated.length > prevLen) {
      final delta = fullAccumulated.substring(prevLen);
      _networkBuffer.write(delta);
    } else if (fullAccumulated.length < _displayText.length) {
      // Regressão rara (strip de metadata): reseta o buffer com o novo texto
      _networkBuffer.clear();
      _networkBuffer.write(fullAccumulated
          .substring(_displayText.length.clamp(0, fullAccumulated.length)));
    }

    // Garante que o timer está ativo durante o streaming
    if (_renderTimer == null || !_renderTimer!.isActive) {
      _startRenderTimer();
    }
  }

  void _attachNotifier(ValueNotifier<String>? notifier) {
    if (_attachedNotifier == notifier) return;
    _attachedNotifier?.removeListener(_onStreamingChunk);
    _attachedNotifier = notifier;
    _attachedNotifier?.addListener(_onStreamingChunk);
  }

  @override
  void initState() {
    super.initState();
    _displayText = widget.text;
    _cachedBlocks = _computeBlocksFromText(_displayText);
    _attachNotifier(widget.streamingTextNotifier);
    // Inicia a sequência de exibição após o primeiro frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _startSequence());
  }

  @override
  void dispose() {
    _stopRenderTimer();
    _attachedNotifier?.removeListener(_onStreamingChunk);
    _attachedNotifier = null;
    super.dispose();
  }

  @override
  void didUpdateWidget(AiBubble old) {
    super.didUpdateWidget(old);

    // Build 188: atualiza o listener do notifier se mudou
    if (old.streamingTextNotifier != widget.streamingTextNotifier) {
      _attachNotifier(widget.streamingTextNotifier);
    }

    final textChanged = old.text != widget.text;
    final streamingChanged = old.isStreaming != widget.isStreaming;

    // ── BUILD 462: Detecta conclusão do stream (true → false) ─────────────
    // Quando streaming termina: para o timer, drena qualquer delta residual
    // no buffer, comita o texto final definitivo e marca _streamingComplete=true
    // para que o build() substitua SelectableText → MarkdownBody.
    final streamingJustEnded = old.isStreaming && !widget.isStreaming;
    if (streamingJustEnded) {
      _stopRenderTimer();
      // Drena buffer residual sincronamente antes do setState final
      final residual = _networkBuffer.toString();
      _networkBuffer.clear();
      // Texto final definitivo: usa widget.text (commitado pelo provider) como
      // source-of-truth — descarta qualquer delta residual que possa ter chegado
      // fora de ordem nos últimos milissegundos do stream.
      try {
        setState(() {
          _displayText =
              widget.text.isNotEmpty ? widget.text : (_displayText + residual);
          _cachedBlocks = _computeBlocksFromText(_displayText);
          _streamingComplete = true;
          if (_cachedBlocks.isNotEmpty) _visibleCount = _cachedBlocks.length;
        });
      } catch (_) {}
    }

    if (!textChanged && !streamingChanged) return;

    // ── CORREÇÃO CRÍTICA DE REATIVIDADE ─────────────────────────────────────
    // Build 188: quando o notifier está ativo e streaming, os chunks chegam via
    // _onStreamingChunk() — não precisamos processar widget.text aqui.
    // Só processa widget.text quando: (a) não há notifier, ou (b) streaming acabou.
    final hasActiveNotifier = _attachedNotifier != null && widget.isStreaming;

    // Sempre atualiza _displayText a partir de widget.text quando streaming termina
    // ou quando não há notifier (bolha histórica).
    if (!hasActiveNotifier || streamingJustEnded) {
      try {
        setState(() {
          _displayText = widget.text;
          _cachedBlocks = _computeBlocksFromText(_displayText);

          // Durante streaming: garante que _visibleCount >= 1 assim que o
          // primeiro bloco existe, mesmo que _startSequence ainda não rodou.
          // Sem isso, o primeiro chunk ficava invisível (visibleCount=0).
          if (widget.isStreaming &&
              _cachedBlocks.isNotEmpty &&
              _visibleCount < 1) {
            _visibleCount = 1;
          }

          // Quando novos blocos aparecem (quebras de parágrafo no stream),
          // avança _visibleCount para revelar imediatamente — sem delay de animação.
          // A animação de "revelação em sequência" só se aplica à resposta final,
          // não ao texto chegando em tempo real.
          if (widget.isStreaming && _cachedBlocks.length > _visibleCount) {
            _visibleCount = _cachedBlocks.length;
          }

          // ── BUILD 101 FIX: garante visibilidade total ao fim do stream ────────
          // Quando isStreaming muda de true → false (cursor removido), o
          // _computeBlocksFromText() pode gerar um nº diferente de blocos (sem o ▌).
          // Garante que _visibleCount cobre TODOS os blocos finais — evita que
          // o último bloco fique invisível se o count anterior era para blocos-com-cursor.
          if (streamingJustEnded && _cachedBlocks.isNotEmpty) {
            _visibleCount = _cachedBlocks.length;
          }
        });
      } catch (_) {
        // Falha de render silenciosa: mantém estado anterior da bolha intacto.
        // O próximo chunk válido aciona novo didUpdateWidget e recupera a tela.
      }
    }

    // Scroll para o fim a cada chunk — texto cresce e médico acompanha
    if (widget.isStreaming && textChanged && widget.onBlockRevealed != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onBlockRevealed!(widget.scrollGeneration);
      });
    }

    // ── BUILD 101 FIX: scroll final quando streaming termina ──────────────
    // Quando isStreaming muda de true → false, o cursor ▌ é removido e o
    // _computeBlocks() recomputa os blocos sem ele. Este addPostFrameCallback
    // garante que o scroll se ajusta ao layout final DEPOIS que os blocos sem
    // cursor foram renderizados — eliminando o congelamento mid-screen.
    if (!widget.isStreaming &&
        old.isStreaming &&
        widget.onBlockRevealed != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onBlockRevealed!(widget.scrollGeneration);
      });
    }
  }

  /// Build 188: renomeado de _computeBlocks para aceitar texto como parâmetro
  /// explícito (em vez de sempre usar widget.text) — necessário para que
  /// _onStreamingChunk possa computar blocos do texto do notifier.
  ///
  /// BUILD 277-PATCH: bypass transparente de _cleanAiText para o caminho
  /// não-streaming (texto final commitado). O RAW_AI_OUTPUT é injetado
  /// diretamente sem mutação de string intermediária — preserva marcadores
  /// de negrito (**) e emojis adjacentes intactos.
  /// _cleanAiText é mantido APENAS para o caminho de streaming (chunks parciais)
  /// onde a sanitização de CoT/metadados ainda é necessária durante o stream.
  List<String> _computeBlocksFromText(String text) {
    // Build 123 — DESTRUIÇÃO DO SPLIT:
    // _splitIntoBlocks() foi removido do pipeline de renderização.
    // 100% do texto da IA é retornado como UM ÚNICO elemento de lista.
    // AiBlockBubble recebe o texto completo e renderiza com MarkdownBody fluido.
    // ZERO fatiamento. ZERO containers escuros múltiplos. ZERO fallback de blocos.
    //
    // ORDEM 27 — ISOLAMENTO ABSOLUTO DO PIPELINE DO PLANTÃO:
    // _cleanAiText() É PROIBIDO para texto final do Plantão. O BUILD 277-PATCH
    // já garante o bypass pelo gate isStreaming==false (pass-through direto).
    // O único caminho legítimo para _cleanAiText() é o streaming parcial de chunks
    // (isStreaming==true) — onde a sanitização de CoT/metadados ainda é necessária.
    // Plantão finalizado (isPlantaoFinalBubble) nunca usa _AiBubble, portanto
    // este método NUNCA é chamado pelo render engine do Plantão pós-ORDEM 26.
    try {
      final displayText = widget.isStreaming ? '$text\u258c' : text;
      final safeText = widget.isStreaming
          ? _sanitizePartialMarkdown(displayText)
          : displayText;

      // BUILD 277-PATCH — BYPASS TRANSPARENTE (ORDEM 27: isolamento Plantão):
      // Caminho não-streaming (texto final commitado): pass-through RAW_AI_OUTPUT.
      //   → _cleanAiText() NUNCA chamada → zero CPU desperdiçado em regex pesado
      //     para texto já processado pelo PlantatoPipeline ou pelo Estudo renderer.
      // Caminho streaming (chunks parciais): _cleanAiText() APENAS aqui,
      //   filtrando CoT/metadados/asteriscos ornamentais durante o stream activo.
      final String result;
      if (widget.isStreaming) {
        // ORDEM 27: _cleanAiText() chamada SOMENTE neste branch (streaming chunk).
        // Confirma isolamento: se chegar aqui com isPlantaoFinalBubble=true seria
        // impossível pois _AiBubble não é instanciado para bolhas finais do Plantão.
        if (kDebugMode)
          debugPrint(
              '[CPU_GUARD] _cleanAiText called — isStreaming=true (legítimo)');
        final cleaned = _cleanAiText(safeText);
        result = cleaned.isEmpty ? safeText.trim() : cleaned;
      } else {
        // Texto final: pass-through direto — preserva toda a formatação Markdown.
        // _cleanAiText() NÃO é chamada — isolamento CPU garantido.
        result = safeText.trim();
      }

      return result.isEmpty ? [] : [result];
    } catch (_) {
      if (_cachedBlocks.isNotEmpty) return _cachedBlocks;
      final fallback = text.trim();
      return fallback.isEmpty ? [] : [fallback];
    }
  }

  /// Sanitiza markdown incompleto durante o streaming chunk a chunk.
  ///
  /// Problemas comuns ao renderizar texto parcial:
  ///  • "* " sozinho no fim  → marcador de lista sem conteúdo ainda
  ///  • "- " sozinho no fim  → traço de lista sem texto
  ///  • "**texto" sem fechar → negrito não terminado quebra layout
  ///  • "### " sem título    → cabeçalho vazio
  ///  • "🟥" / "⛔" sozinho  → emoji de card sem texto ainda
  ///  • "🟥 AMO" incompleto  → card parcialmente digitado
  ///
  /// Estratégia: inspeciona apenas a ÚLTIMA linha (fragmento em construção).
  /// Linhas anteriores já chegaram completas e não são alteradas.
  ///
  /// Build 112 — REACTIVE CARD DETECTION (substitui supressão do Build 108):
  /// Ao detectar emoji de card (🟥 ⛔ 📌 📚 🚨 💊) na última linha, NÃO suprimir.
  /// Em vez disso, completar o token para que o AiBlockBubble abra o container
  /// do card IMEDIATAMENTE, mesmo com texto parcial — eliminando o "vazamento cru".
  ///
  /// Estratégia v2:
  ///  • Emoji sozinho (sem texto) → preservar com placeholder mínimo "…"
  ///    para que o parser reconheça como header e abra o card colorido.
  ///  • Emoji + texto parcial curto → preservar como está (card abre imediatamente).
  ///  • Apenas texto de "thinking" interno (sem emoji de card) antes do \n → suprimir.
  static String _sanitizePartialMarkdown(String text) {
    if (text.isEmpty) return text;

    final lines = text.split('\n');
    final lastIdx = lines.length - 1;
    String last = lines[lastIdx];

    // Remove cursor ▌ para analisar o conteúdo real
    final hasCursor = last.endsWith('\u258c');
    if (hasCursor) last = last.substring(0, last.length - 1);

    final trimmedLast = last.trimLeft();

    // ── Build 112: tokens de card UI — detecção reativa imediata ────────────
    // Quando a última linha começa com um emoji de card, abrimos o container
    // do card imediatamente — sem threshold de supressão.
    // Se o emoji está totalmente sozinho (sem nenhum char após), injetamos
    // um placeholder mínimo para que o AiBlockBubble reconheça como header
    // e instancie o card colorido antes do texto chegar.
    final cardEmojiRx = RegExp(r'^(🟥|⛔|📌|📚|🚨|💊)');
    if (cardEmojiRx.hasMatch(trimmedLast)) {
      final afterEmoji = trimmedLast.replaceFirst(cardEmojiRx, '').trim();
      if (afterEmoji.isEmpty) {
        // Emoji sozinho → preserva a linha com um espaço após o emoji para que
        // o AiBlockBubble reconheça o token e instancie o container do card.
        // O texto real substituirá o espaço nos próximos chunks do stream.
        // Não há artefato visual: o container aparece imediatamente mas vazio.
        last = '$trimmedLast ';
      }
      // Se já tem qualquer texto após o emoji, deixa passar normalmente.
      // O AiBlockBubble já abre o card com conteúdo parcial disponível.
    }
    // ── Supressão de pensamento interno vazado (linha sem emoji de card) ────
    // Padrões de CoT que ainda podem aparecer na última linha durante streaming:
    // ex: "Let me think", "I'll structure", "Okay, I need to"
    else if (_looksLikeLeakedThought(trimmedLast)) {
      last = ''; // suprimir linha — CoT não deve aparecer na UI
    }
    // Marcador de lista sozinho ("* ", "- ", "• " sem texto após)
    else if (RegExp(r'^[\*\-•]\s*$').hasMatch(trimmedLast)) {
      last = '';
    }
    // Cabeçalho markdown vazio ("## ", "### " sem título ainda)
    else if (RegExp(r'^#{1,3}\s*$').hasMatch(trimmedLast)) {
      last = '';
    }
    // Negrito não fechado: conta pares de "**" — se ímpar, está aberto
    else {
      final pairs = RegExp(r'\*\*').allMatches(last).length;
      if (pairs.isOdd) {
        // Fecha provisoriamente para não quebrar o RichText inline
        last = '$last**';
      }
    }

    if (hasCursor) last = '$last\u258c';
    lines[lastIdx] = last;
    return lines.join('\n');
  }

  /// Detecta padrões de "pensamento interno" (CoT leaked) na última linha
  /// do stream — expressões que indicam o modelo "pensando em voz alta".
  /// Usado por _sanitizePartialMarkdown() para suprimir antes da exibição.
  static bool _looksLikeLeakedThought(String line) {
    if (line.isEmpty) return false;
    final lower = line.toLowerCase();
    // Padrões em inglês (vazamento de CoT interno do modelo)
    if (lower.startsWith("let me ") ||
        lower.startsWith("okay, ") ||
        lower.startsWith("i'll ") ||
        lower.startsWith("i need to ") ||
        lower.startsWith("i should ") ||
        lower.startsWith("i will ") ||
        lower.startsWith("first, i") ||
        lower.startsWith("the user ") ||
        lower.startsWith("the user's ") ||
        lower.startsWith("the doctor ") ||
        lower.startsWith("this is a ") ||
        lower.startsWith("this implies") ||
        lower.startsWith("looking at ") ||
        lower.startsWith("user input analysis") ||
        lower.startsWith("assumed patient") ||
        lower.startsWith("constructing ") ||
        lower.startsWith("since the user") ||
        lower.startsWith("as the previous") ||
        lower.startsWith("given the context") ||
        lower.startsWith("given the previous") ||
        lower.startsWith("interpreting ") ||
        lower.startsWith("the previous response") ||
        lower.startsWith("my task ") ||
        lower.startsWith("to address ") ||
        lower.startsWith("the question asked") ||
        lower.startsWith("based on the previous") ||
        // Padrão "< DIAGNÓSTICO. texto análise..."
        (line.startsWith('<') &&
            lower.contains(" the ") &&
            lower.contains("response"))) {
      return true;
    }
    // Padrões em português (meta-comentário de intenção)
    if (lower.startsWith("o usuário ") ||
        lower.startsWith("o médico ") ||
        lower.startsWith("preciso ") ||
        lower.startsWith("vou ") ||
        lower.startsWith("deixa eu ") ||
        lower.startsWith("primeiro, ") ||
        lower.startsWith("pensando ") ||
        lower.startsWith("analisando ")) {
      return true;
    }
    return false;
  }

  void _startSequence() {
    if (_started || !mounted) return;
    _started = true;

    final total = _cachedBlocks.isEmpty ? 1 : _cachedBlocks.length;

    if (!widget.animate || total <= 1) {
      // Sem animação (histórico) ou bloco único → mostra tudo imediatamente
      if (mounted) setState(() => _visibleCount = total);
      // Notifica o pai mesmo para bloco único (para scroll até o fundo)
      if (widget.animate && widget.onBlockRevealed != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onBlockRevealed!(widget.scrollGeneration);
        });
      }
      return;
    }

    // ── Revelar blocos sequencialmente ──────────────────────────────────────
    // Delay: 80ms primeiro bloco, 450ms subsequentes (mais rápido = menos conflito)
    // CRÍTICO: cada Future captura o `gen` no momento do agendamento.
    // Quando o pai incrementa `_scrollGeneration`, os Futures antigos passam
    // a enviar um gen desatualizado → _onBlockRevealed ignora. Zero jumps.
    final gen = widget.scrollGeneration;
    for (int i = 0; i < total; i++) {
      final delayMs = i == 0 ? 80 : (80 + i * 420).clamp(0, 3000);
      Future.delayed(Duration(milliseconds: delayMs), () {
        if (!mounted) return;
        // Se a geração mudou (nova resposta chegou), não revela mais blocos.
        if (widget.scrollGeneration != gen) return;

        setState(() => _visibleCount = i + 1);

        // Delega scroll ao pai — apenas uma chamada, sem animateTo aqui.
        // O pai (_AiScreenState._onBlockRevealed) decide o que fazer.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (widget.scrollGeneration != gen) return;
          widget.onBlockRevealed?.call(gen);
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── BUILD 462: SKELETON SCREEN — fase AiStarted (antes do 1º delta) ─────
    // Quando streaming está ativo mas nenhum texto chegou ainda (conexão
    // estabelecida, aguardando primeiro AiTextDelta), exibe 3 linhas pulsantes.
    // Transição natural: skeleton → SelectableText (primeiros chars) → MarkdownBody.
    if (widget.isStreaming && _displayText.isEmpty && _networkBuffer.isEmpty) {
      return RepaintBoundary(
        child: AiSkeletonLines(dark: widget.dark),
      );
    }

    // Build 123: _visibleCount não bloqueia mais — sempre exibe se há texto.
    if (_visibleCount == 0) return const SizedBox.shrink();

    // ── BUILD 462: DIPARO ÚNICO DO MARKDOWN ─────────────────────────────────
    // DURANTE streaming ativo (!_streamingComplete):
    //   → SelectableText com estilo limpo (height: 1.45) — zero overhead de parse
    //   → texto bruto do _displayText acumulado pelo batch timer (40ms)
    //   → SelectionArea do pai permanece 100% funcional
    //
    // APÓS conclusão (_streamingComplete = true):
    //   → MarkdownBody substitui SelectableText EM UM ÚNICO FRAME
    //   → aplica negritos, listas, emojis de card 🟥, hierarquia clínica
    //   → usuário vivencia velocidade do texto cru + layout premium na finalização
    if (widget.isStreaming && !_streamingComplete) {
      // ── Texto em fluxo: SelectableText cru, máxima velocidade ──────────────
      final rawText = _displayText.isNotEmpty ? _displayText : '';
      // Remove cursor ▌ do texto bruto (adicionado pelo _computeBlocksFromText)
      final displayRaw = rawText.replaceAll('\u258c', '');
      final textColor = widget.dark
          ? Colors.white.withOpacity(0.88)
          : const Color(0xFF1A202C);
      return RepaintBoundary(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: SelectableText(
            displayRaw,
            style: TextStyle(
              fontSize: 14.5,
              color: textColor,
              height: 1.45,
              fontFamily: 'Roboto',
              letterSpacing: 0.01,
            ),
          ),
        ),
      );
    }

    // ── Streaming concluído ou bolha histórica: AiBlockBubble com MarkdownBody
    // Build 123 — texto único direto: sem join, sem fragmentação.
    // Build 188: usa _displayText (pode vir do notifier) em vez de widget.text.
    final unified =
        _cachedBlocks.isNotEmpty ? _cachedBlocks.first : _displayText.trim();

    if (unified.isEmpty) return const SizedBox.shrink();

    return RepaintBoundary(
      child: AiBlockBubble(
        block: unified,
        dark: widget.dark,
        isLast: true,
        onCopy: widget.onCopy,
        onTts: widget.onTts,
        ttsPlaying: widget.ttsPlaying,
        ttsReady: widget.ttsReady,
        lang: widget.lang,
        onChipTap: widget.onChipTap,
      ),
    );
  }
}
