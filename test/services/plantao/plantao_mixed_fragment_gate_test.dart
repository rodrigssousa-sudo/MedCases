import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/plantao_global_clinical_response_gate.dart';
import 'package:medcases/services/ai/safety/clinical_safety_flow.dart';
import '../ai/recovery/ai_recovery_audit_test.dart' show contextFor;

void main() {
  for (final lang in ['pt', 'es']) {
    final before = lang == 'pt'
        ? 'A encefalopatia hepática é uma síndrome neuropsiquiátrica.'
        : 'La encefalopatía hepática es un síndrome neuropsiquiátrico.';
    final after = lang == 'pt'
        ? 'A fisiopatologia envolve disfunção hepática e fatores precipitantes.'
        : 'La fisiopatología incluye disfunción hepática y factores precipitantes.';
    for (final separator in ['\n\n', ' ']) {
      test('mixed fragments $lang separator=${separator.length}', () {
        final result = PlantaoGlobalClinicalGateResult(
          finalText: ClinicalSafetyFlow(contextFor('Encefalopatía hepática',lang:lang)).present('Encefalopatía hepática\n\n'
              '${lang == 'pt' ? 'Conduta imediata' : 'Conducta inmediata'}\n'
              '$before${separator}Administrar 999 mg de fármaco ficticio.$separator$after'),
          issues: const [PlantaoGlobalClinicalGateIssue(
            code:'required_action_missing', critical:true, detail:'required action')],
          projected:true, machineAuthorityEvaluated:true,
        );
        final actual = PlantaoGlobalClinicalResponseGate.degradeCriticalResultForPresentation(result:result,language:lang);
        expect(actual.hasCriticalIssue,isTrue); // Gate still authoritative.
        expect(actual.finalText,contains(before));
        expect(actual.finalText,contains(after));
        expect(actual.finalText,isNot(contains('999 mg')));
        expect(actual.finalText,isNot(contains('Administrar')));
        expect(actual.finalText,isNot(contains('Nota de valid')));
      });
    }
  }
}
