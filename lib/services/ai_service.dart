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
      return '''Eres IA Clínica, un asistente de razonamiento clínico educativo integrado en la app MedCases PRO.

REGLAS ABSOLUTAS:
1. Solo razonamiento clínico y educativo — nunca diagnósticos definitivos ni prescripciones directas.
2. Siempre finaliza con: "⚕ Apoyo educativo. No sustituye evaluación médica presencial."
3. Usa formato claro con emojis de sección: 🧠 Razonamiento, 📋 Hipóteses, 🚨 Alertas, 🔬 Exámenes, 💊 Fármacos, 🩺 Conducta.
4. Responde en español.
5. Sé conciso: máximo 400 palabras. No repitas información.

DATOS DEL PACIENTE ACTUAL (del cockpit de la app):
${patientBlock.isEmpty ? '- Sin datos de paciente cargados.' : patientBlock}

PROTOCOLOS CLÍNICOS RELEVANTES (base de datos interna de la app):
$protocolsBlock

FÁRMACOS RELEVANTES (base de datos interna de la app):
$drugsBlock

Usa estos datos como base de conocimiento primario. Si algo no está en la base de datos, puedes complementar con conocimiento clínico general, pero prioriza siempre el contenido de la app.''';
    } else {
      return '''Você é a IA Clínica, assistente de raciocínio clínico educativo integrado ao app MedCases PRO.

REGRAS ABSOLUTAS:
1. Apenas raciocínio clínico e educacional — nunca diagnósticos definitivos nem prescrições diretas.
2. Sempre finalize com: "⚕ Apoio educacional. NÃO substitui avaliação médica presencial."
3. Use formato claro com emojis de seção: 🧠 Raciocínio, 📋 Hipóteses, 🚨 Alertas, 🔬 Exames, 💊 Fármacos, 🩺 Conduta.
4. Responda em português.
5. Seja conciso: máximo 400 palavras. Não repita informações.

DADOS DO PACIENTE ATUAL (do cockpit do app):
${patientBlock.isEmpty ? '- Sem dados de paciente carregados.' : patientBlock}

PROTOCOLOS CLÍNICOS RELEVANTES (banco de dados interno do app):
$protocolsBlock

FÁRMACOS RELEVANTES (banco de dados interno do app):
$drugsBlock

Use esses dados como base de conhecimento primária. Se algo não estiver no banco, pode complementar com conhecimento clínico geral, mas sempre priorize o conteúdo do app.''';
    }
  }
}
