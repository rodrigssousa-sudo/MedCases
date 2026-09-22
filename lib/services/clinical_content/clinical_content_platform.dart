import '../ai_pipeline/plantao/adapters/plantao_versioned_remote_drug_evidence_json_loader.dart';
import 'clinical_content_gateway.dart';

/// Composition root: caller supplies a reviewed endpoint, entitlement/session
/// policy and durable store. Does not bypass existing UI/offline repositories.
class ClinicalContentPlatform {
  ClinicalContentPlatform(
      {required this.gateway,
      required PlantaoCanonicalCatalogReadOnlyResolver drugs})
      : drugs = DrugResolver(gateway, drugs);
  final ClinicalContentGateway gateway;

  /// Reuses canonical calculator authority; no independent authored drug copy.
  final DrugResolver drugs;
  GuideResolver get guides => GuideResolver(gateway);
  ProtocolResolver get protocols => ProtocolResolver(gateway);
  CaseResolver get cases => CaseResolver(gateway);
  ReferenceResolver get references => ReferenceResolver(gateway);
  ClinicalDomainResolver domain(String domain) =>
      ClinicalDomainResolver(gateway, domain);
  Future<ContentSyncResult> synchronize() => gateway.sync();
}

/// Uses the same canonical calculator data. A validated snapshot, when present,
/// is authoritative for visibility/revocation; network cannot resurrect an ID.
class DrugResolver {
  const DrugResolver(this.gateway, this.canonical);
  final ClinicalContentGateway gateway;
  final PlantaoCanonicalCatalogReadOnlyResolver canonical;
  Future<PlantaoReadOnlyCatalogDocument?> lookup(String id) async {
    if (!gateway.hasDomain('drugs')) return canonical.lookup(id);
    final cached = gateway.lookup('drugs', id);
    if (cached == null) return null;
    return PlantaoReadOnlyCatalogDocument.fromCanonicalSource(
        id, cached.payload);
  }

  Future<Map<String, Map<String, Object?>>> loadIndex() async {
    if (!gateway.hasDomain('drugs')) return canonical.loadIndex();
    return Map.unmodifiable({
      for (final item in gateway.activeItems('drugs'))
        item.canonicalId: Map<String, Object?>.unmodifiable({
          'id': item.canonicalId,
          'name': item.payload['name'],
          'category': item.payload['category'],
          'icon': item.payload['icon'],
          'referenceOnly': true,
        })
    });
  }

  String infusionAuthorityForFallback(String name) =>
      canonical.infusionAuthorityForFallback(name);
}
