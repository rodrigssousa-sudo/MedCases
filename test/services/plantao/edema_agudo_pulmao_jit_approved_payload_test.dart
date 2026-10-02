import 'package:medcases/data/evidence_database.dart';
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
    'docs/clinical_content/approvals/edema_agudo_pulmao/JIT-2026-10-02-v1.0.json',
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
          ...model.getList(model.drugsFirstLine, lang),
          ...model.getList(model.objectives, lang),
          ...model.getList(model.monitoring, lang),
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
  test('The same-owner prescription is the exact approved ES Plantao payload', () {
    final source = File('lib/screens/prescripciones_screen.dart').readAsStringSync();
    final start = source.indexOf("    id: 'icad_eap_icc',");
    final a = source.indexOf('    content: ', start) + '    content: '.length;
    final b = source.indexOf('\n  ),', a);
    final value = jsonDecode(source.substring(a, b).trim().replaceFirst(RegExp(r',$'), ''));
    expect(value, approved['es']['plantao']);
  });
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
  test('EAP medicine links retain established evidence identities', () {
    final model = protocolsDatabase.singleWhere((p) => p.id == 'edema_agudo_pulmao');
    expect(model.drugs.map((d) => getGlobalEvidence(d)?.drugKey), ['furosemida', 'nitroglicerina']);
  });
  for (final query in ["edema agudo de pulmão", "edema agudo de pulmón"]) {
    test('$query resolves the approved references', () {
      final result = ClinicalReferenceResolver.resolve(userText: query, aiText: '', lang: 'pt');
      expect(result.protocolId, 'edema_agudo_pulmao');
      expect(result.lines.join('\n'), contains('escardio.org'));
    });
  }
}
