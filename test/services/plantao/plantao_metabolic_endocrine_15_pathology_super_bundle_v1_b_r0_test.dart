import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Plantão metabolic endocrine 15-pathology super bundle V1-B-R0', () {
    late String source;

    setUpAll(() {
      source = File('lib/services/ai_service.dart').readAsStringSync();
    });

    test('all fifteen metabolic endocrine authority guards exist', () {
      for (final token in <String>[
        'AUTORIDADE_FINAL_CETOACIDOSE_DIABETICA',
        'AUTORIDADE_FINAL_ESTADO_HIPEROSMOLAR',
        'AUTORIDADE_FINAL_HIPOGLICEMIA_GRAVE',
        'AUTORIDADE_FINAL_HIPERCALEMIA',
        'AUTORIDADE_FINAL_HIPOCALEMIA',
        'AUTORIDADE_FINAL_HIPONATREMIA_SINTOMATICA_GRAVE',
        'AUTORIDADE_FINAL_HIPERNATREMIA',
        'AUTORIDADE_FINAL_CRISE_HIPERCALCEMICA',
        'AUTORIDADE_FINAL_HIPOCALCEMIA_SINTOMATICA',
        'AUTORIDADE_FINAL_HIPOMAGNESEMIA_GRAVE',
        'AUTORIDADE_FINAL_HIPERMAGNESEMIA',
        'AUTORIDADE_FINAL_HIPOFOSFATEMIA_REALIMENTACAO',
        'AUTORIDADE_FINAL_TEMPESTADE_TIREOIDIANA',
        'AUTORIDADE_FINAL_COMA_MIXEDEMATOSO',
        'AUTORIDADE_FINAL_CRISE_ADRENAL',
      ]) {
        expect(source, contains(token));
      }
    });

    test('DKA uses 2024 three-component diagnosis and beta hydroxybutyrate', () {
      expect(source, contains('diagnostico exige os tres componentes'));
      expect(source, contains('diabetes/hiperglicemia, cetose e acidose metabolica'));
      expect(source, contains('priorizar beta-hidroxibutirato'));
    });

    test('DKA potassium gate precedes insulin and dextrose permits ongoing ketone clearance', () {
      expect(source, contains('Avaliar K ANTES da insulina'));
      expect(source, contains('adiar insulina ate faixa segura'));
      expect(source, contains('acrescentar dextrose para continuar insulina ate resolver cetose/acidose'));
    });

    test('DKA avoids anion gap only resolution and preserves existing safety contract', () {
      expect(source, contains('NAO usar anion gap isolado como criterio final'));
      expect(source, contains('Preservar todas as restricoes do DkahhsRuntimeSafetyContract existente'));
      expect(source, contains('Bicarbonato NAO e rotina'));
    });

    test('HHS prioritizes fluids osmolality and potassium safety', () {
      expect(source, contains('Reposicao de volume e prioridade'));
      expect(source, contains('evitando mudancas osmoticas rapidas demais'));
      expect(source, contains('Insulina IV e iniciada apos reposicao inicial de volume e com K seguro'));
    });

    test('severe hypoglycemia uses level three functional definition', () {
      expect(source, contains('Nivel 3 e definido por alteracao mental/fisica que exige ajuda de outra pessoa'));
      expect(source, contains('independentemente do valor de glicose'));
    });

    test('severe hypoglycemia separates oral from IV glucose or glucagon', () {
      expect(source, contains('capaz de deglutir: carboidrato de absorcao rapida'));
      expect(source, contains('glicose IV se houver acesso'));
      expect(source, contains('glucagon parenteral/intranasal'));
      expect(source, contains('nao oferecer alimento oral'));
    });

    test('hyperkalemia separates membrane stabilization shift and removal', () {
      expect(source, contains('calcio IV estabiliza membrana, mas NAO reduz K'));
      expect(source, contains('insulina + glicose e beta2-agonista'));
      expect(source, contains('Bicarbonato NAO e tratamento rotineiro salvo acidose metabolica relevante'));
      expect(source, contains('hemodialise na hipercalemia grave/refrataria'));
    });

    test('hyperkalemia includes rebound monitoring and rejects number only authority', () {
      expect(source, contains('Repetir K para detectar rebote'));
      expect(source, contains('Nao usar numero isolado como unica autoridade'));
    });

    test('hypokalemia prefers oral and never IV push', () {
      expect(source, contains('Via oral e preferida'));
      expect(source, contains('K IV fica para hipocalemia grave'));
      expect(source, contains('NUNCA administrar K IV em push/bolus'));
      expect(source, contains('Corrigir hipomagnesemia concomitante'));
    });

    test('symptomatic hyponatremia uses 3 percent saline and small initial rise', () {
      expect(source, contains('solucao salina hipertonica 3%'));
      expect(source, contains('aproximadamente 4-6 mmol/L'));
      expect(source, contains('NAO normalizar sodio rapidamente'));
    });

    test('hyponatremia guards ODS and provides relowering route', () {
      expect(source, contains('desmielinizacao osmotica'));
      expect(source, contains('evitar aumentos >10 mmol/L nas primeiras 24 h'));
      expect(source, contains('~8 mmol/L/24 h'));
      expect(source, contains('desmopressina + agua livre/D5W'));
    });

    test('hypernatremia treats shock first then free water and distinguishes chronic', () {
      expect(source, contains('restaurar primeiro perfusao com cristaloide isotonico'));
      expect(source, contains('depois repor agua livre'));
      expect(source, contains('10-12 mmol/L em 24 h'));
      expect(source, contains('aguda sintomatica por carga de sodio pode exigir correcao mais rapida'));
    });

    test('hypercalcemic crisis uses fluids calcitonin and antiresorptive therapy', () {
      expect(source, contains('calcitonina oferece queda rapida mas transitoria'));
      expect(source, contains('bisfosfonato IV ou denosumabe'));
      expect(source, contains('nao usar diuretico de alca antes de corrigir hipovolemia'));
    });

    test('symptomatic hypocalcemia uses IV calcium and magnesium correction', () {
      expect(source, contains('calcio IV, preferencialmente gluconato'));
      expect(source, contains('Corrigir hipomagnesemia concomitante'));
      expect(source, contains('QT prolongado'));
    });

    test('severe hypomagnesemia routes torsades and refractory potassium', () {
      expect(source, contains('Sintomas graves ou arritmia/torsades: administrar magnesio IV'));
      expect(source, contains('hipocalemia pode ser refrataria ate corrigir Mg'));
    });

    test('hypermagnesemia stops magnesium gives calcium and selects dialysis', () {
      expect(source, contains('Suspender toda fonte de Mg'));
      expect(source, contains('calcio IV como antagonista fisiologico'));
      expect(source, contains('Hemodialise e tratamento definitivo na toxicidade grave'));
    });

    test('refeeding route uses thiamine slow calories and electrolyte monitoring', () {
      expect(source, contains('administrar tiamina antes ou junto do aporte calorico'));
      expect(source, contains('iniciar nutricao de forma reduzida/progressiva'));
      expect(source, contains('medir P/K/Mg'));
      expect(source, contains('reduzir/pausar escalonamento calorico'));
    });

    test('thyroid storm preserves treatment order and beta blocker caution', () {
      expect(source, contains('administrar iodo DEPOIS da tionamida'));
      expect(source, contains('evitar aspirina'));
      expect(source, contains('beta-bloqueio agressivo pode precipitar colapso'));
    });

    test('myxedema coma uses ICU steroid before thyroid hormone and cautious warming', () {
      expect(source, contains('Administrar glicocorticoide de estresse antes ou junto da reposicao tireoidiana'));
      expect(source, contains('Levotiroxina IV e o tratamento hormonal principal'));
      expect(source, contains('Reaquecimento deve ser passivo/cauteloso'));
    });

    test('adrenal crisis treatment is not delayed for cortisol ACTH', () {
      expect(source, contains('colher cortisol e ACTH antes do corticoide'));
      expect(source, contains('nunca atrasar tratamento salvador por laboratorio'));
      expect(source, contains('Administrar hidrocortisona parenteral imediatamente'));
    });

    test('metabolic guards precede cardiac guards to preserve causal precedence', () {
      final adrenal = source.indexOf('if (isAdrenalCrisis)');
      final dka = source.indexOf('if (isDka)');
      final cardiac = source.indexOf('if (isAcuteAorticSyndrome)');
      expect(adrenal, greaterThanOrEqualTo(0));
      expect(dka, greaterThan(adrenal));
      expect(cardiac, greaterThan(dka));
    });

    test('all previous major bundles remain present', () {
      for (final token in <String>[
        'AUTORIDADE_FINAL_PANCREATITE_AGUDA_GRAVE',
        'AUTORIDADE_FINAL_LESAO_RENAL_AGUDA',
        'AUTORIDADE_FINAL_SINDROME_AORTICA_AGUDA',
        'AUTORIDADE_FINAL_HEMOPTISE_AMEACADORA_VIDA',
        'AUTORIDADE_FINAL_APENDICITE_AGUDA',
        'AUTORIDADE_FINAL_TAMPONAMENTO_CARDIACO_TRAUMATICO',
      ]) {
        expect(source, contains(token));
      }
    });
  });
}
