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

  // ── Amiodarona — QT e interações adicionais ───────────────────────────────
  ('amiodarona', 'azitromicina',   InteractionSeverity.major,
    'Prolongamento aditivo do intervalo QT por mecanismos distintos',
    'Torsades de Pointes, fibrilação ventricular',
    'Evitar combinação. Se antibiótico essencial, preferir amoxicilina ou doxiciclina. Monitorar QTc'),
  ('amiodarona', 'metoprolol',     InteractionSeverity.major,
    'Efeito cronotrópico e dromotrópico negativo aditivo sobre o nó sinusal e AV',
    'Bradicardia grave, bloqueio AV, colapso hemodinâmico',
    'Monitorar FC e ECG continuamente. Reduzir dose do betabloqueador. Ter atropina disponível'),

  // ── Warfarina — entradas complementares ───────────────────────────────────
  ('warfarina', 'aine',            InteractionSeverity.major,
    'AINEs inibem função plaquetária e causam ulceração GI; deslocamento proteico eleva INR',
    'Risco muito alto de sangramento gastrointestinal e ulceração péptica',
    'Evitar combinação. Preferir paracetamol. Se inevitável, usar IBP e monitorar INR frequentemente'),

  // ── Clopidogrel ───────────────────────────────────────────────────────────
  ('clopidogrel', 'omeprazol',     InteractionSeverity.moderate,
    'Inibição do CYP2C19 pelo omeprazol reduz conversão do clopidogrel ao metabólito ativo',
    'Redução do efeito antiagregante — maior risco de eventos isquêmicos e trombose de stent',
    'Preferir pantoprazol (menor inibição CYP2C19) se IBP necessário. Monitorar eventos cardiovasculares'),
  ('clopidogrel', 'esomeprazol',   InteractionSeverity.moderate,
    'Inibição do CYP2C19 pelo esomeprazol reduz ativação do clopidogrel',
    'Eficácia antiagregante reduzida — risco de trombose de stent',
    'Substituir por pantoprazol. Reavaliar necessidade do IBP após período de risco'),

  // ── IECA — entradas complementares ────────────────────────────────────────
  ('enalapril', 'sacubitrila',     InteractionSeverity.contraindicated,
    'Inibição simultânea do sistema neprilisina-angiotensina causa acúmulo de bradicinina',
    'Angioedema grave e potencialmente fatal — risco 3× maior que IECA isolado',
    'Contraindicado. Respeitar janela de washout de 36 horas entre suspender IECA e iniciar sacubitrila'),

  // ── Lítio ─────────────────────────────────────────────────────────────────
  ('carbonato de litio', 'ibuprofeno',      InteractionSeverity.major,
    'AINEs reduzem excreção renal de lítio por inibição das prostaglandinas renais',
    'Toxicidade lítica rápida — tremor, confusão, convulsões, arritmias',
    'Evitar AINEs em pacientes em uso de lítio. Usar paracetamol. Monitorar litemia se inevitável'),
  ('carbonato de litio', 'hidroclorotiazida', InteractionSeverity.major,
    'Tiazídicos aumentam reabsorção proximal de sódio e lítio em compensação à perda distal',
    'Toxicidade por lítio — confusão, tremor, nefrotoxicidade',
    'Monitorar litemia a cada 3–5 dias no início. Reduzir dose de lítio em 30–50%'),
  ('carbonato de litio', 'enalapril',       InteractionSeverity.major,
    'IECAs reduzem clearance renal de lítio por inibição da angiotensina II',
    'Elevação dos níveis séricos de lítio — toxicidade',
    'Monitorar litemia semanalmente nas primeiras 4 semanas. Reduzir dose de lítio conforme necessário'),

  // ── Serotonina — entradas complementares ──────────────────────────────────
  ('ssri', 'linezolida',           InteractionSeverity.contraindicated,
    'Linezolida inibe a MAO — hiperestimulação serotoninérgica com SSRI',
    'Síndrome serotoninérgica grave — hipertermia, rigidez, crise convulsiva, colapso',
    'Contraindicado. Aguardar washout adequado (≥5 semanas para fluoxetina, ≥2 semanas para outros SSRIs)'),
  ('tramadol', 'amitriptilina',    InteractionSeverity.major,
    'Redução do limiar convulsivo + inibição da recaptação de serotonina/noradrenalina aditiva',
    'Risco aumentado de convulsões e síndrome serotoninérgica',
    'Evitar combinação. Se necessário, iniciar tramadol em dose mínima com monitoramento neurológico'),

  // ── Aminoglicosídeos ───────────────────────────────────────────────────────
  ('aminoglicosideo', 'vancomicina', InteractionSeverity.major,
    'Nefrotoxicidade e ototoxicidade sinérgica — ambos lesam túbulos renais proximais e células ciliadas',
    'Insuficiência renal aguda, surdez irreversível',
    'Evitar combinação se possível. Se necessária, monitorar creatinina diariamente e função auditiva'),

  // ── Quinolonas — quelação por cátions ─────────────────────────────────────
  ('ciprofloxacino', 'carbonato de calcio', InteractionSeverity.moderate,
    'Cálcio forma complexo insolúvel com ciprofloxacino no intestino (quelação)',
    'Redução de até 50% na absorção oral da quinolona',
    'Administrar ciprofloxacino 2h antes ou 6h após cálcio/antiácidos/ferro'),
  ('ciprofloxacino', 'sulfato ferroso',     InteractionSeverity.moderate,
    'Ferro quelata ciprofloxacino no TGI reduzindo drasticamente sua biodisponibilidade',
    'Falha terapêutica do antibiótico',
    'Administrar ciprofloxacino 2h antes ou 6h após suplemento de ferro'),

  // ── Levotiroxina ──────────────────────────────────────────────────────────
  ('levotiroxina', 'carbonato de calcio',   InteractionSeverity.moderate,
    'Cálcio liga-se à levotiroxina no intestino reduzindo sua absorção',
    'Hipotireoidismo por absorção inadequada — TSH elevado',
    'Intervalo mínimo de 4 horas entre levotiroxina e cálcio. Tomar levotiroxina em jejum'),
  ('levotiroxina', 'pantoprazol',           InteractionSeverity.moderate,
    'Redução da acidez gástrica pelos IBPs prejudica dissolução e absorção da levotiroxina',
    'Absorção reduzida — hipotireoidismo subclínico',
    'Monitorar TSH a cada 6–8 semanas. Pode ser necessário aumentar dose de levotiroxina'),
  ('levotiroxina', 'antiácido',             InteractionSeverity.moderate,
    'Cátions (Al, Mg, Ca) dos antiácidos quelam levotiroxina no TGI',
    'Redução da absorção — hipotireoidismo',
    'Administrar levotiroxina 2h antes de antiácidos, IBPs, cálcio ou ferro'),

  // ── Benzodiazepínicos — complementar ──────────────────────────────────────
  ('benzodiazepínico', 'alcool',   InteractionSeverity.major,
    'Potenciação mútua da depressão do SNC por mecanismos GABA-A aditivos',
    'Sedação severa, depressão respiratória, coma, morte',
    'Contraindicado. Orientar paciente explicitamente sobre proibição de álcool'),

  // ── Anticonvulsivantes ─────────────────────────────────────────────────────
  ('carbamazepina', 'anticoncepcional', InteractionSeverity.major,
    'Indução enzimática do CYP3A4 acelera metabolismo de estrógenos e progestágenos',
    'Falha do anticoncepcional hormonal — gravidez não planejada',
    'Usar método contraceptivo não hormonal (DIU de cobre, preservativo). Orientar explicitamente a paciente'),
  ('acido valproico', 'lamotrigina',    InteractionSeverity.major,
    'Ácido valproico inibe a glucuronidação da lamotrigina, dobrando sua meia-vida',
    'Toxicidade por lamotrigina — rash grave, Síndrome de Stevens-Johnson',
    'Reduzir dose de lamotrigina em 50% ao introduzir valproato. Monitorar rash cutâneo'),
  ('midazolam', 'claritromicina',       InteractionSeverity.major,
    'Inibição potente do CYP3A4 pela claritromicina prolonga meia-vida do midazolam',
    'Sedação prolongada e excessiva, depressão respiratória',
    'Reduzir dose de midazolam em 50–75%. Monitorar nível de consciência e SpO₂'),

  // ── Corticosteroides ──────────────────────────────────────────────────────
  ('dexametasona', 'aine',         InteractionSeverity.major,
    'Corticosteroide + AINE: inibição dupla das prostaglandinas protetoras da mucosa gástrica',
    'Risco muito elevado de úlcera péptica e hemorragia GI',
    'Contraindicado sem proteção gástrica. Prescrever IBP obrigatoriamente se combinação necessária'),

  // ── Hiperpotassemia ────────────────────────────────────────────────────────
  ('espironolactona', 'cloreto de potassio', InteractionSeverity.contraindicated,
    'Espironolactona retém potássio + suplementação adicional = hipercalemia aditiva extrema',
    'Hipercalemia fatal — parada cardíaca em assistolia',
    'Contraindicado. Não suplementar potássio rotineiramente com espironolactona. Monitorar K+ sérico'),

  // ── Colchicina / Imunossupressores ────────────────────────────────────────
  ('colchicina', 'claritromicina', InteractionSeverity.contraindicated,
    'Inibição da P-gp e CYP3A4 eleva drasticamente os níveis de colchicina',
    'Toxicidade por colchicina — miopatia, neuropatia, pancitopenia, falência de múltiplos órgãos',
    'Contraindicado em insuficiência renal ou hepática. Reduzir dose de colchicina e monitorar rigidamente'),
  ('alopurinol', 'azatioprina',    InteractionSeverity.contraindicated,
    'Alopurinol inibe xantina oxidase — enzima que metaboliza azatioprina — causando acúmulo tóxico',
    'Mielossupressão grave: leucopenia, trombocitopenia, anemia aplásica',
    'Contraindicado. Se combinação inevitável, reduzir azatioprina a 25% da dose e monitorar hemograma semanalmente'),

  // ── Interações farmacodinâmicas adicionais ────────────────────────────────
  ('ondansetrona', 'tramadol',     InteractionSeverity.moderate,
    'Ondansetrona bloqueia receptores 5-HT₃ utilizados pelo tramadol para analgesia',
    'Redução significativa do efeito analgésico do tramadol',
    'Avaliar eficácia analgésica. Se necessário, substituir por outro antiemético ou usar analgésico alternativo'),
  ('insulina', 'dapagliflozina',   InteractionSeverity.moderate,
    'Efeito hipoglicemiante aditivo — iSGLT2 potencializa o efeito da insulina',
    'Hipoglicemia grave, especialmente com insulina basal ou bolus elevados',
    'Reduzir dose de insulina em 10–20% ao iniciar iSGLT2. Monitorar glicemia frequentemente'),
  ('amitriptilina', 'atropina',    InteractionSeverity.moderate,
    'Efeitos anticolinérgicos aditivos — bloqueio muscarínico somado',
    'Boca seca intensa, retenção urinária, visão turva, confusão, delírio (especialmente em idosos)',
    'Evitar em idosos. Se necessário, usar menor dose possível e monitorar sintomas anticolinérgicos'),

  // ══════════════════════════════════════════════════════════════════════════
  // NOVAS INTERAÇÕES — MERGE v2
  // Fontes: Micromedex, UpToDate 2024, Drugs.com, Liverpool Drug Interaction
  // Checker, FDA Drug Interaction Labels, ESC/AHA/IDSA guidelines.
  // ══════════════════════════════════════════════════════════════════════════

  // ── Dronedarona ───────────────────────────────────────────────────────────
  ('dronedarona', 'dabigatrana',   InteractionSeverity.major,
    'Dronedarona inibe P-glicoproteína → aumenta absorção e nível sérico de dabigatrana',
    'Risco hemorrágico elevado — aumento de até 100% na exposição à dabigatrana',
    'Reduzir dose de dabigatrana para 75 mg 2x/dia com dronedarona. Monitorar sinais de sangramento'),
  ('dronedarona', 'sinvastatina',  InteractionSeverity.major,
    'Inibição do CYP3A4 e P-gp pela dronedarona aumenta nível de sinvastatina',
    'Risco de miopatia/rabdomiólise',
    'Dose máxima de sinvastatina: 20 mg/dia. Preferir rosuvastatina ou pravastatina'),
  ('dronedarona', 'metoprolol',    InteractionSeverity.major,
    'Inibição do CYP2D6 pela dronedarona aumenta nível de metoprolol + efeito cronotrópico negativo aditivo',
    'Bradicardia grave, bloqueio AV, hipotensão',
    'Monitorar FC e ECG. Reduzir dose de metoprolol. Alvo: FC ≥50 bpm em repouso'),
  ('dronedarona', 'digoxina',      InteractionSeverity.major,
    'Inibição da P-gp aumenta nível sérico de digoxina',
    'Toxicidade digitálica — náuseas, bradicardia, distúrbios de condução',
    'Reduzir dose de digoxina em 50%. Monitorar nível sérico e ECG regularmente'),
  ('dronedarona', 'varfarina',     InteractionSeverity.moderate,
    'Inibição do CYP3A4 e possível efeito no CYP2C9 pela dronedarona',
    'Elevação moderada do INR',
    'Monitorar INR semanalmente nas primeiras 2–4 semanas após introdução. Ajustar dose de varfarina conforme necessário'),
  ('dronedarona', 'ciclosporina',  InteractionSeverity.contraindicated,
    'Inibição mútua do CYP3A4 e P-gp — exposição de ambos aumenta drasticamente',
    'Toxicidade por ciclosporina (nefrotóxica) e toxicidade cardíaca por dronedarona',
    'Combinação contraindicada. Substituir por antiarrítmico alternativo'),

  // ── Ivabradina ────────────────────────────────────────────────────────────
  ('ivabradina', 'diltiazem',      InteractionSeverity.contraindicated,
    'Diltiazem inibe CYP3A4 (aumenta nível de ivabradina) + efeito cronotrópico negativo aditivo no nó sinusal',
    'Bradicardia grave, bloqueio sinusal, assistolia',
    'Combinação contraindicada. Usar apenas um agente para controle de FC'),
  ('ivabradina', 'verapamil',      InteractionSeverity.contraindicated,
    'Verapamil inibe CYP3A4 + efeito bradicardizante sinérgico',
    'Bradicardia grave, síncope, parada sinusal',
    'Contraindicado — não combinar ivabradina com bloqueadores de cálcio não-diidropiridínicos'),
  ('ivabradina', 'claritromicina', InteractionSeverity.major,
    'Inibição potente do CYP3A4 pela claritromicina aumenta exposição à ivabradina em ~7×',
    'Bradicardia grave, prolongamento QT, Torsade de Pointes',
    'Contraindicado. Suspender ivabradina durante curso de claritromicina. Alternativa: azitromicina'),
  ('ivabradina', 'fluconazol',     InteractionSeverity.major,
    'Inibição do CYP3A4 pelo fluconazol aumenta significativamente o nível de ivabradina',
    'Bradicardia excessiva, tontura, fosfenos',
    'Monitorar FC. Reduzir dose de ivabradina se FC <50 bpm. Considerar antifúngico alternativo'),

  // ── Ranolazina ────────────────────────────────────────────────────────────
  ('ranolazina', 'claritromicina', InteractionSeverity.contraindicated,
    'Inibição potente do CYP3A4 aumenta ranolazina em >5× + ambos prolongam QTc',
    'Prolongamento QTc grave, Torsade de Pointes, arritmia ventricular fatal',
    'Contraindicado. Substituir por azitromicina ou doxiciclina'),
  ('ranolazina', 'amiodarona',     InteractionSeverity.major,
    'Amiodarona inibe CYP3A4 + ambos prolongam QTc por mecanismos distintos',
    'Prolongamento QTc excessivo, Torsade de Pointes',
    'Evitar combinação. Se necessária, monitorar QTc (ECG seriado). Suspender se QTc >500 ms'),
  ('ranolazina', 'digoxina',       InteractionSeverity.moderate,
    'Ranolazina inibe P-gp → aumento do nível sérico de digoxina em ~50%',
    'Toxicidade digitálica — bradiarritmias, náuseas, distúrbios visuais',
    'Reduzir dose de digoxina em 50% ao iniciar ranolazina. Monitorar nível sérico'),
  ('ranolazina', 'sinvastatina',   InteractionSeverity.moderate,
    'Inibição do CYP3A4 pela ranolazina aumenta exposição à sinvastatina',
    'Risco aumentado de miopatia',
    'Limitar sinvastatina a 20 mg/dia com ranolazina. Monitorar CPK e sintomas musculares'),

  // ── Eplerenona ────────────────────────────────────────────────────────────
  ('eplerenona', 'cloreto de potassio', InteractionSeverity.contraindicated,
    'Eplerenona retém K⁺ (poupador de potássio) + suplementação adicional',
    'Hipercalemia fatal — parada cardíaca',
    'Contraindicado. Não suplementar potássio rotineiramente com eplerenona. Monitorar K⁺ sérico rigorosamente'),
  ('eplerenona', 'enalapril',      InteractionSeverity.moderate,
    'Ambos elevam K⁺ por mecanismos distintos — antagonismo aldosterona + inibição da angiotensina II',
    'Hipercalemia, especialmente em DRC ou diabetes',
    'Monitorar K⁺ e creatinina semanalmente no início. Reduzir/suspender eplerenona se K⁺ >5,5 mEq/L'),
  ('eplerenona', 'claritromicina', InteractionSeverity.contraindicated,
    'Inibição potente do CYP3A4 pela claritromicina aumenta exposição à eplerenona em >5×',
    'Hipercalemia grave e excessiva retenção de potássio',
    'Contraindicado. Substituir por azitromicina. Aguardar 14 dias após claritromicina antes de reiniciar eplerenona'),

  // ── Daptomicina ───────────────────────────────────────────────────────────
  ('daptomicina', 'estatina',      InteractionSeverity.major,
    'Mecanismo sinérgico de miotoxicidade — ambos lesam membranas musculares por mecanismos complementares',
    'Miopatia grave e rabdomiólise',
    'Suspender estatinas durante uso de daptomicina. Monitorar CPK semanalmente. Reiniciar estatina após término do antibiótico'),
  ('daptomicina', 'aminoglicosideo', InteractionSeverity.moderate,
    'Possível nefrotoxicidade aditiva — ambos podem elevar creatinina em uso prolongado',
    'Insuficiência renal aguda, especialmente em pacientes vulneráveis',
    'Monitorar creatinina e eletrólitos diariamente. Minimizar duração e dose de aminoglicosídeo'),

  // ── Nirmatrelvir/Ritonavir (Paxlovid) ────────────────────────────────────
  ('ritonavir', 'sinvastatina',    InteractionSeverity.contraindicated,
    'Inibição potente do CYP3A4 pelo ritonavir aumenta sinvastatina >10× — rabdomiólise',
    'Rabdomiólise grave, insuficiência renal, coagulação intravascular disseminada',
    'Contraindicado absolutamente. Suspender sinvastatina durante uso de Paxlovid'),
  ('ritonavir', 'midazolam',       InteractionSeverity.contraindicated,
    'Inibição potente do CYP3A4 pelo ritonavir → nível de midazolam aumenta dezenas de vezes',
    'Sedação prolongada e grave, depressão respiratória, coma',
    'Contraindicado. Não usar midazolam oral/parenteral com ritonavir'),
  ('ritonavir', 'amiodarona',      InteractionSeverity.contraindicated,
    'Inibição do CYP3A4 e CYP2C8 pelo ritonavir aumenta amiodarona dramaticamente + QT aditivo',
    'Toxicidade por amiodarona (pulmonar, hepática, tireoidiana) e Torsade de Pointes',
    'Contraindicado. Substituir ritonavir se paciente em uso de amiodarona. Paxlovid contraindicado nestas situações'),
  ('ritonavir', 'warfarina',       InteractionSeverity.major,
    'Ritonavir é indutor e inibidor do CYP2C9 (efeito bifásico) — INR pode aumentar ou diminuir',
    'Instabilidade do INR — risco de sangramento ou trombose dependendo da fase',
    'Monitorar INR a cada 1–2 dias durante uso de Paxlovid e por 2 semanas após. Ajustar dose de varfarina'),
  ('ritonavir', 'atorvastatina',   InteractionSeverity.major,
    'Inibição do CYP3A4 pelo ritonavir aumenta atorvastatina em ~8×',
    'Risco significativo de miopatia/rabdomiólise',
    'Suspender atorvastatina durante uso de Paxlovid (5 dias). Reiniciar após término. Alternativa: pravastatina ou rosuvastatina em baixa dose'),
  ('ritonavir', 'carbamazepina',   InteractionSeverity.major,
    'Carbamazepina é indutor potente do CYP3A4 → reduz drasticamente níveis de nirmatrelvir/ritonavir',
    'Falha terapêutica do Paxlovid — concentrações subterapêuticas de nirmatrelvir',
    'Paxlovid contraindicado com carbamazepina. Considerar molnupiravir como alternativa'),
  ('ritonavir', 'ranolazina',      InteractionSeverity.contraindicated,
    'Inibição do CYP3A4 pelo ritonavir eleva ranolazina drasticamente + prolongamento QTc aditivo',
    'Arritmia ventricular grave, Torsade de Pointes',
    'Contraindicado. Suspender ranolazina durante uso de Paxlovid'),

  // ── Semaglutida / Tirzepatida (arGLP-1) ──────────────────────────────────
  ('semaglutida', 'insulina',      InteractionSeverity.moderate,
    'Efeito hipoglicemiante aditivo — arGLP-1 potencia ação da insulina',
    'Hipoglicemia grave, especialmente com insulina basal ou prandial em altas doses',
    'Reduzir dose de insulina em 20–40% ao iniciar arGLP-1. Monitorar glicemia. Titular gradualmente'),
  ('semaglutida', 'sulfonilureia', InteractionSeverity.moderate,
    'Efeito insulinotrópico aditivo com risco aumentado de hipoglicemia',
    'Hipoglicemia grave, tontura, sudorese, convulsões',
    'Reduzir dose da sulfonilureia em 50% ao iniciar semaglutida. Monitorar glicemia capilar diariamente'),
  ('semaglutida', 'levotiroxina',  InteractionSeverity.minor,
    'Retardo do esvaziamento gástrico pela semaglutida pode reduzir absorção da levotiroxina',
    'Redução da absorção de levotiroxina → hipotireoidismo subclínico',
    'Tomar levotiroxina em jejum, ≥30 min antes da semaglutida se via oral (Rybelsus). Monitorar TSH a cada 6–8 semanas'),

  // ── Canagliflozina / iSGLT2 ──────────────────────────────────────────────
  ('canagliflozina', 'furosemida', InteractionSeverity.moderate,
    'Efeito natriurético e diurético aditivo — ambos causam depleção de volume',
    'Hipotensão grave, IRA pré-renal, desidratação, hipocalemia',
    'Monitorar PA, função renal e eletrólitos. Reduzir dose de furosemida se necessário. Hidratação adequada'),
  ('canagliflozina', 'enalapril',  InteractionSeverity.moderate,
    'Efeito natriurético dos iSGLT2 associado a vasodilatação dos IECAs — hipotensão e hipercalemia',
    'Hipotensão sintomática, IRA pré-renal, hipercalemia',
    'Monitorar PA, K⁺ e função renal nas primeiras 2–4 semanas. Hidratação adequada'),
  ('canagliflozina', 'rifampicina', InteractionSeverity.moderate,
    'Rifampicina induz UGT e CYP → redução de 51% na exposição à canagliflozina',
    'Redução do efeito hipoglicemiante e nefroprotetor',
    'Monitorar controle glicêmico. Pode ser necessário aumentar dose de canagliflozina ou substituir por outra classe'),

  // ── Finerenona ────────────────────────────────────────────────────────────
  ('finerenona', 'claritromicina', InteractionSeverity.contraindicated,
    'Inibição potente do CYP3A4 pela claritromicina aumenta finerenona em >5×',
    'Hipercalemia grave e potencialmente fatal',
    'Contraindicado. Suspender finerenona durante uso de claritromicina. Alternativa: azitromicina'),
  ('finerenona', 'espironolactona', InteractionSeverity.contraindicated,
    'Antagonismo mineralocorticoide aditivo — duplo bloqueio do receptor de aldosterona',
    'Hipercalemia grave, parada cardíaca',
    'Contraindicado — não combinar dois ARM. Escolher apenas um deles'),
  ('finerenona', 'enalapril',      InteractionSeverity.moderate,
    'Efeito poupador de potássio da finerenona + redução da excreção de K⁺ pelo IECA',
    'Hipercalemia — risco aumentado, especialmente em DRC',
    'Monitorar K⁺ semanalmente nas primeiras 4 semanas. Suspender se K⁺ >5,5 mEq/L'),

  // ── Tocilizumabe / Baricitinibe ───────────────────────────────────────────
  ('tocilizumabe', 'warfarina',    InteractionSeverity.moderate,
    'IL-6 regula expressão de enzimas CYP; ao bloquear IL-6, tocilizumabe restaura metabolismo de varfarina (reduz INR)',
    'Redução inesperada do INR quando tocilizumabe é iniciado ou escalado',
    'Monitorar INR semanalmente por 4–6 semanas após início do tocilizumabe. Ajustar dose de varfarina'),
  ('tocilizumabe', 'estatina',     InteractionSeverity.moderate,
    'Bloqueio de IL-6 restaura CYP3A4 — estatinas metabolizadas por CYP3A4 têm metabolismo aumentado',
    'Redução dos níveis plasmáticos de estatinas — menor efeito hipolipemiante',
    'Monitorar perfil lipídico 4–8 semanas após início. Pode ser necessário aumentar dose da estatina'),
  ('baricitinibe', 'ssri',         InteractionSeverity.minor,
    'Inibição do transportador OAT3 pelo baricitinibe pode aumentar levemente concentração de alguns SSRIs',
    'Aumento marginal da exposição a SSRIs renalmente eliminados',
    'Monitorar efeitos adversos dos SSRIs. Interação geralmente não requer ajuste de dose'),

  // ── Vedolizumabe ──────────────────────────────────────────────────────────
  ('vedolizumabe', 'natalizumabe', InteractionSeverity.contraindicated,
    'Ambos são antagonistas de integrinas — imunomodulação aditiva sistêmica e intestinal',
    'Risco muito aumentado de infecções oportunistas e leucoencefalopatia multifocal progressiva (LMP)',
    'Contraindicado — não combinar biológicos anti-integrinas. Washout adequado entre os agentes'),

  // ── Tofacitinibe ──────────────────────────────────────────────────────────
  ('tofacitinibe', 'ciclosporina', InteractionSeverity.contraindicated,
    'Inibição do CYP3A4 + imunossupressão aditiva potente',
    'Infecções oportunistas graves, nefrotoxicidade, linfoma',
    'Contraindicado. Não combinar JAKi com imunossupressores biológicos potentes'),
  ('tofacitinibe', 'fluconazol',   InteractionSeverity.major,
    'Inibição do CYP3A4 e CYP2C19 pelo fluconazol aumenta exposição ao tofacitinibe em ~130%',
    'Toxicidade por tofacitinibe — infecções, trombose, elevação de enzimas hepáticas',
    'Reduzir dose de tofacitinibe para 5 mg 1x/dia durante uso de fluconazol. Monitorar hemograma e transaminases'),
  ('tofacitinibe', 'rifampicina',  InteractionSeverity.major,
    'Rifampicina induz CYP3A4 → redução de ~84% na exposição ao tofacitinibe',
    'Falha terapêutica — concentrações subterapêuticas',
    'Evitar combinação. Se necessário, monitorar atividade da doença de base. Considerar alternativa biológica'),

  // ── Ruxolitinibe ──────────────────────────────────────────────────────────
  ('ruxolitinibe', 'claritromicina', InteractionSeverity.major,
    'Inibição potente do CYP3A4 → aumento de ~200% na exposição ao ruxolitinibe',
    'Citopenia grave (anemia, trombocitopenia), infecções oportunistas, toxicidade hepática',
    'Reduzir dose de ruxolitinibe em 50% durante uso de claritromicina. Monitorar hemograma. Alternativa: azitromicina'),
  ('ruxolitinibe', 'fluconazol',   InteractionSeverity.moderate,
    'Inibição do CYP3A4 aumenta exposição ao ruxolitinibe em ~100%',
    'Citopenia e risco de infecções oportunistas aumentado',
    'Reduzir dose de ruxolitinibe em 50%. Monitorar hemograma frequentemente'),

  // ── Dupilumabe / Biológicos respiratórios ─────────────────────────────────
  ('dupilumabe', 'vacinas vivas',  InteractionSeverity.major,
    'Imunossupressão relativa causada por dupilumabe pode reduzir resposta imunológica a vacinas vivas',
    'Risco de infecção pela cepa vacinal (vacina viva atenuada)',
    'Não administrar vacinas vivas durante uso de dupilumabe. Completar vacinação antes de iniciar biológico'),
  ('mepolizumabe', 'corticosteroide sistemico', InteractionSeverity.moderate,
    'Redução dos eosinófilos pelo mepolizumabe permite desmame dos corticosteroides, mas retirada abrupta causa insuficiência adrenal',
    'Insuficiência adrenal aguda se corticosteroide retirado abruptamente',
    'Desmame LENTO e gradual de corticosteroides sistêmicos — nunca retirar abruptamente. Monitorar sintomas de insuficiência adrenal'),

  // ── Isavuconazol ──────────────────────────────────────────────────────────
  ('isavuconazol', 'rifampicina',  InteractionSeverity.contraindicated,
    'Rifampicina induz CYP3A4 potentemente → redução drástica dos níveis de isavuconazol',
    'Falha terapêutica antifúngica — concentrações subterapêuticas',
    'Contraindicado — combinação invalida o tratamento antifúngico'),
  ('isavuconazol', 'ciclosporina', InteractionSeverity.moderate,
    'Inibição do CYP3A4 pelo isavuconazol aumenta exposição à ciclosporina',
    'Toxicidade por ciclosporina — nefrotoxicidade, neurotoxicidade',
    'Monitorar nível sérico de ciclosporina. Reduzir dose em 25–50% se necessário. Isavuconazol é inibidor CYP3A4 mais fraco que voriconazol'),
  ('isavuconazol', 'warfarina',    InteractionSeverity.moderate,
    'Inibição do CYP2C9 pelo isavuconazol pode aumentar nível de varfarina',
    'Elevação do INR e risco hemorrágico',
    'Monitorar INR a cada 2–3 dias após início e término do isavuconazol. Ajustar dose de varfarina conforme necessário'),

  // ── Eltrombopague ─────────────────────────────────────────────────────────
  ('eltrombopague', 'antiácido',   InteractionSeverity.major,
    'Cátions polivalentes (Al, Mg, Ca) dos antiácidos formam quelatos com eltrombopague no TGI',
    'Redução de até 70% na absorção do eltrombopague → falha terapêutica',
    'Administrar eltrombopague ≥4 horas antes ou ≥2 horas após antiácidos, suplementos de cálcio ou ferro'),
  ('eltrombopague', 'sulfato ferroso', InteractionSeverity.major,
    'Ferro quelata eltrombopague no intestino — redução drástica da absorção',
    'Falha terapêutica da trombocitopoiese',
    'Separar eltrombopague do ferro por pelo menos 4 horas. Tomar eltrombopague em jejum'),
  ('eltrombopague', 'ciclosporina', InteractionSeverity.moderate,
    'Inibição do OATP1B1 e CYP1A2 pelo eltrombopague pode aumentar exposição à ciclosporina',
    'Nefrotoxicidade por aumento do nível de ciclosporina',
    'Monitorar nível sérico de ciclosporina. Ajustar dose conforme necessário'),

  // ── Denosumabe ────────────────────────────────────────────────────────────
  ('denosumabe', 'corticosteroide sistemico', InteractionSeverity.moderate,
    'Ambos aumentam risco de osteonecrose mandibular e fraturas atípicas; corticosteroides causam osteoporose adicional',
    'Risco de osteonecrose mandibular e fraturas ósseas graves',
    'Avaliação odontológica obrigatória antes de iniciar. Garantir reposição adequada de Ca²⁺ e vitamina D. Monitorar DMO'),

  // ── Bupropiona ────────────────────────────────────────────────────────────
  ('bupropiona', 'imao',           InteractionSeverity.contraindicated,
    'Bupropiona inibe recaptação de dopamina/noradrenalina + IMAOs inibem degradação — hiperestimulação adrenérgica e serotoninérgica',
    'Crise hipertensiva, síndrome serotoninérgica, convulsões — risco de morte',
    'Contraindicado. Aguardar ≥14 dias após suspender IMAO antes de iniciar bupropiona'),
  ('bupropiona', 'carbamazepina',  InteractionSeverity.major,
    'Carbamazepina induz CYP3A4/2B6 → redução significativa dos níveis de bupropiona',
    'Falha antidepressiva e no programa de cessação tabágica',
    'Aumentar dose de bupropiona (monitorar efeito). Avaliar alternativa antidepressiva sem interação com indutores CYP'),
  ('bupropiona', 'tramadol',       InteractionSeverity.major,
    'Ambos reduzem o limiar convulsivo por mecanismos independentes — sinergia pró-convulsivante',
    'Risco muito aumentado de convulsões generalizadas',
    'Evitar combinação. Se necessário, usar mínima dose de tramadol com monitoramento neurológico. Considerar analgésico alternativo'),
  ('bupropiona', 'ssri',           InteractionSeverity.moderate,
    'Bupropiona inibe CYP2D6 → aumenta exposição a fluoxetina, paroxetina e outros SSRIs metabolizados por esse CYP',
    'Síndrome serotoninérgica leve a moderada, elevação de efeitos adversos dos SSRIs',
    'Monitorar sinais de excesso serotoninérgico. Considerar redução da dose do SSRI se sintomas surgem'),

  // ── Aripiprazol ───────────────────────────────────────────────────────────
  ('aripiprazol', 'claritromicina', InteractionSeverity.major,
    'Inibição do CYP3A4 pela claritromicina aumenta exposição ao aripiprazol em ~90%',
    'Toxicidade por aripiprazol — acatisia intensa, hipotensão, sedação, convulsões (raro)',
    'Reduzir dose de aripiprazol em 50% durante uso de claritromicina. Monitorar efeitos adversos'),
  ('aripiprazol', 'fluoxetina',    InteractionSeverity.moderate,
    'Fluoxetina inibe CYP2D6 e CYP3A4 → aumento de 100% na exposição ao aripiprazol',
    'Acatisia, sedação excessiva, hipotensão ortostática',
    'Reduzir dose de aripiprazol em 50% com fluoxetina. Monitorar efeitos extrapiramidais e PA'),

  // ── Perampanel ────────────────────────────────────────────────────────────
  ('perampanel', 'carbamazepina',  InteractionSeverity.major,
    'Carbamazepina induz potentemente CYP3A4 → redução de ~67% na exposição ao perampanel',
    'Falha antiepiléptica — concentrações subterapêuticas de perampanel',
    'Triplicar a dose-alvo de perampanel quando em uso com carbamazepina. Titular cuidadosamente com monitoramento clínico'),
  ('perampanel', 'alcool',         InteractionSeverity.major,
    'Perampanel potencializa depressão do SNC pelo álcool; pode aumentar comportamentos agressivos/impulsivos',
    'Sedação grave, comportamento irracional, agressividade, maior risco de acidentes',
    'Contraindicado uso de álcool com perampanel. Orientar paciente explicitamente'),

  // ── Rifaximina ────────────────────────────────────────────────────────────
  ('rifaximina', 'anticoncepcional', InteractionSeverity.minor,
    'Mesmo com absorção mínima, pode alterar flora intestinal que participa da circulação êntero-hepática dos anticoncepcionais',
    'Redução teórica (baixo risco clinicamente) da eficácia anticoncepcional hormonal',
    'Risco muito baixo (absorção <1%). Porém, orientar uso de método contraceptivo de barreira adicional por precaução durante e 7 dias após o curso'),

  // ── Nintedanibe ───────────────────────────────────────────────────────────
  ('nintedanibe', 'warfarina',     InteractionSeverity.moderate,
    'Nintedanibe inibe P-gp e CYP3A4; interação potencial aumentando nível de varfarina',
    'Elevação do INR e risco hemorrágico — intensificado pelo risco de sangramento GI do nintedanibe',
    'Monitorar INR semanalmente. Vigilância redobrada para sinais de sangramento GI'),
  ('nintedanibe', 'rifampicina',   InteractionSeverity.major,
    'Rifampicina induz P-gp e CYP3A4 → redução de ~60% nos níveis de nintedanibe',
    'Falha terapêutica na FPI — progressão da fibrose',
    'Evitar combinação. Se tratamento de TB necessário, avaliar alternativa antifibrótica ou substituição do antimicrobiano'),

  // ── Fondaparinux ──────────────────────────────────────────────────────────
  ('fondaparinux', 'ssri',         InteractionSeverity.moderate,
    'SSRIs inibem função plaquetária (redução de serotonina plaquetária) + anticoagulação do fondaparinux',
    'Risco aumentado de sangramento — especialmente GI',
    'Monitorar sinais de sangramento. Considerar IBP para proteção gástrica em uso combinado'),
  ('fondaparinux', 'aine',         InteractionSeverity.moderate,
    'AINEs inibem função plaquetária e protegem mucosa gástrica — risco hemorrágico aditivo',
    'Sangramento GI e em outros sítios',
    'Evitar AINEs com fondaparinux. Usar paracetamol para analgesia. Se AINE necessário, associar IBP'),

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
  'carbamazepina': 'carbamazepina', 'tegretol': 'carbamazepina',
  'acido valproico': 'acido valproico', 'ácido valpróico': 'acido valproico',
  'valproato': 'acido valproico', 'depakote': 'acido valproico',
  'lamotrigina': 'lamotrigina', 'lamictal': 'lamotrigina',

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
  'candesartana': 'candesartana', 'atacand': 'candesartana', 'candesartán': 'candesartana',
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
