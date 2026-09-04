/// PHASE3I-J2F1: productive treatment presentation contract.
///
/// Represents only an explicitly assigned clinical presentation relationship.
/// It does not establish canonical drug identity, calculate doses, validate
/// regimens or infer a relationship from AI-generated free text.
enum ClinicalTreatmentRelation {
  concomitant,
  alternative,
  conditional,
  adjunct,
  rescue,
  sequenceStep,
  contraindicated,
  unclassified,
}

/// Safety information remains distinct from treatment relationships.
enum ClinicalSafetyFlagType {
  alert,
  hardStop,
}

final class ClinicalTreatmentPresentationItem {
  ClinicalTreatmentPresentationItem({
    required String text,
    required this.relation,
    String condition = '',
    String rationale = '',
  })  : text = _requireText(text, field: 'text'),
        condition = condition.trim(),
        rationale = rationale.trim();

  final String text;
  final ClinicalTreatmentRelation relation;
  final String condition;
  final String rationale;

  bool get isClassified => relation != ClinicalTreatmentRelation.unclassified;

  bool get isSafetyCritical =>
      relation == ClinicalTreatmentRelation.contraindicated;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'text': text,
      'relation': relation.name,
      if (condition.isNotEmpty) 'condition': condition,
      if (rationale.isNotEmpty) 'rationale': rationale,
    };
  }

  factory ClinicalTreatmentPresentationItem.fromJson(
    Map<String, Object?> json,
  ) {
    const allowedKeys = <String>{
      'text',
      'relation',
      'condition',
      'rationale',
    };
    const requiredKeys = <String>{
      'text',
      'relation',
    };

    final actualKeys = json.keys.toSet();

    if (!_sameOrSubsetKeys(
      actual: actualKeys,
      allowed: allowedKeys,
      required: requiredKeys,
    )) {
      throw const FormatException(
        'clinical_treatment_item_invalid_keys',
      );
    }

    final text = json['text'];
    final relation = json['relation'];
    final condition = json['condition'];
    final rationale = json['rationale'];

    if (text is! String) {
      throw const FormatException(
        'clinical_treatment_item_invalid_text',
      );
    }
    if (relation is! String) {
      throw const FormatException(
        'clinical_treatment_item_invalid_relation',
      );
    }
    if (condition != null && condition is! String) {
      throw const FormatException(
        'clinical_treatment_item_invalid_condition',
      );
    }
    if (rationale != null && rationale is! String) {
      throw const FormatException(
        'clinical_treatment_item_invalid_rationale',
      );
    }

    return ClinicalTreatmentPresentationItem(
      text: text,
      relation: _relationFromName(relation),
      condition: condition as String? ?? '',
      rationale: rationale as String? ?? '',
    );
  }

  static ClinicalTreatmentRelation _relationFromName(String name) {
    for (final relation in ClinicalTreatmentRelation.values) {
      if (relation.name == name) return relation;
    }
    throw FormatException(
      'clinical_treatment_item_unknown_relation:$name',
    );
  }

  static String _requireText(
    String value, {
    required String field,
  }) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw FormatException(
        'clinical_treatment_item_empty_$field',
      );
    }
    return normalized;
  }
}

final class ClinicalSafetyFlag {
  ClinicalSafetyFlag({
    required String text,
    required this.type,
  }) : text = _requireText(text);

  final String text;
  final ClinicalSafetyFlagType type;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'text': text,
      'type': type.name,
    };
  }

  factory ClinicalSafetyFlag.fromJson(
    Map<String, Object?> json,
  ) {
    const expectedKeys = <String>{
      'text',
      'type',
    };

    if (!_sameKeys(json.keys.toSet(), expectedKeys)) {
      throw const FormatException(
        'clinical_safety_flag_invalid_keys',
      );
    }

    final text = json['text'];
    final type = json['type'];

    if (text is! String || type is! String) {
      throw const FormatException(
        'clinical_safety_flag_invalid_values',
      );
    }

    return ClinicalSafetyFlag(
      text: text,
      type: _typeFromName(type),
    );
  }

  static ClinicalSafetyFlagType _typeFromName(String name) {
    for (final type in ClinicalSafetyFlagType.values) {
      if (type.name == name) return type;
    }
    throw FormatException(
      'clinical_safety_flag_unknown_type:$name',
    );
  }

  static String _requireText(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw const FormatException(
        'clinical_safety_flag_empty_text',
      );
    }
    return normalized;
  }
}

/// Immutable productive presentation payload.
///
/// Deliberately disconnected from ClinicalStructuredOutput in J2F1.
/// Parser, provider and renderer integration require separate authorization.
final class ClinicalTreatmentPresentation {
  ClinicalTreatmentPresentation({
    List<ClinicalTreatmentPresentationItem> items =
        const <ClinicalTreatmentPresentationItem>[],
    List<ClinicalSafetyFlag> safetyFlags = const <ClinicalSafetyFlag>[],
  })  : items = List<ClinicalTreatmentPresentationItem>.unmodifiable(items),
        safetyFlags = List<ClinicalSafetyFlag>.unmodifiable(safetyFlags);

  final List<ClinicalTreatmentPresentationItem> items;
  final List<ClinicalSafetyFlag> safetyFlags;

  bool get isEmpty => items.isEmpty && safetyFlags.isEmpty;

  List<ClinicalTreatmentPresentationItem> itemsFor(
    ClinicalTreatmentRelation relation,
  ) {
    return List<ClinicalTreatmentPresentationItem>.unmodifiable(
      items.where((item) => item.relation == relation),
    );
  }

  List<ClinicalSafetyFlag> flagsFor(
    ClinicalSafetyFlagType type,
  ) {
    return List<ClinicalSafetyFlag>.unmodifiable(
      safetyFlags.where((flag) => flag.type == type),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'items': items.map((item) => item.toJson()).toList(growable: false),
      'safetyFlags':
          safetyFlags.map((flag) => flag.toJson()).toList(growable: false),
    };
  }

  factory ClinicalTreatmentPresentation.fromJson(
    Map<String, Object?> json,
  ) {
    const expectedKeys = <String>{
      'items',
      'safetyFlags',
    };

    if (!_sameKeys(json.keys.toSet(), expectedKeys)) {
      throw const FormatException(
        'clinical_treatment_presentation_invalid_keys',
      );
    }

    final rawItems = json['items'];
    final rawSafetyFlags = json['safetyFlags'];

    if (rawItems is! List || rawSafetyFlags is! List) {
      throw const FormatException(
        'clinical_treatment_presentation_invalid_lists',
      );
    }

    final items = <ClinicalTreatmentPresentationItem>[];
    for (var index = 0; index < rawItems.length; index++) {
      final rawItem = rawItems[index];
      if (rawItem is! Map) {
        throw FormatException(
          'clinical_treatment_presentation_invalid_item:$index',
        );
      }
      items.add(
        ClinicalTreatmentPresentationItem.fromJson(
          Map<String, Object?>.from(rawItem),
        ),
      );
    }

    final safetyFlags = <ClinicalSafetyFlag>[];
    for (var index = 0; index < rawSafetyFlags.length; index++) {
      final rawFlag = rawSafetyFlags[index];
      if (rawFlag is! Map) {
        throw FormatException(
          'clinical_treatment_presentation_invalid_flag:$index',
        );
      }
      safetyFlags.add(
        ClinicalSafetyFlag.fromJson(
          Map<String, Object?>.from(rawFlag),
        ),
      );
    }

    return ClinicalTreatmentPresentation(
      items: items,
      safetyFlags: safetyFlags,
    );
  }
}

bool _sameKeys(Set<String> actual, Set<String> expected) {
  return actual.length == expected.length && actual.containsAll(expected);
}

bool _sameOrSubsetKeys({
  required Set<String> actual,
  required Set<String> allowed,
  required Set<String> required,
}) {
  return actual.difference(allowed).isEmpty && actual.containsAll(required);
}
