import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/audio/clinical_transcript_reconciler.dart';
import 'package:medcases/services/audio/clinical_transcription_accuracy_eval.dart';

void main() {
  group('ClinicalTranscriptReconciler', () {
    test('final replaces cumulative partial without duplication', () {
      final reconciler = ClinicalTranscriptReconciler();

      reconciler.ingest(
        const ClinicalTranscriptUpdate(
          kind: ClinicalTranscriptUpdateKind.partial,
          sequence: 1,
          itemId: 'item_1',
          contentIndex: 0,
          text: 'Cef',
        ),
      );
      reconciler.ingest(
        const ClinicalTranscriptUpdate(
          kind: ClinicalTranscriptUpdateKind.partial,
          sequence: 2,
          itemId: 'item_1',
          contentIndex: 0,
          text: 'Ceftriaxona 2',
        ),
      );
      reconciler.ingest(
        const ClinicalTranscriptUpdate(
          kind: ClinicalTranscriptUpdateKind.finalResult,
          sequence: 3,
          itemId: 'item_1',
          contentIndex: 0,
          text: 'Ceftriaxona 2 g intravenosa.',
        ),
      );

      expect(
        reconciler.canonicalText,
        'Ceftriaxona 2 g intravenosa.',
      );
      expect(reconciler.segmentCount, 1);
      expect(reconciler.segments.single.isFinal, isTrue);
    });

    test('out-of-order completion preserves first-seen turn order', () {
      final reconciler = ClinicalTranscriptReconciler();

      reconciler.ingest(
        const ClinicalTranscriptUpdate(
          kind: ClinicalTranscriptUpdateKind.partial,
          sequence: 1,
          itemId: 'item_A',
          contentIndex: 0,
          text: 'Primeiro turno',
        ),
      );
      reconciler.ingest(
        const ClinicalTranscriptUpdate(
          kind: ClinicalTranscriptUpdateKind.partial,
          sequence: 2,
          itemId: 'item_B',
          contentIndex: 0,
          text: 'Segundo turno',
        ),
      );

      reconciler.ingest(
        const ClinicalTranscriptUpdate(
          kind: ClinicalTranscriptUpdateKind.finalResult,
          sequence: 3,
          itemId: 'item_B',
          contentIndex: 0,
          text: 'Segundo turno final.',
        ),
      );
      reconciler.ingest(
        const ClinicalTranscriptUpdate(
          kind: ClinicalTranscriptUpdateKind.finalResult,
          sequence: 4,
          itemId: 'item_A',
          contentIndex: 0,
          text: 'Primeiro turno final.',
        ),
      );

      expect(
        reconciler.canonicalText,
        'Primeiro turno final. Segundo turno final.',
      );
      expect(
        reconciler.segments.map((segment) => segment.itemId),
        <String>['item_A', 'item_B'],
      );
    });

    test('partial arriving after final cannot downgrade canonical text', () {
      final reconciler = ClinicalTranscriptReconciler();

      reconciler.ingest(
        const ClinicalTranscriptUpdate(
          kind: ClinicalTranscriptUpdateKind.finalResult,
          sequence: 1,
          itemId: 'item_1',
          contentIndex: 0,
          text: 'Troponina 0,08 ng/mL.',
        ),
      );
      reconciler.ingest(
        const ClinicalTranscriptUpdate(
          kind: ClinicalTranscriptUpdateKind.partial,
          sequence: 2,
          itemId: 'item_1',
          contentIndex: 0,
          text: 'Troponina',
        ),
      );

      expect(
        reconciler.canonicalText,
        'Troponina 0,08 ng/mL.',
      );
    });

    test('regressive sequence is rejected', () {
      final reconciler = ClinicalTranscriptReconciler();

      reconciler.ingest(
        const ClinicalTranscriptUpdate(
          kind: ClinicalTranscriptUpdateKind.partial,
          sequence: 2,
          itemId: 'item_1',
          contentIndex: 0,
          text: 'teste',
        ),
      );

      expect(
        () => reconciler.ingest(
          const ClinicalTranscriptUpdate(
            kind: ClinicalTranscriptUpdateKind.partial,
            sequence: 1,
            itemId: 'item_2',
            contentIndex: 0,
            text: 'regressivo',
          ),
        ),
        throwsStateError,
      );
    });
  });

  group('ClinicalTranscriptionAccuracyEvaluator', () {
    const evaluator = ClinicalTranscriptionAccuracyEvaluator();

    test('perfect PT clinical transcript scores 1.0', () {
      const casePt = ClinicalTranscriptionEvalCase(
        id: 'pt_perfect',
        locale: 'pt-BR',
        reference: 'Paciente com dispneia. Ceftriaxona 2 g intravenosa. '
            'Saturação 92%. Creatinina 1,8 mg/dL.',
        hypothesis: 'Paciente com dispneia. Ceftriaxona 2 g intravenosa. '
            'Saturação 92%. Creatinina 1,8 mg/dL.',
        medicalTerms: <String>[
          'dispneia',
          'ceftriaxona',
          'saturação',
          'creatinina',
        ],
        units: <String>['g', 'mg/dl'],
        criticalPhrases: <String>[
          'ceftriaxona 2 g',
          'creatinina 1,8 mg/dl',
        ],
      );

      final result = evaluator.evaluate(casePt);

      expect(result.wordErrorRate, 0);
      expect(result.medicalTermRecall, 1);
      expect(result.numberRecall, 1);
      expect(result.unitRecall, 1);
      expect(result.criticalPhraseRecall, 1);
      expect(result.weightedClinicalScore, 1);
      expect(result.passesStrictClinicalGate, isTrue);
    });

    test('terminal punctuation does not create false unit or phrase loss', () {
      const punctuationCase = ClinicalTranscriptionEvalCase(
        id: 'punctuation_boundary',
        locale: 'pt-BR',
        reference: 'Creatinina 1,8 mg/dL. Ceftriaxona 2 g intravenosa.',
        hypothesis: 'Creatinina 1.8 mg/dL. Ceftriaxona 2 g intravenosa.',
        medicalTerms: <String>[
          'creatinina',
          'ceftriaxona',
        ],
        units: <String>[
          'mg/dl',
          'g',
        ],
        criticalPhrases: <String>[
          'creatinina 1,8 mg/dl',
          'ceftriaxona 2 g',
        ],
      );

      final result = evaluator.evaluate(punctuationCase);

      expect(result.medicalTermRecall, 1);
      expect(result.numberRecall, 1);
      expect(result.unitRecall, 1);
      expect(result.criticalPhraseRecall, 1);
      expect(result.weightedClinicalScore, 1);
      expect(result.passesStrictClinicalGate, isTrue);
    });

    test('unit safety still distinguishes grams from milligrams', () {
      const unsafeUnitCase = ClinicalTranscriptionEvalCase(
        id: 'unit_safety_g_vs_mg',
        locale: 'pt-BR',
        reference: 'Ceftriaxona 2 g intravenosa.',
        hypothesis: 'Ceftriaxona 2 mg intravenosa.',
        medicalTerms: <String>['ceftriaxona'],
        units: <String>['g'],
        criticalPhrases: <String>['ceftriaxona 2 g'],
      );

      final result = evaluator.evaluate(unsafeUnitCase);

      expect(result.medicalTermRecall, 1);
      expect(result.numberRecall, 1);
      expect(result.unitRecall, 0);
      expect(result.criticalPhraseRecall, 0);
      expect(result.passesStrictClinicalGate, isFalse);
    });

    test('ES dosage/unit corruption is detected as clinical loss', () {
      const caseEs = ClinicalTranscriptionEvalCase(
        id: 'es_dose_error',
        locale: 'es-ES',
        reference: 'Administrar ceftriaxona 2 g intravenosa. '
            'Saturación 92%. Troponina 0,08 ng/mL.',
        hypothesis: 'Administrar ceftriaxona 2 mg intravenosa. '
            'Saturación 92%. Troponina 0,8 ng/mL.',
        medicalTerms: <String>[
          'ceftriaxona',
          'saturación',
          'troponina',
        ],
        units: <String>['g', 'ng/ml'],
        criticalPhrases: <String>[
          'ceftriaxona 2 g',
          'troponina 0,08 ng/ml',
        ],
      );

      final result = evaluator.evaluate(caseEs);

      expect(result.medicalTermRecall, 1);
      expect(result.numberRecall, lessThan(1));
      expect(result.unitRecall, lessThan(1));
      expect(result.criticalPhraseRecall, 0);
      expect(result.weightedClinicalScore, lessThan(0.95));
      expect(result.passesStrictClinicalGate, isFalse);
    });

    test('duplicate numbers use multiset recall', () {
      const caseNumbers = ClinicalTranscriptionEvalCase(
        id: 'duplicate_numbers',
        locale: 'pt-BR',
        reference: 'Pressão 120 por 80. Pulso 120.',
        hypothesis: 'Pressão 120 por 80. Pulso normal.',
      );

      final result = evaluator.evaluate(caseNumbers);

      expect(result.numberRecall, closeTo(2 / 3, 0.0001));
    });

    test('suite aggregates PT and ES cases deterministically', () {
      const cases = <ClinicalTranscriptionEvalCase>[
        ClinicalTranscriptionEvalCase(
          id: 'pt',
          locale: 'pt-BR',
          reference: 'Ceftriaxona 2 g.',
          hypothesis: 'Ceftriaxona 2 g.',
          medicalTerms: <String>['ceftriaxona'],
          units: <String>['g'],
          criticalPhrases: <String>['ceftriaxona 2 g'],
        ),
        ClinicalTranscriptionEvalCase(
          id: 'es',
          locale: 'es-ES',
          reference: 'Saturación 92%.',
          hypothesis: 'Saturación 92%.',
          medicalTerms: <String>['saturación'],
        ),
      ];

      final suite = evaluator.evaluateSuite(cases);

      expect(suite.results, hasLength(2));
      expect(suite.averageWordErrorRate, 0);
      expect(suite.averageClinicalScore, 1);
      expect(suite.strictPassCount, 2);
    });
  });

  test('new evaluation layer is offline and absent from production owners', () {
    final combined = <String>[
      File(
        'lib/services/audio/clinical_transcript_reconciler.dart',
      ).readAsStringSync(),
      File(
        'lib/services/audio/clinical_transcription_accuracy_eval.dart',
      ).readAsStringSync(),
    ].join('\n');

    for (final forbidden in <String>[
      'package:http',
      'dart:io',
      'WebSocket',
      'HttpClient',
      'Uri.parse(',
      'Authorization',
      'Bearer ',
      'Firebase',
      'api.openai.com',
    ]) {
      expect(combined, isNot(contains(forbidden)), reason: forbidden);
    }

    final main = File('lib/main.dart').readAsStringSync();
    final recorder =
        File('lib/services/clinical_recorder_service.dart').readAsStringSync();

    expect(
      main,
      isNot(contains('ClinicalTranscriptReconciler')),
    );
    expect(
      main,
      isNot(contains('ClinicalTranscriptionAccuracyEvaluator')),
    );
    expect(
      recorder,
      isNot(contains('ClinicalTranscriptReconciler')),
    );
    expect(
      recorder,
      isNot(contains('ClinicalTranscriptionAccuracyEvaluator')),
    );
  });
}
