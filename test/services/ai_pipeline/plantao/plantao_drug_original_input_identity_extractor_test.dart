import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_canonical_drug_evidence.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_drug_original_input_identity_extractor.dart';

PlantaoDrugEvidenceIndexEntry entry({
  required String id,
  required String pt,
  required String es,
  List<String> keywords = const <String>[],
  bool hasContextVariants = false,
}) {
  return PlantaoDrugEvidenceIndexEntry(
    documentId: id,
    names: <String, String>{'pt': pt, 'es': es},
    category: 'teste',
    keywords: keywords,
    schema: PlantaoCanonicalDrugSchema.premiumV1,
    sourceModule: 'teste.js',
    hasContextVariants: hasContextVariants,
    contextVariantCount: hasContextVariants ? 1 : 0,
    canonicalOwner: 'teste.js',
  );
}

void main() {
  const extractor = PlantaoDrugOriginalInputIdentityExtractor();

  test('resolves exact canonical name from the original question', () {
    final result = extractor.extract(
      originalUserInput: 'Qual a dose da furosemida?',
      languageCode: 'pt',
      intent: PlantaoDrugOriginalInputIntent.dosage,
      entries: <PlantaoDrugEvidenceIndexEntry>[
        entry(
          id: 'furosemida',
          pt: 'Furosemida',
          es: 'Furosemida',
          keywords: const <String>['furosemida', 'lasix'],
        ),
      ],
    );

    expect(result.isMatched, isTrue);
    expect(result.candidates.single.documentId, 'furosemida');
  });

  test('resolves a safe brand alias but ignores descriptive keywords', () {
    final result = extractor.extract(
      originalUserInput: 'Qual a dose do Lasix?',
      languageCode: 'pt',
      intent: PlantaoDrugOriginalInputIntent.dosage,
      entries: <PlantaoDrugEvidenceIndexEntry>[
        entry(
          id: 'furosemida',
          pt: 'Furosemida',
          es: 'Furosemida',
          keywords: const <String>[
            'lasix',
            'diuretico de alca potente para congestao',
          ],
        ),
      ],
    );

    expect(result.isMatched, isTrue);
    expect(result.candidates.single.matchedValue, 'lasix');

    final descriptor = extractor.extract(
      originalUserInput: 'Qual a dose do diurético de alça potente?',
      languageCode: 'pt',
      intent: PlantaoDrugOriginalInputIntent.dosage,
      entries: <PlantaoDrugEvidenceIndexEntry>[
        entry(
          id: 'furosemida',
          pt: 'Furosemida',
          es: 'Furosemida',
          keywords: const <String>[
            'lasix',
            'diuretico de alca potente para congestao',
          ],
        ),
      ],
    );
    expect(descriptor.status, PlantaoDrugOriginalInputExtractionStatus.empty);
  });

  test(
    'parenthetical abbreviation resolves AAS without short-keyword mining',
    () {
      final result = extractor.extract(
        originalUserInput: 'Qual a dose de AAS?',
        languageCode: 'pt',
        intent: PlantaoDrugOriginalInputIntent.dosage,
        entries: <PlantaoDrugEvidenceIndexEntry>[
          entry(
            id: 'aas_antiagregante',
            pt: 'Ácido Acetilsalicílico (AAS)',
            es: 'Ácido Acetilsalicílico (AAS)',
            keywords: const <String>['aas_antiagregante'],
          ),
        ],
      );

      expect(result.isMatched, isTrue);
      expect(result.candidates.single.documentId, 'aas_antiagregante');
    },
  );

  test('interaction requires exactly two canonical identities', () {
    final entries = <PlantaoDrugEvidenceIndexEntry>[
      entry(id: 'furosemida', pt: 'Furosemida', es: 'Furosemida'),
      entry(
        id: 'espironolactona',
        pt: 'Espironolactona',
        es: 'Espironolactona',
      ),
    ];

    final complete = extractor.extract(
      originalUserInput: 'Existe interação entre furosemida e espironolactona?',
      languageCode: 'pt',
      intent: PlantaoDrugOriginalInputIntent.interaction,
      entries: entries,
    );
    expect(complete.isMatched, isTrue);
    expect(complete.candidates, hasLength(2));

    final incomplete = extractor.extract(
      originalUserInput: 'Existe interação com furosemida?',
      languageCode: 'pt',
      intent: PlantaoDrugOriginalInputIntent.interaction,
      entries: entries,
    );
    expect(
      incomplete.status,
      PlantaoDrugOriginalInputExtractionStatus.ambiguous,
    );
  });

  test('intent none embargoes drug identity extraction', () {
    final result = extractor.extract(
      originalUserInput: 'Paciente usa furosemida. Analise o caso.',
      languageCode: 'pt',
      intent: PlantaoDrugOriginalInputIntent.none,
      entries: <PlantaoDrugEvidenceIndexEntry>[
        entry(id: 'furosemida', pt: 'Furosemida', es: 'Furosemida'),
      ],
    );

    expect(
      result.status,
      PlantaoDrugOriginalInputExtractionStatus.notEvaluated,
    );
    expect(result.candidates, isEmpty);
  });
}
