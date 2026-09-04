// MEDCASES PEDIATRIA — REFERENCE REGISTRY
// Clinical review date: 2026-08-10.
//
// IMPORTANT:
// "Revisão MedCases 2026" means the evidence set was re-checked in 2026.
// It does NOT rename WHO 2006/2007 standards or AHA/AAP 2025 guidelines.

class PediatricClinicalReferenceV2026 {
  final String id;
  final String organization;
  final String title;
  final String sourceVersion;
  final String citation;
  final String? doi;
  final String status;

  const PediatricClinicalReferenceV2026({
    required this.id,
    required this.organization,
    required this.title,
    required this.sourceVersion,
    required this.citation,
    required this.status,
    this.doi,
  });
}

class PediatricReferenceRegistryV2026 {
  PediatricReferenceRegistryV2026._();

  static const reviewDate = '2026-08-10';

  static const whoGrowth0to5 = PediatricClinicalReferenceV2026(
    id: 'who_growth_0_5',
    organization: 'World Health Organization (WHO)',
    title: 'WHO Child Growth Standards',
    sourceVersion: '2006 standard · verified 2026',
    citation:
        'WHO Multicentre Growth Reference Study Group. WHO Child Growth Standards.',
    status: 'CURRENT',
  );

  static const whoGrowth5to19 = PediatricClinicalReferenceV2026(
    id: 'who_growth_5_19',
    organization: 'World Health Organization (WHO)',
    title: 'WHO Growth Reference for School-aged Children and Adolescents',
    sourceVersion: '2007 reference · verified 2026',
    citation:
        'de Onis M, Onyango AW, Borghi E, Siyam A, Nishida C, Siekmann J. Development of a WHO growth reference for school-aged children and adolescents.',
    status: 'CURRENT',
  );

  static const whoAnthroData2026 = PediatricClinicalReferenceV2026(
    id: 'who_anthro_data_2026',
    organization: 'World Health Organization (WHO)',
    title: 'WHO anthro numeric LMS dataset',
    sourceVersion: 'anthro v1.1.0 · 2026-01-30',
    citation:
        'Official WHO anthro package numeric growth-standard reference tables.',
    status: 'PINNED_DATA_SNAPSHOT',
  );

  static const whoAnthroPlusData2026 = PediatricClinicalReferenceV2026(
    id: 'who_anthroplus_data_2026',
    organization: 'World Health Organization (WHO)',
    title: 'WHO anthroplus numeric LMS dataset',
    sourceVersion: 'anthroplus v1.1.0 · 2026-03-12',
    citation:
        'Official WHO anthroplus package numeric WHO Reference 2007 tables.',
    status: 'PINNED_DATA_SNAPSHOT',
  );

  static const ckidU25 = PediatricClinicalReferenceV2026(
    id: 'ckid_u25_creatinine',
    organization: 'NIDDK / CKiD',
    title: 'CKiD U25 creatinine-based eGFR equation',
    sourceVersion: 'Current NIDDK pediatric equation set · reviewed May 2025',
    citation:
        'Pierce CB, Muñoz A, Ng DK, Warady BA, Furth SL, Schwartz GJ. Kidney International. 2021;99(4):948–956.',
    doi: '10.1016/j.kint.2020.10.047',
    status: 'CURRENT_PREFERRED_PEDIATRIC_EGFR',
  );

  static const ckidBedside2009 = PediatricClinicalReferenceV2026(
    id: 'ckid_bedside_2009',
    organization: 'CKiD / NIDDK',
    title: '2009 creatinine-based CKiD bedside equation',
    sourceVersion: '2009',
    citation:
        'Schwartz GJ, Muñoz A, Schneider MF, et al. J Am Soc Nephrol. 2009;20:629–637.',
    doi: '10.1681/ASN.2008030287',
    status: 'OLDER_COMMON_QUICK_ESTIMATE',
  );

  static const pals2025 = PediatricClinicalReferenceV2026(
    id: 'aha_aap_pals_2025',
    organization: 'American Heart Association / American Academy of Pediatrics',
    title: 'Part 8: Pediatric Advanced Life Support — 2025 Guidelines',
    sourceVersion: '2025',
    citation:
        'Lasa JJ, et al. 2025 American Heart Association and American Academy of Pediatrics Guidelines for CPR and ECC: Pediatric Advanced Life Support. Circulation. 2025.',
    doi: '10.1161/CIR.0000000000001368',
    status: 'CURRENT',
  );

  static const rcukPediatricVitals2025 = PediatricClinicalReferenceV2026(
    id: 'rcuk_pediatric_vitals_2025',
    organization: 'Resuscitation Council UK',
    title: 'Paediatric Life Support — approximate normal vital signs',
    sourceVersion: '2025',
    citation:
        'Resuscitation Council UK. 2025 Resuscitation Guidelines: Paediatric Life Support. Table 1.',
    status: 'CURRENT',
  );

  static const mostellerBsa = PediatricClinicalReferenceV2026(
    id: 'mosteller_bsa',
    organization: 'New England Journal of Medicine',
    title: 'Simplified calculation of body-surface area',
    sourceVersion: '1987',
    citation: 'Mosteller RD. N Engl J Med. 1987;317(17):1098.',
    status: 'CLASSIC_FORMULA',
  );

  static const brightonPews = PediatricClinicalReferenceV2026(
    id: 'brighton_pews',
    organization: 'Royal Alexandra Children\'s Hospital, Brighton',
    title: 'Brighton Pediatric Early Warning Score (PEWS)',
    sourceVersion: 'Monaghan 2005 · source reconciled 2026',
    citation:
        'Monaghan A. Detecting and managing deterioration in children. Paediatr Nurs. 2005;17(1):32-35.',
    doi: '10.7748/paed2005.02.17.1.32.c964',
    status: 'VALIDATED_SCORE_SOURCE_RECONCILED_2026',
  );

  static const brightonPewsValidation2021 = PediatricClinicalReferenceV2026(
    id: 'brighton_pews_validation_2021',
    organization: 'Indian Journal of Child Health',
    title: 'Validation of Brighton PEWS for predicting deterioration',
    sourceVersion: '2021 · reviewed 2026',
    citation:
        'Duraisamy R, Vanaja J, Samy KPA, Balasubramaniam B, Palanisamy S. Indian J Child Health. 2021;8(6):211-215.',
    doi: '10.32677/IJCH.2021.v08.i06.003',
    status: 'VALIDATION_STUDY',
  );
}
