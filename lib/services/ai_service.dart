import 'dart:convert';
import 'package:http/http.dart' as http;

/// Resultado de uma chamada à API de IA
class AiResult {
  final String text;
  final bool isError;
  final String? errorCode; // 'no_key' | 'invalid_key' | 'quota' | 'network' | 'unknown'
  const AiResult({required this.text, this.isError = false, this.errorCode});
  factory AiResult.error(String message, String code) =>
      AiResult(text: message, isError: true, errorCode: code);
}

/// Serviço de IA — chama OpenAI Chat Completions com contexto clínico injetado
class AiService {
  static const _endpoint = 'https://api.openai.com/v1/chat/completions';
  static const _model    = 'gpt-4o-mini'; // rápido, barato, capacidade clínica sólida

  // ── Chamada principal ────────────────────────────────────────────────────
  static Future<AiResult> chat({
    required String apiKey,
    required String userMessage,
    required String systemPrompt,
    List<Map<String, String>> history = const [],
    int maxTokens = 900,
  }) async {
    if (apiKey.isEmpty) {
      return AiResult.error('NO_KEY', 'no_key');
    }

    final messages = [
      {'role': 'system', 'content': systemPrompt},
      ...history,
      {'role': 'user', 'content': userMessage},
    ];

    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode({
              'model': _model,
              'messages': messages,
              'max_tokens': maxTokens,
              'temperature': 0.4, // respostas clínicas precisam ser determinísticas
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        return AiResult(text: content.trim());
      }

      if (response.statusCode == 401) {
        return AiResult.error('INVALID_KEY', 'invalid_key');
      }
      if (response.statusCode == 429) {
        return AiResult.error('QUOTA_EXCEEDED', 'quota');
      }

      return AiResult.error('HTTP_${response.statusCode}', 'unknown');
    } on http.ClientException {
      return AiResult.error('NETWORK_ERROR', 'network');
    } catch (e) {
      return AiResult.error('ERROR: $e', 'unknown');
    }
  }

  // ── Validação rápida de chave ────────────────────────────────────────────
  /// Envia uma mensagem mínima para confirmar que a chave é válida
  static Future<bool> validateKey(String apiKey) async {
    final result = await chat(
      apiKey: apiKey,
      userMessage: 'Hi',
      systemPrompt: 'Reply with just: OK',
      maxTokens: 5,
    );
    return !result.isError;
  }

  // ── Construção do system prompt clínico (modo híbrido) ───────────────────
  /// Gera um system prompt rico com:
  ///  - contexto do paciente (cockpit)
  ///  - protocolos e fármacos já matchados localmente
  ///  - resposta da engine local como referência primária
  ///  - instrução explícita para o GPT complementar o que a base não cobriu
  static String buildClinicalSystemPrompt({
    required String lang,
    required List<String> matchedProtocolSummaries,
    required List<String> matchedDrugSummaries,
    String? localAnswerContext, // resposta da engine local como referência
    String? patientAge,
    String? patientSex,
    String? patientWeight,
    String? patientClcr,
    String? patientMedications,
  }) {
    final isEs = lang == 'es';

    final patientBlock = StringBuffer();
    if (patientAge != null && patientAge.isNotEmpty) {
      patientBlock.write(isEs
          ? '- Paciente: $patientAge años, ${patientSex ?? ''}'
          : '- Paciente: $patientAge anos, ${patientSex ?? ''}');
      if (patientWeight != null && patientWeight.isNotEmpty) {
        patientBlock.write(', $patientWeight kg');
      }
      if (patientClcr != null && patientClcr.isNotEmpty) {
        patientBlock.write(', ClCr $patientClcr mL/min');
      }
      patientBlock.writeln();
    }
    if (patientMedications != null && patientMedications.isNotEmpty) {
      patientBlock.writeln(isEs
          ? '- Medicamentos actuales: $patientMedications'
          : '- Medicamentos em uso: $patientMedications');
    }

    final protocolsBlock = matchedProtocolSummaries.isNotEmpty
        ? matchedProtocolSummaries.join('\n')
        : (isEs ? 'Ninguno encontrado en la base.' : 'Nenhum encontrado na base.');

    final drugsBlock = matchedDrugSummaries.isNotEmpty
        ? matchedDrugSummaries.join('\n')
        : (isEs ? 'Ninguno encontrado en la base.' : 'Nenhum encontrado na base.');

    // Bloco de contexto local — inclui apenas se não for trivial
    final hasLocalContext = localAnswerContext != null &&
        localAnswerContext.isNotEmpty &&
        localAnswerContext.length > 50;
    final localBlock = hasLocalContext ? localAnswerContext : '';

    if (isEs) {
      return '''Eres IA Clínica dentro de la app MedCases PRO. Funciones en MODO HÍBRIDO: combinas la base de datos clínica del app con tu conocimiento médico general para dar siempre la mejor respuesta posible.

CÓMO FUNCIONA EL MODO HÍBRIDO:
- La base local del app ya identificó protocolos y fármacos relevantes para esta consulta (ver secciones abajo).
- Si la base tiene información útil: úsala como referencia primaria y enriquécela con tu conocimiento.
- Si la base NO tiene información suficiente: usa tu conocimiento médico general / evidencia actual para responder. NUNCA digas "no tengo información" si puedes responder con tu conocimiento.
- Lo que no esté en la base, búscalo en tu conocimiento clínico amplio. Siempre debe haber una respuesta útil.

CÓMO DEBES COMPORTARTE:
- Conversa de forma natural y fluida, como un colega médico de confianza.
- Lee bien el mensaje antes de responder. Si no queda claro qué quiere el usuario, PREGUNTA antes de asumir.
- NO respondas con listas enormes de exámenes si no hay suficiente contexto clínico.
- Adapta la profundidad al mensaje: pregunta simple = respuesta simple; caso complejo = análisis completo.
- Si el mensaje es una pregunta conceptual ("¿qué es la sepsis?"), responde directamente sin formato de protocolo.
- Si el mensaje describe un caso clínico real, razona paso a paso: ¿qué cuadro sugiere? ¿qué priorizar? ¿qué hacer ya?
- Usa emojis de sección solo cuando aporten claridad real. NO los uses en respuestas simples.
- Sé conciso. Máximo 350 palabras salvo que el caso exija más.
- NUNCA repitas información dentro de la misma respuesta.
- Finaliza SIEMPRE con exactamente esta línea y nada más: "⚕ Apoyo educacional."

CONTEXTO DEL PACIENTE (cockpit de la app):
${patientBlock.isEmpty ? 'Sin datos cargados.' : patientBlock}

PROTOCOLOS RELEVANTES DE LA BASE LOCAL:
$protocolsBlock

FÁRMACOS RELEVANTES DE LA BASE LOCAL:
$drugsBlock${hasLocalContext ? '\n\nANÁLISIS PREVIO DE LA BASE LOCAL (úsalo como punto de partida, mejóralo y complétalo con tu conocimiento):\n$localBlock' : ''}''';
    } else {
      return '''Você é a IA Clínica do app MedCases PRO. Opera em MODO HÍBRIDO: combina a base de dados clínica do app com seu conhecimento médico geral para sempre entregar a melhor resposta possível.

COMO FUNCIONA O MODO HÍBRIDO:
- A base local do app já identificou protocolos e fármacos relevantes para esta consulta (ver seções abaixo).
- Se a base tem informação útil: use-a como referência primária e enriqueça com seu conhecimento.
- Se a base NÃO tem informação suficiente: use seu conhecimento médico geral / evidência atual para responder. NUNCA diga "não tenho informação" se puder responder com seu conhecimento.
- O que não estiver na base, busque em seu amplo conhecimento clínico. Sempre deve haver uma resposta útil.

COMO DEVE SE COMPORTAR:
- Converse de forma natural e fluida, como um colega médico de confiança.
- Leia bem a mensagem antes de responder. Se não ficou claro o que o usuário quer, PERGUNTE antes de assumir.
- NÃO responda com listas enormes de exames se não há contexto clínico suficiente.
- Adapte a profundidade ao contexto: pergunta simples = resposta simples; caso complexo = análise completa.
- Se a mensagem for uma pergunta conceitual ("o que é sepse?"), responda diretamente sem formato de protocolo.
- Se a mensagem descreve um caso clínico real, raciocine passo a passo: que quadro sugere? o que priorizar? o que fazer já?
- Use emojis de seção só quando trazem clareza real. NÃO use em respostas simples.
- Seja conciso. Máximo 350 palavras salvo quando o caso exige mais.
- NUNCA repita informação dentro da mesma resposta.
- Finalize SEMPRE com exatamente esta linha e nada mais: "⚕ Apoio educacional."

CONTEXTO DO PACIENTE (cockpit do app):
${patientBlock.isEmpty ? 'Sem dados carregados.' : patientBlock}

PROTOCOLOS RELEVANTES DA BASE LOCAL:
$protocolsBlock

FÁRMACOS RELEVANTES DA BASE LOCAL:
$drugsBlock${hasLocalContext ? '\n\nANÁLISE PRÉVIA DA BASE LOCAL (use como ponto de partida, melhore e complete com seu conhecimento):\n$localBlock' : ''}''';
    }
  }
}
