import 'dart:convert';
import 'package:crypto/crypto.dart';

/// RAM-only bilingual view of one clinical record. No persistence API.
class CanonicalClinicalSnapshot {
  static const version = 'plantao_clinical_snapshot_v4';
  static const headings = {
    'immediate': ['Conduta', 'Conducta'],
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

  /// Read-only source transport, accepted only by the internal authenticated
  /// catalog handshake. Never accepted as a generated dose/section record.
  factory CanonicalClinicalSnapshot.fromApprovedProtocol(
      Map<String, dynamic> protocol, String expectedHash) {
    final raw = protocol['approvedClinicalPayloadJson'];
    final review = protocol['review'];
    if (raw is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(expectedHash) ||
        sha256.convert(utf8.encode(raw)).toString() != expectedHash ||
        protocol['payloadSha256'] != expectedHash ||
        protocol['scope'] !=
            'UNCHANGED_GENERAL_PROTOCOL_NOT_INDIVIDUAL_PRESCRIPTION' ||
        review is! Map ||
        [
          'recordId',
          'reviewerId',
          'reviewedAt',
          'evidenceSha256'
        ].any((k) => review[k] is! String || (review[k] as String).isEmpty)) {
      throw const FormatException('approved_protocol_integrity');
    }
    final content = jsonDecode(raw) as Map;
    if ((content['owner'] ?? content['ownerId'] ?? content['ownerCandidate']) !=
            protocol['owner'] ||
        content['version'] != protocol['version'] ||
        protocol['activeVersion'] is! String) {
      throw const FormatException('approved_protocol_scope');
    }
    for (final lang in ['pt', 'es']) {
      final embedded = content[lang]?['plantao'];
      final text = protocol['approvedProjections']?[lang] ?? embedded;
      if (text is! String ||
          text.trim().isEmpty ||
          (embedded is String && embedded != text) ||
          (protocol['approvedProjections'] != null &&
              sha256.convert(utf8.encode(text)).toString() !=
                  protocol['projectionSha256']?[lang]) ||
          (embedded is! String && protocol['approvedProjections'] == null)) {
        throw const FormatException('approved_protocol_language');
      }
      validateClinicalText(text);
    }
    final snapshot = CanonicalClinicalSnapshot._(
        jsonEncode({'approvedProtocol': protocol}), expectedHash);
    snapshot.blocks('pt');
    snapshot.blocks('es');
    return snapshot;
  }

  factory CanonicalClinicalSnapshot.fromExternalEvidence(
      String raw, String expectedHash) {
    if (sha256.convert(utf8.encode(raw)).toString() != expectedHash) {
      throw const FormatException('external_evidence_integrity');
    }
    final doc = jsonDecode(raw) as Map;
    if (doc['scope'] != 'EXTERNAL_GENERAL_INFORMATION_NOT_APPROVED_PROTOCOL' ||
        !['pt', 'es'].contains(doc['language']) ||
        doc['text'] is! String ||
        (doc['text'] as String).trim().isEmpty ||
        doc['sources'] is! List ||
        (doc['sources'] as List).isEmpty) {
      throw const FormatException('external_evidence_scope');
    }
    validateClinicalText(doc['text'] as String);
    final snapshot = CanonicalClinicalSnapshot._(
        jsonEncode({'externalEvidence': doc}), expectedHash);
    snapshot.blocks(doc['language'] as String);
    return snapshot;
  }

  factory CanonicalClinicalSnapshot.fromDrugReference(
      String raw, String expectedHash) {
    if (sha256.convert(utf8.encode(raw)).toString() != expectedHash) {
      throw const FormatException('drug_reference_integrity');
    }
    final doc = jsonDecode(raw) as Map;
    final source = jsonDecode(doc['sourceJson'] as String) as Map;
    if (doc['scope'] != 'CANONICAL_DRUG_INFORMATION_NOT_PRESCRIPTION' ||
        !['pt', 'es'].contains(doc['language']) ||
        doc['calculationAuthorized'] != false ||
        doc['clinicalApprovalGranted'] != false ||
        source['id'] != doc['canonicalDrugId'] ||
        source['dataVersion'] != doc['sourceVersion'] ||
        source['clinicalContentSha256'] != doc['sourceContentHash'] ||
        doc['text'] is! String ||
        (doc['text'] as String).isEmpty) {
      throw const FormatException('drug_reference_scope');
    }
    validateClinicalText(doc['text'] as String);
    return CanonicalClinicalSnapshot._(
        jsonEncode({'drugReference': doc}), expectedHash);
  }

  static const drugNoticePt =
      'Ficha farmacológica — informação de referência, não é prescrição nem autorização de cálculo.';
  static const drugNoticeEs =
      'Ficha farmacológica — información de referencia, no es prescripción ni autorización de cálculo.';

  bool get isReferenceDocument =>
      isApprovedProtocol ||
      (jsonDecode(_encoded) as Map).containsKey('drugReference') ||
      (jsonDecode(_encoded) as Map).containsKey('externalEvidence');
  static const externalNoticePt =
      'Pesquisa externa — informação geral, não é protocolo homologado nem prescrição individualizada.';
  static const externalNoticeEs =
      'Investigación externa — información general, no es un protocolo homologado ni una prescripción individualizada.';

  bool get isApprovedProtocol =>
      (jsonDecode(_encoded) as Map).containsKey('approvedProtocol');

  /// Read-only copy of the already validated authenticated protocol transport.
  /// No constructor from saved history grants this authority.
  Map<String, dynamic>? get approvedProtocolData {
    final value = (jsonDecode(_encoded) as Map)['approvedProtocol'];
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  static const protocolNoticePt =
      'Protocolo homologado integral — referência geral, não é prescrição individualizada.';
  static const protocolNoticeEs =
      'Protocolo homologado íntegro — referencia general, no es una prescripción individualizada.';
  // Display-only detection preserves historic reference typography; it grants
  // no approval, entitlement or dose authority.
  static bool isProtocolPresentation(String text) =>
      text.startsWith(drugNoticePt) ||
      text.startsWith(drugNoticeEs) ||
      text.startsWith(protocolNoticePt) ||
      text.startsWith(protocolNoticeEs) ||
      text.startsWith(externalNoticePt) ||
      text.startsWith(externalNoticeEs);

  /// Reject transport corruption; never repair or rewrite clinical characters.
  /// ASCII quantities and biomedical subscripts/superscripts remain unchanged.
  static void validateClinicalText(String text) {
    if (RegExp(r'<\||\|>|\|{2,}|\uFFFD').hasMatch(text) ||
        RegExp(r'\p{Nd}', unicode: true)
            .hasMatch(text.replaceAll(RegExp(r'[0-9]'), ''))) {
      throw const FormatException('canonical_text_corruption');
    }
  }

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
    if (json['drugReference'] is Map) {
      final doc = json['drugReference'] as Map;
      if (doc['language'] != lang)
        throw const FormatException('drug_reference_language');
      return List.unmodifiable([
        '${lang == 'pt' ? drugNoticePt : drugNoticeEs}\n\n',
        doc['text'] as String,
        '\n\n'
      ]);
    }
    if (json['externalEvidence'] is Map) {
      final doc = json['externalEvidence'] as Map;
      final links = (doc['sources'] as List).map((raw) {
        final source = raw as Map;
        final uri = Uri.tryParse(source['url'] as String);
        if (uri == null ||
            uri.scheme != 'https' ||
            uri.host.isEmpty ||
            uri.userInfo.isNotEmpty) {
          throw const FormatException('external_evidence_reference');
        }
        return '- [${source['title']}](${source['url']})';
      }).join('\n');
      return List.unmodifiable([
        '${lang == 'pt' ? externalNoticePt : externalNoticeEs}\n\n',
        doc['text'] as String,
        '\n\n## ${lang == 'pt' ? 'Referências' : 'Referencias'}\n\n$links\n\n',
      ]);
    }
    if (json['approvedProtocol'] is Map) {
      final protocol = json['approvedProtocol'] as Map;
      final content =
          jsonDecode(protocol['approvedClinicalPayloadJson'] as String) as Map;
      final refs = (content['references'] as List).map((raw) {
        final source = raw is List && raw.length >= 3
            ? {'id': raw[0], 'title': raw[1], 'url': raw[2]}
            : raw as Map;
        final uri = Uri.tryParse(source['url'] as String);
        if (uri == null ||
            uri.scheme != 'https' ||
            uri.host.isEmpty ||
            uri.userInfo.isNotEmpty) {
          throw const FormatException('approved_protocol_reference');
        }
        return '- [${source['id'] ?? source['key'] ?? ''} · ${source['title']}](${source['url']})';
      }).join('\n');
      final body = (protocol['approvedProjections']?[lang] ??
          content[lang]['plantao']) as String;
      return List.unmodifiable([
        '${lang == 'pt' ? protocolNoticePt : protocolNoticeEs}\n\n',
        body,
        if (!RegExp(r'^#{1,6}\s+Refer[eê]ncias?\s*$',
                multiLine: true, caseSensitive: false)
            .hasMatch(body))
          '\n\n## ${lang == 'pt' ? 'Referências' : 'Referencias'}\n\n$refs\n\n',
      ]);
    }
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
      validateClinicalText(value[lang] as String);
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
            if (slot['kind'] == 'quantity' &&
                RegExp(r'\b(?:mg|mcg|g|kg|ml|l)\s*%', caseSensitive: false)
                    .hasMatch(slot['value'] as String)) {
              throw const FormatException(
                  'canonical_quantity_dimension_conflict');
            }
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
          final rendered =
              template.replaceAllMapped(expression, (m) => values[m[1]]!);
          if (RegExp(
                  r'\b(?:mg|mcg|g|kg|ml|l)\s*(?:%|por\s+(?:cento|ciento)|percent\b)',
                  caseSensitive: false)
              .hasMatch(rendered)) {
            throw const FormatException(
                'canonical_quantity_dimension_conflict');
          }
          validateClinicalText(rendered);
          lines.add('- $rendered');
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
