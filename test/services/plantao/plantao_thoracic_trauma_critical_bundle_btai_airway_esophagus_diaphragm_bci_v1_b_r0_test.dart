import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Plantão thoracic trauma critical bundle V1-B-R0', () {
    late String source;

    setUpAll(() {
      source = File('lib/services/ai_service.dart').readAsStringSync();
    });

    test('BTAI terminology and CTA owner exist', () {
      expect(source, contains("folded.contains('btai')"));
      expect(source, contains("folded.contains('blunt thoracic aortic injury')"));
      expect(source, contains('AUTORIDADE_FINAL_LESAO_AORTICA_TRAUMATICA_BTAI'));
      expect(source, contains('realizar angio-TC de torax como exame diagnostico principal'));
    });

    test('BTAI uses anti-impulse without rigid universal targets', () {
      expect(source, contains('controle anti-impulso de frequencia/pressao'));
      expect(source, contains('evitando hipotensao'));
      expect(source, contains('adaptando metas se houver TCE'));
      expect(source, isNot(contains('SBP_TARGET_BTAI=')));
    });

    test('BTAI distinguishes minimal injury from significant TEVAR route', () {
      expect(source, contains('Lesao intimal minima/nao complicada pode ser manejada de forma nao operatoria'));
      expect(source, contains('TEVAR e a estrategia preferida'));
      expect(source, contains('Ruptura livre, hemorragia ativa ou instabilidade'));
    });

    test('tracheobronchial injury recognizes persistent leak and bronchoscopy', () {
      expect(source, contains('AUTORIDADE_FINAL_LESAO_TRAQUEOBRONQUICA_TRAUMATICA'));
      expect(source, contains('fuga aerea persistente ou macica'));
      expect(source, contains('A broncoscopia flexivel e o exame-chave'));
      expect(source, contains('TC negativa nao exclui lesao significativa'));
    });

    test('tracheobronchial injury avoids blind repeated intubation', () {
      expect(source, contains('evitar tentativas repetidas de intubacao cega'));
      expect(source, contains('realiza-la sob guia broncoscopica'));
      expect(source, contains('posicionar o tubo distalmente a lesao'));
    });

    test('tracheobronchial surgery versus selected conservative route exists', () {
      expect(source, contains('reparo cirurgico precoce'));
      expect(source, contains('Lesoes pequenas, estaveis, bem contidas'));
      expect(source, contains('manejo conservador com vigilancia broncoscopica estreita'));
    });

    test('traumatic esophageal injury uses NPO antibiotics and early surgery involvement', () {
      expect(source, contains('AUTORIDADE_FINAL_LESAO_ESOFAGICA_TRAUMATICA'));
      expect(source, contains('Manter jejum'));
      expect(source, contains('antibioticos IV de amplo espectro'));
      expect(source, contains('envolver cirurgia do trauma/toracica precocemente'));
    });

    test('esophageal diagnosis can combine CT esophagography and endoscopy', () {
      expect(source, contains('TC/angio-TC com contraste apropriado'));
      expect(source, contains('esofagografia com contraste hidrossoluvel'));
      expect(source, contains('e/ou endoscopia'));
      expect(source, contains('um unico exame negativo nao deve encerrar o caso'));
    });

    test('esophageal free perforation gets urgent source control', () {
      expect(source, contains('Perfuracao livre, fuga ativa'));
      expect(source, contains('controle de foco urgente'));
      expect(source, contains('desbridamento'));
      expect(source, contains('drenagem adequada'));
    });

    test('diaphragmatic injury requires repair and respects diagnostic limitations', () {
      expect(source, contains('AUTORIDADE_FINAL_LESAO_DIAFRAGMATICA_TRAUMATICA'));
      expect(source, contains('a TC pode falhar em detectar lesoes pequenas'));
      expect(source, contains('Toda lesao diafragmatica traumatica confirmada deve ser reparada'));
    });

    test('diaphragm guard avoids blind tube through herniated viscera', () {
      expect(source, contains('NAO confundi-la com pneumotorax nem passar dreno cegamente atraves de uma viscera'));
      expect(source, contains('descomprimir estomago com sonda quando indicado'));
    });

    test('diaphragm guard supports laparoscopy thoracoscopy when stable equivocal', () {
      expect(source, contains('considerar avaliacao cirurgica diagnostica'));
      expect(source, contains('incluindo laparoscopia/toracoscopia'));
    });

    test('BCI uses ECG plus troponin I screening', () {
      expect(source, contains('AUTORIDADE_FINAL_LESAO_CARDIACA_CONTUSA_BCI'));
      expect(source, contains('ECG de 12 derivacoes e troponina I'));
      expect(source, contains('ECG de admissao normal + troponina I normal permitem excluir BCI clinicamente significativa'));
    });

    test('BCI abnormal ECG or troponin gets monitoring', () {
      expect(source, contains('ECG novo anormal'));
      expect(source, contains('e/ou troponina I elevada'));
      expect(source, contains('monitorizacao continua/telemetria'));
    });

    test('BCI instability or arrhythmia gets echocardiography', () {
      expect(source, contains('Instabilidade hemodinamica, arritmia persistente'));
      expect(source, contains('realizar ecocardiografia'));
      expect(source, contains('usar TTE inicialmente'));
      expect(source, contains('TEE se a janela for insuficiente'));
    });

    test('isolated sternal fracture does not diagnose BCI', () {
      expect(source, contains('Fratura esternal isolada NAO diagnostica BCI'));
      expect(source, contains('se ECG e troponina forem normais'));
    });

    test('BCI does not use CK-MB as substitute for ECG troponin', () {
      expect(source, contains('Nao usar CPK/CK-MB como substituto do binomio ECG + troponina'));
    });

    test('tamponade remains higher precedence than bundle and flail follows bundle', () {
      final tamponade = source.indexOf('if (isTraumaticCardiacTamponade)');
      final btai = source.indexOf('if (isBluntThoracicAorticInjury)');
      final airway = source.indexOf('if (isTracheobronchialInjury)');
      final esophagus = source.indexOf('if (isTraumaticEsophagealInjury)');
      final diaphragm = source.indexOf('if (isTraumaticDiaphragmaticInjury)');
      final bci = source.indexOf('if (isBluntCardiacInjury)');
      final flail = source.indexOf('if (isFlailChest)');
      expect(tamponade, greaterThanOrEqualTo(0));
      expect(btai, greaterThan(tamponade));
      expect(airway, greaterThan(btai));
      expect(esophagus, greaterThan(airway));
      expect(diaphragm, greaterThan(esophagus));
      expect(bci, greaterThan(diaphragm));
      expect(flail, greaterThan(bci));
    });

    test('prior thoracic pleural guards remain present', () {
      for (final token in <String>[
        'AUTORIDADE_FINAL_TAMPONAMENTO_CARDIACO_TRAUMATICO',
        'AUTORIDADE_FINAL_TORAX_INSTAVEL',
        'AUTORIDADE_FINAL_CONTUSAO_PULMONAR',
        'AUTORIDADE_FINAL_FRATURAS_COSTAIS',
        'AUTORIDADE_FINAL_PNEUMOTORAX_HIPERTENSIVO',
        'AUTORIDADE_FINAL_PNEUMOTORAX_ABERTO',
        'AUTORIDADE_FINAL_HEMOTORAX_MACICO',
        'AUTORIDADE_FINAL_HEMOTORAX_PEQUENO_MODERADO',
        'AUTORIDADE_FINAL_INFECCAO_PLEURAL_EMPIEMA',
        'AUTORIDADE_FINAL_DERRAME_PLEURAL',
      ]) {
        expect(source, contains(token));
      }
    });
  });
}
