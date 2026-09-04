import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/ai/widgets/guardia_clinical_response_view.dart';

void main() {
  const esRaw = """
🟥 INFARTO AGUDO DE MIOCARDIO/SÍNDROME CORONARIA AGUDA — MANEJO AVANZADO
🚨 Estratificación de riesgo:
* Clasificación según escala de GRACE o TIMI
* Considerar factores: edad, antecedentes, signos clínicos y troponina
💊 Estrategia invasiva:
* Cateterismo cardíaco inmediato si riesgo alto (p. ej., GRACE >140)
* Revascularización percutánea (angioplastia) si indicado, especialmente en STEMI
🔑 Monitorización continua:
* Registro de presión arterial, frecuencia cardíaca y ritmo
* Vigilancia de síntomas de isquemia recurrente o complicaciones
🚩 Manejo de complicaciones:
* Manejo de arritmias: monitorización y tratamiento específico
* Insuficiencia cardíaca: diuréticos si congestión
* Shock cardiogénico: soporte inotrópico y considerar asistencia ventricular si necesario
📌 Próxima acción clínica: implementar cateterismo según estratificación de riesgo y respuesta clínica del paciente.
""";

  const ptRaw = """
🟥 INFARTO AGUDO DO MIOCÁRDIO/SÍNDROME CORONARIANA AGUDA — MANEJO AVANÇADO
🚨 Estratificação de risco:
* Classificação pela escala GRACE ou TIMI
* Considerar fatores: idade, antecedentes, sinais clínicos e troponina
💊 Estratégia invasiva:
* Cateterismo cardíaco imediato se alto risco (por exemplo, GRACE >140)
* Revascularização percutânea (angioplastia) quando indicada
🔑 Monitorização contínua:
* Pressão arterial, frequência cardíaca e ritmo
* Vigiar sintomas de isquemia recorrente ou complicações
🚩 Manejo de complicações:
* Manejo de arritmias: monitorização e tratamento específico
* Insuficiência cardíaca: diuréticos se congestão
* Choque cardiogênico: suporte inotrópico quando necessário
📌 Próxima ação clínica: implementar cateterismo conforme estratificação de risco e resposta clínica.
""";

  Widget subject({
    required String rawText,
    required String languageCode,
    bool isStreaming = false,
    ValueNotifier<String>? notifier,
  }) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: GuardiaClinicalResponseView(
            key: const ValueKey('advanced_continuation_subject'),
            rawText: rawText,
            output: null,
            dark: true,
            languageCode: languageCode,
            onCopy: () {},
            isStreaming: isStreaming,
            streamingTextNotifier: notifier,
          ),
        ),
      ),
    );
  }

  group('renderer advanced continuation final preservation', () {
    test('source has exact ES/PT aliases and RichText bullet owner', () {
      final source = File(
        'lib/screens/ai/widgets/guardia_clinical_response_view.dart',
      ).readAsStringSync();

      final bulletStart = source.indexOf('class _BulletLine extends StatelessWidget');
      final bulletEnd = source.indexOf('class _PinnedLine', bulletStart);
      expect(bulletStart, greaterThanOrEqualTo(0));
      expect(bulletEnd, greaterThan(bulletStart));
      final bulletOwner = source.substring(bulletStart, bulletEnd);
      expect(bulletOwner, contains('RichText('));
      expect(bulletOwner, contains('TextSpan('));

      final pinnedStart = source.indexOf('class _PinnedLine extends StatelessWidget');
      final pinnedEnd = source.indexOf('class _PartialLine', pinnedStart);
      expect(pinnedStart, greaterThanOrEqualTo(0));
      expect(pinnedEnd, greaterThan(pinnedStart));
      final pinnedOwner = source.substring(pinnedStart, pinnedEnd);
      expect(
        pinnedOwner,
        contains('_normalizeGuardiaNoteLabel(text)'),
      );
      expect(
        pinnedOwner,
        isNot(contains(r"'📌 $text'")),
      );
      for (final alias in const <String>[
        'estratificacion de riesgo',
        'estratificacion del riesgo',
        'estratificacao de risco',
        'estratificacao do risco',
        'estrategia invasiva',
        'monitorizacion continua',
        'monitorizacao continua',
        'manejo de complicaciones',
        'manejo de complicacoes',
      ]) {
        expect(source, contains("value == '$alias'"), reason: alias);
      }
    });

    test('generic 🚩 complication heading does not freeze streaming', () {
      final visible = GuardiaStreamingPresentation.stableBeforeHardStop(
        rawText: esRaw,
        isStreaming: true,
      );
      expect(visible, esRaw);
      expect(visible, contains('Shock cardiogénico'));
      expect(visible, contains('Próxima acción clínica'));
    });

    test('explicit RED FLAGS still freezes until final', () {
      const raw = """
🟥 ARRITMIA
* Monitorizar ritmo
🚩 RED FLAGS:
* Inestabilidad hemodinámica
""";
      final streaming = GuardiaStreamingPresentation.stableBeforeHardStop(
        rawText: raw,
        isStreaming: true,
      );
      expect(streaming, contains('Monitorizar ritmo'));
      expect(streaming, isNot(contains('RED FLAGS')));
      expect(streaming, isNot(contains('Inestabilidad hemodinámica')));
      expect(
        GuardiaStreamingPresentation.stableBeforeHardStop(
          rawText: raw,
          isStreaming: false,
        ),
        raw,
      );
    });

    testWidgets('ES final keeps all substantive advanced content', (tester) async {
      await tester.pumpWidget(subject(rawText: esRaw, languageCode: 'es'));
      await tester.pump();
      for (final text in const <String>[
        'Clasificación según escala de GRACE o TIMI',
        'Considerar factores: edad, antecedentes, signos clínicos y troponina',
        'Cateterismo cardíaco inmediato si riesgo alto (p. ej., GRACE >140)',
        'Revascularización percutánea (angioplastia) si indicado, especialmente en STEMI',
        'Registro de presión arterial, frecuencia cardíaca y ritmo',
        'Vigilancia de síntomas de isquemia recurrente o complicaciones',
        'Manejo de arritmias: monitorización y tratamiento específico',
        'Insuficiencia cardíaca: diuréticos si congestión',
        'Shock cardiogénico: soporte inotrópico y considerar asistencia ventricular si necesario',
        'Próxima acción clínica: implementar cateterismo según estratificación de riesgo y respuesta clínica del paciente',
      ]) {
        expect(
          find.textContaining(text, findRichText: true),
          findsOneWidget,
          reason: text,
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('PT final keeps all substantive advanced content', (tester) async {
      await tester.pumpWidget(subject(rawText: ptRaw, languageCode: 'pt'));
      await tester.pump();
      for (final text in const <String>[
        'Classificação pela escala GRACE ou TIMI',
        'Considerar fatores: idade, antecedentes, sinais clínicos e troponina',
        'Cateterismo cardíaco imediato se alto risco (por exemplo, GRACE >140)',
        'Revascularização percutânea (angioplastia) quando indicada',
        'Pressão arterial, frequência cardíaca e ritmo',
        'Vigiar sintomas de isquemia recorrente ou complicações',
        'Manejo de arritmias: monitorização e tratamento específico',
        'Insuficiência cardíaca: diuréticos se congestão',
        'Choque cardiogênico: suporte inotrópico quando necessário',
        'Próxima ação clínica: implementar cateterismo conforme estratificação de risco e resposta clínica',
      ]) {
        expect(
          find.textContaining(text, findRichText: true),
          findsOneWidget,
          reason: text,
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('streaming -> final keeps same surface and expands', (tester) async {
      final notifier = ValueNotifier<String>("""
🟥 INFARTO AGUDO DE MIOCARDIO/SÍNDROME CORONARIA AGUDA — MANEJO AVANZADO
🚨 Estratificación de riesgo:
* Clasificación según escala de GRACE o TIMI
""");
      late StateSetter updateHost;
      var rawText = notifier.value;
      var isStreaming = true;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: StatefulBuilder(
            builder: (context, setState) {
              updateHost = setState;
              return Scaffold(
                body: SingleChildScrollView(
                  child: GuardiaClinicalResponseView(
                    key: const ValueKey('advanced_continuation_same_surface'),
                    rawText: rawText,
                    output: null,
                    dark: true,
                    languageCode: 'es',
                    onCopy: () {},
                    isStreaming: isStreaming,
                    streamingTextNotifier: notifier,
                  ),
                ),
              );
            },
          ),
        ),
      );

      final root = find.byKey(const ValueKey('guardia_clinical_response'));
      expect(root, findsOneWidget);
      final before = tester.element(root);

      expect(
        find.textContaining(
          'Clasificación según escala de GRACE o TIMI',
          findRichText: true,
        ),
        findsOneWidget,
      );

      updateHost(() {
        rawText = esRaw;
        isStreaming = false;
      });
      await tester.pump();
      await tester.pump();

      final after = tester.element(root);
      expect(identical(before, after), isTrue);
      for (final text in const <String>[
        'GRACE >140',
        'Revascularización percutánea',
        'isquemia recurrente',
        'Manejo de arritmias',
        'Insuficiencia cardíaca',
        'Shock cardiogénico',
        'Próxima acción clínica',
      ]) {
        expect(
          find.textContaining(text, findRichText: true),
          findsOneWidget,
          reason: text,
        );
      }

      notifier.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
