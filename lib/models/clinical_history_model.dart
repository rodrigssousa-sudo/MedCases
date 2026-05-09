import 'package:flutter/foundation.dart';

/// Seção de evolução/nota de progresso
class EvolutionEntry {
  final String id;
  final String date;       // ISO8601
  final String author;     // nome do profissional
  final String text;       // texto livre
  final String type;       // 'evolution' | 'nursing' | 'lab' | 'imaging' | 'procedure'

  const EvolutionEntry({
    required this.id,
    required this.date,
    required this.author,
    required this.text,
    this.type = 'evolution',
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'date': date, 'author': author, 'text': text, 'type': type,
  };

  factory EvolutionEntry.fromJson(Map<String, dynamic> j) => EvolutionEntry(
    id: j['id'] ?? '',
    date: j['date'] ?? '',
    author: j['author'] ?? '',
    text: j['text'] ?? '',
    type: j['type'] ?? 'evolution',
  );

  factory EvolutionEntry.blank() => EvolutionEntry(
    id: 'evo_${DateTime.now().millisecondsSinceEpoch}',
    date: DateTime.now().toIso8601String(),
    author: '',
    text: '',
    type: 'evolution',
  );

  EvolutionEntry copyWith({String? id, String? date, String? author, String? text, String? type}) =>
    EvolutionEntry(
      id: id ?? this.id, date: date ?? this.date,
      author: author ?? this.author, text: text ?? this.text,
      type: type ?? this.type,
    );
}

/// Modelo principal de história clínica
class ClinicalHistoryModel {
  final String id;
  final String createdAt;
  final String updatedAt;
  final String authorUid;      // uid do criador
  final String authorName;     // nome exibível
  final String authorEmail;    // e-mail do criador
  final String uploadedAt;     // timestamp de quando foi publicado
  final bool isPublic;         // compartilhado com todos

  // ── Identificação do paciente ───────────────────────────────────────────
  final String patientInitials; // ex: "J.S." (privacidade)
  final String patientAge;
  final String patientSex;
  final String patientWeight;
  final String patientHeight;
  final String patientRecord;   // número de prontuário (opcional)

  // ── Anamnese ────────────────────────────────────────────────────────────
  final String chiefComplaint;      // Queixa principal
  final String hpi;                 // História da doença atual
  final String pastHistory;         // Antecedentes pessoais
  final String familyHistory;       // Antecedentes familiares
  final String socialHistory;       // História social (tabagismo, etilismo, etc.)
  final String medications;         // Medicamentos em uso
  final String allergies;           // Alergias
  final String reviewOfSystems;     // Revisão de sistemas

  // ── Exame físico ─────────────────────────────────────────────────────────
  final String vitalSigns;          // PA, FC, FR, Temp, SpO2, Peso
  final String physicalExam;        // Exame físico por sistemas

  // ── Diagnóstico ──────────────────────────────────────────────────────────
  final String workingDiagnosis;    // Hipótese diagnóstica principal
  final String differentialDx;      // Diagnóstico diferencial
  final String finalDiagnosis;      // Diagnóstico final (CID)
  final String cid;                 // Código CID

  // ── Exames e resultados ───────────────────────────────────────────────────
  final String labResults;          // Resultados laboratoriais
  final String imagingResults;      // Exames de imagem
  final String otherResults;        // Outros exames (ECG, biopsia, etc.)

  // ── Conduta / Tratamento ──────────────────────────────────────────────────
  final String treatmentPlan;       // Plano de tratamento
  final String procedures;          // Procedimentos realizados
  final List<String> drugIds;       // Fármacos vinculados

  // ── Evolução (notas de progresso sequenciais) ─────────────────────────────
  final List<EvolutionEntry> evolutions;

  // ── Alta / Desfecho ───────────────────────────────────────────────────────
  final String outcome;             // 'internado' | 'alta' | 'obito' | 'transferencia'
  final String dischargeCondition;  // Condições de alta
  final String followUp;            // Seguimento ambulatorial / instruções

  // ── Metadados ─────────────────────────────────────────────────────────────
  final String category;            // Especialidade
  final String tags;                // Tags livres (ex: "sepse, UTI, pediatria")

  const ClinicalHistoryModel({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.authorUid,
    this.authorName = '',
    this.authorEmail = '',
    this.uploadedAt = '',
    this.isPublic = false,
    this.patientInitials = '',
    this.patientAge = '',
    this.patientSex = 'Masculino',
    this.patientWeight = '',
    this.patientHeight = '',
    this.patientRecord = '',
    this.chiefComplaint = '',
    this.hpi = '',
    this.pastHistory = '',
    this.familyHistory = '',
    this.socialHistory = '',
    this.medications = '',
    this.allergies = '',
    this.reviewOfSystems = '',
    this.vitalSigns = '',
    this.physicalExam = '',
    this.workingDiagnosis = '',
    this.differentialDx = '',
    this.finalDiagnosis = '',
    this.cid = '',
    this.labResults = '',
    this.imagingResults = '',
    this.otherResults = '',
    this.treatmentPlan = '',
    this.procedures = '',
    this.drugIds = const [],
    this.evolutions = const [],
    this.outcome = 'internado',
    this.dischargeCondition = '',
    this.followUp = '',
    this.category = 'Clínica Geral',
    this.tags = '',
  });

  factory ClinicalHistoryModel.blank({required String authorUid, String authorName = '', String authorEmail = ''}) {
    final now = DateTime.now().toIso8601String();
    return ClinicalHistoryModel(
      id: 'hc_${DateTime.now().millisecondsSinceEpoch}',
      createdAt: now,
      updatedAt: now,
      authorUid: authorUid,
      authorName: authorName,
      authorEmail: authorEmail,
    );
  }

  ClinicalHistoryModel copyWith({
    String? id, String? createdAt, String? updatedAt, String? authorUid,
    String? authorName, String? authorEmail, String? uploadedAt, bool? isPublic,
    String? patientInitials, String? patientAge, String? patientSex,
    String? patientWeight, String? patientHeight, String? patientRecord,
    String? chiefComplaint, String? hpi, String? pastHistory,
    String? familyHistory, String? socialHistory, String? medications,
    String? allergies, String? reviewOfSystems,
    String? vitalSigns, String? physicalExam,
    String? workingDiagnosis, String? differentialDx, String? finalDiagnosis, String? cid,
    String? labResults, String? imagingResults, String? otherResults,
    String? treatmentPlan, String? procedures, List<String>? drugIds,
    List<EvolutionEntry>? evolutions,
    String? outcome, String? dischargeCondition, String? followUp,
    String? category, String? tags,
  }) {
    return ClinicalHistoryModel(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now().toIso8601String(),
      authorUid: authorUid ?? this.authorUid,
      authorName: authorName ?? this.authorName,
      authorEmail: authorEmail ?? this.authorEmail,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      isPublic: isPublic ?? this.isPublic,
      patientInitials: patientInitials ?? this.patientInitials,
      patientAge: patientAge ?? this.patientAge,
      patientSex: patientSex ?? this.patientSex,
      patientWeight: patientWeight ?? this.patientWeight,
      patientHeight: patientHeight ?? this.patientHeight,
      patientRecord: patientRecord ?? this.patientRecord,
      chiefComplaint: chiefComplaint ?? this.chiefComplaint,
      hpi: hpi ?? this.hpi,
      pastHistory: pastHistory ?? this.pastHistory,
      familyHistory: familyHistory ?? this.familyHistory,
      socialHistory: socialHistory ?? this.socialHistory,
      medications: medications ?? this.medications,
      allergies: allergies ?? this.allergies,
      reviewOfSystems: reviewOfSystems ?? this.reviewOfSystems,
      vitalSigns: vitalSigns ?? this.vitalSigns,
      physicalExam: physicalExam ?? this.physicalExam,
      workingDiagnosis: workingDiagnosis ?? this.workingDiagnosis,
      differentialDx: differentialDx ?? this.differentialDx,
      finalDiagnosis: finalDiagnosis ?? this.finalDiagnosis,
      cid: cid ?? this.cid,
      labResults: labResults ?? this.labResults,
      imagingResults: imagingResults ?? this.imagingResults,
      otherResults: otherResults ?? this.otherResults,
      treatmentPlan: treatmentPlan ?? this.treatmentPlan,
      procedures: procedures ?? this.procedures,
      drugIds: drugIds ?? this.drugIds,
      evolutions: evolutions ?? this.evolutions,
      outcome: outcome ?? this.outcome,
      dischargeCondition: dischargeCondition ?? this.dischargeCondition,
      followUp: followUp ?? this.followUp,
      category: category ?? this.category,
      tags: tags ?? this.tags,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'createdAt': createdAt, 'updatedAt': updatedAt,
    'authorUid': authorUid, 'authorName': authorName,
    'authorEmail': authorEmail, 'uploadedAt': uploadedAt,
    'isPublic': isPublic,
    'patientInitials': patientInitials, 'patientAge': patientAge,
    'patientSex': patientSex, 'patientWeight': patientWeight,
    'patientHeight': patientHeight, 'patientRecord': patientRecord,
    'chiefComplaint': chiefComplaint, 'hpi': hpi,
    'pastHistory': pastHistory, 'familyHistory': familyHistory,
    'socialHistory': socialHistory, 'medications': medications,
    'allergies': allergies, 'reviewOfSystems': reviewOfSystems,
    'vitalSigns': vitalSigns, 'physicalExam': physicalExam,
    'workingDiagnosis': workingDiagnosis, 'differentialDx': differentialDx,
    'finalDiagnosis': finalDiagnosis, 'cid': cid,
    'labResults': labResults, 'imagingResults': imagingResults,
    'otherResults': otherResults,
    'treatmentPlan': treatmentPlan, 'procedures': procedures,
    'drugIds': drugIds,
    'evolutions': evolutions.map((e) => e.toJson()).toList(),
    'outcome': outcome, 'dischargeCondition': dischargeCondition,
    'followUp': followUp, 'category': category, 'tags': tags,
  };

  factory ClinicalHistoryModel.fromJson(Map<String, dynamic> j) {
    final evoRaw = j['evolutions'] as List<dynamic>? ?? [];
    return ClinicalHistoryModel(
      id: j['id'] ?? '',
      createdAt: j['createdAt'] ?? DateTime.now().toIso8601String(),
      updatedAt: j['updatedAt'] ?? DateTime.now().toIso8601String(),
      authorUid: j['authorUid'] ?? '',
      authorName: j['authorName'] ?? '',
      authorEmail: j['authorEmail'] ?? '',
      uploadedAt: j['uploadedAt'] ?? '',
      isPublic: j['isPublic'] ?? false,
      patientInitials: j['patientInitials'] ?? '',
      patientAge: j['patientAge'] ?? '',
      patientSex: j['patientSex'] ?? 'Masculino',
      patientWeight: j['patientWeight'] ?? '',
      patientHeight: j['patientHeight'] ?? '',
      patientRecord: j['patientRecord'] ?? '',
      chiefComplaint: j['chiefComplaint'] ?? '',
      hpi: j['hpi'] ?? '',
      pastHistory: j['pastHistory'] ?? '',
      familyHistory: j['familyHistory'] ?? '',
      socialHistory: j['socialHistory'] ?? '',
      medications: j['medications'] ?? '',
      allergies: j['allergies'] ?? '',
      reviewOfSystems: j['reviewOfSystems'] ?? '',
      vitalSigns: j['vitalSigns'] ?? '',
      physicalExam: j['physicalExam'] ?? '',
      workingDiagnosis: j['workingDiagnosis'] ?? '',
      differentialDx: j['differentialDx'] ?? '',
      finalDiagnosis: j['finalDiagnosis'] ?? '',
      cid: j['cid'] ?? '',
      labResults: j['labResults'] ?? '',
      imagingResults: j['imagingResults'] ?? '',
      otherResults: j['otherResults'] ?? '',
      treatmentPlan: j['treatmentPlan'] ?? '',
      procedures: j['procedures'] ?? '',
      drugIds: (j['drugIds'] as List<dynamic>? ?? []).cast<String>(),
      evolutions: evoRaw.map((e) => EvolutionEntry.fromJson(e as Map<String, dynamic>)).toList(),
      outcome: j['outcome'] ?? 'internado',
      dischargeCondition: j['dischargeCondition'] ?? '',
      followUp: j['followUp'] ?? '',
      category: j['category'] ?? 'Clínica Geral',
      tags: j['tags'] ?? '',
    );
  }

  /// Título curto para exibir na lista
  String get displayTitle {
    if (chiefComplaint.isNotEmpty) return chiefComplaint;
    if (workingDiagnosis.isNotEmpty) return workingDiagnosis;
    if (finalDiagnosis.isNotEmpty) return finalDiagnosis;
    return 'História clínica sem título';
  }

  /// Percentual de preenchimento (para barra de progresso)
  double get completionRatio {
    final fields = [
      chiefComplaint, hpi, pastHistory, medications, allergies,
      vitalSigns, physicalExam, workingDiagnosis, treatmentPlan,
    ];
    final filled = fields.where((f) => f.trim().isNotEmpty).length;
    return filled / fields.length;
  }

  String get formattedDate {
    try {
      final dt = DateTime.parse(updatedAt);
      return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}';
    } catch (_) { return ''; }
  }
}
