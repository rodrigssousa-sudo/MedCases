import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/plantao_machine_native_context_prefetch.dart';

class SnapshotSource implements PlantaoMachineNativeRegistrySource {
  SnapshotSource(this.snapshot);

  final Map<String, dynamic> snapshot;

  static const collections = <String, String>{
    'clinical_identity_registry': 'identities',
    'clinical_protocols': 'protocols',
    'clinical_classification_registry': 'classifications',
    'clinical_management_rules': 'managementRules',
    'clinical_action_registry': 'actions',
    'clinical_content_registry': 'content',
  };

  List<Map<String, dynamic>> rows(String collection) {
    final key = collections[collection];
    if (key == null) return const <Map<String, dynamic>>[];
    return (snapshot[key] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .where((row) => row['enabled'] != false)
        .toList(growable: false);
  }

  Object? field(Map<String, dynamic> row, String path) {
    Object? value = row;
    for (final part in path.split('.')) {
      if (value is! Map) return null;
      value = value[part];
    }
    return value;
  }

  @override
  Future<List<Map<String, dynamic>>> loadEnabled(String collection) async =>
      rows(collection);

  @override
  Future<List<Map<String, dynamic>>> loadPathology(
    String collection,
    String canonicalKey, {
    String fieldPath = 'canonicalPathologyKey',
  }) async {
    return rows(collection)
        .where((row) => '${field(row, fieldPath) ?? ''}' == canonicalKey)
        .toList(growable: false);
  }
}

String keyOf(Map<String, dynamic> row) =>
    '${row['canonicalKey'] ?? row['canonicalPathologyKey'] ?? ''}'.trim();

List<Map<String, dynamic>> localizedObjects(
  Map<String, dynamic> row,
  String field,
) {
  final value = row[field];
  if (value is! List) return const <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

void main() {
  test(
    'all 270 authored management records become authoritative packs',
    () async {
      final snapshot =
          jsonDecode(
                File(
                  'functions/clinical_context/generated/'
                  'clinical_registry_remote_snapshot.phase24_authoritative270.local.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;

      final identities = (snapshot['identities'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final management = (snapshot['managementRules'] as List<dynamic>)
          .cast<Map<String, dynamic>>();

      expect(identities, hasLength(270));
      expect(management, hasLength(270));

      final source = SnapshotSource(snapshot);
      final prefetch = PlantaoMachineNativeContextPrefetch(
        source: source,
        cacheTtl: const Duration(hours: 1),
      );

      final byKey = <String, Map<String, dynamic>>{
        for (final row in management) '${row['canonicalPathologyKey']}': row,
      };

      var authoritative = 0;
      var initialLocalizedChecked = 0;
      var definitiveLocalizedChecked = 0;
      var conditionalLocalizedChecked = 0;
      var prohibitedLocalizedChecked = 0;

      for (final identity in identities) {
        final key = keyOf(identity);
        final rule = byKey[key]!;
        expect(rule['enabled'], isTrue, reason: key);
        expect(rule['managementReady'], isTrue, reason: key);
        expect(
          rule['provenancePolicy'],
          'AUTHORITATIVE_CURRENT_OR_FAIL_CLOSED',
          reason: key,
        );
        expect(
          rule['resolutionPolicy'],
          'authoritative_current_machine_management',
          reason: key,
        );

        final es = await prefetch.prefetch(
          userText: key.replaceAll('_', ' '),
          language: 'es',
        );

        expect(es.canonicalPathologyKey, key, reason: key);
        expect(es.authoritative, isTrue, reason: '$key ${es.reason}');
        expect(es.contextPack, isNotNull, reason: key);
        expect(es.providerPromptBlock, contains('pathologyKey=$key'));
        expect(es.providerPromptBlock, contains('requiredFacts='));
        expect(es.providerPromptBlock, contains('monitoring='));
        expect(es.providerPromptBlock, contains('reassessment='));
        expect(es.providerPromptBlock, contains('escalationCriteria='));
        authoritative++;

        final initial = localizedObjects(rule, 'initialActions');
        if (initial.isNotEmpty) {
          final expected = '${initial.first['es'] ?? ''}'.trim();
          expect(expected, isNotEmpty, reason: key);
          expect(
            es.contextPack!.requiredActions,
            contains(expected),
            reason: key,
          );
          initialLocalizedChecked++;
        }

        final definitive = localizedObjects(rule, 'definitiveActions');
        if (definitive.isNotEmpty) {
          final expected = '${definitive.first['es'] ?? ''}'.trim();
          expect(expected, isNotEmpty, reason: key);
          expect(
            es.contextPack!.requiredActions,
            contains(expected),
            reason: key,
          );
          definitiveLocalizedChecked++;
        }

        final conditional = localizedObjects(rule, 'conditionalActions');
        if (conditional.isNotEmpty) {
          final expected = '${conditional.first['es'] ?? ''}'.trim();
          expect(expected, isNotEmpty, reason: key);
          expect(
            es.contextPack!.conditionalActions,
            contains(expected),
            reason: key,
          );
          conditionalLocalizedChecked++;
        }

        final contraindicated = localizedObjects(
          rule,
          'contraindicatedActions',
        );
        if (contraindicated.isNotEmpty) {
          final expected = '${contraindicated.first['es'] ?? ''}'.trim();
          expect(expected, isNotEmpty, reason: key);
          expect(
            es.contextPack!.prohibitedActions,
            contains(expected),
            reason: key,
          );
          prohibitedLocalizedChecked++;
        }
      }

      print(
        '[M56C_R5_SCHEMA_MATRIX] '
        'authoritative=$authoritative '
        'initialLocalizedChecked=$initialLocalizedChecked '
        'definitiveLocalizedChecked=$definitiveLocalizedChecked '
        'conditionalLocalizedChecked=$conditionalLocalizedChecked '
        'prohibitedLocalizedChecked=$prohibitedLocalizedChecked',
      );

      expect(authoritative, 270);
      expect(initialLocalizedChecked, greaterThan(0));
      expect(definitiveLocalizedChecked, greaterThan(0));
    },
  );

  test('same pathology cache remains locale specific ES then PT', () async {
    final snapshot =
        jsonDecode(
              File(
                'functions/clinical_context/generated/'
                'clinical_registry_remote_snapshot.phase24_authoritative270.local.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;

    final management = (snapshot['managementRules'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final representative = management.firstWhere(
      (row) =>
          row['enabled'] == true &&
          row['managementReady'] == true &&
          (row['initialActions'] as List<dynamic>).isNotEmpty,
    );
    final key = '${representative['canonicalPathologyKey']}';

    final firstAction =
        (representative['initialActions'] as List<dynamic>).first
            as Map<String, dynamic>;
    final esText = '${firstAction['es']}';
    final ptText = '${firstAction['pt']}';

    final prefetch = PlantaoMachineNativeContextPrefetch(
      source: SnapshotSource(snapshot),
      cacheTtl: const Duration(hours: 1),
    );

    final es = await prefetch.prefetch(
      userText: key.replaceAll('_', ' '),
      language: 'es',
    );
    final pt = await prefetch.prefetch(
      userText: key.replaceAll('_', ' '),
      language: 'pt',
    );

    expect(es.authoritative, isTrue);
    expect(pt.authoritative, isTrue);
    expect(es.contextPack!.requiredActions, contains(esText));
    expect(pt.contextPack!.requiredActions, contains(ptText));
    expect(es.providerPromptBlock, contains('INSTRUCCIÓN:'));
    expect(pt.providerPromptBlock, contains('INSTRUÇÃO:'));
  });
}
