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

  factory GuideModel.fromJson(Map<String, dynamic> json) => GuideModel(
    id: json['id'] ?? '',
    title: json['title'] ?? '',
    description: json['description'] ?? '',
    category: json['category'] ?? 'Geral',
    authors: json['authors'] ?? '',
    year: json['year'] ?? '',
    pdfUrl: json['pdfUrl'] ?? '',
    fileName: json['fileName'] ?? '',
    fileSize: (json['fileSize'] as num?)?.toInt() ?? 0,
    uploadedAt: json['uploadedAt'] ?? '',
    uploadedBy: json['uploadedBy'] ?? '',
    isPublished: json['isPublished'] ?? true,
    downloadCount: (json['downloadCount'] as num?)?.toInt() ?? 0,
  );

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
