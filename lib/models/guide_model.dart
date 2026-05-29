import 'package:flutter/foundation.dart' show debugPrint;

class GuideModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final String authors;
  final String year;
  final String pdfUrl;
  final String fileName;
  final int fileSize; // bytes
  final String uploadedAt;
  final String uploadedBy;
  final bool isPublished;
  final int downloadCount;

  const GuideModel({
    required this.id,
    required this.title,
    this.description = '',
    this.category = 'Geral',
    this.authors = '',
    this.year = '',
    required this.pdfUrl,
    required this.fileName,
    this.fileSize = 0,
    required this.uploadedAt,
    this.uploadedBy = '',
    this.isPublished = true,
    this.downloadCount = 0,
  });

  static const List<String> categories = [
    'Geral',
    'Cardiologia',
    'Infectologia',
    'Emergência',
    'Pediatria',
    'Neurologia',
    'Pneumologia',
    'Nefrologia',
    'Endocrinologia',
    'Gastroenterologia',
    'Oncologia',
    'Cirurgia',
    'UTI / Intensivismo',
    'Farmacologia',
    'Diretrizes Nacionais',
    'Diretrizes Internacionais',
  ];

  String get fileSizeLabel {
    if (fileSize <= 0) return '';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(0)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'category': category,
    'authors': authors,
    'year': year,
    'pdfUrl': pdfUrl,
    'fileName': fileName,
    'fileSize': fileSize,
    'uploadedAt': uploadedAt,
    'uploadedBy': uploadedBy,
    'isPublished': isPublished,
    'downloadCount': downloadCount,
  };

  /// Parse seguro: aceita campos alternativos de URL e título.
  /// Nunca usa casts diretos (as T) — imune a TypeError em dart2js release.
  factory GuideModel.fromJson(Map<String, dynamic> json) {
    // ── pdfUrl: aceita pdfUrl, fileUrl, url, downloadUrl ──────────────────
    final pdfUrl = _firstNonEmpty(json, ['pdfUrl', 'fileUrl', 'url', 'downloadUrl']);

    // ── title: aceita title, name, titulo ─────────────────────────────────
    final title = _firstNonEmpty(json, ['title', 'name', 'titulo']);

    // ── isPublished: aceita bool true ou string "true" ─────────────────────
    // SEGURO: sem cast — testa igualdade antes
    final rawPublished = json['isPublished'];
    final isPublished  = rawPublished == true
        || rawPublished?.toString().toLowerCase() == 'true';

    // ── fileSize e downloadCount: aceita num ou string ─────────────────────
    final rawSize  = json['fileSize'];
    final fileSize = rawSize is num
        ? rawSize.toInt()
        : int.tryParse(rawSize?.toString() ?? '') ?? 0;

    final rawCount    = json['downloadCount'];
    final downloadCount = rawCount is num
        ? rawCount.toInt()
        : int.tryParse(rawCount?.toString() ?? '') ?? 0;

    // ── LOG diagnóstico (kDebugMode via debugPrint — silencioso em release) ─
    debugPrint(
      '[GuideModel.fromJson] id=${json['id']?.toString() ?? ''} '
      'title="$title" pdfUrl="$pdfUrl" '
      'isPublished=$isPublished rawPublished=$rawPublished',
    );

    return GuideModel(
      id:            json['id']?.toString() ?? '',
      title:         title,
      description:   json['description']?.toString() ?? '',
      category:      json['category']?.toString() ?? 'Geral',
      authors:       json['authors']?.toString() ?? '',
      year:          json['year']?.toString() ?? '',
      pdfUrl:        pdfUrl,
      fileName:      json['fileName']?.toString() ?? '',
      fileSize:      fileSize,
      uploadedAt:    json['uploadedAt']?.toString() ?? '',
      uploadedBy:    json['uploadedBy']?.toString() ?? '',
      isPublished:   isPublished,
      downloadCount: downloadCount,
    );
  }

  /// Retorna o primeiro valor não-vazio dos campos tentados, em ordem.
  static String _firstNonEmpty(Map<String, dynamic> json, List<String> keys) {
    for (final k in keys) {
      final v = json[k]?.toString().trim() ?? '';
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  GuideModel copyWith({
    String? id, String? title, String? description, String? category,
    String? authors, String? year, String? pdfUrl, String? fileName,
    int? fileSize, String? uploadedAt, String? uploadedBy,
    bool? isPublished, int? downloadCount,
  }) => GuideModel(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    category: category ?? this.category,
    authors: authors ?? this.authors,
    year: year ?? this.year,
    pdfUrl: pdfUrl ?? this.pdfUrl,
    fileName: fileName ?? this.fileName,
    fileSize: fileSize ?? this.fileSize,
    uploadedAt: uploadedAt ?? this.uploadedAt,
    uploadedBy: uploadedBy ?? this.uploadedBy,
    isPublished: isPublished ?? this.isPublished,
    downloadCount: downloadCount ?? this.downloadCount,
  );
}
