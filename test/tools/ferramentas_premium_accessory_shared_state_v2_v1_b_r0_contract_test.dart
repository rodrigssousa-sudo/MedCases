import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();

void main() {
  late String provider;
  late String nefro;
  late String cardio;
  late String electro;
  late String hepato;
  late List<String> tabs;

  setUpAll(() {
    provider = read('lib/providers/tools_state_provider.dart');
    nefro = read('lib/screens/nephrology_tools_screen.dart');
    cardio = read('lib/screens/cardio_tools_screen.dart');
    electro = read('lib/screens/electrolytes_tools_screen.dart');
    hepato = read('lib/screens/hepatology_tools_screen.dart');
    tabs = [nefro, cardio, electro, hepato];
  });

  test(
      'premium accessory explicitly removes inherited underline and adds restrained affordance',
      () {
    for (final source in tabs) {
      expect(source, contains('decoration: TextDecoration.none'));
      expect(source, contains('decorationColor: Colors.transparent'));
      expect(source, contains('Icons.arrow_forward_rounded'));
      expect(source, contains('Icons.check_rounded'));
      expect(source, contains('blurRadius: 8'));
      expect(source, contains('offset: const Offset(0, 3)'));
      expect(source, contains('height: 40'));
      expect(source, contains('BorderRadius.circular(20)'));
    }
  });

  test('provider cache covers shared height and gasometry', () {
    for (final token in const <String>[
      "_set(heightCtrl, 'altura');",
      "_set(phCtrl,     'ph');",
      "_set(pco2Ctrl,   'pco2');",
      "_set(beCtrl,     'be');",
      "'altura':      heightCtrl.text",
      "'ph':          phCtrl.text",
      "'pco2':        pco2Ctrl.text",
      "'be':          beCtrl.text",
    ]) {
      expect(provider, contains(token), reason: token);
    }
  });

  test('pending data covers every shared text controller', () {
    final start = provider
        .indexOf('late final List<TextEditingController> _primaryCtrls');
    final end = provider.indexOf('];', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final block = provider.substring(start, end + 2);
    for (final name in const <String>[
      'ageCtrl',
      'weightCtrl',
      'heightCtrl',
      'naCtrl',
      'crCtrl',
      'clCtrl',
      'hco3Ctrl',
      'glucCtrl',
      'caCtrl',
      'bunCtrl',
      'phCtrl',
      'pco2Ctrl',
      'beCtrl',
      'albCtrl',
      'biliCtrl',
      'inrCtrl',
      'astCtrl',
      'altCtrl',
      'platCtrl',
      'pasCtrl',
      'colCtrl',
      'qtCtrl',
      'fcCtrl',
    ]) {
      expect(block, contains(name), reason: name);
    }
  });

  test('Nefrologia current serum creatinine shares Hepatologia crCtrl', () {
    expect(nefro, isNot(contains('_creatCurrCtrl')));
    expect(nefro, contains('final creatCurr = _pd(tp.crCtrl.text);'));
    expect(nefro, contains("'creatinina_atual': tp2.crCtrl.text"));
    expect(nefro, contains("['creatinina_basal']"));
    expect(hepato,
        contains('creatCtrl: context.read<ToolsStateProvider>().crCtrl'));
  });

  test(
      'patient selection hydrates age and sex into canonical provider from all tabs',
      () {
    for (final source in tabs) {
      expect(source, contains('.applyFromPatient('));
      expect(source, contains('parseAgeFromString(paciente.idade)'));
      expect(source, contains("paciente.sexo.trim().toUpperCase()"));
      expect(source, contains('context.watch<ToolsStateProvider>()'));
    }
  });

  test('specialty-only data remains local', () {
    for (final token in const [
      '_creatBaseCtrl',
      '_naUrineCtrl',
      '_creatUrineCtrl',
      '_NephroEngine.compute('
    ]) {
      expect(nefro, contains(token));
    }
    for (final token in const [
      '_hasDiabetes',
      '_hasHtn',
      '_hadStroke',
      '_CardioEngine.compute('
    ]) {
      expect(cardio, contains(token));
    }
    expect(electro, contains('_ElectroEngine.compute('));
    for (final token in const [
      '_noduleCountCtrl',
      '_tpPatientCtrl',
      '_faCtrl',
      '_HepEngine.compute('
    ]) {
      expect(hepato, contains(token));
    }
  });

  test('keyboard viewport and localized labels remain preserved', () {
    for (final source in tabs) {
      expect(source, contains('return 16.0 + safeBottom;'));
      expect(source, contains('return 114.0 + safeBottom;'));
      expect(source, contains('Scrollable.ensureVisible('));
      expect(
          source, contains("last ? 'OK' : (isEs ? 'SIGUIENTE' : 'PRÓXIMO')"));
    }
  });
}
