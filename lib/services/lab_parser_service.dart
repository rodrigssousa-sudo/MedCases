// ── lib/services/lab_parser_service.dart ─────────────────────────────────────
// Serviço de extração de parâmetros laboratoriais via Gemini 2.5 Flash.
//
// Design:
//   • Usa a mesma API Key estática já carregada pelo GeminiService — zero config extra.
//   • Suporta 3 modalidades de entrada: texto puro, imagem Base64, PDF (texto extraído).
//   • O prompt instrui o modelo a:
//       - retornar JSON estrito (array de objetos LabResult)
//       - usar examKey em inglês snake_case (integridade dos cálculos)
//       - traduzir examName para o idioma do usuário (PT ou ES)
//   • Pós-processamento: normalização de chaves, conversão de unidades,
//     substituição de vírgula por ponto, detecção de status critical.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'gemini_service.dart';
import '../models/lab_result_model.dart';
import 'lab_normalizer.dart';

class LabParserService {
  // Reutiliza o endpoint e a chave já gerenciados pelo GeminiService singleton.
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  // ── Entrada: texto puro (laudo digitado / colado / extraído de PDF) ─────

  /// Extrai parâmetros laboratoriais de um bloco de texto.
  static Future<List<LabResult>> parseText(
    String text, {
    required String locale,
  }) async {
    _assertApiKey();
    final body = _buildTextBody(text, locale);
    return _execute(body, locale);
  }

  // ── Entrada: imagem (JPEG/PNG/WEBP/GIF) ───────────────────────────────

  /// Extrai parâmetros laboratoriais de bytes de imagem (câmera ou galeria).
  /// [mimeType]: 'image/jpeg' | 'image/png' | 'image/webp'
  static Future<List<LabResult>> parseImage(
    Uint8List imageBytes, {
    required String locale,
    String mimeType = 'image/jpeg',
  }) async {
    _assertApiKey();
    final body = _buildImageBody(imageBytes, mimeType, locale);
    return _execute(body, locale);
  }

  // ── Entrada: PDF (bytes já lidos pelo file_picker) ─────────────────────

  /// Extrai texto do PDF via Gemini (inline base64 — limite ~20 MB).
  static Future<List<LabResult>> parsePdf(
    Uint8List pdfBytes, {
    required String locale,
  }) async {
    _assertApiKey();
    final body = _buildPdfBody(pdfBytes, locale);
    return _execute(body, locale);
  }

  // ── Execução central ───────────────────────────────────────────────────

  static Future<List<LabResult>> _execute(
    Map<String, dynamic> requestBody,
    String locale,
  ) async {
    final isEs = locale.toLowerCase() == 'es';

    try {
      final response = await http
          .post(
            Uri.parse('$_endpoint?key=${GeminiService.apiKeyForLab}'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final rawText = _extractText(data);

        if (rawText != null && rawText.isNotEmpty) {
          return _parseJsonArray(rawText, locale);
        }
      }

      // HTTP error → lança com mensagem bilíngue
      throw LabParseException(
        isEs
            ? 'El servidor devolvió un error (${response.statusCode}). '
                'Intente de nuevo o pegue el texto manualmente.'
            : 'O servidor retornou erro (${response.statusCode}). '
                'Tente novamente ou cole o texto do exame manualmente.',
      );
    } on LabParseException {
      rethrow;
    } catch (e) {
      throw LabParseException(
        isEs
            ? 'No fue posible extraer los datos de forma segura. '
                'Use buena iluminación o pegue el texto del examen.'
            : 'Não foi possível extrair os dados com segurança. '
                'Use boa iluminação ou cole o texto do exame.',
      );
    }
  }

  // ── Extração do texto da resposta Gemini ──────────────────────────────

  static String? _extractText(Map<String, dynamic> data) {
    try {
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return null;
      final parts = candidates[0]['content']?['parts'] as List?;
      if (parts == null || parts.isEmpty) return null;
      // Filtra apenas parts de texto puro (ignora thought, functionCall)
      return parts
          .where((p) {
            final part = p as Map<String, dynamic>;
            if (part['thought'] == true) return false;
            if (part.containsKey('functionCall')) return false;
            if (!part.containsKey('text')) return false;
            return true;
          })
          .map((p) => (p as Map<String, dynamic>)['text'] as String? ?? '')
          .join();
    } catch (_) {
      return null;
    }
  }

  // ── Parsing do JSON array retornado pelo Gemini ───────────────────────

  static List<LabResult> _parseJsonArray(String rawText, String locale) {
    // Remove possível markdown code fence ```json ... ```
    final cleaned = rawText
        .replaceAll(RegExp(r'```json\s*', multiLine: true), '')
        .replaceAll(RegExp(r'```\s*', multiLine: true), '')
        .trim();

    final decoded = jsonDecode(cleaned);
    final List list = decoded is List ? decoded : [];

    final parsed = list.map((e) {
      final result = LabResult.fromJson(Map<String, dynamic>.from(e as Map));
      // Força status critical nos gatilhos clínicos de segurança
      return result.copyWith(status: _forceCritical(result));
    }).toList();

    return LabNormalizer.normalizeResults(parsed, locale);
  }

  // ── Gatilhos de status Critical ───────────────────────────────────────
  //
  // Valores fora desses limiares exigem atenção imediata — o status é
  // forçado para `critical` independente do que o Gemini retornou.

  static LabStatus _forceCritical(LabResult result) {
    final key = LabNormalizer.normalizeKey(result.examKey);
    final v   = result.value;

    if (key == 'potassium'   && (v >= 6.5  || v < 2.5))   return LabStatus.critical;
    if (key == 'sodium'      && (v < 120   || v > 160))    return LabStatus.critical;
    if (key == 'glucose'     && (v < 50    || v > 600))    return LabStatus.critical;
    if (key == 'ph'          && (v < 7.10  || v > 7.60))   return LabStatus.critical;
    if (key == 'lactate'     && v >= 4.0)                   return LabStatus.critical;
    if (key == 'hemoglobin'  && v < 7.0)                    return LabStatus.critical;
    if (key == 'platelets'   && v < 20000)                  return LabStatus.critical;
    if (key == 'paco2'       && (v < 20    || v > 70))      return LabStatus.critical;
    if (key == 'pao2'        && v < 50)                     return LabStatus.critical;
    if (key == 'calcium'     && (v < 6.5   || v > 13.0))   return LabStatus.critical;
    if (key == 'magnesium'   && (v < 0.8   || v > 4.0))    return LabStatus.critical;
    if (key == 'inr'         && v > 5.0)                    return LabStatus.critical;

    return result.status;
  }

  // ── Construtores de body para a API Gemini ────────────────────────────

  static Map<String, dynamic> _buildTextBody(String text, String locale) {
    return {
      'contents': [
        {
          'parts': [
            {'text': _systemPrompt(locale)},
            {'text': 'Laudo/texto para análise:\n\n$text'},
          ],
        },
      ],
      'generationConfig': {
        'temperature':       0.05,  // máximo determinismo para extração estruturada
        'maxOutputTokens':   4096,
        'responseMimeType': 'application/json',
      },
      'safetySettings': _safetySettings(),
    };
  }

  static Map<String, dynamic> _buildImageBody(
    Uint8List bytes,
    String mimeType,
    String locale,
  ) {
    return {
      'contents': [
        {
          'parts': [
            {'text': _systemPrompt(locale)},
            {
              'inlineData': {
                'mimeType': mimeType,
                'data':     base64Encode(bytes),
              },
            },
          ],
        },
      ],
      'generationConfig': {
        'temperature':       0.05,
        'maxOutputTokens':   4096,
        'responseMimeType': 'application/json',
      },
      'safetySettings': _safetySettings(),
    };
  }

  static Map<String, dynamic> _buildPdfBody(
    Uint8List bytes,
    String locale,
  ) {
    return {
      'contents': [
        {
          'parts': [
            {'text': _systemPrompt(locale)},
            {
              'inlineData': {
                'mimeType': 'application/pdf',
                'data':     base64Encode(bytes),
              },
            },
          ],
        },
      ],
      'generationConfig': {
        'temperature':       0.05,
        'maxOutputTokens':   4096,
        'responseMimeType': 'application/json',
      },
      'safetySettings': _safetySettings(),
    };
  }

  // ── System prompt bilíngue ────────────────────────────────────────────

  static String _systemPrompt(String locale) {
    final isEs = locale.toLowerCase() == 'es';

    final langInstruction = isEs
        ? 'Preencha "examName" obrigatoriamente em ESPANHOL '
          '(ex: Sódio → Sodio, Ureia → Urea, Hemoglobina → Hemoglobina, '
          'Plaquetas → Plaquetas, Leucócitos → Leucocitos).'
        : 'Preencha "examName" obrigatoriamente em PORTUGUÊS '
          '(ex: Sodium → Sódio, Urea → Ureia, Hemoglobin → Hemoglobina, '
          'Platelets → Plaquetas, WBC → Leucócitos).';

    return '''
Você é um extrator especializado de laudos laboratoriais médicos para o MedCases Pro.

TAREFA: Analise o conteúdo fornecido (texto, imagem ou PDF) e retorne EXCLUSIVAMENTE um array JSON.
Cada objeto do array representa UM parâmetro laboratorial com os campos abaixo:

{
  "examKey":        string  // OBRIGATÓRIO — chave inglesa snake_case (ex: "sodium", "potassium", "hemoglobin")
  "examName":       string  // OBRIGATÓRIO — nome legível no idioma do usuário (ver instrução abaixo)
  "value":          number  // OBRIGATÓRIO — valor numérico (use ponto como decimal, nunca vírgula)
  "unit":           string  // OBRIGATÓRIO — unidade (ex: "mEq/L", "mg/dL", "g/dL", "%", "x10³/µL")
  "referenceRange": string  // OPCIONAL — faixa de referência do laudo (ex: "135-145")
  "status":         string  // OBRIGATÓRIO — "low" | "normal" | "high" | "critical"
  "confidence":     number  // OBRIGATÓRIO — 0.0 a 1.0: certeza da extração OCR
  "originalText":   string  // OBRIGATÓRIO — trecho literal capturado do laudo
}

INSTRUÇÕES CRÍTICAS:
1. examKey: sempre em inglês snake_case minúsculo. Nunca em PT ou ES.
   Exemplos corretos: "sodium", "potassium", "creatinine", "base_excess", "paco2"
   Exemplos ERRADOS: "sodio", "potássio", "creatinina"

2. $langInstruction

3. value: converta vírgula decimal para ponto. Se o valor for ambíguo ou ilegível, use 0 e confidence < 0.5.

4. status: avalie conforme a faixa de referência do laudo. Se não houver referência, use limites clínicos universais.

5. confidence: reflita a legibilidade real:
   - Texto digital nítido: 0.95–1.0
   - Texto manuscrito ou PDF escaneado: 0.75–0.90
   - Foto com ruído/borramento: 0.50–0.75
   - Valor ilegível: < 0.50

6. Inclua TODOS os parâmetros encontrados, mesmo os normais.

7. Retorne APENAS o array JSON limpo. Sem markdown, sem comentários, sem texto introdutório.
   Exemplo de saída válida: [{"examKey":"sodium","examName":"Sódio",...}, ...]
''';
  }

  // ── Safety settings (igual ao GeminiService principal) ────────────────

  static List<Map<String, String>> _safetySettings() => [
    {'category': 'HARM_CATEGORY_HARASSMENT',        'threshold': 'BLOCK_NONE'},
    {'category': 'HARM_CATEGORY_HATE_SPEECH',       'threshold': 'BLOCK_NONE'},
    {'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT', 'threshold': 'BLOCK_NONE'},
    {'category': 'HARM_CATEGORY_DANGEROUS_CONTENT', 'threshold': 'BLOCK_NONE'},
  ];

  // ── Guard: API key ────────────────────────────────────────────────────

  static void _assertApiKey() {
    if (!GeminiService.hasApiKey) {
      throw LabParseException(
        'Gemini API Key não configurada. '
        'Conecte sua conta Google no menu lateral.',
      );
    }
  }
}

// ── Exceção tipada ────────────────────────────────────────────────────────────

/// Exceção lançada quando a extração falha por qualquer motivo.
/// Sempre contém uma mensagem pronta para exibição ao usuário.
class LabParseException implements Exception {
  final String message;
  const LabParseException(this.message);

  @override
  String toString() => 'LabParseException: $message';
}
