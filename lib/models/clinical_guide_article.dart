class ClinicalGuideBlock {
  const ClinicalGuideBlock({
    required this.type,
    this.title = '',
    this.text = '',
    this.items = const <String>[],
  });

  final String type;
  final String title;
  final String text;
  final List<String> items;

  factory ClinicalGuideBlock.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return ClinicalGuideBlock(
      type: _string(json['type'], fallback: 'paragraph'),
      title: _string(json['title']),
      text: _firstNonEmpty(json, const ['text', 'content', 'body']),
      items: rawItems is List
          ? rawItems
                .map((item) => item?.toString().trim() ?? '')
                .where((item) => item.isNotEmpty)
                .toList(growable: false)
          : const <String>[],
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': type,
    if (title.isNotEmpty) 'title': title,
    if (text.isNotEmpty) 'text': text,
    if (items.isNotEmpty) 'items': items,
  };
}

class ClinicalGuideArticle {
  const ClinicalGuideArticle({
    required this.id,
    required this.title,
    this.slug = '',
    this.language = 'es',
    this.specialty = 'Geral',
    this.subtitle = '',
    this.heroImageUrl = '',
    this.summary = '',
    this.bodyBlocks = const <ClinicalGuideBlock>[],
    this.references = const <String>[],
    this.pdfUrl = '',
    this.authors = '',
    this.year = '',
    this.status = 'published',
    this.isPublished = true,
    this.publishedAt,
    this.updatedAt,
    this.version = 1,
    this.localizations = const <String, dynamic>{},
  });

  final String id;
  final String slug;
  final String language;
  final String specialty;
  final String title;
  final String subtitle;
  final String heroImageUrl;
  final String summary;
  final List<ClinicalGuideBlock> bodyBlocks;
  final List<String> references;
  final String pdfUrl;
  final String authors;
  final String year;
  final String status;
  final bool isPublished;
  final DateTime? publishedAt;
  final DateTime? updatedAt;
  final int version;
  // MEDCASES_GUIDES_BILINGUAL_CMS_V1_B_R4
  final Map<String, dynamic> localizations;

  bool get hasEditorialBody => bodyBlocks.isNotEmpty;
  ClinicalGuideArticle forLanguage(String requestedLanguage) {
    final code = requestedLanguage.trim().toLowerCase().startsWith('es')
        ? 'es'
        : 'pt';
    final raw = localizations[code];

    Map<String, dynamic>? locale;
    if (raw is Map<String, dynamic>) {
      locale = raw;
    } else if (raw is Map) {
      locale = raw.map((key, value) => MapEntry(key.toString(), value));
    }

    if (locale == null || locale.isEmpty) return this;

    return ClinicalGuideArticle.fromJson(<String, dynamic>{
      ...toJson(),
      ...locale,
      'id': id,
      'language': code,
      'localizations': localizations,
    }, documentId: id);
  }

  factory ClinicalGuideArticle.fromJson(
    Map<String, dynamic> json, {
    String documentId = '',
  }) {
    final rawBlocks = json['bodyBlocks'];
    final blocks = <ClinicalGuideBlock>[];

    if (rawBlocks is List) {
      for (final raw in rawBlocks) {
        if (raw is Map<String, dynamic>) {
          blocks.add(ClinicalGuideBlock.fromJson(raw));
        } else if (raw is Map) {
          blocks.add(
            ClinicalGuideBlock.fromJson(
              raw.map((key, value) => MapEntry(key.toString(), value)),
            ),
          );
        }
      }
    }

    final legacyContent = _firstNonEmpty(json, const [
      'content',
      'body',
      'articleBody',
    ]);

    if (blocks.isEmpty && legacyContent.isNotEmpty) {
      blocks.add(ClinicalGuideBlock(type: 'paragraph', text: legacyContent));
    }

    final references = _stringList(json['references']);
    final rawPublished = json['isPublished'];
    final status = _firstNonEmpty(json, const [
      'status',
    ], fallback: _asBool(rawPublished, fallback: true) ? 'published' : 'draft');
    final isPublished = _asBool(
      rawPublished,
      fallback: status.toLowerCase() == 'published',
    );

    final rawLocalizations = json['localizations'];
    final localizations = <String, dynamic>{};
    if (rawLocalizations is Map<String, dynamic>) {
      localizations.addAll(rawLocalizations);
    } else if (rawLocalizations is Map) {
      for (final entry in rawLocalizations.entries) {
        localizations[entry.key.toString()] = entry.value;
      }
    }

    return ClinicalGuideArticle(
      id: _firstNonEmpty(json, const ['id'], fallback: documentId),
      slug: _firstNonEmpty(json, const ['slug']),
      language: _firstNonEmpty(json, const [
        'language',
        'lang',
      ], fallback: 'es'),
      specialty: _firstNonEmpty(json, const [
        'specialty',
        'category',
      ], fallback: 'Geral'),
      title: _firstNonEmpty(json, const ['title', 'name', 'titulo']),
      subtitle: _firstNonEmpty(json, const ['subtitle', 'subTitle']),
      heroImageUrl: _firstNonEmpty(json, const [
        'heroImageUrl',
        'coverUrl',
        'imageUrl',
        'thumbnailUrl',
        'coverImageUrl',
      ]),
      summary: _firstNonEmpty(json, const ['summary', 'description']),
      bodyBlocks: blocks,
      references: references,
      pdfUrl: _firstNonEmpty(json, const [
        'pdfUrl',
        'fileUrl',
        'url',
        'downloadUrl',
      ]),
      authors: _firstNonEmpty(json, const ['authors', 'author']),
      year: _firstNonEmpty(json, const ['year']),
      status: status,
      isPublished: isPublished,
      publishedAt: _asDateTime(json['publishedAt'] ?? json['uploadedAt']),
      updatedAt: _asDateTime(json['updatedAt']),
      version: _asInt(json['version'], fallback: 1),
      localizations: localizations,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (id.isNotEmpty) 'id': id,
    if (slug.isNotEmpty) 'slug': slug,
    'language': language,
    'specialty': specialty,
    'title': title,
    if (subtitle.isNotEmpty) 'subtitle': subtitle,
    if (heroImageUrl.isNotEmpty) 'heroImageUrl': heroImageUrl,
    if (summary.isNotEmpty) 'summary': summary,
    if (bodyBlocks.isNotEmpty)
      'bodyBlocks': bodyBlocks
          .map((block) => block.toJson())
          .toList(growable: false),
    if (references.isNotEmpty) 'references': references,
    if (pdfUrl.isNotEmpty) 'pdfUrl': pdfUrl,
    if (authors.isNotEmpty) 'authors': authors,
    if (year.isNotEmpty) 'year': year,
    'status': status,
    'isPublished': isPublished,
    if (publishedAt != null) 'publishedAt': publishedAt!.toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    'version': version,
    if (localizations.isNotEmpty) 'localizations': localizations,
  };
}

String _string(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String _firstNonEmpty(
  Map<String, dynamic> json,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = _string(json[key]);
    if (value.isNotEmpty) return value;
  }
  return fallback;
}

bool _asBool(Object? value, {required bool fallback}) {
  if (value is bool) return value;
  final text = value?.toString().trim().toLowerCase();
  if (text == 'true' || text == '1') return true;
  if (text == 'false' || text == '0') return false;
  return fallback;
}

int _asInt(Object? value, {required int fallback}) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

List<String> _stringList(Object? value) {
  if (value is List) {
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return const <String>[];

  return text
      .split(RegExp(r'\r?\n'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

DateTime? _asDateTime(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;

  try {
    final dynamic dynamicValue = value;
    final converted = dynamicValue.toDate();
    if (converted is DateTime) return converted;
  } catch (_) {
    // Not a Firestore Timestamp-like object.
  }

  return DateTime.tryParse(value.toString());
}
