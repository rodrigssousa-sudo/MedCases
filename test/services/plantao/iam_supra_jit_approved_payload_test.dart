import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/ai/widgets/clinical_reference_resolver.dart';
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
    'docs/clinical_content/approvals/iam_supra/JIT-2026-10-02-v1.0.json',
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
          ...List<String>.from(model.classification![lang] as List),
          model.getString(model.recognize, lang),
          ...model.getList(model.objectives, lang),
          ...model.getList(model.complications, lang),
          ...model.getList(model.scenarios, lang),
          ...model.getList(model.doNotDo, lang),
        ].join('\n\n');
        expect(reconstructedStudy, approved[lang]['study']);
        expect(model.getActions(lang).join('\n\n'), approved[lang]['plantao']);
        final references = (approved['references'] as List)
            .map((r) => '[${r['id']}] ${r['title']} ${r['url']}').toList();
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
              reason: 'Medication, dilution, infusion speed and monitoring must not be truncated.');
        }
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
  for (final query in ['IAMCSST sem congestão', 'IAMCEST sin congestion', 'IAM com supra de ST', 'IAM con elevación del ST']) {
    test('$query resolves current approved IAM references', () {
      final result = ClinicalReferenceResolver.resolve(userText: query, aiText: '', lang: 'pt');
      expect(result.protocolId, 'iam_supra');
      expect(result.lines.join('\n'), contains('ehag101/8766309'));
      expect(result.lines.join('\n'), contains('0000000000001397'));
    });
  }
}
