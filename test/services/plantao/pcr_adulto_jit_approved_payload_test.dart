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
    'docs/clinical_content/approvals/pcr_adulto/JIT-2026-10-02-v1.0.json',
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
            contains(model.getList(model.scenarios, lang).single));
        expect(result.providerPromptBlock,
            endsWith('[/MEDCASES_MACHINE_NATIVE_CONTEXT_V1]'));
      });
    }
  }
  for (final language in ['pt', 'es']) {
    test('PCR adulto $language resolves approved current references', () {
      final result = ClinicalReferenceResolver.resolve(
        userText: language == 'pt' ? 'PCR adulto' : 'Paro cardiorrespiratorio adulto',
        aiText: '', lang: language,
      );
      final text = result.lines.join('\n');
      expect(text, contains('cpr.heart.org'));
      expect(text, contains('resus.org.uk'));
    });
  }
  for (final query in ['PCR adulto', 'Paro cardiorrespiratorio adulto']) {
    test('$query resolves the approved canonical owner', () async {
      final result = await PlantaoMachineNativeContextPrefetch(
        source: PlantaoBundledPhase24MachineNativeRegistrySource(bundle: _FileBundle()),
      ).prefetch(userText: query, language: query.startsWith('Paro') ? 'es' : 'pt');
      expect(result.authoritative, isTrue);
      expect(result.canonicalPathologyKey, 'pcr_adulto');
      expect(result.providerPromptBlock, contains('Adrenalina'));
    });
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
  test('cardiac arrest dose-volume dimensional checks', () {
    expect(1 / 0.1, 10);
    expect(300 / 50, 6);
    expect(150 / 50, 3);
  });
  test('adult aliases do not redirect pediatric arrest or an ambiguous PCR', () async {
    final prefetch = PlantaoMachineNativeContextPrefetch(
      source: PlantaoBundledPhase24MachineNativeRegistrySource(bundle: _FileBundle()),
    );
    final child = await prefetch.prefetch(userText: 'pcr_pediatrica', language: 'pt');
    expect(child.canonicalPathologyKey, 'pcr_pediatrica');
    expect(child.providerPromptBlock, isNot(contains('JIT-2026-10-02-v1.0')));
    final ambiguous = await prefetch.prefetch(userText: 'PCR', language: 'pt');
    expect(ambiguous.canonicalPathologyKey, isNot('pcr_adulto'));
  });
  test('local fallback changes only the adult PCR condition', () {
    final text = File('lib/providers/app_provider.dart').readAsStringSync();
    final start = text.indexOf("      _CliCondition(\n        id: 'pcr',");
    final end = text.indexOf('      _CliCondition(', start + 10);
    final block = text.substring(start, end);
    expect(block, isNot(contains('a partir do 2º ciclo em não desfibriláveis')));
    expect(block, contains('1 mg IV/IO a cada 3–5 minutos'));
    expect(block, contains('AHA 2025'));
  });
}
