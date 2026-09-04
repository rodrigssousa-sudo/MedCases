import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Plantao diverticular authority plus planificar renderer fix V1-B-R0', () {
    late String ai;
    late String renderer;

    setUpAll(() {
      ai = File('lib/services/ai_service.dart').readAsStringSync();
      renderer = File(
        'lib/screens/ai/widgets/guardia_clinical_response_view.dart',
      ).readAsStringSync();
    });

    test('renderer recognizes Spanish planificar and Portuguese planejar as action-like', () {
      expect(
        renderer,
        contains(
          "r'confirmar|investigar|iniciar|realizar|planificar|planejar|solicitar|'",
        ),
      );
      expect(renderer, contains("bool _isActionLikeClinicalLine(String value)"));
    });

    test('fallback remains final-only hidden when structured content exists', () {
      expect(renderer, contains('content.fallbackLines.isNotEmpty &&'));
      expect(
        renderer,
        contains('(widget.isStreaming || !content.hasStructuredContent)'),
      );
      expect(renderer, contains('_addText(fallbackLines, cleaned);'));
    });

    test('diverticulitis and diverticulosis final runtime authorities exist', () {
      expect(ai, contains('AUTORIDADE_FINAL_DIVERTICULITE_AGUDA'));
      expect(ai, contains('AUTORIDADE_FINAL_DIVERTICULOSE'));
      expect(ai, contains('AUTORIDAD_FINAL_DIVERTICULITIS_AGUDA'));
      expect(ai, contains('AUTORIDAD_FINAL_DIVERTICULOSIS'));
    });

    test('acute diverticulitis precedes asymptomatic diverticulosis', () {
      final acute = ai.indexOf('if (isAcuteDiverticulitis)');
      final diverticulosis = ai.indexOf('if (isDiverticulosis)');
      final cutaneous = ai.indexOf('if (isSjsTen)');
      expect(acute, greaterThanOrEqualTo(0));
      expect(diverticulosis, greaterThan(acute));
      expect(cutaneous, greaterThan(diverticulosis));
    });

    test('diverticulosis corrects low-fiber misinformation and avoids routine antibiotics or CT', () {
      expect(
        ai,
        contains('NAO recomendar dieta baixa em fibras como estrategia cronica da diverticulose'),
      );
      expect(ai, contains('fibra suficiente/alta'));
      expect(ai, contains('nao exige antibiotico nem TC de rotina apenas pelo achado'));
      expect(ai, contains('Nao e necessario evitar rotineiramente nozes, sementes ou pipoca'));
    });

    test('acute diverticulitis uses CT selectively and outpatient care for stable uncomplicated disease', () {
      expect(
        ai,
        contains('Se o diagnostico for incerto ou houver suspeita de complicacao'),
      );
      expect(ai, contains('TC de abdomen/pelve e o exame de imagem de escolha'));
      expect(
        ai,
        contains('Muitos pacientes estaveis com diverticulite nao complicada podem ser manejados ambulatorialmente'),
      );
    });

    test('antibiotics are selective rather than automatic in uncomplicated diverticulitis', () {
      expect(
        ai,
        contains('Antibioticos sao seletivos, NAO automaticos para todos os casos nao complicados'),
      );
      expect(ai, contains('Nao inventar esquema nem dose'));
    });

    test('complicated diverticulitis preserves source control and surgical escape', () {
      expect(ai, contains('Abscesso grande ou sem melhora pode exigir drenagem'));
      expect(
        ai,
        contains('perfuracao, peritonite, fistula ou obstrucao exigem avaliacao cirurgica/coloproctologica urgente'),
      );
      expect(ai, contains('diverticulite complicada exige internacao'));
    });

    test('previous major final runtime authorities remain present', () {
      for (final token in <String>[
        'AUTORIDADE_FINAL_MENINGITE_BACTERIANA',
        'AUTORIDADE_FINAL_CISTITE_AGUDA',
        'AUTORIDADE_FINAL_LEPTOSPIROSE',
        'AUTORIDADE_FINAL_SJS_TEN',
        'AUTORIDADE_FINAL_PNEUMONIA_ADQUIRIDA_COMUNIDADE_GRAVE',
        'AUTORIDADE_FINAL_PIELONEFRITE_ITU_SISTEMICA',
        'AUTORIDADE_FINAL_CETOACIDOSE_DIABETICA',
        'AUTORIDADE_FINAL_PANCREATITE_AGUDA_GRAVE',
        'AUTORIDADE_FINAL_VASCULITE_ANCA',
      ]) {
        expect(ai, contains(token));
      }
    });
  });
}
