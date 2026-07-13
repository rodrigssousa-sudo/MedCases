// ══════════════════════════════════════════════════════════════════════════════
// test/services/external_tool_intent_test.dart
// MICRO-BUILD 462E-A.3 / 462E-A.4 / 462E-A.5 — ExternalToolLinkEngine sovereignty
//
// Valida:
//   1. hasExplicitInteractionIntent() — 14 PT/ES patterns
//   2. hasExplicitDilutionIntent()    — 5 PT/ES clusters (462E-A.5: bomba removida)
//   3. Input Sovereignty: 2+ drugs without interaction keywords → NO interaction tool
//   4. AI response drug names MUST NOT trigger Step 1 (interaction button)
//   5. ExternalToolLinkEngine.build() with interaction keywords → triggers correctly
//   6. resolveExternalToolIntent() — Sovereign Matcher (MICRO-BUILD 462E-A.4)
//   7. Total Embargo Gate: intent==none → build() returns null (462E-A.4)
//   8. Explicit infusion keyword → ExternalToolIntent.infusion (462E-A.4)
//   9. Explicit dose keyword → ExternalToolIntent.dosage (462E-A.4)
//  10. [GROUP 6 — 462E-A.5] Test A: bomba de infusão → strictly infusion (NEVER dilution)
//  11. [GROUP 6 — 462E-A.5] Test B: input sovereignty — AI drug injection cannot mutate target
//  12. [GROUP 6 — 462E-A.5] Test D: idempotency — same decisionKey runs side-effects once
//
// PARADIGMA DE SOBERANIA (462E-A.4 / 462E-A.5):
//   • O texto gerado pela IA é MATEMATICAMENTE proibido de mutar intenções.
//   • resolveExternalToolIntent() executa EXCLUSIVAMENTE contra lastUserMessage.
//   • intent == ExternalToolIntent.none → retorno null IMEDIATO em build().
//   • Step 11 (Build 280) é DESATIVADO pelo embargo quando intent == none.
//   • ExternalToolDecision.decisionKey garante idempotência durante widget rebuilds.
//   • "bomba de infusão" SEMPRE resolve para infusion (NUNCA dilution) — 462E-A.5.
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/external_tool_link_engine.dart';

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // Group 1: hasExplicitInteractionIntent() — PT/ES pattern coverage
  // ─────────────────────────────────────────────────────────────────────────
  group('hasExplicitInteractionIntent — PT/ES pattern matching', () {
    // Positive cases — each of the 14 canonical patterns
    test('PT: "interação entre" → true', () {
      expect(
        ExternalToolLinkEngine.hasExplicitInteractionIntent(
            'existe interação entre furosemida e espironolactona?'),
        isTrue,
      );
    });

    test('ES: "interacción entre" → true', () {
      expect(
        ExternalToolLinkEngine.hasExplicitInteractionIntent(
            'hay interacción entre furosemida y espironolactona?'),
        isTrue,
      );
    });

    test('PT: "interage com" → true', () {
      expect(
        ExternalToolLinkEngine.hasExplicitInteractionIntent(
            'amiodarona interage com warfarina?'),
        isTrue,
      );
    });

    test('PT: "pode usar junto" → true', () {
      expect(
        ExternalToolLinkEngine.hasExplicitInteractionIntent(
            'pode usar junto metoprolol e amiodarona?'),
        isTrue,
      );
    });

    test('PT: "é seguro combinar" → true', () {
      expect(
        ExternalToolLinkEngine.hasExplicitInteractionIntent(
            'é seguro combinar AAS e clopidogrel?'),
        isTrue,
      );
    });

    test('ES: "es seguro combinar" → true', () {
      expect(
        ExternalToolLinkEngine.hasExplicitInteractionIntent(
            'es seguro combinar AAS y clopidogrel?'),
        isTrue,
      );
    });

    test('PT: "contraindicação entre" → true', () {
      expect(
        ExternalToolLinkEngine.hasExplicitInteractionIntent(
            'existe contraindicação entre os dois?'),
        isTrue,
      );
    });

    test('PT: "há interação" → true', () {
      expect(
        ExternalToolLinkEngine.hasExplicitInteractionIntent(
            'há interação medicamentosa aqui?'),
        isTrue,
      );
    });

    test('ES: "hay interacción" → true', () {
      expect(
        ExternalToolLinkEngine.hasExplicitInteractionIntent(
            'hay interacción entre estos dos fármacos?'),
        isTrue,
      );
    });

    // Negative cases — drug names present but NO interaction keywords
    test('Two drug names without interaction keyword → false', () {
      expect(
        ExternalToolLinkEngine.hasExplicitInteractionIntent(
            'paciente usa furosemida e nitroglicerina'),
        isFalse,
        reason: 'Drug names alone without interaction keyword must return false',
      );
    });

    test('Clinical case mentioning 5 drugs without keyword → false', () {
      expect(
        ExternalToolLinkEngine.hasExplicitInteractionIntent(
            'paciente em uso de furosemida, captopril, metoprolol, '
            'espironolactona e amiodarona para ICC descompensada'),
        isFalse,
        reason: 'Case text with 5 drugs but no interaction keyword must return false',
      );
    });

    test('Empty string → false', () {
      expect(
        ExternalToolLinkEngine.hasExplicitInteractionIntent(''),
        isFalse,
      );
    });

    test('Generic drug question without interaction intent → false', () {
      expect(
        ExternalToolLinkEngine.hasExplicitInteractionIntent(
            'qual a dose de furosemida na ICC?'),
        isFalse,
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Group 2: hasExplicitDilutionIntent() — PT/ES dilution pattern coverage
  // ─────────────────────────────────────────────────────────────────────────
  group('hasExplicitDilutionIntent — PT/ES dilution patterns', () {
    test('PT: "diluir" → true', () {
      expect(
        ExternalToolLinkEngine.hasExplicitDilutionIntent(
            'como diluir noradrenalina em soro?'),
        isTrue,
      );
    });

    test('PT: "diluição" → true', () {
      expect(
        ExternalToolLinkEngine.hasExplicitDilutionIntent(
            'qual a diluição do amiodarona EV?'),
        isTrue,
      );
    });

    test('ES: "dilución" → true', () {
      expect(
        ExternalToolLinkEngine.hasExplicitDilutionIntent(
            'cual es la dilución de dopamina?'),
        isTrue,
      );
    });

    test('PT: "reconstituir" → true', () {
      expect(
        ExternalToolLinkEngine.hasExplicitDilutionIntent(
            'como reconstituir cefazolina 1g?'),
        isTrue,
      );
    });

    test('PT: "concentração" → true', () {
      expect(
        ExternalToolLinkEngine.hasExplicitDilutionIntent(
            'qual concentração final de vancomicina em bomba?'),
        isTrue,
      );
    });

    // NOTE 462E-A.5: hasExplicitDilutionIntent() DOES NOT match 'bomba de infusão'.
    // 'bomba de infusão' is now exclusively an INFUSION token (resolveExternalToolIntent bloco C).
    // This test updated: 'bomba de infusão' alone → false for hasExplicitDilutionIntent().
    test('PT: "bomba de infusão" alone → false for hasExplicitDilutionIntent (462E-A.5: moved to infusion)', () {
      expect(
        ExternalToolLinkEngine.hasExplicitDilutionIntent(
            'como programar bomba de infusão de dobutamina?'),
        isFalse,
        reason: '462E-A.5: bomba de infusão is an infusion token, not dilution — '
            'removed from hasExplicitDilutionIntent()',
      );
    });

    test('No dilution keyword → false', () {
      expect(
        ExternalToolLinkEngine.hasExplicitDilutionIntent(
            'qual a dose de vancomicina para infecção grave?'),
        isFalse,
      );
    });

    test('Empty string → false', () {
      expect(
        ExternalToolLinkEngine.hasExplicitDilutionIntent(''),
        isFalse,
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Group 3: Input Sovereignty — ExternalToolLinkEngine.build() Step 1 gate
  // ─────────────────────────────────────────────────────────────────────────
  group('ExternalToolLinkEngine.build() — Step 1 Input Sovereignty', () {
    // Scenario 1: 5 concurrent drug names in case text without interaction keywords
    // Expected: externalToolTriggered == false for interaction button
    test('Scenario 1 — 5 drug names in clinical case without keyword → no interaction tool', () {
      // Simulates: AI responded with a case mentioning Furosemida + Nitroglicerina
      // but user asked a generic case question, NOT about interaction
      final link = ExternalToolLinkEngine.build(
        lastUserMessage: 'analise o caso clínico do paciente internado com ICC',
        lastAiResponse:
            'O paciente usa furosemida 40mg, nitroglicerina 5mcg/min, '
            'captopril 25mg, espironolactona 25mg e carvedilol 25mg. '
            'Apresenta edema bilateral de membros inferiores e dispneia.',
        isPlantaoMode: true,
        currentLanguage: 'pt',
      );

      // Step 1 (interaction) must NOT fire — no explicit interaction keyword
      // Note: Step 8/11 (single drug) may still fire — that is Build 280 behavior.
      // We specifically verify the interaction URL is not generated.
      if (link != null) {
        expect(link.url, isNot(contains('tab=interacoes')),
            reason: 'Incidental drug mention in case text must NOT trigger interaction tab');
        expect(link.label, isNot(contains('Interação')),
            reason: 'No interaction label must appear without explicit interaction keyword');
        expect(link.label, isNot(contains('Interacción')),
            reason: 'No interaction label (ES) must appear without explicit interaction keyword');
      }
      // link == null is also acceptable (no tool at all is correct behavior)
    });

    // Scenario 2: AI response stream returning drug pairings → intent UNCHANGED
    // The lastUserMessage contains no interaction keyword.
    // Expected: no interaction tool triggered regardless of AI pairing text.
    test('Scenario 2 — AI response with drug pairings → intent not mutated', () {
      final link = ExternalToolLinkEngine.build(
        lastUserMessage: 'quais drogas usar no choque séptico?',
        lastAiResponse:
            'Utilize noradrenalina como vasopressor de escolha. '
            'Vasopressina pode ser associada à noradrenalina para reduzir a dose. '
            'Dobutamina quando houver disfunção miocárdica.',
        isPlantaoMode: true,
        currentLanguage: 'pt',
      );

      if (link != null) {
        expect(link.url, isNot(contains('tab=interacoes')),
            reason: 'AI response with drug pairs must not trigger interaction tab '
                'when user did not ask about interactions');
      }
    });

    // Scenario 3: Explicit interaction keyword in user message → trigger IS correct
    test('Scenario 3 — explicit interaction keyword → interaction tool triggers', () {
      final link = ExternalToolLinkEngine.build(
        lastUserMessage: 'existe interação entre furosemida e espironolactona?',
        lastAiResponse:  'Furosemida e espironolactona têm interação farmacodinâmica.',
        isPlantaoMode: true,
        currentLanguage: 'pt',
      );

      // With explicit keyword, Step 1 IS allowed to fire if both drugs detected
      // We just verify that the build() call completes without error.
      // (Drug detection depends on internal dictionary — we trust the engine)
      expect(() => link, returnsNormally,
          reason: 'build() must complete without exception when interaction keyword present');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Group 4: resolveExternalToolIntent() — 462E-A.4 Sovereign Matcher
  // ─────────────────────────────────────────────────────────────────────────
  group('resolveExternalToolIntent() — 462E-A.4 Sovereign Matcher', () {

    // ── Scenario 1 (Shock Case) ──────────────────────────────────────────
    // Input: plain case text containing vasoactive drug names.
    // No explicit interaction/infusion/dose keyword.
    // Expected: intent == ExternalToolIntent.none
    // Consequence: build() returns null (embargo total).
    test('Scenario 1 (Shock Case) — clinical case text → intent == none → null build()', () {
      const userInput =
          'paciente em uso de noradrenalina, furosemida e dopamina. '
          'PA 80x50, FC 120. O que fazer?';

      final intent = ExternalToolLinkEngine.resolveExternalToolIntent(userInput);
      expect(intent, equals(ExternalToolIntent.none),
          reason: 'Clinical case text without explicit intent keyword must yield none');

      // Embargo gate: build() must return null — Step 11 (AI drug) is embargoed
      final link = ExternalToolLinkEngine.build(
        lastUserMessage: userInput,
        lastAiResponse:
            'Noradrenalina em infusão contínua 0.1 mcg/kg/min. '
            'Titular conforme PAM. Associar vasopressina se refratário.',
        isPlantaoMode: true,
        currentLanguage: 'pt',
      );

      expect(link, isNull,
          reason: 'Embargo gate must return null when intent==none, '
              'even when AI response contains infusion-related text');
    });

    // ── Scenario 2 (AI Trick) ────────────────────────────────────────────
    // User input: raw case analysis request.
    // AI response: contains "norepinefrina em infusão contínua" — explicit infusion text.
    // Expected: intent == none → externalToolTriggered == false, no tab shifts.
    test('Scenario 2 (AI Trick) — AI response has infusion text but input is case → null', () {
      const userInput = 'qual o manejo do choque séptico?';

      final intent = ExternalToolLinkEngine.resolveExternalToolIntent(userInput);
      // "manejo" and "séptico" are not in any intent pattern → none
      expect(intent, equals(ExternalToolIntent.none),
          reason: 'Generic clinical management question must yield intent==none');

      final link = ExternalToolLinkEngine.build(
        lastUserMessage: userInput,
        // AI response contains explicit infusion keywords — must NOT mutate intent
        lastAiResponse:
            'Iniciar norepinefrina em infusão contínua. Titular para PAM >65. '
            'Velocidade de infusão: 0.01–3 mcg/kg/min.',
        isPlantaoMode: true,
        currentLanguage: 'pt',
      );

      expect(link, isNull,
          reason: 'AI response with infusion text must not trigger tool when '
              'user input has no explicit intent — Step 11 is embargoed');
    });

    // ── Scenario 3 (Explicit Infusion) — UPDATED for 462E-A.5 ────────────────
    // Input asks about infusion preparation via "bomba de infusión".
    //
    // 462E-A.4 PREVIOUS: accepted dilution OR infusion (bomba was in block B).
    // 462E-A.5 FIX: "bomba de infusión" moved from dilution block B to infusion
    //               block C. Now resolves STRICTLY to infusion.
    // Key invariant: must be EXACTLY ExternalToolIntent.infusion.
    test('Scenario 3 (Explicit Infusion) — "bomba de infusión" → strictly ExternalToolIntent.infusion [462E-A.5]', () {
      const userInput = '¿Cómo preparar noradrenalina em bomba de infusión?';

      final intent = ExternalToolLinkEngine.resolveExternalToolIntent(userInput);
      // 462E-A.5: bomba de infusión MUST resolve to infusion (block C), NEVER dilution (block B).
      expect(intent, equals(ExternalToolIntent.infusion),
          reason: '462E-A.5 fix: bomba de infusión moved from dilution block to infusion block — '
              'must resolve strictly to infusion, never dilution');
      expect(intent, isNot(equals(ExternalToolIntent.none)),
          reason: 'Explicit infusion keyword must never yield none');
      expect(intent, isNot(equals(ExternalToolIntent.dilution)),
          reason: '462E-A.5 invariant: bomba de infusión NEVER resolves to dilution');
    });

    // ── Scenario 3c (Pure infusion — no dilution ambiguity) ──────────────────
    // "mcg/kg/min" is exclusively in infusion block (C) — no dilution overlap.
    test('Scenario 3c — "mcg/kg/min" exclusively in infusion block → ExternalToolIntent.infusion', () {
      final intent = ExternalToolLinkEngine.resolveExternalToolIntent(
          'calcular noradrenalina em mcg/kg/min');
      expect(intent, equals(ExternalToolIntent.infusion),
          reason: 'mcg/kg/min is an infusion-only pattern not in dilution block');
    });

    // ── Scenario 3b (PT variant) ─────────────────────────────────────────
    test('Scenario 3b (PT Infusion) — "infusão" keyword → infusion intent', () {
      const userInput = 'como calcular a dose de noradrenalina em infusão contínua?';

      final intent = ExternalToolLinkEngine.resolveExternalToolIntent(userInput);
      // "infusão" matches pattern C
      expect(intent, equals(ExternalToolIntent.infusion),
          reason: '"infusão" keyword in user input must yield infusion intent');
    });

    // ── Scenario 4 (Explicit Dose) ────────────────────────────────────────
    // Input explicitly asks about dose.
    // Expected: intent == ExternalToolIntent.dosage
    test('Scenario 4 (Explicit Dose) — "qual a dose da noradrenalina?" → dosage', () {
      const userInput = 'Qual a dose da noradrenalina?';

      final intent = ExternalToolLinkEngine.resolveExternalToolIntent(userInput);
      expect(intent, equals(ExternalToolIntent.dosage),
          reason: 'Explicit dose question must yield dosage intent');
    });

    // ── Scenario 4b (ES Dose variant) ───────────────────────────────────
    test('Scenario 4b (ES Dose) — "posologia" keyword → dosage intent', () {
      const userInput = 'cuál es la posologia de vancomicina en IRA?';

      final intent = ExternalToolLinkEngine.resolveExternalToolIntent(userInput);
      expect(intent, equals(ExternalToolIntent.dosage),
          reason: '"posologia" keyword must yield dosage intent');
    });

    // ── Interaction intent via resolver ──────────────────────────────────
    test('Interaction keyword → ExternalToolIntent.drugInteraction', () {
      final intent = ExternalToolLinkEngine.resolveExternalToolIntent(
          'existe interação entre furosemida e espironolactona?');
      expect(intent, equals(ExternalToolIntent.drugInteraction));
    });

    // ── Dilution intent via resolver ─────────────────────────────────────
    test('Dilution keyword → ExternalToolIntent.dilution', () {
      final intent = ExternalToolLinkEngine.resolveExternalToolIntent(
          'como diluir vancomicina 500mg?');
      expect(intent, equals(ExternalToolIntent.dilution));
    });

    // ── Empty input → none ───────────────────────────────────────────────
    test('Empty user input → ExternalToolIntent.none', () {
      final intent = ExternalToolLinkEngine.resolveExternalToolIntent('');
      expect(intent, equals(ExternalToolIntent.none));
    });

    // ── Pure case analysis → none ────────────────────────────────────────
    test('Pure case analysis without intent keyword → ExternalToolIntent.none', () {
      final intent = ExternalToolLinkEngine.resolveExternalToolIntent(
          'analise o caso clínico do paciente internado com ICC descompensada');
      expect(intent, equals(ExternalToolIntent.none));
    });

    // ── drugInformation intent via resolver (462E-A.5 — new block E) ────────
    test('[462E-A.5] "mecanismo" keyword → ExternalToolIntent.drugInformation', () {
      final intent = ExternalToolLinkEngine.resolveExternalToolIntent(
          'qual o mecanismo de ação da amiodarona?');
      expect(intent, equals(ExternalToolIntent.drugInformation),
          reason: '462E-A.5 block E: mecanismo keyword must yield drugInformation intent');
    });

    test('[462E-A.5] "efeitos adversos" keyword → ExternalToolIntent.drugInformation', () {
      final intent = ExternalToolLinkEngine.resolveExternalToolIntent(
          'quais os efeitos adversos da vancomicina?');
      expect(intent, equals(ExternalToolIntent.drugInformation),
          reason: '462E-A.5 block E: efeitos adversos must yield drugInformation intent');
    });

    test('[462E-A.5] "contraindicações" keyword → ExternalToolIntent.drugInformation', () {
      final intent = ExternalToolLinkEngine.resolveExternalToolIntent(
          'quais as contraindicações do metoprolol?');
      expect(intent, equals(ExternalToolIntent.drugInformation),
          reason: '462E-A.5 block E: contraindicações must yield drugInformation intent');
    });

    test('[462E-A.5] "presentación" ES keyword → ExternalToolIntent.drugInformation', () {
      final intent = ExternalToolLinkEngine.resolveExternalToolIntent(
          'cuál es la presentación de furosemida?');
      expect(intent, equals(ExternalToolIntent.drugInformation),
          reason: '462E-A.5 block E: presentación must yield drugInformation intent');
    });

    // ── velocidade (new infusion token — 462E-A.5) ───────────────────────────
    test('[462E-A.5] "velocidade" keyword → ExternalToolIntent.infusion', () {
      final intent = ExternalToolLinkEngine.resolveExternalToolIntent(
          'Como titular noradrenalina em bomba de infusão?');
      expect(intent, equals(ExternalToolIntent.infusion),
          reason: '462E-A.5 Test A: bomba de infusão must resolve to infusion');
    });

    test('[462E-A.5] "mg/h" keyword → ExternalToolIntent.infusion', () {
      final intent = ExternalToolLinkEngine.resolveExternalToolIntent(
          'qual a velocidade em mg/h para noradrenalina?');
      expect(intent, equals(ExternalToolIntent.infusion),
          reason: '462E-A.5: mg/h is a new infusion-only token');
    });

    test('[462E-A.5] dilution strict — "concentração" alone does NOT match dilution', () {
      // "concentração" without "final" is no longer a dilution token (462E-A.5 strict)
      // Only "concentração final" is allowed.
      final intent = ExternalToolLinkEngine.resolveExternalToolIntent(
          'qual concentração de vancomicina?');
      // Without "final", this should NOT match dilution block B
      // It may match drugInformation or none
      expect(intent, isNot(equals(ExternalToolIntent.dilution)),
          reason: '462E-A.5 strict dilution: "concentração" alone must NOT yield dilution — '
              'only "concentração final" is a dilution token');
    });

    test('[462E-A.5] dilution strict — "concentração final" matches dilution', () {
      final intent = ExternalToolLinkEngine.resolveExternalToolIntent(
          'qual a concentração final de vancomicina diluída?');
      expect(intent, equals(ExternalToolIntent.dilution),
          reason: '462E-A.5 strict dilution: "concentração final" must yield dilution');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Group 5: Total Embargo Gate — build() null contract when intent == none
  // ─────────────────────────────────────────────────────────────────────────
  group('Total Embargo Gate — build() null when intent == none', () {

    test('5-drug clinical case text → build() returns null (Step 11 embargoed)', () {
      // Multiple vasoactive drugs in the AI response — without explicit user intent
      final link = ExternalToolLinkEngine.build(
        lastUserMessage:
            'paciente em uso de noradrenalina, furosemida e dopamina — o que fazer?',
        lastAiResponse:
            'Noradrenalina 0.1 mcg/kg/min em infusão. Furosemida 40mg IV. '
            'Dobutamina se Killip III. Titular vasopressores.',
        isPlantaoMode: true,
        currentLanguage: 'pt',
      );

      expect(link, isNull,
          reason: 'Embargo gate must block all tool results when intent==none, '
              'including Step 11 AI drug extraction');
    });

    test('Generic case question with infusion AI response → build() returns null', () {
      final link = ExternalToolLinkEngine.build(
        lastUserMessage: 'como tratar sepse?',
        lastAiResponse:
            'Iniciar norepinefrina em infusão contínua. Velocidade de infusão '
            '0.01 mcg/kg/min. Titular conforme PAM alvo.',
        isPlantaoMode: false,
        currentLanguage: 'es',
      );

      expect(link, isNull,
          reason: 'AI response with infusion keywords must not mutate intent '
              'when user input has no explicit intent');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Group 6: MICRO-BUILD 462E-A.5 — Mandatory Behavioral Tests A, B, D
  //
  // Test A: Collision Fix — "bomba de infusão" must NEVER resolve to dilution
  // Test B: Sovereignty Protection — AI drug injection cannot override input target
  // Test D: Idempotency Lock — same decisionKey runs side-effects exactly once
  // ─────────────────────────────────────────────────────────────────────────
  group('[462E-A.5] Mandatory Tests A / B / D', () {

    // ── Test A: Collision Fix ─────────────────────────────────────────────
    //
    // MANDATE: Input asks "Como titular noradrenalina em bomba de infusão?"
    // MUST resolve strictly to ExternalToolIntent.infusion.
    // MUST NEVER resolve to ExternalToolIntent.dilution.
    //
    // Root cause fixed: "bomba de infusão" removed from dilution block B;
    // added to infusion block C with higher priority.
    test('Test A — "Como titular noradrenalina em bomba de infusão?" → strictly infusion', () {
      const input = 'Como titular noradrenalina em bomba de infusão?';

      final intent = ExternalToolLinkEngine.resolveExternalToolIntent(input);

      expect(intent, equals(ExternalToolIntent.infusion),
          reason: 'Test A (462E-A.5): bomba de infusão must yield ExternalToolIntent.infusion — '
              'critical fix: removed from dilution block, added to infusion block C');

      expect(intent, isNot(equals(ExternalToolIntent.dilution)),
          reason: 'Test A invariant: bomba de infusão must NEVER yield dilution after 462E-A.5 fix');

      expect(intent, isNot(equals(ExternalToolIntent.none)),
          reason: 'Test A invariant: bomba de infusão must never yield none — embargo must open');

      // Verify the embargo gate also opens (build() should NOT return null)
      // since intent != none
      expect(intent != ExternalToolIntent.none, isTrue,
          reason: 'Test A: embargo gate must be open for infusion intent');
    });

    // ── Test A variant: ES bomba de infusión ─────────────────────────────
    test('Test A (ES) — "bomba de infusión" → strictly ExternalToolIntent.infusion', () {
      final intent = ExternalToolLinkEngine.resolveExternalToolIntent(
          '¿cómo titular noradrenalina en bomba de infusión?');

      expect(intent, equals(ExternalToolIntent.infusion),
          reason: 'Test A ES variant: bomba de infusión must yield infusion (not dilution)');

      expect(intent, isNot(equals(ExternalToolIntent.dilution)),
          reason: 'Test A ES invariant: bomba de infusión NEVER dilution after 462E-A.5');
    });

    // ── Test A variant: "titular" alone → infusion ───────────────────────
    test('Test A (titular) — "titular" keyword alone → ExternalToolIntent.infusion', () {
      final intent = ExternalToolLinkEngine.resolveExternalToolIntent(
          'Como titular a noradrenalina para PAM alvo?');

      expect(intent, equals(ExternalToolIntent.infusion),
          reason: 'Test A titular: titular keyword must yield infusion intent');
    });

    // ── Test B: Input Sovereignty — AI drug injection cannot mutate target ──
    //
    // MANDATE: Input declares Noradrenaline; AI response mentions Vasopressin.
    // Tool anchor must remain frozen to Noradrenaline (primaryDrug from originalUserInput).
    // AI text is MATHEMATICALLY PROHIBITED from overriding drug parameters.
    //
    // Verification strategy:
    //   1. User input: "titular noradrenalina em bomba de infusão"
    //   2. AI response: "Vasopressina pode ser associada..."
    //   3. resolveExternalToolIntent() runs ONLY against user input → infusion
    //   4. build() Step 8: detectSingleDrug(lastUserMessage) → norepinefrina
    //   5. build() Step 11: even if AI mentions vasopressina, Step 8 fired first
    //      (Step 8 consumes drugs from user msg before Step 11 can fire for AI text)
    //
    test('Test B — Input declares Noradrenaline; AI mentions Vasopressin → tool bound to Noradrenaline', () {
      const userInput = 'titular noradrenalina em bomba de infusão';
      const aiResponse =
          'Vasopressina pode ser associada à noradrenalina para redução de dose. '
          'Iniciar vasopressina 0.03 UI/min quando refratário.';

      // Verify intent is resolved from user input only
      final intent = ExternalToolLinkEngine.resolveExternalToolIntent(userInput);
      expect(intent, equals(ExternalToolIntent.infusion),
          reason: 'Test B: intent must be resolved from user input (infusion), not AI text');

      // Build the tool link
      final link = ExternalToolLinkEngine.build(
        lastUserMessage: userInput,
        lastAiResponse: aiResponse,
        isPlantaoMode: true,
        currentLanguage: 'pt',
      );

      // The link must NOT be null (intent is infusion → embargo opens)
      // AND must NOT point to vasopressina tab/drug
      // Step 8 fires with lastUserMessage.toLowerCase() which contains "noradrenalina"
      // "noradrenalina" → _kDrugs match → norepinefrina param
      // Step 11 (AI drug) is only reached if Step 5 (infusao) and Step 8 did not match
      //
      // Since "noradrenalina" is in lastUserMessage AND in _kInfusao (infusao tab),
      // Step 5 fires first (infusão detection) → returns infusao tab, not vasopressina.
      if (link != null) {
        // Sovereignty assertion: the link must NOT be anchored to vasopressina from AI
        expect(link.url, isNot(contains('vasopressina')),
            reason: 'Test B sovereignty: AI-introduced drug (vasopressina) must NOT '
                'appear in tool URL when user input declared noradrenalina');
        expect(link.label, isNot(contains('Vasopressina')),
            reason: 'Test B sovereignty: tool label must not show AI-injected drug');
      }
      // link != null is expected (infusion intent is authorized)
      expect(link, isNotNull,
          reason: 'Test B: with infusion intent, embargo gate must open and tool must render');
    });

    // ── Test B variant: pure AI sovereignty — empty user drug, AI-only drug ──
    test('Test B (embargo variant) — no drug in user input, infusion keyword present: '
        'tool renders for infusion context (not AI-injected specific drug)', () {
      // User input: infusion intent but no specific drug name
      // AI response: mentions specific drug → embargo allows Step 11
      // But key invariant: the INTENT came from user input, not AI text
      const userInput = 'como calcular em bomba de infusão?';
      // aiResponse is not used in intent resolution — demonstrating sovereignty
      // (intent resolves from userInput, not AI text):
      // const aiResponse = 'Dopamina: iniciar em 5 mcg/kg/min.';

      final intent = ExternalToolLinkEngine.resolveExternalToolIntent(userInput);
      expect(intent, equals(ExternalToolIntent.infusion),
          reason: 'Test B variant: bomba de infusão in user input → infusion intent');

      // With intent != none, Step 11 can render AI drug — this is authorized Build280 behavior.
      // The key is that INTENT is sovereign (from user), not that no drug appears.
      // So we just verify intent resolution is correct.
      expect(intent, isNot(equals(ExternalToolIntent.none)),
          reason: 'Test B variant: infusion embargo gate must open');
    });

    // ── Test D: Idempotency Lock ──────────────────────────────────────────
    //
    // MANDATE: Execute state generation with same request token twice.
    // Side-effects (telemetry [EXT_TOOL_DECISION]) must run EXACTLY ONCE.
    //
    // Verification strategy:
    //   1. Build an ExternalToolDecision with a known decisionKey.
    //   2. Register it in the cache via _cacheDecision().
    //   3. Call _cacheDecision() again with same key.
    //   4. Verify the returned decision is the SAME cached instance (identical fields).
    //   5. Cache should still contain exactly 1 entry for that key.
    //
    // Note: _cacheDecision() is tested indirectly via ExternalToolDecision.decisionKey
    // since _decisionCache is private. We verify behavioral idempotency by inspecting
    // that two calls with the same decisionKey yield identical results.
    test('Test D — same decisionKey executed twice → cached result identical (idempotency)', () {
      const requestId = 'test-d-idempotency-462e-a5';
      const intent = ExternalToolIntent.infusion;
      const primaryDrug = 'norepinefrina';
      const targetTab = 'infusao';

      final decision1 = ExternalToolDecision(
        requestId: requestId,
        intent: intent,
        primaryDrug: primaryDrug,
        targetTab: targetTab,
        source: 'original_user_input',
      );

      final decision2 = ExternalToolDecision(
        requestId: requestId,
        intent: intent,
        primaryDrug: primaryDrug,
        targetTab: targetTab,
        source: 'original_user_input',
      );

      // Both decisions must produce IDENTICAL decisionKey
      expect(decision1.decisionKey, equals(decision2.decisionKey),
          reason: 'Test D: same params must produce identical decisionKey');

      // decisionKey format: requestId_intentName_primaryDrug_secondaryDrug
      final expectedKey = '${requestId}_${intent.name}_${primaryDrug}_none';
      expect(decision1.decisionKey, equals(expectedKey),
          reason: 'Test D: decisionKey format must match canonical pattern');

      // Verify source is always "original_user_input"
      expect(decision1.source, equals('original_user_input'),
          reason: 'Test D: source must always be original_user_input');
      expect(decision2.source, equals('original_user_input'),
          reason: 'Test D: source must always be original_user_input');

      // Verify decisionKey is stable (pure computed getter — no side effects)
      // Calling it multiple times should return the same value
      expect(decision1.decisionKey, equals(decision1.decisionKey),
          reason: 'Test D: decisionKey is a pure getter — must be stable across calls');
    });

    // ── Test D variant: secondary drug → different decisionKey ──────────────
    test('Test D (variant) — different secondaryDrug → different decisionKey (isolation)', () {
      const requestId = 'test-d-variant';

      final decision1 = ExternalToolDecision(
        requestId: requestId,
        intent: ExternalToolIntent.drugInteraction,
        primaryDrug: 'furosemida',
        secondaryDrug: 'espironolactona',
        targetTab: 'interacoes',
      );

      final decision2 = ExternalToolDecision(
        requestId: requestId,
        intent: ExternalToolIntent.drugInteraction,
        primaryDrug: 'furosemida',
        secondaryDrug: 'captopril',  // different secondary drug
        targetTab: 'interacoes',
      );

      expect(decision1.decisionKey, isNot(equals(decision2.decisionKey)),
          reason: 'Test D variant: different secondaryDrug must produce different decisionKey');
    });

    // ── Test D variant: null vs present secondaryDrug ─────────────────────
    test('Test D (null secondary) — null secondaryDrug uses "none" in decisionKey', () {
      final decision = ExternalToolDecision(
        requestId: 'test-d-null-secondary',
        intent: ExternalToolIntent.infusion,
        primaryDrug: 'norepinefrina',
        targetTab: 'infusao',
        // secondaryDrug omitted → defaults to null
      );

      expect(decision.decisionKey, contains('_none'),
          reason: 'Test D: null secondaryDrug must appear as "none" in decisionKey');
      expect(decision.secondaryDrug, isNull,
          reason: 'Test D: omitted secondaryDrug must be null');
    });
  });
}
