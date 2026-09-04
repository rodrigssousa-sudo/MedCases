import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String gateway;

  setUpAll(() {
    gateway =
        File('lib/services/ai_gateway_service.dart').readAsStringSync();
  });

  group('Final physical blockers closure V1-B-R0', () {
    test('M14 separates shockable and nonshockable rhythms', () {
      expect(
        gateway,
        contains(
          'ASSISTOLIA/AESP = NÃO CHOCÁVEL; FV/TVSP = CHOCÁVEL',
        ),
      );
      expect(
        gateway,
        contains(
          'ASSISTOLIA/AESP: NÃO indicar desfibrilação/choque',
        ),
      );
      expect(
        gateway,
        contains(
          'Adrenalina 1 mg IV/IO o mais cedo possível',
        ),
      );
      expect(
        gateway,
        contains('repetir a cada 3–5 min'),
      );
      expect(
        gateway,
        contains(
          'Choque/desfibrilação e amiodarona pertencem '
          'SOMENTE ao ramo FV/TVSP',
        ),
      );
    });

    test('PT question follow-up cannot become immediate management', () {
      expect(
        gateway,
        contains(
          "normalizedFollowUpRequest.contains('perguntas')",
        ),
      );
      expect(
        gateway,
        contains(
          'Responda EXATAMENTE 10 perguntas clínicas, '
          'em português, uma por linha',
        ),
      );
      expect(
        gateway,
        contains(
          'Use como único cabeçalho de seção: '
          '"Perguntas-chave:"',
        ),
      );
      expect(
        gateway,
        contains(
          'NÃO use "Conduta imediata", "Conducta inmediata"',
        ),
      );
    });

    test('ES question follow-up cannot leak PT or become management', () {
      expect(
        gateway,
        contains(
          "normalizedFollowUpRequest.contains('preguntas')",
        ),
      );
      expect(
        gateway,
        contains(
          'Responde EXACTAMENTE 10 preguntas clínicas, '
          'en español, una por línea',
        ),
      );
      expect(
        gateway,
        contains(
          'Usa como único encabezado de sección: '
          '"Preguntas clave:"',
        ),
      );
      expect(
        gateway,
        contains(
          'NO uses "Conduta inmediata", "Conducta inmediata"',
        ),
      );
    });

    test('general follow-up liberty path remains present', () {
      expect(
        gateway,
        contains('ESTÁS COMPLETAMENTE LIBERADO'),
      );
      expect(
        gateway,
        contains('VOCÊ ESTÁ COMPLETAMENTE LIBERADO'),
      );
    });

    test('canonical cutover authority remains unique', () {
      expect(
        'PlantaoCanonicalRouteResolver.resolveAnalysis('
            .allMatches(gateway)
            .length,
        1,
      );
      expect(
        'observeLegacy: false,'.allMatches(gateway).length,
        1,
      );
      expect(
        gateway,
        contains(
          'canonicalDecision.contract?.legacyMatrixNumber',
        ),
      );
      expect(
        gateway,
        contains(
          'forcedMatrixNumber: canonicalMatrixNumber',
        ),
      );
    });
  });
}
