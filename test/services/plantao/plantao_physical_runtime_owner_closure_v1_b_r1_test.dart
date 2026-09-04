import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_service.dart';

String _prompt(
  String query, {
  String lang = 'pt',
  bool first = true,
}) {
  return AiService.buildClinicalSystemPrompt(
    lang: lang,
    matchedProtocolSummaries: const [],
    matchedDrugSummaries: const [],
    userQuery: query,
    isFirstMessage: first,
    isPlantaoMode: true,
  );
}

void main() {
  group('Physical runtime owner closure V1-B-R1', () {
    test('PT assistolia injects nonshockable final authority', () {
      final p = _prompt(
        'Paciente em parada cardiorrespiratória com assistolia. '
        'Qual é o manejo imediato?',
      );
      expect(p, contains('[AUTORIDADE_FINAL_M14_NAO_CHOCAVEL]'));
      expect(p, contains('ASSISTOLIA/AESP = NÃO CHOCÁVEL'));
      expect(p, contains('PROIBIDO indicar desfibrilação/choque'));
      expect(p, contains('Epinefrina 1 mg IV/IO o mais cedo possível'));
      expect(p, contains('repetir a cada 3-5 min'));
      expect(p, contains('nunca como passo da assistolia/AESP atual'));
    });

    test('ES asistolia injects nonshockable final authority', () {
      final p = _prompt(
        'Paciente en parada cardiorrespiratoria con asistolia. '
        '¿Cuál es el manejo inmediato?',
        lang: 'es',
      );
      expect(p, contains('[AUTORIDAD_FINAL_M14_NO_DESFIBRILABLE]'));
      expect(p, contains('ASISTOLIA/AESP = NO DESFIBRILABLE'));
      expect(p, contains('PROHIBIDO indicar desfibrilación/choque'));
      expect(p, contains('Epinefrina 1 mg IV/IO lo antes posible'));
      expect(p, contains('repetir cada 3-5 min'));
      expect(p, contains('nunca como paso de la asistolia/AESP actual'));
    });

    test('PT Perguntas-chave overrides therapeutic matrix', () {
      final p = _prompt(
        'Perguntas-chave: faça perguntas ao paciente para orientar a conduta.',
        first: false,
      );
      expect(p, contains('[AUTORIDADE_FINAL_PERGUNTAS_CHAVE]'));
      expect(p, contains('EXATAMENTE 10 perguntas clínicas'));
      expect(p, contains('"Perguntas-chave:"'));
      expect(p, contains('PROIBIDO: "Conduta imediata"'));
    });

    test('ES Preguntas clave overrides therapeutic matrix', () {
      final p = _prompt(
        'Preguntas clave: haz preguntas al paciente para orientar la conducta.',
        lang: 'es',
        first: false,
      );
      expect(p, contains('[AUTORIDAD_FINAL_PREGUNTAS_CLAVE]'));
      expect(p, contains('EXACTAMENTE 10 preguntas clínicas'));
      expect(p, contains('"Preguntas clave:"'));
      expect(p, contains('PROHIBIDO: "Conducta inmediata"'));
    });

    test('unrelated Plantao query does not receive physical guard', () {
      final p = _prompt('Dose de ceftriaxona em pneumonia.');
      expect(p, isNot(contains('[AUTORIDADE_FINAL_M14_NAO_CHOCAVEL]')));
      expect(p, isNot(contains('[AUTORIDADE_FINAL_PERGUNTAS_CHAVE]')));
    });
  });
}
