import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/study/study_canonical_response.dart';
import 'study_canonical_snapshot_test.dart' show records;

// Deliberately synthetic values, testing structure, not clinical recommendations.
Map<String,dynamic> numericFact(String unit,{double? upper})=>{
 'type':'fact','id':'synthetic', 'clinical':{
 'section':'treatment','conceptId':'synthetic_pattern','actionId':'assess',
 'polarity':'conditional','conditionIds':['synthetic_c'],'items':[
 {'id':'synthetic_c','kind':'condition','code':'synthetic_condition'},
 {'id':'synthetic_q','kind':'quantity','amount':1.25,'upper':upper,'operator':'','unit':unit},
 {'id':'synthetic_tail','kind':'relation','code':'synthetic_qualifier'}]},
 'localization':{'synthetic_c':{'pt':'No exemplo sintético, considerar','es':'En el ejemplo sintético, considerar'},
 'synthetic_tail':{'pt':'apenas para testar a estrutura.','es':'solo para probar la estructura.'}}};
StudyCanonicalDecoder decode(Map<String,dynamic> f,String lang){final d=StudyCanonicalDecoder(lang);d.add(jsonEncode([records().first,f,{'type':'end'}]));d.finish();return d;}
void main(){
 final patterns={'glucose':'mg/dL','bicarbonate':'mmol/L','ph':'','potassium':'mEq/L','insulin':'U/kg','fluids':'mL','anion_gap':'mmol/L','interval':'h'};
 for(final p in patterns.entries){for(final range in [false,true]){
 test('${p.key} ${range?'range':'single'} binds once identically PT ES',(){
 final f=numericFact(p.value,upper:range?2.5:null);
 final pt=decode(f,'pt'),es=decode(f,'es');
 expect(pt.issues,isEmpty);expect(es.issues,isEmpty);
 expect(pt.snapshot()!.quantities.length,1);
 expect(pt.snapshot()!.audit('pt'),es.snapshot()!.audit('es'));
 });}}
 for(final kind in ['missing_condition','wrong_condition_kind','inline_number','reversed_range','duplicate_quantity']){
 test('$kind remains rejected',(){final f=numericFact('mg');
 if(kind=='missing_condition')f['clinical']['conditionIds']=['another_fact_c'];
 if(kind=='wrong_condition_kind')f['clinical']['items'][0]['kind']='concept';
 if(kind=='inline_number')f['localization']['synthetic_tail']['pt']='valor 20 mg.';
 if(kind=='reversed_range')f['clinical']['items'][1]['upper']=0.5;
 if(kind=='duplicate_quantity')f['clinical']['items'].add(Map<String,dynamic>.from(f['clinical']['items'][1]));
 final d=decode(f,'pt');expect(d.issues,isNotEmpty);expect(d.snapshot(),isNull);
 expect(d.presentationSnapshot()?.quantities??[],isEmpty);
 });}
}
