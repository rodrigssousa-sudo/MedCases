// drug_interaction_service.dart — Detecção de interações medicamentosas
// Base de dados embutida (offline, sem API externa)
// Fontes: Micromedex, UpToDate, Harrison's, Drugs.com interaction checker

/// Severidade da interação
enum InteractionSeverity {
  contraindicated, // Contraindicado — não usar juntos
  major,           // Maior — risco clínico significativo
  moderate,        // Moderada — monitorar com atenção
  minor,           // Menor — relevância clínica baixa
}

/// Resultado de uma interação detectada
class DrugInteraction {
  final String drug1;       // Nome do fármaco 1
  final String drug2;       // Nome do fármaco 2
  final InteractionSeverity severity;
  final String mechanism;   // Mecanismo da interação
  final String effect;      // Efeito clínico
  final String management;  // Conduta recomendada

  const DrugInteraction({
    required this.drug1,
    required this.drug2,
    required this.severity,
    required this.mechanism,
    required this.effect,
    required this.management,
  });

  String get severityLabel {
    switch (severity) {
      case InteractionSeverity.contraindicated: return 'CONTRAINDICADO';
      case InteractionSeverity.major:           return 'MAIOR';
      case InteractionSeverity.moderate:        return 'MODERADA';
      case InteractionSeverity.minor:           return 'MENOR';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BANCO DE INTERAÇÕES (termos normalizados para busca)
// Cada entrada: (id_fármaco_1, id_fármaco_2, severidade, mecanismo, efeito, conduta)
// ─────────────────────────────────────────────────────────────────────────────
const _interactionDB = <(String, String, InteractionSeverity, String, String, String)>[

  // ── AINES / Anticoagulantes ───────────────────────────────────────────────
  ('warfarina', 'aspirina',        InteractionSeverity.major,
    'Inibição plaquetária aditiva + deslocamento proteico aumentando INR',
    'Risco aumentado de sangramento grave (GI, intracraniano)',
    'Evitar combinação. Se necessário, usar dose mínima de AAS (≤100 mg/dia) com INR ≤2,5 e monitoramento frequente'),
  ('warfarina', 'aas',             InteractionSeverity.major,
    'Inibição plaquetária aditiva + deslocamento proteico aumentando INR',
    'Risco aumentado de sangramento grave (GI, intracraniano)',
    'Evitar combinação. Se necessário, usar dose mínima de AAS (≤100 mg/dia) com INR ≤2,5 e monitoramento frequente'),
  ('warfarina', 'ibuprofeno',      InteractionSeverity.major,
    'Deslocamento da ligação proteica e inibição plaquetária',
    'Elevação do INR e risco de sangramento',
    'Evitar. Preferir paracetamol como analgésico. Monitorar INR se inevitável'),
  ('warfarina', 'naproxeno',       InteractionSeverity.major,
    'Deslocamento da ligação proteica e inibição plaquetária',
    'Elevação do INR e risco de sangramento',
    'Evitar. Preferir paracetamol como analgésico. Monitorar INR se inevitável'),
  ('warfarina', 'cetorolaco',      InteractionSeverity.major,
    'AINE potente com efeito anticoagulante aditivo',
    'Risco hemorrágico grave — combinação perigosa',
    'Contraindicado. Usar analgésico alternativo'),
  ('warfarina', 'metronidazol',    InteractionSeverity.major,
    'Inibição do CYP2C9 reduz metabolismo da warfarina',
    'Aumento significativo do INR → risco de hemorragia',
    'Monitorar INR a cada 2–3 dias. Reduzir dose de warfarina em ~25–50%'),
  ('warfarina', 'fluconazol',      InteractionSeverity.major,
    'Inibição potente do CYP2C9 e CYP3A4',
    'Elevação marcada do INR com risco hemorrágico grave',
    'Reduzir dose de warfarina em 25–50%. Monitorar INR diariamente nos primeiros 3–5 dias'),
  ('warfarina', 'amiodarona',      InteractionSeverity.major,
    'Inibição do CYP2C9 (metabolizador da varfarina S) pela amiodarona e seus metabólitos',
    'Elevação progressiva do INR — efeito pode durar semanas após suspender amiodarona',
    'Reduzir dose de warfarina em 30–50%. Monitorar INR semanalmente. Efeito persiste por meses'),
  ('warfarina', 'ciprofloxacino',  InteractionSeverity.moderate,
    'Inibição do CYP1A2 e possível redução da flora intestinal produtora de vitamina K',
    'Elevação do INR',
    'Monitorar INR 2–3 dias após início e 2–3 dias após término do antibiótico'),

  // ── Estatinas ─────────────────────────────────────────────────────────────
  ('sinvastatina', 'amiodarona',   InteractionSeverity.major,
    'Inibição do CYP3A4 aumenta concentração de sinvastatina',
    'Risco de miopatia / rabdomiólise',
    'Dose máxima de sinvastatina: 20 mg/dia com amiodarona. Preferir rosuvastatina ou pravastatina'),
  ('sinvastatina', 'claritromicina', InteractionSeverity.major,
    'Inibição potente do CYP3A4',
    'Risco de rabdomiólise',
    'Suspender sinvastatina durante o curso de claritromicina. Alternativa: azitromicina'),
  ('sinvastatina', 'eritromicina',   InteractionSeverity.major,
    'Inibição do CYP3A4',
    'Risco de miopatia/rabdomiólise',
    'Suspender sinvastatina durante o curso. Alternativa: azitromicina'),
  ('sinvastatina', 'fluconazol',     InteractionSeverity.major,
    'Inibição do CYP3A4',
    'Risco de rabdomiólise',
    'Suspender sinvastatina durante uso de fluconazol'),
  ('atorvastatina', 'claritromicina', InteractionSeverity.moderate,
    'Inibição do CYP3A4 aumenta nível de atorvastatina',
    'Risco aumentado de miopatia',
    'Reduzir dose de atorvastatina. Preferir azitromicina'),
  ('atorvastatina', 'amiodarona',    InteractionSeverity.moderate,
    'Inibição do CYP3A4',
    'Risco de miopatia',
    'Limitar atorvastatina a 40 mg/dia. Monitorar CPK e sintomas musculares'),

  // ── IECA / ARA-II / Diuréticos ────────────────────────────────────────────
  ('enalapril', 'espironolactona',  InteractionSeverity.moderate,
    'Ambos elevam potássio sérico por mecanismos distintos',
    'Hipercalemia, especialmente em DRC ou insuficiência cardíaca',
    'Monitorar K+ sérico e função renal semanalmente no início; reduzir dose de espironolactona se K+ >5,5 mEq/L'),
  ('losartana', 'espironolactona',  InteractionSeverity.moderate,
    'Ambos elevam potássio sérico',
    'Hipercalemia — mais frequente em IRC/ICF',
    'Monitorar K+ sérico e creatinina regularmente'),
  ('enalapril', 'alisquireno',      InteractionSeverity.contraindicated,
    'Bloqueio duplo do SRAA',
    'Hipotensão grave, hipercalemia e insuficiência renal aguda',
    'Combinação contraindicada por guidelines (ESC 2016, JNC)'),
  ('losartana', 'alisquireno',      InteractionSeverity.contraindicated,
    'Bloqueio duplo do SRAA',
    'Hipotensão grave, hipercalemia e insuficiência renal aguda',
    'Combinação contraindicada — evitar em qualquer paciente'),
  ('enalapril', 'aine',             InteractionSeverity.moderate,
    'AINEs reduzem síntese de prostaglandinas vasodilatadoras renais',
    'Redução do efeito anti-hipertensivo do IECA; risco de IRA',
    'Evitar uso crônico concomitante. Se necessário, monitorar PA e função renal'),

  // ── Betabloqueadores ──────────────────────────────────────────────────────
  ('metoprolol', 'verapamil',      InteractionSeverity.major,
    'Efeito aditivo de ambos no nó AV (cronotropismo e dromotropismo negativos)',
    'Bradicardia grave, bloqueio AV completo, hipotensão, ICC',
    'Contraindicado na maioria das situações. Se inevitável, monitorar com ECG contínuo'),
  ('metoprolol', 'diltiazem',      InteractionSeverity.major,
    'Efeito aditivo no nó sinusal e AV',
    'Bradicardia, bloqueio AV, hipotensão',
    'Evitar combinação. Se necessário, iniciar com doses muito baixas e monitorar ECG'),
  ('propranolol', 'verapamil',     InteractionSeverity.major,
    'Efeito aditivo no nó AV',
    'Bradicardia grave, bloqueio AV, parada cardíaca (relatos)',
    'Contraindicado — alternativa: usar apenas um deles'),
  ('metoprolol', 'clonidina',      InteractionSeverity.moderate,
    'Retirada abrupta de clonidina com betabloqueador causa hipertensão rebote grave',
    'Crise hipertensiva rebote ao suspender clonidina',
    'Nunca suspender clonidina abruptamente; se suspender, retirar betabloqueador primeiro'),

  // ── Antiarrítmicos ────────────────────────────────────────────────────────
  ('amiodarona', 'sotalol',        InteractionSeverity.contraindicated,
    'Prolongamento aditivo do intervalo QT',
    'Torsade de Pointes, fibrilação ventricular, morte súbita',
    'Contraindicado — nunca combinar antiarrítmicos que prolongam QT'),
  ('amiodarona', 'haloperidol',    InteractionSeverity.major,
    'Prolongamento aditivo do QT',
    'Torsade de Pointes',
    'Evitar. Se necessário, monitorar QTc com ECG regular'),
  ('amiodarona', 'digoxina',       InteractionSeverity.major,
    'Inibição da P-glicoproteína aumenta nível sérico de digoxina',
    'Toxicidade digitálica — náuseas, bradicardia, distúrbios visuais',
    'Reduzir dose de digoxina em 50%. Monitorar nível sérico e ECG'),
  ('digoxina', 'furosemida',       InteractionSeverity.moderate,
    'Furosemida causa hipocalemia que potencializa toxicidade da digoxina',
    'Arritmias por toxicidade digitálica facilitadas pela hipocalemia',
    'Monitorar K+ sérico; repor potássio se <4 mEq/L; dosar digoxina se suspeita de toxicidade'),
  ('digoxina', 'espironolactona',  InteractionSeverity.moderate,
    'Espironolactona pode elevar nível sérico de digoxina (inibição da secreção tubular)',
    'Toxicidade digitálica aumentada',
    'Monitorar nível sérico de digoxina após introdução de espironolactona'),

  // ── Antibióticos ──────────────────────────────────────────────────────────
  ('metronidazol', 'alcool',       InteractionSeverity.contraindicated,
    'Inibição da aldeído desidrogenase — reação tipo dissulfiram',
    'Flushing, náuseas, vômitos, cefaleia, taquicardia, hipotensão',
    'Contraindicado álcool durante uso e por 48h após término do metronidazol'),
  ('quinolona', 'antiácido',       InteractionSeverity.moderate,
    'Cátions divalentes (Al, Mg, Ca) quelam quinolonas no TGI',
    'Redução de 50–90% na absorção oral da quinolona',
    'Administrar quinolona 2h antes ou 6h após antiácido/suplemento de cálcio/ferro'),
  ('ciprofloxacino', 'teofilina',  InteractionSeverity.major,
    'Inibição do CYP1A2 reduz metabolismo da teofilina',
    'Toxicidade por teofilina — náuseas, convulsões, arritmias',
    'Reduzir dose de teofilina em 30–50%. Monitorar nível sérico de teofilina'),
  ('claritromicina', 'estatina',   InteractionSeverity.major,
    'Inibição do CYP3A4 eleva concentração plasmática de estatinas metabolizadas por esse CYP',
    'Risco de miopatia/rabdomiólise',
    'Suspender estatina durante o curso de claritromicina. Alternativa: azitromicina'),
  ('rifampicina', 'warfarina',     InteractionSeverity.major,
    'Indução potente do CYP2C9 — aumenta metabolismo da warfarina',
    'Redução marcada do efeito anticoagulante (INR pode cair >50%)',
    'Monitorar INR diariamente no início e ao final. Aumentar dose de warfarina significativamente'),

  // ── Psicotrópicos / SNC ───────────────────────────────────────────────────
  ('tramadol', 'ssri',             InteractionSeverity.major,
    'Inibição da recaptação serotoninérgica somada',
    'Síndrome serotoninérgica — agitação, hipertermia, mioclonia, taquicardia',
    'Evitar combinação. Se indispensável, iniciar com dose baixa de tramadol e monitorar por 24–48h'),
  ('tramadol', 'imao',             InteractionSeverity.contraindicated,
    'Potenciação serotoninérgica extrema',
    'Síndrome serotoninérgica grave com risco de morte',
    'Contraindicado — aguardar 14 dias após suspender IMAO antes de usar tramadol'),
  ('tramadol', 'morfina',          InteractionSeverity.moderate,
    'Efeitos aditivos no SNC e depressão respiratória',
    'Sedação excessiva, depressão respiratória',
    'Usar com cautela. Monitorar nível de consciência e função respiratória'),
  ('benzodiazepínico', 'opioide',  InteractionSeverity.major,
    'Depressão aditiva do SNC — sinergia respiratória e sedativa',
    'Depressão respiratória grave, coma, morte (alerta FDA/ANVISA)',
    'Evitar combinação. Se essencial (ICU/paliativo), monitorar com oximetria contínua; ter naloxona disponível'),
  ('haloperidol', 'carbonato de litio', InteractionSeverity.moderate,
    'Possível potenciação neurotóxica; lítio pode alterar farmacocinética do haloperidol',
    'Neurotoxicidade aumentada — confusão, tremor, extra-piramidal exacerbado',
    'Monitorar lítio sérico, ECG e sinais neurológicos'),
  ('ssri', 'imao',                 InteractionSeverity.contraindicated,
    'Hiperestimulação serotoninérgica extrema',
    'Síndrome serotoninérgica grave — hiperpirexia, convulsões, colapso cardiovascular, morte',
    'Contraindicado. Aguardar 14 dias após suspender IMAO (ou 5 semanas para fluoxetina) antes de iniciar SSRI'),

  // ── Hipoglicemiantes ──────────────────────────────────────────────────────
  ('metformina', 'contraste iodado', InteractionSeverity.major,
    'Contraste iodado pode causar IRA transitória → acúmulo de metformina → acidose lática',
    'Acidose lática (rara mas grave)',
    'Suspender metformina 48h antes de contraste em pacientes com DRC (TFG <60). Reintroduzir após 48h se função renal estável'),
  ('glibenclamida', 'fluconazol',  InteractionSeverity.major,
    'Inibição do CYP2C9 aumenta nível sérico de glibenclamida',
    'Hipoglicemia grave e prolongada',
    'Evitar. Se necessário, monitorar glicemia intensivamente e reduzir dose de glibenclamida'),
  ('insulina', 'betabloqueador',   InteractionSeverity.moderate,
    'Betabloqueadores mascarar taquicardia e tremor (sintomas adrenérgicos de hipoglicemia)',
    'Hipoglicemia pode passar desapercebida — somente sudorese persiste como sinal',
    'Preferir betabloqueadores cardiosseletivos. Orientar o paciente. Monitorar glicemia mais frequentemente'),

  // ── Imunossupressores ─────────────────────────────────────────────────────
  ('ciclosporina', 'fluconazol',   InteractionSeverity.major,
    'Inibição do CYP3A4 eleva nível sérico de ciclosporina',
    'Nefrotoxicidade e imunossupressão excessiva',
    'Reduzir dose de ciclosporina em 50% e monitorar nível sérico diariamente'),
  ('ciclosporina', 'claritromicina', InteractionSeverity.major,
    'Inibição do CYP3A4 e P-gp',
    'Aumento do nível sérico de ciclosporina — nefrotoxicidade',
    'Reduzir dose de ciclosporina; monitorar nível sérico frequentemente'),

  // ── Cardiovascular / Miscellaneous ────────────────────────────────────────
  ('atorvastatina', 'gemfibrozil',  InteractionSeverity.major,
    'Inibição da glucuronidação da atorvastatina pelo gemfibrozil',
    'Risco significativo de miopatia/rabdomiólise',
    'Evitar combinação. Se necessário usar fibratos, preferir fenofibrato + estatina'),
  ('sildenafila', 'nitrato',        InteractionSeverity.contraindicated,
    'Ambos potencializam vasodilatação via via GMPc',
    'Hipotensão grave, choque cardiovascular, colapso hemodinâmico, morte',
    'Contraindicado absolutamente. Aguardar ≥24h após sildenafila (≥48h para tadalafila) para administrar nitrato'),
  ('sildenafila', 'alfa-bloqueador', InteractionSeverity.major,
    'Efeito hipotensor aditivo',
    'Hipotensão sintomática grave — tontura, síncope',
    'Iniciar alfa-bloqueador com dose baixa. Aguardar estabilização antes de associar. Orientar paciente'),
  ('furosemida', 'aminoglicosideo', InteractionSeverity.major,
    'Ototoxicidade aditiva sinérgica',
    'Surdez neurossensorial permanente — risco aumentado especialmente em DRC',
    'Evitar combinação. Se necessário, minimizar dose e duração; monitorar função auditiva'),
  ('furosemida', 'aine',            InteractionSeverity.moderate,
    'AINEs inibem síntese de prostaglandinas renais vasodilatadoras',
    'Redução do efeito diurético; risco de IRA',
    'Evitar AINEs em pacientes usando furosemida, especialmente se ICC/DRC'),

  // ── Antifúngicos / QT ──────────────────────────────────────────────────────
  ('fluconazol', 'quetiapina',     InteractionSeverity.major,
    'Inibição do CYP3A4 eleva nível de quetiapina + ambos prolongam QT',
    'Prolongamento QT excessivo → Torsade de Pointes',
    'Evitar. Monitorar ECG se inevitável; reduzir dose de quetiapina'),
  ('haloperidol', 'ondansetrona',  InteractionSeverity.major,
    'Prolongamento aditivo do QT por mecanismos distintos',
    'Torsade de Pointes',
    'Evitar. Monitorar QTc. Se QTc >500ms, suspender um dos medicamentos'),

  // ── Heparina / Anticoagulantes ─────────────────────────────────────────────
  ('heparina', 'aspirina',         InteractionSeverity.moderate,
    'Efeito antitrombótico/hemostático aditivo',
    'Risco aumentado de sangramento (especialmente GI)',
    'Monitorar sinais de sangramento. Combinação aceita em SCA (protocolo AHA/ACC), mas com atenção'),
  ('heparina', 'nsaid',            InteractionSeverity.moderate,
    'AINEs inibem função plaquetária + risco de sangramento GI',
    'Risco aumentado de hemorragia',
    'Evitar AINEs durante anticoagulação. Preferir paracetamol para analgesia'),

];

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
  'diclofenaco': 'aine', 'voltaren': 'aine', 'aine': 'aine', 'nsaid': 'nsaid',
  'nimesulida': 'aine', 'meloxicam': 'aine', 'piroxicam': 'aine',
  'indometacina': 'aine', 'celecoxib': 'aine', 'etoricoxib': 'aine',

  // Estatinas
  'sinvastatina': 'sinvastatina', 'zocor': 'sinvastatina', 'simvastatina': 'sinvastatina',
  'atorvastatina': 'atorvastatina', 'crestor': 'atorvastatina', 'lipitor': 'atorvastatina',
  'estatina': 'estatina',
  'gemfibrozil': 'gemfibrozil', 'lopid': 'gemfibrozil',

  // Anti-hipertensivos
  'enalapril': 'enalapril', 'renitec': 'enalapril', 'vasotec': 'enalapril',
  'ramipril': 'enalapril', 'captopril': 'enalapril', 'lisinopril': 'enalapril',
  'ieca': 'enalapril', 'perindopril': 'enalapril',
  'losartana': 'losartana', 'cozaar': 'losartana', 'valsartana': 'losartana',
  'olmesartana': 'losartana', 'ara-ii': 'losartana', 'irbesartana': 'losartana',
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

  // Psicotrópicos
  'tramadol': 'tramadol', 'tramal': 'tramadol',
  'morfina': 'morfina', 'meperidina': 'opioide', 'codeína': 'opioide',
  'fentanila': 'opioide', 'oxicodona': 'opioide', 'opioide': 'opioide',
  'benzodiazepínico': 'benzodiazepínico', 'diazepam': 'benzodiazepínico',
  'lorazepam': 'benzodiazepínico', 'midazolam': 'benzodiazepínico',
  'alprazolam': 'benzodiazepínico', 'clonazepam': 'benzodiazepínico',
  'haloperidol': 'haloperidol', 'haldol': 'haloperidol',
  'quetiapina': 'quetiapina', 'seroquel': 'quetiapina',
  'ssri': 'ssri', 'fluoxetina': 'ssri', 'sertralina': 'ssri',
  'escitalopram': 'ssri', 'paroxetina': 'ssri', 'citalopram': 'ssri',
  'imao': 'imao', 'fenelzina': 'imao', 'tranilcipromina': 'imao',
  'litio': 'carbonato de litio', 'lítio': 'carbonato de litio',
  'carbonato de litio': 'carbonato de litio',

  // Hipoglicemiantes
  'metformina': 'metformina', 'glifage': 'metformina', 'glucoformin': 'metformina',
  'glibenclamida': 'glibenclamida', 'daonil': 'glibenclamida',
  'insulina': 'insulina',
  'contraste': 'contraste iodado', 'contraste iodado': 'contraste iodado',

  // Imunossupressores
  'ciclosporina': 'ciclosporina', 'neoral': 'ciclosporina', 'sandimmun': 'ciclosporina',

  // Cardiovascular misc.
  'sildenafila': 'sildenafila', 'viagra': 'sildenafila', 'sildenafil': 'sildenafila',
  'tadalafila': 'sildenafila', 'cialis': 'sildenafila',
  'nitrato': 'nitrato', 'nitroglicerina': 'nitrato', 'isossorbida': 'nitrato',
  'mononitrato': 'nitrato', 'dinitrato': 'nitrato',
  'alfa-bloqueador': 'alfa-bloqueador', 'doxazosina': 'alfa-bloqueador',
  'tansulosina': 'alfa-bloqueador', 'prazosina': 'alfa-bloqueador',
  'teofilina': 'teofilina', 'aminofilina': 'teofilina',
  'ondansetrona': 'ondansetrona', 'zofran': 'ondansetrona',

  // Outros
  'antiácido': 'antiácido', 'omeprazol': 'antiácido', 'hidróxido': 'antiácido',
  'álcool': 'alcool', 'alcool': 'alcool', 'bebida': 'alcool',
  'gemfibrozila': 'gemfibrozil',
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
