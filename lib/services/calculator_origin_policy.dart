/// Only the canonical HTTPS calculator or its exact selected offline document
/// may host native calculator bridges. Never trust arbitrary file:// pages.
class CalculatorOriginPolicy {
  String? _localDocument;

  /// Protected drug details need the HTTPS origin accepted by the MCC1 issuer.
  /// Keep other calculator routes eligible for their existing offline cache.
  static bool requiresOnlineDrugDocument(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.port == 443 &&
        uri.userInfo.isEmpty &&
        const {'medcasescalcu.com', 'www.medcasescalcu.com'}
            .contains(uri.host.toLowerCase()) &&
        uri.queryParameters['tab']?.toLowerCase() == 'farmacos';
  }

  /// Public embedded document currently served by the canonical Wix page.
  /// Navigation permission only: this is NOT a trusted native bridge origin.
  bool allowsEmbeddedDocument(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    return uri != null && uri.scheme == 'https' && uri.port == 443 &&
        uri.userInfo.isEmpty &&
        uri.host == 'b047deb0-a06e-4403-942c-743fbdb9667b.filesusr.com' &&
        uri.path == '/html/817a38_55582a1776679463f24dc9b1f9870c9d.html';
  }

  bool allowsNavigation(String rawUrl, {required bool isMainFrame}) =>
      allows(rawUrl) || (!isMainFrame && allowsEmbeddedDocument(rawUrl));

  void selectLocalDocument(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    _localDocument = uri != null && uri.scheme == 'file' && uri.host.isEmpty
        ? uri.replace(query: '', fragment: '').toString()
        : null;
  }

  bool allows(String? rawUrl) {
    final uri = rawUrl == null ? null : Uri.tryParse(rawUrl);
    if (uri == null || uri.userInfo.isNotEmpty) return false;
    if (uri.scheme == 'https' && uri.port == 443) {
      return const {'medcasescalcu.com', 'www.medcasescalcu.com'}
          .contains(uri.host.toLowerCase());
    }
    return uri.scheme == 'file' &&
        uri.host.isEmpty &&
        _localDocument != null &&
        uri.replace(query: '', fragment: '').toString() == _localDocument;
  }
}
