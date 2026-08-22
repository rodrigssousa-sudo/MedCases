import 'dart:convert';

import '../contracts/plantao_canonical_drug_evidence.dart';

class PlantaoDrugEvidenceParityShadowComparator {
  const PlantaoDrugEvidenceParityShadowComparator();

  static const bool shadowOnly = true;
  static const bool productiveConnectionEnabled = false;
  static const bool promptMutationEnabled = false;
  static const bool renderingEnabled = false;
  static const bool persistenceEnabled = false;
  static const bool medicationMaterializationEnabled = false;
  static const bool deterministicDosingEnabled = false;

  PlantaoDrugEvidenceParitySnapshot compare({
    required PlantaoDrugEvidenceManifest legacyManifest,
    required PlantaoDrugEvidenceManifest remoteManifest,
    required List<PlantaoDrugEvidenceIndexEntry> legacyIndex,
    required List<PlantaoDrugEvidenceIndexEntry> remoteIndex,
    required Map<String, PlantaoCanonicalDrugEvidenceDocument> legacyDocuments,
    required Map<String, PlantaoCanonicalDrugEvidenceDocument> remoteDocuments,
  }) {
    final differences = <PlantaoDrugEvidenceParityDifference>[];

    _compareValue(
      differences,
      scope: 'manifest',
      field: 'drugCount',
      legacy: legacyManifest.drugCount,
      remote: remoteManifest.drugCount,
    );
    _compareValue(
      differences,
      scope: 'manifest',
      field: 'interactionCount',
      legacy: legacyManifest.interactionCount,
      remote: remoteManifest.interactionCount,
    );
    _compareValue(
      differences,
      scope: 'manifest',
      field: 'collisionCount',
      legacy: legacyManifest.collisionCount,
      remote: remoteManifest.collisionCount,
    );
    _compareValue(
      differences,
      scope: 'manifest',
      field: 'exportErrors',
      legacy: legacyManifest.exportErrors,
      remote: remoteManifest.exportErrors,
    );
    _compareValue(
      differences,
      scope: 'manifest',
      field: 'identitySchema',
      legacy: legacyManifest.identitySchema,
      remote: remoteManifest.identitySchema,
    );

    final legacyById = {
      for (final entry in legacyIndex) entry.documentId: entry,
    };
    final remoteById = {
      for (final entry in remoteIndex) entry.documentId: entry,
    };
    final allIds = <String>{...legacyById.keys, ...remoteById.keys}.toList()
      ..sort();

    for (final id in allIds) {
      final legacy = legacyById[id];
      final remote = remoteById[id];
      if (legacy == null || remote == null) {
        differences.add(
          PlantaoDrugEvidenceParityDifference(
            scope: 'index:$id',
            field: 'presence',
            legacy: legacy != null,
            remote: remote != null,
          ),
        );
        continue;
      }
      _compareValue(
        differences,
        scope: 'index:$id',
        field: 'canonicalIdentity',
        legacy: _stableJson(legacy.toJson()),
        remote: _stableJson(remote.toJson()),
      );
    }

    final documentIds = <String>{
      ...legacyDocuments.keys,
      ...remoteDocuments.keys,
    }.toList()
      ..sort();

    for (final id in documentIds) {
      final legacy = legacyDocuments[id];
      final remote = remoteDocuments[id];
      if (legacy == null || remote == null) {
        differences.add(
          PlantaoDrugEvidenceParityDifference(
            scope: 'document:$id',
            field: 'presence',
            legacy: legacy != null,
            remote: remote != null,
          ),
        );
        continue;
      }
      _compareValue(
        differences,
        scope: 'document:$id',
        field: 'documentId',
        legacy: legacy.documentId,
        remote: remote.documentId,
      );
      _compareValue(
        differences,
        scope: 'document:$id',
        field: 'canonicalRawEvidence',
        legacy: _stableJson(legacy.raw),
        remote: _stableJson(remote.raw),
      );
      _compareValue(
        differences,
        scope: 'document:$id',
        field: 'supportsMedicationMaterialization',
        legacy: legacy.supportsMedicationMaterialization,
        remote: remote.supportsMedicationMaterialization,
      );
    }

    return PlantaoDrugEvidenceParitySnapshot(
      comparedIndexIds: allIds.length,
      comparedDocumentIds: documentIds.length,
      differences: List.unmodifiable(differences),
    );
  }

  static void _compareValue(
    List<PlantaoDrugEvidenceParityDifference> output, {
    required String scope,
    required String field,
    required Object? legacy,
    required Object? remote,
  }) {
    if (legacy == remote) return;
    output.add(
      PlantaoDrugEvidenceParityDifference(
        scope: scope,
        field: field,
        legacy: legacy,
        remote: remote,
      ),
    );
  }

  static String _stableJson(Object? value) {
    return jsonEncode(_canonicalize(value));
  }

  static Object? _canonicalize(Object? value) {
    if (value is Map<Object?, Object?>) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return <String, Object?>{
        for (final key in keys) key: _canonicalize(value[key]),
      };
    }
    if (value is List<Object?>) {
      return value.map(_canonicalize).toList(growable: false);
    }
    return value;
  }
}

class PlantaoDrugEvidenceParitySnapshot {
  const PlantaoDrugEvidenceParitySnapshot({
    required this.comparedIndexIds,
    required this.comparedDocumentIds,
    required this.differences,
  });

  final int comparedIndexIds;
  final int comparedDocumentIds;
  final List<PlantaoDrugEvidenceParityDifference> differences;

  bool get isExactParity => differences.isEmpty;

  Map<String, Object?> toJson() => <String, Object?>{
        'shadowOnly': true,
        'productiveConnectionEnabled': false,
        'comparedIndexIds': comparedIndexIds,
        'comparedDocumentIds': comparedDocumentIds,
        'differenceCount': differences.length,
        'isExactParity': isExactParity,
        'differences': differences.map((item) => item.toJson()).toList(),
      };
}

class PlantaoDrugEvidenceParityDifference {
  const PlantaoDrugEvidenceParityDifference({
    required this.scope,
    required this.field,
    required this.legacy,
    required this.remote,
  });

  final String scope;
  final String field;
  final Object? legacy;
  final Object? remote;

  Map<String, Object?> toJson() => <String, Object?>{
        'scope': scope,
        'field': field,
        'legacy': legacy,
        'remote': remote,
      };
}
