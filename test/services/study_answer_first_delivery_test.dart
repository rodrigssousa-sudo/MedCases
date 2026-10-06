import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/study/study_delivery_policy.dart';
import 'package:medcases/services/study/study_canonical_response.dart';
import 'package:medcases/services/ai/safety/clinical_safety_flow.dart';
import 'package:medcases/services/study/study_quantity_retention.dart';
import 'package:medcases/services/study/study_reference_boundary.dart';
import 'study_canonical_snapshot_test.dart' show records;
import 'study_global_validation_regression_test.dart' show studyContext, finalizeStudyFixture;

void main() {
  test('transient 500/502/504 activate existing Study recovery only', () {
    for (final code in ['http_500', 'http_502', 'http_504']) {
      expect(StudyDeliveryPolicy.isAdditionalTechnicalFailure(code), isTrue);
      expect(StudyDeliveryPolicy.fallbackReasonCode(code), greaterThan(0));
    }
    for (final code in [null, 'api_key_invalid', 'http_401', 'http_403',
      'quota', 'http_429', 'safety', 'content_filter', 'binding_invalid']) {
      expect(StudyDeliveryPolicy.isAdditionalTechnicalFailure(code), isFalse);
    }
  });
  test('Study canonical prompts above old 20k threshold retain primary streaming', () {
    for (final chars in [0, 19999, 20000, 24254, 36000, 80000]) {
      expect(StudyDeliveryPolicy.bypassPrimaryForVolume(isStudy: true, promptChars: chars), false);
      expect(StudyDeliveryPolicy.bypassPrimaryForVolume(isStudy: false, promptChars: chars), chars > 20000);
    }
  });
  for (final query in ['Cetoacidosis diabética', 'Síndrome nefrótico', 'Metformina',
    'Sepse', 'IAM', 'Asma', 'Hiperkalemia', 'Anemia', 'AVC', 'Insuficiência cardíaca',
    'Tema educativo fora do repositório']) {
    for (final lang in ['pt', 'es']) {
      test('answer-first without catalog/grounding: $query/$lang', () async {
        final context = studyContext(query, lang: lang);
        expect(context.mayGenerate, true);
        expect(context.unknownCriticalFacts, isEmpty);
        // Synthetic bound notation exercises the delivery pipeline, not the
        // factual accuracy of a generated answer for this disease.
        final decoder = StudyCanonicalDecoder(lang);
        decoder.add(jsonEncode(records()));decoder.finish();
        final snapshot = decoder.presentationSnapshot(references: StudyReferenceBoundary().records)!;
        final answer = snapshot.blocks(lang).join();
        final safe = ClinicalSafetyFlow(context).present(answer);
        final ui = await finalizeStudyFixture(safe, lang);
        expect(ui, isNotEmpty);
        expect(ui, contains('2.5–5 mg/kg'));
        StudyQuantityRetention.requirePreserved(snapshot, ui);
        expect(ui, isNot(matches('Valida[çc][ãó]o cl[íi]nica|no se mostr|não foi exibida|No pudimos|Não há suporte')));
        expect(ui, isNot(contains('clinical')));
      });
    }
  }
  test('missing binding cannot erase independently validated dose fact', () {
    final rows = records();
    rows[2]['localization']['f_two_monitor'].remove('es');
    for (final lang in ['pt','es']) {
      final decoder = StudyCanonicalDecoder(lang);
      final shown = decoder.add(jsonEncode(rows));decoder.finish();
      expect(decoder.issues, isNotEmpty);
      final snapshot = decoder.presentationSnapshot()!;
      expect(shown, contains('2.5–5 mg/kg'));
      StudyQuantityRetention.requirePreserved(snapshot, shown);
      expect(snapshot.quantities, hasLength(2));
    }
  });
}
