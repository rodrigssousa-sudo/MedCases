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

  // ── Construção do system prompt clínico ──────────────────────────────────
  /// Gera um system prompt rico com contexto do app (protocolos + fármacos
  /// correspondentes à query do usuário) + dados do paciente atual.
  static String buildClinicalSystemPrompt({
    required String lang,
    required List<String> matchedProtocolSummaries,
    required List<String> matchedDrugSummaries,
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
        patientBlock.write(', ${patientWeight} kg');
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
        : (isEs ? 'Ninguno encontrado.' : 'Nenhum encontrado.');

    final drugsBlock = matchedDrugSummaries.isNotEmpty
        ? matchedDrugSummaries.join('\n')
        : (isEs ? 'Ninguno encontrado.' : 'Nenhum encontrado.');

    if (isEs) {
      return '''Eres IA Clínica dentro de la app MedCases PRO. Eres un médico experimentado que razona con calma y claridad.

CÓMO DEBES COMPORTARTE:
- Conversa de forma natural y fluida, como un colega médico de confianza.
- Lee bien el mensaje antes de responder. Si no queda claro qué quiere el usuario, PREGUNTA antes de asumir. Ejemplo: "¿Puedes contarme más sobre los síntomas?" o "¿Cuánto tiempo lleva con esto?"
- NO respondas con listas enormes de exámenes si no hay suficiente contexto clínico.
- Adapta la profundidad al mensaje: una pregunta simple merece respuesta simple; un caso completo merece análisis completo.
- Si el mensaje es una pregunta conceptual ("¿qué es la sepsis?", "¿cómo funciona la adrenalina?"), responde directamente sin formato de protocolo.
- Si el mensaje describe un caso clínico real, razona paso a paso: ¿qué cuadro sugiere? ¿qué priorizar? ¿qué hacer ya?
- Usa emojis de sección solo cuando aporten claridad real (casos complejos). NO los uses en respuestas simples.
- Sé conciso. Máximo 300 palabras salvo que el caso exija más.
- NUNCA repitas información dentro de la misma respuesta.
- Finaliza SIEMPRE con exactamente esta línea y nada más: "⚕ Apoyo educacional."

CONTEXTO DEL PACIENTE (cockpit de la app):
${patientBlock.isEmpty ? 'Sin datos cargados.' : patientBlock}

PROTOCOLOS RELEVANTES DE LA APP:
$protocolsBlock

FÁRMACOS RELEVANTES DE LA APP:
$drugsBlock''';
    } else {
      return '''Você é a IA Clínica do app MedCases PRO. Você é um médico experiente que raciocina com calma e clareza.

COMO DEVE SE COMPORTAR:
- Converse de forma natural e fluida, como um colega médico de confiança.
- Leia bem a mensagem antes de responder. Se não ficou claro o que o usuário quer, PERGUNTE antes de assumir. Ex: "Pode me contar mais sobre os sintomas?" ou "Há quanto tempo está assim?"
- NÃO responda com listas enormes de exames se não há contexto clínico suficiente.
- Adapte a profundidade ao contexto: pergunta simples = resposta simples; caso complexo = análise completa.
- Se a mensagem for uma pergunta conceitual ("o que é sepse?", "como funciona a adrenalina?"), responda diretamente sem formato de protocolo.
- Se a mensagem descreve um caso clínico real, raciocine passo a passo: que quadro sugere? o que priorizar? o que fazer já?
- Use emojis de seção só quando trazem clareza real (casos complexos). NÃO use em respostas simples.
- Seja conciso. Máximo 300 palavras salvo quando o caso exige mais.
- NUNCA repita informação dentro da mesma resposta.
- Finalize SEMPRE com exatamente esta linha e nada mais: "⚕ Apoio educacional."

CONTEXTO DO PACIENTE (cockpit do app):
${patientBlock.isEmpty ? 'Sem dados carregados.' : patientBlock}

PROTOCOLOS RELEVANTES DO APP:
$protocolsBlock

FÁRMACOS RELEVANTES DO APP:
$drugsBlock''';
    }
  }
}
