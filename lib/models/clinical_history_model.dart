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

  // ── Moderação (admin/supervisor) ─────────────────────────────────────────
  final bool isHidden;              // Oculto por moderador (reversível)
  final String? hiddenBy;           // UID do moderador que ocultou
  final String? hiddenAt;           // ISO8601 quando foi ocultado

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
    this.isHidden = false,
    this.hiddenBy,
    this.hiddenAt,
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
    bool? isHidden, String? hiddenBy, String? hiddenAt,
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
      isHidden: isHidden ?? this.isHidden,
      hiddenBy: hiddenBy ?? this.hiddenBy,
      hiddenAt: hiddenAt ?? this.hiddenAt,
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
    'isHidden': isHidden,
    'hiddenBy': hiddenBy,
    'hiddenAt': hiddenAt,
  };

  /// Parse seguro de List<dynamic> → List<String>, sem lançar em release.
  /// NUNCA usa `as` para cast — dart2js release mode lança TypeError para
  /// qualquer tipo inesperado (Timestamp, Map, etc.).
  static List<String> _safeStringList(dynamic raw) {
    if (raw == null) return const [];
    // SEGURO: verifica is List antes de iterar (evita `as List` que falha em release)
    if (raw is! List) return const [];
    return raw.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
  }

  /// Parse seguro de List<dynamic> → List<EvolutionEntry>.
  /// Cada item é envolto em try/catch individual para não quebrar a lista inteira.
  /// NUNCA usa `as` para cast — dart2js release mode lança TypeError.
  static List<EvolutionEntry> _safeEvolutionList(dynamic raw) {
    if (raw == null) return const [];
    // SEGURO: verifica is List antes de iterar (evita `as List` que falha em release)
    if (raw is! List) return const [];
    final result = <EvolutionEntry>[];
    for (final e in raw) {
      try {
        if (e == null) continue;
        // CRÍTICO: nunca usar Map<String,dynamic>.from() em dart2js release —
        // quando e é JavaScriptObject o .from() pode lançar TypeError.
        // Em vez disso, itera entry-by-entry manualmente.
        final Map<String, dynamic> safe;
        if (e is Map<String, dynamic>) {
          safe = e;
        } else if (e is Map) {
          // Converte sem .from() — entrada por entrada com try/catch
          final tmp = <String, dynamic>{};
          e.forEach((k, v) {
            try { tmp[k.toString()] = v; } catch (_) {}
          });
          safe = tmp;
        } else {
          continue; // tipos primitivos (Timestamp, String, etc.) — ignora
        }
        result.add(EvolutionEntry.fromJson(safe));
      } catch (_) {
        // item malformado — ignora, não quebra os demais
      }
    }
    return result;
  }

  factory ClinicalHistoryModel.fromJson(Map<String, dynamic> j) {
    return ClinicalHistoryModel(
      id: j['id']?.toString() ?? '',
      createdAt: j['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
      updatedAt: j['updatedAt']?.toString() ?? DateTime.now().toIso8601String(),
      authorUid: j['authorUid']?.toString() ?? '',
      authorName: j['authorName']?.toString() ?? '',
      authorEmail: j['authorEmail']?.toString() ?? '',
      uploadedAt: j['uploadedAt']?.toString() ?? '',
      // isPublic pode chegar como bool (SDK) ou bool (REST booleanValue já decodificado)
      isPublic: j['isPublic'] == true || j['isPublic'].toString() == 'true',
      patientInitials: j['patientInitials']?.toString() ?? '',
      patientAge: j['patientAge']?.toString() ?? '',
      patientSex: j['patientSex']?.toString() ?? 'Masculino',
      patientWeight: j['patientWeight']?.toString() ?? '',
      patientHeight: j['patientHeight']?.toString() ?? '',
      patientRecord: j['patientRecord']?.toString() ?? '',
      chiefComplaint: j['chiefComplaint']?.toString() ?? '',
      hpi: j['hpi']?.toString() ?? '',
      pastHistory: j['pastHistory']?.toString() ?? '',
      familyHistory: j['familyHistory']?.toString() ?? '',
      socialHistory: j['socialHistory']?.toString() ?? '',
      medications: j['medications']?.toString() ?? '',
      allergies: j['allergies']?.toString() ?? '',
      reviewOfSystems: j['reviewOfSystems']?.toString() ?? '',
      vitalSigns: j['vitalSigns']?.toString() ?? '',
      physicalExam: j['physicalExam']?.toString() ?? '',
      workingDiagnosis: j['workingDiagnosis']?.toString() ?? '',
      differentialDx: j['differentialDx']?.toString() ?? '',
      finalDiagnosis: j['finalDiagnosis']?.toString() ?? '',
      cid: j['cid']?.toString() ?? '',
      labResults: j['labResults']?.toString() ?? '',
      imagingResults: j['imagingResults']?.toString() ?? '',
      otherResults: j['otherResults']?.toString() ?? '',
      treatmentPlan: j['treatmentPlan']?.toString() ?? '',
      procedures: j['procedures']?.toString() ?? '',
      // CRÍTICO: .cast<String>() quebra em release se algum elemento não for String.
      // _safeStringList usa .toString() em cada elemento — nunca lança TypeError.
      drugIds: _safeStringList(j['drugIds']),
      evolutions: _safeEvolutionList(j['evolutions']),
      outcome: j['outcome']?.toString() ?? 'internado',
      dischargeCondition: j['dischargeCondition']?.toString() ?? '',
      followUp: j['followUp']?.toString() ?? '',
      category: j['category']?.toString() ?? 'Clínica Geral',
      tags: j['tags']?.toString() ?? '',
      isHidden: j['isHidden'] == true || j['isHidden'].toString() == 'true',
      hiddenBy: j['hiddenBy']?.toString(),
      hiddenAt: j['hiddenAt']?.toString(),
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
