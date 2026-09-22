import '../../../free_drug_catalog.dart';
import 'dart:convert';

/// Exact-ID catalog visibility, independent of versioned dosing projections.
/// The transport owns authentication and limits. No authority or name binding
/// can be obtained from this resolver, even if source metadata grants one.
class PlantaoCanonicalCatalogReadOnlyResolver {
  PlantaoCanonicalCatalogReadOnlyResolver({required this.loadObject});

  final Future<Map<String, Object?>> Function(String path) loadObject;
  static final _safeId = RegExp(r'^[a-z0-9_]+$');

  Future<Map<String, Map<String, Object?>>> loadIndex() async {
    final payload = await loadObject('/api/drug-catalog');
    final rows = payload['drugs'];
    if (payload['ok'] != true || rows is! List || rows.isEmpty) {
      throw const FormatException('Invalid canonical catalog');
    }
    final result = <String, Map<String, Object?>>{};
    for (final raw in rows) {
      if (raw is! Map<String, Object?>) {
        throw const FormatException('Invalid canonical catalog row');
      }
      final id = raw['id'];
      final name = raw['name'];
      if (id is! String ||
          !_safeId.hasMatch(id) ||
          name is! Map ||
          name['pt'] is! String ||
          name['es'] is! String ||
          result.containsKey(id)) {
        throw const FormatException('Invalid or duplicate canonical identity');
      }
      result[id] = _freeze(raw) as Map<String, Object?>;
    }
    return Map.unmodifiable(result);
  }

  Future<PlantaoReadOnlyCatalogDocument?> lookup(String canonicalDrugId) async {
    // Exact identifiers only: never trim, fold, fuzzy-match or alias a name.
    if (!_safeId.hasMatch(canonicalDrugId)) return null;
    // Exact Free60 IDs are already canonical, so a fresh Free installation
    // does not need permission to download the full Premium discovery index.
    if (!freeDrugCanonicalIds.contains(canonicalDrugId)) {
      final index = await loadIndex();
      if (!index.containsKey(canonicalDrugId)) return null;
    }
    final payload = await loadObject('/api/drugs/$canonicalDrugId');
    final raw = payload['drug'];
    if (payload['ok'] != true ||
        raw is! Map<String, Object?> ||
        raw['id'] != canonicalDrugId) {
      throw const FormatException('Canonical document identity mismatch');
    }
    return PlantaoReadOnlyCatalogDocument._(
      canonicalDrugId,
      _freeze(raw) as Map<String, Object?>,
    );
  }

  String infusionAuthorityForFallback(String fallbackName) =>
      'FAIL_CLOSED_UNRESOLVED_BINDING';

  static Object? _freeze(Object? value) {
    if (value is Map<String, Object?>) {
      return Map<String, Object?>.unmodifiable(
        value.map((key, item) => MapEntry(key, _freeze(item))),
      );
    }
    if (value is List) return List<Object?>.unmodifiable(value.map(_freeze));
    return value;
  }
}

class PlantaoReadOnlyCatalogDocument {
  const PlantaoReadOnlyCatalogDocument._(this.canonicalDrugId, this.source);
  factory PlantaoReadOnlyCatalogDocument.fromCanonicalSource(
    String canonicalDrugId,
    Map<String, Object?> source,
  ) {
    if (!PlantaoCanonicalCatalogReadOnlyResolver._safeId
            .hasMatch(canonicalDrugId) ||
        source['id'] != canonicalDrugId) {
      throw const FormatException('Canonical document identity mismatch');
    }
    return PlantaoReadOnlyCatalogDocument._(
        canonicalDrugId,
        PlantaoCanonicalCatalogReadOnlyResolver._freeze(source)
            as Map<String, Object?>);
  }

  final String canonicalDrugId;

  /// Source text/metadata preserved verbatim in meaning; never executable rules.
  final Map<String, Object?> source;
  bool get catalogVisible => true;
  bool get calculationAuthorized => false;
  bool get clinicalAuthority => false;
  bool get infusionAuthority => false;
  Map<String, Object?> get derivedClinicalValues => const {};
  String get referenceJson => jsonEncode(source);
}
