import 'dart:convert';
import 'package:crypto/crypto.dart';

/// RAM-only bilingual view of one clinical record. No persistence API.
class CanonicalClinicalSnapshot {
  static const version = 'plantao_clinical_snapshot_v4';
  static const headings = {
    'immediate': ['Conduta imediata', 'Conducta inmediata'],
    'indications': ['Indicações', 'Indicaciones'],
    'treatment': ['Tratamento', 'Tratamiento'],
    'reference_doses': ['Doses de referência', 'Dosis de referencia'],
    'monitoring': ['Monitorização', 'Monitorización'],
    'contraindications': [
      'Contraindicações importantes',
      'Contraindicaciones importantes'
    ],
    'warning_signs': ['Sinais de alarme', 'Signos de alarma'],
    'next_step': ['Próximo passo', 'Próximo paso'],
    'explanation': ['Pontos essenciais', 'Puntos esenciales'],
  };
  final String _encoded;
  final String factsHash;
  CanonicalClinicalSnapshot._(this._encoded, this.factsHash);

  static Object? _sorted(Object? value) {
    if (value is List) return value.map(_sorted).toList();
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: _sorted(value[key])};
    }
    return value;
  }

  static String hash(Object? value) =>
      sha256.convert(utf8.encode(jsonEncode(_sorted(value)))).toString();
  factory CanonicalClinicalSnapshot.fromJson(Map<String, dynamic> json) {
    if (json['version'] != version ||
        json['clinical'] is! List ||
        json['presentation'] is! List ||
        json['sources'] is! List ||
        hash(json['clinical']) != json['factsHash']) {
      throw const FormatException('canonical_snapshot_invalid');
    }
    final snapshot = CanonicalClinicalSnapshot._(
        jsonEncode(json), json['factsHash'] as String);
    snapshot.blocks('pt');
    snapshot.blocks('es');
    return snapshot;
  }
  List<String> blocks(String language) {
    final lang = language.startsWith('pt') ? 'pt' : 'es';
    final json = jsonDecode(_encoded) as Map<String, dynamic>;
    final records = json['clinical'] as List;
    final views = json['presentation'] as List;
    if (records.length < 2 || records.length != views.length) {
      throw const FormatException('canonical_record_count');
    }
    String label(dynamic value) {
      if (value is! Map ||
          value[lang] is! String ||
          (value[lang] as String).trim().isEmpty) {
        throw const FormatException('canonical_label_missing');
      }
      return value[lang] as String;
    }

    final blocks = <String>[];
    final sections = <String>{};
    bool references = false;
    for (var i = 0; i < records.length; i++) {
      final record = records[i] as Map;
      final view = views[i] as Map;
      if ((i == 0) != (record['type'] == 'title') || references) {
        throw const FormatException('canonical_order');
      }
      if (record['type'] == 'title') {
        blocks.add('# ${label(view['labels'])}\n\n');
      } else if (record['type'] == 'references') {
        references = true;
        final ids = record['sourceIds'] as List;
        if (ids.isEmpty) continue;
        final sources = json['sources'] as List;
        final links = ids.map((id) {
          final source = sources.cast<Map>().singleWhere((s) => s['id'] == id);
          final uri = Uri.tryParse(source['url'] as String);
          if (uri == null ||
              uri.scheme != 'https' ||
              uri.host.isEmpty ||
              uri.userInfo.isNotEmpty) {
            throw const FormatException('canonical_reference_invalid');
          }
          return '- [${source['title']}](${source['url']})';
        });
        blocks.add(
            '## ${lang == 'pt' ? 'Referências' : 'Referencias'}\n\n${links.join('\n')}\n\n');
      } else if (record['type'] == 'section' &&
          headings.containsKey(record['id']) &&
          sections.add(record['id'] as String)) {
        final facts = record['facts'] as List;
        final labels = view['facts'] as List;
        if (facts.isEmpty || facts.length != labels.length)
          throw const FormatException('canonical_fact_count');
        final lines = <String>[];
        for (var f = 0; f < facts.length; f++) {
          final fact = facts[f] as Map;
          final localized = labels[f] as Map;
          if (fact['id'] != localized['id'])
            throw const FormatException('canonical_fact_binding');
          final slots = fact['slots'] as List;
          final values = <String, String>{};
          for (final raw in slots) {
            final slot = raw as Map;
            final id = slot['id'] as String;
            if (values.containsKey(id))
              throw const FormatException('canonical_duplicate_slot');
            values[id] = slot['kind'] == 'quantity'
                ? slot['value'] as String
                : label((localized['labels'] as Map)[id]);
          }
          final template = fact['template'] as String;
          final expression = RegExp(r'\{\{([a-z][a-z0-9_]*)\}\}');
          final bound = expression
              .allMatches(template)
              .map((m) => m[1]!)
              .toList()
            ..sort();
          final ids = values.keys.toList()..sort();
          if (jsonEncode(bound) != jsonEncode(ids))
            throw const FormatException('canonical_slot_binding');
          lines.add(
              '- ${template.replaceAllMapped(expression, (m) => values[m[1]]!)}');
        }
        blocks.add(
            '## ${headings[record['id']]![lang == 'pt' ? 0 : 1]}\n\n${lines.join('\n')}\n\n');
      } else {
        throw const FormatException('canonical_record_unknown');
      }
    }
    if (sections.isEmpty) throw const FormatException('canonical_no_facts');
    return List.unmodifiable(blocks);
  }
}

/// Scope/lifetime is owned by the existing conversation. It is never serialized.
/// The server rechecks auth and all dependencies before granting reuse.
class CanonicalConversationCache {
  final Map<
      String,
      ({
        String serverKey,
        CanonicalClinicalSnapshot snapshot,
        String model,
        String provider
      })> _entries = {};
  String? _uid;
  void clear() {
    _entries.clear();
    _uid = null;
  }

  String key(
      {required String uid,
      required String prompt,
      required String query,
      required Object history}) {
    if (_uid != uid) {
      clear();
      _uid = uid;
    }
    return CanonicalClinicalSnapshot.hash({
      'uid': uid,
      'prompt': prompt,
      'query': semanticQuery(query),
      'history': history,
      'contract': CanonicalClinicalSnapshot.version
    });
  }

  static String semanticQuery(String query) {
    var q = query.toLowerCase();
    const accents = {
      'á': 'a',
      'à': 'a',
      'ã': 'a',
      'â': 'a',
      'é': 'e',
      'ê': 'e',
      'í': 'i',
      'ó': 'o',
      'ô': 'o',
      'õ': 'o',
      'ú': 'u',
      'ç': 'c'
    };
    accents.forEach((a, b) {
      q = q.replaceAll(a, b);
    });
    final topics = {
      r'\bencefalopatia hepatica\b': 'hepatic_encephalopathy',
      r'\bmetformina\b': 'metformin',
      r'\binfarto agudo (?:de|do) miocardio\b|\biam\b':
          'acute_myocardial_infarction',
      r'\bhiper(?:c|k)alemia\b|\bhiperpotasemia\b': 'hyperkalemia',
      r'\b(?:sepsis|sepse)\b': 'sepsis',
    };
    final selected = <String>[];
    topics.forEach((pattern, id) {
      q = q.replaceAllMapped(RegExp(pattern), (_) {
        selected.add(id);
        return ' ';
      });
    });
    final intents = <String>{};
    for (final pair in [
      [r'\b(?:tratamento|tratamiento)\b', 'treatment'],
      [r'\b(?:dose|doses|dosis)\b', 'reference_doses'],
      [r'\b(?:indicacoes|indicaciones)\b', 'indications'],
      [r'\b(?:mecanismo de (?:acao|accion)|mecanismo da)\b', 'mechanism'],
    ]) {
      q = q.replaceAllMapped(RegExp(pair[0]), (_) {
        intents.add(pair[1]);
        return ' ';
      });
    }
    q = q.replaceAll(RegExp(r'\b(?:e|y)\b|[:;,?.]'), ' ').trim();
    if (selected.length != 1 || q.isNotEmpty) return query.trim();
    final ordered = intents.toList()..sort();
    return jsonEncode({'topic': selected.single, 'intents': ordered});
  }

  ({
    String serverKey,
    CanonicalClinicalSnapshot snapshot,
    String model,
    String provider
  })? get(String key) => _entries[key];
  void put(String key, String serverKey, CanonicalClinicalSnapshot snapshot,
      String model, String provider) {
    if (_entries.length >= 16 && !_entries.containsKey(key))
      _entries.remove(_entries.keys.first);
    _entries[key] = (
      serverKey: serverKey,
      snapshot: snapshot,
      model: model,
      provider: provider
    );
  }
}
