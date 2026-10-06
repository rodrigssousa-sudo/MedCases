import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/gemini_service_v2.dart';
import 'package:medcases/services/study/study_answer_first.dart';
void main() {
 for(final bad in ['NaN mg','Infinity mg','20–10 mg','20-10 mg','1.2.3 mg','{"dose": 2}','debug internal','0 mg']) {
 test('reject $bad without dropping adjacent explanation',(){
 expect(StudyAnswerFirst.safeFragment(bad),false);
 expect(StudyAnswerFirst.safeBlock('Texto educacional completo.\n$bad'), 'Texto educacional completo.');
 });}
 test('standard doses do not require snapshot',(){expect(StudyAnswerFirst.safeFragment('Exemplo: 10–20 mg VO c/24 h.'),true);});
 test('stream complete blocks before completion and exclude broken tail',()async{
 final chunks=await StudyAnswerFirst.stream(Stream.fromIterable([
 const GeminiChunk(text:'# Tema\n\nTexto seguro'),
 const GeminiChunk(text:'.\n\nDose quebr'),
 GeminiChunk.error('stream_error')])).toList();
 expect(chunks.map((c)=>c.text).join(),'# Tema\n\nTexto seguro.\n\n');
 expect(chunks.last.isError,true);
 });
 test('numeric split across transport chunks stays blocked',()async{
 final chunks=await StudyAnswerFirst.stream(Stream.fromIterable([
 const GeminiChunk(text:'Texto seguro.\n\nDose 20–'),
 const GeminiChunk(text:'10 mg.\n\n'),
 const GeminiChunk(text:'Fim seguro.',isDone:true,finishReason:'STOP')])).toList();
 expect(chunks.map((c)=>c.text).join(),'Texto seguro.\n\nFim seguro.');
 });
 test('missing terminal emits technical error and discards tail',()async{
 final chunks=await StudyAnswerFirst.stream(Stream.value(const GeminiChunk(text:'Texto completo.\n\nRest'))).toList();
 expect(chunks.first.text,'Texto completo.\n\n');expect(chunks.last.errorCode,'stream_error');
 });
}
