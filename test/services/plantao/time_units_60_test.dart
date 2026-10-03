import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/data/new_pathology_approved_hashes.dart';
import 'package:medcases/data/new_pathology_approved_context.dart';
import 'package:medcases/data/protocols_database.dart';
import 'package:medcases/services/approved_pathology_time_output.dart';
import 'package:medcases/utils/clinical_time_unit_presentation.dart';

void main() {
  test('Expand known time units without converting magnitude or confusing intervals', () {
    expect(ClinicalTimeUnitPresentation.expand('500 mg VO c/12h por 7d; máximo 4000mg/24h; deixar 3–5min', 'pt'),
        '500 mg por via oral a cada 12 horas por 7 dias; máximo 4000mg/24 horas; deixar 3–5 minutos');
    expect(ClinicalTimeUnitPresentation.expand('200 mg VO c/1 d durante 7 d; 2–4 semanas; 3 meses; 1h', 'es'),
        '200 mg por vía oral cada 1 día durante 7 días; 2–4 semanas; 3 meses; 1 hora');
    expect(ClinicalTimeUnitPresentation.expand('c/1 mo durante 2–4 mo semanas', 'es'),contains('mo'));
    expect(ClinicalTimeUnitPresentation.hasAmbiguousTime('c/1 mo durante 2–4 mo semanas'),true);
    expect(ClinicalTimeUnitPresentation.expand('5 mL/min; https://example.org/12h?d=7d', 'pt'),
        '5 mL/minuto; https://example.org/12h?d=7d');
  });
  test('Presentation policy does not affect original270 owners', () {
    expect(ClinicalTimeUnitPresentation.forOwner('avc_isquemico','10 mg VO c/12h','pt'),'10 mg VO c/12h');
    expect(ApprovedPathologyTimeOutput.enforce(query:'unknown topic',text:'300 mg c/1 mo',language:'es',normalize:(s)=>s.toLowerCase()),'300 mg c/1 mo');
  });
  test('Screenshot corrupt systemic dose cannot be guessed into a week or month', () {
    final actual=ApprovedPathologyTimeOutput.enforce(query:'Pitiriasis versicolor',
        text:'Fluconazol 300 mg VO c/1 mo durante 2–4 mo semanas. Itraconazol 200 mg VO c/2 d.',
        language:'es',normalize:(s)=>s.toLowerCase());
    expect(actual, isNot(contains('mo semanas')));
    expect(actual, isNot(contains('300 mg')));
    expect(actual, isNot(contains('cada 2 días')));
    expect(actual, contains('ketoconazol'));
    expect(actual, contains('3–5 minutos'));
    expect(actual, contains('https://www.pcds.org.uk/clinical-guidance/pityriasis-versicolor'));
  });
  for(final id in newPathologyApprovedHashes.keys) {
    final v=newPathologyG06Versions[id]??newPathologyG05Versions[id]??newPathologyG04Versions[id]??newPathologyG03Versions[id]??newPathologyG02Versions[id]??'NEW-JIT-2026-10-02-v1.0';
    final p=jsonDecode(File('docs/clinical_content/approvals/$id/$v.json').readAsStringSync());
    for(final lang in ['pt','es']) {
      test('$id $lang preserve every number, reference and approved clinical fact', () {
        final ctx=approvedNewPathologyContext(p['title'][lang],lang,normalize:(s)=>s.toLowerCase())!;
        for(final f in p['facts']) {
          final before=f[lang] as String;final after=ClinicalTimeUnitPresentation.expand(before,lang);
          expect(RegExp(r'\d+(?:[.,]\d+)?').allMatches(after).map((m)=>m[0]).toList(),
              RegExp(r'\d+(?:[.,]\d+)?').allMatches(before).map((m)=>m[0]).toList());
          expect(ctx,contains(after));
          expect(RegExp(r'\d\s*(?:h|min|d)(?![A-Za-zÀ-ÿ])').hasMatch(after),false,reason:after);
          expect(ClinicalTimeUnitPresentation.expand(after,lang),after);
        }
        expect(ctx,contains(newPathologyApprovedHashes[id]!));
        for(final ref in p['references'])expect(ctx,contains(ref['url']));
      });
    }
  }
}
