import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/clinical_session_memory.dart';
import 'package:medcases/services/clinical_thread_manager.dart';

ClinicalThreadStatus classifyFollowUp({
  required String initial,
  required String followUp,
}) {
  final manager = ClinicalThreadManager();
  final first = manager.evaluate(
    currentUserText: initial,
    isPlantaoMode: true,
  );
  expect(first.action, ThreadAction.newThread);
  return manager.evaluate(
    currentUserText: followUp,
    isPlantaoMode: true,
  );
}

void expectContinuation({
  required String initial,
  required String followUp,
}) {
  final status = classifyFollowUp(initial: initial, followUp: followUp);
  expect(
    status.action,
    ThreadAction.continueThread,
    reason: 'A continuação deve preservar o thread clínico ativo.',
  );
  expect(status.reason, 'contextual_clinical_followup');
}

void main() {
  group('Plantão — continuidade contextual PT', () {
    test('mantém medicamento único ao receber peso', () {
      expectContinuation(
        initial: 'Qual a dose de noradrenalina no choque séptico?',
        followUp: 'Calcule para 80 kg.',
      );
    });

    test('mantém contexto com paciente e peso explícitos', () {
      expectContinuation(
        initial: 'Qual a dose de noradrenalina no choque séptico?',
        followUp: 'Calcule a dose para um paciente de 18 kg.',
      );
    });

    test('mantém conjunto terapêutico anterior', () {
      expectContinuation(
        initial: 'Tratamento da anafilaxia em uma criança.',
        followUp: 'Calcule as doses para 18 kg.',
      );
    });

    test('mantém contexto ao atualizar o peso', () {
      expectContinuation(
        initial: 'Dose de adrenalina intramuscular na anafilaxia pediátrica.',
        followUp: 'E para 25 kg?',
      );
    });

    test('mantém medicamento anterior no ajuste renal', () {
      expectContinuation(
        initial: 'Prescrição de vancomicina para uma infecção grave.',
        followUp: 'Creatinina 2,1 e ClCr 25. Ajuste.',
      );
    });
  });

  group('Guardia — continuidad contextual ES', () {
    test('mantiene el contexto al recibir el peso', () {
      expectContinuation(
        initial: '¿Cuál es la dosis de noradrenalina en el shock séptico?',
        followUp: 'Calcule para 80 kg.',
      );
    });

    test('mantiene el contexto con pronombre enclítico acentuado', () {
      expectContinuation(
        initial: '¿Cuál es la dosis de noradrenalina en el shock séptico?',
        followUp: 'Calcúlala para 80 kg.',
      );
    });

    test('mantiene varias dosis con pronombre enclítico plural', () {
      expectContinuation(
        initial: 'Tratamiento de la anafilaxia en una niña.',
        followUp: 'Calcúlalas para 18 kg.',
      );
    });

    test('mantiene el contexto con imperativo formal pronominal', () {
      expectContinuation(
        initial: '¿Cuál es la dosis de noradrenalina en el shock séptico?',
        followUp: 'Calcúlela para 80 kg.',
      );
    });

    test('mantiene el fármaco en ajuste renal pronominal', () {
      expectContinuation(
        initial: 'Prescripción de vancomicina para una infección grave.',
        followUp: 'Ajústala para función renal con ClCr 25.',
      );
    });

    test('mantiene el contexto al actualizar el peso', () {
      expectContinuation(
        initial: 'Dosis de adrenalina intramuscular en anafilaxia pediátrica.',
        followUp: '¿Y para 25 kg?',
      );
    });

    test('mantiene el fármaco previo en el ajuste renal', () {
      expectContinuation(
        initial: 'Prescripción de vancomicina para una infección grave.',
        followUp: 'Creatinina 2,1 y ClCr 25. Ajuste.',
      );
    });
  });

  group('isolamento e segurança', () {
    test('primeira mensagem sem contexto continua sendo novo thread', () {
      final manager = ClinicalThreadManager();
      final status = manager.evaluate(
        currentUserText: 'Calcule para 18 kg.',
        isPlantaoMode: true,
      );
      expect(status.action, ThreadAction.newThread);
      expect(status.reason, 'first_message');
    });

    test('primeira mensagem pronominal em espanhol não herda contexto', () {
      final manager = ClinicalThreadManager();
      final status = manager.evaluate(
        currentUserText: 'Calcúlala para 80 kg.',
        isPlantaoMode: true,
      );
      expect(status.action, ThreadAction.newThread);
      expect(status.reason, 'first_message');
    });

    test('mudança explícita de patologia inicia novo thread', () {
      final status = classifyFollowUp(
        initial: 'Tratamento da anafilaxia em uma criança.',
        followUp: 'Agora quero falar sobre meningite.',
      );
      expect(status.action, ThreadAction.newThread);
    });

    test('nova patologia com peso não é confundida com continuação', () {
      final status = classifyFollowUp(
        initial: 'Tratamento da anafilaxia em uma criança.',
        followUp: 'Calcule a dose para meningite em paciente de 18 kg.',
      );
      expect(status.action, ThreadAction.newThread);
    });

    test('nova patologia em espanhol mantém precedência sobre pronome', () {
      final status = classifyFollowUp(
        initial: 'Tratamiento de la anafilaxia en una niña.',
        followUp: 'Calcúlala para meningitis en una paciente de 18 kg.',
      );
      expect(status.action, ThreadAction.newThread);
    });

    test('mesma patologia explícita com peso preserva o thread', () {
      expectContinuation(
        initial: 'Tratamento da anafilaxia em uma criança.',
        followUp: 'Calcule a dose na anafilaxia para 18 kg.',
      );
    });

    test('termo clínico isolado continua iniciando novo thread', () {
      final status = classifyFollowUp(
        initial: 'Uso de sertralina na depressão.',
        followUp: 'ICC',
      );
      expect(status.action, ThreadAction.newThread);
      expect(status.reason, 'isolated_new_case_term');
    });
  });

  group('restauração e memória tipada', () {
    test('continuação após restauração preserva histórico', () {
      final manager = ClinicalThreadManager();
      manager.primeFromHistory(const [
        {'role': 'user', 'content': 'Tratamento da anafilaxia em uma criança.'},
        {'role': 'assistant', 'content': 'Adrenalina IM e medidas de suporte.'},
        {'role': 'user', 'content': 'Calcule as doses para 18 kg.'},
        {'role': 'assistant', 'content': 'Cálculo realizado para 18 kg.'},
      ]);

      final status = manager.evaluate(
        currentUserText: 'E para 25 kg?',
        isPlantaoMode: true,
      );
      expect(status.action, ThreadAction.continueThread);
      expect(status.reason, 'contextual_clinical_followup');
    });

    test('peso de continuação não apaga medicamentos tipados', () {
      final memory = ClinicalSessionMemory();
      expect(
        memory.resetIfTopicChanged('Noradrenalina no choque séptico.'),
        isFalse,
      );
      memory.addMedication('noradrenalina');

      final didReset = memory.resetIfTopicChanged(
        'Calcule a dose para um paciente de 18 kg.',
      );
      expect(didReset, isFalse);
      expect(memory.previousMeds, contains('noradrenalina'));
    });

    test('ajuste renal não apaga medicamentos tipados', () {
      final memory = ClinicalSessionMemory();
      expect(
        memory.resetIfTopicChanged('Vancomicina para infecção grave.'),
        isFalse,
      );
      memory.addMedication('vancomicina');

      final didReset = memory.resetIfTopicChanged(
        'Creatinina 2,1 e ClCr 25. Ajuste.',
      );
      expect(didReset, isFalse);
      expect(memory.previousMeds, contains('vancomicina'));
    });

    test('nova patologia continua limpando memória tipada', () {
      final memory = ClinicalSessionMemory();
      expect(
        memory.resetIfTopicChanged('Anafilaxia com adrenalina intramuscular.'),
        isFalse,
      );
      memory.addMedication('adrenalina');

      final didReset = memory.resetIfTopicChanged(
        'Agora quero falar sobre meningite bacteriana.',
      );
      expect(didReset, isTrue);
      expect(memory.previousMeds, isEmpty);
    });
  });
}
