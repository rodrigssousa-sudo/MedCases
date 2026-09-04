import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/tep_2026_plantao_response_guard.dart';

String _guard(String input, {String lang = 'es', String raw = 'RAW_MODEL'}) {
  return Tep2026PlantaoResponseGuard.materialize(
    userInput: input,
    assistantOutput: raw,
    languageCode: lang,
  );
}

void main() {
  group('TEP 2026 Plantão physical runtime compliance guard V1-B-R0', () {
    test('B1 is deterministic and removes unsafe model plan', () {
      const input =
          'Paciente de 42 anos, TEP agudo confirmado por angioTC, sintomático, '
          'com embolia subsegmentar isolada. PA 124/76 mmHg, FC 82 bpm, '
          'FR 18/min, SpO2 96% em ar ambiente. sPESI = 0. '
          'Ecocardiograma sem disfunção de VD, troponina e BNP normais, '
          'lactato 1,2 mmol/L. Sem sinais de hipoperfusão. '
          'Doppler de membros inferiores sem TVP proximal.';

      final out = _guard(
        input,
        raw:
            'TEP bajo riesgo. HNF 80 U/kg + 18 U/kg/h. Evaluar trombólisis si empeora.',
      );

      expect(out, contains('TEP AGUDO CONFIRMADO — B1'));
      expect(out, contains('Categoría AHA/ACC 2026: **B1**'));
      expect(out, contains('TEP subsegmentario sintomático'));
      expect(out, contains('HBPM sobre HNF'));
      expect(out, contains('DOAC sobre AVK'));
      expect(out, contains('NO realizar trombólisis'));
      expect(out, isNot(contains('80 U/kg')));
      expect(out, isNot(contains('18 U/kg/h')));
      expect(
        out,
        isNot(contains('Ingresar en unidad de cuidados intermedios')),
      );
    });

    test('C2 rejects routine systemic thrombolysis', () {
      const input =
          'Paciente de 67 anos com TEP agudo confirmado por angioTC. '
          'PA 118/72 mmHg, FC 116 bpm, FR 24/min, SpO2 94% em ar ambiente. '
          'sPESI = 1. Ecocardiograma mostra dilatação/disfunção do ventrículo '
          'direito. Troponina e BNP normais. Lactato 1,5 mmol/L, função renal '
          'preservada, sem alteração do sensório e sem outros sinais de hipoperfusão.';

      final out = _guard(input);
      expect(out, contains('TEP AGUDO CONFIRMADO — C2'));
      expect(out, contains('Categoría AHA/ACC 2026: **C2**'));
      expect(out, contains('NO usar trombólisis sistémica de rutina'));
      expect(out, contains('Hospitalizar'));
    });

    test('C3 receives R for hypoxemia/tachypnea/oxygen', () {
      const input =
          'Paciente de 71 anos com TEP agudo confirmado. PA 112/70 mmHg, '
          'FC 118 bpm, FR 34/min, SpO2 86% em ar ambiente, necessitando '
          'oxigênio suplementar. sPESI elevado. AngioTC/eco mostram disfunção '
          'de VD. Troponina elevada e BNP elevado. Lactato 1,6 mmol/L, '
          'diurese preservada, função renal preservada, sensório normal, '
          'sem sinais de hipoperfusão.';

      final out = _guard(input);
      expect(out, contains('TEP AGUDO CONFIRMADO — C3R'));
      expect(out, contains('| Categoría / resultado final | **C3R** |'));
      expect(out, contains('Modificador **R** presente'));
      expect(out, contains('beneficio de trombólisis sistémica'));
      expect(out, contains('incierto'));
    });

    test('D2 is recognized by objective hypoperfusion despite preserved BP', () {
      const input =
          'Paciente com TEP agudo confirmado. PA 112/72 mmHg, lactato 3,2 mmol/L, '
          'diurese 0,3 mL/kg/h, sensório preservado. sPESI = 1. '
          'Sem hipotensão persistente.';

      final out = _guard(input);
      expect(out, contains('TEP AGUDO CONFIRMADO — D2'));
      expect(out, contains('shock normotensivo/hipoperfusión'));
      expect(out, contains('PAS preservada **NO excluye D2**'));
    });

    test('E1 is recognized by cardiogenic shock with persistent hypotension', () {
      const input =
          'Paciente com TEP agudo confirmado. Mantém PAS 78/50 mmHg apesar das '
          'medidas iniciais, com choque cardiogênico. Sem parada cardíaca.';

      final out = _guard(input);
      expect(out, contains('TEP AGUDO CONFIRMADO — E1'));
      expect(out, contains('shock cardiogénico'));
      expect(out, contains('opciones razonables'));
    });

    test('E2 is recognized by refractory cardiogenic shock/arrest', () {
      const input =
          'Paciente com TEP agudo confirmado em choque cardiogênico refratário '
          'e parada cardíaca, em reanimação.';

      final out = _guard(input);
      expect(out, contains('TEP AGUDO CONFIRMADO — E2'));
      expect(out, contains('VA-ECMO'));
      expect(out, contains('trombólisis sistémica puede ser razonable'));
    });

    test(
      'suspected PE remains model-owned and Wells diagnostic lane is untouched',
      () {
        const input =
            'Suspeita de TEP. Calcule Wells e defina estratégia diagnóstica.';
        const raw = 'RAW_DIAGNOSTIC_WELLS';
        expect(_guard(input, raw: raw), raw);
      },
    );

    test(
      'confirmed PE with insufficient classification data is fail-closed',
      () {
        const input = 'TEP agudo confirmado. Qual a conduta?';
        const raw = 'RAW_NEEDS_MORE_DATA';
        expect(_guard(input, raw: raw), raw);
      },
    );

    test('PT rendering is supported', () {
      const input =
          'TEP agudo confirmado, sintomático, subsegmentar isolado, sPESI = 0, '
          'sem disfunção de VD, troponina e BNP normais, lactato 1,2 mmol/L.';
      final out = _guard(input, lang: 'pt');
      expect(out, contains('TEP AGUDO CONFIRMADO — B1'));
      expect(out, contains('Categoria AHA/ACC 2026: **B1**'));
      expect(out, contains('NÃO realizar trombólise'));
    });

    test('materialization is idempotent for resolved category', () {
      const input =
          'TEP agudo confirmado, sintomático, subsegmentar isolado, sPESI = 0, '
          'sem disfunção de VD, troponina e BNP normais, lactato 1,2 mmol/L.';
      final first = _guard(input);
      final second = _guard(input, raw: first);
      expect(second, first);
    });
    test(
      'classification-only follow-up reuses prior USER case and answers B1 directly',
      () {
        const priorUserCase =
            'Paciente de 42 anos, TEP agudo confirmado por angioTC, sintomático, '
            'com embolia subsegmentar isolada. PA 124/76 mmHg, FC 82 bpm, '
            'FR 18/min, SpO2 96% em ar ambiente. sPESI = 0. '
            'Ecocardiograma sem disfunção de VD, troponina e BNP normais, '
            'lactato 1,2 mmol/L. Sem sinais de hipoperfusão. '
            'Doppler de membros inferiores sem TVP proximal.';

        final out = Tep2026PlantaoResponseGuard.materialize(
          userInput: '¿Y cuál es la clasificación?',
          assistantOutput:
              'Clasificar TEP según AHA/ACC 2026: A, B1/B2, C1/C2/C3, D1/D2, E1/E2.',
          languageCode: 'es',
          recentUserTurns: const [priorUserCase],
        );

        expect(out, contains('TEP AGUDO CONFIRMADO — B1'));
        expect(out, contains('Clasificación AHA/ACC 2026:'));
        expect(out, contains('**B1**'));
        expect(out, contains('Categoría final: **B1**'));
        expect(out, isNot(contains('Conducta inmediata')));
        expect(out, isNot(contains('Realizar angioTC')));
        expect(out, isNot(contains('A, B1/B2, C1/C2/C3')));
      },
    );

    test(
      'classification follow-up resolves D2 from prior USER case, not assistant text',
      () {
        const priorUserCase =
            'Paciente com TEP agudo confirmado. PA 116/74 mmHg, '
            'lactato 3,8 mmol/L, diurese 0,3 mL/kg/h, extremidades frias, '
            'sem PAS abaixo de 90 mmHg.';

        final out = Tep2026PlantaoResponseGuard.materialize(
          userInput: 'qual a classificação?',
          assistantOutput: 'Categoria C3 por estar normotenso.',
          languageCode: 'pt',
          recentUserTurns: const [priorUserCase],
        );

        expect(out, contains('TEP AGUDO CONFIRMADO — D2'));
        expect(out, contains('Classificação AHA/ACC 2026:'));
        expect(out, contains('Categoria final: **D2**'));
        expect(out, contains('Choque normotensivo/hipoperfusão'));
        expect(out, isNot(contains('Categoria C3')));
      },
    );

    test(
      'classification follow-up without resolvable USER context does not invent category',
      () {
        const raw = 'Preciso dos dados clínicos para classificar.';
        final out = Tep2026PlantaoResponseGuard.materialize(
          userInput: 'qual a classificação?',
          assistantOutput: raw,
          languageCode: 'pt',
          recentUserTurns: const [
            'Paciente com dor torácica inespecífica, diagnóstico ainda não confirmado.',
          ],
        );

        expect(out, raw);
      },
    );

    test(
      'full classify plus management request still gets complete management renderer',
      () {
        const input =
            'TEP agudo confirmado, sintomático, subsegmentar isolado, '
            'sPESI = 0, sem disfunção de VD, troponina e BNP normais, '
            'lactato 1,2 mmol/L. Classifique e indique a conduta.';

        final out = Tep2026PlantaoResponseGuard.materialize(
          userInput: input,
          assistantOutput: 'RAW_MODEL',
          languageCode: 'pt',
        );

        expect(out, contains('TEP AGUDO CONFIRMADO — B1'));
        expect(out, contains('Conduta imediata:'));
        expect(out, contains('NÃO realizar trombólise'));
      },
    );
  });
}
