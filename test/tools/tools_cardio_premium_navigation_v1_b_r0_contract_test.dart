import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String tools;
  late String cardio;
  late String hub;
  late String workspace;
  late String detail;
  late String acuteEngine;
  late String chronicEngine;

  setUpAll(() {
    tools = File('lib/screens/tools_screen.dart').readAsStringSync();
    cardio = File('lib/screens/cardio_tools_screen.dart').readAsStringSync();
    hub = File('lib/widgets/cardio/cardio_acute_risk_hub.dart')
        .readAsStringSync();
    workspace = File('lib/screens/cardio_premium_workspace_screen.dart')
        .readAsStringSync();
    detail =
        File('lib/screens/cardio_score_detail_screen.dart').readAsStringSync();
    acuteEngine = File('lib/services/cardio/cardio_acute_risk_engine_2026.dart')
        .readAsStringSync();
    chronicEngine =
        File('lib/services/cardio/cardio_chronic_score_engine_2026.dart')
            .readAsStringSync();
  });

  test('Ferramentas segue hub e Cardiologia abre rota dedicada', () {
    expect(tools, contains('CardioPremiumWorkspaceScreen'));
    expect(tools, contains('_openToolsSpecialtyRoute(context, index)'));
  });

  test('Cardiologia é catálogo plano por seções sem contexto intermediário',
      () {
    expect(workspace, contains('SCA · DOLOR TORÁCICO'));
    expect(workspace, contains('FA · TROMBOEMBOLIA · SANGRADO'));
    expect(workspace, contains('ECG · REPOLARIZACIÓN'));
    expect(workspace, contains('PREVENCIÓN PRIMARIA'));

    expect(workspace, contains("title: 'HEART'"));
    expect(workspace, contains("title: 'TIMI'"));
    expect(workspace, contains("title: 'GRACE'"));
    expect(workspace, contains("title: 'Killip'"));
    expect(workspace, contains("title: 'CHA₂DS₂-VA'"));
    expect(workspace, contains("title: 'CHA₂DS₂-VASc'"));
    expect(workspace, contains("title: 'HAS-BLED'"));
    expect(workspace, contains("title: 'QTc Bazett'"));
    expect(workspace, contains("title: 'QTc Fridericia'"));
    expect(workspace, contains("title: 'PREVENT-ASCVD'"));

    expect(workspace, isNot(contains('FA · sangrado · QTc')));
    expect(workspace, isNot(contains('SCA · dolor torácico')));
  });

  test('cada card abre diretamente CardioScoreDetailScreen', () {
    expect(workspace, contains('CardioScoreDetailScreen('));
    expect(workspace, contains('scoreId: item.id'));
    expect(workspace, contains('Navigator.of(context).push('));
  });

  test('tela do score usa topbar Cardiologia + importação imediatamente abaixo',
      () {
    expect(detail, contains("title: isEs ? 'CARDIOLOGÍA' : 'CARDIOLOGIA'"));
    expect(detail, contains('const SizedBox(height: 1)'));
    expect(detail, contains("Key('cardio_import_patient')"));
    expect(detail, contains('Importar datos del paciente'));
    expect(detail, contains("buildQueryStringForSpecialty('cardio', lang)"));
    expect(detail, contains('modulo=cardiologia'));
  });

  test('resultado e explicação ficam após cálculo', () {
    expect(detail, contains("Key('cardio_score_calculate')"));
    expect(detail, contains("Key('cardio_score_result')"));
    expect(detail, contains('USO Y LIMITACIONES'));
    expect(detail, contains('REFERENCIA'));
    expect(detail, contains("Key('cardio_score_open_calculator')"));
  });

  test('motores F2A/F2B permanecem clinicamente representados', () {
    for (final token in <String>[
      'HeartScoreInput',
      'TimiUaNstemiInput',
      'GraceAdmissionInput',
      'KillipResult',
      'Do NOT infer GRACE 2.0 probabilities',
    ]) {
      expect(acuteEngine, contains(token));
    }

    for (final token in <String>[
      'cha2Ds2Va',
      'cha2Ds2Vasc',
      'hasBled',
      'bazett',
      'fridericia',
    ]) {
      expect(chronicEngine, contains(token));
    }

    expect(cardio, contains('CHA₂DS₂-VA'));
    expect(hub, contains('HEART'));
  });

  test('visual usa verde MedCases e não cria azul primário', () {
    expect(workspace, contains('0xFF009C3B'));
    expect(detail, contains('0xFF009C3B'));
    expect(workspace, isNot(contains('0xFF3B82F6')));
    expect(detail, isNot(contains('0xFF3B82F6')));
  });
}
