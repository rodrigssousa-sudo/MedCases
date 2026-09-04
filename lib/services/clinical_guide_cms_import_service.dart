import 'dart:convert';
import 'dart:typed_data';

class ClinicalGuideCmsImportException implements Exception {
  const ClinicalGuideCmsImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ClinicalGuideCmsImportBlock {
  const ClinicalGuideCmsImportBlock({
    required this.type,
    this.title = '',
    this.text = '',
  });

  final String type;
  final String title;
  final String text;
}

class ClinicalGuideCmsImportLocale {
  const ClinicalGuideCmsImportLocale({
    required this.code,
    required this.title,
    required this.subtitle,
    required this.summary,
    required this.blocks,
    required this.references,
    required this.sourceTypes,
    required this.tableConversions,
    required this.algorithmConversions,
  });

  final String code;
  final String title;
  final String subtitle;
  final String summary;
  final List<ClinicalGuideCmsImportBlock> blocks;
  final List<String> references;
  final List<String> sourceTypes;
  final int tableConversions;
  final int algorithmConversions;
}

class ClinicalGuideCmsImportPackage {
  const ClinicalGuideCmsImportPackage({
    required this.schemaVersion,
    required this.topicPt,
    required this.topicEs,
    required this.specialty,
    required this.authors,
    required this.year,
    required this.version,
    required this.pt,
    required this.es,
  });

  final String schemaVersion;
  final String topicPt;
  final String topicEs;
  final String specialty;
  final String authors;
  final String year;
  final int version;
  final ClinicalGuideCmsImportLocale pt;
  final ClinicalGuideCmsImportLocale es;

  int get tableConversions => pt.tableConversions + es.tableConversions;

  int get algorithmConversions =>
      pt.algorithmConversions + es.algorithmConversions;
}

class ClinicalGuideCmsImportService {
  ClinicalGuideCmsImportService._();

  static const Set<String> _supportedNativeTypes = <String>{
    'heading',
    'paragraph',
    'bullets',
    'callout',
    'warning',
    'note',
  };

  static const Set<String> _supportedImportTypes = <String>{
    ..._supportedNativeTypes,
    'table',
    'algorithm',
  };

  static ClinicalGuideCmsImportPackage parseBytes(Uint8List bytes) {
    final text = utf8.decode(bytes, allowMalformed: false);
    return parseJson(text);
  }

  static ClinicalGuideCmsImportPackage parseJson(String source) {
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (e) {
      throw ClinicalGuideCmsImportException('JSON inválido: ${e.message}');
    }

    final root = _asMap(decoded, 'raiz');

    // MEDCASES_ADMIN_CONTENT_CMS_DUAL_SCHEMA_COMPAT_V1_B_R2
    // Canonical package:
    //   schema_version + metadata + pt + es
    // Editorial legacy V1:
    //   version + pt + es (+ optional top-level references)
    //
    // Compatibility belongs only at the import boundary. Persistence,
    // publication, clinical blocks and public guide rendering stay unchanged.
    // MEDCASES_ADMIN_CONTENT_CMS_V1_ENVELOPE_TOLERANT_IMPORT_V1_B_R5
    // Import is transport-tolerant but content-strict. Optional envelope
    // fields must not block a structurally valid bilingual CMS V1 payload.
    final rawSchemaVersion = _text(root['schema_version']);
    if (rawSchemaVersion.isNotEmpty && rawSchemaVersion != '1.0') {
      throw ClinicalGuideCmsImportException(
        'schema_version não suportado: $rawSchemaVersion. Esperado: 1.0.',
      );
    }

    final rawMetadata = root['metadata'];
    if (rawMetadata != null && rawMetadata is! Map) {
      _asMap(rawMetadata, 'metadata');
    }

    final rootVersion = _text(root['version']);
    final metadataVersion = rawMetadata is Map
        ? _text(Map<String, dynamic>.from(rawMetadata)['version'])
        : '';
    final declaredVersion =
        rootVersion.isNotEmpty ? rootVersion : metadataVersion;
    final declaredMajor =
        declaredVersion.isEmpty ? '' : declaredVersion.split('.').first;

    if (rawMetadata == null &&
        declaredMajor.isNotEmpty &&
        declaredMajor != '1') {
      throw ClinicalGuideCmsImportException(
        'version editorial não suportada: $declaredVersion. Esperado: V1.x.',
      );
    }

    final schemaVersion = '1.0';
    final metadata = rawMetadata == null
        ? <String, dynamic>{
            'topic_pt': root['topic_pt'],
            'topic_es': root['topic_es'],
            'specialty_pt': root['specialty_pt'],
            'specialty_es': root['specialty_es'],
            'specialty': root['specialty'],
            'category': root['category'],
            'authors': root['authors'] ?? root['author'],
            'year': root['year'],
            'review_date': root['review_date'],
            'version': root['version'],
          }
        : _asMap(rawMetadata, 'metadata');

    final ptMap = _asMap(root['pt'], 'pt');
    final esMap = _asMap(root['es'], 'es');

    // MEDCASES_ADMIN_CONTENT_CMS_BLOCKS_SECTIONS_ALIAS_COMPAT_V1_B_R9
    // Historical CMS exports used `blocks`; current importer calls the same
    // clinical payload `sections`. Normalize only when `sections` is absent
    // or empty. A non-empty `sections` list remains authoritative.
    void normalizeBlocksAlias(Map<String, dynamic> localeMap) {
      final sections = localeMap['sections'];
      final blocks = localeMap['blocks'];
      final hasUsableSections = sections is List && sections.isNotEmpty;
      if (!hasUsableSections && blocks is List && blocks.isNotEmpty) {
        localeMap['sections'] = blocks;
      }
    }

    normalizeBlocksAlias(ptMap);
    normalizeBlocksAlias(esMap);

    // Some approved editorial CMS exports keep one reference ledger at root
    // instead of duplicating it inside both locales. Reuse it only when the
    // locale did not provide a usable list.
    final rootReferences = root['references'];
    if (rootReferences is List) {
      final ptReferences = ptMap['references'];
      final esReferences = esMap['references'];
      if (ptReferences is! List || ptReferences.isEmpty) {
        ptMap['references'] = rootReferences;
      }
      if (esReferences is! List || esReferences.isEmpty) {
        esMap['references'] = rootReferences;
      }
    }

    final pt = _parseLocale('pt', ptMap);
    final es = _parseLocale('es', esMap);

    if (pt.sourceTypes.length != es.sourceTypes.length) {
      throw const ClinicalGuideCmsImportException(
        'PT e ES possuem quantidades diferentes de sections.',
      );
    }

    for (var i = 0; i < pt.sourceTypes.length; i++) {
      if (pt.sourceTypes[i] != es.sourceTypes[i]) {
        throw ClinicalGuideCmsImportException(
          'Estrutura PT/ES divergente em sections[$i]: '
          '${pt.sourceTypes[i]} != ${es.sourceTypes[i]}.',
        );
      }
    }

    if (pt.references.length != es.references.length) {
      throw const ClinicalGuideCmsImportException(
        'PT e ES possuem quantidades diferentes de referências.',
      );
    }

    for (var i = 0; i < pt.references.length; i++) {
      if (pt.references[i] != es.references[i]) {
        throw ClinicalGuideCmsImportException(
          'Referências PT/ES divergentes na posição ${i + 1}.',
        );
      }
    }

    final reviewDate = _text(metadata['review_date']);
    var year = _text(metadata['year']);
    if (year.isEmpty && reviewDate.length >= 4) {
      final candidate = reviewDate.substring(0, 4);
      if (int.tryParse(candidate) != null) year = candidate;
    }

    // Editorial V1 files created for human approval commonly carry the
    // approval date in human_approval_note instead of metadata.review_date.
    // Derive only an explicitly present YYYY-MM-DD year; never invent one.
    if (year.isEmpty) {
      final approvalNote = _text(root['human_approval_note']);
      final match =
          RegExp(r'\b(20\d{2})-\d{2}-\d{2}\b').firstMatch(approvalNote);
      year = match?.group(1) ?? '';
    }

    // Year is editorial envelope metadata. If absent, keep it blank for
    // explicit Admin review instead of rejecting otherwise valid PT/ES data.

    final rawVersion = _text(metadata['version']);
    final version = _parseVersion(rawVersion);

    return ClinicalGuideCmsImportPackage(
      schemaVersion: schemaVersion,
      topicPt: _text(metadata['topic_pt']).isNotEmpty
          ? _text(metadata['topic_pt'])
          : pt.title,
      topicEs: _text(metadata['topic_es']).isNotEmpty
          ? _text(metadata['topic_es'])
          : es.title,
      specialty: _text(
        metadata['specialty_pt'] ??
            metadata['specialty_es'] ??
            metadata['specialty'] ??
            metadata['category'],
      ),
      authors: _text(metadata['authors']),
      year: year,
      version: version,
      pt: pt,
      es: es,
    );
  }

  static ClinicalGuideCmsImportLocale _parseLocale(
    String code,
    Map<String, dynamic> data,
  ) {
    final title = _requiredText(data, 'title', code);
    final subtitle = _requiredText(data, 'subtitle', code);
    final summary = _requiredText(data, 'summary', code);

    final rawSections = _asList(data['sections'], '$code.sections');
    if (rawSections.isEmpty) {
      throw ClinicalGuideCmsImportException(
        '$code.sections não pode estar vazio.',
      );
    }

    final blocks = <ClinicalGuideCmsImportBlock>[];
    final sourceTypes = <String>[];
    var tableConversions = 0;
    var algorithmConversions = 0;

    for (var i = 0; i < rawSections.length; i++) {
      final section = _asMap(rawSections[i], '$code.sections[$i]');
      final type = _text(section['type']).toLowerCase();

      if (!_supportedImportTypes.contains(type)) {
        throw ClinicalGuideCmsImportException(
          'Tipo de bloco não suportado em $code.sections[$i]: '
          '${type.isEmpty ? "(ausente)" : type}.',
        );
      }

      sourceTypes.add(type);

      if (type == 'table') {
        tableConversions++;
        blocks.addAll(_convertTable(section, code, i));
        continue;
      }

      if (type == 'algorithm') {
        algorithmConversions++;
        blocks.addAll(_convertAlgorithm(section, code, i));
        continue;
      }

      if (type == 'bullets') {
        final items = _asList(
          section['items'],
          '$code.sections[$i].items',
        ).map(_text).where((item) => item.isNotEmpty).toList(growable: false);

        if (items.isEmpty) {
          throw ClinicalGuideCmsImportException(
            '$code.sections[$i] bullets sem items.',
          );
        }

        blocks.add(
          ClinicalGuideCmsImportBlock(
            type: 'bullets',
            title: _text(section['title']),
            text: items.join('\n'),
          ),
        );
        continue;
      }

      final text = _text(
        section['text'] ?? (type == 'heading' ? section['title'] : null),
      );

      if (text.isEmpty) {
        throw ClinicalGuideCmsImportException(
          '$code.sections[$i] ($type) sem conteúdo.',
        );
      }

      blocks.add(
        ClinicalGuideCmsImportBlock(
          type: type,
          title: type == 'heading' ? '' : _text(section['title']),
          text: text,
        ),
      );
    }

    final rawReferences = _asList(data['references'], '$code.references');
    if (rawReferences.isEmpty) {
      throw ClinicalGuideCmsImportException(
        '$code.references não pode estar vazio.',
      );
    }

    final references = rawReferences
        .map((raw) => _formatReference(raw, code))
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    if (references.isEmpty) {
      throw ClinicalGuideCmsImportException(
        '$code.references não contém referências utilizáveis.',
      );
    }

    return ClinicalGuideCmsImportLocale(
      code: code,
      title: title,
      subtitle: subtitle,
      summary: summary,
      blocks: List.unmodifiable(blocks),
      references: List.unmodifiable(references),
      sourceTypes: List.unmodifiable(sourceTypes),
      tableConversions: tableConversions,
      algorithmConversions: algorithmConversions,
    );
  }

  static List<ClinicalGuideCmsImportBlock> _convertTable(
    Map<String, dynamic> section,
    String code,
    int index,
  ) {
    final title = _text(section['title']);
    final headers = _asList(
      section['headers'],
      '$code.sections[$index].headers',
    ).map(_text).toList(growable: false);

    final rows = _asList(section['rows'], '$code.sections[$index].rows');

    if (headers.isEmpty || rows.isEmpty) {
      throw ClinicalGuideCmsImportException(
        '$code.sections[$index] table requer headers e rows.',
      );
    }

    final items = <String>[];

    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final row = _asList(
        rows[rowIndex],
        '$code.sections[$index].rows[$rowIndex]',
      ).map(_text).toList(growable: false);

      if (row.isEmpty) continue;

      if (headers.length == 2 && row.length >= 2) {
        final left = row[0];
        final right = row[1];
        final line = [
          if (left.isNotEmpty) left,
          if (right.isNotEmpty) right,
        ].join(' — ');
        if (line.isNotEmpty) items.add(line);
        continue;
      }

      final parts = <String>[];
      for (var i = 0; i < row.length; i++) {
        final value = row[i];
        if (value.isEmpty) continue;
        final header = i < headers.length ? headers[i] : '';
        parts.add(header.isEmpty ? value : '$header: $value');
      }
      if (parts.isNotEmpty) items.add(parts.join(' · '));
    }

    if (items.isEmpty) {
      throw ClinicalGuideCmsImportException(
        '$code.sections[$index] table sem linhas utilizáveis.',
      );
    }

    return <ClinicalGuideCmsImportBlock>[
      if (title.isNotEmpty)
        ClinicalGuideCmsImportBlock(type: 'heading', text: title),
      ClinicalGuideCmsImportBlock(type: 'bullets', text: items.join('\n')),
    ];
  }

  static List<ClinicalGuideCmsImportBlock> _convertAlgorithm(
    Map<String, dynamic> section,
    String code,
    int index,
  ) {
    final title = _text(section['title']);
    final steps = _asList(
      section['steps'],
      '$code.sections[$index].steps',
    ).map(_text).where((item) => item.isNotEmpty).toList(growable: false);

    if (steps.isEmpty) {
      throw ClinicalGuideCmsImportException(
        '$code.sections[$index] algorithm sem steps.',
      );
    }

    return <ClinicalGuideCmsImportBlock>[
      if (title.isNotEmpty)
        ClinicalGuideCmsImportBlock(type: 'heading', text: title),
      ClinicalGuideCmsImportBlock(type: 'bullets', text: steps.join('\n')),
    ];
  }

  static String _formatReference(Object? raw, String code) {
    if (raw is String) return raw.trim();

    final map = _asMap(raw, '$code.references[]');

    final authors = _text(
      map['organization_or_authors'] ?? map['authors'] ?? map['organization'],
    );
    final title = _text(map['title']);
    final publication = _text(
      map['publication'] ?? map['journal'] ?? map['institution'],
    );
    final year = _text(map['year']);
    final doi = _text(map['doi']);
    final url = _text(map['url']);

    final parts = <String>[
      if (authors.isNotEmpty) _sentence(authors),
      if (title.isNotEmpty) _sentence(title),
      if (publication.isNotEmpty) _sentence(publication),
      if (year.isNotEmpty) _sentence(year),
      if (doi.isNotEmpty) 'DOI: $doi.',
      if (url.isNotEmpty) url,
    ];

    return parts.join(' ').trim();
  }

  static String _sentence(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.endsWith('.') ? trimmed : '$trimmed.';
  }

  static String _requiredText(
    Map<String, dynamic> data,
    String key,
    String code,
  ) {
    final value = _text(data[key]);
    if (value.isEmpty) {
      throw ClinicalGuideCmsImportException(
        'Campo obrigatório ausente: $code.$key.',
      );
    }
    return value;
  }

  static int _parseVersion(String raw) {
    if (raw.trim().isEmpty) return 1;

    final normalized = raw.trim();
    final direct = int.tryParse(normalized);
    if (direct != null && direct > 0) return direct;

    final major = normalized.split('.').first;
    final parsed = int.tryParse(major);
    if (parsed != null && parsed > 0) return parsed;

    throw ClinicalGuideCmsImportException('metadata.version inválida: $raw.');
  }

  static Map<String, dynamic> _asMap(Object? raw, String owner) {
    if (raw is Map<String, dynamic>) {
      return Map<String, dynamic>.of(raw);
    }

    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }

    throw ClinicalGuideCmsImportException('$owner deve ser um objeto JSON.');
  }

  static List<Object?> _asList(Object? raw, String owner) {
    if (raw is List) return List<Object?>.from(raw);

    throw ClinicalGuideCmsImportException('$owner deve ser uma lista JSON.');
  }

  static String _text(Object? raw) {
    if (raw == null) return '';
    return raw.toString().trim();
  }
}
