import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../models/study_workspace_model.dart';
import '../gemini_service.dart';

final class StudyEducationalMaterialPolicy {
  const StudyEducationalMaterialPolicy._();

  static const bool binaryRemoteExtractionEnabled = true;
  static const bool realPatientMaterialAllowed = false;
  static const bool explicitEducationalConfirmationRequired = true;
  static const int maxInlineBytes = 20 * 1024 * 1024;
}

final class StudyExtraction {
  const StudyExtraction({required this.text, required this.refs});

  final String text;
  final List<SourceRef> refs;
}

final class StudyMultimodalExtractionService {
  const StudyMultimodalExtractionService._();

  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/'
      'gemini-2.5-flash:generateContent';

  static StudyExtraction text({
    required String sourceId,
    required String value,
  }) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, 'value');
    }

    return StudyExtraction(
      text: normalized,
      refs: <SourceRef>[
        SourceRef(
          sourceId: sourceId,
          sourceType: StudySourceType.text,
          textBlockIndex: 1,
        ),
      ],
    );
  }

  static Future<StudyExtraction> binary({
    required String sourceId,
    required StudySourceType type,
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
    required bool isEs,
  }) async {
    if (!StudyEducationalMaterialPolicy.binaryRemoteExtractionEnabled) {
      throw StateError('study_binary_extraction_disabled');
    }
    if (bytes.isEmpty) throw StateError('study_file_empty');
    if (bytes.length > StudyEducationalMaterialPolicy.maxInlineBytes) {
      throw StateError('study_file_over_20mb');
    }
    if (!_mimeAllowed(type, mimeType)) {
      throw StateError('study_mime_not_allowed');
    }
    if (!GeminiService.hasApiKey || GeminiService.apiKeyForLab.trim().isEmpty) {
      throw StateError('study_ai_not_ready');
    }

    final prompt =
        """
MODO ESTUDIO MEDCASES — EXTRACCIÓN DE MATERIAL EDUCATIVO.
Archivo: $fileName
Idioma de salida: ${isEs ? "español" : "português"}.

No diagnostiques. No resumas todavía.
Extrae/transcribe el contenido de forma fiel.
Preserva dosis, números, unidades, clasificaciones y negaciones.
Para PDF: separa por página e informa pageNumber cuando sea identificable.
Para audio: separa bloques e informa startMs/endMs aproximados si es posible.
Para imagen: OCR fiel e imageIndex=1.

Devuelve SOLO JSON válido:
{"chunks":[
  {"text":"...", "pageNumber":null, "startMs":null,
   "endMs":null, "imageIndex":null}
]}
""";

    final body = <String, Object?>{
      'contents': <Object?>[
        <String, Object?>{
          'role': 'user',
          'parts': <Object?>[
            <String, Object?>{'text': prompt},
            <String, Object?>{
              'inlineData': <String, Object?>{
                'mimeType': mimeType,
                'data': base64Encode(bytes),
              },
            },
          ],
        },
      ],
      'generationConfig': <String, Object?>{
        'temperature': 0.1,
        'responseMimeType': 'application/json',
        'maxOutputTokens': 8192,
      },
    };

    final uri = Uri.parse(
      '$_endpoint?key='
      '${Uri.encodeQueryComponent(GeminiService.apiKeyForLab)}',
    );

    final response = await http
        .post(
          uri,
          headers: const <String, String>{'content-type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 90));

    if (response.statusCode != 200) {
      throw StateError('study_extract_http_${response.statusCode}');
    }

    return _decode(
      sourceId: sourceId,
      type: type,
      raw: _candidateText(response.body),
    );
  }

  static bool _mimeAllowed(StudySourceType type, String mimeType) {
    final mime = mimeType.toLowerCase().trim();
    switch (type) {
      case StudySourceType.pdf:
        return mime == 'application/pdf';
      case StudySourceType.image:
        return <String>{
          'image/jpeg',
          'image/png',
          'image/webp',
          'image/gif',
        }.contains(mime);
      case StudySourceType.uploadedAudio:
        return <String>{
          'audio/mp4',
          'audio/mpeg',
          'audio/wav',
          'audio/x-wav',
          'audio/aac',
        }.contains(mime);
      case StudySourceType.recordedAudio:
      case StudySourceType.text:
        return false;
    }
  }

  static String _candidateText(String body) {
    final root = jsonDecode(body);
    if (root is! Map<String, dynamic>) {
      throw const FormatException('invalid Gemini response');
    }
    final candidates = root['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw const FormatException('Gemini candidates missing');
    }
    final candidate = candidates.first;
    if (candidate is! Map<String, dynamic>) {
      throw const FormatException('Gemini candidate invalid');
    }
    final content = candidate['content'];
    if (content is! Map<String, dynamic>) {
      throw const FormatException('Gemini content missing');
    }
    final parts = content['parts'];
    if (parts is! List) {
      throw const FormatException('Gemini parts missing');
    }

    final out = StringBuffer();
    for (final part in parts) {
      if (part is Map<String, dynamic>) {
        final text = part['text'];
        if (text is String && text.trim().isNotEmpty) {
          if (out.length > 0) out.writeln();
          out.write(text.trim());
        }
      }
    }

    if (out.length == 0) {
      throw const FormatException('Gemini extraction empty');
    }
    return out.toString();
  }

  static StudyExtraction _decode({
    required String sourceId,
    required StudySourceType type,
    required String raw,
  }) {
    var clean = raw.trim();
    clean = clean
        .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
        .replaceFirst(RegExp(r'\s*```$'), '')
        .trim();

    final root = jsonDecode(clean);
    if (root is! Map<String, dynamic>) {
      throw const FormatException('Study extraction root invalid');
    }

    final chunks = root['chunks'];
    if (chunks is! List || chunks.isEmpty) {
      throw const FormatException('Study extraction chunks missing');
    }

    final text = <String>[];
    final refs = <SourceRef>[];

    for (var index = 0; index < chunks.length; index++) {
      final item = chunks[index];
      if (item is! Map<String, dynamic>) continue;

      final value = (item['text'] as String?)?.trim() ?? '';
      if (value.isEmpty) continue;

      text.add(value);
      refs.add(
        SourceRef(
          sourceId: sourceId,
          sourceType: type,
          pageNumber: _positive(item['pageNumber']),
          timestampStartMs: _nonNegative(item['startMs']),
          timestampEndMs: _nonNegative(item['endMs']),
          imageIndex:
              _positive(item['imageIndex']) ??
              (type == StudySourceType.image ? 1 : null),
        ),
      );
    }

    if (text.isEmpty) {
      throw const FormatException('Study extraction has no text');
    }

    return StudyExtraction(
      text: text.join('\n\n'),
      refs: List<SourceRef>.unmodifiable(refs),
    );
  }

  static int? _positive(Object? value) {
    final number = _int(value);
    return number != null && number > 0 ? number : null;
  }

  static int? _nonNegative(Object? value) {
    final number = _int(value);
    return number != null && number >= 0 ? number : null;
  }

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
