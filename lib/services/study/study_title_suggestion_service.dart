import '../ai_service.dart';

/// Best-effort short title generation for Study organization.
///
/// A failure here must never interrupt transcription, source review,
/// persistence, or artifact generation.
final class StudyTitleSuggestionService {
  const StudyTitleSuggestionService._();

  static const int _maxInputCharacters = 6000;
  static const int maxTitleCharacters = 64;

  static Future<String?> suggest({
    required String text,
    required bool isEs,
  }) async {
    final normalized = text.trim();
    if (normalized.isEmpty) return null;

    final clipped = normalized.length <= _maxInputCharacters
        ? normalized
        : normalized.substring(0, _maxInputCharacters);

    try {
      final result = await AiService.chat(
        apiKey: '',
        userMessage: '''
MATERIAL EDUCATIVO:
$clipped
''',
        systemPrompt: isEs
            ? '''
Genera SOLO un título breve para organizar este material de estudio.
Reglas:
- identifica el tema clínico principal;
- si no hay un tema específico claro, usa el área médica principal;
- máximo 2 a 6 palabras;
- no uses "Resumen de", "Clase de", "Explicación de";
- no inventes datos ausentes;
- devuelve solamente el título, sin comillas, Markdown ni punto final.
'''
            : '''
Gere SOMENTE um título breve para organizar este material de estudo.
Regras:
- identifique o tema clínico principal;
- se não houver tema específico claro, use a área médica principal;
- máximo de 2 a 6 palavras;
- não use "Resumo de", "Aula de", "Explicação de";
- não invente dados ausentes;
- devolva somente o título, sem aspas, Markdown ou ponto final.
''',
        history: const <Map<String, String>>[],
        maxTokens: 80,
        isPlantaoMode: false,
      );

      if (result.isError || result.text.trim().isEmpty) return null;
      return normalizeCandidate(result.text);
    } catch (_) {
      return null;
    }
  }

  static String? normalizeCandidate(String raw) {
    var value = raw
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map((line) => line.trim())
        .firstWhere(
          (line) => line.isNotEmpty && line != '```',
          orElse: () => '',
        );

    // Model output commonly returns **Título:** / **Tema:**.
    // Remove inline Markdown before label extraction.
    value = value
        .replaceAll('**', '')
        .replaceAll('__', '')
        .replaceAll('`', '')
        .replaceAll(RegExp(r'^#{1,6}\s*'), '')
        .replaceAll(RegExp(r'^[*-]\s+'), '')
        .replaceFirst(
          RegExp(
            r'^(?:t[ií]tulo(?:\s+del?\s+estudio)?|tema|[aá]rea)\s*:\s*',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'^[`"“”‘’]+|[`"“”‘’]+$'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    while (value.endsWith('.') || value.endsWith(':') || value.endsWith(';')) {
      value = value.substring(0, value.length - 1).trimRight();
    }

    final lower = value.toLowerCase();
    if (value.length < 3 ||
        lower == 'novo estudo' ||
        lower == 'nuevo estudio' ||
        lower == 'estudo' ||
        lower == 'estudio') {
      return null;
    }

    if (value.length > maxTitleCharacters) {
      var cut = value.lastIndexOf(' ', maxTitleCharacters);
      if (cut < maxTitleCharacters ~/ 2) {
        cut = maxTitleCharacters;
      }
      value = value.substring(0, cut).trimRight();
    }

    return value.isEmpty ? null : value;
  }
}
