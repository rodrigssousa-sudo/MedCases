import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Study gold presentation identity hidden V1-B-R3', () {
    test('Study oculta identidade redundante no call-site da resposta', () {
      final source = File('lib/screens/ai_screen.dart').readAsStringSync();

      expect(source, contains('visible: !_longResponse'));
      expect(source, contains('_AiResponseIdentityHeader('));

      // Owner legado continua existente para caminhos não-Study.
      expect(
        source,
        contains("isEs ? 'GENERANDO RESPUESTA' : 'GERANDO RESPOSTA'"),
      );
      expect(
        source,
        contains("isEs ? 'RESPUESTA COMPLETADA' : 'RESPOSTA CONCLUÍDA'"),
      );
    });

    test('preserva pergunta oculta e continuação didática do Estudo', () {
      final source = File('lib/screens/ai_screen.dart').readAsStringSync();

      expect(source, contains('study_user_hidden'));
      expect(source, contains('StudyContinuationResolver.resolve('));
      expect(source, contains('StudyContinuationButton('));
    });

    test('preserva renderer dedicado do Plantão e AiBubble do Estudo', () {
      final source = File('lib/screens/ai_screen.dart').readAsStringSync();

      expect(source, contains('GuardiaClinicalResponseView('));
      expect(source, contains('AiBubble('));
    });
  });
}
