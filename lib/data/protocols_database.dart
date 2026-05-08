import '../models/protocol_model.dart';

/// Base de protocolos clínicos MedCases Pro
/// Fontes: AHA/ACC, ESC, SCCM, Surviving Sepsis Campaign, SBN, SBH,
/// Harrison's Principles (21ª ed.), UpToDate, Micromedex.
const List<ProtocolModel> protocolsDatabase = [

  // ─────────────────────────────────────────────
  //  CARDIOVASCULAR
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'iam_congestao',
    title: {'pt': 'IAM + Congestão Pulmonar (Killip II–IV)', 'es': 'IAM + Congestión Pulmonar (Killip II–IV)'},
    severity: {'pt': 'Alto', 'es': 'Alto'},
    recognize: {
      'pt': 'Dor torácica + dispneia + crepitações pulmonares + hipoxemia. ECG: IAMCSST ou IAMSSST. Sinais Killip: B3, estertores, edema agudo.',
      'es': 'Dolor torácico + disnea + crepitantes pulmonares + hipoxemia. ECG: IAMCEST o IAMSEST. Signos Killip: B3, estertores, edema agudo.',
    },
    actions: {
      'pt': [
        '1. O2 se SpO2 <90%: máscara 5–10 L/min ou VNI (CPAP/BiPAP) se EAP',
        '2. AAS 300 mg VO mastigar + Inibidor P2Y12 (ticagrelor 180 mg ou prasugrel 60 mg se ICP)',
        '3. Anticoagulação: HNF 60–70 UI/kg IV (máx. 5000 UI) + infusão',
        '4. Nitroglicerina 5–10 µg/min IV se PA >90 mmHg (EVITAR se VD, hipotensão, PDE5)',
        '5. Furosemida 40–80 mg IV se EAP/congestão evidente',
        '6. Morfina 2–4 mg IV se dor intensa refratária (usar com cautela — reduz PA)',
        '7. REPERFUSÃO URGENTE: ICP primária <90 min (meta; fibrinólise se indisponível <120 min)',
        '8. Monitorar ECG, PA, SpO2, diurese e sódio'
      ],
      'es': [
        '1. O2 si SpO2 <90%: mascarilla 5–10 L/min o VNI (CPAP/BiPAP) si EAP',
        '2. AAS 300 mg VO masticar + Inhibidor P2Y12 (ticagrelor 180 mg o prasugrel 60 mg si ICP)',
        '3. Anticoagulación: HNF 60–70 UI/kg IV (máx. 5000 UI) + infusión',
        '4. Nitroglicerina 5–10 µg/min IV si PA >90 mmHg (EVITAR en VD, hipotensión, PDE5)',
        '5. Furosemida 40–80 mg IV si EAP/congestión evidente',
        '6. Morfina 2–4 mg IV si dolor intenso refractario (usar con cautela)',
        '7. REPERFUSIÓN URGENTE: ICP primaria <90 min (meta; fibrinólisis si no disponible <120 min)',
        '8. Monitorizar ECG, PA, SpO2, diuresis y sodio'
      ],
    },
    avoid: {
      'pt': 'EVITAR nitratos se PA <90 mmHg, IAM de VD ou uso recente de PDE5 (sildenafil/tadalafil). Evitar betabloqueador IV na fase aguda com congestão/hipotensão/BAV.',
      'es': 'EVITAR nitratos si PA <90 mmHg, IAM de VD o uso reciente de PDE5. Evitar betabloqueador IV en fase aguda con congestión/hipotensión/BAV.',
    },
    drugs: ['aas', 'clopidogrel', 'heparina_nf', 'nitroglicerina', 'furosemida', 'morfina', 'noradrenalina', 'dobutamina'],
  ),

  ProtocolModel(
    id: 'choque_cardiogenico',
    title: {'pt': 'Choque Cardiogênico', 'es': 'Choque Cardiogénico'},
    severity: {'pt': 'Crítico', 'es': 'Crítico'},
    recognize: {
      'pt': 'PA sistólica <90 mmHg (ou queda ≥40 mmHg) por ≥30 min + sinais de hipoperfusão: pele fria/úmida, oligúria, confusão, lactato >2 mmol/L, ausência de hipovolemia.',
      'es': 'PA sistólica <90 mmHg (o caída ≥40 mmHg) por ≥30 min + signos de hipoperfusión: piel fría/húmeda, oliguria, confusión, lactato >2 mmol/L.',
    },
    actions: {
      'pt': [
        '1. ABCDE; O2 alto fluxo; intubação se necessário (evitar se possível — piora prognóstico)',
        '2. Noradrenalina: 0,1–0,5 µg/kg/min IV (PAM alvo ≥65 mmHg) — vasopressor de 1ª linha',
        '3. Se baixo débito cardíaco com PA razoável: dobutamina 2,5–10 µg/kg/min IV',
        '4. Tratar causa subjacente: IAM → reperfusão urgente (ICP), arritmia → cardioversão, tamponamento → pericardiocentese',
        '5. Volume (cristaloide) com parcimônia: 250 mL bolus se sinais de hipovolemia confirmados',
        '6. Monitorar lactato, débito urinário, PA invasiva, SvO2 ou ScvO2',
        '7. Considerar suporte mecânico (IABP, Impella) se refratário',
        '8. UTI obrigatória; cateterismo de emergência se IAM subjacente'
      ],
      'es': [
        '1. ABCDE; O2 alto flujo; intubación si necesario',
        '2. Noradrenalina: 0,1–0,5 µg/kg/min IV (PAM objetivo ≥65 mmHg) — vasopresor de 1ª línea',
        '3. Si bajo gasto cardíaco con PA razonable: dobutamina 2,5–10 µg/kg/min IV',
        '4. Tratar causa subyacente: IAM → reperfusión urgente, arritmia → cardioversión, taponamiento → pericardiocentesis',
        '5. Volumen (cristaloide) con parsimonia: 250 mL bolo si hipovolemia confirmada',
        '6. Monitorar lactato, diuresis, PA invasiva, SvO2 o ScvO2',
        '7. Considerar soporte mecánico (IABP, Impella) si refractario',
        '8. UCI obligatoria; cateterismo de emergencia si IAM subyacente'
      ],
    },
    avoid: {
      'pt': 'EVITAR volume excessivo (piora congestão). Evitar dobutamina isolada se PA baixa (pode piorar hipotensão). Não usar nitroprussiato sem suporte vasopressor.',
      'es': 'EVITAR volumen excesivo. Evitar dobutamina aislada si PA baja. No usar nitroprusiato sin soporte vasopresor.',
    },
    drugs: ['noradrenalina', 'dobutamina', 'adrenalina', 'furosemida', 'heparina_nf'],
  ),

  ProtocolModel(
    id: 'anafilaxia',
    title: {'pt': 'Anafilaxia / Choque Anafilático', 'es': 'Anafilaxia / Choque Anafiláctico'},
    severity: {'pt': 'Crítico', 'es': 'Crítico'},
    recognize: {
      'pt': 'Exposição a alérgeno + urticária/angioedema + broncoespasmo + hipotensão/colapso circulatório + vômito. Início em segundos a minutos.',
      'es': 'Exposición a alérgeno + urticaria/angioedema + broncoespasmo + hipotensión/colapso circulatorio + vómito.',
    },
    actions: {
      'pt': [
        '1. ADRENALINA 0,3–0,5 mg IM na coxa lateral (IMEDIATAMENTE — 1ª linha absoluta)',
        '2. Deitar paciente; elevar MMII se hipotensão (Trendelenburg)',
        '3. O2 alto fluxo: 10–15 L/min por máscara com reservatório',
        '4. Acesso venoso: SF 0,9% 1–2 L IV rápido se hipotensão',
        '5. Se broncoespasmo: salbutamol nebulização 5 mg (+ adrenalina IM se grave)',
        '6. Se sem resposta: Adrenalina IV 0,1–0,5 mg em bolus diluído ou 0,1 µg/kg/min em infusão',
        '7. Difenidramina 25–50 mg IV (anti-H1 — adjuvante, não substitui adrenalina)',
        '8. Metilprednisolona 125 mg IV (adjuvante para reação bifásica)',
        '9. Observação 4–8h mínimo (reação bifásica em 20% dos casos)'
      ],
      'es': [
        '1. ADRENALINA 0,3–0,5 mg IM en muslo lateral (INMEDIATAMENTE — 1ª línea absoluta)',
        '2. Acostar paciente; elevar MMII si hipotensión',
        '3. O2 alto flujo: 10–15 L/min por mascarilla con reservorio',
        '4. Acceso venoso: SF 0,9% 1–2 L IV rápido si hipotensión',
        '5. Si broncoespasmo: salbutamol nebulización 5 mg',
        '6. Si sin respuesta: Adrenalina IV 0,1–0,5 mg bolo diluido o 0,1 µg/kg/min infusión',
        '7. Difenhidramina 25–50 mg IV (anti-H1 — adyuvante, no sustituye adrenalina)',
        '8. Metilprednisolona 125 mg IV (adyuvante para reacción bifásica)',
        '9. Observación 4–8 h mínimo (reacción bifásica en 20% de los casos)'
      ],
    },
    avoid: {
      'pt': 'NUNCA atrasar adrenalina IM. Anti-histamínico e corticoide NÃO substituem adrenalina. Evitar posição sentada/de pé se hipotensão. Não dar alta precoce (risco bifásico).',
      'es': 'NUNCA retrasar adrenalina IM. Antihistamínico y corticoide NO sustituyen adrenalina. Evitar posición sentada/de pie si hipotensión.',
    },
    drugs: ['adrenalina', 'salbutamol', 'metilprednisolona'],
  ),

  ProtocolModel(
    id: 'tpsv',
    title: {'pt': 'Taquicardia Paroxística Supraventricular (TPSV)', 'es': 'Taquicardia Paroxística Supraventricular (TPSV)'},
    severity: {'pt': 'Médio', 'es': 'Medio'},
    recognize: {
      'pt': 'Taquicardia regular de complexo estreito (FC 150–250 bpm) com início/fim súbito. Pode causar palpitação, tontura, pré-síncope, dispneia leve.',
      'es': 'Taquicardia regular de complejo estrecho (FC 150–250 lpm) con inicio/fin súbito. Puede causar palpitación, mareo, presíncope.',
    },
    actions: {
      'pt': [
        '1. ECG 12 derivações (documentar arritmia)',
        '2. Manobras vagais: Valsalva modificado (decúbito dorsal, soprar seringa 10 mL por 15 s + elevação de MMII) — 1ª linha (reversão 40–50%)',
        '3. Adenosina 6 mg IV bolus rápido + flush 20 mL SF; se sem resposta em 2 min: 12 mg; 3ª dose: 12 mg',
        '4. Se sem resposta: Verapamil 5–10 mg IV lento (2 min) ou Diltiazem 20 mg IV',
        '5. Se instabilidade hemodinâmica: Cardioversão sincronizada 50–100 J',
        '6. Monitorar ECG e PA durante tratamento',
        '7. Investigar causa: hipertireoidismo, WPW (evitar verapamil em WPW), pré-excitação'
      ],
      'es': [
        '1. ECG 12 derivaciones (documentar arritmia)',
        '2. Maniobras vagales: Valsalva modificado (decúbito dorsal, soplar jeringa 10 mL × 15 s + elevación de MMII) — 1ª línea',
        '3. Adenosina 6 mg IV bolo rápido + flush 20 mL SF; si sin respuesta en 2 min: 12 mg; 3ª dosis: 12 mg',
        '4. Si sin respuesta: Verapamil 5–10 mg IV lento (2 min) o Diltiazem 20 mg IV',
        '5. Si inestabilidad hemodinámica: Cardioversión sincronizada 50–100 J',
        '6. Monitorizar ECG y PA durante tratamiento',
        '7. Investigar causa: hipertiroidismo, WPW (evitar verapamil en WPW)'
      ],
    },
    avoid: {
      'pt': 'EVITAR verapamil em WPW (pode precipitar FV). Evitar adenosina em asma/DPOC grave (broncoespasmo). Não usar verapamil + betabloqueador IV (bloqueio AV grave).',
      'es': 'EVITAR verapamil en WPW (puede precipitar FV). Evitar adenosina en asma/EPOC grave.',
    },
    drugs: ['amiodarona', 'metoprolol'],
  ),

  ProtocolModel(
    id: 'fa_aguda',
    title: {'pt': 'Fibrilação Atrial de Início Recente (<48h)', 'es': 'Fibrilación Auricular de Inicio Reciente (<48 h)'},
    severity: {'pt': 'Médio', 'es': 'Medio'},
    recognize: {
      'pt': 'Taquicardia irregular de início abrupto <48h. Ausência de onda P, intervalo RR irregular. FC variável. Pode causar: palpitação, dispneia, síncope, IC aguda.',
      'es': 'Taquicardia irregular de inicio abrupto <48 h. Ausencia de onda P, intervalo RR irregular. FC variable.',
    },
    actions: {
      'pt': [
        '1. ECG 12 derivações para confirmar FA',
        '2. Avaliar estabilidade: se instável (hipotensão, sinais de IC aguda, isquemia) → Cardioversão elétrica sincronizada imediata 120–200 J',
        '3. Se estável: controle de FC com Metoprolol 5 mg IV lento (3×) ou Diltiazem 20 mg IV',
        '4. Cardioversão química se <48h e hemodinâmica estável: Amiodarona 150 mg IV em 10 min + infusão, ou Propafenona (sem cardiopatia estrutural)',
        '5. Anticoagulação: HNF ou HBPM imediata se cardioversão planejada; ou rivaroxabana/dabigatrana',
        '6. Avaliar CHA2DS2-VASc para decisão de anticoagulação crônica',
        '7. Investigar causa: hipertireoidismo, HAS, IC, álcool, embolia pulmonar'
      ],
      'es': [
        '1. ECG 12 derivaciones para confirmar FA',
        '2. Evaluar estabilidad: si inestable → Cardioversión eléctrica sincronizada inmediata 120–200 J',
        '3. Si estable: control de FC con Metoprolol 5 mg IV lento (3×) o Diltiazem 20 mg IV',
        '4. Cardioversión química si <48 h y estable: Amiodarona 150 mg IV en 10 min + infusión',
        '5. Anticoagulación: HNF o HBPM inmediata si cardioversión planeada',
        '6. Evaluar CHA2DS2-VASc para decisión de anticoagulación crónica',
        '7. Investigar causa: hipertiroidismo, HAS, IC, alcohol, embolia pulmonar'
      ],
    },
    avoid: {
      'pt': 'EVITAR cardioversão sem anticoagulação se >48h (risco de tromboembolia). Evitar verapamil/diltiazem na disfunção sistólica grave. Não usar propafenona em cardiopatia estrutural.',
      'es': 'EVITAR cardioversión sin anticoagulación si >48 h. Evitar verapamil/diltiazem en disfunción sistólica grave.',
    },
    drugs: ['metoprolol', 'amiodarona', 'heparina_nf', 'enoxaparina'],
  ),

  ProtocolModel(
    id: 'crise_hipertensiva',
    title: {'pt': 'Crise Hipertensiva — Urgência e Emergência', 'es': 'Crisis Hipertensiva — Urgencia y Emergencia'},
    severity: {'pt': 'Alto', 'es': 'Alto'},
    recognize: {
      'pt': 'PA muito elevada (geralmente >180/120 mmHg). URGÊNCIA: sem lesão aguda de órgão-alvo (LOA). EMERGÊNCIA: com LOA (encefalopatia, EAP, AVC, IAM, dissecção aórtica, eclampsia).',
      'es': 'PA muy elevada (generalmente >180/120 mmHg). URGENCIA: sin lesión aguda de órgano diana. EMERGENCIA: con lesión de órgano diana.',
    },
    actions: {
      'pt': [
        '1. Confirmar leitura da PA (repouso 5 min, ambos os braços)',
        '2. URGÊNCIA (sem LOA): redução gradual em 24–48h VO. Captopril 25 mg SL/VO, Clonidina 0,1–0,2 mg VO, Amlodipina 5 mg VO',
        '3. EMERGÊNCIA (com LOA): internação em UTI + acesso venoso central',
        '4. Nitroprussiato de Na: 0,5–10 µg/kg/min IV (crise HAS grave, dissecção). Reduzir PA 10–20% na 1ª hora, não mais que 25%',
        '5. Labetalol IV: 20 mg em 2 min, repetir 40–80 mg a cada 10 min (máx. 300 mg) — preferido em AVC hemorrágico, gravidez',
        '6. Nicardipina IV: 5–15 mg/h IV — preferido em AVC isquêmico, eclampsia',
        '7. Se AVC isquêmico: meta PA <185/110 mmHg antes de trombolítico',
        '8. Se dissecção aórtica: meta PAS <120 mmHg + FC <60 (labetalol + nitroprussiato)',
        '9. Eclampsia: Sulfato de Mg 4–6 g IV + hidralazina ou labetalol'
      ],
      'es': [
        '1. Confirmar lectura de PA (reposo 5 min, ambos brazos)',
        '2. URGENCIA (sin lesión): reducción gradual en 24–48 h VO. Captopril 25 mg SL/VO',
        '3. EMERGENCIA (con lesión): ingreso UCI + acceso venoso central',
        '4. Nitroprusiato de Na: 0,5–10 µg/kg/min IV. Reducir PA 10–20% en 1ª hora, no más del 25%',
        '5. Labetalol IV: 20 mg en 2 min, repetir 40–80 mg cada 10 min — preferido en AVC hemorrágico, embarazo',
        '6. Nicardipina IV: 5–15 mg/h IV — preferido en AVC isquémico, eclampsia',
        '7. Si AVC isquémico: meta PA <185/110 mmHg antes de trombolítico',
        '8. Si disección aórtica: meta PAS <120 mmHg + FC <60'
      ],
    },
    avoid: {
      'pt': 'EVITAR redução agressiva/rápida de PA (risco de isquemia cerebral/renal/coronária). Não usar nifedipina sublingual (redução imprevisível). Evitar nitroprussiato por >24–48h (toxicidade por tiocianato).',
      'es': 'EVITAR reducción agresiva/rápida de PA. No usar nifedipina sublingual. Evitar nitroprusiato por >24–48 h.',
    },
    drugs: ['enalapril', 'furosemida', 'metoprolol', 'nitroglicerina'],
  ),

  // ─────────────────────────────────────────────
  //  NEUROLÓGICO
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'avc_isquemico',
    title: {'pt': 'AVC Isquêmico Agudo — Protocolo de Reperfusão', 'es': 'AVC Isquémico Agudo — Protocolo de Reperfusión'},
    severity: {'pt': 'Crítico', 'es': 'Crítico'},
    recognize: {
      'pt': 'Déficit neurológico focal de início súbito (hemiplegia, afasia, hemianopsia, ataxia, desvio do olhar). NIHSS para quantificar. Tempo é CÉREBRO.',
      'es': 'Déficit neurológico focal de inicio súbito (hemiplejía, afasia, hemianopsia, ataxia). NIHSS para cuantificar. El tiempo es CEREBRO.',
    },
    actions: {
      'pt': [
        '1. TEMPO: "Call to needle" <60 min; AVC code ativo',
        '2. Glicemia imediata (corrigir hipoglicemia <60 mg/dL antes de qualquer decisão)',
        '3. TC crânio sem contraste URGENTE (excluir hemorragia)',
        '4. Exames: hemograma, coagulação, eletrólitos, ECG, SpO2',
        '5. O2 se SpO2 <94%; controle glicêmico (alvo 140–180 mg/dL)',
        '6. TROMBOLÍTICO (alteplase): 0,9 mg/kg IV (máx. 90 mg); 10% em bolus, 90% em 60 min. Janela: <4,5h dos sintomas. Verificar CONTRAINDICAÇÕES',
        '7. TROMBECTOMIA MECÂNICA: oclusão de grande vaso + <24h selecionados (ASPECTS ≥6)',
        '8. Controle de PA: se alteplase planejado: manter <185/110. Se sem alteplase: tratar apenas se >220/120',
        '9. Internação em Unidade de AVC (reduz mortalidade e sequelas)',
        '10. AAS 300 mg VO (se sem trombolítico e >24h do evento) + estatina'
      ],
      'es': [
        '1. TIEMPO: "Call to needle" <60 min; código AVC activo',
        '2. Glucemia inmediata (corregir hipoglucemia <60 mg/dL)',
        '3. TC cráneo sin contraste URGENTE (excluir hemorragia)',
        '4. Exámenes: hemograma, coagulación, electrolitos, ECG, SpO2',
        '5. O2 si SpO2 <94%; control glucémico (objetivo 140–180 mg/dL)',
        '6. TROMBOLÍTICO (alteplase): 0,9 mg/kg IV (máx. 90 mg); ventana: <4,5 h',
        '7. TROMBECTOMÍA MECÁNICA: oclusión de gran vaso + <24 h seleccionados',
        '8. Control de PA: si alteplase planeado: mantener <185/110',
        '9. Internación en Unidad de AVC',
        '10. AAS 300 mg VO (si sin trombolítico y >24 h del evento) + estatina'
      ],
    },
    avoid: {
      'pt': 'NUNCA dar alteplase sem excluir hemorragia (TC). Contraindicações absolutas alteplase: sangramento recente, cirurgia <14 dias, INR >1,7, plaquetas <100.000. Não hiperhidratar. Evitar febre (piora neurológica).',
      'es': 'NUNCA dar alteplase sin excluir hemorragia. Contraindicaciones absolutas alteplase: sangrado reciente, cirugía <14 días, INR >1,7, plaquetas <100.000.',
    },
    drugs: ['heparina_nf', 'enoxaparina'],
  ),

  ProtocolModel(
    id: 'avc_hemorragico',
    title: {'pt': 'AVC Hemorrágico (Hemorragia Intracerebral)', 'es': 'AVC Hemorrágico (Hemorragia Intracerebral)'},
    severity: {'pt': 'Crítico', 'es': 'Crítico'},
    recognize: {
      'pt': 'Déficit neurológico focal + TC mostrando hiperdensidade intracerebral. Frequentemente associado a HAS grave, anticoagulação, TCE. Cefaleia intensa, vômitos, rebaixamento de consciência.',
      'es': 'Déficit neurológico focal + TC mostrando hiperdensidad intracerebral. Frecuentemente asociado a HAS grave, anticoagulación, TCE.',
    },
    actions: {
      'pt': [
        '1. ABCDE; O2; monitorização contínua (ECG, PA, SpO2)',
        '2. Intubação se Glasgow ≤8 ou comprometimento de via aérea',
        '3. Controle de PA: alvo PAS 130–150 mmHg (AHA 2022). Labetalol IV ou Nicardipina IV',
        '4. Reverter anticoagulação se presente: Vitamina K + CCP (4 fatores) para varfarina; Andexanet alfa/Idarucizumabe para NOAC',
        '5. Manitol 20%: 0,5–1 g/kg IV (20 min) se herniação/edema cerebral (HIC intracraniana)',
        '6. Hiperventilação transitória (PCO2 30–35 mmHg) se herniação iminente',
        '7. Cabeceira 30°; controle glicêmico; antiepiléticos se convulsão',
        '8. Avaliação neurocirúrgica: considerar evacuação cirúrgica (hematoma cerebelar, hidrocefalia)',
        '9. Transferir para UTI com monitoração neurológica contínua'
      ],
      'es': [
        '1. ABCDE; O2; monitorización continua',
        '2. Intubación si Glasgow ≤8 o compromiso de vía aérea',
        '3. Control de PA: objetivo PAS 130–150 mmHg. Labetalol IV o Nicardipina IV',
        '4. Revertir anticoagulación: Vitamina K + CCP (4 factores) para warfarina; Andexanet/Idarucizumab para NOAC',
        '5. Manitol 20%: 0,5–1 g/kg IV (20 min) si herniación/edema cerebral',
        '6. Hiperventilación transitoria (PCO2 30–35 mmHg) si herniación inminente',
        '7. Cabecera 30°; control glucémico; antiepilépticos si convulsión',
        '8. Evaluación neuroquirúrgica',
        '9. UCI con monitorización neurológica continua'
      ],
    },
    avoid: {
      'pt': 'CONTRAINDICADO trombolítico, anticoagulantes e antiagregantes na fase aguda. Evitar hipotensão excessiva (piora perfusão perilesional). Evitar glicose >180 mg/dL.',
      'es': 'CONTRAINDICADO trombolítico, anticoagulantes y antiagregantes en fase aguda. Evitar hipotensión excesiva. Evitar glucosa >180 mg/dL.',
    },
    drugs: ['dexametasona', 'metoprolol', 'levetiracetam', 'fenitoina'],
  ),

  ProtocolModel(
    id: 'status_epilepticus',
    title: {'pt': 'Status Epilepticus Convulsivo', 'es': 'Status Epiléptico Convulsivo'},
    severity: {'pt': 'Crítico', 'es': 'Crítico'},
    recognize: {
      'pt': 'Convulsão contínua ≥5 min OU 2 crises sem recuperação da consciência. Emergência neurológica — risco de morte e lesão neuronal permanente após 30 min.',
      'es': 'Convulsión continua ≥5 min O 2 crisis sin recuperación de consciencia. Emergencia neurológica.',
    },
    actions: {
      'pt': [
        '0–5 min: ABCDE, O2 10 L/min, acesso venoso/IO, glicemia capilar (glicose IV se hipoglicemia)',
        '5–20 min (1ª linha): Midazolam 10 mg IM (adulto) OU Diazepam 10 mg IV lento OU Lorazepam 4 mg IV (se disponível)',
        '20–40 min (2ª linha): Levetiracetam 60 mg/kg IV (máx. 4500 mg) em 15 min — 1ª escolha atual (AHA/ESE 2021); ou Valproato 40 mg/kg IV; ou Fenitoína 20 mg/kg IV lento (<50 mg/min)',
        '40–60 min (status refratário): Anestesia geral — Propofol 2 mg/kg IV + infusão; ou Midazolam 0,2 mg/kg IV + infusão; ou Fenobarbital 20 mg/kg IV',
        'Monitoração EEG contínua em status refratário',
        'Investigar causa: TC, PL, eletrólitos, toxicologia, neuroimagem'
      ],
      'es': [
        '0–5 min: ABCDE, O2 10 L/min, acceso venoso/IO, glucemia capilar',
        '5–20 min (1ª línea): Midazolam 10 mg IM (adulto) O Diazepam 10 mg IV lento',
        '20–40 min (2ª línea): Levetiracetam 60 mg/kg IV (máx. 4500 mg) en 15 min; o Valproato 40 mg/kg IV; o Fenitoína 20 mg/kg IV lento',
        '40–60 min (refractario): Anestesia general — Propofol 2 mg/kg IV + infusión; o Midazolam 0,2 mg/kg IV + infusión',
        'Monitorización EEG continua en status refractario',
        'Investigar causa: TC, PL, electrolitos, toxicología, neuroimagen'
      ],
    },
    avoid: {
      'pt': 'NUNCA atrasar benzodiazepínico. Não usar fenitoína como primeira linha em ausência típica ou espasmos infantis. Evitar hiperventilação (precipita convulsão). Monitorar depressão respiratória.',
      'es': 'NUNCA retrasar benzodiacepina. Monitorar depresión respiratoria.',
    },
    drugs: ['midazolam', 'diazepam', 'fenitoina', 'levetiracetam'],
  ),

  // ─────────────────────────────────────────────
  //  RESPIRATÓRIO
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'asma_grave',
    title: {'pt': 'Asma Aguda Grave / Quase Fatal', 'es': 'Asma Aguda Grave / Casi Fatal'},
    severity: {'pt': 'Alto', 'es': 'Alto'},
    recognize: {
      'pt': 'Dispneia intensa, SpO2 <90% (ou O2 <60%), uso intenso de musculatura acessória, incapacidade de falar frases completas, sibilos ou silêncio auscultório (grave). PFE <50% previsto.',
      'es': 'Disnea intensa, SpO2 <90%, uso intenso de musculatura accesoria, incapacidad de hablar frases completas. PFE <50% previsto.',
    },
    actions: {
      'pt': [
        '1. O2 alto fluxo para SpO2 ≥94%; posição sentada',
        '2. Salbutamol nebulização: 5 mg a cada 20 min × 3 doses (1ª hora); depois a cada 1–4h; considerar contínuo na crise grave',
        '3. Ipratrópio brometo nebulização: 0,5 mg a cada 20 min × 3 (combinado com salbutamol)',
        '4. Metilprednisolona 125 mg IV (ou Prednisolona 40–60 mg VO se leve/moderada)',
        '5. Magnésio sulfato: 2 g IV em 20 min (crise grave refratária) — broncodilatador',
        '6. VNI (CPAP/BiPAP) se SpO2 <90% refratária ou fadiga respiratória',
        '7. Intubação orotraqueal se parada iminente, exaustão ou coma (estratégia ventilatória especial: baixa FR, alto fluxo, I:E 1:3–5)',
        '8. Adrenalina SC 0,3 mg se anafilaxia ou crise refratária extrema',
        '9. Alta: corticoide VO 5–7 dias + broncodilatador de resgate + plano de ação'
      ],
      'es': [
        '1. O2 alto flujo para SpO2 ≥94%',
        '2. Salbutamol nebulización: 5 mg cada 20 min × 3 dosis; luego cada 1–4 h',
        '3. Ipratropio bromuro nebulización: 0,5 mg cada 20 min × 3',
        '4. Metilprednisolona 125 mg IV (o Prednisolona 40–60 mg VO si leve/moderada)',
        '5. Magnesio sulfato: 2 g IV en 20 min (crise grave refractaria)',
        '6. VNI (CPAP/BiPAP) si SpO2 <90% refractaria o fatiga respiratoria',
        '7. Intubación orotraqueal si parada inminente o coma',
        '8. Alta: corticoide VO 5–7 días + broncodilatador de rescate + plan de acción'
      ],
    },
    avoid: {
      'pt': 'EVITAR sedação sem via aérea garantida. Evitar betabloqueadores (broncoespasmo). Não usar ketamina IV sem experiência em asma intubada. Evitar AINEs se asma aspirina-sensível.',
      'es': 'EVITAR sedación sin vía aérea garantizada. Evitar betabloqueadores. No usar AINEs si asma aspirina-sensible.',
    },
    drugs: ['salbutamol', 'dexametasona', 'metilprednisolona', 'adrenalina'],
  ),

  ProtocolModel(
    id: 'dpoc_exacerbacao',
    title: {'pt': 'DPOC — Exacerbação Aguda Grave', 'es': 'EPOC — Exacerbación Aguda Grave'},
    severity: {'pt': 'Alto', 'es': 'Alto'},
    recognize: {
      'pt': 'Piora de dispneia, tosse e/ou escarro além da variação diária. Exacerbação grave: SpO2 <88%, FR >30, uso de musculatura acessória, encefalopatia, pH <7,35.',
      'es': 'Empeoramiento de disnea, tos y/o esputo más allá de la variación diaria. Grave: SpO2 <88%, FR >30, uso de musculatura accesoria.',
    },
    actions: {
      'pt': [
        '1. O2 CONTROLADO: alvo SpO2 88–92% (DPOC grave — risco de hipercapnia); usar máscara Venturi 24–28%',
        '2. Salbutamol nebulização: 2,5–5 mg a cada 20–30 min nas primeiras 2h, depois a cada 4–6h',
        '3. Ipratrópio brometo nebulização: 0,5 mg a cada 6h (combinar com salbutamol)',
        '4. Prednisolona 40 mg VO por 5 dias (ou Metilprednisolona 40–80 mg IV se grave)',
        '5. Antibiótico se escarro purulento/febre: Amoxicilina-Clavulanato VO ou Azitromicina ou Ciprofloxacino IV',
        '6. VNI (BiPAP) se pH <7,35 e PaCO2 >45 mmHg — GOLD standard; reduz mortalidade 50%',
        '7. Intubação se falha de VNI, apneia, coma ou contraindicação',
        '8. Monitorar gasometria arterial 1–2h após VNI ou mudança terapêutica'
      ],
      'es': [
        '1. O2 CONTROLADO: objetivo SpO2 88–92%; mascarilla Venturi 24–28%',
        '2. Salbutamol nebulización: 2,5–5 mg cada 20–30 min, luego cada 4–6 h',
        '3. Ipratropio bromuro nebulización: 0,5 mg cada 6 h',
        '4. Prednisolona 40 mg VO por 5 días (o Metilprednisolona 40–80 mg IV si grave)',
        '5. Antibiótico si esputo purulento/fiebre: Amoxicilina-Clavulanato VO o Azitromicina',
        '6. VNI (BiPAP) si pH <7,35 y PaCO2 >45 mmHg — estándar de oro; reduce mortalidad 50%',
        '7. Intubación si falla de VNI, apnea, coma',
        '8. Monitorizar gasometría arterial 1–2 h tras VNI'
      ],
    },
    avoid: {
      'pt': 'EVITAR O2 alto fluxo sem controle (SpO2 >94% em DPOC grave → hipercapnia). Evitar sedação sem via aérea. Não usar metilxantinas rotineiramente (teofilina — sem evidência).',
      'es': 'EVITAR O2 alto flujo sin control (SpO2 >94% en EPOC grave → hipercapnia). Evitar sedación sin vía aérea.',
    },
    drugs: ['salbutamol', 'metilprednisolona', 'azitromicina', 'ciprofloxacino'],
  ),

  ProtocolModel(
    id: 'tep_agudo',
    title: {'pt': 'Tromboembolismo Pulmonar (TEP) Agudo', 'es': 'Tromboembolismo Pulmonar (TEP) Agudo'},
    severity: {'pt': 'Alto', 'es': 'Alto'},
    recognize: {
      'pt': 'Dispneia súbita + dor pleurítica + hemoptise + taquicardia + fator de risco (TVP, imobilização, cirurgia, neoplasia). Score de Wells. D-dímero. AngioTC de tórax.',
      'es': 'Disnea súbita + dolor pleurítico + hemoptisis + taquicardia + factor de riesgo (TVP, inmovilización, cirugía, neoplasia). Score de Wells.',
    },
    actions: {
      'pt': [
        '1. Avaliar gravidade: TEP de alto risco = choque/hipotensão (PA <90 mmHg); intermediário = RVD + troponina; baixo risco = estável sem disfunção VD',
        '2. O2: manter SpO2 ≥94%',
        '3. Anticoagulação imediata (se probabilidade alta ou diagnóstico confirmado): Enoxaparina 1 mg/kg SC 12/12h OU HNF IV OU NOAC (rivaroxabana 15 mg 2×/dia)',
        '4. TEP de alto risco (choque): Trombólise sistêmica — Alteplase 100 mg IV em 2h (se sem contraindicação absoluta)',
        '5. Trombólise contraindicada + alto risco: trombectomia cirúrgica ou por cateter',
        '6. Monitoração: ECG (S1Q3T3, BRD), troponina, BNP, ecocardiograma (disfunção VD)',
        '7. Suporte hemodinâmico: Noradrenalina se hipotensão (evitar fluidos excessivos — sobrecarga VD)',
        '8. Anticoagulação mínima 3–6 meses; avaliar causa (trombofilia, neoplasia)'
      ],
      'es': [
        '1. Evaluar gravedad: alto riesgo = choque/hipotensión; intermediario = disfunción VD + troponina; bajo riesgo = estable',
        '2. O2: mantener SpO2 ≥94%',
        '3. Anticoagulación inmediata: Enoxaparina 1 mg/kg SC 12/12 h o HNF IV o NOAC',
        '4. TEP de alto riesgo (choque): Trombólisis sistémica — Alteplase 100 mg IV en 2 h',
        '5. Trombólisis contraindicada + alto riesgo: trombectomía quirúrgica o por catéter',
        '6. Monitorización: ECG, troponina, BNP, ecocardiograma',
        '7. Soporte hemodinámico: Noradrenalina si hipotensión',
        '8. Anticoagulación mínima 3–6 meses'
      ],
    },
    avoid: {
      'pt': 'EVITAR sobrecarga de volume no VD (piora disfunção). Evitar hipotensão. Trombólise contraindicada se cirurgia recente <3 semanas, sangramento ativo, AVC isquêmico <3 meses.',
      'es': 'EVITAR sobrecarga de volumen en VD. Trombólisis contraindicada si cirugía reciente <3 semanas, sangrado activo, AVC isquémico <3 meses.',
    },
    drugs: ['heparina_nf', 'enoxaparina', 'noradrenalina'],
  ),

  // ─────────────────────────────────────────────
  //  INFECÇÃO / SEPSE
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'sepse',
    title: {'pt': 'Sepse e Choque Séptico — Bundle Sobrevivendo à Sepse', 'es': 'Sepsis y Choque Séptico — Bundle Sobreviviendo a la Sepsis'},
    severity: {'pt': 'Crítico', 'es': 'Crítico'},
    recognize: {
      'pt': 'Suspeita de infecção + disfunção orgânica aguda (qSOFA ≥2: FR ≥22, Glasgow <15, PAS ≤100). Choque séptico: vasopressor necessário + lactato >2 mmol/L apesar de volume.',
      'es': 'Sospecha de infección + disfunción orgánica aguda (qSOFA ≥2: FR ≥22, Glasgow <15, PAS ≤100). Choque séptico: vasopresor necesario + lactato >2 mmol/L a pesar de volumen.',
    },
    actions: {
      'pt': [
        'BUNDLE 1 HORA (Surviving Sepsis Campaign 2018):',
        '1. Medir lactato; repetir se >2 mmol/L',
        '2. Hemoculturas (2 pares) ANTES do antibiótico',
        '3. ATB de amplo espectro EM ATÉ 1 HORA (idealmente 30 min): Pip-Taz 4,5 g IV + Vancomicina se risco MRSA',
        '4. Volume: Cristaloide 30 mL/kg IV rápido se hipotensão ou lactato ≥4 mmol/L',
        '5. Vasopressor se hipotensão refratária ao volume: Noradrenalina 0,1 µg/kg/min IV (PAM alvo ≥65)',
        'BUNDLE ADICIONAL UTI:',
        '6. Controle de foco: drenagem de abscessos, remoção de cateteres infectados',
        '7. Hidrocortisona 200 mg/dia IV (em 4 doses ou infusão) se choque refratário a vasopressores',
        '8. Controle glicêmico: alvo 140–180 mg/dL',
        '9. Proteção renal: evitar nefrotóxicos, controlar PAM ≥65',
        '10. Monitorar SOFA score diariamente'
      ],
      'es': [
        'BUNDLE 1 HORA (Surviving Sepsis Campaign 2018):',
        '1. Medir lactato; repetir si >2 mmol/L',
        '2. Hemocultivos (2 pares) ANTES del antibiótico',
        '3. ATB de amplio espectro EN 1 HORA: Pip-Taz 4,5 g IV + Vancomicina si riesgo MRSA',
        '4. Volumen: Cristaloide 30 mL/kg IV rápido si hipotensión o lactato ≥4 mmol/L',
        '5. Vasopresor si hipotensión refractaria: Noradrenalina 0,1 µg/kg/min IV (PAM objetivo ≥65)',
        'BUNDLE ADICIONAL UCI:',
        '6. Control de foco: drenaje de abscesos, remoción de catéteres infectados',
        '7. Hidrocortisona 200 mg/día IV si choque refractario a vasopresores',
        '8. Control glucémico: objetivo 140–180 mg/dL',
        '9. Protección renal: evitar nefrotóxicos, mantener PAM ≥65',
        '10. Monitorizar SOFA score diariamente'
      ],
    },
    avoid: {
      'pt': 'NUNCA atrasar antibiótico (cada hora de atraso aumenta mortalidade). Evitar volume excessivo (ARDS). Não usar albumina como expansão de rotina (controvérsia). Ajustar antibióticos em 48–72h com resultado de cultura (descalonamento).',
      'es': 'NUNCA retrasar antibiótico. Evitar volumen excesivo (SDRA). Ajustar antibióticos en 48–72 h con resultado de cultivo (desescalada).',
    },
    drugs: ['noradrenalina', 'piperacilina_tazobactam', 'vancomicina', 'meropenem', 'dexametasona'],
  ),

  // ─────────────────────────────────────────────
  //  METABÓLICO / ENDÓCRINO
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'cad_shh',
    title: {'pt': 'Cetoacidose Diabética (CAD) e Estado Hiperosmolar (EHH)', 'es': 'Cetoacidosis Diabética (CAD) y Estado Hiperosmolar (EHH)'},
    severity: {'pt': 'Alto', 'es': 'Alto'},
    recognize: {
      'pt': 'CAD: glicemia >250 mg/dL + cetonemia/cetonúria + pH <7,30 + HCO3 <18 mEq/L + náuseas/vômito/dor abdominal. EHH: glicemia >600 mg/dL + osmolaridade >320 mOsm/kg + sem acidose/cetose importante.',
      'es': 'CAD: glucemia >250 mg/dL + cetonemia/cetonuria + pH <7,30 + HCO3 <18 mEq/L. EHH: glucemia >600 mg/dL + osmolaridad >320 mOsm/kg + sin acidosis/cetosis importante.',
    },
    actions: {
      'pt': [
        'FASE 1 — RESSUSCITAÇÃO VOLÊMICA (1ª hora):',
        '1. SF 0,9% 1 L/h IV na 1ª hora; depois ajustar conforme Na+ corrigido e débito urinário',
        '2. Se K+ >3,3 mEq/L: Insulina Regular 0,1 UI/kg/h IV contínuo (ou 0,14 UI/kg/h sem bolus)',
        '3. Se K+ <3,3 mEq/L: SUSPENDER insulina; repor K+ 40 mEq/h IV até K+ >3,5 antes de insulina',
        'FASE 2 — MONITORAÇÃO HORÁRIA:',
        '4. Meta: queda de glicemia 50–75 mg/dL/hora (se queda >100: reduzir insulina)',
        '5. Quando glicemia <200 (CAD) ou <300 (EHH): Soro Glicosado 5% + manter insulina 0,05 UI/kg/h',
        '6. Reposição de K+: manter K+ 3,5–5,5 mEq/L (repor se <5,5)',
        '7. Fosfato: repor se <1 mg/dL com sintomas',
        '8. Bicarbonato apenas se pH <6,9 (50 mEq IV em 1h)',
        'RESOLUÇÃO CAD: pH >7,30 + HCO3 >18 + anion gap normalizado',
        '9. Transição para insulina SC: sobrepor 1–2h antes de retirar IV'
      ],
      'es': [
        'FASE 1 — RESUCITACIÓN VOLÉMICA (1ª hora):',
        '1. SF 0,9% 1 L/h IV en 1ª hora; ajustar según Na+ corregido y diuresis',
        '2. Si K+ >3,3 mEq/L: Insulina Regular 0,1 UI/kg/h IV continuo',
        '3. Si K+ <3,3 mEq/L: SUSPENDER insulina; reponer K+ 40 mEq/h IV hasta K+ >3,5',
        'FASE 2 — MONITORIZACIÓN HORARIA:',
        '4. Meta: caída de glucemia 50–75 mg/dL/hora',
        '5. Cuando glucemia <200 (CAD) o <300 (EHH): Suero Glucosado 5% + mantener insulina 0,05 UI/kg/h',
        '6. Reposición de K+: mantener K+ 3,5–5,5 mEq/L',
        '7. Bicarbonato solo si pH <6,9',
        'RESOLUCIÓN CAD: pH >7,30 + HCO3 >18 + anion gap normalizado',
        '8. Transición a insulina SC: solapar 1–2 h antes de retirar IV'
      ],
    },
    avoid: {
      'pt': 'NUNCA iniciar insulina com K+ <3,3 mEq/L (hipopotassemia fatal). Evitar bicarbonato rotineiro (piora hipopotassemia, alcalose). Não usar insulina rápida SC isolada em CAD grave. Evitar queda glicêmica rápida (edema cerebral em criança).',
      'es': 'NUNCA iniciar insulina con K+ <3,3 mEq/L. Evitar bicarbonato rutinario. No usar insulina rápida SC aislada en CAD grave.',
    },
    drugs: ['insulina_regular', 'cloreto_potassio', 'bicarbonato_sodio'],
  ),

  ProtocolModel(
    id: 'pcr_adulto',
    title: {'pt': 'Parada Cardiorrespiratória (PCR) — ACLS Adulto', 'es': 'Paro Cardiorrespiratorio (PCR) — ACLS Adulto'},
    severity: {'pt': 'Crítico', 'es': 'Crítico'},
    recognize: {
      'pt': 'Ausência de responsividade + ausência de respiração normal + ausência de pulso carotídeo (verificar em <10 s). Ritmos: FV/TV sem pulso (chocáveis) ou AESP/Assistolia (não chocáveis).',
      'es': 'Ausencia de responsividad + ausencia de respiración normal + ausencia de pulso carotídeo (verificar en <10 s). Ritmos: FV/TV sin pulso (chocables) o AESP/Asistolia (no chocables).',
    },
    actions: {
      'pt': [
        '1. CHAMAR AJUDA + desfibrilador + timer',
        '2. RCP de alta qualidade: 30:2; compressões 5–6 cm; 100–120/min; reexpansão completa; mínimo interrupções',
        '3. RITMOS CHOCÁVEIS (FV/TV sem pulso):',
        '   → Choque bifásico 120–200 J (ou máx. do desfibrilador); reiniciar RCP imediatamente',
        '   → Epinefrina 1 mg IV a cada 3–5 min (a partir do 2º ciclo sem desfibrilação)',
        '   → Amiodarona: 300 mg IV bolus (1ª dose) + 150 mg se necessário',
        '4. RITMOS NÃO CHOCÁVEIS (AESP/Assistolia):',
        '   → Epinefrina 1 mg IV A CADA 3–5 MIN (iniciar imediatamente)',
        '   → RCP contínua; tratar 5H5T',
        '5. VIA AÉREA: considerar IOT ou máscara laríngea (não interromper RCP)',
        '6. ACESSO: periférico ou IO (intraósseo) — preferir periférico se disponível',
        '7. TRATAR 5H5T: Hipovolemia, Hipóxia, Hidrogênio (acidose), Hipo/Hiperpotassemia, Hipotermia | Tensão (pneumotórax), Tamponamento, Trombose coronária, Trombose pulmonar, Tóxicos',
        '8. RETORNO DA CIRCULAÇÃO ESPONTÂNEA (ROSC): iniciar protocolo pós-PCR (TTM, angiografia urgente se IAMCSST)'
      ],
      'es': [
        '1. LLAMAR AYUDA + desfibrilador + timer',
        '2. RCP de alta calidad: 30:2; compresiones 5–6 cm; 100–120/min; reexpansión completa',
        '3. RITMOS CHOCABLES (FV/TV sin pulso):',
        '   → Choque bifásico 120–200 J; reiniciar RCP inmediatamente',
        '   → Epinefrina 1 mg IV cada 3–5 min (a partir del 2° ciclo)',
        '   → Amiodarona: 300 mg IV bolo + 150 mg si necesario',
        '4. RITMOS NO CHOCABLES (AESP/Asistolia):',
        '   → Epinefrina 1 mg IV CADA 3–5 MIN (iniciar inmediatamente)',
        '5. VÍA AÉREA: considerar IOT o máscara laríngea',
        '6. TRATAR 5H5T: Hipovolemia, Hipoxia, Hidrógeno (acidosis), Hipo/Hiperpotasemia, Hipotermia | Tensión (neumotórax), Taponamiento, Trombosis coronaria, Trombosis pulmonar, Tóxicos',
        '7. RETORNO CIRCULACIÓN ESPONTÁNEA (ROSC): protocolo post-PCR'
      ],
    },
    avoid: {
      'pt': 'NUNCA interromper RCP por >10 s (exceto durante desfibrilação). Evitar ventilação excessiva (↑ pressão intratorácica → ↓ retorno venoso). Não checar pulso desnecessariamente. Bicarbonato NÃO é rotina — usar apenas em hiperpotassemia ou acidose documentada.',
      'es': 'NUNCA interrumpir RCP por >10 s. Evitar ventilación excesiva. Bicarbonato NO es rutina.',
    },
    drugs: ['adrenalina', 'amiodarona', 'bicarbonato_sodio', 'cloreto_potassio'],
  ),

  // ─────────────────────────────────────────────
  //  GASTROENTEROLOGIA
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'hda_varizeal',
    title: {'pt': 'Hemorragia Digestiva Alta Varicosa', 'es': 'Hemorragia Digestiva Alta Varicosa'},
    severity: {'pt': 'Crítico', 'es': 'Crítico'},
    recognize: {
      'pt': 'Hematêmese + melena/hematoquezia em paciente com cirrose/hipertensão portal. Sinais de choque hipovolêmico. Urgência endoscópica.',
      'es': 'Hematemesis + melena/hematoquecia en paciente con cirrosis/hipertensión portal. Signos de choque hipovolémico.',
    },
    actions: {
      'pt': [
        '1. 2 acessos calibrosos (14–16 G); SF 0,9% para ressuscitação',
        '2. Meta transfusional: Hb alvo 7–8 g/dL (transfusão restritiva reduz mortalidade)',
        '3. Vasopressina esplâncnica: Octreotida 50 µg IV bolus + 25–50 µg/h infusão (ou Terlipressina 2 mg IV a cada 4h)',
        '4. Antibiótico: Ceftriaxona 1 g IV/dia por 5–7 dias (profilaxia PBE/bacteremia)',
        '5. Endoscopia digestiva alta: em <12h (ligadura elástica ou escleroterapia)',
        '6. Pantoprazol 80 mg IV bolus + 8 mg/h infusão (IBP alto)',
        '7. Se sangramento refratário: balão de Sengstaken-Blakemore como ponte + TIPS precoce',
        '8. Profilaxia secundária: betabloqueador não-seletivo (propranolol) + ligadura eletiva'
      ],
      'es': [
        '1. 2 accesos calibrosos (14–16 G); SF 0,9% para resucitación',
        '2. Meta transfusional: Hb objetivo 7–8 g/dL (transfusión restrictiva)',
        '3. Vasopresina esplácnica: Octreotida 50 µg IV bolo + 25–50 µg/h infusión (o Terlipresina)',
        '4. Antibiótico: Ceftriaxona 1 g IV/día por 5–7 días',
        '5. Endoscopia digestiva alta: en <12 h',
        '6. Pantoprazol 80 mg IV bolo + 8 mg/h infusión',
        '7. Si sangrado refractario: balón de Sengstaken-Blakemore + TIPS precoz',
        '8. Profilaxis secundaria: betabloqueador no selectivo + ligadura electiva'
      ],
    },
    avoid: {
      'pt': 'EVITAR ressuscitação volêmica agressiva (piora hipertensão portal). Transfusão: manter Hb entre 7–8 g/dL (NÃO 10 g/dL). Evitar AINEs e álcool. Não usar vasopressina sistêmica (efeitos adversos).',
      'es': 'EVITAR resucitación volémica agresiva. Transfusión: mantener Hb entre 7–8 g/dL. Evitar AINEs y alcohol.',
    },
    drugs: ['ceftriaxona', 'omeprazol', 'noradrenalina'],
  ),

  // ─────────────────────────────────────────────
  //  NEUROLÓGICO
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'avc_isquemico',
    title: {'pt': 'AVC Isquêmico Agudo — Janela Trombolítica', 'es': 'ACV Isquémico Agudo — Ventana Trombolítica'},
    severity: {'pt': 'Crítico', 'es': 'Crítico'},
    recognize: {
      'pt': 'Déficit neurológico focal de início súbito (NIHSS). TC crânio sem contraste: excluir hemorragia. Janela: ≤4,5h (alteplase) ou ≤24h wake-up (avaliação imagem). Escala FAST: Face/Arm/Speech/Time.',
      'es': 'Déficit neurológico focal de inicio súbito (NIHSS). TC cráneo sin contraste: excluir hemorragia. Ventana: ≤4,5 h (alteplase). Escala FAST.',
    },
    actions: {
      'pt': [
        '1. CÓDIGO AVC: TC crânio SEM CONTRASTE em <25 min da chegada',
        '2. Glicemia capilar imediata (tratar hipo/hiperglicemia grave)',
        '3. Monitorar ECG, PA, SpO2 — manter SpO2 >94%, O2 apenas se necessário',
        '4. NIHSS à beira do leito para determinar elegibilidade e monitorar',
        '5. Alteplase IV 0,9 mg/kg (máx. 90 mg): 10% em bolo 1 min, 90% em 60 min — se elegível ≤4,5h',
        '6. Contraindicações absolutas alteplase: hemorragia, PA >185/110 mmHg não controlada, glicemia <50 ou >400 mg/dL, cirurgia recente <14d, AVC/TCE <3 meses',
        '7. Trombectomia mecânica: NIHSS ≥6, oclusão de grande vaso, janela ≤24h (com imagem adequada)',
        '8. Não iniciar anticoagulação/antiagregação nas primeiras 24h pós-alteplase',
      ],
      'es': [
        '1. CÓDIGO ACV: TC cráneo SIN CONTRASTE en <25 min de llegada',
        '2. Glucemia capilar inmediata',
        '3. Monitorizar ECG, PA, SpO2 — manter SpO2 >94%',
        '4. NIHSS para determinar elegibilidad',
        '5. Alteplase IV 0,9 mg/kg (máx. 90 mg): 10% en bolo 1 min, 90% en 60 min — si elegible ≤4,5 h',
        '6. Contraindicaciones alteplase: hemorragia, PA >185/110 mmHg, glucemia <50 o >400, cirugía <14d',
        '7. Trombectomía mecánica: NIHSS ≥6, oclusión vaso grande, ventana ≤24 h',
        '8. No iniciar anticoagulación en primeras 24 h post-alteplase',
      ],
    },
    avoid: {
      'pt': 'EVITAR: anti-hipertensivos agressivos antes de alteplase (meta PA ≤185/110 mmHg apenas). Não baixar PA <180/105 mmHg nas primeiras 24h pós-alteplase (risco extensão isquêmica). Evitar glicose IV desnecessária (hiperglicemia piora prognóstico). Não administrar heparina ou antiagregante nas primeiras 24h após trombólise.',
      'es': 'EVITAR: antihipertensivos agresivos antes de alteplase. No bajar PA <180/105 mmHg en primeras 24 h post-alteplase. Evitar glucosa IV innecesaria. No dar heparina/antiagregante primeras 24 h post-trombólisis.',
    },
    drugs: ['alteplase', 'atenolol', 'acido_acetilsalicilico'],
  ),

  ProtocolModel(
    id: 'status_epilepticus',
    title: {'pt': 'Estado de Mal Epiléptico (Status Epilepticus)', 'es': 'Estado Epiléptico (Status Epilepticus)'},
    severity: {'pt': 'Crítico', 'es': 'Crítico'},
    recognize: {
      'pt': 'Convulsão contínua ≥5 min OU ≥2 crises sem recuperação completa da consciência. Urgência absoluta — mortalidade 10–20%. Verificar: hipoglicemia, eletrólitos, febre, histórico de epilepsia, AAS, trauma.',
      'es': 'Convulsión continua ≥5 min O ≥2 crisis sin recuperación completa. Urgencia absoluta — mortalidad 10–20%.',
    },
    actions: {
      'pt': [
        '1. 0–5 min: Via aérea, O2, acesso IV, glicemia capilar — tratar hipoglicemia (50 mL glicose 50% IV)',
        '2. 0–5 min: Colher: gasometria, eletrólitos, glicose, hemograma, antiepilépticos séricos',
        '3. 5–20 min (1ª linha — benzodiazepínico): Diazepam 10 mg IV OU Midazolam 10 mg IM/IV OU Clonazepam 1–2 mg IV',
        '4. 20–40 min (2ª linha — antiepiléptico IV): Fenitoína 20 mg/kg IV 50 mg/min OU Levetiracetam 60 mg/kg IV (máx. 4500 mg) OU Valproato 40 mg/kg IV',
        '5. >40 min (Status refratário): Anestesia geral com intubação — midazolam infusão 0,1–2 mg/kg/h OU propofol OU tiopental',
        '6. Identificar e tratar causa subjacente: infecção, AVC, metabólico, tóxico',
        '7. EEG contínuo se status não-convulsivo ou anestesia geral',
      ],
      'es': [
        '1. 0–5 min: Vía aérea, O2, acceso IV, glucemia — tratar hipoglucemia',
        '2. 0–5 min: Gasometría, electrolitos, glucosa, hemograma, antiepilépticos séricos',
        '3. 5–20 min (1ª línea): Diazepam 10 mg IV O Midazolam 10 mg IM/IV O Clonazepam 1–2 mg IV',
        '4. 20–40 min (2ª línea): Fenitoína 20 mg/kg IV OU Levetiracetam 60 mg/kg IV OU Valproato 40 mg/kg IV',
        '5. >40 min (Status refractario): Anestesia general + intubación — midazolam 0,1–2 mg/kg/h',
        '6. Identificar y tratar causa subyacente',
        '7. EEG continuo en status no convulsivo o anestesia general',
      ],
    },
    avoid: {
      'pt': 'EVITAR: atraso na 1ª dose — cada minuto aumenta refratariedade. Não esperar acesso IV para dar midazolam (IM é eficaz). Fenitoína: infusão >50 mg/min causa bradiarritmia. Não usar fenitoína em crises alcoólicas ou metabólicas (baixa eficácia). Evitar hiperventilação agressiva sem ITÁ.',
      'es': 'EVITAR: demora en 1ª dosis. No esperar acceso IV para midazolam (IM es eficaz). Fenitoína: infusión >50 mg/min causa bradiarritmia. No usar fenitoína en crisis alcohólicas o metabólicas.',
    },
    drugs: ['diazepam', 'midazolam', 'fenitoina', 'levetiracetam', 'clonazepam'],
  ),

  ProtocolModel(
    id: 'meningite_bacteriana',
    title: {'pt': 'Meningite Bacteriana Aguda', 'es': 'Meningitis Bacteriana Aguda'},
    severity: {'pt': 'Crítico', 'es': 'Crítico'},
    recognize: {
      'pt': 'Tríade: cefaleia + febre + rigidez de nuca. Sinais Kernig e Brudzinski. Alteração do nível de consciência. Petéquias/púrpura (meningococo). Fotofobia, fonofobia. Liquor: pleocitose PMN, proteína ↑, glicose ↓.',
      'es': 'Tríada: cefalea + fiebre + rigidez de nuca. Kernig y Brudzinski. Petequias (meningococo). LCR: pleocitosis PMN, proteína ↑, glucosa ↓.',
    },
    actions: {
      'pt': [
        '1. NÃO ATRASAR ANTIBIÓTICO para esperar TC (se sem papiledema e Glasgow ≥13)',
        '2. Hemocultura (2 amostras) ANTES do antibiótico — 5 min no máximo',
        '3. Dexametasona 0,15 mg/kg IV imediatamente ANTES ou COM 1ª dose de antibiótico',
        '4. Ceftriaxona 2 g IV 12/12h (adulto) — cobertura pneumo/meningo',
        '5. Ampicilina 2 g IV 4/4h se >50 anos ou imunossuprimido (cobertura Listeria)',
        '6. TC crânio: realizar se papiledema, Glasgow <13, crise, déficit focal — ANTES da punção',
        '7. Punção lombar com análise do LCR (após TC se indicada)',
        '8. Suporte: correção de eletrólitos, controle de PA, cabeceira 30°, monitorar hidrocefalia',
      ],
      'es': [
        '1. NO RETRASAR ANTIBIÓTICO para esperar TC (si sin papiledema y Glasgow ≥13)',
        '2. Hemocultivo (2 muestras) ANTES del antibiótico — máx. 5 min',
        '3. Dexametasona 0,15 mg/kg IV ANTES o CON 1ª dosis de antibiótico',
        '4. Ceftriaxona 2 g IV c/12 h (adulto)',
        '5. Ampicilina 2 g IV c/4 h si >50 años o inmunosuprimido (cobertura Listeria)',
        '6. TC cráneo si papiledema, Glasgow <13, crisis, déficit focal — ANTES de punción',
        '7. Punción lumbar con análisis de LCR',
        '8. Soporte: electrolitos, PA, cabecera 30°, monitorar hidrocefalia',
      ],
    },
    avoid: {
      'pt': 'NUNCA atrasar antibiótico esperando TC sem indicação. Não realizar punção lombar se suspeita de hipertensão intracraniana sem TC prévia. Dexametasona: eficácia máxima apenas se iniciada antes/com antibiótico — não usar após. Evitar hipotensão e hiponatremia (piora edema cerebral).',
      'es': 'NUNCA retrasar antibiótico esperando TC sin indicación. No realizar PL sin TC previa si sospecha HIC. Dexametasona: máxima eficacia solo si antes/con antibiótico. Evitar hipotensión e hiponatremia.',
    },
    drugs: ['ceftriaxona', 'dexametasona', 'meropenem'],
  ),

  // ─────────────────────────────────────────────
  //  ENDÓCRINO / METABÓLICO
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'cetoacidose_diabetica',
    title: {'pt': 'Cetoacidose Diabética (CAD)', 'es': 'Cetoacidosis Diabética (CAD)'},
    severity: {'pt': 'Alto', 'es': 'Alto'},
    recognize: {
      'pt': 'Glicemia >250 mg/dL + pH <7,3 OU HCO3 <18 mEq/L + cetonúria/cetonemia. Tríade: poliúria, polidipsia, vômitos + dor abdominal. Respiração de Kussmaul (acidose grave). Hálito cetônico.',
      'es': 'Glucemia >250 mg/dL + pH <7,3 O HCO3 <18 mEq/L + cetonuria/cetonemia. Respiración de Kussmaul. Aliento cetónico.',
    },
    actions: {
      'pt': [
        '1. Hidratação: SF 0,9% — 1L em 1h, depois 250–500 mL/h (ajustar pela resposta)',
        '2. K+ sérico: se K+ <3,5 repor KCl antes da insulina! Se K+ 3,5–5,5: KCl 20–40 mEq/h com insulina',
        '3. Insulina Regular IV contínua: 0,14 UI/kg/h (sem bolus se K+ reposto). Trocar para SC após anion gap normalizado',
        '4. Glicemia-alvo queda 50–75 mg/dL/h. Adicionar SG 5–10% quando glicemia <250 mg/dL para manter infusão de insulina',
        '5. Bicarbonato APENAS se pH <6,9: 100 mEq NaHCO3 em 1–2h',
        '6. Monitorar: glicemia horária, eletrólitos e gasometria a cada 2–4h',
        '7. Identificar e tratar fator precipitante: infecção, omissão de insulina, IAM',
        '8. Critérios de resolução: glicemia <200 + HCO3 ≥15 + pH ≥7,3 + anion gap ≤12',
      ],
      'es': [
        '1. Hidratación: SF 0,9% — 1L en 1h, luego 250–500 mL/h',
        '2. K+ sérico: si K+ <3,5 reponer KCl ANTES de insulina. Si K+ 3,5–5,5: KCl 20–40 mEq/h',
        '3. Insulina Regular IV: 0,14 UI/kg/h (sin bolo si K+ repuesto)',
        '4. Glucemia objetivo: caída 50–75 mg/dL/h. Agregar SG 5% cuando <250 mg/dL',
        '5. Bicarbonato SOLO si pH <6,9: 100 mEq NaHCO3 en 1–2 h',
        '6. Monitorizar: glucemia horaria, electrolitos y gasometría c/2–4 h',
        '7. Identificar y tratar factor precipitante',
        '8. Resolución: glucemia <200 + HCO3 ≥15 + pH ≥7,3',
      ],
    },
    avoid: {
      'pt': 'EVITAR: insulina sem reposição prévia de K+ (hipopotassemia grave fatal). Não usar bicarbonato rotineiramente (piora hipopotassemia, acidose paradoxal intracraniana). Evitar queda rápida de osmolaridade (edema cerebral, especialmente crianças). Não suspender insulina até anion gap normalizar.',
      'es': 'EVITAR: insulina sin reposición K+ (hipopotasemia fatal). No usar bicarbonato rutinariamente. Evitar caída rápida de osmolaridad (edema cerebral). No suspender insulina hasta normalizar anion gap.',
    },
    drugs: ['insulina_regular', 'cloreto_potassio', 'bicarbonato_sodio'],
  ),

  ProtocolModel(
    id: 'crise_hipertensiva',
    title: {'pt': 'Crise Hipertensiva — Emergência vs. Urgência', 'es': 'Crisis Hipertensiva — Emergencia vs. Urgencia'},
    severity: {'pt': 'Alto', 'es': 'Alto'},
    recognize: {
      'pt': 'Emergência hipertensiva: PA muito elevada + lesão aguda de órgão-alvo (LOA): encefalopatia, EAP, SCA, AVC, eclâmpsia, disseção de aorta. Urgência: PA muito elevada SEM LOA (assintomático/sintomas menores).',
      'es': 'Emergencia hipertensiva: PA muy elevada + lesión aguda de órgano diana (LOA). Urgencia: PA muy elevada SIN LOA.',
    },
    actions: {
      'pt': [
        '1. Emergência hipertensiva: internação UTI, monitoração invasiva de PA',
        '2. Meta redução PA: -20–25% nas primeiras 1–2h (NÃO normalizar abruptamente)',
        '3. Encefalopatia/EAP: Nitroprussiato de sódio 0,5–10 µg/kg/min IV OU Nicardipino 5 mg/h IV',
        '4. SCA + hipertensão: Nitroglicerina 5–200 µg/min IV',
        '5. Disseção de aorta: Esmolol IV (meta FC <60 bpm) + Nitroprussiato IV — meta PA sistólica ≤120 mmHg',
        '6. Eclâmpsia: MgSO4 4–6 g IV (ataque) + 1–2 g/h + Hidralazina 5–10 mg IV ou Labetalol IV',
        '7. Urgência hipertensiva: reduzir PA em 24–48h com medicação VO (captopril, atenolol, amlodipino)',
        '8. Investigar causas secundárias: feocromocitoma, hiperaldosteronismo, uso de cocaína',
      ],
      'es': [
        '1. Emergencia hipertensiva: internación UTI, monitoreo invasivo de PA',
        '2. Meta reducción PA: -20–25% en primeras 1–2 h (NO normalizar abruptamente)',
        '3. Encefalopatía/EAP: Nitroprusiato 0,5–10 µg/kg/min IV O Nicardipino 5 mg/h IV',
        '4. SCA + HAS: Nitroglicerina 5–200 µg/min IV',
        '5. Disección aórtica: Esmolol IV (meta FC <60 lpm) + Nitroprusiato IV',
        '6. Eclampsia: MgSO4 4–6 g IV + 1–2 g/h + Hidralazina 5–10 mg IV',
        '7. Urgencia: reducir PA en 24–48 h con VO (captopril, atenolol, amlodipino)',
        '8. Investigar causas secundarias',
      ],
    },
    avoid: {
      'pt': 'NUNCA normalizar PA rapidamente na emergência (AVC isquêmico: meta apenas <185/110 para trombólise). Sublingual nifedipino: CONTRAINDICADO (queda abrupta e imprevisível da PA → isquemia cerebral/coronariana). Evitar diuréticos em disseção de aorta. Não usar IECA/ARA II no AVC agudo.',
      'es': 'NUNCA normalizar PA rápido en emergencia (ACV isquémico: meta solo <185/110). Nifedipino SL: CONTRAINDICADO. Evitar diuréticos en disección aórtica.',
    },
    drugs: ['nitroglicerina', 'metoprolol', 'atenolol', 'amlodipino', 'sulfato_magnesio'],
  ),

  // ─────────────────────────────────────────────
  //  PNEUMOLOGIA / RESPIRATÓRIO
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'tromboembolismo_pulmonar',
    title: {'pt': 'Tromboembolismo Pulmonar (TEP) — Diagnóstico e Tratamento', 'es': 'Tromboembolismo Pulmonar (TEP) — Diagnóstico y Tratamiento'},
    severity: {'pt': 'Crítico', 'es': 'Crítico'},
    recognize: {
      'pt': 'Dispneia súbita, dor pleurítica, hemoptise. Escore de Wells e Escore de Genebra para probabilidade pré-teste. D-dímero negativo (<500 µg/L): exclui TEP em baixa probabilidade. Angiotomografia (gold standard). ECG: S1Q3T3, BDRCD, taquicardia sinusal.',
      'es': 'Disnea súbita, dolor pleurítico, hemoptisis. Escores Wells y Ginebra para probabilidad pre-test. D-dímero negativo: excluye TEP en baja probabilidad. Angiotomografía (gold standard).',
    },
    actions: {
      'pt': [
        '1. TEP de baixo risco: Anticoagulação + alta precoce se PESI classe I–II',
        '2. Anticoagulação imediata: Rivaroxabana 15 mg 12/12h × 21d ou Enoxaparina 1 mg/kg 12/12h',
        '3. TEP de alto risco (choque/hipotensão): Trombólise sistêmica — Alteplase 100 mg IV em 2h (Contraindicações: AVC <3m, cirurgia <10d)',
        '4. Se contraindicação à trombólise: Embolectomia cirúrgica ou Trombectomia mecânica percutânea',
        '5. Suporte hemodinâmico: Noradrenalina 0,1–0,5 µg/kg/min, Dobutamina se disfunção VD',
        '6. O2 suplementar: SpO2 ≥ 94%. VNI ou IOT se insuficiência respiratória grave',
        '7. Filtro de VCI: apenas em contraindicação absoluta à anticoagulação',
        '8. Monitorar: ecocardiograma (disfunção VD?), troponina, BNP, lactato',
      ],
      'es': [
        '1. TEP bajo riesgo: Anticoagulación + alta precoz si PESI I–II',
        '2. Anticoagulación inmediata: Rivaroxabana 15 mg c/12 h × 21d o Enoxaparina 1 mg/kg c/12 h',
        '3. TEP alto riesgo (choque/hipotensión): Trombólisis — Alteplase 100 mg IV en 2 h',
        '4. Si contraindicación a trombólisis: Embolectomía quirúrgica',
        '5. Soporte hemodinámico: Noradrenalina + Dobutamina si disfunción VD',
        '6. O2: SpO2 ≥ 94%. VNI o IOT si insuficiencia respiratoria grave',
        '7. Filtro VCI: solo en contraindicación absoluta a anticoagulación',
        '8. Monitorizar: ecocardiograma, troponina, BNP, lactato',
      ],
    },
    avoid: {
      'pt': 'EVITAR heparina IM (usar SC ou IV). Não realizar trombólise em TEP hemodinamicamente estável (risco sangramento > benefício). Não interromper anticoagulação precocemente (mínimo 3 meses). Evitar repouso absoluto desnecessário (↑ risco TVP). Não usar D-dímero isolado em alta probabilidade pré-teste.',
      'es': 'EVITAR heparina IM. No realizar trombólisis en TEP hemodinámicamente estable. No interrumpir anticoagulación precoz (mín. 3 meses). No usar D-dímero aislado en alta probabilidad.',
    },
    drugs: ['enoxaparina', 'rivaroxabana', 'noradrenalina', 'dobutamina'],
  ),

  ProtocolModel(
    id: 'pneumonia_grave',
    title: {'pt': 'Pneumonia Adquirida na Comunidade (PAC) Grave — UTI', 'es': 'Neumonía Adquirida en la Comunidad (NAC) Grave — UTI'},
    severity: {'pt': 'Alto', 'es': 'Alto'},
    recognize: {
      'pt': 'Critérios de gravidade (ATS/IDSA): escore CURB-65 ≥3 ou critérios maiores (VM, choque séptico). Critérios menores: FR >30, PaO2/FiO2 <250, multilobar, confusão, ureia >20, leucopenia, trombocitopenia, hipotermia, hipotensão.',
      'es': 'Criterios CURB-65 ≥3 o criterios mayores (VM, choque séptico). Criterios menores: FR >30, PaO2/FiO2 <250, multilobar, confusión, urea >20.',
    },
    actions: {
      'pt': [
        '1. Antibiótico em <1h do diagnóstico (impacto em mortalidade)',
        '2. PAC-UTI sem risco Pseudomonas: Ceftriaxona 1–2 g IV/dia + Azitromicina 500 mg IV/dia',
        '3. PAC-UTI com risco Pseudomonas (DPOC, bronquiectasias, corticoterapia): Pip-Tazo + Azitromicina OU Cefepima + Azitromicina',
        '4. Moxifloxacino ou Levofloxacino (monoterapia) se betametol alérgico',
        '5. O2 suplementar: SpO2 92–96%. HFNI (high flow) ou VNI se hipoxemia refratária',
        '6. Sepse associada: bundle de sepse (ver protocolo sepse grave)',
        '7. Corticosteroide: Dexametasona 6 mg/dia × 5d se ventilado e PaO2/FiO2 <150',
        '8. Oseltamivir 75 mg 12/12h se suspeita de influenza grave',
      ],
      'es': [
        '1. Antibiótico en <1 h del diagnóstico',
        '2. NAC-UTI sin riesgo Pseudomonas: Ceftriaxona 1–2 g IV + Azitromicina 500 mg IV',
        '3. NAC-UTI con riesgo Pseudomonas: Pip-Tazo + Azitromicina O Cefepima + Azitromicina',
        '4. Moxifloxacino o Levofloxacino si alergia a betalactámico',
        '5. O2: SpO2 92–96%. HFNI o VNI si hipoxemia refractaria',
        '6. Sepsis asociada: bundle de sepsis',
        '7. Corticoide: Dexametasona 6 mg/día × 5d si ventilado y PaO2/FiO2 <150',
        '8. Oseltamivir 75 mg c/12 h si sospecha influenza grave',
      ],
    },
    avoid: {
      'pt': 'EVITAR atraso no antibiótico (cada hora de atraso aumenta mortalidade). Não usar cobertura anaeróbica de rotina (exceto broncoaspiração documentada). Evitar corticosteróide sistêmico fora das indicações (piora em influenza não complicada). Não manter antibióticos por mais de 5–7 dias se boa resposta clínica (risco de resistência e C. difficile).',
      'es': 'EVITAR retraso en antibiótico. No usar cobertura anaeróbica de rutina. Evitar corticoide sistémico fuera de indicaciones. No mantener antibióticos >5–7 días si buena respuesta.',
    },
    drugs: ['azitromicina', 'ceftriaxona', 'dexametasona', 'meropenem'],
  ),

  // ─────────────────────────────────────────────
  //  EMERGÊNCIA / UTI
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'choque_septico_avancado',
    title: {'pt': 'Sepse Grave e Choque Séptico — Bundle SSC 2021', 'es': 'Sepsis Grave y Choque Séptico — Bundle SSC 2021'},
    severity: {'pt': 'Crítico', 'es': 'Crítico'},
    recognize: {
      'pt': 'Sepse: disfunção orgânica ameaçadora (SOFA ≥2 pontos) causada por infecção suspeita/confirmada. Choque séptico: sepse + necessidade de vasopressor para PAM ≥65 mmHg + lactato >2 mmol/L na ausência de hipovolemia.',
      'es': 'Sepsis: disfunción orgánica (SOFA ≥2) causada por infección. Choque séptico: sepsis + vasopresor para PAM ≥65 mmHg + lactato >2 mmol/L sin hipovolemia.',
    },
    actions: {
      'pt': [
        '1. HORA 1 (bundle 1h): coletar culturas, dosar lactato, iniciar antibiótico',
        '2. Hemocultura 2 amostras de sítios diferentes ANTES do antibiótico',
        '3. Antibiótico empírico de amplo espectro em <1h: Pip-Tazo 4,5 g 6/6h + Vancomicina OU Meropenem 1–2g 8/8h',
        '4. Ressuscitação volêmica: SF/Ringer Lactato 30 mL/kg em ≤3h (avaliar responsividade)',
        '5. Noradrenalina: iniciar se PAM <65 após reposição volêmica — titular (0,01–1 µg/kg/min)',
        '6. Hidrocortisona 200 mg/dia IV contínuo (ou 50 mg 6/6h) se choque refratário (≥2 vasopressores)',
        '7. Controle glicêmico: alvo 140–180 mg/dL (protocolo insulina)',
        '8. Pacote 24h: ventilação protetora se IOT, controle de foco infeccioso, hemodiálise se necessário',
      ],
      'es': [
        '1. HORA 1 (bundle): cultivos, lactato, iniciar antibiótico',
        '2. Hemocultivo 2 muestras de sitios diferentes ANTES del antibiótico',
        '3. Antibiótico empírico amplio en <1 h: Pip-Tazo 4,5 g c/6 h + Vancomicina O Meropenem 1–2 g c/8 h',
        '4. Resucitación volémica: SF/Ringer Lactato 30 mL/kg en ≤3 h',
        '5. Noradrenalina: iniciar si PAM <65 tras reposición volémica',
        '6. Hidrocortisona 200 mg/día IV continuo si choque refractario (≥2 vasopresores)',
        '7. Control glucémico: objetivo 140–180 mg/dL',
        '8. Paquete 24 h: ventilación protectora si IOT, control foco infeccioso, hemodiálisis si necesario',
      ],
    },
    avoid: {
      'pt': 'EVITAR: atraso no antibiótico (>1h aumenta mortalidade ~7% por hora). Não usar coloides de amido (HES) — nefrotóxicos. Evitar ressuscitação volêmica excessiva (síndrome compartimental abdominal, EAP). Não usar corticosteroide como terapia primária (apenas em choque refratário). Evitar hiperglicemia e hipoglicemia (ambas pioram prognóstico).',
      'es': 'EVITAR: demora en antibiótico. No usar coloides de almidón (HES). Evitar resucitación volémica excesiva. No usar corticoide como terapia primaria. Evitar hiper e hipoglucemia.',
    },
    drugs: ['noradrenalina', 'meropenem', 'vancomicina', 'hidrocortisona', 'insulina_regular'],
  ),

  ProtocolModel(
    id: 'hiperpotassemia_grave',
    title: {'pt': 'Hiperpotassemia Grave (K+ ≥6,0 mEq/L)', 'es': 'Hiperpotasemia Grave (K+ ≥6,0 mEq/L)'},
    severity: {'pt': 'Alto', 'es': 'Alto'},
    recognize: {
      'pt': 'K+ ≥6,0 mEq/L (ou >5,5 com alterações ECG). ECG: ondas T apiculadas (>5,5) → PR longo, QRS largo, onda P desaparece → padrão sinusoidal → FV/assistolia. Causas: IRC, IECA/ARA2, espironolactona, betabloqueadores, hemólise, rabdomiólise.',
      'es': 'K+ ≥6,0 mEq/L o >5,5 con cambios ECG. ECG: ondas T picudas → PR largo, QRS ancho → patrón sinusoidal → FV/asistolia. Causas: IRC, IECA/ARA2, espironolactona.',
    },
    actions: {
      'pt': [
        '1. ECG imediato — qualquer alteração = EMERGÊNCIA',
        '2. Se alterações ECG (QRS largo, onda sinusoidal): Gluconato de Cálcio 1 g IV em 2–3 min (estabiliza membrana; repetir em 5 min se sem melhora)',
        '3. Shift K+ para intracelular: Insulina Regular 10 UI IV + Glicose 50% 50 mL (onset 15–30 min)',
        '4. Salbutamol nebulização 10–20 mg (agonista β2 — shift K+ intracelular)',
        '5. Bicarbonato de Sódio 50–100 mEq IV se acidose metabólica concomitante (pH <7,2)',
        '6. Remoção de K+: Resina de troca (patirômero/SPS) VO ou Hemodiálise (K+ >7 ou refratário)',
        '7. Suspender imediatamente: IECA, ARA2, poupadores de K+, suplementos de K+, AINEs',
        '8. Monitorar ECG continuamente e K+ a cada 2h até <5,5 mEq/L',
      ],
      'es': [
        '1. ECG inmediato — cualquier alteración = EMERGENCIA',
        '2. Si alteraciones ECG (QRS ancho): Gluconato de Calcio 1 g IV en 2–3 min',
        '3. Shift K+ intracelular: Insulina Regular 10 UI IV + Glucosa 50% 50 mL',
        '4. Salbutamol nebulización 10–20 mg (agonista β2)',
        '5. Bicarbonato de Sodio 50–100 mEq IV si acidosis metabólica (pH <7,2)',
        '6. Eliminación K+: Resina de intercambio (patirómero) VO o Hemodiálisis (K+ >7)',
        '7. Suspender: IECA, ARA2, ahorradores K+, AINEs',
        '8. ECG continuo y K+ c/2 h hasta <5,5 mEq/L',
      ],
    },
    avoid: {
      'pt': 'EVITAR: gluconato de cálcio em intoxicação digitálica (precipita arritmias fatais). Não tratar hiperpotassemia leve assintomática sem ECG. Não usar resinas como única medida em K+ >7 com alterações ECG (demora). Bicarbonato: eficácia limitada na ausência de acidose. Evitar IECA + ARA II + espironolactona juntos (tripla bloqueio do SRAA).',
      'es': 'EVITAR: gluconato de calcio en intoxicación digitálica (arritmias fatales). No usar resinas como única medida con K+ >7 y alteraciones ECG. Bicarbonato: eficacia limitada sin acidosis.',
    },
    drugs: ['bicarbonato_sodio', 'insulina_regular', 'cloreto_potassio'],
  ),

  ProtocolModel(
    id: 'intoxicacao_exogena',
    title: {'pt': 'Intoxicação Exógena Aguda — Abordagem Geral', 'es': 'Intoxicación Exógena Aguda — Abordaje General'},
    severity: {'pt': 'Alto', 'es': 'Alto'},
    recognize: {
      'pt': 'Identificar: substância, quantidade, tempo de exposição, via. Síndromes tóxicas: colinérgica (SLUDGE: salivação, lacrimejamento, diurese, GI, edema pulmonar — organofosforados), simpaticomimética (taquicardia, HAS, midríase — cocaína), anticolinérgica (seca, retro, confusão, midríase), opioide (tríade: coma + miose + FR↓).',
      'es': 'Identificar: sustancia, cantidad, tiempo, vía. Síndromes tóxicas: colinérgica (SLUDGE — organofosforados), simpaticomimética (cocaína), anticolinérgica, opioide (tríada: coma + miosis + FR↓).',
    },
    actions: {
      'pt': [
        '1. ABCDE: via aérea, IOT se Glasgow ≤8 ou aspiração',
        '2. Glicemia capilar + tiamina 100 mg IV (se alcoolismo) + Naloxona 0,4–2 mg IV/IM (se opioide)',
        '3. Carvão ativado 1 g/kg VO (até 50 g): eficaz se <1–2h ingesta, consciência preservada, sem cáustico/hidrocarboneto',
        '4. Organofosforados: Atropina 2–4 mg IV (titular pelos sintomas muscarínicos — secretomimético), Pralidoxima 1–2 g IV',
        '5. BZD: Flumazenil (cautela — convulsões em dependentes)',
        '6. Paracetamol: N-acetilcisteína 150 mg/kg IV em 60 min (nomograma Rumack-Matthew)',
        '7. Tricíclicos: Bicarbonato de sódio se QRS >120ms; Diazepam nas convulsões',
        '8. Contato com Centro de Informação Toxicológica: 0800-722-6001 (Brasil)',
      ],
      'es': [
        '1. ABCDE: vía aérea, IOT si Glasgow ≤8',
        '2. Glucemia + tiamina 100 mg IV (alcoholismo) + Naloxona 0,4–2 mg IV/IM (opioide)',
        '3. Carbón activado 1 g/kg VO (máx. 50 g): eficaz si <1–2 h ingesta, consciencia preservada',
        '4. Organofosforados: Atropina 2–4 mg IV, Pralidoxima 1–2 g IV',
        '5. BZD: Flumazenil (precaución — convulsiones en dependientes)',
        '6. Paracetamol: N-acetilcisteína 150 mg/kg IV en 60 min',
        '7. Tricíclicos: Bicarbonato si QRS >120ms; Diazepam en convulsiones',
        '8. Centro de información toxicológica local',
      ],
    },
    avoid: {
      'pt': 'EVITAR: lavagem gástrica de rotina (apenas seletivamente, <1h, proteger VA). Nunca carvão ativado em cáusticos/hidrocarbonetos/coma sem VA protegida. Flumazenil contraindicado em dependentes de BZD (convulsões) e uso crônico de epilépticos. Não induzir vômito (risco broncoaspiração). Evitar diálise sem indicação específica.',
      'es': 'EVITAR: lavado gástrico de rutina. Nunca carbón activado en cáusticos/hidrocarburos/coma. Flumazenil contraindicado en dependientes BZD. No inducir vómito.',
    },
    drugs: ['diazepam', 'midazolam', 'bicarbonato_sodio', 'noradrenalina'],
  ),

];
