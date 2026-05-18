// drug_interaction_service.dart — Detecção de interações medicamentosas
// Base de dados embutida (offline, sem API externa)
// Fontes: Goodman & Gilman 14ª ed., Katzung 15ª ed., Micromedex, UpToDate,
//         Lexicomp, Harrison's, FDA Drug Labels, ESC/AHA/IDSA guidelines

// ─────────────────────────────────────────────────────────────────────────────
// ENUMERAÇÕES DO SISTEMA DE INTERAÇÕES
// ─────────────────────────────────────────────────────────────────────────────

/// Severidade da interação (5 níveis clínicos)
enum InteractionSeverity {
  contraindicated, // CONTRAINDICADA — não utilizar juntos em nenhuma circunstância
  major,           // GRAVE / ALTO RISCO — risco clínico grave, evitar combinação
  moderate,        // MODERADA — monitorar com atenção, ajuste de dose possível
  minor,           // LEVE — relevância clínica baixa, vigilância simples
  monitorOnly,     // SÓ MONITORIZAR — interação teórica/leve, vigilância periódica
}

/// Nível de evidência científica da interação
enum EvidenceLevel {
  established,  // Estabelecida — documentada em múltiplos estudos clínicos controlados
  probable,     // Provável — evidência consistente mas limitada ou de estudos menores
  possible,     // Possível — baseada em relatos de caso ou mecanismo farmacológico plausível
  theoretical,  // Teórica — baseada em farmacodinâmica/cinética, sem confirmação clínica direta
}

/// Tipos de risco clínico envolvidos na interação
enum RiskType {
  qtProlongation,        // Prolongamento do intervalo QT / Torsades de Pointes
  hemorrhagic,           // Risco hemorrágico / sangrado
  arrhythmia,            // Arritmia cardíaca (não-QT)
  respiratoryDepression, // Depressão respiratória / apneia
  serotonin,             // Síndrome serotoninérgica
  nephrotoxicity,        // Nefrotoxicidad / lesão renal aguda
  hepatotoxicity,        // Hepatotoxicidad / lesão hepática
  plasmaLevel,           // Alteração de niveles plasmáticos (CYP/P-gp)
  cardiovascular,        // Hipotensão, bradicardia, colapso hemodinâmico
  reducedEfficacy,       // Redução de eficácia terapéutica
  increasedToxicity,     // Aumento de toxicidad do fármaco
  hypoglycemia,          // Hipoglucemia
  hyperkalemia,          // Hipercalemia
  hypokalemia,           // Hipocalemia
  cns,                   // Depressão do SNC / sedação excessiva
  myopathy,              // Miopatia / rabdomiólisis
  myelosuppression,      // Mielossupressão / citopenia
  infection,             // Risco aumentado de infecções
  thrombosis,            // Risco tromboembólico
  electrolyte,           // Distúrbio eletrolítico (hipo/hiperpotasemia, hipomagnesemia, etc.)
  seizure,               // Risco convulsivo / rebaixamento do limiar convulsivo
  ototoxicity,           // Ototoxicidad / perda auditiva
  other,                 // Outro risco clínico relevante
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELO DE INTERAÇÃO EXPANDIDO
// ─────────────────────────────────────────────────────────────────────────────

/// Resultado completo de uma interação medicamentosa detectada
class DrugInteraction {
  final String drug1;                // Nome do fármaco 1 (para exibição)
  final String drug2;                // Nome do fármaco 2 (para exibição)
  final InteractionSeverity severity;
  final String mechanism;            // Mecanismo farmacológico da interação
  final String effect;               // Efeito clínico resultante
  final String management;           // Conduta recomendada
  final String clinicalAlert;        // Mensagem objetiva de alerta visual
  final EvidenceLevel evidenceLevel; // Nível de evidência científica
  final Set<RiskType> riskTypes;     // Tipos de risco clínico envolvidos
  final List<String> references;     // Fontes bibliográficas

  const DrugInteraction({
    required this.drug1,
    required this.drug2,
    required this.severity,
    required this.mechanism,
    required this.effect,
    required this.management,
    required this.clinicalAlert,
    required this.evidenceLevel,
    required this.riskTypes,
    required this.references,
  });

  /// Rótulo curto da severidade
  /// Badge de severidade — bilíngue (padrão: es quando isEs=true)
  String get severityLabel {
    switch (severity) {
      case InteractionSeverity.contraindicated: return 'CONTRAINDICADA';
      case InteractionSeverity.major:           return 'GRAVE';
      case InteractionSeverity.moderate:        return 'MODERADA';
      case InteractionSeverity.minor:           return 'LEVE';
      case InteractionSeverity.monitorOnly:     return 'MONITORAR';
    }
  }

  String severityLabelL10n({bool isEs = true}) {
    switch (severity) {
      case InteractionSeverity.contraindicated: return 'CONTRAINDICADA';
      case InteractionSeverity.major:           return isEs ? 'GRAVE'      : 'GRAVE';
      case InteractionSeverity.moderate:        return isEs ? 'MODERADA'   : 'MODERADA';
      case InteractionSeverity.minor:           return isEs ? 'LEVE'       : 'LEVE';
      case InteractionSeverity.monitorOnly:     return isEs ? 'MONITOREAR' : 'MONITORAR';
    }
  }

  /// Rótulo longo da severidade — bilíngue
  String severityLongLabel({bool isEs = true}) {
    switch (severity) {
      case InteractionSeverity.contraindicated:
        return isEs ? 'CONTRAINDICADA — NO UTILIZAR JUNTOS' : 'CONTRAINDICADA — NO UTILIZAR JUNTOS';
      case InteractionSeverity.major:
        return isEs ? 'GRAVE — ALTO RIESGO'                : 'GRAVE — ALTO RISCO';
      case InteractionSeverity.moderate:
        return isEs ? 'MODERADA — MONITOREAR'              : 'MODERADA — MONITORAR';
      case InteractionSeverity.minor:
        return isEs ? 'LEVE — VIGILANCIA'                  : 'LEVE — VIGILÂNCIA';
      case InteractionSeverity.monitorOnly:
        return isEs ? 'SOLO MONITORIZAR'                   : 'SÓ MONITORIZAR';
    }
  }

  /// Rótulo do nível de evidência — bilíngue
  String evidenceLabel({bool isEs = true}) {
    switch (evidenceLevel) {
      case EvidenceLevel.established:  return isEs ? 'ESTABLECIDA'  : 'ESTABELECIDA';
      case EvidenceLevel.probable:     return isEs ? 'PROBABLE'     : 'PROVÁVEL';
      case EvidenceLevel.possible:     return isEs ? 'POSIBLE'      : 'POSSÍVEL';
      case EvidenceLevel.theoretical:  return isEs ? 'TEÓRICA'      : 'TEÓRICA';
    }
  }

  /// Rótulo legível de cada tipo de risco — bilíngue
  static String riskTypeLabel(RiskType r, {bool isEs = true}) {
    switch (r) {
      case RiskType.qtProlongation:        return '↑QT';
      case RiskType.hemorrhagic:           return isEs ? 'Hemorrágico'      : 'Hemorrágico';
      case RiskType.arrhythmia:            return isEs ? 'Arritmia'         : 'Arritmia';
      case RiskType.respiratoryDepression: return isEs ? 'Dep. Resp.'       : 'Dep. Resp.';
      case RiskType.serotonin:             return isEs ? 'Serotonina'       : 'Serotonina';
      case RiskType.nephrotoxicity:        return isEs ? 'Nefrotóxico'      : 'Nefrotóxico';
      case RiskType.hepatotoxicity:        return isEs ? 'Hepatotóxico'     : 'Hepatotóxico';
      case RiskType.plasmaLevel:           return isEs ? 'Nivel Plasmático' : 'Nível Plasmático';
      case RiskType.cardiovascular:        return 'Cardiovascular';
      case RiskType.reducedEfficacy:       return isEs ? 'Eficacia ↓'       : 'Eficácia ↓';
      case RiskType.increasedToxicity:     return isEs ? 'Toxicidad ↑'      : 'Toxicidade ↑';
      case RiskType.hypoglycemia:          return isEs ? 'Hipoglucemia'     : 'Hipoglucemia';
      case RiskType.hyperkalemia:          return isEs ? 'Hiperpotasemia'   : 'Hipercalemia';
      case RiskType.hypokalemia:           return isEs ? 'Hipopotasemia'    : 'Hipocalemia';
      case RiskType.cns:                   return isEs ? 'Depresión SNC'    : 'Depressão SNC';
      case RiskType.myopathy:              return isEs ? 'Miopatía'         : 'Miopatia';
      case RiskType.myelosuppression:      return isEs ? 'Mielosupresión'   : 'Mielossupressão';
      case RiskType.infection:             return isEs ? 'Infección'        : 'Infecção';
      case RiskType.thrombosis:            return isEs ? 'Trombosis'        : 'Trombose';
      case RiskType.electrolyte:           return isEs ? 'Electrolitos'     : 'Eletrólitos';
      case RiskType.seizure:               return isEs ? 'Convulsión'       : 'Convulsão';
      case RiskType.ototoxicity:           return isEs ? 'Ototóxico'        : 'Ototóxico';
      case RiskType.other:                 return isEs ? 'Otro'             : 'Outro';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BANCO DE INTERAÇÕES (termos normalizados para busca)
// Cada entrada: (id1, id2, severity, mechanism, effect, management,
//                clinicalAlert, evidenceLevel, {riskTypes}, [references])
// ─────────────────────────────────────────────────────────────────────────────
const _kRefGG   = 'Goodman & Gilman 13ª ed.';
const _kRefKatz = 'Katzung 13ª ed.';
const _kRefMdx  = 'Micromedex 2024';
const _kRefUT   = 'UpToDate 2024';
const _kRefLex  = 'Lexicomp 2024';
const _kRefFDA  = 'FDA Drug Label';

typedef _IxEntry = (
  String, String, InteractionSeverity,
  String, String, String,          // mechanism, effect, management
  String,                          // clinicalAlert
  EvidenceLevel,
  Set<RiskType>,
  List<String>,                    // references
);

const _interactionDB = <_IxEntry>[

  // ── AINES / Anticoagulantes ───────────────────────────────────────────────

  ('warfarina', 'aspirina', InteractionSeverity.major,
    'Inhibición plaquetaria aditiva + desplazamiento proteico aumentando INR',
    'Riesgo aumentado de sangrado grave (GI, intracraneal)',
    'Evitar combinación. Si necesario, usar dosis mínima de AAS (≤100 mg/día) con INR ≤2,5 y monitoreo frecuente',
    'ALTO RIESGO DE SANGRADO — Evitar combinación',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),

  ('warfarina', 'ibuprofeno', InteractionSeverity.major,
    'Desplazamiento de la unión proteica e inhibición plaquetaria',
    'Elevación del INR y riesgo de sangrado',
    'Evitar. Preferir paracetamol como analgésico. Monitorar INR si inevitable',
    'ALTO RIESGO DE SANGRADO — Use paracetamol',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),

  ('warfarina', 'naproxeno', InteractionSeverity.major,
    'Desplazamiento de la unión proteica e inhibición plaquetaria',
    'Elevación del INR y riesgo de sangrado',
    'Evitar. Preferir paracetamol como analgésico. Monitorar INR si inevitable',
    'ALTO RIESGO DE SANGRADO — Use paracetamol',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),

  ('warfarina', 'cetorolaco', InteractionSeverity.major,
    'AINE potente con efecto anticoagulante aditivo',
    'Riesgo hemorrágico grave — combinación peligrosa',
    'Contraindicado. Usar analgésico alternativo',
    'ALTO RIESGO HEMORRÁGICO — Contraindicado',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefMdx, _kRefFDA]),

  ('warfarina', 'metronidazol', InteractionSeverity.major,
    'Inhibición del CYP2C9 reduce metabolismo de warfarina',
    'Aumento significativo del INR → riesgo de hemorragia',
    'Monitorar INR cada 2–3 días. Reducir dosis de warfarina en ~25–50%',
    'MONITORAR INR — Riesgo de hemorragia por aumento de nivel',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),

  ('warfarina', 'fluconazol', InteractionSeverity.major,
    'Inhibición potente del CYP2C9 y CYP3A4',
    'Elevación marcada del INR con riesgo hemorrágico grave',
    'Reducir dosis de warfarina 25–50%. Monitorar INR diariamente los primeros 3–5 días',
    'ALTO RIESGO HEMORRÁGICO — Reducir warfarina y monitorar INR',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefLex]),

  ('warfarina', 'amiodarona', InteractionSeverity.major,
    'Inhibición del CYP2C9 (metabolizador de warfarina S) por amiodarona y sus metabolitos',
    'Elevación progresiva del INR — el efecto puede durar semanas después de suspender amiodarona',
    'Reducir dosis de warfarina 30–50%. Monitorar INR semanalmente. El efecto persiste meses',
    'RIESGO HEMORRÁGICO PROLONGADO — El efecto persiste semanas después de suspender amiodarona',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),

  ('warfarina', 'ciprofloxacino', InteractionSeverity.moderate,
    'Inhibición del CYP1A2 y posible reducción de la flora intestinal productora de vitamina K',
    'Elevación del INR',
    'Monitorar INR 2–3 días después del inicio y 2–3 días después del fin del antibiótico',
    'Requiere monitorización de INR durante el tratamiento',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),

    // ── Estatinas ─────────────────────────────────────────────────────────────

  ('sinvastatina', 'amiodarona', InteractionSeverity.major,
    'Inhibición del CYP3A4 aumenta concentración de simvastatina',
    'Riesgo de miopatía / rabdomiólisis',
    'Dose máxima de sinvastatina: 20 mg/dia com amiodarona. Preferir rosuvastatina ou pravastatina',
    'RIESGO DE RABDOMIÓLISIS — Limitar simvastatina a 20 mg/día',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefFDA]),

  ('sinvastatina', 'claritromicina', InteractionSeverity.major,
    'Inhibición potente del CYP3A4',
    'Riesgo de rabdomiólisis',
    'Suspender simvastatina durante el curso de claritromicina. Alternativa: azitromicina',
    'RIESGO DE RABDOMIÓLISIS — Suspender simvastatina',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefFDA]),

  ('sinvastatina', 'eritromicina', InteractionSeverity.major,
    'Inhibición del CYP3A4',
    'Riesgo de miopatía/rabdomiólisis',
    'Suspender simvastatina durante el curso. Alternativa: azitromicina',
    'RIESGO DE RABDOMIÓLISIS — Suspender simvastatina',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefMdx, _kRefFDA]),
    // DUPLICATA REMOVIDA: sinvastatina+fluconazol — par detalhado mantido como fluconazol+sinvastatina (linha ~1654)

  ('atorvastatina', 'claritromicina', InteractionSeverity.moderate,
    'Inhibición del CYP3A4 aumenta nível de atorvastatina',
    'Riesgo aumentado de miopatía',
    'Reduzir dose de atorvastatina. Preferir azitromicina',
    'Requiere monitorización — riesgo de miopatía',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),

  ('atorvastatina', 'amiodarona', InteractionSeverity.moderate,
    'Inhibición del CYP3A4',
    'Riesgo de miopatía',
    'Limitar atorvastatina a 40 mg/dia. Monitorar CPK y síntomas musculares',
    'Requiere monitorización clínica — limitar dosis de estatina',
    EvidenceLevel.probable,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefMdx, _kRefLex]),

    // ── IECA / ARA-II / Diuréticos ────────────────────────────────────────────

  ('enalapril', 'espironolactona', InteractionSeverity.moderate,
    'Ambos elevan potasio sérico por mecanismos distintos',
    'Hiperpotasemia, especialmente en ERC o insuficiencia cardíaca',
    'Monitorar K+ sérico y función renal semanalmente al inicio; reducir dosis de espironolactona si K+ >5,5 mEq/L',
    'Requiere monitorización de potasio sérico',
    EvidenceLevel.established,
    {RiskType.hyperkalemia},
    [_kRefGG, _kRefUT]),

  ('losartana', 'espironolactona', InteractionSeverity.moderate,
    'Ambos elevan potasio sérico',
    'Hiperpotasemia — más frecuente en IRC/ICF',
    'Monitorar K+ sérico y creatinina regularmente',
    'Requiere monitorización de potasio sérico',
    EvidenceLevel.established,
    {RiskType.hyperkalemia},
    [_kRefGG, _kRefUT]),

  ('enalapril', 'alisquireno', InteractionSeverity.contraindicated,
    'Doble bloqueo del SRAA',
    'Hipotensión grave, hiperpotasemia e insuficiencia renal aguda',
    'Combinação contraindicada por guidelines (ESC 2016, JNC)',
    'NO UTILIZAR — Contraindicado por guías internacionales',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.hyperkalemia, RiskType.nephrotoxicity},
    [_kRefGG, _kRefFDA, _kRefUT]),

  ('losartana', 'alisquireno', InteractionSeverity.contraindicated,
    'Doble bloqueo del SRAA',
    'Hipotensión grave, hiperpotasemia e insuficiencia renal aguda',
    'Combinação contraindicada — evitar em qualquer paciente',
    'NO UTILIZAR — Contraindicado por guías internacionales',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.hyperkalemia, RiskType.nephrotoxicity},
    [_kRefGG, _kRefFDA]),

    // ── IECA + ARA-II (bloqueio duplo do SRAA) ───────────────────────────────

  ('enalapril', 'losartana', InteractionSeverity.contraindicated,
    'Doble bloqueo del SRAA: inibição simultânea da ECA e do receptor AT1 da angiotensina II — sem benefício adicional, com risco multiplicado',
    'Hipotensión sintomática grave, hiperpotasemia potencialmente fatal, insuficiencia renal aguda (estudio ONTARGET)',
    'CONTRAINDICADO — No combinar IECA + ARA-II. Elegir uno de los dos. Excepción restringida: cardiólogo experto en IC refractaria con monitorización intensiva',
    'DOBLE BLOQUEO DEL SRAA — Contraindicado por ESC/AHA. Estudio ONTARGET demostró perjuicio sin beneficio',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.hyperkalemia, RiskType.nephrotoxicity},
    [_kRefGG, _kRefUT, _kRefFDA]),


  ('enalapril', 'aine', InteractionSeverity.moderate,
    'AINEs reducen síntesis de prostaglandinas vasodilatadoras renales',
    'Redução do efeito anti-hipertensivo do IECA; risco de IRA',
    'Evitar uso crónico concomitante. Si necesario, monitorar PA y función renal',
    'Requiere monitorización clínica/laboratorial — riesgo renal',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.cardiovascular},
    [_kRefGG, _kRefUT]),

    // ── Betabloqueadores ──────────────────────────────────────────────────────

  ('metoprolol', 'verapamil', InteractionSeverity.major,
    'Efecto aditivo de ambos en el nodo AV (cronotropismo y dromotropismo negativos)',
    'Bradicardia grave, bloqueo AV completo, hipotensión, ICC',
    'Contraindicado en la mayoría de situaciones. Si inevitable, monitorar con ECG continuo',
    'ALTO RIESGO CARDIOVASCULAR — Evitar combinación',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx, _kRefUT]),

  ('metoprolol', 'diltiazem', InteractionSeverity.major,
    'Efecto aditivo en el nodo sinusal y AV',
    'Bradicardia, bloqueo AV, hipotensión',
    'Evitar combinación. Si necesario, iniciar con dosis muy bajas y monitorar ECG',
    'ALTO RIESGO CARDIOVASCULAR — Monitorar ECG continuamente',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),

  ('propranolol', 'verapamil', InteractionSeverity.major,
    'Efeito aditivo no nó AV',
    'Bradicardia grave, bloqueo AV, paro cardíaco (reportes)',
    'Contraindicado — alternativa: usar solo uno de ellos',
    'ALTO RIESGO DE PARO CARDÍACO — Contraindicado',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx, _kRefFDA]),

  ('metoprolol', 'clonidina', InteractionSeverity.moderate,
    'La retirada abrupta de clonidina con betabloqueador causa hipertensión de rebote grave',
    'Crisis hipertensiva de rebote al suspender clonidina',
    'Nunca suspender clonidina abruptamente; si se suspende, retirar betabloqueador primero',
    'Requiere monitorización — Nunca suspender clonidina abruptamente',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    [_kRefGG, _kRefUT]),

    // ── Antiarrítmicos ────────────────────────────────────────────────────────

  ('amiodarona', 'sotalol', InteractionSeverity.contraindicated,
    'Prolongación aditiva del intervalo QT',
    'Torsades de Pointes, fibrilación ventricular, muerte súbita',
    'Contraindicado — nunca combinar antiarrítmicos que prolongan QT',
    'NO UTILIZAR ESTOS FÁRMACOS JUNTOS — Riesgo de muerte súbita',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx, _kRefFDA]),

  ('amiodarona', 'haloperidol', InteractionSeverity.major,
    'Prolongación aditiva del QT',
    'Torsades de Pointes',
    'Evitar. Si necesario, monitorar QTc con ECG regular',
    'ALTO RIESGO DE TORSADES DE POINTES — Monitorar QTc',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefMdx, _kRefUT]),

  ('amiodarona', 'digoxina', InteractionSeverity.major,
    'Inhibición de la P-glucoproteína aumenta nivel sérico de digoxina',
    'Toxicidad digitálica — náuseas, bradicardia, trastornos visuales',
    'Reducir dosis de digoxina 50%. Monitorar nivel sérico y ECG',
    'ALTO RIESGO DE TOXICIDAD DIGITÁLICA — Reducir dosis de digoxina 50%',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.cardiovascular},
    [_kRefGG, _kRefMdx, _kRefUT]),

  ('digoxina', 'furosemida', InteractionSeverity.moderate,
    'Furosemida causa hipopotasemia que potencializa toxicidad de digoxina',
    'Arritmias por toxicidad digitálica facilitadas por hipopotasemia',
    'Monitorar K+ sérico; repor potássio se <4 mEq/L; dosar digoxina se suspeita de toxicidad',
    'Requiere monitorización de K+ sérico e nível de digoxina',
    EvidenceLevel.established,
    {RiskType.hypokalemia, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),

  ('digoxina', 'espironolactona', InteractionSeverity.moderate,
    'Espironolactona puede elevar nivel sérico de digoxina (inhibición de la secreción tubular)',
    'Toxicidad digitálica aumentada',
    'Monitorar nivel sérico de digoxina após introdução de espironolactona',
    'Requiere monitorización de nivel sérico de digoxina',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel, RiskType.arrhythmia},
    [_kRefMdx, _kRefLex]),

    // ── Antibióticos ──────────────────────────────────────────────────────────

  ('metronidazol', 'alcool', InteractionSeverity.contraindicated,
    'Inhibición de la aldehído deshidrogenasa — reacción tipo disulfiram',
    'Flushing, náuseas, vómitos, cefalea, taquicardia, hipotensión',
    'Contraindicado alcohol durante el uso y por 48h después del fin del metronidazol',
    'NO UTILIZAR — Prohibido alcohol durante y 48h después del metronidazol',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    [_kRefGG, _kRefFDA]),

  ('quinolona', 'antiácido', InteractionSeverity.moderate,
    'Cationes divalentes (Al, Mg, Ca) quelan quinolonas en el TGI',
    'Reducción del 50–90% en la absorción oral de la quinolona',
    'Administrar quinolona 2h antes o 6h después del antiácido/suplemento de calcio/hierro',
    'Requiere intervalo de 2–6h entre administraciones',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefFDA]),

  ('ciprofloxacino', 'teofilina', InteractionSeverity.major,
    'Inhibición del CYP1A2 reduce metabolismo de teofilina',
    'Toxicidad por teofilina — náuseas, convulsiones, arritmias',
    'Reducir dosis de teofilina 30–50%. Monitorar nivel sérico de teofilina',
    'ALTO RIESGO DE TOXICIDAD — Monitorar nivel sérico de teofilina',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx, _kRefFDA]),

  ('claritromicina', 'estatina', InteractionSeverity.major,
    'Inhibición del CYP3A4 eleva concentração plasmática de estatinas metabolizadas por esse CYP',
    'Riesgo de miopatía/rabdomiólisis',
    'Suspender estatina durante el curso de claritromicina. Alternativa: azitromicina',
    'RIESGO DE RABDOMIÓLISIS — Suspender estatina durante claritromicina',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefFDA]),

  ('rifampicina', 'warfarina', InteractionSeverity.major,
    'Inducción potente del CYP2C9 — aumenta metabolismo de warfarina',
    'Reducción marcada del efecto anticoagulante (INR puede caer >50%)',
    'Monitorar INR diariamente al inicio y al final. Aumentar dosis de warfarina significativamente',
    'ALTO RIESGO DE FALLO ANTICOAGULANTE — Monitorar INR diariamente',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel, RiskType.thrombosis},
    [_kRefGG, _kRefMdx, _kRefUT]),

    // ── Psicotrópicos / SNC ───────────────────────────────────────────────────

  ('tramadol', 'isrs', InteractionSeverity.major,
    'Inhibición de la recaptación serotoninérgica sumada',
    'Síndrome serotoninérgica — agitación, hipertermia, mioclonía, taquicardia',
    'Evitar combinación. Si indispensable, iniciar con dosis baja de tramadol y monitorar por 24–48h',
    'ALTO RIESGO DE SÍNDROME SEROTONINÉRGICA — Evitar combinación',
    EvidenceLevel.established,
    {RiskType.serotonin},
    [_kRefGG, _kRefMdx, _kRefFDA]),

  ('tramadol', 'imao', InteractionSeverity.contraindicated,
    'Potenciación serotoninérgica extrema',
    'Síndrome serotoninérgica grave con riesgo de muerte',
    'Contraindicado — esperar 14 días después de suspender IMAO antes de usar tramadol',
    'NO UTILIZAR ESTOS FÁRMACOS JUNTOS — Riesgo de muerte',
    EvidenceLevel.established,
    {RiskType.serotonin},
    [_kRefGG, _kRefFDA, _kRefMdx]),

  ('tramadol', 'morfina', InteractionSeverity.moderate,
    'Efectos aditivos en el SNC y depresión respiratoria',
    'Sedación excesiva, depresión respiratoria',
    'Usar com cautela. Monitorar nivel de consciencia y función respiratoria',
    'Requiere monitorización clínica — depresión respiratoria aditiva',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns},
    [_kRefGG, _kRefMdx]),

  ('benzodiazepínico', 'opioide', InteractionSeverity.contraindicated,
    'Depresión aditiva del SNC — sinergia respiratoria y sedativa',
    'Depresión respiratoria grave, coma, muerte (alerta FDA/ANVISA)',
    'Evitar combinación. Se essencial (ICU/paliativo), monitorar com oximetria contínua; ter naloxona disponible',
    'ALTO RIESGO DE DEPRESIÓN RESPIRATORIA — FDA Black Box Warning',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns},
    [_kRefFDA, _kRefGG, _kRefMdx]),

  ('haloperidol', 'carbonato de litio', InteractionSeverity.moderate,
    'Posible potenciación neurotóxica; el litio puede alterar la farmacocinética del haloperidol',
    'Neurotoxicidad aumentada — confusión, temblor, extrapiramidal exacerbado',
    'Monitorar litio sérico, ECG y signos neurológicos',
    'Requiere monitorización clínica/laboratorial — neurotoxicidad',
    EvidenceLevel.probable,
    {RiskType.cns, RiskType.qtProlongation},
    [_kRefMdx, _kRefUT]),

  ('isrs', 'imao', InteractionSeverity.contraindicated,
    'Hiperestimulación serotoninérgica extrema',
    'Síndrome serotoninérgica grave — hiperpirexia, convulsiones, colapso cardiovascular, muerte',
    'Contraindicado. Esperar 14 días después de suspender IMAO (o 5 semanas para fluoxetina) antes de iniciar SSRI',
    'NO UTILIZAR ESTOS FÁRMACOS JUNTOS — Síndrome serotoninérgica fatal',
    EvidenceLevel.established,
    {RiskType.serotonin},
    [_kRefGG, _kRefFDA, _kRefMdx]),

    // ── Hipoglucemiantes ──────────────────────────────────────────────────────

  ('metformina', 'contraste iodado', InteractionSeverity.major,
    'El contraste yodado puede causar IRA transitoria → acumulación de metformina → acidosis láctica',
    'Acidosis láctica (rara pero grave)',
    'Suspender metformina 48h antes del contraste en pacientes con ERC (TFG <60). Reintroducir tras 48h si la función renal es estable',
    'ALTO RIESGO — Suspender metformina 48h antes del contraste',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx, _kRefFDA]),

  ('glibenclamida', 'fluconazol', InteractionSeverity.major,
    'Inhibición del CYP2C9 aumenta nivel sérico de glibenclamida',
    'Hipoglucemia grave y prolongada',
    'Evitar. Se necesario, monitorar glucemia intensivamente e reduzir dose de glibenclamida',
    'ALTO RIESGO DE HIPOGLUCEMIA GRAVE — Monitorar glucemia intensivamente',
    EvidenceLevel.established,
    {RiskType.hypoglycemia, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),

  ('insulina', 'betabloqueador', InteractionSeverity.moderate,
    'Los betabloqueadores enmascaran taquicardia y temblor (síntomas adrenérgicos de hipoglucemia)',
    'La hipoglucemia puede pasar desapercibida — solo la sudoración persiste como signo',
    'Preferir betabloqueadores cardiosseletivos. Orientar o paciente. Monitorar glucemia más frecuentemente',
    'Requiere monitorización — signos de hipoglucemia enmascarados',
    EvidenceLevel.established,
    {RiskType.hypoglycemia},
    [_kRefGG, _kRefKatz]),

    // ── Imunossupressores ─────────────────────────────────────────────────────

  ('ciclosporina', 'fluconazol', InteractionSeverity.major,
    'Inhibición del CYP3A4 eleva nivel sérico de ciclosporina',
    'Nefrotoxicidad e inmunosupresión excesiva',
    'Reducir dosis de ciclosporina 50% y monitorar nivel sérico diariamente',
    'ALTO RIESGO DE NEFROTOXICIDAD — Monitorar nivel sérico diariamente',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefLex]),

  ('ciclosporina', 'claritromicina', InteractionSeverity.major,
    'Inhibición del CYP3A4 e P-gp',
    'Aumento del nivel sérico de ciclosporina — nefrotoxicidad',
    'Reducir dosis de ciclosporina; monitorar nivel sérico frecuentemente',
    'ALTO RIESGO DE NEFROTOXICIDAD — Monitorar nivel sérico diariamente',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.plasmaLevel},
    [_kRefMdx, _kRefLex]),

    // ── Cardiovascular / Miscellaneous ────────────────────────────────────────

  ('atorvastatina', 'gemfibrozil', InteractionSeverity.major,
    'Inhibición de la glucuronidación de atorvastatina por gemfibrozil',
    'Riesgo significativo de miopatía/rabdomiólisis',
    'Evitar combinación. Si necesario usar fibratos, preferir fenofibrato + estatina',
    'ALTO RIESGO DE RABDOMIÓLISIS — Evitar combinación',
    EvidenceLevel.established,
    {RiskType.myopathy},
    [_kRefGG, _kRefMdx, _kRefFDA]),

  ('sildenafila', 'nitrato', InteractionSeverity.contraindicated,
    'Ambos potencializan vasodilatación vía GMPc',
    'Hipotensión grave, shock cardiovascular, colapso hemodinámico, muerte',
    'Contraindicado absolutamente. Esperar ≥24h después de sildenafil (≥48h para tadalafil) para administrar nitrato',
    'NO UTILIZAR ESTOS FÁRMACOS JUNTOS — Hipotensión fatal',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    [_kRefGG, _kRefFDA, _kRefMdx]),

  ('sildenafila', 'alfa-bloqueador', InteractionSeverity.major,
    'Efecto hipotensor aditivo',
    'Hipotensión sintomática grave — mareo, síncope',
    'Iniciar alfa-bloqueador con dosis baja. Esperar estabilización antes de asociar. Orientar al paciente',
    'ALTO RISCO DE HIPOTENSÃO GRAVE — Iniciar com doses baixas',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    [_kRefGG, _kRefFDA]),

  ('furosemida', 'aminoglicosideo', InteractionSeverity.major,
    'Ototoxicidad aditiva sinérgica',
    'Sordera neurosensorial permanente — riesgo aumentado especialmente en ERC',
    'Evitar combinación. Se necesario, minimizar dose e duração; monitorar função auditiva',
    'ALTO RIESGO DE SORDERA IRREVERSIBLE — Evitar combinación',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx]),

  ('furosemida', 'aine', InteractionSeverity.moderate,
    'AINEs inhiben síntesis de prostaglandinas renales vasodilatadoras',
    'Reducción del efecto diurético; riesgo de IRA',
    'Evitar AINEs en pacientes que usan furosemida, especialmente en ICC/ERC',
    'Requiere monitorización clínica/laboratorial — riesgo renal',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.reducedEfficacy},
    [_kRefGG, _kRefUT]),

    // DUPLICATA REMOVIDA: fluconazol+quetiapina — par detalhado mantido na seção de fluconazol (linha ~1670)

  ('haloperidol', 'ondansetrona', InteractionSeverity.major,
    'Prolongación aditiva del QT por mecanismos distintos',
    'Torsades de Pointes',
    'Evitar. Monitorar QTc. Si QTc >500ms, suspender uno de los medicamentos',
    'ALTO RIESGO DE TORSADES DE POINTES — Monitorar QTc',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefMdx, _kRefFDA]),

    // ── Heparina / Anticoagulantes ─────────────────────────────────────────────

  ('heparina', 'aspirina', InteractionSeverity.moderate,
    'Efecto antitrombótico/hemostático aditivo',
    'Riesgo aumentado de sangrado (especialmente GI)',
    'Monitorar signos de sangrado. Combinación aceptada en SCA (protocolo AHA/ACC), con precaución',
    'Requiere monitorización clínica — riesgo hemorrágico aditivo',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefUT]),

  ('heparina', 'aine', InteractionSeverity.moderate,
    'AINEs inhiben función plaquetaria + riesgo de sangrado GI',
    'Riesgo aumentado de hemorragia',
    'Evitar AINEs durante anticoagulación. Preferir paracetamol para analgesia',
    'Requiere monitorización — evitar AINEs con heparina',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx]),

    // ── Amiodarona — QT e interações adicionais ───────────────────────────────

  ('amiodarona', 'azitromicina', InteractionSeverity.major,
    'Prolongación aditiva del intervalo QT por mecanismos distintos',
    'Torsades de Pointes, fibrilação ventricular',
    'Evitar combinación. Se antibiótico essencial, preferir amoxicilina ou doxiciclina. Monitorar QTc',
    'ALTO RIESGO DE TORSADES DE POINTES — Preferir amoxicilina',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefMdx, _kRefUT]),

  ('amiodarona', 'metoprolol', InteractionSeverity.major,
    'Efeito cronotrópico e dromotrópico negativo aditivo sobre o nó sinusal e AV',
    'Bradicardia grave, bloqueo AV, colapso hemodinámico',
    'Monitorar FC e ECG continuamente. Reduzir dose do betabloqueador. Ter atropina disponible',
    'ALTO RIESGO CARDIOVASCULAR — Monitorar ECG y FC continuamente',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),

    // ── Warfarina — entradas complementares ───────────────────────────────────

  ('warfarina', 'aine', InteractionSeverity.major,
    'AINEs inibem função plaquetária e causam ulceração GI; deslocamento proteico eleva INR',
    'Riesgo muy alto de sangrado gastrointestinal y úlcera péptica',
    'Evitar combinación. Preferir paracetamol. Si inevitable, usar IBP e monitorar INR frecuentemente',
    'ALTO RIESGO DE SANGRADO GI — Use paracetamol + IBP',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),

    // ── Clopidogrel ───────────────────────────────────────────────────────────

  ('clopidogrel', 'omeprazol', InteractionSeverity.moderate,
    'Inibição do CYP2C19 pelo omeprazol reduz conversão do clopidogrel ao metabólito ativo',
    'Reducción del efecto antiagregante — mayor riesgo de eventos isquémicos y trombosis de stent',
    'Preferir pantoprazol (menor inhibición CYP2C19) si IBP necesario. Monitorar eventos cardiovasculares',
    'Requiere sustitución de IBP — preferir pantoprazol',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.thrombosis},
    [_kRefGG, _kRefMdx, _kRefFDA]),

  ('clopidogrel', 'esomeprazol', InteractionSeverity.moderate,
    'Inibição do CYP2C19 pelo esomeprazol reduz ativação do clopidogrel',
    'Eficacia antiagregante reducida — riesgo de trombosis de stent',
    'Sustituir por pantoprazol. Reevaluar necesidad del IBP después del período de riesgo',
    'Requiere sustitución de IBP — preferir pantoprazol',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.thrombosis},
    [_kRefMdx, _kRefFDA]),

    // ── IECA — entradas complementares ────────────────────────────────────────

  ('enalapril', 'sacubitrila', InteractionSeverity.contraindicated,
    'Inibição simultânea do sistema neprilisina-angiotensina causa acúmulo de bradicinina',
    'Angioedema grave y potencialmente fatal — riesgo 3× mayor que IECA solo',
    'Contraindicado. Respetar ventana de washout de 36 horas entre suspender IECA e iniciar sacubitril',
    'NO UTILIZAR — Angioedema fatal; washout 36h obligatorio',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    [_kRefGG, _kRefFDA, _kRefUT]),

    // ── Lítio ─────────────────────────────────────────────────────────────────

  ('carbonato de litio', 'ibuprofeno', InteractionSeverity.major,
    'AINEs reduzem excreção renal de lítio por inhibición das prostaglandinas renais',
    'Toxicidad lítica rápida — temblor, confusión, convulsiones, arritmias',
    'Evitar AINEs en pacientes con litio. Usar paracetamol. Monitorar litemia si inevitable',
    'ALTO RIESGO DE TOXICIDAD POR LITIO — Use paracetamol',
    EvidenceLevel.established,
    {RiskType.increasedToxicity, RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx, _kRefUT]),

  ('carbonato de litio', 'hidroclorotiazida', InteractionSeverity.major,
    'Tiazídicos aumentam reabsorção proximal de sódio e lítio em compensação à perda distal',
    'Toxicidad por litio — confusión, temblor, nefrotoxicidad',
    'Monitorar litemia cada 3–5 días al inicio. Reducir dosis de litio 30–50%',
    'ALTO RIESGO DE TOXICIDAD POR LITIO — Monitorar litemia',
    EvidenceLevel.established,
    {RiskType.increasedToxicity, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),

  ('carbonato de litio', 'enalapril', InteractionSeverity.major,
    'IECAs reduzem clearance renal de lítio por inhibición da angiotensina II',
    'Elevación de los niveles séricos de litio — toxicidad',
    'Monitorar litemia semanalmente las primeras 4 semanas. Reducir dosis de litio según sea necesario',
    'ALTO RIESGO DE TOXICIDAD POR LITIO — Monitorar litemia semanalmente',
    EvidenceLevel.established,
    {RiskType.increasedToxicity, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),

    // ── Serotonina — entradas complementares ──────────────────────────────────

  ('isrs', 'linezolida', InteractionSeverity.contraindicated,
    'Linezolida inibe a MAO — hiperestimulação serotoninérgica com SSRI',
    'Síndrome serotoninérgica grave — hipertermia, rigidez, crisis convulsiva, colapso',
    'Contraindicado. Esperar washout adecuado (≥5 semanas para fluoxetina, ≥2 semanas para otros SSRIs)',
    'NO UTILIZAR ESTOS FÁRMACOS JUNTOS — Síndrome serotoninérgica fatal',
    EvidenceLevel.established,
    {RiskType.serotonin},
    [_kRefGG, _kRefFDA, _kRefMdx]),

  ('tramadol', 'amitriptilina', InteractionSeverity.major,
    'Redução do limiar convulsivo + inibição da recaptação de serotonina/noradrenalina aditiva',
    'Riesgo aumentado de convulsiones y síndrome serotoninérgica',
    'Evitar combinación. Si necesario, iniciar tramadol en dosis mínima con monitorización neurológica',
    'ALTO RIESGO DE SÍNDROME SEROTONINÉRGICA Y CONVULSIONES',
    EvidenceLevel.probable,
    {RiskType.serotonin, RiskType.cns},
    [_kRefMdx, _kRefUT]),

    // ── Aminoglicosídeos ───────────────────────────────────────────────────────

  ('aminoglicosideo', 'vancomicina', InteractionSeverity.major,
    'Nefrotoxicidad e ototoxicidad sinérgica — ambos lesam túbulos renais proximais e células ciliadas',
    'Insuficiencia renal aguda, sordera irreversible',
    'Evitar combinación se possível. Se necessária, monitorar creatinina diariamente e função auditiva',
    'ALTO RIESGO DE NEFROTOXICIDAD Y SORDERA IRREVERSIBLE',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx, _kRefUT]),

    // ── Quinolonas — quelação por cátions ─────────────────────────────────────

  ('ciprofloxacino', 'carbonato de calcio', InteractionSeverity.moderate,
    'Cálcio forma complexo insolúvel com ciprofloxacino no intestino (quelação)',
    'Reducción de hasta el 50% en la absorción oral de la quinolona',
    'Administrar ciprofloxacino 2h antes o 6h después del calcio/antiácidos/hierro',
    'Requiere intervalo de 2–6h entre administraciones',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefFDA]),

  ('ciprofloxacino', 'sulfato ferroso', InteractionSeverity.moderate,
    'Ferro quelata ciprofloxacino no TGI reduzindo drásticamente sua biodisponibilidade',
    'Fracaso terapéutico del antibiótico',
    'Administrar ciprofloxacino 2h antes o 6h después del suplemento de hierro',
    'Requiere intervalo de 2–6h entre administraciones — risco de falha terapéutica',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefFDA]),

    // ── Levotiroxina ──────────────────────────────────────────────────────────

  ('levotiroxina', 'carbonato de calcio', InteractionSeverity.moderate,
    'Cálcio liga-se à levotiroxina no intestino reduzindo sua absorção',
    'Hipotiroidismo por absorción inadecuada — TSH elevado',
    'Intervalo mínimo de 4 horas entre levotiroxina y calcio. Tomar levotiroxina en ayunas',
    'Requiere intervalo de 4h — separar administraciones',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefFDA]),

  ('levotiroxina', 'pantoprazol', InteractionSeverity.moderate,
    'Redução da acidez gástrica pelos IBPs prejudica dissolução e absorção da levotiroxina',
    'Absorción reducida — hipotiroidismo subclínico',
    'Monitorar TSH a cada 6–8 semanas. Pode ser necesario aumentar dose de levotiroxina',
    'Requiere monitorización de TSH cada 6–8 semanas',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy},
    [_kRefMdx, _kRefUT]),

  ('levotiroxina', 'antiácido', InteractionSeverity.moderate,
    'Cátions (Al, Mg, Ca) dos antiácidos quelam levotiroxina no TGI',
    'Reducción de la absorción — hipotiroidismo',
    'Administrar levotiroxina 2h antes de antiácidos, IBPs, calcio o hierro',
    'Requiere intervalo de 2h entre administraciones',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefFDA]),

    // ── Benzodiazepínicos — complementar ──────────────────────────────────────

  ('benzodiazepínico', 'alcool', InteractionSeverity.major,
    'Potenciação mútua da depressão do SNC por mecanismos GABA-A aditivos',
    'Sedación severa, depresión respiratoria, coma, muerte',
    'Contraindicado. Orientar al paciente explícitamente sobre la prohibición de alcohol',
    'ALTO RIESGO DE DEPRESIÓN RESPIRATORIA — Prohibido alcohol',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns},
    [_kRefGG, _kRefFDA]),

    // ── Anticonvulsivantes ─────────────────────────────────────────────────────

  ('carbamazepina', 'anticoncepcional', InteractionSeverity.major,
    'Indução enzimática do CYP3A4 acelera metabolismo de estrógenos e progestágenos',
    'Fracaso del anticonceptivo hormonal — embarazo no planificado',
    'Usar método anticonceptivo no hormonal (DIU de cobre, preservativo). Orientar explícitamente a la paciente',
    'ALTO RIESGO DE FALLO CONTRACEPTIVO — Usar método no hormonal',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefFDA]),

  ('valproato', 'lamotrigina', InteractionSeverity.major,
    'Ácido valproico inibe a glucuronidação da lamotrigina, dobrando sua meia-vida',
    'Toxicidad por lamotrigina — erupción grave, Síndrome de Stevens-Johnson',
    'Reducir dosis de lamotrigina 50% al introducir valproato. Monitorar erupción cutánea',
    'ALTO RIESGO DE SÍNDROME DE STEVENS-JOHNSON — Reducir lamotrigina 50%',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx, _kRefFDA]),

  ('midazolam', 'claritromicina', InteractionSeverity.major,
    'Inhibición potente del CYP3A4 pela claritromicina prolonga meia-vida do midazolam',
    'Sedación prolongada y excesiva, depresión respiratoria',
    'Reducir dosis de midazolam 50–75%. Monitorar nivel de consciencia y SpO₂',
    'ALTO RIESGO DE SEDACIÓN PROLONGADA — Reducir dosis de midazolam',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefFDA]),

    // ── Claritromicina + Benzodiazepínicos (CYP3A4) ──────────────────────────

  ('claritromicina', 'benzodiazepínico', InteractionSeverity.major,
    'Claritromicina inibe potentemente o CYP3A4 — principal via de metabolismo de alprazolam, diazepam, clonazepam e triazolam. Lorazepam é menos afetado (metabolismo por glucuronidação)',
    'Aumento de 2-5x en los niveles plasmáticos de las benzodiazepinas → sedación excesiva y prolongada, compromiso psicomotor, depresión respiratoria, amnesia anterógrada',
    'Preferir azitromicina quando possível (não inibe CYP3A4). Se claritromicina necessária: reduzir dose do benzodiazepínico em 50%, evitar alprazolam e triazolam, preferir lorazepam. Monitorar nivel de consciencia y SpO₂',
    'SEDACIÓN AUMENTADA — Claritromicina inhibe CYP3A4; reducir BZD 50% o preferir lorazepam',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.respiratoryDepression, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),

    // ── Corticosteroides ──────────────────────────────────────────────────────

  ('dexametasona', 'aine', InteractionSeverity.major,
    'Corticosteroide + AINE: inibição dupla das prostaglandinas protetoras da mucosa gástrica',
    'Riesgo muy elevado de úlcera péptica y hemorragia GI',
    'Contraindicado sem proteção gástrica. Prescrever IBP obligatoriamente se combinação necessária',
    'ALTO RIESGO DE HEMORRAGIA GI — Prescribir IBP obligatoriamente',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx]),

    // ── Hiperpotassemia ────────────────────────────────────────────────────────

  ('espironolactona', 'cloreto de potassio', InteractionSeverity.contraindicated,
    'Espironolactona retém potássio + suplementação adicional = hiperpotasemia aditiva extrema',
    'Hiperpotasemia fatal — paro cardíaco en asistolia',
    'Contraindicado. No suplementar potasio rutinariamente con espironolactona. Monitorar K+ sérico',
    'NO UTILIZAR — Hiperpotasemia fatal; paro cardíaco',
    EvidenceLevel.established,
    {RiskType.hyperkalemia, RiskType.arrhythmia},
    [_kRefGG, _kRefFDA]),

    // ── Colchicina / Imunossupressores ────────────────────────────────────────

  ('colchicina', 'claritromicina', InteractionSeverity.contraindicated,
    'Inibição da P-gp e CYP3A4 eleva drásticamente os níveis de colchicina',
    'Toxicidad por colchicina — miopatía, neuropatía, pancitopenia, falla de múltiples órganos',
    'Contraindicado en insuficiencia renal o hepática. Reducir dosis de colchicina y monitorar rigurosamente',
    'NO UTILIZAR — Toxicidad por colchicina con riesgo de falla orgánica',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.myelosuppression, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefFDA]),

  ('alopurinol', 'azatioprina', InteractionSeverity.contraindicated,
    'Alopurinol inibe xantina oxidase — enzima que metaboliza azatioprina — causando acúmulo tóxico',
    'Mielosupresión grave: leucopenia, trombocitopenia, anemia aplásica',
    'Contraindicado. Si la combinación es inevitable, reducir azatioprina a 25% de la dosis y monitorar hemograma semanalmente',
    'NO UTILIZAR — Mielosupresión grave; riesgo de aplasia medular',
    EvidenceLevel.established,
    {RiskType.myelosuppression, RiskType.increasedToxicity},
    [_kRefGG, _kRefFDA, _kRefMdx]),

    // ── Interações farmacodinâmicas adicionais ────────────────────────────────

  ('ondansetrona', 'tramadol', InteractionSeverity.moderate,
    'Ondansetrona bloqueia receptores 5-HT₃ utilizados pelo tramadol para analgesia',
    'Reducción significativa del efecto analgésico del tramadol',
    'Evaluar eficacia analgésica. Si necesario, sustituir por otro antiemético o usar analgésico alternativo',
    'Requiere monitorización — analgesia del tramadol puede reducirse',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy},
    [_kRefMdx, _kRefUT]),

  ('insulina', 'dapagliflozina', InteractionSeverity.moderate,
    'Efeito hipoglucemiante aditivo — iSGLT2 potencializa o efeito da insulina',
    'Hipoglucemia grave, especialmente con insulina basal o bolos elevados',
    'Reduzir dose de insulina em 10–20% ao iniciar iSGLT2. Monitorar glucemia frecuentemente',
    'Requiere monitorización de glucemia — reducir insulina al iniciar iSGLT2',
    EvidenceLevel.established,
    {RiskType.hypoglycemia},
    [_kRefGG, _kRefFDA, _kRefUT]),

  ('amitriptilina', 'atropina', InteractionSeverity.moderate,
    'Efeitos anticolinérgicos aditivos — bloqueio muscarínico somado',
    'Boca seca intensa, retención urinaria, visión borrosa, confusión, delirio (especialmente en ancianos)',
    'Evitar en ancianos. Si necesario, usar la menor dosis posible y monitorar síntomas anticolinérgicos',
    'Requiere monitorización clínica — toxicidad anticolinérgica aditiva',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.increasedToxicity},
    [_kRefGG, _kRefKatz]),

    // ══════════════════════════════════════════════════════════════════════════
    // INTERAÇÕES — MERGE v2 (modelo expandido)
    // ══════════════════════════════════════════════════════════════════════════

    // ── Dronedarona ───────────────────────────────────────────────────────────

  ('dronedarona', 'dabigatrana', InteractionSeverity.major,
    'Dronedarona inibe P-glicoproteína → aumenta absorção e nivel sérico de dabigatrana',
    'Riesgo hemorrágico elevado — aumento de hasta 100% en la exposición a dabigatrán',
    'Reduzir dose de dabigatrana para 75 mg 2x/dia com dronedarona. Monitorar sinais de sangrado',
    'ALTO RISCO DE SANGRAMENTO — Reduzir dose de dabigatrana',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefFDA]),

  ('dronedarona', 'sinvastatina', InteractionSeverity.major,
    'Inhibición del CYP3A4 e P-gp pela dronedarona aumenta nível de sinvastatina',
    'Riesgo de miopatía/rabdomiólisis',
    'Dose máxima de sinvastatina: 20 mg/dia. Preferir rosuvastatina ou pravastatina',
    'RIESGO DE RABDOMIÓLISIS — Limitar simvastatina a 20 mg/día',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefMdx, _kRefFDA]),

  ('dronedarona', 'metoprolol', InteractionSeverity.major,
    'Inhibición del CYP2D6 por dronedarona aumenta nivel de metoprolol + efecto cronotrópico negativo aditivo',
    'Bradicardia grave, bloqueio AV, hipotensão',
    'Monitorar FC e ECG. Reducir dosis de metoprolol. Objetivo: FC ≥50 lpm en reposo',
    'ALTO RIESGO CARDIOVASCULAR — Monitorar FC y ECG',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.plasmaLevel},
    [_kRefMdx, _kRefLex]),

  ('dronedarona', 'digoxina', InteractionSeverity.major,
    'Inhibición de la P-gp aumenta nivel sérico de digoxina',
    'Toxicidad digitálica — náuseas, bradicardia, trastornos de conducción',
    'Reducir dosis de digoxina 50%. Monitorar nivel sérico y ECG regularmente',
    'ALTO RIESGO DE TOXICIDAD DIGITÁLICA — Reducir digoxina 50%',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.cardiovascular},
    [_kRefMdx, _kRefFDA]),

  ('dronedarona', 'warfarina', InteractionSeverity.moderate,
    'Inhibición del CYP3A4 e possível efeito no CYP2C9 pela dronedarona',
    'Elevação moderada do INR',
    'Monitorar INR semanalmente nas primeiras 2–4 semanas após introdução. Ajustar dosis de warfarina según sea necesario',
    'Requiere monitorización de INR las primeras 2–4 semanas',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),

  ('dronedarona', 'ciclosporina', InteractionSeverity.contraindicated,
    'Inhibición mutua del CYP3A4 y P-gp — exposición de ambos aumenta drásticamente',
    'Toxicidade por ciclosporina (nefrotóxica) e toxicidad cardíaca por dronedarona',
    'Combinação contraindicada. Substituir por antiarrítmico alternativo',
    'NO UTILIZAR — Toxicidad grave bilateral',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.cardiovascular, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),

    // ── Ivabradina ────────────────────────────────────────────────────────────

  ('ivabradina', 'diltiazem', InteractionSeverity.contraindicated,
    'Diltiazem inhibe CYP3A4 (aumenta nivel de ivabradina) + efecto cronotrópico negativo aditivo en nodo sinusal',
    'Bradicardia grave, bloqueio sinusal, asistolia',
    'Combinação contraindicada. Usar apenas um agente para controle de FC',
    'NO UTILIZAR — Bradicardia grave y asistolia',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    [_kRefFDA, _kRefMdx]),

  ('ivabradina', 'verapamil', InteractionSeverity.contraindicated,
    'Verapamil inhibe CYP3A4 + efecto bradicardizante sinérgico',
    'Bradicardia grave, síncope, parada sinusal',
    'Contraindicado — não combinar ivabradina com bloqueadores de cálcio não-diidropiridínicos',
    'NO UTILIZAR — Bradicardia grave y paro sinusal',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    [_kRefFDA, _kRefMdx]),

  ('ivabradina', 'claritromicina', InteractionSeverity.major,
    'Inhibición potente del CYP3A4 pela claritromicina aumenta exposição à ivabradina em ~7×',
    'Bradicardia grave, prolongamento QT, Torsades de Pointes',
    'Contraindicado. Suspender ivabradina durante el curso de claritromicina. Alternativa: azitromicina',
    'ALTO RIESGO CARDIOVASCULAR — Suspender ivabradina',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.cardiovascular, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),

  ('ivabradina', 'fluconazol', InteractionSeverity.major,
    'Inhibición del CYP3A4 pelo fluconazol aumenta significativamente o nível de ivabradina',
    'Bradicardia excessiva, tontura, fosfenos',
    'Monitorar FC. Reducir dosis de ivabradina si FC <50 lpm. Considerar antifúngico alternativo',
    'ALTO RIESGO DE BRADICARDIA — Monitorar FC',
    EvidenceLevel.probable,
    {RiskType.cardiovascular, RiskType.plasmaLevel},
    [_kRefMdx, _kRefLex]),

    // ── Ranolazina ────────────────────────────────────────────────────────────

  ('ranolazina', 'claritromicina', InteractionSeverity.contraindicated,
    'Inhibición potente del CYP3A4 aumenta ranolazina em >5× + ambos prolongam QTc',
    'Prolongamento QTc grave, Torsades de Pointes, arritmia ventricular fatal',
    'Contraindicado. Substituir por azitromicina ou doxiciclina',
    'NO UTILIZAR — Arritmia ventricular fatal',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),

  ('ranolazina', 'amiodarona', InteractionSeverity.major,
    'Amiodarona inhibe CYP3A4 + ambos prolongan QTc por mecanismos distintos',
    'Prolongamento QTc excessivo, Torsades de Pointes',
    'Evitar combinación. Si necesaria, monitorar QTc (ECG seriado). Suspender si QTc >500 ms',
    'ALTO RIESGO DE TORSADES DE POINTES — Monitorar QTc seriado',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefMdx, _kRefUT]),

  ('ranolazina', 'digoxina', InteractionSeverity.moderate,
    'Ranolazina inhibe P-gp → aumento del nivel sérico de digoxina en ~50%',
    'Toxicidade digitálica — bradiarritmias, náuseas, distúrbios visuais',
    'Reducir dosis de digoxina 50% al iniciar ranolazina. Monitorar nivel sérico',
    'Requiere monitorización — toxicidad digitálica por aumento de nivel',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.arrhythmia},
    [_kRefMdx, _kRefFDA]),

  ('ranolazina', 'sinvastatina', InteractionSeverity.moderate,
    'Inhibición del CYP3A4 pela ranolazina aumenta exposição à sinvastatina',
    'Riesgo aumentado de miopatía',
    'Limitar sinvastatina a 20 mg/dia com ranolazina. Monitorar CPK y síntomas musculares',
    'Requiere monitorización — limitar simvastatina a 20 mg/día',
    EvidenceLevel.probable,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefMdx, _kRefFDA]),

    // ── Eplerenona ────────────────────────────────────────────────────────────

  ('eplerenona', 'cloreto de potassio', InteractionSeverity.contraindicated,
    'Eplerenona retiene K⁺ (ahorrador de potasio) + suplementación adicional',
    'Hiperpotasemia fatal — paro cardíaco',
    'Contraindicado. No suplementar potasio rutinariamente con eplerenona. Monitorar K⁺ sérico rigurosamente',
    'NO UTILIZAR — Hiperpotasemia fatal; paro cardíaco',
    EvidenceLevel.established,
    {RiskType.hyperkalemia, RiskType.arrhythmia},
    [_kRefFDA, _kRefGG]),

  ('eplerenona', 'enalapril', InteractionSeverity.moderate,
    'Ambos elevan K⁺ por mecanismos distintos — antagonismo aldosterona + inhibición de la angiotensina II',
    'Hiperpotasemia, especialmente en ERC o diabetes',
    'Monitorar K⁺ e creatinina semanalmente no início. Reducir/suspender eplerenona si K⁺ >5,5 mEq/L',
    'Requiere monitorización de K+ sérico semanal',
    EvidenceLevel.established,
    {RiskType.hyperkalemia},
    [_kRefGG, _kRefUT]),

  ('eplerenona', 'claritromicina', InteractionSeverity.contraindicated,
    'Inhibición potente del CYP3A4 pela claritromicina aumenta exposição à eplerenona em >5×',
    'Hipercalemia grave e excessiva retenção de potássio',
    'Contraindicado. Sustituir por azitromicina. Esperar 14 días después de claritromicina antes de reiniciar eplerenona',
    'NO UTILIZAR — Hiperpotasemia grave; sustituir por azitromicina',
    EvidenceLevel.established,
    {RiskType.hyperkalemia, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),

    // ── Daptomicina ───────────────────────────────────────────────────────────

  ('daptomicina', 'estatina', InteractionSeverity.major,
    'Mecanismo sinérgico de miotoxicidad — ambos lesionan membranas musculares por mecanismos complementarios',
    'Miopatia grave e rabdomiólisis',
    'Suspender estatinas durante uso de daptomicina. Monitorar CPK semanalmente. Reiniciar estatina tras fin del antibiótico',
    'ALTO RIESGO DE RABDOMIÓLISIS — Suspender estatina durante daptomicina',
    EvidenceLevel.established,
    {RiskType.myopathy},
    [_kRefMdx, _kRefFDA]),

  ('daptomicina', 'aminoglicosideo', InteractionSeverity.moderate,
    'Posible nefrotoxicidad aditiva — ambos pueden elevar creatinina con uso prolongado',
    'Insuficiência renal aguda, especialmente em pacientes vulneráveis',
    'Monitorar creatinina y electrolitos diariamente. Minimizar duración y dosis de aminoglucósido',
    'Requiere monitorización renal diaria',
    EvidenceLevel.probable,
    {RiskType.nephrotoxicity},
    [_kRefMdx, _kRefUT]),

    // ── Nirmatrelvir/Ritonavir (Paxlovid) ────────────────────────────────────

  ('ritonavir', 'sinvastatina', InteractionSeverity.contraindicated,
    'Inhibición potente del CYP3A4 pelo ritonavir aumenta sinvastatina >10× — rabdomiólisis',
    'Rabdomiólisis grave, insuficiencia renal, coagulación intravascular diseminada',
    'Contraindicado absolutamente. Suspender simvastatina durante uso de Paxlovid',
    'NO UTILIZAR — Rabdomiólisis con CID; riesgo de muerte',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.nephrotoxicity, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),

  ('ritonavir', 'midazolam', InteractionSeverity.contraindicated,
    'Inhibición potente del CYP3A4 pelo ritonavir → nível de midazolam aumenta dezenas de vezes',
    'Sedación prolongada y grave, depresión respiratoria, coma',
    'Contraindicado. No usar midazolam oral/parenteral con ritonavir',
    'NO UTILIZAR — Sedación grave y coma',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),

  ('ritonavir', 'amiodarona', InteractionSeverity.contraindicated,
    'Inhibición del CYP3A4 e CYP2C8 pelo ritonavir aumenta amiodarona dramaticamente + QT aditivo',
    'Toxicidade por amiodarona (pulmonar, hepática, tireoidiana) e Torsades de Pointes',
    'Contraindicado. Sustituir ritonavir si el paciente usa amiodarona. Paxlovid contraindicado en estas situaciones',
    'NO UTILIZAR — Toxicidad grave por amiodarona y arritmia',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.hepatotoxicity, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),

  ('ritonavir', 'warfarina', InteractionSeverity.major,
    'Ritonavir es inductor e inhibidor del CYP2C9 (efecto bifásico) — INR puede aumentar o disminuir',
    'Inestabilidad del INR — riesgo de sangrado o trombosis dependiendo de la fase',
    'Monitorar INR cada 1–2 días durante uso de Paxlovid y por 2 semanas después. Ajustar dosis de warfarina',
    'ALTO RIESGO — Monitorar INR diariamente durante Paxlovid',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),

  ('ritonavir', 'atorvastatina', InteractionSeverity.major,
    'Inhibición del CYP3A4 pelo ritonavir aumenta atorvastatina em ~8×',
    'Riesgo significativo de miopatía/rabdomiólisis',
    'Suspender atorvastatina durante uso de Paxlovid (5 días). Reiniciar al terminar. Alternativa: pravastatina o rosuvastatina en dosis baja',
    'RIESGO DE RABDOMIÓLISIS — Suspender atorvastatina durante Paxlovid',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),

  ('ritonavir', 'carbamazepina', InteractionSeverity.major,
    'Carbamazepina es inductor potente del CYP3A4 → reduce drásticamente niveles de nirmatrelvir/ritonavir',
    'Fracaso terapéutico de Paxlovid — concentraciones subterapéuticas de nirmatrelvir',
    'Paxlovid contraindicado con carbamazepina. Considerar molnupiravir como alternativa',
    'ALTO RIESGO DE FRACASO TERAPÉUTICO — Paxlovid ineficaz con carbamazepina',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefFDA, _kRefUT]),

  ('ritonavir', 'ranolazina', InteractionSeverity.contraindicated,
    'Inhibición del CYP3A4 pelo ritonavir eleva ranolazina drásticamente + prolongamento QTc aditivo',
    'Arritmia ventricular grave, Torsades de Pointes',
    'Contraindicado. Suspender ranolazina durante uso de Paxlovid',
    'NO UTILIZAR — Arritmia ventricular fatal',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefFDA, _kRefMdx]),

    // ── Semaglutida / Tirzepatida (arGLP-1) ──────────────────────────────────

  ('semaglutida', 'insulina', InteractionSeverity.moderate,
    'Efecto hipoglucemiante aditivo — arGLP-1 potencia acción de la insulina',
    'Hipoglucemia grave, especialmente con insulina basal o prandial en dosis altas',
    'Reduzir dose de insulina em 20–40% ao iniciar arGLP-1. Monitorar glucemia. Titular gradualmente',
    'Requiere monitorización — reducir insulina al iniciar arGLP-1',
    EvidenceLevel.established,
    {RiskType.hypoglycemia},
    [_kRefGG, _kRefFDA, _kRefUT]),

  ('semaglutida', 'sulfonilureia', InteractionSeverity.moderate,
    'Efecto insulinotrópico aditivo con riesgo aumentado de hipoglucemia',
    'Hipoglucemia grave, mareo, sudoración, convulsiones',
    'Reduzir dose da sulfonilureia em 50% ao iniciar semaglutida. Monitorar glucemia capilar diariamente',
    'Requiere monitorización — reducir sulfonilurea al iniciar semaglutida',
    EvidenceLevel.established,
    {RiskType.hypoglycemia},
    [_kRefFDA, _kRefUT]),

  ('semaglutida', 'levotiroxina', InteractionSeverity.monitorOnly,
    'El retardo del vaciamiento gástrico por semaglutida puede reducir absorción de levotiroxina',
    'Reducción de la absorción de levotiroxina → hipotiroidismo subclínico',
    'Tomar levotiroxina en ayunas, ≥30 min antes de semaglutida si oral (Rybelsus). Monitorar TSH cada 6–8 semanas',
    'Solo monitorizar — monitorar TSH cada 6–8 semanas',
    EvidenceLevel.possible,
    {RiskType.reducedEfficacy},
    [_kRefMdx, _kRefUT]),

    // ── Canagliflozina / iSGLT2 ──────────────────────────────────────────────

  ('canagliflozina', 'furosemida', InteractionSeverity.moderate,
    'Efecto natriurético y diurético aditivo — ambos causan depleción de volumen',
    'Hipotensión grave, IRA prerrenal, deshidratación, hipopotasemia',
    'Monitorar PA, función renal y electrolitos. Reducir dosis de furosemida si necesario. Hidratación adecuada',
    'Requiere monitorización clínica/laboratorial — depleción de volumen',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.nephrotoxicity, RiskType.hypokalemia},
    [_kRefGG, _kRefFDA]),

  ('canagliflozina', 'enalapril', InteractionSeverity.moderate,
    'Efecto natriurético de los iSGLT2 asociado a vasodilatación de los IECAs — hipotensión e hiperpotasemia',
    'Hipotensión sintomática, IRA prerrenal, hiperpotasemia',
    'Monitorar PA, K⁺ e función renal nas primeiras 2–4 semanas. Hidratação adecuada',
    'Requiere monitorización de PA y función renal',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.hyperkalemia},
    [_kRefGG, _kRefUT]),

  ('canagliflozina', 'rifampicina', InteractionSeverity.moderate,
    'Rifampicina induce UGT y CYP → reducción del 51% en la exposición a canagliflozina',
    'Reducción del efecto hipoglucemiante y nefroprotector',
    'Monitorar controle glicêmico. Pode ser necesario aumentar dose de canagliflozina ou substituir por outra classe',
    'Requiere monitorización glucémica — eficacia reducida',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),

    // ── Finerenona ────────────────────────────────────────────────────────────

  ('finerenona', 'claritromicina', InteractionSeverity.contraindicated,
    'Inhibición potente del CYP3A4 pela claritromicina aumenta finerenona em >5×',
    'Hiperpotasemia grave y potencialmente fatal',
    'Contraindicado. Suspender finerenona durante uso de claritromicina. Alternativa: azitromicina',
    'NO UTILIZAR — Hiperpotasemia grave; sustituir por azitromicina',
    EvidenceLevel.established,
    {RiskType.hyperkalemia, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),

  ('finerenona', 'espironolactona', InteractionSeverity.contraindicated,
    'Antagonismo mineralocorticoide aditivo — doble bloqueo del receptor de aldosterona',
    'Hiperpotasemia grave, paro cardíaco',
    'Contraindicado — não combinar dois ARM. Escolher apenas um deles',
    'NO UTILIZAR — Hiperpotasemia fatal por doble bloqueo de ARM',
    EvidenceLevel.established,
    {RiskType.hyperkalemia, RiskType.arrhythmia},
    [_kRefFDA, _kRefGG]),

  ('finerenona', 'enalapril', InteractionSeverity.moderate,
    'Efecto ahorrador de potasio de finerenona + reducción de excreción de K⁺ por IECA',
    'Hiperpotasemia — riesgo aumentado, especialmente en ERC',
    'Monitorar K⁺ semanalmente las primeras 4 semanas. Suspender si K⁺ >5,5 mEq/L',
    'Requiere monitorización de K+ semanal las primeras 4 semanas',
    EvidenceLevel.established,
    {RiskType.hyperkalemia},
    [_kRefFDA, _kRefUT]),

    // ── Tocilizumabe / Baricitinibe ───────────────────────────────────────────

  ('tocilizumabe', 'warfarina', InteractionSeverity.moderate,
    'IL-6 regula expresión de enzimas CYP; al bloquear IL-6, tocilizumab restaura metabolismo de warfarina (reduce INR)',
    'Reducción inesperada del INR cuando tocilizumab es iniciado o escalado',
    'Monitorar INR semanalmente por 4–6 semanas após início do tocilizumabe. Ajustar dose de varfarina',
    'Requiere monitorização de INR — tocilizumabe pode reduzir INR',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.thrombosis},
    [_kRefMdx, _kRefUT]),

  ('tocilizumabe', 'estatina', InteractionSeverity.moderate,
    'El bloqueo de IL-6 restaura CYP3A4 — estatinas metabolizadas por CYP3A4 tienen metabolismo aumentado',
    'Reducción de los niveles plasmáticos de estatinas — menor efecto hipolipemiante',
    'Monitorar perfil lipídico 4–8 semanas tras inicio. Puede ser necesario aumentar dosis de la estatina',
    'Requiere monitorización del perfil lipídico',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),

  ('baricitinibe', 'isrs', InteractionSeverity.monitorOnly,
    'Inhibición del transportador OAT3 por baricitinib puede aumentar levemente concentración de algunos SSRIs',
    'Aumento marginal de la exposición a SSRIs eliminados por vía renal',
    'Monitorar efectos adversos de los SSRIs. La interacción generalmente no requiere ajuste de dosis',
    'Solo monitorizar — ajuste de dosis generalmente no necesario',
    EvidenceLevel.theoretical,
    {RiskType.plasmaLevel},
    [_kRefMdx, _kRefLex]),

    // ── Vedolizumabe ──────────────────────────────────────────────────────────

  ('vedolizumabe', 'natalizumabe', InteractionSeverity.contraindicated,
    'Ambos son antagonistas de integrinas — inmunomodulación aditiva sistémica e intestinal',
    'Riesgo muy aumentado de infecciones oportunistas y leucoencefalopatía multifocal progresiva (LMP)',
    'Contraindicado — no combinar biológicos anti-integrinas. Washout adecuado entre los agentes',
    'NO UTILIZAR — Riesgo de LMP e infecciones oportunistas graves',
    EvidenceLevel.established,
    {RiskType.infection},
    [_kRefFDA, _kRefMdx]),

    // ── Tofacitinibe ──────────────────────────────────────────────────────────

  ('tofacitinibe', 'ciclosporina', InteractionSeverity.contraindicated,
    'Inhibición del CYP3A4 + imunossupressão aditiva potente',
    'Infecciones oportunistas graves, nefrotoxicidad, linfoma',
    'Contraindicado. No combinar JAKi con inmunosupresores biológicos potentes',
    'NO UTILIZAR — Inmunosupresión excesiva con riesgo de linfoma',
    EvidenceLevel.established,
    {RiskType.infection, RiskType.nephrotoxicity},
    [_kRefFDA, _kRefMdx]),

  ('tofacitinibe', 'fluconazol', InteractionSeverity.major,
    'Inhibición del CYP3A4 e CYP2C19 pelo fluconazol aumenta exposição ao tofacitinibe em ~130%',
    'Toxicidad por tofacitinib — infecciones, trombosis, elevación de enzimas hepáticas',
    'Reducir dosis de tofacitinib a 5 mg 1x/día durante uso de fluconazol. Monitorar hemograma y transaminasas',
    'ALTO RIESGO — Reducir dosis de tofacitinib y monitorar hemograma',
    EvidenceLevel.established,
    {RiskType.infection, RiskType.hepatotoxicity, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),

  ('tofacitinibe', 'rifampicina', InteractionSeverity.major,
    'Rifampicina induce CYP3A4 → reducción de ~84% en la exposición a tofacitinib',
    'Fracaso terapéutico — concentraciones subterapéuticas',
    'Evitar combinación. Se necesario, monitorar atividade da doença de base. Considerar alternativa biológica',
    'ALTO RIESGO DE FRACASO TERAPÉUTICO — Evitar combinación',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),

    // ── Ruxolitinibe ──────────────────────────────────────────────────────────

  ('ruxolitinibe', 'claritromicina', InteractionSeverity.major,
    'Inhibición potente del CYP3A4 → aumento de ~200% na exposição ao ruxolitinibe',
    'Citopenia grave (anemia, trombocitopenia), infecciones oportunistas, toxicidad hepática',
    'Reducir dosis de ruxolitinib 50% durante uso de claritromicina. Monitorar hemograma. Alternativa: azitromicina',
    'ALTO RIESGO DE CITOPENIA GRAVE — Reducir dosis de ruxolitinib 50%',
    EvidenceLevel.established,
    {RiskType.myelosuppression, RiskType.infection, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),

  ('ruxolitinibe', 'fluconazol', InteractionSeverity.moderate,
    'Inhibición del CYP3A4 aumenta exposição ao ruxolitinibe em ~100%',
    'Citopenia y riesgo de infecciones oportunistas aumentado',
    'Reducir dosis de ruxolitinib 50%. Monitorar hemograma frecuentemente',
    'Requiere monitorización — reducir dosis de ruxolitinib 50%',
    EvidenceLevel.established,
    {RiskType.myelosuppression, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),

    // ── Dupilumabe / Biológicos respiratórios ─────────────────────────────────

  ('dupilumabe', 'vacinas vivas', InteractionSeverity.major,
    'La inmunosupresión relativa por dupilumab puede reducir la respuesta inmunológica a vacunas vivas',
    'Riesgo de infección por la cepa vacunal (vacuna viva atenuada)',
    'No administrar vacunas vivas durante uso de dupilumab. Completar vacunación antes de iniciar biológico',
    'ALTO RIESGO — Vacunas vivas contraindicadas durante dupilumab',
    EvidenceLevel.established,
    {RiskType.infection},
    [_kRefFDA, _kRefMdx]),

  ('mepolizumabe', 'corticosteroide sistemico', InteractionSeverity.moderate,
    'La reducción de eosinófilos por mepolizumab permite retirada de corticosteroides, pero la retirada abrupta causa insuficiencia adrenal',
    'Insuficiencia adrenal aguda si corticosteroide retirado abruptamente',
    'Retirada LENTA y gradual de corticosteroides sistémicos — nunca retirar abruptamente. Monitorar síntomas de insuficiencia adrenal',
    'Requiere retirada LENTA de corticosteroides — nunca suspensión abrupta',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    [_kRefFDA, _kRefUT]),

    // ── Isavuconazol ──────────────────────────────────────────────────────────

  ('isavuconazol', 'rifampicina', InteractionSeverity.contraindicated,
    'Rifampicina induce CYP3A4 potentemente → reducción drástica de los niveles de isavuconazol',
    'Fracaso terapéutico antifúngico — concentraciones subterapéuticas',
    'Contraindicado — la combinación invalida el tratamiento antifúngico',
    'NO UTILIZAR — Fracaso terapéutico antifúngico garantizado',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),

  ('isavuconazol', 'ciclosporina', InteractionSeverity.moderate,
    'Inhibición del CYP3A4 pelo isavuconazol aumenta exposição à ciclosporina',
    'Toxicidad por ciclosporina — nefrotoxicidad, neurotoxicidad',
    'Monitorar nivel sérico de ciclosporina. Reduzir dose em 25–50% se necesario. Isavuconazol é inibidor CYP3A4 mais fraco que voriconazol',
    'Requiere monitorización de nivel sérico de ciclosporina',
    EvidenceLevel.probable,
    {RiskType.nephrotoxicity, RiskType.plasmaLevel},
    [_kRefMdx, _kRefLex]),

  ('isavuconazol', 'warfarina', InteractionSeverity.moderate,
    'Inhibición del CYP2C9 por isavuconazol puede aumentar nivel de warfarina',
    'Elevación del INR e risco hemorrágico',
    'Monitorar INR a cada 2–3 dias após início e término do isavuconazol. Ajustar dosis de warfarina según sea necesario',
    'Requiere monitorización de INR cada 2–3 días',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefMdx, _kRefLex]),

    // ── Eltrombopague ─────────────────────────────────────────────────────────

  ('eltrombopague', 'antiácido', InteractionSeverity.major,
    'Cationes polivalentes (Al, Mg, Ca) de los antiácidos forman quelatos con eltrombopag en el TGI',
    'Reducción de hasta el 70% en la absorción del eltrombopag → fracaso terapéutico',
    'Administrar eltrombopag ≥4 horas antes o ≥2 horas después de antiácidos, suplementos de calcio o hierro',
    'ALTO RISCO DE FALHA TERAPÊUTICA — Separar por ≥4 horas',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefFDA, _kRefMdx]),

  ('eltrombopague', 'sulfato ferroso', InteractionSeverity.major,
    'El hierro quela eltrombopag en el intestino — reducción drástica de la absorción',
    'Fracaso terapéutico de la trombocitopoyesis',
    'Separar eltrombopag del hierro al menos 4 horas. Tomar eltrombopag en ayunas',
    'ALTO RISCO DE FALHA TERAPÊUTICA — Separar por ≥4 horas',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefFDA, _kRefMdx]),

  ('eltrombopague', 'ciclosporina', InteractionSeverity.moderate,
    'Inhibición del OATP1B1 y CYP1A2 por eltrombopag puede aumentar exposición a ciclosporina',
    'Nefrotoxicidad por aumento del nivel de ciclosporina',
    'Monitorar nivel sérico de ciclosporina. Ajustar dose conforme necesario',
    'Requiere monitorización de nivel sérico de ciclosporina',
    EvidenceLevel.probable,
    {RiskType.nephrotoxicity, RiskType.plasmaLevel},
    [_kRefMdx, _kRefLex]),

    // ── Denosumabe ────────────────────────────────────────────────────────────

  ('denosumabe', 'corticosteroide sistemico', InteractionSeverity.moderate,
    'Ambos aumentan riesgo de osteonecrosis mandibular y fracturas atípicas; los corticosteroides causan osteoporosis adicional',
    'Riesgo de osteonecrosis mandibular y fracturas óseas graves',
    'Evaluación odontológica obligatoria antes de iniciar. Garantizar reposición adecuada de Ca²⁺ y vitamina D. Monitorar DMO',
    'Requiere evaluación odontológica antes de iniciar + reposición Ca²⁺/VitD',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefFDA, _kRefUT]),

    // ── Bupropiona ────────────────────────────────────────────────────────────

  ('bupropiona', 'imao', InteractionSeverity.contraindicated,
    'Bupropiona inhibe recaptación de dopamina/noradrenalina + IMAOs inhiben degradación — hiperestimulación adrenérgica y serotoninérgica',
    'Crisis hipertensiva, síndrome serotoninérgica, convulsiones — riesgo de muerte',
    'Contraindicado. Esperar ≥14 días después de suspender IMAO antes de iniciar bupropiona',
    'NO UTILIZAR — Síndrome serotoninérgica e crise hipertensiva',
    EvidenceLevel.established,
    {RiskType.serotonin, RiskType.cardiovascular},
    [_kRefFDA, _kRefGG]),

  ('bupropiona', 'carbamazepina', InteractionSeverity.major,
    'Carbamazepina induce CYP3A4/2B6 → reducción significativa de los niveles de bupropiona',
    'Fracaso antidepresivo y en el programa de cesación tabáquica',
    'Aumentar dosis de bupropiona (monitorar efecto). Evaluar alternativa antidepresiva sin interacción con inductores CYP',
    'ALTO RISCO DE FALHA TERAPÊUTICA — Monitorar eficácia da bupropiona',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefMdx, _kRefFDA]),

  ('bupropiona', 'tramadol', InteractionSeverity.major,
    'Ambos reducen el umbral convulsivo por mecanismos independientes — sinergia proconvulsivante',
    'Riesgo muy aumentado de convulsiones generalizadas',
    'Evitar combinación. Si necesario, usar dosis mínima de tramadol con monitorización neurológica. Considerar analgésico alternativo',
    'ALTO RIESGO DE CONVULSIONES — Evitar combinación',
    EvidenceLevel.established,
    {RiskType.cns},
    [_kRefMdx, _kRefFDA]),

  ('bupropiona', 'isrs', InteractionSeverity.moderate,
    'Bupropiona inhibe CYP2D6 → aumenta exposición a fluoxetina, paroxetina y otros SSRIs metabolizados por ese CYP',
    'Síndrome serotoninérgica leve a moderada, elevación de efectos adversos de los SSRIs',
    'Monitorar signos de exceso serotoninérgico. Considerar reducción de dosis del SSRI si aparecen síntomas',
    'Requiere monitorización — riesgo de síndrome serotoninérgica leve',
    EvidenceLevel.probable,
    {RiskType.serotonin, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),

    // ── Aripiprazol ───────────────────────────────────────────────────────────

  ('aripiprazol', 'claritromicina', InteractionSeverity.major,
    'Inhibición del CYP3A4 pela claritromicina aumenta exposição ao aripiprazol em ~90%',
    'Toxicidad por aripiprazol — acatisia intensa, hipotensión, sedación, convulsiones (raro)',
    'Reducir dosis de aripiprazol 50% durante uso de claritromicina. Monitorar efectos adversos',
    'ALTO RIESGO — Reducir dosis de aripiprazol 50%',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.increasedToxicity},
    [_kRefFDA, _kRefMdx]),

  ('aripiprazol', 'fluoxetina', InteractionSeverity.moderate,
    'Fluoxetina inhibe CYP2D6 y CYP3A4 → aumento del 100% en la exposición a aripiprazol',
    'Acatisia, sedación excesiva, hipotensión ortostática',
    'Reducir dosis de aripiprazol 50% con fluoxetina. Monitorar efectos extrapiramidales y PA',
    'Requiere monitorización — reducir dosis de aripiprazol 50%',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.cardiovascular},
    [_kRefFDA, _kRefMdx]),

    // ── Perampanel ────────────────────────────────────────────────────────────

  ('perampanel', 'carbamazepina', InteractionSeverity.major,
    'Carbamazepina induce potentemente CYP3A4 → reducción de ~67% en la exposición a perampanel',
    'Fallo antiepiléptico — concentraciones subterapéuticas de perampanel',
    'Triplicar la dosis objetivo de perampanel cuando se usa con carbamazepina. Titular cuidadosamente con monitorización clínica',
    'ALTO RIESGO DE FALLO ANTIEPILÉPTICO — Triplicar dosis de perampanel',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),

  ('perampanel', 'alcool', InteractionSeverity.major,
    'Perampanel potencializa depresión del SNC por alcohol; puede aumentar comportamientos agresivos/impulsivos',
    'Sedación grave, comportamiento irracional, agresividad, mayor riesgo de accidentes',
    'Contraindicado uso de álcool com perampanel. Orientar paciente explicitamente',
    'ALTO RIESGO — Prohibido alcohol con perampanel',
    EvidenceLevel.established,
    {RiskType.cns},
    [_kRefFDA, _kRefMdx]),

    // ── Rifaximina ────────────────────────────────────────────────────────────

  ('rifaximina', 'anticoncepcional', InteractionSeverity.monitorOnly,
    'Incluso con absorción mínima, puede alterar la flora intestinal que participa en la circulación enterohepática de los anticonceptivos',
    'Reducción teórica (bajo riesgo clínico) de la eficacia anticonceptiva hormonal',
    'Riesgo muy bajo (absorción <1%). Sin embargo, orientar uso de método anticonceptivo de barrera adicional por precaución durante y 7 días después del curso',
    'Solo monitorizar — considerar método contraceptivo de barrera adicional',
    EvidenceLevel.theoretical,
    {RiskType.reducedEfficacy},
    [_kRefMdx, _kRefUT]),

    // ── Nintedanibe ───────────────────────────────────────────────────────────

  ('nintedanibe', 'warfarina', InteractionSeverity.moderate,
    'Nintedanib inhibe P-gp y CYP3A4; interacción potencial aumentando nivel de warfarina',
    'Elevación del INR e risco hemorrágico — intensificado pelo risco de sangrado GI do nintedanibe',
    'Monitorar INR semanalmente. Vigilancia reforzada para signos de sangrado GI',
    'Requiere monitorización de INR semanal — riesgo hemorrágico aditivo',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),

  ('nintedanibe', 'rifampicina', InteractionSeverity.major,
    'Rifampicina induce P-gp y CYP3A4 → reducción de ~60% en los niveles de nintedanib',
    'Fracaso terapéutico en FPI — progresión de la fibrosis',
    'Evitar combinación. Se tratamento de TB necesario, avaliar alternativa antifibrótica ou substituição do antimicrobiano',
    'ALTO RISCO DE FALHA TERAPÊUTICA — Evitar rifampicina com nintedanibe',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),

    // ── Fondaparinux ──────────────────────────────────────────────────────────

  ('fondaparinux', 'isrs', InteractionSeverity.moderate,
    'SSRIs inhiben función plaquetaria (reducción de serotonina plaquetaria) + anticoagulación del fondaparinux',
    'Riesgo aumentado de sangrado — especialmente GI',
    'Monitorar signos de sangrado. Considerar IBP para protección gástrica en uso combinado',
    'Requiere monitorización clínica — riesgo hemorrágico aditivo',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic},
    [_kRefMdx, _kRefUT]),

  ('fondaparinux', 'aine', InteractionSeverity.moderate,
    'AINEs inhiben función plaquetaria y protegen mucosa gástrica — riesgo hemorrágico aditivo',
    'Sangrado GI y en otros sitios',
    'Evitar AINEs con fondaparinux. Usar paracetamol para analgesia. Si AINE necesario, asociar IBP',
    'Requiere monitorización — evitar AINEs; usar paracetamol',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx]),

    // ── Lote 3 — Novas interações ─────────────────────────────────────────────

    // Gabapentina

  ('gabapentina', 'morfina', InteractionSeverity.major,
    'Sinergismo farmacodinámico en la depresión del SNC y del centro respiratorio',
    'Depresión respiratoria potencialmente fatal, sedación profunda, apnea',
    'Evitar combinación ou reduzir doses. Monitorar FR e saturação. Tener naloxona disponible',
    'ALTO RIESGO DE DEPRESIÓN RESPIRATORIA — FDA Black Box Warning',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns},
    [_kRefFDA, _kRefMdx]),

  ('gabapentina', 'opioide', InteractionSeverity.major,
    'Sinergismo farmacodinámico — ambos deprimen SNC y centro respiratorio',
    'Depresión respiratoria grave, sedación excesiva, riesgo de muerte',
    'FDA Black Box Warning. Usar la menor dosis eficaz de cada uno. Monitorar SpO2 continuamente',
    'ALTO RIESGO DE DEPRESIÓN RESPIRATORIA — FDA Black Box Warning',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns},
    [_kRefFDA, _kRefMdx, _kRefGG]),

  ('gabapentina', 'benzodiazepínico', InteractionSeverity.major,
    'Depressão aditiva do SNC pela combinação de anticonvulsivante + benzodiazepínico',
    'Sedación excesiva, depresión respiratoria, risco de queda',
    'Reducir dosis. Monitorar nivel de consciencia. Evitar en ancianos sin soporte monitorizado',
    'ALTO RISCO DE SEDAÇÃO E QUEDA — Reduzir doses e monitorar',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns},
    [_kRefFDA, _kRefMdx]),

    // Sertralina + Tramadol

  ('fenobarbital', 'warfarina', InteractionSeverity.major,
    'Fenobarbital induce potentemente CYP2C9 y CYP3A4, acelerando el metabolismo de warfarina',
    'Reducción marcada del INR — fallo anticoagulante y riesgo trombótico',
    'Monitorar INR semanalmente ao iniciar/suspender fenobarbital. Aumentar dose de warfarina conforme INR',
    'ALTO RIESGO DE FALLO ANTICOAGULANTE — Monitorar INR semanalmente',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel, RiskType.thrombosis},
    [_kRefGG, _kRefMdx]),

  ('fenobarbital', 'apixabana', InteractionSeverity.major,
    'Inducción de CYP3A4 y P-gp por fenobarbital reduce niveles plasmáticos de apixabán en ~50%',
    'Anticoagulación subterapéutica — riesgo de tromboembolismo (ACV, TEP, TVP)',
    'Contraindicado pela bula da apixabana. Substituir anticonvulsivante ou trocar anticoagulante',
    'ALTO RISCO DE TROMBOEMBOLISMO — Apixabana contraindicada com fenobarbital',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.thrombosis},
    [_kRefFDA, _kRefMdx]),

  ('fenobarbital', 'rivaroxabana', InteractionSeverity.major,
    'Inducción de CYP3A4 y P-gp reduce exposición a rivaroxabán significativamente',
    'Pérdida de efecto anticoagulante — riesgo tromboembólico grave',
    'Contraindicado. Evitar combinación. Usar heparina ou warfarina com monitorização rigurosa do INR',
    'ALTO RISCO DE TROMBOEMBOLISMO — Rivaroxabana contraindicada com fenobarbital',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.thrombosis},
    [_kRefFDA, _kRefMdx]),

    // Metformina + Furosemida

  ('metformina', 'furosemida', InteractionSeverity.moderate,
    'Furosemida causa depleción de volumen y reduce clearance renal de metformina; riesgo aumentado de acidosis láctica en contextos de hipovolemia',
    'Acumulación de metformina por reducción de la excreción renal → acidosis láctica (rara pero grave)',
    'Monitorar función renal (creatinina/TFG) ao iniciar ou titular furosemida. Suspender metformina se TFG <30 mL/min',
    'Requiere monitorización renal — suspender metformina si TFG <30',
    EvidenceLevel.probable,
    {RiskType.nephrotoxicity, RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx]),

    // Espironolactona + IECAs

  ('dexmedetomidina', 'metoprolol', InteractionSeverity.moderate,
    'El agonismo alfa-2 central de dexmedetomidina potencia bradicardia e hipotensión de los betabloqueadores',
    'Bradicardia sinusal, hipotensión refractaria — especialmente en hipovolemia',
    'Monitorar FC e PA continuamente em UTI. Reducir dosis de betabloqueador si FC <50 lpm o PA sistólica <90 mmHg',
    'Requiere monitorización hemodinámica continua en UCI',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    [_kRefMdx, _kRefUT]),

  ('dexmedetomidina', 'propofol', InteractionSeverity.moderate,
    'Sedación aditiva del SNC — ambos son agentes de sedación IV',
    'Sedación excesiva, apnea, hipotensión, bradicardia',
    'Reducir dosis de propofol al combinar. Monitorar nivel de sedación (escala RASS), FR y hemodinámica',
    'Requiere monitorización de RASS, FR y hemodinámica',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cardiovascular, RiskType.cns},
    [_kRefMdx, _kRefUT]),

    // Propofol

  ('propofol', 'opioide', InteractionSeverity.moderate,
    'Sinergismo sedativo y depresor respiratorio — especialmente con fentanilo y remifentanilo',
    'Apnea, hipotensión, bradicardia — riesgo aumentado en bolos',
    'Titular cuidadosamente. Tener soporte de vía aérea disponible. Monitorar ETCO2 si posible',
    'Requiere monitorização — risco de apneia em bolus',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cardiovascular},
    [_kRefGG, _kRefMdx]),

    // Fentanila + Benzodiazepínico

  ('fentanila', 'benzodiazepínico', InteractionSeverity.major,
    'Depresión aditiva del SNC — combinación clásica de inducción anestésica con riesgo aumentado',
    'Depresión respiratoria grave, apnea, hipotensión',
    'FDA Black Box Warning para essa combinação em contexto ambulatorial. Em UTI: monitoramento contínuo de SpO2, FR e PA',
    'ALTO RIESGO DE DEPRESIÓN RESPIRATORIA — FDA Black Box Warning',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns},
    [_kRefFDA, _kRefGG]),

    // Esmolol

  ('esmolol', 'verapamil', InteractionSeverity.major,
    'Bloqueo aditivo del nodo AV por betabloqueador IV + bloqueador de calcio — riesgo máximo en vía IV',
    'Asistolia, bloqueo AV completo, colapso hemodinámico',
    'Contraindicado usar IV simultaneamente. Se necesario, espaçar administrações com monitoramento rigoroso de ECG',
    'ALTO RIESGO DE ASISTOLIA — Nunca administrar IV simultáneamente',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),

    // Milrinona

  ('milrinona', 'furosemida', InteractionSeverity.moderate,
    'Furosemida causa hipovolemia e hipopotasemia, amplificando efectos vasodilatadores de milrinona',
    'Hipotensión grave, arritmias por hipopotasemia (potencializa milrinona)',
    'Repor K+ antes de iniciar. Monitorar PA, diuresis y electrolitos cada 4–6h',
    'Requiere monitorización de PA y K+ cada 4–6h',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.hypokalemia},
    [_kRefMdx, _kRefUT]),

    // Levosimendan

  ('levosimendan', 'nitrato', InteractionSeverity.moderate,
    'Ambos son vasodilatadores — levosimendan abre canales K-ATP vasculares; nitratos liberan NO',
    'Hipotensión grave, especialmente en las primeras horas de infusión de levosimendan',
    'Monitorar PA invasiva. Reducir o suspender nitrato durante infusión de levosimendan. Reponer volumen si necesario',
    'Requiere monitorização de PA invasiva durante infusão',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    [_kRefMdx, _kRefUT]),

    // Naloxona

  ('naloxona', 'opioide', InteractionSeverity.major,
    'Antagonismo competitivo en los receptores mu-opioide — revierte analgesia y sedación',
    'Crisis de abstinencia aguda en dependientes, dolor intenso, agitación, hipertensión, edema pulmonar (raro)',
    'Titular en dosis bajas IV (0,04–0,1 mg) para revertir depresión respiratoria sin precipitar abstinencia. Reevaluar cada 2–3 min',
    'Titular naloxona en dosis bajas — riesgo de abstinencia aguda',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.cns},
    [_kRefGG, _kRefFDA]),

    // Labetalol

  ('labetalol', 'verapamil', InteractionSeverity.major,
    'Bloqueo combinado alfa+beta (labetalol) + bloqueo de canal de calcio — depresión cardíaca aditiva',
    'Bradicardia, hipotensión grave, insuficiencia cardíaca aguda',
    'Evitar combinación. Monitorar ECG, FC e PA. Não usar em IC descompensada',
    'ALTO RIESGO CARDIOVASCULAR — Evitar en IC descompensada',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),

    // Aminoglicosídeo + Vancomicina (Lote 3 duplicate — mantido por compatibilidade)
    // (já existe entrada idêntica acima; esta é aceita por _seen deduplication)

    // Fluconazol — CYP2C9/3A4

  ('fluconazol', 'sinvastatina', InteractionSeverity.major,
    'Inhibición del CYP3A4 pelo fluconazol aumenta AUC da sinvastatina em até 14 vezes',
    'Miopatía grave, rabdomiólisis con insuficiencia renal aguda',
    'Suspender simvastatina durante el curso de fluconazol. Reanudar tras 48–72h. Si estatina necesaria, usar pravastatina',
    'RIESGO DE RABDOMIÓLISIS — Suspender simvastatina durante fluconazol',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.nephrotoxicity, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefFDA]),

  ('fluconazol', 'atorvastatina', InteractionSeverity.major,
    'Inhibición del CYP3A4 eleva concentrações de atorvastatina significativamente',
    'Miopatia, rabdomiólisis, lesão renal aguda',
    'Suspender atorvastatina durante fluconazol. Alternativa: pravastatina o rosuvastatina en dosis reducida',
    'RIESGO DE RABDOMIÓLISIS — Suspender atorvastatina durante fluconazol',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefMdx, _kRefFDA]),

  ('fluconazol', 'quetiapina', InteractionSeverity.major,
    'Inhibición de CYP3A4 aumenta exposición a quetiapina con prolongación del QTc',
    'Prolongamento do intervalo QT, torsades de pointes, fibrilação ventricular',
    'Evitar. Si inevitable, reducir dosis de quetiapina 50% y monitorar ECG seriado',
    'ALTO RIESGO DE TORSADES DE POINTES — Reducir quetiapina 50%',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.plasmaLevel},
    [_kRefMdx, _kRefLex]),

  ('fluconazol', 'fenitoína', InteractionSeverity.major,
    'Fluconazol inhibe CYP2C9 y CYP2C19 — principales metabolizadores de fenitoína',
    'Toxicidad por fenitoína: nistagmo, ataxia, diplopía, convulsiones paradójicas',
    'Monitorar nivel sérico de fenitoína (nível-alvo: 10–20 mcg/mL). Reducir dosis de fenitoína anticipadamente',
    'ALTO RIESGO DE TOXICIDAD POR FENITOÍNA — Monitorar nivel sérico',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx]),

    // Fenitoína (indutora)

  ('fenitoína', 'warfarina', InteractionSeverity.major,
    'Fenitoína induce CYP2C9 → mayor metabolismo de warfarina; también puede desplazar warfarina de proteínas (efecto bifásico)',
    'Inicialmente: elevación del INR → riesgo hemorrágico. Crónicamente: reducción del INR → riesgo tromboembólico',
    'Monitorar INR intensivamente al iniciar/ajustar/suspender fenitoína. Ajustar dosis de warfarina según curva',
    'ALTO RISCO — INR instável; monitorar intensivamente ao ajustar fenitoína',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.thrombosis, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),

  ('fenitoína', 'lamotrigina', InteractionSeverity.major,
    'Fenitoína induce UGT y CYP2C19, acelerando glucuronidación de lamotrigina',
    'Reducción del 40–50% en los niveles de lamotrigina → fallo antiepiléptico',
    'Doblar la dosis objetivo de lamotrigina cuando se asocia con fenitoína. Monitorar nivel sérico si disponible',
    'ALTO RIESGO DE FALLO ANTIEPILÉPTICO — Doblar dosis de lamotrigina',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),

    // Topiramato

  ('topiramato', 'valproato', InteractionSeverity.moderate,
    'Interacción farmacodinámica y metabólica: topiramato puede reducir niveles de valproato e inhibir beta-oxidación mitocondrial',
    'Encefalopatía hiperamonémica (sin elevación de aminotransferasas), hipotermia',
    'Monitorar amonio sérico en pacientes sintomáticos (confusión, letargia). Suspender topiramato si encefalopatía',
    'Requiere monitorización de amonio sérico — riesgo de encefalopatía',
    EvidenceLevel.probable,
    {RiskType.cns, RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx]),

  ('topiramato', 'anticoncepcional', InteractionSeverity.moderate,
    'Topiramato induce CYP3A4 en dosis ≥200 mg/día, reduciendo etinilestradiol y progestágeno',
    'Fracaso anticonceptivo — embarazo no planificado',
    'Usar método anticonceptivo no hormonal (DIU de cobre, preservativo). Orientar al paciente explícitamente sobre el riesgo',
    'Requiere método contraceptivo no hormonal — riesgo de fracaso',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),

    // Olanzapina

  ('olanzapina', 'benzodiazepínico', InteractionSeverity.major,
    'Depresión aditiva del SNC — riesgo especialmente elevado con formulación IM de olanzapina',
    'Sedación grave, depresión respiratoria, hipotensión — casos de muerte descritos',
    'Contraindicado usar olanzapina IM com benzodiazepínico parenteral (intervalo mínimo 1h). Monitorar SpO2 e PA',
    'ALTO RIESGO DE MUERTE — Contraindicado olanzapina IM + BDZ parenteral',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cardiovascular, RiskType.cns},
    [_kRefFDA, _kRefMdx]),

  ('olanzapina', 'metoprolol', InteractionSeverity.moderate,
    'Olanzapina inhibe CYP2D6, aumentando exposición a metoprolol',
    'Bradicardia, hipotensión ortostática, broncoespasmo en asmáticos',
    'Monitorar FC e PA. Reducir dosis de metoprolol si FC <55 lpm o sintomático',
    'Requiere monitorização de FC e PA — bradicardia por inhibición CYP2D6',
    EvidenceLevel.probable,
    {RiskType.cardiovascular, RiskType.plasmaLevel},
    [_kRefMdx, _kRefLex]),

    // Mirtazapina

  ('mirtazapina', 'tramadol', InteractionSeverity.major,
    'Mirtazapina tiene acción serotoninérgica y noradrenérgica; tramadol inhibe recaptación de serotonina',
    'Síndrome serotoninérgica — hipertermia, agitación, clonus, diarrea',
    'Evitar combinación. Se analgesia opioide necessária, preferir morfina ou fentanila pura',
    'ALTO RISCO DE SÍNDROME SEROTONINÉRGICA — Preferir morfina',
    EvidenceLevel.probable,
    {RiskType.serotonin},
    [_kRefMdx, _kRefUT]),

  ('mirtazapina', 'imao', InteractionSeverity.contraindicated,
    'Mirtazapina potencializa transmisión serotoninérgica y noradrenérgica; IMAOs bloquean catabolismo de monoaminas',
    'Síndrome serotoninérgica grave potencialmente fatal',
    'ABSOLUTAMENTE CONTRAINDICADO. Intervalo mínimo de 14 días entre IMAO y mirtazapina',
    'NO UTILIZAR — Síndrome serotoninérgica fatal; washout 14 días',
    EvidenceLevel.established,
    {RiskType.serotonin},
    [_kRefFDA, _kRefGG]),

    // Clonazepam + Valproato

  ('benzodiazepínico', 'valproato', InteractionSeverity.moderate,
    'Valproato puede aumentar concentraciones de clonazepam por inhibición metabólica; riesgo de ausencia paradójica',
    'Sedação excessiva, ou paradoxalmente: piora do estado de ausência epiléptica',
    'Monitorar respuesta clínica. Evaluar patrón de ausencias en electroencefalograma si empeora',
    'Requiere monitorización clínica — empeoramiento paradójico de ausencias posible',
    EvidenceLevel.probable,
    {RiskType.cns, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),

    // Acetazolamida

  ('acetazolamida', 'topiramato', InteractionSeverity.moderate,
    'Ambos inhiben anhidrasa carbónica — efecto aditivo en acidosis metabólica y nefrolitiasis',
    'Acidosis metabólica hiperclorémica grave, nefrolitiasis, encefalopatía (raro)',
    'Evitar combinación. Monitorar gasometria e pH urinário. Garantizar hidratación >2L/día',
    'Requiere monitorización de gasometría — acidosis metabólica aditiva',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.increasedToxicity},
    [_kRefMdx, _kRefGG]),

  ('acetazolamida', 'aspirina', InteractionSeverity.major,
    'AAS en dosis analgésicas compite con acetazolamida por secreción tubular renal, elevando nivel de acetazolamida; también puede inducir acidosis',
    'Toxicidad por acetazolamida: letargia, anorexia, parestesias, acidosis grave',
    'Evitar AAS em doses altas com acetazolamida. Se analgesia necessária, usar paracetamol',
    'ALTO RIESGO DE TOXICIDAD — Usar paracetamol en vez de AAS',
    EvidenceLevel.probable,
    {RiskType.increasedToxicity, RiskType.nephrotoxicity},
    [_kRefMdx, _kRefGG]),

    // Clortalidona / Hidroclorotiazida

  ('hidroclorotiazida', 'digoxina', InteractionSeverity.major,
    'La hipopotasemia inducida por tiazídico potencializa toxicidad de digoxina (competencia por bomba Na/K-ATPase)',
    'Toxicidad digitálica: bradiarritmia, BAV, bigeminismo, náuseas, trastornos visuales',
    'Manter K+ sérico >4 mEq/L. Dosar K+ e digoxina regularmente. Suplementar KCl se necesario',
    'ALTO RIESGO DE TOXICIDAD DIGITÁLICA — Mantener K+ >4 mEq/L',
    EvidenceLevel.established,
    {RiskType.hypokalemia, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),

    // Verapamil + Digoxina

  ('verapamil', 'digoxina', InteractionSeverity.major,
    'Verapamil inhibe P-gp y reduce clearance renal de digoxina, aumentando nivel sérico en 50–75%',
    'Toxicidad digitálica: BAV, bradicardia grave, náuseas, visión borrosa',
    'Reducir dosis de digoxina 30–50% al iniciar verapamil. Monitorar nivel sérico de digoxina. ECG seriado',
    'ALTO RIESGO DE TOXICIDAD DIGITÁLICA — Reducir digoxina 30–50%',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.cardiovascular},
    [_kRefGG, _kRefMdx]),

    // Glibenclamida

  ('glibenclamida', 'ciprofloxacino', InteractionSeverity.moderate,
    'Ciprofloxacino inhibe CYP1A2 y puede aumentar secreción de insulina por bloqueo de canales K-ATP pancreáticos',
    'Hipoglucemia — especialmente en ancianos con insuficiencia renal',
    'Monitorar glucemia. Orientar al paciente sobre síntomas de hipoglucemia. Evaluar sustitución del antibiótico',
    'Requiere monitorização de glucemia — hipoglucemia em idosos',
    EvidenceLevel.probable,
    {RiskType.hypoglycemia},
    [_kRefMdx, _kRefUT]),

    // Isossorbida + Sildenafila

  ('rocurônio', 'aminoglicosideo', InteractionSeverity.moderate,
    'Aminoglicosídeos inibem a liberação de acetilcolina na junção neuromuscular — potencialização do bloqueio neuromuscular',
    'Prolongación del bloqueo neuromuscular, dificultad de reversión con neostigmina',
    'Monitorar bloqueo neuromuscular con TOF (train-of-four). Tener sugamadex disponible para reversión en bloqueo prolongado',
    'Requiere monitorización con TOF — tener sugamadex disponible',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx]),

    // Tigeciclina

  ('tigeciclina', 'warfarina', InteractionSeverity.moderate,
    'Tigeciclina pode aumentar INR por mecanismo não completamente elucidado (possivelmente inibição da flora intestinal produtora de vitamina K)',
    'Elevación del INR com risco hemorrágico',
    'Monitorar INR a cada 2–3 dias durante uso de tigeciclina. Ajustar dosis de warfarina según sea necesario',
    'Requiere monitorización de INR cada 2–3 días',
    EvidenceLevel.possible,
    {RiskType.hemorrhagic},
    [_kRefMdx, _kRefFDA]),

    // Ceftolozana + Furosemida

  ('ceftolozana', 'furosemida', InteractionSeverity.monitorOnly,
    'Furosemida puede reducir excreción renal de betalactámicos por competencia tubular',
    'Aumento leve de los niveles plasmáticos de ceftolozana — sin relevancia clínica significativa en la mayoría de los casos',
    'Sin ajuste necesario con función renal normal. Monitorar TFG en pacientes con insuficiencia renal previa',
    'Solo monitorizar — ajuste no necesario con función renal normal',
    EvidenceLevel.theoretical,
    {RiskType.plasmaLevel},
    [_kRefMdx]),

    // Clonixinato de Lisina

  ('clonixinato', 'warfarina', InteractionSeverity.moderate,
    'AINE con inhibición plaquetaria y posible desplazamiento proteico de warfarina',
    'Aumento del INR y riesgo de sangrado',
    'Evitar. Preferir paracetamol como analgésico alternativo. Monitorar INR se uso inevitável',
    'Requiere monitorização de INR — usar paracetamol',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefMdx]),

  ('clonixinato', 'aine', InteractionSeverity.moderate,
    'Riesgo aditivo de toxicidad GI y renal por uso de dos AINEs simultáneamente',
    'Úlcera gástrica, sangrado GI, lesión renal aguda',
    'No asociar dos AINEs. Elegir un único AINE en la menor dosis eficaz por el menor tiempo',
    'Requiere monitorização — evitar uso de dois AINEs simultaneamente',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx]),

    // ══════════════════════════════════════════════════════════════════════════
    // AUDITORIA COMPLETA — LOTE 4 — pares clinicamente críticos faltantes
    // Fonte: Goodman & Gilman 14ª ed., Micromedex 2024, UpToDate 2024,
    //        Lexicomp 2024, FDA Drug Label, ESC/AHA/SBC Guidelines
    // ══════════════════════════════════════════════════════════════════════════

    // ── 1. ANTICOAGULANTES ORAIS DIRETOS (AOD) ────────────────────────────────

  ('apixabana', 'aspirina', InteractionSeverity.major,
    'Doble inhibición hemostática: apixabán bloquea factor Xa; aspirina inhibe COX-1 plaquetaria',
    'Riesgo hemorrágico aumentado 2-3x — hemorragia GI, intracraneal, retroperitoneal',
    'Evitar combinación crônica salvo indicação específica (ex: FA + SCA recente). Se necesario, IBP obligatorio e dose mínima de AAS (100 mg)',
    'RIESGO HEMORRÁGICO GRAVE — Evitar combinación crónica sin indicación formal',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefUT, _kRefFDA]),


  ('apixabana', 'aine', InteractionSeverity.major,
    'AINE inhibe COX-1 plaquetaria y prostaglandinas citoprotectoras gástricas; apixabán bloquea factor Xa',
    'Sangrado GI significativo; riesgo de IRA por reducción de prostaglandinas renales',
    'Evitar combinación. Si inevitable: IBP, menor dose possível de AINE, monitorar sinais de sangrado',
    'RIESGO HEMORRÁGICO + RENAL — Evitar AINEs durante anticoagulación con apixabán',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('rivaroxabana', 'aspirina', InteractionSeverity.major,
    'Doble inhibición hemostática: rivaroxabán bloquea factor Xa; aspirina inhibe COX-1 plaquetaria',
    'Riesgo hemorrágico aumentado — hemorragia GI, intracraneal',
    'Evitar combinación crônica salvo indicação específica (SCA + FA). Se necesario, IBP obligatorio',
    'RIESGO HEMORRÁGICO GRAVE — La combinación aumenta el sangrado en 2-3x',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefUT, _kRefFDA]),


  ('rivaroxabana', 'aine', InteractionSeverity.major,
    'AINE inhibe COX-1 plaquetaria; rivaroxabán bloquea factor Xa — efecto aditivo en sangrado GI',
    'Sangrado GI significativo; lesión renal aguda',
    'Evitar combinación. Si inevitable: IBP, menor dose de AINE, monitorar sinais de sangrado',
    'RIESGO HEMORRÁGICO + RENAL — Evitar AINEs durante anticoagulación con rivaroxabán',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('dabigatrana', 'aspirina', InteractionSeverity.major,
    'Doble inhibición hemostática: dabigatrán inhibe trombina; aspirina inhibe COX-1 plaquetaria',
    'Riesgo hemorrágico aumentado — hemorragia GI, intracraneal',
    'Evitar combinación crônica. Se necesario (pós-SCA + FA), usar dose mínima de AAS + IBP',
    'RIESGO HEMORRÁGICO GRAVE — La combinación aumenta el sangrado significativamente',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefUT, _kRefFDA]),


  ('dabigatrana', 'aine', InteractionSeverity.major,
    'AINE inhibe COX-1 plaquetaria; dabigatrán inhibe trombina — efecto aditivo en el sangrado',
    'Sangramento GI significativo; possível lesão renal',
    'Evitar combinación. Si inevitable: menor dose de AINE por menor tempo, IBP, monitoração rigurosa',
    'RIESGO HEMORRÁGICO — Evitar AINEs durante anticoagulación con dabigatrán',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx]),


  ('apixabana', 'clopidogrel', InteractionSeverity.major,
    'Doble antitrombótica: apixabán anticoagulante + clopidogrel antiagregante — sin beneficio aditivo en la mayoría de indicaciones',
    'Riesgo hemorrágico doblado sin beneficio adicional en la mayoría de los pacientes',
    'Evitar terapia triple. Si FA + stent coronario, preferir doble (AOD + un antiagregante) el menor tiempo posible',
    'TRIPLE ANTITROMBÓTICA — Evitar. Riesgo hemorrágico doblado; usar doble terapia cuando sea posible',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefUT, _kRefFDA]),


  ('rivaroxabana', 'clopidogrel', InteractionSeverity.major,
    'Doble antitrombótica: rivaroxabán anticoagulante + clopidogrel antiagregante',
    'Riesgo hemorrágico doblado sin beneficio adicional en la mayoría de los pacientes',
    'Evitar terapia triple. Si indicado, usar el menor tiempo posible con IBP obligatorio',
    'TRIPLE ANTITROMBÓTICA — Evitar. Riesgo hemorrágico muy aumentado',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefUT, _kRefFDA]),


  ('apixabana', 'fluconazol', InteractionSeverity.major,
    'Fluconazol inhibe CYP3A4 y P-gp, principales vías de metabolismo de apixabán',
    'Aumento significativo dos niveles plasmáticos de apixabana — risco hemorrágico grave',
    'Evitar combinación. Si inevitable, reduzir dose de apixabana e monitorar sinais de sangrado',
    'RIESGO HEMORRÁGICO — Fluconazol eleva niveles de apixabán significativamente',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT, _kRefLex]),


  ('rivaroxabana', 'fluconazol', InteractionSeverity.major,
    'Fluconazol inhibe CYP3A4 y P-gp, principales vías de metabolismo de rivaroxabán',
    'Aumento significativo dos niveles plasmáticos de rivaroxabana — risco hemorrágico grave',
    'Evitar combinación. Si inevitable, monitorar sinais de sangrado rigurosamente',
    'RIESGO HEMORRÁGICO — Fluconazol eleva niveles de rivaroxabán significativamente',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT, _kRefLex]),


  ('apixabana', 'rifampicina', InteractionSeverity.major,
    'Rifampicina es potente inductor de CYP3A4 y P-gp — aumenta metabolismo y eflujo de apixabán',
    'Reducción del 54% en los niveles plasmáticos de apixabán — riesgo de fallo anticoagulante y trombosis',
    'Evitar combinación. Considerar anticoagulante alternativo não dependente de CYP3A4/P-gp',
    'RIESGO DE TROMBOSIS — Rifampicina reduce niveles de apixabán en ~54%',
    EvidenceLevel.established,
    {RiskType.thrombosis, RiskType.reducedEfficacy},
    [_kRefFDA, _kRefUT]),


  ('rivaroxabana', 'rifampicina', InteractionSeverity.major,
    'Rifampicina induce CYP3A4 y P-gp — aumenta metabolismo y eflujo de rivaroxabán',
    'Reducción de ~50% en los niveles plasmáticos de rivaroxabán — fallo anticoagulante',
    'Evitar combinación. Considerar anticoagulante alternativo durante uso de rifampicina',
    'RIESGO DE TROMBOSIS — Rifampicina reduce niveles de rivaroxabán en ~50%',
    EvidenceLevel.established,
    {RiskType.thrombosis, RiskType.reducedEfficacy},
    [_kRefFDA, _kRefUT]),


  ('dabigatrana', 'rifampicina', InteractionSeverity.major,
    'Rifampicina induce P-gp (principal transportador de eflujo de dabigatrán)',
    'Reducción de ~66% en los niveles plasmáticos de dabigatrán — riesgo de trombosis',
    'Evitar combinación. Considerar anticoagulante alternativo durante uso de rifampicina',
    'RIESGO DE TROMBOSIS — Rifampicina reduce niveles de dabigatrán en ~66%',
    EvidenceLevel.established,
    {RiskType.thrombosis, RiskType.reducedEfficacy},
    [_kRefFDA, _kRefUT]),

    // ── 2. WARFARINA — pares faltantes ────────────────────────────────────────

  ('warfarina', 'clopidogrel', InteractionSeverity.major,
    'Mecanismos complementarios: warfarina inhibe coagulación; clopidogrel inhibe agregación plaquetaria vía P2Y12',
    'Sangrado GI grave, hemorragia intracraneal — riesgo 3x mayor que monoterapia',
    'Evitar terapia triple (warfarina + AAS + clopidogrel). Si FA + stent: preferir AOD + antiagregante único',
    'TRIPLE ANTITROMBÓTICA — Riesgo hemorrágico muy elevado; reevaluar indicación',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefUT]),


  ('warfarina', 'carbamazepina', InteractionSeverity.major,
    'Carbamazepina es potente inductor del CYP2C9 y CYP3A4 — aumenta metabolismo de warfarina',
    'Redução significativa do INR — perda do efeito anticoagulante e risco de trombosis',
    'Monitorar INR rigurosamente ao iniciar ou suspender carbamazepina. Ajustar dose conforme INR',
    'RIESGO DE TROMBOSIS — Carbamazepina reduce el efecto anticoagulante de warfarina',
    EvidenceLevel.established,
    {RiskType.thrombosis, RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('warfarina', 'tramadol', InteractionSeverity.major,
    'Tramadol inhibe CYP2C9 (metabolismo de warfarina S) y puede tener efecto anticoagulante aditivo',
    'Elevación del INR — risco de sangrado grave',
    'Monitorar INR próximo ao iniciar ou suspender tramadol. Ajustar dosis de warfarina según sea necesario',
    'RIESGO HEMORRÁGICO — Tramadol eleva INR; monitorar warfarina rigurosamente',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),


  ('warfarina', 'omeprazol', InteractionSeverity.moderate,
    'Omeprazol inhibe CYP2C19 — puede elevar discretamente los niveles de warfarina S',
    'Elevación moderada del INR en algunos pacientes (polimorfismo CYP2C19)',
    'Monitorar INR ao iniciar ou trocar IBP. O efeito é clinicamente relevante apenas em metabolizadores lentos do CYP2C19',
    'Monitorar INR — omeprazol pode elevar discretamente o efeito anticoagulante',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),


  ('warfarina', 'sulfametoxazol', InteractionSeverity.major,
    'SMX-TMP inhibe CYP2C9 (metabolizador de warfarina S) y desplaza warfarina de proteínas plasmáticas',
    'Elevación abrupta del INR en 2-3x — riesgo de sangrado grave',
    'Reducir dosis de warfarina 25-50% al iniciar SMX-TMP. Monitorar INR en 3-5 días. Preferir antibiótico alternativo cuando sea posible',
    'RIESGO HEMORRÁGICO GRAVE — SMX-TMP es uno de los mayores potenciadores del efecto de warfarina',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),

    // ── 3. CLOPIDOGREL — pares faltantes ──────────────────────────────────────

  ('clopidogrel', 'aspirina', InteractionSeverity.moderate,
    'Doble antiagregación plaquetaria: clopidogrel vía P2Y12; aspirina vía COX-1 — complementarios en contexto de síndrome coronario agudo y stent',
    'Riesgo hemorrágico aumentado vs. monoterapia (sangrado GI, equimosis); necesario en indicaciones específicas (SCA, stent coronario)',
    'Indicado em SCA e pós-stent coronário por tempo definido (12 meses/6 meses conforme stent). IBP obligatorio. Evitar fora dessas indicações',
    'DOBLE ANTIAGREGACIÓN — Necesaria en SCA/stent, pero monitorar sangrado. IBP obligatorio',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefUT, _kRefFDA]),

    // ── 4. IECA/ARA-II — pares faltantes ──────────────────────────────────────

  ('enalapril', 'cloreto de potassio', InteractionSeverity.major,
    'IECA reduce excreción renal de potasio por inhibición de aldosterona; suplementación de KCl aditiva',
    'Hiperpotasemia grave — riesgo de arritmias ventriculares fatales, paro cardíaco',
    'Monitorar electrolitos rigurosamente. Reducir o suspender suplementación de KCl. Evitar en insuficiencia renal',
    'RIESGO DE HIPERPOTASEMIA GRAVE — IECA + KCl puede causar arritmia fatal',
    EvidenceLevel.established,
    {RiskType.hyperkalemia, RiskType.arrhythmia},
    [_kRefGG, _kRefUT]),


  ('losartana', 'cloreto de potassio', InteractionSeverity.major,
    'ARA-II reduce excreción renal de potasio por bloqueo del receptor AT1; suplementación de KCl aditiva',
    'Hiperpotasemia grave — riesgo de arritmias ventriculares fatales',
    'Monitorar electrolitos rigurosamente. Reducir o suspender suplementación de KCl. Evitar en insuficiencia renal',
    'RIESGO DE HIPERPOTASEMIA GRAVE — ARA-II + KCl puede causar arritmia fatal',
    EvidenceLevel.established,
    {RiskType.hyperkalemia, RiskType.arrhythmia},
    [_kRefGG, _kRefUT]),


  ('enalapril', 'trimetoprima', InteractionSeverity.major,
    'Trimetoprima bloquea secreción tubular de potasio de forma similar a amilorida; IECA ya reduce excreción de K+',
    'Hiperpotasemia grave — especialmente en ancianos, diabéticos e insuficiencia renal',
    'Monitorar potássio sérico 3-5 dias após início de SMX-TMP em pacientes em uso de IECA/ARA-II',
    'RIESGO DE HIPERPOTASEMIA — SMX-TMP + IECA combinación frecuentemente subestimada',
    EvidenceLevel.established,
    {RiskType.hyperkalemia},
    [_kRefUT, _kRefMdx]),


  ('losartana', 'aine', InteractionSeverity.moderate,
    'AINEs reducen síntesis de prostaglandinas vasodilatadoras renales e antagonizam efeito do ARA-II',
    'Redução do efeito anti-hipertensivo do ARA-II; risco de insuficiencia renal aguda',
    'Evitar uso crónico concomitante. Si necesario, monitorar PA y función renal. Preferir paracetamol como analgésico',
    'Requiere monitorización — AINEs reducen efecto antihipertensivo y aumentan riesgo renal',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.cardiovascular},
    [_kRefGG, _kRefUT]),


  ('enalapril', 'hidroclorotiazida', InteractionSeverity.minor,
    'Combinación sinérgica antihipertensiva — IECA potencializa efecto diurético y viceversa',
    'Hipotensión de primera dosis, especialmente en pacientes con depleción volémica; hiponatremia e hipopotasemia',
    'Combinação frecuentemente intencional e benéfica (formulações fixas disponíveis). Iniciar com doses baixas e titular. Monitorar PA na 1ª semana e electrolitos a cada 3 meses',
    'Combinación sinérgica — vigilar hipotensión de 1ª dosis y electrolitos',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.hypokalemia, RiskType.electrolyte},
    [_kRefGG, _kRefKatz, _kRefUT]),

    // ── 5. ESTATINAS — pares faltantes ────────────────────────────────────────

  ('rosuvastatina', 'fenofibrato', InteractionSeverity.moderate,
    'Fenofibrato inhibe CYP2C9 y puede elevar niveles de rosuvastatina; riesgo farmacodinámico aditivo de miopatía',
    'Miopatía, mialgia, rabdomiólisis — riesgo menor que con gemfibrozil',
    'Monitorar síntomas musculares. Preferir fenofibrato em vez de gemfibrozil quando necesario combinar com estatina. Usar menor dose de estatina',
    'Monitorar síntomas musculares — risco de miopatia com combinação estatina + fibrato',
    EvidenceLevel.probable,
    {RiskType.myopathy},
    [_kRefGG, _kRefMdx, _kRefFDA]),


  ('sinvastatina', 'fenofibrato', InteractionSeverity.moderate,
    'Fenofibrato inhibe glucuronidación de simvastatina y tiene efecto farmacodinámico aditivo de miopatía',
    'Miopatía, mialgia; menor riesgo de rabdomiólisis vs. gemfibrozil',
    'Monitorar síntomas musculares regularmente. Preferir fenofibrato vs. gemfibrozil. Evitar altas doses de sinvastatina',
    'Monitorar síntomas musculares — preferir fenofibrato a gemfibrozil se necesario',
    EvidenceLevel.probable,
    {RiskType.myopathy},
    [_kRefGG, _kRefMdx, _kRefFDA]),


  ('rosuvastatina', 'claritromicina', InteractionSeverity.moderate,
    'Claritromicina inhibe CYP3A4, pero rosuvastatina no es metabolizada por CYP3A4; inhibe OATP1B1 — efecto moderado',
    'Aumento moderado de los niveles de rosuvastatina — riesgo de miopatía',
    'Monitorar síntomas musculares. Reduzir dose de rosuvastatina ou suspender temporariamente durante curso de claritromicina',
    'Monitorar síntomas musculares durante uso de claritromicina com rosuvastatina',
    EvidenceLevel.probable,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),


  ('atorvastatina', 'fenofibrato', InteractionSeverity.moderate,
    'Fenofibrato inibe CYP2C8 e tem efeito farmacodinâmico aditivo; menos interação que com gemfibrozil',
    'Riesgo de miopatía; menor que com gemfibrozil',
    'Combinação aceitável com monitoramento. Usar menor dose eficaz de atorvastatina. Monitorar CPK y síntomas musculares',
    'Monitorar síntomas musculares — combinação geralmente tolerada com vigilância',
    EvidenceLevel.probable,
    {RiskType.myopathy},
    [_kRefMdx, _kRefFDA]),

    // ── 6. DIGOXINA — pares faltantes ─────────────────────────────────────────

  ('digoxina', 'claritromicina', InteractionSeverity.major,
    'Claritromicina inibe P-gp intestinal e renal, principal via de eliminação da digoxina',
    'Aumento de 70-100% nos níveis séricos de digoxina — toxicidad digitálica (náusea, bradiarritmias, BAV)',
    'Reduzir dose de digoxina em 50% ao iniciar claritromicina. Monitorar nivel sérico de digoxina e ECG. Preferir azitromicina se possível',
    'TOXICIDADE DIGITÁLICA — Claritromicina dobra níveis de digoxina; ajustar dose obligatoriamente',
    EvidenceLevel.established,
    {RiskType.arrhythmia, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('digoxina', 'azitromicina', InteractionSeverity.moderate,
    'Azitromicina inibe P-gp intestinal, aumentando absorção de digoxina; menor efeito que claritromicina',
    'Aumento moderado dos níveis séricos de digoxina — risco de toxicidad digitálica',
    'Monitorar sintomas de toxicidad digitálica (náusea, bradicardia) durante uso de azitromicina. Considerar nivel sérico',
    'Monitorar toxicidad digitálica — azitromicina pode elevar níveis de digoxina moderadamente',
    EvidenceLevel.probable,
    {RiskType.arrhythmia, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),


  ('amiodarona', 'ciprofloxacino', InteractionSeverity.major,
    'Ambos prolongam o intervalo QT por bloqueio de canais de potássio (IKr) — efeito aditivo',
    'Torsades de Pointes, taquicardia ventricular polimórfica, fibrilação ventricular — risco de morte súbita',
    'Evitar combinación. Se necesario, monitorar ECG continuamente. Preferir antibiótico sem efeito QT (amoxicilina, beta-lactâmico)',
    'RISCO DE TORSADES DE POINTES — Combinação de dois potentes prolongadores de QT',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefMdx, _kRefUT, _kRefFDA]),


  ('amiodarona', 'quetiapina', InteractionSeverity.major,
    'Ambos prolongam o intervalo QT — amiodarona por bloqueio de IKr; quetiapina por bloqueio de canais de Na+/K+',
    'Torsades de Pointes, taquicardia ventricular, morte súbita cardíaca',
    'Evitar combinación. Se necesario, moniorar ECG seriado e electrolitos. Corrija hipopotasemia/hipomagnesemia',
    'RISCO DE TORSADES DE POINTES — Duplo prolongamento de QT com risco de morte súbita',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefMdx, _kRefUT]),


  ('sotalol', 'ciprofloxacino', InteractionSeverity.contraindicated,
    'Ambos prolongam o intervalo QT por bloqueio de canais de potássio (IKr) — efeito aditivo sinérgico',
    'Torsades de Pointes, fibrilação ventricular, morte súbita — risco muito elevado',
    'CONTRAINDICADO — Não usar ciprofloxacino (ou qualquer quinolona) em pacientes em uso de sotalol. Usar antibiótico alternativo',
    'CONTRAINDICADO — Sotalol + quinolona: risco muito alto de torsades de pointes fatal',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefMdx, _kRefUT, _kRefFDA]),


  ('sotalol', 'azitromicina', InteractionSeverity.contraindicated,
    'Ambos prolongam o intervalo QT — sotalol por bloqueio de IKr; azitromicina por mecanismo similar',
    'Torsades de Pointes, taquicardia ventricular polimórfica, morte súbita',
    'CONTRAINDICADO — Não usar azitromicina em pacientes em uso de sotalol. Usar amoxicilina ou cefalosporina',
    'CONTRAINDICADO — Sotalol + azitromicina: alto risco de torsades de pointes',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefMdx, _kRefUT, _kRefFDA]),


  ('haloperidol', 'ciprofloxacino', InteractionSeverity.major,
    'Ambos prolongam o intervalo QT — haloperidol por bloqueio de IKr; ciprofloxacino por mecanismo similar',
    'Torsades de Pointes, taquicardia ventricular, morte súbita cardíaca',
    'Evitar combinación. Se necesario, monitorar ECG e corrigir electrolitos. Preferir antibiótico sem efeito QT',
    'RISCO DE TORSADES DE POINTES — Duplo prolongamento de QT',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefMdx, _kRefUT]),


  ('quetiapina', 'ciprofloxacino', InteractionSeverity.major,
    'Ambos prolongam o intervalo QT — efeito aditivo',
    'Torsades de Pointes, taquicardia ventricular',
    'Evitar combinación. Monitorar ECG se inevitável. Corrigir hipopotasemia e hipomagnesemia',
    'RISCO DE TORSADES DE POINTES — Duplo prolongamento de QT',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefMdx, _kRefUT]),


  ('quetiapina', 'azitromicina', InteractionSeverity.major,
    'Ambos prolongam o intervalo QT por bloqueio de IKr — efeito aditivo',
    'Torsades de Pointes, taquicardia ventricular',
    'Evitar combinación. Se necesario, monitorar ECG. Preferir amoxicilina ou doxiciclina',
    'RISCO DE TORSADES DE POINTES — Duplo prolongamento de QT',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefMdx, _kRefUT]),


  ('metadona', 'amiodarona', InteractionSeverity.contraindicated,
    'Ambos prolongam fortemente o intervalo QT — metadona por bloqueio de IKr; amiodarona por múltiplos mecanismos',
    'Torsades de Pointes, fibrilação ventricular, morte súbita — risco extremamente alto',
    'CONTRAINDICADO — Não associar. Usar opioide alternativo em pacientes em uso de amiodarona',
    'CONTRAINDICADO — Metadona + amiodarona: risco de morte súbita por arritmia ventricular',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefMdx, _kRefUT, _kRefFDA]),


  ('metadona', 'ciprofloxacino', InteractionSeverity.major,
    'Ciprofloxacino inibe CYP1A2 (metabolismo da metadona) e prolonga QT — efeito duplo',
    'Elevação dos níveis de metadona + prolongamento de QT — Torsades de Pointes, depresión respiratoria',
    'Evitar combinación. Monitorar ECG e sinais de toxicidad por metadona se inevitável',
    'RISCO DE TORSADES + TOXICIDADE — Ciprofloxacino eleva metadona e ambos prolongam QT',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),

    // ── 8. ANTIBIÓTICOS — pares faltantes ─────────────────────────────────────

  ('sulfametoxazol', 'metformina', InteractionSeverity.moderate,
    'Trimetoprima inibe secreção tubular da creatinina — eleva creatinina sérica sem lesão renal real; pode mascarar disfunción renal e levar à manutenção de metformina em dose excessiva',
    'Elevação falsa de creatinina pode induzir descontinuação inadecuada de metformina ou, ao contrário, mascarar IRA real com acúmulo de metformina e acidose lática',
    'Monitorar función renal real (cistatina C ou clearance real) durante uso de SMX-TMP em pacientes com metformina',
    'Monitorar función renal — SMX-TMP eleva creatinina sérica independentemente de IRA real',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    [_kRefUT, _kRefMdx]),


  ('ciprofloxacino', 'metformina', InteractionSeverity.moderate,
    'Ciprofloxacino inibe o transportador OCT2 renal — reduz secreção tubular da metformina',
    'Aumento dos niveles plasmáticos de metformina — risco de acidose lática',
    'Monitorar función renal durante uso concomitante. Suspender metformina se creatinina elevar ou función renal deteriorar',
    'Monitorar — ciprofloxacino pode elevar níveis de metformina e risco de acidose lática',
    EvidenceLevel.probable,
    {RiskType.nephrotoxicity, RiskType.increasedToxicity},
    [_kRefMdx, _kRefUT]),


  ('vancomicina', 'furosemida', InteractionSeverity.major,
    'Furosemida é ototóxica e nefrotóxica; vancomicina também causa nefrotoxicidad — efeito sinérgico',
    'Nefrotoxicidad grave (IRA), ototoxicidad (perda auditiva irreversível)',
    'Monitorar función renal e nivel sérico de vancomicina (AUC/MIC alvo). Evitar furosemida desnecessária. Manter hidratação adecuada',
    'RISCO RENAL E AUDITIVO — Combinação aumenta nefrotoxicidad e ototoxicidad significativamente',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('vancomicina', 'piperacilina-tazobactam', InteractionSeverity.major,
    'Piperacilina-tazobactam aumenta exposição à vancomicina e potencializa nefrotoxicidad por mecanismo não completamente elucidado',
    'Nefrotoxicidad aguda aumentada em 2-3x vs. vancomicina isolada (meta-análises)',
    'Monitorar función renal diariamente. Considerar alternativas (ceftarolina, daptomicina) quando possível. Ajustar dose de vancomicina por AUC/MIC',
    'NEFROTOXICIDADE AUMENTADA — Pip-tazo + vancomicina: risco renal muito elevado',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    [_kRefMdx, _kRefUT]),


  ('aminoglicosideo', 'cisplatina', InteractionSeverity.major,
    'Ambos são nefrotóxicos e ototóxicos — cisplatina por lesão tubular direta; aminoglicosídeo por acúmulo na cóclea e túbulo proximal',
    'Nefrotoxicidad sinérgica grave, ototoxicidad irreversível (surdez)',
    'Evitar combinación se possível. Se necesario, espaçar administrações, monitorar función renal e audiometria, ajustar dose por clearance',
    'NEFRO E OTOTOXICIDADE SINÉRGICA — Ambos lesam rins e cóclea; evitar combinação',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx]),

    // ── 9. HIPOGLICEMIANTES — pares faltantes ─────────────────────────────────

  ('insulina', 'alcool', InteractionSeverity.major,
    'Álcool inibe gliconeogênese hepática e potencializa o efeito hipoglucemiante da insulina',
    'Hipoglucemia grave prolongada — especialmente noturna; o álcool mascara os sintomas adrenérgicos de hipoglucemia',
    'Alertar paciente sobre risco. Monitorar glucemia. Orientar ingestão de carboidrato junto com bebida alcoólica. Evitar consumo de álcool em jejum',
    'RISCO DE HIPOGLICEMIA GRAVE — Álcool potencializa insulina e mascara sintomas de hipoglucemia',
    EvidenceLevel.established,
    {RiskType.hypoglycemia},
    [_kRefGG, _kRefMdx]),


  ('metformina', 'alcool', InteractionSeverity.major,
    'Álcool inibe gliconeogênese hepática e aumenta produção de lactato — metformina também inibe gliconeogênese e reduz metabolismo de lactato',
    'Acidose lática — especialmente em uso crônico ou ingestão aguda de grande quantidade de álcool',
    'Orientar abstinência ou consumo muito moderado. Alertar sobre risco de acidose lática. Monitorar lactato em pacientes sintomáticos',
    'RISCO DE ACIDOSE LÁTICA — Álcool + metformina podem causar acidose lática potencialmente fatal',
    EvidenceLevel.established,
    {RiskType.hepatotoxicity},
    [_kRefGG, _kRefMdx, _kRefFDA]),


  ('sulfonilureia', 'alcool', InteractionSeverity.major,
    'Álcool potencializa efeito hipoglucemiante e inibe gliconeogênese; com algumas sulfonilureias (clorpropamida) causa reação similar ao dissulfiram',
    'Hipoglucemia grave prolongada; rubor facial, náusea e palpitações (reação dissulfiram-like com clorpropamida)',
    'Orientar moderação no consumo de álcool. Monitorar glucemia. Evitar jejum prolongado combinado com álcool',
    'RISCO DE HIPOGLICEMIA — Álcool potencializa sulfonilureias e pode mascarar sintomas',
    EvidenceLevel.established,
    {RiskType.hypoglycemia},
    [_kRefGG, _kRefMdx]),


  ('insulina', 'enalapril', InteractionSeverity.moderate,
    'IECAs aumentam sensibilidade à insulina e podem elevar captação periférica de glicose — mecanismo não completamente elucidado',
    'Hipoglucemia — especialmente em diabéticos tipo 1 e pacientes com doença renal',
    'Monitorar glucemia ao iniciar IECA em pacientes insulinodependentes. Ajustar dose de insulina conforme necesario',
    'Monitorar glucemia — IECAs podem aumentar sensibilidade à insulina e risco de hipoglucemia',
    EvidenceLevel.probable,
    {RiskType.hypoglycemia},
    [_kRefMdx, _kRefUT]),


  ('glibenclamida', 'alcool', InteractionSeverity.major,
    'Álcool potencializa efeito hipoglucemiante das sulfonilureias e inibe gliconeogênese hepática',
    'Hipoglucemia grave y prolongada; pode causar reação dissulfiram-like com rubor, náusea, cefaleia',
    'Orientar evitar álcool em jejum. Monitorar glucemia. Preferir secretagogo com menor risco (gliclazida)',
    'RISCO DE HIPOGLICEMIA GRAVE — Glibenclamida + álcool: hipoglucemia grave e reação dissulfiram',
    EvidenceLevel.established,
    {RiskType.hypoglycemia},
    [_kRefGG, _kRefMdx]),

    // ── 10. IMUNOSSUPRESSORES — pares faltantes ───────────────────────────────

  ('tacrolimo', 'claritromicina', InteractionSeverity.contraindicated,
    'Claritromicina é potente inibidora do CYP3A4 — principal enzima de metabolismo do tacrolimo',
    'Elevação de 5-20x nos níveis séricos de tacrolimo — nefrotoxicidad grave, neurotoxicidad, imunossupressão excessiva',
    'CONTRAINDICADO — Não usar claritromicina em pacientes com tacrolimo. Usar azitromicina ou amoxicilina. Si inevitable: reduzir tacrolimo drásticamente e monitorar nivel sérico diariamente',
    'CONTRAINDICADO — Claritromicina eleva tacrolimo em 5-20x: nefrotoxicidad e neurotoxicidad graves',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.plasmaLevel, RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx, _kRefUT]),

    // DUPLICATA REMOVIDA: tacrolimo+fluconazol — par detalhado mantido como fluconazol+tacrolimo (linha ~2541)


  ('tacrolimo', 'rifampicina', InteractionSeverity.contraindicated,
    'Rifampicina induz fortemente CYP3A4 e P-gp — reduz drásticamente os níveis séricos de tacrolimo',
    'Redução de 80-90% nos níveis de tacrolimo — rejeição aguda do enxerto',
    'CONTRAINDICADO — Usar antibiótico alternativo. Se inevitable, aumentar dose de tacrolimo 3-5x e monitorar nivel sérico diariamente',
    'CONTRAINDICADO — Rifampicina reduz tacrolimo em 80-90%: risco de rejeição aguda',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('tacrolimo', 'aine', InteractionSeverity.major,
    'AINEs são nefrotóxicos; tacrolimo já causa nefrotoxicidad — efeito sinérgico na lesão tubular renal',
    'Insuficiência renal aguda grave — especialmente em pacientes transplantados',
    'Evitar AINEs em pacientes com tacrolimo. Usar paracetamol como analgésico alternativo. Monitorar función renal se inevitável',
    'NEFROTOXICIDADE SINÉRGICA — AINEs + tacrolimo: alto risco de IRA em transplantados',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('ciclosporina', 'aine', InteractionSeverity.major,
    'AINEs reduzem prostaglandinas vasodilatadoras renais; ciclosporina já causa vasoconstrição da arteríola aferente — efeito sinérgico',
    'Insuficiência renal aguda grave, hipertensão',
    'Evitar AINEs em pacientes com ciclosporina. Usar paracetamol como alternativa. Monitorar función renal e PA',
    'NEFROTOXICIDADE SINÉRGICA — AINEs + ciclosporina: alto risco de IRA',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('ciclosporina', 'rifampicina', InteractionSeverity.contraindicated,
    'Rifampicina induz fortemente CYP3A4 e P-gp — metabolismo da ciclosporina drásticamente aumentado',
    'Redução de 80-90% nos níveis séricos de ciclosporina — rejeição aguda do enxerto',
    'CONTRAINDICADO — Usar antibiótico alternativo. Se inevitable, aumentar dose de ciclosporina e monitorar nivel sérico diariamente',
    'CONTRAINDICADO — Rifampicina reduz ciclosporina em 80-90%: risco de rejeição aguda',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('azatioprina', 'sulfametoxazol', InteractionSeverity.major,
    'SMX-TMP inibe enzimas de metabolismo da azatioprina e potencializa mielosupresión',
    'Leucopenia grave, pancitopenia — risco de infecções oportunistas graves',
    'Monitorar hemograma semanalmente durante uso concomitante. Reduzir dose de azatioprina se leucopenia',
    'MIELOSSUPRESSÃO — SMX-TMP + azatioprina: risco elevado de leucopenia grave',
    EvidenceLevel.established,
    {RiskType.myelosuppression, RiskType.infection},
    [_kRefGG, _kRefMdx, _kRefUT]),

    // ── 11. ANALGÉSICOS — pares faltantes ────────────────────────────────────

  ('paracetamol', 'alcool', InteractionSeverity.major,
    'Álcool induz CYP2E1 — via de metabolismo que produz o metabólito hepatotóxico NAPQI; indução crônica aumenta formação de NAPQI',
    'Hepatotoxicidad grave — insuficiência hepática fulminante mesmo com doses terapéuticas de paracetamol em alcoólicos crônicos',
    'Limitar paracetamol a ≤2 g/dia em usuários crônicos de álcool. Monitorar função hepática. Considerar AINE como alternativa analgésica se função hepática normal',
    'HEPATOTOXICIDADE — Álcool crônico + paracetamol: risco de falência hepática mesmo em doses terapéuticas',
    EvidenceLevel.established,
    {RiskType.hepatotoxicity},
    [_kRefGG, _kRefMdx, _kRefFDA]),


  ('tramadol', 'carbamazepina', InteractionSeverity.major,
    'Carbamazepina induz CYP3A4 e CYP2B6 — aumenta metabolismo do tramadol e reduz seus niveles plasmáticos',
    'Redução do efeito analgésico do tramadol; possível síndrome de abstinência em usuários crônicos',
    'Considerar analgésico alternativo. Se necesario manter tramadol, aumentar dose com cautela e monitorar eficácia analgésica',
    'Redução do efeito analgésico — carbamazepina reduz níveis de tramadol',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),

    // ── 12. PSICOTRÓPICOS — pares faltantes ──────────────────────────────────

  ('isrs', 'imao reversivel', InteractionSeverity.contraindicated,
    'Inibição dupla da recaptação e do metabolismo de serotonina — síndrome serotoninérgica',
    'Síndrome serotoninérgica grave: hipertermia, rigidez muscular, mioclonia, alteração do nível de consciência, instabilidade autonômica',
    'CONTRAINDICADO — Aguardar 14 dias após suspender IMAO antes de iniciar SSRI; aguardar 5 meias-vidas do SSRI (14 dias para a maioria, 5 semanas para fluoxetina) antes de iniciar IMAO',
    'CONTRAINDICADO — Síndrome serotoninérgica potencialmente fatal; wash-out obligatorio',
    EvidenceLevel.established,
    {RiskType.serotonin},
    [_kRefGG, _kRefFDA, _kRefUT]),


  ('carbonato de litio', 'aine', InteractionSeverity.major,
    'AINEs inibem síntese de prostaglandinas renais — reduzem excreção renal de lítio, elevando seus níveis séricos',
    'Intoxicação por lítio: tremor grosseiro, ataxia, confusão, convulsiones, coma — efeito em 3-5 dias',
    'Evitar AINEs em pacientes com lítio. Usar paracetamol como alternativa analgésica. Se AINE necesario, monitorar lítio sérico em 3-5 dias',
    'INTOXICAÇÃO POR LÍTIO — AINEs elevam lítio sérico em dias; monitorar ou usar paracetamol',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.cns},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('carbonato de litio', 'furosemida', InteractionSeverity.major,
    'Furosemida causa depleção de sódio — induz reabsorção tubular compensatória de lítio no túbulo proximal',
    'Elevação dos níveis séricos de lítio — intoxicação: tremor, ataxia, confusão, insuficiencia renal',
    'Monitorar lítio sérico 5-7 dias após início ou aumento de dose da furosemida. Ajustar dose de lítio conforme necesario. Manter hidratação e ingestão de sódio',
    'INTOXICAÇÃO POR LÍTIO — Furosemida eleva lítio sérico; monitorar rigurosamente',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.cns},
    [_kRefGG, _kRefMdx]),


  ('olanzapina', 'valproato', InteractionSeverity.moderate,
    'Sinergismo farmacológico: ambos têm efeito sedativo e podem alterar metabolismo hepático mutualmente',
    'Sedação excessiva, ganho de peso aditivo; casos raros de neutropenia com a combinação',
    'Monitorar sedação, hemograma e peso corporal. Usar doses mínimas eficazes de ambos',
    'Monitorar sedação, peso e hemograma — sinergismo olanzapina + valproato',
    EvidenceLevel.probable,
    {RiskType.cns},
    [_kRefMdx, _kRefUT]),


  ('carbonato de litio', 'losartana', InteractionSeverity.major,
    'ARA-II reduzem perfusão renal glomerular e excreção de lítio — mecanismo similar ao IECA',
    'Elevação dos níveis séricos de lítio — risco de intoxicação: tremor, ataxia, confusão, insuficiencia renal',
    'Monitorar lítio sérico em 5-7 dias ao iniciar ARA-II. Ajustar dose conforme necesario. Manter hidratação',
    'INTOXICAÇÃO POR LÍTIO — ARA-II elevam lítio sérico; monitorar como com IECA',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.cns},
    [_kRefGG, _kRefMdx, _kRefUT]),

    // ── 13. ANTIEPILÉPTICOS — pares faltantes ────────────────────────────────

  ('carbamazepina', 'rifampicina', InteractionSeverity.major,
    'Rifampicina induz CYP3A4 — aumenta metabolismo da carbamazepina',
    'Redução dos níveis séricos de carbamazepina — perda do controle de crises epilépticas',
    'Monitorar nivel sérico de carbamazepina ao iniciar rifampicina. Ajustar dose conforme necesario',
    'RISCO DE CRISES — Rifampicina reduz carbamazepina; monitorar níveis séricos',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),


  ('fenitoína', 'carbamazepina', InteractionSeverity.moderate,
    'Interação bidirecional: fenitoína induz CYP3A4 (metabolismo da carbamazepina); carbamazepina induz CYP2C9 (metabolismo da fenitoína)',
    'Variação imprevisível dos níveis de ambos — tanto aumento quanto diminuição possíveis',
    'Monitorar nivel sérico de ambos os antiepilépticos regularmente. Ajustar doses individualmente',
    'Monitorar níveis séricos — interação bidirecional e imprevisível entre fenitoína e carbamazepina',
    EvidenceLevel.established,
    {RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('valproato', 'carbamazepina', InteractionSeverity.moderate,
    'Valproato inibe metabolismo do metabólito ativo da carbamazepina (carbamazepina-10,11-epóxido) — acúmulo do metabólito tóxico',
    'Toxicidade por carbamazepina-epóxido: diplopia, ataxia, náusea, tontura — mesmo com nivel sérico de carbamazepina normal',
    'Monitorar sintomas de toxicidad por carbamazepina. Medir nível do epóxido se disponible. Considerar redução de carbamazepina',
    'Monitorar toxicidad — valproato acumula metabólito tóxico da carbamazepina mesmo com nível normal',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),

    // ── 14. ANTIFÚNGICOS — pares faltantes ───────────────────────────────────

  ('fluconazol', 'midazolam', InteractionSeverity.contraindicated,
    'Fluconazol inibe fortemente CYP3A4 — principal enzima de metabolismo do midazolam',
    'Elevação de 3-5x nos níveis de midazolam — sedação excessiva e prolongada, depresión respiratoria grave',
    'CONTRAINDICADO para midazolam oral. Para midazolam IV em UTI: reduzir dose em 50-75% e monitorar sedação rigurosamente',
    'CONTRAINDICADO via oral — Fluconazol eleva midazolam 3-5x; depresión respiratoria grave',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefFDA]),


  ('fluconazol', 'carbamazepina', InteractionSeverity.moderate,
    'Fluconazol inibe CYP3A4 — eleva níveis séricos de carbamazepina',
    'Toxicidade por carbamazepina: tontura, diplopia, ataxia, hiponatremia',
    'Monitorar nivel sérico de carbamazepina e sintomas de toxicidad ao iniciar fluconazol',
    'Monitorar toxicidad — fluconazol eleva carbamazepina por inhibición do CYP3A4',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),


  ('fluconazol', 'tacrolimo', InteractionSeverity.contraindicated,
    'Fluconazol inibe CYP3A4 e CYP2C19 — principais enzimas de metabolismo do tacrolimo',
    'Elevação de 3-5x nos níveis séricos de tacrolimo — nefrotoxicidad, neurotoxicidad',
    'CONTRAINDICADO em doses plenas — Reduzir tacrolimo drásticamente e monitorar nivel sérico diariamente se inevitável',
    'CONTRAINDICADO — Fluconazol eleva tacrolimo 3-5x; alto risco de nefrotoxicidad',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),

    // ── 15. CARDIOVASCULAR — pares faltantes ─────────────────────────────────

  ('betabloqueador', 'verapamil', InteractionSeverity.contraindicated,
    'Efecto aditivo en el nodo sinusal y AV: betabloqueador reduz frequência e condução; verapamil também — dupla depressão',
    'Bradicardia grave, bloqueio AV completo, asistolia, hipotensão severa, ICC descompensada',
    'CONTRAINDICADO via IV — Para uso oral, apenas sob monitoramento cardíaco rigoroso em situações muito específicas. Evitar na maioria das situações',
    'CONTRAINDICADO IV — Betabloqueador + verapamil IV: risco de asistolia e colapso hemodinâmico',
    EvidenceLevel.established,
    {RiskType.arrhythmia, RiskType.cardiovascular},
    [_kRefGG, _kRefMdx, _kRefFDA]),


  ('hidroclorotiazida', 'aine', InteractionSeverity.moderate,
    'AINEs antagonizam efeito natriurético dos tiazídicos por inhibición das prostaglandinas renais',
    'Redução do efeito diurético e anti-hipertensivo; retenção hídrica; possível piora da función renal',
    'Evitar uso crônico concomitante. Monitorar PA e función renal. Preferir paracetamol como analgésico',
    'Monitorar PA e función renal — AINEs reduzem efeito diurético e anti-hipertensivo dos tiazídicos',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.nephrotoxicity},
    [_kRefGG, _kRefUT]),

    // NOTA: par furosemida+litio consolidado em carbonato de litio+furosemida (acima, linha ~2467)


  ('digoxina', 'quinolona', InteractionSeverity.moderate,
    'Quinolonas alteram flora intestinal que metaboliza digoxina — em 10% dos pacientes ("metabolizadores por Eggerthella lenta"), quinolonas aumentam absorção de digoxina significativamente',
    'Elevação dos níveis séricos de digoxina em subpopulação específica — toxicidad digitálica',
    'Monitorar nivel sérico de digoxina e sintomas de toxicidad (náusea, bradicardia) ao iniciar quinolona',
    'Monitorar nível de digoxina — quinolonas podem elevar níveis em ~10% dos pacientes',
    EvidenceLevel.probable,
    {RiskType.arrhythmia, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),


  ('clopidogrel', 'morfina', InteractionSeverity.major,
    'Morfina retarda esvaziamento gástrico e absorção de clopidogrel — reduz pico plasmático e concentração máxima',
    'Redução de 30-50% nos niveles plasmáticos de clopidogrel ativo — inibição plaquetária subótima durante fase crítica de SCA',
    'Em SCA com morfina: usar ticagrelor ou prasugrel em vez de clopidogrel (não têm essa interação). Se clopidogrel obligatorio: considerar ticagrelor IV ou cangrelor como ponte',
    'FALHA ANTIAGREGANTE — Morfina reduz clopidogrel em 30-50%; preferir ticagrelor em SCA',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.thrombosis},
    [_kRefUT, _kRefFDA]),

    // ── 16. RESPIRATÓRIO / BRONCODILATADORES ─────────────────────────────────

  ('teofilina', 'eritromicina', InteractionSeverity.major,
    'Eritromicina inibe CYP1A2 e CYP3A4 — principais enzimas de metabolismo da teofilina',
    'Elevação dos níveis séricos de teofilina — toxicidad: náusea, vômito, taquicardia, convulsiones, arritmias',
    'Reduzir dose de teofilina em 25-50% ao iniciar eritromicina. Monitorar nivel sérico de teofilina. Preferir azitromicina (menor interação)',
    'TOXICIDADE POR TEOFILINA — Eritromicina eleva teofilina; monitorar nivel sérico',
    EvidenceLevel.established,
    {RiskType.arrhythmia, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('ritonavir', 'sildenafila', InteractionSeverity.contraindicated,
    'Ritonavir inibe fortemente CYP3A4 — principal via de metabolismo da sildenafila',
    'Elevação de 11x nos níveis de sildenafila — hipotensão grave, priapismo, perda visual',
    'CONTRAINDICADO — Não usar sildenafila para disfunção erétil em pacientes com ritonavir. Para hipertensão pulmonar: dose máxima 20 mg/48h com monitoramento rigoroso',
    'CONTRAINDICADO — Ritonavir eleva sildenafila 11x: hipotensão grave e priapismo',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),


  ('ritonavir', 'metadona', InteractionSeverity.major,
    'Ritonavir induz CYP3A4 e CYP2B6 — aumenta metabolismo da metadona e também prolonga QT',
    'Redução dos níveis de metadona (síndrome de abstinência) + risco de QT prolongado',
    'Monitorar sintomas de abstinência ao iniciar ritonavir. Ajustar dose de metadona. Monitorar ECG',
    'RISCO DE ABSTINÊNCIA + QT — Ritonavir reduz metadona e ambos prolongam QT',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),

    // ── FLUCONAZOL + BENZODIAZEPÍNICOS (par ausente — bug crítico alprazolam+fluconazol) ──

  ('fluconazol', 'benzodiazepínico', InteractionSeverity.major,
    'Fluconazol inibe fortemente CYP3A4 — principal via de metabolismo de alprazolam, diazepam, clonazepam e lorazepam',
    'Aumento de 2-4x nos niveles plasmáticos de benzodiazepínicos (alprazolam, diazepam, clonazepam). Sedação excessiva, depressão do SNC e risco de depresión respiratoria. Lorazepam é menos afetado (metabolismo por glucuronidação).',
    'Monitorar sedação e função respiratória. Reduzir dose do benzodiazepínico em 50% ao iniciar fluconazol. Preferir lorazepam quando possível (menos dependente de CYP3A4). Evitar alprazolam e diazepam prolongados com fluconazol sistêmico.',
    'SEDAÇÃO AUMENTADA — Fluconazol inibe CYP3A4; reduzir dose do benzodiazepínico em 50%',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.respiratoryDepression, RiskType.plasmaLevel},
    [_kRefGG, _kRefUT]),




  ('aspirina', 'aine', InteractionSeverity.major,
    'Competição pelo sítio de ligação da COX-1 plaquetária + inibição dupla de prostaglandinas protetoras da mucosa gástrica',
    'Antagonismo do efeito cardioprotetor do AAS; risco elevado de hemorragia GI',
    'Evitar AINEs não seletivos com AAS. Se analgesia necessária, preferir paracetamol. Se AINE inevitável, tomar AAS 2h antes e usar IBP',
    'ANTAGONISMO + SANGRAMENTO GI — evitar AINEs com AAS; usar paracetamol',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.reducedEfficacy},
    [_kRefGG, _kRefFDA]),


  ('aspirina', 'corticosteroide sistemico', InteractionSeverity.major,
    'Corticosteroide reduz proteção da mucosa gástrica (diminui prostaglandinas) + AAS inibe COX — efeito duplo lesivo',
    'Riesgo muy elevado de úlcera péptica y hemorragia GI',
    'Associar IBP obligatoriamente. Minimizar dose e duração do corticosteroide. Monitorar sintomas GI',
    'ALTO RISCO GI — AAS + corticosteroide: IBP obligatorio',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx]),


  ('aspirina', 'metotrexato', InteractionSeverity.major,
    'AAS reduz excreção renal e tubular do metotrexato por competição',
    'Elevação dos níveis de metotrexato — toxicidad hematológica, mucosites, nefrotoxicidad',
    'Evitar em doses altas de metotrexato. Em baixas doses (artrite), monitorar hemograma e función renal',
    'TOXICIDADE DE METOTREXATO — AAS reduz clearance renal; monitorar',
    EvidenceLevel.established,
    {RiskType.increasedToxicity, RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx]),


  ('aspirina', 'carbonato de litio', InteractionSeverity.moderate,
    'AAS pode interferir levemente na excreção renal de lítio via prostaglandinas renais',
    'Elevação modesta dos níveis séricos de lítio',
    'Monitorar litemia ao iniciar ou aumentar dose de AAS em pacientes com lítio',
    'Monitorar litemia — AAS pode elevar lítio levemente',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel},
    [_kRefGG]),


  ('aspirina', 'metformina', InteractionSeverity.minor,
    'AAS pode potencializar levemente o efeito hipoglucemiante da metformina',
    'Hipoglucemia leve em doses altas de AAS (>3 g/dia)',
    'Sem restrição em doses cardioprotetoras (≤100 mg/dia). Monitorar glucemia se doses analgésicas elevadas',
    'Doses altas de AAS podem aumentar efeito hipoglucemiante',
    EvidenceLevel.probable,
    {RiskType.hypoglycemia},
    [_kRefGG]),


  ('apixabana', 'heparina', InteractionSeverity.contraindicated,
    'Dupla anticoagulação: inibição fator Xa (apixabana) + inibição múltipla da cascata (heparina)',
    'Risco extremo de hemorragia grave',
    'CONTRAINDICADO em uso concomitante. Usar apenas em transição monitorada (bridging). Nunca usar simultaneamente em dose plena',
    'CONTRAINDICADO — dupla anticoagulação plena: risco de hemorragia fatal',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx]),


  ('apixabana', 'warfarina', InteractionSeverity.contraindicated,
    'Dupla anticoagulação: inibição fator Xa + inibição vitamina K',
    'Risco extremo de hemorragia grave',
    'CONTRAINDICADO. Nunca usar juntos. Na transição warfarina → apixabana, suspender warfarina e iniciar apixabana quando INR <2,0',
    'CONTRAINDICADO — dupla anticoagulação plena',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefFDA]),


  ('apixabana', 'dabigatrana', InteractionSeverity.contraindicated,
    'Dupla anticoagulação com dois mecanismos distintos — risco hemorrágico extremo',
    'Hemorragia fatal',
    'CONTRAINDICADO. Nunca usar dois anticoagulantes de ação direta simultaneamente',
    'CONTRAINDICADO — dois anticoagulantes diretos juntos',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG]),


  ('apixabana', 'rivaroxabana', InteractionSeverity.contraindicated,
    'Dois inibidores do fator Xa — anticoagulação excessiva',
    'Hemorragia grave',
    'CONTRAINDICADO. Nunca combinar dois inibidores do fator Xa',
    'CONTRAINDICADO — dois inibidores do fator Xa',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG]),


  ('apixabana', 'fondaparinux', InteractionSeverity.contraindicated,
    'Dois inibidores do fator Xa por mecanismos distintos — anticoagulação excessiva',
    'Risco muito elevado de hemorragia',
    'CONTRAINDICADO em uso concomitante pleno. Evitar sobreposição',
    'CONTRAINDICADO — dupla inibição fator Xa',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG]),


  ('dabigatrana', 'heparina', InteractionSeverity.contraindicated,
    'Inibição direta da trombina (dabigatrana) + anticoagulação múltipla (heparina) — dupla anticoagulação',
    'Risco extremo de hemorragia grave',
    'CONTRAINDICADO em uso simultâneo pleno. Apenas em transições controladas (suspender heparina antes de iniciar dabigatrana)',
    'CONTRAINDICADO — dupla anticoagulação plena',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx]),


  ('dabigatrana', 'warfarina', InteractionSeverity.contraindicated,
    'Dupla anticoagulação por mecanismos distintos',
    'Risco extremo de hemorragia',
    'CONTRAINDICADO. Na transição, iniciar dabigatrana quando INR <2,0 após suspensão de warfarina',
    'CONTRAINDICADO — dupla anticoagulação',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefFDA]),


  ('dabigatrana', 'rivaroxabana', InteractionSeverity.contraindicated,
    'Dois anticoagulantes de ação direta com mecanismos distintos',
    'Hemorragia grave',
    'CONTRAINDICADO. Nunca combinar dois anticoagulantes diretos',
    'CONTRAINDICADO — dois anticoagulantes diretos',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG]),


  ('dabigatrana', 'fondaparinux', InteractionSeverity.contraindicated,
    'Inibição trombina + inibição fator Xa — dupla anticoagulação',
    'Hemorragia grave',
    'CONTRAINDICADO em uso simultâneo pleno',
    'CONTRAINDICADO — dupla anticoagulação',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG]),


  ('dabigatrana', 'clopidogrel', InteractionSeverity.major,
    'Anticoagulação direta (trombina) + antiagregação P2Y12 — sinergia hemorrágica',
    'Aumento significativo do risco de sangrado maior',
    'Usar somente quando indicação estabelecida. Usar IBP. Período mínimo de terapia combinada',
    'SANGRAMENTO AUMENTADO — dabigatrana + clopidogrel: usar IBP',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx]),


  ('heparina', 'warfarina', InteractionSeverity.moderate,
    'Dupla anticoagulação — usada intencionalmente em transição, mas com risco hemorrágico aditivo',
    'Hemorragia se sobreposição prolongada ou INR supraterapéutico',
    'Sobreposição de 5 dias com INR >2,0 por 2 dias consecutivos antes de suspender heparina. Monitorar TTPA e INR',
    'TRANSIÇÃO CONTROLADA — sobreposição 5 dias; suspender heparina quando INR ≥2,0',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx]),


  ('heparina', 'clopidogrel', InteractionSeverity.major,
    'Anticoagulação (heparina) + antiagregação P2Y12 (clopidogrel) — sinergia hemorrágica',
    'Aumento do risco de sangrado maior, especialmente em procedimentos invasivos',
    'Combinação usada em SCA — monitorar ativamente. Cessar heparina quando clinicamente possível',
    'SANGRAMENTO AUMENTADO — heparina + clopidogrel: monitorar em SCA',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx]),


  ('heparina', 'rivaroxabana', InteractionSeverity.contraindicated,
    'Dois anticoagulantes com mecanismos distintos — dupla anticoagulação',
    'Hemorragia grave',
    'CONTRAINDICADO em uso simultâneo pleno. Apenas em transição controlada',
    'CONTRAINDICADO — dupla anticoagulação plena',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG]),


  ('heparina', 'fondaparinux', InteractionSeverity.contraindicated,
    'Dois anticoagulantes com ação anti-Xa — anticoagulação excessiva',
    'Hemorragia grave',
    'CONTRAINDICADO em uso simultâneo',
    'CONTRAINDICADO — dois anticoagulantes anti-Xa',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG]),


  ('rivaroxabana', 'warfarina', InteractionSeverity.contraindicated,
    'Dois anticoagulantes por mecanismos distintos — dupla anticoagulação',
    'Hemorragia grave',
    'CONTRAINDICADO. Na transição rivaroxabana → warfarina, manter rivaroxabana até INR ≥2,0',
    'CONTRAINDICADO — dupla anticoagulação',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefFDA]),


  ('rivaroxabana', 'fondaparinux', InteractionSeverity.contraindicated,
    'Dois inibidores do fator Xa — anticoagulação excessiva',
    'Hemorragia grave',
    'CONTRAINDICADO em uso simultâneo',
    'CONTRAINDICADO — dois inibidores fator Xa',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG]),


  ('fondaparinux', 'warfarina', InteractionSeverity.major,
    'Inibição fator Xa (fondaparinux) + inibição vitamina K (warfarina) — anticoagulação aditiva',
    'Hemorragia grave se sobreposição prolongada',
    'Usar somente em transição controlada. Monitorar INR e ajustar fondaparinux conforme protocolo',
    'ANTICOAGULAÇÃO ADITIVA — transição controlada somente',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx]),


  ('fondaparinux', 'clopidogrel', InteractionSeverity.major,
    'Anticoagulação + antiagregação — sinergia hemorrágica',
    'Aumento do risco de sangrado maior',
    'Monitorar ativamente. Usar somente quando indicação estabelecida',
    'SANGRAMENTO AUMENTADO — fondaparinux + clopidogrel',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG]),


  ('clopidogrel', 'aine', InteractionSeverity.major,
    'Antiagregação + lesão mucosa e inibição plaquetária pelos AINEs',
    'Hemorragia GI aumentada',
    'Evitar AINEs. Usar paracetamol. Se AINE inevitável, associar IBP',
    'SANGRAMENTO GI AUMENTADO — evitar AINEs com clopidogrel',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx]),


  ('clopidogrel', 'fluoxetina', InteractionSeverity.moderate,
    'Fluoxetina inibe CYP2C19 — reduz ativação do clopidogrel',
    'Possível redução do efeito antiagregante',
    'Preferir sertralina ou escitalopram (menor inibição de CYP2C19) em pacientes com clopidogrel',
    'REDUÇÃO ANTIAGREGANTE — preferir sertralina ao usar clopidogrel',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),


  ('amiodarona', 'betabloqueador', InteractionSeverity.major,
    'Efecto aditivo en el nodo sinusal y AV — amiodarona já prolonga período refratário + betabloqueador reduz FC e condução',
    'Bradicardia grave, bloqueio AV de alto grau, asistolia',
    'Monitorar ECG continuamente. Evitar combinación IV simultânea. Se oral, titulação lenta com monitoramento cardíaco',
    'BRADICARDIA GRAVE — amiodarona + betabloqueador: monitorar ECG',
    EvidenceLevel.established,
    {RiskType.arrhythmia, RiskType.other},
    [_kRefGG, _kRefMdx]),


  ('amiodarona', 'diltiazem', InteractionSeverity.major,
    'Efeito aditivo no nó AV — amiodarona e diltiazem ambos deprimem condução AV',
    'Bloqueio AV completo, bradicardia grave, hipotensão',
    'Evitar combinación. Se necesario, monitorar ECG continuamente e ter marca-passo disponible',
    'BLOQUEIO AV — amiodarona + diltiazem: monitorar ECG rigurosamente',
    EvidenceLevel.established,
    {RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),


  ('amiodarona', 'propranolol', InteractionSeverity.major,
    'Amiodarona inibe CYP2D6 → eleva nível de propranolol + efeito aditivo cronotrópico negativo',
    'Bradicardia grave, bloqueio AV, hipotensão',
    'Reduzir dose de propranolol. Monitorar FC e pressão arterial',
    'BRADICARDIA — amiodarona eleva propranolol via CYP2D6',
    EvidenceLevel.established,
    {RiskType.arrhythmia, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('amiodarona', 'ondansetrona', InteractionSeverity.major,
    'Prolongación aditiva del QT — amiodarona (classe III) + ondansetrona (bloqueio canal hERG)',
    'Torsades de Pointes',
    'Evitar combinación. Se uso necesario, monitorar QTc. Substituir por metoclopramida ou domperidona',
    'PROLONGAMENTO QT — amiodarona + ondansetrona: monitorar QTc',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),


  ('amiodarona', 'fenitoína', InteractionSeverity.major,
    'Amiodarona inibe CYP2C9 → eleva nível de fenitoína; fenitoína induz CYP3A4 → reduz nível de amiodarona',
    'Toxicidade por fenitoína (nistagmo, ataxia, confusão) e possível redução da eficácia da amiodarona',
    'Monitorar nivel sérico de fenitoína. Reduzir dose de fenitoína em 30-50% ao iniciar amiodarona',
    'TOXICIDADE FENITOÍNA — amiodarona eleva via CYP2C9; monitorar nível',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx]),


  ('amiodarona', 'levotiroxina', InteractionSeverity.major,
    'Amiodarona inibe conversão periférica de T4 em T3 e contém 37% de iodo — interfere profundamente na função tireoidiana',
    'Hipotireoidismo ou hipertireoidismo induzido pela amiodarona — ambos com risco cardíaco',
    'Monitorar TSH, T4 livre e T3 a cada 6 meses. Ajustar levotiroxina conforme função tireoidiana. Acompanhamento com endocrinologia',
    'DISFUNÇÃO TIREOIDIANA — monitorar TSH/T4 a cada 6 meses',
    EvidenceLevel.established,
    {RiskType.other},
    [_kRefGG, _kRefMdx]),


  ('amiodarona', 'ciclosporina', InteractionSeverity.major,
    'Amiodarona inibe CYP3A4 e P-gp — aumenta nível de ciclosporina',
    'Nefrotoxicidad, neurotoxicidad por elevação de ciclosporina',
    'Reduzir dose de ciclosporina. Monitorar nivel sérico e función renal',
    'TOXICIDADE CICLOSPORINA — amiodarona eleva via CYP3A4/P-gp',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('amiodarona', 'metformina', InteractionSeverity.minor,
    'Amiodarona pode alterar levemente a función renal — risco de acúmulo de metformina',
    'Risco teórico de acidose lática em disfunción renal',
    'Monitorar función renal periodicamente em pacientes com amiodarona e metformina',
    'Monitorar función renal — amiodarona pode afetar clearance de metformina',
    EvidenceLevel.theoretical,
    {RiskType.other},
    [_kRefGG]),


  ('betabloqueador', 'diltiazem', InteractionSeverity.major,
    'Efeito aditivo na depressão do nó sinusal e AV — betabloqueador + diltiazem (bloqueador canal Ca não-DHP)',
    'Bradicardia grave, bloqueio AV de 2º/3º grau, hipotensão, ICC descompensada',
    'Contraindicado por via IV simultânea. Oral com monitoramento cardíaco. ECG antes e após início',
    'BRADICARDIA/BLOQUEIO AV — evitar combinação IV; monitorar ECG se oral',
    EvidenceLevel.established,
    {RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),


  ('betabloqueador', 'sotalol', InteractionSeverity.major,
    'Sotalol tem propriedades betabloqueadoras + prolongamento QT — efeito aditivo com betabloqueador',
    'Bradicardia, bloqueio AV, prolongamento QT, Torsades de Pointes',
    'Evitar combinación. Se necesario, monitorar ECG e FC continuamente',
    'BRADICARDIA + PROLONGAMENTO QT — evitar betabloqueador + sotalol',
    EvidenceLevel.established,
    {RiskType.arrhythmia, RiskType.qtProlongation},
    [_kRefGG, _kRefMdx]),


  ('betabloqueador', 'clonidina', InteractionSeverity.major,
    'Na retirada abrupta de clonidina com betabloqueador em uso, há hipertensão de rebote grave — betabloqueador bloqueia vasodilatação beta-mediada',
    'Crise hipertensiva grave na retirada de clonidina',
    'Retirar betabloqueador antes de descontinuar clonidina. Nunca suspender clonidina abruptamente',
    'CRISE HIPERTENSIVA — retirar betabloqueador ANTES de suspender clonidina',
    EvidenceLevel.established,
    {RiskType.other},
    [_kRefGG, _kRefMdx]),


  ('betabloqueador', 'alfa-bloqueador', InteractionSeverity.moderate,
    'Bloqueio alfa (vasodilatação periférica) + bloqueio beta (impede taquicardia reflexa compensatória)',
    'Hipotensão ortostática grave, síncope — especialmente na primeira dose',
    'Iniciar alfa-bloqueador com dose baixa. Monitorar PA após primeira dose. Orientar paciente sobre risco de síncope',
    'HIPOTENSÃO ORTOSTÁTICA — iniciar alfa-bloqueador com dose mínima',
    EvidenceLevel.established,
    {RiskType.other},
    [_kRefGG, _kRefMdx]),


  ('betabloqueador', 'nitrato', InteractionSeverity.moderate,
    'Vasodilatação pelo nitrato + redução da taquicardia reflexa pelo betabloqueador — efeito hemodinâmico aditivo',
    'Hipotensão sinérgica, tontura, síncope',
    'Combinação geralmente benéfica em angina. Titular doses com monitoramento de PA. Orientar mudança postural lenta',
    'HIPOTENSÃO ADITIVA — monitorar PA; combinação útil em angina',
    EvidenceLevel.established,
    {RiskType.other},
    [_kRefGG]),


  ('betabloqueador', 'sildenafila', InteractionSeverity.moderate,
    'Sildenafila causa vasodilatação; betabloqueador bloqueia taquicardia reflexa compensatória',
    'Hipotensão sintomática, tontura, síncope',
    'Monitorar PA. Evitar uso próximo ao horário do betabloqueador. Cautela em pacientes com IC',
    'HIPOTENSÃO — monitorar PA com betabloqueador + sildenafila',
    EvidenceLevel.established,
    {RiskType.other},
    [_kRefGG, _kRefMdx]),


  ('digoxina', 'diltiazem', InteractionSeverity.moderate,
    'Diltiazem inibe P-gp → aumenta nível de digoxina + efeito aditivo no nó AV',
    'Toxicidade por digoxina e bradicardia',
    'Monitorar nivel sérico de digoxina ao iniciar diltiazem. Reduzir dose de digoxina se necesario',
    'TOXICIDADE DIGOXINA — diltiazem eleva via P-gp; monitorar nível',
    EvidenceLevel.established,
    {RiskType.arrhythmia, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('digoxina', 'betabloqueador', InteractionSeverity.major,
    'Efeito aditivo no nó AV — digoxina (vagotônico) + betabloqueador (cronotrópico negativo)',
    'Bradicardia grave, bloqueio AV de alto grau',
    'Monitorar FC e ECG. Titular doses. Evitar combinación em disfunção sinusal',
    'BRADICARDIA/BLOQUEIO AV — digoxina + betabloqueador: monitorar ECG',
    EvidenceLevel.established,
    {RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),


  ('digoxina', 'metoprolol', InteractionSeverity.major,
    'Efeito aditivo cronotrópico negativo no nó sinusal e AV',
    'Bradicardia grave, bloqueio AV',
    'Monitorar FC e ECG. Manter FC >50 bpm. Titular doses gradualmente',
    'BRADICARDIA — digoxina + metoprolol: manter FC >50 bpm',
    EvidenceLevel.established,
    {RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),


  ('digoxina', 'aine', InteractionSeverity.moderate,
    'AINEs reduzem filtração glomerular → diminuem clearance renal da digoxina',
    'Elevação do nivel sérico de digoxina — toxicidad',
    'Evitar AINEs em pacientes com digoxina. Usar paracetamol. Se AINE necesario, monitorar nível de digoxina',
    'TOXICIDADE DIGOXINA — AINEs reduzem clearance renal',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx]),


  ('digoxina', 'carbonato de litio', InteractionSeverity.moderate,
    'Depleção de sódio pelo lítio e alterações renais podem elevar nível de digoxina',
    'Toxicidade por digoxina',
    'Monitorar nivel sérico de digoxina e ECG quando usar com lítio',
    'Monitorar digoxina — lítio pode elevar nivel sérico',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel},
    [_kRefGG]),


  ('diltiazem', 'sinvastatina', InteractionSeverity.major,
    'Diltiazem inibe CYP3A4 — aumenta AUC da sinvastatina em 3-4x',
    'Risco elevado de miopatia e rabdomiólisis',
    'Limitar sinvastatina a 10 mg/dia com diltiazem. Preferir pravastatina ou rosuvastatina',
    'RISCO DE RABDOMIÓLISE — limitar sinvastatina a 10mg/dia',
    EvidenceLevel.established,
    {RiskType.myopathy},
    [_kRefGG, _kRefMdx]),


  ('diltiazem', 'ciclosporina', InteractionSeverity.major,
    'Diltiazem inibe CYP3A4 → aumenta nível de ciclosporina em 30-50%',
    'Nefrotoxicidad, neurotoxicidad por hiperciclosporinemia',
    'Monitorar nivel sérico de ciclosporina. Reduzir dose de ciclosporina',
    'TOXICIDADE CICLOSPORINA — diltiazem eleva via CYP3A4',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('diltiazem', 'midazolam', InteractionSeverity.moderate,
    'Diltiazem inibe CYP3A4 — aumenta nível de midazolam',
    'Sedação excessiva e prolongada',
    'Reduzir dose de midazolam. Monitorar nível de consciência',
    'SEDAÇÃO AUMENTADA — diltiazem eleva midazolam via CYP3A4',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('diltiazem', 'carbamazepina', InteractionSeverity.major,
    'Diltiazem inibe CYP3A4 → eleva carbamazepina; carbamazepina induz CYP3A4 → reduz diltiazem',
    'Toxicidade por carbamazepina (diplopia, ataxia) + redução da eficácia do diltiazem',
    'Monitorar nível de carbamazepina. Considerar alternativa ao diltiazem',
    'TOXICIDADE CARBAMAZEPINA — diltiazem inibe metabolismo; monitorar',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx]),


  ('dronedarona', 'betabloqueador', InteractionSeverity.major,
    'Dronedarona tem leve ação betabloqueadora + efeito aditivo com betabloqueador na depressão do nó AV',
    'Bradicardia grave, bloqueio AV',
    'Monitorar ECG. Iniciar betabloqueador com dose baixa. Manter FC >50 bpm',
    'BRADICARDIA — dronedarona + betabloqueador: monitorar FC e ECG',
    EvidenceLevel.established,
    {RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),


  ('dronedarona', 'diltiazem', InteractionSeverity.major,
    'Dronedarona inibe CYP3A4 e também tem efeito no nó AV; diltiazem inibe CYP3A4 eleva dronedarona + efeito aditivo AV',
    'Bradicardia grave, bloqueio AV, prolongamento QT',
    'Evitar combinación. Se necesario, monitorar ECG continuamente',
    'BLOQUEIO AV + BRADICARDIA — evitar dronedarona + diltiazem',
    EvidenceLevel.established,
    {RiskType.arrhythmia, RiskType.qtProlongation},
    [_kRefGG, _kRefMdx]),


  ('nitrato', 'alfa-bloqueador', InteractionSeverity.major,
    'Dupla vasodilatação — nitrato (venodilatação) + alfa-bloqueador (vasodilatação arterial)',
    'Hipotensão grave, síncope ortostática',
    'Iniciar alfa-bloqueador com dose mínima. Monitorar PA. Evitar combinación em hipotensão basal',
    'HIPOTENSÃO GRAVE — nitrato + alfa-bloqueador: monitorar PA',
    EvidenceLevel.established,
    {RiskType.other},
    [_kRefGG, _kRefMdx]),


  ('nitrato', 'alcool', InteractionSeverity.major,
    'Álcool causa vasodilatação + nitrato é vasodilatador — efeito hemodinâmico aditivo',
    'Hipotensão grave, síncope, taquicardia reflexa',
    'Evitar álcool durante uso de nitratos. Orientar paciente sobre risco de síncope',
    'HIPOTENSÃO — evitar álcool com nitratos',
    EvidenceLevel.established,
    {RiskType.other},
    [_kRefGG]),


  ('sotalol', 'haloperidol', InteractionSeverity.major,
    'Dois prolongadores de QT por bloqueio de canais hERG — efeito aditivo',
    'Torsades de Pointes, fibrilação ventricular',
    'Evitar. Se necesario, monitorar QTc rigurosamente. Medir K+ e Mg2+',
    'TORSADE DE POINTES — sotalol + haloperidol: monitorar QTc',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),


  ('sotalol', 'ondansetrona', InteractionSeverity.major,
    'Prolongación aditiva del QT',
    'Torsades de Pointes',
    'Evitar. Preferir metoclopramida como antiemético alternativo',
    'TORSADE DE POINTES — sotalol + ondansetrona: evitar',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),


  ('sotalol', 'quetiapina', InteractionSeverity.major,
    'Dois prolongadores de QT — efeito aditivo',
    'Torsades de Pointes, morte súbita',
    'Evitar. Monitorar QTc se combinação inevitável. Suspender se QTc >500ms',
    'TORSADE DE POINTES — evitar sotalol + quetiapina',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),


  ('sotalol', 'diurético', InteractionSeverity.major,
    'Diuréticos causam hipopotasemia e hipomagnesemia — potencializam o prolongamento de QT pelo sotalol',
    'Torsades de Pointes precipitada por distúrbio eletrolítico',
    'Monitorar K+ e Mg2+ séricos antes e durante uso de sotalol. Corrigir hipopotasemia antes de iniciar',
    'TORSADE — corrigir K+ e Mg2+ antes de iniciar sotalol',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.hypokalemia},
    [_kRefGG, _kRefMdx]),


  ('verapamil', 'sinvastatina', InteractionSeverity.major,
    'Verapamil inibe CYP3A4 — aumenta AUC da sinvastatina em 4-5x',
    'Risco muito elevado de rabdomiólisis',
    'Limitar sinvastatina a 10 mg/dia. Preferir pravastatina ou rosuvastatina',
    'RISCO DE RABDOMIÓLISE — limitar sinvastatina a 10mg/dia',
    EvidenceLevel.established,
    {RiskType.myopathy},
    [_kRefGG, _kRefMdx]),


  ('verapamil', 'ciclosporina', InteractionSeverity.major,
    'Verapamil inibe CYP3A4 e P-gp → eleva nível de ciclosporina',
    'Nefrotoxicidad por hiperciclosporinemia',
    'Monitorar nivel sérico de ciclosporina. Reduzir dose',
    'TOXICIDADE CICLOSPORINA — verapamil eleva via CYP3A4/P-gp',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('verapamil', 'carbamazepina', InteractionSeverity.major,
    'Verapamil inibe CYP3A4 → eleva carbamazepina; carbamazepina induz CYP3A4 → reduz verapamil',
    'Toxicidade por carbamazepina + redução da eficácia do verapamil',
    'Monitorar nível de carbamazepina. Considerar alternativa',
    'TOXICIDADE CARBAMAZEPINA — verapamil inibe metabolismo',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx]),


  ('verapamil', 'rifampicina', InteractionSeverity.major,
    'Rifampicina induz fortemente CYP3A4 e P-gp → reduz biodisponibilidade oral do verapamil em >90%',
    'Perda completa do efeito do verapamil — angina descontrolada, arritmias',
    'Evitar combinación. Usar antiarrítmico alternativo durante rifampicina',
    'INEFICÁCIA TOTAL — rifampicina elimina efeito do verapamil; evitar',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),


  ('metoprolol', 'fluoxetina', InteractionSeverity.major,
    'Fluoxetina inibe CYP2D6 — aumenta nível de metoprolol em 4-6x',
    'Bradicardia grave, bloqueio AV, hipotensão',
    'Reduzir dose de metoprolol. Monitorar FC e PA. Preferir sertralina (menor inibição CYP2D6)',
    'BRADICARDIA — fluoxetina eleva metoprolol 4-6x via CYP2D6',
    EvidenceLevel.established,
    {RiskType.arrhythmia, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('ivabradina', 'betabloqueador', InteractionSeverity.major,
    'Ivabradina inibe canal If do nó sinusal + betabloqueador também reduz FC — efeito aditivo cronotrópico negativo',
    'Bradicardia grave sintomática',
    'Monitorar FC. Manter FC >50 bpm. Titular doses. Combinação pode ser usada com cautela em angina refratária',
    'BRADICARDIA — ivabradina + betabloqueador: manter FC >50 bpm',
    EvidenceLevel.established,
    {RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),


  ('ivabradina', 'metoprolol', InteractionSeverity.major,
    'Dois agentes cronotrópicos negativos — efeito aditivo no nó sinusal',
    'Bradicardia grave',
    'Monitorar FC continuamente. Manter FC >50 bpm. Combinação pode ser útil em IC com FC elevada',
    'BRADICARDIA — ivabradina + metoprolol: monitorar FC',
    EvidenceLevel.established,
    {RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),


  ('esmolol', 'digoxina', InteractionSeverity.major,
    'Efeito aditivo na depressão do nó AV — esmolol (betabloqueador IV) + digoxina',
    'Bradicardia grave, bloqueio AV',
    'Monitorar ECG continuamente. Usar com cautela em procedimentos. Ter atropina disponible',
    'BRADICARDIA/BLOQUEIO AV — esmolol + digoxina: monitorar ECG',
    EvidenceLevel.established,
    {RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),


  ('esmolol', 'diltiazem', InteractionSeverity.major,
    'Dupla depressão do nó AV — esmolol (betabloqueador IV) + diltiazem',
    'Bradicardia grave, bloqueio AV completo, hipotensão',
    'CONTRAINDICADO IV simultâneo. Monitorar ECG e PA rigurosamente',
    'CONTRAINDICADO IV — esmolol + diltiazem: asistolia possível',
    EvidenceLevel.established,
    {RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),

    // ── FLUCONAZOL (inibidor CYP3A4/2C9/2C19) ──────────────────────────────

  ('fluconazol', 'rifampicina', InteractionSeverity.major,
    'Rifampicina é potente indutor de CYP3A4 e CYP2C9, as principais vias de metabolismo do fluconazol. Reduz significativamente os niveles plasmáticos do antifúngico',
    'Redução de 25-50% na AUC do fluconazol → falha terapéutica antifúngica, especialmente crítica em candidemia e meningite criptocócica',
    'Evitar combinación quando possível. Se indispensável: aumentar dose do fluconazol (até 800mg/dia monitorando toxicidad) ou substituir por anfotericina B. Monitorar resposta clínica e marcadores fúngicos',
    'EFICÁCIA REDUZIDA — Rifampicina induz CYP; considerar aumentar dose fluconazol ou trocar antifúngico',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('fluconazol', 'fenobarbital', InteractionSeverity.moderate,
    'Fenobarbital induz CYP2C9 e CYP3A4, reduzindo os níveis de fluconazol. Efeito inverso também ocorre: fluconazol inibe CYP2C9, podendo aumentar níveis de fenobarbital',
    'Reducción de la eficacia antifúngica por inducción enzimática. Riesgo de toxicidad por fenobarbital (sedación, ataxia) por inhibición do seu metabolismo',
    'Monitorar resposta antifúngica e ajustar dose do fluconazol conforme necesario. Monitorar sinais de toxicidad por fenobarbital (sedação excessiva, ataxia)',
    'INTERAÇÃO BIDIRECIONAL — Monitorar eficácia antifúngica e toxicidad de fenobarbital',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('fluconazol', 'eritromicina', InteractionSeverity.moderate,
    'Ambos prolongam o intervalo QT por mecanismos distintos. Eritromicina bloqueia canais IKr (hERG) e fluconazol prolonga o QT por inhibición do CYP3A4 (podendo elevar níveis da própria eritromicina)',
    'Risco aditivo/sinérgico de prolongamento do QTc e torsades de pointes, especialmente em pacientes com hipopotasemia, hipomagnesemia ou QT basal prolongado',
    'Monitorar ECG (QTc). Corrigir electrolitos antes e durante uso. Evitar em pacientes com QT basal > 450ms. Considerar azitromicina (menor risco de QT) se possível',
    'PROLONGAMENTO QT ADITIVO — Monitorar ECG e electrolitos; evitar se QTc > 450ms',
    EvidenceLevel.probable,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),


  ('fluconazol', 'claritromicina', InteractionSeverity.moderate,
    'Fluconazol inibe CYP3A4, reduzindo o metabolismo da claritromicina. Ambos prolongam o QTc por mecanismos complementares',
    'Aumento dos níveis de claritromicina → toxicidad gastrointestinal e risco aumentado de prolongamento QTc. Risco aditivo de torsades',
    'Monitorar ECG (QTc), especialmente em idosos e pacientes com cardiopatia. Corrigir hipopotasemia e hipomagnesemia. Considerar alternativa (azitromicina) se QTc > 450ms',
    'PROLONGAMENTO QT + NÍVEIS AUMENTADOS — Monitorar ECG; corrigir electrolitos',
    EvidenceLevel.probable,
    {RiskType.qtProlongation, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('fluconazol', 'ritonavir', InteractionSeverity.moderate,
    'Interação bidirecional complexa: ritonavir inibe CYP3A4 (pode aumentar fluconazol); fluconazol inibe CYP3A4 (pode aumentar ritonavir). Ambos prolongam QTc',
    'Riesgo de toxicidad mútua por inhibición enzimática bidirecional. Risco aumentado de prolongamento QTc',
    'Monitorar ECG e parâmetros hepáticos. Em TARV, preferir voriconazol ou anidulafungina quando disponible. Ajustar doses com base em monitoramento clínico',
    'INIBIÇÃO BIDIRECIONAL CYP3A4 — Monitorar ECG, hepatotoxicidad e resposta clínica',
    EvidenceLevel.probable,
    {RiskType.qtProlongation, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),

    // ── RIFAMPICINA (indutor potente CYP1A2/2C9/2C19/3A4/P-gp) ──────────────

  ('rifampicina', 'estatina', InteractionSeverity.major,
    'Rifampicina induz fortemente CYP3A4 (sinvastatina, atorvastatina, lovastatina) e transportadores OATP1B1/1B3 (rosuvastatina, pravastatina). Reduz drásticamente os niveles plasmáticos de todas as estatinas',
    'Redução de 80-90% nas concentrações de sinvastatina e atorvastatina. Riesgo de fallo en el control lipídico e cardiovascular durante tratamento com rifampicina',
    'Suspender estatinas durante tratamento com rifampicina quando possível. Se imprescindível: aumentar dose da estatina (com cautela pelo efeito rebote ao suspender rifampicina). Monitorar perfil lipídico',
    'EFICÁCIA DRASTICAMENTE REDUZIDA — Rifampicina reduz 80-90% dos níveis de estatinas; suspender ou ajustar dose',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('rifampicina', 'isrs', InteractionSeverity.major,
    'Rifampicina induz CYP2C19 e CYP2D6, as principais vias de metabolismo de citalopram, escitalopram, sertralina, paroxetina e fluoxetina. Pode reduzir níveis em 50-70%',
    'Redução significativa dos níveis do ISRS → risco de falha terapéutica e recorrência de depressão ou transtorno de ansiedade durante tratamento antituberculoso',
    'Monitorar resposta clínica ao ISRS. Pode ser necesario aumentar dose do antidepressivo. Reavaliar dose ao suspender rifampicina (risco de toxicidad por acúmulo)',
    'EFICÁCIA REDUZIDA — Rifampicina induz metabolismo de ISRSs; monitorar e ajustar dose do antidepressivo',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('rifampicina', 'metadona', InteractionSeverity.major,
    'Rifampicina é indutor potente de CYP3A4 e CYP2B6, as principais vias de metabolismo da metadona. Reduz os níveis em 50-80%',
    'Redução grave dos níveis de metadona → síndrome de abstinência opiácea grave, risco de recaída em pacientes em programa de substituição opiácea. Início rápido (2-5 dias)',
    'Evitar combinación. Si inevitable: aumentar dose de metadona gradualmente (pode ser necesario dobrar), monitorar diariamente sinais de abstinência. Ao suspender rifampicina, reduzir metadona gradualmente para evitar superdose',
    'ABSTINÊNCIA OPIÁCEA GRAVE — Rifampicina reduz metadona 50-80%; aumentar dose e monitorar diariamente',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('rifampicina', 'opioide', InteractionSeverity.major,
    'Rifampicina induz CYP3A4 e CYP2D6, reduzindo os níveis de morfina, codeína, oxicodona, fentanila e tramadol. A morfina (glucuronidação) é menos afetada que opioides com metabolismo hepático CYP',
    'Redução da analgesia → dor não controlada, risco de subdose em cuidados paliativos e pós-operatório. Ao cessar rifampicina, risco de superdose por acúmulo',
    'Monitorar controle da dor e aumentar dose do opioide conforme necesario. Preferir morfina (metabolismo por glucuronidação, menos afetada). Reduzir dose de opioides ao suspender rifampicina',
    'ANALGESIA REDUZIDA — Rifampicina induz CYP; preferir morfina e monitorar controle da dor',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('rifampicina', 'anticoncepcional', InteractionSeverity.major,
    'Rifampicina induz potentemente CYP3A4 e UGT, acelerando o metabolismo de etinilestradiol e progestágenos. Efeito começa em 1-2 semanas e persiste até 4-8 semanas após a suspensão',
    'Redução de 50-80% nos níveis hormonais → falha contraceptiva (gravidez não planejada), especialmente com anticoncepcionais de baixa dose',
    'CONTRAINDICADO usar rifampicina com contracepção hormonal oral/patch/anel como único método. Usar método de barreira durante o tratamento e por 4-8 semanas após. Considerar DIU de cobre como alternativa confiável',
    'FALHA CONTRACEPTIVA — Rifampicina reduz hormônios em 50-80%; usar método de barreira + adicional',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('rifampicina', 'benzodiazepínico', InteractionSeverity.major,
    'Rifampicina induz CYP3A4 (principal via de metabolismo de alprazolam, diazepam, clonazepam, triazolam, midazolam). Reduz os níveis em 50-90%',
    'Redução grave da eficácia ansiolítica/sedativa → ansiedade não controlada, insônia, possível síndrome de abstinência em uso crônico',
    'Aumentar dose do benzodiazepínico conforme resposta clínica. Preferir lorazepam (glucuronidação, menos afetado). Monitorar sintomas de abstinência e ansiedade',
    'EFICÁCIA REDUZIDA — Rifampicina induz CYP3A4; preferir lorazepam e monitorar resposta clínica',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('rifampicina', 'quetiapina', InteractionSeverity.major,
    'Rifampicina induz CYP3A4, a principal via de metabolismo da quetiapina. Estudos mostram redução de até 80% na AUC da quetiapina',
    'Falha no controle psiquiátrico (psicose, mania, depressão bipolar) por níveis subterapéuticos de quetiapina',
    'Evitar combinación. Se necesario: aumentar dose de quetiapina substancialmente (guideline sugere 5-7x a dose usual). Monitorar resposta clínica e efeitos adversos',
    'EFICÁCIA REDUZIDA — Rifampicina reduz quetiapina em até 80%; aumento substancial de dose necesario',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('rifampicina', 'haloperidol', InteractionSeverity.moderate,
    'Rifampicina induz CYP3A4 e glicuronidação, reduzindo os niveles plasmáticos do haloperidol em 50-70%',
    'Possível falha no controle antipsicótico → recorrência de sintomas psicóticos durante tratamento antituberculoso',
    'Monitorar resposta clínica e aumentar dose do haloperidol se necesario. Avaliar níveis séricos se disponible',
    'EFICÁCIA REDUZIDA — Monitorar sintomas psicóticos e ajustar dose de haloperidol',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('rifampicina', 'olanzapina', InteractionSeverity.moderate,
    'Rifampicina induz CYP1A2 e glicuronidação (principais vias da olanzapina), reduzindo os niveles plasmáticos em 50%',
    'Possível falha terapéutica no controle da psicose/mania durante tratamento antituberculoso',
    'Monitorar resposta clínica. Pode ser necesario aumentar dose de olanzapina. Reavaliar ao suspender rifampicina',
    'EFICÁCIA REDUZIDA — Rifampicina induz CYP1A2; monitorar e ajustar dose de olanzapina',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('rifampicina', 'digoxina', InteractionSeverity.moderate,
    'Rifampicina induz P-gp intestinal e hepática, reduzindo a absorção e aumentando a eliminação de digoxina. Redução de 30-50% nos níveis',
    'Reducción de la eficacia da digoxina no controle da frequência ventricular (FA) e na insuficiencia cardíaca',
    'Monitorar ECG e sinais de descompensação cardíaca. Ajustar dose de digoxina. Monitorar nivel sérico de digoxina após início e suspensão da rifampicina',
    'EFICÁCIA REDUZIDA — Rifampicina induz P-gp; monitorar níveis de digoxina e resposta cardíaca',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('rifampicina', 'amiodarona', InteractionSeverity.major,
    'Rifampicina induz CYP3A4 e CYP2C8, as vias de metabolismo da amiodarona e seu metabólito ativo (desetilamiodarona). Reduz os níveis de ambos',
    'Perda do controle do ritmo cardíaco (fibrilação atrial, flutter, TV) por níveis subterapéuticos de amiodarona. Risco elevado dado o estreito índice terapéutico da amiodarona',
    'Evitar combinación. Si inevitable: monitorar ECG continuamente, ajustar dose de amiodarona e verificar níveis séricos. Considerar ablação ou cardioversão elétrica como alternativa',
    'PERDA DE CONTROLE DO RITMO — Rifampicina reduz amiodarona; monitorar ECG e considerar alternativa',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('rifampicina', 'levotiroxina', InteractionSeverity.moderate,
    'Rifampicina induz enzimas hepáticas que aumentam o metabolismo de T4 e T3 e pode reduzir a absorção intestinal de levotiroxina',
    'Riesgo de hipotiroidismo durante tratamento com rifampicina em pacientes com hipotireoidismo prévio ou pós-tireoidectomia',
    'Monitorar TSH e T4 livre 4-6 semanas após início da rifampicina. Pode ser necesario aumentar dose de levotiroxina em 25-50%. Reavaliar ao suspender rifampicina',
    'HIPOTIREOIDISMO — Rifampicina aumenta metabolismo de T4; monitorar TSH e ajustar dose',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),


  ('rifampicina', 'fenitoína', InteractionSeverity.moderate,
    'Interação bidirecional: rifampicina induz CYP2C9 (metabolismo da fenitoína) → reduz níveis. Concomitantemente, fenitoína também induz CYP, podendo reduzir rifampicina',
    'Riesgo de fallo en ambos fármacos (control convulsivo y antituberculoso). Relación imprevisible: alguns pacientes têm aumento paradoxal de fenitoína por inhibición de CYP2C9',
    'Monitorar nivel sérico de fenitoína (alvo: 10-20 mcg/mL) e resposta clínica. Ajustar dose conforme necesario. Monitorar eficácia antituberculosa',
    'INTERAÇÃO BIDIRECIONAL IMPREVISÍVEL — Monitorar nivel sérico de fenitoína e eficácia antituberculosa',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('rifampicina', 'fenobarbital', InteractionSeverity.moderate,
    'Ambos são indutores enzimáticos potentes (CYP2B6, CYP3A4, CYP2C). Rifampicina pode reduzir os níveis de fenobarbital por indução de CYP2C9/glicuronidação',
    'Riesgo de ineficacia anticonvulsivante por reducción de los niveles de fenobarbital, con posible recurrencia de crisis',
    'Monitorar nivel sérico de fenobarbital e ajustar dose conforme necesario. Avaliar controle clínico das crises',
    'EFICÁCIA REDUZIDA — Monitorar nivel sérico de fenobarbital durante uso de rifampicina',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('rifampicina', 'claritromicina', InteractionSeverity.major,
    'Rifampicina induz CYP3A4, a principal via de metabolismo da claritromicina. Reduz os níveis de claritromicina em 75-80%',
    'Falha terapéutica da claritromicina (infecções por Mycobacterium avium complex, Helicobacter pylori, pneumonias). Especialmente crítico no contexto de MAC em imunodeprimidos',
    'Evitar a combinação no contexto de infecção por MAC. Para outras indicações, avaliar se azitromicina é uma alternativa (menos afetada). Monitorar resposta microbiológica e clínica',
    'FALHA TERAPÊUTICA — Rifampicina reduz claritromicina em 75-80%; usar azitromicina se possível',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('rifampicina', 'eritromicina', InteractionSeverity.major,
    'Rifampicina induz CYP3A4, reduzindo significativamente os níveis de eritromicina. Pode reduzir a AUC em 50-70%',
    'Falha terapéutica por níveis subterapéuticos de eritromicina. Combinação clinicamente irracional na maioria dos cenários',
    'Evitar combinación. Usar azitromicina (menos afetada por indução de CYP) ou outro antibiótico adecuado ao espectro necesario',
    'FALHA TERAPÊUTICA — Rifampicina reduz eritromicina; substituir por azitromicina',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('rifampicina', 'ritonavir', InteractionSeverity.contraindicated,
    'Rifampicina é indutor potente de CYP3A4/P-gp; ritonavir é inibidor potente de CYP3A4. A indução pela rifampicina supera a inibição do ritonavir, podendo reduzir os níveis de ritonavir em 75% e aumentar paradoxalmente o risco de hepatotoxicidad grave',
    'Falha virológica (HIV/HCV) por níveis subterapéuticos de ritonavir. Risco elevado de hepatotoxicidad grave e síndrome de reconstituição imune. Documentados casos de hepatite fulminante',
    'CONTRAINDICADO. Para TARV durante tuberculose: substituir por regimes baseados em inibidores de integrase (dolutegravir 50mg 2x/dia + rifampicina) segundo diretrizes OMS. Nunca combinar rifampicina com IP boosted',
    'CONTRAINDICADO — Falha virológica + hepatotoxicidad fatal; usar dolutegravir + rifampicina segundo protocolo OMS',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.hepatotoxicity},
    [_kRefGG, _kRefMdx, _kRefUT]),

    // ── CARBAMAZEPINA (indutor CYP3A4/1A2/2C9, indutor P-gp) ──────────────────

  ('carbamazepina', 'isrs', InteractionSeverity.major,
    'Carbamazepina induz CYP3A4 e CYP2C19, acelerando o metabolismo de citalopram, escitalopram, sertralina e outros ISRSs. Fluoxetina e fluvoxamina inibem CYP3A4/2C19, podendo aumentar carbamazepina e seu metabólito epóxido (tóxico)',
    'Redução dos níveis do ISRS → falha antidepressiva. Fluoxetina/fluvoxamina podem causar toxicidad de carbamazepina (diplopia, ataxia, tontura, náusea) por inhibición do seu metabolismo',
    'Monitorar resposta ao ISRS e nivel sérico de carbamazepina. Sertralina é a opção mais segura (menor interação). Evitar fluoxetina e fluvoxamina com carbamazepina',
    'EFICÁCIA REDUZIDA + RISCO DE TOXICIDADE — Monitorar nível de carbamazepina e resposta ao ISRS',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('carbamazepina', 'opioide', InteractionSeverity.moderate,
    'Carbamazepina induz CYP3A4 (fentanila, oxicodona, tramadol) e CYP2D6 (codeína, tramadol), reduzindo os níveis e a eficácia analgésica. Tramadol tem risco adicional de abaixamento do limiar convulsivo',
    'Redução da analgesia por níveis subterapéuticos de opioides. Tramadol especialmente problemático: além de analgesia reducida, o abaixamento do limiar convulsivo pode precipitar crises em epiléticos',
    'Evitar tramadol em pacientes com epilepsia em uso de carbamazepina. Aumentar dose de opioides conforme necesario. Preferir morfina ou hidromorfona (metabolismo por glucuronidação)',
    'ANALGESIA REDUZIDA — Evitar tramadol; preferir morfina e monitorar controle da dor',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.seizure},
    [_kRefGG, _kRefMdx]),


  ('carbamazepina', 'metadona', InteractionSeverity.major,
    'Carbamazepina induz CYP3A4 e CYP2C8, as principais vias de metabolismo da metadona, reduzindo os níveis em 50-60%',
    'Síndrome de abstinência opiácea em pacientes em programa de substituição → risco de recaída. Dor não controlada em uso crônico',
    'Evitar combinación quando possível. Se necessária: aumentar dose de metadona gradualmente, monitorar sinais de abstinência. Ao suspender carbamazepina, reduzir metadona para prevenir superdosagem',
    'ABSTINÊNCIA OPIÁCEA — Carbamazepina reduz metadona 50-60%; aumentar dose e monitorar abstinência',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('carbamazepina', 'olanzapina', InteractionSeverity.moderate,
    'Carbamazepina induz CYP1A2 (principal via da olanzapina) e glicuronidação, reduzindo os níveis de olanzapina em 50%',
    'Possível falha terapéutica no controle da psicose ou mania bipolar',
    'Monitorar resposta clínica. Aumentar dose de olanzapina se necesario (pode ser necesario dobrar). Reavaliar ao modificar dose de carbamazepina',
    'EFICÁCIA REDUZIDA — Carbamazepina induz CYP1A2; monitorar e ajustar dose de olanzapina',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('carbamazepina', 'haloperidol', InteractionSeverity.moderate,
    'Carbamazepina induz CYP3A4 e CYP2D6, as principais vias de metabolismo do haloperidol. Pode reduzir os níveis em 50-60%',
    'Reducción de la eficacia antipsicótica → recorrência de sintomas psicóticos ou maníacos',
    'Monitorar resposta clínica e aumentar dose de haloperidol se necesario. Monitorar nivel sérico se disponible',
    'EFICÁCIA REDUZIDA — Carbamazepina induz CYP; monitorar resposta clínica e ajustar dose de haloperidol',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('carbamazepina', 'quetiapina', InteractionSeverity.major,
    'Carbamazepina induz CYP3A4, reduzindo os níveis de quetiapina em 80%. É uma das interações mais documentadas em psiquiatria',
    'Falha grave no controle da psicose ou transtorno bipolar. Pacientes podem exigir doses muito elevadas de quetiapina, com risco de toxicidad ao suspender carbamazepina',
    'Evitar combinación quando possível. Se necesario: aumentar dose de quetiapina substancialmente (5-7x a dose usual). Monitorar resposta clínica. Alternativas: valproato + quetiapina, ou trocar carbamazepina por lamotrigina',
    'FALHA TERAPÊUTICA GRAVE — Carbamazepina reduz quetiapina em 80%; considerar trocar antiepilético',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('carbamazepina', 'digoxina', InteractionSeverity.moderate,
    'Carbamazepina pode induzir P-gp, reduzindo a absorção intestinal e aumentando a eliminação renal de digoxina',
    'Redução dos níveis de digoxina → perda do controle da frequência ventricular em FA ou insuficiencia cardíaca',
    'Monitorar nivel sérico de digoxina e ECG após início ou modificação de carbamazepina. Ajustar dose conforme necesario',
    'EFICÁCIA REDUZIDA — Monitorar nivel sérico de digoxina durante uso de carbamazepina',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('carbamazepina', 'ciclosporina', InteractionSeverity.major,
    'Carbamazepina induz potentemente CYP3A4, a principal via de metabolismo da ciclosporina. Redução de 50-75% nos níveis do imunossupressor',
    'Rejeição aguda de transplante por níveis subterapéuticos de ciclosporina. Risco alto em transplantados de órgão sólido',
    'Evitar combinación em transplantados. Substituir carbamazepina por lamotrigina, levetiracetam ou gabapentina (não indutores). Si inevitable: aumentar dose de ciclosporina e monitorar nivel sérico (alvo C0 por tipo de transplante)',
    'REJEIÇÃO DE TRANSPLANTE — Carbamazepina reduz ciclosporina 50-75%; substituir antiepilético por não-indutor',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('carbamazepina', 'tacrolimo', InteractionSeverity.major,
    'Carbamazepina induz CYP3A4 e P-gp, reduzindo drásticamente os níveis de tacrolimo (imunossupressor com índice terapéutico estreitíssimo)',
    'Rechazo agudo de trasplante por niveles subterapéuticos de tacrolimús. Riesgo de pérdida del injerto',
    'Evitar combinación em transplantados. Substituir carbamazepina por antiepilético não-indutor. Se impossível: monitorar C0 de tacrolimo diariamente até estabilização e ajustar dose agressivamente',
    'REJEIÇÃO DE TRANSPLANTE — Carbamazepina reduz tacrolimo drásticamente; substituir antiepilético',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('carbamazepina', 'amiodarona', InteractionSeverity.major,
    'Amiodarona inibe CYP3A4 e CYP2C8, aumentando os níveis de carbamazepina e seu metabólito epóxido (tóxico). Carbamazepina induz CYP3A4, podendo reduzir amiodarona',
    'Toxicidade de carbamazepina (diplopia, ataxia, tontura, náusea, sedação) por inhibición do seu metabolismo pela amiodarona. Risco de falha antiarrítmica por indução',
    'Evitar combinación. Monitorar nivel sérico de carbamazepina e sinais de toxicidad. Se mantida, ajustar doses com base em níveis séricos e ECG',
    'TOXICIDADE DE CARBAMAZEPINA — Amiodarona inibe CYP3A4; monitorar nivel sérico e sinais de toxicidad',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.cns},
    [_kRefGG, _kRefMdx]),


  ('carbamazepina', 'dabigatrana', InteractionSeverity.major,
    'Carbamazepina induz P-gp, o principal transportador de efflux da dabigatrana, reduzindo a absorção e aumentando a eliminação. Pode reduzir os níveis em 50-70%',
    'Riesgo de trombosis (AVC, TEP, TVP) por anticoagulação insuficiente',
    'Evitar combinación. Substituir dabigatrana por varfarina (monitorada por INR) ou substituir carbamazepina por antiepilético não-indutor. Não usar dabigatrana como anticoagulante durante uso de carbamazepina',
    'TROMBOSE — Carbamazepina induz P-gp; não usar dabigatrana; usar varfarina com INR rigoroso',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('carbamazepina', 'apixabana', InteractionSeverity.major,
    'Carbamazepina induz CYP3A4 e P-gp, ambas as vias de eliminação da apixabana, reduzindo os níveis em 50-60%',
    'Anticoagulação insuficiente → trombosis (AVC, TEP, TVP)',
    'Evitar combinación. Usar varfarina (monitorada por INR) ou substituir carbamazepina por antiepilético não-indutor (levetiracetam, lamotrigina). A bula da apixabana contraindica uso com indutores potentes de CYP3A4/P-gp',
    'TROMBOSE — Carbamazepina reduz apixabana 50-60%; usar varfarina ou trocar antiepilético',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('carbamazepina', 'rivaroxabana', InteractionSeverity.major,
    'Carbamazepina induz CYP3A4 e P-gp, reduzindo os níveis de rivaroxabana em 50-60%',
    'Anticoagulação insuficiente → trombosis. A bula da rivaroxabana contraindica uso combinado com indutores potentes de CYP3A4/P-gp',
    'CONTRAINDICADO pela bula da rivaroxabana. Usar varfarina (monitorada por INR) ou substituir carbamazepina por antiepilético não-indutor',
    'CONTRAINDICADO — Carbamazepina reduz rivaroxabana 50-60%; usar varfarina ou trocar antiepilético',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('carbamazepina', 'lamotrigina', InteractionSeverity.major,
    'Carbamazepina induz UGT1A4 e CYP3A4, reduzindo os níveis de lamotrigina em 40-50%. A lamotrigina não afeta os níveis de carbamazepina, mas pode potencializar o metabólito epóxido (tóxico)',
    'Níveis subterapéuticos de lamotrigina → falha no controle de crises. Riesgo de toxicidad de carbamazepina epóxido (diplopia, ataxia)',
    'Quando combinados (uso frecuente em epilepsia refratária): doses de lamotrigina em uso concomitante com carbamazepina são 2x maiores do que em monoterapia. Monitorar sinais de toxicidad de carbamazepina epóxido',
    'DOSE DE LAMOTRIGINA DOBRADA — Carbamazepina reduz lamotrigina 40-50%; ajustar dose conforme protocolo',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('carbamazepina', 'topiramato', InteractionSeverity.moderate,
    'Carbamazepina induz CYP3A4, reduzindo os níveis de topiramato em 40-50%. Topiramato pode levemente aumentar os níveis de carbamazepina',
    'Possível falha no control convulsivo por níveis subterapéuticos de topiramato',
    'Monitorar resposta ao topiramato. Aumentar dose de topiramato conforme necesario. Usar a maior dose efetiva dentro das recomendações',
    'EFICÁCIA REDUZIDA — Carbamazepina reduz topiramato 40-50%; monitorar controle das crises',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('carbamazepina', 'claritromicina', InteractionSeverity.major,
    'Claritromicina inibe potentemente CYP3A4, a principal via de eliminação da carbamazepina. Pode aumentar os níveis de carbamazepina e seu metabólito epóxido em 50-100%',
    'Toxicidade grave de carbamazepina: diplopia, ataxia, tontura, vômitos, confusão mental, hiponatremia. O metabólito epóxido (também tóxico) também se acumula',
    'Evitar combinación. Substituir claritromicina por azitromicina (não inibe CYP3A4) quando possível. Si inevitable: reduzir dose de carbamazepina em 25-50% e monitorar nivel sérico',
    'TOXICIDADE DE CARBAMAZEPINA — Claritromicina inibe CYP3A4; preferir azitromicina',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.cns},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('carbamazepina', 'eritromicina', InteractionSeverity.major,
    'Eritromicina inibe CYP3A4, aumentando os níveis de carbamazepina e seu metabólito epóxido. Interação bem documentada em literatura',
    'Toxicidade de carbamazepina: diplopia, ataxia, vômitos, confusão, hiponatremia, arritmias',
    'Evitar combinación. Substituir eritromicina por azitromicina (segura com carbamazepina). Se mantida: monitorar nivel sérico e reduzir dose de carbamazepina',
    'TOXICIDADE DE CARBAMAZEPINA — Eritromicina inibe CYP3A4; substituir por azitromicina',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.cns},
    [_kRefGG, _kRefMdx]),

    // ── FENITOÍNA (indutor CYP2C9/2C19/3A4, substrato CYP2C9/2C19) ──────────

  ('fenitoína', 'isrs', InteractionSeverity.major,
    'Fluoxetina e fluvoxamina inibem CYP2C9/2C19, aumentando os níveis de fenitoína. Fenitoína induz CYP3A4/2C19, podendo reduzir níveis de alguns ISRSs. Interação bidirecional e complexa',
    'Toxicidade de fenitoína (nistagmo, ataxia, diplopia, confusão) com fluoxetina/fluvoxamina. Falha antidepressiva com sertralina/escitalopram por indução',
    'Evitar fluoxetina e fluvoxamina com fenitoína. Sertralina é a opção mais segura. Monitorar nivel sérico de fenitoína (alvo: 10-20 mcg/mL) ao iniciar/suspender ISRS',
    'TOXICIDADE DE FENITOÍNA com fluoxetina/fluvoxamina — evitar; usar sertralina e monitorar nivel sérico',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.cns},
    [_kRefGG, _kRefMdx]),


  ('fenitoína', 'digoxina', InteractionSeverity.moderate,
    'Fenitoína induz P-gp e CYP3A4, reduzindo os níveis de digoxina. A própria fenitoína IV pode causar arritmias (bradicardia, bloqueio AV) quando administrada rapidamente',
    'Redução dos níveis de digoxina → perda do controle da frequência ventricular em FA. Risco adicional de arritmias com fenitoína IV em bolus rápido',
    'Monitorar nivel sérico de digoxina e ECG. Ajustar dose de digoxina conforme necesario. Administrar fenitoína IV lentamente (máximo 50mg/min)',
    'EFICÁCIA REDUZIDA — Monitorar nível de digoxina; administrar fenitoína IV lentamente',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),


  ('fenitoína', 'ciclosporina', InteractionSeverity.major,
    'Fenitoína induz CYP3A4, reduzindo os níveis de ciclosporina em 50-75%. Ciclosporina pode ter efeito minor sobre fenitoína',
    'Rejeição aguda de transplante por níveis subterapéuticos de ciclosporina em pacientes transplantados que necessitam de anticonvulsivante',
    'Evitar combinación em transplantados. Substituir fenitoína por levetiracetam, gabapentina ou lamotrigina (não indutores de CYP3A4). Se impossível: monitorar C0 de ciclosporina diariamente e ajustar dose agressivamente',
    'REJEIÇÃO DE TRANSPLANTE — Fenitoína reduz ciclosporina 50-75%; substituir por antiepilético não-indutor',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('fenitoína', 'tacrolimo', InteractionSeverity.major,
    'Fenitoína induz CYP3A4 e P-gp, reduzindo drásticamente os níveis de tacrolimo (imunossupressor com janela terapéutica estreitíssima)',
    'Rechazo agudo de trasplante por niveles subterapéuticos de tacrolimús. Riesgo de pérdida del injerto',
    'Evitar combinación. Substituir fenitoína por antiepilético não-indutor em transplantados. Se impossível: monitorar C0 de tacrolimo diariamente e aumentar dose significativamente',
    'REJEIÇÃO DE TRANSPLANTE — Fenitoína reduz tacrolimo drásticamente; substituir antiepilético',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('fenitoína', 'anticoncepcional', InteractionSeverity.major,
    'Fenitoína induz CYP3A4 e UGT, acelerando o metabolismo de etinilestradiol e progestágenos. Pode reduzir os níveis hormonais em 50%',
    'Falha contraceptiva com gravidez não planejada em mulheres em uso de anticoncepcional hormonal (oral, patch, anel vaginal)',
    'Usar método de barreira adicional. Preferir anticoncepcional com dose maior de estrogênio (≥50mcg etinilestradiol) ou DIU de cobre/levonorgestrel (SIU). Informar a paciente sobre o risco',
    'FALHA CONTRACEPTIVA — Fenitoína reduz hormônios; usar método de barreira adicional ou DIU',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),


  ('fenitoína', 'valproato', InteractionSeverity.major,
    'Interação bidirecional complexa: valproato desloca fenitoína da albumina (↑ fração livre, mais tóxica) e inibe CYP2C9 (↑ nível total). Fenitoína induz o metabolismo de valproato (↓ nível). Relação imprevisível',
    'Toxicidade de fenitoína (nível livre elevado mesmo com nível total normal/baixo) com ataxia, nistagmo, confusão. Falha do valproato por níveis subterapéuticos',
    'Monitorar nível livre de fenitoína (não apenas nível total). Monitorar nível de valproato e resposta clínica. Considerar alternativas (levetiracetam) para evitar interação complexa',
    'INTERAÇÃO COMPLEXA — Monitorar nível LIVRE de fenitoína e nível de valproato; interação bidirecional imprevisível',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.cns},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('fenitoína', 'quetiapina', InteractionSeverity.major,
    'Fenitoína induz CYP3A4, a principal via de metabolismo da quetiapina. Pode reduzir os níveis em 80%',
    'Falha no controle da psicose ou transtorno bipolar por níveis subterapéuticos de quetiapina',
    'Evitar combinación quando possível. Se necesario: aumentar dose de quetiapina substancialmente. Monitorar resposta clínica',
    'EFICÁCIA REDUZIDA — Fenitoína reduz quetiapina em até 80%; considerar trocar antiepilético',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('fenitoína', 'claritromicina', InteractionSeverity.major,
    'Claritromicina inibe CYP3A4 e pode inibir parcialmente CYP2C19, reduzindo o metabolismo da fenitoína. Riesgo de toxicidad por acúmulo',
    'Toxicidade de fenitoína: nistagmo, ataxia, diplopia, confusão, encefalopatia',
    'Evitar combinación. Substituir claritromicina por azitromicina quando possível. Monitorar nivel sérico de fenitoína se mantida',
    'TOXICIDADE DE FENITOÍNA — Claritromicina inibe metabolismo; preferir azitromicina',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel, RiskType.cns},
    [_kRefGG, _kRefMdx]),


  ('fenitoína', 'eritromicina', InteractionSeverity.moderate,
    'Eritromicina inibe CYP3A4 e pode aumentar os níveis de fenitoína por inhibición do seu metabolismo',
    'Toxicidade de fenitoína: nistagmo, ataxia, diplopia, náusea',
    'Monitorar nivel sérico de fenitoína e sinais de toxicidad. Considerar azitromicina como alternativa',
    'TOXICIDADE DE FENITOÍNA — Monitorar nivel sérico ao usar eritromicina; preferir azitromicina',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel, RiskType.cns},
    [_kRefGG, _kRefMdx]),


  ('fenitoína', 'ritonavir', InteractionSeverity.major,
    'Interação bidirecional: ritonavir inibe CYP2C9 (pode aumentar fenitoína) mas também induz CYP2C9 crónicamente (pode reduzir fenitoína). Fenitoína induz CYP3A4, reduzindo ritonavir e ARVs boosted',
    'Falha virológica por redução do ritonavir/ARVs. Toxicidade ou falha da fenitoína por interação imprevisível e bidirecional',
    'Evitar combinación em TARV. Substituir fenitoína por levetiracetam. Se mantida: monitorar carga viral e nivel sérico de fenitoína frecuentemente',
    'FALHA VIROLÓGICA + INTERAÇÃO IMPREVISÍVEL DE FENITOÍNA — Substituir por levetiracetam em TARV',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('fenitoína', 'fenobarbital', InteractionSeverity.moderate,
    'Interação bidirecional: fenobarbital pode induzir CYP2C9 (reduz fenitoína) ou inibir competitivamente (aumenta fenitoína). Efeito final é imprevisível e varia entre pacientes',
    'Toxicidade ou falha de fenitoína por interação bidirecional e variável. Toxicidade de sedação aditiva por ambos os fármacos',
    'Monitorar nivel sérico de fenitoína e resposta clínica. Esta combinação é usada em epilepsia refratária mas requer monitoramento cuidadoso',
    'INTERAÇÃO IMPREVISÍVEL — Monitorar nivel sérico de fenitoína e controle clínico das crises',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.cns},
    [_kRefGG, _kRefMdx]),

    // ── FENOBARBITAL (indutor CYP1A2/2C9/2C19/3A4/UGT) ───────────────────────

  ('fenobarbital', 'isrs', InteractionSeverity.moderate,
    'Fenobarbital induz CYP2C19 e CYP3A4, acelerando o metabolismo de vários ISRSs. Risco adicional de sedação aditiva (fenobarbital é sedativo)',
    'Redução dos níveis do ISRS → falha antidepressiva. Sedação excessiva por efeito aditivo no SNC',
    'Monitorar resposta ao ISRS. Pode ser necesario aumentar dose. Evitar atividades de risco (dirigir, operar máquinas) pelo efeito sedativo combinado',
    'EFICÁCIA REDUZIDA + SEDAÇÃO — Monitorar resposta ao antidepressivo e sedação aditiva',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.cns},
    [_kRefGG, _kRefMdx]),


  ('fenobarbital', 'ciclosporina', InteractionSeverity.major,
    'Fenobarbital induz CYP3A4, reduzindo os níveis de ciclosporina em 40-60%',
    'Rejeição aguda de transplante por anticoagulação insuficiente. Risco de pérdida del injerto',
    'Evitar combinación em transplantados. Substituir fenobarbital por levetiracetam ou gabapentina. Se impossível: monitorar C0 de ciclosporina e ajustar dose agressivamente',
    'REJEIÇÃO DE TRANSPLANTE — Fenobarbital reduz ciclosporina 40-60%; substituir por antiepilético não-indutor',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('fenobarbital', 'tacrolimo', InteractionSeverity.major,
    'Fenobarbital induz CYP3A4 e P-gp, reduzindo os níveis de tacrolimo significativamente',
    'Rejeição aguda de transplante por níveis subterapéuticos de tacrolimo',
    'Evitar em transplantados. Substituir por antiepilético não-indutor. Monitorar C0 de tacrolimo diariamente se mantido',
    'REJEIÇÃO DE TRANSPLANTE — Fenobarbital reduz tacrolimo; substituir antiepilético por não-indutor',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('fenobarbital', 'anticoncepcional', InteractionSeverity.major,
    'Fenobarbital induz CYP3A4 e UGT, reduzindo os níveis de etinilestradiol e progestágenos. Mesma magnitude que fenitoína e carbamazepina',
    'Falha contraceptiva → gravidez não planejada. Risco especialmente crítico em mulheres em idade fértil com epilepsia',
    'Usar método de barreira adicional obligatoriamente. Preferir DIU de cobre ou levonorgestrel (não afetados). Considerar substituição por antiepilético não-indutor (lamotrigina, levetiracetam)',
    'FALHA CONTRACEPTIVA — Fenobarbital reduz hormônios; usar DIU ou método de barreira adicional',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),


  ('fenobarbital', 'valproato', InteractionSeverity.major,
    'Valproato inibe o metabolismo de fenobarbital (CYP2C9 e β-oxidação mitocondrial), aumentando os níveis em 30-60%. Fenobarbital pode induzir o metabolismo do valproato',
    'Toxicidade de fenobarbital: sedação excessiva, ataxia, confusão mental, depresión respiratoria. Falha do valproato por indução',
    'Monitorar nivel sérico de fenobarbital e sinais de toxicidad ao iniciar valproato. Reduzir dose de fenobarbital preventivamente em 25%. Esta combinação é usada em epilepsia mas requer ajuste de doses',
    'TOXICIDADE DE FENOBARBITAL — Valproato aumenta nível de fenobarbital 30-60%; reduzir dose de fenobarbital',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.cns},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('fenobarbital', 'lamotrigina', InteractionSeverity.major,
    'Fenobarbital induz UGT1A4 (principal via de glucuronidação da lamotrigina), reduzindo os níveis em 40%',
    'Falha no controle de crises por níveis subterapéuticos de lamotrigina',
    'Doses de lamotrigina em uso com fenobarbital são aproximadamente 2x maiores que em monoterapia. Seguir protocolo de titulação específico para uso com indutores enzimáticos',
    'DOSE DE LAMOTRIGINA DOBRADA — Fenobarbital induz UGT; ajustar dose conforme protocolo com indutores',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('fenobarbital', 'quetiapina', InteractionSeverity.major,
    'Fenobarbital induz CYP3A4, reduzindo os níveis de quetiapina em 70-80%',
    'Falha no controle da psicose ou transtorno bipolar por níveis subterapéuticos de quetiapina',
    'Evitar combinación quando possível. Se necesario: aumentar dose de quetiapina substancialmente (5-7x). Considerar trocar fenobarbital por valproato ou levetiracetam',
    'EFICÁCIA REDUZIDA — Fenobarbital reduz quetiapina em 70-80%; considerar trocar antiepilético',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('fenobarbital', 'claritromicina', InteractionSeverity.moderate,
    'Claritromicina inibe CYP3A4, podendo aumentar os níveis de fenobarbital. Fenobarbital induz CYP3A4, podendo reduzir claritromicina',
    'Sedação excessiva por acúmulo de fenobarbital. Possível falha antibiótica por redução de claritromicina',
    'Monitorar sedação e nível de fenobarbital. Considerar azitromicina como alternativa (sem interação CYP significativa com fenobarbital)',
    'SEDAÇÃO AUMENTADA + EFICÁCIA REDUZIDA — Monitorar sedação; preferir azitromicina',
    EvidenceLevel.probable,
    {RiskType.cns, RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),


  ('fenobarbital', 'eritromicina', InteractionSeverity.moderate,
    'Eritromicina inibe CYP3A4, podendo aumentar os níveis de fenobarbital. Fenobarbital induz CYP3A4, podendo reduzir eritromicina. Sedação aditiva por SNC',
    'Sedação excessiva por acúmulo de fenobarbital. Possível falha antibiótica',
    'Monitorar sedação. Preferir azitromicina. Se mantida: monitorar nivel sérico de fenobarbital',
    'SEDAÇÃO AUMENTADA — Monitorar sedação; preferir azitromicina a eritromicina',
    EvidenceLevel.probable,
    {RiskType.cns, RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),


  ('fenobarbital', 'ritonavir', InteractionSeverity.major,
    'Fenobarbital induz CYP3A4, reduzindo os níveis de ritonavir e ARVs boosted. Risco de falha virológica em HIV',
    'Falha virológica (HIV) por redução dos níveis de ritonavir/ARVs. Risco de resistência viral',
    'Evitar em TARV. Substituir fenobarbital por levetiracetam ou lamotrigina. Monitorar carga viral e CD4 se mantida',
    'FALHA VIROLÓGICA — Fenobarbital reduz ritonavir/ARVs; substituir por antiepilético não-indutor em TARV',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),

    // ── ERITROMICINA (inibidor moderado CYP3A4, prolonga QTc) ─────────────────

  ('eritromicina', 'warfarina', InteractionSeverity.major,
    'Eritromicina inibe CYP3A4 e CYP2C9, reduzindo o metabolismo da varfarina (especialmente da S-varfarina, mais potente). Pode também reduzir a flora intestinal produtora de vitamina K',
    'Aumento do INR → risco de sangrado grave (intracraneal, gastrointestinal). Início rápido (2-5 dias após início da eritromicina)',
    'Monitorar INR 2-3 dias após início e ao suspender eritromicina. Antecipar necessidade de redução da dose de varfarina em 20-30%. Considerar azitromicina (menos interação com varfarina)',
    'SANGRAMENTO — Eritromicina aumenta INR; monitorar INR e reduzir dose de varfarina; preferir azitromicina',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('eritromicina', 'estatina', InteractionSeverity.major,
    'Eritromicina inibe CYP3A4, aumentando os níveis de sinvastatina, atorvastatina e lovastatina. Rosuvastatina e pravastatina são menos afetadas',
    'Riesgo aumentado de miopatía e rabdomiólisis por acúmulo de estatinas. Risco mais elevado com sinvastatina (maior dependência de CYP3A4)',
    'Evitar eritromicina com sinvastatina (suspender sinvastatina durante curso de eritromicina). Preferir azitromicina. Se eritromicina necessária: usar rosuvastatina ou pravastatina (menos afetadas por CYP3A4)',
    'RABDOMIÓLISE — Eritromicina inibe CYP3A4; suspender sinvastatina ou usar azitromicina',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('eritromicina', 'digoxina', InteractionSeverity.major,
    'Eritromicina aumenta a biodisponibilidade da digoxina por dois mecanismos: inibição de P-gp intestinal e eliminação de bactérias intestinais que inativam digoxina (Eggerthella lenta). Afeta ~10% dos pacientes mas pode ser grave',
    'Intoxicação digitálica: náusea, vômitos, bradicardia, bloqueio AV, arritmias ventriculares potencialmente fatais',
    'Monitorar nivel sérico de digoxina e ECG após início de eritromicina. Em pacientes com nível próximo ao terapéutico máximo, reduzir dose de digoxina preventivamente. Considerar azitromicina',
    'INTOXICAÇÃO DIGITÁLICA — Eritromicina aumenta digoxina; monitorar nivel sérico e ECG; preferir azitromicina',
    EvidenceLevel.established,
    {RiskType.arrhythmia, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('eritromicina', 'ciclosporina', InteractionSeverity.major,
    'Eritromicina inibe CYP3A4 e P-gp, aumentando os níveis de ciclosporina em 50-100% em pacientes transplantados',
    'Nefrotoxicidad grave, hipertensão, hiperpotasemia por acúmulo de ciclosporina',
    'Monitorar C0 de ciclosporina a cada 2-3 dias durante uso de eritromicina. Reduzir dose preventivamente em 25-50%. Preferir azitromicina (menor interação) em transplantados',
    'NEFROTOXICIDADE — Eritromicina dobra níveis de ciclosporina; reduzir dose e monitorar C0; preferir azitromicina',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('eritromicina', 'tacrolimo', InteractionSeverity.major,
    'Eritromicina inibe CYP3A4 e P-gp, aumentando os níveis de tacrolimo significativamente (pode duplicar ou triplicar)',
    'Nefrotoxicidad grave e neurotoxicidad por acúmulo de tacrolimo. Risco de rejeição paradoxal se os níveis forem mal manejados',
    'Monitorar C0 de tacrolimo diariamente ao iniciar eritromicina. Reduzir dose de tacrolimo em 30-50% preventivamente. Preferir azitromicina em transplantados',
    'NEFROTOXICIDADE GRAVE — Eritromicina triplica tacrolimo; monitorar C0 diariamente; preferir azitromicina',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('eritromicina', 'isrs', InteractionSeverity.moderate,
    'Eritromicina inibe CYP3A4 e prolonga QTc. Citalopram e escitalopram também prolongam QTc. Fluoxetina inibe CYP2D6/3A4 (interação bidirecional)',
    'Prolongamento QTc aditivo, especialmente com citalopram e escitalopram. Risco de torsades de pointes',
    'Evitar eritromicina + citalopram/escitalopram. Monitorar ECG com outros ISRSs. Corrigir electrolitos. Preferir azitromicina (menor risco de QT)',
    'PROLONGAMENTO QT — Evitar eritromicina + citalopram/escitalopram; monitorar ECG com outros ISRSs',
    EvidenceLevel.probable,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),


  ('eritromicina', 'benzodiazepínico', InteractionSeverity.moderate,
    'Eritromicina inibe CYP3A4, aumentando os níveis de alprazolam, diazepam, triazolam e midazolam. Lorazepam não é afetado significativamente (glucuronidação)',
    'Sedación excesiva y prolongada, compromiso psicomotor, depresión respiratoria (especialmente com triazolam e midazolam)',
    'Evitar eritromicina com triazolam e midazolam oral (alto risco). Preferir lorazepam ou azitromicina. Reduzir dose do benzodiazepínico em 50% se necesario',
    'SEDAÇÃO EXCESSIVA — Eritromicina inibe CYP3A4; evitar triazolam/midazolam; preferir lorazepam ou azitromicina',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.respiratoryDepression, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('eritromicina', 'quetiapina', InteractionSeverity.major,
    'Eritromicina inibe CYP3A4 (metabolismo de quetiapina) e prolonga QTc. Quetiapina também prolonga QTc',
    'Aumento dos níveis de quetiapina → toxicidad (sedação, hipotensão, prolongamento QTc). Risco aditivo de torsades de pointes',
    'Evitar combinación. Substituir eritromicina por azitromicina. Monitorar ECG e sinais de toxicidad de quetiapina se mantida',
    'QT PROLONGADO + TOXICIDADE DE QUETIAPINA — Substituir eritromicina por azitromicina; monitorar ECG',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('eritromicina', 'metadona', InteractionSeverity.major,
    'Eritromicina inibe CYP3A4 (metabolismo de metadona) e prolonga QTc. Metadona também prolonga QTc de forma dose-dependente',
    'Acúmulo de metadona → sedação, depresión respiratoria, prolongamento QTc grave, torsades de pointes. Risco fatal em doses elevadas de metadona',
    'Evitar combinación. Substituir eritromicina por azitromicina. Monitorar ECG (QTc), SpO₂ e sinais de superdosagem de metadona se mantida',
    'TORSADES DE POINTES + SUPERDOSAGEM DE METADONA — Substituir eritromicina por azitromicina; monitorar ECG',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.respiratoryDepression},
    [_kRefGG, _kRefMdx, _kRefUT]),

    // ── RITONAVIR (inibidor potentíssimo CYP3A4, 2D6, P-gp) ─────────────────

  ('ritonavir', 'estatina', InteractionSeverity.contraindicated,
    'Ritonavir inibe potentemente CYP3A4, a principal via de metabolismo de sinvastatina, lovastatina e atorvastatina. Pode aumentar os níveis de sinvastatina em mais de 30x',
    'Rabdomiólise grave por acúmulo maciço de estatinas → insuficiencia renal aguda, hiperpotasemia, morte. Um dos raros casos de interação com risco de vida imediato',
    'CONTRAINDICADO: ritonavir + sinvastatina/lovastatina. Usar rosuvastatina (moderadamente afetada — iniciar com 10mg) ou pravastatina (menos afetada por CYP3A4) com monitoramento de CK. Evitar doses altas de qualquer estatina com ritonavir',
    'CONTRAINDICADO — Ritonavir aumenta sinvastatina >30x; usar pravastatina ou rosuvastatina em dose baixa',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('ritonavir', 'quetiapina', InteractionSeverity.contraindicated,
    'Ritonavir inibe potentemente CYP3A4, a principal via de metabolismo da quetiapina. Pode aumentar os níveis de quetiapina em 10-20x. Ambos prolongam QTc',
    'Toxicidade grave de quetiapina: sedação profunda, hipotensão grave, prolongamento QTc com risco de torsades, depresión respiratoria. Casos fatais reportados',
    'CONTRAINDICADO. Substituir quetiapina por antipsicótico com menor dependência de CYP3A4 (haloperidol, aripiprazol). Consultar infectologista antes de iniciar TARV com ritonavir em pacientes em uso de quetiapina',
    'CONTRAINDICADO — Ritonavir aumenta quetiapina 10-20x; substituir por haloperidol ou aripiprazol',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.qtProlongation, RiskType.respiratoryDepression},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('ritonavir', 'benzodiazepínico', InteractionSeverity.contraindicated,
    'Ritonavir inibe potentemente CYP3A4, a principal via de metabolismo de alprazolam, diazepam, triazolam, midazolam e clonazepam. Pode aumentar os níveis em 10-30x. Lorazepam é menos afetado',
    'Sedação profunda e prolongada, depresión respiratoria grave, coma e morte. Triazolam e midazolam oral são as combinações mais perigosas',
    'CONTRAINDICADO: ritonavir + triazolam/midazolam oral (bula). Alprazolam, diazepam, clonazepam: evitar ou usar doses muito reducidas com monitoramento. Usar lorazepam (glucuronidação — menos afetado) quando sedação necessária',
    'CONTRAINDICADO com triazolam/midazolam — Ritonavir aumenta BZDs 10-30x; usar lorazepam se necesario',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.respiratoryDepression},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('ritonavir', 'fentanila', InteractionSeverity.major,
    'Ritonavir inibe CYP3A4, a principal via de metabolismo da fentanila. Pode aumentar significativamente os níveis de fentanila e prolonga sua meia-vida',
    'Sedação intensa, depresión respiratoria e apneia por acúmulo de fentanila. Especialmente perigoso em uso crônico (adesivos transdérmicos)',
    'Reduzir dose de fentanila em 50% ao iniciar ritonavir. Monitorar frequência respiratória, SpO₂ e nível de sedação. Tener naloxona disponible. Titular dose lentamente',
    'DEPRESSÃO RESPIRATÓRIA — Ritonavir aumenta fentanila; reduzir dose 50% e monitorar SpO₂',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('ritonavir', 'opioide', InteractionSeverity.major,
    'Ritonavir inibe CYP3A4 e CYP2D6, as principais vias de metabolismo de oxicodona, codeína, tramadol e fentanila. Pode aumentar os níveis em 50-100%. Morfina (glucuronidação) é menos afetada',
    'Sedación excesiva, depresión respiratoria, constipação intensa por acúmulo de opioides',
    'Preferir morfina (glucuronidação, menos afetada pelo CYP). Reduzir dose de opioides CYP3A4-dependentes em 30-50%. Monitorar SpO₂ e nível de sedação. Titular lentamente',
    'DEPRESSÃO RESPIRATÓRIA — Ritonavir aumenta opioides; preferir morfina e reduzir doses de CYP3A4-dependentes',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),

    // ── ENTRE INIBIDORES/INDUTORES CYP ────────────────────────────────────────

  ('claritromicina', 'eritromicina', InteractionSeverity.moderate,
    'Ambos inibem CYP3A4 e prolongam o intervalo QTc. A combinação não tem indicação terapéutica (espectro antibacteriano sobreposto) e potencializa os efeitos adversos de ambos',
    'Prolongamento QTc aditivo → risco aumentado de torsades de pointes. Toxicidade GI aumentada. Combinação sem benefício clínico justificável',
    'Evitar combinación. Usar apenas um dos agentes. Se necesario cobertura mais ampla, combinar com outro antibiótico de classe diferente',
    'SEM BENEFÍCIO CLÍNICO + QT PROLONGADO — Evitar combinación; mesma classe com efeitos adversos aditivos',
    EvidenceLevel.established,
    {RiskType.qtProlongation},
    [_kRefGG, _kRefMdx]),


  ('claritromicina', 'ritonavir', InteractionSeverity.major,
    'Ritonavir inibe CYP3A4, aumentando os níveis de claritromicina em 77%. Claritromicina inibe CYP3A4, podendo aumentar ritonavir. Ambos prolongam QTc',
    'Acúmulo de claritromicina → toxicidad (distúrbios auditivos, hepatotoxicidad, prolongamento QTc). Em insuficiencia renal, risco ainda maior',
    'Reduzir dose de claritromicina em 50% se TFG < 60mL/min. Monitorar ECG e função hepática. Azitromicina é a alternativa preferida em pacientes com TARV baseada em ritonavir',
    'QT PROLONGADO + TOXICIDADE — Reduzir claritromicina 50% em IR; monitorar ECG; preferir azitromicina em TARV',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('eritromicina', 'ritonavir', InteractionSeverity.major,
    'Ritonavir inibe CYP3A4, aumentando os níveis de eritromicina. Ambos prolongam QTc de forma dose-dependente',
    'Acúmulo de eritromicina → prolongamento QTc grave, torsades de pointes. Toxicidade GI aumentada',
    'Evitar combinación. Substituir eritromicina por azitromicina (menor interação e menor risco de QT). Se mantida: monitorar ECG rigurosamente',
    'TORSADES DE POINTES — Ritonavir aumenta eritromicina; substituir por azitromicina',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),


  ('isrs', 'amitriptilina', InteractionSeverity.major,
    'ISRSs (especialmente fluoxetina e paroxetina) inibem CYP2D6, principal via de metabolismo da amitriptilina. Aumentam seus níveis em 2-4x. Ambos têm atividade serotoninérgica somada',
    'Toxicidade por amitriptilina: arritmias (QT prolongado, bloqueio AV), hipotensão ortostática, retenção urinária, confusão. Risco de síndrome serotoninérgica',
    'Evitar fluoxetina e paroxetina com amitriptilina. Se necesario: sertralina (menor inibição de CYP2D6) em dose baixa. Monitorar ECG (QTc) e sinais de toxicidad tricíclica',
    'TOXICIDADE DE AMITRIPTILINA + QT PROLONGADO — Evitar fluoxetina/paroxetina; monitorar ECG',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.serotonin, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('isrs', 'mirtazapina', InteractionSeverity.moderate,
    'Mirtazapina tem mecanismo noradrenérgico/serotoninérgico (antagonismo α2 + 5-HT2/3). A combinação com ISRS é usada terapeuticamente em depressão refratária ("California Rocket"), mas aumenta o risco de síndrome serotoninérgica',
    'Risco moderado de síndrome serotoninérgica. Sedação aditiva por efeito anti-histamínico da mirtazapina + ISRS',
    'Combinação usada em depressão resistente sob supervisão especializada. Titular lentamente. Monitorar sinais de serotonina. Evitar em ambulatório sem suporte psiquiátrico',
    'SÍNDROME SEROTONINÉRGICA MODERADA — Combinação usada em depressão refratária; monitorar sinais serotoninérgicos',
    EvidenceLevel.probable,
    {RiskType.serotonin, RiskType.cns},
    [_kRefGG, _kRefMdx]),


  ('isrs', 'quetiapina', InteractionSeverity.moderate,
    'Quetiapina tem atividade serotoninérgica (antagonismo 5-HT2A). Fluoxetina inibe CYP3A4/2D6, podendo aumentar os níveis de quetiapina. Prolongamento QTc aditivo com citalopram/escitalopram',
    'Risco de síndrome serotoninérgica leve-moderada. QTc prolongado com citalopram + quetiapina. Sedação aditiva',
    'Monitorar ECG com citalopram/escitalopram + quetiapina. Monitorar sinais serotoninérgicos. Reduzir dose de quetiapina se fluoxetina for usada',
    'QT PROLONGADO + SEDAÇÃO — Monitorar ECG (especialmente citalopram + quetiapina) e sinais serotoninérgicos',
    EvidenceLevel.probable,
    {RiskType.qtProlongation, RiskType.serotonin},
    [_kRefGG, _kRefMdx]),


  ('isrs', 'haloperidol', InteractionSeverity.moderate,
    'Fluoxetina e paroxetina inibem CYP2D6, a principal via de metabolismo do haloperidol, aumentando os níveis em 50-100%. Ambos prolongam QTc',
    'Toxicidade de haloperidol: prolongamento QTc, sintomas extrapiramidais (acatisia, distonia aguda). Sedação aditiva',
    'Monitorar ECG e sinais extrapiramidais. Considerar reduzir dose de haloperidol em 30-50% com fluoxetina/paroxetina. Sertralina tem menor impacto em CYP2D6',
    'QT PROLONGADO + SINTOMAS EXTRAPIRAMIDAIS — Monitorar ECG; reduzir haloperidol com fluoxetina/paroxetina',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('isrs', 'olanzapina', InteractionSeverity.minor,
    'Fluoxetina inibe CYP2D6/1A2, podendo aumentar modestamente os níveis de olanzapina. Risco serotoninérgico teórico',
    'Aumento modesto da sedação e dos efeitos metabólicos (ganho de peso). Síndrome serotoninérgica improvável mas possível',
    'Monitorar sedação e ganho de peso. Combinação usada em depressão bipolar (fluoxetina + olanzapina = "OFC"). Sem ajuste de dose rotineiro necesario',
    'SEDAÇÃO AUMENTADA — Combinação usada em depressão bipolar; monitorar sedação e peso',
    EvidenceLevel.probable,
    {RiskType.cns},
    [_kRefGG, _kRefMdx]),

    // ── IMAO × outros SNC ─────────────────────────────────────────────────────

  ('imao', 'amitriptilina', InteractionSeverity.contraindicated,
    'IMAOs inibem a degradação de monoaminas; amitriptilina inibe recaptação de serotonina e noradrenalina. Combinação causa acúmulo maciço de monoaminas. Washout: 14 dias para IMAO irreversível',
    'Síndrome serotoninérgica grave (agitação, hipertermia, convulsiones, rabdomiólisis) e crise adrenérgica (hipertensão grave, arritmias). Potencialmente fatal',
    'CONTRAINDICADO. Washout de 14 dias após suspensão do IMAO antes de iniciar tricíclico. Nunca combinar',
    'CONTRAINDICADO — Síndrome serotoninérgica fatal; washout obligatorio de 14 dias',
    EvidenceLevel.established,
    {RiskType.serotonin},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('imao', 'opioide', InteractionSeverity.contraindicated,
    'Meperidina e tramadol têm atividade serotoninérgica e são contraindicados. Morfina e fentanila têm menor risco serotoninérgico, mas todos os opioides podem causar síndrome excitadora ou depressora com IMAOs',
    'Síndrome excitadora (agitação, convulsiones, hipertermia com meperidina/tramadol) ou síndrome depressora (coma, depresión respiratoria com morfina/fentanila). Ambas potencialmente fatais',
    'CONTRAINDICADO: IMAOs + meperidina ou tramadol (absoluto). Morfina e fentanila: usar com cautela extrema e monitoramento rigoroso se inevitável. Washout de 14 dias do IMAO antes de opioides',
    'CONTRAINDICADO com meperidina/tramadol — Síndromes excitadora ou depressora; usar morfina apenas com cautela extrema',
    EvidenceLevel.established,
    {RiskType.serotonin, RiskType.respiratoryDepression},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('imao', 'benzodiazepínico', InteractionSeverity.moderate,
    'IMAOs podem potencializar os efeitos sedativos do SNC dos benzodiazepínicos por mecanismos não totalmente elucidados. Interação de menor magnitude que outras combinações com IMAO',
    'Sedación excesiva, depresión respiratoria aumentada, hipotensão',
    'Usar com cautela. Reduzir dose do benzodiazepínico. Monitorar nível de sedação e FR. Evitar durante washout do IMAO',
    'SEDAÇÃO AUMENTADA — Usar dose reducida de benzodiazepínico; monitorar sedação e frequência respiratória',
    EvidenceLevel.probable,
    {RiskType.cns, RiskType.respiratoryDepression},
    [_kRefGG, _kRefMdx]),


  ('imao', 'quetiapina', InteractionSeverity.major,
    'IMAOs podem potencializar os efeitos da quetiapina no SNC e cardiovasculares. Risco de síndrome serotoninérgica por atividade 5-HT2A da quetiapina',
    'Sedação excessiva, hipotensão grave, risco de síndrome serotoninérgica',
    'Evitar combinación. Washout de 14 dias do IMAO. Se necesario antipsicótico durante transição: usar haloperidol com cautela',
    'EVITAR — Hipotensão grave e sedação; washout de 14 dias do IMAO antes de iniciar quetiapina',
    EvidenceLevel.probable,
    {RiskType.cns, RiskType.serotonin},
    [_kRefGG, _kRefMdx]),


  ('imao', 'haloperidol', InteractionSeverity.moderate,
    'IMAOs podem potencializar os efeitos do haloperidol no SNC. Risco de hipotensão e sedação aditivos',
    'Hipotensão grave, sedação excessiva, risco aumentado de efeitos extrapiramidais',
    'Usar com extrema cautela e apenas quando antipsicótico for indispensável durante washout. Monitorar PA e sedação rigurosamente',
    'HIPOTENSÃO + SEDAÇÃO — Usar apenas se indispensável durante washout; monitorar PA',
    EvidenceLevel.probable,
    {RiskType.cns},
    [_kRefGG, _kRefMdx]),


  ('amitriptilina', 'mirtazapina', InteractionSeverity.major,
    'Amitriptilina + mirtazapina: efeitos anticolinérgicos, antihistamínicos e sedativos aditivos. Ambas têm atividade serotoninérgica. Riesgo de toxicidad por acúmulo',
    'Sedação profunda, confusão, retenção urinária, visão turva, constipação grave, delirium anticolinérgico em idosos. QTc prolongado',
    'Evitar em idosos (síndrome anticolinérgica grave). Em adultos jovens: monitorar cognição, função vesical e ECG. Considerar alternativas mais seguras',
    'TOXICIDADE ANTICOLINÉRGICA + SEDAÇÃO GRAVE — Evitar em idosos; monitorar cognição e ECG',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.qtProlongation},
    [_kRefGG, _kRefMdx]),


  ('amitriptilina', 'quetiapina', InteractionSeverity.major,
    'Ambas prolongam o QTc e têm efeitos anticolinérgicos e sedativos significativos. Fluoxetina inibe CYP2D6/3A4, aumentando os níveis de ambas',
    'QTc prolongado com risco de torsades de pointes. Sedação excessiva e delirium anticolinérgico, especialmente em idosos',
    'Monitorar ECG (QTc) antes e durante o tratamento. Evitar em pacientes com QTc basal > 450ms. Evitar em idosos. Manter electrolitos normais',
    'QT PROLONGADO GRAVE + DELIRIUM — Monitorar ECG; evitar em idosos e pacientes com QTc > 450ms',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.cns},
    [_kRefGG, _kRefMdx]),


  ('amitriptilina', 'benzodiazepínico', InteractionSeverity.moderate,
    'Efeitos depressores do SNC aditivos. Amitriptilina tem efeitos sedativos intrínsecas (anti-H1). Benzodiazepínicos potencializam a sedação',
    'Sedación excesiva, depresión respiratoria (especialmente em idosos), comprometimento cognitivo, risco de quedas',
    'Evitar em idosos (critérios de Beers). Em adultos: usar doses mínimas efetivas de ambos. Advertir sobre dirigir e operar máquinas',
    'SEDAÇÃO EXCESSIVA — Evitar em idosos; usar doses mínimas e advertir sobre dirigir',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.respiratoryDepression},
    [_kRefGG, _kRefMdx]),


  ('amitriptilina', 'haloperidol', InteractionSeverity.major,
    'Ambos prolongam o QTc (haloperidol bloqueia IKr/hERG; amitriptilina prolonga QT por múltiplos mecanismos) e têm efeitos anticolinérgicos aditivos',
    'QTc prolongado com risco de torsades de pointes. Delirium anticolinérgico, especialmente em idosos',
    'Monitorar ECG (QTc). Evitar em pacientes com QTc > 450ms ou hipopotasemia/hipomagnesemia. Considerar alternativas com menor impacto no QT',
    'QT PROLONGADO + DELIRIUM ANTICOLINÉRGICO — Monitorar ECG; evitar se QTc > 450ms',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.cns},
    [_kRefGG, _kRefMdx]),


  ('amitriptilina', 'olanzapina', InteractionSeverity.moderate,
    'Efeitos anticolinérgicos, sedativos e metabólicos aditivos (ganho de peso, hiperglucemia). Ambas prolongam modestamente o QTc',
    'Sedação excessiva, delirium anticolinérgico em idosos, ganho de peso, intolerância à glicose, QTc prolongado',
    'Evitar em idosos e pacientes com risco metabólico/DM2. Monitorar peso, glucemia e ECG. Preferir alternativas com menor perfil anticolinérgico',
    'TOXICIDADE ANTICOLINÉRGICA + METABÓLICA — Evitar em idosos; monitorar peso, glucemia e ECG',
    EvidenceLevel.probable,
    {RiskType.cns, RiskType.qtProlongation},
    [_kRefGG, _kRefMdx]),


  ('amitriptilina', 'imao reversivel', InteractionSeverity.contraindicated,
    'Mesmo que IMAO irreversível: amitriptilina + moclobemida pode causar síndrome serotoninérgica por atividade serotoninérgica somada',
    'Síndrome serotoninérgica: agitação, mioclonias, hipertermia, convulsiones',
    'CONTRAINDICADO. Washout de 1 dia após moclobemida; washout de 7 dias após amitriptilina antes de moclobemida',
    'CONTRAINDICADO — Síndrome serotoninérgica; washout obligatorio mesmo com IMAO reversível',
    EvidenceLevel.established,
    {RiskType.serotonin},
    [_kRefGG, _kRefMdx]),


  ('bupropiona', 'amitriptilina', InteractionSeverity.major,
    'Bupropiona inibe CYP2D6, aumentando os níveis de amitriptilina em 2-4x. Ambos abaixam o limiar convulsivo',
    'Toxicidade por amitriptilina (QTc prolongado, efeitos anticolinérgicos, arritmias) + risco aumentado de convulsiones',
    'Evitar combinación. Se antidepressivo dual necesario: preferir combinação de ISRS + mirtazapina. Monitorar ECG e nível de amitriptilina se mantida',
    'TOXICIDADE DE AMITRIPTILINA + CONVULSÕES — Bupropiona aumenta amitriptilina 2-4x; evitar combinação',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.seizure, RiskType.qtProlongation},
    [_kRefGG, _kRefMdx]),


  ('bupropiona', 'haloperidol', InteractionSeverity.moderate,
    'Bupropiona inibe CYP2D6, aumentando os níveis de haloperidol. Ambos abaixam o limiar convulsivo',
    'Toxicidade de haloperidol: prolongamento QTc, sintomas extrapiramidais. Risco aumentado de convulsiones',
    'Monitorar ECG e sintomas extrapiramidais. Considerar reduzir dose de haloperidol. Monitorar sinais de toxicidad',
    'QT PROLONGADO + EXTRAPIRAMIDAL — Monitorar ECG e sintomas extrapiramidais; reduzir dose de haloperidol',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel, RiskType.qtProlongation, RiskType.seizure},
    [_kRefGG, _kRefMdx]),


  ('bupropiona', 'quetiapina', InteractionSeverity.moderate,
    'Bupropiona inibe CYP2D6, podendo aumentar os metabólitos ativos da quetiapina. Ambos abaixam o limiar convulsivo e alteram o limiar convulsivo',
    'Risco aumentado de convulsiones. Sedação aditiva',
    'Usar com cautela em pacientes com histórico de convulsiones. Monitorar sedação e limiar convulsivo',
    'CONVULSÕES — Usar com cautela; ambos abaixam limiar convulsivo; evitar em pacientes com epilepsia',
    EvidenceLevel.probable,
    {RiskType.seizure, RiskType.cns},
    [_kRefGG, _kRefMdx]),


  ('bupropiona', 'mirtazapina', InteractionSeverity.moderate,
    'Bupropiona (noradrenérgica/dopaminérgica) + mirtazapina (noradrenérgica/serotoninérgica) é combinação usada em depressão refratária. Bupropiona inibe CYP2D6, podendo aumentar metabólitos da mirtazapina',
    'Risco moderado de convulsiones (bupropiona abaixa limiar). Insônia paradoxal (bupropiona ativa; mirtazapina sedativa)',
    'Combinação usada em depressão resistente ("rocket fuel"). Titular lentamente. Monitorar limiar convulsivo e efeitos opostos na sedação/sono',
    'RISCO DE CONVULSÕES — Combinação usada em depressão refratária; monitorar limiar convulsivo e sono',
    EvidenceLevel.probable,
    {RiskType.seizure},
    [_kRefGG, _kRefMdx]),


  ('bupropiona', 'imao reversivel', InteractionSeverity.contraindicated,
    'Bupropiona inibe recaptação de dopamina e noradrenalina; moclobemida inibe MAO-A. Combinação causa acúmulo de monoaminas',
    'Crise hipertensiva, convulsiones, síndrome adrenérgica grave',
    'CONTRAINDICADO. Washout de 1 dia após moclobemida antes de iniciar bupropiona',
    'CONTRAINDICADO — Crise hipertensiva e convulsiones',
    EvidenceLevel.established,
    {RiskType.serotonin},
    [_kRefGG, _kRefMdx]),


  ('opioide', 'mirtazapina', InteractionSeverity.moderate,
    'Mirtazapina tem efeitos sedativos potentes (anti-H1). A combinação com opioides potencializa a depressão do SNC. Risco serotoninérgico teórico (mirtazapina ativa 5-HT indireto)',
    'Sedación excesiva, depresión respiratoria aumentada, especialmente em início de tratamento ou com doses elevadas',
    'Monitorar sedação e frequência respiratória. Usar doses mínimas de ambos. Advertir paciente sobre risco de quedas e comprometimento cognitivo',
    'SEDAÇÃO + DEPRESSÃO RESPIRATÓRIA — Monitorar SpO₂ e sedação; usar doses mínimas de ambos',
    EvidenceLevel.probable,
    {RiskType.cns, RiskType.respiratoryDepression},
    [_kRefGG, _kRefMdx]),


  ('opioide', 'quetiapina', InteractionSeverity.major,
    'Quetiapina tem potentes efeitos sedativos e depressores do SNC. A combinação com opioides potencializa a depresión respiratoria. Quetiapina inibe CYP2D6/3A4 variadamente',
    'Sedação profunda, depresión respiratoria grave, hipotensão, risco de aspiração e morte. Combinação frecuentemente envolvida em óbitos por superdosagem acidental',
    'Evitar uso concomitante em altas doses. Se necesario: usar doses mínimas de ambos, monitorar SpO₂ e PA. Prescrever naloxona de resgate. Educar paciente e família',
    'DEPRESSÃO RESPIRATÓRIA GRAVE — Evitar altas doses combinadas; prescrever naloxona; monitorar SpO₂',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns},
    [_kRefGG, _kRefMdx]),


  ('opioide', 'haloperidol', InteractionSeverity.moderate,
    'Haloperidol potencializa os efeitos sedativos dos opioides. Usado terapeuticamente em cuidados paliativos (controle de náusea + dor), mas com risco de sedação excessiva',
    'Sedação excessiva, hipotensão ortostática, depresión respiratoria em doses elevadas de ambos',
    'Em cuidados paliativos: titulação cuidadosa com doses mínimas. Monitorar nível de sedação (RASS), PA e FR. Tener naloxona disponible',
    'SEDAÇÃO AUMENTADA — Em CP: titular cuidadosamente; monitorar RASS, PA e FR; ter naloxona disponible',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.respiratoryDepression},
    [_kRefGG, _kRefMdx]),


  ('fentanila', 'midazolam', InteractionSeverity.major,
    'Fentanila (depressor respiratório μ-opioide) + midazolam (benzodiazepínico GABA-A) é combinação de alto risco para sedação procedural. O efeito sinérgico (não apenas aditivo) pode precipitar apneia mesmo com doses que seriam seguras individualmente',
    'Apneia, dessaturação grave (SpO₂ < 85%), bradicardia, parada respiratória. Combinação responsável por incidentes graves em sedação procedural e UTI',
    'Usar apenas em ambiente monitorizado com acesso imediato a bolsa-válvula-máscara, oxigênio e flumazenil + naloxona. Titular em doses fracionadas. Monitorar SpO₂ e ETCO₂ continuamente',
    'APNEIA — Usar apenas em ambiente monitorizado; ter naloxona + flumazenil disponíveis; monitorar SpO₂ e ETCO₂',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('tramadol', 'quetiapina', InteractionSeverity.moderate,
    'Quetiapina inibe parcialmente CYP2D6, podendo aumentar os níveis de tramadol. Ambos abaixam o limiar convulsivo e têm efeitos sedativos',
    'Convulsões, sedação excessiva, síndrome serotoninérgica leve',
    'Usar com cautela. Evitar em pacientes com histórico de convulsiones. Monitorar sedação e limiar convulsivo',
    'CONVULSÕES + SEDAÇÃO — Usar com cautela; ambos abaixam limiar convulsivo; evitar em epilépticos',
    EvidenceLevel.probable,
    {RiskType.seizure, RiskType.cns},
    [_kRefGG, _kRefMdx]),


  ('tramadol', 'haloperidol', InteractionSeverity.moderate,
    'Haloperidol inibe CYP2D6, podendo aumentar os níveis de tramadol e seu metabolito ativo. Ambos abaixam o limiar convulsivo',
    'Convulsões, sedação excessiva, síndrome serotoninérgica',
    'Usar com cautela. Evitar em pacientes com epilepsia. Para analgesia: preferir morfina com haloperidol',
    'CONVULSÕES — Evitar em epilépticos; preferir morfina para analgesia com haloperidol',
    EvidenceLevel.probable,
    {RiskType.seizure, RiskType.cns},
    [_kRefGG, _kRefMdx]),

    // ── MIRTAZAPINA × outros ──────────────────────────────────────────────────

  ('mirtazapina', 'quetiapina', InteractionSeverity.moderate,
    'Efeitos sedativos aditivos (ambas têm potente atividade anti-H1). Risco serotoninérgico teórico. Quetiapina prolonga QTc',
    'Sedação profunda e prolongada, especialmente ao início. Risco de quedas em idosos. QTc prolongado',
    'Monitorar sedação, especialmente nas primeiras semanas. Evitar em idosos com risco de quedas. Monitorar ECG',
    'SEDAÇÃO PROFUNDA — Monitorar sedação; evitar em idosos com risco de quedas; monitorar ECG',
    EvidenceLevel.probable,
    {RiskType.cns, RiskType.qtProlongation},
    [_kRefGG, _kRefMdx]),


  ('mirtazapina', 'haloperidol', InteractionSeverity.moderate,
    'Efeitos sedativos aditivos. Haloperidol prolonga QTc; mirtazapina prolonga QTc modestamente. Combinação usada em alucinações + insônia em cuidados paliativos',
    'Sedação excessiva, prolongamento QTc, hipotensão ortostática, risco de quedas em idosos',
    'Monitorar ECG (QTc) e sedação. Usar doses mínimas. Em CP: titulação cuidadosa com monitoramento',
    'QT PROLONGADO + SEDAÇÃO — Monitorar ECG e sedação; usar doses mínimas',
    EvidenceLevel.probable,
    {RiskType.qtProlongation, RiskType.cns},
    [_kRefGG, _kRefMdx]),


  ('mirtazapina', 'olanzapina', InteractionSeverity.moderate,
    'Efeitos sedativos, antihistamínicos e metabólicos aditivos. Ambas aumentam peso e risco de síndrome metabólica',
    'Sedação intensa, ganho de peso significativo, resistência à insulina, dislipidemia',
    'Monitorar peso, glucemia, perfil lipídico e pressão arterial. Usar doses mínimas. Evitar em pacientes com obesidade ou DM2',
    'SÍNDROME METABÓLICA + SEDAÇÃO — Monitorar peso, glucemia e lipídios; evitar em pacientes obesos/diabéticos',
    EvidenceLevel.established,
    {RiskType.cns},
    [_kRefGG, _kRefMdx]),

    // ── QUETIAPINA / HALOPERIDOL / OLANZAPINA × entre si ─────────────────────

  ('quetiapina', 'haloperidol', InteractionSeverity.major,
    'Ambos prolongam o QTc (haloperidol é um dos mais potentes; quetiapina também). Efeitos sedativos e extrapiramidais aditivos',
    'QTc prolongado com alto risco de torsades de pointes. Sedação excessiva. Somatório de efeitos extrapiramidais. Raramente indicado combinar dois antipsicóticos',
    'Evitar combinación. Raramente indicada (exceto transição controlada). Se usada: monitorar ECG rigurosamente, corrigir electrolitos, usar doses mínimas',
    'QT PROLONGADO GRAVE — Evitar combinación de antipsicóticos; monitorar ECG se indispensável',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),


  ('quetiapina', 'olanzapina', InteractionSeverity.moderate,
    'Ambas têm efeitos sedativos, metabólicos e anticolinérgicos aditivos. Raramente indicada a combinação',
    'Sedação excessiva, síndrome metabólica, efeitos anticolinérgicos aditivos. Sem benefício clínico adicional sobre monoterapia em doses adecuadas',
    'Evitar combinación. Otimizar dose do antipsicótico único antes de combinar. Se usada: monitorar peso, glucemia, sedação',
    'EFEITOS METABÓLICOS + SEDAÇÃO ADITIVOS — Evitar; otimizar monoterapia antes de combinar antipsicóticos',
    EvidenceLevel.probable,
    {RiskType.cns},
    [_kRefGG, _kRefMdx]),


  ('haloperidol', 'olanzapina', InteractionSeverity.moderate,
    'Efeitos extrapiramidais aditivos (haloperidol D2 típico; olanzapina atípico). Ambos prolongam QTc. Raramente indicada a combinação',
    'Sintomas extrapiramidais graves (acatisia, distonia), sedação excessiva, QTc prolongado',
    'Evitar combinación de antipsicóticos. Se usada em transição: monitorar sintomas extrapiramidais e ECG',
    'EXTRAPIRAMIDAL + QT PROLONGADO — Evitar; monitorar sintomas EPS e ECG na transição',
    EvidenceLevel.probable,
    {RiskType.qtProlongation},
    [_kRefGG, _kRefMdx]),

    // ── CARBONATO DE LÍTIO × SNC (pares ausentes relevantes) ─────────────────

  ('carbonato de litio', 'isrs', InteractionSeverity.major,
    'Lítio tem propriedades serotoninérgicas (aumenta síntese e liberação de 5-HT). ISRSs inibem recaptação de serotonina. Combinação usada em depressão refratária, mas com risco serotoninérgico',
    'Síndrome serotoninérgica: tremor, mioclonias, diaforese, hipertermia, agitação, especialmente com fluoxetina (que também inibe CYP2D6 e pode alterar excreção renal de lítio)',
    'Combinação usada em psiquiatria com monitoramento. Titular lentamente. Monitorar nivel sérico de lítio (alvo 0,6-1,0 mEq/L) e sinais serotoninérgicos',
    'SÍNDROME SEROTONINÉRGICA — Combinação usada em DR; monitorar nivel sérico de lítio e sinais serotoninérgicos',
    EvidenceLevel.established,
    {RiskType.serotonin, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('carbonato de litio', 'tramadol', InteractionSeverity.major,
    'Lítio tem propriedades serotoninérgicas + tramadol inibe recaptação de serotonina. Ambos abaixam o limiar convulsivo',
    'Síndrome serotoninérgica e convulsiones por mecanismos aditivos',
    'Evitar combinación. Para analgesia com lítio: preferir paracetamol (cuidado com AINEs — alteram excreção renal de lítio) ou morfina',
    'SÍNDROME SEROTONINÉRGICA + CONVULSÕES — Evitar tramadol com lítio; usar paracetamol ou morfina',
    EvidenceLevel.established,
    {RiskType.serotonin, RiskType.seizure},
    [_kRefGG, _kRefMdx]),


  ('carbonato de litio', 'imao', InteractionSeverity.major,
    'Lítio aumenta síntese de serotonina; IMAOs inibem sua degradação. Interação com potencial serotoninérgico significativo',
    'Síndrome serotoninérgica, crise adrenérgica, toxicidad do lítio por interações hemodinâmicas',
    'Evitar combinación. Washout de 14 dias do IMAO antes de iniciar lítio. Monitorar nivel sérico de lítio se mantidos',
    'SÍNDROME SEROTONINÉRGICA — Evitar; washout de 14 dias do IMAO',
    EvidenceLevel.probable,
    {RiskType.serotonin},
    [_kRefGG, _kRefMdx]),


  ('carbonato de litio', 'quetiapina', InteractionSeverity.moderate,
    'Combinação amplamente usada em transtorno bipolar. Quetiapina prolonga QTc; lítio prolonga QTc em toxicidad. Em doses terapéuticas: risco moderado de sedação aditiva e QTc',
    'Sedação aditiva, prolongamento QTc, síndrome neuroléptica maligna raramente descrita com lítio + antipsicótico. Hiponatremia por lítio pode aumentar toxicidad',
    'Monitorar nivel sérico de lítio (0,6-1,0 mEq/L) e ECG regularmente. Manter hidratação adecuada. Monitorar electrolitos e función renal',
    'MONITORAR NÍVEL DE LÍTIO + ECG — Combinação usada em TB; manter hidratação e monitorar electrolitos',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('carbonato de litio', 'olanzapina', InteractionSeverity.moderate,
    'Combinação usada em transtorno bipolar. Efeitos metabólicos (ganho de peso, hiperglucemia) aditivos. Olanzapina pode mascarar sinais de toxicidad de lítio',
    'Síndrome metabólica, ganho de peso excessivo, hiperglucemia, SNM raramente descrito',
    'Monitorar peso, glucemia, perfil lipídico e nivel sérico de lítio. Rastrear DM2. Combinação preferida ao haloperidol + lítio',
    'SÍNDROME METABÓLICA — Monitorar peso, glucemia e nível de lítio; combinação usada em TB',
    EvidenceLevel.established,
    {RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('aminoglicosideo', 'espironolactona', InteractionSeverity.minor,
    'Espironolactona pode reduzir a excreção renal de aminoglicosídeos ao competir por transportadores tubulares. Risco geralmente baixo',
    'Possível acúmulo discreto de aminoglicosídeo com maior risco de nefrotoxicidad',
    'Monitorar nivel sérico do aminoglicosídeo e función renal regularmente',
    'MONITORAR — Espironolactona pode reduzir excreção renal de aminoglicosídeos; dosar nivel sérico',
    EvidenceLevel.possible,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx]),


  ('aminoglicosideo', 'enalapril', InteractionSeverity.moderate,
    'IECAs reduzem a TFG ao bloquear a angiotensina II (vasoconstritora da arteríola eferente), diminuindo a pressão de filtração. Em situações de hipoperfusão renal, isso pode elevar o nível de aminoglicosídeos',
    'Risco aumentado de nefrotoxicidad e de acúmulo de aminoglicosídeos em pacientes com TFG reducida ou hipovolemia',
    'Monitorar función renal e nivel sérico do aminoglicosídeo. Garantir euvolemia antes e durante o tratamento. Ajustar dose do aminoglicosídeo conforme TFG',
    'NEFROTOXICIDADE AUMENTADA — Monitorar TFG e nivel sérico; garantir euvolemia',
    EvidenceLevel.probable,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx]),


  ('aminoglicosideo', 'losartana', InteractionSeverity.moderate,
    'BRAs reduzem a TFG de forma análoga aos IECAs, podendo aumentar o risco de acúmulo e nefrotoxicidad de aminoglicosídeos',
    'Nefrotoxicidad aumentada em pacientes com TFG reducida ou uso concomitante com outros nefrotóxicos',
    'Monitorar función renal e nivel sérico do aminoglicosídeo. Garantir euvolemia. Ajustar dose por TFG',
    'NEFROTOXICIDADE AUMENTADA — Monitorar TFG e nivel sérico; garantir euvolemia com BRA',
    EvidenceLevel.probable,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx]),

    // ── VANCOMICINA × nefrotóxicos ────────────────────────────────────────────

  ('vancomicina', 'cisplatina', InteractionSeverity.major,
    'Ambas são nefrotóxicas: cisplatina causa dano tubular por adutos de DNA e estresse oxidativo; vancomicina acumula nos túbulos por endocitose mediada por megalina. Combinação com risco sinérgico',
    'IRA grave, especialmente em pacientes oncológicos que já têm comprometimento renal por outros quimioterápicos. Riesgo de toxicidad permanente',
    'Separar administrações por 48-72h quando possível. Hidratação vigorosa com cisplatina. Monitorar AUC de vancomicina. Considerar alternativas (linezolida, daptomicina)',
    'NEFROTOXICIDADE GRAVE — Separar por 48-72h; hidratação vigorosa; AUC-guided vancomicina',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx]),


  ('vancomicina', 'espironolactona', InteractionSeverity.minor,
    'Espironolactona compete por transportadores tubulares renais, podendo reduzir discretamente a excreção de vancomicina',
    'Possível acúmulo discreto de vancomicina com risco aumentado de nefrotoxicidad',
    'Monitorar AUC de vancomicina e función renal durante uso concomitante',
    'MONITORAR — Possível acúmulo de vancomicina; monitorar AUC e función renal',
    EvidenceLevel.possible,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx]),


  ('vancomicina', 'enalapril', InteractionSeverity.moderate,
    'IECAs reduzem a TFG, diminuindo a eliminação de vancomicina e aumentando o risco de acúmulo e nefrotoxicidad',
    'Nefrotoxicidad por acúmulo de vancomicina, especialmente em pacientes com TFG de base reducida',
    'Monitorar TFG e AUC de vancomicina. Ajustar dose/intervalo de vancomicina conforme TFG. Garantir euvolemia',
    'NEFROTOXICIDADE AUMENTADA — IECA reduz eliminação de vancomicina; AUC-guided monitoring',
    EvidenceLevel.probable,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx]),

    // ── CISPLATINA × electrolitos e diuréticos ────────────────────────────────

  ('cisplatina', 'furosemida', InteractionSeverity.major,
    'Cisplatina causa depleção de magnésio, potássio e cálcio. Furosemida potencializa a perda renal de electrolitos e pode exacerbar a nefrotoxicidad da cisplatina ao reduzir o volume intravascular',
    'Hipomagnesemia grave (pode causar arritmias, convulsiones, tetania), hipopotasemia, hipocalcemia. Nefrotoxicidad potencializada',
    'Reposição profilática de magnésio (MgSO4 2-4g IV) durante e após cada ciclo. Monitorar electrolitos (Mg, K, Ca, Na) a cada ciclo. Hidratação vigorosa. Usar furosemida apenas se sobrecarga hídrica comprovada',
    'HIPOMAGNESEMIA GRAVE + NEFROTOXICIDADE — Repor MgSO4 profilático; monitorar electrolitos a cada ciclo',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.electrolyte},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('cisplatina', 'hidroclorotiazida', InteractionSeverity.major,
    'Hidroclorotiazida exacerba as perdas eletrolíticas causadas pela cisplatina (Mg, K, Na) e pode comprometer a hidratação necessária para proteger os rins durante a quimioterapia',
    'Hipomagnesemia, hipopotasemia e hiponatremia graves. Aumento da nefrotoxicidad por depleção de volume',
    'Considerar suspender hidroclorotiazida durante ciclos de cisplatina. Monitorar electrolitos antes, durante e após cada ciclo. Hidratação vigorosa obrigatória com cisplatina',
    'DISTÚRBIOS ELETROLÍTICOS GRAVES + NEFROTOXICIDADE — Suspender HCTZ durante ciclos; repor electrolitos',
    EvidenceLevel.probable,
    {RiskType.nephrotoxicity, RiskType.electrolyte},
    [_kRefGG, _kRefMdx]),


  ('cisplatina', 'enalapril', InteractionSeverity.moderate,
    'IECAs reduzem a TFG e a pressão de filtração glomerular; cisplatina já compromete o rim. Combinação aumenta risco de IRA. IECAs também reduzem a pressão de filtração glomerular, podendo impedir a eliminação de cisplatina',
    'IRA aditiva. Acúmulo de cisplatina por redução da TFG → aumento da toxicidad sistêmica',
    'Considerar suspender IECA durante os ciclos de cisplatina. Monitorar creatinina e TFG rigurosamente. Manter hidratação',
    'IRA ADITIVA — Considerar suspender IECA durante ciclos de cisplatina; monitorar TFG',
    EvidenceLevel.probable,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx]),

    // ── FUROSEMIDA × electrolitos e renina-angiotensina ───────────────────────

  ('furosemida', 'hidroclorotiazida', InteractionSeverity.major,
    'Combinação de diuréticos de alça + tiazídico (bloqueio sequencial nefron) tem efeito diurético sinérgico poderoso. Usada terapeuticamente em IC refratária, mas com alto risco de desequilíbrio',
    'Depleção grave de volume (hipotensão, pré-renal), hipopotasemia grave (arritmias ventriculares), hiponatremia, hipomagnesemia, alcalose metabólica',
    'Usar apenas sob supervisão especializada em IC refratária. Monitorar ureia, creatinina, electrolitos (K, Mg, Na) e PA diariamente ao iniciar. Reposição de potássio e magnésio obrigatória',
    'DEPLEÇÃO GRAVE DE VOLUME + HIPOCALEMIA — Monitorar electrolitos e PA diariamente; repor K e Mg',
    EvidenceLevel.established,
    {RiskType.electrolyte, RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('furosemida', 'espironolactona', InteractionSeverity.moderate,
    'Combinação sinérgica e poupadora de potássio, amplamente usada em IC e cirrose. Furosemida causa hipopotasemia; espironolactona causa hiperpotasemia. O balanço é geralmente favorável, mas pode pender para qualquer lado',
    'Hipocalemia (furosemida domina) ou hiperpotasemia (espironolactona domina, especialmente em IR). Depleção de volume se doses excessivas. Ginecomastia por espironolactona',
    'Monitorar K, Mg, Na, creatinina e PA regularmente. Ajustar doses pelo K sérico. Reduzir espironolactona se K > 5,5 mEq/L. Evitar em TFG < 30mL/min',
    'MONITORAR POTÁSSIO — Hipocalemia ou hiperpotasemia possíveis; ajustar doses pelo K sérico; evitar se TFG < 30',
    EvidenceLevel.established,
    {RiskType.electrolyte, RiskType.hyperkalemia},
    [_kRefGG, _kRefMdx]),


  ('furosemida', 'enalapril', InteractionSeverity.major,
    'IECAs reduzem a angiotensina II (responsável por manter a TFG em estados de hipovolemia). Furosemida causa depleção de volume. A combinação pode precipitar IRA pré-renal, especialmente ao iniciar IECA em pacientes já diuretizados',
    'IRA pré-renal ("first-dose hypotension"), hipotensão grave na primeira dose do IECA, hiperpotasemia (IECA retém K), hiponatremia',
    'Reduzir ou suspender furosemida 24-48h antes da primeira dose do IECA. Iniciar IECA em dose baixa. Monitorar PA, creatinina e K nas primeiras 48h. Reintroduzir furosemida após estabilização',
    'IRA POR HIPOTENSÃO — Suspender furosemida 24-48h antes da 1ª dose do IECA; iniciar IECA em dose baixa',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.electrolyte},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('furosemida', 'losartana', InteractionSeverity.major,
    'Interação análoga à furosemida + enalapril. BRAs bloqueiam receptor AT1, reduzindo vasoconstrição eferente. Depleção de volume por furosemida precipita hipotensão e IRA',
    'IRA pré-renal, hipotensão grave na primeira dose do BRA, hiperpotasemia',
    'Reduzir furosemida 24-48h antes de iniciar losartana. Começar com dose baixa de losartana. Monitorar PA, creatinina e K nas primeiras 48h',
    'IRA POR HIPOTENSÃO — Suspender furosemida 24-48h antes da 1ª dose do BRA; monitorar PA e creatinina',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.electrolyte},
    [_kRefGG, _kRefMdx]),

    // ── HIDROCLOROTIAZIDA × renina-angiotensina e electrolitos ─────────────────

  ('hidroclorotiazida', 'espironolactona', InteractionSeverity.moderate,
    'Combinação poupadora de potássio usada em hipertensão e IC leve. HCTZ causa hipopotasemia; espironolactona causa hiperpotasemia. O balanço pode ser favorável ou pender para hiperpotasemia em IR',
    'Hipercalemia se TFG reducida, especialmente em idosos diabéticos com nefropatia. Depleção de volume se doses altas de ambas',
    'Monitorar K, Na, Mg e creatinina. Reduzir espironolactona se K > 5,5 mEq/L. Evitar em TFG < 30mL/min ou K basal > 5,0 mEq/L',
    'HIPERCALEMIA EM IR — Monitorar K e TFG; evitar se K basal > 5,0 ou TFG < 30',
    EvidenceLevel.established,
    {RiskType.hyperkalemia, RiskType.electrolyte},
    [_kRefGG, _kRefMdx]),


  ('hidroclorotiazida', 'losartana', InteractionSeverity.moderate,
    'Análogo ao HCTZ + enalapril. BRA + tiazídico é combinação de primeira linha para hipertensão. Risco de hipotensão e hiperpotasemia',
    'Hipotensão de primeira dose, hiperpotasemia, IRA pré-renal em estados de hipovolemia',
    'Monitorar PA, K e creatinina após início. Reduzir HCTZ se PA muito reducida',
    'HIPOTENSÃO + HIPERCALEMIA — Monitorar PA, K e creatinina; reduzir HCTZ se necesario',
    EvidenceLevel.established,
    {RiskType.electrolyte},
    [_kRefGG, _kRefMdx]),


  ('espironolactona', 'carbonato de litio', InteractionSeverity.moderate,
    'Espironolactona pode alterar os níveis de lítio de forma imprevisível. Alguns estudos mostram elevação (por retenção de Na com carga de Na baixa), outros redução',
    'Toxicidade de lítio ou falha terapéutica por alteração imprevisível dos níveis séricos',
    'Monitorar nivel sérico de lítio ao iniciar ou modificar espironolactona. Manter ingestão de sódio estável',
    'NÍVEL DE LÍTIO IMPREVISÍVEL — Monitorar nivel sérico de lítio ao iniciar espironolactona',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),

    // ── CISPLATINA × outros nefrotóxicos/electrolitos ─────────────────────────

  ('cisplatina', 'espironolactona', InteractionSeverity.minor,
    'Espironolactona pode repor potássio e magnésio perdidos pela cisplatina (efeito protetor parcial). Porém, em IRA induzida por cisplatina, a retenção de K pela espironolactona pode causar hiperpotasemia',
    'Hipercalemia em contexto de IRA por cisplatina. Proteção parcial contra hipopotasemia/hipomagnesemia em función renal preservada',
    'Monitorar K, Mg e TFG rigurosamente. Suspender espironolactona se K > 5,5 ou em IRA',
    'HIPERCALEMIA EM IRA — Monitorar K e TFG; suspender espironolactona se IRA ou K > 5,5',
    EvidenceLevel.possible,
    {RiskType.hyperkalemia, RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx]),


  ('metformina', 'corticosteroide sistemico', InteractionSeverity.major,
    'Corticosteroides sistêmicos causam hiperglucemia por múltiplos mecanismos (resistência à insulina, gliconeogênese hepática, lipólise). A metformina sozinha raramente controla a hiperglucemia induzida por corticoide',
    'Hiperglucemia grave e descontrolada durante corticoterapia, especialmente em diabéticos. Descompensação glicêmica que pode requerer insulina',
    'Aumentar monitorização da glucemia durante corticoterapia (glucemia capilar pré e pós-refeições). Metformina insuficiente em hiperglucemia grave por corticoide — adicionar sulfonilureia ou insulina. Reduzir ajustes ao suspender corticoide',
    'HIPERGLICEMIA GRAVE — Corticoide antagoniza metformina; aumentar monitorização e considerar insulina',
    EvidenceLevel.established,
    {RiskType.hypoglycemia},
    [_kRefGG, _kRefMdx]),


  ('metformina', 'enalapril', InteractionSeverity.minor,
    'IECAs podem melhorar a sensibilidade à insulina e reduzir levemente a glucemia. Em combinação com metformina, risco teórico de hipoglucemia leve',
    'Hipoglucemia leve, especialmente em pacientes idosos ou com dieta restrita',
    'Monitorar glucemia. Combinação usada com frequência em DM2 + HAS. Ajuste raramente necesario',
    'HIPOGLICEMIA LEVE — Combinação usual; monitorar glucemia especialmente em idosos',
    EvidenceLevel.probable,
    {RiskType.hypoglycemia},
    [_kRefGG, _kRefMdx]),

    // ── INSULINA × corticosteroides e outros ─────────────────────────────────

  ('insulina', 'corticosteroide sistemico', InteractionSeverity.major,
    'Corticosteroides causam hiperglucemia por resistência à insulina e gliconeogênese aumentada. A necessidade de insulina pode aumentar dramaticamente (2-4x) durante corticoterapia intensa, especialmente em altas doses (> 40mg prednisona/dia)',
    'Hiperglucemia grave e cetoácidose diabética em diabéticos tipo 1. Descompensação glicêmica intensa em tipo 2. Hipoglucemia de rebote ao suspender corticoide abruptamente',
    'Aumentar doses de insulina durante corticoterapia (monitorar glucemia capilar 4-6x/dia). Padrão típico: hiperglucemia pós-prandial dominante → preferir insulina prandial ajustada. Reduzir insulina gradualmente ao suspender corticoide',
    'HIPERGLICEMIA GRAVE — Corticoide aumenta necessidade de insulina 2-4x; monitorar glucemia 4-6x/dia',
    EvidenceLevel.established,
    {RiskType.hypoglycemia},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('insulina', 'isrs', InteractionSeverity.moderate,
    'ISRSs (especialmente fluoxetina) aumentam a sensibilidade à insulina e têm efeito hipoglucemiante modesto. Em diabéticos usando insulina, podem aumentar o risco de hipoglucemia',
    'Hipoglucemia, especialmente nas primeiras semanas de tratamento com ISRS',
    'Monitorar glucemia nas primeiras semanas ao iniciar ISRS em pacientes usando insulina. Pode ser necesario reduzir dose de insulina',
    'HIPOGLICEMIA — ISRSs aumentam sensibilidade à insulina; monitorar glucemia ao iniciar antidepressivo',
    EvidenceLevel.probable,
    {RiskType.hypoglycemia},
    [_kRefGG, _kRefMdx]),


  ('insulina', 'sulfonilureia', InteractionSeverity.major,
    'Efeito hipoglucemiante aditivo e sinérgico: insulina reduz diretamente a glucemia; sulfonilureias estimulam a secreção pancreática de insulina. Combinação com risco elevado de hipoglucemia grave',
    'Hipoglucemia grave, prolongada e recorrente. Risco especialmente alto em idosos, IR, desnutrição e uso de sulfoniureias de longa ação (glibenclamida)',
    'Monitorar glucemia frecuentemente. Preferir sulfonilureias de ação curta (gliclazida, glipizida). Evitar glibenclamida em idosos. Reduzir doses ao adicionar insulina. Ter glicose oral ou IV disponible',
    'HIPOGLICEMIA GRAVE — Efeito aditivo; preferir sulfonilureia de ação curta; monitorar glucemia frecuentemente',
    EvidenceLevel.established,
    {RiskType.hypoglycemia},
    [_kRefGG, _kRefMdx, _kRefUT]),

    // ── SULFONILUREIA × outros ────────────────────────────────────────────────

  ('sulfonilureia', 'corticosteroide sistemico', InteractionSeverity.major,
    'Corticosteroides antagonizam completamente o efeito das sulfonilureias ao causar resistência à insulina e aumentar a gliconeogênese. A sulfonilureia torna-se ineficaz durante corticoterapia de médio a alta dose',
    'Hiperglucemia grave e refratária durante corticoterapia em diabéticos tipo 2. Hipoglucemia grave ao suspender corticoide (efeito rebote da sulfonilureia)',
    'Aumentar dose da sulfonilureia ou adicionar insulina durante corticoterapia. Monitorar glucemia 4x/dia. Reduzir sulfonilureia gradualmente ao suspender corticoide para evitar hipoglucemia de rebote',
    'HIPERGLICEMIA GRAVE — Corticoide antagoniza sulfonilureia; adicionar insulina e monitorar glucemia',
    EvidenceLevel.established,
    {RiskType.hypoglycemia},
    [_kRefGG, _kRefMdx]),


  ('sulfonilureia', 'fluconazol', InteractionSeverity.major,
    'Fluconazol inibe CYP2C9, a principal via de metabolismo de glibenclamida, glipizida e gliclazida. Pode aumentar os níveis em 2-3x',
    'Hipoglucemia grave y prolongada por acúmulo da sulfonilureia. Glibenclamida (meia-vida longa) tem risco especialmente elevado',
    'Evitar combinación com glibenclamida (alto risco). Se fluconazol necesario: reduzir dose da sulfonilureia em 50%, monitorar glucemia frecuentemente, ter glicose disponible. Preferir fluconazol de curto curso',
    'HIPOGLICEMIA GRAVE — Fluconazol aumenta sulfonilureia 2-3x; reduzir dose 50% e monitorar glucemia',
    EvidenceLevel.established,
    {RiskType.hypoglycemia, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('sulfonilureia', 'claritromicina', InteractionSeverity.major,
    'Claritromicina inibe CYP3A4 e pode inibir parcialmente CYP2C9, aumentando os níveis de glibenclamida e outras sulfonilureias',
    'Hipoglucemia grave por acúmulo da sulfonilureia durante o curso de antibioticoterapia',
    'Monitorar glucemia frecuentemente durante curso de claritromicina. Reduzir dose da sulfonilureia se necesario. Preferir azitromicina quando possível',
    'HIPOGLICEMIA — Claritromicina aumenta sulfonilureia; monitorar glucemia; preferir azitromicina',
    EvidenceLevel.established,
    {RiskType.hypoglycemia, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('sulfonilureia', 'isrs', InteractionSeverity.moderate,
    'ISRSs (fluoxetina especialmente) inibem CYP2C9, podendo aumentar os níveis de sulfonilureias CYP2C9-dependentes. Também têm efeito hipoglucemiante intrínseco',
    'Hipoglucemia por efeito aditivo e por inhibición do metabolismo da sulfonilureia',
    'Monitorar glucemia nas primeiras semanas ao iniciar ISRS. Pode ser necesario reduzir dose da sulfonilureia',
    'HIPOGLICEMIA — ISRSs inibem CYP2C9 e aumentam sensibilidade à insulina; monitorar glucemia',
    EvidenceLevel.probable,
    {RiskType.hypoglycemia},
    [_kRefGG, _kRefMdx]),

    // ── GLIBENCLAMIDA (sulfonilureia de longa ação) × outros ─────────────────

  ('glibenclamida', 'betabloqueador', InteractionSeverity.major,
    'Betabloqueadores (especialmente não-seletivos) mascaram sintomas adrenérgicos de hipoglucemia induzida por glibenclamida. Glibenclamida tem meia-vida de 24h e maior potência hipoglucemiante entre as sulfonilureias',
    'Hipoglucemia silenciosa grave, especialmente em idosos, IR e jejum. Risco elevado de internação por coma hipoglicêmico',
    'Evitar glibenclamida em idosos + betabloqueador. Preferir sulfonilureias de ação curta (gliclazida). Se mantida: preferir betabloqueadores seletivos (metoprolol, bisoprolol) e monitorar glucemia',
    'HIPOGLICEMIA SILENCIOSA GRAVE — Evitar glibenclamida em idosos; preferir betabloqueadores seletivos e gliclazida',
    EvidenceLevel.established,
    {RiskType.hypoglycemia},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('glibenclamida', 'corticosteroide sistemico', InteractionSeverity.major,
    'Corticosteroides antagonizam o efeito de glibenclamida por resistência à insulina. Ao suspender o corticoide, o efeito da glibenclamida (já sem antagonismo) causa hipoglucemia grave de rebote',
    'Hiperglucemia grave durante corticoterapia. Hipoglucemia grave de rebote ao suspender corticoide, especialmente com glibenclamida de ação prolongada',
    'Evitar glibenclamida durante corticoterapia; preferir insulina para controle. Ao suspender corticoide: reduzir hipoglucemiantes gradualmente. Monitorar glucemia 4x/dia',
    'HIPOGLICEMIA DE REBOTE — Ao suspender corticoide, risco alto de hipoglucemia grave com glibenclamida; preferir insulina',
    EvidenceLevel.established,
    {RiskType.hypoglycemia},
    [_kRefGG, _kRefMdx]),

    // ── CORTICOSTEROIDE SISTÊMICO × outros ────────────────────────────────────

  ('corticosteroide sistemico', 'aine', InteractionSeverity.major,
    'Corticosteroides inibem síntese de prostaglandinas (via lipocortina/PLA2) e prejudicam a integridade da mucosa gástrica. AINEs inibem COX-1, reduzindo prostaglandinas citoprotetoras. Efeito sinérgico na lesão da mucosa GI',
    'Úlcera péptica, hemorragia digestiva alta (risco 4-15x maior que com cada fármaco isolado), perfuração. Risco especialmente alto em idosos, história de úlcera e uso de anticoagulantes',
    'Evitar combinación quando possível. Se necessária: usar o AINE mais seletivo (COX-2 seletivo ou ibuprofeno em dose baixa) + IBP profilático (omeprazol 20mg/pantoprazol 40mg) obligatorio. Evitar uso prolongado',
    'HEMORRAGIA DIGESTIVA — Risco 4-15x maior; usar IBP profilático obligatorio se mantida a combinação',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('corticosteroide sistemico', 'warfarina', InteractionSeverity.major,
    'Corticosteroides em altas doses têm efeito anticoagulante intrínseco e podem aumentar os efeitos da varfarina por múltiplos mecanismos (indução de CYP com doses altas paradoxalmente inibindo CYP2C9 em doses baixas). Relação imprevisível',
    'Variação imprevisível do INR (aumento ou redução) com risco de sangrado ou trombosis. Em uso concomitante com AINEs: risco de sangrado gastrointestinal grave',
    'Monitorar INR frecuentemente ao iniciar, mudar dose ou suspender corticoide. Evitar combinación tripla com AINE + varfarina + corticoide (risco extremamente alto de hemorragia GI)',
    'INR IMPREVISÍVEL — Monitorar INR frecuentemente ao modificar corticoide; evitar tripla combinação com AINE',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx]),


  ('corticosteroide sistemico', 'isrs', InteractionSeverity.moderate,
    'Corticosteroides causam transtornos do humor (psicose, mania, depressão, ansiedade) que podem ser potencializados por ISRSs. Fluoxetina inibe CYP2C9 (metabolismo de alguns corticosteroides)',
    'Psicose por corticoide, mania, insônia grave. Possível elevação dos níveis de corticosteroides com fluoxetina',
    'Monitorar estado mental durante corticoterapia. Usar ISRSs se necesario para sintomas depressivos pós-corticoide (mas aguardar redução de dose do corticoide). Preferir sertralina ou escitalopram',
    'TRANSTORNOS DO HUMOR — Monitorar estado mental; ISRS pode ser necesario para depressão pós-corticoide',
    EvidenceLevel.probable,
    {RiskType.cns},
    [_kRefGG, _kRefMdx]),


  ('corticosteroide sistemico', 'ciclosporina', InteractionSeverity.major,
    'Corticosteroides inibem CYP3A4 em baixas doses e induzem em altas doses — efeito imprevisível sobre ciclosporina. Ciclosporina inibe o metabolismo de metilprednisolona, aumentando seus níveis',
    'Toxicidade de corticoide (Cushing iatrogênico, hiperglucemia, osteoporose) por aumento dos níveis. Possível falha imunossupressora se corticoide altera ciclosporina. Efeitos imunossupressores aditivos',
    'Monitorar níveis de ciclosporina e efeitos do corticoide. Combinação usada em transplante (padrão), mas com monitoramento rigoroso de función renal, glucemia, PA e peso',
    'TOXICIDADE ADITIVA — Combinação padrão em transplante; monitorar ciclosporina, glucemia, PA e peso',
    EvidenceLevel.established,
    {RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('corticosteroide sistemico', 'tacrolimo', InteractionSeverity.major,
    'Corticosteroides podem induzir CYP3A4 em altas doses, reduzindo tacrolimo; em retirada de corticoide, os níveis de tacrolimo podem elevar-se dramaticamente. Tacrolimo é diabetogênico + corticoide é diabetogênico',
    'Flutuações dos níveis de tacrolimo (rejeição ou toxicidad) ao modificar doses de corticoide. Hiperglucemia grave (NODAT — Novo-Onset Diabetes After Transplant)',
    'Monitorar C0 de tacrolimo ao modificar doses de corticoide. Rastrear NODAT com glucemia em jejum e HbA1c. Combinação padrão em transplante com monitoramento rigoroso',
    'FLUTUAÇÕES DE TACROLIMO + DIABETES — Monitorar C0 ao modificar corticoide; rastrear NODAT',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.hypoglycemia},
    [_kRefGG, _kRefMdx]),


  ('corticosteroide sistemico', 'vacinas vivas', InteractionSeverity.contraindicated,
    'Corticosteroides sistêmicos em doses imunossupressoras (≥ 20mg/dia de prednisona ou equivalente por ≥ 2 semanas) causam imunossupressão que impede resposta adecuada a vacinas vivas e pode levar à doença vacinal disseminada',
    'Doença vacinal disseminada (varicela, sarampo, febre amarela) com risco de morte. Falha de imunização por resposta imune inadecuada',
    'CONTRAINDICADO vacinas vivas durante corticoterapia imunossupressora. Aguardar ≥ 4 semanas após suspensão do corticoide antes de vacinas vivas. Vacinas inativadas podem ser administradas (resposta pode ser subótima)',
    'CONTRAINDICADO — Doença vacinal disseminada; aguardar 4 semanas após suspensão do corticoide',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('levotiroxina', 'omeprazol', InteractionSeverity.moderate,
    'IBPs reduzem a acidez gástrica, alterando a dissolução e absorção de levotiroxina (que requer pH ácido para absorção ótima)',
    'Hipotireoidismo por absorção reducida de levotiroxina, especialmente com uso prolongado de IBP',
    'Tomar levotiroxina em jejum, separada dos IBPs por pelo menos 30-60 minutos. Monitorar TSH periodicamente em pacientes em uso prolongado de IBP + levotiroxina',
    'HIPOTIREOIDISMO — Tomar levotiroxina separada do IBP por 30-60min; monitorar TSH periodicamente',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),


  ('levotiroxina', 'sulfato ferroso', InteractionSeverity.major,
    'Ferro forma complexos insolúveis com levotiroxina no intestino, reduzindo a absorção em 30-50%. Interação clinicamente relevante e frecuentemente negligenciada',
    'Hipotireoidismo por absorção reducida de levotiroxina, especialmente em gestantes com hipotireoidismo (que usam ferro + levotiroxina)',
    'Separar levotiroxina do sulfato ferroso por pelo menos 4 horas. Tomar levotiroxina em jejum; ferro com as refeições. Monitorar TSH após início de suplementação de ferro',
    'HIPOTIREOIDISMO — Separar levotiroxina do ferro por pelo menos 4 horas; monitorar TSH',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('levotiroxina', 'warfarina', InteractionSeverity.major,
    'Levotiroxina aumenta o catabolismo dos fatores de coagulação vitamina K-dependentes e potencializa o efeito anticoagulante da varfarina. O hipotireoidismo reduz o catabolismo, diminuindo o efeito da varfarina',
    'Aumento do INR (toxicidad) ao tratar hipotireoidismo com levotiroxina em pacientes já em uso de varfarina. Redução do INR (trombosis) em hipotireoidismo não tratado',
    'Monitorar INR frecuentemente (a cada 1-2 semanas) ao iniciar, ajustar dose ou suspender levotiroxina. Antecipar necessidade de redução de varfarina ao tratar hipotireoidismo',
    'SANGRAMENTO — Levotiroxina aumenta INR; monitorar INR frecuentemente ao ajustar dose de tireoide',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx]),


  ('levotiroxina', 'corticosteroide sistemico', InteractionSeverity.moderate,
    'Corticosteroides em altas doses podem suprimir o TSH e aumentar o metabolismo de T4 → T3 reverso (forma inativa). Em hipotireoidismo com adrenal insuficiente simultânea: corticoide deve ser repostos antes da levotiroxina',
    'Crise tirotóxica se levotiroxina iniciada antes de reposição de cortisol em insuficiencia adrenal concomitante. Em corticoterapia longa: hipotireoidismo subclínico por supressão de TSH',
    'Em suspeita de insuficiencia adrenal + hipotireoidismo: iniciar corticoide antes da levotiroxina. Monitorar TSH e T4 livre periodicamente em corticoterapia prolongada',
    'CRISE TIROTÓXICA EM IA — Iniciar corticoide antes da levotiroxina quando há insuficiencia adrenal concomitante',
    EvidenceLevel.established,
    {RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('semaglutida', 'warfarina', InteractionSeverity.moderate,
    'Semaglutida altera o esvaziamento gástrico, podendo alterar a absorção de varfarina. Melhora do controle glicêmico também pode alterar o metabolismo de varfarina indiretamente',
    'Alteração do INR (aumento ou redução) ao iniciar ou ajustar semaglutida',
    'Monitorar INR nas primeiras 4 semanas ao iniciar semaglutida. Ajustar dosis de warfarina según sea necesario',
    'INR ALTERADO — Monitorar INR nas primeiras semanas ao iniciar semaglutida',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx]),


  ('semaglutida', 'metformina', InteractionSeverity.minor,
    'Combinação de primeira linha em DM2. Semaglutida pode causar náusea/vômitos (especialmente nas primeiras 8 semanas), que podem ser exacerbados com metformina GI',
    'Náusea e intolerância GI aumentadas, podendo levar à descontinuação. Risco de hipoglucemia leve pela somatória do efeito hipoglucemiante de ambos',
    'Titular semaglutida lentamente (0,25mg/semana por 4 semanas, depois 0,5mg). Tomar metformina com refeições para minimizar GI. Monitorar tolerância GI',
    'INTOLERÂNCIA GI — Titular semaglutida lentamente; tomar metformina com refeições; combinação de 1ª linha',
    EvidenceLevel.established,
    {RiskType.hypoglycemia},
    [_kRefGG, _kRefMdx]),


  ('semaglutida', 'corticosteroide sistemico', InteractionSeverity.major,
    'Corticosteroides antagonizam o efeito hipoglucemiante da semaglutida por resistência à insulina e gliconeogênese aumentada. O efeito de esvaziamento gástrico lento da semaglutida não protege contra a hiperglucemia induzida por corticoide',
    'Hiperglucemia grave e refratária durante corticoterapia em pacientes com DM2 em uso de semaglutida',
    'Aumentar monitorização da glucemia durante corticoterapia. Semaglutida insuficiente em hiperglucemia grave por corticoide → adicionar insulina. Reduzir ajustes ao suspender corticoide',
    'HIPERGLICEMIA GRAVE — Corticoide antagoniza semaglutida; adicionar insulina durante corticoterapia',
    EvidenceLevel.probable,
    {RiskType.hypoglycemia},
    [_kRefGG, _kRefMdx]),

    // ── CICLOSPORINA × outros imunossupressores ───────────────────────────────

  ('ciclosporina', 'tacrolimo', InteractionSeverity.contraindicated,
    'Ambos são inibidores de calcineurina com mecanismos sobrepostos e nefrotoxicidad aditiva. A combinação não é clinicamente justificada e representa sobreposição de classe sem benefício adicional',
    'Nefrotoxicidad grave aditiva, hipertensão, hiperpotasemia, neurotoxicidad (tremor, cefaleia, convulsiones). Ausência de benefício imunossupressor adicional sobre monoterapia',
    'CONTRAINDICADO. Usar apenas um inibidor de calcineurina por vez. Transição entre os dois deve ser feita com período de washout e monitoramento de C0',
    'CONTRAINDICADO — Nefrotoxicidad aditiva sem benefício; usar apenas um inibidor de calcineurina',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('ciclosporina', 'azatioprina', InteractionSeverity.major,
    'Ciclosporina inibe TPMT (tiopurina metiltransferase), enzima responsável pela inativação da azatioprina. Pode aumentar os níveis do metabólito ativo (6-TGN) em 3-5x. Combinação usada em transplante mas com risco de mielotoxicidad',
    'Mielossupressão grave (leucopenia, trombocitopenia, anemia) por acúmulo de metabólitos ativos da azatioprina. Maior risco em pacientes com atividade de TPMT reducida',
    'Monitorar hemograma semanalmente nas primeiras 4-8 semanas e mensalmente depois. Reduzir dose de azatioprina em 50% quando combinada com ciclosporina. Genotipagem de TPMT recomendada antes de iniciar',
    'MIELOSSUPRESSÃO GRAVE — Ciclosporina inibe TPMT; reduzir azatioprina 50% e monitorar hemograma semanalmente',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('ciclosporina', 'estatina', InteractionSeverity.major,
    'Ciclosporina inibe OATP1B1/1B3 (transportadores de captação hepática) e CYP3A4, aumentando os níveis de todas as estatinas. Sinvastatina e lovastatina são mais afetadas. A bula da sinvastatina contraindica uso com ciclosporina',
    'Rabdomiólise grave por acúmulo de estatinas em pacientes transplantados. Incidência de miopatia 2-10x maior com ciclosporina',
    'CONTRAINDICADO: ciclosporina + sinvastatina ou lovastatina. Usar pravastatina (10-20mg max), fluvastatina ou rosuvastatina em dose reducida. Monitorar CK e síntomas musculares regularmente',
    'RABDOMIÓLISE — Ciclosporina aumenta estatinas; usar pravastatina ou fluvastatina em dose reducida; contraindica sinvastatina',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('ciclosporina', 'colchicina', InteractionSeverity.contraindicated,
    'Ciclosporina inibe P-gp e CYP3A4, as principais vias de eliminação da colchicina. Pode aumentar os níveis de colchicina em 2-4x. Colchicina já tem janela terapéutica estreita',
    'Toxicidade grave de colchicina: miopatia, neuropatia periférica, pancitopenia, disfunção hepática, IRA, colapso multissistêmico e morte. Casos fatais documentados em transplantados',
    'CONTRAINDICADO em IR (TFG < 60mL/min) + ciclosporina. Em IR normal: reduzir dose de colchicina em 50%, limitar a 1 curso curto (3-5 dias), monitorar CK, hemograma e función renal. Preferir corticoide ou AINE para crise de gota',
    'CONTRAINDICADO em IR — Toxicidade fatal; preferir corticoide para gota em transplantados com ciclosporina',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('ciclosporina', 'metformina', InteractionSeverity.moderate,
    'Ciclosporina é diabetogênica (causa NODAT) e pode competir com metformina por transportadores OCT2 renais, reduzindo a excreção de metformina. Nefrotoxicidad de ciclosporina pode precipitar acúmulo de metformina',
    'Hiperglucemia (NODAT) e acúmulo de metformina em disfunción renal por ciclosporina → risco de acidose lática',
    'Monitorar TFG, glucemia e lactato. Suspender metformina se TFG < 45mL/min ou em deterioração renal. Rastrear NODAT com glucemia em jejum',
    'NODAT + ACIDOSE LÁTICA — Monitorar TFG, glucemia e lactato; suspender metformina se TFG < 45',
    EvidenceLevel.probable,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx]),


  ('ciclosporina', 'vancomicina', InteractionSeverity.major,
    'Ambas são nefrotóxicas: ciclosporina causa vasoconstricção da arteríola aferente; vancomicina acumula nos túbulos. Efeito aditivo/sinérgico em transplantados que já têm TFG reducida',
    'IRA grave em transplantados, podendo simular ou precipitar rejeição aguda. Acúmulo de vancomicina por TFG reducida cria ciclo de toxicidad crescente',
    'Monitorar AUC de vancomicina diariamente. Monitorar C0 de ciclosporina. Manter euvolemia. Considerar alternativas (linezolida, daptomicina) para reduzir exposição à vancomicina',
    'IRA GRAVE EM TRANSPLANTADOS — AUC-guided vancomicina; monitorar C0 de ciclosporina; considerar alternativa antibiótica',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx]),

    // ── TACROLIMO × outros ────────────────────────────────────────────────────

  ('tacrolimo', 'azatioprina', InteractionSeverity.moderate,
    'Tacrolimo pode inibir parcialmente TPMT, aumentando metabólitos ativos de azatioprina (efeito menor que ciclosporina). Imunossupressão aditiva aumenta risco infeccioso',
    'Mielossupressão moderada, infecções oportunistas por imunossupressão excessiva',
    'Monitorar hemograma regularmente. Genotipagem de TPMT antes de iniciar. Reduzir azatioprina se leucopenia',
    'MIELOSSUPRESSÃO — Monitorar hemograma; genotipagem de TPMT antes de iniciar azatioprina',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),


  ('tacrolimo', 'estatina', InteractionSeverity.moderate,
    'Tacrolimo inibe modestamente OATP1B1 e CYP3A4, aumentando os níveis de estatinas (efeito menor que ciclosporina). Sinvastatina tem maior risco; pravastatina menor',
    'Riesgo aumentado de miopatía/rabdomiólisis em transplantados. Menor que com ciclosporina, mas clinicamente relevante',
    'Monitorar CK e síntomas musculares. Usar estatinas em doses mais baixas. Evitar sinvastatina em altas doses. Pravastatina e fluvastatina são preferíveis',
    'MIOPATIA — Monitorar CK; usar estatinas em doses baixas; preferir pravastatina',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('tacrolimo', 'vancomicina', InteractionSeverity.major,
    'Análogo à interação ciclosporina + vancomicina. Ambas são nefrotóxicas com efeito aditivo em transplantados',
    'IRA grave em transplantados com tacrolimo + vancomicina, especialmente se TFG já comprometida',
    'AUC-guided vancomicina. Monitorar C0 de tacrolimo. Considerar alternativas antibióticas. Manter euvolemia',
    'IRA GRAVE — AUC-guided vancomicina; monitorar C0 de tacrolimo; considerar linezolida ou daptomicina',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx]),


  ('tacrolimo', 'metformina', InteractionSeverity.moderate,
    'Tacrolimo é diabetogênico (NODAT). Em disfunción renal por tacrolimo, metformina pode acumular com risco de acidose lática',
    'NODAT (diabetes pós-transplante) e acidose lática por acúmulo de metformina em TFG reducida',
    'Rastrear NODAT com glucemia em jejum e HbA1c. Monitorar TFG. Suspender metformina se TFG < 45. Preferir insulina para NODAT em transplantados',
    'NODAT + ACIDOSE LÁTICA — Monitorar TFG; suspender metformina se TFG < 45; preferir insulina para NODAT',
    EvidenceLevel.probable,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx]),


  ('azatioprina', 'warfarina', InteractionSeverity.major,
    'Azatioprina pode reduzir o efeito anticoagulante da varfarina por mecanismo não totalmente elucidado (possível indução de enzimas de metabolismo)',
    'Redução do INR → risco de tromboembolismo em pacientes que necessitam de anticoagulação (ex.: válvula cardíaca, FA)',
    'Monitorar INR frecuentemente ao iniciar, ajustar ou suspender azatioprina. Aumentar dose de varfarina conforme necesario',
    'TROMBOSE — Azatioprina reduz INR; monitorar INR frecuentemente ao iniciar ou suspender',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx]),


  ('azatioprina', 'isrs', InteractionSeverity.minor,
    'Risco teórico de mielosupresión aditiva (efeitos hematológicos raros dos ISRSs + mielosupresión da azatioprina)',
    'Mielossupressão aumentada, trombocitopenia (ISRSs podem raramente causar trombocitopenia por mecanismo imunológico)',
    'Monitorar hemograma periodicamente. Combinação geralmente bem tolerada, mas monitorar se sinais de mielosupresión',
    'MONITORAR HEMOGRAMA — Risco teórico de mielosupresión aditiva com ISRSs',
    EvidenceLevel.possible,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),


  ('azatioprina', 'vacinas vivas', InteractionSeverity.contraindicated,
    'Azatioprina causa imunossupressão por redução de linfócitos T e B, impedindo resposta imune adecuada a vacinas vivas e podendo causar doença vacinal disseminada',
    'Doença vacinal disseminada (varicela, sarampo, febre amarela) potencialmente fatal. Falha de imunização',
    'CONTRAINDICADO. Atualizar vacinação com vacinas vivas antes de iniciar azatioprina. Aguardar ≥ 3 meses após suspensão. Vacinas inativadas podem ser usadas (resposta subótima esperada)',
    'CONTRAINDICADO — Doença vacinal disseminada; vacinar com vacinas vivas antes de iniciar azatioprina',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx, _kRefUT]),

    // ── BARICITINIBE / TOFACITINIBE (JAK inibidores) × outros ────────────────

  ('baricitinibe', 'tofacitinibe', InteractionSeverity.contraindicated,
    'Ambos são inibidores de JAK com mecanismos de imunossupressão sobrepostos. Combinação sem benefício clínico e com risco aumentado de infecções oportunistas graves, tromboembolismo e malignidades',
    'Imunossupressão excessiva → infecções oportunistas graves (TB, herpes zóster disseminado, pneumocistose, citomegalovirose), tromboembolismo venoso, malignidades',
    'CONTRAINDICADO. Usar apenas um inibidor de JAK por vez. Trocar de um para outro apenas após washout adecuado',
    'CONTRAINDICADO — Imunossupressão aditiva sem benefício; usar apenas um inibidor de JAK',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('baricitinibe', 'vacinas vivas', InteractionSeverity.contraindicated,
    'Baricitinibe causa imunossupressão por inhibición de JAK1/2, comprometendo a resposta imune a vacinas vivas e podendo causar doença vacinal disseminada',
    'Doença vacinal disseminada potencialmente fatal. Falha de imunização',
    'CONTRAINDICADO. Atualizar vacinação (incluindo herpes zóster) antes de iniciar baricitinibe. Vacinas inativadas preferidas',
    'CONTRAINDICADO — Vacinas vivas contraindicadas; atualizar vacinação antes de iniciar baricitinibe',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),


  ('tofacitinibe', 'vacinas vivas', InteractionSeverity.contraindicated,
    'Análogo ao baricitinibe + vacinas vivas. Tofacitinibe inibe JAK1/3, causando imunossupressão',
    'Doença vacinal disseminada potencialmente fatal',
    'CONTRAINDICADO. Atualizar vacinação antes de iniciar tofacitinibe. Herpes zóster (vacina inativada Shingrix) recomendada antes de iniciar',
    'CONTRAINDICADO — Vacinas vivas contraindicadas; atualizar vacinação antes de iniciar tofacitinibe',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),


  ('tofacitinibe', 'isrs', InteractionSeverity.minor,
    'Risco análogo ao baricitinibe + ISRS',
    'Neutropenia aumentada em pacientes susceptíveis',
    'Monitorar hemograma periodicamente',
    'MONITORAR HEMOGRAMA — Risco teórico de neutropenia aditiva com ISRSs',
    EvidenceLevel.possible,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),


  ('baricitinibe', 'warfarina', InteractionSeverity.moderate,
    'Baricitinibe pode alterar o INR por efeito inflamatório sistêmico (inflamação eleva os fatores de coagulação; ao reduzir inflamação, o IECA pode aumentar o INR). Efeito indireto por controle da artrite',
    'Alteração do INR ao iniciar ou ajustar baricitinibe, especialmente em pacientes com AR+FA em uso de varfarina',
    'Monitorar INR nas primeiras 4-8 semanas ao iniciar baricitinibe. Ajustar varfarina conforme necesario',
    'INR ALTERADO — Monitorar INR ao iniciar baricitinibe em pacientes usando varfarina',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx]),

    // ── TOCILIZUMABE × outros ─────────────────────────────────────────────────

  ('tocilizumabe', 'vacinas vivas', InteractionSeverity.contraindicated,
    'Tocilizumabe (anti-IL-6R) causa imunossupressão significativa, comprometendo a resposta a vacinas vivas e podendo causar doença vacinal disseminada',
    'Doença vacinal disseminada. Falha de imunização',
    'CONTRAINDICADO. Atualizar vacinação antes de iniciar tocilizumabe. Vacinas inativadas (influenza, pneumococo, herpes zóster inativada) recomendadas',
    'CONTRAINDICADO — Vacinas vivas contraindicadas; atualizar vacinação antes de iniciar tocilizumabe',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),

    // ── NATALIZUMABE × outros ─────────────────────────────────────────────────

  ('natalizumabe', 'tofacitinibe', InteractionSeverity.contraindicated,
    'Natalizumabe (anti-α4-integrina) causa imunossupressão por sequestro de linfócitos. Combinação com tofacitinibe (JAK inibidor) resulta em imunossupressão excessiva com alto risco de infecções oportunistas',
    'Leucoencefalopatia multifocal progressiva (LMP por vírus JC), pneumonia por pneumocystis, infecções oportunistas graves, reativação viral',
    'CONTRAINDICADO. Qualquer combinação de natalizumabe com imunossupressor potente é de alto risco. Washout obligatorio ao trocar',
    'CONTRAINDICADO — LMP e infecções oportunistas fatais; não combinar natalizumabe com imunossupressores potentes',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('natalizumabe', 'baricitinibe', InteractionSeverity.contraindicated,
    'Análogo ao natalizumabe + tofacitinibe. Imunossupressão excessiva com risco de LMP e infecções oportunistas graves',
    'LMP fatal, infecções oportunistas graves',
    'CONTRAINDICADO. Não combinar natalizumabe com inibidores de JAK',
    'CONTRAINDICADO — LMP e infecções oportunistas fatais; não combinar',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('natalizumabe', 'vacinas vivas', InteractionSeverity.contraindicated,
    'Natalizumabe causa imunossupressão profunda (sequestro de linfócitos no sangue, impedindo migração tecidual). Vacinas vivas são contraindicadas',
    'Doença vacinal disseminada. Risco de LMP aumentado por qualquer estímulo imune',
    'CONTRAINDICADO. Atualizar vacinação antes de iniciar natalizumabe. Após suspensão, aguardar ≥ 6 meses (restauração imune demora)',
    'CONTRAINDICADO — Doença vacinal disseminada; atualizar antes de iniciar; aguardar 6 meses após suspensão',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx, _kRefUT]),

    // ── VEDOLIZUMABE × outros ─────────────────────────────────────────────────

  ('vedolizumabe', 'tofacitinibe', InteractionSeverity.major,
    'Vedolizumabe (anti-α4β7 gut-selective) + tofacitinibe (JAK inibidor sistêmico): imunossupressão aditiva, especialmente na mucosa intestinal. Risco de infecções oportunistas gastrointestinais e sistêmicas',
    'Infecções oportunistas gastrointestinais (CMV colitis, histoplasmose intestinal), infecções sistêmicas. Tromboembolismo venoso (tofacitinibe)',
    'Evitar combinación. Se necesario em DII refratária: supervisão especializada, monitoramento intensivo de infecções. Atualizar vacinações',
    'INFECÇÕES OPORTUNISTAS — Evitar combinación; supervisão especializada em DII refratária',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),


  ('vedolizumabe', 'baricitinibe', InteractionSeverity.major,
    'Análogo ao vedolizumabe + tofacitinibe. Imunossupressão aditiva em mucosa intestinal e sistemicamente',
    'Infecções oportunistas intestinais e sistêmicas',
    'Evitar combinación. Se necesario: supervisão especializada, monitoramento de infecções',
    'INFECÇÕES OPORTUNISTAS — Evitar combinación de vedolizumabe com inibidores de JAK',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),


  ('vedolizumabe', 'vacinas vivas', InteractionSeverity.major,
    'Vedolizumabe causa imunossupressão seletiva da mucosa intestinal mas também sistêmica em grau menor. Vacinas vivas orais (poliomielite oral, febre tifóide oral) são especialmente problemáticas',
    'Vacinas vivas orais podem causar infecção disseminada por replicação aumentada do agente vacinal na mucosa intestinal desprotegida/imunocomprometida',
    'Evitar vacinas vivas, especialmente orais. Preferir vacinas inativadas. Consultar guia de vacinação em imunossuprimidos',
    'EVITAR VACINAS VIVAS — Especialmente as orais; usar apenas vacinas inativadas',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),


  ('ruxolitinibe', 'rifampicina', InteractionSeverity.major,
    'Rifampicina induz CYP3A4, reduzindo os níveis de ruxolitinibe em 70%',
    'Falha terapéutica (mielofibrose, policitemia vera) por níveis subterapéuticos',
    'Evitar combinación. Se necesario: aumentar dose de ruxolitinibe com monitoramento hematológico',
    'FALHA TERAPÊUTICA — Rifampicina reduz ruxolitinibe 70%; aumentar dose com monitoramento',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),

    // ── MEPOLIZUMABE × outros ─────────────────────────────────────────────────

  ('mepolizumabe', 'vacinas vivas', InteractionSeverity.moderate,
    'Mepolizumabe (anti-IL-5) afeta eosinófilos mas tem menor impacto em linfócitos T e B do que outros biológicos. Vacinas vivas têm risco teórico por imunossupressão eosinofílica',
    'Falha de imunização (resposta reducida), risco teórico de doença vacinal (menor que com biológicos anti-TNF ou anti-IL-6)',
    'Preferir vacinas inativadas. Consultar especialista antes de vacinas vivas. Risco menor que outros biológicos mas não desprezível',
    'MONITORAR — Preferir vacinas inativadas; consultar especialista antes de vacinas vivas',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),


  ('ciprofloxacino', 'ciclosporina', InteractionSeverity.major,
    'Ciprofloxacino inibe CYP3A4, aumentando os níveis de ciclosporina. Ambos são nefrotóxicos. Riesgo de toxicidad cumulativa',
    'Nefrotoxicidad grave por acúmulo de ciclosporina + efeito nefrotóxico direto do ciprofloxacino (raro mas descrito)',
    'Monitorar C0 de ciclosporina a cada 2-3 dias durante ciprofloxacino. Reduzir dose de ciclosporina se C0 elevado. Considerar alternativa antibiótica',
    'NEFROTOXICIDADE + AUMENTO DE CICLOSPORINA — Monitorar C0 de ciclosporina; considerar alternativa',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('ciprofloxacino', 'isrs', InteractionSeverity.moderate,
    'Ciprofloxacino inibe CYP1A2 (metabolismo de fluvoxamina) e prolonga QTc. Citalopram e escitalopram também prolongam QTc',
    'QTc prolongado aditivo com citalopram/escitalopram. Toxicidade de fluvoxamina por inhibición de CYP1A2',
    'Evitar ciprofloxacino + citalopram/escitalopram. Monitorar ECG. Preferir outro antibiótico em pacientes com ISRS que prolongam QT',
    'QT PROLONGADO — Evitar ciprofloxacino + citalopram/escitalopram; monitorar ECG',
    EvidenceLevel.probable,
    {RiskType.qtProlongation},
    [_kRefGG, _kRefMdx]),


  ('ciprofloxacino', 'antiácido', InteractionSeverity.major,
    'Cátions divalentes e trivalentes (Mg²⁺, Al³⁺, Ca²⁺, Fe²⁺/³⁺, Zn²⁺) formam complexos insolúveis de quelação com ciprofloxacino no TGI, reduzindo a absorção em 30-75%',
    'Falha terapéutica por níveis subterapéuticos de ciprofloxacino, especialmente em infecções graves',
    'Separar ciprofloxacino de antiácidos, suplementos de ferro, cálcio e zinco por pelo menos 2 horas (ciprofloxacino primeiro) ou 6 horas depois. Nunca coadministrar',
    'FALHA TERAPÊUTICA — Separar ciprofloxacino de antiácidos/Fe/Ca por 2h antes ou 6h depois; nunca juntos',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('ciprofloxacino', 'estatina', InteractionSeverity.moderate,
    'Ciprofloxacino inibe CYP1A2, podendo aumentar os níveis de atorvastatina (metabolizada por CYP3A4/1A2) e rosuvastatina',
    'Risco discretamente aumentado de miopatia/rabdomiólisis, especialmente com doses altas de estatina',
    'Monitorar síntomas musculares. Interação geralmente clinicamente modesta em cursos curtos de ciprofloxacino. Mais relevante em uso prolongado',
    'MIOPATIA AUMENTADA — Monitorar síntomas musculares em uso prolongado de ciprofloxacino com estatinas',
    EvidenceLevel.probable,
    {RiskType.myopathy},
    [_kRefGG, _kRefMdx]),


  ('metronidazol', 'isrs', InteractionSeverity.moderate,
    'Metronidazol inibe CYP2C19 (metabolismo de citalopram, escitalopram, sertralina). Pode aumentar os níveis de ISRSs e potencializar atividade serotoninérgica',
    'Síndrome serotoninérgica leve-moderada, especialmente com citalopram/escitalopram. Prolongamento QTc com citalopram',
    'Monitorar sinais serotoninérgicos e ECG com citalopram/escitalopram. Preferir tinidazol em pacientes com ISRS quando possível',
    'SÍNDROME SEROTONINÉRGICA + QT — Monitorar sinais serotoninérgicos e ECG com citalopram/escitalopram',
    EvidenceLevel.probable,
    {RiskType.serotonin, RiskType.qtProlongation},
    [_kRefGG, _kRefMdx]),


  ('metronidazol', 'ciclosporina', InteractionSeverity.moderate,
    'Metronidazol inibe CYP3A4 e CYP2C9, podendo aumentar os níveis de ciclosporina',
    'Nefrotoxicidad e hepatotoxicidad por acúmulo de ciclosporina',
    'Monitorar C0 de ciclosporina e función renal durante curso de metronidazol. Reduzir dose de ciclosporina se C0 elevado',
    'NEFROTOXICIDADE — Monitorar C0 de ciclosporina durante metronidazol',
    EvidenceLevel.probable,
    {RiskType.nephrotoxicity, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('metronidazol', 'tacrolimo', InteractionSeverity.moderate,
    'Metronidazol inibe CYP3A4, podendo aumentar os níveis de tacrolimo em pacientes transplantados',
    'Nefrotoxicidad e neurotoxicidad por acúmulo de tacrolimo',
    'Monitorar C0 de tacrolimo diariamente durante curso de metronidazol. Reduzir dose se C0 elevado',
    'NEFROTOXICIDADE — Monitorar C0 de tacrolimo diariamente durante metronidazol',
    EvidenceLevel.probable,
    {RiskType.nephrotoxicity, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('trimetoprima', 'losartana', InteractionSeverity.major,
    'Análogo ao trimetoprima + enalapril. BRA retém K + trimetoprima retém K por bloqueio de ENaC → hiperpotasemia grave',
    'Hipercalemia grave com risco de arritmias fatais',
    'Monitorar K 3-5 dias após início de SMX-TMP em pacientes com BRA. Evitar em IR + BRA + diurético poupador de K',
    'HIPERCALEMIA GRAVE — Monitorar K 3-5 dias após início de SMX-TMP em uso de BRA',
    EvidenceLevel.established,
    {RiskType.hyperkalemia, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),


  ('sulfametoxazol', 'fenitoína', InteractionSeverity.major,
    'SMX inibe CYP2C9 (principal via da fenitoína). Trimetoprima pode também inibir CYP2C9 em menor grau',
    'Toxicidade de fenitoína: nistagmo, ataxia, diplopia, confusão por acúmulo',
    'Monitorar nivel sérico de fenitoína ao iniciar SMX-TMP. Reduzir dose de fenitoína preventivamente. Preferir outro antibiótico quando possível',
    'TOXICIDADE DE FENITOÍNA — SMX-TMP inibe CYP2C9; monitorar nivel sérico de fenitoína',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.cns},
    [_kRefGG, _kRefMdx]),


  ('sulfametoxazol', 'ciclosporina', InteractionSeverity.major,
    'SMX-TMP inibe CYP3A4 e CYP2C9, aumentando os níveis de ciclosporina. Adicionalmente, ambos são nefrotóxicos',
    'Nefrotoxicidad grave por acúmulo de ciclosporina + efeito nefrotóxico do SMX-TMP (cristalúria, nefrite intersticial)',
    'Monitorar C0 de ciclosporina e creatinina diariamente durante SMX-TMP. Manter boa hidratação (previne cristalúria do SMX)',
    'NEFROTOXICIDADE GRAVE — Monitorar C0 de ciclosporina diariamente; manter hidratação adecuada',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('piperacilina-tazobactam', 'aminoglicosideo', InteractionSeverity.moderate,
    'Piperacilinas em altas doses podem inativar aminoglicosídeos in vitro por inativação química. Interação depende de concentração e tempo de contato. Significado clínico variável',
    'Possível redução da eficácia do aminoglicosídeo por inativação. Risco aumentado de nefrotoxicidad por aminoglicosídeo',
    'Não misturar no mesmo frasco/linha. Administrar em horários separados. Dosar nivel sérico do aminoglicosídeo. Monitorar función renal',
    'NÃO MISTURAR — Administrar em linhas separadas; dosar nivel sérico do aminoglicosídeo',
    EvidenceLevel.probable,
    {RiskType.nephrotoxicity, RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),


  ('piperacilina-tazobactam', 'warfarina', InteractionSeverity.moderate,
    'Piperacilina (como outras penicilinas em doses altas) tem efeito anticoagulante por inhibición da agregação plaquetária (platelet-inhibiting effect). Pode aumentar modestamente o INR por supressão da flora intestinal',
    'Aumento modesto do INR + risco de sangrado por efeito antiplaquetário direto da piperacilina em doses altas',
    'Monitorar INR durante pip/tazo em pacientes com varfarina. Risco de sangrado maior em uremia (que também afeta plaquetas)',
    'INR AUMENTADO — Monitorar INR durante pip/tazo em pacientes com varfarina',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx]),


  ('linezolida', 'tramadol', InteractionSeverity.contraindicated,
    'Linezolida inibe MAO; tramadol inibe recaptação de serotonina/noradrenalina. Combinação potencialmente fatal por síndrome serotoninérgica + efeito adrenérgico',
    'Síndrome serotoninérgica grave, crise adrenérgica, convulsiones',
    'CONTRAINDICADO. Substituir tramadol por morfina ou fentanila (menor atividade serotoninérgica) durante linezolida',
    'CONTRAINDICADO — Síndrome serotoninérgica grave; substituir tramadol por morfina durante linezolida',
    EvidenceLevel.established,
    {RiskType.serotonin},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('linezolida', 'imao', InteractionSeverity.contraindicated,
    'Dupla inibição de MAO: linezolida inibe MAO não seletivamente + IMAO irreversível ou reversível. Combinação sem indicação clínica e com risco de síndrome serotoninérgica/adrenérgica grave',
    'Crise adrenérgica, síndrome serotoninérgica, colapso cardiovascular',
    'CONTRAINDICADO absolutamente. Washout de 14 dias do IMAO antes de linezolida y viceversa',
    'CONTRAINDICADO — Dupla inibição de MAO; washout de 14 dias',
    EvidenceLevel.established,
    {RiskType.serotonin},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('linezolida', 'amitriptilina', InteractionSeverity.contraindicated,
    'Linezolida inibe MAO; amitriptilina inibe recaptação de serotonina e noradrenalina. Risco de síndrome serotoninérgica análoga ao IMAO + tricíclico',
    'Síndrome serotoninérgica, crise adrenérgica, arritmias graves',
    'CONTRAINDICADO. Suspender amitriptilina antes de linezolida. Considerar alternativa antibiótica (daptomicina)',
    'CONTRAINDICADO — Síndrome serotoninérgica; suspender amitriptilina antes de linezolida',
    EvidenceLevel.established,
    {RiskType.serotonin},
    [_kRefGG, _kRefMdx]),


  ('linezolida', 'mirtazapina', InteractionSeverity.contraindicated,
    'Linezolida inibe MAO; mirtazapina aumenta neurotransmissão serotoninérgica/noradrenérgica. Risco de síndrome serotoninérgica',
    'Síndrome serotoninérgica',
    'CONTRAINDICADO. Suspender mirtazapina antes de linezolida. Considerar alternativa antibiótica',
    'CONTRAINDICADO — Síndrome serotoninérgica; suspender mirtazapina antes de linezolida',
    EvidenceLevel.established,
    {RiskType.serotonin},
    [_kRefGG, _kRefMdx]),


  ('linezolida', 'bupropiona', InteractionSeverity.contraindicated,
    'Linezolida inibe MAO; bupropiona inibe recaptação de dopamina e noradrenalina. Risco de crise adrenérgica e convulsiones',
    'Crise hipertensiva, convulsiones, síndrome adrenérgica',
    'CONTRAINDICADO. Suspender bupropiona antes de linezolida. Considerar alternativa antibiótica',
    'CONTRAINDICADO — Crise hipertensiva e convulsiones; suspender bupropiona antes de linezolida',
    EvidenceLevel.established,
    {RiskType.serotonin},
    [_kRefGG, _kRefMdx]),


  ('linezolida', 'warfarina', InteractionSeverity.moderate,
    'Linezolida pode ter leve efeito sobre a coagulação, especialmente em tratamentos prolongados. Inibição de MAO não diretamente relacionada, mas interação farmacológica com varfarina possível',
    'Leve aumento do INR em cursos prolongados de linezolida',
    'Monitorar INR em tratamentos prolongados de linezolida. Risco geralmente baixo em cursos curtos',
    'MONITORAR INR — Risco baixo; monitorar em tratamentos prolongados de linezolida',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx]),

    // ── AZITROMICINA × outros ─────────────────────────────────────────────────

  ('azitromicina', 'warfarina', InteractionSeverity.moderate,
    'Azitromicina tem menor interação com CYP que eritromicina/claritromicina, mas pode aumentar modestamente o INR por supressão da flora intestinal produtora de vitamina K',
    'Aumento modesto do INR com risco de sangrado leve a moderado',
    'Monitorar INR ao iniciar e suspender azitromicina. Risco geralmente baixo vs eritromicina/claritromicina. Mas monitoramento ainda recomendado',
    'INR AUMENTADO — Monitorar INR com azitromicina; menor risco que eritromicina, mas relevante',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx]),


  ('azitromicina', 'haloperidol', InteractionSeverity.moderate,
    'Azitromicina prolonga QTc + haloperidol prolonga QTc por bloqueio de IKr. Risco aditivo',
    'QTc prolongado com risco de torsades de pointes',
    'Monitorar ECG. Evitar em pacientes com QTc basal > 450ms. Corrigir hipopotasemia',
    'QT PROLONGADO — Monitorar ECG com azitromicina + haloperidol; corrigir electrolitos',
    EvidenceLevel.probable,
    {RiskType.qtProlongation},
    [_kRefGG, _kRefMdx]),


  ('azitromicina', 'metadona', InteractionSeverity.major,
    'Azitromicina prolonga QTc + metadona prolonga QTc dose-dependentemente. Risco aditivo significativo em doses altas de metadona',
    'QTc prolongado com risco de torsades de pointes, especialmente em doses elevadas de metadona ou hipopotasemia',
    'Monitorar ECG antes e durante azitromicina em pacientes com metadona em dose > 100mg/dia. Corrigir electrolitos. Considerar alternativa antibiótica (betalactâmico)',
    'QT PROLONGADO — Monitorar ECG com azitromicina + metadona em doses altas; corrigir electrolitos',
    EvidenceLevel.established,
    {RiskType.qtProlongation},
    [_kRefGG, _kRefMdx]),

    // ── TIGECICLINA × outros ─────────────────────────────────────────────────

  ('tigeciclina', 'anticoncepcional', InteractionSeverity.moderate,
    'Tigeciclina, como outras tetraciclinas, suprime a flora intestinal que hidrolisa conjugados de estrogênio, podendo reduzir a circulação êntero-hepática de etinilestradiol',
    'Possível redução da eficácia contraceptiva hormonal em uso curto',
    'Usar método de barreira adicional durante o curso de tigeciclina e por 7 dias após. Embora o risco seja controverso para tetraciclinas modernas, a prudência recomenda o método de barreira',
    'FALHA CONTRACEPTIVA — Usar método de barreira adicional durante tigeciclina',
    EvidenceLevel.possible,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),

    // ── ESTATINAS × outros ────────────────────────────────────────────────────

  ('estatina', 'amiodarona', InteractionSeverity.major,
    'Amiodarona inibe CYP3A4 e CYP2C8 — vias de metabolismo de sinvastatina, atorvastatina e lovastatina. Pode aumentar os níveis de estatinas em 2-3x. Risco mais elevado com sinvastatina em doses > 20mg',
    'Miopatia grave e rabdomiólisis. FDA limitou sinvastatina a 20mg/dia com amiodarona',
    'Limitar sinvastatina a 20mg/dia com amiodarona (FDA). Evitar lovastatina. Preferir rosuvastatina ou pravastatina. Monitorar CK e síntomas musculares',
    'RABDOMIÓLISE — Limitar sinvastatina a 20mg com amiodarona (FDA); preferir pravastatina ou rosuvastatina',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('estatina', 'verapamil', InteractionSeverity.major,
    'Verapamil inibe CYP3A4 e P-gp, aumentando os níveis de sinvastatina, lovastatina e atorvastatina. FDA limita sinvastatina a 10mg/dia com verapamil',
    'Miopatia e rabdomiólisis por acúmulo de estatinas',
    'Limitar sinvastatina a 10mg/dia com verapamil (FDA). Evitar lovastatina. Preferir pravastatina, rosuvastatina ou fluvastatina. Monitorar CK',
    'RABDOMIÓLISE — Limitar sinvastatina a 10mg com verapamil (FDA); preferir pravastatina',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('estatina', 'diltiazem', InteractionSeverity.moderate,
    'Diltiazem inibe moderadamente CYP3A4, aumentando os níveis de sinvastatina em 2-4x e atorvastatina em menor grau',
    'Miopatia/rabdomiólisis por acúmulo de sinvastatina. FDA limita sinvastatina a 10mg/dia com diltiazem',
    'Limitar sinvastatina a 10mg/dia com diltiazem. Preferir pravastatina ou rosuvastatina. Monitorar CK',
    'RABDOMIÓLISE — Limitar sinvastatina a 10mg com diltiazem; preferir pravastatina',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('estatina', 'azitromicina', InteractionSeverity.minor,
    'Azitromicina tem mínima inibição de CYP3A4. Riesgo de miopatía muito baixo em cursos curtos (5 dias). Relevante principalmente com sinvastatina em doses altas',
    'Risco muito baixo de miopatia em tratamentos curtos. Monitoramento geralmente desnecesario',
    'Geralmente seguro em cursos curtos. Monitorar síntomas musculares se sinvastatina em dose alta (> 40mg). Sem ajuste de dose necesario',
    'RISCO MÍNIMO — Geralmente seguro; monitorar síntomas musculares se sinvastatina > 40mg',
    EvidenceLevel.possible,
    {RiskType.myopathy},
    [_kRefGG, _kRefMdx]),


  ('estatina', 'colchicina', InteractionSeverity.major,
    'Colchicina causa miopatia por inhibición de microtúbulos nas fibras musculares (efeito direto). Estatinas causam miopatia por depleção de ubiquinona. Efeito aditivo/sinérgico',
    'Miopatia grave e rabdomiólisis, especialmente em IR (que também eleva os níveis de colchicina), idosos e em pacientes com doses altas de estatina',
    'Monitorar CK e síntomas musculares durante uso concomitante. Limitar dose de colchicina ao mínimo efetivo. Preferir estatinas com menor risco (pravastatina, rosuvastatina). Suspender se CK > 5x LSN',
    'RABDOMIÓLISE — Efeito miopático aditivo; preferir pravastatina; monitorar CK; limitar colchicina ao mínimo',
    EvidenceLevel.established,
    {RiskType.myopathy},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('estatina', 'fenofibrato', InteractionSeverity.moderate,
    'Fenofibrato inibe CYP2C8 e OATP1B1, podendo aumentar os níveis de estatinas (especialmente cerivastina — retirada do mercado por este motivo). Efeito miopático aditivo independente do mecanismo CYP',
    'Miopatia e rabdomiólisis pelo efeito miopático aditivo de fibratos + estatinas. Menor risco que gemfibrozil',
    'Monitorar CK e síntomas musculares. Fenofibrato tem menor risco que gemfibrozil com estatinas. Prefira fenofibrato a gemfibrozil quando a combinação for necessária',
    'MIOPATIA ADITIVA — Fenofibrato mais seguro que gemfibrozil; monitorar CK e síntomas musculares',
    EvidenceLevel.established,
    {RiskType.myopathy},
    [_kRefGG, _kRefMdx]),


  ('estatina', 'warfarina', InteractionSeverity.moderate,
    'Estatinas inibem variadamente CYP2C9 (principal via da S-varfarina): fluvastatina e rosuvastatina têm maior inibição de CYP2C9; pravastatina e atorvastatina têm menor impacto',
    'Aumento modesto do INR ao iniciar ou aumentar dose de estatina, especialmente fluvastatina e rosuvastatina',
    'Monitorar INR ao iniciar ou mudar dose de estatina. Risco maior com fluvastatina e rosuvastatina. Ajustar varfarina conforme necesario',
    'INR AUMENTADO — Monitorar INR ao iniciar estatina; maior risco com fluvastatina e rosuvastatina',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx]),


  ('aine', 'isrs', InteractionSeverity.major,
    'ISRSs inibem recaptação de serotonina nas plaquetas, reduzindo a agregação plaquetária. AINEs inibem COX-1 (antiagregação + lesão GI). Efeito antiagregante e lesivo GI aditivo/sinérgico',
    'Hemorragia GI significativa (risco 3-15x maior). Metanálises mostram que a combinação AINE + ISRS aumenta risco de HDA em 15x em relação a nenhum dos dois',
    'Evitar uso concomitante prolongado. Se necesario: adicionar IBP profilático (omeprazol 20mg ou pantoprazol 40mg). Monitorar sinais de sangrado (fezes escuras, anemia)',
    'HEMORRAGIA GI GRAVE — Risco 3-15x de HDA; adicionar IBP profilático obligatoriamente se mantida a combinação',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('omeprazol', 'metformina', InteractionSeverity.minor,
    'Omeprazol inibe OCT1/OCT2 (transportadores de captação hepática e renal de metformina), podendo aumentar discretamente os niveles plasmáticos de metformina',
    'Aumento discreto dos níveis de metformina. Risco mínimo de acidose lática em doses usuais e función renal normal',
    'Sem ajuste de dose necesario em función renal normal. Monitorar se TFG reducida. Combinação geralmente segura',
    'RISCO MÍNIMO — Sem ajuste necesario; monitorar se TFG reducida',
    EvidenceLevel.possible,
    {RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('pantoprazol', 'metformina', InteractionSeverity.minor,
    'Pantoprazol tem mínima inibição de OCT1/OCT2 comparado ao omeprazol. Risco de interação com metformina ainda menor',
    'Risco muito baixo de aumento dos níveis de metformina',
    'Sem ajuste necesario. Pantoprazol é o IBP preferido em pacientes com clopidogrel e/ou metformina',
    'RISCO MÍNIMO — Pantoprazol é o IBP mais seguro com clopidogrel e metformina',
    EvidenceLevel.possible,
    {RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('valproato', 'quetiapina', InteractionSeverity.moderate,
    'Combinação amplamente usada em transtorno bipolar. Valproato pode inibir CYP3A4 modestamente, aumentando os níveis de quetiapina. Sedação aditiva',
    'Sedação excessiva, especialmente ao início do tratamento. QTc prolongado com quetiapina',
    'Monitorar sedação e ECG. Combinação considerada segura em adultos com bipolaridade. Titular lentamente',
    'SEDAÇÃO AUMENTADA — Combinação usada em TB; monitorar sedação e ECG; titular lentamente',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.qtProlongation},
    [_kRefGG, _kRefMdx]),


  ('valproato', 'amitriptilina', InteractionSeverity.moderate,
    'Valproato inibe CYP2C9 e CYP2C19, podendo aumentar os níveis de amitriptilina. Ambos têm efeitos sedativos e anticolinérgicos',
    'Toxicidade de amitriptilina: QTc prolongado, efeitos anticolinérgicos aditivos, sedação excessiva',
    'Monitorar ECG e nivel sérico de amitriptilina. Evitar em idosos (critérios de Beers). Usar doses baixas de ambos',
    'QT PROLONGADO + TOXICIDADE ANTICOLINÉRGICA — Monitorar ECG; evitar em idosos',
    EvidenceLevel.probable,
    {RiskType.qtProlongation, RiskType.cns},
    [_kRefGG, _kRefMdx]),


  ('gabapentina', 'tramadol', InteractionSeverity.major,
    'Gabapentina potencializa a depressão do SNC do tramadol. Tramadol abaixa o limiar convulsivo; gabapentina não. Risco predominante: sedação e depresión respiratoria',
    'Sedación excesiva, depresión respiratoria. Síndrome serotoninérgica improvável mas risco de sedação é real',
    'Usar doses mínimas de ambos. Monitorar SpO₂. Prescrever naloxona para tramadol',
    'DEPRESSÃO RESPIRATÓRIA — Usar doses mínimas; monitorar SpO₂; ter naloxona disponible',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns},
    [_kRefGG, _kRefMdx]),


  ('topiramato', 'carbonato de litio', InteractionSeverity.moderate,
    'Topiramato inibe anidrase carbônica, podendo alterar o pH urinário e a excreção renal de lítio. Risco de acúmulo de lítio ou alteração de seus níveis',
    'Toxicidade de lítio por acúmulo ou alteração imprevisível dos níveis séricos',
    'Monitorar nivel sérico de lítio ao iniciar ou ajustar topiramato. Manter hidratação e ingestão de sódio estáveis',
    'NÍVEL DE LÍTIO ALTERADO — Monitorar nivel sérico de lítio ao iniciar topiramato',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('lamotrigina', 'quetiapina', InteractionSeverity.moderate,
    'Quetiapina pode reduzir os níveis de lamotrigina em 50% por mecanismo não completamente elucidado. Combinação usada em bipolaridade mas requer monitoramento',
    'Possível falha no controle de crises epilépticas ou humor por redução dos níveis de lamotrigina',
    'Monitorar nivel sérico de lamotrigina e resposta clínica. Aumentar dose de lamotrigina se necesario. Combinação usada em TB tipo I',
    'EFICÁCIA REDUZIDA — Quetiapina pode reduzir lamotrigina 50%; monitorar nivel sérico e resposta clínica',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),

    // ── MISC — pares importantes ainda ausentes ───────────────────────────────

  ('paracetamol', 'warfarina', InteractionSeverity.moderate,
    'Paracetamol em doses regulares (≥ 2g/dia por ≥ 3 dias) pode aumentar o INR em pacientes usando varfarina. Mecanismo discutido: possível inibição da vitamina K epóxido redutase por metabólitos do paracetamol',
    'Aumento modesto do INR (geralmente 1,5-2x) com doses habituais. Raramente sangrado grave. Ainda assim, clinicamente relevante em pacientes idosos ou com INR já elevado',
    'Monitorar INR se uso regular de paracetamol (> 2g/dia por > 3 dias) com varfarina. Não é necesario evitar paracetamol (é o analgésico de escolha com varfarina), mas monitorar. Evitar doses > 2g/dia se INR lábil',
    'INR AUMENTADO — Monitorar INR se uso regular de paracetamol > 2g/dia; ainda é o analgésico de escolha',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx]),


  ('teofilina', 'amiodarona', InteractionSeverity.major,
    'Amiodarona e seu metabólito (desetilamiodarona) inibem CYP1A2, a principal via de metabolismo da teofilina. Pode aumentar os níveis em 40-100%',
    'Toxicidade de teofilina: taquicardia, arritmias, náusea, vômitos, convulsiones. Especialmente perigoso dado o estreito índice terapéutico da teofilina',
    'Monitorar nivel sérico de teofilina frecuentemente ao iniciar amiodarona. Reduzir dose de teofilina em 30-50% preventivamente. Considerar substituir teofilina por outro broncodilatador',
    'TOXICIDADE DE TEOFILINA — Amiodarona inibe CYP1A2; reduzir dose 30-50% e monitorar nivel sérico',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),


  ('teofilina', 'isrs', InteractionSeverity.moderate,
    'Fluvoxamina inibe potentemente CYP1A2 (principal via de metabolismo da teofilina). Pode aumentar os níveis em 3-10x',
    'Toxicidade grave de teofilina: taquicardia, arritmias ventriculares, convulsiones, náusea',
    'CONTRAINDICADO: fluvoxamina + teofilina. Substituir fluvoxamina por sertralina ou escitalopram (menor inibição de CYP1A2). Se mantida: monitorar nivel sérico e reduzir dose de teofilina em 50-80%',
    'TOXICIDADE DE TEOFILINA — Fluvoxamina inibe CYP1A2 potentemente; substituir ou reduzir teofilina 50-80%',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),


  ('teofilina', 'benzodiazepínico', InteractionSeverity.moderate,
    'Teofilina antagoniza os efeitos sedativos e anticonvulsivantes dos benzodiazepínicos por antagonismo de adenosina. Reduz a eficácia dos benzodiazepínicos no controle da ansiedade e do status epilepticus',
    'Reducción de la eficacia sedativa e anticonvulsivante dos benzodiazepínicos. Status epilepticus resistente a benzodiazepínicos em pacientes com toxicidad de teofilina',
    'Em intoxicação por teofilina com convulsiones: usar fenitoína ou fenobarbital (mais efetivos que benzodiazepínicos). Aumentar dose de benzodiazepínico se usado para sedação procedural',
    'EFICÁCIA REDUZIDA DE BZD — Teofilina antagoniza benzodiazepínicos; na intoxicação por teofilina: preferir fenitoína',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),


  ('ondansetrona', 'isrs', InteractionSeverity.major,
    'Ondansetrona bloqueia receptores 5-HT3 (serotonina). Citalopram e escitalopram também prolongam QTc. Combinação aumenta o risco de QT. Paradoxalmente, ondansetrona pode reduzir a atividade de ISRSs ao bloquear 5-HT3, mas o risco de QT predomina',
    'QTc prolongado com risco de torsades de pointes, especialmente com citalopram/escitalopram (que mais prolongam QT entre ISRSs). FDA limitou ondansetrona a 16mg IV por dose em 2011',
    'Evitar ondansetrona + citalopram ou escitalopram (maior risco). Limitar ondansetrona IV a 8mg por dose. Monitorar ECG. Considerar metoclopramida como alternativa antiemética (mas não em idosos → extrapiramidal)',
    'QT PROLONGADO — Evitar ondansetrona + citalopram/escitalopram; limitar IV a 8mg; monitorar ECG',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('ondansetrona', 'quetiapina', InteractionSeverity.major,
    'Ambos prolongam QTc: ondansetrona por IKr; quetiapina por múltiplos mecanismos. Risco aditivo de torsades',
    'QTc prolongado com risco de torsades de pointes',
    'Monitorar ECG. Corrigir electrolitos. Evitar em pacientes com QTc > 450ms',
    'QT PROLONGADO — Monitorar ECG com ondansetrona + quetiapina; corrigir electrolitos',
    EvidenceLevel.established,
    {RiskType.qtProlongation},
    [_kRefGG, _kRefMdx]),


  ('colchicina', 'eritromicina', InteractionSeverity.major,
    'Eritromicina inibe CYP3A4 e P-gp, aumentando os níveis de colchicina. Menor magnitude que claritromicina, mas ainda clinicamente perigosa',
    'Toxicidade de colchicina: miopatia, pancitopenia, insuficiencia renal, toxicidad multissistêmica',
    'Evitar combinación. Preferir azitromicina (não inibe CYP3A4 ou P-gp significativamente). Se eritromicina necessária: dose única e mínima de colchicina, monitorar CK e hemograma',
    'TOXICIDADE GRAVE — Evitar eritromicina com colchicina; preferir azitromicina',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx]),


  ('colchicina', 'verapamil', InteractionSeverity.major,
    'Verapamil inibe P-gp e CYP3A4, as principais vias de eliminação da colchicina. Riesgo de toxicidad análoga à claritromicina + colchicina',
    'Toxicidade grave de colchicina: miopatia, pancitopenia, insuficiencia renal multissistêmica',
    'Evitar combinación. Se colchicina necessária em paciente com verapamil: dose única de 0,6mg (sem repetir), monitorar CK e hemograma. Considerar alternativa para gota (prednisona, AINE)',
    'TOXICIDADE FATAL POSSÍVEL — Evitar colchicina com verapamil; usar prednisona ou AINE para gota',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx]),


  ('ranolazina', 'verapamil', InteractionSeverity.major,
    'Verapamil inibe CYP3A4 e P-gp, aumentando os níveis de ranolazina em 100%. Ambos têm efeitos cardiovasculares: bradicardia e prolongamento do PR. Ranolazina prolonga QTc',
    'Acúmulo de ranolazina → QTc prolongado, hipotensão. Bradicardia aditiva',
    'Limitar dose de ranolazina a 500mg 2x/dia com verapamil. Monitorar ECG e PA. Bula da ranolazina recomenda dose máxima reducida com inibidores de CYP3A4 moderados',
    'QT PROLONGADO + HIPOTENSÃO — Limitar ranolazina a 500mg 2x/dia com verapamil; monitorar ECG e PA',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('ranolazina', 'diltiazem', InteractionSeverity.major,
    'Diltiazem inibe CYP3A4 moderadamente, aumentando os níveis de ranolazina em 50-70%. Ambos prolongam o intervalo QT e reduzem PA',
    'Acúmulo de ranolazina → QTc prolongado, hipotensão',
    'Limitar dose de ranolazina a 500mg 2x/dia com diltiazem. Monitorar ECG e PA',
    'QT PROLONGADO + ACÚMULO — Limitar ranolazina a 500mg 2x/dia com diltiazem; monitorar ECG',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('sildenafila', 'amiodarona', InteractionSeverity.major,
    'Amiodarona inibe CYP3A4, podendo aumentar os níveis de sildenafila. Ambos causam vasodilatação e hipotensão. Em pacientes com HTP (hipertensão pulmonar) usando ambos: risco hemodinâmico',
    'Hipotensão grave por efeito vasodilatador aditivo (PDE5-i + amiodarona). Acúmulo de sildenafila por inhibición de CYP3A4',
    'Monitorar PA rigurosamente. Iniciar sildenafila em dose baixa (25mg). Em HTP: supervisão cardiológica especializada',
    'HIPOTENSÃO GRAVE — Amiodarona inibe CYP3A4; iniciar sildenafila em dose baixa; monitorar PA',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('propofol', 'benzodiazepínico', InteractionSeverity.major,
    'Propofol (potenciador de GABA-A) e benzodiazepínicos (também GABA-A) têm efeito sinérgico na sedação e depresión respiratoria',
    'Apneia, depresión respiratoria profunda, hipotensão grave. Risco especialmente alto em idosos, DPOC e em bolus rápidos',
    'Usar apenas em ambiente monitorado. Titular lentamente. Ter flumazenil disponible. Monitorar SpO₂ e ETCO₂',
    'APNEIA — Usar apenas em ambiente monitorado; ter flumazenil; monitorar SpO₂',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression},
    [_kRefGG, _kRefMdx]),


  ('levosimendan', 'betabloqueador', InteractionSeverity.moderate,
    'Levosimendan (sensibilizador de cálcio + abre canais de KATP vasculares) causa vasodilatação e melhora contratilidade. Betabloqueadores reduzem a FC e contratilidade. Efeito hemodinâmico parcialmente oposto',
    'Hipotensão e bradicardia por efeito vasodilatador de levosimendan + cronotropismo negativo do betabloqueador',
    'Monitorar PA e FC rigurosamente durante infusão de levosimendan. Reduzir dose do betabloqueador se hipotensão ou bradicardia sintomáticas',
    'HIPOTENSÃO + BRADICARDIA — Monitorar PA e FC durante levosimendan; reduzir betabloqueador se necesario',
    EvidenceLevel.probable,
    {RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),


  ('dexmedetomidina', 'betabloqueador', InteractionSeverity.major,
    'Dexmedetomidina (agonista α2 central) causa bradicardia e hipotensão. Betabloqueadores também causam bradicardia. Efeito aditivo na redução da FC e PA',
    'Bradicardia grave (FC < 40bpm), bloqueio AV, hipotensão grave, asistolia em bolus rápidos de dexmedetomidina',
    'Monitorar ECG e PA continuamente durante dexmedetomidina. Titular lentamente. Ter atropina disponible. Evitar bolus rápidos de carga',
    'BRADICARDIA GRAVE — Monitorar ECG continuamente; ter atropina disponible; evitar bolus rápidos',
    EvidenceLevel.established,
    {RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),


  ('dexmedetomidina', 'opioide', InteractionSeverity.major,
    'Dexmedetomidina potencializa os efeitos analgésicos e sedativos dos opioides por mecanismo agonista α2. Permite redução de 30-50% na dose de opioide em UTI (efeito "opioide-sparing"). Risco de depresión respiratoria aditiva',
    'Depressão respiratória aumentada, bradicardia, hipotensão grave em doses elevadas de ambos',
    'Usar combinação com redução da dose de opioide (efeito opioide-sparing reconhecido). Monitorar SpO₂, PA e FC continuamente. Tener naloxona disponible',
    'DEPRESSÃO RESPIRATÓRIA + BRADICARDIA — Reduzir dose de opioide 30-50%; monitorar SpO₂ e PA continuamente',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),


    // ═══════════════════════════════════════════════════════════════
    // BLOCO 10 — pares clinicamente relevantes ausentes entre IDs existentes
    // Categorias: QT, serotonina, imunossupressores, antiepilépticos,
    //             hemostasia, hiperpotasemia, hipoglucemia, estatinas,
    //             digoxina, IBPs, cardiovascular, lítio, antimicrobianos
    // ═══════════════════════════════════════════════════════════════

  ('amiodarona', 'fluconazol', InteractionSeverity.major,
    'Ambos prolongam o intervalo QT: amiodarona bloqueia canais de potássio (IKr); fluconazol inibe CYP3A4/2C9 elevando níveis de amiodarona',
    'Prolongación aditiva del QTc; risco elevado de torsades de pointes e morte súbita cardíaca',
    'Evitar combinación. Se imprescindível, monitorar ECG contínuo, corrigir hipopotasemia/hipomagnesemia e reduzir dose de fluconazol',
    'RISCO DE TORSADES — Evitar combinación',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefMdx, _kRefUT, _kRefLex]),

  ('amiodarona', 'claritromicina', InteractionSeverity.major,
    'Claritromicina prolonga QT e inibe CYP3A4, elevando concentrações de amiodarona; efeito aditivo sobre IKr',
    'Prolongamento marcado do QTc; torsades de pointes e fibrilação ventricular',
    'Contraindicado. Usar azitromicina somente se ECG basal normal e sem alternativa; monitorar ECG',
    'RISCO DE TORSADES — Contraindicado',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefMdx, _kRefUT]),

  ('amiodarona', 'olanzapina', InteractionSeverity.major,
    'Olanzapina bloqueia canais hERG (IKr); somado ao potente efeito de amiodarona, prolonga QTc aditivamente',
    'Prolongamento do QTc; risco de torsades de pointes e morte súbita',
    'Evitar combinación. Considerar antipsicótico com menor risco de QT. Monitorar ECG',
    'RISCO DE TORSADES — Evitar',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefMdx, _kRefUT]),

  ('sotalol', 'fluconazol', InteractionSeverity.major,
    'Fluconazol inibe CYP3A4 elevando nível de sotalol; sotalol bloqueia IKr prolongando QT',
    'Prolongamento excessivo do QTc; torsades de pointes',
    'Evitar. Monitorar ECG e electrolitos. Preferir antifúngico alternativo',
    'RISCO DE TORSADES — Evitar',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefMdx, _kRefUT]),

  ('sotalol', 'claritromicina', InteractionSeverity.major,
    'Claritromicina inibe CYP3A4 e prolonga QT por si mesma; efeito aditivo sobre IKr com sotalol',
    'Prolongamento crítico do QTc; torsades de pointes',
    'Contraindicado. Usar antibiótico alternativo sem efeito sobre QT',
    'RISCO DE TORSADES — Contraindicado',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefMdx, _kRefUT]),

  ('sotalol', 'metadona', InteractionSeverity.major,
    'Metadona prolonga QT por bloqueio de IKr; somado ao sotalol, efeito aditivo significativo',
    'Prolongamento grave do QTc; risco de torsades de pointes e morte súbita',
    'Contraindicado. Se analgesia com opioide necessária, usar morfina ou fentanila com monitoração de ECG',
    'RISCO DE TORSADES — Contraindicado',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefMdx, _kRefUT]),

  ('haloperidol', 'claritromicina', InteractionSeverity.major,
    'Claritromicina inibe CYP3A4 elevando nível de haloperidol e prolonga QT por si mesma; efeito aditivo',
    'Prolongamento do QTc; torsades de pointes; aumento de efeitos extrapiramidais',
    'Evitar. Monitorar ECG. Usar antibiótico alternativo',
    'RISCO DE TORSADES — Evitar combinación',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),

  ('haloperidol', 'metadona', InteractionSeverity.major,
    'Ambos prolongam QT por bloqueio de IKr; metadona inibe CYP2D6 podendo elevar haloperidol',
    'Prolongamento crítico do QTc; torsades de pointes',
    'Contraindicado. Se necesario antipsicótico, preferir quetiapina com dose baixa e monitoração de ECG',
    'RISCO DE TORSADES — Contraindicado',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefMdx, _kRefUT]),

  ('quetiapina', 'claritromicina', InteractionSeverity.major,
    'Claritromicina inibe CYP3A4 intensamente; quetiapina é metabolizada por CYP3A4 — nível plasmático aumenta 5-10x',
    'Sedação excessiva, hipotensão ortostática, prolongamento do QT',
    'Evitar. Reduzir dose de quetiapina em até 80% se antibiótico imprescindível. Monitorar ECG',
    'NÍVEL DE QUETIAPINA ↑↑↑ — Sedação e QT',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.qtProlongation, RiskType.cns},
    [_kRefMdx, _kRefUT]),

  ('metadona', 'fluconazol', InteractionSeverity.major,
    'Fluconazol inibe CYP3A4 e CYP2C19, reduzindo metabolismo da metadona; elevação do nível plasmático',
    'Sedación excesiva, depresión respiratoria, prolongamento do QT',
    'Reduzir dose de metadona em ~25-50%. Monitorar ECG e nível de consciência',
    'METADONA ↑ — Depressão respiratória e QT',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.qtProlongation, RiskType.respiratoryDepression},
    [_kRefMdx, _kRefUT]),

  ('sacubitrila', 'losartana', InteractionSeverity.moderate,
    'Sacubitrila já associada a valsartana (sacubitril/valsartan); adicionar outro ARA-II eleva risco de hipotensão e hiperpotasemia',
    'Hipotensão sintomática; hiperpotasemia; piora da función renal',
    'Não combinar ARA-II adicional com sacubitrila/valsartana; monitorar PA, creatinina e potássio',
    'HIPOTENSÃO e HIPERCALEMIA — Não combinar ARA-II extra',
    EvidenceLevel.probable,
    {RiskType.cardiovascular, RiskType.hyperkalemia},
    [_kRefUT, _kRefFDA]),

  ('rivaroxabana', 'claritromicina', InteractionSeverity.major,
    'Claritromicina inibe CYP3A4 e P-gp; rivaroxabana é substrato de ambos — nível plasmático aumenta significativamente',
    'Risco hemorrágico aumentado (sangrado GI, intracraneal)',
    'Evitar combinación. Se imprescindível, monitorar sinais de sangrado ativamente',
    'RISCO HEMORRÁGICO ↑ — Evitar',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),

  ('apixabana', 'claritromicina', InteractionSeverity.major,
    'Claritromicina inibe CYP3A4 e P-gp; apixabana é substrato de ambos — exposição plasmática aumentada',
    'Risco hemorrágico aumentado',
    'Evitar combinación. Se imprescindível, vigilância clínica intensa para sinais de sangrado',
    'RISCO HEMORRÁGICO ↑ — Evitar',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),

  ('dabigatrana', 'claritromicina', InteractionSeverity.major,
    'Claritromicina inibe P-gp; dabigatrana é substrato de P-gp — biodisponibilidade e AUC aumentam ~15-20%',
    'Risco hemorrágico aumentado',
    'Evitar. Monitorar tempo de trombina ou nível anti-Xa se alternativa não disponible',
    'RISCO HEMORRÁGICO ↑ — Evitar',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),

  ('dabigatrana', 'fluconazol', InteractionSeverity.moderate,
    'Fluconazol inibe P-gp moderadamente; dabigatrana é substrato de P-gp — leve aumento de exposição',
    'Risco de sangrado aumentado de forma moderada',
    'Monitorar sinais de sangrado. Evitar em pacientes com alto risco hemorrágico',
    'MONITORAR SANGRAMENTO',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),

  ('fondaparinux', 'aspirina', InteractionSeverity.moderate,
    'Efeito antitrombótico aditivo: inibição de fator Xa + inibição plaquetária por aspirina',
    'Risco hemorrágico moderadamente aumentado',
    'Monitorar sinais de sangrado, especialmente GI. Usar dose mínima de AAS',
    'MONITORAR SANGRAMENTO',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefUT]),

  ('fluoxetina', 'tramadol', InteractionSeverity.major,
    'Tramadol inibe recaptação de serotonina; fluoxetina é ISRS potente — síndrome serotoninérgica por efeito aditivo; fluoxetina inibe CYP2D6 reduzindo conversão de tramadol ao metabólito ativo',
    'Síndrome serotoninérgica (tremor, mioclonia, hipertermia, agitação, confusão)',
    'Evitar combinación. Usar opioide sem efeito serotoninérgico (morfina, fentanila)',
    'SÍNDROME SEROTONINÉRGICA — Evitar',
    EvidenceLevel.established,
    {RiskType.serotonin, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),

  ('fluoxetina', 'metadona', InteractionSeverity.major,
    'Fluoxetina inibe CYP2D6 e CYP3A4 elevando nível de metadona; ambos prolongam QT; risco serotoninérgico aditivo',
    'Toxicidade de metadona: depresión respiratoria, prolongamento do QTc, síndrome serotoninérgica',
    'Evitar. Monitorar ECG e nível de consciência. Considerar opioide alternativo',
    'METADONA ↑ + QT + SEROTONINA — Evitar',
    EvidenceLevel.established,
    {RiskType.serotonin, RiskType.qtProlongation, RiskType.respiratoryDepression, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),

  ('amitriptilina', 'fluoxetina', InteractionSeverity.major,
    'Fluoxetina inibe CYP2D6 intensamente — metabolismo de amitriptilina reducido, nível aumenta 2-4x; ambos prolongam QT; risco serotoninérgico',
    'Toxicidade de antidepressivo tricíclico: arritmias, hipotensão, sedação, convulsiones',
    'Evitar. Se necesario, reduzir dose de amitriptilina em 50-75% e monitorar ECG e nível plasmático',
    'AMITRIPTILINA ↑↑ + QT + SEROTONINA — Evitar',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.qtProlongation, RiskType.serotonin},
    [_kRefMdx, _kRefUT]),

  ('fenobarbital', 'carbamazepina', InteractionSeverity.moderate,
    'Ambos são indutores de CYP3A4 e CYP2C — redução mútua dos niveles plasmáticos',
    'Nível de ambos reducido; possível perda de eficácia antiepiléptica',
    'Monitorar níveis séricos e resposta clínica. Ajustar doses individualmente',
    'NÍVEIS REDUZIDOS MÚTUOS — Monitorar',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),

  ('contraste iodado', 'aminoglicosideo', InteractionSeverity.major,
    'Aminoglicosídeos causam nefrotoxicidad; contraste iodado causa nefropatia por contraste — risco aditivo de lesão renal aguda',
    'Lesão renal aguda grave; possível necessidade de diálise',
    'Evitar contraste em pacientes em uso de aminoglicosídeo. Se imprescindível, hidratar vigorosamente e monitorar creatinina 48-72h',
    'NEFROTÓXICO ADITIVO — Hidratar e monitorar',
    EvidenceLevel.probable,
    {RiskType.nephrotoxicity},
    [_kRefMdx, _kRefUT]),

  ('metotrexato', 'trimetoprima', InteractionSeverity.major,
    'Trimetoprima inibe dihidrofolato redutase; somado a metotrexato (também inibe DHFR), causa depleção grave de folato',
    'Mielossupressão grave (pancitopenia); mucosite; toxicidad hematológica',
    'Evitar combinación. Se necesario, usar ácido folínico (leucovorina) após metotrexato',
    'MIELOSSUPRESSÃO GRAVE — Evitar',
    EvidenceLevel.established,
    {RiskType.myelosuppression},
    [_kRefGG, _kRefMdx, _kRefUT]),

  ('metotrexato', 'sulfametoxazol', InteractionSeverity.major,
    'Sulfametoxazol inibe DHFR e compete com metotrexato pela excreção tubular renal — nível de metotrexato aumenta',
    'Mielossupressão grave; mucosite; nefrotoxicidad',
    'Evitar. Usar antibiótico alternativo. Se imprescindível, monitorar hemograma e nível de metotrexato',
    'MIELOSSUPRESSÃO + METOTREXATO ↑ — Evitar',
    EvidenceLevel.established,
    {RiskType.myelosuppression, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),

  ('eplerenona', 'losartana', InteractionSeverity.major,
    'Eplerenona retém potássio; ARA-II reduz excreção de potássio — hiperpotasemia aditiva',
    'Hipercalemia grave; arritmia ventricular',
    'Monitorar K+ e creatinina. Evitar em pacientes com TFG <50 mL/min',
    'HIPERCALEMIA GRAVE — Monitorar K+',
    EvidenceLevel.established,
    {RiskType.hyperkalemia},
    [_kRefFDA, _kRefUT]),

  ('finerenona', 'losartana', InteractionSeverity.major,
    'Finerenona retém potássio; ARA-II reduz excreção de K+ — hiperpotasemia aditiva',
    'Hipercalemia; piora da función renal',
    'Monitorar K+ e función renal. Contraindicado se K+ >5 mEq/L',
    'HIPERCALEMIA — Monitorar K+',
    EvidenceLevel.established,
    {RiskType.hyperkalemia},
    [_kRefFDA, _kRefUT]),

  ('rosuvastatina', 'ciclosporina', InteractionSeverity.major,
    'Ciclosporina inibe OATP1B1 e P-gp; rosuvastatina é substrato de ambos — AUC aumenta ~10x',
    'Miopatia grave; rabdomiólisis',
    'Evitar ou limitar rosuvastatina a 5 mg/dia com ciclosporina. Monitorar CK',
    'RABDOMIÓLISE — Dose máx 5 mg/dia',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),

  ('digoxina', 'fluconazol', InteractionSeverity.moderate,
    'Fluconazol pode inibir P-gp e reduzir clearance renal de digoxina — nivel sérico aumenta moderadamente',
    'Toxicidade digitálica leve a moderada',
    'Monitorar nivel sérico de digoxina e ECG. Reduzir dose se necesario',
    'DIGOXINA ↑ — Monitorar nível',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel, RiskType.arrhythmia},
    [_kRefMdx, _kRefUT]),

  ('quinolona', 'teofilina', InteractionSeverity.major,
    'Quinolonas (principalmente ciprofloxacino, enoxacino) inibem CYP1A2; teofilina metabolizada por CYP1A2',
    'Toxicidade da teofilina: convulsiones, arritmias',
    'Monitorar nível de teofilina. Reduzir dose em 30-50% com ciprofloxacino. Preferir levofloxacino (menor interação)',
    'TEOFILINA ↑ — Monitorar e reduzir dose',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.seizure},
    [_kRefGG, _kRefMdx]),

  ('dexametasona', 'ciclosporina', InteractionSeverity.moderate,
    'Dexametasona induz CYP3A4; ciclosporina metabolizada por CYP3A4 — nível reducido; ciclosporina inibe metabolismo de dexametasona',
    'Nível de ciclosporina reducido (risco de rejeição); nível de dexametasona aumentado',
    'Monitorar nivel sérico de ciclosporina. Ajustar doses',
    'CICLOSPORINA ↓ — Monitorar nivel sérico',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel, RiskType.reducedEfficacy},
    [_kRefMdx, _kRefUT]),

  ('dexametasona', 'warfarina', InteractionSeverity.moderate,
    'Corticosteroides podem inibir ou induzir CYP2C9 (variável); efeito líquido imprevisível sobre INR; também inibem trombosis',
    'Variação do INR (aumento ou redução)',
    'Monitorar INR a cada 3-5 dias durante uso de dexametasona. Ajustar dosis de warfarina según INR',
    'INR VARIÁVEL — Monitorar',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel, RiskType.hemorrhagic},
    [_kRefMdx, _kRefUT]),

  ('dexametasona', 'fenitoína', InteractionSeverity.major,
    'Fenitoína induz CYP3A4 reduzindo nível de dexametasona; dexametasona induz CYP3A4 reduzindo fenitoína; interação bidirecional',
    'Eficácia de dexametasona reducida; nível de fenitoína instável',
    'Aumentar dose de dexametasona se necesario. Monitorar nível de fenitoína. Considerar antiepiléptico alternativo',
    'DEXAMETASONA ↓ + FENITOÍNA VARIÁVEL',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx, _kRefUT]),

  ('rocurônio', 'dexmedetomidina', InteractionSeverity.minor,
    'Dexmedetomidina pode prolongar levemente o bloqueio neuromuscular por redução do tônus simpático',
    'Bloqueio neuromuscular levemente prolongado',
    'Monitorar TOF. Ajustar dose de reversão se necesario',
    'BLOQ. NEUROMUSCULAR PROLONGADO — Monitorar',
    EvidenceLevel.possible,
    {RiskType.respiratoryDepression},
    [_kRefMdx]),

  ('teofilina', 'furosemida', InteractionSeverity.moderate,
    'Furosemida pode aumentar excreção de teofilina em altas doses; hipopotasemia pode aumentar toxicidad cardíaca de teofilina',
    'Variação do nível de teofilina; toxicidad cardíaca facilitada por hipopotasemia',
    'Monitorar nível de teofilina e K+ sérico. Repor potássio se necesario',
    'TEOFILINA VARIÁVEL + HIPOCALEMIA — Monitorar',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel, RiskType.hypokalemia},
    [_kRefMdx]),

  ('teofilina', 'rifampicina', InteractionSeverity.major,
    'Rifampicina induz CYP1A2; teofilina metabolizada por CYP1A2 — clearance aumenta e nível cai 50-75%',
    'Perda de eficácia da teofilina; piora do broncoespasmo',
    'Aumentar dose de teofilina 50-100% ao usar rifampicina. Monitorar nivel sérico',
    'TEOFILINA ↓↓ — Aumentar dose',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),

  ('metotrexato', 'aine', InteractionSeverity.major,
    'AINEs inibem secreção tubular renal de metotrexato e reduzem TFG — retenção de metotrexato',
    'Toxicidade de metotrexato: mielosupresión, mucosite, nefrotoxicidad, hepatotoxicidad',
    'Evitar AINEs com metotrexato em altas doses. Em baixas doses (artrite), monitorar hemograma e función renal',
    'METOTREXATO ↑ — TOXICIDADE GRAVE',
    EvidenceLevel.established,
    {RiskType.myelosuppression, RiskType.nephrotoxicity, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),

  ('bupropiona', 'tamoxifeno', InteractionSeverity.major,
    'Bupropiona inibe CYP2D6; tamoxifeno convertido ao metabólito ativo endoxifeno por CYP2D6 — eficácia reducida',
    'Redução do efeito antiestrogênico do tamoxifeno; possível falha no tratamento de câncer de mama',
    'Evitar. Usar antidepressivo que não iniba CYP2D6 (venlafaxina, citalopram, mirtazapina)',
    'TAMOXIFENO ↓ — Falha oncológica',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.reducedEfficacy},
    [_kRefMdx, _kRefUT]),

  ('fluoxetina', 'tamoxifeno', InteractionSeverity.major,
    'Fluoxetina é inibidor potente de CYP2D6; tamoxifeno requer CYP2D6 para conversão ao metabólito ativo (endoxifeno)',
    'Reducción de la eficacia do tamoxifeno; risco de recorrência do câncer de mama',
    'Evitar. Preferir antidepressivos com mínima inibição de CYP2D6: venlafaxina ou citalopram',
    'TAMOXIFENO ↓ — Falha oncológica',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.reducedEfficacy},
    [_kRefMdx, _kRefUT, _kRefLex]),

  ('ranolazina', 'fluconazol', InteractionSeverity.major,
    'Fluconazol inibe CYP3A4; ranolazina metabolizada por CYP3A4 — exposição aumenta significativamente',
    'Prolongamento do QT; toxicidad de ranolazina',
    'Evitar. Monitorar ECG se imprescindível',
    'RANOLAZINA ↑ + QT — Evitar',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel, RiskType.qtProlongation},
    [_kRefMdx, _kRefUT]),

  ('propofol', 'midazolam', InteractionSeverity.major,
    'Ambos são depressores do SNC; efeito sedativo e respiratório aditivo',
    'Depressão respiratória grave; apneia; hipotensão',
    'Reduzir dose de cada agente (interação sinérgica). Ter suporte ventilatório disponible. Monitorar SpO2',
    'DEPRESSÃO RESPIRATÓRIA — Reduzir doses',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.respiratoryDepression, RiskType.cardiovascular},
    [_kRefGG, _kRefMdx]),

  ('ritonavir', 'colchicina', InteractionSeverity.contraindicated,
    'Ritonavir inibe CYP3A4 e P-gp; colchicina substrato de ambos — nível aumenta 20-40x',
    'Toxicidade fatal de colchicina: mielossuupressão, miopatia, falência de múltiplos órgãos',
    'Contraindicado em IRC. Dose única máxima de colchicina 0,6 mg (sem repetição por 3 dias) se TFG normal',
    'CONTRAINDICADO em IRC — Toxicidade fatal',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.myelosuppression, RiskType.myopathy},
    [_kRefFDA, _kRefMdx]),

  ('isavuconazol', 'tacrolimo', InteractionSeverity.major,
    'Isavuconazol inibe CYP3A4 e P-gp; tacrolimo é substrato de ambos — nível aumenta ~100%',
    'Nefrotoxicidad; neurotoxicidad',
    'Reduzir dose de tacrolimo em 50%. Monitorar nivel sérico a cada 2-3 dias',
    'TACROLIMO ↑↑ — Reduzir dose 50%',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.nephrotoxicity},
    [_kRefMdx, _kRefUT]),

  ('acetazolamida', 'carbonato de litio', InteractionSeverity.moderate,
    'Acetazolamida aumenta excreção renal de lítio (alcalinização da urina); nível de lítio pode reduzir',
    'Redução do nível de lítio; possível perda de eficácia terapéutica',
    'Monitorar nível de lítio ao iniciar ou suspender acetazolamida. Ajustar dose se necesario',
    'LÍTIO ↓ — Monitorar nivel sérico',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel, RiskType.reducedEfficacy},
    [_kRefMdx]),

  ('perampanel', 'valproato', InteractionSeverity.moderate,
    'Valproato pode aumentar nível de perampanel; perampanel pode reduzir levemente nível de valproato',
    'Toxicidade de perampanel: tontura, irritabilidade, agressividade',
    'Monitorar sinais de toxicidad de perampanel. Ajustar dose conforme tolerância',
    'PERAMPANEL ↑ — Monitorar toxicidad',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel, RiskType.cns},
    [_kRefMdx, _kRefUT]),

  ('tocilizumabe', 'baricitinibe', InteractionSeverity.major,
    'Ambos são imunossupressores potentes (IL-6i + JAKi); risco de imunossupressão excessiva',
    'Infecções oportunistas graves; reativação de tuberculose/herpes; trombosis',
    'Evitar combinación. Monitorar hemograma e sinais de infecção se necesario',
    'IMUNOSSUPRESSÃO EXCESSIVA — Evitar combinación',
    EvidenceLevel.probable,
    {RiskType.infection, RiskType.myelosuppression},
    [_kRefFDA, _kRefUT]),
    // ── BLOCO 10 — Pares intra-categoria ausentes ──────────────────────────────


  ('aine', 'ibuprofeno', InteractionSeverity.moderate,
    'Dois inibidores de COX: inibição aditiva de prostaglandinas protetoras da mucosa gástrica e vasodilatadoras renais. Sem benefício analgésico adicional comprovado',
    'Risco aumentado de sangrado GI, úlcera péptica e lesão renal aguda por efeito aditivo na inibição de prostaglandinas',
    'EVITAR combinação de dois AINEs. Usar dose mínima efetiva de um único AINE. Adicionar protetor gástrico (IBP) se uso inevitável. Monitorar función renal e sinais de sangrado GI',
    'EVITAR DOIS AINEs — Risco hemorrágico e nefrotóxico aditivo; usar apenas um AINE',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.nephrotoxicity},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('aine', 'naproxeno', InteractionSeverity.moderate,
    'Dois inibidores de COX: inibição aditiva de prostaglandinas protetoras da mucosa gástrica e vasodilatadoras renais. Sem benefício analgésico adicional comprovado',
    'Risco aumentado de sangrado GI, úlcera péptica e lesão renal aguda por efeito aditivo na inibição de prostaglandinas',
    'EVITAR combinação de dois AINEs. Usar dose mínima efetiva de um único AINE. Adicionar protetor gástrico (IBP) se uso inevitável. Monitorar función renal e sinais de sangrado GI',
    'EVITAR DOIS AINEs — Risco hemorrágico e nefrotóxico aditivo; usar apenas um AINE',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.nephrotoxicity},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('aine', 'cetorolaco', InteractionSeverity.moderate,
    'Dois inibidores de COX: inibição aditiva de prostaglandinas protetoras da mucosa gástrica e vasodilatadoras renais. Sem benefício analgésico adicional comprovado',
    'Risco aumentado de sangrado GI, úlcera péptica e lesão renal aguda por efeito aditivo na inibição de prostaglandinas',
    'EVITAR combinação de dois AINEs. Usar dose mínima efetiva de um único AINE. Adicionar protetor gástrico (IBP) se uso inevitável. Monitorar función renal e sinais de sangrado GI',
    'EVITAR DOIS AINEs — Risco hemorrágico e nefrotóxico aditivo; usar apenas um AINE',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.nephrotoxicity},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('aspirina', 'ibuprofeno', InteractionSeverity.major,
    'Ibuprofeno compete com aspirina pelo sítio de ligação irreversível na COX-1 plaquetária, bloqueando o acesso da aspirina e anulando seu efeito antiagregante',
    'Perda do efeito cardioprotetor da aspirina. Risco hemorrágico GI aditivo por inhibición de prostaglandinas protetoras da mucosa',
    'Administrar aspirina ≥2h antes do ibuprofeno para preservar o efeito antiagregante. Se AINE obligatorio, preferir celecoxibe (não compete com aspirina). Monitorar INR e sintomas GI',
    'ANULA EFEITO ANTIAGREGANTE — Administrar AAS ≥2h antes do ibuprofeno; considerar celecoxibe',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('aspirina', 'naproxeno', InteractionSeverity.moderate,
    'Dois inibidores de COX: inibição aditiva de prostaglandinas protetoras da mucosa gástrica e vasodilatadoras renais. Sem benefício analgésico adicional comprovado',
    'Risco aumentado de sangrado GI, úlcera péptica e lesão renal aguda por efeito aditivo na inibição de prostaglandinas',
    'EVITAR combinação de dois AINEs. Usar dose mínima efetiva de um único AINE. Adicionar protetor gástrico (IBP) se uso inevitável. Monitorar función renal e sinais de sangrado GI',
    'EVITAR DOIS AINEs — Risco hemorrágico e nefrotóxico aditivo; usar apenas um AINE',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.nephrotoxicity},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('aspirina', 'cetorolaco', InteractionSeverity.moderate,
    'Dois inibidores de COX: inibição aditiva de prostaglandinas protetoras da mucosa gástrica e vasodilatadoras renais. Sem benefício analgésico adicional comprovado',
    'Risco aumentado de sangrado GI, úlcera péptica e lesão renal aguda por efeito aditivo na inibição de prostaglandinas',
    'EVITAR combinação de dois AINEs. Usar dose mínima efetiva de um único AINE. Adicionar protetor gástrico (IBP) se uso inevitável. Monitorar función renal e sinais de sangrado GI',
    'EVITAR DOIS AINEs — Risco hemorrágico e nefrotóxico aditivo; usar apenas um AINE',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.nephrotoxicity},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('aspirina', 'clonixinato', InteractionSeverity.moderate,
    'Dois inibidores de COX: inibição aditiva de prostaglandinas protetoras da mucosa gástrica e vasodilatadoras renais. Sem benefício analgésico adicional comprovado',
    'Risco aumentado de sangrado GI, úlcera péptica e lesão renal aguda por efeito aditivo na inibição de prostaglandinas',
    'EVITAR combinação de dois AINEs. Usar dose mínima efetiva de um único AINE. Adicionar protetor gástrico (IBP) se uso inevitável. Monitorar función renal e sinais de sangrado GI',
    'EVITAR DOIS AINEs — Risco hemorrágico e nefrotóxico aditivo; usar apenas um AINE',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.nephrotoxicity},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('cetorolaco', 'ibuprofeno', InteractionSeverity.moderate,
    'Dois inibidores de COX: inibição aditiva de prostaglandinas protetoras da mucosa gástrica e vasodilatadoras renais. Sem benefício analgésico adicional comprovado',
    'Risco aumentado de sangrado GI, úlcera péptica e lesão renal aguda por efeito aditivo na inibição de prostaglandinas',
    'EVITAR combinação de dois AINEs. Usar dose mínima efetiva de um único AINE. Adicionar protetor gástrico (IBP) se uso inevitável. Monitorar función renal e sinais de sangrado GI',
    'EVITAR DOIS AINEs — Risco hemorrágico e nefrotóxico aditivo; usar apenas um AINE',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.nephrotoxicity},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('cetorolaco', 'naproxeno', InteractionSeverity.moderate,
    'Dois inibidores de COX: inibição aditiva de prostaglandinas protetoras da mucosa gástrica e vasodilatadoras renais. Sem benefício analgésico adicional comprovado',
    'Risco aumentado de sangrado GI, úlcera péptica e lesão renal aguda por efeito aditivo na inibição de prostaglandinas',
    'EVITAR combinação de dois AINEs. Usar dose mínima efetiva de um único AINE. Adicionar protetor gástrico (IBP) se uso inevitável. Monitorar función renal e sinais de sangrado GI',
    'EVITAR DOIS AINEs — Risco hemorrágico e nefrotóxico aditivo; usar apenas um AINE',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.nephrotoxicity},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('cetorolaco', 'clonixinato', InteractionSeverity.moderate,
    'Dois inibidores de COX: inibição aditiva de prostaglandinas protetoras da mucosa gástrica e vasodilatadoras renais. Sem benefício analgésico adicional comprovado',
    'Risco aumentado de sangrado GI, úlcera péptica e lesão renal aguda por efeito aditivo na inibição de prostaglandinas',
    'EVITAR combinação de dois AINEs. Usar dose mínima efetiva de um único AINE. Adicionar protetor gástrico (IBP) se uso inevitável. Monitorar función renal e sinais de sangrado GI',
    'EVITAR DOIS AINEs — Risco hemorrágico e nefrotóxico aditivo; usar apenas um AINE',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.nephrotoxicity},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('ibuprofeno', 'naproxeno', InteractionSeverity.moderate,
    'Dois inibidores de COX: inibição aditiva de prostaglandinas protetoras da mucosa gástrica e vasodilatadoras renais. Sem benefício analgésico adicional comprovado',
    'Risco aumentado de sangrado GI, úlcera péptica e lesão renal aguda por efeito aditivo na inibição de prostaglandinas',
    'EVITAR combinação de dois AINEs. Usar dose mínima efetiva de um único AINE. Adicionar protetor gástrico (IBP) se uso inevitável. Monitorar función renal e sinais de sangrado GI',
    'EVITAR DOIS AINEs — Risco hemorrágico e nefrotóxico aditivo; usar apenas um AINE',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.nephrotoxicity},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('clonixinato', 'naproxeno', InteractionSeverity.moderate,
    'Dois inibidores de COX: inibição aditiva de prostaglandinas protetoras da mucosa gástrica e vasodilatadoras renais. Sem benefício analgésico adicional comprovado',
    'Risco aumentado de sangrado GI, úlcera péptica e lesão renal aguda por efeito aditivo na inibição de prostaglandinas',
    'EVITAR combinação de dois AINEs. Usar dose mínima efetiva de um único AINE. Adicionar protetor gástrico (IBP) se uso inevitável. Monitorar función renal e sinais de sangrado GI',
    'EVITAR DOIS AINEs — Risco hemorrágico e nefrotóxico aditivo; usar apenas um AINE',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.nephrotoxicity},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('clonixinato', 'ibuprofeno', InteractionSeverity.moderate,
    'Dois inibidores de COX: inibição aditiva de prostaglandinas protetoras da mucosa gástrica e vasodilatadoras renais. Sem benefício analgésico adicional comprovado',
    'Risco aumentado de sangrado GI, úlcera péptica e lesão renal aguda por efeito aditivo na inibição de prostaglandinas',
    'EVITAR combinação de dois AINEs. Usar dose mínima efetiva de um único AINE. Adicionar protetor gástrico (IBP) se uso inevitável. Monitorar función renal e sinais de sangrado GI',
    'EVITAR DOIS AINEs — Risco hemorrágico e nefrotóxico aditivo; usar apenas um AINE',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.nephrotoxicity},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('amiodarona', 'dronedarona', InteractionSeverity.contraindicated,
    'Dronedarona é contraindicada com amiodarona: ambas prolongam QTc por bloqueio de canais IKr. Risco de Torsades de Pointes e fibrilação ventricular',
    'Torsades de Pointes, fibrilación ventricular, muerte súbita cardíaca',
    'CONTRAINDICAÇÃO ABSOLUTA. Nunca combinar. Aguardar washout completo de amiodarona (meia-vida: 40-55 dias) antes de iniciar dronedarona',
    'CONTRAINDICADO ABSOLUTO — Torsades de Pointes; aguardar washout de amiodarona (40-55 dias)',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('amiodarona', 'verapamil', InteractionSeverity.major,
    'Dois antiarrítmicos com mecanismos sobrepostos: prolongamento aditivo do QTc e/ou efeito dromotrópico negativo aditivo',
    'Bradicardia, bloqueio AV, Torsades de Pointes, síncope, morte súbita',
    'Evitar combinación. Se necesario, monitorar ECG continuamente e QTc. Suspender se QTc > 500ms ou FC < 50bpm',
    'ARRITMIA GRAVE — QTc aditivo; monitorar ECG; suspender se QTc > 500ms ou FC < 50bpm',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('amiodarona', 'ivabradina', InteractionSeverity.major,
    'Ivabradina reduz FC por bloqueio dos canais If no nó sinusal. Combinada com antiarrítmico bradicardizante: bradicardia grave aditiva',
    'Bradicardia sintomática grave, bloqueio AV, síncope',
    'Evitar combinación. Se necessária, iniciar ivabradina em dose baixa (2,5 mg 2x/dia) e monitorar FC e ECG continuamente',
    'BRADICARDIA GRAVE — Ivabradina + antiarrítmico bradicardizante; monitorar FC continuamente',
    EvidenceLevel.established,
    {RiskType.arrhythmia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('diltiazem', 'verapamil', InteractionSeverity.contraindicated,
    'Dois BCCs não-diidropiridínicos com efeito dromotrópico e cronotrópico negativo aditivo. Inibição aditiva do nó AV',
    'Bloqueio AV completo, asistolia, bradicardia extrema, choque cardiogênico',
    'CONTRAINDICAÇÃO ABSOLUTA. Nunca combinar diltiazem e verapamil. Monitorar ECG rigurosamente se exposição inadvertida',
    'CONTRAINDICADO — Bloqueio AV completo e asistolia; nunca combinar diltiazem + verapamil',
    EvidenceLevel.established,
    {RiskType.arrhythmia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('diltiazem', 'sotalol', InteractionSeverity.major,
    'Sotalol prolonga QTc por bloqueio IKr. Combinado com outro antiarrítmico com mesma ação: prolongamento QTc aditivo',
    'Torsades de Pointes, fibrilação ventricular, síncope cardíaca',
    'Evitar combinación. Se necesario, monitorar QTc continuamente. QTc > 500ms exige suspensão imediata',
    'TORSADE DE POINTES — QTc aditivo; monitorar ECG; suspender se QTc > 500ms',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('dronedarona', 'sotalol', InteractionSeverity.major,
    'Sotalol prolonga QTc por bloqueio IKr. Combinado com outro antiarrítmico com mesma ação: prolongamento QTc aditivo',
    'Torsades de Pointes, fibrilação ventricular, síncope cardíaca',
    'Evitar combinación. Se necesario, monitorar QTc continuamente. QTc > 500ms exige suspensão imediata',
    'TORSADE DE POINTES — QTc aditivo; monitorar ECG; suspender se QTc > 500ms',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('dronedarona', 'verapamil', InteractionSeverity.major,
    'Dois antiarrítmicos com mecanismos sobrepostos: prolongamento aditivo do QTc e/ou efeito dromotrópico negativo aditivo',
    'Bradicardia, bloqueio AV, Torsades de Pointes, síncope, morte súbita',
    'Evitar combinación. Se necesario, monitorar ECG continuamente e QTc. Suspender se QTc > 500ms ou FC < 50bpm',
    'ARRITMIA GRAVE — QTc aditivo; monitorar ECG; suspender se QTc > 500ms ou FC < 50bpm',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('dronedarona', 'ivabradina', InteractionSeverity.major,
    'Ivabradina reduz FC por bloqueio dos canais If no nó sinusal. Combinada com antiarrítmico bradicardizante: bradicardia grave aditiva',
    'Bradicardia sintomática grave, bloqueio AV, síncope',
    'Evitar combinación. Se necessária, iniciar ivabradina em dose baixa (2,5 mg 2x/dia) e monitorar FC e ECG continuamente',
    'BRADICARDIA GRAVE — Ivabradina + antiarrítmico bradicardizante; monitorar FC continuamente',
    EvidenceLevel.established,
    {RiskType.arrhythmia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('ivabradina', 'sotalol', InteractionSeverity.major,
    'Sotalol prolonga QTc por bloqueio IKr. Combinado com outro antiarrítmico com mesma ação: prolongamento QTc aditivo',
    'Torsades de Pointes, fibrilação ventricular, síncope cardíaca',
    'Evitar combinación. Se necesario, monitorar QTc continuamente. QTc > 500ms exige suspensão imediata',
    'TORSADE DE POINTES — QTc aditivo; monitorar ECG; suspender se QTc > 500ms',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('sotalol', 'verapamil', InteractionSeverity.major,
    'Sotalol prolonga QTc por bloqueio IKr. Combinado com outro antiarrítmico com mesma ação: prolongamento QTc aditivo',
    'Torsades de Pointes, fibrilação ventricular, síncope cardíaca',
    'Evitar combinación. Se necesario, monitorar QTc continuamente. QTc > 500ms exige suspensão imediata',
    'TORSADE DE POINTES — QTc aditivo; monitorar ECG; suspender se QTc > 500ms',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('betabloqueador', 'metoprolol', InteractionSeverity.major,
    'Dois betabloqueadores: bloqueio aditivo de receptores β1 com efeito cronotrópico e inotrópico negativo aditivo',
    'Bradicardia grave, bloqueio AV 2º/3º grau, broncoespasmo, hipotensão, choque cardiogênico',
    'EVITAR combinação de dois betabloqueadores. Em transição terapéutica, suspender o primeiro antes de iniciar o segundo. Monitorar FC e ECG',
    'BRADICARDIA + BLOQUEIO AV — Dois betabloqueadores; nunca combinar; monitorar FC',
    EvidenceLevel.established,
    {RiskType.arrhythmia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('betabloqueador', 'propranolol', InteractionSeverity.major,
    'Dois betabloqueadores: bloqueio aditivo de receptores β1 com efeito cronotrópico e inotrópico negativo aditivo',
    'Bradicardia grave, bloqueio AV 2º/3º grau, broncoespasmo, hipotensão, choque cardiogênico',
    'EVITAR combinação de dois betabloqueadores. Em transição terapéutica, suspender o primeiro antes de iniciar o segundo. Monitorar FC e ECG',
    'BRADICARDIA + BLOQUEIO AV — Dois betabloqueadores; nunca combinar; monitorar FC',
    EvidenceLevel.established,
    {RiskType.arrhythmia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('betabloqueador', 'esmolol', InteractionSeverity.major,
    'Dois betabloqueadores: bloqueio aditivo de receptores β1 com efeito cronotrópico e inotrópico negativo aditivo',
    'Bradicardia grave, bloqueio AV 2º/3º grau, broncoespasmo, hipotensão, choque cardiogênico',
    'EVITAR combinação de dois betabloqueadores. Em transição terapéutica, suspender o primeiro antes de iniciar o segundo. Monitorar FC e ECG',
    'BRADICARDIA + BLOQUEIO AV — Dois betabloqueadores; nunca combinar; monitorar FC',
    EvidenceLevel.established,
    {RiskType.arrhythmia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('betabloqueador', 'labetalol', InteractionSeverity.major,
    'Dois betabloqueadores: bloqueio aditivo de receptores β1 com efeito cronotrópico e inotrópico negativo aditivo',
    'Bradicardia grave, bloqueio AV 2º/3º grau, broncoespasmo, hipotensão, choque cardiogênico',
    'EVITAR combinação de dois betabloqueadores. Em transição terapéutica, suspender o primeiro antes de iniciar o segundo. Monitorar FC e ECG',
    'BRADICARDIA + BLOQUEIO AV — Dois betabloqueadores; nunca combinar; monitorar FC',
    EvidenceLevel.established,
    {RiskType.arrhythmia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('esmolol', 'metoprolol', InteractionSeverity.major,
    'Dois betabloqueadores: bloqueio aditivo de receptores β1 com efeito cronotrópico e inotrópico negativo aditivo',
    'Bradicardia grave, bloqueio AV 2º/3º grau, broncoespasmo, hipotensão, choque cardiogênico',
    'EVITAR combinação de dois betabloqueadores. Em transição terapéutica, suspender o primeiro antes de iniciar o segundo. Monitorar FC e ECG',
    'BRADICARDIA + BLOQUEIO AV — Dois betabloqueadores; nunca combinar; monitorar FC',
    EvidenceLevel.established,
    {RiskType.arrhythmia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('esmolol', 'propranolol', InteractionSeverity.major,
    'Dois betabloqueadores: bloqueio aditivo de receptores β1 com efeito cronotrópico e inotrópico negativo aditivo',
    'Bradicardia grave, bloqueio AV 2º/3º grau, broncoespasmo, hipotensão, choque cardiogênico',
    'EVITAR combinação de dois betabloqueadores. Em transição terapéutica, suspender o primeiro antes de iniciar o segundo. Monitorar FC e ECG',
    'BRADICARDIA + BLOQUEIO AV — Dois betabloqueadores; nunca combinar; monitorar FC',
    EvidenceLevel.established,
    {RiskType.arrhythmia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('esmolol', 'labetalol', InteractionSeverity.major,
    'Dois betabloqueadores: bloqueio aditivo de receptores β1 com efeito cronotrópico e inotrópico negativo aditivo',
    'Bradicardia grave, bloqueio AV 2º/3º grau, broncoespasmo, hipotensão, choque cardiogênico',
    'EVITAR combinação de dois betabloqueadores. Em transição terapéutica, suspender o primeiro antes de iniciar o segundo. Monitorar FC e ECG',
    'BRADICARDIA + BLOQUEIO AV — Dois betabloqueadores; nunca combinar; monitorar FC',
    EvidenceLevel.established,
    {RiskType.arrhythmia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('labetalol', 'metoprolol', InteractionSeverity.major,
    'Dois betabloqueadores: bloqueio aditivo de receptores β1 com efeito cronotrópico e inotrópico negativo aditivo',
    'Bradicardia grave, bloqueio AV 2º/3º grau, broncoespasmo, hipotensão, choque cardiogênico',
    'EVITAR combinação de dois betabloqueadores. Em transição terapéutica, suspender o primeiro antes de iniciar o segundo. Monitorar FC e ECG',
    'BRADICARDIA + BLOQUEIO AV — Dois betabloqueadores; nunca combinar; monitorar FC',
    EvidenceLevel.established,
    {RiskType.arrhythmia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('labetalol', 'propranolol', InteractionSeverity.major,
    'Dois betabloqueadores: bloqueio aditivo de receptores β1 com efeito cronotrópico e inotrópico negativo aditivo',
    'Bradicardia grave, bloqueio AV 2º/3º grau, broncoespasmo, hipotensão, choque cardiogênico',
    'EVITAR combinação de dois betabloqueadores. Em transição terapéutica, suspender o primeiro antes de iniciar o segundo. Monitorar FC e ECG',
    'BRADICARDIA + BLOQUEIO AV — Dois betabloqueadores; nunca combinar; monitorar FC',
    EvidenceLevel.established,
    {RiskType.arrhythmia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('metoprolol', 'propranolol', InteractionSeverity.major,
    'Dois betabloqueadores: bloqueio aditivo de receptores β1 com efeito cronotrópico e inotrópico negativo aditivo',
    'Bradicardia grave, bloqueio AV 2º/3º grau, broncoespasmo, hipotensão, choque cardiogênico',
    'EVITAR combinação de dois betabloqueadores. Em transição terapéutica, suspender o primeiro antes de iniciar o segundo. Monitorar FC e ECG',
    'BRADICARDIA + BLOQUEIO AV — Dois betabloqueadores; nunca combinar; monitorar FC',
    EvidenceLevel.established,
    {RiskType.arrhythmia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('carbamazepina', 'gabapentina', InteractionSeverity.moderate,
    'Combinação de dois antiepiléticos com potencial interação farmacocinética (indução/inibição enzimática) ou farmacodinâmica (sedação aditiva)',
    'Alteração nos níveis séricos de um ou ambos os fármacos, sedação excessiva, tontura, ataxia',
    'Monitorar níveis séricos dos antiepiléticos envolvidos. Ajustar doses com base em resposta clínica e nivel sérico. Considerar titulação mais lenta',
    'MONITORAR NÍVEIS SÉRICOS — Antiepiléticos com interação farmacocinética; ajustar doses conforme nível',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('fenitoína', 'gabapentina', InteractionSeverity.moderate,
    'Combinação de dois antiepiléticos com potencial interação farmacocinética (indução/inibição enzimática) ou farmacodinâmica (sedação aditiva)',
    'Alteração nos níveis séricos de um ou ambos os fármacos, sedação excessiva, tontura, ataxia',
    'Monitorar níveis séricos dos antiepiléticos envolvidos. Ajustar doses com base em resposta clínica e nivel sérico. Considerar titulação mais lenta',
    'MONITORAR NÍVEIS SÉRICOS — Antiepiléticos com interação farmacocinética; ajustar doses conforme nível',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('fenitoína', 'topiramato', InteractionSeverity.moderate,
    'Combinação de dois antiepiléticos com potencial interação farmacocinética (indução/inibição enzimática) ou farmacodinâmica (sedação aditiva)',
    'Alteração nos níveis séricos de um ou ambos os fármacos, sedação excessiva, tontura, ataxia',
    'Monitorar níveis séricos dos antiepiléticos envolvidos. Ajustar doses com base em resposta clínica e nivel sérico. Considerar titulação mais lenta',
    'MONITORAR NÍVEIS SÉRICOS — Antiepiléticos com interação farmacocinética; ajustar doses conforme nível',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('fenitoína', 'perampanel', InteractionSeverity.major,
    'Fortes indutores de CYP3A4 reduzem exposição ao perampanel em 50-67%, comprometendo eficácia antiepiléptica',
    'Falha terapéutica do perampanel com escape de convulsiones',
    'Dobrar a dose de perampanel quando combinado com indutor forte. Titulação mais rápida permitida. Monitorar eficácia clínica',
    'PERAMPANEL REDUZIDO 50-67% — Indutores de CYP3A4; dobrar dose de perampanel',
    EvidenceLevel.established,
    {RiskType.plasmaLevel},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('fenobarbital', 'topiramato', InteractionSeverity.moderate,
    'Combinação de dois antiepiléticos com potencial interação farmacocinética (indução/inibição enzimática) ou farmacodinâmica (sedação aditiva)',
    'Alteração nos níveis séricos de um ou ambos os fármacos, sedação excessiva, tontura, ataxia',
    'Monitorar níveis séricos dos antiepiléticos envolvidos. Ajustar doses com base em resposta clínica e nivel sérico. Considerar titulação mais lenta',
    'MONITORAR NÍVEIS SÉRICOS — Antiepiléticos com interação farmacocinética; ajustar doses conforme nível',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('fenobarbital', 'perampanel', InteractionSeverity.major,
    'Fortes indutores de CYP3A4 reduzem exposição ao perampanel em 50-67%, comprometendo eficácia antiepiléptica',
    'Falha terapéutica do perampanel com escape de convulsiones',
    'Dobrar a dose de perampanel quando combinado com indutor forte. Titulação mais rápida permitida. Monitorar eficácia clínica',
    'PERAMPANEL REDUZIDO 50-67% — Indutores de CYP3A4; dobrar dose de perampanel',
    EvidenceLevel.established,
    {RiskType.plasmaLevel},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('fenobarbital', 'gabapentina', InteractionSeverity.moderate,
    'Combinação de dois antiepiléticos com potencial interação farmacocinética (indução/inibição enzimática) ou farmacodinâmica (sedação aditiva)',
    'Alteração nos níveis séricos de um ou ambos os fármacos, sedação excessiva, tontura, ataxia',
    'Monitorar níveis séricos dos antiepiléticos envolvidos. Ajustar doses com base em resposta clínica e nivel sérico. Considerar titulação mais lenta',
    'MONITORAR NÍVEIS SÉRICOS — Antiepiléticos com interação farmacocinética; ajustar doses conforme nível',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('lamotrigina', 'topiramato', InteractionSeverity.moderate,
    'Combinação de dois antiepiléticos com potencial interação farmacocinética (indução/inibição enzimática) ou farmacodinâmica (sedação aditiva)',
    'Alteração nos níveis séricos de um ou ambos os fármacos, sedação excessiva, tontura, ataxia',
    'Monitorar níveis séricos dos antiepiléticos envolvidos. Ajustar doses com base em resposta clínica e nivel sérico. Considerar titulação mais lenta',
    'MONITORAR NÍVEIS SÉRICOS — Antiepiléticos com interação farmacocinética; ajustar doses conforme nível',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('lamotrigina', 'perampanel', InteractionSeverity.moderate,
    'Combinação de dois antiepiléticos com potencial interação farmacocinética (indução/inibição enzimática) ou farmacodinâmica (sedação aditiva)',
    'Alteração nos níveis séricos de um ou ambos os fármacos, sedação excessiva, tontura, ataxia',
    'Monitorar níveis séricos dos antiepiléticos envolvidos. Ajustar doses com base em resposta clínica e nivel sérico. Considerar titulação mais lenta',
    'MONITORAR NÍVEIS SÉRICOS — Antiepiléticos com interação farmacocinética; ajustar doses conforme nível',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('perampanel', 'topiramato', InteractionSeverity.moderate,
    'Combinação de dois antiepiléticos com potencial interação farmacocinética (indução/inibição enzimática) ou farmacodinâmica (sedação aditiva)',
    'Alteração nos níveis séricos de um ou ambos os fármacos, sedação excessiva, tontura, ataxia',
    'Monitorar níveis séricos dos antiepiléticos envolvidos. Ajustar doses com base em resposta clínica e nivel sérico. Considerar titulação mais lenta',
    'MONITORAR NÍVEIS SÉRICOS — Antiepiléticos com interação farmacocinética; ajustar doses conforme nível',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('gabapentina', 'valproato', InteractionSeverity.moderate,
    'Combinação de dois antiepiléticos com potencial interação farmacocinética (indução/inibição enzimática) ou farmacodinâmica (sedação aditiva)',
    'Alteração nos níveis séricos de um ou ambos os fármacos, sedação excessiva, tontura, ataxia',
    'Monitorar níveis séricos dos antiepiléticos envolvidos. Ajustar doses com base em resposta clínica e nivel sérico. Considerar titulação mais lenta',
    'MONITORAR NÍVEIS SÉRICOS — Antiepiléticos com interação farmacocinética; ajustar doses conforme nível',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('gabapentina', 'lamotrigina', InteractionSeverity.moderate,
    'Combinação de dois antiepiléticos com potencial interação farmacocinética (indução/inibição enzimática) ou farmacodinâmica (sedação aditiva)',
    'Alteração nos níveis séricos de um ou ambos os fármacos, sedação excessiva, tontura, ataxia',
    'Monitorar níveis séricos dos antiepiléticos envolvidos. Ajustar doses com base em resposta clínica e nivel sérico. Considerar titulação mais lenta',
    'MONITORAR NÍVEIS SÉRICOS — Antiepiléticos com interação farmacocinética; ajustar doses conforme nível',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('gabapentina', 'perampanel', InteractionSeverity.moderate,
    'Combinação de dois antiepiléticos com potencial interação farmacocinética (indução/inibição enzimática) ou farmacodinâmica (sedação aditiva)',
    'Alteração nos níveis séricos de um ou ambos os fármacos, sedação excessiva, tontura, ataxia',
    'Monitorar níveis séricos dos antiepiléticos envolvidos. Ajustar doses com base em resposta clínica e nivel sérico. Considerar titulação mais lenta',
    'MONITORAR NÍVEIS SÉRICOS — Antiepiléticos com interação farmacocinética; ajustar doses conforme nível',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('fluoxetina', 'isrs', InteractionSeverity.contraindicated,
    'Dois SSRIs: inibição aditiva do transportador SERT com acúmulo excessivo de serotonina sináptica',
    'Síndrome serotoninérgica, hiperreflexia, mioclonias, agitação, hipertermia',
    'CONTRAINDICADO. Usar apenas um SSRI. Em troca de SSRI, respeitar washout adecuado (5 meias-vidas)',
    'CONTRAINDICADO — Dois SSRIs: síndrome serotoninérgica; usar apenas um SSRI',
    EvidenceLevel.established,
    {RiskType.serotonin},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('fluoxetina', 'mirtazapina', InteractionSeverity.moderate,
    'Dois antidepressivos com mecanismos serotoninérgicos sobrepostos ou interações farmacocinéticas via CYP2D6',
    'Síndrome serotoninérgica leve a moderada, sedação excessiva, alteração de níveis séricos',
    'Monitorar sinais de síndrome serotoninérgica. Iniciar segundo antidepressivo em dose baixa. Preferir combinações com menor sobreposição serotoninérgica',
    'SÍNDROME SEROTONINÉRGICA — Dois antidepressivos; iniciar em dose baixa; monitorar sintomas',
    EvidenceLevel.probable,
    {RiskType.serotonin},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('fluoxetina', 'imao reversivel', InteractionSeverity.contraindicated,
    'IMAO inibe degradação de serotonina/noradrenalina. Antidepressivo adiciona liberação ou inibição de recaptação: acúmulo massivo de serotonina',
    'Síndrome serotoninérgica: agitação, hipertermia, mioclonias, rigidez, convulsiones, colapso cardiovascular, morte',
    'CONTRAINDICAÇÃO ABSOLUTA. Respeitar washout de 14 dias entre IMAO e qualquer antidepressivo (21 dias para fluoxetina). Tratamento de emergência: ciproheptadina + suporte',
    'CONTRAINDICADO — Síndrome serotoninérgica letal; washout 14 dias (21 dias para fluoxetina)',
    EvidenceLevel.established,
    {RiskType.serotonin},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('imao', 'imao reversivel', InteractionSeverity.moderate,
    'Dois antidepressivos com mecanismos serotoninérgicos sobrepostos ou interações farmacocinéticas via CYP2D6',
    'Síndrome serotoninérgica leve a moderada, sedação excessiva, alteração de níveis séricos',
    'Monitorar sinais de síndrome serotoninérgica. Iniciar segundo antidepressivo em dose baixa. Preferir combinações com menor sobreposição serotoninérgica',
    'SÍNDROME SEROTONINÉRGICA — Dois antidepressivos; iniciar em dose baixa; monitorar sintomas',
    EvidenceLevel.probable,
    {RiskType.serotonin},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('imao reversivel', 'mirtazapina', InteractionSeverity.contraindicated,
    'IMAO inibe degradação de serotonina/noradrenalina. Antidepressivo adiciona liberação ou inibição de recaptação: acúmulo massivo de serotonina',
    'Síndrome serotoninérgica: agitação, hipertermia, mioclonias, rigidez, convulsiones, colapso cardiovascular, morte',
    'CONTRAINDICAÇÃO ABSOLUTA. Respeitar washout de 14 dias entre IMAO e qualquer antidepressivo (21 dias para fluoxetina). Tratamento de emergência: ciproheptadina + suporte',
    'CONTRAINDICADO — Síndrome serotoninérgica letal; washout 14 dias (21 dias para fluoxetina)',
    EvidenceLevel.established,
    {RiskType.serotonin},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('aripiprazol', 'haloperidol', InteractionSeverity.major,
    'Haloperidol prolonga QTc significativamente. Combinação com outro antipsicótico prolonga QTc de forma aditiva',
    'Torsades de Pointes, fibrilación ventricular, muerte súbita. Sedação excessiva',
    'Monitorar QTc antes e durante o tratamento. Evitar combinación se QTc > 450ms. Preferir monoterapia. Corrigir electrolitos (K+, Mg2+)',
    'TORSADE DE POINTES — Haloperidol prolonga QTc; monitorar ECG; evitar se QTc > 450ms',
    EvidenceLevel.established,
    {RiskType.qtProlongation},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('aripiprazol', 'olanzapina', InteractionSeverity.moderate,
    'Dois antipsicóticos: bloqueio aditivo de receptores D2, histaminérgicos (H1) e muscarínicos. Sedação e efeitos extrapiramidais aditivos',
    'Sedação excessiva, síndrome extrapiramidal, prolongamento QTc, síndrome neuroléptica maligna (raro)',
    'Preferir monoterapia antipsicótica. Se combinação necessária (p. ex., estabilização aguda), usar menor dose possível e monitorar ECG',
    'SEDAÇÃO + QTc — Dois antipsicóticos; preferir monoterapia; monitorar ECG e sintomas extrapiramidais',
    EvidenceLevel.probable,
    {RiskType.qtProlongation},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('aripiprazol', 'quetiapina', InteractionSeverity.moderate,
    'Dois antipsicóticos: bloqueio aditivo de receptores D2, histaminérgicos (H1) e muscarínicos. Sedação e efeitos extrapiramidais aditivos',
    'Sedação excessiva, síndrome extrapiramidal, prolongamento QTc, síndrome neuroléptica maligna (raro)',
    'Preferir monoterapia antipsicótica. Se combinação necessária (p. ex., estabilização aguda), usar menor dose possível e monitorar ECG',
    'SEDAÇÃO + QTc — Dois antipsicóticos; preferir monoterapia; monitorar ECG e sintomas extrapiramidais',
    EvidenceLevel.probable,
    {RiskType.qtProlongation},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('fentanila', 'morfina', InteractionSeverity.major,
    'Dois opioides agonistas de receptor μ: depressão do SNC e do centro respiratório bulbar de forma aditiva',
    'Depressão respiratória grave, apneia, sedação profunda, coma, óbito',
    'EVITAR combinação de dois opioides plenos sem indicação específica. Se necesario (dor refratária), monitorar SpO₂ e ter naloxona disponible. Titular lentamente',
    'APNEIA — Dois opioides agonistas μ; depresión respiratoria grave; ter naloxona disponible',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('fentanila', 'opioide', InteractionSeverity.major,
    'Dois opioides agonistas de receptor μ: depressão do SNC e do centro respiratório bulbar de forma aditiva',
    'Depressão respiratória grave, apneia, sedação profunda, coma, óbito',
    'EVITAR combinação de dois opioides plenos sem indicação específica. Se necesario (dor refratária), monitorar SpO₂ e ter naloxona disponible. Titular lentamente',
    'APNEIA — Dois opioides agonistas μ; depresión respiratoria grave; ter naloxona disponible',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('fentanila', 'tramadol', InteractionSeverity.major,
    'Dois opioides agonistas de receptor μ: depressão do SNC e do centro respiratório bulbar de forma aditiva',
    'Depressão respiratória grave, apneia, sedação profunda, coma, óbito',
    'EVITAR combinação de dois opioides plenos sem indicação específica. Se necesario (dor refratária), monitorar SpO₂ e ter naloxona disponible. Titular lentamente',
    'APNEIA — Dois opioides agonistas μ; depresión respiratoria grave; ter naloxona disponible',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('fentanila', 'metadona', InteractionSeverity.major,
    'Metadona tem meia-vida prolongada (24-36h) e prolonga QTc por bloqueio IKr. Combinação com outro opioide: depresión respiratoria e QTc aditivos',
    'Depressão respiratória grave/fatal, Torsades de Pointes, apneia',
    'EVITAR combinação. Se necesario em cuidados paliativos, monitorar SpO₂ continuamente, ECG (QTc) e ter naloxona disponible. Titular doses muito lentamente',
    'DEPRESSÃO RESP. + QTc — Metadona com opioide; monitorar SpO₂ e ECG; ter naloxona',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.qtProlongation},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('metadona', 'morfina', InteractionSeverity.major,
    'Metadona tem meia-vida prolongada (24-36h) e prolonga QTc por bloqueio IKr. Combinação com outro opioide: depresión respiratoria e QTc aditivos',
    'Depressão respiratória grave/fatal, Torsades de Pointes, apneia',
    'EVITAR combinação. Se necesario em cuidados paliativos, monitorar SpO₂ continuamente, ECG (QTc) e ter naloxona disponible. Titular doses muito lentamente',
    'DEPRESSÃO RESP. + QTc — Metadona com opioide; monitorar SpO₂ e ECG; ter naloxona',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.qtProlongation},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('metadona', 'opioide', InteractionSeverity.major,
    'Metadona tem meia-vida prolongada (24-36h) e prolonga QTc por bloqueio IKr. Combinação com outro opioide: depresión respiratoria e QTc aditivos',
    'Depressão respiratória grave/fatal, Torsades de Pointes, apneia',
    'EVITAR combinação. Se necesario em cuidados paliativos, monitorar SpO₂ continuamente, ECG (QTc) e ter naloxona disponible. Titular doses muito lentamente',
    'DEPRESSÃO RESP. + QTc — Metadona com opioide; monitorar SpO₂ e ECG; ter naloxona',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.qtProlongation},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('metadona', 'tramadol', InteractionSeverity.major,
    'Metadona tem meia-vida prolongada (24-36h) e prolonga QTc por bloqueio IKr. Combinação com outro opioide: depresión respiratoria e QTc aditivos',
    'Depressão respiratória grave/fatal, Torsades de Pointes, apneia',
    'EVITAR combinação. Se necesario em cuidados paliativos, monitorar SpO₂ continuamente, ECG (QTc) e ter naloxona disponible. Titular doses muito lentamente',
    'DEPRESSÃO RESP. + QTc — Metadona com opioide; monitorar SpO₂ e ECG; ter naloxona',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.qtProlongation},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('morfina', 'opioide', InteractionSeverity.major,
    'Dois opioides agonistas de receptor μ: depressão do SNC e do centro respiratório bulbar de forma aditiva',
    'Depressão respiratória grave, apneia, sedação profunda, coma, óbito',
    'EVITAR combinação de dois opioides plenos sem indicação específica. Se necesario (dor refratária), monitorar SpO₂ e ter naloxona disponible. Titular lentamente',
    'APNEIA — Dois opioides agonistas μ; depresión respiratoria grave; ter naloxona disponible',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('opioide', 'tramadol', InteractionSeverity.major,
    'Dois opioides agonistas de receptor μ: depressão do SNC e do centro respiratório bulbar de forma aditiva',
    'Depressão respiratória grave, apneia, sedação profunda, coma, óbito',
    'EVITAR combinação de dois opioides plenos sem indicação específica. Se necesario (dor refratária), monitorar SpO₂ e ter naloxona disponible. Titular lentamente',
    'APNEIA — Dois opioides agonistas μ; depresión respiratoria grave; ter naloxona disponible',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('benzodiazepínico', 'midazolam', InteractionSeverity.major,
    'Midazolam é um benzodiazepínico: potenciação aditiva do receptor GABA-A com depressão do SNC e respiratório',
    'Sedación excesiva, depresión respiratoria, amnésia prolongada, hipotensão',
    'EVITAR combinação de dois benzodiazepínicos. Se necesario em sedação procedural, reduzir dose de ambos em 50% e monitorar SpO₂. Ter flumazenil disponible',
    'DEPRESSÃO RESP. — Dois benzodiazepínicos; reduzir doses; monitorar SpO₂; ter flumazenil',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('glibenclamida', 'insulina', InteractionSeverity.moderate,
    'Insulina exógena e sulfonilureias/glibenclamida (estimulantes de secreção endógena de insulina) têm efeito hipoglucemiante aditivo',
    'Hipoglucemia grave y prolongada, especialmente com glibenclamida (meia-vida longa)',
    'Monitorar glucemia 4x/dia. Reduzir dose da sulfonilureia ao iniciar insulina. Considerar substituição por metformina ou iDPP4 para minimizar hipoglucemia',
    'HIPOGLICEMIA GRAVE — Insulina + sulfonilureia; glibenclamida tem risco maior; monitorar glucemia',
    EvidenceLevel.established,
    {RiskType.other},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('glibenclamida', 'sulfonilureia', InteractionSeverity.minor,
    'Dois antidiabéticos com mecanismos diferentes: potencial efeito hipoglucemiante aditivo ou sinérgico',
    'Hipoglucemia leve a moderada. Desconforto GI aditivo (especialmente metformina + outros)',
    'Monitorar glucemia. Ajustar doses conforme resposta. Orientar o paciente sobre sintomas de hipoglucemia',
    'HIPOGLICEMIA LEVE — Monitorar glucemia ao combinar antidiabéticos; ajustar doses',
    EvidenceLevel.established,
    {RiskType.other},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('insulina', 'metformina', InteractionSeverity.minor,
    'Dois antidiabéticos com mecanismos diferentes: potencial efeito hipoglucemiante aditivo ou sinérgico',
    'Hipoglucemia leve a moderada. Desconforto GI aditivo (especialmente metformina + outros)',
    'Monitorar glucemia. Ajustar doses conforme resposta. Orientar o paciente sobre sintomas de hipoglucemia',
    'HIPOGLICEMIA LEVE — Monitorar glucemia ao combinar antidiabéticos; ajustar doses',
    EvidenceLevel.established,
    {RiskType.other},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('glibenclamida', 'metformina', InteractionSeverity.minor,
    'Dois antidiabéticos com mecanismos diferentes: potencial efeito hipoglucemiante aditivo ou sinérgico',
    'Hipoglucemia leve a moderada. Desconforto GI aditivo (especialmente metformina + outros)',
    'Monitorar glucemia. Ajustar doses conforme resposta. Orientar o paciente sobre sintomas de hipoglucemia',
    'HIPOGLICEMIA LEVE — Monitorar glucemia ao combinar antidiabéticos; ajustar doses',
    EvidenceLevel.established,
    {RiskType.other},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('canagliflozina', 'insulina', InteractionSeverity.moderate,
    'iSGLT2 promovem glicosúria e reduzem glucemia independentemente. Insulina reduz glucemia por captação periférica. Efeito hipoglucemiante aditivo',
    'Hipoglucemia grave, cetoacidose diabética euglicêmica (mesmo com glucemia normal)',
    'Reduzir dose de insulina basal em 10-20% ao iniciar iSGLT2. Monitorar glucemia. Orientar sobre cetoacidose euglicêmica: checar cetonas se sintomas mesmo com glucemia normal',
    'HIPOGLICEMIA + CETOACIDOSE EUGLICÊMICA — Reduzir insulina 10-20%; monitorar cetonas',
    EvidenceLevel.established,
    {RiskType.other},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('canagliflozina', 'sulfonilureia', InteractionSeverity.moderate,
    'Gliflozinas (iSGLT2) causam glicosúria independente de insulina. Sulfonilureias/glibenclamida aumentam secreção de insulina. Efeito hipoglucemiante aditivo',
    'Hipoglucemia moderada a grave. Cetoacidose diabética euglicêmica (rara com iSGLT2)',
    'Monitorar glucemia frecuentemente. Considerar redução da dose de sulfonilureia em 25-50% ao adicionar iSGLT2. Orientar paciente sobre sintomas de hipoglucemia',
    'HIPOGLICEMIA — iSGLT2 + sulfonilureia; reduzir dose da sulfonilureia 25-50%; monitorar glucemia',
    EvidenceLevel.established,
    {RiskType.other},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('canagliflozina', 'glibenclamida', InteractionSeverity.moderate,
    'Gliflozinas (iSGLT2) causam glicosúria independente de insulina. Sulfonilureias/glibenclamida aumentam secreção de insulina. Efeito hipoglucemiante aditivo',
    'Hipoglucemia moderada a grave. Cetoacidose diabética euglicêmica (rara com iSGLT2)',
    'Monitorar glucemia frecuentemente. Considerar redução da dose de sulfonilureia em 25-50% ao adicionar iSGLT2. Orientar paciente sobre sintomas de hipoglucemia',
    'HIPOGLICEMIA — iSGLT2 + sulfonilureia; reduzir dose da sulfonilureia 25-50%; monitorar glucemia',
    EvidenceLevel.established,
    {RiskType.other},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('canagliflozina', 'metformina', InteractionSeverity.minor,
    'Dois antidiabéticos com mecanismos diferentes: potencial efeito hipoglucemiante aditivo ou sinérgico',
    'Hipoglucemia leve a moderada. Desconforto GI aditivo (especialmente metformina + outros)',
    'Monitorar glucemia. Ajustar doses conforme resposta. Orientar o paciente sobre sintomas de hipoglucemia',
    'HIPOGLICEMIA LEVE — Monitorar glucemia ao combinar antidiabéticos; ajustar doses',
    EvidenceLevel.established,
    {RiskType.other},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('dapagliflozina', 'sulfonilureia', InteractionSeverity.moderate,
    'Gliflozinas (iSGLT2) causam glicosúria independente de insulina. Sulfonilureias/glibenclamida aumentam secreção de insulina. Efeito hipoglucemiante aditivo',
    'Hipoglucemia moderada a grave. Cetoacidose diabética euglicêmica (rara com iSGLT2)',
    'Monitorar glucemia frecuentemente. Considerar redução da dose de sulfonilureia em 25-50% ao adicionar iSGLT2. Orientar paciente sobre sintomas de hipoglucemia',
    'HIPOGLICEMIA — iSGLT2 + sulfonilureia; reduzir dose da sulfonilureia 25-50%; monitorar glucemia',
    EvidenceLevel.established,
    {RiskType.other},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('dapagliflozina', 'glibenclamida', InteractionSeverity.moderate,
    'Gliflozinas (iSGLT2) causam glicosúria independente de insulina. Sulfonilureias/glibenclamida aumentam secreção de insulina. Efeito hipoglucemiante aditivo',
    'Hipoglucemia moderada a grave. Cetoacidose diabética euglicêmica (rara com iSGLT2)',
    'Monitorar glucemia frecuentemente. Considerar redução da dose de sulfonilureia em 25-50% ao adicionar iSGLT2. Orientar paciente sobre sintomas de hipoglucemia',
    'HIPOGLICEMIA — iSGLT2 + sulfonilureia; reduzir dose da sulfonilureia 25-50%; monitorar glucemia',
    EvidenceLevel.established,
    {RiskType.other},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('dapagliflozina', 'metformina', InteractionSeverity.minor,
    'Dois antidiabéticos com mecanismos diferentes: potencial efeito hipoglucemiante aditivo ou sinérgico',
    'Hipoglucemia leve a moderada. Desconforto GI aditivo (especialmente metformina + outros)',
    'Monitorar glucemia. Ajustar doses conforme resposta. Orientar o paciente sobre sintomas de hipoglucemia',
    'HIPOGLICEMIA LEVE — Monitorar glucemia ao combinar antidiabéticos; ajustar doses',
    EvidenceLevel.established,
    {RiskType.other},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('azatioprina', 'metotrexato', InteractionSeverity.major,
    'Metotrexato e azatioprina têm efeitos mielossupressores aditivos. Metotrexato inibe DHFR; azatioprina interfere na síntese de purinas',
    'Mielossupressão grave: pancitopenia, infecções oportunistas, mucosite, hepatotoxicidad aditiva',
    'EVITAR combinação. Se necesario em doenças graves, monitorar hemograma semanal, função hepática e renal. Suplementar ácido fólico',
    'MIELOSSUPRESSÃO GRAVE — Metotrexato + azatioprina; hemograma semanal; ácido fólico obligatorio',
    EvidenceLevel.established,
    {RiskType.other},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('azatioprina', 'corticosteroide sistemico', InteractionSeverity.moderate,
    'Dois imunossupressores: imunossupressão aditiva com risco aumentado de infecções oportunistas e malignidades linfoides',
    'Infecções oportunistas graves (CMV, PCP, fungos), linfoma, hepatotoxicidad, nefrotoxicidad',
    'Monitorar hemograma, função hepática e renal mensalmente. Profilaxia anti-infecciosa conforme protocolo (SMX-TMP para PCP). Vacinas inativadas atualizadas',
    'IMUNOSSUPRESSÃO ADITIVA — Monitorar hemograma; profilaxia anti-infecciosa; evitar vacinas vivas',
    EvidenceLevel.established,
    {RiskType.other},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('ciclosporina', 'metotrexato', InteractionSeverity.moderate,
    'Dois imunossupressores: imunossupressão aditiva com risco aumentado de infecções oportunistas e malignidades linfoides',
    'Infecções oportunistas graves (CMV, PCP, fungos), linfoma, hepatotoxicidad, nefrotoxicidad',
    'Monitorar hemograma, função hepática e renal mensalmente. Profilaxia anti-infecciosa conforme protocolo (SMX-TMP para PCP). Vacinas inativadas atualizadas',
    'IMUNOSSUPRESSÃO ADITIVA — Monitorar hemograma; profilaxia anti-infecciosa; evitar vacinas vivas',
    EvidenceLevel.established,
    {RiskType.other},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('corticosteroide sistemico', 'metotrexato', InteractionSeverity.moderate,
    'Dois imunossupressores: imunossupressão aditiva com risco aumentado de infecções oportunistas e malignidades linfoides',
    'Infecções oportunistas graves (CMV, PCP, fungos), linfoma, hepatotoxicidad, nefrotoxicidad',
    'Monitorar hemograma, função hepática e renal mensalmente. Profilaxia anti-infecciosa conforme protocolo (SMX-TMP para PCP). Vacinas inativadas atualizadas',
    'IMUNOSSUPRESSÃO ADITIVA — Monitorar hemograma; profilaxia anti-infecciosa; evitar vacinas vivas',
    EvidenceLevel.established,
    {RiskType.other},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('metotrexato', 'tacrolimo', InteractionSeverity.moderate,
    'Dois imunossupressores: imunossupressão aditiva com risco aumentado de infecções oportunistas e malignidades linfoides',
    'Infecções oportunistas graves (CMV, PCP, fungos), linfoma, hepatotoxicidad, nefrotoxicidad',
    'Monitorar hemograma, função hepática e renal mensalmente. Profilaxia anti-infecciosa conforme protocolo (SMX-TMP para PCP). Vacinas inativadas atualizadas',
    'IMUNOSSUPRESSÃO ADITIVA — Monitorar hemograma; profilaxia anti-infecciosa; evitar vacinas vivas',
    EvidenceLevel.established,
    {RiskType.other},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('acetazolamida', 'furosemida', InteractionSeverity.moderate,
    'Dois diuréticos com mecanismos distintos: efeitos diuréticos e natriuréticos aditivos, depleção de volume aumentada',
    'Hipotensão ortostática, depleção de volume, IRA pré-renal, distúrbios eletrolíticos',
    'Monitorar PA, función renal e electrolitos regularmente. Iniciar combinação em doses baixas. Orientar hidratação adecuada',
    'DEPLEÇÃO DE VOLUME — Dois diuréticos; monitorar PA, creatinina e electrolitos',
    EvidenceLevel.probable,
    {RiskType.nephrotoxicity},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('acetazolamida', 'hidroclorotiazida', InteractionSeverity.moderate,
    'Dois diuréticos com mecanismos distintos: efeitos diuréticos e natriuréticos aditivos, depleção de volume aumentada',
    'Hipotensão ortostática, depleção de volume, IRA pré-renal, distúrbios eletrolíticos',
    'Monitorar PA, función renal e electrolitos regularmente. Iniciar combinação em doses baixas. Orientar hidratação adecuada',
    'DEPLEÇÃO DE VOLUME — Dois diuréticos; monitorar PA, creatinina e electrolitos',
    EvidenceLevel.probable,
    {RiskType.nephrotoxicity},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('acetazolamida', 'espironolactona', InteractionSeverity.moderate,
    'Diurético poupador de K+ combinado com diurético perdedor de K+: efeitos opostos no potássio, mas depleção de volume e hipotensão aditivos',
    'Hipotensão, depleção de volume, risco de IRA. Potassemia imprevisível (normo, hipo ou hiperpotasemia)',
    'Monitorar K+ sérico, función renal e PA regularmente. Titular doses para manter K+ 3,5-5 mEq/L. Monitorar sinais de depleção de volume',
    'POTASSEMIA IMPREVISÍVEL + HIPOTENSÃO — Monitorar K+, creatinina e PA; titular doses',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('acetazolamida', 'eplerenona', InteractionSeverity.moderate,
    'Diurético poupador de K+ combinado com diurético perdedor de K+: efeitos opostos no potássio, mas depleção de volume e hipotensão aditivos',
    'Hipotensão, depleção de volume, risco de IRA. Potassemia imprevisível (normo, hipo ou hiperpotasemia)',
    'Monitorar K+ sérico, función renal e PA regularmente. Titular doses para manter K+ 3,5-5 mEq/L. Monitorar sinais de depleção de volume',
    'POTASSEMIA IMPREVISÍVEL + HIPOTENSÃO — Monitorar K+, creatinina e PA; titular doses',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('acetazolamida', 'finerenona', InteractionSeverity.moderate,
    'Diurético poupador de K+ combinado com diurético perdedor de K+: efeitos opostos no potássio, mas depleção de volume e hipotensão aditivos',
    'Hipotensão, depleção de volume, risco de IRA. Potassemia imprevisível (normo, hipo ou hiperpotasemia)',
    'Monitorar K+ sérico, función renal e PA regularmente. Titular doses para manter K+ 3,5-5 mEq/L. Monitorar sinais de depleção de volume',
    'POTASSEMIA IMPREVISÍVEL + HIPOTENSÃO — Monitorar K+, creatinina e PA; titular doses',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('eplerenona', 'espironolactona', InteractionSeverity.major,
    'Dois diuréticos poupadores de potássio: retenção aditiva de K+ por bloqueio de aldosterona/receptores de mineralocorticóide',
    'Hipercalemia grave (K+ > 6 mEq/L), arritmias cardíacas, paro cardíaco em asistolia',
    'EVITAR combinação de dois poupadores de K+. Se necesario, monitorar K+ sérico cada 3-7 días. Restrição de K+ na dieta. Suspender se K+ > 5,5 mEq/L',
    'HIPERCALEMIA GRAVE — Dois poupadores de K+; monitorar K+ sérico; suspender se K+ > 5,5 mEq/L',
    EvidenceLevel.established,
    {RiskType.arrhythmia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('eplerenona', 'finerenona', InteractionSeverity.major,
    'Dois diuréticos poupadores de potássio: retenção aditiva de K+ por bloqueio de aldosterona/receptores de mineralocorticóide',
    'Hipercalemia grave (K+ > 6 mEq/L), arritmias cardíacas, paro cardíaco em asistolia',
    'EVITAR combinação de dois poupadores de K+. Se necesario, monitorar K+ sérico cada 3-7 días. Restrição de K+ na dieta. Suspender se K+ > 5,5 mEq/L',
    'HIPERCALEMIA GRAVE — Dois poupadores de K+; monitorar K+ sérico; suspender se K+ > 5,5 mEq/L',
    EvidenceLevel.established,
    {RiskType.arrhythmia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('eplerenona', 'furosemida', InteractionSeverity.moderate,
    'Diurético poupador de K+ combinado com diurético perdedor de K+: efeitos opostos no potássio, mas depleção de volume e hipotensão aditivos',
    'Hipotensão, depleção de volume, risco de IRA. Potassemia imprevisível (normo, hipo ou hiperpotasemia)',
    'Monitorar K+ sérico, función renal e PA regularmente. Titular doses para manter K+ 3,5-5 mEq/L. Monitorar sinais de depleção de volume',
    'POTASSEMIA IMPREVISÍVEL + HIPOTENSÃO — Monitorar K+, creatinina e PA; titular doses',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('eplerenona', 'hidroclorotiazida', InteractionSeverity.moderate,
    'Diurético poupador de K+ combinado com diurético perdedor de K+: efeitos opostos no potássio, mas depleção de volume e hipotensão aditivos',
    'Hipotensão, depleção de volume, risco de IRA. Potassemia imprevisível (normo, hipo ou hiperpotasemia)',
    'Monitorar K+ sérico, función renal e PA regularmente. Titular doses para manter K+ 3,5-5 mEq/L. Monitorar sinais de depleção de volume',
    'POTASSEMIA IMPREVISÍVEL + HIPOTENSÃO — Monitorar K+, creatinina e PA; titular doses',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('finerenona', 'furosemida', InteractionSeverity.moderate,
    'Diurético poupador de K+ combinado com diurético perdedor de K+: efeitos opostos no potássio, mas depleção de volume e hipotensão aditivos',
    'Hipotensão, depleção de volume, risco de IRA. Potassemia imprevisível (normo, hipo ou hiperpotasemia)',
    'Monitorar K+ sérico, función renal e PA regularmente. Titular doses para manter K+ 3,5-5 mEq/L. Monitorar sinais de depleção de volume',
    'POTASSEMIA IMPREVISÍVEL + HIPOTENSÃO — Monitorar K+, creatinina e PA; titular doses',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('finerenona', 'hidroclorotiazida', InteractionSeverity.moderate,
    'Diurético poupador de K+ combinado com diurético perdedor de K+: efeitos opostos no potássio, mas depleção de volume e hipotensão aditivos',
    'Hipotensão, depleção de volume, risco de IRA. Potassemia imprevisível (normo, hipo ou hiperpotasemia)',
    'Monitorar K+ sérico, función renal e PA regularmente. Titular doses para manter K+ 3,5-5 mEq/L. Monitorar sinais de depleção de volume',
    'POTASSEMIA IMPREVISÍVEL + HIPOTENSÃO — Monitorar K+, creatinina e PA; titular doses',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('atorvastatina', 'sinvastatina', InteractionSeverity.contraindicated,
    'Duas estatinas: miopatia por inhibición aditiva de HMG-CoA redutase e depleção de coenzima Q10 muscular',
    'Miopatia grave, rabdomiólisis, IRA por mioglobinúria, morte',
    'CONTRAINDICADO. Usar apenas uma estatina. Se necesario potencializar efeito, aumentar dose de uma estatina ou adicionar ezetimiba',
    'CONTRAINDICADO — Rabdomiólise por duas estatinas; usar apenas uma; adicionar ezetimiba se necesario',
    EvidenceLevel.established,
    {RiskType.other},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('atorvastatina', 'rosuvastatina', InteractionSeverity.contraindicated,
    'Duas estatinas: miopatia por inhibición aditiva de HMG-CoA redutase e depleção de coenzima Q10 muscular',
    'Miopatia grave, rabdomiólisis, IRA por mioglobinúria, morte',
    'CONTRAINDICADO. Usar apenas uma estatina. Se necesario potencializar efeito, aumentar dose de uma estatina ou adicionar ezetimiba',
    'CONTRAINDICADO — Rabdomiólise por duas estatinas; usar apenas uma; adicionar ezetimiba se necesario',
    EvidenceLevel.established,
    {RiskType.other},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('atorvastatina', 'estatina', InteractionSeverity.contraindicated,
    'Duas estatinas: miopatia por inhibición aditiva de HMG-CoA redutase e depleção de coenzima Q10 muscular',
    'Miopatia grave, rabdomiólisis, IRA por mioglobinúria, morte',
    'CONTRAINDICADO. Usar apenas uma estatina. Se necesario potencializar efeito, aumentar dose de uma estatina ou adicionar ezetimiba',
    'CONTRAINDICADO — Rabdomiólise por duas estatinas; usar apenas uma; adicionar ezetimiba se necesario',
    EvidenceLevel.established,
    {RiskType.other},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('estatina', 'sinvastatina', InteractionSeverity.contraindicated,
    'Duas estatinas: miopatia por inhibición aditiva de HMG-CoA redutase e depleção de coenzima Q10 muscular',
    'Miopatia grave, rabdomiólisis, IRA por mioglobinúria, morte',
    'CONTRAINDICADO. Usar apenas uma estatina. Se necesario potencializar efeito, aumentar dose de uma estatina ou adicionar ezetimiba',
    'CONTRAINDICADO — Rabdomiólise por duas estatinas; usar apenas uma; adicionar ezetimiba se necesario',
    EvidenceLevel.established,
    {RiskType.other},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('estatina', 'rosuvastatina', InteractionSeverity.contraindicated,
    'Duas estatinas: miopatia por inhibición aditiva de HMG-CoA redutase e depleção de coenzima Q10 muscular',
    'Miopatia grave, rabdomiólisis, IRA por mioglobinúria, morte',
    'CONTRAINDICADO. Usar apenas uma estatina. Se necesario potencializar efeito, aumentar dose de uma estatina ou adicionar ezetimiba',
    'CONTRAINDICADO — Rabdomiólise por duas estatinas; usar apenas uma; adicionar ezetimiba se necesario',
    EvidenceLevel.established,
    {RiskType.other},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('rosuvastatina', 'sinvastatina', InteractionSeverity.contraindicated,
    'Duas estatinas: miopatia por inhibición aditiva de HMG-CoA redutase e depleção de coenzima Q10 muscular',
    'Miopatia grave, rabdomiólisis, IRA por mioglobinúria, morte',
    'CONTRAINDICADO. Usar apenas uma estatina. Se necesario potencializar efeito, aumentar dose de uma estatina ou adicionar ezetimiba',
    'CONTRAINDICADO — Rabdomiólise por duas estatinas; usar apenas uma; adicionar ezetimiba se necesario',
    EvidenceLevel.established,
    {RiskType.other},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('fenofibrato', 'gemfibrozil', InteractionSeverity.major,
    'Dois fibratos: miopatia por depleção aditiva de coenzima Q10 e interferência na beta-oxidação muscular. Gemfibrozil inibe glicuronidação de outras estatinas e fibratos',
    'Miopatia, rabdomiólisis, elevação de CPK, IRA',
    'EVITAR combinação de dois fibratos. Gemfibrozil tem maior risco de rabdomiólisis que fenofibrato. Se necesario controle lipídico adicional, adicionar ezetimiba ou niacina',
    'RABDOMIÓLISE — Dois fibratos; evitar combinação; preferir fenofibrato isolado + ezetimiba',
    EvidenceLevel.established,
    {RiskType.other},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('esomeprazol', 'omeprazol', InteractionSeverity.moderate,
    'Dois IBPs com mecanismo idêntico (inibição de H+/K+-ATPase): supressão ácida excessiva sem benefício adicional. Omeprazol/esomeprazol inibem CYP2C19',
    'Supressão ácida excessiva: deficiência de B12, hipomagnesemia, colonização por Clostridium difficile, hipergastrinemia',
    'EVITAR dois IBPs. Usar apenas o IBP mais adecuado para a indicação. Revisar necessidade de IBP regularmente (deprescrição quando possível)',
    'EVITAR DOIS IBPs — Supressão ácida excessiva; risco de B12, Mg2+ e infecção por C. difficile',
    EvidenceLevel.established,
    {RiskType.other},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('esomeprazol', 'pantoprazol', InteractionSeverity.moderate,
    'Dois IBPs com mecanismo idêntico (inibição de H+/K+-ATPase): supressão ácida excessiva sem benefício adicional. Omeprazol/esomeprazol inibem CYP2C19',
    'Supressão ácida excessiva: deficiência de B12, hipomagnesemia, colonização por Clostridium difficile, hipergastrinemia',
    'EVITAR dois IBPs. Usar apenas o IBP mais adecuado para a indicação. Revisar necessidade de IBP regularmente (deprescrição quando possível)',
    'EVITAR DOIS IBPs — Supressão ácida excessiva; risco de B12, Mg2+ e infecção por C. difficile',
    EvidenceLevel.established,
    {RiskType.other},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('omeprazol', 'pantoprazol', InteractionSeverity.moderate,
    'Dois IBPs com mecanismo idêntico (inibição de H+/K+-ATPase): supressão ácida excessiva sem benefício adicional. Omeprazol/esomeprazol inibem CYP2C19',
    'Supressão ácida excessiva: deficiência de B12, hipomagnesemia, colonização por Clostridium difficile, hipergastrinemia',
    'EVITAR dois IBPs. Usar apenas o IBP mais adecuado para a indicação. Revisar necessidade de IBP regularmente (deprescrição quando possível)',
    'EVITAR DOIS IBPs — Supressão ácida excessiva; risco de B12, Mg2+ e infecção por C. difficile',
    EvidenceLevel.established,
    {RiskType.other},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('omeprazol', 'sulfato ferroso', InteractionSeverity.minor,
    'IBPs elevam pH gástrico; antiácidos/sulfato ferroso/carbonato de cálcio dependem de ambiente ácido para absorção. IBP pode reduzir absorção de sulfato ferroso e Ca',
    'Redução de absorção de ferro, cálcio e antiácidos. Redução leve da eficácia do IBP se tomados junto',
    'Separar a administração por pelo menos 2h. Sulfato ferroso: administrar em jejum, 1h antes ou 2h após o IBP para maximizar absorção',
    'ABSORÇÃO REDUZIDA — Separar por 2h; sulfato ferroso: 1h antes ou 2h após o IBP',
    EvidenceLevel.established,
    {RiskType.other},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('esomeprazol', 'sulfato ferroso', InteractionSeverity.minor,
    'IBPs elevam pH gástrico; antiácidos/sulfato ferroso/carbonato de cálcio dependem de ambiente ácido para absorção. IBP pode reduzir absorção de sulfato ferroso e Ca',
    'Redução de absorção de ferro, cálcio e antiácidos. Redução leve da eficácia do IBP se tomados junto',
    'Separar a administração por pelo menos 2h. Sulfato ferroso: administrar em jejum, 1h antes ou 2h após o IBP para maximizar absorção',
    'ABSORÇÃO REDUZIDA — Separar por 2h; sulfato ferroso: 1h antes ou 2h após o IBP',
    EvidenceLevel.established,
    {RiskType.other},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('pantoprazol', 'sulfato ferroso', InteractionSeverity.minor,
    'IBPs elevam pH gástrico; antiácidos/sulfato ferroso/carbonato de cálcio dependem de ambiente ácido para absorção. IBP pode reduzir absorção de sulfato ferroso e Ca',
    'Redução de absorção de ferro, cálcio e antiácidos. Redução leve da eficácia do IBP se tomados junto',
    'Separar a administração por pelo menos 2h. Sulfato ferroso: administrar em jejum, 1h antes ou 2h após o IBP para maximizar absorção',
    'ABSORÇÃO REDUZIDA — Separar por 2h; sulfato ferroso: 1h antes ou 2h após o IBP',
    EvidenceLevel.established,
    {RiskType.other},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('antiácido', 'esomeprazol', InteractionSeverity.minor,
    'IBPs elevam pH gástrico; antiácidos/sulfato ferroso/carbonato de cálcio dependem de ambiente ácido para absorção. IBP pode reduzir absorção de sulfato ferroso e Ca',
    'Redução de absorção de ferro, cálcio e antiácidos. Redução leve da eficácia do IBP se tomados junto',
    'Separar a administração por pelo menos 2h. Sulfato ferroso: administrar em jejum, 1h antes ou 2h após o IBP para maximizar absorção',
    'ABSORÇÃO REDUZIDA — Separar por 2h; sulfato ferroso: 1h antes ou 2h após o IBP',
    EvidenceLevel.established,
    {RiskType.other},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('antiácido', 'omeprazol', InteractionSeverity.minor,
    'IBPs elevam pH gástrico; antiácidos/sulfato ferroso/carbonato de cálcio dependem de ambiente ácido para absorção. IBP pode reduzir absorção de sulfato ferroso e Ca',
    'Redução de absorção de ferro, cálcio e antiácidos. Redução leve da eficácia do IBP se tomados junto',
    'Separar a administração por pelo menos 2h. Sulfato ferroso: administrar em jejum, 1h antes ou 2h após o IBP para maximizar absorção',
    'ABSORÇÃO REDUZIDA — Separar por 2h; sulfato ferroso: 1h antes ou 2h após o IBP',
    EvidenceLevel.established,
    {RiskType.other},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('antiácido', 'pantoprazol', InteractionSeverity.minor,
    'IBPs elevam pH gástrico; antiácidos/sulfato ferroso/carbonato de cálcio dependem de ambiente ácido para absorção. IBP pode reduzir absorção de sulfato ferroso e Ca',
    'Redução de absorção de ferro, cálcio e antiácidos. Redução leve da eficácia do IBP se tomados junto',
    'Separar a administração por pelo menos 2h. Sulfato ferroso: administrar em jejum, 1h antes ou 2h após o IBP para maximizar absorção',
    'ABSORÇÃO REDUZIDA — Separar por 2h; sulfato ferroso: 1h antes ou 2h após o IBP',
    EvidenceLevel.established,
    {RiskType.other},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('antiácido', 'sulfato ferroso', InteractionSeverity.moderate,
    'Antiácidos (cátions Al3+, Mg2+, Ca2+) quelam o ferro ferroso do sulfato ferroso, formando complexos insolúveis não absorvíveis',
    'Absorção de ferro reducida em até 70%, falha no tratamento de anemia ferropriva',
    'Administrar sulfato ferroso 2h antes ou 4h após antiácidos. Carbonato de cálcio: separar por pelo menos 2h. Monitorar ferritina e Hb a cada 4-8 semanas',
    'QUELAÇÃO DE FERRO — Antiácido reduz absorção do ferro em 70%; separar por 2-4h',
    EvidenceLevel.established,
    {RiskType.other},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('carbonato de calcio', 'sulfato ferroso', InteractionSeverity.moderate,
    'Antiácidos (cátions Al3+, Mg2+, Ca2+) quelam o ferro ferroso do sulfato ferroso, formando complexos insolúveis não absorvíveis',
    'Absorção de ferro reducida em até 70%, falha no tratamento de anemia ferropriva',
    'Administrar sulfato ferroso 2h antes ou 4h após antiácidos. Carbonato de cálcio: separar por pelo menos 2h. Monitorar ferritina e Hb a cada 4-8 semanas',
    'QUELAÇÃO DE FERRO — Antiácido reduz absorção do ferro em 70%; separar por 2-4h',
    EvidenceLevel.established,
    {RiskType.other},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('anticoncepcional', 'levotiroxina', InteractionSeverity.moderate,
    'Estrogênios (anticoncepcional oral) aumentam globulina ligadora de tiroxina (TBG), reduzindo T4 livre disponible. Maior necessidade de levotiroxina',
    'Hipotireoidismo por aumento da ligação proteica da T4: fadiga, ganho de peso, bradicardia',
    'Monitorar TSH 6-8 semanas após iniciar/suspender anticoncepcional. Aumentar dose de levotiroxina em 20-30% se necesario',
    'HIPOTIREOIDISMO — Estrogênio aumenta TBG; monitorar TSH 6-8 semanas; ajustar dose de levotiroxina',
    EvidenceLevel.established,
    {RiskType.plasmaLevel},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('anticoncepcional', 'tamoxifeno', InteractionSeverity.major,
    'Tamoxifeno é um antagonista de receptor de estrogênio. Anticoncepcional com estrogênio pode antagonizar o efeito antiestrogênico do tamoxifeno',
    'Reducción de la eficacia do tamoxifeno no tratamento de câncer de mama receptor hormonal positivo. Risco de recidiva tumoral',
    'EVITAR combinação. Usar contracepção não hormonal (DIU de cobre, preservativo) durante tamoxifeno. Discutir com oncologista',
    'ANTAGONISMO FARMACOLÓGICO — Estrogênio antagoniza tamoxifeno; usar contracepção não hormonal',
    EvidenceLevel.established,
    {RiskType.other},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('dexametasona', 'levotiroxina', InteractionSeverity.moderate,
    'Glicocorticóides em altas doses inibem conversão periférica de T4 em T3 (inibição de deiodinase tipo I) e reduzem liberação de TSH',
    'Hipotireoidismo relativo em uso prolongado, alteração nos valores de TSH dificultando ajuste de levotiroxina',
    'Monitorar TSH e T4 livre durante uso de dexametasona. Ajustar dose de levotiroxina conforme nível de TSH. Reavaliar ao suspender dexametasona',
    'CONVERSÃO T4→T3 REDUZIDA — Dexametasona inibe deiodinase; monitorar TSH; ajustar levotiroxina',
    EvidenceLevel.established,
    {RiskType.plasmaLevel},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('dexametasona', 'tamoxifeno', InteractionSeverity.moderate,
    'Dexametasona induz CYP3A4 e P-glicoproteína, podendo reduzir niveles plasmáticos de tamoxifeno e seu metabólito ativo endoxifeno',
    'Reducción de la eficacia antiestrogênica do tamoxifeno, risco de recidiva em câncer de mama',
    'Monitorar resposta clínica ao tamoxifeno. Se dexametasona em uso prolongado, discutir com oncologista alternativa ao tamoxifeno (inibidores de aromatase podem ser afetados similarmente)',
    'EFICÁCIA DE TAMOXIFENO REDUZIDA — Dexametasona induz CYP3A4; monitorar resposta oncológica',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('daptomicina', 'vancomicina', InteractionSeverity.moderate,
    'Dois agentes com atividade contra Gram-positivos: potencial nefrotoxicidad aditiva. Sem sinergismo estabelecido para a maioria das infecções',
    'Nefrotoxicidad aditiva, miopatia por daptomicina potencializada',
    'Monitorar función renal diariamente e CPK semanal (daptomicina). Monitorar nivel sérico de vancomicina (meta: AUC/MIC 400-600). Evitar combinación sem indicação específica',
    'NEFROTOXICIDADE ADITIVA — Monitorar creatinina e CPK; dosar nível de vancomicina',
    EvidenceLevel.probable,
    {RiskType.nephrotoxicity},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('linezolida', 'vancomicina', InteractionSeverity.minor,
    'Linezolida e vancomicina têm cobertura sobreposta para Gram-positivos. Sem interação farmacocinética significativa, mas trombocitopenia e mielosupresión aditivas com linezolida',
    'Trombocitopenia, anemia, mielosupresión por linezolida. Nefrotoxicidad de vancomicina',
    'Monitorar hemograma 2x/semana (linezolida). Monitorar función renal e nível de vancomicina. Combinação raramente justificada — revisar cobertura necessária',
    'MIELOSSUPRESSÃO + NEFROTOXICIDADE — Monitorar hemograma e creatinina; revisar indicação da combinação',
    EvidenceLevel.probable,
    {RiskType.other},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('sulfametoxazol', 'trimetoprima', InteractionSeverity.moderate,
    'Sulfametoxazol + trimetoprima (co-trimoxazol): sinergia intencional por bloqueio sequencial da síntese de folato bacteriano. Porém: hiperpotasemia, mielosupresión e nefrotoxicidad aditivas',
    'Hipercalemia (trimetoprima bloqueia ENaC renal), mielosupresión, cristalúria (sulfametoxazol), nefrotoxicidad',
    'Combinação intencional terapéutica. Monitorar K+, creatinina e hemograma semanalmente. Hidratação adecuada. Suplementar ácido fólico em uso prolongado. Evitar em IR grave (TFG < 15)',
    'CO-TRIMOXAZOL — Hipercalemia + mielosupresión; monitorar K+, creatinina e hemograma',
    EvidenceLevel.established,
    {RiskType.other, RiskType.nephrotoxicity},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('fluconazol', 'isavuconazol', InteractionSeverity.major,
    'Fluconazol e isavuconazol são azólicos que prolongam QTc (isavuconazol: encurta levemente, mas a combinação tem efeito imprevisível). Ambos inibem CYP3A4 com potencial interação. Inibição aditiva de ergosterol fúngico',
    'Interação farmacocinética imprevisível (ambos inibem CYP3A4 mutuamente), prolongamento QTc incerto, toxicidad hepática aditiva',
    'EVITAR combinação de dois azólicos. Usar o mais adecuado para o fungo isolado. Monitorar ECG e função hepática se exposição inevitável',
    'DOIS AZÓLICOS — Interação CYP3A4 imprevisível; hepatotoxicidad aditiva; usar apenas um azólico',
    EvidenceLevel.probable,
    {RiskType.qtProlongation, RiskType.other},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('azitromicina', 'eritromicina', InteractionSeverity.major,
    'Dois macrolídeos: prolongamento aditivo do QTc por bloqueio de canais IKr. Inibição de CYP3A4 aditiva (exceto azitromicina)',
    'Torsades de Pointes, fibrilación ventricular, muerte súbita. Interações medicamentosas aditivas por inhibición de CYP3A4',
    'EVITAR combinação de dois macrolídeos. Usar o mais adecuado para a indicação clínica. Monitorar QTc se exposição inevitável',
    'TORSADE DE POINTES — Dois macrolídeos prolongam QTc de forma aditiva; usar apenas um',
    EvidenceLevel.established,
    {RiskType.qtProlongation},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('azitromicina', 'claritromicina', InteractionSeverity.major,
    'Dois macrolídeos: prolongamento aditivo do QTc por bloqueio de canais IKr. Inibição de CYP3A4 aditiva (exceto azitromicina)',
    'Torsades de Pointes, fibrilación ventricular, muerte súbita. Interações medicamentosas aditivas por inhibición de CYP3A4',
    'EVITAR combinação de dois macrolídeos. Usar o mais adecuado para a indicação clínica. Monitorar QTc se exposição inevitável',
    'TORSADE DE POINTES — Dois macrolídeos prolongam QTc de forma aditiva; usar apenas um',
    EvidenceLevel.established,
    {RiskType.qtProlongation},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('dexmedetomidina', 'levosimendan', InteractionSeverity.moderate,
    'Dexmedetomidina (α2-agonista central) causa bradicardia e hipotensão. Combinada com inodilatador (levosimendan/milrinona): hipotensão aditiva e hemodinâmica complexa',
    'Hipotensão grave, bradicardia, necessidade de vasopressores',
    'Monitorar PA e FC continuamente em UTI. Titular dexmedetomidina lentamente. Ter noradrenalina disponible para suporte vasopressor',
    'HIPOTENSÃO + BRADICARDIA — Dexmedetomidina + inodilatador; monitorar PA e FC; ter vasopressor disponible',
    EvidenceLevel.probable,
    {RiskType.arrhythmia},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('dexmedetomidina', 'milrinona', InteractionSeverity.moderate,
    'Dexmedetomidina (α2-agonista central) causa bradicardia e hipotensão. Combinada com inodilatador (levosimendan/milrinona): hipotensão aditiva e hemodinâmica complexa',
    'Hipotensão grave, bradicardia, necessidade de vasopressores',
    'Monitorar PA e FC continuamente em UTI. Titular dexmedetomidina lentamente. Ter noradrenalina disponible para suporte vasopressor',
    'HIPOTENSÃO + BRADICARDIA — Dexmedetomidina + inodilatador; monitorar PA e FC; ter vasopressor disponible',
    EvidenceLevel.probable,
    {RiskType.arrhythmia},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('levosimendan', 'milrinona', InteractionSeverity.moderate,
    'Levosimendan (sensibilizador de cálcio + abertura de KATP) e milrinona (inibidor de PDE3): ambos causam vasodilatação e aumento do débito cardíaco. Efeitos hemodinâmicos aditivos',
    'Hipotensão grave, taquicardia, arritmias ventriculares por efeito inotrópico e vasodilatador excessivo',
    'Monitorar PA, FC e débito cardíaco (Swan-Ganz ou ecocardiograma) continuamente. Reduzir dose de um dos agentes se hipotensão. Reposição volêmica adecuada',
    'HIPOTENSÃO GRAVE — Dois inodilatadores; monitorar hemodinâmica continuamente; titular doses',
    EvidenceLevel.probable,
    {RiskType.arrhythmia},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('levosimendan', 'propofol', InteractionSeverity.moderate,
    'Propofol causa vasodilatação e depressão miocárdica direta. Combinado com inodilatador: hipotensão aditiva por vasodilatação somada e depressão cardíaca',
    'Hipotensão grave, especialmente em bolus de propofol. Depressão cardíaca aditiva',
    'Evitar bolus rápidos de propofol. Usar infusão contínua em dose baixa. Monitorar PA invasiva. Ter vasopressor disponible (noradrenalina)',
    'HIPOTENSÃO — Propofol + inodilatador; evitar bolus; monitorar PA; ter vasopressor',
    EvidenceLevel.probable,
    {RiskType.arrhythmia},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('levosimendan', 'rocurônio', InteractionSeverity.minor,
    'Rocurônio (bloqueador neuromuscular adespolarizante) associado a outros agentes de UTI: sem interação farmacocinética direta, mas contexto de sedoanalgesia complexa',
    'Paralisia muscular prolongada em contexto de sedação profunda. Dificulta avaliação neurológica',
    'Monitorar grau de bloqueio neuromuscular (TOF - train-of-four). Usar sugamadex para reversão rápida se necesario. Manter sedação adecuada durante bloqueio',
    'BLOQUEIO NEUROMUSCULAR — Monitorar TOF; ter sugamadex disponible; manter sedação adecuada',
    EvidenceLevel.probable,
    {RiskType.respiratoryDepression},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('milrinona', 'propofol', InteractionSeverity.moderate,
    'Propofol causa vasodilatação e depressão miocárdica direta. Combinado com inodilatador: hipotensão aditiva por vasodilatação somada e depressão cardíaca',
    'Hipotensão grave, especialmente em bolus de propofol. Depressão cardíaca aditiva',
    'Evitar bolus rápidos de propofol. Usar infusão contínua em dose baixa. Monitorar PA invasiva. Ter vasopressor disponible (noradrenalina)',
    'HIPOTENSÃO — Propofol + inodilatador; evitar bolus; monitorar PA; ter vasopressor',
    EvidenceLevel.probable,
    {RiskType.arrhythmia},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('milrinona', 'rocurônio', InteractionSeverity.minor,
    'Rocurônio (bloqueador neuromuscular adespolarizante) associado a outros agentes de UTI: sem interação farmacocinética direta, mas contexto de sedoanalgesia complexa',
    'Paralisia muscular prolongada em contexto de sedação profunda. Dificulta avaliação neurológica',
    'Monitorar grau de bloqueio neuromuscular (TOF - train-of-four). Usar sugamadex para reversão rápida se necesario. Manter sedação adecuada durante bloqueio',
    'BLOQUEIO NEUROMUSCULAR — Monitorar TOF; ter sugamadex disponible; manter sedação adecuada',
    EvidenceLevel.probable,
    {RiskType.respiratoryDepression},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('propofol', 'rocurônio', InteractionSeverity.minor,
    'Rocurônio (bloqueador neuromuscular adespolarizante) associado a outros agentes de UTI: sem interação farmacocinética direta, mas contexto de sedoanalgesia complexa',
    'Paralisia muscular prolongada em contexto de sedação profunda. Dificulta avaliação neurológica',
    'Monitorar grau de bloqueio neuromuscular (TOF - train-of-four). Usar sugamadex para reversão rápida se necesario. Manter sedação adecuada durante bloqueio',
    'BLOQUEIO NEUROMUSCULAR — Monitorar TOF; ter sugamadex disponible; manter sedação adecuada',
    EvidenceLevel.probable,
    {RiskType.respiratoryDepression},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('ciprofloxacino', 'quinolona', InteractionSeverity.contraindicated,
    'Ciprofloxacino é uma quinolona fluorada: uso concomitante representa duplicação do mesmo mecanismo de ação (inibição de DNA-girase/topoisomerase IV)',
    'Toxicidade por quinolona aditiva: QTc prolongado, tendinite/ruptura de tendão, neurotoxicidad, fotossensibilidade',
    'DUPLICAÇÃO: usar apenas uma quinolona. Selecionar a mais adecuada para o patógeno. Sem benefício adicional de duas quinolonas',
    'DUPLICAÇÃO DE QUINOLONA — Ciprofloxacino é quinolona; usar apenas uma; sem benefício adicional',
    EvidenceLevel.established,
    {RiskType.qtProlongation},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('paracetamol', 'rifampicina', InteractionSeverity.major,
    'Rifampicina é potente indutor de CYP2E1 e CYP3A4, aumentando conversão de paracetamol em seu metabólito hepatotóxico NAPQI. Depleção de glutationa hepática',
    'Hepatotoxicidad grave por paracetamol em doses que seriam normalmente seguras. Risco especialmente alto em doses >2g/dia',
    'Limitar paracetamol a ≤1,5 g/dia durante rifampicina. Monitorar função hepática mensalmente. Preferir analgésico alternativo (tramadol em baixa dose, dipirona)',
    'HEPATOTOXICIDADE — Rifampicina induz CYP2E1; limitar paracetamol a ≤1,5g/dia; monitorar TGO/TGP',
    EvidenceLevel.established,
    {RiskType.other},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('colchicina', 'rifampicina', InteractionSeverity.major,
    'Rifampicina induz CYP3A4 e P-glicoproteína (P-gp), reduzindo absorção e aumentando eliminação de colchicina. Níveis de colchicina reducidos em 50-70%',
    'Falha terapéutica da colchicina (crise de gota não controlada, falha na profilaxia de pericardite)',
    'Aumentar dose de colchicina com cautela ao usar rifampicina. Monitorar resposta clínica. Considerar corticoide ou AINE como alternativa para crise de gota',
    'COLCHICINA REDUZIDA 50-70% — Rifampicina induz P-gp e CYP3A4; aumentar dose ou usar alternativa',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel},
    ['Micromedex 2024', 'UpToDate 2024']),


  // ── LOTE 5 — 159 pares novos ───────────────────────────────────────────────

  // ── 1. AINEs específicos × Anticoagulantes ───────────────────────────────

  ('warfarina', 'aine', InteractionSeverity.major,
    'Deslocamento da ligação proteica + inibição plaquetária + irritação mucosa gástrica',
    'Elevación del INR y riesgo de sangrado GI grave',
    'Evitar AINEs com warfarina. Usar paracetamol como alternativa. Se imprescindível, usar por ≤3 dias com monitoramento de INR',
    'ALTO RISCO — AINEs elevam INR e causam sangrado GI',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),

  ('apixabana', 'aine', InteractionSeverity.major,
    'Inibição plaquetária aditiva ao efeito anticoagulante do fator Xa; irritação mucosa',
    'Risco aumentado de sangrado GI e sistêmico',
    'Evitar combinación. Si inevitable, usar AINE por período mínimo e monitorar sinais de sangrado',
    'RISCO HEMORRÁGICO — AINEs potencializam apixabana',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    ['Micromedex 2024', 'UpToDate 2024', 'ESC 2021']),

  ('rivaroxabana', 'aine', InteractionSeverity.major,
    'Inibição plaquetária aditiva + efeito anti-Xa somado à lesão mucosa pelos AINEs',
    'Risco aumentado de sangrado GI grave',
    'Evitar combinación. Se necesario uso pontual, proteger mucosa com IBP e monitorar sangrado',
    'RISCO HEMORRÁGICO — AINEs potencializam rivaroxabana',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    ['Micromedex 2024', 'UpToDate 2024']),

  ('dabigatrana', 'aine', InteractionSeverity.major,
    'Inibição plaquetária aditiva ao bloqueio direto da trombina; lesão gástrica pelos AINEs',
    'Risco aumentado de sangrado GI, especialmente com dabigatrana (maior incidência GI)',
    'Evitar. Dabigatrana já tem maior risco GI basal; AINEs agravam significativamente',
    'RISCO HEMORRÁGICO GI ELEVADO — Combinação perigosa com dabigatrana',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    ['Micromedex 2024', 'UpToDate 2024', 'RE-LY Trial']),

  ('heparina', 'aine', InteractionSeverity.major,
    'Inibição plaquetária pelos AINEs soma-se ao efeito anticoagulante da heparina',
    'Risco hemorrágico aumentado, especialmente sangrado GI',
    'Evitar combinación. Usar paracetamol como analgésico alternativo durante anticoagulação com heparina',
    'RISCO HEMORRÁGICO — AINEs potencializam heparina',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),

  // ── 2. Ticagrelor × Anticoagulantes ──────────────────────────────────────

  ('apixabana', 'ticagrelor', InteractionSeverity.major,
    'Dupla inibição: anticoagulação por fator Xa + inibição plaquetária P2Y12; sem antídoto específico para combinação',
    'Risco hemorrágico grave; triplamente aumentado se aspirina associada',
    'Usar apenas em indicação absolutamente necessária (ex: SCA + FA + stent recente). Associar IBP. Checar guidelines',
    'TRIPLA ANTITROMBÓTICA — Risco hemorrágico muito elevado',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    ['ESC 2023', 'Micromedex 2024', 'UpToDate 2024']),

  ('rivaroxabana', 'ticagrelor', InteractionSeverity.major,
    'Inibição plaquetária P2Y12 + anticoagulação oral direta; rivaroxabana inibe CYP3A4/P-gp, podendo elevar níveis de ticagrelor',
    'Risco hemorrágico muito elevado; ticagrelor pode ter nível aumentado',
    'Combinação aceitável apenas em contexto específico (SCA + FA). Duração mínima, com IBP obligatorio',
    'ALTO RISCO HEMORRÁGICO — Ticagrelor pode ter nível elevado por rivaroxabana',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    ['ESC 2023', 'UpToDate 2024']),

  ('dabigatrana', 'ticagrelor', InteractionSeverity.major,
    'Ticagrelor inibe P-gp, elevando os niveles plasmáticos de dabigatrana em ~30%',
    'Risco hemorrágico aumentado por dupla ação antitrombótica + elevação do nível de dabigatrana',
    'Evitar ou usar dose reducida de dabigatrana (110 mg 2x/dia). Monitorar sinais de sangrado rigurosamente',
    'NÍVEL DE DABIGATRANA AUMENTADO 30% — Ticagrelor inibe P-gp',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    ['Micromedex 2024', 'UpToDate 2024', 'ESC 2023']),

  ('warfarina', 'ticagrelor', InteractionSeverity.major,
    'Inibição plaquetária P2Y12 + anticoagulação com warfarina; sem impacto relevante no INR, mas risco hemorrágico aditivo',
    'Risco hemorrágico grave pela combinação anticoagulante + antiagregante',
    'Usar apenas com indicação formal. Manter INR 2,0–2,5. Associar IBP. Monitorar sinais de sangrado',
    'RISCO HEMORRÁGICO GRAVE — Combinação anticoagulante + antiagregante',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    ['ESC 2023', 'AHA 2023', 'Micromedex 2024']),

  ('heparina', 'ticagrelor', InteractionSeverity.major,
    'Inibição plaquetária P2Y12 + anticoagulação parenteral; risco hemorrágico aditivo',
    'Risco de sangrado aumentado no contexto de SCA/internação',
    'Combinação comum em SCA; manter vigilância de sangrado; reverter heparina se necesario',
    'RISCO HEMORRÁGICO — Combinação frecuente em SCA; vigiar sangrado',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    ['ESC 2023', 'Micromedex 2024']),

  // ── 3. Dabigatrana × Verapamil / Diltiazem / Amiodarona ──────────────────

  ('dabigatrana', 'verapamil', InteractionSeverity.major,
    'Verapamil inibe fortemente a P-glicoproteína, principal via de eliminação da dabigatrana, elevando seus níveis em 50–180%',
    'Aumento significativo dos níveis de dabigatrana → risco hemorrágico grave',
    'Reduzir dose de dabigatrana para 110 mg 2x/dia. Monitorar sinais de sangrado. Evitar em insuficiencia renal',
    'NÍVEL DE DABIGATRANA AUMENTADO 50–180% — Reduzir dose para 110 mg',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    ['Micromedex 2024', 'UpToDate 2024', 'EMA SmPC Pradaxa']),

  ('dabigatrana', 'diltiazem', InteractionSeverity.moderate,
    'Diltiazem inibe parcialmente a P-gp, elevando os níveis de dabigatrana em ~20–40%',
    'Moderado aumento dos níveis de dabigatrana com potencial hemorrágico',
    'Monitorar sinais de sangrado. Considerar redução de dose em pacientes com risco aumentado ou insuficiencia renal',
    'NÍVEL DABIGATRANA +20–40% — Diltiazem inibe P-gp parcialmente',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    ['Micromedex 2024', 'UpToDate 2024']),

  ('dabigatrana', 'amiodarona', InteractionSeverity.major,
    'Amiodarona e seu metabólito DEA inibem P-gp, elevando os níveis de dabigatrana em 12–60%; associação de arritmia de base',
    'Elevação dos níveis de dabigatrana com risco hemorrágico, especialmente em idosos com FA',
    'Monitorar sangrado rigurosamente. Considerar redução de dose para 110 mg 2x/dia. Avaliar función renal periodicamente',
    'NÍVEL DABIGATRANA ELEVADO — Amiodarona inibe P-gp; monitorar em FA',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    ['Micromedex 2024', 'UpToDate 2024', 'ESC 2020']),

  // ── 4. Rivaroxabana × Amiodarona ─────────────────────────────────────────

  ('rivaroxabana', 'amiodarona', InteractionSeverity.moderate,
    'Amiodarona inibe CYP3A4 e P-gp, vias de metabolismo da rivaroxabana, elevando seus niveles plasmáticos em ~10–40%',
    'Aumento moderado dos níveis de rivaroxabana com possível risco hemorrágico',
    'Monitorar sinais de sangrado. Avaliar función renal (rivaroxabana é eliminada parcialmente por via renal)',
    'NÍVEL RIVAROXABANA ELEVADO — Amiodarona inibe CYP3A4/P-gp',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    ['Micromedex 2024', 'UpToDate 2024']),

  // ── 5. Prolongamento do QT (domperidona, metoclopramida, levosulpirida, clorpromazina, risperidona) ──

  ('amiodarona', 'domperidona', InteractionSeverity.contraindicated,
    'Ambos prolongam o intervalo QT por bloqueio de canais hERG/IKr; risco de somação',
    'Torsades de Pointes e morte súbita cardíaca',
    'Contraindicado. Substituir domperidona por outra antiemética (ex: metoclopramida com cautela, ondansetrona)',
    'CONTRAINDICADO — QT aditivo: risco de Torsades de Pointes fatal',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    ['Micromedex 2024', 'ANSM 2012', 'EMA 2014']),

  ('sotalol', 'domperidona', InteractionSeverity.contraindicated,
    'Ambos prolongam o QT por bloqueio de IKr; sotalol prolonga QT dose-dependente',
    'Torsades de Pointes e fibrilação ventricular',
    'Contraindicado. Evitar combinación',
    'CONTRAINDICADO — QT aditivo com sotalol',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    ['Micromedex 2024', 'UpToDate 2024']),

  ('haloperidol', 'domperidona', InteractionSeverity.major,
    'Ambos bloqueiam receptores D2 e prolongam QT; efeito aditivo no prolongamento',
    'Risco de Torsades de Pointes e arritmias ventriculares graves',
    'Evitar combinación. Se necesario, monitorar ECG e potássio sérico',
    'RISCO DE TORSADE — QT aditivo: haloperidol + domperidona',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    ['Micromedex 2024', 'UpToDate 2024']),

  ('quetiapina', 'domperidona', InteractionSeverity.major,
    'Ambos prolongam QT por bloqueio de canais hERG',
    'Risco aumentado de Torsades de Pointes',
    'Evitar combinación. Monitorar ECG se uso necesario',
    'RISCO DE TORSADE — QT aditivo: quetiapina + domperidona',
    EvidenceLevel.probable,
    {RiskType.qtProlongation},
    ['Micromedex 2024', 'CredibleMeds 2024']),

  ('amiodarona', 'metoclopramida', InteractionSeverity.major,
    'Metoclopramida prolonga QT moderadamente; amiodarona prolonga significativamente; efeito aditivo',
    'Risco aumentado de Torsades de Pointes e arritmias ventriculares',
    'Evitar. Se necesario como antiemético, preferir ondansetrona (com cautela) ou dexametasona',
    'RISCO DE TORSADE — QT aditivo: amiodarona + metoclopramida',
    EvidenceLevel.probable,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    ['Micromedex 2024', 'CredibleMeds 2024']),

  ('amiodarona', 'levosulpirida', InteractionSeverity.major,
    'Levosulpirida bloqueia receptores D2 e prolonga QT; amiodarona prolonga significativamente; efeito aditivo',
    'Risco de Torsades de Pointes',
    'Evitar combinación. Usar alternativa para DRGE/gastroparesia',
    'RISCO DE TORSADE — QT aditivo: amiodarona + levosulpirida',
    EvidenceLevel.probable,
    {RiskType.qtProlongation},
    ['Micromedex 2024', 'CredibleMeds 2024']),

  ('haloperidol', 'metoclopramida', InteractionSeverity.major,
    'Ambos bloqueiam D2 e prolongam QT; risco aditivo extrapiramidal e de Torsade',
    'Risco de Torsades de Pointes e sintomas extrapiramidais graves',
    'Evitar. Se antiemético necesario, usar ondansetrona. Monitorar ECG e electrolitos',
    'RISCO DE TORSADE + EXTRAPIRAMIDAL — Haloperidol + metoclopramida',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    ['Micromedex 2024', 'UpToDate 2024']),

  ('amiodarona', 'clorpromazina', InteractionSeverity.contraindicated,
    'Ambos prolongam QT significativamente por bloqueio hERG; clorpromazina é antipsicótico típico de alta potência QT',
    'Torsades de Pointes e morte súbita cardíaca',
    'Contraindicado. Substituir clorpromazina por antipsicótico com menor risco QT',
    'CONTRAINDICADO — QT aditivo: risco de Torsade fatal',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    ['Micromedex 2024', 'CredibleMeds 2024']),

  ('sotalol', 'clorpromazina', InteractionSeverity.contraindicated,
    'Ambos prolongam QT por bloqueio de IKr; efeito aditivo grave',
    'Torsades de Pointes e fibrilação ventricular',
    'Contraindicado. Substituir antipsicótico por opção com menor risco QT',
    'CONTRAINDICADO — QT aditivo: sotalol + clorpromazina',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    ['Micromedex 2024', 'CredibleMeds 2024']),

  ('amiodarona', 'risperidona', InteractionSeverity.major,
    'Risperidona prolonga QT de forma dose-dependente; amiodarona prolonga significativamente; efeito aditivo',
    'Risco de Torsades de Pointes e arritmias ventriculares',
    'Evitar combinación. Monitorar ECG e electrolitos. Corrigir hipopotasemia/hipomagnesemia',
    'RISCO DE TORSADE — QT aditivo: amiodarona + risperidona',
    EvidenceLevel.probable,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    ['Micromedex 2024', 'CredibleMeds 2024']),

  ('sotalol', 'risperidona', InteractionSeverity.major,
    'Ambos prolongam QT; sotalol de forma dose-dependente; risperidona em doses altas',
    'Risco de Torsades de Pointes',
    'Evitar. Monitorar ECG e electrolitos se uso inevitável',
    'RISCO DE TORSADE — QT aditivo: sotalol + risperidona',
    EvidenceLevel.probable,
    {RiskType.qtProlongation},
    ['Micromedex 2024', 'CredibleMeds 2024']),

  // ── 6. Síndrome Serotoninérgica — duloxetina, venlafaxina, petidina ──────

  ('isrs', 'duloxetina', InteractionSeverity.major,
    'Duloxetina é IRSN; combinação com ISRS produz inibição serotoninérgica aditiva',
    'Síndrome serotoninérgica: agitação, hipertermia, tremor, rigidez, instabilidade autonômica',
    'Evitar combinación. Se necesario trocar, respeitar washout de 14 dias entre medicamentos',
    'SÍNDROME SEROTONINÉRGICA — Não combinar ISRS com duloxetina',
    EvidenceLevel.established,
    {RiskType.serotonin},
    ['Micromedex 2024', 'UpToDate 2024']),

  ('imao', 'duloxetina', InteractionSeverity.contraindicated,
    'IMAO + duloxetina (IRSN): acúmulo massivo de serotonina por inhibición da MAO + inibição da recaptação',
    'Síndrome serotoninérgica grave, hipercrise hipertensiva e risco de morte',
    'Contraindicado. Washout de 14 dias após IMAO antes de iniciar duloxetina; 5 dias após duloxetina antes de IMAO',
    'CONTRAINDICADO — Crise serotoninérgica e hipercrise hipertensiva fatal',
    EvidenceLevel.established,
    {RiskType.serotonin, RiskType.cardiovascular},
    ['FDA Label', 'Micromedex 2024']),

  ('imao', 'venlafaxina', InteractionSeverity.contraindicated,
    'IMAO + venlafaxina (IRSN): inibição da MAO + inibição da recaptação de serotonina e noradrenalina',
    'Síndrome serotoninérgica grave con riesgo de muerte',
    'Contraindicado. Washout de 14 dias após IMAO; 7 dias após venlafaxina antes de IMAO',
    'CONTRAINDICADO — Síndrome serotoninérgica fatal',
    EvidenceLevel.established,
    {RiskType.serotonin},
    ['FDA Label', 'Micromedex 2024', 'UpToDate 2024']),

  ('tramadol', 'duloxetina', InteractionSeverity.major,
    'Tramadol tem atividade serotoninérgica intrínseca; duloxetina é IRSN — efeito aditivo serotoninérgico',
    'Síndrome serotoninérgica e risco convulsivo aumentado',
    'Evitar. Se dor moderada-intensa, usar opioide sem ação serotoninérgica (ex: morfina, oxicodona)',
    'SÍNDROME SEROTONINÉRGICA — Tramadol + duloxetina',
    EvidenceLevel.probable,
    {RiskType.serotonin, RiskType.seizure},
    ['Micromedex 2024', 'UpToDate 2024']),

  ('tramadol', 'venlafaxina', InteractionSeverity.major,
    'Tramadol + venlafaxina: ação serotoninérgica aditiva; tramadol também inibe recaptação de monoaminas',
    'Síndrome serotoninérgica e convulsiones',
    'Evitar combinación. Usar alternativa analgésica sem ação serotoninérgica',
    'SÍNDROME SEROTONINÉRGICA — Tramadol + venlafaxina',
    EvidenceLevel.probable,
    {RiskType.serotonin, RiskType.seizure},
    ['Micromedex 2024', 'UpToDate 2024']),

  ('opioide', 'petidina', InteractionSeverity.major,
    'Petidina (meperidina) tem ação serotoninérgica intrínseca; combinação com outros opioides e serotoninérgicos amplifica o risco',
    'Síndrome serotoninérgica e depresión respiratoria aditiva',
    'Evitar petidina em pacientes usando serotoninérgicos. Preferir morfina ou fentanila',
    'SÍNDROME SEROTONINÉRGICA + DEPRESSÃO RESPIRATÓRIA — Evitar petidina',
    EvidenceLevel.established,
    {RiskType.serotonin, RiskType.respiratoryDepression},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),

  ('isrs', 'petidina', InteractionSeverity.contraindicated,
    'Petidina inibe recaptação de serotonina; ISRS adiciona inibição serotoninérgica; risco muito elevado',
    'Síndrome serotoninérgica grave, convulsiones e óbito',
    'Contraindicado. Usar morfina ou fentanila como alternativa em pacientes com ISRS',
    'CONTRAINDICADO — Síndrome serotoninérgica grave: ISRS + petidina',
    EvidenceLevel.established,
    {RiskType.serotonin, RiskType.seizure},
    ['Micromedex 2024', 'UpToDate 2024', 'FDA Label']),

  ('imao', 'petidina', InteractionSeverity.contraindicated,
    'Petidina + IMAO: síndrome serotoninérgica clássica e hipercrise hipertensiva',
    'Síndrome serotoninérgica grave con riesgo de muerte',
    'Contraindicado absolutamente. Usar morfina como alternativa com cautela',
    'CONTRAINDICADO — Síndrome serotoninérgica fatal clássica',
    EvidenceLevel.established,
    {RiskType.serotonin, RiskType.cardiovascular},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'FDA Label']),

  // ── 7. Depressão respiratória ─────────────────────────────────────────────

  ('benzodiazepínico', 'opioide', InteractionSeverity.major,
    'Depressão aditiva do SNC e do centro respiratório; benzodiazepínico potencializa receptores GABA enquanto opioide age em receptores μ',
    'Depressão respiratória grave, apneia e risco de óbito',
    'Evitar combinación quando possível. Se necesario, usar doses mínimas, monitorar oximetria e ter naloxona disponible',
    'DEPRESSÃO RESPIRATÓRIA FATAL — FDA black box warning',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns},
    ['FDA Black Box Warning 2016', 'Micromedex 2024', 'UpToDate 2024']),

  ('benzodiazepínico', 'morfina', InteractionSeverity.major,
    'Benzodiazepínico potencializa efeito depressor respiratório da morfina via GABA + receptores μ',
    'Depressão respiratória grave e apneia',
    'Usar doses mínimas. Monitorar oximetria. Naloxona disponible. Evitar em pacientes sem monitoramento',
    'DEPRESSÃO RESPIRATÓRIA GRAVE — Benzodiazepínico + morfina',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns},
    ['FDA Black Box Warning', 'Micromedex 2024']),

  ('benzodiazepínico', 'fentanila', InteractionSeverity.major,
    'Combinação sinérgica na depressão do SNC; fentanila tem janela terapéutica estreita',
    'Depressão respiratória grave, apneia e parada cardiorrespiratória',
    'Monitoração rigurosa em UTI/cirurgia. Naloxona disponible. Titular doses cuidadosamente',
    'DEPRESSÃO RESPIRATÓRIA GRAVE — Benzodiazepínico + fentanila',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns},
    ['FDA Black Box Warning', 'Micromedex 2024']),

  ('benzodiazepínico', 'tramadol', InteractionSeverity.major,
    'Depressão aditiva do SNC; tramadol também reduz limiar convulsivo',
    'Depressão respiratória e paradoxalmente convulsiones em alguns pacientes',
    'Evitar. Se necesario, usar doses mínimas com monitoramento',
    'DEPRESSÃO RESPIRATÓRIA + RISCO DE CONVULSÃO — Benzodiazepínico + tramadol',
    EvidenceLevel.probable,
    {RiskType.respiratoryDepression, RiskType.seizure},
    ['Micromedex 2024', 'UpToDate 2024']),

  ('gabapentina', 'opioide', InteractionSeverity.major,
    'Pregabalina/gabapentina potencializam depressão do SNC e respiratória dos opioides por mecanismo sinérgico no canal de cálcio α2δ',
    'Depressão respiratória grave, especialmente com doses altas ou em idosos',
    'FDA emitiu aviso. Usar doses mínimas, monitorar oximetria. Evitar em DPOC e apneia do sono',
    'DEPRESSÃO RESPIRATÓRIA — FDA warning: gabapentinoides + opioides',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns},
    ['FDA Drug Safety Communication 2019', 'Micromedex 2024', 'UpToDate 2024']),

  ('gabapentina', 'morfina', InteractionSeverity.major,
    'Gabapentina aumenta biodisponibilidade da morfina e potencializa depresión respiratoria',
    'Depressão respiratória grave com risco de óbito',
    'Usar com cautela. Doses mínimas. Monitorar oximetria continuamente',
    'DEPRESSÃO RESPIRATÓRIA GRAVE — Gabapentina + morfina',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns},
    ['FDA Drug Safety Communication 2019', 'Micromedex 2024']),

  ('gabapentina', 'benzodiazepínico', InteractionSeverity.major,
    'Tripla depressão do SNC: gabapentinóide + benzodiazepínico, frecuentemente com opioide associado',
    'Depressão respiratória e sedação excessiva',
    'Evitar tripla combinação. Se necesario, monitorar oximetria e reduzir doses',
    'DEPRESSÃO RESPIRATÓRIA — Gabapentina + benzodiazepínico (alto risco)',
    EvidenceLevel.probable,
    {RiskType.respiratoryDepression, RiskType.cns},
    ['FDA 2019', 'Micromedex 2024']),

  ('benzodiazepínico', 'zolpidem', InteractionSeverity.major,
    'Depressão aditiva do SNC; ambos atuam em receptores GABA-A',
    'Sedación excesiva, depresión respiratoria, quedas e amnésia',
    'Evitar combinación. Se necesario em contexto hospitalar, monitorar continuamente',
    'DEPRESSÃO DO SNC GRAVE — Benzodiazepínico + zolpidem',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.respiratoryDepression},
    ['Micromedex 2024', 'UpToDate 2024']),

  ('opioide', 'zolpidem', InteractionSeverity.major,
    'Zolpidem + opioide: depressão sinérgica do SNC e respiratória',
    'Depressão respiratória, sedação excessiva e óbito',
    'Evitar combinación. Si inevitable, usar doses mínimas com monitoramento',
    'DEPRESSÃO RESPIRATÓRIA — Zolpidem + opioide',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns},
    ['FDA Black Box Warning', 'Micromedex 2024']),

  // ── 8. Hipercalemia — IECAs/ARAs × Poupadores de K ───────────────────────

  ('enalapril', 'espironolactona', InteractionSeverity.major,
    'IECA reduz angiotensina II → reduz aldosterona → retém K; espironolactona antagoniza aldosterona diretamente; efeito aditivo hipercalêmico',
    'Hipercalemia grave (K+ >6,5 mEq/L), arritmias e paro cardíaco',
    'Monitorar potássio sérico e creatinina. Iniciar espironolactona em dose baixa (25 mg/dia). Evitar suplementação de K+',
    'HIPERCALEMIA GRAVE — IECA + espironolactona; monitorar K+ e creatinina',
    EvidenceLevel.established,
    {RiskType.hyperkalemia, RiskType.arrhythmia},
    ['RALES Trial', 'Goodman & Gilman 14ª ed.', 'Micromedex 2024']),

  ('losartana', 'espironolactona', InteractionSeverity.major,
    'ARA II reduz aldosterona → retém K; espironolactona antagoniza aldosterona; efeito hipercalêmico aditivo',
    'Hipercalemia grave com risco de arritmia e paro cardíaco',
    'Monitorar K+ e función renal regularmente. Dose inicial baixa de espironolactona. Evitar K+ suplementar',
    'HIPERCALEMIA GRAVE — ARA II + espironolactona; monitorar K+',
    EvidenceLevel.established,
    {RiskType.hyperkalemia, RiskType.arrhythmia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),

  ('sacubitrila', 'espironolactona', InteractionSeverity.major,
    'Sacubitril/valsartana bloqueia receptores AT1 (como ARA II) → reduz aldosterona; espironolactona adiciona antagonismo de aldosterona',
    'Hipercalemia grave, especialmente em insuficiencia renal',
    'Monitorar K+ a cada 1–4 semanas inicialmente. Dose baixa de espironolactona (25 mg). Evitar em K+ >5,0 mEq/L',
    'HIPERCALEMIA — Sacubitril/valsartana + espironolactona; monitorar K+',
    EvidenceLevel.probable,
    {RiskType.hyperkalemia},
    ['PARADIGM-HF', 'Micromedex 2024', 'ESC HF Guidelines 2021']),

  ('enalapril', 'eplerenona', InteractionSeverity.major,
    'IECA + eplerenona (poupador de K seletivo): efeito hipercalêmico aditivo por redução de aldosterona e bloqueio do receptor',
    'Hipercalemia grave com risco de arritmias',
    'Monitorar K+ e función renal. Eplerenona contraindicada se clearance <30 mL/min',
    'HIPERCALEMIA — IECA + eplerenona; monitorar K+ e TFG',
    EvidenceLevel.established,
    {RiskType.hyperkalemia},
    ['EPHESUS Trial', 'Micromedex 2024']),

  ('losartana', 'eplerenona', InteractionSeverity.major,
    'ARA II + eplerenona: duplo bloqueio do eixo renina-angiotensina-aldosterona → hiperpotasemia',
    'Hipercalemia grave com risco de paro cardíaco',
    'Monitorar K+ frecuentemente. Contraindicado se K+ >5,0 mEq/L ou TFG <30 mL/min',
    'HIPERCALEMIA — ARA II + eplerenona; monitorar K+',
    EvidenceLevel.established,
    {RiskType.hyperkalemia},
    ['Micromedex 2024', 'UpToDate 2024']),

  // ── 9. Lítio × Vários ─────────────────────────────────────────────────────

  ('carbonato de litio', 'enalapril', InteractionSeverity.major,
    'IECAs reduzem filtração glomerular e excreção de lítio pelo rim → acúmulo de lítio',
    'Toxicidade por lítio: tremor, ataxia, confusão, convulsiones, arritmias',
    'Monitorar lítio semanalmente nas primeiras 4 semanas. Reduzir dose de lítio em 25–50%. Hidratar adecuadamente',
    'TOXICIDADE DE LÍTIO — IECA reduz excreção renal de lítio',
    EvidenceLevel.established,
    {RiskType.increasedToxicity, RiskType.plasmaLevel},
    ['Micromedex 2024', 'UpToDate 2024', 'Goodman & Gilman']),

  ('carbonato de litio', 'losartana', InteractionSeverity.major,
    'ARA II reduz filtração glomerular → reduz excreção renal de lítio → acúmulo',
    'Toxicidade por lítio',
    'Monitorar lítio regularmente. Ajustar dose. Hidratação adecuada',
    'TOXICIDADE DE LÍTIO — ARA II reduz excreção renal de lítio',
    EvidenceLevel.established,
    {RiskType.increasedToxicity, RiskType.plasmaLevel},
    ['Micromedex 2024', 'UpToDate 2024']),

  ('carbonato de litio', 'hidroclorotiazida', InteractionSeverity.major,
    'Tiazídicos reduzem a excreção renal de lítio ao aumentar reabsorção tubular (lítio e Na+ competem no túbulo)',
    'Toxicidade grave por lítio',
    'Reduzir dose de lítio em 30–50%. Monitorar lítio semanalmente. Preferir furosemida se diurético necesario (menor efeito)',
    'TOXICIDADE DE LÍTIO — Tiazídico retém lítio; reduzir dose',
    EvidenceLevel.established,
    {RiskType.increasedToxicity, RiskType.plasmaLevel},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),

  ('carbonato de litio', 'aine', InteractionSeverity.major,
    'AINEs inibem prostaglandinas renais → reduzem TFG → diminuem excreção de lítio em 25–60%',
    'Toxicidade por lítio com sintomas neurológicos graves',
    'Evitar AINEs em pacientes em uso de lítio. Usar paracetamol como analgésico. Se AINE necesario, monitorar lítio',
    'TOXICIDADE DE LÍTIO — AINEs reduzem excreção renal em 25–60%',
    EvidenceLevel.established,
    {RiskType.increasedToxicity, RiskType.plasmaLevel},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),

  ('carbonato de litio', 'metronidazol', InteractionSeverity.major,
    'Metronidazol reduz excreção renal de lítio por mecanismo não totalmente elucidado',
    'Toxicidade por lítio',
    'Monitorar lítio durante e após o tratamento com metronidazol. Ajustar dose se necesario',
    'TOXICIDADE DE LÍTIO — Metronidazol reduz excreção renal',
    EvidenceLevel.probable,
    {RiskType.increasedToxicity},
    ['Micromedex 2024', 'UpToDate 2024']),

  ('carbonato de litio', 'haloperidol', InteractionSeverity.major,
    'Combinação histórica associada a encefalopatia irreversível; haloperidol pode mascarar sintomas precoces de toxicidad por lítio',
    'Encefalopatia tóxica, dano neurológico permanente',
    'Usar com extrema cautela. Manter lítio na faixa baixa do terapéutico. Monitorar signos neurológicos',
    'ENCEFALOPATIA TÓXICA — Haloperidol + lítio: combinação de alto risco',
    EvidenceLevel.probable,
    {RiskType.increasedToxicity, RiskType.cns},
    ['Micromedex 2024', 'UpToDate 2024']),

  ('carbonato de litio', 'carbonato de calcio', InteractionSeverity.moderate,
    'Carbonato de cálcio pode aumentar reabsorção renal de lítio em algumas situações, além de reduzir absorção GI',
    'Variação nos niveles plasmáticos de lítio',
    'Administrar lítio separado de antiácidos. Monitorar lítio sérico',
    'NÍVEL DE LÍTIO VARIÁVEL — Separar administração de cálcio/antiácidos',
    EvidenceLevel.possible,
    {RiskType.plasmaLevel},
    ['Micromedex 2024']),

  ('carbonato de litio', 'furosemida', InteractionSeverity.moderate,
    'Furosemida aumenta excreção de sódio → pode elevar ou reduzir excreção de lítio dependendo da hidratação',
    'Toxicidade de lítio se depleção de sódio; hipolítio se boa hidratação',
    'Monitorar lítio sérico. Manter hidratação adecuada. Ajustar dose conforme necesario',
    'LÍTIO VARIÁVEL — Furosemida altera excreção dependendo da hidratação',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel},
    ['Micromedex 2024', 'UpToDate 2024']),

  // ── 10. Fenitoína × Anticoagulantes ──────────────────────────────────────

  ('fenitoína', 'warfarina', InteractionSeverity.major,
    'Indução do CYP2C9 (reduz warfarina) inicialmente; depois competição pelo CYP2C9 pode elevar warfarina — efeito bifásico e imprevisível',
    'Instabilidade do INR: inicialmente redução (risco trombótico) e depois possível elevação (risco hemorrágico)',
    'Monitorar INR frecuentemente ao iniciar/suspender fenitoína. Ajustar dose de warfarina conforme resposta',
    'INR IMPREVISÍVEL — Fenitoína tem efeito bifásico sobre warfarina',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),

  ('fenitoína', 'apixabana', InteractionSeverity.major,
    'Fenitoína induz CYP3A4 e P-gp, reduzindo os níveis de apixabana em ~50%',
    'Falha terapéutica da apixabana → risco trombótico e tromboembólico',
    'Evitar combinación. Se necesario, considerar anticoagulante alternativo não metabolizado por CYP3A4/P-gp',
    'APIXABANA REDUZIDA 50% — Fenitoína induz CYP3A4/P-gp',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    ['Micromedex 2024', 'UpToDate 2024', 'FDA Label Eliquis']),

  ('fenitoína', 'rivaroxabana', InteractionSeverity.major,
    'Fenitoína induz CYP3A4 e P-gp, reduzindo os níveis de rivaroxabana significativamente',
    'Falha terapéutica da rivaroxabana → risco de trombosis',
    'Evitar combinación. Usar anticoagulante não afetado por indutores enzimáticos',
    'RIVAROXABANA REDUZIDA — Fenitoína induz CYP3A4/P-gp',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    ['Micromedex 2024', 'UpToDate 2024', 'FDA Label Xarelto']),

  // ── 11. Betabloqueadores × BCC não-DHP / Digoxina ─────────────────────────

  ('metoprolol', 'verapamil', InteractionSeverity.major,
    'Ambos deprimem o nó sinusal e AV por mecanismos diferentes (β-bloqueio + bloqueio de canal de cálcio); efeito cronotrópico e dromotrópico negativo aditivo',
    'Bradicardia grave, bloqueio AV, hipotensão e insuficiencia cardíaca aguda',
    'Contraindicado em pacientes com disfunção ventricular. Monitorar ECG e FC. Evitar especialmente verapamil IV em pacientes com betabloqueador oral',
    'BRADICARDIA/BLOQUEIO AV — Betabloqueador + verapamil: combinação perigosa',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),

  ('metoprolol', 'diltiazem', InteractionSeverity.major,
    'Ambos têm efeito cronotrópico e dromotrópico negativo; diltiazem também inibe CYP2D6, elevando níveis de metoprolol',
    'Bradicardia grave, bloqueio AV de alto grau, hipotensão',
    'Usar com cautela. Monitorar ECG e FC. Reduzir dose de metoprolol se necesario. Evitar em bradiarritmias',
    'BRADICARDIA/BLOQUEIO AV — Metoprolol + diltiazem; nível de metoprolol elevado',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.arrhythmia, RiskType.plasmaLevel},
    ['Micromedex 2024', 'UpToDate 2024']),

  ('metoprolol', 'digoxina', InteractionSeverity.major,
    'Betabloqueador + digoxina: ambos deprimem o nó AV; efeito dromotrópico negativo aditivo',
    'Bradicardia grave e bloqueio AV',
    'Monitorar ECG e FC. Ajustar doses. Útil em FA para controle de ritmo, mas titular cuidadosamente',
    'BRADICARDIA/BLOQUEIO AV — Betabloqueador + digoxina',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    ['Micromedex 2024', 'UpToDate 2024', 'ESC 2020']),

  ('propranolol', 'verapamil', InteractionSeverity.major,
    'Ambos deprimem nó sinusal e AV; propranolol bloqueia receptores β1/β2; verapamil bloqueia canal de cálcio no nó AV',
    'Bradicardia grave, bloqueio AV completo e colapso hemodinâmico',
    'Contraindicado em pacientes com disfunção ventricular. Monitorar ECG rigurosamente',
    'BRADICARDIA/COLAPSO — Propranolol + verapamil: contraindicado em disfunção ventricular',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),

  ('propranolol', 'diltiazem', InteractionSeverity.major,
    'Efeito dromotrópico negativo aditivo; diltiazem pode elevar nível de propranolol',
    'Bradicardia e bloqueio AV',
    'Monitorar ECG e FC. Usar doses baixas com cautela',
    'BRADICARDIA — Propranolol + diltiazem: efeito dromotrópico aditivo',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    ['Micromedex 2024']),

  // ── 12. Empagliflozina × Antidiabéticos ──────────────────────────────────

  ('dapagliflozina', 'insulina', InteractionSeverity.moderate,
    'SGLT2i reduz a glucemia; insulina também reduz glucemia — risco de hipoglucemia aditiva, especialmente se dose de insulina não ajustada',
    'Hipoglucemia, cetoacidose euglicêmica (rara mas grave)',
    'Reduzir dose de insulina em 20–30% ao iniciar SGLT2i. Monitorar glucemia. Alertar sobre cetoacidose euglicêmica',
    'HIPOGLICEMIA + CETOACIDOSE EUGLICÊMICA — SGLT2i + insulina; ajustar dose',
    EvidenceLevel.established,
    {RiskType.hypoglycemia},
    ['EMPA-REG OUTCOME', 'ADA 2024', 'Micromedex 2024']),

  ('dapagliflozina', 'sulfonilureia', InteractionSeverity.moderate,
    'SGLT2i + sulfonilureia: ambos reduzem glucemia por mecanismos diferentes; risco aditivo de hipoglucemia',
    'Hipoglucemia, especialmente se jejum ou exercício',
    'Reduzir dose de sulfonilureia ao iniciar SGLT2i. Monitorar glucemia regularmente',
    'HIPOGLICEMIA — SGLT2i + sulfonilureia; reduzir dose de sulfonilureia',
    EvidenceLevel.established,
    {RiskType.hypoglycemia},
    ['ADA 2024', 'Micromedex 2024']),

  ('dapagliflozina', 'metformina', InteractionSeverity.moderate,
    'Ambos reduzem glucemia; SGLT2i causa diurese osmótica podendo precipitar acidose lática em situações de risco',
    'Acidose lática em situações específicas (desidratação, cirurgia, contraste)',
    'Suspender SGLT2i antes de contraste iodado ou cirurgia de grande porte. Monitorar hidratação',
    'ACIDOSE LÁTICA — SGLT2i + metformina: suspender antes de contraste/cirurgia',
    EvidenceLevel.probable,
    {RiskType.increasedToxicity},
    ['ADA 2024', 'Micromedex 2024']),

  // ── 13. Dexametasona × Antidiabéticos ────────────────────────────────────

  ('dexametasona', 'insulina', InteractionSeverity.moderate,
    'Corticosteroides induzem resistência insulínica e gliconeogênese hepática → hiperglucemia',
    'Hiperglucemia grave, descompensação diabética',
    'Aumentar dose de insulina durante corticoterapia. Monitorar glucemia frecuentemente (a cada 4–6h se hospitalizado)',
    'HIPERGLICEMIA — Corticoide induz resistência insulínica; ajustar insulina',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    ['ADA 2024', 'Goodman & Gilman 14ª ed.', 'Micromedex 2024']),

  ('dexametasona', 'metformina', InteractionSeverity.moderate,
    'Corticosteroides reduzem eficácia da metformina por indução de hiperglucemia persistente',
    'Perda de controle glicêmico durante corticoterapia',
    'Monitorar glucemia. Adicionar insulina se necesario durante o tratamento com corticoide',
    'CONTROLE GLICÊMICO PERDIDO — Corticoide reduz eficácia de antidiabéticos orais',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    ['ADA 2024', 'Micromedex 2024']),

  ('dexametasona', 'sulfonilureia', InteractionSeverity.moderate,
    'Corticosteroides antagonizam o efeito hipoglucemiante das sulfonilureias por resistência insulínica',
    'Hiperglucemia e perda do controle glicêmico',
    'Aumentar frequência de monitoramento glicêmico. Pode ser necesario adicionar insulina',
    'HIPERGLICEMIA — Corticoide antagoniza sulfonilureia',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    ['ADA 2024', 'Micromedex 2024']),

  // ── 14. Quelação — levotiroxina, ciprofloxacino, doxiciclina, eltrombopague × cálcio/ferro ──

  ('levotiroxina', 'sulfato ferroso', InteractionSeverity.major,
    'Ferro forma complexo insolúvel com levotiroxina no trato GI, reduzindo sua absorção em 30–50%',
    'Hipotireoidismo por falha terapéutica da levotiroxina',
    'Administrar levotiroxina 4 horas antes ou após o ferro. Monitorar TSH após mudança',
    'QUELAÇÃO — Separar levotiroxina e ferro por ≥4 horas',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),

  ('levotiroxina', 'carbonato de calcio', InteractionSeverity.major,
    'Cálcio reduz absorção de levotiroxina em 20–40% por formação de complexo insolúvel no GI',
    'Hipotireoidismo por redução da absorção de levotiroxina',
    'Administrar levotiroxina 4 horas antes ou após o cálcio. Monitorar TSH',
    'QUELAÇÃO — Separar levotiroxina e cálcio por ≥4 horas',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    ['Micromedex 2024', 'UpToDate 2024']),

  ('ciprofloxacino', 'sulfato ferroso', InteractionSeverity.major,
    'Ferro forma quelato com ciprofloxacino no GI, reduzindo absorção em 50–90%',
    'Falha terapéutica do ciprofloxacino → risco de infecção não tratada',
    'Administrar ciprofloxacino 2 horas antes ou 6 horas após ferro/antiácidos',
    'QUELAÇÃO — Separar ciprofloxacino e ferro por ≥2 horas',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),

  ('ciprofloxacino', 'carbonato de calcio', InteractionSeverity.major,
    'Cálcio (antiácido/suplemento) quelata ciprofloxacino no GI, reduzindo absorção em 30–50%',
    'Falha terapéutica de ciprofloxacino',
    'Administrar ciprofloxacino 2 horas antes ou 6 horas após cálcio/antiácidos',
    'QUELAÇÃO — Separar ciprofloxacino e cálcio por ≥2 horas',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    ['Micromedex 2024', 'UpToDate 2024']),

  ('eltrombopague', 'sulfato ferroso', InteractionSeverity.major,
    'Eltrombopague tem alta afinidade por metais polivalentes; ferro reduz sua absorção em até 70%',
    'Falha terapéutica do eltrombopague → trombocitopenia persistente',
    'Administrar eltrombopague 4 horas antes ou após ferro, cálcio, alumínio, magnésio',
    'QUELAÇÃO — Separar eltrombopague e ferro por ≥4 horas',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    ['FDA Label Promacta', 'Micromedex 2024']),

  ('eltrombopague', 'carbonato de calcio', InteractionSeverity.major,
    'Cálcio quelata eltrombopague no GI, reduzindo absorção significativamente',
    'Falha terapéutica → trombocitopenia',
    'Separar eltrombopague e cálcio por ≥4 horas',
    'QUELAÇÃO — Separar eltrombopague e cálcio por ≥4 horas',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    ['FDA Label Promacta', 'Micromedex 2024']),

  // ── 15. Salbutamol / Fenoterol × Teofilina / Furosemida ──────────────────

  ('salbutamol', 'teofilina', InteractionSeverity.major,
    'Ambos são broncodilatadores; teofilina tem janela terapéutica estreita; salbutamol pode aumentar toxicidad de teofilina via redução de K+',
    'Taquicardia, arritmias, hipopotasemia e toxicidad por teofilina',
    'Monitorar FC, K+ sérico e nível de teofilina. Evitar doses altas de salbutamol',
    'TAQUICARDIA E HIPOCALEMIA — Salbutamol + teofilina',
    EvidenceLevel.established,
    {RiskType.arrhythmia, RiskType.hypokalemia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),

  ('salbutamol', 'furosemida', InteractionSeverity.moderate,
    'Ambos causam hipopotasemia; salbutamol por redistribuição intracelular de K+ (β2); furosemida por perda urinária',
    'Hipocalemia grave, arritmias cardíacas',
    'Monitorar K+ sérico. Repor potássio se necesario. Evitar altas doses de salbutamol nebulizado',
    'HIPOCALEMIA ADITIVA — Salbutamol + furosemida; monitorar K+',
    EvidenceLevel.established,
    {RiskType.hypokalemia, RiskType.arrhythmia},
    ['Micromedex 2024', 'UpToDate 2024']),

  // ── 16. Ritonavir/Paxlovid × AODs / Dronedarona ──────────────────────────

  ('ritonavir', 'apixabana', InteractionSeverity.major,
    'Ritonavir inibe potentemente CYP3A4 e P-gp, elevando os níveis de apixabana em 2–3 vezes',
    'Risco hemorrágico grave por superdose de apixabana',
    'Evitar combinación. Se anticoagulação necessária durante Paxlovid, substituir por heparina de baixo peso molecular',
    'NÍVEL APIXABANA 2–3× ELEVADO — Ritonavir inibe CYP3A4/P-gp; usar HBPM',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    ['FDA Label Paxlovid 2021', 'Micromedex 2024', 'UpToDate 2024']),

  ('ritonavir', 'rivaroxabana', InteractionSeverity.contraindicated,
    'Ritonavir inibe CYP3A4 e P-gp elevando os níveis de rivaroxabana em 2,5–3,5 vezes',
    'Risco hemorrágico grave e risco de morte',
    'Contraindicado. Substituir por HBPM durante curso de Paxlovid (5 dias)',
    'CONTRAINDICADO — Rivaroxabana 2,5–3,5× elevada por ritonavir',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    ['FDA Label Paxlovid 2021', 'Micromedex 2024']),

  ('ritonavir', 'dabigatrana', InteractionSeverity.major,
    'Ritonavir inibe P-gp, principal via de eliminação da dabigatrana, elevando seus níveis em ~50%',
    'Risco hemorrágico aumentado',
    'Evitar. Substituir dabigatrana por HBPM durante Paxlovid',
    'NÍVEL DABIGATRANA ELEVADO — Ritonavir inibe P-gp',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    ['FDA Label Paxlovid 2021', 'Micromedex 2024']),

  ('ritonavir', 'dronedarona', InteractionSeverity.contraindicated,
    'Ritonavir inibe CYP3A4; dronedarona é substrato exclusivo de CYP3A4 — elevação de nível >10 vezes',
    'Prolongamento do QT grave, Torsades de Pointes e risco de morte',
    'Contraindicado. Substituir dronedarona por amiodarona ou outro antiarrítmico durante Paxlovid',
    'CONTRAINDICADO — Dronedarona >10× elevada por ritonavir: risco de morte',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia, RiskType.plasmaLevel},
    ['FDA Label Paxlovid', 'Micromedex 2024', 'ESC 2020']),

  // ── 17. Interações especiais ──────────────────────────────────────────────

  ('anticoncepcional', 'rifampicina', InteractionSeverity.major,
    'Rifampicina induz CYP3A4 e glicuronoconjugação, reduzindo drásticamente os níveis de etinilestradiol e progestágenos em 40–70%',
    'Falha contraceptiva com gravidez não planejada',
    'Usar método contraceptivo adicional (preservativo) durante e por 4 semanas após rifampicina. Considerar LARC',
    'FALHA CONTRACEPTIVA — Rifampicina reduz nível do anticoncepcional 40–70%',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'WHO MEC 2015']),

  ('anticoncepcional', 'acido tranexamico', InteractionSeverity.major,
    'Ácido tranexâmico inibe fibrinólise; anticoncepcionais orais aumentam estado pró-trombótico — efeito tromboembólico aditivo',
    'Risco aumentado de tromboembolismo venoso e arterial',
    'Evitar uso combinado, especialmente em pacientes com outros fatores de risco tromboembólico',
    'RISCO TROMBOEMBÓLICO — Anticoncepcional + ácido tranexâmico',
    EvidenceLevel.probable,
    {RiskType.thrombosis},
    ['Micromedex 2024', 'UpToDate 2024']),

  ('azitromicina', 'amiodarona', InteractionSeverity.contraindicated,
    'Ambos prolongam o QT por bloqueio hERG; azitromicina prolonga QT moderadamente, amiodarona prolonga significativamente — efeito aditivo grave',
    'Torsades de Pointes e morte súbita cardíaca',
    'Contraindicado. Substituir azitromicina por amoxicilina ou doxiciclina. Monitorar ECG se uso inevitável',
    'CONTRAINDICADO — QT aditivo: azitromicina + amiodarona = risco de Torsade fatal',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    ['FDA 2013', 'CredibleMeds 2024', 'Micromedex 2024']),

  ('metformina', 'contraste iodado', InteractionSeverity.major,
    'Contraste iodado pode causar nefropatia aguda → reduz excreção renal de metformina → acúmulo → acidose lática',
    'Acidose lática grave com risco de morte',
    'Suspender metformina 48h antes do contraste. Reiniciar apenas após confirmar función renal estável (48h após)',
    'ACIDOSE LÁTICA — Suspender metformina 48h antes do contraste iodado',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.increasedToxicity},
    ['ACR Manual on Contrast Media 2023', 'Micromedex 2024', 'UpToDate 2024']),

  ('glibenclamida', 'sulfametoxazol', InteractionSeverity.major,
    'Sulfametoxazol-trimetoprima inibe CYP2C9 (metabolismo da glibenclamida) + possui ação hipoglucemiante própria (estrutura semelhante a sulfonilureias)',
    'Hipoglucemia grave, prolongada e potencialmente fatal',
    'Evitar combinación. Se antibiótico necesario, substituir por alternativa sem ação hipoglucemiante. Monitorar glucemia rigurosamente',
    'HIPOGLICEMIA GRAVE — SMX-TMP + glibenclamida: dupla ação hipoglucemiante',
    EvidenceLevel.established,
    {RiskType.hypoglycemia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),

  ('clopidogrel', 'omeprazol', InteractionSeverity.major,
    'Omeprazol inibe CYP2C19, enzima necessária para conversão do clopidogrel em seu metabólito ativo, reduzindo atividade antiagregante em 45%',
    'Reducción de la eficacia do clopidogrel → risco de trombosis de stent e eventos cardiovasculares',
    'Preferir pantoprazol ou rabeprazol (menor inibição de CYP2C19). Evitar omeprazol/esomeprazol em pacientes em uso de clopidogrel',
    'CLOPIDOGREL 45% MENOS EFICAZ — Omeprazol inibe CYP2C19; usar pantoprazol',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    ['FDA 2010', 'AHA 2010', 'Micromedex 2024', 'UpToDate 2024']),

  ('metotrexato', 'omeprazol', InteractionSeverity.major,
    'Omeprazol (IBP) reduz excreção renal de metotrexato ao inibir transportadores tubulares (OAT1/OAT3), elevando seus niveles plasmáticos',
    'Toxicidade por metotrexato: mielosupresión, mucosites, hepatotoxicidad',
    'Evitar IBPs em pacientes com metotrexato em doses altas. Se necesario, suspender IBP 48h antes e após dose de metotrexato',
    'TOXICIDADE DE METOTREXATO — IBP reduz excreção renal de MTX',
    EvidenceLevel.established,
    {RiskType.myelosuppression, RiskType.hepatotoxicity, RiskType.plasmaLevel},
    ['Micromedex 2024', 'UpToDate 2024']),

  ('heparina', 'alteplase', InteractionSeverity.major,
    'Ambos aumentam risco hemorrágico; alteplase dissolve coágulos e heparina inibe coagulação — efeito antitrombótico máximo com alto risco de sangrado grave',
    'Hemorragia grave, incluindo sangrado intracraneal',
    'Suspender heparina IV durante infusão de alteplase em AVC isquêmico. Retomar apenas após 24h e TC sem hemorragia',
    'RISCO HEMORRÁGICO GRAVE — Suspender heparina durante trombolítico',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    ['AHA/ASA Stroke Guidelines 2023', 'Micromedex 2024']),

  ('hidroxicloroquina', 'azitromicina', InteractionSeverity.major,
    'Ambos prolongam QT por bloqueio de canais hERG; combinação foi amplamente estudada durante COVID-19 com alto risco confirmado',
    'Prolongamento do QT grave, Torsades de Pointes e morte súbita',
    'Evitar combinación. Se anti-infeccioso necesario em paciente com hidroxicloroquina, preferir amoxicilina ou doxiciclina',
    'RISCO DE TORSADE — Hidroxicloroquina + azitromicina: combinação de alto risco',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    ['FDA Safety Alert 2020', 'CredibleMeds 2024', 'Micromedex 2024']),

  ('hidroxicloroquina', 'amiodarona', InteractionSeverity.contraindicated,
    'Ambos prolongam QT de forma significativa; hidroxicloroquina é QT prolongador estabelecido; amiodarona idem — risco máximo de somação',
    'Torsades de Pointes e morte súbita',
    'Contraindicado. Substituir hidroxicloroquina por outro antirreumático ou amiodarona por outro antiarrítmico',
    'CONTRAINDICADO — QT aditivo máximo: hidroxicloroquina + amiodarona',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    ['CredibleMeds 2024', 'Micromedex 2024']),

  // ── LOTE 7 — Interações críticas: novos fármacos Lote 6 ──────────────────
  // Dextrometorfano, Pseudoefedrina, Montelukast, Cetirizina

  // ── 7.1 DEXTROMETORFANO ──────────────────────────────────────────────────

  ('dextrometorfano', 'isrs', InteractionSeverity.contraindicated,
    'Dextrometorfano é agonista fraco de receptores serotoninérgicos e inibe recaptação de serotonina; ISRSs potencializam massivamente a atividade serotoninérgica central — risco máximo de síndrome serotoninérgica',
    'Síndrome serotoninérgica: agitação, hipertermia, tremores, mioclonias, diarreia, taquicardia, diaforese, rigidez muscular — pode evoluir para rabdomiólisis, CID e óbito',
    'CONTRAINDICADO. Evitar qualquer antitussivo com dextrometorfano em pacientes em uso de ISRSs (fluoxetina, sertralina, paroxetina, escitalopram, fluvoxamina). Substituir por antitussivo não serotoninérgico (ex: levodropropizina, butamirato)',
    'CONTRAINDICADO — Síndrome serotoninérgica: dextrometorfano + ISRS',
    EvidenceLevel.established,
    {RiskType.serotonin},
    ['FDA Drug Safety 2010', 'CredibleMeds 2024', 'Micromedex 2024', 'Serotonin Syndrome: Recognition and Treatment — AAFP 2017']),

  ('dextrometorfano', 'imao', InteractionSeverity.contraindicated,
    'IMAOs inibem degradação de serotonina e monoaminas; dextrometorfano inibe recaptação de serotonina e é agonista sigma-1 — combinação resulta em acúmulo massivo de serotonina no SNC',
    'Síndrome serotoninérgica grave/fulminante: hipertermia >41°C, hipertensão, convulsiones, coma — risco de morte',
    'CONTRAINDICADO de forma absoluta. Aguardar washout completo do IMAO (≥14 dias para irreversíveis fenelzina/tranilcipromina; ≥24h para moclobemida) antes de qualquer antitussivo com dextrometorfano',
    'CONTRAINDICADO ABSOLUTO — Síndrome serotoninérgica fatal: dextrometorfano + IMAO',
    EvidenceLevel.established,
    {RiskType.serotonin},
    ['FDA Drug Safety 2010', 'CredibleMeds 2024', 'Sternbach 1991 — Serotonin Syndrome', 'Boyer & Shannon NEJM 2005']),

  ('dextrometorfano', 'tramadol', InteractionSeverity.contraindicated,
    'Tramadol inibe recaptação de serotonina e noradrenalina, é agonista µ fraco e metabolizado pelo CYP2D6 (mesmo que dextrometorfano) — duplo mecanismo serotoninérgico + competição CYP2D6 eleva níveis de ambos',
    'Síndrome serotoninérgica; aumento de niveles plasmáticos de tramadol e dextrometorfano por inhibición competitiva do CYP2D6',
    'Contraindicado. Substituir antitussivo por levodropropizina ou butamirato em pacientes usando tramadol',
    'CONTRAINDICADO — Síndrome serotoninérgica + competição CYP2D6: dextrometorfano + tramadol',
    EvidenceLevel.probable,
    {RiskType.serotonin, RiskType.plasmaLevel},
    ['Micromedex 2024', 'CredibleMeds 2024']),

  ('dextrometorfano', 'duloxetina', InteractionSeverity.contraindicated,
    'Duloxetina é ISRN e inibidor potente do CYP2D6 — eleva marcadamente os níveis de dextrometorfano (substrato CYP2D6) e potencializa atividade serotoninérgica',
    'Síndrome serotoninérgica; aumento de 3–8× nos niveles plasmáticos de dextrometorfano por inhibición do CYP2D6',
    'Contraindicado. Usar antitussivo não serotoninérgico e não metabolizado pelo CYP2D6 (levodropropizina, butamirato)',
    'CONTRAINDICADO — Síndrome serotoninérgica + inibição CYP2D6: dextrometorfano + duloxetina',
    EvidenceLevel.established,
    {RiskType.serotonin, RiskType.plasmaLevel},
    ['FDA Drug Safety 2010', 'Micromedex 2024', 'CredibleMeds 2024']),

  ('dextrometorfano', 'amiodarona', InteractionSeverity.major,
    'Amiodarona é inibidor potente do CYP2D6 — aumenta significativamente a biodisponibilidade oral do dextrometorfano (substrato CYP2D6); pode elevar concentrações 4–10×',
    'Toxicidade pelo dextrometorfano: vertigem, sedação excessiva, ataxia, nistagmo, disforia, efeitos alucinatórios em doses terapéuticas',
    'Evitar combinación. Se necesario, usar dose mínima de dextrometorfano e monitorar sinais de toxicidad. Preferir antitussivos não dependentes do CYP2D6',
    'CUIDADO — Toxicidade por dextrometorfano: inibição CYP2D6 pela amiodarona',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel},
    ['Micromedex 2024', 'CYP2D6 Inhibitor Interactions — FDA']),

  ('dextrometorfano', 'fluoxetina', InteractionSeverity.contraindicated,
    'Fluoxetina é inibidor potente do CYP2D6 e ISRS — bloqueia o metabolismo do dextrometorfano (substrato CYP2D6) e soma atividade serotoninérgica — duplo mecanismo de toxicidad',
    'Síndrome serotoninérgica; elevação drástica dos níveis de dextrometorfano (↑5–10×) com risco de toxicidad SNC',
    'Contraindicado. Washout de fluoxetina exige ≥5 semanas (meia-vida longa). Substituir antitussivo por levodropropizina ou butamirato',
    'CONTRAINDICADO — Síndrome serotoninérgica + inibição CYP2D6 severa: dextrometorfano + fluoxetina',
    EvidenceLevel.established,
    {RiskType.serotonin, RiskType.plasmaLevel},
    ['FDA Drug Safety 2010', 'CredibleMeds 2024', 'Micromedex 2024']),

  ('dextrometorfano', 'paroxetina', InteractionSeverity.contraindicated,
    'Paroxetina é o inibidor mais potente do CYP2D6 entre os ISRSs — eleva os níveis de dextrometorfano em até 9× e soma atividade serotoninérgica',
    'Síndrome serotoninérgica grave; toxicidad pelo dextrometorfano com efeitos dissociativos e alucinatórios',
    'Contraindicado. Substituir antitussivo por levodropropizina ou butamirato',
    'CONTRAINDICADO — CYP2D6 + serotonina: dextrometorfano + paroxetina',
    EvidenceLevel.established,
    {RiskType.serotonin, RiskType.plasmaLevel},
    ['FDA Drug Safety 2010', 'CredibleMeds 2024']),

  ('dextrometorfano', 'codeina', InteractionSeverity.moderate,
    'Dextrometorfano e codeína competem pelo CYP2D6 para metabolização; em metabolizadores lentos pode haver acúmulo de ambos; risco adicional de depresión respiratoria em combinações com opioides',
    'Sedación excesiva, depresión respiratoria em polimorfismos CYP2D6; efeito antitussivo duplicado sem benefício adicional',
    'Evitar uso concomitante. Não há benefício clínico em combinar dois antitussivos. Escolher apenas um',
    'EVITAR — Depressão respiratória aditiva + competição CYP2D6: dextrometorfano + codeína',
    EvidenceLevel.probable,
    {RiskType.respiratoryDepression, RiskType.plasmaLevel},
    ['Micromedex 2024', 'CredibleMeds 2024']),

  // ── 7.2 PSEUDOEFEDRINA ──────────────────────────────────────────────────

  ('pseudoefedrina', 'imao', InteractionSeverity.contraindicated,
    'IMAOs inibem a MAO-A e MAO-B responsáveis pela degradação de catecolaminas; pseudoefedrina libera noradrenalina e adrenalina nas terminações simpáticas — acúmulo massivo de catecolaminas causa crise adrenérgica',
    'Crise hipertensiva grave (PA sistólica >220 mmHg), encefalopatia hipertensiva, AVC hemorrágico, infarto agudo do miocárdio, morte',
    'CONTRAINDICADO de forma absoluta. Aguardar ≥14 dias após suspensão de IMAO irreversível (fenelzina, tranilcipromina) e ≥24h após moclobemida antes de usar pseudoefedrina ou qualquer descongestionante simpatomimético',
    'CONTRAINDICADO ABSOLUTO — Crise hipertensiva fatal: pseudoefedrina + IMAO',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    ['FDA Drug Safety', 'CredibleMeds 2024', 'Micromedex 2024', 'Gillman PK 2005 — MAOIs and sympathomimetics']),

  ('pseudoefedrina', 'betabloqueador', InteractionSeverity.moderate,
    'Pseudoefedrina ativa receptores α-adrenérgicos (vasoconstrição) e β-adrenérgicos (taquicardia, broncodilatação); betabloqueadores bloqueiam receptores β — efeito α fica desimpedido, resultando em vasoconstrição sem taquicardia reflexa (resposta β bloqueada) — pode elevar PA',
    'Hipertensão paradoxal; bradicardia reflexa mediada por barorreceptores (sem compensação β); broncoespasmo em betabloqueadores não seletivos (propranolol, atenolol, carvedilol) — risco aumentado em asmáticos/DPOC',
    'Evitar uso concomitante. Se necesario: preferir betabloqueadores β1-seletivos (metoprolol, bisoprolol), monitorar PA e FC. Evitar em pacientes com asma/DPOC se betabloqueador não for seletivo',
    'CUIDADO — Hipertensão paradoxal + broncoespasmo potencial: pseudoefedrina + betabloqueador',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    ['Micromedex 2024', 'CredibleMeds 2024', 'Drugs.com Interactions 2024']),

  ('pseudoefedrina', 'metoprolol', InteractionSeverity.moderate,
    'Metoprolol bloqueia seletivamente receptores β1-adrenérgicos cardíacos; pseudoefedrina ativa tanto β quanto α; a seletividade β1 do metoprolol reduz parcialmente o antagonismo — efeito vasoconstritor α permanece',
    'Elevação da PA (efeito α desimpedido); redução da taquicardia reflexa esperada; menor risco de broncoespasmo que com betabloqueadores não seletivos',
    'Monitorar PA e FC durante uso concomitante. Preferir descongestionante alternativo quando possível. Evitar em crises hipertensivas não controladas',
    'ATENÇÃO — Elevação de PA: pseudoefedrina + metoprolol',
    EvidenceLevel.probable,
    {RiskType.cardiovascular},
    ['Micromedex 2024', 'CredibleMeds 2024']),

  ('pseudoefedrina', 'enalapril', InteractionSeverity.moderate,
    'Pseudoefedrina eleva a PA por vasoconstrição α-adrenérgica; IECAs como enalapril são anti-hipertensivos — antagonismo farmacológico direto na regulação pressórica',
    'Reducción de la eficacia anti-hipertensiva do enalapril; elevação transitória da PA; risco aumentado em hipertensos',
    'Evitar uso prolongado de descongestionantes simpatomimíticos em hipertensos. Usar apenas por ≤3 dias, monitorar PA diariamente. Preferir lavagem nasal salina ou corticoide nasal tópico como alternativas',
    'ATENÇÃO — Antagonismo anti-hipertensivo: pseudoefedrina + enalapril',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    ['Micromedex 2024', 'CredibleMeds 2024', 'JNC 8 Guidelines']),

  ('pseudoefedrina', 'losartana', InteractionSeverity.moderate,
    'Pseudoefedrina eleva PA por ativação adrenérgica; losartana bloqueia receptor AT1 da angiotensina II — antagonismo no controle pressórico',
    'Atenuação do efeito anti-hipertensivo da losartana; elevação da PA especialmente em picos de absorção da pseudoefedrina',
    'Evitar uso em hipertensos não controlados. Limitar a ≤3 dias de uso e monitorar PA. Preferir alternativas não sistêmicas para congestão nasal',
    'ATENÇÃO — Atenuação de anti-hipertensivo: pseudoefedrina + losartana',
    EvidenceLevel.probable,
    {RiskType.cardiovascular},
    ['Micromedex 2024', 'Drugs.com 2024']),

  ('pseudoefedrina', 'digoxina', InteractionSeverity.major,
    'Pseudoefedrina aumenta a automaticidade do nó sinusal e sensibiliza o miocárdio à estimulação adrenérgica; digoxina inibe Na+/K+-ATPase e aumenta tônus vagal — combinação favorece arritmias',
    'Arritmias cardíacas (taquicardia supraventricular, fibrilação atrial, extrassístoles ventriculares) em pacientes digitalizados',
    'Evitar uso concomitante. Se necesario, monitorar ECG e níveis de digoxina. Usar descongestionante alternativo (spray nasal salino, corticoide intranasal)',
    'CUIDADO — Arritmias cardíacas: pseudoefedrina + digoxina',
    EvidenceLevel.probable,
    {RiskType.arrhythmia, RiskType.cardiovascular},
    ['Micromedex 2024', 'CredibleMeds 2024']),

  ('pseudoefedrina', 'amitriptilina', InteractionSeverity.major,
    'Antidepressivos tricíclicos bloqueiam o transportador de noradrenalina (NET) e bloqueiam receptores α1-adrenérgicos — inibem o mecanismo de ação da pseudoefedrina mas também aumentam a suscetibilidade cardiovascular a arritmias',
    'Hipertensão paradoxal; taquicardia; arritmias; potencialização de efeitos adversos cardiovasculares de ambos os fármacos',
    'Evitar combinación. Tricíclicos + simpaticomiméticos são combinação clássica de risco cardiovascular. Usar descongestionante tópico nasal como alternativa',
    'CUIDADO — Arritmias e hipertensão: pseudoefedrina + amitriptilina',
    EvidenceLevel.probable,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    ['Micromedex 2024', 'CredibleMeds 2024']),

  // ── 7.3 MONTELUKAST ─────────────────────────────────────────────────────

  ('montelukast', 'rifampicina', InteractionSeverity.major,
    'Rifampicina é indutor potente do CYP3A4 e CYP2C8/2C9 — acelera o metabolismo do montelukast (substrato CYP3A4/2C8), reduzindo sua biodisponibilidade oral',
    'Redução de 40–60% nos niveles plasmáticos de montelukast; falha terapéutica no controle da asma ou rinite alérgica; risco de exacerbação broncospástica por perda de efeito antiinflamatório',
    'Monitorar eficácia clínica do montelukast durante uso de rifampicina. Considerar aumento de dose ou substituição por corticoide inalatório como principal terapia anti-inflamatória enquanto rifampicina estiver em uso',
    'ALTO RISCO DE FALHA TERAPÊUTICA — Indução CYP: montelukast + rifampicina',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    ['FDA Drug Label Montelukast 2024', 'Micromedex 2024', 'CredibleMeds 2024']),

  ('montelukast', 'fenitoina', InteractionSeverity.moderate,
    'Fenitoína é indutor moderado/forte do CYP3A4 e CYP2C8 — aumenta o clearance do montelukast e reduz seus niveles plasmáticos em 40–50%',
    'Reducción de la eficacia do montelukast; possível piora do controle da asma ou rinite; perda de proteção contra broncospasmo induzido por exercício',
    'Monitorar controle da asma clinicamente (frequência de broncodilatadores de resgate, sintomas noturnos). Considerar corticoide inalatório como terapia principal. Se montelukast for mantido, avaliar aumento de dose',
    'ATENÇÃO — Redução de eficácia: montelukast + fenitoína',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    ['Micromedex 2024', 'CredibleMeds 2024', 'Drug Interactions in Epilepsy — Lancet Neurology 2022']),

  ('montelukast', 'carbamazepina', InteractionSeverity.moderate,
    'Carbamazepina é indutor potente do CYP3A4 e moderado do CYP2C8 — reduz significativamente os niveles plasmáticos de montelukast por aumento do clearance hepático',
    'Reducción de la eficacia antiinflamatória e broncodilatadora indireta do montelukast; possível falha no controle de asma alérgica e rinite',
    'Monitorar controle da asma em pacientes epilépticos usando carbamazepina + montelukast. Considerar corticoide inalatório como alternativa mais robusta',
    'ATENÇÃO — Indução CYP3A4: montelukast + carbamazepina',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    ['Micromedex 2024', 'CredibleMeds 2024']),

  ('montelukast', 'fluconazol', InteractionSeverity.moderate,
    'Fluconazol inibe CYP2C9 e CYP3A4 — pode aumentar os niveles plasmáticos de montelukast por redução do clearance',
    'Aumento dos níveis de montelukast com potencial aumento de reações adversas neuropsiquiátricas (ansiedade, distúrbios do sono, comportamento)',
    'Monitorar sintomas neuropsiquiátricos durante uso concomitante. Suspender montelukast se surgirem alterações de comportamento ou humor',
    'ATENÇÃO — Aumento de montelukast: montelukast + fluconazol',
    EvidenceLevel.possible,
    {RiskType.plasmaLevel},
    ['Micromedex 2024']),

  ('montelukast', 'gemfibrozila', InteractionSeverity.moderate,
    'Gemfibrozila inibe potentemente o CYP2C8 — principal enzima responsável pelo metabolismo do montelukast; pode elevar seus niveles plasmáticos em 4–5×',
    'Aumento significativo nos níveis de montelukast; risco amplificado de efeitos adversos neuropsiquiátricos (insônia, agitação, depressão, pensamentos suicidas)',
    'Evitar combinación sempre que possível. Se necessária, monitorar de perto sintomas neuropsiquiátricos. Considerar alternativa a gemfibrozila (fenofibrato tem menor inibição do CYP2C8)',
    'CUIDADO — Toxicidade neuropsiquiátrica: montelukast + gemfibrozila',
    EvidenceLevel.established,
    {RiskType.plasmaLevel},
    ['FDA Drug Label Montelukast 2024', 'Micromedex 2024', 'CredibleMeds 2024']),

  // ── 7.4 CETIRIZINA ──────────────────────────────────────────────────────

  ('cetirizina', 'benzodiazepínico', InteractionSeverity.moderate,
    'Cetirizina, apesar de ser anti-histamínico de 2ª geração com menor penetração no SNC que os de 1ª geração, pode causar sedação especialmente em doses altas ou em idosos; benzodiazepínicos são depressores do SNC — somação de efeitos sedativos',
    'Sedação excessiva; comprometimento psicomotor; risco de quedas (especialmente em idosos); sonolência diurna; déficit cognitivo agudo',
    'Usar com cautela. Preferir cetirizina à noite. Reduzir dose de benzodiazepínico se sedação for excessiva. Evitar em idosos (critérios de Beers). Alertar paciente sobre não dirigir ou operar máquinas',
    'CUIDADO — Sedação aditiva: cetirizina + benzodiazepínico',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression},
    ['Beers Criteria AGS 2023', 'Micromedex 2024', 'CredibleMeds 2024']),

  ('cetirizina', 'opioide', InteractionSeverity.moderate,
    'Cetirizina tem propriedades anticolinérgicas leves e sedativas — some com efeitos sedativos e depressores respiratórios dos opioides',
    'Sedação excessiva; depresión respiratoria potencializada; constipação aumentada (efeitos anticolinérgicos aditivos); risco de retenção urinária',
    'Monitorar estado de consciência e padrão respiratório. Preferir anti-histamínico com menor ação sedativa ou anticolinérgica. Atenção redobrada em idosos e pacientes com DPOC/apneia do sono',
    'ATENÇÃO — Depressão do SNC aditiva: cetirizina + opioide',
    EvidenceLevel.probable,
    {RiskType.respiratoryDepression},
    ['Micromedex 2024', 'CredibleMeds 2024']),

  ('cetirizina', 'ritonavir', InteractionSeverity.moderate,
    'Ritonavir é inibidor do CYP3A4 e inibidor da glicoproteína-P — pode elevar os niveles plasmáticos de cetirizina, que é parcialmente eliminada pelo rim mas também tem transporte dependente de P-gp',
    'Elevação dos níveis de cetirizina com possível aumento de sedação e efeitos anticolinérgicos; prolongamento do efeito',
    'Monitorar sedação excessiva. Reduzir dose de cetirizina se necesario (considerar 5 mg ao invés de 10 mg). Preferir fexofenadina como alternativa (menor interação com P-gp)',
    'ATENÇÃO — Elevação de cetirizina: cetirizina + ritonavir',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel},
    ['Micromedex 2024', 'FDA Drug Interaction Studies']),

  ('cetirizina', 'teofilina', InteractionSeverity.minor,
    'Teofilina pode reduzir ligeiramente o clearance da cetirizina — mecanismo não completamente elucidado, possivelmente via inibição competitiva de transporte renal',
    'Aumento leve de ~16% na AUC da cetirizina; risco clínico mínimo, mas pode ampliar sedação em doses altas',
    'Monitorar sedação em pacientes com asma ou DPOC usando teofilina + cetirizina. Relevância clínica baixa em doses padrão',
    'MONITORAR — Leve elevação de cetirizina: cetirizina + teofilina',
    EvidenceLevel.established,
    {RiskType.plasmaLevel},
    ['FDA Drug Label Cetirizina', 'Micromedex 2024']),

  ('cetirizina', 'alcool', InteractionSeverity.moderate,
    'Álcool etílico é depressor do SNC; cetirizina tem efeito sedativo variável (maior em doses altas, idosos e metabolizadores lentos) — somação dos efeitos depressores centrais',
    'Sedação acentuada; comprometimento da coordenação motora; lentificação dos reflexos; risco de acidentes de trânsito; tontura',
    'Evitar consumo de álcool durante uso de cetirizina. Alertar especialmente pacientes que dirigem ou operam máquinas. Preferir cetirizina ao deitar para minimizar impacto diurno',
    'CUIDADO — Sedação aditiva: cetirizina + álcool',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression},
    ['FDA Drug Label Cetirizina 2024', 'Micromedex 2024']),

  // ── 7.5 FENILEFRINA ─────────────────────────────────────────────────────

  ('fenilefrina', 'imao', InteractionSeverity.contraindicated,
    'Fenilefrina é agonista α1-adrenérgico direto; IMAOs bloqueiam degradação de catecolaminas — potencialização extrema do efeito vasopressor da fenilefrina',
    'Crise hipertensiva grave; encefalopatia hipertensiva; AVC; infarto agudo do miocárdio',
    'CONTRAINDICADO. Aguardar washout completo de IMAO (≥14 dias para irreversíveis; ≥24h para moclobemida)',
    'CONTRAINDICADO ABSOLUTO — Crise hipertensiva: fenilefrina + IMAO',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    ['FDA Drug Safety', 'Micromedex 2024', 'CredibleMeds 2024']),

  ('fenilefrina', 'betabloqueador', InteractionSeverity.moderate,
    'Betabloqueadores bloqueiam a vasodilatação β2-mediada — efeito vasoconstritor α1 da fenilefrina fica desimpedido, podendo causar elevação pressórica e bradicardia reflexa',
    'Hipertensão paradoxal; bradicardia reflexa; aumento da pós-carga cardíaca',
    'Evitar combinación em hipertensos e cardiopatas. Se necesario, monitorar PA e FC durante uso',
    'CUIDADO — Hipertensão paradoxal: fenilefrina + betabloqueador',
    EvidenceLevel.probable,
    {RiskType.cardiovascular},
    ['Micromedex 2024', 'CredibleMeds 2024']),


  // ── Dislipidemia: Fibratos e Resinas ─────────────────────────────────────────

  ('gemfibrozil', 'pravastatina', InteractionSeverity.major,
    'Inibição da glicuronidação da estatina pelo gemfibrozil, aumentando drásticamente os niveles plasmáticos',
    'Risco altíssimo de miopatia grave e rabdomiólisis fatal',
    'Evitar a combinação. Se fibrato for essencial, o fenofibrato é preferível e mais seguro com estatinas',
    'ALTO RISCO DE RABDOMIÓLISE — Contraindicado',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),

  ('gemfibrozil', 'repaglinida', InteractionSeverity.contraindicated,
    'Inibição potente do CYP2C8 e OATP1B1 pelo gemfibrozil',
    'Aumento de até 8 vezes na concentração de repaglinida, causando hipoglucemia severa e prolongada',
    'Combinação contraindicada.',
    'HIPOGLICEMIA GRAVE — Contraindicado',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.hypoglycemia},
    [_kRefMdx, _kRefFDA]),

  ('colestiramina', 'warfarina', InteractionSeverity.moderate,
    'Ligação da resina à varfarina no lúmen intestinal',
    'Redução da absorção da varfarina, diminuindo o INR e elevando o risco trombótico',
    'Administrar varfarina pelo menos 1 hora antes ou 4 a 6 horas após a colestiramina',
    'MONITORAR INR — Risco de falha terapéutica',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx]),

  ('colestiramina', 'levotiroxina', InteractionSeverity.major,
    'Sequestro da levotiroxina no trato gastrointestinal formando complexo insolúvel',
    'Falha no tratamento do hipotireoidismo (elevação do TSH)',
    'Separar a administração por pelo menos 4 a 6 horas',
    'FALHA DE ABSORÇÃO — Espaçar doses rigurosamente',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefMdx, _kRefUT]),

  // ── Hepatite C: Antivirais de Ação Direta ─────────────────────────────────────

  ('sofosbuvir', 'amiodarona', InteractionSeverity.contraindicated,
    'Mecanismo desconhecido, possivelmente disfunção acentuada do nó sinusal miocárdico',
    'Bradicardia sintomática grave, bloqueio cardíaco fatal ou necessidade de marcapasso',
    'Combinação totalmente contraindicada. Si inevitable, monitoramento cardíaco contínuo hospitalar por 48h',
    'BRADICARDIA FATAL — Contraindicado',
    EvidenceLevel.established,
    {RiskType.arrhythmia, RiskType.cardiovascular},
    [_kRefFDA, _kRefMdx, _kRefUT]),

  ('ledipasvir', 'omeprazol', InteractionSeverity.major,
    'O ledipasvir necessita de ambiente ácido no estômago para ser absorvido. Os IBP anulam essa acidez',
    'Falha virológica no tratamento da Hepatite C por subdosagem de ledipasvir',
    'Evitar IBP. Se necesario, administrar simultaneamente com estômago vazio usando dose máx de omeprazol 20mg',
    'FALHA TERAPÊUTICA — Absorção comprometida',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefFDA, _kRefUT]),

  ('velpatasvir', 'carbamazepina', InteractionSeverity.major,
    'Indução potente da P-glicoproteína (P-gp) e CYP450 pela carbamazepina',
    'Redução drástica nos níveis de velpatasvir, levando à perda de eficácia antiviral',
    'Evitar o uso concomitante de indutores fortes durante o tratamento da Hepatite C',
    'PERDA DE EFICÁCIA ANTIVIRAL — Evitar combinación',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.reducedEfficacy},
    [_kRefMdx]),

  // ── Psiquiatria: Antipsicóticos Atípicos ──────────────────────────────────────

  ('clozapina', 'carbamazepina', InteractionSeverity.contraindicated,
    'Efeito aditivo/sinérgico na toxicidad da medula óssea',
    'Aumento dramático no risco de agranulocitose e aplasia medular fatal',
    'Combinação absolutamente contraindicada. Escolher outro estabilizador do humor (ex: Valproato)',
    'AGRANULOCITOSE FATAL — Contraindicado',
    EvidenceLevel.established,
    {RiskType.myelosuppression},
    [_kRefGG, _kRefMdx, _kRefUT]),

  ('ziprasidona', 'amiodarona', InteractionSeverity.contraindicated,
    'Sinergismo na inibição dos canais de potássio retificadores miocárdicos (hERG)',
    'Prolongação extrema do intervalo QT e risco de Torsades de Pointes',
    'Contraindicado o uso conjunto com outros fármacos que prolongam o QT de forma conhecida',
    'RISCO DE TORSADES DE POINTES — Contraindicado',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefMdx, _kRefUT]),

  ('cariprazina', 'cetoconazol', InteractionSeverity.moderate,
    'Inhibición potente del CYP3A4 pelo cetoconazol',
    'Aumento significativo das concentrações de cariprazina e seus metabólitos ativos (DDCAR)',
    'Reduzir a dose de cariprazina à metade e monitorar acatisia e parkinsonismo',
    'RISCO EXTRAPIRAMIDAL — Reduzir dose',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel, RiskType.increasedToxicity},
    [_kRefMdx, _kRefFDA]),

  ('lurasidona', 'diltiazem', InteractionSeverity.major,
    'Inibição moderada a forte do CYP3A4 pelo diltiazem',
    'Elevação aguda da lurasidona, aumentando sedação, acatisia e hipotensão',
    'A dose de lurasidona não deve exceder 40 mg/dia quando coadministrada com diltiazem',
    'AJUSTE DE DOSE NECESSÁRIO — Riesgo de toxicidad',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.increasedToxicity},
    [_kRefMdx, _kRefUT]),

  // ── Demência / Alzheimer ──────────────────────────────────────────────────────

  ('donepezila', 'butilescopolamina', InteractionSeverity.major,
    'Antagonismo farmacodinâmico direto (Colinérgico vs Anticolinérgico)',
    'Anulação da eficácia do tratamento para Alzheimer (piora cognitiva) e exacerbação anticolinérgica periférica',
    'Evitar o uso de anticolinérgicos sistêmicos em pacientes com demência tratada farmacologicamente',
    'ANTAGONISMO TERAPÊUTICO — Piora do Alzheimer',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.cns},
    [_kRefGG, _kRefMdx]),

  ('donepezila', 'difenidramina', InteractionSeverity.major,
    'A difenidramina possui altíssima carga anticolinérgica (anti-M1 central)',
    'Anulação completa do efeito do inibidor da acetilcolinesterase e indução de delirium agudo no idoso',
    'Contraindicado. Usar anti-histamínicos de 2ª geração (ex: Bilastina, Fexofenadina)',
    'DELIRIUM E CONFUSÃO — Evitar anti-H1 de 1ª geração',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.cns},
    [_kRefMdx, _kRefUT]),

  ('memantina', 'acetazolamida', InteractionSeverity.moderate,
    'A alcalinização urinária induzida pela acetazolamida diminui o clearance renal da memantina',
    'Acúmulo de memantina sérica, levando a confusão mental, tontura e psicose paradoxal',
    'Monitorar função cognitiva de perto ou evitar a combinação',
    'TOXICIDADE NEUROLÓGICA — Risco de acúmulo sistêmico',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel, RiskType.increasedToxicity},
    [_kRefMdx, _kRefFDA]),

  ('donepezila', 'timolol', InteractionSeverity.major,
    'Sinergia cronotrópica negativa: aumento do tônus colinérgico central/periférico + bloqueio beta-adrenérgico sistémico',
    'Bradicardia sinusal sintomática grave, bloqueios auriculoventriculares e síncope recorrente no idoso',
    'Monitorar o pulso regularmente. Ensinar o paciente a ocluir o ponto lacrimal ao instilar o colírio para evitar absorção',
    'BRADICARDIA E SÍNCOPE — Sinergia Cardiodepressora',
    EvidenceLevel.established,
    {RiskType.arrhythmia, RiskType.cardiovascular},
    [_kRefMdx, _kRefUT]),

  // ── Hemostáticos ──────────────────────────────────────────────────────────────

  ('desmopressina', 'furosemida', InteractionSeverity.major,
    'Efeitos aditivos sobre a alteração do volume e concentração do sódio plasmático (retenção de água livre + depleção de sódio)',
    'Hiponatremia dilucional aguda e grave, provocando edema cerebral, obnubilação e convulsiones',
    'Evitar o uso de diuréticos potentes em pacientes que recebem desmopressina. Controlar o sódio sérico a cada 24h',
    'HIPONATREMIA DILUCIONAL GRAVE — Risco de Convulsões',
    EvidenceLevel.established,
    {RiskType.electrolyte, RiskType.seizure},
    [_kRefMdx, _kRefGG]),

  ('acido tranexamico', 'anticoncepcional', InteractionSeverity.moderate,
    'Sinergia pró-trombótica: inibição da fibrinólise pelo ácido tranexâmico somada ao estado pró-coagulante dos estrogênios',
    'Risco aumentado de tromboembolismo venoso (TVP, TEP) e arterial',
    'Usar com cautela. Evitar combinación em pacientes com histórico ou fatores de risco para trombosis',
    'RISCO TROMBÓTICO ADITIVO — Precaução em pacientes de risco',
    EvidenceLevel.probable,
    {RiskType.thrombosis},
    [_kRefMdx, _kRefUT]),

  ('vitamina k1', 'varfarina', InteractionSeverity.major,
    'Antagonismo farmacodinâmico direto: a vitamina K1 é o substrato que a varfarina bloqueia na síntese de fatores de coagulação',
    'Reversão do efeito anticoagulante e queda do INR, aumentando risco trombótico',
    'Monitorar INR rigurosamente. Uso terapéutico intencional para reverter superdosagem de varfarina',
    'REVERSÃO DO ANTICOAGULANTE — Monitorizar INR',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.thrombosis},
    [_kRefGG, _kRefFDA]),

  // ── Psoríase / Dermatologia ───────────────────────────────────────────────────

  ('acitretina', 'metotrexato', InteractionSeverity.major,
    'Ambos fármacos são intensamente hepatotóxicos; competência na excreção e metabolismo',
    'Hepatite tóxica aguda, elevação fulminante de transaminases e risco de cirrose a longo prazo',
    'Associação frecuentemente evitada. Se usada, exige hepatograma a cada 2-4 semanas',
    'HEPATOTOXICIDADE GRAVE ADITIVA — Evitar se possível',
    EvidenceLevel.established,
    {RiskType.hepatotoxicity},
    [_kRefGG, _kRefUT]),

  ('acitretina', 'doxiciclina', InteractionSeverity.contraindicated,
    'Sinergia neurotóxica idiopática entre retinoides sistémicos (vitamina A) e tetraciclinas',
    'Risco crítico de Hipertensão Intracraniana Benigna (Pseudotumor Cerebri), causando cefaleia severa, edema de papila e cegueira permanente',
    'Contraindicado. Nunca associar retinoides orais com antibióticos da classe das tetraciclinas',
    'CEGUEIRA POR HIC — Contraindicado com Tetraciclinas',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefFDA, _kRefMdx]),

  ('acitretina', 'alcool', InteractionSeverity.contraindicated,
    'O álcool converte a acitretina de volta a etretinato, metabólito com meia-vida extremamente longa (120 dias) e altamente teratogênico',
    'Risco de teratogenicidade prolongada por até 2 anos após a suspensão do medicamento',
    'Consumo de álcool absolutamente contraindicado durante e por 2 meses após o tratamento',
    'TERATOGENICIDADE PROLONGADA — Álcool absolutamente prohibido',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefFDA, _kRefGG]),

  ('finasterida', 'inibidores cyp3a4', InteractionSeverity.minor,
    'A finasterida é metabolizada principalmente pelo CYP3A4',
    'Possível aumento modesto dos níveis de finasterida com inibidores potentes (cetoconazol, itraconazol)',
    'Sem ajuste de dose necesario para a maioria dos pacientes; monitorar efeitos adversos',
    'INTERAÇÃO LEVE — Monitorar efeitos adversos',
    EvidenceLevel.theoretical,
    {RiskType.plasmaLevel},
    [_kRefMdx]),

  // ── Vitaminas e Suplementos ───────────────────────────────────────────────────

  ('vitamina d', 'tiazidico', InteractionSeverity.moderate,
    'Os tiazídicos reduzem a excreção renal de cálcio e a vitamina D aumenta a absorção intestinal de cálcio',
    'Hipercalcemia, especialmente em pacientes com hiperparatireoidismo ou sarcoidose',
    'Monitorar calcemia periodicamente em pacientes usando vitamina D e tiazídicos crónicamente',
    'HIPERCALCEMIA — Monitorar cálcio sérico',
    EvidenceLevel.established,
    {RiskType.electrolyte, RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx]),

  ('vitamina d', 'orlistate', InteractionSeverity.moderate,
    'O orlistate inibe a absorção de gordura e vitaminas lipossolúveis no intestino',
    'Redução da absorção de vitamina D, agravando deficiências em pacientes obesos',
    'Suplementar vitamina D em doses adecuadas e separar a administração do orlistate',
    'ABSORÇÃO REDUZIDA — Suplementação ajustada',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefFDA, _kRefMdx]),

  ('vitamina c', 'varfarina', InteractionSeverity.minor,
    'Altas doses de vitamina C (>1g/dia) podem interferir com o metabolismo da varfarina',
    'Possível alteração do INR (redução ou aumento dependendo da dose)',
    'Monitorar INR se paciente usar suplementação de vitamina C em doses altas',
    'MONITORAR INR — Altas doses de vitamina C',
    EvidenceLevel.possible,
    {RiskType.hemorrhagic},
    [_kRefMdx]),

  ('vitamina c', 'deferasirox', InteractionSeverity.moderate,
    'A vitamina C aumenta a biodisponibilidade do ferro e pode alterar a farmacocinética do quelante',
    'Potencial excesso de quelação e toxicidad por deferasirox se iron stores forem baixos',
    'Evitar suplementação simultânea de vitamina C em altas doses com quelantes de ferro',
    'INTERAÇÃO COM QUELANTE DE FERRO — Evitar altas doses',
    EvidenceLevel.probable,
    {RiskType.increasedToxicity},
    [_kRefMdx]),

  ('acido folico', 'metotrexato', InteractionSeverity.moderate,
    'O ácido fólico é o substrato que o metotrexato antagoniza ao inibir a diidrofolato redutase',
    'Suplementação com ácido fólico pode atenuar a toxicidad do metotrexato sin embargo pode reduzir ligeiramente sua eficácia',
    'Uso intencional e supervisionado: suplementar com 1-5 mg/dia de ácido fólico para reduzir efeitos adversos do MTX em doses baixas reumatológicas',
    'ANTAGONISMO FOLATO — Uso supervisionado para reduzir toxicidad',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefUT]),

  ('acido folico', 'sulfassalazina', InteractionSeverity.moderate,
    'A sulfassalazina inibe a absorção intestinal do ácido fólico e compete pelas enzimas do metabolismo do folato',
    'Deficiência de folato e aumento do risco de anemia megaloblástica ou macrocitose',
    'Aumentar a dose de suplementação de ácido fólico (ex. 1 a 5 mg/dia) e espaçar as tomadas da sulfassalazina',
    'DÉFICIT DE ÁCIDO FÓLICO — Requer suplementação maior',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.increasedToxicity},
    [_kRefMdx]),

  ('magnesio', 'antibiotico tetraciclinico', InteractionSeverity.major,
    'Formação de quelatos insolúveis entre o magnésio e as tetraciclinas no trato gastrointestinal',
    'Redução drástica na absorção das tetraciclinas (doxiciclina, tetraciclina), levando a falha antibiótica',
    'Espaçar a administração em pelo menos 2 horas. Preferir administrar o antibiótico 1h antes do suplemento',
    'FALHA ANTIBIÓTICA POR QUELAÇÃO — Espaçar doses',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),

  ('magnesio', 'fluoroquinolona', InteractionSeverity.major,
    'Formação de quelatos entre cátions divalentes (Mg2+) e fluoroquinolonas no lúmen intestinal',
    'Redução de até 50% na biodisponibilidade da fluoroquinolona, causando falha antibiótica',
    'Administrar a fluoroquinolona pelo menos 2 horas antes ou 6 horas após o suplemento de magnésio',
    'FALHA ANTIBIÓTICA (QUELAÇÃO) — Espaçar doses obligatoriamente',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),

  ('zinco', 'antibiotico tetraciclinico', InteractionSeverity.major,
    'Quelação do zinco com tetraciclinas no trato gastrointestinal',
    'Redução significativa na absorção de ambos: do antibiótico e do zinco',
    'Espaçar em pelo menos 2 horas. Tomar o antibiótico antes do suplemento',
    'QUELAÇÃO MÚTUA — Espaçar doses 2h',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefMdx]),

  ('zinco', 'fluoroquinolona', InteractionSeverity.moderate,
    'Formação de quelatos insolúveis entre zinco e fluoroquinolonas',
    'Redução da biodisponibilidade da fluoroquinolona e do zinco simultaneamente',
    'Administrar a fluoroquinolona pelo menos 2 horas antes do suplemento de zinco',
    'ABSORÇÃO REDUZIDA — Espaçar doses',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefMdx]),

  ('cianocobalamina', 'metformina', InteractionSeverity.moderate,
    'A metformina reduz a absorção de vitamina B12 ao interferir no receptor cálcio-dependente ileal',
    'Deficiência subclínica ou clínica de vitamina B12 a longo prazo, risco de neuropatia megaloblástica',
    'Monitorar os níveis séricos de B12 anualmente em pacientes sob terapia crônica com metformina',
    'DÉFICIT CRÓNICO DE B12 — Monitoramento anual',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefUT, _kRefMdx]),

  ('cianocobalamina', 'omeprazol', InteractionSeverity.moderate,
    'A supressão profunda e prolongada do ácido gástrico impede a dissociação da vitamina B12 de suas proteínas dietéticas',
    'Deficiência subclínica ou clínica de vitamina B12 a longo prazo, risco de neuropatia megaloblástica',
    'Monitorar os níveis séricos de B12 anualmente em pacientes sob terapia crônica com IBP',
    'DÉFICIT CRÓNICO DE B12 — Monitoramento anual com IBP',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefUT, _kRefMdx]),

  ('tiamina', 'alcool', InteractionSeverity.major,
    'O álcool crônico inibe a absorção intestinal, diminui o estoque hepático e aumenta a excreção urinária de tiamina',
    'Deficiência grave de tiamina com risco de Encefalopatia de Wernicke e Síndrome de Korsakoff',
    'Reposição intravenosa urgente de tiamina (300 mg IV/IM) antes de qualquer infusão de glicose em alcoolistas',
    'ENCEFALOPATIA DE WERNICKE — Reposição IV urgente',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.reducedEfficacy},
    [_kRefGG, _kRefUT]),

  ('piridoxina', 'levodopa', InteractionSeverity.major,
    'A piridoxina aumenta o metabolismo periférico da levodopa pela DOPA descarboxilase antes de atingir o SNC',
    'Redução significativa da eficácia terapéutica da levodopa para o Parkinson',
    'Evitar suplementação de piridoxina em pacientes usando levodopa sem inibidor de descarboxilase (benserazida ou carbidopa)',
    'PERDA DE EFICÁCIA DO ANTIPARKINSONIANO — Usar com carbidopa',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),

  ('piridoxina', 'isoniazida', InteractionSeverity.major,
    'A isoniazida inibe o metabolismo da piridoxina e sua conversão à forma ativa (piridoxal-5-fosfato)',
    'Neuropatia periférica por deficiência funcional de piridoxina, especialmente em desnutridos e diabéticos',
    'Suplementar piridoxina 25-50 mg/dia em todos os pacientes em uso de isoniazida',
    'NEUROPATIA PERIFÉRICA — Suplementar piridoxina obligatoriamente',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx]),

  // ── Anemias ───────────────────────────────────────────────────────────────────

  ('sulfato ferroso', 'omeprazol', InteractionSeverity.moderate,
    'Os IBP elevam o pH gástrico, reduzindo a solubilização do ferro ferroso',
    'Redução na absorção do sulfato ferroso, dificultando a correção da anemia ferropriva',
    'Administrar o ferro em jejum se possível, ou separar do IBP. Monitorar hemograma e ferritina',
    'ABSORÇÃO REDUZIDA — Monitorar resposta hematológica',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),

  ('sulfato ferroso', 'ciprofloxacino', InteractionSeverity.major,
    'Formação de quelatos insolúveis entre o ferro e as fluoroquinolonas no lúmen intestinal',
    'Falha do antibiótico fluoroquinolona por absorção insuficiente',
    'Administrar a fluoroquinolona pelo menos 2 horas antes ou 6 horas após o sulfato ferroso',
    'FALHA ANTIBIÓTICA — Espaçar doses obligatoriamente',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),

  ('sulfato ferroso', 'levotiroxina', InteractionSeverity.major,
    'O ferro forma complexo insolúvel com a levotiroxina no trato gastrointestinal',
    'Redução da absorção da levotiroxina e elevação do TSH, levando ao hipotireoidismo descontrolado',
    'Separar as administrações em pelo menos 4 horas',
    'HIPOTIREOIDISMO DESCOMPENSADO — Espaçar 4 horas',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefMdx, _kRefUT]),

  ('ferro iv', 'epoetina', InteractionSeverity.moderate,
    'A eritropoetina estimula a eritropoese, aumentando a demanda por ferro. A oferta de ferro IV potencializa a resposta',
    'Quando o ferro IV é administrado sem eritropoetina adecuada, pode haver acúmulo de ferro livre (toxicidad oxidativa)',
    'Monitorar ferritina e saturação de transferrina. Titular a dose de ferro IV conforme resposta hematológica',
    'MONITORAR ESTOQUE DE FERRO — Evitar sobrecarga',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefUT, _kRefMdx]),

  ('epoetina', 'varfarina', InteractionSeverity.moderate,
    'O aumento do hematócrito e da viscosidade sanguínea induzido pela eritropoetina pode alterar o estado tromboembólico',
    'Aumento do risco trombótico e possível necessidade de ajuste da dose de varfarina',
    'Monitorar INR e sinais de tromboembolismo em pacientes anticoagulados iniciando eritropoetina',
    'RISCO TROMBÓTICO E ALTERAÇÃO DO INR — Monitorar',
    EvidenceLevel.probable,
    {RiskType.thrombosis, RiskType.hemorrhagic},
    [_kRefMdx]),

  ('epoetina', 'ciclosporina', InteractionSeverity.moderate,
    'A eritropoetina eleva o hematócrito e pode aumentar a viscosidade, alterando a farmacocinética da ciclosporina',
    'Alteração dos níveis de ciclosporina e aumento da pressão arterial, podendo comprometer o enxerto renal',
    'Monitorar pressão arterial e níveis de ciclosporina ao iniciar ou ajustar a dose de eritropoetina',
    'HIPERTENSÃO E ALTERAÇÃO DE CICLOSPORINA — Monitorar',
    EvidenceLevel.probable,
    {RiskType.cardiovascular, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),

  // ── Fígado e Pâncreas ─────────────────────────────────────────────────────────

  ('acido ursodesoxicolico', 'ciclosporina', InteractionSeverity.moderate,
    'O ácido ursodesoxicólico pode aumentar a absorção da ciclosporina ao alterar a composição da bile intestinal',
    'Elevação dos níveis de ciclosporina, com potencial nefrotoxicidad e imunossupressão excessiva',
    'Monitorar os níveis séricos de ciclosporina ao iniciar o ácido ursodesoxicólico',
    'NÍVEL DE CICLOSPORINA AUMENTADO — Monitorar concentrações',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel, RiskType.nephrotoxicity},
    [_kRefMdx]),

  ('acido ursodesoxicolico', 'colestiramina', InteractionSeverity.major,
    'A colestiramina sequestra o ácido ursodesoxicólico no intestino, impedindo sua absorção',
    'Falha terapéutica no tratamento da colangite biliar primária ou litíase biliar',
    'Administrar o ácido ursodesoxicólico pelo menos 2 horas antes ou 4 horas após a colestiramina',
    'ABSORÇÃO ANULADA — Espaçar doses obligatoriamente',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefMdx, _kRefUT]),

  ('lactulose', 'antibiotico', InteractionSeverity.moderate,
    'Antibióticos sistêmicos alteram a flora intestinal necessária para a fermentação da lactulose',
    'Reducción de la eficacia da lactulose no controle da encefalopatia hepática ao eliminar as bactérias que a metabolizam',
    'Monitorar o grau de encefalopatia e considerar ajuste da dose de lactulose durante cursos de antibióticos',
    'EFICÁCIA REDUZIDA — Monitorar encefalopatia',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),

  ('pancrelipase', 'acarbosa', InteractionSeverity.major,
    'A acarbosa é um inibidor direto das enzimas alfa-glicosidases e da amilase pancreática',
    'Anulação total do efeito terapéutico da pancrelipase (especificamente a fração amilase), piorando a esteatorrea e desnutrição',
    'Evitar a combinação. Pacientes com insuficiência pancreática exócrina não devem ser tratados com acarbosa',
    'ANULAÇÃO ENZIMÁTICA TOTAL — Evitar uso concomitante',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),

  ('pancrelipase', 'bicarbonato', InteractionSeverity.moderate,
    'A alcalinização do ambiente gástrico-duodenal pode inativar as enzimas pancreáticas antes de atingirem o intestino delgado',
    'Reducción de la eficacia da reposição enzimática, com persistência de má absorção e esteatorrea',
    'Usar formulações entéricas de enzimas pancreáticas (revestimento gastrorresistente) e evitar antiácidos potentes próximos às refeições',
    'INATIVAÇÃO ENZIMÁTICA — Preferir cápsulas gastrorresistentes',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy},
    [_kRefMdx]),

  // ── Respiratório Avançado ─────────────────────────────────────────────────────

  ('omalizumabe', 'vacinas vivas', InteractionSeverity.major,
    'O omalizumabe suprime a resposta imune mediada por IgE e pode atenuar a resposta a vacinas vivas',
    'Risco de infecção ativa pela cepa vacinal e resposta imune atenuada',
    'Evitar vacinas vivas atenuadas durante o tratamento com omalizumabe. Preferir vacinas inativadas',
    'RISCO DE INFECÇÃO VACINAL — Evitar vacinas vivas',
    EvidenceLevel.probable,
    {RiskType.infection},
    [_kRefFDA, _kRefUT]),

  ('omalizumabe', 'dupilumabe', InteractionSeverity.major,
    'Combinação de dois biológicos com supressão imune em vias diferentes (anti-IgE + anti-IL-4/IL-13)',
    'Imunossupressão excessiva com risco de infecções oportunistas sem benefício adicional comprovado',
    'Combinação de dois biológicos sistêmicos absolutamente contraindicada',
    'IMUNOSSUPRESSÃO EXCESSIVA — Contraindicado',
    EvidenceLevel.established,
    {RiskType.infection, RiskType.increasedToxicity},
    [_kRefFDA, _kRefUT]),

  // ── Alergias ──────────────────────────────────────────────────────────────────

  ('cetirizina', 'alcool', InteractionSeverity.moderate,
    'Potenciação da sedação central pelo álcool em combinação com anti-histamínicos de 2ª geração',
    'Sedação aumentada, comprometimento da atenção e habilidades psicomotoras',
    'Evitar o consumo de álcool durante o uso de cetirizina, especialmente se for dirigir ou operar máquinas',
    'SEDAÇÃO AUMENTADA — Evitar álcool',
    EvidenceLevel.established,
    {RiskType.cns},
    [_kRefMdx]),

  ('difenidramina', 'benzodiazepínico', InteractionSeverity.major,
    'Sinergia na depressão do Sistema Nervioso Central e sedação excessiva',
    'Sedação profunda, comprometimento cognitivo grave, depresión respiratoria e risco de queda em idosos',
    'Evitar a combinação. A difenidramina está na lista de medicamentos de alto risco para idosos (Critérios de Beers)',
    'DEPRESSÃO SNC SEVERA — Evitar em idosos (Critérios de Beers)',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.respiratoryDepression},
    [_kRefGG, _kRefMdx]),

  ('difenidramina', 'opioide', InteractionSeverity.major,
    'Depressão farmacodinâmica aditiva do SNC e do centro respiratório bulbar',
    'Sedação profunda, letargia prolongada e risco iminente de parada respiratória',
    'Evitar a associação. Usar anti-histamínicos de 2ª geração (fexofenadina, loratadina) como alternativas seguras',
    'DEPRESSÃO RESPIRATÓRIA SEVERA — Evitar combinación',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns},
    [_kRefMdx, _kRefGG]),

  ('difenidramina', 'imao', InteractionSeverity.contraindicated,
    'Os IMAOs inibem o metabolismo hepático da difenidramina, potencializando seus efeitos anticolinérgicos e sedativos',
    'Toxicidade anticolinérgica grave: taquicardia, delirium, hipertermia, retenção urinária e possível psicose',
    'Contraindicado. Aguardar washout completo do IMAO antes de usar difenidramina',
    'TOXICIDADE ANTICOLINÉRGICA GRAVE — Contraindicado com IMAO',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.increasedToxicity},
    [_kRefMdx, _kRefFDA]),

  ('fexofenadina', 'cetoconazol', InteractionSeverity.moderate,
    'O cetoconazol inibe o transportador P-glicoproteína e aumenta a biodisponibilidade da fexofenadina',
    'Aumento dos niveles plasmáticos de fexofenadina, com potencial prolongamento do intervalo QT',
    'Monitorar ECG em pacientes com fatores de risco cardíaco. Geralmente bem tolerado na prática',
    'AUMENTO DE NÍVEIS — Monitorar QT em pacientes de risco',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel, RiskType.qtProlongation},
    [_kRefMdx, _kRefFDA]),

  ('fexofenadina', 'eritromicina', InteractionSeverity.moderate,
    'A eritromicina inibe a P-glicoproteína e o transportador OATP, aumentando a biodisponibilidade da fexofenadina',
    'Aumento de até 2 vezes nos niveles plasmáticos de fexofenadina',
    'Geralmente bem tolerado, mas monitorar em pacientes com fatores de risco para prolongamento do QT',
    'AUMENTO DE BIODISPONIBILIDADE — Monitorar em pacientes de risco cardíaco',
    EvidenceLevel.established,
    {RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),

  // ── Alzheimer ─────────────────────────────────────────────────────────────────

  ('donepezila', 'amiodarona', InteractionSeverity.major,
    'Sinergia bradicardizante: inibidor da colinesterase aumenta o tônus vagal somado ao efeito cronotrópico negativo da amiodarona',
    'Bradicardia sinusal severa, bloqueio AV de 2º/3º grau e síncope recorrente',
    'Monitorar ECG e frequência cardíaca. Considerar alternativas terapéuticas',
    'BRADICARDIA SEVERA — Monitorar ECG',
    EvidenceLevel.established,
    {RiskType.arrhythmia, RiskType.cardiovascular},
    [_kRefMdx, _kRefUT]),

  ('donepezila', 'succinilcolina', InteractionSeverity.major,
    'Os inibidores da colinesterase reduzem a hidrólise da succinilcolina, prolongando seu efeito neuromuscular',
    'Bloqueio neuromuscular prolongado e apneia pós-operatória inesperada',
    'Alertar o anestesiologista sobre o uso de inibidores de colinesterase antes de procedimentos cirúrgicos',
    'APNEIA PÓS-OPERATÓRIA — Alertar equipe de anestesia',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx]),

  ('memantina', 'amantadina', InteractionSeverity.major,
    'Ambos são antagonistas dos receptores NMDA de glutamato; efeito aditivo/sinérgico',
    'Toxicidade por excesso de bloqueio NMDA: alucinações, agitação, mioclonias e psicose aguda',
    'Evitar a combinação. Se necesario para Parkinson + demência, usar doses mínimas com monitoramento rigoroso',
    'PSICOSE E ALUCINAÇÕES — Evitar bloqueio NMDA duplo',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx]),

  ('memantina', 'ketamina', InteractionSeverity.major,
    'Antagonismo NMDA duplo: a cetamina e a memantina bloqueiam o mesmo receptor',
    'Potenciação dos efeitos dissociativos e psicodislépticos, risco de psicose e excitação paradoxal',
    'Usar a cetamina com extrema cautela em pacientes usando memantina. Reduzir a dose de cetamina e monitorar o estado mental',
    'POTENCIAÇÃO DISSOCIATIVA — Risco de psicose aguda',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx]),

  // ── Psicose e Mania ───────────────────────────────────────────────────────────

  ('carbonato de litio', 'aine', InteractionSeverity.major,
    'Os AINEs inibem as prostaglandinas renais, reduzindo a filtração glomerular e clearance renal do lítio',
    'Acúmulo de lítio com toxicidad aguda (tremor grosseiro, ataxia, confusão, convulsiones)',
    'Monitorar níveis séricos de lítio ao iniciar ou suspender AINEs. Preferir paracetamol como analgésico',
    'TOXICIDADE POR LÍTIO — Monitorar nivel sérico rigurosamente',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.seizure},
    [_kRefGG, _kRefMdx]),

  ('quetiapina', 'carbamazepina', InteractionSeverity.major,
    'A carbamazepina é indutor potente do CYP3A4, principal via metabólica da quetiapina',
    'Redução de até 87% nos niveles plasmáticos de quetiapina, causando falha terapéutica psiquiátrica',
    'Evitar a combinação ou aumentar significativamente a dose de quetiapina sob monitoramento clínico rigoroso',
    'FALHA ANTIPSICÓTICA — Indução CYP3A4 pela carbamazepina',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.reducedEfficacy},
    [_kRefMdx, _kRefUT]),

  ('haloperidol', 'carbamazepina', InteractionSeverity.moderate,
    'A carbamazepina induz o metabolismo hepático do haloperidol pelo CYP3A4',
    'Redução significativa dos niveles plasmáticos de haloperidol, com risco de recaída psicótica',
    'Monitorar resposta clínica e considerar aumento da dose de haloperidol durante o uso concomitante',
    'REDUÇÃO DOS NÍVEIS — Monitorar resposta psiquiátrica',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),

  ('haloperidol', 'rifampicina', InteractionSeverity.major,
    'A rifampicina é um indutor enzimático potente do CYP3A4 e CYP2D6, vias de metabolismo do haloperidol',
    'Queda drástica nos níveis de haloperidol, com perda do controle dos sintomas psicóticos',
    'Evitar a associação ou aumentar a dose de haloperidol com monitoramento clínico intensivo',
    'PERDA DE CONTROLE PSICÓTICO — Indução enzimática grave',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.reducedEfficacy},
    [_kRefMdx]),

  ('haloperidol', 'mefloquina', InteractionSeverity.major,
    'Ambos prolongam o intervalo QT de forma independente e aditiva',
    'Risco aumentado de Torsades de Pointes e morte súbita cardíaca',
    'Contraindicado. Escolher outro antipsicótico com menor risco de prolongamento do QT',
    'TORSADES DE POINTES — Contraindicado',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefMdx, _kRefUT]),

  // ── Anestesia ─────────────────────────────────────────────────────────────────

  ('cetamina', 'benzodiazepínico', InteractionSeverity.moderate,
    'Os benzodiazepínicos potencializam a sedação e podem prolongar a recuperação anestésica da cetamina',
    'Sedação prolongada e risco de depresión respiratoria no período pós-operatório imediato',
    'Reduzir a dose de cetamina quando usada em combinação com benzodiazepínicos. Monitorar recuperação',
    'SEDAÇÃO PROLONGADA — Reduzir dose de cetamina',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.respiratoryDepression},
    [_kRefGG, _kRefMdx]),

  ('cetamina', 'teofilina', InteractionSeverity.major,
    'Interação farmacodinâmica: ambos podem reduzir o limiar convulsivo por mecanismos diferentes',
    'Risco aumentado de convulsiones intraoperatórias ou no período de recuperação anestésica',
    'Evitar a combinação em pacientes asmáticos usando teofilina que necessitem de cetamina como anestésico',
    'RISCO DE CONVULSÕES — Evitar combinación',
    EvidenceLevel.probable,
    {RiskType.seizure, RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx]),

  ('cetamina', 'lítio', InteractionSeverity.moderate,
    'O lítio pode prolongar a duração do bloqueio neuromuscular e potenciar os efeitos anestésicos da cetamina',
    'Recuperação anestésica prolongada e possível potenciação dos efeitos dissociativos',
    'Monitorar cuidadosamente a recuperação em pacientes com lítio submetidos à anestesia com cetamina',
    'RECUPERAÇÃO ANESTÉSICA PROLONGADA — Monitorar',
    EvidenceLevel.probable,
    {RiskType.cns},
    [_kRefMdx, _kRefUT]),

  // ── Tireoide ──────────────────────────────────────────────────────────────────

  ('propiltiouracil', 'varfarina', InteractionSeverity.major,
    'O hipotireoidismo induzido pelo propiltiouracil altera o metabolismo dos fatores de coagulação e pode potencializar o efeito da varfarina',
    'Risco aumentado de sangrado com elevação do INR conforme o paciente torna-se eutireóideo',
    'Monitorar INR frecuentemente durante o início e ajuste da dose de propiltiouracil',
    'ELEVAÇÃO DO INR — Monitorar rigurosamente',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),

  ('propiltiouracil', 'metformina', InteractionSeverity.minor,
    'O hipotireoidismo pode reduzir o clearance renal da metformina e alterar o metabolismo da glicose',
    'Possível alteração no controle glicêmico e risco leve de acúmulo de metformina',
    'Monitorar a glucemia e función renal durante o ajuste da dose de propiltiouracil',
    'MONITORAR GLICEMIA — Interação indireta via função tireoidiana',
    EvidenceLevel.possible,
    {RiskType.other},
    [_kRefMdx]),

  ('propiltiouracil', 'digoxina', InteractionSeverity.moderate,
    'O hipotireoidismo altera o volume de distribuição e o clearance da digoxina',
    'Aumento dos níveis séricos de digoxina com risco de toxicidad digitálica (bradiarritmias, náuseas)',
    'Monitorar níveis de digoxina ao ajustar a dose de propiltiouracil durante o tratamento do hipertireoidismo',
    'TOXICIDADE DIGITÁLICA — Monitorar digoxinemia',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),

  // ── Diuréticos ────────────────────────────────────────────────────────────────

  ('espironolactona', 'acido acetilsalicilico', InteractionSeverity.moderate,
    'O ácido acetilsalicílico em altas doses pode antagonizar o efeito natriurético da espironolactona por inhibición das prostaglandinas renais',
    'Reducción de la eficacia diurética da espironolactona, podendo agravar edema e insuficiencia cardíaca',
    'Evitar aspirina em doses altas em pacientes com insuficiencia cardíaca usando espironolactona. Doses baixas (100mg) são geralmente seguras',
    'EFICÁCIA DIURÉTICA REDUZIDA — Evitar AAS em altas doses',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),

  ('espironolactona', 'trimetoprima', InteractionSeverity.major,
    'A trimetoprima bloqueia os canais epiteliais de sódio no néfron distal, semelhante à amilorida, causando retenção de potássio',
    'Hipercalemia grave, especialmente em idosos, pacientes com IRC ou em uso de outros poupadores de potássio',
    'Monitorar potássio sérico ao iniciar a trimetoprima em pacientes usando espironolactona',
    'HIPERCALEMIA GRAVE — Monitorar potássio sérico',
    EvidenceLevel.established,
    {RiskType.hyperkalemia, RiskType.electrolyte},
    [_kRefGG, _kRefMdx, _kRefUT]),

  ('espironolactona', 'heparina', InteractionSeverity.moderate,
    'A heparina inibe a síntese de aldosterona nas adrenais, potencializando o efeito antialdosterônico da espironolactona',
    'Hipercalemia significativa, especialmente em pacientes com insuficiencia renal',
    'Monitorar potássio sérico frecuentemente em pacientes anticoagulados com heparina usando espironolactona',
    'HIPERCALEMIA ADITIVA — Monitorar electrolitos',
    EvidenceLevel.established,
    {RiskType.hyperkalemia, RiskType.electrolyte},
    [_kRefGG, _kRefMdx]),

  // ── EII: Doença Inflamatória Intestinal ──────────────────────────────────────

  ('mesalazina', 'varfarina', InteractionSeverity.moderate,
    'A mesalazina pode potenciar o efeito anticoagulante da varfarina por mecanismo não completamente elucidado',
    'Elevación del INR y riesgo de sangrado, incluindo hemorragia gastrointestinal',
    'Monitorar INR regularmente ao iniciar ou alterar a dose de mesalazina em pacientes anticoagulados',
    'MONITORAR INR — Risco de sangrado GI',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),

  ('mesalazina', 'mercaptopurina', InteractionSeverity.major,
    'A mesalazina inibe a tiopurina metiltransferase (TPMT), enzima responsável pela inativação da mercaptopurina',
    'Acúmulo de metabólitos tóxicos da mercaptopurina, causando mielosupresión grave',
    'Monitorar hemograma completo com atenção. Reduzir a dose de mercaptopurina se necesario',
    'MIELOSSUPRESSÃO GRAVE — Monitorar hemograma',
    EvidenceLevel.established,
    {RiskType.myelosuppression, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),

  ('sulfassalazina', 'digoxina', InteractionSeverity.moderate,
    'A sulfassalazina pode reduzir a absorção da digoxina por mecanismos gastrointestinais',
    'Redução dos níveis séricos de digoxina, com possível perda do efeito terapéutico',
    'Monitorar níveis de digoxina ao iniciar ou suspender sulfassalazina',
    'NÍVEL DE DIGOXINA REDUZIDO — Monitorar',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefMdx]),

  ('sulfassalazina', 'metotrexato', InteractionSeverity.moderate,
    'Ambos podem causar supressão da medula óssea e hepatotoxicidad, além de competição pela excreção renal',
    'Risco aumentado de leucopenia, trombocitopenia e hepatotoxicidad aditiva',
    'Monitorar hemograma e enzimas hepáticas regularmente. A combinação é usada em reumatologia sob supervisão',
    'TOXICIDADE HEMATOLÓGICA E HEPÁTICA ADITIVA — Monitorar',
    EvidenceLevel.established,
    {RiskType.myelosuppression, RiskType.hepatotoxicity},
    [_kRefGG, _kRefMdx]),

  ('budesonida', 'cetoconazol', InteractionSeverity.major,
    'O cetoconazol inibe o CYP3A4, a principal via de metabolismo da budesonida',
    'Aumento significativo dos níveis sistêmicos de budesonida, com risco de supressão do eixo hipotálamo-hipófise-adrenal',
    'Evitar a combinação. Se necesario, reduzir a dose de budesonida e monitorar sinais de hipercortisolismo',
    'EFEITO SISTÊMICO DO CORTICOIDE — Evitar inibidores potentes de CYP3A4',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.increasedToxicity},
    [_kRefMdx, _kRefFDA]),

  ('budesonida', 'ritonavir', InteractionSeverity.major,
    'O ritonavir é inibidor extremamente potente do CYP3A4, bloqueando quase completamente o metabolismo de primeira passagem da budesonida',
    'Síndrome de Cushing iatrogênica com supressão adrenal grave e insuficiencia adrenal ao suspender',
    'Combinação contraindicada. Usar alternativas que não dependam do CYP3A4 ou ajustar para doses mínimas com monitoramento',
    'CUSHING IATROGÊNICO — Contraindicado com ritonavir',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.increasedToxicity},
    [_kRefFDA, _kRefMdx]),

  // ── Biológicos: Imunobiológicos ───────────────────────────────────────────────

  ('ustekinumabe', 'vacinas vivas', InteractionSeverity.major,
    'O ustekinumabe suprime a resposta imune via bloqueio de IL-12/23, podendo impedir resposta protetora à vacina',
    'Risco de infecção ativa pela cepa vacinal e resposta imune inadecuada',
    'Evitar vacinas vivas durante o tratamento. Completar vacinação antes de iniciar o ustekinumabe',
    'RISCO DE INFECÇÃO VACINAL — Evitar vacinas vivas',
    EvidenceLevel.established,
    {RiskType.infection},
    [_kRefFDA, _kRefUT]),

  ('ustekinumabe', 'tofacitinibe', InteractionSeverity.contraindicated,
    'Imunossupressão sinérgica por bloqueio de IL-12/23 e inibição de JAK',
    'Risco inaceitável de infecções oportunistas letais sem benefício clínico adicional comprovado',
    'Nunca combinar dois imunobiológicos ou biológico + inibidor de JAK',
    'IMUNOSSUPRESSÃO LETAL — Absolutamente contraindicado',
    EvidenceLevel.established,
    {RiskType.infection, RiskType.increasedToxicity},
    [_kRefFDA, _kRefUT]),

  ('secuquinumabe', 'vacinas vivas', InteractionSeverity.major,
    'Bloqueio de IL-17A pelo secuquinumabe compromete a imunidade inata antifúngica e antiviral',
    'Risco de doença ativa por cepa vacinal e candidose mucocutânea recorrente',
    'Evitar vacinas vivas. Rastrear candidose oral durante o tratamento',
    'RISCO INFECCIOSO — Evitar vacinas vivas e monitorar candidose',
    EvidenceLevel.established,
    {RiskType.infection},
    [_kRefFDA, _kRefMdx]),

  ('secuquinumabe', 'infliximabe', InteractionSeverity.contraindicated,
    'Dupla imunossupressão biológica sistêmica: bloqueio de IL-17 + bloqueio de TNF-alfa',
    'Risco extremo de infecções oportunistas, sepse, tuberculose ativa e vasculite',
    'Absolutamente contraindicado combinar dois biológicos sistêmicos',
    'IMUNOSSUPRESSÃO FATAL — Contraindicado',
    EvidenceLevel.established,
    {RiskType.infection},
    [_kRefFDA, _kRefGG]),

  ('ixequizumabe', 'vacinas vivas', InteractionSeverity.major,
    'O bloqueio de IL-17A pelo ixequizumabe compromete a resposta imune adaptativa contra patógenos atenuados',
    'Risco de infecção ativa pela cepa vacinal e resposta vacinal inadecuada',
    'Evitar vacinas vivas durante o tratamento com ixequizumabe',
    'RISCO DE INFECÇÃO VACINAL — Evitar vacinas vivas',
    EvidenceLevel.established,
    {RiskType.infection},
    [_kRefFDA]),

  ('risanquizumabe', 'vacinas vivas', InteractionSeverity.major,
    'O risanquizumabe bloqueia a subunidade p19 da IL-23, afetando a imunidade celular adaptativa',
    'Risco de infecção ativa por cepas vacinais vivas',
    'Evitar vacinas vivas atenuadas durante todo o período de tratamento',
    'RISCO INFECCIOSO VACINAL — Contraindicado com vacinas vivas',
    EvidenceLevel.established,
    {RiskType.infection},
    [_kRefFDA]),

  // ── Deslipidemias: Inibidores de PCSK9 e Ezetimiba ───────────────────────────

  ('evolocumabe', 'estatina', InteractionSeverity.minor,
    'Os inibidores de PCSK9 são usados como adjuvantes às estatinas para redução do LDL',
    'Quando combinados, podem ocorrer miopatias em casos raros, embora o risco seja menor que com fibratos',
    'Monitorar CK e síntomas musculares. A combinação é a base do tratamento de hipercolesterolemia grave',
    'MONITORAR MIALGIAS — Combinação geralmente segura e intencional',
    EvidenceLevel.established,
    {RiskType.myopathy},
    [_kRefGG, _kRefUT]),

  ('alirocumabe', 'estatina', InteractionSeverity.minor,
    'Os inibidores de PCSK9 potencializam a redução de LDL das estatinas de forma aditiva',
    'A combinação é geralmente segura, sin embargo pode ocorrer miopatia em casos raros',
    'Monitorar síntomas musculares e CK. A combinação é padrão de tratamento para dislipidemia refratária',
    'MONITORAR MIALGIAS — Combinação usualmente segura',
    EvidenceLevel.established,
    {RiskType.myopathy},
    [_kRefGG, _kRefUT]),

  ('ezetimiba', 'ciclosporina', InteractionSeverity.major,
    'A ciclosporina inibe o transportador OATP1B1, aumentando drásticamente os niveles plasmáticos de ezetimiba e seu metabólito ativo',
    'Aumento de até 3 a 4 vezes na exposição à ezetimiba, com risco de efeitos adversos aumentados',
    'Monitorar lipídios e enzimas hepáticas. Evitar doses altas de ezetimiba em pacientes transplantados',
    'AUMENTO DE EXPOSIÇÃO À EZETIMIBA — Monitorar',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.increasedToxicity},
    [_kRefMdx, _kRefFDA]),

  ('ezetimiba', 'colestiramina', InteractionSeverity.moderate,
    'A colestiramina pode reduzir a absorção da ezetimiba ao sequestrar o fármaco no intestino',
    'Reducción de la eficacia hipolipemiante da ezetimiba',
    'Administrar a ezetimiba pelo menos 2 horas antes ou 4 horas após a colestiramina',
    'ABSORÇÃO REDUZIDA — Espaçar doses',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefMdx]),

  ('acido nicotinico', 'estatina', InteractionSeverity.moderate,
    'A combinação de ácido nicotínico com estatinas aumenta o risco de miopatia',
    'Riesgo de miopatía e rabdomiólisis, especialmente com sinvastatina em doses altas',
    'Monitorar CK e síntomas musculares. Evitar niacina em doses altas com estatinas em doses máximas',
    'RISCO DE MIOPATIA — Monitorar CK',
    EvidenceLevel.established,
    {RiskType.myopathy},
    [_kRefGG, _kRefMdx]),

  ('acido nicotinico', 'antidiabetico', InteractionSeverity.moderate,
    'A niacina em altas doses causa resistência insulínica e hiperglucemia',
    'Perda do controle glicêmico em pacientes diabéticos, podendo requerer ajuste da medicação',
    'Monitorar glucemia ao iniciar niacina em doses altas em pacientes diabéticos',
    'HIPERGLICEMIA — Monitorar controle glicêmico',
    EvidenceLevel.established,
    {RiskType.other},
    [_kRefGG, _kRefMdx]),

  // ── INTERACCIONES NUEVAS ─────────────────────────────────────────────────

  // 1. Metformina + Contraste Iodado → Acidosis Láctica
  ('metformina', 'contraste iodado',
    InteractionSeverity.major,
    'El contraste iodado puede causar insuficiencia renal aguda transitoria; la metformina se acumula cuando el clearance renal cae, con riesgo de acidosis láctica por bloqueo de la cadena respiratoria mitocondrial',
    'Acidosis láctica potencialmente fatal (mortalidad ~50%): náuseas, vómitos, dolor abdominal, hiperventilación, confusión, colapso hemodinámico',
    'Suspender metformina 48 h antes del procedimiento con contraste IV; reiniciar solo tras confirmar función renal normal (creatinina ≤ basal). En urgencias: hidratación vigorosa y monitoreo de lactato',
    'ACIDOSIS LÁCTICA — Suspender metformina 48 h antes del contraste IV',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx, _kRefFDA]),

  // 2. Sertralina + Tramadol → Síndrome Serotoninérgico
  ('sertralina', 'tramadol',
    InteractionSeverity.major,
    'La sertralina inhibe la recaptación de serotonina (ISRS) y el tramadol actúa como inhibidor de la recaptación de serotonina/noradrenalina además de agonista opioide débil; la combinación produce hiperserotonemia por acumulación sinérgica de 5-HT sináptica',
    'Síndrome serotoninérgico: agitación, mioclonus, hiperreflexia, hipertermia, taquicardia, diaforesis, rigidez muscular; en casos graves: rabdomiólisis, CID, insuficiencia renal y muerte',
    'Evitar la combinación siempre que sea posible; si es imprescindible, usar la dosis mínima de tramadol con vigilancia estrecha. En síndrome serotoninérgico: suspender ambos fármacos, ciproheptadina 4–8 mg VO/SNG, soporte hemodinámico, benzodiacepinas para agitación y mioclonus',
    'SÍNDROME SEROTONINÉRGICO — Combinación de alto riesgo con tramadol',
    EvidenceLevel.established,
    {RiskType.serotonin},
    [_kRefGG, _kRefMdx, _kRefUT, _kRefLex]),

  // 3. Digoxina + Amiodarona → Toxicidad Digitálica
  ('digoxina', 'amiodarona',
    InteractionSeverity.major,
    'La amiodarona inhibe la glucoproteína-P y la CYP3A4, reduciendo la eliminación renal y hepática de digoxina; el nivel plasmático de digoxina aumenta 70–100% en los primeros 7–14 días',
    'Toxicidad digitálica: náuseas, vómitos, visión con halos amarillo-verdosos, bradicardia, bloqueos AV de alto grado, arritmias ventriculares (TV bidireccional), trastornos del potasio',
    'Reducir la dosis de digoxina a la mitad al iniciar amiodarona; monitorear niveles de digoxina (objetivo 0,5–0,9 ng/mL) al 3.°, 7.° y 14.° día; ajustar según niveles y función renal; vigilar potasio sérico (hipopotasemia potencia toxicidad)',
    'TOXICIDAD DIGITÁLICA — Reducir dosis de digoxina 50% al agregar amiodarona',
    EvidenceLevel.established,
    {RiskType.plasmaLevel},
    [_kRefGG, _kRefKatz, _kRefMdx, _kRefUT]),

  // ═══════════════════════════════════════════════════════════════════════════
  // LOTE 300 INTERACCIONES — Fármacos nuevos × base existente
  // Fuentes: UpToDate 2024, Goodman & Gilman 14ª, Micromedex 2024, IDSA
  // ═══════════════════════════════════════════════════════════════════════════

  // ── SECCIÓN 1: Paxlovid (Nirmatrelvir+Ritonavir) ─────────────────────────

  // 1
  ('paxlovid', 'opioide',
    InteractionSeverity.contraindicated,
    'Ritonavir inhibe potentemente CYP3A4, bloqueando el metabolismo de opioides como oxicodona, hidromorfona y tapentadol; la exposición plasmática al opioide aumenta hasta 10 veces',
    'Sobredosis opioide: depresión respiratoria fatal, coma, miosis puntiforme, hipotensión severa',
    'Contraindicado. Suspender el opioide antes de iniciar Paxlovid o cambiar a fármaco no metabolizado por CYP3A4 (ej. morfina, hidromorfona parche)',
    'SOBREDOSIS OPIOIDE — Depresión respiratoria fatal con opioides + Paxlovid',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns, RiskType.plasmaLevel},
    [_kRefUT, _kRefMdx, _kRefFDA]),

  // 2
  ('paxlovid', 'lurasidona',
    InteractionSeverity.contraindicated,
    'Ritonavir inhibe CYP3A4 — única vía de metabolismo de la lurasidona — elevando sus niveles plasmáticos de forma masiva e incontrolable',
    'Toxicidad neurológica grave, arritmias ventriculares por prolongación del QT, sedación profunda e hipotensión crítica',
    'Contraindicación absoluta. Suspender lurasidona antes de iniciar Paxlovid. Cambiar temporalmente a quetiapina a dosis reducida bajo monitoreo cardiológico',
    'CONTRAINDICADO — Riesgo de arritmia y toxicidad neurológica grave con lurasidona',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.plasmaLevel, RiskType.arrhythmia},
    [_kRefFDA, _kRefUT, _kRefMdx]),

  // 3
  ('paxlovid', 'pimavanserina',
    InteractionSeverity.contraindicated,
    'Ritonavir inhibe CYP3A4, la principal vía de eliminación de pimavanserina; la acumulación del antipsicótico prolonga el intervalo QTc de forma crítica',
    'Arritmias ventriculares letales: Torsades de Pointes, fibrilación ventricular y muerte súbita cardíaca',
    'Contraindicado de forma absoluta. No coadministrar bajo ninguna circunstancia',
    'CONTRAINDICADO — Riesgo de muerte por Torsades de Pointes',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefFDA, _kRefMdx]),

  // 4
  ('paxlovid', 'sinvastatina',
    InteractionSeverity.contraindicated,
    'Ritonavir inhibe extremadamente CYP3A4 y OATP1B1; la simvastatina es un sustrato con margen terapéutico estrecho → niveles séricos aumentan >30 veces',
    'Rabdomiólisis fulminante: mioglobinuria, insuficiencia renal aguda, hiperpotasemia fatal',
    'Contraindicado. Suspender simvastatina/lovastatina en cuanto se inicia Paxlovid. Reanudar 2 días después de finalizar el tratamiento antiviral',
    'CONTRAINDICADO — Rabdomiólisis inminente con simvastatina + Paxlovid',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.nephrotoxicity, RiskType.plasmaLevel},
    [_kRefFDA, _kRefUT, _kRefMdx]),

  // 5
  ('paxlovid', 'midazolam',
    InteractionSeverity.contraindicated,
    'Ritonavir bloquea el metabolismo de primer paso del midazolam oral por CYP3A4; el AUC del midazolam oral aumenta >400 veces',
    'Sedación profunda prolongada, apnea, coma e insuficiencia respiratoria fatal',
    'Contraindicado con midazolam oral/sublingual. El midazolam IV puede usarse con cautela extrema en UCI bajo ventilación mecánica y monitoreo continuo',
    'CONTRAINDICADO — Apnea por midazolam oral con Paxlovid',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns},
    [_kRefFDA, _kRefMdx]),

  // 6
  ('paxlovid', 'amiodarona',
    InteractionSeverity.contraindicated,
    'Ritonavir inhibe CYP3A4 y P-gp, reduciendo el aclaramiento de amiodarona y su metabolito activo DEA; acumulación a niveles tóxicos con vida media >40 días',
    'Arritmias letales por toxicidad por amiodarona: TV polimórfica, FV, bradiarritmias graves, toxicidad pulmonar y hepática acelerada',
    'Contraindicación absoluta documentada en la ficha técnica de Paxlovid. No coadministrar bajo ninguna circunstancia',
    'CONTRAINDICADO — Riesgo de muerte por acumulación de amiodarona',
    EvidenceLevel.established,
    {RiskType.arrhythmia, RiskType.qtProlongation, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx, _kRefUT]),

  // 7
  ('paxlovid', 'rifampicina',
    InteractionSeverity.contraindicated,
    'Rifampicina es el inductor más potente de CYP3A4 y P-gp; reduce los niveles de nirmatrelvir/ritonavir >90%, anulando por completo la actividad antiviral',
    'Fracaso terapéutico total del tratamiento COVID-19, riesgo de selección de variantes resistentes',
    'Contraindicación absoluta. Suspender rifampicina antes de iniciar Paxlovid. Considerar regímenes alternativos antituberculosos sin rifampicina durante el tratamiento antiviral',
    'CONTRAINDICADO — Rifampicina anula eficacia de Paxlovid completamente',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefFDA, _kRefUT]),

  // 8
  ('paxlovid', 'carbamazepina',
    InteractionSeverity.contraindicated,
    'Carbamazepina induce fuertemente CYP3A4 (y se autoiduce) reduciendo los niveles de nirmatrelvir/ritonavir por debajo del umbral terapéutico',
    'Fracaso antiviral: los niveles de nirmatrelvir caen hasta un 87% con carbamazepina',
    'Contraindicado. Cambiar temporalmente el anticonvulsivo a levetiracetam o lamotrigina durante el tratamiento con Paxlovid',
    'CONTRAINDICADO — Carbamazepina elimina eficacia de Paxlovid',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefFDA, _kRefMdx]),

  // 9
  ('paxlovid', 'ranolazina',
    InteractionSeverity.contraindicated,
    'Ritonavir inhibe CYP3A4 y P-gp, duplicando o triplicando los niveles de ranolazina con riesgo de Torsades de Pointes',
    'Prolongación crítica del QT, taquicardia ventricular polimórfica y muerte súbita',
    'Contraindicado según ficha técnica de Paxlovid. Suspender ranolazina durante el tratamiento antiviral',
    'CONTRAINDICADO — Arritmia ventricular fatal por ranolazina acumulada',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefFDA]),

  // 10
  ('paxlovid', 'ergotamina',
    InteractionSeverity.contraindicated,
    'Ritonavir inhibe el metabolismo de la ergotamina por CYP3A4; la acumulación del alcaloide produce vasoconstricción arterial periférica extrema',
    'Ergotismo agudo: isquemia de extremidades, gangrena digital, angina mesentérica, accidente cerebrovascular por vasoespasmo',
    'Contraindicado. Suspender ergotamina antes de Paxlovid. Para cefalea usar gepantes o triptanes (con monitoreo)',
    'CONTRAINDICADO — Ergotismo agudo con riesgo de gangrena isquémica',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.other},
    [_kRefFDA, _kRefMdx]),

  // 11
  ('paxlovid', 'tramadol',
    InteractionSeverity.major,
    'Ritonavir puede aumentar la exposición al tramadol vía CYP3A4; además, la inhibición de CYP2D6 puede reducir la conversión a M1 pero aumentar el tramadol parental con riesgo convulsivo y serotoninérgico',
    'Convulsiones, síndrome serotoninérgico, toxicidad opioide aumentada',
    'Evitar si es posible. Si es inevitable, usar dosis mínima de tramadol con monitoreo neurológico estricto durante los 5 días de Paxlovid',
    'ALTO RIESGO — Convulsiones y toxicidad serotoninérgica con tramadol',
    EvidenceLevel.probable,
    {RiskType.serotonin, RiskType.seizure, RiskType.cns},
    [_kRefUT, _kRefMdx]),

  // 12
  ('paxlovid', 'atorvastatina',
    InteractionSeverity.major,
    'Ritonavir inhibe CYP3A4 y OATP1B1; los niveles de atorvastatina aumentan hasta 9 veces',
    'Miopatía grave, elevación marcada de CPK, riesgo de rabdomiólisis subclínica',
    'Suspender atorvastatina durante los 5 días de Paxlovid y por 2 días adicionales. Reanudar con CPK de control. Si el paciente no puede suspenderla, usar dosis mínima (10 mg) con monitoreo clínico diario',
    'SUSPENDER ESTATINA — Atorvastatina durante tratamiento con Paxlovid',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefFDA, _kRefUT]),

  // 13
  ('paxlovid', 'warfarina',
    InteractionSeverity.major,
    'Ritonavir inhibe CYP2C9 (metabolismo de la S-warfarina) y CYP3A4 (R-warfarina); efecto neto impredecible sobre el INR — puede aumentar o disminuir',
    'Elevación del INR con riesgo de hemorragia mayor o, paradójicamente, descenso con riesgo trombótico',
    'Medir INR antes de iniciar, al día 2–3 y al finalizar Paxlovid. Ajustar dosis de warfarina según resultados. Informar al paciente sobre signos de sangrado y trombosis',
    'MONITOREO DIARIO DE INR — Interacción imprevisible con warfarina',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefFDA, _kRefUT, _kRefMdx]),

  // 14
  ('paxlovid', 'rivaroxabana',
    InteractionSeverity.major,
    'Ritonavir inhibe CYP3A4 y P-gp, ambas vías principales de eliminación de rivaroxabán; el AUC del anticoagulante puede aumentar hasta un 160%',
    'Sangrado mayor: hemorragia intracraneal, gastrointestinal masiva, hematomas musculares extensos',
    'Evitar la combinación si el riesgo hemorrágico del paciente es alto. Si es inevitable, reducir dosis de rivaroxabán o cambiar temporalmente a heparina de bajo peso molecular durante los 5 días de Paxlovid',
    'ALTO RIESGO DE SANGRADO — Rivaroxabán acumulado con Paxlovid',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefFDA, _kRefUT]),

  // 15
  ('paxlovid', 'ticagrelor',
    InteractionSeverity.major,
    'Ritonavir inhibe CYP3A4, la principal vía de metabolismo del ticagrelor; los niveles plasmáticos aumentan marcadamente',
    'Hemorragia mayor espontánea: epistaxis, equimosis masivas, sangrado gastrointestinal alto',
    'Considerar suspensión temporal del ticagrelor durante Paxlovid si el riesgo hemorrágico supera el trombótico. Alternativa: clopidogrel (no afectado por CYP3A4 para su metabolismo). Monitorizar signos de sangrado activamente',
    'HEMORRAGIA MAYOR — Ticagrelor acumulado con Paxlovid',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefFDA, _kRefUT]),

  // 16
  ('paxlovid', 'diltiazem',
    InteractionSeverity.major,
    'Ritonavir inhibe CYP3A4; el diltiazem es sustrato e inhibidor moderado de CYP3A4 → acumulación bidireccional de ambos fármacos con efectos sobre el nódulo AV',
    'Bradicardia sinusal severa, bloqueo AV de 2.°-3.° grado, hipotensión profunda',
    'Monitoreo electrocardiográfico y de PA durante los 5 días de Paxlovid. Reducir dosis de diltiazem al 50%. Considerar pausa del diltiazem si clínicamente posible',
    'BRADICARDIA GRAVE — Reducir dosis de diltiazem durante Paxlovid',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    [_kRefFDA, _kRefUT]),

  // 17
  ('paxlovid', 'quetiapina',
    InteractionSeverity.major,
    'Ritonavir inhibe CYP3A4, única vía de metabolismo de la quetiapina; los niveles aumentan hasta 6 veces',
    'Sedación extrema, hipotensión ortostática severa con síncope, prolongación del QT',
    'Reducir dosis de quetiapina al mínimo terapéutico (25-50 mg) durante los 5 días de Paxlovid. Monitorizar ECG y presión arterial. Reanudar dosis habitual al finalizar el antiviral',
    'SEDACIÓN EXTREMA — Reducir quetiapina durante Paxlovid',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.cardiovascular, RiskType.qtProlongation},
    [_kRefFDA, _kRefUT]),

  // 18
  ('paxlovid', 'isrs',
    InteractionSeverity.major,
    'Ritonavir puede inhibir CYP2D6 y CYP3A4 dependiendo del ISRS específico (fluoxetina, paroxetina, sertralina, escitalopram); posible elevación de niveles de serotonina plasmática',
    'Síndrome serotoninérgico, náuseas, mareos, palpitaciones; monitorizar QT con escitalopram',
    'Monitorear estrechamente durante los 5 días. Para escitalopram: realizar ECG al día 2. Informar al paciente sobre signos de síndrome serotoninérgico',
    'MONITOREO ESTRECHO — ISRS + Paxlovid: riesgo serotoninérgico y QT',
    EvidenceLevel.probable,
    {RiskType.serotonin, RiskType.qtProlongation},
    [_kRefUT, _kRefMdx]),

  // 19
  ('paxlovid', 'fluticasona',
    InteractionSeverity.major,
    'Ritonavir inhibe intensamente CYP3A4; la fluticasona inhalada normalmente tiene biodisponibilidad sistémica <1%, pero la inhibición metabólica aumenta esta exposición hasta 50 veces',
    'Síndrome de Cushing iatrogénico, supresión del eje hipotálamo-hipófiso-adrenal (HHA), insuficiencia adrenal secundaria al suspender el corticoide',
    'Considerar cambiar temporalmente a beclometasona (menor interacción con CYP3A4). Si no es posible, informar al paciente sobre síntomas de supresión adrenal. No suspender abruptamente tras el tratamiento',
    'SÍNDROME DE CUSHING — Fluticasona acumulada con Paxlovid: monitorear',
    EvidenceLevel.established,
    {RiskType.other, RiskType.increasedToxicity},
    [_kRefFDA, _kRefUT]),

  // 20
  ('paxlovid', 'digoxina',
    InteractionSeverity.major,
    'Ritonavir inhibe la P-glucoproteína intestinal y renal, reduciendo la eliminación de digoxina; los niveles séricos aumentan 25-75%',
    'Toxicidad digitálica: náuseas, bradicardia, bloqueo AV, arritmias ventriculares, visión en halos',
    'Medir niveles de digoxina antes de iniciar Paxlovid y al día 3. Reducir dosis de digoxina empíricamente al 50-75%. Monitorear ECG y electrolitos (K+)',
    'TOXICIDAD DIGITÁLICA — Medir digoxinemia antes y durante Paxlovid',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.arrhythmia},
    [_kRefFDA, _kRefUT, _kRefMdx]),

  // ── SECCIÓN 2: Antipsicóticos nuevos (Lurasidona, Asenapina, etc.) ─────────

  // 21
  ('lurasidona', 'claritromicina',
    InteractionSeverity.contraindicated,
    'Claritromicina inhibe potentemente CYP3A4, única vía metabólica de la lurasidona; los niveles aumentan hasta 9 veces',
    'Toxicidad neurológica grave, sedación profunda, hipotensión severa, prolongación del QT',
    'Contraindicado según ficha técnica de lurasidona. Usar azitromicina (no inhibe CYP3A4 significativamente) como alternativa antibiótica',
    'CONTRAINDICADO — Lurasidona + Claritromicina: toxicidad neurológica grave',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.plasmaLevel, RiskType.cns},
    [_kRefFDA, _kRefMdx]),

  // 22
  ('lurasidona', 'rifampicina',
    InteractionSeverity.major,
    'Rifampicina, carbamazepina, fenitoína y fenobarbital inducen fuertemente CYP3A4; los niveles de lurasidona se reducen hasta un 80%',
    'Fracaso terapéutico total: recaída psicótica o maníaca por niveles subterapéuticos del antipsicótico',
    'Contraindicado según ficha técnica. Cambiar a antipsicótico no dependiente de CYP3A4 (haloperidol, risperidona) durante el uso del inductor',
    'FRACASO TERAPÉUTICO — Inductores enzimáticos anulan efecto de lurasidona',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefFDA, _kRefUT]),

  // 23
  ('lurasidona', 'fluconazol',
    InteractionSeverity.contraindicated,
    'Fluconazol (inhibidor moderado de CYP3A4 y potente de CYP2C19) duplica los niveles plasmáticos de lurasidona de forma sostenida',
    'Sedación excesiva, hipotensión ortostática, prolongación del QTc con riesgo de arritmia',
    'Contraindicado. Cambiar a itraconazol tópico u otro antifúngico sin efecto sobre CYP3A4',
    'CONTRAINDICADO — Fluconazol duplica niveles de lurasidona',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.qtProlongation},
    [_kRefFDA]),

  // 24
  ('lurasidona', 'metoclopramida',
    InteractionSeverity.major,
    'Ambos fármacos antagonizan receptores dopaminérgicos D2 de forma aditiva; la suma del bloqueo dopaminérgico central supera el umbral de toxicidad extrapiramidal',
    'Distonías agudas dolorosas (crisis oculogira, tortícolis), acatisia intensa, parkinsonismo farmacológico',
    'Evitar la combinación. Si se necesita antiemético, preferir ondansetrona o domperidona (actúa periféricamente). Si ya ocurrió distonía: difenhidramina 25-50 mg IV',
    'DISTONÍA AGUDA — Bloqueo dopaminérgico aditivo con metoclopramida',
    EvidenceLevel.established,
    {RiskType.other, RiskType.increasedToxicity},
    [_kRefGG, _kRefUT]),

  // 25
  ('clozapina', 'ciprofloxacino',
    InteractionSeverity.contraindicated,
    'Ciprofloxacino inhibe fuertemente CYP1A2, principal vía de metabolismo de la clozapina; los niveles plasmáticos pueden aumentar 3-5 veces en 24-48 horas',
    'Toxicidad por clozapina: convulsiones tónico-clónicas generalizadas, colapso circulatorio, agranulocitosis acelerada, hipertermia',
    'Contraindicado. Usar antibiótico alternativo: amoxicilina-clavulánico, piperacilina-tazobactam, trimetoprim (sin sulfametoxazol en clozapina). Si se debe usar ciprofloxacino: reducir clozapina al 33% y medir niveles diariamente',
    'CONTRAINDICADO — Ciprofloxacino eleva clozapina: riesgo de convulsiones',
    EvidenceLevel.established,
    {RiskType.seizure, RiskType.plasmaLevel, RiskType.myelosuppression},
    [_kRefGG, _kRefMdx, _kRefUT]),

  // 26
  ('clozapina', 'benzodiazepínico',
    InteractionSeverity.major,
    'La clozapina produce sedación, hipotensión y depresión respiratoria; las benzodiazepinas suman efectos depresores del SNC de forma sinérgica y no aditiva',
    'Colapso cardiorrespiratorio (especialmente en primeras dosis de clozapina): hipotensión severa, apnea, bradicardia, paro respiratorio',
    'Evitar la coadministración al inicio de clozapina. Si es imprescindible: usar dosis mínima de BZD (lorazepam 0.5 mg máx), con equipo de reanimación disponible y monitoreo continuo de O2 y PA por 4 horas tras la dosis',
    'COLAPSO CARDIORRESPIRATORIO — Evitar benzodiacepinas con clozapina al inicio',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cardiovascular, RiskType.cns},
    [_kRefGG, _kRefMdx, _kRefUT, _kRefLex]),

  // 27
  ('clozapina', 'haloperidol',
    InteractionSeverity.major,
    'Ambos antipsicóticos tienen propiedades que aumentan el riesgo del Síndrome Neuroléptico Maligno; la combinación potencia el bloqueo dopaminérgico nigroestriatal y el estrés hipotalámico',
    'Síndrome Neuroléptico Maligno: hipertermia >40°C, rigidez muscular generalizada, inestabilidad autonómica, alteración de conciencia, rabdomiólisis, CPK >10.000 U/L',
    'Evitar la politerapia antipsicótica. Si es necesaria la clozapina + otro antipsicótico, preferir aripiprazol (menor bloqueo D2 puro). Informar sobre síntomas del SNM. Monitorear temperatura, CPK y función renal',
    'SÍNDROME NEUROLÉPTICO MALIGNO — Evitar combinación clozapina + haloperidol',
    EvidenceLevel.probable,
    {RiskType.myopathy, RiskType.other},
    [_kRefGG, _kRefUT, _kRefMdx]),

  // 28
  ('ziprasidona', 'amiodarona',
    InteractionSeverity.major,
    'Ziprasidona prolonga el QTc de forma dependiente de dosis; la amiodarona prolonga el QT por bloqueo de canales hERR/KCNH2; efecto aditivo crítico',
    'Torsades de Pointes, fibrilación ventricular, muerte súbita cardíaca',
    'Evitar la combinación. Cambiar ziprasidona a haloperidol o risperidona si el paciente requiere amiodarona crónicamente. Si no es posible: ECG antes de iniciar, QTc basal <450 ms, monitoreo ECG cada 48 h',
    'TORSADES DE POINTES — Combinación arritmogénica crítica ziprasidona + amiodarona',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx, _kRefUT]),

  // 29
  ('ziprasidona', 'ondansetrona',
    InteractionSeverity.major,
    'Ambos fármacos prolongan el intervalo QTc: ziprasidona bloquea canales de potasio hERG y ondansetrona inhibe canales iKr de forma aditiva',
    'Prolongación del QTc con riesgo de Torsades de Pointes, especialmente en presencia de hipopotasemia o hipomagnesemia',
    'Monitorear ECG antes y durante la combinación. Corregir electrolitos (K+ objetivo >4.0 mEq/L, Mg2+ >2.0 mg/dL). Considerar metoclopramida como antiemético alternativo',
    'PROLONGACIÓN QT — Monitoreo ECG obligatorio con ziprasidona + ondansetrona',
    EvidenceLevel.probable,
    {RiskType.qtProlongation},
    [_kRefMdx, _kRefUT]),

  // 30
  ('quetiapina', 'claritromicina',
    InteractionSeverity.major,
    'Claritromicina inhibe CYP3A4; los niveles de quetiapina aumentan 4-6 veces con riesgo de toxicidad severa',
    'Sedación extrema, hipotensión ortostática, prolongación del QT, síncope',
    'Evitar la combinación. Usar azitromicina (menor interacción). Si es inevitable: reducir quetiapina al 25% de la dosis habitual y monitorear ECG y PA',
    'SEDACIÓN + QT — Claritromicina eleva quetiapina 4-6 veces',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.qtProlongation, RiskType.cardiovascular},
    [_kRefMdx, _kRefUT]),

  // ── SECCIÓN 3: Nuevos antidiabéticos (iSGLT2 y arGLP-1) ─────────────────

  // 31
  ('canagliflozina', 'rifampicina',
    InteractionSeverity.contraindicated,
    'Rifampicina induce fuertemente UGT1A9 y UGT2B4 (glucuronidación), principales vías de eliminación de la canagliflozina; los niveles plasmáticos caen hasta un 51%',
    'Fracaso terapéutico en el control glucémico, pérdida del efecto nefroprotector y cardioprotector del iSGLT2',
    'Aumentar dosis de canagliflozina a 300 mg/día (dosis máxima) durante el uso de rifampicina, o cambiar a otro antidiabético. Monitorear glucemia estrechamente',
    'FRACASO GLUCÉMICO — Rifampicina reduce canagliflozina a niveles subterapéuticos',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefFDA, _kRefUT]),

  // 32
  ('dapagliflozina', 'furosemida',
    InteractionSeverity.major,
    'Los iSGLT2 producen diuresis osmótica activa (glucosuria) y los diuréticos de asa producen natriuresis e hipopotasemia; la acción diurética es aditiva y sinérgica en la depleción de volumen',
    'Deshidratación severa, hipotensión ortostática con síncope, insuficiencia renal prerrenal aguda, hipopotasemia que puede precipitar arritmias',
    'Iniciar iSGLT2 con dosis reducida en pacientes con furosemida >40 mg/día. Instruir al paciente para beber líquidos abundantes, medir PA postural y suspender el iSGLT2 ante náuseas o vómitos. Controlar electrolitos al inicio y a las 2 semanas',
    'DESHIDRATACIÓN SEVERA — Potenciación diurética iSGLT2 + furosemida',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.nephrotoxicity, RiskType.electrolyte},
    [_kRefGG, _kRefMdx, _kRefUT]),

  // 33
  ('dapagliflozina', 'enalapril',
    InteractionSeverity.major,
    'Los iSGLT2 reducen la precarga renal (diuresis osmótica) y los IECAs dilatan la arteriola eferente; la combinación puede comprometer agudamente la TFG, especialmente al inicio',
    'Caída aguda de la TFG (hipoperfusión glomerular): insuficiencia renal aguda funcional, hiperpotasemia',
    'Monitorear creatinina sérica y potasio a los 7 y 14 días del inicio de la combinación. Instruir al paciente para suspender el iSGLT2 ante episodios febriles, diarrea o reducción drástica de ingesta hídrica (riesgo de cetoacidosis euglicémica)',
    'INSUFICIENCIA RENAL AGUDA — Monitorear TFG y K+ al combinar iSGLT2 + IECA',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.hyperkalemia},
    [_kRefUT, _kRefGG]),

  // 34
  ('dapagliflozina', 'insulina',
    InteractionSeverity.major,
    'Los iSGLT2 potencian el efecto hipoglucemiante de la insulina al aumentar la glucosuria y reducir la glucemia en 1-2 mmol/L adicionales; la glucemia basal en la que ocurre hipoglucemia se anticipa',
    'Hipoglucemia grave, especialmente nocturna; riesgo de cetoacidosis euglicémica (glucemia normal pero cetonas elevadas)',
    'Reducir la dosis de insulina basal un 20% al iniciar el iSGLT2. Instruir al paciente sobre el riesgo de cetoacidosis euglicémica: medir cetonas si hay síntomas aunque la glucemia sea normal. Suspender el iSGLT2 24-48 h antes de cirugía electiva',
    'HIPOGLICEMIA Y CETOACIDOSIS — Reducir insulina 20% al iniciar iSGLT2',
    EvidenceLevel.established,
    {RiskType.hypoglycemia, RiskType.other},
    [_kRefGG, _kRefUT, _kRefFDA]),

  // 35
  ('dapagliflozina', 'glibenclamida',
    InteractionSeverity.major,
    'La combinación de iSGLT2 (que reduce glucemia ~1-2 mmol/L) con secretagogos de insulina (sulfonilureas) que liberan insulina de forma glucosa-independiente produce hipoglucemia sinérgica',
    'Hipoglucemia grave, especialmente postprandial tardía y nocturna; riesgo aumentado en pacientes >65 años o con IRC',
    'Reducir dosis de la sulfonilurea al 50% al iniciar el iSGLT2. Instruir al paciente para reconocer hipoglucemia. Monitorear glucemia en ayunas durante las primeras 2 semanas. Considerar cambiar la sulfonilurea a inhibidor de DPP-4',
    'HIPOGLICEMIA GRAVE — Reducir sulfonilurea 50% al agregar iSGLT2',
    EvidenceLevel.established,
    {RiskType.hypoglycemia},
    [_kRefGG, _kRefMdx, _kRefUT]),

  // 36
  ('liraglutida', 'insulina',
    InteractionSeverity.major,
    'Los arGLP-1 estimulan la secreción de insulina de forma glucosa-dependiente y ralentizan el vaciamiento gástrico; la combinación con insulina basal tiene riesgo de hipoglucemia, aunque la interacción es glucose-dependiente',
    'Hipoglucemia grave principalmente nocturna; pérdida de peso marcada con liraglutida puede requerir ajustes continuos de insulina',
    'Reducir insulina basal 20% al iniciar el arGLP-1. Monitorear glucemia en ayunas diariamente las primeras 4 semanas. Ajustar dosis progresivamente según respuesta glucémica real',
    'HIPOGLICEMIA — Reducir insulina basal al iniciar arGLP-1 (liraglutida, semaglutida)',
    EvidenceLevel.established,
    {RiskType.hypoglycemia},
    [_kRefGG, _kRefUT, _kRefFDA]),

  // 37
  ('liraglutida', 'warfarina',
    InteractionSeverity.major,
    'El retraso del vaciamiento gástrico inducido por los arGLP-1 altera la absorción de warfarina (pico de Cmax y Tmax retrasados); los cambios en el INR son impredecibles',
    'Riesgo de hemorragia mayor por elevación inesperada del INR o de trombosis por descenso del INR',
    'Medir INR a los 3-5 días del inicio del arGLP-1 y tras cada cambio de dosis. Instruir al paciente sobre signos de sangrado (heces oscuras, equimosis inexplicables)',
    'MONITOREO INR — Aripiprazol GLP-1 altera absorción de warfarina',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic},
    [_kRefUT, _kRefMdx]),

  // 38
  ('liraglutida', 'glibenclamida',
    InteractionSeverity.major,
    'Los arGLP-1 aumentan la sensibilidad insulínica y potencian la secreción de insulina; las sulfonilureas liberan insulina de forma fija e independiente de la glucosa',
    'Hipoglucemia grave y prolongada; el riesgo es mayor en pacientes con IRC, ancianos o con ingesta irregular',
    'Reducir dosis de sulfonilurea al 50% al agregar el arGLP-1. Preferir gliclazida MR (menor duración de hipoglucemia) sobre glibenclamida. Monitorear glucemia 2 h post-desayuno',
    'HIPOGLICEMIA — Reducir sulfonilurea 50% al agregar arGLP-1',
    EvidenceLevel.established,
    {RiskType.hypoglycemia},
    [_kRefGG, _kRefUT]),

  // ── SECCIÓN 4: Triptanes, gepantes y monoclonales para cefaleas ───────────

  // 39
  ('sumatriptano', 'isrs',
    InteractionSeverity.major,
    'Ambos potencian la neurotransmisión serotoninérgica central: los ISRS/IRSN inhiben la recaptación de 5-HT; los triptanes activan receptores 5-HT1B/1D presinápticos y pueden aumentar la liberación de serotonina en el rafe dorsal',
    'Síndrome serotoninérgico moderado-severo: agitación, mioclonus, hiperreflexia, hipertermia, diaforesis, taquicardia; en casos graves: rabdomiólisis y CID',
    'La FDA emitió advertencia en 2010 pero evidencia actual sugiere que el riesgo es bajo con uso esporádico de triptanes a dosis habituales. Informar sobre síntomas de síndrome serotoninérgico. Evitar uso repetido frecuente de triptanes en pacientes con ISRS',
    'SÍNDROME SEROTONINÉRGICO — Triptanes + ISRS/IRSN: informar al paciente',
    EvidenceLevel.possible,
    {RiskType.serotonin},
    [_kRefFDA, _kRefUT, _kRefGG]),

  // 40
  ('sumatriptano', 'linezolida',
    InteractionSeverity.contraindicated,
    'Linezolida es un inhibidor reversible de la MAO (IMAO); bloquea la degradación de serotonina en la hendidura sináptica; los triptanes activan receptores 5-HT1 y pueden aumentar la liberación de 5-HT',
    'Síndrome serotoninérgico grave: hipertermia maligna, rigidez muscular, crisis hipertensiva, convulsiones, coma y muerte',
    'Contraindicado. No usar triptanes dentro de las 24 horas de linezolida. Para el tratamiento de la migraña aguda, considerar AINEs + antieméticos o paracetamol',
    'CONTRAINDICADO — Triptanes + Linezolida: síndrome serotoninérgico grave',
    EvidenceLevel.established,
    {RiskType.serotonin},
    [_kRefFDA, _kRefMdx]),

  // 41
  ('eletriptano', 'claritromicina',
    InteractionSeverity.contraindicated,
    'Claritromicina inhibe intensamente CYP3A4, principal vía de metabolismo del eletriptán; los niveles plasmáticos aumentan hasta 5 veces',
    'Vasoespasmo coronario, opresión torácica severa, angina, isquemia miocárdica transitoria por activación de receptores 5-HT1B vasculares',
    'Contraindicado según ficha técnica del eletriptán. No usar eletriptán en las 72 horas siguientes a claritromicina. Usar sumatriptán (no metabolizado por CYP3A4) como alternativa',
    'CONTRAINDICADO — Eletriptán + Claritromicina: vasoespasmo coronario',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.plasmaLevel},
    [_kRefFDA]),

  // 42
  ('rimegepant', 'claritromicina',
    InteractionSeverity.contraindicated,
    'Claritromicina inhibe fuertemente CYP3A4, principal vía de metabolismo del rimegepant; el AUC del gepante aumenta más de 3 veces',
    'Toxicidad sistémica del gepante: nauseas severas, estreñimiento, elevación de transaminasas, efectos vasculares inesperados',
    'Contraindicado según ficha técnica de Nurtec (rimegepant). No usar otra dosis de rimegepant en las 48 h siguientes. Usar AINE o sumatriptán como alternativa',
    'CONTRAINDICADO — Rimegepant + Claritromicina: toxicidad del gepante triplicada',
    EvidenceLevel.established,
    {RiskType.increasedToxicity, RiskType.plasmaLevel},
    [_kRefFDA]),

  // 43
  ('sumatriptano', 'tramadol',
    InteractionSeverity.contraindicated,
    'El tramadol inhibe la recaptación de serotonina y noradrenalina (mecanismo ISRN) y actúa como opioide débil; los triptanes activan receptores 5-HT1B/D; la combinación produce hiperserotonemia sinérgica',
    'Síndrome serotoninérgico grave: convulsiones, rigidez muscular, hipertermia >41°C, inestabilidad autonómica',
    'Contraindicado. Usar alternativas para la cefalea (AINEs, paracetamol, naproxeno). Si ya se administraron ambos y aparecen síntomas: ciproheptadina 4-8 mg y soporte intensivo',
    'CONTRAINDICADO — Triptanes + tramadol: síndrome serotoninérgico grave',
    EvidenceLevel.established,
    {RiskType.serotonin, RiskType.seizure},
    [_kRefGG, _kRefMdx, _kRefUT]),

  // 44
  ('lasmiditano', 'benzodiazepínico',
    InteractionSeverity.major,
    'El lasmiditan actúa sobre receptores 5-HT1F y produce sedación y mareos significativos como efectos secundarios directos; las benzodiazepinas deprimen el SNC de forma sinérgica',
    'Somnolencia severa incapacitante, deterioro psicomotriz peligroso para la conducción de vehículos',
    'Evitar conducir durante al menos 8 horas después de la dosis de lasmiditan. Informar al paciente de la suma de sedación con BZD. Considerar sumatriptán o rimegepant como alternativas si el paciente toma BZD de forma crónica',
    'SEDACIÓN SEVERA — No conducir 8h tras lasmiditan; potenciado por BZD',
    EvidenceLevel.established,
    {RiskType.cns},
    [_kRefFDA, _kRefUT]),

  // 45
  ('lasmiditano', 'propranolol',
    InteractionSeverity.major,
    'Propranolol reduce la eliminación de lasmiditan, aumentando sus niveles plasmáticos un 19%; la bradicardia basal por el betabloqueador se suma al efecto vagotónico del lasmiditan',
    'Bradicardia sinusal severa, mareo significativo, riesgo de síncope reflejo',
    'Reducir dosis de lasmiditan a 50 mg (dosis más baja disponible) en pacientes que toman propranolol. Monitorizar la frecuencia cardíaca tras la dosis',
    'BRADICARDIA — Reducir lasmiditan a 50 mg con propranolol',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    [_kRefFDA]),

  // 46
  ('rimegepant', 'fluconazol',
    InteractionSeverity.major,
    'Fluconazol inhibe CYP3A4 de forma moderada y CYP2C19 potentemente; aumenta el AUC del rimegepant hasta un 40-60%',
    'Aumento de efectos adversos del gepante: náuseas, estreñimiento, fatiga',
    'Reducir a la mitad la frecuencia de dosis de rimegepant. No usar más de una vez cada 96 horas con fluconazol. Considerar AINE o triptán alternativo',
    'TOXICIDAD AUMENTADA — Fluconazol eleva rimegepant 40-60%',
    EvidenceLevel.probable,
    {RiskType.increasedToxicity, RiskType.plasmaLevel},
    [_kRefFDA, _kRefUT]),

  // 47
  ('atogepant', 'claritromicina',
    InteractionSeverity.major,
    'Claritromicina inhibe CYP3A4; el atogepant es sustrato de CYP3A4 con moderada extracción hepática; los niveles aumentan aproximadamente 2-3 veces',
    'Toxicidad del gepante: náuseas, elevación de enzimas hepáticas, estreñimiento severo',
    'Reducir dosis de atogepant a 10 mg (dosis mínima) al usar claritromicina. Evitar la combinación si es posible. Usar eritromicina tópica o amoxicilina si se necesita antibiótico',
    'REDUCIR DOSIS — Atogepant a 10 mg con claritromicina',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.increasedToxicity},
    [_kRefFDA]),

  // ── SECCIÓN 5: EII y biológicos ──────────────────────────────────────────

  // 48
  ('upadacitinibe', 'claritromicina',
    InteractionSeverity.contraindicated,
    'Claritromicina inhibe fuertemente CYP3A4, la principal vía metabólica del upadacitinib; los niveles plasmáticos pueden triplicarse',
    'Toxicidad hematológica del inhibidor de JAK: neutropenia grave, linfopenia, anemia, trombocitopenia; riesgo de infecciones oportunistas mortales',
    'Contraindicado durante el tratamiento con upadacitinib (Rinvoq). Usar amoxicilina o azitromicina como alternativa antibiótica',
    'CONTRAINDICADO — Claritromicina triplica upadacitinib: toxicidad hematológica',
    EvidenceLevel.established,
    {RiskType.myelosuppression, RiskType.infection, RiskType.plasmaLevel},
    [_kRefFDA, _kRefUT]),

  // 49
  ('upadacitinibe', 'rifampicina',
    InteractionSeverity.major,
    'Rifampicina es inductor potente de CYP3A4; reduce los niveles de upadacitinib en aproximadamente un 60%, eliminando su eficacia en EII',
    'Fracaso terapéutico: reactivación de la EII (colitis ulcerosa o enfermedad de Crohn)',
    'Contraindicado según ficha técnica. Cambiar el antibiótico o el esquema de tratamiento para EII. Si se debe usar rifampicina, suspender el inhibidor de JAK y monitorear la actividad de la enfermedad',
    'FRACASO TERAPÉUTICO — Rifampicina elimina eficacia de upadacitinib',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefFDA]),

  // 50
  ('ozanimodo', 'linezolida',
    InteractionSeverity.contraindicated,
    'El ozanimod produce un metabolito activo mayor (CC112273) que inhibe la MAO-B y levemente la MAO-A; la linezolida también inhibe la MAO; la combinación puede producir crisis hipertensivas graves',
    'Crisis hipertensiva severa, accidente cerebrovascular isquémico, síndrome serotoninérgico',
    'Contraindicado según ficha técnica de Zeposia (ozanimod). Suspender ozanimod al menos 3 días antes de iniciar linezolida',
    'CONTRAINDICADO — Ozanimod + Linezolida: crisis hipertensiva y síndrome serotoninérgico',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.serotonin},
    [_kRefFDA]),

  // 51
  ('ozanimodo', 'metoprolol',
    InteractionSeverity.major,
    'Los moduladores de S1P (ozanimod, etrasimod) producen bradicardia significativa al inicio por secuestro de linfocitos en ganglios linfáticos y efecto directo sobre el nódulo SA; los betabloqueadores suman efecto cronotrópico negativo',
    'Bradicardia severa (<40 lpm), bloqueo AV de 2.°-3.° grado, síncope, shock cardiogénico',
    'Realizar ECG antes de iniciar el modulador S1P. Monitorear FC y ECG durante las primeras 6 horas de la primera dosis. Considerar el ingreso hospitalario para la primera dosis en pacientes con betabloqueadores. Si la FC <40 lpm: suspender el modulador S1P',
    'BRADICARDIA GRAVE — Monitoreo ECG 6h en primera dosis de ozanimod + betabloqueador',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    [_kRefFDA, _kRefUT]),

  // 52
  ('ozanimodo', 'amitriptilina',
    InteractionSeverity.contraindicated,
    'El metabolito activo del ozanimod inhibe MAO-B; la amitriptilina es un TCA con propiedades adrenérgicas e inhibidor débil de la MAO; la combinación puede producir síndrome serotoninérgico y crisis hipertensivas',
    'Crisis hipertensiva, síndrome serotoninérgico, arritmias por activación adrenérgica',
    'Contraindicado. Cambiar a un antidepresivo sin actividad sobre la MAO (ISRS con precaución, o mirtazapina)',
    'CONTRAINDICADO — Ozanimod + Amitriptilina: crisis hipertensiva',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.serotonin},
    [_kRefFDA]),

  // 53
  ('sulfassalazina', 'warfarina',
    InteractionSeverity.major,
    'La sulfasalazina puede desplazar a la warfarina de su unión a la albúmina plasmática (90-99% unida a proteínas) y alterar la síntesis de vitamina K por la flora intestinal',
    'Elevación del INR con riesgo de hemorragia mayor; efecto más pronunciado en las primeras 2 semanas',
    'Medir INR antes de iniciar sulfasalazina y a los 7 y 14 días del inicio. Ajustar dosis de warfarina según resultados. Informar al paciente sobre signos de sangrado',
    'MONITOREO INR — Sulfasalazina desplaza warfarina: riesgo hemorrágico',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),

  // 54
  ('sulfassalazina', 'sulfametoxazol',
    InteractionSeverity.contraindicated,
    'Duplicación de estructura sulfonamídica: ambas son derivados de sulfonamidas. Suma de toxicidad hematológica (inhibición de folato) y dermatológica',
    'Aplasia medular grave, agranulocitosis, síndrome de Stevens-Johnson, necrólisis epidérmica tóxica',
    'Contraindicado. Usar trimetoprima sola o nitrofurantoína como alternativa antibiótica en el contexto de la EII',
    'CONTRAINDICADO — Doble sulfonamida: aplasia medular y Stevens-Johnson',
    EvidenceLevel.established,
    {RiskType.myelosuppression, RiskType.other},
    [_kRefGG, _kRefMdx]),

  // ── SECCIÓN 6: Dislipidemia, hemostáticos, Alzheimer ─────────────────────

  // 55
  ('gemfibrozil', 'sinvastatina',
    InteractionSeverity.contraindicated,
    'Gemfibrozilo inhibe la glucuronidación (UGT1A1/UGT1A3) de las estatinas y CYP2C8; los niveles de simvastatina y lovastatina aumentan hasta 4-5 veces sin posibilidad de compensación metabólica',
    'Rabdomiólisis masiva y fulminante: mioglobinuria marrón oscura, insuficiencia renal anúrica, hiperpotasemia fatal por liberación masiva de potasio intramuscular',
    'Contraindicado absolutamente (FDA). Si el paciente necesita un fibrato con estatina, usar fenofibrato + estatina (interacción significativamente menor). El bezafibrato también es más seguro que gemfibrozilo con estatinas',
    'CONTRAINDICADO FDA — Rabdomiólisis fatal: Gemfibrozilo + Simvastatina/Lovastatina',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.nephrotoxicity},
    [_kRefFDA, _kRefGG, _kRefMdx, _kRefUT]),

  // 56
  ('gemfibrozil', 'atorvastatina',
    InteractionSeverity.major,
    'Gemfibrozilo inhibe la glucuronidación y OATP1B1; los niveles de atorvastatina aumentan 1.8 veces; menor que simvastatina pero clínicamente relevante',
    'Miopatía, elevación de CPK, riesgo de rabdomiólisis especialmente en pacientes con IRC o hipotiroidismo',
    'Evitar si es posible. Si la combinación es necesaria: usar dosis mínima de atorvastatina (10 mg), monitorear CPK mensualmente. Instruir al paciente para reportar dolor muscular o debilidad',
    'MIOPATÍA — Monitorear CPK mensual con gemfibrozilo + atorvastatina',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefFDA, _kRefGG, _kRefMdx]),

  // 57
  ('acido bempedoico', 'sinvastatina',
    InteractionSeverity.contraindicated,
    'El ácido bempedoico inhibe el transportador OAT2 y comparte vías de excreción con simvastatina y lovastatina; los niveles de estas estatinas aumentan hasta un 60-70%',
    'Miopatía severa, rabdomiólisis, insuficiencia renal aguda',
    'Contraindicado superar 20 mg de simvastatina y 20 mg de lovastatina durante el uso de ácido bempedoico. Cambiar preferiblemente a rosuvastatina (no afectada significativamente por bempedoico)',
    'CONTRAINDICADO >20mg — Ácido bempedoico eleva simvastatina: rabdomiólisis',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefFDA]),

  // 58
  ('acido bempedoico', 'alopurinol',
    InteractionSeverity.major,
    'El ácido bempedoico inhibe el transportador OAT1/OAT3 renal, reduciendo la excreción de ácido úrico; los niveles de urato sérico aumentan 1.5-2 mg/dL sobre la línea basal',
    'Hiperuricemia sintomática, crisis aguda de gota articular (tofácea), nefrolitiasis úrica',
    'Monitorear ácido úrico sérico al inicio y a los 3 meses. Ajustar dosis de alopurinol según niveles de urato objetivo (<6 mg/dL). Instruir al paciente sobre síntomas de gota',
    'HIPERURICEMIA — Bempedoico + diuréticos tiazídicos: crisis de gota',
    EvidenceLevel.established,
    {RiskType.other},
    [_kRefFDA, _kRefUT]),

  // 59
  ('icosapento de etilo', 'warfarina',
    InteractionSeverity.major,
    'El EPA puro (icosapento) inhibe la función plaquetaria (inhibición de TXA2) y puede afectar la síntesis de factores de coagulación dependientes de vitamina K de forma secundaria; efecto anticoagulante aditivo sin alterar necesariamente el INR estándar',
    'Hemorragia mayor espontánea: sangrado gastrointestinal, hemorragia intracraneal, hematomas musculares extensos con INR dentro del rango terapéutico',
    'Monitorear signos de sangrado activamente. El INR puede no reflejar el riesgo hemorrágico real. En pacientes anticoagulados que inician Vascepa: considerar revisión del balance riesgo-beneficio. Control en 4 semanas',
    'SANGRADO MAYOR — Icosapento de etilo potencia anticoagulación sin alterar INR',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefUT, _kRefFDA]),

  // 60
  ('icosapento de etilo', 'ticagrelor',
    InteractionSeverity.major,
    'Ambos tienen efectos antiagregantes plaquetarios; el icosapento inhibe la síntesis de TXA2 (similar al AAS) y el ticagrelor bloquea el receptor P2Y12; la acción antiagregante es aditiva',
    'Sangrado gastrointestinal oculto, hemorragia subaguda en sitios de punción, epistaxis frecuente',
    'Monitorear signos de sangrado gastrointestinal (heces oscuras, epigastralgia). En procedimientos invasivos planificados: suspender icosapento 5-7 días antes',
    'SANGRADO AUMENTADO — Doble antiagregación con icosapento + ticagrelor',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic},
    [_kRefUT, _kRefGG]),

  // 61 — Donepezilo + anticolinérgicos
  ('donepezilo', 'atropina',
    InteractionSeverity.contraindicated,
    'Los inhibidores de la acetilcolinesterasa (donepezilo, rivastigmina, galantamina) aumentan la actividad colinérgica central y periférica; los anticolinérgicos (atropina, escopolamina, hioscina) la antagonizan de forma directa y completa',
    'Anulación total del efecto terapéutico del fármaco pro-Alzheimer, desencadenamiento de delirium hiperactivo por efecto anticolinérgico central predominante',
    'Contraindicado. Los anticolinérgicos están en la lista de Beers (medicamentos inapropiados en ancianos). Sustituir atropina/escopolamina por fármacos sin carga anticolinérgica para el control de secreciones o espasmo',
    'CONTRAINDICADO — Anticolinérgicos anulan inhibidores de colinesterasa en Alzheimer',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.cns},
    [_kRefGG, _kRefUT, _kRefMdx]),

  // 62 — Donepezilo + metoprolol
  ('donepezilo', 'metoprolol',
    InteractionSeverity.major,
    'Los inhibidores de la colinesterasa aumentan el tono vagal cardíaco vía estimulación parasimpática directa del nódulo SA; los betabloqueadores suprimen la respuesta simpática contrarreguladora; la suma produce bloqueo cronotrópico aditivo severo',
    'Bradicardia sinusal extrema (<40 lpm), síncope, bloqueo SA o AV, colapso hemodinámico',
    'Monitorear frecuencia cardíaca semanalmente al inicio de la combinación. Si FC <50 lpm en reposo: considerar reducir dosis de betabloqueador o cambiar a donepezilo en dosis nocturna (menor impacto vagotónico diurno). ECG basal obligatorio',
    'BRADICARDIA GRAVE — Monitorear FC semanal con inhibidor colinesterasa + betabloqueador',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    [_kRefGG, _kRefUT, _kRefMdx]),

  // 63 — Donepezilo + claritromicina
  ('donepezilo', 'claritromicina',
    InteractionSeverity.major,
    'Claritromicina inhibe CYP3A4, una de las vías de metabolismo del donepezilo; los niveles plasmáticos del pro-colinérgico aumentan un 40-50%; la galantamina comparte una interacción similar',
    'Crisis colinérgica periférica: diarrea severa, vómitos, broncospasmo, bradicardia extrema, hipersecreción glandular, calambres musculares',
    'Monitorear signos de toxicidad colinérgica durante el tratamiento con claritromicina. Usar azitromicina como alternativa antibiótica de primera elección en pacientes con Alzheimer tratados con inhibidores de colinesterasa',
    'CRISIS COLINÉRGICA — Claritromicina eleva donepezilo: bradicardia y diarrea',
    EvidenceLevel.probable,
    {RiskType.cardiovascular, RiskType.other},
    [_kRefUT, _kRefMdx]),

  // 64 — Memantina + acetazolamida
  ('memantina', 'acetazolamida',
    InteractionSeverity.major,
    'La memantina es eliminada principalmente por el riñón de forma dependiente del pH urinario; la alcalinización de la orina por acetazolamida o bicarbonato reduce dramáticamente la excreción renal de memantina hasta en un 80%',
    'Toxicidad por memantina: agitación psicomotriz severa, alucinaciones, confusión, psicosis aguda, marcha inestable, convulsiones',
    'Evitar la coadministración. Si el paciente requiere acetazolamida (glaucoma, epilepsia), considerar dosis menores de memantina y monitoreo neuropsiquiátrico estricto',
    'TOXICIDAD POR MEMANTINA — Acetazolamida alcaliniza orina: acumulación 80%',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.plasmaLevel},
    [_kRefGG, _kRefUT]),

  // 65 — Sofosbuvir + amiodarona
  ('sofosbuvir', 'amiodarona',
    InteractionSeverity.contraindicated,
    'Mecanismo no completamente elucidado; posiblemente la inhibición de la actividad del canal If por el sofosbuvir o por efecto directo sobre el sistema de conducción potenciado por la amiodarona produce bradicardia sinusal progresiva fatal',
    'Bradicardia sinusal letal, bloqueo AV completo de instauración rápida, asistolia, muerte súbita cardíaca (casos reportados en FDA MedWatch 2015)',
    'Contraindicación absoluta según ficha técnica de Sovaldi/Harvoni. Si el paciente requiere amiodarona, hospitalizar y monitorear el ritmo cardíaco durante 48 horas de inicio del antiviral. Considerar cambio de amiodarona a otro antiarrítmico',
    'CONTRAINDICADO — Muerte súbita cardíaca: Sofosbuvir + Amiodarona (FDA Black Box)',
    EvidenceLevel.established,
    {RiskType.arrhythmia, RiskType.cardiovascular},
    [_kRefFDA, _kRefMdx, _kRefUT]),

  // 66 — Sofosbuvir/Ledipasvir + carbamazepina
  ('sofosbuvir', 'carbamazepina',
    InteractionSeverity.contraindicated,
    'Carbamazepina, fenitoína y fenobarbital inducen P-gp y CYP3A4, reduciendo la absorción y aumentando el metabolismo del sofosbuvir y sus metabolitos; los niveles caen hasta un 72%',
    'Fracaso terapéutico del tratamiento de hepatitis C: niveles subterapéuticos con riesgo de selección de variantes resistentes pan-genotípicas',
    'Contraindicado. Cambiar el anticonvulsivo a levetiracetam, lamotrigina o lacosamida (sin inducción significativa) durante el tratamiento de la hepatitis C',
    'CONTRAINDICADO — Anticonvulsivantes inductores eliminan eficacia del antiviral HCV',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefFDA, _kRefUT]),

  // 67 — Ledipasvir + omeprazol
  ('ledipasvir', 'omeprazol',
    InteractionSeverity.major,
    'Ledipasvir y velpatasvir requieren acidez gástrica para disolverse y absorberse adecuadamente; los IBPs elevan el pH gástrico >5, reduciendo la solubilidad y la absorción del antiviral hasta un 40-50%',
    'Reducción de la concentración plasmática del antiviral y riesgo de niveles subterapéuticos que comprometen la cura sostenida de la hepatitis C (RVS12)',
    'Si es inevitable el IBP: usar omeprazol 20 mg máximo y tomar junto con el antiviral en ayunas (el pH post-deglución es más ácido inmediatamente). Si la supresión ácida es indispensable, usar famotidina 40 mg (12h después del antiviral)',
    'REDUCCIÓN EFICACIA HCV — Tomar ledipasvir/velpatasvir junto con IBP en ayunas',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefFDA, _kRefUT, _kRefMdx]),

  // 68 — Daptomicina + estatinas
  ('daptomicina', 'atorvastatina',
    InteractionSeverity.contraindicated,
    'La daptomicina causa miotoxicidad directa por inserción en las membranas de las células musculares; las estatinas causan miotoxicidad por depleción de CoQ10 y alteración de la cadena respiratoria mitocondrial; la toxicidad muscular es aditiva y sinérgica',
    'Rabdomiólisis severa, CPK >10.000 U/L, insuficiencia renal aguda por mioglobinuria, hiperpotasemia potencialmente fatal',
    'Suspender TODA estatina al inicio de daptomicina y medir CPK basalmente. Controlar CPK cada 48 horas durante el tratamiento. Reanudar la estatina solo 7 días después de completar la daptomicina y con CPK documentada en descenso',
    'CONTRAINDICADO — Suspender estatina al iniciar daptomicina: rabdomiólisis',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx, _kRefUT, _kRefFDA]),

  // 69 — Amicacina + furosemida
  ('aminoglicosideo', 'furosemida',
    InteractionSeverity.contraindicated,
    'Los aminoglucósidos son ototóxicos por destrucción de células ciliadas del órgano de Corti (especialmente alta frecuencia); los diuréticos de asa (furosemida, ácido etacrínico) son co-ototóxicos por edema endolinfático y daño estrial vascular; el efecto combinado es explosivo e irreversible',
    'Sordera bilateral permanente irreversible de instauración rápida (horas-días), anacusia, vértigo vestibular severo con trastorno del equilibrio crónico',
    'Evitar la combinación siempre que sea clínicamente posible. Si es imprescindible: usar la dosis mínima efectiva de ambos, monitoreo audiológico cada 48 h, niveles valle de aminoglucósido <1 mcg/mL, hidratación adecuada. En sepsis por Pseudomonas sin alternativa: decisión individualizada con consentimiento informado',
    'CONTRAINDICADO — Sordera irreversible: Aminoglucósido + Furosemida',
    EvidenceLevel.established,
    {RiskType.ototoxicity, RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx, _kRefUT]),

  // 70 — Amicacina + vancomicina
  ('aminoglicosideo', 'vancomicina',
    InteractionSeverity.major,
    'Ambos antibióticos tienen nefrotoxicidad tubular directa; la vancomicina daña las células del túbulo proximal y distal; los aminoglucósidos dañan las células del túbulo proximal por estrés oxidativo; el daño renal es aditivo con sinergia tóxica',
    'Insuficiencia renal aguda oligúrica, necesidad de terapia de reemplazo renal, prolongación del efecto de ambos antibióticos por acumulación',
    'Monitorear creatinina sérica cada 24-48 horas. Medir niveles valle de vancomicina (objetivo 15-20 mcg/mL con AUC/CMI 400-600) y nivel máximo de aminoglucósido. Ajustar intervalos según TFG calculada. Hidratación forzada IV y evitar NSAIDs o contraste simultáneos',
    'NEFROTOXICIDAD ADITIVA — Monitoreo diario creatinina + niveles con amicacina + vancomicina',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx, _kRefUT]),

  // 71 — Bedaquilina + rifampicina
  ('bedaquilina', 'rifampicina',
    InteractionSeverity.contraindicated,
    'Rifampicina induce potentemente CYP3A4, la principal enzima de metabolismo de bedaquilina; la exposición sistémica cae más de un 50% con ciclos estándar de rifampicina',
    'Fracaso terapéutico del esquema contra TBC-MDR, selección de mutantes resistentes a bedaquilina, amplificación de resistencia a XDR-TB',
    'Contraindicado absolutamente según ficha técnica. En TBC-MDR que requiere bedaquilina, usar esquemas sin rifampicina. La rifabutina es una alternativa con menor inducción de CYP3A4 y puede usarse bajo monitoreo estrecho',
    'CONTRAINDICADO — Rifampicina elimina eficacia de bedaquilina en TBC-MDR',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefFDA, _kRefUT]),

  // 72 — Bedaquilina + amiodarona
  ('bedaquilina', 'amiodarona',
    InteractionSeverity.contraindicated,
    'Bedaquilina prolonga el QTc de forma dependiente de dosis (hasta +11 ms con 400 mg); la amiodarona prolonga el QTc de forma marcada (+60-100 ms); la combinación produce una prolongación aditiva que supera el umbral crítico de seguridad',
    'Torsades de Pointes, fibrilación ventricular, muerte súbita cardíaca durante el tratamiento de TBC-MDR',
    'Contraindicado. Si el paciente requiere amiodarona para una arritmia grave, elegir un esquema alternativo sin bedaquilina para la TBC-MDR (por ejemplo, con linezolida, moxifloxacino a dosis controlada, con ECG frecuente)',
    'CONTRAINDICADO — Bedaquilina + Amiodarona: Torsades de Pointes fatal',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefFDA, _kRefMdx]),

  // 73 — Isoniazida + carbamazepina
  ('isoniazida', 'carbamazepina',
    InteractionSeverity.major,
    'La isoniazida inhibe CYP2C9 y CYP3A4 de forma significativa; bloquea el metabolismo de la carbamazepina a su metabolito activo CBZ-E, elevando los niveles del fármaco parental; la carbamazepina, a su vez, puede inducir el metabolismo de la isoniazida',
    'Toxicidad por carbamazepina: ataxia, diplopia, nistagmo, mareos severos, somnolencia extrema, náuseas; en casos graves: hiponatremia y convulsiones por la carbamazepina misma',
    'Medir niveles de carbamazepina antes de iniciar isoniazida y a los 5-7 días. Reducir la dosis de carbamazepina un 25-50% al iniciar el antituberculoso. Medir hepatograma (ambos son hepatotóxicos)',
    'TOXICIDAD CBZ — Isoniazida eleva carbamazepina: ataxia y diplopia',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.cns},
    [_kRefGG, _kRefMdx, _kRefUT]),

  // 74 — Isoniazida + paracetamol
  ('isoniazida', 'paracetamol',
    InteractionSeverity.contraindicated,
    'La isoniazida induce fuertemente CYP2E1, la enzima responsable de generar el metabolito hepatotóxico del paracetamol (N-acetil-p-benzoquinoneimina, NAPQI); con dosis terapéuticas de paracetamol, la cantidad de NAPQI formada puede superar la capacidad de conjugación glutatión hepático',
    'Hepatitis fulminante por paracetamol: elevación masiva de transaminasas >5000 U/L, coagulopatía, encefalopatía hepática y muerte; riesgo particularmente alto en alcohólicos, desnutridos o con reserva hepática reducida',
    'Contraindicado el uso regular de paracetamol >1 g/día en pacientes con isoniazida. Si es imprescindible un analgésico: usar ibuprofeno (sin esta interacción, pero con riesgo GI). Monitorizar transaminasas mensualmente durante el tratamiento con isoniazida',
    'CONTRAINDICADO — Hepatitis fulminante: isoniazida + paracetamol induce metabolito tóxico',
    EvidenceLevel.established,
    {RiskType.hepatotoxicity},
    [_kRefGG, _kRefMdx, _kRefUT, _kRefFDA]),

  // 75 — Praziquantel + rifampicina
  ('praziquantel', 'rifampicina',
    InteractionSeverity.contraindicated,
    'Rifampicina induce CYP3A4 y CYP2C19 de forma extrema; los niveles plasmáticos del praziquantel se reducen hasta un 85%, con un AUC cercano a cero tras una sola dosis de rifampicina',
    'Fracaso terapéutico total del tratamiento antiparasitario: persistencia de teniasis, esquistosomiasis o neurocisticercosis activa con riesgo de progresión',
    'Contraindicado de forma absoluta. Suspender rifampicina mínimo 4 semanas antes del tratamiento con praziquantel. Si el paciente no puede suspender rifampicina, considerar albendazol o ivermectina según el parásito a tratar',
    'CONTRAINDICADO — Rifampicina elimina praziquantel al 85%: fracaso antiparasitario total',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),

  // 76 — Nitroimidazoles + alcohol
  ('metronidazol', 'etanol',
    InteractionSeverity.contraindicated,
    'Los nitroimidazoles (metronidazol, secnidazol, tinidazol, ornidazol) inhiben la aldehído deshidrogenasa (ALDH), bloqueando la oxidación del acetaldehído; el acetaldehído se acumula a niveles tóxicos en sangre y tejidos produciendo una reacción disulfiram-like',
    'Reacción tipo disulfiram severa: náuseas violentas, vómitos repetitivos, enrojecimiento facial (flushing), taquicardia, hipotensión, diaforesis profusa, cefalea pulsátil y disnea; en casos graves: angina, arritmias, colapso hemodinámico',
    'Contraindicado el consumo de alcohol durante el tratamiento y hasta 72 horas después de la última dosis (algunos expertos recomiendan 5 días). Incluir instrucción verbal y escrita en la prescripción. El alcohol en preparaciones farmacéuticas (jarabes, colutorios) también debe evitarse',
    'CONTRAINDICADO — Reacción tipo disulfiram severa: nitroimidazoles + alcohol',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.other},
    [_kRefGG, _kRefMdx, _kRefFDA]),

  // 77 — Nitroimidazoles + warfarina
  ('metronidazol', 'warfarina',
    InteractionSeverity.major,
    'El metronidazol inhibe CYP2C9 (principal vía de metabolismo de la S-warfarina, el isómero 3-5 veces más potente); la inhibición reduce el aclaramiento de la warfarina, elevando el INR de forma rápida y marcada',
    'Hemorragia mayor: sangrado gastrointestinal masivo, hemorragia intracraneal, hematurias macroscópicas; el INR puede duplicarse en 2-3 días',
    'Reducir la dosis de warfarina un 25-50% al iniciar el nitroimidazol. Medir INR antes de iniciar, al día 3, al día 7 y a los 3 días de finalizar el antibiótico. Informar al paciente sobre signos de sangrado',
    'HEMORRAGIA MAYOR — Reducir warfarina 25-50% con nitroimidazoles: INR duplicado',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),

  // ── SECCIÓN 7: Cardiovascular, EPOC, ginecología ─────────────────────────

  // 78 — LABA + propranolol
  ('indacaterol', 'propranolol',
    InteractionSeverity.contraindicated,
    'El propranolol es un betabloqueador no selectivo que antagoniza directamente los receptores beta-2 bronquiales; esta acción contrarresta el efecto broncodilatador de todos los LABA (indacaterol, olodaterol, salmeterol, formoterol, vilanterol)',
    'Broncoespasmo severo con insuficiencia respiratoria aguda, hipoxemia severa, asma fatal o exacerbación grave de EPOC',
    'Contraindicado en cualquier paciente con asma o EPOC que recibe un LABA. Si el paciente requiere un betabloqueador cardiovascular: usar un cardioselectivo (metoprolol, bisoprolol) a la dosis mínima efectiva con monitoreo de la función pulmonar (FEV1)',
    'CONTRAINDICADO — Broncoespasmo fatal: LABA + Propranolol (betabloqueador no selectivo)',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.other},
    [_kRefGG, _kRefMdx, _kRefFDA]),

  // 79 — LABA + furosemida (hipopotasemia)
  ('indacaterol', 'furosemida',
    InteractionSeverity.major,
    'Los agonistas beta-2 (LABA) estimulan la Na+/K+-ATPase, promoviendo la entrada de potasio al interior celular (hipopotasemia extracorporal); los diuréticos de asa causan hipopotasemia por pérdida renal; el efecto combinado puede llevar a hipopotasemia severa de forma rápida',
    'Hipocalemia severa (<3.0 mEq/L): debilidad muscular, calambres, arritmias ventriculares, prolongación del QT, parálisis hipocalémica',
    'Monitorear potasio sérico al inicio y semanalmente. Objetivo K+ >3.5 mEq/L. Considerar suplementación con cloruro de potasio 40-80 mEq/día si el paciente usa dosis altas de LABA + furosemida. ECG de control si K+ <3.5',
    'HIPOCALEMIA GRAVE — Monitorear K+ semanal con LABA + diurético de asa',
    EvidenceLevel.established,
    {RiskType.hypokalemia, RiskType.arrhythmia, RiskType.electrolyte},
    [_kRefGG, _kRefMdx, _kRefUT]),

  // 80 — LAMA + amitriptilina
  ('glicopirronio', 'amitriptilina',
    InteractionSeverity.major,
    'Los LAMA (glicopirronio, umeclidinio, aclidinio) bloquean receptores muscarínicos M1-M3; la amitriptilina tiene potente efecto antimuscarínico central y periférico; la suma de actividades anticolinérgicas produce toxicidad sistémica en pacientes añosos',
    'Retención urinaria aguda (especialmente en hiperplasia prostática), glaucoma de ángulo cerrado, íleo paralítico, taquicardia sinusal, confusión mental, delirium anticolinérgico',
    'Evitar la combinación en pacientes con HBP, glaucoma de ángulo estrecho o demencia. Si es inevitable, monitorear la diuresis, la presión intraocular y el estado cognitivo. Considerar cambiar amitriptilina a un antidepresivo sin carga anticolinérgica (sertralina, mirtazapina)',
    'SÍNDROME ANTICOLINÉRGICO — LAMA + Amitriptilina: retención urinaria y delirium',
    EvidenceLevel.established,
    {RiskType.other, RiskType.cns},
    [_kRefGG, _kRefUT, _kRefMdx]),

  // 81 — Roflumilast + rifampicina
  ('roflumilast', 'rifampicina',
    InteractionSeverity.major,
    'Rifampicina, carbamazepina, fenitoína y fenobarbital inducen CYP3A4 y CYP1A2, las enzimas responsables del metabolismo de roflumilast y su metabolito activo N-óxido; la exposición total cae hasta un 58-79%',
    'Pérdida del efecto antiinflamatorio del roflumilast: incremento en la frecuencia de exacerbaciones de EPOC severa con bronquitis crónica',
    'Contraindicado según ficha técnica del roflumilast (Daxas/Daliresp). Cambiar el anticonvulsivo o antibiótico por opciones sin inducción enzimática. Si la rifampicina es indispensable: suspender roflumilast y adoptar medidas alternativas de control de la inflamación en EPOC',
    'FRACASO TERAPÉUTICO EPOC — Inductores eliminan eficacia de roflumilast',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefFDA, _kRefUT]),

  // 82 — Roflumilast + claritromicina
  ('roflumilast', 'claritromicina',
    InteractionSeverity.major,
    'Claritromicina inhibe CYP3A4 y CYP1A2; el AUC del roflumilast y su metabolito activo aumentan hasta un 100% con inhibidores potentes',
    'Aumento marcado de efectos adversos: diarrea severa, náuseas, pérdida de peso extrema, insomnio, cefaleas, aumento del riesgo de depresión y pensamientos suicidas',
    'Monitorear los efectos secundarios de roflumilast de forma estrecha durante el tratamiento con claritromicina. Considerar suspensión temporal del roflumilast durante el curso de antibiótico',
    'TOXICIDAD AUMENTADA — Claritromicina duplica roflumilast: diarrea y efectos GI',
    EvidenceLevel.established,
    {RiskType.increasedToxicity, RiskType.plasmaLevel},
    [_kRefFDA, _kRefUT]),

  // 83 — Drospirenona + espironolactona
  ('drospirenona', 'espironolactona',
    InteractionSeverity.contraindicated,
    'La drospirenona tiene actividad antimineralocorticoide equivalente a 25 mg de espironolactona; la adición de espironolactona adicional produce bloqueo aldosterónico doble y extremo',
    'Hipercalemia severa potencialmente fatal (K+ >6.5 mEq/L): debilidad muscular progresiva, parálisis ascendente, arritmias ventriculares, paro cardíaco',
    'Contraindicado. Si el paciente requiere tratamiento antiandrogénico junto con AO con drospirenona: elegir AO con otra progestina (levonorgestrel) y espironolactona, o usar drospirenona sola. Monitorizar K+ en toda mujer con drospirenona + cualquier ahorrador de potasio',
    'CONTRAINDICADO — Hipercalemia fatal: Drospirenona + Espironolactona',
    EvidenceLevel.established,
    {RiskType.hyperkalemia, RiskType.arrhythmia},
    [_kRefGG, _kRefFDA]),

  // 84 — Ácido mefenámico + enoxaparina
  ('aine', 'enoxaparina',
    InteractionSeverity.contraindicated,
    'Los AINEs (ácido mefenámico, tolfenámico, ibuprofeno, naproxeno, etc.) inhiben la función plaquetaria (antiagregación por COX-1) y dañan la mucosa gástrica (úlcera/hemorragia); las heparinas bloquean la coagulación; el efecto combinado sobre la hemostasia es multiplicador',
    'Hemorragia gastrointestinal masiva activa con sangrado incoagulable, hematomas musculares extensos, sangrado retroperitoneal grave',
    'Contraindicado. Si el paciente requiere analgesia con HBPM: usar paracetamol (sin efecto antiagregante). En caso de uso urgente de AINE con anticoagulación: gastroprotección obligatoria con omeprazol 40 mg y reducción máxima del tiempo de exposición al AINE',
    'CONTRAINDICADO — Hemorragia masiva: AINEs + Heparina/HBPM',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx, _kRefFDA]),

  // 85 — Ácido mefenámico + metotrexato
  ('aine', 'metotrexato',
    InteractionSeverity.major,
    'Los AINEs y salicilatos compiten por la secreción tubular renal activa del metotrexato por el transportador OAT1/OAT3; la reducción del aclaramiento renal eleva los niveles de metotrexato hasta 3-4 veces',
    'Toxicidad severa por metotrexato: mucositis oral grave, mielodepresión profunda (pancitopenia), hepatotoxicidad, neumonitis intersticial; el riesgo es mayor en pacientes con IRC o deshidratados',
    'Contraindicado con metotrexato en dosis oncológicas. Con metotrexato en dosis bajas para artritis/psoriasis: evitar AINEs o usar paracetamol. Si es inevitable: hidratación IV abundante, reducir dosis de metotrexato y medir niveles a las 48 h',
    'TOXICIDAD METOTREXATO — AINEs bloquean excreción renal: pancitopenia',
    EvidenceLevel.established,
    {RiskType.myelosuppression, RiskType.nephrotoxicity, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),

  // 86 — Dienogest + rifampicina
  ('dienogest', 'rifampicina',
    InteractionSeverity.major,
    'Rifampicina, carbamazepina, fenitoína y fenobarbital inducen fuertemente CYP3A4, reduciendo los niveles séricos del dienogest hasta en un 83%; la progesterona micronizada es igualmente afectada',
    'Fracaso del tratamiento de la endometriosis: reinicio del dolor pélvico crónico, sangrado uterino anormal y progresión de las lesiones endometriósicas',
    'Contraindicado para el uso concomitante según ficha técnica. Si el anticonvulsivo es indispensable, cambiar el tratamiento hormonal a un análogo de GnRH (goserelina, leuprolida) que no es afectado por CYP3A4. Agregar método de barrera adicional si se usa como contracepción',
    'FRACASO TERAPÉUTICO — Inductores reducen dienogest 83%: endometriosis reactiva',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefFDA, _kRefUT]),

  // 87 — Goserelina + escitalopram
  ('goserelina', 'isrs',
    InteractionSeverity.major,
    'Los análogos de GnRH (goserelina, leuprolida) producen hipogonadismo agudo que prolonga el intervalo QTc de forma secundaria a la deprivación androgénica/estrogénica; el escitalopram también prolonga el QTc de manera dosis-dependiente',
    'Prolongación del QTc con riesgo de Torsades de Pointes, especialmente en presencia de hipokalemia o el uso concomitante de otros fármacos que prolongan el QT',
    'Realizar ECG basal antes de iniciar el análogo de GnRH en pacientes con escitalopram. Monitorear QTc cada 3 meses. Si QTc >500 ms: considerar cambio de escitalopram a sertralina (menor efecto sobre QT). Corregir hipopotasemia',
    'PROLONGACIÓN QT — ECG cada 3 meses con análogos GnRH + escitalopram',
    EvidenceLevel.probable,
    {RiskType.qtProlongation},
    [_kRefUT, _kRefMdx]),

  // ── SECCIÓN 8: Nuevos termMap entries y cruces adicionales ───────────────

  // 88 — Ganciclovir + imipenem
  ('ganciclovir', 'imipenem',
    InteractionSeverity.major,
    'Ambos fármacos tienen actividad convulsígena independiente: el imipenem reduce el umbral convulsivo por bloqueo de receptores GABA-A, y el ganciclovir puede producir neurotoxicidad directa; la combinación tiene efecto aditivo o sinérgico sobre el SNC',
    'Convulsiones generalizadas tónico-clónicas, especialmente en pacientes con disfunción renal (mayor acumulación de ambos) o daño neurológico previo',
    'Evitar la combinación siempre que sea posible. Si ambos son indispensables: reducir dosis según TFG, monitoreo neurológico continuo, considerar profilaxis anticonvulsiva con valproato o levetiracetam',
    'CONVULSIONES — Imipenem + Ganciclovir: toxicidad aditiva del SNC',
    EvidenceLevel.established,
    {RiskType.seizure, RiskType.cns},
    [_kRefGG, _kRefMdx]),

  // 89 — Ganciclovir + cotrimoxazol
  ('ganciclovir', 'metronidazol',
    InteractionSeverity.major,
    'El ganciclovir causa mielodepresión significativa (neutropenia, trombocitopenia); el trimetoprim-sulfametoxazol también inhibe la síntesis de folato con toxicidad hematológica; la suma produce aplasia de la médula ósea más profunda',
    'Neutropenia severa (<500/mm³), trombocitopenia grave, anemia aplásica, riesgo de infecciones bacterianas oportunistas fatales',
    'Monitorear hemograma completo 2 veces por semana durante la combinación. Si neutrófilos <500/mm³: suspender uno de los fármacos (preferentemente el cotrimoxazol si hay alternativa). Considerar filgrastim (G-CSF) para recuperar neutrófilos',
    'APLASIA MEDULAR — Monitorear hemograma 2×/semana con ganciclovir + cotrimoxazol',
    EvidenceLevel.established,
    {RiskType.myelosuppression},
    [_kRefGG, _kRefMdx, _kRefUT]),

  // 90 — Caspofungina + rifampicina
  ('caspofungina', 'rifampicina',
    InteractionSeverity.major,
    'Rifampicina induce el aclaramiento hepático de la caspofungina por mecanismos complejos de transporte (no CYP450); el AUC de caspofungina cae hasta un 30% durante el tratamiento concomitante con rifampicina',
    'Niveles subterapéuticos de caspofungina con riesgo de fracaso en el tratamiento de candidemia o aspergilosis invasiva',
    'Según ficha técnica: usar dosis aumentada de caspofungina (70 mg/día en lugar de 50 mg/día en adultos) durante el tratamiento con rifampicina. Monitorear la respuesta clínica y microbiológica de forma estricta',
    'AUMENTAR DOSIS — Caspofungina a 70 mg/día durante el tratamiento con rifampicina',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefFDA, _kRefUT]),

  // 91 — Ozanimod + diltiazem
  ('ozanimodo', 'diltiazem',
    InteractionSeverity.major,
    'Los moduladores de S1P (ozanimod, etrasimod) producen bradicardia significativa al inicio del tratamiento por efecto directo sobre el nódulo SA; el diltiazem tiene efecto cronotrópico e inotrópico negativo aditivo',
    'Bradicardia extrema (<40 lpm), bloqueo AV de 2.°-3.° grado, hipotensión severa, síncope',
    'Mismo protocolo que con betabloqueadores: ECG basal, monitoreo de FC durante las primeras 6 horas de la primera dosis del modulador S1P. Reducir dosis de diltiazem a la mínima efectiva antes de iniciar ozanimod',
    'BRADICARDIA GRAVE — ECG obligatorio en primera dosis de ozanimod con diltiazem',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    [_kRefFDA]),

  // 92 — Espironolactona + ARA-II (candesartana, olmesartana)
  ('espironolactona', 'losartana',
    InteractionSeverity.major,
    'Ambos fármacos retienen potasio: la espironolactona bloquea el receptor mineralocorticoide (aldosterona) y los ARA-II reducen la síntesis de aldosterona; la hiperpotasemia es el resultado de la suma de ambos efectos',
    'Hipercalemia severa (K+ >5.5-6.5 mEq/L): debilidad muscular, parálisis, arritmias ventriculares letales, paro cardíaco; riesgo especialmente alto en pacientes con IRC o diabetes',
    'Monitorizar K+ y creatinina sérica a los 7 y 14 días del inicio de la combinación, luego mensualmente. Objetivo K+ <5.0 mEq/L. Advertir sobre alimentos ricos en potasio (plátano, naranja). Ajustar dosis de espironolactona según K+',
    'HIPERCALEMIA GRAVE — Monitorear K+ semanal con espironolactona + ARA-II',
    EvidenceLevel.established,
    {RiskType.hyperkalemia, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx, _kRefUT]),

  // 93 — Infliximab/biológicos + vacunas vivas
  ('adalimumabe', 'vacuna',
    InteractionSeverity.contraindicated,
    'Los anticuerpos monoclonales anti-TNF (infliximab, adalimumab, golimumab) y otros biológicos (ustekinumab, risankizumab, ozanimod) producen inmunosupresión profunda que impide la respuesta protectora contra los patógenos vacunales vivos atenuados',
    'Infección diseminada potencialmente fatal por el organismo vacunal: tuberculosis miliar por BCG, varicela diseminada, sarampión progresivo, fiebre amarilla generalizada',
    'Contraindicado de forma absoluta durante la terapia biológica. Las vacunas vivas deben administrarse al menos 4 semanas antes de iniciar el biológico. Después de suspender el biológico: esperar 3-6 meses (dependiendo de la vida media) antes de administrar vacunas vivas. Vacunas inactivadas son seguras durante la terapia',
    'CONTRAINDICADO — Vacunas vivas en biológicos: infección diseminada mortal',
    EvidenceLevel.established,
    {RiskType.infection},
    [_kRefGG, _kRefMdx, _kRefUT, _kRefFDA]),

  // 94 — Volanesorsen + warfarina
  ('volanesorsen', 'warfarina',
    InteractionSeverity.major,
    'El volanesorsen (oligonucleótido antisentido) causa trombocitopenia en hasta el 77% de los pacientes; con plaquetas <50.000/mm³, el riesgo de sangrado espontáneo se multiplica de forma exponencial cuando se combina con anticoagulación oral',
    'Hemorragia espontánea severa: sangrado gastrointestinal masivo, hemorragia intracraneal, sangrado retroperitoneal; equimosis extensas con plaquetopenia profunda',
    'Contraindicado con anticoagulantes orales en pacientes con plaquetas <100.000/mm³. Recuento de plaquetas quincenal durante la terapia con volanesorsen. Si plaquetas <50.000: suspender volanesorsen. Si plaquetas <25.000: hospitalización inmediata y suspensión de la anticoagulación',
    'HEMORRAGIA SEVERA — Controlar plaquetas quincenal con volanesorsen + anticoagulantes',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.myelosuppression},
    [_kRefFDA, _kRefUT]),

  // 95 — Evolocumab/alirocumab + estatinas (sinergismo beneficioso documentado)
  ('evolocumab', 'atorvastatina',
    InteractionSeverity.moderate,
    'Las estatinas inhiben HMG-CoA reductasa, reduciendo la síntesis de colesterol intracelular; esto aumenta la expresión de receptores LDL y eleva la expresión de PCSK9; los anticuerpos anti-PCSK9 (evolocumab, alirocumab) bloquean este feedback negativo, potenciando el aclaramiento de LDL',
    'No hay toxicidad; la interacción es farmacodinámica positiva beneficiosa: la adición del iPCSK9 a la estatina reduce el LDL un 60% adicional sobre la estatina sola',
    'No requiere ajuste de dosis. Es la combinación sinérgica esperada y deseada para la reducción máxima de LDL en pacientes de alto riesgo cardiovascular. El tratamiento de base con estatina potencia la eficacia del iPCSK9',
    'SINERGISMO BENEFICIOSO — Estatina + iPCSK9: reducción LDL óptima en alto riesgo CV',
    EvidenceLevel.established,
    {RiskType.other},
    [_kRefGG, _kRefUT, _kRefFDA]),

  // 96 — Roxadustat + estatinas (OATP1B1)
  ('roxadustat', 'atorvastatina',
    InteractionSeverity.major,
    'El roxadustat (y otros inhibidores de HIF-PH) inhiben el transportador OATP1B1/BCRP, aumentando la biodisponibilidad sistémica de las estatinas que son sustratos de este transportador (rosuvastatina especialmente, atorvastatina)',
    'Miopatía y elevación de CPK; riesgo de rabdomiólisis en pacientes con IRC grave o que usan dosis altas de estatinas',
    'Monitorear CPK antes de iniciar el inhibidor de HIF-PH y a los 30 días. Reducir la dosis de rosuvastatina a la mitad en combinación con roxadustat. Usar dosis menores de atorvastatina (10-20 mg máx)',
    'MIOPATÍA — Roxadustat eleva estatinas vía OATP1B1: monitorear CPK',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefFDA, _kRefUT]),

  // 97 — Hierro IV + hierro oral
  ('hierro sacarato', 'ferritina',
    InteractionSeverity.major,
    'El hierro endovenoso satura los depósitos y eleva los niveles de hepcidina hepática de forma aguda; la hepcidina bloquea el transportador ferroportina intestinal, inhibiendo completamente la absorción intestinal del hierro oral hasta por 24-48 horas',
    'Reducción marcada de la absorción del hierro oral suplementario, resultando en tratamiento ineficaz de la anemia ferropénica si se dan simultáneamente',
    'No administrar hierro oral dentro de las 24-48 horas del hierro IV. Instruir al paciente que si recibe hierro IV en infusión, suspenda el hierro oral ese día y el siguiente. La suplementación oral puede reanudarse a las 48 horas de la infusión IV',
    'INEFICACIA — No dar hierro oral en las 48h del hierro IV: hepcidina bloquea absorción',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefUT]),

  // 98 — Mizolastina + claritromicina
  ('mizolastina', 'claritromicina',
    InteractionSeverity.contraindicated,
    'Claritromicina inhibe CYP3A4, la única vía de metabolismo de la mizolastina; los niveles plasmáticos de la mizolastina aumentan de forma sustancial con riesgo de toxicidad cardíaca',
    'Prolongación del intervalo QTc, Torsades de Pointes, arritmias ventriculares graves y muerte súbita cardíaca',
    'Contraindicado según ficha técnica de Mizollen (mizolastina). Sustituir por un antihistamínico sin efecto QT: cetirizina, loratadina o fexofenadina (metabolismo hepático diferente)',
    'CONTRAINDICADO — Mizolastina + Claritromicina: Torsades de Pointes',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefFDA, _kRefMdx]),

  // 99 — Ciclesonida/mometasona + itraconazol
  ('mometasona', 'fluconazol',
    InteractionSeverity.major,
    'Los antifúngicos azólicos potentes (itraconazol, ketoconazol) inhiben intensamente CYP3A4; aunque los corticoides inhalados tienen baja biodisponibilidad sistémica normalmente, su metabolismo CYP3A4 se bloquea con azólicos potentes, aumentando la absorción sistémica significativamente',
    'Síndrome de Cushing iatrogénico: cara de luna llena, distribución central de grasa, estrías violáceas, hipertensión, hiperglucemia; supresión del eje HHA con riesgo de insuficiencia adrenal al suspender el corticoide',
    'Evitar la combinación con itraconazol/ketoconazol sistémicos. Con fluconazol a dosis estándar: monitorear signos de Cushing. Considerar beclometasona dipropionato (metabolismo pulmonar diferente, menor interacción) como alternativa de corticoide inhalado',
    'SÍNDROME DE CUSHING — Azoles sistémicos elevan corticoides inhalados: supresión adrenal',
    EvidenceLevel.established,
    {RiskType.other, RiskType.increasedToxicity},
    [_kRefGG, _kRefUT, _kRefMdx]),

  // 100 — Rosuvastatina + roxadustat (BCRP)
  ('rosuvastatina', 'roxadustat',
    InteractionSeverity.major,
    'Roxadustat inhibe los transportadores OATP1B1 y BCRP; la rosuvastatina es el sustrato más sensible de ambos transportadores; el AUC de la rosuvastatina puede aumentar hasta un 130% con roxadustat',
    'Miopatía grave, elevación marcada de CPK, riesgo de rabdomiólisis especialmente en pacientes con IRC (que ya tienen mayor riesgo de miopatía)',
    'Reducir la dosis de rosuvastatina al 50% (máx 10 mg/día) en pacientes que inician roxadustat. Medir CPK basalmente y a los 30 días. Si CPK >5× LSN: suspender la rosuvastatina. Monitoreo clínico de dolor muscular y debilidad',
    'MIOPATÍA — Reducir rosuvastatina 50% con roxadustat (inhibición OATP1B1/BCRP)',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefFDA]),

  // ── Termmap IDs adicionais para detecção ─────────────────────────────────

  // 101 — Dapagliflozina + espironolactona
  ('dapagliflozina', 'espironolactona',
    InteractionSeverity.major,
    'Os iSGLT2 causam diurese osmótica e natriurese; a espironolactona causa retenção de potássio e perda de sódio; a depleção de sódio cumulativa pode precipitar hipovolemia severa, especialmente em idosos',
    'Hipotensão ortostática, insuficiencia renal aguda por hipoperfusão, hiperpotasemia se houver IRC subjacente',
    'Monitorar PA postural, creatinina e K+ nas semanas 1, 2 e 4. Instruir o paciente a hidratar-se adecuadamente',
    'HIPOVOLEMIA — Monitorar PA e K+ ao combinar iSGLT2 + espironolactona',
    EvidenceLevel.probable,
    {RiskType.cardiovascular, RiskType.hyperkalemia, RiskType.nephrotoxicity},
    [_kRefUT, _kRefGG]),

  // 102 — Metformina + ciprofloxacino
  ('metformina', 'ciprofloxacino',
    InteractionSeverity.major,
    'As quinolonas podem causar tanto hipoglucemia (estimulação de secreção insulínica) quanto hiperglucemia (inibição da secreção); em diabéticos com metformina o efeito líquido é imprevisível',
    'Hipoglucemia ou hiperglucemia inesperada e potencialmente grave, especialmente em idosos',
    'Monitorar glucemia diariamente durante o tratamento com quinolonas. Orientar o paciente sobre sintomas de hipoglucemia',
    'GLICEMIA INSTÁVEL — Monitorar glucemia com quinolonas + antidiabéticos',
    EvidenceLevel.established,
    {RiskType.hypoglycemia, RiskType.other},
    [_kRefGG, _kRefMdx]),

  // 103 — Rifampicina + warfarina
  ('rifampicina', 'warfarina',
    InteractionSeverity.major,
    'Rifampicina é o indutor mais potente do CYP2C9 (metabolismo da S-varfarina); o AUC da varfarina pode cair até 90% em 1 semana de rifampicina',
    'Trombose ou embolia por nível subterapéutico de anticoagulação; ao suspender rifampicina, risco de hemorragia por acumulação rápida de varfarina',
    'Aumentar dose de varfarina em até 5-10 vezes ao iniciar rifampicina, com controle diário de INR. Ao suspender rifampicina: reduzir warfarina imediatamente e monitorar INR a cada 2-3 dias por 2 semanas',
    'FALHA ANTICOAGULAÇÃO — Rifampicina reduz varfarina 90%: INR diário obligatorio',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.thrombosis, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),

  // 104 — Valproato + carbamazepina
  ('valproato', 'carbamazepina',
    InteractionSeverity.major,
    'Interação bidirecional complexa: o valproato inibe o metabolismo do metabólito ativo da carbamazepina (CBZ-10,11-epóxido) e a carbamazepina induz o metabolismo do valproato; resultados clínicos imprevisíveis',
    'Toxicidade por CBZ-epóxido (ataxia, diplopia, sonolência) com níveis normais de carbamazepina; falha terapéutica do valproato por redução dos níveis',
    'Monitorar níveis de ambos e do epóxido da carbamazepina. Ajustar doses segundo resposta clínica e EEG. Preferir levetiracetam como terceiro antiepiléptico para evitar interações complexas',
    'TOXICIDADE CBZ + FALHA VPA — Monitorar níveis de ambos na combinação',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),

  // 105 — Lítio + diuréticos tiazídicos
  ('carbonato de litio', 'espironolactona',
    InteractionSeverity.major,
    'Os diuréticos tiazídicos e análogos (hidroclorotiazida, indapamida) reduzem a excreção renal de lítio por depleção de sódio que aumenta a reabsorção tubular de lítio; os níveis séricos de lítio aumentam 25-40%',
    'Toxicidade por lítio: tremor grosseiro, ataxia, confusão, convulsiones, insuficiencia renal, coma; janela terapéutica estreita (0.6-1.2 mEq/L)',
    'Monitorar lítio sérico 5-7 dias após início do diurético e após qualquer mudança de dose. Reduzir dose de lítio empiricamente 25% ao iniciar tiazídico. Manter hidratação adecuada e evitar dieta hiposódica',
    'TOXICIDADE LÍTIO — Tiazídicos elevam lítio 25-40%: dosagem sérica obrigatória',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.cns, RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx, _kRefUT]),

  // 106 — Alopurinol + azatioprina
  ('alopurinol', 'azatioprina',
    InteractionSeverity.contraindicated,
    'O alopurinol inibe a xantina oxidase, principal enzima de inativação da 6-mercaptopurina (metabólito ativo da azatioprina); os níveis da 6-MP aumentam 4-5 vezes com toxicidad hematológica severa',
    'Mielossupressão grave: neutropenia profunda (<200/mm³), aplasia medular, pancitopenia fatal, infecções oportunistas',
    'Contraindicado. Se o paciente necessita de alopurinol com azatioprina: reduzir azatioprina para 25% da dose e monitorar hemograma semanal. Alternativa: febuxostat para hiperuricemia (menor interação, mas ainda requer precaução)',
    'CONTRAINDICADO — Alopurinol eleva azatioprina 4-5×: aplasia medular',
    EvidenceLevel.established,
    {RiskType.myelosuppression},
    [_kRefGG, _kRefMdx, _kRefUT, _kRefFDA]),

  // 107 — Colchicina + claritromicina
  ('colchicina', 'claritromicina',
    InteractionSeverity.contraindicated,
    'A claritromicina inibe CYP3A4 e P-gp, ambas vias de eliminação da colchicina; os niveles plasmáticos aumentam 3-4 vezes com risco de toxicidad grave em doses normais',
    'Toxicidade por colchicina: diarreia severa, náuseas, dor abdominal, miopatia, neuropatia periférica, mielosupresión, insuficiência orgânica múltipla e morte',
    'Contraindicado em pacientes com IRC (colchicina já acumulada). Em pacientes com función renal normal: reduzir colchicina a dose mínima única (0.6 mg uma vez) e evitar doses repetidas durante o antibiótico. Informar sobre sintomas de toxicidad',
    'CONTRAINDICADO — Colchicina + Claritromicina: toxicidad múltipla de órgãos',
    EvidenceLevel.established,
    {RiskType.myelosuppression, RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx, _kRefUT]),

  // 108 — Ciclosporina + fluconazol
  ('ciclosporina', 'fluconazol',
    InteractionSeverity.major,
    'O fluconazol inibe CYP3A4, principal via de metabolismo da ciclosporina; os níveis de ciclosporina aumentam 50-200% dependendo da dose de fluconazol',
    'Nefrotoxicidad por ciclosporina: elevação de creatinina, hipertensão arterial, hiperpotasemia; rejeição aguda se os níveis forem insuficientes ao suspender o azol',
    'Reduzir dose de ciclosporina em 50% ao iniciar fluconazol e monitorar nível de ciclosporina diariamente. Objetivo: manter a mesma concentração mínima (trough) alvo. Ao suspender fluconazol: aumentar ciclosporina gradualmente com monitoração',
    'NEFROTOXICIDADE — Fluconazol eleva ciclosporina 50-200%: monitorar nível diário',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),

  // 109 — Sildenafila + nitratos
  ('sildenafila', 'nitrato',
    InteractionSeverity.contraindicated,
    'Ambos vasodilatam via óxido nítrico/GMPc: os nitratos aumentam o GMPc e a sildenafila inibe a PDE-5 que o degrada; o efeito vasodilatador é exponencialmente potenciado',
    'Hipotensão severa refratária: colapso hemodinâmico, síncope, isquemia miocárdica por hipoperfusão coronária, AVC isquêmico',
    'Contraindicação absoluta. Intervalo mínimo: 24 h após sildenafila/vardenafila; 48 h após tadalafila (vida media longa) antes de qualquer nitrato. Em emergência com síndrome coronária aguda: evitar nitratos; usar morfina + beta-bloqueador',
    'CONTRAINDICADO — Hipotensão fatal: Sildenafila + Nitratos',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    [_kRefFDA, _kRefGG, _kRefMdx]),

  // 110 — Sacubitrila + IECA
  ('sacubitrila', 'enalapril',
    InteractionSeverity.contraindicated,
    'Sacubitrila inibe a neprilisina, reduzindo a degradação dos peptídeos natriuréticos e da bradicinina; os IECAs também aumentam a bradicinina por inibir a ECA; a combinação leva a acúmulo de bradicinina com risco de angioedema grave',
    'Angioedema de língua, laringe e faringe com risco de asfixia; o risco é maior nas primeiras semanas de uso',
    'Contraindicado. Intervalo obligatorio de 36 horas entre a última dose do IECA e a primeira dose do sacubitril/valsartana (Entresto). Monitorar sinais de angioedema nas primeiras 4 semanas de uso',
    'CONTRAINDICADO — Angioedema fatal: iniciar Entresto somente 36h após o último IECA',
    EvidenceLevel.established,
    {RiskType.other, RiskType.respiratoryDepression},
    [_kRefFDA, _kRefGG, _kRefUT]),


  // ═══════════════════════════════════════════════════════════════
  // BLOCK 4 RECUPERADO — LABA/LAMA, Roflumilast, Biológicos+Vacinas,
  // Hemostáticos, Ginecologia avançada, Miscelânea (111–130)
  // ═══════════════════════════════════════════════════════════════

  // 111 — Indacaterol (LABA) + Propranolol
  ('indacaterol', 'propranolol',
    InteractionSeverity.contraindicated,
    'Propranolol (beta-bloqueador não seletivo) antagoniza competitivamente os receptores beta-2 nos brônquios, bloqueando o efeito broncodilatador do indacaterol e podendo precipitar broncoespasmo grave em pacientes com asma/DPOC',
    'Broncoespasmo paradoxal, falha terapéutica do broncodilatador, crise asmática refratária com risco de insuficiência respiratória',
    'Contraindicado em asma. Em DPOC com indicação absoluta de beta-bloqueador (pós-IAM), usar cardioselective (bisoprolol, metoprolol) com monitoramento rigoroso da função pulmonar',
    'CONTRAINDICADO em asma — Beta-bloqueador não seletivo anula efeito do LABA',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression},
    [_kRefGG, _kRefUT]),

  // 112 — Indacaterol (LABA) + Furosemida
  ('indacaterol', 'furosemida',
    InteractionSeverity.moderate,
    'LABAs estimulam a bomba Na-K-ATPase via AMPc, promovendo entrada de potássio nas células (hipopotasemia intracelu­lar); furosemida causa perdas renais de potássio; a combinação pode precipitar hipopotasemia acentuada e prolongamento do QT',
    'Hipocalemia sintomática (fraqueza, cãibras), arritmias cardíacas incluindo torsades de pointes, potencialização da toxicidad digitálica',
    'Monitorar potássio sérico regularmente. Suplementação de potássio se K+ < 3,5 mEq/L. Considerar potássio sérico basal antes de iniciar LABA em pacientes em uso de diuréticos de alça',
    'Monitorar potássio — LABA + furosemida: risco de hipopotasemia e QT longo',
    EvidenceLevel.probable,
    {RiskType.hypokalemia, RiskType.qtProlongation},
    [_kRefGG, _kRefMdx]),

  // 113 — Tiotrópio (LAMA) + Amitriptilina
  ('tiotropio', 'amitriptilina',
    InteractionSeverity.moderate,
    'Efeito anticolinérgico aditivo: tiotrópio bloqueia receptores muscarínicos M1-M3 nas vias aéreas; amitriptilina tem potente atividade anticolinérgica sistêmica; a combinação soma efeitos antimuscarínicos periféricos e centrais',
    'Retenção urinária, constipação intestinal grave, taquicardia, boca seca intensa, visão turva, confusão mental (especialmente em idosos), glaucoma de ângulo fechado',
    'Usar com cautela. Preferir antidepressivos com menor perfil anticolinérgico (ISRS, venlafaxina, mirtazapina). Monitorar sintomas anticolinérgicos. Evitar em homens com HPB e em idosos frágeis',
    'Efeito anticolinérgico aditivo — LAMA + Amitriptilina: risco em idosos',
    EvidenceLevel.probable,
    {RiskType.other, RiskType.cns},
    [_kRefGG, _kRefKatz]),

  // 114 — Roflumilast + Teofilina
  ('roflumilast', 'teofilina',
    InteractionSeverity.moderate,
    'Roflumilast inibe a PDE-4, aumentando AMPc nas células inflamatórias e musculares lisas; a teofilina inibe múltiplos isotipos de PDE (1, 3, 4, 5); a inibição aditiva da PDE-4 pode potenciar efeitos adversos gastrointestinais e neurológicos',
    'Náuseas, vômitos, cefaleia, insônia, taquicardia, irritabilidade, possíveis convulsiones em doses elevadas de teofilina',
    'Monitorar nivel sérico de teofilina (alvo 5–15 mcg/mL). Iniciar roflumilast na dose de 250 mcg/dia por 4 semanas antes de titular para 500 mcg/dia. Avaliar tolerabilidade gastrointestinal',
    'Inibição PDE aditiva — Roflumilast + Teofilina: monitorar tolerabilidade',
    EvidenceLevel.probable,
    {RiskType.increasedToxicity, RiskType.cns},
    [_kRefGG, _kRefUT]),

  // 115 — Roflumilast + Enoxaparina
  ('roflumilast', 'enoxaparina',
    InteractionSeverity.minor,
    'Roflumilast pode reduzir a função plaquetária via aumento de AMPc (efeito anti-agregante), somando-se ao efeito anticoagulante da enoxaparina; o risco hemorrágico adicional é baixo mas presente',
    'Leve aumento do risco de sangrado, especialmente em sítios de injeção de enoxaparina ou procedimentos invasivos',
    'Monitoramento padrão do anti-Xa se clinicamente indicado. Sem ajuste de dose rotineiro necesario. Alertar sobre sinais de sangrado incomum',
    'Risco hemorrágico leve — Roflumilast + Enoxaparina: monitorar sangrado',
    EvidenceLevel.theoretical,
    {RiskType.hemorrhagic},
    [_kRefGG]),

  // 116 — Adalimumabe (biológico anti-TNF) + Vacinas vivas atenuadas
  ('adalimumabe', 'vacina_viva',
    InteractionSeverity.contraindicated,
    'Adalimumabe suprime profundamente a resposta imune mediada por TNF-alfa e linfócitos T; vacinas vivas contêm patógenos atenuados que se replicam para gerar imunidade; em imunossupressão, esses patógenos podem causar doença disseminada',
    'Doença disseminada pela cepa vacinal: BCGite sistêmica, varicela disseminada, poliomielite vacinal, sarampo grave; risco de óbito',
    'Contraindicado usar vacinas vivas durante terapia com adalimumabe ou dentro de 3 meses após a suspensão. Vacinas inativadas (gripe inativada, pneumocócica, meningocócica) são permitidas e recomendadas. Vacinar ANTES de iniciar o biológico',
    'CONTRAINDICADO — Biológico anti-TNF + vacinas vivas: risco de doença vacinal grave',
    EvidenceLevel.established,
    {RiskType.infection},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 117 — Ustekinumabe (anti-IL12/23) + Vacinas vivas atenuadas
  ('ustekinumabe', 'vacina_viva',
    InteractionSeverity.contraindicated,
    'Ustekinumabe bloqueia a subunidade p40 compartilhada de IL-12 e IL-23, comprometendo a imunidade mediada por células Th1 e Th17; essencial para o controle de infecções intracelulares e pelo vacinal atenuado',
    'Infecção disseminada pela cepa vacinal com risco de insuficiência orgânica e óbito; BCGite disseminada em caso de BCG inadvertido',
    'Contraindicado. Completar calendário vacinal com vacinas vivas pelo menos 4 semanas antes do início do ustekinumabe. Aguardar 15 semanas após última dose antes de aplicar vacinas vivas',
    'CONTRAINDICADO — Ustekinumabe + vacinas vivas: imunossupressão grave',
    EvidenceLevel.established,
    {RiskType.infection},
    [_kRefFDA, _kRefGG]),

  // 118 — Drospirenona + Espironolactona
  ('drospirenona', 'espironolactona',
    InteractionSeverity.major,
    'Drospirenona tem atividade antiandrogênica e antimineralocorticoide análoga à espironolactona (derivada da 17-espironolactona); ambas bloqueiam receptores mineralocorticoides, causando retenção de potássio e natriurese; efeito hipercalêmico aditivo',
    'Hipercalemia grave (K+ > 6 mEq/L): bradicardia, fraqueza muscular, paro cardíaco; hipotensão por natriurese excessiva',
    'Contraindicar combinação de rotina. Se necesario por indicação específica, monitorar K+ sérico dentro de 1 semana e depois mensalmente. Risco especialmente elevado em diabéticas, renais crônicas e usuárias de IECAs/ARA-II',
    'Hipercalemia grave — Drospirenona + Espironolactona: efeito antimineralocorticoide aditivo',
    EvidenceLevel.probable,
    {RiskType.hyperkalemia, RiskType.cardiovascular},
    [_kRefGG, _kRefUT]),

  // 119 — Dienogest + AIES/Corticoides (indutores enzimáticos)
  ('dienogest', 'rifampicina',
    InteractionSeverity.major,
    'Rifampicina é potente indutor do CYP3A4, principal enzima responsável pelo metabolismo do dienogest; a inducción enzimática reduz drásticamente os niveles plasmáticos do progestogênio, comprometendo a eficácia anticoncepcional e terapéutica na endometriose',
    'Falha contraceptiva com gravidez não planejada; recorrência de dor pélvica e lesões de endometriose por concentrações subterapéuticas de dienogest',
    'Usar método contraceptivo não hormonal (preservativo, DIU de cobre) durante o tratamento com rifampicina e por 28 dias após a suspensão. Para endometriose, discutir opção terapéutica alternativa',
    'FALHA CONTRACEPTIVA — Dienogest + Rifampicina: indução CYP3A4 elimina eficácia',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefUT]),

  // 120 — Dienogest + Fluconazol (inibidor CYP3A4)
  ('dienogest', 'fluconazol',
    InteractionSeverity.moderate,
    'Fluconazol inibe moderadamente o CYP3A4 e CYP2C19, reduzindo o metabolismo do dienogest; os niveles plasmáticos de dienogest podem aumentar 1,5–2x, potencializando efeitos androgênicos/estrogênicos e adversos',
    'Spotting, mastalgia, cefaleia, mudanças de humor; raramente trombosis venosa em pacientes com fatores de risco',
    'Monitorar efeitos colaterais durante tratamento antifúngico prolongado (> 7 dias). Interação clinicamente relevante principalmente em ciclos longos de fluconazol',
    'Níveis aumentados de dienogest — Fluconazol inibe metabolismo CYP3A4',
    EvidenceLevel.theoretical,
    {RiskType.increasedToxicity},
    [_kRefGG]),

  // 121 — Goserelina + Antidiabéticos (hipoglucemiantes)
  ('goserelina', 'insulina',
    InteractionSeverity.moderate,
    'Análogos de GnRH como goserelina causam supressão androgênica (privação hormonal) que induz resistência à insulina, intolerância à glicose e síndrome metabólica; pacientes em terapia de privação androgênica têm risco aumentado de diabetes e de controle glicêmico difícil',
    'Hiperglucemia, piora do controle do diabetes mellitus preexistente, necessidade de ajuste de doses de antidiabéticos, risco de cetoacidose diabética em diabetes tipo 1',
    'Monitorar glucemia em jejum e HbA1c a cada 3 meses durante terapia com goserelina. Ajustar doses de antidiabéticos conforme necesario. Orientar sobre dieta e exercício para minimizar impacto metabólico',
    'Resistência à insulina — Análogos GnRH (goserelina) aumentam risco de hiperglucemia',
    EvidenceLevel.established,
    {RiskType.hypoglycemia, RiskType.cardiovascular},
    [_kRefGG, _kRefMdx]),

  // 122 — Ganciclovir + Micofenolato de Mofetila
  ('ganciclovir', 'micofenolato',
    InteractionSeverity.major,
    'Ambos competem pelo mesmo transportador renal tubular (proteína de transporte de nucleosídeos); micofenolato inibe a inosina monofosfato desidrogenase (IMPDH) reduzindo proliferação de linfócitos; ganciclovir pode reduzir o clearance renal de micofenolato aumentando sua toxicidad; mielosupresión aditiva profunda',
    'Leucopenia grave, neutropenia, anemia, trombocitopenia; risco aumentado de infecções oportunistas e episódios hemorrágicos; potencial toxicidad renal aditiva',
    'Monitorar hemograma completo semanalmente nas primeiras 8 semanas, depois mensalmente. Ajustar dose de micofenolato se leucopenia grave (< 1.000/mm³). Considerar profilaxia antifúngica e antibacteriana',
    'Mielossupressão aditiva grave — Ganciclovir + Micofenolato: monitorar hemograma',
    EvidenceLevel.probable,
    {RiskType.myelosuppression, RiskType.infection},
    [_kRefGG, _kRefUT]),

  // 123 — Caspofungina + Tacrolimus
  ('caspofungina', 'tacrolimus',
    InteractionSeverity.moderate,
    'Caspofungina induz o CYP3A4 e pode reduzir os níveis de tacrolimus em 20–25%; tacrolimus tem janela terapéutica muito estreita e variabilidade inter e intraindividual alta; a queda de níveis pode precipitar rejeição de órgão transplantado',
    'Rejeição aguda de órgão transplantado (rim, fígado, coração) por concentrações subterapéuticas de tacrolimus; risco de pérdida del injerto',
    'Monitorar tacrolimus por cromatografia (objetivo terapéutico baseado no órgão transplantado e fase pós-transplante). Ajustar dose de tacrolimus durante e após caspofungina. Aumentar frequência de monitoramento de C0 para diária nas primeiras 2 semanas',
    'Redução de tacrolimus — Caspofungina induz CYP3A4: risco de rejeição',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel, RiskType.reducedEfficacy},
    [_kRefGG, _kRefUT, _kRefMdx]),

  // 124 — Caspofungina + Rifampicina
  ('caspofungina', 'rifampicina',
    InteractionSeverity.major,
    'Rifampicina é potente indutor de transportadores hepáticos (OATP1B1/B3) e pode reduzir a exposição sistêmica à caspofungina em até 35% pelo aumento de sua eliminação e distribuição; mecanismo não totalmente elucidado (caspofungina não é metabolizada pelo CYP450)',
    'Falha terapéutica da caspofungina com progressão de infecção fúngica invasiva (candidemia, aspergilose); mortalidade aumentada em pacientes imunocomprometidos',
    'Quando combinação for necessária, aumentar dose de caspofungina para 70 mg/dia (em vez de 50 mg/dia de manutenção). Monitorar resposta clínica, microbiológica e marcadores de infecção (galactomanana, beta-D-glucana)',
    'Redução de caspofungina — Rifampicina: aumentar dose para 70 mg/dia',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefFDA, _kRefUT]),

  // 125 — Ozanimod + Diltiazem
  ('ozanimod', 'diltiazem',
    InteractionSeverity.major,
    'Ozanimod causa bradicardia e bloqueio AV pela modulação dos receptores S1P1/5 no nódulo AV, reduzindo a frequência cardíaca em média 8–12 bpm; diltiazem é bloqueador dos canais de cálcio com efeito cronotrópico negativo; efeito sinérgico no nódulo sinoatrial e AV',
    'Bradicardia grave (FC < 40 bpm), bloqueio AV de 2º e 3º grau, síncope, pausa sinusal, hipotensão; risco de parada cardiorrespiratória',
    'Contraindicação relativa. Se indispensável, realizar ECG antes de iniciar ozanimod e no dia 1, 2 e 4 de uso. Monitorar durante 6 horas após a primeira dose. Considerar betabloqueador seletivo alternativo ao diltiazem se necesario antiarrítmico',
    'Bradicardia grave — Ozanimod + Diltiazem: efeito cronotrópico negativo aditivo',
    EvidenceLevel.probable,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    [_kRefFDA, _kRefGG]),

  // 126 — Espironolactona + Candesartana (ARA-II)
  ('espironolactona', 'candesartana',
    InteractionSeverity.major,
    'Espironolactona bloqueia os receptores de aldosterona, promovendo retenção de potássio; candesartana (ARA-II) reduz a produção de aldosterona e aumenta o potássio sérico via bloqueio dos receptores AT1 da angiotensina II; hiperpotasemia sinérgica',
    'Hipercalemia grave (K+ > 6 mEq/L): arritmias letais (fibrilação ventricular, asistolia), fraqueza muscular progressiva, parestesias, paro cardíaco',
    'Monitorar K+ e creatinina dentro de 1–2 semanas após início da combinação e depois mensalmente. Alvo K+ < 5,0 mEq/L. Risco especialmente alto em pacientes com IRC, diabetes e idosos. Esta combinação é frecuentemente necessária em ICC com disfunción renal — titular cautelosamente',
    'Hipercalemia grave — Espironolactona + ARA-II: monitorar K+ semanalmente',
    EvidenceLevel.established,
    {RiskType.hyperkalemia, RiskType.cardiovascular},
    [_kRefGG, _kRefKatz, _kRefMdx]),

  // 127 — Evolocumabe (iPCSK9) + Sinvastatina
  ('evolocumabe', 'sinvastatina',
    InteractionSeverity.minor,
    'Evolocumabe não possui interações farmacocinéticas significativas com sinvastatina (via subcutânea, sem metabolismo CYP hepático relevante); a combinação é intencional e recomendada nas diretrizes para pacientes de alto risco cardiovascular que não atingem LDL-alvo com estatina máxima tolerada',
    'Potencial aditivo de redução de LDL (60–70% adicional com evolocumabe sobre estatina); reações no local de injeção; raramente mialgias',
    'Combinação segura e recomendada. Medir LDL 4–8 semanas após início do evolocumabe para confirmar resposta. Continuar estatina na dose máxima tolerada',
    'Combinação segura e recomendada — Evolocumabe + Estatina: LDL-alvo mais alcançável',
    EvidenceLevel.established,
    {RiskType.other},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 128 — Volanesorsen + Anticoagulantes
  ('volanesorsen', 'varfarina',
    InteractionSeverity.moderate,
    'Volanesorsen (oligonucleotídeo antisense anti-APO-C3) pode causar trombocitopenia grave como efeito adverso de classe dos oligonucleotídeos antisense; em pacientes anticoagulados com varfarina, a plaquetopenia aumenta sinergicamente o risco hemorrágico',
    'Sangramento grave por trombocitopenia (< 50.000/mm³) associada a anticoagulação: hemorragia intracraniana, sangrado gastrointestinal maciço, hemoperitônio',
    'Contraindicado se plaquetas < 140.000/mm³ antes de iniciar volanesorsen. Monitorar contagem plaquetária a cada 2 semanas durante os primeiros 3 meses. Suspender volanesorsen se plaquetas < 75.000/mm³. Ajustar dose de varfarina e monitorar INR mais frecuentemente',
    'Trombocitopenia + anticoagulação — Volanesorsen: risco hemorrágico grave',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.myelosuppression},
    [_kRefFDA, _kRefGG]),

  // 129 — Roxadustate (inibidor HIF-PH) + Varfarina
  ('roxadustate', 'varfarina',
    InteractionSeverity.major,
    'Roxadustate inibe o CYP2C9 e a enzima HIF prolil-hidroxilase; como a varfarina é metabolizada principalmente pelo CYP2C9 (S-varfarina, mais potente), a inibição aumenta significativamente os níveis de S-varfarina e o efeito anticoagulante; INR pode aumentar 30–40%',
    'Sangramento grave por supracoagulação: hemorragia intracraniana, digestiva maciça, retroperitoneal; INR suprateapêutico (> 4)',
    'Monitorar INR com maior frequência ao iniciar ou suspender roxadustate (a cada 3 dias na primeira semana, depois semanalmente por 4 semanas). Ajustar dose de varfarina com base no INR. Considerar anticoagulante não warfarínico (DOAC) em pacientes renais crônicos com TFG adecuado',
    'INR aumentado 30–40% — Roxadustate inibe CYP2C9: ajustar varfarina urgente',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 130 — Ferro Sacarato IV + Cefalosporinas (quelação)
  ('ferro_sacarato', 'ceftriaxona',
    InteractionSeverity.minor,
    'O ferro intravenoso não apresenta interação farmacocinética clinicamente significativa com cefalosporinas; no entanto, ferro dextrano pode formar complexos com algumas drogas se infundido simultaneamente no mesmo acesso venoso',
    'Formação de precipitado ou complexo insolúvel se misturado no mesmo equipo IV; potencial redução da atividade antibiótica',
    'Não infundir ferro IV simultaneamente no mesmo acesso que antibióticos. Usar via IV separada ou flush com SF 0,9% entre infusões. Ferro sacarato e gluconato de ferro têm menor risco que dextrano',
    'Não misturar na mesma via — Ferro IV + Antibióticos: usar vias separadas',
    EvidenceLevel.theoretical,
    {RiskType.other},
    [_kRefGG]),


  // ═══════════════════════════════════════════════════════════════
  // BLOCK 6 — Procinéticos, Antieméticos, Antifúngicos avançados,
  // Antituberculosos avançados, Miscelânea (131–160)
  // ═══════════════════════════════════════════════════════════════

  // 131 — Metoclopramida + ISRS (Serotonina)
  ('metoclopramida', 'fluoxetina',
    InteractionSeverity.major,
    'Metoclopramida antagoniza receptores D2 e tem efeito agonista serotoninérgico (5-HT4); ISRS inibem a recaptação de serotonina; a combinação pode precipitar síndrome serotoninérgica, especialmente em doses elevadas ou uso prolongado; metoclopramida também inibe o CYP2D6 que metaboliza fluoxetina',
    'Síndrome serotoninérgica: tremor, agitação, confusão, hiperreflexia, mioclonias, sudorese, taquicardia, hipertermia; casos graves com rabdomiólisis e insuficiência de múltiplos órgãos',
    'Evitar uso concomitante prolongado. Se necesario para náuseas agudas, limitar a doses únicas e curtos períodos. Preferir ondansetrona (antagonista 5-HT3) para náuseas em pacientes em ISRS. Monitorar sinais de toxicidad serotoninérgica',
    'Síndrome serotoninérgica — Metoclopramida + ISRS: preferir ondansetrona',
    EvidenceLevel.probable,
    {RiskType.serotonin, RiskType.cns},
    [_kRefGG, _kRefMdx, _kRefUT]),

  // 132 — Metoclopramida + Antipsicóticos (efeito extrapiramidal)
  ('metoclopramida', 'haloperidol',
    InteractionSeverity.major,
    'Ambos bloqueiam receptores D2 dopaminérgicos no sistema nigroestriatal e mesolímbico; a combinação causa bloqueio dopaminérgico aditivo no estriado, aumentando drásticamente o risco de reações extrapiramidais agudas',
    'Distonia aguda (torcicolo, crise oculogírica, trismo), acatisia, parkinsonismo farmacológico agudo; raramente síndrome neuroléptica maligna com hipertermia e rigidez',
    'Contraindicar combinação de rotina. Se antiemético for necesario em paciente em antipsicótico, preferir ondansetrona. Se ocorrer distonia aguda, administrar biperideno 5 mg IM ou difenidramina IV',
    'Extrapiramidal grave — Metoclopramida + Antipsicótico: antagonismo D2 aditivo',
    EvidenceLevel.established,
    {RiskType.cns},
    [_kRefGG, _kRefKatz]),

  // 133 — Domperidona + Amiodarona (QT)
  ('domperidona', 'amiodarona',
    InteractionSeverity.contraindicated,
    'Domperidona bloqueia canais hERG (IKr) de forma dose-dependente, prolongando o intervalo QT; amiodarona também prolonga o QTc por múltiplos mecanismos (bloqueio IKr, IKs, INa); a combinação causa prolongamento aditivo do QT com alto risco de torsades de pointes',
    'Torsades de pointes (TV polimórfica), fibrilação ventricular, morte súbita cardíaca; QTc > 500 ms',
    'Contraindicado. Amiodarona consta como fármaco contraindicado com domperidona nas bulas europeias. Usar metoclopramida (com cautela) ou ondansetrona como alternativas. Monitorar ECG se combinação inadvertida ocorrer',
    'CONTRAINDICADO — Domperidona + Amiodarona: QT longo fatal',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefGG, _kRefFDA, _kRefUT]),

  // 134 — Domperidona + Claritromicina (QT + inibição CYP)
  ('domperidona', 'claritromicina',
    InteractionSeverity.contraindicated,
    'Claritromicina é potente inibidor do CYP3A4, principal via de metabolismo da domperidona; a inibição aumenta a exposição sistêmica à domperidona em 3–4x; claritromicina também prolonga o QT por bloqueio hERG; efeito duplo (farmacocinético + farmacodinâmico) no prolongamento do QT',
    'QTc > 500 ms, torsades de pointes, fibrilação ventricular, morte súbita; risco especialmente elevado em idosos, hipocalêmicos e com cardiopatia de base',
    'Combinação formalmente contraindicada pelas agências regulatórias. Usar alternativa para náuseas (ondansetrona, metoclopramida em dose única). Usar azitromicina ou doxiciclina em vez de claritromicina se possível',
    'CONTRAINDICADO — Domperidona + Claritromicina: QT fatal + inibição CYP3A4',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 135 — Ondansetrona + Tramadol (5-HT3 + serotonina)
  ('ondansetron', 'tramadol',
    InteractionSeverity.moderate,
    'Ondansetrona antagoniza receptores 5-HT3 que são parcialmente responsáveis pela analgesia do tramadol; além de reduzir a analgesia, o tramadol inibe a recaptação de serotonina e o bloqueio 5-HT3 pela ondansetrona pode paradoxalmente aumentar a atividade serotoninérgica em outros receptores (5-HT1A, 5-HT2); efeito complexo no equilíbrio serotoninérgico',
    'Reducción de la eficacia analgésica do tramadol (necessidade de doses maiores); síndrome serotoninérgica paradoxal em doses altas; prolongamento do QT (ambos prolongam o QTc)',
    'Usar com cautela e monitorar eficácia analgésica. Considerar alternativas analgésicas em pacientes em ondansetrona. Preferir granisetron ou palonosetrona (menor interação) como antieméticos alternativos. Monitorar ECG se QTc basal elevado',
    'Redução da analgesia + risco QT — Ondansetrona + Tramadol: interação dual',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy, RiskType.qtProlongation, RiskType.serotonin},
    [_kRefGG, _kRefMdx]),

  // 136 — Prucaloprida + Antifúngicos azólicos (CYP3A4)
  ('prucalopride', 'ketoconazol',
    InteractionSeverity.moderate,
    'Prucaloprida é agonista seletivo 5-HT4 metabolizada parcialmente pelo CYP3A4 e excretada principalmente pelos rins; cetoconazol, como potente inibidor do CYP3A4, pode aumentar a exposição sistêmica à prucaloprida em ~40%; efeito clinicamente moderado dado o papel menor do CYP3A4 na eliminação total',
    'Diarreia, cólicas abdominais, cefaleia, palpitações por concentrações aumentadas de prucaloprida',
    'Monitorar efeitos gastrointestinais durante uso concomitante. Iniciar com dose menor de prucaloprida (1 mg/dia) em vez de 2 mg/dia se necesario. Azóis tópicos ou fluconazol em dose única têm menor impacto',
    'Exposição aumentada de prucaloprida — Azóis inibem CYP3A4: reduzir dose',
    EvidenceLevel.probable,
    {RiskType.increasedToxicity},
    [_kRefGG]),

  // 137 — Voriconazol + Sirolimus (inibição CYP extrema)
  ('voriconazol', 'sirolimus',
    InteractionSeverity.contraindicated,
    'Voriconazol é potentíssimo inibidor do CYP3A4 e CYP2C19; sirolimus (rapamicina) é substrato exclusivo do CYP3A4 com janela terapéutica extremamente estreita; a inibição causa aumento de 10–11x nos níveis de sirolimus, uma das interações de maior magnitude clínica descrita',
    'Toxicidade grave de sirolimus: pneumonite intersticial, trombocitopenia, anemia, hipertrigliceridemia, insuficiencia renal aguda, infecções oportunistas, cicatrização prejudicada',
    'Combinação contraindicada pelas bulas. Se antifúngico azólico for indispensável em transplantado em sirolimus, suspender o sirolimus e trocar por tacrolimus (menor interação) ou anfotericina B lipossomal como antifúngico alternativo',
    'CONTRAINDICADO — Voriconazol + Sirolimus: 10x aumento de sirolimus = toxicidad letal',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.nephrotoxicity, RiskType.myelosuppression},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 138 — Voriconazol + Varfarina
  ('voriconazol', 'varfarina',
    InteractionSeverity.major,
    'Voriconazol inibe intensamente o CYP2C9 (e CYP3A4 e CYP2C19); o CYP2C9 é responsável pela metabolização da S-varfarina (forma farmacologicamente mais potente); a inibição aumenta os níveis de S-varfarina em 2–3x, amplificando o efeito anticoagulante dramaticamente',
    'Sangramento grave e potencialmente fatal: hemorragia intracraniana, gastrointestinal maciça, retroperitoneal; INR pode dobrar ou triplicar dentro de 48–72 horas do início do voriconazol',
    'Monitorar INR a cada 2–3 dias durante co-administração. Reduzir dose de varfarina em 30–50% ao iniciar voriconazol. Ao suspender voriconazol, reajustar varfarina com monitoramento diário por 1 semana. Considerar heparina como ponte se INR instável',
    'INR dobra/triplica — Voriconazol + Varfarina: monitorar INR a cada 2 dias',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefFDA, _kRefGG, _kRefUT, _kRefMdx]),

  // 139 — Posaconazol + Ciclosporina
  ('posaconazol', 'ciclosporina',
    InteractionSeverity.major,
    'Posaconazol inibe o CYP3A4 e a P-glicoproteína (P-gp); ciclosporina é substrato de ambos; a inibição aumenta os níveis de ciclosporina em 1,5–2x; ciclosporina tem janela terapéutica estreita com nefrotoxicidad e neurotoxicidad dependentes de concentração',
    'Nefrotoxicidad por ciclosporina (creatinina elevada, oligúria, síndrome hemolítico-urêmica); neurotoxicidad (tremor, encefalopatia, convulsiones); hepatotoxicidad por acúmulo',
    'Monitorar níveis de ciclosporina (C0) dentro de 2–3 dias após início do posaconazol. Reduzir dose de ciclosporina em ~25% preventivamente. Manter monitoramento diário de función renal nas primeiras 2 semanas',
    'Nefrotoxicidad de ciclosporina — Posaconazol aumenta níveis 1,5–2x',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.nephrotoxicity},
    [_kRefGG, _kRefUT, _kRefFDA]),

  // 140 — Anfotericina B + Aminoglicosídeos (nefrotoxicidad)
  ('anfotericina', 'gentamicina',
    InteractionSeverity.major,
    'Anfotericina B causa nefrotoxicidad por alteração da permeabilidade de membranas celulares tubulares renais, redução do fluxo sanguíneo renal e hipopotasemia/hipomagnesemia induzida; aminoglicosídeos causam nefrotoxicidad por acúmulo no córtex renal com dano tubular proximal; efeito nefrotóxico sinérgico',
    'Insuficiência renal aguda grave, oligúria, hipopotasemia, hipomagnesemia, necrose tubular aguda; pode ser necessária terapia renal substitutiva',
    'Evitar combinación sempre que possível. Se indispensável em infecção grave, monitorar creatinina, K+ e Mg++ diariamente. Assegurar hidratação adecuada (200–500 mL SF antes de cada dose de anfotericina). Usar anfotericina B lipossomal (menor nefrotoxicidad que convencional). Monitorar nível de aminoglicosídeo',
    'Nefrotoxicidad sinérgica grave — Anfotericina + Aminoglicosídeo: monitorar renal diário',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefUT, _kRefMdx]),

  // 141 — Rifampicina + Fluconazol (antagonismo + indução)
  ('rifampicina', 'fluconazol',
    InteractionSeverity.major,
    'Rifampicina é potente indutor do CYP2C9 e CYP3A4, principais enzimas de metabolismo do fluconazol; a indução reduz os níveis de fluconazol em 22–25%, comprometendo a eficácia antifúngica; paradoxalmente, fluconazol inibe o CYP2C9 que metaboliza compostos do próprio regime antituberculoso',
    'Falha terapéutica do fluconazol com progressão de infecção fúngica; interações complexas com outros fármacos antifúngicos e antibióticos do regime TB',
    'Considerar aumentar dose de fluconazol para 800 mg/dia (padrão habitual 400 mg/dia) em infecções graves. Monitorar resposta clínica e microbiológica semanal. Para criptococose em TB: posaconazol IV pode ser alternativa com menor indução',
    'Falha antifúngica — Rifampicina reduz fluconazol 25%: aumentar dose para 800 mg',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefUT]),

  // 142 — Isoniazida + Fenitoína (inibição CYP2C9)
  ('isoniazida', 'fenitoina',
    InteractionSeverity.major,
    'Isoniazida é inibidor do CYP2C9 (via inibição do citocromo P450 hepático); fenitoína é substrato primário do CYP2C9 com janela terapéutica estreita; a inibição pode aumentar os níveis de fenitoína em 2–5x, gerando toxicidad grave; acetiladores lentos de isoniazida têm maior risco',
    'Toxicidade por fenitoína: nistagmo, ataxia, diplopia, confusão mental, sonolência, convulsiones paradoxais por toxicidad; encefalopatia em casos graves',
    'Monitorar nivel sérico de fenitoína (alvo 10–20 mcg/mL) na primeira semana após início da isoniazida e depois mensalmente. Reduzir dose de fenitoína em ~25% preventivamente. Dosagem frecuente em pacientes acetiladores lentos (índice étnico: africanos, asiáticos têm maior proporção)',
    'Toxicidade de fenitoína — Isoniazida inibe CYP2C9: monitorar nível semanalmente',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.plasmaLevel},
    [_kRefGG, _kRefKatz, _kRefMdx]),

  // 143 — Etambutol + Hidróxido de Alumínio (absorção)
  ('etambutol', 'hidróxido_alumínio',
    InteractionSeverity.moderate,
    'Antácidos contendo alumínio formam complexos de quelação com o etambutol no trato gastrointestinal, reduzindo sua absorção oral em 10–28%; o alumínio se liga ao etambutol formando quelatos não absorvíveis; a biodisponibilidade reducida pode comprometer a eficácia antituberculosa',
    'Concentrações subterapéuticas de etambutol com risco de falha terapéutica no tratamento da tuberculose; maior risco de resistência a etambutol',
    'Administrar etambutol pelo menos 4 horas antes ou 2 horas após os antiácidos contendo alumínio ou magnésio. Orientar paciente sobre o intervalo necesario. Horários fixos ajudam na adesão',
    'Redução de absorção do etambutol — Separar 4 horas de antiácidos com alumínio',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefUT]),

  // 144 — Pirazinamida + Alopurinol
  ('pirazinamida', 'alopurinol',
    InteractionSeverity.moderate,
    'Pirazinamida reduz a excreção renal de ácido úrico ao inibir a uricase tubular, causando hiperuricemia e precipitando crises de gota; alopurinol inibe a xantina oxidase, reduzindo a síntese de ácido úrico; os dois mecanismos se opõem mas a interação é complexa: pirazinamida pode superar o efeito do alopurinol em doses terapéuticas de TB',
    'Persistência de hiperuricemia e crises gotosas apesar do uso de alopurinol; necessidade de doses maiores de uricostático; raramente gota poliarticular grave',
    'Aumentar dose de alopurinol se necesario (até 600–800 mg/dia). Monitorar ácido úrico sérico mensalmente durante regime com pirazinamida. Em crises de gota, usar colchicina (cautela com interações) ou corticoide oral de curta duração',
    'Hiperuricemia resistente — Pirazinamida supera efeito do alopurinol: monitorar uricemia',
    EvidenceLevel.established,
    {RiskType.other},
    [_kRefGG, _kRefMdx]),

  // 145 — Bedaquilina + Moxifloxacino (QT aditivo)
  ('bedaquilina', 'moxifloxacino',
    InteractionSeverity.major,
    'Bedaquilina bloqueia a ATP sintase da micobactéria e prolonga o QT por mecanismo não totalmente elucidado (não é hERG); moxifloxacino prolonga o QT por bloqueio dos canais hERG (IKr) de forma dose-dependente; a combinação prolonga o QTc de forma aditiva, com risco substancial de torsades de pointes em pacientes com TB-MR',
    'Prolongamento do QTc > 500 ms, torsades de pointes, fibrilação ventricular, morte súbita; risco elevado em desnutridos, hipocalêmicos e com cardiopatia de base (comuns em TB-MR)',
    'ECG obligatorio antes, ao 2 e 12 semanas, e mensalmente. Se QTc > 480 ms, revisar electrolitos e todos os fármacos que prolongam QT. Se QTc > 500 ms, suspender bedaquilina. Manter K+ > 4 mEq/L e Mg++ > 0,8 mEq/L durante toda a terapia',
    'QT longo grave — Bedaquilina + Moxifloxacino: ECG obligatorio quinzenal',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 146 — Delamanida + Claritromicina (QT + inibição CYP)
  ('delamanida', 'claritromicina',
    InteractionSeverity.major,
    'Delamanida (nitroimidazol para TB-MR) prolonga o QT por bloqueio dos canais IKr; claritromicina prolonga o QT e inibe o CYP3A4, responsável pelo metabolismo do metabólito ativo da delamanida; o resultado é aumento da exposição ao metabólito ativo e maior prolongamento do QT',
    'QTc > 500 ms, torsades de pointes, morte súbita em pacientes com TB-MR; interação de alto risco em pacientes já com comprometimento metabólico',
    'Evitar combinación. Se necesario antibiótico para TB-MR com infecção bacteriana sobreposta, considerar azitromicina (menor risco de QT que claritromicina, sem inibição CYP3A4). Monitorar ECG semanalmente se combinação inevitável',
    'QT fatal — Delamanida + Claritromicina: prolongamento QT aditivo + inibição metabólica',
    EvidenceLevel.probable,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefFDA, _kRefGG]),

  // 147 — Linezolida + Triptofano/Suplementos (serotonina)
  ('linezolida', 'triptofano',
    InteractionSeverity.major,
    'Linezolida é inibidor fraco mas clinicamente relevante da MAO-A; o triptofano (aminoácido precursor da serotonina) aumenta a disponibilidade de serotonina; a inibição da MAO-A reduz a degradação da serotonina endógena e da proveniente do triptofano, podendo precipitar síndrome serotoninérgica',
    'Síndrome serotoninérgica: tremor, agitação, diarreia, hiperreflexia, mioclonia, hipertermia; casos graves com colapso hemodinâmico',
    'Evitar suplementos de triptofano e alimentos ricos em tiramina durante linezolida. Orientar paciente sobre restrições dietéticas (queijos maturados, vinho tinto, embutidos). Monitorar sinais de toxicidad serotoninérgica',
    'Síndrome serotoninérgica — Linezolida (IMAO) + Triptofano: restringir dieta',
    EvidenceLevel.probable,
    {RiskType.serotonin},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 148 — Ceftolozano/Tazobactam + Piperacilina/Tazobactam (redundância)
  ('ceftolozane', 'piperacilina',
    InteractionSeverity.minor,
    'Ceftolozano/tazobactam e piperacilina/tazobactam não têm interação farmacocinética ou farmacodinâmica sinérgica clinicamente relevante; ambos contêm tazobactam (inibidor de betalactamases), sendo a combinação desnecessária e potencialmente geradora de resistência ao tazobactam por saturação',
    'Sem toxicidad adicional esperada; uso redundante de tazobactam sem benefício clínico comprovado; risco teórico de seleção de resistência',
    'Não combinar de rotina. Cada um tem espectro específico: ceftolozano é dirigido a Pseudomonas MDR; piperacilina cobre Gram-negativos sensíveis. Selecionar o mais adecuado ao perfil de sensibilidade e evitar uso simultâneo',
    'Redundância de tazobactam — Não combinar ceftolozano + pip-tazo: espectro sobrepostos',
    EvidenceLevel.theoretical,
    {RiskType.other},
    [_kRefGG]),

  // 149 — Fosfomicina + Metotrexato
  ('fosfomicina', 'metotrexato',
    InteractionSeverity.moderate,
    'Fosfomicina pode reduzir a excreção renal tubular do metotrexato por competição pelo mesmo transportador (OAT1/OAT3); como o metotrexato tem janela terapéutica estreita e é excretado principalmente pelos rins, qualquer redução no clearance aumenta o risco de toxicidad grave',
    'Mucosita oral grave, pancitopenia, insuficiencia renal aguda, hepatotoxicidad por acúmulo de metotrexato; risco especialmente alto em doses altas de metotrexato para oncologia',
    'Monitorar nível de metotrexato nas doses oncológicas. Para doses reumatológicas baixas (7,5–25 mg/semana), o risco é menor mas manter vigilância. Assegurar hidratação adecuada e alcalinização urinária. Evitar fosfomicina IV em pacientes com metotrexato em dose alta',
    'Acúmulo de metotrexato — Fosfomicina pode reduzir clearance renal: monitorar nível',
    EvidenceLevel.theoretical,
    {RiskType.nephrotoxicity, RiskType.myelosuppression},
    [_kRefGG]),

  // 150 — Daptomicina + HMG-CoA Redutase (rabdomiólisis aditiva)
  ('daptomicina', 'rosuvastatina',
    InteractionSeverity.major,
    'Daptomicina causa miotoxicidad por inserção nas membranas celulares dos miócitos, com risco de miopatia e rabdomiólisis; estatinas inibem a síntese do CoQ10 e do colesterol de membrana, aumentando a vulnerabilidade muscular à lesão; a combinação tem efeito miotóxico sinérgico, com maior risco para rosuvastatina (maior potência)',
    'Miopatia grave, rabdomiólisis com CK > 10x o limite superior, mioglobinúria, insuficiencia renal aguda por nefropatia pigmentar',
    'Suspender estatina enquanto durar o tratamento com daptomicina (geralmente 4–6 semanas). Monitorar CK no início, semanalmente durante a daptomicina e 1 semana após a suspensão. Se CK > 5x LSN: suspender daptomicina. Manter hidratação adecuada',
    'Rabdomiólise aditiva — Suspender estatina durante tratamento com daptomicina',
    EvidenceLevel.established,
    {RiskType.myopathy},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 151 — Meropeném + Ácido Valpróico (redução de valproato)
  ('meropenem', 'valproato',
    InteractionSeverity.major,
    'Carbapenêmicos (imipeném, meropeném, ertapeném) reduzem os níveis de valproato em 40–90% por mecanismo multifatorial: inibição da absorção intestinal, aumento da eliminação renal do valproato-glucuronídeo (que é convertido de volta ao valproato) e possivelmente inibição hepática da conversão do metabólito ao valproato ativo',
    'Perda do controle de crises epilépticas com níveis subterapéuticos de valproato; crises tônico-clônicas generalizadas; estado de mal epiléptico em casos graves',
    'Contraindicar combinação se possível. Se carbapenêmico for indispensável em epiléptico controlado com valproato, planejar terapia antiepiléptica alternativa imediatamente (levetiracetam, lacosamida). Monitorar nível de valproato a cada 24–48 horas. A interação inicia em 24 horas e pode persistir por dias após a suspensão do carbapenêmico',
    'CONTRAINDICADO em epilépticos — Meropeném reduz valproato até 90%: crises epilépticas',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.seizure},
    [_kRefGG, _kRefKatz, _kRefMdx, _kRefUT]),

  // 152 — Colistina + Polimixina B (nefrotoxicidad aditiva)
  ('colistina', 'polimixina_b',
    InteractionSeverity.contraindicated,
    'Colistina (polimixina E) e polimixina B são antibióticos do mesmo grupo (polimixinas) com mecanismo de ação e toxicidad idênticos: ruptura da membrana celular bacteriana por interação com lipopolissacarídeos; ambas causam nefrotoxicidad dose-dependente e neurotoxicidad; a combinação não tem benefício adicional e duplica o risco tóxico',
    'Nefrotoxicidad grave com insuficiencia renal aguda (incidência de 50–60% com monoterapia, maior com combinação); neurotoxicidad com parestesias, ataxia, bloqueio neuromuscular',
    'Nunca combinar duas polimixinas. Selecionar uma para uso baseado em disponibilidade e vias de administração (colistina IV e inalatória; polimixina B IV). Ajustar dose renal rigurosamente. Monitorar creatinina e urina diariamente',
    'CONTRAINDICADO — Duas polimixinas: nefrotoxicidad e neurotoxicidad duplicadas',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefFDA]),

  // 153 — Linezolida + Metformina
  ('linezolida', 'metformina',
    InteractionSeverity.moderate,
    'Linezolida inibe fracamente a MAO mitocondrial; metformina actua nas mitocôndrias inibindo o complexo I da cadeia respiratória; a combinação pode potenciar o risco de acidose lática por comprometimento adicional do metabolismo mitocondrial e acúmulo de lactato; mecanismo hipotético mas com casos clínicos descritos',
    'Acidose lática (pH < 7,35, lactato > 5 mmol/L): náuseas, dor abdominal, fraqueza muscular, taquipneia, hipotensão; mortalidade de 30–50% em casos graves',
    'Monitorar lactato sérico se combinação necessária em pacientes com fatores de risco (insuficiencia renal, hepática, etilismo). Considerar suspender metformina durante cursos prolongados de linezolida (> 10 dias). Não há necessidade de suspensão preventiva em todos os casos',
    'Acidose lática potencial — Linezolida + Metformina: monitorar lactato em fatores de risco',
    EvidenceLevel.possible,
    {RiskType.other, RiskType.hepatotoxicity},
    [_kRefGG, _kRefMdx]),

  // 154 — Vancomicina + Piperacilina-Tazobactam (nefrotoxicidad)
  ('vancomicina', 'piperacilina',
    InteractionSeverity.major,
    'Estudos farmacoepidemiológicos e metanálises demonstraram que a combinação de vancomicina com piperacilina/tazobactam aumenta o risco de lesão renal aguda (LRA) em 2–3x em comparação com vancomicina com outros beta-lactâmicos; o mecanismo exato é debatido: possível inibição do transportador OAT por tazobactam aumentando a concentração intratubular de vancomicina',
    'Insuficiência renal aguda (creatinina > 0,5 mg/dL acima do basal ou aumento > 50%); oligúria; necessidade de terapia renal substitutiva em casos graves; a LRA ocorre em média no dia 4–6 de combinação',
    'Se possível, preferir cefepima ou meropeném como partner de vancomicina em sepse grave. Se pip-tazo for necesario, monitorar creatinina diariamente. Usar vancomicina AUC-guided (meta AUC/MIC 400–600) em vez de monitoramento de vale tradicional. Hidratação adecuada',
    'Nefrotoxicidad 3x maior — Vancomicina + Pip-Tazo: preferir cefepima como partner',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefUT, _kRefMdx]),

  // 155 — Budesonida inalatória + Itraconazol (corticoide sistêmico)
  ('budesonida', 'itraconazol',
    InteractionSeverity.major,
    'Itraconazol inibe potentemente o CYP3A4 no intestino e fígado; budesonida inalatória passa pelo efeito de primeira passagem, e a porção deglutida (30–40%) sofre extenso metabolismo CYP3A4 intestinal; com a inibição, os níveis sistêmicos de budesonida podem aumentar 4–6x, causando efeitos sistêmicos do corticoide',
    'Síndrome de Cushing iatrogênica: ganho de peso, face em lua, estrias, hiperglucemia, hipertensão, osteoporose acelerada, supressão do eixo HPA com insuficiencia adrenal ao suspender o corticoide',
    'Evitar itraconazol em pacientes em budesonida inalatória de alta dose. Se necesario antifúngico sistêmico, preferir anfotericina B IV (sem interação CYP) ou ajustar para menor dose de budesonida. Monitorar sinais de Cushing e função adrenal',
    'Síndrome de Cushing — Itraconazol + Budesonida inalatória: níveis 4–6x maiores',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefGG, _kRefUT, _kRefFDA]),

  // 156 — Dexametasona + Ciclosporina (efeito bidirecional)
  ('dexametasona', 'ciclosporina',
    InteractionSeverity.major,
    'Interação bidirecional: dexametasona induz o CYP3A4 reduzindo os níveis de ciclosporina (risco de rejeição); por outro lado, a ciclosporina inibe o CYP3A4 podendo aumentar os níveis sistêmicos de dexametasona; o resultado líquido depende das doses relativas e da duração do uso',
    'Rejeição aguda de transplante por queda nos níveis de ciclosporina; ou efeitos cushingoides exacerbados por acúmulo de dexametasona; imunossupressão excessiva',
    'Monitorar nível de ciclosporina (C0) rigurosamente durante uso concomitante de dexametasona. Ajustar dose de ciclosporina conforme. Após suspensão da dexametasona, re-monitorar ciclosporina pois os níveis podem aumentar',
    'Interação bidirecional — Dexametasona + Ciclosporina: monitorar C0 em ambas as direções',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.reducedEfficacy},
    [_kRefGG, _kRefUT]),

  // 157 — Prednisona + Antiácidos (absorção)
  ('prednisona', 'hidróxido_alumínio',
    InteractionSeverity.minor,
    'Antiácidos contendo alumínio e magnésio podem reduzir ligeiramente a absorção oral de corticoides, formando complexos que retardam a dissolução do comprimido; o efeito é pequeno e clinicamente relevante apenas com uso crônico e altas doses',
    'Leve redução na biodisponibilidade do corticoide; raramente impacto clínico significativo em doses terapéuticas habituais',
    'Separar a administração do corticoide dos antiácidos em pelo menos 2 horas. Em uso crônico de corticoide em doses altas, preferir inibidor de bomba de prótons (proteção gástrica) em vez de antiácido com alumínio',
    'Absorção leve reducida — Prednisona + Antiácidos: separar 2 horas',
    EvidenceLevel.possible,
    {RiskType.reducedEfficacy},
    [_kRefGG]),

  // 158 — Hidrocortisona IV + Ampicilina (inativação Y-site)
  ('hidrocortisona', 'ampicilina',
    InteractionSeverity.minor,
    'Hidrocortisona e ampicilina são fisicamente incompatíveis quando misturadas na mesma solução ou Y-site em concentrações elevadas: a alcalinidade da ampicilina pode acelerar a degradação da hidrocortisona; a mistura pode causar turvação e formação de precipitado',
    'Redução na eficácia de ambos os fármacos por degradação química; obstrução de cateteres IV por precipitado',
    'Não misturar na mesma bolsa de infusão. Se usar Y-site simultâneo, verificar compatibilidade farmacêutica para as concentrações específicas. Preferencialmente, administrar em vias separadas',
    'Incompatibilidade física — Hidrocortisona IV + Ampicilina: usar vias separadas',
    EvidenceLevel.theoretical,
    {RiskType.other},
    [_kRefGG]),

  // 159 — Mometasona intranasal + Cetoconazol oral
  ('mometasona', 'cetoconazol',
    InteractionSeverity.moderate,
    'Cetoconazol sistêmico inibe intensamente o CYP3A4; mometasona, mesmo por via intranasal, tem metabolismo de primeira passagem CYP3A4 para a porção absorvida sistemicamente; os níveis sistêmicos de mometasona podem aumentar, causando efeitos corticosteroidais sistêmicos',
    'Supressão adrenal, síndrome de Cushing, hiperglucemia, osteoporose acelerada; risco maior em crianças e usuários de doses altas de mometasona intranasal',
    'Evitar cetoconazol oral sistêmico em usuários de mometasona. Usar fluconazol tópico ou anfotericina B tópica para candidíase oral/esofágica. Se antifúngico sistêmico for necesario, escolher terbinafina (sem interação CYP3A4) para infecções cutâneas',
    'Supressão adrenal — Cetoconazol sistêmico + Mometasona: evitar combinação',
    EvidenceLevel.probable,
    {RiskType.increasedToxicity},
    [_kRefGG, _kRefFDA]),

  // 160 — Mizolastina + Amiodarona (QT)
  ('mizolastina', 'amiodarona',
    InteractionSeverity.contraindicated,
    'Mizolastina (anti-histamínico H1 de segunda geração) prolonga o intervalo QT por bloqueio dos canais hERG (IKr), de forma semelhante à terfenadina (precursor que causou mortes por arritmia); amiodarona prolonga agressivamente o QT por múltiplos mecanismos; combinação com risco de torsades de pointes muito elevado',
    'QTc > 500 ms, torsades de pointes, fibrilação ventricular, morte súbita; casos fatais documentados com anti-histamínicos que prolongam QT associados a antiarrítmicos classe III',
    'Contraindicado. Anti-histamínicos seguros em pacientes com amiodarona: cetirizina, loratadina, fexofenadina (sem efeito no QT). Evitar todos os anti-histamínicos com risco de QT (mizolastina, astemizol, terfenadina)',
    'CONTRAINDICADO — Mizolastina + Amiodarona: QT fatal (mesma classe da terfenadina)',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefGG, _kRefFDA, _kRefUT]),


  // ═══════════════════════════════════════════════════════════════
  // BLOCK 7 — Cardiovascular avançado, Insuficiência cardíaca,
  // Ginecologia avançada, Neurologia (161–190)
  // ═══════════════════════════════════════════════════════════════

  // 161 — Ivabradina + Diltiazem (bradicardia sinérgica)
  ('ivabradina', 'diltiazem',
    InteractionSeverity.contraindicated,
    'Ivabradina reduz a frequência cardíaca por bloqueio seletivo dos canais If no nódulo sinusal (HCN4); diltiazem é inibidor dos canais de cálcio com efeito cronotrópico negativo significativo e, adicionalmente, inibe o CYP3A4 responsável pelo metabolismo da ivabradina, aumentando sua exposição em 2–3x; duplo mecanismo de bradicardia (farmacodinâmico + farmacocinético)',
    'Bradicardia sintomática grave (FC < 40 bpm), bloqueio AV, síncope, hipotensão grave; risco de parada cardiorrespiratória',
    'Contraindicado. Diuréticos ou hidralazina como alternativas para manejo da ICC se necesario. Se beta-bloqueador e ivabradina forem usados, monitorar FC rigurosamente. Nunca combinar ivabradina com diltiazem ou verapamil',
    'CONTRAINDICADO — Ivabradina + Diltiazem: bradicardia grave (PK + PD)',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 162 — Ivabradina + Claritromicina (inibição CYP3A4 severa)
  ('ivabradina', 'claritromicina',
    InteractionSeverity.contraindicated,
    'Claritromicina é potente inibidor do CYP3A4 e aumenta a exposição à ivabradina em até 7x; com concentrações tão elevadas de ivabradina, o risco de bradicardia grave e bloqueio AV é muito alto; a interação é de alta magnitude clínica',
    'Bradicardia grave, bloqueio AV de 2º e 3º grau, síncope, hipotensão, risco de morte',
    'Contraindicado. Usar azitromicina como alternativa antibiótica (sem inibição CYP3A4 significativa). Se claritromicina for indispensável (ex: Helicobacter, MAC em HIV), suspender temporariamente a ivabradina',
    'CONTRAINDICADO — Ivabradina + Claritromicina: níveis 7x maiores, bradicardia fatal',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    [_kRefFDA, _kRefGG]),

  // 163 — Dronedarona + Dabigatrana (P-gp inibição)
  ('dronedarona', 'dabigatrana',
    InteractionSeverity.major,
    'Dronedarona é potente inibidor da P-glicoproteína (P-gp) e do CYP3A4; dabigatrana é substrato exclusivo da P-gp (não é metabolizada pelo CYP450); a inibição da P-gp pelo dronedarona aumenta a exposição à dabigatrana em 70–100%, duplicando o risco hemorrágico',
    'Sangramento grave: hemorragia intracraniana, gastrointestinal, retroperitoneal; risco especialmente elevado em pacientes com insuficiencia renal (dabigatrana é excretada principalmente pelos rins)',
    'Se necesario anticoagulante com dronedarona, preferir warfarina com monitoramento de INR ou rivaroxabana (menor interação com P-gp). Se dabigatrana for mantida, reduzir dose para 110 mg 2x/dia e evitar em pacientes com TFG < 50 mL/min',
    'Sangramento grave — Dronedarona dobra exposição à dabigatrana via P-gp',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 164 — Dronedarona + Sinvastatina (rabdomiólisis)
  ('dronedarona', 'sinvastatina',
    InteractionSeverity.major,
    'Dronedarona inibe o CYP3A4 e a P-gp; sinvastatina é extensamente metabolizada pelo CYP3A4 e tem elevada extração de primeira passagem; a inibição aumenta os níveis de sinvastatina ativa em 2–4x, aumentando o risco de miopatia',
    'Miopatia, rabdomiólisis, CK > 10x LSN, mioglobinúria, insuficiencia renal aguda',
    'Limitar dose de sinvastatina a 10 mg/dia se dronedarona for indispensável. Preferir atorvastatina (menor risco) em dose ajustada ou pravastatina/rosuvastatina (não metabolizadas pelo CYP3A4). Monitorar CK se mialgias',
    'Rabdomiólise — Dronedarona aumenta sinvastatina: limitar a 10 mg/dia ou trocar estatina',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefFDA, _kRefGG]),

  // 165 — Ranolazina + Metformina
  ('ranolazina', 'metformina',
    InteractionSeverity.moderate,
    'Ranolazina inibe o transportador renal OCT2 (cátion orgânico 2) e a P-gp, reduzindo a excreção tubular da metformina; os niveles plasmáticos de metformina podem aumentar em 30–40%; em pacientes com fatores de risco para acidose lática (IRC, insuficiencia cardíaca), o aumento de metformina é clinicamente relevante',
    'Acidose lática por acúmulo de metformina: náuseas, dor abdominal, fraqueza, taquipneia, colapso hemodinâmico; mortalidade de 30–50%',
    'Monitorar función renal e sintomas de acidose lática. Dose máxima de metformina com ranolazina: 1.700 mg/dia (em vez de 2.550 mg/dia). Contraindicada a combinação em pacientes com TFG < 45 mL/min',
    'Acúmulo de metformina — Ranolazina inibe OCT2: limitar dose de metformina',
    EvidenceLevel.probable,
    {RiskType.other, RiskType.plasmaLevel},
    [_kRefGG, _kRefFDA]),

  // 166 — Vernakalant + Antiarrítmicos classe I/III
  ('vernakalant', 'flecainida',
    InteractionSeverity.contraindicated,
    'Vernakalant (antiarrítmico de ação predominantemente atrial para cardioversão de FA) tem efeitos eletrofisiológicos aditivos com outros antiarrítmicos classe I (bloqueio de canais de Na) e classe III (bloqueio de canais de K); a combinação pode causar disfunção do nódulo sinusal, bloqueio AV grave e prolongamento excessivo do QRS e QT',
    'Bradiarritmias graves, bloqueio AV completo, pausa sinusal, TV/FV; hipotensão por disfunção miocárdica aguda',
    'Contraindicado. Aguardar 4 horas após última dose de classe I antes de vernakalant IV. Não usar vernakalant em pacientes em amiodarona, sotalol ou outros classe III. Monitorar ECG e PA continuamente durante administração de vernakalant',
    'CONTRAINDICADO — Vernakalant + Classe I ou III: arritmias e bloqueio AV grave',
    EvidenceLevel.established,
    {RiskType.arrhythmia, RiskType.cardiovascular},
    [_kRefFDA, _kRefGG]),

  // 167 — Telmisartana + Lítio
  ('telmisartana', 'litio',
    InteractionSeverity.major,
    'ARA-II (telmisartana, losartana, etc.) reduzem a excreção renal de sódio; como o lítio é reabsorvido junto ao sódio no túbulo proximal, a retenção de sódio pelos ARA-II paradoxalmente aumenta a reabsorção de lítio, elevando seus níveis séricos em 20–35%; mecanismo similar ao dos IECA e diuréticos',
    'Toxicidade por lítio: tremor grosseiro, ataxia, confusão mental, letargia, convulsiones, insuficiencia renal aguda, coma; litemia > 1,5 mEq/L = toxicidad moderada; > 2 mEq/L = toxicidad grave',
    'Monitorar litemia dentro de 1 semana após início ou mudança de dose do ARA-II, depois mensalmente. Reduzir dose de lítio em 25% preventivamente. Assegurar hidratação adecuada. Pacientes em dieta hipossódica têm risco maior',
    'Toxicidade de lítio — ARA-II (telmisartana) aumenta litemia 20–35%: monitorar',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.cns},
    [_kRefGG, _kRefKatz, _kRefMdx]),

  // 168 — Aliskiren + IECA + ARA-II (bloqueio SRAA duplo)
  ('aliskiren', 'enalapril',
    InteractionSeverity.contraindicated,
    'Aliskiren (inibidor direto de renina) combinado com IECA ou ARA-II cria bloqueio duplo do sistema renina-angiotensina-aldosterona (SRAA); estudos (ALTITUDE, ONTARGET) demonstraram que o duplo bloqueio do SRAA aumenta o risco de hipotensão grave, hiperpotasemia e insuficiencia renal sem benefício cardiovascular adicional',
    'Hipotensão grave (síncope), insuficiencia renal aguda, hiperpotasemia grave (K+ > 6 mEq/L); maior risco em diabéticos com nefropatia e pacientes com ICC',
    'Contraindicado especialmente em diabéticos (ALTITUDE trial: interrompido por dano). Evitar em qualquer paciente. Se necesario maximizar bloqueio de SRAA, usar IECA + espironolactona (apenas com monitoramento) mas nunca IECA + ARA-II + aliskiren',
    'CONTRAINDICADO — Aliskiren + IECA: duplo bloqueio SRAA = hipotensão e IRA',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.hyperkalemia, RiskType.nephrotoxicity},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 169 — Clonidina + Beta-Bloqueador (rebound hipertensivo)
  ('clonidina', 'atenolol',
    InteractionSeverity.major,
    'Clonidina é agonista alfa-2 adrenérgico central que reduz a descarga simpática; ao suspender abruptamente a clonidina, ocorre hipertensão de rebote por aumento súbito do tônus simpático; beta-bloqueadores, ao bloquear os receptores beta e deixar os alfa-adrenérgicos desimpedidos, potencializam a vasoconstrição periférica durante o rebound, exacerbando a hipertensão',
    'Crise hipertensiva grave (PA > 180/120 mmHg) ao descontinuar abruptamente a clonidina; risco de AVC, IAM, encefalopatia hipertensiva; efeito especialmente perigoso na síndrome de retirada',
    'Nunca suspender clonidina abruptamente, especialmente se em uso de beta-bloqueador. Retirar gradualmente a lo largo de 7–10 días. Em caso de rebound, não tratar com beta-bloqueador IV (piora). Usar nitroprussiato, labetalol ou clonidina IV para controle da crise',
    'Crise hipertensiva de rebound — Nunca suspender clonidina abruptamente com beta-bloqueador',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    [_kRefGG, _kRefKatz]),

  // 170 — Hidralazina + Dinitrato de Isossorbida (hipotensão)
  ('hidralazina', 'isossorbida',
    InteractionSeverity.moderate,
    'Combinação deliberada para ICC em pacientes intolerantes a IECA/ARA-II (A-HeFT trial); hidralazina causa vasodilatação arterial (reduz pós-carga) e isossorbida causa vasodilatação venosa (reduz pré-carga); a combinação pode causar hipotensão ortostática significativa, especialmente no início do tratamento',
    'Hipotensão ortostática sintomática (tontura, síncope), taquicardia reflexa, cefaleia intensa por vasodilatação; a taquicardia pode precipitar eventos isquêmicos',
    'Iniciar com doses baixas e titular lentamente. Orientar paciente a mudar de posição gradualmente. Monitorar PA antes de cada dose nas primeiras semanas. Cefaleia pode melhorar após 2–4 semanas de uso contínuo',
    'Hipotensão ortostática — Hidralazina + Isossorbida: iniciar dose baixa e titular lentamente',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    [_kRefGG, _kRefUT]),

  // 171 — Digoxina + Amiodarona (toxicidad digitálica)
  ('digoxina', 'amiodarona',
    InteractionSeverity.major,
    'Amiodarona inibe a P-gp e reduz o clearance renal e extra-renal da digoxina; os níveis de digoxina aumentam 70–100% (quase dobram) dentro de 1–4 semanas do início da amiodarona; além do aumento farmacocinético, amiodarona tem efeito cronótropo negativo aditivo ao da digoxina no nódulo AV',
    'Toxicidade digitálica: náuseas, vômitos, xantopsia, bradicardia grave, bloqueio AV, bigeminismo, TV bidirecional; digoxinemia > 2 ng/mL confirma toxicidad',
    'Reduzir dose de digoxina em 50% ao iniciar amiodarona. Monitorar digoxinemia (alvo 0,5–1,0 ng/mL) após 7 dias e depois mensalmente. Monitorar ECG (PR, FC). Em toxicidad grave: anticorpo antidigoxina (Digibind)',
    'Toxicidade digitálica — Amiodarona dobra digoxina: reduzir dose 50% imediatamente',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.arrhythmia},
    [_kRefGG, _kRefKatz, _kRefMdx, _kRefUT]),

  // 172 — Sitagliptina + Insulina Glargina (hipoglucemia)
  ('sitagliptina', 'insulina_glargina',
    InteractionSeverity.moderate,
    'Inibidores de DPP-4 (sitagliptina) potencializam o efeito da insulina ao aumentar os níveis de GLP-1 e GIP endógenos, que estimulam a secreção de insulina glucose-dependente; em combinação com insulina basal, há risco de hipoglucemia por efeito aditivo nas células beta e possível sensibilização à ação insulínica',
    'Hipoglucemia: sudorese, tremor, taquicardia, confusão, convulsiones; o risco é maior ao iniciar ou aumentar dose de sitagliptina em pacientes já em insulina',
    'Considerar redução de 10–20% na dose de insulina basal ao iniciar sitagliptina. Orientar monitoramento de glucemia capilar mais frecuente nas primeiras 2–4 semanas. Educar paciente sobre reconhecimento e tratamento de hipoglucemia',
    'Hipoglucemia — Sitagliptina + Insulina: reduzir insulina 10–20% ao iniciar DPP-4i',
    EvidenceLevel.probable,
    {RiskType.hypoglycemia},
    [_kRefGG, _kRefUT]),

  // 173 — Exenatida + Acetaminofeno/Paracetamol (absorção)
  ('exenatida', 'paracetamol',
    InteractionSeverity.moderate,
    'Agonistas do receptor GLP-1 (exenatida, liraglutida) retardam o esvaziamento gástrico de forma dose-dependente; o paracetamol tem absorção primariamente duodenal e gástrica precoce; o retardo do esvaziamento gástrico pelo arGLP-1 atrasa o pico plasmático do paracetamol (Tmax aumenta de ~0,75h para ~2–3h) sem alterar a ASC total',
    'Retardo na analgesia: início da ação mais lento do paracetamol, podendo ser inadecuado em dor aguda; doses repetidas de paracetamol podem se acumular se o paciente tomar doses seguintes sem aguardar o intervalo adecuado',
    'Administrar paracetamol pelo menos 1 hora antes da injeção de arGLP-1 para analgesia rápida. Em dor crônica ou pós-operatória, monitorar eficácia e considerar intervalos maiores entre doses. AINEs podem ser alternativa (sem esta interação)',
    'Analgesia retardada — arGLP-1 retarda absorção do paracetamol: tomar 1h antes da injeção',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),

  // 174 — Empagliflozina + Torasemida (hipovolemia)
  ('empagliflozina', 'torasemida',
    InteractionSeverity.moderate,
    'iSGLT2 causam glicosúria osmótica com perda de água e sódio (efeito diurético osmótico); diuréticos de alça (torasemida, furosemida) causam perda adicional de sódio, potássio e água; a combinação tem efeito diurético sinérgico com risco de depleção de volume grave',
    'Hipotensão (especialmente ortostática), desidratação, insuficiencia renal pré-renal (creatinina elevada), hipopotasemia, quedas em idosos; em pacientes com ICC, o risco de depleção excessiva pode ser desejável mas requer monitoramento',
    'Monitorar PA e función renal ao início da combinação. Reduzir dose do diurético de alça em 25–50% se PA < 90/60 mmHg ou sinais de desidratação. Orientar ingestão hídrica adecuada e reconhecimento de sintomas de hipovolemia',
    'Hipovolemia sinérgica — iSGLT2 + Diurético de alça: monitorar PA e función renal',
    EvidenceLevel.probable,
    {RiskType.cardiovascular, RiskType.nephrotoxicity},
    [_kRefGG, _kRefUT]),

  // 175 — Canagliflozina + Fenitoína (CYP3A4 + UGT1A9)
  ('canagliflozina', 'fenitoina',
    InteractionSeverity.moderate,
    'Fenitoína induz múltiplas enzimas hepáticas incluindo UGT1A9, via de glucuronidação dos iSGLT2; a indução da UGT1A9 pode aumentar o metabolismo da canagliflozina em 20–30%, reduzindo seus niveles plasmáticos e eficácia',
    'Reducción de la eficacia hipoglucemiante da canagliflozina; piora do controle glicêmico com HbA1c acima do esperado; falha terapéutica do iSGLT2',
    'Monitorar HbA1c e glucemia em jejum ao iniciar ou aumentar dose de fenitoína. Pode ser necesario aumentar dose de canagliflozina para 300 mg/dia ou adicionar outro agente hipoglucemiante',
    'Eficácia reducida — Fenitoína (indutor UGT1A9) reduz canagliflozina: monitorar glucemia',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefFDA]),

  // 176 — Levodopa + Metoclopramida (antagonismo)
  ('levodopa', 'metoclopramida',
    InteractionSeverity.contraindicated,
    'Metoclopramida bloqueia receptores D2 dopaminérgicos no SNC e na periferia; a levodopa age via conversão a dopamina nos neurônios dopaminérgicos nigroestriatais; o bloqueio D2 pela metoclopramida antagoniza diretamente o efeito terapéutico da levodopa, piorando o parkinsonismo; também pode precipitar reações extrapiramidais agudas',
    'Piora grave do parkinsonismo (rigidez, tremor, acinesia), crises de distonia aguda, potencial síndrome neuroléptica maligna em pacientes com doença de Parkinson',
    'Contraindicado em parkinsonismo. Usar domperidona como alternativa antiemética (age perifericamente, sem penetrar SNC significativamente). Para gastroparesia em parkinsonismo, domperidona 10 mg 3x/dia antes das refeições',
    'CONTRAINDICADO — Metoclopramida + Levodopa: piora grave do parkinsonismo',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.reducedEfficacy},
    [_kRefGG, _kRefKatz, _kRefMdx]),

  // 177 — Pramipexol + Metoclopramida
  ('pramipexol', 'metoclopramida',
    InteractionSeverity.contraindicated,
    'Pramipexol é agonista D2/D3 dopaminérgico usado no parkinsonismo e síndrome das pernas inquietas; metoclopramida antagoniza D2, bloqueando diretamente o mecanismo de ação do pramipexol e revertendo o controle dos sintomas parkinsonianos e da síndrome das pernas inquietas',
    'Recorrência de parkinsonismo, síndrome das pernas inquietas refratária, potencial exacerbação com reações extrapiramidais agudas por antagonismo D2 somado',
    'Contraindicado. Mesma orientação que levodopa + metoclopramida. Domperidona é a alternativa antiemética segura no parkinsonismo',
    'CONTRAINDICADO — Metoclopramida antagoniza pramipexol: piora do parkinsonismo',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.reducedEfficacy},
    [_kRefGG, _kRefUT]),

  // 178 — Donepezilo + Succinilcolina (bloqueio neuromuscular)
  ('donepezilo', 'succinilcolina',
    InteractionSeverity.major,
    'Donepezilo inibe a acetilcolinesterase, aumentando os níveis de acetilcolina na fenda neuromuscular; a succinilcolina (bloqueador neuromuscular despolarizante) é hidrolisada pela pseudocolinesterase plasmática; com os inibidores de colinesterase, a atividade da pseudocolinesterase pode ser reducida, retardando a hidrólise da succinilcolina e prolongando o bloqueio neuromuscular',
    'Bloqueio neuromuscular prolongado com apneia pós-anestésica; necessidade de ventilação mecânica prolongada; paralisia muscular persistente',
    'Alertar o anestesiologista sobre o uso de donepezilo (e outros inibidores de colinesterase: rivastigmina, galantamina). Planejar monitoramento de bloqueio neuromuscular com neuroestimulador. Considerar uso de bloqueador não despolarizante (rocurônio) como alternativa à succinilcolina',
    'Apneia pós-anestésica — Donepezilo prolonga ação da succinilcolina: alertar anestesia',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression},
    [_kRefGG, _kRefKatz, _kRefUT]),

  // 179 — Memantina + Amantadina
  ('memantina', 'amantadina',
    InteractionSeverity.major,
    'Memantina é antagonista não competitivo de receptores NMDA; amantadina também é antagonista de receptores NMDA, além de ter propriedades dopaminérgicas; a combinação potencializa o bloqueio NMDA de forma sinérgica, com risco de toxicidad central (efeitos psicotomiméticos e convulsiones)',
    'Confusão mental, alucinações, agitação, tontura, convulsiones; síndrome de abstinência glutamatérgica com abstinência abrupta de ambos',
    'Evitar combinación. Se amantadina for necessária (influenza ou parkinsonismo avançado), considerar suspender temporariamente a memantina ou usar donepezilo como alternativa para demência',
    'Toxicidade central — Memantina + Amantadina: bloqueio NMDA duplo aditivo',
    EvidenceLevel.probable,
    {RiskType.cns},
    [_kRefGG, _kRefUT]),

  // 180 — Rivastigmina + Betanecol (colinérgico aditivo)
  ('rivastigmina', 'betanecol',
    InteractionSeverity.major,
    'Rivastigmina inibe as colinesterases, aumentando acetilcolina; betanecol é agonista muscarínico direto; a combinação gera estimulação colinérgica periférica e central excessiva com risco de síndrome colinérgica grave',
    'Síndrome colinérgica: bradicardia grave, hipotensão, sialorréia, broncoespasmo, cólicas intestinais, diarreia, sudorese profusa, miose, fraqueza muscular, convulsiones',
    'Evitar combinación. Se betanecol for indispensável (retenção urinária neurogênica), suspender rivastigmina temporariamente com orientação neurológica. Atropina como antídoto se toxicidad grave',
    'Síndrome colinérgica grave — Rivastigmina + Betanecol: estimulação muscarínica excessiva',
    EvidenceLevel.probable,
    {RiskType.cardiovascular, RiskType.respiratoryDepression},
    [_kRefGG]),

  // 181 — Lecanemabe + Anticoagulantes (hemorragia cerebral)
  ('lecanemabe', 'varfarina',
    InteractionSeverity.major,
    'Lecanemabe (anticorpo monoclonal anti-beta-amiloide para Alzheimer) causa como efeito adverso característico ARIA (anormalidades de imagem relacionadas a amiloide): ARIA-E (edema/efusão) e ARIA-H (hemossiderose/microhemorragias); anticoagulantes sistêmicos aumentam o risco de sangrado intracraneal quando ARIA-H ocorre, transformando microhemorragias em macroemorragias com sequelas neurológicas graves',
    'Hemorragia intracraniana sintomática, macroemorragia em áreas de ARIA-H preexistente; edema cerebral; óbito por hemorragia cerebral em pacientes anticoagulados',
    'Contraindicação relativa — alta cautela. Realizar RNM de triagem antes de iniciar lecanemabe. Anticoagulação sistêmica é fator de risco independente para ARIA sintomática. Discutir benefício/risco individualmente com cada paciente. Monitorar RNM a cada 3 meses durante o primeiro ano. Se ARIA-H detectado, suspender lecanemabe e anticoagulante',
    'Hemorragia cerebral — Lecanemabe + Anticoagulantes: ARIA-H com risco de macro-hemorragia',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.cns},
    [_kRefFDA, _kRefGG]),

  // 182 — Dutasterida + CYP3A4 inibidores (ex: Verapamil)
  ('dutasterida', 'verapamil',
    InteractionSeverity.moderate,
    'Dutasterida é metabolizada pelo CYP3A4 (e em menor grau CYP3A5); verapamil é inibidor moderado do CYP3A4 e pode reduzir o metabolismo da dutasterida, aumentando seus níveis em 30–50%; como dutasterida inibe a 5-alfa-redutase, concentrações maiores intensificam a supressão da DHT',
    'Efeitos feminilizantes exacerbados: disfunção sexual, ginecomastia, diminuição da libido; teratogenicidade potencial (DHT fetal crítica para desenvolvimento masculino)',
    'Monitorar sintomas de hiperdutasteridemia. Em parceiras em idade fértil, reforçar uso de preservativo (dutasterida excretada no sêmen). Alternativa: finasterida (metabolismo diferente) ou alfuzosina para HPB',
    'Efeitos da dutasterida amplificados — Verapamil inibe CYP3A4: monitorar efeitos adversos',
    EvidenceLevel.probable,
    {RiskType.increasedToxicity},
    [_kRefGG]),

  // 183 — Anastrozol + Tamoxifeno (antagonismo)
  ('anastrozol', 'tamoxifeno',
    InteractionSeverity.major,
    'Tamoxifeno é modulador seletivo do receptor de estrogênio (SERM) com efeito agonista parcial; anastrozol é inibidor de aromatase; estudos ATAC e ABCSG demonstraram que a combinação simultânea não oferece benefício adicional em relação à monoterapia e que o tamoxifeno pode reduzir os níveis de anastrozol em 27% por mecanismo farmacocinético (inducción enzimática)',
    'Redução dos niveles plasmáticos de anastrozol com possível comprometimento da supressão estrogênica; a combinação não reduz a recorrência do câncer de mama além da monoterapia e pode aumentar eventos adversos',
    'Não usar concomitantemente em adjuvância do câncer de mama. Usar sequencialmente (ex: tamoxifeno por 2–3 anos, depois anastrozol por 2–3 anos) conforme protocolos (MA.17). Cada monoterapia tem perfil de efeitos adversos específico',
    'Interação antagonista — Anastrozol + Tamoxifeno simultâneos: sem benefício adicional',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefUT, _kRefMdx]),

  // 184 — Letrozol + Indutores CYP (tamoxifeno como indutor)
  ('letrozol', 'carbamazepina',
    InteractionSeverity.moderate,
    'Letrozol é metabolizado pelo CYP2A6 e CYP3A4; carbamazepina induz o CYP3A4, podendo reduzir a AUC do letrozol em 20–35%; a supressão estrogênica pode ser comprometida com concentrações subterapéuticas de letrozol',
    'Falha terapéutica do letrozol com risco de recorrência de câncer de mama ou endométrio dependente de estrogênio',
    'Monitorar estradiol sérico como proxy da supressão estrogênica em pacientes em uso de indutores enzimáticos. Considerar alternativa antiepiléptica (levetiracetam, lamotrigina) sem indução CYP3A4. Aumentar dose de letrozol pode não ser possível por efeitos adversos',
    'Falha terapéutica — Carbamazepina reduz letrozol: considerar antiepiléptico sem indução',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefUT]),

  // 185 — Medroxiprogesterona + Rifampicina
  ('medroxiprogesterona', 'rifampicina',
    InteractionSeverity.major,
    'Rifampicina induz potentemente o CYP3A4 e CYP2C19, principais enzimas de metabolismo da medroxiprogesterona; mesmo a formulação injetável depot (ACM-D) sofre impacto: a depuração da medroxiprogesterona é acelerada, podendo reduzir a duração do efeito contraceptivo de 12 para 8–10 semanas',
    'Falha contraceptiva com gravidez não planejada; concentrações subterapéuticas antes do período habitual de reinjeção',
    'Reduzir o intervalo de aplicação do ACM-D de 13 para 10 semanas durante uso de rifampicina. Adicionar método de barreira (preservativo). Após suspensão da rifampicina, aguardar 28 dias antes de retornar ao intervalo normal de 13 semanas',
    'FALHA CONTRACEPTIVA — Rifampicina acelera metabolismo da medroxiprogesterona depot',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefUT]),

  // 186 — Leflunomida + Rifampicina (toxicidad de teriflunomida)
  ('leflunomida', 'rifampicina',
    InteractionSeverity.major,
    'Leflunomida é pró-farmaco convertido ao metabólito ativo teriflunomida (inibidor de diidroorotato desidrogenase); rifampicina induz o CYP1A2 e CYP2C19, e pode aumentar o metabolismo da teriflunomida, reduzindo seus níveis e a eficácia imunossupressora; paradoxalmente, a indução hepática pela rifampicina pode aumentar os níveis de alguns metabólitos tóxicos',
    'Falha do controle da artrite reumatoide por subexpossição à teriflunomida; raramente toxicidad hepática por acúmulo de metabólitos',
    'Monitorar resposta clínica (articulações, PCR, VHS) durante e após rifampicina. Monitorar ALT/AST mensalmente. Esta combinação é geralmente necessária em tuberculose em pacientes com AR — planejar cuidadosamente',
    'Falha imunossupressora — Rifampicina altera metabolismo de leflunomida: monitorar AR',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy, RiskType.hepatotoxicity},
    [_kRefGG, _kRefUT]),

  // 187 — Colchicina + Verapamil (toxicidad por P-gp + CYP3A4)
  ('colchicina', 'verapamil',
    InteractionSeverity.major,
    'Verapamil é inibidor do CYP3A4 e da P-glicoproteína; colchicina é substrato de ambos com janela terapéutica estreita e índice terapéutico baixo; a inibição simultânea de CYP3A4 e P-gp aumenta a exposição sistêmica à colchicina em 2–3x; toxicidad grave pode ocorrer mesmo em doses habituais',
    'Toxicidade grave de colchicina: miopatia com rabdomiólisis, pancitopenia, neuropatia periférica, falência de múltiplos órgãos; mortalidade elevada na toxicidad grave',
    'Reduzir dose de colchicina para metade em usuários de verapamil (dose máxima: 0,6 mg/dia em vez de 1,2 mg/dia). Monitorar CK e hemograma. Em pacientes com IRC, a combinação é especialmente perigosa e pode ser contraindicada',
    'Toxicidade de colchicina — Verapamil inibe CYP3A4 e P-gp: reduzir dose 50%',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.myelosuppression},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 188 — Febuxostate + Azatioprina (toxicidad fatal)
  ('febuxostate', 'azatioprina',
    InteractionSeverity.contraindicated,
    'Azatioprina é convertida a 6-mercaptopurina (6-MP), que é metabolizada pela xantina oxidase a metabólitos inativos; febuxostate inibe potentemente a xantina oxidase (de forma não competitiva e irreversível), bloqueando a inativação da 6-MP; os níveis de 6-MP aumentam drásticamente com toxicidad hematopoiética grave; mecanismo idêntico ao da interação alopurinol/azatioprina mas com inibição ainda mais completa',
    'Pancitopenia grave, aplasia medular, infecções oportunistas fatais, hepatotoxicidad; mortalidade documentada',
    'Contraindicado. Em pacientes com gota em azatioprina, usar estratégias alternativas de redução do urato: uricosuricos (benzobromarona, probenecida) ou modificação de dose de azatioprina com acompanhamento hematológico. Se febuxostate for indispensável, suspender azatioprina e substituir por outro imunossupressor',
    'CONTRAINDICADO — Febuxostate + Azatioprina: aplasia medular e óbito (como alopurinol)',
    EvidenceLevel.established,
    {RiskType.myelosuppression, RiskType.hepatotoxicity},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 189 — Sulfassalazina + Digoxina (redução de absorção)
  ('sulfassalazina', 'digoxina',
    InteractionSeverity.moderate,
    'Sulfassalazina pode reduzir a absorção intestinal da digoxina em até 25% por mecanismo não completamente esclarecido, possivelmente por interferência na motilidade intestinal ou por complexação no lúmen; a digoxina tem janela terapéutica estreita e qualquer redução de nível pode comprometer a resposta clínica',
    'Redução dos níveis séricos de digoxina com falha no controle da frequência cardíaca em fibrilação atrial ou redução da contratilidade na ICC',
    'Monitorar digoxinemia após início da sulfassalazina. Pode ser necesario aumentar a dose de digoxina em 15–25%. Usar comprimido de liberação lenta (Lanoxicaps) que tem menor interação. Manter intervalo de 2 horas entre as medicações',
    'Absorção reducida de digoxina — Sulfassalazina: monitorar digoxinemia ao iniciar',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),

  // 190 — Hidroxicloroquina + Amiodarona (QT + arritmias)
  ('hidroxicloroquina', 'amiodarona',
    InteractionSeverity.major,
    'Hidroxicloroquina prolonga o QT por bloqueio de canais hERG (IKr); amiodarona prolonga o QT por múltiplos mecanismos; ambos têm meia-vida longa (HCQ: 40–50 dias; amiodarona: 40–55 dias) tornando o efeito cumulativo persistente; combinação frecuente em lúpus com FA ou arritmias',
    'Prolongamento do QTc > 500 ms, torsades de pointes, fibrilação ventricular, morte súbita; toxicidad acumulativa por meia-vida muito longa de ambos',
    'Monitorar ECG antes de iniciar e mensalmente. Manter K+ > 4 mEq/L e Mg++ > 0,8 mEq/L. Se QTc > 480 ms, reduzir dose de HCQ. Se QTc > 500 ms, suspender HCQ e reavaliar esquema. Monitorar visão (HCQ) e tireoide e pulmão (amiodarona) separadamente',
    'QT longo grave — Hidroxicloroquina + Amiodarona: meia-vida longa amplifica risco',
    EvidenceLevel.probable,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefGG, _kRefUT]),


  // ═══════════════════════════════════════════════════════════════
  // BLOCK 8 — Aminoglicosídeos avançados, Laxantes, Anemias,
  // iPCSK9, Hepatite B/C, Antivirais (191–220)
  // ═══════════════════════════════════════════════════════════════

  // 191 — Tobramicina + Cisplatina (ototoxicidad sinérgica)
  ('tobramicina', 'cisplatina',
    InteractionSeverity.major,
    'Tobramicina e cisplatina causam ototoxicidad por mecanismos diferentes mas sinérgicos: tobramicina acumula na cóclea causando lesão das células ciliadas externas via radicais livres; cisplatina causa dano ao estria vascular e células de suporte; a combinação tem efeito aditivo ou sinérgico na perda auditiva permanente',
    'Perda auditiva neurossensorial permanente, especialmente em frequências altas (4.000–8.000 Hz); tinitus; perda de frequências da fala em exposição prolongada; irreversível',
    'Evitar combinación. Se indispensável, realizar audiometria basal e a cada ciclo de cisplatina. Monitorar tinnitus e sintomas de perda auditiva. Usar amikacina como alternativa aminoglicosídeo (menor ototoxicidad cumulativa). Considerar N-acetilcisteína como protetor coclear (evidência limitada)',
    'Ototoxicidad irreversível — Tobramicina + Cisplatina: audiometria obrigatória',
    EvidenceLevel.established,
    {RiskType.ototoxicity},
    [_kRefGG, _kRefUT, _kRefMdx]),

  // 192 — Amikacina + Polimixina B (nefrotoxicidad máxima)
  ('amikacina', 'polimixina_b',
    InteractionSeverity.major,
    'Amikacina e polimixina B causam nefrotoxicidad por mecanismos aditivos: amikacina acumula no córtex renal causando lesão dos túbulos proximais; polimixina B liga-se a fosfolipídios de membrana das células tubulares causando ruptura; a combinação é de extrema necessidade em infecções por gram-negativos MDR mas com nefrotoxicidad cumulativa muito elevada',
    'Insuficiência renal aguda grave, oligúria, necrose tubular aguda; incidência de LRA de 70–80% com a combinação; frecuentemente necessita diálise',
    'Monitorar creatinina diariamente. Dosar amikacina (nível de vale < 5 mcg/mL, pico 20–30 mcg/mL). Dosagem única diária de amikacina reduz nefrotoxicidad. Hidratação agressiva (200 mL/h SF 0,9% durante a infusão de polimixina). Suspender imediatamente se creatinina dobrar em 48 horas',
    'Nefrotoxicidad máxima — Amikacina + Polimixina B: monitorar renal diário rigoroso',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefUT]),

  // 193 — Gentamicina + Relaxantes musculares (bloqueio neuromuscular)
  ('gentamicina', 'vecurônio',
    InteractionSeverity.major,
    'Aminoglicosídeos inibem a liberação de acetilcolina na junção neuromuscular por bloqueio dos canais de cálcio pré-sinápticos e competição com cálcio; bloqueadores neuromusculares não despolarizantes (vecurônio, pancurônio, rocurônio) bloqueiam receptores nicotínicos pós-sinápticos; a combinação causa potenciação do bloqueio neuromuscular com prolongamento significativo da paralisia',
    'Paralisia muscular prolongada pós-operatória, apneia, necessidade de ventilação mecânica por tempo indefinido; risco maior em pacientes com miastenia gravis ou hipocalcemia',
    'Alertar anestesiologista sobre uso de gentamicina em pacientes cirúrgicos. Monitorar bloqueio neuromuscular com estimulador de nervo periférico. Usar anticolinesterásico (neostigmina) para reversão. Evitar aminoglicosídeos em período peri-operatório se possível',
    'Paralisia prolongada — Gentamicina potencializa bloqueadores neuromusculares: alertar anestesia',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression},
    [_kRefGG, _kRefKatz]),

  // 194 — Polietilenoglicol (PEG) + Fármacos de janela estreita oral
  ('polietilenoglicol', 'ciclosporina',
    InteractionSeverity.moderate,
    'Soluções de polietilenoglicol (PEG) para preparo intestinal aumentam intensamente a motilidade intestinal e o trânsito gastrointestinal; fármacos administrados oralmente com baixa absorção intestinal ou que requerem contato prolongado com a mucosa podem ter sua absorção reducida drásticamente; ciclosporina, varfarina, carbamazepina e outros fármacos de janela estreita são especialmente vulneráveis',
    'Absorção drásticamente reducida durante o preparo intestinal; níveis subterapéuticos de ciclosporina com risco de rejeição de transplante; INR instável com varfarina; crisis convulsivas por queda de nível de antiepilépticos',
    'Suspender fármacos de janela estreita oral por 24 horas antes e retomar 2 horas após o término do preparo intestinal. Para ciclosporina: dosar C0 e C2 após o procedimento. Para varfarina: monitorar INR. Para antiepilépticos: monitorar nível',
    'Absorção prejudicada — Laxante PEG + Fármacos de janela estreita: suspender 24h antes',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefUT]),

  // 195 — Bisacodil + Laxantes estimulantes + Diuréticos (hipopotasemia)
  ('bisacodil', 'furosemida',
    InteractionSeverity.moderate,
    'Bisacodil e outros laxantes estimulantes (sena, picossulfato) causam perda de potássio através da mucosa intestinal por aumento da secreção colônica; furosemida causa perda renal de potássio; a combinação tem efeito hipocalêmico aditivo, especialmente em uso crônico de laxantes (abuso em transtornos alimentares, idosos)',
    'Hipocalemia sintomática (K+ < 3,0 mEq/L): fraqueza muscular, cãibras, arritmias, miopatia; possível toxicidad digitálica em pacientes em digoxina; prolongamento do QT',
    'Monitorar K+ sérico mensalmente em uso crônico de laxante + diurético. Suplementar potássio se K+ < 3,5 mEq/L. Preferir laxantes osmóticos (lactulose, PEG) ao invés de estimulantes para uso crônico. Uso crônico de laxantes estimulantes deve ser investigado (transtorno alimentar, síndrome do intestino preguiçoso)',
    'Hipocalemia aditiva — Laxante estimulante + Furosemida: monitorar K+ mensalmente',
    EvidenceLevel.probable,
    {RiskType.hypokalemia, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),

  // 196 — Lactulose + Antibióticos (redução do efeito na encefalopatia)
  ('lactulose', 'rifaximina',
    InteractionSeverity.minor,
    'Lactulose age como acidificante colônico (converte amônia em NH4+, não absorvível) e laxante osmótico, reduzindo a produção e absorção de amônia na encefalopatia hepática; rifaximina reduz as bactérias produtoras de amônia no cólon; a combinação é sinérgica e recomendada em encefalopatia hepática crônica — não há interação adversa',
    'A combinação é benéfica e não causa efeito adverso relevante; rifaximina não é absorvida sistemicamente (< 0,4%), portanto sem interação farmacocinética',
    'Combinação segura e sinérgica para encefalopatia hepática. Monitorar consistência das fezes com lactulose (alvo 2–3 evacuações/dia moles). A rifaximina pode ser adicionada à lactulose em casos de resposta insuficiente',
    'Combinação benéfica — Lactulose + Rifaximina: sinergia na encefalopatia hepática',
    EvidenceLevel.established,
    {RiskType.other},
    [_kRefGG, _kRefUT]),

  // 197 — Sevelâmer + Quinolonas (quelação de absorção)
  ('sevelâmer', 'ciprofloxacino',
    InteractionSeverity.moderate,
    'Sevelâmer (quelante de fósforo) pode ligar-se ao ciprofloxacino no trato gastrointestinal por interação eletrostática (sevelâmer é policatiônico, ciprofloxacino é anfotérico); a quelação pode reduzir a absorção do antibiótico; mecanismo similar ao dos antiácidos com alumínio/magnésio e das quinolonas',
    'Redução das concentrações plasmáticas de ciprofloxacino podendo comprometer eficácia antibiótica, especialmente em infecções graves (bacteremia, osteomielite, infecção do trato urinário por Pseudomonas)',
    'Administrar ciprofloxacino pelo menos 2 horas antes ou 6 horas após o sevelâmer. Em pacientes em hemodiálise onde o controle do fósforo é essencial, ajustar horários de forma a garantir os intervalos necesarios',
    'Absorção reducida — Ciprofloxacino + Sevelâmer: separar 6 horas para eficácia máxima',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),

  // 198 — Eritropoetina (EPO) + Ciclosporina (hipertensão)
  ('eritropoetina', 'ciclosporina',
    InteractionSeverity.moderate,
    'Eritropoetina aumenta a viscosidade sanguínea pela elevação do hematócrito e tem efeito vasoconstritor direto; ciclosporina causa vasoconstrição endotelina-mediada e hipertensão; ambos aumentam resistência vascular periférica; o hematócrito elevado pela EPO pode aumentar a toxicidad nefrológica e cardiovascular da ciclosporina; a ciclosporina pode reduzir a resposta à EPO por toxicidad medular leve',
    'Hipertensão arterial grave resistente ao tratamento (encefalopatia hipertensiva, crise hipertensiva); trombosis de acesso vascular (fístula ou cateter) por hiperviscosidade; possível redução da resposta à EPO',
    'Monitorar PA rigurosamente (alvo < 130/80 mmHg). Titular EPO para hematócrito 30–36% (não > 36%) em transplantados. Monitorar nível de ciclosporina. Considerar anti-hipertensivos como bloqueadores de canal de cálcio (diltiazem — mas cautela com ciclosporina)',
    'Hipertensão grave — Eritropoetina + Ciclosporina: hiperviscosidade + vasoconstrição',
    EvidenceLevel.probable,
    {RiskType.cardiovascular, RiskType.thrombosis},
    [_kRefGG, _kRefUT]),

  // 199 — Darbepoetina + Ferro IV (resposta eritropoética)
  ('darbepoetina', 'ferro_sacarato',
    InteractionSeverity.minor,
    'Darbepoetina (eritropoetina de ação prolongada) requer disponibilidade adecuada de ferro para que a eritropoese seja eficiente; a administração concomitante de ferro IV melhora a resposta eritropoética por fornecer substrato para a síntese de hemoglobina; esta é uma combinação terapéutica benéfica e recomendada em anemia da DRC',
    'Sem toxicidad adicional; a combinação é terapéutica e reduz a dose necessária de darbepoetina; reações de hipersensibilidade ao ferro IV (raras) independem da darbepoetina',
    'Combinação recomendada e sinérgica. Monitorar ferritina (alvo 200–500 ng/mL) e saturação de transferrina (alvo 20–50%). Suspender ferro IV se ferritina > 800 ng/mL. Administrar em dias diferentes para facilitar monitoramento de reações',
    'Sinergia terapéutica — Darbepoetina + Ferro IV: combinação benéfica e recomendada',
    EvidenceLevel.established,
    {RiskType.other},
    [_kRefGG, _kRefFDA]),

  // 200 — Roxadustate + Estatinas (CYP2C9 e OATP)
  ('roxadustate', 'rosuvastatina',
    InteractionSeverity.moderate,
    'Roxadustate inibe o transportador hepático OATP1B1/B3, responsável pela captação hepatocelular da rosuvastatina; a inibição do OATP aumenta os níveis sistêmicos de rosuvastatina em 2–3x; además, roxadustate inibe o CYP2C9, afetando o metabolismo de outros fármacos co-prescritos em IRC',
    'Miopatia por acúmulo de rosuvastatina: mialgia, CK elevada, rabdomiólisis; risco maior em pacientes com IRC avançada (já com risco aumentado de miopatia por uremia)',
    'Reduzir dose de rosuvastatina em 50% ao iniciar roxadustate. Iniciar com 5 mg/dia e avaliar CK mensalmente. Considerar pravastatina (não é substrato OATP1B1) como alternativa com menor interação',
    'Miopatia — Roxadustate inibe OATP: rosuvastatina 2–3x maior, reduzir dose 50%',
    EvidenceLevel.probable,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefFDA, _kRefGG]),

  // 201 — Sofosbuvir + Amiodarona (bradicardia fatal)
  ('sofosbuvir', 'amiodarona',
    InteractionSeverity.contraindicated,
    'Combinação de sofosbuvir com amiodarona causa bradicardia grave, bloqueio AV e paro cardíaco por mecanismo não completamente elucidado — provavelmente relacionado à ação do sofosbuvir nos canais cardíacos de sódio e ao efeito cronotrópico negativo da amiodarona; vários casos fatais foram reportados ao FDA',
    'Bradicardia sintomática (FC < 40 bpm), pausa sinusal, bloqueio AV de grau elevado, asistolia, morte; alguns casos ocorreram em pacientes que haviam descontinuado amiodarona meses antes (meia-vida longa de 40–55 dias)',
    'Contraindicado. Aguardar pelo menos 4 meses após a última dose de amiodarona antes de iniciar regimes contendo sofosbuvir. Se monitoramento for necesario em combinação inadvertida: ECG contínuo em ambiente hospitalar por 48 horas. Usar alternativa (regimes sem sofosbuvir) se disponible',
    'CONTRAINDICADO — Sofosbuvir + Amiodarona: bradicardia fatal documentada, aguardar 4 meses',
    EvidenceLevel.established,
    {RiskType.arrhythmia, RiskType.cardiovascular},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 202 — Ledipasvir + Antiácidos IBP (absorção)
  ('ledipasvir', 'omeprazol',
    InteractionSeverity.major,
    'Ledipasvir requer pH ácido gástrico para dissolução e absorção adecuadas; omeprazol e outros IBP aumentam o pH gástrico para 4–6, reduzindo a solubilidade e absorção do ledipasvir em ~15–35%; o efeito é dose-dependente: omeprazol 20 mg reduz AUC em 14%, doses maiores causam reduções maiores',
    'Redução das concentrações plasmáticas de ledipasvir podendo comprometer a eficácia antiviral, especialmente em pacientes com hepatite C genótipo 1 sem cirrose (que já têm menores reservas à falha terapéutica)',
    'Evitar IBP em doses acima de 20 mg/dia com ledipasvir. Se IBP for indispensável: usar a menor dose possível (omeprazol 20 mg/dia), administrar ledipasvir/sofosbuvir com alimento (aumenta absorção 40%), e se possível tomar IBP à noite e ledipasvir de manhã em jejum',
    'Absorção reducida — Omeprazol >20mg reduz ledipasvir: usar dose mínima de IBP',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 203 — Glecaprevir/Pibrentasvir + Atazanavir (Paxlovid-like)
  ('glecaprevir', 'atazanavir',
    InteractionSeverity.major,
    'Atazanavir é inibidor potente do CYP3A4 e da P-gp; glecaprevir é substrato de ambos; a inibição aumenta os níveis de glecaprevir em 5–7x; pibrentasvir também é afetado; os antivirais para HIV com inibição de CYP3A4/P-gp são contraindicados com regimes contendo inibidores de NS3/NS5A',
    'Toxicidade grave dos DAAs por supraexposição: hepatotoxicidad, elevação de ALT/AST, icterícia, insuficiência hepática aguda',
    'Contraindicado. Aguardar troca ou suspensão do antiviral para HIV antes de iniciar glecaprevir/pibrentasvir. Em coinfectados HIV/HCV, escolher combinação compatível: sofosbuvir/velpatasvir com TARV baseada em raltegravir ou dolutegravir (sem inibição CYP3A4)',
    'CONTRAINDICADO — Glecaprevir + Atazanavir: 5–7x de exposição ao DAA, hepatotoxicidad',
    EvidenceLevel.established,
    {RiskType.hepatotoxicity, RiskType.plasmaLevel},
    [_kRefFDA, _kRefGG]),

  // 204 — Sofosbuvir/Velpatasvir + Rifampicina
  ('velpatasvir', 'rifampicina',
    InteractionSeverity.contraindicated,
    'Rifampicina é potente indutor do CYP3A4, P-gp e UGT1A1, as principais vias de eliminação do velpatasvir (e sofosbuvir); a indução reduz a AUC do velpatasvir em 82% e a do sofosbuvir em 72%; com concentrações tão reducidas, não é possível obter a supressão viral necessária para cura da hepatite C',
    'Falha virológica com concentrações subterapéuticas de ambos os DAAs; risco de seleção de resistência com impacto em regimes futuros de retratamento',
    'Contraindicado. Tratamento da hepatite C deve ser adiado até a conclusão da rifampicina. Se coinfecção TB/HCV necessitar tratamento simultâneo, usar rifabutina (indutor menos potente) ou regimes com sofosbuvir + ledipasvir com ajuste de dose; consultar especialista em infectologia',
    'CONTRAINDICADO — Rifampicina reduz DAAs >80%: falha virológica certa e resistência',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 205 — Entecavir + Metformina (transportador OCT1)
  ('entecavir', 'metformina',
    InteractionSeverity.moderate,
    'Entecavir e metformina compartilham o transportador renal OCT2 e o transportador hepático OCT1 para captação celular; competição pelos mesmos transportadores pode aumentar os niveles plasmáticos de metformina por redução do transporte tubular de secreção',
    'Leve a moderado aumento de metformina podendo precipitar acidose lática em pacientes com IRC subjacente (frecuente na hepatite B com cirrose)',
    'Monitorar función renal e sintomas de acidose lática. Em pacientes com cirrose por hepatite B com redução de TFG (< 45 mL/min), evitar combinação ou usar dose reducida de metformina. Alternativa: usar ISRS2 ou sulfonilurea de curta ação',
    'Risco de acidose lática — Entecavir compete com metformina no transportador OCT: monitorar',
    EvidenceLevel.theoretical,
    {RiskType.other},
    [_kRefGG]),

  // 206 — Tenofovir (TDF) + Antivirais nefrotóxicos
  ('tenofovir', 'cidofovir',
    InteractionSeverity.contraindicated,
    'Tenofovir alafenamida (TAF) e tenofovir disoproxil fumarato (TDF) causam nefrotoxicidad tubular; cidofovir é altamente nefrotóxico por acúmulo nas células tubulares proximais; ambos lesam as células tubulares proximais (toxicidad em S1 e S2 do túbulo proximal), causando síndrome de Fanconi; a combinação multiplica o risco',
    'Síndrome de Fanconi por lesão tubular: hipouricemia, hipofosfatemia, proteinúria tubular, glicosúria normoglicêmica, acidose metabólica hiperclorêmica; insuficiencia renal aguda grave',
    'Contraindicado. Cidofovir requer probenecida IV + hidratação pré-infusão; ainda assim, evitar combinação com tenofovir. Usar ganciclovir ou foscarnet como alternativa para CMV em pacientes em tenofovir',
    'CONTRAINDICADO — Tenofovir + Cidofovir: síndrome de Fanconi e IRA grave',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefFDA]),

  // 207 — Abacavir + Ribavirina (anemia hemolítica)
  ('abacavir', 'ribavirina',
    InteractionSeverity.major,
    'Ribavirina é análogo de nucleosídeo que pode ser fosforilado intracelularmente; os tri-fosfatos de ribavirina competem com os de abacavir (carbovir-TP) pelos transportadores de nucleosídeos e pela incorporação à cadeia de DNA viral; además, a ribavirina causa anemia hemolítica dose-dependente, potencializando o risco em coinfecção HIV/HCV tratada com abacavir',
    'Anemia hemolítica grave (Hb < 8 g/dL), reticulocitose, hiperbilirrubinemia; falha virológica da TARV por redução da eficácia do abacavir pela competição com ribavirina',
    'Evitar combinación em coinfecção HIV/HCV. Preferir tenofovir-based TARV em pacientes em tratamento de HCV com ribavirina. Monitorar hemograma quinzenalmente. Reduzir dose de ribavirina ou transfundir se Hb < 8 g/dL',
    'Anemia grave — Ribavirina + Abacavir: hemólise e redução da eficácia antiviral',
    EvidenceLevel.established,
    {RiskType.myelosuppression},
    [_kRefGG, _kRefUT, _kRefFDA]),

  // 208 — Lamivudina + Sorbitol (absorção oral)
  ('lamivudina', 'sorbitol',
    InteractionSeverity.moderate,
    'Sorbitol (adoçante e excipiente de xaropes e suspensões) reduz significativamente a absorção oral da lamivudina em solução oral; mecanismo: aceleração do trânsito intestinal pelo efeito osmótico do sorbitol; coadministração de 3,2 g de sorbitol reduziu a AUC da lamivudina oral em 20%; doses maiores de sorbitol podem ter impacto maior',
    'Redução das concentrações de lamivudina com risco de concentrações subterapéuticas e possível falha virológica no tratamento de HIV ou hepatite B',
    'Usar formulação em comprimidos (não xarope) de lamivudina sempre que possível. Se solução oral for necessária (pediatria, disfagia), verificar se outros xaropes/medicamentos contêm sorbitol. Administrar lamivudina separada dos medicamentos com sorbitol',
    'Absorção reducida — Sorbitol reduz lamivudina oral 20%: preferir comprimidos',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefFDA]),

  // 209 — Alirocumabe (iPCSK9) + Varfarina
  ('alirocumabe', 'varfarina',
    InteractionSeverity.minor,
    'Alirocumabe (anticorpo monoclonal) não é metabolizado pelo CYP450 e não possui interações farmacocinéticas clinicamente significativas com a varfarina; a combinação é frecuente em pacientes de alto risco cardiovascular com FA ou trombosis em anticoagulação; o risco cardiovascular reducido pelo alirocumabe pode, indiretamente, melhorar a estabilidade do INR ao reduzir a inflamação sistêmica',
    'Sem interação farmacológica direta; reações no local de injeção do alirocumabe não interferem com o INR; raras reações alérgicas generalizadas podem causar instabilidade hemodinâmica',
    'Sem necessidade de ajuste de dose. Combinação segura e clinicamente relevante. Continuar monitoramento habitual do INR. Verificar e tratar fatores que interferem no INR independentemente do alirocumabe',
    'Combinação segura — Alirocumabe + Varfarina: sem interação clinicamente relevante',
    EvidenceLevel.established,
    {RiskType.other},
    [_kRefFDA, _kRefGG]),

  // 210 — Inclisirán (siRNA anti-PCSK9) + Estatinas
  ('inclisiran', 'atorvastatina',
    InteractionSeverity.minor,
    'Inclisirán é um siRNA (RNA de interferência pequeno) que inibe a síntese hepática de PCSK9; não possui interações farmacocinéticas com estatinas (não metabolizado pelo CYP450, injetável SC); a combinação resulta em redução adicional de LDL de 50–55% sobre a estatina, sendo altamente benéfica e recomendada',
    'Sem toxicidad adicional farmacológica; reações no local de injeção (eritema, dor) são os únicos eventos adversos específicos do inclisirán; mialgias das estatinas não são potencializadas pelo inclisirán',
    'Combinação recomendada e altamente eficaz. Dosar LDL-C 3 meses após cada injeção de inclisirán para confirmar resposta. Continuar a estatina em dose máxima tolerada',
    'Combinação recomendada — Inclisirán + Estatina: sinergia no controle do LDL-C',
    EvidenceLevel.established,
    {RiskType.other},
    [_kRefFDA, _kRefGG]),

  // 211 — Finerenona + Itraconazol (CYP3A4 severa)
  ('finerenona', 'itraconazol',
    InteractionSeverity.contraindicated,
    'Finerenona (antagonista seletivo de mineralocorticoides não esteroidal) é metabolizada predominantemente pelo CYP3A4; itraconazol é potente inibidor do CYP3A4; a inibição aumenta a AUC da finerenona em ~12x, causando exposição extremamente elevada',
    'Hipercalemia grave (K+ > 6 mEq/L), hipotensão grave, arritmias cardíacas por hiperpotasemia; a exposição aumentada em 12x é extremamente perigosa',
    'Contraindicado. Usar azóis de menor potência inibitória (fluconazol — cautela, apenas dose única) ou anfotericina tópica. Monitorar K+ e PA urgente se a combinação ocorrer inadvertidamente',
    'CONTRAINDICADO — Itraconazol + Finerenona: exposição 12x maior = hiperpotasemia fatal',
    EvidenceLevel.established,
    {RiskType.hyperkalemia, RiskType.cardiovascular},
    [_kRefFDA, _kRefGG]),

  // 212 — Finerenona + IECA + iSGLT2 (hiperpotasemia tripla)
  ('finerenona', 'enalapril',
    InteractionSeverity.major,
    'Finerenona bloqueia receptores de mineralocorticoides retendo potássio; IECAs reduzem a aldosterona (aumentando K+); iSGLT2 têm efeito natriurético e podem aumentar levemente o potássio por mecanismo renal; a triple therapy tem efeito hipercalêmico aditivo significativo, especialmente em diabetes com DRC (indicação principal de finerenona)',
    'Hipercalemia grave (K+ > 6 mEq/L) com risco de arritmias letais; a combinação de 3 fármacos que aumentam o potássio em pacientes com DRC (TFG < 60) é de alto risco',
    'Monitorar K+ após 4 semanas do início de finerenona com IECA e iSGLT2. Alvo K+ < 5,0 mEq/L antes de iniciar finerenona. Não iniciar se K+ > 5,0 mEq/L. Dieta hipossódica e hipopotássica. Patiromer como quelante de potássio se necesario para permitir o uso da triple therapy',
    'Hipercalemia tripla — Finerenona + IECA + iSGLT2: monitorar K+ em DRC/Diabetes',
    EvidenceLevel.probable,
    {RiskType.hyperkalemia},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 213 — Mavacamten + Verapamil (disfunção sistólica sinérgica)
  ('mavacamten', 'verapamil',
    InteractionSeverity.major,
    'Mavacamten é inibidor seletivo de miosina cardíaca, reduzindo a contratilidade miocárdica para tratar obstrução na miocardiopatia hipertrófica obstrutiva (MHCO); verapamil reduz a contratilidade (efeito inotrópico negativo) e a frequência cardíaca; a combinação causa redução sinérgica da função sistólica com risco de descompensação cardíaca grave',
    'Descompensação de insuficiencia cardíaca aguda, redução grave da fração de ejeção (FE < 50%), edema pulmonar agudo; hipotensão, síncope',
    'Contraindicado com mavacamten. Verapamil é frecuentemente usado na MHCO como alternativa ao beta-bloqueador — substituir por beta-bloqueador cardioselective (metoprolol, bisoprolol) ao iniciar mavacamten. Monitorar ecocardiograma a cada 4–6 semanas',
    'Disfunção cardíaca grave — Mavacamten + Verapamil: inotrópico negativo sinérgico',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    [_kRefFDA, _kRefGG]),

  // 214 — Sacubitrila/Valsartana + Diuréticos (hipovolemia)
  ('sacubitrila', 'hidroclorotiazida',
    InteractionSeverity.moderate,
    'Sacubitrila/valsartana inibe a neprilisina e o receptor AT1, causando natriurese e vasodilatação (redução de pré e pós-carga); tiazídicos e diuréticos de alça adicionam efeito natriurético e diurético; a combinação pode causar depleção de volume excessiva, especialmente ao iniciar sacubitrila em pacientes já em diuréticos de alça',
    'Hipotensão sintomática, tontura, síncope, insuficiencia renal pré-renal, hipopotasemia',
    'Reduzir dose de diurético de alça em 25–50% antes de iniciar sacubitrila/valsartana. Monitorar PA, función renal e electrolitos nas primeiras 2–4 semanas. Titular sacubitrila lentamente. A diurese é, em parte, desejável na ICC com congestão',
    'Hipovolemia — Sacubitrila/Valsartana + Diuréticos: reduzir diurético ao iniciar Entresto',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.electrolyte},
    [_kRefGG, _kRefFDA, _kRefUT]),

  // 215 — Empagliflozina + Acetazolamida (cetoacidose)
  ('empagliflozina', 'acetazolamida',
    InteractionSeverity.major,
    'iSGLT2 promovem glicosúria e podem causar cetoacidose diabética euglicêmica (CAD-E) por aumento da cetogênese; acetazolamida inibe a anidrase carbônica, causando acidose metabólica hiperclorêmica (tipo 2); a combinação de dois mecanismos de acidose metabólica pode precipitar acidose grave',
    'Cetoacidose diabética euglicêmica grave, acidose metabólica mista (lática + cetótica + hiperclorêmica); confusão mental, taquipneia, vômitos, colapso hemodinâmico',
    'Evitar combinación. Se acetazolamida for necessária (glaucoma, altitude), suspender iSGLT2 48–72 horas antes. Monitorar cetonas urinárias/sanguíneas e pH. Dieta pobre em carboidratos é fator de risco adicional para CAD-E',
    'CAD euglicêmica — iSGLT2 + Acetazolamida: duas acidoses metabólicas simultâneas',
    EvidenceLevel.probable,
    {RiskType.other},
    [_kRefGG, _kRefFDA]),

  // 216 — Ozempic (semaglutida) + Antiepilépticos (absorção oral)
  ('semaglutida', 'lamotrigina',
    InteractionSeverity.moderate,
    'Semaglutida oral (Rybelsus) requer pH gástrico ácido e absorção muito específica (tomada em jejum, 30 min antes de qualquer alimento/bebida); qualquer fármaco que aumente o pH gástrico ou a motilidade pode reduzir sua absorção; lamotrigina oral tem absorção duodenal e o retardo do esvaziamento gástrico pela semaglutida SC pode reduzir a absorção de lamotrigina',
    'Para semaglutida oral: falha do efeito hipoglucemiante por absorção inadecuada; para semaglutida SC: retardo na absorção da lamotrigina com pico mais lento e possível redução do nível no estado de equilíbrio (< 15% para a maioria dos antiepilépticos)',
    'Para semaglutida oral: tomar sempre em jejum, 30 min antes de qualquer outro medicamento. Para semaglutida SC: monitorar nível de lamotrigina se houver perda de controle de crises. A interação é geralmente de magnitude pequena',
    'Absorção leve reducida — Semaglutida + Antiepilépticos orais: tomar lamotrigina após 30 min',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefFDA]),

  // 217 — Tirzepatida + Contraceptivos orais (absorção)
  ('tirzepatida', 'etinilestradiol',
    InteractionSeverity.moderate,
    'Tirzepatida (agonista dual GIP/GLP-1) retarda significativamente o esvaziamento gástrico; contraceptivos orais combinados têm absorção intestinal que pode ser prejudicada pelo retardo gástrico; o estudo SURPASS-4 demonstrou redução do Cmax do etinilestradiol em 33% e da noretindrona em 13% quando administrados 30 min após tirzepatida',
    'Possível redução da concentração máxima de esteroides sexuais com risco de falha contraceptiva, especialmente nas primeiras semanas de uso de tirzepatida quando o efeito no esvaziamento gástrico é mais pronunciado',
    'Para as primeiras 4 semanas de tirzepatida e após cada aumento de dose: usar método contraceptivo adicional (preservativo). Administrar contraceptivo oral com 30 min de antecedência à refeição e separado da tirzepatida. A interação é mais pronunciada durante as primeiras 4 semanas',
    'Falha contraceptiva potencial — Tirzepatida retarda absorção de COC: usar preservativo nas 4 primeiras semanas',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefFDA, _kRefGG]),

  // 218 — Naltrexona + Opioides (bloqueio e precipitação de abstinência)
  ('naltrexona', 'morfina',
    InteractionSeverity.contraindicated,
    'Naltrexona é antagonista puro de receptores opioides (mu, kappa, delta) com alta afinidade e longa duração de ação; em pacientes dependentes de opioides, a naltrexona precipita síndrome de abstinência aguda grave; mesmo em pacientes não-dependentes, bloqueia completamente o efeito analgésico dos opioides',
    'Síndrome de abstinência precipitada em dependentes: diaforese, tremor, ansiedade extrema, vômitos, mialgias, hipertensão, taquicardia, possível colapso; bloqueio analgésico completo em situações de dor aguda',
    'Contraindicado em pacientes com dependência de opioides (aguardar 7–10 dias de abstinência completa antes de iniciar naltrexona). Em emergências analgésicas com paciente em naltrexona: opioides em doses extremamente altas podem superar o bloqueio com risco de depresión respiratoria; preferir analgesia regional ou AINEs',
    'CONTRAINDICADO em dependentes — Naltrexona + Opioides: abstinência precipitada ou sem analgesia',
    EvidenceLevel.established,
    {RiskType.other, RiskType.cns},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 219 — Buprenorfina + Benzodiazepínicos (depresión respiratoria)
  ('buprenorfina', 'diazepam',
    InteractionSeverity.major,
    'Buprenorfina é agonista parcial de receptores mu-opioides e antagonista kappa; benzodiazepínicos potencializam a depressão do SNC via receptores GABA-A; a combinação causa depresión respiratoria sinérgica, especialmente em doses elevadas de BZD e em pacientes não tolerantes a opioides; cases fatais documentados, especialmente por via IV de buprenorfina com BZD injetável',
    'Depressão respiratória grave, hipóxia, coma, morte; o risco é maior com benzodiazepínicos de alta potência (flunitrazepam, triazolam) ou IV',
    'Usar com extrema cautela. A combinação é às vezes necessária em manejo da dor (buprenorfina + BZD ansiolítico). Preferir BZD de menor potência e menor dose. Orientar paciente sobre proibição de automedicação adicional de BZD. Naloxona reverte parcialmente a buprenorfina (agonismo parcial é difícil de reverter)',
    'Morte respiratória — Buprenorfina + Benzodiazepínico: depresión respiratoria sinérgica',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 220 — Metadona + Fluconazol (QT + CYP3A4/CYP2C19)
  ('metadona', 'fluconazol',
    InteractionSeverity.major,
    'Metadona prolonga o QT por bloqueio de canais hERG (IKr); fluconazol inibe o CYP3A4 e CYP2C19, principais enzimas de metabolismo da metadona, aumentando seus níveis em 35–50%; combinação de aumento das concentrações (PK) + efeito direto no QT (PD) da metadona resulta em risco substancial de torsades de pointes',
    'QTc > 500 ms, torsades de pointes, fibrilação ventricular, morte súbita; o risco é maior nos primeiros dias de fluconazol (antes da nova steady-state da metadona)',
    'Monitorar ECG antes e 3–5 dias após início do fluconazol. Reduzir dose de metadona em 15–20% preventivamente. Preferir nistatina tópica ou fluconazol em dose única (menor impacto no QT) para candidíase oral. Em candidíase sistêmica: micafungina ou anidulafungina como alternativas sistêmicas sem interação CYP',
    'QT grave + níveis de metadona aumentados — Fluconazol + Metadona: monitorar ECG urgente',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.plasmaLevel},
    [_kRefGG, _kRefUT, _kRefFDA]),


  // ═══════════════════════════════════════════════════════════════
  // BLOCK 9 — Psiquiatria avançada, Neurologia, Respiratório (221–250)
  // ═══════════════════════════════════════════════════════════════

  // 221 — Clozapina + Ácido Valpróico (sedação + convulsiones paradoxais)
  ('clozapina', 'valproato',
    InteractionSeverity.moderate,
    'A combinação de clozapina com valproato é paradoxalmente arriscada: ambos têm ação GABAérgica e sedativa aditiva; valproato pode inibir o CYP2D6 e a glucuronidação, aumentando os níveis de clozapina em 15–40%; además, altas doses de clozapina diminuem o limiar convulsivo e valproato pode ter efeito protetor parcial mas insuficiente; casos de convulsiones com a combinação são reportados',
    'Sedación excesiva, depresión respiratoria, convulsiones paradoxais em doses altas de clozapina (> 600 mg/dia); prolongamento do QT pela soma dos efeitos; hipotensão ortostática grave',
    'Monitorar nível de clozapina (alvo 350–600 ng/mL) ao iniciar valproato. Monitorar ECG. Em pacientes em risco de convulsiones por clozapina (doses altas, perda rápida de peso, hiponatremia), usar lamotrigina ou levetiracetam em vez de valproato como anticonvulsivante adjunto',
    'Sedação e convulsiones paradoxais — Clozapina + Valproato: monitorar nível de clozapina',
    EvidenceLevel.probable,
    {RiskType.cns, RiskType.seizure},
    [_kRefGG, _kRefUT]),

  // 222 — Aripiprazol + CYP2D6 inibidores (bupropiona)
  ('aripiprazol', 'bupropiona',
    InteractionSeverity.moderate,
    'Bupropiona é inibidor potente do CYP2D6; aripiprazol é metabolizado principalmente pelo CYP2D6 (e CYP3A4); a inibição do CYP2D6 pela bupropiona aumenta os níveis de aripiprazol em 2–3x, aumentando o risco de efeitos adversos; bupropiona per se também tem propriedades dopaminérgicas/noradrenérgicas que podem interagir com aripiprazol dopaminérgico',
    'Toxicidade por aripiprazol: acatisia intensa, insônia, ansiedade, taquicardia, tontura; possível piora de sintomas psicóticos por estimulação dopaminérgica excessiva',
    'Monitorar efeitos adversos de aripiprazol ao iniciar bupropiona. Reduzir dose de aripiprazol em 50% (ex: de 15 mg para 10 mg/dia) se combinação for necessária. Ao suspender bupropiona, restaurar dose original de aripiprazol monitorando eficácia',
    'Toxicidade de aripiprazol — Bupropiona inibe CYP2D6: reduzir dose de aripiprazol 50%',
    EvidenceLevel.probable,
    {RiskType.cns, RiskType.plasmaLevel},
    [_kRefGG, _kRefUT]),

  // 223 — Olanzapina + Tabaco (indução CYP1A2)
  ('olanzapina', 'tabaco',
    InteractionSeverity.moderate,
    'O tabaco contém hidrocarbonetos policíclicos aromáticos (HPA) que são potentes indutores do CYP1A2 (não a nicotina em si); olanzapina é metabolizada principalmente pelo CYP1A2; fumantes têm níveis de olanzapina 30–50% menores que não-fumantes pela inducción enzimática; ao cessar o tabagismo (hospitalizações, internações psiquiátricas), os níveis de olanzapina aumentam rapidamente',
    'Em fumantes: níveis subterapéuticos com necessidade de doses maiores; ao parar de fumar (internação): aumento abrupto de níveis com toxicidad (sedação, ganho de peso, síndrome metabólica); o risco é inverso — ao cessar, os níveis sobem',
    'Informar paciente e equipe sobre esta interação ao hospitalizar fumantes. Monitorar nível de olanzapina durante internação (pode precisar reduzir dose 25–30% ao parar de fumar). Ao retornar ao fumo após internação: restaurar dose mais alta anterior com monitoramento de eficácia',
    'Nível de olanzapina 30–50% menor em fumantes — Ao cessar tabagismo: reduzir dose urgente',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.cns},
    [_kRefGG, _kRefKatz, _kRefMdx]),

  // 224 — Paliperidona + Carbamazepina (CYP3A4 + P-gp indução)
  ('paliperidona', 'carbamazepina',
    InteractionSeverity.major,
    'Carbamazepina induz o CYP3A4 e a P-gp (glicoproteína-P); paliperidona é substrato da P-gp e parcialmente do CYP3A4; a indução da P-gp pela carbamazepina reduz os níveis de paliperidona em 37% (estudo de bula); a carbamazepina também reduz os níveis de outras antipsicóticos metabolizados pelo CYP',
    'Concentrações subterapéuticas de paliperidona com risco de recaída psicótica, descompensação de esquizofrenia, hospitalização psiquiátrica',
    'Evitar combinación se possível. Se antiepiléptico for necesario em esquizofrenia, preferir lamotrigina, levetiracetam ou ácido valpróico (menor interação com paliperidona). Se a combinação for indispensável, pode ser necesario aumentar dose de paliperidona e monitorar nivel sérico',
    'Falha antipsicótica — Carbamazepina reduz paliperidona 37%: trocar antiepiléptico',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefFDA]),

  // 225 — Quetiapina + Fenitoína (CYP3A4 indução)
  ('quetiapina', 'fenitoina',
    InteractionSeverity.major,
    'Fenitoína induz o CYP3A4, principal via de metabolismo da quetiapina; a indução reduz os níveis de quetiapina em 80% (5x de redução na AUC), tornando a dose habitual totalmente ineficaz; fenitoína é um dos mais potentes indutores do CYP3A4 conhecidos',
    'Falha terapéutica quase certa da quetiapina com recaída psicótica ou maníaca grave; necessidade de doses extremamente altas (5x acima do habitual) para manter eficácia',
    'Contraindicação relativa — evitar. Substituir fenitoína por levetiracetam ou lamotrigina. Se a combinação for indispensável, doses de quetiapina de 1.500–2.000 mg/dia podem ser necessárias (monitoramento clínico rigoroso). Ao suspender fenitoína: reduzir quetiapina imediatamente para evitar toxicidad',
    'FALHA TERAPÊUTICA — Fenitoína reduz quetiapina 80%: trocar antiepiléptico urgente',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefUT]),

  // 226 — Lítio + Carbamazepina (toxicidad do SNC)
  ('litio', 'carbamazepina',
    InteractionSeverity.major,
    'A combinação de lítio com carbamazepina pode causar toxicidad neurológica sinérgica mesmo com concentrações séricas de ambos dentro dos limites terapéuticos; carbamazepina pode aumentar a excreção de sódio, aumentando indiretamente os níveis de lítio; ambos têm mecanismos complexos de ação no SNC que se sobrepõem em populações de canais iônicos',
    'Síndrome neurotóxica: tremor, ataxia, nistagmo, confusão mental, sintomas cerebelares, convulsiones; o efeito pode ocorrer com litemias aparentemente normais (1,0–1,2 mEq/L)',
    'Monitorar clinicamente e com litemia e nível de carbamazepina. Manter litemia no limite inferior do terapéutico (0,6–0,8 mEq/L) quando em combinação. Hidratação adecuada. Monitorar sódio sérico',
    'Toxicidade neurológica sinérgica — Lítio + Carbamazepina: mesmo com níveis normais',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.seizure},
    [_kRefGG, _kRefKatz]),

  // 227 — Lamotrigina + Anticoncepcionais orais (indução UGT)
  ('lamotrigina', 'etinilestradiol',
    InteractionSeverity.major,
    'Anticoncepcionais orais contendo etinilestradiol induzem a glucuronidação (UGT1A4) da lamotrigina, aumentando seu metabolismo e reduzindo seus níveis em 40–60%; inversamente, ao suspender o anticoncepcional (semana de pausa dos pílulas combinadas ou ao descontinuar), os níveis de lamotrigina sobem abruptamente em 40–60%, causando toxicidad',
    'Durante o uso do COC: concentrações subterapéuticas de lamotrigina com risco de crisis convulsivas; durante a semana de pausa da pílula: pico tóxico de lamotrigina (diplopia, ataxia, tontura, vômitos); ao suspender COC definitivamente: toxicidad de lamotrigina',
    'Monitorar nível de lamotrigina ao iniciar/suspender COC. Pode ser necesario aumentar dose de lamotrigina em 50% ao iniciar COC. Reduzir a dose ao suspender COC. Durante semana de pausa: informar paciente sobre possíveis efeitos; considerar pílulas sem pausa (uso contínuo)',
    'Crises epilépticas e toxicidad bidirecional — COC + Lamotrigina: monitorar nível ao iniciar/suspender',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.seizure},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 228 — Levetiracetam + Metronidazol
  ('levetiracetam', 'metronidazol',
    InteractionSeverity.moderate,
    'Metronidazol pode potencializar os efeitos neurológicos do levetiracetam; ambos têm propriedades neuromodulatórias; metronidazol pode causar encefalopatia, especialmente em uso prolongado ou em pacientes com insuficiência hepática; a combinação soma efeitos neurológicos adversos',
    'Confusão mental, sonolência excessiva, ataxia, psicose; encefalopatia por metronidazol pode ser confundida com ajuste inadecuado do levetiracetam',
    'Monitorar cuidadosamente sinais neurológicos durante combinação. Limitar uso de metronidazol a cursos curtos (< 14 dias). Em encefalites ou infecções de SNC, monitorar EEG e nível de levetiracetam se piora neurológica',
    'Toxicidade neurológica aditiva — Levetiracetam + Metronidazol: monitorar estado mental',
    EvidenceLevel.possible,
    {RiskType.cns},
    [_kRefGG]),

  // 229 — Duloxetina + Tamoxifeno (inibição CYP2D6)
  ('duloxetina', 'tamoxifeno',
    InteractionSeverity.major,
    'Duloxetina é inibidor moderado a potente do CYP2D6; tamoxifeno requer ativação pelo CYP2D6 ao seu metabólito ativo endoxifeno (4–10x mais potente que o tamoxifeno original); a inibição do CYP2D6 pela duloxetina reduz os níveis de endoxifeno em 50–70%, comprometendo a eficácia antiestrogênica do tamoxifeno no câncer de mama',
    'Reducción de la eficacia do tamoxifeno no câncer de mama dependente de estrogênio; aumento do risco de recorrência do câncer de mama em pacientes em uso concomitante de ISRS/IRSNa fortes inibidores do CYP2D6',
    'Evitar duloxetina (e outros fortes inibidores de CYP2D6: paroxetina, fluoxetina, bupropiona) em pacientes em tamoxifeno. Usar antidepressivos/ansiolíticos com menor inibição de CYP2D6 para sintomas menopausais e depressão: venlafaxina, escitalopram, citalopram, mirtazapina',
    'Recorrência de câncer de mama — Duloxetina inibe CYP2D6: endoxifeno reducido 50–70%',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 230 — Venlafaxina + Tramadol (síndrome serotoninérgica)
  ('venlafaxina', 'tramadol',
    InteractionSeverity.major,
    'Venlafaxina é inibidor da recaptação de serotonina e noradrenalina (IRSNA); tramadol inibe a recaptação de serotonina e noradrenalina além de atuar em receptores mu-opioides; a combinação potencia a atividade serotoninérgica sinapticamente com risco de síndrome serotoninérgica, especialmente em doses altas ou em metabolizadores lentos do CYP2D6 (que acumulam tramadol)',
    'Síndrome serotoninérgica: tremor fino, agitação, diarreia, hiperreflexia, mioclonias, diaforese, hipertermia, taquicardia; pode progredir para convulsiones, rabdomiólisis e insuficiência de múltiplos órgãos',
    'Usar com cautela. Preferir opioides sem atividade serotoninérgica (morfina, oxicodona, hidromorfona) em pacientes em venlafaxina. Se tramadol for necesario, usar dose mínima por período curto com monitoramento de sintomas serotoninérgicos. Criptoimidazol como antídoto parcial se toxicidad grave',
    'Síndrome serotoninérgica — Venlafaxina + Tramadol: preferir morfina como opioide',
    EvidenceLevel.established,
    {RiskType.serotonin, RiskType.cns},
    [_kRefGG, _kRefMdx, _kRefUT]),

  // 231 — Sertralina + Piroxicam/AINE (sangrado GI)
  ('sertralina', 'piroxicam',
    InteractionSeverity.major,
    'ISRS reduzem a função plaquetária ao depletar as reservas de serotonina das plaquetas (que dependem do transportador SERT para captação de serotonina e armazenamento nos grânulos densos); AINEs inibem a COX-1 plaquetária, reduzindo a síntese de tromboxano A2; ambos prejudicam a hemostasia primária por mecanismos diferentes; efeito sinérgico no risco hemorrágico gastrointestinal',
    'Sangramento gastrointestinal superior (úlcera, erosão gástrica, gastrite hemorrágica); risco aumentado de 7–15x em comparação com uso isolado de AINE; hemorragia digestiva alta potencialmente grave',
    'Preferir paracetamol para dor em pacientes em ISRS. Se AINE for necesario, usar proteção gástrica com IBP (omeprazol 20 mg/dia). Considerar ISRS com menor atividade antiplaquetária (citalopram). Monitorar fezes e HB em uso crônico',
    'Sangramento GI 7–15x maior — ISRS + AINE: usar IBP obligatorio se combinação necessária',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefKatz, _kRefMdx]),

  // 232 — Mirtazapina + Álcool (sedação extrema)
  ('mirtazapina', 'alcool',
    InteractionSeverity.major,
    'Mirtazapina tem potente efeito sedativo via antagonismo dos receptores H1-histaminérgicos e alfa-2 adrenérgicos; o álcool potencializa a depressão do SNC de forma sinérgica; a combinação causa sedação extrema desproporcional ao consumo de álcool; mirtazapina nas doses mais baixas (7,5–15 mg) é mais sedativa que em doses altas',
    'Sedação extrema com comprometimento psicomotor grave, depresión respiratoria em doses elevadas de álcool, hipotensão, amnésia anterógrada; risco de acidentes automobilísticos e quedas',
    'Orientar abstinência alcoólica durante tratamento com mirtazapina. Se o paciente beber, não operar veículos ou máquinas. Contra-indicação relativa em alcoólatras ativos. Monitorar função hepática (mirtazapina tem metabolismo hepático)',
    'Sedação extrema — Mirtazapina + Álcool: depressão do SNC sinérgica, evitar dirigir',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.respiratoryDepression},
    [_kRefGG, _kRefMdx]),

  // 233 — Quetiapina + Succo de toranja/Grapefruit (CYP3A4 intestinal)
  ('quetiapina', 'grapefruit',
    InteractionSeverity.major,
    'O suco de toranja contém furanocumarinas (bergamotina, 6,7-diidroxibergamotina) que inibem irreversivelmente o CYP3A4 intestinal; quetiapina tem extensa metabolização de primeira passagem pelo CYP3A4 intestinal; o suco de toranja pode aumentar a biodisponibilidade da quetiapina em 50–100%, dobrando os niveles plasmáticos com um único copo de 200 mL',
    'Hipotensão ortostática grave, sedação extrema, prolongamento do QT por supraexposição à quetiapina; risco de síncope e torsades de pointes',
    'Orientar evitar suco de toranja e frutas cítricas tipo grapefruit durante tratamento com quetiapina (e outros antipsicóticos e BZD metabolizados pelo CYP3A4). Laranja comum é segura. Suco de laranja-bahia/pomelo também tem risco',
    'Níveis dobram — Suco de toranja + Quetiapina: inibição CYP3A4 intestinal, hipotensão e QT',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.qtProlongation},
    [_kRefGG, _kRefMdx]),

  // 234 — Dupilumabe (biológico anti-IL4/13) + Vacinas vivas
  ('dupilumabe', 'vacina_viva',
    InteractionSeverity.moderate,
    'Dupilumabe bloqueia o receptor da IL-4 e IL-13, comprometendo a imunidade do tipo Th2; diferentemente dos imunossupressores clássicos e anti-TNF, o dupilumabe não compromete significativamente a imunidade celular Th1 e a resposta a vacinas vivas; o risco é teórico e menor que com biológicos anti-TNF, mas ainda presente',
    'Risco teórico de doença disseminada pela cepa vacinal em imunocompromissão Th2 grave; na prática, menos casos reportados que com anti-TNF',
    'Precaução — não contraindicação absoluta. Vacinar preferencialmente antes de iniciar dupilumabe. Se necesario vacinar durante o tratamento, discutir com especialista. Vacinas inativadas são seguras e recomendadas (influenza, pneumocócica)',
    'Precaução — Dupilumabe + vacinas vivas: menor risco que anti-TNF, mas preferir vacinar antes',
    EvidenceLevel.possible,
    {RiskType.infection},
    [_kRefFDA, _kRefGG]),

  // 235 — Mepolizumabe (anti-IL5) + Corticoides (retirada)
  ('mepolizumabe', 'prednisona',
    InteractionSeverity.moderate,
    'Mepolizumabe (anticorpo anti-IL-5) reduz a inflamação eosinofílica na asma grave, podendo permitir a redução gradual dos corticoides orais; ao iniciar mepolizumabe em pacientes com asma grave corticoidedependente, há possibilidade de reduzir e eventualmente suspender os corticoides; a retirada rápida de corticoides pode desmascarar insuficiencia adrenal por supressão prévia do eixo HPA',
    'Insuficiência adrenal aguda durante a retirada de corticoides: fadiga intensa, hipotensão, hipoglucemia, hiponatremia, colapso hemodinâmico; síndrome de Churg-Strauss (vasculite eosinofílica) ao reduzir corticoides em alguns pacientes com eosinofilia grave',
    'Redução dos corticoides deve ser lenta e gradual (10% da dose a cada 4 semanas) após início do mepolizumabe. Monitorar eosinófilos e função adrenal (cortisol basal). Reconhecer sinais de insuficiencia adrenal. Considerar teste de estimulação com ACTH antes de suspender corticoide',
    'Insuficiência adrenal — Retirada de corticoide ao iniciar mepolizumabe: fazer gradualmente',
    EvidenceLevel.established,
    {RiskType.other},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 236 — Omalizumabe (anti-IgE) + Beta-agonistas
  ('omalizumabe', 'indacaterol',
    InteractionSeverity.minor,
    'Omalizumabe (anti-IgE) não tem interações farmacocinéticas com LABAs; a combinação é terapéutica e frecuente em asma grave não controlada; omalizumabe reduz a resposta inflamatória mediada por IgE enquanto o LABA causa broncodilatação direta; a combinação é tanto segura quanto clinicamente benéfica e recomendada pelas diretrizes de asma',
    'Sem efeito adverso adicional farmacológico relevante; reações locais à injeção de omalizumabe (eritema, edema) independem do LABA',
    'Combinação segura e recomendada nas diretrizes GINA para asma grave. Monitorar eosinófilos, IgE sérica e função pulmonar para avaliar resposta ao omalizumabe. Manter LABA para controle sintomático',
    'Combinação segura e recomendada — Omalizumabe + LABA: sinergia na asma grave',
    EvidenceLevel.established,
    {RiskType.other},
    [_kRefGG, _kRefFDA]),

  // 237 — Tezepelumabe (anti-TSLP) + Corticoides inalatórios
  ('tezepelumabe', 'budesonida',
    InteractionSeverity.minor,
    'Tezepelumabe (anticorpo anti-TSLP) não possui interações farmacocinéticas com corticoides inalatórios; a combinação é a base do tratamento da asma grave eosinofílica ou do tipo 2 e é a combinação padrão nos estudos (NAVIGATOR trial); tezepelumabe reduz exacerbações e permite redução da dose de corticoide inalatório em muitos pacientes',
    'Sem toxicidad adicional pela combinação; a redução progressiva do corticoide inalatório ao longo do tempo com tezepelumabe é desejável mas deve ser gradual',
    'Combinação terapéutica recomendada. Após 6–12 meses de boa resposta ao tezepelumabe, considerar reduzir gradualmente o corticoide inalatório para a menor dose eficaz. Monitorar eosinófilos e FeNO como biomarcadores de resposta',
    'Combinação terapéutica — Tezepelumabe + Corticoide inalatório: permite redução do CI',
    EvidenceLevel.established,
    {RiskType.other},
    [_kRefFDA, _kRefGG]),

  // 238 — Aclidínio (LAMA) + Anticolinérgicos sistêmicos (somação)
  ('aclidinio', 'solifenacina',
    InteractionSeverity.moderate,
    'Aclidínio é LAMA (antagonista muscarínico de ação prolongada) para DPOC com ação predominantemente pulmonar (alta afinidade por M3); solifenacina é anticolinérgico para bexiga hiperativa com ação periférica sistêmica; ambos bloqueiam receptores muscarínicos M2/M3 causando efeitos anticolinérgicos sistêmicos somados quando usados simultaneamente',
    'Retenção urinária (especialmente em HPB), constipação intestinal grave, taquicardia, boca seca intensa, visão turva, confusão mental (idosos), glaucoma de ângulo fechado; "carga anticolinérgica" elevada com risco de síndromes anticolinérgicas',
    'Avaliar necessidade clínica de ambos. Em idosos, usar escala de carga anticolinérgica. Preferir LAMA para DPOC e terapias alternativas para bexiga hiperativa (fisioterapia pélvica, betanecol, mirabegron que é beta-3 agonista sem anticolinérgio)',
    'Carga anticolinérgica elevada — LAMA + Anticolinérgico sistêmico: risco em idosos',
    EvidenceLevel.probable,
    {RiskType.other, RiskType.cns},
    [_kRefGG, _kRefKatz]),

  // 239 — Sildenafila (HAP) + Riociguate (hipertensão pulmonar)
  ('sildenafila', 'riociguate',
    InteractionSeverity.contraindicated,
    'Sildenafila inibe a PDE-5, aumentando o GMPc e causando vasodilatação pulmonar; riociguate estimula diretamente a guanilato ciclase solúvel, também aumentando o GMPc; ambos aumentam o GMPc por mecanismos diferentes (complementares) mas o efeito vasodilatador combinado é extremamente potente, causando hipotensão grave que não responde ao tratamento convencional',
    'Hipotensão grave e refratária (PA < 60/40 mmHg), síncope, colapso hemodinâmico, morte; a interação foi motivo de contraindicação formal pela FDA e EMA',
    'Contraindicado. Aguardar 24 horas após suspensão de sildenafila antes de iniciar riociguate (y viceversa). Em hipertensão arterial pulmonar refratária, escolher um mecanismo por vez. Não combinar qualquer inibidor de PDE-5 com riociguate',
    'CONTRAINDICADO — Sildenafila + Riociguate: hipotensão fatal por GMPc excessivo',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    [_kRefFDA, _kRefGG]),

  // 240 — Pirfenidona + Fluvoxamina (CYP1A2 inibição)
  ('pirfenidona', 'fluvoxamina',
    InteractionSeverity.major,
    'Pirfenidona (antifibrótico para fibrose pulmonar idiopática) é metabolizada principalmente pelo CYP1A2; fluvoxamina é potente inibidor do CYP1A2; a inibição aumenta os niveles plasmáticos de pirfenidona em ~4x, causando exposição muito elevada',
    'Toxicidade grave da pirfenidona: náuseas, vômitos, anorexia, fotossensibilidade grave, hepatotoxicidad, tontura; os efeitos adversos são dose-dependentes e muito frecuentes com níveis 4x maiores',
    'Contraindicado com fluvoxamina. Usar antidepressivos sem inibição CYP1A2 (escitalopram, sertralina, mirtazapina). Também evitar ciprofloxacino, mexiletina e enoxacino em usuários de pirfenidona. O tabagismo induz CYP1A2 e reduz a eficácia da pirfenidona',
    'Toxicidade grave de pirfenidona — Fluvoxamina inibe CYP1A2: 4x de exposição',
    EvidenceLevel.established,
    {RiskType.hepatotoxicity, RiskType.plasmaLevel},
    [_kRefFDA, _kRefGG]),

  // 241 — Nintedanibe + Rifampicina (CYP3A4 e P-gp)
  ('nintedanibe', 'rifampicina',
    InteractionSeverity.major,
    'Nintedanibe (inibidor de tirosina quinase para FPI) é substrato do CYP3A4 e da P-gp; rifampicina induz ambos; a coadministração reduz a AUC do nintedanibe em 50% e o Cmax em 60%; com concentrações tão reducidas, a eficácia antifibrótica é comprometida',
    'Falha terapéutica do nintedanibe com progressão da fibrose pulmonar; deterioração da função pulmonar (CVF, DLCO) por concentrações subterapéuticas',
    'Evitar combinación. Se antituberculoso for necesario (coinfecção TB/FPI), considerar substituição do nintedanibe durante o tratamento de TB, retomando após. Monitorar CVF a cada 3 meses. Não há alternativa com dose ajustada validada',
    'Falha antifibrótica — Rifampicina reduz nintedanibe 50%: progressão da FPI',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy},
    [_kRefFDA, _kRefGG]),

  // 242 — Bosentana + Ciclosporina (inibição e indução mútua)
  ('bosentana', 'ciclosporina',
    InteractionSeverity.contraindicated,
    'Bosentana (antagonista de receptor de endotelina para HAP) induz o CYP3A4 e CYP2C9, reduzindo os níveis de ciclosporina em 50%; simultaneamente, ciclosporina inibe o transportador de captação hepática (OATP1B1/B3) de bosentana, aumentando os níveis de bosentana em 30x; o efeito líquido é toxicidad grave de bosentana com hepatotoxicidad e falha do imunossupressor',
    'Hepatotoxicidad grave por acúmulo de bosentana (30x de aumento); rejeição de órgão transplantado por queda dos níveis de ciclosporina; insuficiência hepática aguda',
    'Contraindicado. Em transplantados com HAP, usar riociguate ou prostanoides (epoprostenol, iloprost) que não têm esta interação crítica. Macitentan tem menor interação com ciclosporina que bosentana',
    'CONTRAINDICADO — Bosentana + Ciclosporina: 30x de bosentana = hepatotoxicidad + rejeição',
    EvidenceLevel.established,
    {RiskType.hepatotoxicity, RiskType.plasmaLevel},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 243 — Iloprost inalatório + Anti-hipertensivos
  ('iloprost', 'amlodipina',
    InteractionSeverity.moderate,
    'Iloprost (prostaciclina sintética) causa vasodilatação pulmonar e sistêmica; bloqueadores de canal de cálcio (amlodipina, nifedipina) também causam vasodilatação sistêmica; a combinação pode resultar em hipotensão sistêmica excessiva que limita o uso do iloprost ou cause síncope',
    'Hipotensão sistêmica sintomática (PA < 90/60 mmHg), tontura, síncope, presíncope; a hipotensão sistêmica limita a titulação das doses terapéuticas do iloprost',
    'Monitorar PA antes e após cada inalação de iloprost. Medir pressão em posição sentada e de pé (hipotensão ortostática). Pode ser necesario reduzir dose de amlodipina ou substituir por hidralazina específica para redução de pós-carga sem hipotensão sistêmica',
    'Hipotensão sistêmica — Iloprost + Bloqueadores de canal de cálcio: monitorar PA',
    EvidenceLevel.probable,
    {RiskType.cardiovascular},
    [_kRefGG, _kRefUT]),

  // 244 — Selexipague + Fluconazol (CYP2C8)
  ('selexipague', 'fluconazol',
    InteractionSeverity.major,
    'Selexipague (agonista do receptor IP da prostaciclina) é hidrolisada ao metabólito ativo MRE-269 pelo CES1 e metabolizado pelo CYP2C8; fluconazol inibe o CYP2C8 (além de CYP3A4 e CYP2C19); a inibição do CYP2C8 aumenta os níveis do metabólito ativo da selexipague em 1,7–2x',
    'Toxicidade do selexipague: cefaleia grave, dor mandibular, eritema, diarreia, hipotensão; risco aumentado de eventos vasculares periféricos por vasodilatação excessiva',
    'Monitorar sintomas de toxicidad ao iniciar fluconazol. Reduzir dose de selexipague se necesario. Em infecção fúngica, usar equinocandinas (micafungina, anidulafungina) como alternativa sem interação CYP2C8. Fluconazol em dose única para candidíase oral tem menor impacto',
    'Toxicidade de selexipague — Fluconazol inibe CYP2C8: cefaleia e hipotensão',
    EvidenceLevel.probable,
    {RiskType.increasedToxicity, RiskType.cardiovascular},
    [_kRefFDA, _kRefGG]),

  // 245 — Ciclesonida + Itraconazol (corticoide sistêmico)
  ('ciclesonida', 'itraconazol',
    InteractionSeverity.major,
    'Ciclesonida é pró-farmaco ativado pela esterase pulmonar ao des-ciclesonida ativo; a fração pulmonar ativa tem baixa absorção sistêmica; sin embargo, itraconazol (potente inibidor CYP3A4) pode aumentar significativamente a fração sistêmica disponible da ciclesonida e de seu metabólito ativo, causando efeitos corticosteroidais sistêmicos similares ao visto com budesonida',
    'Síndrome de Cushing iatrogênica com supressão adrenal; hiperglucemia, osteoporose acelerada, ganho de peso',
    'Evitar itraconazol em pacientes em ciclesonida em doses altas. Usar anfotericina tópica ou nistatina oral para candidíase. Monitorar cortisol matinal e sinais de Cushing se combinação inevitável',
    'Cushing iatrogênico — Itraconazol + Ciclesonida: inibição CYP3A4 sistêmica',
    EvidenceLevel.probable,
    {RiskType.increasedToxicity},
    [_kRefGG]),

  // 246 — Montelucaste + Fluconazol (CYP2C9)
  ('montelucaste', 'fluconazol',
    InteractionSeverity.moderate,
    'Montelucaste é metabolizado pelo CYP2C9 (e CYP3A4 e CYP2C8); fluconazol é inibidor dos CYP2C9 e CYP3A4; a inibição pode aumentar os níveis de montelucaste em 30–50%; como montelucaste tem ampla margem de segurança, o impacto clínico é geralmente leve a moderado',
    'Cefaleia mais frecuente, náuseas, distúrbios do sono, ansiedade, pesadelos (efeitos neuropsiquiátricos do montelucaste são dose-dependentes)',
    'Monitorar efeitos neuropsiquiátricos durante fluconazol (ansiedade, pesadelos, comportamento anormal). A interação raramente requer ajuste de dose. Usar menor dose de montelucaste se efeitos adversos se tornam problemáticos',
    'Efeitos neuropsiquiátricos aumentados — Fluconazol + Montelucaste: monitorar humor e sono',
    EvidenceLevel.probable,
    {RiskType.cns},
    [_kRefGG]),

  // 247 — Teofilina + Enoxacino/Ciprofloxacino (inibição CYP1A2)
  ('teofilina', 'enoxacino',
    InteractionSeverity.contraindicated,
    'Enoxacino é um dos mais potentes inibidores conhecidos do CYP1A2; ciprofloxacino é inibidor moderado do CYP1A2; teofilina é substrato primário do CYP1A2 com janela terapéutica muito estreita (10–20 mcg/mL); enoxacino aumenta os níveis de teofilina em 4–8x; ciprofloxacino aumenta em 1,5–2x',
    'Toxicidade grave por teofilina: convulsiones, arritmias ventriculares, taquicardia grave, náuseas, vômitos, hipotensão; convulsiones de teofilina são refratárias a tratamento padrão',
    'Enoxacino: contraindicado com teofilina. Ciprofloxacino: monitorar nível de teofilina e reduzir dose em 30–50% ao iniciar ciprofloxacino. Preferir levofloxacino ou azitromicina como alternativas antibióticas (menor inibição CYP1A2)',
    'CONTRAINDICADO (enoxacino) / Monitorar (ciprofloxacino) — Quinolonas + Teofilina: convulsiones',
    EvidenceLevel.established,
    {RiskType.seizure, RiskType.plasmaLevel},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 248 — Aminofilina + Erva de São João (Hypericum)
  ('aminofilina', 'hypericum',
    InteractionSeverity.major,
    'Erva de São João (Hypericum perforatum) contém hiperforina, potente indutor do CYP3A4, CYP2C9 e da P-gp; aminofilina (pró-farmaco da teofilina) é metabolizada principalmente pelo CYP1A2, mas a erva também pode induzir CYP1A2; además, hipericina (outro componente) pode ter efeito direto na teofilina; a inducción enzimática reduz os níveis de teofilina comprometendo o tratamento de asma e DPOC',
    'Concentrações subterapéuticas de teofilina com perda do controle de asma ou DPOC; crises de broncoespasmo por eficácia reducida do broncodilatador',
    'Orientar sobre uso de fitoterápicos. Suspender erva de São João ao iniciar aminofilina. Monitorar nível de teofilina ao iniciar e ao suspender o fitoterápico. A indução persiste por 2 semanas após suspensão da erva',
    'Falha terapéutica de teofilina — Erva de São João induz CYP: monitorar nível',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefUT]),

  // 249 — Ivacaftor (CFTR modulador) + Rifampicina
  ('ivacaftor', 'rifampicina',
    InteractionSeverity.contraindicated,
    'Ivacaftor (modulador CFTR para fibrose cística) é extensamente metabolizado pelo CYP3A4; rifampicina é potente indutor do CYP3A4; a coadministração reduz a AUC do ivacaftor em 89% e de seu metabólito ativo M1 em 75%; com concentrações tão drásticamente reducidas, não há benefício terapéutico e o custo do medicamento (muito elevado) é desperdiçado',
    'Perda completa do benefício terapéutico do ivacaftor na fibrose cística; risco de deterioração da função pulmonar e piora da qualidade de vida',
    'Contraindicado. Na impossibilidade de evitar a rifampicina, usar rifabutina (indutor menos potente, reduz ivacaftor ~36% — ainda problemático mas manejável com ajuste). Consultar equipe de fibrose cística antes de qualquer mudança. Ivacaftor é extremamente caro: garantir que não seja desperdiçado',
    'CONTRAINDICADO — Rifampicina reduz ivacaftor 89%: perda total da eficácia terapéutica',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefFDA, _kRefGG]),

  // 250 — Elexacaftor/Tezacaftor/Ivacaftor + Itraconazol
  ('elexacaftor', 'itraconazol',
    InteractionSeverity.major,
    'A triple terapia CFTR (elexacaftor+tezacaftor+ivacaftor, Trikafta) contém substrato do CYP3A4; itraconazol é potente inibidor do CYP3A4; a inibição aumenta significativamente a exposição aos componentes da triple therapy; a bula recomenda redução da dose para administração em dias alternados com inibidores potentes de CYP3A4',
    'Toxicidade por supraexposição: dor de cabeça, fadiga, tontura, transaminases elevadas, exacerbações respiratórias; hepatotoxicidad por acúmulo de elexacaftor',
    'Reduzir a dose de Trikafta para um comprimido em dias alternados quando em uso de itraconazol ou outros inibidores potentes de CYP3A4. Monitorar função hepática (AST/ALT) mensalmente. Usar antifúngicos alternativos quando possível',
    'Toxicidade de Trikafta — Itraconazol exige redução para uso em dias alternados',
    EvidenceLevel.established,
    {RiskType.hepatotoxicity, RiskType.plasmaLevel},
    [_kRefFDA, _kRefGG]),


  // ═══════════════════════════════════════════════════════════════
  // BLOCK 10 — Oncologia, Imunossupressores, Reumatologia,
  // Geriatria, Miscelânea final (251–280)
  // ═══════════════════════════════════════════════════════════════

  // 251 — Imatinibe + Rifampicina (CYP3A4 indução)
  ('imatinibe', 'rifampicina',
    InteractionSeverity.contraindicated,
    'Imatinibe (inibidor de BCR-ABL/c-KIT para LMC e GIST) é extensamente metabolizado pelo CYP3A4; rifampicina é o mais potente indutor do CYP3A4 disponible clinicamente; a coadministração reduz a AUC do imatinibe em 70–74%; com concentrações tão reducidas, não há resposta citogenética ou molecular suficiente para controle da leucemia',
    'Falha citogenética e molecular com progressão de LMC e GIST; risco de crise blástica por exposição subterapéutica ao imatinibe; impacto clínico documentado em estudos retrospectivos',
    'Contraindicado. Trocar rifampicina por rifabutina (reduz imatinibe ~36%, ainda problemático) ou explorar alternativas não indutoras. Se rifampicina for indispensável (TB + LMC), discutir com hematologista: dobrar dose do imatinibe pode não ser suficiente e pode ser tóxico. Dasatinibe ou nilotinibe têm menor interação com CYP3A4',
    'CONTRAINDICADO — Rifampicina reduz imatinibe 74%: progressão da leucemia',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 252 — Erlotinibe + IBP (absorção pH-dependente)
  ('erlotinibe', 'omeprazol',
    InteractionSeverity.major,
    'Erlotinibe (EGFR-TKI) tem solubilidade altamente dependente do pH: solubilidade cai 100x quando pH sobe de 2 para 7; IBP aumentam o pH gástrico para 4–6, reduzindo drásticamente a absorção do erlotinibe; estudos demonstraram redução de 46% na AUC com omeprazol; antiácidos reduzem AUC em 33% se tomados separados por 2 horas',
    'Falha terapéutica do erlotinibe com progressão do câncer de pulmão EGFR-mutado; risco de resistência secundária por exposição subterapéutica',
    'Evitar IBP com erlotinibe sempre que possível. Usar antiácido (carbonato de cálcio, hidróxido de alumínio) tomado 2 horas após erlotinibe se proteção gástrica necessária. Se IBP for indispensável, investigar alternativa (gefitinibe tem menor interação; osimertinibe não tem interação significativa com IBP)',
    'Falha terapéutica oncológica — IBP reduz erlotinibe 46%: trocar para osimertinibe se possível',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 253 — Ponatinibe + Claritromicina (QT + CYP3A4)
  ('ponatinibe', 'claritromicina',
    InteractionSeverity.major,
    'Ponatinibe (inibidor de BCR-ABL T315I para LMC resistente) prolonga o QT e é metabolizado pelo CYP3A4; claritromicina inibe o CYP3A4 e também prolonga o QT; dupla interação: aumento das concentrações de ponatinibe e efeito aditivo no QT',
    'QTc > 500 ms, torsades de pointes, morte súbita; toxicidads de ponatinibe amplificadas (trombosis arterial, pancreatite, hepatotoxicidad)',
    'Evitar claritromicina com ponatinibe. Usar azitromicina como alternativa (menor inibição CYP3A4 e menor efeito no QT). Monitorar ECG semanalmente se combinação necessária',
    'QT grave + toxicidad oncológica — Claritromicina + Ponatinibe: azitromicina como alternativa',
    EvidenceLevel.probable,
    {RiskType.qtProlongation, RiskType.plasmaLevel},
    [_kRefFDA, _kRefGG]),

  // 254 — Capecitabina + Varfarina (CYP2C9 inibição)
  ('capecitabina', 'varfarina',
    InteractionSeverity.major,
    'Capecitabina é convertida a 5-fluorouracil (5-FU) no tumor; o 5-FU inibe o CYP2C9, principal enzima de metabolismo da S-varfarina (mais potente); o INR pode aumentar dramaticamente ao iniciar ou após cada ciclo de capecitabina; a interação é frecuentemente subestimada por oncologistas e pode causar sangrados fatais',
    'Sangramento grave: hemorragia intracraniana, gastrointestinal maciça; INR pode dobrar ou triplicar dentro de 7–14 dias do início da capecitabina; mortalidade documentada',
    'Monitorar INR a cada 3–5 dias no primeiro ciclo de capecitabina e depois semanalmente durante os ciclos subsequentes. Reduzir dose de varfarina em 30–50% preventivamente. Considerar DOAC como alternativa à varfarina em pacientes com câncer (menor necessidade de monitoramento)',
    'INR dobra/triplica — Capecitabina inibe CYP2C9: monitorar INR a cada 3 dias no ciclo 1',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 255 — Tamoxifeno + Anastrozol (interação já descrita, variação)
  ('tamoxifeno', 'fluoxetina',
    InteractionSeverity.major,
    'Fluoxetina é inibidor potente do CYP2D6; tamoxifeno requer ativação pelo CYP2D6 ao endoxifeno (metabólito ativo); a inibição pelo CYP2D6 pela fluoxetina reduz os níveis de endoxifeno em 50–75%, comprometendo a eficácia antiestrogênica no câncer de mama; paroxetina tem efeito ainda maior (71–75% de redução)',
    'Aumento do risco de recorrência do câncer de mama HR+; falha terapéutica do tamoxifeno na adjuvância e metástase',
    'Substituir fluoxetina e paroxetina por antidepressivos com menor inibição de CYP2D6: escitalopram, venlafaxina, mirtazapina, desvenlafaxina. Esta interação pode ter impacto na sobrevida global em mulheres com câncer de mama',
    'Recorrência de câncer de mama — Fluoxetina inibe CYP2D6: trocar por escitalopram',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefFDA, _kRefGG, _kRefMdx]),

  // 256 — Tacrolimus + Sirolimus (toxicidad renal sinérgica)
  ('tacrolimus', 'sirolimus',
    InteractionSeverity.major,
    'Tacrolimus e sirolimus são ambos inibidores de calcineurina/mTOR com nefrotoxicidad independente; tacrolimus causa nefrotoxicidad por vasoconstrição aferente e lesão tubular; sirolimus potencializa a nefrotoxicidad do tacrolimus possivelmente por inhibición da regeneração tubular e amplificação da isquemia; estudos em transplante renal mostraram maior incidência de rejeição aguda e DGF com a combinação',
    'Nefrotoxicidad grave: insuficiencia renal aguda, DGF (delayed graft function), pérdida del injerto a longo prazo; hiperlipidemia e mielosupresión adicionais do sirolimus',
    'Monitorar creatinina, nível de tacrolimus (C0) e sirolimus (C0) rigurosamente. Considerar substituição: micofenolato de mofetila tem menor nefrotoxicidad que sirolimus como adjuvante ao tacrolimus em transplante renal. Manter sirolimusC0 < 8 ng/mL e tacrolimus < 8 ng/mL quando em combinação',
    'Nefrotoxicidad sinérgica — Tacrolimus + Sirolimus: monitorar C0 de ambos e creatinina',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.plasmaLevel},
    [_kRefGG, _kRefUT, _kRefFDA]),

  // 257 — Micofenolato + Colestiramina (absorção)
  ('micofenolato', 'colestiramina',
    InteractionSeverity.major,
    'Colestiramina (resina quelante de ácidos biliares) liga-se ao micofenolato de mofetila (MMF) e ao seu metabólito ativo ácido micofenólico (MPA) no trato gastrointestinal, interrompendo a circulação êntero-hepática do MPA; esta circulação é responsável por ~10–40% da exposição total ao MPA; a quelação pode reduzir drásticamente os níveis de MPA',
    'Concentrações subterapéuticas de MPA com risco de rejeição aguda em transplantados; reversão do efeito imunossupressor',
    'Contraindicado de rotina. Se colestiramina for necessária (hipercolesterolemia em transplantado), administrar pelo menos 4 horas separadas do MMF. Dosar MPA (C0 e C2) após início da colestiramina. Colestipol tem menor interação que colestiramina',
    'Rejeição de transplante — Colestiramina inibe absorção de micofenolato: separar 4 horas',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefUT]),

  // 258 — Azatioprina + Alopurinol (mielosupresión fatal)
  ('azatioprina', 'alopurinol',
    InteractionSeverity.contraindicated,
    'Azatioprina é convertida a 6-mercaptopurina (6-MP), que é metabolizada pela xantina oxidase (XO) a metabólitos inativos; alopurinol inibe a XO de forma competitiva e irreversível; a inibição bloqueia a inativação da 6-MP, cujos metabólitos ativos (tioguanina) acumulam na medula óssea causando aplasia; esta interação causou mortes e é amplamente documentada nas bulas',
    'Aplasia medular grave com pancitopenia profunda: leucopenia < 1.000/mm³, infecções oportunistas fatais, sepse; anemia e trombocitopenia graves; mortalidade de até 50% se não reconhecida precocemente',
    'Contraindicado. Se ambos forem necesarios (gota em paciente imunossuprimido com artrite/DII): reduzir azatioprina para 25% da dose e monitorar hemograma semanalmente. Preferir febuxostate NÃO — também contraindicado. Usar uricosúrico (probenecida) ou modificar dieta. Se azatioprina for indispensável, suspender alopurinol',
    'CONTRAINDICADO — Alopurinol + Azatioprina: aplasia medular com óbito (bula vermelho)',
    EvidenceLevel.established,
    {RiskType.myelosuppression},
    [_kRefFDA, _kRefGG, _kRefKatz, _kRefUT]),

  // 259 — Ciclofosfamida + Alopurinol (mielosupresión)
  ('ciclofosfamida', 'alopurinol',
    InteractionSeverity.moderate,
    'Ciclofosfamida é metabolizada pelo CYP2B6 a metabólitos ativos alquilantes; alopurinol pode inibir o CYP2B6 reduzindo a ativação da ciclofosfamida mas paradoxalmente estudos mostram que o alopurinol aumenta a mielosupresión da ciclofosfamida por mecanismo não completamente elucidado; o alopurinol é usado preventivamente para hiperuricemia em quimioterapia',
    'Mielossupressão mais pronunciada com neutropenia e trombocitopenia; infecções bacterianas e fúngicas graves; necessidade de ajuste de dose de quimioterapia',
    'Usar com cautela. O alopurinol é frecuentemente necesario para prevenir síndrome de lise tumoral em quimioterapia; monitorar hemograma mais frecuentemente. Considerar rasburicase como alternativa para síndrome de lise tumoral (não tem esta interação)',
    'Mielossupressão aumentada — Alopurinol + Ciclofosfamida: monitorar hemograma intensivo',
    EvidenceLevel.probable,
    {RiskType.myelosuppression},
    [_kRefGG, _kRefMdx]),

  // 260 — Metotrexato + Doxiciclina
  ('metotrexato', 'doxiciclina',
    InteractionSeverity.moderate,
    'Tetraciclinas (doxiciclina, tetraciclina) competem com o metotrexato pelos transportadores OAT1/OAT3 e OATP para excreção renal tubular; a competição pode aumentar os niveles plasmáticos de metotrexato em 30–50%; o metotrexato também tem circulação êntero-hepática que pode ser afetada pela alteração da flora intestinal pela doxiciclina',
    'Toxicidade de metotrexato: mucosita oral grave, pancitopenia, hepatotoxicidad; insuficiencia renal aguda em doses altas (oncológicas)',
    'Monitorar leucometria e creatinina ao iniciar antibiótico em paciente em metotrexato. Nas doses reumatológicas baixas (< 25 mg/semana), o risco é moderado mas real. Em doses oncológicas altas: dosar nível de metotrexato. Preferir azitromicina ou cefalosporina como alternativa antibiótica',
    'Toxicidade de metotrexato — Doxiciclina compete no transporte renal: monitorar hemograma',
    EvidenceLevel.probable,
    {RiskType.myelosuppression, RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx]),

  // 261 — Tocilizumabe + Sinvastatina (normalização de CRP e metabolismo)
  ('tocilizumabe', 'sinvastatina',
    InteractionSeverity.moderate,
    'Inflamação sistêmica suprime o CYP3A4 e CYP2C9 via interleucinas (especialmente IL-6); ao iniciar tocilizumabe (anti-IL-6R), a IL-6 sistêmica cai drásticamente, restaurando a atividade normal do CYP3A4; a sinvastatina (substrato CYP3A4) que era metabolizada mais lentamente durante inflamação ativa agora é metabolizada mais rapidamente, resultando em queda dos seus níveis; efeito paradoxal',
    'Queda inesperada dos níveis de sinvastatina com possível redução da eficácia na proteção cardiovascular durante o início do tratamento; o efeito é oposto ao esperado em terapias com anti-inflamatórios',
    'Monitorar LDL-C 4–8 semanas após início do tocilizumabe. Em pacientes com alto risco cardiovascular, pode ser necesario aumentar a dose de sinvastatina ou trocar para outra estatina. Este efeito é temporário — a nova steady-state estabiliza em 4–8 semanas',
    'Queda paradoxal de estatina — Tocilizumabe restaura CYP3A4: monitorar LDL-C ao iniciar',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefFDA]),

  // 262 — Baricitinibe + Rifampicina (JAK inibidor)
  ('baricitinibe', 'rifampicina',
    InteractionSeverity.major,
    'Baricitinibe (JAK1/2 inibidor para artrite reumatoide) é metabolizado principalmente pelo CYP3A4; rifampicina induz o CYP3A4 reduzindo a AUC do baricitinibe em 60%; com concentrações tão reducidas, a inibição de JAK1/2 é insuficiente para controle da inflamação articular',
    'Falha terapéutica com progressão da artrite reumatoide; sinovite recorrente, dano articular; necessidade de corticoides de resgate',
    'Evitar rifampicina com baricitinibe. Se tratamento para TB for necesario em paciente com AR em baricitinibe, suspender baricitinibe e usar biológico alternativo (adalimumabe) que tem menor interação com rifampicina. Retomar baricitinibe após o término da TB',
    'Falha terapéutica de baricitinibe — Rifampicina reduz 60%: suspender durante TB e usar biológico',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefFDA, _kRefGG]),

  // 263 — Upadacitinibe + Rifampicina (já coberto mas confirmação)
  ('upadacitinibe', 'carbamazepina',
    InteractionSeverity.major,
    'Upadacitinibe (JAK1 inibidor seletivo) é metabolizado pelo CYP3A4; carbamazepina é indutor moderado a potente do CYP3A4; a indução pode reduzir os níveis de upadacitinibe em 30–45%, comprometendo a eficácia terapéutica',
    'Controle insuficiente da AR ou espondilite anquilosante com dor articular persistente, falha de remissão; necessidade de doses de resgate',
    'Substituir carbamazepina por antiepiléptico sem indução CYP3A4 (levetiracetam, lamotrigina) sempre que possível. Se carbamazepina for indispensável, monitorar atividade da doença (DAS28, CRP). Aumento de dose de upadacitinibe pode ser necesario e está dentro das possibilidades da bula',
    'Falha terapéutica — Carbamazepina reduz upadacitinibe: trocar antiepiléptico',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy},
    [_kRefFDA, _kRefGG]),

  // 264 — Certolizumabe + Vacinas vivas (contraindicação)
  ('certolizumabe', 'vacina_viva',
    InteractionSeverity.contraindicated,
    'Certolizumabe pegol (anti-TNF PEGilado) neutraliza o TNF-alfa, prejudicando a imunidade celular mediada por Th1 necessária para controle de infecções; vacinas vivas contêm patógenos atenuados que requerem a imunidade Th1 intacta para contenção; em imunossupressão anti-TNF, esses patógenos podem causar doença grave disseminada',
    'Doença disseminada pela cepa vacinal: BCGite, varicela grave, febre amarela visceral, sarampo fatal; óbito documentado em pacientes em anti-TNF vacinados com vacinas vivas',
    'Contraindicado. Completar todas as vacinas vivas pelo menos 4 semanas antes de iniciar certolizumabe. Aguardar pelo menos 3 meses após a última dose antes de administrar vacinas vivas. Vacinas inativadas são seguras e recomendadas',
    'CONTRAINDICADO — Certolizumabe + Vacinas vivas: doença vacinal disseminada e óbito',
    EvidenceLevel.established,
    {RiskType.infection},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 265 — Secuquinumabe (anti-IL17) + Vacinas vivas
  ('secuquinumabe', 'vacina_viva',
    InteractionSeverity.contraindicated,
    'Secuquinumabe (anti-IL-17A para psoríase, espondiloartrite) suprime a imunidade Th17, essencial para defesa contra fungos (Candida) e algumas bactérias extracelulares; vacinas vivas requerem imunidade celular preservada; o risco específico de Candida disseminada é aumentado com anti-IL17',
    'Candidemia disseminada após vacinação com vacinas vivas em imunocomprometidos; outras infecções graves por patógenos da cepa vacinal',
    'Contraindicado. Vacinar com vacinas vivas pelo menos 4 semanas antes de iniciar secuquinumabe. Aguardar 3–6 meses após a última dose antes de vacinas vivas. Risco adicional de candidíase mucocutânea durante o tratamento (não relacionado às vacinas)',
    'CONTRAINDICADO — Secuquinumabe + vacinas vivas: supressão Th17 e infecção fúngica',
    EvidenceLevel.established,
    {RiskType.infection},
    [_kRefFDA, _kRefGG]),

  // 266 — Prednisolona + Diuréticos (hipopotasemia + hiperglucemia)
  ('prednisolona', 'clortalidona',
    InteractionSeverity.moderate,
    'Corticoides causam retenção de sódio e perda de potássio (efeito mineralocorticoide), hiperglucemia (efeito diabetogênico) e dislipidemia; diuréticos tiazídicos (clortalidona) também causam hipopotasemia e hiperglucemia (reduzem a secreção de insulina); os dois mecanismos são aditivos na hipopotasemia e hiperglucemia',
    'Hipocalemia grave (K+ < 3 mEq/L): arritmias, fraqueza muscular, paro cardíaco; hiperglucemia (DM esteroidal) requerendo início de hipoglucemiante',
    'Monitorar K+ e glucemia semanalmente ao início da combinação. Suplementar K+ se K+ < 3,5 mEq/L. Monitorar HbA1c a cada 3 meses em uso crônico. Reduzir dose de tiazídico ou substituir por poupador de potássio (espironolactona) se hipopotasemia persistente',
    'Hipocalemia + hiperglucemia aditivas — Corticoide + Tiazídico: monitorar K+ e glucemia',
    EvidenceLevel.established,
    {RiskType.hypokalemia, RiskType.hypoglycemia},
    [_kRefGG, _kRefKatz]),

  // 267 — Colchicina + Inibidores de P-gp (ciclosporina)
  ('colchicina', 'ciclosporina',
    InteractionSeverity.major,
    'Ciclosporina inibe tanto o CYP3A4 quanto a P-glicoproteína; colchicina é substrato de ambos com janela terapéutica estreita; a inibição dupla pode aumentar os níveis de colchicina em 2,5–4x; colchicina tem toxicidad grave dose-dependente; esta combinação é a causa mais documentada de colchicinemia tóxica em pacientes transplantados com gota',
    'Toxicidade grave de colchicina: miopatia com rabdomiólisis, neuropatia periférica, pancitopenia, disfunção de múltiplos órgãos; mortalidade documentada em transplantados com gota tratados com colchicina em dose habitual',
    'Dose máxima de colchicina com ciclosporina: 0,5 mg/dia (metade da dose usual mínima para profilaxia). Para gota aguda: 0,6 mg dose única (não repetir por pelo menos 3 dias). Monitorar CK, hemograma e función renal. Em transplantados com gota, considerar corticoide oral de curta duração (5 dias) como alternativa mais segura',
    'Toxicidade fatal de colchicina — Ciclosporina inibe CYP3A4 + P-gp: 0,5 mg/dia máximo',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.myelosuppression},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 268 — Piroxicam + Metotrexato (toxicidad renal + hematológica)
  ('piroxicam', 'metotrexato',
    InteractionSeverity.major,
    'AINEs (especialmente naproxeno, piroxicam, indometacina) reduzem o clearance renal do metotrexato por inhibición das prostaglandinas renais e competição com o transporte tubular (OAT); o metotrexato acumula nos compartimentos intra e extracelulares causando toxicidad grave; a combinação é aceita em doses reumatológicas (< 25 mg/semana) com cautela mas é de alto risco em doses oncológicas',
    'Mucosita oral ulcerativa grave, neutropenia profunda, insuficiencia renal aguda, hepatotoxicidad; óbito documentado em doses oncológicas',
    'Evitar AINEs nas 24–48 horas antes e após as doses de metotrexato (especialmente em doses oncológicas). Em doses reumatológicas (< 25 mg/semana), monitorar creatinina e hemograma mensalmente. Paracetamol é alternativa analgésica segura. Preferir celecoxibe (menor efeito na prostaglandina renal) se AINE for necesario',
    'Toxicidade fatal de metotrexato — AINEs reduzem clearance renal: evitar nas 48h do MTX',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.myelosuppression},
    [_kRefGG, _kRefKatz, _kRefMdx]),

  // 269 — Zoledrônico + Aminoglicosídeos (hipocalcemia profunda)
  ('zoledronico', 'gentamicina',
    InteractionSeverity.major,
    'Bisfosfonatos IV (zoledronato, pamidronato) inibem a reabsorção óssea de osteoclastos, reduzindo o cálcio sérico; aminoglicosídeos podem potencializar a hipocalcemia por mecanismo incerto (possível efeito direto na reabsorção tubular de cálcio e magnésio); además, aminoglicosídeos causam hipomagnesemia, que impede a correção da hipocalcemia (o paratormônio requer magnésio para agir)',
    'Hipocalcemia grave sintomática: tetania, convulsiones, broncoespasmo, prolongamento do QT; impossibilidade de correção da hipocalcemia enquanto hipomagnesemia persistir',
    'Monitorar cálcio, magnésio e fósforo diariamente durante a combinação. Repor magnésio IV antes de tentar corrigir a hipocalcemia. Suplementar cálcio IV se cálcio total < 7,5 mg/dL sintomático. Considerar adiar a infusão de zoledronato se aminoglicosídeo for indispensável',
    'Hipocalcemia profunda + hipomagnesemia — Zoledronato + Aminoglicosídeo: repor Mg++ primeiro',
    EvidenceLevel.probable,
    {RiskType.electrolyte, RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx]),

  // 270 — Denosumabe + Corticoides (hipocalcemia + osteofragilidade)
  ('denosumabe', 'prednisona',
    InteractionSeverity.moderate,
    'Denosumabe (anti-RANK-L) inibe a diferenciação de osteoclastos, reduzindo a reabsorção óssea e liberação de cálcio; corticoides reduzem a absorção intestinal de cálcio (anti-vitamina D), diminuem a reabsorção renal e aumentam a reabsorção óssea; embora os mecanismos sejam opostos na reabsorção óssea, o cálcio sérico pode cair com a combinação; a proteção óssea do denosumabe é necessária justamente em usuários crônicos de corticoide',
    'Hipocalcemia moderada a grave, especialmente em pacientes com hipoparatireoidismo subclínico ou insuficiência de vitamina D; maior risco nas primeiras semanas após a injeção de denosumabe',
    'Suplementar cálcio (1.500 mg/dia) e vitamina D3 (800 UI/dia ou mais) antes e durante denosumabe + corticoide. Monitorar calcemia e vitamina D 25-OH no início e a cada 6 meses. Considerar calcitriol em pacientes com hipoparatireoidismo',
    'Hipocalcemia — Denosumabe + Corticoide: suplementar Ca++ e vitamina D obligatoriamente',
    EvidenceLevel.established,
    {RiskType.electrolyte},
    [_kRefFDA, _kRefGG]),

  // 271 — Rosiglitazona + Nitrato (hipotensão)
  ('rosiglitazona', 'mononitrato',
    InteractionSeverity.moderate,
    'Rosiglitazona (glitazona/TZD) causa retenção de líquidos e leve expansão de volume, sin embargo também tem efeito vasodilatador por redução da resistência vascular periférica; nitratos causam vasodilatação venosa e arterial; a combinação pode causar hipotensão excessiva por vasodilatação sinérgica, especialmente em idosos ou pacientes já com ICC',
    'Hipotensão ortostática, tontura, síncope; edema pulmonar ou periférico exacerbado pela retenção hídrica da rosiglitazona em ICC',
    'Monitorar PA (especialmente ortostática) ao usar combinação. Rosiglitazona é contraindicada em ICC classes III e IV (retenção hídrica). Preferir iSGLT2 para proteção cardiovascular em diabéticos com DAC (sem efeito de retenção hídrica)',
    'Hipotensão e edema — Rosiglitazona + Nitratos: monitorar PA, preferir iSGLT2 em DAC',
    EvidenceLevel.probable,
    {RiskType.cardiovascular},
    [_kRefGG]),

  // 272 — Pioglitazona + Gemfibrozil (CYP2C8 inibição)
  ('pioglitazona', 'gemfibrozil',
    InteractionSeverity.major,
    'Pioglitazona é metabolizada pelo CYP2C8; gemfibrozil é um dos mais potentes inibidores do CYP2C8 disponíveis; a inibição aumenta a AUC da pioglitazona em 3–4x; com concentrações tão elevadas, todos os efeitos adversos de pioglitazona são amplificados: retenção hídrica, edema, risco de ICC e bexiga (após uso crônico)',
    'Edema grave com insuficiencia cardíaca descompensada; hipoglucemia mais pronunciada; risco aumentado de câncer de bexiga com exposição cumulativa elevada',
    'Contraindicação relativa. Preferir fenofibrato (não inibe CYP2C8) para hipertrigliceridemia em pacientes em pioglitazona. Se gemfibrozil for necesario, monitorar PA, peso, função cardíaca e glucemia. Considerar iSGLT2 como alternativa à pioglitazona',
    'Toxicidade de pioglitazona 4x maior — Gemfibrozil inibe CYP2C8: usar fenofibrato',
    EvidenceLevel.established,
    {RiskType.increasedToxicity, RiskType.cardiovascular},
    [_kRefFDA, _kRefGG]),

  // 273 — Insulina detemir + Álcool (hipoglucemia noturna)
  ('insulina_detemir', 'alcool',
    InteractionSeverity.major,
    'O álcool inibe a gliconeogênese hepática, reduzindo a produção endógena de glicose; a insulina detemir (basal) mantém ação contínua por 16–24 horas; a combinação causa hipoglucemia prolongada noturna sem que o fígado possa compensar; a hipoglucemia alcoólica é especialmente perigosa pois o paciente pode não reconhê-la (similitude de sintomas com embriaguez) e não ter acompanhante',
    'Hipoglucemia grave noturna: tontura, sudorese, convulsiones, coma hipoglicêmico; o álcool pode mascarar os sinais de hipoglucemia e impedir o reconhecimento e tratamento oportuno',
    'Orientar fortemente sobre o risco de hipoglucemia noturna com álcool. Se o paciente beber, deve consumir carboidratos antes de dormir e monitorar glucemia capilar. Limitar consumo alcoólico. Em episódio de hipoglucemia alcoólica: glicose IV (não glucagon oral, que depende da gliconeogênese hepática)',
    'Hipoglucemia noturna grave — Álcool + Insulina basal: consumir CHO antes de dormir se beber',
    EvidenceLevel.established,
    {RiskType.hypoglycemia},
    [_kRefGG, _kRefKatz]),

  // 274 — Sulfoniluréia + Fluconazol (hipoglucemia por inhibición CYP2C9)
  ('glibenclamida', 'fluconazol',
    InteractionSeverity.major,
    'Sulfoniluréias de segunda geração (glibenclamida, glipizida) são metabolizadas pelo CYP2C9; fluconazol é potente inibidor do CYP2C9; a inibição aumenta os niveles plasmáticos das sulfoniluréias em 50–100%, prolongando e potencializando a ação hipoglucemiante; o risco é especialmente alto em idosos e em pacientes com IRC',
    'Hipoglucemia grave y prolongada (> 24 horas pois a glibenclamida é de longa duração); convulsiones hipoglicêmicas, coma, dano neurológico irreversível; idosos têm maior risco por menor resposta adrenérgica à hipoglucemia',
    'Monitorar glucemia capilar a cada 4–6 horas durante fluconazol em usuário de sulfoniluréia. Reduzir dose de sulfoniluréia em 25–50%. Hospitalizar se glucemia < 60 mg/dL e difícil controle. Preferir fluconazol em dose única (150 mg) para candidíase vaginal (menor impacto)',
    'Hipoglucemia prolongada grave — Fluconazol dobra sulfoniluréia: monitorar glucemia de 4/4h',
    EvidenceLevel.established,
    {RiskType.hypoglycemia, RiskType.plasmaLevel},
    [_kRefGG, _kRefKatz, _kRefUT]),

  // 275 — Acarbose + Digoxina (absorção reducida)
  ('acarbose', 'digoxina',
    InteractionSeverity.moderate,
    'Acarbose (inibidor de alfa-glicosidase) retarda a digestão e absorção de carboidratos no intestino delgado; pode alterar a motilidade intestinal e a flora microbiana; estudos mostraram redução de 20–35% na AUC da digoxina quando administrada concomitantemente com acarbose por possível quelação ou alteração da absorção intestinal',
    'Redução dos níveis séricos de digoxina com falha no controle da frequência em FA ou redução da contratilidade em ICC',
    'Monitorar digoxinemia ao iniciar acarbose. Pode ser necesario aumentar a dose de digoxina em 15–25%. Administrar digoxina 30 min antes da acarbose (antes das refeições) para minimizar a interação',
    'Absorção reducida de digoxina — Acarbose: monitorar digoxinemia e tomar digoxina 30 min antes',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),

  // 276 — Canagliflozina + Diuréticos + Betabloqueadores (hipoglucemia mascarada)
  ('canagliflozina', 'propranolol',
    InteractionSeverity.moderate,
    'Propranolol (betabloqueador não seletivo) mascara os sintomas adrenérgicos de hipoglucemia (taquicardia, tremor, diaforese) por bloqueio de receptores beta-adrenérgicos; a sudorese é preservada (mediada por colinérgicos); em combinação com iSGLT2 que podem raramente causar hipoglucemia euglicêmica, a ausência de sintomas pode retardar o diagnóstico e tratamento',
    'Hipoglucemia não reconhecida com coma hipoglicêmico; episódios de hipoglucemia assintomáticos especialmente durante exercício ou jejum',
    'Monitorar glucemia com maior frequência em usuários de propranolol. Educar sobre sintomas não adrenérgicos de hipoglucemia (palor, sudorese, confusão). Preferir betabloqueador cardioselective (bisoprolol, metoprolol) que preserva maior resposta adrenérgica. iSGLT2 raramente causam hipoglucemia isoladamente, mas o risco aumenta com insulina ou sulfoniluréia associada',
    'Hipoglucemia mascarada — Betabloqueador não seletivo + iSGLT2: monitorar glucemia',
    EvidenceLevel.probable,
    {RiskType.hypoglycemia},
    [_kRefGG]),

  // 277 — Ritonavir + Morfina (glucuronidação)
  ('ritonavir', 'morfina',
    InteractionSeverity.moderate,
    'Ritonavir induz a UGT2B7, principal enzima de glucuronidação da morfina; a morfina é inativada principalmente pela glucuronidação a morfina-6-glucuronídeo (ativo) e morfina-3-glucuronídeo (inativo); a indução da UGT2B7 pode aumentar o metabolismo da morfina, reduzindo seus niveles plasmáticos em 20–55% e reduzindo a analgesia; o metabólito ativo M6G também é afetado',
    'Analgesia insuficiente, dor não controlada, abstinência opioide em dependentes em TARV; necessidade de doses maiores de morfina',
    'Monitorar nível de dor em pacientes em morfina que iniciam TARV com ritonavir. Pode ser necesario aumentar a dose de morfina em 20–40%. Considerar alternativas analgésicas (hidromorfona — menor interação; oxicodona — metabolizada pelo CYP3A4 inibido por ritonavir, portanto níveis aumentam)',
    'Analgesia reducida — Ritonavir induz glucuronidação da morfina: aumentar dose em 20–40%',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefUT]),

  // 278 — Linezolida + Pseudoefedrina/Efedrina (crise hipertensiva)
  ('linezolida', 'pseudoefedrina',
    InteractionSeverity.major,
    'Linezolida inibe a MAO-A; pseudoefedrina (simpatomimético de ação indireta) libera noradrenalina armazenada nas vesículas neurais; com a MAO-A inibida, a noradrenalina liberada não é degradada, causando acúmulo e tempestade adrenérgica; mecanismo idêntico à crise de queijo com IMAOs tradicionais',
    'Crise hipertensiva grave (PA > 180/120 mmHg), cefaleia em trovão, AVC hemorrágico, infarto do miocárdio; taquicardia grave',
    'Contraindicado. Descongestionantes nasais (oximetazolina, xilometazolina tópicos) podem ser alternativas mais seguras pois têm baixa absorção sistêmica. Evitar todos os simpaticomiméticos orais (efedrina, fenilefrina oral) durante linezolida. Restrição dietética de tiramina também se aplica',
    'Crise hipertensiva — Linezolida (IMAO) + Pseudoefedrina: evitar todos os simpaticomiméticos',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 279 — Tranilcipromina (IMAO irreversível) + Triptanos
  ('tranilcipromina', 'sumatriptano',
    InteractionSeverity.contraindicated,
    'Tranilcipromina é IMAO irreversível (inibidor de MAO-A e MAO-B); sumatriptano e outros triptanos são agonistas de receptores 5-HT1B/D; o metabolismo dos triptanos requer MAO-A; com a MAO-A inibida, os níveis de triptanos aumentam drásticamente (2–3x) e o risco de síndrome serotoninérgica é muito alto; además, vasoconstrição coronariana pelo triptano associada à hipertensão do IMAO pode causar IAM',
    'Síndrome serotoninérgica grave, crise hipertensiva, vasoespasmo coronariano com IAM; mortalidade documentada',
    'Contraindicado. Aguardar pelo menos 14 dias após suspensão de tranilcipromina antes de usar qualquer triptano (período necesario para síntese de nova MAO-A). Em enxaqueca durante tratamento com IMAO: usar AINEs, paracetamol, metoclopramida (sem ISRS) para as crises',
    'CONTRAINDICADO — IMAO + Triptano: aguardar 14 dias após IMAO antes de usar triptano',
    EvidenceLevel.established,
    {RiskType.serotonin, RiskType.cardiovascular},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 280 — Fenelzina (IMAO) + Meperidina (serotonina letal)
  ('fenelzina', 'meperidina',
    InteractionSeverity.contraindicated,
    'Fenelzina é IMAO irreversível não seletivo (MAO-A e MAO-B); meperidina (petidina) inibe a recaptação de serotonina de forma mais potente que outros opioides; com a MAO-A inibida, a serotonina não é degradada e o bloqueio adicional de recaptação pela meperidina causa acúmulo sináptico maciço de serotonina; síndrome serotoninérgica severa com alta mortalidade',
    'Síndrome serotoninérgica potencialmente fatal: tremor, hiperreflexia, hipertermia grave (> 42°C), colapso cardiovascular, morte; casos fatais bem documentados na literatura',
    'Contraindicado absolutamente. Aguardar 14 dias após suspensão de IMAO antes de usar meperidina. Usar morfina, hidromorfona ou fentanil como analgésicos alternativos (menor atividade serotoninérgica). Em cirurgia de emergência, informar anestesiologista sobre o uso de IMAO',
    'CONTRAINDICADO — IMAO + Meperidina: síndrome serotoninérgica fatal documentada',
    EvidenceLevel.established,
    {RiskType.serotonin},
    [_kRefFDA, _kRefGG, _kRefUT, _kRefMdx]),


  // ═══════════════════════════════════════════════════════════════
  // BLOCK 11 — Interações finais clínicas de alta relevância (281–300)
  // ═══════════════════════════════════════════════════════════════

  // 281 — Fentanil + Midazolam + Propofol (tríade anestésica)
  ('fentanil', 'midazolam',
    InteractionSeverity.major,
    'A combinação de fentanil (opioide), midazolam (BZD) e propofol (anestésico geral) cria depresión respiratoria sinérgica extrema via três mecanismos diferentes: fentanil deprime o centro respiratório via receptores mu; midazolam potencializa GABA-A reduzindo o drive respiratório; propofol suprime o SNC globalmente; a combinação é essencial em anestesia mas com risco de apneia súbita em sedações não controladas',
    'Apneia, hipóxia grave, colapso cardiovascular, morte; o fentanil potencia a sedação do midazolam em 4–8x',
    'Fora do contexto anestésico controlado: monitoração rigurosa de SpO2, FR e nível de consciência. Ter naloxona e flumazenil disponíveis. Titulação lenta e sequencial. Apenas profissionais treinados em via aérea devem administrar esta combinação',
    'Apneia — Fentanil + Midazolam + Propofol: somente com monitorização anestésica',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns},
    [_kRefGG, _kRefKatz]),

  // 282 — Rocurônio + Sugammadex (reversão farmacológica)
  ('rocurônio', 'sugammadex',
    InteractionSeverity.minor,
    'Sugammadex é uma ciclodextrina que encapsula seletivamente o rocurônio (e vecurônio), revertendo farmacologicamente o bloqueio neuromuscular; não é uma interação adversa — é o uso terapéutico intencional do sugammadex como antídoto específico do rocurônio; a interação física entre as duas moléculas é altamente seletiva e desejável',
    'Sem efeito adverso pela interação molecular; em raros casos, sugammadex pode causar bradicardia transitória ou reação alérgica; o rocurônio não tem efeitos adicionais após encapsulamento',
    'Combinação intencional e terapéutica. Verificar dose adecuada de sugammadex (16 mg/kg para reversão imediata em intubação difícil; 4 mg/kg para bloqueio moderado; 2 mg/kg para bloqueio superficial). Monitorar recuperação neuromuscular com TOF ratio > 0,9',
    'Reversão farmacológica intencional — Sugammadex encapsula rocurônio: antídoto específico',
    EvidenceLevel.established,
    {RiskType.other},
    [_kRefFDA, _kRefGG]),

  // 283 — Ketamina + IMAOs (crise simpaticomimética)
  ('cetamina', 'tranilcipromina',
    InteractionSeverity.contraindicated,
    'Cetamina (anestésico dissociativo) inibe a recaptação de noradrenalina, dopamina e serotonina além de bloquear receptores NMDA; com a MAO-A inibida por tranilcipromina ou fenelzina, a noradrenalina e serotonina acumulam causando crise hipertensiva grave e síndrome serotoninérgica; risco extremo em anestesia de emergência em pacientes não identificados como usuários de IMAO',
    'Crise hipertensiva grave (PA > 200/120 mmHg), AVC hemorrágico, infarto do miocárdio, síndrome serotoninérgica grave com hipertermia; mortalidade alta',
    'Contraindicado. Informar anestesiologista sobre uso atual ou recente de IMAO. Aguardar 14 dias após IMAO antes de cetamina eletiva. Em emergência: usar propofol ou etomidato como indução alternativa. Se cetamina inadvertida: labetalol IV + ciproheptadina para crise hipertensiva e serotonina',
    'CONTRAINDICADO — IMAO + Cetamina: crise hipertensiva + serotonina em emergência anestésica',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.serotonin},
    [_kRefGG, _kRefFDA]),

  // 284 — Dexmedetomidina + Beta-bloqueadores (bradicardia profunda)
  ('dexmedetomidina', 'esmolol',
    InteractionSeverity.major,
    'Dexmedetomidina é agonista alfa-2 adrenérgico central que reduz o tônus simpático, causando bradicardia e hipotensão; esmolol e outros beta-bloqueadores causam bradicardia por bloqueio de receptores beta-1; a combinação causa bradicardia sinérgica profunda por dupla inibição da estimulação cardíaca simpática',
    'Bradicardia grave (FC < 40 bpm), asistolia temporária, hipotensão refratária; bloqueio AV; colapso hemodinâmico em pacientes com baixa reserva cardíaca',
    'Monitorar FC e PA continuamente em UTI/sedação. Ter atropina 0,5 mg IV disponible para bradicardia sintomática. Reduzir dose de um dos agentes se FC < 50 bpm. Evitar em pacientes com disfunção sinusal prévia',
    'Bradicardia profunda — Dexmedetomidina + Beta-bloqueador: ter atropina disponible',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    [_kRefGG, _kRefFDA]),

  // 285 — Propofol + Antibióticos lipofílicos (síndrome do propofol)
  ('propofol', 'linezolida',
    InteractionSeverity.moderate,
    'O propofol é formulado como emulsão lipídica (óleo de soja 10%); em infusão prolongada em altas doses (> 5 mg/kg/h por > 48h), pode causar síndrome de infusão de propofol (PRIS) com acidose lática, rabdomiólisis e colapso cardiovascular; linezolida pode potencializar a toxicidad mitocondrial (inibe a síntese proteica mitocondrial) amplificando os efeitos da PRIS; a interação é farmacodinâmica',
    'Síndrome de infusão de propofol amplificada: acidose metabólica grave, rabdomiólisis, insuficiencia cardíaca, colapso hemodinâmico; mortalidade de 33–85% em PRIS grave',
    'Monitorar triglicerídeos (alvo < 400 mg/dL), CK, lactato e ECG em infusão prolongada de propofol. Se linezolida for necessária por > 7 dias, considerar alternativa sedativa (dexmedetomidina, midazolam). Interromper propofol se CK > 5x LSN ou acidose lática sem causa identificável',
    'PRIS amplificada — Propofol prolongado + Linezolida: monitorar triglicerídeos, CK e lactato',
    EvidenceLevel.possible,
    {RiskType.myopathy, RiskType.other},
    [_kRefGG]),

  // 286 — Atenolol + Verapamil (bloqueio AV completo)
  ('atenolol', 'verapamil',
    InteractionSeverity.contraindicated,
    'Atenolol e outros beta-bloqueadores inibem os efeitos cronotrópico e dromotrópico da estimulação adrenérgica no nódulo sinoatrial e AV; verapamil é bloqueador de canal de cálcio com efeitos cronotrópico e dromotrópico negativos potentes no nódulo AV; a combinação causa bloqueio AV sinérgico com risco de bloqueio completo e asistolia',
    'Bloqueio AV de 3º grau, asistolia, bradicardia extrema (FC < 30 bpm), colapso hemodinâmico, morte; o risco é máximo com administração intravenosa de qualquer um dos dois',
    'Contraindicação clínica bem estabelecida. Nunca administrar verapamil IV em pacientes em beta-bloqueador oral. Para taquiarritmias supraventriculares: adenosina é alternativa segura. Para controle de frequência a longo prazo em FA: digoxina tem menor interação com verapamil',
    'CONTRAINDICADO — Atenolol + Verapamil IV: bloqueio AV completo e asistolia',
    EvidenceLevel.established,
    {RiskType.arrhythmia, RiskType.cardiovascular},
    [_kRefGG, _kRefKatz, _kRefFDA]),

  // 287 — Haloperidol + Lítio (neurotoxicidad)
  ('haloperidol', 'litio',
    InteractionSeverity.major,
    'Haloperidol e lítio têm mecanismos distintos mas podem causar neurotoxicidad sinérgica; o lítio pode potencializar a toxicidad do haloperidol no SNC; estudos retrospectivos relataram encefalopatia, parkinsonismo irreversível e discinesias tardias com a combinação; haloperidol reduz a clearance renal de sódio, podendo indiretamente aumentar a litemia; a combinação clássica (Cohen encephalopathy) foi amplamente documentada nos anos 1970',
    'Encefalopatia com confusão mental, febre, parkinsonismo grave, discinesias tardias possivelmente irreversíveis; litemia pode aumentar inadvertidamente com haloperidol',
    'Usar com cautela e monitorar litemia de perto (a cada 3–5 dias no início). Preferir antipsicóticos atípicos (olanzapina, quetiapina) com menor risco de neurotoxicidad em combinação com lítio. Evitar haloperidol em doses altas com lítio. Hidratação adecuada',
    'Neurotoxicidad grave — Haloperidol + Lítio: monitorar litemia e sinais neurológicos',
    EvidenceLevel.probable,
    {RiskType.cns, RiskType.plasmaLevel},
    [_kRefGG, _kRefKatz]),

  // 288 — Dissulfiram + Álcool (reação aversiva intencional)
  ('dissulfiram', 'alcool',
    InteractionSeverity.contraindicated,
    'Dissulfiram inibe a aldeído desidrogenase (ALDH), bloqueando o metabolismo do acetaldeído (metabólito do álcool); a inibição causa acúmulo de acetaldeído com reação sistêmica grave; esta é uma interação terapéutica intencional para dissuasão do consumo alcoólico, mas pode ser fatal em dose elevada de álcool',
    'Reação dissulfiram-álcool: rubor facial, cefaleia pulsátil, náuseas, vômitos, taquicardia, hipotensão, dispneia; em doses altas de álcool: colapso cardiovascular, IAM, convulsiones, coma, morte',
    'Combinação intencional terapéutica para alcoolismo. Educação intensiva do paciente é essencial. Monitorar consumo alcoólico inadvertido (molhos, vinagre, remédios com álcool). Ter suporte cardiovascular disponible se reação grave. Suspender dissulfiram pelo menos 2 semanas antes de cirurgia eletiva',
    'REAÇÃO GRAVE — Dissulfiram + Álcool: acúmulo de acetaldeído intencional, educar paciente',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.other},
    [_kRefFDA, _kRefGG]),

  // 289 — Aciclovir + Tenofovir (nefrotoxicidad tubular)
  ('aciclovir', 'tenofovir',
    InteractionSeverity.moderate,
    'Aciclovir e tenofovir são análogos de nucleosídeos que competem pelo mesmo transportador renal OAT1 para excreção tubular ativa; a competição pode reduzir o clearance de ambos os fármacos, aumentando seus niveles plasmáticos; tenofovir já causa nefrotoxicidad tubular proximal; aciclovir pode precipitar na urina causando nefrotoxicidad tubular obstrutiva',
    'Nefrotoxicidad aditiva com risco de insuficiencia renal aguda; cristalúria por aciclovir potencializada pela competição transportadora; síndrome de Fanconi por acúmulo de tenofovir',
    'Garantir hidratação adecuada (> 2 L/dia) durante co-administração de aciclovir IV. Monitorar creatinina, fósforo e urina (proteinúria, cilindros) semanalmente. Preferir valaciclovir oral (menor concentração urinária) quando possível em pacientes em tenofovir',
    'Nefrotoxicidad tubular — Aciclovir + Tenofovir: hidratação ≥2L/dia obligatorio',
    EvidenceLevel.probable,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx]),

  // 290 — Oseltamivir + Probenecida (aumento de exposição)
  ('oseltamivir', 'probenecida',
    InteractionSeverity.moderate,
    'Probenecida inibe os transportadores renais OAT1/OAT3 para excreção tubular de ácidos orgânicos; oseltamivir ativo (GS4071) é excretado via OAT1/OAT3; probenecida reduz o clearance renal do oseltamivir ativo em ~50%, dobrando sua AUC; embora possa ser usado terapeuticamente em tratamentos de baixa disponibilidade, aumenta o risco de toxicidad',
    'Náuseas, vômitos, cefaleia mais frecuentes por supraexposição ao oseltamivir ativo; raramente neuropsiquiátrico (agitação, alucinações) em concentrações elevadas',
    'A combinação pode ser usada intencionalmente para "stretching" de doses de oseltamivir em emergências de saúde pública. Na clínica habitual, monitorar efeitos adversos. Ajustar dose de oseltamivir para metade (75 mg dose única ao invés de 75 mg 2x/dia) se probenecida for necessária por outra indicação',
    'Dobra exposição ao oseltamivir — Probenecida inibe excreção renal: monitorar efeitos adversos',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefFDA, _kRefGG]),

  // 291 — Ganciclovir IV + Zidovudina (AZT) — mielosupresión
  ('ganciclovir', 'zidovudina',
    InteractionSeverity.major,
    'Ganciclovir (antiviral para CMV) inibe a síntese de DNA viral por competição com dGTP, causando mielosupresión dose-dependente; zidovudina (AZT) causa mielosupresión por inhibición da timidina quinase e toxicidad mitocondrial; a combinação causa mielosupresión sinérgica grave; em pacientes HIV+ com retinite por CMV (situação clínica típica), a combinação era frecuentemente limitante antes dos antirretrovirais modernos',
    'Anemia grave (Hb < 8 g/dL), neutropenia profunda (< 500/mm³), trombocitopenia; infecções oportunistas por mielosupresión; transfusões repetidas de hemácias',
    'Substituir AZT por tenofovir ou abacavir (menos mielossupressores) se ganciclovir IV for necesario. Monitorar hemograma completo duas vezes por semana. Usar valganciclovir oral quando possível (mielosupresión similar, mas administração mais cômoda). G-CSF pode ser usado para neutropenia grave',
    'Mielossupressão grave — Ganciclovir + Zidovudina (AZT): trocar AZT por tenofovir',
    EvidenceLevel.established,
    {RiskType.myelosuppression},
    [_kRefGG, _kRefFDA, _kRefUT]),

  // 292 — Didanosina + Allopurinol
  ('didanosina', 'alopurinol',
    InteractionSeverity.contraindicated,
    'Didanosina (DDI, análogo de nucleosídeo para HIV) é metabolizada pela xantina oxidase (XO) a hipoxantina; alopurinol inibe a XO, bloqueando o metabolismo da didanosina; os níveis de didanosina aumentam em 4x, causando toxicidad grave pelo acúmulo do fármaco ativo e de seus metabólitos na mitocôndria',
    'Neuropatia periférica grave por toxicidad mitocondrial (dor queimante nos pés), pancreatite grave, acidose lática, esteatose hepática; toxicidad dose-dependente amplificada em 4x',
    'Contraindicado. Didanosina está em desuso (substituída por tenofovir, abacavir), mas ainda pode ser usada em países de renda baixa. Se alopurinol for necesario em paciente em DDI, substituir a DDI. Nunca aumentar dose de alopurinol em paciente em DDI',
    'CONTRAINDICADO — Alopurinol + Didanosina: 4x de exposição = neuropatia e pancreatite',
    EvidenceLevel.established,
    {RiskType.increasedToxicity, RiskType.hepatotoxicity},
    [_kRefFDA, _kRefGG]),

  // 293 — Maraviroque + Potentes inibidores de CYP3A4
  ('maraviroque', 'cetoconazol',
    InteractionSeverity.major,
    'Maraviroque (antagonista de CCR5 para HIV) é substrato do CYP3A4; cetoconazol e outros potentes inibidores do CYP3A4 aumentam a AUC do maraviroque em 3–5x; com concentrações tão elevadas, o risco de hipotensão ortostática (efeito adverso principal do maraviroque) é substancialmente maior',
    'Hipotensão ortostática grave, síncope, quedas; tontura e lipotimia; na maioria dos casos a toxicidad é hemodinâmica',
    'Reduzir dose de maraviroque para 150 mg 2x/dia (em vez de 300 mg 2x/dia) quando em uso de inibidores potentes de CYP3A4 (cetoconazol, itraconazol, indinavir, saquinavir, lopinavir/r). Monitorar PA ortostática. A bula da Celsentri especifica estas combinações e ajustes de dose',
    'Hipotensão grave — Cetoconazol + Maraviroque: reduzir dose para 150 mg 2x/dia',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.plasmaLevel},
    [_kRefFDA, _kRefGG]),

  // 294 — Dolutegravir + Metformina (aumento de exposição)
  ('dolutegravir', 'metformina',
    InteractionSeverity.moderate,
    'Dolutegravir inibe o transportador renal OCT2 e MATE1/MATE2-K, responsáveis pela excreção tubular da metformina; estudos farmacocinéticos demonstraram que dolutegravir aumenta a AUC da metformina em 79% (quase dobra); em pacientes com IRC, o acúmulo de metformina é clinicamente relevante para acidose lática',
    'Acidose lática por acúmulo de metformina: náuseas, dor abdominal, dispneia, choque; pH < 7,35, lactato > 5 mmol/L; mortalidade de 30–50%',
    'Limitar dose de metformina a 1.000 mg/dia quando em uso de dolutegravir. Monitorar lactato e función renal a cada 3–6 meses. Em pacientes com TFG < 45 mL/min, contraindicar a combinação. Considerar iSGLT2 ou DPP-4i como alternativas com menor risco de acidose lática',
    'Acidose lática — Dolutegravir dobra exposição à metformina: dose máxima 1.000 mg/dia',
    EvidenceLevel.established,
    {RiskType.other, RiskType.plasmaLevel},
    [_kRefFDA, _kRefGG]),

  // 295 — Bictegravir + Margetuximabe (interações protocolares)
  ('bictegravir', 'rifampicina',
    InteractionSeverity.contraindicated,
    'Bictegravir (integrase strand transfer inhibitor, parte do Biktarvy) é substrato do CYP3A4 e P-gp; rifampicina induz ambos potentemente; a coadministração reduz a AUC do bictegravir em ~75%, resultando em concentrações subterapéuticas do antirretroviral e risco de falha virológica e resistência',
    'Falha virológica com rebote de carga viral HIV; seleção de mutações de resistência ao integrase (resistência cruzada a raltegravir, elvitegravir); progressão para AIDS',
    'Contraindicado. Usar rifabutina em vez de rifampicina para tuberculose em pacientes em bictegravir (rifabutina tem menor indução CYP3A4); requer ajuste de dose do regime. Consultar infectologista experiente em TARV para manejo da coinfecção TB/HIV',
    'CONTRAINDICADO — Rifampicina reduz bictegravir 75%: falha virológica e resistência ao HIV',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefFDA, _kRefGG]),

  // 296 — Naloxona + Buprenorfina (reversão parcial)
  ('naloxona', 'buprenorfina',
    InteractionSeverity.major,
    'Naloxona é antagonista puro de receptores opioides com alta afinidade; buprenorfina é agonista parcial com afinidade muito alta para receptores mu (maior que a naloxona em baixas doses); em pacientes em buprenorfina para dependência de opioides, a naloxona pode deslocar a buprenorfina parcialmente, precipitando abstinência moderada; em sobredose de buprenorfina, doses altas de naloxona são necessárias para reversão',
    'Síndrome de abstinência precipitada (moderada, não severa como com opioides plenos); redução insuficiente da depresión respiratoria em sobredose por buprenorfina em altas doses se naloxona em doses padrão',
    'Em emergência de sobredose de buprenorfina: usar naloxona em infusão contínua (não em bolus único) pois a buprenorfina tem meia-vida muito longa (24–72h). Iniciar naloxona 2 mg IV, titular até melhora da respiração. Em pacientes em tratamento com buprenorfina: evitar naloxona exceto em emergência vital',
    'Reversão parcial e abstinência — Naloxona + Buprenorfina: infusão contínua, não bolus único',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.other},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 297 — Flumazenil + Benzodiazepínicos de longa ação (rebote de sedação)
  ('flumazenil', 'diazepam',
    InteractionSeverity.moderate,
    'Flumazenil antagoniza competitivamente e reversivelmente os receptores GABA-A benzodiazepínicos; sua meia-vida é muito curta (40–80 minutos) comparada à de benzodiazepínicos de longa ação (diazepam: 20–100h; clobazam: 18–42h); após a eliminação do flumazenil, o efeito sedativo do BZD de longa duração retorna (ressedação)',
    'Ressedação após 1–2 horas com retorno da depresión respiratoria e confusão mental; risco de convulsiones de abstinência ao antagonizar BZD em paciente dependente',
    'Monitorar por pelo menos 2 horas após reversão com flumazenil em pacientes com BZD de longa ação. Considerar segunda dose ou infusão de flumazenil. Não dispensar o paciente após flumazenil sem período de observação. Em dependentes de BZD: usar flumazenil com cautela (convulsiones de abstinência)',
    'Ressedação — Flumazenil de meia-vida curta vs diazepam de longa ação: observar 2 horas',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.respiratoryDepression},
    [_kRefGG, _kRefKatz]),

  // 298 — Vitamina K + Varfarina (antagonismo intencional)
  ('vitamina_k', 'varfarina',
    InteractionSeverity.major,
    'Vitamina K é co-fator essencial para a carboxilação dos fatores de coagulação II, VII, IX e X; varfarina inibe a vitamina K epóxido redutase (VKOR), bloqueando a regeneração da vitamina K ativa; ao administrar vitamina K exógena, reverte-se o efeito anticoagulante da varfarina por repleção do cofator; a interação é farmacológica e dose-dependente',
    'Redução do INR com possível tromboembolismo em paciente com FA, prótese valvar ou TVP/EP se vitamina K em excesso; em supracoagulação (INR > 9): vitamina K intencional para correção',
    'Uso intencional para reverter supracoagulação ou sangrado. Para INR > 9 sem sangrado: vitamina K 2,5 mg VO. Para sangrado grave: vitamina K 10 mg IV + CCP (concentrado de complexo protrombínico) ou PFC. Alimentos ricos em vitamina K (espinafre, brócolis) afetam o INR crónicamente — dieta consistente',
    'Antagonismo intencional — Vitamina K reverte varfarina: dose ajustada ao grau de supracoagulação',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.thrombosis},
    [_kRefGG, _kRefKatz, _kRefMdx, _kRefUT]),

  // 299 — Protamina + Heparina (neutralização dose-dependente)
  ('protamina', 'heparina',
    InteractionSeverity.major,
    'Protamina (proteína catiônica de esperma de salmão) neutraliza a heparina ao formar um complexo iônico estável com heparina (aniônica) tornando-a farmacologicamente inativa; a interação é intencional e dose-dependente (1 mg de protamina neutraliza 100 UI de heparina); excesso de protamina (dose > 1,5 mg/100 UI heparina) causa paradoxalmente efeito anticoagulante e toxicidad cardiovascular',
    'Em dose correta: neutralização do efeito anticoagulante da heparina com possível trombosis se desnecessária; excesso de protamina: hipotensão grave, bradicardia, efeito anticoagulante paradoxal, vasoconstrição pulmonar; anafilaxia à protamina (especialmente em alérgicos a peixe)',
    'Calcular dose de protamina com base na dose de heparina administrada e no tempo desde a última dose (heparina tem meia-vida de 1–2h). Injeção lenta IV (máximo 5 mg/min) para minimizar toxicidad cardiovascular. Testar para alergia antes do uso eletivo. Ter epinefrina e corticoide disponíveis',
    'Neutralização dose-dependente — Protamina + Heparina: calcular dose exata para evitar excesso',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.thrombosis},
    [_kRefGG, _kRefFDA]),

  // 300 — Idarucizumabe (anticorpo) + Dabigatrana (reversão)
  ('idarucizumabe', 'dabigatrana',
    InteractionSeverity.major,
    'Idarucizumabe (Praxbind) é um anticorpo monoclonal fragmento Fab que se liga à dabigatrana com afinidade 350x maior que a trombina, revertendo completamente seu efeito anticoagulante em minutos; a interação é intencional e terapéutica; a reversão é imediata e dura pelo menos 24 horas; após a reversão, a dabigatrana livre no plasma é eliminada mas reservatórios teciduais podem liberar dabigatrana com rebote do efeito anticoagulante',
    'Ausência de efeito após administração: possível se dabigatranemia muito alta (sobredose) ou fatores interferentes; rebote anticoagulante em 12–24h por redistribuição do compartimento tecidual; trombosis por reversão excessiva em pacientes com alto risco trombótico',
    'Dose padrão: 5 g IV (2 frascos de 2,5 g) em infusão rápida ou bolus. Monitorar TT (tempo de trombina) ou TCE (teste de coagulação por ecarina) para confirmar reversão. Se rebote suspeito: segunda dose de idarucizumabe. Reiniciar anticoagulação assim que possível após hemostasia cirúrgica ou controle do sangrado',
    'Reversão de emergência — Idarucizumabe reverte dabigatrana: monitorar rebote em 12–24h',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.thrombosis},
    [_kRefFDA, _kRefGG, _kRefUT]),


];


const _termMap = <String, String>{
  // Anticoagulantes
'warfarina': 'warfarina', 'varfarina': 'warfarina', 'coumadin': 'warfarina',
'marevan': 'warfarina', 'warfarin': 'warfarina',
'heparina': 'heparina', 'enoxaparina': 'heparina', 'clexane': 'heparina',
'alisquireno': 'alisquireno', 'rasilez': 'alisquireno',

  // Antiagregantes
'aspirina': 'aspirina', 'aas': 'aspirina', 'ácido acetilsalicílico': 'aspirina',
'acido acetilsalicilico': 'aspirina', 'aspirin': 'aspirina',

  // AINEs
'ibuprofeno': 'ibuprofeno', 'advil': 'ibuprofeno', 'ibuprofen': 'ibuprofeno',
'naproxeno': 'naproxeno', 'naprosyn': 'naproxeno', 'naproxen': 'naproxeno',
'cetorolaco': 'cetorolaco', 'ketorolac': 'cetorolaco', 'toradol': 'cetorolaco',
'diclofenaco': 'aine', 'voltaren': 'aine', 'aine': 'aine', 'nsaid': 'aine',
'nimesulida': 'aine', 'meloxicam': 'aine', 'piroxicam': 'aine',
'indometacina': 'aine', 'celecoxib': 'aine', 'etoricoxib': 'aine',

  // Estatinas
'sinvastatina': 'sinvastatina', 'zocor': 'sinvastatina', 'simvastatina': 'sinvastatina',
'atorvastatina': 'atorvastatina', 'lipitor': 'atorvastatina', 'atorvastatin': 'atorvastatina',
'estatina': 'estatina',
'gemfibrozil': 'gemfibrozil', 'lopid': 'gemfibrozil',

  // Anti-hipertensivos
'enalapril': 'enalapril', 'renitec': 'enalapril', 'vasotec': 'enalapril',
'ramipril': 'enalapril', 'captopril': 'enalapril', 'lisinopril': 'enalapril',
'ieca': 'enalapril', 'perindopril': 'enalapril',
'losartana': 'losartana', 'cozaar': 'losartana', 'valsartana': 'losartana',
'olmesartana': 'losartana', 'ara-ii': 'losartana', 'irbesartana': 'losartana',
'telmisartana': 'losartana', 'micardis': 'losartana', 'candesartana': 'losartana',
'atacand': 'losartana', 'azilsartana': 'losartana', 'eprosartana': 'losartana',
'losartan': 'losartana', 'valsartan': 'losartana', 'olmesartan': 'losartana',
'irbesartan': 'losartana', 'telmisartan': 'losartana', 'candesartan': 'losartana',
'ara2': 'losartana', 'sartana': 'losartana', 'sartan': 'losartana',
'espironolactona': 'espironolactona', 'aldactone': 'espironolactona',
'furosemida': 'furosemida', 'lasix': 'furosemida',
'clonidina': 'clonidina', 'atensina': 'clonidina',

  // Betabloqueadores
'metoprolol': 'metoprolol', 'seloken': 'metoprolol', 'lopressor': 'metoprolol',
'atenolol': 'metoprolol', 'propranolol': 'propranolol', 'inderal': 'propranolol',
'carvedilol': 'metoprolol', 'bisoprolol': 'metoprolol', 'betabloqueador': 'metoprolol',

  // Bloqueadores dos canais de cálcio
'verapamil': 'verapamil', 'isoptin': 'verapamil',
'diltiazem': 'diltiazem', 'cardizem': 'diltiazem',

  // Antiarrítmicos
'amiodarona': 'amiodarona', 'cordarone': 'amiodarona',
'sotalol': 'sotalol', 'betapace': 'sotalol',
'digoxina': 'digoxina', 'lanoxin': 'digoxina',

  // Antibióticos
'metronidazol': 'metronidazol', 'flagyl': 'metronidazol',
'ciprofloxacino': 'ciprofloxacino', 'cipro': 'ciprofloxacino', 'ciprofloxacin': 'ciprofloxacino',
'levofloxacino': 'quinolona', 'levofloxacin': 'quinolona', 'quinolona': 'quinolona',
'claritromicina': 'claritromicina', 'klaricid': 'claritromicina', 'clarithromycin': 'claritromicina',
'eritromicina': 'eritromicina', 'erythromycin': 'eritromicina',
'azitromicina': 'azitromicina', 'zithromax': 'azitromicina',
'rifampicina': 'rifampicina', 'rifampin': 'rifampicina',
'gentamicina': 'aminoglicosideo', 'amicacina': 'aminoglicosideo', 'tobramicina': 'aminoglicosideo',
'aminoglicosídeo': 'aminoglicosideo',

  // Antifúngicos
'fluconazol': 'fluconazol', 'diflucan': 'fluconazol',

  // Antiepilépticos
'fenitoína': 'fenitoína', 'fenitoin': 'fenitoína',
'carbamazepina': 'carbamazepina', 'tegretol': 'carbamazepina',
'acido valproico': 'valproato', 'ácido valpróico': 'valproato',
'ácido valproico': 'valproato', 'valproico': 'valproato',
'valproato': 'valproato', 'depakote': 'valproato', 'depakene': 'valproato',
'divalproex': 'valproato', 'epival': 'valproato', 'stavzor': 'valproato',
'lamotrigina': 'lamotrigina', 'lamictal': 'lamotrigina',

  // Psicotrópicos
'tramadol': 'tramadol', 'tramal': 'tramadol',
'morfina': 'morfina', 'meperidina': 'opioide', 'codeína': 'opioide',
'fentanila': 'fentanila', 'oxicodona': 'opioide', 'opioide': 'opioide',
'benzodiazepínico': 'benzodiazepínico', 'diazepam': 'benzodiazepínico',
'lorazepam': 'benzodiazepínico', 'alprazolam': 'benzodiazepínico',
'clonazepam': 'benzodiazepínico', 'rivotril': 'benzodiazepínico',
'bromazepam': 'benzodiazepínico', 'lexotan': 'benzodiazepínico',
'nitrazepam': 'benzodiazepínico', 'triazolam': 'benzodiazepínico',
  // midazolam tem IDs diretos no banco → ID canônico próprio (NÃO benzodiazepínico)
'midazolam': 'midazolam', 'dormicum': 'midazolam', 'versed': 'midazolam',
'haloperidol': 'haloperidol', 'haldol': 'haloperidol',
'quetiapina': 'quetiapina', 'seroquel': 'quetiapina',
'ssri': 'isrs', 'isrs': 'isrs',
'fluoxetina': 'fluoxetina', 'prozac': 'fluoxetina', 'sertralina': 'isrs', 'zoloft': 'isrs',
'escitalopram': 'isrs', 'lexapro': 'isrs', 'paroxetina': 'isrs', 'paxil': 'isrs',
'citalopram': 'isrs', 'celexa': 'isrs', 'fluvoxamina': 'isrs', 'luvox': 'isrs',
'venlafaxina': 'isrs', 'effexor': 'isrs',
'imao': 'imao', 'fenelzina': 'imao', 'tranilcipromina': 'imao',
'linezolida': 'linezolida', 'linezolid': 'linezolida', 'zyvox': 'linezolida',
'amitriptilina': 'amitriptilina', 'laroxyl': 'amitriptilina', 'tryptanol': 'amitriptilina',
'atropina': 'atropina',
'litio': 'carbonato de litio', 'lítio': 'carbonato de litio',
'carbonato de litio': 'carbonato de litio',

  // Hipoglucemiantes
'metformina': 'metformina', 'glifage': 'metformina', 'glucoformin': 'metformina',
'glibenclamida': 'glibenclamida', 'daonil': 'glibenclamida',
'insulina': 'insulina',
'dapagliflozina': 'dapagliflozina', 'forxiga': 'dapagliflozina',
'empagliflozina': 'dapagliflozina', 'jardiance': 'dapagliflozina',
'contraste': 'contraste iodado', 'contraste iodado': 'contraste iodado',

  // Imunossupressores / Gota
'ciclosporina': 'ciclosporina', 'neoral': 'ciclosporina', 'sandimmun': 'ciclosporina',
'alopurinol': 'alopurinol', 'zyloric': 'alopurinol',
'azatioprina': 'azatioprina', 'imuran': 'azatioprina',
'colchicina': 'colchicina', 'colchis': 'colchicina',

  // Cardiovascular misc.
'sildenafila': 'sildenafila', 'viagra': 'sildenafila', 'sildenafil': 'sildenafila',
'tadalafila': 'sildenafila', 'cialis': 'sildenafila',
'nitrato': 'nitrato', 'nitroglicerina': 'nitrato', 'isossorbida': 'nitrato',
'mononitrato': 'nitrato', 'dinitrato': 'nitrato',
'sacubitrila': 'sacubitrila', 'sacubitril': 'sacubitrila', 'entresto': 'sacubitrila',
'alfa-bloqueador': 'alfa-bloqueador', 'doxazosina': 'alfa-bloqueador',
'tansulosina': 'alfa-bloqueador', 'prazosina': 'alfa-bloqueador',
'teofilina': 'teofilina', 'aminofilina': 'teofilina',
'ondansetrona': 'ondansetrona', 'zofran': 'ondansetrona',
'clopidogrel': 'clopidogrel', 'plavix': 'clopidogrel',

  // Tireóide
'levotiroxina': 'levotiroxina', 'synthroid': 'levotiroxina', 'puran': 'levotiroxina',
'euthyrox': 'levotiroxina',

  // Suplementos / Quelantes
'carbonato de calcio': 'carbonato de calcio', 'cálcio': 'carbonato de calcio',
'calcio': 'carbonato de calcio', 'calcium': 'carbonato de calcio',
'sulfato ferroso': 'sulfato ferroso', 'ferro': 'sulfato ferroso',
'cloreto de potassio': 'cloreto de potassio', 'kcl': 'cloreto de potassio',
'potassio': 'cloreto de potassio',

  // Corticosteroides
'dexametasona': 'dexametasona', 'decadron': 'dexametasona',
'prednisona': 'dexametasona', 'prednisolona': 'dexametasona',
'hidrocortisona': 'dexametasona',

  // Diuréticos
'hidroclorotiazida': 'hidroclorotiazida', 'hctz': 'hidroclorotiazida',
'clortalidona': 'hidroclorotiazida',

  // Anticoncepcionais
'anticoncepcional': 'anticoncepcional', 'anticonceptivo': 'anticoncepcional',
'pilula': 'anticoncepcional', 'pílula': 'anticoncepcional',
'etinilestradiol': 'anticoncepcional', 'levonorgestrel': 'anticoncepcional',

  // Vancomicina
'vancomicina': 'vancomicina', 'vancocin': 'vancomicina',

  // Outros
'antiácido': 'antiácido', 'hidróxido': 'antiácido',
'omeprazol': 'omeprazol', 'losec': 'omeprazol',
'pantoprazol': 'pantoprazol', 'pantozol': 'pantoprazol', 'tecta': 'pantoprazol',
'esomeprazol': 'esomeprazol', 'nexium': 'esomeprazol',
'álcool': 'alcool', 'alcool': 'alcool', 'bebida': 'alcool',
'gemfibrozila': 'gemfibrozil',

  // ── NOVOS — Merge v2 ───────────────────────────────────────────────────────

  // Antiarrítmicos novos
'dronedarona': 'dronedarona', 'multaq': 'dronedarona',
'ivabradina': 'ivabradina', 'procoralan': 'ivabradina', 'corlanor': 'ivabradina',
'ranolazina': 'ranolazina', 'ranexa': 'ranolazina',

  // Anti-hipertensivos novos
'eplerenona': 'eplerenona', 'inspra': 'eplerenona',
'candesartán': 'losartana',
'riociguate': 'riociguate', 'adempas': 'riociguate',

  // Anticoagulantes / antídotos
'fondaparinux': 'fondaparinux', 'arixtra': 'fondaparinux',
'andexanet': 'andexanet alfa', 'ondexxya': 'andexanet alfa', 'andexanet alfa': 'andexanet alfa',
'idarucizumabe': 'idarucizumabe', 'praxbind': 'idarucizumabe',

  // Antibióticos novos
'daptomicina': 'daptomicina', 'cubicin': 'daptomicina',
'ceftarolina': 'ceftarolina', 'zinforo': 'ceftarolina', 'teflaro': 'ceftarolina',
'tedizolida': 'tedizolida', 'sivextro': 'tedizolida',
'cefiderocol': 'cefiderocol', 'fetcroja': 'cefiderocol',
'sulfametoxazol trimetoprima iv': 'sulfametoxazol_tmp_iv',
'smx-tmp iv': 'sulfametoxazol_tmp_iv', 'bactrim iv': 'sulfametoxazol_tmp_iv',

  // Antivirais COVID-19
'nirmatrelvir': 'ritonavir', 'paxlovid': 'ritonavir',
'nirmatrelvir ritonavir': 'ritonavir',
'ritonavir': 'ritonavir', 'norvir': 'ritonavir',
'molnupiravir': 'molnupiravir', 'lagevrio': 'molnupiravir',

  // Antifúngicos novos
'isavuconazol': 'isavuconazol', 'cresemba': 'isavuconazol',
'isavuconazonium': 'isavuconazol',

  // Antiepiléticos novos
'perampanel': 'perampanel', 'fycompa': 'perampanel',
'brivaracetam': 'brivaracetam', 'briviact': 'brivaracetam',

  // Antipsicóticos novos
'aripiprazol': 'aripiprazol', 'abilify': 'aripiprazol', 'aripiprazole': 'aripiprazol',

  // Antidepressivos / TDAH
'bupropiona': 'bupropiona', 'wellbutrin': 'bupropiona', 'zyban': 'bupropiona',
'bupropion': 'bupropiona',
'lisdexanfetamina': 'lisdexanfetamina', 'vyvanse': 'lisdexanfetamina',

  // Hipoglucemiantes / Obesidade novos
'semaglutida': 'semaglutida', 'ozempic': 'semaglutida', 'wegovy': 'semaglutida',
'rybelsus': 'semaglutida', 'semaglutide': 'semaglutida',
'tirzepatida': 'tirzepatida', 'mounjaro': 'tirzepatida', 'zepbound': 'tirzepatida',
'tirzepatide': 'tirzepatida',
'dulaglutida': 'semaglutida', 'trulicity': 'semaglutida', 'dulaglutide': 'semaglutida',
'canagliflozina': 'canagliflozina', 'invokana': 'canagliflozina',
'finerenona': 'finerenona', 'kerendia': 'finerenona',
'sulfonilureia': 'sulfonilureia', 'glipizida': 'sulfonilureia',
'glimepirida': 'sulfonilureia', 'gliclazida': 'sulfonilureia',

  // Antiosteoporose
'denosumabe': 'denosumabe', 'prolia': 'denosumabe', 'xgeva': 'denosumabe',
'denosumab': 'denosumabe',

  // DII / Reumatologia
'vedolizumabe': 'vedolizumabe', 'entyvio': 'vedolizumabe', 'vedolizumab': 'vedolizumabe',
'natalizumabe': 'natalizumabe', 'tysabri': 'natalizumabe',
'tofacitinibe': 'tofacitinibe', 'xeljanz': 'tofacitinibe', 'tofacitinib': 'tofacitinibe',

  // Gastro
'rifaximina': 'rifaximina', 'xifaxan': 'rifaximina', 'rifaximin': 'rifaximina',

  // Respiratório / Biológicos
'dupilumabe': 'dupilumabe', 'dupixent': 'dupilumabe', 'dupilumab': 'dupilumabe',
'mepolizumabe': 'mepolizumabe', 'nucala': 'mepolizumabe', 'mepolizumab': 'mepolizumabe',
'nintedanibe': 'nintedanibe', 'ofev': 'nintedanibe', 'nintedanib': 'nintedanibe',
'corticosteroide sistemico': 'corticosteroide sistemico',
'prednisona sistemica': 'corticosteroide sistemico',
'prednisolona sistemica': 'corticosteroide sistemico',

  // Hematologia
'ruxolitinibe': 'ruxolitinibe', 'jakafi': 'ruxolitinibe', 'jakavi': 'ruxolitinibe',
'ruxolitinib': 'ruxolitinibe',
'eltrombopague': 'eltrombopague', 'revolade': 'eltrombopague', 'promacta': 'eltrombopague',
'eltrombopag': 'eltrombopague',

  // Biológicos / Imunológicos
'tocilizumabe': 'tocilizumabe', 'actemra': 'tocilizumabe', 'tocilizumab': 'tocilizumabe',
'baricitinibe': 'baricitinibe', 'olumiant': 'baricitinibe', 'baricitinib': 'baricitinibe',
'belimumabe': 'belimumabe', 'benlysta': 'belimumabe', 'belimumab': 'belimumabe',

  // Vacinas (genérico para interações com imunossupressores)
'vacinas vivas': 'vacinas vivas', 'vacina viva': 'vacinas vivas',
'mmr': 'vacinas vivas', 'febre amarela': 'vacinas vivas',
'varicela vacina': 'vacinas vivas', 'bcg': 'vacinas vivas',

  // ── Lote 3 — novos fármacos ───────────────────────────────────────────────

  // Cardiovascular — estatinas (novos aliases; atorvastatina/lipitor já existem acima)
'torvacard': 'atorvastatina',

  // Cardiovascular — diuréticos (clortalidona/hidroclorotiazida/hctz já existem acima)
'clortalidone': 'hidroclorotiazida', 'hidrodiuril': 'hidroclorotiazida',

  // Cardiovascular — anti-hipertensivos (clonidina/atensina/isossorbida/nitrato já existem)
'clonidine': 'clonidina',
'monoísordil': 'nitrato', 'isordil': 'nitrato',
'dinitrato de isossorbida': 'nitrato', 'mononitrato de isossorbida': 'nitrato',
'labetalol': 'labetalol', 'trandate': 'labetalol',

  // Cardiovascular — bloqueadores de canal de cálcio (verapamil/isoptin/diltiazem/cardizem já existem)
'verapamilo': 'verapamil', 'balcor': 'diltiazem',

  // Cardiovascular — inotrópicos/vasoativos
'levosimendan': 'levosimendan', 'simdax': 'levosimendan',
'milrinona': 'milrinona', 'primacor': 'milrinona',
'esmolol': 'esmolol', 'brevibloc': 'esmolol',
'nitroprussiato': 'nitroprussiato', 'nipride': 'nitroprussiato',
'nitroprussiato de sódio': 'nitroprussiato',

  // Neurologia / Antiepilépticos (fenitoína/fenitoin/lamotrigina/lamictal já existem acima)
'gabapentina': 'gabapentina', 'neurontin': 'gabapentina', 'gabapentin': 'gabapentina',
'gabatina': 'gabapentina', 'gabaneurin': 'gabapentina',
'fenobarbital': 'fenobarbital', 'gardenal': 'fenobarbital', 'phenobarbital': 'fenobarbital',
'hidantal': 'fenitoína', 'phenytoin': 'fenitoína', 'dilantin': 'fenitoína',
'lamotrigine': 'lamotrigina',
'topiramato': 'topiramato', 'topamax': 'topiramato', 'topiramate': 'topiramato',
'acetazolamida': 'acetazolamida', 'diamox': 'acetazolamida', 'acetazolamide': 'acetazolamida',

  // Psiquiatria / Antidepressivos (sertralina já mapeada como ssri acima)
'sertraline': 'isrs', 'serenata': 'isrs', 'venlafaxine': 'isrs',
'paroxetine': 'isrs', 'fluvoxamine': 'isrs', 'citaloprame': 'isrs',
'mirtazapina': 'mirtazapina', 'remeron': 'mirtazapina', 'mirtazapine': 'mirtazapina',
'zolvera': 'mirtazapina',

  // Psiquiatria / Antipsicóticos
'olanzapina': 'olanzapina', 'zyprexa': 'olanzapina', 'olanzapine': 'olanzapina',
'zydis': 'olanzapina',

  // Psiquiatria / Ansiolíticos (clonazepam e rivotril já mapeados acima)
'zolpidem': 'benzodiazepínico', 'stilnox': 'benzodiazepínico', 'zolpidem tartarato': 'benzodiazepínico',

  // Anestesia / UTI (fentanila já mapeada como opioide acima)
'propofol': 'propofol', 'diprivan': 'propofol',
'fentanil': 'opioide', 'duragesic': 'opioide',
'dexmedetomidina': 'dexmedetomidina', 'precedex': 'dexmedetomidina', 'dexmedetomidine': 'dexmedetomidina',
'rocurônio': 'rocurônio', 'esmeron': 'rocurônio', 'rocuronium': 'rocurônio',
'naloxona': 'naloxona', 'narcan': 'naloxona', 'naloxone': 'naloxona',
'lidocaína': 'lidocaína', 'xylocaine': 'lidocaína', 'xylestesin': 'lidocaína',
'lidocaine': 'lidocaína',

  // Infectologia (amicacina já mapeada como aminoglicosideo acima)
'tigeciclina': 'tigeciclina', 'tygacil': 'tigeciclina', 'tigecycline': 'tigeciclina',
'fosfomicina': 'fosfomicina', 'monurol': 'fosfomicina', 'fosfocin': 'fosfomicina',
'fosfomycin': 'fosfomicina',
'valaciclovir': 'valaciclovir', 'valtrex': 'valaciclovir', 'valacyclovir': 'valaciclovir',
'amikin': 'aminoglicosideo', 'amikacin': 'aminoglicosideo',
'ceftolozana': 'ceftolozana', 'zerbaxa': 'ceftolozana',
'ceftolozana tazobactam': 'ceftolozana', 'ceftolozane': 'ceftolozana',

  // Antifúngicos (fluconazol/diflucan já mapeados acima)
'fluconazole': 'fluconazol', 'zoltec': 'fluconazol',

  // Endocrinologia / Hipoglucemiantes (glibenclamida/daonil já mapeados acima)
'glyburide': 'glibenclamida', 'diabeta': 'glibenclamida',

  // Gastroenterologia
'racecadotril': 'racecadotril', 'tiorfan': 'racecadotril', 'hidrasec': 'racecadotril',
'levosulpirida': 'levosulpirida', 'levopraid': 'levosulpirida',
'simeticona': 'simeticona', 'luftal': 'simeticona', 'mylicon': 'simeticona',
'dimeticona': 'simeticona',

  // Hematologia / Vitaminas
'etamsilato': 'etamsilato', 'dicynone': 'etamsilato', 'etamsylate': 'etamsilato',
'tiamina': 'tiamina', 'vitamina b1': 'tiamina', 'benerva': 'tiamina',
'thiamine': 'tiamina',
'piridoxina': 'piridoxina', 'vitamina b6': 'piridoxina', 'pyridoxine': 'piridoxina',

  // Respiratório / Mucolíticos
'ambroxol': 'ambroxol', 'mucosolvan': 'ambroxol', 'ambroxol hcl': 'ambroxol',
'acebrofilina': 'acebrofilina', 'bronchoton': 'acebrofilina',
'salbutamol': 'salbutamol', 'ventolin': 'salbutamol', 'albuterol': 'salbutamol',
'aerolin': 'salbutamol', 'salbutamol gotas': 'salbutamol',

  // Dermatologia / Tópicos
'sulfadiazina de prata': 'sulfadiazina de prata', 'silverex': 'sulfadiazina de prata',
'sulfadiazina': 'sulfadiazina de prata',
'mupirocina': 'mupirocina', 'bactroban': 'mupirocina', 'mupirocin': 'mupirocina',
'permetrina': 'permetrina', 'keltrina': 'permetrina', 'permethrin': 'permetrina',
'clobetasol': 'clobetasol', 'temovate': 'clobetasol', 'clobetasol propionato': 'clobetasol',
'fexofenadina': 'fexofenadina', 'allegra': 'fexofenadina', 'fexofenadine': 'fexofenadina',

  // Analgesia
'clonixinato': 'clonixinato', 'dorilax': 'clonixinato', 'clonixin': 'clonixinato',
'clonixinato de lisina': 'clonixinato',

  // Nefrologia
'kayexalate': 'kayexalate', 'poliestireno sulfonato': 'kayexalate',
'resina de troca iônica': 'kayexalate', 'sorcal': 'kayexalate',

  // ── Auditoria Lote 4 — aliases novos ──────────────────────────────────────

  // AOD — anticoagulantes orais diretos
'apixabana': 'apixabana', 'eliquis': 'apixabana', 'apixaban': 'apixabana',
'rivaroxabana': 'rivaroxabana', 'xarelto': 'rivaroxabana', 'rivaroxaban': 'rivaroxabana',
'dabigatrana': 'dabigatrana', 'pradaxa': 'dabigatrana', 'dabigatran': 'dabigatrana',
'edoxabana': 'apixabana', 'lixiana': 'apixabana', 'edoxaban': 'apixabana',
'aod': 'apixabana', 'noac': 'apixabana', 'doac': 'apixabana',

  // Imunossupressores — tacrolimo / FK506
'tacrolimo': 'tacrolimo', 'prograf': 'tacrolimo', 'tacrolimus': 'tacrolimo',
'fk506': 'tacrolimo', 'advagraf': 'tacrolimo', 'envarsus': 'tacrolimo',

  // Opioides — metadona
'metadona': 'metadona', 'methadone': 'metadona', 'metadon': 'metadona',
'dolophine': 'metadona',

  // Antibióticos — sulfametoxazol-trimetoprima
'sulfametoxazol': 'sulfametoxazol', 'smx-tmp': 'sulfametoxazol',
'sulfametoxazol trimetoprima': 'sulfametoxazol', 'trimetoprima': 'sulfametoxazol',
'cotrimoxazol': 'sulfametoxazol', 'bactrim': 'sulfametoxazol',
'septra': 'sulfametoxazol', 'trimethoprim': 'sulfametoxazol',
'tmp-smx': 'sulfametoxazol', 'smz-tmp': 'sulfametoxazol',

  // Analgésicos — paracetamol / acetaminofeno
'paracetamol': 'paracetamol', 'acetaminofeno': 'paracetamol', 'tylenol': 'paracetamol',
'acetaminophen': 'paracetamol', 'acetaminofen': 'paracetamol',
'dipirona': 'paracetamol', 'novalgina': 'paracetamol', 'metamizol': 'paracetamol',

  // Antibióticos — piperacilina-tazobactam
'piperacilina_tazobactam': 'piperacilina-tazobactam',
'piperacilina-tazobactam': 'piperacilina-tazobactam',
'piperacilina tazobactam': 'piperacilina-tazobactam',
'pip-tazo': 'piperacilina-tazobactam', 'tazocin': 'piperacilina-tazobactam',
'zosyn': 'piperacilina-tazobactam', 'tazobac': 'piperacilina-tazobactam',

  // Quimioterapia — cisplatina
'cisplatina': 'cisplatina', 'cisplatin': 'cisplatina', 'platinol': 'cisplatina',

  // Estatinas — rosuvastatina
'rosuvastatina': 'rosuvastatina', 'rosuvastatin': 'rosuvastatina',
'vivacor': 'rosuvastatina', 'rosuvas': 'rosuvastatina', 'crestor': 'rosuvastatina', 'ezallor': 'rosuvastatina',

  // Fibratos
'fenofibrato': 'fenofibrato', 'tricor': 'fenofibrato', 'lipanthyl': 'fenofibrato',
'fenofibrate': 'fenofibrato', 'triglide': 'fenofibrato',

  // IMAO reversível (moclobemida)
'imao_reversivel': 'imao reversivel', 'imao reversivel': 'imao reversivel',
'moclobemida': 'imao reversivel', 'aurorix': 'imao reversivel',
'moclobemide': 'imao reversivel', 'inibidor mao reversivel': 'imao reversivel',
'rima': 'imao reversivel',

  // Lítio — aliases adicionais (ID canônico: 'carbonato de litio')
'li': 'carbonato de litio', 'lithium': 'carbonato de litio',
'quilonorm': 'carbonato de litio', 'carbolithium': 'carbonato de litio',
'litiocar': 'carbonato de litio',

  // (valproato e betabloqueador já mapeados acima — sem duplicatas)

  // ── Lote 6 — Mucolíticos, Antitussivos e Gripe ────────────────────────────

  // Mucolíticos
'bromhexina': 'bromhexina', 'bisolvon': 'bromhexina', 'bromhexine': 'bromhexina',
'carbocisteina': 'carbocisteina', 'carbocisteína': 'carbocisteina',
'mucosol': 'carbocisteina', 'rhinathiol': 'carbocisteina',
'guaifenesina': 'guaifenesina', 'guaifenesin': 'guaifenesina',
'robitussin': 'guaifenesina', 'guaiacolato': 'guaifenesina',

  // Antitussivos
'dextrometorfano': 'dextrometorfano', 'dextromethorphan': 'dextrometorfano',
'dxm': 'dextrometorfano', 'robitussin dm': 'dextrometorfano',
'levodropropizina': 'levodropropizina', 'antuss': 'levodropropizina',
'cloperastina': 'cloperastina', 'seki': 'cloperastina', 'cloperastine': 'cloperastina',
'butamirato': 'butamirato', 'sinecod': 'butamirato', 'butamirate': 'butamirato',

  // Descongestionantes
'pseudoefedrina': 'pseudoefedrina', 'sudafed': 'pseudoefedrina',
'pseudoephedrine': 'pseudoefedrina', 'afrinol': 'pseudoefedrina',
'fenilefrina': 'fenilefrina', 'sudafed pe': 'fenilefrina',
'phenylephrine': 'fenilefrina', 'neo-synephrine': 'fenilefrina',

  // Anti-histamínicos
'cetirizina': 'cetirizina', 'zyrtec': 'cetirizina', 'cetirizine': 'cetirizina',
'reactine': 'cetirizina', 'cetizine': 'cetirizina',

  // Antiviral gripe
'zanamivir': 'zanamivir', 'relenza': 'zanamivir', 'zanamivir inalado': 'zanamivir',

  // Antagonista leucotrienos
'montelukast': 'montelukast', 'singulair': 'montelukast', 'montelukaste': 'montelukast',
'airon': 'montelukast',

  // ── Lote 5 — aliases para os 159 novos pares ──────────────────────────────

  // Antiagregantes — ticagrelor
'ticagrelor': 'ticagrelor', 'brilinta': 'ticagrelor', 'brilique': 'ticagrelor',

  // Antieméticos — domperidona
'domperidona': 'domperidona', 'motilium': 'domperidona', 'domperidone': 'domperidona',

  // Antipsicóticos — clorpromazina, risperidona
'clorpromazina': 'clorpromazina', 'amplictil': 'clorpromazina', 'thorazine': 'clorpromazina',
'chlorpromazine': 'clorpromazina',
'risperidona': 'risperidona', 'risperdal': 'risperidona', 'risperidone': 'risperidona',

  // Antidepressivos — duloxetina
'duloxetina': 'duloxetina', 'cymbalta': 'duloxetina', 'duloxetine': 'duloxetina',
'ariclaim': 'duloxetina',

  // Opioides — petidina / meperidina
  // ('meperidina' já mapeada como 'opioide' acima — não duplicar)
'petidina': 'petidina', 'meperidine': 'petidina',
'demerol': 'petidina', 'pethidine': 'petidina',

  // Hematologia — ácido tranexâmico, alteplase
'acido tranexamico': 'acido tranexamico', 'ácido tranexâmico': 'acido tranexamico',
'tranexamico': 'acido tranexamico', 'tranexamic acid': 'acido tranexamico',
'transamin': 'acido tranexamico', 'hemoblock': 'acido tranexamico',
'alteplase': 'alteplase', 'actilyse': 'alteplase', 'activase': 'alteplase',
'rt-pa': 'alteplase', 'rtpa': 'alteplase', 'tpa': 'alteplase',

  // Antirreumáticos / Antimaláricos — hidroxicloroquina
'hidroxicloroquina': 'hidroxicloroquina', 'hydroxychloroquine': 'hidroxicloroquina',
'plaquinol': 'hidroxicloroquina', 'reuquinol': 'hidroxicloroquina',
'plaquenil': 'hidroxicloroquina',

  // Imunossupressores / Oncológicos — metotrexato
'metotrexato': 'metotrexato', 'methotrexate': 'metotrexato', 'mtx': 'metotrexato',
'methofar': 'metotrexato', 'ledertrexate': 'metotrexato',

  // ── Lotes 7–10 — aliases realmente novos (sem duplicatas com lotes anteriores) ──

  // Dextrometorfano — aliases extras novos
'vick 44': 'dextrometorfano', 'vick44': 'dextrometorfano',
'neotoss': 'dextrometorfano', 'trimedal': 'dextrometorfano',

  // Pseudoefedrina — aliases extras novos
'actifed': 'pseudoefedrina', 'resfenol': 'pseudoefedrina',
'rhinosoro': 'pseudoefedrina',

  // Álcool — aliases extras novos
'bebida alcoolica': 'alcool',

  // Gemfibrozila — aliases extras novos
'jezil': 'gemfibrozila',

  // Amitriptilina — aliases extras novos
'amitriptyline': 'amitriptilina', 'amytril': 'amitriptilina',
'adepril': 'amitriptilina',

  // Propafenona (novo — Lote 8)
'propafenona': 'propafenona', 'propafenone': 'propafenona',
'rytmonorm': 'propafenona', 'ritmonorm': 'propafenona',

  // Flecainida (novo — Lote 8)
'flecainida': 'flecainida', 'flecainide': 'flecainida',
'tambocor': 'flecainida',

  // Dobutamina (novo — Lote 8)
'dobutamina': 'dobutamina', 'dobutamine': 'dobutamina',
'dobutrex': 'dobutamina',

  // Adenosina (novo — Lote 8)
'adenosina': 'adenosina', 'adenosine': 'adenosina',
'adenocor': 'adenosina', 'adenocard': 'adenosina',

  // Ácido valproico — aliases extras novos
'valpakine': 'acido valproico', 'valproic acid': 'acido valproico',
'valproato de sodio': 'acido valproico', 'valproato de sódio': 'acido valproico',

  // Levetiracetam (novo — Lote 9)
'levetiracetam': 'levetiracetam', 'levetiracetame': 'levetiracetam',
'keppra': 'levetiracetam', 'spritam': 'levetiracetam',

  // Levodopa + Carbidopa (novo — Lote 9)
'levodopa': 'levodopa carbidopa', 'carbidopa': 'levodopa carbidopa',
'levodopa carbidopa': 'levodopa carbidopa', 'sinemet': 'levodopa carbidopa',
'prolopa': 'levodopa carbidopa', 'stalevo': 'levodopa carbidopa',

  // Pramipexol (novo — Lote 9)
'pramipexol': 'pramipexol', 'pramipexole': 'pramipexol',
'mirapex': 'pramipexol', 'sifrol': 'pramipexol',

  // Leflunomida (novo — Lote 10)
'leflunomida': 'leflunomida', 'leflunomide': 'leflunomida',
'arava': 'leflunomida', 'leflunomida sanofi': 'leflunomida',

  // Adalimumabe (novo — Lote 10)
'adalimumabe': 'adalimumabe', 'adalimumab': 'adalimumabe',
'humira': 'adalimumabe', 'adalimumabe pfizer': 'adalimumabe',
'hyrimoz': 'adalimumabe', 'hadlima': 'adalimumabe',

  // Etanercepte (novo — Lote 10)
'etanercepte': 'etanercepte', 'etanercept': 'etanercepte',
'enbrel': 'etanercepte', 'benepali': 'etanercepte',
  // ═══════════════════════════════════════════════════════════════
  // NOVOS TERMOS — IDs canônicos para todas as 300 novas interações
  // ═══════════════════════════════════════════════════════════════

  // Paxlovid / antivirais COVID
  'ritonavir_boost': 'paxlovid',

  // Antipsicóticos novos
'lurasidona': 'lurasidona', 'latuda': 'lurasidona',
'pimavanserina': 'pimavanserina', 'nuplazid': 'pimavanserina',
'asenapina': 'asenapina', 'sycrest': 'asenapina',
'paliperidona': 'paliperidona', 'invega': 'paliperidona',

  // Antidiabéticos novos
'liraglutida': 'liraglutida', 'victoza': 'liraglutida',
'exenatida': 'exenatida', 'byetta': 'exenatida',
'sitagliptina': 'sitagliptina', 'januvia': 'sitagliptina',

  // Triptanos / enxaqueca
'sumatriptano': 'sumatriptano', 'imigran': 'sumatriptano',
'eletriptano': 'eletriptano', 'relpax': 'eletriptano',
'rimegepant': 'rimegepant', 'nurtec': 'rimegepant',
'atogepant': 'atogepant', 'qulipta': 'atogepant',
'lasmiditano': 'lasmiditano', 'reyvow': 'lasmiditano',

  // EII / biológicos
'ozanimod': 'ozanimod', 'zeposia': 'ozanimod',
'upadacitinibe': 'upadacitinibe', 'rinvoq': 'upadacitinibe',
'ustekinumabe': 'ustekinumabe', 'stelara': 'ustekinumabe',
'certolizumabe': 'certolizumabe', 'cimzia': 'certolizumabe',
'secuquinumabe': 'secuquinumabe', 'cosentyx': 'secuquinumabe',

  // Dislipidemia
'bempedoico': 'bempedoico', 'nexletol': 'bempedoico',
'icosapento': 'icosapento', 'vascepa': 'icosapento',
'evolocumabe': 'evolocumabe', 'repatha': 'evolocumabe',
'alirocumabe': 'alirocumabe', 'praluent': 'alirocumabe',
'inclisiran': 'inclisiran', 'leqvio': 'inclisiran',
'volanesorsen': 'volanesorsen', 'waylivra': 'volanesorsen',

  // Alzheimer / neurologia
'donepezilo': 'donepezilo', 'aricept': 'donepezilo',
'memantina': 'memantina', 'ebixa': 'memantina',
'rivastigmina': 'rivastigmina', 'exelon': 'rivastigmina',
'lecanemabe': 'lecanemabe', 'leqembi': 'lecanemabe',

  // Asma / DPOC / HAP
'indacaterol': 'indacaterol', 'onbrez': 'indacaterol',
'tiotropio': 'tiotropio', 'spiriva': 'tiotropio',
'aclidinio': 'aclidinio', 'genuair': 'aclidinio',
'roflumilast': 'roflumilast', 'daxas': 'roflumilast',
'omalizumabe': 'omalizumabe', 'xolair': 'omalizumabe',
'tezepelumabe': 'tezepelumabe', 'tezspire': 'tezepelumabe',
'ivacaftor': 'ivacaftor', 'kalydeco': 'ivacaftor',
'elexacaftor': 'elexacaftor', 'trikafta': 'elexacaftor',
'bosentana': 'bosentana', 'tracleer': 'bosentana',
'iloprost': 'iloprost', 'ventavis': 'iloprost',
'selexipague': 'selexipague', 'uptravi': 'selexipague',
'macitentan': 'macitentan', 'opsumit': 'macitentan',
'pirfenidona': 'pirfenidona', 'esbriet': 'pirfenidona',

  // Hepatite C / antivirais
'sofosbuvir': 'sofosbuvir', 'sovaldi': 'sofosbuvir',
'ledipasvir': 'ledipasvir', 'harvoni': 'ledipasvir',
'velpatasvir': 'velpatasvir', 'epclusa': 'velpatasvir',
'glecaprevir': 'glecaprevir', 'maviret': 'glecaprevir',
'entecavir': 'entecavir', 'baraclude': 'entecavir',

  // HIV / antivirais
'maraviroque': 'maraviroque', 'selzentry': 'maraviroque',
'dolutegravir': 'dolutegravir', 'tivicay': 'dolutegravir',
'bictegravir': 'bictegravir', 'biktarvy': 'bictegravir',
'didanosina': 'didanosina', 'ddi': 'didanosina',
'zidovudina': 'zidovudina', 'azt': 'zidovudina', 'retrovir': 'zidovudina',
'abacavir': 'abacavir', 'ziagen': 'abacavir',
'lamivudina': 'lamivudina', '3tc': 'lamivudina', 'epivir': 'lamivudina',
'tenofovir': 'tenofovir', 'viread': 'tenofovir', 'taf': 'tenofovir', 'tdf': 'tenofovir',

  // Antibióticos novos
'colistina': 'colistina', 'polymyxin_e': 'colistina',
'polimixina_b': 'polimixina_b', 'polymyxin_b': 'polimixina_b',
  'tobi': 'tobramicina',
'amikacina': 'amikacina',

  // Antituberculosos novos
'bedaquilina': 'bedaquilina', 'sirturo': 'bedaquilina',
'delamanida': 'delamanida', 'deltyba': 'delamanida',
'pirazinamida': 'pirazinamida', 'pyrazinamide': 'pirazinamida',
'etambutol': 'etambutol', 'myambutol': 'etambutol',

  // Antifúngicos
'voriconazol': 'voriconazol', 'vfend': 'voriconazol',
'posaconazol': 'posaconazol', 'noxafil': 'posaconazol',
'caspofungina': 'caspofungina', 'cancidas': 'caspofungina',
'anfotericina': 'anfotericina', 'fungizone': 'anfotericina',

  // Anemias / hematopoese
'roxadustate': 'roxadustate', 'evrenzo': 'roxadustate',
'ferro_sacarato': 'ferro_sacarato', 'venofer': 'ferro_sacarato',
'darbepoetina': 'darbepoetina', 'aranesp': 'darbepoetina',
'eritropoetina': 'eritropoetina', 'epo': 'eritropoetina', 'eprex': 'eritropoetina',

  // Ginecologia / hormonais
'drospirenona': 'drospirenona', 'yasmin': 'drospirenona',
'dienogest': 'dienogest', 'visanne': 'dienogest',
'goserelina': 'goserelina', 'zoladex': 'goserelina',
'medroxiprogesterona': 'medroxiprogesterona', 'depo-provera': 'medroxiprogesterona',
'anastrozol': 'anastrozol', 'arimidex': 'anastrozol',
'letrozol': 'letrozol', 'femara': 'letrozol',

  // Cardiovascular / novas moléculas
'vernakalant': 'vernakalant', 'brinavess': 'vernakalant',
'mavacamten': 'mavacamten', 'camzyos': 'mavacamten',
'aliskiren': 'aliskiren',
  'catapres': 'clonidina',
'hidralazina': 'hidralazina', 'apresoline': 'hidralazina',
  'isoket': 'isossorbida',

  // Oncologia / TKIs
'imatinibe': 'imatinibe', 'glivec': 'imatinibe',
'erlotinibe': 'erlotinibe', 'tarceva': 'erlotinibe',
'ponatinibe': 'ponatinibe', 'iclusig': 'ponatinibe',
'capecitabina': 'capecitabina', 'xeloda': 'capecitabina',
'micofenolato': 'micofenolato', 'cellcept': 'micofenolato',
'sirolimus': 'sirolimus', 'rapamicina': 'sirolimus', 'rapamune': 'sirolimus',

  // Anestesia / emergência
'cetamina': 'cetamina', 'ketamina': 'cetamina', 'ketalar': 'cetamina',
  'durogesic': 'fentanil',
'sugammadex': 'sugammadex', 'bridion': 'sugammadex',
'protamina': 'protamina', 'protamine': 'protamina',
'flumazenil': 'flumazenil', 'lanexat': 'flumazenil',
'naltrexona': 'naltrexona', 'revia': 'naltrexona',
'buprenorfina': 'buprenorfina', 'subutex': 'buprenorfina', 'suboxone': 'buprenorfina',
'vitamina_k': 'vitamina_k', 'fitomenadiona': 'vitamina_k',
'dissulfiram': 'dissulfiram', 'antabuse': 'dissulfiram',
  'physeptone': 'metadona',

  // Procinéticos / antieméticos
'prucalopride': 'prucalopride', 'resolor': 'prucalopride',
'ondansetron': 'ondansetron',

  // Imunossupressores

  // Vacinas / imunologia
'vacina_viva': 'vacina_viva', 'varicela_vacina': 'vacina_viva',

  // Miscelânea
'sorbitol': 'sorbitol',
'grapefruit': 'grapefruit', 'toranja': 'grapefruit', 'suco_grapefruit': 'grapefruit',
'hypericum': 'hypericum', 'erva_sao_joao': 'hypericum', 'hipericao': 'hypericum',
  'etanol': 'alcool',
'tabaco': 'tabaco', 'cigarro': 'tabaco',
  'parnate': 'tranilcipromina',
  'nardil': 'fenelzina',
'triptofano': 'triptofano',
'sevelâmer': 'sevelâmer', 'renagel': 'sevelâmer',
'polietilenoglicol': 'polietilenoglicol', 'peg': 'polietilenoglicol', 'movicol': 'polietilenoglicol',
'bisacodil': 'bisacodil', 'dulcolax': 'bisacodil',
'lactulose': 'lactulose', 'lactulax': 'lactulose',
'zoledronico': 'zoledronico', 'zometa': 'zoledronico', 'aclasta': 'zoledronico',
'acarbose': 'acarbose', 'glucobay': 'acarbose',
'rosiglitazona': 'rosiglitazona', 'avandia': 'rosiglitazona',
'pioglitazona': 'pioglitazona', 'actos': 'pioglitazona',
  'glibenclamide': 'glibenclamida',
'ganciclovir': 'ganciclovir', 'cymevene': 'ganciclovir',
'cidofovir': 'cidofovir', 'vistide': 'cidofovir',
'aciclovir': 'aciclovir', 'zovirax': 'aciclovir',
'oseltamivir': 'oseltamivir', 'tamiflu': 'oseltamivir',
'ribavirina': 'ribavirina', 'copegus': 'ribavirina',
'probenecida': 'probenecida', 'benemid': 'probenecida',
'meropenem': 'meropenem', 'meronem': 'meropenem',
'vecurônio': 'vecurônio', 'vecuronium': 'vecurônio',
'succinilcolina': 'succinilcolina', 'succinylcholine': 'succinilcolina',
'insulina_glargina': 'insulina_glargina', 'lantus': 'insulina_glargina',
'insulina_detemir': 'insulina_detemir', 'levemir': 'insulina_detemir',
  'aminophylline': 'aminofilina',
'ciclesonida': 'ciclesonida', 'alvesco': 'ciclesonida',
'montelucaste': 'montelucaste',
'enoxacino': 'enoxacino',

};

// ─────────────────────────────────────────────────────────────────────────────
// SERVIÇO PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────
class DrugInteractionService {

  /// Total de pares de interações na base de dados embutida.
  static int get totalInteractions => _interactionDB.length;

  /// Retorna todos os nomes de fármacos conhecidos (chaves do _termMap),
  /// ordenados alfabeticamente — usado para autocomplete na UI.
  static List<String> getAllDrugNames() {
    final names = _termMap.keys.toList()..sort();
    return names;
  }

  /// Extrai termos reconhecidos de um texto livre — exposto para uso na UI.
  static List<String> extractTerms(String text) => _extractTerms(text);

  /// Extrai termos de medicamentos a partir de um texto livre.
  /// Remove pontuação, divide por separadores comuns e normaliza.
  static List<String> _extractTerms(String text) {
    final lower = text.toLowerCase()
        .replaceAll(RegExp(r'[\d]+\s*(mg|mcg|ml|ui|g|%)'), '') // remove doses
        .replaceAll(RegExp(r'[,;/\n\r\t+&]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final words = lower.split(' ');
    final terms = <String>{};

    for (int i = 0; i < words.length; i++) {
      final w = words[i].trim();
      if (w.length < 3) continue;

      // Palavra simples
      if (_termMap.containsKey(w)) terms.add(_termMap[w]!);

      // Bigrama (duas palavras)
      if (i + 1 < words.length) {
        final bigram = '$w ${words[i+1]}';
        if (_termMap.containsKey(bigram)) terms.add(_termMap[bigram]!);
      }

      // Trigrama (três palavras)
      if (i + 2 < words.length) {
        final trigram = '$w ${words[i+1]} ${words[i+2]}';
        if (_termMap.containsKey(trigram)) terms.add(_termMap[trigram]!);
      }
    }

    return terms.toList();
  }

  /// Verifica interações entre uma lista de IDs de fármacos (drugsDatabase)
  /// e um texto livre de medicamentos do paciente.
  ///
  /// [selectedDrugNames] — lista de nomes dos fármacos selecionados no app
  /// [patientMedicationsText] — campo livre de medicamentos em uso do paciente
  ///
  /// Retorna lista de interações ordenadas por severidade.
  static List<DrugInteraction> checkInteractions({
    required List<String> selectedDrugNames,
    required String patientMedicationsText,
  }) {
    // Extrair termos de AMBAS as fontes
    final patientTerms = _extractTerms(patientMedicationsText);
    final selectedTerms = selectedDrugNames
        .expand((name) => _extractTerms(name))
        .toSet()
        .toList();

    // Unir todos os termos para checar interações internas (entre selecionados)
    final allTerms = {...patientTerms, ...selectedTerms}.toList();

    final results = <DrugInteraction>[];
    final seen = <String>{};

    for (final entry in _interactionDB) {
      final id1 = entry.$1;
      final id2 = entry.$2;

      // Verifica se AMBOS os termos estão presentes (em qualquer combinação de fontes)
      final has1 = allTerms.any((t) => t == id1 || _termMap[t] == id1);
      final has2 = allTerms.any((t) => t == id2 || _termMap[t] == id2);

      // Para interações com medicamentos DO PACIENTE: precisa de pelo menos um selecionado
      final hasSelected1 = selectedTerms.any((t) => t == id1 || _termMap[t] == id1);
      final hasSelected2 = selectedTerms.any((t) => t == id2 || _termMap[t] == id2);

      if (has1 && has2 && (hasSelected1 || hasSelected2)) {
        final key = [id1, id2]..sort();
        final keyStr = key.join('|');
        if (!seen.contains(keyStr)) {
          seen.add(keyStr);
          results.add(DrugInteraction(
            drug1: _displayName(id1, selectedDrugNames, patientMedicationsText),
            drug2: _displayName(id2, selectedDrugNames, patientMedicationsText),
            severity: entry.$3,
            mechanism: entry.$4,
            effect: entry.$5,
            management: entry.$6,
            clinicalAlert: entry.$7,
            evidenceLevel: entry.$8,
            riskTypes: entry.$9,
            references: entry.$10,
          ));
        }
      }
    }

    // Ordena por severidade (mais grave primeiro)
    results.sort((a, b) => a.severity.index.compareTo(b.severity.index));
    return results;
  }

  /// Verifica interações apenas entre os fármacos selecionados no app (sem texto livre)
  static List<DrugInteraction> checkSelectedOnly(List<String> drugNames) {
    return checkInteractions(selectedDrugNames: drugNames, patientMedicationsText: '');
  }

  /// Tenta retornar um nome mais legível para exibição
  static String _displayName(String id, List<String> selectedNames, String patientText) {
    // Verifica se algum nome selecionado tem esse ID
    for (final name in selectedNames) {
      final terms = _extractTerms(name);
      if (terms.contains(id)) return name.split('/').first.trim();
    }
    // Tenta encontrar no texto do paciente
    final words = patientText.toLowerCase().split(RegExp(r'[\s,;/]+'));
    for (final w in words) {
      if (_termMap[w] == id) {
        return '${w[0].toUpperCase()}${w.substring(1)}';
      }
    }
    // Fallback: capitalizar o próprio ID
    return '${id[0].toUpperCase()}${id.substring(1)}';
  }
}
