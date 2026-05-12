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
  qtProlongation,        // Prolongamento do intervalo QT / Torsade de Pointes
  hemorrhagic,           // Risco hemorrágico / sangramento
  arrhythmia,            // Arritmia cardíaca (não-QT)
  respiratoryDepression, // Depressão respiratória / apneia
  serotonin,             // Síndrome serotoninérgica
  nephrotoxicity,        // Nefrotoxicidade / lesão renal aguda
  hepatotoxicity,        // Hepatotoxicidade / lesão hepática
  plasmaLevel,           // Alteração de níveis plasmáticos (CYP/P-gp)
  cardiovascular,        // Hipotensão, bradicardia, colapso hemodinâmico
  reducedEfficacy,       // Redução de eficácia terapêutica
  increasedToxicity,     // Aumento de toxicidade do fármaco
  hypoglycemia,          // Hipoglicemia
  hyperkalemia,          // Hipercalemia
  hypokalemia,           // Hipocalemia
  cns,                   // Depressão do SNC / sedação excessiva
  myopathy,              // Miopatia / rabdomiólise
  myelosuppression,      // Mielossupressão / citopenia
  infection,             // Risco aumentado de infecções
  thrombosis,            // Risco tromboembólico
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
  String get severityLabel {
    switch (severity) {
      case InteractionSeverity.contraindicated: return 'CONTRAINDICADA';
      case InteractionSeverity.major:           return 'GRAVE';
      case InteractionSeverity.moderate:        return 'MODERADA';
      case InteractionSeverity.minor:           return 'LEVE';
      case InteractionSeverity.monitorOnly:     return 'MONITORAR';
    }
  }

  /// Rótulo longo da severidade (para bottom sheets)
  String get severityLongLabel {
    switch (severity) {
      case InteractionSeverity.contraindicated: return 'CONTRAINDICADA — NÃO UTILIZAR JUNTOS';
      case InteractionSeverity.major:           return 'GRAVE — ALTO RISCO';
      case InteractionSeverity.moderate:        return 'MODERADA — MONITORAR';
      case InteractionSeverity.minor:           return 'LEVE — VIGILÂNCIA';
      case InteractionSeverity.monitorOnly:     return 'SÓ MONITORIZAR';
    }
  }

  /// Rótulo do nível de evidência
  String get evidenceLabel {
    switch (evidenceLevel) {
      case EvidenceLevel.established:  return 'ESTABELECIDA';
      case EvidenceLevel.probable:     return 'PROVÁVEL';
      case EvidenceLevel.possible:     return 'POSSÍVEL';
      case EvidenceLevel.theoretical:  return 'TEÓRICA';
    }
  }

  /// Rótulo legível de cada tipo de risco
  static String riskTypeLabel(RiskType r) {
    switch (r) {
      case RiskType.qtProlongation:        return '↑QT';
      case RiskType.hemorrhagic:           return 'Hemorrágico';
      case RiskType.arrhythmia:            return 'Arritmia';
      case RiskType.respiratoryDepression: return 'Dep. Resp.';
      case RiskType.serotonin:             return 'Serotonina';
      case RiskType.nephrotoxicity:        return 'Nefrotóxico';
      case RiskType.hepatotoxicity:        return 'Hepatotóxico';
      case RiskType.plasmaLevel:           return 'Nível Plasmático';
      case RiskType.cardiovascular:        return 'Cardiovascular';
      case RiskType.reducedEfficacy:       return 'Eficácia ↓';
      case RiskType.increasedToxicity:     return 'Toxicidade ↑';
      case RiskType.hypoglycemia:          return 'Hipoglicemia';
      case RiskType.hyperkalemia:          return 'Hipercalemia';
      case RiskType.hypokalemia:           return 'Hipocalemia';
      case RiskType.cns:                   return 'Depressão SNC';
      case RiskType.myopathy:              return 'Miopatia';
      case RiskType.myelosuppression:      return 'Mielossupressão';
      case RiskType.infection:             return 'Infecção';
      case RiskType.thrombosis:            return 'Trombose';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BANCO DE INTERAÇÕES (termos normalizados para busca)
// Cada entrada: (id1, id2, severity, mechanism, effect, management,
//                clinicalAlert, evidenceLevel, {riskTypes}, [references])
// ─────────────────────────────────────────────────────────────────────────────
const _kRefGG   = 'Goodman & Gilman 14ª ed.';
const _kRefKatz = 'Katzung 15ª ed.';
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
    'Inibição plaquetária aditiva + deslocamento proteico aumentando INR',
    'Risco aumentado de sangramento grave (GI, intracraniano)',
    'Evitar combinação. Se necessário, usar dose mínima de AAS (≤100 mg/dia) com INR ≤2,5 e monitoramento frequente',
    'ALTO RISCO DE SANGRAMENTO — Evitar combinação',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),
  ('warfarina', 'aas', InteractionSeverity.major,
    'Inibição plaquetária aditiva + deslocamento proteico aumentando INR',
    'Risco aumentado de sangramento grave (GI, intracraniano)',
    'Evitar combinação. Se necessário, usar dose mínima de AAS (≤100 mg/dia) com INR ≤2,5 e monitoramento frequente',
    'ALTO RISCO DE SANGRAMENTO — Evitar combinação',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),
  ('warfarina', 'ibuprofeno', InteractionSeverity.major,
    'Deslocamento da ligação proteica e inibição plaquetária',
    'Elevação do INR e risco de sangramento',
    'Evitar. Preferir paracetamol como analgésico. Monitorar INR se inevitável',
    'ALTO RISCO DE SANGRAMENTO — Use paracetamol',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),
  ('warfarina', 'naproxeno', InteractionSeverity.major,
    'Deslocamento da ligação proteica e inibição plaquetária',
    'Elevação do INR e risco de sangramento',
    'Evitar. Preferir paracetamol como analgésico. Monitorar INR se inevitável',
    'ALTO RISCO DE SANGRAMENTO — Use paracetamol',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),
  ('warfarina', 'cetorolaco', InteractionSeverity.major,
    'AINE potente com efeito anticoagulante aditivo',
    'Risco hemorrágico grave — combinação perigosa',
    'Contraindicado. Usar analgésico alternativo',
    'ALTO RISCO HEMORRÁGICO — Contraindicado',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefMdx, _kRefFDA]),
  ('warfarina', 'metronidazol', InteractionSeverity.major,
    'Inibição do CYP2C9 reduz metabolismo da warfarina',
    'Aumento significativo do INR → risco de hemorragia',
    'Monitorar INR a cada 2–3 dias. Reduzir dose de warfarina em ~25–50%',
    'MONITORAR INR — Risco de hemorragia por aumento de nível',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),
  ('warfarina', 'fluconazol', InteractionSeverity.major,
    'Inibição potente do CYP2C9 e CYP3A4',
    'Elevação marcada do INR com risco hemorrágico grave',
    'Reduzir dose de warfarina em 25–50%. Monitorar INR diariamente nos primeiros 3–5 dias',
    'ALTO RISCO HEMORRÁGICO — Reduzir warfarina e monitorar INR',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefLex]),
  ('warfarina', 'amiodarona', InteractionSeverity.major,
    'Inibição do CYP2C9 (metabolizador da varfarina S) pela amiodarona e seus metabólitos',
    'Elevação progressiva do INR — efeito pode durar semanas após suspender amiodarona',
    'Reduzir dose de warfarina em 30–50%. Monitorar INR semanalmente. Efeito persiste por meses',
    'RISCO HEMORRÁGICO PROLONGADO — Efeito persiste semanas após suspender amiodarona',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),
  ('warfarina', 'ciprofloxacino', InteractionSeverity.moderate,
    'Inibição do CYP1A2 e possível redução da flora intestinal produtora de vitamina K',
    'Elevação do INR',
    'Monitorar INR 2–3 dias após início e 2–3 dias após término do antibiótico',
    'Necessita monitorização do INR durante o tratamento',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),

  // ── Estatinas ─────────────────────────────────────────────────────────────
  ('sinvastatina', 'amiodarona', InteractionSeverity.major,
    'Inibição do CYP3A4 aumenta concentração de sinvastatina',
    'Risco de miopatia / rabdomiólise',
    'Dose máxima de sinvastatina: 20 mg/dia com amiodarona. Preferir rosuvastatina ou pravastatina',
    'RISCO DE RABDOMIÓLISE — Limitar sinvastatina a 20 mg/dia',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefFDA]),
  ('sinvastatina', 'claritromicina', InteractionSeverity.major,
    'Inibição potente do CYP3A4',
    'Risco de rabdomiólise',
    'Suspender sinvastatina durante o curso de claritromicina. Alternativa: azitromicina',
    'RISCO DE RABDOMIÓLISE — Suspender sinvastatina',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefFDA]),
  ('sinvastatina', 'eritromicina', InteractionSeverity.major,
    'Inibição do CYP3A4',
    'Risco de miopatia/rabdomiólise',
    'Suspender sinvastatina durante o curso. Alternativa: azitromicina',
    'RISCO DE RABDOMIÓLISE — Suspender sinvastatina',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefMdx, _kRefFDA]),
  // DUPLICATA REMOVIDA: sinvastatina+fluconazol — par detalhado mantido como fluconazol+sinvastatina (linha ~1654)
  ('atorvastatina', 'claritromicina', InteractionSeverity.moderate,
    'Inibição do CYP3A4 aumenta nível de atorvastatina',
    'Risco aumentado de miopatia',
    'Reduzir dose de atorvastatina. Preferir azitromicina',
    'Necessita monitorização — risco de miopatia',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),
  ('atorvastatina', 'amiodarona', InteractionSeverity.moderate,
    'Inibição do CYP3A4',
    'Risco de miopatia',
    'Limitar atorvastatina a 40 mg/dia. Monitorar CPK e sintomas musculares',
    'Necessita monitorização clínica — limitar dose da estatina',
    EvidenceLevel.probable,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefMdx, _kRefLex]),

  // ── IECA / ARA-II / Diuréticos ────────────────────────────────────────────
  ('enalapril', 'espironolactona', InteractionSeverity.moderate,
    'Ambos elevam potássio sérico por mecanismos distintos',
    'Hipercalemia, especialmente em DRC ou insuficiência cardíaca',
    'Monitorar K+ sérico e função renal semanalmente no início; reduzir dose de espironolactona se K+ >5,5 mEq/L',
    'Necessita monitorização de potássio sérico',
    EvidenceLevel.established,
    {RiskType.hyperkalemia},
    [_kRefGG, _kRefUT]),
  ('losartana', 'espironolactona', InteractionSeverity.moderate,
    'Ambos elevam potássio sérico',
    'Hipercalemia — mais frequente em IRC/ICF',
    'Monitorar K+ sérico e creatinina regularmente',
    'Necessita monitorização de potássio sérico',
    EvidenceLevel.established,
    {RiskType.hyperkalemia},
    [_kRefGG, _kRefUT]),
  ('enalapril', 'alisquireno', InteractionSeverity.contraindicated,
    'Bloqueio duplo do SRAA',
    'Hipotensão grave, hipercalemia e insuficiência renal aguda',
    'Combinação contraindicada por guidelines (ESC 2016, JNC)',
    'NÃO UTILIZAR — Contraindicado por guidelines internacionais',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.hyperkalemia, RiskType.nephrotoxicity},
    [_kRefGG, _kRefFDA, _kRefUT]),
  ('losartana', 'alisquireno', InteractionSeverity.contraindicated,
    'Bloqueio duplo do SRAA',
    'Hipotensão grave, hipercalemia e insuficiência renal aguda',
    'Combinação contraindicada — evitar em qualquer paciente',
    'NÃO UTILIZAR — Contraindicado por guidelines internacionais',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.hyperkalemia, RiskType.nephrotoxicity},
    [_kRefGG, _kRefFDA]),

  // ── IECA + ARA-II (bloqueio duplo do SRAA) ───────────────────────────────
  ('enalapril', 'losartana', InteractionSeverity.contraindicated,
    'Bloqueio duplo do SRAA: inibição simultânea da ECA e do receptor AT1 da angiotensina II — sem benefício adicional, com risco multiplicado',
    'Hipotensão sintomática grave, hipercalemia potencialmente fatal, insuficiência renal aguda (estudo ONTARGET)',
    'CONTRAINDICADO — Não combinar IECA + ARA-II. Escolher um dos dois. Exceção restrita: cardiologista experiente em IC refratária com monitorização intensiva',
    'BLOQUEIO DUPLO DO SRAA — Contraindicado por ESC/AHA. Estudo ONTARGET demonstrou malefício sem benefício',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.hyperkalemia, RiskType.nephrotoxicity},
    [_kRefGG, _kRefUT, _kRefFDA]),

  ('enalapril', 'aine', InteractionSeverity.moderate,
    'AINEs reduzem síntese de prostaglandinas vasodilatadoras renais',
    'Redução do efeito anti-hipertensivo do IECA; risco de IRA',
    'Evitar uso crônico concomitante. Se necessário, monitorar PA e função renal',
    'Necessita monitorização clínica/laboratorial — risco renal',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.cardiovascular},
    [_kRefGG, _kRefUT]),

  // ── Betabloqueadores ──────────────────────────────────────────────────────
  ('metoprolol', 'verapamil', InteractionSeverity.major,
    'Efeito aditivo de ambos no nó AV (cronotropismo e dromotropismo negativos)',
    'Bradicardia grave, bloqueio AV completo, hipotensão, ICC',
    'Contraindicado na maioria das situações. Se inevitável, monitorar com ECG contínuo',
    'ALTO RISCO CARDIOVASCULAR — Evitar combinação',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx, _kRefUT]),
  ('metoprolol', 'diltiazem', InteractionSeverity.major,
    'Efeito aditivo no nó sinusal e AV',
    'Bradicardia, bloqueio AV, hipotensão',
    'Evitar combinação. Se necessário, iniciar com doses muito baixas e monitorar ECG',
    'ALTO RISCO CARDIOVASCULAR — Monitorar ECG continuamente',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),
  ('propranolol', 'verapamil', InteractionSeverity.major,
    'Efeito aditivo no nó AV',
    'Bradicardia grave, bloqueio AV, parada cardíaca (relatos)',
    'Contraindicado — alternativa: usar apenas um deles',
    'ALTO RISCO DE PARADA CARDÍACA — Contraindicado',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx, _kRefFDA]),
  ('metoprolol', 'clonidina', InteractionSeverity.moderate,
    'Retirada abrupta de clonidina com betabloqueador causa hipertensão rebote grave',
    'Crise hipertensiva rebote ao suspender clonidina',
    'Nunca suspender clonidina abruptamente; se suspender, retirar betabloqueador primeiro',
    'Necessita monitorização — Nunca suspender clonidina abruptamente',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    [_kRefGG, _kRefUT]),

  // ── Antiarrítmicos ────────────────────────────────────────────────────────
  ('amiodarona', 'sotalol', InteractionSeverity.contraindicated,
    'Prolongamento aditivo do intervalo QT',
    'Torsade de Pointes, fibrilação ventricular, morte súbita',
    'Contraindicado — nunca combinar antiarrítmicos que prolongam QT',
    'NÃO UTILIZAR ESTES FÁRMACOS JUNTOS — Risco de morte súbita',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx, _kRefFDA]),
  ('amiodarona', 'haloperidol', InteractionSeverity.major,
    'Prolongamento aditivo do QT',
    'Torsade de Pointes',
    'Evitar. Se necessário, monitorar QTc com ECG regular',
    'ALTO RISCO DE TORSADE DE POINTES — Monitorar QTc',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefMdx, _kRefUT]),
  ('amiodarona', 'digoxina', InteractionSeverity.major,
    'Inibição da P-glicoproteína aumenta nível sérico de digoxina',
    'Toxicidade digitálica — náuseas, bradicardia, distúrbios visuais',
    'Reduzir dose de digoxina em 50%. Monitorar nível sérico e ECG',
    'ALTO RISCO DE TOXICIDADE DIGITÁLICA — Reduzir dose de digoxina 50%',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.cardiovascular},
    [_kRefGG, _kRefMdx, _kRefUT]),
  ('digoxina', 'furosemida', InteractionSeverity.moderate,
    'Furosemida causa hipocalemia que potencializa toxicidade da digoxina',
    'Arritmias por toxicidade digitálica facilitadas pela hipocalemia',
    'Monitorar K+ sérico; repor potássio se <4 mEq/L; dosar digoxina se suspeita de toxicidade',
    'Necessita monitorização de K+ sérico e nível de digoxina',
    EvidenceLevel.established,
    {RiskType.hypokalemia, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),
  ('digoxina', 'espironolactona', InteractionSeverity.moderate,
    'Espironolactona pode elevar nível sérico de digoxina (inibição da secreção tubular)',
    'Toxicidade digitálica aumentada',
    'Monitorar nível sérico de digoxina após introdução de espironolactona',
    'Necessita monitorização de nível sérico de digoxina',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel, RiskType.arrhythmia},
    [_kRefMdx, _kRefLex]),

  // ── Antibióticos ──────────────────────────────────────────────────────────
  ('metronidazol', 'alcool', InteractionSeverity.contraindicated,
    'Inibição da aldeído desidrogenase — reação tipo dissulfiram',
    'Flushing, náuseas, vômitos, cefaleia, taquicardia, hipotensão',
    'Contraindicado álcool durante uso e por 48h após término do metronidazol',
    'NÃO UTILIZAR — Proibido álcool durante e 48h após metronidazol',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    [_kRefGG, _kRefFDA]),
  ('quinolona', 'antiácido', InteractionSeverity.moderate,
    'Cátions divalentes (Al, Mg, Ca) quelam quinolonas no TGI',
    'Redução de 50–90% na absorção oral da quinolona',
    'Administrar quinolona 2h antes ou 6h após antiácido/suplemento de cálcio/ferro',
    'Necessita intervalo de 2–6h entre administrações',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefFDA]),
  ('ciprofloxacino', 'teofilina', InteractionSeverity.major,
    'Inibição do CYP1A2 reduz metabolismo da teofilina',
    'Toxicidade por teofilina — náuseas, convulsões, arritmias',
    'Reduzir dose de teofilina em 30–50%. Monitorar nível sérico de teofilina',
    'ALTO RISCO DE TOXICIDADE — Monitorar nível sérico de teofilina',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx, _kRefFDA]),
  ('claritromicina', 'estatina', InteractionSeverity.major,
    'Inibição do CYP3A4 eleva concentração plasmática de estatinas metabolizadas por esse CYP',
    'Risco de miopatia/rabdomiólise',
    'Suspender estatina durante o curso de claritromicina. Alternativa: azitromicina',
    'RISCO DE RABDOMIÓLISE — Suspender estatina durante claritromicina',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefFDA]),
  ('rifampicina', 'warfarina', InteractionSeverity.major,
    'Indução potente do CYP2C9 — aumenta metabolismo da warfarina',
    'Redução marcada do efeito anticoagulante (INR pode cair >50%)',
    'Monitorar INR diariamente no início e ao final. Aumentar dose de warfarina significativamente',
    'ALTO RISCO DE FALHA ANTICOAGULANTE — Monitorar INR diariamente',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel, RiskType.thrombosis},
    [_kRefGG, _kRefMdx, _kRefUT]),

  // ── Psicotrópicos / SNC ───────────────────────────────────────────────────
  ('tramadol', 'ssri', InteractionSeverity.major,
    'Inibição da recaptação serotoninérgica somada',
    'Síndrome serotoninérgica — agitação, hipertermia, mioclonia, taquicardia',
    'Evitar combinação. Se indispensável, iniciar com dose baixa de tramadol e monitorar por 24–48h',
    'ALTO RISCO DE SÍNDROME SEROTONINÉRGICA — Evitar combinação',
    EvidenceLevel.established,
    {RiskType.serotonin},
    [_kRefGG, _kRefMdx, _kRefFDA]),
  ('tramadol', 'imao', InteractionSeverity.contraindicated,
    'Potenciação serotoninérgica extrema',
    'Síndrome serotoninérgica grave com risco de morte',
    'Contraindicado — aguardar 14 dias após suspender IMAO antes de usar tramadol',
    'NÃO UTILIZAR ESTES FÁRMACOS JUNTOS — Risco de morte',
    EvidenceLevel.established,
    {RiskType.serotonin},
    [_kRefGG, _kRefFDA, _kRefMdx]),
  ('tramadol', 'morfina', InteractionSeverity.moderate,
    'Efeitos aditivos no SNC e depressão respiratória',
    'Sedação excessiva, depressão respiratória',
    'Usar com cautela. Monitorar nível de consciência e função respiratória',
    'Necessita monitorização clínica — depressão respiratória aditiva',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns},
    [_kRefGG, _kRefMdx]),
  ('benzodiazepínico', 'opioide', InteractionSeverity.major,
    'Depressão aditiva do SNC — sinergia respiratória e sedativa',
    'Depressão respiratória grave, coma, morte (alerta FDA/ANVISA)',
    'Evitar combinação. Se essencial (ICU/paliativo), monitorar com oximetria contínua; ter naloxona disponível',
    'ALTO RISCO DE DEPRESSÃO RESPIRATÓRIA — FDA Black Box Warning',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns},
    [_kRefFDA, _kRefGG, _kRefMdx]),
  ('haloperidol', 'carbonato de litio', InteractionSeverity.moderate,
    'Possível potenciação neurotóxica; lítio pode alterar farmacocinética do haloperidol',
    'Neurotoxicidade aumentada — confusão, tremor, extra-piramidal exacerbado',
    'Monitorar lítio sérico, ECG e sinais neurológicos',
    'Necessita monitorização clínica/laboratorial — neurotoxicidade',
    EvidenceLevel.probable,
    {RiskType.cns, RiskType.qtProlongation},
    [_kRefMdx, _kRefUT]),
  ('ssri', 'imao', InteractionSeverity.contraindicated,
    'Hiperestimulação serotoninérgica extrema',
    'Síndrome serotoninérgica grave — hiperpirexia, convulsões, colapso cardiovascular, morte',
    'Contraindicado. Aguardar 14 dias após suspender IMAO (ou 5 semanas para fluoxetina) antes de iniciar SSRI',
    'NÃO UTILIZAR ESTES FÁRMACOS JUNTOS — Síndrome serotoninérgica fatal',
    EvidenceLevel.established,
    {RiskType.serotonin},
    [_kRefGG, _kRefFDA, _kRefMdx]),

  // ── Hipoglicemiantes ──────────────────────────────────────────────────────
  ('metformina', 'contraste iodado', InteractionSeverity.major,
    'Contraste iodado pode causar IRA transitória → acúmulo de metformina → acidose lática',
    'Acidose lática (rara mas grave)',
    'Suspender metformina 48h antes de contraste em pacientes com DRC (TFG <60). Reintroduzir após 48h se função renal estável',
    'ALTO RISCO — Suspender metformina 48h antes do contraste',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx, _kRefFDA]),
  ('glibenclamida', 'fluconazol', InteractionSeverity.major,
    'Inibição do CYP2C9 aumenta nível sérico de glibenclamida',
    'Hipoglicemia grave e prolongada',
    'Evitar. Se necessário, monitorar glicemia intensivamente e reduzir dose de glibenclamida',
    'ALTO RISCO DE HIPOGLICEMIA GRAVE — Monitorar glicemia intensivamente',
    EvidenceLevel.established,
    {RiskType.hypoglycemia, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),
  ('insulina', 'betabloqueador', InteractionSeverity.moderate,
    'Betabloqueadores mascaram taquicardia e tremor (sintomas adrenérgicos de hipoglicemia)',
    'Hipoglicemia pode passar desapercebida — somente sudorese persiste como sinal',
    'Preferir betabloqueadores cardiosseletivos. Orientar o paciente. Monitorar glicemia mais frequentemente',
    'Necessita monitorização — sinais de hipoglicemia mascarados',
    EvidenceLevel.established,
    {RiskType.hypoglycemia},
    [_kRefGG, _kRefKatz]),

  // ── Imunossupressores ─────────────────────────────────────────────────────
  ('ciclosporina', 'fluconazol', InteractionSeverity.major,
    'Inibição do CYP3A4 eleva nível sérico de ciclosporina',
    'Nefrotoxicidade e imunossupressão excessiva',
    'Reduzir dose de ciclosporina em 50% e monitorar nível sérico diariamente',
    'ALTO RISCO DE NEFROTOXICIDADE — Monitorar nível sérico diariamente',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefLex]),
  ('ciclosporina', 'claritromicina', InteractionSeverity.major,
    'Inibição do CYP3A4 e P-gp',
    'Aumento do nível sérico de ciclosporina — nefrotoxicidade',
    'Reduzir dose de ciclosporina; monitorar nível sérico frequentemente',
    'ALTO RISCO DE NEFROTOXICIDADE — Monitorar nível sérico diariamente',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.plasmaLevel},
    [_kRefMdx, _kRefLex]),

  // ── Cardiovascular / Miscellaneous ────────────────────────────────────────
  ('atorvastatina', 'gemfibrozil', InteractionSeverity.major,
    'Inibição da glucuronidação da atorvastatina pelo gemfibrozil',
    'Risco significativo de miopatia/rabdomiólise',
    'Evitar combinação. Se necessário usar fibratos, preferir fenofibrato + estatina',
    'ALTO RISCO DE RABDOMIÓLISE — Evitar combinação',
    EvidenceLevel.established,
    {RiskType.myopathy},
    [_kRefGG, _kRefMdx, _kRefFDA]),
  ('sildenafila', 'nitrato', InteractionSeverity.contraindicated,
    'Ambos potencializam vasodilatação via GMPc',
    'Hipotensão grave, choque cardiovascular, colapso hemodinâmico, morte',
    'Contraindicado absolutamente. Aguardar ≥24h após sildenafila (≥48h para tadalafila) para administrar nitrato',
    'NÃO UTILIZAR ESTES FÁRMACOS JUNTOS — Hipotensão fatal',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    [_kRefGG, _kRefFDA, _kRefMdx]),
  ('sildenafila', 'alfa-bloqueador', InteractionSeverity.major,
    'Efeito hipotensor aditivo',
    'Hipotensão sintomática grave — tontura, síncope',
    'Iniciar alfa-bloqueador com dose baixa. Aguardar estabilização antes de associar. Orientar paciente',
    'ALTO RISCO DE HIPOTENSÃO GRAVE — Iniciar com doses baixas',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    [_kRefGG, _kRefFDA]),
  ('furosemida', 'aminoglicosideo', InteractionSeverity.major,
    'Ototoxicidade aditiva sinérgica',
    'Surdez neurossensorial permanente — risco aumentado especialmente em DRC',
    'Evitar combinação. Se necessário, minimizar dose e duração; monitorar função auditiva',
    'ALTO RISCO DE SURDEZ IRREVERSÍVEL — Evitar combinação',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx]),
  ('furosemida', 'aine', InteractionSeverity.moderate,
    'AINEs inibem síntese de prostaglandinas renais vasodilatadoras',
    'Redução do efeito diurético; risco de IRA',
    'Evitar AINEs em pacientes usando furosemida, especialmente se ICC/DRC',
    'Necessita monitorização clínica/laboratorial — risco renal',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.reducedEfficacy},
    [_kRefGG, _kRefUT]),

  // DUPLICATA REMOVIDA: fluconazol+quetiapina — par detalhado mantido na seção de fluconazol (linha ~1670)
  ('haloperidol', 'ondansetrona', InteractionSeverity.major,
    'Prolongamento aditivo do QT por mecanismos distintos',
    'Torsade de Pointes',
    'Evitar. Monitorar QTc. Se QTc >500ms, suspender um dos medicamentos',
    'ALTO RISCO DE TORSADE DE POINTES — Monitorar QTc',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefMdx, _kRefFDA]),

  // ── Heparina / Anticoagulantes ─────────────────────────────────────────────
  ('heparina', 'aspirina', InteractionSeverity.moderate,
    'Efeito antitrombótico/hemostático aditivo',
    'Risco aumentado de sangramento (especialmente GI)',
    'Monitorar sinais de sangramento. Combinação aceita em SCA (protocolo AHA/ACC), mas com atenção',
    'Necessita monitorização clínica — risco hemorrágico aditivo',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefUT]),
  ('heparina', 'aine', InteractionSeverity.moderate,
    'AINEs inibem função plaquetária + risco de sangramento GI',
    'Risco aumentado de hemorragia',
    'Evitar AINEs durante anticoagulação. Preferir paracetamol para analgesia',
    'Necessita monitorização — evitar AINEs com heparina',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx]),

  // ── Amiodarona — QT e interações adicionais ───────────────────────────────
  ('amiodarona', 'azitromicina', InteractionSeverity.major,
    'Prolongamento aditivo do intervalo QT por mecanismos distintos',
    'Torsades de Pointes, fibrilação ventricular',
    'Evitar combinação. Se antibiótico essencial, preferir amoxicilina ou doxiciclina. Monitorar QTc',
    'ALTO RISCO DE TORSADE DE POINTES — Preferir amoxicilina',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefMdx, _kRefUT]),
  ('amiodarona', 'metoprolol', InteractionSeverity.major,
    'Efeito cronotrópico e dromotrópico negativo aditivo sobre o nó sinusal e AV',
    'Bradicardia grave, bloqueio AV, colapso hemodinâmico',
    'Monitorar FC e ECG continuamente. Reduzir dose do betabloqueador. Ter atropina disponível',
    'ALTO RISCO CARDIOVASCULAR — Monitorar ECG e FC continuamente',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),

  // ── Warfarina — entradas complementares ───────────────────────────────────
  ('warfarina', 'aine', InteractionSeverity.major,
    'AINEs inibem função plaquetária e causam ulceração GI; deslocamento proteico eleva INR',
    'Risco muito alto de sangramento gastrointestinal e ulceração péptica',
    'Evitar combinação. Preferir paracetamol. Se inevitável, usar IBP e monitorar INR frequentemente',
    'ALTO RISCO DE SANGRAMENTO GI — Use paracetamol + IBP',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),

  // ── Clopidogrel ───────────────────────────────────────────────────────────
  ('clopidogrel', 'omeprazol', InteractionSeverity.moderate,
    'Inibição do CYP2C19 pelo omeprazol reduz conversão do clopidogrel ao metabólito ativo',
    'Redução do efeito antiagregante — maior risco de eventos isquêmicos e trombose de stent',
    'Preferir pantoprazol (menor inibição CYP2C19) se IBP necessário. Monitorar eventos cardiovasculares',
    'Necessita substituição de IBP — preferir pantoprazol',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.thrombosis},
    [_kRefGG, _kRefMdx, _kRefFDA]),
  ('clopidogrel', 'esomeprazol', InteractionSeverity.moderate,
    'Inibição do CYP2C19 pelo esomeprazol reduz ativação do clopidogrel',
    'Eficácia antiagregante reduzida — risco de trombose de stent',
    'Substituir por pantoprazol. Reavaliar necessidade do IBP após período de risco',
    'Necessita substituição de IBP — preferir pantoprazol',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.thrombosis},
    [_kRefMdx, _kRefFDA]),

  // ── IECA — entradas complementares ────────────────────────────────────────
  ('enalapril', 'sacubitrila', InteractionSeverity.contraindicated,
    'Inibição simultânea do sistema neprilisina-angiotensina causa acúmulo de bradicinina',
    'Angioedema grave e potencialmente fatal — risco 3× maior que IECA isolado',
    'Contraindicado. Respeitar janela de washout de 36 horas entre suspender IECA e iniciar sacubitrila',
    'NÃO UTILIZAR — Angioedema fatal; washout 36h obrigatório',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    [_kRefGG, _kRefFDA, _kRefUT]),

  // ── Lítio ─────────────────────────────────────────────────────────────────
  ('carbonato de litio', 'ibuprofeno', InteractionSeverity.major,
    'AINEs reduzem excreção renal de lítio por inibição das prostaglandinas renais',
    'Toxicidade lítica rápida — tremor, confusão, convulsões, arritmias',
    'Evitar AINEs em pacientes em uso de lítio. Usar paracetamol. Monitorar litemia se inevitável',
    'ALTO RISCO DE TOXICIDADE POR LÍTIO — Use paracetamol',
    EvidenceLevel.established,
    {RiskType.increasedToxicity, RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx, _kRefUT]),
  ('carbonato de litio', 'hidroclorotiazida', InteractionSeverity.major,
    'Tiazídicos aumentam reabsorção proximal de sódio e lítio em compensação à perda distal',
    'Toxicidade por lítio — confusão, tremor, nefrotoxicidade',
    'Monitorar litemia a cada 3–5 dias no início. Reduzir dose de lítio em 30–50%',
    'ALTO RISCO DE TOXICIDADE POR LÍTIO — Monitorar litemia',
    EvidenceLevel.established,
    {RiskType.increasedToxicity, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),
  ('carbonato de litio', 'enalapril', InteractionSeverity.major,
    'IECAs reduzem clearance renal de lítio por inibição da angiotensina II',
    'Elevação dos níveis séricos de lítio — toxicidade',
    'Monitorar litemia semanalmente nas primeiras 4 semanas. Reduzir dose de lítio conforme necessário',
    'ALTO RISCO DE TOXICIDADE POR LÍTIO — Monitorar litemia semanalmente',
    EvidenceLevel.established,
    {RiskType.increasedToxicity, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),

  // ── Serotonina — entradas complementares ──────────────────────────────────
  ('ssri', 'linezolida', InteractionSeverity.contraindicated,
    'Linezolida inibe a MAO — hiperestimulação serotoninérgica com SSRI',
    'Síndrome serotoninérgica grave — hipertermia, rigidez, crise convulsiva, colapso',
    'Contraindicado. Aguardar washout adequado (≥5 semanas para fluoxetina, ≥2 semanas para outros SSRIs)',
    'NÃO UTILIZAR ESTES FÁRMACOS JUNTOS — Síndrome serotoninérgica fatal',
    EvidenceLevel.established,
    {RiskType.serotonin},
    [_kRefGG, _kRefFDA, _kRefMdx]),
  ('tramadol', 'amitriptilina', InteractionSeverity.major,
    'Redução do limiar convulsivo + inibição da recaptação de serotonina/noradrenalina aditiva',
    'Risco aumentado de convulsões e síndrome serotoninérgica',
    'Evitar combinação. Se necessário, iniciar tramadol em dose mínima com monitoramento neurológico',
    'ALTO RISCO DE SÍNDROME SEROTONINÉRGICA E CONVULSÕES',
    EvidenceLevel.probable,
    {RiskType.serotonin, RiskType.cns},
    [_kRefMdx, _kRefUT]),

  // ── Aminoglicosídeos ───────────────────────────────────────────────────────
  ('aminoglicosideo', 'vancomicina', InteractionSeverity.major,
    'Nefrotoxicidade e ototoxicidade sinérgica — ambos lesam túbulos renais proximais e células ciliadas',
    'Insuficiência renal aguda, surdez irreversível',
    'Evitar combinação se possível. Se necessária, monitorar creatinina diariamente e função auditiva',
    'ALTO RISCO DE NEFROTOXICIDADE E SURDEZ IRREVERSÍVEL',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx, _kRefUT]),

  // ── Quinolonas — quelação por cátions ─────────────────────────────────────
  ('ciprofloxacino', 'carbonato de calcio', InteractionSeverity.moderate,
    'Cálcio forma complexo insolúvel com ciprofloxacino no intestino (quelação)',
    'Redução de até 50% na absorção oral da quinolona',
    'Administrar ciprofloxacino 2h antes ou 6h após cálcio/antiácidos/ferro',
    'Necessita intervalo de 2–6h entre administrações',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefFDA]),
  ('ciprofloxacino', 'sulfato ferroso', InteractionSeverity.moderate,
    'Ferro quelata ciprofloxacino no TGI reduzindo drasticamente sua biodisponibilidade',
    'Falha terapêutica do antibiótico',
    'Administrar ciprofloxacino 2h antes ou 6h após suplemento de ferro',
    'Necessita intervalo de 2–6h entre administrações — risco de falha terapêutica',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefFDA]),

  // ── Levotiroxina ──────────────────────────────────────────────────────────
  ('levotiroxina', 'carbonato de calcio', InteractionSeverity.moderate,
    'Cálcio liga-se à levotiroxina no intestino reduzindo sua absorção',
    'Hipotireoidismo por absorção inadequada — TSH elevado',
    'Intervalo mínimo de 4 horas entre levotiroxina e cálcio. Tomar levotiroxina em jejum',
    'Necessita intervalo de 4h — separar administrações',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefFDA]),
  ('levotiroxina', 'pantoprazol', InteractionSeverity.moderate,
    'Redução da acidez gástrica pelos IBPs prejudica dissolução e absorção da levotiroxina',
    'Absorção reduzida — hipotireoidismo subclínico',
    'Monitorar TSH a cada 6–8 semanas. Pode ser necessário aumentar dose de levotiroxina',
    'Necessita monitorização de TSH a cada 6–8 semanas',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy},
    [_kRefMdx, _kRefUT]),
  ('levotiroxina', 'antiácido', InteractionSeverity.moderate,
    'Cátions (Al, Mg, Ca) dos antiácidos quelam levotiroxina no TGI',
    'Redução da absorção — hipotireoidismo',
    'Administrar levotiroxina 2h antes de antiácidos, IBPs, cálcio ou ferro',
    'Necessita intervalo de 2h entre administrações',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefFDA]),

  // ── Benzodiazepínicos — complementar ──────────────────────────────────────
  ('benzodiazepínico', 'alcool', InteractionSeverity.major,
    'Potenciação mútua da depressão do SNC por mecanismos GABA-A aditivos',
    'Sedação severa, depressão respiratória, coma, morte',
    'Contraindicado. Orientar paciente explicitamente sobre proibição de álcool',
    'ALTO RISCO DE DEPRESSÃO RESPIRATÓRIA — Proibido álcool',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns},
    [_kRefGG, _kRefFDA]),

  // ── Anticonvulsivantes ─────────────────────────────────────────────────────
  ('carbamazepina', 'anticoncepcional', InteractionSeverity.major,
    'Indução enzimática do CYP3A4 acelera metabolismo de estrógenos e progestágenos',
    'Falha do anticoncepcional hormonal — gravidez não planejada',
    'Usar método contraceptivo não hormonal (DIU de cobre, preservativo). Orientar explicitamente a paciente',
    'ALTO RISCO DE FALHA CONTRACEPTIVA — Usar método não hormonal',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefFDA]),
  ('acido valproico', 'lamotrigina', InteractionSeverity.major,
    'Ácido valproico inibe a glucuronidação da lamotrigina, dobrando sua meia-vida',
    'Toxicidade por lamotrigina — rash grave, Síndrome de Stevens-Johnson',
    'Reduzir dose de lamotrigina em 50% ao introduzir valproato. Monitorar rash cutâneo',
    'ALTO RISCO DE STEVEN-JOHNSON — Reduzir lamotrigina 50%',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx, _kRefFDA]),
  ('midazolam', 'claritromicina', InteractionSeverity.major,
    'Inibição potente do CYP3A4 pela claritromicina prolonga meia-vida do midazolam',
    'Sedação prolongada e excessiva, depressão respiratória',
    'Reduzir dose de midazolam em 50–75%. Monitorar nível de consciência e SpO₂',
    'ALTO RISCO DE SEDAÇÃO PROLONGADA — Reduzir dose de midazolam',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefFDA]),

  // ── Claritromicina + Benzodiazepínicos (CYP3A4) ──────────────────────────
  ('claritromicina', 'benzodiazepínico', InteractionSeverity.major,
    'Claritromicina inibe potentemente o CYP3A4 — principal via de metabolismo de alprazolam, diazepam, clonazepam e triazolam. Lorazepam é menos afetado (metabolismo por glucuronidação)',
    'Aumento de 2-5x nos níveis plasmáticos dos benzodiazepínicos → sedação excessiva e prolongada, comprometimento psicomotor, depressão respiratória, amnésia anterógrada',
    'Preferir azitromicina quando possível (não inibe CYP3A4). Se claritromicina necessária: reduzir dose do benzodiazepínico em 50%, evitar alprazolam e triazolam, preferir lorazepam. Monitorar nível de consciência e SpO₂',
    'SEDAÇÃO AUMENTADA — Claritromicina inibe CYP3A4; reduzir BZD em 50% ou preferir lorazepam',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.respiratoryDepression, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),

  // ── Corticosteroides ──────────────────────────────────────────────────────
  ('dexametasona', 'aine', InteractionSeverity.major,
    'Corticosteroide + AINE: inibição dupla das prostaglandinas protetoras da mucosa gástrica',
    'Risco muito elevado de úlcera péptica e hemorragia GI',
    'Contraindicado sem proteção gástrica. Prescrever IBP obrigatoriamente se combinação necessária',
    'ALTO RISCO DE HEMORRAGIA GI — Prescrever IBP obrigatoriamente',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx]),

  // ── Hiperpotassemia ────────────────────────────────────────────────────────
  ('espironolactona', 'cloreto de potassio', InteractionSeverity.contraindicated,
    'Espironolactona retém potássio + suplementação adicional = hipercalemia aditiva extrema',
    'Hipercalemia fatal — parada cardíaca em assistolia',
    'Contraindicado. Não suplementar potássio rotineiramente com espironolactona. Monitorar K+ sérico',
    'NÃO UTILIZAR — Hipercalemia fatal; parada cardíaca',
    EvidenceLevel.established,
    {RiskType.hyperkalemia, RiskType.arrhythmia},
    [_kRefGG, _kRefFDA]),

  // ── Colchicina / Imunossupressores ────────────────────────────────────────
  ('colchicina', 'claritromicina', InteractionSeverity.contraindicated,
    'Inibição da P-gp e CYP3A4 eleva drasticamente os níveis de colchicina',
    'Toxicidade por colchicina — miopatia, neuropatia, pancitopenia, falência de múltiplos órgãos',
    'Contraindicado em insuficiência renal ou hepática. Reduzir dose de colchicina e monitorar rigidamente',
    'NÃO UTILIZAR — Toxicidade por colchicina com risco de falência orgânica',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.myelosuppression, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefFDA]),
  ('alopurinol', 'azatioprina', InteractionSeverity.contraindicated,
    'Alopurinol inibe xantina oxidase — enzima que metaboliza azatioprina — causando acúmulo tóxico',
    'Mielossupressão grave: leucopenia, trombocitopenia, anemia aplásica',
    'Contraindicado. Se combinação inevitável, reduzir azatioprina a 25% da dose e monitorar hemograma semanalmente',
    'NÃO UTILIZAR — Mielossupressão grave; risco de aplasia medular',
    EvidenceLevel.established,
    {RiskType.myelosuppression, RiskType.increasedToxicity},
    [_kRefGG, _kRefFDA, _kRefMdx]),

  // ── Interações farmacodinâmicas adicionais ────────────────────────────────
  ('ondansetrona', 'tramadol', InteractionSeverity.moderate,
    'Ondansetrona bloqueia receptores 5-HT₃ utilizados pelo tramadol para analgesia',
    'Redução significativa do efeito analgésico do tramadol',
    'Avaliar eficácia analgésica. Se necessário, substituir por outro antiemético ou usar analgésico alternativo',
    'Necessita monitorização — analgesia do tramadol pode ser reduzida',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy},
    [_kRefMdx, _kRefUT]),
  ('insulina', 'dapagliflozina', InteractionSeverity.moderate,
    'Efeito hipoglicemiante aditivo — iSGLT2 potencializa o efeito da insulina',
    'Hipoglicemia grave, especialmente com insulina basal ou bolus elevados',
    'Reduzir dose de insulina em 10–20% ao iniciar iSGLT2. Monitorar glicemia frequentemente',
    'Necessita monitorização de glicemia — reduzir insulina ao iniciar iSGLT2',
    EvidenceLevel.established,
    {RiskType.hypoglycemia},
    [_kRefGG, _kRefFDA, _kRefUT]),
  ('amitriptilina', 'atropina', InteractionSeverity.moderate,
    'Efeitos anticolinérgicos aditivos — bloqueio muscarínico somado',
    'Boca seca intensa, retenção urinária, visão turva, confusão, delírio (especialmente em idosos)',
    'Evitar em idosos. Se necessário, usar menor dose possível e monitorar sintomas anticolinérgicos',
    'Necessita monitorização clínica — toxicidade anticolinérgica aditiva',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.increasedToxicity},
    [_kRefGG, _kRefKatz]),

  // ══════════════════════════════════════════════════════════════════════════
  // INTERAÇÕES — MERGE v2 (modelo expandido)
  // ══════════════════════════════════════════════════════════════════════════

  // ── Dronedarona ───────────────────────────────────────────────────────────
  ('dronedarona', 'dabigatrana', InteractionSeverity.major,
    'Dronedarona inibe P-glicoproteína → aumenta absorção e nível sérico de dabigatrana',
    'Risco hemorrágico elevado — aumento de até 100% na exposição à dabigatrana',
    'Reduzir dose de dabigatrana para 75 mg 2x/dia com dronedarona. Monitorar sinais de sangramento',
    'ALTO RISCO DE SANGRAMENTO — Reduzir dose de dabigatrana',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefFDA]),
  ('dronedarona', 'sinvastatina', InteractionSeverity.major,
    'Inibição do CYP3A4 e P-gp pela dronedarona aumenta nível de sinvastatina',
    'Risco de miopatia/rabdomiólise',
    'Dose máxima de sinvastatina: 20 mg/dia. Preferir rosuvastatina ou pravastatina',
    'RISCO DE RABDOMIÓLISE — Limitar sinvastatina a 20 mg/dia',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefMdx, _kRefFDA]),
  ('dronedarona', 'metoprolol', InteractionSeverity.major,
    'Inibição do CYP2D6 pela dronedarona aumenta nível de metoprolol + efeito cronotrópico negativo aditivo',
    'Bradicardia grave, bloqueio AV, hipotensão',
    'Monitorar FC e ECG. Reduzir dose de metoprolol. Alvo: FC ≥50 bpm em repouso',
    'ALTO RISCO CARDIOVASCULAR — Monitorar FC e ECG',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.plasmaLevel},
    [_kRefMdx, _kRefLex]),
  ('dronedarona', 'digoxina', InteractionSeverity.major,
    'Inibição da P-gp aumenta nível sérico de digoxina',
    'Toxicidade digitálica — náuseas, bradicardia, distúrbios de condução',
    'Reduzir dose de digoxina em 50%. Monitorar nível sérico e ECG regularmente',
    'ALTO RISCO DE TOXICIDADE DIGITÁLICA — Reduzir digoxina 50%',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.cardiovascular},
    [_kRefMdx, _kRefFDA]),
  ('dronedarona', 'warfarina', InteractionSeverity.moderate,
    'Inibição do CYP3A4 e possível efeito no CYP2C9 pela dronedarona',
    'Elevação moderada do INR',
    'Monitorar INR semanalmente nas primeiras 2–4 semanas após introdução. Ajustar dose de warfarina conforme necessário',
    'Necessita monitorização de INR nas primeiras 2–4 semanas',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),
  ('dronedarona', 'ciclosporina', InteractionSeverity.contraindicated,
    'Inibição mútua do CYP3A4 e P-gp — exposição de ambos aumenta drasticamente',
    'Toxicidade por ciclosporina (nefrotóxica) e toxicidade cardíaca por dronedarona',
    'Combinação contraindicada. Substituir por antiarrítmico alternativo',
    'NÃO UTILIZAR — Toxicidade grave bilateral',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.cardiovascular, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),

  // ── Ivabradina ────────────────────────────────────────────────────────────
  ('ivabradina', 'diltiazem', InteractionSeverity.contraindicated,
    'Diltiazem inibe CYP3A4 (aumenta nível de ivabradina) + efeito cronotrópico negativo aditivo no nó sinusal',
    'Bradicardia grave, bloqueio sinusal, assistolia',
    'Combinação contraindicada. Usar apenas um agente para controle de FC',
    'NÃO UTILIZAR — Bradicardia grave e assistolia',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    [_kRefFDA, _kRefMdx]),
  ('ivabradina', 'verapamil', InteractionSeverity.contraindicated,
    'Verapamil inibe CYP3A4 + efeito bradicardizante sinérgico',
    'Bradicardia grave, síncope, parada sinusal',
    'Contraindicado — não combinar ivabradina com bloqueadores de cálcio não-diidropiridínicos',
    'NÃO UTILIZAR — Bradicardia grave e parada sinusal',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    [_kRefFDA, _kRefMdx]),
  ('ivabradina', 'claritromicina', InteractionSeverity.major,
    'Inibição potente do CYP3A4 pela claritromicina aumenta exposição à ivabradina em ~7×',
    'Bradicardia grave, prolongamento QT, Torsade de Pointes',
    'Contraindicado. Suspender ivabradina durante curso de claritromicina. Alternativa: azitromicina',
    'ALTO RISCO CARDIOVASCULAR — Suspender ivabradina',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.cardiovascular, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),
  ('ivabradina', 'fluconazol', InteractionSeverity.major,
    'Inibição do CYP3A4 pelo fluconazol aumenta significativamente o nível de ivabradina',
    'Bradicardia excessiva, tontura, fosfenos',
    'Monitorar FC. Reduzir dose de ivabradina se FC <50 bpm. Considerar antifúngico alternativo',
    'ALTO RISCO DE BRADICARDIA — Monitorar FC',
    EvidenceLevel.probable,
    {RiskType.cardiovascular, RiskType.plasmaLevel},
    [_kRefMdx, _kRefLex]),

  // ── Ranolazina ────────────────────────────────────────────────────────────
  ('ranolazina', 'claritromicina', InteractionSeverity.contraindicated,
    'Inibição potente do CYP3A4 aumenta ranolazina em >5× + ambos prolongam QTc',
    'Prolongamento QTc grave, Torsade de Pointes, arritmia ventricular fatal',
    'Contraindicado. Substituir por azitromicina ou doxiciclina',
    'NÃO UTILIZAR — Arritmia ventricular fatal',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),
  ('ranolazina', 'amiodarona', InteractionSeverity.major,
    'Amiodarona inibe CYP3A4 + ambos prolongam QTc por mecanismos distintos',
    'Prolongamento QTc excessivo, Torsade de Pointes',
    'Evitar combinação. Se necessária, monitorar QTc (ECG seriado). Suspender se QTc >500 ms',
    'ALTO RISCO DE TORSADE DE POINTES — Monitorar QTc seriado',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefMdx, _kRefUT]),
  ('ranolazina', 'digoxina', InteractionSeverity.moderate,
    'Ranolazina inibe P-gp → aumento do nível sérico de digoxina em ~50%',
    'Toxicidade digitálica — bradiarritmias, náuseas, distúrbios visuais',
    'Reduzir dose de digoxina em 50% ao iniciar ranolazina. Monitorar nível sérico',
    'Necessita monitorização — toxicidade digitálica por aumento de nível',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.arrhythmia},
    [_kRefMdx, _kRefFDA]),
  ('ranolazina', 'sinvastatina', InteractionSeverity.moderate,
    'Inibição do CYP3A4 pela ranolazina aumenta exposição à sinvastatina',
    'Risco aumentado de miopatia',
    'Limitar sinvastatina a 20 mg/dia com ranolazina. Monitorar CPK e sintomas musculares',
    'Necessita monitorização — limitar sinvastatina a 20 mg/dia',
    EvidenceLevel.probable,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefMdx, _kRefFDA]),

  // ── Eplerenona ────────────────────────────────────────────────────────────
  ('eplerenona', 'cloreto de potassio', InteractionSeverity.contraindicated,
    'Eplerenona retém K⁺ (poupador de potássio) + suplementação adicional',
    'Hipercalemia fatal — parada cardíaca',
    'Contraindicado. Não suplementar potássio rotineiramente com eplerenona. Monitorar K⁺ sérico rigorosamente',
    'NÃO UTILIZAR — Hipercalemia fatal; parada cardíaca',
    EvidenceLevel.established,
    {RiskType.hyperkalemia, RiskType.arrhythmia},
    [_kRefFDA, _kRefGG]),
  ('eplerenona', 'enalapril', InteractionSeverity.moderate,
    'Ambos elevam K⁺ por mecanismos distintos — antagonismo aldosterona + inibição da angiotensina II',
    'Hipercalemia, especialmente em DRC ou diabetes',
    'Monitorar K⁺ e creatinina semanalmente no início. Reduzir/suspender eplerenona se K⁺ >5,5 mEq/L',
    'Necessita monitorização de K+ sérico semanal',
    EvidenceLevel.established,
    {RiskType.hyperkalemia},
    [_kRefGG, _kRefUT]),
  ('eplerenona', 'claritromicina', InteractionSeverity.contraindicated,
    'Inibição potente do CYP3A4 pela claritromicina aumenta exposição à eplerenona em >5×',
    'Hipercalemia grave e excessiva retenção de potássio',
    'Contraindicado. Substituir por azitromicina. Aguardar 14 dias após claritromicina antes de reiniciar eplerenona',
    'NÃO UTILIZAR — Hipercalemia grave; substituir por azitromicina',
    EvidenceLevel.established,
    {RiskType.hyperkalemia, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),

  // ── Daptomicina ───────────────────────────────────────────────────────────
  ('daptomicina', 'estatina', InteractionSeverity.major,
    'Mecanismo sinérgico de miotoxicidade — ambos lesam membranas musculares por mecanismos complementares',
    'Miopatia grave e rabdomiólise',
    'Suspender estatinas durante uso de daptomicina. Monitorar CPK semanalmente. Reiniciar estatina após término do antibiótico',
    'ALTO RISCO DE RABDOMIÓLISE — Suspender estatina durante daptomicina',
    EvidenceLevel.established,
    {RiskType.myopathy},
    [_kRefMdx, _kRefFDA]),
  ('daptomicina', 'aminoglicosideo', InteractionSeverity.moderate,
    'Possível nefrotoxicidade aditiva — ambos podem elevar creatinina em uso prolongado',
    'Insuficiência renal aguda, especialmente em pacientes vulneráveis',
    'Monitorar creatinina e eletrólitos diariamente. Minimizar duração e dose de aminoglicosídeo',
    'Necessita monitorização renal diária',
    EvidenceLevel.probable,
    {RiskType.nephrotoxicity},
    [_kRefMdx, _kRefUT]),

  // ── Nirmatrelvir/Ritonavir (Paxlovid) ────────────────────────────────────
  ('ritonavir', 'sinvastatina', InteractionSeverity.contraindicated,
    'Inibição potente do CYP3A4 pelo ritonavir aumenta sinvastatina >10× — rabdomiólise',
    'Rabdomiólise grave, insuficiência renal, coagulação intravascular disseminada',
    'Contraindicado absolutamente. Suspender sinvastatina durante uso de Paxlovid',
    'NÃO UTILIZAR — Rabdomiólise com CID; risco de morte',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.nephrotoxicity, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),
  ('ritonavir', 'midazolam', InteractionSeverity.contraindicated,
    'Inibição potente do CYP3A4 pelo ritonavir → nível de midazolam aumenta dezenas de vezes',
    'Sedação prolongada e grave, depressão respiratória, coma',
    'Contraindicado. Não usar midazolam oral/parenteral com ritonavir',
    'NÃO UTILIZAR — Sedação grave e coma',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),
  ('ritonavir', 'amiodarona', InteractionSeverity.contraindicated,
    'Inibição do CYP3A4 e CYP2C8 pelo ritonavir aumenta amiodarona dramaticamente + QT aditivo',
    'Toxicidade por amiodarona (pulmonar, hepática, tireoidiana) e Torsade de Pointes',
    'Contraindicado. Substituir ritonavir se paciente em uso de amiodarona. Paxlovid contraindicado nestas situações',
    'NÃO UTILIZAR — Toxicidade grave por amiodarona e arritmia',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.hepatotoxicity, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),
  ('ritonavir', 'warfarina', InteractionSeverity.major,
    'Ritonavir é indutor e inibidor do CYP2C9 (efeito bifásico) — INR pode aumentar ou diminuir',
    'Instabilidade do INR — risco de sangramento ou trombose dependendo da fase',
    'Monitorar INR a cada 1–2 dias durante uso de Paxlovid e por 2 semanas após. Ajustar dose de varfarina',
    'ALTO RISCO — Monitorar INR diariamente durante Paxlovid',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),
  ('ritonavir', 'atorvastatina', InteractionSeverity.major,
    'Inibição do CYP3A4 pelo ritonavir aumenta atorvastatina em ~8×',
    'Risco significativo de miopatia/rabdomiólise',
    'Suspender atorvastatina durante uso de Paxlovid (5 dias). Reiniciar após término. Alternativa: pravastatina ou rosuvastatina em baixa dose',
    'RISCO DE RABDOMIÓLISE — Suspender atorvastatina durante Paxlovid',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),
  ('ritonavir', 'carbamazepina', InteractionSeverity.major,
    'Carbamazepina é indutor potente do CYP3A4 → reduz drasticamente níveis de nirmatrelvir/ritonavir',
    'Falha terapêutica do Paxlovid — concentrações subterapêuticas de nirmatrelvir',
    'Paxlovid contraindicado com carbamazepina. Considerar molnupiravir como alternativa',
    'ALTO RISCO DE FALHA TERAPÊUTICA — Paxlovid ineficaz com carbamazepina',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefFDA, _kRefUT]),
  ('ritonavir', 'ranolazina', InteractionSeverity.contraindicated,
    'Inibição do CYP3A4 pelo ritonavir eleva ranolazina drasticamente + prolongamento QTc aditivo',
    'Arritmia ventricular grave, Torsade de Pointes',
    'Contraindicado. Suspender ranolazina durante uso de Paxlovid',
    'NÃO UTILIZAR — Arritmia ventricular fatal',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefFDA, _kRefMdx]),

  // ── Semaglutida / Tirzepatida (arGLP-1) ──────────────────────────────────
  ('semaglutida', 'insulina', InteractionSeverity.moderate,
    'Efeito hipoglicemiante aditivo — arGLP-1 potencia ação da insulina',
    'Hipoglicemia grave, especialmente com insulina basal ou prandial em altas doses',
    'Reduzir dose de insulina em 20–40% ao iniciar arGLP-1. Monitorar glicemia. Titular gradualmente',
    'Necessita monitorização — reduzir insulina ao iniciar arGLP-1',
    EvidenceLevel.established,
    {RiskType.hypoglycemia},
    [_kRefGG, _kRefFDA, _kRefUT]),
  ('semaglutida', 'sulfonilureia', InteractionSeverity.moderate,
    'Efeito insulinotrópico aditivo com risco aumentado de hipoglicemia',
    'Hipoglicemia grave, tontura, sudorese, convulsões',
    'Reduzir dose da sulfonilureia em 50% ao iniciar semaglutida. Monitorar glicemia capilar diariamente',
    'Necessita monitorização — reduzir sulfonilureia ao iniciar semaglutida',
    EvidenceLevel.established,
    {RiskType.hypoglycemia},
    [_kRefFDA, _kRefUT]),
  ('semaglutida', 'levotiroxina', InteractionSeverity.monitorOnly,
    'Retardo do esvaziamento gástrico pela semaglutida pode reduzir absorção da levotiroxina',
    'Redução da absorção de levotiroxina → hipotireoidismo subclínico',
    'Tomar levotiroxina em jejum, ≥30 min antes da semaglutida se via oral (Rybelsus). Monitorar TSH a cada 6–8 semanas',
    'Só monitorizar — monitorar TSH a cada 6–8 semanas',
    EvidenceLevel.possible,
    {RiskType.reducedEfficacy},
    [_kRefMdx, _kRefUT]),

  // ── Canagliflozina / iSGLT2 ──────────────────────────────────────────────
  ('canagliflozina', 'furosemida', InteractionSeverity.moderate,
    'Efeito natriurético e diurético aditivo — ambos causam depleção de volume',
    'Hipotensão grave, IRA pré-renal, desidratação, hipocalemia',
    'Monitorar PA, função renal e eletrólitos. Reduzir dose de furosemida se necessário. Hidratação adequada',
    'Necessita monitorização clínica/laboratorial — depleção de volume',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.nephrotoxicity, RiskType.hypokalemia},
    [_kRefGG, _kRefFDA]),
  ('canagliflozina', 'enalapril', InteractionSeverity.moderate,
    'Efeito natriurético dos iSGLT2 associado a vasodilatação dos IECAs — hipotensão e hipercalemia',
    'Hipotensão sintomática, IRA pré-renal, hipercalemia',
    'Monitorar PA, K⁺ e função renal nas primeiras 2–4 semanas. Hidratação adequada',
    'Necessita monitorização de PA e função renal',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.hyperkalemia},
    [_kRefGG, _kRefUT]),
  ('canagliflozina', 'rifampicina', InteractionSeverity.moderate,
    'Rifampicina induz UGT e CYP → redução de 51% na exposição à canagliflozina',
    'Redução do efeito hipoglicemiante e nefroprotetor',
    'Monitorar controle glicêmico. Pode ser necessário aumentar dose de canagliflozina ou substituir por outra classe',
    'Necessita monitorização glicêmica — eficácia reduzida',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),

  // ── Finerenona ────────────────────────────────────────────────────────────
  ('finerenona', 'claritromicina', InteractionSeverity.contraindicated,
    'Inibição potente do CYP3A4 pela claritromicina aumenta finerenona em >5×',
    'Hipercalemia grave e potencialmente fatal',
    'Contraindicado. Suspender finerenona durante uso de claritromicina. Alternativa: azitromicina',
    'NÃO UTILIZAR — Hipercalemia grave; substituir por azitromicina',
    EvidenceLevel.established,
    {RiskType.hyperkalemia, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),
  ('finerenona', 'espironolactona', InteractionSeverity.contraindicated,
    'Antagonismo mineralocorticoide aditivo — duplo bloqueio do receptor de aldosterona',
    'Hipercalemia grave, parada cardíaca',
    'Contraindicado — não combinar dois ARM. Escolher apenas um deles',
    'NÃO UTILIZAR — Hipercalemia fatal por duplo bloqueio de ARM',
    EvidenceLevel.established,
    {RiskType.hyperkalemia, RiskType.arrhythmia},
    [_kRefFDA, _kRefGG]),
  ('finerenona', 'enalapril', InteractionSeverity.moderate,
    'Efeito poupador de potássio da finerenona + redução da excreção de K⁺ pelo IECA',
    'Hipercalemia — risco aumentado, especialmente em DRC',
    'Monitorar K⁺ semanalmente nas primeiras 4 semanas. Suspender se K⁺ >5,5 mEq/L',
    'Necessita monitorização de K+ semanal nas primeiras 4 semanas',
    EvidenceLevel.established,
    {RiskType.hyperkalemia},
    [_kRefFDA, _kRefUT]),

  // ── Tocilizumabe / Baricitinibe ───────────────────────────────────────────
  ('tocilizumabe', 'warfarina', InteractionSeverity.moderate,
    'IL-6 regula expressão de enzimas CYP; ao bloquear IL-6, tocilizumabe restaura metabolismo de varfarina (reduz INR)',
    'Redução inesperada do INR quando tocilizumabe é iniciado ou escalado',
    'Monitorar INR semanalmente por 4–6 semanas após início do tocilizumabe. Ajustar dose de varfarina',
    'Necessita monitorização de INR — tocilizumabe pode reduzir INR',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.thrombosis},
    [_kRefMdx, _kRefUT]),
  ('tocilizumabe', 'estatina', InteractionSeverity.moderate,
    'Bloqueio de IL-6 restaura CYP3A4 — estatinas metabolizadas por CYP3A4 têm metabolismo aumentado',
    'Redução dos níveis plasmáticos de estatinas — menor efeito hipolipemiante',
    'Monitorar perfil lipídico 4–8 semanas após início. Pode ser necessário aumentar dose da estatina',
    'Necessita monitorização do perfil lipídico',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),
  ('baricitinibe', 'ssri', InteractionSeverity.monitorOnly,
    'Inibição do transportador OAT3 pelo baricitinibe pode aumentar levemente concentração de alguns SSRIs',
    'Aumento marginal da exposição a SSRIs renalmente eliminados',
    'Monitorar efeitos adversos dos SSRIs. Interação geralmente não requer ajuste de dose',
    'Só monitorizar — ajuste de dose geralmente não necessário',
    EvidenceLevel.theoretical,
    {RiskType.plasmaLevel},
    [_kRefMdx, _kRefLex]),

  // ── Vedolizumabe ──────────────────────────────────────────────────────────
  ('vedolizumabe', 'natalizumabe', InteractionSeverity.contraindicated,
    'Ambos são antagonistas de integrinas — imunomodulação aditiva sistêmica e intestinal',
    'Risco muito aumentado de infecções oportunistas e leucoencefalopatia multifocal progressiva (LMP)',
    'Contraindicado — não combinar biológicos anti-integrinas. Washout adequado entre os agentes',
    'NÃO UTILIZAR — Risco de LMP e infecções oportunistas graves',
    EvidenceLevel.established,
    {RiskType.infection},
    [_kRefFDA, _kRefMdx]),

  // ── Tofacitinibe ──────────────────────────────────────────────────────────
  ('tofacitinibe', 'ciclosporina', InteractionSeverity.contraindicated,
    'Inibição do CYP3A4 + imunossupressão aditiva potente',
    'Infecções oportunistas graves, nefrotoxicidade, linfoma',
    'Contraindicado. Não combinar JAKi com imunossupressores biológicos potentes',
    'NÃO UTILIZAR — Imunossupressão excessiva com risco de linfoma',
    EvidenceLevel.established,
    {RiskType.infection, RiskType.nephrotoxicity},
    [_kRefFDA, _kRefMdx]),
  ('tofacitinibe', 'fluconazol', InteractionSeverity.major,
    'Inibição do CYP3A4 e CYP2C19 pelo fluconazol aumenta exposição ao tofacitinibe em ~130%',
    'Toxicidade por tofacitinibe — infecções, trombose, elevação de enzimas hepáticas',
    'Reduzir dose de tofacitinibe para 5 mg 1x/dia durante uso de fluconazol. Monitorar hemograma e transaminases',
    'ALTO RISCO — Reduzir dose de tofacitinibe e monitorar hemograma',
    EvidenceLevel.established,
    {RiskType.infection, RiskType.hepatotoxicity, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),
  ('tofacitinibe', 'rifampicina', InteractionSeverity.major,
    'Rifampicina induz CYP3A4 → redução de ~84% na exposição ao tofacitinibe',
    'Falha terapêutica — concentrações subterapêuticas',
    'Evitar combinação. Se necessário, monitorar atividade da doença de base. Considerar alternativa biológica',
    'ALTO RISCO DE FALHA TERAPÊUTICA — Evitar combinação',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),

  // ── Ruxolitinibe ──────────────────────────────────────────────────────────
  ('ruxolitinibe', 'claritromicina', InteractionSeverity.major,
    'Inibição potente do CYP3A4 → aumento de ~200% na exposição ao ruxolitinibe',
    'Citopenia grave (anemia, trombocitopenia), infecções oportunistas, toxicidade hepática',
    'Reduzir dose de ruxolitinibe em 50% durante uso de claritromicina. Monitorar hemograma. Alternativa: azitromicina',
    'ALTO RISCO DE CITOPENIA GRAVE — Reduzir dose de ruxolitinibe 50%',
    EvidenceLevel.established,
    {RiskType.myelosuppression, RiskType.infection, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),
  ('ruxolitinibe', 'fluconazol', InteractionSeverity.moderate,
    'Inibição do CYP3A4 aumenta exposição ao ruxolitinibe em ~100%',
    'Citopenia e risco de infecções oportunistas aumentado',
    'Reduzir dose de ruxolitinibe em 50%. Monitorar hemograma frequentemente',
    'Necessita monitorização — reduzir dose de ruxolitinibe 50%',
    EvidenceLevel.established,
    {RiskType.myelosuppression, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),

  // ── Dupilumabe / Biológicos respiratórios ─────────────────────────────────
  ('dupilumabe', 'vacinas vivas', InteractionSeverity.major,
    'Imunossupressão relativa causada por dupilumabe pode reduzir resposta imunológica a vacinas vivas',
    'Risco de infecção pela cepa vacinal (vacina viva atenuada)',
    'Não administrar vacinas vivas durante uso de dupilumabe. Completar vacinação antes de iniciar biológico',
    'ALTO RISCO — Vacinas vivas contraindicadas durante dupilumabe',
    EvidenceLevel.established,
    {RiskType.infection},
    [_kRefFDA, _kRefMdx]),
  ('mepolizumabe', 'corticosteroide sistemico', InteractionSeverity.moderate,
    'Redução dos eosinófilos pelo mepolizumabe permite desmame dos corticosteroides, mas retirada abrupta causa insuficiência adrenal',
    'Insuficiência adrenal aguda se corticosteroide retirado abruptamente',
    'Desmame LENTO e gradual de corticosteroides sistêmicos — nunca retirar abruptamente. Monitorar sintomas de insuficiência adrenal',
    'Necessita desmame LENTO dos corticosteroides — nunca suspensão abrupta',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    [_kRefFDA, _kRefUT]),

  // ── Isavuconazol ──────────────────────────────────────────────────────────
  ('isavuconazol', 'rifampicina', InteractionSeverity.contraindicated,
    'Rifampicina induz CYP3A4 potentemente → redução drástica dos níveis de isavuconazol',
    'Falha terapêutica antifúngica — concentrações subterapêuticas',
    'Contraindicado — combinação invalida o tratamento antifúngico',
    'NÃO UTILIZAR — Falha terapêutica antifúngica garantida',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),
  ('isavuconazol', 'ciclosporina', InteractionSeverity.moderate,
    'Inibição do CYP3A4 pelo isavuconazol aumenta exposição à ciclosporina',
    'Toxicidade por ciclosporina — nefrotoxicidade, neurotoxicidade',
    'Monitorar nível sérico de ciclosporina. Reduzir dose em 25–50% se necessário. Isavuconazol é inibidor CYP3A4 mais fraco que voriconazol',
    'Necessita monitorização de nível sérico de ciclosporina',
    EvidenceLevel.probable,
    {RiskType.nephrotoxicity, RiskType.plasmaLevel},
    [_kRefMdx, _kRefLex]),
  ('isavuconazol', 'warfarina', InteractionSeverity.moderate,
    'Inibição do CYP2C9 pelo isavuconazol pode aumentar nível de varfarina',
    'Elevação do INR e risco hemorrágico',
    'Monitorar INR a cada 2–3 dias após início e término do isavuconazol. Ajustar dose de varfarina conforme necessário',
    'Necessita monitorização de INR a cada 2–3 dias',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefMdx, _kRefLex]),

  // ── Eltrombopague ─────────────────────────────────────────────────────────
  ('eltrombopague', 'antiácido', InteractionSeverity.major,
    'Cátions polivalentes (Al, Mg, Ca) dos antiácidos formam quelatos com eltrombopague no TGI',
    'Redução de até 70% na absorção do eltrombopague → falha terapêutica',
    'Administrar eltrombopague ≥4 horas antes ou ≥2 horas após antiácidos, suplementos de cálcio ou ferro',
    'ALTO RISCO DE FALHA TERAPÊUTICA — Separar por ≥4 horas',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefFDA, _kRefMdx]),
  ('eltrombopague', 'sulfato ferroso', InteractionSeverity.major,
    'Ferro quelata eltrombopague no intestino — redução drástica da absorção',
    'Falha terapêutica da trombocitopoiese',
    'Separar eltrombopague do ferro por pelo menos 4 horas. Tomar eltrombopague em jejum',
    'ALTO RISCO DE FALHA TERAPÊUTICA — Separar por ≥4 horas',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefFDA, _kRefMdx]),
  ('eltrombopague', 'ciclosporina', InteractionSeverity.moderate,
    'Inibição do OATP1B1 e CYP1A2 pelo eltrombopague pode aumentar exposição à ciclosporina',
    'Nefrotoxicidade por aumento do nível de ciclosporina',
    'Monitorar nível sérico de ciclosporina. Ajustar dose conforme necessário',
    'Necessita monitorização de nível sérico de ciclosporina',
    EvidenceLevel.probable,
    {RiskType.nephrotoxicity, RiskType.plasmaLevel},
    [_kRefMdx, _kRefLex]),

  // ── Denosumabe ────────────────────────────────────────────────────────────
  ('denosumabe', 'corticosteroide sistemico', InteractionSeverity.moderate,
    'Ambos aumentam risco de osteonecrose mandibular e fraturas atípicas; corticosteroides causam osteoporose adicional',
    'Risco de osteonecrose mandibular e fraturas ósseas graves',
    'Avaliação odontológica obrigatória antes de iniciar. Garantir reposição adequada de Ca²⁺ e vitamina D. Monitorar DMO',
    'Necessita avaliação odontológica antes de iniciar + reposição Ca²⁺/VitD',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefFDA, _kRefUT]),

  // ── Bupropiona ────────────────────────────────────────────────────────────
  ('bupropiona', 'imao', InteractionSeverity.contraindicated,
    'Bupropiona inibe recaptação de dopamina/noradrenalina + IMAOs inibem degradação — hiperestimulação adrenérgica e serotoninérgica',
    'Crise hipertensiva, síndrome serotoninérgica, convulsões — risco de morte',
    'Contraindicado. Aguardar ≥14 dias após suspender IMAO antes de iniciar bupropiona',
    'NÃO UTILIZAR — Síndrome serotoninérgica e crise hipertensiva',
    EvidenceLevel.established,
    {RiskType.serotonin, RiskType.cardiovascular},
    [_kRefFDA, _kRefGG]),
  ('bupropiona', 'carbamazepina', InteractionSeverity.major,
    'Carbamazepina induz CYP3A4/2B6 → redução significativa dos níveis de bupropiona',
    'Falha antidepressiva e no programa de cessação tabágica',
    'Aumentar dose de bupropiona (monitorar efeito). Avaliar alternativa antidepressiva sem interação com indutores CYP',
    'ALTO RISCO DE FALHA TERAPÊUTICA — Monitorar eficácia da bupropiona',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefMdx, _kRefFDA]),
  ('bupropiona', 'tramadol', InteractionSeverity.major,
    'Ambos reduzem o limiar convulsivo por mecanismos independentes — sinergia pró-convulsivante',
    'Risco muito aumentado de convulsões generalizadas',
    'Evitar combinação. Se necessário, usar mínima dose de tramadol com monitoramento neurológico. Considerar analgésico alternativo',
    'ALTO RISCO DE CONVULSÕES — Evitar combinação',
    EvidenceLevel.established,
    {RiskType.cns},
    [_kRefMdx, _kRefFDA]),
  ('bupropiona', 'ssri', InteractionSeverity.moderate,
    'Bupropiona inibe CYP2D6 → aumenta exposição a fluoxetina, paroxetina e outros SSRIs metabolizados por esse CYP',
    'Síndrome serotoninérgica leve a moderada, elevação de efeitos adversos dos SSRIs',
    'Monitorar sinais de excesso serotoninérgico. Considerar redução da dose do SSRI se sintomas surgem',
    'Necessita monitorização — risco de síndrome serotoninérgica leve',
    EvidenceLevel.probable,
    {RiskType.serotonin, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),

  // ── Aripiprazol ───────────────────────────────────────────────────────────
  ('aripiprazol', 'claritromicina', InteractionSeverity.major,
    'Inibição do CYP3A4 pela claritromicina aumenta exposição ao aripiprazol em ~90%',
    'Toxicidade por aripiprazol — acatisia intensa, hipotensão, sedação, convulsões (raro)',
    'Reduzir dose de aripiprazol em 50% durante uso de claritromicina. Monitorar efeitos adversos',
    'ALTO RISCO — Reduzir dose de aripiprazol 50%',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.increasedToxicity},
    [_kRefFDA, _kRefMdx]),
  ('aripiprazol', 'fluoxetina', InteractionSeverity.moderate,
    'Fluoxetina inibe CYP2D6 e CYP3A4 → aumento de 100% na exposição ao aripiprazol',
    'Acatisia, sedação excessiva, hipotensão ortostática',
    'Reduzir dose de aripiprazol em 50% com fluoxetina. Monitorar efeitos extrapiramidais e PA',
    'Necessita monitorização — reduzir dose de aripiprazol 50%',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.cardiovascular},
    [_kRefFDA, _kRefMdx]),

  // ── Perampanel ────────────────────────────────────────────────────────────
  ('perampanel', 'carbamazepina', InteractionSeverity.major,
    'Carbamazepina induz potentemente CYP3A4 → redução de ~67% na exposição ao perampanel',
    'Falha antiepiléptica — concentrações subterapêuticas de perampanel',
    'Triplicar a dose-alvo de perampanel quando em uso com carbamazepina. Titular cuidadosamente com monitoramento clínico',
    'ALTO RISCO DE FALHA ANTIEPILÉPTICA — Triplicar dose de perampanel',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),
  ('perampanel', 'alcool', InteractionSeverity.major,
    'Perampanel potencializa depressão do SNC pelo álcool; pode aumentar comportamentos agressivos/impulsivos',
    'Sedação grave, comportamento irracional, agressividade, maior risco de acidentes',
    'Contraindicado uso de álcool com perampanel. Orientar paciente explicitamente',
    'ALTO RISCO — Proibido álcool com perampanel',
    EvidenceLevel.established,
    {RiskType.cns},
    [_kRefFDA, _kRefMdx]),

  // ── Rifaximina ────────────────────────────────────────────────────────────
  ('rifaximina', 'anticoncepcional', InteractionSeverity.monitorOnly,
    'Mesmo com absorção mínima, pode alterar flora intestinal que participa da circulação êntero-hepática dos anticoncepcionais',
    'Redução teórica (baixo risco clinicamente) da eficácia anticoncepcional hormonal',
    'Risco muito baixo (absorção <1%). Porém, orientar uso de método contraceptivo de barreira adicional por precaução durante e 7 dias após o curso',
    'Só monitorizar — considerar método contraceptivo de barreira adicional',
    EvidenceLevel.theoretical,
    {RiskType.reducedEfficacy},
    [_kRefMdx, _kRefUT]),

  // ── Nintedanibe ───────────────────────────────────────────────────────────
  ('nintedanibe', 'warfarina', InteractionSeverity.moderate,
    'Nintedanibe inibe P-gp e CYP3A4; interação potencial aumentando nível de varfarina',
    'Elevação do INR e risco hemorrágico — intensificado pelo risco de sangramento GI do nintedanibe',
    'Monitorar INR semanalmente. Vigilância redobrada para sinais de sangramento GI',
    'Necessita monitorização de INR semanal — risco hemorrágico aditivo',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),
  ('nintedanibe', 'rifampicina', InteractionSeverity.major,
    'Rifampicina induz P-gp e CYP3A4 → redução de ~60% nos níveis de nintedanibe',
    'Falha terapêutica na FPI — progressão da fibrose',
    'Evitar combinação. Se tratamento de TB necessário, avaliar alternativa antifibrótica ou substituição do antimicrobiano',
    'ALTO RISCO DE FALHA TERAPÊUTICA — Evitar rifampicina com nintedanibe',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),

  // ── Fondaparinux ──────────────────────────────────────────────────────────
  ('fondaparinux', 'ssri', InteractionSeverity.moderate,
    'SSRIs inibem função plaquetária (redução de serotonina plaquetária) + anticoagulação do fondaparinux',
    'Risco aumentado de sangramento — especialmente GI',
    'Monitorar sinais de sangramento. Considerar IBP para proteção gástrica em uso combinado',
    'Necessita monitorização clínica — risco hemorrágico aditivo',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic},
    [_kRefMdx, _kRefUT]),
  ('fondaparinux', 'aine', InteractionSeverity.moderate,
    'AINEs inibem função plaquetária e protegem mucosa gástrica — risco hemorrágico aditivo',
    'Sangramento GI e em outros sítios',
    'Evitar AINEs com fondaparinux. Usar paracetamol para analgesia. Se AINE necessário, associar IBP',
    'Necessita monitorização — evitar AINEs; usar paracetamol',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx]),

  // ── Lote 3 — Novas interações ─────────────────────────────────────────────

  // Gabapentina
  ('gabapentina', 'morfina', InteractionSeverity.major,
    'Sinergismo farmacodinâmico na depressão do SNC e do centro respiratório',
    'Depressão respiratória potencialmente fatal, sedação profunda, apneia',
    'Evitar combinação ou reduzir doses. Monitorar FR e saturação. Ter naloxona disponível',
    'ALTO RISCO DE DEPRESSÃO RESPIRATÓRIA — FDA Black Box Warning',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns},
    [_kRefFDA, _kRefMdx]),
  ('gabapentina', 'opioide', InteractionSeverity.major,
    'Sinergismo farmacodinâmico — ambos deprimem SNC e centro respiratório',
    'Depressão respiratória grave, sedação excessiva, risco de morte',
    'FDA Black Box Warning. Usar menor dose eficaz de cada. Monitorar SpO2 continuamente',
    'ALTO RISCO DE DEPRESSÃO RESPIRATÓRIA — FDA Black Box Warning',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns},
    [_kRefFDA, _kRefMdx, _kRefGG]),
  ('gabapentina', 'benzodiazepínico', InteractionSeverity.major,
    'Depressão aditiva do SNC pela combinação de anticonvulsivante + benzodiazepínico',
    'Sedação excessiva, depressão respiratória, risco de queda',
    'Reduzir doses. Monitorar nível de consciência. Evitar em idosos sem suporte monitorizado',
    'ALTO RISCO DE SEDAÇÃO E QUEDA — Reduzir doses e monitorar',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns},
    [_kRefFDA, _kRefMdx]),

  // Sertralina + Tramadol
  ('ssri', 'tramadol', InteractionSeverity.major,
    'Tramadol inibe recaptação de serotonina e noradrenalina; SSRIs aumentam serotonina sinapticamente — efeito serotoninérgico aditivo',
    'Síndrome serotoninérgica: hipertermia, agitação, mioclonias, diarreia, taquicardia — risco de morte',
    'Evitar combinação. Se dor intensa, preferir opioide puro (morfina, oxicodona). Monitorar triade serotoninérgica',
    'ALTO RISCO DE SÍNDROME SEROTONINÉRGICA — Evitar; usar morfina',
    EvidenceLevel.established,
    {RiskType.serotonin},
    [_kRefFDA, _kRefGG, _kRefMdx]),

  // Fenobarbital + DOACs/Anticoagulantes
  ('fenobarbital', 'warfarina', InteractionSeverity.major,
    'Fenobarbital induz potentemente CYP2C9 e CYP3A4, acelerando o metabolismo da warfarina',
    'Redução marcada do INR — falha anticoagulante e risco trombótico',
    'Monitorar INR semanalmente ao iniciar/suspender fenobarbital. Aumentar dose de warfarina conforme INR',
    'ALTO RISCO DE FALHA ANTICOAGULANTE — Monitorar INR semanalmente',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel, RiskType.thrombosis},
    [_kRefGG, _kRefMdx]),
  ('fenobarbital', 'apixabana', InteractionSeverity.major,
    'Indução de CYP3A4 e P-gp pelo fenobarbital reduz níveis plasmáticos de apixabana em ~50%',
    'Anticoagulação subterapêutica — risco de tromboembolismo (AVC, TEP, TVP)',
    'Contraindicado pela bula da apixabana. Substituir anticonvulsivante ou trocar anticoagulante',
    'ALTO RISCO DE TROMBOEMBOLISMO — Apixabana contraindicada com fenobarbital',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.thrombosis},
    [_kRefFDA, _kRefMdx]),
  ('fenobarbital', 'rivaroxabana', InteractionSeverity.major,
    'Indução de CYP3A4 e P-gp reduz exposição à rivaroxabana significativamente',
    'Perda de efeito anticoagulante — risco tromboembólico grave',
    'Contraindicado. Evitar combinação. Usar heparina ou warfarina com monitorização rigorosa do INR',
    'ALTO RISCO DE TROMBOEMBOLISMO — Rivaroxabana contraindicada com fenobarbital',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.thrombosis},
    [_kRefFDA, _kRefMdx]),

  // Metformina + Furosemida
  ('metformina', 'furosemida', InteractionSeverity.moderate,
    'Furosemida causa depleção de volume e reduz clearance renal de metformina; risco aumentado de acidose lática em contextos de hipovolemia',
    'Acúmulo de metformina por redução da excreção renal → acidose lática (rara mas grave)',
    'Monitorar função renal (creatinina/TFG) ao iniciar ou titular furosemida. Suspender metformina se TFG <30 mL/min',
    'Necessita monitorização renal — suspender metformina se TFG <30',
    EvidenceLevel.probable,
    {RiskType.nephrotoxicity, RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx]),

  // Espironolactona + IECAs
  ('espironolactona', 'enalapril', InteractionSeverity.major,
    'Ambos retêm potássio por mecanismos distintos (poupador de K+ + bloqueio SRAA)',
    'Hipercalemia grave (K+ >6 mEq/L) — risco de arritmia ventricular fatal e parada cardíaca',
    'Monitorar K+ e creatinina em 1–2 semanas ao iniciar. Dosar K+ mensalmente. Restringir K+ dietético. Suspender se K+ >5,5 mEq/L',
    'ALTO RISCO DE HIPERCALEMIA — Monitorar K+ e creatinina semanalmente',
    EvidenceLevel.established,
    {RiskType.hyperkalemia, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx, _kRefUT]),

  // Verapamil / Diltiazem + Betabloqueadores
  ('verapamil', 'metoprolol', InteractionSeverity.major,
    'Ambos deprimem o nó SA e AV por mecanismos distintos — bloqueio aditivo da condução cardíaca',
    'Bradicardia grave, bloqueio AV de alto grau, assistolia — especialmente em disfunção de VE',
    'Evitar combinação IV. Uso oral requer ECG basal e monitoramento. Não administrar IV ambos simultaneamente',
    'ALTO RISCO DE ASSISTOLIA — Nunca usar IV simultaneamente',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),
  ('diltiazem', 'metoprolol', InteractionSeverity.major,
    'Depressão aditiva do nó SA/AV por bloqueadores de cálcio não-diidropiridínicos + betabloqueadores',
    'Bradicardia, bloqueio AV, hipotensão, insuficiência cardíaca descompensada',
    'Monitorar ECG e FC. Evitar em FEVE reduzida. Não titular doses sem ECG de controle',
    'ALTO RISCO CARDIOVASCULAR — Monitorar ECG e FC continuamente',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),

  // Dexmedetomidina
  ('dexmedetomidina', 'metoprolol', InteractionSeverity.moderate,
    'Agonismo alfa-2 central da dexmedetomidina potencia bradicardia e hipotensão dos betabloqueadores',
    'Bradicardia sinusal, hipotensão refratária — especialmente em hipovolemia',
    'Monitorar FC e PA continuamente em UTI. Reduzir dose de betabloqueador se FC <50 bpm ou PA sistólica <90 mmHg',
    'Necessita monitorização hemodinâmica contínua em UTI',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    [_kRefMdx, _kRefUT]),
  ('dexmedetomidina', 'propofol', InteractionSeverity.moderate,
    'Sedação aditiva do SNC — ambos são agentes de sedação IV',
    'Sedação excessiva, apneia, hipotensão, bradicardia',
    'Reduzir dose de propofol ao combinar. Monitorar nível de sedação (escala RASS), FR e hemodinâmica',
    'Necessita monitorização de RASS, FR e hemodinâmica',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cardiovascular, RiskType.cns},
    [_kRefMdx, _kRefUT]),

  // Propofol
  ('propofol', 'opioide', InteractionSeverity.moderate,
    'Sinergismo sedativo e depressor respiratório — especialmente com fentanila e remifentanila',
    'Apneia, hipotensão, bradicardia — risco aumentado em bolus',
    'Titular cuidadosamente. Ter suporte de via aérea disponível. Monitorar ETCO2 se possível',
    'Necessita monitorização — risco de apneia em bolus',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cardiovascular},
    [_kRefGG, _kRefMdx]),

  // Fentanila + Benzodiazepínico
  ('fentanila', 'benzodiazepínico', InteractionSeverity.major,
    'Depressão aditiva do SNC — combinação clássica de indução anestésica com risco aumentado',
    'Depressão respiratória grave, apneia, hipotensão',
    'FDA Black Box Warning para essa combinação em contexto ambulatorial. Em UTI: monitoramento contínuo de SpO2, FR e PA',
    'ALTO RISCO DE DEPRESSÃO RESPIRATÓRIA — FDA Black Box Warning',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns},
    [_kRefFDA, _kRefGG]),

  // Esmolol
  ('esmolol', 'verapamil', InteractionSeverity.major,
    'Bloqueio aditivo do nó AV por betabloqueador IV + bloqueador de cálcio — risco máximo em via IV',
    'Assistolia, bloqueio AV completo, colapso hemodinâmico',
    'Contraindicado usar IV simultaneamente. Se necessário, espaçar administrações com monitoramento rigoroso de ECG',
    'ALTO RISCO DE ASSISTOLIA — Nunca administrar IV simultaneamente',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),

  // Milrinona
  ('milrinona', 'furosemida', InteractionSeverity.moderate,
    'Furosemida causa hipovolemia e hipocalemia, amplificando efeitos vasodilatadores da milrinona',
    'Hipotensão grave, arritmias por hipocalemia (potencializa milrinona)',
    'Repor K+ antes de iniciar. Monitorar PA, débito urinário e eletrólitos a cada 4–6h',
    'Necessita monitorização de PA e K+ a cada 4–6h',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.hypokalemia},
    [_kRefMdx, _kRefUT]),

  // Levosimendan
  ('levosimendan', 'nitrato', InteractionSeverity.moderate,
    'Ambos são vasodilatadores — levosimendan abre canais K-ATP vasculares; nitratos liberam NO',
    'Hipotensão grave, especialmente nas primeiras horas de infusão do levosimendan',
    'Monitorar PA invasiva. Reduzir ou suspender nitrato durante infusão de levosimendan. Repor volume se necessário',
    'Necessita monitorização de PA invasiva durante infusão',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    [_kRefMdx, _kRefUT]),

  // Naloxona
  ('naloxona', 'opioide', InteractionSeverity.major,
    'Antagonismo competitivo nos receptores mu-opioide — reverte analgesia e sedação',
    'Crise de abstinência aguda em dependentes, dor intensa, agitação, hipertensão, edema pulmonar (raro)',
    'Titular em baixas doses IV (0,04–0,1 mg) para reverter depressão respiratória sem precipitar abstinência. Reavaliar a cada 2–3 min',
    'Titular naloxona em baixas doses — risco de abstinência aguda',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.cns},
    [_kRefGG, _kRefFDA]),

  // Labetalol
  ('labetalol', 'verapamil', InteractionSeverity.major,
    'Bloqueio combinado alfa+beta (labetalol) + bloqueio de canal de cálcio — depressão cardíaca aditiva',
    'Bradicardia, hipotensão grave, insuficiência cardíaca aguda',
    'Evitar combinação. Monitorar ECG, FC e PA. Não usar em IC descompensada',
    'ALTO RISCO CARDIOVASCULAR — Evitar em IC descompensada',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),

  // Aminoglicosídeo + Vancomicina (Lote 3 duplicate — mantido por compatibilidade)
  // (já existe entrada idêntica acima; esta é aceita por _seen deduplication)

  // Fluconazol — CYP2C9/3A4
  ('fluconazol', 'sinvastatina', InteractionSeverity.major,
    'Inibição do CYP3A4 pelo fluconazol aumenta AUC da sinvastatina em até 14 vezes',
    'Miopatia grave, rabdomiólise com insuficiência renal aguda',
    'Suspender sinvastatina durante o curso de fluconazol. Retomar após 48–72h. Se estatina necessária, usar pravastatina',
    'RISCO DE RABDOMIÓLISE — Suspender sinvastatina durante fluconazol',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.nephrotoxicity, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefFDA]),
  ('fluconazol', 'atorvastatina', InteractionSeverity.major,
    'Inibição do CYP3A4 eleva concentrações de atorvastatina significativamente',
    'Miopatia, rabdomiólise, lesão renal aguda',
    'Suspender atorvastatina durante fluconazol. Alternativa: pravastatina ou rosuvastatina em dose reduzida',
    'RISCO DE RABDOMIÓLISE — Suspender atorvastatina durante fluconazol',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefMdx, _kRefFDA]),
  ('fluconazol', 'quetiapina', InteractionSeverity.major,
    'Inibição de CYP3A4 aumenta exposição à quetiapina com prolongamento do QTc',
    'Prolongamento do intervalo QT, torsades de pointes, fibrilação ventricular',
    'Evitar. Se inevitável, reduzir dose de quetiapina em 50% e monitorar ECG seriado',
    'ALTO RISCO DE TORSADE DE POINTES — Reduzir quetiapina 50%',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.plasmaLevel},
    [_kRefMdx, _kRefLex]),
  ('fluconazol', 'fenitoína', InteractionSeverity.major,
    'Fluconazol inibe CYP2C9 e CYP2C19 — principais metabolizadores da fenitoína',
    'Toxicidade por fenitoína: nistagmo, ataxia, diplopia, convulsões paradoxais',
    'Monitorar nível sérico de fenitoína (nível-alvo: 10–20 mcg/mL). Reduzir dose de fenitoína antecipadamente',
    'ALTO RISCO DE TOXICIDADE POR FENITOÍNA — Monitorar nível sérico',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx]),

  // Fenitoína (indutora)
  ('fenitoína', 'warfarina', InteractionSeverity.major,
    'Fenitoína induz CYP2C9 → maior metabolismo da warfarina; também pode deslocar warfarina de proteínas (efeito bifásico)',
    'Inicialmente: elevação do INR → risco hemorrágico. Cronicamente: redução do INR → risco tromboembólico',
    'Monitorar INR intensivamente ao iniciar/ajustar/suspender fenitoína. Ajustar dose de warfarina conforme curva',
    'ALTO RISCO — INR instável; monitorar intensivamente ao ajustar fenitoína',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.thrombosis, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),
  ('fenitoína', 'lamotrigina', InteractionSeverity.major,
    'Fenitoína induz UGT e CYP2C19, acelerando glucuronidação da lamotrigina',
    'Redução de 40–50% nos níveis de lamotrigina → falha antiepiléptica',
    'Dobrar a dose-alvo de lamotrigina quando associada à fenitoína. Monitorar nível sérico se disponível',
    'ALTO RISCO DE FALHA ANTIEPILÉPTICA — Dobrar dose de lamotrigina',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),

  // Topiramato
  ('topiramato', 'acido valproico', InteractionSeverity.moderate,
    'Interação farmacodinâmica e metabólica: topiramato pode reduzir níveis de valproato e inibir beta-oxidação mitocondrial',
    'Encefalopatia hiperamonêmica (sem elevação de aminotransferases), hipotermia',
    'Monitorar amônia sérica em pacientes sintomáticos (confusão, letargia). Suspender topiramato se encefalopatia',
    'Necessita monitorização de amônia sérica — risco de encefalopatia',
    EvidenceLevel.probable,
    {RiskType.cns, RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx]),
  ('topiramato', 'anticoncepcional', InteractionSeverity.moderate,
    'Topiramato induz CYP3A4 em doses ≥200 mg/dia, reduzindo etinilestradiol e progestagênio',
    'Falha contraceptiva — gravidez não planejada',
    'Usar método contraceptivo não hormonal (DIU de cobre, preservativo). Orientar paciente explicitamente sobre o risco',
    'Necessita método contraceptivo não hormonal — risco de falha',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),

  // Olanzapina
  ('olanzapina', 'benzodiazepínico', InteractionSeverity.major,
    'Depressão aditiva do SNC — risco especialmente elevado com formulação IM de olanzapina',
    'Sedação grave, depressão respiratória, hipotensão — casos de óbito descritos',
    'Contraindicado usar olanzapina IM com benzodiazepínico parenteral (intervalo mínimo 1h). Monitorar SpO2 e PA',
    'ALTO RISCO DE ÓBITO — Contraindicado olanzapina IM + BDZ parenteral',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cardiovascular, RiskType.cns},
    [_kRefFDA, _kRefMdx]),
  ('olanzapina', 'metoprolol', InteractionSeverity.moderate,
    'Olanzapina inibe CYP2D6, aumentando exposição ao metoprolol',
    'Bradicardia, hipotensão ortostática, broncoespasmo em asmáticos',
    'Monitorar FC e PA. Reduzir dose de metoprolol se FC <55 bpm ou sintomático',
    'Necessita monitorização de FC e PA — bradicardia por inibição CYP2D6',
    EvidenceLevel.probable,
    {RiskType.cardiovascular, RiskType.plasmaLevel},
    [_kRefMdx, _kRefLex]),

  // Mirtazapina
  ('mirtazapina', 'tramadol', InteractionSeverity.major,
    'Mirtazapina tem ação serotoninérgica e noradrenérgica; tramadol inibe recaptação de serotonina',
    'Síndrome serotoninérgica — hipertermia, agitação, clonus, diarreia',
    'Evitar combinação. Se analgesia opioide necessária, preferir morfina ou fentanila pura',
    'ALTO RISCO DE SÍNDROME SEROTONINÉRGICA — Preferir morfina',
    EvidenceLevel.probable,
    {RiskType.serotonin},
    [_kRefMdx, _kRefUT]),
  ('mirtazapina', 'imao', InteractionSeverity.contraindicated,
    'Mirtazapina potencializa transmissão serotoninérgica e noradrenérgica; IMAOs bloqueiam catabolismo de monoaminas',
    'Síndrome serotoninérgica grave potencialmente fatal',
    'ABSOLUTAMENTE CONTRAINDICADO. Intervalo mínimo de 14 dias entre IMAO e mirtazapina',
    'NÃO UTILIZAR — Síndrome serotoninérgica fatal; washout 14 dias',
    EvidenceLevel.established,
    {RiskType.serotonin},
    [_kRefFDA, _kRefGG]),

  // Clonazepam + Valproato
  ('benzodiazepínico', 'acido valproico', InteractionSeverity.moderate,
    'Valproato pode aumentar concentrações de clonazepam por inibição metabólica; risco de ausência paradoxal',
    'Sedação excessiva, ou paradoxalmente: piora do estado de ausência epiléptica',
    'Monitorar resposta clínica. Avaliar padrão de ausências em eletroencefalograma se piora',
    'Necessita monitorização clínica — piora paradoxal de ausências possível',
    EvidenceLevel.probable,
    {RiskType.cns, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),

  // Acetazolamida
  ('acetazolamida', 'topiramato', InteractionSeverity.moderate,
    'Ambos inibem anidrase carbônica — efeito aditivo na acidose metabólica e nefrolitíase',
    'Acidose metabólica hiperclorêmica grave, nefrolitíase, encefalopatia (raro)',
    'Evitar combinação. Monitorar gasometria e pH urinário. Garantir hidratação >2L/dia',
    'Necessita monitorização de gasometria — acidose metabólica aditiva',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.increasedToxicity},
    [_kRefMdx, _kRefGG]),
  ('acetazolamida', 'aspirina', InteractionSeverity.major,
    'AAS em doses analgésicas compete com acetazolamida por secreção tubular renal, elevando nível da acetazolamida; também pode induzir acidose',
    'Toxicidade por acetazolamida: letargia, anorexia, parestesias, acidose grave',
    'Evitar AAS em doses altas com acetazolamida. Se analgesia necessária, usar paracetamol',
    'ALTO RISCO DE TOXICIDADE — Usar paracetamol em vez de AAS',
    EvidenceLevel.probable,
    {RiskType.increasedToxicity, RiskType.nephrotoxicity},
    [_kRefMdx, _kRefGG]),

  // Clortalidona / Hidroclorotiazida
  ('hidroclorotiazida', 'carbonato de litio', InteractionSeverity.major,
    'Tiazídicos causam depleção de sódio → aumento compensatório da reabsorção de lítio no túbulo proximal',
    'Toxicidade por lítio: tremor grosseiro, náuseas, ataxia, confusão, convulsões, insuficiência renal',
    'Monitorar lítio sérico semanalmente ao iniciar/ajustar diurético. Reduzir dose de lítio em ~25%. Manter ingesta hídrica e salina adequadas',
    'ALTO RISCO DE TOXICIDADE POR LÍTIO — Monitorar litemia semanalmente',
    EvidenceLevel.established,
    {RiskType.increasedToxicity, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),
  ('hidroclorotiazida', 'digoxina', InteractionSeverity.major,
    'Hipocalemia induzida por tiazídico potencializa toxicidade da digoxina (competição por bomba Na/K-ATPase)',
    'Toxicidade digitálica: bradiarritmia, BAV, bigeminismo, náuseas, distúrbios visuais',
    'Manter K+ sérico >4 mEq/L. Dosar K+ e digoxina regularmente. Suplementar KCl se necessário',
    'ALTO RISCO DE TOXICIDADE DIGITÁLICA — Manter K+ >4 mEq/L',
    EvidenceLevel.established,
    {RiskType.hypokalemia, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),

  // Verapamil + Digoxina
  ('verapamil', 'digoxina', InteractionSeverity.major,
    'Verapamil inibe P-gp e reduz clearance renal de digoxina, aumentando nível sérico em 50–75%',
    'Toxicidade digitálica: BAV, bradicardia grave, náuseas, visão turva',
    'Reduzir dose de digoxina em 30–50% ao iniciar verapamil. Monitorar nível sérico de digoxina. ECG seriado',
    'ALTO RISCO DE TOXICIDADE DIGITÁLICA — Reduzir digoxina 30–50%',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.cardiovascular},
    [_kRefGG, _kRefMdx]),

  // Glibenclamida
  ('glibenclamida', 'fluconazol', InteractionSeverity.major,
    'Fluconazol inibe CYP2C9, principal enzima de metabolismo da glibenclamida',
    'Hipoglicemia grave prolongada — risco em idosos e insuficiência renal',
    'Monitorar glicemia capilar a cada 4h durante uso concomitante. Reduzir dose de glibenclamida. Considerar switch para insulina',
    'ALTO RISCO DE HIPOGLICEMIA GRAVE — Monitorar glicemia a cada 4h',
    EvidenceLevel.established,
    {RiskType.hypoglycemia, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),
  ('glibenclamida', 'ciprofloxacino', InteractionSeverity.moderate,
    'Ciprofloxacino inibe CYP1A2 e pode aumentar secreção de insulina por bloqueio de canais de K-ATP pancreáticos',
    'Hipoglicemia — especialmente em idosos com insuficiência renal',
    'Monitorar glicemia. Orientar paciente sobre sintomas de hipoglicemia. Avaliar substituição do antibiótico',
    'Necessita monitorização de glicemia — hipoglicemia em idosos',
    EvidenceLevel.probable,
    {RiskType.hypoglycemia},
    [_kRefMdx, _kRefUT]),

  // Isossorbida + Sildenafila
  ('nitrato', 'sildenafila', InteractionSeverity.contraindicated,
    'Sinergismo no aumento de GMPc (NO + PDE5i) → vasodilatação sistêmica potencializada e incontrolável',
    'Hipotensão grave potencialmente fatal, síncope, isquemia miocárdica por "roubo"',
    'ABSOLUTAMENTE CONTRAINDICADO. Informar explicitamente todos os pacientes com angina que usam nitratos sobre essa contraindicação',
    'NÃO UTILIZAR — Hipotensão fatal absolutamente contraindicada',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    [_kRefFDA, _kRefGG, _kRefMdx]),

  // Rocurônio
  ('rocurônio', 'aminoglicosideo', InteractionSeverity.moderate,
    'Aminoglicosídeos inibem a liberação de acetilcolina na junção neuromuscular — potencialização do bloqueio neuromuscular',
    'Prolongamento do bloqueio neuromuscular, dificuldade de reversão com neostigmina',
    'Monitorar bloqueio neuromuscular com TOF (train-of-four). Ter sugamadex disponível para reversão em casos de bloqueio prolongado',
    'Necessita monitorização com TOF — ter sugamadex disponível',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx]),

  // Tigeciclina
  ('tigeciclina', 'warfarina', InteractionSeverity.moderate,
    'Tigeciclina pode aumentar INR por mecanismo não completamente elucidado (possivelmente inibição da flora intestinal produtora de vitamina K)',
    'Elevação do INR com risco hemorrágico',
    'Monitorar INR a cada 2–3 dias durante uso de tigeciclina. Ajustar dose de warfarina conforme necessário',
    'Necessita monitorização de INR a cada 2–3 dias',
    EvidenceLevel.possible,
    {RiskType.hemorrhagic},
    [_kRefMdx, _kRefFDA]),

  // Ceftolozana + Furosemida
  ('ceftolozana', 'furosemida', InteractionSeverity.monitorOnly,
    'Furosemida pode reduzir excreção renal de betalactâmicos por competição tubular',
    'Aumento leve dos níveis plasmáticos de ceftolozana — sem relevância clínica significativa na maioria dos casos',
    'Sem ajuste necessário em função renal normal. Monitorar TFG em pacientes com insuficiência renal prévia',
    'Só monitorizar — ajuste não necessário em função renal normal',
    EvidenceLevel.theoretical,
    {RiskType.plasmaLevel},
    [_kRefMdx]),

  // Clonixinato de Lisina
  ('clonixinato', 'warfarina', InteractionSeverity.moderate,
    'AINE com inibição plaquetária e possível deslocamento proteico da warfarina',
    'Aumento do INR e risco de sangramento',
    'Evitar. Preferir paracetamol como analgésico alternativo. Monitorar INR se uso inevitável',
    'Necessita monitorização de INR — usar paracetamol',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefMdx]),
  ('clonixinato', 'aine', InteractionSeverity.moderate,
    'Risco aditivo de toxicidade GI e renal por uso de dois AINEs simultaneamente',
    'Úlcera gástrica, sangramento GI, lesão renal aguda',
    'Não associar dois AINEs. Escolher um único AINE na menor dose eficaz pelo menor tempo',
    'Necessita monitorização — evitar uso de dois AINEs simultaneamente',
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
    'Dupla inibição hemostática: apixabana bloqueia fator Xa; aspirina inibe COX-1 plaquetária',
    'Risco hemorrágico aumentado 2-3x — hemorragia GI, intracraniana, retroperitoneal',
    'Evitar combinação crônica salvo indicação específica (ex: FA + SCA recente). Se necessário, IBP obrigatório e dose mínima de AAS (100 mg)',
    'RISCO HEMORRÁGICO GRAVE — Evitar combinação crônica sem indicação formal',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefUT, _kRefFDA]),

  ('apixabana', 'aine', InteractionSeverity.major,
    'AINE inibe COX-1 plaquetária e prostaglandinas citoprotetoras gástricas; apixabana bloqueia fator Xa',
    'Sangramento GI significativo; risco de IRA por redução de prostaglandinas renais',
    'Evitar combinação. Se inevitável: IBP, menor dose possível de AINE, monitorar sinais de sangramento',
    'RISCO HEMORRÁGICO + RENAL — Evitar AINEs durante anticoagulação com apixabana',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx, _kRefUT]),

  ('rivaroxabana', 'aspirina', InteractionSeverity.major,
    'Dupla inibição hemostática: rivaroxabana bloqueia fator Xa; aspirina inibe COX-1 plaquetária',
    'Risco hemorrágico aumentado — hemorragia GI, intracraniana',
    'Evitar combinação crônica salvo indicação específica (SCA + FA). Se necessário, IBP obrigatório',
    'RISCO HEMORRÁGICO GRAVE — Combinação aumenta sangramento em 2-3x',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefUT, _kRefFDA]),

  ('rivaroxabana', 'aine', InteractionSeverity.major,
    'AINE inibe COX-1 plaquetária; rivaroxabana bloqueia fator Xa — efeito aditivo no sangramento GI',
    'Sangramento GI significativo; lesão renal aguda',
    'Evitar combinação. Se inevitável: IBP, menor dose de AINE, monitorar sinais de sangramento',
    'RISCO HEMORRÁGICO + RENAL — Evitar AINEs durante anticoagulação com rivaroxabana',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx, _kRefUT]),

  ('dabigatrana', 'aspirina', InteractionSeverity.major,
    'Dupla inibição hemostática: dabigatrana inibe trombina; aspirina inibe COX-1 plaquetária',
    'Risco hemorrágico aumentado — hemorragia GI, intracraniana',
    'Evitar combinação crônica. Se necessário (pós-SCA + FA), usar dose mínima de AAS + IBP',
    'RISCO HEMORRÁGICO GRAVE — Combinação aumenta sangramento significativamente',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefUT, _kRefFDA]),

  ('dabigatrana', 'aine', InteractionSeverity.major,
    'AINE inibe COX-1 plaquetária; dabigatrana inibe trombina — efeito aditivo no sangramento',
    'Sangramento GI significativo; possível lesão renal',
    'Evitar combinação. Se inevitável: menor dose de AINE por menor tempo, IBP, monitoração rigorosa',
    'RISCO HEMORRÁGICO — Evitar AINEs durante anticoagulação com dabigatrana',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx]),

  ('apixabana', 'clopidogrel', InteractionSeverity.major,
    'Dupla antitrombótica: apixabana anticoagulante + clopidogrel antiagregante — sem benefício aditivo na maioria das indicações',
    'Risco hemorrágico dobrado sem benefício adicional na maioria dos pacientes',
    'Evitar terapia tripla. Se FA + stent coronário, preferir dupla (AOD + um antiagregante) pelo menor tempo possível',
    'TRIPLA ANTITROMBÓTICA — Evitar. Risco hemorrágico dobrado; usar dupla terapia quando possível',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefUT, _kRefFDA]),

  ('rivaroxabana', 'clopidogrel', InteractionSeverity.major,
    'Dupla antitrombótica: rivaroxabana anticoagulante + clopidogrel antiagregante',
    'Risco hemorrágico dobrado sem benefício adicional na maioria dos pacientes',
    'Evitar terapia tripla. Se indicado, usar pelo menor tempo possível com IBP obrigatório',
    'TRIPLA ANTITROMBÓTICA — Evitar. Risco hemorrágico muito aumentado',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefUT, _kRefFDA]),

  ('apixabana', 'fluconazol', InteractionSeverity.major,
    'Fluconazol inibe CYP3A4 e P-gp, principais vias de metabolismo da apixabana',
    'Aumento significativo dos níveis plasmáticos de apixabana — risco hemorrágico grave',
    'Evitar combinação. Se inevitável, reduzir dose de apixabana e monitorar sinais de sangramento',
    'RISCO HEMORRÁGICO — Fluconazol eleva níveis de apixabana significativamente',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT, _kRefLex]),

  ('rivaroxabana', 'fluconazol', InteractionSeverity.major,
    'Fluconazol inibe CYP3A4 e P-gp, principais vias de metabolismo da rivaroxabana',
    'Aumento significativo dos níveis plasmáticos de rivaroxabana — risco hemorrágico grave',
    'Evitar combinação. Se inevitável, monitorar sinais de sangramento rigorosamente',
    'RISCO HEMORRÁGICO — Fluconazol eleva níveis de rivaroxabana significativamente',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT, _kRefLex]),

  ('apixabana', 'rifampicina', InteractionSeverity.major,
    'Rifampicina é potente indutor de CYP3A4 e P-gp — aumenta metabolismo e efluxo da apixabana',
    'Redução de 54% nos níveis plasmáticos de apixabana — risco de falha anticoagulante e trombose',
    'Evitar combinação. Considerar anticoagulante alternativo não dependente de CYP3A4/P-gp',
    'RISCO DE TROMBOSE — Rifampicina reduz níveis de apixabana em ~54%',
    EvidenceLevel.established,
    {RiskType.thrombosis, RiskType.reducedEfficacy},
    [_kRefFDA, _kRefUT]),

  ('rivaroxabana', 'rifampicina', InteractionSeverity.major,
    'Rifampicina induz CYP3A4 e P-gp — aumenta metabolismo e efluxo da rivaroxabana',
    'Redução de ~50% nos níveis plasmáticos de rivaroxabana — falha anticoagulante',
    'Evitar combinação. Considerar anticoagulante alternativo durante uso de rifampicina',
    'RISCO DE TROMBOSE — Rifampicina reduz níveis de rivaroxabana em ~50%',
    EvidenceLevel.established,
    {RiskType.thrombosis, RiskType.reducedEfficacy},
    [_kRefFDA, _kRefUT]),

  ('dabigatrana', 'rifampicina', InteractionSeverity.major,
    'Rifampicina induz P-gp (principal transportador de efluxo da dabigatrana)',
    'Redução de ~66% nos níveis plasmáticos de dabigatrana — risco de trombose',
    'Evitar combinação. Considerar anticoagulante alternativo durante uso de rifampicina',
    'RISCO DE TROMBOSE — Rifampicina reduz droga dabigatrana em ~66%',
    EvidenceLevel.established,
    {RiskType.thrombosis, RiskType.reducedEfficacy},
    [_kRefFDA, _kRefUT]),

  // ── 2. WARFARINA — pares faltantes ────────────────────────────────────────
  ('warfarina', 'clopidogrel', InteractionSeverity.major,
    'Mecanismos complementares: warfarina inibe coagulação; clopidogrel inibe agregação plaquetária via P2Y12',
    'Sangramento GI grave, hemorragia intracraniana — risco 3x maior que monoterapia',
    'Evitar terapia tripla (warfarina + AAS + clopidogrel). Se FA + stent: preferir AOD + antiagregante único',
    'TRIPLA ANTITROMBÓTICA — Risco hemorrágico muito elevado; reavaliar indicação',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefUT]),

  ('warfarina', 'carbamazepina', InteractionSeverity.major,
    'Carbamazepina é potente indutor do CYP2C9 e CYP3A4 — aumenta metabolismo da warfarina',
    'Redução significativa do INR — perda do efeito anticoagulante e risco de trombose',
    'Monitorar INR rigorosamente ao iniciar ou suspender carbamazepina. Ajustar dose conforme INR',
    'RISCO DE TROMBOSE — Carbamazepina reduz efeito anticoagulante da warfarina',
    EvidenceLevel.established,
    {RiskType.thrombosis, RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx, _kRefUT]),

  ('warfarina', 'tramadol', InteractionSeverity.major,
    'Tramadol inibe CYP2C9 (metabolismo da warfarina S) e pode ter efeito anticoagulante aditivo',
    'Elevação do INR — risco de sangramento grave',
    'Monitorar INR próximo ao iniciar ou suspender tramadol. Ajustar dose de warfarina conforme necessário',
    'RISCO HEMORRÁGICO — Tramadol eleva INR; monitorar warfarina rigorosamente',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),

  ('warfarina', 'omeprazol', InteractionSeverity.moderate,
    'Omeprazol inibe CYP2C19 — pode elevar discretamente os níveis de warfarina S',
    'Elevação moderada do INR em alguns pacientes (polimorfismo CYP2C19)',
    'Monitorar INR ao iniciar ou trocar IBP. O efeito é clinicamente relevante apenas em metabolizadores lentos do CYP2C19',
    'Monitorar INR — omeprazol pode elevar discretamente o efeito anticoagulante',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),

  ('warfarina', 'sulfametoxazol', InteractionSeverity.major,
    'SMX-TMP inibe CYP2C9 (metabolizador da warfarina S) e desloca warfarina de proteínas plasmáticas',
    'Elevação abrupta do INR em 2-3x — risco de sangramento grave',
    'Reduzir dose de warfarina em 25-50% ao iniciar SMX-TMP. Monitorar INR em 3-5 dias. Preferir antibiótico alternativo quando possível',
    'RISCO HEMORRÁGICO GRAVE — SMX-TMP é um dos maiores potenciadores do efeito da warfarina',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),

  // ── 3. CLOPIDOGREL — pares faltantes ──────────────────────────────────────
  ('clopidogrel', 'aspirina', InteractionSeverity.moderate,
    'Dupla antiagregação plaquetária: clopidogrel via P2Y12; aspirina via COX-1 — complementares no contexto de síndrome coronária aguda e stent',
    'Risco hemorrágico aumentado vs. monoterapia (sangramento GI, equimoses); necessário em indicações específicas (SCA, stent coronário)',
    'Indicado em SCA e pós-stent coronário por tempo definido (12 meses/6 meses conforme stent). IBP obrigatório. Evitar fora dessas indicações',
    'DUPLA ANTIAGREGAÇÃO — Necessária em SCA/stent, mas monitorar sangramento. IBP obrigatório',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefUT, _kRefFDA]),

  // ── 4. IECA/ARA-II — pares faltantes ──────────────────────────────────────
  ('enalapril', 'cloreto de potassio', InteractionSeverity.major,
    'IECA reduz excreção renal de potássio por inibição da aldosterona; suplementação de KCl aditiva',
    'Hipercalemia grave — risco de arritmias ventriculares fatais, parada cardíaca',
    'Monitorar eletrólitos rigorosamente. Reduzir ou suspender suplementação de KCl. Evitar em insuficiência renal',
    'RISCO DE HIPERCALEMIA GRAVE — IECA + KCl pode causar arritmia fatal',
    EvidenceLevel.established,
    {RiskType.hyperkalemia, RiskType.arrhythmia},
    [_kRefGG, _kRefUT]),

  ('losartana', 'cloreto de potassio', InteractionSeverity.major,
    'ARA-II reduz excreção renal de potássio por bloqueio do receptor AT1; suplementação de KCl aditiva',
    'Hipercalemia grave — risco de arritmias ventriculares fatais',
    'Monitorar eletrólitos rigorosamente. Reduzir ou suspender suplementação de KCl. Evitar em insuficiência renal',
    'RISCO DE HIPERCALEMIA GRAVE — ARA-II + KCl pode causar arritmia fatal',
    EvidenceLevel.established,
    {RiskType.hyperkalemia, RiskType.arrhythmia},
    [_kRefGG, _kRefUT]),

  ('enalapril', 'trimetoprima', InteractionSeverity.major,
    'Trimetoprima bloqueia secreção tubular de potássio de forma similar à amilorida; IECA já reduz excreção de K+',
    'Hipercalemia grave — especialmente em idosos, diabéticos e insuficiência renal',
    'Monitorar potássio sérico 3-5 dias após início de SMX-TMP em pacientes em uso de IECA/ARA-II',
    'RISCO DE HIPERCALEMIA — SMX-TMP + IECA combinação frequentemente subestimada',
    EvidenceLevel.established,
    {RiskType.hyperkalemia},
    [_kRefUT, _kRefMdx]),

  ('losartana', 'aine', InteractionSeverity.moderate,
    'AINEs reduzem síntese de prostaglandinas vasodilatadoras renais e antagonizam efeito do ARA-II',
    'Redução do efeito anti-hipertensivo do ARA-II; risco de insuficiência renal aguda',
    'Evitar uso crônico concomitante. Se necessário, monitorar PA e função renal. Preferir paracetamol como analgésico',
    'Necessita monitorização — AINEs reduzem efeito anti-hipertensivo e aumentam risco renal',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.cardiovascular},
    [_kRefGG, _kRefUT]),

  ('enalapril', 'hidroclorotiazida', InteractionSeverity.monitorOnly,
    'Combinação sinérgica anti-hipertensiva — IECA potencializa efeito diurético e vice-versa',
    'Hipotensão de primeira dose, especialmente em pacientes com depleção volêmica; hiponatremia',
    'Combinação frequentemente intencional e benéfica. Iniciar com doses baixas e titular. Monitorar PA na 1ª semana e eletrólitos',
    'Combinação sinérgica — monitorar PA e eletrólitos especialmente no início',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.hypokalemia},
    [_kRefGG, _kRefUT]),

  // ── 5. ESTATINAS — pares faltantes ────────────────────────────────────────
  ('rosuvastatina', 'fenofibrato', InteractionSeverity.moderate,
    'Fenofibrato inibe CYP2C9 e pode elevar níveis de rosuvastatina; risco farmacodinâmico aditivo de miopatia',
    'Miopatia, mialgia, rabdomiólise — risco menor que com genfibrozil',
    'Monitorar sintomas musculares. Preferir fenofibrato em vez de gemfibrozil quando necessário combinar com estatina. Usar menor dose de estatina',
    'Monitorar sintomas musculares — risco de miopatia com combinação estatina + fibrato',
    EvidenceLevel.probable,
    {RiskType.myopathy},
    [_kRefGG, _kRefMdx, _kRefFDA]),

  ('sinvastatina', 'fenofibrato', InteractionSeverity.moderate,
    'Fenofibrato inibe glucuronidação de sinvastatina e tem efeito farmacodinâmico aditivo de miopatia',
    'Miopatia, mialgia; menor risco de rabdomiólise vs. gemfibrozil',
    'Monitorar sintomas musculares regularmente. Preferir fenofibrato vs. gemfibrozil. Evitar altas doses de sinvastatina',
    'Monitorar sintomas musculares — preferir fenofibrato a gemfibrozil se necessário',
    EvidenceLevel.probable,
    {RiskType.myopathy},
    [_kRefGG, _kRefMdx, _kRefFDA]),

  ('rosuvastatina', 'claritromicina', InteractionSeverity.moderate,
    'Claritromicina inibe CYP3A4, mas rosuvastatina não é metabolizada pelo CYP3A4; inibe OATP1B1 — efeito moderado',
    'Aumento moderado dos níveis de rosuvastatina — risco de miopatia',
    'Monitorar sintomas musculares. Reduzir dose de rosuvastatina ou suspender temporariamente durante curso de claritromicina',
    'Monitorar sintomas musculares durante uso de claritromicina com rosuvastatina',
    EvidenceLevel.probable,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),

  ('atorvastatina', 'fenofibrato', InteractionSeverity.moderate,
    'Fenofibrato inibe CYP2C8 e tem efeito farmacodinâmico aditivo; menos interação que com gemfibrozil',
    'Risco de miopatia; menor que com gemfibrozil',
    'Combinação aceitável com monitoramento. Usar menor dose eficaz de atorvastatina. Monitorar CPK e sintomas musculares',
    'Monitorar sintomas musculares — combinação geralmente tolerada com vigilância',
    EvidenceLevel.probable,
    {RiskType.myopathy},
    [_kRefMdx, _kRefFDA]),

  // ── 6. DIGOXINA — pares faltantes ─────────────────────────────────────────
  ('digoxina', 'claritromicina', InteractionSeverity.major,
    'Claritromicina inibe P-gp intestinal e renal, principal via de eliminação da digoxina',
    'Aumento de 70-100% nos níveis séricos de digoxina — toxicidade digitálica (náusea, bradiarritmias, BAV)',
    'Reduzir dose de digoxina em 50% ao iniciar claritromicina. Monitorar nível sérico de digoxina e ECG. Preferir azitromicina se possível',
    'TOXICIDADE DIGITÁLICA — Claritromicina dobra níveis de digoxina; ajustar dose obrigatoriamente',
    EvidenceLevel.established,
    {RiskType.arrhythmia, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),

  ('digoxina', 'azitromicina', InteractionSeverity.moderate,
    'Azitromicina inibe P-gp intestinal, aumentando absorção de digoxina; menor efeito que claritromicina',
    'Aumento moderado dos níveis séricos de digoxina — risco de toxicidade digitálica',
    'Monitorar sintomas de toxicidade digitálica (náusea, bradicardia) durante uso de azitromicina. Considerar nível sérico',
    'Monitorar toxicidade digitálica — azitromicina pode elevar níveis de digoxina moderadamente',
    EvidenceLevel.probable,
    {RiskType.arrhythmia, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),

  ('digoxina', 'hidroclorotiazida', InteractionSeverity.major,
    'Tiazídicos causam hipocalemia e hipomagnesemia — desequilíbrios que aumentam toxicidade da digoxina mesmo com níveis séricos normais',
    'Toxicidade digitálica com arritmias — bradiarritmias, taquicardia ventricular, fibrilação ventricular',
    'Monitorar potássio e magnésio séricos regularmente. Repor potássio se K+ < 3,5 mEq/L. Monitorar nível sérico de digoxina',
    'TOXICIDADE DIGITÁLICA — Hipocalemia por tiazídico aumenta toxicidade da digoxina mesmo com nível sérico normal',
    EvidenceLevel.established,
    {RiskType.arrhythmia, RiskType.hypokalemia},
    [_kRefGG, _kRefMdx]),

  ('digoxina', 'amiodarona', InteractionSeverity.major,
    'Amiodarona inibe P-gp e reduz clearance renal da digoxina; efeito bradicardizante aditivo no nó sinusal e AV',
    'Aumento de 50-100% nos níveis séricos de digoxina + bradicardia sinusal e BAV',
    'Reduzir dose de digoxina em 50% ao iniciar amiodarona. Monitorar nível sérico de digoxina e ECG seriado',
    'TOXICIDADE DIGITÁLICA — Amiodarona dobra níveis de digoxina; reduzir dose 50% obrigatoriamente',
    EvidenceLevel.established,
    {RiskType.arrhythmia, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),

  // ── 7. PROLONGAMENTO DE QT — pares críticos faltantes ─────────────────────
  ('amiodarona', 'ciprofloxacino', InteractionSeverity.major,
    'Ambos prolongam o intervalo QT por bloqueio de canais de potássio (IKr) — efeito aditivo',
    'Torsades de Pointes, taquicardia ventricular polimórfica, fibrilação ventricular — risco de morte súbita',
    'Evitar combinação. Se necessário, monitorar ECG continuamente. Preferir antibiótico sem efeito QT (amoxicilina, beta-lactâmico)',
    'RISCO DE TORSADES DE POINTES — Combinação de dois potentes prolongadores de QT',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefMdx, _kRefUT, _kRefFDA]),

  ('amiodarona', 'quetiapina', InteractionSeverity.major,
    'Ambos prolongam o intervalo QT — amiodarona por bloqueio de IKr; quetiapina por bloqueio de canais de Na+/K+',
    'Torsades de Pointes, taquicardia ventricular, morte súbita cardíaca',
    'Evitar combinação. Se necessário, moniorar ECG seriado e eletrólitos. Corrija hipocalemia/hipomagnesemia',
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
    'Evitar combinação. Se necessário, monitorar ECG e corrigir eletrólitos. Preferir antibiótico sem efeito QT',
    'RISCO DE TORSADES DE POINTES — Duplo prolongamento de QT',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefMdx, _kRefUT]),

  ('quetiapina', 'ciprofloxacino', InteractionSeverity.major,
    'Ambos prolongam o intervalo QT — efeito aditivo',
    'Torsades de Pointes, taquicardia ventricular',
    'Evitar combinação. Monitorar ECG se inevitável. Corrigir hipocalemia e hipomagnesemia',
    'RISCO DE TORSADES DE POINTES — Duplo prolongamento de QT',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefMdx, _kRefUT]),

  ('quetiapina', 'azitromicina', InteractionSeverity.major,
    'Ambos prolongam o intervalo QT por bloqueio de IKr — efeito aditivo',
    'Torsades de Pointes, taquicardia ventricular',
    'Evitar combinação. Se necessário, monitorar ECG. Preferir amoxicilina ou doxiciclina',
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
    'Elevação dos níveis de metadona + prolongamento de QT — Torsades de Pointes, depressão respiratória',
    'Evitar combinação. Monitorar ECG e sinais de toxicidade por metadona se inevitável',
    'RISCO DE TORSADES + TOXICIDADE — Ciprofloxacino eleva metadona e ambos prolongam QT',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),

  // ── 8. ANTIBIÓTICOS — pares faltantes ─────────────────────────────────────
  ('sulfametoxazol', 'metformina', InteractionSeverity.moderate,
    'Trimetoprima inibe secreção tubular da creatinina — eleva creatinina sérica sem lesão renal real; pode mascarar disfunção renal e levar à manutenção de metformina em dose excessiva',
    'Elevação falsa de creatinina pode induzir descontinuação inadequada de metformina ou, ao contrário, mascarar IRA real com acúmulo de metformina e acidose lática',
    'Monitorar função renal real (cistatina C ou clearance real) durante uso de SMX-TMP em pacientes com metformina',
    'Monitorar função renal — SMX-TMP eleva creatinina sérica independentemente de IRA real',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    [_kRefUT, _kRefMdx]),

  ('ciprofloxacino', 'metformina', InteractionSeverity.moderate,
    'Ciprofloxacino inibe o transportador OCT2 renal — reduz secreção tubular da metformina',
    'Aumento dos níveis plasmáticos de metformina — risco de acidose lática',
    'Monitorar função renal durante uso concomitante. Suspender metformina se creatinina elevar ou função renal deteriorar',
    'Monitorar — ciprofloxacino pode elevar níveis de metformina e risco de acidose lática',
    EvidenceLevel.probable,
    {RiskType.nephrotoxicity, RiskType.increasedToxicity},
    [_kRefMdx, _kRefUT]),

  ('vancomicina', 'furosemida', InteractionSeverity.major,
    'Furosemida é ototóxica e nefrotóxica; vancomicina também causa nefrotoxicidade — efeito sinérgico',
    'Nefrotoxicidade grave (IRA), ototoxicidade (perda auditiva irreversível)',
    'Monitorar função renal e nível sérico de vancomicina (AUC/MIC alvo). Evitar furosemida desnecessária. Manter hidratação adequada',
    'RISCO RENAL E AUDITIVO — Combinação aumenta nefrotoxicidade e ototoxicidade significativamente',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx, _kRefUT]),

  ('vancomicina', 'piperacilina_tazobactam', InteractionSeverity.major,
    'Piperacilina-tazobactam aumenta exposição à vancomicina e potencializa nefrotoxicidade por mecanismo não completamente elucidado',
    'Nefrotoxicidade aguda aumentada em 2-3x vs. vancomicina isolada (meta-análises)',
    'Monitorar função renal diariamente. Considerar alternativas (ceftarolina, daptomicina) quando possível. Ajustar dose de vancomicina por AUC/MIC',
    'NEFROTOXICIDADE AUMENTADA — Pip-tazo + vancomicina: risco renal muito elevado',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    [_kRefMdx, _kRefUT]),

  ('aminoglicosideo', 'cisplatina', InteractionSeverity.major,
    'Ambos são nefrotóxicos e ototóxicos — cisplatina por lesão tubular direta; aminoglicosídeo por acúmulo na cóclea e túbulo proximal',
    'Nefrotoxicidade sinérgica grave, ototoxicidade irreversível (surdez)',
    'Evitar combinação se possível. Se necessário, espaçar administrações, monitorar função renal e audiometria, ajustar dose por clearance',
    'NEFRO E OTOTOXICIDADE SINÉRGICA — Ambos lesam rins e cóclea; evitar combinação',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx]),

  // ── 9. HIPOGLICEMIANTES — pares faltantes ─────────────────────────────────
  ('insulina', 'alcool', InteractionSeverity.major,
    'Álcool inibe gliconeogênese hepática e potencializa o efeito hipoglicemiante da insulina',
    'Hipoglicemia grave prolongada — especialmente noturna; o álcool mascara os sintomas adrenérgicos de hipoglicemia',
    'Alertar paciente sobre risco. Monitorar glicemia. Orientar ingestão de carboidrato junto com bebida alcoólica. Evitar consumo de álcool em jejum',
    'RISCO DE HIPOGLICEMIA GRAVE — Álcool potencializa insulina e mascara sintomas de hipoglicemia',
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
    'Álcool potencializa efeito hipoglicemiante e inibe gliconeogênese; com algumas sulfonilureias (clorpropamida) causa reação similar ao dissulfiram',
    'Hipoglicemia grave prolongada; rubor facial, náusea e palpitações (reação dissulfiram-like com clorpropamida)',
    'Orientar moderação no consumo de álcool. Monitorar glicemia. Evitar jejum prolongado combinado com álcool',
    'RISCO DE HIPOGLICEMIA — Álcool potencializa sulfonilureias e pode mascarar sintomas',
    EvidenceLevel.established,
    {RiskType.hypoglycemia},
    [_kRefGG, _kRefMdx]),

  ('insulina', 'enalapril', InteractionSeverity.moderate,
    'IECAs aumentam sensibilidade à insulina e podem elevar captação periférica de glicose — mecanismo não completamente elucidado',
    'Hipoglicemia — especialmente em diabéticos tipo 1 e pacientes com doença renal',
    'Monitorar glicemia ao iniciar IECA em pacientes insulinodependentes. Ajustar dose de insulina conforme necessário',
    'Monitorar glicemia — IECAs podem aumentar sensibilidade à insulina e risco de hipoglicemia',
    EvidenceLevel.probable,
    {RiskType.hypoglycemia},
    [_kRefMdx, _kRefUT]),

  ('glibenclamida', 'alcool', InteractionSeverity.major,
    'Álcool potencializa efeito hipoglicemiante das sulfonilureias e inibe gliconeogênese hepática',
    'Hipoglicemia grave e prolongada; pode causar reação dissulfiram-like com rubor, náusea, cefaleia',
    'Orientar evitar álcool em jejum. Monitorar glicemia. Preferir secretagogo com menor risco (gliclazida)',
    'RISCO DE HIPOGLICEMIA GRAVE — Glibenclamida + álcool: hipoglicemia grave e reação dissulfiram',
    EvidenceLevel.established,
    {RiskType.hypoglycemia},
    [_kRefGG, _kRefMdx]),

  // ── 10. IMUNOSSUPRESSORES — pares faltantes ───────────────────────────────
  ('tacrolimo', 'claritromicina', InteractionSeverity.contraindicated,
    'Claritromicina é potente inibidora do CYP3A4 — principal enzima de metabolismo do tacrolimo',
    'Elevação de 5-20x nos níveis séricos de tacrolimo — nefrotoxicidade grave, neurotoxicidade, imunossupressão excessiva',
    'CONTRAINDICADO — Não usar claritromicina em pacientes com tacrolimo. Usar azitromicina ou amoxicilina. Se inevitável: reduzir tacrolimo drasticamente e monitorar nível sérico diariamente',
    'CONTRAINDICADO — Claritromicina eleva tacrolimo em 5-20x: nefrotoxicidade e neurotoxicidade graves',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.plasmaLevel, RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx, _kRefUT]),

  // DUPLICATA REMOVIDA: tacrolimo+fluconazol — par detalhado mantido como fluconazol+tacrolimo (linha ~2541)

  ('tacrolimo', 'rifampicina', InteractionSeverity.contraindicated,
    'Rifampicina induz fortemente CYP3A4 e P-gp — reduz drasticamente os níveis séricos de tacrolimo',
    'Redução de 80-90% nos níveis de tacrolimo — rejeição aguda do enxerto',
    'CONTRAINDICADO — Usar antibiótico alternativo. Se inevitable, aumentar dose de tacrolimo 3-5x e monitorar nível sérico diariamente',
    'CONTRAINDICADO — Rifampicina reduz tacrolimo em 80-90%: risco de rejeição aguda',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),

  ('tacrolimo', 'aine', InteractionSeverity.major,
    'AINEs são nefrotóxicos; tacrolimo já causa nefrotoxicidade — efeito sinérgico na lesão tubular renal',
    'Insuficiência renal aguda grave — especialmente em pacientes transplantados',
    'Evitar AINEs em pacientes com tacrolimo. Usar paracetamol como analgésico alternativo. Monitorar função renal se inevitável',
    'NEFROTOXICIDADE SINÉRGICA — AINEs + tacrolimo: alto risco de IRA em transplantados',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx, _kRefUT]),

  ('ciclosporina', 'aine', InteractionSeverity.major,
    'AINEs reduzem prostaglandinas vasodilatadoras renais; ciclosporina já causa vasoconstrição da arteríola aferente — efeito sinérgico',
    'Insuficiência renal aguda grave, hipertensão',
    'Evitar AINEs em pacientes com ciclosporina. Usar paracetamol como alternativa. Monitorar função renal e PA',
    'NEFROTOXICIDADE SINÉRGICA — AINEs + ciclosporina: alto risco de IRA',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx, _kRefUT]),

  ('ciclosporina', 'rifampicina', InteractionSeverity.contraindicated,
    'Rifampicina induz fortemente CYP3A4 e P-gp — metabolismo da ciclosporina drasticamente aumentado',
    'Redução de 80-90% nos níveis séricos de ciclosporina — rejeição aguda do enxerto',
    'CONTRAINDICADO — Usar antibiótico alternativo. Se inevitable, aumentar dose de ciclosporina e monitorar nível sérico diariamente',
    'CONTRAINDICADO — Rifampicina reduz ciclosporina em 80-90%: risco de rejeição aguda',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),

  ('azatioprina', 'sulfametoxazol', InteractionSeverity.major,
    'SMX-TMP inibe enzimas de metabolismo da azatioprina e potencializa mielossupressão',
    'Leucopenia grave, pancitopenia — risco de infecções oportunistas graves',
    'Monitorar hemograma semanalmente durante uso concomitante. Reduzir dose de azatioprina se leucopenia',
    'MIELOSSUPRESSÃO — SMX-TMP + azatioprina: risco elevado de leucopenia grave',
    EvidenceLevel.established,
    {RiskType.myelosuppression, RiskType.infection},
    [_kRefGG, _kRefMdx, _kRefUT]),

  // ── 11. ANALGÉSICOS — pares faltantes ────────────────────────────────────
  ('paracetamol', 'alcool', InteractionSeverity.major,
    'Álcool induz CYP2E1 — via de metabolismo que produz o metabólito hepatotóxico NAPQI; indução crônica aumenta formação de NAPQI',
    'Hepatotoxicidade grave — insuficiência hepática fulminante mesmo com doses terapêuticas de paracetamol em alcoólicos crônicos',
    'Limitar paracetamol a ≤2 g/dia em usuários crônicos de álcool. Monitorar função hepática. Considerar AINE como alternativa analgésica se função hepática normal',
    'HEPATOTOXICIDADE — Álcool crônico + paracetamol: risco de falência hepática mesmo em doses terapêuticas',
    EvidenceLevel.established,
    {RiskType.hepatotoxicity},
    [_kRefGG, _kRefMdx, _kRefFDA]),

  ('tramadol', 'carbamazepina', InteractionSeverity.major,
    'Carbamazepina induz CYP3A4 e CYP2B6 — aumenta metabolismo do tramadol e reduz seus níveis plasmáticos',
    'Redução do efeito analgésico do tramadol; possível síndrome de abstinência em usuários crônicos',
    'Considerar analgésico alternativo. Se necessário manter tramadol, aumentar dose com cautela e monitorar eficácia analgésica',
    'Redução do efeito analgésico — carbamazepina reduz níveis de tramadol',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),

  // ── 12. PSICOTRÓPICOS — pares faltantes ──────────────────────────────────
  ('ssri', 'imao_reversivel', InteractionSeverity.contraindicated,
    'Inibição dupla da recaptação e do metabolismo de serotonina — síndrome serotoninérgica',
    'Síndrome serotoninérgica grave: hipertermia, rigidez muscular, mioclonia, alteração do nível de consciência, instabilidade autonômica',
    'CONTRAINDICADO — Aguardar 14 dias após suspender IMAO antes de iniciar SSRI; aguardar 5 meias-vidas do SSRI (14 dias para a maioria, 5 semanas para fluoxetina) antes de iniciar IMAO',
    'CONTRAINDICADO — Síndrome serotoninérgica potencialmente fatal; wash-out obrigatório',
    EvidenceLevel.established,
    {RiskType.serotonin},
    [_kRefGG, _kRefFDA, _kRefUT]),

  ('carbonato de litio', 'aine', InteractionSeverity.major,
    'AINEs inibem síntese de prostaglandinas renais — reduzem excreção renal de lítio, elevando seus níveis séricos',
    'Intoxicação por lítio: tremor grosseiro, ataxia, confusão, convulsões, coma — efeito em 3-5 dias',
    'Evitar AINEs em pacientes com lítio. Usar paracetamol como alternativa analgésica. Se AINE necessário, monitorar lítio sérico em 3-5 dias',
    'INTOXICAÇÃO POR LÍTIO — AINEs elevam lítio sérico em dias; monitorar ou usar paracetamol',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.cns},
    [_kRefGG, _kRefMdx, _kRefUT]),

  ('carbonato de litio', 'furosemida', InteractionSeverity.major,
    'Furosemida causa depleção de sódio — induz reabsorção tubular compensatória de lítio no túbulo proximal',
    'Elevação dos níveis séricos de lítio — intoxicação: tremor, ataxia, confusão, insuficiência renal',
    'Monitorar lítio sérico 5-7 dias após início ou aumento de dose da furosemida. Ajustar dose de lítio conforme necessário. Manter hidratação e ingestão de sódio',
    'INTOXICAÇÃO POR LÍTIO — Furosemida eleva lítio sérico; monitorar rigorosamente',
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
    'Elevação dos níveis séricos de lítio — risco de intoxicação: tremor, ataxia, confusão, insuficiência renal',
    'Monitorar lítio sérico em 5-7 dias ao iniciar ARA-II. Ajustar dose conforme necessário. Manter hidratação',
    'INTOXICAÇÃO POR LÍTIO — ARA-II elevam lítio sérico; monitorar como com IECA',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.cns},
    [_kRefGG, _kRefMdx, _kRefUT]),

  // ── 13. ANTIEPILÉPTICOS — pares faltantes ────────────────────────────────
  ('carbamazepina', 'rifampicina', InteractionSeverity.major,
    'Rifampicina induz CYP3A4 — aumenta metabolismo da carbamazepina',
    'Redução dos níveis séricos de carbamazepina — perda do controle de crises epilépticas',
    'Monitorar nível sérico de carbamazepina ao iniciar rifampicina. Ajustar dose conforme necessário',
    'RISCO DE CRISES — Rifampicina reduz carbamazepina; monitorar níveis séricos',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),

  ('fenitoína', 'carbamazepina', InteractionSeverity.moderate,
    'Interação bidirecional: fenitoína induz CYP3A4 (metabolismo da carbamazepina); carbamazepina induz CYP2C9 (metabolismo da fenitoína)',
    'Variação imprevisível dos níveis de ambos — tanto aumento quanto diminuição possíveis',
    'Monitorar nível sérico de ambos os antiepilépticos regularmente. Ajustar doses individualmente',
    'Monitorar níveis séricos — interação bidirecional e imprevisível entre fenitoína e carbamazepina',
    EvidenceLevel.established,
    {RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),

  ('acido valproico', 'carbamazepina', InteractionSeverity.moderate,
    'Valproato inibe metabolismo do metabólito ativo da carbamazepina (carbamazepina-10,11-epóxido) — acúmulo do metabólito tóxico',
    'Toxicidade por carbamazepina-epóxido: diplopia, ataxia, náusea, tontura — mesmo com nível sérico de carbamazepina normal',
    'Monitorar sintomas de toxicidade por carbamazepina. Medir nível do epóxido se disponível. Considerar redução de carbamazepina',
    'Monitorar toxicidade — valproato acumula metabólito tóxico da carbamazepina mesmo com nível normal',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),

  // ── 14. ANTIFÚNGICOS — pares faltantes ───────────────────────────────────
  ('fluconazol', 'midazolam', InteractionSeverity.contraindicated,
    'Fluconazol inibe fortemente CYP3A4 — principal enzima de metabolismo do midazolam',
    'Elevação de 3-5x nos níveis de midazolam — sedação excessiva e prolongada, depressão respiratória grave',
    'CONTRAINDICADO para midazolam oral. Para midazolam IV em UTI: reduzir dose em 50-75% e monitorar sedação rigorosamente',
    'CONTRAINDICADO via oral — Fluconazol eleva midazolam 3-5x; depressão respiratória grave',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefFDA]),

  ('fluconazol', 'carbamazepina', InteractionSeverity.moderate,
    'Fluconazol inibe CYP3A4 — eleva níveis séricos de carbamazepina',
    'Toxicidade por carbamazepina: tontura, diplopia, ataxia, hiponatremia',
    'Monitorar nível sérico de carbamazepina e sintomas de toxicidade ao iniciar fluconazol',
    'Monitorar toxicidade — fluconazol eleva carbamazepina por inibição do CYP3A4',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),

  ('fluconazol', 'tacrolimo', InteractionSeverity.contraindicated,
    'Fluconazol inibe CYP3A4 e CYP2C19 — principais enzimas de metabolismo do tacrolimo',
    'Elevação de 3-5x nos níveis séricos de tacrolimo — nefrotoxicidade, neurotoxicidade',
    'CONTRAINDICADO em doses plenas — Reduzir tacrolimo drasticamente e monitorar nível sérico diariamente se inevitável',
    'CONTRAINDICADO — Fluconazol eleva tacrolimo 3-5x; alto risco de nefrotoxicidade',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),

  // ── 15. CARDIOVASCULAR — pares faltantes ─────────────────────────────────
  ('betabloqueador', 'verapamil', InteractionSeverity.contraindicated,
    'Efeito aditivo no nó sinusal e AV: betabloqueador reduz frequência e condução; verapamil também — dupla depressão',
    'Bradicardia grave, bloqueio AV completo, assistolia, hipotensão severa, ICC descompensada',
    'CONTRAINDICADO via IV — Para uso oral, apenas sob monitoramento cardíaco rigoroso em situações muito específicas. Evitar na maioria das situações',
    'CONTRAINDICADO IV — Betabloqueador + verapamil IV: risco de assistolia e colapso hemodinâmico',
    EvidenceLevel.established,
    {RiskType.arrhythmia, RiskType.cardiovascular},
    [_kRefGG, _kRefMdx, _kRefFDA]),

  ('hidroclorotiazida', 'aine', InteractionSeverity.moderate,
    'AINEs antagonizam efeito natriurético dos tiazídicos por inibição das prostaglandinas renais',
    'Redução do efeito diurético e anti-hipertensivo; retenção hídrica; possível piora da função renal',
    'Evitar uso crônico concomitante. Monitorar PA e função renal. Preferir paracetamol como analgésico',
    'Monitorar PA e função renal — AINEs reduzem efeito diurético e anti-hipertensivo dos tiazídicos',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.nephrotoxicity},
    [_kRefGG, _kRefUT]),

  // NOTA: par furosemida+litio consolidado em carbonato de litio+furosemida (acima, linha ~2467)

  ('digoxina', 'quinolona', InteractionSeverity.moderate,
    'Quinolonas alteram flora intestinal que metaboliza digoxina — em 10% dos pacientes ("metabolizadores por Eggerthella lenta"), quinolonas aumentam absorção de digoxina significativamente',
    'Elevação dos níveis séricos de digoxina em subpopulação específica — toxicidade digitálica',
    'Monitorar nível sérico de digoxina e sintomas de toxicidade (náusea, bradicardia) ao iniciar quinolona',
    'Monitorar nível de digoxina — quinolonas podem elevar níveis em ~10% dos pacientes',
    EvidenceLevel.probable,
    {RiskType.arrhythmia, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),

  ('clopidogrel', 'morfina', InteractionSeverity.major,
    'Morfina retarda esvaziamento gástrico e absorção de clopidogrel — reduz pico plasmático e concentração máxima',
    'Redução de 30-50% nos níveis plasmáticos de clopidogrel ativo — inibição plaquetária subótima durante fase crítica de SCA',
    'Em SCA com morfina: usar ticagrelor ou prasugrel em vez de clopidogrel (não têm essa interação). Se clopidogrel obrigatório: considerar ticagrelor IV ou cangrelor como ponte',
    'FALHA ANTIAGREGANTE — Morfina reduz clopidogrel em 30-50%; preferir ticagrelor em SCA',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.thrombosis},
    [_kRefUT, _kRefFDA]),

  // ── 16. RESPIRATÓRIO / BRONCODILATADORES ─────────────────────────────────
  ('teofilina', 'eritromicina', InteractionSeverity.major,
    'Eritromicina inibe CYP1A2 e CYP3A4 — principais enzimas de metabolismo da teofilina',
    'Elevação dos níveis séricos de teofilina — toxicidade: náusea, vômito, taquicardia, convulsões, arritmias',
    'Reduzir dose de teofilina em 25-50% ao iniciar eritromicina. Monitorar nível sérico de teofilina. Preferir azitromicina (menor interação)',
    'TOXICIDADE POR TEOFILINA — Eritromicina eleva teofilina; monitorar nível sérico',
    EvidenceLevel.established,
    {RiskType.arrhythmia, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),

  ('teofilina', 'ciprofloxacino', InteractionSeverity.major,
    'Ciprofloxacino inibe CYP1A2 — principal enzima de metabolismo da teofilina; efeito potente e rápido',
    'Elevação de 30-90% nos níveis séricos de teofilina — toxicidade: náusea, vômito, taquicardia, convulsões',
    'Reduzir dose de teofilina em 30-50% ao iniciar ciprofloxacino. Monitorar nível sérico. Preferir levofloxacino ou outro antibiótico com menor interação',
    'TOXICIDADE POR TEOFILINA — Ciprofloxacino eleva teofilina 30-90%; ajustar dose obrigatoriamente',
    EvidenceLevel.established,
    {RiskType.arrhythmia, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefFDA]),

  // ── 17. ANTIRETROVIRAIS — pares faltantes ────────────────────────────────
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
    'Aumento de 2-4x nos níveis plasmáticos de benzodiazepínicos (alprazolam, diazepam, clonazepam). Sedação excessiva, depressão do SNC e risco de depressão respiratória. Lorazepam é menos afetado (metabolismo por glucuronidação).',
    'Monitorar sedação e função respiratória. Reduzir dose do benzodiazepínico em 50% ao iniciar fluconazol. Preferir lorazepam quando possível (menos dependente de CYP3A4). Evitar alprazolam e diazepam prolongados com fluconazol sistêmico.',
    'SEDAÇÃO AUMENTADA — Fluconazol inibe CYP3A4; reduzir dose do benzodiazepínico em 50%',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.respiratoryDepression, RiskType.plasmaLevel},
    [_kRefGG, _kRefUT]),

];


// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// MAPA DE TERMOS PARA NORMALIZAÇÃO
// Associa nomes comerciais / genéricos comuns ao ID usado na tabela
// ─────────────────────────────────────────────────────────────────────────────
const _termMap = <String, String>{
  // Anticoagulantes
  'warfarina': 'warfarina', 'varfarina': 'warfarina', 'coumadin': 'warfarina',
  'marevan': 'warfarina', 'warfarin': 'warfarina',
  'heparina': 'heparina', 'enoxaparina': 'heparina', 'clexane': 'heparina',
  'alisquireno': 'alisquireno', 'rasilez': 'alisquireno',

  // Antiagregantes
  'aspirina': 'aspirina', 'aas': 'aas', 'ácido acetilsalicílico': 'aspirina',
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
  'acido valproico': 'acido valproico', 'ácido valpróico': 'acido valproico',
  'valproato': 'acido valproico', 'depakote': 'acido valproico',
  'lamotrigina': 'lamotrigina', 'lamictal': 'lamotrigina',

  // Psicotrópicos
  'tramadol': 'tramadol', 'tramal': 'tramadol',
  'morfina': 'morfina', 'meperidina': 'opioide', 'codeína': 'opioide',
  'fentanila': 'opioide', 'oxicodona': 'opioide', 'opioide': 'opioide',
  'benzodiazepínico': 'benzodiazepínico', 'diazepam': 'benzodiazepínico',
  'lorazepam': 'benzodiazepínico', 'alprazolam': 'benzodiazepínico',
  'clonazepam': 'benzodiazepínico', 'rivotril': 'benzodiazepínico',
  'bromazepam': 'benzodiazepínico', 'lexotan': 'benzodiazepínico',
  'nitrazepam': 'benzodiazepínico', 'triazolam': 'benzodiazepínico',
  // midazolam tem IDs diretos no banco → ID canônico próprio (NÃO benzodiazepínico)
  'midazolam': 'midazolam', 'dormicum': 'midazolam', 'versed': 'midazolam',
  'haloperidol': 'haloperidol', 'haldol': 'haloperidol',
  'quetiapina': 'quetiapina', 'seroquel': 'quetiapina',
  'ssri': 'ssri', 'fluoxetina': 'ssri', 'sertralina': 'ssri',
  'escitalopram': 'ssri', 'paroxetina': 'ssri', 'citalopram': 'ssri',
  'imao': 'imao', 'fenelzina': 'imao', 'tranilcipromina': 'imao',
  'linezolida': 'linezolida', 'linezolid': 'linezolida', 'zyvox': 'linezolida',
  'amitriptilina': 'amitriptilina', 'laroxyl': 'amitriptilina', 'tryptanol': 'amitriptilina',
  'atropina': 'atropina',
  'litio': 'carbonato de litio', 'lítio': 'carbonato de litio',
  'carbonato de litio': 'carbonato de litio',

  // Hipoglicemiantes
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

  // Hipoglicemiantes / Obesidade novos
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
  'zoloft': 'ssri', 'sertraline': 'ssri', 'serenata': 'ssri',
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

  // Endocrinologia / Hipoglicemiantes (glibenclamida/daonil já mapeados acima)
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
  'piperacilina_tazobactam': 'piperacilina_tazobactam',
  'piperacilina tazobactam': 'piperacilina_tazobactam',
  'piperacilina-tazobactam': 'piperacilina_tazobactam',
  'pip-tazo': 'piperacilina_tazobactam', 'tazocin': 'piperacilina_tazobactam',
  'zosyn': 'piperacilina_tazobactam',

  // Quimioterapia — cisplatina
  'cisplatina': 'cisplatina', 'cisplatin': 'cisplatina', 'platinol': 'cisplatina',

  // Estatinas — rosuvastatina
  'rosuvastatina': 'rosuvastatina', 'rosuvastatin': 'rosuvastatina',
  'vivacor': 'rosuvastatina', 'rosuvas': 'rosuvastatina', 'crestor': 'rosuvastatina', 'ezallor': 'rosuvastatina',

  // Fibratos
  'fenofibrato': 'fenofibrato', 'tricor': 'fenofibrato', 'lipanthyl': 'fenofibrato',
  'fenofibrate': 'fenofibrato', 'triglide': 'fenofibrato',

  // IMAO reversível (moclobemida)
  'imao_reversivel': 'imao_reversivel', 'moclobemida': 'imao_reversivel',
  'aurorix': 'imao_reversivel', 'moclobemide': 'imao_reversivel',

  // Lítio — aliases adicionais (ID canônico: 'carbonato de litio')
  'li': 'carbonato de litio', 'lithium': 'carbonato de litio',
  'quilonorm': 'carbonato de litio', 'carbolithium': 'carbonato de litio',
  'litiocar': 'carbonato de litio',

  // (valproato e betabloqueador já mapeados acima — sem duplicatas)
};

// ─────────────────────────────────────────────────────────────────────────────
// SERVIÇO PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────
class DrugInteractionService {

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
