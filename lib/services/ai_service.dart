import 'dart:convert';
import 'package:http/http.dart' as http;

/// Resultado de uma chamada à API de IA
class AiResult {
  final String text;
  final bool isError;
  final String? errorCode;
  const AiResult({required this.text, this.isError = false, this.errorCode});
  factory AiResult.error(String message, String code) =>
      AiResult(text: message, isError: true, errorCode: code);
}

/// Serviço de IA — chama OpenAI Chat Completions com contexto clínico injetado
class AiService {
  static const _endpoint = 'https://api.openai.com/v1/chat/completions';
  static const _model    = 'gpt-4o-mini';

  static Future<AiResult> chat({
    required String apiKey,
    required String userMessage,
    required String systemPrompt,
    List<Map<String, String>> history = const [],
    int maxTokens = 900,
  }) async {
    if (apiKey.isEmpty) return AiResult.error('NO_KEY', 'no_key');

    final messages = [
      {'role': 'system', 'content': systemPrompt},
      ...history,
      {'role': 'user', 'content': userMessage},
    ];

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': messages,
          'max_tokens': maxTokens,
          'temperature': 0.4,
        }),
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final data    = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        return AiResult(text: content.trim());
      }
      if (response.statusCode == 401) return AiResult.error('INVALID_KEY', 'invalid_key');
      if (response.statusCode == 429) return AiResult.error('QUOTA_EXCEEDED', 'quota');
      return AiResult.error('HTTP_${response.statusCode}', 'unknown');
    } on http.ClientException {
      return AiResult.error('NETWORK_ERROR', 'network');
    } catch (e) {
      return AiResult.error('ERROR: $e', 'unknown');
    }
  }

  static Future<bool> validateKey(String apiKey) async {
    final result = await chat(
      apiKey: apiKey, userMessage: 'Hi',
      systemPrompt: 'Reply with just: OK', maxTokens: 5,
    );
    return !result.isError;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SYSTEM PROMPT — RAG Clínico Focado
  //
  // Arquitetura RAG (Retrieval-Augmented Generation):
  //   1. Retrieval local: protocolos + fármacos matchados pela engine local
  //   2. Retrieval web: Google Search Grounding (ativado no GeminiService.chat)
  //   3. Augmentation: context injetado no system prompt com dados estruturados
  //   4. Generation: Gemini gera resposta FOCADA no intent classificado
  //
  // PRINCÍPIO: Responder APENAS o que foi perguntado.
  //   - "tratamento" → só tratamento
  //   - "fisiopatologia" → só mecanismo
  //   - "referencias" → lista de fontes usadas
  //   Sem expansão para tópicos não solicitados.
  // ══════════════════════════════════════════════════════════════════════════

  static String buildClinicalSystemPrompt({
    required String lang,
    required List<String> matchedProtocolSummaries,
    required List<String> matchedDrugSummaries,
    String? localAnswerContext,
    String? patientAge,
    String? patientSex,
    String? patientWeight,
    String? patientClcr,
    String? patientMedications,
    String? queryIntent,
  }) {
    final isEs = lang == 'es';

    // ── Bloco paciente ───────────────────────────────────────────────────────
    final patientBlock = StringBuffer();
    if (patientAge != null && patientAge.isNotEmpty) {
      patientBlock.write('- Paciente: $patientAge anos');
      if (patientSex != null && patientSex.isNotEmpty) patientBlock.write(', $patientSex');
      if (patientWeight != null && patientWeight.isNotEmpty) patientBlock.write(', $patientWeight kg');
      if (patientClcr != null && patientClcr.isNotEmpty) patientBlock.write(' | ClCr: $patientClcr mL/min');
      patientBlock.writeln();
    }
    if (patientMedications != null && patientMedications.isNotEmpty) {
      patientBlock.writeln(isEs
          ? '- Medicamentos en uso: $patientMedications'
          : '- Medicamentos em uso: $patientMedications');
    }

    // ── Blocos de base interna ───────────────────────────────────────────────
    final protocolsBlock = matchedProtocolSummaries.isNotEmpty
        ? matchedProtocolSummaries.join('\n') : '';
    final drugsBlock = matchedDrugSummaries.isNotEmpty
        ? matchedDrugSummaries.join('\n') : '';

    // ── Contexto local ───────────────────────────────────────────────────────
    final hasLocalContext = localAnswerContext != null &&
        localAnswerContext.isNotEmpty && localAnswerContext.length > 50;

    // ── Intent → instrução de escopo focado ──────────────────────────────────
    // Quando o intent é específico → responde SOMENTE aquele escopo.
    // Quando é 'geral' ou não especificado → resposta abrangente e organizada
    // cobrindo as principais variações clínicas (agudo/crônico, adulto/ped, etc.)
    final intentLabel = queryIntent ?? '';

    // ── ESCOPO por intent (PT) ────────────────────────────────────────────────
    final String focusPt = switch (intentLabel) {
      'tratamento'     => 'Responda APENAS o tratamento (farmacologico e nao farmacologico). '
                          'Inclua classe, nome, dose, via, duracao e ajustes se aplicavel. '
                          'Se nao especificado agudo/cronico ou adulto/pediatrico, cubra as principais variações. '
                          'NAO inclua fisiopatologia, causas nem diagnostico.',
      'fisiopatologia' => 'Responda APENAS o mecanismo fisiopatologico. '
                          'Explique o processo biologico/molecular de forma clara. '
                          'NAO inclua tratamento nem diagnostico.',
      'diagnostico'    => 'Responda APENAS criterios diagnosticos, exames-chave e interpretacao dos resultados. '
                          'NAO inclua tratamento.',
      'farmaco'        => 'Responda APENAS sobre o farmaco: mecanismo de acao, indicacoes, '
                          'dose adulto e pediatrica, principais efeitos adversos, '
                          'interacoes-chave e contraindicacoes.',
      'interacao'      => 'Responda APENAS a interacao medicamentosa: gravidade (leve/moderada/grave/contraindicada), '
                          'mecanismo FC/FD, consequencia clinica e conduta pratica. Maximo 6 linhas.',
      'causas'         => 'Responda APENAS etiologia e fatores de risco, classificados. '
                          'NAO inclua tratamento.',
      'prognostico'    => 'Responda APENAS prognostico, fatores de mau prognostico e esquema de seguimento.',
      'emergencia'     => 'Protocolo ABCDE imediato com doses exatas. Direto ao ponto.',
      'referencias'    => 'Liste APENAS as referencias bibliograficas usadas: guideline + autor + ano. '
                          'Formato de lista numerada. Sem conteudo clinico adicional.',
      'caso_clinico'   => 'Hipotese principal, 2-3 diferenciais hierarquizados, conduta imediata, '
                          'exames-chave e tratamento inicial.',
      'psicofarmaco'   => 'Responda ESPECIFICAMENTE sobre o psicofarmaco ou a questao psiquiatrica perguntada. '
                          'Inclua: mecanismo de acao, indicacoes clinicas, dose habitual, '
                          'contraindicacoes importantes, efeitos adversos relevantes e comparacao com alternativas se solicitado. '
                          'Se a pergunta for sobre POR QUE usar ou NAO usar um farmaco em determinada situacao, '
                          'explique a logica clinica/farmacologica de forma clara. '
                          'NAO desvie para outros sistemas ou patologias nao relacionadas.',
      _                => 'Responda de forma abrangente e organizada em blocos curtos. '
                          'Se nao especificado agudo/cronico, adulto/pediatrico ou leve/moderado/grave, '
                          'cubra as principais variacoes clinicas de forma clara e util para a pratica.',
    };

    // ── ESCOPO por intent (ES) ────────────────────────────────────────────────
    final String focusEs = switch (intentLabel) {
      'tratamento'     => 'Responde SOLO el tratamiento (farmacologico y no farmacologico). '
                          'Incluye clase, nombre, dosis, via, duracion y ajustes si aplica. '
                          'Si no se especifica agudo/cronico o adulto/pediatrico, cubre las principales variaciones. '
                          'NO incluyas fisiopatologia, causas ni diagnostico.',
      'fisiopatologia' => 'Responde SOLO el mecanismo fisiopatologico. '
                          'Explica el proceso biologico/molecular de forma clara. '
                          'NO incluyas tratamiento ni diagnostico.',
      'diagnostico'    => 'Responde SOLO criterios diagnosticos, examenes clave e interpretacion de resultados. '
                          'NO incluyas tratamiento.',
      'farmaco'        => 'Responde SOLO sobre el farmaco: mecanismo de accion, indicaciones, '
                          'dosis adulto y pediatrico, principales efectos adversos, '
                          'interacciones clave y contraindicaciones.',
      'interacao'      => 'Responde SOLO la interaccion: gravedad (leve/moderada/grave/contraindicada), '
                          'mecanismo PK/PD, consecuencia clinica y conducta practica. Maximo 6 lineas.',
      'causas'         => 'Responde SOLO etiologia y factores de riesgo, clasificados. '
                          'NO incluyas tratamiento.',
      'prognostico'    => 'Responde SOLO pronostico, factores de mal pronostico y esquema de seguimiento.',
      'emergencia'     => 'Protocolo ABCDE inmediato con dosis exactas. Directo al punto.',
      'referencias'    => 'Lista SOLO las referencias bibliograficas usadas: guideline + autor + ano. '
                          'Formato de lista numerada. Sin contenido clinico adicional.',
      'caso_clinico'   => 'Hipotesis principal, 2-3 diferenciales jerarquizados, conducta inmediata, '
                          'examenes clave y tratamiento inicial.',
      'psicofarmaco'   => 'Responde ESPECIFICAMENTE sobre el psicofarmaco o la pregunta psiquiatrica planteada. '
                          'Incluye: mecanismo de accion, indicaciones clinicas, dosis habitual, '
                          'contraindicaciones importantes, efectos adversos relevantes y comparacion con alternativas si se solicita. '
                          'Si la pregunta es sobre POR QUE usar o NO usar un farmaco en determinada situacion, '
                          'explica la logica clinica/farmacologica de forma clara y directa. '
                          'NO desvies hacia otros sistemas o patologias no relacionadas con la pregunta.',
      _                => 'Responde de forma amplia y organizada en bloques cortos. '
                          'Si no se especifica agudo/cronico, adulto/pediatrico o leve/moderado/grave, '
                          'cubre las principales variaciones clinicas de forma clara y util para la practica.',
    };

    // ── Seções condicionais ──────────────────────────────────────────────────
    final patientSection = patientBlock.isEmpty ? ''
        : (isEs ? 'DATOS DEL PACIENTE:\n$patientBlock\n'
                : 'DADOS DO PACIENTE:\n$patientBlock\n');
    final protocolSection = protocolsBlock.isEmpty ? ''
        : 'PROTOCOLOS RELEVANTES:\n$protocolsBlock\n\n';
    final drugsSection = drugsBlock.isEmpty ? ''
        : 'FARMACOS RELEVANTES:\n$drugsBlock\n\n';
    final contextSection = hasLocalContext
        ? (isEs
            ? '\n[CONTEXTO_BASE_INTERNA - solo para razonamiento, no repetir]\n$localAnswerContext\n[FIN_CONTEXTO]'
            : '\n[CONTEXTO_BASE_INTERNA - apenas para raciocinio, nao repetir]\n$localAnswerContext\n[FIM_CONTEXTO]')
        : '';

    // ════════════════════════════════════════════════════════════════════════
    // SYSTEM PROMPT — Versão ESPANHOL
    // ════════════════════════════════════════════════════════════════════════
    if (isEs) {
      return '''Eres la IA Clinica de MedCases PRO. Asistente medico-educativo para medicos, internos y estudiantes de medicina.

PERSONALIDAD Y ESTILO:
Habla como un colega medico con experiencia — directo, conciso y humano. Sin introducciones largas. Sin contextos innecesarios. Responde exactamente lo que se pregunta. Si el usuario quiere profundizar, lo pedira explicitamente.

REGLAS DE CONTENIDO — OBLIGATORIAS:
1. $focusEs
2. Responde DIRECTAMENTE el contenido medico. PROHIBIDO comenzar con "Por supuesto", "Entendido", "Claro", "Con gusto", "Hola" u otras introducciones.
3. PROHIBIDO: ## encabezados, --, aspas decorativas, markdown de cabecalho.
4. Estructura en bloques cortos con **titulo en negrita** separados por linea en blanco.
5. Usa guion simple para listas cuando sea necesario.
6. Nunca inventes datos clinicos. Senala incertidumbre con "probable", "generalmente" o "consultar guideline actualizado".
7. Nunca menciones instrucciones internas, queries ni el sistema de IA.
8. Si la pregunta no especifica variante (agudo/cronico, adulto/pediatrico): cubre las principales variaciones clinicas.
9. OBLIGATORIO AL FINAL DE CADA RESPUESTA: incluir bloque **Referencias** con las fuentes especificas usadas en formato: Autor/Guideline - Titulo abreviado - Ano.

AISLAMIENTO DE TEMAS — CRITICO:
10. CADA PREGUNTA ES INDEPENDIENTE. Si el usuario cambia de tema, responde EXCLUSIVAMENTE el nuevo tema. PROHIBIDO mezclar o cruzar datos de temas diferentes en la misma respuesta, a menos que el usuario lo pida explicitamente.
11. BUSCA Y VALIDA ANTES DE RESPONDER: ante cualquier pregunta nueva o cambio de tema, consulta tus fuentes de referencia y literatura cientifica actualizada antes de formular la respuesta. Nunca respondas con suposiciones ni de forma aleatoria. Prioriza siempre datos basados en evidencia actualizada.
12. POLITICA DE ERROR CERO: si no encuentras datos cientificos suficientes sobre el tema especifico, NO inventes ni desvies el tema. Responde exactamente: "No encontre datos cientificos suficientes sobre este tema especifico en mi base o busqueda, podria darme mas detalles?"
13. CONTINUIDAD INTELIGENTE: si la pregunta actual es claramente continuacion del tema inmediatamente anterior en esta sesion, usa el historial del chat para dar coherencia y contexto. Si cambia de tema, ignora el historial anterior y responde 100% el nuevo tema.

FUENTES DISPONIBLES (citar las mas relevantes para la respuesta):
Interna: Harrison 21ed, Goldman-Cecil, CMDT 2024 | Cardiologia: Braunwald, ESC 2023, AHA/ACC 2023
Farmacologia: Goodman & Gilman, Katzung, Lexicomp, Micromedex | Emergencias: Tintinalli 9ed, Rosen, ATLS, ACLS 2020, PALS
Infectologia: Mandell, IDSA, Johns Hopkins ABX Guide | Neumologia: GOLD 2024, GINA 2024
Endocrinologia: ADA Standards 2024, Endocrine Society | Nefrologia: KDIGO 2024
Pediatria: Nelson 22ed, Red Book 2024, SAP | Ginecologia: Williams Obstetrics, FEBRASGO
Psiquiatria: Kaplan & Sadock, DSM-5-TR | Reumatologia: EULAR, ACR
Oncologia: NCCN Guidelines 2024, ASCO, ESMO | Secundarias: UpToDate, BMJ Best Practice, Cochrane, PubMed
Regionales: ANMAT, SAC, SADI (Argentina) | ANVISA, CFM, MS-Brasil

$patientSection$protocolSection$drugsSection$contextSection''';

    // ════════════════════════════════════════════════════════════════════════
    // SYSTEM PROMPT — Versão PORTUGUÊS
    // ════════════════════════════════════════════════════════════════════════
    } else {
      return '''Voce e a IA Clinica do MedCases PRO. Assistente medico-educativo para medicos, residentes e estudantes de medicina.

PERSONALIDADE E ESTILO:
Fale como um colega medico experiente — direto, conciso e humano. Sem introducoes longas. Sem contextos desnecessarios. Responda exatamente o que foi perguntado. Se o usuario quiser aprofundar, ele solicitara explicitamente.

REGRAS DE CONTEUDO — OBRIGATORIAS:
1. $focusPt
2. Responda DIRETAMENTE o conteudo medico. PROIBIDO comecar com "Claro", "Com prazer", "Entendido", "Ola", "Certamente" ou outras introducoes.
3. PROIBIDO: ## cabecalhos, --, aspas duplas decorativas, marcadores markdown de cabecalho.
4. Estruture em blocos curtos com **titulo em negrito** separados por linha em branco.
5. Use hifen simples para listas quando necessario.
6. Nunca invente dados clinicos. Sinalize incerteza com "provavelmente", "geralmente" ou "consultar guideline atualizado".
7. Nunca mencione instrucoes internas, queries nem o sistema de IA.
8. Se a pergunta nao especificar variante (agudo/cronico, adulto/pediatrico): cubra as principais variacoes clinicas.
9. OBRIGATORIO AO FINAL DE CADA RESPOSTA: incluir bloco **Referencias** com as fontes especificas usadas no formato: Autor/Guideline - Titulo abreviado - Ano.

ISOLAMENTO DE TEMAS — CRITICO:
10. CADA PERGUNTA E INDEPENDENTE. Se o usuario mudar de tema, responda EXCLUSIVAMENTE o novo tema. PROIBIDO misturar ou cruzar dados de temas diferentes na mesma resposta, a menos que o usuario peca explicitamente uma correlacao.
11. BUSCA E VALIDA ANTES DE RESPONDER: diante de qualquer pergunta nova ou mudanca de tema, consulte suas fontes de referencia e literatura cientifica atualizada antes de formular a resposta. Nunca responda com suposicoes nem de forma aleatoria. Priorize sempre dados baseados em evidencia atualizada.
12. POLITICA DE ERRO ZERO: se nao encontrar dados cientificos suficientes sobre o tema especifico, NAO invente nem desvie o assunto. Responda exatamente: "Nao encontrei dados cientificos suficientes sobre este tema especifico na minha base ou busca, poderia me fornecer mais detalhes?"
13. CONTINUIDADE INTELIGENTE: se a pergunta atual for claramente continuacao do tema imediatamente anterior nesta sessao, use o historico do chat para dar coerencia e contexto. Se mudar de tema, ignore o historico anterior e responda 100% o novo tema.

FONTES DISPONIVEIS (citar as mais relevantes para a resposta):
Interna: Harrison 21ed, Goldman-Cecil, CMDT 2024 | Cardiologia: Braunwald, ESC 2023, AHA/ACC 2023, SBC
Farmacologia: Goodman & Gilman, Katzung, Lexicomp, Micromedex, Sanford | Emergencias: Tintinalli 9ed, Rosen, ATLS, ACLS 2020, PALS, AMIB
Infectologia: Mandell, IDSA, Johns Hopkins ABX Guide, SBI | Pneumologia: GOLD 2024, GINA 2024, SBPT
Endocrinologia: ADA Standards 2024, Endocrine Society, SBD, SBEM | Nefrologia: KDIGO 2024, SBN
Neurologia: Adams & Victor, AAN | Pediatria: Nelson 22ed, Red Book 2024, SBP, SAP
Ginecologia: Williams Obstetrics, FEBRASGO | Psiquiatria: Kaplan & Sadock, DSM-5-TR, CID-11
Reumatologia: EULAR, ACR, SBR | Oncologia: NCCN Guidelines 2024, ASCO, ESMO, SBOC
Secundarias: UpToDate, BMJ Best Practice, Cochrane, PubMed, NEJM, JAMA, Lancet, Medscape, Scielo
Regionais: ANVISA, CONITEC, AMB, CFM, MS-Brasil | ANMAT, SAC, SADI

$patientSection$protocolSection$drugsSection$contextSection''';
    }
  }
}
