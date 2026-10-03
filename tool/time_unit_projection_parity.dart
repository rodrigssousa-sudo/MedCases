import 'dart:convert';
import 'dart:io';
import '../lib/utils/clinical_time_unit_presentation.dart';
void main(List<String> args) {
 final audit=jsonDecode(File(args[0]).readAsStringSync());
 var projections=0;
 for(final e in audit['entries']) {
  for(final mode in ['study','plantao']) {
   for(final lang in ['pt','es']) {
    final old=File('${e['sourceRoot']}/entries/${e['owner']}/$mode.$lang.md').readAsStringSync();
    final expected=File('${args[1]}/${e['owner']}/$mode.$lang.md').readAsStringSync();
    final actual=ClinicalTimeUnitPresentation.expand(old,lang);
    if(actual!=expected)throw StateError('Presentation parity failed ${e['owner']} $mode $lang');
    projections++;
   }
  }
 }
 print('DART_DISPLAY_CMS_PROJECTION_PARITY=PASS PROJECTIONS=$projections');
}
