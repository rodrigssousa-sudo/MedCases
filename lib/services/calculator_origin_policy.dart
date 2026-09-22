/// Only the canonical HTTPS calculator or its exact selected offline document
/// may host native calculator bridges. Never trust arbitrary file:// pages.
class CalculatorOriginPolicy {
  String? _localDocument;

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
