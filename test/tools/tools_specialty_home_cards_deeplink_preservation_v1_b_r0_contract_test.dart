import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String tools;
  late String externalLinks;
  late String calculator;
  late String toolsState;

  setUpAll(() {
    tools = File('lib/screens/tools_screen.dart').readAsStringSync();
    externalLinks =
        File('lib/services/external_tool_link_engine.dart').readAsStringSync();
    calculator = File('lib/screens/calculadora_screen.dart').readAsStringSync();
    toolsState =
        File('lib/providers/tools_state_provider.dart').readAsStringSync();
  });

  test('Ferramentas usa cards 2x2 por especialidade em linguagem Home', () {
    expect(tools, contains('Ferramentas por especialidade'));
    expect(tools, contains('Herramientas por especialidad'));
    expect(tools, contains('GridView.builder'));
    expect(tools, contains('crossAxisCount: 2'));
    expect(tools, contains('Cardiologia'));
    expect(tools, contains('Nefrologia'));
    expect(tools, contains('Eletrólitos'));
    expect(tools, contains('Hepatologia'));
  });

  test('workspace clínico de quatro áreas permanece intacto', () {
    expect(tools, contains('TabController(length: 4'));
    expect(tools, contains('const NephrologyToolsScreen()'));
    expect(tools, contains('const CardioToolsScreen()'));
    expect(tools, contains('const ElectrolytesToolsScreen()'));
    expect(tools, contains('const HepatologyToolsScreen()'));
  });

  test('notifier/deeplink continua controlando o mesmo TabController', () {
    expect(tools, contains('toolsScreenTabNotifier'));
    expect(tools, contains('tabCtrl.animateTo(index)'));
  });

  test('estado compartilhado de paciente/cache continua disponível', () {
    expect(toolsState, contains('class ToolsStateProvider'));
    expect(toolsState, contains('exportToCache'));
    expect(toolsState, contains('applyFromPatient'));
  });

  test('owners WebView/deeplink permanecem estruturalmente presentes', () {
    expect(externalLinks, contains('class ExternalToolLinkEngine'));
    expect(externalLinks, contains('_detectScore'));
    expect(calculator, contains('WebView'));
  });
}
