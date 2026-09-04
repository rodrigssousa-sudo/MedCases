import 'dart:convert';

class PlantaoNormalizedDrugEvidenceIdentity {
  const PlantaoNormalizedDrugEvidenceIdentity({
    required this.drugId,
    required this.namePt,
    required this.nameEs,
    required this.category,
    required this.keywords,
    required this.schema,
    required this.sourceModule,
    required this.hasContextVariants,
    required this.contextVariantCount,
    required this.canonicalOwner,
  });

  factory PlantaoNormalizedDrugEvidenceIdentity.fromLegacyIndex(
    Map<String, Object?> json,
  ) {
    return PlantaoNormalizedDrugEvidenceIdentity._fromJson(
      json,
      drugIdKey: 'id',
      schemaKey: 'schema',
    );
  }

  factory PlantaoNormalizedDrugEvidenceIdentity.fromRemoteIndex(
    Map<String, Object?> json,
  ) {
    return PlantaoNormalizedDrugEvidenceIdentity._fromJson(
      json,
      drugIdKey: 'drugId',
      schemaKey: 'calculatorSchema',
    );
  }

  factory PlantaoNormalizedDrugEvidenceIdentity._fromJson(
    Map<String, Object?> json, {
    required String drugIdKey,
    required String schemaKey,
  }) {
    final name = _stringMap(json['name']);
    final keywords = _stringList(json['keywords'])..sort();

    return PlantaoNormalizedDrugEvidenceIdentity(
      drugId: _requiredString(json[drugIdKey], drugIdKey),
      namePt: _requiredString(name['pt'], 'name.pt'),
      nameEs: _requiredString(name['es'], 'name.es'),
      category: _optionalString(json['category']),
      keywords: List.unmodifiable(keywords),
      schema: _optionalString(json[schemaKey]),
      sourceModule: _optionalString(json['sourceModule']),
      hasContextVariants: json['hasContextVariants'] == true,
      contextVariantCount: (json['contextVariantCount'] as num?)?.toInt() ?? 0,
      canonicalOwner: _optionalString(json['canonicalOwner']),
    );
  }

  final String drugId;
  final String namePt;
  final String nameEs;
  final String category;
  final List<String> keywords;
  final String schema;
  final String sourceModule;
  final bool hasContextVariants;
  final int contextVariantCount;
  final String canonicalOwner;

  Map<String, Object?> toJson() => <String, Object?>{
        'drugId': drugId,
        'name': <String, String>{'pt': namePt, 'es': nameEs},
        'category': category,
        'keywords': keywords,
        'schema': schema,
        'sourceModule': sourceModule,
        'hasContextVariants': hasContextVariants,
        'contextVariantCount': contextVariantCount,
        'canonicalOwner': canonicalOwner,
      };

  String get canonicalJson => jsonEncode(toJson());

  @override
  bool operator ==(Object other) {
    return other is PlantaoNormalizedDrugEvidenceIdentity &&
        canonicalJson == other.canonicalJson;
  }

  @override
  int get hashCode => canonicalJson.hashCode;

  static Map<String, Object?> _stringMap(Object? value) {
    if (value is! Map<Object?, Object?>) {
      throw const FormatException('Drug evidence name must be an object');
    }
    return value.map(
      (Object? key, Object? item) =>
          MapEntry<String, Object?>(key.toString(), item),
    );
  }

  static List<String> _stringList(Object? value) {
    if (value == null) return <String>[];
    if (value is! List<Object?>) {
      throw const FormatException('Drug evidence keywords must be a list');
    }
    return value
        .map((Object? item) => _requiredString(item, 'keywords[]'))
        .toSet()
        .toList();
  }

  static String _requiredString(Object? value, String field) {
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Drug evidence $field must be a non-empty string');
    }
    return value.trim();
  }

  static String _optionalString(Object? value) {
    return value is String ? value.trim() : '';
  }
}
