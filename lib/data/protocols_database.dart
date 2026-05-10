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

  // ─────────────────────────────────────────────
  //  GASTROENTEROLOGIA
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'pancreatite_aguda_grave',
    title: {'pt': 'Pancreatite Aguda Grave', 'es': 'Pancreatitis Aguda Grave'},
    severity: {'pt': 'Crítico', 'es': 'Crítico'},
    recognize: {
      'pt': 'Dor abdominal epigástrica intensa irradiada para o dorso + lipase/amilase >3× o limite superior + TC com necrose ≥30% (Balthazar D–E). Critérios de gravidade: APACHE II ≥8, Ranson ≥3, PCR >150 mg/L em 48h, falência orgânica (Revised Atlanta Classification).',
      'es': 'Dolor epigástrico intenso irradiado al dorso + lipasa/amilasa >3× LSN + TC con necrosis ≥30% (Balthazar D–E). Criterios de gravedad: APACHE II ≥8, Ranson ≥3, PCR >150 mg/L en 48 h, falla orgánica.',
    },
    actions: {
      'pt': [
        '1. INTERNAÇÃO em UTI se falência orgânica (renal, respiratória, circulatória)',
        '2. Ressuscitação volêmica agressiva: Ringer Lactato 250–500 mL/h nas primeiras 12–24h (preferir RL — reduz acidose e necrose vs. SF)',
        '3. Analgesia: Morfina 2–4 mg IV ou Tramadol 100 mg IV (dor intensa); considerar analgesia epidural em casos graves',
        '4. Dieta: nada VO nas primeiras 24–48h; nutrição ENTERAL precoce (nasojejunal) preferível à parenteral em pancreatite grave',
        '5. Antibiótico NÃO é rotina — apenas se necrose infectada confirmada (PAAF com cultura ou deterioração clínica): Meropenem 1 g 8/8h IV',
        '6. Monitorar: débito urinário (alvo ≥0,5 mL/kg/h), creatinina, hematócrito, Ca²⁺, glicemia, gases arteriais',
        '7. CPRE em <24h se colangite associada (PAC biliar + obstrução/febre)',
        '8. Necrose infectada: drenagem guiada (endoscópica step-up ou cirúrgica) — não operar na fase inicial',
        '9. Colecistectomia eletiva antes da alta se etiologia biliar (previne recorrência)',
      ],
      'es': [
        '1. Internación en UTI si falla orgánica (renal, respiratoria, circulatoria)',
        '2. Resucitación volémica agresiva: Ringer Lactato 250–500 mL/h en primeras 12–24 h',
        '3. Analgesia: Morfina 2–4 mg IV o Tramadol 100 mg IV',
        '4. Dieta: nada VO primeras 24–48 h; nutrición ENTERAL precoz (nasoyeyunal) preferible a parenteral',
        '5. Antibiótico NO es rutina — solo si necrosis infectada confirmada: Meropenem 1 g c/8 h IV',
        '6. Monitorizar: diuresis (≥0,5 mL/kg/h), creatinina, hematocrito, Ca²⁺, glucemia, gases',
        '7. CPRE en <24 h si colangitis asociada (PA biliar + obstrucción/fiebre)',
        '8. Necrosis infectada: drenaje guiado (endoscópico step-up o quirúrgico)',
        '9. Colecistectomía electiva antes del alta si etiología biliar',
      ],
    },
    avoid: {
      'pt': 'EVITAR SF 0,9% em grandes volumes (acidose hiperclorêmica — usar RL). Não usar antibiótico profilático de rotina (sem benefício, seleciona resistentes). Evitar nutrição parenteral total rotineira (↑ infecção, custo). Não operar necrose estéril na fase aguda (primeiras 4 semanas). Evitar CPRE desnecessária sem colangite ou icterícia obstrutiva.',
      'es': 'EVITAR SF 0,9% en grandes volúmenes (acidosis hiperclorémica). No usar antibiótico profiláctico rutinario. Evitar nutrición parenteral total rutinaria. No operar necrosis estéril en fase aguda (primeras 4 semanas).',
    },
    drugs: ['meropenem', 'morfina', 'omeprazol', 'insulina_regular'],
  ),

  ProtocolModel(
    id: 'hda_nao_varicosa',
    title: {'pt': 'Hemorragia Digestiva Alta Não Varicosa', 'es': 'Hemorragia Digestiva Alta No Varicosa'},
    severity: {'pt': 'Alto', 'es': 'Alto'},
    recognize: {
      'pt': 'Hematêmese (vômito de sangue vivo ou em borra de café) e/ou melena. Causas: úlcera péptica (70%), erosões, síndrome de Mallory-Weiss, neoplasia. Escore de Glasgow-Blatchford (GBS) ≥1: necessita intervenção. Escore de Rockall pós-endoscopia: estratifica risco de ressangramento.',
      'es': 'Hematemesis (vómito de sangre viva o en posos de café) y/o melena. Causas: úlcera péptica (70%), erosiones, Mallory-Weiss, neoplasia. Glasgow-Blatchford ≥1: necesita intervención.',
    },
    actions: {
      'pt': [
        '1. 2 acessos venosos calibrosos (14–16G); SF 0,9% 500 mL se instabilidade',
        '2. Transfusão: Hb alvo 7–8 g/dL (restritiva) — Hb <9 g/dL em cardiopata ou idoso',
        '3. Plasma fresco + plaquetas se coagulopatia (INR >1,5 ou plaquetas <50.000)',
        '4. IBP: Omeprazol/Pantoprazol 80 mg IV bolus + 8 mg/h infusão contínua (reduz ressangramento)',
        '5. Endoscopia digestiva alta em <24h (estável) ou <12h (alto risco: Rockall ≥3, sangramento ativo)',
        '6. Tratamento endoscópico: injeção de adrenalina + clipagem ou termocoagulação (úlcera Forrest Ia–IIb)',
        '7. Se falha endoscópica: 2ª endoscopia; se persistir → arteriografia com embolização ou cirurgia',
        '8. Erradicação H. pylori após estabilização (reduz recorrência 80%)',
        '9. Suspender AINEs, AAS e anticoagulantes — reintroduzir com cautela conforme risco cardiovascular',
      ],
      'es': [
        '1. 2 accesos venosos calibrosos (14–16G); SF 0,9% 500 mL si inestabilidad',
        '2. Transfusión: Hb objetivo 7–8 g/dL (restrictiva)',
        '3. PFC + plaquetas si coagulopatía (INR >1,5 o plaquetas <50.000)',
        '4. IBP: Omeprazol/Pantoprazol 80 mg IV bolo + 8 mg/h infusión continua',
        '5. Endoscopia digestiva alta en <24 h (estable) o <12 h (alto riesgo)',
        '6. Tratamiento endoscópico: inyección adrenalina + clipado o termocoagulación',
        '7. Si falla endoscópica: 2ª endoscopia; si persiste → arteriografía/embolización o cirugía',
        '8. Erradicación H. pylori tras estabilización',
        '9. Suspender AINEs, AAS y anticoagulantes',
      ],
    },
    avoid: {
      'pt': 'EVITAR ressuscitação volêmica excessiva (↑ pressão portal → ressangramento varicoso). Não transfundir com Hb >9 g/dL em não cardiopatas (piora mortalidade). Evitar IBP VO no sangramento ativo grave (usar IV). Não realizar endoscopia sem estabilização mínima. Evitar sonda nasogástrica de rotina (não muda conduta, causa desconforto).',
      'es': 'EVITAR resucitación volémica excesiva. No transfundir con Hb >9 g/dL en no cardiopatas. Evitar IBP VO en sangrado activo grave. No realizar endoscopia sin estabilización mínima.',
    },
    drugs: ['omeprazol', 'noradrenalina', 'ceftriaxona'],
  ),

  // ─────────────────────────────────────────────
  //  NEFROLOGIA
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'lesao_renal_aguda',
    title: {'pt': 'Lesão Renal Aguda (LRA) — KDIGO', 'es': 'Lesión Renal Aguda (LRA) — KDIGO'},
    severity: {'pt': 'Alto', 'es': 'Alto'},
    recognize: {
      'pt': 'Critérios KDIGO: Cr ≥0,3 mg/dL em 48h OU Cr ≥1,5× basal em 7 dias OU diurese <0,5 mL/kg/h por ≥6h. Estágios: 1 (Cr 1,5–1,9× basal), 2 (Cr 2–2,9×), 3 (Cr ≥3× ou ≥4 mg/dL ou diálise). Causas: pré-renal (hipovolemia), intrínseca (NTA, GN, nefrite), pós-renal (obstrução).',
      'es': 'Criterios KDIGO: Cr ≥0,3 mg/dL en 48h O Cr ≥1,5× basal en 7d O diuresis <0,5 mL/kg/h por ≥6 h. Estadios 1–3. Causas: prerrenal (hipovolemia), intrínseca (NTA, GN), posrenal (obstrucción).',
    },
    actions: {
      'pt': [
        '1. Identificar e corrigir causa: volume (LRA pré-renal), suspender nefrotóxicos, desobstrução (pós-renal)',
        '2. Reposição volêmica se pré-renal: Ringer Lactato 250–500 mL IV em 30 min (avaliar resposta)',
        '3. Otimizar PAM ≥65 mmHg (vasopressor se necessário — não usar dopamina em dose "renal")',
        '4. Monitorar: balanço hídrico rigoroso, peso diário, débito urinário horário',
        '5. Ajustar doses de todos os medicamentos à função renal atual (antibióticos, HBPM, etc.)',
        '6. Evitar e suspender nefrotóxicos: AINEs, aminoglicosídeos, contraste iodado (se possível)',
        '7. Controle de complicações: hiperpotassemia (ver protocolo), acidose, hipervolemia',
        '8. Indicações de diálise de urgência (AEIOU): Acidose refratária, Eletrólitos (K+ >6,5), Intoxicação, Overload (sobrecarga volêmica), Uremia sintomática (encefalopatia, pericardite)',
        '9. Hemodiálise contínua (CRRT): preferida no choque séptico ou instabilidade hemodinâmica',
      ],
      'es': [
        '1. Identificar y corregir causa: volumen (LRA prerrenal), suspender nefrotóxicos, desobstrucción',
        '2. Reposición volémica si prerrenal: Ringer Lactato 250–500 mL IV en 30 min',
        '3. Optimizar PAM ≥65 mmHg (vasopresor si necesario — no usar dopamina "renal")',
        '4. Balance hídrico estricto, peso diario, diuresis horaria',
        '5. Ajustar dosis de todos los fármacos a función renal actual',
        '6. Evitar nefrotóxicos: AINEs, aminoglucósidos, contraste yodado',
        '7. Control complicaciones: hiperpotasemia, acidosis, hipervolemia',
        '8. Indicaciones diálisis urgente (AEIOU): Acidosis refractaria, Electrolitos (K+ >6,5), Intoxicación, Overload, Uremia sintomática',
        '9. Hemodiálisis continua (CRRT): preferida en choque séptico',
      ],
    },
    avoid: {
      'pt': 'NÃO usar dopamina em dose renal (sem evidência, pode ser deletéria). Evitar diuréticos de alça para converter oligúria em poliúria (não muda prognóstico). Não usar bicarbonato de rotina na acidose metabólica da LRA (exceto se pH <7,1 ou K+ alto). Contraste iodado: usar apenas se indispensável — pré-hidratar com SF ou RL.',
      'es': 'NO usar dopamina en dosis renal. Evitar diuréticos para convertir oliguria en poliuria. No usar bicarbonato rutinario en acidosis de LRA. Contraste yodado: solo si indispensable — prehidratar.',
    },
    drugs: ['furosemida', 'bicarbonato_sodio', 'noradrenalina', 'insulina_regular'],
  ),

  // ─────────────────────────────────────────────
  //  HEMATOLOGIA
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'coagulacao_intravascular',
    title: {'pt': 'Coagulação Intravascular Disseminada (CIVD)', 'es': 'Coagulación Intravascular Diseminada (CID)'},
    severity: {'pt': 'Crítico', 'es': 'Crítico'},
    recognize: {
      'pt': 'Ativação sistêmica da coagulação com consumo de fatores e plaquetas. Manifesta: sangramento difuso (pele, mucosas, sítios de punção) + trombose microvascular (IRA, SDRA, isquemia). Escore ISTH ≥5: CIVD manifesta. Lab: TP↑, TTPA↑, fibrinogênio↓, D-dímero↑↑, plaquetas↓↓. Causas: sepse, trauma grave, neoplasia, CID obstétrica, hemólise intravascular.',
      'es': 'Activación sistémica de coagulación con consumo de factores y plaquetas. Sangrado difuso + trombosis microvascular. Score ISTH ≥5: CID manifiesta. Lab: TP↑, TTPA↑, fibrinógeno↓, D-dímero↑↑, plaquetas↓↓.',
    },
    actions: {
      'pt': [
        '1. TRATAR A CAUSA SUBJACENTE — sem isso não há resolução da CIVD (antibiótico em sepse, parto/curetagem na CID obstétrica, quimioterapia na leucemia promielocítica)',
        '2. Plasma Fresco Congelado (PFC): 15–30 mL/kg IV se sangramento ativo + TP/TTPA >1,5× (repõe fatores)',
        '3. Concentrado de Plaquetas: se plaquetas <50.000 com sangramento, ou <20.000 profilático',
        '4. Crioprecipitado: 1 U/10 kg se fibrinogênio <1,5 g/L (repõe fibrinogênio, fator VIII, vWF)',
        '5. Vitamina K 10 mg IV se déficit nutricional ou anticoagulação prévia',
        '6. Heparina: indicada em CIVD trombótica predominante (isquemia de extremidades, leucemia pró-mielocítica) — CONTRAINDICADA na CIVD hemorrágica pura',
        '7. Ácido tranexâmico: apenas em CIVD com hiperfibrinólise dominante (trauma, LPA) — NÃO usar na CIVD séptica (trombogênico)',
        '8. Monitorar: fibrinogênio, plaquetas, TP, TTPA, D-dímero a cada 4–6h',
      ],
      'es': [
        '1. TRATAR LA CAUSA SUBYACENTE — sin esto no hay resolución (antibiótico en sepsis, parto en CID obstétrica)',
        '2. Plasma Fresco Congelado (PFC): 15–30 mL/kg IV si sangrado activo + TP/TTPA >1,5×',
        '3. Concentrado de plaquetas: si plaquetas <50.000 con sangrado, o <20.000 profiláctico',
        '4. Crioprecipitado: 1 U/10 kg si fibrinógeno <1,5 g/L',
        '5. Vitamina K 10 mg IV si déficit nutricional o anticoagulación previa',
        '6. Heparina: indicada en CID trombótica (isquemia extremidades, LPA) — CONTRAINDICADA en CID hemorrágica',
        '7. Ácido tranexámico: solo en CID con hiperfibrinólisis (trauma, LPA) — NO en CID séptica',
        '8. Monitorizar: fibrinógeno, plaquetas, TP, TTPA, D-dímero c/4–6 h',
      ],
    },
    avoid: {
      'pt': 'EVITAR ácido tranexâmico na CIVD séptica (risco de trombose fatal). Não repor fatores sem sangramento ativo apenas por resultados laboratoriais alterados ("tratamento de exame"). Heparina contraindicada na CIVD hemorrágica. Não usar aspirina nem AINEs. Evitar punções desnecessárias — pressão prolongada após procedimentos.',
      'es': 'EVITAR ácido tranexámico en CID séptica. No reponer factores sin sangrado activo solo por laboratorio alterado. Heparina contraindicada en CID hemorrágica. No usar aspirina ni AINEs.',
    },
    drugs: ['heparina_nf', 'enoxaparina', 'dexametasona', 'noradrenalina'],
  ),

  // ─────────────────────────────────────────────
  //  TRAUMA / EMERGÊNCIA
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'politrauma_atls',
    title: {'pt': 'Politrauma — Abordagem ATLS (Primary Survey)', 'es': 'Politrauma — Abordaje ATLS (Primary Survey)'},
    severity: {'pt': 'Crítico', 'es': 'Crítico'},
    recognize: {
      'pt': 'Vítima de trauma de alta energia: acidente de trânsito, queda de altura, projétil de arma de fogo. Avaliar mecanismo e transferência de energia. Mortalidade trimodal: imediata (ruptura aórtica), precoce (hemorragia/hipóxia — tratável), tardia (SIRS/infecção).',
      'es': 'Víctima de trauma de alta energía: accidente de tráfico, caída de altura, proyectil. Mortalidad trimodal: inmediata, precoz (hemorragia/hipoxia — tratable), tardía (SIRS/infección).',
    },
    actions: {
      'pt': [
        'A — AIRWAY + controle cervical: avaliar perviedade, IOT se Glasgow ≤8 ou via aérea comprometida. Colar cervical + prancha longa até excluir lesão.',
        'B — BREATHING: oxigênio 15L/min máscara; ausculta bilateral; tratar pneumotórax hipertensivo (agulha 2º EIC LMC) e hemotórax (dreno 28–32F em 5º EIC LAA)',
        'C — CIRCULATION + controle de hemorragia: 2 acessos periféricos calibrosos; Ringer Lactato 1L IV rápido; compressão de sangramento externo; pelve estável (fajas/tração); FAST eco para hemoperitoneu',
        'D — DISABILITY: Glasgow (olhos + verbal + motor), pupilas, déficit motor/sensitivo; glicemia capilar',
        'E — EXPOSURE + controle ambiental: expor completamente; cobrir após exame (hipotermia = morte)',
        '6. Controle de danos (Damage Control): ressuscitação hemostática — razão 1:1:1 (CH:PFC:plaquetas). Ácido Tranexâmico 1 g IV em 10 min (se <3h do trauma)',
        '7. Hipotensão permissiva pré-operatória: PAM 50–65 mmHg se hemorragia incontrolada (reduz coagulopatia dilucional)',
        '8. Transferir para centro de trauma nível I se necessário; acionamento de cirurgia de emergência se FAST+/instável',
      ],
      'es': [
        'A — AIRWAY + control cervical: evaluar permeabilidad, IOT si Glasgow ≤8. Collarín + tabla larga.',
        'B — BREATHING: O2 15 L/min; auscultación bilateral; neumotórax hipertensivo (aguja 2º EIC LMC); hemotórax (drenaje 28–32F en 5º EIC LAA)',
        'C — CIRCULATION: 2 accesos periféricos calibrosos; Ringer Lactato 1L IV; compresión sangrado externo; pelvis estable; FAST eco',
        'D — DISABILITY: Glasgow, pupilas, déficit motor/sensitivo; glucemia',
        'E — EXPOSURE: exponer completamente; cubrir tras examen (hipotermia = muerte)',
        '6. Control de daños: resucitación hemostática 1:1:1 (GR:PFC:plaquetas). Ácido Tranexámico 1 g IV en 10 min (si <3 h del trauma)',
        '7. Hipotensión permisiva preoperatoria: PAM 50–65 mmHg si hemorragia incontrolable',
        '8. Trasladar a centro de trauma nivel I; cirugía de emergencia si FAST+/inestable',
      ],
    },
    avoid: {
      'pt': 'EVITAR ressuscitação com grandes volumes de SF (acidose hiperclorêmica + coagulopatia dilucional — usar RL e sangue). Não mobilizar coluna sem estabilização adequada. Evitar hipotermia (<35°C inicia coagulopatia — tríade da morte: hipotermia + acidose + coagulopatia). Não realizar TC se paciente instável (sala de cirurgia primeiro). Ácido tranexâmico: sem benefício se >3h do trauma.',
      'es': 'EVITAR resucitación con grandes volúmenes de SF. No movilizar columna sin estabilización. Evitar hipotermia (tríada de la muerte). No TC si inestable (quirófano primero). Ácido tranexámico: sin beneficio si >3 h del trauma.',
    },
    drugs: ['noradrenalina', 'adrenalina', 'morfina', 'midazolam'],
  ),

  // ─────────────────────────────────────────────
  //  OBSTETRÍCIA
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'eclampsia_hellp',
    title: {'pt': 'Eclâmpsia e Síndrome HELLP', 'es': 'Eclampsia y Síndrome HELLP'},
    severity: {'pt': 'Crítico', 'es': 'Crítico'},
    recognize: {
      'pt': 'ECLÂMPSIA: pré-eclâmpsia + convulsão (sem outra causa). HELLP: Hemólise (LDH >600, esquizócitos) + Enzimas hepáticas elevadas (AST/ALT >70 UI/L) + Plaquetas Baixas (<100.000). Sinais de alarme: cefaleia intensa, epigastralgia, escotomas, anasarca.',
      'es': 'ECLAMPSIA: preeclampsia + convulsión. HELLP: Hemólisis (LDH >600) + Enzimas hepáticas elevadas (AST/ALT >70) + Plaquetas Bajas (<100.000). Alarmas: cefalea intensa, epigastralgia, escotomas.',
    },
    actions: {
      'pt': [
        '1. DECÚBITO LATERAL ESQUERDO; O2 10 L/min máscara; acesso venoso bilateral calibroso',
        '2. Sulfato de Magnésio (anticonvulsivante de 1ª linha): 4–6 g IV em 15–20 min (ataque) + 1–2 g/h IV (manutenção). Manter por 24–48h pós-parto',
        '3. Controle de PA: meta PA <160/110 mmHg. Hidralazina 5–10 mg IV (repetir em 20 min) OU Labetalol 20–80 mg IV OU Nifedipina 10–20 mg VO (liberação imediata)',
        '4. Corticosteroide fetal se <34 semanas: Betametasona 12 mg IM 24/24h × 2 doses',
        '5. HELLP: Dexametasona 10 mg IV 12/12h (melhora plaquetas e enzimas — uso controverso, mas amplo na prática)',
        '6. Se convulsão refratária ao MgSO4: Diazepam 10 mg IV ou Lorazepam 4 mg IV',
        '7. INTERRUPÇÃO DA GESTAÇÃO: único tratamento definitivo. Parto vaginal (se condições) ou cesárea de urgência',
        '8. Antídoto do MgSO4 (intoxicação — abolição de reflexos, apneia): Gluconato de Cálcio 1 g IV lento',
        '9. Monitorar: reflexo patelar (abolido = toxicidade MgSO4), FR, diurese, plaquetas, função hepática',
      ],
      'es': [
        '1. DECÚBITO LATERAL IZQUIERDO; O2 10 L/min; acceso venoso bilateral',
        '2. Sulfato de Magnesio: 4–6 g IV en 15–20 min (ataque) + 1–2 g/h IV (mantenimiento). Mantener 24–48 h posparto',
        '3. Control PA: meta <160/110 mmHg. Hidralazina 5–10 mg IV O Labetalol 20–80 mg IV O Nifedipina 10–20 mg VO',
        '4. Corticoide fetal si <34 semanas: Betametasona 12 mg IM c/24 h × 2 dosis',
        '5. HELLP: Dexametasona 10 mg IV c/12 h',
        '6. Si convulsión refractaria: Diazepam 10 mg IV o Lorazepam 4 mg IV',
        '7. INTERRUPCIÓN GESTACIÓN: único tratamiento definitivo',
        '8. Antídoto MgSO4 (toxicidad): Gluconato de Calcio 1 g IV lento',
        '9. Monitorizar: reflejo patelar, FR, diuresis, plaquetas, función hepática',
      ],
    },
    avoid: {
      'pt': 'EVITAR diazepam como 1ª linha anticonvulsivante (MgSO4 é superior na eclâmpsia). Não baixar PA abruptamente (hipoperfusão uteroplacentária → sofrimento fetal). Nifedipina sublingual: CONTRAINDICADA (queda abrupta). Evitar sulfato de magnésio IV rápido (parada cardíaca). IECA e ARA II são CONTRAINDICADOS na gestação. Não usar AAS em dose plena.',
      'es': 'EVITAR diazepam como 1ª línea (MgSO4 es superior). No bajar PA abruptamente (hipoperfusión uteroplacentaria). Nifedipina sublingual: CONTRAINDICADA. Evitar MgSO4 IV rápido (paro cardíaco). IECA y ARA II CONTRAINDICADOS en gestación.',
    },
    drugs: ['sulfato_magnesio', 'dexametasona', 'metoprolol', 'diazepam'],
  ),

  // ─────────────────────────────────────────────
  //  ENDOCRINOLOGIA
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'crise_adrenal',
    title: {'pt': 'Crise Adrenal (Insuficiência Adrenal Aguda)', 'es': 'Crisis Adrenal (Insuficiencia Adrenal Aguda)'},
    severity: {'pt': 'Crítico', 'es': 'Crítico'},
    recognize: {
      'pt': 'Hipotensão refratária + náuseas/vômitos + dor abdominal + hipoglicemia + hiponatremia + hiperpotassemia em paciente com doença de Addison, corticoterapia crônica interrompida, ou infecção severa/cirurgia em paciente em uso de corticoides. Pigmentação cutânea (Addison primária). Síndrome de Waterhouse-Friderichsen (meningococcemia).',
      'es': 'Hipotensión refractaria + náuseas/vómitos + dolor abdominal + hipoglucemia + hiponatremia + hiperpotasemia. Pigmentación cutánea (Addison primaria). Síndrome de Waterhouse-Friderichsen (meningococemia).',
    },
    actions: {
      'pt': [
        '1. NÃO ATRASAR tratamento para aguardar exames — tratar empiricamente se suspeita forte',
        '2. Hidrocortisona 100 mg IV bolus IMEDIATAMENTE, depois 50–100 mg IV 6/6h (ou 200 mg/24h em infusão contínua)',
        '3. Ressuscitação volêmica: SF 0,9% 1 L IV rápido (primeira hora), depois 500 mL/h conforme resposta (corrige hipovolemia e hiponatremia)',
        '4. Glicose: SG 5–10% se hipoglicemia (<60 mg/dL); manter glicemia >100 mg/dL',
        '5. Identificar e tratar fator precipitante: infecção (hemoculturas + antibiótico), cirurgia, trauma, omissão de corticoide',
        '6. Monitorar: PA, glicemia, sódio, potássio, cortisol e ACTH (coletar antes da hidrocortisona se possível)',
        '7. Transição VO: iniciar assim que possível — Hidrocortisona 20–30 mg/dia em 2–3 doses (manhã 2/3, tarde 1/3)',
        '8. Orientar paciente: cartão de alerta, dose de estresse (dobrar/triplicar em doença febril), aplicar hidrocortisona IM em emergência (100 mg ampola para casa)',
      ],
      'es': [
        '1. NO RETRASAR tratamiento para exámenes — tratar empíricamente si fuerte sospecha',
        '2. Hidrocortisona 100 mg IV bolo INMEDIATAMENTE, luego 50–100 mg IV c/6 h',
        '3. Resucitación volémica: SF 0,9% 1 L IV rápido, luego 500 mL/h según respuesta',
        '4. Glucosa: SG 5–10% si hipoglucemia (<60 mg/dL)',
        '5. Identificar y tratar precipitante: infección (hemocultivos + antibiótico), cirugía, omisión de corticoide',
        '6. Monitorizar: PA, glucemia, sodio, potasio, cortisol y ACTH (antes de hidrocortisona si posible)',
        '7. Transición VO: Hidrocortisona 20–30 mg/día en 2–3 dosis',
        '8. Orientar paciente: tarjeta de alerta, dosis de estrés, hidrocortisona IM en emergencia',
      ],
    },
    avoid: {
      'pt': 'NUNCA atrasar hidrocortisona por esperar cortisol (perda de minutos é fatal). Não usar dexametasona de rotina (não interfere no cortisol sérico para diagnóstico, mas falta efeito mineralocorticoide). Evitar hipoglicemia e hipernatremia na ressuscitação. Não suspender corticoide abruptamente em uso crônico. Vasopressores: usar apenas como ponte — a hidrocortisona é o tratamento definitivo.',
      'es': 'NUNCA retrasar hidrocortisona esperando cortisol. No usar dexametasona de rutina (falta efecto mineralocorticoide). Evitar hipoglucemia e hipernatremia. No suspender corticoide abruptamente en uso crónico. Vasopresores: solo como puente.',
    },
    drugs: ['dexametasona', 'noradrenalina', 'insulina_regular'],
  ),

  // ─────────────────────────────────────────────
  //  PSIQUIATRIA DE EMERGÊNCIA
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'agitacao_psicomotora',
    title: {'pt': 'Agitação Psicomotora Grave — Sedação de Emergência', 'es': 'Agitación Psicomotora Grave — Sedación de Emergencia'},
    severity: {'pt': 'Alto', 'es': 'Alto'},
    recognize: {
      'pt': 'Hiperatividade motora, agressividade, desorientação, risco para si e outros. Causas orgânicas SEMPRE descartar primeiro (AEIOU-TIPPS): Álcool/abstinência, Epilepsia, Infecção (meningite), Overdose, Uremia | Trauma, Insulina (hipo), Psiquiátrico, Psicose, AVC. Glicemia capilar OBRIGATÓRIA.',
      'es': 'Hiperactividad motora, agresividad, desorientación, riesgo para sí y otros. Causas orgánicas SIEMPRE descartar (AEIOU-TIPPS). Glucemia capilar OBLIGATORIA.',
    },
    actions: {
      'pt': [
        '1. SEGURANÇA: contenção física com pelo menos 4–5 pessoas; retirar objetos perigosos; não ficar sozinho',
        '2. Glicemia capilar imediata + oximetria; corrigir hipoglicemia antes de qualquer sedação',
        '3. ABORDAGEM VERBAL: ambiente calmo, falar devagar e diretamente, oferecer medicação VO primeiro',
        '4. SEDAÇÃO VO (preferível se aceitar): Olanzapina 10 mg VO OU Haloperidol 5–10 mg VO + Lorazepam 1–2 mg VO',
        '5. SEDAÇÃO IM (recusa ou urgência): Midazolam 5–10 mg IM + Haloperidol 5 mg IM — início rápido (5–15 min)',
        '6. Alternativa IM: Droperidol 5–10 mg IM (muito eficaz, monitorar QTc) ou Ziprasidona 10–20 mg IM',
        '7. Agitação por abstinência alcoólica: Diazepam 10–20 mg IV/IM titulado (protocolo CIWA)',
        '8. Monitorar: SpO2, FR, PA, nível de consciência a cada 15 min após sedação',
        '9. Após sedação: investigar causa orgânica (exames, TC se trauma)',
      ],
      'es': [
        '1. SEGURIDAD: contención física con ≥4–5 personas; retirar objetos peligrosos',
        '2. Glucemia capilar + oximetría; corregir hipoglucemia antes de sedación',
        '3. ABORDAJE VERBAL: ambiente calmo, hablar despacio, ofrecer medicación VO primero',
        '4. SEDACIÓN VO (si acepta): Olanzapina 10 mg VO O Haloperidol 5–10 mg VO + Lorazepam 1–2 mg VO',
        '5. SEDACIÓN IM (urgencia): Midazolam 5–10 mg IM + Haloperidol 5 mg IM',
        '6. Alternativa IM: Droperidol 5–10 mg IM o Ziprasidona 10–20 mg IM',
        '7. Abstinencia alcohólica: Diazepam 10–20 mg IV/IM titulado (protocolo CIWA)',
        '8. Monitorizar: SpO2, FR, PA, consciencia c/15 min post-sedación',
        '9. Tras sedación: investigar causa orgánica',
      ],
    },
    avoid: {
      'pt': 'NUNCA sedar antes de excluir hipoglicemia. Evitar haloperidol em abstinência alcoólica (↓ limiar convulsivo). Não usar benzodiazepínico isolado em psicose (pode piorar desinibição). Contenção física: máximo 4 pontos com monitoração contínua — nunca em decúbito ventral (morte por asfixia posicional). Evitar antipsicóticos fenotiazínicos (clorpromazina) em epilepsia.',
      'es': 'NUNCA sedar antes de excluir hipoglucemia. Evitar haloperidol en abstinencia alcohólica (↓ umbral convulsivo). No usar benzodiazepínico solo en psicosis. Contención física: máx. 4 puntos con monitoreo — nunca decúbito ventral (asfixia posicional). Evitar antipsicóticos fenotiazínicos en epilepsia.',
    },
    drugs: ['midazolam', 'diazepam', 'haloperidol'],
  ),

  // ─────────────────────────────────────────────
  //  ONCOLOGIA DE EMERGÊNCIA
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'neutropenia_febril',
    title: {'pt': 'Neutropenia Febril — Emergência Oncológica', 'es': 'Neutropenia Febril — Emergencia Oncológica'},
    severity: {'pt': 'Crítico', 'es': 'Crítico'},
    recognize: {
      'pt': 'Neutrófilos <500/mm³ (ou <1000/mm³ com tendência a cair) + temperatura axilar ≥38,3°C (ou ≥38°C por ≥1h). Paciente oncológico em quimioterapia. Risco ALTO (MASCC <21 ou CISNE ≥3): internação obrigatória. Risco BAIXO (MASCC ≥21, CISNE 0–2): pode considerar ATB VO ambulatorial.',
      'es': 'Neutrófilos <500/mm³ + temperatura axilar ≥38,3°C. Paciente oncológico en quimioterapia. Riesgo ALTO (MASCC <21): internación obligatoria. Riesgo BAJO (MASCC ≥21): puede considerar ATB VO ambulatorio.',
    },
    actions: {
      'pt': [
        '1. ANTIBIÓTICO EM <60 MIN DA CHEGADA (mortalidade ↑ com atraso)',
        '2. Hemoculturas: 2 amostras periféricas + de cada lúmen do cateter central ANTES do ATB',
        '3. Exames: hemograma, função renal/hepática, PCR, lactato, eletrólitos, RX tórax',
        '4. ATB 1ª linha (sem foco e sem risco de MRSA/Pseudomonas resistente): Piperacilina-Tazobactam 4,5 g IV 6/6h',
        '5. Com risco de Pseudomonas resistente (colonizado, ATB recente, unidade endêmica): Cefepima 2 g IV 8/8h ou Meropenem 1 g IV 8/8h',
        '6. Adicionar Vancomicina 25–30 mg/kg/dia se: cateter infectado, mucosite grave, pneumonia, MRSA colonizado, sepse grave',
        '7. Antifúngico (fluconazol ou equinocandina): se febre persistente >4–7 dias sem foco (fungemia)',
        '8. Fator estimulador G-CSF: considerar em neutropenia grave prolongada (não rotina)',
        '9. Alta: apenas após ≥48h afebril, neutrófilos em recuperação (>500/mm³ ou tendência), sem instabilidade',
      ],
      'es': [
        '1. ANTIBIÓTICO EN <60 MIN DE LA LLEGADA',
        '2. Hemocultivos: 2 muestras periféricas + de cada lúmen del catéter central ANTES del ATB',
        '3. Exámenes: hemograma, función renal/hepática, PCR, lactato, RX tórax',
        '4. ATB 1ª línea (sin foco y sin riesgo MRSA/Pseudomonas): Piperacilina-Tazobactam 4,5 g IV c/6 h',
        '5. Riesgo Pseudomonas resistente: Cefepima 2 g IV c/8 h o Meropenem 1 g IV c/8 h',
        '6. Agregar Vancomicina si: catéter infectado, mucositis grave, neumonía, MRSA colonizado',
        '7. Antifúngico: si fiebre persistente >4–7 días sin foco',
        '8. G-CSF: considerar en neutropenia grave prolongada',
        '9. Alta: tras ≥48 h afebril, neutrófilos en recuperación (>500/mm³)',
      ],
    },
    avoid: {
      'pt': 'NUNCA atrasar antibiótico aguardando resultados de exames. Não usar quinolona como 1ª linha se paciente já em profilaxia com quinolona (resistência). Evitar aminoglicosídeo em monoterapia (nefrotóxico em neutropênicos). Não usar antifúngico profilático universalmente (reservar para neutropenia prolongada >7d). Evitar alta precoce antes de recuperação de neutrófilos.',
      'es': 'NUNCA retrasar antibiótico esperando resultados. No usar quinolona como 1ª línea si ya en profilaxis. Evitar aminoglucósido en monoterapia. No usar antifúngico profiláctico universal. Evitar alta precoz antes de recuperación de neutrófilos.',
    },
    drugs: ['piperacilina_tazobactam', 'vancomicina', 'meropenem', 'ceftriaxona'],
  ),

  // ─────────────────────────────────────────────
  //  PEDIATRIA
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'pcr_pediatrica',
    title: {'pt': 'Parada Cardiorrespiratória Pediátrica (PALS)', 'es': 'Paro Cardiorrespiratorio Pediátrico (PALS)'},
    severity: {'pt': 'Crítico', 'es': 'Crítico'},
    recognize: {
      'pt': 'Ausência de responsividade + ausência de respiração normal + ausência de pulso central (<10 s). Lactente: pulso braquial/femoral. Criança: pulso carotídeo/femoral. Ritmos mais comuns em pediatria: assistolia e AESP (>80%). FV/TV sem pulso: menos frequente, mais em cardiopatas.',
      'es': 'Ausencia de responsividad + ausencia de respiración normal + ausencia de pulso central (<10 s). Lactante: pulso braquial/femoral. Niño: pulso carotídeo/femoral. Ritmos más comunes: asistolia y AESP (>80%).',
    },
    actions: {
      'pt': [
        '1. CHAMAR AJUDA + desfibrilador + timer',
        '2. RCP de alta qualidade: relação 15:2 (2 socorristas) ou 30:2 (1 socorrista). Compressões: 1/3 do diâmetro AP do tórax (~4 cm lactente, ~5 cm criança). 100–120/min.',
        '3. RITMOS NÃO CHOCÁVEIS (Assistolia/AESP — maioria pediátrica):',
        '   → Adrenalina 0,01 mg/kg IV/IO a cada 3–5 min (máx. 1 mg/dose)',
        '   → Tratar causas reversíveis: 5H5T',
        '4. RITMOS CHOCÁVEIS (FV/TV sem pulso):',
        '   → Desfibrilação 2 J/kg (1ª dose) → 4 J/kg (doses seguintes)',
        '   → Adrenalina 0,01 mg/kg IV/IO a partir do 2º ciclo',
        '   → Amiodarona 5 mg/kg IV/IO bolus (FV/TV refratária)',
        '5. VIA AÉREA: BVM com O2 100%, relação compressão:ventilação 15:2 sem IOT; após IOT ventilação assíncrona 10 rpm',
        '6. ACESSO: IO (intraósseo) se sem acesso venoso após 2 tentativas (tíbia proximal)',
        '7. TRATAR 5H5T: hipóxia (causa mais comum em pediatria!), hipovolemia, hipotermia, hipo/hiperpotassemia, H+ (acidose) | pneumotórax, tamponamento, trombose, tóxicos',
        '8. ROSC: iniciar protocolo pós-PCR; controle de temperatura 36–37,5°C (evitar febre)',
      ],
      'es': [
        '1. LLAMAR AYUDA + desfibrilador + timer',
        '2. RCP de alta calidad: 15:2 (2 reanimadores) o 30:2 (1 reanimador). Compresiones: 1/3 diámetro AP del tórax. 100–120/min.',
        '3. RITMOS NO CHOCABLES (Asistolia/AESP — mayoría pediátrica):',
        '   → Adrenalina 0,01 mg/kg IV/IO c/3–5 min (máx. 1 mg/dosis)',
        '   → Tratar causas reversibles: 5H5T',
        '4. RITMOS CHOCABLES (FV/TV sin pulso):',
        '   → Desfibrilación 2 J/kg (1ª dosis) → 4 J/kg (siguientes)',
        '   → Adrenalina 0,01 mg/kg IV/IO a partir del 2º ciclo',
        '   → Amiodarona 5 mg/kg IV/IO bolo (FV/TV refractaria)',
        '5. VÍA AÉREA: BVM con O2 100%; tras IOT ventilación asíncrona 10 rpm',
        '6. ACCESO: IO (intraóseo) si sin acceso venoso en 2 intentos (tibia proximal)',
        '7. TRATAR 5H5T: hipoxia (causa más común en pediatría), hipovolemia, hipotermia, hipo/hiperpotasemia, H+ (acidosis) | neumotórax, taponamiento, trombosis, tóxicos',
        '8. ROSC: protocolo post-PCR; control temperatura 36–37,5°C',
      ],
    },
    avoid: {
      'pt': 'NUNCA interromper RCP por >10 s. Não hiperventilar (↑ pressão intratorácica → ↓ retorno venoso). Adrenalina em dose alta (0,1 mg/kg) não melhora sobrevida e pode piorar desfecho neurológico. Não desfibrilhar com >4 J/kg (sem benefício adicional).',
      'es': 'NUNCA interrumpir RCP por >10 s. No hiperventilar. Adrenalina en dosis alta (0,1 mg/kg) no mejora sobrevida. No desfibrilar con >4 J/kg.',
    },
    drugs: ['adrenalina', 'amiodarona', 'bicarbonato_sodio', 'cloreto_potassio'],
  ),

  ProtocolModel(
    id: 'bronquiolite_aguda',
    title: {'pt': 'Bronquiolite Aguda Viral (Lactente)', 'es': 'Bronquiolitis Aguda Viral (Lactante)'},
    severity: {'pt': 'Médio', 'es': 'Medio'},
    recognize: {
      'pt': 'Lactente <2 anos com primeiro episódio de sibilância + coriza + tosse + taquipneia + retrações. Pico: novembro–março (VSR). Grave: FR >70 rpm, SpO2 <92%, apneia, recusa alimentar, letargia, retrações intensas.',
      'es': 'Lactante <2 años con primer episodio de sibilancias + coriza + tos + taquipnea + retracciones. Pico: noviembre–marzo (VSR). Grave: FR >70 rpm, SpO2 <92%, apnea, rechazo alimentario.',
    },
    actions: {
      'pt': [
        '1. SUPORTE é o tratamento principal — não existe tratamento farmacológico de eficácia comprovada',
        '2. O2 suplementar se SpO2 <92%: cateter nasal 0,5–2 L/min ou máscara',
        '3. Alto fluxo nasal (HFN): 2 L/kg/min se SpO2 refratária ou esforço respiratório intenso — reduz intubação',
        '4. Hidratação: via oral se possível; SNE ou IV se recusa alimentar ou FR >60 rpm (risco broncoaspiração)',
        '5. Aspiração de vias aéreas superiores delicada (não profunda) — melhora sintomas',
        '6. Posição: cabeceira 30°',
        '7. Adrenalina nebulizada 3 mg (0,5 mL de 1:1000 diluída): pode ser tentada em internados — efeito transitório, não muda hospitalização',
        '8. Monitorar: FR, SpO2, sinais de apneia, hidratação, dificuldade alimentar',
        '9. Critérios de alta: SpO2 ≥95%, FR <60 rpm, boa aceitação alimentar, sem retrações importantes',
      ],
      'es': [
        '1. SOPORTE es el tratamiento principal — no existe tratamiento farmacológico de eficacia comprobada',
        '2. O2 suplementario si SpO2 <92%: cánula nasal 0,5–2 L/min o mascarilla',
        '3. Alto flujo nasal (HFN): 2 L/kg/min si SpO2 refractaria o esfuerzo respiratorio intenso',
        '4. Hidratación: vía oral si posible; SNG o IV si rechazo alimentario o FR >60 rpm',
        '5. Aspiración de vías aéreas superiores delicada',
        '6. Posición: cabecera 30°',
        '7. Adrenalina nebulizada 3 mg: puede intentarse en internados — efecto transitorio',
        '8. Monitorizar: FR, SpO2, apnea, hidratación, dificultad alimentaria',
        '9. Criterios de alta: SpO2 ≥95%, FR <60 rpm, buena aceptación alimentaria',
      ],
    },
    avoid: {
      'pt': 'NÃO usar: broncodilatadores de rotina (salbutamol — sem evidência em <2 anos com 1º episódio), corticoides sistêmicos (sem benefício comprovado), antibióticos (causa viral), fisioterapia respiratória (sem benefício, aumenta desconforto). Evitar aspiração profunda (lesiona mucosa). Não hiperhidratar (risco de hiponatremia dilucional — SIADH frequente).',
      'es': 'NO usar: broncodilatadores de rutina (sin evidencia en <2 años, 1er episodio), corticoides sistémicos, antibióticos (causa viral), fisioterapia respiratoria. Evitar aspiración profunda. No hiperhidratar (riesgo hiponatremia dilucional).',
    },
    drugs: ['salbutamol', 'adrenalina', 'dexametasona'],
  ),

  ProtocolModel(
    id: 'laringite_estridulosa',
    title: {'pt': 'Laringite Estridulosa (Crupe Viral)', 'es': 'Laringitis Estridulosa (Crup Viral)'},
    severity: {'pt': 'Médio', 'es': 'Medio'},
    recognize: {
      'pt': 'Criança 6 meses–3 anos. Tosse "ladrante" (crup), estridor inspiratório, rouquidão + coriza prévia. Início noturno. Escore de Westley: leve (<3), moderado (3–5), grave (6–11), iminência de falência (≥12). Grave: estridor em repouso + retração intensa + agitação/letargia.',
      'es': 'Niño 6 meses–3 años. Tos "perruna" (crup), estridor inspiratorio, ronquera + coriza previa. Inicio nocturno. Score de Westley: leve (<3), moderado (3–5), grave (6–11), inminencia de falla (≥12).',
    },
    actions: {
      'pt': [
        '1. CRUPE LEVE (estridor apenas ao choro/agitação, sem retração em repouso):',
        '   → Dexametasona 0,15–0,6 mg/kg VO/IM/IV dose única (máx. 10 mg) — reduz hospitalização e retorno',
        '   → Orientar pais: inalação de ar úmido frio (duvidosa), retornar se piora',
        '2. CRUPE MODERADO (estridor em repouso leve, retração discreta):',
        '   → Dexametasona 0,6 mg/kg IM/IV + observação 4h',
        '   → Adrenalina nebulizada L-epinefrina 5 mL de 1:1000 (ou adrenalina 2% 0,5 mL/kg) — efeito em 15–30 min, duração 2h',
        '3. CRUPE GRAVE (estridor em repouso intenso, retrações graves, agitação/letargia):',
        '   → Dexametasona 0,6 mg/kg IV IMEDIATO',
        '   → Adrenalina nebulizada — pode repetir em 20–30 min se necessário',
        '   → O2 por máscara; posição confortável (colo dos pais se possível)',
        '   → Preparar para IOT se deterioração: lâmina menor que o habitual, tubo 0,5 mm menor',
        '4. Internar se crupe grave, 2 doses de adrenalina, <6 meses ou <3 meses, SpO2 <92%',
        '5. Alta 2–4h após adrenalina se melhora mantida (efeito rebote até 2h)',
      ],
      'es': [
        '1. CRUP LEVE (estridor solo al llanto, sin retracción en reposo):',
        '   → Dexametasona 0,15–0,6 mg/kg VO/IM/IV dosis única (máx. 10 mg)',
        '   → Orientar padres: regresar si empeora',
        '2. CRUP MODERADO (estridor en reposo leve, retracción discreta):',
        '   → Dexametasona 0,6 mg/kg IM/IV + observación 4 h',
        '   → Adrenalina nebulizada L-epinefrina 5 mL de 1:1000',
        '3. CRUP GRAVE (estridor intenso, retracciones graves, agitación/letargia):',
        '   → Dexametasona 0,6 mg/kg IV INMEDIATO',
        '   → Adrenalina nebulizada — repetir en 20–30 min si necesario',
        '   → O2 por mascarilla; posición cómoda',
        '   → Preparar IOT si deterioro: tubo 0,5 mm menor',
        '4. Internar si crup grave, 2 dosis adrenalina, <6 meses, SpO2 <92%',
        '5. Alta 2–4 h tras adrenalina si mejoría mantenida',
      ],
    },
    avoid: {
      'pt': 'EVITAR agitar a criança (piora obstrutiva). Não usar antibióticos (causa viral). Não usar vaporizadores quentes (queimaduras). Não usar budesonida nebulizada como substituta da dexametasona sistêmica (menos eficaz). Não realizar laringoscopia sem material de IOT disponível (pode precipitar laringoespasmo total). Alta precoce após adrenalina: observar mínimo 2–4h (rebote).',
      'es': 'EVITAR agitar al niño. No usar antibióticos (causa viral). No usar vaporizadores calientes. No usar budesonida nebulizada como sustituta de dexametasona sistémica. No realizar laringoscopia sin material de IOT disponible. Alta precoz tras adrenalina: observar mín. 2–4 h.',
    },
    drugs: ['dexametasona', 'adrenalina', 'salbutamol'],
  ),

  // ─────────────────────────────────────────────
  //  TOXICOLOGIA ESPECÍFICA
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'intox_paracetamol',
    title: {'pt': 'Intoxicação por Paracetamol (Acetaminofeno)', 'es': 'Intoxicación por Paracetamol (Acetaminofén)'},
    severity: {'pt': 'Alto', 'es': 'Alto'},
    recognize: {
      'pt': 'Ingestão >150 mg/kg (adulto: >7,5 g). Fase 1 (0–24h): náusea, vômito, mal-estar — ASSINTOMÁTICO frequente. Fase 2 (24–72h): dor em hipocôndrio direito, hepatomegalia, ↑TGO/TGP. Fase 3 (72–96h): necrose hepática fulminante, IRA, coagulopatia, encefalopatia. Nomograma de Rumack-Matthew: nível sérico de paracetamol × tempo pós-ingestão define tratamento.',
      'es': 'Ingestión >150 mg/kg (adulto: >7,5 g). Fase 1 (0–24h): náusea, vómito — ASINTOMÁTICO frecuente. Fase 2 (24–72h): dolor hipocondrio derecho, ↑TGO/TGP. Fase 3 (72–96h): necrosis hepática fulminante, IRA, coagulopatía. Nomograma de Rumack-Matthew: nivel sérico × tiempo post-ingestión.',
    },
    actions: {
      'pt': [
        '1. Tempo de ingestão <1–2h + consciente: Carvão ativado 1 g/kg VO (até 50 g)',
        '2. Dosar nível sérico de paracetamol a partir de 4h pós-ingestão',
        '3. Aplicar Nomograma de Rumack-Matthew: nível acima da linha de tratamento = N-acetilcisteína (NAC)',
        '4. N-ACETILCISTEÍNA IV (protocolo 21h — padrão):',
        '   → 1ª bolsa: 150 mg/kg em 200 mL SG5% em 60 min',
        '   → 2ª bolsa: 50 mg/kg em 500 mL SG5% em 4h',
        '   → 3ª bolsa: 100 mg/kg em 1000 mL SG5% em 16h',
        '5. NAC VO (se IV indisponível): 140 mg/kg ataque + 70 mg/kg 4/4h × 17 doses',
        '6. Iniciar NAC em qualquer dose se: ingestão >10–12h sem nível sérico disponível, ou dose maciça (>250 mg/kg)',
        '7. Monitorar: TGO, TGP, INR, creatinina, glicemia a cada 12–24h',
        '8. Insuficiência hepática fulminante: UTI + avaliação para transplante hepático (critérios King\'s College)',
      ],
      'es': [
        '1. Tiempo ingestión <1–2h + consciente: Carbón activado 1 g/kg VO (máx. 50 g)',
        '2. Dosar nivel sérico de paracetamol a partir de 4 h post-ingestión',
        '3. Aplicar Nomograma de Rumack-Matthew: nivel sobre línea de tratamiento = N-acetilcisteína',
        '4. N-ACETILCISTEÍNA IV (protocolo 21h — estándar):',
        '   → 1ª bolsa: 150 mg/kg en 200 mL SG5% en 60 min',
        '   → 2ª bolsa: 50 mg/kg en 500 mL SG5% en 4 h',
        '   → 3ª bolsa: 100 mg/kg en 1000 mL SG5% en 16 h',
        '5. NAC VO si IV no disponible: 140 mg/kg ataque + 70 mg/kg c/4 h × 17 dosis',
        '6. Iniciar NAC si: ingestión >10–12 h sin nivel sérico, o dosis masiva (>250 mg/kg)',
        '7. Monitorizar: TGO, TGP, INR, creatinina, glucemia c/12–24 h',
        '8. Falla hepática fulminante: UCI + evaluación para trasplante hepático (criterios King\'s College)',
      ],
    },
    avoid: {
      'pt': 'NUNCA aguardar sintomas hepáticos para iniciar NAC (janela terapêutica é nas primeiras horas). Não dosar nível sérico antes de 4h (resultado não interpretável no nomograma). Evitar NAC IV rápida na 1ª bolsa (reação anafilactoide — reduzir velocidade se urticária/broncoespasmo). Não usar paracetamol após hepatotoxicidade.',
      'es': 'NUNCA esperar síntomas hepáticos para iniciar NAC. No dosar nivel sérico antes de 4 h (no interpretable en nomograma). Evitar NAC IV rápida en 1ª bolsa (reacción anafilactoide). No usar paracetamol tras hepatotoxicidad.',
    },
    drugs: ['omeprazol', 'dexametasona', 'noradrenalina'],
  ),

  ProtocolModel(
    id: 'intox_opioides',
    title: {'pt': 'Intoxicação por Opioides', 'es': 'Intoxicación por Opioides'},
    severity: {'pt': 'Crítico', 'es': 'Crítico'},
    recognize: {
      'pt': 'Tríade clássica: coma + miose puntiforme bilateral + depressão respiratória (FR <12 rpm ou apneia). Pode haver: hipotensão, bradicardia, hipotermia, edema pulmonar (heroína IV). Causas: morfina, codeína, tramadol, metadona, fentanil, oxicodona, heroína, loperamida (altas doses).',
      'es': 'Tríada clásica: coma + miosis puntiforme bilateral + depresión respiratoria (FR <12 rpm o apnea). Puede haber: hipotensión, bradicardia, hipotermia, edema pulmonar (heroína IV).',
    },
    actions: {
      'pt': [
        '1. ABCDE — PRIORIDADE: via aérea e respiração',
        '2. Posição lateral de segurança se inconsciente e respirando',
        '3. BVM com O2 100% se apneia ou FR <8 rpm (ANTES de naloxona se disponível)',
        '4. NALOXONA (antídoto específico):',
        '   → Via IV: 0,4–2 mg IV bolus; repetir a cada 2–3 min até FR >12 rpm ou consciência adequada (máx. 10 mg)',
        '   → Via IM/SC: 0,4–0,8 mg se sem acesso venoso',
        '   → Via IN (intranasal): 2–4 mg (atomizador) — uso pré-hospitalar',
        '5. Naloxona tem duração curta (30–90 min): monitorar por mínimo 4–6h (opioides de ação prolongada como metadona: até 24h)',
        '6. Se sem resposta após 10 mg de naloxona: reconsiderar diagnóstico (trauma, AVC, outra intoxicação)',
        '7. Infusão contínua de naloxona se opioide de ação longa: 2/3 da dose de reversão/hora em SG5%',
        '8. Tratar edema pulmonar se presente: O2, posição sentada, considerar VNI',
      ],
      'es': [
        '1. ABCDE — PRIORIDAD: vía aérea y respiración',
        '2. Posición lateral de seguridad si inconsciente y respirando',
        '3. BVM con O2 100% si apnea o FR <8 rpm',
        '4. NALOXONA (antídoto específico):',
        '   → IV: 0,4–2 mg IV bolo; repetir c/2–3 min hasta FR >12 rpm (máx. 10 mg)',
        '   → IM/SC: 0,4–0,8 mg si sin acceso venoso',
        '   → IN (intranasal): 2–4 mg (atomizador) — uso prehospitalario',
        '5. Naloxona tiene duración corta (30–90 min): monitorizar ≥4–6 h (metadona: hasta 24 h)',
        '6. Sin respuesta tras 10 mg naloxona: reconsiderar diagnóstico',
        '7. Infusión continua naloxona si opioide de acción larga: 2/3 dosis de reversión/hora en SG5%',
        '8. Tratar edema pulmonar si presente: O2, posición sentada, VNI',
      ],
    },
    avoid: {
      'pt': 'EVITAR naloxona em dose excessiva (precipita síndrome de abstinência aguda: dor intensa, agitação, vômito, taquicardia — dose mínima eficaz). Não dar alta antes de 4–6h (risco de re-narcotização). Não usar flumazenil empiricamente junto (intoxicação mista BZD + opioide).',
      'es': 'EVITAR naloxona en dosis excesiva (precipita síndrome de abstinencia: agitación, vómito — dosis mínima eficaz). No dar alta antes de 4–6 h (riesgo de re-narcotización). No usar flumazenil empíricamente junto (intoxicación mixta BZD + opioide).',
    },
    drugs: ['midazolam', 'diazepam', 'noradrenalina'],
  ),

  // ─────────────────────────────────────────────
  //  URGÊNCIAS ENDÓCRINAS
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'crise_tireotoxica',
    title: {'pt': 'Crise Tireotóxica (Tempestade Tireoidiana)', 'es': 'Crisis Tirotóxica (Tormenta Tiroidea)'},
    severity: {'pt': 'Crítico', 'es': 'Crítico'},
    recognize: {
      'pt': 'Escore de Burch-Wartofsky ≥45 = crise provável. Sinais: hipertermia (>38,5°C), taquicardia extrema (FA, FC >140 bpm), disfunção SNC (agitação, psicose, coma), insuficiência cardíaca, disfunção GI (diarreia, vômitos, icterícia). Precipitantes: cirurgia, infecção, contraste iodado, parto, abandono de medicação.',
      'es': 'Score de Burch-Wartofsky ≥45 = crisis probable. Signos: hipertermia (>38,5°C), taquicardia extrema (FA, FC >140 lpm), disfunción SNC (agitación, psicosis, coma), insuficiencia cardíaca. Precipitantes: cirugía, infección, contraste yodado, parto.',
    },
    actions: {
      'pt': [
        '1. UTI + monitorização contínua; tratar fator precipitante (antibiótico se infecção)',
        '2. PROPILTIOURACIL (PTU) 600 mg VO/SNE ataque → 200–250 mg 4/4h (bloqueia síntese + conversão T4→T3)',
        '3. IODO (APÓS 1h do PTU — nunca antes): Solução de Lugol 8 gotas 6/6h VO ou iodeto de sódio 500 mg IV 12/12h (bloqueia liberação de hormônios)',
        '4. PROPRANOLOL 60–80 mg VO 4/4h ou 1–2 mg IV lento (controla taquicardia e sintomas adrenérgicos) — 1ª linha para FC',
        '5. DEXAMETASONA 2 mg IV 6/6h (inibe conversão T4→T3, cobre possível insuficiência adrenal)',
        '6. Controle de hipertermia: paracetamol + resfriamento físico (NÃO usar salicilatos — deslocam T4 da albumina)',
        '7. Suporte hemodinâmico: volume + vasopressores se choque',
        '8. Se IC refratária: considerar plasmaférese ou diálise (remove hormônios tireoideos)',
      ],
      'es': [
        '1. UCI + monitorización continua; tratar factor precipitante',
        '2. PROPILTIOURACILO (PTU) 600 mg VO/SNG ataque → 200–250 mg c/4 h',
        '3. YODO (DESPUÉS de 1 h del PTU — nunca antes): Solución de Lugol 8 gotas c/6 h VO o yoduro de sodio 500 mg IV c/12 h',
        '4. PROPRANOLOL 60–80 mg VO c/4 h o 1–2 mg IV lento (controla taquicardia)',
        '5. DEXAMETASONA 2 mg IV c/6 h',
        '6. Control de hipertermia: paracetamol + enfriamiento físico (NO salicilatos)',
        '7. Soporte hemodinámico: volumen + vasopresores si choque',
        '8. Si IC refractaria: considerar plasmaféresis o diálisis',
      ],
    },
    avoid: {
      'pt': 'NUNCA dar iodo antes do PTU (iodo isolado pode piorar hipersecreção transitoriamente). NÃO usar ácido acetilsalicílico/salicilatos (deslocam T4 e T3 da TBG → piora tireotoxicose). Evitar amiodarona (contém iodo — precipita ou piora crise). Betabloqueador com cautela na IC grave.',
      'es': 'NUNCA dar yodo antes del PTU. NO usar ácido acetilsalicílico/salicilatos (desplazan T4 y T3 de TBG → empeoran tirotoxicosis). Evitar amiodarona (contiene yodo). Betabloqueador con cautela en IC grave.',
    },
    drugs: ['dexametasona', 'metoprolol', 'noradrenalina'],
  ),

  ProtocolModel(
    id: 'hipoglicemia_grave',
    title: {'pt': 'Hipoglicemia Grave (Glicemia <54 mg/dL com Sintomas)', 'es': 'Hipoglucemia Grave (Glucemia <54 mg/dL con Síntomas)'},
    severity: {'pt': 'Alto', 'es': 'Alto'},
    recognize: {
      'pt': 'Glicemia capilar <70 mg/dL com sintomas; grave se <54 mg/dL ou necessita assistência. Sintomas adrenérgicos: tremor, sudorese, taquicardia, ansiedade, fome. Neuroglicopênicos: confusão, sonolência, visão turva, convulsão, coma. Causas: insulina (principal), sulfonilureias, álcool, jejum, sepse, neoplasia pancreática.',
      'es': 'Glucemia capilar <70 mg/dL con síntomas; grave si <54 mg/dL o necesita asistencia. Síntomas adrenérgicos: temblor, sudoración, taquicardia. Neuroglicopénicos: confusión, somnolencia, convulsión, coma. Causas: insulina (principal), sulfonilureas, alcohol, ayuno.',
    },
    actions: {
      'pt': [
        '1. CONSCIENTE + deglutição preservada: 15–20 g de carboidrato simples VO (3–4 comprimidos de glicose, 150 mL de suco de laranja, 1 colher de sopa de mel)',
        '2. Repetir glicemia em 15 min; se ainda <70 mg/dL: repetir dose de carboidrato',
        '3. INCONSCIENTE ou sem acesso VO:',
        '   → Glicose 50% (Glicose hipertônica): 40–60 mL IV bolus (20–30 g glicose)',
        '   → Se sem acesso venoso: Glucagon 1 mg IM ou SC (ou IN 3 mg)',
        '4. Após reversão: oferecer refeição com carboidrato complexo (evita re-hipoglicemia)',
        '5. Sulfonilureias (glibenclamida, glipizida): hipoglicemia PROLONGADA — monitorar 24–48h, glicose IV contínua, octreotida 50 µg SC 8/8h (reduz liberação de insulina)',
        '6. Investigar e tratar causa: ajustar insulina, suspender medicação, tratar sepse/neoplasia',
        '7. Hospitalizar se: sulfonilureia, idoso, insuficiência renal/hepática, glicemia difícil de controlar, hipoglicemia não percebida',
      ],
      'es': [
        '1. CONSCIENTE + deglución preservada: 15–20 g de carbohidrato simple VO (3–4 comprimidos de glucosa, 150 mL de jugo de naranja)',
        '2. Repetir glucemia en 15 min; si aún <70 mg/dL: repetir dosis',
        '3. INCONSCIENTE o sin acceso VO:',
        '   → Glucosa 50% (hipertónica): 40–60 mL IV bolo',
        '   → Sin acceso venoso: Glucagón 1 mg IM o SC (o IN 3 mg)',
        '4. Tras reversión: ofrecer comida con carbohidrato complejo',
        '5. Sulfonilureas: hipoglucemia PROLONGADA — monitorizar 24–48 h, glucosa IV continua, octreotida 50 µg SC c/8 h',
        '6. Investigar y tratar causa',
        '7. Hospitalizar si: sulfonilurea, anciano, IR/IH, hipoglucemia no percibida',
      ],
    },
    avoid: {
      'pt': 'NÃO usar glicose oral em paciente inconsciente (broncoaspiração). Evitar glicose 50% periférica sem diluição (flebite/necrose — diluir ou usar veia calibrosa). Não dar alta de pronto-socorro sem refeição após correção. Sulfonilureias: NUNCA alta precoce (re-hipoglicemia tardia, até 24–48h). Não usar glicagon em desnutridos/hepatopatas (sem glicogênio hepático — não funciona).',
      'es': 'NO usar glucosa oral en paciente inconsciente. Evitar glucosa 50% periférica sin dilución (flebitis/necrosis). No dar alta sin comida tras corrección. Sulfonilureas: NUNCA alta precoz (re-hipoglucemia tardía hasta 24–48 h). No usar glucagón en desnutridos/hepatópatas (sin glucógeno hepático).',
    },
    drugs: ['insulina_regular', 'dexametasona'],
  ),

  // ─────────────────────────────────────────────
  //  URGÊNCIAS CIRÚRGICAS / ABDOMINAIS
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'apendicite_aguda',
    title: {'pt': 'Apendicite Aguda', 'es': 'Apendicitis Aguda'},
    severity: {'pt': 'Alto', 'es': 'Alto'},
    recognize: {
      'pt': 'Dor em fossa ilíaca direita (migra periumbilical → FID). Anorexia, náuseas, febre baixa. Sinal de Blumberg (descompressão dolorosa), Rovsing, Psoas. Alvarado ≥7 = alta suspeita. Leucocitose com desvio. TC abdome: espessamento apendicular >6 mm, líquido periapendicular. Escore de Alvarado e AIR (Appendicitis Inflammatory Response).',
      'es': 'Dolor en fosa ilíaca derecha (migra periumbilical → FID). Anorexia, náuseas, fiebre baja. Signo de Blumberg, Rovsing, Psoas. Alvarado ≥7 = alta sospecha. Leucocitosis con desvío. TC abdomen: engrosamiento apendicular >6 mm.',
    },
    actions: {
      'pt': [
        '1. Jejum + acesso venoso + hidratação IV',
        '2. Analgesia: Dipirona 1 g IV ou Morfina 2–4 mg IV (analgesia NÃO mascara diagnóstico — evidência atual)',
        '3. Exames: hemograma, PCR, ureia, creatinina, beta-hCG (mulher em idade fértil), urinalise',
        '4. Imagem: USG (triagem, sem radiação — sensibilidade 85%) ou TC abdome/pelve com contraste (gold standard — sensibilidade 94%)',
        '5. ANTIBIÓTICO PRÉ-OPERATÓRIO: dose única 60 min antes — Cefazolina 2 g IV + Metronidazol 500 mg IV',
        '6. TRATAMENTO CIRÚRGICO: apendicectomia laparoscópica (padrão ouro) — indicar urgência',
        '7. Apendicite não complicada (sem perfuração): antibiótico (amoxicilina-clavulanato) como alternativa ao cirúrgico em selecionados (reavaliar com equipe)',
        '8. Apendicite complicada (perfuração/peritonite): cirurgia de urgência + antibiótico de amplo espectro: Pip-Tazo 4,5 g IV 6/6h ou Meropenem se grave',
      ],
      'es': [
        '1. Ayuno + acceso venoso + hidratación IV',
        '2. Analgesia: Dipirona 1 g IV o Morfina 2–4 mg IV (analgesia NO enmascara diagnóstico)',
        '3. Exámenes: hemograma, PCR, urea, creatinina, beta-hCG (mujer en edad fértil), urinálisis',
        '4. Imagen: USG (cribado, sin radiación — sensibilidad 85%) o TC abdomen/pelvis con contraste (gold standard — sensibilidad 94%)',
        '5. ANTIBIÓTICO PRE-OPERATORIO: dosis única 60 min antes — Cefazolina 2 g IV + Metronidazol 500 mg IV',
        '6. TRATAMIENTO QUIRÚRGICO: apendicectomía laparoscópica (estándar de oro)',
        '7. Apendicitis no complicada: antibiótico (amoxicilina-clavulanato) como alternativa en seleccionados',
        '8. Complicada (perforación/peritonitis): cirugía urgente + amplio espectro: Pip-Tazo 4,5 g IV c/6 h',
      ],
    },
    avoid: {
      'pt': 'EVITAR atraso diagnóstico em mulheres (diagnóstico diferencial amplo: cisto ovariano, GEP, DIP — solicitar beta-hCG sempre). Não negar analgesia por medo de mascarar diagnóstico (mito — evidência contrária). Não usar TC desnecessariamente em crianças e gestantes (preferir USG + RM). Evitar antibiótico prolongado sem cirurgia em perfuração.',
      'es': 'EVITAR retraso diagnóstico en mujeres (beta-hCG siempre). No negar analgesia por miedo a enmascarar diagnóstico (mito). No usar TC innecesariamente en niños y gestantes (preferir USG + RM). Evitar antibiótico prolongado sin cirugía en perforación.',
    },
    drugs: ['ceftriaxona', 'meropenem', 'morfina', 'omeprazol'],
  ),

  ProtocolModel(
    id: 'obstrucao_intestinal',
    title: {'pt': 'Obstrução Intestinal Aguda', 'es': 'Obstrucción Intestinal Aguda'},
    severity: {'pt': 'Alto', 'es': 'Alto'},
    recognize: {
      'pt': 'Dor abdominal em cólica, distensão abdominal, náuseas/vômitos (biliosos se alto, fecaloides se baixo), parada de gases/fezes. Ausculta: ruídos hiperativos (fase inicial) ou ausentes (íleo). RX abdome: alças distendidas + nível hidro-aéreo. TC: localiza obstrução, detecta estrangulamento. Causas: bridas/aderências (70%), hérnia encarcerada, neoplasia, vólvulo.',
      'es': 'Dolor abdominal en cólico, distensión abdominal, náuseas/vómitos (biliosos si alto, fecaloides si bajo), paro de gases/heces. RX abdomen: asas distendidas + nivel hidro-aéreo. TC: localiza obstrucción, detecta estrangulamiento.',
    },
    actions: {
      'pt': [
        '1. JEJUM + SNG (Levin) para descompressão gástrica — alivio imediato de vômitos',
        '2. Acesso venoso + hidratação vigorosa IV (Ringer Lactato 1–2 L em 2h — perdas para 3º espaço)',
        '3. Sonda vesical + controle rigoroso de diurese (alvo ≥0,5 mL/kg/h)',
        '4. Analgesia: Morfina 2–4 mg IV ou Tramadol 100 mg IV',
        '5. Exames: hemograma, eletrólitos, lactato, ureia/Cr, gasometria; RX abdome em pé + deitado',
        '6. TC abdome/pelve com contraste: confirmação, nível de obstrução, sinais de estrangulamento (ausência de captação do contraste em alça)',
        '7. SINAIS DE ALARME → cirurgia urgente: febre + peritonite, leucocitose com desvio, lactato ↑, pneumoperitônio, estrangulamento na TC',
        '8. Obstrução parcial de delgado por bridas: tratamento conservador 24–48h (SNE, hidratação) + gastrografin 100 mL VO (diagnóstico e terapêutico)',
        '9. Vólvulo de sigmóide: retossigmoidoscopia com descompressão + cirurgia eletiva',
      ],
      'es': [
        '1. AYUNO + SNG (Levin) para descompresión gástrica',
        '2. Acceso venoso + hidratación vigorosa IV (Ringer Lactato 1–2 L en 2 h)',
        '3. Sonda vesical + control diuresis (objetivo ≥0,5 mL/kg/h)',
        '4. Analgesia: Morfina 2–4 mg IV o Tramadol 100 mg IV',
        '5. Exámenes: hemograma, electrolitos, lactato, urea/Cr, gasometría; RX abdomen',
        '6. TC abdomen/pelvis con contraste: confirmación, nivel de obstrucción, signos de estrangulamiento',
        '7. SIGNOS DE ALARMA → cirugía urgente: fiebre + peritonitis, lactato ↑, neumoperitoneo, estrangulamiento en TC',
        '8. Obstrucción parcial de delgado por bridas: conservador 24–48 h + gastrografin 100 mL VO',
        '9. Vólvulo de sigmoides: rectosigmoidoscopia + descompresión + cirugía electiva',
      ],
    },
    avoid: {
      'pt': 'EVITAR atraso na cirurgia se sinais de estrangulamento (isquemia → necrose em horas). Não usar laxantes ou enema (risco de perfuração). Não progredir dieta sem confirmação de resolução. Não usar opioides antes de avaliação cirúrgica inicial (pode mascarar sinais de peritonite). Hidratação inadequada → IRA por contração de volume.',
      'es': 'EVITAR demora en cirugía si signos de estrangulamiento (isquemia → necrosis en horas). No usar laxantes ni enema (riesgo de perforación). No progresar dieta sin confirmar resolución. Hidratación inadecuada → IRA.',
    },
    drugs: ['meropenem', 'morfina', 'noradrenalina', 'omeprazol'],
  ),

  // ─────────────────────────────────────────────
  //  INFECTOLOGIA
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'pbe_cirrose',
    title: {'pt': 'Peritonite Bacteriana Espontânea (PBE) na Cirrose', 'es': 'Peritonitis Bacteriana Espontánea (PBE) en Cirrosis'},
    severity: {'pt': 'Alto', 'es': 'Alto'},
    recognize: {
      'pt': 'Cirrótico com ascite + qualquer um: dor/distensão abdominal, febre, encefalopatia de piora, IRA, leucocitose. Diagnóstico: paracentese diagnóstica (PMN ≥250/mm³ no líquido ascítico). Culturas do líquido (inocular em frascos de hemocultura à beira do leito). Mortalidade hospitalar 20–30%.',
      'es': 'Cirrótico con ascitis + cualquiera: dolor/distensión abdominal, fiebre, encefalopatía de empeoramiento, IRA, leucocitosis. Diagnóstico: paracentesis (PMN ≥250/mm³ en líquido ascítico). Culturas del líquido. Mortalidad hospitalaria 20–30%.',
    },
    actions: {
      'pt': [
        '1. PARACENTESE DIAGNÓSTICA imediata (não aguardar exame de imagem)',
        '2. ANTIBIÓTICO antes do resultado da cultura (PMN ≥250/mm³):',
        '   → 1ª linha: Cefotaxima 2 g IV 8/8h por 5–7 dias (cobertura de bacilos gram-negativos)',
        '   → Alternativa VO se tolerância: Ciprofloxacino 500 mg 12/12h por 7 dias (PBE não complicada)',
        '3. ALBUMINA IV (reduz IRA e mortalidade — evidência A):',
        '   → 1,5 g/kg IV no D1 + 1 g/kg no D3',
        '4. Controle de resposta: paracentese de controle em 48h (PMN deve reduzir >25%)',
        '5. Se sem melhora em 48h: ampliar cobertura (Pip-Tazo ou Meropenem — resistência)',
        '6. Profilaxia secundária após 1º episódio: Norfloxacino 400 mg/dia VO indefinidamente',
        '7. Tratar precipitantes: hemorragia digestiva (ATB profilático reduz PBE), suspender diuréticos se IRA',
        '8. Triagem para transplante hepático (PBE = pior prognóstico — MELD > 15)',
      ],
      'es': [
        '1. PARACENTESIS DIAGNÓSTICA inmediata',
        '2. ANTIBIÓTICO antes del resultado del cultivo (PMN ≥250/mm³):',
        '   → 1ª línea: Cefotaxima 2 g IV c/8 h por 5–7 días',
        '   → Alternativa VO: Ciprofloxacino 500 mg c/12 h × 7 días (PBE no complicada)',
        '3. ALBÚMINA IV (reduce IRA y mortalidad — evidencia A):',
        '   → 1,5 g/kg IV en D1 + 1 g/kg en D3',
        '4. Control de respuesta: paracentesis control en 48 h (PMN debe reducir >25%)',
        '5. Sin mejoría en 48 h: ampliar cobertura (Pip-Tazo o Meropenem)',
        '6. Profilaxis secundaria: Norfloxacino 400 mg/día VO indefinidamente',
        '7. Tratar precipitantes; suspender diuréticos si IRA',
        '8. Evaluar trasplante hepático',
      ],
    },
    avoid: {
      'pt': 'EVITAR paracentese terapêutica de grande volume sem albumina (precipita disfunção circulatória pós-paracentese). Não atrasar antibiótico aguardando cultura. Evitar aminoglicosídeos (nefrotóxico em cirróticos). Não usar AINE (piora função renal e hepática). Não usar fluoroquinolona profilática em paciente já em uso de profilaxia com fluoroquinolona (resistência).',
      'es': 'EVITAR paracentesis terapéutica de gran volumen sin albúmina. No retrasar antibiótico esperando cultivo. Evitar aminoglucósidos (nefrotóxico en cirróticos). No usar AINEs. No usar fluoroquinolona profiláctica si ya en profilaxis con fluoroquinolona.',
    },
    drugs: ['ceftriaxona', 'ciprofloxacino', 'noradrenalina', 'omeprazol'],
  ),

  ProtocolModel(
    id: 'pielonefrite_aguda',
    title: {'pt': 'Pielonefrite Aguda', 'es': 'Pielonefritis Aguda'},
    severity: {'pt': 'Médio', 'es': 'Medio'},
    recognize: {
      'pt': 'Tríade: febre >38°C + dor lombar/flanco + síndrome miccional (disúria, polaciúria). Pode haver náuseas, vômitos, sinal de Giordano +. Urina I: piúria + bacteriúria + nitritos. Urocultura + antibiograma (colher antes do ATB). Critérios de gravidade/internação: febre alta, vômitos, sepse, gestação, imunossupressão, anomalia urológica, IRA.',
      'es': 'Tríada: fiebre >38°C + dolor lumbar/flanco + síndrome miccional (disuria, polaquiuria). Orina I: piuria + bacteriuria + nitritos. Urocultivo + antibiograma (antes del ATB). Criterios de hospitalización: fiebre alta, vómitos, sepsis, gestación, inmunosupresión, IRA.',
    },
    actions: {
      'pt': [
        '1. UROCULTURA + HEMOCULTURA (se febre alta/sepse) antes do antibiótico',
        '2. LEVE a MODERADA (tolerância VO, sem sepse, sem comorbidades):',
        '   → Ciprofloxacino 500 mg VO 12/12h × 7–14 dias (resistência local <20%)',
        '   → Ou Trimetoprim-Sulfametoxazol (TMP-SMX) 160/800 mg VO 12/12h × 14 dias (se sensível)',
        '   → Ou Cefalexina 500 mg VO 6/6h × 10–14 dias (gestantes)',
        '3. GRAVE (sepse, vômitos, comorbidades, gestação complicada): internação + IV',
        '   → Ceftriaxona 1–2 g IV/dia (1ª linha) ou Gentamicina 5 mg/kg/dia IV (monodose)',
        '   → Reavaliar em 48–72h com urocultura; descalonar conforme antibiograma',
        '4. Hidratação: VO generosa ou IV se grave',
        '5. Analgesia: Dipirona 1 g VO/IV; AINE se não contraindicado',
        '6. Investigação: USG de vias urinárias se dúvida diagnóstica, cálculo, anomalia, pielonefrite complicada ou ausência de melhora em 72h',
        '7. TC se suspeita de abscesso perirrenal (febre persistente após 72h de ATB adequado)',
      ],
      'es': [
        '1. UROCULTIVO + HEMOCULTIVO (si fiebre alta/sepsis) antes del antibiótico',
        '2. LEVE a MODERADA (tolerancia VO, sin sepsis):',
        '   → Ciprofloxacino 500 mg VO c/12 h × 7–14 días',
        '   → O TMP-SMX 160/800 mg VO c/12 h × 14 días (si sensible)',
        '   → O Cefalexina 500 mg VO c/6 h × 10–14 días (gestantes)',
        '3. GRAVE (sepsis, vómitos, comorbidades, gestación complicada): internación + IV',
        '   → Ceftriaxona 1–2 g IV/día o Gentamicina 5 mg/kg/día IV (monodosis)',
        '   → Reevaluar en 48–72 h; desescalar según antibiograma',
        '4. Hidratación: VO generosa o IV si grave',
        '5. Analgesia: Dipirona 1 g VO/IV; AINE si no contraindicado',
        '6. Investigación: USG vías urinarias si duda diagnóstica, cálculo o sin mejoría en 72 h',
        '7. TC si sospecha de absceso perirrenal (fiebre persistente >72 h con ATB adecuado)',
      ],
    },
    avoid: {
      'pt': 'EVITAR alta sem urocultura colhida. Não usar ATB sem antibiograma posterior (alta resistência de E. coli a quinolonas em algumas regiões). Evitar nitrofurantoína em pielonefrite (não atinge concentração tecidual adequada — apenas para cistite). Não usar aminoglicosídeo sem monitorar função renal. Gestante: SEMPRE internar se pielonefrite (risco de parto prematuro).',
      'es': 'EVITAR alta sin urocultivo. No usar ATB sin antibiograma posterior. Evitar nitrofurantoína en pielonefritis (no alcanza concentración tisular — solo cistitis). No usar aminoglucósido sin monitorear función renal. Gestante: SIEMPRE internar (riesgo de parto prematuro).',
    },
    drugs: ['ciprofloxacino', 'ceftriaxona', 'meropenem', 'azitromicina'],
  ),

  // ─────────────────────────────────────────────
  //  URGÊNCIAS GERAIS
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'crise_gota',
    title: {'pt': 'Crise Aguda de Gota', 'es': 'Crisis Aguda de Gota'},
    severity: {'pt': 'Baixo', 'es': 'Bajo'},
    recognize: {
      'pt': 'Artrite monoarticular aguda (1ª metatarsofalângica = podagra em 50%) com dor intensa, eritema, calor e edema de início súbito, geralmente noturno. Hiperuricemia (ácido úrico ≥7 mg/dL em homens / ≥6 em mulheres) — pode estar normal na crise aguda. Líquido sinovial: cristais de urato monossódico (birrefringência negativa). Precipitantes: álcool, frutos do mar, carnes vermelhas, diuréticos, trauma, cirurgia, desidratação.',
      'es': 'Artritis monoarticular aguda (1ª metatarsofalángica = podagra en 50%) con dolor intenso, eritema, calor y edema de inicio súbito, generalmente nocturno. Líquido sinovial: cristales de urato monosódico (birrefringencia negativa). Precipitantes: alcohol, mariscos, carnes rojas, diuréticos.',
    },
    actions: {
      'pt': [
        '1. ANTI-INFLAMATÓRIO imediato (iniciar nas primeiras 24–36h para máxima eficácia):',
        '2. COLCHICINA 1 mg VO ataque → 0,5 mg 1h depois (total 1,5 mg no D1) → 0,5 mg 12/12h até resolução (máx. 10 dias)',
        '3. NAPROXENO 500 mg VO 12/12h OU Ibuprofeno 800 mg VO 8/8h (com gastroproteção — omeprazol)',
        '4. PREDNISONA 0,5 mg/kg/dia × 5–10 dias (se contraindicação a AINE e colchicina — IRA, IH, idoso)',
        '5. Gelo local 20 min 4×/dia (adjuvante)',
        '6. Repouso e elevação do membro afetado',
        '7. NÃO iniciar hipouricemiante na crise aguda (piora a artrite — aguardar 2–4 semanas)',
        '8. Hidratação oral abundante (2–3 L/dia)',
        '9. Após resolução: ácido úrico sérico, função renal, iniciar alopurinol 100 mg/dia com ajuste progressivo se indicado (≥2 crises/ano, tofos, LRA, urolitíase)',
      ],
      'es': [
        '1. ANTIINFLAMATORIO inmediato (iniciar en primeras 24–36 h):',
        '2. COLCHICINA 1 mg VO ataque → 0,5 mg 1 h después (total 1,5 mg en D1) → 0,5 mg c/12 h hasta resolución',
        '3. NAPROXENO 500 mg VO c/12 h O Ibuprofeno 800 mg VO c/8 h (con gastroprotección)',
        '4. PREDNISONA 0,5 mg/kg/día × 5–10 días (si contraindicación a AINE y colchicina)',
        '5. Hielo local 20 min 4×/día (adyuvante)',
        '6. Reposo y elevación del miembro afectado',
        '7. NO iniciar hipouricemiante en la crisis aguda (empeora la artritis — esperar 2–4 semanas)',
        '8. Hidratación oral abundante (2–3 L/día)',
        '9. Tras resolución: ácido úrico sérico, función renal, iniciar alopurinol si indicado',
      ],
    },
    avoid: {
      'pt': 'NUNCA iniciar alopurinol ou febuxostat na crise aguda (mobiliza depósitos de urato → prolonga e piora artrite). Evitar AINEs em IRA, IH grave, anticoagulados, gastropatas sem IBP. Não usar colchicina em IRA grave (dose única máxima 1,5 mg/dia se TFG <30). Evitar álcool e alimentos ricos em purinas durante a crise.',
      'es': 'NUNCA iniciar alopurinol o febuxostat en crisis aguda (moviliza depósitos → prolonga artritis). Evitar AINEs en IRA, IH grave, anticoagulados. No usar colchicina en IRA grave (TFG <30 → máx. 1,5 mg/día). Evitar alcohol y alimentos ricos en purinas.',
    },
    drugs: ['metilprednisolona', 'dexametasona'],
  ),

  ProtocolModel(
    id: 'hemorragia_pos_parto',
    title: {'pt': 'Hemorragia Pós-Parto (HPP)', 'es': 'Hemorragia Posparto (HPP)'},
    severity: {'pt': 'Crítico', 'es': 'Crítico'},
    recognize: {
      'pt': 'Perda sanguínea >500 mL (parto vaginal) ou >1000 mL (cesárea) com comprometimento hemodinâmico. Causas — 4 Ts: Tônus (atonia uterina 70–80%), Trauma (lacerações, rotura), Tecido (retenção placentária), Trombina (coagulopatia). Diagnóstico clínico: taquicardia + hipotensão + sangramento vaginal excessivo + útero amolecido (atonia).',
      'es': 'Pérdida sanguínea >500 mL (parto vaginal) o >1000 mL (cesárea) con compromiso hemodinámico. Causas — 4 Ts: Tono (atonía uterina 70–80%), Trauma (laceraciones), Tejido (retención placentaria), Trombina (coagulopatía).',
    },
    actions: {
      'pt': [
        '1. CHAMAR EQUIPE + acionar protocolo HPP (OB, anestesia, banco de sangue)',
        '2. 2 acessos venosos calibrosos + cristaloide IV + tipagem + crossmatch urgente',
        '3. ATONIA UTERINA (causa mais comum):',
        '   → Massagem uterina bimanual IMEDIATA',
        '   → Ocitocina 10–40 UI em 500 mL SF IV (manutenção) OU 10 UI IM',
        '   → Misoprostol 800–1000 µg retal ou sublingual (se ocitocina insuficiente)',
        '   → Ergometrina 0,2 mg IM ou IV lento (contraindicada em HAS/pré-eclâmpsia)',
        '   → Ácido Tranexâmico 1 g IV em 10 min (IMEDIATAMENTE se >500 mL — máx. eficácia nas primeiras 3h)',
        '4. Ressuscitação hemostática: transfusão 1:1:1 (hemácias:PFC:plaquetas)',
        '5. Se atonia refratária: tamponamento com balão de Bakri + cirurgia (ligadura artérias uterinas, B-Lynch, histerectomia)',
        '6. Fator VIIa recombinante (rFVIIa): considerar em hemorragia maciça refratária',
        '7. Corrigir acidose, hipotermia e coagulopatia — tríade letal',
        '8. Monitorar: lactato, fibrinogênio (alvo >2 g/L), ROTEG/TEG se disponível',
      ],
      'es': [
        '1. LLAMAR EQUIPO + activar protocolo HPP',
        '2. 2 accesos venosos calibrosos + cristaloide IV + tipificación + crossmatch urgente',
        '3. ATONÍA UTERINA (causa más común):',
        '   → Masaje uterino bimanual INMEDIATO',
        '   → Oxitocina 10–40 UI en 500 mL SF IV O 10 UI IM',
        '   → Misoprostol 800–1000 µg rectal o sublingual',
        '   → Ergometrina 0,2 mg IM o IV lento (contraindicada en HAS/preeclampsia)',
        '   → Ácido Tranexámico 1 g IV en 10 min (INMEDIATAMENTE si >500 mL)',
        '4. Resucitación hemostática: transfusión 1:1:1 (hematíes:PFC:plaquetas)',
        '5. Si atonía refractaria: taponamiento con balón de Bakri + cirugía (ligadura arterias uterinas, B-Lynch, histerectomía)',
        '6. Factor VIIa recombinante: considerar en hemorragia masiva refractaria',
        '7. Corregir acidosis, hipotermia y coagulopatía — tríada letal',
        '8. Monitorizar: lactato, fibrinógeno (objetivo >2 g/L)',
      ],
    },
    avoid: {
      'pt': 'EVITAR demora no ácido tranexâmico (após 3h do parto eficácia reduz significativamente). Não usar ergometrina em pré-eclâmpsia/HAS (vasoconstrição → crise hipertensiva). Evitar ressuscitação excessiva com cristaloides (dilui fatores de coagulação — usar sangue e hemoderivados). Não aguardar coagulopatia instalada para transfundir PFC.',
      'es': 'EVITAR demora en ácido tranexámico (tras 3 h eficacia reduce significativamente). No usar ergometrina en preeclampsia/HAS. Evitar resucitación excesiva con cristaloides (diluye factores). No esperar coagulopatía instalada para transfundir PFC.',
    },
    drugs: ['noradrenalina', 'sulfato_magnesio', 'dexametasona', 'adrenalina'],
  ),

  ProtocolModel(
    id: 'hipercalemia_grave',
    title: {'pt': 'Hipercalemia Grave — Manejo de Urgência', 'es': 'Hipercalemia Grave — Manejo de Urgencia'},
    severity: {'pt': 'Crítico', 'es': 'Crítico'},
    recognize: {
      'pt': 'K+ ≥6,0 mEq/L (ou K+ ≥5,5 com alterações de ECG). ECG: ondas T apiculadas (primeiros achados, K+ 5,5–6,5) → PR alargado, QRS alargado → padrão sinusoidal (K+ >7) → FV/assistolia. Sintomas: fraqueza muscular, paralisia flácida ascendente, parestesias. Causas: IRA/DRC, IECA/BRA, espironolactona, destruição celular (rabdomiólise, hemólise, trauma).',
      'es': 'K+ ≥6,0 mEq/L o ≥5,5 con alteraciones ECG. ECG: ondas T picudas → PR alargado, QRS ancho → patrón sinusoidal (K+ >7) → FV/asistolia. Síntomas: debilidad muscular, parálisis flácida, parestesias.',
    },
    actions: {
      'pt': [
        '1. ECG imediato — qualquer alteração = EMERGÊNCIA; monitoração cardíaca contínua',
        '2. K+ >6,5 OU alterações no ECG: ESTABILIZAR MEMBRANA CARDÍACA:',
        '   → Gluconato de Cálcio 10% 10 mL IV em 2–3 min (onset: 1–3 min; duração: 30–60 min)',
        '   → Repetir em 5 min se sem melhora do ECG; total até 3 ampolas',
        '3. REDUZIR K+ SÉRICO — Shift intracelular (início: 15–30 min):',
        '   → Insulina Regular 10 UI IV + Glicose 50% 50 mL IV (monitorar glicemia — risco hipoglicemia!)',
        '   → Salbutamol nebulizado 10–20 mg (agonista β2 — sinergia com insulina)',
        '   → Bicarbonato de Sódio 50–100 mEq IV se acidose metabólica (pH <7,2)',
        '4. REMOVER K+ DO ORGANISMO:',
        '   → Furosemida 40–80 mg IV (se débito urinário preservado)',
        '   → Resina de troca: Patirômero 8,4 g VO ou SPS (Sorcal) 15 g VO (início: 2–6h)',
        '   → Hemodiálise urgente: K+ >7 mEq/L, IRA oligúrica, refratário, instabilidade',
        '5. Suspender IMEDIATAMENTE: IECA, BRA, espironolactona, trimetoprim, AINEs, suplementos de K+',
        '6. Identificar e tratar causa subjacente',
        '7. Reavaliar K+ a cada 2h até <5,5 mEq/L',
      ],
      'es': [
        '1. ECG inmediato — cualquier alteración = EMERGENCIA; monitoreo cardíaco continuo',
        '2. K+ >6,5 O alteraciones ECG: ESTABILIZAR MEMBRANA:',
        '   → Gluconato de Calcio 10% 10 mL IV en 2–3 min; repetir en 5 min si sin mejoría',
        '3. REDUCIR K+ SÉRICO — Shift intracelular:',
        '   → Insulina Regular 10 UI IV + Glucosa 50% 50 mL IV',
        '   → Salbutamol nebulizado 10–20 mg (agonista β2)',
        '   → Bicarbonato de Sodio 50–100 mEq IV si acidosis (pH <7,2)',
        '4. ELIMINAR K+ DEL ORGANISMO:',
        '   → Furosemida 40–80 mg IV (si diuresis preservada)',
        '   → Resina de intercambio: Patirómero 8,4 g VO (inicio: 2–6 h)',
        '   → Hemodiálisis urgente: K+ >7 mEq/L, IRA oligúrica, refractario',
        '5. Suspender INMEDIATAMENTE: IECA, BRA, espironolactona, AINEs, suplementos K+',
        '6. Identificar y tratar causa subyacente',
        '7. Reevaluar K+ c/2 h hasta <5,5 mEq/L',
      ],
    },
    avoid: {
      'pt': 'EVITAR gluconato de cálcio em intoxicação digitálica (precipita arritmias refratárias — usar Digibind). Resinas: efeito lento — não usar como única medida em emergência. Bicarbonato: eficácia limitada sem acidose concomitante. Não confundir hipercalemia com hipernatremia no ECG. Salientar: glicose sem insulina não faz shift de K+ (usar sempre juntos).',
      'es': 'EVITAR gluconato de calcio en intoxicación digitálica (arritmias refractarias — usar Digibind). Resinas: efecto lento — no usar como única medida en emergencia. Bicarbonato: eficacia limitada sin acidosis. Glucosa sin insulina no hace shift de K+ (usar siempre juntos).',
    },
    drugs: ['bicarbonato_sodio', 'insulina_regular', 'furosemida', 'salbutamol'],
  ),

  ProtocolModel(
    id: 'encefalopatia_hepatica',
    title: {'pt': 'Encefalopatia Hepática (EH) Aguda', 'es': 'Encefalopatía Hepática (EH) Aguda'},
    severity: {'pt': 'Alto', 'es': 'Alto'},
    recognize: {
      'pt': 'Cirrótico com alteração do nível de consciência, desorientação, inversão do sono, asterixe (flapping tremor), foetor hepaticus. Graus West Haven: I (leve, atenção diminuída), II (letargia, confusão), III (soporoso, responsivo a estímulos), IV (coma). Amoníaco sérico ≥ 2× normal (inespecífico — diagnóstico é clínico). Excluir outras causas: hipoglicemia, infecção do SNC, intoxicação.',
      'es': 'Cirrótico con alteración del nivel de consciencia, desorientación, inversión del sueño, asterixis (flapping tremor). Grados West Haven: I (leve), II (letargia, confusión), III (soporoso), IV (coma). Amonio sérico elevado (inespecífico). Excluir otras causas.',
    },
    actions: {
      'pt': [
        '1. ABCDE; proteção de via aérea se grau III–IV (IOT se Glasgow ≤8)',
        '2. IDENTIFICAR E TRATAR FATOR PRECIPITANTE (essencial — sem isso não há resolução):',
        '   → Hemorragia digestiva (mais comum) → ver protocolo HDA',
        '   → Infecção (PBE, pneumonia, ITU) → paracentese + ATB',
        '   → Constipação → lactulose',
        '   → Hipopotassemia, desidratação, uso de sedativos/BZD, omissão de lactulose',
        '3. LACTULOSE (reduz absorção de amônia):',
        '   → 25–45 mL VO 6/6–8/8h; ajustar dose para 2–3 evacuações pastosas/dia',
        '   → Via enema se sem VO: 300 mL de lactulose + 700 mL água (retal)',
        '4. RIFAXIMINA 550 mg VO 12/12h (reduz flora produtora de amônia — adjuvante/prevenção de recorrência)',
        '5. Glicemia capilar + corrigir hipoglicemia; eletrólitos + corrigir hipopotassemia',
        '6. Suspender diuréticos, sedativos, BZD, opioides (reduzem excreção de amônia)',
        '7. Dieta proteica NÃO deve ser restrita cronicamente (piora sarcopenia e prognóstico). Proteína vegetal ou BCAA se intolerância.',
        '8. Triagem para transplante hepático',
      ],
      'es': [
        '1. ABCDE; protección vía aérea si grado III–IV (IOT si Glasgow ≤8)',
        '2. IDENTIFICAR Y TRATAR FACTOR PRECIPITANTE (esencial):',
        '   → Hemorragia digestiva → ver protocolo HDA',
        '   → Infección (PBE, neumonía, ITU) → paracentesis + ATB',
        '   → Estreñimiento → lactulosa',
        '   → Hipopotasemia, deshidratación, sedativos/BZD, omisión de lactulosa',
        '3. LACTULOSA: 25–45 mL VO c/6–8 h; ajustar para 2–3 deposiciones pastosas/día',
        '   → Enema si sin VO: 300 mL lactulosa + 700 mL agua (rectal)',
        '4. RIFAXIMINA 550 mg VO c/12 h (adyuvante/prevención de recurrencia)',
        '5. Glucemia capilar + corregir hipoglucemia; electrolitos + corregir hipopotasemia',
        '6. Suspender diuréticos, sedativos, BZD, opioides',
        '7. Dieta proteica NO debe restringirse crónicamente. Proteína vegetal o BCAA si intolerancia.',
        '8. Evaluar trasplante hepático',
      ],
    },
    avoid: {
      'pt': 'NÃO restringir proteína cronicamente (piora sarcopenia e prognóstico — mito antigo). Evitar diuréticos na fase aguda grave (hipopotassemia agrava EH). Não usar flumazenil de rotina (efeito transitório, sem benefício em EH confirmada). Lactulose em excesso → diarreia maciça → hipernatremia e desidratação → piora da EH.',
      'es': 'NO restringir proteína crónicamente (empeora sarcopenia — mito antiguo). Evitar diuréticos en fase aguda grave. No usar flumazenil de rutina. Lactulosa en exceso → diarrea masiva → hipernatremia → empeora EH.',
    },
    drugs: ['omeprazol', 'ceftriaxona', 'noradrenalina'],
  ),

  ProtocolModel(
    id: 'edema_agudo_pulmao',
    title: {'pt': 'Edema Agudo de Pulmão Cardiogênico', 'es': 'Edema Agudo de Pulmón Cardiogénico'},
    severity: {'pt': 'Crítico', 'es': 'Crítico'},
    recognize: {
      'pt': 'Dispneia súbita intensa + ortopneia + estertores crepitantes bilaterais + SpO2 <90% + taquicardia + B3 + distensão venosa jugular. RX tórax: infiltrado intersticial bilateral ("asa de borboleta"), cefalização, linhas B de Kerley. Causa: disfunção sistólica/diastólica aguda, IAM, arritmia, HAS grave, valvopatia aguda.',
      'es': 'Disnea súbita intensa + ortopnea + estertores crepitantes bilaterales + SpO2 <90% + taquicardia + B3 + distensión venosa yugular. RX tórax: infiltrado intersticial bilateral ("ala de mariposa"). Causa: disfunción sistólica/diastólica aguda, IAM, arritmia.',
    },
    actions: {
      'pt': [
        '1. POSIÇÃO SENTADA (fowler); pernas pendentes (reduz retorno venoso)',
        '2. O2 ALTO FLUXO: máscara com reservatório 10–15 L/min → SpO2 alvo ≥94%',
        '3. VNI (CPAP/BiPAP) — 1ª linha se SpO2 <90% ou FR >25 rpm:',
        '   → CPAP 5–10 cmH2O (1ª opção) ou BiPAP IPAP 10–12 / EPAP 5–8 cmH2O',
        '   → Reduz intubação em 50% e mortalidade (evidência A)',
        '4. FUROSEMIDA 40–80 mg IV (ou 2,5× dose oral habitual se já em uso) — efeito venodilatador imediato + diurético',
        '5. NITROGLICERINA 5–200 µg/min IV (reduz pré e pós-carga) se PA >90 mmHg',
        '   → Contraindicada se PA <90 mmHg, uso de PDE5 inibidores, IAM de VD',
        '6. MORFINA 2–4 mg IV (reduz ansiedade e pré-carga) — uso controverso, usar com cautela',
        '7. SE HIPOTENSÃO (EAP + choque cardiogênico): ver protocolo choque cardiogênico',
        '   → Dobutamina 2,5–10 µg/kg/min IV + Noradrenalina 0,1–0,5 µg/kg/min IV',
        '8. Tratar causa: IAM (reperfusão urgente), arritmia (cardioversão), HAS (nitroprussiato)',
        '9. IOT se VNI falha, apneia, coma, Glasgow ≤8',
      ],
      'es': [
        '1. POSICIÓN SENTADA (fowler); piernas colgantes',
        '2. O2 ALTO FLUJO: mascarilla con reservorio 10–15 L/min → SpO2 ≥94%',
        '3. VNI (CPAP/BiPAP) — 1ª línea si SpO2 <90% o FR >25 rpm:',
        '   → CPAP 5–10 cmH2O o BiPAP IPAP 10–12/EPAP 5–8 cmH2O',
        '4. FUROSEMIDA 40–80 mg IV (efecto venodilatador inmediato + diurético)',
        '5. NITROGLICERINA 5–200 µg/min IV si PA >90 mmHg',
        '   → Contraindicada si PA <90 mmHg, PDE5i, IAM de VD',
        '6. MORFINA 2–4 mg IV (uso controversial, con cautela)',
        '7. SI HIPOTENSIÓN: ver protocolo choque cardiogénico',
        '8. Tratar causa: IAM (reperfusión urgente), arritmia (cardioversión), HAS (nitroprusiato)',
        '9. IOT si VNI falla, apnea, Glasgow ≤8',
      ],
    },
    avoid: {
      'pt': 'EVITAR nitroglicerina se PA <90 mmHg (hipotensão grave). Evitar sobrecarga de volume. Não usar VNI em vômitos ativos, rebaixamento de consciência grave ou contraindicação à máscara (trauma facial). Morfina: pode deprimir respiração — monitorar. Betabloqueadores IV contraindicados na fase aguda de EAP com broncoespasmo.',
      'es': 'EVITAR nitroglicerina si PA <90 mmHg. Evitar sobrecarga de volumen. No usar VNI en vómitos activos, rebajamiento de consciencia grave. Morfina: puede deprimir respiración. Betabloqueadores IV contraindicados en fase aguda de EAP con broncoespasmo.',
    },
    drugs: ['furosemida', 'nitroglicerina', 'noradrenalina', 'dobutamina', 'morfina'],
  ),

  ProtocolModel(
    id: 'parada_respiratoria',
    title: {'pt': 'Insuficiência Respiratória Aguda — Suporte Ventilatório', 'es': 'Insuficiencia Respiratoria Aguda — Soporte Ventilatorio'},
    severity: {'pt': 'Crítico', 'es': 'Crítico'},
    recognize: {
      'pt': 'Tipo I (hipoxêmica): PaO2 <60 mmHg com FiO2 ambiente; SpO2 <90%; causas: pneumonia, TEP, EAP, SDRA. Tipo II (hipercápnica): PaCO2 >50 mmHg + pH <7,35; causas: DPOC, asma, overdose, síndrome de Guillain-Barré. Sinais clínicos: taquipneia >30 rpm, uso de musculatura acessória, cianose, alteração do nível de consciência, SpO2 <90%.',
      'es': 'Tipo I (hipoxémica): PaO2 <60 mmHg con FiO2 ambiente; causas: neumonía, TEP, EAP, SDRA. Tipo II (hipercápnica): PaCO2 >50 mmHg + pH <7,35; causas: EPOC, asma, sobredosis. Signos clínicos: taquipnea >30 rpm, uso de musculatura accesoria, cianosis, SpO2 <90%.',
    },
    actions: {
      'pt': [
        '1. O2 de alto fluxo imediato: cateter nasal 1–6 L/min → máscara Venturi → máscara com reservatório 10–15 L/min',
        '2. Cânula nasal de alto fluxo (CNAF): 40–60 L/min, FiO2 até 100% — excelente para hipoxemia grave sem hipercapnia (SDRA, PAC grave, pós-extubação)',
        '3. VNI (CPAP/BiPAP): indicada em EAP, DPOC exacerbado (pH 7,25–7,35), pós-extubação preventiva, imunossuprimido com IRA',
        '4. INTUBAÇÃO OROTRAQUEAL (IOT): indicações absolutas:',
        '   → Apneia ou FR <8 rpm',
        '   → Glasgow <8 ou incapacidade de proteger via aérea',
        '   → Falha de VNI ou CNAF',
        '   → Exaustão muscular respiratória',
        '5. IOT — Sequência Rápida de Intubação (SRI): Etomidato 0,3 mg/kg IV + Succinilcolina 1,5 mg/kg IV OU Rocurônio 1,2 mg/kg IV',
        '6. VENTILAÇÃO PROTETORA pós-IOT (SDRA):',
        '   → Volume corrente: 6 mL/kg de peso predito',
        '   → PEEP: 5–15 cmH2O (titular pela oxigenação)',
        '   → Pressão de platô: <30 cmH2O',
        '7. Posição prona (12–16h/dia) se PaO2/FiO2 <150 (SDRA grave)',
        '8. Tratar causa subjacente: ATB (pneumonia), diurético+VNI (EAP), broncodilatador (asma/DPOC)',
      ],
      'es': [
        '1. O2 alto flujo inmediato: cánula nasal → mascarilla Venturi → mascarilla con reservorio',
        '2. Cánula nasal de alto flujo (CNAF): 40–60 L/min, FiO2 hasta 100%',
        '3. VNI (CPAP/BiPAP): EAP, EPOC exacerbado (pH 7,25–7,35), post-extubación, inmunosuprimido con IRA',
        '4. INTUBACIÓN OROTRAQUEAL (IOT): indicaciones absolutas:',
        '   → Apnea o FR <8 rpm',
        '   → Glasgow <8 o incapacidad de proteger vía aérea',
        '   → Falla de VNI o CNAF',
        '5. SRI: Etomidato 0,3 mg/kg IV + Succinilcolina 1,5 mg/kg IV O Rocuronio 1,2 mg/kg IV',
        '6. VENTILACIÓN PROTECTORA post-IOT (SDRA):',
        '   → Volumen corriente: 6 mL/kg peso predicho',
        '   → PEEP: 5–15 cmH2O',
        '   → Presión meseta: <30 cmH2O',
        '7. Posición prona (12–16 h/día) si PaO2/FiO2 <150 (SDRA grave)',
        '8. Tratar causa: ATB (neumonía), diurético+VNI (EAP), broncodilatador (asma/EPOC)',
      ],
    },
    avoid: {
      'pt': 'EVITAR O2 excessivo em DPOC (alvo SpO2 88–92%). Não atrasar IOT quando indicada (piora hipóxia e dificulta via aérea). VNI contraindicada em: apneia, vômitos ativos, rebaixamento grave de consciência, trauma facial, instabilidade hemodinâmica grave. Volume corrente alto (>8 mL/kg) em SDRA: biotrauma pulmonar → piora mortalidade.',
      'es': 'EVITAR O2 excesivo en EPOC (SpO2 88–92%). No retrasar IOT cuando indicada. VNI contraindicada en: apnea, vómitos, rebajamiento grave de consciencia, trauma facial. Volumen corriente alto (>8 mL/kg) en SDRA: biotrauma pulmonar → peor mortalidad.',
    },
    drugs: ['midazolam', 'fenitoina', 'dexametasona', 'noradrenalina'],
  ),

  ProtocolModel(
    id: 'faringite_estrep',
    title: {'pt': 'Faringite Estreptocócica (Streptococcus pyogenes — SBHGA)', 'es': 'Faringitis Estreptocócica (Streptococcus pyogenes — SBHGA)'},
    severity: {'pt': 'Baixo', 'es': 'Bajo'},
    recognize: {
      'pt': 'Escore de Centor/McIsaac: exsudato tonsilar (+1), linfonodo cervical anterior doloroso (+1), ausência de tosse (+1), febre >38°C (+1), idade <15 anos (+1) ou >45 anos (−1). Score ≥3: alta probabilidade estreptocócica. Teste rápido de antígeno (RADT) ou cultura de orofaringe confirma. Complicações: febre reumática, glomerulonefrite, abscesso periamigdaliano.',
      'es': 'Score Centor/McIsaac: exudado tonsilar (+1), ganglio cervical anterior doloroso (+1), ausencia de tos (+1), fiebre >38°C (+1), edad <15 años (+1) o >45 años (−1). Score ≥3: alta probabilidad estreptocócica. Complicaciones: fiebre reumática, glomerulonefritis, absceso periamigdalino.',
    },
    actions: {
      'pt': [
        '1. Avaliar escore Centor/McIsaac:',
        '   → Score 0–1: sem antibiótico; tratar sintomaticamente',
        '   → Score 2–3: RADT (teste rápido). Se positivo: antibiótico. Se negativo: sem ATB',
        '   → Score ≥4 ou epidemia confirmada: antibiótico sem aguardar teste',
        '2. ANTIBIÓTICO 1ª LINHA: Amoxicilina 500 mg VO 12/12h × 10 dias (ou 1 g 1×/dia × 10 dias)',
        '3. Penicilina V benzatina 1.200.000 UI IM dose única (se aderência incerta ou surto)',
        '4. ALÉRGICO A PENICILINA: Azitromicina 500 mg VO D1, depois 250 mg D2–D5 (5 dias total)',
        '5. Analgesia/antipirético: Ibuprofeno 400 mg VO 8/8h ou Paracetamol 500 mg 6/6h',
        '6. Gargarejo com água morna e sal (adjuvante)',
        '7. Abscesso periamigdaliano: drenagem cirúrgica + Amoxicilina-Clavulanato 875/125 mg VO 12/12h × 10 dias',
        '8. Orientar: febre reumática → manter ATB por 10 dias completos mesmo com melhora rápida',
      ],
      'es': [
        '1. Evaluar score Centor/McIsaac:',
        '   → Score 0–1: sin antibiótico; tratar sintomáticamente',
        '   → Score 2–3: RADT. Si positivo: antibiótico. Si negativo: sin ATB',
        '   → Score ≥4 o epidemia confirmada: antibiótico sin esperar test',
        '2. ANTIBIÓTICO 1ª LÍNEA: Amoxicilina 500 mg VO c/12 h × 10 días',
        '3. Penicilina benzatínica 1.200.000 UI IM dosis única (si adherencia incierta)',
        '4. ALÉRGICO A PENICILINA: Azitromicina 500 mg VO D1, luego 250 mg D2–D5',
        '5. Analgesia/antipirético: Ibuprofeno 400 mg VO c/8 h o Paracetamol 500 mg c/6 h',
        '6. Gárgaras con agua tibia y sal',
        '7. Absceso periamigdalino: drenaje quirúrgico + Amoxicilina-Clavulanato 875/125 mg c/12 h × 10 días',
        '8. Orientar: fiebre reumática → mantener ATB por 10 días completos',
      ],
    },
    avoid: {
      'pt': 'NÃO usar antibiótico em faringite viral (maioria das faringites — rinovírus, adenovírus). Evitar amoxicilina em mononucleose (exantema maculopapular generalizado). Não interromper antibiótico antes de 10 dias (risco de febre reumática). Evitar fluoroquinolonas como 1ª linha (preservar para infecções graves). Não usar antibiótico baseado apenas em sintomas sem escore/teste (superprescrição).',
      'es': 'NO usar antibiótico en faringitis viral (mayoría). Evitar amoxicilina en mononucleosis (exantema). No interrumpir antibiótico antes de 10 días (riesgo fiebre reumática). Evitar fluoroquinolonas como 1ª línea. No usar antibiótico solo por síntomas sin score/test.',
    },
    drugs: ['azitromicina', 'dexametasona'],
  ),

  ProtocolModel(
    id: 'celulite_erisipela',
    title: {'pt': 'Celulite e Erisipela', 'es': 'Celulitis y Erisipela'},
    severity: {'pt': 'Médio', 'es': 'Medio'},
    recognize: {
      'pt': 'ERISIPELA: placa eritematosa, quente, brilhante, bordas elevadas e bem delimitadas (superficial — derme), face ou MMII. CELULITE: eritema, edema, calor, dor sem bordas definidas (mais profunda — hipoderme), geralmente MMII. Ambas: febre, mal-estar, leucocitose. Porta de entrada: tinea pedis, fissura, ferida, picada. Agentes: Streptococcus pyogenes (erisipela), S. aureus (celulite).',
      'es': 'ERISIPELA: placa eritematosa, caliente, brillante, bordes elevados y bien delimitados (superficial — dermis), cara o MMII. CELULITIS: eritema, edema, calor, dolor sin bordes definidos (más profunda — hipodermis). Agentes: Streptococcus pyogenes (erisipela), S. aureus (celulitis).',
    },
    actions: {
      'pt': [
        '1. LEVE a MODERADA (sem sinais de gravidade, imunocompetente):',
        '   → ERISIPELA: Amoxicilina 500 mg VO 8/8h × 7–14 dias OU Penicilina V 500 mg VO 6/6h × 10–14 dias',
        '   → CELULITE (sem risco MRSA): Cefalexina 500 mg VO 6/6h × 7–14 dias',
        '   → Suspeita MRSA (picada de inseto, atividade esportiva, IV drug use, comunidade): Sulfametoxazol-Trimetoprim 800/160 mg VO 12/12h + Cefalexina (cobertura para estreptococo)',
        '2. GRAVE / INTERNAÇÃO (febre alta, progressão rápida, falha VO, imunossuprimido, pé diabético):',
        '   → Oxacilina 2 g IV 4/4h (S. aureus sensível — celulite grave)',
        '   → Suspeita MRSA: Vancomicina 25–30 mg/kg/dia IV dividida',
        '   → Erisipela grave: Penicilina G cristalina 2–4 M UI IV 4/4h',
        '3. Elevar membro afetado (reduz edema e dor)',
        '4. Demarcar bordas com caneta (monitorar progressão)',
        '5. Analgesia: Dipirona ou Ibuprofeno VO',
        '6. Tratar porta de entrada: tinea pedis → antifúngico tópico',
        '7. Sinais de alarme → reavaliação urgente: bolhas, necrose, crepitação (fasciíte necrotizante), hipotensão',
      ],
      'es': [
        '1. LEVE a MODERADA (sin signos de gravedad, inmunocompetente):',
        '   → ERISIPELA: Amoxicilina 500 mg VO c/8 h × 7–14 días O Penicilina V 500 mg c/6 h',
        '   → CELULITIS (sin riesgo MRSA): Cefalexina 500 mg VO c/6 h × 7–14 días',
        '   → Sospecha MRSA: TMP-SMX 800/160 mg VO c/12 h + Cefalexina',
        '2. GRAVE / INTERNACIÓN (fiebre alta, progresión rápida, fallo VO, inmunosuprimido, pie diabético):',
        '   → Oxacilina 2 g IV c/4 h (S. aureus sensible)',
        '   → Sospecha MRSA: Vancomicina 25–30 mg/kg/día IV',
        '   → Erisipela grave: Penicilina G cristalina 2–4 M UI IV c/4 h',
        '3. Elevar miembro afectado',
        '4. Delimitar bordes con bolígrafo (monitorizar progresión)',
        '5. Analgesia: Dipirona o Ibuprofeno VO',
        '6. Tratar puerta de entrada: tinea pedis → antifúngico tópico',
        '7. Signos de alarma → reevaluación urgente: ampollas, necrosis, crepitación (fascitis necrotizante)',
      ],
    },
    avoid: {
      'pt': 'EVITAR diagnóstico diferencial tardio com fasciíte necrotizante (mortalidade 30–70% sem desbridamento precoce — crepitação, anestesia local da pele, instabilidade são sinais). Não usar antibiótico tópico isolado em celulite (insuficiente). Amoxicilina-clavulanato não tem vantagem sobre amoxicilina em erisipela típica. Evitar corticoide (piora infecção). Não tratar erisipela bilateral em MMII como infecciosa sem excluir estase venosa/linfedema (pseudoerisipela por estase).',
      'es': 'EVITAR diagnóstico tardío de fascitis necrotizante (mortalidad 30–70% sin desbridamiento precoz — crepitación, anestesia cutánea local son signos). No usar antibiótico tópico aislado. No tratar erisipela bilateral en MMII sin excluir estasis venosa (pseudoerisipela).',
    },
    drugs: ['vancomicina', 'ceftriaxona', 'meropenem', 'azitromicina'],
  ),

  ProtocolModel(
    id: 'anafilaxia_ped',
    title: {'pt': 'Anafilaxia Pediátrica', 'es': 'Anafilaxia Pediátrica'},
    severity: {'pt': 'Crítico', 'es': 'Crítico'},
    recognize: {
      'pt': 'Reação alérgica grave de início rápido (segundos a minutos) após exposição a alérgeno. Critérios: (1) pele/mucosas + comprometimento respiratório ou hemodinâmico; (2) 2 ou mais sistemas após exposição ao alérgeno. Manifestações: urticária/angioedema, broncoespasmo (sibilância), estridor, hipotensão, vômito/diarreia. Alérgenos frequentes em crianças: alimentos (amendoim, leite, ovo), medicamentos, picada de inseto.',
      'es': 'Reacción alérgica grave de inicio rápido tras exposición a alérgeno. Criterios: (1) piel/mucosas + compromiso respiratorio o hemodinámico; (2) 2 o más sistemas afectados. Alérgenos frecuentes en niños: alimentos (maní, leche, huevo), medicamentos, picadura de insecto.',
    },
    actions: {
      'pt': [
        '1. ADRENALINA IM IMEDIATAMENTE (1ª linha absoluta — não há contraindicação em anafilaxia):',
        '   → Adrenalina 1:1000 (1 mg/mL): 0,01 mg/kg IM na coxa anterolateral (máx. 0,5 mg)',
        '   → Pode repetir a cada 5–15 min (2–3 doses se necessário)',
        '2. POSIÇÃO: deitado com MMII elevados se hipotensão; sentado se broncoespasmo; lateral de segurança se vômitos',
        '3. O2 alto fluxo: 10–15 L/min por máscara com reservatório',
        '4. Acesso venoso: SF 0,9% 10–20 mL/kg IV rápido se hipotensão',
        '5. BRONCOESPASMO: Salbutamol 2,5–5 mg nebulizado (se sibilância persistente após adrenalina)',
        '6. Se sem resposta à adrenalina IM: adrenalina IV 0,1 µg/kg/min em infusão',
        '7. Adjuvantes (NÃO substituem adrenalina):',
        '   → Dexclorfeniramina 0,2 mg/kg IV/IM (anti-H1 — trata urticária)',
        '   → Hidrocortisona 5–10 mg/kg IV (máx. 200 mg) — previne reação bifásica',
        '8. Observação mínima 4–8h (reação bifásica em 5–20%)',
        '9. Prescrever autoaplicador de adrenalina (EpiPen Jr.) + plano de emergência na alta',
      ],
      'es': [
        '1. ADRENALINA IM INMEDIATAMENTE (1ª línea absoluta):',
        '   → Adrenalina 1:1000: 0,01 mg/kg IM en muslo anterolateral (máx. 0,5 mg)',
        '   → Puede repetirse c/5–15 min (2–3 dosis si necesario)',
        '2. POSICIÓN: acostado con MMII elevados si hipotensión; sentado si broncoespasmo',
        '3. O2 alto flujo: 10–15 L/min por mascarilla con reservorio',
        '4. Acceso venoso: SF 0,9% 10–20 mL/kg IV rápido si hipotensión',
        '5. BRONCOESPASMO: Salbutamol 2,5–5 mg nebulizado',
        '6. Sin respuesta a adrenalina IM: adrenalina IV 0,1 µg/kg/min en infusión',
        '7. Adyuvantes (NO sustituyen adrenalina):',
        '   → Dexclorfeniramina 0,2 mg/kg IV/IM',
        '   → Hidrocortisona 5–10 mg/kg IV (máx. 200 mg)',
        '8. Observación mínima 4–8 h (reacción bifásica en 5–20%)',
        '9. Prescribir autoinyector de adrenalina (EpiPen Jr.) + plan de emergencia al alta',
      ],
    },
    avoid: {
      'pt': 'NUNCA atrasar adrenalina IM — anti-histamínico e corticoide isolados NÃO tratam anafilaxia. Evitar adrenalina IV em bolo sem monitoração (arritmias). Não dar alta antes de 4–8h (reação bifásica). Não usar adrenalina SC (absorção irregular — sempre IM). Evitar anti-H2 isolado (não cobre receptor H1 — sem eficácia na anafilaxia).',
      'es': 'NUNCA retrasar adrenalina IM — antihistamínico y corticoide aislados NO tratan anafilaxia. Evitar adrenalina IV en bolo sin monitoreo. No dar alta antes de 4–8 h. No usar adrenalina SC (absorción irregular — siempre IM).',
    },
    drugs: ['adrenalina', 'dexclorfeniramina', 'hidrocortisona'],
  ),

  // ─────────────────────────────────────────────
  //  DOENÇAS INFECCIOSAS
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'dengue_manejo',
    title: {'pt': 'Dengue — Manejo Clínico (Grupos A-D)', 'es': 'Dengue — Manejo Clínico (Grupos A-D)'},
    severity: {'pt': 'Alto', 'es': 'Alto'},
    recognize: {
      'pt': 'Febre + mialgia + dor retro-orbitária + exantema. Sinais de Alarme: dor abdominal intensa, vômitos persistentes, sangramento de mucosas, hipotensão, queda abrupta de plaquetas (<100.000), hematócrito em ascensão.',
      'es': 'Fiebre + mialgia + dolor retroorbitario + exantema. Signos de Alarma: dolor abdominal intenso, vómitos persistentes, sangrado de mucosas, hipotensión, plaquetas <100.000, hematocrito en ascenso.',
    },
    actions: {
      'pt': [
        '1. GRUPO A (sem sinais de alarme, sem comorbidades): Hidratação Oral 60 mL/kg/dia (1/3 SRO, 2/3 líquidos claros); analgesia com Paracetamol; acompanhamento ambulatorial',
        '2. GRUPO B (comorbidades OU sinais de alarme leves): observação hospitalar; hidratação IV 10 mL/kg SF em 1h; repetir se necessário',
        '3. GRUPO C (dengue grave — extravasamento grave, choque, sangramento intenso, disfunção orgânica):',
        '   → Cristaloide 20 mL/kg IV em 15–20 min; repetir 1–2x se sem resposta',
        '   → Se choque refratário: colóide 10–20 mL/kg IV',
        '   → Monitorar hematócrito 2/2h',
        '4. Analgesia: Paracetamol 500–1000 mg 6/6h OU Dipirona 500–1000 mg 6/6h',
        '5. Monitorar: hematócrito, plaquetas, PA, diurese (alvo ≥1 mL/kg/h)',
        '6. Transfusão de plaquetas: apenas se <20.000/mm³ sem sangramento, ou <50.000 com sangramento ativo',
      ],
      'es': [
        '1. GRUPO A (sin signos de alarma): Hidratación Oral 60 mL/kg/día; Paracetamol; seguimiento ambulatorio',
        '2. GRUPO B (comorbidades O signos leves): hidratación IV 10 mL/kg SF en 1 h',
        '3. GRUPO C (dengue grave — choque, sangrado intenso, disfunción orgánica):',
        '   → Cristaloide 20 mL/kg IV en 15–20 min; repetir si sin respuesta',
        '   → Monitorizar hematocrito c/2 h',
        '4. Analgesia: Paracetamol o Dipirona',
        '5. Monitorizar: hematocrito, plaquetas, PA, diuresis (objetivo ≥1 mL/kg/h)',
        '6. Transfusión plaquetas: solo si <20.000 sin sangrado, o <50.000 con sangrado activo',
      ],
    },
    avoid: {
      'pt': 'CONTRAINDICADO: AAS e AINEs (risco de sangramento por plaquetopenia e disfunção plaquetária). Evitar corticoides na fase febril (sem benefício, pode piorar). Não hiperhidratar (risco de derrame pleural e ascite iatrogênica). Evitar antibióticos de rotina (causa viral).',
      'es': 'CONTRAINDICADO: AAS y AINEs (riesgo de sangrado). Evitar corticoides en fase febril. No hiperhidratar. Evitar antibióticos de rutina (causa viral).',
    },
    drugs: ['paracetamol', 'dipirona'],
  ),

  // ─────────────────────────────────────────────
  //  TOXICOLOGIA ESPECÍFICA (continuação)
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'intox_benzodiazepinas',
    title: {'pt': 'Intoxicação por Benzodiazepínicos', 'es': 'Intoxicación por Benzodiacepinas'},
    severity: {'pt': 'Médio', 'es': 'Medio'},
    recognize: {
      'pt': 'Ataxia, disartria, nistagmo, sonolência profunda, amnésia. Depressão respiratória grave geralmente ocorre apenas quando associada a outros depressores (álcool, opioides, barbitúricos). Intoxicação isolada por BZD raramente é fatal.',
      'es': 'Ataxia, disartria, nistagmo, somnolencia profunda, amnesia. Depresión respiratoria grave generalmente ocurre solo cuando asociada a otros depresores (alcohol, opioides). Intoxicación aislada raramente es fatal.',
    },
    actions: {
      'pt': [
        '1. ABCDE; garantir via aérea e oxigenação',
        '2. Posição lateral de segurança se sonolência com reflexos preservados',
        '3. Carvão ativado 1 g/kg VO (até 50 g) se <1–2h da ingestão e consciente',
        '4. FLUMAZENIL (antídoto — usar com cautela):',
        '   → 0,2 mg IV em 30 s; repetir 0,1 mg a cada 60 s até resposta (máx. 1 mg)',
        '   → INDICAÇÕES RESTRITAS: depressão respiratória grave, sem contraindicações',
        '5. Suporte hemodinâmico: cristaloide 250–500 mL IV se hipotensão',
        '6. Monitorar: SpO2, FR, nível de consciência por mínimo 4–6h',
        '7. Intoxicação mista (BZD + álcool/opioides): suporte ventilatório + considerar naloxona se componente opioide',
      ],
      'es': [
        '1. ABCDE; asegurar vía aérea y oxigenación',
        '2. Posición lateral de seguridad si somnolencia con reflejos preservados',
        '3. Carbón activado 1 g/kg VO si <1–2 h y consciente',
        '4. FLUMAZENIL (usar con cautela):',
        '   → 0,2 mg IV en 30 s; repetir 0,1 mg c/60 s hasta respuesta (máx. 1 mg)',
        '   → INDICACIONES RESTRINGIDAS: depresión respiratoria grave, sin contraindicaciones',
        '5. Cristaloide 250–500 mL IV si hipotensión',
        '6. Monitorizar: SpO2, FR, consciencia por mín. 4–6 h',
      ],
    },
    avoid: {
      'pt': 'FLUMAZENIL CONTRAINDICADO em: usuários crônicos de BZD (precipita síndrome de abstinência aguda grave — status epilepticus refratário), epilépticos em uso de BZD, intoxicação por antidepressivos tricíclicos concomitante (convulsões). Não induzir vômito. Evitar flumazenil como teste diagnóstico rotineiro.',
      'es': 'FLUMAZENIL CONTRAINDICADO en: usuarios crónicos de BZD (precipita síndrome de abstinencia — status epiléptico refractario), epilépticos, intoxicación por tricíclicos (convulsiones). No inducir vómito.',
    },
    drugs: ['diazepam', 'midazolam'],
  ),

  // ─────────────────────────────────────────────
  //  PEDIATRIA (continuação)
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'crise_asmatica_ped',
    title: {'pt': 'Crise de Asma Pediátrica', 'es': 'Crisis de Asma Pediátrica'},
    severity: {'pt': 'Médio', 'es': 'Medio'},
    recognize: {
      'pt': 'Sibilância, taquipneia, retração subcostal/intercostal, fala entrecortada ou choro fraco. SpO2 <92% indica gravidade. Escore PRAM ou Escore de Wood-Downes para estratificação. Grave: SpO2 <92%, FR >50, retração grave, incapacidade de falar/mamar, cianose.',
      'es': 'Sibilancias, taquipnea, tiraje subcostal/intercostal, llanto débil. SpO2 <92% indica gravedad. Grave: SpO2 <92%, FR >50, tiraje grave, incapacidad de hablar/mamar, cianosis.',
    },
    actions: {
      'pt': [
        '1. LEVE a MODERADA: O2 para SpO2 ≥94%',
        '2. Salbutamol MDI (com espaçador): 2–10 jatos a cada 20 min (1ª hora)',
        '   → Alternativa: nebulização 2,5 mg (<20 kg) ou 5 mg (>20 kg) a cada 20 min',
        '3. Ipratrópio brometo MDI 2–4 jatos (ou nebulização 0,25 mg) a cada 20 min × 3 — crises moderadas/graves',
        '4. CORTICOIDE: Prednisolona 1–2 mg/kg VO (máx. 40 mg) OU Dexametasona 0,15–0,3 mg/kg VO (máx. 10 mg) × 2 dias (mais adesão)',
        '5. GRAVE (SpO2 <92% após broncodilatadores iniciais):',
        '   → Sulfato de Magnésio 50–75 mg/kg IV em 20 min (máx. 2,5 g) — broncodilatador adjuvante',
        '   → Adrenalina SC 0,01 mg/kg (máx. 0,3 mg) se broncoespasmo grave refratário',
        '6. Internação: SpO2 <94% após 1h, necessidade >6 jatos/hora, crise grave, <1 ano',
        '7. Critérios de alta: SpO2 ≥94% em ar ambiente, FR normal, sem retração, boa tolerância',
      ],
      'es': [
        '1. LEVE a MODERADA: O2 para SpO2 ≥94%',
        '2. Salbutamol MDI (con espaciador): 2–10 disparos c/20 min',
        '3. Ipratropio MDI 2–4 disparos c/20 min × 3 — crisis moderadas/graves',
        '4. CORTICOIDE: Prednisolona 1–2 mg/kg VO (máx. 40 mg) O Dexametasona 0,15–0,3 mg/kg VO × 2 días',
        '5. GRAVE (SpO2 <92%):',
        '   → Sulfato de Magnesio 50–75 mg/kg IV en 20 min (máx. 2,5 g)',
        '   → Adrenalina SC 0,01 mg/kg si broncoespasmo refractario',
        '6. Internación: SpO2 <94% tras 1 h, >6 disparos/hora, crisis grave',
      ],
    },
    avoid: {
      'pt': 'EVITAR nebulização em detrimento do MDI com espaçador (MDI é igualmente eficaz, menor risco de infecção cruzada, menor tempo de administração). Não usar teofilina IV (maior toxicidade sem benefício adicional). Evitar sedação sem via aérea garantida. Não usar ketamina sem experiência em asma pediátrica.',
      'es': 'EVITAR nebulización sobre MDI con espaciador (igualmente eficaz, menor riesgo infección cruzada). No usar teofilina IV (mayor toxicidad). Evitar sedación sin vía aérea garantizada.',
    },
    drugs: ['salbutamol', 'dexametasona', 'metilprednisolona', 'sulfato_magnesio'],
  ),

  // ─────────────────────────────────────────────
  //  CARDIOVASCULAR (continuação)
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'insuficiencia_cardiaca_descomp',
    title: {'pt': 'IC Descompensada — Perfil B (Quente e Úmido)', 'es': 'IC Descompensada — Perfil B (Caliente y Húmedo)'},
    severity: {'pt': 'Alto', 'es': 'Alto'},
    recognize: {
      'pt': 'Dispneia em repouso, ortopneia, estertores crepitantes bilaterais, edema de MMII, turgência jugular, B3. Perfil B (mais comum): normoperfundido + congestão. Diferir de Perfil C (frio e úmido — baixo débito + congestão → choque cardiogênico). RX: cardiomegalia, redistribuição vascular, linhas B de Kerley.',
      'es': 'Disnea de reposo, ortopnea, crepitantes bilaterales, edema MMII, ingurgitación yugular, B3. Perfil B (más común): normoperfundido + congestión. Diferir Perfil C (frío y húmedo → choque cardiogénico). RX: redistribución vascular, líneas B de Kerley.',
    },
    actions: {
      'pt': [
        '1. POSIÇÃO SENTADA; O2 se SpO2 <94%; VNI (CPAP/BiPAP) se SpO2 refratária ou FR >25',
        '2. FUROSEMIDA IV: 40–80 mg IV (ou 2,5× dose oral crônica se já em uso)',
        '   → Resposta: diurese ≥1 mL/kg/h; se insuficiente: dobrar dose em 2h',
        '3. VASODILATADORES (se PAS >110 mmHg):',
        '   → Nitroglicerina IV 5–200 µg/min OU Isossorbida SL 5 mg',
        '4. Betabloqueador: NÃO iniciar na descompensação aguda; manter se já em uso e estável (reduzir dose se FC >100 ou hipotensão)',
        '5. Restrição hídrica: 1–1,5 L/dia; dieta hipossódica',
        '6. Monitorar: PA, FC, SpO2, diurese horária, eletrólitos (K+), função renal',
        '7. Pesagem diária; controle de balanço hídrico rigoroso',
        '8. Perfil C (frio + úmido): dobutamina 2,5–10 µg/kg/min IV + noradrenalina — ver protocolo choque cardiogênico',
      ],
      'es': [
        '1. POSICIÓN SENTADA; O2 si SpO2 <94%; VNI si SpO2 refractaria o FR >25',
        '2. FUROSEMIDA IV: 40–80 mg IV (o 2,5× dosis oral crónica)',
        '   → Respuesta: diuresis ≥1 mL/kg/h; si insuficiente: doblar dosis en 2 h',
        '3. VASODILATADORES (si PAS >110 mmHg): Nitroglicerina IV o Isosorbide SL',
        '4. Betabloqueante: NO iniciar en descompensación aguda; mantener si estable',
        '5. Restricción hídrica 1–1,5 L/día; dieta hipiosódica',
        '6. Monitorizar: PA, FC, SpO2, diuresis horaria, K+, función renal',
      ],
    },
    avoid: {
      'pt': 'EVITAR iniciar betabloqueador na fase congestiva aguda (pode piorar o débito cardíaco). Nitroglicerina contraindicada se PAS <90 mmHg ou uso de PDE5i. Não usar furosemida IM (absorção imprevisível). Evitar diuréticos excessivos sem monitoração (hipovolemia, IRA, hipopotassemia).',
      'es': 'EVITAR iniciar betabloqueante en fase congestiva aguda. Nitroglicerina contraindicada si PAS <90 mmHg o PDE5i. No usar furosemida IM. Evitar diuréticos excesivos sin monitorización.',
    },
    drugs: ['furosemida', 'nitroglicerina', 'dobutamina', 'noradrenalina'],
  ),

  // ─────────────────────────────────────────────
  //  DISTÚRBIOS HIDROELETROLÍTICOS
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'hipernatremia_grave',
    title: {'pt': 'Hipernatremia Grave (Na+ >155 mEq/L)', 'es': 'Hipernatremia Grave (Na+ >155 mEq/L)'},
    severity: {'pt': 'Alto', 'es': 'Alto'},
    recognize: {
      'pt': 'Sede intensa, mucosas secas, letargia, irritabilidade, hiperreflexia, convulsões, coma. Na+ >145 mEq/L = hipernatremia; >155 = grave. Causas: perda de água livre (febre, taquipneia, sudorese, diabetes insipidus), ganho de sódio (NaHCO3 excessivo), restrição de água (idosos, lactentes, rebaixamento de consciência).',
      'es': 'Sed intensa, mucosas secas, letargia, irritabilidad, hiperreflexia, convulsiones, coma. Causas: pérdida de agua libre (fiebre, taquipnea, diabetes insípidus), ganancia de sodio, restricción de agua.',
    },
    actions: {
      'pt': [
        '1. Calcular déficit de água livre: déficit = 0,6 × peso × [(Na+ atual / 140) − 1]',
        '2. REPOSIÇÃO: Água livre VO/SNE (preferível se possível) OU SG5% IV OU SF 0,45% IV',
        '3. VELOCIDADE: Reduzir Na+ máximo 10–12 mEq/L em 24h (risco de edema cerebral se correção rápida)',
        '   → Taxa de infusão: ajustar conforme cálculo + perdas contínuas',
        '4. Monitorar sódio a cada 4–6h até estabilização',
        '5. Identificar e tratar causa: diabetes insipidus central (desmopressina), nefrogênico (retirar causa), perda extrarenal (reposição)',
        '6. Se Na+ >170 mEq/L: hemodiálise pode ser necessária para controle mais preciso',
      ],
      'es': [
        '1. Calcular déficit de agua libre: déficit = 0,6 × peso × [(Na+ actual / 140) − 1]',
        '2. REPOSICIÓN: Agua libre VO/SNG O SG5% IV O SF 0,45% IV',
        '3. VELOCIDAD: Reducir Na+ máx. 10–12 mEq/L en 24 h (riesgo edema cerebral si corrección rápida)',
        '4. Monitorizar sodio c/4–6 h hasta estabilización',
        '5. Identificar y tratar causa: DI central (desmopresina), nefrogénico, pérdida extrarrenal',
        '6. Si Na+ >170 mEq/L: hemodiálisis puede ser necesaria',
      ],
    },
    avoid: {
      'pt': 'EVITAR correção rápida (queda >12 mEq/L/24h → edema cerebral → deterioração neurológica paradoxal). Não usar SF 0,9% para correção (aumenta sódio ainda mais — usar apenas se choque hipovolêmico associado). Evitar hipoglicemia ao usar SG5% (monitorar glicemia).',
      'es': 'EVITAR corrección rápida (caída >12 mEq/L/24h → edema cerebral). No usar SF 0,9% para corrección. Evitar hipoglucemia al usar SG5%.',
    },
    drugs: ['insulina_regular'],
  ),

  ProtocolModel(
    id: 'hiponatremia_grave',
    title: {'pt': 'Hiponatremia Grave Sintomática (Na+ <125 mEq/L)', 'es': 'Hiponatremia Grave Sintomática (Na+ <125 mEq/L)'},
    severity: {'pt': 'Crítico', 'es': 'Crítico'},
    recognize: {
      'pt': 'Confusão, desorientação, cefaleia intensa, náuseas, convulsões, coma. Na+ <125 mEq/L geralmente sintomático. Causas: SIADH, ICC, cirrose, hipotireoidismo, insuficiência adrenal, politraumatismo, pós-operatório. Diferenciar: hipovolêmica (hipovolemia) × euvolêmica (SIADH) × hipervolêmica (ICC, cirrose).',
      'es': 'Confusión, desorientación, cefalea intensa, convulsiones, coma. Causas: SIADH, ICC, cirrosis, hipotiroidismo, insuficiencia adrenal. Diferenciar: hipovolémica × euvolémica (SIADH) × hipervolémica.',
    },
    actions: {
      'pt': [
        '1. SINTOMÁTICA GRAVE (convulsão, coma): NaCl 3% (soro hipertônico) 100–150 mL IV em 10–20 min',
        '2. Repetir bolus de 100 mL até 3× se sintomas neurológicos persistem',
        '3. Meta inicial: elevar Na+ 4–6 mEq/L nas primeiras 1–2h (suficiente para cessar convulsões)',
        '4. LIMITE SEGURO: elevar no máximo 8–10 mEq/L em 24h (risco de Síndrome de Desmielinização Osmótica — SDO)',
        '5. SINTOMÁTICA MODERADA (confusão, cefaleia): NaCl 3% 0,5–1 mL/kg/h IV — velocidade de elevação 0,5–1 mEq/L/h',
        '6. Monitorar sódio a cada 2h nas primeiras 6h, depois a cada 4–6h',
        '7. Tratar causa: SIADH (restrição hídrica 800 mL/dia + NaCl 3%; suspender medicação causadora), hipovolêmica (SF 0,9% IV), ICC/cirrose (diurético + restrição hídrica)',
        '8. Tolvaptana (antagonista V2) em SIADH: 15 mg/dia VO — iniciar apenas em ambiente hospitalar',
      ],
      'es': [
        '1. SINTOMÁTICA GRAVE (convulsión, coma): NaCl 3% 100–150 mL IV en 10–20 min',
        '2. Repetir bolus de 100 mL hasta 3× si síntomas persisten',
        '3. Meta inicial: elevar Na+ 4–6 mEq/L en primeras 1–2 h',
        '4. LÍMITE SEGURO: elevar máx. 8–10 mEq/L en 24 h (riesgo de Síndrome de Desmielinización Osmótica)',
        '5. SINTOMÁTICA MODERADA: NaCl 3% 0,5–1 mL/kg/h IV',
        '6. Monitorizar sodio c/2 h en primeras 6 h, luego c/4–6 h',
        '7. Tratar causa: SIADH (restricción hídrica + NaCl 3%), hipovolémica (SF 0,9% IV)',
      ],
    },
    avoid: {
      'pt': 'EVITAR correção total em 24h (SDO — síndrome de desmielinização osmótica: paraplegia, coma). Se Na+ subir >10 mEq/L em 24h sem sintomas graves: FREAR a correção (água livre 10 mL/kg VO ou desmopressina 2 µg IV). Não usar NaCl 3% em hiponatremia hipervolêmica sem diurético. Evitar SF 0,9% em SIADH (pode piorar hiponatremia paradoxalmente).',
      'es': 'EVITAR corrección total en 24 h (SDO — desmielinización osmótica: paraplejía, coma). Si Na+ sube >10 mEq/L en 24 h: FRENAR corrección (agua libre VO o desmopresina). No usar NaCl 3% en hiponatremia hipervolémica sin diurético.',
    },
    drugs: ['furosemida'],
  ),

  // ─────────────────────────────────────────────
  //  NEFROLOGIA / UROLOGIA
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'colica_nefretica',
    title: {'pt': 'Cólica Nefrética (Urolitíase)', 'es': 'Cólico Renoureteral (Urolitiasis)'},
    severity: {'pt': 'Médio', 'es': 'Medio'},
    recognize: {
      'pt': 'Dor lombar súbita, intensa, em cólica, irradiada para região inguinal/genitália, inquietude (não melhora com posição). Náuseas, vômitos, hematúria macro/microscópica. Pode haver febre (infecção associada = urológica urgência). USG ou TC sem contraste: cálculo, dilatação de via urinária.',
      'es': 'Dolor lumbar súbito, intenso, en cólico, irradiado a ingle/genitales, inquietud (no mejora con posición). Náuseas, hematuria. Fiebre = infección asociada (urgencia urológica). USG o TC sin contraste: cálculo, dilatación.',
    },
    actions: {
      'pt': [
        '1. ANALGESIA (1ª linha — AINE é superior a opioides):',
        '   → Cetorolaco 30 mg IV ou Diclofenaco 75 mg IM',
        '   → Alternativa: Dipirona 1 g IV + Hioscina 20 mg IV (antiespasmódico)',
        '2. RESGATE se dor refratária: Morfina 2–4 mg IV ou Tramadol 100 mg IV',
        '3. Antiespasmódico: Hioscina 20 mg IV ou Propinoxato 20 mg IV',
        '4. TERAPIA EXPULSIVA (cálculo ≤10 mm, sem complicação): Tamsulosina 0,4 mg/dia VO × 4 semanas (facilita passagem espontânea)',
        '5. Hidratação moderada IV se desidratação (sem hiperidratação — não acelera passagem)',
        '6. INDICAÇÕES CIRÚRGICAS URGENTES: febre (obstrução infectada — pielonefrite obstrutiva), anúria (cálculo bilateral ou rim único), cálculo >10 mm (improvável passagem espontânea), dor refratária',
        '7. Orientar retorno se febre, calafrios ou anúria (urgência urológica)',
      ],
      'es': [
        '1. ANALGESIA (1ª línea — AINE superior a opioides):',
        '   → Ketorolaco 30 mg IV o Diclofenaco 75 mg IM',
        '   → Alternativa: Dipirona 1 g IV + Hioscina 20 mg IV',
        '2. RESCATE si dolor refractario: Morfina 2–4 mg IV o Tramadol 100 mg IV',
        '3. TERAPIA EXPULSIVA (cálculo ≤10 mm): Tamsulosina 0,4 mg/día VO × 4 semanas',
        '4. Hidratación moderada si deshidratación (sin hiperhidratación)',
        '5. INDICACIONES QUIRÚRGICAS URGENTES: fiebre (obstrucción infectada), anuria, cálculo >10 mm, dolor refractario',
      ],
    },
    avoid: {
      'pt': 'EVITAR hiperidratação (não acelera passagem do cálculo e aumenta a dor por distensão do sistema coletor). AINEs: cautela em IRC (nefroproteção — preferir opioides). Não subestimar febre com cólica — pielonefrite obstrutiva exige desobstrução urgente (risco de sepse e perda renal).',
      'es': 'EVITAR hiperhidratación (no acelera paso del cálculo). AINEs: precaución en IRC. No subestimar fiebre con cólico — pielonefritis obstructiva exige desobstrucción urgente (riesgo sepsis).',
    },
    drugs: ['morfina', 'omeprazol'],
  ),

  // ─────────────────────────────────────────────
  //  GASTROENTEROLOGIA (continuação)
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'pancreatite_aguda',
    title: {'pt': 'Pancreatite Aguda — Manejo Inicial (Leve a Moderada)', 'es': 'Pancreatitis Aguda — Manejo Inicial (Leve a Moderada)'},
    severity: {'pt': 'Alto', 'es': 'Alto'},
    recognize: {
      'pt': 'Dor abdominal epigástrica intensa em barra irradiada para dorso, náuseas, vômitos. Lipase OU Amilase >3× LSN. Diferir de pancreatite aguda grave (ver protocolo `pancreatite_aguda_grave`): sem falência orgânica e sem necrose ≥30%. Causas: litíase biliar (40%), álcool (30%), hipertrigliceridemia, medicamentos, idiopática.',
      'es': 'Dolor epigástrico intenso en cinturón irradiado al dorso, náuseas, vómitos. Lipasa O Amilasa >3× LSN. Sin falla orgánica ni necrosis (leve-moderada). Causas: litiasis biliar (40%), alcohol (30%), hipertrigliceridemia.',
    },
    actions: {
      'pt': [
        '1. REPOSIÇÃO VOLÊMICA: Ringer Lactato 250–500 mL/h nas primeiras 12–24h (preferir RL sobre SF — reduz acidose e SIRS)',
        '2. Monitorar: débito urinário (alvo ≥0,5 mL/kg/h), PA, FC, hematócrito a cada 6h',
        '3. ANALGESIA: Tramadol 100 mg IV ou Morfina 2–4 mg IV (mito de que opioides pioram — sem evidência)',
        '4. DIETA: jejum apenas se vômitos incoercíveis ou íleo; reintroduzir dieta oral precoce (24–48h) se tolerância — reduz complicações',
        '5. Exames: hemograma, PCR, cálcio, glicemia, triglicerídeos, função renal e hepática',
        '6. AVALIAR GRAVIDADE (Revised Atlanta 2012):',
        '   → Leve: sem falência orgânica, sem complicação local',
        '   → Moderada: falência transitória (<48h) ou complicação local',
        '   → Grave: falência persistente (>48h) → ver protocolo pancreatite grave',
        '7. ETIOLOGIA BILIAR: CPRE se colangite ou icterícia obstrutiva persistente. Colecistectomia antes da alta (leve) ou eletiva (moderada/grave)',
        '8. Antibiótico NÃO é rotina — apenas se necrose infectada confirmada',
      ],
      'es': [
        '1. REPOSICIÓN VOLÉMICA: Ringer Lactato 250–500 mL/h en primeras 12–24 h',
        '2. Monitorizar: diuresis (≥0,5 mL/kg/h), hematocrito c/6 h',
        '3. ANALGESIA: Tramadol 100 mg IV o Morfina 2–4 mg IV',
        '4. DIETA: ayuno solo si vómitos o íleo; dieta oral precoz (24–48 h) si tolerancia',
        '5. EVALUAR GRAVEDAD (Revised Atlanta 2012):',
        '   → Leve: sin falla orgánica, sin complicación local',
        '   → Grave: falla persistente (>48 h) → ver protocolo pancreatitis grave',
        '6. ETIOLOGÍA BILIAR: CPRE si colangitis. Colecistectomía antes del alta',
        '7. Antibiótico NO es rutina',
      ],
    },
    avoid: {
      'pt': 'EVITAR SF 0,9% em grandes volumes (acidose hiperclorêmica — usar Ringer Lactato). Não usar antibiótico profilático de rotina. Não manter jejum prolongado sem motivo (piora íleo e aumenta permeabilidade intestinal). Evitar analgesia insuficiente (dor intensa aumenta SIRS). Não confundir com pancreatite grave (falência orgânica → UTI obrigatória).',
      'es': 'EVITAR SF 0,9% en grandes volúmenes. No usar antibiótico profiláctico. No mantener ayuno prolongado sin motivo. No confundir con pancreatitis grave (falla orgánica → UCI obligatoria).',
    },
    drugs: ['morfina', 'omeprazol', 'meropenem'],
  ),

  ProtocolModel(
    id: 'hemorragia_digestiva_baixa',
    title: {'pt': 'Hemorragia Digestiva Baixa (HDB)', 'es': 'Hemorragia Digestiva Baja (HDB)'},
    severity: {'pt': 'Alto', 'es': 'Alto'},
    recognize: {
      'pt': 'Hematoquezia (sangue vivo ou marrom nas fezes) ou enterorragia (sangue vivo em grande volume). Causas: diverticulose (principal, 40%), angiodisplasia, neoplasia, colite isquêmica, doença inflamatória intestinal, hemorroida. Diferenciar de HDA: aspirado nasogástrico pode ajudar (bílis = HDA improvável).',
      'es': 'Hematoquecia (sangre viva en heces) o enterorragia. Causas: diverticulosis (principal, 40%), angiodisplasia, neoplasia, colitis isquémica, EII, hemorroides. Diferir de HDA: aspirado nasogástrico (bilis = HDA improbable).',
    },
    actions: {
      'pt': [
        '1. 2 acessos venosos calibrosos (14–16G); Cristaloide IV se instabilidade',
        '2. Tipagem + crossmatch; hemograma, coagulação, função renal',
        '3. Excluir HDA: se instabilidade grave ou aspirado NG com sangue → EDA primeiro',
        '4. Ressuscitação: transfusão se Hb <7 g/dL (ou <9 g/dL em cardiopatas)',
        '5. Colonoscopia: gold standard diagnóstico e terapêutico — em 24–48h após preparo adequado (colonoscopia precoce <24h em instabilidade hemodinâmica controlada pode ser preferível)',
        '6. Se sangramento maciço persistente + colonoscopia inconclusa: Arteriografia com embolização ou TC-angiografia',
        '7. Cirurgia (última opção): hemicolectomia se sangramento não localizado e intratável',
        '8. Suspender AINE, AAS (reavaliação risco/benefício), anticoagulantes temporariamente',
      ],
      'es': [
        '1. 2 accesos venosos gruesos; Cristaloide IV si inestabilidad',
        '2. Tipificación, hemograma, coagulación, función renal',
        '3. Excluir HDA: si inestabilidad → EDA primero',
        '4. Transfusión si Hb <7 g/dL (o <9 en cardiopatas)',
        '5. Colonoscopia: gold standard — en 24–48 h tras preparación adecuada',
        '6. Sangrado masivo persistente: Arteriografía con embolización o TC-angiografía',
        '7. Cirugía: hemicolectomía si sangrado no localizado',
      ],
    },
    avoid: {
      'pt': 'EVITAR colonoscopia sem preparo adequado de cólon (campo visual ruim, perfuração). Não usar colonoscopia de urgência sem estabilização mínima. Evitar hiperidratação (↑ pressão portal nas varizes — se causa varicosa suspeita: ver protocolo HDA varicosa). Não assumir que HDB para espontaneamente — 75–90% param, mas ressangramento precoce em 20–25%.',
      'es': 'EVITAR colonoscopia sin preparación adecuada. No realizar colonoscopia de urgencia sin estabilización mínima. No asumir que HDB para espontáneamente (ressangrado precoz en 20–25%).',
    },
    drugs: ['omeprazol', 'noradrenalina', 'ceftriaxona'],
  ),

  // ─────────────────────────────────────────────
  //  PSIQUIATRIA / NEUROLOGIA (continuação)
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'delirium_tremens',
    title: {'pt': 'Síndrome de Abstinência Alcoólica / Delirium Tremens', 'es': 'Síndrome de Abstinencia Alcohólica / Delirium Tremens'},
    severity: {'pt': 'Crítico', 'es': 'Crítico'},
    recognize: {
      'pt': 'Tremor, taquicardia, sudorese, hipertensão, alucinações visuais/táteis, agitação psicomotora intensa, convulsões. Cronologia: 6–24h após última dose (tremor, ansiedade), 24–48h (convulsões), 48–72h (Delirium Tremens — confusão, alucinações, disautonomia). Escala CIWA-Ar ≥10 = tratamento indicado.',
      'es': 'Temblor, taquicardia, sudoración, hipertensión, alucinaciones visuales/táctiles, agitación, convulsiones. Cronología: 6–24 h (temblor), 24–48 h (convulsiones), 48–72 h (Delirium Tremens). CIWA-Ar ≥10 = tratamiento indicado.',
    },
    actions: {
      'pt': [
        '1. MONITORIZAÇÃO contínua (ECG, PA, SpO2); acesso venoso; ambiente calmo',
        '2. TIAMINA: 200–300 mg IV/IM ANTES de qualquer glicose (prevenir encefalopatia de Wernicke)',
        '3. BENZODIAZEPÍNICO (1ª linha — protocolo sintoma-guiado pelo CIWA-Ar):',
        '   → Diazepam 10–20 mg IV a cada 15–30 min até sedação leve (CIWA <10)',
        '   → Lorazepam 2–4 mg IV se hepatopatia grave (sem metabolismo hepático ativo)',
        '4. CONVULSÃO por abstinência: Diazepam 10 mg IV + Tiamina IV (não usar fenitoína — sem eficácia em abstinência alcoólica)',
        '5. Reposição de Magnésio: MgSO4 2 g IV se hipomagnesemia (frequente em alcoolistas)',
        '6. Reposição de Potássio se hipopotassemia',
        '7. Hidratação IV e glicose APÓS tiamina',
        '8. Delirium Tremens refratário: Fenobarbital 65–130 mg IV ou Propofol em UTI',
      ],
      'es': [
        '1. MONITORIZACIÓN continua; acceso venoso; ambiente tranquilo',
        '2. TIAMINA: 200–300 mg IV/IM ANTES de cualquier glucosa (prevenir encefalopatía de Wernicke)',
        '3. BENZODIACEPINA (1ª línea — protocolo guiado por CIWA-Ar):',
        '   → Diazepam 10–20 mg IV c/15–30 min hasta sedación leve (CIWA <10)',
        '   → Lorazepam 2–4 mg IV si hepatopatía grave',
        '4. CONVULSIÓN por abstinencia: Diazepam 10 mg IV + Tiamina (no usar fenitoína)',
        '5. Reposición de Magnesio: MgSO4 2 g IV si hipomagnesemia',
        '6. Hidratación IV y glucosa DESPUÉS de tiamina',
        '7. Delirium Tremens refractario: Fenobarbital o Propofol en UCI',
      ],
    },
    avoid: {
      'pt': 'EVITAR glicose IV antes da tiamina (precipita encefalopatia de Wernicke aguda). Haloperidol como monoterapia: reduz limiar convulsivo — usar apenas como adjuvante aos BZD se alucinações persistentes. Não usar fenitoína em convulsões por abstinência (sem eficácia demonstrada). Evitar alta precoce — Delirium Tremens pode aparecer até 72h após a última dose de álcool.',
      'es': 'EVITAR glucosa IV antes de tiamina (precipita Wernicke). Haloperidol en monoterapia: reduce umbral convulsivo — usar solo como adyuvante. No usar fenitoína en convulsiones por abstinencia. No dar alta precoz — DT puede aparecer hasta 72 h después.',
    },
    drugs: ['diazepam', 'midazolam', 'sulfato_magnesio'],
  ),

  // ─────────────────────────────────────────────
  //  PEDIATRIA (continuação)
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'meningite_pediatrica',
    title: {'pt': 'Meningite Bacteriana Pediátrica', 'es': 'Meningitis Bacteriana Pediátrica'},
    severity: {'pt': 'Crítico', 'es': 'Crítico'},
    recognize: {
      'pt': 'Lactente: febre, irritabilidade, recusa alimentar, abaulamento de fontanela, gemência, choro agudo. Criança >2 anos: tríade (febre + cefaleia + rigidez de nuca) + Kernig/Brudzinski. Petéquias/púrpura: meningococo. Agentes por faixa: <1 mês (Streptococcus agalactiae, E. coli, Listeria), 1 mês–5 anos (Neisseria, Pneumococo), >5 anos (Pneumococo, Meningococo).',
      'es': 'Lactante: fiebre, irritabilidad, rechazo alimentario, fontanela abombada. Niño >2 años: tríada (fiebre + cefalea + rigidez de nuca) + Kernig/Brudzinski. Petequias/púrpura: meningococo. Agentes por edad: <1 mes (SGB, E. coli, Listeria), 1m–5a (Meningococo, Neumococo), >5a (Neumococo).',
    },
    actions: {
      'pt': [
        '1. ANTIBIÓTICO IMEDIATO (≤30 min após chegada — não aguardar TC, não aguardar PL se contraindicada)',
        '2. Hemocultura × 2 ANTES do antibiótico (5 min no máximo)',
        '3. DEXAMETASONA 0,15 mg/kg IV ANTES ou COM 1ª dose de ATB (máx. 6 mg; manter 4 dias):',
        '   → Reduz sequelas neurológicas (surdez) em meningite por pneumococo e meningococo',
        '4. ANTIBIÓTICO por faixa etária:',
        '   → <1 mês: Ampicilina 200 mg/kg/dia IV 6/6h + Cefotaxima 200 mg/kg/dia IV 6/6h',
        '   → 1 mês–5 anos: Ceftriaxona 100 mg/kg/dia IV 12/12h (máx. 4 g/dia)',
        '   → >5 anos: Ceftriaxona 100 mg/kg/dia IV + Vancomicina 60 mg/kg/dia IV 6/6h (cobertura pneumococo resistente)',
        '5. TC crânio ANTES da PL se: lactente <6 meses, Glasgow <13, papiledema, déficit focal, convulsão focal',
        '6. Suporte: cabeceira 30°, controle glicêmico, correção de eletrólitos, monitoração de PIC',
        '7. Quimioprofilaxia para contatos: Rifampicina 10 mg/kg 12/12h × 2 dias (meningococo)',
      ],
      'es': [
        '1. ANTIBIÓTICO INMEDIATO (≤30 min — no esperar TC, no esperar PL si contraindicada)',
        '2. Hemocultivo × 2 ANTES del antibiótico (máx. 5 min)',
        '3. DEXAMETASONA 0,15 mg/kg IV ANTES o CON 1ª dosis ATB (máx. 6 mg; mantener 4 días)',
        '4. ANTIBIÓTICO por edad:',
        '   → <1 mes: Ampicilina 200 mg/kg/día c/6 h + Cefotaxima 200 mg/kg/día c/6 h',
        '   → 1m–5a: Ceftriaxona 100 mg/kg/día c/12 h (máx. 4 g/día)',
        '   → >5a: Ceftriaxona 100 mg/kg/día + Vancomicina 60 mg/kg/día c/6 h',
        '5. TC cráneo antes de PL si: lactante <6m, Glasgow <13, papiledema, déficit focal',
        '6. Quimioprofilaxis contactos: Rifampicina 10 mg/kg c/12 h × 2 días (meningococo)',
      ],
    },
    avoid: {
      'pt': 'NUNCA atrasar antibiótico por qualquer motivo (cada hora de atraso aumenta mortalidade e sequelas). Não realizar PL sem TC prévia se sinais de HIC. Dexametasona: sem eficácia se iniciada após o antibiótico — não usar tardiamente. Evitar Ceftriaxona em neonatos com hiperbilirrubinemia (desloca bilirrubina da albumina — usar Cefotaxima).',
      'es': 'NUNCA retrasar antibiótico. No realizar PL sin TC previa si signos de HIC. Dexametasona sin eficacia si iniciada después del antibiótico. Evitar Ceftriaxona en neonatos con hiperbilirrubinemia (usar Cefotaxima).',
    },
    drugs: ['ceftriaxona', 'vancomicina', 'dexametasona', 'meropenem'],
  ),

  ProtocolModel(
    id: 'crise_hipertensiva_ped',
    title: {'pt': 'Crise Hipertensiva Pediátrica', 'es': 'Crisis Hipertensiva Pediátrica'},
    severity: {'pt': 'Alto', 'es': 'Alto'},
    recognize: {
      'pt': 'PA >95° percentil para idade/sexo/altura em 3 ocasiões = HAS. URGÊNCIA: PA >95° + sintomas menores (cefaleia, epistaxe). EMERGÊNCIA: PA muito elevada + lesão de órgão-alvo: encefalopatia (cefaleia + convulsão + alteração visual), IRA, cardiomegalia/IC aguda. Causas pediátricas: glomerulonefrite, coarctação de aorta, hiperaldosteronismo, feocromocitoma.',
      'es': 'PA >95° percentil para edad/sexo/talla. URGENCIA: PA >95° + síntomas menores. EMERGENCIA: PA muy elevada + lesión de órgano diana: encefalopatía, IRA, IC aguda. Causas: glomerulonefritis, coartación aórtica, feocromocitoma.',
    },
    actions: {
      'pt': [
        '1. URGÊNCIA HIPERTENSIVA (sem LOA): reduzir PA 25% em 24–48h com medicação VO',
        '   → Amlodipina 0,05–0,3 mg/kg/dia (máx. 5 mg/dia) VO ou Captopril 0,1–0,5 mg/kg/dose VO',
        '2. EMERGÊNCIA HIPERTENSIVA (com LOA): internação + monitoração contínua + IV',
        '3. Meta de redução: 25% da PA nas primeiras 8h; não normalizar abruptamente',
        '4. NITROPRUSSIATO DE SÓDIO: 0,3–0,5 µg/kg/min IV (encefalopatia, IC — 1ª linha emergência grave)',
        '5. HIDRALAZINA: 0,1–0,2 mg/kg IV a cada 4–6h (glomerulonefrite, HAS aguda)',
        '6. LABETALOL: 0,2–1 mg/kg IV (útil em feocromocitoma, coarctação)',
        '7. Investigar causa subjacente: ureia, creatinina, eletrólitos, sumário de urina, USG renal, ecocardiograma',
        '8. Encefalopatia hipertensiva: meta PA 25% de redução em 1h; depois gradual em 24–48h',
      ],
      'es': [
        '1. URGENCIA (sin LOA): reducir PA 25% en 24–48 h con VO',
        '   → Amlodipina 0,05–0,3 mg/kg/día VO o Captopril 0,1–0,5 mg/kg/dosis VO',
        '2. EMERGENCIA (con LOA): internación + monitoreo + IV',
        '3. Meta: reducir 25% en primeras 8 h; no normalizar abruptamente',
        '4. NITROPRUSIATO: 0,3–0,5 µg/kg/min IV (encefalopatía, IC)',
        '5. HIDRALAZINA: 0,1–0,2 mg/kg IV c/4–6 h',
        '6. LABETALOL: 0,2–1 mg/kg IV (feocromocitoma, coartación)',
        '7. Investigar causa: función renal, orina, USG renal, ecocardiograma',
      ],
    },
    avoid: {
      'pt': 'EVITAR queda súbita de PA (risco de isquemia cerebral, coronária e renal — especialmente em HAS crônica adaptada). Nifedipina sublingual: CONTRAINDICADA (queda abrupta e imprevisível). IECA/ARA2: contraindicados em estenose de artéria renal bilateral e gestação. Não usar nitroprussiato por >24–48h (toxicidade por tiocianato — especialmente em crianças).',
      'es': 'EVITAR caída brusca de PA. Nifedipina sublingual: CONTRAINDICADA. IECA/ARA2: contraindicados en estenosis arterial renal bilateral. No usar nitroprusiato >24–48 h en niños (toxicidad por tiocianato).',
    },
    drugs: ['enalapril', 'metoprolol', 'furosemida'],
  ),

  // ─────────────────────────────────────────────
  //  TOXICOLOGIA ESPECÍFICA (continuação)
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'intox_organofosforados',
    title: {'pt': 'Intoxicação por Organofosforados e Carbamatos', 'es': 'Intoxicación por Organofosforados y Carbamatos'},
    severity: {'pt': 'Crítico', 'es': 'Crítico'},
    recognize: {
      'pt': 'Síndrome colinérgica (inibição da acetilcolinesterase). Muscarínicos (SLUDGE/DUMBELS): Salivação, Lacrimejamento, Urina (incontinência), Defecação/Diarreia, GI (cólicas), Emese, Bradicardia, Broncospasmo/Broncorreia, Miose. Nicotínicos: fasciculações, fraqueza muscular, paralisia, taquicardia. SNC: convulsões, coma.',
      'es': 'Síndrome colinérgica. Muscarínicos (SLUDGE): Salivación, Lagrimeo, Micción, Defecación, GI, Emesis, Bradicardia, Broncorrea, Miosis. Nicotínicos: fasciculaciones, debilidad, parálisis, taquicardia. SNC: convulsiones, coma.',
    },
    actions: {
      'pt': [
        '1. DESCONTAMINAÇÃO: retirar roupas e calçados (proteção dos socorristas — EPI), lavar pele/mucosas com água e sabão abundante',
        '2. ATROPINA — titulada pelos sintomas muscarínicos (meta: secar secreções brônquicas):',
        '   → Dose inicial: 2–5 mg IV bolus a cada 5–10 min',
        '   → Doses repetidas até cessar broncorreia e broncoespasmo (pode necessitar centenas de mg)',
        '   → Atropina NÃO reverte fraqueza muscular (ação nicotínica)',
        '3. PRALIDOXIMA (reativa colinesterase — eficaz se <24–48h da exposição):',
        '   → 1–2 g IV em 15–30 min; manutenção 200–500 mg/h IV por 24–48h',
        '   → Carbamatos: pralidoxima controversa (pode agravar) — consultar toxicologia',
        '4. SUPORTE VENTILATÓRIO: IOT se broncoespasmo grave, fraqueza muscular ou coma',
        '   → ATENÇÃO: succinilcolina tem metabolismo prolongado (colinesterase inibida) → usar Rocurônio',
        '5. CONVULSÕES: Diazepam 10 mg IV ou Midazolam 10 mg IM',
        '6. Monitorar atividade de colinesterase sérica (orienta duração do tratamento)',
      ],
      'es': [
        '1. DESCONTAMINACIÓN: retirar ropa y calzado (EPI para reanimadores), lavar piel/mucosas con agua y jabón',
        '2. ATROPINA — titulada por síntomas muscarínicos (meta: secar secreciones bronquiales):',
        '   → Dosis inicial: 2–5 mg IV bolo c/5–10 min hasta cesar broncorrea',
        '   → Atropina NO revierte debilidad muscular (acción nicotínica)',
        '3. PRALIDOXIMA (reactiva colinesterasa — eficaz si <24–48 h):',
        '   → 1–2 g IV en 15–30 min; mantenimiento 200–500 mg/h × 24–48 h',
        '4. SOPORTE VENTILATORIO: IOT si broncoespasmo grave o coma',
        '   → Usar Rocuronio (succinilcolina metabolismo prolongado)',
        '5. CONVULSIONES: Diazepam 10 mg IV o Midazolam 10 mg IM',
      ],
    },
    avoid: {
      'pt': 'EVITAR succinilcolina na IOT (inibição de colinesterase plasmática → bloqueio neuromuscular prolongado e imprevisível — usar Rocurônio). Não usar atropina sem antes garantir oxigenação adequada (pode precipitar FV em hipóxia). Não expor equipe sem EPI (contaminação secundária por via cutânea/inalatória é frequente).',
      'es': 'EVITAR succinilcolina (colinesterasa inhibida → bloqueo prolongado — usar Rocuronio). No usar atropina sin oxigenación adecuada (puede precipitar FV en hipoxia). No exponer al equipo sin EPI (contaminación secundaria frecuente).',
    },
    drugs: ['atropina', 'diazepam', 'midazolam'],
  ),

  // ─────────────────────────────────────────────
  //  NEFROLOGIA (continuação)
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'rabdomiolise_aguda',
    title: {'pt': 'Rabdomiólise Aguda', 'es': 'Rabdomiólisis Aguda'},
    severity: {'pt': 'Alto', 'es': 'Alto'},
    recognize: {
      'pt': 'Mialgia intensa, fraqueza muscular, urina escura ("cor de coca-cola" — mioglobinúria), CPK >5× o LSN (frequentemente >10.000 UI/L). Causas: trauma/síndrome de esmagamento, exercício extremo, hipertermia, hipopotassemia grave, estatinas, convulsões prolongadas, isquemia muscular, cocaína/drogas. Complicações: IRA (mioglobina nefrotóxica), hiperpotassemia, hipocalcemia, CIVD.',
      'es': 'Mialgia intensa, debilidad muscular, orina oscura (mioglobinuria), CPK >5× LSN (frecuentemente >10.000). Causas: trauma/síndrome de aplastamiento, ejercicio extremo, hipertermia, estatinas, convulsiones prolongadas. Complicaciones: IRA, hiperpotasemia, hipocalcemia, CID.',
    },
    actions: {
      'pt': [
        '1. HIDRATAÇÃO IV AGRESSIVA: SF 0,9% 1–2 L/h (alvo: diurese 200–300 mL/h ou 3–5 mL/kg/h)',
        '2. Manter hidratação até CPK em queda sustentada e urina clara',
        '3. Monitorar: K+, Ca²⁺, creatinina, CPK a cada 6–12h; ECG se K+ elevado',
        '4. HIPERCALEMIA: tratamento agressivo (ver protocolo hipercalemia) — risco de arritmia fatal',
        '5. HIPOCALCEMIA sintomática: Gluconato de Cálcio 1 g IV (evitar repor cálcio assintomático — pode precipitar em músculo)',
        '6. BICARBONATO DE SÓDIO (controverso): 50–100 mEq/L no SF para alcalinizar urina (pH urinário alvo >6,5 — reduz precipitação de mioglobina)',
        '7. Furosemida: apenas após restauração adequada da volemia (não usar para forçar diurese em hipovolemia)',
        '8. Hemodiálise: IRA oligúrica refratária, hiperpotassemia intratável, sobrecarga volêmica',
        '9. Tratar causa subjacente: calor (resfriamento), convulsão (BZD), isquemia (reperfusão), medicamento (suspender)',
      ],
      'es': [
        '1. HIDRATACIÓN IV AGRESIVA: SF 0,9% 1–2 L/h (objetivo: diuresis 200–300 mL/h)',
        '2. Mantener hidratación hasta CPK en caída sostenida y orina clara',
        '3. Monitorizar: K+, Ca²⁺, creatinina, CPK c/6–12 h; ECG si K+ elevado',
        '4. HIPERPOTASEMIA: tratamiento agresivo (ver protocolo)',
        '5. HIPOCALCEMIA sintomática: Gluconato de Calcio 1 g IV',
        '6. BICARBONATO (controvertido): 50–100 mEq/L en SF (pH urinario objetivo >6,5)',
        '7. Furosemida: solo tras restauración volémica adecuada',
        '8. Hemodiálisis: IRA oligúrica refractaria, hiperpotasemia',
        '9. Tratar causa: calor (enfriamiento), convulsión (BZD), estatina (suspender)',
      ],
    },
    avoid: {
      'pt': 'EVITAR diuréticos (furosemida, manitol) antes de restaurar volemia adequada (piora IRA pré-renal). Não repor cálcio assintomático (Ca²⁺ precipita no músculo isquêmico → piora lesão). Evitar AINEs e aminoglicosídeos (nefrotóxicos). Não subestimar CPK levemente elevado em contexto clínico sugestivo — iniciar hidratação precoce.',
      'es': 'EVITAR diuréticos antes de restaurar volemia adecuada. No reponer calcio asintomático (precipita en músculo isquémico). Evitar AINEs y aminoglucósidos (nefrotóxicos). No subestimar CPK levemente elevada — iniciar hidratación precoz.',
    },
    drugs: ['furosemida', 'bicarbonato_sodio', 'insulina_regular'],
  ),

  // ─────────────────────────────────────────────
  //  PNEUMOLOGIA (continuação)
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'hemoptise_macica',
    title: {'pt': 'Hemoptise Maciça (>200 mL/24h ou ≥100 mL em episódio único)', 'es': 'Hemoptisis Masiva (>200 mL/24 h o ≥100 mL en episodio único)'},
    severity: {'pt': 'Crítico', 'es': 'Crítico'},
    recognize: {
      'pt': 'Expectoração de sangue vivo em grande volume, desconforto respiratório, SpO2 em queda. Causas: tuberculose (principal no Brasil — 70%), bronquiectasias, neoplasia pulmonar, aspergilose, vasculite (síndrome de Goodpasture, GPA), malformação arteriovenosa, cateter de artéria pulmonar.',
      'es': 'Expectoración de sangre viva en gran volumen, disnea, SpO2 en caída. Causas: tuberculosis (principal), bronquiectasias, neoplasia pulmonar, aspergilosis, vasculitis (Goodpasture, GPA), MAV.',
    },
    actions: {
      'pt': [
        '1. POSICIONAMENTO: decúbito lateral sobre o lado AFETADO (protege pulmão sadio de inundação)',
        '2. O2 alto fluxo; acesso venoso calibroso; monitoração contínua',
        '3. IOT se: SpO2 <90% refratária, FR >35 rpm, rebaixamento de consciência, volume >500 mL',
        '   → Usar tubo de maior calibre (8–9 mm) para facilitar broncoscopia',
        '4. ÁCIDO TRANEXÂMICO 1 g IV em 10 min (+ 1 g IV em 8h se persistir) — antifibrinolítico',
        '5. Reverter anticoagulação se presente: vitamina K + CCP para varfarina; Andexanet/Idarucizumabe para NOAC',
        '6. BRONCOSCOPIA DIAGNÓSTICA E TERAPÊUTICA: localiza foco + tamponamento brônquico + coagulação a laser',
        '7. ARTERIOGRAFIA BRÔNQUICA COM EMBOLIZAÇÃO: tratamento definitivo em >90% dos casos (artérias brônquicas hipertrofiadas — TB, bronquiectasia)',
        '8. Cirurgia (ressecção): se embolização falha, lesão localizada, tumor ressecável',
        '9. Vasopressina/Terlipressina: vasoconstrição pulmonar (uso adjuvante — pouca evidência)',
      ],
      'es': [
        '1. POSICIONAMIENTO: decúbito lateral sobre lado AFECTADO (protege pulmón sano)',
        '2. O2 alto flujo; acceso venoso calibroso; monitoreo continuo',
        '3. IOT si: SpO2 <90%, FR >35 rpm, rebajamiento de consciencia, volumen >500 mL',
        '4. ÁCIDO TRANEXÁMICO 1 g IV en 10 min (+ 1 g en 8 h si persiste)',
        '5. Revertir anticoagulación si presente',
        '6. BRONCOSCOPIA diagnóstica y terapéutica',
        '7. ARTERIOGRAFÍA BRONQUIAL CON EMBOLIZACIÓN: tratamiento definitivo en >90% (TB, bronquiectasia)',
        '8. Cirugía: si embolización falla, lesión localizada, tumor resecable',
      ],
    },
    avoid: {
      'pt': 'EVITAR suprimir tosse excessivamente (risco de inundação alveolar por coágulos — manter reflexo de tosse preservado). Não posicionar no decúbito lateral do pulmão sadio (inundação). Evitar broncoscopia rígida sem equipe experiente e sala cirúrgica disponível. Não iniciar antibiótico sem diagnóstico de infecção ativo (TB: isolar e investigar antes de tratar).',
      'es': 'EVITAR suprimir tos excesivamente (riesgo de inundación alveolar). No posicionar sobre el pulmón sano. Evitar broncoscopia rígida sin equipo experto. No iniciar antibiótico sin diagnóstico de infección activa.',
    },
    drugs: ['noradrenalina', 'adrenalina'],
  ),

  // ─────────────────────────────────────────────
  //  CARDIOVASCULAR (continuação)
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'sindrome_coronariana_sem_st',
    title: {'pt': 'SCA sem Supra de ST (Angina Instável / IAMSSST)', 'es': 'SCA sin Elevación de ST (AI / IAMSEST)'},
    severity: {'pt': 'Alto', 'es': 'Alto'},
    recognize: {
      'pt': 'Dor torácica anginosa em repouso ou mínimo esforço (>20 min), nova angina grau III-IV, angina em crescendo. ECG: infra de ST ≥0,5 mm ou inversão de onda T. Troponina positiva = IAMSSST; troponina negativa com ECG alterado = Angina Instável. Estratificação de risco: escore GRACE, TIMI Risk Score.',
      'es': 'Dolor torácico anginoso en reposo o mínimo esfuerzo (>20 min), nueva angina grado III-IV. ECG: infra ST ≥0,5 mm o inversión T. Troponina positiva = IAMSEST; negativa con ECG alterado = AI. Estratificación: score GRACE, TIMI.',
    },
    actions: {
      'pt': [
        '1. AAS 300 mg VO mastigar (ataque) + Inibidor P2Y12:',
        '   → Ticagrelor 180 mg VO (preferência — maior eficácia) OU Clopidogrel 300–600 mg VO',
        '2. ANTICOAGULAÇÃO: Enoxaparina 1 mg/kg SC 12/12h (ou HNF IV se cateterismo em <24h)',
        '3. NITROGLICERINA se dor persistente: 0,4 mg SL; se refratária → 5–200 µg/min IV',
        '4. BETA-BLOQUEADOR VO: Metoprolol 25–50 mg 12/12h (se sem contraindicação: FC >60, PA >100, sem BAV, sem IC aguda)',
        '5. ESTATINA de alta intensidade: Atorvastatina 80 mg/dia VO (IMEDIATAMENTE)',
        '6. ESTRATÉGIA INVASIVA (cateterismo):',
        '   → URGENTE (<2h): instabilidade hemodinâmica, choque, arritmia grave, dor refratária',
        '   → PRECOCE (<24h): GRACE >140, troponina elevada, alterações dinâmicas de ST',
        '   → ELETIVA (<72h): risco intermediário, sem critérios acima',
        '7. O2: apenas se SpO2 <90%',
        '8. Morfina 2–4 mg IV se dor intensa refratária (cautela — pode mascarar sintomas)',
      ],
      'es': [
        '1. AAS 300 mg VO masticar + Inhibidor P2Y12:',
        '   → Ticagrelor 180 mg VO O Clopidogrel 300–600 mg VO',
        '2. ANTICOAGULACIÓN: Enoxaparina 1 mg/kg SC c/12 h (o HNF IV si cateterismo <24 h)',
        '3. NITROGLICERINA si dolor persistente: 0,4 mg SL; si refractario → IV',
        '4. BETABLOQUEANTE VO: Metoprolol 25–50 mg c/12 h',
        '5. ESTATINA: Atorvastatina 80 mg/día VO (INMEDIATAMENTE)',
        '6. ESTRATEGIA INVASIVA:',
        '   → URGENTE (<2 h): inestabilidad, choque, arritmia grave',
        '   → PRECOZ (<24 h): GRACE >140, troponina elevada, cambios dinámicos ST',
        '   → ELECTIVA (<72 h): riesgo intermedio',
      ],
    },
    avoid: {
      'pt': 'EVITAR fibrinolíticos (indicados APENAS em IAM com supra de ST — no IAMSSST aumentam sangramento sem benefício). Nitroglicerina contraindicada: PAS <90 mmHg, uso de PDE5i, IAM de VD. Clopidogrel em vez de Ticagrelor em: AVC hemorrágico prévio, sangramento ativo. Heparina de baixo peso molecular: ajustar em IRA (ClCr <30: enoxaparina 1 mg/kg/dia).',
      'es': 'EVITAR fibrinolíticos (solo en IAM con supra ST). Nitroglicerina contraindicada: PAS <90 mmHg, PDE5i, IAM de VD. Clopidogrel sobre Ticagrelor en: ACV hemorrágico previo, sangrado activo. Enoxaparina: ajustar en IRA.',
    },
    drugs: ['aas', 'clopidogrel', 'enoxaparina', 'nitroglicerina', 'metoprolol'],
  ),

  ProtocolModel(
    id: 'choque_hipovolemico',
    title: {'pt': 'Choque Hipovolêmico / Hemorrágico', 'es': 'Choque Hipovolémico / Hemorrágico'},
    severity: {'pt': 'Crítico', 'es': 'Crítico'},
    recognize: {
      'pt': 'Hipotensão (PAS <90 mmHg) + taquicardia + palidez + extremidades frias + enchimento capilar lento (>2 s) + oligúria. Classificação ATLS: I (<750 mL, FC <100), II (750–1500 mL, FC 100–120), III (1500–2000 mL, FC 120–140 + hipotensão), IV (>2000 mL, FC >140 + colapso). Causas: hemorragia (principal), vômito/diarreia, queimaduras, perdas para 3º espaço.',
      'es': 'Hipotensión (PAS <90 mmHg) + taquicardia + palidez + frialdad distal + relleno capilar lento + oliguria. Clasificación ATLS: I (<750 mL), II (750–1500), III (1500–2000 + hipotensión), IV (>2000 + colapso). Causas: hemorragia (principal), vómitos/diarrea, quemaduras.',
    },
    actions: {
      'pt': [
        '1. 2 ACESSOS VENOSOS CALIBROSOS (14–16G); se impossível: IO (intraósseo)',
        '2. RESSUSCITAÇÃO VOLÊMICA:',
        '   → Cristaloide: Ringer Lactato 1–2 L (adulto) ou 20 mL/kg (ped) em 15–20 min',
        '   → Hemorragia ativa: preferir SANGUE sobre cristaloide (ressuscitação hemostática)',
        '3. CONTROLE DE HEMORRAGIA:',
        '   → Pressão direta em sangramento externo acessível',
        '   → Torniquete se membros (máx. 2h — anotar horário)',
        '   → Cintas pélvicas se fratura de pelve instável',
        '4. ÁCIDO TRANEXÂMICO 1 g IV em 10 min se trauma <3h (reduz mortalidade — CRASH-2)',
        '5. TRANSFUSÃO MACIÇA (protocolo 1:1:1):',
        '   → Hemácias : Plasma Fresco Congelado : Plaquetas = 1:1:1',
        '   → Ativar protocolo de transfusão maciça do banco de sangue',
        '6. HIPOTENSÃO PERMISSIVA (trauma hemorrágico sem TCE):',
        '   → PAS alvo 80–90 mmHg até controle cirúrgico (reduz coagulopatia dilucional)',
        '7. Vasopressor (noradrenalina 0,1–0,5 µg/kg/min) se choque refratário APÓS reposição adequada',
        '8. Corrigir tríade letal: hipotermia (aquecimento), acidose (bicarbonato se pH <7,1), coagulopatia (PFC, crioprecipitado)',
      ],
      'es': [
        '1. 2 ACCESOS VENOSOS GRUESOS (14–16G); si imposible: IO (intraóseo)',
        '2. RESUCITACIÓN VOLÉMICA: Ringer Lactato 1–2 L (adulto) o 20 mL/kg (ped) en 15–20 min',
        '   → Hemorragia activa: preferir SANGRE sobre cristaloide',
        '3. CONTROL DE HEMORRAGIA: presión directa, torniquete si miembros, cinta pélvica si fractura pelvis',
        '4. ÁCIDO TRANEXÁMICO 1 g IV en 10 min si trauma <3 h',
        '5. TRANSFUSIÓN MASIVA (protocolo 1:1:1): GR : PFC : Plaquetas = 1:1:1',
        '6. HIPOTENSIÓN PERMISIVA (trauma sin TCE): PAS objetivo 80–90 mmHg hasta control quirúrgico',
        '7. Vasopresor (noradrenalina) si choque refractario TRAS reposición adecuada',
        '8. Corregir tríada letal: hipotermia, acidosis, coagulopatía',
      ],
    },
    avoid: {
      'pt': 'EVITAR uso ISOLADO de vasopressores antes da reposição volêmica adequada (piora isquemia tissular). Não ressuscitar com SF 0,9% em grandes volumes (acidose hiperclorêmica + coagulopatia dilucional — usar RL e sangue). Hipotensão permissiva contraindicada em TCE (PAM alvo ≥80 mmHg para perfusão cerebral). Não atrasar cirurgia de controle de danos por ressuscitação interminável.',
      'es': 'EVITAR vasopresores aislados antes de reposición adecuada. No resucitar con SF 0,9% en grandes volúmenes. Hipotensión permisiva contraindicada en TCE (PAM ≥80 mmHg). No retrasar cirugía de control de daños.',
    },
    drugs: ['noradrenalina', 'adrenalina', 'dobutamina'],
  ),

  ProtocolModel(
    id: 'pericardite_aguda',
    title: {'pt': 'Pericardite Aguda', 'es': 'Pericarditis Aguda'},
    severity: {'pt': 'Médio', 'es': 'Medio'},
    recognize: {
      'pt': 'Dor torácica pleurítica (piora com inspiração e decúbito dorsal, melhora ao inclinar para frente), atrito pericárdico à ausculta. ECG: infra de PR difuso + supra de ST difuso côncavo (sem espelho). Derrame pericárdico: ecocardiograma (pode ser assintomático). Causas: viral (70% — coxsackie, echovírus), bacteriana, autoimune, pós-IAM (Dressler), urêmica, neoplásica.',
      'es': 'Dolor torácico pleurítico (empeora inspiración y decúbito, mejora al inclinarse adelante), frote pericárdico. ECG: infra PR difuso + supra ST difuso cóncavo. Derrame pericárdico: ecocardiograma. Causas: viral (70%), bacteriana, autoinmune, post-IAM (Dressler), urémica.',
    },
    actions: {
      'pt': [
        '1. AAS 500–1000 mg VO 8/8h × 1–2 semanas OU Ibuprofeno 600 mg VO 8/8h × 1–2 semanas (+ omeprazol gastroproteção)',
        '2. COLCHICINA 0,5 mg VO 12/12h × 3 meses (adjuvante — reduz recorrência em 50%)',
        '3. REPOUSO: atividade física intensa contraindicada até resolução completa dos sintomas (4–6 semanas — atletas: até 3 meses)',
        '4. Ecocardiograma para excluir/quantificar derrame pericárdico',
        '5. TAMPONAMENTO CARDÍACO (hipotensão + turgência jugular + bulhas abafadas = tríade de Beck):',
        '   → PERICARDIOCENTESE guiada por ecocardiografia imediata',
        '6. PERICARDITE BACTERIANA: internação + antibiótico IV + pericardiocentese diagnóstica + drenagem cirúrgica',
        '7. URÊMICA: hemodiálise + AINEs com cautela',
        '8. Retorno em 1 semana: reavaliação clínica + ECG',
      ],
      'es': [
        '1. AAS 500–1000 mg VO c/8 h × 1–2 semanas O Ibuprofeno 600 mg c/8 h (+ omeprazol)',
        '2. COLCHICINA 0,5 mg VO c/12 h × 3 meses (reduce recurrencia en 50%)',
        '3. REPOSO: actividad física intensa contraindicada hasta resolución completa (4–6 semanas)',
        '4. Ecocardiograma para excluir/cuantificar derrame pericárdico',
        '5. TAPONAMIENTO CARDÍACO (tríada de Beck: hipotensión + ingurgitación yugular + ruidos apagados):',
        '   → PERICARDIOCENTESIS guiada por ecocardiografía inmediata',
        '6. BACTERIANA: internación + antibiótico IV + drenaje quirúrgico',
        '7. URÉMICA: hemodiálisis',
      ],
    },
    avoid: {
      'pt': 'EVITAR corticoides como 1ª linha (aumentam risco de recorrência crônica — reservar para pericardite autoimune/urêmica refratária ou contraindicação a AINE/colchicina). Não usar AINEs sem gastroproteção (omeprazol). Não liberar atividade física precocemente (risco de pericardite constritiva). Anticoagulação: usar com extrema cautela (risco de hemopericárdio).',
      'es': 'EVITAR corticoides como 1ª línea (aumentan recurrencia — reservar para autoinmune/urémica). No usar AINEs sin gastroprotección. No liberar actividad física precozmente. Anticoagulación: con extrema cautela (riesgo de hemopericardio).',
    },
    drugs: ['aas', 'metilprednisolona', 'dexametasona'],
  ),

  // ─────────────────────────────────────────────
  //  PEDIATRIA (continuação)
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'tromboembolismo_venoso_ped',
    title: {'pt': 'Trombose Venosa Profunda Pediátrica (TVP)', 'es': 'Trombosis Venosa Profunda Pediátrica (TVP)'},
    severity: {'pt': 'Alto', 'es': 'Alto'},
    recognize: {
      'pt': 'Edema assimétrico de membro, dor, calor, eritema, cordão venoso palpável. Fatores de risco: cateter venoso central (causa mais comum em pediatria!), imobilização, cardiopatia congênita, síndrome nefrótica, trombofilia, trauma, cirurgia. USG Doppler: exame de eleição. TEP associado em até 30%.',
      'es': 'Edema asimétrico de miembro, dolor, calor, eritema, cordón venoso palpable. Factores de riesgo: catéter venoso central (causa más común en pediatría), inmovilización, cardiopatía congénita, síndrome nefrótico, trombofilia. USG Doppler: examen de elección. TEP asociado hasta 30%.',
    },
    actions: {
      'pt': [
        '1. USG DOPPLER do membro afetado para confirmação (não anticoagular sem diagnóstico)',
        '2. ANTICOAGULAÇÃO (iniciar após confirmação diagnóstica):',
        '   → ENOXAPARINA SC (1ª linha):',
        '     • Recém-nascidos/lactentes (<2 meses): 1,5 mg/kg SC 12/12h',
        '     • Crianças >2 meses: 1 mg/kg SC 12/12h',
        '   → HNF IV (se alto risco hemorrágico, IRA grave, necessidade de reversão rápida):',
        '     • Ataque: 50–75 UI/kg IV em 10 min',
        '     • Manutenção: 20 UI/kg/h IV; titular pelo TTPA (60–85 s)',
        '3. MONITORAR: Anti-Xa 4h após 2ª dose de enoxaparina (alvo: 0,5–1,0 UI/mL em TVP)',
        '4. DURAÇÃO:',
        '   → TVP provocada (cateter): 3–6 semanas após remoção do cateter',
        '   → TVP não provocada: 3–6 meses',
        '5. Elevação do membro afetado; compressa morna local',
        '6. Remover cateter central se possível (causa mais comum)',
        '7. Investigar trombofilia se TVP espontânea (<18 anos): fator V Leiden, protrombina G20210A, anticoagulante lúpico',
      ],
      'es': [
        '1. USG DOPPLER del miembro afectado para confirmación',
        '2. ANTICOAGULACIÓN tras confirmación diagnóstica:',
        '   → ENOXAPARINA SC (1ª línea):',
        '     • Neonatos/lactantes (<2 meses): 1,5 mg/kg SC c/12 h',
        '     • Niños >2 meses: 1 mg/kg SC c/12 h',
        '   → HNF IV si alto riesgo hemorrágico o IRA grave',
        '3. MONITORIZAR: Anti-Xa 4 h tras 2ª dosis de enoxaparina (objetivo: 0,5–1,0 UI/mL)',
        '4. DURACIÓN:',
        '   → TVP provocada (catéter): 3–6 semanas tras retirada',
        '   → TVP no provocada: 3–6 meses',
        '5. Elevar miembro; retirar catéter central si posible',
        '6. Investigar trombofilia si TVP espontánea (<18 años)',
      ],
    },
    avoid: {
      'pt': 'EVITAR imobilização prolongada (piora estase venosa e TVP). Não anticoagular sem diagnóstico confirmado por imagem. Warfarina: evitar em neonatos (monitoração difícil, maior variabilidade). Evitar aspirina como anticoagulante em TVP ativa (sem eficácia para tratamento). NOAC: dados limitados em pediatria <18 anos.',
      'es': 'EVITAR inmovilización prolongada. No anticoagular sin confirmación por imagen. Warfarina: evitar en neonatos. No usar aspirina como anticoagulante en TVP activa. NOAC: datos limitados en <18 años.',
    },
    drugs: ['enoxaparina', 'heparina_nf'],
  ),

  ProtocolModel(
    id: 'sinusite_bacteriana_ped',
    title: {'pt': 'Sinusite Bacteriana Pediátrica', 'es': 'Sinusitis Bacteriana Pediátrica'},
    severity: {'pt': 'Baixo', 'es': 'Bajo'},
    recognize: {
      'pt': 'Critérios clínicos (IDSA): (1) sintomas persistentes >10 dias sem melhora; (2) sintomas graves (febre ≥39°C + secreção purulenta ipsilateral ≥3 dias consecutivos); (3) piora bifásica ("double worsening" — melhora inicial seguida de piora após 5–7 dias). NÃO fazer TC de rotina para diagnóstico em crianças. Agentes: S. pneumoniae, H. influenzae não tipável, M. catarrhalis.',
      'es': 'Criterios clínicos (IDSA): (1) síntomas persistentes >10 días sin mejoría; (2) síntomas graves (fiebre ≥39°C + secreción purulenta ipsilateral ≥3 días); (3) empeoramiento bifásico. NO hacer TC de rutina. Agentes: S. pneumoniae, H. influenzae no tipable, M. catarrhalis.',
    },
    actions: {
      'pt': [
        '1. ANTIBIÓTICO de 1ª linha (se critérios diagnósticos preenchidos):',
        '   → Amoxicilina 45 mg/kg/dia VO (2× ao dia) × 10–14 dias (sem fatores de risco para resistência)',
        '   → Amoxicilina-Clavulanato 90 mg/kg/dia VO (se: frequenta creche, uso de ATB nos últimos 3 meses, hospitalização recente, falha à amoxicilina em 72h)',
        '2. LAVAGEM NASAL: SF 0,9% isotônico 2–3× ao dia (alivia obstrução, remove secreções)',
        '3. Analgesia/antipirético: Dipirona 15 mg/kg 6/6h OU Ibuprofeno 10 mg/kg 8/8h',
        '4. REAVALIAÇÃO em 72h: se sem melhora → amoxicilina-clavulanato ou ceftriaxona IM/IV',
        '5. Descongestionantes tópicos: oxymetazolina 0,025% — máx. 3 dias (evitar em <2 anos)',
        '6. COMPLICAÇÕES (indicação de TC + internação + ATB IV):',
        '   → Celulite orbitária (edema periorbitário + limitação de movimentos oculares)',
        '   → Abscesso subperiosteal ou orbitário (proptose, oftalmoplégia)',
        '   → Complicações intracranianas (meningite, abscesso cerebral)',
        '7. Ceftriaxona 50 mg/kg/dia IV se internação por complicação orbitária',
      ],
      'es': [
        '1. ANTIBIÓTICO 1ª línea (si criterios diagnósticos cumplidos):',
        '   → Amoxicilina 45 mg/kg/día VO (2× al día) × 10–14 días',
        '   → Amoxicilina-Clavulanato 90 mg/kg/día si: guardería, ATB reciente, fallo a amoxicilina',
        '2. LAVADO NASAL: SF 0,9% isotónico 2–3× al día',
        '3. Analgesia: Dipirona 15 mg/kg c/6 h O Ibuprofeno 10 mg/kg c/8 h',
        '4. REEVALUACIÓN en 72 h: sin mejoría → amoxicilina-clavulanato o ceftriaxona IM/IV',
        '5. COMPLICACIONES (TC + internación + ATB IV):',
        '   → Celulitis orbitaria (edema periorbitario + limitación movimientos oculares)',
        '   → Absceso subperióstico u orbitario',
        '   → Complicaciones intracraneales',
      ],
    },
    avoid: {
      'pt': 'EVITAR antibióticos sem critérios diagnósticos preenchidos (maioria das rinosinusites é viral e resolve espontaneamente em 10 dias). Descongestionantes orais e tópicos: CONTRAINDICADOS em <2 anos (efeitos adversos graves). Não usar TC de rotina para diagnóstico (exposição à radiação sem benefício adicional). Anti-histamínicos: sem benefício comprovado em sinusite bacteriana.',
      'es': 'EVITAR antibióticos sin criterios diagnósticos (mayoría es viral). Descongestionantes: CONTRAINDICADOS en <2 años. No usar TC de rutina para diagnóstico. Antihistamínicos: sin beneficio probado en sinusitis bacteriana.',
    },
    drugs: ['azitromicina', 'ceftriaxona', 'dexametasona'],
  ),

  // ─────────────────────────────────────────────
  //  PNEUMOLOGIA AVANÇADA
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'crise_asmatica_quase_fatal',
    title: {'pt': 'Asma Quase Fatal (Near-Fatal Asthma)', 'es': 'Asma Casi Fatal'},
    severity: {'pt': 'Crítico', 'es': 'Crítico'},
    recognize: {
      'pt': 'Tórax silencioso, cianose, bradicardia, exaustão respiratória, Glasgow <15, PaCO2 normal ou elevada em paciente acidótico.',
      'es': 'Tórax silente, cianosis, bradicardia, agotamiento, Glasgow <15, PaCO2 normal o elevada.',
    },
    actions: {
      'pt': [
        '1. IOT imediata (tubo calibroso ≥8.0 se possível) + Ventilação Protetora (baixa FR, tempo expiratório longo)',
        '2. Salbutamol contínuo (nebulização) + Ipratrópio',
        '3. Sulfato de Magnésio 2 g IV em 20 min',
        '4. Hidrocortisona 200 mg IV ou Metilprednisolona 125 mg IV',
        '5. Considerar Ketamina para sedação (efeito broncodilatador)',
      ],
      'es': [
        '1. IOT inmediata + Ventilación Protectora (FR baja, TE largo)',
        '2. Salbutamol continuo + Ipratropio',
        '3. Sulfato de Magnesio 2 g IV',
        '4. Hidrocortisona 200 mg IV',
        '5. Considerar Ketamina para sedación',
      ],
    },
    avoid: {
      'pt': 'EVITAR PEEP alta (risco de auto-PEEP e pneumotórax). Não atrasar a intubação se houver rebaixamento de consciência.',
      'es': 'EVITAR PEEP alta. No retrasar IOT si hay deterioro de conciencia.',
    },
    drugs: ['salbutamol', 'sulfato_magnesio', 'hidrocortisona', 'ketamina'],
  ),

  ProtocolModel(
    id: 'mal_asmatico_ped',
    title: {'pt': 'Estado de Mal Asmático Pediátrico', 'es': 'Estado de Mal Asmático Pediátrico'},
    severity: {'pt': 'Crítico', 'es': 'Crítico'},
    recognize: {
      'pt': 'Insuficiência respiratória iminente, silêncio auscultatório, agitação ou letargia, SpO2 <90% com O2.',
      'es': 'Fallo respiratorio, silencio auscultatorio, SpO2 <90% con O2.',
    },
    actions: {
      'pt': [
        '1. Salbutamol contínuo nebulizado + Ipratrópio cada 20 min',
        '2. Hidrocortisona 5 mg/kg IV cada 6h',
        '3. Sulfato de Magnésio 40-50 mg/kg IV (máx 2 g)',
        '4. Considerar Aminofilina IV ou Terbutalina SC',
        '5. VNI ou IOT conforme evolução',
      ],
      'es': [
        '1. Salbutamol continuo + Ipratropio',
        '2. Hidrocortisona 5 mg/kg IV',
        '3. Sulfato de Magnesio 40-50 mg/kg IV',
        '4. Aminofilina IV o Terbutalina SC si refractario',
        '5. VNI o IOT según evolución',
      ],
    },
    avoid: {
      'pt': 'EVITAR intubação tardia, mas realizar com extrema cautela (risco de barotrauma).',
      'es': 'EVITAR demorar IOT en agotamiento.',
    },
    drugs: ['salbutamol', 'hidrocortisona', 'sulfato_magnesio', 'aminofilina'],
  ),

  ProtocolModel(
    id: 'pneumonia_aspirativa',
    title: {'pt': 'Pneumonia Aspirativa', 'es': 'Neumonía Aspirativa'},
    severity: {'pt': 'Médio', 'es': 'Medio'},
    recognize: {
      'pt': 'Histórico de vômito/engasgo + infiltrado em lobos dependentes (base D) + febre + escarro fétido.',
      'es': 'Antecedente de aspiración + infiltrado en zonas dependientes + fiebre.',
    },
    actions: {
      'pt': [
        '1. Antibiótico com cobertura para anaeróbios: Amoxicilina-Sulbactam ou Clindamicina',
        '2. Higiene oral e elevação da cabeceira',
        '3. Suporte de Oxigênio',
        '4. Avaliar deglutição (Fonoaudiologia) pós-crise',
      ],
      'es': [
        '1. Antibiótico: Amox-Sulbactam o Clindamicina',
        '2. Soporte ventilatorio',
        '3. Cabecera elevada',
        '4. Evaluar deglución post-crisis',
      ],
    },
    avoid: {
      'pt': 'EVITAR antibióticos profiláticos em pacientes que aspiraram mas não têm pneumonia clínica (apenas vigilância).',
      'es': 'EVITAR antibióticos profilácticos tras aspiración simple.',
    },
    drugs: ['amoxicilina_sulbactam', 'clindamicina'],
  ),

  // ─────────────────────────────────────────────
  //  OBSTETRÍCIA DE URGÊNCIA
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'descolamento_placenta',
    title: {'pt': 'Descolamento Prematuro de Placenta (DPP)', 'es': 'Desprendimiento Prematuro de Placenta (DPP)'},
    severity: {'pt': 'Crítico', 'es': 'Crítico'},
    recognize: {
      'pt': 'Dor abdominal súbita + hipertonia uterina (abdome em tábua) + sangramento vaginal escuro (80%) + sofrimento fetal.',
      'es': 'Dolor abdominal súbito + hipertonía uterina + sangrado vaginal oscuro + sufrimiento fetal.',
    },
    actions: {
      'pt': [
        '1. Estabilização hemodinâmica (2 acessos calibrosos + Cristaloide)',
        '2. O2 por máscara se instabilidade',
        '3. Avaliação da vitalidade fetal (CTG/USG)',
        '4. INTERRUPÇÃO IMEDIATA (geralmente Cesárea de emergência)',
        '5. Laboratório: Coagulograma (risco alto de CIVD), Hb/Ht, Tipagem sanguínea',
      ],
      'es': [
        '1. Estabilización hemodinámica (2 accesos calibrosos + cristaloide)',
        '2. O2 si es necesario',
        '3. Evaluación vitalidad fetal (CTG/Eco)',
        '4. INTERRUPCIÓN INMEDIATA (Cesárea)',
        '5. Laboratorio: Coagulación, Hb, Tipificación',
      ],
    },
    avoid: {
      'pt': 'EVITAR toque vaginal antes de excluir placenta prévia por USG. Não aguardar exames se houver choque ou sofrimento fetal.',
      'es': 'EVITAR tacto vaginal sin ecografía previa. No demorar cirugía.',
    },
    drugs: ['oxitocina', 'acido_tranexamico'],
  ),

  // ─────────────────────────────────────────────
  //  TOXICOLOGIA AVANÇADA
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'intox_triciclicos',
    title: {'pt': 'Intoxicação por Antidepressivos Tricíclicos', 'es': 'Intoxicación por Tricíclicos'},
    severity: {'pt': 'Crítico', 'es': 'Crítico'},
    recognize: {
      'pt': 'Anticolinérgico (midríase, taquicardia) + ECG com QRS largo (>100ms) e onda R em aVR. Risco de arritmia ventricular fatal.',
      'es': 'Anticolinérgico + ECG con QRS ancho (>100ms) y onda R en aVR. Riesgo de arritmia fatal.',
    },
    actions: {
      'pt': [
        '1. Bicarbonato de Sódio 8.4% 1-2 mEq/kg IV se QRS >100ms ou arritmias',
        '2. Manter pH sanguíneo entre 7.45-7.55',
        '3. Diazepam IV se houver convulsões',
        '4. Noradrenalina se hipotensão refratária',
        '5. Monitorização cardíaca contínua por 24h',
      ],
      'es': [
        '1. Bicarbonato de Sodio 1-2 mEq/kg si QRS >100ms',
        '2. Mantener pH 7.45-7.55',
        '3. Diazepam si hay convulsiones',
        '4. Noradrenalina si hipotensión refractaria',
        '5. Monitoreo cardíaco continuo 24h',
      ],
    },
    avoid: {
      'pt': 'EVITAR Fisostigmina (risco de assistolia). Não usar antiarrítmicos Classe IA ou IC.',
      'es': 'EVITAR Fisostigmina. No usar antiarrítmicos Clase IA/IC.',
    },
    drugs: ['bicarbonato_sodio', 'diazepam', 'noradrenalina'],
  ),

  ProtocolModel(
    id: 'intox_betabloqueadores',
    title: {'pt': 'Intoxicação por Betabloqueadores', 'es': 'Intoxicación por Betabloqueantes'},
    severity: {'pt': 'Crítico', 'es': 'Crítico'},
    recognize: {
      'pt': 'Bradicardia, hipotensão, bloqueios AV, hipoglicemia e convulsões (propranolol).',
      'es': 'Bradicardia, hipotensión, bloqueos AV, hipoglucemia.',
    },
    actions: {
      'pt': [
        '1. Glucagon 5-10 mg IV bólus → infusão 2-5 mg/h (Antídoto de 1ª linha)',
        '2. Terapia de Alta Dose de Insulina (HIET): 1 UI/kg + Glicose',
        '3. Adrenalina ou Dopamina se choque',
        '4. Atropina para bradicardia inicial',
        '5. Marcapasso transcutâneo se refratário',
      ],
      'es': [
        '1. Glucagón 5-10 mg IV → infusión 2-5 mg/h (Antídoto 1ª línea)',
        '2. Insulina dosis alta (HIET): 1 UI/kg + Dextrosa',
        '3. Adrenalina o Dopamina si shock',
        '4. Atropina para bradicardia inicial',
        '5. Marcapasos transcutáneo si refractario',
      ],
    },
    avoid: {
      'pt': 'EVITAR excesso de volume se houver sinais de falência de bomba.',
      'es': 'EVITAR sobrecarga de volumen.',
    },
    drugs: ['glucagon', 'insulina_regular', 'adrenalina', 'atropina'],
  ),

  ProtocolModel(
    id: 'intox_monoxido_carbono',
    title: {'pt': 'Intoxicação por Monóxido de Carbono', 'es': 'Intoxicación por Monóxido de Carbono'},
    severity: {'pt': 'Alto', 'es': 'Alto'},
    recognize: {
      'pt': 'Cefaleia, náuseas, síncope, "pele cereja", carboxihemoglobina (COHb) elevada.',
      'es': 'Cefalea, náuseas, síncope, piel cereza, COHb elevada.',
    },
    actions: {
      'pt': [
        '1. Retirar da fonte de exposição',
        '2. Oxigênio 100% em máscara com reservatório (reduz meia-vida da COHb)',
        '3. Considerar Oxigenoterapia Hiperbárica se COHb >25% ou gestante ou alteração neurológica',
        '4. Monitorar ECG (risco de isquemia miocárdica)',
      ],
      'es': [
        '1. Retirar de la fuente de exposición',
        '2. O2 al 100% con reservorio (reduce vida media COHb)',
        '3. Oxigenoterapia hiperbárica si COHb >25%, gestante o clínica neurológica',
        '4. Monitoreo ECG (riesgo isquemia miocárdica)',
      ],
    },
    avoid: {
      'pt': 'EVITAR confiar na Oximetria de Pulso (não distingue oxihemoglobina de carboxihemoglobina).',
      'es': 'EVITAR confiar en la saturación de oxímetro común.',
    },
    drugs: [],
  ),

  ProtocolModel(
    id: 'intox_metanol_etilenoglicol',
    title: {'pt': 'Intoxicação por Álcoois Tóxicos', 'es': 'Intoxicación por Metanol/Etilenglicol'},
    severity: {'pt': 'Crítico', 'es': 'Crítico'},
    recognize: {
      'pt': 'Acidose metabólica com Anion Gap e Gap Osmótico elevados + alteração visual (metanol) ou IRA (etilenoglicol).',
      'es': 'Acidosis metabólica grave + Gap Osmótico elevado + alteración visual (metanol) o IRA (etilenglicol).',
    },
    actions: {
      'pt': [
        '1. Antídoto: Etanol (VO ou IV) ou Fomepizol (se disponível)',
        '2. Bicarbonato de Sódio para corrigir acidose severa',
        '3. Hemodiálise de urgência (tratamento de escolha se acidose grave)',
        '4. Tiamina e Ácido Folínico como adjuvantes',
      ],
      'es': [
        '1. Antídoto: Etanol o Fomepizol (si disponible)',
        '2. Bicarbonato de Sodio para acidosis severa',
        '3. Hemodiálisis urgente (elección si acidosis grave)',
        '4. Tiamina y Ácido Folínico como adyuvantes',
      ],
    },
    avoid: {
      'pt': 'EVITAR atraso na diálise se houver gap osmótico elevado ou falência renal.',
      'es': 'EVITAR demora en diálisis.',
    },
    drugs: ['bicarbonato_sodio', 'tiamina'],
  ),

  // ─────────────────────────────────────────────
  //  PEDIATRIA AVANÇADA
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'convulsao_febril_ped',
    title: {'pt': 'Convulsão Febril Pediátrica', 'es': 'Convulsión Febril Pediátrica'},
    severity: {'pt': 'Médio', 'es': 'Medio'},
    recognize: {
      'pt': 'Crise tônico-clônica generalizada em criança de 6 meses a 5 anos, associada a febre, sem infecção do SNC.',
      'es': 'Convulsión generalizada en niños (6m-5a) asociada a fiebre, sin infección del SNC.',
    },
    actions: {
      'pt': [
        '1. Manter via aérea pérvia e posição de segurança',
        '2. Se crise >5 min: Diazepam 0.3 mg/kg IV ou Midazolam 0.5 mg/kg Intranasal',
        '3. Tratar a febre: Dipirona ou Paracetamol (não evita nova crise, mas traz conforto)',
        '4. Investigar foco febril (otite, IVAS, ITU)',
      ],
      'es': [
        '1. Posición de seguridad + vía aérea permeable',
        '2. Si dura >5 min: Diazepam 0.3 mg/kg IV o Midazolam 0.5 mg/kg IN',
        '3. Tratar la fiebre: Dipirona o Paracetamol',
        '4. Investigar foco febril',
      ],
    },
    avoid: {
      'pt': 'EVITAR punção lombar de rotina se a crise for simples e a criança estiver bem após o período pós-ictal.',
      'es': 'EVITAR punción lumbar de rutina si la crisis es simple.',
    },
    drugs: ['diazepam', 'midazolam', 'dipirona'],
  ),

  ProtocolModel(
    id: 'mastoidite_aguda',
    title: {'pt': 'Mastoidite Aguda', 'es': 'Mastoiditis Aguda'},
    severity: {'pt': 'Alto', 'es': 'Alto'},
    recognize: {
      'pt': 'Otalgia + febre + abaulamento retroauricular com apagamento do sulco + desvio do pavilhão auricular.',
      'es': 'Otalgia + fiebre + inflamación retroauricular + desplazamiento de la oreja.',
    },
    actions: {
      'pt': [
        '1. Internação hospitalar obrigatória',
        '2. Coleta de secreção (miringotomia) se possível',
        '3. Antibiótico IV: Ceftriaxona 2 g/dia ou Amoxicilina-Sulbactam',
        '4. Analgesia IV',
        '5. Tomografia de mastoides se suspeita de complicações (abscesso)',
      ],
      'es': [
        '1. Internación hospitalaria obligatoria',
        '2. Cultivo de secreción (miringotomía) si es posible',
        '3. Antibiótico IV: Ceftriaxona 2 g/día o Amox-Sulbactam',
        '4. Analgesia IV',
        '5. TC de mastoides si sospecha de complicaciones',
      ],
    },
    avoid: {
      'pt': 'EVITAR tratamento ambulatorial apenas com antibiótico oral.',
      'es': 'EVITAR tratamiento ambulatorio.',
    },
    drugs: ['ceftriaxona', 'amoxicilina_sulbactam', 'dipirona'],
  ),

  // ─────────────────────────────────────────────
  //  DISTÚRBIOS ELETROLÍTICOS AVANÇADOS
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'hipocalcemia_grave',
    title: {'pt': 'Hipocalcemia Grave (Sintomática)', 'es': 'Hipocalcemia Grave'},
    severity: {'pt': 'Alto', 'es': 'Alto'},
    recognize: {
      'pt': 'Sinais de Chvostek e Trousseau +, parestesias, laringoespasmo, prolongamento do intervalo QT.',
      'es': 'Signos de Chvostek y Trousseau +, parestesias, laringoespasmo, QT largo.',
    },
    actions: {
      'pt': [
        '1. Gluconato de Cálcio 10% 1-2 g (10-20 mL) IV em 10-20 min',
        '2. Manutenção: Infusão contínua 0.5-1.5 mg/kg/h de cálcio elementar',
        '3. Monitorar Magnésio (hipocalemia refratária se houver hipomagnesemia)',
        '4. ECG seriado',
      ],
      'es': [
        '1. Gluconato de Calcio 10% 1-2 g IV en 10-20 min',
        '2. Mantenimiento: Infusión continua de calcio',
        '3. Corregir Magnesio si es necesario',
        '4. ECG seriado',
      ],
    },
    avoid: {
      'pt': 'EVITAR bólus rápido de cálcio (risco de arritmias e parada cardíaca). Não misturar com Bicarbonato (precipita).',
      'es': 'EVITAR bolo rápido. No mezclar con Bicarbonato.',
    },
    drugs: ['gluconato_calcio', 'sulfato_magnesio'],
  ),

  // ─────────────────────────────────────────────
  //  HEMATOLOGIA / DOENÇAS DO SANGUE
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'crise_de_anemia_falciforme',
    title: {'pt': 'Crise Vaso-Oclusiva (Anemia Falciforme)', 'es': 'Crisis Vaso-oclusiva (Falciforme)'},
    severity: {'pt': 'Alto', 'es': 'Alto'},
    recognize: {
      'pt': 'Dor intensa em ossos e articulações, febre, histórico de Doença Falciforme.',
      'es': 'Dolor óseo intenso, fiebre, antecedente de Drepanocitosis.',
    },
    actions: {
      'pt': [
        '1. Hidratação vigorosa (venosa ou oral)',
        '2. Analgesia Escalonada: Dipirona → AINEs → Opioides (Morfina IV)',
        '3. Oxigênio apenas se SpO2 <92%',
        '4. Pesquisar infecção gatilho',
        '5. Considerar Transfusão se queda de Hb >2 g/dL do basal',
      ],
      'es': [
        '1. Hidratación vigorosa (IV u oral)',
        '2. Analgesia escalonada: Dipirona → AINEs → Morfina IV',
        '3. O2 solo si SpO2 <92%',
        '4. Investigar infección desencadenante',
        '5. Transfusión si caída de Hb >2 g/dL del basal',
      ],
    },
    avoid: {
      'pt': 'EVITAR hipovolemia e frio (pioram a foicização). Não subestimar a dor do paciente.',
      'es': 'EVITAR deshidratación y frío.',
    },
    drugs: ['morfina', 'dipirona', 'diclofenaco'],
  ),

  // ─────────────────────────────────────────────
  //  ALERGOLOGIA / IMUNOLOGIA AVANÇADA
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'anafilaxia_refrataria',
    title: {'pt': 'Anafilaxia Refratária ao Tratamento Inicial', 'es': 'Anafilaxia Refractaria'},
    severity: {'pt': 'Crítico', 'es': 'Crítico'},
    recognize: {
      'pt': 'Hipotensão persistente ou broncoespasmo grave após 2 doses de Adrenalina IM.',
      'es': 'Hipotensión o broncoespasmo tras 2 dosis de Adrenalina IM.',
    },
    actions: {
      'pt': [
        '1. Infusão Contínua de Adrenalina: 0.1 mcg/kg/min (titular)',
        '2. Glucagon 1-5 mg IV (se o paciente usa Beta-bloqueadores)',
        '3. Salbutamol contínuo ou Aminofilina IV (broncoespasmo severo)',
        '4. Expansão volêmica agressiva (4-6 Litros de cristaloide)',
      ],
      'es': [
        '1. Infusión continua de Adrenalina: 0.1 mcg/kg/min (titular)',
        '2. Glucagón 1-5 mg IV si toma Betabloqueantes',
        '3. Salbutamol continuo o Aminofilina IV si broncoespasmo severo',
        '4. Expansión volémica agresiva (4-6 L de cristaloide)',
      ],
    },
    avoid: {
      'pt': 'EVITAR suspender a vigilância por pelo menos 24h (risco de reação bifásica tardia).',
      'es': 'EVITAR el alta precoz (riesgo de reacción bifásica).',
    },
    drugs: ['adrenalina', 'glucagon', 'aminofilina'],
  ),

  // ─────────────────────────────────────────────
  //  GASTROENTEROLOGIA AVANÇADA
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'colangite_aguda',
    title: {'pt': 'Colangite Aguda', 'es': 'Colangitis Aguda'},
    severity: {'pt': 'Alto', 'es': 'Alto'},
    recognize: {
      'pt': 'Tríade de Charcot: Febre + Icterícia + Dor em Hipocôndrio D. Pentade de Reynolds: Charcot + Hipotensão + Confusão.',
      'es': 'Tríada de Charcot: Fiebre + Ictericia + Dolor HD. Péntada de Reynolds: Charcot + Shock + Confusión.',
    },
    actions: {
      'pt': [
        '1. Hidratação IV vigorosa',
        '2. Antibiótico amplo espectro: Piperacilina-Tazobactam ou Cipro + Metro',
        '3. Descompressão biliar urgente (CPRE)',
        '4. Suporte vasopressor se choque',
      ],
      'es': [
        '1. Hidratación IV vigorosa',
        '2. Antibiótico amplio espectro: Pip-Taz o Cipro + Metro',
        '3. Descompresión biliar urgente (CPRE)',
        '4. Vasopresores si shock',
      ],
    },
    avoid: {
      'pt': 'EVITAR atraso na descompressão biliar, especialmente na Pêntade de Reynolds.',
      'es': 'EVITAR retraso en CPRE.',
    },
    drugs: ['piperacilina_tazobactam', 'ciprofloxacino', 'metronidazol', 'noradrenalina'],
  ),

  // ─────────────────────────────────────────────
  //  UROLOGIA / ANDROLOGIA DE URGÊNCIA
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'priapismo_emergencia',
    title: {'pt': 'Priapismo Isquêmico (Baixo Fluxo)', 'es': 'Priapismo Isquémico'},
    severity: {'pt': 'Alto', 'es': 'Alto'},
    recognize: {
      'pt': 'Ereção dolorosa >4h, corpos cavernosos rígidos, glande flácida.',
      'es': 'Erección dolorosa >4h, cuerpos cavernosos rígidos.',
    },
    actions: {
      'pt': [
        '1. Bloqueio anestésico do nervo dorsal do pênis',
        '2. Aspiração de sangue cavernoso (sangue escuro/acidótico)',
        '3. Injeção intracavernosa de Fenilefrina diluída cada 5 min',
        '4. Se falha clínica: Shunt cirúrgico',
      ],
      'es': [
        '1. Bloqueo anestésico del nervio dorsal del pene',
        '2. Aspiración de sangre cavernosa (oscura/acidótica)',
        '3. Inyección intracavernosa de Fenilefrina diluida c/5 min',
        '4. Si falla clínica: Shunt quirúrgico',
      ],
    },
    avoid: {
      'pt': 'EVITAR o uso de gelo ou compressas quentes como tratamento único. Não usar adrenalina pura.',
      'es': 'EVITAR retraso en tratamiento (>24h causa impotencia irreversible).',
    },
    drugs: ['fenilefrina', 'lidocaina'],
  ),

  // ─────────────────────────────────────────────
  //  CIRURGIA DE URGÊNCIA AVANÇADA
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'hemorragia_intra_abdominal',
    title: {'pt': 'Hemorragia Intra-abdominal (Não Traumática)', 'es': 'Hemorragia Intraabdominal'},
    severity: {'pt': 'Crítico', 'es': 'Crítico'},
    recognize: {
      'pt': 'Dor abdominal súbita + sinais de choque (taquicardia, hipotensão) + abdome distendido e doloroso.',
      'es': 'Dolor abdominal súbito + shock (taquicardia, hipotensión) + distensión.',
    },
    actions: {
      'pt': [
        '1. Protocolo de Transfusão Maciça (CH:PFC:Plaquetas 1:1:1)',
        '2. Ácido Tranexâmico 1 g IV',
        '3. Laparotomia exploradora de urgência ou Angioembolização',
        '4. Aquecer o paciente (prevenir tríade da morte)',
      ],
      'es': [
        '1. Protocolo Transfusión Masiva (GR:PFC:Plaquetas 1:1:1)',
        '2. Ácido Tranexámico 1 g IV',
        '3. Laparotomía exploradora de urgencia o Angioembolización',
        '4. Calentar al paciente (prevenir tríada de la muerte)',
      ],
    },
    avoid: {
      'pt': 'EVITAR tomografia em pacientes instáveis que não respondem à reposição inicial.',
      'es': 'EVITAR TC en pacientes inestables.',
    },
    drugs: ['acido_tranexamico', 'noradrenalina'],
  ),

  ProtocolModel(
    id: 'sindrome_compartimental',
    title: {'pt': 'Síndrome Compartimental de Membros', 'es': 'Síndrome Compartimental'},
    severity: {'pt': 'Crítico', 'es': 'Crítico'},
    recognize: {
      'pt': 'Dor desproporcional à lesão, parestesia, palidez, ausência de pulso (tardio), pressão compartimental elevada.',
      'es': 'Dolor desproporcionado, parestesias, palidez, pulso ausente (tardío).',
    },
    actions: {
      'pt': [
        '1. Retirar gesso ou curativos compressivos',
        '2. Manter membro ao nível do coração (não elevar)',
        '3. Analgesia potente (Opioides)',
        '4. FASCIOTOMIA de urgência (tratamento definitivo)',
      ],
      'es': [
        '1. Retirar yesos o vendajes compresivos',
        '2. Mantener miembro al nivel del corazón (no elevar)',
        '3. Analgesia potente (Opioides)',
        '4. FASCIOTOMÍA de urgencia (tratamiento definitivo)',
      ],
    },
    avoid: {
      'pt': 'EVITAR a elevação do membro (reduz a pressão de perfusão capilar, piorando a isquemia).',
      'es': 'EVITAR elevar el miembro.',
    },
    drugs: ['morfina'],
  ),

  // ─────────────────────────────────────────────
  //  INFECTOLOGIA AVANÇADA
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'sepse_foco_urinario',
    title: {'pt': 'Urossepse', 'es': 'Urosepsis'},
    severity: {'pt': 'Alto', 'es': 'Alto'},
    recognize: {
      'pt': 'Sinais de sepse + dor lombar/disúria + urocultura positiva ou sedimento urinário alterado.',
      'es': 'Sepsis + clínica urinaria + sedimento patológico.',
    },
    actions: {
      'pt': [
        '1. Coleta de culturas (Hemo + Uro)',
        '2. Antibiótico IV: Ceftriaxona ou Ciprofloxacino ou Meropenem (se risco MDR)',
        '3. Ressuscitação volêmica (30 mL/kg)',
        '4. Desobstrução urinária se houver hidronefrose (Duplo J ou Nefrostomia)',
      ],
      'es': [
        '1. Cultivos (hemocultivos + urocultivo)',
        '2. Antibiótico IV precoz: Ceftriaxona, Ciprofloxacino o Meropenem (si riesgo MDR)',
        '3. Resucitación volémica (30 mL/kg)',
        '4. Desobstrucción urinaria si hidronefritis (doble J o Nefrostomía)',
      ],
    },
    avoid: {
      'pt': 'EVITAR tratar apenas com ATB se houver obstrução mecânica (o foco deve ser drenado).',
      'es': 'EVITAR demora en drenaje si hay obstrucción.',
    },
    drugs: ['ceftriaxona', 'ciprofloxacino', 'meropenem', 'noradrenalina'],
  ),

  // ─────────────────────────────────────────────
  //  PSIQUIATRIA / DEPENDÊNCIA QUÍMICA AVANÇADA
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'sindrome_abst_opioides',
    title: {'pt': 'Síndrome de Abstinência de Opioides', 'es': 'Síndrome de Abstinencia de Opioides'},
    severity: {'pt': 'Médio', 'es': 'Medio'},
    recognize: {
      'pt': 'Midríase, bocejos, rinorreia, piloereção, cólicas abdominais, diarreia e ansiedade extrema.',
      'es': 'Midriasis, bostezos, rinorrea, piloerección, cólicos, diarrea y ansiedad extrema.',
    },
    actions: {
      'pt': [
        '1. Clonidina 0.1 mg cada 8h (controle simpático)',
        '2. Metadona 10-20 mg VO (reposição escalonada)',
        '3. Loperamida para diarreia',
        '4. Antieméticos (Metoclopramida)',
        '5. Suporte de hidratação',
      ],
      'es': [
        '1. Clonidina 0.1 mg c/8h (control simpático)',
        '2. Metadona 10-20 mg VO (reposición escalonada)',
        '3. Loperamida para diarrea',
        '4. Antieméticos (Metoclopramida)',
        '5. Soporte de hidratación',
      ],
    },
    avoid: {
      'pt': 'EVITAR uso de Naloxona (irá precipitar ou piorar gravemente os sintomas).',
      'es': 'EVITAR Naloxona.',
    },
    drugs: ['clonidina', 'metadona', 'loperamida', 'metoclopramida'],
  ),

  // ─────────────────────────────────────────────
  //  CARDIOLOGIA AVANÇADA
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'miocardite_aguda',
    title: {'pt': 'Miocardite Aguda', 'es': 'Miocarditis Aguda'},
    severity: {'pt': 'Alto', 'es': 'Alto'},
    recognize: {
      'pt': 'Dor torácica ou IC após quadro viral + elevação de troponina + ECG alterado + disfunção ventricular ao Eco.',
      'es': 'Dolor torácico o IC post-viral + troponina elevada + Eco patológico.',
    },
    actions: {
      'pt': [
        '1. Internação e monitoração de arritmias',
        '2. Suporte hemodinâmico (Inotrópicos se necessário)',
        '3. Tratamento de IC (IECA, Espironolactona) após estabilização',
        '4. Repouso absoluto na fase aguda',
        '5. Considerar RMN cardíaca ou Biópsia em casos graves',
      ],
      'es': [
        '1. Internación y monitoreo de arritmias',
        '2. Soporte hemodinámico (inotrópicos si es necesario)',
        '3. Tratamiento de IC (IECA, Espironolactona) tras estabilización',
        '4. Reposo absoluto en fase aguda',
        '5. Considerar RMN cardíaca o Biopsia en casos graves',
      ],
    },
    avoid: {
      'pt': 'EVITAR AINEs na fase aguda (pode piorar a inflamação miocárdica em modelos animais).',
      'es': 'EVITAR AINEs en fase aguda.',
    },
    drugs: ['dobutamina', 'enalapril', 'espironolactona', 'furosemida'],
  ),

  // ─────────────────────────────────────────────
  //  CARDIOLOGIA — BRADIARRITMIA
  // ─────────────────────────────────────────────
  ProtocolModel(
    id: 'bradiarritmia_grave',
    title: {'pt': 'Bradiarritmia Sintomática / Bloqueio AV de Alto Grau', 'es': 'Bradiarritmia Sintomática / Bloqueo AV de Alto Grado'},
    severity: {'pt': 'Alto', 'es': 'Alto'},
    recognize: {
      'pt': 'FC <50 bpm com sintomas: síncope, pré-síncope, hipotensão, angor, dispneia, confusão. ECG: BAV 2º grau Mobitz II (bloqueio súbito sem progressão do PR) ou BAV 3º grau (dissociação atrioventricular completa) são emergências. BAV 1º grau e Mobitz I (Wenckebach): geralmente benignos.',
      'es': 'FC <50 lpm con síntomas: síncope, presíncope, hipotensión, angina, disnea. ECG: BAV 2º grado Mobitz II o BAV 3º grado (disociación AV completa) son emergencias.',
    },
    actions: {
      'pt': [
        '1. ABCDE; O2; monitor cardíaco contínuo; acesso venoso',
        '2. Atropina 0,5 mg IV bolus (repetir a cada 3–5 min; dose máxima 3 mg) — 1ª linha em BAV infranodal (cautela: pode piorar BAV infra-His)',
        '3. Se sem resposta à atropina ou BAV 3º grau / Mobitz II:',
        '   → Marcapasso transcutâneo imediato (desfibrilador externo em modo pacemaker): 60–80 ppm; aumentar mA até captura elétrica + pulso',
        '   → Sedação + analgesia para o procedimento (midazolam + fentanil)',
        '4. Enquanto aguarda marcapasso: Dopamina 2–20 µg/kg/min IV OU Adrenalina 2–10 µg/min IV (cronotropia positiva)',
        '5. Marcapasso transvenoso temporário: indicado se transcutâneo ineficaz ou em uso prolongado',
        '6. Identificar e reverter causa: hiperpotassemia (gluconato de cálcio), intoxicação digitálica, betabloqueador (glucagon 3–10 mg IV), hipotireoidismo, IAM inferior (reperfusão)',
        '7. Marcapasso definitivo: indicado em BAV 3º grau sintomático, Mobitz II, BAV 2:1 com bloqueio infranodal',
        '8. Suspender fármacos cronotrópicos negativos: betabloqueadores, bloqueadores de cálcio, digoxina, amiodarona',
      ],
      'es': [
        '1. ABCDE; O2; monitor cardíaco continuo; acceso venoso',
        '2. Atropina 0,5 mg IV bolo (repetir c/3–5 min; dosis máx. 3 mg)',
        '3. Si sin respuesta o BAV 3º grado/Mobitz II:',
        '   → Marcapasos transcutáneo inmediato: 60–80 lpm; aumentar mA hasta captura + pulso',
        '   → Sedación + analgesia (midazolam + fentanilo)',
        '4. Mientras aguarda MP: Dopamina 2–20 µg/kg/min IV O Adrenalina 2–10 µg/min IV',
        '5. Marcapasos transvenoso temporal: si transcutáneo ineficaz o uso prolongado',
        '6. Identificar causa reversible: hiperpotasemia, intoxicación digitálica, betabloqueador (glucagón 3–10 mg IV), IAM inferior',
        '7. Marcapasos definitivo: BAV 3º grado sintomático, Mobitz II, BAV 2:1 infranodal',
        '8. Suspender: betabloqueadores, calcioantagonistas, digoxina, amiodarona',
      ],
    },
    avoid: {
      'pt': 'EVITAR atropina em BAV infranodal (Mobitz II, BAV 3º grau com complexo largo) — pode paradoxalmente piorar bloqueio. Não usar verapamil ou diltiazem (bloqueio AV adicional). Evitar isoproterenol sem marcapasso disponível (↑ consumo O2 miocárdico, arritmias). Não aguardar muito antes do marcapasso transcutâneo se paciente instável.',
      'es': 'EVITAR atropina en BAV infranodal (puede empeorar bloqueo). No usar verapamil ni diltiazem. Evitar isoproterenol sin marcapasos disponible. No demorar marcapasos transcutáneo si inestabilidad.',
    },
    drugs: ['adrenalina', 'atropina', 'dopamina', 'amiodarona'],
  ),

];
