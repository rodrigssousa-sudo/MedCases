import '../gemini_service_v2.dart';
import '../ai/safety/clinical_dose_scope.dart';
import '../study_response_contract.dart';

/// Study-only transport presentation. ClinicalSafetyFlow still owns clinical
/// scope and references after these structural/numeric checks.
class StudyAnswerFirst {
  static const version = 'study_answer_first_v1';
  static String prompt(String clinicalPrompt, String language) =>
      'STUDY ANSWER FIRST v1\n$clinicalPrompt\n'
      '${StudyResponseContract.forLanguage(language)}'
      'Return educational Markdown, not JSON or internal metadata. '
      'Complete each paragraph before starting another; end clinical sentences '
      'with punctuation. Never leave a dose or its qualification unfinished.\n';

  static bool safeFragment(String text) {
    if (ClinicalDoseScope.hasInvalidReferenceValue(text)) return false;
    if (RegExp(r'\b(?:NaN|Infinity|system_prompt|debug|chain.of.thought)\b|[{}]|```|<\/?(?:think|analysis)', caseSensitive: false).hasMatch(text)) return false;
    final clean = text.replaceAll('**', '');
    for (final m in RegExp(r'(\d+(?:[.,]\d+)?)\s*[–−-]\s*(\d+(?:[.,]\d+)?)').allMatches(clean)) {
      if (double.parse(m[1]!.replaceAll(',', '.')) > double.parse(m[2]!.replaceAll(',', '.'))) return false;
    }
    if (RegExp(r'\d+[.,]\d+[.,]\d+|\d\s*[.,]\s*(?:mg|mcg|mL|UI)\b',caseSensitive:false).hasMatch(clean)) return false;
    return true;
  }

  static String safeBlock(String block) {
    final kept = <String>[];
    for (final line in block.split('\n')) {
      final fragments = line.split(RegExp(r'(?<=[.!?])\s+(?=[A-ZÁÉÍÓÚÀÂÊÔÇÑ¿])'));
      kept.add(fragments.where(safeFragment).join(' '));
    }
    return kept.join('\n').trim();
  }

  static Stream<GeminiChunk> stream(Stream<GeminiChunk> source) async* {
    var pending = '';
    var terminal = false;
    await for (final chunk in source) {
      pending += chunk.text;
      int split;
      while ((split = pending.indexOf('\n\n')) >= 0) {
        final block = pending.substring(0, split);
        pending = pending.substring(split + 2);
        final safe = safeBlock(block);
        if (safe.isNotEmpty) yield GeminiChunk(text: '$safe\n\n');
      }
      if (chunk.isDone || chunk.isError) {
        terminal = true;
        // A broken tail is never promoted by an error or missing terminal.
        final tail = pending.trim();
        if (!chunk.isError && chunk.finishReason == 'STOP' &&
            RegExp(r'[.!?][*_]*$').hasMatch(tail)) {
          final safe = safeBlock(tail);
          if (safe.isNotEmpty) yield GeminiChunk(text: safe);
        }
        yield GeminiChunk(text: '', isDone: true,
            finishReason: chunk.finishReason, errorCode: chunk.errorCode,
            groundedSources: chunk.groundedSources);
        break;
      }
      if (chunk.groundedSources.isNotEmpty) {
        yield GeminiChunk(text: '', groundedSources: chunk.groundedSources);
      }
    }
    if (!terminal) yield GeminiChunk.error('stream_error');
  }
}
