// soap_ai_processor.dart
//
// Processa transcrição bruta via Gemini e estrutura nos campos SOAP do prontuário.
// Também executa OCR de exames (imagem base64 → texto estruturado).
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'gemini_service.dart';
import 'clinical_recorder_service.dart';

class SoapAiProcessor {

  // BUILD 334: gemini-2.5-flash-lite → gemini-2.5-flash (modelo canônico).
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  // ─────────────────────────────────────────────────────────────────────────
  // structure() — converte transcrição bruta em SoapData
  // ─────────────────────────────────────────────────────────────────────────
  static Future<SoapData> structure(String rawTranscript, {String lang = 'pt'}) async {
    if (rawTranscript.trim().isEmpty) {
      return SoapData(rawTranscript: rawTranscript);
    }

    final langInstr = lang == 'es'
        ? 'Responde SEMPRE em Español.'
        : 'Responde SEMPRE em Português do Brasil.';

    const systemPrompt = '''
Você é um assistente médico de alto desempenho especializado em prontuário eletrônico.
Sua tarefa é analisar uma transcrição de consulta médica (médico + paciente) e extrair,
organizar e estruturar as informações nos campos SOAP do prontuário.

REGRAS ESTRITAS:
1. Retorne APENAS um objeto JSON válido, sem markdown, sem comentários, sem texto extra.
2. Preserve terminologia médica exata (nomes de fármacos, dosagens, CIDs, siglas clínicas).
3. Se um campo não tiver informação na transcrição, retorne string vazia "".
4. Não invente dados que não estejam na transcrição.
5. O campo medications deve incluir nome + dose + via + frequência quando disponível.
6. O campo exams deve listar exames PEDIDOS e/ou RESULTADOS presentes na transcrição.

SCHEMA JSON obrigatório:
{
  "subjective": "Queixa principal + HDA + história do paciente (relato do próprio paciente)",
  "objective": "Sinais vitais + achados do exame físico (dados objetivos mensuráveis)",
  "assessment": "Hipótese diagnóstica + diagnóstico diferencial + impressão clínica",
  "plan": "Condutas + plano terapêutico + critérios de alta + seguimento",
  "medications": "Medicações em uso + prescrições novas (nome, dose, via, frequência)",
  "exams": "Exames laboratoriais e de imagem pedidos + resultados mencionados"
}
''';

    final userMessage = '$langInstr\n\nTRANSCRIÇÃO:\n$rawTranscript';

    try {
      final result = await GeminiService.chat(
        userMessage: userMessage,
        systemPrompt: systemPrompt,
        maxTokens: 3000,
        useGrounding: false,
      );

      if (result.isError) {
        debugPrint('[SoapAI] Erro Gemini: ${result.text}');
        return SoapData(rawTranscript: rawTranscript, subjective: rawTranscript);
      }

      // Extrai JSON da resposta (pode vir com ```json ... ```)
      String jsonStr = result.text.trim();
      final jsonStart = jsonStr.indexOf('{');
      final jsonEnd   = jsonStr.lastIndexOf('}');
      if (jsonStart >= 0 && jsonEnd > jsonStart) {
        jsonStr = jsonStr.substring(jsonStart, jsonEnd + 1);
      }

      final Map<String, dynamic> data = jsonDecode(jsonStr) as Map<String, dynamic>;

      return SoapData(
        subjective:    (data['subjective']   ?? '').toString().trim(),
        objective:     (data['objective']    ?? '').toString().trim(),
        assessment:    (data['assessment']   ?? '').toString().trim(),
        plan:          (data['plan']         ?? '').toString().trim(),
        medications:   (data['medications']  ?? '').toString().trim(),
        exams:         (data['exams']        ?? '').toString().trim(),
        rawTranscript: rawTranscript,
      );
    } catch (e) {
      debugPrint('[SoapAI] Parse error: $e');
      // Fallback: coloca tudo no campo subjetivo
      return SoapData(
        subjective:    rawTranscript,
        rawTranscript: rawTranscript,
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ocrExam() — OCR de imagem de exame laboratorial/de imagem
  // Recebe bytes da imagem e retorna texto estruturado
  // ─────────────────────────────────────────────────────────────────────────
  static Future<String> ocrExam(Uint8List imageBytes, {String lang = 'pt'}) async {
    final apiKey = GeminiService.apiKeyForLab;
    if (apiKey.isEmpty) {
      return 'IA não conectada. Configure a chave Gemini nas configurações.';
    }

    final base64Image = base64Encode(imageBytes);
    final mimeType = _detectMime(imageBytes);

    final langInstr = lang == 'es'
        ? 'Responde SEMPRE em Español.'
        : 'Responde SEMPRE em Português do Brasil.';

    const systemInstruction = '''
Você é um especialista em interpretação de exames médicos com visão computacional de alta precisão.
Realize OCR do documento médico e estruture todos os resultados de forma limpa e organizada.

REGRAS:
1. Extraia TODOS os valores, referências e unidades encontrados.
2. Formato: "Nome do exame: valor [referência] unidade".
3. Marque valores alterados (fora da referência) com ⚠️.
4. Se for laudo de imagem, transcreva o texto do laudo com fidelidade.
5. Não invente dados; se ilegível, indique "(ilegível)".
6. Retorne apenas o texto estruturado limpo.
''';

    final payload = {
      'system_instruction': {
        'parts': [{'text': systemInstruction}]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': '$langInstr\nAnalise este exame médico e extraia todos os resultados estruturados:'},
            {
              'inline_data': {
                'mime_type': mimeType,
                'data': base64Image,
              }
            }
          ]
        }
      ],
      'generationConfig': {
        'maxOutputTokens': 2000,
        'temperature': 0.1,
      },
    };

    try {
      final response = await http.post(
        Uri.parse('$_endpoint?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final parts = candidates[0]['content']?['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            return (parts[0]['text'] ?? '').toString().trim();
          }
        }
        return 'Não foi possível extrair texto do exame.';
      } else {
        debugPrint('[OcrExam] HTTP ${response.statusCode}: ${response.body}');
        return 'Erro ao processar exame (${response.statusCode}). Tente novamente.';
      }
    } catch (e) {
      debugPrint('[OcrExam] Exceção: $e');
      return 'Erro de conexão ao processar exame.';
    }
  }

  // Detecta MIME type pelos magic bytes
  static String _detectMime(Uint8List bytes) {
    if (bytes.length > 3 &&
        bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length > 3 &&
        bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E) {
      return 'image/png';
    }
    if (bytes.length > 3 &&
        bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44) {
      return 'application/pdf';
    }
    return 'image/jpeg';
  }
}
