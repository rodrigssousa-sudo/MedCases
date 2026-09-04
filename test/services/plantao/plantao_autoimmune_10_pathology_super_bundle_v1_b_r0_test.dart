import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Plantão autoimmune 10-pathology super bundle V1-B-R0', () {
    late String source;

    setUpAll(() {
      source = File('lib/services/ai_service.dart').readAsStringSync();
    });

    test('all ten autoimmune authority guards exist', () {
      for (final token in <String>[
        'AUTORIDADE_FINAL_HEPATITE_AUTOIMUNE_AGUDA_GRAVE',
        'AUTORIDADE_FINAL_ANEMIA_HEMOLITICA_AUTOIMUNE_GRAVE',
        'AUTORIDADE_FINAL_PTI_SANGRAMENTO_CRITICO',
        'AUTORIDADE_FINAL_GUILLAIN_BARRE',
        'AUTORIDADE_FINAL_CRISE_MIASTENICA',
        'AUTORIDADE_FINAL_SAF_CATASTROFICA',
        'AUTORIDADE_FINAL_CRISE_RENAL_ESCLERODERMICA',
        'AUTORIDADE_FINAL_ARTERITE_CELULAS_GIGANTES',
        'AUTORIDADE_FINAL_VASCULITE_ANCA',
        'AUTORIDADE_FINAL_LES_GRAVE_NEFRITE_LUPICA',
      ]) {
        expect(source, contains(token));
      }
    });

    test('lupus nephritis uses active urine kidney workup and biopsy threshold', () {
      expect(source, contains('creatinina/TFGe, urina com sedimento'));
      expect(source, contains('proteinuria >0,5 g/g'));
      expect(source, contains('biopsia renal'));
      expect(source, contains('deterioracao renal nao explicada'));
    });

    test('severe lupus does not immunosuppress serology alone', () {
      expect(source, contains('Nao iniciar imunossupressao intensa automaticamente por ANA/anti-dsDNA/complemento isolados'));
      expect(source, contains('enquanto se exclui infeccao'));
      expect(source, contains('plasmaferese nao e rotina para toda exacerbacao de LES'));
    });

    test('ANCA severe disease uses KDIGO 2024 induction and biopsy no-delay', () {
      expect(source, contains('KDIGO 2024 orienta que tratamento nao deve ser atrasado aguardando biopsia'));
      expect(source, contains('glicocorticoide + rituximabe ou ciclofosfamida'));
      expect(source, contains('avacopan pode ser alternativa'));
    });

    test('ANCA plasma exchange is selected not routine', () {
      expect(source, contains('Troca plasmatica NAO e rotina para todos'));
      expect(source, contains('hemorragia alveolar com hipoxemia'));
      expect(source, contains('sobreposicao anti-GBM'));
    });

    test('GCA threatened vision gets steroid without biopsy delay', () {
      expect(source, contains('perda visual, amaurose fugaz ou ameaca a visao'));
      expect(source, contains('iniciar glicocorticoide imediatamente'));
      expect(source, contains('NAO atrasar por biopsia ou imagem'));
      expect(source, contains('ultrassom vascular temporal/axilar'));
    });

    test('GCA tocilizumab is steroid sparing and aspirin is not universal', () {
      expect(source, contains('Tocilizumabe junto com glicocorticoide'));
      expect(source, contains('Aspirina NAO deve ser dada rotineiramente a todos'));
    });

    test('scleroderma renal crisis immediately uses ACE inhibitor and keeps it through creatinine rise', () {
      expect(source, contains('Iniciar inibidor da ECA imediatamente'));
      expect(source, contains('NAO suspender automaticamente IECA por aumento inicial da creatinina'));
      expect(source, contains('mesmo se o paciente precisar de dialise'));
    });

    test('scleroderma renal crisis avoids high-dose glucocorticoids and ARB substitution', () {
      expect(source, contains('Evitar glicocorticoide em dose alta'));
      expect(source, contains('Nao substituir IECA por BRA como estrategia inicial equivalente'));
    });

    test('catastrophic APS does not wait twelve week classification confirmation', () {
      expect(source, contains('tratamento nao deve aguardar preencher criterios classificatorios completos'));
      expect(source, contains('NAO aguardar confirmacao de persistencia em 12 semanas'));
    });

    test('CAPS uses anticoagulation steroid and plasma exchange or IVIG combination', () {
      expect(source, contains('anticoagulacao terapeutica com heparina + glicocorticoide de alta intensidade + troca plasmatica e/ou IVIG'));
      expect(source, contains('diferenciar CAPS de PTT/TMA, CIVD, HIT, HELLP e sepse'));
      expect(source, contains('Nao trombolisar sistemicamente toda trombose da CAPS de rotina'));
    });

    test('myasthenic crisis is clinical respiratory and not one FVC threshold', () {
      expect(source, contains('falencia respiratoria ou bulbar'));
      expect(source, contains('NAO aguardar numero isolado de CVF/NIF'));
      expect(source, contains('intubar se a clinica mostrar deterioracao'));
    });

    test('myasthenic crisis uses IVIG or PLEX and medication caution', () {
      expect(source, contains('IVIG ou troca plasmatica sao terapias de resgate'));
      expect(source, contains('magnesio IV salvo indicacao vital'));
      expect(source, contains('corticoides podem causar piora transitoria'));
    });

    test('GBS monitors respiratory and autonomic function', () {
      expect(source, contains('Fraqueza flacida progressiva/arreflexia'));
      expect(source, contains('disautonomia pode causar arritmias'));
      expect(source, contains('NAO aguardar limiar isolado'));
    });

    test('GBS IVIG and PLEX are alternatives and steroids are rejected', () {
      expect(source, contains('IVIG ou troca plasmatica sao tratamentos imunes eficazes e alternativas entre si'));
      expect(source, contains('NAO combinar rotineiramente plasmaferese seguida de IVIG'));
      expect(source, contains('NAO usar corticoides como tratamento do GBS'));
      expect(source, contains('Evitar succinilcolina'));
    });

    test('critical ITP is bleeding driven not platelet count only', () {
      expect(source, contains('Gravidade e definida por localizacao/impacto do sangramento e nao apenas pela contagem de plaquetas'));
      expect(source, contains('glicocorticoide + IVIG e transfusao de plaquetas'));
      expect(source, contains('NAO reter plaquetas'));
    });

    test('ITP distinguishes critical bleed from TTP DIC HIT and leukemia mimics', () {
      expect(source, contains('PTT/TMA, CIVD, HIT ou leucemia'));
      expect(source, contains('TPO-RA, rituximabe ou esplenectomia sao estrategias de resgate/segunda linha'));
    });

    test('severe AIHA confirms hemolysis and does not equate DAT positivity', () {
      expect(source, contains('Hb, reticulocitos, LDH, bilirrubina, haptoglobina e esfregaco'));
      expect(source, contains('DAT positivo isolado NAO demonstra hemolise clinica'));
    });

    test('severe AIHA does not delay lifesaving transfusion and distinguishes warm from cold', () {
      expect(source, contains('NAO atrasar transfusao salvadora aguardando compatibilidade sorologica perfeita'));
      expect(source, contains('AHAI quente grave: glicocorticoide e primeira linha'));
      expect(source, contains('Na doenca por crioaglutininas'));
      expect(source, contains('corticoides costumam ter baixa eficacia'));
    });

    test('acute severe AIH uses INR phenotype early steroid and transplant reassessment', () {
      expect(source, contains('Ictericia com INR >=1,5 sem encefalopatia'));
      expect(source, contains('encefalopatia implica falencia hepatica aguda'));
      expect(source, contains('iniciar corticoide precocemente'));
      expect(source, contains('aproximadamente entre dias 3-7'));
    });

    test('acute severe AIH escalates transplant and rejects budesonide', () {
      expect(source, contains('transplante hepatico urgente'));
      expect(source, contains('evitar prolongar corticoide ineficaz'));
      expect(source, contains('Budesonida NAO deve ser usada'));
    });

    test('autoimmune bundle precedes vascular and therefore disease-specific thrombotic routes', () {
      final autoimmune = source.indexOf('if (isAcuteSevereAutoimmuneHepatitis)');
      final caps = source.indexOf('if (isCatastrophicAntiphospholipidSyndrome)');
      final vascular = source.indexOf('if (isAcuteCompartmentSyndrome)');
      expect(autoimmune, greaterThanOrEqualTo(0));
      expect(caps, greaterThan(autoimmune));
      expect(vascular, greaterThan(caps));
    });

    test('previous renal ANCA fallback and all major bundles remain present', () {
      for (final token in <String>[
        'AUTORIDADE_FINAL_GNRP_SINDROME_PULMAO_RIM',
        'AUTORIDADE_FINAL_SINDROME_COMPARTIMENTAL_AGUDA',
        'AUTORIDADE_FINAL_CETOACIDOSE_DIABETICA',
        'AUTORIDADE_FINAL_PANCREATITE_AGUDA_GRAVE',
        'AUTORIDADE_FINAL_LESAO_RENAL_AGUDA',
        'AUTORIDADE_FINAL_SINDROME_AORTICA_AGUDA',
        'AUTORIDADE_FINAL_TEP_AGUDO',
        'AUTORIDADE_FINAL_TAMPONAMENTO_CARDIACO_TRAUMATICO',
      ]) {
        expect(source, contains(token));
      }
    });
  });
}
