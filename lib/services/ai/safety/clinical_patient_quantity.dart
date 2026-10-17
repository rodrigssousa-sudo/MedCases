/// Normalizes only explicit patient-weight expressions, never regimen numbers.
class ClinicalPatientQuantity {
  static const _words = {
    'um': 1,
    'uno': 1,
    'dois': 2,
    'dos': 2,
    'tres': 3,
    'três': 3,
    'quatro': 4,
    'cuatro': 4,
    'cinco': 5,
    'seis': 6,
    'sete': 7,
    'siete': 7,
    'oito': 8,
    'ocho': 8,
    'nove': 9,
    'nueve': 9,
    'dez': 10,
    'diez': 10,
    'onze': 11,
    'once': 11,
    'doze': 12,
    'doce': 12,
    'treze': 13,
    'trece': 13,
    'catorze': 14,
    'quatorze': 14,
    'catorce': 14,
    'quinze': 15,
    'quince': 15,
    'dezesseis': 16,
    'dezasseis': 16,
    'dieciseis': 16,
    'dieciséis': 16,
    'dezessete': 17,
    'diecisiete': 17,
    'dezoito': 18,
    'dieciocho': 18,
    'dezenove': 19,
    'diecinueve': 19,
    'vinte': 20,
    'veinte': 20,
    'trinta': 30,
    'treinta': 30,
    'quarenta': 40,
    'cuarenta': 40,
    'cinquenta': 50,
    'cincuenta': 50,
    'sessenta': 60,
    'sesenta': 60,
    'setenta': 70,
    'oitenta': 80,
    'ochenta': 80,
    'noventa': 90,
    'cem': 100,
    'cien': 100,
  };
  static String normalize(String text) {
    final pattern = RegExp(
        r'\b(peso|pesa|pesando|weight|weighs|para|con|com)\s*(?:de\s+|of\s+|[:=]\s*)?'
        r'([a-záéíóúãõêç]+(?:\s+(?:e|y)\s+[a-záéíóúãõêç]+)?)\s+'
        r'(kg|kilogramos|quilogramas|kilograms)\b',
        caseSensitive: false);
    return text.replaceAllMapped(pattern, (m) {
      final parts = m[2]!.toLowerCase().split(RegExp(r'\s+(?:e|y)\s+'));
      if (parts.any((p) => !_words.containsKey(p))) return m[0]!;
      if (parts.length == 2 &&
          (_words[parts.first]! < 20 || _words[parts.last]! > 9)) return m[0]!;
      final value = parts.fold<int>(0, (n, p) => n + _words[p]!);
      return '${m[1]} $value kg';
    });
  }

  static const weightPattern =
      r'\b(?:peso|pesa|pesando|weight|weighs|para|con|com)\s*(?:de\s+|of\s+|[:=]\s*)?'
      r'(\d+(?:[.,]\d+)?)\s*(?:kg|kilogramos|quilogramas|kilograms)\b';
  static bool hasWeight(String text) =>
      RegExp(weightPattern, caseSensitive: false).hasMatch(normalize(text));
}
