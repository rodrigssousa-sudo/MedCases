import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_canonical_drug_evidence.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_drug_candidate_resolver.dart';

PlantaoDrugEvidenceIndexEntry entry({
  required String id,
  required String pt,
  required String es,
  List<String> keywords = const <String>[],
}) {
  return PlantaoDrugEvidenceIndexEntry(
    documentId: id,
    names: <String, String>{'pt': pt, 'es': es},
    category: 'teste',
    keywords: keywords,
    schema: PlantaoCanonicalDrugSchema.premiumV1,
    sourceModule: 'teste.js',
    hasContextVariants: false,
    contextVariantCount: 0,
    canonicalOwner: 'teste.js',
  );
}

void main() {
  const resolver = PlantaoDrugCandidateResolver();

  test('exact ID has priority and returns one typed identity candidate', () {
    final result = resolver.resolve(
      term: 'furosemida',
      languageCode: 'pt',
      entries: <PlantaoDrugEvidenceIndexEntry>[
        entry(
          id: 'furosemida',
          pt: 'Furosemida',
          es: 'Furosemida',
          keywords: const <String>['furosemida'],
        ),
      ],
    );
    expect(result.status, PlantaoDrugCandidateResolutionStatus.matched);
    expect(result.candidates.single.documentId, 'furosemida');
    expect(
      result.candidates.single.matchKind,
      PlantaoDrugIdentityMatchKind.exactId,
    );
  });

  test('accent-insensitive Spanish name resolves deterministically', () {
    final result = resolver.resolve(
      term: 'acetaminofen',
      languageCode: 'es',
      entries: <PlantaoDrugEvidenceIndexEntry>[
        entry(
          id: 'paracetamol',
          pt: 'Paracetamol',
          es: 'Paracetamol / Acetaminofén',
          keywords: const <String>['paracetamol'],
        ),
      ],
    );
    expect(result.hasSingleMatch, isTrue);
    expect(result.candidates.single.documentId, 'paracetamol');
  });

  test('duplicate exact alias is ambiguous and never auto-merged', () {
    final result = resolver.resolve(
      term: 'droga compartilhada',
      languageCode: 'pt',
      entries: <PlantaoDrugEvidenceIndexEntry>[
        entry(
          id: 'droga_a',
          pt: 'Droga A',
          es: 'Droga A',
          keywords: const <String>['droga compartilhada'],
        ),
        entry(
          id: 'droga_b',
          pt: 'Droga B',
          es: 'Droga B',
          keywords: const <String>['droga compartilhada'],
        ),
      ],
    );
    expect(result.status, PlantaoDrugCandidateResolutionStatus.ambiguous);
    expect(result.candidates, hasLength(2));
  });

  test('free sentence is not mined for a medication name', () {
    final result = resolver.resolve(
      term: 'qual a dose de furosemida',
      languageCode: 'pt',
      entries: <PlantaoDrugEvidenceIndexEntry>[
        entry(
          id: 'furosemida',
          pt: 'Furosemida',
          es: 'Furosemida',
          keywords: const <String>['furosemida'],
        ),
      ],
    );
    expect(result.status, PlantaoDrugCandidateResolutionStatus.notFound);
  });
}
