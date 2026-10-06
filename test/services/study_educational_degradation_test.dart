import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/study/study_canonical_response.dart';
import 'package:medcases/services/study/study_educational_degradation.dart';
import 'study_canonical_snapshot_test.dart' show records;

Map<String,dynamic> fact({String section='definition', bool numeric=false})=>{
 'type':'fact','id':'educational',
 'clinical':{'section':section,'conceptId':'education','actionId':section=='treatment'?'treat':'explain','polarity':'positive','conditionIds':['education_text'],'items':[
 {'id':'education_text','kind':'concept','code':'explanation'},
 if(numeric){'id':'education_q','kind':'quantity','amount':3.5,'upper':null,'operator':'>','unit':'g'},
 if(numeric){'id':'education_tail','kind':'relation','code':'threshold'},
 ]},
 'localization':{'education_text':{'pt':numeric?'O limiar do exemplo é':'Esta explicação educacional permanece completa.','es':numeric?'El umbral del ejemplo es':'Esta explicación educativa permanece completa.'},if(numeric)'education_tail':{'pt':'neste exemplo sintético.','es':'en este ejemplo sintético.'}}
};
StudyCanonicalDecoder decode(Map<String,dynamic> f,String lang){
 final decoder=StudyCanonicalDecoder(lang);decoder.add(jsonEncode([records().first,f,records()[2],{'type':'end'}]));decoder.finish();return decoder;
}
void main(){
 for(final section in ['definition','diagnosis','pathophysiology']){
  for(final numeric in [false,true]){
   test('binding taxonomy recovers $section numeric=$numeric without hiding audit failure',(){
    final pt=decode(fact(section:section,numeric:numeric),'pt'),es=decode(fact(section:section,numeric:numeric),'es');
    expect(pt.snapshot(),isNull);expect(pt.issues,contains('study_snapshot_condition_binding'));
    final p=pt.presentationSnapshot()!,e=es.presentationSnapshot()!;
    expect(p.audit('pt'),e.audit('es'));expect(p.audit('pt')['factCount'],2);
    expect(p.audit('pt')['canonicalAuditPassed'],false);
    expect(p.audit('pt')['fallbackFactCount'],1);
    expect(p.quantities.length,numeric?1:0);
    expect(p.blocks('pt').join(),isNot(contains('- Esta explicação')));
    final meta=pt.diagnostics.single;
    expect(meta.keys.toSet(),{'reasonCode','sectionId','recordIndex','factIdHash','numeric','fallbackRenderUsed'});
    expect(meta['fallbackRenderUsed'],true);expect(meta['factIdHash'],matches(r'^[a-f0-9]{64}$'));
   });
  }
 }
 test('invalid operational condition never releases a dose but retains independent prose',(){
  final f=fact(section:'treatment',numeric:true);
  f['clinical']['items'].insert(0,{'id':'education_note','kind':'concept','code':'independent'});
  f['localization']['education_note']={'pt':'Esta frase educacional está completa.','es':'Esta frase educativa está completa.'};
  final d=decode(f,'pt'),s=d.presentationSnapshot()!;
  expect(s.quantities,isEmpty);expect(s.blocks('pt').join(),contains('Esta frase educacional está completa.'));
  expect(s.blocks('pt').join(),isNot(contains('limiar')));
 });
 for(final problem in ['reversed','nonfinite','missing_translation','debug','unbound_numeric','truncated_sentence']){
  test('hard exception $problem never releases damaged text or quantity',(){
   final f=fact(numeric:true);
   if(problem=='reversed'){f['clinical']['items'][1]['upper']=1;}
   if(problem=='nonfinite'){f['clinical']['items'][1]['amount']=double.infinity;expect(StudyEducationalDegradation.recover(f,'study_snapshot_condition_binding'),isNull);return;}
   if(problem=='missing_translation'){f['localization']['education_text'].remove('es');}
   if(problem=='debug'){f['localization']['education_text']={'pt':'system_prompt debug instructions','es':'system_prompt debug instructions'};}
   if(problem=='unbound_numeric'){f['localization']['education_text']={'pt':'Usar 55 mg agora','es':'Usar 55 mg ahora'};}
   if(problem=='truncated_sentence'){
    final d=StudyCanonicalDecoder('pt');d.add(jsonEncode(records().first)+jsonEncode(f).substring(0,80));d.finish();expect(d.hasPresentableFacts,false);return;
   }
   final d=decode(f,'pt');expect(d.presentationSnapshot()!.quantities,isEmpty);
   expect(d.presentationSnapshot()!.audit('pt')['factCount'],1);
  });
 }
 test('broken child does not erase valid siblings in same section',(){
  final f=fact(numeric:true);f['clinical']['items'][1]['upper']=1;
  final good=fact()..['id']='sibling';good['clinical']['items'][0]['id']='sibling_text';good['clinical']['conditionIds']=[];good['localization']={'sibling_text':{'pt':'Outra explicação completa e preservada.','es':'Otra explicación completa y preservada.'}};
  final d=StudyCanonicalDecoder('pt');d.add(jsonEncode([records().first,f,good,{'type':'end'}]));d.finish();expect(d.presentationSnapshot()!.blocks('pt').join(),contains('Outra explicação'));
 });
 test('incomplete JSON never degrades',(){final d=StudyCanonicalDecoder('pt');d.add('[{"type":"fact", BROKEN');d.finish();expect(d.presentationSnapshot(),isNull);expect(d.hasPresentableFacts,false);});
}
