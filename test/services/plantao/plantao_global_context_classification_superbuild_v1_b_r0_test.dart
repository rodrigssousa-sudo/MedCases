import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/clinical_thread_manager.dart';

void main() {
  group('Plantao global context + classification superbuild V1-B-R0', () {
    test('IAM + generic classification remains in active IAM case', () {
      final manager = ClinicalThreadManager();

      final first = manager.evaluate(
        currentUserText:
            'Paciente con IAMCEST anterior confirmado, dolor torácico y elevación persistente del ST.',
        isPlantaoMode: true,
      );
      expect(first.action, ThreadAction.newThread);

      final follow = manager.evaluate(
        currentUserText: '¿Y cuál es la clasificación?',
        isPlantaoMode: true,
      );

      expect(follow.action, ThreadAction.continueThread);
    });

    test('IAM + same explicit topic remains in active IAM case', () {
      final manager = ClinicalThreadManager();

      manager.evaluate(
        currentUserText:
            'Paciente con IAMCEST anterior confirmado, dolor torácico y elevación persistente del ST.',
        isPlantaoMode: true,
      );

      for (final question in <String>[
        '¿Cuál es la clasificación del IAM?',
        '¿Y la clasificación del IAMCEST?',
        '¿Y en STEMI?',
      ]) {
        final follow = manager.evaluate(
          currentUserText: question,
          isPlantaoMode: true,
        );

        expect(follow.action, ThreadAction.continueThread, reason: question);
      }
    });

    test('STEMI active + explicit IAM remains same coronary topic', () {
      final manager = ClinicalThreadManager();

      manager.evaluate(
        currentUserText:
            'Paciente con STEMI anterior confirmado y elevación persistente del ST.',
        isPlantaoMode: true,
      );

      final follow = manager.evaluate(
        currentUserText: '¿Y en IAM cuál es la clasificación?',
        isPlantaoMode: true,
      );

      expect(follow.action, ThreadAction.continueThread);
    });

    test(
      'same coronary alias without new-case boundary remains continuation',
      () {
        final manager = ClinicalThreadManager();

        manager.evaluate(
          currentUserText:
              'Paciente con STEMI anterior confirmado y elevación persistente del ST.',
          isPlantaoMode: true,
        );

        final next = manager.evaluate(
          currentUserText: '¿Y en IAM cuál es la clasificación?',
          isPlantaoMode: true,
        );

        expect(next.action, ThreadAction.continueThread);
      },
    );

    test('same IAM pathology but explicit new patient starts new thread', () {
      final manager = ClinicalThreadManager();

      manager.evaluate(
        currentUserText:
            'Paciente con IAMCEST anterior confirmado, dolor torácico y elevación persistente del ST.',
        isPlantaoMode: true,
      );

      final next = manager.evaluate(
        currentUserText:
            'Nuevo caso: otro paciente con IAM. ¿Cuál es la clasificación?',
        isPlantaoMode: true,
      );

      expect(next.action, ThreadAction.newThread);
    });

    test('IAM to explicit diabetes classification starts new thread', () {
      final manager = ClinicalThreadManager();

      manager.evaluate(
        currentUserText:
            'Paciente con IAMCEST anterior confirmado, dolor torácico y elevación persistente del ST.',
        isPlantaoMode: true,
      );

      final next = manager.evaluate(
        currentUserText: '¿Cuál es la clasificación de diabetes mellitus?',
        isPlantaoMode: true,
      );

      expect(next.action, ThreadAction.newThread);
    });

    test('IAM to DBT shorthand starts new thread', () {
      final manager = ClinicalThreadManager();

      manager.evaluate(
        currentUserText:
            'Paciente con IAMCEST anterior confirmado, dolor torácico y elevación persistente del ST.',
        isPlantaoMode: true,
      );

      final next = manager.evaluate(
        currentUserText: '¿Y en DBT?',
        isPlantaoMode: true,
      );

      expect(next.action, ThreadAction.newThread);
    });

    test('diabetes to DBT shorthand remains same topic', () {
      final manager = ClinicalThreadManager();

      manager.evaluate(
        currentUserText:
            'Paciente con diabetes mellitus tipo 2, HbA1c 9,2% y tratamiento con metformina.',
        isPlantaoMode: true,
      );

      final next = manager.evaluate(
        currentUserText: '¿Y en DBT?',
        isPlantaoMode: true,
      );

      expect(next.action, ThreadAction.continueThread);
    });

    test('common dependent questions preserve the active pathology', () {
      final manager = ClinicalThreadManager();

      manager.evaluate(
        currentUserText:
            'Paciente con neumonía adquirida en la comunidad, fiebre, tos y consolidación basal derecha.',
        isPlantaoMode: true,
      );

      for (final question in <String>[
        '¿Y cuál es la clasificación?',
        '¿Y el tratamiento?',
        '¿Necesita internación?',
        '¿Y el pronóstico?',
      ]) {
        final status = manager.evaluate(
          currentUserText: question,
          isPlantaoMode: true,
        );

        expect(status.action, ThreadAction.continueThread, reason: question);
      }
    });

    test('different named pathology wins over prior case', () {
      final manager = ClinicalThreadManager();

      manager.evaluate(
        currentUserText:
            'Paciente con sepsis de foco urinario, hipotensión y lactato elevado.',
        isPlantaoMode: true,
      );

      final next = manager.evaluate(
        currentUserText: '¿Cuál es la clasificación del asma?',
        isPlantaoMode: true,
      );

      expect(next.action, ThreadAction.newThread);
    });

    test(
      'active topic signatures normalize underscore separators before alias matching',
      () {
        final thread = File(
          'lib/services/clinical_thread_manager.dart',
        ).readAsStringSync();

        expect(thread, contains(".replaceAll('_', ' ')"));
        expect(thread, contains("' infarto miocardio '"));
      },
    );

    test('classification and severity are transported to prompt path', () {
      final app = File('lib/providers/app_provider.dart').readAsStringSync();

      expect(app, contains('PLANTAO_GLOBAL_CLASSIFICATION_TRANSPORT_V1'));
      expect(app, contains('CLASSIFICACAO_VERIFICADA'));
      expect(app, contains('CLASIFICACION_VERIFICADA'));
      expect(app, contains('CRITERIOS_DE_GRAVIDADE'));
      expect(app, contains('CRITERIOS_DE_GRAVEDAD'));
      expect(app, contains('_appendProtocolClassificationContext'));
      expect(app, contains('matchedProtocolSummaries: qaFinalProtos,'));
      expect(app, contains('matchedProtocolSummaries: finalProtocols,'));
      expect(
        app,
        contains('qaFinalProtos = _appendProtocolClassificationContext('),
      );
      expect(
        app,
        contains('finalProtocols = _appendProtocolClassificationContext('),
      );
      expect(app, contains("'classification': protocol.classification"));
      expect(app, contains("'severityCriteria': protocol.severityCriteria"));
    });

    test(
      'prompt uses active history and blocks cross-pathology contamination',
      () {
        final ai = File('lib/services/ai_service.dart').readAsStringSync();

        expect(ai, contains('PLANTAO_GLOBAL_CONTEXT_CLASSIFICATION_POLICY_V1'));
        expect(ai, contains('novo tema tem prioridade absoluta'));
        expect(ai, contains('nuevo tema tiene prioridad absoluta'));
        expect(
          ai,
          contains('JAMAIS misturar pacientes ou patologias distintas'),
        );
        expect(ai, contains('JAMAS mezclar pacientes o patologias distintas'));
        expect(
          ai,
          isNot(
            contains(
              'JAMAS cargar datos de respuestas anteriores en la respuesta actual',
            ),
          ),
        );
        expect(
          ai,
          isNot(
            contains(
              'JAMAIS carregar dados de respostas anteriores na resposta atual',
            ),
          ),
        );
      },
    );

    test('protocol database remains owned by previous clinical work', () {
      final source = File(
        'lib/data/protocols_database.dart',
      ).readAsStringSync();

      expect(source, contains('classification:'));
      expect(source, contains('severityCriteria:'));
    });
  });
}
