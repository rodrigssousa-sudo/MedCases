import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_next_action_engine.dart';

void main() {
  group('PHASE3I-J2F12-R1 negation-aware current-turn relevance', () {
    SmartNextAction build({
      required String user,
      required String response,
      required String language,
    }) {
      return NextActionEngine.build(
        lastUserMessage: user,
        lastAiResponse: response,
        isPlantaoMode: true,
        currentLanguage: language,
        chatHistory: const <String>[],
      );
    }

    const ptPneumoniaResponse =
        '🟥 PNEUMONIA ADQUIRIDA NA COMUNIDADE — TRATAMENTO\n'
        '💊 Tratamento farmacológico:\n'
        '1ª linha: Ceftriaxona 1–2 g IV/dia.\n'
        '2ª linha: Piperacilina-tazobactam 4,5 g IV 6/6h.\n'
        '🔑 Pontos-chave: monitorar evolução clínica.';

    const esPneumoniaResponse =
        '🟥 NEUMONÍA ADQUIRIDA EN LA COMUNIDAD — TRATAMIENTO\n'
        '💊 Tratamiento farmacológico:\n'
        '1ª línea: ceftriaxona.\n'
        '2ª línea: piperacilina-tazobactam.\n'
        '🔑 Puntos clave: controlar evolución clínica.';

    test('PT exact device phrase remains pneumonia', () {
      final action = build(
        user: 'Paciente com pneumonia, sem sinais de sepse, choque ou '
            'instabilidade hemodinâmica. Organize a conduta.',
        response: ptPneumoniaResponse,
        language: 'pt',
      );

      expect(action.label, 'Exames e evolução');
    });

    test('ES equivalent phrase remains pneumonia', () {
      final action = build(
        user: 'Paciente con neumonía, sin signos de sepsis, shock ni '
            'inestabilidad hemodinámica. Organiza la conducta.',
        response: esPneumoniaResponse,
        language: 'es',
      );

      expect(action.label, 'Estudios y evolución');
    });

    test('PT negation in AI response remains pneumonia', () {
      final action = build(
        user: 'Organize a conduta da pneumonia comunitária.',
        response: '$ptPneumoniaResponse\n'
            'Sem sinais de sepse ou choque séptico.',
        language: 'pt',
      );

      expect(action.label, 'Exames e evolução');
    });

    test('ES negation in AI response remains pneumonia', () {
      final action = build(
        user: 'Organiza la conducta de la neumonía comunitaria.',
        response: '$esPneumoniaResponse\n'
            'No hay signos de sepsis ni shock séptico.',
        language: 'es',
      );

      expect(action.label, 'Estudios y evolución');
    });

    test('PT true septic shock remains vasopressor action', () {
      final action = build(
        user: 'Paciente com sepse, hipotensão persistente e necessidade '
            'de noradrenalina.',
        response: '🟥 CHOQUE SÉPTICO\n'
            'Lactato elevado apesar de cristaloides.',
        language: 'pt',
      );

      expect(action.label.toLowerCase(), contains('vasopressor'));
    });

    test('ES true septic shock remains vasopressor action', () {
      final action = build(
        user: 'Paciente con sepsis, hipotensión persistente y necesidad '
            'de noradrenalina.',
        response: '🟥 SHOCK SÉPTICO\n'
            'Lactato elevado pese a cristaloides.',
        language: 'es',
      );

      expect(action.label.toLowerCase(), contains('vasopresor'));
    });

    test('negated shock does not erase separate positive sepsis', () {
      final action = build(
        user: 'Sem choque, mas com sepse provável, lactato elevado e '
            'noradrenalina em curso.',
        response: '🟥 SEPSE COM HIPOPERFUSÃO',
        language: 'pt',
      );

      expect(action.label.toLowerCase(), contains('vasopressor'));
    });

    test('negated sepsis does not erase positive vasopressor evidence', () {
      final action = build(
        user: 'No hay sepsis confirmada, pero presenta lactato elevado, '
            'hipotensión y noradrenalina en curso.',
        response: '🟥 SHOCK CON HIPOPERFUSIÓN',
        language: 'es',
      );

      expect(action.label.toLowerCase(), contains('vasopresor'));
    });

    test('original pneumonia prompt remains unchanged', () {
      final action = build(
        user: 'Organize o tratamento de pneumonia comunitária em primeira '
            'linha e segunda linha, com alertas e contraindicações.',
        response: ptPneumoniaResponse,
        language: 'pt',
      );

      expect(action.label, 'Exames e evolução');
    });

    test('simple active sepsis anchor remains active', () {
      final action = build(
        user: 'Paciente com sepse e hipotensão.',
        response: '🟥 SEPSE — CONDUTA',
        language: 'pt',
      );

      expect(action.label.toLowerCase(), contains('vasopressor'));
    });
  });
}
