import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/study_workspace_model.dart';
import '../gemini_service.dart';
import 'study_multimodal_extraction_service.dart';

final class StudyLongInputPolicy {
  const StudyLongInputPolicy._();

  static const Duration maxUploadedAudioDuration = Duration(hours: 4);
  static const int audioTokensPerSecond = 32;
  static const int maxUploadedAudioTokens = 4 * 60 * 60 * audioTokensPerSecond;

  static const int maxPdfBytes = 50 * 1024 * 1024;
  static const int maxFilesApiBytes = 2 * 1024 * 1024 * 1024;
  static const int maxPdfPages = 1000;
  static const int targetAudioBlockMs = 5 * 60 * 1000;

  static bool supports(StudySourceType type) =>
      type == StudySourceType.uploadedAudio || type == StudySourceType.pdf;
}

final class _RemoteStudyFile {
  const _RemoteStudyFile({
    required this.name,
    required this.uri,
    required this.mimeType,
    required this.state,
  });

  final String name;
  final String uri;
  final String mimeType;
  final String state;

  _RemoteStudyFile copyWith({String? state}) => _RemoteStudyFile(
        name: name,
        uri: uri,
        mimeType: mimeType,
        state: state ?? this.state,
      );
}

final class StudyLargeFileExtractionService {
  const StudyLargeFileExtractionService._();

  static const String _model = 'gemini-2.5-flash';
  static const String _apiRoot =
      'https://generativelanguage.googleapis.com/v1beta';
  static const String _uploadStart =
      'https://generativelanguage.googleapis.com/upload/v1beta/files';

  static const Duration _startTimeout = Duration(seconds: 45);
  static const Duration _uploadTimeout = Duration(minutes: 20);
  static const Duration _processingTimeout = Duration(minutes: 12);
  static const Duration _generationTimeout = Duration(minutes: 15);

  static Future<StudyExtraction> binaryStream({
    required String sourceId,
    required StudySourceType type,
    required String fileName,
    required String mimeType,
    required int byteLength,
    required Stream<List<int>> byteStream,
    required bool isEs,
  }) async {
    if (!StudyLongInputPolicy.supports(type)) {
      throw StateError('study_long_input_type_not_supported');
    }
    if (!StudyEducationalMaterialPolicy.binaryRemoteExtractionEnabled) {
      throw StateError('study_binary_extraction_disabled');
    }
    if (StudyEducationalMaterialPolicy.realPatientMaterialAllowed) {
      throw StateError('study_long_input_patient_material_policy_invalid');
    }
    if (byteLength <= 0) throw StateError('study_file_empty');
    if (byteLength > StudyLongInputPolicy.maxFilesApiBytes) {
      throw StateError('study_file_over_2gb');
    }
    if (type == StudySourceType.pdf &&
        byteLength > StudyLongInputPolicy.maxPdfBytes) {
      throw StateError('study_pdf_over_50mb');
    }
    if (!_mimeAllowed(type, mimeType)) {
      throw StateError('study_long_input_mime_not_allowed');
    }
    if (!GeminiService.hasApiKey || GeminiService.apiKeyForLab.trim().isEmpty) {
      throw StateError('study_ai_not_ready');
    }

    final apiKey = GeminiService.apiKeyForLab.trim();
    final client = http.Client();
    _RemoteStudyFile? remote;
    StudyExtraction? extraction;
    Object? primaryError;
    StackTrace? primaryStack;

    try {
      remote = await _upload(
        client: client,
        apiKey: apiKey,
        fileName: fileName,
        mimeType: mimeType,
        byteLength: byteLength,
        byteStream: byteStream,
      );
      remote = await _waitUntilActive(
        client: client,
        apiKey: apiKey,
        file: remote,
      );

      if (type == StudySourceType.uploadedAudio) {
        final audioTokens = await _countTokens(
          client: client,
          apiKey: apiKey,
          file: remote,
        );
        if (audioTokens <= 0) {
          throw StateError('study_audio_duration_unavailable');
        }
        if (audioTokens > StudyLongInputPolicy.maxUploadedAudioTokens) {
          throw StateError('study_audio_over_4h');
        }

        final estimatedDurationMs =
            (audioTokens * 1000 / StudyLongInputPolicy.audioTokensPerSecond)
                .round();

        extraction = await _extractAudio(
          client: client,
          apiKey: apiKey,
          file: remote,
          sourceId: sourceId,
          fileName: fileName,
          isEs: isEs,
          estimatedDurationMs: estimatedDurationMs,
        );
      } else {
        extraction = await _extractPdf(
          client: client,
          apiKey: apiKey,
          file: remote,
          sourceId: sourceId,
          fileName: fileName,
          isEs: isEs,
        );
      }
    } catch (error, stack) {
      primaryError = error;
      primaryStack = stack;
    }

    Object? cleanupError;
    if (remote != null) {
      try {
        await _delete(
          client: client,
          apiKey: apiKey,
          fileName: remote.name,
        );
      } catch (error) {
        cleanupError = error;
      }
    }
    client.close();

    if (cleanupError != null) {
      throw StateError('study_remote_file_cleanup_failed');
    }
    if (primaryError != null) {
      Error.throwWithStackTrace(primaryError, primaryStack!);
    }
    if (extraction == null) {
      throw StateError('study_long_input_extraction_missing');
    }
    return extraction;
  }

  static Future<_RemoteStudyFile> _upload({
    required http.Client client,
    required String apiKey,
    required String fileName,
    required String mimeType,
    required int byteLength,
    required Stream<List<int>> byteStream,
  }) async {
    final start = http.Request('POST', Uri.parse(_uploadStart))
      ..headers.addAll(<String, String>{
        'x-goog-api-key': apiKey,
        'X-Goog-Upload-Protocol': 'resumable',
        'X-Goog-Upload-Command': 'start',
        'X-Goog-Upload-Header-Content-Length': '$byteLength',
        'X-Goog-Upload-Header-Content-Type': mimeType,
        'Content-Type': 'application/json',
      })
      ..body = jsonEncode(<String, Object?>{
        'file': <String, Object?>{'display_name': fileName},
      });

    final startResponse = await client.send(start).timeout(_startTimeout);
    final uploadUrl = startResponse.headers['x-goog-upload-url'];
    await startResponse.stream.drain<void>();

    if (startResponse.statusCode < 200 ||
        startResponse.statusCode >= 300 ||
        uploadUrl == null ||
        uploadUrl.trim().isEmpty) {
      throw StateError(
        'study_files_upload_start_http_${startResponse.statusCode}',
      );
    }

    final upload = http.StreamedRequest('POST', Uri.parse(uploadUrl))
      ..contentLength = byteLength
      ..headers.addAll(<String, String>{
        'Content-Length': '$byteLength',
        'X-Goog-Upload-Offset': '0',
        'X-Goog-Upload-Command': 'upload, finalize',
        'Content-Type': mimeType,
      });

    final responseFuture = client.send(upload).timeout(_uploadTimeout);
    try {
      await upload.sink.addStream(byteStream);
    } finally {
      await upload.sink.close();
    }

    final response = await responseFuture;
    final body = await http.Response.fromStream(response);

    if (body.statusCode < 200 || body.statusCode >= 300) {
      throw StateError('study_files_upload_http_${body.statusCode}');
    }

    final root = jsonDecode(body.body);
    if (root is! Map<String, dynamic>) {
      throw const FormatException('Gemini Files upload response invalid');
    }
    final file = root['file'];
    if (file is! Map<String, dynamic>) {
      throw const FormatException('Gemini Files upload file missing');
    }

    final name = (file['name'] as String?)?.trim() ?? '';
    final uri = (file['uri'] as String?)?.trim() ?? '';
    final returnedMime = (file['mimeType'] as String?)?.trim() ??
        (file['mime_type'] as String?)?.trim() ??
        mimeType;
    final state = (file['state'] as String?)?.trim() ?? 'STATE_UNSPECIFIED';

    if (!name.startsWith('files/') || uri.isEmpty) {
      throw const FormatException('Gemini Files upload identity invalid');
    }

    return _RemoteStudyFile(
      name: name,
      uri: uri,
      mimeType: returnedMime,
      state: state,
    );
  }

  static Future<_RemoteStudyFile> _waitUntilActive({
    required http.Client client,
    required String apiKey,
    required _RemoteStudyFile file,
  }) async {
    if (file.state == 'ACTIVE') return file;
    if (file.state == 'FAILED') {
      throw StateError('study_files_processing_failed');
    }

    final deadline = DateTime.now().add(_processingTimeout);
    var current = file;

    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(seconds: 2));
      final response = await client.get(
        Uri.parse('$_apiRoot/${current.name}'),
        headers: <String, String>{'x-goog-api-key': apiKey},
      ).timeout(_startTimeout);

      if (response.statusCode != 200) {
        throw StateError('study_files_get_http_${response.statusCode}');
      }

      final root = jsonDecode(response.body);
      if (root is! Map<String, dynamic>) {
        throw const FormatException('Gemini Files get response invalid');
      }

      final state = (root['state'] as String?)?.trim() ?? '';
      if (state == 'ACTIVE') return current.copyWith(state: state);
      if (state == 'FAILED') {
        throw StateError('study_files_processing_failed');
      }
      current = current.copyWith(state: state);
    }

    throw StateError('study_files_processing_timeout');
  }

  static Future<int> _countTokens({
    required http.Client client,
    required String apiKey,
    required _RemoteStudyFile file,
  }) async {
    final uri = Uri.parse(
      '$_apiRoot/models/$_model:countTokens'
      '?key=${Uri.encodeQueryComponent(apiKey)}',
    );

    final response = await client
        .post(
          uri,
          headers: const <String, String>{'content-type': 'application/json'},
          body: jsonEncode(<String, Object?>{
            'contents': <Object?>[
              <String, Object?>{
                'role': 'user',
                'parts': <Object?>[
                  <String, Object?>{
                    'fileData': <String, Object?>{
                      'mimeType': file.mimeType,
                      'fileUri': file.uri,
                    },
                  },
                ],
              },
            ],
          }),
        )
        .timeout(_generationTimeout);

    if (response.statusCode != 200) {
      throw StateError('study_audio_count_tokens_http_${response.statusCode}');
    }

    final root = jsonDecode(response.body);
    if (root is! Map<String, dynamic>) {
      throw const FormatException('Gemini countTokens response invalid');
    }
    final value = root['totalTokens'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    throw const FormatException('Gemini countTokens missing totalTokens');
  }

  static Future<StudyExtraction> _extractAudio({
    required http.Client client,
    required String apiKey,
    required _RemoteStudyFile file,
    required String sourceId,
    required String fileName,
    required bool isEs,
    required int estimatedDurationMs,
  }) async {
    final expectedBlocks =
        (estimatedDurationMs / StudyLongInputPolicy.targetAudioBlockMs).ceil();

    final prompt = """
MODO ESTUDIO MEDCASES — TRANSCRIPCIÓN FIEL DE AUDIO EDUCATIVO LARGO.
Archivo: $fileName
Idioma de salida: ${isEs ? "español" : "português"}.
Duración técnica estimada: $estimatedDurationMs ms.
Bloques obligatorios: $expectedBlocks.

TRANSCRIBE, NO RESUMAS.
Preserva fielmente conceptos médicos, dosis, números, unidades,
clasificaciones, criterios, negaciones y relaciones causales.
Corrige solamente puntuación obvia que mejore legibilidad sin cambiar sentido.

Divide TODA la línea temporal en EXACTAMENTE $expectedBlocks bloques
cronológicos de aproximadamente 5 minutos.
Incluye también ventanas sin habla inteligible con un texto breve que lo indique.
No omitas inicio, medio ni final.

Devuelve SOLO JSON válido:
{"chunks":[
  {"text":"transcripción fiel del bloque","startMs":0,"endMs":300000}
]}

REGLAS DE COBERTURA:
- Primer startMs = 0.
- Cada bloque comienza donde terminó el anterior.
- El último endMs debe cubrir la duración completa.
- chunks.length debe ser EXACTAMENTE $expectedBlocks.
""";

    final raw = await _generate(
      client: client,
      apiKey: apiKey,
      file: file,
      prompt: prompt,
    );

    final root = _jsonObject(raw);
    final chunks = root['chunks'];
    if (chunks is! List || chunks.length != expectedBlocks) {
      throw StateError('study_audio_coverage_block_count_mismatch');
    }

    final texts = <String>[];
    final refs = <SourceRef>[];
    var previousEnd = 0;

    for (var i = 0; i < chunks.length; i++) {
      final item = chunks[i];
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Study audio chunk invalid');
      }

      final text = (item['text'] as String?)?.trim() ?? '';
      final start = _int(item['startMs']);
      final end = _int(item['endMs']);

      if (text.isEmpty || start == null || end == null || end <= start) {
        throw StateError('study_audio_coverage_chunk_invalid');
      }
      if (i == 0 && start.abs() > 5000) {
        throw StateError('study_audio_coverage_start_missing');
      }
      if (i > 0 && (start - previousEnd).abs() > 10000) {
        throw StateError('study_audio_coverage_gap_detected');
      }

      texts.add(text);
      refs.add(
        SourceRef(
          sourceId: sourceId,
          sourceType: StudySourceType.uploadedAudio,
          timestampStartMs: start,
          timestampEndMs: end,
        ),
      );
      previousEnd = end;
    }

    if (previousEnd < estimatedDurationMs - 120000) {
      throw StateError('study_audio_coverage_end_missing');
    }

    return StudyExtraction(
      text: texts.join('\n\n'),
      refs: List<SourceRef>.unmodifiable(refs),
    );
  }

  static Future<StudyExtraction> _extractPdf({
    required http.Client client,
    required String apiKey,
    required _RemoteStudyFile file,
    required String sourceId,
    required String fileName,
    required bool isEs,
  }) async {
    final prompt = """
MODO ESTUDIO MEDCASES — LECTURA INTEGRAL DE PDF EDUCATIVO.
Archivo: $fileName
Idioma de salida: ${isEs ? "español" : "português"}.

Lee TODAS las páginas. No produzcas todavía el resumen final.
Crea una extracción académica fiel página por página.
Preserva diagnósticos mencionados, definiciones, fisiopatología, criterios,
clasificaciones, dosis, números, unidades, tratamientos, contraindicaciones,
negaciones, tablas y relaciones relevantes.
Elimina solamente encabezados/pies repetidos y ruido sin valor académico.

Devuelve SOLO JSON válido:
{
  "pageCount": 50,
  "chunks": [
    {"pageNumber":1,"text":"contenido académico fiel de la página"}
  ]
}

REGLAS DE COBERTURA:
- pageCount debe ser el número REAL total de páginas.
- Debe existir EXACTAMENTE un chunk para CADA página 1..pageCount.
- Si una página está vacía o no es legible, inclúyela igualmente y dilo.
- No omitas páginas.
- No inventes contenido no visible en el PDF.
""";

    final raw = await _generate(
      client: client,
      apiKey: apiKey,
      file: file,
      prompt: prompt,
    );

    final root = _jsonObject(raw);
    final pageCount = _int(root['pageCount']);
    if (pageCount == null ||
        pageCount < 1 ||
        pageCount > StudyLongInputPolicy.maxPdfPages) {
      throw StateError('study_pdf_page_count_invalid');
    }

    final chunks = root['chunks'];
    if (chunks is! List || chunks.length != pageCount) {
      throw StateError('study_pdf_coverage_count_mismatch');
    }

    final byPage = <int, String>{};
    for (final rawItem in chunks) {
      if (rawItem is! Map<String, dynamic>) {
        throw const FormatException('Study PDF chunk invalid');
      }
      final page = _int(rawItem['pageNumber']);
      final text = (rawItem['text'] as String?)?.trim() ?? '';
      if (page == null ||
          page < 1 ||
          page > pageCount ||
          text.isEmpty ||
          byPage.containsKey(page)) {
        throw StateError('study_pdf_coverage_page_invalid');
      }
      byPage[page] = text;
    }

    for (var page = 1; page <= pageCount; page++) {
      if (!byPage.containsKey(page)) {
        throw StateError('study_pdf_coverage_page_missing');
      }
    }

    final texts = <String>[];
    final refs = <SourceRef>[];
    for (var page = 1; page <= pageCount; page++) {
      texts.add('[Página $page/$pageCount]\n${byPage[page]!}');
      refs.add(
        SourceRef(
          sourceId: sourceId,
          sourceType: StudySourceType.pdf,
          pageNumber: page,
        ),
      );
    }

    return StudyExtraction(
      text: texts.join('\n\n'),
      refs: List<SourceRef>.unmodifiable(refs),
    );
  }

  static Future<String> _generate({
    required http.Client client,
    required String apiKey,
    required _RemoteStudyFile file,
    required String prompt,
  }) async {
    final uri = Uri.parse(
      '$_apiRoot/models/$_model:generateContent'
      '?key=${Uri.encodeQueryComponent(apiKey)}',
    );

    final response = await client
        .post(
          uri,
          headers: const <String, String>{'content-type': 'application/json'},
          body: jsonEncode(<String, Object?>{
            'contents': <Object?>[
              <String, Object?>{
                'role': 'user',
                'parts': <Object?>[
                  <String, Object?>{'text': prompt},
                  <String, Object?>{
                    'fileData': <String, Object?>{
                      'mimeType': file.mimeType,
                      'fileUri': file.uri,
                    },
                  },
                ],
              },
            ],
            'generationConfig': <String, Object?>{
              'temperature': 0.1,
              'responseMimeType': 'application/json',
              'maxOutputTokens': 65536,
            },
          }),
        )
        .timeout(_generationTimeout);

    if (response.statusCode != 200) {
      throw StateError('study_long_extract_http_${response.statusCode}');
    }

    final root = jsonDecode(response.body);
    if (root is! Map<String, dynamic>) {
      throw const FormatException('Gemini long extraction response invalid');
    }
    final candidates = root['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw const FormatException('Gemini long extraction candidates missing');
    }
    final candidate = candidates.first;
    if (candidate is! Map<String, dynamic>) {
      throw const FormatException('Gemini long extraction candidate invalid');
    }

    final finishReason = (candidate['finishReason'] as String?)?.trim() ?? '';
    if (finishReason != 'STOP') {
      throw StateError(
        finishReason == 'MAX_TOKENS'
            ? 'study_long_extract_truncated'
            : 'study_long_extract_finish_$finishReason',
      );
    }

    final content = candidate['content'];
    if (content is! Map<String, dynamic>) {
      throw const FormatException('Gemini long extraction content missing');
    }
    final parts = content['parts'];
    if (parts is! List) {
      throw const FormatException('Gemini long extraction parts missing');
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
      throw const FormatException('Gemini long extraction empty');
    }
    return out.toString();
  }

  static Map<String, dynamic> _jsonObject(String raw) {
    var clean = raw.trim();
    clean = clean
        .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
        .replaceFirst(RegExp(r'\s*```$'), '')
        .trim();
    final value = jsonDecode(clean);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Study long extraction JSON root invalid');
    }
    return value;
  }

  static Future<void> _delete({
    required http.Client client,
    required String apiKey,
    required String fileName,
  }) async {
    final response = await client.delete(
      Uri.parse('$_apiRoot/$fileName'),
      headers: <String, String>{'x-goog-api-key': apiKey},
    ).timeout(_startTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('study_files_delete_http_${response.statusCode}');
    }
  }

  static bool _mimeAllowed(StudySourceType type, String mimeType) {
    final mime = mimeType.toLowerCase().trim();
    if (type == StudySourceType.pdf) return mime == 'application/pdf';

    if (type == StudySourceType.uploadedAudio) {
      return <String>{
        'audio/mp4',
        'audio/x-m4a',
        'audio/mp3',
        'audio/mpeg',
        'audio/wav',
        'audio/x-wav',
        'audio/aac',
        'audio/aiff',
        'audio/ogg',
        'audio/flac',
      }.contains(mime);
    }
    return false;
  }

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static String friendlyError(Object error, {required bool isEs}) {
    final value = error.toString();

    if (value.contains('study_audio_over_4h')) {
      return isEs
          ? 'El audio supera el límite de 4 horas.'
          : 'O áudio supera o limite de 4 horas.';
    }
    if (value.contains('study_pdf_over_50mb')) {
      return isEs
          ? 'El PDF supera el límite técnico actual de 50 MB.'
          : 'O PDF supera o limite técnico atual de 50 MB.';
    }
    if (value.contains('study_pdf_coverage_')) {
      return isEs
          ? 'No fue posible confirmar la lectura de todas las páginas.'
          : 'Não foi possível confirmar a leitura de todas as páginas.';
    }
    if (value.contains('study_audio_coverage_') ||
        value.contains('study_long_extract_truncated')) {
      return isEs
          ? 'La transcripción quedó incompleta y no fue aceptada. Intenta nuevamente.'
          : 'A transcrição ficou incompleta e não foi aceita. Tente novamente.';
    }
    if (value.contains('study_remote_file_cleanup_failed')) {
      return isEs
          ? 'El archivo fue procesado, pero no se pudo confirmar su eliminación remota.'
          : 'O arquivo foi processado, mas não foi possível confirmar sua exclusão remota.';
    }

    return isEs
        ? 'No fue posible procesar este archivo.'
        : 'Não foi possível processar este arquivo.';
  }
}
