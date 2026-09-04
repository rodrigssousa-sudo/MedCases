import '../../models/lab_reference_model.dart';

abstract final class LabReferenceCatalog {
  static const String clinicalVersion = '2026-08';
  static const String sourceMode = 'USER_PROVIDED_MASTER_BASE';

  static const List<LabReferenceCategory> categories = [
    LabReferenceCategory(id: 'hematology', pt: 'HEMATOLOGIA', es: 'HEMATOLOGÍA'),
    LabReferenceCategory(id: 'iron_nutrition', pt: 'FERRO / NUTRIÇÃO', es: 'HIERRO / NUTRICIÓN'),
    LabReferenceCategory(id: 'coagulation', pt: 'COAGULAÇÃO', es: 'COAGULACIÓN'),
    LabReferenceCategory(id: 'biochemistry', pt: 'BIOQUÍMICA', es: 'BIOQUÍMICA'),
    LabReferenceCategory(id: 'renal', pt: 'RENAL', es: 'RENAL'),
    LabReferenceCategory(id: 'hepatic', pt: 'HEPÁTICO', es: 'HEPÁTICO'),
    LabReferenceCategory(id: 'pancreatic', pt: 'PANCREÁTICO', es: 'PANCREÁTICO'),
    LabReferenceCategory(id: 'metabolic', pt: 'METABÓLICO', es: 'METABÓLICO'),
    LabReferenceCategory(id: 'endocrine', pt: 'ENDÓCRINO', es: 'ENDOCRINO'),
    LabReferenceCategory(id: 'inflammation', pt: 'INFLAMAÇÃO', es: 'INFLAMACIÓN'),
    LabReferenceCategory(id: 'cardiac', pt: 'CARDÍACO', es: 'CARDÍACO'),
    LabReferenceCategory(id: 'urine', pt: 'URINA', es: 'ORINA'),
    LabReferenceCategory(id: 'csf', pt: 'LCR', es: 'LCR'),
    LabReferenceCategory(id: 'body_fluids', pt: 'LÍQUIDOS BIOLÓGICOS', es: 'LÍQUIDOS BIOLÓGICOS'),
    LabReferenceCategory(id: 'blood_gas', pt: 'GASOMETRIA', es: 'GASOMETRÍA'),
    LabReferenceCategory(id: 'microbiology', pt: 'MICROBIOLOGIA', es: 'MICROBIOLOGÍA'),
    LabReferenceCategory(id: 'serology', pt: 'SOROLOGIA', es: 'SEROLOGÍA'),
    LabReferenceCategory(id: 'immunology', pt: 'IMUNOLOGIA / AUTOIMUNIDADE', es: 'INMUNOLOGÍA / AUTOINMUNIDAD'),
    LabReferenceCategory(id: 'toxicology', pt: 'TOXICOLOGIA', es: 'TOXICOLOGÍA'),
    LabReferenceCategory(id: 'therapeutic_monitoring', pt: 'MONITORIZAÇÃO TERAPÊUTICA', es: 'MONITORIZACIÓN TERAPÉUTICA'),
    LabReferenceCategory(id: 'oncology', pt: 'ONCOLOGIA', es: 'ONCOLOGÍA'),
    LabReferenceCategory(id: 'stool', pt: 'FEZES', es: 'HECES'),
    LabReferenceCategory(id: 'reproduction', pt: 'REPRODUÇÃO', es: 'REPRODUCCIÓN'),
  ];

  static const List<LabReferenceRecord> records = [
    LabReferenceRecord(
      testId: 'hb',
      canonicalNamePt: 'Hemoglobina — Hb',
      canonicalNameEs: 'Hemoglobina — Hb',
      categoryId: 'hematology',
      unit: 'g/dL',
      referenceIntervals: const [
        LabValueLine(labelPt: 'M 0–14 dias', labelEs: 'M 0–14 días', value: '13,9–19,1'),
        LabValueLine(labelPt: 'M 15 dias–4 semanas', labelEs: 'M 15 días–4 semanas', value: '10,0–15,3'),
        LabValueLine(labelPt: 'M 5–7 semanas', labelEs: 'M 5–7 semanas', value: '8,9–12,7'),
        LabValueLine(labelPt: 'M 8 semanas–5 meses', labelEs: 'M 8 semanas–5 meses', value: '9,6–12,4'),
        LabValueLine(labelPt: 'M 6–23 meses', labelEs: 'M 6–23 meses', value: '10,1–12,5'),
        LabValueLine(labelPt: 'M 24–35 meses', labelEs: 'M 24–35 meses', value: '10,2–12,7'),
        LabValueLine(labelPt: 'M 3–5 anos', labelEs: 'M 3–5 años', value: '11,4–14,3'),
        LabValueLine(labelPt: 'M 6–8 anos', labelEs: 'M 6–8 años', value: '11,5–14,3'),
        LabValueLine(labelPt: 'M 9–10 anos', labelEs: 'M 9–10 años', value: '11,8–14,7'),
        LabValueLine(labelPt: 'M 11–14 anos', labelEs: 'M 11–14 años', value: '12,4–15,7'),
        LabValueLine(labelPt: 'M 15–17 anos', labelEs: 'M 15–17 años', value: '13,3–16,9'),
        LabValueLine(labelPt: 'M adulto', labelEs: 'M adulto', value: '13,2–16,6'),
        LabValueLine(labelPt: 'F 0–14 dias', labelEs: 'F 0–14 días', value: '13,4–20,0'),
        LabValueLine(labelPt: 'F 15 dias–4 semanas', labelEs: 'F 15 días–4 semanas', value: '10,8–14,6'),
        LabValueLine(labelPt: 'F 5–7 semanas', labelEs: 'F 5–7 semanas', value: '9,2–11,4'),
        LabValueLine(labelPt: 'F 8 semanas–5 meses', labelEs: 'F 8 semanas–5 meses', value: '9,9–12,4'),
        LabValueLine(labelPt: 'F 6–35 meses', labelEs: 'F 6–35 meses', value: '10,2–12,7'),
        LabValueLine(labelPt: 'F 3–5 anos', labelEs: 'F 3–5 años', value: '11,4–14,3'),
        LabValueLine(labelPt: 'F 6–8 anos', labelEs: 'F 6–8 años', value: '11,5–14,3'),
        LabValueLine(labelPt: 'F 9–10 anos', labelEs: 'F 9–10 años', value: '11,8–14,7'),
        LabValueLine(labelPt: 'F 11–17 anos', labelEs: 'F 11–17 años', value: '11,9–14,8'),
        LabValueLine(labelPt: 'F adulto', labelEs: 'F adulto', value: '11,6–15,0'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: 'A queda fisiológica da Hb nos primeiros meses deve ser reconhecida.',
      clinicalNotesEs: 'Debe reconocerse la caída fisiológica de Hb en los primeros meses.',
      sourceTitle: 'Complete Blood Cell Count with Differential / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'hct',
      canonicalNamePt: 'Hematócrito — HCT',
      canonicalNameEs: 'Hematocrito — HCT',
      categoryId: 'hematology',
      unit: '%',
      referenceIntervals: const [
        LabValueLine(labelPt: 'M 0–14 dias', labelEs: 'M 0–14 días', value: '39,8–53,6'),
        LabValueLine(labelPt: 'M 15 dias–4 sem', labelEs: 'M 15 días–4 sem', value: '30,5–45,0'),
        LabValueLine(labelPt: 'M 5–7 sem', labelEs: 'M 5–7 sem', value: '26,8–37,5'),
        LabValueLine(labelPt: 'M 8 sem–5 meses', labelEs: 'M 8 sem–5 meses', value: '28,6–37,2'),
        LabValueLine(labelPt: 'M 6–23 meses', labelEs: 'M 6–23 meses', value: '30,8–37,8'),
        LabValueLine(labelPt: 'M 24–35 meses', labelEs: 'M 24–35 meses', value: '31,0–37,7'),
        LabValueLine(labelPt: 'M 3–7 anos', labelEs: 'M 3–7 años', value: '34–42'),
        LabValueLine(labelPt: 'M 8–11 anos', labelEs: 'M 8–11 años', value: '35–43'),
        LabValueLine(labelPt: 'M 12–15 anos', labelEs: 'M 12–15 años', value: '38–47'),
        LabValueLine(labelPt: 'M 16–17 anos', labelEs: 'M 16–17 años', value: '40–50'),
        LabValueLine(labelPt: 'M adulto', labelEs: 'M adulto', value: '38,3–48,6'),
        LabValueLine(labelPt: 'F 0–14 dias', labelEs: 'F 0–14 días', value: '39,6–57,2'),
        LabValueLine(labelPt: 'F 15 dias–4 sem', labelEs: 'F 15 días–4 sem', value: '32,0–44,5'),
        LabValueLine(labelPt: 'F 5–7 sem', labelEs: 'F 5–7 sem', value: '27,7–35,1'),
        LabValueLine(labelPt: 'F 8 sem–5 meses', labelEs: 'F 8 sem–5 meses', value: '29,5–37,1'),
        LabValueLine(labelPt: 'F 6–23 meses', labelEs: 'F 6–23 meses', value: '30,9–37,9'),
        LabValueLine(labelPt: 'F 24–35 meses', labelEs: 'F 24–35 meses', value: '31,2–37,8'),
        LabValueLine(labelPt: 'F 3–7 anos', labelEs: 'F 3–7 años', value: '34–42'),
        LabValueLine(labelPt: 'F 8–17 anos', labelEs: 'F 8–17 años', value: '35–43'),
        LabValueLine(labelPt: 'F adulto', labelEs: 'F adulto', value: '35,5–44,9'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'CBC with Differential / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'rbc',
      canonicalNamePt: 'Eritrócitos — RBC',
      canonicalNameEs: 'Eritrocitos — RBC',
      categoryId: 'hematology',
      unit: '×10¹²/L',
      referenceIntervals: const [
        LabValueLine(labelPt: 'M 0–14 dias', labelEs: 'M 0–14 días', value: '4,10–5,55'),
        LabValueLine(labelPt: 'M 15 d–4 sem', labelEs: 'M 15 d–4 sem', value: '3,16–4,63'),
        LabValueLine(labelPt: 'M 5–7 sem', labelEs: 'M 5–7 sem', value: '3,02–4,22'),
        LabValueLine(labelPt: 'M 8 sem–5 m', labelEs: 'M 8 sem–5 m', value: '3,43–4,80'),
        LabValueLine(labelPt: 'M 6–23 m', labelEs: 'M 6–23 m', value: '4,03–5,07'),
        LabValueLine(labelPt: 'M 24–35 m', labelEs: 'M 24–35 m', value: '3,89–4,97'),
        LabValueLine(labelPt: 'M 3–5 a', labelEs: 'M 3–5 a', value: '4,00–5,10'),
        LabValueLine(labelPt: 'M 6–10 a', labelEs: 'M 6–10 a', value: '4,10–5,20'),
        LabValueLine(labelPt: 'M 11–14 a', labelEs: 'M 11–14 a', value: '4,20–5,30'),
        LabValueLine(labelPt: 'M 15–17 a', labelEs: 'M 15–17 a', value: '4,30–5,70'),
        LabValueLine(labelPt: 'M adulto', labelEs: 'M adulto', value: '4,35–5,65'),
        LabValueLine(labelPt: 'F 0–14 dias', labelEs: 'F 0–14 días', value: '4,12–5,74'),
        LabValueLine(labelPt: 'F 15 d–4 sem', labelEs: 'F 15 d–4 sem', value: '3,32–4,80'),
        LabValueLine(labelPt: 'F 5–7 sem', labelEs: 'F 5–7 sem', value: '2,93–3,87'),
        LabValueLine(labelPt: 'F 8 sem–5 m', labelEs: 'F 8 sem–5 m', value: '3,45–4,75'),
        LabValueLine(labelPt: 'F 6–23 m', labelEs: 'F 6–23 m', value: '3,97–5,01'),
        LabValueLine(labelPt: 'F 24–35 m', labelEs: 'F 24–35 m', value: '3,84–4,92'),
        LabValueLine(labelPt: 'F 3–5 a', labelEs: 'F 3–5 a', value: '4,00–5,10'),
        LabValueLine(labelPt: 'F 6–10 a', labelEs: 'F 6–10 a', value: '4,10–5,20'),
        LabValueLine(labelPt: 'F 11–14 a', labelEs: 'F 11–14 a', value: '4,10–5,10'),
        LabValueLine(labelPt: 'F 15–17 a', labelEs: 'F 15–17 a', value: '3,80–5,00'),
        LabValueLine(labelPt: 'F adulto', labelEs: 'F adulto', value: '3,92–5,13'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'CBC with Differential / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'mcv',
      canonicalNamePt: 'VCM / MCV',
      canonicalNameEs: 'VCM / MCV',
      categoryId: 'hematology',
      unit: 'fL',
      referenceIntervals: const [
        LabValueLine(labelPt: 'M 0–14 dias', labelEs: 'M 0–14 días', value: '91,3–103,1'),
        LabValueLine(labelPt: 'M 15 d–4 sem', labelEs: 'M 15 d–4 sem', value: '89,4–99,7'),
        LabValueLine(labelPt: 'M 5–7 sem', labelEs: 'M 5–7 sem', value: '84,3–94,2'),
        LabValueLine(labelPt: 'M 8 sem–5 m', labelEs: 'M 8 sem–5 m', value: '74,1–87,5'),
        LabValueLine(labelPt: 'M 6–23 m', labelEs: 'M 6–23 m', value: '69,5–81,7'),
        LabValueLine(labelPt: 'M 24–35 m', labelEs: 'M 24–35 m', value: '71,3–84,0'),
        LabValueLine(labelPt: 'M 3–5 a', labelEs: 'M 3–5 a', value: '77,2–89,5'),
        LabValueLine(labelPt: 'M 6–11 a', labelEs: 'M 6–11 a', value: '77,8–91,1'),
        LabValueLine(labelPt: 'M 12–14 a', labelEs: 'M 12–14 a', value: '79,9–93,0'),
        LabValueLine(labelPt: 'M 15–17 a', labelEs: 'M 15–17 a', value: '82,5–98,0'),
        LabValueLine(labelPt: 'M adulto', labelEs: 'M adulto', value: '78,2–97,9'),
        LabValueLine(labelPt: 'F 0–14 dias', labelEs: 'F 0–14 días', value: '92,7–106,4'),
        LabValueLine(labelPt: 'F 15 d–4 sem', labelEs: 'F 15 d–4 sem', value: '90,1–103,0'),
        LabValueLine(labelPt: 'F 5–7 sem', labelEs: 'F 5–7 sem', value: '83,4–96,4'),
        LabValueLine(labelPt: 'F 8 sem–5 m', labelEs: 'F 8 sem–5 m', value: '74,8–88,3'),
        LabValueLine(labelPt: 'F 6–23 m', labelEs: 'F 6–23 m', value: '71,3–82,6'),
        LabValueLine(labelPt: 'F 24–35 m', labelEs: 'F 24–35 m', value: '72,3–85,0'),
        LabValueLine(labelPt: 'F 3–5 a', labelEs: 'F 3–5 a', value: '77,2–89,5'),
        LabValueLine(labelPt: 'F 6–11 a', labelEs: 'F 6–11 a', value: '77,8–91,1'),
        LabValueLine(labelPt: 'F 12–14 a', labelEs: 'F 12–14 a', value: '79,9–93,0'),
        LabValueLine(labelPt: 'F 15–17 a', labelEs: 'F 15–17 a', value: '82,5–98,0'),
        LabValueLine(labelPt: 'F adulto', labelEs: 'F adulto', value: '78,2–97,9'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: 'O VCM neonatal é fisiologicamente maior.',
      clinicalNotesEs: 'El VCM neonatal es fisiológicamente mayor.',
      sourceTitle: 'CBC with Differential / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'rdw',
      canonicalNamePt: 'RDW-CV',
      canonicalNameEs: 'RDW-CV',
      categoryId: 'hematology',
      unit: '%',
      referenceIntervals: const [
        LabValueLine(labelPt: 'M adulto', labelEs: 'M adulto', value: '11,8–14,5'),
        LabValueLine(labelPt: 'F adulto', labelEs: 'F adulto', value: '12,2–16,1'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: 'Valores adultos representativos; não aplicar automaticamente em crianças.',
      clinicalNotesEs: 'Valores adultos representativos; no aplicar automáticamente en niños.',
      sourceTitle: 'CBC with Differential / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'wbc',
      canonicalNamePt: 'Leucócitos totais',
      canonicalNameEs: 'Leucocitos totales',
      categoryId: 'hematology',
      unit: '×10⁹/L',
      referenceIntervals: const [
        LabValueLine(labelPt: 'M 0–14 d', labelEs: 'M 0–14 d', value: '8,0–15,4'),
        LabValueLine(labelPt: 'M 15 d–4 sem', labelEs: 'M 15 d–4 sem', value: '7,8–15,9'),
        LabValueLine(labelPt: 'M 5–7 sem', labelEs: 'M 5–7 sem', value: '8,1–15,0'),
        LabValueLine(labelPt: 'M 8 sem–5 m', labelEs: 'M 8 sem–5 m', value: '6,5–13,3'),
        LabValueLine(labelPt: 'M 6–23 m', labelEs: 'M 6–23 m', value: '6,0–13,5'),
        LabValueLine(labelPt: 'M 24–35 m', labelEs: 'M 24–35 m', value: '5,1–13,4'),
        LabValueLine(labelPt: 'M 3–5 a', labelEs: 'M 3–5 a', value: '4,4–12,9'),
        LabValueLine(labelPt: 'M 6–17 a', labelEs: 'M 6–17 a', value: '3,8–10,4'),
        LabValueLine(labelPt: 'M adulto', labelEs: 'M adulto', value: '3,4–9,6'),
        LabValueLine(labelPt: 'F 0–14 d', labelEs: 'F 0–14 d', value: '8,2–14,6'),
        LabValueLine(labelPt: 'F 15 d–4 sem', labelEs: 'F 15 d–4 sem', value: '8,4–14,4'),
        LabValueLine(labelPt: 'F 5–7 sem', labelEs: 'F 5–7 sem', value: '7,1–14,7'),
        LabValueLine(labelPt: 'F 8 sem–5 m', labelEs: 'F 8 sem–5 m', value: '6,0–13,3'),
        LabValueLine(labelPt: 'F 6–23 m', labelEs: 'F 6–23 m', value: '6,5–13,0'),
        LabValueLine(labelPt: 'F 24–35 m', labelEs: 'F 24–35 m', value: '4,9–13,2'),
        LabValueLine(labelPt: 'F 3–5 a', labelEs: 'F 3–5 a', value: '4,4–12,9'),
        LabValueLine(labelPt: 'F 6–17 a', labelEs: 'F 6–17 a', value: '3,8–10,4'),
        LabValueLine(labelPt: 'F adulto', labelEs: 'F adulto', value: '3,4–9,6'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'CBC with Differential / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'diff',
      canonicalNamePt: 'Diferencial leucocitário — adulto',
      canonicalNameEs: 'Diferencial leucocitario — adulto',
      categoryId: 'hematology',
      unit: '×10⁹/L',
      referenceIntervals: const [
        LabValueLine(labelPt: 'ANC', labelEs: 'ANC', value: '1,56–6,45'),
        LabValueLine(labelPt: 'Linfócitos', labelEs: 'Linfocitos', value: '0,95–3,07'),
        LabValueLine(labelPt: 'Monócitos', labelEs: 'Monocitos', value: '0,26–0,81'),
        LabValueLine(labelPt: 'Eosinófilos', labelEs: 'Eosinófilos', value: '0,03–0,48'),
        LabValueLine(labelPt: 'Basófilos', labelEs: 'Basófilos', value: '0,01–0,08'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
        LabValueLine(labelPt: 'ANC — crítico Mayo', labelEs: 'ANC — crítico Mayo', value: '≤0,5 ×10⁹/L'),
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: 'Preferir contagem absoluta; crianças pequenas têm faixas próprias.',
      clinicalNotesEs: 'Preferir recuento absoluto; niños pequeños tienen rangos propios.',
      sourceTitle: 'CBC with Differential / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific, LabReferenceStatus.criticalValue},
    ),
    LabReferenceRecord(
      testId: 'platelets',
      canonicalNamePt: 'Plaquetas',
      canonicalNameEs: 'Plaquetas',
      categoryId: 'hematology',
      unit: '×10⁹/L',
      referenceIntervals: const [
        LabValueLine(labelPt: 'M 0–14 d', labelEs: 'M 0–14 d', value: '218–419'),
        LabValueLine(labelPt: 'M 15 d–4 sem', labelEs: 'M 15 d–4 sem', value: '248–586'),
        LabValueLine(labelPt: 'M 5–7 sem', labelEs: 'M 5–7 sem', value: '229–562'),
        LabValueLine(labelPt: 'M 8 sem–5 m', labelEs: 'M 8 sem–5 m', value: '244–529'),
        LabValueLine(labelPt: 'M 6–23 m', labelEs: 'M 6–23 m', value: '206–445'),
        LabValueLine(labelPt: 'M 24–35 m', labelEs: 'M 24–35 m', value: '202–403'),
        LabValueLine(labelPt: 'M 3–5 a', labelEs: 'M 3–5 a', value: '187–445'),
        LabValueLine(labelPt: 'M 6–9 a', labelEs: 'M 6–9 a', value: '187–400'),
        LabValueLine(labelPt: 'M 10–13 a', labelEs: 'M 10–13 a', value: '177–381'),
        LabValueLine(labelPt: 'M 14–17 a', labelEs: 'M 14–17 a', value: '139–320'),
        LabValueLine(labelPt: 'M adulto', labelEs: 'M adulto', value: '135–317'),
        LabValueLine(labelPt: 'F 0–14 d', labelEs: 'F 0–14 d', value: '144–449'),
        LabValueLine(labelPt: 'F 15 d–4 sem', labelEs: 'F 15 d–4 sem', value: '279–571'),
        LabValueLine(labelPt: 'F 5–7 sem', labelEs: 'F 5–7 sem', value: '331–597'),
        LabValueLine(labelPt: 'F 8 sem–5 m', labelEs: 'F 8 sem–5 m', value: '247–580'),
        LabValueLine(labelPt: 'F 6–23 m', labelEs: 'F 6–23 m', value: '214–459'),
        LabValueLine(labelPt: 'F 24–35 m', labelEs: 'F 24–35 m', value: '189–394'),
        LabValueLine(labelPt: 'F 3–5 a', labelEs: 'F 3–5 a', value: '187–445'),
        LabValueLine(labelPt: 'F 6–9 a', labelEs: 'F 6–9 a', value: '187–400'),
        LabValueLine(labelPt: 'F 10–13 a', labelEs: 'F 10–13 a', value: '177–381'),
        LabValueLine(labelPt: 'F 14–17 a', labelEs: 'F 14–17 a', value: '158–362'),
        LabValueLine(labelPt: 'F adulto', labelEs: 'F adulto', value: '157–371'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
        LabValueLine(labelPt: 'Crítico Mayo', labelEs: 'Crítico Mayo', value: '≤40 ou ≥1.000 ×10⁹/L'),
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'CBC with Differential / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific, LabReferenceStatus.criticalValue},
    ),
    LabReferenceRecord(
      testId: 'retic',
      canonicalNamePt: 'Reticulócitos',
      canonicalNameEs: 'Reticulocitos',
      categoryId: 'hematology',
      unit: '%',
      referenceIntervals: const [
        LabValueLine(labelPt: '1–3 dias', labelEs: '1–3 días', value: '3,47–5,40'),
        LabValueLine(labelPt: '4 dias–4 sem', labelEs: '4 días–4 sem', value: '1,06–2,37'),
        LabValueLine(labelPt: '5–7 sem', labelEs: '5–7 sem', value: '2,12–3,47'),
        LabValueLine(labelPt: '8 sem–5 m', labelEs: '8 sem–5 m', value: '1,55–2,70'),
        LabValueLine(labelPt: '6–23 m', labelEs: '6–23 m', value: '0,99–1,82'),
        LabValueLine(labelPt: '2–5 a', labelEs: '2–5 a', value: '0,82–1,45'),
        LabValueLine(labelPt: '6–11 a', labelEs: '6–11 a', value: '0,98–1,94'),
        LabValueLine(labelPt: '12–17 a', labelEs: '12–17 a', value: '0,90–1,49'),
        LabValueLine(labelPt: 'Adulto', labelEs: 'Adulto', value: '0,60–2,71'),
        LabValueLine(labelPt: 'Contagem absoluta adulto', labelEs: 'Recuento absoluto adulto', value: '30,4–110,9 ×10⁹/L'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Reticulocyte Profile / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'ferritin',
      canonicalNamePt: 'Ferritina',
      canonicalNameEs: 'Ferritina',
      categoryId: 'iron_nutrition',
      unit: 'µg/L ou ng/mL',
      referenceIntervals: const [
        LabValueLine(labelPt: 'M 0–4 sem', labelEs: 'M 0–4 sem', value: '150–973'),
        LabValueLine(labelPt: 'M 5 sem–5 m', labelEs: 'M 5 sem–5 m', value: '9–580'),
        LabValueLine(labelPt: 'M 6 m–9 a', labelEs: 'M 6 m–9 a', value: '6–111'),
        LabValueLine(labelPt: 'M 10–17 a', labelEs: 'M 10–17 a', value: '15–201'),
        LabValueLine(labelPt: 'M adulto', labelEs: 'M adulto', value: '31–409'),
        LabValueLine(labelPt: 'F 0–4 sem', labelEs: 'F 0–4 sem', value: '150–973'),
        LabValueLine(labelPt: 'F 5 sem–5 m', labelEs: 'F 5 sem–5 m', value: '9–580'),
        LabValueLine(labelPt: 'F 6 m–17 a', labelEs: 'F 6 m–17 a', value: '8–115'),
        LabValueLine(labelPt: 'F 18–50 a', labelEs: 'F 18–50 a', value: '6–175'),
        LabValueLine(labelPt: 'F ≥51 a', labelEs: 'F ≥51 a', value: '11–328'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: 'Ferritina é reagente de fase aguda.',
      clinicalNotesEs: 'Ferritina es reactante de fase aguda.',
      sourceTitle: 'Ferritin, Serum / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'iron',
      canonicalNamePt: 'Ferro sérico',
      canonicalNameEs: 'Hierro sérico',
      categoryId: 'iron_nutrition',
      unit: 'µg/dL',
      referenceIntervals: const [
        LabValueLine(labelPt: 'M adulto', labelEs: 'M adulto', value: '50–150'),
        LabValueLine(labelPt: 'F adulto', labelEs: 'F adulto', value: '35–145'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Iron and Total Iron-Binding Capacity / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'tibc',
      canonicalNamePt: 'TIBC',
      canonicalNameEs: 'TIBC',
      categoryId: 'iron_nutrition',
      unit: 'µg/dL',
      referenceIntervals: const [
        LabValueLine(labelPt: 'Representativo', labelEs: 'Representativo', value: '250–400'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Iron and Total Iron-Binding Capacity / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'sat',
      canonicalNamePt: 'Saturação de transferrina',
      canonicalNameEs: 'Saturación de transferrina',
      categoryId: 'iron_nutrition',
      unit: '%',
      referenceIntervals: const [
        LabValueLine(labelPt: 'Representativo', labelEs: 'Representativo', value: '14–50'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Iron and Total Iron-Binding Capacity / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'trans',
      canonicalNamePt: 'Transferrina',
      canonicalNameEs: 'Transferrina',
      categoryId: 'iron_nutrition',
      unit: 'mg/dL',
      referenceIntervals: const [
        LabValueLine(labelPt: 'Representativo', labelEs: 'Representativo', value: '200–360'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Transferrin, Serum / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'b12',
      canonicalNamePt: 'Vitamina B12',
      canonicalNameEs: 'Vitamina B12',
      categoryId: 'iron_nutrition',
      unit: 'ng/L',
      referenceIntervals: const [
        LabValueLine(labelPt: 'Representativo', labelEs: 'Representativo', value: '180–914'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Vitamin B12 and Folate / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'folate',
      canonicalNamePt: 'Folato sérico',
      canonicalNameEs: 'Folato sérico',
      categoryId: 'iron_nutrition',
      unit: 'µg/L',
      referenceIntervals: const [
        LabValueLine(labelPt: 'Adequado', labelEs: 'Adecuado', value: '≥4'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Vitamin B12 and Folate / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'pt',
      canonicalNamePt: 'TP — Tempo de Protrombina',
      canonicalNameEs: 'TP — Tiempo de Protrombina',
      categoryId: 'coagulation',
      unit: 's',
      referenceIntervals: const [
        LabValueLine(labelPt: 'Representativo', labelEs: 'Representativo', value: '9,4–12,5'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Prolonged Clot Time Profile / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'inr',
      canonicalNamePt: 'INR',
      canonicalNameEs: 'INR',
      categoryId: 'coagulation',
      unit: '',
      referenceIntervals: const [
        LabValueLine(labelPt: 'Não anticoagulado', labelEs: 'No anticoagulado', value: '0,9–1,1'),
      ],
      clinicalDecisionLimits: const [
        LabValueLine(labelPt: 'Alvo comum varfarina', labelEs: 'Objetivo común warfarina', value: '2,0–3,0'),
      ],
      criticalValues: const [
        LabValueLine(labelPt: 'Crítico Mayo', labelEs: 'Crítico Mayo', value: '≥5,0'),
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Prolonged Clot Time Profile / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific, LabReferenceStatus.decisionLimit, LabReferenceStatus.criticalValue},
    ),
    LabReferenceRecord(
      testId: 'aptt',
      canonicalNamePt: 'TTPa / aPTT',
      canonicalNameEs: 'TTPa / aPTT',
      categoryId: 'coagulation',
      unit: 's',
      referenceIntervals: const [
        LabValueLine(labelPt: 'Representativo', labelEs: 'Representativo', value: '25–37'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Prolonged Clot Time Profile / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'tt',
      canonicalNamePt: 'Tempo de trombina',
      canonicalNameEs: 'Tiempo de trombina',
      categoryId: 'coagulation',
      unit: 's',
      referenceIntervals: const [
        LabValueLine(labelPt: 'Representativo', labelEs: 'Representativo', value: '15,8–24,9'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Prolonged Clot Time Profile / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'fib',
      canonicalNamePt: 'Fibrinogênio',
      canonicalNameEs: 'Fibrinógeno',
      categoryId: 'coagulation',
      unit: 'mg/dL',
      referenceIntervals: const [
        LabValueLine(labelPt: 'Adulto', labelEs: 'Adulto', value: '200–500'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Prolonged Clot Time Profile / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'ddimer',
      canonicalNamePt: 'D-dímero',
      canonicalNameEs: 'Dímero-D',
      categoryId: 'coagulation',
      unit: 'ng/mL FEU',
      referenceIntervals: const [
        LabValueLine(labelPt: 'Exemplo metodológico', labelEs: 'Ejemplo metodológico', value: '≤500'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: 'Ponto de corte depende do ensaio/contexto.',
      clinicalNotesEs: 'El punto de corte depende del ensayo/contexto.',
      sourceTitle: 'Prolonged Clot Time Profile / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'na',
      canonicalNamePt: 'Sódio',
      canonicalNameEs: 'Sodio',
      categoryId: 'biochemistry',
      unit: 'mmol/L',
      referenceIntervals: const [
        LabValueLine(labelPt: '≥1 ano', labelEs: '≥1 año', value: '135–145'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
        LabValueLine(labelPt: 'Crítico Mayo', labelEs: 'Crítico Mayo', value: '≤120 ou ≥160 mmol/L'),
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Comprehensive Metabolic Panel / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific, LabReferenceStatus.criticalValue},
    ),
    LabReferenceRecord(
      testId: 'k',
      canonicalNamePt: 'Potássio',
      canonicalNameEs: 'Potasio',
      categoryId: 'biochemistry',
      unit: 'mmol/L',
      referenceIntervals: const [
        LabValueLine(labelPt: '≥1 ano', labelEs: '≥1 año', value: '3,6–5,2'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
        LabValueLine(labelPt: 'Crítico Mayo', labelEs: 'Crítico Mayo', value: '≤2,5 ou ≥6,0 mmol/L'),
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: 'Hemólise pode causar pseudohipercalemia.',
      clinicalNotesEs: 'Hemólisis puede causar pseudohiperpotasemia.',
      sourceTitle: 'Comprehensive Metabolic Panel / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific, LabReferenceStatus.criticalValue},
    ),
    LabReferenceRecord(
      testId: 'cl',
      canonicalNamePt: 'Cloro',
      canonicalNameEs: 'Cloro',
      categoryId: 'biochemistry',
      unit: 'mmol/L',
      referenceIntervals: const [
        LabValueLine(labelPt: '1–17 anos', labelEs: '1–17 años', value: '102–112'),
        LabValueLine(labelPt: 'Adulto', labelEs: 'Adulto', value: '98–107'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Comprehensive Metabolic Panel / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'hco3',
      canonicalNamePt: 'Bicarbonato / CO₂ total',
      canonicalNameEs: 'Bicarbonato / CO₂ total',
      categoryId: 'biochemistry',
      unit: 'mmol/L',
      referenceIntervals: const [
        LabValueLine(labelPt: 'M 12–24 m', labelEs: 'M 12–24 m', value: '17–25'),
        LabValueLine(labelPt: 'M 3 a', labelEs: 'M 3 a', value: '18–26'),
        LabValueLine(labelPt: 'M 4–5 a', labelEs: 'M 4–5 a', value: '19–27'),
        LabValueLine(labelPt: 'M 6–7 a', labelEs: 'M 6–7 a', value: '20–28'),
        LabValueLine(labelPt: 'M 8–17 a', labelEs: 'M 8–17 a', value: '21–29'),
        LabValueLine(labelPt: 'M adulto', labelEs: 'M adulto', value: '22–29'),
        LabValueLine(labelPt: 'F 1–3 a', labelEs: 'F 1–3 a', value: '18–25'),
        LabValueLine(labelPt: 'F 4–5 a', labelEs: 'F 4–5 a', value: '19–26'),
        LabValueLine(labelPt: 'F 6–7 a', labelEs: 'F 6–7 a', value: '20–27'),
        LabValueLine(labelPt: 'F 8–9 a', labelEs: 'F 8–9 a', value: '21–28'),
        LabValueLine(labelPt: 'F ≥10 a', labelEs: 'F ≥10 a', value: '22–29'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Comprehensive Metabolic Panel / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'ag',
      canonicalNamePt: 'Ânion gap',
      canonicalNameEs: 'Anión gap',
      categoryId: 'biochemistry',
      unit: 'mmol/L',
      referenceIntervals: const [
        LabValueLine(labelPt: '≥7 anos', labelEs: '≥7 años', value: '7–15'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: 'AG = Na − (Cl + HCO₃); hipoalbuminemia reduz AG.',
      clinicalNotesEs: 'AG = Na − (Cl + HCO₃); hipoalbuminemia reduce AG.',
      sourceTitle: 'Comprehensive Metabolic Panel / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'ca',
      canonicalNamePt: 'Cálcio total',
      canonicalNameEs: 'Calcio total',
      categoryId: 'biochemistry',
      unit: 'mg/dL',
      referenceIntervals: const [
        LabValueLine(labelPt: '<1 ano', labelEs: '<1 año', value: '8,7–11,0'),
        LabValueLine(labelPt: '1–17 anos', labelEs: '1–17 años', value: '9,3–10,6'),
        LabValueLine(labelPt: '18–59 anos', labelEs: '18–59 años', value: '8,6–10,0'),
        LabValueLine(labelPt: '60–90 anos', labelEs: '60–90 años', value: '8,8–10,2'),
        LabValueLine(labelPt: '>90 anos', labelEs: '>90 años', value: '8,2–9,6'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Comprehensive Metabolic Panel / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'mg',
      canonicalNamePt: 'Magnésio',
      canonicalNameEs: 'Magnesio',
      categoryId: 'biochemistry',
      unit: 'mg/dL',
      referenceIntervals: const [
        LabValueLine(labelPt: '0–2 a', labelEs: '0–2 a', value: '1,6–2,7'),
        LabValueLine(labelPt: '3–5 a', labelEs: '3–5 a', value: '1,6–2,6'),
        LabValueLine(labelPt: '6–8 a', labelEs: '6–8 a', value: '1,6–2,5'),
        LabValueLine(labelPt: '9–11 a', labelEs: '9–11 a', value: '1,6–2,4'),
        LabValueLine(labelPt: '12–17 a', labelEs: '12–17 a', value: '1,6–2,3'),
        LabValueLine(labelPt: 'Adulto', labelEs: 'Adulto', value: '1,7–2,3'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
        LabValueLine(labelPt: 'Crítico Mayo', labelEs: 'Crítico Mayo', value: '≤1,0 ou ≥9,0 mg/dL'),
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Magnesium, Serum / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific, LabReferenceStatus.criticalValue},
    ),
    LabReferenceRecord(
      testId: 'phos',
      canonicalNamePt: 'Fósforo / Fosfato',
      canonicalNameEs: 'Fósforo / Fosfato',
      categoryId: 'biochemistry',
      unit: 'mg/dL',
      referenceIntervals: const [
        LabValueLine(labelPt: 'M 1–4 a', labelEs: 'M 1–4 a', value: '4,3–5,4'),
        LabValueLine(labelPt: 'M 5–13 a', labelEs: 'M 5–13 a', value: '3,7–5,4'),
        LabValueLine(labelPt: 'M 14–15 a', labelEs: 'M 14–15 a', value: '3,5–5,3'),
        LabValueLine(labelPt: 'M 16–17 a', labelEs: 'M 16–17 a', value: '3,1–4,7'),
        LabValueLine(labelPt: 'M adulto', labelEs: 'M adulto', value: '2,5–4,5'),
        LabValueLine(labelPt: 'F 1–7 a', labelEs: 'F 1–7 a', value: '4,3–5,4'),
        LabValueLine(labelPt: 'F 8–13 a', labelEs: 'F 8–13 a', value: '4,0–5,2'),
        LabValueLine(labelPt: 'F 14–15 a', labelEs: 'F 14–15 a', value: '3,5–4,9'),
        LabValueLine(labelPt: 'F 16–17 a', labelEs: 'F 16–17 a', value: '3,1–4,7'),
        LabValueLine(labelPt: 'F adulto', labelEs: 'F adulto', value: '2,5–4,5'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Phosphorus, Serum / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'creat',
      canonicalNamePt: 'Creatinina sérica',
      canonicalNameEs: 'Creatinina sérica',
      categoryId: 'renal',
      unit: 'mg/dL',
      referenceIntervals: const [
        LabValueLine(labelPt: 'M 0–11 m', labelEs: 'M 0–11 m', value: '0,17–0,42'),
        LabValueLine(labelPt: 'M 1–5 a', labelEs: 'M 1–5 a', value: '0,19–0,49'),
        LabValueLine(labelPt: 'M 6–10 a', labelEs: 'M 6–10 a', value: '0,26–0,61'),
        LabValueLine(labelPt: 'M 11–14 a', labelEs: 'M 11–14 a', value: '0,35–0,86'),
        LabValueLine(labelPt: 'M ≥15 a', labelEs: 'M ≥15 a', value: '0,74–1,35'),
        LabValueLine(labelPt: 'F 0–11 m', labelEs: 'F 0–11 m', value: '0,17–0,42'),
        LabValueLine(labelPt: 'F 1–5 a', labelEs: 'F 1–5 a', value: '0,19–0,49'),
        LabValueLine(labelPt: 'F 6–10 a', labelEs: 'F 6–10 a', value: '0,26–0,61'),
        LabValueLine(labelPt: 'F 11–15 a', labelEs: 'F 11–15 a', value: '0,35–0,86'),
        LabValueLine(labelPt: 'F ≥16 a', labelEs: 'F ≥16 a', value: '0,59–1,04'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Comprehensive Metabolic Panel / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'bun',
      canonicalNamePt: 'Ureia / BUN',
      canonicalNameEs: 'Urea / BUN',
      categoryId: 'renal',
      unit: 'mg/dL',
      referenceIntervals: const [
        LabValueLine(labelPt: '1–17 anos', labelEs: '1–17 años', value: '7–20'),
        LabValueLine(labelPt: 'Adulto M', labelEs: 'Adulto M', value: '8–24'),
        LabValueLine(labelPt: 'Adulto F', labelEs: 'Adulto F', value: '6–21'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Comprehensive Metabolic Panel / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'egfr',
      canonicalNamePt: 'eGFR — KDIGO',
      canonicalNameEs: 'eGFR — KDIGO',
      categoryId: 'renal',
      unit: 'mL/min/1,73 m²',
      referenceIntervals: const [
      ],
      clinicalDecisionLimits: const [
        LabValueLine(labelPt: 'G1', labelEs: 'G1', value: '≥90'),
        LabValueLine(labelPt: 'G2', labelEs: 'G2', value: '60–89'),
        LabValueLine(labelPt: 'G3a', labelEs: 'G3a', value: '45–59'),
        LabValueLine(labelPt: 'G3b', labelEs: 'G3b', value: '30–44'),
        LabValueLine(labelPt: 'G4', labelEs: 'G4', value: '15–29'),
        LabValueLine(labelPt: 'G5', labelEs: 'G5', value: '<15'),
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: 'G1/G2 isoladamente não significam DRC; DRC exige persistência ≥3 meses. Não aplicar CKD-EPI adulta em crianças.',
      clinicalNotesEs: 'G1/G2 aisladas no significan ERC; ERC requiere persistencia ≥3 meses. No aplicar CKD-EPI adulta en niños.',
      sourceTitle: 'KDIGO 2024 / KDIGO',
      methodSpecific: false,
      statuses: {LabReferenceStatus.decisionLimit},
    ),
    LabReferenceRecord(
      testId: 'acr',
      canonicalNamePt: 'Albuminúria — ACR',
      canonicalNameEs: 'Albuminuria — ACR',
      categoryId: 'renal',
      unit: 'mg/g',
      referenceIntervals: const [
      ],
      clinicalDecisionLimits: const [
        LabValueLine(labelPt: 'A1', labelEs: 'A1', value: '<30'),
        LabValueLine(labelPt: 'A2', labelEs: 'A2', value: '30–300'),
        LabValueLine(labelPt: 'A3', labelEs: 'A3', value: '>300'),
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'KDIGO 2024 / KDIGO',
      methodSpecific: false,
      statuses: {LabReferenceStatus.decisionLimit},
    ),
    LabReferenceRecord(
      testId: 'pcratio',
      canonicalNamePt: 'Proteína/creatinina urinária',
      canonicalNameEs: 'Proteína/creatinina urinaria',
      categoryId: 'renal',
      unit: 'mg/mg',
      referenceIntervals: const [
        LabValueLine(labelPt: 'Adulto', labelEs: 'Adulto', value: '<0,18'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Protein/Creatinine Ratio, Random Urine / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'ast',
      canonicalNamePt: 'AST / TGO',
      canonicalNameEs: 'AST / TGO',
      categoryId: 'hepatic',
      unit: 'U/L',
      referenceIntervals: const [
        LabValueLine(labelPt: 'M 1–13 a', labelEs: 'M 1–13 a', value: '8–60'),
        LabValueLine(labelPt: 'M ≥14 a', labelEs: 'M ≥14 a', value: '8–48'),
        LabValueLine(labelPt: 'F 1–13 a', labelEs: 'F 1–13 a', value: '8–50'),
        LabValueLine(labelPt: 'F ≥14 a', labelEs: 'F ≥14 a', value: '8–43'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Comprehensive Metabolic Panel / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'alt',
      canonicalNamePt: 'ALT / TGP',
      canonicalNameEs: 'ALT / TGP',
      categoryId: 'hepatic',
      unit: 'U/L',
      referenceIntervals: const [
        LabValueLine(labelPt: 'M ≥1 a', labelEs: 'M ≥1 a', value: '7–55'),
        LabValueLine(labelPt: 'F ≥1 a', labelEs: 'F ≥1 a', value: '7–45'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Comprehensive Metabolic Panel / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'alp',
      canonicalNamePt: 'Fosfatase alcalina — ALP/FAL',
      canonicalNameEs: 'Fosfatasa alcalina — ALP/FAL',
      categoryId: 'hepatic',
      unit: 'U/L',
      referenceIntervals: const [
        LabValueLine(labelPt: 'M 0–14 d', labelEs: 'M 0–14 d', value: '83–248'),
        LabValueLine(labelPt: 'M 15 d–<1 a', labelEs: 'M 15 d–<1 a', value: '122–469'),
        LabValueLine(labelPt: 'M 1–<10 a', labelEs: 'M 1–<10 a', value: '142–335'),
        LabValueLine(labelPt: 'M 10–<13 a', labelEs: 'M 10–<13 a', value: '129–417'),
        LabValueLine(labelPt: 'M 13–<15 a', labelEs: 'M 13–<15 a', value: '116–468'),
        LabValueLine(labelPt: 'M 15–<17 a', labelEs: 'M 15–<17 a', value: '82–331'),
        LabValueLine(labelPt: 'M 17–<19 a', labelEs: 'M 17–<19 a', value: '55–149'),
        LabValueLine(labelPt: 'M ≥19 a', labelEs: 'M ≥19 a', value: '40–129'),
        LabValueLine(labelPt: 'F 0–14 d', labelEs: 'F 0–14 d', value: '83–248'),
        LabValueLine(labelPt: 'F 15 d–<1 a', labelEs: 'F 15 d–<1 a', value: '122–469'),
        LabValueLine(labelPt: 'F 1–<10 a', labelEs: 'F 1–<10 a', value: '142–335'),
        LabValueLine(labelPt: 'F 10–<13 a', labelEs: 'F 10–<13 a', value: '129–417'),
        LabValueLine(labelPt: 'F 13–<15 a', labelEs: 'F 13–<15 a', value: '57–254'),
        LabValueLine(labelPt: 'F 15–<17 a', labelEs: 'F 15–<17 a', value: '50–117'),
        LabValueLine(labelPt: 'F ≥17 a', labelEs: 'F ≥17 a', value: '35–104'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Alkaline Phosphatase, Serum / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'ggt',
      canonicalNamePt: 'GGT',
      canonicalNameEs: 'GGT',
      categoryId: 'hepatic',
      unit: 'U/L',
      referenceIntervals: const [
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: 'Não armazenar intervalo global único; depende de método, idade e sexo.',
      clinicalNotesEs: 'No usar un intervalo global único; depende de método, edad y sexo.',
      sourceTitle: 'Gamma-Glutamyltransferase, Serum / Mayo Clinic Laboratories',
      methodSpecific: true,
      statuses: {LabReferenceStatus.methodSpecific, LabReferenceStatus.referenceNotEstablished},
    ),
    LabReferenceRecord(
      testId: 'bt',
      canonicalNamePt: 'Bilirrubina total',
      canonicalNameEs: 'Bilirrubina total',
      categoryId: 'hepatic',
      unit: 'mg/dL',
      referenceIntervals: const [
        LabValueLine(labelPt: '7–14 d', labelEs: '7–14 d', value: '0–14,9'),
        LabValueLine(labelPt: '15 d–17 a', labelEs: '15 d–17 a', value: '0–1,0'),
        LabValueLine(labelPt: 'Adulto', labelEs: 'Adulto', value: '0–1,2'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '0–6 dias: interpretar por idade pós-natal em horas/nomograma.',
      clinicalNotesEs: '0–6 días: interpretar por edad posnatal en horas/nomograma.',
      sourceTitle: 'Bilirubin, Neonatal and Total/Direct / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'bd',
      canonicalNamePt: 'Bilirrubina direta',
      canonicalNameEs: 'Bilirrubina directa',
      categoryId: 'hepatic',
      unit: 'mg/dL',
      referenceIntervals: const [
        LabValueLine(labelPt: '≥12 meses', labelEs: '≥12 meses', value: '0–0,3'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '<12 meses: intervalo não estabelecido no ensaio citado.',
      clinicalNotesEs: '<12 meses: intervalo no establecido en el ensayo citado.',
      sourceTitle: 'Bilirubin, Neonatal and Total/Direct / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'alb',
      canonicalNamePt: 'Albumina',
      canonicalNameEs: 'Albúmina',
      categoryId: 'hepatic',
      unit: 'g/dL',
      referenceIntervals: const [
        LabValueLine(labelPt: '≥12 meses', labelEs: '≥12 meses', value: '3,5–5,0'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Comprehensive Metabolic Panel / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'tp',
      canonicalNamePt: 'Proteína total',
      canonicalNameEs: 'Proteína total',
      categoryId: 'hepatic',
      unit: 'g/dL',
      referenceIntervals: const [
        LabValueLine(labelPt: '≥1 ano', labelEs: '≥1 año', value: '6,3–7,9'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Comprehensive Metabolic Panel / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'ldh',
      canonicalNamePt: 'LDH',
      canonicalNameEs: 'LDH',
      categoryId: 'hepatic',
      unit: 'U/L',
      referenceIntervals: const [
        LabValueLine(labelPt: '1–30 d', labelEs: '1–30 d', value: '135–750'),
        LabValueLine(labelPt: '31 d–11 m', labelEs: '31 d–11 m', value: '180–435'),
        LabValueLine(labelPt: '1–3 a', labelEs: '1–3 a', value: '160–370'),
        LabValueLine(labelPt: '4–6 a', labelEs: '4–6 a', value: '145–345'),
        LabValueLine(labelPt: '7–9 a', labelEs: '7–9 a', value: '143–290'),
        LabValueLine(labelPt: '10–12 a', labelEs: '10–12 a', value: '120–293'),
        LabValueLine(labelPt: '13–15 a', labelEs: '13–15 a', value: '110–283'),
        LabValueLine(labelPt: '16–17 a', labelEs: '16–17 a', value: '105–233'),
        LabValueLine(labelPt: 'Adulto', labelEs: 'Adulto', value: '122–222'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Lactate Dehydrogenase, Serum / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'amy',
      canonicalNamePt: 'Amilase',
      canonicalNameEs: 'Amilasa',
      categoryId: 'pancreatic',
      unit: 'U/L',
      referenceIntervals: const [
        LabValueLine(labelPt: '0–30 d', labelEs: '0–30 d', value: '0–6'),
        LabValueLine(labelPt: '31–182 d', labelEs: '31–182 d', value: '1–17'),
        LabValueLine(labelPt: '183–365 d', labelEs: '183–365 d', value: '6–44'),
        LabValueLine(labelPt: '1–3 a', labelEs: '1–3 a', value: '8–79'),
        LabValueLine(labelPt: '4–17 a', labelEs: '4–17 a', value: '21–110'),
        LabValueLine(labelPt: 'Adulto', labelEs: 'Adulto', value: '28–100'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Amylase, Serum / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'lip',
      canonicalNamePt: 'Lipase',
      canonicalNameEs: 'Lipasa',
      categoryId: 'pancreatic',
      unit: 'U/L',
      referenceIntervals: const [
        LabValueLine(labelPt: 'Adulto', labelEs: 'Adulto', value: '13–60'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Lipase, Serum / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'fg',
      canonicalNamePt: 'Glicemia de jejum',
      canonicalNameEs: 'Glucemia en ayunas',
      categoryId: 'metabolic',
      unit: 'mg/dL',
      referenceIntervals: const [
      ],
      clinicalDecisionLimits: const [
        LabValueLine(labelPt: 'Normal', labelEs: 'Normal', value: '<100'),
        LabValueLine(labelPt: 'Pré-diabetes', labelEs: 'Prediabetes', value: '100–125'),
        LabValueLine(labelPt: 'Diabetes', labelEs: 'Diabetes', value: '≥126'),
      ],
      criticalValues: const [
        LabValueLine(labelPt: 'Crítico Mayo ≥4 semanas', labelEs: 'Crítico Mayo ≥4 semanas', value: '≤50 ou ≥400 mg/dL'),
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Standards of Care in Diabetes—2026 / American Diabetes Association — ADA',
      methodSpecific: false,
      statuses: {LabReferenceStatus.decisionLimit, LabReferenceStatus.criticalValue},
    ),
    LabReferenceRecord(
      testId: 'ogtt',
      canonicalNamePt: 'TOTG 75 g — 2 h',
      canonicalNameEs: 'PTOG 75 g — 2 h',
      categoryId: 'metabolic',
      unit: 'mg/dL',
      referenceIntervals: const [
      ],
      clinicalDecisionLimits: const [
        LabValueLine(labelPt: 'Normal', labelEs: 'Normal', value: '<140'),
        LabValueLine(labelPt: 'Pré-diabetes', labelEs: 'Prediabetes', value: '140–199'),
        LabValueLine(labelPt: 'Diabetes', labelEs: 'Diabetes', value: '≥200'),
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Standards of Care in Diabetes—2026 / American Diabetes Association — ADA',
      methodSpecific: false,
      statuses: {LabReferenceStatus.decisionLimit},
    ),
    LabReferenceRecord(
      testId: 'rand',
      canonicalNamePt: 'Glicemia aleatória',
      canonicalNameEs: 'Glucemia aleatoria',
      categoryId: 'metabolic',
      unit: 'mg/dL',
      referenceIntervals: const [
      ],
      clinicalDecisionLimits: const [
        LabValueLine(labelPt: 'Diagnóstico contextual', labelEs: 'Diagnóstico contextual', value: '≥200 + sintomas clássicos/crise hiperglicêmica'),
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Standards of Care in Diabetes—2026 / American Diabetes Association — ADA',
      methodSpecific: false,
      statuses: {LabReferenceStatus.decisionLimit},
    ),
    LabReferenceRecord(
      testId: 'a1c',
      canonicalNamePt: 'HbA1c',
      canonicalNameEs: 'HbA1c',
      categoryId: 'metabolic',
      unit: '%',
      referenceIntervals: const [
        LabValueLine(labelPt: 'Referência representativa', labelEs: 'Referencia representativa', value: '4,0–5,6'),
      ],
      clinicalDecisionLimits: const [
        LabValueLine(labelPt: 'Pré-diabetes', labelEs: 'Prediabetes', value: '5,7–6,4'),
        LabValueLine(labelPt: 'Diabetes', labelEs: 'Diabetes', value: '≥6,5'),
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Hemoglobin A1c / Mayo Clinic Laboratories; ADA 2026',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific, LabReferenceStatus.decisionLimit},
    ),
    LabReferenceRecord(
      testId: 'ct',
      canonicalNamePt: 'Colesterol total',
      canonicalNameEs: 'Colesterol total',
      categoryId: 'metabolic',
      unit: 'mg/dL',
      referenceIntervals: const [
      ],
      clinicalDecisionLimits: const [
        LabValueLine(labelPt: '2–17 a aceitável', labelEs: '2–17 a aceptable', value: '<170'),
        LabValueLine(labelPt: '2–17 a limítrofe', labelEs: '2–17 a limítrofe', value: '170–199'),
        LabValueLine(labelPt: '2–17 a alto', labelEs: '2–17 a alto', value: '≥200'),
        LabValueLine(labelPt: 'Adulto desejável', labelEs: 'Adulto deseable', value: '<200'),
        LabValueLine(labelPt: 'Adulto limítrofe', labelEs: 'Adulto limítrofe', value: '200–239'),
        LabValueLine(labelPt: 'Adulto alto', labelEs: 'Adulto alto', value: '≥240'),
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Lipid Panel / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.decisionLimit},
    ),
    LabReferenceRecord(
      testId: 'ldl',
      canonicalNamePt: 'LDL',
      canonicalNameEs: 'LDL',
      categoryId: 'metabolic',
      unit: 'mg/dL',
      referenceIntervals: const [
      ],
      clinicalDecisionLimits: const [
        LabValueLine(labelPt: '2–17 a aceitável', labelEs: '2–17 a aceptable', value: '<110'),
        LabValueLine(labelPt: '2–17 a limítrofe', labelEs: '2–17 a limítrofe', value: '110–129'),
        LabValueLine(labelPt: '2–17 a alto', labelEs: '2–17 a alto', value: '≥130'),
        LabValueLine(labelPt: 'Adulto desejável', labelEs: 'Adulto deseable', value: '<100'),
        LabValueLine(labelPt: 'Adulto 100–129', labelEs: 'Adulto 100–129', value: 'acima do desejável'),
        LabValueLine(labelPt: 'Adulto 130–159', labelEs: 'Adulto 130–159', value: 'limítrofe alto'),
        LabValueLine(labelPt: 'Adulto 160–189', labelEs: 'Adulto 160–189', value: 'alto'),
        LabValueLine(labelPt: 'Adulto ≥190', labelEs: 'Adulto ≥190', value: 'muito alto'),
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Lipid Panel / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.decisionLimit},
    ),
    LabReferenceRecord(
      testId: 'hdl',
      canonicalNamePt: 'HDL',
      canonicalNameEs: 'HDL',
      categoryId: 'metabolic',
      unit: 'mg/dL',
      referenceIntervals: const [
      ],
      clinicalDecisionLimits: const [
        LabValueLine(labelPt: '2–17 a baixo', labelEs: '2–17 a bajo', value: '<40'),
        LabValueLine(labelPt: '2–17 a limítrofe', labelEs: '2–17 a limítrofe', value: '40–45'),
        LabValueLine(labelPt: '2–17 a aceitável', labelEs: '2–17 a aceptable', value: '>45'),
        LabValueLine(labelPt: 'Adulto M desejável', labelEs: 'Adulto M deseable', value: '≥40'),
        LabValueLine(labelPt: 'Adulto F desejável', labelEs: 'Adulto F deseable', value: '≥50'),
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Lipid Panel / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.decisionLimit},
    ),
    LabReferenceRecord(
      testId: 'nonhdl',
      canonicalNamePt: 'Não-HDL',
      canonicalNameEs: 'No-HDL',
      categoryId: 'metabolic',
      unit: 'mg/dL',
      referenceIntervals: const [
      ],
      clinicalDecisionLimits: const [
        LabValueLine(labelPt: '2–17 a aceitável', labelEs: '2–17 a aceptable', value: '<120'),
        LabValueLine(labelPt: '2–17 a limítrofe', labelEs: '2–17 a limítrofe', value: '120–144'),
        LabValueLine(labelPt: '2–17 a alto', labelEs: '2–17 a alto', value: '≥145'),
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Lipid Panel / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.decisionLimit},
    ),
    LabReferenceRecord(
      testId: 'tg',
      canonicalNamePt: 'Triglicerídeos',
      canonicalNameEs: 'Triglicéridos',
      categoryId: 'metabolic',
      unit: 'mg/dL',
      referenceIntervals: const [
      ],
      clinicalDecisionLimits: const [
        LabValueLine(labelPt: '2–9 a aceitável', labelEs: '2–9 a aceptable', value: '<75'),
        LabValueLine(labelPt: '2–9 a limítrofe', labelEs: '2–9 a limítrofe', value: '75–99'),
        LabValueLine(labelPt: '2–9 a alto', labelEs: '2–9 a alto', value: '≥100'),
        LabValueLine(labelPt: '10–17 a aceitável', labelEs: '10–17 a aceptable', value: '<90'),
        LabValueLine(labelPt: '10–17 a limítrofe', labelEs: '10–17 a limítrofe', value: '90–129'),
        LabValueLine(labelPt: '10–17 a alto', labelEs: '10–17 a alto', value: '≥130'),
        LabValueLine(labelPt: 'Adulto normal', labelEs: 'Adulto normal', value: '<150'),
        LabValueLine(labelPt: 'Adulto limítrofe', labelEs: 'Adulto limítrofe', value: '150–199'),
        LabValueLine(labelPt: 'Adulto alto', labelEs: 'Adulto alto', value: '200–499'),
        LabValueLine(labelPt: 'Adulto muito alto', labelEs: 'Adulto muy alto', value: '≥500'),
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Lipid Panel / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.decisionLimit},
    ),
    LabReferenceRecord(
      testId: 'tsh',
      canonicalNamePt: 'TSH',
      canonicalNameEs: 'TSH',
      categoryId: 'endocrine',
      unit: 'mIU/L',
      referenceIntervals: const [
        LabValueLine(labelPt: '0–5 d', labelEs: '0–5 d', value: '0,7–15,2'),
        LabValueLine(labelPt: '6 d–2 m', labelEs: '6 d–2 m', value: '0,7–11,0'),
        LabValueLine(labelPt: '3–11 m', labelEs: '3–11 m', value: '0,7–8,4'),
        LabValueLine(labelPt: '1–5 a', labelEs: '1–5 a', value: '0,7–6,0'),
        LabValueLine(labelPt: '6–10 a', labelEs: '6–10 a', value: '0,6–4,8'),
        LabValueLine(labelPt: '11–19 a', labelEs: '11–19 a', value: '0,5–4,3'),
        LabValueLine(labelPt: '≥20 a', labelEs: '≥20 a', value: '0,3–4,2'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Thyroid-Stimulating Hormone / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'ft4',
      canonicalNamePt: 'T4 livre',
      canonicalNameEs: 'T4 libre',
      categoryId: 'endocrine',
      unit: 'ng/dL',
      referenceIntervals: const [
        LabValueLine(labelPt: '0–5 d', labelEs: '0–5 d', value: '0,9–2,5'),
        LabValueLine(labelPt: '6 d–2 m', labelEs: '6 d–2 m', value: '0,9–2,2'),
        LabValueLine(labelPt: '3–11 m', labelEs: '3–11 m', value: '0,9–2,0'),
        LabValueLine(labelPt: '1–5 a', labelEs: '1–5 a', value: '1,0–1,8'),
        LabValueLine(labelPt: '6–10 a', labelEs: '6–10 a', value: '1,0–1,7'),
        LabValueLine(labelPt: '11–19 a', labelEs: '11–19 a', value: '1,0–1,6'),
        LabValueLine(labelPt: 'Adulto', labelEs: 'Adulto', value: '0,9–1,7'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Free Thyroxine / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 't3',
      canonicalNamePt: 'T3 total',
      canonicalNameEs: 'T3 total',
      categoryId: 'endocrine',
      unit: 'ng/dL',
      referenceIntervals: const [
        LabValueLine(labelPt: '0–5 d', labelEs: '0–5 d', value: '73–288'),
        LabValueLine(labelPt: '6 d–2 m', labelEs: '6 d–2 m', value: '80–275'),
        LabValueLine(labelPt: '3–11 m', labelEs: '3–11 m', value: '86–265'),
        LabValueLine(labelPt: '1–5 a', labelEs: '1–5 a', value: '92–248'),
        LabValueLine(labelPt: '6–10 a', labelEs: '6–10 a', value: '93–231'),
        LabValueLine(labelPt: '11–19 a', labelEs: '11–19 a', value: '91–218'),
        LabValueLine(labelPt: 'Adulto', labelEs: 'Adulto', value: '80–200'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Triiodothyronine, Total / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'ft3',
      canonicalNamePt: 'T3 livre',
      canonicalNameEs: 'T3 libre',
      categoryId: 'endocrine',
      unit: 'pg/mL',
      referenceIntervals: const [
        LabValueLine(labelPt: '0–1 m', labelEs: '0–1 m', value: '2,7–8,5'),
        LabValueLine(labelPt: '1–<12 m', labelEs: '1–<12 m', value: '3,4–5,6'),
        LabValueLine(labelPt: '1–<14 a', labelEs: '1–<14 a', value: '3,0–5,1'),
        LabValueLine(labelPt: '14–<19 a', labelEs: '14–<19 a', value: '3,3–5,3'),
        LabValueLine(labelPt: 'Adulto', labelEs: 'Adulto', value: '2,0–4,4'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Triiodothyronine, Free / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'others',
      canonicalNamePt: 'Outros hormônios',
      canonicalNameEs: 'Otras hormonas',
      categoryId: 'endocrine',
      unit: '',
      referenceIntervals: const [
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: 'Cortisol, ACTH, renina, aldosterona, PTH, prolactina, LH, FSH, estradiol, progesterona, testosterona, SHBG, DHEA-S, IGF-1, GH, insulina, C-peptídeo, metanefrinas e catecolaminas: usar intervalo específico do ensaio/contexto.',
      clinicalNotesEs: 'Cortisol, ACTH, renina, aldosterona, PTH, prolactina, LH, FSH, estradiol, progesterona, testosterona, SHBG, DHEA-S, IGF-1, GH, insulina, péptido C, metanefrinas y catecolaminas: usar rango específico del ensayo/contexto.',
      sourceTitle: 'Base clínica mestra agosto 2026',
      methodSpecific: true,
      statuses: {LabReferenceStatus.methodSpecific, LabReferenceStatus.referenceNotEstablished},
    ),
    LabReferenceRecord(
      testId: 'crp',
      canonicalNamePt: 'PCR / CRP',
      canonicalNameEs: 'PCR / CRP',
      categoryId: 'inflammation',
      unit: 'mg/L',
      referenceIntervals: const [
        LabValueLine(labelPt: 'Representativo', labelEs: 'Representativo', value: '<5,0'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'C-Reactive Protein, Serum / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'hscrp',
      canonicalNamePt: 'hsCRP',
      canonicalNameEs: 'hsCRP',
      categoryId: 'inflammation',
      unit: '',
      referenceIntervals: const [
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: 'Ensaio/contexto diferente, principalmente risco cardiovascular; não usar seus limites para infecção aguda.',
      clinicalNotesEs: 'Ensayo/contexto distinto, principalmente riesgo cardiovascular; no usar sus límites para infección aguda.',
      sourceTitle: 'C-Reactive Protein, Serum / Mayo Clinic Laboratories',
      methodSpecific: true,
      statuses: {LabReferenceStatus.methodSpecific, LabReferenceStatus.referenceNotEstablished},
    ),
    LabReferenceRecord(
      testId: 'esr',
      canonicalNamePt: 'VHS / ESR',
      canonicalNameEs: 'VSG / ESR',
      categoryId: 'inflammation',
      unit: '',
      referenceIntervals: const [
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: 'Dependente de idade, sexo e método; não há faixa universal única.',
      clinicalNotesEs: 'Depende de edad, sexo y método; no hay un rango universal único.',
      sourceTitle: 'Base clínica mestra agosto 2026',
      methodSpecific: true,
      statuses: {LabReferenceStatus.methodSpecific, LabReferenceStatus.referenceNotEstablished},
    ),
    LabReferenceRecord(
      testId: 'pct',
      canonicalNamePt: 'Procalcitonina',
      canonicalNameEs: 'Procalcitonina',
      categoryId: 'inflammation',
      unit: '',
      referenceIntervals: const [
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: 'A base lista o exame, mas não fornece cut-off numérico universal.',
      clinicalNotesEs: 'La base enumera el examen, pero no aporta un cut-off numérico universal.',
      sourceTitle: 'Base clínica mestra agosto 2026',
      methodSpecific: true,
      statuses: {LabReferenceStatus.methodSpecific, LabReferenceStatus.referenceNotEstablished},
    ),
    LabReferenceRecord(
      testId: 'trop',
      canonicalNamePt: 'hs-cTnT',
      canonicalNameEs: 'hs-cTnT',
      categoryId: 'cardiac',
      unit: 'ng/L',
      referenceIntervals: const [
      ],
      clinicalDecisionLimits: const [
        LabValueLine(labelPt: 'Masculino — exemplo 5ª geração', labelEs: 'Masculino — ejemplo 5ª generación', value: '≤15'),
        LabValueLine(labelPt: 'Feminino — exemplo 5ª geração', labelEs: 'Femenino — ejemplo 5ª generación', value: '≤10'),
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: 'Extremamente dependente do ensaio; não transferir para troponina I/outro fabricante.',
      clinicalNotesEs: 'Extremadamente dependiente del ensayo; no transferir a troponina I/u otro fabricante.',
      sourceTitle: 'High-Sensitivity Cardiac Troponin T / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.decisionLimit},
    ),
    LabReferenceRecord(
      testId: 'ntp',
      canonicalNamePt: 'NT-proBNP',
      canonicalNameEs: 'NT-proBNP',
      categoryId: 'cardiac',
      unit: 'pg/mL',
      referenceIntervals: const [
        LabValueLine(labelPt: '0–2 d', labelEs: '0–2 d', value: '321–11.987'),
        LabValueLine(labelPt: '3–11 d', labelEs: '3–11 d', value: '263–5.918'),
        LabValueLine(labelPt: '2 m–1 a', labelEs: '2 m–1 a', value: '37–646'),
        LabValueLine(labelPt: '2 a', labelEs: '2 a', value: '39–413'),
        LabValueLine(labelPt: '3–6 a', labelEs: '3–6 a', value: '23–289'),
        LabValueLine(labelPt: '7–14 a', labelEs: '7–14 a', value: '≤157'),
        LabValueLine(labelPt: '15–18 a', labelEs: '15–18 a', value: '≤158'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'NT-proBNP / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'sg',
      canonicalNamePt: 'Densidade específica',
      canonicalNameEs: 'Densidad específica',
      categoryId: 'urine',
      unit: '',
      referenceIntervals: const [
        LabValueLine(labelPt: 'Representativo', labelEs: 'Representativo', value: '1,002–1,030'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Urine Specific Gravity / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'ph',
      canonicalNamePt: 'pH urinário',
      canonicalNameEs: 'pH urinario',
      categoryId: 'urine',
      unit: '',
      referenceIntervals: const [
        LabValueLine(labelPt: 'Aproximado', labelEs: 'Aproximado', value: '4,5–8,0'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Urine Specific Gravity / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'dip',
      canonicalNamePt: 'Fita reagente — esperado',
      canonicalNameEs: 'Tira reactiva — esperado',
      categoryId: 'urine',
      unit: '',
      referenceIntervals: const [
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
        'Glicose: negativa',
        'Cetonas: negativas',
        'Bilirrubina: negativa',
        'Sangue: negativo',
        'Nitrito: negativo',
        'Esterase leucocitária: negativa',
        'Proteína: negativa ou traço',
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Base clínica mestra agosto 2026',
      methodSpecific: false,
      statuses: {LabReferenceStatus.qualitative},
    ),
    LabReferenceRecord(
      testId: 'uosm',
      canonicalNamePt: 'Osmolalidade urinária',
      canonicalNameEs: 'Osmolalidad urinaria',
      categoryId: 'urine',
      unit: 'mOsm/kg',
      referenceIntervals: const [
        LabValueLine(labelPt: '0–11 m', labelEs: '0–11 m', value: '50–750'),
        LabValueLine(labelPt: '≥12 m', labelEs: '≥12 m', value: '150–1.150'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Osmolality, Random Urine / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'cacr',
      canonicalNamePt: 'Cálcio/creatinina urinária',
      canonicalNameEs: 'Calcio/creatinina urinaria',
      categoryId: 'urine',
      unit: 'mg/mg',
      referenceIntervals: const [
        LabValueLine(labelPt: '1–<12 m', labelEs: '1–<12 m', value: '0,03–0,81'),
        LabValueLine(labelPt: '12–24 m', labelEs: '12–24 m', value: '0,03–0,56'),
        LabValueLine(labelPt: '2–<3 a', labelEs: '2–<3 a', value: '0,02–0,50'),
        LabValueLine(labelPt: '3–<5 a', labelEs: '3–<5 a', value: '0,02–0,41'),
        LabValueLine(labelPt: '5–<7 a', labelEs: '5–<7 a', value: '0,01–0,30'),
        LabValueLine(labelPt: '7–<10 a', labelEs: '7–<10 a', value: '0,01–0,25'),
        LabValueLine(labelPt: '10–<18 a', labelEs: '10–<18 a', value: '0,01–0,24'),
        LabValueLine(labelPt: 'Adulto', labelEs: 'Adulto', value: '0,05–0,27'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Calcium/Creatinine Ratio, Random Urine / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'mgcr',
      canonicalNamePt: 'Magnésio/creatinina urinária',
      canonicalNameEs: 'Magnesio/creatinina urinaria',
      categoryId: 'urine',
      unit: 'mg/mg',
      referenceIntervals: const [
        LabValueLine(labelPt: '1–<12 m', labelEs: '1–<12 m', value: '0,10–0,48'),
        LabValueLine(labelPt: '12–24 m', labelEs: '12–24 m', value: '0,09–0,37'),
        LabValueLine(labelPt: '2–<3 a', labelEs: '2–<3 a', value: '0,07–0,34'),
        LabValueLine(labelPt: '3–<5 a', labelEs: '3–<5 a', value: '0,07–0,29'),
        LabValueLine(labelPt: '5–<7 a', labelEs: '5–<7 a', value: '0,06–0,21'),
        LabValueLine(labelPt: '7–<10 a', labelEs: '7–<10 a', value: '0,05–0,18'),
        LabValueLine(labelPt: '10–<14 a', labelEs: '10–<14 a', value: '0,05–0,15'),
        LabValueLine(labelPt: '14–<18 a', labelEs: '14–<18 a', value: '0,05–0,13'),
        LabValueLine(labelPt: 'Adulto', labelEs: 'Adulto', value: '0,04–0,12'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Magnesium/Creatinine Ratio, Random Urine / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'appearance',
      canonicalNamePt: 'Aspecto',
      canonicalNameEs: 'Aspecto',
      categoryId: 'csf',
      unit: '',
      referenceIntervals: const [
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
        'Límpido e incolor / claro e incoloro',
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Base clínica mestra agosto 2026',
      methodSpecific: false,
      statuses: {LabReferenceStatus.qualitative},
    ),
    LabReferenceRecord(
      testId: 'glucose',
      canonicalNamePt: 'Glicose no LCR',
      canonicalNameEs: 'Glucosa en LCR',
      categoryId: 'csf',
      unit: '',
      referenceIntervals: const [
      ],
      clinicalDecisionLimits: const [
        LabValueLine(labelPt: 'Relação usual', labelEs: 'Relación habitual', value: '≈60% da glicemia plasmática/sérica simultânea'),
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Glucose, Spinal Fluid / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.decisionLimit},
    ),
    LabReferenceRecord(
      testId: 'protein',
      canonicalNamePt: 'Proteína total no LCR',
      canonicalNameEs: 'Proteína total en LCR',
      categoryId: 'csf',
      unit: 'mg/dL',
      referenceIntervals: const [
        LabValueLine(labelPt: '≥12 meses', labelEs: '≥12 meses', value: '0–35'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '<12 meses: intervalo único não estabelecido no ensaio citado.',
      clinicalNotesEs: '<12 meses: intervalo único no establecido en el ensayo citado.',
      sourceTitle: 'Protein, Total, Spinal Fluid / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'lactate',
      canonicalNamePt: 'Lactato no LCR',
      canonicalNameEs: 'Lactato en LCR',
      categoryId: 'csf',
      unit: 'mmol/L',
      referenceIntervals: const [
        LabValueLine(labelPt: '0–2 d', labelEs: '0–2 d', value: '1,1–6,7'),
        LabValueLine(labelPt: '3–10 d', labelEs: '3–10 d', value: '1,1–4,4'),
        LabValueLine(labelPt: '11 d–17 a', labelEs: '11 d–17 a', value: '1,1–2,8'),
        LabValueLine(labelPt: '>17 a', labelEs: '>17 a', value: '1,1–2,4'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Lactic Acid, Spinal Fluid / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'ocb',
      canonicalNamePt: 'Bandas oligoclonais',
      canonicalNameEs: 'Bandas oligoclonales',
      categoryId: 'csf',
      unit: '',
      referenceIntervals: const [
      ],
      clinicalDecisionLimits: const [
        LabValueLine(labelPt: 'Negativo', labelEs: 'Negativo', value: '<2 bandas exclusivas do LCR'),
        LabValueLine(labelPt: 'Positivo', labelEs: 'Positivo', value: '≥2 bandas exclusivas do LCR'),
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Oligoclonal Banding, Serum and Spinal Fluid / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.decisionLimit},
    ),
    LabReferenceRecord(
      testId: 'igg',
      canonicalNamePt: 'Índice IgG / perfil adulto',
      canonicalNameEs: 'Índice IgG / perfil adulto',
      categoryId: 'csf',
      unit: '',
      referenceIntervals: const [
        LabValueLine(labelPt: 'Índice IgG', labelEs: 'Índice IgG', value: '0–0,70'),
        LabValueLine(labelPt: 'IgG LCR', labelEs: 'IgG LCR', value: '0–8,1 mg/dL'),
        LabValueLine(labelPt: 'Albumina LCR', labelEs: 'Albúmina LCR', value: '0–27 mg/dL'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Multiple Sclerosis Profile / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'syn',
      canonicalNamePt: 'Líquido sinovial',
      canonicalNameEs: 'Líquido sinovial',
      categoryId: 'body_fluids',
      unit: '',
      referenceIntervals: const [
        LabValueLine(labelPt: 'Células nucleadas totais', labelEs: 'Células nucleadas totales', value: '<150/µL'),
        LabValueLine(labelPt: 'Neutrófilos', labelEs: 'Neutrófilos', value: '<25%'),
        LabValueLine(labelPt: 'Linfócitos', labelEs: 'Linfocitos', value: '<75%'),
        LabValueLine(labelPt: 'Monócitos/macrófagos', labelEs: 'Monocitos/macrófagos', value: '≤70%'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Cell Count and Differential, Body Fluid / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'cavity',
      canonicalNamePt: 'Pleural / pericárdico / peritoneal',
      canonicalNameEs: 'Pleural / pericárdico / peritoneal',
      categoryId: 'body_fluids',
      unit: '',
      referenceIntervals: const [
        LabValueLine(labelPt: 'Células nucleadas totais', labelEs: 'Células nucleadas totales', value: '<500/µL'),
        LabValueLine(labelPt: 'Neutrófilos', labelEs: 'Neutrófilos', value: '<25%'),
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: '',
      clinicalNotesEs: '',
      sourceTitle: 'Cell Count and Differential, Body Fluid / Mayo Clinic Laboratories',
      methodSpecific: false,
      statuses: {LabReferenceStatus.ageSpecific},
    ),
    LabReferenceRecord(
      testId: 'overview',
      canonicalNamePt: 'Exames incluídos',
      canonicalNameEs: 'Estudios incluidos',
      categoryId: 'blood_gas',
      unit: '',
      referenceIntervals: const [
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: 'pH, pCO₂, pO₂, HCO₃⁻, excesso de base, saturação, lactato, carboxihemoglobina, metahemoglobina. A base fornecida não apresenta um intervalo numérico universal para este grupo; usar guideline/ensaio específico.',
      clinicalNotesEs: 'pH, pCO₂, pO₂, HCO₃⁻, excesso de base, saturação, lactato, carboxihemoglobina, metahemoglobina. La base proporcionada no presenta un intervalo numérico universal para este grupo; usar guía/ensayo específico.',
      sourceTitle: 'Base clínica mestra agosto 2026',
      methodSpecific: true,
      statuses: {LabReferenceStatus.methodSpecific, LabReferenceStatus.referenceNotEstablished},
    ),
    LabReferenceRecord(
      testId: 'overview',
      canonicalNamePt: 'Exames incluídos',
      canonicalNameEs: 'Estudios incluidos',
      categoryId: 'microbiology',
      unit: '',
      referenceIntervals: const [
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: 'hemocultura, urocultura, coprocultura, Gram, culturas, PCR, antibiograma, MIC/CIM. A base fornecida não apresenta um intervalo numérico universal para este grupo; usar guideline/ensaio específico.',
      clinicalNotesEs: 'hemocultura, urocultura, coprocultura, Gram, culturas, PCR, antibiograma, MIC/CIM. La base proporcionada no presenta un intervalo numérico universal para este grupo; usar guía/ensayo específico.',
      sourceTitle: 'Base clínica mestra agosto 2026',
      methodSpecific: true,
      statuses: {LabReferenceStatus.methodSpecific, LabReferenceStatus.referenceNotEstablished},
    ),
    LabReferenceRecord(
      testId: 'overview',
      canonicalNamePt: 'Exames incluídos',
      canonicalNameEs: 'Estudios incluidos',
      categoryId: 'serology',
      unit: '',
      referenceIntervals: const [
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: 'HIV, hepatites, CMV, EBV, toxoplasmose, sífilis, dengue, chikungunya, Chagas, HTLV, rubéola, sarampo, varicela, parvovírus B19, HSV. A base fornecida não apresenta um intervalo numérico universal para este grupo; usar guideline/ensaio específico.',
      clinicalNotesEs: 'HIV, hepatites, CMV, EBV, toxoplasmose, sífilis, dengue, chikungunya, Chagas, HTLV, rubéola, sarampo, varicela, parvovírus B19, HSV. La base proporcionada no presenta un intervalo numérico universal para este grupo; usar guía/ensayo específico.',
      sourceTitle: 'Base clínica mestra agosto 2026',
      methodSpecific: true,
      statuses: {LabReferenceStatus.methodSpecific, LabReferenceStatus.referenceNotEstablished},
    ),
    LabReferenceRecord(
      testId: 'overview',
      canonicalNamePt: 'Exames incluídos',
      canonicalNameEs: 'Estudios incluidos',
      categoryId: 'immunology',
      unit: '',
      referenceIntervals: const [
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: 'IgG, IgA, IgM, IgE, complemento, ANA, anti-dsDNA, ENA, ANCA, anti-CCP, fator reumatoide e outros autoanticorpos. A base fornecida não apresenta um intervalo numérico universal para este grupo; usar guideline/ensaio específico.',
      clinicalNotesEs: 'IgG, IgA, IgM, IgE, complemento, ANA, anti-dsDNA, ENA, ANCA, anti-CCP, fator reumatoide e outros autoanticorpos. La base proporcionada no presenta un intervalo numérico universal para este grupo; usar guía/ensayo específico.',
      sourceTitle: 'Base clínica mestra agosto 2026',
      methodSpecific: true,
      statuses: {LabReferenceStatus.methodSpecific, LabReferenceStatus.referenceNotEstablished},
    ),
    LabReferenceRecord(
      testId: 'overview',
      canonicalNamePt: 'Exames incluídos',
      canonicalNameEs: 'Estudios incluidos',
      categoryId: 'toxicology',
      unit: '',
      referenceIntervals: const [
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: 'paracetamol, salicilato, etanol, metanol, etilenoglicol, carboxihemoglobina e metahemoglobina. A base fornecida não apresenta um intervalo numérico universal para este grupo; usar guideline/ensaio específico.',
      clinicalNotesEs: 'paracetamol, salicilato, etanol, metanol, etilenoglicol, carboxihemoglobina e metahemoglobina. La base proporcionada no presenta un intervalo numérico universal para este grupo; usar guía/ensayo específico.',
      sourceTitle: 'Base clínica mestra agosto 2026',
      methodSpecific: true,
      statuses: {LabReferenceStatus.methodSpecific, LabReferenceStatus.referenceNotEstablished},
    ),
    LabReferenceRecord(
      testId: 'overview',
      canonicalNamePt: 'Exames incluídos',
      canonicalNameEs: 'Estudios incluidos',
      categoryId: 'therapeutic_monitoring',
      unit: '',
      referenceIntervals: const [
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: 'lítio, digoxina, valproato, carbamazepina, fenitoína, fenobarbital, vancomicina, aminoglicosídeos, tacrolimo, ciclosporina, sirolimo. A base fornecida não apresenta um intervalo numérico universal para este grupo; usar guideline/ensaio específico.',
      clinicalNotesEs: 'lítio, digoxina, valproato, carbamazepina, fenitoína, fenobarbital, vancomicina, aminoglicosídeos, tacrolimo, ciclosporina, sirolimo. La base proporcionada no presenta un intervalo numérico universal para este grupo; usar guía/ensayo específico.',
      sourceTitle: 'Base clínica mestra agosto 2026',
      methodSpecific: true,
      statuses: {LabReferenceStatus.methodSpecific, LabReferenceStatus.referenceNotEstablished},
    ),
    LabReferenceRecord(
      testId: 'overview',
      canonicalNamePt: 'Exames incluídos',
      canonicalNameEs: 'Estudios incluidos',
      categoryId: 'oncology',
      unit: '',
      referenceIntervals: const [
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: 'PSA, AFP, β-hCG, CEA, CA 19-9, CA-125, CA 15-3, calcitonina, tireoglobulina, cromogranina A, β2-microglobulina. A base fornecida não apresenta um intervalo numérico universal para este grupo; usar guideline/ensaio específico.',
      clinicalNotesEs: 'PSA, AFP, β-hCG, CEA, CA 19-9, CA-125, CA 15-3, calcitonina, tireoglobulina, cromogranina A, β2-microglobulina. La base proporcionada no presenta un intervalo numérico universal para este grupo; usar guía/ensayo específico.',
      sourceTitle: 'Base clínica mestra agosto 2026',
      methodSpecific: true,
      statuses: {LabReferenceStatus.methodSpecific, LabReferenceStatus.referenceNotEstablished},
    ),
    LabReferenceRecord(
      testId: 'overview',
      canonicalNamePt: 'Exames incluídos',
      canonicalNameEs: 'Estudios incluidos',
      categoryId: 'stool',
      unit: '',
      referenceIntervals: const [
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: 'sangue oculto, parasitas, coprocultura, C. difficile, calprotectina, elastase, gordura fecal, leucócitos. A base fornecida não apresenta um intervalo numérico universal para este grupo; usar guideline/ensaio específico.',
      clinicalNotesEs: 'sangue oculto, parasitas, coprocultura, C. difficile, calprotectina, elastase, gordura fecal, leucócitos. La base proporcionada no presenta un intervalo numérico universal para este grupo; usar guía/ensayo específico.',
      sourceTitle: 'Base clínica mestra agosto 2026',
      methodSpecific: true,
      statuses: {LabReferenceStatus.methodSpecific, LabReferenceStatus.referenceNotEstablished},
    ),
    LabReferenceRecord(
      testId: 'overview',
      canonicalNamePt: 'Exames incluídos',
      canonicalNameEs: 'Estudios incluidos',
      categoryId: 'reproduction',
      unit: '',
      referenceIntervals: const [
      ],
      clinicalDecisionLimits: const [
      ],
      criticalValues: const [
      ],
      qualitativeValues: const [
      ],
      clinicalNotesPt: 'β-hCG, hormônios reprodutivos e espermograma. A base fornecida não apresenta um intervalo numérico universal para este grupo; usar guideline/ensaio específico.',
      clinicalNotesEs: 'β-hCG, hormônios reprodutivos e espermograma. La base proporcionada no presenta un intervalo numérico universal para este grupo; usar guía/ensayo específico.',
      sourceTitle: 'Base clínica mestra agosto 2026',
      methodSpecific: true,
      statuses: {LabReferenceStatus.methodSpecific, LabReferenceStatus.referenceNotEstablished},
    ),
  ];

  static List<LabReferenceRecord> recordsForCategory(String id) =>
      records.where((record) => record.categoryId == id).toList(growable: false);

  static int countForCategory(String id) =>
      records.where((record) => record.categoryId == id).length;
}
