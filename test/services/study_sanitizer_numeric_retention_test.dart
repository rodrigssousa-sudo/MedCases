import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/models/study_clinical_snapshot.dart';
import 'package:medcases/services/ai_pipeline/ai_meta_leak_rules.dart';
import 'package:medcases/services/ai_smart_router.dart';
import 'package:medcases/services/study/study_quantity_retention.dart';
import 'study_global_validation_regression_test.dart' show finalizeStudyFixture;

StudyClinicalSnapshot fixture() => StudyClinicalSnapshot.fromRecords([
      {
        'type': 'title',
        'id': 'topic',
        'localization': {'pt': 'Exemplo sintético', 'es': 'Ejemplo sintético'}
      },
      {
        'type': 'fact',
        'id': 'f1',
        'clinical': {
          'section': 'monitoring',
          'conceptId': 'synthetic_value',
          'actionId': 'monitor',
          'polarity': 'positive',
          'conditionIds': <String>[],
          'items': [
            {'id': 'f1a', 'kind': 'concept', 'code': 'synthetic', 'value': null}
              ..remove('value'),
            {'id': 'f1q', 'kind': 'quantity', 'value': '30 mL'},
            {'id': 'f1r', 'kind': 'relation', 'code': 'context'}
          ]
        },
        'localization': {
          'f1a': {'pt': 'Valor sintético', 'es': 'Valor sintético'},
          'f1r': {
            'pt': 'conforme o contexto clínico.',
            'es': 'según el contexto clínico.'
          }
        }
      },
      {'type': 'end'}
    ]);

void main() {
  for (final lang in ['pt', 'es']) {
    test(
        'Study $lang preserves numeric prose with exact old clinical-context trigger',
        () async {
      final snapshot = fixture();
      final text = snapshot.blocks(lang).join();
      final line = text.split('\n').firstWhere((line) => line.startsWith('-'));
      final old = AiMetaLeakRules.match(line)!;
      expect(old.ruleId, 'META_LEAK_CLINICAL_CONTEXT_LABEL');
      expect(AiMetaLeakRules.match(line, study: true), isNull);
      final sanitized = AiSmartRouter.sanitizeAndCheck(text, appLanguage: lang);
      expect(sanitized.hadMetaLeak, isFalse);
      expect(sanitized.text, contains('30 mL'));
      final finalText = await finalizeStudyFixture(text, lang);
      StudyQuantityRetention.requirePreserved(snapshot, finalText);
      expect(
          finalText,
          contains(lang == 'pt'
              ? 'conforme o contexto clínico'
              : 'según el contexto clínico'));
    });
    test('Study $lang retains lexical trigger without debug meaning', () {
      for (final line in [
        'Decidir pelo contexto clínico.',
        'Interpretar no contexto clinico.',
        'Interpretar según el contexto clínico.',
        '## Contexto clínico'
      ]) {
        expect(
            AiSmartRouter.sanitizeAndCheck(line, appLanguage: lang).text, line);
      }
    });
    test('Study $lang removes explicit clinical-context metadata labels', () {
      for (final marker in [
        'CONTEXTO CLÍNICO: interno',
        '[CONTEXTO CLINICO] interno',
        '**CONTEXTO CLÍNICO**: interno',
        '- CONTEXTO CLINICO=interno'
      ]) {
        final result = AiSmartRouter.sanitizeAndCheck('$marker\nTexto final.',
            appLanguage: lang);
        expect(result.text, 'Texto final.');
      }
    });
    test(
        'Study $lang preserves numbers units acronyms headings references and CTA',
        () {
      const text =
          '## Mecanismo\n\nValor sintético **500 mg** VO c/24 h; ECG.\n\n'
          '## Referencias\n\nRegistro sintético de prueba.\n\n'
          '[NEXT_ACTION_LABEL: Alternativa]\n[NEXT_ACTION_PROMPT: Alternativa sintética]';
      expect(
          AiSmartRouter.sanitizeAndCheck(text, appLanguage: lang).text, text);
    });
  }
  test(
      'genuine internal prompt debug reasoning and schema labels remain removed',
      () {
    const input =
        "Let's review constraints:\nLanguage checked.\nLine 17\nschema: internal\n"
        '# Resposta final\n[PROMPT] instrução\n[AI_ROUTER] debug\n'
        'Language: checked\nSchema: internal\nLine 17: ## Mecanismo\nTexto final.';
    final result = AiSmartRouter.sanitizeAndCheck(input).text;
    for (final marker in [
      "Let's review constraints",
      'Language checked',
      'Line 17',
      'schema:',
      'Schema:',
      '[PROMPT]',
      '[AI_ROUTER]'
    ]) {
      expect(result, isNot(contains(marker)));
    }
    expect(result, contains('## Mecanismo'));
    expect(result, contains('Texto final.'));
  });
  test('Plantão retains the previous matching decisions', () {
    const text =
        'Valor sintético 30 mL conforme o contexto clínico.\nTexto final.';
    expect(AiSmartRouter.sanitizeAndCheck(text, isPlantaoMode: true).text,
        'Texto final.');
    expect(AiMetaLeakRules.pattern(study: false).pattern,
        AiMetaLeakRules.legacyPattern.pattern);
  });
  test('diagnostics contain only fixed IDs count hash and locale', () {
    const line = 'Valor sintético 30 mL conforme o contexto clínico.';
    final m = AiMetaLeakRules.metadata(AiMetaLeakRules.match(line)!, line,
        lineIndex: 7, locale: 'es');
    expect(m.keys.toSet(), {
      'ruleId',
      'reasonCode',
      'lineIndex',
      'patternId',
      'containsNumericQuantity',
      'quantityHash',
      'lineLength',
      'locale'
    });
    expect(m['containsNumericQuantity'], true);
    expect(jsonEncode(m), isNot(contains('Valor sintético')));
    expect(
        (m['quantityHash'] as List).single, matches(RegExp(r'^[a-f0-9]{64}$')));
  });
  test('loss of a canonical quantity fails closed with explicit reason', () {
    final snapshot = fixture();
    final text = snapshot.blocks('pt').join().replaceAll('30 mL', '');
    final result = StudyQuantityRetention.audit(snapshot, text);
    expect(result['missingQuantityCount'], 1);
    expect(result['reasonCode'], 'UNEXPLAINED_CANONICAL_QUANTITY_LOSS');
    expect(() => StudyQuantityRetention.requirePreserved(snapshot, text),
        throwsStateError);
  });
  test('only explicit safety reason for exact quantity ID exempts removal', () {
    final snapshot = fixture();
    final text = snapshot.blocks('pt').join().replaceAll('30 mL', '');
    expect(
        StudyQuantityRetention.audit(snapshot, text,
            safetyRemovalReasons: {'other': 'unsafe'})['missingQuantityCount'],
        1);
    expect(
        StudyQuantityRetention.audit(snapshot, text,
            safetyRemovalReasons: {'f1q': ''})['missingQuantityCount'],
        1);
    StudyQuantityRetention.requirePreserved(snapshot, text,
        safetyRemovalReasons: {'f1q': 'EXPLICIT_SYNTHETIC_SAFETY_REASON'});
  });
  test('quantity after comma punctuation is retained, with its word boundary',
      () {
    final snapshot = fixture();
    final text = snapshot
        .blocks('pt')
        .join()
        .replaceAll('Valor sintético 30', 'Valor sintético, 30');
    expect(StudyQuantityRetention.audit(snapshot, text)['missingQuantityCount'],
        0);
  });
  test('quantity boundary does not accept a different larger quantity', () {
    final snapshot = fixture();
    final text = snapshot.blocks('pt').join().replaceAll('30 mL', '130 mL');
    expect(StudyQuantityRetention.audit(snapshot, text)['missingQuantityCount'],
        1);
  });
}
