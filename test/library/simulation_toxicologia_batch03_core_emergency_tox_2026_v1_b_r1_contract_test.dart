import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

String block(String s,String id){
 final at=s.indexOf("id: '$id'"); expect(at,greaterThanOrEqualTo(0),reason:id);
 final a=s.lastIndexOf('ProtocolModel(',at);
 final marker=String.fromCharCode(10)+'  ProtocolModel(';
 final n=s.indexOf(marker,at);
 return s.substring(a,n<0?s.length:n);
}
void main(){
 group('Toxicologia Batch03 — core emergency tox 2026',(){
  late String db,renderer;
  const ids=<String>[
   'intox_salicilatos','intox_bloqueadores_canal_calcio',
   'intox_digoxina_glicosideos','intox_litio','intox_valproato',
   'intox_ferro','intox_isoniazida','intox_cocaina_simpaticomimeticos',
   'sindrome_serotoninergica','intox_anestesico_local_last'];
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
  test('Batch01 renderer and Batch02 content remain retained',(){
   expect(renderer,contains('MEDCASES_SIMULACOES_TOXICOLOGIA_EXPERIENCE_2026_V1_B_R5'));
   expect(renderer,contains('_toxicologySimulationIds2026.contains(protocol.id)'));
   final h2s=block(db,'intox_sulfeto_hidrogenio');
   expect(h2s,contains('Mecanismo de toxicidade —'));
   expect(h2s,contains('SCBA'));
  });
  test('high-risk semantics and 2026/current sources are explicit',(){
   final sal=block(db,'intox_salicilatos');
   expect(sal,contains('≥100 mg/dL')); expect(sal,contains('pH ≤7,20')); expect(sal,contains('150 mEq'));
   final ccb=block(db,'intox_bloqueadores_canal_calcio');
   expect(ccb,contains('1 U/kg')); expect(ccb,contains('1–10 U/kg/h')); expect(ccb,contains('ECLS'));
   final dig=block(db,'intox_digoxina_glicosideos');
   expect(dig,contains('20 frascos')); expect(dig,contains('0,5 mg')); expect(dig,contains('6 frascos'));
   final li=block(db,'intox_litio');
   expect(li,contains('>4,0 mEq/L')); expect(li,contains('>5,0 mEq/L')); expect(li,contains('12 h'));
   final vpa=block(db,'intox_valproato');
   expect(vpa,contains('>1300 mg/L')); expect(vpa,contains('100 mg/kg')); expect(vpa,contains('50 mg/kg'));
   final fe=block(db,'intox_ferro');
   expect(fe,contains('15 mg/kg/h')); expect(fe,contains('6000 mg/24 h')); expect(fe,contains('2026'));
   final inh=block(db,'intox_isoniazida');
   expect(inh,contains('70 mg/kg')); expect(inh,contains('5 g')); expect(inh,contains('GABA'));
   final stim=block(db,'intox_cocaina_simpaticomimeticos');
   expect(stim,contains('>40 °C')); expect(stim,contains('β-bloqueador'));
   final ser=block(db,'sindrome_serotoninergica');
   expect(ser,contains('revisão sistemática 2025')); expect(ser,contains('clônus'));
   final last=block(db,'intox_anestesico_local_last');
   expect(last,contains('1,5 mL/kg')); expect(last,contains('0,25 mL/kg/min')); expect(last,contains('12 mL/kg'));
  });
 });
}
