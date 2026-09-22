import '../../ai_pipeline/ai_request_contract.dart';
import 'clinical_request_safety.dart';

/// Productive boundary used by AppProvider for previews and final presentation.
/// It contains no provider implementation and cannot change patient facts.
class ClinicalSafetyFlow {
  const ClinicalSafetyFlow(this.context);
  final ClinicalRequestContext context;

  ClinicalSafetyResult terminal(String text,
          {AiRequestMode? mode,
          Iterable<String> structuredClaims = const []}) =>
      ClinicalSafetyPass.evaluate(
          context: context,
          output: text,
          outputMode: mode ?? context.mode,
          structuredClaims: structuredClaims);

  /// Only completed explanatory paragraphs can be previewed. Operational
  /// requests and Plantão remain buffered until terminal verification.
  String? preview(String accumulated) {
    if (context.mode != AiRequestMode.estudo ||
        context.isOperationalRequest ||
        !context.mayGenerate) {
      return null;
    }
    final boundary = accumulated.lastIndexOf('\n\n');
    if (boundary < 0) return null;
    final text = accumulated.substring(0, boundary).trimRight();
    if (text.isEmpty ||
        !RegExp(r'[.!?]$').hasMatch(text) ||
        ClinicalSafetyPass.operational(text)) {
      return null;
    }
    if (!terminal(text).allowed) return null;
    return text;
  }

  String present(String text, {AiRequestMode? mode}) =>
      terminal(text, mode: mode).allowed ? text : context.safeMessage;
}
