import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Plantão renal emergencies 10-pathology super bundle V1-B-R0', () {
    late String source;

    setUpAll(() {
      source = File('lib/services/ai_service.dart').readAsStringSync();
    });

    test('all ten renal authority guards exist', () {
      for (final token in <String>[
        'AUTORIDADE_FINAL_UREMIA_DIALISE_EMERGENTE',
        'AUTORIDADE_FINAL_GNRP_SINDROME_PULMAO_RIM',
        'AUTORIDADE_FINAL_INFARTO_RENAL_AGUDO',
        'AUTORIDADE_FINAL_RABDOMIOLISE_RISCO_RENAL',
        'AUTORIDADE_FINAL_SINDROME_NEFROTICA_COMPLICADA',
        'AUTORIDADE_FINAL_SINDROME_NEFRITICA_GLOMERULONEFRITE',
        'AUTORIDADE_FINAL_RETENCAO_URINARIA_AGUDA',
        'AUTORIDADE_FINAL_COLICA_RENAL_URETEROLITIASE',
        'AUTORIDADE_FINAL_PIELONEFRITE_ITU_SISTEMICA',
        'AUTORIDADE_FINAL_LESAO_RENAL_AGUDA',
      ]) {
        expect(source, contains(token));
      }
    });

    test('uremic emergency uses clinical refractory KRT indications not rigid numbers', () {
      expect(source, contains('NAO deve se basear em valor isolado de creatinina, ureia ou TFGe'));
      expect(source, contains('alteracoes potencialmente letais e refratarias'));
      expect(source, contains('encefalopatia/pericardite'));
      expect(source, contains('Nao usar limiares rigidos como K>6,5, pH<7,1'));
    });

    test('RPGN pulmonary renal syndrome has urgent serologies and biopsy route', () {
      expect(source, contains('ANCA PR3/MPO, anti-GBM, C3/C4, ANA'));
      expect(source, contains('Biopsia renal urgente'));
      expect(source, contains('NAO deve atrasar tratamento salvador'));
    });

    test('anti GBM and ANCA treatment distinction is preserved', () {
      expect(source, contains('glicocorticoide + ciclofosfamida + troca plasmatica'));
      expect(source, contains('glicocorticoide + rituximabe ou ciclofosfamida conforme KDIGO 2024'));
      expect(source, contains('troca plasmatica NAO e rotina para todos'));
      expect(source, contains('sobreposicao anti-GBM'));
    });

    test('renal infarction gets contrast CTA and etiologic workup', () {
      expect(source, contains('TC contrastada/angio-TC renal precocemente'));
      expect(source, contains('ECG/monitorizacao para FA'));
      expect(source, contains('Na etiologia tromboembolica sem contraindicacao, anticoagulacao sistemica'));
    });

    test('renal infarction selected early revascularization has no universal window', () {
      expect(source, contains('rim unico viavel pode justificar avaliacao endovascular urgente'));
      expect(source, contains('nao existe janela universal aplicavel a todos'));
    });

    test('rhabdomyolysis uses CK electrolytes and goal directed isotonic crystalloid', () {
      expect(source, contains('Medir CK seriada, creatinina, K, fosforo, Ca, bicarbonato e diurese'));
      expect(source, contains('cristaloide isotonico precocemente de forma guiada por resposta/diurese'));
      expect(source, contains('evitando sobrecarga'));
    });

    test('rhabdomyolysis rejects routine bicarbonate mannitol diuretics and preventive dialysis', () {
      expect(source, contains('NAO usar bicarbonato, manitol ou diureticos rotineiramente'));
      expect(source, contains('NAO iniciar dialise apenas para remover mioglobina ou por CK elevada'));
    });

    test('nephrotic syndrome identifies thrombosis infection AKI and avoids routine albumin', () {
      expect(source, contains('trombose venosa/TEP, infeccao, LRA'));
      expect(source, contains('albumina IV + diuretico NAO e rotina'));
      expect(source, contains('Profilaxia anticoagulante primaria deve ser individualizada'));
    });

    test('nephritic syndrome uses glomerular sediment complement serology and biopsy', () {
      expect(source, contains('hematuria dismorfica/cilindros hematicos'));
      expect(source, contains('C3/C4 e sorologias direcionadas'));
      expect(source, contains('Biopsia renal e central'));
      expect(source, contains('NAO iniciar corticoide ou imunossupressao empirica rotineiramente'));
    });

    test('acute urinary retention promptly decompresses and protects suspected urethral injury', () {
      expect(source, contains('descomprimir prontamente a bexiga com cateter uretral'));
      expect(source, contains('evitar tentativas repetidas de sondagem cega'));
      expect(source, contains('uretrografia retrograda'));
      expect(source, contains('diurese pos-obstrutiva'));
    });

    test('renal colic uses NSAID first line and no antibiotics without infection', () {
      expect(source, contains('Analgesia com AINE e primeira linha'));
      expect(source, contains('Nao indicar antibioticos sem evidencia de infeccao'));
      expect(source, contains('TC sem contraste e o exame mais preciso'));
    });

    test('renal colic MET is limited to selected distal stones above five mm', () {
      expect(source, contains('calculos ureterais distais >5 mm'));
      expect(source, contains('uso e off-label conforme EAU'));
      expect(source, contains('rim unico obstruido'));
      expect(source, contains('Nao forcar hidratacao excessiva'));
    });

    test('pyelonephritis uses cultures antibiotics and complication imaging', () {
      expect(source, contains('colher urocultura antes de antibioticos'));
      expect(source, contains('hemoculturas se sepse/doenca grave'));
      expect(source, contains('Iniciar antibiotico empirico conforme gravidade'));
      expect(source, contains('Procurar obstrucao/abscesso'));
    });

    test('pyelonephritis explicitly escalates infected obstruction to existing decompression guard', () {
      expect(source, contains('ativar descompressao urinaria urgente com stent ou nefrostomia'));
      expect(source, contains('ja coberta pelo guard especifico'));
    });

    test('AKI is staged by creatinine trend and urine output not single creatinine', () {
      expect(source, contains('tendencia de creatinina e diurese conforme criterios KDIGO vigentes'));
      expect(source, contains('creatinina unica nao define cronologia nem causa'));
    });

    test('AKI evaluates causes and avoids reflex fluid and cosmetic diuresis', () {
      expect(source, contains('causas pre-renais/hemodinamicas, intrinsecas e pos-renais'));
      expect(source, contains('NAO administrar bolus repetidos automaticamente'));
      expect(source, contains('Diureticos NAO tratam a LRA nem aceleram recuperacao'));
      expect(source, contains('diurese cosmetica'));
    });

    test('AKI dialysis authority is clinical and 2026 update is identified as draft', () {
      expect(source, contains('NAO por creatinina/BUN isolados'));
      expect(source, contains('atualizacao KDIGO AKI/AKD 2026 esta em rascunho de revisao publica'));
      expect(source, contains('nao apresenta-la como guideline final publicada'));
    });

    test('infected obstructed kidney stays before the new renal bundle', () {
      final infected = source.indexOf('if (isInfectedObstructedKidney)');
      final uremic = source.indexOf('if (isUremicEmergency)');
      final pyelo = source.indexOf('if (isAcutePyelonephritis)');
      final aki = source.indexOf('if (isAcuteKidneyInjury)');
      expect(infected, greaterThanOrEqualTo(0));
      expect(uremic, greaterThan(infected));
      expect(pyelo, greaterThan(uremic));
      expect(aki, greaterThan(pyelo));
    });

    test('renal high specificity order keeps RPGN and uremia before generic AKI', () {
      final uremic = source.indexOf('if (isUremicEmergency)');
      final rpgn = source.indexOf('if (isRapidlyProgressiveGn)');
      final nephritic = source.indexOf('if (isAcuteNephriticSyndrome)');
      final aki = source.indexOf('if (isAcuteKidneyInjury)');
      expect(rpgn, greaterThan(uremic));
      expect(nephritic, greaterThan(rpgn));
      expect(aki, greaterThan(nephritic));
    });

    test('cardiac respiratory abdominal and thoracic bundles remain present', () {
      for (final token in <String>[
        'AUTORIDADE_FINAL_SINDROME_AORTICA_AGUDA',
        'AUTORIDADE_FINAL_CHOQUE_CARDIOGENICO',
        'AUTORIDADE_FINAL_HEMOPTISE_AMEACADORA_VIDA',
        'AUTORIDADE_FINAL_SDRA_ARDS',
        'AUTORIDADE_FINAL_RIM_OBSTRUIDO_INFECTADO',
        'AUTORIDADE_FINAL_APENDICITE_AGUDA',
        'AUTORIDADE_FINAL_TAMPONAMENTO_CARDIACO_TRAUMATICO',
      ]) {
        expect(source, contains(token));
      }
    });
  });
}
