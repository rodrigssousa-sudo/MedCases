import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String cardio;
  late String tools;
  late String state;
  late String externalLink;
  late String calculator;

  setUpAll(() {
    cardio = File('lib/screens/cardio_tools_screen.dart').readAsStringSync();
    tools = File('lib/screens/tools_screen.dart').readAsStringSync();
    state = File('lib/providers/tools_state_provider.dart').readAsStringSync();
    externalLink =
        File('lib/services/external_tool_link_engine.dart').readAsStringSync();
    calculator = File('lib/screens/calculadora_screen.dart').readAsStringSync();
  });

  test('pseudo PREVENT foi removido sem percentual fabricado', () {
    expect(cardio, isNot(contains('static double _prevent(')));
    expect(cardio, isNot(contains('Modelo ponderado PREVENT/ACC-AHA')));
    expect(cardio, isNot(contains('r.preventRisk')));
    expect(cardio, contains('PREVENT-ASCVD'));
    expect(cardio, contains('Não calculado'));
    expect(cardio, contains('No calculado'));
  });

  test('CHA2DS2-VA ESC 2024 e VASc paralelo', () {
    expect(cardio, contains('static int _cha2Va('));
    expect(cardio, contains('static int _cha2Vasc('));
    expect(cardio, contains('cha2VaScore'));
    expect(cardio, contains('ESC Atrial Fibrillation 2024'));
  });

  test('HAS-BLED usa nove componentes independentes', () {
    expect(cardio, contains('if (pas > 160.0) score += 1;'));
    expect(cardio, contains('hasLiverDisease'));
    expect(cardio, contains('usesBleedingRiskDrugs'));
    expect(cardio, contains('highAlcoholUse'));
    expect(cardio, contains('ageOver65'));
    expect(cardio, contains('return score.clamp(0, 9);'));
    expect(cardio, isNot(contains('usesDrugsAlcohol')));
  });

  test('QTc possui Bazett e Fridericia', () {
    expect(cardio, contains('_qtcBazett('));
    expect(cardio, contains('_qtcFridericia('));
    expect(cardio, contains('qtcFridericiaMs'));
    expect(cardio, contains('math.pow(rr, 1.0 / 3.0)'));
  });

  test('resultado é explicável', () {
    for (final token in <String>[
      'INTERPRETAÇÃO',
      'IMPLICAÇÃO CLÍNICA',
      'LIMITAÇÕES',
      'SISTEMA / FÓRMULA',
      'REFERÊNCIA'
    ]) {
      expect(cardio, contains(token));
    }
  });

  test('deeplink histórico foi preservado e enriquecido', () {
    expect(
        cardio, contains("buildQueryStringForSpecialty('cardio', langCode)"));
    expect(cardio, contains('modulo=cardiologia'));
    for (final token in <String>[
      "'cha2ds2Va'",
      "'cha2ds2Vasc'",
      "'hasBled'",
      "'qtcBazettMs'",
      "'qtcFridericiaMs'",
      "'cardioHasLiverAbnormality'"
    ]) {
      expect(cardio, contains(token));
    }
  });

  test('owners compartilhados seguem presentes', () {
    expect(tools, contains('toolsScreenTabNotifier'));
    expect(tools, contains('const CardioToolsScreen()'));
    expect(state, contains('class ToolsStateProvider'));
    expect(externalLink, contains('class ExternalToolLinkEngine'));
    expect(calculator, contains('WebView'));
  });
}
