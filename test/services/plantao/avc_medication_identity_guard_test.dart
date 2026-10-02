import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/ai/widgets/guardia_clinical_response_view.dart';
import 'package:medcases/services/plantao_avc_approved_medication_identity_guard.dart';
import 'package:medcases/services/plantao_global_clinical_response_gate.dart';
import 'package:medcases/data/protocols_database.dart';

void main() {
  const anonymousEs = '• 0.9 mg/kg hasta un máximo de 90 mg por vía IV, '
      'con diez por ciento en bolo y el resto en infusión 60 min';
  const anonymousPt = '• 0,9 mg/kg até um máximo de 90 mg IV, '
      '10% em bolo e o restante em infusão 60 min';
  final model = protocolsDatabase.singleWhere((p) => p.id == 'avc_isquemico');
  String repair(String text, String lang, {
    String owner = 'avc_isquemico', bool authority = true,
    String version = 'AHA_ASA_AIS_2026_CORRECTED_JULY_2026',
  }) => PlantaoAvcApprovedMedicationIdentityGuard.preserveName(
    text: text, language: lang, authoritative: authority,
    pathologyKey: owner, guidelineVersion: version,
    approvedActions: model.getActions(lang),
  );

  test('screenshot anonymous Spanish regimen keeps dose and displays Alteplasa', () {
    expect(repair(anonymousEs, 'es'), anonymousEs.replaceFirst('0.9', 'Alteplasa: 0.9'));
  });
  test('Portuguese regimen keeps dose and displays Alteplase', () {
    expect(repair(anonymousPt, 'pt'), anonymousPt.replaceFirst('0,9', 'Alteplase: 0,9'));
  });
  test('named prescription remains byte identical and repair is idempotent', () {
    final named = repair(anonymousEs, 'es');
    expect(repair(named, 'es'), named);
  });
  test('another owner, historical version and absent authority are unchanged', () {
    expect(repair(anonymousEs, 'es', owner: 'caso_avc_isquemico'), anonymousEs);
    expect(repair(anonymousEs, 'es', version: 'AHA_ASA_AIS_2026'), anonymousEs);
    expect(repair(anonymousEs, 'es', authority: false), anonymousEs);
  });
  test('dose alone or mismatched maximum never assigns a drug', () {
    const doseOnly = '• 0.9 mg/kg IV';
    expect(repair(doseOnly, 'es'), doseOnly);
    final different = anonymousEs.replaceFirst('90 mg', '100 mg');
    expect(repair(different, 'es'), different);
  });
  test('production presentation gate retains the approved drug identity', () {
    final result = PlantaoGlobalClinicalResponseGate.finalizeForPresentation(
      userText: 'ACV isquémico agudo',
      rawText: 'Conducta inmediata\n- Activar código ACV\n\n'
          'Tratamiento farmacológico\n$anonymousEs',
      language: 'es', enforceRequiredActions: false,
      contextPack: PlantaoGlobalClinicalContextPack(
        pathologyKey: 'avc_isquemico', protocolKey: 'legacy_protocol::avc_isquemico',
        authoritative: true, guidelineVersion: 'AHA_ASA_AIS_2026_CORRECTED_JULY_2026',
        requiredActions: model.getActions('es'),
      ),
    );
    expect(result.finalText, contains('Alteplasa: 0.9 mg/kg'));
  });
  for (final lang in ['pt', 'es']) {
    testWidgets('AVC $lang displays the medication name beside the dose', (tester) async {
      final named = repair(lang == 'es' ? anonymousEs : anonymousPt, lang);
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: SingleChildScrollView(
          child: GuardiaClinicalResponseView(
            rawText: '${lang == 'es' ? 'Tratamiento farmacológico' : 'Tratamento farmacológico'}\n$named',
            dark: true, languageCode: lang, onCopy: () {},
            typedTreatmentVisualEnabled: false,
          ),
        )),
      ));
      await tester.pumpAndSettle();
      final rendered = tester.widgetList<RichText>(find.byType(RichText))
          .map((widget) => widget.text.toPlainText());
      expect(rendered.any((line) => line.contains(lang == 'es'
          ? 'Alteplasa: 0.9 mg/kg' : 'Alteplase: 0,9 mg/kg')), isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
