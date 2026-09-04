import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_next_action_engine.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_continuation_type.dart';

void main() {
  test('IAMCSST confirmado avança para reperfusão, não ECG/troponina', () {
    final action = NextActionEngine.build(
      lastUserMessage: 'IAMCSST confirmado no ECG',
      lastAiResponse: '''
🟥 IAMCSST CONFIRMADO NO ECG
🚨 Conduta imediata:
• Acionar hemodinâmica imediatamente
💊 Tratamento farmacológico:
• **Aspirina 300 mg VO**
• **Ticagrelor 180 mg VO**
🔑 Pontos-chave:
• Meta: ICP em <90 min do primeiro contato médico
🚩 RED FLAGS:
• Choque cardiogênico
📌 Preparar para cateterismo imediato.
''',
      isPlantaoMode: true,
      currentLanguage: 'pt',
      chatHistory: const <String>[],
    );

    expect(action.label, 'Estratégia de reperfusão');
    expect(action.label, isNot('ECG + Troponina urgente'));
    expect(action.promptToSend, contains('Não repita ECG/troponina'));
  });

  test('IAM já terapêutico não regride para ECG e troponina', () {
    final action = NextActionEngine.build(
      lastUserMessage: 'IAM',
      lastAiResponse: '''
🟥 INFARTO AGUDO DO MIOCÁRDIO — CONDUTA IMEDIATA

Conduta imediata:
• Monitorar sinais vitais e estabilizar o paciente
• Obter acesso venoso e solicitar ECG
• Iniciar oxigenoterapia se saturação < 94%

Tratamento farmacológico:
• AAS 160 mg via oral — antiagregante
• Clopidogrel 300 mg via oral — se disponível
• Nitroglicerina 5-10 mcg/min IV — para dor torácica persistente

Pontos-chave:
• Manter equipe de suporte para intervenção
• Levar o paciente para cateterismo se indicado
• Avaliar rapidamente a gravidade do quadro

RED FLAGS:
• Deteriorização clínica ou choque
''',
      isPlantaoMode: true,
      currentLanguage: 'pt',
      chatHistory: const <String>[],
    );

    expect(action.label, 'Estratégia terapêutica e monitorização');
    expect(action.label, isNot('ECG + Troponina urgente'));
    expect(action.continuationType, PlantaoContinuationType.treatmentExpansion);
    expect(action.promptToSend, contains('Não repita ECG/troponina'));
  });

  test('IAM ainda em etapa diagnóstica parcial preserva ECG e troponina', () {
    final action = NextActionEngine.build(
      lastUserMessage: 'Iam',
      lastAiResponse: '''
🟥 IAM — INFARTO AGUDO MIOCÁRDIO
Conduta imediata:
• Realizar ECG em menos de 10 minutos
Tratamento farmacológico:
• AAS 300 mg VO
''',
      isPlantaoMode: true,
      currentLanguage: 'pt',
      chatHistory: const <String>[],
    );

    expect(action.label, 'ECG + Troponina urgente');
  });
}
