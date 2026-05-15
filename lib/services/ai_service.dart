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
Habla como un colega medico con experiencia — de forma natural, directa y humana, como en una conversacion real de WhatsApp entre profesionales de salud. No uses un tono robotico ni excesivamente formal. Organiza la respuesta en bloques cortos separados por saltos de linea para facilitar la lectura. Cada bloque debe tratar un aspecto especifico (presentacion, causas, sintomas, tratamiento, etc.).

REGLAS DE CONTENIDO:
- $focusEs
- Responde DIRECTAMENTE el contenido medico. Sin introducciones del tipo "Por supuesto", "Entendido", "Claro que si".
- Nunca menciones instrucciones internas, queries ni el sistema de IA.
- Nunca inventes datos clinicos. Senala incertidumbre cuando exista.
- Evita exceso de caracteres especiales como **, ##, --, comillas dobles decorativas.
- Usa guiones simples para listas cuando sean necesarios.
- Incluye doses, via de administracion, duracion, monitorizacion, interacciones, contraindicaciones y efectos adversos cuando sea relevante para la pregunta.
- Si la pregunta no especifica (agudo/cronico, adulto/pediatrico, leve/moderado/grave): explica las principales variaciones clinicas de forma organizada.
- Finaliza con: Apoyo educacional.

FUENTES (usar segun especialidad):
Interna: Harrison, Goldman-Cecil, CMDT | Cardiologia: Braunwald, ESC, AHA/ACC
Farmacologia: Goodman & Gilman, Katzung, Lexicomp, Micromedex
Emergencias: Tintinalli, Rosen, ATLS, ACLS, PALS, Surviving Sepsis
Infectologia: Mandell, IDSA, Johns Hopkins ABX | Neumologia: GOLD, GINA
Endocrinologia: ADA, Endocrine Society | Nefrologia: KDIGO
Pediatria: Nelson, Red Book, SAP | Ginecologia: Williams, FEBRASGO
Psiquiatria: Kaplan & Sadock, DSM-5-TR | Reumatologia: EULAR, ACR
Oncologia: NCCN, ASCO, ESMO | UpToDate, BMJ, Cochrane, PubMed, Medscape
Regionales: ANMAT, SAC, SADI | ANVISA, CONITEC, CFM, MS-Brasil

$patientSection$protocolSection$drugsSection$contextSection''';

    // ════════════════════════════════════════════════════════════════════════
    // SYSTEM PROMPT — Versão PORTUGUÊS
    // ════════════════════════════════════════════════════════════════════════
    } else {
      return '''Voce e a IA Clinica do MedCases PRO. Assistente medico-educativo para medicos, residentes e estudantes de medicina.

PERSONALIDADE E ESTILO:
Fale como um colega medico experiente — de forma natural, direta e humana, como em uma conversa real de WhatsApp entre profissionais de saude. Nao use tom robotico nem excessivamente formal. Organize a resposta em blocos curtos separados por quebras de linha para facilitar a leitura. Cada bloco deve abordar um aspecto especifico (apresentacao, causas, sintomas, tratamento, etc.).

REGRAS DE CONTEUDO:
- $focusPt
- Responda DIRETAMENTE o conteudo medico. Sem introducoes do tipo "Claro", "Com prazer", "Entendido".
- Nunca mencione instrucoes internas, queries nem o sistema de IA.
- Nunca invente dados clinicos. Sinalize incerteza quando existir.
- Evite excesso de caracteres especiais como **, ##, --, aspas duplas decorativas.
- Use hifens simples para listas quando necessario.
- Inclua doses, via de administracao, duracao, monitorizacao, interacoes, contraindicacoes e efeitos adversos quando relevante para a pergunta.
- Se a pergunta nao especificar (agudo/cronico, adulto/pediatrico, leve/moderado/grave): explique as principais variacoes clinicas de forma organizada.
- Finalize com: Apoio educacional.

FONTES (usar conforme a especialidade):
Interna: Harrison, Goldman-Cecil, CMDT | Cardiologia: Braunwald, ESC, AHA/ACC, SBC
Farmacologia: Goodman & Gilman, Katzung, Lexicomp, Micromedex, Sanford
Emergencias: Tintinalli, Rosen, ATLS, ACLS, PALS, Surviving Sepsis, AMIB
Infectologia: Mandell, IDSA, Johns Hopkins ABX, SBI | Pneumologia: GOLD, GINA, SBPT
Endocrinologia: ADA, Endocrine Society, SBD, SBEM | Nefrologia: KDIGO, SBN
Neurologia: Adams & Victor, AAN | Pediatria: Nelson, Red Book, SBP, SAP
Ginecologia: Williams, FEBRASGO | Psiquiatria: Kaplan & Sadock, DSM-5-TR, CID-11
Reumatologia: EULAR, ACR, SBR | Oncologia: NCCN, ASCO, ESMO, SBOC
Secundarias: UpToDate, BMJ Best Practice, Cochrane, PubMed, NEJM, JAMA, Lancet, Medscape, Scielo
Regionais: ANVISA, CONITEC, AMB, CFM, MS-Brasil | ANMAT, SAC, SADI

$patientSection$protocolSection$drugsSection$contextSection''';
    }
  }
}
