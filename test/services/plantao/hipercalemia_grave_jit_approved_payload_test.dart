import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/data/protocols_database.dart';
import 'package:medcases/services/plantao_machine_native_context_prefetch.dart';

class _FileBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final bytes = await File(key).readAsBytes();
    return ByteData.sublistView(bytes);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final approved = jsonDecode(File(
    'docs/clinical_content/approvals/hipercalemia_grave/JIT-2026-10-01-v1.0.json',
  ).readAsStringSync()) as Map<String, dynamic>;
  final ids = List<String>.from(approved['preservedRuntimeIds'] as List);
  final registry = jsonDecode(File(
    'assets/clinical/clinical_registry_phase24_authoritative270.json',
  ).readAsStringSync()) as Map<String, dynamic>;

  for (final id in ids) {
    for (final lang in ['pt', 'es']) {
      test('$id $lang preserves the exact approved Study and Plantao content', () {
        final model = protocolsDatabase.singleWhere((p) => p.id == id);
        final reconstructedStudy = [
          model.getString(model.definition, lang),
          model.getString(model.physiopathology, lang),
          ...model.getList(model.differentialDiagnosis, lang),
          ...model.getList(model.objectives, lang),
          ...model.getList(model.scenarios, lang),
          ...model.getList(model.complications, lang),
        ].join('\n\n');
        expect(reconstructedStudy, approved[lang]['study']);
        expect(model.getActions(lang).join('\n\n'), approved[lang]['plantao']);
        final references = (approved['references'] as List)
            .map((r) => '[${r[0]}] ${r[1]} ${r[2]}').toList();
        expect(model.getList(model.references, lang), references);
        final content = (registry['content'] as List).singleWhere(
          (r) => r['contentKey'] == 'legacy_protocol_content::$id',
        );
        expect(content['payload']['actions']['locales'][lang],
            model.getActions(lang));
        expect(content['payload']['approvedClinicalPayload'], approved);
      });
      test('$id $lang sends complete approved doses and monitoring to Plantao', () async {
        final prefetch = PlantaoMachineNativeContextPrefetch(
          source: PlantaoBundledPhase24MachineNativeRegistrySource(
            bundle: _FileBundle(),
          ),
        );
        final result = await prefetch.prefetch(userText: id, language: lang);
        expect(result.authoritative, isTrue);
        expect(result.canonicalPathologyKey, id);
        final model = protocolsDatabase.singleWhere((p) => p.id == id);
        for (final section in model.getActions(lang)) {
          expect(result.providerPromptBlock, contains(section),
              reason: 'Dose, speed, glucose prevention and monitoring must not be truncated.');
        }
        expect(result.providerPromptBlock,
            contains(model.getList(model.scenarios, lang).single));
        expect(result.providerPromptBlock,
            endsWith('[/MEDCASES_MACHINE_NATIVE_CONTEXT_V1]'));
      });
    }
  }
  test('PT/ES approved numeric sequences stay equivalent', () {
    final refs = RegExp(r'\[R[\d,R]+\]');
    final numbers = RegExp(r'\d+(?:[,.]\d+)?');
    for (final mode in ['study', 'plantao']) {
      List<String> values(String lang) => numbers
          .allMatches((approved[lang][mode] as String).replaceAll(refs, ''))
          .map((m) => m.group(0)!).toList();
      expect(values('pt'), values('es'));
    }
  });
}
