import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai/safety/clinical_safety_flow.dart';
import 'package:medcases/services/study/study_artifact_generator.dart';
import 'study_global_validation_regression_test.dart'
    show studyContext, nephroticAnswer;

void main() {
  for (final lang in ['pt', 'es']) {
    test(
        'summary source tool may generate and preserve educational content $lang',
        () {
      final context = studyContext(
          'Resuma o material educativo aceito, sem executar prescrições ou cálculos para um paciente.',
          lang: lang,
          owns: () => true);
      expect(context.mayGenerate, true);
      final result = ClinicalSafetyFlow(context).present(nephroticAnswer(lang));
      expect(StudyArtifactGenerator.isFailureText(result), false);
      expect(result, contains('glomerular'));
    });
  }
}
