import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_service.dart';

String _plantaoPrompt(String query, {String lang = 'pt'}) {
  return AiService.buildClinicalSystemPrompt(
    lang: lang,
    matchedProtocolSummaries: const [],
    matchedDrugSummaries: const [],
    userQuery: query,
    isFirstMessage: false,
    isPlantaoMode: true,
  );
}

void main() {
  group('Plantao/Guardia calculation action contract', () {
    test('PT explicit weight calculation injects mandatory numeric total', () {
      final prompt = _plantaoPrompt('Calcule para 80 kg.');
      expect(prompt, contains('[CALCULO_POR_PESO]'));
      expect(prompt, contains('80 kg'));
      expect(prompt, contains('resultado numerico absoluto'));
      expect(prompt, contains('calcular minimo E maximo'));
      expect(prompt, contains('NAO invente dose-base'));
    });

    test('PT multiple doses for weight injects the same contract', () {
      final prompt = _plantaoPrompt('Calcule as doses para 18 kg.');
      expect(prompt, contains('[CALCULO_POR_PESO]'));
      expect(prompt, contains('18 kg'));
      expect(prompt, contains('varios farmacos'));
    });

    test('ES accented enclitic injects mandatory numeric total', () {
      final prompt = _plantaoPrompt('Calcúlala para 80 kg.', lang: 'es');
      expect(prompt, contains('[CALCULO_POR_PESO]'));
      expect(prompt, contains('80 kg'));
      expect(prompt, contains('resultado numerico absoluto'));
      expect(prompt, contains('calcular minimo Y maximo'));
      expect(prompt, contains('NO inventes una dosis base'));
    });

    test('ES short continuation with new weight preserves calculation contract', () {
      final prompt = _plantaoPrompt('¿Y para 90 kg?', lang: 'es');
      expect(prompt, contains('[CALCULO_POR_PESO]'));
      expect(prompt, contains('90 kg'));
    });

    test('bare weight statement does not activate pharmacologic calculation', () {
      final prompt = _plantaoPrompt('Paciente pesa 80 kg.');
      expect(prompt, isNot(contains('[CALCULO_POR_PESO]')));
    });

    test('unrelated BMI calculation does not activate pharmacologic calculation', () {
      final prompt = _plantaoPrompt('Calcule IMC para 80 kg.');
      expect(prompt, isNot(contains('[CALCULO_POR_PESO]')));
    });

    test('ES calculation contract is independent from external-tool routing', () {
      final prompt = _plantaoPrompt(
        'Calcúlala para 80 kg.',
        lang: 'es',
      );
      expect(prompt, contains('[CALCULO_POR_PESO]'));
      expect(prompt, contains('Usa SOLO el farmaco/regimen activo'));
    });
  });
}
