import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/services/ai_next_action_engine.dart').readAsStringSync();
  });

  group('NextActionEngine ES/PT contract', () {
    test('fallback Guardia localiza os três rótulos', () {
      expect(
        source,
        contains(
          "label: es ? 'Conductas y dosis' : "
          "'Condutas e dosagens'",
        ),
      );
      expect(
        source,
        contains(
          "label: es ? 'Estudios y evolución' : "
          "'Exames e evolução'",
        ),
      );
      expect(
        source,
        isNot(
          contains(
            "label: es ? 'Preguntas importantes' : "
            "'Perguntas importantes'",
          ),
        ),
      );
    });

    test('fallback Guardia sem tópico permanece em espanhol', () {
      expect(
        source,
        contains(
          '¿Cuáles son las conductas clínicas inmediatas '
          'y las dosis recomendadas para este caso de urgencia?',
        ),
      );
      expect(
        source,
        isNot(
          contains(
            "es ? 'Condutas e dosagens' : "
            "'Condutas e dosagens'",
          ),
        ),
      );
    });

    test('mapa Guardia localiza rótulos específicos', () {
      const expectedSpanishLabels = <String>[
        'Doble antiagregación: dosis',
        'Fibrinólisis: dosis por peso',
        'Titulación de vasopresores',
        'Paquete de la primera hora: estudios',
        'Algoritmo ACLS desfibrilable',
        'Manejo de causas: 5H y 5T',
        'Dosis de secuencia rápida',
      ];

      for (final label in expectedSpanishLabels) {
        expect(source, contains(label), reason: 'rótulo ES ausente: $label');
      }
    });

    test('mapa Estudo localiza terminologia espanhola', () {
      const expectedSpanishLabels = <String>[
        'IAMCEST × IAMSEST: diagnóstico',
        'Escalas de riesgo y pronóstico',
        'Criterios Sepsis-3 y SOFA',
        'ISRS × IRSN: farmacodinámica',
      ];

      for (final label in expectedSpanishLabels) {
        expect(source, contains(label), reason: 'rótulo ES ausente: $label');
      }
    });

    test('prompts específicos não repetem o português no ramo ES', () {
      const forbiddenSpanishFragments = <String>[
        "promptToSend: es ? 'Doses de AAS",
        "promptToSend: es ? 'Doses por peso",
        "promptToSend: es ? 'Dose e titulação",
        "promptToSend: es ? 'Bundle hora 1",
        "promptToSend: es ? 'PCR em FV/TVSP",
        "promptToSend: es ? 'Causas reversíveis",
        "promptToSend: es ? 'SRI: doses",
        "promptToSend: es ? 'Diferença fisiopatológica",
        "promptToSend: es ? 'Variáveis e valor",
        "promptToSend: es ? 'Critérios Sepsis-3",
        "promptToSend: es ? 'Comparativo entre ISRS",
      ];

      for (final fragment in forbiddenSpanishFragments) {
        expect(
          source,
          isNot(contains(fragment)),
          reason: 'prompt português no ramo ES: $fragment',
        );
      }
    });

    test('complicaciones y alertas mantém paridade ES/PT atual', () {
      final labelPair = RegExp(
        r"label:\s*es\s*\?\s*'Complicaciones y alertas'\s*:\s*'Complicações e alertas'",
        multiLine: true,
      );

      expect(labelPair.hasMatch(source), isTrue);
      expect(
        source,
        contains(
          r'Explica las complicaciones de $topicName, señales de alarma y errores clínicos',
        ),
      );
    });

    test('ramos portugueses continuam presentes', () {
      const expectedPortugueseLabels = <String>[
        'Condutas e dosagens',
        'Exames e evolução',
        'Dupla antiagregação: doses',
        'Fibrinólise: dose por peso',
        'Titulação de vasopressores',
        'Doses da Sequência Rápida',
        'Escores de risco e prognóstico',
      ];

      for (final label in expectedPortugueseLabels) {
        expect(source, contains(label), reason: 'rótulo PT ausente: $label');
      }
    });
  });
}
