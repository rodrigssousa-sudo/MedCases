import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

String block(String s,String id){
 final at=s.indexOf("id: '$id'"); expect(at,greaterThanOrEqualTo(0),reason:id);
 final a=s.lastIndexOf('ProtocolModel(',at); final n=s.indexOf('\n  ProtocolModel(',at);
 return s.substring(a,n<0?s.length:n);
}
void main(){
 group('Toxicologia Batch02 — asfixiantes + metemoglobinemia 2026',(){
  late String db,renderer;
  const ids=<String>[
   'intox_co2_espaco_confinado','intox_cianeto','intox_fumaca_co_cianeto',
   'metahemoglobinemia_adquirida','metahemoglobinemia_dapsona',
   'metahemoglobinemia_nitrito_nitrato','metahemoglobinemia_anestesico_local',
   'metahemoglobinemia_anilina_nitrobenzeno','intox_sulfeto_hidrogenio',
   'intox_cloreto_metileno'];
  setUpAll((){
   db=File('lib/data/protocols_database.dart').readAsStringSync();
   renderer=File('lib/screens/protocols_screen.dart').readAsStringSync();
  });
  test('10/10 bilingual rich mechanism source',(){
   expect(ids.toSet(),hasLength(10));
   for(final id in ids){
    expect("id: '$id'".allMatches(db).length,1,reason:id);
    final b=block(db,id);
    for(final f in <String>['definition:','classification:','severityCriteria:','physiopathology:',
      'redFlags:','differentialDiagnosis:','exams:','objectives:','drugsFirstLine:',
      'drugsSecondLine:','drugsConditional:','drugsContraindicated:','scenarios:',
      'monitoring:','complications:','doNotDo:','pearls:','references:','recognize:','actions:','avoid:']){
      expect(b,contains(f),reason:'$id $f');
    }
    expect(b,contains('Mecanismo de toxicidade —'),reason:id);
    expect(b,contains('Mecanismo de toxicidad —'),reason:id);
    expect(b,contains('MECANISMO 1'),reason:id);
    expect(b,contains('RESUMO 30 S'),reason:id);
    expect(b,contains('RESUMEN 30 S'),reason:id);
    expect('https://'.allMatches(b).length,greaterThanOrEqualTo(6),reason:id);
   }
  });
  test('Batch01 toxicology-only experience remains active and untouched',(){
   expect(renderer,contains('MEDCASES_SIMULACOES_TOXICOLOGIA_EXPERIENCE_2026_V1_B_R5'));
   expect(renderer,contains('_toxicologySimulationIds2026.contains(protocol.id)'));
   expect(renderer,contains('DA TOXINA À CONDUTA'));
  });
  test('current 2026 high-risk semantics explicit',(){
   final cy=block(db,'intox_cianeto');
   expect(cy,contains('5 g IV')); expect(cy,contains('total 10 g'));
   final smoke=block(db,'intox_fumaca_co_cianeto');
   expect(smoke,contains('nitrito')); expect(smoke,contains('tiossulfato'));
   final meta=block(db,'metahemoglobinemia_adquirida');
   expect(meta,contains('1 mg/kg')); expect(meta,contains('5–30 min')); expect(meta,contains('G6PD'));
   expect(meta,contains('serotonin'));
   final dap=block(db,'metahemoglobinemia_dapsona');
   expect(dap,contains('múltiplas doses')); expect(dap,contains('2026'));
   final h2s=block(db,'intox_sulfeto_hidrogenio');
   final h2sLower=h2s.toLowerCase();
   expect(h2sLower,contains('não há antídoto')); expect(h2s,contains('SCBA'));
   final mc=block(db,'intox_cloreto_metileno');
   expect(mc,contains('CYP2E1')); expect(mc,contains('COHb'));
  });
 });
}
