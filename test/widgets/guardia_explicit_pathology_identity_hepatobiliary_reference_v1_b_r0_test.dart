import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/ai/widgets/clinical_reference_resolver.dart';
import 'package:medcases/screens/ai/widgets/guardia_clinical_response_view.dart';

void main() {
  Widget host({
    required String raw,
    required String user,
    String lang = 'es',
  }) {
    return MaterialApp(
      home: Scaffold(
        body: GuardiaClinicalResponseView(
          rawText: raw,
          userText: user,
          dark: true,
          languageCode: lang,
          typedTreatmentVisualEnabled: false,
          onCopy: () {},
        ),
      ),
    );
  }

  group('explicit pathology identity + hepatobiliary reference V1-B-R0', () {
    testWidgets(
      'coledocolitiasis explícita não vira Orientación clínica se o modelo troca entidade',
      (tester) async {
        const raw = '🟥 COLECISTOLITIASIS — DIFERENCIALES PRIORITARIOS\n'
            '🚨 Evaluación inicial:\n'
            '* Estabilidad del paciente y monitorización de signos vitales.\n'
            '🔑 Puntos clave:\n'
            '* Posibilidad 1: colecistitis aguda.\n'
            '* Posibilidad 2: cólico biliar.\n'
            '🚩 RED FLAGS:\n'
            '* Ictericia y fiebre alta.\n'
            '📌 Realizar evaluación biliar dirigida.';

        await tester.pumpWidget(host(raw: raw, user: 'COLEDUCOLITIASIS'));

        expect(find.text('COLEDOCOLITIASIS'), findsOneWidget);
        expect(find.text('Orientación clínica'), findsNothing);
        expect(
          find.text('COLECISTOLITIASIS — DIFERENCIALES PRIORITARIOS'),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'síndrome coledociano explícito conserva identidade visível',
      (tester) async {
        const raw = '🟥 COLECISTOLITIASIS — DIFERENCIALES PRIORITARIOS\n'
            '🚨 Evaluación inicial:\n'
            '* Estabilidad clínica.\n'
            '🔑 Puntos clave:\n'
            '* Posibilidad 1: obstrucción biliar.';

        await tester.pumpWidget(host(raw: raw, user: 'síndrome coledociano'));

        expect(find.text('SÍNDROME COLEDOCIANO'), findsOneWidget);
        expect(find.text('Orientación clínica'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'sintoma inespecífico continua demovendo diagnóstico inferido',
      (tester) async {
        const raw = '🟥 COLECISTITIS AGUDA\n'
            '🚨 Conducta inmediata:\n'
            '* Evaluar estabilidad.';

        await tester.pumpWidget(host(raw: raw, user: 'dolor abdominal'));

        expect(find.text('Orientación clínica'), findsOneWidget);
        expect(find.text('COLECISTITIS AGUDA'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'IAM continua usando título expandido já homologado',
      (tester) async {
        const raw = '🟥 INFARTO AGUDO DE MIOCARDIO\n'
            '🚨 Conducta inmediata:\n'
            '* Realizar ECG.';

        await tester.pumpWidget(host(raw: raw, user: 'IAM'));

        expect(find.text('INFARTO AGUDO DE MIOCARDIO'), findsOneWidget);
        expect(find.text('Orientación clínica'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    test('coledocolitiasis usa ASGE + ESGE e nunca renal/genérico', () {
      final result = ClinicalReferenceResolver.resolve(
        userText: 'COLEDUCOLITIASIS',
        aiText: '🟥 COLECISTOLITIASIS — DIFERENCIALES PRIORITARIOS',
        lang: 'es',
      );

      final text = result.lines.join(' ');
      expect(result.sourceType, 'specialty_fallback_choledocholithiasis');
      expect(text, contains('ASGE'));
      expect(text, contains('choledocholithiasis'));
      expect(text, contains('ESGE'));
      expect(text, contains('10.1055/a-0862-0346'));
      expect(text, isNot(contains('KDIGO')));
      expect(text, isNot(contains("Harrison's")));
    });

    test('síndrome coledociano usa o mesmo domínio hepatobiliar', () {
      final result = ClinicalReferenceResolver.resolve(
        userText: 'síndrome coledociano',
        aiText: '🟥 ORIENTACIÓN BILIAR',
        lang: 'es',
      );

      final text = result.lines.join(' ');
      expect(result.sourceType, 'specialty_fallback_choledocholithiasis');
      expect(text, contains('ASGE'));
      expect(text, contains('ESGE'));
      expect(text, isNot(contains('KDIGO')));
    });
  });
}
