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
 group('Toxicologia Batch04 — LATAM venoms + botulism 2026',(){
  late String db,renderer;
  const ids=<String>[
   'botulismo_neuroparalitico',
   'ofidismo_bothrops_alternatus_yarara',
   'ofidismo_bothrops_jararaca_jararacucu',
   'ofidismo_crotalus_durissus','ofidismo_micrurus_coral',
   'escorpionismo_tityus_argentina','escorpionismo_tityus_brasil',
   'araneismo_loxosceles','araneismo_phoneutria','araneismo_latrodectus'];
  setUpAll((){
   db=File('lib/data/protocols_database.dart').readAsStringSync();
   renderer=File('lib/screens/protocols_screen.dart').readAsStringSync();
  });
  test('10/10 bilingual rich source and stable mechanism labels',(){
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
  test('previous 30 and toxicology renderer remain retained',(){
   expect(renderer,contains('MEDCASES_SIMULACOES_TOXICOLOGIA_EXPERIENCE_2026_V1_B_R5'));
   expect(renderer,contains('_toxicologySimulationIds2026.contains(protocol.id)'));
   expect(block(db,'intox_salicilatos'),contains('Mecanismo de toxicidade —'));
   expect(block(db,'intox_sulfeto_hidrogenio'),contains('SCBA'));
   expect(block(db,'intox_paracetamol'),contains('Mecanismo de toxicidade —'));
  });
  test('2026 and LATAM regional high-risk semantics explicit',(){
   final bot=block(db,'botulismo_neuroparalitico').toLowerCase();
   expect(bot,contains('snare')); expect(bot,contains('1 frasco')); expect(bot,contains('não aguardar confirmação'));
   final alt=block(db,'ofidismo_bothrops_alternatus_yarara');
   expect(alt,contains('B. alternatus')); expect(alt,contains('Argentina')); expect(alt,contains('bivalente'));
   final jar=block(db,'ofidismo_bothrops_jararaca_jararacucu');
   expect(jar,contains('2–4')); expect(jar,contains('4–8')); expect(jar,contains('12'));
   final cro=block(db,'ofidismo_crotalus_durissus');
   expect(cro,contains('5 frascos')); expect(cro,contains('10')); expect(cro,contains('20')); expect(cro,contains('crotoxina'));
   final mic=block(db,'ofidismo_micrurus_coral');
   expect(mic,contains('10 frascos')); expect(mic,contains('nicotínic'));
   final arSc=block(db,'escorpionismo_tityus_argentina');
   expect(arSc,contains('Tityus carrilloi')); expect(arSc,contains('T. trivittatus')); expect(arSc,contains('Argentina'));
   final brSc=block(db,'escorpionismo_tityus_brasil');
   expect(brSc,contains('moderado 3 frascos')); expect(brSc,contains('grave 6 frascos')); expect(brSc,contains('não ultrapassar 6'));
   final lox=block(db,'araneismo_loxosceles');
   expect(lox,contains('5 frascos')); expect(lox,contains('10 frascos')); expect(lox,contains('hemólise'));
   final pho=block(db,'araneismo_phoneutria');
   expect(pho,contains('2–4')); expect(pho,contains('5–10')); expect(pho,contains('priapismo'));
   final lat=block(db,'araneismo_latrodectus');
   expect(lat,contains('moderado = 1 ampola')); expect(lat,contains('grave = 2 ampolas'));
   expect(lat,contains('Brasil')); expect(lat.toLowerCase(),contains('indisponibilidade rotineira'));
   expect(lat,contains('antiveneno latrodéctico ANLIS'));
   expect(lat.toLowerCase(),contains('ausência de antiveneno'));
  });
  test('regional antivenom products are not falsely treated as interchangeable',(){
   expect(block(db,'ofidismo_bothrops_alternatus_yarara').toLowerCase(),contains('não extrapolar'));
   expect(block(db,'ofidismo_crotalus_durissus').toLowerCase(),contains('potência'));
   expect(block(db,'escorpionismo_tityus_argentina').toLowerCase(),contains('não deve ser convertida'));
   expect(block(db,'araneismo_latrodectus'),contains('Argentina 2025'));
  });
 });
}
