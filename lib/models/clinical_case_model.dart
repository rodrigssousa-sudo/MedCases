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
    String _resolveField(dynamic field) {
      if (field == null) return '';
      if (field is String) return field;
      if (field is Map) {
        return (field['pt'] ?? field['es'] ?? field.values.firstOrNull ?? '') as String;
      }
      return '';
    }

    // Old format had 'drugs', new format has 'drugIds'
    final drugsRaw = json['drugIds'] ?? json['drugs'] ?? [];
    final drugIds = (drugsRaw is List) ? drugsRaw.cast<String>() : <String>[];

    return ClinicalCaseModel(
      id: json['id'] ?? 'case_${UniqueKey().hashCode}',
      title: _resolveField(json['title']),
      patientAge: json['patientAge'] ?? _resolveField(json['patient'])
          .split('•').skip(1).firstOrNull?.replaceAll(RegExp(r'[^\d]'), '').trim() ?? '',
      patientSex: json['patientSex'] ?? 'Masculino',
      patientWeight: json['patientWeight'] ?? '',
      history: _resolveField(json['history']),
      diagnosis: _resolveField(json['diagnosis']),
      plan: _resolveField(json['plan']),
      notes: json['notes'] ?? '',
      category: json['category'] ?? 'Emergência',
      drugIds: drugIds,
      isCustom: json['isCustom'] ?? false,
      createdAt: json['createdAt'],
    );
  }
}
