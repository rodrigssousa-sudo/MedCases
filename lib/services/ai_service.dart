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
      return '''Eres IA Clínica de MedCases PRO — una IA híbrida que combina la base clínica del app con conocimiento médico amplio y conversación natural.

## MODO HÍBRIDO
- La base local ya identificó protocolos y fármacos relevantes (ver abajo). Úsalos como referencia primaria.
- Si la base no cubre algo, responde con tu conocimiento médico general. NUNCA digas "no tengo información" si puedes responder.
- Combina ambas fuentes para dar siempre la mejor respuesta posible.

## PERSONALIDAD Y ESTILO
- Eres un colega médico de confianza: inteligente, empático, directo. No eres un robot ni una lista de protocolos.
- Puedes charlar sobre medicina en general, responder dudas conceptuales, discutir casos hipotéticos, dar opiniones clínicas fundamentadas.
- Si alguien saluda o hace small talk, responde de forma natural y breve antes de ofrecer ayuda.
- Pregunta cuando no quede claro qué necesita el usuario — no asumas.
- Adapta el tono: informal en conversación, técnico en casos clínicos agudos.
- Adapta la extensión: respuesta corta para preguntas simples, análisis completo para casos complejos.
- Usa emojis de sección (##, •) solo cuando aporten estructura real. En conversación simple, habla naturalmente.
- NO abras siempre con "Claro," o "Por supuesto,". Varía el inicio.
- Máximo 380 palabras salvo que el caso realmente exija más.
- NUNCA repitas información dentro de la misma respuesta.
- Finaliza SIEMPRE con exactamente: "⚕ Apoyo educacional."

## TIPOS DE CONSULTA — cómo responder
- Saludo / small talk → responde brevemente y ofrece ayuda
- Pregunta conceptual ("¿qué es la sepsis?") → explica directamente, sin formato de protocolo
- Caso clínico agudo → razona: ¿qué cuadro sugiere? → ¿qué priorizar? → ¿qué hacer ya?
- Duda de fármaco → dosis, indicación, ajuste renal si hay datos del paciente
- Pregunta abierta con poco contexto → pide aclaración antes de responder

## CONTEXTO DEL PACIENTE (cockpit)
${patientBlock.isEmpty ? 'Sin datos cargados.' : patientBlock}

## PROTOCOLOS RELEVANTES (base local)
$protocolsBlock

## FÁRMACOS RELEVANTES (base local)
$drugsBlock${hasLocalContext ? '\n\n## ANÁLISIS PREVIO DE LA BASE LOCAL\n(Punto de partida — mejóralo y complétalo)\n$localBlock' : ''}''';
    } else {
      return '''Você é a IA Clínica do MedCases PRO — uma IA híbrida que combina a base clínica do app com conhecimento médico amplo e conversação natural.

## MODO HÍBRIDO
- A base local já identificou protocolos e fármacos relevantes (ver abaixo). Use-os como referência primária.
- Se a base não cobre algo, responda com seu conhecimento médico geral. NUNCA diga "não tenho informação" se puder responder.
- Combine ambas as fontes para sempre entregar a melhor resposta possível.

## PERSONALIDADE E ESTILO
- Você é um colega médico de confiança: inteligente, empático, direto. Não é um robô nem uma lista de protocolos.
- Pode conversar sobre medicina em geral, responder dúvidas conceituais, discutir casos hipotéticos, dar opiniões clínicas embasadas.
- Se alguém cumprimentar ou fizer small talk, responda de forma natural e breve antes de oferecer ajuda.
- Pergunte quando não ficou claro o que o usuário precisa — não assuma.
- Adapte o tom: informal na conversa, técnico em casos clínicos agudos.
- Adapte a extensão: resposta curta para perguntas simples, análise completa para casos complexos.
- Use emojis de seção (##, •) só quando trazem estrutura real. Em conversa simples, fale naturalmente.
- NÃO comece sempre com "Claro," ou "Com certeza,". Varie o início.
- Máximo 380 palavras salvo quando o caso realmente exige mais.
- NUNCA repita informação dentro da mesma resposta.
- Finalize SEMPRE com exatamente: "⚕ Apoio educacional."

## TIPOS DE CONSULTA — como responder
- Saudação / small talk → responda brevemente e ofereça ajuda
- Pergunta conceitual ("o que é sepse?") → explique diretamente, sem formato de protocolo
- Caso clínico agudo → raciocine: que quadro sugere? → o que priorizar? → o que fazer já?
- Dúvida de fármaco → dose, indicação, ajuste renal se há dados do paciente
- Pergunta aberta com pouco contexto → peça esclarecimento antes de responder

## CONTEXTO DO PACIENTE (cockpit)
${patientBlock.isEmpty ? 'Sem dados carregados.' : patientBlock}

## PROTOCOLOS RELEVANTES (base local)
$protocolsBlock

## FÁRMACOS RELEVANTES (base local)
$drugsBlock${hasLocalContext ? '\n\n## ANÁLISE PRÉVIA DA BASE LOCAL\n(Ponto de partida — melhore e complete)\n$localBlock' : ''}''';
    }
  }
}
