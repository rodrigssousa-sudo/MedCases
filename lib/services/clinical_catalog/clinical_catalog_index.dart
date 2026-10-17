import 'dart:collection';

String foldClinicalAlias(String value) {
  var out = value.toLowerCase();
  const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const to = 'aaaaaeeeeiiiiooooouuuucn';
  for (var i = 0; i < from.length; i++) {
    out = out.replaceAll(from[i], to[i]);
  }
  return out.replaceAll(RegExp('[^a-z0-9]+'), ' ').trim();
}

Iterable<String> _strings(Object? value) sync* {
  if (value is String) yield value;
  if (value is List) {
    for (final child in value) {
      yield* _strings(child);
    }
  }
  if (value is Map) {
    for (final child in value.values) {
      yield* _strings(child);
    }
  }
}

/// Built once from a fully validated immutable snapshot. Stores references, not
/// copies of clinical fields. Free text preserves longest-match/tie semantics.
class ClinicalCatalogIndex {
  ClinicalCatalogIndex(Map<String, dynamic> data, int schema) {
    for (final row
        in (data['clinical_identity_registry'] as List? ?? const [])) {
      final owner = row['canonicalKey'] as String;
      for (final a in [
        owner,
        ..._strings(row['aliases']),
        ..._strings(row['strongAliases']),
        ..._strings(row['displayLabel'])
      ]) {
        final folded = foldClinicalAlias(a);
        if (folded.length >= 3) (_aliases[folded] ??= <String>{}).add(owner);
      }
    }
    _orderedAliases = _aliases.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final row in (data[schema == 2
            ? 'clinical_projection_registry'
            : 'clinical_content_registry'] as List? ??
        const [])) {
      final owner = row['canonicalPathologyKey'] as String;
      for (final mode in ['study', 'plantao']) {
        for (final locale in ['pt', 'es']) {
          final value = row['payload'][locale]['${mode}Projection'];
          if (value is Map) {
            final projection = value.cast<String, dynamic>();
            (_owners['$owner/$mode/$locale'] ??= []).add(projection);
            (_surfaces['$mode/$locale'] ??= []).add(projection);
          }
        }
      }
    }
  }
  final _aliases = <String, Set<String>>{};
  late final List<String> _orderedAliases;
  final _owners = <String, List<Map<String, dynamic>>>{};
  final _surfaces = <String, List<Map<String, dynamic>>>{};
  final _queries = LinkedHashMap<String, String?>();
  final _contexts = LinkedHashMap<String, String>();
  int _chars = 0;
  static const maxCachedChars = 4 * 1024 * 1024;

  String? matchOwner(String query) {
    final folded = foldClinicalAlias(query);
    if (_queries.containsKey(folded)) return _queries[folded];
    final exact = _aliases[folded];
    String? result;
    if (exact != null) {
      result = exact.length == 1 ? exact.single : null;
    } else {
      final q = ' $folded ';
      var score = 0;
      final matches = <String>{};
      for (final a in _orderedAliases) {
        if (a.length < score) break;
        if (!q.contains(' $a ')) continue;
        score = a.length;
        matches.addAll(_aliases[a]!);
      }
      result = matches.length == 1 ? matches.single : null;
    }
    if (_queries.length >= 128) _queries.remove(_queries.keys.first);
    _queries[folded] = result;
    return result;
  }

  List<Map<String, dynamic>> projections(String mode, String locale,
          {String? owner}) =>
      List.unmodifiable((owner == null
              ? _surfaces['$mode/$locale']
              : _owners['$owner/$mode/$locale']) ??
          const []);

  String context(String owner, String mode, String locale,
      String Function(Object?) encode) {
    final key = '$owner/$mode/$locale';
    final hit = _contexts.remove(key);
    if (hit != null) {
      _contexts[key] = hit;
      return hit;
    }
    final text = projections(mode, locale, owner: owner)
        .where((p) => p['format'] != 'legacy_source')
        .map(encode)
        .join('\n');
    if (text.length <= maxCachedChars) {
      while (_chars + text.length > maxCachedChars && _contexts.isNotEmpty) {
        _chars -= _contexts.remove(_contexts.keys.first)!.length;
      }
      _contexts[key] = text;
      _chars += text.length;
    }
    return text;
  }
}
