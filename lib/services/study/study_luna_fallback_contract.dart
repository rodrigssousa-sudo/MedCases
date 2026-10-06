import '../../models/study_clinical_snapshot.dart';
import 'study_canonical_response.dart';
import 'study_quantity_retention.dart';
import 'study_reference_boundary.dart';

/// Transport adapter for Study chat only. The primary schema, prompt and
/// decoder are shared unchanged; the server owns the model and bounded budget.
class StudyLunaFallbackContract {
  static const model = 'gpt-5.6-luna';
  static const maxOutputTokens = 12288;

  static bool applies({required String mode, required bool studyChat}) =>
      mode == 'estudo' && studyChat;

  static Map<String, Object> fields(String clinicalPrompt) => {
        'provider': 'openai',
        'studyFallbackModel': model,
        'studyCanonicalVersion': StudyClinicalSnapshot.version,
        'systemPrompt': StudyCanonicalResponse.prompt(clinicalPrompt),
        'maxOutputTokens': maxOutputTokens,
      };

  static ({String text, StudyClinicalSnapshot snapshot}) decode(
    Map<String, dynamic> response, {
    required String language,
    required StudyReferenceBoundary references,
  }) {
    if (response['model'] != model ||
        response['finishReason'] != 'STOP' ||
        response['studyCanonicalVersion'] != StudyClinicalSnapshot.version ||
        response['text'] is! String) {
      throw const FormatException('study_luna_invalid_terminal');
    }
    final decoder = StudyCanonicalDecoder(language);
    decoder.add(response['text'] as String);
    decoder.finish();
    final snapshot = decoder.presentationSnapshot(references: references.records);
    if (snapshot == null) {
      throw const FormatException('study_luna_invalid_snapshot');
    }
    final text = snapshot.blocks(language, includeContinuation: true).join();
    StudyQuantityRetention.requirePreserved(snapshot, text);
    return (text: text, snapshot: snapshot);
  }
}
