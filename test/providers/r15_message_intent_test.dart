import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/providers/app_provider.dart';
import 'package:medcases/services/clinical_thread_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppProvider provider;
  setUp(() => provider = AppProvider());
  tearDown(() => provider.dispose());
  for (final q in [
    'Paracetamol',
    'Noradrenalina',
    'Ceftriaxona',
    'Metformina',
    'Paracetamol dosis',
    'Ceftriaxona contraindicaciones',
    'Ajuste renal de metformina'
  ]) {
    test('actual provider selects drug intent: $q', () {
      expect(provider.classifyIntentForTesting(q), 'farmaco');
    });
  }
  for (final q in [
    'Intoxicação por paracetamol',
    'Sobredosis de paracetamol',
    '¿Sobredosis de paracetamol?',
    '  Intoxicação por paracetamol',
    'Paciente ingeriu 20 g de paracetamol'
  ]) {
    test('actual provider preserves toxicological context: $q', () {
      expect(provider.classifyIntentForTesting(q), 'caso_clinico');
    });
  }
  for (final q in ['Hipocalemia', 'Hipopotasemia', 'Sepse']) {
    test('actual provider retains pathology intent: $q', () {
      expect(provider.classifyIntentForTesting(q), 'tratamento');
    });
  }
  test('contextual dose is a case, not a name-only card', () {
    expect(
        provider.classifyIntentForTesting(
            'Dose de paracetamol em criança de 15 kg'),
        'caso_clinico');
  });
  test('short case retains clinical context', () {
    expect(provider.classifyIntentForTesting('Sepse no idoso com hipotensão'),
        'caso_clinico');
  });
  test('typo and ambiguous name cannot authorize a drug lookup', () {
    expect(provider.classifyIntentForTesting('Paracetamo'), 'geral');
    expect(provider.classifyIntentForTesting('Nome ambíguo'), 'geral');
  });
  test('scope-specific corrections leave Study legacy intent intact', () {
    expect(provider.classifyIntentForTesting('Paracetamol', plantao: false),
        'geral');
  });
  for (final q in [
    'E quanto ao ajuste renal?',
    '¿Y el ajuste renal?',
    'Qual o ajuste renal?',
    'Quais as interações?',
    'Como diluir?',
    '¿Cuáles son las interacciones?',
    '¿Cómo diluir?'
  ]) {
    test('actual thread manager retains follow-up: $q', () {
      final thread = ClinicalThreadManager();
      thread.evaluate(currentUserText: 'Metformina', isPlantaoMode: true);
      expect(
          thread
              .evaluate(currentUserText: q, isPlantaoMode: true)
              .isContinuation,
          isTrue);
    });
  }
  test('explicit new case and different drug do not inherit adjustment context',
      () {
    final thread = ClinicalThreadManager();
    thread.evaluate(currentUserText: 'Metformina', isPlantaoMode: true);
    expect(
        thread
            .evaluate(
                currentUserText: 'Novo caso: pneumonia', isPlantaoMode: true)
            .isContinuation,
        isFalse);
    final drugs = ClinicalThreadManager();
    drugs.evaluate(currentUserText: 'Noradrenalina', isPlantaoMode: true);
    expect(
        drugs
            .evaluate(
                currentUserText: 'Ajuste renal da ceftriaxona',
                isPlantaoMode: true)
            .isContinuation,
        isFalse);
  });
}
