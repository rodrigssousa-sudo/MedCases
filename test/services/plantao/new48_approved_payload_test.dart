import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/data/protocols_database.dart';
import 'package:medcases/data/new_pathology_approved_hashes.dart';
import 'package:medcases/screens/ai/widgets/clinical_reference_resolver.dart';
import 'package:medcases/services/plantao_machine_native_context_prefetch.dart';

class _FileBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(await File(key).readAsBytes());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Catalog adds exactly48 and excludes both unresolved HOLD owners', () {
    expect(protocolsDatabase.length, 318);
    expect(protocolsDatabase.map((p) => p.id).toSet().length, 318);
    for (final id in ['epididimite_orquite', 'abrasao_corneana']) {
      expect(protocolsDatabase.any((p) => p.id == id), false);
    }
  });
  for (final id in newPathologyApprovedHashes.keys) {
    final p = jsonDecode(
        File('docs/clinical_content/approvals/$id/NEW-JIT-2026-10-02-v1.0.json')
            .readAsStringSync()) as Map<String, dynamic>;
    final model = protocolsDatabase.singleWhere((p) => p.id == id);
    for (final lang in ['pt', 'es']) {
      test(
          '$id $lang Study and Plantao preserve every exact approved fact and reference',
          () {
        final study = [
          model.getString(model.definition, lang),
          model.getString(model.physiopathology, lang),
          ...model.getList(model.redFlags, lang),
          ...model.getList(model.differentialDiagnosis, lang),
          ...model.getList(model.exams, lang),
          ...model.getList(model.objectives, lang),
          ...model.getList(model.drugsFirstLine, lang),
          ...model.getList(model.scenarios, lang),
          ...model.getList(model.monitoring, lang),
          ...model.getList(model.doNotDo, lang),
          ...List<String>.from(model.classification![lang] as List)
        ].join('\n\n');
        for (final f in p['facts']) {
          expect(study, contains(f[lang]));
          expect(model.getActions(lang), contains(f[lang]));
        }
        final refs = (p['references'] as List)
            .map((r) => '[${r['id']}] ${r['title']} ${r['url']}')
            .toList();
        expect(model.getList(model.references, lang), refs);
      });
      test(
          '$id $lang actual Plantao resolver carries every approved fact without truncation',
          () async {
        final resolver = PlantaoMachineNativeContextPrefetch(
            source: PlantaoBundledPhase24MachineNativeRegistrySource(
                bundle: _FileBundle()));
        final result =
            await resolver.prefetch(userText: p['title'][lang], language: lang);
        expect(result.authoritative, true,
            reason: '${result.reason} key=${result.canonicalPathologyKey}');
        expect(result.canonicalPathologyKey, id);
        for (final f in p['facts']) {
          expect(result.providerPromptBlock, contains(f[lang]),
              reason: 'Preserve full clinical/dose/safety text for ${f['id']}');
        }
        expect(result.providerPromptBlock,
            endsWith('[/MEDCASES_MACHINE_NATIVE_CONTEXT_V1]'));
      });
      test(
          '$id $lang exact topic references override generic drug/specialty fallback',
          () {
        final result = ClinicalReferenceResolver.resolve(
            userText: p['title'][lang], aiText: '', lang: lang);
        expect(result.protocolId, id);
        for (final r in p['references']) {
          expect(result.lines.join('\n'), contains(r['url']));
        }
      });
    }
  }
}
