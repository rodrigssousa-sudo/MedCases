import '../models/protocol_model.dart';

const List<ProtocolModel> protocolsDatabase = [
  ProtocolModel(
    id: 'iam_congestao',
    title: {'pt': 'IAM + congestão pulmonar', 'es': 'IAM + congestión pulmonar'},
    severity: {'pt': 'Alto risco', 'es': 'Alto riesgo'},
    recognize: {
      'pt': 'Dor torácica + dispneia, crepitações, hipoxemia ou sinais de Killip. Fazer ECG imediato, SatO2, PA, acesso venoso e troponina.',
      'es': 'Dolor torácico + disnea, crepitantes, hipoxemia o signos de Killip. Realizar ECG inmediato, SatO2, PA, acceso venoso y troponina.',
    },
    actions: {
      'pt': ['Oxigênio se hipoxemia', 'AAS + P2Y12 se SCA provável', 'Anticoagulação conforme estratégia', 'Nitroglicerina se PA permite', 'Furosemida IV se congestão', 'Reperfusão urgente se IAM com supra'],
      'es': ['Oxígeno si hipoxemia', 'AAS + P2Y12 si SCA probable', 'Anticoagulación según estrategia', 'Nitroglicerina si PA permite', 'Furosemida IV si congestión', 'Reperfusión urgente si IAM con supra'],
    },
    avoid: {
      'pt': 'Evitar nitrato se hipotensão, suspeita de infarto de VD ou uso recente de sildenafil/tadalafil.',
      'es': 'Evitar nitrato si hipotensión, sospecha de infarto de VD o uso reciente de sildenafil/tadalafil.',
    },
    drugs: ['aas', 'clopidogrel', 'heparina_nf', 'nitroglicerina', 'furosemida', 'noradrenalina', 'dobutamina'],
  ),
  ProtocolModel(
    id: 'choque_cardiogenico',
    title: {'pt': 'Choque cardiogênico', 'es': 'Shock cardiogénico'},
    severity: {'pt': 'Crítico', 'es': 'Crítico'},
    recognize: {
      'pt': 'Hipotensão ou hipoperfusão com pele fria, oligúria, confusão, lactato alto, baixo débito e/ou congestão pulmonar.',
      'es': 'Hipotensión o hipoperfusión con piel fría, oliguria, confusión, lactato alto, bajo gasto y/o congestión pulmonar.',
    },
    actions: {
      'pt': ['ABCDE', 'Oxigênio/ventilação se necessário', 'Noradrenalina se PAM baixa', 'Dobutamina se baixo débito', 'Tratar causa: IAM, arritmia, valva, tamponamento', 'Considerar suporte mecânico se refratário'],
      'es': ['ABCDE', 'Oxígeno/ventilación si necesario', 'Noradrenalina si PAM baja', 'Dobutamina si bajo gasto', 'Tratar causa: IAM, arritmia, válvula, taponamiento', 'Considerar soporte mecánico si refractario'],
    },
    avoid: {
      'pt': 'Não dar volume em excesso se congesto. Milrinona/levosimendana podem piorar hipotensão.',
      'es': 'No dar volumen en exceso si congestivo. Milrinona/levosimendán pueden empeorar hipotensión.',
    },
    drugs: ['noradrenalina', 'dobutamina', 'furosemida'],
  ),
  ProtocolModel(
    id: 'anafilaxia',
    title: {'pt': 'Anafilaxia / choque anafilático', 'es': 'Anafilaxia / shock anafiláctico'},
    severity: {'pt': 'Crítico', 'es': 'Crítico'},
    recognize: {
      'pt': 'Exposição + urticária/angioedema, broncoespasmo, hipotensão, vômitos ou edema de via aérea.',
      'es': 'Exposición + urticaria/angioedema, broncoespasmo, hipotensión, vómitos o edema de vía aérea.',
    },
    actions: {
      'pt': ['Adrenalina IM na coxa imediatamente', 'ABCDE e oxigênio', 'Cristaloide se hipotensão', 'Nebulização se broncoespasmo', 'Anti-H1/corticoide apenas como adjuvantes'],
      'es': ['Adrenalina IM en muslo inmediatamente', 'ABCDE y oxígeno', 'Cristaloide si hipotensión', 'Nebulización si broncoespasmo', 'Anti-H1/corticoide solo como adyuvantes'],
    },
    avoid: {
      'pt': 'Erro clássico: atrasar adrenalina e tratar só com anti-histamínico/corticoide.',
      'es': 'Error clásico: retrasar adrenalina y tratar solo con antihistamínico/corticoide.',
    },
    drugs: ['adrenalina'],
  ),
  ProtocolModel(
    id: 'tpsv',
    title: {'pt': 'TPSV regular estreita', 'es': 'TPSV regular estrecha'},
    severity: {'pt': 'Moderado/Alto', 'es': 'Moderado/Alto'},
    recognize: {
      'pt': 'Taquicardia regular de QRS estreito. Primeiro separar estável versus instável.',
      'es': 'Taquicardia regular de QRS estrecho. Primero separar estable versus inestable.',
    },
    actions: {
      'pt': ['Instável: cardioversão sincronizada', 'Estável: manobra vagal', 'Adenosina IV rápida com flush', 'Registrar ECG antes/depois se possível'],
      'es': ['Inestable: cardioversión sincronizada', 'Estable: maniobra vagal', 'Adenosina IV rápida con flush', 'Registrar ECG antes/después si posible'],
    },
    avoid: {
      'pt': 'Cuidado em asma grave. Se QRS largo ou dúvida diagnóstica, tratar como taquicardia de maior risco.',
      'es': 'Cuidado en asma grave. Si QRS ancho o duda diagnóstica, tratar como taquicardia de mayor riesgo.',
    },
    drugs: ['adenosina', 'amiodarona'],
  ),
  ProtocolModel(
    id: 'tep_instavel',
    title: {'pt': 'TEP com instabilidade', 'es': 'TEP con inestabilidad'},
    severity: {'pt': 'Crítico', 'es': 'Crítico'},
    recognize: {
      'pt': 'Dispneia/dor torácica/síncope + hipotensão, choque, hipoxemia ou disfunção de VD.',
      'es': 'Disnea/dolor torácico/síncope + hipotensión, shock, hipoxemia o disfunción de VD.',
    },
    actions: {
      'pt': ['ABCDE e oxigênio', 'Noradrenalina se choque', 'Heparina não fracionada', 'Considerar trombólise/reperfusão se choque e sem contraindicação', 'Eco/angioTC conforme estabilidade'],
      'es': ['ABCDE y oxígeno', 'Noradrenalina si shock', 'Heparina no fraccionada', 'Considerar trombólisis/reperfusión si shock y sin contraindicación', 'Eco/angioTC según estabilidad'],
    },
    avoid: {
      'pt': 'Não tratar TEP em choque como TEP estável. DOAC não é primeira decisão no choque.',
      'es': 'No tratar TEP en shock como TEP estable. DOAC no es primera decisión en shock.',
    },
    drugs: ['heparina_nf', 'noradrenalina'],
  ),
  ProtocolModel(
    id: 'tvp_tep_estavel',
    title: {'pt': 'TVP / TEP estável', 'es': 'TVP / TEP estable'},
    severity: {'pt': 'Anticoagulação', 'es': 'Anticoagulación'},
    recognize: {
      'pt': 'Suspeita clínica ou confirmação de TVP/TEP sem choque, sem hipotensão persistente e sem contraindicação absoluta a anticoagulação.',
      'es': 'Sospecha clínica o confirmación de TVP/TEP sin shock, sin hipotensión persistente y sin contraindicación absoluta a anticoagulación.',
    },
    actions: {
      'pt': ['DOAC se elegível', 'HBPM/HNF em gestação, DRC grave, instabilidade ou procedimento próximo', 'Avaliar risco de sangramento', 'Definir duração conforme fator provocador/recorrência'],
      'es': ['DOAC si elegible', 'HBPM/HNF en embarazo, ERC grave, inestabilidad o procedimiento próximo', 'Evaluar riesgo de sangrado', 'Definir duración según factor provocador/recurrencia'],
    },
    avoid: {
      'pt': 'TEP com choque é outro cenário: HNF + considerar reperfusão.',
      'es': 'TEP con shock es otro escenario: HNF + considerar reperfusión.',
    },
    drugs: ['rivaroxabana', 'apixabana', 'enoxaparina', 'heparina_nf'],
  ),
  ProtocolModel(
    id: 'hipercalemia',
    title: {'pt': 'Hipercalemia grave', 'es': 'Hiperpotasemia grave'},
    severity: {'pt': 'Crítico', 'es': 'Crítico'},
    recognize: {
      'pt': 'K+ alto ou suspeita com DRC, IECA/BRA/MRA, fraqueza, bradicardia ou alterações no ECG.',
      'es': 'K+ alto o sospecha con ERC, IECA/ARA II/ARM, debilidad, bradicardia o alteraciones en ECG.',
    },
    actions: {
      'pt': ['ECG imediato', 'Cálcio IV se alteração no ECG', 'Insulina regular + glicose', 'Beta-agonista', 'Remover K+: diurético/resina/diálise conforme caso'],
      'es': ['ECG inmediato', 'Calcio IV si alteración en ECG', 'Insulina regular + glucosa', 'Beta-agonista', 'Remover K+: diurético/resina/diálisis según caso'],
    },
    avoid: {
      'pt': 'Cálcio protege o coração, mas não remove potássio. Sempre fazer deslocamento/remoção.',
      'es': 'Calcio protege el corazón, pero no remueve potasio. Siempre hacer desplazamiento/remoción.',
    },
    drugs: ['insulina_regular', 'furosemida'],
  ),
  ProtocolModel(
    id: 'cetoacidose_diabetica',
    title: {'pt': 'Cetoacidose diabética', 'es': 'Cetoacidosis diabética'},
    severity: {'pt': 'Alto risco', 'es': 'Alto riesgo'},
    recognize: {
      'pt': 'Hiperglicemia + cetose + acidose/ânion gap. Procurar gatilho: infecção, IAM, omissão de insulina.',
      'es': 'Hiperglucemia + cetosis + acidosis/anión gap. Buscar disparador: infección, IAM, omisión de insulina.',
    },
    actions: {
      'pt': ['Cristaloide', 'Checar K+ antes da insulina', 'Insulina regular IV se K+ permite', 'Dextrose quando glicose cair com gap aberto', 'Tratar gatilho'],
      'es': ['Cristaloide', 'Verificar K+ antes de insulina', 'Insulina regular IV si K+ permite', 'Dextrosa cuando glucosa baja con gap abierto', 'Tratar disparador'],
    },
    avoid: {
      'pt': 'Nunca iniciar insulina com K+ muito baixo sem reposição: risco de arritmia fatal.',
      'es': 'Nunca iniciar insulina con K+ muy bajo sin reposición: riesgo de arritmia fatal.',
    },
    drugs: ['insulina_regular'],
  ),
  ProtocolModel(
    id: 'choque_septico',
    title: {'pt': 'Choque séptico', 'es': 'Shock séptico'},
    severity: {'pt': 'Crítico', 'es': 'Crítico'},
    recognize: {
      'pt': 'Infecção suspeita + hipotensão, lactato alto, oligúria, confusão ou pele moteada.',
      'es': 'Infección sospechada + hipotensión, lactato alto, oliguria, confusión o piel moteada.',
    },
    actions: {
      'pt': ['Culturas se não atrasar', 'Antibiótico precoce', 'Cristaloide se hipoperfusão', 'Noradrenalina para PAM alvo', 'Controle de foco'],
      'es': ['Cultivos si no retrasa', 'Antibiótico precoz', 'Cristaloide si hipoperfusión', 'Noradrenalina para PAM objetivo', 'Control del foco'],
    },
    avoid: {
      'pt': 'Não esperar todos os exames para iniciar antibiótico se choque provável.',
      'es': 'No esperar todos los estudios para iniciar antibiótico si shock probable.',
    },
    drugs: ['noradrenalina', 'ceftriaxona', 'vancomicina'],
  ),
  ProtocolModel(
    id: 'dor_pos_operatoria',
    title: {'pt': 'Dor pós-operatória', 'es': 'Dolor posoperatorio'},
    severity: {'pt': 'Risco variável', 'es': 'Riesgo variable'},
    recognize: {
      'pt': 'Dor pós-operatória leve, moderada ou intensa; avaliar sangramento, rim, fígado, sedação e tipo de cirurgia.',
      'es': 'Dolor posoperatorio leve, moderado o intenso; evaluar sangrado, riñón, hígado, sedación y tipo de cirugía.',
    },
    actions: {
      'pt': ['Dor leve: paracetamol/dipirona', 'Dor moderada: associar tramadol com cautela', 'Dor intensa: opioide titulado', 'AINE só se risco renal/hemorrágico baixo'],
      'es': ['Dolor leve: paracetamol/dipirona', 'Dolor moderado: asociar tramadol con cautela', 'Dolor intenso: opioide titulado', 'AINE solo si bajo riesgo renal/hemorrágico'],
    },
    avoid: {
      'pt': 'Em alcoolismo/cirurgia retal, cuidado com paracetamol em dose alta, AINE por sangramento/rim e opioide por sedação.',
      'es': 'En alcoholismo/cirugía rectal, cuidado con paracetamol en dosis alta, AINE por sangrado/riñón y opioide por sedación.',
    },
    drugs: ['paracetamol', 'dipirona', 'morfina', 'cetorolaco', 'pregabalina'],
  ),
];
