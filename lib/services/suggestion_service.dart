import 'package:shared_preferences/shared_preferences.dart';

/// Serviço de autocomplete adaptativo por campo clínico.
///
/// Aprende com o que o usuário digita e sugere frases/palavras
/// baseadas no histórico de cada campo (hpi, physicalExam, etc.).
///
/// Persistência: SharedPreferences (local, offline, sem servidor).
class SuggestionService {
  static const int _maxSuggestionsPerField = 60;
  static const int _minCharsToSuggest = 3;
  static const String _prefix = 'sug_';

  /// Salva a frase digitada no campo [fieldKey].
  /// Divide o conteúdo em sentenças e salva cada uma individualmente.
  static Future<void> saveEntry(String fieldKey, String text) async {
    final value = text.trim();
    if (value.length < _minCharsToSuggest) return;

    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefix$fieldKey';

    // Recupera lista existente
    final existing = prefs.getStringList(key) ?? [];

    // Extrai sentenças úteis (separa por ponto, vírgula ou quebra de linha)
    final sentences = _extractSentences(value);

    for (final sentence in sentences) {
      final s = sentence.trim();
      if (s.length < _minCharsToSuggest) continue;
      // Evita duplicatas (case-insensitive)
      if (!existing.any((e) => e.toLowerCase() == s.toLowerCase())) {
        existing.insert(0, s); // Mais recente primeiro
      } else {
        // Move para o topo (mais usado = mais relevante)
        existing.removeWhere((e) => e.toLowerCase() == s.toLowerCase());
        existing.insert(0, s);
      }
    }

    // Mantém limite máximo
    final trimmed = existing.take(_maxSuggestionsPerField).toList();
    await prefs.setStringList(key, trimmed);
  }

  /// Retorna sugestões para o campo [fieldKey] que contenham [query].
  /// Retorna no máximo [limit] sugestões.
  static Future<List<String>> getSuggestions(
    String fieldKey,
    String query, {
    int limit = 5,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.length < _minCharsToSuggest) return [];

    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefix$fieldKey';
    final stored = prefs.getStringList(key) ?? [];

    // Filtra: começa com query > contém query
    final startsWith = <String>[];
    final contains = <String>[];

    for (final s in stored) {
      final lower = s.toLowerCase();
      if (lower.startsWith(q)) {
        startsWith.add(s);
      } else if (lower.contains(q)) {
        contains.add(s);
      }
    }

    final result = [...startsWith, ...contains];
    return result.take(limit).toList();
  }

  /// Limpa todo o histórico de sugestões de um campo.
  static Future<void> clearField(String fieldKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$fieldKey');
  }

  /// Limpa todo o histórico de sugestões de todos os campos.
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  }

  // ─── helpers ───────────────────────────────────────────────────────────────

  static List<String> _extractSentences(String text) {
    // Divide por ponto final, ponto e vírgula, quebras de linha
    final raw = text.split(RegExp(r'[.;\n]+'));
    final result = <String>[];
    for (final part in raw) {
      final s = part.trim();
      if (s.length >= _minCharsToSuggest) result.add(s);
    }
    // Também adiciona o texto completo se for curto o suficiente
    if (text.trim().length <= 120 && !result.contains(text.trim())) {
      result.add(text.trim());
    }
    return result;
  }
}
