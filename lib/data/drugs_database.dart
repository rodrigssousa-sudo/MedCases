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

  // ═══════════════════════════════════════════════════════════════
  //  CARDIOVASCULARES - EXPANSÃO
  // ═══════════════════════════════════════════════════════════════

  DrugModel(
    id: 'atenolol',
    name: 'Atenolol',
    className: {'pt': 'Betabloqueador cardiosseletivo', 'es': 'Betabloqueador cardioselectivo'},
    category: {'pt': 'Cardiovasculares', 'es': 'Cardiovasculares'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': '25–50 mg VO 1x/dia (hipertensão). Angina: 50–100 mg/dia. Pós-IAM: iniciar 50 mg 12/12h por 6–9 dias, depois 100 mg/dia.',
      'es': '25–50 mg VO 1x/día (hipertensión). Angina: 50–100 mg/día. Post-IAM: iniciar 50 mg c/12h por 6–9 días, luego 100 mg/día.',
    },
    renalAlert: {
      'pt': 'ClCr 15–35 mL/min: 50 mg dia alternado. ClCr <15 mL/min: 50 mg a cada 4 dias ou 25 mg/dia. Dialisável (hemodiálise pós-sessão).',
      'es': 'ClCr 15–35 mL/min: 50 mg día alternado. ClCr <15 mL/min: 50 mg cada 4 días. Dializablepost-hemodiálisis).',
    },
    elderlyAlert: {
      'pt': 'Iniciar 25 mg/dia. Risco de bradicardia, hipotensão ortostática, broncoespasmo (evitar se DPOC grave).',
      'es': 'Iniciar 25 mg/día. Riesgo de bradicardia, hipotensión ortostática, broncoespasmo.',
    },
    mechanism: {
      'pt': 'Antagonista β1-seletivo → ↓ FC, ↓ contratilidade, ↓ consumo O₂ miocárdico. Hidrofílico (excreção renal).',
      'es': 'Antagonista β1-selectivo → ↓ FC, ↓ contractilidad, ↓ consumo O₂ miocárdico. Hidrofílico (excreción renal).',
    },
    warning: {
      'pt': 'Contraindicado: bradicardia <50 bpm, BAV 2º/3º grau, choque cardiogênico, asma grave. Suspender gradualmente (risco rebote).',
      'es': 'Contraindicado: bradicardia <50 lpm, BAV 2º/3º grado, shock cardiogénico, asma grave. Suspender gradualmente.',
    },
    adverse: {
      'pt': ['Bradicardia', 'Fadiga', 'Extremidades frias', 'Broncoespasmo (dose-dependente)', 'Disfunção erétil', 'Depressão (raro)'],
      'es': ['Bradicardia', 'Fatiga', 'Extremidades frías', 'Broncoespasmo', 'Disfunción eréctil', 'Depresión (raro)'],
    },
  ),

  DrugModel(
    id: 'metoprolol',
    name: 'Metoprolol',
    className: {'pt': 'Betabloqueador cardiosseletivo', 'es': 'Betabloqueador cardioselectivo'},
    category: {'pt': 'Cardiovasculares', 'es': 'Cardiovasculares'},
    route: 'VO / IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'VO: 50–100 mg 12/12h (hipertensão/angina). IC: iniciar 12,5–25 mg 12/12h, titular lento até 200 mg/dia. IV (IAM/arritmia): 5 mg lento 3 doses (2 min cada), intervalo 5 min.',
      'es': 'VO: 50–100 mg c/12h (hipertensión/angina). IC: iniciar 12,5–25 mg c/12h, titular lento hasta 200 mg/día. IV: 5 mg lento 3 dosis.',
    },
    renalAlert: {
      'pt': 'Ajuste desnecessário (metabolismo hepático). Cautela se disfunção hepática grave (↓ dose 50%).',
      'es': 'Ajuste innecesario (metabolismo hepático). Cautela si disfunción hepática grave.',
    },
    elderlyAlert: {
      'pt': 'Iniciar doses baixas (12,5–25 mg). Monitorar PA, FC, sinais de IC descompensada.',
      'es': 'Iniciar dosis bajas. Monitorizar PA, FC, signos de IC descompensada.',
    },
    mechanism: {
      'pt': 'Antagonista β1-seletivo (lipofílico) → ↓ FC, ↓ PA, ↓ mortalidade pós-IAM e IC.',
      'es': 'Antagonista β1-selectivo (lipofílico) → ↓ FC, ↓ PA, ↓ mortalidad post-IAM e IC.',
    },
    warning: {
      'pt': 'Contraindicações: BAV 2º/3º grau, bradicardia <45 bpm, choque cardiogênico, asma descontrolada. Suspender gradualmente.',
      'es': 'Contraindicaciones: BAV 2º/3º grado, bradicardia <45 lpm, shock cardiogénico, asma no controlada.',
    },
    adverse: {
      'pt': ['Bradicardia', 'Hipotensão', 'Fadiga', 'Tontura', 'Broncoespasmo (β2 em altas doses)', 'Pesadelos', 'Disfunção erétil'],
      'es': ['Bradicardia', 'Hipotensión', 'Fatiga', 'Mareo', 'Broncoespasmo', 'Pesadillas', 'Disfunción eréctil'],
    },
  ),

  DrugModel(
    id: 'enalapril',
    name: 'Enalapril',
    className: {'pt': 'IECA (Inibidor da ECA)', 'es': 'IECA (Inhibidor de la ECA)'},
    category: {'pt': 'Cardiovasculares', 'es': 'Cardiovasculares'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Hipertensão: 5–10 mg/dia, máx. 40 mg/dia. IC: iniciar 2,5 mg 12/12h, titular até 10–20 mg 12/12h.',
      'es': 'Hipertensión: 5–10 mg/día, máx. 40 mg/día. IC: iniciar 2,5 mg c/12h, titular hasta 10–20 mg c/12h.',
    },
    renalAlert: {
      'pt': 'ClCr 30–80 mL/min: 5 mg/dia. ClCr 10–30: 2,5 mg/dia. ClCr <10: 2,5 mg pós-hemodiálise. Monitorar K⁺ e creatinina (semana 1–2).',
      'es': 'ClCr 30–80 mL/min: 5 mg/día. ClCr 10–30: 2,5 mg/día. ClCr <10: 2,5 mg post-hemodiálisis. Monitorizar K⁺ y creatinina.',
    },
    elderlyAlert: {
      'pt': 'Iniciar 2,5 mg/dia. Risco hipotensão primeira dose (administrar à noite). Monitorar função renal e K⁺.',
      'es': 'Iniciar 2,5 mg/día. Riesgo hipotensión primera dosis (administrar por la noche). Monitorizar función renal y K⁺.',
    },
    mechanism: {
      'pt': 'Inibe ECA → ↓ angiotensina II, ↓ aldosterona → vasodilatação, ↓ retenção Na⁺/H₂O, ↓ remodelamento cardíaco.',
      'es': 'Inhibe ECA → ↓ angiotensina II, ↓ aldosterona → vasodilatación, ↓ retención Na⁺/H₂O.',
    },
    warning: {
      'pt': 'Contraindicado: gravidez, angioedema prévio, estenose bilateral artéria renal. Evitar K⁺ suplementar e diuréticos poupadores K⁺ (risco hipercalemia).',
      'es': 'Contraindicado: embarazo, angioedema previo, estenosis bilateral arteria renal. Evitar suplemento K⁺.',
    },
    adverse: {
      'pt': ['Tosse seca (10–15%)', 'Hipotensão primeira dose', 'Hipercalemia', 'Insuficiência renal (estenose bilateral)', 'Angioedema (raro, 0,1–0,5%)', 'Rash'],
      'es': ['Tos seca (10–15%)', 'Hipotensión primera dosis', 'Hiperpotasemia', 'Insuficiencia renal', 'Angioedema (raro)', 'Rash'],
    },
  ),

  DrugModel(
    id: 'losartana',
    name: 'Losartana',
    className: {'pt': 'BRA (Bloqueador Receptor AT1)', 'es': 'ARA-II (Antagonista Receptor AT1)'},
    category: {'pt': 'Cardiovasculares', 'es': 'Cardiovasculares'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Hipertensão: 50 mg/dia, máx. 100 mg/dia. IC: 25–50 mg/dia. Nefropatia diabética: 50–100 mg/dia.',
      'es': 'Hipertensión: 50 mg/día, máx. 100 mg/día. IC: 25–50 mg/día. Nefropatía diabética: 50–100 mg/día.',
    },
    renalAlert: {
      'pt': 'ClCr <30 mL/min: iniciar 25 mg/dia. Monitorar K⁺ e creatinina (semana 1–2). Evitar se hipercalemia >5,5 mEq/L.',
      'es': 'ClCr <30 mL/min: iniciar 25 mg/día. Monitorizar K⁺ y creatinina. Evitar si hiperpotasemia >5,5 mEq/L.',
    },
    elderlyAlert: {
      'pt': 'Iniciar 25 mg/dia (volume-depleted). Sem ajuste de rotina em >65 anos se normovolêmicos.',
      'es': 'Iniciar 25 mg/día si depleción de volumen. Sin ajuste rutinario en >65 años.',
    },
    mechanism: {
      'pt': 'Antagonista competitivo receptor AT1 → bloqueia angiotensina II → vasodilatação, ↓ aldosterona, nefroproteção.',
      'es': 'Antagonista competitivo receptor AT1 → bloquea angiotensina II → vasodilatación, ↓ aldosterona.',
    },
    warning: {
      'pt': 'Contraindicado: gravidez, estenose bilateral artéria renal, hipercalemia. NÃO combinar IECA + BRA (↑ eventos adversos).',
      'es': 'Contraindicado: embarazo, estenosis bilateral, hiperpotasemia. NO combinar IECA + ARA-II.',
    },
    adverse: {
      'pt': ['Hipercalemia', 'Tontura', 'Cefaleia', 'Insuficiência renal (estenose bilateral)', 'Angioedema (muito raro, <0,1%)', 'Hipotensão'],
      'es': ['Hiperpotasemia', 'Mareo', 'Cefalea', 'Insuficiencia renal', 'Angioedema (muy raro)', 'Hipotensión'],
    },
  ),

  DrugModel(
    id: 'espironolactona',
    name: 'Espironolactona',
    className: {'pt': 'Diurético poupador de potássio (antagonista aldosterona)', 'es': 'Diurético ahorrador de potasio'},
    category: {'pt': 'Cardiovasculares', 'es': 'Cardiovasculares'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'IC (NYHA II–IV): 25 mg/dia, máx. 50 mg/dia. Hipertensão refratária: 25–50 mg/dia. Ascite: 100–400 mg/dia.',
      'es': 'IC (NYHA II–IV): 25 mg/día, máx. 50 mg/día. Hipertensión refractaria: 25–50 mg/día. Ascitis: 100–400 mg/día.',
    },
    renalAlert: {
      'pt': 'Contraindicado se ClCr <30 mL/min ou K⁺ >5,0 mEq/L. Monitorar K⁺ e creatinina após 1 semana e mensalmente.',
      'es': 'Contraindicado si ClCr <30 mL/min o K⁺ >5,0 mEq/L. Monitorizar K⁺ y creatinina semanalmente.',
    },
    elderlyAlert: {
      'pt': 'Risco aumentado de hipercalemia. Iniciar 12,5–25 mg/dia. Evitar em >75 anos com IECA/BRA + ClCr <60.',
      'es': 'Riesgo aumentado de hiperpotasemia. Iniciar 12,5–25 mg/día. Evitar en >75 años con IECA/ARA-II.',
    },
    mechanism: {
      'pt': 'Antagonista competitivo aldosterona → ↓ reabsorção Na⁺/H₂O no ducto coletor, ↑ excreção Na⁺, ↓ secreção K⁺. Reduz fibrose miocárdica.',
      'es': 'Antagonista aldosterona → ↓ reabsorción Na⁺/H₂O, ↑ excreción Na⁺, ↓ secreción K⁺.',
    },
    warning: {
      'pt': 'Contraindicado: hipercalemia, insuficiência renal grave, doença de Addison. EVITAR suplementos K⁺. Interação: IECA/BRA/AINEs/trimetoprima ↑ risco hipercalemia.',
      'es': 'Contraindicado: hiperpotasemia, insuficiencia renal grave. EVITAR suplementos K⁺.',
    },
    adverse: {
      'pt': ['Hipercalemia', 'Ginecomastia (10–20% homens)', 'Irregularidade menstrual', 'Hipotensão', 'Náuseas', 'Hiponatremia', 'Acidose metabólica hiperclorêmica'],
      'es': ['Hiperpotasemia', 'Ginecomastia (10–20% hombres)', 'Irregularidad menstrual', 'Hipotensión', 'Náuseas', 'Hiponatremia'],
    },
  ),

  DrugModel(
    id: 'anlodipino',
    name: 'Anlodipino',
    className: {'pt': 'Bloqueador de canal de cálcio (di-hidropiridina)', 'es': 'Bloqueador de canal de calcio (dihidropiridina)'},
    category: {'pt': 'Cardiovasculares', 'es': 'Cardiovasculares'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': '5–10 mg 1x/dia (hipertensão/angina estável). Iniciar 2,5 mg/dia em idosos ou hepatopatas.',
      'es': '5–10 mg 1x/día (hipertensión/angina estable). Iniciar 2,5 mg/día en ancianos o hepatópatas.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário (metabolismo hepático). Seguro em DRC.',
      'es': 'Sin ajuste necesario (metabolismo hepático). Seguro en ERC.',
    },
    elderlyAlert: {
      'pt': 'Iniciar 2,5 mg/dia. Risco edema periférico (até 30% idosos). Monitorar PA ortostática.',
      'es': 'Iniciar 2,5 mg/día. Riesgo edema periférico (hasta 30% ancianos).',
    },
    mechanism: {
      'pt': 'Bloqueia canais Ca²⁺ tipo L → vasodilatação arterial periférica e coronariana → ↓ RVP, ↓ PA, ↓ pós-carga.',
      'es': 'Bloquea canales Ca²⁺ tipo L → vasodilatación arterial periférica y coronaria.',
    },
    warning: {
      'pt': 'Evitar em IC descompensada (↑ mortalidade PRAISE-2). Interação: suco de grapefruit ↑ níveis plasmáticos.',
      'es': 'Evitar en IC descompensada. Interacción: jugo de toronja ↑ niveles plasmáticos.',
    },
    adverse: {
      'pt': ['Edema periférico (10–30%)', 'Cefaleia', 'Rubor facial', 'Palpitações', 'Fadiga', 'Tontura', 'Hiperplasia gengival (raro)'],
      'es': ['Edema periférico (10–30%)', 'Cefalea', 'Rubor facial', 'Palpitaciones', 'Fatiga', 'Mareo'],
    },
  ),

  DrugModel(
    id: 'digoxina',
    name: 'Digoxina',
    className: {'pt': 'Glicosídeo cardíaco (inotrópico + cronotrópico negativo)', 'es': 'Glucósido cardíaco'},
    category: {'pt': 'Cardiovasculares', 'es': 'Cardiovasculares'},
    route: 'VO / IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'VO: 0,125–0,25 mg/dia. FA rápida: dose ataque 0,5–0,75 mg → 0,25 mg 6h depois → manutenção. IV: 0,5 mg lento.',
      'es': 'VO: 0,125–0,25 mg/día. FA rápida: carga 0,5–0,75 mg → 0,25 mg 6h después → mantenimiento. IV: 0,5 mg lento.',
    },
    renalAlert: {
      'pt': 'ClCr <50 mL/min: ↓ 50% dose (0,0625–0,125 mg/dia ou dia alternado). Dialisável (suplementar pós-HD). Monitorar digoxinemia (0,5–0,9 ng/mL).',
      'es': 'ClCr <50 mL/min: ↓ 50% dosis. Dializable (suplementar post-HD). Monitorizar digoxinemia (0,5–0,9 ng/mL).',
    },
    elderlyAlert: {
      'pt': 'Dose máxima 0,125 mg/dia (↓ massa magra). Risco intoxicação (náuseas, arritmias). Alvo digoxinemia 0,5–0,8 ng/mL.',
      'es': 'Dosis máxima 0,125 mg/día. Riesgo intoxicación (náuseas, arritmias). Meta 0,5–0,8 ng/mL.',
    },
    mechanism: {
      'pt': 'Inibe Na⁺/K⁺-ATPase → ↑ Ca²⁺ intracelular → ↑ contratilidade. ↑ tônus vagal → ↓ condução AV (controle FC em FA).',
      'es': 'Inhibe Na⁺/K⁺-ATPasa → ↑ Ca²⁺ intracelular → ↑ contractilidad. ↑ tono vagal → ↓ conducción AV.',
    },
    warning: {
      'pt': 'Contraindicado: BAV 2º/3º grau, FA + WPW, hipocalemia/hipomagnesemia (↑ risco toxicidade). Interação: amiodarona/verapamil ↑ níveis 50%.',
      'es': 'Contraindicado: BAV 2º/3º grado, FA + WPW, hipopotasemia. Interacción: amiodarona/verapamilo ↑ niveles.',
    },
    adverse: {
      'pt': ['Intoxicação digitálica (náuseas, visão amarelada, arritmias ventriculares)', 'Bradicardia', 'BAV', 'Ginecomastia', 'Confusão mental (idosos)'],
      'es': ['Intoxicación digitálica (náuseas, visión amarillenta, arritmias)', 'Bradicardia', 'BAV', 'Ginecomastia', 'Confusión'],
    },
  ),

  // ═══════════════════════════════════════════════════════════════
  //  ANTIBIÓTICOS - EXPANSÃO
  // ═══════════════════════════════════════════════════════════════

  DrugModel(
    id: 'amoxicilina_clavulanato',
    name: 'Amoxicilina + Clavulanato',
    className: {'pt': 'Penicilina + inibidor β-lactamase', 'es': 'Penicilina + inhibidor β-lactamasa'},
    category: {'pt': 'Antibióticos', 'es': 'Antibióticos'},
    route: 'VO / IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'VO: 500/125 mg ou 875/125 mg 8/8h ou 12/12h. IV: 1–2 g (amoxicilina) 6/6–8/8h (pneumonia grave, sepse abdominal).',
      'es': 'VO: 500/125 mg u 875/125 mg c/8h o c/12h. IV: 1–2 g (amoxicilina) c/6–8h.',
    },
    renalAlert: {
      'pt': 'ClCr 10–30 mL/min: 500/125 mg 12/12h. ClCr <10: 500/125 mg 24/24h. Hemodiálise: dose pós-sessão.',
      'es': 'ClCr 10–30 mL/min: 500/125 mg c/12h. ClCr <10: 500/125 mg c/24h. Hemodiálisis: dosis post-sesión.',
    },
    elderlyAlert: {
      'pt': 'Ajustar por ClCr. Risco diarreia (Clostridioides difficile). Monitorar função hepática (raro hepatotoxicidade colestática).',
      'es': 'Ajustar por ClCr. Riesgo diarrea (C. difficile). Monitorizar función hepática.',
    },
    mechanism: {
      'pt': 'Amoxicilina inibe síntese parede bacteriana (β-lactâmico). Clavulanato inibe β-lactamases → ↑ espectro (H. influenzae, M. catarrhalis, anaeróbios).',
      'es': 'Amoxicilina inhibe síntesis pared bacteriana. Clavulanato inhibe β-lactamasas.',
    },
    warning: {
      'pt': 'Contraindicado: alergia penicilinas. Reação cruzada com cefalosporinas (5–10%). Diarreia (10–25%, usar formulação XR se intolerância).',
      'es': 'Contraindicado: alergia penicilinas. Reacción cruzada con cefalosporinas (5–10%).',
    },
    adverse: {
      'pt': ['Diarreia (10–25%)', 'Náuseas', 'Colite pseudomembranosa (C. difficile)', 'Rash', 'Hepatotoxicidade colestática (raro)', 'Cristalúria (altas doses IV)'],
      'es': ['Diarrea (10–25%)', 'Náuseas', 'Colitis pseudomembranosa', 'Rash', 'Hepatotoxicidad', 'Cristaluria'],
    },
  ),

  DrugModel(
    id: 'ceftriaxona',
    name: 'Ceftriaxona',
    className: {'pt': 'Cefalosporina 3ª geração', 'es': 'Cefalosporina 3ª generación'},
    category: {'pt': 'Antibióticos', 'es': 'Antibióticos'},
    route: 'IV / IM',
    doseType: 'fixed',
    fixedDose: {
      'pt': '1–2 g IV/IM 1x/dia. Meningite: 2 g 12/12h. Infecção grave: 2 g 12/12h. Gonorreia: 500 mg IM dose única.',
      'es': '1–2 g IV/IM 1x/día. Meningitis: 2 g c/12h. Infección grave: 2 g c/12h. Gonorrea: 500 mg IM dosis única.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário até ClCr >10 mL/min (excreção biliar + renal). Se ClCr <10 + hepatopatia: máx. 2 g/dia.',
      'es': 'Sin ajuste necesario hasta ClCr >10 mL/min. Si ClCr <10 + hepatopatía: máx. 2 g/día.',
    },
    elderlyAlert: {
      'pt': 'Dose padrão. Monitorar bilirrubina (risco precipitação biliar em idosos debilitados). Evitar Ca²⁺ IV concomitante (precipitação).',
      'es': 'Dosis estándar. Monitorizar bilirrubina. Evitar Ca²⁺ IV concomitante.',
    },
    mechanism: {
      'pt': 'Inibe transpeptidases (PBPs) → ↓ síntese peptideoglicano → lise bacteriana. Espectro: gram-negativos (E. coli, Klebsiella, Proteus), Streptococcus, Neisseria.',
      'es': 'Inhibe transpeptidasas → ↓ síntesis peptidoglicano. Espectro: gram-negativos, Streptococcus, Neisseria.',
    },
    warning: {
      'pt': 'Contraindicado: neonatos com hiperbilirrubinemia (deslocamento albumina), uso concomitante Ca²⁺ IV (precipitação). Alergia cruzada com penicilinas (5–10%).',
      'es': 'Contraindicado: neonatos con hiperbilirrubinemia, uso Ca²⁺ IV concomitante. Alergia cruzada penicilinas.',
    },
    adverse: {
      'pt': ['Diarreia (5–10%)', 'Rash', 'Eosinofilia', 'Trombocitose', 'Pseudolitíase biliar (2–4%, reversível)', 'Colite pseudomembranosa (raro)', 'Anafilaxia (raro)'],
      'es': ['Diarrea (5–10%)', 'Rash', 'Eosinofilia', 'Pseudolitiasis biliar (2–4%)', 'Colitis pseudomembranosa', 'Anafilaxia'],
    },
  ),

  DrugModel(
    id: 'azitromicina',
    name: 'Azitromicina',
    className: {'pt': 'Macrolídeo', 'es': 'Macrólido'},
    category: {'pt': 'Antibióticos', 'es': 'Antibióticos'},
    route: 'VO / IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'VO: 500 mg 1x/dia por 3 dias (pneumonia comunitária). IV: 500 mg 1x/dia (infecção grave). IST: 1 g VO dose única (clamídia/gonorreia).',
      'es': 'VO: 500 mg 1x/día por 3 días. IV: 500 mg 1x/día. ITS: 1 g VO dosis única.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário (excreção biliar predominante). Cautela se ClCr <10 mL/min (monitorar função hepática).',
      'es': 'Sin ajuste necesario (excreción biliar). Cautela si ClCr <10 mL/min.',
    },
    elderlyAlert: {
      'pt': 'Dose padrão. Risco prolongamento QT (evitar se QTc >500 ms, hipocalemia, uso concomitante antiarrítmicos). ECG basal se >75 anos.',
      'es': 'Dosis estándar. Riesgo prolongación QT. ECG basal si >75 años.',
    },
    mechanism: {
      'pt': 'Inibe subunidade 50S ribossomal → ↓ síntese proteica bacteriana. Espectro: Mycoplasma, Chlamydia, Legionella, H. influenzae, gram-positivos (S. pneumoniae sensível).',
      'es': 'Inhibe subunidad 50S ribosomal → ↓ síntesis proteica. Espectro: Mycoplasma, Chlamydia, Legionella, gram-positivos.',
    },
    warning: {
      'pt': 'Contraindicado: hepatopatia grave, QTc prolongado. Interação: warfarina (↑ INR), digoxina (↑ níveis). Resistência crescente S. pneumoniae.',
      'es': 'Contraindicado: hepatopatía grave, QTc prolongado. Interacción: warfarina, digoxina.',
    },
    adverse: {
      'pt': ['Diarreia (5–10%)', 'Náuseas', 'Dor abdominal', 'Prolongamento QT (raro, <1%)', 'Hepatotoxicidade (raro)', 'Arritmias ventriculares (torsades de pointes, raro)'],
      'es': ['Diarrea (5–10%)', 'Náuseas', 'Dolor abdominal', 'Prolongación QT', 'Hepatotoxicidad', 'Arritmias ventriculares'],
    },
  ),

  DrugModel(
    id: 'ciprofloxacino',
    name: 'Ciprofloxacino',
    className: {'pt': 'Fluoroquinolona', 'es': 'Fluoroquinolona'},
    category: {'pt': 'Antibióticos', 'es': 'Antibióticos'},
    route: 'VO / IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'VO: 500–750 mg 12/12h. IV: 400 mg 8/8–12/12h (infecção grave). ITU: 250–500 mg 12/12h por 3–7 dias.',
      'es': 'VO: 500–750 mg c/12h. IV: 400 mg c/8–12h. ITU: 250–500 mg c/12h por 3–7 días.',
    },
    renalAlert: {
      'pt': 'ClCr 30–50 mL/min: 500–750 mg 12/12h. ClCr <30: 250–500 mg 12/12h. Hemodiálise: 250–500 mg pós-sessão.',
      'es': 'ClCr 30–50 mL/min: 500–750 mg c/12h. ClCr <30: 250–500 mg c/12h. Hemodiálisis: pós-sesión.',
    },
    elderlyAlert: {
      'pt': 'Risco tendinite/ruptura tendão Aquiles (2–3x maior >60 anos + corticoides). Evitar se história tendinopatia. Risco prolongamento QT.',
      'es': 'Riesgo tendinitis/ruptura tendón Aquiles (2–3x >60 años + corticoides). Riesgo prolongación QT.',
    },
    mechanism: {
      'pt': 'Inibe DNA girase e topoisomerase IV → ↓ replicação DNA bacteriano. Espectro: gram-negativos (E. coli, Pseudomonas, Klebsiella), atípicos, alguns gram-positivos.',
      'es': 'Inhibe DNA girasa y topoisomerasa IV. Espectro: gram-negativos, atípicos, algunos gram-positivos.',
    },
    warning: {
      'pt': 'Contraindicado: <18 anos (risco cartilagem), gravidez/lactação, miastenia gravis (↑ fraqueza). Evitar antiácidos (↓ absorção). Interação: teofilina, warfarina.',
      'es': 'Contraindicado: <18 años, embarazo, miastenia gravis. Evitar antiácidos. Interacción: teofilina, warfarina.',
    },
    adverse: {
      'pt': ['Náuseas/diarreia (5–10%)', 'Tendinite/ruptura tendão (1–2%)', 'Prolongamento QT', 'Neuropatia periférica (raro)', 'Fototoxicidade', 'Confusão/alucinações (idosos)', 'Hipoglicemia (diabéticos)'],
      'es': ['Náuseas/diarrea', 'Tendinitis/ruptura tendón (1–2%)', 'Prolongación QT', 'Neuropatía periférica', 'Fototoxicidad', 'Confusión'],
    },
  ),

  DrugModel(
    id: 'vancomicina',
    name: 'Vancomicina',
    className: {'pt': 'Glicopeptídeo', 'es': 'Glucopéptido'},
    category: {'pt': 'Antibióticos', 'es': 'Antibióticos'},
    route: 'IV',
    doseType: 'weight',
    fixedDose: {
      'pt': '15–20 mg/kg IV 8/8–12/12h (infusão lenta ≥60 min). Alvo nível vale: 15–20 µg/mL (infecção grave), 10–15 µg/mL (bacteremia).',
      'es': '15–20 mg/kg IV c/8–12h (infusión lenta ≥60 min). Meta nivel valle: 15–20 µg/mL (infección grave).',
    },
    renalAlert: {
      'pt': 'Ajustar por ClCr e níveis séricos. ClCr 20–49: 15 mg/kg 24/24h. ClCr <20: dose ataque 15 mg/kg → individualizar por níveis. Monitorar vale pré-4ª dose.',
      'es': 'Ajustar por ClCr y niveles séricos. ClCr 20–49: c/24h. ClCr <20: individualizar. Monitorizar valle antes de 4ª dosis.',
    },
    elderlyAlert: {
      'pt': 'Risco nefrotoxicidade (↑ se >65 anos + desidratação + aminoglicosídeos). Monitorar creatinina e níveis vancomicina. Hidratar adequadamente.',
      'es': 'Riesgo nefrotoxicidad (↑ >65 años + deshidratación). Monitorizar creatinina y niveles. Hidratar.',
    },
    mechanism: {
      'pt': 'Inibe síntese parede celular (liga D-Ala-D-Ala) → lise bacteriana. Espectro: gram-positivos (MRSA, S. epidermidis, Enterococcus, C. difficile oral).',
      'es': 'Inhibe síntesis pared celular. Espectro: gram-positivos (MRSA, Enterococcus, C. difficile oral).',
    },
    warning: {
      'pt': 'Contraindicado: alergia vancomicina. Síndrome homem vermelho (infusão rápida → histamina). Nefrotoxicidade (10–20% se níveis >20 µg/mL). Ototoxicidade (raro).',
      'es': 'Contraindicado: alergia. Síndrome hombre rojo (infusión rápida). Nefrotoxicidad (10–20%). Ototoxicidad.',
    },
    adverse: {
      'pt': ['Síndrome homem vermelho (rubor, prurido, hipotensão)', 'Nefrotoxicidade (10–20%)', 'Flebite', 'Trombocitopenia', 'Neutropenia (raro)', 'Ototoxicidade (raro)'],
      'es': ['Síndrome hombre rojo', 'Nefrotoxicidad (10–20%)', 'Flebitis', 'Trombocitopenia', 'Neutropenia', 'Ototoxicidad'],
    },
  ),

  DrugModel(
    id: 'meropenem',
    name: 'Meropenem',
    className: {'pt': 'Carbapenem', 'es': 'Carbapenem'},
    category: {'pt': 'Antibióticos', 'es': 'Antibióticos'},
    route: 'IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': '1 g IV 8/8h (infecção grave). Meningite: 2 g 8/8h (infusão 3h). Sepse: 1–2 g 8/8h (infusão estendida).',
      'es': '1 g IV c/8h (infección grave). Meningitis: 2 g c/8h (infusión 3h). Sepsis: 1–2 g c/8h.',
    },
    renalAlert: {
      'pt': 'ClCr 26–50: 1 g 12/12h. ClCr 10–25: 500 mg 12/12h. ClCr <10: 500 mg 24/24h. Hemodiálise: 500 mg pós-sessão.',
      'es': 'ClCr 26–50: 1 g c/12h. ClCr 10–25: 500 mg c/12h. ClCr <10: 500 mg c/24h. Hemodiálisis: post-sesión.',
    },
    elderlyAlert: {
      'pt': 'Ajustar por ClCr. Risco convulsões (0,5–1% se SNC comprometido, IR, doses altas). Evitar se história epilepsia sem controle.',
      'es': 'Ajustar por ClCr. Riesgo convulsiones (0,5–1%). Evitar si epilepsia no controlada.',
    },
    mechanism: {
      'pt': 'Inibe PBPs → ↓ síntese peptideoglicano → lise bacteriana. Espectro amplo: gram-positivos, gram-negativos (incluindo Pseudomonas), anaeróbios. Estável a β-lactamases.',
      'es': 'Inhibe PBPs → lise bacteriana. Espectro amplio: gram-positivos, gram-negativos (Pseudomonas), anaerobios.',
    },
    warning: {
      'pt': 'Contraindicado: alergia carbapenems. Alergia cruzada penicilinas/cefalosporinas (1–5%). Uso empírico sepse grave/neutropenia febril. Evitar uso prolongado (resistência).',
      'es': 'Contraindicado: alergia carbapenems. Alergia cruzada penicilinas. Uso empírico sepsis grave.',
    },
    adverse: {
      'pt': ['Diarreia (4–5%)', 'Náuseas', 'Rash', 'Flebite', 'Convulsões (0,5–1%)', 'Colite pseudomembranosa', 'Eosinofilia', 'Trombocitopenia (raro)'],
      'es': ['Diarrea (4–5%)', 'Náuseas', 'Rash', 'Flebitis', 'Convulsiones (0,5–1%)', 'Colitis pseudomembranosa', 'Trombocitopenia'],
    },
  ),

  // ═══════════════════════════════════════════════════════════════
  //  RESPIRATÓRIOS - EXPANSÃO
  // ═══════════════════════════════════════════════════════════════

  DrugModel(
    id: 'salbutamol',
    name: 'Salbutamol (Albuterol)',
    className: {'pt': 'Broncodilatador β2-agonista de curta ação', 'es': 'Broncodilatador β2-agonista de corta acción'},
    category: {'pt': 'Respiratórios', 'es': 'Respiratorios'},
    route: 'Inalatório / IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Inalatório: 2–4 puffs (100 µg/puff) 4/4–6/6h. Exacerbação: nebulização 2,5–5 mg em 3 mL SF 0,9% 20/20min × 3 doses, depois 4/4h.',
      'es': 'Inhalatorio: 2–4 puffs (100 µg/puff) c/4–6h. Exacerbación: nebulización 2,5–5 mg en 3 mL SF 0,9% c/20min × 3, luego c/4h.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário (metabolismo hepático). Seguro em DRC.',
      'es': 'Sin ajuste necesario (metabolismo hepático). Seguro en ERC.',
    },
    elderlyAlert: {
      'pt': 'Dose padrão. Risco taquicardia (↑ se cardiopatia). Tremor fino (dose-dependente). Monitorar FC e ECG se cardiopatia.',
      'es': 'Dosis estándar. Riesgo taquicardia (↑ si cardiopatía). Temblor fino. Monitorizar FC y ECG.',
    },
    mechanism: {
      'pt': 'Agonista β2-adrenérgico → ↑ AMPc → relaxamento músculo liso brônquico → broncodilatação. Início 5 min, pico 30–60 min, duração 4–6h.',
      'es': 'Agonista β2-adrenérgico → ↑ AMPc → relajación músculo liso bronquial → broncodilatación.',
    },
    warning: {
      'pt': 'Contraindicado: taquiarritmias. Cautela: cardiopatia isquêmica, hipertireoidismo, DM (hiperglicemia transitória). Hipocalemia (altas doses).',
      'es': 'Contraindicado: taquiarritmias. Cautela: cardiopatía isquémica, hipertiroidismo, DM.',
    },
    adverse: {
      'pt': ['Tremor fino (10–20%)', 'Taquicardia', 'Palpitações', 'Hipocalemia (altas doses)', 'Hiperglicemia transitória', 'Cefaleia', 'Nervosismo'],
      'es': ['Temblor fino (10–20%)', 'Taquicardia', 'Palpitaciones', 'Hipopotasemia', 'Hiperglucemia', 'Cefalea', 'Nerviosismo'],
    },
  ),

  DrugModel(
    id: 'ipratropio',
    name: 'Ipratrópio',
    className: {'pt': 'Broncodilatador anticolinérgico', 'es': 'Broncodilatador anticolinérgico'},
    category: {'pt': 'Respiratórios', 'es': 'Respiratorios'},
    route: 'Inalatório',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Inalatório: 2–4 puffs (20 µg/puff) 6/6h. Exacerbação DPOC: nebulização 500 µg (20 gotas) em 3 mL SF 0,9% 4/4–6/6h.',
      'es': 'Inhalatorio: 2–4 puffs (20 µg/puff) c/6h. Exacerbación EPOC: nebulización 500 µg (20 gotas) en 3 mL SF 0,9% c/4–6h.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário (absorção sistêmica mínima).',
      'es': 'Sin ajuste necesario (absorción sistémica mínima).',
    },
    elderlyAlert: {
      'pt': 'Dose padrão. Cautela: glaucoma de ângulo fechado, hiperplasia prostática. Evitar contato olhos (nebulização com máscara).',
      'es': 'Dosis estándar. Cautela: glaucoma de ángulo cerrado, hiperplasia prostática. Evitar contacto ojos.',
    },
    mechanism: {
      'pt': 'Antagonista competitivo receptores muscarínicos M3 → ↓ AMPc → broncodilatação. Sinérgico com β2-agonistas. Início 15 min, pico 1–2h, duração 4–6h.',
      'es': 'Antagonista receptores muscarínicos M3 → broncodilatación. Sinérgico con β2-agonistas.',
    },
    warning: {
      'pt': 'Contraindicado: alergia atropina/derivados. Cautela: glaucoma, obstrução urinária. Combinação com salbutamol ↑ eficácia (DPOC exacerbação).',
      'es': 'Contraindicado: alergia atropina. Cautela: glaucoma, obstrucción urinaria. Combinación salbutamol ↑ eficacia.',
    },
    adverse: {
      'pt': ['Boca seca (10–15%)', 'Tosse', 'Cefaleia', 'Náuseas', 'Visão turva (se contato olhos)', 'Glaucoma agudo (raro, se contato olhos)', 'Retenção urinária (raro)'],
      'es': ['Boca seca (10–15%)', 'Tos', 'Cefalea', 'Náuseas', 'Visión borrosa', 'Glaucoma agudo (raro)', 'Retención urinaria'],
    },
  ),

  DrugModel(
    id: 'prednisolona',
    name: 'Prednisolona',
    className: {'pt': 'Corticosteroide sistêmico', 'es': 'Corticosteroide sistémico'},
    category: {'pt': 'Respiratórios', 'es': 'Respiratorios'},
    route: 'VO',
    doseType: 'weight',
    fixedDose: {
      'pt': '0,5–1 mg/kg/dia VO (máx. 40–60 mg/dia). Exacerbação asma/DPOC: 30–40 mg/dia por 5–7 dias. Reduzir gradualmente se uso >2 semanas.',
      'es': '0,5–1 mg/kg/día VO (máx. 40–60 mg/día). Exacerbación asma/EPOC: 30–40 mg/día por 5–7 días.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário (metabolismo hepático).',
      'es': 'Sin ajuste necesario (metabolismo hepático).',
    },
    elderlyAlert: {
      'pt': 'Risco osteoporose, hiperglicemia, HTA, imunossupressão. Usar menor dose/tempo possível. Suplementar Ca²⁺ 1000 mg + vit. D 800 UI/dia.',
      'es': 'Riesgo osteoporosis, hiperglucemia, HTA, inmunosupresión. Suplementar Ca²⁺ y vit. D.',
    },
    mechanism: {
      'pt': 'Liga receptores citoplasmáticos → ↓ transcrição citocinas pró-inflamatórias (IL-1, IL-6, TNF-α) → ↓ inflamação, ↓ permeabilidade vascular.',
      'es': 'Liga receptores citoplasmáticos → ↓ transcripción citocinas proinflamatorias → ↓ inflamación.',
    },
    warning: {
      'pt': 'Contraindicado: infecção fúngica sistêmica. Cautela: DM (hiperglicemia), úlcera péptica, osteoporose. Suspensão abrupta (>2 semanas) → crise adrenal.',
      'es': 'Contraindicado: infección fúngica sistémica. Cautela: DM, úlcera péptica, osteoporosis. Suspensión abrupta → crisis adrenal.',
    },
    adverse: {
      'pt': ['Hiperglicemia', 'HTA', 'Retenção Na⁺/H₂O', 'Hipocalemia', 'Osteoporose (uso crônico)', 'Imunossupressão', 'Síndrome Cushing (uso prolongado)', 'Miopatia', 'Catarata'],
      'es': ['Hiperglucemia', 'HTA', 'Retención Na⁺/H₂O', 'Hipopotasemia', 'Osteoporosis', 'Inmunosupresión', 'Síndrome Cushing', 'Miopatía'],
    },
  ),

  DrugModel(
    id: 'montelucaste',
    name: 'Montelucaste',
    className: {'pt': 'Antagonista leucotrienos', 'es': 'Antagonista leucotrienos'},
    category: {'pt': 'Respiratórios', 'es': 'Respiratorios'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': '10 mg VO 1x/dia (à noite). Crianças 6–14 anos: 5 mg/dia. Controle asma leve-moderada persistente.',
      'es': '10 mg VO 1x/día (por la noche). Niños 6–14 años: 5 mg/día. Control asma leve-moderada.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário.',
      'es': 'Sin ajuste necesario.',
    },
    elderlyAlert: {
      'pt': 'Dose padrão. Raros efeitos neuropsiquiátricos (agitação, ansiedade, depressão, ideação suicida 1:10.000). Descontinuar se alterações comportamentais.',
      'es': 'Dosis estándar. Raros efectos neuropsiquiátricos (agitación, ansiedad, depresión). Descontinuar si cambios.',
    },
    mechanism: {
      'pt': 'Antagonista competitivo receptor cisteinil-leucotrieno CysLT1 → ↓ broncoconstrição, ↓ inflamação eosinofílica, ↓ permeabilidade vascular.',
      'es': 'Antagonista receptor cisteinil-leucotrieno CysLT1 → ↓ broncoconstricción, ↓ inflamación eosinofílica.',
    },
    warning: {
      'pt': 'NÃO usar para crise aguda asma (uso profilático). Alertas FDA: efeitos neuropsiquiátricos (depressão, ideação suicida 1:10.000). Síndrome Churg-Strauss (raro, redução corticoide).',
      'es': 'NO usar para crisis aguda. Alertas FDA: efectos neuropsiquiátricos. Síndrome Churg-Strauss (raro).',
    },
    adverse: {
      'pt': ['Cefaleia (18%)', 'Dor abdominal', 'Dispepsia', 'Fadiga', 'Efeitos neuropsiquiátricos (agitação, ansiedade, depressão <1%)', 'Elevação transaminases (raro)'],
      'es': ['Cefalea (18%)', 'Dolor abdominal', 'Dispepsia', 'Fatiga', 'Efectos neuropsiquiátricos (<1%)', 'Elevación transaminasas'],
    },
  ),

  // ═══════════════════════════════════════════════════════════════
  //  ANTIBIÓTICOS / ANTIMICROBIANOS
  // ═══════════════════════════════════════════════════════════════

  DrugModel(
    id: 'amoxicilina_clavulanato',
    name: 'Amoxicilina + Clavulanato',
    className: {'pt': 'Penicilina + inibidor de β-lactamase', 'es': 'Penicilina + inhibidor de β-lactamasa'},
    category: {'pt': 'Antibióticos', 'es': 'Antibióticos'},
    route: 'VO / IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Leve-moderado: 875/125 mg 12/12h ou 500/125 mg 8/8h VO. Grave/IV: 1,2 g (1000/200 mg) 8/8h IV. Duração: 5–10 dias conforme indicação.',
      'es': 'Leve-moderado: 875/125 mg 12/12 h VO. Grave/IV: 1,2 g (1000/200 mg) c/8 h IV.',
    },
    renalAlert: {
      'pt': 'ClCr 10–30 mL/min: 875/125 mg 12/12h. ClCr <10 mL/min: 500/125 mg 12/12h. Hemodiálise: dose extra após sessão.',
      'es': 'ClCr 10–30: 875/125 mg c/12 h. ClCr <10: 500/125 mg c/12 h.',
    },
    elderlyAlert: {
      'pt': 'Diarreia e colite por C. difficile mais frequentes. Monitorar função renal. Dose padrão salvo IR.',
      'es': 'Diarrea y colitis C. difficile más frecuentes. Monitorizar función renal.',
    },
    mechanism: {
      'pt': 'Amoxicilina inibe síntese de parede celular (PBP). Clavulanato inibe β-lactamases bacterianas, ampliando espectro.',
      'es': 'Amoxicilina inhibe síntesis de pared celular (PBP). Clavulanato inhibe β-lactamasas bacterianas.',
    },
    warning: {
      'pt': 'Hepatotoxicidade (clavulanato) — icterícia colestática, geralmente reversível. Risco aumentado em idosos e uso prolongado. Verificar alergia a penicilinas (reação cruzada 1–2% com cefalosporinas).',
      'es': 'Hepatotoxicidad (clavulanato) — ictericia colestática. Verificar alergia a penicilinas.',
    },
    adverse: {
      'pt': ['Diarreia (10–15%)', 'Náuseas/vômitos', 'Rash cutâneo', 'Hepatotoxicidade colestática (raro)', 'C. difficile'],
      'es': ['Diarrea (10–15%)', 'Náuseas/vómitos', 'Rash cutáneo', 'Hepatotoxicidad colestática (raro)', 'C. difficile'],
    },
  ),

  DrugModel(
    id: 'azitromicina',
    name: 'Azitromicina',
    className: {'pt': 'Macrolídeo – antibiótico', 'es': 'Macrólido – antibiótico'},
    category: {'pt': 'Antibióticos', 'es': 'Antibióticos'},
    route: 'VO / IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'PAC: 500 mg/dia por 3–5 dias. DST (Clamídia): 1 g dose única. IV: 500 mg/dia em 250 mL SF em 1h. Faringite/Sinusite: 500 mg D1, depois 250 mg D2–5.',
      'es': 'PAC: 500 mg/día por 3–5 días. ETS (Clamidia): 1 g dosis única. IV: 500 mg/día en 1 h.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário em IR leve-moderada. Usar com cautela em IR grave (dados limitados).',
      'es': 'Sin ajuste en IR leve-moderada. Precaución en IR grave.',
    },
    elderlyAlert: {
      'pt': 'Risco aumentado de prolongamento do QT. Revisar medicamentos concomitantes (sotalol, haloperidol). Monitorar ECG em cardiopatas.',
      'es': 'Mayor riesgo de prolongación QT. Revisar medicamentos concomitantes. ECG en cardíacos.',
    },
    mechanism: {
      'pt': 'Liga-se à subunidade 50S ribossomal → inibe translocação → bacteriostático (bactericida em altas concentrações). Longa meia-vida tecidual (~68h).',
      'es': 'Se une a subunidad 50S ribosomal → inhibe translocación → bacteriostático.',
    },
    warning: {
      'pt': 'Prolongamento do QT e risco de Torsades de Pointes — contraindicado com QTc >500 ms ou uso de outros QT-prolongadores. Hepatotoxicidade (icterícia colestática, raro). Interação com varfarina (↑ INR).',
      'es': 'Prolongación QT y riesgo de Torsades — contraindicado con QTc >500 ms. Interacción con warfarina (↑ INR).',
    },
    adverse: {
      'pt': ['Diarreia', 'Náuseas', 'Dor abdominal', 'Prolongamento QT', 'Hepatotoxicidade (raro)', 'Ototoxicidade (doses altas)'],
      'es': ['Diarrea', 'Náuseas', 'Dolor abdominal', 'Prolongación QT', 'Hepatotoxicidad (raro)'],
    },
  ),

  DrugModel(
    id: 'ciprofloxacino',
    name: 'Ciprofloxacino',
    className: {'pt': 'Fluorquinolona – antibiótico', 'es': 'Fluoroquinolona – antibiótico'},
    category: {'pt': 'Antibióticos', 'es': 'Antibióticos'},
    route: 'VO / IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'ITU complicada: 500 mg 12/12h VO ou 400 mg 12/12h IV. Infecções sistêmicas graves: 400 mg 8/8h IV. Antraz: 500 mg 12/12h VO por 60 dias. Duração: 7–14 dias conforme foco.',
      'es': 'ITU complicada: 500 mg c/12 h VO o 400 mg c/12 h IV. Infecciones sistémicas graves: 400 mg c/8 h IV.',
    },
    renalAlert: {
      'pt': 'ClCr 30–50: reduzir intervalo para 12–18h. ClCr <30: 250–500 mg 18/18h. HD: dose após cada sessão.',
      'es': 'ClCr 30–50: intervalo 12–18 h. ClCr <30: 250–500 mg c/18 h.',
    },
    elderlyAlert: {
      'pt': 'Maior risco de tendinopatia/ruptura de tendão (especialmente Aquiles). Prolongamento QT. Nefrotoxicidade aumentada.',
      'es': 'Mayor riesgo de tendinopatía/ruptura de tendón (Aquiles). Prolongación QT.',
    },
    mechanism: {
      'pt': 'Inibe DNA-girase (topoisomerase II) e topoisomerase IV → impede replicação e reparo do DNA bacteriano → bactericida.',
      'es': 'Inhibe DNA-girasa (topoisomerasa II) y topoisomerasa IV → bactericida.',
    },
    warning: {
      'pt': 'Ruptura de tendão (principalmente Aquiles) — risco elevado com corticosteroides, > 60 anos, IR, transplante. Prolongamento QT. Alucinações/convulsões (SNC). Fotossensibilidade. Interação com anticoagulantes (↑ INR) e antiácidos (reduzem absorção oral).',
      'es': 'Ruptura de tendón (Aquiles) — riesgo elevado con corticoides, >60 años. Prolongación QT. Fotosensibilidad.',
    },
    adverse: {
      'pt': ['Náuseas/diarreia', 'Tendinopatia/ruptura (0,5%)', 'Prolongamento QT', 'Convulsões (raro)', 'Fotossensibilidade', 'Elevação transaminases'],
      'es': ['Náuseas/diarrea', 'Tendinopatía/ruptura (0,5%)', 'Prolongación QT', 'Convulsiones (raro)', 'Fotosensibilidad'],
    },
  ),

  DrugModel(
    id: 'vancomicina',
    name: 'Vancomicina',
    className: {'pt': 'Glicopeptídeo – antibiótico', 'es': 'Glucopéptido – antibiótico'},
    category: {'pt': 'Antibióticos', 'es': 'Antibióticos'},
    route: 'IV / VO (colite C. diff)',
    doseType: 'weight',
    fixedDose: {
      'pt': '15–20 mg/kg IV 8/8–12/12h (adulto). Meta AUC/MIC 400–600 (guias ASHP 2020). Infusão: mínimo 60 min (≥1g em 60–90 min). VO para C. difficile: 125 mg 6/6h por 10 dias.',
      'es': '15–20 mg/kg IV c/8–12 h. Meta AUC/MIC 400–600. VO para C. difficile: 125 mg c/6 h × 10 días.',
    },
    renalAlert: {
      'pt': 'Ajuste obrigatório por nível sérico/AUC ou ClCr. ClCr 40–60: 1 g 12/12–24h. ClCr 20–40: 1 g 24/24–48h. Hemodiálise: variável — dosar nível pré-HD.',
      'es': 'Ajuste obligatorio por nivel sérico/AUC o ClCr. Hemodiálisis: dosificar según nivel.',
    },
    elderlyAlert: {
      'pt': 'Nefrotoxicidade aumentada — monitorar creatinina 2–3x/semana. Ototoxicidade (nível >80 mg/L). Ajustar frequentemente pela função renal.',
      'es': 'Nefrotoxicidad aumentada. Monitorizar creatinina 2–3×/semana. Ototoxicidad (nivel >80 mg/L).',
    },
    mechanism: {
      'pt': 'Liga-se ao D-Ala-D-Ala do peptidoglicano → inibe transpeptidação e transglicosilação → bactericida. Sem ação em gram-negativos (parede externa).',
      'es': 'Se une al D-Ala-D-Ala del peptidoglucano → inhibe transpeptidación → bactericida.',
    },
    warning: {
      'pt': 'Síndrome do Homem Vermelho (infusão rápida <60 min) — flushing, eritema, hipotensão; tratar com anti-histamínico e reduzir velocidade. Nefrotoxicidade dose-dependente. Ototoxicidade (reversível ou permanente).',
      'es': 'Síndrome del Hombre Rojo (infusión rápida). Nefrotoxicidad dosis-dependiente. Ototoxicidad.',
    },
    adverse: {
      'pt': ['Síndrome do Homem Vermelho', 'Nefrotoxicidade (5–7%)', 'Ototoxicidade', 'Flebite', 'Neutropenia (uso prolongado)', 'Trombocitopenia'],
      'es': ['Síndrome del Hombre Rojo', 'Nefrotoxicidad (5–7%)', 'Ototoxicidad', 'Flebitis', 'Neutropenia (uso prolongado)'],
    },
  ),

  DrugModel(
    id: 'meropenem',
    name: 'Meropenem',
    className: {'pt': 'Carbapenêmico – antibiótico', 'es': 'Carbapenémico – antibiótico'},
    category: {'pt': 'Antibióticos', 'es': 'Antibióticos'},
    route: 'IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Infecções moderadas: 1 g IV 8/8h. Meningite/infecções graves: 2 g IV 8/8h. Infusão estendida: 1–2 g IV em 3h 8/8h (otimiza PK/PD para MIC elevado). Duração: 7–14 dias.',
      'es': 'Infecciones moderadas: 1 g IV c/8 h. Meningitis/graves: 2 g IV c/8 h. Infusión extendida: 1–2 g en 3 h c/8 h.',
    },
    renalAlert: {
      'pt': 'ClCr 26–50: 1 g 12/12h. ClCr 10–25: 500 mg 12/12h. ClCr <10/HD: 500 mg 24/24h (dose após HD). TRRC: 1 g 12/12h.',
      'es': 'ClCr 26–50: 1 g c/12 h. ClCr 10–25: 500 mg c/12 h. ClCr <10/HD: 500 mg c/24 h.',
    },
    elderlyAlert: {
      'pt': 'Reduzir dose proporcionalmente à ClCr. Risco aumentado de convulsões em IR e dose excessiva. Monitorar função renal.',
      'es': 'Reducir dosis según ClCr. Mayor riesgo de convulsiones en IR.',
    },
    mechanism: {
      'pt': 'Liga-se às PBPs (proteínas ligantes de penicilinas) da parede bacteriana → inibe síntese de peptidoglicano → bactericida de amplo espectro (gram+, gram-, anaeróbios). Resistente a maioria das β-lactamases exceto MBL.',
      'es': 'Se une a PBPs → inhibe síntesis de peptidoglucano → bactericida de amplio espectro.',
    },
    warning: {
      'pt': 'Convulsões (especialmente IR, dose excessiva, meningite prévia). Seleciona KPC/MBL se uso indiscriminado. Não misturar com outras drogas na mesma linha. Clostridium difficile.',
      'es': 'Convulsiones (IR, dosis excesiva). Selecciona KPC/MBL. C. difficile.',
    },
    adverse: {
      'pt': ['Diarreia', 'Náuseas/vômitos', 'Convulsões (1–3% com IR)', 'Elevação transaminases', 'Trombocitose', 'C. difficile'],
      'es': ['Diarrea', 'Náuseas/vómitos', 'Convulsiones (1–3% con IR)', 'Elevación transaminasas', 'C. difficile'],
    },
  ),

  DrugModel(
    id: 'metronidazol',
    name: 'Metronidazol',
    className: {'pt': 'Nitroimidazol – antibiótico / antiparasitário', 'es': 'Nitroimidazol – antibiótico / antiparasitario'},
    category: {'pt': 'Antibióticos', 'es': 'Antibióticos'},
    route: 'VO / IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Infecções anaeróbias: 500 mg 8/8h VO ou IV. Vaginose bacteriana: 500 mg 12/12h × 7d VO. Tricomoníase: 2 g dose única. C. difficile leve-mod: 500 mg 8/8h VO × 10–14d. IV: 500 mg em 100 mL em 30 min.',
      'es': 'Infecciones anaerobias: 500 mg c/8 h VO o IV. Vaginosis: 500 mg c/12 h × 7d. Tricomoniasis: 2 g dosis única.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário em IR leve-moderada. Em IR grave e HD, metabólitos podem acumular (hepatotóxico/neurotóxico); usar com cautela.',
      'es': 'Sin ajuste en IR leve-moderada. En IR grave y HD, metabolitos pueden acumularse.',
    },
    elderlyAlert: {
      'pt': 'Risco de neuropatia periférica com uso prolongado. Encefalopatia (raro). Monitorar sintomas neurológicos.',
      'es': 'Riesgo de neuropatía periférica con uso prolongado. Encefalopatía (raro).',
    },
    mechanism: {
      'pt': 'Produto nitroso após redução intracelular em anaeróbios/protozoários → dano ao DNA → bactericida seletivo para anaeróbios.',
      'es': 'Producto nitroso tras reducción intracelular → daño al DNA → bactericida selectivo para anaerobios.',
    },
    warning: {
      'pt': 'Efeito antabuse com álcool (vômitos intensos, flushing) — proibir álcool e xaropes alcoólicos. Neuropatia periférica com uso >10 dias. Encefalopatia cerebelar (rara). Potencial carcinogênico em altas doses prolongadas (relevância clínica incerta).',
      'es': 'Efecto antabuse con alcohol. Neuropatía periférica con uso >10 días. Evitar alcohol.',
    },
    adverse: {
      'pt': ['Náuseas/sabor metálico', 'Neuropatia periférica (prolongado)', 'Efeito antabuse (álcool)', 'Encefalopatia cerebelar (raro)', 'Leucopenia (raro)', 'Urina escurecida'],
      'es': ['Náuseas/sabor metálico', 'Neuropatía periférica', 'Efecto antabuse (alcohol)', 'Encefalopatía cerebelar (raro)'],
    },
  ),

  DrugModel(
    id: 'fluconazol',
    name: 'Fluconazol',
    className: {'pt': 'Antifúngico triazólico', 'es': 'Antifúngico triazólico'},
    category: {'pt': 'Antifúngicos', 'es': 'Antifúngicos'},
    route: 'VO / IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Candidíase oral/esofagiana: 100–200 mg/dia × 7–14d. Candidíase vaginal: 150 mg dose única. Candidemia (não-neutropênicos): 800 mg ataque + 400 mg/dia. Meningite criptocócica: 400–800 mg/dia manutenção.',
      'es': 'Candidiasis oral: 100–200 mg/día × 7–14d. Vaginal: 150 mg dosis única. Candidemia: 800 mg ataque + 400 mg/día.',
    },
    renalAlert: {
      'pt': 'ClCr <50 mL/min: reduzir 50% da dose. Hemodiálise: 100% da dose habitual após sessão (dose única diária).',
      'es': 'ClCr <50: reducir 50% de la dosis. Hemodiálisis: 100% tras la sesión.',
    },
    elderlyAlert: {
      'pt': 'Múltiplas interações medicamentosas (CYP2C9, CYP3A4). Revisar polifarmácia. Prolongamento QT com azóis + amiodarona/quinolonas.',
      'es': 'Múltiples interacciones medicamentosas (CYP2C9, CYP3A4). Prolongación QT.',
    },
    mechanism: {
      'pt': 'Inibe CYP51 (lanosterol 14α-desmetilase) → ↓ ergosterol → alteração da membrana fúngica → fungistático (fungicida em altas doses).',
      'es': 'Inhibe CYP51 (lanosterol 14α-desmetilasa) → ↓ ergosterol → fungistático.',
    },
    warning: {
      'pt': 'Múltiplas interações via CYP2C9 e CYP3A4 (varfarina ↑, sirolimo ↑, ciclosporina ↑, estatinas ↑, benzodiazepínicos ↑). Prolongamento QT com amiodarona. Hepatotoxicidade (raro).',
      'es': 'Múltiples interacciones CYP2C9/3A4. Prolongación QT con amiodarona. Hepatotoxicidad (raro).',
    },
    adverse: {
      'pt': ['Náuseas/dor abdominal', 'Elevação transaminases', 'Prolongamento QT', 'Rash (raro)', 'Hepatotoxicidade (raro)', 'Alopecia (uso prolongado)'],
      'es': ['Náuseas/dolor abdominal', 'Elevación transaminasas', 'Prolongación QT', 'Rash (raro)', 'Hepatotoxicidad (raro)'],
    },
  ),

  // ═══════════════════════════════════════════════════════════════
  //  CARDIOVASCULARES
  // ═══════════════════════════════════════════════════════════════

  DrugModel(
    id: 'atenolol',
    name: 'Atenolol',
    className: {'pt': 'β-bloqueador cardioseletivo (β1)', 'es': 'β-bloqueador cardioselectivo (β1)'},
    category: {'pt': 'Cardiovasculares', 'es': 'Cardiovasculares'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'HAS/angina: 25–100 mg 1x/dia. FC alvo: 55–65 bpm repouso. Pós-IAM: 50–100 mg/dia. Arritmia: 25–100 mg/dia. Iniciar com 25 mg em idosos ou ICC.',
      'es': 'HAS/angina: 25–100 mg 1×/día. FC objetivo: 55–65 lpm. Post-IAM: 50–100 mg/día.',
    },
    renalAlert: {
      'pt': 'ClCr 15–35: máx. 50 mg/dia. ClCr <15 ou HD: 25 mg/dia ou 50 mg a cada 2 dias.',
      'es': 'ClCr 15–35: máx. 50 mg/día. ClCr <15 o HD: 25 mg/día.',
    },
    elderlyAlert: {
      'pt': 'Iniciar com 25 mg/dia. Risco de bradicardia, hipotensão postural e quedas. Pode mascarar hipoglicemia em diabéticos.',
      'es': 'Iniciar con 25 mg/día. Riesgo de bradicardia, hipotensión postural y caídas.',
    },
    mechanism: {
      'pt': 'Bloqueia seletivamente receptores β1-adrenérgicos → ↓ FC, ↓ contratilidade, ↓ condução AV, ↓ PA. Ação anti-isquêmica e antiarrítmica.',
      'es': 'Bloquea selectivamente receptores β1 → ↓ FC, ↓ contractilidad, ↓ conducción AV, ↓ PA.',
    },
    warning: {
      'pt': 'Contraindicado: BAV 2º/3º grau, bradicardia <50 bpm, choque cardiogênico, asma (relativo). Retirada abrupta pode precipitar angina/IAM. Mascaramento de hipoglicemia em diabéticos.',
      'es': 'Contraindicado: BAV 2°/3°, bradicardia <50 lpm, choque cardiogénico, asma (relativo). Retirada abrupta puede precipitar IAM.',
    },
    adverse: {
      'pt': ['Bradicardia', 'Fadiga/astenia', 'Extremidades frias', 'Broncoespasmo (asma)', 'Hipotensão', 'Depressão', 'Disfunção erétil'],
      'es': ['Bradicardia', 'Fatiga/astenia', 'Extremidades frías', 'Broncoespasmo (asma)', 'Hipotensión', 'Disfunción eréctil'],
    },
  ),

  DrugModel(
    id: 'losartana',
    name: 'Losartana',
    className: {'pt': 'Antagonista do receptor AT1 (ARA II)', 'es': 'Antagonista del receptor AT1 (ARA II)'},
    category: {'pt': 'Cardiovasculares', 'es': 'Cardiovasculares'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'HAS: 50 mg 1x/dia (pode aumentar para 100 mg/dia). Nefropatia diabética: 50–100 mg/dia. ICC (intolerância a IECA): 25 mg 2x/dia. Iniciar 25 mg em idosos.',
      'es': 'HAS: 50 mg 1×/día (hasta 100 mg/día). Nefropatía diabética: 50–100 mg/día.',
    },
    renalAlert: {
      'pt': 'Monitorar K+ e creatinina 1–2 semanas após início ou ajuste. Redução do fluxo renal pode piorar função em estenose de artéria renal bilateral ou rim único.',
      'es': 'Monitorizar K+ y creatinina 1–2 semanas tras inicio. Contraindicado en estenosis bilateral de arteria renal.',
    },
    elderlyAlert: {
      'pt': 'Risco de hiperpotassemia com IECA/diuréticos poupadores/suplementos de K+. Hipotensão na 1ª dose em idosos desidratados.',
      'es': 'Riesgo de hiperpotasemia con IECA/diuréticos ahorradores/suplementos K+. Hipotensión 1ª dosis.',
    },
    mechanism: {
      'pt': 'Bloqueia receptor AT1 da angiotensina II → vasodilatação, ↓ aldosterona, ↓ PA, proteção renal e cardíaca. Não aumenta bradicinina (sem tosse).',
      'es': 'Bloquea receptor AT1 de angiotensina II → vasodilatación, ↓ aldosterona. No aumenta bradicinina (sin tos).',
    },
    warning: {
      'pt': 'Contraindicado na gravidez (2º e 3º trimestres — teratogênico grave). Hiperpotassemia em combinação com IECA, diuréticos poupadores, suplementos de K+. Monitorar função renal e K+ periodicamente.',
      'es': 'Contraindicado en embarazo (2°/3° trimestre — teratogénico). Hiperpotasemia con IECA/diuréticos ahorradores.',
    },
    adverse: {
      'pt': ['Hiperpotassemia', 'Tontura/hipotensão', 'Insuficiência renal (estenose renal bilateral)', 'Angioedema (raro — menos que IECA)', 'Astenia'],
      'es': ['Hiperpotasemia', 'Mareo/hipotensión', 'Insuficiencia renal', 'Angioedema (raro)', 'Astenia'],
    },
  ),

  DrugModel(
    id: 'amlodipino',
    name: 'Amlodipino',
    className: {'pt': 'Bloqueador de canal de cálcio (di-hidropiridínico)', 'es': 'Bloqueador de canal de calcio (dihidropiridínico)'},
    category: {'pt': 'Cardiovasculares', 'es': 'Cardiovasculares'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'HAS/angina: 5 mg/dia. Pode aumentar para 10 mg/dia após 7–14 dias se necessário. Iniciar com 2,5 mg em idosos, hepatopatas ou ICC.',
      'es': 'HAS/angina: 5 mg/día. Puede aumentarse a 10 mg/día. Iniciar 2,5 mg en ancianos/hepatópatas.',
    },
    renalAlert: {
      'pt': 'Sem ajuste em IR (metabolismo hepático). Seguro em hemodiálise.',
      'es': 'Sin ajuste en IR (metabolismo hepático). Seguro en hemodiálisis.',
    },
    elderlyAlert: {
      'pt': 'Edema periférico frequente (vasodilatação arteriolar). Hipotensão postural. Iniciar 2,5 mg/dia. Taquicardia reflexa geralmente mínima (longa meia-vida).',
      'es': 'Edema periférico frecuente. Hipotensión postural. Iniciar 2,5 mg/día.',
    },
    mechanism: {
      'pt': 'Bloqueia canais L de cálcio nas células musculares lisas vasculares → vasodilatação arterial → ↓ resistência vascular → ↓ PA. Longa meia-vida (~35–50h).',
      'es': 'Bloquea canales L de calcio vasculares → vasodilatación arterial → ↓ resistencia vascular → ↓ PA.',
    },
    warning: {
      'pt': 'Edema periférico (não indica sobrecarga hídrica — é vasodilatação local). Rubor facial. Interação com inibidores de CYP3A4 (cetoconazol, claritromicina) pode elevar nível sérico. Pode piorar angina no início do tratamento (vasoespástica).',
      'es': 'Edema periférico (vasodilatación local, no sobrecarga). Rubor facial. Interacción CYP3A4.',
    },
    adverse: {
      'pt': ['Edema periférico (10–15%)', 'Cefaleia', 'Rubor facial', 'Palpitações', 'Hipotensão', 'Hiperplasia gengival (raro)'],
      'es': ['Edema periférico (10–15%)', 'Cefalea', 'Rubor facial', 'Palpitaciones', 'Hipotensión'],
    },
  ),

  DrugModel(
    id: 'espironolactona',
    name: 'Espironolactona',
    className: {'pt': 'Diurético poupador de potássio – antagonista de aldosterona', 'es': 'Diurético ahorrador de potasio – antagonista de aldosterona'},
    category: {'pt': 'Cardiovasculares', 'es': 'Cardiovasculares'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'ICC com FE reduzida: 25 mg/dia (titular até 50 mg/dia). Hiperaldosteronismo primário: 100–400 mg/dia. Ascite por cirrose: 100 mg/dia (até 400 mg). HAS resistente: 25–100 mg/dia.',
      'es': 'ICC FE reducida: 25 mg/día (hasta 50 mg/día). Hiperaldosteronismo: 100–400 mg/día. Ascitis: 100 mg/día.',
    },
    renalAlert: {
      'pt': 'Contraindicada se K+ >5,0 mEq/L ou ClCr <30 mL/min. Risco de hiperpotassemia grave. Monitorar K+ e creatinina frequentemente.',
      'es': 'Contraindicada si K+ >5,0 mEq/L o ClCr <30 mL/min. Riesgo de hiperpotasemia grave.',
    },
    elderlyAlert: {
      'pt': 'Hiperpotassemia mais frequente (menor reserva renal). Ginecomastia dolorosa em homens. Iniciar 12,5–25 mg. Monitorar eletrólitos e função renal.',
      'es': 'Hiperpotasemia más frecuente. Ginecomastia dolorosa en hombres. Iniciar 12,5–25 mg.',
    },
    mechanism: {
      'pt': 'Antagonista competitivo da aldosterona no TCD/TC → ↓ reabsorção de Na+, ↓ excreção de K+ → diurético poupador de K+. Efeito hemodinâmico e anti-fibrótico na ICC.',
      'es': 'Antagonista competitivo de aldosterona → ↓ reabsorción Na+, ↓ excreción K+. Efecto anti-fibrótico en ICC.',
    },
    warning: {
      'pt': 'Hiperpotassemia potencialmente fatal — monitorar K+ e creatinina 1 semana após início e mensalmente. Ginecomastia em homens (até 10%). Evitar associação com IECA + ARA II (tripla bloqueio).',
      'es': 'Hiperpotasemia potencialmente fatal — monitorizar K+ y creatinina. Ginecomastia en hombres (hasta 10%).',
    },
    adverse: {
      'pt': ['Hiperpotassemia', 'Ginecomastia/mastalgia (homens)', 'Irregularidade menstrual', 'Disfunção erétil', 'Câimbras', 'Confusão (idosos)'],
      'es': ['Hiperpotasemia', 'Ginecomastia/mastalgia (hombres)', 'Irregularidad menstrual', 'Disfunción eréctil'],
    },
  ),

  DrugModel(
    id: 'digoxina',
    name: 'Digoxina',
    className: {'pt': 'Glicosídeo cardíaco – inotrópico positivo', 'es': 'Glucósido cardíaco – inotrópico positivo'},
    category: {'pt': 'Cardiovasculares', 'es': 'Cardiovasculares'},
    route: 'VO / IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'FA com resposta ventricular rápida: 0,125–0,25 mg/dia VO. Nível sérico alvo: 0,5–0,9 ng/mL (ICC) ou 0,8–2,0 ng/mL (FA). Ataque IV: 0,25–0,5 mg IV lento em 20 min (monitoração ECG).',
      'es': 'FA con respuesta ventricular rápida: 0,125–0,25 mg/día VO. Nivel sérico: 0,5–0,9 ng/mL (ICC). IV ataque: 0,25–0,5 mg en 20 min.',
    },
    renalAlert: {
      'pt': 'Eliminação 70% renal — ajuste obrigatório. ClCr 10–50: 0,0625–0,125 mg/dia. ClCr <10 ou HD: 0,0625 mg/dia ou dias alternados. Dosar nível sérico frequentemente.',
      'es': 'Eliminación 70% renal. ClCr 10–50: 0,0625–0,125 mg/día. ClCr <10/HD: 0,0625 mg/día.',
    },
    elderlyAlert: {
      'pt': 'Índice terapêutico estreito. Nível tóxico em idosos mesmo com doses baixas (↓ ClCr, ↓ massa muscular, ↓ volume de distribuição). Monitorar nível sérico mensalmente. Hipocalemia amplifica toxicidade.',
      'es': 'Índice terapéutico estrecho. Niveles tóxicos con dosis bajas en ancianos. Monitorizar nivel sérico mensualmente.',
    },
    mechanism: {
      'pt': 'Inibe Na+/K+-ATPase → ↑ Ca²+ intracelular → ↑ contratilidade. Aumenta tônus vagal (↓ FC, ↓ condução AV) — útil na FA.',
      'es': 'Inhibe Na+/K+-ATPasa → ↑ Ca²+ intracelular → ↑ contractilidad. Aumenta tono vagal → ↓ FC en FA.',
    },
    warning: {
      'pt': 'Janela terapêutica estreita. Intoxicação: náuseas, visão amarelada, arritmias (BAV, TV). Hipocalemia e hipomagnessemia aumentam toxicidade. Antídoto: anticorpos anti-digoxina (Digibind). Múltiplas interações (amiodarona, verapamil, quinidina elevam nível).',
      'es': 'Ventana terapéutica estrecha. Intoxicación: náuseas, visión amarilla, arritmias. Antídoto: anticuerpos anti-digoxina (Digibind).',
    },
    adverse: {
      'pt': ['Intoxicação digitálica (náuseas, visão amarelada)', 'Bradiarritmias', 'BAV 2º/3º grau', 'TV/FV (tóxico)', 'Ginecomastia (raro)', 'Anorexia'],
      'es': ['Intoxicación digitálica (náuseas, visión amarilla)', 'Bradiarritmias', 'BAV 2°/3°', 'TV/FV (tóxico)', 'Ginecomastia (raro)'],
    },
  ),

  DrugModel(
    id: 'nitroglicerina',
    name: 'Nitroglicerina',
    className: {'pt': 'Nitrato orgânico – vasodilatador', 'es': 'Nitrato orgánico – vasodilatador'},
    category: {'pt': 'Cardiovasculares', 'es': 'Cardiovasculares'},
    route: 'SL / IV / Transdérmico',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Angina (SL): 0,3–0,6 mg SL; repetir a cada 5 min, máx. 3 doses. IV (SCA/EAP): iniciar 5–10 mcg/min; titular 5–10 mcg/min a cada 3–5 min até alívio sintomático ou PAS <90 mmHg. Patch: 0,2–0,8 mg/h (período livre 10–12h para evitar tolerância).',
      'es': 'Angina (SL): 0,3–0,6 mg SL c/5 min, máx. 3 dosis. IV (SCA/EAP): 5–10 mcg/min, titular. Parche: 0,2–0,8 mg/h.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário. Hipotensão pode reduzir perfusão renal em pacientes com IR.',
      'es': 'Sin ajuste necesario. Hipotensión puede reducir perfusión renal.',
    },
    elderlyAlert: {
      'pt': 'Hipotensão severa — monitorar PA continuamente. Cefaleia intensa frequente. Tolerância com uso contínuo. Síncope ortostática.',
      'es': 'Hipotensión severa — monitorizar PA continuamente. Cefalea intensa frecuente. Síncope ortostática.',
    },
    mechanism: {
      'pt': 'Libera NO (óxido nítrico) → ativa guanilil-ciclase → ↑ GMPc → relaxamento do músculo liso vascular → vasodilatação predominantemente venosa (↓ pré-carga) e arteriolar coronariana.',
      'es': 'Libera NO → activa guanilil-ciclasa → ↑ GMPc → vasodilatación venosa (↓ precarga) y coronaria.',
    },
    warning: {
      'pt': 'Hipotensão grave — PAS <90 mmHg suspender. Contraindicada com inibidores de PDE5 (sildenafil, tadalafil) — hipotensão fatal. Tolerância desenvolve em 24–48h de infusão contínua (período livre obrigatório). Cefaleia intensa.',
      'es': 'Hipotensión grave — PAS <90 mmHg suspender. Contraindicada con inhibidores PDE5 (sildenafil) — hipotensión fatal. Tolerancia en 24–48 h.',
    },
    adverse: {
      'pt': ['Cefaleia (50–60%)', 'Hipotensão', 'Taquicardia reflexa', 'Tolerância farmacológica', 'Rubor facial', 'Síncope'],
      'es': ['Cefalea (50–60%)', 'Hipotensión', 'Taquicardia refleja', 'Tolerancia farmacológica', 'Rubor facial'],
    },
  ),

  // ═══════════════════════════════════════════════════════════════
  //  NEUROLÓGICOS / PSIQUIÁTRICOS
  // ═══════════════════════════════════════════════════════════════

  DrugModel(
    id: 'haloperidol',
    name: 'Haloperidol',
    className: {'pt': 'Antipsicótico típico – butirofenonas', 'es': 'Antipsicótico típico – butirofenonas'},
    category: {'pt': 'Neurológicos / Psiquiátricos', 'es': 'Neurológicos / Psiquiátricos'},
    route: 'VO / IM / IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Psicose aguda: 5–10 mg IM/IV (repetir a cada 30–60 min; máx. 30 mg/24h). Agitação (delírio): 0,5–2 mg IV lento; titular. Manutenção VO: 0,5–5 mg 12/12h ou 8/8h. Idosos: 0,25–1 mg IM/IV; máx. 3,5 mg/24h.',
      'es': 'Psicosis aguda: 5–10 mg IM/IV c/30–60 min; máx. 30 mg/24 h. Agitación: 0,5–2 mg IV lento. Mantenimiento VO: 0,5–5 mg c/12 h.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário. Usar com cautela em IR grave (metabólitos podem acumular).',
      'es': 'Sin ajuste necesario. Precaución en IR grave.',
    },
    elderlyAlert: {
      'pt': 'Risco alto de síndrome extrapiramidal, sedação excessiva, quedas, hipotensão ortostática. Prolongamento QT. Usar menor dose possível (0,25–1 mg). Evitar em demência (↑ mortalidade).',
      'es': 'Alto riesgo de síndrome extrapiramidal, sedación, caídas, hipotensión ortostática, QT prolongado. Evitar en demencia (↑ mortalidad).',
    },
    mechanism: {
      'pt': 'Antagonista D2 no sistema mesolímbico e mesocortical → ↓ dopamina → efeito antipsicótico. Também bloqueia receptores α1, H1, muscarínicos.',
      'es': 'Antagonista D2 en sistema mesolímbico → ↓ dopamina → efecto antipsicótico.',
    },
    warning: {
      'pt': 'Síndrome maligna dos neurolépticos (hipertermia, rigidez, instabilidade autonômica, rabdomiólise — descontinuar imediatamente). Prolongamento QT → Torsades. Discinesia tardia com uso crônico. Evitar em Parkinson e corpos de Lewy.',
      'es': 'Síndrome maligno de los neurolépticos (hipertermia, rigidez — suspender). Prolongación QT → Torsades. Discinesia tardía crónica.',
    },
    adverse: {
      'pt': ['Distonia aguda', 'Acatisia', 'Parkinsonismo', 'Sedação', 'Hipotensão ortostática', 'Prolongamento QT', 'Discinesia tardia (crônico)', 'Hiperprolactinemia'],
      'es': ['Distonía aguda', 'Acatisia', 'Parkinsonismo', 'Sedación', 'Hipotensión ortostática', 'QT prolongado', 'Discinesia tardía'],
    },
  ),

  DrugModel(
    id: 'clonazepam',
    name: 'Clonazepam',
    className: {'pt': 'Benzodiazepínico antiepiléptico', 'es': 'Benzodiacepina antiepiléptica'},
    category: {'pt': 'Neurológicos / Psiquiátricos', 'es': 'Neurológicos / Psiquiátricos'},
    route: 'VO / IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Epilepsia: 0,5 mg 3x/dia inicial; titular até 20 mg/dia em adultos. Status epilepticus (IV): 0,015 mg/kg IV lento (1–2 mg adulto) — repetir se necessário. Pânico/ansiedade: 0,25–2 mg 2x/dia.',
      'es': 'Epilepsia: 0,5 mg 3×/día inicial; titular hasta 20 mg/día. Status epilepticus IV: 0,015 mg/kg IV lento. Pánico: 0,25–2 mg 2×/día.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário. Monitorar sedação excessiva em IR grave.',
      'es': 'Sin ajuste necesario. Monitorizar sedación excesiva en IR grave.',
    },
    elderlyAlert: {
      'pt': 'Alto risco de quedas, confusão, sedação excessiva e dependência. Evitar como primeira linha em idosos (Beers criteria). Usar menor dose por menor período possível.',
      'es': 'Alto riesgo de caídas, confusión, sedación y dependencia (criterios Beers). Usar menor dosis por menor tiempo posible.',
    },
    mechanism: {
      'pt': 'Potencializa GABA-A → ↑ frequência de abertura do canal Cl- → hiperpolarização neuronal → efeito anticonvulsivante, ansiolítico, miorrelaxante e hipnótico.',
      'es': 'Potencia GABA-A → ↑ frecuencia apertura canal Cl- → hiperpolarización neuronal → anticonvulsivante, ansiolítico.',
    },
    warning: {
      'pt': 'Dependência física e síndrome de abstinência grave (convulsões, delirium). Nunca interromper abruptamente após uso prolongado. Risco de abuso. Depressão respiratória em associação com opioides, álcool ou barbitúricos. Antídoto: flumazenil.',
      'es': 'Dependencia física y síndrome de abstinencia (convulsiones, delirium). Nunca suspender abruptamente. Antídoto: flumazenil.',
    },
    adverse: {
      'pt': ['Sedação', 'Ataxia', 'Confusão/amnésia', 'Depressão respiratória', 'Dependência/abstinência', 'Tolerância', 'Hipersalivação'],
      'es': ['Sedación', 'Ataxia', 'Confusión/amnesia', 'Depresión respiratoria', 'Dependencia/abstinencia'],
    },
  ),

  DrugModel(
    id: 'amitriptilina',
    name: 'Amitriptilina',
    className: {'pt': 'Antidepressivo tricíclico (ADT)', 'es': 'Antidepresivo tricíclico (ADT)'},
    category: {'pt': 'Neurológicos / Psiquiátricos', 'es': 'Neurológicos / Psiquiátricos'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Depressão: 25–75 mg/dia inicial (à noite); titular até 150–300 mg/dia. Dor neuropática/profilaxia migrânea: 10–75 mg/dia (doses menores são eficazes). Enurese: 10–25 mg à noite.',
      'es': 'Depresión: 25–75 mg/día (por la noche); hasta 150–300 mg/día. Dolor neuropático: 10–75 mg/día.',
    },
    renalAlert: {
      'pt': 'Sem ajuste em IR leve-moderada. Usar com cautela em IR grave (metabólitos ativos).',
      'es': 'Sin ajuste en IR leve-moderada. Precaución en IR grave.',
    },
    elderlyAlert: {
      'pt': 'Efeitos anticolinérgicos pronunciados: confusão, retenção urinária, constipação, visão turva. Hipotensão ortostática grave (quedas). Cardiotoxicidade (arritmias, QT↑). Evitar em idosos (Beers criteria). Preferir nortriptilina se ADT necessário.',
      'es': 'Efectos anticolinérgicos pronunciados: confusión, retención urinaria, constipación. Hipotensión ortostática grave. Evitar en ancianos (criterios Beers).',
    },
    mechanism: {
      'pt': 'Inibe recaptação de noradrenalina e serotonina (NET >> SERT). Também bloqueia receptores H1, muscarínicos, α1 e canais de Na+ cardíacos.',
      'es': 'Inhibe recaptación de noradrenalina y serotonina. Bloquea receptores H1, muscarínicos, α1.',
    },
    warning: {
      'pt': 'Cardiotoxicidade em superdose (↑ QRS, arritmias, morte). Janela terapêutica estreita em overdose. Evitar com IMAOs (intervalo 14 dias). Rebaixamento do limiar convulsivo. Síndrome serotoninérgica com ISSRs.',
      'es': 'Cardiotoxicidad en sobredosis (↑ QRS, arritmias, muerte). Ventana estrecha. Evitar con IMAOs. Síndrome serotoninérgico con ISRSs.',
    },
    adverse: {
      'pt': ['Sedação/sonolência', 'Boca seca', 'Constipação', 'Retenção urinária', 'Visão turva', 'Hipotensão ortostática', 'Taquicardia', 'Ganho de peso', 'QT prolongado'],
      'es': ['Sedación/somnolencia', 'Boca seca', 'Constipación', 'Retención urinaria', 'Hipotensión ortostática', 'Taquicardia', 'QT prolongado'],
    },
  ),

  DrugModel(
    id: 'sertralina',
    name: 'Sertralina',
    className: {'pt': 'Inibidor seletivo da recaptação de serotonina (ISRS)', 'es': 'Inhibidor selectivo de la recaptación de serotonina (ISRS)'},
    category: {'pt': 'Neurológicos / Psiquiátricos', 'es': 'Neurológicos / Psiquiátricos'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Depressão/TAG: 50 mg/dia inicial; titular 25–50 mg a cada 1–2 semanas; máx. 200 mg/dia. TOC: até 200 mg/dia. TEPT/pânico: 25 mg/dia inicial, titular para 50–200 mg/dia.',
      'es': 'Depresión/TAG: 50 mg/día inicial; hasta 200 mg/día. TOC: hasta 200 mg/día. TEPT: iniciar 25 mg/día.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário. Usar com cautela em IR grave (dados limitados).',
      'es': 'Sin ajuste necesario. Precaución en IR grave.',
    },
    elderlyAlert: {
      'pt': 'Hiponatremia/SIADH (especialmente com diuréticos tiazídicos). Risco de sangramento GI com AINEs/anticoagulantes. Menor tolerabilidade em idosos frágeis. Titulação lenta.',
      'es': 'Hiponatremia/SIADH (especialmente con tiazidas). Riesgo de sangrado GI con AINEs/anticoagulantes. Titulación lenta en ancianos.',
    },
    mechanism: {
      'pt': 'Inibe transportador SERT → ↑ serotonina sináptica → adaptação de receptores 5-HT1A (onset terapêutico 2–4 semanas). Efeito ansiolítico, antidepressivo e antiobsessivo.',
      'es': 'Inhibe SERT → ↑ serotonina sináptica. Onset terapéutico 2–4 semanas.',
    },
    warning: {
      'pt': 'Síndrome serotoninérgica (com tramadol, triptanos, IMAOs, linezolida — evitar). Hiponatremia (SIADH). Sangramento (↓ serotonina plaquetária). Ideação suicida em < 25 anos (primeiras semanas). Síndrome de descontinuação (não interromper abruptamente).',
      'es': 'Síndrome serotoninérgico (con tramadol, triptanos, IMAOs). Hiponatremia (SIADH). Sangrado. Ideación suicida en <25 años.',
    },
    adverse: {
      'pt': ['Náuseas (início)', 'Insônia ou hipersonia', 'Disfunção sexual', 'Cefaleia', 'Diarreia', 'Inquietação (início)', 'Hiponatremia', 'Síndrome de descontinuação'],
      'es': ['Náuseas (inicio)', 'Insomnio', 'Disfunción sexual', 'Cefalea', 'Diarrea', 'Hiponatremia', 'Síndrome de discontinuación'],
    },
  ),

  // ═══════════════════════════════════════════════════════════════
  //  ENDÓCRINOS / METABÓLICOS
  // ═══════════════════════════════════════════════════════════════

  DrugModel(
    id: 'levotiroxina',
    name: 'Levotiroxina (T4)',
    className: {'pt': 'Hormônio tireoidiano sintético', 'es': 'Hormona tiroidea sintética'},
    category: {'pt': 'Endócrinos / Metabólicos', 'es': 'Endócrinos / Metabólicos'},
    route: 'VO / IV',
    doseType: 'weight',
    fixedDose: {
      'pt': 'Hipotireoidismo adulto: 1,6 mcg/kg/dia VO em jejum. Idosos/cardiopatas: iniciar 12,5–25 mcg/dia, titular lentamente. TSH alvo: 0,5–2,5 mUI/L (variável por condição). IV (mixedema): 200–400 mcg bolus + 50–100 mcg/dia.',
      'es': 'Hipotiroidismo adulto: 1,6 mcg/kg/día VO en ayunas. Ancianos/cardíacos: iniciar 12,5–25 mcg/día. IV (mixedema): 200–400 mcg bolo.',
    },
    renalAlert: {
      'pt': 'Sem ajuste em IR — metabolismo hepático. Hipotiroidismo pode reduzir débito cardíaco e perfusão renal.',
      'es': 'Sin ajuste en IR — metabolismo hepático.',
    },
    elderlyAlert: {
      'pt': 'Risco de fibrilação atrial, angina e ICC se titulação rápida. Iniciar SEMPRE com 12,5–25 mcg/dia em idosos cardiopatas. TSH alvo mais alto em idosos (0,5–4,0 mUI/L). Revisar dose regularmente.',
      'es': 'Riesgo de FA, angina e ICC si titulación rápida. Iniciar SIEMPRE con 12,5–25 mcg/día. TSH objetivo 0,5–4,0 mUI/L en ancianos.',
    },
    mechanism: {
      'pt': 'Pró-hormônio convertido a T3 ativo perifericamente → liga-se a receptores nucleares TRα/TRβ → regula expressão gênica → controla metabolismo basal, crescimento, sistema cardíaco, nervoso e muscular.',
      'es': 'Prehormona convertida a T3 activo → receptores nucleares TRα/TRβ → regula metabolismo basal, función cardíaca y nerviosa.',
    },
    warning: {
      'pt': 'Administrar 30–60 min antes do café da manhã (jejum). Separar 4h de carbonato de cálcio, antiácidos, colestiramina, ferro (↓ absorção). Hiperdosagem → taquicardia, perda de peso, FA, insônia.',
      'es': 'Administrar 30–60 min antes del desayuno (ayunas). Separar 4 h de calcio, antiácidos, colestiramina, hierro (↓ absorción).',
    },
    adverse: {
      'pt': ['Taquicardia/palpitações (supradose)', 'Fibrilação atrial', 'Angina (cardiopatas)', 'Insônia', 'Tremor', 'Perda de peso', 'Sudorese', 'Osteoporose (TSH suprimido)'],
      'es': ['Taquicardia/palpitaciones (sobredosis)', 'Fibrilación auricular', 'Angina (cardíacos)', 'Insomnio', 'Temblor', 'Pérdida de peso'],
    },
  ),

  DrugModel(
    id: 'metformina',
    name: 'Metformina',
    className: {'pt': 'Biguanida – antidiabético oral', 'es': 'Biguanida – antidiabético oral'},
    category: {'pt': 'Endócrinos / Metabólicos', 'es': 'Endócrinos / Metabólicos'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'DM2: 500 mg 2x/dia ou 850 mg 1x/dia (durante refeição); titular semana a semana. Máx. 2550 mg/dia (usual 1500–2000 mg/dia). XR: 500–2000 mg 1x/dia à noite.',
      'es': 'DM2: 500 mg 2×/día (con comida); titular semana a semana. Máx. 2550 mg/día. XR: 500–2000 mg 1×/noche.',
    },
    renalAlert: {
      'pt': 'ClCr ≥ 45: dose normal. ClCr 30–44: reduzir dose; máx. 1000 mg/dia — monitorar. ClCr <30: CONTRAINDICADA (risco de acidose lática). Suspender antes de contraste iodado se ClCr <60 e reintroduzir 48h depois.',
      'es': 'ClCr ≥ 45: dosis normal. ClCr 30–44: reducir; máx. 1000 mg/día. ClCr <30: CONTRAINDICADA (acidosis láctica). Suspender antes de contraste yodado.',
    },
    elderlyAlert: {
      'pt': 'Reavaliar dose com queda da ClCr (comum em idosos). Deficiência de vitamina B12 com uso prolongado (monitorar). Risco de acidose lática em desidratação, cirurgia, contraste.',
      'es': 'Reevaluar dosis con caída de ClCr. Deficiencia vitamina B12 con uso prolongado. Riesgo acidosis láctica en deshidratación/cirugía/contraste.',
    },
    mechanism: {
      'pt': 'Ativa AMPK → ↓ gliconeogênese hepática, ↑ captação periférica de glicose, ↓ absorção intestinal de glicose. Sem risco de hipoglicemia em monoterapia.',
      'es': 'Activa AMPK → ↓ gluconeogénesis hepática, ↑ captación periférica de glucosa. Sin hipoglucemia en monoterapia.',
    },
    warning: {
      'pt': 'Acidose lática (rara, mas fatal) — fatores de risco: IR, insuficiência hepática, insuficiência cardíaca descompensada, sepse, desidratação, alcoólicos, contraste iodado. Suspender em cirurgias/exames com contraste.',
      'es': 'Acidosis láctica (rara, pero fatal) — factores de riesgo: IR, IC descompensada, sepsis, deshidratación, contraste yodado.',
    },
    adverse: {
      'pt': ['Náuseas/diarreia (início — reduzir com alimento)', 'Sabor metálico', 'Déficit B12 (uso prolongado)', 'Acidose lática (raro)', 'Anorexia'],
      'es': ['Náuseas/diarrea (inicio)', 'Sabor metálico', 'Déficit B12 (uso prolongado)', 'Acidosis láctica (raro)'],
    },
  ),

  DrugModel(
    id: 'glibenclamida',
    name: 'Glibenclamida (Gliburida)',
    className: {'pt': 'Sulfonilureia – secretagogo de insulina', 'es': 'Sulfonilurea – secretagogo de insulina'},
    category: {'pt': 'Endócrinos / Metabólicos', 'es': 'Endócrinos / Metabólicos'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Iniciar 2,5–5 mg/dia com o café da manhã. Titular a cada 1–2 semanas. Máx. 20 mg/dia (10 mg 2x/dia). Monitorar glicemia em jejum e pós-prandial regularmente.',
      'es': 'Iniciar 2,5–5 mg/día con desayuno. Titular c/1–2 semanas. Máx. 20 mg/día.',
    },
    renalAlert: {
      'pt': 'EVITAR em ClCr <30 (metabólitos ativos acumulam → hipoglicemia prolongada). Preferir gliclazida ou glipizida em IR.',
      'es': 'EVITAR con ClCr <30 (metabolitos activos acumulan → hipoglucemia prolongada). Preferir gliclazida en IR.',
    },
    elderlyAlert: {
      'pt': 'Alto risco de hipoglicemia grave e prolongada em idosos (Beers criteria — evitar). Preferir sulfonilureia de ação curta (glipizida) ou IDPP-4/SGLT2. Risco de quedas por hipoglicemia.',
      'es': 'Alto riesgo de hipoglucemia grave en ancianos (criterios Beers — evitar). Preferir glipizida o IDPP-4/SGLT2.',
    },
    mechanism: {
      'pt': 'Liga-se aos canais K+-ATP das células β pancreáticas → despolarização → ↑ Ca²+ → liberação de insulina. Efeito dependente de células β funcionais.',
      'es': 'Se une a canales K+-ATP de células β → despolarización → ↑ Ca²+ → liberación de insulina.',
    },
    warning: {
      'pt': 'Hipoglicemia grave e prolongada (especialmente em idosos, insuficiência renal, jejum, álcool). Ganho de peso. Interações com sulfonamidas, fluconazol, fenofibrato (↑ hipoglicemia). Fotossensibilidade.',
      'es': 'Hipoglucemia grave y prolongada (ancianos, IR, ayuno, alcohol). Ganancia de peso. Fotosensibilidad.',
    },
    adverse: {
      'pt': ['Hipoglicemia', 'Ganho de peso', 'Náuseas/epigastralgia', 'Fotossensibilidade', 'Icterícia colestática (raro)', 'Agranulocitose (muito raro)'],
      'es': ['Hipoglucemia', 'Aumento de peso', 'Náuseas/epigastralgia', 'Fotosensibilidad', 'Ictericia colestática (raro)'],
    },
  ),

  // ═══════════════════════════════════════════════════════════════
  //  GASTROENTEROLÓGICOS
  // ═══════════════════════════════════════════════════════════════

  DrugModel(
    id: 'pantoprazol',
    name: 'Pantoprazol',
    className: {'pt': 'Inibidor da bomba de prótons (IBP)', 'es': 'Inhibidor de la bomba de protones (IBP)'},
    category: {'pt': 'Gastroenterológicos', 'es': 'Gastroenterológicos'},
    route: 'VO / IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'DRGE/úlcera: 40 mg/dia VO. Úlcera H. pylori: 40 mg 12/12h × 7–14d (tripla terapia). Hemorragia digestiva alta: 80 mg IV bolus + 8 mg/h por 72h. Profilaxia úlcera de estresse UTI: 40 mg/dia IV ou VO.',
      'es': 'DRGE/úlcera: 40 mg/día VO. H. pylori: 40 mg c/12 h × 7–14d. HDA: 80 mg IV bolo + 8 mg/h por 72 h.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário em IR — metabolismo hepático.',
      'es': 'Sin ajuste en IR — metabolismo hepático.',
    },
    elderlyAlert: {
      'pt': 'Uso crônico: risco de hipomagnesemia, déficit de B12, osteoporose/fraturas (↓ absorção Ca2+), infecção por C. difficile e pneumonia. Usar pelo menor tempo possível.',
      'es': 'Uso crónico: hipomagnesemia, déficit B12, osteoporosis/fracturas, C. difficile. Usar el menor tiempo posible.',
    },
    mechanism: {
      'pt': 'Pró-fármaco ativado em ambiente ácido → inibe irreversivelmente a H+/K+-ATPase (bomba de prótons) da célula parietal → supressão potente e prolongada do ácido gástrico.',
      'es': 'Profármaco activado en ambiente ácido → inhibe irreversiblemente H+/K+-ATPasa (bomba de protones) → supresión ácido gástrico.',
    },
    warning: {
      'pt': 'Hipomagnesemia com uso > 3 meses (monitorar Mg2+ em uso prolongado). Reduz absorção de clopidogrel (interação CYP2C19 — preferir pantoprazol/rabeprazol). Aumenta risco C. difficile. Interação com metotrexato (↑ toxicidade).',
      'es': 'Hipomagnesemia con uso >3 meses. Reduce absorción de clopidogrel (CYP2C19). Aumenta riesgo C. difficile.',
    },
    adverse: {
      'pt': ['Cefaleia', 'Diarreia', 'Náuseas', 'Hipomagnesemia (crônico)', 'Déficit B12 (crônico)', 'Osteoporose (crônico)', 'Nefrite intersticial (raro)'],
      'es': ['Cefalea', 'Diarrea', 'Náuseas', 'Hipomagnesemia (crónico)', 'Déficit B12 (crónico)', 'Osteoporosis (crónico)'],
    },
  ),

  DrugModel(
    id: 'ondansetrona',
    name: 'Ondansetrona',
    className: {'pt': 'Antiemético – antagonista 5-HT3', 'es': 'Antiemético – antagonista 5-HT3'},
    category: {'pt': 'Gastroenterológicos', 'es': 'Gastroenterológicos'},
    route: 'VO / IV / SL',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Náuseas/vômitos cirurgia ou QT: 4–8 mg IV lento (2–5 min) ou 8 mg VO 30 min antes de QT. Pós-op: 4 mg IV. Comprimido SL: 4–8 mg. Pode repetir 4–8 mg a cada 8h (máx. 24 mg/dia).',
      'es': 'Náuseas/vómitos cirugía o QT: 4–8 mg IV lento o 8 mg VO 30 min antes. Pós-op: 4 mg IV. Máx. 24 mg/día.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário em IR.',
      'es': 'Sin ajuste en IR.',
    },
    elderlyAlert: {
      'pt': 'Prolongamento QT (maior risco com IC, hipocalemia, hipomagnessemia e outros QT-prolongadores). Monitorar ECG em cardiopatas.',
      'es': 'Prolongación QT (mayor riesgo con IC, hipopotasemia, hipomagnasemia). Monitorizar ECG en cardíacos.',
    },
    mechanism: {
      'pt': 'Antagonista competitivo de receptores 5-HT3 no trato GI e zona gatilho quimiorreceptora (CTZ) → bloqueia impulsos vagais emeto-indutores → antiemético eficaz.',
      'es': 'Antagonista de receptores 5-HT3 en TGI y zona gatillo quimiorreceptora → bloquea impulsos vagales eméticos.',
    },
    warning: {
      'pt': 'Prolongamento QT — evitar com outros QT-prolongadores (haloperidol, azitromicina, amiodarona). Estreiteza serotonérgica com ISSRs/IMAOs (síndrome serotoninérgica, raro). Constipação. Pode mascarar obstrução intestinal.',
      'es': 'Prolongación QT — evitar con otros QT-prolongadores. Síndrome serotoninérgico (raro) con ISRSs/IMAOs.',
    },
    adverse: {
      'pt': ['Cefaleia (9%)', 'Constipação', 'Prolongamento QT', 'Rubor', 'Elevação transaminases (raro)', 'Reações extrapiramidais (raro)'],
      'es': ['Cefalea (9%)', 'Constipación', 'Prolongación QT', 'Rubor', 'Elevación transaminasas (raro)'],
    },
  ),

  DrugModel(
    id: 'lactulose',
    name: 'Lactulose',
    className: {'pt': 'Laxante osmótico / tratamento encefalopatia hepática', 'es': 'Laxante osmótico / tratamiento encefalopatia hepática'},
    category: {'pt': 'Gastroenterológicos', 'es': 'Gastroenterológicos'},
    route: 'VO / Retal',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Constipação: 15–30 mL (10–20 g) 1–3x/dia. Encefalopatia hepática (EH) aguda: 30–45 mL a cada 1–2h até evacuação; depois 15–45 mL 3–4x/dia (meta: 2–3 evacuações pastosas/dia). Retal (EH grave): enema 300 mL + 700 mL SF.',
      'es': 'Constipación: 15–30 mL 1–3×/día. EH aguda: 30–45 mL c/1–2 h hasta evacuación; mantenimiento 15–45 mL 3–4×/día.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário. Hipernatremia/desidratação em IR com diarreia excessiva.',
      'es': 'Sin ajuste necesario. Precaución con diarrea excesiva en IR.',
    },
    elderlyAlert: {
      'pt': 'Diarreia excessiva → desidratação e distúrbios eletrolíticos. Monitorar hidratação e eletrólitos em idosos.',
      'es': 'Diarrea excesiva → deshidratación y trastornos electrolíticos. Monitorizar hidratación.',
    },
    mechanism: {
      'pt': 'Dissacarídeo sintético não absorvível → metabolizado por bactérias colônicas → ácidos orgânicos → acidificação do cólon → converte NH3 (tóxico) em NH4+ (não absorvível) → reduz hiperamonemia na EH.',
      'es': 'Disacárido no absorbible → bactérias colónicas → acidificación cólica → convierte NH3 en NH4+ no absorbible → reduce hiperamonemia.',
    },
    warning: {
      'pt': 'Cólicas abdominais intensas nos primeiros dias. Hipernatremia se uso excessivo com baixa ingestão hídrica. Diabéticos: contém galactose e lactose (glicemia elevada).',
      'es': 'Cólicos abdominales intensos al inicio. Hipernatremia con uso excesivo. Diabéticos: contiene galactosa y lactosa.',
    },
    adverse: {
      'pt': ['Flatulência/meteorismo', 'Cólicas abdominais', 'Diarreia', 'Náuseas', 'Desidratação (excessivo)', 'Hipernatremia (excessivo)'],
      'es': ['Flatulencia/meteorismo', 'Cólicos abdominales', 'Diarrea', 'Náuseas', 'Deshidratación (excesivo)'],
    },
  ),

  // ═══════════════════════════════════════════════════════════════
  //  HEMATOLÓGICOS / ANTICOAGULANTES
  // ═══════════════════════════════════════════════════════════════

  DrugModel(
    id: 'enoxaparina',
    name: 'Enoxaparina (HBPM)',
    className: {'pt': 'Heparina de baixo peso molecular (HBPM)', 'es': 'Heparina de bajo peso molecular (HBPM)'},
    category: {'pt': 'Hematológicos / Anticoagulantes', 'es': 'Hematológicos / Anticoagulantes'},
    route: 'SC',
    doseType: 'weight',
    fixedDose: {
      'pt': 'Profilaxia TVP: 40 mg SC 1x/dia. Tratamento TEV: 1 mg/kg SC 12/12h ou 1,5 mg/kg SC 1x/dia. SCA (IAM STEMI, NSTEMI): 1 mg/kg SC 12/12h (+ bolus 30 mg IV se < 75 anos). Máx. 100 mg/dose.',
      'es': 'Profilaxis TVP: 40 mg SC 1×/día. Tratamiento TEV: 1 mg/kg SC c/12 h. SCA: 1 mg/kg SC c/12 h (+ bolo 30 mg IV si <75 años).',
    },
    renalAlert: {
      'pt': 'ClCr 15–29: reduzir 50% (profilaxia: 20 mg/dia; terapêutica: 1 mg/kg 1x/dia). ClCr <15 ou HD: evitar ou usar heparina não-fracionada com controle de TTPa. Dosagem anti-Xa se disponível.',
      'es': 'ClCr 15–29: reducir 50%. ClCr <15/HD: evitar o usar HNF con control TTPa.',
    },
    elderlyAlert: {
      'pt': 'Risco hemorrágico aumentado (queda da ClCr). Monitorar anti-Xa se > 75 anos e peso <50 kg ou >100 kg. Evitar bolus IV em > 75 anos (SCA).',
      'es': 'Mayor riesgo hemorrágico (↓ ClCr). Monitorizar anti-Xa si >75 años, <50 kg o >100 kg. Evitar bolo IV en >75 años.',
    },
    mechanism: {
      'pt': 'Liga-se à antitrombina III (ATIII) → inibe fator Xa (principalmente) e IIa (trombina) → anticoagulação. Maior ação anti-Xa/anti-IIa que HNF → efeito mais previsível.',
      'es': 'Se une a ATIII → inhibe factor Xa (principalmente) e IIa → anticoagulación más predecible que HNF.',
    },
    warning: {
      'pt': 'Sangramento (principal risco). Trombocitopenia induzida por heparina (TIH) — menos frequente que HNF mas possível (monitorar plaquetas a cada 2–3 dias primeiros 14 dias). Antídoto parcial: sulfato de protamina (neutraliza ~60% anti-Xa).',
      'es': 'Sangrado (principal riesgo). TIH — menos frecuente que HNF. Antídoto parcial: sulfato de protamina.',
    },
    adverse: {
      'pt': ['Sangramento', 'Trombocitopenia (TIH — <1%)', 'Hematoma no local SC', 'Hiperpotassemia (hipoaldosteronismo)', 'Elevação transaminases', 'Osteoporose (uso prolongado)'],
      'es': ['Sangrado', 'Trombocitopenia (TIH <1%)', 'Hematoma local SC', 'Hiperpotasemia', 'Osteoporosis (uso prolongado)'],
    },
  ),

  DrugModel(
    id: 'rivaroxabana',
    name: 'Rivaroxabana',
    className: {'pt': 'Anticoagulante oral direto – inibidor do fator Xa', 'es': 'Anticoagulante oral directo – inhibidor del factor Xa'},
    category: {'pt': 'Hematológicos / Anticoagulantes', 'es': 'Hematológicos / Anticoagulantes'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'FA não-valvar (↓ AVC): 20 mg 1x/dia (com jantar). TEV (tratamento inicial): 15 mg 12/12h × 21 dias, depois 20 mg/dia. Profilaxia TEV pós-ortopedia: 10 mg/dia × 35 dias (quadril) ou 14 dias (joelho).',
      'es': 'FA no valvular: 20 mg 1×/día (con cena). TEV: 15 mg c/12 h × 21 días, luego 20 mg/día. Profilaxis TEV: 10 mg/día.',
    },
    renalAlert: {
      'pt': 'FA: ClCr 15–49: reduzir para 15 mg/dia. ClCr <15: CONTRAINDICADO. TEV: ClCr <30: CONTRAINDICADO. Monitorar função renal trimestralmente.',
      'es': 'FA: ClCr 15–49: reducir a 15 mg/día. ClCr <15: CONTRAINDICADO. TEV: ClCr <30: CONTRAINDICADO.',
    },
    elderlyAlert: {
      'pt': 'Risco hemorrágico aumentado. Avaliar função renal frequentemente. Antídoto disponível: andexanet alfa (aprovado no Brasil). Interação com inibidores/indutores de P-gp e CYP3A4.',
      'es': 'Mayor riesgo hemorrágico. Evaluar función renal frecuentemente. Antídoto: andexanet alfa.',
    },
    mechanism: {
      'pt': 'Inibe diretamente e seletivamente o fator Xa livre e ligado ao coágulo → bloqueia conversão de protrombina a trombina → anticoagulação previsível sem monitoração rotineira.',
      'es': 'Inhibe directamente el factor Xa libre y unido al coágulo → bloquea conversión protrombina a trombina.',
    },
    warning: {
      'pt': 'Sangramento grave (sem antídoto de acesso fácil — andexanet alfa disponível, custo alto). Evitar com anticoagulantes/antiplaquetários combinados sem indicação clara. Sem monitoração rotineira de coagulação. Evitar em gravidez.',
      'es': 'Sangrado grave (antídoto andexanet alfa disponible, alto costo). Evitar en embarazo. Sin monitoreo rutinario de coagulación.',
    },
    adverse: {
      'pt': ['Sangramento (GI, intracraniano, outros)', 'Anemia', 'Elevação transaminases', 'Náuseas', 'Prurido', 'Hematomas'],
      'es': ['Sangrado (GI, intracraneal, otros)', 'Anemia', 'Elevación transaminasas', 'Náuseas'],
    },
  ),

  DrugModel(
    id: 'acido_tranexamico',
    name: 'Ácido Tranexâmico',
    className: {'pt': 'Antifibrinolítico', 'es': 'Antifibrinolítico'},
    category: {'pt': 'Hematológicos / Anticoagulantes', 'es': 'Hematológicos / Anticoagulantes'},
    route: 'IV / VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Trauma com hemorragia: 1 g IV em 10 min nas primeiras 3h do trauma, seguido de 1 g IV em 8h. PPH (hemorragia pós-parto): 1 g IV em 10 min; se persistir, 2ª dose de 1 g após 30 min. Epistaxe/oral VO: 500–1000 mg 3x/dia.',
      'es': 'Trauma hemorrágico: 1 g IV en 10 min primeras 3 h; seguido de 1 g IV en 8 h. HPP: 1 g IV en 10 min; 2ª dosis 1 g si persiste. VO: 500–1000 mg 3×/día.',
    },
    renalAlert: {
      'pt': 'Ajuste necessário: ClCr 20–50: 10 mg/kg 12/12h. ClCr 10–20: 10 mg/kg 24/24h. ClCr <10: 5 mg/kg 24/24h.',
      'es': 'Ajuste necesario: ClCr 20–50: 10 mg/kg c/12 h. ClCr 10–20: c/24 h. ClCr <10: 5 mg/kg c/24 h.',
    },
    elderlyAlert: {
      'pt': 'Ajustar pela ClCr. Risco trombótico aumentado (TEV, AVE). Usar com cautela em história de tromboembolismo.',
      'es': 'Ajustar por ClCr. Mayor riesgo trombótico (TEV, ACV). Precaución en historia de tromboembolismo.',
    },
    mechanism: {
      'pt': 'Liga-se aos sítios de ligação ao lisina do plasminogênio e plasmina → inibe fibrinólise → estabiliza o coágulo formado. Não coagulante direto.',
      'es': 'Se une a sitios de lisina del plasminógeno y plasmina → inhibe fibrinólisis → estabiliza el coágulo.',
    },
    warning: {
      'pt': 'Contraindicado se hemorragia subaracnóidea (vasoespasmo). Contraindicado em TVP ativa/TEP/CIVD com predominância fibrinolítica. Após 3h do trauma — evidências de benefício diminuem (estudo CRASH-2). Risco de convulsões em doses altas IV.',
      'es': 'Contraindicado en HSA (vasoespasmo). Contraindicado en TVP activa/TEP/CIVD. Beneficio disminuye >3 h del trauma (CRASH-2). Convulsiones con dosis altas.',
    },
    adverse: {
      'pt': ['Náuseas/vômitos', 'Diarreia', 'Hipotensão (IV rápido)', 'Convulsões (doses altas)', 'Trombose (TEV, TVP)', 'Visão cromática alterada (raro)'],
      'es': ['Náuseas/vómitos', 'Hipotensión (IV rápido)', 'Convulsiones (dosis altas)', 'Trombosis (TEV)', 'Cambio visión cromática (raro)'],
    },
  ),

  // ═══════════════════════════════════════════════════════════════
  //  ANESTESIOLOGIA / SEDAÇÃO / EMERGÊNCIA
  // ═══════════════════════════════════════════════════════════════

  DrugModel(
    id: 'ketamina',
    name: 'Ketamina',
    className: {'pt': 'Anestésico dissociativo – antagonista NMDA', 'es': 'Anestésico disociativo – antagonista NMDA'},
    category: {'pt': 'Anestesiologia / Sedação', 'es': 'Anestesiología / Sedación'},
    route: 'IV / IM',
    doseType: 'weight',
    fixedDose: {
      'pt': 'Anestesia IV: 1–2 mg/kg IV lento. IM: 4–6 mg/kg. Sedação procedimento: 0,5–1 mg/kg IV. Analgesia subanestésica: 0,1–0,5 mg/kg IV. Broncoespasmo severo: 1–2 mg/kg IV. Associar midazolam (0,03–0,05 mg/kg) para ↓ reações emergentes.',
      'es': 'Anestesia IV: 1–2 mg/kg IV lento. IM: 4–6 mg/kg. Sedación: 0,5–1 mg/kg IV. Analgesia: 0,1–0,5 mg/kg IV. Broncoespasmo: 1–2 mg/kg IV.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário. Metabólitos renais — acumulam em IR grave (sedação prolongada).',
      'es': 'Sin ajuste necesario. Metabolitos renales — acumulan en IR grave.',
    },
    elderlyAlert: {
      'pt': 'Alucinações e reações emergentes mais frequentes. Hipertensão e taquicardia marcantes. Reduzir dose 30–50%. Titulação lenta.',
      'es': 'Alucinaciones y reacciones emergentes más frecuentes. HAS y taquicardia marcadas. Reducir dosis 30–50%.',
    },
    mechanism: {
      'pt': 'Antagonista não-competitivo dos receptores NMDA (glutamato) → anestesia dissociativa, analgesia, amnésia. Mantém reflexos de proteção de vias aéreas. Simpaticomiméticas endógenas → ↑ PA, ↑ FC, broncodilatação.',
      'es': 'Antagonista NMDA (glutamato) → anestesia disociativa, analgesia, amnesia. Mantiene reflejos de vía aérea. Simpaticomiméticas endógenas → ↑ PA, ↑ FC, broncodilatación.',
    },
    warning: {
      'pt': 'Reações emergentes (alucinações, delirium, pesadelos) — profilaxia com benzodiazepínico. Contraindicada em HAS descontrolada grave, trauma cranioencefálico com PIC elevada (relativo), doença coronariana instável. ↑ Secreções (atropina profilática opcional).',
      'es': 'Reacciones emergentes (alucinaciones, delirium) — profilaxis con benzodiacepina. Contraindicada en HAS grave descontrolada, TCE con PIC elevada (relativo).',
    },
    adverse: {
      'pt': ['Reações emergentes (15–30%)', 'Hipertensão/taquicardia', 'Hipersecreção', 'Diplopia', 'Laringoespasmo (raro)', 'Vômitos', 'Aumento da PIC (relativo)'],
      'es': ['Reacciones emergentes (15–30%)', 'Hipertensión/taquicardia', 'Hipersecreción', 'Laringoespasmo (raro)', 'Vómitos'],
    },
  ),

  DrugModel(
    id: 'succinilcolina',
    name: 'Succinilcolina (Suxametônio)',
    className: {'pt': 'Bloqueador neuromuscular despolarizante', 'es': 'Bloqueante neuromuscular despolarizante'},
    category: {'pt': 'Anestesiologia / Sedação', 'es': 'Anestesiología / Sedación'},
    route: 'IV',
    doseType: 'weight',
    fixedDose: {
      'pt': 'IRS (adulto): 1,5 mg/kg IV rápido. Máx. 150 mg. Criança: 2 mg/kg IV. Início: 30–60 s. Duração: 6–12 min. Pré-oxigenar 3–5 min. Pré-tratar atropina 0,01 mg/kg se < 1 ano (bradicardia).',
      'es': 'IRS (adulto): 1,5 mg/kg IV rápido. Máx. 150 mg. Niño: 2 mg/kg IV. Inicio: 30–60 s. Duración: 6–12 min.',
    },
    renalAlert: {
      'pt': 'CONTRAINDICADA em hiperpotassemia (K+ ≥ 5,5 mEq/L) ou risco alto de hiperpotassemia — libera K+ (0,5–1 mEq/L na resposta normal). Alternativa: rocurônio 1,2 mg/kg.',
      'es': 'CONTRAINDICADA en hiperpotasemia (K+ ≥5,5 mEq/L). Libera K+ (0,5–1 mEq/L). Alternativa: rocurônio.',
    },
    elderlyAlert: {
      'pt': 'Usar com cautela — pseudocolinesterase reduzida pode prolongar bloqueio. Hiperpotassemia em imobilização prolongada.',
      'es': 'Precaución — pseudocolinesterasa reducida puede prolongar bloqueo. Hiperpotasemia en inmovilización.',
    },
    mechanism: {
      'pt': 'Liga-se permanentemente ao receptor nicotínico de acetilcolina na placa motora → despolarização persistente → bloqueio (fase I) → início ultrarrápido. Degradado pela pseudocolinesterase plasmática.',
      'es': 'Se une permanentemente al receptor nicotínico → despolarización persistente → bloqueo ultrarrápido. Degradado por pseudocolinesterasa.',
    },
    warning: {
      'pt': 'Hipertermia maligna (associada a anestésicos inalatórios — evitar combinação). Hiperpotassemia grave em queimados (> 24h), lesão medular, denervação, sepse prolongada, miopatias. Bradicardia (especialmente 2ª dose IV, crianças). Trismo (raro, preditor de hipertermia maligna).',
      'es': 'Hipertermia maligna (con anestésicos inhalados). Hiperpotasemia grave en quemados/lesión medular/sepsis. Bradicardia (2ª dosis, niños).',
    },
    adverse: {
      'pt': ['Hiperpotassemia', 'Bradicardia/assistolia (especialmente crianças)', 'Hipertermia maligna (genético)', 'Mialgia pós-operatória', 'Aumento PIC/POI/PG', 'Bloqueio prolongado (pseudo-colinesterase deficiente)'],
      'es': ['Hiperpotasemia', 'Bradicardia/asistolia (niños)', 'Hipertermia maligna (genético)', 'Mialgia post-op', 'Bloqueo prolongado'],
    },
  ),

  DrugModel(
    id: 'noradrenalina',
    name: 'Noradrenalina (Norepinefrina)',
    className: {'pt': 'Vasopressor – catecolamina α1/β1', 'es': 'Vasopresor – catecolamina α1/β1'},
    category: {'pt': 'UTI / Emergência', 'es': 'UCI / Emergencia'},
    route: 'IV (infusão contínua)',
    doseType: 'weight',
    fixedDose: {
      'pt': 'Choque séptico/distributivo: 0,01–3 mcg/kg/min IV contínuo (usual 0,1–0,5 mcg/kg/min). Titular pela PAM alvo ≥ 65 mmHg. Via central preferencial. Pode iniciar periférica se urgência (diluir bem; máx. 4h periférica).',
      'es': 'Choque séptico: 0,01–3 mcg/kg/min IV continuo. Titular por PAM ≥ 65 mmHg. Vía central preferencial.',
    },
    renalAlert: {
      'pt': 'Não há ajuste de dose, mas vasoconstricção periférica pode reduzir perfusão renal. Monitorar diurese e creatinina. Evitar doses muito altas sem necessidade.',
      'es': 'Sin ajuste, pero vasoconstricción puede reducir perfusión renal. Monitorizar diuresis y creatinina.',
    },
    elderlyAlert: {
      'pt': 'Vasoconstrição periférica intensa → risco de isquemia de extremidades, mesentérica e renal. Usar menor dose eficaz. Monitorar sinais de isquemia periférica.',
      'es': 'Vasoconstricción intensa → riesgo de isquemia de extremidades, mesentérica y renal. Usar menor dosis eficaz.',
    },
    mechanism: {
      'pt': 'Agonista α1 (vasoconstrição intensa) >> β1 (↑ contratilidade) e β2 mínimo → ↑ PAM, ↑ RVS. Droga de escolha no choque séptico (SSC 2021).',
      'es': 'Agonista α1 (vasoconstricción intensa) >> β1 (↑ contractilidad) → ↑ PAM. Droga de elección en choque séptico (SSC 2021).',
    },
    warning: {
      'pt': 'Necrose tissular se extravasamento — usar via central preferencial. Taquiarritmias. Isquemia mesentérica em doses altas. Evitar hipoperfusão periférica prolongada. Não usar em solução alcalina (inativada).',
      'es': 'Necrosis tisular si extravasación — vía central preferida. Taquiarritmias. Isquemia mesentérica en dosis altas.',
    },
    adverse: {
      'pt': ['Hipertensão', 'Bradicardia reflexa', 'Isquemia periférica', 'Necrose por extravasamento', 'Isquemia mesentérica', 'Taquiarritmias'],
      'es': ['Hipertensión', 'Bradicardia refleja', 'Isquemia periférica', 'Necrosis por extravasación', 'Isquemia mesentérica'],
    },
  ),

  DrugModel(
    id: 'dobutamina',
    name: 'Dobutamina',
    className: {'pt': 'Inotrópico positivo – agonista β1 seletivo', 'es': 'Inotrópico positivo – agonista β1 selectivo'},
    category: {'pt': 'UTI / Emergência', 'es': 'UCI / Emergencia'},
    route: 'IV (infusão contínua)',
    doseType: 'weight',
    fixedDose: {
      'pt': 'Choque cardiogênico/ICC descompensada: 2–20 mcg/kg/min IV contínuo. Iniciar 2–5 mcg/kg/min e titular pelo débito cardíaco/PA. Efeito inotrópico predominante 2–10 mcg/kg/min.',
      'es': 'Choque cardiogénico/ICC descompensada: 2–20 mcg/kg/min IV continuo. Iniciar 2–5 mcg/kg/min, titular por DC/PA.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário. ↑ Débito cardíaco pode melhorar perfusão renal no choque cardiogênico.',
      'es': 'Sin ajuste necesario. ↑ Gasto cardíaco puede mejorar perfusión renal en choque cardiogénico.',
    },
    elderlyAlert: {
      'pt': 'Taquiarritmias mais frequentes (FA, ESV). Usar menor dose eficaz. Monitorar ECG continuamente.',
      'es': 'Taquiarritmias más frecuentes (FA, ESV). Usar menor dosis eficaz. Monitorizar ECG continuamente.',
    },
    mechanism: {
      'pt': 'Agonista β1 seletivo → ↑ contratilidade, ↑ DC, ↓ RVS (vasodilatação β2 leve). Sem efeito dopaminérgico. Cronotrópico positivo moderado. Não aumenta PA como vasopressores.',
      'es': 'Agonista β1 selectivo → ↑ contractilidad, ↑ DC, ↓ RVS (vasodilatación β2 leve). Sin efecto dopaminérgico.',
    },
    warning: {
      'pt': 'Taquicardia (25%) e taquiarritmias — reduzir dose ou suspender se FC > 130 bpm. Não usa como vasopressor (não aumenta PAM de forma confiável). Tolerância após 72–96h uso contínuo. Não melhorou prognóstico em estudos — usar na menor dose por menor tempo.',
      'es': 'Taquicardia (25%) y taquiarritmias — reducir si FC >130 lpm. No es vasopresor. Tolerancia tras 72–96 h de uso continuo.',
    },
    adverse: {
      'pt': ['Taquicardia', 'Taquiarritmias (FA, TVNS)', 'Hipertensão leve', 'Cefaleia', 'Piloereção', 'Tolerância (uso prolongado)'],
      'es': ['Taquicardia', 'Taquiarritmias (FA, TVNS)', 'Hipertensión leve', 'Cefalea', 'Tolerancia (uso prolongado)'],
    },
  ),

  DrugModel(
    id: 'adenosina',
    name: 'Adenosina',
    className: {'pt': 'Antiarrítmico – purina endógena (Classe V)', 'es': 'Antiarrítmico – purina endógena (Clase V)'},
    category: {'pt': 'UTI / Emergência', 'es': 'UCI / Emergencia'},
    route: 'IV rápido (bolus)',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'TPSV: 6 mg IV rápido em 1–3 s + flush 20 mL SF imediato. Se sem resposta em 1–2 min: 12 mg IV rápido. Repetir 12 mg se necessário. Máx. 30 mg total. Via central: reduzir dose pela metade.',
      'es': 'TPSV: 6 mg IV rápido + flush 20 mL SF. Sin respuesta en 1–2 min: 12 mg IV. Repetir 12 mg si necesario. Máx. 30 mg total.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário — meia-vida < 10 s (metabolismo eritrócitos/endotélio).',
      'es': 'Sin ajuste — semivida <10 s (metabolismo eritrocitos/endotelio).',
    },
    elderlyAlert: {
      'pt': 'Maior sensibilidade — iniciar com 3 mg se suspeita de doença do nó sinusal ou bloqueio AV. Monitorar ECG e PA.',
      'es': 'Mayor sensibilidad — iniciar con 3 mg si sospecha disfunción nodo sinusal o BAV. Monitorizar ECG y PA.',
    },
    mechanism: {
      'pt': 'Liga-se ao receptor A1 no nó AV → ↑ condutância K+ e ↓ corrente If → bloqueia condução AV transitoriamente (6–12 s) → interrompe reentrada no nó AV → converte TPSV.',
      'es': 'Se une al receptor A1 en nodo AV → bloqueo transitorio conducción AV (6–12 s) → interrumpe reentrada → convierte TPSV.',
    },
    warning: {
      'pt': 'Broncoespasmo grave (contraindicada em asma e DPOC grave). Assistolia transitória (5–15 s) esperada. Informar paciente antes. Padrão de pré-excitação (WPW) pode converter em FA com alta resposta ventricular. ECG contínuo obrigatório.',
      'es': 'Broncoespasmo grave — contraindicada en asma y EPOC grave. Asistolia transitoria esperada (5–15 s). Síndrome WPW puede convertir en FA con alta respuesta.',
    },
    adverse: {
      'pt': ['Flushing/calor (75%)', 'Dispneia (50%)', 'Dor torácica', 'Assistolia transitória', 'Broncoespasmo (asma)', 'Náuseas', 'Bradicardia reflexa pós-conversão'],
      'es': ['Flushing/calor (75%)', 'Disnea (50%)', 'Dolor torácico', 'Asistolia transitoria', 'Broncoespasmo (asma)', 'Náuseas'],
    },
  ),

  DrugModel(
    id: 'sulfato_magnesio',
    name: 'Sulfato de Magnésio (MgSO₄)',
    className: {'pt': 'Eletrólito / anticonvulsivante / tocolítico / antiarrítmico', 'es': 'Electrolito / anticonvulsivante / tocolítico / antiarrítmico'},
    category: {'pt': 'UTI / Emergência', 'es': 'UCI / Emergencia'},
    route: 'IV / IM',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Pré-eclâmpsia/eclâmpsia: 4–6 g IV em 20 min (ataque) + 1–2 g/h (manutenção). Torsades de Pointes: 2 g IV em 5–15 min. Exacerbação grave de asma: 2 g IV em 20 min. Hipomagnesemia: 1–2 g IV em 15–60 min.',
      'es': 'Preeclampsia/eclampsia: 4–6 g IV en 20 min + 1–2 g/h. Torsades: 2 g IV en 5–15 min. Asma grave: 2 g IV en 20 min.',
    },
    renalAlert: {
      'pt': 'Eliminação renal exclusiva — acúmulo em IR leve-moderada. Monitorar reflexos patelares, FR e nível sérico. ClCr <30: máx. 50% da dose usual. Antídoto: gluconato de cálcio 1 g IV.',
      'es': 'Eliminación renal exclusiva — acumulación en IR. Monitorizar reflejos patelares, FR y nivel sérico. Antídoto: gluconato de calcio 1 g IV.',
    },
    elderlyAlert: {
      'pt': 'Toxicidade rápida em idosos (↓ ClCr). Monitorar: reflejos (desaparecem >5 mEq/L), FR (paralisia >10 mEq/L), PA. Ter gluconato de cálcio à beira.',
      'es': 'Toxicidad rápida en ancianos (↓ ClCr). Monitorizar: reflejos (desaparecen >5 mEq/L), FR (parálisis >10 mEq/L). Gluconato de calcio a la cabecera.',
    },
    mechanism: {
      'pt': 'Antagonista fisiológico do Ca²+ → ↓ excitabilidade neuromuscular → efeito anticonvulsivante, tocolítico e antiarrítmico. Cofator enzimático essencial (300+ reações metabólicas).',
      'es': 'Antagonista fisiológico del Ca²+ → ↓ excitabilidad neuromuscular → anticonvulsivante, tocolítico y antiarrítmico.',
    },
    warning: {
      'pt': 'Toxicidade em escala: ↓ reflexos patelares (4–5 mEq/L) → FR < 12/min (5–10 mEq/L) → parada cardiorrespiratória (> 15 mEq/L). Antídoto: gluconato de cálcio 1 g IV lento. Monitorar nível sérico se IR.',
      'es': 'Toxicidad escalonada: ↓ reflejos (4–5 mEq/L) → FR <12/min (5–10 mEq/L) → parada (>15 mEq/L). Antídoto: gluconato calcio 1 g IV.',
    },
    adverse: {
      'pt': ['Flushing/calor', 'Náuseas', 'Hipotensão', 'Bloqueio neuromuscular', 'Depressão respiratória', 'Parada cardíaca (tóxico)', 'Bradicardia'],
      'es': ['Flushing/calor', 'Náuseas', 'Hipotensión', 'Bloqueo neuromuscular', 'Depresión respiratoria', 'Parada cardíaca (tóxico)'],
    },
  ),

];
