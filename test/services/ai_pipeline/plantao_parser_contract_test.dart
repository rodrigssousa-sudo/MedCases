import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/plantao_pipeline.dart';

void main() {
  group('PlantaoParser contract', () {
    test(
      'interpreta o template clínico completo',
      () {
        final result = PlantaoParser.parse(
          '🟥 Choque séptico\n'
          '💊 Noradrenalina 0,05 mcg/kg/min EV\n'
          '🔄 Vasopressina como adjuvante\n'
          '⛔ Evitar atraso no antibiótico\n'
          '📌 Monitorar PAM e diurese\n'
          '⚠️ Risco de hipoperfusão',
        );

        expect(result, isNotNull);
        expect(result?.conduta, 'Choque séptico');

        expect(
          result?.primeiraLinha,
          'Noradrenalina 0,05 mcg/kg/min EV',
        );

        expect(
          result?.alternativa,
          'Vasopressina como adjuvante',
        );

        expect(
          result?.evitar,
          'Evitar atraso no antibiótico',
        );

        expect(
          result?.monitorar,
          'Monitorar PAM e diurese',
        );

        expect(
          result?.alerta,
          'Risco de hipoperfusão',
        );

        expect(result?.isComplete, isTrue);
      },
    );

    test(
      'aceita somente a âncora obrigatória',
      () {
        final result = PlantaoParser.parse(
          '🟥 Conduta clínica imediata',
        );

        expect(result, isNotNull);

        expect(
          result?.conduta,
          'Conduta clínica imediata',
        );

        expect(result?.monitorar, isEmpty);
        expect(result?.isComplete, isTrue);
      },
    );

    test(
      'rejeita texto sem âncora de conduta',
      () {
        final result = PlantaoParser.parse(
          '💊 Medicação\n'
          '📌 Monitorização',
        );

        expect(result, isNull);
      },
    );

    test(
      'ignora linhas técnicas iniciadas por colchete',
      () {
        final result = PlantaoParser.parse(
          '🟥 Pneumonia\n'
          '[SYSTEM] conteúdo interno proibido\n'
          '💊 Amoxicilina 500 mg VO\n'
          '[PROMPT] outra linha interna\n'
          '📌 Reavaliar em 48 horas',
        );

        expect(result, isNotNull);

        expect(
          result?.conduta,
          'Pneumonia',
        );

        expect(
          result?.primeiraLinha,
          'Amoxicilina 500 mg VO',
        );

        expect(
          result.toString(),
          isNot(contains('SYSTEM')),
        );

        expect(
          result.toString(),
          isNot(contains('PROMPT')),
        );
      },
    );

    test(
      'preserva continuação multilinha dentro do bloco',
      () {
        final result = PlantaoParser.parse(
          '🟥 Insuficiência cardíaca\n'
          '💊 Furosemida 40 mg EV\n'
          'Reavaliar congestão após a dose\n'
          'Ajustar conforme diurese\n'
          '📌 Monitorar pressão e função renal',
        );

        expect(
          result?.primeiraLinha,
          'Furosemida 40 mg EV\n'
          'Reavaliar congestão após a dose\n'
          'Ajustar conforme diurese',
        );
      },
    );

    test(
      'usa metas como fallback do campo monitorar',
      () {
        final result = PlantaoParser.parse(
          '🟥 Cetoacidose diabética\n'
          '📈 Redução gradual da glicemia',
        );

        expect(
          result?.metas,
          'Redução gradual da glicemia',
        );

        expect(
          result?.monitorar,
          'Redução gradual da glicemia',
        );
      },
    );

    test(
      'usa próximo passo como segundo fallback de monitorar',
      () {
        final result = PlantaoParser.parse(
          '🟥 Dor torácica\n'
          '✅ Solicitar ECG imediato',
        );

        expect(
          result?.proxPasso,
          'Solicitar ECG imediato',
        );

        expect(
          result?.monitorar,
          'Solicitar ECG imediato',
        );
      },
    );

    test(
      'conteúdo espanhol usa o mesmo contrato estrutural',
      () {
        final result = PlantaoParser.parse(
          '🟥 Hipoglucemia sintomática\n'
          '💊 Administrar glucosa EV\n'
          '📌 Controlar glucemia a los 15 minutos',
        );

        expect(
          result?.conduta,
          'Hipoglucemia sintomática',
        );

        expect(
          result?.primeiraLinha,
          'Administrar glucosa EV',
        );

        expect(
          result?.monitorar,
          'Controlar glucemia a los 15 minutos',
        );
      },
    );

    test(
      'não interpreta JSON bruto',
      () {
        final result = PlantaoParser.parse(
          '{"conduta":"Pneumonia",'
          '"dose":"Amoxicilina"}',
        );

        expect(result, isNull);
      },
    );
  });
}
