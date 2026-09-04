// MEDCASES — VACCINE CLINICAL CATALOG 2026
// Versioned clinical dataset. Clinical review: 2026-08-10.
// ES -> Argentina | PT -> Brasil.
// Reference data only: no patient-specific auto-recommendation.

enum VaccineJurisdiction { argentina, brazil }

enum VaccineProgramStatus {
  routineAge,
  seasonal,
  pregnancy,
  riskGroup,
  focalizedStrategy,
  travelExposure,
  postExposure,
  nonUniversal,
  temporaryHold,
}

class VaccineDoseRef {
  const VaccineDoseRef({required this.vaccineId, required this.schedule});
  final String vaccineId;
  final String schedule;
}

class VaccineAgeGroup {
  const VaccineAgeGroup(
      {required this.id,
      required this.label,
      required this.entries,
      this.note});
  final String id;
  final String label;
  final List<VaccineDoseRef> entries;
  final String? note;
}

class VaccineClinicalRecord {
  const VaccineClinicalRecord({
    required this.id,
    required this.title,
    required this.status,
    required this.statusLabel,
    required this.schedule,
    required this.prevents,
    required this.platform,
    required this.liveVaccine,
    required this.administration,
    required this.keyPoints,
    required this.contraindications,
    required this.commonEffects,
    required this.alertSigns,
    required this.reference,
    required this.lastVerifiedAt,
    this.aliases = const <String>[],
    this.safetyReference,
    this.requiresClinicalAssessment = false,
    this.requiresLiveStatusCheck = false,
  });
  final String id,
      title,
      statusLabel,
      schedule,
      prevents,
      platform,
      administration,
      reference,
      lastVerifiedAt;
  final List<String> aliases,
      keyPoints,
      contraindications,
      commonEffects,
      alertSigns;
  final VaccineProgramStatus status;
  final bool liveVaccine, requiresClinicalAssessment, requiresLiveStatusCheck;
  final String? safetyReference;
}

class VaccineCatalog {
  const VaccineCatalog({
    required this.jurisdiction,
    required this.countryLabel,
    required this.programLabel,
    required this.versionLabel,
    required this.lastVerifiedAt,
    required this.primaryReference,
    required this.routineGroups,
    required this.seasonalIds,
    required this.pregnancyIds,
    required this.specialIds,
    required this.records,
  });
  final VaccineJurisdiction jurisdiction;
  final String countryLabel,
      programLabel,
      versionLabel,
      lastVerifiedAt,
      primaryReference;
  final List<VaccineAgeGroup> routineGroups;
  final List<String> seasonalIds, pregnancyIds, specialIds;
  final List<VaccineClinicalRecord> records;
  VaccineClinicalRecord? recordById(String id) {
    for (final record in records) {
      if (record.id == id) return record;
    }
    return null;
  }
}

const String vaccineClinicalVersion = '2026-08-10';

VaccineCatalog vaccineCatalogForLanguage(String lang) {
  return lang == 'es' ? argentinaVaccineCatalog2026 : brazilVaccineCatalog2026;
}

const argentinaVaccineCatalog2026 = VaccineCatalog(
  jurisdiction: VaccineJurisdiction.argentina,
  countryLabel: 'ARGENTINA',
  programLabel: 'Calendario Nacional de Vacunación',
  versionLabel: '2026',
  lastVerifiedAt: vaccineClinicalVersion,
  primaryReference:
      'Calendario Nacional de Vacunación 2026 / Ministerio de Salud de la Nación / Argentina',
  routineGroups: <VaccineAgeGroup>[
    VaccineAgeGroup(
      id: 'ar_birth',
      label: 'Nacimiento / 0 mes',
      entries: <VaccineDoseRef>[
        VaccineDoseRef(
            vaccineId: 'ar_bcg', schedule: 'Dosis única antes del alta'),
        VaccineDoseRef(
            vaccineId: 'ar_hepb',
            schedule: 'Dosis neonatal dentro de las primeras 12 h'),
      ],
    ),
    VaccineAgeGroup(
      id: 'ar_2m',
      label: '2 meses',
      entries: <VaccineDoseRef>[
        VaccineDoseRef(vaccineId: 'ar_pcv20', schedule: '1.ª dosis'),
        VaccineDoseRef(vaccineId: 'ar_ipv', schedule: '1.ª dosis'),
        VaccineDoseRef(vaccineId: 'ar_penta', schedule: '1.ª dosis'),
        VaccineDoseRef(vaccineId: 'ar_rotavirus', schedule: '1.ª dosis'),
      ],
    ),
    VaccineAgeGroup(
      id: 'ar_3m',
      label: '3 meses',
      entries: <VaccineDoseRef>[
        VaccineDoseRef(vaccineId: 'ar_menacwy', schedule: '1.ª dosis'),
      ],
    ),
    VaccineAgeGroup(
      id: 'ar_4m',
      label: '4 meses',
      entries: <VaccineDoseRef>[
        VaccineDoseRef(vaccineId: 'ar_pcv20', schedule: '2.ª dosis'),
        VaccineDoseRef(vaccineId: 'ar_ipv', schedule: '2.ª dosis'),
        VaccineDoseRef(vaccineId: 'ar_penta', schedule: '2.ª dosis'),
        VaccineDoseRef(vaccineId: 'ar_rotavirus', schedule: '2.ª dosis'),
      ],
    ),
    VaccineAgeGroup(
      id: 'ar_5m',
      label: '5 meses',
      entries: <VaccineDoseRef>[
        VaccineDoseRef(vaccineId: 'ar_menacwy', schedule: '2.ª dosis'),
      ],
    ),
    VaccineAgeGroup(
      id: 'ar_6m',
      label: '6 meses',
      entries: <VaccineDoseRef>[
        VaccineDoseRef(vaccineId: 'ar_penta', schedule: '3.ª dosis'),
        VaccineDoseRef(vaccineId: 'ar_ipv', schedule: '3.ª dosis'),
        VaccineDoseRef(
            vaccineId: 'ar_influenza',
            schedule: 'Inicio estacional entre 6 y 24 meses'),
      ],
      note: 'La antigripal también aparece en Vacunas estacionales.',
    ),
    VaccineAgeGroup(
      id: 'ar_12m',
      label: '12 meses (1 año)',
      entries: <VaccineDoseRef>[
        VaccineDoseRef(vaccineId: 'ar_pcv20', schedule: 'Refuerzo'),
        VaccineDoseRef(vaccineId: 'ar_hepa', schedule: 'Dosis única'),
        VaccineDoseRef(vaccineId: 'ar_mmr', schedule: '1.ª dosis'),
      ],
    ),
    VaccineAgeGroup(
      id: 'ar_15m',
      label: '15 meses',
      entries: <VaccineDoseRef>[
        VaccineDoseRef(vaccineId: 'ar_varicella', schedule: '1.ª dosis'),
        VaccineDoseRef(vaccineId: 'ar_menacwy', schedule: 'Refuerzo'),
        VaccineDoseRef(
            vaccineId: 'ar_penta', schedule: 'Refuerzo entre 15–18 meses'),
        VaccineDoseRef(
            vaccineId: 'ar_mmr',
            schedule: '2.ª dosis 15–18 meses para nacidos desde 01/07/2024'),
      ],
      note:
          'Cohorte 01/01/2021–30/06/2024: 2.ª SRP en el año que cumplen 5 años.',
    ),
    VaccineAgeGroup(
      id: 'ar_18m',
      label: '18 meses',
      entries: <VaccineDoseRef>[
        VaccineDoseRef(
            vaccineId: 'ar_yf', schedule: 'Áreas de riesgo epidemiológico'),
      ],
    ),
    VaccineAgeGroup(
      id: 'ar_5y',
      label: '5 años (Ingreso Escolar)',
      entries: <VaccineDoseRef>[
        VaccineDoseRef(vaccineId: 'ar_ipv', schedule: 'Refuerzo'),
        VaccineDoseRef(vaccineId: 'ar_dtp', schedule: 'Refuerzo'),
        VaccineDoseRef(vaccineId: 'ar_varicella', schedule: '2.ª dosis'),
        VaccineDoseRef(
            vaccineId: 'ar_mmr',
            schedule:
                '2.ª dosis para cohorte de transición cuando corresponde'),
      ],
    ),
    VaccineAgeGroup(
      id: 'ar_11y',
      label: '11 años',
      entries: <VaccineDoseRef>[
        VaccineDoseRef(vaccineId: 'ar_hpv', schedule: 'Dosis única'),
        VaccineDoseRef(vaccineId: 'ar_menacwy', schedule: 'Dosis única'),
        VaccineDoseRef(vaccineId: 'ar_tdap', schedule: 'Dosis única'),
        VaccineDoseRef(
            vaccineId: 'ar_yf',
            schedule: 'Refuerzo si vive en zona de riesgo y corresponde'),
      ],
    ),
    VaccineAgeGroup(
      id: 'ar_adult',
      label: 'Adultos (15 a 64 años)',
      entries: <VaccineDoseRef>[
        VaccineDoseRef(
            vaccineId: 'ar_hepb', schedule: 'Completar según antecedentes'),
        VaccineDoseRef(
            vaccineId: 'ar_td', schedule: 'Completar y mantener refuerzos'),
        VaccineDoseRef(
            vaccineId: 'ar_mmr', schedule: 'Recupero según antecedentes'),
        VaccineDoseRef(
            vaccineId: 'ar_influenza', schedule: 'Anual en factores de riesgo'),
        VaccineDoseRef(
            vaccineId: 'ar_candid1', schedule: 'Áreas endémicas desde 15 años'),
      ],
    ),
    VaccineAgeGroup(
      id: 'ar_65',
      label: 'Mayores de 65 años',
      entries: <VaccineDoseRef>[
        VaccineDoseRef(vaccineId: 'ar_influenza', schedule: 'Anual'),
        VaccineDoseRef(
            vaccineId: 'ar_pcv20', schedule: 'Según antecedente neumocócico'),
        VaccineDoseRef(vaccineId: 'ar_td', schedule: 'Mantener refuerzos'),
      ],
    ),
  ],
  seasonalIds: <String>['ar_influenza', 'ar_covid'],
  pregnancyIds: <String>['ar_influenza', 'ar_tdap', 'ar_rsv', 'ar_covid'],
  specialIds: <String>[
    'ar_yf',
    'ar_candid1',
    'ar_qdenga',
    'ar_rabies',
    'ar_pneumo_risk',
    'ar_menb',
    'ar_zoster',
    'ar_travel'
  ],
  records: <VaccineClinicalRecord>[
    VaccineClinicalRecord(
      id: 'ar_bcg',
      title: 'BCG',
      status: VaccineProgramStatus.routineAge,
      statusLabel: 'Calendario rutinario',
      schedule: 'Dosis única al nacer, antes del alta.',
      prevents: 'Formas graves de tuberculosis infantil.',
      platform: 'BCG vivo atenuado',
      liveVaccine: true,
      administration: 'Intradérmica; técnica/producto vigentes.',
      keyPoints: <String>[
        'La ausencia de cicatriz aislada no indica revacunación automática.'
      ],
      contraindications: <String>[
        'Inmunodeficiencia celular significativa o inmunosupresión grave.'
      ],
      commonEffects: <String>[
        'Pápula, nódulo, pequeña ulceración y cicatriz local.'
      ],
      alertSigns: <String>[
        'Lesión extensa, supuración persistente o cuadro sistémico.'
      ],
      reference:
          'Calendario Nacional de Vacunación 2026 / Ministerio de Salud de la Nación / Argentina',
      safetyReference: 'BCG Vaccine Safety / WHO',
      lastVerifiedAt: vaccineClinicalVersion,
    ),
    VaccineClinicalRecord(
      id: 'ar_hepb',
      title: 'Hepatitis B',
      status: VaccineProgramStatus.routineAge,
      statusLabel: 'Calendario rutinario',
      schedule:
          'Dosis neonatal dentro de las primeras 12 h; completar según antecedentes.',
      prevents: 'Hepatitis B aguda/crónica y complicaciones.',
      platform: 'HBsAg recombinante',
      liveVaccine: false,
      administration: 'Intramuscular.',
      keyPoints: <String>[
        'No reiniciar dosis válidas por atraso.',
        'Exposición perinatal requiere protocolo neonatal específico.'
      ],
      contraindications: <String>['Anafilaxia a dosis/componente.'],
      commonEffects: <String>['Dolor local, febrícula, cefalea o malestar.'],
      alertSigns: <String>['Reacción alérgica sistémica.'],
      reference:
          'Calendario Nacional de Vacunación 2026 / Ministerio de Salud de la Nación / Argentina',
      safetyReference: 'Hepatitis B Vaccine VIS / CDC',
      lastVerifiedAt: vaccineClinicalVersion,
    ),
    VaccineClinicalRecord(
      id: 'ar_pcv20',
      title: 'Neumocócica conjugada VCN20',
      status: VaccineProgramStatus.routineAge,
      statusLabel: 'Calendario rutinario',
      schedule: '2 y 4 meses + refuerzo a los 12 meses.',
      prevents: 'Enfermedad neumocócica invasiva y parte de neumonías/otitis.',
      platform: 'Polisacáridos conjugados',
      liveVaccine: false,
      administration: 'Intramuscular.',
      keyPoints: <String>[
        'VCN20 reemplaza progresivamente VCN13.',
        'En ≥65 y riesgo revisar antecedentes neumocócicos.'
      ],
      contraindications: <String>['Anafilaxia a dosis/componente.'],
      commonEffects: <String>['Dolor local, fiebre, irritabilidad o mialgias.'],
      alertSigns: <String>['Reacción alérgica grave.'],
      reference:
          'Calendario Nacional de Vacunación 2026 / Ministerio de Salud de la Nación / Argentina',
      safetyReference: 'Pneumococcal Conjugate Vaccine VIS / CDC',
      lastVerifiedAt: vaccineClinicalVersion,
    ),
    VaccineClinicalRecord(
      id: 'ar_ipv',
      title: 'IPV / Salk',
      status: VaccineProgramStatus.routineAge,
      statusLabel: 'Calendario rutinario',
      schedule: '2, 4 y 6 meses + refuerzo a los 5 años.',
      prevents: 'Poliomielitis paralítica.',
      platform: 'Poliovirus inactivados',
      liveVaccine: false,
      administration: 'Intramuscular.',
      keyPoints: <String>['No produce poliomielitis asociada a vacuna.'],
      contraindications: <String>['Anafilaxia a dosis/componente.'],
      commonEffects: <String>['Dolor o eritema local.'],
      alertSigns: <String>['Reacción alérgica grave.'],
      reference:
          'Calendario Nacional de Vacunación 2026 / Ministerio de Salud de la Nación / Argentina',
      safetyReference: 'Polio Vaccine VIS / CDC',
      lastVerifiedAt: vaccineClinicalVersion,
    ),
    VaccineClinicalRecord(
      id: 'ar_penta',
      title: 'Quíntuple / Pentavalente',
      status: VaccineProgramStatus.routineAge,
      statusLabel: 'Calendario rutinario',
      schedule: '2, 4 y 6 meses + refuerzo entre 15–18 meses.',
      prevents: 'Difteria, tétanos, coqueluche, hepatitis B y Hib.',
      platform: 'DTP-HB-Hib; no viva',
      liveVaccine: false,
      administration: 'Intramuscular.',
      keyPoints: <String>[
        'Eventos importantes tras pertussis requieren evaluación.'
      ],
      contraindications: <String>[
        'Anafilaxia; encefalopatía vinculada a pertussis sin otra causa requiere evaluación.'
      ],
      commonEffects: <String>['Dolor, fiebre, irritabilidad, somnolencia.'],
      alertSigns: <String>[
        'Convulsión, episodio hipotónico-hiporresponsivo o anafilaxia.'
      ],
      reference:
          'Calendario Nacional de Vacunación 2026 / Ministerio de Salud de la Nación / Argentina',
      lastVerifiedAt: vaccineClinicalVersion,
    ),
    VaccineClinicalRecord(
      id: 'ar_rotavirus',
      title: 'Rotavirus',
      status: VaccineProgramStatus.routineAge,
      statusLabel: 'Ventana etaria rígida',
      schedule:
          'D1 a los 2 meses, D2 a los 4; D1 hasta 14 sem + 6 días, D2 hasta 24 sem.',
      prevents: 'Gastroenteritis grave por rotavirus.',
      platform: 'Virus vivo atenuado',
      liveVaccine: true,
      administration: 'Oral.',
      keyPoints: <String>[
        'La ventana argentina no debe extrapolarse desde Brasil.'
      ],
      contraindications: <String>[
        'Invaginación intestinal previa, SCID, edad fuera de ventana.'
      ],
      commonEffects: <String>['Irritabilidad, diarrea leve o vómitos.'],
      alertSigns: <String>[
        'Dolor abdominal intenso, vómitos repetidos, sangre en heces o postración.'
      ],
      reference:
          'Calendario Nacional de Vacunación 2026 / Ministerio de Salud de la Nación / Argentina',
      safetyReference: 'Rotavirus Vaccine VIS / CDC',
      lastVerifiedAt: vaccineClinicalVersion,
    ),
    VaccineClinicalRecord(
      id: 'ar_menacwy',
      title: 'Meningocócica ACWY',
      status: VaccineProgramStatus.routineAge,
      statusLabel: 'Calendario rutinario',
      schedule: '3 y 5 meses + refuerzo a los 15 meses + dosis a los 11 años.',
      prevents: 'Enfermedad meningocócica invasiva A,C,W,Y.',
      platform: 'Conjugada; no viva',
      liveVaccine: false,
      administration: 'Intramuscular.',
      keyPoints: <String>['Argentina usa MenACWY en el esquema infantil.'],
      contraindications: <String>['Anafilaxia a dosis/componente.'],
      commonEffects: <String>['Dolor local, fiebre, cefalea o fatiga.'],
      alertSigns: <String>['Reacción alérgica grave.'],
      reference:
          'Recomendaciones MenACWY 2026 / Ministerio de Salud / Argentina',
      safetyReference: 'Meningococcal ACWY Vaccine VIS / CDC',
      lastVerifiedAt: vaccineClinicalVersion,
    ),
    VaccineClinicalRecord(
      id: 'ar_hepa',
      title: 'Hepatitis A',
      status: VaccineProgramStatus.routineAge,
      statusLabel: 'Calendario rutinario',
      schedule: 'Dosis única a los 12 meses.',
      prevents: 'Hepatitis A y complicaciones.',
      platform: 'Virus inactivado',
      liveVaccine: false,
      administration: 'Intramuscular.',
      keyPoints: <String>['La edad de rutina difiere de Brasil.'],
      contraindications: <String>['Anafilaxia a dosis/componente.'],
      commonEffects: <String>['Dolor local, fiebre, cefalea o fatiga.'],
      alertSigns: <String>['Reacción alérgica grave.'],
      reference:
          'Calendario Nacional de Vacunación 2026 / Ministerio de Salud de la Nación / Argentina',
      safetyReference: 'Hepatitis A Vaccine VIS / CDC',
      lastVerifiedAt: vaccineClinicalVersion,
    ),
    VaccineClinicalRecord(
      id: 'ar_mmr',
      title: 'Triple viral SRP',
      status: VaccineProgramStatus.routineAge,
      statusLabel: 'Regla por cohorte',
      schedule:
          'D1 a los 12 meses. D2 entre 15–18 meses para nacidos desde 01/07/2024; cohortes 01/01/2021–30/06/2024 completan a los 5 años.',
      prevents: 'Sarampión, rubéola y paperas.',
      platform: 'Virus vivos atenuados',
      liveVaccine: true,
      administration: 'Según producto/lineamiento.',
      keyPoints: <String>['La fecha de nacimiento modifica la 2.ª dosis.'],
      contraindications: <String>[
        'Embarazo, inmunosupresión grave, anafilaxia relevante.'
      ],
      commonEffects: <String>[
        'Fiebre, exantema leve, adenopatía o artralgias.'
      ],
      alertSigns: <String>['Convulsión prolongada o reacción alérgica grave.'],
      reference:
          'Calendario Nacional de Vacunación 2026 / Ministerio de Salud de la Nación / Argentina',
      safetyReference: 'MMR Vaccine VIS / CDC',
      lastVerifiedAt: vaccineClinicalVersion,
    ),
    VaccineClinicalRecord(
      id: 'ar_varicella',
      title: 'Varicela',
      status: VaccineProgramStatus.routineAge,
      statusLabel: 'Calendario rutinario',
      schedule: '1.ª dosis a los 15 meses + 2.ª a los 5 años.',
      prevents: 'Varicela y complicaciones.',
      platform: 'Virus vivo atenuado',
      liveVaccine: true,
      administration: 'Según producto.',
      keyPoints: <String>[
        'Antivirales antiherpes pueden interferir con la vacuna.'
      ],
      contraindications: <String>['Embarazo e inmunosupresión grave.'],
      commonEffects: <String>['Dolor local, fiebre o exantema leve.'],
      alertSigns: <String>['Cuadro sistémico o neurológico importante.'],
      reference:
          'Calendario Nacional de Vacunación 2026 / Ministerio de Salud de la Nación / Argentina',
      safetyReference: 'Varicella Vaccine VIS / CDC',
      lastVerifiedAt: vaccineClinicalVersion,
    ),
    VaccineClinicalRecord(
      id: 'ar_dtp',
      title: 'Triple bacteriana celular',
      status: VaccineProgramStatus.routineAge,
      statusLabel: 'Refuerzo',
      schedule: 'Refuerzo a los 5 años.',
      prevents: 'Difteria, tétanos y coqueluche.',
      platform: 'Toxoides + pertussis celular inactivada',
      liveVaccine: false,
      administration: 'Intramuscular.',
      keyPoints: <String>[
        'Eventos neurológicos o hipotónicos requieren evaluación antes de futuras dosis con pertussis.'
      ],
      contraindications: <String>[
        'Anafilaxia; encefalopatía relacionada a pertussis sin otra causa.'
      ],
      commonEffects: <String>['Dolor, edema, fiebre o irritabilidad.'],
      alertSigns: <String>[
        'Convulsión prolongada o alteración importante de conciencia.'
      ],
      reference:
          'Calendario Nacional de Vacunación 2026 / Ministerio de Salud de la Nación / Argentina',
      lastVerifiedAt: vaccineClinicalVersion,
    ),
    VaccineClinicalRecord(
      id: 'ar_hpv',
      title: 'VPH / HPV',
      status: VaccineProgramStatus.routineAge,
      statusLabel: 'Calendario rutinario',
      schedule: 'Dosis única a los 11 años; recupero según edad/condición.',
      prevents: 'Infección persistente por HPV y cánceres relacionados.',
      platform: 'VLP recombinantes; no viva',
      liveVaccine: false,
      administration: 'Intramuscular.',
      keyPoints: <String>['Inmunocomprometidos pueden requerir más dosis.'],
      contraindications: <String>['Anafilaxia a dosis/componente.'],
      commonEffects: <String>[
        'Dolor local, cefalea, fiebre o síncope vasovagal.'
      ],
      alertSigns: <String>['Reacción alérgica grave.'],
      reference:
          'Calendario Nacional de Vacunación 2026 / Ministerio de Salud de la Nación / Argentina',
      safetyReference: 'HPV Vaccine VIS / CDC',
      lastVerifiedAt: vaccineClinicalVersion,
    ),
    VaccineClinicalRecord(
      id: 'ar_tdap',
      title: 'dTpa',
      status: VaccineProgramStatus.pregnancy,
      statusLabel: 'Rutina + embarazo',
      schedule: 'A los 11 años. En cada embarazo desde la semana 20.',
      prevents: 'Difteria, tétanos y coqueluche.',
      platform: 'Toxoides + pertussis acelular',
      liveVaccine: false,
      administration: 'Intramuscular.',
      keyPoints: <String>['En embarazo se indica en cada gestación.'],
      contraindications: <String>[
        'Anafilaxia; antecedentes neurológicos graves requieren evaluación.'
      ],
      commonEffects: <String>['Dolor local, cefalea, cansancio o febrícula.'],
      alertSigns: <String>['Reacción alérgica grave.'],
      reference:
          'Calendario Nacional de Vacunación 2026 / Ministerio de Salud de la Nación / Argentina',
      safetyReference: 'Tdap Vaccine VIS / CDC',
      lastVerifiedAt: vaccineClinicalVersion,
    ),
    VaccineClinicalRecord(
      id: 'ar_td',
      title: 'Doble bacteriana (dT)',
      status: VaccineProgramStatus.routineAge,
      statusLabel: 'Adultos',
      schedule: 'Completar serie cuando corresponda + refuerzo cada 10 años.',
      prevents: 'Difteria y tétanos.',
      platform: 'Toxoides',
      liveVaccine: false,
      administration: 'Intramuscular.',
      keyPoints: <String>['No reiniciar serie válida por atraso.'],
      contraindications: <String>['Anafilaxia a dosis/componente.'],
      commonEffects: <String>['Dolor, edema, cefalea o febrícula.'],
      alertSigns: <String>['Reacción alérgica grave.'],
      reference:
          'Calendario Nacional de Vacunación 2026 / Ministerio de Salud de la Nación / Argentina',
      safetyReference: 'Td Vaccine VIS / CDC',
      lastVerifiedAt: vaccineClinicalVersion,
    ),
    VaccineClinicalRecord(
      id: 'ar_influenza',
      title: 'Antigripal / Influenza',
      status: VaccineProgramStatus.seasonal,
      statusLabel: 'Estacional / anual',
      schedule:
          '6–24 meses; ≥65; embarazo; personal de salud y grupos de riesgo. Esquema infantil inicial puede requerir 2 dosis separadas ≥4 semanas.',
      prevents: 'Influenza y complicaciones graves.',
      platform: 'Inactivada estacional',
      liveVaccine: false,
      administration: 'Intramuscular.',
      keyPoints: <String>[
        'La vacuna inyectable no produce gripe.',
        'La indicación se renueva por temporada.'
      ],
      contraindications: <String>[
        'Anafilaxia; situaciones especiales requieren evaluación.'
      ],
      commonEffects: <String>[
        'Dolor local, fiebre, cefalea, mialgia o fatiga.'
      ],
      alertSigns: <String>[
        'Debilidad neurológica progresiva o reacción alérgica grave.'
      ],
      reference: 'Vacuna antigripal 2026 / Ministerio de Salud / Argentina',
      safetyReference: 'Inactivated Influenza Vaccine VIS / CDC',
      lastVerifiedAt: vaccineClinicalVersion,
    ),
    VaccineClinicalRecord(
      id: 'ar_rsv',
      title: 'VSR materna',
      status: VaccineProgramStatus.pregnancy,
      statusLabel: 'Embarazo',
      schedule:
          'Una dosis por embarazo entre 32 semanas y 36+6, durante estrategia estacional.',
      prevents: 'En el lactante: enfermedad respiratoria baja grave por VSR.',
      platform: 'Proteína F prefusión recombinante',
      liveVaccine: false,
      administration: 'Intramuscular.',
      keyPoints: <String>[
        'La ventana argentina no es igual a la brasileña.',
        'Nirsevimab no es vacuna.'
      ],
      contraindications: <String>['Anafilaxia a dosis/componente.'],
      commonEffects: <String>['Dolor local, fatiga, cefalea o mialgias.'],
      alertSigns: <String>[
        'Reacción alérgica grave o evento obstétrico agudo.'
      ],
      reference:
          'Vacunación VSR en personas gestantes / Ministerio de Salud / Argentina',
      safetyReference: 'RSV Vaccine VIS / CDC',
      lastVerifiedAt: vaccineClinicalVersion,
    ),
    VaccineClinicalRecord(
      id: 'ar_covid',
      title: 'COVID-19',
      status: VaccineProgramStatus.seasonal,
      statusLabel: 'Recomendación vigente',
      schedule:
          'Periodicidad depende de edad, riesgo, inmunocompromiso, embarazo, producto y recomendación nacional vigente.',
      prevents: 'Principalmente formas graves, hospitalización y muerte.',
      platform: 'Producto/plataforma versionados',
      liveVaccine: false,
      administration: 'Intramuscular; volumen por producto.',
      keyPoints: <String>[
        'Versionar por producto y fecha.',
        'Embarazo: seguir recomendación vigente.'
      ],
      contraindications: <String>['Anafilaxia a dosis/componente.'],
      commonEffects: <String>[
        'Dolor local, fatiga, cefalea, mialgia o fiebre.'
      ],
      alertSigns: <String>[
        'Dolor torácico persistente, disnea o palpitaciones.'
      ],
      reference: 'Estrategia COVID-19 / Ministerio de Salud / Argentina',
      safetyReference: 'COVID-19 Vaccine VIS / CDC',
      lastVerifiedAt: vaccineClinicalVersion,
      requiresLiveStatusCheck: true,
    ),
    VaccineClinicalRecord(
      id: 'ar_yf',
      title: 'Fiebre amarilla',
      status: VaccineProgramStatus.riskGroup,
      statusLabel: 'Zona de riesgo / viaje',
      schedule: 'Según residencia en áreas de riesgo, antecedentes y viaje.',
      prevents: 'Fiebre amarilla y formas graves.',
      platform: 'Virus vivo atenuado 17D',
      liveVaccine: true,
      administration: 'Según producto.',
      keyPoints: <String>['No es universal para toda Argentina.'],
      contraindications: <String>[
        'Inmunosupresión grave; embarazo/otras situaciones requieren riesgo-beneficio.'
      ],
      commonEffects: <String>['Dolor local, fiebre, cefalea o mialgia.'],
      alertSigns: <String>[
        'Fiebre alta persistente, ictericia o síntomas neurológicos.'
      ],
      reference:
          'Vacuna contra la fiebre amarilla / Ministerio de Salud / Argentina',
      safetyReference: 'Yellow Fever Vaccine VIS / CDC',
      lastVerifiedAt: vaccineClinicalVersion,
      requiresClinicalAssessment: true,
    ),
    VaccineClinicalRecord(
      id: 'ar_candid1',
      title: 'Candid #1 — Fiebre Hemorrágica Argentina',
      status: VaccineProgramStatus.riskGroup,
      statusLabel: 'Área endémica',
      schedule:
          'Dosis única desde 15 años para personas con residencia/trabajo/exposición en áreas endémicas.',
      prevents: 'Fiebre Hemorrágica Argentina por virus Junín.',
      platform: 'Virus vivo atenuado Candid #1',
      liveVaccine: true,
      administration: 'Según lineamiento.',
      keyPoints: <String>['La elegibilidad depende de territorio/exposición.'],
      contraindications: <String>[
        'Embarazo, lactancia, inmunodeficiencia/inmunosupresión.'
      ],
      commonEffects: <String>[
        'Cefalea, malestar, mialgia, fiebre o reacción local.'
      ],
      alertSigns: <String>['Cuadro sistémico importante.'],
      reference: 'Vacuna Candid #1 / Ministerio de Salud / Argentina',
      lastVerifiedAt: vaccineClinicalVersion,
      requiresClinicalAssessment: true,
    ),
    VaccineClinicalRecord(
      id: 'ar_qdenga',
      title: 'Dengue — Qdenga / TAK-003',
      status: VaccineProgramStatus.focalizedStrategy,
      statusLabel: 'Estrategia focalizada',
      schedule:
          '2 dosis: 0 y 3 meses. Estrategia pública focalizada 15–39 años en departamentos priorizados.',
      prevents: 'Dengue por los cuatro serotipos.',
      platform: 'Tetravalente viva atenuada',
      liveVaccine: true,
      administration: '0,5 mL subcutánea para el producto descrito.',
      keyPoints: <String>[
        'No es universal.',
        'Depende de territorio y situación epidemiológica.'
      ],
      contraindications: <String>[
        'Embarazo, lactancia, inmunocompromiso importante.'
      ],
      commonEffects: <String>[
        'Dolor local, cefalea, mialgia, malestar o fiebre.'
      ],
      alertSigns: <String>['Reacción alérgica o cuadro sistémico grave.'],
      reference:
          'Lineamientos Técnicos Dengue / Ministerio de Salud / Argentina',
      lastVerifiedAt: vaccineClinicalVersion,
      requiresClinicalAssessment: true,
      requiresLiveStatusCheck: true,
    ),
    VaccineClinicalRecord(
      id: 'ar_rabies',
      title: 'Vacuna antirrábica humana',
      status: VaccineProgramStatus.postExposure,
      statusLabel: 'Exposición / protocolo',
      schedule:
          'No definir por edad: depende de exposición, animal, herida, antecedentes y epidemiología.',
      prevents: 'Rabia humana.',
      platform: 'Virus rábico inactivado',
      liveVaccine: false,
      administration: 'Según protocolo pre/postexposición.',
      keyPoints: <String>[
        'La posible exposición se evalúa inmediatamente.',
        'Puede requerir inmunoglobulina.'
      ],
      contraindications: <String>[
        'En postexposición, el riesgo de rabia modifica la valoración de contraindicaciones relativas.'
      ],
      commonEffects: <String>['Dolor local, cefalea, náuseas o mialgia.'],
      alertSigns: <String>['No esperar síntomas tras exposición relevante.'],
      reference: 'Profilaxis de rabia humana / Ministerio de Salud / Argentina',
      safetyReference: 'Rabies Vaccine VIS / CDC',
      lastVerifiedAt: vaccineClinicalVersion,
      requiresClinicalAssessment: true,
    ),
    VaccineClinicalRecord(
      id: 'ar_pneumo_risk',
      title: 'Neumococo — grupos de riesgo',
      status: VaccineProgramStatus.riskGroup,
      statusLabel: 'Grupo de riesgo',
      schedule: 'Según edad, comorbilidad y antecedentes de PCV/PPSV23.',
      prevents: 'Enfermedad neumocócica invasiva y neumonía.',
      platform: 'Conjugada/polisacárida según estrategia',
      liveVaccine: false,
      administration: 'Según vacuna.',
      keyPoints: <String>['Revisar tipo y fecha de dosis previas.'],
      contraindications: <String>['Anafilaxia a dosis/componente.'],
      commonEffects: <String>['Dolor local, fiebre o mialgia.'],
      alertSigns: <String>['Reacción alérgica grave.'],
      reference:
          'Calendario Nacional de Vacunación 2026 / Ministerio de Salud de la Nación / Argentina',
      lastVerifiedAt: vaccineClinicalVersion,
      requiresClinicalAssessment: true,
    ),
    VaccineClinicalRecord(
      id: 'ar_menb',
      title: 'Meningocócica B',
      status: VaccineProgramStatus.nonUniversal,
      statusLabel: 'No universal',
      schedule:
          'No integra el esquema universal; depende de producto, edad e indicación.',
      prevents: 'Enfermedad invasiva por meningococo B.',
      platform: 'No viva; por producto',
      liveVaccine: false,
      administration: 'Según producto.',
      keyPoints: <String>['MenB no sustituye MenACWY.'],
      contraindications: <String>['Anafilaxia a dosis/componente.'],
      commonEffects: <String>['Dolor local, fiebre, cefalea o fatiga.'],
      alertSigns: <String>['Reacción alérgica grave.'],
      reference: 'No integrante universal del Calendario Nacional argentino',
      lastVerifiedAt: vaccineClinicalVersion,
      requiresClinicalAssessment: true,
    ),
    VaccineClinicalRecord(
      id: 'ar_zoster',
      title: 'Herpes zóster — RZV',
      status: VaccineProgramStatus.nonUniversal,
      statusLabel: 'No universal',
      schedule:
          'No integra actualmente el calendario nacional universal; individualizar.',
      prevents: 'Herpes zóster y neuralgia posherpética.',
      platform: 'Recombinante adyuvada',
      liveVaccine: false,
      administration: 'Según producto.',
      keyPoints: <String>[
        'No extrapolar automáticamente esquemas de otros países.'
      ],
      contraindications: <String>['Anafilaxia a dosis/componente.'],
      commonEffects: <String>['Dolor local, mialgia, fatiga o fiebre.'],
      alertSigns: <String>[
        'Reacción alérgica o evento neurológico importante.'
      ],
      reference: 'No integrante universal del Calendario Nacional argentino',
      lastVerifiedAt: vaccineClinicalVersion,
      requiresClinicalAssessment: true,
    ),
    VaccineClinicalRecord(
      id: 'ar_travel',
      title: 'Vacunas del viajero',
      status: VaccineProgramStatus.travelExposure,
      statusLabel: 'Viaje / exposición',
      schedule:
          'Depende de destino, duración, actividad, antecedentes y requisitos sanitarios.',
      prevents: 'Riesgos específicos de viaje/exposición.',
      platform: 'Variable',
      liveVaccine: false,
      administration: 'Variable.',
      keyPoints: <String>[
        'No deben aparecer como “faltantes” para toda persona.'
      ],
      contraindications: <String>['Dependen de cada vacuna.'],
      commonEffects: <String>['Dependen del producto.'],
      alertSigns: <String>['Dependen del producto/exposición.'],
      reference: 'Fuentes nacionales + OMS/OPS según destino',
      lastVerifiedAt: vaccineClinicalVersion,
      requiresClinicalAssessment: true,
      requiresLiveStatusCheck: true,
    ),
  ],
);

const brazilVaccineCatalog2026 = VaccineCatalog(
  jurisdiction: VaccineJurisdiction.brazil,
  countryLabel: 'BRASIL',
  programLabel: 'Programa Nacional de Imunizações — PNI',
  versionLabel: '2026',
  lastVerifiedAt: vaccineClinicalVersion,
  primaryReference:
      'Instrução Normativa do Calendário Nacional de Vacinação 2026 / PNI / Ministério da Saúde / Brasil',
  routineGroups: <VaccineAgeGroup>[
    VaccineAgeGroup(
      id: 'br_birth',
      label: 'Nascimento / 0 mês',
      entries: <VaccineDoseRef>[
        VaccineDoseRef(vaccineId: 'br_bcg', schedule: 'Dose única'),
        VaccineDoseRef(vaccineId: 'br_hepb', schedule: 'Dose ao nascer'),
      ],
    ),
    VaccineAgeGroup(
      id: 'br_2m',
      label: '2 meses',
      entries: <VaccineDoseRef>[
        VaccineDoseRef(vaccineId: 'br_penta', schedule: '1ª dose'),
        VaccineDoseRef(vaccineId: 'br_ipv', schedule: '1ª dose'),
        VaccineDoseRef(vaccineId: 'br_pcv', schedule: '1ª dose'),
        VaccineDoseRef(vaccineId: 'br_rotavirus', schedule: '1ª dose'),
      ],
    ),
    VaccineAgeGroup(
      id: 'br_3m',
      label: '3 meses',
      entries: <VaccineDoseRef>[
        VaccineDoseRef(vaccineId: 'br_menc', schedule: '1ª dose'),
      ],
    ),
    VaccineAgeGroup(
      id: 'br_4m',
      label: '4 meses',
      entries: <VaccineDoseRef>[
        VaccineDoseRef(vaccineId: 'br_penta', schedule: '2ª dose'),
        VaccineDoseRef(vaccineId: 'br_ipv', schedule: '2ª dose'),
        VaccineDoseRef(vaccineId: 'br_pcv', schedule: '2ª dose'),
        VaccineDoseRef(vaccineId: 'br_rotavirus', schedule: '2ª dose'),
      ],
    ),
    VaccineAgeGroup(
      id: 'br_5m',
      label: '5 meses',
      entries: <VaccineDoseRef>[
        VaccineDoseRef(vaccineId: 'br_menc', schedule: '2ª dose'),
      ],
    ),
    VaccineAgeGroup(
      id: 'br_6m',
      label: '6 meses',
      entries: <VaccineDoseRef>[
        VaccineDoseRef(vaccineId: 'br_penta', schedule: '3ª dose'),
        VaccineDoseRef(vaccineId: 'br_ipv', schedule: '3ª dose'),
        VaccineDoseRef(
            vaccineId: 'br_influenza',
            schedule: 'Início da rotina em crianças elegíveis'),
        VaccineDoseRef(vaccineId: 'br_covid', schedule: '1ª dose infantil'),
      ],
    ),
    VaccineAgeGroup(
      id: 'br_7m',
      label: '7 meses',
      entries: <VaccineDoseRef>[
        VaccineDoseRef(
            vaccineId: 'br_covid', schedule: '2ª dose no esquema Comirnaty'),
      ],
    ),
    VaccineAgeGroup(
      id: 'br_9m',
      label: '9 meses',
      entries: <VaccineDoseRef>[
        VaccineDoseRef(vaccineId: 'br_yf', schedule: '1ª dose'),
        VaccineDoseRef(
            vaccineId: 'br_covid',
            schedule: '3ª dose no esquema correspondente'),
      ],
    ),
    VaccineAgeGroup(
      id: 'br_12m',
      label: '12 meses (1 ano)',
      entries: <VaccineDoseRef>[
        VaccineDoseRef(vaccineId: 'br_pcv', schedule: 'Reforço'),
        VaccineDoseRef(vaccineId: 'br_menacwy', schedule: 'Dose aos 12 meses'),
        VaccineDoseRef(vaccineId: 'br_mmr', schedule: '1ª dose'),
      ],
    ),
    VaccineAgeGroup(
      id: 'br_15m',
      label: '15 meses',
      entries: <VaccineDoseRef>[
        VaccineDoseRef(vaccineId: 'br_dtp', schedule: '1º reforço'),
        VaccineDoseRef(vaccineId: 'br_ipv', schedule: '1º reforço'),
        VaccineDoseRef(vaccineId: 'br_mmr', schedule: '2ª dose'),
        VaccineDoseRef(vaccineId: 'br_varicella', schedule: '1ª dose'),
        VaccineDoseRef(vaccineId: 'br_hepa', schedule: 'Dose única'),
      ],
    ),
    VaccineAgeGroup(
      id: 'br_4y',
      label: '4 anos',
      entries: <VaccineDoseRef>[
        VaccineDoseRef(vaccineId: 'br_dtp', schedule: '2º reforço'),
        VaccineDoseRef(vaccineId: 'br_ipv', schedule: '2º reforço'),
        VaccineDoseRef(vaccineId: 'br_yf', schedule: 'Reforço'),
        VaccineDoseRef(vaccineId: 'br_varicella', schedule: '2ª dose'),
      ],
    ),
    VaccineAgeGroup(
      id: 'br_9_14',
      label: '9 a 14 anos',
      entries: <VaccineDoseRef>[
        VaccineDoseRef(vaccineId: 'br_hpv', schedule: 'Dose única'),
      ],
    ),
    VaccineAgeGroup(
      id: 'br_10_14',
      label: '10 a 14 anos',
      entries: <VaccineDoseRef>[
        VaccineDoseRef(
            vaccineId: 'br_qdenga',
            schedule: '2 doses com intervalo de 3 meses'),
      ],
      note: 'Oferta depende da estratégia e organização territorial.',
    ),
    VaccineAgeGroup(
      id: 'br_11_14',
      label: '11 a 14 anos',
      entries: <VaccineDoseRef>[
        VaccineDoseRef(vaccineId: 'br_menacwy', schedule: 'Dose/reforço'),
      ],
    ),
    VaccineAgeGroup(
      id: 'br_adult',
      label: 'Adultos (20 a 59 anos)',
      entries: <VaccineDoseRef>[
        VaccineDoseRef(
            vaccineId: 'br_hepb', schedule: 'Completar conforme histórico'),
        VaccineDoseRef(
            vaccineId: 'br_td', schedule: 'Completar e manter refuerços'),
        VaccineDoseRef(
            vaccineId: 'br_mmr',
            schedule: 'Atualizar conforme idade/histórico'),
        VaccineDoseRef(
            vaccineId: 'br_yf',
            schedule: 'Atualizar conforme antecedente/indicação'),
      ],
    ),
    VaccineAgeGroup(
      id: 'br_60',
      label: 'Idosos (60 anos ou mais)',
      entries: <VaccineDoseRef>[
        VaccineDoseRef(vaccineId: 'br_influenza', schedule: 'Anual'),
        VaccineDoseRef(
            vaccineId: 'br_covid', schedule: 'Periodicidade semestral em 2026'),
        VaccineDoseRef(
            vaccineId: 'br_hepb', schedule: 'Completar conforme histórico'),
        VaccineDoseRef(vaccineId: 'br_td', schedule: 'Manter reforços'),
      ],
      note:
          'Pneumocócicas e febre amarela dependem de histórico, risco e indicação.',
    ),
  ],
  seasonalIds: <String>['br_influenza', 'br_covid'],
  pregnancyIds: <String>[
    'br_influenza',
    'br_covid',
    'br_tdap',
    'br_rsv',
    'br_hepb',
    'br_td'
  ],
  specialIds: <String>[
    'br_yf',
    'br_qdenga',
    'br_butantan_dv',
    'br_chik',
    'br_rabies',
    'br_pneumo_risk',
    'br_menb',
    'br_zoster',
    'br_travel'
  ],
  records: <VaccineClinicalRecord>[
    VaccineClinicalRecord(
      id: 'br_bcg',
      title: 'BCG',
      status: VaccineProgramStatus.routineAge,
      statusLabel: 'Rotina nacional',
      schedule:
          'Dose ao nascer; não vacinados podem ser avaliados até 4 anos, 11 meses e 29 dias conforme PNI.',
      prevents: 'Formas graves de tuberculose infantil.',
      platform: 'BCG vivo atenuado',
      liveVaccine: true,
      administration: 'Intradérmica; volume depende de idade/apresentação.',
      keyPoints: <String>[
        'Ausência de cicatriz isoladamente não indica revacinação.'
      ],
      contraindications: <String>[
        'Imunodeficiência celular significativa ou imunossupressão grave.'
      ],
      commonEffects: <String>['Pápula, nódulo, pequena ulceração e cicatriz.'],
      alertSigns: <String>[
        'Lesão extensa, supuração persistente ou quadro sistêmico.'
      ],
      reference:
          'Instrução Normativa do Calendário Nacional de Vacinação 2026 / PNI / Ministério da Saúde / Brasil',
      safetyReference: 'BCG Vaccine Safety / WHO',
      lastVerifiedAt: vaccineClinicalVersion,
    ),
    VaccineClinicalRecord(
      id: 'br_hepb',
      title: 'Hepatite B',
      status: VaccineProgramStatus.routineAge,
      statusLabel: 'Rotina nacional',
      schedule:
          'Dose ao nascer, idealmente nas primeiras 12 h; completar segundo idade/histórico.',
      prevents: 'Hepatite B aguda/crônica e complicações.',
      platform: 'HBsAg recombinante',
      liveVaccine: false,
      administration: 'Intramuscular.',
      keyPoints: <String>[
        'Não reiniciar doses válidas por atraso.',
        'Exposição perinatal exige protocolo neonatal específico.'
      ],
      contraindications: <String>['Anafilaxia a dose/componente.'],
      commonEffects: <String>['Dor local, febre baixa, cefaleia ou mal-estar.'],
      alertSigns: <String>['Reação alérgica sistêmica.'],
      reference:
          'Instrução Normativa do Calendário Nacional de Vacinação 2026 / PNI / Ministério da Saúde / Brasil',
      safetyReference: 'Hepatitis B Vaccine VIS / CDC',
      lastVerifiedAt: vaccineClinicalVersion,
    ),
    VaccineClinicalRecord(
      id: 'br_penta',
      title: 'Pentavalente',
      status: VaccineProgramStatus.routineAge,
      statusLabel: 'Rotina nacional',
      schedule: '2, 4 e 6 meses.',
      prevents: 'Difteria, tétano, coqueluche, hepatite B e Hib.',
      platform: 'DTP-HB-Hib; não viva',
      liveVaccine: false,
      administration: 'Intramuscular.',
      keyPoints: <String>['Reforços posteriores são feitos com DTP.'],
      contraindications: <String>[
        'Anafilaxia; eventos neurológicos graves relacionados a pertussis exigem avaliação.'
      ],
      commonEffects: <String>['Dor, febre, irritabilidade, sonolência.'],
      alertSigns: <String>[
        'Convulsão, episódio hipotônico-hiporresponsivo ou anafilaxia.'
      ],
      reference:
          'Instrução Normativa do Calendário Nacional de Vacinação 2026 / PNI / Ministério da Saúde / Brasil',
      lastVerifiedAt: vaccineClinicalVersion,
    ),
    VaccineClinicalRecord(
      id: 'br_ipv',
      title: 'VIP / IPV',
      status: VaccineProgramStatus.routineAge,
      statusLabel: 'Rotina nacional',
      schedule: '2, 4 e 6 meses + reforços aos 15 meses e 4 anos.',
      prevents: 'Poliomielite paralítica.',
      platform: 'Poliovírus inativados',
      liveVaccine: false,
      administration: 'Intramuscular.',
      keyPoints: <String>['Não produz poliomielite associada à vacina.'],
      contraindications: <String>['Anafilaxia a dose/componente.'],
      commonEffects: <String>['Dor, eritema ou edema local.'],
      alertSigns: <String>['Reação alérgica grave.'],
      reference:
          'Instrução Normativa do Calendário Nacional de Vacinação 2026 / PNI / Ministério da Saúde / Brasil',
      safetyReference: 'Polio Vaccine VIS / CDC',
      lastVerifiedAt: vaccineClinicalVersion,
    ),
    VaccineClinicalRecord(
      id: 'br_pcv',
      title: 'Pneumocócica conjugada',
      status: VaccineProgramStatus.routineAge,
      statusLabel: 'Transição VPC10 → VPC20',
      schedule:
          '2 e 4 meses + reforço aos 12 meses; respeitar regra operacional de transição.',
      prevents: 'Doença pneumocócica invasiva e parte de pneumonias/otites.',
      platform: 'Polissacarídeos conjugados',
      liveVaccine: false,
      administration: 'Intramuscular.',
      keyPoints: <String>[
        'PNI 2026 está em transição VPC10→VPC20.',
        'Não presumir intercambialidade sem regra vigente.'
      ],
      contraindications: <String>['Anafilaxia a dose/componente.'],
      commonEffects: <String>['Dor local, febre, irritabilidade ou mialgia.'],
      alertSigns: <String>['Reação alérgica grave.'],
      reference:
          'Instrução Normativa do Calendário Nacional de Vacinação 2026 / PNI / Ministério da Saúde / Brasil',
      safetyReference: 'Pneumococcal Conjugate Vaccine VIS / CDC',
      lastVerifiedAt: vaccineClinicalVersion,
      requiresLiveStatusCheck: true,
    ),
    VaccineClinicalRecord(
      id: 'br_rotavirus',
      title: 'Rotavírus',
      status: VaccineProgramStatus.routineAge,
      statusLabel: 'Janela etária',
      schedule: 'Rotina aos 2 e 4 meses. D1: 1m15d–11m29d; D2: 3m15d–23m29d.',
      prevents: 'Gastroenterite grave por rotavírus.',
      platform: 'Vírus vivo atenuado',
      liveVaccine: true,
      administration: 'Oral.',
      keyPoints: <String>[
        'A janela brasileira é diferente da argentina.',
        'Atraso não implica reinício; respeitar idade/intervalos.'
      ],
      contraindications: <String>[
        'Invaginação intestinal prévia, SCID, idade fora de janela.'
      ],
      commonEffects: <String>['Irritabilidade, diarreia leve ou vômitos.'],
      alertSigns: <String>[
        'Dor abdominal intensa, vômitos repetidos, sangue nas fezes ou prostração.'
      ],
      reference:
          'Instrução Normativa do Calendário Nacional de Vacinação 2026 / PNI / Ministério da Saúde / Brasil',
      safetyReference: 'Rotavirus Vaccine VIS / CDC',
      lastVerifiedAt: vaccineClinicalVersion,
    ),
    VaccineClinicalRecord(
      id: 'br_menc',
      title: 'Meningocócica C',
      status: VaccineProgramStatus.routineAge,
      statusLabel: 'Rotina infantil',
      schedule: '3 e 5 meses.',
      prevents: 'Doença meningocócica invasiva pelo sorogrupo C.',
      platform: 'Conjugada',
      liveVaccine: false,
      administration: 'Intramuscular.',
      keyPoints: <String>['O reforço aos 12 meses é com MenACWY.'],
      contraindications: <String>['Anafilaxia a dose/componente.'],
      commonEffects: <String>['Dor local, febre ou irritabilidade.'],
      alertSigns: <String>['Reação alérgica grave.'],
      reference:
          'Instrução Normativa do Calendário Nacional de Vacinação 2026 / PNI / Ministério da Saúde / Brasil',
      lastVerifiedAt: vaccineClinicalVersion,
    ),
    VaccineClinicalRecord(
      id: 'br_menacwy',
      title: 'Meningocócica ACWY',
      status: VaccineProgramStatus.routineAge,
      statusLabel: 'Rotina nacional',
      schedule: 'Dose aos 12 meses + dose/reforço entre 11 e 14 anos.',
      prevents: 'Doença meningocócica invasiva A,C,W,Y.',
      platform: 'Conjugada',
      liveVaccine: false,
      administration: 'Intramuscular.',
      keyPoints: <String>['Brasil: MenC aos 3/5 meses, MenACWY aos 12 meses.'],
      contraindications: <String>['Anafilaxia a dose/componente.'],
      commonEffects: <String>['Dor local, febre, cefaleia ou fatiga.'],
      alertSigns: <String>['Reação alérgica grave.'],
      reference:
          'Instrução Normativa do Calendário Nacional de Vacinação 2026 / PNI / Ministério da Saúde / Brasil',
      safetyReference: 'Meningococcal ACWY Vaccine VIS / CDC',
      lastVerifiedAt: vaccineClinicalVersion,
    ),
    VaccineClinicalRecord(
      id: 'br_influenza',
      title: 'Influenza / Gripe',
      status: VaccineProgramStatus.seasonal,
      statusLabel: 'Anual / sazonal',
      schedule:
          'Rotina: 6 meses–<6 anos, gestantes e ≥60 anos, além de grupos da estratégia anual.',
      prevents: 'Influenza e complicações graves.',
      platform: 'Inativada trivalente sazonal',
      liveVaccine: false,
      administration: 'Intramuscular.',
      keyPoints: <String>[
        'Criança iniciando pode necessitar 2 doses conforme histórico.',
        'A vacina injetável não produz gripe.'
      ],
      contraindications: <String>[
        'Anafilaxia; antecedente de SGB temporalmente relacionado requer avaliação.'
      ],
      commonEffects: <String>['Dor local, febre, cefaleia, mialgia ou fadiga.'],
      alertSigns: <String>['Fraqueza neurológica progressiva ou anafilaxia.'],
      reference:
          'Estratégia de Vacinação contra Influenza 2026 / Ministério da Saúde / Brasil',
      safetyReference: 'Inactivated Influenza Vaccine VIS / CDC',
      lastVerifiedAt: vaccineClinicalVersion,
    ),
    VaccineClinicalRecord(
      id: 'br_covid',
      title: 'COVID-19',
      status: VaccineProgramStatus.seasonal,
      statusLabel: 'Rotina / periódico',
      schedule:
          '6m–4a11m: esquema por produto; Comirnaty em 6,7,9 meses. ≥60: semestral em 2026. Gestantes: 1 dose por gestação.',
      prevents: 'Principalmente formas graves, hospitalização e óbito.',
      platform: 'Produto/plataforma versionados',
      liveVaccine: false,
      administration: 'Intramuscular; volume por produto.',
      keyPoints: <String>[
        'Produto/apresentação mudam rapidamente.',
        'Imunocomprometidos têm esquema próprio.'
      ],
      contraindications: <String>['Anafilaxia a dose/componente.'],
      commonEffects: <String>['Dor local, fadiga, cefaleia, mialgia ou febre.'],
      alertSigns: <String>[
        'Dor torácica persistente, falta de ar ou palpitações.'
      ],
      reference:
          'Instrução Normativa do Calendário Nacional de Vacinação 2026 / PNI / Ministério da Saúde / Brasil',
      safetyReference: 'COVID-19 Vaccine VIS / CDC',
      lastVerifiedAt: vaccineClinicalVersion,
      requiresLiveStatusCheck: true,
    ),
    VaccineClinicalRecord(
      id: 'br_yf',
      title: 'Febre amarela',
      status: VaccineProgramStatus.routineAge,
      statusLabel: 'Rotina nacional + avaliação',
      schedule:
          'D1 aos 9 meses + reforço aos 4 anos; adultos por antecedente; ≥60 exige risco-benefício quando indicada.',
      prevents: 'Febre amarela e formas graves.',
      platform: 'Vírus vivo atenuado 17D',
      liveVaccine: true,
      administration: 'Segundo produto/norma.',
      keyPoints: <String>[
        'Recomendação brasileira abrange o território nacional.'
      ],
      contraindications: <String>[
        'Imunossupressão grave; gestação/lactação/≥60 requerem avaliação.'
      ],
      commonEffects: <String>['Dor local, febre, cefaleia ou mialgia.'],
      alertSigns: <String>[
        'Febre alta persistente, icterícia ou sintomas neurológicos.'
      ],
      reference:
          'Instrução Normativa do Calendário Nacional de Vacinação 2026 / PNI / Ministério da Saúde / Brasil',
      safetyReference: 'Yellow Fever Vaccine VIS / CDC',
      lastVerifiedAt: vaccineClinicalVersion,
      requiresClinicalAssessment: true,
    ),
    VaccineClinicalRecord(
      id: 'br_mmr',
      title: 'Tríplice viral — SCR',
      status: VaccineProgramStatus.routineAge,
      statusLabel: 'Rotina nacional',
      schedule:
          'D1 aos 12 meses + D2 aos 15 meses; recuperação depende de idade/histórico.',
      prevents: 'Sarampo, caxumba e rubéola.',
      platform: 'Vírus vivos atenuados',
      liveVaccine: true,
      administration: 'Conforme produto.',
      keyPoints: <String>['Trabalhadores de saúde possuem esquema específico.'],
      contraindications: <String>[
        'Gestação, imunossupressão grave, anafilaxia relevante.'
      ],
      commonEffects: <String>[
        'Fiebre, exantema leve, adenopatia ou artralgia.'
      ],
      alertSigns: <String>['Convulsão prolongada ou reação alérgica grave.'],
      reference:
          'Instrução Normativa do Calendário Nacional de Vacinação 2026 / PNI / Ministério da Saúde / Brasil',
      safetyReference: 'MMR Vaccine VIS / CDC',
      lastVerifiedAt: vaccineClinicalVersion,
    ),
    VaccineClinicalRecord(
      id: 'br_dtp',
      title: 'DTP — Tríplice bacteriana celular',
      status: VaccineProgramStatus.routineAge,
      statusLabel: 'Reforço infantil',
      schedule: 'Reforços aos 15 meses e 4 anos.',
      prevents: 'Difteria, tétano e coqueluche.',
      platform: 'Toxoides + pertussis celular inativada',
      liveVaccine: false,
      administration: 'Intramuscular.',
      keyPoints: <String>[
        'Eventos importantes após pertussis exigem avaliação.'
      ],
      contraindications: <String>[
        'Anafilaxia; encefalopatia ligada a pertussis sem outra causa.'
      ],
      commonEffects: <String>['Dor, edema, febre ou irritabilidade.'],
      alertSigns: <String>[
        'Convulsão prolongada ou alteração importante de consciência.'
      ],
      reference:
          'Instrução Normativa do Calendário Nacional de Vacinação 2026 / PNI / Ministério da Saúde / Brasil',
      lastVerifiedAt: vaccineClinicalVersion,
    ),
    VaccineClinicalRecord(
      id: 'br_varicella',
      title: 'Varicela',
      status: VaccineProgramStatus.routineAge,
      statusLabel: 'Rotina nacional',
      schedule: 'D1 aos 15 meses + D2 aos 4 anos.',
      prevents: 'Varicela e complicações.',
      platform: 'Vírus vivo atenuado',
      liveVaccine: true,
      administration: 'Conforme produto.',
      keyPoints: <String>['Antivirais antiherpes podem interferir.'],
      contraindications: <String>['Gestação e imunossupressão grave.'],
      commonEffects: <String>['Dor local, febre ou exantema leve.'],
      alertSigns: <String>['Quadro sistêmico ou neurológico importante.'],
      reference:
          'Instrução Normativa do Calendário Nacional de Vacinação 2026 / PNI / Ministério da Saúde / Brasil',
      safetyReference: 'Varicella Vaccine VIS / CDC',
      lastVerifiedAt: vaccineClinicalVersion,
    ),
    VaccineClinicalRecord(
      id: 'br_hepa',
      title: 'Hepatite A',
      status: VaccineProgramStatus.routineAge,
      statusLabel: 'Rotina nacional',
      schedule: 'Dose única aos 15 meses.',
      prevents: 'Hepatite A e complicações.',
      platform: 'Vírus inativado',
      liveVaccine: false,
      administration: 'Intramuscular.',
      keyPoints: <String>['A idade de rotina brasileira difere da Argentina.'],
      contraindications: <String>['Anafilaxia a dose/componente.'],
      commonEffects: <String>['Dor local, febre, cefaleia ou fadiga.'],
      alertSigns: <String>['Reação alérgica grave.'],
      reference:
          'Instrução Normativa do Calendário Nacional de Vacinação 2026 / PNI / Ministério da Saúde / Brasil',
      safetyReference: 'Hepatitis A Vaccine VIS / CDC',
      lastVerifiedAt: vaccineClinicalVersion,
    ),
    VaccineClinicalRecord(
      id: 'br_hpv',
      title: 'HPV4',
      status: VaccineProgramStatus.routineAge,
      statusLabel: 'Rotina 9–14 anos',
      schedule:
          'Dose única 9–14 anos; recuperação e grupos especiais seguem regras próprias.',
      prevents: 'Infecção persistente por HPV e cânceres relacionados.',
      platform: 'VLP recombinantes',
      liveVaccine: false,
      administration: 'Intramuscular.',
      keyPoints: <String>[
        'Vacinar cedo dentro da janela de oportunidade.',
        'Imunocomprometidos podem ter esquema diferente.'
      ],
      contraindications: <String>['Anafilaxia a dose/componente.'],
      commonEffects: <String>[
        'Dor local, cefaleia, febre ou síncope vasovagal.'
      ],
      alertSigns: <String>['Reação alérgica grave.'],
      reference:
          'Instrução Normativa do Calendário Nacional de Vacinação 2026 / PNI / Ministério da Saúde / Brasil',
      safetyReference: 'HPV Vaccine VIS / CDC',
      lastVerifiedAt: vaccineClinicalVersion,
    ),
    VaccineClinicalRecord(
      id: 'br_qdenga',
      title: 'Dengue — Qdenga / DNG4',
      status: VaccineProgramStatus.focalizedStrategy,
      statusLabel: 'Estratégia 10–14 anos',
      schedule: '2 doses com intervalo de 3 meses na estratégia 2026.',
      prevents: 'Dengue pelos quatro sorotipos.',
      platform: 'Tetravalente viva atenuada',
      liveVaccine: true,
      administration: '0,5 mL subcutânea para o produto descrito.',
      keyPoints: <String>[
        'Oferta depende da estratégia/território.',
        'Não confundir com Butantan-DV.'
      ],
      contraindications: <String>[
        'Gestação, lactação, imunocompromisso importante.'
      ],
      commonEffects: <String>[
        'Dor local, cefaleia, mialgia, mal-estar ou febre.'
      ],
      alertSigns: <String>['Reação alérgica ou quadro sistêmico grave.'],
      reference:
          'Instrução Normativa do Calendário Nacional de Vacinação 2026 / PNI / Ministério da Saúde / Brasil',
      lastVerifiedAt: vaccineClinicalVersion,
      requiresClinicalAssessment: true,
      requiresLiveStatusCheck: true,
    ),
    VaccineClinicalRecord(
      id: 'br_tdap',
      title: 'dTpa',
      status: VaccineProgramStatus.pregnancy,
      statusLabel: 'Gestação',
      schedule:
          'Uma dose em cada gestação a partir de 20 semanas; outras indicações específicas existem.',
      prevents: 'Difteria, tétano e coqueluche.',
      platform: 'Toxoides + pertussis acelular',
      liveVaccine: false,
      administration: 'Intramuscular.',
      keyPoints: <String>['Aplicar em cada gestação segundo PNI.'],
      contraindications: <String>[
        'Anafilaxia; antecedentes neurológicos graves exigem avaliação.'
      ],
      commonEffects: <String>['Dor local, cefaleia, cansaço ou febrícula.'],
      alertSigns: <String>['Reação alérgica grave.'],
      reference:
          'Instrução Normativa do Calendário Nacional de Vacinação 2026 / PNI / Ministério da Saúde / Brasil',
      safetyReference: 'Tdap Vaccine VIS / CDC',
      lastVerifiedAt: vaccineClinicalVersion,
    ),
    VaccineClinicalRecord(
      id: 'br_rsv',
      title: 'VSR materna',
      status: VaccineProgramStatus.pregnancy,
      statusLabel: 'Gestação ≥28 semanas',
      schedule: 'Uma dose em cada gestação a partir de 28 semanas.',
      prevents: 'No lactente: doença respiratória baixa grave por VSR.',
      platform: 'Proteína F prefusão recombinante',
      liveVaccine: false,
      administration: 'Intramuscular.',
      keyPoints: <String>[
        'A janela brasileira começa em 28 semanas.',
        'Nirsevimabe não é vacina.'
      ],
      contraindications: <String>['Anafilaxia a dose/componente.'],
      commonEffects: <String>['Dor local, fadiga, cefaleia ou mialgias.'],
      alertSigns: <String>['Reação alérgica grave ou evento obstétrico agudo.'],
      reference:
          'Instrução Normativa do Calendário Nacional de Vacinação 2026 / PNI / Ministério da Saúde / Brasil',
      safetyReference: 'RSV Vaccine VIS / CDC',
      lastVerifiedAt: vaccineClinicalVersion,
    ),
    VaccineClinicalRecord(
      id: 'br_td',
      title: 'dT — Dupla adulto',
      status: VaccineProgramStatus.routineAge,
      statusLabel: 'Adultos / gestação',
      schedule:
          'Completar série básica conforme histórico + reforços periódicos.',
      prevents: 'Difteria e tétano.',
      platform: 'Toxoides',
      liveVaccine: false,
      administration: 'Intramuscular.',
      keyPoints: <String>['Não reiniciar série válida por atraso.'],
      contraindications: <String>['Anafilaxia a dose/componente.'],
      commonEffects: <String>['Dor, edema, cefaleia ou febre baixa.'],
      alertSigns: <String>['Reação alérgica grave.'],
      reference:
          'Instrução Normativa do Calendário Nacional de Vacinação 2026 / PNI / Ministério da Saúde / Brasil',
      safetyReference: 'Td Vaccine VIS / CDC',
      lastVerifiedAt: vaccineClinicalVersion,
    ),
    VaccineClinicalRecord(
      id: 'br_butantan_dv',
      title: 'Dengue — Butantan-DV',
      status: VaccineProgramStatus.temporaryHold,
      statusLabel: 'STATUS DINÂMICO — VERIFICAR',
      schedule:
          'Dose única. A estratégia pública foi temporariamente descontinuada em 08/06/2026 por precaução; não usar como recomendação automática sem nova verificação oficial.',
      prevents: 'Dengue pelos quatro sorotipos.',
      platform: 'Tetravalente viva atenuada',
      liveVaccine: true,
      administration: 'Conforme produto/guia técnico.',
      keyPoints: <String>[
        'Butantan-DV e Qdenga são produtos distintos.',
        'Aprovação regulatória não significa estratégia pública ativa.'
      ],
      contraindications: <String>[
        'Vacina viva: gestação/imunossupressão relevante exigem bloqueio/avaliação.'
      ],
      commonEffects: <String>['Reações locais e sistêmicas conforme produto.'],
      alertSigns: <String>[
        'Evento sistêmico grave ou reação alérgica importante.'
      ],
      reference:
          'Ministério da Saúde — descontinuação temporária da estratégia Butantan-DV / 08/06/2026',
      lastVerifiedAt: vaccineClinicalVersion,
      requiresClinicalAssessment: true,
      requiresLiveStatusCheck: true,
    ),
    VaccineClinicalRecord(
      id: 'br_chik',
      title: 'Chikungunya',
      status: VaccineProgramStatus.focalizedStrategy,
      statusLabel: 'Estratégia-piloto',
      schedule:
          'Dose única para adultos 18–59 anos em municípios selecionados na estratégia-piloto 2026.',
      prevents: 'Doença por vírus chikungunya.',
      platform: 'Recombinante viva atenuada',
      liveVaccine: true,
      administration: 'Conforme produto/protocolo.',
      keyPoints: <String>[
        'Não é vacinação universal.',
        'Elegibilidade depende de município e status vigente.'
      ],
      contraindications: <String>[
        'Gestação, lactação, imunocompromisso; condições descompensadas conforme protocolo.'
      ],
      commonEffects: <String>['Dor local, febre leve, mialgia ou fadiga.'],
      alertSigns: <String>['Evento sistêmico grave ou reação alérgica.'],
      reference: 'Nota Técnica nº 9/2026-CGFAM/DPNI/SVSA/MS / Brasil',
      lastVerifiedAt: vaccineClinicalVersion,
      requiresClinicalAssessment: true,
      requiresLiveStatusCheck: true,
    ),
    VaccineClinicalRecord(
      id: 'br_rabies',
      title: 'Vacina antirrábica humana',
      status: VaccineProgramStatus.postExposure,
      statusLabel: 'Exposição / protocolo',
      schedule:
          'Não definir só por idade. Pós-exposição depende de animal, lesão, epidemiologia, vacina prévia e necessidade de soro/imunoglobulina.',
      prevents: 'Raiva humana.',
      platform: 'Vírus rábico inativado',
      liveVaccine: false,
      administration: 'IM ou ID conforme protocolo.',
      keyPoints: <String>[
        'Exposição relevante deve ser avaliada imediatamente.'
      ],
      contraindications: <String>[
        'Em pós-exposição, o risco de raiva modifica contraindicações relativas.'
      ],
      commonEffects: <String>['Dor local, cefaleia, náuseas ou mialgia.'],
      alertSigns: <String>['Não esperar sintomas após exposição relevante.'],
      reference:
          'Fluxograma da Profilaxia da Raiva Humana / Ministério da Saúde / Brasil',
      safetyReference: 'Rabies Vaccine VIS / CDC',
      lastVerifiedAt: vaccineClinicalVersion,
      requiresClinicalAssessment: true,
    ),
    VaccineClinicalRecord(
      id: 'br_pneumo_risk',
      title: 'Pneumococo — grupos de risco',
      status: VaccineProgramStatus.riskGroup,
      statusLabel: 'Grupo especial',
      schedule:
          'Segundo idade, condição clínica, produto e histórico de PCV/PPSV23.',
      prevents: 'Doença pneumocócica invasiva e pneumonia.',
      platform: 'Conjugada/polisacárida conforme indicação',
      liveVaccine: false,
      administration: 'Segundo imunobiológico.',
      keyPoints: <String>[
        '≥60 não significa VPC20 universal para todos.',
        'Asplenia, implante coclear, fístula LCR, imunocompromisso e doença renal podem alterar esquema.'
      ],
      contraindications: <String>['Anafilaxia a dose/componente.'],
      commonEffects: <String>['Dor local, febre ou mialgia.'],
      alertSigns: <String>['Reação alérgica grave.'],
      reference: 'Instrução Normativa 2026 + CRIE / PNI / Brasil',
      lastVerifiedAt: vaccineClinicalVersion,
      requiresClinicalAssessment: true,
    ),
    VaccineClinicalRecord(
      id: 'br_menb',
      title: 'Meningocócica B',
      status: VaccineProgramStatus.nonUniversal,
      statusLabel: 'Não universal',
      schedule:
          'Não integra esquema universal do PNI; depende de produto, idade e indicação.',
      prevents: 'Doença invasiva por meningococo B.',
      platform: 'Não viva; por produto',
      liveVaccine: false,
      administration: 'Segundo produto.',
      keyPoints: <String>['MenB não substitui MenACWY.'],
      contraindications: <String>['Anafilaxia a dose/componente.'],
      commonEffects: <String>['Dor local, febre, cefaleia ou fadiga.'],
      alertSigns: <String>['Reação alérgica grave.'],
      reference: 'Indicação especial — não integrante universal do PNI',
      lastVerifiedAt: vaccineClinicalVersion,
      requiresClinicalAssessment: true,
    ),
    VaccineClinicalRecord(
      id: 'br_zoster',
      title: 'Herpes-zóster — RZV',
      status: VaccineProgramStatus.nonUniversal,
      statusLabel: 'Não universal',
      schedule:
          'Não integra atualmente o calendário nacional universal; individualizar.',
      prevents: 'Herpes-zóster e neuralgia pós-herpética.',
      platform: 'Recombinante adjuvada',
      liveVaccine: false,
      administration: 'Segundo produto.',
      keyPoints: <String>[
        'Não importar automaticamente calendário de outros países.'
      ],
      contraindications: <String>['Anafilaxia a dose/componente.'],
      commonEffects: <String>['Dor local, mialgia, fadiga ou febre.'],
      alertSigns: <String>['Reação alérgica ou evento neurológico importante.'],
      reference: 'Não integrante universal do PNI',
      lastVerifiedAt: vaccineClinicalVersion,
      requiresClinicalAssessment: true,
    ),
    VaccineClinicalRecord(
      id: 'br_travel',
      title: 'Vacinas do viajante',
      status: VaccineProgramStatus.travelExposure,
      statusLabel: 'Viagem / exposição',
      schedule:
          'Depende de destino, duração, atividade, antecedentes e requisitos sanitários.',
      prevents: 'Riscos específicos de viagem/exposição.',
      platform: 'Variável',
      liveVaccine: false,
      administration: 'Variável.',
      keyPoints: <String>[
        'Não devem aparecer como “faltando” para toda pessoa.'
      ],
      contraindications: <String>['Dependem de cada vacina.'],
      commonEffects: <String>['Dependem do produto.'],
      alertSigns: <String>['Dependem do produto/exposição.'],
      reference: 'PNI/ANVISA + fontes internacionais conforme destino',
      lastVerifiedAt: vaccineClinicalVersion,
      requiresClinicalAssessment: true,
      requiresLiveStatusCheck: true,
    ),
  ],
);
