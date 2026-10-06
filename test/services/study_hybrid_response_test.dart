import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/study/study_hybrid_response.dart';
import 'study_canonical_snapshot_test.dart' show records;
void main(){
 test('nonnumeric prose before snapshot',(){final d=StudyHybridDecoder('pt');expect(d.add('${jsonEncode({'type':'prose','text':'A explicação conceitual está completa.'})}\n'),contains('explicação'));expect(d.validatedNumericRecords,0);});
 test('bound numeric fact appears',(){final d=StudyHybridDecoder('pt');expect(d.add('${jsonEncode(records()[1])}\n'),contains('2.5–5 mg/kg'));expect(d.blockedNumericRecords,0);});
 for(final value in ['20 mg','NaN mg','Infinity mg','20–10 mg','cinco mg','cinco UI','dose usual']){
 test('unbound $value remains blocked and prose preserved',(){final d=StudyHybridDecoder('pt');final s=d.add('${jsonEncode({'type':'prose','text':'Explicação segura. Dose $value.'})}\n');expect(s,contains('Explicação segura.'));expect(s, isNot(contains(value)));});}
 test('invalid binding blocks only numeric child',(){final f=records()[1];f['clinical']['conditionIds']=['absent'];final d=StudyHybridDecoder('pt');final s=d.add('${jsonEncode({'type':'prose','text':'Texto seguro antes.'})}\n${jsonEncode(f)}\n${jsonEncode({'type':'prose','text':'Texto seguro depois.'})}\n');expect(s,contains('antes'));expect(s,contains('depois'));expect(s,isNot(contains('mg/kg')));expect(d.blockedNumericRecords,1);});
 test('reversed bound range stays blocked',(){final f=records()[1];f['clinical']['items'][2]['value']='5–2.5 mg/kg';final d=StudyHybridDecoder('pt');expect(d.add('${jsonEncode(f)}\n'),isNot(contains('mg/kg')));expect(d.blockedNumericRecords,1);});
 test('arbitrary chunk boundary cannot release partial numeric record',(){final f=jsonEncode(records()[1]);for(var i=1;i<f.length;i++){final d=StudyHybridDecoder('es');expect(d.add(f.substring(0,i)),isEmpty);expect(d.add('${f.substring(i)}\n'),contains('2.5–5 mg/kg'));}});
 test('duplicate ids blocked across independently validated facts',(){final d=StudyHybridDecoder('pt');d.add('${jsonEncode(records()[1])}\n');expect(d.add('${jsonEncode(records()[1])}\n'),isEmpty);expect(d.blockedNumericRecords,1);});
}
