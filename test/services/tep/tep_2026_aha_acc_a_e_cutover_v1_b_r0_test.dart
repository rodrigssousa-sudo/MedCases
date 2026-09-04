import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_service.dart';

void main() {
  group('TEP 2026 AHA/ACC A-E cutover V1-B-R0', () {
    late String ai;
    late String app;
    late String proto;
    late String resolver;

    setUpAll(() {
      ai = File('lib/services/ai_service.dart').readAsStringSync();
      app = File('lib/providers/app_provider.dart').readAsStringSync();
      proto = File('lib/data/protocols_database.dart').readAsStringSync();
      resolver = File(
        'lib/screens/ai/widgets/clinical_reference_resolver.dart',
      ).readAsStringSync();
    });

    test('shared AI tool says Wells is pretest only after PE confirmation', () {
      final pt = AiService.buildToolsBlock(
        'TEP confirmado, qual a classificação e tratamento?',
        false,
      );
      final es = AiService.buildToolsBlock(
        'TEP confirmado, clasificación y tratamiento',
        true,
      );

      expect(pt, contains('NÃO usar Wells para gravidade nem tratamento'));
      expect(es, contains('NO usar Wells para gravedad ni tratamiento'));
      expect(pt, contains('A, B1/B2, C1/C2/C3, D1/D2, E1/E2'));
    });

    test('Plantão deterministic guard is 2026 authority', () {
      expect(ai, contains('AUTORIDADE_FINAL_TEP_AGUDO_AHA_ACC_2026'));
      expect(ai, isNot(contains('[AUTORIDADE_FINAL_TEP_AGUDO]')));
      expect(ai, contains('D2 choque normotensivo/hipoperfusão'));
      expect(ai, contains('VA-ECMO é razoável'));
    });

    test('app local PE owner no longer governs with massive/submassive', () {
      final start = app.indexOf("id: 'tep'");
      expect(start, greaterThanOrEqualTo(0));
      final end = app.indexOf('_CliCondition(', start + 20);
      final block = app.substring(
        start,
        end > start ? end : (start + 9000).clamp(0, app.length),
      );

      expect(block, contains('AHA/ACC 2026'));
      expect(block, contains('JACC Correction 2026'));
      expect(block, isNot(contains('TEP maciço')));
      expect(block, isNot(contains('TEP submaciço')));
      expect(block, isNot(contains('ESC TEP 2019')));
      expect(block, isNot(contains('ACCP VTE 2021')));
      expect(block, isNot(contains('AHA PE 2023')));
    });

    test('canonical tep_agudo protocol carries A-E and R', () {
      final id = proto.indexOf("id: 'tep_agudo'");
      expect(id, greaterThanOrEqualTo(0));
      final next = proto.indexOf('ProtocolModel(', id + 20);
      final block = proto.substring(
        id,
        next > id ? next : (id + 24000).clamp(0, proto.length),
      );

      for (final token in <String>[
        'AHA/ACC 2026',
        'B1 — TEP subsegmentar',
        'C2 — VD anormal OU',
        'C3 — VD anormal E',
        'D2 — choque normotensivo',
        'E2 — choque cardiogênico refratário',
        'modificador R',
        '10.1016/j.jacc.2026.06.033',
      ]) {
        expect(block, contains(token), reason: token);
      }

      expect(block, isNot(contains('Classificação ESC 2019')));
      expect(block, isNot(contains('Intermediário-alto:')));
      expect(block, isNot(contains('Intermediário-baixo:')));
    });

    test('shared resolver PE case is 2026-only authority set', () {
      final start = resolver.indexOf("case 'pulmonary_embolism':");
      expect(start, greaterThanOrEqualTo(0));
      final next = resolver.indexOf("\n      case '", start + 10);
      final block = resolver.substring(
        start,
        next > start ? next : (start + 3000).clamp(0, resolver.length),
      );

      expect(block, contains('Acute Pulmonary Embolism Guideline (2026)'));
      expect(block, contains('10.1161/CIR.0000000000001415'));
      expect(block, contains('10.1016/j.jacc.2025.11.005'));
      expect(block, contains('10.1016/j.jacc.2026.06.033'));
      expect(block, isNot(contains('ESC/ERS')));
      expect(block, isNot(contains('2019')));
    });

    test('Wells calculator itself is not globally removed', () {
      final tools = File('lib/screens/tools_screen.dart').readAsStringSync();
      expect(tools, contains('Wells TEP'));
    });
  });
}
