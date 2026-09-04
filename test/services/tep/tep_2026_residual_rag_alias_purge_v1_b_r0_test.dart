import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _protocolBlock(String source, String id) {
  final marker = "id: '$id'";
  final idPos = source.indexOf(marker);
  expect(idPos, greaterThanOrEqualTo(0), reason: 'missing $id');

  final start = source.lastIndexOf('ProtocolModel(', idPos);
  expect(start, greaterThanOrEqualTo(0), reason: 'missing ProtocolModel for $id');

  final next = source.indexOf('ProtocolModel(', idPos + marker.length);
  return source.substring(start, next > start ? next : source.length);
}

void main() {
  group('TEP 2026 residual RAG alias purge V1-B-R4', () {
    late String ai;
    late String app;
    late String proto;

    setUpAll(() {
      ai = File('lib/services/ai_service.dart').readAsStringSync();
      app = File('lib/providers/app_provider.dart').readAsStringSync();
      proto = File('lib/data/protocols_database.dart').readAsStringSync();
    });

    test('both productive PE protocol ids are AHA ACC 2026', () {
      for (final id in <String>['tep_agudo', 'tromboembolismo_pulmonar']) {
        final block = _protocolBlock(proto, id);

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
          expect(block, contains(token), reason: '$id :: $token');
        }

        for (final stale in <String>[
          'Classificação ESC 2019',
          'Clasificación ESC 2019',
          'Intermediário-alto',
          'Intermediário-baixo',
          'Intermedio-alto',
          'Intermedio-bajo',
          'TEP maciço',
          'TEP masivo',
          'ESC Guidelines on PE',
        ]) {
          expect(block.toLowerCase(), isNot(contains(stale.toLowerCase())),
              reason: '$id :: $stale');
        }
      }
    });

    test('legacy protocol id is explicit 2026 compatibility alias', () {
      final block = _protocolBlock(proto, 'tromboembolismo_pulmonar');
      expect(block, contains('TEP_2026_COMPATIBILITY_ALIAS'));
      expect(block, contains("id: 'tromboembolismo_pulmonar'"));
    });

    test('productive app no longer carries massive/submassive PE labels', () {
      expect(app, isNot(contains('TEP maciço')));
      expect(app, isNot(contains('TEP submaciço')));
      expect(app, contains('AHA/ACC D/E'));
    });

    test('authoritative AI guard uses only A-E plus R after confirmation', () {
      final marker = ai.indexOf('AUTORIDADE_FINAL_TEP_AGUDO_AHA_ACC_2026');
      expect(marker, greaterThanOrEqualTo(0));
      final end = ai.indexOf('final isAcuteSevereAsthma', marker);
      final fallbackEnd =
          marker + 12000 > ai.length ? ai.length : marker + 12000;
      final block = ai.substring(
        marker,
        end > marker ? end : fallbackEnd,
      );

      expect(
        block,
        contains(
          'NÃO usar Wells como classificador de gravidade nem como decisor terapêutico',
        ),
      );
      expect(block, contains('AHA/ACC 2026 A-E'));
      expect(block, contains('modificador R'));
      expect(block, isNot(contains('maciço/submaciço')));
      expect(block, isNot(contains('intermediário-alto/intermediário-baixo')));
    });

    test('Study and Plantao both receive matched protocol summaries', () {
      expect(app, contains('matchedProtocolSummaries: finalProtocols'));
      expect(app, contains('isPlantaoMode: !longResponse'));
      expect(app, contains('_matchProtocolsExtended('));
      expect(app, contains('_matchProtocols('));
      expect(app, contains('for (final p in protocolsDatabase)'));
    });

    test('Wells diagnostic calculator remains available', () {
      final tools = File('lib/screens/tools_screen.dart').readAsStringSync();
      expect(tools, contains('Wells TEP'));
    });
  });
}
