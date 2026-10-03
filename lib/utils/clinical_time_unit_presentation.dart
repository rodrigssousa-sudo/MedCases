import '../data/new_pathology_approved_hashes.dart';

/// Display units without converting values or inferring an unknown interval.
abstract final class ClinicalTimeUnitPresentation {
  static bool appliesTo(String owner) => newPathologyApprovedHashes.containsKey(owner);

  static String forOwner(String owner, String text, String lang) =>
      appliesTo(owner) ? expand(text, lang) : text;

  static bool hasAmbiguousTime(String text) => RegExp(
      r'(?:\d\s*mo\b|\bmo\s+(?:semanas?|horas?|d[ií]as?)\b)',
      caseSensitive: false).hasMatch(text);

  static String expand(String text, String lang) {
    final es = lang == 'es';
    final urls = RegExp(r'https?://[^\s)\]]+');
    final result = StringBuffer();
    var offset = 0;
    for (final url in urls.allMatches(text)) {
      result.write(_clinical(text.substring(offset, url.start), es));
      result.write(url.group(0));
      offset = url.end;
    }
    result.write(_clinical(text.substring(offset), es));
    return result.toString();
  }

  static String _clinical(String text, bool es) {
    var t = text;
    t = t.replaceAll(RegExp(r'\bc/\s*(?=\d)'), es ? 'cada ' : 'a cada ');
    t = t.replaceAll(RegExp(r'\bq(?=\d+\s*(?:h|d)\b)'), es ? 'cada ' : 'a cada ');
    t = t.replaceAll(RegExp(r'/min\b'), '/minuto');
    t = t.replaceAllMapped(RegExp(r'(\d+)\s*h(?![A-Za-zÀ-ÿ])', caseSensitive: false),
        (m) => '${m[1]} ${m[1] == '1' ? 'hora' : 'horas'}');
    t = t.replaceAllMapped(RegExp(r'(\d+)\s*min(?![A-Za-zÀ-ÿ])', caseSensitive: false),
        (m) => '${m[1]} ${m[1] == '1' ? 'minuto' : 'minutos'}');
    t = t.replaceAllMapped(RegExp(r'(\d+)\s*d(?![A-Za-zÀ-ÿ])'),
        (m) => '${m[1]} ${es ? (m[1] == '1' ? 'día' : 'días') : (m[1] == '1' ? 'dia' : 'dias')}');
    t = t.replaceAll(RegExp(r'(?<=\d)(?=dias\b|días\b|semanas\b|meses\b|horas\b|minutos\b)'), ' ');
    t = t.replaceAllMapped(RegExp(r'\b(cada|até|hasta|por|em|en|desde|menos|durante)(?=\d)'), (m) => '${m[1]} ');
    t = t.replaceAllMapped(RegExp(r'\b(uma vez|duas vezes|una vez|dos veces|\d+\s*(?:vez|vezes|veces))\s*/\s*(?:dia|día)\b'),
        (m) => '${m[1]} ${es ? 'al día' : 'ao dia'}');
    t = t.replaceAllMapped(RegExp(r'\b(uma vez|duas vezes|una vez|dos veces|\d+\s*(?:vez|vezes|veces))\s*/\s*semana\b'), (m) => '${m[1]} por semana');
    t = t.replaceAll(RegExp(r'\bVO\b'), es ? 'por vía oral' : 'por via oral');
    return t;
  }
}
