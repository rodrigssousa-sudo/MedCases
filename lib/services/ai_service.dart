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
    int maxTokens = 1800,
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
  // SYSTEM PROMPT — RAG Clínico Avançado
  //
  // Arquitetura RAG (Retrieval-Augmented Generation):
  //   1. Retrieval local: protocolos + fármacos matchados pela engine local
  //   2. Retrieval web: Google Search Grounding (ativado no GeminiService.chat)
  //   3. Augmentation: context injetado no system prompt com dados estruturados
  //   4. Generation: Gemini gera resposta clínica com raciocínio explícito
  //
  // O modelo recebe:
  //   - Intent classificada (qual tipo de pergunta é)
  //   - Dados do paciente (cockpit)
  //   - Protocolos relevantes da base interna
  //   - Fármacos relevantes da base interna
  //   - Análise prévia da engine local (quando existir)
  //   - Instruções explícitas para usar Google Search quando precisar
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
    String? queryIntent, // classificação do tipo de pergunta
  }) {
    final isEs = lang == 'es';

    // ── Bloco paciente ───────────────────────────────────────────────────────
    final patientBlock = StringBuffer();
    if (patientAge != null && patientAge.isNotEmpty) {
      patientBlock.write(isEs
          ? '• Paciente: $patientAge años'
          : '• Paciente: $patientAge anos');
      if (patientSex != null && patientSex.isNotEmpty) {
        patientBlock.write(', $patientSex');
      }
      if (patientWeight != null && patientWeight.isNotEmpty) {
        patientBlock.write(', $patientWeight kg');
      }
      if (patientClcr != null && patientClcr.isNotEmpty) {
        patientBlock.write(' | ClCr: $patientClcr mL/min');
      }
      patientBlock.writeln();
    }
    if (patientMedications != null && patientMedications.isNotEmpty) {
      patientBlock.writeln(isEs
          ? '• Medicamentos en uso: $patientMedications'
          : '• Medicamentos em uso: $patientMedications');
    }

    // ── Blocos de base interna ───────────────────────────────────────────────
    final protocolsBlock = matchedProtocolSummaries.isNotEmpty
        ? matchedProtocolSummaries.join('\n')
        : (isEs ? '(sin coincidencias en esta consulta)' : '(sem coincidências nesta consulta)');

    final drugsBlock = matchedDrugSummaries.isNotEmpty
        ? matchedDrugSummaries.join('\n')
        : (isEs ? '(sin coincidencias en esta consulta)' : '(sem coincidências nesta consulta)');

    // ── Contexto local (análise prévia da engine) ────────────────────────────
    final hasLocalContext = localAnswerContext != null &&
        localAnswerContext.isNotEmpty &&
        localAnswerContext.length > 50;

    // ── Intent label ────────────────────────────────────────────────────────
    final intentLabel = queryIntent ?? '';

    if (isEs) {
      return '''Eres la IA Clinica de MedCases PRO. Asistente medico-educativo con acceso a base clinica interna y busqueda web.

REGLAS CRITICAS (nunca violar):
- Responde DIRECTAMENTE con contenido medico. Nunca repitas, copies ni menciones el contexto que recibes.
- Nunca uses frases como "consulta medica", "query del usuario", "instruccion para la IA", "topico identificado".
- Nunca empieces con ## ni con texto de instruccion. Empieza siempre con el contenido medico.
- Primero orienta clinicamente, despues pregunta solo si es estrictamente necesario.
- Tono natural como colega medico. Sin estructuras roboticas ni burocracia.
- Formato minimo: usa titulos solo para respuestas largas (>4 parrafos). Prosa directa para preguntas simples.
- Finaliza siempre con: Apoyo educacional.

FUENTES: Goodman & Gilman, Harrison, DiPiro, Braunwald, Mandell, Cecil, UpToDate, PubMed, NEJM, guias ESC/AHA/IDSA.

TIPOS DE CONSULTA:
- Enfermedad: fisiopatologia, diagnostico, tratamiento, red flags
- Farmaco: mecanismo, dosis, indicaciones, RAM, interacciones, ajuste renal
- Caso clinico: hipotesis principal, diferenciales, conducta inmediata, examenes
- Interaccion: gravedad, mecanismo, consecuencia, conducta

RAZONAMIENTO:
- Cuadro banal (gripe, faringitis, cefalea tensional): conducta practica directa
- Cuadro moderado (neumonia, celulitis): diagnostico + tratamiento + alarmas
- Emergencia (PCR, shock, IAM, AVC, sepsis): protocolo inmediato sin demora
- Siempre da orientacion clinica completa antes de sugerir consultar medico

${patientBlock.isEmpty ? '' : 'PACIENTE: $patientBlock\n'}
${protocolsBlock.contains('(sin coincidencias') ? '' : 'PROTOCOLOS RELEVANTES:\n$protocolsBlock\n'}
${drugsBlock.contains('(sin coincidencias') ? '' : 'FARMACOS RELEVANTES:\n$drugsBlock\n'}${hasLocalContext ? '\n[CONTEXTO_BASE_INTERNA - solo para razonamiento, no repetir]\n$localAnswerContext\n[FIN_CONTEXTO]' : ''}${intentLabel.isNotEmpty ? '\n[tipo: $intentLabel]' : ''}''';
    } else {
      return '''Voce e a IA Clinica do MedCases PRO. Assistente medico-educativo com acesso a base clinica interna e busca web.

REGRAS CRITICAS (nunca violar):
- Responda DIRETAMENTE com conteudo medico. Nunca repita, copie nem mencione o contexto que recebe.
- Nunca use frases como "consulta medica", "query do usuario", "instrucao para a IA", "topico identificado".
- Nunca comece com ## nem com texto de instrucao. Comece sempre com o conteudo medico.
- Primeiro oriente clinicamente, depois pergunte somente se estritamente necessario.
- Tom natural como colega medico. Sem estruturas roboticas nem burocracia.
- Formato minimo: use titulos apenas para respostas longas (>4 paragrafos). Prosa direta para perguntas simples.
- Finalize sempre com: Apoio educacional.

FONTES: Goodman & Gilman, Harrison, DiPiro, Braunwald, Mandell, Cecil, UpToDate, PubMed, NEJM, diretrizes ESC/AHA/IDSA/SBC.

TIPOS DE CONSULTA:
- Doenca: fisiopatologia, diagnostico, tratamento, red flags
- Farmaco: mecanismo, dose, indicacoes, RAM, interacoes, ajuste renal
- Caso clinico: hipotese principal, diferenciais, conduta imediata, exames
- Interacao: gravidade, mecanismo, consequencia, conduta

RACIOCINIO:
- Quadro banal (gripe, faringite, cefaleia tensional): conduta pratica direta
- Quadro moderado (pneumonia, celulite): diagnostico + tratamento + alarmas
- Emergencia (PCR, choque, IAM, AVC, sepse): protocolo imediato sem demora
- Sempre da orientacao clinica completa antes de sugerir consultar medico

${patientBlock.isEmpty ? '' : 'PACIENTE: $patientBlock\n'}
${protocolsBlock.contains('(sem coincidencias') ? '' : 'PROTOCOLOS RELEVANTES:\n$protocolsBlock\n'}
${drugsBlock.contains('(sem coincidencias') ? '' : 'FARMACOS RELEVANTES:\n$drugsBlock\n'}${hasLocalContext ? '\n[CONTEXTO_BASE_INTERNA - apenas para raciocinio, nao repetir]\n$localAnswerContext\n[FIM_CONTEXTO]' : ''}${intentLabel.isNotEmpty ? '\n[tipo: $intentLabel]' : ''}''';
    }
  }
}
