import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_drug_original_input_identity_extractor.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_drug_original_input_intent_resolver.dart';

void main() {
  const resolver = PlantaoDrugOriginalInputIntentResolver();

  test('interaction intent has priority', () {
    expect(
      resolver.resolve(
        originalUserInput: 'Interação entre furosemida e espironolactona',
        legacyQueryIntent: 'interacao',
        legacyDirectQuery: true,
      ),
      PlantaoDrugOriginalInputIntent.interaction,
    );
  });

  test('dose, dilution and infusion are distinguished', () {
    expect(
      resolver.resolve(
        originalUserInput: 'Qual a dose da ceftriaxona?',
        legacyQueryIntent: 'farmaco',
        legacyDirectQuery: true,
      ),
      PlantaoDrugOriginalInputIntent.dosage,
    );
    expect(
      resolver.resolve(
        originalUserInput: 'Como diluir ceftriaxona?',
        legacyQueryIntent: 'farmaco',
        legacyDirectQuery: true,
      ),
      PlantaoDrugOriginalInputIntent.dilution,
    );
    expect(
      resolver.resolve(
        originalUserInput: 'Velocidade de infusão de noradrenalina',
        legacyQueryIntent: 'farmaco',
        legacyDirectQuery: true,
      ),
      PlantaoDrugOriginalInputIntent.infusion,
    );
    expect(
      resolver.resolve(
        originalUserInput: '¿Cómo reconstituir ceftriaxona?',
        legacyQueryIntent: 'farmaco',
        legacyDirectQuery: true,
      ),
      PlantaoDrugOriginalInputIntent.dilution,
    );
  });

  test('single canonical candidate permits index verification', () {
    expect(
      resolver.resolve(
        originalUserInput: 'furosemida',
        legacyQueryIntent: 'geral',
        legacyDirectQuery: false,
      ),
      PlantaoDrugOriginalInputIntent.drugInformation,
    );
  });

  test('long clinical question without pharmacology cue remains none', () {
    expect(
      resolver.resolve(
        originalUserInput:
            'Paciente com dispneia progressiva e edema de membros inferiores',
        legacyQueryIntent: 'caso_clinico',
        legacyDirectQuery: false,
      ),
      PlantaoDrugOriginalInputIntent.none,
    );
  });
}
