import '../models/drug_model.dart';

/// Base de fármacos MedCases Pro
/// Fontes: Harrison's Principles of Internal Medicine (21ª ed.),
/// Goodman & Gilman's Pharmacological Basis of Therapeutics (14ª ed.),
/// Micromedex, UpToDate, SBC, SBD, AHA/ACC, IDSA, SCCM guidelines.
const List<DrugModel> drugsDatabase = [

  // ─────────────────────────────────────────────
  //  ANALGÉSICOS / ANTIPIRÉTICOS
  // ─────────────────────────────────────────────
  DrugModel(
    id: 'paracetamol',
    name: 'Paracetamol / Acetaminofeno',
    className: {'pt': 'Analgésico / antipirético', 'es': 'Analgésico / antipirético'},
    category: {'pt': 'Analgésicos', 'es': 'Analgésicos'},
    route: 'VO / IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': '500–1000 mg a cada 6h (adulto). Máx. 4 g/dia; hepatopatas/baixo peso/álcool: Máx. 2 g/dia. IV: 1 g em 15 min a cada 6h.',
      'es': '500–1000 mg cada 6 h (adulto). Máx. 4 g/día; hepatópatas/bajo peso/alcohol: Máx. 2 g/día. IV: 1 g en 15 min cada 6 h.',
    },
    renalAlert: {
      'pt': 'ClCr 10–50 mL/min: intervalo a cada 6h. ClCr <10 mL/min ou diálise: a cada 8h. Geralmente seguro.',
      'es': 'ClCr 10–50 mL/min: intervalo cada 6 h. ClCr <10 mL/min o diálisis: cada 8 h.',
    },
    elderlyAlert: {
      'pt': 'Evitar dose máxima plena em frágeis, baixo peso (<50 kg) ou hepatopatia. Preferir 500 mg a cada 6–8h.',
      'es': 'Evitar dosis máxima plena en frágiles, bajo peso (<50 kg) o hepatopatía.',
    },
    mechanism: {
      'pt': 'Inibe síntese central de prostaglandinas (COX-3 central); ativa sistema serotoninérgico descendente.',
      'es': 'Inhibe síntesis central de prostaglandinas (COX-3 central); activa sistema serotoninérgico descendente.',
    },
    warning: {
      'pt': 'Hepatotoxicidade grave em overdose (antídoto: N-acetilcisteína). Verificar presença em compostos combinados para evitar dose dupla.',
      'es': 'Hepatotoxicidad grave en sobredosis (antídoto: N-acetilcisteína). Verificar presencia en compuestos combinados.',
    },
    adverse: {
      'pt': ['Hepatotoxicidade (dose-dependente)', 'Náuseas', 'Rash (raro)', 'Anafilaxia (muito raro)'],
      'es': ['Hepatotoxicidad (dosis-dependiente)', 'Náuseas', 'Rash (raro)', 'Anafilaxia (muy raro)'],
    },
  ),

  DrugModel(
    id: 'dipirona',
    name: 'Dipirona / Metamizol',
    className: {'pt': 'Analgésico / antipirético não-opioide', 'es': 'Analgésico / antipirético no opioide'},
    category: {'pt': 'Analgésicos', 'es': 'Analgésicos'},
    route: 'VO / IV / IM',
    doseType: 'fixed',
    fixedDose: {
      'pt': '500–1000 mg a cada 6–8h (adulto). IV: infundir lentamente (≥15 min) para evitar hipotensão. Máx. 4 g/dia.',
      'es': '500–1000 mg cada 6–8 h (adulto). IV: infundir lentamente (≥15 min). Máx. 4 g/día.',
    },
    renalAlert: {
      'pt': 'Metabólitos acumulam em insuficiência renal. Evitar em ClCr <30 mL/min ou usar com cautela e menor dose.',
      'es': 'Metabolitos se acumulan en insuficiencia renal. Evitar con ClCr <30 mL/min.',
    },
    elderlyAlert: {
      'pt': 'Risco aumentado de hipotensão na via IV. Infundir lentamente; monitorar PA.',
      'es': 'Mayor riesgo de hipotensión IV. Infundir lentamente; monitorizar PA.',
    },
    mechanism: {
      'pt': 'Inibe prostaglandinas centrais e periféricas; efeito espasmolítico musculotrópico; ativação opioide endógena.',
      'es': 'Inhibe prostaglandinas centrales y periféricas; efecto espasmolítico musculotrópico.',
    },
    warning: {
      'pt': 'Agranulocitose (1:1.000.000 usos; raro mas grave). Hipotensão severa em IV rápido. Proibida em alguns países (EUA, Reino Unido).',
      'es': 'Agranulocitosis (1:1.000.000; raro pero grave). Hipotensión severa en IV rápido.',
    },
    adverse: {
      'pt': ['Hipotensão (IV rápido)', 'Anafilaxia', 'Agranulocitose (raro)', 'Náuseas'],
      'es': ['Hipotensión (IV rápido)', 'Anafilaxia', 'Agranulocitosis (raro)', 'Náuseas'],
    },
  ),

  DrugModel(
    id: 'cetorolaco',
    name: 'Cetorolaco / Ketorolac',
    className: {'pt': 'AINE – analgésico potente', 'es': 'AINE – analgésico potente'},
    category: {'pt': 'Analgésicos', 'es': 'Analgésicos'},
    route: 'VO / SL / IV / IM',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'VO/SL: 10 mg a cada 4–6h (máx. 40 mg/dia). IV/IM: 15–30 mg a cada 6h (máx. 120 mg/dia). LIMITAR a 5 dias.',
      'es': 'VO/SL: 10 mg cada 4–6 h (máx. 40 mg/día). IV/IM: 15–30 mg cada 6 h (máx. 120 mg/día). LIMITAR a 5 días.',
    },
    renalAlert: {
      'pt': 'EVITAR em insuficiência renal (ClCr <50 mL/min), desidratação, hipovolemia ou uso de IECA/ARA2. Nefrotóxico.',
      'es': 'EVITAR en insuficiencia renal (ClCr <50 mL/min), deshidratación, hipovolemia o uso de IECA/ARA2.',
    },
    elderlyAlert: {
      'pt': '>65 anos: reduzir dose (máx. 15 mg IV, 60 mg/dia); usar por no máximo 2–3 dias; alto risco de sangramento GI e renal.',
      'es': '>65 años: reducir dosis (máx. 15 mg IV, 60 mg/día); usar máx. 2–3 días; alto riesgo GI y renal.',
    },
    mechanism: {
      'pt': 'Inibe COX-1 e COX-2; reduz síntese de prostaglandinas e tromboxano.',
      'es': 'Inhibe COX-1 y COX-2; reduce síntesis de prostaglandinas y tromboxano.',
    },
    warning: {
      'pt': 'Sangramento GI, úlcera péptica, insuficiência renal aguda, inibição plaquetária. Contraindicado perioperatório de cirurgia cardíaca (aumenta risco CV).',
      'es': 'Sangrado GI, úlcera péptica, IRA, inhibición plaquetaria. Contraindicado perioperatorio cardíaco.',
    },
    adverse: {
      'pt': ['Sangramento GI', 'IRA', 'Inibição plaquetária', 'Edema', 'Hipertensão'],
      'es': ['Sangrado GI', 'IRA', 'Inhibición plaquetaria', 'Edema', 'Hipertensión'],
    },
  ),

  DrugModel(
    id: 'morfina',
    name: 'Morfina',
    className: {'pt': 'Opioide forte – agonista µ', 'es': 'Opioide fuerte – agonista µ'},
    category: {'pt': 'Opioides', 'es': 'Opioides'},
    route: 'IV / VO / SC',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Dor aguda IV: 2–4 mg IV lento a cada 5–15 min (titulação). Manutenção: 2–10 mg IV/SC a cada 4h. VO: 15–30 mg a cada 4h.',
      'es': 'Dolor agudo IV: 2–4 mg IV lento cada 5–15 min (titulación). Mantenimiento: 2–10 mg IV/SC cada 4 h. VO: 15–30 mg cada 4 h.',
    },
    renalAlert: {
      'pt': 'Metabólito ativo (morfina-6-glucuronídeo) acumula em IRC. ClCr <30 mL/min: reduzir dose 50–75%; preferir fentanil. Evitar em diálise.',
      'es': 'Metabolito activo (morfina-6-glucurónido) se acumula en IRC. ClCr <30 mL/min: reducir dosis 50–75%; preferir fentanilo.',
    },
    elderlyAlert: {
      'pt': 'Iniciar com 1–2 mg IV; alto risco de delirium, quedas, constipação, retenção urinária e depressão respiratória.',
      'es': 'Iniciar con 1–2 mg IV; alto riesgo de delirium, caídas, constipación, retención urinaria y depresión respiratoria.',
    },
    mechanism: {
      'pt': 'Agonista dos receptores µ, κ e δ opioides: analgesia, sedação, depressão respiratória, efeitos GI.',
      'es': 'Agonista de receptores µ, κ y δ opioides: analgesia, sedación, depresión respiratoria, efectos GI.',
    },
    warning: {
      'pt': 'Depressão respiratória (antídoto: naloxona 0,4–2 mg IV/IM/SC). Constipação — usar laxativo profilático. Dependência física.',
      'es': 'Depresión respiratoria (antídoto: naloxona 0,4–2 mg IV/IM/SC). Constipación — usar laxante profiláctico.',
    },
    adverse: {
      'pt': ['Depressão respiratória', 'Sedação', 'Náusea/vômito', 'Constipação', 'Hipotensão', 'Prurido', 'Retenção urinária'],
      'es': ['Depresión respiratoria', 'Sedación', 'Náusea/vómito', 'Constipación', 'Hipotensión', 'Prurito', 'Retención urinaria'],
    },
  ),

  DrugModel(
    id: 'fentanil',
    name: 'Fentanil / Fentanila',
    className: {'pt': 'Opioide forte – agonista µ', 'es': 'Opioide fuerte – agonista µ'},
    category: {'pt': 'Opioides', 'es': 'Opioides'},
    route: 'IV / SC / Transdérmico',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Dor aguda/procedimento: 0,5–1,5 µg/kg IV (bolus). Infusão: 25–200 µg/h IV. Analgesia pós-op: titular conforme dor.',
      'es': 'Dolor agudo/procedimiento: 0,5–1,5 µg/kg IV (bolo). Infusión: 25–200 µg/h IV.',
    },
    renalAlert: {
      'pt': 'Preferido em IRC (não acumula metabólitos ativos). Reduzir dose em ClCr <30 mL/min — iniciar com 50% da dose.',
      'es': 'Preferido en IRC (no acumula metabolitos activos). Reducir dosis en ClCr <30 mL/min — iniciar con 50% de la dosis.',
    },
    elderlyAlert: {
      'pt': 'Reduzir dose 25–50%. Risco de depressão respiratória, rigidez torácica (IV rápido), bradicardia.',
      'es': 'Reducir dosis 25–50%. Riesgo de depresión respiratoria, rigidez torácica (IV rápido), bradicardia.',
    },
    mechanism: {
      'pt': 'Agonista µ-opioide potente (100× morfina); lipossolúvel, início rápido, meia-vida curta (IV).',
      'es': 'Agonista µ-opioide potente (100× morfina); liposoluble, inicio rápido, vida media corta (IV).',
    },
    warning: {
      'pt': 'Rigidez da parede torácica em doses altas/IV rápido (tratar com naloxona ou bloqueador neuromuscular). Antídoto: naloxona.',
      'es': 'Rigidez de la pared torácica en dosis altas/IV rápido (tratar con naloxona o BNM). Antídoto: naloxona.',
    },
    adverse: {
      'pt': ['Depressão respiratória', 'Bradicardia', 'Hipotensão', 'Rigidez torácica', 'Náuseas', 'Sedação'],
      'es': ['Depresión respiratoria', 'Bradicardia', 'Hipotensión', 'Rigidez torácica', 'Náuseas', 'Sedación'],
    },
  ),

  DrugModel(
    id: 'tramadol',
    name: 'Tramadol',
    className: {'pt': 'Opioide fraco + inibidor de recaptação de serotonina/noradrenalina', 'es': 'Opioide débil + inhibidor de recaptación de serotonina/noradrenalina'},
    category: {'pt': 'Opioides', 'es': 'Opioides'},
    route: 'VO / IV / IM',
    doseType: 'fixed',
    fixedDose: {
      'pt': '50–100 mg a cada 6–8h (VO ou IV lento). Máx. 400 mg/dia. IR prolongado: 100–300 mg 2×/dia.',
      'es': '50–100 mg cada 6–8 h (VO o IV lento). Máx. 400 mg/día.',
    },
    renalAlert: {
      'pt': 'ClCr <30 mL/min: intervalo a cada 12h, máx. 200 mg/dia. Hemodiálise: dose pós-diálise.',
      'es': 'ClCr <30 mL/min: intervalo cada 12 h, máx. 200 mg/día.',
    },
    elderlyAlert: {
      'pt': '>75 anos: máx. 300 mg/dia. Risco de convulsões, síndrome serotoninérgica, delirium, quedas.',
      'es': '>75 años: máx. 300 mg/día. Riesgo de convulsiones, síndrome serotoninérgico, delirium, caídas.',
    },
    mechanism: {
      'pt': 'Agonista µ-opioide fraco + inibe recaptação de serotonina e noradrenalina.',
      'es': 'Agonista µ-opioide débil + inhibe recaptación de serotonina y noradrenalina.',
    },
    warning: {
      'pt': 'Síndrome serotoninérgica com ISRS/IRSN/IMAO. Convulsões (limiar baixo). Não usar em metabolizadores ultrarrápidos do CYP2D6 (risco de overdose).',
      'es': 'Síndrome serotoninérgico con ISRS/IRSN/IMAO. Convulsiones (umbral bajo).',
    },
    adverse: {
      'pt': ['Náuseas/vômitos', 'Tontura', 'Constipação', 'Sudorese', 'Convulsões', 'Síndrome serotoninérgica'],
      'es': ['Náuseas/vómitos', 'Mareo', 'Constipación', 'Sudoración', 'Convulsiones', 'Síndrome serotoninérgico'],
    },
  ),

  DrugModel(
    id: 'pregabalina',
    name: 'Pregabalina',
    className: {'pt': 'Anticonvulsivante / dor neuropática', 'es': 'Anticonvulsivante / dolor neuropático'},
    category: {'pt': 'Analgésicos adjuvantes', 'es': 'Analgésicos adyuvantes'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Início: 75 mg 2×/dia. Titular até 150–300 mg 2×/dia conforme resposta. Máx. 600 mg/dia.',
      'es': 'Inicio: 75 mg 2×/día. Titular hasta 150–300 mg 2×/día. Máx. 600 mg/día.',
    },
    renalAlert: {
      'pt': 'ClCr 30–60: máx. 300 mg/dia. ClCr 15–30: máx. 150 mg/dia. ClCr <15: 75 mg/dia. HD: dose suplementar pós-sessão.',
      'es': 'ClCr 30–60: máx. 300 mg/día. ClCr 15–30: máx. 150 mg/día. ClCr <15: 75 mg/día.',
    },
    elderlyAlert: {
      'pt': 'Iniciar com 25–50 mg à noite. Risco de sedação, edema periférico, quedas, confusão.',
      'es': 'Iniciar con 25–50 mg al acostarse. Riesgo de sedación, edema periférico, caídas, confusión.',
    },
    mechanism: {
      'pt': 'Liga-se à subunidade α2-δ dos canais de Ca² voltagem-dependentes → reduz liberação de neurotransmissores excitatórios.',
      'es': 'Se une a la subunidad α2-δ de canales de Ca²⁺ voltaje-dependientes → reduce liberación de neurotransmisores excitatorios.',
    },
    warning: {
      'pt': 'Depressão respiratória com opioides (combinação de risco). Dependência/abuso. Retirada gradual para evitar convulsões.',
      'es': 'Depresión respiratoria con opioides. Dependencia/abuso. Retirada gradual para evitar convulsiones.',
    },
    adverse: {
      'pt': ['Sonolência', 'Tontura', 'Edema periférico', 'Ganho de peso', 'Ataxia', 'Visão borrada'],
      'es': ['Somnolencia', 'Mareo', 'Edema periférico', 'Ganancia de peso', 'Ataxia', 'Visión borrosa'],
    },
  ),

  // ─────────────────────────────────────────────
  //  ANTIBIÓTICOS
  // ─────────────────────────────────────────────
  DrugModel(
    id: 'ceftriaxona',
    name: 'Ceftriaxona',
    className: {'pt': 'Cefalosporina de 3ª geração', 'es': 'Cefalosporina de 3ª generación'},
    category: {'pt': 'Antibióticos', 'es': 'Antibióticos'},
    route: 'IV / IM',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Pneumonia/IAM: 1–2 g/dia IV/IM. Meningite: 2 g a cada 12h IV. ITU/infecção suave: 1 g/dia. Gonorreia: 500 mg IM dose única.',
      'es': 'Neumonía: 1–2 g/día IV/IM. Meningitis: 2 g cada 12 h IV. ITU/infección leve: 1 g/día. Gonorrea: 500 mg IM dosis única.',
    },
    renalAlert: {
      'pt': 'Geralmente não necessita ajuste renal (eliminação biliar/renal). Em DRC grave + disfunção hepática: máx. 2 g/dia.',
      'es': 'Generalmente no requiere ajuste renal. En IRC grave + disfunción hepática: máx. 2 g/día.',
    },
    elderlyAlert: {
      'pt': 'Considerar ajuste em hepatopatia grave associada. Risco de C. difficile. Monitorar função renal.',
      'es': 'Considerar ajuste en hepatopatía grave. Riesgo de C. difficile.',
    },
    mechanism: {
      'pt': 'Inibe síntese da parede bacteriana ligando-se às PBPs. Bactericida tempo-dependente. Espectro: Gram-positivos, Gram-negativos, anaeróbios limitados.',
      'es': 'Inhibe síntesis de pared bacteriana uniéndose a PBPs. Bactericida tiempo-dependiente.',
    },
    warning: {
      'pt': 'Alergia a β-lactâmico (anafilaxia rara; cross-reatividade penicilina ~1%). Colite por C. difficile. Colelitíase biliar (cristais ceftriaxona). Não misturar com cálcio IV em neonatos.',
      'es': 'Alergia a β-lactámicos. Colitis por C. difficile. Colelitiasis biliar (cristales).',
    },
    adverse: {
      'pt': ['Diarreia', 'Rash', 'Anafilaxia', 'Colite por C. difficile', 'Barro biliar/colelitíase'],
      'es': ['Diarrea', 'Rash', 'Anafilaxia', 'Colitis por C. difficile', 'Barro biliar/colelitiasis'],
    },
  ),

  DrugModel(
    id: 'vancomicina',
    name: 'Vancomicina',
    className: {'pt': 'Glicopeptídeo', 'es': 'Glucopéptido'},
    category: {'pt': 'Antibióticos', 'es': 'Antibióticos'},
    route: 'IV / VO (apenas C. diff)',
    doseType: 'weight',
    mgKg: 15,
    fixedDose: {
      'pt': '15–20 mg/kg IV a cada 8–12h (guiado por AUC/MIC ou nível vale ≥ 15–20 µg/mL). Infundir em ≥60 min. Dose máx. habitual: 3 g/dose; ajustar por farmacocinética.',
      'es': '15–20 mg/kg IV cada 8–12 h (guiado por AUC/MIC o nivel valle ≥ 15–20 µg/mL). Infundir ≥60 min.',
    },
    renalAlert: {
      'pt': 'Ajuste obrigatório por ClCr; monitorar níveis séricos. ClCr 20–49: a cada 24–48h. ClCr <20: a cada 48–96h. HD: dose pós-sessão.',
      'es': 'Ajuste obligatorio por ClCr; monitorizar niveles séricos. ClCr 20–49: cada 24–48 h. ClCr <20: cada 48–96 h.',
    },
    elderlyAlert: {
      'pt': 'Maior risco de nefrotoxicidade. Monitorar nível de vancomicina, creatinina e diurese com mais frequência.',
      'es': 'Mayor riesgo de nefrotoxicidad. Monitorizar nivel de vancomicina, creatinina y diuresis.',
    },
    mechanism: {
      'pt': 'Liga-se ao D-Ala–D-Ala do peptidoglicano → inibe síntese da parede bacteriana. Bactericida para Gram-positivos, incluindo MRSA.',
      'es': 'Se une al D-Ala–D-Ala del peptidoglicano → inhibe síntesis de pared bacteriana. Bactericida para Gram-positivos (MRSA).',
    },
    warning: {
      'pt': 'Nefrotoxicidade (especialmente com aminoglicosídeos). Síndrome do Homem Vermelho (infusão rápida → rubor, prurido, hipotensão). Ototoxicidade. Monitorar níveis séricos (AUC 400–600).',
      'es': 'Nefrotoxicidad (especialmente con aminoglucósidos). Síndrome del Hombre Rojo (infusión rápida). Ototoxicidad.',
    },
    adverse: {
      'pt': ['Nefrotoxicidade', 'Síndrome do Homem Vermelho', 'Ototoxicidade', 'Neutropenia', 'Flebite'],
      'es': ['Nefrotoxicidad', 'Síndrome del Hombre Rojo', 'Ototoxicidad', 'Neutropenia', 'Flebitis'],
    },
  ),

  DrugModel(
    id: 'piperacilina_tazobactam',
    name: 'Piperacilina-Tazobactam (Pip-Taz)',
    className: {'pt': 'Penicilina + inibidor de β-lactamase', 'es': 'Penicilina + inhibidor de β-lactamasa'},
    category: {'pt': 'Antibióticos', 'es': 'Antibióticos'},
    route: 'IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': '4,5 g (4 g pip + 0,5 g taz) a cada 6–8h IV. Infusão prolongada (3–4h) melhora eficácia para Pseudomonas. Sepse/neutropenia: 4,5 g a cada 6h.',
      'es': '4,5 g (4 g pip + 0,5 g taz) cada 6–8 h IV. Infusión prolongada (3–4 h) mejora eficacia para Pseudomonas.',
    },
    renalAlert: {
      'pt': 'ClCr 20–40: 3,375 g a cada 6h. ClCr <20: 2,25 g a cada 6h ou 3,375 g a cada 8h. HD: 2,25 g a cada 8h + dose suplementar após HD.',
      'es': 'ClCr 20–40: 3,375 g cada 6 h. ClCr <20: 2,25 g cada 6 h. HD: 2,25 g cada 8 h + dosis suplementaria.',
    },
    elderlyAlert: {
      'pt': 'Monitorar função renal. Ajustar dose conforme ClCr. Neurotoxicidade (convulsões) em doses altas com insuficiência renal.',
      'es': 'Monitorizar función renal. Neurotoxicidad (convulsiones) en dosis altas con insuficiencia renal.',
    },
    mechanism: {
      'pt': 'Piperacilina inibe PBPs (bactericida). Tazobactam inibe β-lactamases → amplia espectro vs. Gram-negativos produtores de ESBL e anaeróbios.',
      'es': 'Piperacilina inhibe PBPs (bactericida). Tazobactam inhibe β-lactamasas → amplia espectro vs. Gram-negativos ESBL y anaerobios.',
    },
    warning: {
      'pt': 'Hipopotassemia (monitorar K+). Colite por C. difficile. Alergia a penicilinas. Não usar para KPC (Klebsiella produtora de carbapenemase).',
      'es': 'Hipopotasemia. Colitis por C. difficile. Alergia a penicilinas. No usar para KPC.',
    },
    adverse: {
      'pt': ['Diarreia/C. difficile', 'Hipopotassemia', 'Rash', 'Anafilaxia', 'Convulsões (altas doses/IRC)'],
      'es': ['Diarrea/C. difficile', 'Hipopotasemia', 'Rash', 'Anafilaxia', 'Convulsiones (dosis altas/IRC)'],
    },
  ),

  DrugModel(
    id: 'meropenem',
    name: 'Meropenem',
    className: {'pt': 'Carbapenêmico', 'es': 'Carbapenémico'},
    category: {'pt': 'Antibióticos', 'es': 'Antibióticos'},
    route: 'IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Infecção grave/UTI: 1–2 g a cada 8h IV. Meningite: 2 g a cada 8h. Infusão prolongada (3h) para Pseudomonas/Acinetobacter.',
      'es': 'Infección grave/UCI: 1–2 g cada 8 h IV. Meningitis: 2 g cada 8 h. Infusión prolongada (3 h) para Pseudomonas/Acinetobacter.',
    },
    renalAlert: {
      'pt': 'ClCr 26–50: 1 g a cada 12h. ClCr 10–25: 500 mg a cada 12h. ClCr <10: 500 mg a cada 24h. HD: dose após sessão.',
      'es': 'ClCr 26–50: 1 g cada 12 h. ClCr 10–25: 500 mg cada 12 h. ClCr <10: 500 mg cada 24 h.',
    },
    elderlyAlert: {
      'pt': 'Ajustar por ClCr. Risco de convulsões maior (especialmente em ClCr reduzido). Monitorar neurológico.',
      'es': 'Ajustar por ClCr. Riesgo de convulsiones mayor (especialmente con ClCr reducido).',
    },
    mechanism: {
      'pt': 'Inibe PBPs → lise bacteriana. Resistente à maioria das β-lactamases. Cobre Gram-negativos (incluindo Pseudomonas), Gram-positivos e anaeróbios. Não cobre MRSA.',
      'es': 'Inhibe PBPs → lisis bacteriana. Resistente a mayoría de β-lactamasas. Cubre Gram-negativos (Pseudomonas), Gram-positivos y anaerobios.',
    },
    warning: {
      'pt': 'Reservar para infecções multirresistentes (ESBL, AmpC). Risco de convulsões (menor que imipenem). Seleciona KPC. Usar de forma racional – antibiótico de último recurso.',
      'es': 'Reservar para infecciones multirresistentes. Riesgo de convulsiones. Selecciona KPC.',
    },
    adverse: {
      'pt': ['Convulsões', 'Diarreia/C. difficile', 'Rash', 'Anafilaxia', 'Elevação de transaminases'],
      'es': ['Convulsiones', 'Diarrea/C. difficile', 'Rash', 'Anafilaxia', 'Elevación de transaminasas'],
    },
  ),

  DrugModel(
    id: 'azitromicina',
    name: 'Azitromicina',
    className: {'pt': 'Macrolídeo – antibiótico de amplo espectro', 'es': 'Macrólido – antibiótico de amplio espectro'},
    category: {'pt': 'Antibióticos', 'es': 'Antibióticos'},
    route: 'VO / IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Pneumonia comunitária: 500 mg/dia VO por 3–5 dias. IV: 500 mg/dia. DSTs: dose única 1 g VO. Faringite: 500 mg no 1º dia, 250 mg por 4 dias.',
      'es': 'Neumonía comunitaria: 500 mg/día VO 3–5 días. IV: 500 mg/día. ETS: dosis única 1 g VO.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário em IRC leve a moderada. Cuidado em IRC grave (dados limitados).',
      'es': 'Sin ajuste en IRC leve a moderada. Precaución en IRC grave.',
    },
    elderlyAlert: {
      'pt': 'Prolongamento do QT — monitorar ECG se uso concomitante de outros QT-prolongadores, hipopotassemia ou bradicardia.',
      'es': 'Prolongación del QT — monitorizar ECG si uso concomitante de otros prolongadores de QT.',
    },
    mechanism: {
      'pt': 'Liga-se à subunidade 50S ribossomial → inibe síntese proteica bacteriana. Bacteriostático. Concentra intracelularmente (Legionella, Chlamydia, Mycoplasma).',
      'es': 'Se une a la subunidad 50S ribosomal → inhibe síntesis proteica bacteriana.',
    },
    warning: {
      'pt': 'Prolongamento do intervalo QT e torsades de pointes (especialmente com hipopotassemia ou outros QT-prolongadores). Interação com varfarina. Evitar na Miastenia gravis.',
      'es': 'Prolongación del QT y torsades de pointes. Interacción con warfarina. Evitar en Miastenia gravis.',
    },
    adverse: {
      'pt': ['Prolongamento QT', 'Náuseas/vômitos', 'Diarreia', 'Dor abdominal', 'Hepatotoxicidade (raro)'],
      'es': ['Prolongación QT', 'Náuseas/vómitos', 'Diarrea', 'Dolor abdominal', 'Hepatotoxicidad (raro)'],
    },
  ),

  DrugModel(
    id: 'ciprofloxacino',
    name: 'Ciprofloxacino',
    className: {'pt': 'Fluoroquinolona de 2ª geração', 'es': 'Fluoroquinolona de 2ª generación'},
    category: {'pt': 'Antibióticos', 'es': 'Antibióticos'},
    route: 'VO / IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'ITU simples: 250–500 mg VO 2×/dia por 3–7 dias. ITU complicada/pielonefrite: 500 mg VO ou 400 mg IV 2×/dia por 7–14 dias. Pneumonia nosocomial: 400 mg IV 2–3×/dia.',
      'es': 'ITU simple: 250–500 mg VO 2×/día por 3–7 días. ITU complicada: 500 mg VO o 400 mg IV 2×/día por 7–14 días.',
    },
    renalAlert: {
      'pt': 'ClCr 30–50: 250–500 mg a cada 12h. ClCr <30: 250–500 mg a cada 18–24h. HD: dose pós-sessão.',
      'es': 'ClCr 30–50: 250–500 mg cada 12 h. ClCr <30: 250–500 mg cada 18–24 h.',
    },
    elderlyAlert: {
      'pt': 'Risco de tendinite/ruptura do tendão de Aquiles (fluoroquinolonas). Risco de alucinações, confusão, prolongamento QT.',
      'es': 'Riesgo de tendinitis/rotura del tendón de Aquiles. Riesgo de alucinaciones, confusión, prolongación QT.',
    },
    mechanism: {
      'pt': 'Inibe DNA girase (topoisomerase II) e topoisomerase IV → impede replicação e reparo do DNA bacteriano. Bactericida concentração-dependente.',
      'es': 'Inhibe ADN girasa (topoisomerasa II) y topoisomerasa IV → impide replicación y reparación del ADN bacteriano.',
    },
    warning: {
      'pt': 'Tendinite/ruptura de tendão (especialmente Aquiles; risco com corticoides). QT longo. Artropatia em criança (evitar). Fotossensibilidade. Interação com antiácidos (quelação).',
      'es': 'Tendinitis/rotura de tendón (riesgo con corticoides). QT largo. Fotosensibilidad. Interacción con antiácidos.',
    },
    adverse: {
      'pt': ['Tendinite/ruptura de tendão', 'Prolongamento QT', 'Náuseas/diarreia', 'Fotossensibilidade', 'Confusão/alucinações'],
      'es': ['Tendinitis/rotura de tendón', 'Prolongación QT', 'Náuseas/diarrea', 'Fotosensibilidad', 'Confusión/alucinaciones'],
    },
  ),

  DrugModel(
    id: 'metronidazol',
    name: 'Metronidazol',
    className: {'pt': 'Nitroimidazol – antibiótico/antiprotozoário', 'es': 'Nitroimidazol – antibiótico/antiprotozoario'},
    category: {'pt': 'Antibióticos', 'es': 'Antibióticos'},
    route: 'VO / IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Anaeróbios/infecções abdominais: 500 mg IV a cada 8h ou VO 500 mg 3×/dia. C. difficile leve/moderada: 500 mg VO 3×/dia por 10–14 dias. Tricomoníase: 2 g dose única VO.',
      'es': 'Anaerobios/infecciones abdominales: 500 mg IV cada 8 h o VO 500 mg 3×/día. C. difficile: 500 mg VO 3×/día por 10–14 días.',
    },
    renalAlert: {
      'pt': 'Sem ajuste em IRC leve/moderada. HD: dose após sessão. Metabólitos acumulam em IRC grave — monitorar toxicidade neurológica.',
      'es': 'Sin ajuste en IRC leve/moderada. HD: dosis después de sesión.',
    },
    elderlyAlert: {
      'pt': 'Neuropatia periférica e encefalopatia com uso prolongado. Usar menor duração possível.',
      'es': 'Neuropatía periférica y encefalopatía con uso prolongado.',
    },
    mechanism: {
      'pt': 'Ativado em anaerobiose → quebra do DNA bacteriano/protozoário. Bactericida para anaeróbios, Trichomonas, Giardia, Entamoeba.',
      'es': 'Activado en anaerobiosis → ruptura del ADN bacteriano/protozoario.',
    },
    warning: {
      'pt': 'Reação tipo dissulfiram com álcool (náuseas, vômitos, flush). Evitar álcool durante e 48h após. Neuropatia periférica com uso prolongado. Potencialmente carcinogênico (uso crônico animal).',
      'es': 'Reacción tipo disulfiram con alcohol. Evitar alcohol durante y 48 h después. Neuropatía periférica con uso prolongado.',
    },
    adverse: {
      'pt': ['Náuseas', 'Sabor metálico', 'Neuropatia periférica', 'Encefalopatia (uso prolongado)', 'Reação ao álcool'],
      'es': ['Náuseas', 'Sabor metálico', 'Neuropatía periférica', 'Encefalopatía (uso prolongado)', 'Reacción al alcohol'],
    },
  ),

  // ─────────────────────────────────────────────
  //  CARDIOVASCULARES – VASOPRESSORES / INOTRÓPICOS
  // ─────────────────────────────────────────────
  DrugModel(
    id: 'noradrenalina',
    name: 'Noradrenalina / Norepinefrina',
    className: {'pt': 'Vasopressor – agonista α1 predominante', 'es': 'Vasopresor – agonista α1 predominante'},
    category: {'pt': 'Vasopressores', 'es': 'Vasopresores'},
    route: 'IV (bomba)',
    doseType: 'infusion',
    mcgKgMinStart: 0.05,
    mcgKgMinMax: 1.0,
    fixedDose: {
      'pt': 'Iniciar: 0,05–0,1 µg/kg/min IV. Titular a cada 2–5 min para PAM alvo ≥65 mmHg. Dose usual: 0,1–0,5 µg/kg/min. Dose máx. prática: ~1–2 µg/kg/min.',
      'es': 'Iniciar: 0,05–0,1 µg/kg/min IV. Titular cada 2–5 min para PAM objetivo ≥65 mmHg. Dosis usual: 0,1–0,5 µg/kg/min.',
    },
    renalAlert: {
      'pt': 'Doses altas podem agravar isquemia renal. Manter PAM ≥65 mmHg para perfusão renal. Monitorar creatinina e débito urinário.',
      'es': 'Dosis altas pueden agravar isquemia renal. Mantener PAM ≥65 mmHg. Monitorizar creatinina y diuresis.',
    },
    elderlyAlert: {
      'pt': 'Maior risco de isquemia periférica e arritmias. Titular cuidadosamente. Monitorar extremidades.',
      'es': 'Mayor riesgo de isquemia periférica y arritmias. Titular cuidadosamente.',
    },
    mechanism: {
      'pt': 'Agonista α1 (vasoconstricção periférica potente) e β1 (inotropia e cronotropia moderadas). Vasopressor de 1ª linha no choque séptico (SCCM/Surviving Sepsis Campaign).',
      'es': 'Agonista α1 (vasoconstricción periférica potente) y β1 (inotropía y cronotropía moderadas). Vasopresor de 1ª línea en choque séptico.',
    },
    warning: {
      'pt': 'Extravasação causa necrose tecidual (preferir acesso central). Antídoto extravasação: fentolamina local. Arritmias, hipertensão. Monitorar ECG.',
      'es': 'Extravasación causa necrosis tisular (preferir acceso central). Antídoto extravasación: fentolamina local.',
    },
    adverse: {
      'pt': ['Isquemia periférica', 'Arritmias', 'Hipertensão', 'Necrose tecidual (extravasação)', 'Bradicardia reflexa'],
      'es': ['Isquemia periférica', 'Arritmias', 'Hipertensión', 'Necrosis tisular (extravasación)', 'Bradicardia refleja'],
    },
  ),

  DrugModel(
    id: 'dobutamina',
    name: 'Dobutamina',
    className: {'pt': 'Inotrópico – agonista β1', 'es': 'Inotrópico – agonista β1'},
    category: {'pt': 'Inotrópicos', 'es': 'Inotrópicos'},
    route: 'IV (bomba)',
    doseType: 'infusion',
    mcgKgMinStart: 2.5,
    mcgKgMinMax: 20.0,
    fixedDose: {
      'pt': 'Iniciar: 2,5–5 µg/kg/min IV. Titular até 10–20 µg/kg/min conforme DC/PA. Máx. usual: 20–40 µg/kg/min.',
      'es': 'Iniciar: 2,5–5 µg/kg/min IV. Titular hasta 10–20 µg/kg/min. Máx. usual: 20–40 µg/kg/min.',
    },
    renalAlert: {
      'pt': 'Sem ajuste renal específico. Titular conforme hemodinâmica e débito cardíaco.',
      'es': 'Sin ajuste renal específico. Titular según hemodinámica y gasto cardíaco.',
    },
    elderlyAlert: {
      'pt': 'Alto risco de taquicardia, fibrilação atrial e isquemia miocárdica. Monitorar ECG continuamente.',
      'es': 'Alto riesgo de taquicardia, FA y isquemia miocárdica. Monitorizar ECG continuamente.',
    },
    mechanism: {
      'pt': 'Agonista β1 seletivo → aumenta contratilidade e débito cardíaco sem vasoconstricção significativa. Pode causar hipotensão por β2 vasodilatação.',
      'es': 'Agonista β1 selectivo → aumenta contractilidad y gasto cardíaco sin vasoconstricción significativa.',
    },
    warning: {
      'pt': 'Pode piorar hipotensão em choque com baixa PA (combinar com noradrenalina). Taquicardia, FA, isquemia. Tolerância após 72h de infusão contínua.',
      'es': 'Puede empeorar hipotensión en choque con PA baja (combinar con noradrenalina). Taquicardia, FA, isquemia.',
    },
    adverse: {
      'pt': ['Taquicardia', 'Fibrilação atrial', 'Isquemia miocárdica', 'Hipotensão', 'Extrassístoles'],
      'es': ['Taquicardia', 'Fibrilación auricular', 'Isquemia miocárdica', 'Hipotensión', 'Extrasístoles'],
    },
  ),

  DrugModel(
    id: 'adrenalina',
    name: 'Adrenalina / Epinefrina',
    className: {'pt': 'Catecolamina – agonista α e β', 'es': 'Catecolamina – agonista α y β'},
    category: {'pt': 'Vasopressores / Emergência', 'es': 'Vasopresores / Emergencia'},
    route: 'IV / IM / IO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Anafilaxia: 0,3–0,5 mg IM (coxa lateral). PCR: 1 mg IV/IO a cada 3–5 min. Choque séptico refratário: 0,01–0,5 µg/kg/min IV contínuo.',
      'es': 'Anafilaxia: 0,3–0,5 mg IM (muslo lateral). PCR: 1 mg IV/IO cada 3–5 min. Choque séptico refractario: 0,01–0,5 µg/kg/min IV continuo.',
    },
    renalAlert: {
      'pt': 'Sem ajuste específico para emergências agudas. Monitorar função renal durante infusão contínua.',
      'es': 'Sin ajuste específico para emergencias agudas. Monitorizar función renal durante infusión continua.',
    },
    elderlyAlert: {
      'pt': 'Risco aumentado de arritmias e isquemia miocárdica. Dose IM para anafilaxia permanece a mesma.',
      'es': 'Mayor riesgo de arritmias e isquemia miocárdica. Dosis IM para anafilaxia permanece igual.',
    },
    mechanism: {
      'pt': 'Agonismo α1 (vasoconstricção), β1 (inotrófico/cronotrópico), β2 (broncodilatação). Drug of choice em parada cardíaca e anafilaxia.',
      'es': 'Agonismo α1 (vasoconstricción), β1 (inotrópico/cronotrópico), β2 (broncodilatación).',
    },
    warning: {
      'pt': 'Anafilaxia: SEMPRE via IM na coxa (não IV a menos que parada). IV em PCR: acesso venoso central preferível. Arritmias, hipertensão grave, isquemia.',
      'es': 'Anafilaxia: SIEMPRE vía IM en muslo (no IV a menos que parada). Arritmias, hipertensión grave, isquemia.',
    },
    adverse: {
      'pt': ['Taquicardia/arritmias', 'Hipertensão', 'Ansiedade/tremor', 'Isquemia miocárdica', 'Hipopotassemia'],
      'es': ['Taquicardia/arritmias', 'Hipertensión', 'Ansiedad/tremor', 'Isquemia miocárdica', 'Hipopotasemia'],
    },
  ),

  DrugModel(
    id: 'vasopressina',
    name: 'Vasopressina',
    className: {'pt': 'Vasopressor – hormônio antidiurético análogo', 'es': 'Vasopresor – análogo de hormona antidiurética'},
    category: {'pt': 'Vasopressores', 'es': 'Vasopresores'},
    route: 'IV (bomba)',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Choque séptico (adjuvante): dose fixa 0,03–0,04 UI/min IV contínuo (NÃO titular; usar como economizador de noradrenalina).',
      'es': 'Choque séptico (adyuvante): dosis fija 0,03–0,04 UI/min IV continuo (NO titular; usar como ahorrador de noradrenalina).',
    },
    renalAlert: {
      'pt': 'Pode melhorar perfusão renal em choque. Monitorar Na+ sérico (risco de hiponatremia com altas doses prolongadas).',
      'es': 'Puede mejorar perfusión renal en choque. Monitorizar Na+ sérico.',
    },
    elderlyAlert: {
      'pt': 'Monitorar isquemia coronária, mesentérica e periférica. Maior risco em cardiopatas.',
      'es': 'Monitorizar isquemia coronaria, mesentérica y periférica. Mayor riesgo en cardiopatas.',
    },
    mechanism: {
      'pt': 'Liga-se a receptores V1 (vasoconstricção) e V2 (retenção de água). Não dependente de catecolaminas — útil em choque refratário a noradrenalina.',
      'es': 'Se une a receptores V1 (vasoconstricción) y V2 (retención de agua). No dependiente de catecolaminas.',
    },
    warning: {
      'pt': 'Isquemia digital, mesentérica e miocárdica em doses altas. Não usar como agente único de primeira linha. Hiponatremia com doses prolongadas.',
      'es': 'Isquemia digital, mesentérica y miocárdica en dosis altas. No usar como único agente de primera línea.',
    },
    adverse: {
      'pt': ['Isquemia coronária', 'Isquemia mesentérica', 'Isquemia digital', 'Hiponatremia', 'Bradicardia'],
      'es': ['Isquemia coronaria', 'Isquemia mesentérica', 'Isquemia digital', 'Hiponatremia', 'Bradicardia'],
    },
  ),

  // ─────────────────────────────────────────────
  //  CARDIOVASCULARES – DIURÉTICOS / ANTI-HAS
  // ─────────────────────────────────────────────
  DrugModel(
    id: 'furosemida',
    name: 'Furosemida',
    className: {'pt': 'Diurético de alça', 'es': 'Diurético de asa'},
    category: {'pt': 'Diuréticos', 'es': 'Diuréticos'},
    route: 'IV / VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Edema/IC: 20–40 mg IV initial. Titular até resposta diurética (duplicar se sem resposta em 2h). Infusão contínua: 10–40 mg/h. VO: 40–80 mg/dia.',
      'es': 'Edema/IC: 20–40 mg IV inicial. Titular hasta respuesta diurética (doblar si sin respuesta en 2 h). VO: 40–80 mg/día.',
    },
    renalAlert: {
      'pt': 'IRC: doses maiores necessárias (efeito reduzido). Monitorar K+, Mg2+, Na+, creatinina e diurese. Evitar hipovolemia.',
      'es': 'IRC: dosis mayores necesarias. Monitorizar K+, Mg2+, Na+, creatinina y diuresis.',
    },
    elderlyAlert: {
      'pt': 'Risco aumentado de hipotensão, hipovolemia, hiponatremia, hipopotassemia e quedas. Monitorar eletrólitos com frequência.',
      'es': 'Mayor riesgo de hipotensión, hipovolemia, hiponatremia, hipopotasemia y caídas.',
    },
    mechanism: {
      'pt': 'Inibe cotransportador NKCC2 no ramo ascendente espesso da alça de Henle → natriurese e diurese potentes. Efeito em 30 min (IV).',
      'es': 'Inhibe cotransportador NKCC2 en el asa de Henle → natriuresis y diuresis potentes. Efecto en 30 min (IV).',
    },
    warning: {
      'pt': 'Hipopotassemia pode precipitar arritmia (especialmente com digitálicos). Ototoxicidade com doses altas IV (evitar infusão >4 mg/min). Hiperglicemia, hiperuricemia.',
      'es': 'Hipopotasemia puede precipitar arritmia (especialmente con digitálicos). Ototoxicidad en dosis altas IV.',
    },
    adverse: {
      'pt': ['Hipopotassemia', 'Hiponatremia', 'Hipovolemia', 'Hipotensão', 'Ototoxicidade', 'Hiperuricemia'],
      'es': ['Hipopotasemia', 'Hiponatremia', 'Hipovolemia', 'Hipotensión', 'Ototoxicidad', 'Hiperuricemia'],
    },
  ),

  DrugModel(
    id: 'metoprolol',
    name: 'Metoprolol',
    className: {'pt': 'Betabloqueador β1 seletivo', 'es': 'Betabloqueador β1 selectivo'},
    category: {'pt': 'Cardiovasculares', 'es': 'Cardiovasculares'},
    route: 'VO / IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'HAS/Angina: 25–100 mg 2×/dia VO. IC estável (Succinate): 12,5–25 mg/dia, titular até 200 mg/dia. FA aguda: 5 mg IV a cada 5 min (máx. 15 mg); depois VO.',
      'es': 'HAS/Angina: 25–100 mg 2×/día VO. IC estable (Succinato): 12,5–25 mg/día, titular hasta 200 mg/día. FA aguda: 5 mg IV cada 5 min (máx. 15 mg).',
    },
    renalAlert: {
      'pt': 'Sem ajuste renal necessário (metabolismo hepático predominante).',
      'es': 'Sin ajuste renal necesario (metabolismo hepático predominante).',
    },
    elderlyAlert: {
      'pt': 'Bradicardia, hipotensão, fadiga, hipoglicemia mascarada. Reduzir dose inicial; titular lentamente.',
      'es': 'Bradicardia, hipotensión, fatiga, hipoglucemia enmascarada. Reducir dosis inicial; titular lentamente.',
    },
    mechanism: {
      'pt': 'Bloqueia receptores β1 cardíacos → reduz FC, PA e consumo de O2 miocárdico. Diminui mortalidade pós-IAM e na IC.',
      'es': 'Bloquea receptores β1 cardíacos → reduce FC, PA y consumo de O2 miocárdico.',
    },
    warning: {
      'pt': 'CONTRAINDICADO em choque cardiogênico, asma ativa grave, bloqueio AV 2º/3º grau sem marca-passo, bradicardia sintomática. NUNCA interromper abruptamente (pode precipitar IAM).',
      'es': 'CONTRAINDICADO en choque cardiogénico, asma activa grave, bloqueo AV 2°/3°, bradicardia sintomática. NUNCA interrumpir abruptamente.',
    },
    adverse: {
      'pt': ['Bradicardia', 'Hipotensão', 'Fadiga', 'Broncoespasmo', 'Mascaramento de hipoglicemia', 'Disfunção erétil'],
      'es': ['Bradicardia', 'Hipotensión', 'Fatiga', 'Broncoespasmo', 'Enmascaramiento de hipoglucemia', 'Disfunción eréctil'],
    },
  ),

  DrugModel(
    id: 'amiodarona',
    name: 'Amiodarona',
    className: {'pt': 'Antiarrítmico classe III', 'es': 'Antiarrítmico clase III'},
    category: {'pt': 'Antiarrítmicos', 'es': 'Antiarrítmicos'},
    route: 'IV / VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'PCR/FV-TV: 300 mg IV bolus; 2ª dose 150 mg se necessário. FA aguda: 150 mg IV em 10 min, depois 1 mg/min por 6h, 0,5 mg/min por 18h. VO manutenção: 100–200 mg/dia.',
      'es': 'PCR/FV-TV: 300 mg IV bolo; 2ª dosis 150 mg si necesario. FA aguda: 150 mg IV en 10 min, luego 1 mg/min 6 h, 0,5 mg/min 18 h.',
    },
    renalAlert: {
      'pt': 'Sem ajuste renal necessário (metabolismo hepático).',
      'es': 'Sin ajuste renal necesario (metabolismo hepático).',
    },
    elderlyAlert: {
      'pt': 'Bradicardia, hipotireoidismo, neurotoxicidade, pneumonite. Monitorar TSH, função pulmonar, hepática periodicamente.',
      'es': 'Bradicardia, hipotiroidismo, neurotoxicidad, neumonitis. Monitorizar TSH, función pulmonar y hepática periódicamente.',
    },
    mechanism: {
      'pt': 'Bloqueia canais de K+ (prolonga potencial de ação), Na+ e Ca2+; bloqueia receptores α e β-adrenérgicos.',
      'es': 'Bloquea canales de K+ (prolonga potencial de acción), Na+ y Ca2+; bloquea receptores α y β-adrenérgicos.',
    },
    warning: {
      'pt': 'Toxicidade pulmonar (pneumonite, fibrose – potencialmente fatal). Hipotireoidismo/hipertireoidismo. Hepatotoxicidade. Fotossensibilidade. Depósito corneal. Interações múltiplas (varfarina, digoxina, sinvastatina).',
      'es': 'Toxicidad pulmonar (neumonitis, fibrosis). Hipotiroidismo/hipertiroidismo. Hepatotoxicidad. Fotosensibilidad. Múltiples interacciones.',
    },
    adverse: {
      'pt': ['Pneumonite/fibrose pulmonar', 'Hipotireoidismo', 'Hipertireoidismo', 'Hepatotoxicidade', 'Fotossensibilidade', 'Bradiarritmias', 'Neuropatia periférica'],
      'es': ['Neumonitis/fibrosis pulmonar', 'Hipotiroidismo', 'Hipertiroidismo', 'Hepatotoxicidad', 'Fotosensibilidad', 'Bradiarritmias'],
    },
  ),

  DrugModel(
    id: 'heparina_nf',
    name: 'Heparina Não Fracionada (HNF)',
    className: {'pt': 'Anticoagulante – inibidor indireto da trombina/Xa', 'es': 'Anticoagulante – inhibidor indirecto de trombina/Xa'},
    category: {'pt': 'Anticoagulantes', 'es': 'Anticoagulantes'},
    route: 'IV / SC',
    doseType: 'weight',
    mgKg: 80,
    fixedDose: {
      'pt': 'SCA/TEP: bolus 60–80 UI/kg IV (máx. 5000 UI), manutenção 12–18 UI/kg/h. Ajustar pelo TTPA (60–100 s ou 1,5–2,5× controle). Profilaxia: 5000 UI SC a cada 8–12h.',
      'es': 'SCA/TEP: bolo 60–80 UI/kg IV (máx. 5000 UI), mantenimiento 12–18 UI/kg/h. Ajustar por TTPA (60–100 s).',
    },
    renalAlert: {
      'pt': 'Usar com cautela em DRC — maior risco de sangramento. Monitorar TTPA mais frequentemente. Pode usar, ajustar por TTPA.',
      'es': 'Usar con cautela en IRC — mayor riesgo de sangrado. Monitorizar TTPA con más frecuencia.',
    },
    elderlyAlert: {
      'pt': 'Risco aumentado de sangramento. Monitorar TTPA com rigor. Considerar heparina de baixo peso molecular com ajuste de dose.',
      'es': 'Mayor riesgo de sangrado. Monitorizar TTPA rigurosamente.',
    },
    mechanism: {
      'pt': 'Liga-se à antitrombina III → potencializa inibição de trombina (IIa), Xa e outros fatores de coagulação. Efeito rápido, reversível com protamina.',
      'es': 'Se une a antitrombina III → potencializa inhibición de trombina (IIa), Xa y otros factores. Efecto rápido, reversible con protamina.',
    },
    warning: {
      'pt': 'Sangramento (monitorar TTPA). Trombocitopenia induzida por heparina (TIH Tipo II – grave, risco de trombose paradoxal). Antídoto: sulfato de protamina (1 mg por 100 UI heparina). Testar plaquetas a cada 2–3 dias.',
      'es': 'Sangrado. Trombocitopenia inducida por heparina (TIH Tipo II). Antídoto: sulfato de protamina.',
    },
    adverse: {
      'pt': ['Sangramento', 'TIH (trombocitopenia)', 'Osteoporose (uso prolongado)', 'Hiperpotassemia', 'Reação no local de injeção'],
      'es': ['Sangrado', 'TIH (trombocitopenia)', 'Osteoporosis (uso prolongado)', 'Hiperpotasemia'],
    },
  ),

  DrugModel(
    id: 'enoxaparina',
    name: 'Enoxaparina (HBPM)',
    className: {'pt': 'Heparina de Baixo Peso Molecular – anticoagulante', 'es': 'Heparina de Bajo Peso Molecular – anticoagulante'},
    category: {'pt': 'Anticoagulantes', 'es': 'Anticoagulantes'},
    route: 'SC',
    doseType: 'weight',
    mgKg: 1,
    fixedDose: {
      'pt': 'SCA/TEP tratamento: 1 mg/kg SC a cada 12h ou 1,5 mg/kg/dia. Profilaxia: 40 mg SC/dia (ou 30 mg 2×/dia em alto risco). Ajustar anti-Xa em obesidade/IRC.',
      'es': 'SCA/TEP tratamiento: 1 mg/kg SC cada 12 h o 1,5 mg/kg/día. Profilaxis: 40 mg SC/día.',
    },
    renalAlert: {
      'pt': 'ClCr <30 mL/min: 1 mg/kg SC 1×/dia (tratamento) ou 30 mg SC/dia (profilaxia). Monitorar níveis anti-Xa. EVITAR em DRC muito grave.',
      'es': 'ClCr <30 mL/min: 1 mg/kg SC 1×/día (tratamiento) o 30 mg SC/día (profilaxis). Monitorizar anti-Xa.',
    },
    elderlyAlert: {
      'pt': '>75 anos sem ClCr ajustado: reduzir dose em 25%. Monitorar anti-Xa. Risco aumentado de sangramento.',
      'es': '>75 años sin ClCr ajustado: reducir dosis 25%. Monitorizar anti-Xa. Mayor riesgo de sangrado.',
    },
    mechanism: {
      'pt': 'Inibe preferencialmente o fator Xa (proporção anti-Xa:anti-IIa = 3,3:1). Mais previsível que HNF; sem monitoração rotineira do TTPA em casos padrão.',
      'es': 'Inhibe preferentemente el factor Xa. Más predecible que HNF; sin monitorización rutinaria del TTPA.',
    },
    warning: {
      'pt': 'Sangramento (monitorar em risco alto). TIH menos frequente que HNF mas possível. Antídoto parcial: protamina (1 mg por 1 mg enoxaparina; neutraliza ~60%).',
      'es': 'Sangrado. TIH menos frecuente que HNF pero posible. Antídoto parcial: protamina.',
    },
    adverse: {
      'pt': ['Sangramento', 'TIH (menos frequente)', 'Hematoma no local', 'Osteoporose (uso prolongado)', 'Hiperpotassemia'],
      'es': ['Sangrado', 'TIH (menos frecuente)', 'Hematoma local', 'Osteoporosis (uso prolongado)', 'Hiperpotasemia'],
    },
  ),

  DrugModel(
    id: 'enalapril',
    name: 'Enalapril',
    className: {'pt': 'IECA – Inibidor da Enzima Conversora de Angiotensina', 'es': 'IECA – Inhibidor de la Enzima Convertidora de Angiotensina'},
    category: {'pt': 'Anti-hipertensivos', 'es': 'Antihipertensivos'},
    route: 'VO / IV (enalaprilato)',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'HAS: 5–10 mg 1–2×/dia (início 2,5 mg). Máx. 40 mg/dia. IC: 2,5 mg 2×/dia, titular até 10 mg 2×/dia. IV (enalaprilato): 0,625–1,25 mg a cada 6h.',
      'es': 'HAS: 5–10 mg 1–2×/día (inicio 2,5 mg). Máx. 40 mg/día. IC: 2,5 mg 2×/día, titular hasta 10 mg 2×/día.',
    },
    renalAlert: {
      'pt': 'ClCr 30–80: 2,5–5 mg/dia. ClCr <30: 2,5 mg/dia. Hemodiálise: 2,5 mg no dia da diálise. Monitorar Cr e K+ em 1–2 semanas.',
      'es': 'ClCr 30–80: 2,5–5 mg/día. ClCr <30: 2,5 mg/día. Monitorizar Cr y K+ a 1–2 semanas.',
    },
    elderlyAlert: {
      'pt': 'Iniciar com 2,5 mg. Risco de hipotensão de primeira dose, hiperpotassemia, IRA funcional.',
      'es': 'Iniciar con 2,5 mg. Riesgo de hipotensión de primera dosis, hiperpotasemia, IRA funcional.',
    },
    mechanism: {
      'pt': 'Inibe ECA → reduz angiotensina II (vasoconstricção) e aldosterona → vasodilatação e natriurese. Pró-fármaco convertido em enalaprilato.',
      'es': 'Inhibe ECA → reduce angiotensina II (vasoconstricción) y aldosterona → vasodilatación y natriuresis.',
    },
    warning: {
      'pt': 'Angioedema (suspender permanentemente se ocorrer). Tosse seca (efeito de classe por bradicinina – trocar por ARA2). Hiperpotassemia (monitorar K+). CONTRAINDICADO na gravidez (II–III trim.) e com alisquireno em DM.',
      'es': 'Angioedema (suspender permanentemente). Tos seca. Hiperpotasemia. CONTRAINDICADO en embarazo y con aliskirén en DM.',
    },
    adverse: {
      'pt': ['Tosse seca', 'Hipotensão (1ª dose)', 'Hiperpotassemia', 'IRA funcional', 'Angioedema', 'Tontura'],
      'es': ['Tos seca', 'Hipotensión (1ª dosis)', 'Hiperpotasemia', 'IRA funcional', 'Angioedema', 'Mareo'],
    },
  ),

  DrugModel(
    id: 'nitroglicerina',
    name: 'Nitroglicerina / Nitrato',
    className: {'pt': 'Nitrato – vasodilatador', 'es': 'Nitrato – vasodilatador'},
    category: {'pt': 'Anti-anginosos / Cardiovasculares', 'es': 'Antianginosos / Cardiovasculares'},
    route: 'SL / IV / VO / Patch',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Angina aguda: 0,4 mg SL a cada 5 min (máx. 3 doses). IV: iniciar 5–10 µg/min, titular até alívio (máx. 200–400 µg/min). VO: 20–40 mg 2–3×/dia (ISDN).',
      'es': 'Angina aguda: 0,4 mg SL cada 5 min (máx. 3 dosis). IV: iniciar 5–10 µg/min, titular hasta alivio.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário em insuficiência renal.',
      'es': 'Sin ajuste necesario en insuficiencia renal.',
    },
    elderlyAlert: {
      'pt': 'Risco aumentado de hipotensão ortostática e síncope. Monitorar PA a cada dose.',
      'es': 'Mayor riesgo de hipotensión ortostática y síncope. Monitorizar PA con cada dosis.',
    },
    mechanism: {
      'pt': 'Libera óxido nítrico (NO) → ativa guanilil ciclase → GMPc → relaxamento do músculo liso vascular. Venodilatação (↓ pré-carga) > arteriodilatação.',
      'es': 'Libera óxido nítrico (NO) → activa guanil-ciclasa → GMPc → relajación del músculo liso vascular.',
    },
    warning: {
      'pt': 'CONTRAINDICADO com inibidores de PDE5 (sildenafil/tadalafil – hipotensão grave). Evitar em IAM de ventrículo direito e hipovolemia. Tolerância com uso contínuo (janela sem nitrato).',
      'es': 'CONTRAINDICADO con inhibidores de PDE5 (sildenafilo/tadalafilo). Evitar en IAM de VD e hipovolemia.',
    },
    adverse: {
      'pt': ['Cefaleia pulsátil', 'Hipotensão', 'Taquicardia reflexa', 'Tontura', 'Síncope', 'Metahemoglobinemia (altas doses IV)'],
      'es': ['Cefalea pulsátil', 'Hipotensión', 'Taquicardia refleja', 'Mareo', 'Síncope', 'Metahemoglobinemia (dosis altas IV)'],
    },
  ),

  // ─────────────────────────────────────────────
  //  RESPIRATÓRIOS
  // ─────────────────────────────────────────────
  DrugModel(
    id: 'salbutamol',
    name: 'Salbutamol / Albuterol',
    className: {'pt': 'β2-agonista de curta ação (SABA)', 'es': 'β2-agonista de acción corta (SABA)'},
    category: {'pt': 'Broncodilatadores', 'es': 'Broncodilatadores'},
    route: 'Inalatório / Nebulização / IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Broncoespasmo agudo (MDI): 2–4 jatos a cada 20 min por 1h; depois a cada 1–4h. Nebulização: 2,5–5 mg a cada 20 min (3 doses), depois a cada 1–4h. IV (asma grave): 5 µg/min, titular até 20 µg/min.',
      'es': 'Broncoespasmo agudo (MDI): 2–4 puffs cada 20 min por 1 h; luego cada 1–4 h. Nebulización: 2,5–5 mg cada 20 min.',
    },
    renalAlert: {
      'pt': 'Sem ajuste renal necessário para vias inalatórias.',
      'es': 'Sin ajuste renal necesario para vías inhalatorias.',
    },
    elderlyAlert: {
      'pt': 'Taquicardia, tremor, hipopotassemia. Monitorar ECG e K+ em uso intensivo.',
      'es': 'Taquicardia, tremor, hipopotasemia. Monitorizar ECG y K+ en uso intensivo.',
    },
    mechanism: {
      'pt': 'Agonista β2 seletivo → ativa adenilil ciclase → AMPc → broncodilatação. Início de ação: 5 min. Duração: 4–6h.',
      'es': 'Agonista β2 selectivo → activa adenilil-ciclasa → AMPc → broncodilatación. Inicio: 5 min. Duración: 4–6 h.',
    },
    warning: {
      'pt': 'Hipopotassemia (especialmente com corticoides e doses altas). Taquicardia, arritmias. Tremor. Paradoxal broncoespasmo (raro).',
      'es': 'Hipopotasemia (especialmente con corticoides y dosis altas). Taquicardia, arritmias. Broncoespasmo paradójico (raro).',
    },
    adverse: {
      'pt': ['Taquicardia', 'Tremor', 'Hipopotassemia', 'Cefaleia', 'Náuseas', 'Broncoespasmo paradoxal (raro)'],
      'es': ['Taquicardia', 'Tremor', 'Hipopotasemia', 'Cefalea', 'Náuseas', 'Broncoespasmo paradójico (raro)'],
    },
  ),

  DrugModel(
    id: 'dexametasona',
    name: 'Dexametasona',
    className: {'pt': 'Corticosteroide – glicocorticoide potente', 'es': 'Corticosteroide – glucocorticoide potente'},
    category: {'pt': 'Corticosteroides', 'es': 'Corticosteroides'},
    route: 'IV / IM / VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Edema cerebral: 10 mg IV ataque, 4–6 mg a cada 6h. Croup: 0,6 mg/kg VO/IM dose única (máx. 10 mg). COVID-19: 6 mg/dia VO/IV por 10 dias. Antieméticas: 4–8 mg IV.',
      'es': 'Edema cerebral: 10 mg IV ataque, 4–6 mg cada 6 h. Croup: 0,6 mg/kg VO/IM dosis única. COVID-19: 6 mg/día VO/IV por 10 días.',
    },
    renalAlert: {
      'pt': 'Sem ajuste renal necessário. Monitorar glicemia e PA.',
      'es': 'Sin ajuste renal necesario. Monitorizar glucemia y PA.',
    },
    elderlyAlert: {
      'pt': 'Risco de hiperglicemia, hipertensão, confusão, fragilidade óssea, imunossupressão, úlcera GI. Usar menor dose e duração necessárias.',
      'es': 'Riesgo de hiperglucemia, hipertensión, confusión, fragilidad ósea, inmunosupresión, úlcera GI.',
    },
    mechanism: {
      'pt': 'Liga-se a receptores glicocorticoides → inibe NF-κB, reduz síntese de citocinas inflamatórias, estabiliza membranas, suprime imunidade celular e humoral.',
      'es': 'Se une a receptores glucocorticoides → inhibe NF-κB, reduce síntesis de citocinas inflamatorias.',
    },
    warning: {
      'pt': 'Imunossupressão (reativar TB/infecções fúngicas). Hiperglicemia. Osteoporose com uso prolongado. Insuficiência adrenal após retirada abrupta (retirar gradualmente se >2 semanas). Mascaramento de sinais de infecção.',
      'es': 'Inmunosupresión (reactivar TB/infecciones fúngicas). Hiperglucemia. Osteoporosis con uso prolongado.',
    },
    adverse: {
      'pt': ['Hiperglicemia', 'Imunossupressão', 'Osteoporose', 'Hipertensão', 'Miopatia', 'Insuficiência adrenal (retirada)'],
      'es': ['Hiperglucemia', 'Inmunosupresión', 'Osteoporosis', 'Hipertensión', 'Miopatía', 'Insuficiencia adrenal (retirada)'],
    },
  ),

  DrugModel(
    id: 'metilprednisolona',
    name: 'Metilprednisolona',
    className: {'pt': 'Corticosteroide – glicocorticoide de potência intermediária', 'es': 'Corticosteroide – glucocorticoide de potencia intermedia'},
    category: {'pt': 'Corticosteroides', 'es': 'Corticosteroides'},
    route: 'IV / IM / VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Asma grave/DPOC exacerbado: 40–125 mg IV a cada 6–24h ou 1–2 mg/kg/dia. Pulse terapia (LES/vasculite): 1 g IV/dia por 3 dias. Crise miastênica: 1–2 mg/kg/dia.',
      'es': 'Asma grave/EPOC exacerbado: 40–125 mg IV cada 6–24 h. Pulso (LES/vasculitis): 1 g IV/día por 3 días.',
    },
    renalAlert: {
      'pt': 'Sem ajuste renal específico. Monitorar glicemia e PA.',
      'es': 'Sin ajuste renal específico. Monitorizar glucemia y PA.',
    },
    elderlyAlert: {
      'pt': 'Mesmo perfil de risco da dexametasona. Especialmente risco de miopatia, fratura, delirium.',
      'es': 'Mismo perfil de riesgo que dexametasona. Especialmente riesgo de miopatía, fractura, delirium.',
    },
    mechanism: {
      'pt': 'Glicocorticoide sintético com potência 5× prednisolona. Efeito anti-inflamatório e imunossupressor via inibição de citocinas e NF-κB.',
      'es': 'Glucocorticoide sintético con potencia 5× prednisolona. Efecto antiinflamatorio e inmunosupresor.',
    },
    warning: {
      'pt': 'Mesmo perfil que dexametasona. Mínima atividade mineralocorticoide. Em pulse therapy: monitorar PA, glicemia, K+ e risco de aritmias.',
      'es': 'Mismo perfil que dexametasona. En pulso: monitorizar PA, glucemia, K+ y riesgo de arritmias.',
    },
    adverse: {
      'pt': ['Hiperglicemia', 'Imunossupressão', 'Hipertensão', 'Miopatia', 'Osteoporose', 'Úlcera GI'],
      'es': ['Hiperglucemia', 'Inmunosupresión', 'Hipertensión', 'Miopatía', 'Osteoporosis', 'Úlcera GI'],
    },
  ),

  // ─────────────────────────────────────────────
  //  NEUROLÓGICOS / SEDAÇÃO / ANTICONVULSIVANTES
  // ─────────────────────────────────────────────
  DrugModel(
    id: 'midazolam',
    name: 'Midazolam',
    className: {'pt': 'Benzodiazepínico – sedativo/ansiolítico de ação curta', 'es': 'Benzodiazepínico – sedante/ansiolítico de acción corta'},
    category: {'pt': 'Sedativos / Ansiolíticos', 'es': 'Sedantes / Ansiolíticos'},
    route: 'IV / IM / IN / Bucal',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Status epilepticus: 0,1–0,15 mg/kg IV ou 10 mg IM (adulto). Sedação procedimento: 0,05–0,1 mg/kg IV (titular). Infusão UTI: 0,02–0,1 mg/kg/h.',
      'es': 'Status epiléptico: 0,1–0,15 mg/kg IV o 10 mg IM (adulto). Sedación procedimiento: 0,05–0,1 mg/kg IV (titular).',
    },
    renalAlert: {
      'pt': 'Metabólito ativo acumula em IRC. Reduzir dose e monitorar sedação excessiva.',
      'es': 'Metabolito activo se acumula en IRC. Reducir dosis y monitorizar sedación excesiva.',
    },
    elderlyAlert: {
      'pt': 'Iniciar com 25–50% da dose adulto. Risco de depressão respiratória, hipotensão, delirium, quedas.',
      'es': 'Iniciar con 25–50% de la dosis adulta. Riesgo de depresión respiratoria, hipotensión, delirium, caídas.',
    },
    mechanism: {
      'pt': 'Potencializa GABA-A → hiperpolarização neuronal → sedação, amnésia, ansiolítica, anticonvulsivante, relaxamento muscular.',
      'es': 'Potencializa GABA-A → hiperpolarización neuronal → sedación, amnesia, ansiolítica, anticonvulsivante.',
    },
    warning: {
      'pt': 'Depressão respiratória (especialmente com opioides – BLACK BOX). Antídoto: flumazenil (0,2 mg IV, repetir até 1 mg). Amnésia paradoxal. Dependência física.',
      'es': 'Depresión respiratoria (especialmente con opioides – BLACK BOX). Antídoto: flumazenil.',
    },
    adverse: {
      'pt': ['Depressão respiratória', 'Hipotensão', 'Amnésia anterógrada', 'Sedação excessiva', 'Delirium (idoso)'],
      'es': ['Depresión respiratoria', 'Hipotensión', 'Amnesia anterógrada', 'Sedación excesiva', 'Delirium (anciano)'],
    },
  ),

  DrugModel(
    id: 'diazepam',
    name: 'Diazepam',
    className: {'pt': 'Benzodiazepínico – sedativo/anticonvulsivante de longa ação', 'es': 'Benzodiazepínico – sedante/anticonvulsivante de larga acción'},
    category: {'pt': 'Sedativos / Anticonvulsivantes', 'es': 'Sedantes / Anticonvulsivantes'},
    route: 'IV / VO / Retal',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Status epilepticus: 5–10 mg IV (0,1–0,3 mg/kg) lento; repetir a cada 5–10 min (máx. 30 mg). Ansiedade/espasmo: 2–10 mg VO 2–4×/dia.',
      'es': 'Status epiléptico: 5–10 mg IV (0,1–0,3 mg/kg) lento; repetir cada 5–10 min (máx. 30 mg).',
    },
    renalAlert: {
      'pt': 'Sem ajuste específico, mas metabólitos ativos acumulam em IRC grave. Monitorar sedação.',
      'es': 'Sin ajuste específico, pero metabolitos activos se acumulan en IRC grave.',
    },
    elderlyAlert: {
      'pt': 'Meia-vida muito prolongada em idosos (36–200h). Alto risco: quedas, confusão, sedação prolongada. Constante na lista Beers.',
      'es': 'Vida media muy prolongada en ancianos (36–200 h). Alto riesgo: caídas, confusión, sedación prolongada.',
    },
    mechanism: {
      'pt': 'Mesmo mecanismo que midazolam. Meia-vida de 24–48h + metabólitos ativos até 200h → sedação prolongada.',
      'es': 'Mismo mecanismo que midazolam. Vida media 24–48 h + metabolitos activos hasta 200 h.',
    },
    warning: {
      'pt': 'Mesmo perfil do midazolam. Lista Beers: EVITAR em idosos. Dependência física grave. Retirada brusca = convulsões/delirium tremens.',
      'es': 'Lista Beers: EVITAR en ancianos. Dependencia física grave. Retirada brusca = convulsiones/delirium tremens.',
    },
    adverse: {
      'pt': ['Sedação prolongada', 'Dependência', 'Depressão respiratória', 'Amnésia', 'Ataxia', 'Delirium (idoso)'],
      'es': ['Sedación prolongada', 'Dependencia', 'Depresión respiratoria', 'Amnesia', 'Ataxia', 'Delirium (anciano)'],
    },
  ),

  DrugModel(
    id: 'fenitoina',
    name: 'Fenitoína / Phenytoin',
    className: {'pt': 'Anticonvulsivante – bloqueador de canal de Na+', 'es': 'Anticonvulsivante – bloqueador de canal de Na+'},
    category: {'pt': 'Anticonvulsivantes', 'es': 'Anticonvulsivantes'},
    route: 'IV / VO',
    doseType: 'weight',
    mgKg: 20,
    fixedDose: {
      'pt': 'Status epilepticus: 20 mg/kg IV (máx. 1500 mg) lentamente (<50 mg/min) com monitoração ECG/PA. Manutenção: 4–7 mg/kg/dia VO dividido.',
      'es': 'Status epiléptico: 20 mg/kg IV (máx. 1500 mg) lentamente (<50 mg/min) con monitoreo ECG/PA. Mantenimiento: 4–7 mg/kg/día VO.',
    },
    renalAlert: {
      'pt': 'Fenitoína ligada a proteínas — em DRC grave, albumina baixa ou uremia: verificar fenitoína livre. Nível terapêutico total: 10–20 µg/mL; livre: 1–2 µg/mL.',
      'es': 'Unida a proteínas — en IRC grave, albúmina baja o uremia: verificar fenitoína libre. Nivel terapéutico total: 10–20 µg/mL.',
    },
    elderlyAlert: {
      'pt': 'Toxicidade com níveis normais por hipoalbuminemia. Monitorar nível livre. Ataxia, nistagmo, encefalopatia.',
      'es': 'Toxicidad con niveles normales por hipoalbuminemia. Monitorizar nivel libre.',
    },
    mechanism: {
      'pt': 'Bloqueia canais de Na+ voltagem-dependentes (estado inativado) → reduz disparo neuronal repetitivo de alta frequência.',
      'es': 'Bloquea canales de Na+ voltaje-dependientes (estado inactivado) → reduce disparo neuronal repetitivo.',
    },
    warning: {
      'pt': 'Infusão IV rápida → bradiarritmia, hipotensão, PCR. Purple Glove Syndrome (extravasação). Múltiplas interações medicamentosas (induz CYP). Teratogênico. Monitorar nível sérico.',
      'es': 'Infusión IV rápida → bradiarritmia, hipotensión, PCR. Múltiples interacciones (induce CYP). Teratogénico.',
    },
    adverse: {
      'pt': ['Nistagmo/ataxia (toxicidade)', 'Hipotensão (IV rápido)', 'Bradiarritmias', 'Purple Glove Syndrome', 'Hiperplasia gengival', 'Hepatotoxicidade'],
      'es': ['Nistagmo/ataxia (toxicidad)', 'Hipotensión (IV rápido)', 'Bradiarritmias', 'Hiperplasia gingival', 'Hepatotoxicidad'],
    },
  ),

  DrugModel(
    id: 'levetiracetam',
    name: 'Levetiracetam',
    className: {'pt': 'Anticonvulsivante – modula SV2A', 'es': 'Anticonvulsivante – modula SV2A'},
    category: {'pt': 'Anticonvulsivantes', 'es': 'Anticonvulsivantes'},
    route: 'IV / VO',
    doseType: 'weight',
    mgKg: 60,
    fixedDose: {
      'pt': 'Status epilepticus: 60 mg/kg IV (máx. 4500 mg) em 15 min. Manutenção epilepsia: 500 mg 2×/dia, titular até 1500–3000 mg/dia.',
      'es': 'Status epiléptico: 60 mg/kg IV (máx. 4500 mg) en 15 min. Mantenimiento epilepsia: 500 mg 2×/día, titular hasta 1500–3000 mg/día.',
    },
    renalAlert: {
      'pt': 'ClCr 50–80: máx. 1500 mg 2×/dia. ClCr 30–50: 750 mg 2×/dia. ClCr <30: 500 mg 2×/dia. HD: 500–1000 mg pós-sessão.',
      'es': 'ClCr 50–80: máx. 1500 mg 2×/día. ClCr 30–50: 750 mg 2×/día. ClCr <30: 500 mg 2×/día.',
    },
    elderlyAlert: {
      'pt': 'Ajustar por ClCr. Risco de agitação, agressividade (irritabilidade), confusão, depressão.',
      'es': 'Ajustar por ClCr. Riesgo de agitación, agresividad, confusión, depresión.',
    },
    mechanism: {
      'pt': 'Liga-se à proteína SV2A das vesículas sinápticas → modula liberação de neurotransmissores. Sem efeito sobre canais de Na+/Ca2+ ou GABA clássico.',
      'es': 'Se une a proteína SV2A de vesículas sinápticas → modula liberación de neurotransmisores.',
    },
    warning: {
      'pt': 'Comportamento (agitação, agressividade, psicose – "Keppra rage"). Ajuste renal obrigatório. Menos interações que fenitoína/carbamazepina. Seguro em gravidez (relativo).',
      'es': 'Comportamiento (agitación, agresividad, psicosis – "Keppra rage"). Ajuste renal obligatorio.',
    },
    adverse: {
      'pt': ['Sonolência', 'Tontura', 'Agitação/agressividade', 'Cefaleia', 'Infecção (raro)', 'Leucopenia (raro)'],
      'es': ['Somnolencia', 'Mareo', 'Agitación/agresividad', 'Cefalea', 'Leucopenia (raro)'],
    },
  ),

  // ─────────────────────────────────────────────
  //  GASTROINTESTINAIS / METABÓLICOS
  // ─────────────────────────────────────────────
  DrugModel(
    id: 'omeprazol',
    name: 'Omeprazol / Pantoprazol',
    className: {'pt': 'Inibidor da Bomba de Prótons (IBP)', 'es': 'Inhibidor de la Bomba de Protones (IBP)'},
    category: {'pt': 'Gastrintestinais', 'es': 'Gastrointestinales'},
    route: 'VO / IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'DRGE/úlcera: 20–40 mg/dia VO. Hemorragia digestiva alta: bolus 80 mg IV, depois infusão 8 mg/h por 72h. Erradicação H. pylori: 20 mg 2×/dia + antibióticos.',
      'es': 'ERGE/úlcera: 20–40 mg/día VO. Hemorragia digestiva alta: bolo 80 mg IV, luego infusión 8 mg/h por 72 h.',
    },
    renalAlert: {
      'pt': 'Sem ajuste renal necessário.',
      'es': 'Sin ajuste renal necesario.',
    },
    elderlyAlert: {
      'pt': 'Uso prolongado aumenta risco de deficiência de Mg2+, B12, Ca2+, fratura de quadril e infecção por C. difficile/pneumonia. Usar menor dose e duração indicada.',
      'es': 'Uso prolongado aumenta riesgo de déficit de Mg2+, B12, Ca2+, fractura de cadera e infección por C. difficile.',
    },
    mechanism: {
      'pt': 'Inibe irreversivelmente H+/K+-ATPase da célula parietal → supressão potente e prolongada de ácido gástrico. Pró-fármaco ativado em ambiente ácido.',
      'es': 'Inhibe irreversiblemente H+/K+-ATPasa de la célula parietal → supresión potente y prolongada de ácido gástrico.',
    },
    warning: {
      'pt': 'Evitar uso prolongado sem indicação (aumenta C. difficile, fratura, pneumonia, deficiências). Hipomagnesemia grave (monitorar Mg2+ com uso crônico). Interação com clopidogrel (omeprazol inibe CYP2C19 – usar pantoprazol).',
      'es': 'Evitar uso prolongado sin indicación. Hipomagnesemia grave. Interacción con clopidogrel (usar pantoprazol).',
    },
    adverse: {
      'pt': ['Hipomagnesemia', 'Déficit de B12/Ca2+', 'Nefrite intersticial', 'C. difficile', 'Cefaleia', 'Diarreia'],
      'es': ['Hipomagnesemia', 'Déficit de B12/Ca2+', 'Nefritis intersticial', 'C. difficile', 'Cefalea', 'Diarrea'],
    },
  ),

  DrugModel(
    id: 'insulina_regular',
    name: 'Insulina Regular (Humana)',
    className: {'pt': 'Insulina de ação curta – hipoglicemiante', 'es': 'Insulina de acción corta – hipoglucemiante'},
    category: {'pt': 'Endócrinos / Metabólicos', 'es': 'Endócrinos / Metabólicos'},
    route: 'IV / SC / IM',
    doseType: 'weight',
    mgKg: 0.1,
    fixedDose: {
      'pt': 'CAD: 0,1 UI/kg/h IV contínuo (após bolus opcional 0,1 UI/kg). Hiperpotassemia aguda: 10 UI IV bolus + glicose 50% 50 mL. Hiperglicemia hospitalar: conforme protocolo e glicemia capilar.',
      'es': 'CAD: 0,1 UI/kg/h IV continuo. Hiperpotasemia aguda: 10 UI IV bolo + glucosa 50% 50 mL. Hiperglucemia hospitalaria: según protocolo.',
    },
    renalAlert: {
      'pt': 'IRC acumula insulina endógena e reduz clearance → risco de hipoglicemia. Reduzir dose e aumentar monitoração de glicemia.',
      'es': 'IRC acumula insulina → riesgo de hipoglucemia. Reducir dosis y aumentar monitorización de glucemia.',
    },
    elderlyAlert: {
      'pt': 'Alto risco de hipoglicemia. Alvos menos estritos (150–200 mg/dL). Monitorar glicemia frequentemente.',
      'es': 'Alto riesgo de hipoglucemia. Objetivos menos estrictos (150–200 mg/dL). Monitorizar glucemia frecuentemente.',
    },
    mechanism: {
      'pt': 'Liga-se ao receptor de insulina → ativa GLUT4 → captação de glicose, síntese de glicogênio, inibição de gliconeogênese e lipólise.',
      'es': 'Se une al receptor de insulina → activa GLUT4 → captación de glucosa, síntesis de glucógeno, inhibición de gluconeogénesis.',
    },
    warning: {
      'pt': 'Hipoglicemia (sintomas: tremor, sudorese, confusão, coma). Tratar: glicose 50% IV 50 mL (hipoglicemia grave) ou glicose VO (leve). Monitorar glicemia a cada 1–2h em infusão IV.',
      'es': 'Hipoglucemia (síntomas: tremor, sudoración, confusión, coma). Tratar: glucosa 50% IV 50 mL.',
    },
    adverse: {
      'pt': ['Hipoglicemia', 'Hipopotassemia', 'Ganho de peso', 'Lipodistrofia no local', 'Edema'],
      'es': ['Hipoglucemia', 'Hipopotasemia', 'Ganancia de peso', 'Lipodistrofia local', 'Edema'],
    },
  ),

  DrugModel(
    id: 'bicarbonato_sodio',
    name: 'Bicarbonato de Sódio',
    className: {'pt': 'Tampão alcalinizante sistêmico', 'es': 'Tampón alcalinizante sistémico'},
    category: {'pt': 'Eletrólitos / Equilíbrio Ácido-Base', 'es': 'Electrolitos / Equilibrio Ácido-Base'},
    route: 'IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'PCR (acidose grave): 1 mEq/kg IV bolus. Acidose metabólica grave: repor déficit (dose = peso × 0,3 × [BE negativo]). Hiperpotassemia com alteração de ECG: 50 mEq IV + outras medidas.',
      'es': 'PCR (acidosis grave): 1 mEq/kg IV bolo. Acidosis metabólica grave: reponer déficit (dosis = peso × 0,3 × [EB negativo]).',
    },
    renalAlert: {
      'pt': 'Usar com cuidado em IRC (risco de sobrecarga de Na+, alcalose metabólica, hipocalcemia ionizada, edema).',
      'es': 'Usar con cuidado en IRC (riesgo de sobrecarga de Na+, alcalosis metabólica, hipocalcemia ionizada, edema).',
    },
    elderlyAlert: {
      'pt': 'Risco de sobrecarga de volume (Na+ 1 mEq/mL). Usar com cautela em ICC.',
      'es': 'Riesgo de sobrecarga de volumen (Na+ 1 mEq/mL). Usar con cautela en ICC.',
    },
    mechanism: {
      'pt': 'Tampona H+ pelo sistema bicarbonato-CO2 → corrige acidose metabólica. Efeito imediato mas CO2 produzido precisa ser eliminado por ventilação.',
      'es': 'Tamponea H+ por el sistema bicarbonato-CO2 → corrige acidosis metabólica.',
    },
    warning: {
      'pt': 'NÃO usar rotineiramente em PCR (sem evidência de benefício exceto acidose grave documentada). Alcalose metabólica iatrogênica. Hipocalcemia ionizada (aguda). Incompatível com adrenalina (não misturar no mesmo acesso).',
      'es': 'NO usar rutinariamente en PCR. Alcalosis metabólica iatrogénica. Hipocalcemia ionizada (aguda).',
    },
    adverse: {
      'pt': ['Alcalose metabólica', 'Hipocalcemia ionizada', 'Hipopotassemia', 'Hipernatremia', 'Sobrecarga hídrica'],
      'es': ['Alcalosis metabólica', 'Hipocalcemia ionizada', 'Hipopotasemia', 'Hipernatremia', 'Sobrecarga hídrica'],
    },
  ),

  DrugModel(
    id: 'cloreto_potassio',
    name: 'Cloreto de Potássio (KCl)',
    className: {'pt': 'Eletrólito – reposição de potássio', 'es': 'Electrolito – reposición de potasio'},
    category: {'pt': 'Eletrólitos', 'es': 'Electrolitos'},
    route: 'IV / VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'K+ 3,0–3,5: 40 mEq VO ou IV. K+ 2,5–3,0: 40–80 mEq IV lento. K+ <2,5/sintomático: 10–20 mEq/h IV (máx. 40 mEq/h com monitoração). VO: 40–80 mEq/dia.',
      'es': 'K+ 3,0–3,5: 40 mEq VO o IV. K+ 2,5–3,0: 40–80 mEq IV lento. K+ <2,5/sintomático: 10–20 mEq/h IV.',
    },
    renalAlert: {
      'pt': 'IRC: RESTRIÇÃO (hiperpotassemia é o risco). Usar apenas se comprovada hipopotassemia grave. Monitorar K+ a cada 2–4h.',
      'es': 'IRC: RESTRICCIÓN (hiperpotasemia es el riesgo). Usar solo si hipopotasemia grave comprobada.',
    },
    elderlyAlert: {
      'pt': 'Monitorar K+ e ECG especialmente em uso de IECA, ARA2, diuréticos poupadores. Risco de hiperpotassemia.',
      'es': 'Monitorizar K+ y ECG especialmente con IECA, ARA2, diuréticos ahorradores.',
    },
    mechanism: {
      'pt': 'Reposição de K+ intracelular. Principal cátion intracelular — essencial para potencial de membrana, função cardíaca e neuromuscular.',
      'es': 'Reposición de K+ intracelular. Principal catión intracelular — esencial para potencial de membrana y función cardíaca.',
    },
    warning: {
      'pt': 'NUNCA em bolus IV direto (arritmia fatal). Diluição obrigatória: máx. 40 mEq/100 mL. Taxa máx. 40 mEq/h (com monitoração ECG). Flebite em veia periférica — preferir via central para taxas altas.',
      'es': 'NUNCA en bolo IV directo (arritmia fatal). Dilución obligatoria: máx. 40 mEq/100 mL. Tasa máx. 40 mEq/h (con monitoreo ECG).',
    },
    adverse: {
      'pt': ['Hiperpotassemia (se mal dosado)', 'Flebite', 'Arritmia (se bolus/taxa excessiva)', 'Dor local'],
      'es': ['Hiperpotasemia (si mal dosificado)', 'Flebitis', 'Arritmia (si bolo/tasa excesiva)', 'Dolor local'],
    },
  ),

];
