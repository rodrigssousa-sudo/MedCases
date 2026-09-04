import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_next_action_engine.dart';

void main() {
  group('PHASE3I-J2F12-R3 hypothetical sepsis relevance', () {
    SmartNextAction build({
      required String user,
      required String response,
      String language = 'pt',
      List<String> history = const <String>[],
    }) {
      return NextActionEngine.build(
        lastUserMessage: user,
        lastAiResponse: response,
        isPlantaoMode: true,
        currentLanguage: language,
        chatHistory: history,
      );
    }

    const exactDeviceUser =
        'Paciente com pneumonia, sem sinais de sepse, choque ou '
        'instabilidade hemodinâmica. Organize a conduta.';

    const exactDeviceResponse =
        '🟥 PNEUMONIA SEM SEPSE — CONDUTA IMEDIATA\n'
        '🚨 Conduta imediata:\n'
        '* Monitorar sinais vitais e estado geral\n'
        '* Avaliar necessidade de internação ou tratamento ambulatorial\n'
        '* Solicitar exames laboratoriais: hemograma, PCR, gasometria\n'
        '💊 Tratamento farmacológico:\n'
        '1ª linha: Amoxicilina 1 g VO de 8/8h\n'
        '2ª linha: Azitromicina 500 mg VO 1x/dia\n'
        '🔑 Pontos-chave:\n'
        '* Reavaliar após 48-72h o progresso\n'
        '⛔ HARD STOP:\n'
        '* Febre persistente ou piora clínica → considerar sepse '
        'ou necessidade de UTI\n'
        '📌 Iniciar antibióticos rapidamente.';

    test('exact iPhone payload no longer selects vasopressors', () {
      final action = build(
        user: exactDeviceUser,
        response: exactDeviceResponse,
      );

      expect(action.label, isEmpty);
      expect(action.promptToSend, isEmpty);
    });

    test('exact iPhone payload remains stable with same-session history', () {
      final action = build(
        user: exactDeviceUser,
        response: exactDeviceResponse,
        history: const <String>[
          'Pneumonia comunitária em tratamento.',
          'Ceftriaxona e piperacilina-tazobactam conforme gravidade.',
          exactDeviceUser,
          exactDeviceResponse,
        ],
      );

      expect(action.label, isEmpty);
      expect(action.promptToSend, isEmpty);
    });

    test('single considerar sepse phrase does not select vasopressors', () {
      final action = build(
        user: 'Paciente com pneumonia estável.',
        response:
            'Em caso de piora clínica, considerar sepse ou necessidade '
            'de UTI.',
      );

      expect(action.label.toLowerCase(), isNot(contains('vasopressor')));
    });

    test('Spanish considerar sepsis phrase is hypothetical', () {
      final action = build(
        user: 'Paciente con neumonía estable.',
        response:
            'Si presenta deterioro clínico, considerar sepsis o '
            'necesidad de UCI.',
        language: 'es',
      );

      expect(action.label.toLowerCase(), isNot(contains('vasopresor')));
    });

    test('considerar choque séptico phrase is hypothetical', () {
      final action = build(
        user: 'Paciente com pneumonia em acompanhamento.',
        response:
            'Se houver piora, considerar choque séptico e transferência '
            'para UTI.',
      );

      expect(action.label.toLowerCase(), isNot(contains('vasopressor')));
    });

    test('true active sepsis remains vasopressor action', () {
      final action = build(
        user:
            'Paciente com sepse, hipotensão persistente, lactato elevado '
            'e necessidade de noradrenalina.',
        response:
            '🟥 CHOQUE SÉPTICO\n'
            'Hipoperfusão persistente apesar de cristaloides.',
      );

      expect(action.label.toLowerCase(), contains('vasopressor'));
    });

    test('hypothetical phrase does not erase separate active evidence', () {
      final action = build(
        user:
            'Paciente com sepse ativa, lactato elevado e noradrenalina '
            'em curso.',
        response:
            'Após estabilização inicial, considerar sepse refratária '
            'se mantiver hipoperfusão.',
      );

      expect(action.label.toLowerCase(), contains('vasopressor'));
    });

    test('Spanish active sepsis remains vasopressor action', () {
      final action = build(
        user:
            'Paciente con sepsis activa, hipotensión persistente, '
            'lactato elevado y noradrenalina.',
        response:
            '🟥 SHOCK SÉPTICO\n'
            'Hipoperfusión pese a cristaloides.',
        language: 'es',
      );

      expect(action.label.toLowerCase(), contains('vasopresor'));
    });
  });
}
