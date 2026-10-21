import 'plantao_presentation_contract.dart';

/// Local selection AFTER existing request/admission/ownership guards. Neither
/// source availability nor a clinical title establishes request authorization.
class PlantaoCatalogPresentation {
  const PlantaoCatalogPresentation();

  PlantaoPresentationContract select({
    required Map<String, dynamic> full,
    required String fullCatalogHash,
    Map<String, dynamic>? executive,
    String? executiveCatalogHash,
  }) {
    final integral = PlantaoPresentationContract.fromCatalog(full,
        expectedHash: fullCatalogHash);
    if (integral.isExecutive) {
      throw const FormatException('expected_full_protocol');
    }
    // A pending candidate never replaces the already approved integral.
    if (executive == null || executiveCatalogHash == null) return integral;
    final short = PlantaoPresentationContract.fromCatalog(executive,
        expectedHash: executiveCatalogHash);
    if (!short.isExecutive ||
        short.locale != integral.locale ||
        short.data['sourceVersion'] != integral.data['sourceVersion'] ||
        short.data['fullProtocolRef']['id'] !=
            integral.data['fullProtocolRef']['id'] ||
        short.fullText != integral.fullText) {
      throw const FormatException('executive_full_binding');
    }
    return short;
  }

  /// The caller supplies the pin from the currently trusted catalog, not from
  /// stored history. Reopening cannot make a model call or approve stale data.
  PlantaoPresentationContract reopen(Map<String, dynamic> record,
      {required String requestId, required String catalogHash}) {
    if (record['schemaVersion'] != 1 ||
        record['requestId'] != requestId ||
        record['originalQuestion'] is! String ||
        (record['originalQuestion'] as String).trim().isEmpty ||
        record['presentation'] is! Map<String, dynamic>) {
      throw const FormatException('presentation_history_identity');
    }
    return PlantaoPresentationContract.fromCatalog(
        record['presentation'] as Map<String, dynamic>,
        expectedHash: catalogHash);
  }
}
