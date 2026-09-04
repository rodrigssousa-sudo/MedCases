import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/ai/widgets/clinical_reference_resolver.dart';

void main() {
  group('ClinicalReferenceResolver semantic protocol gate', () {
    ClinicalReferenceData resolve(String userText, String aiText) =>
        ClinicalReferenceResolver.resolve(
          userText: userText,
          aiText: aiText,
          lang: 'pt',
        );

    test('mantém sintoma indiferenciado sem protocolo específico', () {
      final result = resolve(
        'Dor na fossa ilíaca',
        '''
🟥 DOR NA FOSSA ILÍACA — DIFERENCIAIS PRIORITÁRIOS
🚨 Avaliação inicial:
• Estabilidade hemodinâmica e avaliação do quadro clínico.
🔑 Pontos-chave:
• Diferenciais prioritários: apendicite, diverticulite, cólica renal.
🚩 RED FLAGS:
• Instabilidade hemodinâmica.
''',
      );
      expect(result.protocolId, isNull);
      expect(result.sourceType, 'general_fallback');
    });

    test('anamnese evolutiva de apendicite usa identidade do heading, não SEM', () {
      final result = resolve(
        'Dor começou há 12 horas na região periumbilical e migrou para FID. '
            'Febre 38,1 C, náuseas, sem sintomas urinários.',
        '''
🟥 APENDICITE AGUDA
🚨 Conduta imediata:
• Realizar hemograma e avaliação cirúrgica.
💊 Tratamento farmacológico:
• Morfina 2–4 mg IV se dor intensa.
• Ceftriaxona 1 g IV + Metronidazol 500 mg IV.
🚩 RED FLAGS:
• Sinais de perfuração.
''',
      );
      expect(result.protocolId, 'apendicite_aguda');
      expect(result.protocolId, isNot('sindrome_coronariana_sem_st'));
    });

    test('PCR laboratorial não vira parada cardiorrespiratória', () {
      final result = resolve(
        'Leucócitos 15.800, neutrofilia, PCR elevada. USG inconclusiva.',
        '''
🟥 APENDICITE AGUDA
🚨 Conduta imediata:
• Considerar tomografia abdominal para melhor avaliação.
💊 Tratamento farmacológico:
• Morfina 2–4 mg IV se dor intensa persistir.
• Ceftriaxona 1 g IV + Metronidazol 500 mg IV.
🔑 Pontos-chave:
• Alta suspeita de apendicite com leucocitose e PCR elevada.
''',
      );
      expect(result.protocolId, 'apendicite_aguda');
      expect(result.protocolId, isNot('pcr_adulto'));
    });

    test('um único fármaco reconhecido preserva hierarquia single_drug', () {
      final result = resolve(
        'Apendicite aguda confirmada.',
        '''
🟥 APENDICITE AGUDA
🚨 Conduta imediata:
• Avaliação cirúrgica.
💊 Tratamento farmacológico:
• Ceftriaxona 1 g IV.
''',
      );
      expect(result.sourceType, 'single_drug');
      expect(result.protocolId, isNull);
    });

    test('PCR elevada isolada sem diagnóstico explícito nunca vincula PCR adulto', () {
      final result = resolve(
        'PCR elevada e leucocitose; USG inconclusiva.',
        'Resposta clínica geral sem diagnóstico fechado.',
      );
      expect(result.protocolId, isNull);
      expect(result.sourceType, 'general_fallback');
    });

    test('IAMCSST confirmado resolve IAM supra e não intoxicação', () {
      final result = resolve(
        'IAMCSST confirmado no ECG',
        '''
🟥 IAMCSST CONFIRMADO — ESTRATÉGIA DE REPERFUSÃO IMEDIATA
🚨 Conduta imediata:
• Preparar ICP primária.
💊 Tratamento farmacológico:
• AAS 300 mg VO.
• Ticagrelor 180 mg VO.
• Heparina não fracionada.
🚩 RED FLAGS:
• Choque cardiogênico.
''',
      );
      expect(result.protocolId, 'iam_supra');
      expect(result.protocolId, isNot('intox_organofosforados'));
    });

    test('consulta verdadeira de SCA sem supra continua resolvendo SCASST', () {
      final result = resolve(
        'Síndrome coronariana aguda sem supra de ST',
        '''
🟥 SÍNDROME CORONARIANA AGUDA SEM SUPRA
🚨 Conduta imediata:
• Estratificar risco isquêmico e realizar ECG seriado.
''',
      );
      expect(result.protocolId, 'sindrome_coronariana_sem_st');
    });

    test('consulta verdadeira de organofosforado continua resolvendo toxicologia', () {
      final result = resolve(
        'Intoxicação por organofosforados',
        '''
🟥 INTOXICAÇÃO POR ORGANOFOSFORADOS
🚨 Conduta imediata:
• Descontaminação e suporte.
💊 Tratamento farmacológico:
• Atropina e pralidoxima.
''',
      );
      expect(result.protocolId, 'intox_organofosforados');
    });

    test('parada cardiorrespiratória explícita continua resolvendo PCR adulto', () {
      final result = resolve(
        'Parada cardiorrespiratória em adulto',
        '''
🟥 PARADA CARDIORRESPIRATÓRIA — ACLS ADULTO
🚨 Conduta imediata:
• Iniciar RCP de alta qualidade e avaliar ritmo.
''',
      );
      expect(result.protocolId, 'pcr_adulto');
    });
  });
}
