import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/ai/widgets/guardia_clinical_response_view.dart';
import 'package:medcases/services/ai_pipeline/plantao_local_clinical_output_adapter.dart';
import 'package:medcases/services/plantao_iamcest_killip_classification_guard.dart';
import 'package:medcases/services/plantao_pipeline.dart';

bool _hasPictographicEmoji(String text) {
  for (final cp in text.runes) {
    if ((cp >= 0x1F000 && cp <= 0x1FAFF) ||
        (cp >= 0x2600 && cp <= 0x27BF) ||
        cp == 0xFE0F) {
      return true;
    }
  }
  return false;
}

void main() {
  group('M55D IAMCEST deterministic initial projector V1-B-R5', () {
    const physicalCase =
        'Varón de 58 años con dolor retroesternal opresivo de 50 minutos, '
        'irradiado al brazo izquierdo, con náuseas. ECG con elevación persistente '
        'del ST en V2–V5. Troponina elevada. PA 128/78 mmHg, FC 86 lpm, '
        'SpO₂ 96% al aire ambiente. Está consciente, bien perfundido. '
        'Auscultación pulmonar sin estertores. Sin edema periférico ni '
        'ingurgitación yugular. ¿Cuál es el diagnóstico, cuál es la clasificación '
        'del IAM y cuál es la clase de Killip? Explica qué significa esa clase, '
        'por qué corresponde a este paciente y cuál es la conducta inicial.';

    const physicalBadRaw =
        '🟥 IAMCEST (Infarto Agudo de Miocardio con Elevación del ST)\n'
        '🔑 Puntos clave:\n'
        '* **Clasificación del paciente: IAMCEST** — elevación persistente del ST en V2–V5 y troponina elevada.\n'
        '* **Clase de Killip: I** — ausencia de signos de congestión pulmonar o de choque cardiogénico.\n'
        '📌 Clasificación final: IAMCEST, Killip I.\n'
        '**Significado de la clase de Killip:** Clase I sin insuficiencia cardíaca.\n'
        '🚨 **Conducta inmediata:**\n'
        '1. MONITORIZACIÓN: ECG continuo, SpO2, PA cada 15 min\n'
        '2. O2 si SpO2 <90%\n'
        '3. AAS 300 mg VO masticar + Ticagrelor 180 mg VO (o Prasugrel 60 mg si ICP)\n'
        '4. Anticoagulación: HNF 60–70 UI/kg IV bolo, máximo 5000 UI + infusión continua 12–15 UI/kg/h\n'
        '📌 Proceder con la conducta inicial según protocolos verificados';

    String project() => PlantaoIamcestKillipClassificationGuard.materialize(
      userInput: physicalCase,
      assistantOutput: physicalBadRaw,
      languageCode: 'es',
    );

    test(
      'exact physical combined IAM is deterministic, ordered, complete and 2-column',
      () {
        final out = project();

        expect(_hasPictographicEmoji(out), isFalse);
        expect(
          out,
          startsWith(
            'IAMCEST (Infarto Agudo de Miocardio con Elevación del Segmento ST)',
          ),
        );

        final immediate = out.indexOf('Conducta inmediata:');
        final pharma = out.indexOf('Tratamiento farmacológico:');
        final classification = out.indexOf(
          '| Criterio / clasificación | Resultado en este paciente |',
        );
        final keyPoints = out.indexOf('Puntos clave:');
        final redFlags = out.indexOf('Red flags:');
        expect(immediate, greaterThanOrEqualTo(0));
        expect(pharma, greaterThan(immediate));
        expect(classification, greaterThan(pharma));
        expect(keyPoints, greaterThan(classification));
        expect(redFlags, greaterThan(keyPoints));

        expect(out, contains('| --- | --- |'));
        expect(out, contains('| Diagnóstico | **IAMCEST** |'));
        expect(out, contains('| Killip | **Clase I** |'));
        expect(
          out,
          contains(
            '| Significado | Sin signos clínicos de insuficiencia cardíaca. |',
          ),
        );
        expect(out, contains('| Aplicación al caso |'));
        expect(out, isNot(contains('Clasificación final:')));

        expect(out.toLowerCase(), contains('reperfusión'));
        expect(out, contains('ICP primaria'));
        expect(out, contains('SpO₂ <90%'));
        expect(out, contains('Antiagregación: AAS 300 mg'));
        expect(out, contains('Ticagrelor 180 mg'));
        expect(out, contains('HNF 60–70 UI/kg'));
        expect(out, contains('Killip y Kimball en 1967'));
        expect(out, isNot(contains('Killip 2026')));

        expect(
          RegExp(r'^\s*[1-9][.)]\s+', multiLine: true).hasMatch(out),
          isFalse,
        );
      },
    );

    test('zero-emoji canonical title is a valid parser anchor', () {
      final guarded = project();
      final parsed = PlantaoParser.parse(guarded);
      expect(parsed, isNotNull);
      expect(parsed!.conduta, contains('IAMCEST'));
      expect(_hasPictographicEmoji(parsed.conduta), isFalse);
    });

    test(
      'zero-emoji parser still rejects section-only text without clinical title',
      () {
        final parsed = PlantaoParser.parse(
          'Tratamiento farmacológico:\nAAS 300 mg VO\nConducta inmediata:\nMonitorizar',
        );
        expect(parsed, isNull);
      },
    );

    testWidgets(
      'final physical renderer order is immediate then pharma then classification table then key points then red flags',
      (tester) async {
        final guarded = project();
        final output = PlantaoLocalClinicalOutputAdapter.fromValidatedText(
          guarded,
        );

        expect(output, isNotNull);
        expect(output!.condutaImediataItens, isNotEmpty);
        expect(output.prescricao, isNotEmpty);
        expect(output.pontosChave, isNotEmpty);
        expect(output.hardStops, isNotEmpty);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: GuardiaClinicalResponseView(
                  rawText: guarded,
                  output: output,
                  userText: physicalCase,
                  dark: true,
                  languageCode: 'es',
                  typedTreatmentVisualEnabled: false,
                  onCopy: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // M55D_R5_PHYSICAL_WIDGET_SEMANTIC_CONTENT_ORDER_ORACLE_V1
        // The productive renderer does not expose wrapper ValueKeys for each
        // clinical section. Validate the physical order using unique visible
        // clinical content plus the existing true-table key instead of
        // inventing a second/test-only renderer contract.
        final immediate = find.textContaining(
          'Activar estrategia de reperfusión inmediata',
          findRichText: true,
        );
        final pharma = find.textContaining(
          'Antiagregación:',
          findRichText: true,
        );
        final table = find.byKey(const ValueKey('guardia_markdown_table_0'));
        final keyPoints = find.textContaining(
          'Killip es una clasificación clínica clásica',
          findRichText: true,
        );
        final redFlags = find.textContaining(
          'Hipotensión, hipoperfusión o shock cardiogénico',
          findRichText: true,
        );

        expect(immediate, findsWidgets);
        expect(pharma, findsWidgets);
        expect(table, findsOneWidget);
        expect(keyPoints, findsWidgets);
        expect(redFlags, findsWidgets);
        expect(find.byType(Table), findsOneWidget);
        expect(find.text('Criterio / clasificación'), findsOneWidget);
        expect(find.text('Resultado en este paciente'), findsOneWidget);
        expect(find.text('Killip'), findsOneWidget);
        expect(find.text('Clase I'), findsOneWidget);
        expect(
          find.textContaining('| --- |', findRichText: true),
          findsNothing,
        );

        final immediateY = tester.getTopLeft(immediate.first).dy;
        final pharmaY = tester.getTopLeft(pharma.first).dy;
        final tableY = tester.getTopLeft(table).dy;
        final keyPointsY = tester.getTopLeft(keyPoints.first).dy;
        final redFlagsY = tester.getTopLeft(redFlags.first).dy;

        expect(immediateY, lessThan(pharmaY));
        expect(pharmaY, lessThan(tableY));
        expect(tableY, lessThan(keyPointsY));
        expect(keyPointsY, lessThan(redFlagsY));
        expect(tester.takeException(), isNull);
      },
    );

    test('classification-only IAM is canonical zero-emoji 2-column table', () {
      final out = PlantaoIamcestKillipClassificationGuard.materialize(
        userInput: '¿Y cuál es la clasificación y la clase de Killip?',
        assistantOutput:
            '📌 Clasificación final: IAMCEST, Killip I. Sin congestión.',
        languageCode: 'es',
        recentUserTurns: const [physicalCase],
      );
      expect(_hasPictographicEmoji(out), isFalse);
      expect(out, startsWith('CLASIFICACIÓN'));
      expect(
        out,
        contains('| Criterio / clasificación | Resultado en este paciente |'),
      );
      expect(out, contains('| Killip | **Clase I** |'));
      expect(out, isNot(contains('Clasificación final:')));
    });

    test('insufficient IAM data fails closed except global emoji cleanup', () {
      const raw = '📌 Clasificación final: IAMCEST.';
      final out = PlantaoIamcestKillipClassificationGuard.materialize(
        userInput: '¿Cuál es la clasificación y la clase de Killip?',
        assistantOutput: raw,
        languageCode: 'es',
        recentUserTurns: const [
          'Paciente con IAMCEST confirmado por ECG, sin más datos hemodinámicos.',
        ],
      );
      expect(out, 'Clasificación final: IAMCEST.');
      expect(_hasPictographicEmoji(out), isFalse);
    });

    test(
    // M72C_SUPERSEDES_CROSS_PATH_EMOJI_CLEANUP_V1
      'non-IAM final text is byte-exact outside IAM owner',
      () {
        const raw =
            '🟥 ANAFILAXIA\n🚨 Conducta inmediata: ADRENALINA IM primero.';
        final out = PlantaoIamcestKillipClassificationGuard.materialize(
          userInput:
              'Mujer tras maní con urticaria, sibilancias e hipotensión. ¿Conducta?',
          assistantOutput: raw,
          languageCode: 'es',
        );
        expect(out, raw);
        expect(_hasPictographicEmoji(out), isTrue);
      },
    );

    test(
      'existing productive wiring remains the single post-TEP IAM owner and rebinds DTO after guard changes',
      () {
        final app = File('lib/providers/app_provider.dart').readAsStringSync();
        expect(
          'PlantaoIamcestKillipClassificationGuard.materialize'
              .allMatches(app)
              .length,
          1,
        );
        expect(
          app.indexOf('final tep2026GuardedText ='),
          lessThan(app.indexOf('final iamcestKillipGuardedText =')),
        );
        expect(
          RegExp(
            r'PlantaoLocalClinicalOutputAdapter\.fromValidatedText\(\s*guardedText\s*,?\s*\)',
          ).hasMatch(app),
          isTrue,
        );
      },
    );

    test(
      'true Flutter table owner is reused with semantic classification slot',
      () {
        final renderer = File(
          'lib/screens/ai/widgets/guardia_clinical_response_view.dart',
        ).readAsStringSync();
        expect(renderer, contains('PLANTAO_MARKDOWN_TABLE_TRUE_RENDER_V1'));
        expect(
          renderer,
          contains('M55D_CLASSIFICATION_TABLE_SEMANTIC_SLOT_V1'),
        );
        expect(renderer, contains('hasClassificationTables'));
        expect(renderer, contains('hasNonClassificationTables'));
        expect(renderer, contains('Table('));
        expect(renderer, contains('scrollDirection: Axis.horizontal'));
      },
    );
  });
}
