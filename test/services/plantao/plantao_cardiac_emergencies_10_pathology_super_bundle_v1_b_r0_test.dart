import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Plantão cardiac emergencies 10-pathology super bundle V1-B-R0', () {
    late String source;

    setUpAll(() {
      source = File('lib/services/ai_service.dart').readAsStringSync();
    });

    test('all ten cardiac authority guards exist', () {
      for (final token in <String>[
        'AUTORIDADE_FINAL_SINDROME_AORTICA_AGUDA',
        'AUTORIDADE_FINAL_CHOQUE_CARDIOGENICO',
        'AUTORIDADE_FINAL_EMERGENCIA_HIPERTENSIVA',
        'AUTORIDADE_FINAL_TAQUICARDIA_VENTRICULAR_TORSADES',
        'AUTORIDADE_FINAL_BRADICARDIA_SINTOMATICA_BLOQUEIO_AV',
        'AUTORIDADE_FINAL_TAQUICARDIA_SUPRAVENTRICULAR',
        'AUTORIDADE_FINAL_FIBRILACAO_FLUTTER_ATRIAL',
        'AUTORIDADE_FINAL_PERICARDITE_MIOPERICARDITE',
        'AUTORIDADE_FINAL_ENDOCARDITE_INFECCIOSA',
        'AUTORIDADE_FINAL_INSUFICIENCIA_CARDIACA_AGUDA_EAP',
      ]) {
        expect(source, contains(token));
      }
    });

    test('acute aortic syndrome has CTA anti impulse and type A surgery', () {
      expect(source, contains('angio-TC de aorta e o exame principal'));
      expect(source, contains('FC 60-80/min e PAS <120 mmHg'));
      expect(source, contains('Disseccao tipo A/comprometimento da aorta ascendente: cirurgia cardiotoracica emergente'));
    });

    test('type B uncomplicated versus complicated route exists', () {
      expect(source, contains('Tipo B nao complicada: tratamento medico intensivo'));
      expect(source, contains('Tipo B complicada por ruptura, malperfusao'));
      expect(source, contains('TEVAR e preferida'));
    });

    test('cardiogenic shock uses norepinephrine and phenotype driven escalation', () {
      expect(source, contains('norepinefrina e vasopressor de primeira linha habitual'));
      expect(source, contains('considerar inotropico conforme fenotipo'));
      expect(source, contains('Evitar cargas de volume rotineiras'));
    });

    test('cardiogenic shock uses invasive hemodynamics and selective MCS', () {
      expect(source, contains('monitorizacao hemodinamica invasiva'));
      expect(source, contains('Suporte circulatorio mecanico temporario NAO e automatico'));
      expect(source, contains('Nao usar balao intra-aortico rotineiramente'));
    });

    test('hypertensive emergency requires acute target organ damage', () {
      expect(source, contains('COM lesao aguda de orgao-alvo'));
      expect(source, contains('numero alto isolado sem lesao aguda nao define emergencia'));
      expect(source, contains('reduzir PAM aproximadamente 20-25% na primeira hora'));
    });

    test('hypertensive emergency preserves condition specific exceptions', () {
      expect(source, contains('sindrome aortica aguda precisa controle anti-impulso rapido'));
      expect(source, contains('AVC isquemico/hemorragico e eclampsia seguem protocolos proprios'));
      expect(source, contains('Nao tratar hipertensao severa assintomatica com reducao IV agressiva'));
    });

    test('VT distinguishes pulseless unstable and stable wide complex', () {
      expect(source, contains('TV sem pulso e tratada como parada desfibrilavel'));
      expect(source, contains('cardioversao sincronizada imediata'));
      expect(source, contains('QRS largo de origem incerta deve ser manejada como TV'));
    });

    test('torsades uses magnesium electrolytes and avoids QT prolonging drugs', () {
      expect(source, contains('corrigir K/Mg e administrar magnesio IV'));
      expect(source, contains('Evitar antiarritmicos que prolonguem QT'));
    });

    test('symptomatic bradycardia uses atropine and pacing escalation', () {
      expect(source, contains('atropina IV e tratamento inicial habitual'));
      expect(source, contains('marcapasso transcutaneo e/ou infusao de epinefrina ou dopamina'));
      expect(source, contains('nao atrasar pacing'));
    });

    test('SVT stable uses vagal then adenosine and unstable cardioversion', () {
      expect(source, contains('cardioversao sincronizada imediata'));
      expect(source, contains('manobras vagais modificadas primeiro'));
      expect(source, contains('adenosina IV de acao rapida'));
    });

    test('SVT protects pre-excited AF from AV nodal blockers', () {
      expect(source, contains('FA pre-excitada/WPW'));
      expect(source, contains('NAO usar bloqueadores nodais AV'));
    });

    test('AF flutter unstable gets cardioversion and stable uses tailored rate rhythm', () {
      expect(source, contains('cardioversao eletrica sincronizada imediata'));
      expect(source, contains('escolher controle de frequencia ou ritmo'));
      expect(source, contains('CHA2DS2-VA conforme ESC 2024'));
    });

    test('AF HAS-BLED does not veto anticoagulation', () {
      expect(source, contains('nao usar HAS-BLED como motivo isolado para negar anticoagulacao'));
      expect(source, contains('nao realizar cardioversao eletiva sem estrategia tromboembolica'));
    });

    test('pericarditis uses echo CMR NSAID aspirin colchicine and high-risk admission', () {
      expect(source, contains('ecocardiografia e inicial'));
      expect(source, contains('RMC ajuda a caracterizar inflamacao'));
      expect(source, contains('AINE/aspirina + colchicina'));
      expect(source, contains('Internar/investigar etiologia se houver febre alta'));
    });

    test('myopericarditis routes ventricular dysfunction and arrhythmias to myocarditis', () {
      expect(source, contains('Miopericardite com troponina elevada, disfuncao ventricular, arritmias'));
      expect(source, contains('rota de miocardite'));
      expect(source, contains('Corticoides nao sao primeira linha universal'));
    });

    test('infective endocarditis gets three blood culture sets and echo escalation', () {
      expect(source, contains('pelo menos 3 conjuntos de hemoculturas'));
      expect(source, contains('em sepse/choque NAO atrasar antibioticos'));
      expect(source, contains('ecocardiograma transtoracico inicialmente'));
      expect(source, contains('ETE e indicada se ETT for negativo/inconclusivo'));
    });

    test('endocarditis surgical indications and team are present', () {
      expect(source, contains('Endocarditis Team/cardiologia-cirurgia-infectologia'));
      expect(source, contains('insuficiencia cardiaca por disfuncao valvar'));
      expect(source, contains('infeccao nao controlada/abscesso'));
      expect(source, contains('Nao anticoagular apenas pelo diagnostico de endocardite'));
    });

    test('acute HF uses oxygen only for hypoxemia and early NIV when appropriate', () {
      expect(source, contains('Oxigenio apenas se houver hipoxemia'));
      expect(source, contains('considerar CPAP/VNI precoce'));
      expect(source, contains('Intubar se falha do suporte nao invasivo'));
    });

    test('acute HF congestion uses IV loop diuretic and hypertensive vasodilator', () {
      expect(source, contains('diuretico de alca IV e tratamento principal'));
      expect(source, contains('vasodilatador IV pode reduzir pre/pos-carga'));
      expect(source, contains('Inotropicos/vasopressores NAO sao rotina'));
      expect(source, contains('Nao usar morfina rotineiramente'));
    });

    test('cardiac bundle precedes respiratory while traumatic BTAI stays present', () {
      final aas = source.indexOf('if (isAcuteAorticSyndrome)');
      final hf = source.indexOf('if (isAcuteHeartFailure)');
      final resp = source.indexOf('if (isLifeThreateningHemoptysis)');
      expect(aas, greaterThanOrEqualTo(0));
      expect(hf, greaterThan(aas));
      expect(resp, greaterThan(hf));
      expect(source, contains('AUTORIDADE_FINAL_LESAO_AORTICA_TRAUMATICA_BTAI'));
      expect(source, contains('AUTORIDADE_FINAL_TAMPONAMENTO_CARDIACO_TRAUMATICO'));
    });

    test('respiratory abdominal and thoracic bundles remain present', () {
      for (final token in <String>[
        'AUTORIDADE_FINAL_HEMOPTISE_AMEACADORA_VIDA',
        'AUTORIDADE_FINAL_SDRA_ARDS',
        'AUTORIDADE_FINAL_TEP_AGUDO',
        'AUTORIDADE_FINAL_ASMA_AGUDA_GRAVE',
        'AUTORIDADE_FINAL_EXACERBACAO_DPOC',
        'AUTORIDADE_FINAL_PNEUMONIA_ADQUIRIDA_COMUNIDADE_GRAVE',
        'AUTORIDADE_FINAL_APENDICITE_AGUDA',
        'AUTORIDADE_FINAL_TAMPONAMENTO_CARDIACO_TRAUMATICO',
        'AUTORIDADE_FINAL_LESAO_AORTICA_TRAUMATICA_BTAI',
      ]) {
        expect(source, contains(token));
      }
    });
  });
}
