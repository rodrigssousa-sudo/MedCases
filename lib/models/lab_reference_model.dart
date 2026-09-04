enum LabReferenceStatus {
  ageSpecific,
  sexSpecific,
  tannerSpecific,
  pregnancySpecific,
  methodSpecific,
  decisionLimit,
  therapeuticTarget,
  criticalValue,
  qualitative,
  referenceNotEstablished,
}

class LabValueLine {
  const LabValueLine({
    required this.labelPt,
    required this.labelEs,
    required this.value,
  });

  final String labelPt;
  final String labelEs;
  final String value;

  String label(bool isEs) => isEs ? labelEs : labelPt;
}

class LabReferenceRecord {
  const LabReferenceRecord({
    required this.testId,
    required this.canonicalNamePt,
    required this.canonicalNameEs,
    required this.categoryId,
    required this.unit,
    required this.referenceIntervals,
    required this.clinicalDecisionLimits,
    required this.criticalValues,
    required this.qualitativeValues,
    required this.clinicalNotesPt,
    required this.clinicalNotesEs,
    required this.sourceTitle,
    this.aliases = const [],
    this.specimenType = '',
    this.matrix = '',
    this.method,
    this.instrument,
    this.alternateUnits = const [],
    this.conversionFactor,
    this.sex,
    this.minimumAge,
    this.maximumAge,
    this.pubertalStage,
    this.pregnancyStatus,
    this.gestationalAge,
    this.referenceLow,
    this.referenceHigh,
    this.referenceType = 'representative',
    this.clinicalDecisionLow,
    this.clinicalDecisionHigh,
    this.criticalLow,
    this.criticalHigh,
    this.fastingRequired,
    this.collectionTime,
    this.postureRequirement,
    this.sampleHandling,
    this.hemolysisInterference,
    this.lipemiaInterference,
    this.icterusInterference,
    this.medicationInterference,
    this.interpretationLow,
    this.interpretationHigh,
    this.commonCausesLow = const [],
    this.commonCausesHigh = const [],
    this.primarySource = 'USER_PROVIDED_MASTER_BASE',
    this.sourceOrganization = '',
    this.sourceDate = '2026-08',
    this.methodSpecific = false,
    this.lastVerifiedAt = '2026-08-11',
    this.lastClinicalReview = '2026-08-11',
    this.statuses = const {},
  });

  final String testId;
  final String canonicalNamePt;
  final String canonicalNameEs;
  final List<String> aliases;
  final String categoryId;
  final String specimenType;
  final String matrix;
  final String? method;
  final String? instrument;
  final String unit;
  final List<String> alternateUnits;
  final double? conversionFactor;
  final String? sex;
  final int? minimumAge;
  final int? maximumAge;
  final String? pubertalStage;
  final String? pregnancyStatus;
  final String? gestationalAge;
  final double? referenceLow;
  final double? referenceHigh;
  final String referenceType;
  final double? clinicalDecisionLow;
  final double? clinicalDecisionHigh;
  final double? criticalLow;
  final double? criticalHigh;
  final bool? fastingRequired;
  final String? collectionTime;
  final String? postureRequirement;
  final String? sampleHandling;
  final String? hemolysisInterference;
  final String? lipemiaInterference;
  final String? icterusInterference;
  final String? medicationInterference;
  final String? interpretationLow;
  final String? interpretationHigh;
  final List<String> commonCausesLow;
  final List<String> commonCausesHigh;
  final String clinicalNotesPt;
  final String clinicalNotesEs;
  final String primarySource;
  final String sourceTitle;
  final String sourceOrganization;
  final String sourceDate;
  final bool methodSpecific;
  final String lastVerifiedAt;
  final String lastClinicalReview;
  final Set<LabReferenceStatus> statuses;
  final List<LabValueLine> referenceIntervals;
  final List<LabValueLine> clinicalDecisionLimits;
  final List<LabValueLine> criticalValues;
  final List<String> qualitativeValues;

  String name(bool isEs) => isEs ? canonicalNameEs : canonicalNamePt;
  String notes(bool isEs) => isEs ? clinicalNotesEs : clinicalNotesPt;
}

class LabReferenceCategory {
  const LabReferenceCategory({
    required this.id,
    required this.pt,
    required this.es,
  });

  final String id;
  final String pt;
  final String es;

  String label(bool isEs) => isEs ? es : pt;
}
