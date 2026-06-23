// calcu_stub.dart — Stub para Android/iOS.
// A implementação real para Web está em calcu_web.dart.
// Esta função nunca é chamada em native — o código usa WebViewWidget diretamente
// dentro do guard `if (!kIsWeb)`.

import 'package:flutter/material.dart';

/// Stub — nunca invocado em iOS/Android.
/// Existe apenas para satisfazer o compilador na conditional import.
Widget buildCalculadoraWebView(String url, bool dark) {
  return const SizedBox.shrink();
}
