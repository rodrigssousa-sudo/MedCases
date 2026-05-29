import 'package:flutter/foundation.dart';

class ClinicalCaseModel {
  final String id;
  final String title;
  final String patientAge;
  final String patientSex;
  final String patientWeight;
  final String history;
  final String diagnosis;
  final String plan;
  final String notes;
  final String category;
  final List<String> drugIds;
  final bool isCustom;
  final String? createdAt;

  const ClinicalCaseModel({
    required this.id,
    required this.title,
    this.patientAge = '',
    this.patientSex = 'Masculino',
    this.patientWeight = '',
    this.history = '',
    this.diagnosis = '',
    this.plan = '',
    this.notes = '',
    this.category = 'Emergência',
    this.drugIds = const [],
    this.isCustom = false,
    this.createdAt,
  });

  factory ClinicalCaseModel.blank() {
    return ClinicalCaseModel(
      id: 'case_${DateTime.now().millisecondsSinceEpoch}',
      title: '',
      isCustom: true,
      createdAt: DateTime.now().toIso8601String(),
    );
  }

  ClinicalCaseModel copyWith({
    String? id,
    String? title,
    String? patientAge,
    String? patientSex,
    String? patientWeight,
    String? history,
    String? diagnosis,
    String? plan,
    String? notes,
    String? category,
    List<String>? drugIds,
    bool? isCustom,
    String? createdAt,
  }) {
    return ClinicalCaseModel(
      id: id ?? this.id,
      title: title ?? this.title,
      patientAge: patientAge ?? this.patientAge,
      patientSex: patientSex ?? this.patientSex,
      patientWeight: patientWeight ?? this.patientWeight,
      history: history ?? this.history,
      diagnosis: diagnosis ?? this.diagnosis,
      plan: plan ?? this.plan,
      notes: notes ?? this.notes,
      category: category ?? this.category,
      drugIds: drugIds ?? this.drugIds,
      isCustom: isCustom ?? this.isCustom,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'patientAge': patientAge,
      'patientSex': patientSex,
      'patientWeight': patientWeight,
      'history': history,
      'diagnosis': diagnosis,
      'plan': plan,
      'notes': notes,
      'category': category,
      'drugIds': drugIds,
      'isCustom': isCustom,
      'createdAt': createdAt,
    };
  }

  factory ClinicalCaseModel.fromJson(Map<String, dynamic> json) {
    // Support both old multilingual format and new flat format
    // SEGURO: nunca usa `as String` — dart2js release lança TypeError em qualquer cast errado
    String _resolveField(dynamic field) {
      if (field == null) return '';
      if (field is String) return field;
      if (field is Map) {
        // SEGURO: usa ?.toString() em vez de `as String`
        final v = field['pt'] ?? field['es'] ?? (field.isNotEmpty ? field.values.first : null);
        return v?.toString() ?? '';
      }
      return field.toString();
    }

    // Old format had 'drugs', new format has 'drugIds'
    // SEGURO: usa map(e => toString()) em vez de .cast<String>() que falha em release
    final drugsRaw = json['drugIds'] ?? json['drugs'] ?? const [];
    final drugIds = (drugsRaw is List)
        ? drugsRaw.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList()
        : <String>[];

    return ClinicalCaseModel(
      id: json['id']?.toString() ?? 'case_${UniqueKey().hashCode}',
      title: _resolveField(json['title']),
      patientAge: json['patientAge']?.toString() ?? _resolveField(json['patient'])
          .split('•').skip(1).firstOrNull?.replaceAll(RegExp(r'[^\d]'), '').trim() ?? '',
      patientSex: json['patientSex']?.toString() ?? 'Masculino',
      patientWeight: json['patientWeight']?.toString() ?? '',
      history: _resolveField(json['history']),
      diagnosis: _resolveField(json['diagnosis']),
      plan: _resolveField(json['plan']),
      notes: json['notes']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Emergência',
      drugIds: drugIds,
      isCustom: json['isCustom'] == true || json['isCustom']?.toString() == 'true',
      createdAt: json['createdAt']?.toString(),
    );
  }
}
