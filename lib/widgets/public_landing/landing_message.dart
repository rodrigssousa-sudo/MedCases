import 'dart:convert';

/// The bridge accepts JSON text only, never arbitrary JavaScript objects.
String? landingLoginLanguage(Object? payload) =>
    landingActionLanguage(payload, 'medcases:login:v1');
String? landingActionLanguage(Object? payload, String action) {
  if (payload is! String || payload.length > 256) return null;
  try {
    final data = jsonDecode(payload);
    if (data is! Map || data['type'] != action) return null;
    final language = data['language'];
    return language == 'pt-BR'
        ? 'pt'
        : language == 'es'
            ? 'es'
            : null;
  } on FormatException {
    return null;
  }
}
