import '../data/clinical_crosscutting_evidence_database.dart';

/// Data-driven resolver for cross-cutting clinical evidence.
///
/// It does not decide diagnoses and does not contain pathology-specific
/// management logic. It only selects an evidence entry from the curated
/// database and appends the corresponding evidence block to existing local RAG.
class ClinicalCrosscuttingEvidenceResolver {
  const ClinicalCrosscuttingEvidenceResolver._();

  static String enrich({
    required String query,
    required String baseContext,
    required String lang,
  }) {
    final entry = resolve(query);
    if (entry == null) return baseContext;

    final facts =
        lang.toLowerCase().startsWith('es') ? entry.esFacts : entry.ptFacts;

    final sourceLabel = entry.sourceIds.join(', ');
    final evidenceBlock = StringBuffer()
      ..writeln('[MEDCASES_CROSSCUTTING_EVIDENCE]')
      ..writeln('id=${entry.id}')
      ..writeln('version=${entry.version}')
      ..writeln('evidence_status=curated_primary_and_guideline_sources')
      ..writeln('clinical_rules:')
      ..writeAll(facts.map((fact) => '- $fact\n'))
      ..writeln('source_ids=$sourceLabel')
      ..writeln(
        'instruction=Use only the supported axis and facts above; do not invent '
        'a classification, dose strategy, patient state, ideal weight, or '
        'vascular-access rule that is not supported by the supplied case.',
      );

    final existing = baseContext.trim();
    if (existing.isEmpty) return evidenceBlock.toString().trim();
    return '$existing\n\n${evidenceBlock.toString().trim()}';
  }

  static ClinicalCrosscuttingEvidenceEntry? resolve(String query) {
    final normalized = _normalize(query);
    if (normalized.isEmpty) return null;

    final queryTokens = _tokens(normalized);
    ClinicalCrosscuttingEvidenceEntry? best;
    var bestScore = 0;

    for (final entry in clinicalCrosscuttingEvidenceEntries) {
      var entryScore = 0;

      for (final rawAlias in entry.aliases) {
        final alias = _normalize(rawAlias);
        if (alias.isEmpty) continue;

        if (_containsPhrase(normalized, alias)) {
          final score = 100 + alias.length;
          if (score > entryScore) entryScore = score;
          continue;
        }

        final aliasTokens = _tokens(alias);
        if (aliasTokens.length >= 2 &&
            aliasTokens.every(queryTokens.contains)) {
          final score = 60 + aliasTokens.length * 5;
          if (score > entryScore) entryScore = score;
          continue;
        }

        final distinctive =
            aliasTokens.where((token) => token.length >= 5).toSet();
        if (distinctive.isNotEmpty) {
          final overlap = distinctive.intersection(queryTokens).length;
          final score = overlap * 8;
          if (score > entryScore) entryScore = score;
        }
      }

      if (entryScore > bestScore) {
        bestScore = entryScore;
        best = entry;
      }
    }

    return bestScore >= 24 ? best : null;
  }

  static String? debugMatchId(String query) => resolve(query)?.id;

  static bool _containsPhrase(String haystack, String phrase) {
    if (haystack == phrase) return true;
    return haystack.contains(' $phrase ') ||
        haystack.startsWith('$phrase ') ||
        haystack.endsWith(' $phrase');
  }

  static Set<String> _tokens(String text) =>
      text.split(RegExp(r'\s+')).where((token) => token.length >= 3).toSet();

  static String _normalize(String value) {
    var text = value.toLowerCase();
    const replacements = <String, String>{
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'ó': 'o',
      'ò': 'o',
      'ô': 'o',
      'õ': 'o',
      'ö': 'o',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ç': 'c',
      'ñ': 'n',
    };
    replacements.forEach((from, to) {
      text = text.replaceAll(from, to);
    });
    return text
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
