import 'package:medcases/services/gi_batch01_publication_state.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:medcases/services/plantao_machine_native_context_prefetch.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/data/protocols_database.dart';
import 'package:medcases/data/new_pathology_approved_hashes.dart';
import 'package:medcases/data/gi_batch01_approved_projections.dart';
import 'package:medcases/models/protocol_model.dart';

class _FileBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(await File(key).readAsBytes());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Map<String,dynamic> validManifest() => {'version':GiBatch01PublicationState.version,'published':true,'manifestSha256':GiBatch01PublicationState.manifestSha256,'ownerCount':54,'approvedHashes':GiBatch01PublicationState.expectedHashes,'modeLocales':['study_pt','study_es','plantao_pt','plantao_es']};
  GiBatch01PublicationState.applyManifest(validManifest());
  test('G07 stays invisible until all four modes and exact hashes are activated together', () {
    GiBatch01PublicationState.applyManifest(null);
    expect(protocolsDatabase.length,489);
    expect(newPathologyG07Versions,isEmpty);
    final partial=validManifest()..['modeLocales']=['study_pt','study_es'];
    expect(GiBatch01PublicationState.applyManifest(partial),false);
    expect(protocolsDatabase.length,489);
    final bad=validManifest()..['approvedHashes']={...GiBatch01PublicationState.expectedHashes,'sindrome_intestino_irritavel':'invalid'};
    expect(GiBatch01PublicationState.applyManifest(bad),false);
    expect(protocolsDatabase.length,489);
    expect(GiBatch01PublicationState.applyManifest(validManifest()),true);
    expect(protocolsDatabase.length,514);
    expect(newPathologyG07Versions.length,54);
  });

  test('The same cached Plantao resolver switches with the Study catalog in one activation', () async {
    GiBatch01PublicationState.applyManifest(null);
    final source=PlantaoBundledPhase24MachineNativeRegistrySource(bundle:_FileBundle());
    final identitiesBefore=await source.loadEnabled('clinical_identity_registry');
    expect(identitiesBefore.length,489);
    final resolver=PlantaoMachineNativeContextPrefetch(source:source);
    final before=await resolver.prefetch(userText:'infeccao clostridioides difficile',language:'pt');
    expect(before.authoritative,true);
    expect(before.contextPack?.guidelineVersion,isNot(GiBatch01PublicationState.version));
    expect(protocolsDatabase.length,489);
    expect(GiBatch01PublicationState.applyManifest(validManifest()),true);
    final identitiesAfter=await source.loadEnabled('clinical_identity_registry');
    expect(identitiesAfter.length,514);
    final after=await resolver.prefetch(userText:'infeccao clostridioides difficile',language:'pt');
    expect(after.authoritative,true);
    expect(after.contextPack?.guidelineVersion,GiBatch01PublicationState.version);
    expect(protocolsDatabase.length,514);
    expect(newPathologyG07Versions['infeccao_clostridioides_difficile'],GiBatch01PublicationState.version);
  });
  test('G07 owner catalog is unique and preserves pediatric identity', () {
    expect(protocolsDatabase.length, 514);
    expect(protocolsDatabase.map((p) => p.id).toSet().length, 514);
    expect(newPathologyG07Versions.length, 54);
    expect(
        newPathologyG07Versions
            .containsKey('intussuscepcao_intestinal_pediatrica'),
        false);
    expect(
        protocolsDatabase
            .any((p) => p.id == 'intussuscepcao_intestinal_pediatrica'),
        false);
    expect(
        protocolsDatabase
            .any((p) => p.id == 'intussuscepcao_intestinal_adulto'),
        true);
  });
  test(
      'Overlay leaves unrelated owners unchanged and preserves stercoral complementary care',
      () {
    const other = ProtocolModel(id: 'not_in_g07', title: {
      'pt': 'Outro'
    }, severity: {}, actions: {
      'pt': ['original']
    }, avoid: {}, drugs: []);
    const stercoral =
        ProtocolModel(id: 'colite_estercoral_impactacao_fecal', title: {
      'pt': 'Colite estercoral'
    }, severity: {}, actions: {
      'pt': ['tratamento complementar original'],
      'es': ['tratamiento complementario original']
    }, avoid: {}, drugs: []);
    final output = applyApprovedGiBatch01([other, stercoral]);
    expect(identical(output.first, other), true);
    expect(output.singleWhere((p) => p.id == stercoral.id).getActions('pt'),
        contains('tratamento complementar original'));
    expect(output.singleWhere((p) => p.id == stercoral.id).getActions('es'),
        contains('tratamiento complementario original'));
  });
  for (final owner in newPathologyG07Versions.keys) {
    final root =
        'docs/clinical_content/approvals/$owner/GI-JIT-2026-10-04-G07-v1.0';
    final payload = jsonDecode(File('$root.json').readAsStringSync())
        as Map<String, dynamic>;
    final approval = jsonDecode(File('$root.approval.json').readAsStringSync())
        as Map<String, dynamic>;
    final selected =
        (approval['selectedApprovedFactIds'] as List).cast<String>().toSet();
    final facts = (payload['facts'] as List)
        .cast<Map<String, dynamic>>()
        .where((f) => selected.contains(f['id']))
        .toList();
    for (final lang in ['pt', 'es']) {
      test('$owner/$lang actual Plantao runtime retains approved facts', () async {
        final resolver = PlantaoMachineNativeContextPrefetch(source: PlantaoBundledPhase24MachineNativeRegistrySource(bundle: _FileBundle()));
        final result = await resolver.prefetch(userText: owner.replaceAll('_',' '), language: lang);
        expect(result.authoritative,true,reason: result.reason);
        expect(result.canonicalPathologyKey,owner);
        for(final fact in facts) {
          expect(result.providerPromptBlock,contains(fact[lang]),reason: '${fact['id']} must be retained');
        }
      });

      test('$owner/$lang preserves exact approved facts and final references',
          () {
        final p = protocolsDatabase.singleWhere((p) => p.id == owner);
        final actions = p.getActions(lang);
        for (final fact in facts) {
          final expected =
              '${fact[lang]} [${(fact['references'] as List).join(', ')}]';
          expect(actions, contains(expected));
        }
        for (final reference in payload['references'] as List) {
          expect(
              p
                  .getList(p.references, lang)
                  .any((s) => s.contains(reference['url'] as String)),
              true);
        }
        expect(p.canonicalProtocolId, owner);
        expect(newPathologyApprovedHashes[owner],
            approval['approvedClinicalPayloadSHA256']);
        if (owner == 'intussuscepcao_intestinal_adulto') {
          expect(selected, {'g058_f05'});
          expect(
              actions.any((s) =>
                  s.startsWith('Estabilizar circulação') ||
                  s.startsWith('Estabilizar la circulación')),
              false);
        }
      });
    }
  }
}
