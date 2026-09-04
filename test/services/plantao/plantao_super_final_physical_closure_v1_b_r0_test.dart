import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_service.dart';

String _prompt(String query, {String lang = 'pt'}) {
  return AiService.buildClinicalSystemPrompt(
    lang: lang,
    matchedProtocolSummaries: const [],
    matchedDrugSummaries: const [],
    userQuery: query,
    isFirstMessage: true,
    isPlantaoMode: true,
  );
}

void main() {
  group('Super final physical closure V1-B-R0', () {
    test('M14 PT assumes professional already providing resuscitation', () {
      final prompt = _prompt(
        'Paciente em parada cardiorrespiratória com assistolia. Qual é o manejo imediato?',
      );
      expect(prompt, contains('[PLANTAO_M14_PROFESSIONAL_ROLE_V1]'));
      expect(prompt, contains('o usuário já integra a equipe assistencial'));
      expect(prompt, contains('NÃO usar como primeira conduta "chamar ajuda"'));
      expect(prompt, contains('monitorização/análise do ritmo'));
      expect(prompt, contains('sem indicar choque na assistolia/AESP'));
    });

    test('M14 ES assumes professional already providing resuscitation', () {
      final prompt = _prompt(
        'Paciente en parada cardiorrespiratoria con asistolia. ¿Cuál es el manejo inmediato?',
        lang: 'es',
      );
      expect(prompt, contains('[PLANTAO_M14_PROFESSIONAL_ROLE_V1]'));
      expect(prompt, contains('el usuario ya integra el equipo asistencial'));
      expect(prompt, contains('NO usar como primera conducta "pedir ayuda"'));
      expect(prompt, contains('monitorización/análisis del ritmo'));
      expect(prompt, contains('sin indicar choque en asistolia/AESP'));
    });

    test('PCR nonshockable filter exists without deleting shockable action', () {
      final source = File('lib/services/ai_next_action_engine.dart').readAsStringSync();
      expect(source, contains('PLANTAO_PCR_NEXT_ACTION_NONSHOCKABLE_FILTER_V1'));
      expect(source, contains("topic == ClinicalTopic.pcr"));
      expect(source, contains("folded.contains('assistolia')"));
      expect(source, contains("folded.contains('asistolia')"));
      expect(source, contains("folded.contains('aesp')"));
      expect(source, contains('_isShockablePcrNextAction(action)'));
      expect(source, contains('Algoritmo ACLS Chocável'));
      expect(source, contains('Algoritmo ACLS desfibrilable'));
      expect(source, contains('Manejo de causas: 5Hs e 5Ts'));
    });

    test('Q10 final acceptance is before persistence and bounded to one repair owner', () {
      final source = File('lib/providers/app_provider.dart').readAsStringSync();
      final gate = source.indexOf('PLANTAO_QUESTIONS_EXACT_TEN_FINAL_ACCEPTANCE_V1');
      final enforce = source.indexOf('safeOutput = await _enforcePlantaoQuestionsExactTen(');
      final persist = source.indexOf('final persistStatus = await persistAiExchangeOnce(', enforce);
      expect(gate, isNonNegative);
      expect(enforce, greaterThan(gate));
      expect(persist, greaterThan(enforce));
      expect(source, contains("RegExp(r'\\?').allMatches(output).length"));
      expect(source, contains('questionCount < 6 || questionCount > 10'));
      expect(source, contains("requestId: '\${requestId}_q10r1'"));
      expect(source, contains('stage=repair_accept'));
      expect(source, contains('stage=fallback_six'));
      expect(source, contains('questionsRepairedToValidContract'));
    });

    test('canonical routing owners are not moved into super closure files', () {
      final next = File('lib/services/ai_next_action_engine.dart').readAsStringSync();
      final ai = File('lib/services/ai_service.dart').readAsStringSync();
      expect(next, isNot(contains('PlantaoCanonicalRouteResolver.resolveAnalysis(')));
      expect(ai, isNot(contains('PlantaoCanonicalRouteResolver.resolveAnalysis(')));
    });
  });
}
