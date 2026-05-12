import '../models/drug_model.dart';

/// Base de fármacos MedCases Pro
/// Fontes: Harrison's Principles of Internal Medicine (21ª ed.),
/// Goodman & Gilman's Pharmacological Basis of Therapeutics (14ª ed.),
/// Micromedex, UpToDate, SBC, SBD, AHA/ACC, IDSA, SCCM guidelines.
const List<DrugModel> drugsDatabase = [

  DrugModel(
    id: 'paracetamol',
    group: 'Analgésicos y Antipiréticos',
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
    group: 'Analgésicos y Antipiréticos',
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
    group: 'Analgésicos y Antipiréticos',
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
    group: 'Analgésicos y Antipiréticos',
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
    group: 'Analgésicos y Antipiréticos',
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
    group: 'Analgésicos y Antipiréticos',
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
    group: 'Analgésicos y Antipiréticos',
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

  DrugModel(
    id: 'ceftriaxona',
    group: 'Antibióticos',
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
    group: 'Antibióticos',
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
    group: 'Antibióticos',
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
    group: 'Antibióticos',
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
    group: 'Antibióticos',
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
    group: 'Antibióticos',
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
    group: 'Antibióticos',
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

  DrugModel(
    id: 'noradrenalina',
    group: 'Cardiovascular y HTA',
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
    group: 'Cardiovascular y HTA',
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
    group: 'UCI – Críticos y Sedoanalgesia',
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
    group: 'Cardiovascular y HTA',
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

  DrugModel(
    id: 'furosemida',
    group: 'Cardiovascular y HTA',
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
    group: 'Cardiovascular y HTA',
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
    group: 'Cardiovascular y HTA',
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
    group: 'Anticoagulantes y Hemostasia',
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
    group: 'Anticoagulantes y Hemostasia',
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
    group: 'Cardiovascular y HTA',
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
    group: 'Cardiovascular y HTA',
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

  DrugModel(
    id: 'salbutamol',
    group: 'Respiratorio',
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
    group: 'Endocrinología y Metabolismo',
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
    group: 'Endocrinología y Metabolismo',
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

  DrugModel(
    id: 'midazolam',
    group: 'Neurología y Psiquiatría',
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
    group: 'Neurología y Psiquiatría',
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
    group: 'Neurología y Psiquiatría',
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
    group: 'Neurología y Psiquiatría',
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

  DrugModel(
    id: 'omeprazol',
    group: 'Gastroenterología',
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
    group: 'Endocrinología y Metabolismo',
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
    group: 'Endocrinología y Metabolismo',
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
    group: 'Endocrinología y Metabolismo',
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

  DrugModel(
    id: 'atenolol',
    group: 'Cardiovascular y HTA',
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
    id: 'losartana',
    group: 'Cardiovascular y HTA',
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
    group: 'Cardiovascular y HTA',
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
    group: 'Cardiovascular y HTA',
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
    group: 'Cardiovascular y HTA',
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

  DrugModel(
    id: 'amoxicilina_clavulanato',
    group: 'Antibióticos',
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
    id: 'ipratropio',
    group: 'Respiratorio',
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
    group: 'Endocrinología y Metabolismo',
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
    group: 'Respiratorio',
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

  DrugModel(
    id: 'fluconazol',
    group: 'Infectología (Antifúngicos / Antivirales / TBC)',
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

  DrugModel(
    id: 'amlodipino',
    group: 'Cardiovascular y HTA',
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
    id: 'haloperidol',
    group: 'Neurología y Psiquiatría',
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
    group: 'Neurología y Psiquiatría',
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
    group: 'Neurología y Psiquiatría',
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
    group: 'Neurología y Psiquiatría',
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

  DrugModel(
    id: 'levotiroxina',
    group: 'Endocrinología y Metabolismo',
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
    group: 'Endocrinología y Metabolismo',
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
    group: 'Endocrinología y Metabolismo',
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

  DrugModel(
    id: 'pantoprazol',
    group: 'Gastroenterología',
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
    group: 'Gastroenterología',
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
    group: 'Gastroenterología',
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

  DrugModel(
    id: 'rivaroxabana',
    group: 'Anticoagulantes y Hemostasia',
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
    group: 'Anticoagulantes y Hemostasia',
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

  DrugModel(
    id: 'ketamina',
    group: 'UCI – Críticos y Sedoanalgesia',
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
    group: 'UCI – Críticos y Sedoanalgesia',
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
    id: 'adenosina',
    group: 'Cardiovascular y HTA',
    name: 'Adenosina',
    className: {'pt': 'Antiarrítmico – purina endógena (Classe V)', 'es': 'Antiarrítmico – purina endógena (Clase V)'},
    category: {'pt': 'UTI / Emergência', 'es': 'UCI / Emergencia'},
    route: 'IV rápido (bolus)',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Adulto — TPSV: 6 mg IV rápido em 1–3 s + flush 20 mL SF imediato. Se sem resposta em 1–2 min: 12 mg IV. Repetir 12 mg se necessário. Máx. 30 mg total. Via central: reduzir dose pela metade. | Pediátrico: 0,1 mg/kg (máx 6 mg) → 0,2 mg/kg (máx 12 mg), flush imediato após cada dose.',
      'es': 'Adulto — TPSV: 6 mg IV rápido + flush 20 mL SF. Sin respuesta en 1–2 min: 12 mg IV. Repetir 12 mg si necesario. Máx. 30 mg total. | Pediátrico: 0,1 mg/kg (máx 6 mg) → 0,2 mg/kg (máx 12 mg), flush inmediato.',
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
      'pt': ['Flushing/calor (75%)', 'Dispneia (50%)', 'Dor torácica', 'Assistolia transitória', 'Sensação de morte iminente', 'Broncoespasmo (asma)', 'Náuseas', 'Bradicardia reflexa pós-conversão'],
      'es': ['Flushing/calor (75%)', 'Disnea (50%)', 'Dolor torácico', 'Asistolia transitoria', 'Sensación de muerte inminente', 'Broncoespasmo (asma)', 'Náuseas'],
    },
  ),

  DrugModel(
    id: 'sulfato_magnesio',
    group: 'Neurología y Psiquiatría',
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

  DrugModel(
    id: 'ampicilina_sulbactam',
    group: 'Antibióticos',
    name: 'Ampicilina-Sulbactam',
    className: {'pt': 'Aminopenicilina + inibidor β-lactamase', 'es': 'Aminopenicilina + inhibidor β-lactamasa'},
    category: {'pt': 'Antibióticos', 'es': 'Antibióticos'},
    route: 'IV / IM',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Adulto: 1,5–3 g (1 g ampicilina + 0,5 g sulbactam a 3 g ampicilina + 1,5 g sulbactam) IV a cada 6h. Infecção leve-moderada: 1,5 g a cada 6–8h. Grave: 3 g a cada 6h.',
      'es': 'Adulto: 1,5–3 g IV cada 6 h. Infección leve-moderada: 1,5 g cada 6–8 h. Grave: 3 g cada 6 h.',
    },
    renalAlert: {
      'pt': 'ClCr 15–29: a cada 12h. ClCr 5–14: a cada 24h. Hemodiálise: dose pós-diálise.',
      'es': 'ClCr 15–29: cada 12 h. ClCr 5–14: cada 24 h. Hemodiálisis: dosis post-diálisis.',
    },
    elderlyAlert: {
      'pt': 'Ajuste por ClCr. Diarreia associada a C. difficile mais frequente.',
      'es': 'Ajustar por ClCr. Mayor riesgo de diarrea por C. difficile.',
    },
    mechanism: {
      'pt': 'Ampicilina inibe PBPs bacterianas. Sulbactam inibe β-lactamases + atividade intrínseca contra Acinetobacter. Cobertura: estreptococos, MSSA, E. coli (ESBL−), Klebsiella (ESBL−), Proteus, H. influenzae, anaeróbios.',
      'es': 'Ampicilina inhibe PBPs. Sulbactam inhibe β-lactamasas + actividad intrínseca vs. Acinetobacter.',
    },
    warning: {
      'pt': 'Não cobre MRSA, Pseudomonas, ESBL+, Enterococcus faecium. Rash maculopapular em mononucleose (40%).',
      'es': 'No cubre MRSA, Pseudomonas, ESBL+. Rash en mononucleosis (40%).',
    },
    adverse: {
      'pt': ['Diarreia', 'Náuseas', 'Rash (10%)', 'Erupção em mononucleose (40%)', 'Elevação transaminases', 'Colite por C. difficile'],
      'es': ['Diarrea', 'Náuseas', 'Rash (10%)', 'Elevación transaminasas', 'Colitis por C. difficile'],
    },
  ),

  DrugModel(
    id: 'doxiciclina',
    group: 'Antibióticos',
    name: 'Doxiciclina',
    className: {'pt': 'Tetraciclina', 'es': 'Tetraciclina'},
    category: {'pt': 'Antibióticos', 'es': 'Antibióticos'},
    route: 'VO / IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Infecções comuns / atípicos / ISTs: 100 mg VO a cada 12h por 7–14 dias. Acne / rosacea: 50–100 mg/dia. Doença de Lyme: 100 mg VO a cada 12h por 14–21 dias. IV: 200 mg/dia em 1–2 doses.',
      'es': 'Infecciones / atípicos / ITS: 100 mg VO cada 12 h por 7–14 días. Acné/rosácea: 50–100 mg/día. Lyme: 100 mg cada 12 h por 14–21 días. IV: 200 mg/día.',
    },
    renalAlert: {
      'pt': 'Ajuste geralmente não necessário (eliminação predominantemente fecal). Segura em IR.',
      'es': 'Ajuste generalmente no necesario (eliminación fecal predominante). Segura en IR.',
    },
    elderlyAlert: {
      'pt': 'Segura em idosos. Tomar com bastante água em posição vertical por 30 min para prevenir esofagite.',
      'es': 'Segura en ancianos. Tomar con agua abundante en posición vertical 30 min para prevenir esofagitis.',
    },
    mechanism: {
      'pt': 'Liga-se à subunidade 30S → inibe síntese proteica bacteriana. Bacteriostática. Amplo espectro: Chlamydia, Mycoplasma, Rickettsia, Lyme, MRSA comunitário (celulite), anaplasma, Brucella.',
      'es': 'Se une a subunidad 30S → inhibe síntesis proteica. Bacteriostática. Espectro: Chlamydia, Mycoplasma, Rickettsia, Lyme, MRSA comunitario.',
    },
    warning: {
      'pt': 'Contraindicada em gravidez (2º/3º trimestre) e <8 anos (deposição óssea/dental). Fotossensibilidade (usar protetor solar). Esofagite se não tomada com água. Reduz eficácia de anticoncepcionais.',
      'es': 'Contraindicada en embarazo (2º/3er trimestre) y <8 años. Fotosensibilidad. Esofagitis si no se toma con agua.',
    },
    adverse: {
      'pt': ['Náuseas/vômitos', 'Fotossensibilidade', 'Esofagite', 'Diarreia', 'Suprainfecção (candida)', 'Hiperpigmentação cutânea'],
      'es': ['Náuseas/vómitos', 'Fotosensibilidad', 'Esofagitis', 'Diarrea', 'Sobreinfección (candida)'],
    },
  ),

  DrugModel(
    id: 'nitrofurantoina',
    group: 'Antibióticos',
    name: 'Nitrofurantoína',
    className: {'pt': 'Nitrofurano — antibiótico urinário', 'es': 'Nitrofurano — antibiótico urinario'},
    category: {'pt': 'Antibióticos', 'es': 'Antibióticos'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'ITU não-complicada: 100 mg (macrocristalina) VO 2×/dia por 5 dias ou 50–100 mg 4×/dia (formulação regular) por 7 dias. Profilaxia ITU recorrente: 50–100 mg/noite.',
      'es': 'ITU no complicada: 100 mg (macrocristalina) VO 2×/día por 5 días o 50–100 mg 4×/día por 7 días. Profilaxis: 50–100 mg/noche.',
    },
    renalAlert: {
      'pt': 'Contraindicada se ClCr <45 mL/min — não atinge concentração urinária terapêutica + acúmulo tóxico sistêmico.',
      'es': 'Contraindicada si ClCr <45 mL/min — no alcanza concentración urinaria terapéutica + acumulación tóxica.',
    },
    elderlyAlert: {
      'pt': 'Evitar em idosos (frequente ClCr <45). Risco de neurotoxicidade periférica e pneumonite com uso crônico.',
      'es': 'Evitar en ancianos (frecuente ClCr <45). Riesgo de neuropatía periférica y neumonitis con uso crónico.',
    },
    mechanism: {
      'pt': 'Reduzida por reductases bacterianas intracelulares → radicais livres danificam DNA, ribossomos e parede. Bactericida urinária. Cobertura: E. coli (>90%), Staphylococcus saprophyticus, Enterococcus.',
      'es': 'Reducida a radicales libres por reductasas bacterianas → daña DNA. Bactericida urinaria.',
    },
    warning: {
      'pt': 'Não penetra tecidos sistêmicos — apenas ITU baixa. Não usar em pielonefrite. Interação com antiácidos (↓ absorção). Falso-positivo no teste de glicosúria com solução de Benedict.',
      'es': 'Solo para ITU baja — no penetra tejidos. No usar en pielonefritis.',
    },
    adverse: {
      'pt': ['Náuseas/vômitos', 'Urina cor alaranjada', 'Pneumonite (uso crônico)', 'Neuropatia periférica (crônico)', 'Hepatotoxicidade (raro)', 'Hemólise em G6PD'],
      'es': ['Náuseas/vómitos', 'Orina anaranjada', 'Neumonitis (crónico)', 'Neuropatía periférica (crónico)', 'Hemólisis en G6PD'],
    },
  ),

  DrugModel(
    id: 'bisoprolol',
    group: 'Cardiovascular y HTA',
    name: 'Bisoprolol',
    className: {'pt': 'Betabloqueador β1-seletivo', 'es': 'Betabloqueador β1-selectivo'},
    category: {'pt': 'Cardiovascular', 'es': 'Cardiovascular'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'ICC: início com 1,25 mg/dia, titular a cada 2 semanas até 10 mg/dia (dose alvo). HAS/angina: 5–20 mg/dia. FA com alta resposta: 5–10 mg/dia.',
      'es': 'ICC: inicio 1,25 mg/día, titular cada 2 semanas hasta 10 mg/día. HAS/angina: 5–20 mg/día.',
    },
    renalAlert: {
      'pt': 'ClCr <20: máx 10 mg/dia. Geralmente bem tolerado.',
      'es': 'ClCr <20: máx 10 mg/día. Generalmente bien tolerado.',
    },
    elderlyAlert: {
      'pt': 'Início com dose baixa (1,25 mg). Monitorar bradicardia, hipotensão ortostática e fadiga.',
      'es': 'Iniciar con dosis baja (1,25 mg). Monitorizar bradicardia, hipotensión ortostática y fatiga.',
    },
    mechanism: {
      'pt': 'Antagonista seletivo β1 → ↓ FC, ↓ pressão arterial, ↓ contratilidade. Em ICC, reverte remodelamento ventricular (reduz mortalidade ~34% nos estudos CIBIS-II/MERIT-HF).',
      'es': 'Antagonista selectivo β1 → ↓ FC, ↓ PA, ↓ contractilidad. En ICC revierte remodelado ventricular (reduce mortalidad ~34%).',
    },
    warning: {
      'pt': 'Contraindicado em BAV 2–3°, bradicardia sinusal <50 bpm, asma brônquica, choque cardiogênico. Não suspender abruptamente em doença coronariana (risco de angina rebote). Mascaramento de hipoglicemia em DM.',
      'es': 'Contraindicado en BAV 2–3°, bradicardia <50, asma, shock cardiogénico. No suspender abruptamente.',
    },
    adverse: {
      'pt': ['Bradicardia', 'Fadiga', 'Hipotensão', 'Broncoespasmo (asma)', 'Extremidades frias', 'Insônia', 'Mascaramento hipoglicemia'],
      'es': ['Bradicardia', 'Fatiga', 'Hipotensión', 'Broncoespasmo (asma)', 'Extremidades frías', 'Insomnio'],
    },
  ),

  DrugModel(
    id: 'hidralazina',
    group: 'Cardiovascular y HTA',
    name: 'Hidralazina',
    className: {'pt': 'Vasodilatador arterial direto', 'es': 'Vasodilatador arterial directo'},
    category: {'pt': 'Cardiovascular', 'es': 'Cardiovascular'},
    route: 'VO / IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Emergência hipertensiva (IV): 5–10 mg IV lento, repetir a cada 20–30 min se necessário (máx. 20 mg por crise). HAS crônica (VO): 25–100 mg 2–4×/dia. Pré-eclâmpsia: 5–10 mg IV a cada 20 min.',
      'es': 'Emergencia HAS (IV): 5–10 mg IV lento, repetir cada 20–30 min (máx. 20 mg). HAS crónica (VO): 25–100 mg 2–4×/día.',
    },
    renalAlert: {
      'pt': 'Ajuste cuidadoso em IR grave (acúmulo). Monitorar efeitos hemodinâmicos.',
      'es': 'Ajuste en IR grave. Monitorizar efectos hemodinámicos.',
    },
    elderlyAlert: {
      'pt': 'Iniciar com 10 mg para evitar hipotensão intensa. Taquicardia reflexa pode exacerbar angina.',
      'es': 'Iniciar con 10 mg. Taquicardia refleja puede exacerbar angina.',
    },
    mechanism: {
      'pt': 'Vasodilatação arteriolar direta → ↓ resistência vascular periférica. Preserva fluxo renal e uteroplacentário. Papel crucial na pré-eclâmpsia e na ICC com IC reduzida (combinação com nitrato).',
      'es': 'Vasodilatación arteriolar directa → ↓ RVP. Preserva flujo renal y uteroplacentario. Útil en preeclampsia.',
    },
    warning: {
      'pt': 'Taquicardia reflexa — combinar com betabloqueador. Síndrome lúpus-like em altas doses (>200 mg/dia) e acetiladores lentos. Evitar em angina isolada sem ICC. Cefaleias intensas comuns.',
      'es': 'Taquicardia refleja — combinar con betabloqueador. Síndrome lupus-like en dosis altas. Cefalea frecuente.',
    },
    adverse: {
      'pt': ['Cefaleia', 'Taquicardia reflexa', 'Flushing', 'Hipotensão', 'Náuseas', 'Síndrome lúpus-like (crônico)', 'Retenção hídrica'],
      'es': ['Cefalea', 'Taquicardia refleja', 'Flushing', 'Hipotensión', 'Náuseas', 'Síndrome lupus-like (crónico)'],
    },
  ),

  DrugModel(
    id: 'acido_valproico',
    group: 'Neurología y Psiquiatría',
    name: 'Ácido Valproico / Valproato',
    className: {'pt': 'Anticonvulsivante / estabilizador de humor', 'es': 'Anticonvulsivante / estabilizador del humor'},
    category: {'pt': 'Neurológico', 'es': 'Neurológico'},
    route: 'VO / IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Epilepsia: início 250 mg 2–3×/dia, titular para 750–3000 mg/dia (nível alvo: 50–100 mcg/mL). Status epilepticus IV: 15–45 mg/kg em 5–10 min. Transtorno bipolar: 250 mg 3×/dia → 1000–2000 mg/dia.',
      'es': 'Epilepsia: inicio 250 mg 2–3×/día, titular hasta 750–3000 mg/día (nivel: 50–100 mcg/mL). Status IV: 15–45 mg/kg en 5–10 min. Bipolar: 250 mg 3×/día → 1000–2000 mg/día.',
    },
    renalAlert: {
      'pt': 'Nível total pode subestimar fração livre em IR (↓ albumina → ↑ livre). Monitorar nível livre se IR + hipoalbuminemia.',
      'es': 'Nivel total puede subestimar fracción libre en IR con hipoalbuminemia. Monitorizar nivel libre.',
    },
    elderlyAlert: {
      'pt': 'Risco aumentado de sedação, tremor, encefalopatia e hiperamonemia. Iniciar com doses baixas. Monitorar amônia se confusão.',
      'es': 'Mayor riesgo de sedación, temblor, encefalopatía e hiperamonemia. Iniciar con dosis bajas. Monitorizar amoniaco si confusión.',
    },
    mechanism: {
      'pt': 'Mecanismo múltiplo: ↑ GABA, bloqueia canais Na+ e Ca²+ tipo T, modula sinalização neuronal. Amplo espectro anticonvulsivante (generalizado + focal).',
      'es': 'Mecanismo múltiple: ↑ GABA, bloquea Na+ y Ca²+ tipo T. Amplio espectro anticonvulsivante.',
    },
    warning: {
      'pt': '⚠ TERATOGÊNICO (espinha bífida, malformações cardíacas, déficit cognitivo) — EVITAR em mulheres em idade fértil sem contracepção adequada. Hepatotoxicidade grave (máx. risco primeiros 6 meses, crianças <2 anos). Pancreatite aguda. Trombocitopenia. Hiperamonemia (↑ amônia sem elevação de transaminases).',
      'es': '⚠ TERATOGÉNICO — EVITAR en mujeres en edad fértil. Hepatotoxicidad grave (primeros 6 meses, niños <2 años). Pancreatitis. Trombocitopenia. Hiperamonemia.',
    },
    adverse: {
      'pt': ['Náuseas/vômitos', 'Tremor (dose-dependente)', 'Ganho de peso', 'Queda de cabelo (reversível)', 'Sonolência', 'Trombocitopenia', 'Hiperamonemia/encefalopatia', 'Hepatotoxicidade grave (raro)'],
      'es': ['Náuseas/vómitos', 'Temblor (dosis-dependiente)', 'Aumento de peso', 'Caída de cabello (reversible)', 'Somnolencia', 'Trombocitopenia', 'Hiperamonemia', 'Hepatotoxicidad grave (raro)'],
    },
  ),

  DrugModel(
    id: 'atropina',
    group: 'Cardiovascular y HTA',
    name: 'Atropina',
    className: {'pt': 'Anticolinérgico — antagonista muscarínico', 'es': 'Anticolinérgico — antagonista muscarínico'},
    category: {'pt': 'UTI / Emergência', 'es': 'UCI / Emergencia'},
    route: 'IV / IM / SC',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Adulto — Bradicardia sintomática (ACLS): 1 mg IV, repetir a cada 3–5 min (máx. 3 mg). Intoxicação organofosforado: 2–4 mg IV, repetir a cada 5–10 min até secar secreções (doses altas: 20–100 mg). Pré-medicação anestesia: 0,4–0,6 mg IM/IV. | Pediátrico: 0,02 mg/kg IV/IM (mín. 0,1 mg; máx. 0,5 mg lactente / 1 mg criança), repetir a cada 5 min se necessário.',
      'es': 'Adulto — Bradicardia sintomática (ACLS): 1 mg IV, repetir cada 3–5 min (máx. 3 mg). Intox. organofosforado: 2–4 mg IV, repetir hasta secar secreciones. | Pediátrico: 0,02 mg/kg IV/IM (mín. 0,1 mg; máx. 0,5 mg lactante / 1 mg niño), repetir cada 5 min si necesario.',
    },
    renalAlert: {
      'pt': 'Eliminação renal — monitorar em IR grave. Efeitos anticolinérgicos mais intensos e prolongados.',
      'es': 'Eliminación renal — monitorizar en IR grave. Efectos anticolinérgicos más intensos.',
    },
    elderlyAlert: {
      'pt': 'Risco alto de delirium, retenção urinária, glaucoma de ângulo fechado e taquiarritmias. Usar dose mínima eficaz.',
      'es': 'Alto riesgo de delirium, retención urinaria, glaucoma ángulo cerrado y taquiarritmias.',
    },
    mechanism: {
      'pt': 'Antagonista competitivo dos receptores muscarínicos (M1–M5) → bloqueia efeitos parassimpáticos: ↑ FC (M2 cardíaco), ↓ secreções, broncodilatação, midríase, ↑ motilidade intestinal.',
      'es': 'Antagonista competitivo de receptores muscarínicos → ↑ FC, ↓ secreciones, broncodilatación, midriasis.',
    },
    warning: {
      'pt': 'Doses subótimas (<0,5 mg) podem causar bradicardia paradoxal. Contraindicada em glaucoma ângulo fechado, obstrução prostática, megacólon. Taquicardia em cardiopatas isquêmicos pode piorar isquemia.',
      'es': 'Dosis subóptimas (<0,5 mg) pueden causar bradicardia paradójica. Contraindicada en glaucoma ángulo cerrado.',
    },
    adverse: {
      'pt': ['Taquicardia', 'Boca seca', 'Retenção urinária', 'Visão turva (midríase)', 'Pele seca e quente', 'Constipação', 'Delirium (idosos)', 'Glaucoma ângulo fechado', 'Confusão mental'],
      'es': ['Taquicardia', 'Boca seca', 'Retención urinaria', 'Visión borrosa (midriasis)', 'Piel seca y caliente', 'Estreñimiento', 'Delirium (ancianos)', 'Confusión mental'],
    },
  ),

  DrugModel(
    id: 'naloxona',
    group: 'Varios / Antídotos / Otros',
    name: 'Naloxona',
    className: {'pt': 'Antagonista opioide — antídoto', 'es': 'Antagonista opioide — antídoto'},
    category: {'pt': 'UTI / Emergência', 'es': 'UCI / Emergencia'},
    route: 'IV / IM / SC / IN',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Depressão respiratória por opioides: 0,4–2 mg IV/IM, repetir a cada 2–3 min se necessário (máx. 10 mg). Intransal: 4 mg (0,1 mL em cada narina). Infusão contínua (opioides de longa duração): 2/3 da dose-resposta por hora.',
      'es': 'Depresión respiratoria por opioides: 0,4–2 mg IV/IM, repetir cada 2–3 min (máx. 10 mg). Intranasal: 4 mg. Infusión: 2/3 dosis-respuesta por hora.',
    },
    renalAlert: {
      'pt': 'Sem ajuste específico necessário. Meia-vida 30–81 min — mais curta que maioria dos opioides (risco de renarcotização).',
      'es': 'Sin ajuste específico. Semivida 30–81 min — más corta que la mayoría de opioides (riesgo de renarcotización).',
    },
    elderlyAlert: {
      'pt': 'Monitorização contínua após reversão — risco de renarcotização. Reversão abrupta pode causar edema pulmonar agudo e arritmia.',
      'es': 'Monitorización continua tras reversión — riesgo de renarcotización. Reversión brusca puede causar EAP y arritmia.',
    },
    mechanism: {
      'pt': 'Antagonista competitivo com alta afinidade pelos receptores μ, κ e δ-opioide → reverte analgesia, sedação e depressão respiratória. Sem efeitos agonistas próprios.',
      'es': 'Antagonista competitivo de receptores μ, κ, δ-opioide → revierte analgesia, sedación y depresión respiratoria.',
    },
    warning: {
      'pt': 'Meia-vida CURTA (30 min IV) → opioides de longa ação precisam de infusão contínua ou repetição. Síndrome de abstinência aguda em dependentes. Renarcotização após 30–60 min — monitorar sempre. Edema pulmonar agudo não cardiogênico (raro, reversão rápida).',
      'es': 'Semivida CORTA → opioides de acción larga requieren infusión continua. Síndrome de abstinencia aguda en dependientes. Renarcotización después de 30–60 min.',
    },
    adverse: {
      'pt': ['Síndrome de abstinência (dependentes)', 'Agitação/agressividade', 'Náuseas/vômitos', 'Hipertensão', 'Taquicardia', 'Edema pulmonar (raro)', 'Renarcotização'],
      'es': ['Síndrome de abstinencia (dependientes)', 'Agitación/agresividad', 'Náuseas/vómitos', 'Hipertensión', 'Taquicardia', 'Edema pulmonar (raro)'],
    },
  ),

  DrugModel(
    id: 'gluconato_calcio',
    group: 'Endocrinología y Metabolismo',
    name: 'Gluconato de Cálcio',
    className: {'pt': 'Eletrólito — estabilizador de membrana cardíaca', 'es': 'Electrolito — estabilizador de membrana cardíaca'},
    category: {'pt': 'UTI / Emergência', 'es': 'UCI / Emergencia'},
    route: 'IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Hipercalemia grave (proteção cardíaca): 1–2 g IV em 5–10 min (10–20 mL de sol. 10%). Repetir em 5 min se alterações ECG persistirem. Hipocalcemia sintomática: 1–2 g IV lento. Antídoto MgSO4: 1 g IV em 3 min. Antagonismo bloqueador Ca²+: 1–3 g IV.',
      'es': 'Hiperpotasemia grave (protección cardíaca): 1–2 g IV en 5–10 min. Repetir si alteraciones ECG persisten. Hipocalcemia sintomática: 1–2 g IV lento. Antídoto MgSO4: 1 g IV en 3 min.',
    },
    renalAlert: {
      'pt': 'Hipercalcemia frequente em IR — monitorar Ca sérico. Deposição vascular/tecidual em IR crônica.',
      'es': 'Hipercalcemia frecuente en IR — monitorizar Ca sérico. Deposición vascular en IR crónica.',
    },
    elderlyAlert: {
      'pt': 'Risco de hipercalcemia. Infusão rápida pode causar bradicardia, especialmente com digoxina.',
      'es': 'Riesgo de hipercalcemia. Infusión rápida puede causar bradicardia, especialmente con digoxina.',
    },
    mechanism: {
      'pt': 'Fornece Ca²+ exógeno → estabiliza potencial de membrana cardíaca (limiar de excitabilidade) durante hipercalemia grave → ação em 1–3 min por 30–60 min. Não reduz K+ sérico (apenas protege o coração).',
      'es': 'Ca²+ exógeno → estabiliza potencial de membrana cardíaca durante hiperpotasemia grave → acción en 1–3 min por 30–60 min. No reduce K sérico.',
    },
    warning: {
      'pt': 'Não reduz K+ sérico — associar insulina+glicose, bicarbonato, kayexalate/patiromer. Bradicardia/assistolia em infusão IV rápida. Contraindicado com digoxina (potencializa toxicidade). Extravasamento: necrose tecidual. Não misturar com bicarbonato (precipita).',
      'es': 'No reduce K sérico — asociar insulina+glucosa, bicarbonato. Bradicardia/asistolia en infusión IV rápida. Contraindicado con digoxina. No mezclar con bicarbonato (precipita).',
    },
    adverse: {
      'pt': ['Bradicardia (infusão rápida)', 'Hipercalcemia', 'Náuseas', 'Flushing', 'Necrose tecidual (extravasamento)', 'Arritmia com digoxina'],
      'es': ['Bradicardia (infusión rápida)', 'Hipercalcemia', 'Náuseas', 'Flushing', 'Necrosis tisular (extravasación)'],
    },
  ),

  DrugModel(
    id: 'tiamina',
    group: 'Hematología y Vitaminas',
    name: 'Tiamina (Vitamina B1)',
    className: {'pt': 'Vitamina / coenzima essencial', 'es': 'Vitamina / coenzima esencial'},
    category: {'pt': 'Neurologia / UTI', 'es': 'Neurología / UCI'},
    route: 'IV / IM / VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Wernicke (urgência): 500 mg IV 3×/dia × 2–3 dias, depois 100 mg/dia VO. Profilaxia em alcoólatra antes de glicose: 200 mg IV. Reposição crônica: 100 mg/dia VO.',
      'es': 'Encefalopatía Wernicke (urgencia): 500 mg IV 3×/día × 2–3 días, después 100 mg/día VO. Profilaxis en alcohólico antes de glucosa: 200 mg IV.',
    },
    renalAlert: {'pt': 'Hidrossolúvel — sem ajuste renal.', 'es': 'Hidrosoluble — sin ajuste renal.'},
    elderlyAlert: {'pt': 'Wernicke subdiagnosticado em idosos — suspeitar em confusão + desnutrição.', 'es': 'Wernicke infradiagnosticado en ancianos — sospechar en confusión + desnutrición.'},
    mechanism: {
      'pt': 'Coenzima da piruvato desidrogenase e alfa-cetoglutarato desidrogenase — essencial no metabolismo oxidativo da glicose. Deficiência → falência energética cerebral → lesão irreversível.',
      'es': 'Coenzima de piruvato deshidrogenasa — esencial en metabolismo oxidativo glucosa. Deficiencia → fallo energético cerebral → lesión irreversible.',
    },
    warning: {
      'pt': 'SEMPRE antes da glicose em alcoólatras ou desnutridos — glicose sem tiamina pode precipitar encefalopatia de Wernicke. Tríade: confusão + oftalmoplegia + ataxia (incompleta em 90% dos casos).',
      'es': 'SIEMPRE antes de glucosa en alcohólicos/desnutridos — la glucosa sin tiamina puede precipitar Wernicke. Tríada: confusión + oftalmoplegia + ataxia.',
    },
    adverse: {
      'pt': ['Anafilaxia (IV rápido — raro)', 'Calor local (IM)', 'Náuseas (VO)', 'Prurido'],
      'es': ['Anafilaxia (IV rápido — raro)', 'Calor local (IM)', 'Náuseas (VO)'],
    },
  ),

  DrugModel(
    id: 'flumazenil',
    group: 'Varios / Antídotos / Otros',
    name: 'Flumazenil',
    className: {'pt': 'Antagonista benzodiazepínico', 'es': 'Antagonista benzodiazepínico'},
    category: {'pt': 'Antídotos / Emergência', 'es': 'Antídotos / Emergencia'},
    route: 'IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': '0,2 mg IV em 30 s; sem resposta: +0,3 mg em 30 s; depois +0,5 mg a cada 60 s (máx. 3 mg). Manutenção se re-sedação: 0,1–0,4 mg/h IV contínuo.',
      'es': '0,2 mg IV en 30 s; sin respuesta: +0,3 mg; después +0,5 mg cada 60 s (máx. 3 mg). Mantenimiento: 0,1–0,4 mg/h IV.',
    },
    renalAlert: {'pt': 'Sem ajuste — metabolismo hepático.', 'es': 'Sin ajuste — metabolismo hepático.'},
    elderlyAlert: {'pt': 'Re-sedação mais frequente — monitorar 2–4h. Meia-vida curta (1h) < BZDs usuais.', 'es': 'Re-sedación más frecuente — monitorizar 2–4h. Semivida corta (1h).'},
    mechanism: {
      'pt': 'Antagonista competitivo seletivo do receptor GABA-A no sítio BZD → reverte sedação, amnésia e depressão respiratória por BZDs em 1–2 min.',
      'es': 'Antagonista competitivo GABA-A sitio BZD → revierte sedación/depresión respiratoria BZD en 1–2 min.',
    },
    warning: {
      'pt': 'CONTRAINDICADO em dependentes de BZD — risco de convulsões graves. Meia-vida 1h menor que maioria dos BZDs: re-sedação quase certa após dose única. NÃO reverte opioides nem barbitúricos. Monitorar 2–4h após uso.',
      'es': 'CONTRAINDICADO en dependientes BZD → convulsiones graves. Semivida 1h < BZDs. NO revierte opioides ni barbitúricos. Monitorizar 2–4h.',
    },
    adverse: {
      'pt': ['Convulsões (dependentes de BZD)', 'Re-sedação', 'Náuseas/vômitos', 'Agitação, ansiedade', 'HAS transitória'],
      'es': ['Convulsiones (dependientes BZD)', 'Re-sedación', 'Náuseas/vómitos', 'Agitación', 'HTA transitoria'],
    },
  ),

  DrugModel(
    id: 'propofol',
    group: 'UCI – Críticos y Sedoanalgesia',
    name: 'Propofol',
    className: {'pt': 'Hipnótico / sedativo IV', 'es': 'Hipnótico / sedante IV'},
    category: {'pt': 'UTI / Anestesia', 'es': 'UCI / Anestesia'},
    route: 'IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Indução: 1,5–2,5 mg/kg IV (idosos: 1–1,5 mg/kg). Sedação UTI: 5–50 µg/kg/min IV contínuo (titular pelo RASS alvo). Procedimento: 0,5–1 mg/kg IV titulado.',
      'es': 'Inducción: 1,5–2,5 mg/kg IV (ancianos: 1–1,5 mg/kg). Sedación UCI: 5–50 µg/kg/min IV. Procedimiento: 0,5–1 mg/kg IV titulado.',
    },
    renalAlert: {'pt': 'Sem ajuste renal — metabolismo hepático/extrahepático. Monitorar triglicerídeos (veículo lipídico).', 'es': 'Sin ajuste renal. Monitorizar triglicéridos (vehículo lipídico).'},
    elderlyAlert: {'pt': 'Reduzir dose 30–50%. Hipotensão e apneia mais frequentes. Titulação lenta obrigatória.', 'es': 'Reducir dosis 30–50%. Hipotensión y apnea más frecuentes. Titulación lenta obligatoria.'},
    mechanism: {
      'pt': 'Potencializa receptor GABA-A → ↑ condutância Cl⁻ → hiperpolarização neuronal → sedação e hipnose dose-dependente. Início em 30–60 s. Despertar rápido por redistribuição (5–10 min).',
      'es': 'Potencia GABA-A → hiperpolarización → sedación/hipnosis. Inicio 30–60 s. Despertar rápido por redistribución.',
    },
    warning: {
      'pt': 'Hipotensão grave na indução (esp. hipovolêmicos) — ter vasopressor à beira. PRIS (Síndrome de Infusão): acidose metabólica + rabdomiólise + IC com doses >4 mg/kg/h por >48h — monitorar CK e pH. Dor à injeção em veia periférica.',
      'es': 'Hipotensión grave en inducción — vasopressor disponible. PRIS: acidosis + rabdomiólisis + IC (>4 mg/kg/h >48h) — monitorizar CK y pH.',
    },
    adverse: {
      'pt': ['Hipotensão (injeção rápida)', 'Apneia', 'Bradicardia', 'Dor à injeção', 'Hipertrigliceridemia', 'PRIS (doses altas)', 'Urina verde (raro)'],
      'es': ['Hipotensión', 'Apnea', 'Bradicardia', 'Dolor inyección', 'Hipertrigliceridemia', 'PRIS (dosis altas)', 'Orina verde (raro)'],
    },
  ),

  DrugModel(
    id: 'hidrocortisona',
    group: 'Endocrinología y Metabolismo',
    name: 'Hidrocortisona',
    className: {'pt': 'Corticosteroide natural / mineralocorticoide', 'es': 'Corticosteroide natural / mineralocorticoide'},
    category: {'pt': 'Corticosteroides / UTI', 'es': 'Corticosteroides / UCI'},
    route: 'IV / IM',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Choque séptico refratário: 200 mg/dia IV contínuo (ou 50 mg IV a cada 6h). Anafilaxia grave: 200–300 mg IV em bolus. Crise addisoniana: 100 mg IV bolus + 100 mg IV a cada 8h.',
      'es': 'Choque séptico refractario: 200 mg/día IV continuo. Anafilaxia grave: 200–300 mg IV bolus. Crisis addisoniana: 100 mg IV + 100 mg IV cada 8h.',
    },
    renalAlert: {'pt': 'Sem ajuste específico. Monitorar eletrólitos (retenção Na+, perda K+).', 'es': 'Sin ajuste específico. Monitorizar electrólitos (retención Na+, pérdida K+).'},
    elderlyAlert: {'pt': 'Confusão, hiperglicemia e infecção mais frequentes. Atividade mineralocorticoide causa edema e hipopotassemia.', 'es': 'Confusión, hiperglucemia e infección más frecuentes. Actividad mineralocorticoide → edema e hipopotasemia.'},
    mechanism: {
      'pt': 'Glicocorticoide + mineralocorticoide natural → ativa receptores GC → resposta anti-inflamatória ampla + retenção de Na+. No choque séptico refratário restaura responsividade vascular às catecolaminas.',
      'es': 'Glucocorticoide + mineralocorticoide → anti-inflamatorio + retención Na+. En choque séptico refractario restaura respuesta vascular a catecolaminas.',
    },
    warning: {
      'pt': 'No choque séptico: usar APENAS se refratário a vasopressores (SSC 2021 — grau fraco). Monitorar hiperglicemia, infecção secundária e sangramento GI. Redução gradual para evitar insuficiência adrenal de rebote.',
      'es': 'En choque séptico: solo si refractario a vasopresores (SSC 2021 — débil). Monitorizar hiperglucemia, infección secundaria y sangrado GI. Reducción gradual obligatoria.',
    },
    adverse: {
      'pt': ['Hiperglicemia', 'Hipopotassemia', 'Edema', 'Infecção oportunista', 'Psicose esteroidea', 'HAS', 'Sangramento GI'],
      'es': ['Hiperglucemia', 'Hipopotasemia', 'Edema', 'Infección oportunista', 'Psicosis esteroidea', 'HTA', 'Sangrado GI'],
    },
  ),

  DrugModel(
    id: 'oxigenio',
    group: 'UCI – Críticos y Sedoanalgesia',
    name: 'Oxigênio Suplementar',
    className: {'pt': 'Terapia respiratória', 'es': 'Terapia respiratoria'},
    category: {'pt': 'UTI / Emergência', 'es': 'UCI / Emergencia'},
    route: 'Inalatória',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Cateter nasal: 1–6 L/min (FiO₂ ~24–44%). Máscara simples: 5–10 L/min (FiO₂ ~40–60%). Máscara com reservatório: 10–15 L/min (FiO₂ ~60–90%). DPOC: SpO₂ alvo 88–92%. Demais: SpO₂ 94–98%.',
      'es': 'Cánula nasal: 1–6 L/min (FiO₂ ~24–44%). Máscara simple: 5–10 L/min. Reservorio: 10–15 L/min (FiO₂ ~90%). EPOC: SpO₂ 88–92%. Otros: 94–98%.',
    },
    renalAlert: {'pt': 'Sem ajuste necessário.', 'es': 'Sin ajuste necesario.'},
    elderlyAlert: {'pt': 'DPOC oculto frequente em idosos — iniciar O₂ controlado e monitorar CO₂ (gasometria).', 'es': 'EPOC oculta frecuente — iniciar O₂ controlado y monitorizar CO₂ (gasometría).'},
    mechanism: {
      'pt': 'Aumenta FiO₂ alveolar → ↑ gradiente de difusão O₂ → ↑ PaO₂ → ↑ SaO₂ → ↑ entrega tecidual de O₂ (DO₂ = DC × CaO₂).',
      'es': 'Aumenta FiO₂ alveolar → ↑ PaO₂ → ↑ SaO₂ → ↑ DO₂ tisular.',
    },
    warning: {
      'pt': 'DPOC: risco de hipercapnia se SpO₂ >92% (abolição do drive hipóxico). Hiperóxia prolongada → ARDS e lesão pulmonar. SpO₂ alvos individualizados. Não usar FiO₂ >60% por >48h sem avaliação.',
      'es': 'EPOC: riesgo hipercapnia si SpO₂ >92% (abolición drive hipóxico). Hiperoxia → lesión pulmonar. No usar FiO₂ >60% >48h sin evaluación.',
    },
    adverse: {
      'pt': ['Ressecamento de mucosa (alta vazão sem umidificação)', 'Hipercapnia em DPOC', 'Atelectasia de absorção', 'Toxicidade pulmonar (FiO₂ >60% >48h)'],
      'es': ['Sequedad mucosa (sin humidificación)', 'Hipercapnia en EPOC', 'Atelectasia absorción', 'Toxicidad pulmonar (FiO₂ >60% >48h)'],
    },
  ),

  DrugModel(
    id: 'glicose_hipertonica',
    group: 'Endocrinología y Metabolismo',
    name: 'Glicose Hipertônica 50%',
    className: {'pt': 'Solução glicosada hipertônica', 'es': 'Solución glucosada hipertónica'},
    category: {'pt': 'UTI / Emergência', 'es': 'UCI / Emergencia'},
    route: 'IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Hipoglicemia grave (glicemia <50 mg/dL + sintomas): 50 mL (25 g) IV em 2–5 min; repetir até glicemia >80 mg/dL. Par obrigatório com insulina na hipercalemia: 50 mL + 10 UI insulina regular IV.',
      'es': 'Hipoglucemia grave (<50 mg/dL con síntomas): 50 mL (25 g) IV en 2–5 min; repetir hasta glucemia >80 mg/dL. Par con insulina en hiperpotasemia: 50 mL + 10 UI insulina IV.',
    },
    renalAlert: {'pt': 'Sem ajuste. Monitorar glicemia a cada 30–60 min.', 'es': 'Sin ajuste. Monitorizar glucemia cada 30–60 min.'},
    elderlyAlert: {'pt': 'Hiperglicemia rebote frequente. Monitorar 60 min após administração.', 'es': 'Hiperglucemia rebote frecuente. Monitorizar 60 min post-administración.'},
    mechanism: {
      'pt': 'Fonte direta de glicose → restaura glicemia. Associada à insulina, redistribui K+ para intracelular via Na+/K+-ATPase (tratamento da hipercalemia aguda).',
      'es': 'Fuente directa de glucosa → restaura glucemia. Con insulina, redistribuye K+ intracelular vía Na+/K+-ATPasa (hiperpotasemia aguda).',
    },
    warning: {
      'pt': 'Via periférica causa flebite grave (osmolaridade ~2700 mOsm/L) — preferir veia central. Em alcoólatras/desnutridos: sempre administrar tiamina ANTES para prevenir encefalopatia de Wernicke.',
      'es': 'Vía periférica → flebitis grave (osmolaridad ~2700). Preferir vena central. En alcohólicos/desnutridos: tiamina ANTES para prevenir Wernicke.',
    },
    adverse: {
      'pt': ['Flebite (via periférica)', 'Hiperglicemia rebote', 'Hiponatremia dilucional (grandes volumes)', 'Hipopotassemia'],
      'es': ['Flebitis (vía periférica)', 'Hiperglucemia rebote', 'Hiponatremia dilucional', 'Hipopotasemia'],
    },
  ),

  DrugModel(
    id: 'ibuprofeno',
    group: 'Analgésicos y Antipiréticos',
    name: 'Ibuprofeno',
    className: {'pt': 'AINE – Inibidor COX não seletivo', 'es': 'AINE – Inhibidor COX no selectivo'},
    category: {'pt': 'Analgésicos / Anti-inflamatórios', 'es': 'Analgésicos / Antiinflamatorios'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Adulto: 400–800 mg a cada 6–8h (máx. 3200 mg/dia). Criança: 5–10 mg/kg a cada 6–8h (máx. 40 mg/kg/dia). Gotas pediátricas: 10 mg/kg/dose.',
      'es': 'Adulto: 400–800 mg cada 6–8 h (máx. 3200 mg/día). Niño: 5–10 mg/kg cada 6–8 h (máx. 40 mg/kg/día).',
    },
    renalAlert: {
      'pt': 'ClCr <30 mL/min: evitar. Pode causar redução do fluxo renal, retenção de sódio e hiperpotassemia. Monitorar função renal.',
      'es': 'ClCr <30 mL/min: evitar. Puede reducir flujo renal, retener sodio e hiperpotasemia.',
    },
    elderlyAlert: {
      'pt': 'Alto risco de sangramento GI, insuficiência renal aguda e retenção hídrica. Preferir paracetamol. Se necessário, usar menor dose com proteção gástrica.',
      'es': 'Alto riesgo de sangrado GI, IRA y retención hídrica. Preferir paracetamol.',
    },
    mechanism: {
      'pt': 'Inibe COX-1 e COX-2 de forma reversível → reduz síntese de prostaglandinas, tromboxano A2 e prostaciclinas. Ação analgésica, antipirética e anti-inflamatória.',
      'es': 'Inhibe COX-1 y COX-2 de forma reversible → reduce síntesis de prostaglandinas. Acción analgésica, antipirética y antiinflamatoria.',
    },
    warning: {
      'pt': 'Contraindicado em úlcera péptica ativa, IRA/IRC grave, 3º trimestre gestação. Risco cardiovascular aumentado (especialmente >60 anos ou doenças CV). Associar IBP se uso prolongado.',
      'es': 'Contraindicado en úlcera péptica activa, IRA/IRC grave, 3er trimestre gestación. Riesgo cardiovascular aumentado.',
    },
    adverse: {
      'pt': ['Dispepsia / náuseas', 'Sangramento GI', 'Retenção hídrica', 'HAS', 'Risco CV aumentado', 'IRA (nefrotóxico)', 'Broncoespasmo (ASA-intolerantes)'],
      'es': ['Dispepsia / náuseas', 'Sangrado GI', 'Retención hídrica', 'HTA', 'Riesgo CV aumentado', 'IRA (nefrotóxico)', 'Broncoespasmo'],
    },
  ),

  DrugModel(
    id: 'cetoprofeno',
    group: 'Analgésicos y Antipiréticos',
    name: 'Cetoprofeno',
    className: {'pt': 'AINE – Inibidor COX não seletivo (derivado do ácido propiônico)', 'es': 'AINE – Inhibidor COX no selectivo (derivado del ácido propiónico)'},
    category: {'pt': 'Analgésicos / Anti-inflamatórios', 'es': 'Analgésicos / Antiinflamatorios'},
    route: 'VO / IV / IM / Tópico',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'VO: 50–100 mg a cada 8–12h (máx. 300 mg/dia). IV/IM: 100 mg a cada 8–12h. Gel tópico: aplicar 2–3×/dia nas áreas afetadas.',
      'es': 'VO: 50–100 mg cada 8–12 h (máx. 300 mg/día). IV/IM: 100 mg cada 8–12 h. Gel tópico: aplicar 2–3×/día.',
    },
    renalAlert: {
      'pt': 'Evitar em insuficiência renal moderada a grave. ClCr <30 mL/min: contraindicado.',
      'es': 'Evitar en insuficiencia renal moderada a grave. ClCr <30 mL/min: contraindicado.',
    },
    elderlyAlert: {
      'pt': 'Maior sensibilidade a efeitos GI e renais. Usar menor dose e menor duração. Associar IBP.',
      'es': 'Mayor sensibilidad a efectos GI y renales. Usar menor dosis y duración. Asociar IBP.',
    },
    mechanism: {
      'pt': 'Inibição reversível de COX-1 e COX-2. Potente anti-inflamatório, analgésico e antipirético. Também inibe a lipoxigenase (efeito leucotrieno).',
      'es': 'Inhibición reversible de COX-1 y COX-2. Potente antiinflamatorio, analgésico y antipirético. También inhibe lipoxigenasa.',
    },
    warning: {
      'pt': 'Risco aumentado de sangramento GI. Evitar em pós-operatório de revascularização coronária (CABG). Fotossensibilidade com uso tópico.',
      'es': 'Riesgo aumentado de sangrado GI. Evitar en post-CABG. Fotosensibilidad con uso tópico.',
    },
    adverse: {
      'pt': ['Dispepsia', 'Úlcera péptica', 'Sangramento GI', 'Retenção hídrica', 'Insuficiência renal', 'Fotossensibilidade (tópico)', 'Rash'],
      'es': ['Dispepsia', 'Úlcera péptica', 'Sangrado GI', 'Retención hídrica', 'Insuficiencia renal', 'Fotosensibilidad (tópico)'],
    },
  ),

  DrugModel(
    id: 'diclofenaco',
    group: 'Analgésicos y Antipiréticos',
    name: 'Diclofenaco de Sódio / Potássio',
    className: {'pt': 'AINE – Inibidor COX preferencial COX-2 (derivado do ácido fenilacético)', 'es': 'AINE – Inhibidor COX preferencial COX-2'},
    category: {'pt': 'Analgésicos / Anti-inflamatórios', 'es': 'Analgésicos / Antiinflamatorios'},
    route: 'VO / IV / IM / Tópico / Supositório',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'VO: 50 mg 2–3×/dia ou 75 mg 2×/dia (SR) — máx. 150 mg/dia. IM: 75 mg 1–2×/dia (máx. 150 mg/dia — evitar uso >2 dias). IV hospitalar: 75 mg em 100 mL SF em 30–120 min.',
      'es': 'VO: 50 mg 2–3×/día o 75 mg 2×/día (SR) — máx. 150 mg/día. IM: 75 mg 1–2×/día. IV: 75 mg en 100 mL SF en 30–120 min.',
    },
    renalAlert: {
      'pt': 'ClCr <30 mL/min: evitar. Potassio: risco adicional de hiperpotassemia.',
      'es': 'ClCr <30 mL/min: evitar. Potasio: riesgo adicional de hiperpotasemia.',
    },
    elderlyAlert: {
      'pt': 'Risco GI e cardiovascular elevado. Evitar uso crônico sem proteção gástrica. Preferir dose mínima efetiva.',
      'es': 'Riesgo GI y cardiovascular elevado. Evitar uso crónico sin protección gástrica.',
    },
    mechanism: {
      'pt': 'Inibe COX-1 e COX-2 (com preferência por COX-2). Reduz prostaglandinas inflamatórias. Inibe também o ácido araquidônico pela via lipoxigenase.',
      'es': 'Inhibe COX-1 y COX-2 (con preferencia por COX-2). Reduce prostaglandinas inflamatorias.',
    },
    warning: {
      'pt': 'Risco CV aumentado (especialmente com doses altas ou uso prolongado — similar aos coxibes). Hepatotoxicidade relatada. Evitar na gestação (especialmente 3º trimestre — fechamento prematuro do canal arterial).',
      'es': 'Riesgo CV aumentado (dosis altas/uso prolongado). Hepatotoxicidad reportada. Evitar en gestación (3er trimestre).',
    },
    adverse: {
      'pt': ['Dispepsia / náuseas', 'Úlcera péptica', 'Sangramento GI', 'Elevação de transaminases', 'Retenção hídrica', 'Risco CV', 'Reação no sítio de injeção (IM)'],
      'es': ['Dispepsia / náuseas', 'Úlcera péptica', 'Sangrado GI', 'Elevación transaminasas', 'Retención hídrica', 'Riesgo CV'],
    },
  ),

  DrugModel(
    id: 'tenoxicam',
    group: 'Analgésicos y Antipiréticos',
    name: 'Tenoxicam',
    className: {'pt': 'AINE – Oxicam (inibidor COX não seletivo de longa ação)', 'es': 'AINE – Oxicam (inhibidor COX no selectivo de larga acción)'},
    category: {'pt': 'Analgésicos / Anti-inflamatórios', 'es': 'Analgésicos / Antiinflamatorios'},
    route: 'VO / IV / IM',
    doseType: 'fixed',
    fixedDose: {
      'pt': '20 mg/dia (dose única diária — meia-vida longa ~60h). IV/IM: 20–40 mg/dia. Artrite reumatoide: 20 mg/dia VO.',
      'es': '20 mg/día (dosis única diaria — t½ ~60 h). IV/IM: 20–40 mg/día.',
    },
    renalAlert: {
      'pt': 'Evitar em ClCr <30 mL/min. Usar com cautela em disfunção renal leve a moderada.',
      'es': 'Evitar en ClCr <30 mL/min. Usar con cautela en disfunción renal leve a moderada.',
    },
    elderlyAlert: {
      'pt': 'Meia-vida longa aumenta risco de acúmulo. Usar dose mínima (10 mg/dia). Alto risco GI.',
      'es': 'Semivida larga aumenta riesgo de acumulación. Usar dosis mínima (10 mg/día). Alto riesgo GI.',
    },
    mechanism: {
      'pt': 'Inibe reversível de COX-1 e COX-2. Meia-vida longa (~72h) permite dosagem única diária. Efeito anti-inflamatório, analgésico e antipirético.',
      'es': 'Inhibición reversible de COX-1 y COX-2. Semivida larga (~72 h) permite dosis única diaria.',
    },
    warning: {
      'pt': 'Risco GI elevado por meia-vida longa. Evitar em úlcera péptica ativa. Interação com anticoagulantes (aumenta risco de sangramento).',
      'es': 'Riesgo GI elevado por semivida larga. Evitar en úlcera péptica activa. Interacción con anticoagulantes.',
    },
    adverse: {
      'pt': ['Dispepsia', 'Úlcera péptica', 'Sangramento GI', 'Insuficiência renal', 'Retenção hídrica', 'Rash'],
      'es': ['Dispepsia', 'Úlcera péptica', 'Sangrado GI', 'Insuficiencia renal', 'Retención hídrica', 'Rash'],
    },
  ),

  DrugModel(
    id: 'naproxeno',
    group: 'Analgésicos y Antipiréticos',
    name: 'Naproxeno',
    className: {'pt': 'AINE – Inibidor COX não seletivo (derivado do ácido propiônico)', 'es': 'AINE – Inhibidor COX no selectivo (derivado del ácido propiónico)'},
    category: {'pt': 'Analgésicos / Anti-inflamatórios', 'es': 'Analgésicos / Antiinflamatorios'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': '250–500 mg 2×/dia (máx. 1250 mg/dia no 1º dia, depois 1000 mg/dia). Gota aguda: 750 mg inicial, depois 250 mg 8/8h. Dismenorreia: 500 mg inicial, 250 mg 6–8h.',
      'es': '250–500 mg 2×/día (máx. 1250 mg/día 1er día, luego 1000 mg/día). Gota aguda: 750 mg inicial, luego 250 mg c/8 h.',
    },
    renalAlert: {
      'pt': 'ClCr <30 mL/min: evitar. Pode causar IRA especialmente em associação com diuréticos/IECA.',
      'es': 'ClCr <30 mL/min: evitar. Puede causar IRA especialmente con diuréticos/IECA.',
    },
    elderlyAlert: {
      'pt': 'Risco CV menor que outros AINEs (dados Nurses Health Study). Mesmo assim, precaução GI e renal. Meia-vida moderada (~12–17h).',
      'es': 'Menor riesgo CV comparado con otros AINEs. Precaución GI y renal. Semivida ~12–17 h.',
    },
    mechanism: {
      'pt': 'Inibe COX-1 e COX-2 de forma reversível e não seletiva. Perfil CV levemente mais seguro por menor efeito na COX-2 vascular.',
      'es': 'Inhibe COX-1 y COX-2 de forma reversible y no selectiva. Perfil CV ligeramente más seguro.',
    },
    warning: {
      'pt': 'Evitar em gestação (especialmente 3º trimestre). Não usar em pós-CABG. Risco de ulceração GI especialmente em > 65 anos.',
      'es': 'Evitar en gestación (3er trimestre). No usar en post-CABG. Riesgo de úlcera GI especialmente en >65 años.',
    },
    adverse: {
      'pt': ['Dispepsia', 'Úlcera péptica', 'Sangramento GI', 'Cefaleia', 'Tontura', 'Retenção hídrica', 'Rash'],
      'es': ['Dispepsia', 'Úlcera péptica', 'Sangrado GI', 'Cefalea', 'Mareo', 'Retención hídrica', 'Rash'],
    },
  ),

  DrugModel(
    id: 'nimesulida',
    group: 'Analgésicos y Antipiréticos',
    name: 'Nimesulida',
    className: {'pt': 'AINE – Inibidor COX-2 preferencial (sulfonamida)', 'es': 'AINE – Inhibidor COX-2 preferencial (sulfonamida)'},
    category: {'pt': 'Analgésicos / Anti-inflamatórios', 'es': 'Analgésicos / Antiinflamatorios'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Adulto: 100 mg 2×/dia (máx. 200 mg/dia) — uso máximo 15 dias. Uso pediátrico >12 anos: mesma dose. NÃO usar em <12 anos (hepatotoxicidade).',
      'es': 'Adulto: 100 mg 2×/día (máx. 200 mg/día) — máximo 15 días. NO usar en <12 años (hepatotoxicidad).',
    },
    renalAlert: {
      'pt': 'ClCr <30 mL/min: contraindicado. Usar com cautela em IRC leve a moderada.',
      'es': 'ClCr <30 mL/min: contraindicado. Usar con cautela en IRC leve a moderada.',
    },
    elderlyAlert: {
      'pt': 'Risco elevado de hepatotoxicidade. Preferir AINEs com melhor perfil de segurança em idosos.',
      'es': 'Riesgo elevado de hepatotoxicidad. Preferir AINEs con mejor perfil de seguridad en ancianos.',
    },
    mechanism: {
      'pt': 'Preferência por inibição de COX-2. Também inibe fosfodiesterase IV, ativação de neutrófilos e produção de histamina.',
      'es': 'Preferencia por inhibición de COX-2. También inhibe fosfodiesterasa IV, activación neutrófilos y producción de histamina.',
    },
    warning: {
      'pt': 'PROIBIDA em crianças <12 anos (risco de síndrome de Reye e hepatotoxicidade grave). Retirada de vários mercados europeus por hepatotoxicidade. Uso máximo de 15 dias contínuos.',
      'es': 'PROHIBIDA en niños <12 años (riesgo síndrome Reye y hepatotoxicidad grave). Retirada de varios mercados europeos. Uso máximo 15 días continuos.',
    },
    adverse: {
      'pt': ['Hepatotoxicidade (potencialmente grave)', 'Dispepsia', 'Náuseas', 'Rash', 'Prurido', 'Insuficiência renal', 'Retenção hídrica'],
      'es': ['Hepatotoxicidad (potencialmente grave)', 'Dispepsia', 'Náuseas', 'Rash', 'Prurito', 'Insuficiencia renal'],
    },
  ),

  DrugModel(
    id: 'celecoxibe',
    group: 'Analgésicos y Antipiréticos',
    name: 'Celecoxibe',
    className: {'pt': 'AINE – Inibidor seletivo COX-2 (coxibe)', 'es': 'AINE – Inhibidor selectivo COX-2 (coxib)'},
    category: {'pt': 'Analgésicos / Anti-inflamatórios', 'es': 'Analgésicos / Antiinflamatorios'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Osteoartrite: 200 mg/dia ou 100 mg 2×/dia. AR/Espondilite: 100–200 mg 2×/dia (máx. 400 mg/dia). Dor aguda: 400 mg no 1º dia, depois 200 mg 2×/dia.',
      'es': 'Osteoartritis: 200 mg/día o 100 mg 2×/día. AR/Espondilitis: 100–200 mg 2×/día (máx. 400 mg/día). Dolor agudo: 400 mg 1er día, luego 200 mg 2×/día.',
    },
    renalAlert: {
      'pt': 'TFG <30 mL/min: evitar. Risco de retenção hídrica e hiperpotassemia (mesmo sendo COX-2 seletivo).',
      'es': 'TFG <30 mL/min: evitar. Riesgo de retención hídrica e hiperpotasemia.',
    },
    elderlyAlert: {
      'pt': 'Menor risco GI comparado aos AINEs não seletivos. Porém risco CV elevado, especialmente em doses altas. Usar dose mínima efetiva.',
      'es': 'Menor riesgo GI vs AINEs no selectivos. Riesgo CV elevado en dosis altas. Usar dosis mínima efectiva.',
    },
    mechanism: {
      'pt': 'Inibe seletivamente COX-2 (induzível por inflamação) poupando COX-1 (gástrica e plaquetária). Reduz prostaglandinas inflamatórias sem reduzir tromboxano A2.',
      'es': 'Inhibe selectivamente COX-2 (inducible por inflamación) preservando COX-1 (gástrica y plaquetaria).',
    },
    warning: {
      'pt': 'Risco cardiovascular aumentado (IAM, AVC) — similar ao rofecoxibe. Contraindicado em doença cardiovascular estabelecida ou alto risco CV. Sulfa-alergias: contraindicado (contém estrutura sulfonamida).',
      'es': 'Riesgo cardiovascular aumentado (IAM, AVC). Contraindicado en ECV establecida o alto riesgo CV. Alergia a sulfa: contraindicado.',
    },
    adverse: {
      'pt': ['Risco CV aumentado (IAM, AVC)', 'HAS', 'Retenção hídrica', 'Dispepsia (menor que AINEs tradicionais)', 'Cefaleia', 'Rash', 'Reação de hipersensibilidade a sulfa'],
      'es': ['Riesgo CV aumentado (IAM, AVC)', 'HTA', 'Retención hídrica', 'Dispepsia (menor que AINEs trad.)', 'Cefalea', 'Rash'],
    },
  ),

  DrugModel(
    id: 'aas',
    group: 'Cardiovascular y HTA',
    name: 'Ácido Acetilsalicílico (AAS / Aspirina)',
    className: {'pt': 'AINE – Salicilato / Antiagregante plaquetário irreversível', 'es': 'AINE – Salicilato / Antiagregante plaquetario irreversible'},
    category: {'pt': 'Analgésicos / Antiagregantes', 'es': 'Analgésicos / Antiagregantes'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Antiagregante: 100 mg/dia (manutenção). Carga no SCA/AVC isquêmico: 300 mg VO (mastigar). Analgesia/antitérmico: 500–1000 mg a cada 4–6h (máx. 4 g/dia). Pericardite: 750 mg–1 g cada 8h.',
      'es': 'Antiagregante: 100 mg/día (mantenimiento). Carga en SCA/AVC isquémico: 300 mg VO (masticar). Analgesia/antitérmico: 500–1000 mg cada 4–6 h (máx. 4 g/día). Pericarditis: 750 mg–1 g c/8 h.',
    },
    renalAlert: {
      'pt': 'ClCr <10 mL/min: evitar doses analgésicas. Doses antiagregantes (100 mg/dia) geralmente toleradas com monitoramento.',
      'es': 'ClCr <10 mL/min: evitar dosis analgésicas. Dosis antiagregantes (100 mg/día) generalmente toleradas con monitoreo.',
    },
    elderlyAlert: {
      'pt': 'Risco aumentado de sangramento GI e hemorragia intracraniana. Associar IBP em uso crônico. Benefício/risco deve ser avaliado individualmente.',
      'es': 'Mayor riesgo de sangrado GI y hemorragia intracraneal. Asociar IBP en uso crónico.',
    },
    mechanism: {
      'pt': 'Acetila irreversivelmente COX-1 e COX-2 → inibe TXA2 plaquetário (antiagregante permanente — dura vida da plaqueta ~7–10 dias). Em doses altas, inibe PGI2 e prostaglandinas inflamatórias.',
      'es': 'Acetila irreversiblemente COX-1 y COX-2 → inhibe TXA2 plaquetario (antiagregante permanente — dura vida de la plaqueta ~7–10 días).',
    },
    warning: {
      'pt': 'SÍNDROME DE REYE: CONTRAINDICADO em crianças/adolescentes com febre viral (varicela, influenza). Potencia anticoagulantes. Cuidado com AINEs concomitantes (reduz efeito antiagregante). Interromper 7–10 dias antes de cirurgia eletiva.',
      'es': 'SÍNDROME DE REYE: CONTRAINDICADO en niños/adolescentes con fiebre viral. Potencia anticoagulantes. Interrumpir 7–10 días antes de cirugía electiva.',
    },
    adverse: {
      'pt': ['Sangramento GI', 'Úlcera péptica', 'Hemorragia (incluindo IC)', 'Broncoespasmo (asma aspirina-sensível)', 'Zumbido/ototoxicidade (doses altas)', 'Síndrome de Reye (crianças)', 'Reação alérgica'],
      'es': ['Sangrado GI', 'Úlcera péptica', 'Hemorragia (incluida HIC)', 'Broncoespasmo', 'Zumbido/ototoxicidad (dosis altas)', 'Síndrome de Reye (niños)'],
    },
  ),

  DrugModel(
    id: 'indometacina',
    group: 'Analgésicos y Antipiréticos',
    name: 'Indometacina',
    className: {'pt': 'AINE – Derivado indolacético (inibidor COX potente não seletivo)', 'es': 'AINE – Derivado indolacético (inhibidor COX potente no selectivo)'},
    category: {'pt': 'Analgésicos / Anti-inflamatórios', 'es': 'Analgésicos / Antiinflamatorios'},
    route: 'VO / IV (neonatal) / Supositório',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Adulto: 25–50 mg 2–3×/dia (máx. 200 mg/dia). Gota aguda: 50 mg 3×/dia por 5 dias. Neonatal (fechamento de canal arterial persistente): 0,1–0,2 mg/kg IV a cada 12–24h (3 doses).',
      'es': 'Adulto: 25–50 mg 2–3×/día (máx. 200 mg/día). Gota aguda: 50 mg 3×/día por 5 días. Neonatal (cierre CAP): 0,1–0,2 mg/kg IV c/12–24 h (3 dosis).',
    },
    renalAlert: {
      'pt': 'Evitar em IRC. Alto risco de nefrotoxicidade. No neonato: pode reduzir diurese — monitorar.',
      'es': 'Evitar en IRC. Alto riesgo de nefrotoxicidad. En neonato: puede reducir diuresis — monitorear.',
    },
    elderlyAlert: {
      'pt': 'BEERS LIST: evitar em idosos. Alto risco de SNC (confusão, alucinações), sangramento GI e nefrotoxicidade.',
      'es': 'LISTA BEERS: evitar en ancianos. Alto riesgo de SNC (confusión, alucinaciones), sangrado GI y nefrotoxicidad.',
    },
    mechanism: {
      'pt': 'Potente inibidor de COX-1 e COX-2. Inibe também a fosfolipase A2. Efeito vasoconstritor sobre o canal arterial (PGE2-dependente).',
      'es': 'Potente inhibidor de COX-1 y COX-2. Inhibe también fosfolipasa A2. Efecto vasoconstrictor sobre el canal arterial (dependiente de PGE2).',
    },
    warning: {
      'pt': 'Um dos AINEs mais gastrotóxicos. Cruzar uso com anticoagulantes aumenta muito o risco de sangramento. Pode precipitar insuficiência renal aguda em neonatos.',
      'es': 'Uno de los AINEs más gastrotóxicos. Uso con anticoagulantes aumenta riesgo de sangrado. Puede precipitar IRA en neonatos.',
    },
    adverse: {
      'pt': ['Cefaleia / tontura (frequentes)', 'Confusão mental (idosos)', 'Úlcera péptica / sangramento', 'Nefrotoxicidade', 'Retenção hídrica / HAS', 'Hepatotoxicidade (raro)'],
      'es': ['Cefalea / mareo (frecuentes)', 'Confusión mental (ancianos)', 'Úlcera péptica / sangrado', 'Nefrotoxicidad', 'Retención hídrica / HTA'],
    },
  ),

  DrugModel(
    id: 'piroxicam',
    group: 'Analgésicos y Antipiréticos',
    name: 'Piroxicam',
    className: {'pt': 'AINE – Oxicam (inibidor COX não seletivo de longa ação)', 'es': 'AINE – Oxicam (inhibidor COX no selectivo de larga acción)'},
    category: {'pt': 'Analgésicos / Anti-inflamatórios', 'es': 'Analgésicos / Antiinflamatorios'},
    route: 'VO / IM / Tópico (gel)',
    doseType: 'fixed',
    fixedDose: {
      'pt': '10–20 mg/dia (dose única). Máx. 20 mg/dia. Gel: aplicar 3–4×/dia na região afetada. NÃO ultrapassar 20 mg/dia VO.',
      'es': '10–20 mg/día (dosis única). Máx. 20 mg/día. Gel: aplicar 3–4×/día en zona afectada.',
    },
    renalAlert: {
      'pt': 'Evitar em IRC moderada a grave. Meia-vida longa (~50h) aumenta risco de acúmulo.',
      'es': 'Evitar en IRC moderada a grave. Semivida larga (~50 h) aumenta riesgo de acumulación.',
    },
    elderlyAlert: {
      'pt': 'BEERS LIST: evitar. Meia-vida muito longa → acúmulo → risco elevado de toxicidade GI e renal.',
      'es': 'LISTA BEERS: evitar. Semivida muy larga → acumulación → alto riesgo GI y renal.',
    },
    mechanism: {
      'pt': 'Inibe reversível COX-1 e COX-2. Meia-vida de ~50h permite dose única diária. Inibe também migração leucocitária.',
      'es': 'Inhibe reversiblemente COX-1 y COX-2. Semivida de ~50 h permite dosis única diaria.',
    },
    warning: {
      'pt': 'Alta incidência de complicações GI sérias devido à meia-vida prolongada. Risco de fototoxicidade (uso tópico e oral). Evitar em idosos (Beers 2023).',
      'es': 'Alta incidencia de complicaciones GI graves por semivida prolongada. Riesgo de fototoxicidad. Evitar en ancianos.',
    },
    adverse: {
      'pt': ['Dispepsia / úlcera (alta incidência)', 'Sangramento GI', 'Fototoxicidade', 'Retenção hídrica', 'Insuficiência renal', 'Rash'],
      'es': ['Dispepsia / úlcera (alta incidencia)', 'Sangrado GI', 'Fototoxicidad', 'Retención hídrica', 'Insuficiencia renal', 'Rash'],
    },
  ),

  DrugModel(
    id: 'etoricoxibe',
    group: 'Analgésicos y Antipiréticos',
    name: 'Etoricoxibe',
    className: {'pt': 'AINE – Inibidor seletivo COX-2 (coxibe de 2ª geração)', 'es': 'AINE – Inhibidor selectivo COX-2 (coxib 2ª generación)'},
    category: {'pt': 'Analgésicos / Anti-inflamatórios', 'es': 'Analgésicos / Antiinflamatorios'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Osteoartrite: 30–60 mg/dia. AR: 60 mg/dia (máx. 90 mg/dia). Gota aguda: 120 mg/dia (máx. 8 dias). Dor pós-operatória: 90–120 mg/dia (curto prazo).',
      'es': 'Osteoartritis: 30–60 mg/día. AR: 60 mg/día (máx. 90 mg/día). Gota aguda: 120 mg/día (máx. 8 días).',
    },
    renalAlert: {
      'pt': 'TFG <30 mL/min: contraindicado. Cuidado em disfunção renal moderada.',
      'es': 'TFG <30 mL/min: contraindicado. Precaución en disfunción renal moderada.',
    },
    elderlyAlert: {
      'pt': 'Menor risco GI que AINEs tradicionais. Porém risco CV aumentado. Monitorar PA — tende a elevar mais que outros AINEs.',
      'es': 'Menor riesgo GI que AINEs tradicionales. Riesgo CV aumentado. Monitorar PA — tiende a elevar más que otros AINEs.',
    },
    mechanism: {
      'pt': 'Inibe seletivamente COX-2 (potência seletiva COX-2/COX-1 de ~106:1). Reduz prostaglandinas inflamatórias. Meia-vida ~22h (dose única diária).',
      'es': 'Inhibe selectivamente COX-2 (potencia selectiva COX-2/COX-1 de ~106:1). Semivida ~22 h.',
    },
    warning: {
      'pt': 'Maior risco CV entre os coxibes (estudo MEDAL). Contraindicado em HAS não controlada, DAC, ICC, AVC/AIT prévio.',
      'es': 'Mayor riesgo CV entre los coxibes (estudio MEDAL). Contraindicado en HTA no controlada, DAC, ICC, AVC/AIT previo.',
    },
    adverse: {
      'pt': ['Risco CV elevado (IAM, AVC)', 'Elevação de PA', 'Retenção hídrica', 'Edema', 'Dispepsia (menor que AINEs trad.)', 'Cefaleia', 'Tonturas'],
      'es': ['Riesgo CV elevado (IAM, AVC)', 'Elevación de PA', 'Retención hídrica', 'Edema', 'Dispepsia (menor)', 'Cefalea'],
    },
  ),

  DrugModel(
    id: 'codeina',
    group: 'Analgésicos y Antipiréticos',
    name: 'Codeína',
    className: {'pt': 'Opioide fraco – Agonista µ (pró-fármaco da morfina)', 'es': 'Opioide débil – Agonista µ (profármaco de morfina)'},
    category: {'pt': 'Analgésicos Opioides', 'es': 'Analgésicos Opioides'},
    route: 'VO / IM (raramente)',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Adulto: 30–60 mg a cada 4–6h (máx. 360 mg/dia). Criança ≥12 anos: 0,5–1 mg/kg a cada 4–6h. NÃO usar em <12 anos (metabolizadores ultra-rápidos — risco letal).',
      'es': 'Adulto: 30–60 mg cada 4–6 h (máx. 360 mg/día). Niño ≥12 años: 0,5–1 mg/kg c/4–6 h. NO usar en <12 años.',
    },
    renalAlert: {
      'pt': 'IRC grave: reduzir dose ou evitar. Metabólito ativo (morfina-6-glucuronídeo) se acumula → risco de depressão respiratória.',
      'es': 'IRC grave: reducir dosis o evitar. Metabolito activo (morfina-6-glucurónido) se acumula → riesgo de depresión respiratoria.',
    },
    elderlyAlert: {
      'pt': 'Reduzir dose (50%). Monitorar constipação, retenção urinária e sedação excessiva.',
      'es': 'Reducir dosis (50%). Monitorear estreñimiento, retención urinaria y sedación excesiva.',
    },
    mechanism: {
      'pt': 'Pró-fármaco convertido a morfina (10%) e codeína-6-glucuronídeo via CYP2D6. Agonismo µ-opioide central → analgesia, antitussígeno, antidiarreico.',
      'es': 'Profármaco convertido a morfina (10%) y codeína-6-glucurónido vía CYP2D6. Agonismo µ-opioide central → analgesia, antitusígeno, antidiarreico.',
    },
    warning: {
      'pt': 'CONTRAINDICADO <12 anos e em amamentação. Metabolizadores ultra-rápidos do CYP2D6 convertem mais para morfina → risco de overdose. Polimorfismo genético CYP2D6 (~5–10% não respondem — metabolizadores lentos).',
      'es': 'CONTRAINDICADO <12 años y en lactancia. Metabolizadores ultrarrápidos CYP2D6 convierten más a morfina → riesgo de sobredosis. Polimorfismo genético CYP2D6.',
    },
    adverse: {
      'pt': ['Constipação (frequente)', 'Náuseas / vômitos', 'Sedação', 'Tontura', 'Dependência', 'Depressão respiratória (doses altas)', 'Retenção urinária', 'Prurido'],
      'es': ['Estreñimiento (frecuente)', 'Náuseas / vómitos', 'Sedación', 'Mareo', 'Dependencia', 'Depresión respiratoria (dosis altas)', 'Retención urinaria'],
    },
  ),

  DrugModel(
    id: 'remifentanil',
    group: 'UCI – Críticos y Sedoanalgesia',
    name: 'Remifentanil',
    className: {'pt': 'Opioide potente – Agonista µ de ação ultracurta', 'es': 'Opioide potente – Agonista µ de acción ultracorta'},
    category: {'pt': 'Analgésicos Opioides / Sedoanalgesia', 'es': 'Analgésicos Opioides / Sedoanalgesia'},
    route: 'IV (infusão contínua)',
    doseType: 'weight',
    mgKg: 0.05,
    fixedDose: {
      'pt': 'Analgesia/sedação (UTI): 0,025–0,2 mcg/kg/min em infusão contínua. Indução: 0,5–1 mcg/kg em bolus IV. Titulação guiada por resposta clínica (índice biespectral). NÃO usar em bolus repetidos para dor crônica.',
      'es': 'Analgesia/sedación (UCI): 0,025–0,2 mcg/kg/min en infusión continua. Inducción: 0,5–1 mcg/kg en bolus IV.',
    },
    renalAlert: {
      'pt': 'Seguro em IRC — metabolismo independente de órgãos (esterases inespecíficas do plasma). Não requer ajuste de dose.',
      'es': 'Seguro en IRC — metabolismo independiente de órganos (esterasas inespecíficas del plasma). No requiere ajuste de dosis.',
    },
    elderlyAlert: {
      'pt': 'Reduzir dose em 30–50%. Maior sensibilidade aos efeitos opioides. Monitorar depressão respiratória.',
      'es': 'Reducir dosis en 30–50%. Mayor sensibilidad a efectos opioides. Monitorizar depresión respiratoria.',
    },
    mechanism: {
      'pt': 'Agonista µ-opioide potente (~100× mais potente que morfina). Metabolizado por esterases plasmáticas inespecíficas → t½ ~3–5 min. Não se acumula em insuficiência renal ou hepática.',
      'es': 'Agonista µ-opioide potente (~100× más potente que morfina). Metabolizado por esterasas plasmáticas → t½ ~3–5 min. No acumula en insuficiencia renal o hepática.',
    },
    warning: {
      'pt': 'USO EXCLUSIVO HOSPITALAR — ventilação assistida disponível obrigatória. Pode causar rigidez torácica (administração em bolus rápido). Hiperalgesia induzida por opioides com uso prolongado. Interromper infusão antes de extubação — sem efeito residual.',
      'es': 'USO EXCLUSIVO HOSPITALARIO — ventilación asistida obligatoria. Puede causar rigidez torácica (bolus rápido). Hiperalgesia inducida por opioides con uso prolongado.',
    },
    adverse: {
      'pt': ['Depressão respiratória', 'Rigidez muscular / torácica', 'Bradicardia / hipotensão', 'Náuseas / vômitos', 'Hiperalgesia pós-infusão', 'Prurido'],
      'es': ['Depresión respiratoria', 'Rigidez muscular / torácica', 'Bradicardia / hipotensión', 'Náuseas / vómitos', 'Hiperalgesia post-infusión'],
    },
  ),

  DrugModel(
    id: 'petidina',
    group: 'Analgésicos y Antipiréticos',
    name: 'Petidina / Meperidina',
    className: {'pt': 'Opioide – Agonista µ (fenilpiperidina)', 'es': 'Opioide – Agonista µ (fenilpiperidina)'},
    category: {'pt': 'Analgésicos Opioides', 'es': 'Analgésicos Opioides'},
    route: 'VO / IV / IM / SC',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Adulto: 50–150 mg IM/IV a cada 3–4h. IV: 25–50 mg lento. USO LIMITADO — não recomendado em dor crônica ou em idosos (Beers). Uso obstétrico: 50–100 mg IM.',
      'es': 'Adulto: 50–150 mg IM/IV cada 3–4 h. IV: 25–50 mg lento. USO LIMITADO — no recomendado en dolor crónico ni ancianos. Uso obstétrico: 50–100 mg IM.',
    },
    renalAlert: {
      'pt': 'IRC: EVITAR. Norpetidina (metabólito) se acumula → convulsões, tremores, mioclonias.',
      'es': 'IRC: EVITAR. Norpetidina (metabolito) se acumula → convulsiones, temblores, mioclonías.',
    },
    elderlyAlert: {
      'pt': 'BEERS LIST: EVITAR em idosos. Norpetidina acumula → risco muito alto de convulsões e delirium.',
      'es': 'LISTA BEERS: EVITAR en ancianos. Norpetidina acumula → alto riesgo de convulsiones y delirium.',
    },
    mechanism: {
      'pt': 'Agonista µ-opioide. Também antagonista do receptor NMDA e inibidor de recaptação de serotonina. Metabólito ativo norpetidina (t½ 15–20h) é neuroexcitatório.',
      'es': 'Agonista µ-opioide. También antagonista receptor NMDA e inhibidor recaptación serotonina. Metabolito activo norpetidina (t½ 15–20 h) es neuroexcitatorio.',
    },
    warning: {
      'pt': 'INTERAÇÃO GRAVE com IMAO → síndrome serotoninérgica / hiperpirexia fatal. Evitar em IRC (norpetidina acumula → convulsões). Descontinuado como primeira linha em muitos protocolos.',
      'es': 'INTERACCIÓN GRAVE con IMAO → síndrome serotoninérgica / hiperpirexia fatal. Evitar en IRC. Descontinuado como primera línea en muchos protocolos.',
    },
    adverse: {
      'pt': ['Convulsões (norpetidina)', 'Delirium', 'Náuseas / vômitos', 'Constipação', 'Sedação', 'Hipotensão', 'Depressão respiratória', 'Síndrome serotoninérgica (com IMAO)'],
      'es': ['Convulsiones (norpetidina)', 'Delirium', 'Náuseas / vómitos', 'Estreñimiento', 'Sedación', 'Hipotensión', 'Depresión respiratoria'],
    },
  ),

  DrugModel(
    id: 'metadona',
    group: 'Analgésicos y Antipiréticos',
    name: 'Metadona',
    className: {'pt': 'Opioide – Agonista µ de longa ação / Antagonista NMDA', 'es': 'Opioide – Agonista µ de larga acción / Antagonista NMDA'},
    category: {'pt': 'Analgésicos Opioides / Dependência', 'es': 'Analgésicos Opioides / Dependencia'},
    route: 'VO / IV / SC',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Dependência opioides (manutenção): 20–120 mg/dia VO (dose única diária). Dor crônica: 2,5–10 mg 2–3×/dia (iniciar com dose baixa — titulação cuidadosa). IV: 2,5–5 mg a cada 8–12h.',
      'es': 'Dependencia opioides (mantenimiento): 20–120 mg/día VO (dosis única diaria). Dolor crónico: 2,5–10 mg 2–3×/día. IV: 2,5–5 mg c/8–12 h.',
    },
    renalAlert: {
      'pt': 'Geralmente seguro em IRC. Sem metabólitos ativos acumulativos. Porém, monitorar QTc — pode prolongar independente de disfunção renal.',
      'es': 'Generalmente seguro en IRC. Sin metabolitos activos acumulativos. Monitorizar QTc.',
    },
    elderlyAlert: {
      'pt': 'Meia-vida longa e variável (8–59h) — risco de acúmulo impredizível. Titular lentamente. Monitorar sedação e QTc.',
      'es': 'Semivida larga y variable (8–59 h) — riesgo de acumulación impredecible. Titular lentamente. Monitorizar sedación y QTc.',
    },
    mechanism: {
      'pt': 'Agonista µ-opioide + antagonista NMDA (útil em dor neuropática) + inibidor de recaptação de serotonina e noradrenalina. Meia-vida ~24–36h (variação enorme inter-individual).',
      'es': 'Agonista µ-opioide + antagonista NMDA (útil en dolor neuropático) + inhibidor recaptación serotonina y noradrenalina. Semivida ~24–36 h (variación enorme inter-individual).',
    },
    warning: {
      'pt': 'PROLONGA QTc → risco de Torsades de Pointes. Meia-vida imprevisível → risco de overdose tardia. Interações medicamentosas extensas (CYP3A4, CYP2D6). Iniciar com doses muito baixas e titular lentamente.',
      'es': 'PROLONGA QTc → riesgo de Torsades de Pointes. Semivida impredecible → riesgo de sobredosis tardía. Interacciones extensas (CYP3A4, CYP2D6).',
    },
    adverse: {
      'pt': ['Prolongamento QTc / Torsades', 'Depressão respiratória (tardia)', 'Constipação', 'Sedação excessiva', 'Sudorese', 'Hipotensão', 'Edema', 'Náuseas'],
      'es': ['Prolongación QTc / Torsades', 'Depresión respiratoria (tardía)', 'Estreñimiento', 'Sedación excesiva', 'Sudoración', 'Hipotensión', 'Edema'],
    },
  ),

  DrugModel(
    id: 'buprenorfina',
    group: 'Analgésicos y Antipiréticos',
    name: 'Buprenorfina',
    className: {'pt': 'Opioide – Agonista parcial µ / Antagonista κ', 'es': 'Opioide – Agonista parcial µ / Antagonista κ'},
    category: {'pt': 'Analgésicos Opioides / Dependência', 'es': 'Analgésicos Opioides / Dependencia'},
    route: 'SL / Transdérmico (adesivo) / IV / IM',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Dor crônica (adesivo): 5–20 mcg/h a cada 7 dias. SL (dor moderada): 0,2–0,4 mg a cada 6–8h. Dependência de opioides (Suboxone SL – buprenorfina + naloxona): 4–24 mg/dia SL.',
      'es': 'Dolor crónico (parche): 5–20 mcg/h cada 7 días. SL (dolor moderado): 0,2–0,4 mg c/6–8 h. Dependencia (Suboxone SL): 4–24 mg/día SL.',
    },
    renalAlert: {
      'pt': 'Mais seguro que morfina em IRC. Metabólitos pouco ativos. Ajuste de dose geralmente não necessário.',
      'es': 'Más seguro que morfina en IRC. Metabolitos poco activos. Ajuste de dosis generalmente no necesario.',
    },
    elderlyAlert: {
      'pt': 'Efeito teto para depressão respiratória (agonista parcial). Considerado mais seguro que opioides plenos em idosos. Monitorar sedação e tontura.',
      'es': 'Efecto techo para depresión respiratoria (agonista parcial). Más seguro que opioides plenos en ancianos. Monitorizar sedación y mareo.',
    },
    mechanism: {
      'pt': 'Agonista parcial µ (alta afinidade, baixa eficácia intrínseca) → efeito teto na depressão respiratória. Antagonista κ. Antagoniza efeitos de opioides plenos quando usados simultaneamente.',
      'es': 'Agonista parcial µ (alta afinidad, baja eficacia intrínseca) → efecto techo en depresión respiratoria. Antagonista κ.',
    },
    warning: {
      'pt': 'Pode precipitar abstinência em dependentes de opioides de ação curta (iniciar 12–24h após última dose de opioide). Difícil reverter com naloxona (alta afinidade). Prolonga QTc levemente.',
      'es': 'Puede precipitar abstinencia en dependientes de opioides de acción corta (iniciar 12–24 h después de última dosis). Difícil revertir con naloxona. Prolonga QTc levemente.',
    },
    adverse: {
      'pt': ['Constipação', 'Náuseas / vômitos', 'Tontura / cefaleia', 'Sedação', 'Sudorese', 'Reação local (adesivo)', 'Abstinência se interrompido abruptamente'],
      'es': ['Estreñimiento', 'Náuseas / vómitos', 'Mareo / cefalea', 'Sedación', 'Sudoración', 'Reacción local (parche)'],
    },
  ),

  DrugModel(
    id: 'fenoterol',
    group: 'Respiratorio',
    name: 'Fenoterol (Berotec)',
    className: {'pt': 'Beta-2 agonista de ação curta (SABA)', 'es': 'Beta-2 agonista de acción corta (SABA)'},
    category: {'pt': 'Sistema Respiratório', 'es': 'Sistema Respiratorio'},
    route: 'Inalatório (aerossol / nebulização)',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Crise aguda: 100–200 mcg (1–2 jatos) a cada 20 min por 3 doses, depois a cada 4–6h. Nebulização: 2,5 mg (10 gotas) em SF 3–5 mL a cada 20 min nas primeiras 3 doses.',
      'es': 'Crisis aguda: 100–200 mcg (1–2 puffs) cada 20 min por 3 dosis, luego cada 4–6 h. Nebulización: 2,5 mg en SF 3–5 mL cada 20 min primeras 3 dosis.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário. Meia-vida curta e ação predominantemente local.',
      'es': 'Sin ajuste necesario. Semivida corta y acción predominantemente local.',
    },
    elderlyAlert: {
      'pt': 'Maior risco de taquicardia e tremores. Monitorar FC e PA. Preferir salbutamol em cardiopatas.',
      'es': 'Mayor riesgo de taquicardia y temblores. Monitorizar FC y PA. Preferir salbutamol en cardiopatías.',
    },
    mechanism: {
      'pt': 'Agonista beta-2 adrenérgico seletivo → broncodilatação por relaxamento da musculatura lisa brônquica. Também ativa canais de K+ → hiperpolarização e relaxamento. Início em 5 min, pico em 30–60 min, duração 4–6h.',
      'es': 'Agonista beta-2 adrenérgico selectivo → broncodilatación por relajación musculatura lisa bronquial. Inicio en 5 min, pico en 30–60 min, duración 4–6 h.',
    },
    warning: {
      'pt': 'Menos seletivo que salbutamol — maior risco cardiovascular. Hipocalemia com doses altas (especialmente combinado com corticoides). Tolerância com uso excessivo.',
      'es': 'Menos selectivo que salbutamol — mayor riesgo cardiovascular. Hipopotasemia con dosis altas. Tolerancia con uso excesivo.',
    },
    adverse: {
      'pt': ['Taquicardia', 'Palpitações', 'Tremores finos', 'Hipocalemia', 'Cefaleia', 'Tontura', 'Hiperglicemia (doses altas)'],
      'es': ['Taquicardia', 'Palpitaciones', 'Temblores finos', 'Hipopotasemia', 'Cefalea', 'Mareo', 'Hiperglucemia (dosis altas)'],
    },
  ),

  DrugModel(
    id: 'fluticasona',
    group: 'Respiratorio',
    name: 'Fluticasona',
    className: {'pt': 'Corticoide inalatório (ICS) – Propionato/Furoato', 'es': 'Corticoide inhalado (ICS) – Propionato/Furoato'},
    category: {'pt': 'Sistema Respiratório', 'es': 'Sistema Respiratorio'},
    route: 'Inalatório (aerossol / pó seco)',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Asma leve: 100–250 mcg/dia (2×). Moderada: 250–500 mcg/dia. Grave: 500–1000 mcg/dia. DPOC: 500–1000 mcg/dia (combinado com LABA). Rinite: 50 mcg/narina 1–2×/dia.',
      'es': 'Asma leve: 100–250 mcg/día (2×). Moderada: 250–500 mcg/día. Grave: 500–1000 mcg/día. DPOC: 500–1000 mcg/día (combinado con LABA). Rinitis: 50 mcg/narina 1–2×/día.',
    },
    renalAlert: {
      'pt': 'Sem ajuste de dose. Absorção sistêmica mínima.',
      'es': 'Sin ajuste de dosis. Absorción sistémica mínima.',
    },
    elderlyAlert: {
      'pt': 'Risco de candidíase oral (bochechar após uso). Osteopenia com uso prolongado — monitorar DMO em doses altas por >6 meses.',
      'es': 'Riesgo de candidiasis oral (enjuagar después del uso). Osteopenia con uso prolongado — monitorizar DMO en dosis altas >6 meses.',
    },
    mechanism: {
      'pt': 'Liga-se a receptores glicocorticoides intracelulares → inibe síntese de citocinas inflamatórias (IL-4, IL-5, IL-13), reduz eosinófilos e hiperresponsividade brônquica. Alta potência local com baixa biodisponibilidade sistêmica.',
      'es': 'Se une a receptores glucocorticoides intracelulares → inhibe síntesis de citocinas inflamatorias (IL-4, IL-5, IL-13), reduce eosinófilos e hiperrespuesta bronquial.',
    },
    warning: {
      'pt': 'Bochechar e cuspir após inalação para prevenir candidíase oral. Não para alívio imediato (não é broncodilatador). Suprimir adrenal com doses muito altas prolongadas.',
      'es': 'Enjuagar y escupir después de inhalar para prevenir candidiasis oral. No es broncodilatador — no usar en crisis aguda.',
    },
    adverse: {
      'pt': ['Candidíase oral / faríngea', 'Rouquidão (disfonia)', 'Tosse', 'Osteoporose (doses altas, uso prolongado)', 'Supressão adrenal (doses muito altas)', 'Retardo de crescimento (crianças)'],
      'es': ['Candidiasis oral / faríngea', 'Ronquera (disfonía)', 'Tos', 'Osteoporosis (dosis altas)', 'Supresión adrenal (dosis muy altas)', 'Retraso crecimiento (niños)'],
    },
  ),

  DrugModel(
    id: 'budesonida',
    group: 'Respiratorio',
    name: 'Budesonida',
    className: {'pt': 'Corticoide inalatório (ICS) + uso sistêmico / nasal', 'es': 'Corticoide inhalado (ICS) + uso sistémico / nasal'},
    category: {'pt': 'Sistema Respiratório', 'es': 'Sistema Respiratorio'},
    route: 'Inalatório / Nasal / VO (colite)',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Asma adulto: 200–800 mcg/dia (2×). Criança: 100–400 mcg/dia. Nebulização (crupe): 2 mg dose única. Rinite alérgica: 64–256 mcg/dia (1–2×). Crupe leve-moderado: 0,5–2 mg nebulizado.',
      'es': 'Asma adulto: 200–800 mcg/día (2×). Niño: 100–400 mcg/día. Nebulización (crup): 2 mg dosis única. Rinitis: 64–256 mcg/día. Crup leve-moderado: 0,5–2 mg nebulizado.',
    },
    renalAlert: {
      'pt': 'Sem ajuste de dose. Mínima absorção sistêmica.',
      'es': 'Sin ajuste de dosis. Mínima absorción sistémica.',
    },
    elderlyAlert: {
      'pt': 'Mesmos cuidados da fluticasona. Bochechar após uso.',
      'es': 'Mismos cuidados que fluticasona. Enjuagar después del uso.',
    },
    mechanism: {
      'pt': 'Glicocorticoide de alta potência local com elevado first-pass hepático → baixa biodisponibilidade sistêmica (~10%). Inibe inflamação eosinofílica e hiperresponsividade brônquica. No crupe: reduz edema subglótico rapidamente.',
      'es': 'Glucocorticoide de alta potencia local con elevado first-pass hepático → baja biodisponibilidad sistémica (~10%). Reduce edema subglótico rápidamente en crup.',
    },
    warning: {
      'pt': 'No crupe: início de ação em 2h (mais lento que adrenalina). Bochechar após inalação. Gestação: categoria B — mais estudada em gravidez que outros ICS.',
      'es': 'En crup: inicio de acción en 2 h (más lento que adrenalina). Enjuagar después de inhalar. Gestación: categoría B — más estudiada en embarazo.',
    },
    adverse: {
      'pt': ['Candidíase oral', 'Rouquidão', 'Osteopenia (doses altas)', 'Supressão adrenal (raro)', 'Irritação nasal (uso nasal)', 'Epistaxe leve'],
      'es': ['Candidiasis oral', 'Ronquera', 'Osteopenia (dosis altas)', 'Supresión adrenal (raro)', 'Irritación nasal (uso nasal)', 'Epistaxis leve'],
    },
  ),

  DrugModel(
    id: 'aminofilina',
    group: 'Respiratorio',
    name: 'Aminofilina',
    className: {'pt': 'Xantina / Broncodilatador – Inibidor de fosfodiesterase', 'es': 'Xantina / Broncodilatador – Inhibidor de fosfodiesterasa'},
    category: {'pt': 'Sistema Respiratório', 'es': 'Sistema Respiratorio'},
    route: 'IV (infusão lenta)',
    doseType: 'weight',
    mgKg: 5.0,
    fixedDose: {
      'pt': 'Ataque: 5 mg/kg IV em 20–30 min (SE não fez teofilina nas últimas 24h). Manutenção: 0,5 mg/kg/h (adulto não fumante); 0,9 mg/kg/h (fumante); 0,25 mg/kg/h (insuficiência hepática/ICC). Nível sérico alvo: 10–20 mcg/mL.',
      'es': 'Ataque: 5 mg/kg IV en 20–30 min (si no usó teofilina últimas 24 h). Mantenimiento: 0,5 mg/kg/h (adulto no fumador); 0,9 mg/kg/h (fumador); 0,25 mg/kg/h (hepatopatía/ICC). Nivel sérico: 10–20 mcg/mL.',
    },
    renalAlert: {
      'pt': 'Usar com cautela. Monitorar nível sérico. Risco de acúmulo em IRC.',
      'es': 'Usar con cautela. Monitorizar nivel sérico. Riesgo de acumulación en IRC.',
    },
    elderlyAlert: {
      'pt': 'Clearance reduzido em idosos e ICC → aumenta toxicidade. Janela terapêutica estreita — monitorar nível sérico.',
      'es': 'Clearance reducido en ancianos e ICC → aumenta toxicidad. Ventana terapéutica estrecha — monitorizar nivel sérico.',
    },
    mechanism: {
      'pt': 'Inibe fosfodiesterase → aumento de AMPc → broncodilatação + estimulação do centro respiratório. Também antagonista de adenosina e estimulante do diafragma. Sal etilenodiamínico da teofilina (85% teofilina).',
      'es': 'Inhibe fosfodiesterasa → aumento de AMPc → broncodilatación + estimulación centro respiratorio. También antagonista de adenosina.',
    },
    warning: {
      'pt': 'JANELA TERAPÊUTICA ESTREITA: nível >20 mcg/mL → toxicidade (náuseas, arritmias, convulsões). MÚLTIPLAS INTERAÇÕES (eritromicina, quinolonas, cimetidina aumentam nível; rifampicina, fenitoína reduzem). Infusão rápida → hipotensão e arritmias.',
      'es': 'VENTANA TERAPÉUTICA ESTRECHA: nivel >20 mcg/mL → toxicidad (náuseas, arritmias, convulsiones). MÚLTIPLES INTERACCIONES. Infusión rápida → hipotensión y arritmias.',
    },
    adverse: {
      'pt': ['Taquicardia / arritmias', 'Náuseas / vômitos', 'Insônia / agitação', 'Cefaleia', 'Convulsões (toxicidade)', 'Hipotensão (infusão rápida)', 'Tremores'],
      'es': ['Taquicardia / arritmias', 'Náuseas / vómitos', 'Insomnio / agitación', 'Cefalea', 'Convulsiones (toxicidad)', 'Hipotensión (infusión rápida)'],
    },
  ),

  DrugModel(
    id: 'acebrofilina',
    group: 'Respiratorio',
    name: 'Acebrofilina',
    className: {'pt': 'Xantina associada a mucolítico (teofilina + bromexina)', 'es': 'Xantina asociada a mucolítico (teofilina + bromexina)'},
    category: {'pt': 'Sistema Respiratório', 'es': 'Sistema Respiratorio'},
    route: 'VO (xarope / cápsulas)',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Adulto: 100 mg 2–3×/dia VO. Criança 2–6 anos: 50 mg 2×/dia. Criança >6 anos: 50–100 mg 2×/dia. Formulação: broncodilatador + mucolítico em dose fixa.',
      'es': 'Adulto: 100 mg 2–3×/día VO. Niño 2–6 años: 50 mg 2×/día. Niño >6 años: 50–100 mg 2×/día.',
    },
    renalAlert: {
      'pt': 'Usar com cautela. Componente teofilínico pode acumular em IRC.',
      'es': 'Usar con cautela. Componente teofilínico puede acumular en IRC.',
    },
    elderlyAlert: {
      'pt': 'Monitorar sinais de toxicidade xantínica (palpitações, tremores, insônia).',
      'es': 'Monitorizar signos de toxicidad xantínica (palpitaciones, temblores, insomnio).',
    },
    mechanism: {
      'pt': 'Combinação de teofilina etileno-diamínica (broncodilatação via inibição de fosfodiesterase) com bromexina/acetilcisteína (fluidificação do muco via redução de pontes dissulfeto).',
      'es': 'Combinación de teofilina etilendiamínica (broncodilatación) con bromexina (fluidificación del moco).',
    },
    warning: {
      'pt': 'Evitar em pacientes com epilepsia ou arritmias cardíacas. Monitorar nível sérico de teofilina se uso prolongado. Interações com quinolonas e eritromicina.',
      'es': 'Evitar en epilepsia o arritmias. Monitorizar nivel sérico teofilina en uso prolongado.',
    },
    adverse: {
      'pt': ['Taquicardia', 'Insônia', 'Náuseas', 'Tremores', 'Cefaleia', 'Refluxo GI'],
      'es': ['Taquicardia', 'Insomnio', 'Náuseas', 'Temblores', 'Cefalea', 'Reflujo GI'],
    },
  ),

  DrugModel(
    id: 'tiotropio',
    group: 'Respiratorio',
    name: 'Tiotrópio',
    className: {'pt': 'Anticolinérgico de longa ação (LAMA) – Brometo de tiotrópio', 'es': 'Anticolinérgico de larga acción (LAMA) – Bromuro de tiotropio'},
    category: {'pt': 'Sistema Respiratório / DPOC', 'es': 'Sistema Respiratorio / EPOC'},
    route: 'Inalatório (HandiHaler / Respimat)',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'DPOC: 18 mcg/dia (HandiHaler) ou 5 mcg/dia (Respimat 2 jatos × 2,5 mcg) — 1×/dia. Asma: 5 mcg/dia (Respimat) — uso off-label em asma não controlada.',
      'es': 'EPOC: 18 mcg/día (HandiHaler) o 5 mcg/día (Respimat 2 puffs × 2,5 mcg) — 1×/día. Asma: 5 mcg/día (Respimat) — off-label.',
    },
    renalAlert: {
      'pt': 'ClCr <50 mL/min: maior exposição sistêmica. Monitorar efeitos anticolinérgicos. ClCr <30: usar com cautela.',
      'es': 'ClCr <50 mL/min: mayor exposición sistémica. Monitorizar efectos anticolinérgicos. ClCr <30: usar con cautela.',
    },
    elderlyAlert: {
      'pt': 'Risco de retenção urinária (hiperplasia prostática), constipação e boca seca. Glaucoma de ângulo fechado: contraindicado.',
      'es': 'Riesgo de retención urinaria (hiperplasia prostática), estreñimiento y boca seca. Glaucoma de ángulo cerrado: contraindicado.',
    },
    mechanism: {
      'pt': 'Antagonista muscarínico M3 de longa ação (t½ de ligação >24h) → broncodilatação sustentada por bloqueio do tônus colinérgico brônquico. Seletividade M3 > M2. Reduz exacerbações de DPOC.',
      'es': 'Antagonista muscarínico M3 de larga acción (t½ ligación >24 h) → broncodilatación sostenida. Reduce exacerbaciones de EPOC.',
    },
    warning: {
      'pt': 'NÃO é para alívio imediato (inicio ~30 min). Cuidado em glaucoma de ângulo fechado e hiperplasia prostática. Respimat: menor risco cardiovascular que HandiHaler em estudos observacionais.',
      'es': 'NO para alivio inmediato (inicio ~30 min). Precaución en glaucoma ángulo cerrado e hiperplasia prostática.',
    },
    adverse: {
      'pt': ['Boca seca (frequente)', 'Constipação', 'Retenção urinária', 'Taquicardia sinusal', 'Glaucoma de ângulo fechado (por neblina nos olhos)', 'Candidíase oral'],
      'es': ['Boca seca (frecuente)', 'Estreñimiento', 'Retención urinaria', 'Taquicardia sinusal', 'Glaucoma ángulo cerrado (por neblina en ojos)'],
    },
  ),

  DrugModel(
    id: 'salmeterol',
    group: 'Respiratorio',
    name: 'Salmeterol',
    className: {'pt': 'Beta-2 agonista de longa ação (LABA) – uso combinado com ICS', 'es': 'Beta-2 agonista de larga acción (LABA) – uso combinado con ICS'},
    category: {'pt': 'Sistema Respiratório', 'es': 'Sistema Respiratorio'},
    route: 'Inalatório (aerossol / pó seco)',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Asma/DPOC (manutenção): 50 mcg 2×/dia (SEMPRE associado a ICS em asma). Prevenção broncoespasmo induzido por exercício: 50 mcg 30 min antes. Formulações fixas: Seretide (salmeterol + fluticasona).',
      'es': 'Asma/EPOC (mantenimiento): 50 mcg 2×/día (SIEMPRE asociado a ICS en asma). Prevención broncoespasmo por ejercicio: 50 mcg 30 min antes. Formulaciones fijas: Seretide.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário.',
      'es': 'Sin ajuste necesario.',
    },
    elderlyAlert: {
      'pt': 'Monitorar FC e PA. Usar com cautela em cardiopatas.',
      'es': 'Monitorizar FC y PA. Usar con cautela en cardiopatías.',
    },
    mechanism: {
      'pt': 'Agonista beta-2 de longa ação (t½ ~12h). Cadeia lateral lipofílica → ancora no receptor por longo período. Broncodilatação sustentada. NUNCA usar isolado em asma (risco de morte — FDA black box).',
      'es': 'Agonista beta-2 de larga acción (t½ ~12 h). Broncodilatación sostenida. NUNCA usar solo en asma (riesgo de muerte — FDA black box).',
    },
    warning: {
      'pt': 'BLACK BOX FDA: NUNCA usar como monoterapia em asma — apenas combinado com ICS. NÃO é broncodilatador de resgate (ação lenta). Hipocalemia com doses altas.',
      'es': 'BLACK BOX FDA: NUNCA usar como monoterapia en asma — solo combinado con ICS. NO es broncodilatador de rescate (acción lenta).',
    },
    adverse: {
      'pt': ['Taquicardia / palpitações', 'Tremores', 'Hipocalemia', 'Cefaleia', 'Câimbras musculares', 'Broncoespasmo paradoxal (raro)'],
      'es': ['Taquicardia / palpitaciones', 'Temblores', 'Hipopotasemia', 'Cefalea', 'Calambres musculares', 'Broncoespasmo paradójico (raro)'],
    },
  ),

  DrugModel(
    id: 'formoterol',
    group: 'Respiratorio',
    name: 'Formoterol',
    className: {'pt': 'Beta-2 agonista de longa ação (LABA) – início rápido', 'es': 'Beta-2 agonista de larga acción (LABA) – inicio rápido'},
    category: {'pt': 'Sistema Respiratório', 'es': 'Sistema Respiratorio'},
    route: 'Inalatório (pó seco / aerossol)',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Manutenção: 12 mcg 2×/dia (SEMPRE + ICS em asma). Exacerbação asma (SMART therapy – Simbicort/Airsupra): dose extra de formoterol 4,5 mcg + budesonida quando necessário. DPOC: 12 mcg 2×/dia.',
      'es': 'Mantenimiento: 12 mcg 2×/día (SIEMPRE + ICS en asma). Exacerbación asma (SMART therapy): dosis extra formoterol 4,5 mcg + budesonida cuando necesario. EPOC: 12 mcg 2×/día.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário.',
      'es': 'Sin ajuste necesario.',
    },
    elderlyAlert: {
      'pt': 'Monitorar FC. Menor risco cardiovascular que salbutamol em doses equivalentes. Tremores podem ser incômodos.',
      'es': 'Monitorizar FC. Menor riesgo cardiovascular que salbutamol en dosis equivalentes.',
    },
    mechanism: {
      'pt': 'LABA com início rápido (~3 min — diferente do salmeterol). Agonismo beta-2 → broncodilatação de 12h. Menor lipofilia que salmeterol → início mais rápido. Permite uso de resgate (SMART).',
      'es': 'LABA con inicio rápido (~3 min). Agonismo beta-2 → broncodilatación de 12 h. Permite uso de rescate (SMART).',
    },
    warning: {
      'pt': 'BLACK BOX FDA (mesmo do salmeterol): NUNCA monoterapia em asma. Porém, no esquema SMART, permite uso como resgate junto com budesonida. Hipocalemia com doses altas.',
      'es': 'BLACK BOX FDA: NUNCA monoterapia en asma. En esquema SMART: permite uso de rescate con budesonida.',
    },
    adverse: {
      'pt': ['Taquicardia', 'Tremores', 'Hipocalemia', 'Cefaleia', 'Câimbras', 'Broncoespasmo paradoxal (raro)'],
      'es': ['Taquicardia', 'Temblores', 'Hipopotasemia', 'Cefalea', 'Calambres', 'Broncoespasmo paradójico (raro)'],
    },
  ),

  DrugModel(
    id: 'acetilcisteina',
    group: 'Hematología y Vitaminas',
    name: 'N-Acetilcisteína (NAC)',
    className: {'pt': 'Mucolítico / Antídoto para paracetamol / Antioxidante', 'es': 'Mucolítico / Antídoto para paracetamol / Antioxidante'},
    category: {'pt': 'Sistema Respiratório / Toxicologia', 'es': 'Sistema Respiratorio / Toxicología'},
    route: 'VO / IV / Inalatório',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Mucolítico: 600 mg/dia VO (1×) ou 200 mg 3×/dia. Antídoto paracetamol (IV): 150 mg/kg em 60 min → 50 mg/kg em 4h → 100 mg/kg em 16h. Antídoto (VO): 140 mg/kg inicial + 70 mg/kg a cada 4h × 17 doses.',
      'es': 'Mucolítico: 600 mg/día VO (1×) o 200 mg 3×/día. Antídoto paracetamol (IV): 150 mg/kg en 60 min → 50 mg/kg en 4 h → 100 mg/kg en 16 h. Antídoto (VO): 140 mg/kg inicial + 70 mg/kg c/4 h × 17 dosis.',
    },
    renalAlert: {
      'pt': 'Pode ser néfro-protetor (antioxidante renal). Usar com cautela em IRC grave via IV — risco de sobrecarga hídrica.',
      'es': 'Puede ser nefroprotector (antioxidante renal). Usar con cautela en IRC grave vía IV — riesgo de sobrecarga hídrica.',
    },
    elderlyAlert: {
      'pt': 'Bem tolerado em idosos. Pode causar náuseas via oral.',
      'es': 'Bien tolerado en ancianos. Puede causar náuseas vía oral.',
    },
    mechanism: {
      'pt': 'Precursor da glutationa → regenera estoques hepáticos de glutationa depletados pela NAPQI (metabólito tóxico do paracetamol). Via mucolítica: reduz pontes dissulfeto do muco → fluidificação. Antioxidante direto (grupamento tiol livre).',
      'es': 'Precursor de glutatión → regenera depósitos hepáticos de glutatión agotados por NAPQI. Vía mucolítica: reduce puentes disulfuro del muco → fluidificación. Antioxidante directo.',
    },
    warning: {
      'pt': 'Odor desagradável de enxofre. Via IV: reações anafilactoides (5–18% — especialmente 1ª infusão, mais frequente em asmáticos) — ter adrenalina disponível. Eficaz no antídoto de paracetamol apenas se iniciado <24h da ingestão.',
      'es': 'Olor desagradable a azufre. Vía IV: reacciones anafilactoides (5–18%) — tener adrenalina disponible. Eficaz como antídoto de paracetamol solo si iniciado <24 h de ingestión.',
    },
    adverse: {
      'pt': ['Náuseas / vômitos (VO)', 'Reação anafilactoide (IV — urticária, broncoespasmo)', 'Flush', 'Hipotensão transitória (IV rápido)', 'Odor a enxofre'],
      'es': ['Náuseas / vómitos (VO)', 'Reacción anafilactoide (IV)', 'Flush', 'Hipotensión transitoria (IV rápido)', 'Olor a azufre'],
    },
  ),

  DrugModel(
    id: 'captopril',
    group: 'Cardiovascular y HTA',
    name: 'Captopril',
    className: {'pt': 'IECA – Inibidor da enzima conversora de angiotensina (ação curta)', 'es': 'IECA – Inhibidor de la enzima convertidora de angiotensina (acción corta)'},
    category: {'pt': 'Cardiovascular / Anti-hipertensivo', 'es': 'Cardiovascular / Antihipertensivo'},
    route: 'VO / SL (urgência)',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'HAS (crônica): 12,5–25 mg 2–3×/dia (máx. 150 mg/dia). URGÊNCIA hipertensiva (SL/mastigar): 25 mg SL — aguardar 15–30 min. IC: iniciar 6,25 mg 3×/dia, titular até 50 mg 3×/dia.',
      'es': 'HAS (crónica): 12,5–25 mg 2–3×/día (máx. 150 mg/día). URGENCIA hipertensiva (SL/masticar): 25 mg SL — esperar 15–30 min. IC: iniciar 6,25 mg 3×/día, titular hasta 50 mg 3×/día.',
    },
    renalAlert: {
      'pt': 'ClCr 10–50 mL/min: 75% da dose. ClCr <10: 50% da dose. Monitorar creatinina e potássio (risco de hiperpotassemia). Evitar em estenose bilateral de artéria renal.',
      'es': 'ClCr 10–50 mL/min: 75% dosis. ClCr <10: 50% dosis. Monitorizar creatinina y potasio. Evitar en estenosis bilateral arteria renal.',
    },
    elderlyAlert: {
      'pt': 'Iniciar com doses menores (6,25 mg 2×). Maior risco de hipotensão na 1ª dose e hiperpotassemia.',
      'es': 'Iniciar con dosis menores (6,25 mg 2×). Mayor riesgo de hipotensión 1ª dosis e hiperpotasemia.',
    },
    mechanism: {
      'pt': 'Inibe ECA → reduz angiotensina II → vasodilatação arterial e venosa, reduz aldosterona → natriurese. Inibe degradação de bradicinina → efeito benéfico cardíaco + tosse como efeito adverso.',
      'es': 'Inhibe ECA → reduce angiotensina II → vasodilatación arterial y venosa, reduce aldosterona → natriuresis. Inhibe degradación de bradicinina.',
    },
    warning: {
      'pt': 'ANGIOEDEMA: descontinuar imediatamente (afrodescendentes 3–4× maior risco). Contraindicado na gestação (categoria D — teratogênico). Hiperpotassemia (monitorar K+ e creatinina). Tosse seca em ~15% (troca por BRA).',
      'es': 'ANGIOEDEMA: descontinuar inmediatamente (afrodescendientes 3–4× mayor riesgo). Contraindicado en gestación (categoría D). Hiperpotasemia. Tos seca en ~15%.',
    },
    adverse: {
      'pt': ['Tosse seca (15%)', 'Hipotensão (1ª dose)', 'Hiperpotassemia', 'Angioedema (raro, grave)', 'Piora da função renal (estenose de artéria renal)', 'Rash / prurido', 'Disgeusia (alteração do paladar)'],
      'es': ['Tos seca (15%)', 'Hipotensión (1ª dosis)', 'Hiperpotasemia', 'Angioedema (raro, grave)', 'Deterioro función renal', 'Rash / prurito', 'Disgeusia'],
    },
  ),

  DrugModel(
    id: 'nifedipino',
    group: 'Cardiovascular y HTA',
    name: 'Nifedipino',
    className: {'pt': 'Bloqueador de canal de cálcio (BCC) – Di-hidropiridina', 'es': 'Bloqueador de canal de calcio (BCC) – Dihidropiridina'},
    category: {'pt': 'Cardiovascular / Anti-hipertensivo', 'es': 'Cardiovascular / Antihipertensivo'},
    route: 'VO (liberação imediata / Retard)',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'HAS (Retard): 30–60 mg/dia VO 1×/dia. Angina: 30–90 mg/dia. NÃO usar a formulação de liberação imediata (cápsula) para urgência hipertensiva (risco de hipotensão grave e AVC).',
      'es': 'HAS (Retard): 30–60 mg/día VO 1×/día. Angina: 30–90 mg/día. NO usar formulación de liberación inmediata para urgencia hipertensiva (riesgo hipotensión grave y AVC).',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário (metabolismo hepático). Pode ser útil na doença renal hipertensiva.',
      'es': 'Sin ajuste necesario (metabolismo hepático). Puede ser útil en enfermedad renal hipertensiva.',
    },
    elderlyAlert: {
      'pt': 'Risco de hipotensão postural e edema periférico. Preferir formulação Retard (liberação controlada).',
      'es': 'Riesgo de hipotensión postural y edema periférico. Preferir formulación Retard.',
    },
    mechanism: {
      'pt': 'Bloqueia canais L de cálcio no músculo liso vascular → vasodilatação arterial periférica (reduz RVP) → queda de PA. Efeito cronotrópico e inotrópico negativo mínimo (seletividade vascular).',
      'es': 'Bloquea canales L de calcio en músculo liso vascular → vasodilatación arterial periférica → reducción PA. Mínimo efecto cronotrópico e inotrópico negativo.',
    },
    warning: {
      'pt': 'CÁPSULA DE LIBERAÇÃO IMEDIATA: CONTRAINDICADA para urgência hipertensiva (hipotensão severa, reflexo taquicardia, AVC isquêmico). Formulação Retard (liberação prolongada) é SEGURA. Interação com suco de toranja (grapefruit) — aumenta níveis.',
      'es': 'CÁPSULA LIBERACIÓN INMEDIATA: CONTRAINDICADA para urgencia hipertensiva. Formulación Retard (liberación prolongada) es SEGURA. Interacción con jugo de pomelo.',
    },
    adverse: {
      'pt': ['Edema periférico (maleolar)', 'Cefaleia / flush', 'Taquicardia reflexa (liberação imediata)', 'Hipotensão', 'Constipação', 'Hiperplasia gengival (uso crônico)'],
      'es': ['Edema periférico (maleolar)', 'Cefalea / flush', 'Taquicardia refleja (lib. inmediata)', 'Hipotensión', 'Estreñimiento', 'Hiperplasia gingival (uso crónico)'],
    },
  ),

  DrugModel(
    id: 'propranolol',
    group: 'Cardiovascular y HTA',
    name: 'Propranolol',
    className: {'pt': 'Betabloqueador não seletivo (β1 + β2) – sem ASI', 'es': 'Betabloqueador no selectivo (β1 + β2) – sin ASI'},
    category: {'pt': 'Cardiovascular / Antiarrítmico', 'es': 'Cardiovascular / Antiarrítmico'},
    route: 'VO / IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'HAS/angina: 40–80 mg 2–3×/dia (máx. 320 mg/dia). Arritmia: 10–30 mg 3–4×/dia. Tireotoxicose: 20–80 mg a cada 6–8h. Profilaxia de enxaqueca: 40–160 mg/dia. Tremor essencial: 40 mg 2×/dia. IV (arritmia aguda): 0,1 mg/kg IV lento.',
      'es': 'HAS/angina: 40–80 mg 2–3×/día (máx. 320 mg/día). Arritmia: 10–30 mg 3–4×/día. Tirotoxicosis: 20–80 mg c/6–8 h. Profilaxis migraña: 40–160 mg/día. Temblor esencial: 40 mg 2×/día. IV: 0,1 mg/kg IV lento.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário (metabolismo hepático de 1ª passagem extenso). Metabolitos hidrofílicos podem acumular em IRC.',
      'es': 'Sin ajuste necesario (metabolismo hepático). Metabolitos hidrofílicos pueden acumular en IRC.',
    },
    elderlyAlert: {
      'pt': 'Risco de bradicardia, BAV e depressão/confusão mental. Preferir betabloqueadores seletivos (metoprolol, bisoprolol) em idosos.',
      'es': 'Riesgo de bradicardia, BAV y depresión/confusión mental. Preferir betabloqueadores selectivos en ancianos.',
    },
    mechanism: {
      'pt': 'Bloqueia β1 e β2 adrenérgicos → reduz FC, PA, contratilidade. β2: pode causar broncoespasmo e mascarar hipoglicemia. Lipossolúvel → atravessa BHE (efeito central: ansiolítico, antipânico).',
      'es': 'Bloquea β1 y β2 adrenérgicos → reduce FC, PA, contractilidad. β2: puede causar broncoespasmo y enmascarar hipoglucemia. Liposoluble → atraviesa BHE.',
    },
    warning: {
      'pt': 'CONTRAINDICADO em asma/DPOC (broncoespasmo por β2 bloqueio). Mascarar sintomas de hipoglicemia em diabéticos. NÃO descontinuar abruptamente (angina rebote, IAM). Cuidado em ICC descompensada.',
      'es': 'CONTRAINDICADO en asma/DPOC (broncoespasmo). Enmascara hipoglucemia en diabéticos. NO descontinuar abruptamente. Precaución en ICC descompensada.',
    },
    adverse: {
      'pt': ['Bradicardia / BAV', 'Broncoespasmo (asma/DPOC)', 'Fadiga / fraqueza', 'Extremidades frias', 'Depressão / pesadelos (efeito central)', 'Disfunção erétil', 'Hipoglicemia mascarada'],
      'es': ['Bradicardia / BAV', 'Broncoespasmo', 'Fatiga / debilidad', 'Extremidades frías', 'Depresión / pesadillas', 'Disfunción eréctil', 'Hipoglucemia enmascarada'],
    },
  ),

  DrugModel(
    id: 'hidroclorotiazida',
    group: 'Cardiovascular y HTA',
    name: 'Hidroclorotiazida (HCTZ)',
    className: {'pt': 'Diurético tiazídico – Inibidor da cotransportadora Na-Cl no túbulo distal', 'es': 'Diurético tiazídico – Inhibidor cotransportador Na-Cl en túbulo distal'},
    category: {'pt': 'Cardiovascular / Diurético', 'es': 'Cardiovascular / Diurético'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'HAS: 12,5–25 mg/dia (máx. 50 mg/dia — doses >25 mg aumentam efeitos adversos sem benefício adicional). Edema: 25–100 mg/dia em dose única matinal.',
      'es': 'HAS: 12,5–25 mg/día (máx. 50 mg/día — dosis >25 mg aumentan efectos adversos sin beneficio adicional). Edema: 25–100 mg/día en dosis única matinal.',
    },
    renalAlert: {
      'pt': 'TFG <30 mL/min: INEFICAZ como anti-hipertensivo. Preferir furosemida em IRC grave. Monitorar eletrólitos.',
      'es': 'TFG <30 mL/min: INEFICAZ como antihipertensivo. Preferir furosemida en IRC grave. Monitorizar electrolitos.',
    },
    elderlyAlert: {
      'pt': 'Risco de hiponatremia grave (especialmente em mulheres idosas). Hipocalemia. Hiperuricemia → precipitar gota. Monitorar eletrólitos.',
      'es': 'Riesgo de hiponatremia grave (especialmente mujeres ancianas). Hipopotasemia. Hiperuricemia → precipitar gota. Monitorizar electrolitos.',
    },
    mechanism: {
      'pt': 'Inibe cotransportador Na-Cl no túbulo contorcido distal → natriurese, calciúria reduzida (retém cálcio — útil em osteoporose). Redução do volume circulante → queda de PA. Efeito vasodilatador direto (crônico).',
      'es': 'Inhibe cotransportador Na-Cl en túbulo distal → natriuresis, calciuria reducida (retiene calcio). Reducción volumen circulante → reducción PA.',
    },
    warning: {
      'pt': 'Monitorar eletrólitos (K+, Na+, Mg2+). Pode elevar glicemia, colesterol e ácido úrico. Fotossensibilidade. Interação com lítio (aumenta toxicidade).',
      'es': 'Monitorizar electrolitos. Puede elevar glucemia, colesterol y ácido úrico. Fotosensibilidad. Interacción con litio.',
    },
    adverse: {
      'pt': ['Hipocalemia', 'Hiponatremia', 'Hiperuricemia / gota', 'Hiperglicemia / DM2', 'Dislipidemia', 'Fotossensibilidade', 'Disfunção erétil'],
      'es': ['Hipopotasemia', 'Hiponatremia', 'Hiperuricemia / gota', 'Hiperglucemia / DM2', 'Dislipidemia', 'Fotosensibilidad', 'Disfunción eréctil'],
    },
  ),

  DrugModel(
    id: 'clortalidona',
    group: 'Cardiovascular y HTA',
    name: 'Clortalidona',
    className: {'pt': 'Diurético tiazídico-símile – Ação prolongada', 'es': 'Diurético tiazídico-símil – Acción prolongada'},
    category: {'pt': 'Cardiovascular / Diurético', 'es': 'Cardiovascular / Diurético'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'HAS: 12,5–25 mg/dia (1×/dia pela manhã — dose máx. 25–50 mg/dia). Preferida sobre HCTZ em estudos (ALLHAT): maior t½ (~35–55h), mais eficaz na redução de eventos CV.',
      'es': 'HAS: 12,5–25 mg/día (1×/día por la mañana — dosis máx. 25–50 mg/día). Preferida sobre HCTZ en estudios (ALLHAT): mayor t½ (~35–55 h), más eficaz en reducción de eventos CV.',
    },
    renalAlert: {
      'pt': 'Ineficaz em TFG <30 mL/min. Monitorar eletrólitos.',
      'es': 'Ineficaz en TFG <30 mL/min. Monitorizar electrolitos.',
    },
    elderlyAlert: {
      'pt': 'Meia-vida muito longa → risco maior de hiponatremia acumulada. Iniciar com dose baixa (12,5 mg).',
      'es': 'Semivida muy larga → mayor riesgo de hiponatremia acumulada. Iniciar con dosis baja (12,5 mg).',
    },
    mechanism: {
      'pt': 'Similar à HCTZ (inibe Na-Cl no túbulo distal). Meia-vida ~35–55h vs 6–12h da HCTZ → cobertura mais uniforme nas 24h. Distribui-se amplamente nos eritrócitos.',
      'es': 'Similar a HCTZ. Semivida ~35–55 h vs 6–12 h de HCTZ → cobertura más uniforme 24 h.',
    },
    warning: {
      'pt': 'Preferida em diretrizes recentes sobre HCTZ para HAS (efeito anti-hipertensivo mais sustentado). Mesmos riscos de hipocalemia, hiperglicemia e hiperuricemia.',
      'es': 'Preferida en guías recientes sobre HCTZ para HAS. Mismos riesgos de hipopotasemia, hiperglucemia y hiperuricemia.',
    },
    adverse: {
      'pt': ['Hipocalemia', 'Hiponatremia', 'Hiperuricemia', 'Hiperglicemia', 'Dislipidemia', 'Fotossensibilidade', 'Câimbras'],
      'es': ['Hipopotasemia', 'Hiponatremia', 'Hiperuricemia', 'Hiperglucemia', 'Dislipidemia', 'Fotosensibilidad', 'Calambres'],
    },
  ),

  DrugModel(
    id: 'clonidina',
    group: 'Cardiovascular y HTA',
    name: 'Clonidina',
    className: {'pt': 'Anti-hipertensivo de ação central – Agonista alfa-2 adrenérgico', 'es': 'Antihipertensivo de acción central – Agonista alfa-2 adrenérgico'},
    category: {'pt': 'Cardiovascular / Anti-hipertensivo', 'es': 'Cardiovascular / Antihipertensivo'},
    route: 'VO / Adesivo transdérmico',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'HAS: 0,1–0,3 mg 2–3×/dia (máx. 2,4 mg/dia). Adesivo: Catapres-TTS 0,1–0,3 mg/24h, troca semanal. Desmame de opioides: 0,1–0,2 mg 3×/dia. Abstinência alcoólica: 0,1–0,2 mg 8/8h.',
      'es': 'HAS: 0,1–0,3 mg 2–3×/día (máx. 2,4 mg/día). Parche: 0,1–0,3 mg/24 h, cambio semanal. Destete opioides: 0,1–0,2 mg 3×/día.',
    },
    renalAlert: {
      'pt': 'ClCr <10 mL/min: reduzir dose em 50%. Metabolismo misto (hepático + renal).',
      'es': 'ClCr <10 mL/min: reducir dosis 50%. Metabolismo mixto (hepático + renal).',
    },
    elderlyAlert: {
      'pt': 'Alto risco de hipotensão postural, bradicardia e sedação. Fazer parte das listas Beers como medicação de cautela em idosos.',
      'es': 'Alto riesgo de hipotensión postural, bradicardia y sedación. Listada en Beers como medicación de precaución en ancianos.',
    },
    mechanism: {
      'pt': 'Agonista alfa-2 central (locus coeruleus e núcleo do trato solitário) → reduz tônus simpático → queda de PA, FC e resistência vascular. Também ativa receptores imidazolínicos I1.',
      'es': 'Agonista alfa-2 central → reduce tono simpático → reducción PA, FC y resistencia vascular. También activa receptores imidazolínicos I1.',
    },
    warning: {
      'pt': 'SÍNDROME DE ABSTINÊNCIA: NÃO interromper abruptamente — risco de crise hipertensiva de rebote. Reduzir gradualmente (25% a cada 2–4 dias). Sedação intensa. Boca seca.',
      'es': 'SÍNDROME DE ABSTINENCIA: NO interrumpir abruptamente — riesgo de crisis hipertensiva de rebote. Reducir gradualmente. Sedación intensa. Boca seca.',
    },
    adverse: {
      'pt': ['Sedação (frequente e intensa)', 'Boca seca', 'Hipotensão postural', 'Bradicardia', 'Constipação', 'Disfunção erétil', 'Depressão', 'Reação local (adesivo)'],
      'es': ['Sedación (frecuente e intensa)', 'Boca seca', 'Hipotensión postural', 'Bradicardia', 'Estreñimiento', 'Disfunción eréctil', 'Depresión'],
    },
  ),

  DrugModel(
    id: 'nitroprussiato',
    group: 'Cardiovascular y HTA',
    name: 'Nitroprussiato de Sódio (Nipride)',
    className: {'pt': 'Vasodilatador arterial e venoso direto – Doador de NO', 'es': 'Vasodilatador arterial y venoso directo – Donador de NO'},
    category: {'pt': 'Emergência / Cardiovascular', 'es': 'Emergencia / Cardiovascular'},
    route: 'IV (infusão contínua — proteger da luz)',
    doseType: 'weight',
    mgKg: 0.3,
    fixedDose: {
      'pt': 'Início: 0,3–0,5 mcg/kg/min IV. Titulação: aumentar 0,5 mcg/kg/min a cada 5 min. Máx. 10 mcg/kg/min. Dose usual efetiva: 3 mcg/kg/min. PROTEGER da luz (papel alumínio). Limitar a 72h para evitar toxicidade por cianeto.',
      'es': 'Inicio: 0,3–0,5 mcg/kg/min IV. Titulación: aumentar 0,5 mcg/kg/min cada 5 min. Máx. 10 mcg/kg/min. PROTEGER de la luz. Limitar a 72 h para evitar toxicidad por cianuro.',
    },
    renalAlert: {
      'pt': 'IRC: RISCO ELEVADO de acúmulo de tiocianato → confusão, convulsões. Monitorar tiocianato sérico (<10 mg/dL) se uso >24h. Evitar em IRC grave.',
      'es': 'IRC: RIESGO ELEVADO de acumulación de tiocianato → confusión, convulsiones. Monitorizar tiocianato sérico (<10 mg/dL) si uso >24 h.',
    },
    elderlyAlert: {
      'pt': 'Maior sensibilidade à hipotensão. Monitorar perfusão cerebral.',
      'es': 'Mayor sensibilidad a hipotensión. Monitorizar perfusión cerebral.',
    },
    mechanism: {
      'pt': 'Libera NO após metabolismo → ativa guanilil ciclase → GMPc → vasodilatação arteriolar e venosa. Reduz pré e pós-carga. Metabolizado a cianeto → tiocianato (excreção renal). Toxicidade por cianeto com doses altas ou prolongadas.',
      'es': 'Libera NO → activa guanilil ciclasa → GMPc → vasodilatación arteriolar y venosa. Metabolizado a cianuro → tiocianato (excreción renal).',
    },
    warning: {
      'pt': 'TOXICIDADE POR CIANETO: acidose metabólica, confusão, convulsões — tratar com hidroxocobalamina ou nitrito/tiossulfato. ROUBO CORONÁRIO em angina — preferir nitroglicerina. Proteger da luz (fotossensível).',
      'es': 'TOXICIDAD POR CIANURO: acidosis metabólica, confusión, convulsiones — tratar con hidroxocobalamina o nitrito/tiosulfato. ROBO CORONARIO en angina. Proteger de la luz.',
    },
    adverse: {
      'pt': ['Hipotensão severa', 'Toxicidade por cianeto (acidose, confusão, convulsão)', 'Toxicidade por tiocianato (IRC)', 'Roubo coronário', 'Cefaleia', 'Náuseas', 'Taquicardia reflexa'],
      'es': ['Hipotensión severa', 'Toxicidad por cianuro (acidosis, confusión, convulsión)', 'Toxicidad por tiocianato (IRC)', 'Robo coronario', 'Cefalea', 'Náuseas'],
    },
  ),

  DrugModel(
    id: 'lorazepam',
    group: 'Neurología y Psiquiatría',
    name: 'Lorazepam',
    className: {'pt': 'Benzodiazepínico', 'es': 'Benzodiazepínico'},
    category: {'pt': 'SNC / Ansiolítico', 'es': 'SNC / Ansiolítico'},
    route: 'VO / IV / IM / SL',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Ansiedade: 0,5–2 mg VO 2–3×/dia | Status epiléptico: 0,1 mg/kg IV (máx 4 mg/dose, repetir 1×) | Sedação procedimento: 2–4 mg IV lento | SL: 1–2 mg',
      'es': 'Ansiedad: 0,5–2 mg VO 2–3×/día | Estatus epiléptico: 0,1 mg/kg IV (máx 4 mg/dosis, repetir 1×) | Sedación procedimiento: 2–4 mg IV lento | SL: 1–2 mg',
    },
    frequency: {'pt': 'conforme indicação', 'es': 'según indicación'},
    renalAlert: {
      'pt': 'Metabolismo hepático; glucuronidação sem acúmulo renal significativo. Usar com cautela em IRC grave — risco de sedação prolongada.',
      'es': 'Metabolismo hepático; glucuronidación sin acumulación renal significativa. Usar con cautela en IRC grave — riesgo de sedación prolongada.',
    },
    elderlyAlert: {
      'pt': 'Beers: EVITAR rotineiramente em idosos. Risco aumentado de quedas, fraturas, sedação excessiva e comprometimento cognitivo. Se necessário, usar dose mínima por tempo limitado.',
      'es': 'Beers: EVITAR rutinariamente en adultos mayores. Riesgo aumentado de caídas, fracturas, sedación excesiva y deterioro cognitivo. Si es necesario, usar dosis mínima por tiempo limitado.',
    },
    mechanism: {
      'pt': 'Potencializa GABA-A (ação no receptor benzodiazepínico → abertura canal Cl⁻ → hiperpolarização neuronal). Sem metabólitos ativos → preferido em idosos e hepatopatas. Meia-vida 10–20 h.',
      'es': 'Potencia GABA-A (acción en receptor benzodiazepínico → apertura canal Cl⁻ → hiperpolarización neuronal). Sin metabolitos activos → preferido en ancianos y hepatópatas. Vida media 10–20 h.',
    },
    warning: {
      'pt': 'Depressão respiratória — ter flumazenil à mão. Não usar como monoanestesia em procedimentos. Tolerância e dependência física com uso prolongado. Retirada gradual obrigatória.',
      'es': 'Depresión respiratoria — tener flumazenil disponible. No usar como monoanestesia en procedimientos. Tolerancia y dependencia física con uso prolongado. Retiro gradual obligatorio.',
    },
    adverse: {
      'pt': ['Sedação', 'Amnésia anterógrada', 'Ataxia', 'Confusão (idosos)', 'Depressão respiratória (IV rápido)', 'Dependência', 'Síndrome de retirada'],
      'es': ['Sedación', 'Amnesia anterógrada', 'Ataxia', 'Confusión (ancianos)', 'Depresión respiratoria (IV rápido)', 'Dependencia', 'Síndrome de abstinencia'],
    },
  ),

  DrugModel(
    id: 'fenobarbital',
    group: 'Neurología y Psiquiatría',
    name: 'Fenobarbital',
    className: {'pt': 'Barbitúrico antiepiléptico', 'es': 'Barbitúrico antiepiléptico'},
    category: {'pt': 'SNC / Anticonvulsivante', 'es': 'SNC / Anticonvulsivante'},
    route: 'VO / IV / IM',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Adulto epilepsia: 60–180 mg/dia VO (dose única noturna) | Status epiléptico IV: ataque 15–20 mg/kg IV (máx 1 g) em 30 min; manutenção 1–4 mg/kg/dia | Neonatal: 20 mg/kg IV ataque',
      'es': 'Adulto epilepsia: 60–180 mg/día VO (dosis única nocturna) | Estatus epiléptico IV: carga 15–20 mg/kg IV (máx 1 g) en 30 min; mantenimiento 1–4 mg/kg/día | Neonatal: 20 mg/kg IV carga',
    },
    frequency: {'pt': '1–2×/dia', 'es': '1–2×/día'},
    renalAlert: {
      'pt': 'Excreção renal aumentada em pH urinário alcalino. Ajuste em TFG < 10 mL/min — reduzir dose 50%. Monitorar nível sérico (alvo 15–40 µg/mL).',
      'es': 'Excreción renal aumentada en pH urinario alcalino. Ajuste con TFG < 10 mL/min — reducir dosis 50%. Monitorear nivel sérico (objetivo 15–40 µg/mL).',
    },
    elderlyAlert: {
      'pt': 'Beers: EVITAR. Sedação excessiva, depressão cognitiva, risco de quedas. Alternativas mais seguras disponíveis. Se inevitável, dose mínima.',
      'es': 'Beers: EVITAR. Sedación excesiva, depresión cognitiva, riesgo de caídas. Alternativas más seguras disponibles. Si es inevitable, dosis mínima.',
    },
    mechanism: {
      'pt': 'Liga-se ao sítio barbitúrico do receptor GABA-A → prolonga abertura do canal Cl⁻ (vs BZD que aumentam frequência). Potente indutor CYP1A2, CYP2C, CYP3A4 → múltiplas interações. Meia-vida 70–140 h.',
      'es': 'Se une al sitio barbitúrico del receptor GABA-A → prolonga apertura del canal Cl⁻ (vs BZD que aumentan frecuencia). Potente inductor CYP1A2, CYP2C, CYP3A4 → múltiples interacciones. Vida media 70–140 h.',
    },
    warning: {
      'pt': 'Indutor enzimático potente — reduz eficácia de contraceptivos, anticoagulantes, HIV, antiepiléticos. Fármaco de faixa terapêutica estreita. Síndrome de Stevens-Johnson (raro). Monitorar função hepática.',
      'es': 'Inductor enzimático potente — reduce eficacia de anticonceptivos, anticoagulantes, VIH, antiepilépticos. Fármaco de margen terapéutico estrecho. Síndrome de Stevens-Johnson (raro). Monitorear función hepática.',
    },
    adverse: {
      'pt': ['Sedação', 'Nistagmo', 'Ataxia', 'Déficit cognitivo (crônico)', 'Hiperatividade paradoxal (crianças)', 'Osteomalácia (uso prolongado)', 'Hepatotoxicidade', 'Dependência'],
      'es': ['Sedación', 'Nistagmo', 'Ataxia', 'Déficit cognitivo (crónico)', 'Hiperactividad paradójica (niños)', 'Osteomalacia (uso prolongado)', 'Hepatotoxicidad', 'Dependencia'],
    },
  ),

  DrugModel(
    id: 'clorpromazina',
    group: 'Neurología y Psiquiatría',
    name: 'Clorpromazina',
    className: {'pt': 'Antipsicótico típico (fenotiazínico)', 'es': 'Antipsicótico típico (fenotiazínico)'},
    category: {'pt': 'SNC / Antipsicótico', 'es': 'SNC / Antipsicótico'},
    route: 'VO / IM / IV (lento)',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Psicose aguda: 25–50 mg IM (repetir 1 h se necessário) | VO manutenção: 25–200 mg 3×/dia | Soluço intratável: 25–50 mg VO/IM | Náusea/êmese: 10–25 mg VO 4–6 h',
      'es': 'Psicosis aguda: 25–50 mg IM (repetir 1 h si necesario) | VO mantenimiento: 25–200 mg 3×/día | Hipo intratable: 25–50 mg VO/IM | Náusea/émesis: 10–25 mg VO 4–6 h',
    },
    frequency: {'pt': '2–4×/dia', 'es': '2–4×/día'},
    renalAlert: {
      'pt': 'Metabolismo predominantemente hepático. Usar com cautela em IRC — risco de sedação prolongada e acúmulo de metabólitos.',
      'es': 'Metabolismo predominantemente hepático. Usar con cautela en IRC — riesgo de sedación prolongada y acumulación de metabolitos.',
    },
    elderlyAlert: {
      'pt': 'Beers: EVITAR em demência — risco aumentado de mortalidade, AVC, sedação intensa, hipotensão ortostática e quedas. Black box FDA: morte em idosos com demência.',
      'es': 'Beers: EVITAR en demencia — riesgo aumentado de mortalidad, ACV, sedación intensa, hipotensión ortostática y caídas. Black box FDA: muerte en adultos mayores con demencia.',
    },
    mechanism: {
      'pt': 'Antagonista D2 (via mesolímbica → efeito antipsicótico), D1, muscarínico (M1), H1, α1-adrenérgico. Efeitos extrapiramidais por bloqueio via nigroestriatal. Baixa potência → sedação e hipotensão mais proeminentes.',
      'es': 'Antagonista D2 (vía mesolímbica → efecto antipsicótico), D1, muscarínico (M1), H1, α1-adrenérgico. Efectos extrapiramidales por bloqueo vía nigroestriatal. Baja potencia → sedación e hipotensión más prominentes.',
    },
    warning: {
      'pt': 'Síndrome maligna dos neurolépticos (SMN) — emergência com hipertermia e rigidez. Prolongamento QT. Discinesia tardia (uso prolongado). Fotossensibilidade. Deprime limiar convulsivo.',
      'es': 'Síndrome maligno de los neurolépticos (SMN) — emergencia con hipertermia y rigidez. Prolongación QT. Discinesia tardía (uso prolongado). Fotosensibilidad. Deprime umbral convulsivo.',
    },
    adverse: {
      'pt': ['Sedação intensa', 'Hipotensão ortostática', 'Efeitos extrapiramidais (distonia, acatisia, parkinsonismo)', 'Discinesia tardia', 'Ganho de peso', 'Hiperprolactinemia', 'Icterícia colestática', 'Fotossensibilidade'],
      'es': ['Sedación intensa', 'Hipotensión ortostática', 'Efectos extrapiramidales (distonía, acatisia, parkinsonismo)', 'Discinesia tardía', 'Aumento de peso', 'Hiperprolactinemia', 'Ictericia colestática', 'Fotosensibilidad'],
    },
  ),

  DrugModel(
    id: 'quetiapina',
    group: 'Neurología y Psiquiatría',
    name: 'Quetiapina',
    className: {'pt': 'Antipsicótico atípico (dibenzotiazepínico)', 'es': 'Antipsicótico atípico (dibenzotiazepínico)'},
    category: {'pt': 'SNC / Antipsicótico', 'es': 'SNC / Antipsicótico'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Esquizofrenia: 150–750 mg/dia (iniciar 25 mg 2×/dia, titular) | Bipolar maníaco: 400–800 mg/dia | Depressão bipolar: 300 mg noturno | Adjunto TDM: 50–300 mg noturno | Delirium/agitação idoso: 12,5–50 mg noturno',
      'es': 'Esquizofrenia: 150–750 mg/día (iniciar 25 mg 2×/día, titular) | Bipolar maníaco: 400–800 mg/día | Depresión bipolar: 300 mg nocturno | Adjunto TDM: 50–300 mg nocturno | Delirio/agitación anciano: 12,5–50 mg nocturno',
    },
    frequency: {'pt': '1–2×/dia', 'es': '1–2×/día'},
    renalAlert: {
      'pt': 'Sem ajuste necessário em IRC. Monitorar sintomas extrapiramidais e sedação.',
      'es': 'Sin ajuste necesario en IRC. Monitorear síntomas extrapiramidales y sedación.',
    },
    elderlyAlert: {
      'pt': 'Usar doses menores (iniciar 12,5–25 mg). Black box FDA: mortalidade aumentada em demência. Risco de hipotensão ortostática, sedação, quedas. Monitorar ECG (QTc).',
      'es': 'Usar dosis menores (iniciar 12,5–25 mg). Black box FDA: mortalidad aumentada en demencia. Riesgo de hipotensión ortostática, sedación, caídas. Monitorear ECG (QTc).',
    },
    mechanism: {
      'pt': 'Antagonista D1/D2 (baixa afinidade → poucos EPS), 5-HT2A, H1 (sedação), α1/α2 (hipotensão), M1 (boca seca, constipação). Metabólito ativo norquetiapina com atividade NRI.',
      'es': 'Antagonista D1/D2 (baja afinidad → pocos EPS), 5-HT2A, H1 (sedación), α1/α2 (hipotensión), M1 (boca seca, estreñimiento). Metabolito activo norquetiapina con actividad NRI.',
    },
    warning: {
      'pt': 'Monitorar glicemia e perfil lipídico (síndrome metabólica). QTc: evitar em QTc > 500 ms. Cataratas: exame oftalmológico a cada 6 meses (em dose alta). SMN raramente.',
      'es': 'Monitorear glucemia y perfil lipídico (síndrome metabólico). QTc: evitar en QTc > 500 ms. Cataratas: examen oftalmológico cada 6 meses (dosis alta). SMN raramente.',
    },
    adverse: {
      'pt': ['Sedação (mais comum)', 'Hipotensão ortostática', 'Ganho de peso e dislipidemia', 'Hiperglicemia', 'Boca seca', 'Constipação', 'Cefaleia', 'EPS leves (raros em dose baixa)'],
      'es': ['Sedación (más común)', 'Hipotensión ortostática', 'Aumento de peso y dislipidemia', 'Hiperglucemia', 'Boca seca', 'Estreñimiento', 'Cefalea', 'EPS leves (raros en dosis baja)'],
    },
  ),

  DrugModel(
    id: 'risperidona',
    group: 'Neurología y Psiquiatría',
    name: 'Risperidona',
    className: {'pt': 'Antipsicótico atípico (benzisoxazol)', 'es': 'Antipsicótico atípico (benzisoxazol)'},
    category: {'pt': 'SNC / Antipsicótico', 'es': 'SNC / Antipsicótico'},
    route: 'VO / IM (depot)',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Esquizofrenia: 2–8 mg/dia (iniciar 1 mg 2×/dia) | Bipolar maníaco: 1–6 mg/dia | Autismo/irritabilidade pediátrico: 0,25–3 mg/dia | Depot (Risperdal Consta): 25–50 mg IM a cada 2 semanas',
      'es': 'Esquizofrenia: 2–8 mg/día (iniciar 1 mg 2×/día) | Bipolar maníaco: 1–6 mg/día | Autismo/irritabilidad pediátrico: 0,25–3 mg/día | Depot (Risperdal Consta): 25–50 mg IM cada 2 semanas',
    },
    frequency: {'pt': '1–2×/dia (VO)', 'es': '1–2×/día (VO)'},
    renalAlert: {
      'pt': 'TFG 10–50: iniciar com 0,5 mg 2×/dia, titular lentamente. TFG < 10: evitar ou usar dose muito reduzida.',
      'es': 'TFG 10–50: iniciar con 0,5 mg 2×/día, titular lentamente. TFG < 10: evitar o usar dosis muy reducida.',
    },
    elderlyAlert: {
      'pt': 'Black box FDA: mortalidade aumentada em demência. Risco de AVC, hipotensão, EPS (maior que outros atípicos em dose alta), quedas. Iniciar 0,25–0,5 mg.',
      'es': 'Black box FDA: mortalidad aumentada en demencia. Riesgo de ACV, hipotensión, EPS (mayor que otros atípicos en dosis alta), caídas. Iniciar 0,25–0,5 mg.',
    },
    mechanism: {
      'pt': 'Antagonista potente D2 e 5-HT2A. Maior potência D2 que quetiapina → EPS mais comuns em doses > 6 mg/dia. Antagonismo H1, α1, α2. Metabólito ativo paliperidona (9-OH-risperidona).',
      'es': 'Antagonista potente D2 y 5-HT2A. Mayor potencia D2 que quetiapina → EPS más comunes en dosis > 6 mg/día. Antagonismo H1, α1, α2. Metabolito activo paliperidona (9-OH-risperidona).',
    },
    warning: {
      'pt': 'Hiperprolactinemia (mais que outros atípicos) → galactorreia, amenorreia, disfunção sexual. Síndrome metabólica. SMN. Prolongamento QT moderado.',
      'es': 'Hiperprolactinemia (más que otros atípicos) → galactorrea, amenorrea, disfunción sexual. Síndrome metabólico. SMN. Prolongación QT moderada.',
    },
    adverse: {
      'pt': ['EPS (dose-dependente)', 'Hiperprolactinemia', 'Ganho de peso', 'Sedação', 'Hipotensão ortostática', 'Cefaleia', 'Ansiedade', 'Insônia', 'Acatisia'],
      'es': ['EPS (dosis-dependiente)', 'Hiperprolactinemia', 'Aumento de peso', 'Sedación', 'Hipotensión ortostática', 'Cefalea', 'Ansiedad', 'Insomnio', 'Acatisia'],
    },
  ),

  DrugModel(
    id: 'fluoxetina',
    group: 'Neurología y Psiquiatría',
    name: 'Fluoxetina',
    className: {'pt': 'ISRS (Inibidor Seletivo da Recaptação de Serotonina)', 'es': 'ISRS (Inhibidor Selectivo de Recaptación de Serotonina)'},
    category: {'pt': 'SNC / Antidepressivo', 'es': 'SNC / Antidepresivo'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'TDM: 20–80 mg/dia (iniciar 10–20 mg pela manhã) | TOC: 20–80 mg/dia | Bulimia: 60 mg/dia | Pânico: 10–60 mg/dia | Pediátrico (≥ 8 anos): 10–20 mg/dia',
      'es': 'TDM: 20–80 mg/día (iniciar 10–20 mg por la mañana) | TOC: 20–80 mg/día | Bulimia: 60 mg/día | Pánico: 10–60 mg/día | Pediátrico (≥ 8 años): 10–20 mg/día',
    },
    frequency: {'pt': '1×/dia (manhã)', 'es': '1×/día (mañana)'},
    renalAlert: {
      'pt': 'Sem ajuste necessário em IRC moderada. IRC grave: espaçar doses (ex.: dias alternados). Monitorar hiponatremia (SIADH).',
      'es': 'Sin ajuste necesario en IRC moderada. IRC grave: espaciar dosis (ej.: días alternos). Monitorear hiponatremia (SIADH).',
    },
    elderlyAlert: {
      'pt': 'Geralmente bem tolerada. Meia-vida muito longa (1–6 dias + metabólito norfluoxetina 4–16 dias) → acúmulo. Monitorar hiponatremia, sangramento GI, interações CYP2D6.',
      'es': 'Generalmente bien tolerada. Vida media muy larga (1–6 días + metabolito norfluoxetina 4–16 días) → acumulación. Monitorear hiponatremia, sangrado GI, interacciones CYP2D6.',
    },
    mechanism: {
      'pt': 'Inibe transportador SERT → ↑ serotonina sináptica. Sem ação relevante em receptores adrenérgicos, histaminérgicos ou muscarínicos em dose terapêutica. Inibidor moderado-forte CYP2D6 e CYP2C19 → múltiplas interações.',
      'es': 'Inhibe transportador SERT → ↑ serotonina sináptica. Sin acción relevante en receptores adrenérgicos, histaminérgicos o muscarínicos en dosis terapéutica. Inhibidor moderado-fuerte CYP2D6 y CYP2C19 → múltiples interacciones.',
    },
    warning: {
      'pt': 'Black box FDA: risco de ideação suicida em < 24 anos (monitorar primeiras semanas). Síndrome serotoninérgica com tramadol, MAOIs, triptanos. Washout 5 semanas antes de MAOI.',
      'es': 'Black box FDA: riesgo de ideación suicida en < 24 años (monitorear primeras semanas). Síndrome serotoninérgico con tramadol, MAOIs, triptanos. Washout 5 semanas antes de MAOI.',
    },
    adverse: {
      'pt': ['Náusea (início)', 'Insônia/agitação', 'Disfunção sexual', 'Cefaleia', 'Diarreia', 'Hiponatremia (SIADH)', 'Sangramento aumentado', 'Síndrome de descontinuação (rara — meia-vida longa)'],
      'es': ['Náusea (inicio)', 'Insomnio/agitación', 'Disfunción sexual', 'Cefalea', 'Diarrea', 'Hiponatremia (SIADH)', 'Sangrado aumentado', 'Síndrome de discontinuación (raro — vida media larga)'],
    },
  ),

  DrugModel(
    id: 'etomidato',
    group: 'UCI – Críticos y Sedoanalgesia',
    name: 'Etomidato',
    className: {'pt': 'Anestésico IV (imidazol)', 'es': 'Anestésico IV (imidazol)'},
    category: {'pt': 'Anestesia / Indução', 'es': 'Anestesia / Inducción'},
    route: 'IV',
    doseType: 'mg_kg',
    mgKg: 0.3,
    fixedDose: {
      'pt': 'Indução anestésica/IOT: 0,3 mg/kg IV bolus (adulto ~20 mg) | Dose reduzida em idosos/instáveis: 0,1–0,2 mg/kg',
      'es': 'Inducción anestésica/IOT: 0,3 mg/kg IV bolo (adulto ~20 mg) | Dosis reducida en ancianos/inestables: 0,1–0,2 mg/kg',
    },
    frequency: {'pt': 'dose única para indução', 'es': 'dosis única para inducción'},
    renalAlert: {
      'pt': 'Sem ajuste necessário. Metabolismo hepático (esterases). Seguro em IRC.',
      'es': 'Sin ajuste necesario. Metabolismo hepático (esterasas). Seguro en IRC.',
    },
    elderlyAlert: {
      'pt': 'Preferido em idosos hemodinamicamente instáveis pela mínima depressão cardiovascular. Reduzir dose para 0,1–0,2 mg/kg. Monitorar mioclonias.',
      'es': 'Preferido en ancianos hemodinámicamente inestables por mínima depresión cardiovascular. Reducir dosis a 0,1–0,2 mg/kg. Monitorear mioclonías.',
    },
    mechanism: {
      'pt': 'Potencializa GABA-A (sítio distinto dos BZDs) → hipnose em 30–60 s, duração 3–10 min. Não libera histamina. Não tem analgesia. Mínimo efeito cardiovascular → ideal em choque. Inibe 11β-hidroxilase → supressão adrenal transitória.',
      'es': 'Potencia GABA-A (sitio distinto de BZDs) → hipnosis en 30–60 s, duración 3–10 min. No libera histamina. Sin analgesia. Mínimo efecto cardiovascular → ideal en choque. Inhibe 11β-hidroxilasa → supresión adrenal transitoria.',
    },
    warning: {
      'pt': 'Supressão adrenocortical — única dose já causa redução do cortisol por 6–12 h (relevante em sépse/choque). Evitar infusão prolongada (insuficiência adrenal). Mioclonias — pretreatar com midazolam/fentanil. Não tem efeito analgésico.',
      'es': 'Supresión adrenocortical — dosis única ya causa reducción del cortisol por 6–12 h (relevante en sepsis/choque). Evitar infusión prolongada (insuficiencia adrenal). Mioclonías — pretratar con midazolam/fentanilo. Sin efecto analgésico.',
    },
    adverse: {
      'pt': ['Mioclonias (30–60%)', 'Supressão adrenal', 'Náusea/vômito ao despertar', 'Dor na injeção', 'Apneia transitória', 'Hiperventilação'],
      'es': ['Mioclonías (30–60%)', 'Supresión adrenal', 'Náusea/vómito al despertar', 'Dolor en la inyección', 'Apnea transitoria', 'Hiperventilación'],
    },
  ),

  DrugModel(
    id: 'amoxicilina',
    group: 'Antibióticos',
    name: 'Amoxicilina',
    className: {'pt': 'Aminopenicilina', 'es': 'Aminopenicilina'},
    category: {'pt': 'Antibiótico / β-lactâmico', 'es': 'Antibiótico / β-lactámico'},
    route: 'VO / IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Adulto — infecção leve-moderada: 500 mg VO 3×/dia ou 875 mg 2×/dia | Otite/sinusite: 875 mg 2×/dia × 7–10 dias | H. pylori: 1 g 2×/dia (em tripla terapia) | Faringite: 500 mg 3×/dia × 10 dias | Pediátrico: 40–90 mg/kg/dia ÷ 2–3 doses',
      'es': 'Adulto — infección leve-moderada: 500 mg VO 3×/día o 875 mg 2×/día | Otitis/sinusitis: 875 mg 2×/día × 7–10 días | H. pylori: 1 g 2×/día (en triple terapia) | Faringitis: 500 mg 3×/día × 10 días | Pediátrico: 40–90 mg/kg/día ÷ 2–3 dosis',
    },
    frequency: {'pt': '2–3×/dia', 'es': '2–3×/día'},
    renalAlert: {
      'pt': 'TFG 10–30: 500 mg a cada 12 h | TFG < 10: 500 mg a cada 24 h | Hemodiálise: dose extra após sessão.',
      'es': 'TFG 10–30: 500 mg cada 12 h | TFG < 10: 500 mg cada 24 h | Hemodiálisis: dosis extra después de sesión.',
    },
    elderlyAlert: {
      'pt': 'Geralmente segura. Ajustar conforme função renal. Monitorar colite por Clostridioides difficile em uso prolongado.',
      'es': 'Generalmente segura. Ajustar según función renal. Monitorear colitis por Clostridioides difficile en uso prolongado.',
    },
    mechanism: {
      'pt': 'Liga-se às PBPs (Penicillin-Binding Proteins) → inibe síntese da parede bacteriana (peptidoglicano) → lise osmótica. Bactericida tempo-dependente. Espectro: amplo para gram-positivos e gram-negativos sem β-lactamase.',
      'es': 'Se une a PBPs (Proteínas Fijadoras de Penicilina) → inhibe síntesis de pared bacteriana (peptidoglucano) → lisis osmótica. Bactericida tiempo-dependiente. Espectro: amplio para gram-positivos y gram-negativos sin β-lactamasa.',
    },
    warning: {
      'pt': 'Verificar alergia à penicilina antes de prescrever (cross-reatividade ~1–2% com cefalosporinas). Exantema maculopapular em mononucleose infecciosa (não é alergia real). Selecionar resistência por β-lactamases.',
      'es': 'Verificar alergia a penicilina antes de prescribir (cross-reactividad ~1–2% con cefalosporinas). Exantema maculopapular en mononucleosis infecciosa (no es alergia real). Seleccionar resistencia por β-lactamasas.',
    },
    adverse: {
      'pt': ['Diarreia', 'Náusea', 'Exantema (5–10%)', 'Urticária/anafilaxia (rara)', 'Candidíase oral/vaginal', 'Colite por C. difficile', 'Elevação de transaminases'],
      'es': ['Diarrea', 'Náusea', 'Exantema (5–10%)', 'Urticaria/anafilaxia (rara)', 'Candidiasis oral/vaginal', 'Colitis por C. difficile', 'Elevación de transaminasas'],
    },
  ),

  DrugModel(
    id: 'ampicilina',
    group: 'Antibióticos',
    name: 'Ampicilina',
    className: {'pt': 'Aminopenicilina IV', 'es': 'Aminopenicilina IV'},
    category: {'pt': 'Antibiótico / β-lactâmico', 'es': 'Antibiótico / β-lactámico'},
    route: 'IV / IM',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Sepse/meningite: 2 g IV a cada 4–6 h | Listeria meningite: 2 g IV a cada 4 h | Endocardite enterococo: 2 g IV a cada 4 h | Neonatal sepse: 50 mg/kg/dose a cada 8–12 h | Profilaxia cirúrgica: 2 g IV dose única',
      'es': 'Sepsis/meningitis: 2 g IV cada 4–6 h | Listeria meningitis: 2 g IV cada 4 h | Endocarditis enterococo: 2 g IV cada 4 h | Neonatal sepsis: 50 mg/kg/dosis cada 8–12 h | Profilaxis quirúrgica: 2 g IV dosis única',
    },
    frequency: {'pt': 'a cada 4–6 h', 'es': 'cada 4–6 h'},
    renalAlert: {
      'pt': 'TFG 10–50: a cada 6–12 h | TFG < 10: a cada 12–24 h. Ajuste obrigatório para evitar neurotoxicidade (convulsões) em doses altas.',
      'es': 'TFG 10–50: cada 6–12 h | TFG < 10: cada 12–24 h. Ajuste obligatorio para evitar neurotoxicidad (convulsiones) en dosis altas.',
    },
    elderlyAlert: {
      'pt': 'Ajustar conforme TFG. Monitorar sinais de colite por C. difficile e superinfecção fúngica.',
      'es': 'Ajustar según TFG. Monitorear signos de colitis por C. difficile y sobreinfección fúngica.',
    },
    mechanism: {
      'pt': 'Mesmo mecanismo da amoxicilina. IV permite concentrações mais elevadas. Ativo contra Listeria monocytogenes e Enterococcus (associado a gentamicina → sinergismo). Coberto por: estreptococos, enterococos sensíveis, Listeria, H. influenzae β-lactamase negativo.',
      'es': 'Mismo mecanismo que amoxicilina. IV permite concentraciones más elevadas. Activo contra Listeria monocytogenes y Enterococcus (asociado a gentamicina → sinergismo). Cubierto: estreptococos, enterococos sensibles, Listeria, H. influenzae β-lactamasa negativo.',
    },
    warning: {
      'pt': 'Verificar alergia à penicilina. Exantema frequente em mononucleose (EBV) — não contraindica uso futuro de β-lactâmicos. Resistência alta em E. coli e Klebsiella.',
      'es': 'Verificar alergia a penicilina. Exantema frecuente en mononucleosis (EBV) — no contraindica uso futuro de β-lactámicos. Resistencia alta en E. coli y Klebsiella.',
    },
    adverse: {
      'pt': ['Exantema maculopapular', 'Diarreia', 'Náusea', 'Flebite (IV)', 'Anafilaxia (rara)', 'Colite por C. difficile', 'Neurotoxicidade (altas doses/IRC)'],
      'es': ['Exantema maculopapular', 'Diarrea', 'Náusea', 'Flebitis (IV)', 'Anafilaxia (rara)', 'Colitis por C. difficile', 'Neurotoxicidad (dosis altas/IRC)'],
    },
  ),

  DrugModel(
    id: 'penicilina_benzatina',
    group: 'Antibióticos',
    name: 'Penicilina G Benzatina / Penicilina G Benzatínica',
    className: {'pt': 'Penicilina de depósito (benzatina)', 'es': 'Penicilina de depósito (benzatínica)'},
    category: {'pt': 'Antibiótico / β-lactâmico', 'es': 'Antibiótico / β-lactámico'},
    route: 'IM profunda (NUNCA IV)',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Sífilis primária/secundária: 2,4 milhões UI IM dose única | Sífilis latente tardia/terciária: 2,4 mi UI IM semanal × 3 semanas | Faringite estreptocócica: 1,2 mi UI IM dose única | Profilaxia febre reumática: 1,2 mi UI IM a cada 21 dias | Pediátrico < 27 kg: 600.000 UI',
      'es': 'Sífilis primaria/secundaria: 2,4 millones UI IM dosis única | Sífilis latente tardía/terciaria: 2,4 M UI IM semanal × 3 semanas | Faringitis estreptocócica: 1,2 M UI IM dosis única | Profilaxis fiebre reumática: 1,2 M UI IM cada 21 días | Pediátrico < 27 kg: 600.000 UI',
    },
    frequency: {'pt': 'conforme indicação (dose única a mensal)', 'es': 'según indicación (dosis única a mensual)'},
    renalAlert: {
      'pt': 'Ajuste necessário em IRC grave: doses únicas sem problema; esquemas repetidos exigem monitoramento de função renal.',
      'es': 'Ajuste necesario en IRC grave: dosis únicas sin problema; esquemas repetidos requieren monitoreo de función renal.',
    },
    elderlyAlert: {
      'pt': 'Injeção IM dolorosa. Risco de síndrome de Hoigne (reação pseudoanfilática). Confirmar alergia à penicilina antes da administração.',
      'es': 'Inyección IM dolorosa. Riesgo de síndrome de Hoigné (reacción pseudoanfiláctica). Confirmar alergia a penicilina antes de la administración.',
    },
    mechanism: {
      'pt': 'Sal de liberação lenta de penicilina G → níveis séricos baixos mas sustentados (14–28 dias). Ideal para sífilis e profilaxia de febre reumática. NUNCA administrar IV — risco de embolia e morte.',
      'es': 'Sal de liberación lenta de penicilina G → niveles séricos bajos pero sostenidos (14–28 días). Ideal para sífilis y profilaxis de fiebre reumática. NUNCA administrar IV — riesgo de embolia y muerte.',
    },
    warning: {
      'pt': 'NUNCA IV (embolia, morte). Síndrome de Hoigné: ansiedade, confusão, alucinações visuais logo após IM (pseudoanfilaxia — não é alergia). Reação de Jarisch-Herxheimer na sífilis 2–8 h após 1ª dose (febre, calafrios, piora transitória).',
      'es': 'NUNCA IV (embolia, muerte). Síndrome de Hoigné: ansiedad, confusión, alucinaciones visuales tras IM (pseudoanfilaxia — no es alergia). Reacción de Jarisch-Herxheimer en sífilis 2–8 h tras 1ª dosis (fiebre, escalofríos, empeoramiento transitorio).',
    },
    adverse: {
      'pt': ['Dor local', 'Anafilaxia (rara)', 'Síndrome de Hoigné', 'Reação de Jarisch-Herxheimer', 'Exantema', 'Nefrite intersticial (raro)', 'Neurotoxicidade (superdosagem)'],
      'es': ['Dolor local', 'Anafilaxia (rara)', 'Síndrome de Hoigné', 'Reacción de Jarisch-Herxheimer', 'Exantema', 'Nefritis intersticial (raro)', 'Neurotoxicidad (sobredosis)'],
    },
  ),

  DrugModel(
    id: 'cefalexina',
    group: 'Antibióticos',
    name: 'Cefalexina',
    className: {'pt': 'Cefalosporina 1ª geração (oral)', 'es': 'Cefalosporina 1ª generación (oral)'},
    category: {'pt': 'Antibiótico / Cefalosporina', 'es': 'Antibiótico / Cefalosporina'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Infecção de pele/partes moles: 500 mg VO 4×/dia × 7–10 dias | Faringite: 500 mg 2×/dia × 10 dias | Cistite: 500 mg 2–4×/dia × 3–7 dias | Pediátrico: 25–100 mg/kg/dia ÷ 4 doses',
      'es': 'Infección piel/tejidos blandos: 500 mg VO 4×/día × 7–10 días | Faringitis: 500 mg 2×/día × 10 días | Cistitis: 500 mg 2–4×/día × 3–7 días | Pediátrico: 25–100 mg/kg/día ÷ 4 dosis',
    },
    frequency: {'pt': '2–4×/dia', 'es': '2–4×/día'},
    renalAlert: {
      'pt': 'TFG 10–50: a cada 8–12 h | TFG < 10: a cada 12–24 h. Hemodiálise: suplementar após sessão.',
      'es': 'TFG 10–50: cada 8–12 h | TFG < 10: cada 12–24 h. Hemodiálisis: suplementar después de sesión.',
    },
    elderlyAlert: {
      'pt': 'Ajustar conforme TFG. Monitorar função renal e colite por C. difficile em uso prolongado.',
      'es': 'Ajustar según TFG. Monitorear función renal y colitis por C. difficile en uso prolongado.',
    },
    mechanism: {
      'pt': 'Liga-se PBPs gram-positivos e alguns gram-negativos → inibe síntese parede bacteriana. Resistente a algumas β-lactamases de gram-positivos. Excelente atividade contra Staphylococcus aureus sensível à oxacilina (MSSA) e estreptococos. Primeira opção oral para IPTM por MSSA.',
      'es': 'Se une a PBPs gram-positivos y algunos gram-negativos → inhibe síntesis pared bacteriana. Resistente a algunas β-lactamasas de gram-positivos. Excelente actividad contra Staphylococcus aureus sensible a oxacilina (MSSA) y estreptococos. Primera opción oral para IPTB por MSSA.',
    },
    warning: {
      'pt': 'Cross-reatividade com penicilina ~1–2%. Atenção em alergia grave à penicilina (anafilaxia). Não cobre MRSA nem Enterococcus.',
      'es': 'Cross-reactividad con penicilina ~1–2%. Atención en alergia grave a penicilina (anafilaxia). No cubre MRSA ni Enterococcus.',
    },
    adverse: {
      'pt': ['Diarreia', 'Náusea', 'Exantema', 'Colite por C. difficile', 'Elevação de creatinina (reversível)', 'Nefrite intersticial (raro)'],
      'es': ['Diarrea', 'Náusea', 'Exantema', 'Colitis por C. difficile', 'Elevación de creatinina (reversible)', 'Nefritis intersticial (raro)'],
    },
  ),

  DrugModel(
    id: 'cefalotina',
    group: 'Antibióticos',
    name: 'Cefalotina',
    className: {'pt': 'Cefalosporina 1ª geração (IV)', 'es': 'Cefalosporina 1ª generación (IV)'},
    category: {'pt': 'Antibiótico / Cefalosporina', 'es': 'Antibiótico / Cefalosporina'},
    route: 'IV / IM',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Adulto: 500 mg–2 g IV a cada 4–6 h | Profilaxia cirúrgica: 2 g IV 30 min antes + 1 g a cada 4 h intraop (cirurgia prolongada) | Pediátrico: 80–160 mg/kg/dia ÷ 4–6 doses',
      'es': 'Adulto: 500 mg–2 g IV cada 4–6 h | Profilaxis quirúrgica: 2 g IV 30 min antes + 1 g cada 4 h intraop (cirugía prolongada) | Pediátrico: 80–160 mg/kg/día ÷ 4–6 dosis',
    },
    frequency: {'pt': 'a cada 4–6 h', 'es': 'cada 4–6 h'},
    renalAlert: {
      'pt': 'TFG 10–50: a cada 6–8 h | TFG < 10: a cada 12 h. Reduzir dose em IRC moderada-grave.',
      'es': 'TFG 10–50: cada 6–8 h | TFG < 10: cada 12 h. Reducir dosis en IRC moderada-grave.',
    },
    elderlyAlert: {
      'pt': 'Ajustar conforme TFG. Monitorar flebite no acesso venoso.',
      'es': 'Ajustar según TFG. Monitorear flebitis en acceso venoso.',
    },
    mechanism: {
      'pt': 'Cefalosporina IV de 1ª geração. Atividade excelente contra MSSA e estreptococos. Profilaxia cirúrgica padrão em cirurgias cardíacas, vasculares e ortopédicas. Não cobre gram-negativos de forma confiável.',
      'es': 'Cefalosporina IV de 1ª generación. Actividad excelente contra MSSA y estreptococos. Profilaxis quirúrgica estándar en cirugías cardíacas, vasculares y ortopédicas. No cubre gram-negativos de forma confiable.',
    },
    warning: {
      'pt': 'Não cobre MRSA, Enterococcus, gram-negativos hospitalares. Verificar alergia a cefalosporinas e penicilinas antes de usar.',
      'es': 'No cubre MRSA, Enterococcus, gram-negativos hospitalarios. Verificar alergia a cefalosporinas y penicilinas antes de usar.',
    },
    adverse: {
      'pt': ['Flebite (IV)', 'Diarreia', 'Náusea', 'Colite por C. difficile', 'Reação alérgica', 'Nefrotoxicidade (em altas doses/IRC)'],
      'es': ['Flebitis (IV)', 'Diarrea', 'Náusea', 'Colitis por C. difficile', 'Reacción alérgica', 'Nefrotoxicidad (dosis altas/IRC)'],
    },
  ),

  DrugModel(
    id: 'cefuroxima',
    group: 'Antibióticos',
    name: 'Cefuroxima',
    className: {'pt': 'Cefalosporina 2ª geração', 'es': 'Cefalosporina 2ª generación'},
    category: {'pt': 'Antibiótico / Cefalosporina', 'es': 'Antibiótico / Cefalosporina'},
    route: 'VO (axetil) / IV / IM',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'VO: 250–500 mg 2×/dia | Sinusite/bronquite: 250 mg 2×/dia × 10 dias | Pneumonia comunitária leve: 500 mg 2×/dia | IV: 750 mg–1,5 g a cada 6–8 h | Doença de Lyme: 500 mg VO 2×/dia × 21 dias',
      'es': 'VO: 250–500 mg 2×/día | Sinusitis/bronquitis: 250 mg 2×/día × 10 días | Neumonía comunitaria leve: 500 mg 2×/día | IV: 750 mg–1,5 g cada 6–8 h | Enfermedad de Lyme: 500 mg VO 2×/día × 21 días',
    },
    frequency: {'pt': '2–3×/dia', 'es': '2–3×/día'},
    renalAlert: {
      'pt': 'TFG 10–20: 750 mg IV a cada 12 h (ou VO 125 mg 2×/dia) | TFG < 10: a cada 24 h.',
      'es': 'TFG 10–20: 750 mg IV cada 12 h (o VO 125 mg 2×/día) | TFG < 10: cada 24 h.',
    },
    elderlyAlert: {
      'pt': 'Geralmente bem tolerada. Ajuste por TFG. Monitorar colite.',
      'es': 'Generalmente bien tolerada. Ajuste por TFG. Monitorear colitis.',
    },
    mechanism: {
      'pt': 'Cefalosporina 2ª geração com cobertura ampliada para gram-negativos (H. influenzae, M. catarrhalis, E. coli) comparada à 1ª geração. Mantém boa atividade contra gram-positivos. Ativa contra Borrelia burgdorferi (Lyme). Não cobre Pseudomonas, Enterococcus, MRSA.',
      'es': 'Cefalosporina 2ª generación con cobertura ampliada para gram-negativos (H. influenzae, M. catarrhalis, E. coli) comparada a 1ª generación. Mantiene buena actividad contra gram-positivos. Activa contra Borrelia burgdorferi (Lyme). No cubre Pseudomonas, Enterococcus, MRSA.',
    },
    warning: {
      'pt': 'Forma VO (axetil) deve ser tomada com alimento para melhor absorção. Cross-reatividade com penicilina ~1–2%. Sabor amargo em crianças (solução).',
      'es': 'Forma VO (axetilo) debe tomarse con alimento para mejor absorción. Cross-reactividad con penicilina ~1–2%. Sabor amargo en niños (solución).',
    },
    adverse: {
      'pt': ['Diarreia', 'Náusea', 'Exantema', 'Colite por C. difficile', 'Cefaleia', 'Tontura'],
      'es': ['Diarrea', 'Náusea', 'Exantema', 'Colitis por C. difficile', 'Cefalea', 'Mareo'],
    },
  ),

  DrugModel(
    id: 'cefepime',
    group: 'Antibióticos',
    name: 'Cefepime',
    className: {'pt': 'Cefalosporina 4ª geração', 'es': 'Cefalosporina 4ª generación'},
    category: {'pt': 'Antibiótico / Cefalosporina', 'es': 'Antibiótico / Cefalosporina'},
    route: 'IV / IM',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Infecção grave/sepse: 2 g IV a cada 8–12 h | Pseudomonas: 2 g IV a cada 8 h | Neutropenia febril: 2 g IV a cada 8 h | Meningite (gram-negativo): 2 g IV a cada 8 h | Pediátrico: 50 mg/kg/dose a cada 8–12 h (máx 2 g/dose)',
      'es': 'Infección grave/sepsis: 2 g IV cada 8–12 h | Pseudomonas: 2 g IV cada 8 h | Neutropenia febril: 2 g IV cada 8 h | Meningitis (gram-negativo): 2 g IV cada 8 h | Pediátrico: 50 mg/kg/dosis cada 8–12 h (máx 2 g/dosis)',
    },
    frequency: {'pt': 'a cada 8–12 h', 'es': 'cada 8–12 h'},
    renalAlert: {
      'pt': 'TFG 30–60: 2 g a cada 12 h | TFG 11–29: 2 g a cada 24 h | TFG < 11: 1 g a cada 24 h. CRÍTICO: subdose em IRC causa falha terapêutica; superdose causa neurotoxicidade (encefalopatia, mioclonias).',
      'es': 'TFG 30–60: 2 g cada 12 h | TFG 11–29: 2 g cada 24 h | TFG < 11: 1 g cada 24 h. CRÍTICO: subdosis en IRC causa falla terapéutica; sobredosis causa neurotoxicidad (encefalopatía, mioclonías).',
    },
    elderlyAlert: {
      'pt': 'Neurotoxicidade mais frequente em idosos — monitorar confusão, mioclonias, convulsões (especialmente se TFG reduzida). Ajuste rigoroso por função renal.',
      'es': 'Neurotoxicidad más frecuente en ancianos — monitorear confusión, mioclonías, convulsiones (especialmente si TFG reducida). Ajuste riguroso por función renal.',
    },
    mechanism: {
      'pt': 'Cefalosporina 4ª geração: zwitteriônica → penetra porina externa de gram-negativos melhor que 3ª geração. Ativo contra Pseudomonas aeruginosa, Enterobacteriaceae (incluindo cepas resistentes a 3ª geração), MSSA, estreptococos. Estável a β-lactamases tipo AmpC.',
      'es': 'Cefalosporina 4ª generación: zwitteriónica → penetra porina externa de gram-negativos mejor que 3ª generación. Activo contra Pseudomonas aeruginosa, Enterobacteriaceae (incluidas cepas resistentes a 3ª generación), MSSA, estreptococos. Estable a β-lactamasas tipo AmpC.',
    },
    warning: {
      'pt': 'Neurotoxicidade: encefalopatia, mioclonias, convulsões — especialmente em IRC não ajustada. ESBL: cefepime pode ter MIC elevado em produtoras de ESBL (preferir carbapenêmico). Não cobre MRSA, Enterococcus, anaeróbios.',
      'es': 'Neurotoxicidad: encefalopatía, mioclonías, convulsiones — especialmente en IRC no ajustada. ESBL: cefepime puede tener MIC elevado en productoras de ESBL (preferir carbapenémico). No cubre MRSA, Enterococcus, anaerobios.',
    },
    adverse: {
      'pt': ['Flebite (IV)', 'Diarreia', 'Náusea', 'Cefaleia', 'Exantema', 'Neurotoxicidade (IRC)', 'Colite por C. difficile', 'Eosinofilia'],
      'es': ['Flebitis (IV)', 'Diarrea', 'Náusea', 'Cefalea', 'Exantema', 'Neurotoxicidad (IRC)', 'Colitis por C. difficile', 'Eosinofilia'],
    },
  ),

  DrugModel(
    id: 'claritromicina',
    group: 'Antibióticos',
    name: 'Claritromicina',
    className: {'pt': 'Macrolídeo', 'es': 'Macrólido'},
    category: {'pt': 'Antibiótico / Macrolídeo', 'es': 'Antibiótico / Macrólido'},
    route: 'VO / IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'PAC leve-moderada: 500 mg VO 2×/dia × 7–14 dias | H. pylori (tripla terapia): 500 mg 2×/dia × 14 dias | MAC (profilaxia HIV): 500 mg 2×/dia | Exacerbação DPOC: 500 mg 2×/dia × 7–14 dias | Pediátrico: 15 mg/kg/dia ÷ 2 doses',
      'es': 'NAC leve-moderada: 500 mg VO 2×/día × 7–14 días | H. pylori (triple terapia): 500 mg 2×/día × 14 días | MAC (profilaxis VIH): 500 mg 2×/día | Exacerbación EPOC: 500 mg 2×/día × 7–14 días | Pediátrico: 15 mg/kg/día ÷ 2 dosis',
    },
    frequency: {'pt': '2×/dia', 'es': '2×/día'},
    renalAlert: {
      'pt': 'TFG < 30: reduzir dose 50% ou dobrar intervalo. TFG < 10: usar com cautela.',
      'es': 'TFG < 30: reducir dosis 50% o doblar intervalo. TFG < 10: usar con cautela.',
    },
    elderlyAlert: {
      'pt': 'Potente inibidor CYP3A4 → revisar interações (estatinas, varfarina, digoxina, BZDs). Monitorar QTc. Pode causar confusão em idosos.',
      'es': 'Potente inhibidor CYP3A4 → revisar interacciones (estatinas, warfarina, digoxina, BZDs). Monitorear QTc. Puede causar confusión en adultos mayores.',
    },
    mechanism: {
      'pt': 'Liga-se à subunidade 50S ribossomal (23S rRNA) → inibe síntese proteica bacteriana. Bacteriostático. Espectro: atípicos (Mycoplasma, Legionella, Chlamydophila), H. pylori, MAC, MSSA, estreptococos. Metabólito ativo 14-OH-claritromicina. Inibidor CYP3A4.',
      'es': 'Se une a subunidad 50S ribosomal (23S rRNA) → inhibe síntesis proteica bacteriana. Bacteriostático. Espectro: atípicos (Mycoplasma, Legionella, Chlamydophila), H. pylori, MAC, MSSA, estreptococos. Metabolito activo 14-OH-claritromicina. Inhibidor CYP3A4.',
    },
    warning: {
      'pt': 'Inibidor potente CYP3A4 → ↑ estatinas (rabdomiólise), ↑ digoxina (toxicidade), ↑ varfarina (sangramento), ↑ colchicina (risco fatal), ↑ midazolam. Prolongamento QTc. Contraindicado com cisaprida, pimozida, ergotamina.',
      'es': 'Inhibidor potente CYP3A4 → ↑ estatinas (rabdomiólisis), ↑ digoxina (toxicidad), ↑ warfarina (sangrado), ↑ colchicina (riesgo fatal), ↑ midazolam. Prolongación QTc. Contraindicado con cisaprida, pimozida, ergotamina.',
    },
    adverse: {
      'pt': ['Diarreia', 'Náusea', 'Gosto metálico/amargo', 'Dor abdominal', 'Prolongamento QTc', 'Elevação de transaminases', 'Cefaleia', 'Psicose/confusão (raro)'],
      'es': ['Diarrea', 'Náusea', 'Sabor metálico/amargo', 'Dolor abdominal', 'Prolongación QTc', 'Elevación de transaminasas', 'Cefalea', 'Psicosis/confusión (raro)'],
    },
  ),

  DrugModel(
    id: 'clindamicina',
    group: 'Antibióticos',
    name: 'Clindamicina',
    className: {'pt': 'Lincosamídeo', 'es': 'Lincosamida'},
    category: {'pt': 'Antibiótico / Lincosamídeo', 'es': 'Antibiótico / Lincosamida'},
    route: 'VO / IV / IM / Tópico / Vaginal',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'IPTM grave: 600 mg IV a cada 8 h | IPTM moderada VO: 300–450 mg 3×/dia | Pneumonia aspirativa: 600 mg IV a cada 8 h (± ampicilina) | Toxoplasmose (alternativa): 600 mg IV/VO a cada 6 h | Pediátrico: 25–40 mg/kg/dia ÷ 3–4 doses',
      'es': 'IPTB grave: 600 mg IV cada 8 h | IPTB moderada VO: 300–450 mg 3×/día | Neumonía aspirativa: 600 mg IV cada 8 h (± ampicilina) | Toxoplasmosis (alternativa): 600 mg IV/VO cada 6 h | Pediátrico: 25–40 mg/kg/día ÷ 3–4 dosis',
    },
    frequency: {'pt': '3–4×/dia', 'es': '3–4×/día'},
    renalAlert: {
      'pt': 'Sem ajuste necessário em IRC. Metabolismo hepático.',
      'es': 'Sin ajuste necesario en IRC. Metabolismo hepático.',
    },
    elderlyAlert: {
      'pt': 'Alto risco de colite por C. difficile em idosos. Monitorar diarreia ativamente. Hidratação adequada.',
      'es': 'Alto riesgo de colitis por C. difficile en adultos mayores. Monitorear diarrea activamente. Hidratación adecuada.',
    },
    mechanism: {
      'pt': 'Liga-se subunidade 50S (sítio diferente dos macrolídeos) → inibe translocação peptídica. Bacteriostático (bactericida em alta concentração). Excelente atividade contra anaeróbios (Bacteroides, Prevotella), MSSA, estreptococos, toxoplasmose. Inibe produção de toxinas por S. aureus e S. pyogenes (útil em fasceíte necrotizante).',
      'es': 'Se une a subunidad 50S (sitio diferente de macrólidos) → inhibe translocación peptídica. Bacteriostático (bactericida en alta concentración). Excelente actividad contra anaerobios (Bacteroides, Prevotella), MSSA, estreptococos, toxoplasmosis. Inhibe producción de toxinas por S. aureus y S. pyogenes (útil en fascitis necrotizante).',
    },
    warning: {
      'pt': 'MAIOR risco de colite pseudomembranosa por C. difficile entre os antibióticos. Suspender imediatamente se diarreia com sangue/muco. Não tem cobertura para gram-negativos.',
      'es': 'MAYOR riesgo de colitis pseudomembranosa por C. difficile entre los antibióticos. Suspender inmediatamente si diarrea con sangre/moco. Sin cobertura para gram-negativos.',
    },
    adverse: {
      'pt': ['Diarreia (comum)', 'Colite por C. difficile (risco alto)', 'Náusea', 'Vômito', 'Exantema', 'Flebite (IV)', 'Hepatotoxicidade (raro)', 'Bloqueio neuromuscular (altas doses IV)'],
      'es': ['Diarrea (común)', 'Colitis por C. difficile (riesgo alto)', 'Náusea', 'Vómito', 'Exantema', 'Flebitis (IV)', 'Hepatotoxicidad (raro)', 'Bloqueo neuromuscular (dosis altas IV)'],
    },
  ),

  DrugModel(
    id: 'levofloxacino',
    group: 'Antibióticos',
    name: 'Levofloxacino',
    className: {'pt': 'Fluoroquinolona (3ª geração)', 'es': 'Fluoroquinolona (3ª generación)'},
    category: {'pt': 'Antibiótico / Quinolona', 'es': 'Antibiótico / Quinolona'},
    route: 'VO / IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'PAC moderada-grave: 500–750 mg/dia × 7–14 dias | DPOC exacerbação: 500 mg/dia × 7 dias | Sinusite bacteriana: 500 mg/dia × 10–14 dias | ITU complicada: 750 mg/dia × 5 dias | Tuberculose (2ª linha): 500–1000 mg/dia',
      'es': 'NAC moderada-grave: 500–750 mg/día × 7–14 días | EPOC exacerbación: 500 mg/día × 7 días | Sinusitis bacteriana: 500 mg/día × 10–14 días | ITU complicada: 750 mg/día × 5 días | Tuberculosis (2ª línea): 500–1000 mg/día',
    },
    frequency: {'pt': '1×/dia', 'es': '1×/día'},
    renalAlert: {
      'pt': 'TFG 20–49: 500 mg/dia → 250 mg/dia manutenção | TFG < 20: 500 mg ataque → 250 mg a cada 48 h. Hemodiálise: após sessão.',
      'es': 'TFG 20–49: 500 mg/día → 250 mg/día mantenimiento | TFG < 20: 500 mg carga → 250 mg cada 48 h. Hemodiálisis: después de sesión.',
    },
    elderlyAlert: {
      'pt': 'Risco aumentado de tendinite/ruptura de tendão de Aquiles (especialmente com corticosteróide). Monitorar QTc. Risco de neuropatia periférica e confusão. Evitar em > 65 anos com história de doença articular.',
      'es': 'Riesgo aumentado de tendinitis/ruptura del tendón de Aquiles (especialmente con corticosteroide). Monitorear QTc. Riesgo de neuropatía periférica y confusión. Evitar en > 65 años con historia de enfermedad articular.',
    },
    mechanism: {
      'pt': 'Inibe DNA girase (topoisomerase II) e topoisomerase IV → impede replicação, transcrição e reparo do DNA bacteriano. Bactericida concentração-dependente. Espectro amplo: gram-positivos (incluindo S. pneumoniae resistente), gram-negativos, atípicos, micobactérias.',
      'es': 'Inhibe DNA girasa (topoisomerasa II) y topoisomerasa IV → impide replicación, transcripción y reparación del DNA bacteriano. Bactericida concentración-dependiente. Espectro amplio: gram-positivos (incluido S. pneumoniae resistente), gram-negativos, atípicos, micobacterias.',
    },
    warning: {
      'pt': 'FDA Black Box: tendinite/ruptura de tendão (especialmente Aquiles, em idosos e com corticóides), neuropatia periférica irreversível, exacerbação miastenia gravis. Prolongamento QTc — evitar com antiarrítmicos. Fotossensibilidade. Restringir uso para evitar resistência.',
      'es': 'FDA Black Box: tendinitis/ruptura de tendón (especialmente Aquiles, en ancianos y con corticoides), neuropatía periférica irreversible, exacerbación miastenia gravis. Prolongación QTc — evitar con antiarrítmicos. Fotosensibilidad. Restringir uso para evitar resistencia.',
    },
    adverse: {
      'pt': ['Náusea', 'Diarreia', 'Cefaleia', 'Tontura', 'Insônia', 'Tendinite/ruptura de tendão', 'Prolongamento QTc', 'Neuropatia periférica', 'Fotossensibilidade', 'Hipoglicemia/hiperglicemia'],
      'es': ['Náusea', 'Diarrea', 'Cefalea', 'Mareo', 'Insomnio', 'Tendinitis/ruptura de tendón', 'Prolongación QTc', 'Neuropatía periférica', 'Fotosensibilidad', 'Hipoglucemia/hiperglucemia'],
    },
  ),

  DrugModel(
    id: 'sulfametoxazol_trimetoprima',
    group: 'Antibióticos',
    name: 'Sulfametoxazol + Trimetoprima (SMX-TMP)',
    className: {'pt': 'Sulfonamida + Inibidor dihidrofolato redutase', 'es': 'Sulfonamida + Inhibidor dihidrofolato reductasa'},
    category: {'pt': 'Antibiótico / Sulfonamida', 'es': 'Antibiótico / Sulfonamida'},
    route: 'VO / IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'ITU não complicada: 1 cp forte (800/160 mg) 2×/dia × 3 dias | ITU complicada: 7–14 dias | Pneumocistose (PCP) tratamento: 15–20 mg/kg/dia TMP ÷ 3–4 doses IV | PCP profilaxia: 1 cp forte/dia ou 3×/semana | Toxoplasmose profilaxia: 1 cp forte/dia | Pediátrico: 8 mg/kg/dia TMP ÷ 2 doses',
      'es': 'ITU no complicada: 1 cp forte (800/160 mg) 2×/día × 3 días | ITU complicada: 7–14 días | Pneumocistosis (PCP) tratamiento: 15–20 mg/kg/día TMP ÷ 3–4 dosis IV | PCP profilaxis: 1 cp forte/día o 3×/semana | Toxoplasmosis profilaxis: 1 cp forte/día | Pediátrico: 8 mg/kg/día TMP ÷ 2 dosis',
    },
    frequency: {'pt': '2×/dia', 'es': '2×/día'},
    renalAlert: {
      'pt': 'TFG 15–30: dose normal a cada 24 h | TFG < 15: evitar (acúmulo sulfa, cristalúria). Hipercalemia: TMP bloqueia secreção renal de K⁺ (efeito poupador como amilorida) — monitorar K⁺ em IRC.',
      'es': 'TFG 15–30: dosis normal cada 24 h | TFG < 15: evitar (acumulación sulfa, cristaluria). Hiperpotasemia: TMP bloquea secreción renal de K⁺ (efecto ahorrador como amilorida) — monitorear K⁺ en IRC.',
    },
    elderlyAlert: {
      'pt': 'Hipercalemia mais frequente (bloqueia secreção tubular K⁺). Interação com varfarina (↑ INR significativo). Risco de síndrome de Stevens-Johnson. Monitorar função renal e eletrólitos.',
      'es': 'Hiperpotasemia más frecuente (bloquea secreción tubular K⁺). Interacción con warfarina (↑ INR significativo). Riesgo de síndrome de Stevens-Johnson. Monitorear función renal y electrolitos.',
    },
    mechanism: {
      'pt': 'Ação sinérgica dupla: SMX inibe dihidropteroato sintase (síntese ácido dihidrofolato) + TMP inibe dihidrofolato redutase → bloqueia síntese de tetrahidrofolato → falha na síntese de purinas e aminoácidos. Bactericida em combinação. Espectro: MRSA CA, Stenotrophomonas, Pneumocystis jirovecii, Toxoplasma, Nocardia, Listeria.',
      'es': 'Acción sinérgica doble: SMX inhibe dihidropteroato sintetasa (síntesis ácido dihidrofolato) + TMP inhibe dihidrofolato reductasa → bloquea síntesis de tetrahidrofolato → falla en síntesis de purinas y aminoácidos. Bactericida en combinación. Espectro: MRSA CA, Stenotrophomonas, Pneumocystis jirovecii, Toxoplasma, Nocardia, Listeria.',
    },
    warning: {
      'pt': 'Stevens-Johnson/necrose epidérmica tóxica (raro mas grave). Mielossupressão em uso prolongado (monitorar hemograma). Interação varfarina (↑↑ INR). Hipercalemia (bloco K⁺ tubular). Contraindicado no 1º trimestre (antagonista folato) e a termo (kernicterus).',
      'es': 'Stevens-Johnson/necrólisis epidérmica tóxica (raro pero grave). Mielosupresión en uso prolongado (monitorear hemograma). Interacción warfarina (↑↑ INR). Hiperpotasemia (bloqueo K⁺ tubular). Contraindicado en 1º trimestre (antagonista folato) y a término (kernicterus).',
    },
    adverse: {
      'pt': ['Náusea', 'Vômito', 'Exantema', 'Stevens-Johnson (raro)', 'Hipercalemia', 'Mielossupressão', 'Cristalúria/nefrotoxicidade (hidratação inadequada)', 'Fotossensibilidade', 'Aumento creatinina (sem lesão renal real)'],
      'es': ['Náusea', 'Vómito', 'Exantema', 'Stevens-Johnson (raro)', 'Hiperpotasemia', 'Mielosupresión', 'Cristaluria/nefrotoxicidad (hidratación inadecuada)', 'Fotosensibilidad', 'Aumento creatinina (sin lesión renal real)'],
    },
  ),

  DrugModel(
    id: 'gentamicina',
    group: 'Antibióticos',
    name: 'Gentamicina',
    className: {'pt': 'Aminoglicosídeo', 'es': 'Aminoglucósido'},
    category: {'pt': 'Antibiótico / Aminoglicosídeo', 'es': 'Antibiótico / Aminoglucósido'},
    route: 'IV / IM / Tópico ocular',
    doseType: 'mg_kg',
    mgKg: 5.0,
    fixedDose: {
      'pt': 'Dose única diária (extended interval): 5–7 mg/kg IV a cada 24 h (preferido em infecções gram-negativas graves) | Dose dividida: 1,5–2 mg/kg IV a cada 8 h (endocardite sinérgica) | Monitorar pico (5–10 µg/mL) e vale (< 1–2 µg/mL)',
      'es': 'Dosis única diaria (intervalo extendido): 5–7 mg/kg IV cada 24 h (preferido en infecciones gram-negativas graves) | Dosis dividida: 1,5–2 mg/kg IV cada 8 h (endocarditis sinérgica) | Monitorear pico (5–10 µg/mL) y valle (< 1–2 µg/mL)',
    },
    frequency: {'pt': '1×/dia (dose única) ou a cada 8 h (sinergismo)', 'es': '1×/día (dosis única) o cada 8 h (sinergismo)'},
    renalAlert: {
      'pt': 'NEFROTÓXICO — monitorar creatinina diariamente. TFG 40–60: a cada 36 h | TFG 20–40: a cada 48 h | TFG < 20: evitar ou usar com monitoramento sérico. Hemodiálise: 2/3 dose após cada sessão.',
      'es': 'NEFROTÓXICO — monitorear creatinina diariamente. TFG 40–60: cada 36 h | TFG 20–40: cada 48 h | TFG < 20: evitar o usar con monitoreo sérico. Hemodiálisis: 2/3 dosis después de cada sesión.',
    },
    elderlyAlert: {
      'pt': 'ALTO RISCO em idosos: nefrotoxicidade e ototoxicidade irreversível. Evitar uso prolongado (> 7 dias). Monitorar função renal, audição e vestibular. Preferir alternativas se possível.',
      'es': 'ALTO RIESGO en ancianos: nefrotoxicidad y ototoxicidad irreversible. Evitar uso prolongado (> 7 días). Monitorear función renal, audición y vestibular. Preferir alternativas si es posible.',
    },
    mechanism: {
      'pt': 'Penetra membrana bacteriana → liga-se subunidade 30S ribossomal → leitura errônea do mRNA → proteínas aberrantes → morte celular. Bactericida concentração-dependente. Sinergismo com β-lactâmicos (ruptura parede + inibição ribossomo). Espectro: gram-negativos aeróbios (Pseudomonas, Enterobacteriaceae). Não cobre anaeróbios nem streptococos isoladamente.',
      'es': 'Penetra membrana bacteriana → se une a subunidad 30S ribosomal → lectura errónea del mRNA → proteínas aberrantes → muerte celular. Bactericida concentración-dependiente. Sinergismo con β-lactámicos (ruptura pared + inhibición ribosoma). Espectro: gram-negativos aerobios (Pseudomonas, Enterobacteriaceae). No cubre anaerobios ni estreptococos aisladamente.',
    },
    warning: {
      'pt': 'Ototoxicidade irreversível: cócleo (surdez, especialmente frequências altas) e vestibular (tontura, ataxia). Nefrotoxicidade dose e tempo-dependente — monitorar creatinina. Bloqueio neuromuscular em altas doses IV rápidas. Evitar com outros nefrotóxicos (vancomicina, AINES, contraste).',
      'es': 'Ototoxicidad irreversible: coclear (sordera, especialmente frecuencias altas) y vestibular (mareo, ataxia). Nefrotoxicidad dosis y tiempo-dependiente — monitorear creatinina. Bloqueo neuromuscular en dosis altas IV rápidas. Evitar con otros nefrotóxicos (vancomicina, AINEs, contraste).',
    },
    adverse: {
      'pt': ['Nefrotoxicidade (10–25%)', 'Ototoxicidade auditiva (irreversível)', 'Ototoxicidade vestibular (irreversível)', 'Bloqueio neuromuscular', 'Flebite (IV)', 'Dermatite tópica'],
      'es': ['Nefrotoxicidad (10–25%)', 'Ototoxicidad auditiva (irreversible)', 'Ototoxicidad vestibular (irreversible)', 'Bloqueo neuromuscular', 'Flebitis (IV)', 'Dermatitis tópica'],
    },
  ),

  DrugModel(
    id: 'linezolida',
    group: 'Antibióticos',
    name: 'Linezolida',
    className: {'pt': 'Oxazolidinona', 'es': 'Oxazolidinona'},
    category: {'pt': 'Antibiótico / Gram-positivo resistente', 'es': 'Antibiótico / Gram-positivo resistente'},
    route: 'VO / IV (biodisponibilidade VO ≈ 100%)',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'MRSA/MRSE/VRE: 600 mg VO/IV a cada 12 h × 10–28 dias | Pneumonia nosocomial MRSA: 600 mg IV a cada 12 h × 7–14 dias | Pediátrico: 10 mg/kg a cada 8–12 h',
      'es': 'MRSA/MRSE/VRE: 600 mg VO/IV cada 12 h × 10–28 días | Neumonía nosocomial MRSA: 600 mg IV cada 12 h × 7–14 días | Pediátrico: 10 mg/kg cada 8–12 h',
    },
    frequency: {'pt': 'a cada 12 h', 'es': 'cada 12 h'},
    renalAlert: {
      'pt': 'Sem ajuste necessário. Metabólitos acumulam em IRC — monitorar mielossupressão.',
      'es': 'Sin ajuste necesario. Metabolitos se acumulan en IRC — monitorear mielosupresión.',
    },
    elderlyAlert: {
      'pt': 'Monitorar neuropatia periférica e ocular em uso > 4 semanas. Risco de acidose lática.',
      'es': 'Monitorear neuropatía periférica y ocular en uso > 4 semanas. Riesgo de acidosis láctica.',
    },
    mechanism: {
      'pt': 'Liga-se subunidade 23S do 50S ribossomal (sítio único) → inibe formação do complexo de iniciação 70S → impede síntese proteica. Bacteriostático contra enterococos e estafilococos. Bactericida contra estreptococos. Ativo contra MRSA, VRE, Listeria, gram-positivos resistentes. Inibidor reversível MAO (RIMA) → interações serotoninérgicas.',
      'es': 'Se une a subunidad 23S del 50S ribosomal (sitio único) → inhibe formación del complejo de iniciación 70S → impide síntesis proteica. Bacteriostático contra enterococos y estafilococos. Bactericida contra estreptococos. Activo contra MRSA, VRE, Listeria, gram-positivos resistentes. Inhibidor reversible MAO (RIMA) → interacciones serotoninérgicas.',
    },
    warning: {
      'pt': 'RIMA: síndrome serotoninérgica com ISRS, IMAO, triptanos, tramadol, meperidina — CONTRAINDICADO em combinação. Mielossupressão reversível (plaquetopenia > anemia) — hemograma semanal em uso > 2 semanas. Neuropatia periférica/óptica irreversível em uso prolongado (> 4 semanas). Acidose lática.',
      'es': 'RIMA: síndrome serotoninérgico con ISRS, IMAO, triptanos, tramadol, meperidina — CONTRAINDICADO en combinación. Mielosupresión reversible (trombocitopenia > anemia) — hemograma semanal en uso > 2 semanas. Neuropatía periférica/óptica irreversible en uso prolongado (> 4 semanas). Acidosis láctica.',
    },
    adverse: {
      'pt': ['Mielossupressão (trombocitopenia, anemia)', 'Náusea/vômito', 'Diarreia', 'Cefaleia', 'Síndrome serotoninérgica (com serotonérgicos)', 'Neuropatia periférica (uso prolongado)', 'Neuropatia óptica (raro)', 'Acidose lática'],
      'es': ['Mielosupresión (trombocitopenia, anemia)', 'Náusea/vómito', 'Diarrea', 'Cefalea', 'Síndrome serotoninérgico (con serotonérgicos)', 'Neuropatía periférica (uso prolongado)', 'Neuropatía óptica (raro)', 'Acidosis láctica'],
    },
  ),

  DrugModel(
    id: 'imipenem',
    group: 'Antibióticos',
    name: 'Imipenem-Cilastatina',
    className: {'pt': 'Carbapenêmico', 'es': 'Carbapenémico'},
    category: {'pt': 'Antibiótico / Carbapenêmico', 'es': 'Antibiótico / Carbapenémico'},
    route: 'IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Infecção grave: 500 mg IV a cada 6 h ou 1 g a cada 8 h | Pseudomonas grave: 1 g IV a cada 6 h | Pediátrico: 60–100 mg/kg/dia ÷ 4 doses',
      'es': 'Infección grave: 500 mg IV cada 6 h o 1 g cada 8 h | Pseudomonas grave: 1 g IV cada 6 h | Pediátrico: 60–100 mg/kg/día ÷ 4 dosis',
    },
    frequency: {'pt': 'a cada 6–8 h', 'es': 'cada 6–8 h'},
    renalAlert: {
      'pt': 'TFG 20–50: 500 mg a cada 6–8 h | TFG < 20: 250–500 mg a cada 12 h. Redução obrigatória — convulsões em IRC com dose normal.',
      'es': 'TFG 20–50: 500 mg cada 6–8 h | TFG < 20: 250–500 mg cada 12 h. Reducción obligatoria — convulsiones en IRC con dosis normal.',
    },
    elderlyAlert: {
      'pt': 'Ajuste rigoroso por TFG. Risco aumentado de convulsões em idosos com IRC. Preferir meropenem (menor epileptogênico).',
      'es': 'Ajuste riguroso por TFG. Riesgo aumentado de convulsiones en ancianos con IRC. Preferir meropenem (menor epileptogénico).',
    },
    mechanism: {
      'pt': 'Liga-se PBPs → inibe síntese parede bacteriana. Espectro ultra-amplo: gram-positivos, gram-negativos (incluindo Pseudomonas e ESBL), anaeróbios. Cilastatina inibe dehidropeptidase renal → impede inativação do imipenem. Resistente a maioria das β-lactamases exceto metalo-β-lactamases (NDM, VIM).',
      'es': 'Se une a PBPs → inhibe síntesis pared bacteriana. Espectro ultra-amplio: gram-positivos, gram-negativos (incluido Pseudomonas y ESBL), anaerobios. Cilastatina inhibe dehidropeptidasa renal → impide inactivación del imipenem. Resistente a mayoría de β-lactamasas excepto metalo-β-lactamasas (NDM, VIM).',
    },
    warning: {
      'pt': 'Epileptogênico — maior que meropenem. Ajuste renal obrigatório para evitar convulsões. Reservar para infecções multirresistentes documentadas. Uso amplo promove resistência.',
      'es': 'Epileptogénico — mayor que meropenem. Ajuste renal obligatorio para evitar convulsiones. Reservar para infecciones multirresistentes documentadas. Uso amplio promueve resistencia.',
    },
    adverse: {
      'pt': ['Convulsões (IRC sem ajuste)', 'Náusea/vômito (infusão rápida)', 'Flebite', 'Colite por C. difficile', 'Exantema', 'Eosinofilia', 'Nefrotoxicidade (leve)'],
      'es': ['Convulsiones (IRC sin ajuste)', 'Náusea/vómito (infusión rápida)', 'Flebitis', 'Colitis por C. difficile', 'Exantema', 'Eosinofilia', 'Nefrotoxicidad (leve)'],
    },
  ),

  DrugModel(
    id: 'ertapenem',
    group: 'Antibióticos',
    name: 'Ertapenem',
    className: {'pt': 'Carbapenêmico (1×/dia, sem anti-Pseudomonas)', 'es': 'Carbapenémico (1×/día, sin anti-Pseudomonas)'},
    category: {'pt': 'Antibiótico / Carbapenêmico', 'es': 'Antibiótico / Carbapenémico'},
    route: 'IV / IM',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Adulto: 1 g IV/IM a cada 24 h | Pediátrico 3 meses–12 anos: 15 mg/kg a cada 12 h (máx 1 g/dia) | Profilaxia cirúrgica colorretal: 1 g IV dose única 1 h antes',
      'es': 'Adulto: 1 g IV/IM cada 24 h | Pediátrico 3 meses–12 años: 15 mg/kg cada 12 h (máx 1 g/día) | Profilaxis quirúrgica colorrectal: 1 g IV dosis única 1 h antes',
    },
    frequency: {'pt': '1×/dia', 'es': '1×/día'},
    renalAlert: {
      'pt': 'TFG < 30: 500 mg a cada 24 h. Hemodiálise: dose adicional 150 mg após sessão se última dose < 6 h antes.',
      'es': 'TFG < 30: 500 mg cada 24 h. Hemodiálisis: dosis adicional 150 mg después de sesión si última dosis < 6 h antes.',
    },
    elderlyAlert: {
      'pt': 'Ajuste rigoroso por TFG. Conveniente para terapia domiciliar (1×/dia IV).',
      'es': 'Ajuste riguroso por TFG. Conveniente para terapia domiciliaria (1×/día IV).',
    },
    mechanism: {
      'pt': 'Carbapenêmico de dose única diária. NÃO tem atividade contra Pseudomonas aeruginosa, Acinetobacter ou Enterococcus. Ideal para infecções comunitárias e hospitalares iniciais por ESBL (abscesso intra-abdominal, pé diabético infectado, pneumonia grave comunitária, pielonefrite por ESBL). Vantagem: 1 g 1×/dia → facilita alta hospitalar precoce.',
      'es': 'Carbapenémico de dosis única diaria. NO tiene actividad contra Pseudomonas aeruginosa, Acinetobacter ni Enterococcus. Ideal para infecciones comunitarias y hospitalarias iniciales por ESBL (absceso intra-abdominal, pie diabético infectado, neumonía grave comunitaria, pielonefritis por ESBL). Ventaja: 1 g 1×/día → facilita alta hospitalar precoz.',
    },
    warning: {
      'pt': 'NÃO cobre Pseudomonas — erro crítico se usado em infecção por Pseudomonas. Menor risco convulsivo que imipenem. Reservar para infecções documentadas resistentes.',
      'es': 'NO cubre Pseudomonas — error crítico si se usa en infección por Pseudomonas. Menor riesgo convulsivo que imipenem. Reservar para infecciones documentadas resistentes.',
    },
    adverse: {
      'pt': ['Diarreia', 'Náusea', 'Cefaleia', 'Flebite', 'Colite por C. difficile', 'Confusão (idosos)', 'Convulsões (raro)', 'Exantema'],
      'es': ['Diarrea', 'Náusea', 'Cefalea', 'Flebitis', 'Colitis por C. difficile', 'Confusión (ancianos)', 'Convulsiones (raro)', 'Exantema'],
    },
  ),

  DrugModel(
    id: 'polimixina_b',
    group: 'Antibióticos',
    name: 'Polimixina B',
    className: {'pt': 'Polimixina (lipopeptídeo catiônico)', 'es': 'Polimixina (lipopéptido catiónico)'},
    category: {'pt': 'Antibiótico / Último recurso (gram-negativo MDR)', 'es': 'Antibiótico / Último recurso (gram-negativo MDR)'},
    route: 'IV / Inalatório / Tópico',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Infecção sistêmica: 1,5–2,5 mg/kg/dia IV ÷ 2 doses (= 15.000–25.000 UI/kg/dia) | Inalatório: 500.000–2.000.000 UI nebulização 2×/dia (adjunto) | Monitorar creatinina diariamente',
      'es': 'Infección sistémica: 1,5–2,5 mg/kg/día IV ÷ 2 dosis (= 15.000–25.000 UI/kg/día) | Inhalatorio: 500.000–2.000.000 UI nebulización 2×/día (adjunto) | Monitorear creatinina diariamente',
    },
    frequency: {'pt': 'a cada 12 h', 'es': 'cada 12 h'},
    renalAlert: {
      'pt': 'NÃO ajustar dose em IRC — diferente da colistina. A polimixina B é excretada extrarenalmente → manter dose; entretanto é nefrotóxica → monitorar diariamente.',
      'es': 'NO ajustar dosis en IRC — diferente a colistina. La polimixina B se excreta extrarrenalmente → mantener dosis; sin embargo es nefrotóxica → monitorear diariamente.',
    },
    elderlyAlert: {
      'pt': 'Nefrotoxicidade severa — especialmente em idosos, hipocalemia, hiponatremia ou uso concomitante de aminoglicosídeos. Monitorar função renal diária.',
      'es': 'Nefrotoxicidad severa — especialmente en ancianos, hipopotasemia, hiponatremia o uso concomitante de aminoglucósidos. Monitorear función renal diaria.',
    },
    mechanism: {
      'pt': 'Liga-se a lipopolissacárideo (LPS) da membrana externa de gram-negativos → desestabiliza membrana → aumenta permeabilidade → morte celular. Bactericida rápido. Ativo contra KPC, NDM, OXA-48, Acinetobacter MDR, Pseudomonas MDR. Último recurso para ESKAPE.',
      'es': 'Se une a lipopolisacárido (LPS) de la membrana externa de gram-negativos → desestabiliza membrana → aumenta permeabilidad → muerte celular. Bactericida rápido. Activo contra KPC, NDM, OXA-48, Acinetobacter MDR, Pseudomonas MDR. Último recurso para ESKAPE.',
    },
    warning: {
      'pt': 'NEFROTÓXICA — monitorar diariamente. NEUROTÓXICA — parestesias, bloqueio neuromuscular. Usar APENAS em infecções documentadas por gram-negativos pan-resistentes (último recurso). Associar com outro agente ativo para evitar emergência de resistência.',
      'es': 'NEFROTÓXICA — monitorear diariamente. NEUROTÓXICA — parestesias, bloqueo neuromuscular. Usar SOLO en infecciones documentadas por gram-negativos pan-resistentes (último recurso). Asociar con otro agente activo para evitar emergencia de resistencia.',
    },
    adverse: {
      'pt': ['Nefrotoxicidade aguda (30–60%)', 'Parestesias/neurotoxicidade', 'Bloqueio neuromuscular', 'Flebite', 'Febre e calafrios', 'Hipopotassemia'],
      'es': ['Nefrotoxicidad aguda (30–60%)', 'Parestesias/neurotoxicidad', 'Bloqueo neuromuscular', 'Flebitis', 'Fiebre y escalofríos', 'Hipopotasemia'],
    },
  ),

  DrugModel(
    id: 'esomeprazol',
    group: 'Gastroenterología',
    name: 'Esomeprazol',
    className: {'pt': 'Inibidor da Bomba de Prótons (IBP)', 'es': 'Inhibidor de la Bomba de Protones (IBP)'},
    category: {'pt': 'Digestivo / IBP', 'es': 'Digestivo / IBP'},
    route: 'VO / IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'DRGE/úlcera: 20–40 mg/dia VO | Sangramento GI agudo: 80 mg IV bolus → infusão 8 mg/h × 72 h | Erradicação H. pylori: 40 mg 2×/dia (em esquema triplo) | Prevenção AINE: 20 mg/dia',
      'es': 'ERGE/úlcera: 20–40 mg/día VO | Sangrado GI agudo: 80 mg IV bolo → infusión 8 mg/h × 72 h | Erradicación H. pylori: 40 mg 2×/día (en esquema triple) | Prevención AINE: 20 mg/día',
    },
    frequency: {'pt': '1–2×/dia', 'es': '1–2×/día'},
    renalAlert: {
      'pt': 'Sem ajuste necessário em IRC. Metabolismo hepático (CYP2C19).',
      'es': 'Sin ajuste necesario en IRC. Metabolismo hepático (CYP2C19).',
    },
    elderlyAlert: {
      'pt': 'Usar dose mínima eficaz. Uso prolongado associado a hipomagnesemia, fraturas osteoporóticas, infecção por C. difficile e pneumonia aspirativa. Reavaliar indicação periodicamente.',
      'es': 'Usar dosis mínima eficaz. Uso prolongado asociado a hipomagnesemia, fracturas osteoporóticas, infección por C. difficile y neumonía aspirativa. Reevaluar indicación periódicamente.',
    },
    mechanism: {
      'pt': 'S-enantiômero do omeprazol. Inibe irreversivelmente a H⁺/K⁺-ATPase (bomba de prótons) da célula parietal gástrica → supressão ácida superior ao omeprazol em alguns pacientes (metabolizadores rápidos CYP2C19). Início de ação 1 h; efeito máximo em 4–5 dias.',
      'es': 'S-enantiómero del omeprazol. Inhibe irreversiblemente la H⁺/K⁺-ATPasa (bomba de protones) de la célula parietal gástrica → supresión ácida superior al omeprazol en algunos pacientes (metabolizadores rápidos CYP2C19). Inicio de acción 1 h; efecto máximo en 4–5 días.',
    },
    warning: {
      'pt': 'Interação com clopidogrel (inibe CYP2C19 → reduz ativação do clopidogrel) — preferir pantoprazol. Hipomagnesemia em uso > 3 meses. Risco de nefrite intersticial. Não suspender abruptamente (efeito rebote).',
      'es': 'Interacción con clopidogrel (inhibe CYP2C19 → reduce activación del clopidogrel) — preferir pantoprazol. Hipomagnesemia en uso > 3 meses. Riesgo de nefritis intersticial. No suspender abruptamente (efecto rebote).',
    },
    adverse: {
      'pt': ['Cefaleia', 'Diarreia', 'Náusea', 'Flatulência', 'Hipomagnesemia (crônico)', 'Infecção por C. difficile', 'Fraturas (uso prolongado)', 'Nefrite intersticial (raro)'],
      'es': ['Cefalea', 'Diarrea', 'Náusea', 'Flatulencia', 'Hipomagnesemia (crónico)', 'Infección por C. difficile', 'Fracturas (uso prolongado)', 'Nefritis intersticial (raro)'],
    },
  ),

  DrugModel(
    id: 'ranitidina',
    group: 'Gastroenterología',
    name: 'Ranitidina (referência histórica) / Ranitidina (referencia histórica)',
    className: {'pt': 'Antagonista H2 (histamínico)', 'es': 'Antagonista H2 (histamínico)'},
    category: {'pt': 'Digestivo / Antiácido', 'es': 'Digestivo / Antiácido'},
    route: 'VO / IV / IM',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'VO: 150 mg 2×/dia ou 300 mg noturno | IV: 50 mg a cada 6–8 h ou infusão 6,25 mg/h | Crianças: 2–4 mg/kg/dia ÷ 2 doses | NOTA: retirada do mercado no Brasil (2019) por NDMA; famotidina é alternativa preferida',
      'es': 'VO: 150 mg 2×/día o 300 mg nocturno | IV: 50 mg cada 6–8 h o infusión 6,25 mg/h | Niños: 2–4 mg/kg/día ÷ 2 dosis | NOTA: retirada del mercado (2019) por NDMA; famotidina es alternativa preferida',
    },
    frequency: {'pt': '1–2×/dia', 'es': '1–2×/día'},
    renalAlert: {
      'pt': 'TFG < 50: dose a cada 24–48 h. Hemodiálise: 150 mg após sessão.',
      'es': 'TFG < 50: dosis cada 24–48 h. Hemodiálisis: 150 mg después de sesión.',
    },
    elderlyAlert: {
      'pt': 'Confusão mental (raro). Preferir IBP para supressão ácida de longa duração.',
      'es': 'Confusión mental (raro). Preferir IBP para supresión ácida de larga duración.',
    },
    mechanism: {
      'pt': 'Antagonista competitivo reversível do receptor H2 da histamina na célula parietal → reduz secreção ácida basal e estimulada pela histamina. Menos potente que IBPs. Retirada do mercado em 2019–2020 (FDA/Anvisa) por contaminação com NDMA (nitrosamina carcinogênica).',
      'es': 'Antagonista competitivo reversible del receptor H2 de histamina en célula parietal → reduce secreción ácida basal y estimulada por histamina. Menos potente que IBPs. Retirada del mercado en 2019–2020 (FDA/Anvisa) por contaminación con NDMA (nitrosamina carcinogénica).',
    },
    warning: {
      'pt': 'RETIRADA DO MERCADO (NDMA). Alternativas: famotidina (antagonista H2), omeprazol/pantoprazol (IBP). Não dispensar ou prescrever ranitidina no Brasil desde 2020.',
      'es': 'RETIRADA DEL MERCADO (NDMA). Alternativas: famotidina (antagonista H2), omeprazol/pantoprazol (IBP). No dispensar ni prescribir ranitidina desde 2020.',
    },
    adverse: {
      'pt': ['Cefaleia', 'Tontura', 'Constipação/diarreia', 'Confusão (idosos, IV)', 'Ginecomastia (raro)', 'Hepatite (raro)', 'NDMA — carcinogênico (causa da retirada)'],
      'es': ['Cefalea', 'Mareo', 'Estreñimiento/diarrea', 'Confusión (ancianos, IV)', 'Ginecomastia (raro)', 'Hepatitis (raro)', 'NDMA — carcinogénico (causa de la retirada)'],
    },
  ),

  DrugModel(
    id: 'metoclopramida',
    group: 'Gastroenterología',
    name: 'Metoclopramida',
    className: {'pt': 'Procinético / Antiemético (antagonista D2)', 'es': 'Procinético / Antiemético (antagonista D2)'},
    category: {'pt': 'Digestivo / Antiemético', 'es': 'Digestivo / Antiemético'},
    route: 'VO / IV / IM',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Náusea/vômito: 10 mg VO/IV/IM 3×/dia (antes das refeições) | Gastroparesia: 10 mg 30 min antes das refeições × 4–12 semanas | IV: 10 mg lento (> 3 min) | Pediátrico: 0,1–0,15 mg/kg/dose (máx 10 mg)',
      'es': 'Náusea/vómito: 10 mg VO/IV/IM 3×/día (antes de comidas) | Gastroparesia: 10 mg 30 min antes de comidas × 4–12 semanas | IV: 10 mg lento (> 3 min) | Pediátrico: 0,1–0,15 mg/kg/dosis (máx 10 mg)',
    },
    frequency: {'pt': '3×/dia (antes das refeições)', 'es': '3×/día (antes de comidas)'},
    renalAlert: {
      'pt': 'TFG < 40: reduzir dose 50%. TFG < 15: evitar — risco de acúmulo e distonia.',
      'es': 'TFG < 40: reducir dosis 50%. TFG < 15: evitar — riesgo de acumulación y distonía.',
    },
    elderlyAlert: {
      'pt': 'Beers: EVITAR. Risco de distonia aguda, parkinsonismo e discinesia tardia (especialmente em uso > 12 semanas). Alternativas: ondansetrona, domperidona.',
      'es': 'Beers: EVITAR. Riesgo de distonía aguda, parkinsonismo y discinesia tardía (especialmente en uso > 12 semanas). Alternativas: ondansetrón, domperidona.',
    },
    mechanism: {
      'pt': 'Antagonista D2 central (antiemético via zona quimiorreceptora) e periférico (procinético: ↑ tônus esfíncter esofagiano, ↑ peristaltismo, ↑ esvaziamento gástrico). Também antagonista 5-HT3 em altas doses. Atravessa barreira hematoencefálica → EPS.',
      'es': 'Antagonista D2 central (antiemético vía zona quimiorreceptora) y periférico (procinético: ↑ tono esfínter esofágico, ↑ peristaltismo, ↑ vaciamiento gástrico). También antagonista 5-HT3 en dosis altas. Atraviesa barrera hematoencefálica → EPS.',
    },
    warning: {
      'pt': 'FDA Black Box: discinesia tardia irreversível com uso > 12 semanas ou em dose alta. Limitar a cursos curtos (< 12 semanas). Distonia aguda: tratar com biperideno/difenidramina IV. Evitar em Parkinson.',
      'es': 'FDA Black Box: discinesia tardía irreversible con uso > 12 semanas o dosis alta. Limitar a cursos cortos (< 12 semanas). Distonía aguda: tratar con biperideno/difenhidramina IV. Evitar en Parkinson.',
    },
    adverse: {
      'pt': ['Distonia aguda (especialmente jovens)', 'Sonolência', 'Agitação/ansiedade', 'Parkinsonismo (uso prolongado)', 'Discinesia tardia (irreversível)', 'Hiperprolactinemia', 'Diarreia'],
      'es': ['Distonía aguda (especialmente jóvenes)', 'Somnolencia', 'Agitación/ansiedad', 'Parkinsonismo (uso prolongado)', 'Discinesia tardía (irreversible)', 'Hiperprolactinemia', 'Diarrea'],
    },
  ),

  DrugModel(
    id: 'domperidona',
    group: 'Gastroenterología',
    name: 'Domperidona',
    className: {'pt': 'Procinético / Antiemético (antagonista D2 periférico)', 'es': 'Procinético / Antiemético (antagonista D2 periférico)'},
    category: {'pt': 'Digestivo / Procinético', 'es': 'Digestivo / Procinético'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Náusea/gastroparesia: 10 mg VO 3×/dia 15–30 min antes das refeições | Dose máxima: 30 mg/dia × máx 1 semana (recomendação EMA) | Pediátrico: 0,25 mg/kg/dose 3×/dia',
      'es': 'Náusea/gastroparesia: 10 mg VO 3×/día 15–30 min antes de comidas | Dosis máxima: 30 mg/día × máx 1 semana (recomendación EMA) | Pediátrico: 0,25 mg/kg/dosis 3×/día',
    },
    frequency: {'pt': '3×/dia (pré-refeição)', 'es': '3×/día (pre-comida)'},
    renalAlert: {
      'pt': 'IRC moderada-grave: reduzir frequência para 1–2×/dia. Metabolismo hepático extenso.',
      'es': 'IRC moderada-grave: reducir frecuencia a 1–2×/día. Metabolismo hepático extenso.',
    },
    elderlyAlert: {
      'pt': 'Prolongamento QTc — monitorar ECG em idosos com fatores de risco cardíacos. Evitar com inibidores CYP3A4 potentes (cetoconazol, claritromicina). Usar menor dose pelo menor tempo possível.',
      'es': 'Prolongación QTc — monitorear ECG en ancianos con factores de riesgo cardíacos. Evitar con inhibidores CYP3A4 potentes (ketoconazol, claritromicina). Usar menor dosis el menor tiempo posible.',
    },
    mechanism: {
      'pt': 'Antagonista D2 periférico (não atravessa BHE significativamente) → menos EPS que metoclopramida. Procinético gástrico. Age na zona gatilho do vômito (fora da BHE). Prolonga QTc via bloqueio canal hERG.',
      'es': 'Antagonista D2 periférico (no atraviesa BHE significativamente) → menos EPS que metoclopramida. Procinético gástrico. Actúa en zona de gatillo del vómito (fuera de BHE). Prolonga QTc vía bloqueo canal hERG.',
    },
    warning: {
      'pt': 'Prolongamento QTc → arritmia ventricular grave (torsades de pointes). Contraindicado: QTc > 470 ms (mulher) ou > 450 ms (homem), hipocalemia, hipomagnesemia, bradicardia, com fármacos que prolongam QT.',
      'es': 'Prolongación QTc → arritmia ventricular grave (torsades de pointes). Contraindicado: QTc > 470 ms (mujer) o > 450 ms (hombre), hipopotasemia, hipomagnesemia, bradicardia, con fármacos que prolongan QT.',
    },
    adverse: {
      'pt': ['Prolongamento QTc', 'Hiperprolactinemia (galactorreia, amenorreia)', 'Cefaleia', 'Boca seca', 'EPS (raro — periférico)', 'Diarreia'],
      'es': ['Prolongación QTc', 'Hiperprolactinemia (galactorrea, amenorrea)', 'Cefalea', 'Boca seca', 'EPS (raro — periférico)', 'Diarrea'],
    },
  ),

  DrugModel(
    id: 'escopolamina',
    group: 'Gastroenterología',
    name: 'Escopolamina (Hioscina)',
    className: {'pt': 'Anticolinérgico / Antiespasmódico', 'es': 'Anticolinérgico / Antiespasmódico'},
    category: {'pt': 'Digestivo / Antiespasmódico', 'es': 'Digestivo / Antiespasmódico'},
    route: 'VO / IV / IM / SC / Transdérmico',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Espasmo GI/biliar: 20 mg VO/IV/IM 3–4×/dia | IV lento (2 min): 20 mg | Transdérmico (cinetose): 1,5 mg patch retro-auricular × 3 dias | Antissecretor paliativo: 0,2–0,4 mg SC a cada 4 h',
      'es': 'Espasmo GI/biliar: 20 mg VO/IV/IM 3–4×/día | IV lento (2 min): 20 mg | Transdérmico (cinetosis): 1,5 mg parche retroauricular × 3 días | Antisecretor paliativo: 0,2–0,4 mg SC cada 4 h',
    },
    frequency: {'pt': '3–4×/dia', 'es': '3–4×/día'},
    renalAlert: {
      'pt': 'Usar com cautela em IRC — risco de retenção urinária e acúmulo. Reduzir dose.',
      'es': 'Usar con cautela en IRC — riesgo de retención urinaria y acumulación. Reducir dosis.',
    },
    elderlyAlert: {
      'pt': 'Beers: EVITAR em idosos. Efeitos anticolinérgicos intensos: confusão, retenção urinária, glaucoma agudo de ângulo fechado, constipação, taquicardia.',
      'es': 'Beers: EVITAR en adultos mayores. Efectos anticolinérgicos intensos: confusión, retención urinaria, glaucoma agudo de ángulo cerrado, estreñimiento, taquicardia.',
    },
    mechanism: {
      'pt': 'Bloqueia receptores muscarínicos M1/M2/M3 → inibe peristaltismo involuntário, reduz secreções glandulares, relaxa músculo liso. A forma butilbrometo (Buscopan) tem menor penetração no SNC que a base lipofílica.',
      'es': 'Bloquea receptores muscarínicos M1/M2/M3 → inhibe peristaltismo involuntario, reduce secreciones glandulares, relaja músculo liso. La forma butilbromuro (Buscapina) tiene menor penetración en SNC que la base lipofílica.',
    },
    warning: {
      'pt': 'Contraindicado em glaucoma de ângulo fechado, retenção urinária, megacólon tóxico, miastenia gravis. Pode mascarar obstrução intestinal. Forma transdérmica: lavar mãos após aplicar (midríase se tocar olhos).',
      'es': 'Contraindicado en glaucoma de ángulo cerrado, retención urinaria, megacolon tóxico, miastenia gravis. Puede enmascarar obstrucción intestinal. Forma transdérmica: lavar manos después de aplicar (midriasis si toca ojos).',
    },
    adverse: {
      'pt': ['Boca seca', 'Visão turva (midríase)', 'Retenção urinária', 'Constipação', 'Taquicardia', 'Confusão (SNC, forma lipofílica)', 'Rubor facial'],
      'es': ['Boca seca', 'Visión borrosa (midriasis)', 'Retención urinaria', 'Estreñimiento', 'Taquicardia', 'Confusión (SNC, forma lipofílica)', 'Rubor facial'],
    },
  ),

  DrugModel(
    id: 'loperamida',
    group: 'Gastroenterología',
    name: 'Loperamida',
    className: {'pt': 'Antidiarreico (opioide periférico)', 'es': 'Antidiarreico (opioide periférico)'},
    category: {'pt': 'Digestivo / Antidiarreico', 'es': 'Digestivo / Antidiarreico'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Diarreia aguda: 4 mg (dose inicial) → 2 mg após cada evacuação líquida (máx 16 mg/dia × 2 dias) | Diarreia crônica (SII, ostomia): 2–4 mg 2–4×/dia | Pediátrico > 2 anos: 1 mg/dose (ver bula)',
      'es': 'Diarrea aguda: 4 mg (dosis inicial) → 2 mg después de cada evacuación líquida (máx 16 mg/día × 2 días) | Diarrea crónica (SII, ostomía): 2–4 mg 2–4×/día | Pediátrico > 2 años: 1 mg/dosis (ver prospecto)',
    },
    frequency: {'pt': 'conforme evacuações', 'es': 'según evacuaciones'},
    renalAlert: {
      'pt': 'Sem ajuste necessário. Metabolismo hepático.',
      'es': 'Sin ajuste necesario. Metabolismo hepático.',
    },
    elderlyAlert: {
      'pt': 'Usar com cautela — risco de distensão abdominal e megacólon em idosos debilitados. Monitorar constipação.',
      'es': 'Usar con cautela — riesgo de distensión abdominal y megacolon en ancianos debilitados. Monitorear estreñimiento.',
    },
    mechanism: {
      'pt': 'Agonista receptor μ-opioide no plexo mioentérico intestinal → ↓ peristaltismo, ↑ tônus esfíncter anal, ↑ absorção de água e eletrólitos. Não atravessa BHE em doses terapêuticas (não tem efeito analgésico central). Efeito antidiarreico puro.',
      'es': 'Agonista receptor μ-opioide en plexo mioentérico intestinal → ↓ peristaltismo, ↑ tono esfínter anal, ↑ absorción de agua y electrolitos. No atraviesa BHE en dosis terapéuticas (sin efecto analgésico central). Efecto antidiarreico puro.',
    },
    warning: {
      'pt': 'CONTRAINDICADO em diarreia com sangue/muco ou febre alta (infecção invasiva — risco de megacólon). CONTRAINDICADO em < 2 anos. Em superdosagem: QT prolongado, arritmias (efeito opioide central). Não usar em colite pseudomembranosa.',
      'es': 'CONTRAINDICADO en diarrea con sangre/moco o fiebre alta (infección invasiva — riesgo de megacolon). CONTRAINDICADO en < 2 años. En sobredosis: QT prolongado, arritmias (efecto opioide central). No usar en colitis pseudomembranosa.',
    },
    adverse: {
      'pt': ['Constipação', 'Distensão abdominal', 'Náusea', 'Tontura', 'Boca seca', 'QTc prolongado (superdosagem)', 'Íleo paralítico (dose excessiva)'],
      'es': ['Estreñimiento', 'Distensión abdominal', 'Náusea', 'Mareo', 'Boca seca', 'QTc prolongado (sobredosis)', 'Íleo paralítico (dosis excesiva)'],
    },
  ),

  DrugModel(
    id: 'mesalazina',
    group: 'Gastroenterología',
    name: 'Mesalazina (5-aminossalicílico) / Mesalazina (5-aminosalicílico)',
    className: {'pt': 'Anti-inflamatório intestinal (aminossalicilato)', 'es': 'Antiinflamatorio intestinal (aminosalicilato)'},
    category: {'pt': 'Digestivo / Doença Inflamatória Intestinal', 'es': 'Digestivo / Enfermedad Inflamatoria Intestinal'},
    route: 'VO / Retal (enema/supositório)',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'RCU ativa leve-moderada: 2,4–4,8 g/dia VO ÷ 2–4 doses | Manutenção RCU: 1,2–2,4 g/dia | Enema retal: 1–4 g/dia | Crohn (colônico): 3,2–4 g/dia | Pediátrico: 30–50 mg/kg/dia ÷ 2–4 doses',
      'es': 'CU activa leve-moderada: 2,4–4,8 g/día VO ÷ 2–4 dosis | Mantenimiento CU: 1,2–2,4 g/día | Enema rectal: 1–4 g/día | Crohn (colónico): 3,2–4 g/día | Pediátrico: 30–50 mg/kg/día ÷ 2–4 dosis',
    },
    frequency: {'pt': '2–4×/dia', 'es': '2–4×/día'},
    renalAlert: {
      'pt': 'TFG < 30: EVITAR — nefrotoxicidade intersticial. Monitorar função renal regularmente (nefrite intersticial assintomática). Contraindicado em IRC grave.',
      'es': 'TFG < 30: EVITAR — nefrotoxicidad intersticial. Monitorear función renal regularmente (nefritis intersticial asintomática). Contraindicado en IRC grave.',
    },
    elderlyAlert: {
      'pt': 'Monitorar função renal (nefrite intersticial silenciosa). Hemograma periódico (discrasias sanguíneas raras).',
      'es': 'Monitorear función renal (nefritis intersticial silenciosa). Hemograma periódico (discrasias sanguíneas raras).',
    },
    mechanism: {
      'pt': 'Inibe síntese de prostaglandinas e leucotrienos na mucosa intestinal → reduz inflamação local. Inibe NF-κB. Ação tópica predominante no cólon (formulações de liberação retardada). Primeira linha para RCU leve-moderada.',
      'es': 'Inhibe síntesis de prostaglandinas y leucotrienos en mucosa intestinal → reduce inflamación local. Inhibe NF-κB. Acción tópica predominante en colon (formulaciones de liberación retardada). Primera línea para CU leve-moderada.',
    },
    warning: {
      'pt': 'Nefrite intersticial (monitorar creatinina a cada 6–12 meses). Síndrome de hipersensibilidade à mesalazina (piora paradoxal da colite — raro). Evitar em alergia à aspirina/salicilatos.',
      'es': 'Nefritis intersticial (monitorear creatinina cada 6–12 meses). Síndrome de hipersensibilidad a mesalazina (empeoramiento paradójico de la colitis — raro). Evitar en alergia a aspirina/salicilatos.',
    },
    adverse: {
      'pt': ['Cefaleia', 'Náusea', 'Diarreia', 'Dor abdominal', 'Nefrite intersticial (crônico)', 'Pancreatite (raro)', 'Pericardite/miocardite (raro)', 'Leucopenia (raro)'],
      'es': ['Cefalea', 'Náusea', 'Diarrea', 'Dolor abdominal', 'Nefritis intersticial (crónico)', 'Pancreatitis (raro)', 'Pericarditis/miocarditis (raro)', 'Leucopenia (raro)'],
    },
  ),

  DrugModel(
    id: 'octreotida',
    group: 'Gastroenterología',
    name: 'Octreotida',
    className: {'pt': 'Análogo da somatostatina', 'es': 'Análogo de somatostatina'},
    category: {'pt': 'Digestivo / Emergência GI / Endocrino', 'es': 'Digestivo / Emergencia GI / Endocrino'},
    route: 'SC / IV / IM (LAR depot)',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Sangramento varizes esofágicas: 50 µg IV bolus → infusão 25–50 µg/h × 5 dias | Síndrome carcinoide: 100–600 µg/dia SC ÷ 2–4 doses | Acromegalia: 100–500 µg SC 3×/dia | LAR depot: 20–30 mg IM a cada 4 semanas | Diarreia refratária oncológica: 50–200 µg SC 2–3×/dia',
      'es': 'Sangrado várices esofágicas: 50 µg IV bolo → infusión 25–50 µg/h × 5 días | Síndrome carcinoide: 100–600 µg/día SC ÷ 2–4 dosis | Acromegalia: 100–500 µg SC 3×/día | LAR depot: 20–30 mg IM cada 4 semanas | Diarrea refractaria oncológica: 50–200 µg SC 2–3×/día',
    },
    frequency: {'pt': 'conforme indicação', 'es': 'según indicación'},
    renalAlert: {
      'pt': 'Sem ajuste significativo necessário em IRC.',
      'es': 'Sin ajuste significativo necesario en IRC.',
    },
    elderlyAlert: {
      'pt': 'Monitorar glicemia (inibe insulina e glucagon → hipoglicemia ou hiperglicemia). Cálculos biliares em uso prolongado.',
      'es': 'Monitorear glucemia (inhibe insulina y glucagón → hipoglucemia o hiperglucemia). Cálculos biliares en uso prolongado.',
    },
    mechanism: {
      'pt': 'Análogo sintético da somatostatina (meia-vida 1,5–2 h vs somatostatina 2–3 min). Liga-se receptores SSTR (subtipos 2 e 5) → ↓ GH, IGF-1, insulina, glucagon, gastrina, secretina, VIP → ↓ fluxo esplâncnico e pressão portal (varizes) + ↓ secreções GI.',
      'es': 'Análogo sintético de somatostatina (vida media 1,5–2 h vs somatostatina 2–3 min). Se une a receptores SSTR (subtipos 2 y 5) → ↓ GH, IGF-1, insulina, glucagón, gastrina, secretina, VIP → ↓ flujo esplácnico y presión portal (várices) + ↓ secreciones GI.',
    },
    warning: {
      'pt': 'Colelitíase em uso prolongado (↓ motilidade vesicular) — ultrassom biliar periódico. Bradicardia sinusal. Hipoglicemia ou hiperglicemia (especialmente em DM). Não usar como único tratamento na hemorragia varicosa — associar à endoscopia.',
      'es': 'Colelitiasis en uso prolongado (↓ motilidad vesicular) — ecografía biliar periódica. Bradicardia sinusal. Hipoglucemia o hiperglucemia (especialmente en DM). No usar como único tratamiento en hemorragia varicosa — asociar a endoscopia.',
    },
    adverse: {
      'pt': ['Dor no local de injeção', 'Náusea', 'Diarreia/esteatorreia', 'Dor abdominal', 'Hiperglicemia/hipoglicemia', 'Colelitíase (uso prolongado)', 'Bradicardia', 'Cefaleia'],
      'es': ['Dolor en sitio de inyección', 'Náusea', 'Diarrea/esteatorrea', 'Dolor abdominal', 'Hiperglucemia/hipoglucemia', 'Colelitiasis (uso prolongado)', 'Bradicardia', 'Cefalea'],
    },
  ),

  DrugModel(
    id: 'terlipressina',
    group: 'Cardiovascular y HTA',
    name: 'Terlipressina / Terlipresina',
    className: {'pt': 'Análogo da vasopressina (vasoconstritor esplâncnico)', 'es': 'Análogo de vasopresina (vasoconstrictor esplácnico)'},
    category: {'pt': 'Emergência / Digestivo', 'es': 'Emergencia / Digestivo'},
    route: 'IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Sangramento varicoso: 2 mg IV bolus → 1–2 mg a cada 4–6 h × 5 dias | Síndrome hepatorrenal tipo 1: 0,5–1 mg IV a cada 4–6 h (associar albumina 1 g/kg) | Dose máxima: 12 mg/dia',
      'es': 'Sangrado varicoso: 2 mg IV bolo → 1–2 mg cada 4–6 h × 5 días | Síndrome hepatorrenal tipo 1: 0,5–1 mg IV cada 4–6 h (asociar albúmina 1 g/kg) | Dosis máxima: 12 mg/día',
    },
    frequency: {'pt': 'a cada 4–6 h', 'es': 'cada 4–6 h'},
    renalAlert: {
      'pt': 'Usar com cautela em IRC — risco de hiponatremia e sobrecarga hídrica. Monitorar eletrólitos.',
      'es': 'Usar con cautela en IRC — riesgo de hiponatremia y sobrecarga hídrica. Monitorear electrolitos.',
    },
    elderlyAlert: {
      'pt': 'Monitorar isquemia miocárdica, arritmias e isquemia periférica em idosos com doença vascular prévia.',
      'es': 'Monitorear isquemia miocárdica, arritmias e isquemia periférica en ancianos con enfermedad vascular previa.',
    },
    mechanism: {
      'pt': 'Pró-fármaco: converte-se em lisina-vasopressina → agonista receptor V1 (vasos esplâncnicos) → vasoconstrição esplâncnica → ↓ fluxo portal e pressão das varizes. Também efeito antidiurético via V2. Meia-vida ação 4–6 h.',
      'es': 'Profármaco: se convierte en lisina-vasopresina → agonista receptor V1 (vasos esplácnicos) → vasoconstricción esplácnica → ↓ flujo portal y presión de várices. También efecto antidiurético vía V2. Vida media acción 4–6 h.',
    },
    warning: {
      'pt': 'Contraindicado em doença coronariana grave (vasoconstrição sistêmica → isquemia). Hiponatremia dilucional. Isquemia periférica (dedos, escroto). Arritmias cardíacas. Monitorar ECG.',
      'es': 'Contraindicado en enfermedad coronaria grave (vasoconstricción sistémica → isquemia). Hiponatremia dilucional. Isquemia periférica (dedos, escroto). Arritmias cardíacas. Monitorear ECG.',
    },
    adverse: {
      'pt': ['Isquemia miocárdica', 'Arritmias', 'Hipertensão', 'Isquemia periférica', 'Hiponatremia', 'Bradicardia', 'Dor abdominal (cólica)', 'Palidez'],
      'es': ['Isquemia miocárdica', 'Arritmias', 'Hipertensión', 'Isquemia periférica', 'Hiponatremia', 'Bradicardia', 'Dolor abdominal (cólico)', 'Palidez'],
    },
  ),

  DrugModel(
    id: 'dopamina',
    group: 'Cardiovascular y HTA',
    name: 'Dopamina',
    className: {'pt': 'Catecolamina vasoativa endógena', 'es': 'Catecolamina vasoactiva endógena'},
    category: {'pt': 'Emergência / UTI / Vasoativo', 'es': 'Emergencia / UTI / Vasoactivo'},
    route: 'IV (infusão contínua exclusivamente)',
    doseType: 'mcg_kg_min',
    mcgKgMinStart: 2.0,
    mcgKgMinMax: 20.0,
    fixedDose: {
      'pt': 'Dose dopaminérgica/renal: 1–3 µg/kg/min (↑ fluxo renal/esplâncnico — evidência controversa) | Dose inotrópica (β1): 3–10 µg/kg/min (↑ DC, FC) | Dose vasopressora (α1): 10–20 µg/kg/min (↑ PAM) | Preparar: 200 mg em 250 mL SG5% (800 µg/mL)',
      'es': 'Dosis dopaminérgica/renal: 1–3 µg/kg/min (↑ flujo renal/esplácnico — evidencia controvertida) | Dosis inotrópica (β1): 3–10 µg/kg/min (↑ GC, FC) | Dosis vasopresora (α1): 10–20 µg/kg/min (↑ PAM) | Preparar: 200 mg en 250 mL SG5% (800 µg/mL)',
    },
    frequency: {'pt': 'infusão contínua IV', 'es': 'infusión continua IV'},
    renalAlert: {
      'pt': 'Doses baixas (1–3 µg/kg/min) não protegem rim em estudos controlados (mito da "dose renal"). Monitorar débito urinário. Não substituir reposição volêmica adequada.',
      'es': 'Dosis bajas (1–3 µg/kg/min) no protegen el riñón en estudios controlados (mito de la "dosis renal"). Monitorear diuresis. No sustituir reposición volémica adecuada.',
    },
    elderlyAlert: {
      'pt': 'Maior risco de arritmias (FA é comum) e isquemia em idosos. Monitorar ECG continuamente. Preferir noradrenalina no choque séptico.',
      'es': 'Mayor riesgo de arritmias (FA es común) e isquemia en ancianos. Monitorear ECG continuamente. Preferir noradrenalina en choque séptico.',
    },
    mechanism: {
      'pt': 'Precursor da noradrenalina. Dose-dependente: D1/D2 (1–3 µg/kg/min) → vasodilatação renal; β1 (3–10 µg/kg/min) → inotrófico/cronotrópico; α1 (> 10 µg/kg/min) → vasoconstrição. Meia-vida 2 min → titular via bomba de infusão.',
      'es': 'Precursor de noradrenalina. Dosis-dependiente: D1/D2 (1–3 µg/kg/min) → vasodilatación renal; β1 (3–10 µg/kg/min) → inotrópico/cronotrópico; α1 (> 10 µg/kg/min) → vasoconstricción. Vida media 2 min → titular vía bomba de infusión.',
    },
    warning: {
      'pt': 'NUNCA em bolus. Extravasamento causa necrose tecidual grave (tratar com fentolamina SC local). Estudos mostram maior mortalidade vs noradrenalina em choque séptico (Surviving Sepsis Campaign: preferir noradrenalina). Alto risco de FA. Monitorar ECG.',
      'es': 'NUNCA en bolo. Extravasación causa necrosis tisular grave (tratar con fentolamina SC local). Estudios muestran mayor mortalidad vs noradrenalina en choque séptico (Surviving Sepsis Campaign: preferir noradrenalina). Alto riesgo de FA. Monitorear ECG.',
    },
    adverse: {
      'pt': ['Taquicardia e arritmias (FA, ESV)', 'Isquemia miocárdica', 'Hipertensão', 'Necrose por extravasamento', 'Náusea/vômito', 'Cefaleia', 'Piloereção'],
      'es': ['Taquicardia y arritmias (FA, ESV)', 'Isquemia miocárdica', 'Hipertensión', 'Necrosis por extravasación', 'Náusea/vómito', 'Cefalea', 'Piloerección'],
    },
  ),

  DrugModel(
    id: 'manitol',
    group: 'Neurología y Psiquiatría',
    name: 'Manitol',
    className: {'pt': 'Diurético osmótico', 'es': 'Diurético osmótico'},
    category: {'pt': 'Emergência / Neurológico / Diurético', 'es': 'Emergencia / Neurológico / Diurético'},
    route: 'IV (infusão; NUNCA IM/SC)',
    doseType: 'mg_kg',
    mgKg: 1.0,
    fixedDose: {
      'pt': 'Hipertensão intracraniana aguda: 0,25–1 g/kg IV em 15–20 min (solução 20%; ex.: 100 g em 500 mL) | Glaucoma agudo: 1–2 g/kg IV | Profilaxia IRA peri-operatória: 0,5 g/kg | Manutenção (neuro-UTI): 0,25–0,5 g/kg a cada 4–6 h guiado por osmolalidade',
      'es': 'Hipertensión intracraneal aguda: 0,25–1 g/kg IV en 15–20 min (solución 20%; ej.: 100 g en 500 mL) | Glaucoma agudo: 1–2 g/kg IV | Profilaxis IRA perioperatoria: 0,5 g/kg | Mantenimiento (neuro-UCI): 0,25–0,5 g/kg cada 4–6 h guiado por osmolalidad',
    },
    frequency: {'pt': 'conforme osmolalidade sérica (manter gap osmótico < 20 mOsm/kg)', 'es': 'según osmolalidad sérica (mantener gap osmótico < 20 mOsm/kg)'},
    renalAlert: {
      'pt': 'CONTRAINDICADO em anúria por IRC (acumula → toxicidade). Monitorar osmolalidade sérica e gap osmótico a cada dose. Gap > 20 mOsm/kg → suspender.',
      'es': 'CONTRAINDICADO en anuria por IRC (acumula → toxicidad). Monitorear osmolalidad sérica y gap osmótico en cada dosis. Gap > 20 mOsm/kg → suspender.',
    },
    elderlyAlert: {
      'pt': 'Risco elevado de desidratação, hiperosmolaridade e insuficiência renal aguda. Monitorar eletrólitos e função renal após cada infusão.',
      'es': 'Riesgo elevado de deshidratación, hiperosmolaridad e insuficiencia renal aguda. Monitorear electrolitos y función renal después de cada infusión.',
    },
    mechanism: {
      'pt': 'Álcool hexaidrico osmoticamente ativo → cria gradiente osmótico entre plasma e tecido cerebral/ocular → retira água desses compartimentos → ↓ edema cerebral e PIC. Também ↑ diurese osmótica. Início de ação 15–30 min; duração 3–8 h.',
      'es': 'Alcohol hexahídrico osmóticamente activo → crea gradiente osmótico entre plasma y tejido cerebral/ocular → extrae agua de esos compartimentos → ↓ edema cerebral y PIC. También ↑ diuresis osmótica. Inicio de acción 15–30 min; duración 3–8 h.',
    },
    warning: {
      'pt': 'Monitorar osmolalidade sérica — gap osmótico > 20 mOsm/kg indica toxicidade por acúmulo. Pode piorar edema pulmonar (não usar em EAP). Filtrar se cristalizar (refrigeração). Contraindicado em anúria e DSIC grave.',
      'es': 'Monitorear osmolalidad sérica — gap osmótico > 20 mOsm/kg indica toxicidad por acumulación. Puede empeorar edema pulmonar (no usar en EPA). Filtrar si cristaliza (refrigeración). Contraindicado en anuria y DSIC grave.',
    },
    adverse: {
      'pt': ['Desidratação', 'Hipernatremia', 'Hipocalemia', 'Insuficiência renal aguda (uso excessivo)', 'Edema pulmonar (rebote)', 'Cefaleia', 'Náusea'],
      'es': ['Deshidratación', 'Hipernatremia', 'Hipopotasemia', 'Insuficiencia renal aguda (uso excesivo)', 'Edema pulmonar (rebote)', 'Cefalea', 'Náusea'],
    },
  ),

  DrugModel(
    id: 'varfarina',
    group: 'Anticoagulantes y Hemostasia',
    name: 'Varfarina / Warfarina',
    className: {'pt': 'Anticoagulante oral (antagonista vitamina K)', 'es': 'Anticoagulante oral (antagonista vitamina K)'},
    category: {'pt': 'Hematologia / Anticoagulante', 'es': 'Hematología / Anticoagulante'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Dose individualizada pelo INR alvo: iniciar 2,5–5 mg/dia (idosos/hepatopatas iniciar 1–2 mg) | INR alvo 2–3: FA, TEP, TVP, válvula biológica | INR alvo 2,5–3,5: prótese valvar mecânica | Ajustar dose conforme INR (monitorar 2–3×/semana no início)',
      'es': 'Dosis individualizada por INR objetivo: iniciar 2,5–5 mg/día (ancianos/hepatópatas iniciar 1–2 mg) | INR objetivo 2–3: FA, TEP, TVP, válvula biológica | INR objetivo 2,5–3,5: prótesis valvular mecánica | Ajustar dosis según INR (monitorear 2–3×/semana al inicio)',
    },
    frequency: {'pt': '1×/dia (mesmo horário)', 'es': '1×/día (misma hora)'},
    renalAlert: {
      'pt': 'IRC aumenta risco de sangramento — iniciar com dose menor, INR alvo mais baixo. Monitorar INR mais frequentemente. Uremia interfere na função plaquetária.',
      'es': 'IRC aumenta riesgo de sangrado — iniciar con dosis menor, INR objetivo más bajo. Monitorear INR más frecuentemente. Uremia interfiere en función plaquetaria.',
    },
    elderlyAlert: {
      'pt': 'Alto risco de sangramento — quedas, polifarmácia, disfunção hepática. Iniciar 1–2 mg/dia. INR alvo 2–2,5 em > 80 anos quando possível. Monitorar INR quinzenalmente quando estável.',
      'es': 'Alto riesgo de sangrado — caídas, polifarmacia, disfunción hepática. Iniciar 1–2 mg/día. INR objetivo 2–2,5 en > 80 años cuando sea posible. Monitorear INR quincenalmente cuando estable.',
    },
    mechanism: {
      'pt': 'Inibe epóxido redutase da vitamina K (VKORC1) → impede reciclagem da vitamina K → deficit de fatores II, VII, IX, X e proteínas C, S, Z. Início de ação: 36–72 h (depende de meia-vida dos fatores). Meia-vida varfarina 36–42 h.',
      'es': 'Inhibe epóxido reductasa de vitamina K (VKORC1) → impide reciclaje de vitamina K → déficit de factores II, VII, IX, X y proteínas C, S, Z. Inicio de acción: 36–72 h (depende de vida media de factores). Vida media warfarina 36–42 h.',
    },
    warning: {
      'pt': 'Faixa terapêutica ESTREITA — inúmeras interações alimentares (vitamina K) e farmacológicas (CYP2C9). INR > 4: risco grave de sangramento. Reversão: vitamina K + concentrado de complexo protrombínico (CCP) ou PFC. Genótipo CYP2C9/VKORC1 influencia dose.',
      'es': 'Margen terapéutico ESTRECHO — numerosas interacciones alimentarias (vitamina K) y farmacológicas (CYP2C9). INR > 4: riesgo grave de sangrado. Reversión: vitamina K + concentrado de complejo protrombínico (CCP) o PFC. Genotipo CYP2C9/VKORC1 influye en la dosis.',
    },
    adverse: {
      'pt': ['Sangramento (principal — desde epistaxe até AVC hemorrágico)', 'Necrose cutânea (início tto — deficit proteína C)', 'Síndrome do dedo roxo', 'Osteoporose (uso prolongado)', 'Hepatotoxicidade (raro)'],
      'es': ['Sangrado (principal — desde epistaxis hasta ACV hemorrágico)', 'Necrosis cutánea (inicio tto — déficit proteína C)', 'Síndrome del dedo morado', 'Osteoporosis (uso prolongado)', 'Hepatotoxicidad (raro)'],
    },
  ),

  DrugModel(
    id: 'clopidogrel',
    group: 'Cardiovascular y HTA',
    name: 'Clopidogrel',
    className: {'pt': 'Antiplaquetário (inibidor P2Y12 irreversível)', 'es': 'Antiplaquetario (inhibidor P2Y12 irreversible)'},
    category: {'pt': 'Hematologia / Antiplaquetário', 'es': 'Hematología / Antiplaquetario'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'SCA/ICP: ataque 300–600 mg VO dose única → manutenção 75 mg/dia | AVCi/AIT: 75 mg/dia (ou ataque 300 mg) | DAP: 75 mg/dia | Dupla antiagregação (DAPT) pós-stent: 75 mg + AAS × 12 meses',
      'es': 'SCA/ICP: carga 300–600 mg VO dosis única → mantenimiento 75 mg/día | AVCi/AIT: 75 mg/día (o carga 300 mg) | DAP: 75 mg/día | Doble antiagregación (DAPT) post-stent: 75 mg + AAS × 12 meses',
    },
    frequency: {'pt': '1×/dia', 'es': '1×/día'},
    renalAlert: {
      'pt': 'Sem ajuste necessário. Maior risco de sangramento em IRC (disfunção plaquetária urémica).',
      'es': 'Sin ajuste necesario. Mayor riesgo de sangrado en IRC (disfunción plaquetaria urémica).',
    },
    elderlyAlert: {
      'pt': 'Risco aumentado de sangramento GI em idosos (especialmente sem IBP). Associar proteção gástrica. Monitorar hematócrito.',
      'es': 'Riesgo aumentado de sangrado GI en ancianos (especialmente sin IBP). Asociar protección gástrica. Monitorear hematocrito.',
    },
    mechanism: {
      'pt': 'Pró-fármaco: ativado pelo CYP2C19 → metabólito tiolactona liga-se irreversivelmente ao receptor P2Y12 na plaqueta → bloqueia ativação/agregação plaquetária mediada por ADP. Inibição plaquetária durante toda a vida da plaqueta (7–10 dias). Polimorfismo CYP2C19 → variabilidade na resposta (20–30% pobres metabolizadores).',
      'es': 'Profármaco: activado por CYP2C19 → metabolito tiolactona se une irreversiblemente al receptor P2Y12 en la plaqueta → bloquea activación/agregación plaquetaria mediada por ADP. Inhibición plaquetaria durante toda la vida de la plaqueta (7–10 días). Polimorfismo CYP2C19 → variabilidad en respuesta (20–30% pobres metabolizadores).',
    },
    warning: {
      'pt': 'Interação com IBPs: esomeprazol/omeprazol inibem CYP2C19 → ↓ ativação do clopidogrel. Preferir pantoprazol ou rabeprazol. Suspender 5–7 dias antes de cirurgia eletiva com risco de sangramento. Resistência farmacológica em CYP2C19 perda-de-função.',
      'es': 'Interacción con IBPs: esomeprazol/omeprazol inhiben CYP2C19 → ↓ activación del clopidogrel. Preferir pantoprazol o rabeprazol. Suspender 5–7 días antes de cirugía electiva con riesgo de sangrado. Resistencia farmacológica en CYP2C19 pérdida de función.',
    },
    adverse: {
      'pt': ['Sangramento (GI, epistaxe, equimoses)', 'Púrpura trombocitopênica trombótica (TTP — raro, grave)', 'Exantema', 'Diarreia', 'Dor abdominal', 'Neutropenia (raro)'],
      'es': ['Sangrado (GI, epistaxis, equimosis)', 'Púrpura trombocitopénica trombótica (PTT — raro, grave)', 'Exantema', 'Diarrea', 'Dolor abdominal', 'Neutropenia (raro)'],
    },
  ),

  DrugModel(
    id: 'fitomenadiona',
    group: 'Anticoagulantes y Hemostasia',
    name: 'Fitomenadiona (Vitamina K1)',
    className: {'pt': 'Vitamina K / Antídoto anticoagulante AVK', 'es': 'Vitamina K / Antídoto anticoagulante AVK'},
    category: {'pt': 'Hematologia / Antídoto / Vitamina', 'es': 'Hematología / Antídoto / Vitamina'},
    route: 'VO / SC / IV lento',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Reversão varfarina (INR 4–10, sem sangramento): 2,5–5 mg VO | Sangramento menor: 2,5–5 mg SC/IV lento | Sangramento grave/AVC: 10 mg IV lento + CCP ou PFC | Profilaxia neonatal: 0,5–1 mg IM dose única ao nascer | Deficiência vitamina K: 1–10 mg/dia',
      'es': 'Reversión warfarina (INR 4–10, sin sangrado): 2,5–5 mg VO | Sangrado menor: 2,5–5 mg SC/IV lento | Sangrado grave/ACV: 10 mg IV lento + CCP o PFC | Profilaxis neonatal: 0,5–1 mg IM dosis única al nacer | Deficiencia vitamina K: 1–10 mg/día',
    },
    frequency: {'pt': 'conforme INR e clínica', 'es': 'según INR y clínica'},
    renalAlert: {
      'pt': 'Sem ajuste necessário. Metabolismo hepático.',
      'es': 'Sin ajuste necesario. Metabolismo hepático.',
    },
    elderlyAlert: {
      'pt': 'Dose excessiva pode causar resistência prolongada à reintrodução de varfarina (dias a semanas). Usar dose mínima necessária.',
      'es': 'Dosis excesiva puede causar resistencia prolongada a la reintroducción de warfarina (días a semanas). Usar dosis mínima necesaria.',
    },
    mechanism: {
      'pt': 'Cofator essencial para ativação dos fatores de coagulação II, VII, IX, X e proteínas C, S, Z (carboxilação por vitamina K epóxido redutase). Reverte o bloqueio da varfarina repondo o substrato. IV: início de ação ~2 h; VO: 6–12 h; máximo efeito 24 h.',
      'es': 'Cofactor esencial para activación de factores de coagulación II, VII, IX, X y proteínas C, S, Z (carboxilación por vitamina K epóxido reductasa). Revierte el bloqueo de warfarina reponiendo el sustrato. IV: inicio de acción ~2 h; VO: 6–12 h; efecto máximo 24 h.',
    },
    warning: {
      'pt': 'Anafilaxia grave com IV rápido — infundir lentamente (máx 1 mg/min), ter adrenalina à mão. Doses altas (> 5 mg) tornam o paciente resistente à reintrodução de varfarina por vários dias. Não reverte anticoagulantes diretos (rivaroxabana, dabigatrana).',
      'es': 'Anafilaxia grave con IV rápido — infundir lentamente (máx 1 mg/min), tener adrenalina disponible. Dosis altas (> 5 mg) vuelven al paciente resistente a la reintroducción de warfarina por varios días. No revierte anticoagulantes directos (rivaroxabán, dabigatrán).',
    },
    adverse: {
      'pt': ['Anafilaxia (IV rápido)', 'Resistência a varfarina (dose alta)', 'Dor local (IM/SC)', 'Rubor', 'Hipotensão (IV rápido)', 'Sabor metálico (IV)'],
      'es': ['Anafilaxia (IV rápido)', 'Resistencia a warfarina (dosis alta)', 'Dolor local (IM/SC)', 'Rubor', 'Hipotensión (IV rápido)', 'Sabor metálico (IV)'],
    },
  ),

  DrugModel(
    id: 'acido_ursodesoxicolico',
    group: 'Gastroenterología',
    name: 'Ácido Ursodesoxicólico (UDCA)',
    className: {'pt': 'Ácido biliar hidrofílico / Hepatoprotetor', 'es': 'Ácido biliar hidrofílico / Hepatoprotector'},
    category: {'pt': 'Digestivo / Hepatologia', 'es': 'Digestivo / Hepatología'},
    route: 'VO',
    doseType: 'mg_kg',
    mgKg: 13.0,
    fixedDose: {
      'pt': 'Cálculo biliar (dissolução): 8–10 mg/kg/dia VO ÷ 2–3 doses × 6–24 meses | CBP (cirrose biliar primária): 13–15 mg/kg/dia ÷ 2–3 doses | Colestase da gravidez: 10–15 mg/kg/dia | CEP: 13–15 mg/kg/dia (benefício limitado)',
      'es': 'Cálculo biliar (disolución): 8–10 mg/kg/día VO ÷ 2–3 dosis × 6–24 meses | CBP (cirrosis biliar primaria): 13–15 mg/kg/día ÷ 2–3 dosis | Colestasis del embarazo: 10–15 mg/kg/día | CEP: 13–15 mg/kg/día (beneficio limitado)',
    },
    frequency: {'pt': '2–3×/dia (com refeições)', 'es': '2–3×/día (con comidas)'},
    renalAlert: {
      'pt': 'Sem ajuste necessário. Excreção biliar predominante.',
      'es': 'Sin ajuste necesario. Excreción biliar predominante.',
    },
    elderlyAlert: {
      'pt': 'Geralmente bem tolerado. Monitorar função hepática.',
      'es': 'Generalmente bien tolerado. Monitorear función hepática.',
    },
    mechanism: {
      'pt': 'Substitui ácidos biliares tóxicos hidrofóbicos endógenos por UDCA hidrofílico → ↓ toxicidade hepatocelular e colangiocitária. Também efeito imunomodulador, antiapoptótico e estimulante da secreção biliar. Única terapia aprovada para CBP (cirrose biliar primária).',
      'es': 'Sustituye ácidos biliares tóxicos hidrofóbicos endógenos por UDCA hidrofílico → ↓ toxicidad hepatocelular y colangiocitaria. También efecto inmunomodulador, antiapoptótico y estimulante de la secreción biliar. Única terapia aprobada para CBP (cirrosis biliar primaria).',
    },
    warning: {
      'pt': 'Cálculos biliares calcificados não respondem. Suspender se diarreia intensa. Em CEP: doses altas (28–30 mg/kg/dia) associadas a MAIOR mortalidade em estudos. Não usar em obstrução biliar completa.',
      'es': 'Cálculos biliares calcificados no responden. Suspender si diarrea intensa. En CEP: dosis altas (28–30 mg/kg/día) asociadas a MAYOR mortalidad en estudios. No usar en obstrucción biliar completa.',
    },
    adverse: {
      'pt': ['Diarreia (dose-dependente)', 'Náusea', 'Dor abdominal leve', 'Alopecia (raro)', 'Prurido paradoxal inicial'],
      'es': ['Diarrea (dosis-dependiente)', 'Náusea', 'Dolor abdominal leve', 'Alopecia (raro)', 'Prurito paradójico inicial'],
    },
  ),

  DrugModel(
    id: 'insulina_nph',
    group: 'Endocrinología y Metabolismo',
    name: 'Insulina NPH',
    className: {'pt': 'Insulina de ação intermediária', 'es': 'Insulina de acción intermedia'},
    category: {'pt': 'Endocrino / Antidiabético', 'es': 'Endocrino / Antidiabético'},
    route: 'SC',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'DM1 (basal-bólus): 0,2–0,5 UI/kg/dia SC 1–2×/dia (manhã e/ou noturna) | DM2 inicio insulinoterapia: 10 UI SC ao deitar (ou 0,1–0,2 UI/kg) | Titular: ↑ 2 UI a cada 3 dias conforme glicemia jejum | Pediátrico: 0,5–1 UI/kg/dia total (basal + bólus)',
      'es': 'DM1 (basal-bolo): 0,2–0,5 UI/kg/día SC 1–2×/día (mañana y/o nocturna) | DM2 inicio insulinoterapia: 10 UI SC al acostarse (o 0,1–0,2 UI/kg) | Titular: ↑ 2 UI cada 3 días según glucemia ayuno | Pediátrico: 0,5–1 UI/kg/día total (basal + bolo)',
    },
    frequency: {'pt': '1–2×/dia', 'es': '1–2×/día'},
    renalAlert: {
      'pt': 'IRC reduz clearance da insulina → maior risco de hipoglicemia. Monitorar glicemia mais frequentemente e reduzir dose 25–50% conforme TFG.',
      'es': 'IRC reduce clearance de insulina → mayor riesgo de hipoglucemia. Monitorear glucemia más frecuentemente y reducir dosis 25–50% según TFG.',
    },
    elderlyAlert: {
      'pt': 'Hipoglicemia grave pode ser silenciosa (sem sintomas adrenérgicos típicos) → risco de queda, AVC, IAM. Alvo glicêmico mais liberal (HbA1c < 8%). Iniciar com dose baixa e titular devagar.',
      'es': 'Hipoglucemia grave puede ser silenciosa (sin síntomas adrenérgicos típicos) → riesgo de caída, ACV, IAM. Objetivo glucémico más liberal (HbA1c < 8%). Iniciar con dosis baja y titular despacio.',
    },
    mechanism: {
      'pt': 'Insulina humana regular neutralizada com protamina → cristais de zinco → absorção retardada. Pico de ação 4–12 h; duração 16–24 h. Liga-se receptor insulínico → ↑ captação glicose (músculo/tecido adiposo), ↑ síntese glicogênio, ↓ gliconeogênese hepática, ↑ lipogênese.',
      'es': 'Insulina humana regular neutralizada con protamina → cristales de zinc → absorción retardada. Pico de acción 4–12 h; duración 16–24 h. Se une a receptor insulínico → ↑ captación glucosa (músculo/tejido adiposo), ↑ síntesis glucógeno, ↓ gluconeogénesis hepática, ↑ lipogénesis.',
    },
    warning: {
      'pt': 'Hipoglicemia: principal risco. Homogeneizar por rolagem suave (NUNCA agitar). Pico às 4–12 h pode causar hipoglicemia noturna. Lipodistrofia por injeção repetida no mesmo local. Não misturar com glargina ou detemir.',
      'es': 'Hipoglucemia: principal riesgo. Homogeneizar por rodadura suave (NUNCA agitar). Pico a las 4–12 h puede causar hipoglucemia nocturna. Lipodistrofia por inyección repetida en el mismo lugar. No mezclar con glargina o detemir.',
    },
    adverse: {
      'pt': ['Hipoglicemia', 'Lipodistrofia', 'Ganho de peso', 'Edema (início tratamento)', 'Reação no local de injeção', 'Alergia à protamina (raro)'],
      'es': ['Hipoglucemia', 'Lipodistrofia', 'Aumento de peso', 'Edema (inicio tratamiento)', 'Reacción en sitio de inyección', 'Alergia a protamina (raro)'],
    },
  ),

  DrugModel(
    id: 'insulina_glargina',
    group: 'Endocrinología y Metabolismo',
    name: 'Insulina Glargina (Lantus/Toujeo)',
    className: {'pt': 'Insulina de ação prolongada (análogo)', 'es': 'Insulina de acción prolongada (análogo)'},
    category: {'pt': 'Endocrino / Antidiabético', 'es': 'Endocrino / Antidiabético'},
    route: 'SC',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'DM1 (basal): 0,2–0,4 UI/kg SC 1×/dia | DM2 início: 10 UI SC ao deitar ou 0,1–0,2 UI/kg | Titular: ↑ 2 UI a cada 3 dias alvo glicemia jejum 80–130 mg/dL | Toujeo (300 UI/mL): dose ~10–20% maior que Lantus',
      'es': 'DM1 (basal): 0,2–0,4 UI/kg SC 1×/día | DM2 inicio: 10 UI SC al acostarse o 0,1–0,2 UI/kg | Titular: ↑ 2 UI cada 3 días objetivo glucemia ayuno 80–130 mg/dL | Toujeo (300 UI/mL): dosis ~10–20% mayor que Lantus',
    },
    frequency: {'pt': '1×/dia (mesmo horário)', 'es': '1×/día (misma hora)'},
    renalAlert: {
      'pt': 'Reduzir dose em IRC — clearance reduzido. Monitorar glicemia 3–4×/dia.',
      'es': 'Reducir dosis en IRC — clearance reducido. Monitorear glucemia 3–4×/día.',
    },
    elderlyAlert: {
      'pt': 'Perfil peakless → menor risco de hipoglicemia noturna que NPH. Preferida em idosos. Iniciar com 6–8 UI. Alvo HbA1c < 8% em idosos frágeis.',
      'es': 'Perfil peakless → menor riesgo de hipoglucemia nocturna que NPH. Preferida en ancianos. Iniciar con 6–8 UI. Objetivo HbA1c < 8% en ancianos frágiles.',
    },
    mechanism: {
      'pt': 'Análogo de insulina modificado (Arg-Arg no C-terminal + substituição Asn→Gly) → precipita em pH fisiológico SC → liberação lenta e contínua. Sem pico definido ("peakless"). Duração 20–24 h (Lantus) ou 24–36 h (Toujeo). NÃO misturar com outras insulinas.',
      'es': 'Análogo de insulina modificado (Arg-Arg en C-terminal + sustitución Asn→Gly) → precipita en pH fisiológico SC → liberación lenta y continua. Sin pico definido ("peakless"). Duración 20–24 h (Lantus) o 24–36 h (Toujeo). NO mezclar con otras insulinas.',
    },
    warning: {
      'pt': 'NUNCA misturar com outras insulinas (pH ácido → precipitação). Não agitar. Solução deve ser clara e incolor. Trocar local de injeção. Não usar IV.',
      'es': 'NUNCA mezclar con otras insulinas (pH ácido → precipitación). No agitar. Solución debe ser clara e incolora. Cambiar sitio de inyección. No usar IV.',
    },
    adverse: {
      'pt': ['Hipoglicemia (menor que NPH)', 'Lipodistrofia', 'Ganho de peso', 'Edema', 'Dor/eritema local', 'Câncer de mama? (controverso — dados epidemiológicos contraditórios)'],
      'es': ['Hipoglucemia (menor que NPH)', 'Lipodistrofia', 'Aumento de peso', 'Edema', 'Dolor/eritema local', 'Cáncer de mama? (controvertido — datos epidemiológicos contradictorios)'],
    },
  ),

  DrugModel(
    id: 'glucagon',
    group: 'Endocrinología y Metabolismo',
    name: 'Glucagon / Glucagón',
    className: {'pt': 'Hormônio pancreático / Antídoto hipoglicemia', 'es': 'Hormona pancreática / Antídoto hipoglucemia'},
    category: {'pt': 'Endocrino / Emergência', 'es': 'Endocrino / Emergencia'},
    route: 'SC / IM / IV / Intranasal',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Hipoglicemia grave: 1 mg SC/IM/IV (adulto e > 25 kg) | < 25 kg ou < 6–8 anos: 0,5 mg | Intranasal (Baqsimi): 3 mg em uma narina | Diagnóstico GI (inibição motilidade): 0,25–2 mg IV/IM | Superdose β-bloqueador: 50–150 µg/kg IV bolus → 2–10 mg/h infusão',
      'es': 'Hipoglucemia grave: 1 mg SC/IM/IV (adulto y > 25 kg) | < 25 kg o < 6–8 años: 0,5 mg | Intranasal (Baqsimi): 3 mg en una narina | Diagnóstico GI (inhibición motilidad): 0,25–2 mg IV/IM | Sobredosis β-bloqueador: 50–150 µg/kg IV bolo → 2–10 mg/h infusión',
    },
    frequency: {'pt': 'dose única (repetir 1×) na emergência', 'es': 'dosis única (repetir 1×) en emergencia'},
    renalAlert: {
      'pt': 'Sem ajuste necessário. Metabolismo hepático e renal.',
      'es': 'Sin ajuste necesario. Metabolismo hepático y renal.',
    },
    elderlyAlert: {
      'pt': 'Eficácia reduzida em hipoglicemia prolongada ou desnutrição (depósitos de glicogênio depletados). Após recuperação, oferecer carboidratos imediatamente.',
      'es': 'Eficacia reducida en hipoglucemia prolongada o desnutrición (depósitos de glucógeno depletados). Tras recuperación, ofrecer carbohidratos inmediatamente.',
    },
    mechanism: {
      'pt': 'Liga-se receptor glucagônico → ↑ AMPc → ativa glicogenólise e gliconeogênese hepática → ↑ glicemia. Também inotrópico/cronotrópico positivo (útil em superdose de β-bloqueador). Início de ação SC/IM: 8–10 min; duração 12–27 min.',
      'es': 'Se une a receptor glucagónico → ↑ AMPc → activa glucogenólisis y gluconeogénesis hepática → ↑ glucemia. También inotrópico/cronotrópico positivo (útil en sobredosis de β-bloqueador). Inicio de acción SC/IM: 8–10 min; duración 12–27 min.',
    },
    warning: {
      'pt': 'Ineficaz em hipoglicemia por álcool, jejum prolongado ou hepatopatia grave (sem glicogênio hepático). Após dose, oferecer glicose oral assim que o paciente recuperar a consciência. Náusea/vômito frequentes — cuidado com broncoaspiração.',
      'es': 'Ineficaz en hipoglucemia por alcohol, ayuno prolongado o hepatopatía grave (sin glucógeno hepático). Después de la dosis, ofrecer glucosa oral cuando el paciente recupere la consciencia. Náusea/vómito frecuentes — cuidado con broncoaspiración.',
    },
    adverse: {
      'pt': ['Náusea/vômito (comum)', 'Taquicardia', 'Hipertensão transitória', 'Hipocalemia (infusão alta dose)', 'Hiperglicemia rebote', 'Anafilaxia (raro)'],
      'es': ['Náusea/vómito (común)', 'Taquicardia', 'Hipertensión transitoria', 'Hipopotasemia (infusión dosis alta)', 'Hiperglucemia rebote', 'Anafilaxia (raro)'],
    },
  ),

  DrugModel(
    id: 'metimazol',
    group: 'Endocrinología y Metabolismo',
    name: 'Metimazol (Tiamazol)',
    className: {'pt': 'Antitireoidiano (tionamida)', 'es': 'Antitiroideo (tionamida)'},
    category: {'pt': 'Endocrino / Tireóide', 'es': 'Endocrino / Tiroides'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Hipertireoidismo leve: 5–10 mg/dia | Moderado: 20–40 mg/dia ÷ 1–3 doses | Grave/storm: 60–80 mg/dia ÷ 3–4 doses | Preparo cirurgia/RAI: 20–30 mg/dia × 6–8 semanas | Manutenção: 5–10 mg/dia | Pediátrico: 0,5–1 mg/kg/dia ÷ 2–3 doses',
      'es': 'Hipertiroidismo leve: 5–10 mg/día | Moderado: 20–40 mg/día ÷ 1–3 dosis | Grave/tormenta: 60–80 mg/día ÷ 3–4 dosis | Preparación cirugía/RAI: 20–30 mg/día × 6–8 semanas | Mantenimiento: 5–10 mg/día | Pediátrico: 0,5–1 mg/kg/día ÷ 2–3 dosis',
    },
    frequency: {'pt': '1–3×/dia', 'es': '1–3×/día'},
    renalAlert: {
      'pt': 'Sem ajuste necessário. Excreção renal de metabólitos.',
      'es': 'Sin ajuste necesario. Excreción renal de metabolitos.',
    },
    elderlyAlert: {
      'pt': 'Monitorar hemograma (agranulocitose — informar paciente para procurar emergência se febre/faringite). Hepatotoxicidade mais frequente em idosos.',
      'es': 'Monitorear hemograma (agranulocitosis — informar al paciente para acudir a urgencias si fiebre/faringitis). Hepatotoxicidad más frecuente en ancianos.',
    },
    mechanism: {
      'pt': 'Inibe a peroxidase tireoidiana → bloqueia oxidação/organificação do iodeto e acoplamento das iodotirosinas → ↓ síntese de T3 e T4. NÃO bloqueia liberação de hormônios já armazenados. Preferido ao propiltiuracil (exceto 1º trimestre). Início de ação clínico: 1–3 semanas.',
      'es': 'Inhibe la peroxidasa tiroidea → bloquea oxidación/organificación del yoduro y acoplamiento de yodotirosinas → ↓ síntesis de T3 y T4. NO bloquea la liberación de hormonas ya almacenadas. Preferido al propiltiouracilo (excepto 1º trimestre). Inicio de acción clínico: 1–3 semanas.',
    },
    warning: {
      'pt': 'AGRANULOCITOSE (0,2–0,5%) — emergência. Orientar paciente: febre ou faringite → suspender e ir à emergência (hemograma). Hepatotoxicidade. Evitar no 1º trimestre (teratogênico — aplasia cutis) → usar propiltiuracil no 1T.',
      'es': 'AGRANULOCITOSIS (0,2–0,5%) — emergencia. Orientar al paciente: fiebre o faringitis → suspender y acudir a urgencias (hemograma). Hepatotoxicidad. Evitar en 1º trimestre (teratogénico — aplasia cutis) → usar propiltiouracilo en 1T.',
    },
    adverse: {
      'pt': ['Agranulocitose (0,2–0,5%)', 'Exantema', 'Prurido', 'Artralgia', 'Hepatotoxicidade (raro)', 'Hipotireoidismo iatrogênico (superdose)', 'Vasculite ANCA (raro)'],
      'es': ['Agranulocitosis (0,2–0,5%)', 'Exantema', 'Prurito', 'Artralgia', 'Hepatotoxicidad (raro)', 'Hipotiroidismo iatrogénico (sobredosis)', 'Vasculitis ANCA (raro)'],
    },
  ),

  DrugModel(
    id: 'alopurinol',
    group: 'Endocrinología y Metabolismo',
    name: 'Alopurinol',
    className: {'pt': 'Inibidor da xantina oxidase / Hipouricemiante', 'es': 'Inhibidor de xantina oxidasa / Hipouricemiante'},
    category: {'pt': 'Reumatologia / Gota', 'es': 'Reumatología / Gota'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Gota (profilaxia): iniciar 100 mg/dia → titular 100 mg/mês alvo ácido úrico < 6 mg/dL (até 800 mg/dia) | Uso empírico habitual: 300 mg/dia | Nefrolitíase úrica: 100–300 mg/dia | Síndrome de lise tumoral: 300–600 mg/dia | Pediátrico: 10 mg/kg/dia (máx 400 mg)',
      'es': 'Gota (profilaxis): iniciar 100 mg/día → titular 100 mg/mes objetivo ácido úrico < 6 mg/dL (hasta 800 mg/día) | Uso empírico habitual: 300 mg/día | Nefrolitiasis úrica: 100–300 mg/día | Síndrome de lisis tumoral: 300–600 mg/día | Pediátrico: 10 mg/kg/día (máx 400 mg)',
    },
    frequency: {'pt': '1–3×/dia (após refeições)', 'es': '1–3×/día (después de comidas)'},
    renalAlert: {
      'pt': 'TFG 30–59: 100 mg/dia | TFG 10–29: 100 mg a cada 48 h | TFG < 10: 100 mg a cada 72 h. Redução obrigatória — metabólito ativo oxipurinol acumula em IRC → síndrome de hipersensibilidade.',
      'es': 'TFG 30–59: 100 mg/día | TFG 10–29: 100 mg cada 48 h | TFG < 10: 100 mg cada 72 h. Reducción obligatoria — metabolito activo oxipurinol se acumula en IRC → síndrome de hipersensibilidad.',
    },
    elderlyAlert: {
      'pt': 'Ajuste rigoroso por TFG. Síndrome de hipersensibilidade ao alopurinol mais grave em idosos com IRC. Início durante crise aguda pode precipitar nova crise — aguardar 2–4 semanas após resolução.',
      'es': 'Ajuste riguroso por TFG. Síndrome de hipersensibilidad al alopurinol más grave en ancianos con IRC. Inicio durante crisis aguda puede precipitar nueva crisis — esperar 2–4 semanas tras resolución.',
    },
    mechanism: {
      'pt': 'Análogo de hipoxantina → inibe xantina oxidase → bloqueia conversão hipoxantina→xantina→ácido úrico → ↓ uricemia e uricossúria. Metabólito ativo oxipurinol (meia-vida 18–30 h). Reduz produção de urato (diferente de uricosúricos que aumentam excreção).',
      'es': 'Análogo de hipoxantina → inhibe xantina oxidasa → bloquea conversión hipoxantina→xantina→ácido úrico → ↓ uricemia y uricosuria. Metabolito activo oxipurinol (vida media 18–30 h). Reduce producción de urato (diferente de uricosúricos que aumentan excreción).',
    },
    warning: {
      'pt': 'Síndrome de hipersensibilidade ao alopurinol (AHS): exantema grave → Stevens-Johnson/necrose epidérmica (mortalidade alta) — especialmente em HLA-B*5801 (asiáticos/afrodescendentes) e IRC. Não iniciar durante crise aguda. Interação: ↑ toxicidade azatioprina/mercaptopurina (BLOQUEIO ENZIMÁTICO — contraindicado ou reduzir 75%).',
      'es': 'Síndrome de hipersensibilidad al alopurinol (AHS): exantema grave → Stevens-Johnson/necrólisis epidérmica (mortalidad alta) — especialmente en HLA-B*5801 (asiáticos/afrodescendientes) e IRC. No iniciar durante crisis aguda. Interacción: ↑ toxicidad azatioprina/mercaptopurina (BLOQUEO ENZIMÁTICO — contraindicado o reducir 75%).',
    },
    adverse: {
      'pt': ['Exantema (2–5%)', 'Síndrome de hipersensibilidade (grave — raro)', 'Stevens-Johnson (raro)', 'Náusea', 'Diarreia', 'Hepatotoxicidade', 'Precipitação de crise de gota (início)'],
      'es': ['Exantema (2–5%)', 'Síndrome de hipersensibilidad (grave — raro)', 'Stevens-Johnson (raro)', 'Náusea', 'Diarrea', 'Hepatotoxicidad', 'Precipitación de crisis de gota (inicio)'],
    },
  ),

  DrugModel(
    id: 'colchicina',
    group: 'Endocrinología y Metabolismo',
    name: 'Colchicina',
    className: {'pt': 'Alcaloide / Anti-inflamatório (inibidor da polimerização da tubulina)', 'es': 'Alcaloide / Antiinflamatorio (inhibidor de polimerización de tubulina)'},
    category: {'pt': 'Reumatologia / Gota / Pericardite', 'es': 'Reumatología / Gota / Pericarditis'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Crise aguda de gota: 1,2 mg VO → 0,6 mg 1 h depois; continuar 0,6 mg 2×/dia até resolução | Profilaxia gota: 0,5–0,6 mg 1–2×/dia | Pericardite aguda: 0,5 mg 2×/dia × 3 meses (< 70 kg: 0,5 mg/dia) | Febre Mediterrânea Familiar: 1–2 mg/dia | FMF pediátrico: 0,5–1 mg/dia',
      'es': 'Crisis aguda de gota: 1,2 mg VO → 0,6 mg 1 h después; continuar 0,6 mg 2×/día hasta resolución | Profilaxis gota: 0,5–0,6 mg 1–2×/día | Pericarditis aguda: 0,5 mg 2×/día × 3 meses (< 70 kg: 0,5 mg/día) | Fiebre Mediterránea Familiar: 1–2 mg/día | FMF pediátrico: 0,5–1 mg/día',
    },
    frequency: {'pt': '1–2×/dia', 'es': '1–2×/día'},
    renalAlert: {
      'pt': 'TFG 30–60: usar com cautela, reduzir dose | TFG < 30: evitar uso prolongado — miopatia e neuropatia por acúmulo. Hemodiálise: não remover → toxicidade.',
      'es': 'TFG 30–60: usar con cautela, reducir dosis | TFG < 30: evitar uso prolongado — miopatía y neuropatía por acumulación. Hemodiálisis: no se elimina → toxicidad.',
    },
    elderlyAlert: {
      'pt': 'Risco de miopatia e neuropatia em idosos com IRC. Interação com claritromicina e ciclosporina pode ser FATAL (↑ colchicina → falência múltipla de órgãos). Diarreia grave indica toxicidade.',
      'es': 'Riesgo de miopatía y neuropatía en ancianos con IRC. Interacción con claritromicina y ciclosporina puede ser FATAL (↑ colchicina → fallo multiorgánico). Diarrea grave indica toxicidad.',
    },
    mechanism: {
      'pt': 'Liga-se à tubulina → inibe polimerização de microtúbulos → bloqueia migração de neutrófilos e macrófagos ao foco inflamatório → ↓ fagocitose de cristais de urato e liberação de IL-1β. Também inibe inflamassoma NLRP3 (mecanismo da pericardite). Faixa terapêutica estreita.',
      'es': 'Se une a tubulina → inhibe polimerización de microtúbulos → bloquea migración de neutrófilos y macrófagos al foco inflamatorio → ↓ fagocitosis de cristales de urato y liberación de IL-1β. También inhibe inflamasoma NLRP3 (mecanismo de pericarditis). Margen terapéutico estrecho.',
    },
    warning: {
      'pt': 'Interação letal: claritromicina + IRC → ↑↑ colchicina → miopatia, insuficiência renal, CID, morte. Contraindicado: claritromicina/cetoconazol/ciclosporina em IRC. Toxicidade GI = sinal de alerta (reduzir dose). NUNCA administrar IV (descontinuada — mortes relatadas).',
      'es': 'Interacción letal: claritromicina + IRC → ↑↑ colchicina → miopatía, insuficiencia renal, CID, muerte. Contraindicado: claritromicina/ketoconazol/ciclosporina en IRC. Toxicidad GI = señal de alerta (reducir dosis). NUNCA administrar IV (descontinuada — muertes reportadas).',
    },
    adverse: {
      'pt': ['Diarreia (mais comum — dose-dependente)', 'Náusea/vômito', 'Dor abdominal', 'Miopatia (uso prolongado/IRC)', 'Neuropatia periférica', 'Mielossupressão (toxicidade grave)', 'Alopecia (raro)'],
      'es': ['Diarrea (más común — dosis-dependiente)', 'Náusea/vómito', 'Dolor abdominal', 'Miopatía (uso prolongado/IRC)', 'Neuropatía periférica', 'Mielosupresión (toxicidad grave)', 'Alopecia (raro)'],
    },
  ),

  DrugModel(
    id: 'hidroxicloroquina',
    group: 'Infectología (Antifúngicos / Antivirales / TBC)',
    name: 'Hidroxicloroquina',
    className: {'pt': 'Antimalárico / DMARD (doença do tecido conjuntivo)', 'es': 'Antipalúdico / FAME (enfermedad del tejido conjuntivo)'},
    category: {'pt': 'Reumatologia / Antimalárico', 'es': 'Reumatología / Antipalúdico'},
    route: 'VO',
    doseType: 'mg_kg',
    mgKg: 5.0,
    fixedDose: {
      'pt': 'LES/AR: 200–400 mg/dia (≤ 5 mg/kg/dia peso real) | Malária tratamento: 800 mg → 400 mg em 6–8–24 h | Malária profilaxia: 400 mg semanal (iniciar 2 semanas antes) | Síndrome de Sjögren: 200–400 mg/dia',
      'es': 'LES/AR: 200–400 mg/día (≤ 5 mg/kg/día peso real) | Malaria tratamiento: 800 mg → 400 mg en 6–8–24 h | Malaria profilaxis: 400 mg semanal (iniciar 2 semanas antes) | Síndrome de Sjögren: 200–400 mg/día',
    },
    frequency: {'pt': '1–2×/dia (com alimentos)', 'es': '1–2×/día (con alimentos)'},
    renalAlert: {
      'pt': 'TFG < 30: reduzir dose 25–50%. Acúmulo em IRC → maior risco de toxicidade retiniana.',
      'es': 'TFG < 30: reducir dosis 25–50%. Acumulación en IRC → mayor riesgo de toxicidad retiniana.',
    },
    elderlyAlert: {
      'pt': 'Monitorar função retiniana anualmente (exame oftalmológico completo). Miopatia em uso prolongado. Interação com digoxina (↑ nível).',
      'es': 'Monitorear función retiniana anualmente (examen oftalmológico completo). Miopatía en uso prolongado. Interacción con digoxina (↑ nivel).',
    },
    mechanism: {
      'pt': 'Acumula em lisossomos → ↑ pH → inibe processamento de autoantígenos e apresentação ao MHC II → ↓ ativação linfócitos T CD4+ e produção de autoanticorpos. Inibe inflamassoma e TLR. Também interfere na síntese de citocinas pró-inflamatórias. Efeito pleno em 3–6 meses.',
      'es': 'Se acumula en lisosomas → ↑ pH → inhibe procesamiento de autoantígenos y presentación al MHC II → ↓ activación linfocitos T CD4+ y producción de autoanticuerpos. Inhibe inflamasoma y TLR. También interfiere en síntesis de citocinas proinflamatorias. Efecto pleno en 3–6 meses.',
    },
    warning: {
      'pt': 'Toxicidade retiniana: maculopatia irreversível (taurina) — risco ↑ com doses > 5 mg/kg/dia e uso > 5 anos. Exame oftalmológico anual obrigatório. Prolongamento QTc. G6PD deficiência → hemólise.',
      'es': 'Toxicidad retiniana: maculopatía irreversible (taurina) — riesgo ↑ con dosis > 5 mg/kg/día y uso > 5 años. Examen oftalmológico anual obligatorio. Prolongación QTc. Deficiencia de G6PD → hemólisis.',
    },
    adverse: {
      'pt': ['Toxicidade retiniana (uso prolongado — grave, irreversível)', 'Prolongamento QTc', 'Náusea/dor abdominal', 'Cefaleia', 'Miopatia (raro)', 'Pigmentação cutânea', 'Hemólise (G6PD)'],
      'es': ['Toxicidad retiniana (uso prolongado — grave, irreversible)', 'Prolongación QTc', 'Náusea/dolor abdominal', 'Cefalea', 'Miopatía (raro)', 'Pigmentación cutánea', 'Hemólisis (G6PD)'],
    },
  ),

  DrugModel(
    id: 'loratadina',
    group: 'Varios / Antídotos / Otros',
    name: 'Loratadina',
    className: {'pt': 'Anti-histamínico H1 de 2ª geração (não sedativo)', 'es': 'Antihistamínico H1 de 2ª generación (no sedativo)'},
    category: {'pt': 'Alergia / Anti-histamínico', 'es': 'Alergia / Antihistamínico'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Adulto: 10 mg VO 1×/dia | Pediátrico 2–5 anos: 5 mg/dia; > 6 anos: 10 mg/dia | Urticária crônica: 10 mg 1×/dia (até 20–40 mg para refratários)',
      'es': 'Adulto: 10 mg VO 1×/día | Pediátrico 2–5 años: 5 mg/día; > 6 años: 10 mg/día | Urticaria crónica: 10 mg 1×/día (hasta 20–40 mg para refractarios)',
    },
    frequency: {'pt': '1×/dia', 'es': '1×/día'},
    renalAlert: {
      'pt': 'TFG < 30: 10 mg a cada 48 h.',
      'es': 'TFG < 30: 10 mg cada 48 h.',
    },
    elderlyAlert: {
      'pt': 'Geralmente segura. Praticamente sem efeitos sedativos ou anticolinérgicos. Preferida em idosos vs difenidramina.',
      'es': 'Generalmente segura. Prácticamente sin efectos sedativos ni anticolinérgicos. Preferida en ancianos vs difenhidramina.',
    },
    mechanism: {
      'pt': 'Antagonista seletivo e periférico dos receptores H1 (menor penetração BHE → mínima sedação). Não tem efeito anticolinérgico significativo. Metabólito ativo desloratadina. Inibe liberação de histamina e leucotrienos dos mastócitos.',
      'es': 'Antagonista selectivo y periférico de los receptores H1 (menor penetración BHE → mínima sedación). Sin efecto anticolinérgico significativo. Metabolito activo desloratadina. Inhibe liberación de histamina y leucotrienos de mastocitos.',
    },
    warning: {
      'pt': 'Evitar com inibidores CYP3A4 potentes (↑ nível). Risco de prolongamento QTc em superdosagem. Pode causar sedação leve em alguns pacientes (não dirigir se apresentar).',
      'es': 'Evitar con inhibidores CYP3A4 potentes (↑ nivel). Riesgo de prolongación QTc en sobredosis. Puede causar sedación leve en algunos pacientes (no conducir si la presenta).',
    },
    adverse: {
      'pt': ['Cefaleia', 'Sonolência leve (raro)', 'Boca seca (mínima)', 'Fadiga', 'Náusea'],
      'es': ['Cefalea', 'Somnolencia leve (raro)', 'Boca seca (mínima)', 'Fatiga', 'Náusea'],
    },
  ),

  DrugModel(
    id: 'dexclorfeniramina',
    group: 'Varios / Antídotos / Otros',
    name: 'Dexclorfeniramina',
    className: {'pt': 'Anti-histamínico H1 de 1ª geração (sedativo)', 'es': 'Antihistamínico H1 de 1ª generación (sedativo)'},
    category: {'pt': 'Alergia / Anti-histamínico', 'es': 'Alergia / Antihistamínico'},
    route: 'VO / IV / IM / SC',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Adulto: 2 mg VO 4–6×/dia (máx 12 mg/dia) | Reação alérgica aguda/anafilaxia adjunto: 5 mg IV/IM | Prurido intenso: 2–6 mg VO noturno | Pediátrico 2–6 anos: 0,5 mg 4×/dia; 6–12 anos: 1 mg 4×/dia',
      'es': 'Adulto: 2 mg VO 4–6×/día (máx 12 mg/día) | Reacción alérgica aguda/anafilaxia adjunto: 5 mg IV/IM | Prurito intenso: 2–6 mg VO nocturno | Pediátrico 2–6 años: 0,5 mg 4×/día; 6–12 años: 1 mg 4×/día',
    },
    frequency: {'pt': '3–4×/dia (VO)', 'es': '3–4×/día (VO)'},
    renalAlert: {
      'pt': 'Reduzir dose em IRC. Excreção renal. Sedação prolongada.',
      'es': 'Reducir dosis en IRC. Excreción renal. Sedación prolongada.',
    },
    elderlyAlert: {
      'pt': 'Beers: EVITAR. Anticolinérgico potente → confusão, retenção urinária, constipação, taquicardia, glaucoma. Preferir loratadina ou desloratadina.',
      'es': 'Beers: EVITAR. Anticolinérgico potente → confusión, retención urinaria, estreñimiento, taquicardia, glaucoma. Preferir loratadina o desloratadina.',
    },
    mechanism: {
      'pt': 'Antagonista competitivo do receptor H1 central e periférico. Atravessa BHE → sedação. Efeito anticolinérgico, antiemético e antitússico adicionais. S-enantiômero ativo da clorfeniramina (maior potência).',
      'es': 'Antagonista competitivo del receptor H1 central y periférico. Atraviesa BHE → sedación. Efecto anticolinérgico, antiemético y antitusivo adicionales. S-enantiómero activo de clorfenamina (mayor potencia).',
    },
    warning: {
      'pt': 'Potencializa álcool, benzodiazepínicos e opioides (depressão SNC). Contraindicado em glaucoma de ângulo fechado, hipertrofia prostática, retenção urinária. Não usar em < 2 anos (risco de convulsões).',
      'es': 'Potencia alcohol, benzodiazepinas y opioides (depresión SNC). Contraindicado en glaucoma de ángulo cerrado, hipertrofia prostática, retención urinaria. No usar en < 2 años (riesgo de convulsiones).',
    },
    adverse: {
      'pt': ['Sedação (muito comum)', 'Boca seca', 'Visão turva', 'Retenção urinária', 'Constipação', 'Taquicardia', 'Confusão (idosos)'],
      'es': ['Sedación (muy común)', 'Boca seca', 'Visión borrosa', 'Retención urinaria', 'Estreñimiento', 'Taquicardia', 'Confusión (ancianos)'],
    },
  ),

  DrugModel(
    id: 'prometazina',
    group: 'Varios / Antídotos / Otros',
    name: 'Prometazina',
    className: {'pt': 'Fenotiazínico / Anti-histamínico H1 + antipsicótico fraco', 'es': 'Fenotiazínico / Antihistamínico H1 + antipsicótico débil'},
    category: {'pt': 'Alergia / Antiemético / Sedação', 'es': 'Alergia / Antiemético / Sedación'},
    route: 'VO / IM / IV lento / Retal',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Alergia/prurido: 25 mg VO/IM noturno | Náusea/êmese: 12,5–25 mg VO/IM/IV a cada 4–6 h | Sedação pré-operatória: 25–50 mg IM | Pediátrico > 2 anos: 0,1–0,5 mg/kg/dose | NUNCA usar < 2 anos (apneia fatal)',
      'es': 'Alergia/prurito: 25 mg VO/IM nocturno | Náusea/émesis: 12,5–25 mg VO/IM/IV cada 4–6 h | Sedación preoperatoria: 25–50 mg IM | Pediátrico > 2 años: 0,1–0,5 mg/kg/dosis | NUNCA usar < 2 años (apnea fatal)',
    },
    frequency: {'pt': '1–4×/dia', 'es': '1–4×/día'},
    renalAlert: {
      'pt': 'Reduzir dose em IRC. Sedação prolongada.',
      'es': 'Reducir dosis en IRC. Sedación prolongada.',
    },
    elderlyAlert: {
      'pt': 'Beers: EVITAR. Anticolinérgico intenso + D2 bloqueio → confusão, EPS, retenção urinária, quedas. Risco de SMN.',
      'es': 'Beers: EVITAR. Anticolinérgico intenso + bloqueo D2 → confusión, EPS, retención urinaria, caídas. Riesgo de SMN.',
    },
    mechanism: {
      'pt': 'Antagonista H1, D2, muscarínico M1, α1-adrenérgico. Fenotiazínico → ação antiemética central (bloqueio D2 na zona de gatilho). Forte sedativo por bloqueio H1/M1 central. Travessa BHE prontamente.',
      'es': 'Antagonista H1, D2, muscarínico M1, α1-adrenérgico. Fenotiazínico → acción antiemética central (bloqueo D2 en zona de gatillo). Fuerte sedante por bloqueo H1/M1 central. Atraviesa BHE fácilmente.',
    },
    warning: {
      'pt': 'FDA Black Box: PROIBIDO em < 2 anos (apneia e morte). Evitar IV rápido → hipotensão grave, arritmias, necrose tecidual por extravasamento. EPS em uso crônico. SMN. Não usar VO em < 2 anos.',
      'es': 'FDA Black Box: PROHIBIDO en < 2 años (apnea y muerte). Evitar IV rápido → hipotensión grave, arritmias, necrosis tisular por extravasación. EPS en uso crónico. SMN. No usar VO en < 2 años.',
    },
    adverse: {
      'pt': ['Sedação intensa', 'Boca seca', 'Hipotensão ortostática', 'EPS (distonias)', 'Retenção urinária', 'Confusão (idosos)', 'SMN (raro)', 'Apneia (< 2 anos)'],
      'es': ['Sedación intensa', 'Boca seca', 'Hipotensión ortostática', 'EPS (distonías)', 'Retención urinaria', 'Confusión (ancianos)', 'SMN (raro)', 'Apnea (< 2 años)'],
    },
  ),

  DrugModel(
    id: 'aciclovir',
    group: 'Infectología (Antifúngicos / Antivirales / TBC)',
    name: 'Aciclovir',
    className: {'pt': 'Antiviral (inibidor DNA polimerase herpética)', 'es': 'Antiviral (inhibidor DNA polimerasa herpética)'},
    category: {'pt': 'Antiviral / Herpes', 'es': 'Antiviral / Herpes'},
    route: 'VO / IV / Tópico',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'HSV genital 1º episódio: 400 mg VO 3×/dia × 7–10 dias | Herpes labial (oral): 200 mg VO 5×/dia × 5 dias | Herpes-zóster (imunocompetente): 800 mg VO 5×/dia × 7 dias | Encefalite herpética: 10 mg/kg IV a cada 8 h × 14–21 dias | Varicela grave: 10 mg/kg IV a cada 8 h | Pediátrico varicela: 80 mg/kg/dia ÷ 4 doses (máx 3,2 g/dia)',
      'es': 'HSV genital 1º episodio: 400 mg VO 3×/día × 7–10 días | Herpes labial (oral): 200 mg VO 5×/día × 5 días | Herpes-zóster (inmunocompetente): 800 mg VO 5×/día × 7 días | Encefalitis herpética: 10 mg/kg IV cada 8 h × 14–21 días | Varicela grave: 10 mg/kg IV cada 8 h | Pediátrico varicela: 80 mg/kg/día ÷ 4 dosis (máx 3,2 g/día)',
    },
    frequency: {'pt': '3–5×/dia (conforme indicação)', 'es': '3–5×/día (según indicación)'},
    renalAlert: {
      'pt': 'TFG 25–50: dose normal a cada 12 h | TFG 10–25: dose normal a cada 24 h | TFG < 10: metade da dose a cada 24 h. Cristalúria/nefrotoxicidade IV — hidratação adequada obrigatória.',
      'es': 'TFG 25–50: dosis normal cada 12 h | TFG 10–25: dosis normal cada 24 h | TFG < 10: mitad de la dosis cada 24 h. Cristaluria/nefrotoxicidad IV — hidratación adecuada obligatoria.',
    },
    elderlyAlert: {
      'pt': 'Ajuste rigoroso por TFG. Neurotoxicidade mais frequente (confusão, tremores, alucinações) em IRC. Hidratação adequada na administração IV.',
      'es': 'Ajuste riguroso por TFG. Neurotoxicidad más frecuente (confusión, temblores, alucinaciones) en IRC. Hidratación adecuada en administración IV.',
    },
    mechanism: {
      'pt': 'Análogo de nucleosídeo: ativado pela timidina quinase do vírus herpes → fosforilado 3× → aciclovir trifosfato → inibe competitivamente DNA polimerase viral → terminação de cadeia. Alta seletividade viral (enzima viral vs humana 3000× maior afinidade).',
      'es': 'Análogo de nucleósido: activado por la timidina quinasa del virus herpes → fosforilado 3× → aciclovir trifosfato → inhibe competitivamente DNA polimerasa viral → terminación de cadena. Alta selectividad viral (enzima viral vs humana 3000× mayor afinidad).',
    },
    warning: {
      'pt': 'Neurotoxicidade IV: confusão, tremores, convulsões — especialmente em IRC sem ajuste. Cristalúria/IRA: infundir lentamente (1 h) com hidratação adequada. Não cobre CMV (usar ganciclovir). Resistência em imunossuprimidos (timidina quinase mutante).',
      'es': 'Neurotoxicidad IV: confusión, temblores, convulsiones — especialmente en IRC sin ajuste. Cristaluria/IRA: infundir lentamente (1 h) con hidratación adecuada. No cubre CMV (usar ganciclovir). Resistencia en inmunodeprimidos (timidina quinasa mutante).',
    },
    adverse: {
      'pt': ['Náusea (VO)', 'Cefaleia', 'Nefrotoxicidade/cristalúria (IV — hidratação inadequada)', 'Neurotoxicidade (IRC)', 'Flebite (IV)', 'Exantema', 'Fotossensibilidade'],
      'es': ['Náusea (VO)', 'Cefalea', 'Nefrotoxicidad/cristaluria (IV — hidratación inadecuada)', 'Neurotoxicidad (IRC)', 'Flebitis (IV)', 'Exantema', 'Fotosensibilidad'],
    },
  ),

  DrugModel(
    id: 'oseltamivir',
    group: 'Respiratorio',
    name: 'Oseltamivir (Tamiflu)',
    className: {'pt': 'Inibidor da neuraminidase (antiviral influenza)', 'es': 'Inhibidor de neuraminidasa (antiviral influenza)'},
    category: {'pt': 'Antiviral / Influenza', 'es': 'Antiviral / Influenza'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Tratamento influenza: 75 mg VO 2×/dia × 5 dias (iniciar em ≤ 48 h) | Profilaxia: 75 mg VO 1×/dia × 10 dias | Imunossuprimidos graves: 75 mg 2×/dia × 10 dias | Pediátrico: peso-dependente (3 mg/kg/dose 2×/dia em < 1 ano — off-label)',
      'es': 'Tratamiento influenza: 75 mg VO 2×/día × 5 días (iniciar en ≤ 48 h) | Profilaxis: 75 mg VO 1×/día × 10 días | Inmunodeprimidos graves: 75 mg 2×/día × 10 días | Pediátrico: peso-dependiente (3 mg/kg/dosis 2×/día en < 1 año — off-label)',
    },
    frequency: {'pt': '2×/dia (tratamento) ou 1×/dia (profilaxia)', 'es': '2×/día (tratamiento) o 1×/día (profilaxis)'},
    renalAlert: {
      'pt': 'TFG 10–30: 30 mg 2×/dia (tratamento) ou 30 mg 1×/dia (profilaxia) | TFG < 10: não recomendado (dados insuficientes).',
      'es': 'TFG 10–30: 30 mg 2×/día (tratamiento) o 30 mg 1×/día (profilaxis) | TFG < 10: no recomendado (datos insuficientes).',
    },
    elderlyAlert: {
      'pt': 'Benefício máximo se iniciado em < 48 h dos sintomas. Monitorar confusão e alterações comportamentais (raramente relatadas em jovens mas possível em idosos).',
      'es': 'Beneficio máximo si se inicia en < 48 h de los síntomas. Monitorear confusión y alteraciones conductuales (raramente reportadas en jóvenes pero posible en ancianos).',
    },
    mechanism: {
      'pt': 'Pró-fármaco (carboxilato de oseltamivir ativo) → inibe neuraminidase viral (NA) do influenza A e B → bloqueia liberação de novos vírions da célula hospedeira → reduz disseminação viral. Reduz duração dos sintomas em 1–1,5 dias se iniciado em < 48 h.',
      'es': 'Profármaco (carboxilato de oseltamivir activo) → inhibe neuraminidasa viral (NA) del influenza A y B → bloquea liberación de nuevos viriones de la célula hospedadora → reduce diseminación viral. Reduce duración de síntomas en 1–1,5 días si iniciado en < 48 h.',
    },
    warning: {
      'pt': 'Eficaz apenas em influenza A e B (não cobre SARS-CoV-2, RSV, adenovírus). Resistência H275Y em H1N1 (oseltamivir-resistente → usar zanamivir). Tomar com alimento para minimizar náusea.',
      'es': 'Eficaz solo en influenza A y B (no cubre SARS-CoV-2, VSR, adenovirus). Resistencia H275Y en H1N1 (oseltamivir-resistente → usar zanamivir). Tomar con alimento para minimizar náusea.',
    },
    adverse: {
      'pt': ['Náusea (mais comum)', 'Vômito', 'Dor abdominal', 'Cefaleia', 'Insônia', 'Alterações comportamentais (raro — adolescentes)'],
      'es': ['Náusea (más común)', 'Vómito', 'Dolor abdominal', 'Cefalea', 'Insomnio', 'Alteraciones conductuales (raro — adolescentes)'],
    },
  ),

  DrugModel(
    id: 'anfotericina_b',
    group: 'Infectología (Antifúngicos / Antivirales / TBC)',
    name: 'Anfotericina B',
    className: {'pt': 'Antifúngico poliênico / Antiprotozoário', 'es': 'Antifúngico poliénico / Antiprotozoario'},
    category: {'pt': 'Antifúngico / Infecção fúngica grave', 'es': 'Antifúngico / Infección fúngica grave'},
    route: 'IV (infusão lenta)',
    doseType: 'mg_kg',
    mgKg: 0.5,
    fixedDose: {
      'pt': 'Anfotericina B deoxicolato (convencional): 0,25–1 mg/kg/dia IV | Formulação lipossômica (AmBisome): 3–5 mg/kg/dia IV | Criptocococose meningite: 0,7–1 mg/kg/dia × 2 semanas + flucitosina | Aspergilose/mucormicose: 1–1,5 mg/kg/dia',
      'es': 'Anfotericina B desoxicolato (convencional): 0,25–1 mg/kg/día IV | Formulación liposomal (AmBisome): 3–5 mg/kg/día IV | Criptococosis meningitis: 0,7–1 mg/kg/día × 2 semanas + flucitosina | Aspergilosis/mucormicosis: 1–1,5 mg/kg/día',
    },
    frequency: {'pt': '1×/dia (infusão 2–6 h)', 'es': '1×/día (infusión 2–6 h)'},
    renalAlert: {
      'pt': 'NEFROTÓXICA — monitorar creatinina e K⁺ diariamente. TFG < 10: reduzir para dias alternados (deoxicolato). Preferir formulação lipossômica em IRC (menos nefrotóxica). Suspender se creatinina > 3 mg/dL.',
      'es': 'NEFROTÓXICA — monitorear creatinina y K⁺ diariamente. TFG < 10: reducir a días alternos (desoxicolato). Preferir formulación liposomal en IRC (menos nefrotóxica). Suspender si creatinina > 3 mg/dL.',
    },
    elderlyAlert: {
      'pt': 'Preferir formulação lipossômica. Monitorar função renal e eletrólitos diariamente. Hidratação com SF 0,9% antes de cada dose reduz nefrotoxicidade.',
      'es': 'Preferir formulación liposomal. Monitorear función renal y electrolitos diariamente. Hidratación con SF 0,9% antes de cada dosis reduce nefrotoxicidad.',
    },
    mechanism: {
      'pt': 'Liga-se ao ergosterol da membrana fúngica → forma poros → perda de K⁺, Mg²⁺ e outros íons → morte celular. Amplo espectro: Candida, Aspergillus, Cryptococcus, Mucor, Histoplasma, Blastomyces. Fungicida. Leva-se anos para desenvolver resistência clínica.',
      'es': 'Se une al ergosterol de la membrana fúngica → forma poros → pérdida de K⁺, Mg²⁺ y otros iones → muerte celular. Amplio espectro: Candida, Aspergillus, Cryptococcus, Mucor, Histoplasma, Blastomyces. Fungicida. Tarda años en desarrollarse resistencia clínica.',
    },
    warning: {
      'pt': 'Reação infusional: febre, calafrios, mialgias, hipotensão (pré-medicar com paracetamol + hidrocortisona + meperidina). NEFROTÓXICA: hipocalemia e hipomagnesemia quase universais. Formulação lipossômica tem perfil de segurança muito superior — usar quando disponível.',
      'es': 'Reacción infusional: fiebre, escalofríos, mialgias, hipotensión (premedicar con paracetamol + hidrocortisona + meperidina). NEFROTÓXICA: hipopotasemia e hipomagnesemia casi universales. Formulación liposomal tiene perfil de seguridad muy superior — usar cuando disponible.',
    },
    adverse: {
      'pt': ['Nefrotoxicidade (80%)', 'Hipocalemia (80%)', 'Hipomagnesemia (80%)', 'Reação infusional (febre, calafrios)', 'Anemia normocítica', 'Flebite', 'Hepatotoxicidade (raro)'],
      'es': ['Nefrotoxicidad (80%)', 'Hipopotasemia (80%)', 'Hipomagnesemia (80%)', 'Reacción infusional (fiebre, escalofríos)', 'Anemia normocítica', 'Flebitis', 'Hepatotoxicidad (raro)'],
    },
  ),

  DrugModel(
    id: 'albendazol',
    group: 'Infectología (Antifúngicos / Antivirales / TBC)',
    name: 'Albendazol',
    className: {'pt': 'Anti-helmíntico (benzimidazol)', 'es': 'Antihelmíntico (benzimidazol)'},
    category: {'pt': 'Antiparasitário / Anti-helmíntico', 'es': 'Antiparasitario / Antihelmíntico'},
    route: 'VO (com alimento gorduroso para ↑ absorção)',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Geo-helmintos (Ascaris, Trichuris, ancilóstomo): 400 mg VO dose única | Estrongiloidíase: 400 mg 2×/dia × 3–7 dias | Neurocisticercose: 15 mg/kg/dia ÷ 2 doses × 8–30 dias (± dexametasona) | Equinococose: 400 mg 2×/dia em ciclos | Larva migrans: 400 mg/dia × 3–5 dias | Pediátrico > 2 anos: mesma dose do adulto',
      'es': 'Geohelmintos (Ascaris, Trichuris, anquilostoma): 400 mg VO dosis única | Estrongiloidiasis: 400 mg 2×/día × 3–7 días | Neurocisticercosis: 15 mg/kg/día ÷ 2 dosis × 8–30 días (± dexametasona) | Equinococosis: 400 mg 2×/día en ciclos | Larva migrans: 400 mg/día × 3–5 días | Pediátrico > 2 años: misma dosis del adulto',
    },
    frequency: {'pt': 'dose única a 2×/dia (conforme parasita)', 'es': 'dosis única a 2×/día (según parásito)'},
    renalAlert: {
      'pt': 'Sem ajuste necessário. Metabolismo hepático (sulfóxido de albendazol ativo).',
      'es': 'Sin ajuste necesario. Metabolismo hepático (sulfóxido de albendazol activo).',
    },
    elderlyAlert: {
      'pt': 'Monitorar função hepática em uso prolongado (neurocisticercose, equinococose).',
      'es': 'Monitorear función hepática en uso prolongado (neurocisticercosis, equinococosis).',
    },
    mechanism: {
      'pt': 'Liga-se à β-tubulina → inibe polimerização de microtúbulos → bloqueia captação de glicose e transporte intracelular → depleção de ATP → imobilização e morte do parasita. Ativo contra larvas e adultos. Metabolizado pelo fígado para sulfóxido de albendazol (forma ativa).',
      'es': 'Se une a β-tubulina → inhibe polimerización de microtúbulos → bloquea captación de glucosa y transporte intracelular → depleción de ATP → inmovilización y muerte del parásito. Activo contra larvas y adultos. Metabolizado por el hígado a sulfóxido de albendazol (forma activa).',
    },
    warning: {
      'pt': 'Neurocisticercose: reação inflamatória ao cisticerco morto → pode ↑ PIC — usar corticoide concomitante. Monitorar hemograma (mielossupressão em uso prolongado). Hepatotóxico em uso prolongado → monitorar TGO/TGP. Categoria D na gravidez.',
      'es': 'Neurocisticercosis: reacción inflamatoria al cisticerco muerto → puede ↑ PIC — usar corticoide concomitante. Monitorear hemograma (mielosupresión en uso prolongado). Hepatotóxico en uso prolongado → monitorear TGO/TGP. Categoría D en embarazo.',
    },
    adverse: {
      'pt': ['Náusea/dor abdominal', 'Cefaleia', 'Elevação de transaminases', 'Mielossupressão (uso prolongado)', 'Alopecia (uso prolongado)', 'Reação inflamatória (neurocisticercose)'],
      'es': ['Náusea/dolor abdominal', 'Cefalea', 'Elevación de transaminasas', 'Mielosupresión (uso prolongado)', 'Alopecia (uso prolongado)', 'Reacción inflamatoria (neurocisticercosis)'],
    },
  ),

  DrugModel(
    id: 'ivermectina',
    group: 'Infectología (Antifúngicos / Antivirales / TBC)',
    name: 'Ivermectina',
    className: {'pt': 'Anti-helmíntico / Antiparasitário (avermectina)', 'es': 'Antihelmíntico / Antiparasitario (avermectina)'},
    category: {'pt': 'Antiparasitário', 'es': 'Antiparasitario'},
    route: 'VO (jejum)',
    doseType: 'mg_kg',
    mgKg: 0.2,
    fixedDose: {
      'pt': 'Estrongiloidíase: 200 µg/kg VO dose única (repetir em 2 semanas) | Oncocercose: 150 µg/kg VO dose única anual | Escabiose: 200 µg/kg dose única (repetir 7–14 dias) | Pediculose: 200–400 µg/kg VO dose única | Larva migrans: 200 µg/kg/dia × 1–2 dias | Hyperinfestação: 200 µg/kg/dia até cura',
      'es': 'Estrongiloidiasis: 200 µg/kg VO dosis única (repetir en 2 semanas) | Oncocercosis: 150 µg/kg VO dosis única anual | Escabiosis: 200 µg/kg dosis única (repetir 7–14 días) | Pediculosis: 200–400 µg/kg VO dosis única | Larva migrans: 200 µg/kg/día × 1–2 días | Hiperinfestación: 200 µg/kg/día hasta curación',
    },
    frequency: {'pt': 'dose única (conforme parasita)', 'es': 'dosis única (según parásito)'},
    renalAlert: {
      'pt': 'Sem ajuste necessário. Excreção fecal predominante.',
      'es': 'Sin ajuste necesario. Excreción fecal predominante.',
    },
    elderlyAlert: {
      'pt': 'Geralmente bem tolerada. Tomar em jejum para melhor absorção. Síndrome de Mazzotti (oncocercose): reação inflamatória pós-tratamento — geralmente leve.',
      'es': 'Generalmente bien tolerada. Tomar en ayuno para mejor absorción. Síndrome de Mazzotti (oncocercosis): reacción inflamatoria post-tratamiento — generalmente leve.',
    },
    mechanism: {
      'pt': 'Liga-se canais de Cl⁻ glutamato-regulados (GluCl) em invertebrados (seletivos para invertebrados, ausentes em mamíferos) → hiperpolarização neuronal → paralisia e morte do parasita. Também potencializa GABA. NÃO tem atividade contra influenza, SARS-CoV-2 ou bactérias.',
      'es': 'Se une a canales de Cl⁻ glutamato-regulados (GluCl) en invertebrados (selectivos para invertebrados, ausentes en mamíferos) → hiperpolarización neuronal → parálisis y muerte del parásito. También potencia GABA. NO tiene actividad contra influenza, SARS-CoV-2 ni bacterias.',
    },
    warning: {
      'pt': 'NÃO tem eficácia comprovada contra COVID-19 (ensaios clínicos negativos). Síndrome de Mazzotti: febre, prurido, urticária após tratamento de oncocercose. Contraindicado em Loa loa coinfecção (encefalite). Mebendazol preferível para crianças < 15 kg.',
      'es': 'NO tiene eficacia comprobada contra COVID-19 (ensayos clínicos negativos). Síndrome de Mazzotti: fiebre, prurito, urticaria tras tratamiento de oncocercosis. Contraindicado en coinfección con Loa loa (encefalitis). Mebendazol preferible para niños < 15 kg.',
    },
    adverse: {
      'pt': ['Náusea', 'Diarreia', 'Tonteira', 'Síndrome de Mazzotti (oncocercose)', 'Prurido', 'Cefaleia', 'Sonolência'],
      'es': ['Náusea', 'Diarrea', 'Mareo', 'Síndrome de Mazzotti (oncocercosis)', 'Prurito', 'Cefalea', 'Somnolencia'],
    },
  ),

  DrugModel(
    id: 'sacubitril_valsartana',
    group: 'Cardiovascular y HTA',
    name: 'Sacubitril/Valsartana / Sacubitrilo/Valsartán',
    className: {'pt': 'ARNI (Inibidor de Neprilisina + BRA)', 'es': 'ARNI (Inhibidor de Neprilisina + ARA)'},
    category: {'pt': 'Cardiovascular', 'es': 'Cardiovascular'},
    route: 'Oral',
    doseType: 'fixed',
    fixedDose: {'pt': '49/51mg a 97/103mg 2x/dia', 'es': '49/51mg a 97/103mg 2 veces/día'},
    frequency: {'pt': '2x/dia', 'es': '2 veces/día'},
    renalAlert: {'pt': 'Reduzir dose se TFG <30mL/min; contraindicado em diálise', 'es': 'Reducir dosis si TFG <30mL/min; contraindicado en diálisis'},
    elderlyAlert: {'pt': 'Iniciar com dose menor (24/26mg); risco de hipotensão', 'es': 'Iniciar con dosis menor (24/26mg); riesgo de hipotensión'},
    mechanism: {'pt': 'Inibe neprilisina (↑peptídeos natriuréticos) e bloqueia receptor AT1 da angiotensina II; reduz pré e pós-carga, promove natriurese', 'es': 'Inhibe neprilisina (↑péptidos natriuréticos) y bloquea receptor AT1 de angiotensina II; reduce pre y poscarga, promueve natriuresis'},
    warning: {'pt': 'Contraindicado com IECA (intervalo mínimo 36h); contraindicado em angioedema prévio por IECA; contraindicado na gravidez', 'es': 'Contraindicado con IECA (intervalo mínimo 36h); contraindicado en angioedema previo por IECA; contraindicado en embarazo'},
    adverse: {
      'pt': ['Hipotensão', 'Hipercalemia', 'Tosse', 'Tontura', 'Angioedema (raro)', 'Insuficiência renal', 'Cefaleia'],
      'es': ['Hipotensión', 'Hipercalemia', 'Tos', 'Mareo', 'Angioedema (raro)', 'Insuficiencia renal', 'Cefalea'],
    },
  ),

  DrugModel(
    id: 'dapagliflozina',
    group: 'Endocrinología y Metabolismo',
    name: 'Dapagliflozina',
    className: {'pt': 'Inibidor SGLT-2', 'es': 'Inhibidor SGLT-2'},
    category: {'pt': 'Cardiovascular / Endócrino', 'es': 'Cardiovascular / Endocrino'},
    route: 'Oral',
    doseType: 'fixed',
    fixedDose: {'pt': '10mg 1x/dia', 'es': '10mg 1 vez/día'},
    frequency: {'pt': '1x/dia', 'es': '1 vez/día'},
    renalAlert: {'pt': 'Contraindicado se TFG <25mL/min para diabetes; para IC/DRC pode usar até TFG >15mL/min', 'es': 'Contraindicado si TFG <25mL/min para diabetes; para IC/ERC puede usar hasta TFG >15mL/min'},
    elderlyAlert: {'pt': 'Risco aumentado de depleção volêmica e infecções genitais', 'es': 'Mayor riesgo de depleción volumétrica e infecciones genitales'},
    mechanism: {'pt': 'Inibe cotransportador SGLT-2 no túbulo proximal renal, promovendo glicosúria e natriurese; efeitos cardioprotetores e nefroprotetores independentes da glicose', 'es': 'Inhibe cotransportador SGLT-2 en túbulo proximal renal, promoviendo glucosuria y natriuresis; efectos cardioprotectores y nefroprotectores independientes de glucosa'},
    warning: {'pt': 'Risco de cetoacidose diabética (mesmo com glicemia normal); suspender antes de cirurgias; risco de Fournier (fasciíte necrosante perineal)', 'es': 'Riesgo de cetoacidosis diabética (incluso con glucemia normal); suspender antes de cirugías; riesgo de Fournier (fascitis necrotizante perineal)'},
    adverse: {
      'pt': ['Infecções genitais fúngicas', 'ITU', 'Poliúria', 'Hipotensão ortostática', 'Cetoacidose diabética (raro)', 'Amputações (atenção)', 'Fraturas'],
      'es': ['Infecciones genitales fúngicas', 'ITU', 'Poliuria', 'Hipotensión ortostática', 'Cetoacidosis diabética (raro)', 'Amputaciones (atención)', 'Fracturas'],
    },
  ),

  DrugModel(
    id: 'empagliflozina',
    group: 'Endocrinología y Metabolismo',
    name: 'Empagliflozina',
    className: {'pt': 'Inibidor SGLT-2', 'es': 'Inhibidor SGLT-2'},
    category: {'pt': 'Cardiovascular / Endócrino', 'es': 'Cardiovascular / Endocrino'},
    route: 'Oral',
    doseType: 'fixed',
    fixedDose: {'pt': '10–25mg 1x/dia', 'es': '10–25mg 1 vez/día'},
    frequency: {'pt': '1x/dia', 'es': '1 vez/día'},
    renalAlert: {'pt': 'Reduzir eficácia glicêmica se TFG <45mL/min; manter para DRC/IC até TFG >20mL/min', 'es': 'Reduce eficacia glucémica si TFG <45mL/min; mantener para ERC/IC hasta TFG >20mL/min'},
    elderlyAlert: {'pt': 'Monitorar pressão e hidratação; maior sensibilidade a depleção volêmica', 'es': 'Monitorear presión e hidratación; mayor sensibilidad a depleción volumétrica'},
    mechanism: {'pt': 'Inibe SGLT-2 no rim, causando glicosúria; reduz mortalidade cardiovascular e hospitalização por IC; efeito nefroprotetor demonstrado', 'es': 'Inhibe SGLT-2 en riñón, causando glucosuria; reduce mortalidad cardiovascular y hospitalización por IC; efecto nefroprotector demostrado'},
    warning: {'pt': 'Mesmos alertas da dapagliflozina; suspender 3 dias antes de cirurgia; monitorar cetose', 'es': 'Mismas alertas que dapagliflozina; suspender 3 días antes de cirugía; monitorear cetosis'},
    adverse: {
      'pt': ['Infecções genitais', 'ITU', 'Poliúria', 'Hipotensão', 'Cetoacidose (raro)', 'Hipoglicemia (com insulina/sulfoniluréia)'],
      'es': ['Infecciones genitales', 'ITU', 'Poliuria', 'Hipotensión', 'Cetoacidosis (raro)', 'Hipoglucemia (con insulina/sulfonilurea)'],
    },
  ),

  DrugModel(
    id: 'ivabradina',
    group: 'Cardiovascular y HTA',
    name: 'Ivabradina',
    className: {'pt': 'Inibidor If (canal HCN)', 'es': 'Inhibidor If (canal HCN)'},
    category: {'pt': 'Cardiovascular', 'es': 'Cardiovascular'},
    route: 'Oral',
    doseType: 'fixed',
    fixedDose: {'pt': '5–7,5mg 2x/dia', 'es': '5–7,5mg 2 veces/día'},
    frequency: {'pt': '2x/dia', 'es': '2 veces/día'},
    renalAlert: {'pt': 'Sem ajuste necessário para TFG >15mL/min', 'es': 'Sin ajuste necesario para TFG >15mL/min'},
    elderlyAlert: {'pt': 'Iniciar com 2,5mg 2x/dia; maior risco de bradicardia', 'es': 'Iniciar con 2,5mg 2 veces/día; mayor riesgo de bradicardia'},
    mechanism: {'pt': 'Inibe seletivamente corrente If no nó sinusal, reduzindo frequência cardíaca sem afetar contratilidade ou pressão arterial', 'es': 'Inhibe selectivamente corriente If en nodo sinusal, reduciendo frecuencia cardíaca sin afectar contractilidad ni presión arterial'},
    warning: {'pt': 'Usar apenas em ritmo sinusal (FC ≥70bpm); contraindicado em FA, bloqueio AV grave, doença do nó sinusal', 'es': 'Usar solo en ritmo sinusal (FC ≥70lpm); contraindicado en FA, bloqueo AV grave, enfermedad del nodo sinusal'},
    adverse: {
      'pt': ['Bradicardia', 'Fosfenos (distúrbios visuais luminosos)', 'FA', 'Tontura', 'Cefaleia', 'Hipotensão'],
      'es': ['Bradicardia', 'Fosfenos (disturbios visuales luminosos)', 'FA', 'Mareo', 'Cefalea', 'Hipotensión'],
    },
  ),

  DrugModel(
    id: 'isossorbida',
    group: 'Cardiovascular y HTA',
    name: 'Isossorbida (Dinitrato/Mononitrato) / Isosorbida (Dinitrato/Mononitrato)',
    className: {'pt': 'Nitrato Orgânico', 'es': 'Nitrato Orgánico'},
    category: {'pt': 'Cardiovascular', 'es': 'Cardiovascular'},
    route: 'Oral / Sublingual',
    doseType: 'fixed',
    fixedDose: {'pt': 'Dinitrato: 5–10mg SL; 10–40mg VO 3x/dia | Mononitrato: 20–60mg 1–2x/dia', 'es': 'Dinitrato: 5–10mg SL; 10–40mg VO 3 veces/día | Mononitrato: 20–60mg 1–2 veces/día'},
    frequency: {'pt': '1–3x/dia (com intervalo nitrato-livre de 10–12h)', 'es': '1–3 veces/día (con intervalo libre de nitrato 10–12h)'},
    renalAlert: {'pt': 'Usar com cautela; possível acúmulo de metabólitos', 'es': 'Usar con cautela; posible acumulación de metabolitos'},
    elderlyAlert: {'pt': 'Alto risco de hipotensão ortostática; iniciar com doses mínimas', 'es': 'Alto riesgo de hipotensión ortostática; iniciar con dosis mínimas'},
    mechanism: {'pt': 'Libera óxido nítrico (NO), ativando guanilato ciclase → ↑GMPc → vasodilatação venosa (principalmente) e arterial; reduz pré-carga e isquemia miocárdica', 'es': 'Libera óxido nítrico (NO), activa guanilato ciclasa → ↑GMPc → vasodilatación venosa (principalmente) y arterial; reduce precarga e isquemia miocárdica'},
    warning: {'pt': 'Contraindicado com sildenafila/tadalafila (hipotensão grave); tolernância com uso contínuo — necessário intervalo livre; contraindicado em hipotensão grave', 'es': 'Contraindicado con sildenafilo/tadalafilo (hipotensión grave); tolerancia con uso continuo — necesario intervalo libre; contraindicado en hipotensión grave'},
    adverse: {
      'pt': ['Cefaleia intensa (vasodilação cerebral)', 'Hipotensão', 'Taquicardia reflexa', 'Rubor facial', 'Tontura', 'Tolerância com uso prolongado'],
      'es': ['Cefalea intensa (vasodilatación cerebral)', 'Hipotensión', 'Taquicardia refleja', 'Rubor facial', 'Mareo', 'Tolerancia con uso prolongado'],
    },
  ),

  DrugModel(
    id: 'verapamil',
    group: 'Cardiovascular y HTA',
    name: 'Verapamil / Verapamilo',
    className: {'pt': 'Bloqueador de Canal de Cálcio (não-diidropiridínico)', 'es': 'Bloqueador de Canal de Calcio (no dihidropiridínico)'},
    category: {'pt': 'Cardiovascular', 'es': 'Cardiovascular'},
    route: 'Oral / IV',
    doseType: 'fixed',
    fixedDose: {'pt': 'VO: 80–120mg 3x/dia (ou 120–480mg SR 1–2x/dia) | IV: 5–10mg em 2 min (pode repetir 10mg após 30 min)', 'es': 'VO: 80–120mg 3 veces/día (o 120–480mg SR 1–2 veces/día) | IV: 5–10mg en 2 min (puede repetir 10mg a los 30 min)'},
    frequency: {'pt': '1–3x/dia', 'es': '1–3 veces/día'},
    renalAlert: {'pt': 'Reduzir dose em insuficiência renal grave', 'es': 'Reducir dosis en insuficiencia renal grave'},
    elderlyAlert: {'pt': 'Maior risco de bloqueio AV e constipação; iniciar com doses menores', 'es': 'Mayor riesgo de bloqueo AV y estreñimiento; iniciar con dosis menores'},
    mechanism: {'pt': 'Bloqueia canais de cálcio L no coração e vasos; deprime nó AV (cronotropismo e dromotropismo negativos) e reduce RVP; efeito inotrópico negativo', 'es': 'Bloquea canales de calcio L en corazón y vasos; deprime nodo AV (cronotropismo y dromotropismo negativos) y reduce RVP; efecto inotrópico negativo'},
    warning: {'pt': 'Contraindicado em IC com FE reduzida, BAV 2º-3º grau, síndrome de WPW com FA; interação grave com betabloqueadores IV (risco de assistolia)', 'es': 'Contraindicado en IC con FE reducida, BAV 2°-3° grado, síndrome de WPW con FA; interacción grave con betabloqueantes IV (riesgo de asistolia)'},
    adverse: {
      'pt': ['Constipação (muito comum)', 'Bradicardia', 'Bloqueio AV', 'Hipotensão', 'Edema periférico', 'Tontura', 'IC (em predispostos)'],
      'es': ['Estreñimiento (muy común)', 'Bradicardia', 'Bloqueo AV', 'Hipotensión', 'Edema periférico', 'Mareo', 'IC (en predispuestos)'],
    },
  ),

  DrugModel(
    id: 'diltiazem',
    group: 'Cardiovascular y HTA',
    name: 'Diltiazem',
    className: {'pt': 'Bloqueador de Canal de Cálcio (benzotiazepínico)', 'es': 'Bloqueador de Canal de Calcio (benzotiazepínico)'},
    category: {'pt': 'Cardiovascular', 'es': 'Cardiovascular'},
    route: 'Oral / IV',
    doseType: 'fixed',
    fixedDose: {'pt': 'VO: 30–90mg 3–4x/dia (ou SR 120–360mg 1–2x/dia) | IV: 0,25mg/kg em 2 min; manutenção 5–15mg/h', 'es': 'VO: 30–90mg 3–4 veces/día (o SR 120–360mg 1–2 veces/día) | IV: 0,25mg/kg en 2 min; mantenimiento 5–15mg/h'},
    frequency: {'pt': '1–4x/dia', 'es': '1–4 veces/día'},
    renalAlert: {'pt': 'Ajuste em insuficiência renal grave; usar com cautela', 'es': 'Ajuste en insuficiencia renal grave; usar con cautela'},
    elderlyAlert: {'pt': 'Reduzir dose inicial; maior sensibilidade a bradicardia e hipotensão', 'es': 'Reducir dosis inicial; mayor sensibilidad a bradicardia e hipotensión'},
    mechanism: {'pt': 'Bloqueia canais de cálcio L cardíacos e vasculares; reduz FC, deprime condução AV e dilata artérias coronárias e periféricas; menos inotrópico negativo que verapamil', 'es': 'Bloquea canales de calcio L cardíacos y vasculares; reduce FC, deprime conducción AV y dilata arterias coronarias y periféricas; menos inotrópico negativo que verapamilo'},
    warning: {'pt': 'Contraindicado em BAV 2º-3º grau, disfunção sinusal, hipotensão grave, IC descompensada; cautela com digoxina e betabloqueadores', 'es': 'Contraindicado en BAV 2°-3° grado, disfunción sinusal, hipotensión grave, IC descompensada; cautela con digoxina y betabloqueantes'},
    adverse: {
      'pt': ['Bradicardia', 'Bloqueio AV', 'Hipotensão', 'Edema periférico', 'Cefaleia', 'Tontura', 'Constipação (menos que verapamil)'],
      'es': ['Bradicardia', 'Bloqueo AV', 'Hipotensión', 'Edema periférico', 'Cefalea', 'Mareo', 'Estreñimiento (menos que verapamilo)'],
    },
  ),

  DrugModel(
    id: 'dabigatrana',
    group: 'Anticoagulantes y Hemostasia',
    name: 'Dabigatrán (Pradaxa)',
    className: {'pt': 'Anticoagulante Oral Direto — Inibidor Direto da Trombina (IDT)', 'es': 'Anticoagulante Oral Directo — Inhibidor Directo de Trombina (IDT)'},
    category: {'pt': 'Hematologia', 'es': 'Hematología'},
    route: 'Oral',
    doseType: 'fixed',
    fixedDose: {'pt': 'FA: 150mg 2x/dia (110mg se >75 anos ou risco hemorrágico); TEV: 150mg 2x/dia após 5–10 dias de heparina', 'es': 'FA: 150mg 2 veces/día (110mg si >75 años o riesgo hemorrágico); TEV: 150mg 2 veces/día tras 5–10 días de heparina'},
    frequency: {'pt': '2x/dia', 'es': '2 veces/día'},
    renalAlert: {'pt': 'Contraindicado se TFG <30mL/min (FA); usar com cautela TFG 30–50mL/min; depende 80% eliminação renal', 'es': 'Contraindicado si TFG <30mL/min (FA); usar con cautela TFG 30–50mL/min; depende 80% eliminación renal'},
    elderlyAlert: {'pt': 'Reduzir para 110mg 2x/dia se >75 anos; alto risco de sangramento GI', 'es': 'Reducir a 110mg 2 veces/día si >75 años; alto riesgo de sangrado GI'},
    mechanism: {'pt': 'Inibe diretamente a trombina (livre e ligada a coágulo), bloqueando conversão de fibrinogênio a fibrina e ativação plaquetária mediada pela trombina', 'es': 'Inhibe directamente la trombina (libre y unida al coágulo), bloqueando conversión de fibrinógeno a fibrina y activación plaquetaria mediada por trombina'},
    warning: {'pt': 'Antídoto: idarucizumabe; não monitorar com INR (usar TT, ECT ou Hemoclot); interação com P-gp (rifampicina, amiodarona); não abrir cápsulas', 'es': 'Antídoto: idarucizumab; no monitorear con INR (usar TT, ECT o Hemoclot); interacción con P-gp (rifampicina, amiodarona); no abrir cápsulas'},
    adverse: {
      'pt': ['Sangramento (GI especialmente)', 'Dispepsia (20%)', 'Dor abdominal', 'Náusea', 'Hemorragia intracraniana (menor que varfarina)', 'Hepatotoxicidade (rara)'],
      'es': ['Sangrado (GI especialmente)', 'Dispepsia (20%)', 'Dolor abdominal', 'Náusea', 'Hemorragia intracraneal (menor que warfarina)', 'Hepatotoxicidad (rara)'],
    },
  ),

  DrugModel(
    id: 'apixabana',
    group: 'Anticoagulantes y Hemostasia',
    name: 'Apixabana / Apixabán',
    className: {'pt': 'Anticoagulante Oral Direto — Inibidor Direto do Fator Xa', 'es': 'Anticoagulante Oral Directo — Inhibidor Directo del Factor Xa'},
    category: {'pt': 'Hematologia', 'es': 'Hematología'},
    route: 'Oral',
    doseType: 'fixed',
    fixedDose: {'pt': 'FA: 5mg 2x/dia (2,5mg se ≥2 critérios: ≥80 anos, ≤60kg, Cr ≥1,5mg/dL); TEV tratamento: 10mg 2x/dia × 7 dias → 5mg 2x/dia', 'es': 'FA: 5mg 2 veces/día (2,5mg si ≥2 criterios: ≥80 años, ≤60kg, Cr ≥1,5mg/dL); TEV tratamiento: 10mg 2 veces/día × 7 días → 5mg 2 veces/día'},
    frequency: {'pt': '2x/dia', 'es': '2 veces/día'},
    renalAlert: {'pt': 'Ajuste em FA se ≥2 critérios; contraindicado se TFG <15mL/min; 27% eliminação renal (melhor tolerado em DRC)', 'es': 'Ajuste en FA si ≥2 criterios; contraindicado si TFG <15mL/min; 27% eliminación renal (mejor tolerado en ERC)'},
    elderlyAlert: {'pt': 'Reduzir dose se ≥2 critérios de dose reduzida; perfil de sangramento favorável vs varfarina', 'es': 'Reducir dosis si ≥2 criterios de dosis reducida; perfil de sangrado favorable vs warfarina'},
    mechanism: {'pt': 'Inibe seletiva e reversivelmente o fator Xa (livre, ligado ao coágulo e no complexo protrombinase), interrompendo a cascata de coagulação sem necessidade de antitrombina', 'es': 'Inhibe selectiva y reversiblemente el factor Xa (libre, unido al coágulo y en el complejo protrombinasa), interrumpiendo la cascada de coagulación sin necesitar antitrombina'},
    warning: {'pt': 'Antídoto: andexanet alfa; menor interação com alimentos/medicamentos vs varfarina; evitar em gravidez; sem monitoramento de rotina (usar anti-Xa se necessário)', 'es': 'Antídoto: andexanet alfa; menor interacción con alimentos/medicamentos vs warfarina; evitar en embarazo; sin monitoreo de rutina (usar anti-Xa si necesario)'},
    adverse: {
      'pt': ['Sangramento (menor que varfarina)', 'Anemia', 'Equimoses', 'Náusea', 'Elevação de transaminases (raro)', 'Hemorragia grave (raro)'],
      'es': ['Sangrado (menor que warfarina)', 'Anemia', 'Equimosis', 'Náusea', 'Elevación de transaminasas (raro)', 'Hemorragia grave (raro)'],
    },
  ),

  DrugModel(
    id: 'ticagrelor',
    group: 'Cardiovascular y HTA',
    name: 'Ticagrelor',
    className: {'pt': 'Antiagregante Plaquetário — Inibidor P2Y12 (reversível)', 'es': 'Antiagregante Plaquetario — Inhibidor P2Y12 (reversible)'},
    category: {'pt': 'Hematologia / Cardiovascular', 'es': 'Hematología / Cardiovascular'},
    route: 'Oral',
    doseType: 'fixed',
    fixedDose: {'pt': 'Ataque: 180mg dose única; Manutenção: 90mg 2x/dia (reduz para 60mg 2x/dia após 12 meses)', 'es': 'Ataque: 180mg dosis única; Mantenimiento: 90mg 2 veces/día (reduce a 60mg 2 veces/día después de 12 meses)'},
    frequency: {'pt': '2x/dia', 'es': '2 veces/día'},
    renalAlert: {'pt': 'Sem ajuste necessário em DRC; cautela em diálise (dados limitados)', 'es': 'Sin ajuste necesario en ERC; cautela en diálisis (datos limitados)'},
    elderlyAlert: {'pt': 'Maior risco de sangramento; monitorar dispneia', 'es': 'Mayor riesgo de sangrado; monitorear disnea'},
    mechanism: {'pt': 'Inibe reversivelmente receptor P2Y12 do ADP nas plaquetas, bloqueando ativação e agregação plaquetária; ação mais rápida e potente que clopidogrel (não necessita ativação hepática)', 'es': 'Inhibe reversiblemente receptor P2Y12 del ADP en plaquetas, bloqueando activación y agregación plaquetaria; acción más rápida y potente que clopidogrel (no necesita activación hepática)'},
    warning: {'pt': 'Contraindicado com AVC hemorrágico prévio e sangramento ativo; reduzir AAS para 75–100mg (doses maiores reduzem eficácia do ticagrelor); parar 5 dias antes de cirurgia', 'es': 'Contraindicado con ACV hemorrágico previo y sangrado activo; reducir AAS a 75–100mg (dosis mayores reducen eficacia); suspender 5 días antes de cirugía'},
    adverse: {
      'pt': ['Dispneia (frequente — mecanismo adenosina)', 'Sangramento', 'Pausas ventriculares (início do tratamento)', 'Elevação de ácido úrico', 'Cefaleia', 'Tontura'],
      'es': ['Disnea (frecuente — mecanismo adenosina)', 'Sangrado', 'Pausas ventriculares (inicio de tratamiento)', 'Elevación de ácido úrico', 'Cefalea', 'Mareo'],
    },
  ),

  DrugModel(
    id: 'alteplase',
    group: 'Cardiovascular y HTA',
    name: 'Alteplase (rt-PA)',
    className: {'pt': 'Trombolítico — Ativador do Plasminogênio Tecidual Recombinante', 'es': 'Trombolítico — Activador del Plasminógeno Tisular Recombinante'},
    category: {'pt': 'Hematologia / Emergência', 'es': 'Hematología / Emergencia'},
    route: 'IV',
    doseType: 'mg_kg',
    mgKg: 0.9,
    fixedDose: {'pt': 'AVC: 0,9mg/kg IV (máx 90mg): 10% em bolus, 90% em 60 min | IAM: 15mg bolus + 0,75mg/kg em 30 min + 0,5mg/kg em 60 min (máx 100mg) | EP maciça: 100mg em 2h', 'es': 'ACV: 0,9mg/kg IV (máx 90mg): 10% en bolo, 90% en 60 min | IAM: 15mg bolo + 0,75mg/kg en 30 min + 0,5mg/kg en 60 min (máx 100mg) | EP masiva: 100mg en 2h'},
    frequency: {'pt': 'Dose única (uso emergencial)', 'es': 'Dosis única (uso emergencial)'},
    renalAlert: {'pt': 'Sem ajuste necessário; monitorar função renal após uso', 'es': 'Sin ajuste necesario; monitorear función renal tras uso'},
    elderlyAlert: {'pt': 'Maior risco de hemorragia intracraniana após 75 anos; avaliar risco-benefício criteriosamente', 'es': 'Mayor riesgo de hemorragia intracraneal después de 75 años; evaluar riesgo-beneficio cuidadosamente'},
    mechanism: {'pt': 'Liga-se à fibrina do trombo e converte o plasminogênio em plasmina, promovendo fibrinólise local e sistêmica; dissolve coágulos arteriais e venosos', 'es': 'Se une a fibrina del trombo y convierte plasminógeno en plasmina, promoviendo fibrinólisis local y sistémica; disuelve coágulos arteriales y venosos'},
    warning: {'pt': 'Contraindicações absolutas: cirurgia/trauma recente (<3 meses), sangramento ativo, HIC/AVC hemorrágico, neoplasia intracraniana, HAS não controlada >185/110mmHg; janela terapêutica AVC: 4,5h do início dos sintomas', 'es': 'Contraindicaciones absolutas: cirugía/trauma reciente (<3 meses), sangrado activo, HIC/ACV hemorrágico, neoplasia intracraneal, HAS no controlada >185/110mmHg; ventana terapéutica ACV: 4,5h del inicio de síntomas'},
    adverse: {
      'pt': ['Hemorragia intracraniana (3–6%)', 'Sangramento em locais de punção', 'Hemorragia GI', 'Angioedema orolingual', 'Hipotensão', 'Febre'],
      'es': ['Hemorragia intracraneal (3–6%)', 'Sangrado en sitios de punción', 'Hemorragia GI', 'Angioedema orolingual', 'Hipotensión', 'Fiebre'],
    },
  ),

  DrugModel(
    id: 'carbamazepina',
    group: 'Neurología y Psiquiatría',
    name: 'Carbamazepina',
    className: {'pt': 'Antiepiléptico — Bloqueador de Canal de Sódio', 'es': 'Antiepiléptico — Bloqueador de Canal de Sodio'},
    category: {'pt': 'Neurologia', 'es': 'Neurología'},
    route: 'Oral',
    doseType: 'fixed',
    fixedDose: {'pt': '100–200mg 2x/dia; aumentar gradualmente; manutenção 400–1600mg/dia', 'es': '100–200mg 2 veces/día; aumentar gradualmente; mantenimiento 400–1600mg/día'},
    frequency: {'pt': '2–4x/dia', 'es': '2–4 veces/día'},
    renalAlert: {'pt': 'Sem ajuste específico; monitorar níveis séricos', 'es': 'Sin ajuste específico; monitorear niveles séricos'},
    elderlyAlert: {'pt': 'Maior risco de hiponatremia, ataxia e interações; reduzir doses iniciais; monitorar sódio', 'es': 'Mayor riesgo de hiponatremia, ataxia e interacciones; reducir dosis iniciales; monitorear sodio'},
    mechanism: {'pt': 'Bloqueia canais de sódio voltagem-dependentes na membrana neuronal, estabilizando-a e reduzindo descarga repetitiva de alta frequência; também agonista receptor GABA-B', 'es': 'Bloquea canales de sodio voltaje-dependientes en membrana neuronal, estabilizándola y reduciendo descargas repetitivas de alta frecuencia; también agonista receptor GABA-B'},
    warning: {'pt': 'Autoindutor enzimático potente (CYP3A4, 2C9, etc.) — reduz eficácia de muitos fármacos; risco de aplasia medular e síndrome de Stevens-Johnson (HLA-B*1502 em asiáticos); monitorar hemograma e sódio; teratogênico', 'es': 'Autoinductor enzimático potente (CYP3A4, 2C9, etc.) — reduce eficacia de muchos fármacos; riesgo de aplasia medular y síndrome de Stevens-Johnson (HLA-B*1502 en asiáticos); monitorar hemograma y sodio; teratogénico'},
    adverse: {
      'pt': ['Diplopia e visão turva', 'Ataxia', 'Tontura', 'Sonolência', 'Hiponatremia (SIADH)', 'Leucopenia', 'Aplasia (raro)', 'Rash/Stevens-Johnson', 'Hepatotoxicidade'],
      'es': ['Diplopía y visión borrosa', 'Ataxia', 'Mareo', 'Somnolencia', 'Hiponatremia (SIADH)', 'Leucopenia', 'Aplasia (raro)', 'Rash/Stevens-Johnson', 'Hepatotoxicidad'],
    },
  ),

  DrugModel(
    id: 'oxcarbazepina',
    group: 'Neurología y Psiquiatría',
    name: 'Oxcarbazepina',
    className: {'pt': 'Antiepiléptico — Bloqueador de Canal de Sódio (análogo da carbamazepina)', 'es': 'Antiepiléptico — Bloqueador de Canal de Sodio (análogo de carbamazepina)'},
    category: {'pt': 'Neurologia', 'es': 'Neurología'},
    route: 'Oral',
    doseType: 'fixed',
    fixedDose: {'pt': '300mg 2x/dia; manutenção 600–2400mg/dia', 'es': '300mg 2 veces/día; mantenimiento 600–2400mg/día'},
    frequency: {'pt': '2x/dia', 'es': '2 veces/día'},
    renalAlert: {'pt': 'Reduzir dose pela metade se TFG <30mL/min; metabólito ativo acumula', 'es': 'Reducir dosis a la mitad si TFG <30mL/min; metabolito activo se acumula'},
    elderlyAlert: {'pt': 'Monitorar sódio sérico com frequência; risco de hiponatremia grave', 'es': 'Monitorear sodio sérico frecuentemente; riesgo de hiponatremia grave'},
    mechanism: {'pt': 'Pró-fármaco convertido a monohydroxi-derivado (MHD) ativo; bloqueia canais de sódio voltagem-dependentes; menor indução enzimática e melhor tolerabilidade vs carbamazepina', 'es': 'Profármaco convertido a monohidroxi-derivado (MHD) activo; bloquea canales de sodio voltaje-dependientes; menor inducción enzimática y mejor tolerabilidad vs carbamazepina'},
    warning: {'pt': 'Hiponatremia significativamente mais frequente que carbamazepina; risco de Stevens-Johnson (monitorar); reatividade cruzada com carbamazepina em ~25% dos casos', 'es': 'Hiponatremia significativamente más frecuente que carbamazepina; riesgo de Stevens-Johnson (monitorear); reactividad cruzada con carbamazepina en ~25% de casos'},
    adverse: {
      'pt': ['Hiponatremia (frequente)', 'Tontura', 'Sonolência', 'Cefaleia', 'Ataxia', 'Diplopia', 'Náusea', 'Rash (Stevens-Johnson raro)'],
      'es': ['Hiponatremia (frecuente)', 'Mareo', 'Somnolencia', 'Cefalea', 'Ataxia', 'Diplopía', 'Náusea', 'Rash (Stevens-Johnson raro)'],
    },
  ),

  DrugModel(
    id: 'lamotrigina',
    group: 'Neurología y Psiquiatría',
    name: 'Lamotrigina',
    className: {'pt': 'Antiepiléptico / Estabilizador de Humor — Bloqueador de Canal de Sódio', 'es': 'Antiepiléptico / Estabilizador del Humor — Bloqueador de Canal de Sodio'},
    category: {'pt': 'Neurologia / Psiquiatria', 'es': 'Neurología / Psiquiatría'},
    route: 'Oral',
    doseType: 'fixed',
    fixedDose: {'pt': 'Monoterapia: 25mg/dia × 2 sem → 50mg × 2 sem → ↑25–50mg/2 sem; manutenção 100–400mg/dia | Com valproato: iniciar 12,5mg em dias alternados (reduzir dose pela metade)', 'es': 'Monoterapia: 25mg/día × 2 sem → 50mg × 2 sem → ↑25–50mg/2 sem; mantenimiento 100–400mg/día | Con valproato: iniciar 12,5mg días alternos (reducir dosis a la mitad)'},
    frequency: {'pt': '1–2x/dia', 'es': '1–2 veces/día'},
    renalAlert: {'pt': 'Reduzir dose em insuficiência renal grave; monitorar níveis', 'es': 'Reducir dosis en insuficiencia renal grave; monitorear niveles'},
    elderlyAlert: {'pt': 'Titular lentamente; monitorar rash cutâneo nas primeiras 8 semanas', 'es': 'Titular lentamente; monitorear rash cutáneo en las primeras 8 semanas'},
    mechanism: {'pt': 'Bloqueia canais de sódio voltagem-dependentes e inibe liberação de glutamato e aspartato; ação estabilizadora de membrana; também bloqueia canais de cálcio tipo N/P', 'es': 'Bloquea canales de sodio voltaje-dependientes e inhibe liberación de glutamato y aspartato; acción estabilizadora de membrana; también bloquea canales de calcio tipo N/P'},
    warning: {'pt': 'Risco grave de síndrome de Stevens-Johnson — TITULAR LENTAMENTE (risco ↑ com ácido valpróico e titulação rápida); interação com valproato (↑ níveis de lamotrigina) e carbamazepina (↓ níveis)', 'es': 'Riesgo grave de síndrome de Stevens-Johnson — TITULAR LENTAMENTE (riesgo ↑ con ácido valpróico y titulación rápida); interacción con valproato (↑ niveles de lamotrigina) y carbamazepina (↓ niveles)'},
    adverse: {
      'pt': ['Rash (10% — pode ser grave)', 'Stevens-Johnson/NET (raro mas grave)', 'Tontura', 'Cefaleia', 'Diplopia', 'Ataxia', 'Insônia', 'Náusea'],
      'es': ['Rash (10% — puede ser grave)', 'Stevens-Johnson/NET (raro pero grave)', 'Mareo', 'Cefalea', 'Diplopía', 'Ataxia', 'Insomnio', 'Náusea'],
    },
  ),

  DrugModel(
    id: 'topiramato',
    group: 'Neurología y Psiquiatría',
    name: 'Topiramato',
    className: {'pt': 'Antiepiléptico Multimodal', 'es': 'Antiepiléptico Multimodal'},
    category: {'pt': 'Neurologia', 'es': 'Neurología'},
    route: 'Oral',
    doseType: 'fixed',
    fixedDose: {'pt': 'Epilepsia: 25mg/dia; ↑25mg/semana; manutenção 200–400mg/dia | Profilaxia enxaqueca: 25–100mg/dia', 'es': 'Epilepsia: 25mg/día; ↑25mg/semana; mantenimiento 200–400mg/día | Profilaxis migraña: 25–100mg/día'},
    frequency: {'pt': '2x/dia', 'es': '2 veces/día'},
    renalAlert: {'pt': 'Reduzir dose 50% se TFG <70mL/min; risco de nefrolitíase (carbonato anidrase); aumentar hidratação', 'es': 'Reducir dosis 50% si TFG <70mL/min; riesgo de nefrolitiasis (anhidrasa carbónica); aumentar hidratación'},
    elderlyAlert: {'pt': 'Titular muito lentamente; maior risco de comprometimento cognitivo', 'es': 'Titular muy lentamente; mayor riesgo de deterioro cognitivo'},
    mechanism: {'pt': 'Mecanismo múltiplo: bloqueia canais Na+, potencializa GABA-A, antagoniza receptores AMPA/kainato de glutamato, inibe anidrase carbônica; também suprime apetite', 'es': 'Mecanismo múltiple: bloquea canales Na+, potencia GABA-A, antagoniza receptores AMPA/kainato de glutamato, inhibe anhidrasa carbónica; también suprime apetito'},
    warning: {'pt': 'Cognição prejudicada ("dopiramato") — comprometimento de memória e linguagem; risco de glaucoma agudo de ângulo fechado (suspender imediatamente); acidose metabólica; hipertermia por oligoidrose; teratogênico (fissura palatina)', 'es': 'Cognición deteriorada ("dopiramato") — compromiso de memoria y lenguaje; riesgo de glaucoma agudo de ángulo cerrado (suspender inmediatamente); acidosis metabólica; hipertermia por oligohidrosis; teratogénico (fisura palatina)'},
    adverse: {
      'pt': ['Comprometimento cognitivo (memória, linguagem)', 'Nefrolitíase', 'Perda de peso', 'Parestesias', 'Sonolência', 'Tontura', 'Glaucoma agudo (raro)', 'Acidose metabólica', 'Oligoidrose'],
      'es': ['Deterioro cognitivo (memoria, lenguaje)', 'Nefrolitiasis', 'Pérdida de peso', 'Parestesias', 'Somnolencia', 'Mareo', 'Glaucoma agudo (raro)', 'Acidosis metabólica', 'Oligohidrosis'],
    },
  ),

  DrugModel(
    id: 'olanzapina',
    group: 'Neurología y Psiquiatría',
    name: 'Olanzapina',
    className: {'pt': 'Antipsicótico Atípico — Tienobenzodiazepínico', 'es': 'Antipsicótico Atípico — Tienobenzodiazepínico'},
    category: {'pt': 'Psiquiatria', 'es': 'Psiquiatría'},
    route: 'Oral / IM',
    doseType: 'fixed',
    fixedDose: {'pt': 'Oral: 5–20mg/dia | IM (agitação): 5–10mg; pode repetir após 2h (máx 30mg/24h)', 'es': 'Oral: 5–20mg/día | IM (agitación): 5–10mg; puede repetir tras 2h (máx 30mg/24h)'},
    frequency: {'pt': '1x/dia (oral)', 'es': '1 vez/día (oral)'},
    renalAlert: {'pt': 'Sem ajuste necessário', 'es': 'Sin ajuste necesario'},
    elderlyAlert: {'pt': 'Reduzir para 2,5–5mg; alto risco metabólico e queda; mortalidade aumentada em idosos com demência (black box)', 'es': 'Reducir a 2,5–5mg; alto riesgo metabólico y caídas; mortalidad aumentada en ancianos con demencia (black box)'},
    mechanism: {'pt': 'Antagonista de múltiplos receptores: D1-D4 (dopamina), 5-HT2A/2C (serotonina), H1 (histamina), M1-M5 (muscarínicos), α1 (adrenérgico); perfil de receptor mais amplo que haloperidol', 'es': 'Antagonista de múltiples receptores: D1-D4 (dopamina), 5-HT2A/2C (serotonina), H1 (histamina), M1-M5 (muscarínicos), α1 (adrenérgico); perfil de receptor más amplio que haloperidol'},
    warning: {'pt': 'Síndrome metabólica (↑peso, ↑glicose, dislipidemia) — MONITORAR; QT prolongado; cautela com benzodiazepínicos IM (depressão respiratória); síndrome neuroléptica maligna (raro)', 'es': 'Síndrome metabólica (↑peso, ↑glucosa, dislipidemia) — MONITOREAR; QT prolongado; cautela con benzodiacepinas IM (depresión respiratoria); síndrome neuroléptica maligna (raro)'},
    adverse: {
      'pt': ['Ganho de peso significativo (>7kg)', 'Hiperglicemia/DM2', 'Hiperlipidemia', 'Sonolência', 'Hipotensão ortostática', 'Sintomas extrapiramidais (menos que típicos)', 'Boca seca'],
      'es': ['Aumento de peso significativo (>7kg)', 'Hiperglucemia/DM2', 'Hiperlipidemia', 'Somnolencia', 'Hipotensión ortostática', 'Síntomas extrapiramidales (menos que típicos)', 'Boca seca'],
    },
  ),

  DrugModel(
    id: 'litio',
    group: 'Neurología y Psiquiatría',
    name: 'Lítio (Carbonato de Lítio) / Litio (Carbonato de Litio)',
    className: {'pt': 'Estabilizador de Humor — Sal de Lítio', 'es': 'Estabilizador del Humor — Sal de Litio'},
    category: {'pt': 'Psiquiatria', 'es': 'Psiquiatría'},
    route: 'Oral',
    doseType: 'fixed',
    fixedDose: {'pt': '300mg 3x/dia (início); manutenção 900–1800mg/dia em doses fracionadas; guiar pela litemia', 'es': '300mg 3 veces/día (inicio); mantenimiento 900–1800mg/día en dosis fraccionadas; guiar por litemia'},
    frequency: {'pt': '2–3x/dia', 'es': '2–3 veces/día'},
    renalAlert: {'pt': 'Contraindicado em insuficiência renal significativa; risco grave de toxicidade; monitorar creatinina e litemia frequentemente', 'es': 'Contraindicado en insuficiencia renal significativa; riesgo grave de toxicidad; monitorear creatinina y litemia frecuentemente'},
    elderlyAlert: {'pt': 'Doses menores (50% da dose adulto); monitorar litemia e função renal mais frequentemente; sensibilidade neurológica aumentada', 'es': 'Dosis menores (50% de dosis adulta); monitorear litemia y función renal más frecuentemente; sensibilidad neurológica aumentada'},
    mechanism: {'pt': 'Mecanismo não completamente elucidado; inibe inositol monofosfatase e GSK-3β; modula neurotransmissão monoaminérgica; aumenta síntese de BDNF (neuroproteção); nível sérico terapêutico: 0,6–1,2mEq/L', 'es': 'Mecanismo no completamente dilucidado; inhibe inositol monofosfatasa y GSK-3β; modula neurotransmisión monoaminérgica; aumenta síntesis de BDNF (neuroprotección); nivel sérico terapéutico: 0,6–1,2mEq/L'},
    warning: {'pt': 'ÍNDICE TERAPÊUTICO ESTREITO — monitorar litemia regularmente; toxicidade grave com litemia >1,5mEq/L; interações: AINE, diuréticos tiazídicos, IECA aumentam litemia; evitar desidratação; teratogênico (anomalia de Ebstein)', 'es': 'ÍNDICE TERAPÉUTICO ESTRECHO — monitorear litemia regularmente; toxicidad grave con litemia >1,5mEq/L; interacciones: AINE, diuréticos tiazídicos, IECA aumentan litemia; evitar deshidratación; teratogénico (anomalía de Ebstein)'},
    adverse: {
      'pt': ['Tremor fino de mãos', 'Poliúria/polidipsia (diabetes insípida nefrogênica)', 'Hipotireoidismo', 'Ganho de peso', 'Acne/psoríase', 'Toxicidade: tremor grosseiro, confusão, convulsões (litemia >2mEq/L)', 'Nefrotoxicidade crônica'],
      'es': ['Temblor fino de manos', 'Poliuria/polidipsia (diabetes insípida nefrogénica)', 'Hipotiroidismo', 'Aumento de peso', 'Acné/psoriasis', 'Toxicidad: temblor grueso, confusión, convulsiones (litemia >2mEq/L)', 'Nefrotoxicidad crónica'],
    },
  ),

  DrugModel(
    id: 'venlafaxina',
    group: 'Neurología y Psiquiatría',
    name: 'Venlafaxina',
    className: {'pt': 'Antidepressivo IRSN (Inibidor de Recaptura de Serotonina e Noradrenalina)', 'es': 'Antidepresivo IRSN (Inhibidor de Recaptación de Serotonina y Noradrenalina)'},
    category: {'pt': 'Psiquiatria', 'es': 'Psiquiatría'},
    route: 'Oral',
    doseType: 'fixed',
    fixedDose: {'pt': '37,5–75mg/dia (início); manutenção 75–225mg/dia (XR: 1x/dia; IR: 2–3x/dia)', 'es': '37,5–75mg/día (inicio); mantenimiento 75–225mg/día (XR: 1 vez/día; IR: 2–3 veces/día)'},
    frequency: {'pt': '1–3x/dia (dependendo da formulação)', 'es': '1–3 veces/día (según formulación)'},
    renalAlert: {'pt': 'Reduzir dose 25–50% em TFG <30mL/min', 'es': 'Reducir dosis 25–50% en TFG <30mL/min'},
    elderlyAlert: {'pt': 'Monitorar PA (HAS dose-dependente); iniciar com dose menor; risco de hiponatremia', 'es': 'Monitorear PA (HAS dosis-dependiente); iniciar con dosis menor; riesgo de hiponatremia'},
    mechanism: {'pt': 'Inibe recaptura de serotonina (potente) e noradrenalina (em doses >150mg); sem ação antimuscarínica, anti-histamínica ou bloqueio alfa-1 significativos (melhor tolerabilidade)', 'es': 'Inhibe recaptación de serotonina (potente) y noradrenalina (a dosis >150mg); sin acción antimuscarínica, antihistamínica o bloqueo alfa-1 significativos (mejor tolerabilidad)'},
    warning: {'pt': 'Hipertensão arterial dose-dependente (monitorar PA); síndrome de descontinuação intensa (retirar gradualmente); risco de síndrome serotoninérgica com MAOIs; piora de ansiedade nas 1–2 primeiras semanas', 'es': 'Hipertensión arterial dosis-dependiente (monitorear PA); síndrome de discontinuación intensa (retirar gradualmente); riesgo de síndrome serotoninérgico con MAOIs; empeoramiento de ansiedad en primeras 1–2 semanas'},
    adverse: {
      'pt': ['Náusea (frequente — melhor com alimentação)', 'Cefaleia', 'Insônia/ansiedade inicial', 'Hipertensão', 'Sudorese', 'Disfunção sexual', 'Síndrome de descontinuação'],
      'es': ['Náusea (frecuente — mejor con alimentos)', 'Cefalea', 'Insomnio/ansiedad inicial', 'Hipertensión', 'Sudoración', 'Disfunción sexual', 'Síndrome de discontinuación'],
    },
  ),

  DrugModel(
    id: 'duloxetina',
    group: 'Neurología y Psiquiatría',
    name: 'Duloxetina',
    className: {'pt': 'Antidepressivo IRSN', 'es': 'Antidepresivo IRSN'},
    category: {'pt': 'Psiquiatria / Dor', 'es': 'Psiquiatría / Dolor'},
    route: 'Oral',
    doseType: 'fixed',
    fixedDose: {'pt': '30–60mg/dia (início); manutenção 60–120mg/dia', 'es': '30–60mg/día (inicio); mantenimiento 60–120mg/día'},
    frequency: {'pt': '1–2x/dia', 'es': '1–2 veces/día'},
    renalAlert: {'pt': 'Contraindicada se TFG <30mL/min (metabólitos acumulam)', 'es': 'Contraindicada si TFG <30mL/min (metabolitos se acumulan)'},
    elderlyAlert: {'pt': 'Monitorar PA e função renal; iniciar com 30mg; risco de quedas', 'es': 'Monitorear PA y función renal; iniciar con 30mg; riesgo de caídas'},
    mechanism: {'pt': 'Inibe recaptura de serotonina e noradrenalina de forma equilibrada; sem afinidade significativa por receptores muscarínicos, histamínicos ou dopaminérgicos; efeito analgésico em dor neuropática via vias descendentes inibitórias', 'es': 'Inhibe recaptación de serotonina y noradrenalina de forma equilibrada; sin afinidad significativa por receptores muscarínicos, histamínicos o dopaminérgicos; efecto analgésico en dolor neuropático vía vías descendentes inhibitorias'},
    warning: {'pt': 'Hepatotoxicidade (evitar em hepatopatia); síndrome de descontinuação; interação com MAOIs (contraindicado); risco de glaucoma de ângulo fechado; hiponatremia', 'es': 'Hepatotoxicidad (evitar en hepatopatía); síndrome de discontinuación; interacción con MAOIs (contraindicado); riesgo de glaucoma de ángulo cerrado; hiponatremia'},
    adverse: {
      'pt': ['Náusea', 'Boca seca', 'Constipação', 'Sonolência', 'Tontura', 'Hiperhidrose', 'Hepatotoxicidade (raro)', 'Disfunção sexual', 'Síndrome de descontinuação'],
      'es': ['Náusea', 'Boca seca', 'Estreñimiento', 'Somnolencia', 'Mareo', 'Hiperhidrosis', 'Hepatotoxicidad (raro)', 'Disfunción sexual', 'Síndrome de discontinuación'],
    },
  ),

  DrugModel(
    id: 'escitalopram',
    group: 'Neurología y Psiquiatría',
    name: 'Escitalopram',
    className: {'pt': 'Antidepressivo ISRS', 'es': 'Antidepresivo ISRS'},
    category: {'pt': 'Psiquiatria', 'es': 'Psiquiatría'},
    route: 'Oral',
    doseType: 'fixed',
    fixedDose: {'pt': '10mg/dia; pode ↑ para 20mg/dia após 1–4 semanas', 'es': '10mg/día; puede ↑ a 20mg/día después de 1–4 semanas'},
    frequency: {'pt': '1x/dia', 'es': '1 vez/día'},
    renalAlert: {'pt': 'Sem ajuste necessário em DRC leve-moderada; cautela em grave', 'es': 'Sin ajuste necesario en ERC leve-moderada; cautela en grave'},
    elderlyAlert: {'pt': 'Máximo 10mg/dia em idosos; ISRS mais seletivo e melhor tolerado; monitorar sódio', 'es': 'Máximo 10mg/día en ancianos; ISRS más selectivo y mejor tolerado; monitorear sodio'},
    mechanism: {'pt': 'Isômero S do citalopram; inibe seletivamente o transportador de serotonina (SERT) com mínima ação em outros receptores; maior seletividade e menos efeitos adversos que racemato', 'es': 'Isómero S del citalopram; inhibe selectivamente el transportador de serotonina (SERT) con mínima acción en otros receptores; mayor selectividad y menos efectos adversos que racemato'},
    warning: {'pt': 'QT prolongado dose-dependente (máx 20mg/dia em adultos; 10mg em idosos/hepatopatas); evitar com outros fármacos que prolongam QT; síndrome de descontinuação', 'es': 'QT prolongado dosis-dependiente (máx 20mg/día en adultos; 10mg en ancianos/hepatópatas); evitar con otros fármacos que prolongan QT; síndrome de discontinuación'},
    adverse: {
      'pt': ['Náusea', 'Insônia/sonolência', 'Cefaleia', 'Boca seca', 'Sudorese', 'Disfunção sexual', 'QT prolongado (altas doses)'],
      'es': ['Náusea', 'Insomnio/somnolencia', 'Cefalea', 'Boca seca', 'Sudoración', 'Disfunción sexual', 'QT prolongado (dosis altas)'],
    },
  ),

  DrugModel(
    id: 'mirtazapina',
    group: 'Neurología y Psiquiatría',
    name: 'Mirtazapina',
    className: {'pt': 'Antidepressivo NaSSA (Antagonista Noradrenérgico e Serotoninérgico Específico)', 'es': 'Antidepresivo NaSSA (Antagonista Noradrenérgico y Serotoninérgico Específico)'},
    category: {'pt': 'Psiquiatria', 'es': 'Psiquiatría'},
    route: 'Oral',
    doseType: 'fixed',
    fixedDose: {'pt': '15mg/noite; pode ↑ até 45mg/dia; paradoxalmente mais sedativo em doses menores', 'es': '15mg/noche; puede ↑ hasta 45mg/día; paradójicamente más sedante a dosis menores'},
    frequency: {'pt': '1x/dia (noite)', 'es': '1 vez/día (noche)'},
    renalAlert: {'pt': 'Reduzir dose em insuficiência renal grave; clearance reduzido 30–50%', 'es': 'Reducir dosis en insuficiencia renal grave; clearance reducido 30–50%'},
    elderlyAlert: {'pt': 'Útil em idosos com insônia, perda de peso ou ansiedade; monitorar leucopenia', 'es': 'Útil en ancianos con insomnio, pérdida de peso o ansiedad; monitorear leucopenia'},
    mechanism: {'pt': 'Bloqueia receptores α2 pré-sinápticos (↑ liberação NE e 5-HT), receptores 5-HT2 e 5-HT3 (reduz náusea e efeitos sexuais), e H1 (sedação e ganho de peso); sem inibição de recaptura', 'es': 'Bloquea receptores α2 presinápticos (↑ liberación NE y 5-HT), receptores 5-HT2 y 5-HT3 (reduce náusea y efectos sexuales), y H1 (sedación y ganancia de peso); sin inhibición de recaptación'},
    warning: {'pt': 'Agranulocitose (rara mas grave — monitorar infecções febris); ganho de peso substancial; sedação pronunciada; não combinar com MAOIs; síndrome serotoninérgica possível', 'es': 'Agranulocitosis (rara pero grave — monitorear infecciones febriles); ganancia de peso sustancial; sedación pronunciada; no combinar con MAOIs; síndrome serotoninérgico posible'},
    adverse: {
      'pt': ['Sedação/sonolência (muito comum)', 'Ganho de peso (muito comum)', 'Aumento do apetite', 'Boca seca', 'Constipação', 'Agranulocitose (raro)', 'Edema'],
      'es': ['Sedación/somnolencia (muy común)', 'Aumento de peso (muy común)', 'Aumento del apetito', 'Boca seca', 'Estreñimiento', 'Agranulocitosis (raro)', 'Edema'],
    },
  ),

  DrugModel(
    id: 'zolpidem',
    group: 'Neurología y Psiquiatría',
    name: 'Zolpidem',
    className: {'pt': 'Hipnótico não-benzodiazepínico (Fármaco-Z)', 'es': 'Hipnótico no benzodiacepínico (Fármaco-Z)'},
    category: {'pt': 'Psiquiatria / Neurologia', 'es': 'Psiquiatría / Neurología'},
    route: 'Oral / SL',
    doseType: 'fixed',
    fixedDose: {'pt': 'Homens: 10mg; Mulheres: 5mg; LP: 6,25–12,5mg; tomar imediatamente antes de dormir', 'es': 'Hombres: 10mg; Mujeres: 5mg; LP: 6,25–12,5mg; tomar inmediatamente antes de dormir'},
    frequency: {'pt': '1x/dia (ao deitar)', 'es': '1 vez/día (al acostarse)'},
    renalAlert: {'pt': 'Reduzir para 5mg em insuficiência renal; maior sedação residual', 'es': 'Reducir a 5mg en insuficiencia renal; mayor sedación residual'},
    elderlyAlert: {'pt': 'Máximo 5mg; alto risco de queda, confusão e amnésia; incluído na lista de Beers (evitar)', 'es': 'Máximo 5mg; alto riesgo de caída, confusión y amnesia; incluido en lista de Beers (evitar)'},
    mechanism: {'pt': 'Agonista seletivo do receptor GABA-A com subunidade α1 (hipnótico); menor ação nas subunidades α2/α3 (ansiolítico, relaxamento muscular); meia-vida curta (2–3h)', 'es': 'Agonista selectivo del receptor GABA-A con subunidad α1 (hipnótico); menor acción en subunidades α2/α3 (ansiolítico, relajación muscular); vida media corta (2–3h)'},
    warning: {'pt': 'Risco de dependência e tolerância; comportamentos complexos durante sono (sonambulismo, direção); amnésia anterógrada; contraindicado em apneia do sono grave; uso máximo recomendado: 4 semanas', 'es': 'Riesgo de dependencia y tolerancia; comportamientos complejos durante sueño (sonambulismo, conducción); amnesia anterógrada; contraindicado en apnea del sueño grave; uso máximo recomendado: 4 semanas'},
    adverse: {
      'pt': ['Sonolência residual (efeito ressaca)', 'Tontura', 'Cefaleia', 'Amnésia anterógrada', 'Comportamentos complexos durante sono', 'Dependência', 'Queda (idosos)'],
      'es': ['Somnolencia residual (efecto resaca)', 'Mareo', 'Cefalea', 'Amnesia anterógrada', 'Comportamientos complejos durante sueño', 'Dependencia', 'Caída (ancianos)'],
    },
  ),

  DrugModel(
    id: 'biperideno',
    group: 'Neurología y Psiquiatría',
    name: 'Biperideno',
    className: {'pt': 'Anticolinérgico — Antiparkinsônico', 'es': 'Anticolinérgico — Antiparkinsónico'},
    category: {'pt': 'Neurologia / Psiquiatria', 'es': 'Neurología / Psiquiatría'},
    route: 'Oral / IM / IV',
    doseType: 'fixed',
    fixedDose: {'pt': 'Sintomas extrapiramidais: 2mg VO 2–3x/dia; Crise aguda distônica: 2,5–5mg IM/IV (pode repetir após 30 min)', 'es': 'Síntomas extrapiramidales: 2mg VO 2–3 veces/día; Crisis distónica aguda: 2,5–5mg IM/IV (puede repetir tras 30 min)'},
    frequency: {'pt': '2–3x/dia (oral)', 'es': '2–3 veces/día (oral)'},
    renalAlert: {'pt': 'Usar com cautela em insuficiência renal; acúmulo possível', 'es': 'Usar con cautela en insuficiencia renal; acumulación posible'},
    elderlyAlert: {'pt': 'Evitar em idosos (lista de Beers) — confusão, retenção urinária, delirium; risco de piora cognitiva', 'es': 'Evitar en ancianos (lista de Beers) — confusión, retención urinaria, delirium; riesgo de deterioro cognitivo'},
    mechanism: {'pt': 'Bloqueia receptores muscarínicos M1 no SNC, restaurando o equilíbrio dopamina/acetilcolina nos gânglios basais; alivia rigidez, tremor e bradicinesia induzidos por antipsicóticos', 'es': 'Bloquea receptores muscarínicos M1 en SNC, restaurando el equilibrio dopamina/acetilcolina en ganglios basales; alivia rigidez, temblor y bradicinesia inducidos por antipsicóticos'},
    warning: {'pt': 'Potencial de abuso (efeitos euforizantes em altas doses); contraindicado em glaucoma de ângulo fechado, hipertrofia prostática, íleo paralítico; pode piorar psicose; evitar em idosos', 'es': 'Potencial de abuso (efectos euforizantes a dosis altas); contraindicado en glaucoma de ángulo cerrado, hipertrofia prostática, íleo paralítico; puede empeorar psicosis; evitar en ancianos'},
    adverse: {
      'pt': ['Boca seca', 'Visão turva', 'Constipação', 'Retenção urinária', 'Taquicardia', 'Confusão mental (idosos)', 'Sonolência', 'Diminuição sudorese'],
      'es': ['Boca seca', 'Visión borrosa', 'Estreñimiento', 'Retención urinaria', 'Taquicardia', 'Confusión mental (ancianos)', 'Somnolencia', 'Disminución sudoración'],
    },
  ),

  DrugModel(
    id: 'propiltiuracil',
    group: 'Endocrinología y Metabolismo',
    name: 'Propiltiuracil (PTU) / Propiltiouracilo (PTU)',
    className: {'pt': 'Antitireoidiano — Tionamida', 'es': 'Antitiroideo — Tionamida'},
    category: {'pt': 'Endocrinologia', 'es': 'Endocrinología'},
    route: 'Oral',
    doseType: 'fixed',
    fixedDose: {'pt': 'Hipertireoidismo leve-moderado: 100–150mg 3x/dia; Tempestade tireoidiana: 200–250mg a cada 4–6h; Manutenção: 50–150mg/dia', 'es': 'Hipertiroidismo leve-moderado: 100–150mg 3 veces/día; Tormenta tiroidea: 200–250mg cada 4–6h; Mantenimiento: 50–150mg/día'},
    frequency: {'pt': '2–4x/dia', 'es': '2–4 veces/día'},
    renalAlert: {'pt': 'Reduzir dose em insuficiência renal grave', 'es': 'Reducir dosis en insuficiencia renal grave'},
    elderlyAlert: {'pt': 'Monitorar hemograma e função hepática regularmente', 'es': 'Monitorear hemograma y función hepática regularmente'},
    mechanism: {'pt': 'Inibe a peroxidase tireoidiana, bloqueando a organificação do iodo e a síntese de T3/T4; também inibe a conversão periférica de T4 em T3 (vantagem em tempestade tireoidiana)', 'es': 'Inhibe la peroxidasa tiroidea, bloqueando la organificación del yodo y la síntesis de T3/T4; también inhibe la conversión periférica de T4 en T3 (ventaja en tormenta tiroidea)'},
    warning: {'pt': 'Risco de hepatotoxicidade fulminante (preferir metimazol exceto no 1º trimestre de gravidez e tempestade tireoidiana); agranulocitose (orientar paciente sobre febre/faringite); monitorar TFH; efeito anticoagulante (potencializa varfarina)', 'es': 'Riesgo de hepatotoxicidad fulminante (preferir metimazol excepto en 1° trimestre de embarazo y tormenta tiroidea); agranulocitosis (informar paciente sobre fiebre/faringitis); monitorear TFH; efecto anticoagulante (potencia warfarina)'},
    adverse: {
      'pt': ['Agranulocitose (0,3%)', 'Hepatotoxicidade (grave, mais que metimazol)', 'Rash cutâneo', 'Artralgia', 'Prurido', 'Náusea', 'ANCA-vasculite (crônico)'],
      'es': ['Agranulocitosis (0,3%)', 'Hepatotoxicidad (grave, más que metimazol)', 'Rash cutáneo', 'Artralgia', 'Prurito', 'Náusea', 'ANCA-vasculitis (crónico)'],
    },
  ),

  DrugModel(
    id: 'prednisona',
    group: 'Endocrinología y Metabolismo',
    name: 'Prednisona',
    className: {'pt': 'Corticosteroide Sistêmico — Glicocorticoide', 'es': 'Corticosteroide Sistémico — Glucocorticoide'},
    category: {'pt': 'Reumatologia / Imunologia', 'es': 'Reumatología / Inmunología'},
    route: 'Oral',
    doseType: 'fixed',
    fixedDose: {'pt': 'Doses variáveis: Anti-inflamatório: 5–15mg/dia | Imunossupressor: 0,5–1mg/kg/dia | Pulsoterapia oral: 1–2mg/kg/dia × 3–5 dias', 'es': 'Dosis variables: Antiinflamatorio: 5–15mg/día | Inmunosupresor: 0,5–1mg/kg/día | Pulsoterapia oral: 1–2mg/kg/día × 3–5 días'},
    frequency: {'pt': '1x/dia (pela manhã)', 'es': '1 vez/día (por la mañana)'},
    renalAlert: {'pt': 'Sem ajuste necessário; monitorar hipercalemia e retenção hídrica', 'es': 'Sin ajuste necesario; monitorear hipercalemia y retención hídrica'},
    elderlyAlert: {'pt': 'Maior risco de osteoporose, DM, infecções e miopatia; suplementar cálcio e vitamina D; gastroproteção necessária', 'es': 'Mayor riesgo de osteoporosis, DM, infecciones y miopatía; suplementar calcio y vitamina D; gastroprotección necesaria'},
    mechanism: {'pt': 'Pró-fármaco convertido em prednisolona ativa pelo fígado; liga-se ao receptor de glicocorticoide → translocação nuclear → inibe NF-κB e AP-1 → reduz síntese de citocinas pró-inflamatórias e fosfolipase A2', 'es': 'Profármaco convertido en prednisolona activa por el hígado; se une a receptor de glucocorticoide → translocación nuclear → inhibe NF-κB y AP-1 → reduce síntesis de citocinas proinflamatorias y fosfolipasa A2'},
    warning: {'pt': 'Evitar retirada abrupta após >2 semanas (insuficiência adrenal); monitorar glicemia, PA, densidade óssea; aumenta risco de infecções oportunistas; úlcera gástrica com AINEs; cataratas com uso prolongado', 'es': 'Evitar retirada abrupta tras >2 semanas (insuficiencia adrenal); monitorear glucemia, PA, densidad ósea; aumenta riesgo de infecciones oportunistas; úlcera gástrica con AINEs; cataratas con uso prolongado'},
    adverse: {
      'pt': ['Hiperglicemia', 'Hipertensão', 'Osteoporose', 'Supressão adrenal', 'Infecções oportunistas', 'Síndrome de Cushing iatrогênica', 'Miopatia', 'Psicose (doses altas)', 'Úlcera gástrica'],
      'es': ['Hiperglucemia', 'Hipertensión', 'Osteoporosis', 'Supresión adrenal', 'Infecciones oportunistas', 'Síndrome de Cushing iatrogénico', 'Miopatía', 'Psicosis (dosis altas)', 'Úlcera gástrica'],
    },
  ),

  DrugModel(
    id: 'metotrexato',
    group: 'Hematología y Vitaminas',
    name: 'Metotrexato',
    className: {'pt': 'Imunossupressor / Antimetabólito — Antagonista do Folato', 'es': 'Inmunosupresor / Antimetabolito — Antagonista del Folato'},
    category: {'pt': 'Reumatologia / Oncologia', 'es': 'Reumatología / Oncología'},
    route: 'Oral / SC / IM / IV',
    doseType: 'fixed',
    fixedDose: {'pt': 'AR/Psoríase: 7,5–25mg 1x/semana; Oncologia: doses muito mais altas (protocolo específico)', 'es': 'AR/Psoriasis: 7,5–25mg 1 vez/semana; Oncología: dosis mucho más altas (protocolo específico)'},
    frequency: {'pt': '1x/semana (reumatologia)', 'es': '1 vez/semana (reumatología)'},
    renalAlert: {'pt': 'Contraindicado se TFG <30mL/min; principal via de eliminação é renal; risco de toxicidade grave', 'es': 'Contraindicado si TFG <30mL/min; principal vía de eliminación es renal; riesgo de toxicidad grave'},
    elderlyAlert: {'pt': 'Reduzir dose; maior toxicidade hematológica e renal; monitorar mais frequentemente', 'es': 'Reducir dosis; mayor toxicidad hematológica y renal; monitorear más frecuentemente'},
    mechanism: {'pt': 'Inibe dihidrofolato redutase (DHFR), bloqueando síntese de nucleotídeos e reduzindo proliferação celular; em baixas doses (reumatologia), efeito imunomodulador via acúmulo de adenosina', 'es': 'Inhibe dihidrofolato reductasa (DHFR), bloqueando síntesis de nucleótidos y reduciendo proliferación celular; a bajas dosis (reumatología), efecto inmunomodulador vía acumulación de adenosina'},
    warning: {'pt': 'SEMPRE suplementar ácido fólico (5mg/semana no dia seguinte ao metotrexato); monitorar hemograma, TFH, creatinina mensalmente; teratogênico (evitar gravidez durante e 3 meses após); hepatotoxicidade com álcool; evitar AINEs (↑ toxicidade)', 'es': 'SIEMPRE suplementar ácido fólico (5mg/semana al día siguiente del metotrexato); monitorear hemograma, TFH, creatinina mensualmente; teratogénico (evitar embarazo durante y 3 meses después); hepatotoxicidad con alcohol; evitar AINEs (↑ toxicidad)'},
    adverse: {
      'pt': ['Náusea/vômito (pior sem folato)', 'Estomatite/mucosite', 'Hepatotoxicidade', 'Fibrose hepática', 'Leucopenia', 'Pneumonite (hipersensibilidade)', 'Teratogenicidade', 'Nefrotoxicidade (altas doses)'],
      'es': ['Náusea/vómito (peor sin folato)', 'Estomatitis/mucositis', 'Hepatotoxicidad', 'Fibrosis hepática', 'Leucopenia', 'Neumonitis (hipersensibilidad)', 'Teratogenicidad', 'Nefrotoxicidad (dosis altas)'],
    },
  ),

  DrugModel(
    id: 'desloratadina',
    group: 'Varios / Antídotos / Otros',
    name: 'Desloratadina',
    className: {'pt': 'Anti-histamínico H1 de 3ª Geração (Não-sedativo)', 'es': 'Antihistamínico H1 de 3ª Generación (No sedante)'},
    category: {'pt': 'Alergologia', 'es': 'Alergología'},
    route: 'Oral',
    doseType: 'fixed',
    fixedDose: {'pt': '5mg 1x/dia', 'es': '5mg 1 vez/día'},
    frequency: {'pt': '1x/dia', 'es': '1 vez/día'},
    renalAlert: {'pt': 'Reduzir para 5mg em dias alternados em insuficiência renal grave', 'es': 'Reducir a 5mg en días alternos en insuficiencia renal grave'},
    elderlyAlert: {'pt': 'Preferível a anti-histamínicos sedativos; sem ajuste de dose necessário', 'es': 'Preferible a antihistamínicos sedantes; sin ajuste de dosis necesario'},
    mechanism: {'pt': 'Metabólito ativo da loratadina; antagonista seletivo e periférico do receptor H1; mínima penetração na BHE; sem efeito anticolinérgico significativo; semi-vida longa (27h)', 'es': 'Metabolito activo de loratadina; antagonista selectivo y periférico del receptor H1; mínima penetración en BHE; sin efecto anticolinérgico significativo; semivida larga (27h)'},
    warning: {'pt': 'Muito bem tolerado; raro QT prolongado em doses elevadas; evitar na gravidez (categoria C)', 'es': 'Muy bien tolerado; raro QT prolongado en dosis elevadas; evitar en embarazo (categoría C)'},
    adverse: {
      'pt': ['Cefaleia (rara)', 'Náusea (rara)', 'Boca seca (leve)', 'Fadiga (ocasional)', 'Sonolência mínima'],
      'es': ['Cefalea (rara)', 'Náusea (rara)', 'Boca seca (leve)', 'Fatiga (ocasional)', 'Somnolencia mínima'],
    },
  ),

  DrugModel(
    id: 'hidroxizina',
    group: 'Varios / Antídotos / Otros',
    name: 'Hidroxizina',
    className: {'pt': 'Anti-histamínico H1 de 1ª Geração / Ansiolítico', 'es': 'Antihistamínico H1 de 1ª Generación / Ansiolítico'},
    category: {'pt': 'Alergologia / Psiquiatria', 'es': 'Alergología / Psiquiatría'},
    route: 'Oral / IM',
    doseType: 'fixed',
    fixedDose: {'pt': 'Prurido: 25mg 3–4x/dia | Ansiedade: 50–100mg 4x/dia | Pré-anestesia: 50–100mg IM', 'es': 'Prurito: 25mg 3–4 veces/día | Ansiedad: 50–100mg 4 veces/día | Preanestesia: 50–100mg IM'},
    frequency: {'pt': '3–4x/dia', 'es': '3–4 veces/día'},
    renalAlert: {'pt': 'Reduzir dose e intervalos em insuficiência renal; cetoconazol acumula (metabólito)', 'es': 'Reducir dosis e intervalos en insuficiencia renal; cetoconazol se acumula (metabolito)'},
    elderlyAlert: {'pt': 'Evitar (lista de Beers); risco de confusão, sedação excessiva, quedas, retenção urinária', 'es': 'Evitar (lista de Beers); riesgo de confusión, sedación excesiva, caídas, retención urinaria'},
    mechanism: {'pt': 'Antagonista H1 com alta penetração no SNC (sedação); também ação anticolinérgica, antiespasmódica e antiserotoninérgica; mecanismo ansiolítico parcialmente explicado pela ação nos receptores 5-HT2A', 'es': 'Antagonista H1 con alta penetración en SNC (sedación); también acción anticolinérgica, antiespasmódica y antiserotonérgica; mecanismo ansiolítico parcialmente explicado por acción en receptores 5-HT2A'},
    warning: {'pt': 'QT prolongado dose-dependente; sedação excessiva; evitar com outros depressores do SNC; não recomendado na gestação (teratogênico em alguns estudos animais)', 'es': 'QT prolongado dosis-dependiente; sedación excesiva; evitar con otros depresores del SNC; no recomendado en gestación (teratogénico en algunos estudios animales)'},
    adverse: {
      'pt': ['Sedação (intensa)', 'Boca seca', 'Tontura', 'Visão turva', 'Constipação', 'Retenção urinária', 'QT prolongado', 'Confusão (idosos)'],
      'es': ['Sedación (intensa)', 'Boca seca', 'Mareo', 'Visión borrosa', 'Estreñimiento', 'Retención urinaria', 'QT prolongado', 'Confusión (ancianos)'],
    },
  ),

  DrugModel(
    id: 'lidocaina',
    group: 'UCI – Críticos y Sedoanalgesia',
    name: 'Lidocaína',
    className: {'pt': 'Anestésico Local / Antiarrítmico Classe IB', 'es': 'Anestésico Local / Antiarrítmico Clase IB'},
    category: {'pt': 'Emergência / Anestesiologia', 'es': 'Emergencia / Anestesiología'},
    route: 'IV / IM / SC / Tópica',
    doseType: 'mg_kg',
    mgKg: 1.5,
    fixedDose: {'pt': 'Arritmia ventricular: 1–1,5mg/kg IV bolus; manutenção 1–4mg/min | Anestesia local: concentração 0,5–2%, dose máxima 4,5mg/kg (sem adrenalina) / 7mg/kg (com adrenalina)', 'es': 'Arritmia ventricular: 1–1,5mg/kg IV bolo; mantenimiento 1–4mg/min | Anestesia local: concentración 0,5–2%, dosis máxima 4,5mg/kg (sin adrenalina) / 7mg/kg (con adrenalina)'},
    frequency: {'pt': 'Infusão contínua ou dose única (contexto dependente)', 'es': 'Infusión continua o dosis única (según contexto)'},
    renalAlert: {'pt': 'Acúmulo de metabólitos (MEGX); monitorar sinais de toxicidade', 'es': 'Acumulación de metabolitos (MEGX); monitorear signos de toxicidad'},
    elderlyAlert: {'pt': 'Reduzir velocidade de infusão; maior sensibilidade a toxicidade do SNC', 'es': 'Reducir velocidad de infusión; mayor sensibilidad a toxicidad del SNC'},
    mechanism: {'pt': 'Bloqueia canais de sódio voltagem-dependentes (estado aberto/inativado), impedindo despolarização da membrana; ação anestésica local e antiarrítmica; início rápido de ação (1–2 min IV)', 'es': 'Bloquea canales de sodio voltaje-dependientes (estado abierto/inactivado), impidiendo despolarización de membrana; acción anestésica local y antiarrítmica; inicio rápido de acción (1–2 min IV)'},
    warning: {'pt': 'Toxicidade sistêmica: progressão SNC→CV: tinido, gosto metálico → convulsões → colapso CV; tratar com lipid emulsion 20% (Intralipid); verificar dose máxima rigorosamente na anestesia local; evitar em bloqueio AV avançado', 'es': 'Toxicidad sistémica: progresión SNC→CV: tinnitus, sabor metálico → convulsiones → colapso CV; tratar con emulsión lipídica 20% (Intralipid); verificar dosis máxima rigurosamente en anestesia local; evitar en bloqueo AV avanzado'},
    adverse: {
      'pt': ['Toxicidade SNC: tinido, visão turva, convulsões', 'Toxicidade CV: bradicardia, hipotensão, parada cardíaca', 'Metemoglobinemia (prilocaína — mais)', 'Reação alérgica (amino-amidas — rara)', 'Bloqueio motor excessivo'],
      'es': ['Toxicidad SNC: tinnitus, visión borrosa, convulsiones', 'Toxicidad CV: bradicardia, hipotensión, paro cardíaco', 'Metahemoglobinemia (prilocaína — más)', 'Reacción alérgica (amino-amidas — rara)', 'Bloqueo motor excesivo'],
    },
  ),

  DrugModel(
    id: 'carvao_ativado',
    group: 'Varios / Antídotos / Otros',
    name: 'Carvão Ativado / Carbón Activado',
    className: {'pt': 'Adsorvente — Antídoto Geral', 'es': 'Adsorbente — Antídoto General'},
    category: {'pt': 'Toxicologia / Emergência', 'es': 'Toxicología / Emergencia'},
    route: 'Oral / SNE',
    doseType: 'mg_kg',
    mgKg: 1.0,
    fixedDose: {'pt': 'Adulto: 50–100g; Criança: 1g/kg; Doses múltiplas: 25–50g a cada 4–6h (fármacos de ciclo entero-hepático)', 'es': 'Adulto: 50–100g; Niño: 1g/kg; Dosis múltiples: 25–50g cada 4–6h (fármacos de ciclo enterohepático)'},
    frequency: {'pt': 'Dose única ou múltiplas (dependendo da indicação)', 'es': 'Dosis única o múltiples (según indicación)'},
    renalAlert: {'pt': 'Sem restrição renal; não absorvido sistemicamente', 'es': 'Sin restricción renal; no absorbido sistémicamente'},
    elderlyAlert: {'pt': 'Risco de aspiração aumentado; considerar proteção de vias aéreas antes da administração', 'es': 'Riesgo de aspiración aumentado; considerar protección de vías aéreas antes de la administración'},
    mechanism: {'pt': 'Adsorve substâncias tóxicas no trato gastrointestinal por ligação não-covalente em sua superfície porosa, impedindo absorção sistêmica; área superficial ~1000m²/g', 'es': 'Adsorbe sustancias tóxicas en el tracto gastrointestinal por unión no covalente en su superficie porosa, impidiendo absorción sistémica; área superficial ~1000m²/g'},
    warning: {'pt': 'Contraindicado quando vias aéreas não protegidas (risco de aspiração grave); NÃO eficaz para: metais pesados (ferro, lítio, chumbo), álcoois (etanol, metanol, etilenoglicol), cáusticos; janela terapêutica: ≤1–2h da ingestão (idealmente ≤1h)', 'es': 'Contraindicado cuando vías aéreas no protegidas (riesgo de aspiración grave); NO eficaz para: metales pesados (hierro, litio, plomo), alcoholes (etanol, metanol, etilenglicol), cáusticos; ventana terapéutica: ≤1–2h de la ingestión (idealmente ≤1h)'},
    adverse: {
      'pt': ['Vômito (pode piorar aspiração)', 'Aspiração pulmonar (grave)', 'Constipação/bezoar (doses múltiplas)', 'Fezes pretas (confundir com melena)', 'Aspiração de carvão (hipoxia)'],
      'es': ['Vómito (puede empeorar aspiración)', 'Aspiración pulmonar (grave)', 'Estreñimiento/bezoar (dosis múltiples)', 'Heces negras (confundir con melena)', 'Aspiración de carbón (hipoxia)'],
    },
  ),

  DrugModel(
    id: 'nistatina',
    group: 'Infectología (Antifúngicos / Antivirales / TBC)',
    name: 'Nistatina',
    className: {'pt': 'Antifúngico Poliênico (Uso Tópico/Oral)', 'es': 'Antifúngico Poliénico (Uso Tópico/Oral)'},
    category: {'pt': 'Infectologia', 'es': 'Infectología'},
    route: 'Oral (suspensão/comprimido) / Tópica (creme/pomada)',
    doseType: 'fixed',
    fixedDose: {'pt': 'Candidíase oral: 100.000–500.000 UI 4x/dia (suspensão "bochechar e engolir") | Candidíase vaginal: 100.000 UI/g creme vaginal 1–2x/dia × 14 dias | Candidíase cutânea: creme 100.000 UI/g 2–3x/dia', 'es': 'Candidiasis oral: 100.000–500.000 UI 4 veces/día (suspensión "enjuagar y tragar") | Candidiasis vaginal: 100.000 UI/g crema vaginal 1–2 veces/día × 14 días | Candidiasis cutánea: crema 100.000 UI/g 2–3 veces/día'},
    frequency: {'pt': '2–4x/dia', 'es': '2–4 veces/día'},
    renalAlert: {'pt': 'Não absorvida sistemicamente — sem restrições renais', 'es': 'No absorbida sistémicamente — sin restricciones renales'},
    elderlyAlert: {'pt': 'Segura para uso em idosos; boa opção para candidíase oral associada a próteses dentárias', 'es': 'Segura para uso en ancianos; buena opción para candidiasis oral asociada a prótesis dentales'},
    mechanism: {'pt': 'Liga-se ao ergosterol da membrana fúngica, formando poros que causam extravasamento de conteúdo intracelular e morte da célula; mínima absorção gastrointestinal', 'es': 'Se une al ergosterol de la membrana fúngica, formando poros que causan extravasación del contenido intracelular y muerte celular; mínima absorción gastrointestinal'},
    warning: {'pt': 'Uso apenas local (não absorvida); tratamento por no mínimo 48h após resolução dos sintomas; verificar causas subjacentes de candidíase recorrente (imunossupressão, DM, uso de antibióticos)', 'es': 'Uso solo local (no absorbida); tratamiento por mínimo 48h tras resolución de síntomas; verificar causas subyacentes de candidiasis recurrente (inmunosupresión, DM, uso de antibióticos)'},
    adverse: {
      'pt': ['Náusea/vômito (oral)', 'Diarreia (oral)', 'Irritação local (tópica)', 'Reação alérgica (rara)', 'Sabor desagradável (suspensão)'],
      'es': ['Náusea/vómito (oral)', 'Diarrea (oral)', 'Irritación local (tópica)', 'Reacción alérgica (rara)', 'Sabor desagradable (suspensión)'],
    },
  ),

  DrugModel(
    id: 'carbonato_calcio',
    group: 'Endocrinología y Metabolismo',
    name: 'Carbonato de Cálcio / Carbonato de Calcio',
    className: {'pt': 'Suplemento Mineral / Antiácido', 'es': 'Suplemento Mineral / Antiácido'},
    category: {'pt': 'Gastroenterologia / Endocrinologia', 'es': 'Gastroenterología / Endocrinología'},
    route: 'Oral',
    doseType: 'fixed',
    fixedDose: {'pt': 'Suplementação: 500–1500mg de cálcio elementar/dia (cada 1250mg CaCO3 = 500mg Ca²⁺) | Antiácido: 0,5–1,5g conforme necessário | Quelante de fósforo (DRC): 500–1000mg com as refeições', 'es': 'Suplementación: 500–1500mg de calcio elemental/día (cada 1250mg CaCO3 = 500mg Ca²⁺) | Antiácido: 0,5–1,5g según necesidad | Quelante de fósforo (ERC): 500–1000mg con las comidas'},
    frequency: {'pt': '2–3x/dia (com refeições para melhor absorção)', 'es': '2–3 veces/día (con comidas para mejor absorción)'},
    renalAlert: {'pt': 'Útil como quelante de fósforo em DRC; monitorar hipercalcemia; cautela em hipercalciúria', 'es': 'Útil como quelante de fósforo en ERC; monitorear hipercalcemia; cautela en hipercalciuria'},
    elderlyAlert: {'pt': 'Suplementar com vitamina D3 (1000–2000 UI/dia) para melhor absorção; monitorar função renal e cálcio sérico', 'es': 'Suplementar con vitamina D3 (1000–2000 UI/día) para mejor absorción; monitorear función renal y calcio sérico'},
    mechanism: {'pt': 'Fornece cálcio elementar essencial para formação óssea, contração muscular, coagulação e neurotransmissão; como antiácido, neutraliza o HCl gástrico; como quelante, liga-se ao fósforo dietético impedindo absorção', 'es': 'Proporciona calcio elemental esencial para formación ósea, contracción muscular, coagulación y neurotransmisión; como antiácido, neutraliza el HCl gástrico; como quelante, se une al fósforo dietético impidiendo su absorción'},
    warning: {'pt': 'Melhor absorção em meio ácido — tomar com alimentos; interação com ferro, ciprofloxacino, tiroxina (espaçar 2h); hipercalcemia com altas doses; síndrome leite-álcali (altas doses + leite)', 'es': 'Mejor absorción en medio ácido — tomar con alimentos; interacción con hierro, ciprofloxacino, tiroxina (espaciar 2h); hipercalcemia con dosis altas; síndrome leche-álcali (dosis altas + leche)'},
    adverse: {
      'pt': ['Constipação (frequente)', 'Gases/distensão', 'Hipercalcemia (doses excessivas)', 'Nefrolitíase (uso crônico excessivo)', 'Síndrome leite-álcali', 'Interações medicamentosas'],
      'es': ['Estreñimiento (frecuente)', 'Gases/distensión', 'Hipercalcemia (dosis excesivas)', 'Nefrolitiasis (uso crónico excesivo)', 'Síndrome leche-álcali', 'Interacciones medicamentosas'],
    },
  ),

  DrugModel(
    id: 'albumina',
    group: 'Endocrinología y Metabolismo',
    name: 'Albumina Humana / Albúmina Humana',
    className: {'pt': 'Expansor Plasmático — Coloide Natural', 'es': 'Expansor Plasmático — Coloide Natural'},
    category: {'pt': 'Emergência / Hepatologia', 'es': 'Emergencia / Hepatología'},
    route: 'IV',
    doseType: 'fixed',
    fixedDose: {'pt': 'Paracentese (>5L): 6–8g por litro removido (albumina 20%) | PBE (profilaxia IRA): 1,5g/kg no D1 + 1g/kg no D3 | Síndrome hepatorrenal: 1g/kg/dia | Hipoalbuminemia sintomática: 0,5–1g/kg', 'es': 'Paracentesis (>5L): 6–8g por litro removido (albúmina 20%) | PBE (profilaxia IRA): 1,5g/kg en D1 + 1g/kg en D3 | Síndrome hepatorrenal: 1g/kg/día | Hipoalbuminemia sintomática: 0,5–1g/kg'},
    frequency: {'pt': 'Conforme indicação clínica', 'es': 'Según indicación clínica'},
    renalAlert: {'pt': 'Monitorar sobrecarga hídrica em DRC; utilizar com cautela em anúria', 'es': 'Monitorear sobrecarga hídrica en ERC; usar con cautela en anuria'},
    elderlyAlert: {'pt': 'Infusão lenta; monitorar sobrecarga cardíaca; maior risco de edema pulmonar', 'es': 'Infusión lenta; monitorear sobrecarga cardíaca; mayor riesgo de edema pulmonar'},
    mechanism: {'pt': 'Proteína oncótica plasmática que mantém a pressão coloidosmótica intravascular; transportador de diversas substâncias (bilirrubina, ácidos graxos, fármacos); papel anti-inflamatório e antioxidante; meia-vida ~19 dias', 'es': 'Proteína oncótica plasmática que mantiene la presión coloidosmótica intravascular; transportador de diversas sustancias (bilirrubina, ácidos grasos, fármacos); papel antiinflamatorio y antioxidante; semivida ~19 días'},
    warning: {'pt': 'Não usar para corrigir hipoalbuminemia assintomática crônica (custo-benefício ruim); produto derivado de plasma humano (risco teórico de transmissão viral — ultrapasteurizado); contraindicado em anemia grave e ICC descompensada', 'es': 'No usar para corregir hipoalbuminemia asintomática crónica (mala relación costo-beneficio); producto derivado de plasma humano (riesgo teórico de transmisión viral — ultrapasteurizado); contraindicado en anemia grave e ICC descompensada'},
    adverse: {
      'pt': ['Sobrecarga hídrica/edema pulmonar', 'Febre/calafrios', 'Náusea', 'Urticária/rash', 'Reação anafilactoide (rara)', 'Hipotensão (infusão rápida)'],
      'es': ['Sobrecarga hídrica/edema pulmonar', 'Fiebre/escalofríos', 'Náusea', 'Urticaria/rash', 'Reacción anafilactoide (rara)', 'Hipotensión (infusión rápida)'],
    },
  ),

  DrugModel(
    id: 'piridoxina',
    group: 'Hematología y Vitaminas',
    name: 'Piridoxina (Vitamina B6)',
    className: {'pt': 'Vitamina / Antídoto', 'es': 'Vitamina / Antídoto'},
    category: {'pt': 'Toxicologia / Nutrição', 'es': 'Toxicología / Nutrición'},
    route: 'Oral / IV / IM',
    doseType: 'fixed',
    fixedDose: {'pt': 'Intoxicação por isoniazida: 1g IV para cada grama de INH ingerida (máx 5g se dose desconhecida) | Suplementação: 10–50mg/dia | Profilaxia neuropatia por INH: 25–50mg/dia | Hiperêmese gravídica: 10–25mg 3–4x/dia', 'es': 'Intoxicación por isoniazida: 1g IV por cada gramo de INH ingerida (máx 5g si dosis desconocida) | Suplementación: 10–50mg/día | Profilaxis neuropatía por INH: 25–50mg/día | Hiperémesis gravídica: 10–25mg 3–4 veces/día'},
    frequency: {'pt': '1–4x/dia (dependendo da indicação)', 'es': '1–4 veces/día (según indicación)'},
    renalAlert: {'pt': 'Sem restrições significativas; ajuste em DRC grave', 'es': 'Sin restricciones significativas; ajuste en ERC grave'},
    elderlyAlert: {'pt': 'Segura; monitorar neuropatia periférica em altas doses prolongadas', 'es': 'Segura; monitorear neuropatía periférica a dosis altas prolongadas'},
    mechanism: {'pt': 'Cofator essencial em mais de 100 reações enzimáticas (transaminações, descarboxilações, síntese de neurotransmissores); na intoxicação por isoniazida, restaura os níveis de GABA reduzidos pela INH que inibe glutamato descarboxilase', 'es': 'Cofactor esencial en más de 100 reacciones enzimáticas (transaminaciones, descarboxilaciones, síntesis de neurotransmisores); en intoxicación por isoniazida, restaura niveles de GABA reducidos por INH que inhibe glutamato descarboxilasa'},
    warning: {'pt': 'Neuropatia periférica sensorial com doses >200mg/dia crônicas; Na intoxicação por INH: tratar ANTES da benzodiazepina para convulsões; doses terapêuticas para gestantes são seguras', 'es': 'Neuropatía periférica sensorial con dosis >200mg/día crónicas; En intoxicación por INH: tratar ANTES del benzodiacepínico para convulsiones; dosis terapéuticas para gestantes son seguras'},
    adverse: {
      'pt': ['Neuropatia sensitiva (doses >200mg/dia crônicas)', 'Fotossensibilidade (raro)', 'Náusea (altas doses)', 'Acne (raro)'],
      'es': ['Neuropatía sensitiva (dosis >200mg/día crónicas)', 'Fotosensibilidad (raro)', 'Náusea (dosis altas)', 'Acné (raro)'],
    },
  ),

  DrugModel(
    id: 'sulfadiazina_prata',
    group: 'Varios / Antídotos / Otros',
    name: 'Sulfadiazina de Prata / Sulfadiazina de Plata',
    className: {'pt': 'Antibacteriano Tópico — Sulfonamida + Prata', 'es': 'Antibacteriano Tópico — Sulfonamida + Plata'},
    category: {'pt': 'Dermatologia / Queimados', 'es': 'Dermatología / Quemados'},
    route: 'Tópica',
    doseType: 'fixed',
    fixedDose: {'pt': 'Creme 1%: aplicar camada de 2–4mm sobre área afetada 1–2x/dia; limpar área antes de cada aplicação', 'es': 'Crema 1%: aplicar capa de 2–4mm sobre área afectada 1–2 veces/día; limpiar área antes de cada aplicación'},
    frequency: {'pt': '1–2x/dia', 'es': '1–2 veces/día'},
    renalAlert: {'pt': 'Absorção sistêmica possível em grandes áreas; monitorar função renal em queimaduras extensas', 'es': 'Absorción sistémica posible en grandes áreas; monitorear función renal en quemaduras extensas'},
    elderlyAlert: {'pt': 'Monitorar absorção em áreas extensas; risco de leucopenia', 'es': 'Monitorear absorción en áreas extensas; riesgo de leucopenia'},
    mechanism: {'pt': 'A sulfonamida inibe a síntese de folato bacteriano (PABA competição); os íons de prata causam desnaturação de proteínas bacterianas e DNA; amplo espectro antimicrobiano incluindo Pseudomonas aeruginosa', 'es': 'La sulfonamida inhibe la síntesis de folato bacteriano (competición con PABA); los iones de plata causan desnaturación de proteínas bacterianas y DNA; amplio espectro antimicrobiano incluyendo Pseudomonas aeruginosa'},
    warning: {'pt': 'Contraindicado em gestantes a termo, recém-nascidos <2 meses e hipersensibilidade a sulfonamidas; leucopenia transitória possível (monitorar); pode manchar tecidos de cor escura (normal)', 'es': 'Contraindicado en gestantes a término, recién nacidos <2 meses e hipersensibilidad a sulfonamidas; leucopenia transitoria posible (monitorear); puede manchar tejidos de color oscuro (normal)'},
    adverse: {
      'pt': ['Leucopenia transitória (2–3% de grandes áreas)', 'Argiria (impregnação por prata — uso prolongado)', 'Irritação local', 'Sensação de queimação', 'Rash cutâneo', 'Cristalúria (absorção sistêmica)'],
      'es': ['Leucopenia transitoria (2–3% de grandes áreas)', 'Argiria (impregnación por plata — uso prolongado)', 'Irritación local', 'Sensación de ardor', 'Rash cutáneo', 'Cristaluria (absorción sistémica)'],
    },
  ),

  DrugModel(
    id: 'mupirocina',
    group: 'Varios / Antídotos / Otros',
    name: 'Mupirocina',
    className: {'pt': 'Antibacteriano Tópico — Inibidor de Isoleucil-tRNA Sintetase', 'es': 'Antibacteriano Tópico — Inhibidor de Isoleucil-tRNA Sintetasa'},
    category: {'pt': 'Dermatologia', 'es': 'Dermatología'},
    route: 'Tópica (pele / intranasal)',
    doseType: 'fixed',
    fixedDose: {'pt': 'Impetigo/infecções de pele: 3x/dia × 5–10 dias | Descolonização MRSA nasal: pomada nasal 2x/dia × 5 dias', 'es': 'Impétigo/infecciones de piel: 3 veces/día × 5–10 días | Descolonización MRSA nasal: pomada nasal 2 veces/día × 5 días'},
    frequency: {'pt': '2–3x/dia', 'es': '2–3 veces/día'},
    renalAlert: {'pt': 'Absorção mínima; sem restrições renais significativas', 'es': 'Absorción mínima; sin restricciones renales significativas'},
    elderlyAlert: {'pt': 'Segura para uso tópico em idosos', 'es': 'Segura para uso tópico en ancianos'},
    mechanism: {'pt': 'Inibe reversivelmente a isoleucil-tRNA sintetase bacteriana, impedindo a síntese proteica; não tem equivalente humano — alta seletividade; ativo contra MRSA, S. aureus, Streptococcus', 'es': 'Inhibe reversiblemente la isoleucil-tRNA sintetasa bacteriana, impidiendo la síntesis proteica; no tiene equivalente humano — alta selectividad; activo contra MRSA, S. aureus, Streptococcus'},
    warning: {'pt': 'Uso apenas tópico (toxicidade sistêmica com polietilenoglicol-base se em grandes áreas/feridas abertas); não usar na mucosa ocular; resistência pode desenvolver com uso prolongado', 'es': 'Uso solo tópico (toxicidad sistémica con polietilenglicol-base si en grandes áreas/heridas abiertas); no usar en mucosa ocular; resistencia puede desarrollar con uso prolongado'},
    adverse: {
      'pt': ['Ardência/irritação local (leve)', 'Prurido local', 'Sensação de dor (nasal)', 'Rash (raro)', 'Cefaleia (uso nasal)'],
      'es': ['Ardor/irritación local (leve)', 'Prurito local', 'Sensación de dolor (nasal)', 'Rash (raro)', 'Cefalea (uso nasal)'],
    },
  ),

  DrugModel(
    id: 'permetrina',
    group: 'Varios / Antídotos / Otros',
    name: 'Permetrina',
    className: {'pt': 'Antiparasitário Tópico — Piretroide Sintético', 'es': 'Antiparasitario Tópico — Piretroide Sintético'},
    category: {'pt': 'Dermatologia / Parasitologia', 'es': 'Dermatología / Parasitología'},
    route: 'Tópica',
    doseType: 'fixed',
    fixedDose: {'pt': 'Escabiose (sarna): creme 5% — aplicar do pescoço aos pés, aguardar 8–14h, lavar; repetir após 7–14 dias | Pediculose (piolhos): loção/xampu 1% — aplicar, aguardar 10 min, enxaguar', 'es': 'Escabiosis (sarna): crema 5% — aplicar del cuello a los pies, esperar 8–14h, lavar; repetir tras 7–14 días | Pediculosis (piojos): loción/champú 1% — aplicar, esperar 10 min, enjuagar'},
    frequency: {'pt': 'Aplicação única (repetir se necessário após 7–14 dias)', 'es': 'Aplicación única (repetir si necesario tras 7–14 días)'},
    renalAlert: {'pt': 'Absorção sistêmica mínima; sem restrições renais', 'es': 'Absorción sistémica mínima; sin restricciones renales'},
    elderlyAlert: {'pt': 'Assistência na aplicação pode ser necessária; monitorar irritação cutânea', 'es': 'Asistencia en la aplicación puede ser necesaria; monitorear irritación cutánea'},
    mechanism: {'pt': 'Modifica a permeabilidade dos canais de sódio dos nervos dos artrópodes, causando prolongamento da despolarização → paralisia e morte dos parasitas; seletividade alta para insetos (temperatura corporal mais baixa)', 'es': 'Modifica la permeabilidad de los canales de sodio de los nervios de los artrópodos, causando prolongamiento de la despolarización → parálisis y muerte de los parásitos; alta selectividad para insectos (temperatura corporal más baja)'},
    warning: {'pt': 'Tratamento simultâneo de todos os comunicantes; lavar roupas de cama/vestuário com água quente; não usar em mucosas ou perto dos olhos; evitar em bebês <2 meses; resistência documentada', 'es': 'Tratamiento simultáneo de todos los comunicantes; lavar ropa de cama/vestimenta con agua caliente; no usar en mucosas ni cerca de ojos; evitar en bebés <2 meses; resistencia documentada'},
    adverse: {
      'pt': ['Ardência e prurido transitórios', 'Parestesia local', 'Eritema local', 'Edema local (raro)', 'Rash alérgico (raro)'],
      'es': ['Ardor y prurito transitorios', 'Parestesia local', 'Eritema local', 'Edema local (raro)', 'Rash alérgico (raro)'],
    },
  ),

  DrugModel(
    id: 'clobetasol',
    group: 'Varios / Antídotos / Otros',
    name: 'Clobetasol',
    className: {'pt': 'Corticosteroide Tópico de Alta Potência (Classe I)', 'es': 'Corticosteroide Tópico de Alta Potencia (Clase I)'},
    category: {'pt': 'Dermatologia', 'es': 'Dermatología'},
    route: 'Tópica',
    doseType: 'fixed',
    fixedDose: {'pt': 'Creme/pomada 0,05%: aplicar fina camada 1–2x/dia; duração máxima recomendada: 2–4 semanas; máximo 50g/semana', 'es': 'Crema/pomada 0,05%: aplicar capa fina 1–2 veces/día; duración máxima recomendada: 2–4 semanas; máximo 50g/semana'},
    frequency: {'pt': '1–2x/dia', 'es': '1–2 veces/día'},
    renalAlert: {'pt': 'Sem restrições renais para uso tópico breve; absorção sistêmica possível em grandes áreas', 'es': 'Sin restricciones renales para uso tópico breve; absorción sistémica posible en grandes áreas'},
    elderlyAlert: {'pt': 'Pele mais fina e maior absorção; usar duração mínima; monitorar atrofia cutânea', 'es': 'Piel más fina y mayor absorción; usar duración mínima; monitorear atrofia cutánea'},
    mechanism: {'pt': 'Liga-se a receptores glicocorticoides intracelulares na pele → translocação nuclear → supressão de NF-κB e citocinas pró-inflamatórias (IL-1, IL-6, TNF-α); vasoconstrição local; inibição de fosfolipase A2 (↓ prostaglandinas e leucotrienos)', 'es': 'Se une a receptores glucocorticoides intracelulares en la piel → translocación nuclear → supresión de NF-κB y citocinas proinflamatorias (IL-1, IL-6, TNF-α); vasoconstricción local; inhibición de fosfolipasa A2 (↓ prostaglandinas y leucotrienos)'},
    warning: {'pt': 'Potência muito alta — usar pelo menor tempo possível; NÃO usar em face, axilas, virilha, membranas mucosas; NÃO usar em infecções cutâneas não tratadas; absorção sistêmica causa supressão do eixo HHA com uso prolongado/extenso', 'es': 'Potencia muy alta — usar el menor tiempo posible; NO usar en cara, axilas, ingle, membranas mucosas; NO usar en infecciones cutáneas no tratadas; absorción sistémica causa supresión del eje HPA con uso prolongado/extenso'},
    adverse: {
      'pt': ['Atrofia cutânea', 'Estrias', 'Telangiectasias', 'Dermatite perioral (face)', 'Rosácea esteroidal', 'Supressão adrenal (uso extenso/prolongado)', 'Hipertricose', 'Dermatite de contato'],
      'es': ['Atrofia cutánea', 'Estrías', 'Telangiectasias', 'Dermatitis perioral (cara)', 'Rosácea esteroidal', 'Supresión adrenal (uso extenso/prolongado)', 'Hipertricosis', 'Dermatitis de contacto'],
    },
  ),

  DrugModel(
    id: 'propinoxato',
    group: 'Gastroenterología',
    name: 'Propinoxato',
    className: {'pt': 'Antiespasmódico / Anticolinérgico', 'es': 'Antiespasmódico / Anticolinérgico'},
    category: {'pt': 'Gastrointestinais', 'es': 'Gastrointestinales'},
    route: 'VO / IV / IM',
    doseType: 'fixed',
    fixedDose: {
      'pt': '10–20 mg a cada 6–8h. IV/IM: 10 mg (1 ampola) lento.',
      'es': '10–20 mg cada 6–8 h. IV/IM: 10 mg (1 ampolla) lento.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário, mas monitorar retenção urinária.',
      'es': 'Sin ajuste necesario, pero monitorear retención urinaria.',
    },
    elderlyAlert: {
      'pt': 'Risco de confusão mental, boca seca e retenção urinária (efeitos anticolinérgicos).',
      'es': 'Riesgo de confusión mental, boca seca y retención urinaria (efectos anticolinérgicos).',
    },
    mechanism: {
      'pt': 'Antagonista muscarínico e relaxante direto da musculatura lisa visceral.',
      'es': 'Antagonista muscarínico y relajante directo de la musculatura lisa visceral.',
    },
    warning: {
      'pt': 'Contraindicado em glaucoma de ângulo fechado e hipertrofia prostática.',
      'es': 'Contraindicado en glaucoma de ángulo cerrado e hipertrofia prostática.',
    },
    adverse: {
      'pt': ['Boca seca', 'Visão turva', 'Taquicardia', 'Constipação'],
      'es': ['Boca seca', 'Visión borrosa', 'Taquicardia', 'Constipación'],
    },
  ),

  DrugModel(
    id: 'pridinol',
    group: 'Neurología y Psiquiatría',
    name: 'Pridinol',
    className: {'pt': 'Relaxante muscular central', 'es': 'Relajante muscular central'},
    category: {'pt': 'Músculo-esquelético', 'es': 'Músculo-esquelético'},
    route: 'VO / IM',
    doseType: 'fixed',
    fixedDose: {
      'pt': '4 mg a cada 8–12h. Frequentemente associado ao Diclofenaco.',
      'es': '4 mg cada 8–12 h. Frecuentemente asociado al Diclofenaco.',
    },
    renalAlert: {
      'pt': 'Usar com precaução em insuficiência renal grave.',
      'es': 'Usar con precaución en insuficiencia renal grave.',
    },
    elderlyAlert: {
      'pt': 'Pode causar tontura e quedas. Efeitos anticolinérgicos potencializados.',
      'es': 'Puede causar mareos y caídas. Efectos anticolinérgicos potenciados.',
    },
    mechanism: {
      'pt': 'Ação miorrelaxante central via efeito anticolinérgico nos centros motores.',
      'es': 'Acción miorrelajante central vía efecto anticolinérgico en los centros motores.',
    },
    warning: {
      'pt': 'Evitar em casos de miastenia gravis.',
      'es': 'Evitar en casos de miastenia gravis.',
    },
    adverse: {
      'pt': ['Tontura', 'Fraqueza muscular', 'Boca seca', 'Sonolência'],
      'es': ['Mareos', 'Debilidad muscular', 'Boca seca', 'Somnolencia'],
    },
  ),

  DrugModel(
    id: 'meprednisona',
    group: 'Varios / Antídotos / Otros',
    name: 'Meprednisona',
    className: {'pt': 'Glicocorticoide', 'es': 'Glucocorticoide'},
    category: {'pt': 'Corticoides', 'es': 'Corticosteroides'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Adulto: 4–60 mg/dia conforme patologia. Pediatria: 0,5–2 mg/kg/dia.',
      'es': 'Adulto: 4–60 mg/día según patología. Pediatría: 0,5–2 mg/kg/día.',
    },
    renalAlert: {
      'pt': 'Geralmente seguro. Pode causar retenção hídrica.',
      'es': 'Generalmente seguro. Puede causar retención hídrica.',
    },
    elderlyAlert: {
      'pt': 'Monitorar glicemia e PA. Risco de osteoporose em uso crônico.',
      'es': 'Monitorear glucemia y PA. Riesgo de osteoporosis en uso crónico.',
    },
    mechanism: {
      'pt': 'Agonista dos receptores de glicocorticoides; inibe transcrição de citocinas inflamatórias.',
      'es': 'Agonista de los receptores de glucocorticoides; inhibe transcripción de citoquinas inflamatorias.',
    },
    warning: {
      'pt': 'Não interromper abruptamente se uso prolongado (risco de insuficiência adrenal).',
      'es': 'No suspender abruptamente si el uso es prolongado (riesgo de insuficiencia adrenal).',
    },
    adverse: {
      'pt': ['Hiperglicemia', 'Síndrome de Cushing', 'Insônia', 'Gastrite'],
      'es': ['Hiperglucemia', 'Síndrome de Cushing', 'Insomnio', 'Gastritis'],
    },
  ),

  DrugModel(
    id: 'labetalol',
    group: 'Cardiovascular y HTA',
    name: 'Labetalol',
    className: {'pt': 'Alfa e Beta bloqueador', 'es': 'Alfa y Beta bloqueante'},
    category: {'pt': 'Anti-hipertensivos', 'es': 'Antihipertensivos'},
    route: 'VO / IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'VO: 100–400 mg 2x/dia. IV bolo: 20 mg lento (2 min); repetir se necessário.',
      'es': 'VO: 100–400 mg 2 veces/día. IV bolo: 20 mg lento (2 min); repetir si necesario.',
    },
    renalAlert: {
      'pt': 'Ajuste não necessário na insuficiência renal.',
      'es': 'Ajuste no necesario en insuficiencia renal.',
    },
    elderlyAlert: {
      'pt': 'Risco elevado de hipotensão ortostática e bradicardia.',
      'es': 'Riesgo elevado de hipotensión ortostática y bradicardia.',
    },
    mechanism: {
      'pt': 'Bloqueio seletivo alfa-1 e não seletivo beta (proporção 1:7 IV).',
      'es': 'Bloqueo selectivo alfa-1 y no selectivo beta (proporción 1:7 IV).',
    },
    warning: {
      'pt': 'Contraindicado em asma, DPOC e bloqueios cardíacos 2º/3º grau.',
      'es': 'Contraindicado en asma, EPOC y bloqueos cardíacos de 2º/3º grado.',
    },
    adverse: {
      'pt': ['Hipotensão postural', 'Bradicardia', 'Broncoespasmo', 'Fadiga'],
      'es': ['Hipotensión postural', 'Bradicardia', 'Broncoespasmo', 'Fatiga'],
    },
  ),

  DrugModel(
    id: 'trimebutina',
    group: 'Gastroenterología',
    name: 'Trimebutina',
    className: {'pt': 'Modulador da motilidade gastrointestinal', 'es': 'Modulador de la motilidad gastrointestinal'},
    category: {'pt': 'Gastrointestinais', 'es': 'Gastrointestinales'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': '200 mg 3 vezes ao dia, antes das refeições.',
      'es': '200 mg 3 veces al día, antes de las comidas.',
    },
    renalAlert: {
      'pt': 'Sem dados de ajuste; usar com cautela em insuficiência grave.',
      'es': 'Sin datos de ajuste; usar con cautela en insuficiencia grave.',
    },
    elderlyAlert: {
      'pt': 'Geralmente bem tolerado.',
      'es': 'Generalmente bien tolerado.',
    },
    mechanism: {
      'pt': 'Agonista encefalinérgico periférico (receptores mu, delta e kappa); modula motilidade.',
      'es': 'Agonista encefalinérgico periférico (receptores mu, delta y kappa); modula motilidad.',
    },
    warning: {
      'pt': 'Uso seguro na maioria dos pacientes com Síndrome do Intestino Irritável.',
      'es': 'Uso seguro en la mayoría de los pacientes con Síndrome de Intestino Irritable.',
    },
    adverse: {
      'pt': ['Constipação', 'Diarreia', 'Boca seca', 'Tontura'],
      'es': ['Constipación', 'Diarrea', 'Boca seca', 'Mareos'],
    },
  ),

  DrugModel(
    id: 'cefadroxilo',
    group: 'Antibióticos',
    name: 'Cefadroxilo',
    className: {'pt': 'Cefalosporina de 1ª geração', 'es': 'Cefalosporina de 1ª generación'},
    category: {'pt': 'Antibióticos', 'es': 'Antibióticos'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Adulto: 500 mg–1 g a cada 12h. Pediatria: 30 mg/kg/dia em 1 ou 2 doses.',
      'es': 'Adulto: 500 mg–1 g cada 12 h. Pediatría: 30 mg/kg/día en 1 o 2 dosis.',
    },
    renalAlert: {
      'pt': 'ClCr <50 mL/min: aumentar intervalo para 24h.',
      'es': 'ClCr <50 mL/min: aumentar intervalo a 24 h.',
    },
    elderlyAlert: {
      'pt': 'Monitorar função renal para ajuste de dose.',
      'es': 'Monitorear función renal para ajuste de dosis.',
    },
    mechanism: {
      'pt': 'Inibe a síntese da parede celular bacteriana (betalactâmico).',
      'es': 'Inhibe la síntesis de la pared celular bacteriana (betalactámico).',
    },
    warning: {
      'pt': 'Reação cruzada em alérgicos à penicilina (5–10%).',
      'es': 'Reacción cruzada en alérgicos a penicilina (5–10%).',
    },
    adverse: {
      'pt': ['Diarreia', 'Náuseas', 'Exantema', 'Candidíase'],
      'es': ['Diarrea', 'Náuseas', 'Exantema', 'Candidiasis'],
    },
  ),

  DrugModel(
    id: 'etamsilato',
    group: 'Hematología y Vitaminas',
    name: 'Etamsilato',
    className: {'pt': 'Hemostático / Vasoprotetor', 'es': 'Hemostático / Vasoprotector'},
    category: {'pt': 'Hematológicos', 'es': 'Hematológicos'},
    route: 'VO / IV / IM',
    doseType: 'fixed',
    fixedDose: {
      'pt': '500 mg a cada 6–8h. IV/IM: 250–500 mg.',
      'es': '500 mg cada 6–8 h. IV/IM: 250–500 mg.',
    },
    renalAlert: {
      'pt': 'Usar com cautela na insuficiência renal.',
      'es': 'Usar con cautela en insuficiencia renal.',
    },
    elderlyAlert: {
      'pt': 'Seguro; monitorar possíveis reações de hipersensibilidade.',
      'es': 'Seguro; monitorear posibles reacciones de hipersensibilidad.',
    },
    mechanism: {
      'pt': 'Aumenta a adesividade plaquetária e a resistência capilar.',
      'es': 'Aumenta la adhesividad plaquetaria y la resistencia capilar.',
    },
    warning: {
      'pt': 'Não é procoagulante sistêmico; não atua na cascata de coagulação.',
      'es': 'No es procoagulante sistémico; no actúa en la cascada de coagulación.',
    },
    adverse: {
      'pt': ['Cefaleia', 'Náuseas', 'Rash cutâneo', 'Hipotensão (se IV rápido)'],
      'es': ['Cefalea', 'Náuseas', 'Rash cutáneo', 'Hipotensión (si IV rápido)'],
    },
  ),

  DrugModel(
    id: 'levosulpirida',
    group: 'Gastroenterología',
    name: 'Levosulpirida',
    className: {'pt': 'Procinético / Neuroléptico', 'es': 'Procinético / Neuroléptico'},
    category: {'pt': 'Gastrointestinais', 'es': 'Gastrointestinales'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': '25 mg 3 vezes ao dia, antes das refeições.',
      'es': '25 mg 3 veces al día, antes de las comidas.',
    },
    renalAlert: {
      'pt': 'Reduzir dose ou evitar na insuficiência renal grave.',
      'es': 'Reducir dosis o evitar en insuficiencia renal grave.',
    },
    elderlyAlert: {
      'pt': 'Risco de síndrome extrapiramidal (Parkinsonismo medicamentoso).',
      'es': 'Riesgo de síndrome extrapiramidal (Parkinsonismo medicamentoso).',
    },
    mechanism: {
      'pt': 'Antagonista seletivo dos receptores dopaminérgicos D2 periféricos e centrais.',
      'es': 'Antagonista selectivo de los receptores dopaminérgicos D2 periféricos y centrales.',
    },
    warning: {
      'pt': 'Pode causar hiperprolactinemia (galactorreia/amenorreia).',
      'es': 'Puede causar hiperprolactinemia (galactorrea/amenorrea).',
    },
    adverse: {
      'pt': ['Sonolência', 'Tremores', 'Tensão mamária', 'Fadiga'],
      'es': ['Somnolencia', 'Temblores', 'Tensión mamaria', 'Fatiga'],
    },
  ),

  DrugModel(
    id: 'racecadotril',
    group: 'Gastroenterología',
    name: 'Racecadotril',
    className: {'pt': 'Antidiarreico antissecretor', 'es': 'Antidiarreico antisecretor'},
    category: {'pt': 'Gastrointestinais', 'es': 'Gastrointestinales'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Pediatria: 1,5 mg/kg por dose 3x/dia. Adulto: 100 mg 3x/dia.',
      'es': 'Pediatría: 1,5 mg/kg por dosis 3 veces/día. Adulto: 100 mg 3 veces/día.',
    },
    renalAlert: {
      'pt': 'Usar com precaução.',
      'es': 'Usar con precaución.',
    },
    elderlyAlert: {
      'pt': 'Seguro na dose padrão.',
      'es': 'Seguro en la dosis estándar.',
    },
    mechanism: {
      'pt': 'Inibidor da encefalinase intestinal; reduz hipersecreção de água e eletrólitos.',
      'es': 'Inhibidor de la encefalinasa intestinal; reduce hipersecreción de agua y electrolitos.',
    },
    warning: {
      'pt': 'Não substitui a reidratação oral. Indicado para tratamento sintomático.',
      'es': 'No reemplaza la rehidratación oral. Indicado para tratamiento sintomático.',
    },
    adverse: {
      'pt': ['Cefaleia', 'Vômitos (raro)', 'Rash'],
      'es': ['Cefalea', 'Vómitos (raro)', 'Rash'],
    },
  ),

  DrugModel(
    id: 'amoxicilina_sulbactam',
    group: 'Antibióticos',
    name: 'Amoxicilina + Sulbactam',
    className: {'pt': 'Betalactâmico + Inibidor de betalactamase', 'es': 'Betalactámico + Inhibidor de betalactamasa'},
    category: {'pt': 'Antibióticos', 'es': 'Antibióticos'},
    route: 'VO / IV / IM',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Adulto: 875/125 mg a cada 12h. Pediatria: 40–90 mg/kg/dia (base amox) cada 12h.',
      'es': 'Adulto: 875/125 mg cada 12 h. Pediatría: 40–90 mg/kg/día (base amox) cada 12 h.',
    },
    renalAlert: {
      'pt': 'ClCr <30 mL/min: ajustar intervalo para 12–24h conforme gravidade.',
      'es': 'ClCr <30 mL/min: ajustar intervalo a 12–24 h según gravedad.',
    },
    elderlyAlert: {
      'pt': 'Ajustar conforme função renal; monitorar diarreia (risco de C. difficile).',
      'es': 'Ajustar según función renal; monitorear diarrea (riesgo de C. difficile).',
    },
    mechanism: {
      'pt': 'Inibe síntese da parede bacteriana (amoxicilina) e protege contra betalactamases (sulbactam).',
      'es': 'Inhibe síntesis de pared bacteriana (amoxicilina) y protege contra betalactamasas (sulbactam).',
    },
    warning: {
      'pt': 'O sulbactam tem atividade intrínseca contra Acinetobacter spp. (diferente da clavulanato).',
      'es': 'El sulbactam tiene actividad intrínseca contra Acinetobacter spp. (diferente al clavulanato).',
    },
    adverse: {
      'pt': ['Diarreia', 'Exantema', 'Náuseas', 'Candidíase oral/vaginal'],
      'es': ['Diarrea', 'Exantema', 'Náuseas', 'Candidiasis oral/vaginal'],
    },
  ),

  DrugModel(
    id: 'tamsulosina',
    group: 'Varios / Antídotos / Otros',
    name: 'Tamsulosina',
    className: {'pt': 'Bloqueador Alfa-1 adrenérgico', 'es': 'Bloqueante Alfa-1 adrenérgico'},
    category: {'pt': 'Urológicos', 'es': 'Urológicos'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': '0,4 mg uma vez ao dia, após refeição.',
      'es': '0,4 mg una vez al día, después de la comida.',
    },
    renalAlert: {
      'pt': 'Sem ajuste se ClCr >10 mL/min.',
      'es': 'Sin ajuste si ClCr >10 mL/min.',
    },
    elderlyAlert: {
      'pt': 'Risco de hipotensão ortostática. Cuidado em cirurgia de catarata (síndrome da íris flácida).',
      'es': 'Riesgo de hipotensión ortostática. Cuidado en cirugía de catarata (síndrome de iris flácido).',
    },
    mechanism: {
      'pt': 'Bloqueio seletivo de receptores alfa-1 no colo vesical e uretra; facilita micção e expulsão de cálculo.',
      'es': 'Bloqueo selectivo de receptores alfa-1 en cuello vesical y uretra; facilita micción y expulsión de cálculo.',
    },
    warning: {
      'pt': 'Pode causar efeito de primeira dose (hipotensão súbita). Tomar à noite.',
      'es': 'Puede causar efecto de primera dosis (hipotensión súbita). Tomar de noche.',
    },
    adverse: {
      'pt': ['Tontura', 'Ejaculação retrógrada', 'Cefaleia', 'Congestão nasal'],
      'es': ['Mareos', 'Eyaculación retrógrada', 'Cefalea', 'Congestión nasal'],
    },
  ),

  DrugModel(
    id: 'ciprofloxacina',
    group: 'Antibióticos',
    name: 'Ciprofloxacina',
    className: {'pt': 'Fluoroquinolona', 'es': 'Fluoroquinolona'},
    category: {'pt': 'Antibióticos', 'es': 'Antibióticos'},
    route: 'VO / IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': '500 mg cada 12h (VO). IV: 400 mg cada 12h.',
      'es': '500 mg cada 12 h (VO). IV: 400 mg cada 12 h.',
    },
    renalAlert: {
      'pt': 'ClCr 30–50 mL/min: 250–500 mg/12h. ClCr <30 mL/min: 250–500 mg/24h.',
      'es': 'ClCr 30–50 mL/min: 250–500 mg/12h. ClCr <30 mL/min: 250–500 mg/24h.',
    },
    elderlyAlert: {
      'pt': 'Risco aumentado de tendinite e ruptura do tendão de Aquiles. Risco de confusão mental.',
      'es': 'Riesgo aumentado de tendinitis y ruptura del tendón de Aquiles. Riesgo de confusión.',
    },
    mechanism: {
      'pt': 'Inibe a DNA girase bacteriana e topoisomerase IV, bloqueando replicação do DNA.',
      'es': 'Inhibe la DNA girasa bacteriana y topoisomerasa IV, bloqueando replicación del DNA.',
    },
    warning: {
      'pt': 'Evitar em crianças (risco articular). Pode prolongar intervalo QT.',
      'es': 'Evitar en niños (riesgo articular). Puede prolongar intervalo QT.',
    },
    adverse: {
      'pt': ['Náuseas', 'Diarreia', 'Artralgia', 'Prolongamento do QT'],
      'es': ['Náuseas', 'Diarrea', 'Artralgia', 'Prolongamiento del QT'],
    },
  ),

  DrugModel(
    id: 'ambroxol',
    group: 'Respiratorio',
    name: 'Ambroxol',
    className: {'pt': 'Mucolítico / Expectorante', 'es': 'Mucolítico / Expectorante'},
    category: {'pt': 'Respiratórios', 'es': 'Respiratorios'},
    route: 'VO / Inalatório',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Adulto: 30–60 mg cada 8–12h. Pediatria: 1,25–2,5 mg/kg/dia.',
      'es': 'Adulto: 30–60 mg cada 8–12 h. Pediatría: 1,25–2,5 mg/kg/día.',
    },
    renalAlert: {
      'pt': 'Ajuste geralmente não necessário.',
      'es': 'Ajuste generalmente no necesario.',
    },
    elderlyAlert: {
      'pt': 'Geralmente seguro.',
      'es': 'Generalmente seguro.',
    },
    mechanism: {
      'pt': 'Diminui a viscosidade do muco e estimula a síntese de surfactante pulmonar.',
      'es': 'Disminuye la viscosidad del moco y estimula la síntesis de surfactante pulmonar.',
    },
    warning: {
      'pt': 'Pode causar irritação gástrica. Tomar após as refeições.',
      'es': 'Puede causar irritación gástrica. Tomar después de las comidas.',
    },
    adverse: {
      'pt': ['Náuseas', 'Pirose', 'Dispepsia', 'Erupção cutânea'],
      'es': ['Náuseas', 'Pirosis', 'Dispepsia', 'Erupción cutánea'],
    },
  ),

  DrugModel(
    id: 'rosuvastatina',
    group: 'Cardiovascular y HTA',
    name: 'Rosuvastatina',
    className: {'pt': 'Inibidor da HMG-CoA redutase / Estatina', 'es': 'Inhibidor de HMG-CoA reductasa / Estatina'},
    category: {'pt': 'Cardiovascular', 'es': 'Cardiovascular'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': '5–20 mg uma vez ao dia. Máx: 40 mg/dia.',
      'es': '5–20 mg una vez al día. Máx: 40 mg/día.',
    },
    renalAlert: {
      'pt': 'ClCr <30 mL/min: contraindicado ou dose máx 5 mg/dia.',
      'es': 'ClCr <30 mL/min: contraindicado o dosis máx 5 mg/día.',
    },
    elderlyAlert: {
      'pt': 'Risco aumentado de miopatia. Iniciar com 5 mg.',
      'es': 'Riesgo aumentado de miopatía. Iniciar con 5 mg.',
    },
    mechanism: {
      'pt': 'Inibe a HMG-CoA redutase, diminuindo síntese de colesterol hepático.',
      'es': 'Inhibe la HMG-CoA reductasa, disminuyendo síntesis de colesterol hepático.',
    },
    warning: {
      'pt': 'Monitorar CPK se houver mialgia. Risco de rabdomiólise.',
      'es': 'Monitorear CPK si hay mialgia. Riesgo de rabdomiólisis.',
    },
    adverse: {
      'pt': ['Mialgia', 'Cefaleia', 'Aumento de transaminases', 'Diabetes mellitus (novo início)'],
      'es': ['Mialgia', 'Cefalea', 'Aumento de transaminasas', 'Diabetes mellitus (nuevo inicio)'],
    },
  ),

  DrugModel(
    id: 'alprazolam',
    group: 'Neurología y Psiquiatría',
    name: 'Alprazolam',
    className: {'pt': 'Benzodiazepínico de ação curta', 'es': 'Benzodiazepina de acción corta'},
    category: {'pt': 'Psicotrópicos', 'es': 'Psicotrópicos'},
    route: 'VO / SL',
    doseType: 'fixed',
    fixedDose: {
      'pt': '0,25–0,5 mg a cada 8h. Máx: 4 mg/dia.',
      'es': '0,25–0,5 mg cada 8 h. Máx: 4 mg/día.',
    },
    renalAlert: {
      'pt': 'Usar com cautela em insuficiência renal grave.',
      'es': 'Usar con cautela en insuficiencia renal grave.',
    },
    elderlyAlert: {
      'pt': 'Aumenta significativamente o risco de quedas e confusão mental aguda.',
      'es': 'Aumenta significativamente el riesgo de caídas y confusión mental aguda.',
    },
    mechanism: {
      'pt': 'Potencializa a atividade do GABA no SNC, aumentando a frequência de abertura dos canais de cloro.',
      'es': 'Potencia la actividad del GABA en el SNC, aumentando la frecuencia de apertura de los canales de cloro.',
    },
    warning: {
      'pt': 'Alto potencial de abuso e síndrome de abstinência severa com retirada abrupta.',
      'es': 'Alto potencial de abuso y síndrome de abstinencia severa con retirada abrupta.',
    },
    adverse: {
      'pt': ['Sonolência', 'Ataxia', 'Boca seca', 'Fadiga'],
      'es': ['Somnolencia', 'Ataxia', 'Boca seca', 'Fatiga'],
    },
  ),

  DrugModel(
    id: 'carvedilol',
    group: 'Cardiovascular y HTA',
    name: 'Carvedilol',
    className: {'pt': 'Betabloqueador não seletivo / Alfa-1 bloqueador', 'es': 'Betabloqueante no selectivo / Alfa-1 bloqueante'},
    category: {'pt': 'Cardiovascular', 'es': 'Cardiovascular'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Início: 3,125–6,25 mg 2x/dia. Alvo (se tolerado): 25–50 mg 2x/dia.',
      'es': 'Inicio: 3,125–6,25 mg 2 veces/día. Meta: 25–50 mg 2 veces/día.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário.',
      'es': 'Sin ajuste necesario.',
    },
    elderlyAlert: {
      'pt': 'Risco de bradicardia e bloqueios. Titular dose lentamente.',
      'es': 'Riesgo de bradicardia y bloqueos. Titular dosis lentamente.',
    },
    mechanism: {
      'pt': 'Antagonista adrenérgico não seletivo β e seletivo α-1; reduz resistência periférica e protege o miocárdio.',
      'es': 'Antagonista adrenérgico no selectivo β y selectivo α-1; reduce resistencia periférica y protege el miocardio.',
    },
    warning: {
      'pt': 'Pode mascarar sintomas de hipoglicemia em diabéticos. Não suspender abruptamente.',
      'es': 'Puede enmascarar síntomas de hipoglucemia en diabéticos. No suspender abruptamente.',
    },
    adverse: {
      'pt': ['Tontura', 'Bradicardia', 'Hipotensão postural', 'Fadiga'],
      'es': ['Mareos', 'Bradicardia', 'Hipotensión postural', 'Fatiga'],
    },
  ),

  DrugModel(
    id: 'lansoprazol',
    group: 'Gastroenterología',
    name: 'Lansoprazol',
    className: {'pt': 'Inibidor da Bomba de Prótons (IBP)', 'es': 'Inhibidor de la Bomba de Protones (IBP)'},
    category: {'pt': 'Gastrointestinais', 'es': 'Gastrointestinales'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': '15–30 mg uma vez ao dia, 30 min antes do café da manhã.',
      'es': '15–30 mg una vez al día, 30 min antes del desayuno.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário.',
      'es': 'Sin ajuste necesario.',
    },
    elderlyAlert: {
      'pt': 'Uso prolongado aumenta risco de osteoporose e infecções (pneumonia / C. difficile).',
      'es': 'Uso prolongado aumenta riesgo de osteoporosis e infecciones (neumonía / C. difficile).',
    },
    mechanism: {
      'pt': 'Bloqueio irreversível da H+/K+ ATPase na célula parietal gástrica.',
      'es': 'Bloqueo irreversible de la H+/K+ ATPase en la célula parietal gástrica.',
    },
    warning: {
      'pt': 'Pode reduzir absorção de vitamina B12 e magnésio em uso crônico.',
      'es': 'Puede reducir absorción de vitamina B12 y magnesio en uso crónico.',
    },
    adverse: {
      'pt': ['Cefaleia', 'Diarreia', 'Dor abdominal', 'Prurido'],
      'es': ['Cefalea', 'Diarrea', 'Dolor abdominal', 'Prurito'],
    },
  ),

  DrugModel(
    id: 'nitazoxanida',
    group: 'Infectología (Antifúngicos / Antivirales / TBC)',
    name: 'Nitazoxanida',
    className: {'pt': 'Antiparasitário de amplo espectro', 'es': 'Antiparasitario de amplio espectro'},
    category: {'pt': 'Antiparasitários', 'es': 'Antiparasitarios'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': '500 mg a cada 12h por 3 dias.',
      'es': '500 mg cada 12 h por 3 días.',
    },
    renalAlert: {
      'pt': 'Sem estudos suficientes; usar com precaução em insuficiência renal grave.',
      'es': 'Sin estudios suficientes; usar con precaución en insuficiencia renal grave.',
    },
    elderlyAlert: {
      'pt': 'Geralmente bem tolerado.',
      'es': 'Generalmente bien tolerado.',
    },
    mechanism: {
      'pt': 'Interfere na transferência de elétrons essencial para o metabolismo anaeróbio dos parasitas.',
      'es': 'Interfiere en la transferencia de electrones esencial para el metabolismo anaerobio de los parásitos.',
    },
    warning: {
      'pt': 'Eficaz contra Giardia, Cryptosporidium e diversos helmintos. Tomar com alimentos.',
      'es': 'Eficaz contra Giardia, Cryptosporidium y diversos helmintos. Tomar con alimentos.',
    },
    adverse: {
      'pt': ['Urina amarelo-esverdeada (normal)', 'Náuseas', 'Dor abdominal', 'Cefaleia'],
      'es': ['Orina amarillo-verdosa (normal)', 'Náuseas', 'Dolor abdominal', 'Cefalea'],
    },
  ),

  DrugModel(
    id: 'atorvastatina',
    group: 'Cardiovascular y HTA',
    name: 'Atorvastatina',
    className: {'pt': 'Inibidor da HMG-CoA redutase / Estatina', 'es': 'Inhibidor de HMG-CoA reductasa / Estatina'},
    category: {'pt': 'Cardiovascular', 'es': 'Cardiovascular'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': '10–80 mg uma vez ao dia, a qualquer hora.',
      'es': '10–80 mg una vez al día, en cualquier horario.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário.',
      'es': 'Sin ajuste necesario.',
    },
    elderlyAlert: {
      'pt': 'Monitorar mialgia e interações com múltiplas medicações.',
      'es': 'Monitorear mialgia e interacción con múltiples medicaciones.',
    },
    mechanism: {
      'pt': 'Inibe competitivamente a HMG-CoA redutase; reduz LDL e triglicerídeos.',
      'es': 'Inhibe competitivamente la HMG-CoA reductasa; reduce LDL y triglicéridos.',
    },
    warning: {
      'pt': 'Contraindicado em doença hepática ativa. Monitorar CPK se mialgia.',
      'es': 'Contraindicado en enfermedad hepática activa. Monitorear CPK si mialgia.',
    },
    adverse: {
      'pt': ['Mialgia', 'Diarreia', 'Nasofaringite', 'Elevação de transaminases'],
      'es': ['Mialgia', 'Diarrea', 'Nasofaringitis', 'Elevación de transaminasas'],
    },
  ),

  DrugModel(
    id: 'simeticona',
    group: 'Gastroenterología',
    name: 'Simeticona',
    className: {'pt': 'Antiflatulento', 'es': 'Antiflatulento'},
    category: {'pt': 'Gastrointestinais', 'es': 'Gastrointestinales'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Adulto: 40–125 mg a cada 6–8h. Pediatria (gotas): 1 gota/kg/dose até 3x/dia.',
      'es': 'Adulto: 40–125 mg cada 6–8 h. Pediatría (gotas): 1 gota/kg/dosis hasta 3 veces/día.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário (não absorvida sistemicamente).',
      'es': 'Sin ajuste necesario (no se absorbe sistémicamente).',
    },
    elderlyAlert: {
      'pt': 'Seguro.',
      'es': 'Seguro.',
    },
    mechanism: {
      'pt': 'Altera a tensão superficial das bolhas de gás intestinal, facilitando sua eliminação.',
      'es': 'Altera la tensión superficial de las burbujas de gas intestinal, facilitando su eliminación.',
    },
    warning: {
      'pt': 'Não trata a causa base (aerofagia, intolerâncias), apenas o sintoma.',
      'es': 'No trata la causa base, solo el síntoma.',
    },
    adverse: {
      'pt': ['Constipação leve', 'Náuseas'],
      'es': ['Constipación leve', 'Náuseas'],
    },
  ),

  DrugModel(
    id: 'gliclazida',
    group: 'Endocrinología y Metabolismo',
    name: 'Gliclazida MR',
    className: {'pt': 'Hipoglicemiante / Sulfonilureia de 2ª geração', 'es': 'Hipoglucemiante / Sulfonilurea de 2ª generación'},
    category: {'pt': 'Endocrinologia', 'es': 'Endocrinología'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': '30–120 mg uma vez ao dia, preferencialmente no café da manhã.',
      'es': '30–120 mg una vez al día, preferentemente en el desayuno.',
    },
    renalAlert: {
      'pt': 'ClCr <30 mL/min: uso com precaução ou contraindicado conforme a fonte.',
      'es': 'ClCr <30 mL/min: uso con precaución o contraindicado.',
    },
    elderlyAlert: {
      'pt': 'Sulfonilureia mais segura para idosos, mas requer cautela com hipoglicemia.',
      'es': 'Sulfonilurea más segura para ancianos, pero requiere cautela con hipoglucemia.',
    },
    mechanism: {
      'pt': 'Estimula a secreção de insulina pelas células beta pancreáticas (bloqueia canais de K+).',
      'es': 'Estimula la secreción de insulina por las células beta pancreáticas (bloquea canales de K+).',
    },
    warning: {
      'pt': 'Não utilizar em jejum prolongado. Risco de hipoglicemia prolongada.',
      'es': 'No usar en ayuno prolongado. Riesgo de hipoglucemia prolongada.',
    },
    adverse: {
      'pt': ['Hipoglicemia', 'Ganho de peso', 'Náuseas', 'Reações cutâneas'],
      'es': ['Hipoglucemia', 'Aumento de peso', 'Náuseas', 'Reacciones cutáneas'],
    },
  ),

  DrugModel(
    id: 'ceftazidima',
    group: 'Antibióticos',
    name: 'Ceftazidima',
    className: {'pt': 'Cefalosporina de 3ª geração (antipseudomonal)', 'es': 'Cefalosporina de 3ª generación (antipseudomonal)'},
    category: {'pt': 'Antibióticos', 'es': 'Antibióticos'},
    route: 'IV / IM',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Adulto: 1–2 g a cada 8h (máx. 6 g/dia). | Pediátrico: 100–150 mg/kg/dia dividido em 3 doses (máx. 6 g/dia). Meningite: 150–200 mg/kg/dia ÷ 3.',
      'es': 'Adulto: 1–2 g cada 8 h (máx. 6 g/día). | Pediátrico: 100–150 mg/kg/día ÷ 3 dosis (máx. 6 g/día). Meningitis: 150–200 mg/kg/día ÷ 3.',
    },
    renalAlert: {
      'pt': 'Ajuste obrigatório se ClCr <50 mL/min. Risco de neurotoxicidade (convulsões, encéfalopatia) por acúmulo em IR grave.',
      'es': 'Ajuste obligatorio si ClCr <50 mL/min. Riesgo de neurotoxicidad (convulsiones, encefalopatia) por acumulación en IR grave.',
    },
    elderlyAlert: {
      'pt': 'Monitorar função renal para evitar estados confusionais e neurotoxicidade por acúmulo.',
      'es': 'Monitorear función renal para evitar confusión y neurotoxicidad por acumulación.',
    },
    mechanism: {
      'pt': 'Inibe a síntese de peptidoglicano da parede celular bacteriana (ligação às PBPs); alta atividade contra Pseudomonas aeruginosa e Gram-negativos.',
      'es': 'Inhibe la síntesis de peptidoglicano de la pared celular (unión a PBPs); alta actividad contra Pseudomonas aeruginosa y Gram-negativos.',
    },
    warning: {
      'pt': 'Baixa atividade contra Gram-positivos (preferír ceftriaxona nesse contexto). Convulsões em doses altas ou IR não ajustada.',
      'es': 'Baja actividad contra Gram-positivos (preferir ceftriaxona en ese contexto). Convulsiones en dosis altas o IR no ajustada.',
    },
    adverse: {
      'pt': ['Flebite', 'Eosinofilia', 'Diarreia', 'Náuseas', 'Teste de Coombs positivo', 'Convulsão (doses altas / IR)'],
      'es': ['Flebitis', 'Eosinofilia', 'Diarrea', 'Náuseas', 'Test de Coombs positivo', 'Convulsión (dosis altas / IR)'],
    },
  ),

  DrugModel(
    id: 'ketotifeno',
    group: 'Respiratorio',
    name: 'Ketotifeno',
    className: {'pt': 'Anti-histamínico / Estabilizador de mastócitos', 'es': 'Antihistamínico / Estabilizador de mastocitos'},
    category: {'pt': 'Antialérgicos', 'es': 'Antialérgicos'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Pediatria: 0,05 mg/kg por dose 2x/dia. Adulto: 1 mg 2x/dia.',
      'es': 'Pediatría: 0,05 mg/kg por dosis 2 veces/día. Adulto: 1 mg 2 veces/día.',
    },
    renalAlert: {
      'pt': 'Usar com cautela em insuficiência renal grave.',
      'es': 'Usar con cautela en insuficiencia renal grave.',
    },
    elderlyAlert: {
      'pt': 'Pode causar sedação excessiva. Não é a primeira escolha.',
      'es': 'Puede causar sedación excesiva. No es la primera elección.',
    },
    mechanism: {
      'pt': 'Bloqueia receptores H1 e impede a liberação de mediadores inflamatórios por mastócitos.',
      'es': 'Bloquea receptores H1 e impide liberación de mediadores inflamatorios por mastocitos.',
    },
    warning: {
      'pt': 'Uso profilático — não é eficaz para abortar crise asmática aguda.',
      'es': 'Uso profiláctico — no eficaz para abortar crisis asmática aguda.',
    },
    adverse: {
      'pt': ['Sedação', 'Aumento de apetite', 'Boca seca', 'Tontura'],
      'es': ['Sedación', 'Aumento de apetito', 'Boca seca', 'Mareos'],
    },
  ),

  DrugModel(
    id: 'valproato_iv',
    group: 'Neurología y Psiquiatría',
    name: 'Valproato de Sódio / Ácido Valproico',
    className: {'pt': 'Antiepiléptico', 'es': 'Antiepiléptico'},
    category: {'pt': 'Neurologia', 'es': 'Neurología'},
    route: 'VO / IV',
    doseType: 'weightBased',
    fixedDose: {
      'pt': 'Carga IV: 20–40 mg/kg. Manutenção: 15–60 mg/kg/dia.',
      'es': 'Carga IV: 20–40 mg/kg. Mantenimiento: 15–60 mg/kg/día.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário; mas monitorar fração livre (proteínas).',
      'es': 'Sin ajuste necesario; monitorear fracción libre.',
    },
    elderlyAlert: {
      'pt': 'Risco de sonolência excessiva e trombocitopenia.',
      'es': 'Riesgo de somnolencia excesiva y trombocitopenia.',
    },
    mechanism: {
      'pt': 'Aumenta níveis de GABA, bloqueia canais de sódio e cálcio tipo T.',
      'es': 'Aumenta niveles de GABA, bloquea canales de sodio y calcio tipo T.',
    },
    warning: {
      'pt': 'Contraindicado em hepatopatias graves.',
      'es': 'Contraindicado en hepatopatías graves.',
    },
    adverse: {
      'pt': ['Hepatotoxicidade', 'Trombocitopenia', 'Náuseas', 'Tremor'],
      'es': ['Hepatotoxicidad', 'Trombocitopenia', 'Náuseas', 'Tremor'],
    },
  ),

  DrugModel(
    id: 'esmolol',
    group: 'UCI – Críticos y Sedoanalgesia',
    name: 'Esmolol',
    className: {'pt': 'Betabloqueador seletivo Beta-1 de curta ação', 'es': 'Beta-bloqueante selectivo Beta-1 de acción corta'},
    category: {'pt': 'Cardiovascular', 'es': 'Cardiovascular'},
    route: 'IV',
    doseType: 'weightBased',
    fixedDose: {
      'pt': 'Carga: 500 mcg/kg em 1 min. Manutenção: 50–200 mcg/kg/min.',
      'es': 'Carga: 500 mcg/kg en 1 min. Mantenimiento: 50–200 mcg/kg/min.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário.',
      'es': 'Sin ajuste necesario.',
    },
    elderlyAlert: {
      'pt': 'Risco de hipotensão severa. Titular com cautela.',
      'es': 'Riesgo de hipotensión severa. Titular con cautela.',
    },
    mechanism: {
      'pt': 'Bloqueio seletivo Beta-1; meia-vida de 9 minutos.',
      'es': 'Bloqueo selectivo Beta-1; vida media de 9 minutos.',
    },
    warning: {
      'pt': 'Ideal para controle de FC em dissecção aórtica ou tireotoxicose.',
      'es': 'Ideal para control de FC en disección aórtica o tirotoxicosis.',
    },
    adverse: {
      'pt': ['Hipotensão', 'Bradicardia', 'Flebite no local', 'Broncoespasmo'],
      'es': ['Hipotensión', 'Bradicardia', 'Flebitis', 'Broncoespasmo'],
    },
  ),

  DrugModel(
    id: 'milrinona',
    group: 'UCI – Críticos y Sedoanalgesia',
    name: 'Milrinona',
    className: {'pt': 'Inodilatador / Inibidor da Fosfodiesterase III', 'es': 'Inodilatador / Inhibidor de la Fosfodiesterasa III'},
    category: {'pt': 'Cardiovascular', 'es': 'Cardiovascular'},
    route: 'IV',
    doseType: 'weightBased',
    fixedDose: {
      'pt': 'Carga: 50 mcg/kg em 10 min. Manutenção: 0,375–0,75 mcg/kg/min.',
      'es': 'Carga: 50 mcg/kg en 10 min. Mantenimiento: 0,375–0,75 mcg/kg/min.',
    },
    renalAlert: {
      'pt': 'Ajuste obrigatório; ClCr <50 requer redução significativa da dose.',
      'es': 'Ajuste obligatorio; ClCr <50 requiere reducción de dosis.',
    },
    elderlyAlert: {
      'pt': 'Alto risco de hipotensão e arritmias ventriculares.',
      'es': 'Alto riesgo de hipotensión y arritmias ventriculares.',
    },
    mechanism: {
      'pt': 'Inibe PDE-III, aumentando AMPc cardíaco (inotropismo) e vascular (vasodilatação).',
      'es': 'Inhibe PDE-III; inotropismo (+) y vasodilatación.',
    },
    warning: {
      'pt': 'Pode causar hipotensão severa se administrado em bolo rápido.',
      'es': 'Puede causar hipotensión severa si se da en bolo rápido.',
    },
    adverse: {
      'pt': ['Hipotensão', 'Arritmias ventriculares', 'Cefaleia', 'Trombocitopenia'],
      'es': ['Hipotensión', 'Arritmias ventriculares', 'Cefalea', 'Trombocitopenia'],
    },
  ),

  DrugModel(
    id: 'fosfomicina',
    group: 'Antibióticos',
    name: 'Fosfomicina Trometamol',
    className: {'pt': 'Antibiótico / Derivado do ácido fosfônico', 'es': 'Antibiótico / Derivado del ácido fosfónico'},
    category: {'pt': 'Antibióticos', 'es': 'Antibióticos'},
    route: 'VO (Sache)',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Adulto: 3 g em dose única. Pediatria (>12 anos): 3 g dose única.',
      'es': 'Adulto: 3 g en dosis única. Pediatría (>12 años): 3 g dosis única.',
    },
    renalAlert: {
      'pt': 'Não recomendado se ClCr <10 mL/min.',
      'es': 'No recomendado si ClCr <10 mL/min.',
    },
    elderlyAlert: {
      'pt': 'Seguro; útil em ITUs não complicadas.',
      'es': 'Seguro; útil en ITUs no complicadas.',
    },
    mechanism: {
      'pt': 'Inibe a síntese da parede celular bacteriana em estágio inicial (Enolpiruvil transferase).',
      'es': 'Inhibe la síntesis de pared celular bacteriana en etapa inicial.',
    },
    warning: {
      'pt': 'Tomar com estômago vazio, preferencialmente ao deitar após esvaziar a bexiga.',
      'es': 'Tomar con estómago vacío, preferentemente al acostarse.',
    },
    adverse: {
      'pt': ['Diarreia', 'Náuseas', 'Cefaleia', 'Vaginite'],
      'es': ['Diarrea', 'Náuseas', 'Cefalea', 'Vaginitis'],
    },
  ),

  DrugModel(
    id: 'acetazolamida',
    group: 'Varios / Antídotos / Otros',
    name: 'Acetazolamida',
    className: {'pt': 'Inibidor da Anidrase Carbônica', 'es': 'Inhibidor de la Anidrasa Carbónica'},
    category: {'pt': 'Neurologia / Oftalmologia', 'es': 'Neurología / Oftalmología'},
    route: 'VO / IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Glaucoma: 250 mg cada 6–12h. Mal de montanha: 125 mg cada 12h.',
      'es': 'Glaucoma: 250 mg cada 6–12 h. Mal de montaña: 125 mg cada 12 h.',
    },
    renalAlert: {
      'pt': 'Não recomendado se ClCr <10 mL/min.',
      'es': 'No recomendado si ClCr <10 mL/min.',
    },
    elderlyAlert: {
      'pt': 'Risco de acidose metabólica e hipocalemia.',
      'es': 'Riesgo de acidosis metabólica e hipopotasemia.',
    },
    mechanism: {
      'pt': 'Reduz a secreção de humor aquoso e aumenta a excreção de bicarbonato.',
      'es': 'Reduce la secreción de humor acuoso.',
    },
    warning: {
      'pt': 'Pode causar parestesias nas extremidades.',
      'es': 'Puede causar parestesias en extremidades.',
    },
    adverse: {
      'pt': ['Parestesias', 'Acidose metabólica', 'Hipocalemia', 'Poliúria'],
      'es': ['Parestesias', 'Acidosis metabólica', 'Hipopotasemia', 'Poliuria'],
    },
  ),

  DrugModel(
    id: 'kayexalate',
    group: 'UCI – Críticos y Sedoanalgesia',
    name: 'Poliestirenossulfonato de Sódio',
    className: {'pt': 'Resina de troca catiônica', 'es': 'Resina de intercambio catiónico'},
    category: {'pt': 'Emergência', 'es': 'Emergencia'},
    route: 'VO / Retal',
    doseType: 'fixed',
    fixedDose: {
      'pt': '15–30 g cada 6–12h, diluído em água ou manitol.',
      'es': '15–30 g cada 6–12 h, diluido en agua o manitol.',
    },
    renalAlert: {
      'pt': 'Usado especificamente na insuficiência renal (hipercalemia).',
      'es': 'Usado en falla renal para hiperpotasemia.',
    },
    elderlyAlert: {
      'pt': 'Risco elevado de necrose intestinal e constipação grave.',
      'es': 'Riesgo de necrosis intestinal y constipación grave.',
    },
    mechanism: {
      'pt': 'Troca íons sódio por íons potássio no intestino grosso.',
      'es': 'Intercambia iones sodio por potasio en el intestino.',
    },
    warning: {
      'pt': 'Não usar em pacientes com obstrução intestinal ou pós-operatório.',
      'es': 'No usar en obstrucción intestinal.',
    },
    adverse: {
      'pt': ['Constipação', 'Náuseas', 'Hipocalemia', 'Necrose colônica (raro)'],
      'es': ['Constipación', 'Náuseas', 'Hipopotasemia', 'Necrosis colónica'],
    },
  ),

  DrugModel(
    id: 'rocuronio',
    group: 'UCI – Críticos y Sedoanalgesia',
    name: 'Rocurônio / Rocuronio',
    className: {'pt': 'Bloqueador neuromuscular não despolarizante', 'es': 'Bloqueante neuromuscular no despolarizante'},
    category: {'pt': 'Emergência', 'es': 'Emergencia'},
    route: 'IV',
    doseType: 'weight',
    fixedDose: {
      'pt': 'Adulto/Pediátrico (IOT): 0.6-1.2 mg/kg IV. Manutenção: 0.1-0.2 mg/kg conforme monitorização (TOF).',
      'es': 'Adulto/Pediátrico (IOT): 0.6-1.2 mg/kg IV. Mantenimiento: 0.1-0.2 mg/kg según monitoreo (TOF).',
    },
    renalAlert: {'pt': 'Eliminação renal (30%). Duração do bloqueio pode ser prolongada em ClCr < 30 mL/min.', 'es': 'Eliminación renal (30%). La duración puede prolongarse en ClCr < 30 mL/min.'},
    elderlyAlert: {'pt': 'Maior sensibilidade; risco de bloqueio residual e aspiração pós-extubação.', 'es': 'Mayor sensibilidad; riesgo de bloqueo residual y aspiración post-extubación.'},
    mechanism: {'pt': 'Antagonista competitivo da acetilcolina nos receptores nicotínicos da junção neuromuscular.', 'es': 'Antagonista competitivo de la acetilcolina en los receptores nicotínicos de la unión neuromuscular.'},
    warning: {'pt': 'Obrigatório garantir via aérea e ventilação. Antídoto: Sugamadex ou Neostigmina.', 'es': 'Obligatorio asegurar vía aérea y ventilación. Antídoto: Sugamadex o Neostigmina.'},
    adverse: {
      'pt': ['Hipotensão', 'Hipertensão transitória', 'Broncoespasmo', 'Taquicardia', 'Reação anafilática'],
      'es': ['Hipotensión', 'Hipertensión transitoria', 'Broncoespasmo', 'Taquicardia', 'Reacción anafiláctica'],
    },
  ),

  DrugModel(
    id: 'dexmedetomidina',
    group: 'UCI – Críticos y Sedoanalgesia',
    name: 'Dexmedetomidina (Precedex)',
    className: {'pt': 'Agonista alfa-2 adrenérgico seletivo', 'es': 'Agonista alfa-2 adrenérgico selectivo'},
    category: {'pt': 'Sedação', 'es': 'Sedación'},
    route: 'IV (Infusão)',
    doseType: 'weight',
    fixedDose: {
      'pt': 'Adulto: Ataque 1 mcg/kg em 10 min; Manutenção 0.2-0.7 mcg/kg/h. Pediátrico: 0.1-0.5 mcg/kg/h.',
      'es': 'Adulto: Carga 1 mcg/kg en 10 min; Mantenimiento 0.2-0.7 mcg/kg/h. Pediátrico: 0.1-0.5 mcg/kg/h.',
    },
    renalAlert: {'pt': 'Sem ajuste de dose, mas metabólitos podem se acumular em insuficiência renal grave.', 'es': 'Sin ajuste de dosis, pero los metabolitos pueden acumularse en falla renal grave.'},
    elderlyAlert: {'pt': 'Alto risco de bradicardia e hipotensão ortostática. Reduzir dose inicial.', 'es': 'Alto riesgo de bradicardia e hipotensión ortostática. Reducir dosis inicial.'},
    mechanism: {'pt': 'Agonista seletivo de receptores alfa-2 centrais no locus coeruleus, gerando sedação e analgesia sem depressão respiratória.', 'es': 'Agonista selectivo de receptores alfa-2 centrales en el locus coeruleus, generando sedación y analgesia.'},
    warning: {'pt': 'Evitar bólus rápido para prevenir hipertensão paradoxal e bradicardia severa.', 'es': 'Evitar bolo rápido para prevenir hipertensión paradojal y bradicardia severa.'},
    adverse: {
      'pt': ['Bradicardia', 'Hipotensão', 'Hipertensão transitória (bólus)', 'Boca seca', 'Náuseas'],
      'es': ['Bradicardia', 'Hipotensión', 'Hipertensión transitoria (bolo)', 'Boca seca', 'Náuseas'],
    },
  ),

  DrugModel(
    id: 'betametasona_f',
    group: 'Endocrinología y Metabolismo',
    name: 'Betametasona (Celestamine / Corticas)',
    className: {'pt': 'Glicocorticoide sistêmico potente', 'es': 'Glucocorticoide sistémico potente'},
    category: {'pt': 'Corticosteroides', 'es': 'Corticosteroides'},
    route: 'VO / IM / IV',
    doseType: 'weight',
    fixedDose: {
      'pt': 'Adulto: 0.6-6 mg/dia. Pediátrico: 0.02-0.25 mg/kg/dia. Laringite (Argentina): 0.15 mg/kg dose única.',
      'es': 'Adulto: 0.6-6 mg/día. Pediátrico: 0.02-0.25 mg/kg/día. Laringitis (Argentina): 0.15 mg/kg dosis única.',
    },
    renalAlert: {'pt': 'Sem ajuste necessário. Pode causar retenção de sódio e edema.', 'es': 'Sin ajuste necesario. Puede causar retención de sodio y edema.'},
    elderlyAlert: {'pt': 'Risco de psicose esteroide, hipertensão e descompensação de Diabetes.', 'es': 'Riesgo de psicosis esteroidea, hipertensión y descompensación de Diabetes.'},
    mechanism: {'pt': 'Modula a transcrição gênica inibindo mediadores inflamatórios e a cascata do ácido araquidônico.', 'es': 'Modula la transcripción génica inhibiendo mediadores inflamatorios.'},
    warning: {'pt': 'Uso prolongado requer desmame para evitar insuficiência adrenal.', 'es': 'Uso prolongado requiere retiro gradual para evitar insuficiencia adrenal.'},
    adverse: {
      'pt': ['Hiperglicemia', 'Insônia', 'Aumento de apetite', 'Hipertensão', 'Miopatia'],
      'es': ['Hiperglucemia', 'Insomnio', 'Aumento de apetite', 'Hipertensión', 'Miopatía'],
    },
  ),

  DrugModel(
    id: 'mebendazol_f',
    group: 'Infectología (Antifúngicos / Antivirales / TBC)',
    name: 'Mebendazol',
    className: {'pt': 'Anti-helmíntico benzimidazol', 'es': 'Antihelmíntico benzimidazol'},
    category: {'pt': 'Antiparasitários', 'es': 'Antiparasitarios'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Adulto/Pediátrico: 100 mg 2x/dia por 3 dias (Enterobíase, Ascaridíase). Repetir em 15 dias.',
      'es': 'Adulto/Pediátrico: 100 mg 2 veces/día por 3 días. Repetir en 15 días.',
    },
    renalAlert: {'pt': 'Sem ajuste necessário.', 'es': 'Sin ajuste necesario.'},
    elderlyAlert: {'pt': 'Geralmente seguro.', 'es': 'Generalmente seguro.'},
    mechanism: {'pt': 'Bloqueia a captação de glicose e formação de microtúbulos no parasita, causando morte por inanição.', 'es': 'Bloquea la captación de glucosa y formación de microtúbulos en el parásito.'},
    warning: {'pt': 'Não recomendado no primeiro trimestre da gestação.', 'es': 'No recomendado en el primer trimestre del embarazo.'},
    adverse: {
      'pt': ['Dor abdominal', 'Diarreia', 'Elevação de transaminases', 'Exantema', 'Neutropenia (uso prolongado)'],
      'es': ['Dolor abdominal', 'Diarrea', 'Elevación de transaminasas', 'Exantema', 'Neutropenia (uso prolongado)'],
    },
  ),

  DrugModel(
    id: 'fexofenadina_f',
    group: 'Varios / Antídotos / Otros',
    name: 'Fexofenadina (Allegra)',
    className: {'pt': 'Anti-histamínico H1 de 2ª geração (não sedativo)', 'es': 'Antihistamínico H1 de 2ª generación (no sedativo)'},
    category: {'pt': 'Antialérgicos', 'es': 'Antialérgicos'},
    route: 'VO',
    doseType: 'weight',
    fixedDose: {
      'pt': 'Adulto: 120 mg 1×/dia ou 180 mg 1×/dia (rinite alérgica grave). | Pediátrico (2–11 anos): 30 mg 2×/dia; (≥12 anos): 60 mg 2×/dia ou 120 mg/dia.',
      'es': 'Adulto: 120 mg 1×/día o 180 mg 1×/día (rinitis alérgica grave). | Pediátrico (2–11 años): 30 mg 2×/día; (≥12 años): 60 mg 2×/día o 120 mg/día.',
    },
    renalAlert: {'pt': 'ClCr < 80 mL/min: dose inicial de 60 mg 1×/dia. Reduzir conforme função renal.', 'es': 'ClCr < 80 mL/min: dosis inicial 60 mg 1×/día. Reducir según función renal.'},
    elderlyAlert: {'pt': 'Fármaco de escolha em idosos — sem efeito anticolinérgico, sem sedação.', 'es': 'Fármaco de elección en ancianos — sin efecto anticolinérgico, sin sedación.'},
    mechanism: {'pt': 'Antagonista seletivo do receptor H1 periférico. Não atravessa a barreira hematoencefálica → sem sedação nem efeitos anticolinérgicos.', 'es': 'Antagonista selectivo del receptor H1 periférico. No atraviesa la barrera hematoencefálica → sin sedación ni efectos anticolinérgicos.'},
    warning: {'pt': 'Não ingerir com suco de toranja, laranja ou maçã (reduz absorção em até 36%). Tomar com água.', 'es': 'No tomar con jugo de toronja, naranja o manzana (reduce absorción hasta 36%). Tomar con agua.'},
    adverse: {
      'pt': ['Cefaleia', 'Náuseas', 'Boca seca (raro)', 'Vertigem', 'Fadiga', 'Tontura', 'Sonolência (raro)'],
      'es': ['Cefalea', 'Náuseas', 'Boca seca (raro)', 'Vértigo', 'Fatiga', 'Mareo', 'Somnolencia (raro)'],
    },
  ),

  DrugModel(
    id: 'levosimendan_f',
    group: 'Cardiovascular y HTA',
    name: 'Levosimendan (Simdax)',
    className: {'pt': 'Inodilatador / Sensibilizador de cálcio', 'es': 'Inodilatador / Sensibilizador de calcio'},
    category: {'pt': 'Vasoativo', 'es': 'Vasoactivo'},
    route: 'IV (Infusão)',
    doseType: 'weight',
    fixedDose: {
      'pt': 'Adulto: 0.1-0.2 mcg/kg/min por 24h. Pediátrico: 0.1-0.2 mcg/kg/min (Uso off-label em choque cardiogênico).',
      'es': 'Adulto: 0.1-0.2 mcg/kg/min por 24h. Pediátrico: 0.1-0.2 mcg/kg/min (Uso off-label en shock cardiogénico).',
    },
    renalAlert: {'pt': 'Contraindicado em insuficiência renal grave (ClCr < 30 mL/min).', 'es': 'Contraindicado en insuficiencia renal grave (ClCr < 30 mL/min).'},
    elderlyAlert: {'pt': 'Monitorar rigorosamente PA e FC devido ao risco de hipotensão e arritmias.', 'es': 'Monitorear rigurosamente PA y FC debido al riesgo de hipotensión.'},
    mechanism: {'pt': 'Sensibiliza troponina C ao cálcio (inotropismo) e abre canais de K+ (vasodilatação).', 'es': 'Sensibiliza troponina C al calcio (inotropismo) y abre canales de K+ (vasodilatación).'},
    warning: {'pt': 'Monitorar potássio (risco de hipocalemia). Efeito dura até 7 dias após parar infusão.', 'es': 'Monitorear potasio. El efecto dura hasta 7 días tras suspender la infusión.'},
    adverse: {
      'pt': ['Hipotensão', 'Taquicardia atrial', 'Hipocalemia', 'Cefaleia', 'Insônia'],
      'es': ['Hipotensión', 'Taquicardia atrial', 'Hipopotasemia', 'Cefalea', 'Insomnio'],
    },
  ),

  DrugModel(
    id: 'tigeciclina_f',
    group: 'Antibióticos',
    name: 'Tigeciclina (Tygacil)',
    className: {'pt': 'Glicilciclina (Amplo espectro)', 'es': 'Glicilciclina (Amplio espectro)'},
    category: {'pt': 'Antibióticos', 'es': 'Antibióticos'},
    route: 'IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Adulto: 100 mg ataque → 50 mg cada 12h. Pediátrico (>8 anos): 1.2 mg/kg cada 12h (máx 50 mg).',
      'es': 'Adulto: 100 mg carga → 50 mg cada 12h. Pediátrico (>8 años): 1.2 mg/kg cada 12h (máx 50 mg).',
    },
    renalAlert: {'pt': 'Sem ajuste necessário.', 'es': 'Sin ajuste necesario.'},
    elderlyAlert: {'pt': 'Geralmente bem tolerada.', 'es': 'Generalmente bien tolerada.'},
    mechanism: {'pt': 'Inibe a síntese proteica ligando-se à subunidade 30S do ribossomo. Ativa contra MRSA, VRE e carbapenem-resistentes.', 'es': 'Inhibe la síntesis proteica uniéndose a la subunidad 30S.'},
    warning: {'pt': 'Aumenta mortalidade em todas as causas (usar apenas se não houver alternativa). Não usar em infecções urinárias.', 'es': 'Aumenta la mortalidad (usar solo si no hay alternativa). No usar en infecciones urinarias.'},
    adverse: {
      'pt': ['Náusea intensa', 'Vômitos', 'Diarreia', 'Prolongamento de TTP', 'Pancreatite'],
      'es': ['Náusea intensa', 'Vómitos', 'Diarrea', 'Prolongamiento de TTP', 'Pancreatitis'],
    },
  ),

  DrugModel(
    id: 'sildenafil_p',
    group: 'Cardiovascular y HTA',
    name: 'Sildenafila (Revatio)',
    className: {'pt': 'Inibidor da fosfodiesterase tipo 5 (PDE5)', 'es': 'Inhibidor de la fosfodiesterasa tipo 5 (PDE5)'},
    category: {'pt': 'Hipertensão Pulmonar', 'es': 'Hipertensión Pulmonar'},
    route: 'VO / IV',
    doseType: 'weight',
    fixedDose: {
      'pt': 'Adulto: 20 mg 3x/dia. Pediátrico (HAP): 0.5-2 mg/kg/dose 3-4x/dia (máx 20 mg/dose).',
      'es': 'Adulto: 20 mg 3 veces/día. Pediátrico (HAP): 0.5-2 mg/kg/dosis 3-4 veces/día.',
    },
    renalAlert: {'pt': 'Sem ajuste necessário em insuficiência leve-moderada.', 'es': 'Sin ajuste necesario en insuficiencia leve-moderada.'},
    elderlyAlert: {'pt': 'Risco de hipotensão postural. Monitorar com outros anti-hipertensivos.', 'es': 'Riesgo de hipotensión postural. Monitorear con otros antihipertensivos.'},
    mechanism: {'pt': 'Aumenta o GMPc nas células musculares lisas vasculares, promovendo relaxamento e vasodilatação pulmonar.', 'es': 'Aumenta el GMPc promoviendo relajación y vasodilatación pulmonar.'},
    warning: {'pt': 'NUNCA usar com nitratos. Risco de colapso cardiovascular fatal.', 'es': 'NUNCA usar con nitratos. Riesgo de colapso cardiovascular fatal.'},
    adverse: {
      'pt': ['Cefaleia', 'Rubor facial', 'Dispepsia', 'Epistaxe', 'Distúrbios visuais (visão azulada)'],
      'es': ['Cefalea', 'Rubor facial', 'Dispepsia', 'Epistaxis', 'Disturbios visuales (visión azulada)'],
    },
  ),

  DrugModel(
    id: 'ceftolozana_taz',
    group: 'Antibióticos',
    name: 'Ceftolozana-Tazobactam (Zerbaxa)',
    className: {'pt': 'Cefalosporina + Inibidor de Beta-lactamase', 'es': 'Cefalosporina + Inhibidor de Beta-lactamasa'},
    category: {'pt': 'Antibióticos', 'es': 'Antibióticos'},
    route: 'IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Adulto: 1.5 g a cada 8h. Pediátrico: 30-40 mg/kg a cada 8h (máx 1.5 g).',
      'es': 'Adulto: 1.5 g cada 8h. Pediátrico: 30-40 mg/kg cada 8h (máx 1.5 g).',
    },
    renalAlert: {'pt': 'Ajuste obrigatório para ClCr < 50 mL/min.', 'es': 'Ajuste obligatorio para ClCr < 50 mL/min.'},
    elderlyAlert: {'pt': 'Monitorar função renal para ajuste de dose.', 'es': 'Monitorear función renal para ajuste de dosis.'},
    mechanism: {'pt': 'Potente ação contra Pseudomonas aeruginosa multirresistente e Enterobacteriaceae produtoras de ESBL.', 'es': 'Potente acción contra Pseudomonas aeruginosa multirresistente.'},
    warning: {'pt': 'Reservar para infecções graves complicadas (intra-abdominal ou urinária).', 'es': 'Reservar para infecciones graves complicadas.'},
    adverse: {
      'pt': ['Náusea', 'Diarreia', 'Cefaleia', 'Elevação de transaminases', 'Hipocalemia'],
      'es': ['Náusea', 'Diarrea', 'Cefalea', 'Elevación de transaminasas', 'Hipopotasemia'],
    },
  ),

  DrugModel(
    id: 'propinoxato_f',
    group: 'Gastroenterología',
    name: 'Propinoxato (Sertala / Viadil)',
    className: {'pt': 'Antiespasmódico / Anticolinérgico', 'es': 'Antiespasmódico / Anticolinérgico'},
    category: {'pt': 'Gastroenterologia', 'es': 'Gastroenterología'},
    route: 'VO / IV / IM',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Adulto: 10-20 mg cada 8h. Pediátrico (>12 anos): 10 mg cada 8h. Gotas: 1-2 gotas/kg/dia.',
      'es': 'Adulto: 10-20 mg cada 8h. Pediátrico (>12 años): 10 mg cada 8h. Gotas: 1-2 gotas/kg/día.',
    },
    renalAlert: {'pt': 'Usar com cautela em casos de retenção urinária.', 'es': 'Usar con cautela en casos de retención urinaria.'},
    elderlyAlert: {'pt': 'Alto risco de confusão, glaucoma de ângulo fechado e boca seca.', 'es': 'Alto riesgo de confusión, glaucoma y boca seca.'},
    mechanism: {'pt': 'Ação musculotrópica direta e anticolinérgica no músculo liso visceral.', 'es': 'Acción musculotrópica directa y anticolinérgica en músculo liso visceral.'},
    warning: {'pt': 'Medicamento de uso extremamente comum na Argentina.', 'es': 'Medicamento de uso muy común en Argentina.'},
    adverse: {
      'pt': ['Taquicardia', 'Visão turva', 'Boca seca', 'Constipação', 'Retenção urinária'],
      'es': ['Taquicardia', 'Visión borrosa', 'Boca seca', 'Estreñimiento', 'Retención urinaria'],
    },
  ),

  DrugModel(
    id: 'sulfato_ferroso_f',
    group: 'Hematología y Vitaminas',
    name: 'Sulfato Ferroso',
    className: {'pt': 'Suplemento mineral de ferro', 'es': 'Suplemento mineral de hierro'},
    category: {'pt': 'Hematologia', 'es': 'Hematología'},
    route: 'VO',
    doseType: 'weight',
    fixedDose: {
      'pt': 'Tratamento Anemia: Adulto 200 mg 1-3x/dia. Pediátrico: 3-6 mg/kg/dia de ferro elementar.',
      'es': 'Tratamiento Anemia: Adulto 200 mg 1-3 veces/día. Pediátrico: 3-6 mg/kg/día de hierro elemental.',
    },
    renalAlert: {'pt': 'Sem ajuste necessário.', 'es': 'Sin ajuste necesario.'},
    elderlyAlert: {'pt': 'Monitorar constipação severa e impacto fecal.', 'es': 'Monitorear estreñimiento severo e impacto fecal.'},
    mechanism: {'pt': 'Fornece o ferro necessário para a produção de hemoglobina e transporte de oxigênio.', 'es': 'Proporciona el hierro necesario para la producción de hemoglobina.'},
    warning: {'pt': 'Tomar 1h antes ou 2h depois das refeições. Vitamina C aumenta a absorção.', 'es': 'Tomar 1h antes o 2h después de comer. Vitamina C aumenta la absorción.'},
    adverse: {
      'pt': ['Fezes escuras', 'Constipação', 'Dor abdominal', 'Náuseas', 'Dano ao esmalte dentário (líquido)'],
      'es': ['Heces oscuras', 'Estreñimiento', 'Dolor abdominal', 'Náuseas', 'Daño al esmalte dental (líquido)'],
    },
  ),

  DrugModel(
    id: 'salbutamol_gotas_f',
    group: 'Respiratorio',
    name: 'Salbutamol (Ventolin - Gotas)',
    className: {'pt': 'Beta-2 agonista de curta ação', 'es': 'Beta-2 agonista de acción corta'},
    category: {'pt': 'Nebulização / Emergência', 'es': 'Nebulización / Emergencia'},
    route: 'Inalatório (Nebulização)',
    doseType: 'weight',
    fixedDose: {
      'pt': 'Adulto: 10-20 gotas (2.5-5 mg). Pediátrico: 1 gota a cada 2-3 kg (mín 5 gotas, máx 20) + 3ml SF.',
      'es': 'Adulto: 10-20 gotas (2.5-5 mg). Pediátrico: 1 gota cada 2-3 kg (mín 5 gotas, máx 20) + 3ml SF.',
    },
    renalAlert: {'pt': 'Sem ajuste necessário.', 'es': 'Sin ajuste necesario.'},
    elderlyAlert: {'pt': 'Risco de taquicardia e tremor; cautela em coronariopatas.', 'es': 'Riesgo de taquicardia y temblor; cautela en coronariópatas.'},
    mechanism: {'pt': 'Relaxamento da musculatura lisa brônquica por estimulação Beta-2.', 'es': 'Relajación de la musculatura lisa bronquial por estimulación Beta-2.'},
    warning: {'pt': 'Monitorar FC. Pode causar hipocalemia em doses altas.', 'es': 'Monitorear FC. Puede causar hipopotasemia en dosis altas.'},
    adverse: {
      'pt': ['Taquicardia', 'Tremores finos', 'Cefaleia', 'Palpitações', 'Hipocalemia'],
      'es': ['Taquicardia', 'Temblores finos', 'Cefalea', 'Palpitaciones', 'Hipopotasemia'],
    },
  ),

  DrugModel(
    id: 'ondansetrona_p',
    group: 'Gastroenterología',
    name: 'Ondansetrona (Zofran)',
    className: {'pt': 'Antiemético (Antagonista 5-HT3)', 'es': 'Antiemético (Antagonista 5-HT3)'},
    category: {'pt': 'Gastroenterologia', 'es': 'Gastroenterología'},
    route: 'VO / IV / SL',
    doseType: 'weight',
    fixedDose: {
      'pt': 'Adulto: 4-8 mg cada 8h. Pediátrico: 0.15 mg/kg por dose (máx 4-8 mg).',
      'es': 'Adulto: 4-8 mg cada 8h. Pediátrico: 0.15 mg/kg por dosis (máx 4-8 mg).',
    },
    renalAlert: {'pt': 'Sem ajuste necessário.', 'es': 'Sin ajuste necesario.'},
    elderlyAlert: {'pt': 'Monitorar intervalo QT.', 'es': 'Monitorear intervalo QT.'},
    mechanism: {'pt': 'Bloqueio seletivo de receptores de serotonina periféricos e centrais.', 'es': 'Bloqueo selectivo de receptores de serotonina periféricos y centrales.'},
    warning: {'pt': 'Pode prolongar o intervalo QT.', 'es': 'Puede prolongar el intervalo QT.'},
    adverse: {
      'pt': ['Cefaleia', 'Constipação', 'Sensação de calor', 'Fadiga', 'Tontura'],
      'es': ['Cefalea', 'Estreñimiento', 'Sensación de calor', 'Fatiga', 'Mareo'],
    },
  ),

  DrugModel(
    id: 'clonato_lisina',
    group: 'Analgésicos y Antipiréticos',
    name: 'Clonixinato de Lisina (Dorixina)',
    className: {'pt': 'AINE potente', 'es': 'AINE potente'},
    category: {'pt': 'Analgésicos', 'es': 'Analgésicos'},
    route: 'VO / IV / IM',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Adulto: 125-250 mg cada 6-8h. IV/IM: 100 mg cada 8h.',
      'es': 'Adulto: 125-250 mg cada 6-8h. IV/IM: 100 mg cada 8h.',
    },
    renalAlert: {'pt': 'Contraindicado em insuficiência renal grave.', 'es': 'Contraindicado en falla renal grave.'},
    elderlyAlert: {'pt': 'Risco de sangramento GI aumentado.', 'es': 'Riesgo de sangrado GI aumentado.'},
    mechanism: {'pt': 'Inibidor de síntese de prostaglandinas e ação central.', 'es': 'Inhibidor de síntesis de prostaglandinas y acción central.'},
    warning: {'pt': 'Uso extremamente comum na Argentina para dor moderada.', 'es': 'Uso extremadamente común en Argentina para dolor moderado.'},
    adverse: {
      'pt': ['Náuseas', 'Sonolência', 'Gastrite', 'Tontura', 'Rash'],
      'es': ['Náuseas', 'Somnolencia', 'Gastritis', 'Mareo', 'Rash'],
    },
  ),

  DrugModel(
    id: 'enalapril_p',
    group: 'Cardiovascular y HTA',
    name: 'Enalapril (Lotrial)',
    className: {'pt': 'IECA', 'es': 'IECA'},
    category: {'pt': 'Anti-hipertensivo', 'es': 'Antihipertensivo'},
    route: 'VO',
    doseType: 'weight',
    fixedDose: {
      'pt': 'Adulto: 5-40 mg/dia. Pediátrico: 0.08 mg/kg/dia até 0.5 mg/kg/dia.',
      'es': 'Adulto: 5-40 mg/día. Pediátrico: 0.08 mg/kg/día hasta 0.5 mg/kg/día.',
    },
    renalAlert: {'pt': 'Reduzir dose se ClCr < 30 mL/min.', 'es': 'Reducir dosis si ClCr < 30 mL/min.'},
    elderlyAlert: {'pt': 'Risco de hipotensão e hipercalemia.', 'es': 'Riesgo de hipotensión e hiperpotasemia.'},
    mechanism: {'pt': 'Inibidor da enzima conversora de angiotensina.', 'es': 'Inhibidor de la enzima convertidora de angiotensina.'},
    warning: {'pt': 'Contraindicado na gravidez.', 'es': 'Contraindicado en el embarazo.'},
    adverse: {
      'pt': ['Tosse seca', 'Hipercalemia', 'Hipotensão', 'Angioedema', 'Disfunção renal'],
      'es': ['Tos seca', 'Hiperpotasemia', 'Hipotensión', 'Angioedema', 'Disfunción renal'],
    },
  ),

  DrugModel(
    id: 'metronidazol_p',
    group: 'Antibióticos',
    name: 'Metronidazol (Flagyl)',
    className: {'pt': 'Nitroimidazol', 'es': 'Nitroimidazol'},
    category: {'pt': 'Antiprotozoário / Antibiótico', 'es': 'Antiprotozoario / Antibiótico'},
    route: 'VO / IV / Retal',
    doseType: 'weight',
    fixedDose: {
      'pt': 'Adulto: 500 mg cada 8h. Pediátrico: 30-45 mg/kg/dia ÷ 3 doses.',
      'es': 'Adulto: 500 mg cada 8h. Pediátrico: 30-45 mg/kg/día ÷ 3 dosis.',
    },
    renalAlert: {'pt': 'Ajustar dose se ClCr < 10 mL/min.', 'es': 'Ajustar dosis si ClCr < 10 mL/min.'},
    elderlyAlert: {'pt': 'Risco de neuropatia periférica e tontura.', 'es': 'Riesgo de neuropatía periférica y mareo.'},
    mechanism: {'pt': 'Dano ao DNA bacteriano por radicais livres.', 'es': 'Daño al DNA bacteriano por radicales libres.'},
    warning: {'pt': 'Efeito Antabuse (não ingerir álcool).', 'es': 'Efecto Antabuse (no ingerir alcohol).'},
    adverse: {
      'pt': ['Gosto metálico', 'Náuseas', 'Glossite', 'Cefaleia', 'Urina escura'],
      'es': ['Sabor metálico', 'Náuseas', 'Glositis', 'Cefalea', 'Orina oscura'],
    },
  ),

  DrugModel(
    id: 'lidocaina_spray',
    group: 'UCI – Críticos y Sedoanalgesia',
    name: 'Lidocaína (Spray / Gel)',
    className: {'pt': 'Anestésico Local', 'es': 'Anestésico Local'},
    category: {'pt': 'Procedimento', 'es': 'Procedimiento'},
    route: 'Tópica',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Aplicar conforme necessidade na área. Não exceder 4 mg/kg.',
      'es': 'Aplicar según necesidad en el área. No exceder 4 mg/kg.',
    },
    renalAlert: {'pt': 'Sem ajuste.', 'es': 'Sin ajuste.'},
    elderlyAlert: {'pt': 'Risco de absorção sistêmica e confusão mental.', 'es': 'Riesgo de absorción sistémica y confusión mental.'},
    mechanism: {'pt': 'Bloqueio reversível de canais de sódio nos axônios neuronais.', 'es': 'Bloqueo reversible de canales de sodio.'},
    warning: {'pt': 'Atenção para não abolir reflexo de tosse em procedimentos orais.', 'es': 'Atención para no abolir reflejo de tos en procedimientos orales.'},
    adverse: {
      'pt': ['Dormência local', 'Parestesia', 'Tontura (se absorvido)', 'Gosto amargo', 'Arritmia (raro)'],
      'es': ['Entumecimiento local', 'Parestesia', 'Mareo (si se absorbe)', 'Sabor amargo', 'Arritmia (raro)'],
    },
  ),

  DrugModel(
    id: 'fitomenadiona_f',
    group: 'Anticoagulantes y Hemostasia',
    name: 'Vitamina K (Fitomenadiona)',
    className: {'pt': 'Fator de coagulação / Vitamina', 'es': 'Factor de coagulación / Vitamina'},
    category: {'pt': 'Emergência / Hematologia', 'es': 'Emergencia / Hematología'},
    route: 'VO / SC / IV Lento',
    doseType: 'weight',
    fixedDose: {
      'pt': 'Adulto: 1-10 mg. Pediátrico: 0.1-0.2 mg/kg/dose.',
      'es': 'Adulto: 1-10 mg. Pediátrico: 0.1-0.2 mg/kg/dosis.',
    },
    renalAlert: {'pt': 'Sem ajuste necessário.', 'es': 'Sin ajuste necesario.'},
    elderlyAlert: {'pt': 'Geralmente seguro.', 'es': 'Generalmente seguro.'},
    mechanism: {'pt': 'Promove a síntese hepática dos fatores II, VII, IX e X.', 'es': 'Promueve la síntesis hepática de los factores II, VII, IX y X.'},
    warning: {'pt': 'Risco de anafilaxia se IV rápido; infundir em 30 min.', 'es': 'Riesgo de anafilaxia si es IV rápido; infundir en 30 min.'},
    adverse: {
      'pt': ['Rubor facial', 'Sudorese', 'Sensação de aperto no peito', 'Dispneia', 'Hipotensão'],
      'es': ['Rubor facial', 'Sudoración', 'Sensación de opresión en el pecho', 'Disnea', 'Hipotensión'],
    },
  ),

  DrugModel(
    id: 'heparina_nf_f',
    group: 'Anticoagulantes y Hemostasia',
    name: 'Heparina Sódica (HNF)',
    className: {'pt': 'Anticoagulante parenteral', 'es': 'Anticoagulante parenteral'},
    category: {'pt': 'Emergência', 'es': 'Emergencia'},
    route: 'IV / SC',
    doseType: 'weight',
    fixedDose: {
      'pt': 'SCA: 60-80 UI/kg ataque → 12-18 UI/kg/h. Ped: 50 UI/kg ataque → 20 UI/kg/h.',
      'es': 'SCA: 60-80 UI/kg carga → 12-18 UI/kg/h. Ped: 50 UI/kg carga → 20 UI/kg/h.',
    },
    renalAlert: {'pt': 'Considerado seguro em insuficiência renal (monitorar TTPA).', 'es': 'Considerado seguro en insuficiencia renal (monitorear TTPA).'},
    elderlyAlert: {'pt': 'Alto risco de sangramento espontâneo.', 'es': 'Alto riesgo de sangrado espontáneo.'},
    mechanism: {'pt': 'Ativa a antitrombina III que inibe a trombina e o fator Xa.', 'es': 'Activa la antitrombina III que inhibe la trombina y el factor Xa.'},
    warning: {'pt': 'Monitorar plaquetas (risco de HIT). Antídoto: Protamina.', 'es': 'Monitorear plaquetas (riesgo de HIT). Antídoto: Protamina.'},
    adverse: {
      'pt': ['Sangramento', 'Trombocitopenia (HIT)', 'Osteoporose (longo prazo)', 'Alopecia', 'Elevação de transaminases'],
      'es': ['Sangrado', 'Trombocitopenia (HIT)', 'Osteoporosis (largo plazo)', 'Alopecia', 'Elevación de transaminasas'],
    },
  ),

  DrugModel(
    id: 'albumina_f',
    group: 'Endocrinología y Metabolismo',
    name: 'Albumina Humana 20%',
    className: {'pt': 'Expansor plasmático', 'es': 'Expansor plasmático'},
    category: {'pt': 'Urgência / Hepatologia', 'es': 'Urgencia / Hepatología'},
    route: 'IV',
    doseType: 'weight',
    fixedDose: {
      'pt': 'Paracentese: 6-8 g por litro extraído. Choque Ped: 0.5-1 g/kg.',
      'es': 'Paracentesis: 6-8 g por litro extraído. Shock Ped: 0.5-1 g/kg.',
    },
    renalAlert: {'pt': 'Cuidado com sobrecarga hídrica em anúria.', 'es': 'Cuidado con sobrecarga hídrica en anuria.'},
    elderlyAlert: {'pt': 'Alto risco de edema agudo de pulmão em cardiopatas.', 'es': 'Alto riesgo de edema agudo de pulmón en cardiópatas.'},
    mechanism: {'pt': 'Mantém a pressão oncótica intravascular e transporta hormônios/fármacos.', 'es': 'Mantiene la presión oncótica intravascular.'},
    warning: {'pt': 'Não usar soluções com turvação ou depósitos.', 'es': 'No usar soluciones con turbidez o depósitos.'},
    adverse: {
      'pt': ['Edema pulmonar', 'Insuficiência cardíaca', 'Febre', 'Rash', 'Hipotensão'],
      'es': ['Edema pulmonar', 'Insuficiencia cardíaca', 'Fiebre', 'Rash', 'Hipotensión'],
    },
  ),

  DrugModel(
    id: 'clortalidona_f',
    group: 'Cardiovascular y HTA',
    name: 'Clortalidona (Higroton)',
    className: {'pt': 'Diurético tiazídico de longa ação', 'es': 'Diurético tiazídico de larga acción'},
    category: {'pt': 'Anti-hipertensivo', 'es': 'Antihipertensivo'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Adulto: 12.5-50 mg/dia. Pediátrico: 0.3-1 mg/kg/dia.',
      'es': 'Adulto: 12.5-50 mg/día. Pediátrico: 0.3-1 mg/kg/día.',
    },
    renalAlert: {'pt': 'Ineficaz se TFG < 30 mL/min.', 'es': 'Ineficaz si TFG < 30 mL/min.'},
    elderlyAlert: {'pt': 'Risco elevado de hiponatremia grave e quedas.', 'es': 'Riesgo elevado de hiponatremia grave y caídas.'},
    mechanism: {'pt': 'Inibe cotransporte Na-Cl no túbulo distal; t1/2 longa (40h).', 'es': 'Inhibe cotransporte Na-Cl en el túbulo distal.'},
    warning: {'pt': 'Preferida em relação à HCTZ em protocolos de HAS.', 'es': 'Preferida respecto a la HCTZ en protocolos de HTA.'},
    adverse: {
      'pt': ['Hiponatremia', 'Hipocalemia', 'Hiperglicemia', 'Hiperuricemia', 'Câimbras'],
      'es': ['Hiponatremia', 'Hipopotasemia', 'Hiperglucemia', 'Hiperuricemia', 'Calambres'],
    },
  ),

  DrugModel(
    id: 'dexclorfeniramina_f',
    group: 'Varios / Antídotos / Otros',
    name: 'Dexclorfeniramina (Polaramine)',
    className: {'pt': 'Anti-histamínico H1 sedativo', 'es': 'Antihistamínico H1 sedativo'},
    category: {'pt': 'Alergia', 'es': 'Alergia'},
    route: 'VO / Tópica',
    doseType: 'weight',
    fixedDose: {
      'pt': 'Adulto: 2 mg cada 6-8h. Pediátrico: 0.15 mg/kg/dia ÷ 3-4 doses.',
      'es': 'Adulto: 2 mg cada 6-8h. Pediátrico: 0.15 mg/kg/día ÷ 3-4 dosis.',
    },
    renalAlert: {'pt': 'Sem ajuste necessário.', 'es': 'Sin ajuste necesario.'},
    elderlyAlert: {'pt': 'Beers: evitar (risco de queda e sedação).', 'es': 'Beers: evitar (riesgo de caída y sedación).'},
    mechanism: {'pt': 'Antagonista H1 clássico com alta afinidade central.', 'es': 'Antagonista H1 clásico.'},
    warning: {'pt': 'Muito usado na Argentina em gotas.', 'es': 'Muy usado en Argentina en gotas.'},
    adverse: {
      'pt': ['Sedação intensa', 'Boca seca', 'Retenção urinária', 'Visão turva', 'Constipação'],
      'es': ['Sedación intensa', 'Boca seca', 'Retención urinaria', 'Visión borrosa', 'Estreñimiento'],
    },
  ),

  DrugModel(
    id: 'clorpromazina_f',
    group: 'Neurología y Psiquiatría',
    name: 'Clorpromazina (Amplictil)',
    className: {'pt': 'Antipsicótico Típico / Sedativo', 'es': 'Antipsicótico Típico / Sedante'},
    category: {'pt': 'Psiquiatria / Emergência', 'es': 'Psiquiatría / Emergencia'},
    route: 'VO / IM / IV lento',
    doseType: 'weight',
    fixedDose: {
      'pt': 'Psicose Adulto: 25-50 mg IM. Ped: 0.5 mg/kg/dose cada 8h.',
      'es': 'Psicosis Adulto: 25-50 mg IM. Ped: 0.5 mg/kg/dosis cada 8h.',
    },
    renalAlert: {'pt': 'Sem ajuste.', 'es': 'Sin ajuste.'},
    elderlyAlert: {'pt': 'Risco alto de hipotensão postural e EPS.', 'es': 'Riesgo alto de hipotensión y EPS.'},
    mechanism: {'pt': 'Antagonista de receptores dopaminérgicos D2.', 'es': 'Antagonista de receptores D2.'},
    warning: {'pt': 'Monitorar temperatura (risco de SMN).', 'es': 'Monitorear temperatura (riesgo de SMN).'},
    adverse: {
      'pt': ['Hipotensão ortostática', 'Sedação', 'Sintomas extrapiramidais', 'Boca seca', 'Galactorreia'],
      'es': ['Hipotensión ortostática', 'Sedación', 'Sintomas extrapiramidales', 'Boca seca', 'Galactorrea'],
    },
  ),

  DrugModel(
    id: 'amiodarona_f',
    group: 'Cardiovascular y HTA',
    name: 'Amiodarona (Atlantil)',
    className: {'pt': 'Antiarrítmico Classe III', 'es': 'Antiarrítmico Clase III'},
    category: {'pt': 'Emergência / Cardiologia', 'es': 'Emergencia / Cardiología'},
    route: 'VO / IV',
    doseType: 'weight',
    fixedDose: {
      'pt': 'PCR: 300 mg → 150 mg. Ped: 5 mg/kg bolus. Manutenção: 900 mg/24h.',
      'es': 'PCR: 300 mg → 150 mg. Ped: 5 mg/kg bolo. Mantenimiento: 900 mg/24h.',
    },
    renalAlert: {'pt': 'Sem ajuste necessário.', 'es': 'Sin ajuste necesario.'},
    elderlyAlert: {'pt': 'Alto risco de hipotireoidismo e toxicidade pulmonar.', 'es': 'Alto riesgo de hipotiroidismo y toxicidad pulmonar.'},
    mechanism: {'pt': 'Prolonga a duração do potencial de ação; bloqueia canais de K, Na e Ca.', 'es': 'Prolonga el potencial de acción.'},
    warning: {'pt': 'Incompatível com SF 0.9% para infusão; usar SG 5%.', 'es': 'Incompatible con SF 0.9% para infusión; usar SG 5%.'},
    adverse: {
      'pt': ['Bradicardia', 'Depósitos na córnea', 'Fibrose pulmonar', 'Fotossensibilidade', 'Hipotireoidismo'],
      'es': ['Bradicardia', 'Depósitos en la córnea', 'Fibrosis pulmonar', 'Fotosensibilidad', 'Hipotiroidismo'],
    },
  ),

  DrugModel(
    id: 'ciprofloxacino_f',
    group: 'Antibióticos',
    name: 'Ciprofloxacino (Ciriax)',
    className: {'pt': 'Fluoroquinolona 2ª Geração', 'es': 'Fluoroquinolona 2ª Generación'},
    category: {'pt': 'Antibióticos', 'es': 'Antibióticos'},
    route: 'VO / IV / Tópico',
    doseType: 'weight',
    fixedDose: {
      'pt': 'Adulto: 500-750 mg cada 12h. Pediátrico (Uso restrito): 10-20 mg/kg cada 12h.',
      'es': 'Adulto: 500-750 mg cada 12h. Pediátrico (Uso restringido): 10-20 mg/kg cada 12h.',
    },
    renalAlert: {'pt': 'Ajustar dose se ClCr < 50 mL/min.', 'es': 'Ajustar dosis si ClCr < 50 mL/min.'},
    elderlyAlert: {'pt': 'Risco aumentado de rotura de tendão e confusão mental.', 'es': 'Riesgo de rotura de tendón y confusión mental.'},
    mechanism: {'pt': 'Inibe a DNA-girase bacteriana; bactericida.', 'es': 'Inhibe la DNA-girasa bacteriana.'},
    warning: {'pt': 'Evitar uso em crianças pelo risco de artropatia (exceto Fibrose Cística).', 'es': 'Evitar en niños (riesgo de artropatía).'},
    adverse: {
      'pt': ['Náuseas', 'Diarreia', 'Tontura', 'Tendinite', 'Prolongamento de QT'],
      'es': ['Náuseas', 'Diarrea', 'Mareo', 'Tendinitis', 'Prolongamiento de QT'],
    },
  ),

  DrugModel(
    id: 'anfotericina_b_f',
    group: 'Infectología (Antifúngicos / Antivirales / TBC)',
    name: 'Anfotericina B (Deoxicolato)',
    className: {'pt': 'Antifúngico Poliênico', 'es': 'Antifúngico Poliénico'},
    category: {'pt': 'Hospitalar', 'es': 'Hospitalaria'},
    route: 'IV Infusão Lenta',
    doseType: 'weight',
    fixedDose: {
      'pt': 'Adulto/Pediátrico: 0.5-1.5 mg/kg/dia. Teste inicial com 1 mg.',
      'es': 'Adulto/Pediátrico: 0.5-1.5 mg/kg/día. Prueba inicial con 1 mg.',
    },
    renalAlert: {'pt': 'Altamente nefrotóxico; monitorar Cr e K diariamente.', 'es': 'Altamente nefrotóxico; monitorear Cr y K.'},
    elderlyAlert: {'pt': 'Usar apenas formulação lipossômica se disponível.', 'es': 'Usar solo formulación liposomal si está disponible.'},
    mechanism: {'pt': 'Cria poros na membrana fúngica ligando-se ao ergosterol.', 'es': 'Crea poros en la membrana fúngica.'},
    warning: {'pt': 'Infundir com hidratação salina prévia para reduzir nefrotoxicidade.', 'es': 'Infundir con hidratación salina previa.'},
    adverse: {
      'pt': ['Nefrotoxicidade', 'Hipocalemia', 'Febre e calafrios', 'Anemia', 'Tromboflebite'],
      'es': ['Nefrotoxicidad', 'Hipopotasemia', 'Fiebre y escalofríos', 'Anemia', 'Tromboflebitis'],
    },
  ),

  DrugModel(
    id: 'mupirocina_f',
    group: 'Varios / Antídotos / Otros',
    name: 'Mupirocina (Bactroban - Pomada)',
    className: {'pt': 'Antibiótico tópico', 'es': 'Antibiótico tópico'},
    category: {'pt': 'Dermatologia', 'es': 'Dermatología'},
    route: 'Tópica',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Aplicar 2-3x/dia na área afetada por 7-10 dias.',
      'es': 'Aplicar 2-3 veces/día en el área por 7-10 días.',
    },
    renalAlert: {'pt': 'Sem ajuste.', 'es': 'Sin ajuste.'},
    elderlyAlert: {'pt': 'Seguro.', 'es': 'Seguro.'},
    mechanism: {'pt': 'Inibe a síntese proteica bacteriana (tRNA sintetase).', 'es': 'Inhibe la síntesis proteica bacteriana.'},
    warning: {'pt': 'Ideal para impetigo e descolonização nasal de MRSA.', 'es': 'Ideal para impétigo y MRSA nasal.'},
    adverse: {
      'pt': ['Ardor local', 'Prurido', 'Eritema', 'Ressecamento cutâneo', 'Náusea (raro)'],
      'es': ['Ardor local', 'Prurito', 'Eritema', 'Sequedad cutánea', 'Náusea (raro)'],
    },
  ),

  DrugModel(
    id: 'permetrina_f',
    group: 'Varios / Antídotos / Otros',
    name: 'Permetrina 5% (Creme)',
    className: {'pt': 'Escabicida', 'es': 'Escabicida'},
    category: {'pt': 'Dermatologia', 'es': 'Dermatología'},
    route: 'Tópica',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Escabiose: aplicar do pescoço aos pés; lavar após 8-14h. Repetir em 1 semana.',
      'es': 'Escabiosis: aplicar del cuello a los pies; lavar tras 8-14h. Repetir en 1 semana.',
    },
    renalAlert: {'pt': 'Sem ajuste.', 'es': 'Sin ajuste.'},
    elderlyAlert: {'pt': 'Seguro.', 'es': 'Seguro.'},
    mechanism: {'pt': 'Interrupção dos canais de sódio causando paralisia do ácaro.', 'es': 'Interrupción de los canales de sodio.'},
    warning: {'pt': 'Tratar todos os contatos domiciliares.', 'es': 'Tratar a todos los contactos domiciliarios.'},
    adverse: {
      'pt': ['Ardência transitória', 'Prurido persistente', 'Edema local', 'Eritema', 'Parestesia'],
      'es': ['Ardor transitorio', 'Prurito persistente', 'Edema local', 'Eritema', 'Parestesia'],
    },
  ),

  DrugModel(
    id: 'clobetasol_f',
    group: 'Varios / Antídotos / Otros',
    name: 'Clobetasol 0.05% (Dermovate)',
    className: {'pt': 'Corticoide Tópico Alta Potência', 'es': 'Corticoide Tópico Alta Potencia'},
    category: {'pt': 'Dermatologia', 'es': 'Dermatología'},
    route: 'Tópica',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Aplicar 1-2x/dia. Limitar uso a 2 semanas seguidas.',
      'es': 'Aplicar 1-2 veces/día. Limitar uso a 2 semanas.',
    },
    renalAlert: {'pt': 'Sem ajuste.', 'es': 'Sin ajuste.'},
    elderlyAlert: {'pt': 'Risco elevado de atrofia cutânea e púrpuras.', 'es': 'Mayor riesgo de atrofia cutánea y púrpuras.'},
    mechanism: {'pt': 'Anti-inflamatório local potente.', 'es': 'Antiinflamatorio local potente.'},
    warning: {'pt': 'Não usar em áreas de dobras ou face.', 'es': 'No usar en áreas de pliegues o cara.'},
    adverse: {
      'pt': ['Atrofia cutânea', 'Estrias', 'Telangiectasias', 'Foliculite', 'Hipopigmentação'],
      'es': ['Atrofia cutánea', 'Estrías', 'Telangiectasias', 'Foliculitis', 'Hipopigmentación'],
    },
  ),

  DrugModel(
    id: 'hioscina_dipirona',
    group: 'Gastroenterología',
    name: 'Hioscina + Dipirona (Buscapina Composite)',
    className: {'pt': 'Antiespasmódico + Analgésico', 'es': 'Antiespasmódico + Analgésico'},
    category: {'pt': 'Gastrointestinal / Dor', 'es': 'Gastrointestinal / Dolor'},
    route: 'VO / IV / IM',
    doseType: 'weight',
    fixedDose: {
      'pt': 'Adulto: 1 ampola (5ml) IV lento. Pediatria: 0.1-0.2 ml/kg por dose (mín 1 gota/kg).',
      'es': 'Adulto: 1 ampolla (5ml) IV lento. Pediatría: 0.1-0.2 ml/kg por dosis (mín 1 gota/kg).',
    },
    renalAlert: {'pt': 'Evitar em ClCr < 30 mL/min devido à dipirona.', 'es': 'Evitar en ClCr < 30 mL/min por la dipirona.'},
    elderlyAlert: {'pt': 'Risco de confusão mental e retenção urinária pela hioscina.', 'es': 'Riesgo de confusión y retención urinaria por hioscina.'},
    mechanism: {'pt': 'Antagonista colinérgico (muscarínico) e inibição da COX central.', 'es': 'Antagonista colinérgico e inhibición de COX central.'},
    warning: {'pt': 'IV deve ser muito lento (risco de hipotensão severa).', 'es': 'IV debe ser muy lento (riesgo de hipotensión).'},
    adverse: {
      'pt': ['Boca seca', 'Visão turva', 'Hipotensão', 'Taquicardia', 'Agranulocitose'],
      'es': ['Boca seca', 'Visión borrosa', 'Hipotensión', 'Taquicardia', 'Agranulocitosis'],
    },
  ),

  DrugModel(
    id: 'diclo_pridinol',
    group: 'Analgésicos y Antipiréticos',
    name: 'Diclofenac + Pridinol (Blokium Flex)',
    className: {'pt': 'AINE + Relaxante Muscular', 'es': 'AINE + Relaxante Muscular'},
    category: {'pt': 'Músculo-esquelético', 'es': 'Músculo-esquelético'},
    route: 'VO / IM',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Adulto: 1 comprimido ou ampola cada 12h. Não recomendado em pediatria.',
      'es': 'Adulto: 1 comprimido o ampolla cada 12h. No recomendado en pediatría.',
    },
    renalAlert: {'pt': 'Evitar em insuficiência renal grave.', 'es': 'Evitar en falla renal grave.'},
    elderlyAlert: {'pt': 'Risco elevado de quedas e sangramento gástrico.', 'es': 'Riesgo elevado de caídas y sangrado gástrico.'},
    mechanism: {'pt': 'Inibe COX-1/2 e exerce efeito anticolinérgico central relaxante.', 'es': 'Inhibe COX-1/2 y efecto anticolinérgico central.'},
    warning: {'pt': 'Uso muito frequente na Argentina para lombalgias.', 'es': 'Uso muy frecuente en Argentina para lumbalgias.'},
    adverse: {
      'pt': ['Gastrite', 'Tontura', 'Boca seca', 'Sonolência', 'Retenção hídrica'],
      'es': ['Gastritis', 'Mareo', 'Boca seca', 'Somnolencia', 'Retención hídrica'],
    },
  ),

  DrugModel(
    id: 'betametasona_mepred',
    group: 'Endocrinología y Metabolismo',
    name: 'Meprednisona (Deltisona)',
    className: {'pt': 'Glicocorticoide', 'es': 'Glucocorticoide'},
    category: {'pt': 'Corticosteroides', 'es': 'Corticosteroides'},
    route: 'VO',
    doseType: 'weight',
    fixedDose: {
      'pt': 'Adulto: 4-60 mg/dia. Pediatria: 0.5-2 mg/kg/dia.',
      'es': 'Adulto: 4-60 mg/día. Pediatría: 0.5-2 mg/kg/día.',
    },
    renalAlert: {'pt': 'Pode causar retenção hídrica.', 'es': 'Puede causar retención hídrica.'},
    elderlyAlert: {'pt': 'Monitorar PA e glicose.', 'es': 'Monitorear PA y glucosa.'},
    mechanism: {'pt': 'Modulação da resposta inflamatória e imunológica.', 'es': 'Modulación de respuesta inflamatoria.'},
    warning: {'pt': 'Corticóide oral mais prescrito na Argentina.', 'es': 'Corticoide oral más prescrito en Argentina.'},
    adverse: {
      'pt': ['Fácies de lua cheia', 'Hiperglicemia', 'Osteoporose', 'Estrias', 'Catarata'],
      'es': ['Fascie lunar', 'Hiperglucemia', 'Osteoporosis', 'Estrías', 'Catarata'],
    },
  ),

  DrugModel(
    id: 'amikacina_f',
    group: 'Antibióticos',
    name: 'Amicacina',
    className: {'pt': 'Aminoglicosídeo', 'es': 'Aminoglucósido'},
    category: {'pt': 'Antibióticos', 'es': 'Antibióticos'},
    route: 'IV / IM',
    doseType: 'weight',
    fixedDose: {
      'pt': 'Adulto/Pediátrico: 15-20 mg/kg dose única diária.',
      'es': 'Adulto/Pediátrico: 15-20 mg/kg dosis única diaria.',
    },
    renalAlert: {'pt': 'Altamente nefrotóxico; monitorar creatinina.', 'es': 'Altamente nefrotóxico; monitorear Cr.'},
    elderlyAlert: {'pt': 'Alto risco de ototoxicidade irreversível.', 'es': 'Alto riesgo de ototoxicidad irreversible.'},
    mechanism: {'pt': 'Inibe síntese proteica (unidade 30S).', 'es': 'Inhibe síntesis proteica (30S).'},
    warning: {'pt': 'Monitorar níveis séricos se possível.', 'es': 'Monitorear niveles séricos.'},
    adverse: {
      'pt': ['Nefrotoxicidade', 'Surdez', 'Vertigem', 'Bloqueio neuromuscular', 'Rash'],
      'es': ['Nefrotoxicidad', 'Sordera', 'Vértigo', 'Bloqueo neuromuscular', 'Rash'],
    },
  ),

  DrugModel(
    id: 'metoclopramida_p',
    group: 'Gastroenterología',
    name: 'Metoclopramida (Reliveran)',
    className: {'pt': 'Procinético e Antiemético', 'es': 'Procinético y Antiemético'},
    category: {'pt': 'Gastrointestinal', 'es': 'Gastrointestinal'},
    route: 'VO / IV / IM',
    doseType: 'weight',
    fixedDose: {
      'pt': 'Adulto: 10 mg cada 8h. Pediátrico: 0.1-0.15 mg/kg por dose.',
      'es': 'Adulto: 10 mg cada 8h. Pediatría: 0.1-0.15 mg/kg por dosis.',
    },
    renalAlert: {'pt': 'Reduzir dose em 50% se ClCr < 40.', 'es': 'Reducir dosis al 50% si ClCr < 40.'},
    elderlyAlert: {'pt': 'Beers: evitar (risco de parkinsonismo e discinesia).', 'es': 'Beers: evitar (riesgo de parkinsonismo).'},
    mechanism: {'pt': 'Antagonista dopaminérgico D2 central e periférico.', 'es': 'Antagonista dopaminérgico D2.'},
    warning: {'pt': 'Na Argentina, Reliveran é sinônimo de antiemético.', 'es': 'En Argentina, Reliveran es el antiemético estándar.'},
    adverse: {
      'pt': ['Acatisia', 'Distonia aguda', 'Sonolência', 'Diarreia', 'Hiperprolactinemia'],
      'es': ['Acatisia', 'Distonía aguda', 'Somnolencia', 'Diarrea', 'Hiperprolactinemia'],
    },
  ),

  DrugModel(
    id: 'esmolol_f',
    group: 'UCI – Críticos y Sedoanalgesia',
    name: 'Esmolol (Brevibloc)',
    className: {'pt': 'Betabloqueador de ação ultra-curta', 'es': 'Betabloqueante de acción ultracorta'},
    category: {'pt': 'Emergência / UTI', 'es': 'Emergencia / UTI'},
    route: 'IV',
    doseType: 'weight',
    fixedDose: {
      'pt': 'Adulto: 500 mcg/kg (1 min) → 50-200 mcg/kg/min.',
      'es': 'Adulto: 500 mcg/kg (1 min) → 50-200 mcg/kg/min.',
    },
    renalAlert: {'pt': 'Sem ajuste necessário.', 'es': 'Sin ajuste necesario.'},
    elderlyAlert: {'pt': 'Hipotensão severa e súbita.', 'es': 'Hipotensión severa.'},
    mechanism: {'pt': 'Antagonista Beta-1 seletivo; t1/2 de 9 minutos.', 'es': 'Antagonista Beta-1 seletivo; t1/2 9 min.'},
    warning: {'pt': 'Ideal para controle de FC em dissecção aórtica.', 'es': 'Ideal para disección aórtica.'},
    adverse: {
      'pt': ['Hipotensão (comum)', 'Bradicardia', 'Flebite', 'Broncoespasmo', 'Náuseas'],
      'es': ['Hipotensión', 'Bradicardia', 'Flebitis', 'Broncoespasmo', 'Náuseas'],
    },
  ),

  DrugModel(
    id: 'labetalol_p',
    group: 'Cardiovascular y HTA',
    name: 'Labetalol (Trandate)',
    className: {'pt': 'Betabloqueador Alfa/Beta', 'es': 'Betabloqueante Alfa/Beta'},
    category: {'pt': 'Emergência Hipertensiva', 'es': 'Emergencia Hipertensiva'},
    route: 'VO / IV',
    doseType: 'weight',
    fixedDose: {
      'pt': 'Adulto: 20 mg bólus IV. Pediatria: 0.2-1 mg/kg (bolus) ou 0.4-3 mg/kg/h.',
      'es': 'Adulto: 20 mg bolo IV. Pediatría: 0.2-1 mg/kg (bolo) o 0.4-3 mg/kg/h.',
    },
    renalAlert: {'pt': 'Sem ajuste necessário.', 'es': 'Sin ajuste necesario.'},
    elderlyAlert: {'pt': 'Hipotensão ortostática grave.', 'es': 'Hipotensión ortostática.'},
    mechanism: {'pt': 'Bloqueio Beta não seletivo e Alfa-1 seletivo.', 'es': 'Bloqueo Beta y Alfa-1.'},
    warning: {'pt': 'Escolha em Pré-eclâmpsia e AVC.', 'es': 'Elección en Preeclampsia.'},
    adverse: {
      'pt': ['Bradicardia', 'Broncoespasmo', 'Hipotensão', 'Congestão nasal', 'Parestesia do couro cabeludo'],
      'es': ['Bradicardia', 'Broncoespasmo', 'Hipotensión', 'Congestión nasal', 'Parestesia cuero cabelludo'],
    },
  ),

  DrugModel(
    id: 'nifedipino_p',
    group: 'Cardiovascular y HTA',
    name: 'Nifedipino (Adalat)',
    className: {'pt': 'Bloqueador de Canal de Cálcio', 'es': 'Bloqueante de Canal de Calcio'},
    category: {'pt': 'Anti-hipertensivo', 'es': 'Antihipertensivo'},
    route: 'VO / SL (Não recomendado)',
    doseType: 'weight',
    fixedDose: {
      'pt': 'Adulto: 10-30 mg cada 8-12h. Pediátrico: 0.25-0.5 mg/kg/dose.',
      'es': 'Adulto: 10-30 mg cada 8-12h. Pediatría: 0.25-0.5 mg/kg/dosis.',
    },
    renalAlert: {'pt': 'Sem ajuste necessário.', 'es': 'Sin ajuste necesario.'},
    elderlyAlert: {'pt': 'Risco de taquicardia reflexa e edema.', 'es': 'Riesgo de taquicardia refleja.'},
    mechanism: {'pt': 'Vasodilatação arterial por bloqueio de canais de Cálcio L.', 'es': 'Vasodilatación arterial.'},
    warning: {'pt': 'Não usar cápsulas de curta ação em emergência (risco AVC).', 'es': 'No usar cápsulas de acción corta en emergencia.'},
    adverse: {
      'pt': ['Edema maleolar', 'Cefaleia', 'Rubor facial', 'Palpitações', 'Constipação'],
      'es': ['Edema maleolar', 'Cefalea', 'Rubor facial', 'Palpitaciones', 'Estreñimiento'],
    },
  ),

  DrugModel(
    id: 'acetazolamida_f',
    group: 'Varios / Antídotos / Otros',
    name: 'Acetazolamida (Diamox)',
    className: {'pt': 'Inibidor da Anidrase Carbônica', 'es': 'Inhibidor de la Anidrasa Carbónica'},
    category: {'pt': 'Diurético / Glaucoma', 'es': 'Diurético / Glaucoma'},
    route: 'VO / IV',
    doseType: 'weight',
    fixedDose: {
      'pt': 'Adulto: 250 mg cada 6-12h. Pediátrico: 8-30 mg/kg/dia.',
      'es': 'Adulto: 250 mg cada 6-12h. Pediatría: 8-30 mg/kg/día.',
    },
    renalAlert: {'pt': 'Contraindicado se ClCr < 10 mL/min.', 'es': 'Contraindicado si ClCr < 10 mL/min.'},
    elderlyAlert: {'pt': 'Risco de acidose metabólica e hipocalemia.', 'es': 'Riesgo de acidosis metabólica.'},
    mechanism: {'pt': 'Reduz formação de bicarbonato e secreção de humor aquoso.', 'es': 'Reduce secreción de humor acuoso.'},
    warning: {'pt': 'Útil no Mal de Montanha.', 'es': 'Útil en el Mal de Montaña.'},
    adverse: {
      'pt': ['Parestesias', 'Acidose metabólica', 'Hipocalemia', 'Poliúria', 'Cálculo renal'],
      'es': ['Parestesias', 'Acidosis metabólica', 'Hipopotasemia', 'Poliuria', 'Cálculo renal'],
    },
  ),

  DrugModel(
    id: 'kayexalate_f',
    group: 'Varios / Antídotos / Otros',
    name: 'Poliestirenossulfonato de Cálcio / Sódio',
    className: {'pt': 'Resina de troca catiônica', 'es': 'Resina de intercambio catiónico'},
    category: {'pt': 'Emergência / Hipercalemia', 'es': 'Emergencia / Hiperpotasemia'},
    route: 'VO / Retal',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Adulto: 15-30 g cada 6-8h. Pediatria: 1 g/kg/dose.',
      'es': 'Adulto: 15-30 g cada 6-8h. Pediatría: 1 g/kg/dosis.',
    },
    renalAlert: {'pt': 'Usado para tratar insuficiência renal.', 'es': 'Usado en falla renal.'},
    elderlyAlert: {'pt': 'Risco de necrose intestinal (especialmente com sorbitol).', 'es': 'Riesgo de necrosis intestinal.'},
    mechanism: {'pt': 'Troca Cálcio/Sódio por Potássio no intestino grosso.', 'es': 'Intercambia Ca/Na por K en el colon.'},
    warning: {'pt': 'Ação lenta (2-12h); não usar isolado em emergência severa.', 'es': 'Acción lenta (2-12h).'},
    adverse: {
      'pt': ['Constipação', 'Náuseas', 'Hipocalemia (excessiva)', 'Necrose colônica', 'Vômitos'],
      'es': ['Constipación', 'Náuseas', 'Hipopotasemia', 'Necrosis colónica', 'Vómitos'],
    },
  ),

  DrugModel(
    id: 'milrinona_f',
    group: 'UCI – Críticos y Sedoanalgesia',
    name: 'Milrinona (Primacor)',
    className: {'pt': 'Inodilatador', 'es': 'Inodilatador'},
    category: {'pt': 'Insuficiência Cardíaca', 'es': 'Insuficiencia Cardíaca'},
    route: 'IV (Bomba)',
    doseType: 'weight',
    fixedDose: {
      'pt': 'Ataque: 50 mcg/kg (10 min). Manutenção: 0.375-0.75 mcg/kg/min.',
      'es': 'Carga: 50 mcg/kg (10 min). Mantenimiento: 0.375-0.75 mcg/kg/min.',
    },
    renalAlert: {'pt': 'Reduzir dose em 50-70% se ClCr < 50 mL/min.', 'es': 'Reducir dosis si ClCr < 50 mL/min.'},
    elderlyAlert: {'pt': 'Alto risco de hipotensão e arritmias ventriculares.', 'es': 'Riesgo de hipotensión y arritmias.'},
    mechanism: {'pt': 'Inibidor seletivo da fosfodiesterase III.', 'es': 'Inhibidor selectivo de la PDE III.'},
    warning: {'pt': 'Aumenta AMPc sem aumentar gasto de O2 celular.', 'es': 'Inodilatador potente.'},
    adverse: {
      'pt': ['Hipotensão', 'Arritmias ventriculares', 'Cefaleia', 'Trombocitopenia', 'Hipocalemia'],
      'es': ['Hipotensión', 'Arritmias ventriculares', 'Cefalea', 'Trombocitopenia', 'Hipopotasemia'],
    },
  ),

  DrugModel(
    id: 'fosfomicina_f',
    group: 'Antibióticos',
    name: 'Fosfomicina (Monurol)',
    className: {'pt': 'Antibiótico de dose única', 'es': 'Antibiótico de dosis única'},
    category: {'pt': 'ITU', 'es': 'ITU'},
    route: 'VO (Sache)',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Adulto: 3 g dose única. Pediatria (>12 anos): 3 g dose única.',
      'es': 'Adulto: 3 g dosis única. Pediatría (>12 años): 3 g dosis única.',
    },
    renalAlert: {'pt': 'Não recomendado se ClCr < 10 mL/min.', 'es': 'No recomendado si ClCr < 10 mL/min.'},
    elderlyAlert: {'pt': 'Bem tolerado.', 'es': 'Bien tolerado.'},
    mechanism: {'pt': 'Inibe síntese de parede (enolpiruvil transferase).', 'es': 'Inhibe síntesis de pared celular.'},
    warning: {'pt': 'Tomar 2h antes ou após refeições.', 'es': 'Tomar 2h antes o después de comer.'},
    adverse: {
      'pt': ['Diarreia', 'Vaginite', 'Náuseas', 'Cefaleia', 'Tontura'],
      'es': ['Diarrea', 'Vaginitis', 'Náuseas', 'Cefalea', 'Mareo'],
    },
  ),

  DrugModel(
    id: 'alprazolam_f',
    group: 'Neurología y Psiquiatría',
    name: 'Alprazolam (Alplax)',
    className: {'pt': 'Benzodiazepínico de ação curta', 'es': 'Benzodiazepina de acción corta'},
    category: {'pt': 'Ansiedade', 'es': 'Ansiedad'},
    route: 'VO / SL',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Adulto: 0.25-1 mg cada 8h. Máx 4 mg/dia.',
      'es': 'Adulto: 0.25-1 mg cada 8h. Máx 4 mg/día.',
    },
    renalAlert: {'pt': 'Usar com cautela.', 'es': 'Usar con cautela.'},
    elderlyAlert: {'pt': 'Beers: evitar (risco alto de quedas).', 'es': 'Beers: evitar (riesgo de caídas).'},
    mechanism: {'pt': 'Aumenta afinidade do GABA pelo receptor GABA-A.', 'es': 'Aumenta afinidad del GABA.'},
    warning: {'pt': 'Droga de alto abuso na região.', 'es': 'Droga de alto abuso.'},
    adverse: {
      'pt': ['Sedação', 'Ataxia', 'Amnésia', 'Fadiga', 'Irritabilidade paradoxal'],
      'es': ['Sedación', 'Ataxia', 'Amnesia', 'Fatiga', 'Irritabilidad paradojal'],
    },
  ),

  DrugModel(
    id: 'carvedilol_f',
    group: 'Cardiovascular y HTA',
    name: 'Carvedilol (Duo-Pres)',
    className: {'pt': 'Betabloqueador Alfa-1 / Beta', 'es': 'Betabloqueante Alfa-1 / Beta'},
    category: {'pt': 'IC / Anti-hipertensivo', 'es': 'IC / Antihipertensivo'},
    route: 'VO',
    doseType: 'weight',
    fixedDose: {
      'pt': 'Adulto: 6.25-25 mg cada 12h. Pediátrico: 0.1 mg/kg cada 12h.',
      'es': 'Adulto: 6.25-25 mg cada 12h. Pediatría: 0.1 mg/kg cada 12h.',
    },
    renalAlert: {'pt': 'Sem ajuste necessário.', 'es': 'Sin ajuste necesario.'},
    elderlyAlert: {'pt': 'Hipotensão postural frequente.', 'es': 'Hipotensión postural.'},
    mechanism: {'pt': 'Bloqueio Beta não seletivo e Alfa-1 (vasodilatador).', 'es': 'Bloqueo Beta y Alfa-1.'},
    warning: {'pt': 'Preferido na Insuficiência Cardíaca.', 'es': 'Elección en IC.'},
    adverse: {
      'pt': ['Tontura', 'Bradicardia', 'Hipotensão ortostática', 'Hiperglicemia', 'Ganho de peso'],
      'es': ['Mareo', 'Bradicardia', 'Hipotensión ortostática', 'Hiperglucemia', 'Aumento de peso'],
    },
  ),

  DrugModel(
    id: 'terlipressina_f',
    group: 'Cardiovascular y HTA',
    name: 'Terlipressina (Glypressin)',
    className: {'pt': 'Análogo da Vasopressina', 'es': 'Análogo de Vasopresina'},
    category: {'pt': 'Hepatologia / Emergência', 'es': 'Hepatología / Emergencia'},
    route: 'IV',
    doseType: 'weight',
    fixedDose: {
      'pt': 'Varizes: 2 mg IV cada 4-6h. Hepatorrenal: 0.5-2 mg cada 6h.',
      'es': 'Várices: 2 mg IV cada 4-6h. Hepatorrenal: 0.5-2 mg cada 6h.',
    },
    renalAlert: {'pt': 'Monitorar sódio (risco hiponatremia).', 'es': 'Monitorear sodio.'},
    elderlyAlert: {'pt': 'Risco de isquemia miocárdica.', 'es': 'Riesgo de isquemia miocárdica.'},
    mechanism: {'pt': 'Vasoconstrição esplâncnica seletiva.', 'es': 'Vasoconstricción esplácnica.'},
    warning: {'pt': 'Usar em Síndrome Hepatorrenal.', 'es': 'Uso en SHR.'},
    adverse: {
      'pt': ['Dor abdominal', 'Palidez', 'Hipertensão', 'Hiponatremia', 'Isquemia periférica'],
      'es': ['Dolor abdominal', 'Palidez', 'Hipertensión', 'Hiponatremia', 'Isquemia distal'],
    },
  ),

  DrugModel(
    id: 'octreotida_f',
    group: 'Gastroenterología',
    name: 'Octreotida (Sandostatin)',
    className: {'pt': 'Análogo da Somatostatina', 'es': 'Análogo de Somatostatina'},
    category: {'pt': 'Emergência GI', 'es': 'Emergencia GI'},
    route: 'IV / SC',
    doseType: 'weight',
    fixedDose: {
      'pt': 'Adulto: 50 mcg bolus → 25-50 mcg/h. Pediatria: 1-2 mcg/kg/h.',
      'es': 'Adulto: 50 mcg bolo → 25-50 mcg/h. Pediatría: 1-2 mcg/kg/h.',
    },
    renalAlert: {'pt': 'Sem ajuste necessário.', 'es': 'Sin ajuste necesario.'},
    elderlyAlert: {'pt': 'Pode causar bradicardia sinusal.', 'es': 'Puede causar bradicardia.'},
    mechanism: {'pt': 'Reduz fluxo sanguíneo portal e inibe hormônios GI.', 'es': 'Reduce flujo portal.'},
    warning: {'pt': 'Padrão em hemorragia por varizes esofágicas.', 'es': 'HDA varicosa.'},
    adverse: {
      'pt': ['Bradicardia', 'Náuseas', 'Diarreia', 'Colelitíase', 'Hipoglicemia'],
      'es': ['Bradicardia', 'Náuseas', 'Diarrea', 'Colelitiasis', 'Hipoglucemia'],
    },
  ),

  DrugModel(
    id: 'levosulpirida_f',
    group: 'Gastroenterología',
    name: 'Levosulpirida (Dislep)',
    className: {'pt': 'Procinético', 'es': 'Procinético'},
    category: {'pt': 'Gastrointestinal', 'es': 'Gastrointestinal'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Adulto: 25 mg cada 8h antes das refeições.',
      'es': 'Adulto: 25 mg cada 8h antes de las comidas.',
    },
    renalAlert: {'pt': 'Evitar em insuficiência renal grave.', 'es': 'Evitar en falla renal grave.'},
    elderlyAlert: {'pt': 'Risco de sintomas extrapiramidais.', 'es': 'Riesgo de extrapiramidalismo.'},
    mechanism: {'pt': 'Antagonista D2 seletivo; acelera esvaziamento gástrico.', 'es': 'Antagonista D2 selectivo.'},
    warning: {'pt': 'Muito prescrito para dispepsia funcional.', 'es': 'Dispepsia funcional.'},
    adverse: {
      'pt': ['Tensão mamária', 'Galactorreia', 'Amenorreia', 'Sonolência', 'EPS'],
      'es': ['Tensión mamaria', 'Galactorrea', 'Amenorrea', 'Somnolencia', 'EPS'],
    },
  ),

  DrugModel(
    id: 'trimebutina_f',
    group: 'Gastroenterología',
    name: 'Trimebutina (Debridat)',
    className: {'pt': 'Modulador da Motilidade GI', 'es': 'Modulador de Motilidad GI'},
    category: {'pt': 'Gastrointestinal', 'es': 'Gastrointestinal'},
    route: 'VO / IV / IM',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Adulto: 200 mg cada 8h. Pediatria: 1 ml/kg/dia (xarope).',
      'es': 'Adulto: 200 mg cada 8h. Pediatría: 1 ml/kg/día (jarabe).',
    },
    renalAlert: {'pt': 'Sem ajuste necessário.', 'es': 'Sin ajuste necesario.'},
    elderlyAlert: {'pt': 'Bem tolerado.', 'es': 'Bien tolerado.'},
    mechanism: {'pt': 'Agonista encefalinérgico mu, kappa e delta.', 'es': 'Agonista encefalinérgico.'},
    warning: {'pt': 'Modula tanto diarreia quanto constipação.', 'es': 'Modula motilidad.'},
    adverse: {
      'pt': ['Boca seca', 'Diarreia', 'Sonolência', 'Cefaleia', 'Rash'],
      'es': ['Boca seca', 'Diarrea', 'Somnolencia', 'Cefalea', 'Rash'],
    },
  ),

  DrugModel(
    id: 'lactobacillus_f',
    group: 'Gastroenterología',
    name: 'Lactobacillus (Floratil)',
    className: {'pt': 'Probiótico', 'es': 'Probiótico'},
    category: {'pt': 'Gastrointestinal', 'es': 'Gastrointestinal'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Adulto/Pediátrico: 200-250 mg 1-2x/dia.',
      'es': 'Adulto/Pediátrico: 200-250 mg 1-2 veces/día.',
    },
    renalAlert: {'pt': 'Sem ajuste.', 'es': 'Sin ajuste.'},
    elderlyAlert: {'pt': 'Cuidado em imunossuprimidos graves.', 'es': 'Cuidado en inmunocomprometidos.'},
    mechanism: {'pt': 'Restauração da microbiota intestinal.', 'es': 'Restauración de microbiota.'},
    warning: {'pt': 'S. boulardii é a cepa padrão.', 'es': 'Cepa estándar S. boulardii.'},
    adverse: {
      'pt': ['Flatulência', 'Obstipação', 'Sede', 'Fungemia (raro)', 'Rash'],
      'es': ['Flatulencia', 'Obstipación', 'Sed', 'Fungemia (raro)', 'Rash'],
    },
  ),

  DrugModel(
    id: 'rifaximina_f',
    group: 'Antibióticos',
    name: 'Rifaximina (Rifax)',
    className: {'pt': 'Antibiótico não absorvível', 'es': 'Antibiótico no absorbible'},
    category: {'pt': 'Gastrointestinal', 'es': 'Gastrointestinal'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Encefalopatia: 550 mg 2x/dia. Diarreia viajante: 200 mg 3x/dia.',
      'es': 'Encefalopatía: 550 mg 2 veces/día. Diarrea viajero: 200 mg 3 veces/día.',
    },
    renalAlert: {'pt': 'Sem ajuste necessário.', 'es': 'Sin ajuste necesario.'},
    elderlyAlert: {'pt': 'Seguro, ação local.', 'es': 'Seguro.'},
    mechanism: {'pt': 'Inibe a síntese de RNA bacteriano no lúmen intestinal.', 'es': 'Acción local en el lúmen.'},
    warning: {'pt': 'Reduz recorrência de Encefalopatia Hepática.', 'es': 'Prevención Encefalopatía.'},
    adverse: {
      'pt': ['Flatulência', 'Náuseas', 'Dor abdominal', 'Tenesmo', 'Cefaleia'],
      'es': ['Flatulencia', 'Náuseas', 'Dolor abdominal', 'Tenesmo', 'Cefalea'],
    },
  ),

  DrugModel(
    id: 'montelukast_f',
    group: 'Respiratorio',
    name: 'Montelukast (Singulair)',
    className: {'pt': 'Antagonista de Leucotrienos', 'es': 'Antagonista de Leucotrienos'},
    category: {'pt': 'Respiratório', 'es': 'Respiratorio'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Adulto: 10 mg/dia (noite). Ped: 4 mg (2-5 anos) ou 5 mg (6-14 anos).',
      'es': 'Adulto: 10 mg/día (noche). Ped: 4 mg (2-5 años) o 5 mg (6-14 años).',
    },
    renalAlert: {'pt': 'Sem ajuste necessário.', 'es': 'Sin ajuste necesario.'},
    elderlyAlert: {'pt': 'Monitorar alterações neuropsiquiátricas.', 'es': 'Monitorear cambios de humor.'},
    mechanism: {'pt': 'Inibe receptor de cisteinil leucotrienos.', 'es': 'Inhibe receptor leucotrienos.'},
    warning: {'pt': 'Black Box: pesadelos e ideação suicida.', 'es': 'Alerta neuropsiquiátrica.'},
    adverse: {
      'pt': ['Pesadelos', 'Cefaleia', 'Dor abdominal', 'Irritabilidade', 'Sintomas gripais'],
      'es': ['Pesadillas', 'Cefalea', 'Dolor abdominal', 'Irritabilidad', 'Gripe'],
    },
  ),

  DrugModel(
    id: 'budesonida_neb_f',
    group: 'Respiratorio',
    name: 'Budesonida (Nebulização)',
    className: {'pt': 'Corticoide inalatório', 'es': 'Corticoide inhalado'},
    category: {'pt': 'Respiratório', 'es': 'Respiratorio'},
    route: 'Inalatório (Nebulização)',
    doseType: 'weight',
    fixedDose: {
      'pt': 'Pediatria: 0.25-0.5 mg cada 12h. Crupe: 2 mg dose única.',
      'es': 'Pediatría: 0.25-0.5 mg cada 12h. Crup: 2 mg dosis única.',
    },
    renalAlert: {'pt': 'Sem ajuste.', 'es': 'Sin ajuste.'},
    elderlyAlert: {'pt': 'Enxaguar a boca após uso.', 'es': 'Enjuagar boca.'},
    mechanism: {'pt': 'Anti-inflamatório local potente.', 'es': 'Antiinflamatorio local.'},
    warning: {'pt': 'Início de ação em 24h para asma crônica.', 'es': 'Uso crónico y agudo.'},
    adverse: {
      'pt': ['Candidíase oral', 'Disfonia', 'Tosse', 'Irritação de garganta', 'Pneumonia (raro)'],
      'es': ['Candidiasis oral', 'Disfonía', 'Tos', 'Irritación faríngea', 'Neumonía'],
    },
  ),

  DrugModel(
    id: 'azitromicina_p',
    group: 'Antibióticos',
    name: 'Azitromicina (Cronopen)',
    className: {'pt': 'Macrolídeo', 'es': 'Macrólido'},
    category: {'pt': 'Antibióticos', 'es': 'Antibióticos'},
    route: 'VO / IV',
    doseType: 'weight',
    fixedDose: {
      'pt': 'Adulto: 500 mg/dia (3-5 dias). Ped: 10 mg/kg/dia.',
      'es': 'Adulto: 500 mg/día. Ped: 10 mg/kg/día.',
    },
    renalAlert: {'pt': 'Sem ajuste necessário.', 'es': 'Sin ajuste necesario.'},
    elderlyAlert: {'pt': 'Risco de morte súbita em cardiopatas (QT).', 'es': 'Riesgo de arritmias.'},
    mechanism: {'pt': 'Inibe síntese proteica; t1/2 longa (68h).', 'es': 'Inhibe síntesis proteica.'},
    warning: {'pt': 'Uso em pneumonia comunitária.', 'es': 'NAC.'},
    adverse: {
      'pt': ['Diarreia', 'Náuseas', 'Vômitos', 'Ototoxicidade (altas doses)', 'Prolongamento QT'],
      'es': ['Diarrea', 'Náuseas', 'Vómitos', 'Ototoxicidad', 'Prolongamiento QT'],
    },
  ),

  DrugModel(
    id: 'ciprofloxacino_iv_f',
    group: 'Antibióticos',
    name: 'Ciprofloxacino IV',
    className: {'pt': 'Quinolona', 'es': 'Quinolona'},
    category: {'pt': 'Antibióticos', 'es': 'Antibióticos'},
    route: 'IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Adulto: 400 mg cada 8-12h. Pediátrico (Fibrose Cística): 10 mg/kg cada 8h.',
      'es': 'Adulto: 400 mg cada 8-12h. Pediatría: 10 mg/kg cada 8h.',
    },
    renalAlert: {'pt': 'Ajustar para cada 24h se ClCr < 30.', 'es': 'Ajustar si ClCr < 30.'},
    elderlyAlert: {'pt': 'Risco de confusão mental e ruptura de tendão.', 'es': 'Confusión y tendinitis.'},
    mechanism: {'pt': 'Inibe DNA girase; excelente contra Pseudomonas.', 'es': 'Inhibe DNA girasa.'},
    warning: {'pt': 'Infundir em no mínimo 60 min.', 'es': 'Infusión lenta.'},
    adverse: {
      'pt': ['Tendinite', 'Náusea', 'Cefaleia', 'Prolongamento QT', 'Convulsão (raro)'],
      'es': ['Tendinitis', 'Náusea', 'Cefalea', 'Prolongamiento QT', 'Convulsión'],
    },
  ),

  DrugModel(
    id: 'valaciclovir_f',
    group: 'Antibióticos',
    name: 'Valaciclovir (Valtrex)',
    className: {'pt': 'Antiviral Herpes', 'es': 'Antiviral Herpes'},
    category: {'pt': 'Antibióticos', 'es': 'Antibióticos'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Adulto: 1 g 3x/dia (Zoster). Ped: 20 mg/kg cada 8h.',
      'es': 'Adulto: 1 g 3 veces/día. Ped: 20 mg/kg cada 8h.',
    },
    renalAlert: {'pt': 'Ajustar se ClCr < 50.', 'es': 'Ajustar ClCr < 50.'},
    elderlyAlert: {'pt': 'Monitorar função renal.', 'es': 'Monitorizar función renal.'},
    mechanism: {'pt': 'Inibe DNA polimerase viral; pró-droga do Aciclovir.', 'es': 'Inhibe DNA polimerasa.'},
    warning: {'pt': 'Hidratação vigorosa necessária.', 'es': 'Hidratación.'},
    adverse: {
      'pt': ['Cefaleia', 'Náusea', 'Dor abdominal', 'Trombocitopenia (raro)', 'Confusão'],
      'es': ['Cefalea', 'Náusea', 'Dolor abdominal', 'Trombocitopenia', 'Confusión'],
    },
  ),

  DrugModel(
    id: 'fluconazol_p',
    group: 'Antibióticos',
    name: 'Fluconazol (Mutum)',
    className: {'pt': 'Antifúngico Triazol', 'es': 'Antifúngico Triazol'},
    category: {'pt': 'Antibióticos', 'es': 'Antibióticos'},
    route: 'VO / IV',
    doseType: 'weight',
    fixedDose: {
      'pt': 'Adulto: 150-400 mg/dia. Pediatria: 6-12 mg/kg/dia.',
      'es': 'Adulto: 150-400 mg/día. Pediatría: 6-12 mg/kg/día.',
    },
    renalAlert: {'pt': 'Reduzir dose em 50% se ClCr < 50.', 'es': 'Reducir dosis al 50% si ClCr < 50.'},
    elderlyAlert: {'pt': 'Monitorar enzimas hepáticas e QT.', 'es': 'Monitorear TFH y QT.'},
    mechanism: {'pt': 'Inibe a síntese de ergosterol na membrana fúngica.', 'es': 'Inhibe síntesis de ergosterol.'},
    warning: {'pt': 'Muitas interações medicamentosas.', 'es': 'Interacciones.'},
    adverse: {
      'pt': ['Náusea', 'Cefaleia', 'Dor abdominal', 'Elevada TGO/TGP', 'Rash'],
      'es': ['Náusea', 'Cefalea', 'Dolor abdominal', 'Elevación TGO/TGP', 'Rash'],
    },
  ),

  DrugModel(
    id: 'venlafaxina_p',
    group: 'Neurología y Psiquiatría',
    name: 'Venlafaxina (Efexor)',
    className: {'pt': 'IRSN', 'es': 'IRSN'},
    category: {'pt': 'Psiquiatria', 'es': 'Psiquiatría'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Adulto: 75-225 mg/dia.',
      'es': 'Adulto: 75-225 mg/día.',
    },
    renalAlert: {'pt': 'Reduzir dose em 50% se ClCr < 30.', 'es': 'Reducir dosis al 50% si ClCr < 30.'},
    elderlyAlert: {'pt': 'Pode aumentar a pressão arterial.', 'es': 'Puede elevar la PA.'},
    mechanism: {'pt': 'Inibe recaptação de serotonina e noradrenalina.', 'es': 'Inhibe recaptación de 5HT y NE.'},
    warning: {'pt': 'Síndrome de descontinuação severa.', 'es': 'Síndrome de abstinencia severo.'},
    adverse: {
      'pt': ['Hipertensão', 'Sudorese', 'Náuseas', 'Boca seca', 'Cefaleia'],
      'es': ['Hipertensión', 'Sudoración', 'Náuseas', 'Boca seca', 'Cefalea'],
    },
  ),

  DrugModel(
    id: 'clonazepam_p',
    group: 'Neurología y Psiquiatría',
    name: 'Clonazepam (Rivotril)',
    className: {'pt': 'Benzodiazepínico', 'es': 'Benzodiazepina'},
    category: {'pt': 'Psicotrópicos', 'es': 'Psicotrópicos'},
    route: 'VO / SL',
    doseType: 'weight',
    fixedDose: {
      'pt': 'Adulto: 0.25-2 mg cada 12h. Ped: 0.01-0.03 mg/kg/dia.',
      'es': 'Adulto: 0.25-2 mg cada 12h. Ped: 0.01-0.03 mg/kg/día.',
    },
    renalAlert: {'pt': 'Sem ajuste necessário.', 'es': 'Sin ajuste necesario.'},
    elderlyAlert: {'pt': 'Alto risco de quedas e sedação residual.', 'es': 'Riesgo de caídas.'},
    mechanism: {'pt': 'Modulador alostérico do receptor GABA-A.', 'es': 'Modulador de GABA-A.'},
    warning: {'pt': 'Uso em gotas muito comum (1 gota = 0.1 mg).', 'es': '1 gota = 0.1 mg.'},
    adverse: {
      'pt': ['Sonolência', 'Ataxia', 'Hipersalivação', 'Fadiga', 'Depressão'],
      'es': ['Somnolencia', 'Ataxia', 'Sialorrea', 'Fatiga', 'Depresión'],
    },
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // NOVOS FÁRMACOS — MERGE v2
  // Fontes: Harrison's 21ª ed., Goodman & Gilman 14ª ed., UpToDate 2024,
  // Micromedex, SBC 2023, SBEM, SBGG, ESC/AHA guidelines.
  // ══════════════════════════════════════════════════════════════════════════

  // ── CARDIOVASCULAR ────────────────────────────────────────────────────────

  DrugModel(
    id: 'dronedarona',
    group: 'Cardiovascular y HTA',
    name: 'Dronedarona (Multaq)',
    className: {'pt': 'Antiarrítmico classe III (análogo da amiodarona)', 'es': 'Antiarrítmico clase III (análogo amiodarona)'},
    category: {'pt': 'Antiarrítmicos', 'es': 'Antiarrítmicos'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': '400 mg 2x/dia com as refeições. Não usar em IC descompensada ou FA permanente.',
      'es': '400 mg 2 veces/día con las comidas. No usar en IC descompensada o FA permanente.',
    },
    renalAlert: {
      'pt': 'Sem ajuste de dose necessário. Cautela em IR grave.',
      'es': 'Sin ajuste. Precaución en IRA grave.',
    },
    elderlyAlert: {
      'pt': 'Monitorar função renal e hepática. Menor toxicidade tireoidiana que amiodarona.',
      'es': 'Monitorizar función renal y hepática. Menos toxicidad tiroidea que amiodarona.',
    },
    mechanism: {
      'pt': 'Bloqueia canais de sódio, potássio e cálcio; antagonismo adrenérgico não competitivo. Sem iodo na estrutura.',
      'es': 'Bloquea canales Na, K, Ca; antagonismo adrenérgico no competitivo. Sin yodo en la molécula.',
    },
    warning: {
      'pt': 'CONTRAINDICADA em IC com FE reduzida sintomática (NYHA III-IV), FA permanente, bloqueio AV avançado. Risco de hepatotoxicidade grave (monitorar TGO/TGP).',
      'es': 'CONTRAINDICADA en IC sistólica sintomática, FA permanente, BAV avanzado. Riesgo de hepatotoxicidad grave.',
    },
    adverse: {
      'pt': ['Bradicardia', 'Prolongamento QT', 'Insuficiência cardíaca', 'Hepatotoxicidade (raro)', 'Diarreia', 'Náuseas', 'Elevação de creatinina (sem lesão renal real)'],
      'es': ['Bradicardia', 'Prolongación QT', 'Insuficiencia cardíaca', 'Hepatotoxicidad (raro)', 'Diarrea', 'Náuseas', 'Elevación creatinina (sin lesión renal real)'],
    },
  ),

  DrugModel(
    id: 'ivabradina',
    group: 'Cardiovascular y HTA',
    name: 'Ivabradina (Procoralan)',
    className: {'pt': 'Inibidor da corrente If (marca-passo sinusal)', 'es': 'Inhibidor de la corriente If'},
    category: {'pt': 'Antianginosos / Insuficiência Cardíaca', 'es': 'Antianginosos / IC'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'IC: iniciar 5 mg 2x/dia; ajustar para 7,5 mg 2x/dia se FC >60 bpm. Angina: 5–7,5 mg 2x/dia. FC alvo: 55–60 bpm.',
      'es': 'IC: iniciar 5 mg 2v/día; ajustar a 7,5 mg 2v/día si FC >60 lpm. Angina: 5–7,5 mg 2v/día.',
    },
    renalAlert: {
      'pt': 'Sem ajuste em ClCr ≥15 mL/min. Dados insuficientes abaixo disso.',
      'es': 'Sin ajuste con ClCr ≥15 mL/min.',
    },
    elderlyAlert: {
      'pt': 'Iniciar com dose menor (2,5 mg 2x/dia). Monitorar FC e PA.',
      'es': 'Iniciar con dosis menor. Monitorizar FC y PA.',
    },
    mechanism: {
      'pt': 'Inibe seletivamente a corrente If (funny current) no nó sinoatrial → reduz FC sem efeito inotrópico negativo.',
      'es': 'Inhibe selectivamente la corriente If en el nodo sinusal → reduce FC sin efecto inotrópico negativo.',
    },
    warning: {
      'pt': 'Somente em ritmo sinusal. Contraindicada em bloqueio AV completo, FA, choque cardiogênico. Pode causar fosfenos (fenômeno visual transitório).',
      'es': 'Solo en ritmo sinusal. Contraindicada en BAV completo, FA, shock cardiogénico. Puede causar fosfenos.',
    },
    adverse: {
      'pt': ['Bradicardia', 'Fosfenos (distúrbio visual luminoso)', 'Cefaleia', 'Fibrilação atrial', 'Bloqueio AV de 1º grau'],
      'es': ['Bradicardia', 'Fosfenos', 'Cefalea', 'Fibrilación auricular', 'BAV 1er grado'],
    },
  ),

  DrugModel(
    id: 'ranolazina',
    group: 'Cardiovascular y HTA',
    name: 'Ranolazina (Ranexa)',
    className: {'pt': 'Antianginoso – inibidor da corrente tardia de sódio', 'es': 'Antianginoso – inhibidor de corriente tardía de Na'},
    category: {'pt': 'Antianginosos', 'es': 'Antianginosos'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': '500 mg 2x/dia; pode aumentar para 1000 mg 2x/dia. Comprimidos de liberação prolongada — não partir.',
      'es': '500 mg 2v/día; aumentar a 1000 mg 2v/día. Comprimidos LP — no partir.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário. Cautela em DRC grave (dados limitados).',
      'es': 'Sin ajuste. Precaución en ERC grave.',
    },
    elderlyAlert: {
      'pt': 'Monitorar QTc. Interações com inibidores de CYP3A4 são relevantes.',
      'es': 'Monitorizar QTc. Interacciones con inhibidores CYP3A4 relevantes.',
    },
    mechanism: {
      'pt': 'Inibe a corrente tardia de Na⁺ (INa-late) → reduz sobrecarga de Ca²⁺ intracelular → melhora relaxamento diastólico e reduz isquemia.',
      'es': 'Inhibe INa-tardía → reduce sobrecarga de Ca²⁺ intracelular → mejora relajación diastólica.',
    },
    warning: {
      'pt': 'Prolonga QTc dose-dependente. Contraindicada com inibidores potentes de CYP3A4 (claritromicina, itraconazol). Não usar em cirrose hepática grave.',
      'es': 'Prolonga QTc dosis-dependiente. Contraindicada con inhibidores potentes CYP3A4. No usar en cirrosis grave.',
    },
    adverse: {
      'pt': ['Tontura', 'Náuseas', 'Constipação', 'Cefaleia', 'Prolongamento QTc', 'Síncope'],
      'es': ['Mareo', 'Náuseas', 'Estreñimiento', 'Cefalea', 'Prolongación QTc', 'Síncope'],
    },
  ),

  DrugModel(
    id: 'eplerenona',
    group: 'Cardiovascular y HTA',
    name: 'Eplerenona (Inspra)',
    className: {'pt': 'Antagonista seletivo da aldosterona (ARM)', 'es': 'Antagonista selectivo de aldosterona (ARM)'},
    category: {'pt': 'Diuréticos poupadores de potássio / IC', 'es': 'Diuréticos ahorradores K / IC'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'IC pós-IAM: 25 mg/dia; aumentar para 50 mg/dia após 4 semanas se K⁺ <5,0 mEq/L. HAS: 50 mg/dia.',
      'es': 'IC post-IAM: 25 mg/día; aumentar a 50 mg/día tras 4 semanas si K⁺ <5,0 mEq/L. HTA: 50 mg/día.',
    },
    renalAlert: {
      'pt': 'Contraindicada se ClCr <30 mL/min ou K⁺ >5,5 mEq/L. Monitorar K⁺ e creatinina semanalmente nas primeiras 4 semanas.',
      'es': 'Contraindicada si ClCr <30 mL/min o K⁺ >5,5 mEq/L. Monitorizar K⁺ y creatinina.',
    },
    elderlyAlert: {
      'pt': 'Maior risco de hipercalemia. Monitorar eletrólitos rigorosamente.',
      'es': 'Mayor riesgo de hipercalemia. Monitorizar electrólitos.',
    },
    mechanism: {
      'pt': 'Antagonismo seletivo dos receptores de mineralocorticoides → reduz retenção de Na⁺ e excreção de K⁺ sem efeitos androgênicos/progestagênicos (vantagem sobre espironolactona).',
      'es': 'Antagonismo selectivo de receptores mineralocorticoides → sin efectos androgénicos/progestagénicos (ventaja vs espironolactona).',
    },
    warning: {
      'pt': 'Hipercalemia potencialmente fatal. Não combinar com outros poupadores de K⁺ ou suplementos de potássio. Monitorar função renal regularmente.',
      'es': 'Hipercalemia potencialmente fatal. No combinar con otros ahorradores de K⁺. Monitorizar función renal.',
    },
    adverse: {
      'pt': ['Hipercalemia', 'Hipotensão', 'Tontura', 'Diarreia', 'Cefaleia', 'Ginecomastia (muito raro — vantagem vs espironolactona)'],
      'es': ['Hipercalemia', 'Hipotensión', 'Mareo', 'Diarrea', 'Cefalea', 'Ginecomastia (muy raro)'],
    },
  ),

  DrugModel(
    id: 'riociguate',
    group: 'Cardiovascular y HTA',
    name: 'Riociguate (Adempas)',
    className: {'pt': 'Estimulador solúvel da guanilato ciclase (sGC)', 'es': 'Estimulador soluble de guanilato ciclasa'},
    category: {'pt': 'Hipertensão Pulmonar', 'es': 'Hipertensión Pulmonar'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Iniciar 1 mg 3x/dia; aumentar 0,5 mg a cada 2 semanas até máx. 2,5 mg 3x/dia, conforme tolerância de PA.',
      'es': 'Iniciar 1 mg 3v/día; aumentar 0,5 mg cada 2 semanas hasta máx. 2,5 mg 3v/día.',
    },
    renalAlert: {
      'pt': 'Dados limitados em ClCr <15 mL/min. Usar com cautela.',
      'es': 'Datos limitados en ClCr <15 mL/min.',
    },
    elderlyAlert: {
      'pt': 'Risco aumentado de hipotensão. Iniciar com dose mínima.',
      'es': 'Mayor riesgo de hipotensión. Iniciar con dosis mínima.',
    },
    mechanism: {
      'pt': 'Estimula diretamente a guanilato ciclase solúvel, aumentando GMPc → vasodilatação pulmonar e sistêmica. Sinergismo com NO endógeno.',
      'es': 'Estimula directamente la guanilato ciclasa soluble → aumenta GMPc → vasodilatación pulmonar.',
    },
    warning: {
      'pt': 'CONTRAINDICADO com inibidores da PDE5 (sildenafila, tadalafila) — hipotensão grave. Teratogênico (programa de prevenção de gravidez obrigatório).',
      'es': 'CONTRAINDICADO con inhibidores PDE5 (sildenafilo, tadalafilo). Teratogénico — programa de prevención embarazo obligatorio.',
    },
    adverse: {
      'pt': ['Hipotensão', 'Cefaleia', 'Tontura', 'Náuseas', 'Diarreia', 'Hemoptise (raro)'],
      'es': ['Hipotensión', 'Cefalea', 'Mareo', 'Náuseas', 'Diarrea', 'Hemoptisis (raro)'],
    },
  ),

  DrugModel(
    id: 'candesartana',
    group: 'Cardiovascular y HTA',
    name: 'Candesartana (Atacand)',
    className: {'pt': 'ARA-II (Bloqueador do receptor de angiotensina II)', 'es': 'ARA-II'},
    category: {'pt': 'Anti-hipertensivos', 'es': 'Antihipertensivos'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'HAS: 8–32 mg/dia em dose única. IC: iniciar 4–8 mg/dia; alvo 32 mg/dia.',
      'es': 'HTA: 8–32 mg/día en dosis única. IC: iniciar 4–8 mg/día; objetivo 32 mg/día.',
    },
    renalAlert: {
      'pt': 'Iniciar com 4 mg/dia em DRC grave. Monitorar K⁺ e creatinina.',
      'es': 'Iniciar con 4 mg/día en ERC grave. Monitorizar K⁺ y creatinina.',
    },
    elderlyAlert: {
      'pt': 'Iniciar com dose menor. Hipotensão postural mais frequente.',
      'es': 'Iniciar con dosis menor. Hipotensión postural más frecuente.',
    },
    mechanism: {
      'pt': 'Bloqueia seletivamente os receptores AT1 da angiotensina II → vasodilatação, redução de aldosterona. Sem acúmulo de bradicinina (sem tosse).',
      'es': 'Bloquea selectivamente receptores AT1 → vasodilatación, reducción de aldosterona. Sin tos (no acumula bradicinina).',
    },
    warning: {
      'pt': 'Contraindicado na gravidez (fetotóxico). Não combinar com IECA + ARA-II (bloqueio dual do SRAA).',
      'es': 'Contraindicado en embarazo. No combinar IECA + ARA-II (doble bloqueo SRAA).',
    },
    adverse: {
      'pt': ['Hipotensão', 'Hipercalemia', 'Tontura', 'Cefaleia', 'Elevação de creatinina'],
      'es': ['Hipotensión', 'Hipercalemia', 'Mareo', 'Cefalea', 'Elevación creatinina'],
    },
  ),

  DrugModel(
    id: 'amlodipino_olmesartana',
    group: 'Cardiovascular y HTA',
    name: 'Anlodipino + Olmesartana (Azor)',
    className: {'pt': 'BCC + ARA-II (associação fixa)', 'es': 'BCC + ARA-II (asociación fija)'},
    category: {'pt': 'Anti-hipertensivos combinados', 'es': 'Antihipertensivos combinados'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': '5/20 mg a 10/40 mg uma vez/dia. Ajuste individualizado conforme controle pressórico.',
      'es': '5/20 mg a 10/40 mg una vez/día. Ajustar según control de PA.',
    },
    renalAlert: {
      'pt': 'Monitorar função renal e K⁺. Cautela em DRC avançada.',
      'es': 'Monitorizar función renal y K⁺. Precaución en ERC avanzada.',
    },
    elderlyAlert: {
      'pt': 'Iniciar com menor dose combinada. Risco de hipotensão postural.',
      'es': 'Iniciar con menor dosis. Riesgo hipotensión postural.',
    },
    mechanism: {
      'pt': 'Anlodipino bloqueia canais de Ca²⁺ L → vasodilatação. Olmesartana bloqueia receptor AT1 → redução da angiotensina II.',
      'es': 'Amlodipino bloquea canales Ca²⁺ L. Olmesartán bloquea AT1.',
    },
    warning: {
      'pt': 'Contraindicado na gravidez. Edema de tornozelo pode surgir pelo componente anlodipino.',
      'es': 'Contraindicado en embarazo. El componente amlodipino puede causar edema de tobillo.',
    },
    adverse: {
      'pt': ['Edema periférico', 'Hipotensão', 'Tontura', 'Cefaleia', 'Hipercalemia'],
      'es': ['Edema periférico', 'Hipotensión', 'Mareo', 'Cefalea', 'Hipercalemia'],
    },
  ),

  // ── ANTICOAGULANTES / HEMOSTASIA ──────────────────────────────────────────

  DrugModel(
    id: 'fondaparinux',
    group: 'Anticoagulantes y Hemostasia',
    name: 'Fondaparinux (Arixtra)',
    className: {'pt': 'Inibidor seletivo do fator Xa (pentassacarídeo sintético)', 'es': 'Inhibidor selectivo del factor Xa'},
    category: {'pt': 'Anticoagulantes parenterais', 'es': 'Anticoagulantes parenterales'},
    route: 'SC',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'TVP/TEP: 5 mg SC 1x/dia (<50 kg); 7,5 mg (<100 kg); 10 mg (>100 kg). SCA sem supra: 2,5 mg SC 1x/dia por até 8 dias.',
      'es': 'TVP/TEP: 5 mg SC/día (<50 kg); 7,5 mg (<100 kg); 10 mg (>100 kg). SCASEST: 2,5 mg SC/día hasta 8 días.',
    },
    renalAlert: {
      'pt': 'Contraindicado se ClCr <30 mL/min (acúmulo e risco hemorrágico). Monitorar função renal.',
      'es': 'Contraindicado si ClCr <30 mL/min. Monitorizar función renal.',
    },
    elderlyAlert: {
      'pt': 'Alta prevalência de DRC nos idosos — avaliar ClCr antes de prescrever. Sem antídoto específico disponível (protamina não reverte).',
      'es': 'Alta prevalencia ERC en ancianos — evaluar ClCr antes de prescribir. Sin antídoto específico.',
    },
    mechanism: {
      'pt': 'Liga-se seletivamente à antitrombina III → inibição do fator Xa → interrupção da cascata de coagulação. Não inibe trombina diretamente.',
      'es': 'Se une selectivamente a antitrombina III → inhibición del factor Xa → interrupción de la cascada coagulación.',
    },
    warning: {
      'pt': 'Sem antídoto específico (andexanet alfa não aprovado para fondaparinux). Não causa TIH (heparina-induced thrombocytopenia). Contraindicado em ClCr <30 mL/min.',
      'es': 'Sin antídoto específico. No causa TIH. Contraindicado en ClCr <30 mL/min.',
    },
    adverse: {
      'pt': ['Sangramento', 'Anemia', 'Trombocitopenia (rara)', 'Reação no local da injeção', 'Elevação de transaminases'],
      'es': ['Sangrado', 'Anemia', 'Trombocitopenia (rara)', 'Reacción local', 'Elevación transaminasas'],
    },
  ),

  DrugModel(
    id: 'andexanet_alfa',
    group: 'Anticoagulantes y Hemostasia',
    name: 'Andexanet Alfa (Ondexxya)',
    className: {'pt': 'Antídoto específico dos inibidores do fator Xa', 'es': 'Antídoto específico inhibidores factor Xa'},
    category: {'pt': 'Antídotos / Hemostasia', 'es': 'Antídotos / Hemostasia'},
    route: 'IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Dose baixa (rivaroxabana ≤10 mg ou apixabana ≤5 mg há <8h): 400 mg IV bolus + 480 mg infusão em 2h. Dose alta: 800 mg bolus + 960 mg em 2h.',
      'es': 'Dosis baja: 400 mg IV bolo + 480 mg infusión 2h. Dosis alta: 800 mg bolo + 960 mg 2h.',
    },
    renalAlert: {
      'pt': 'Sem ajuste de dose. Monitorar atividade anti-Xa após administração.',
      'es': 'Sin ajuste. Monitorizar actividad anti-Xa tras administración.',
    },
    elderlyAlert: {
      'pt': 'Risco trombótico aumentado — monitorar eventos isquêmicos nas 72h pós-reversão.',
      'es': 'Riesgo trombótico aumentado — monitorizar eventos isquémicos 72h post-reversión.',
    },
    mechanism: {
      'pt': 'Proteína recombinante análoga ao fator Xa (modificada, sem atividade catalítica) → captura os inibidores de Xa (apixabana, rivaroxabana, edoxabana) impedindo seu efeito anticoagulante.',
      'es': 'Proteína recombinante análoga al Xa (sin actividad catalítica) → captura inhibidores de Xa.',
    },
    warning: {
      'pt': 'Risco trombótico nas 72h pós-administração — reiniciar anticoagulação assim que possível. Monitorar com ECG (risco de TV/FV relatado). Custo elevadíssimo.',
      'es': 'Riesgo trombótico 72h post-administración — reiniciar anticoagulación lo antes posible. Monitorizar ECG.',
    },
    adverse: {
      'pt': ['Trombose (TVP, TEP, AVC isquêmico nas 72h)', 'Fibrilação atrial', 'Infarto do miocárdio', 'Febre', 'Pneumonia aspirativa'],
      'es': ['Trombosis', 'Fibrilación auricular', 'IAM', 'Fiebre', 'Neumonía aspirativa'],
    },
  ),

  DrugModel(
    id: 'idarucizumabe',
    group: 'Anticoagulantes y Hemostasia',
    name: 'Idarucizumabe (Praxbind)',
    className: {'pt': 'Antídoto específico da dabigatrana', 'es': 'Antídoto específico de dabigatrán'},
    category: {'pt': 'Antídotos / Hemostasia', 'es': 'Antídotos / Hemostasia'},
    route: 'IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': '5 g IV em duas doses de 2,5 g consecutivas (intervaladas em até 15 min). Administrar em bolus ou infusão rápida.',
      'es': '5 g IV en dos dosis de 2,5 g consecutivas (hasta 15 min de intervalo).',
    },
    renalAlert: {
      'pt': 'Sem ajuste de dose. Monitorar tempo de trombina (TT) e tempo de ecarina como indicadores de reversão.',
      'es': 'Sin ajuste. Monitorizar tiempo de trombina (TT) como indicador de reversión.',
    },
    elderlyAlert: {
      'pt': 'Monitorar atividade residual de dabigatrana (TT, APTT) após administração.',
      'es': 'Monitorizar actividad residual dabigatrán (TT, APTT) tras administración.',
    },
    mechanism: {
      'pt': 'Fragmento Fab de anticorpo monoclonal humanizado que se liga à dabigatrana com afinidade 350× maior que a trombina → inibição específica e reversão imediata da anticoagulação.',
      'es': 'Fragmento Fab de anticuerpo monoclonal humanizado → se une a dabigatrán con afinidad 350× mayor que trombina.',
    },
    warning: {
      'pt': 'Indicado apenas para reversão urgente da dabigatrana (cirurgia de emergência, sangramento grave). Reiniciar dabigatrana 24h após se homeostase restabelecida.',
      'es': 'Solo para reversión urgente de dabigatrán. Reiniciar dabigatrán 24h después si hemostasia restablecida.',
    },
    adverse: {
      'pt': ['Trombose (risco ao reverter anticoagulação)', 'Reação de hipersensibilidade', 'Cefaleia', 'Hipoalbuminemia transitória', 'Febre'],
      'es': ['Trombosis', 'Hipersensibilidad', 'Cefalea', 'Hipoalbuminemia transitoria', 'Fiebre'],
    },
  ),

  // ── ANTIBIÓTICOS ──────────────────────────────────────────────────────────

  DrugModel(
    id: 'daptomicina',
    group: 'Antibióticos',
    name: 'Daptomicina (Cubicin)',
    className: {'pt': 'Lipopeptídeo cíclico', 'es': 'Lipopéptido cíclico'},
    category: {'pt': 'Antibióticos Gram-positivos', 'es': 'Antibióticos Gram-positivos'},
    route: 'IV',
    doseType: 'weight',
    mgKg: 6.0,
    fixedDose: {
      'pt': 'Infecções de pele: 4 mg/kg IV 1x/dia. Bacteremia/endocardite por S. aureus: 6 mg/kg IV 1x/dia. Infusão em 30 min ou bolus em 2 min.',
      'es': 'Infecciones piel: 4 mg/kg IV 1v/día. Bacteremia/endocarditis S. aureus: 6 mg/kg IV 1v/día.',
    },
    renalAlert: {
      'pt': 'ClCr <30 mL/min: administrar a cada 48h. Diálise/CAPD: 4–6 mg/kg a cada 48h (após sessão de HD).',
      'es': 'ClCr <30 mL/min: cada 48h. Diálisis: 4–6 mg/kg cada 48h (después de HD).',
    },
    elderlyAlert: {
      'pt': 'Monitorar CPK semanalmente. Risco de miopatia aumentado com estatinas concomitantes.',
      'es': 'Monitorizar CPK semanalmente. Risco de miopatía aumentado con estatinas.',
    },
    mechanism: {
      'pt': 'Insere-se na membrana citoplasmática de bactérias Gram-positivas, causando despolarização e morte celular rápida. Bactericida concentração-dependente.',
      'es': 'Se inserta en la membrana citoplasmática de Gram-positivos → despolarización y muerte celular rápida. Bactericida concentración-dependiente.',
    },
    warning: {
      'pt': 'INATIVADA pelo surfactante pulmonar — NÃO usar em pneumonia. Suspender estatinas durante uso. Monitorar CPK (risco de rabdomiólise).',
      'es': 'INACTIVADA por surfactante pulmonar — NO usar en neumonía. Suspender estatinas. Monitorizar CPK.',
    },
    adverse: {
      'pt': ['Miopatia/rabdomiólise (monitorar CPK)', 'Neuropatia periférica', 'Eosinofilia', 'Diarreia', 'Elevação de transaminases'],
      'es': ['Miopatía/rabdomiólisis', 'Neuropatía periférica', 'Eosinofilia', 'Diarrea', 'Elevación transaminasas'],
    },
  ),

  DrugModel(
    id: 'ceftarolina',
    group: 'Antibióticos',
    name: 'Ceftarolina (Zinforo)',
    className: {'pt': 'Cefalosporina de 5ª geração (anti-MRSA)', 'es': 'Cefalosporina 5ª generación (anti-MRSA)'},
    category: {'pt': 'Cefalosporinas', 'es': 'Cefalosporinas'},
    route: 'IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': '600 mg IV a cada 12h (infusão em 60 min) por 5–14 dias. Pneumonia grave: 600 mg a cada 8h.',
      'es': '600 mg IV cada 12h (infusión 60 min) por 5–14 días. Neumonía grave: 600 mg cada 8h.',
    },
    renalAlert: {
      'pt': 'ClCr 30–50 mL/min: 400 mg a cada 12h. ClCr 15–30 mL/min: 300 mg a cada 12h. Hemodiálise: 200 mg a cada 12h (dose após HD nos dias de diálise).',
      'es': 'ClCr 30–50: 400 mg/12h. ClCr 15–30: 300 mg/12h. HD: 200 mg/12h.',
    },
    elderlyAlert: {
      'pt': 'Avaliar função renal; ajustar dose conforme ClCr. Seguro em idosos com ajuste adequado.',
      'es': 'Evaluar función renal; ajustar dosis según ClCr.',
    },
    mechanism: {
      'pt': 'Liga-se à proteína de ligação à penicilina PBP2a (presente no MRSA) → inibição da síntese da parede celular. Único β-lactâmico ativo contra MRSA sem resistência cruzada com oxacilina.',
      'es': 'Se une a PBP2a (presente en MRSA) → inhibición de síntesis de pared celular. Único β-lactámico activo contra MRSA.',
    },
    warning: {
      'pt': 'Reservar para infecções por MRSA ou Streptococcus pneumoniae resistente. Pode causar teste de Coombs direto positivo (anemia hemolítica rara).',
      'es': 'Reservar para MRSA o S. pneumoniae resistente. Puede causar Coombs directo positivo.',
    },
    adverse: {
      'pt': ['Diarreia', 'Náuseas', 'Rash', 'Teste de Coombs positivo (anemia hemolítica rara)', 'Flebite no local IV'],
      'es': ['Diarrea', 'Náuseas', 'Rash', 'Coombs positivo (anemia hemolítica rara)', 'Flebitis local IV'],
    },
  ),

  DrugModel(
    id: 'tedizolida',
    group: 'Antibióticos',
    name: 'Tedizolida (Sivextro)',
    className: {'pt': 'Oxazolidinona de 2ª geração', 'es': 'Oxazolidinona de 2ª generación'},
    category: {'pt': 'Antibióticos Gram-positivos', 'es': 'Antibióticos Gram-positivos'},
    route: 'VO / IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': '200 mg 1x/dia (VO ou IV) por 6 dias para SSSI. Bioequivalência VO/IV — mudança de via sem necessidade de ajuste.',
      'es': '200 mg 1v/día (VO o IV) por 6 días para SSSI. Bioequivalencia VO/IV.',
    },
    renalAlert: {
      'pt': 'Sem ajuste de dose em DRC ou diálise.',
      'es': 'Sin ajuste en ERC o diálisis.',
    },
    elderlyAlert: {
      'pt': 'Sem ajuste necessário. Perfil de interações mais favorável que linezolida.',
      'es': 'Sin ajuste. Perfil de interacciones más favorable que linezolida.',
    },
    mechanism: {
      'pt': 'Inibe síntese proteica bacteriana ligando-se à subunidade 23S do RNA ribossômico 50S → impede formação do complexo de iniciação 70S. Bacteriostático contra enterococos e estafilococos.',
      'es': 'Inhibe síntesis proteica uniéndose a ARNr 23S subunidad 50S → impide formación del complejo 70S.',
    },
    warning: {
      'pt': 'Menor inibição da MAO que linezolida → menos interações serotoninérgicas e com tiramina. Monitorar contagem sanguínea em uso prolongado (trombocitopenia possível).',
      'es': 'Menor inhibición MAO que linezolida → menos interacciones serotoninérgicas. Monitorizar hemograma en uso prolongado.',
    },
    adverse: {
      'pt': ['Náuseas', 'Cefaleia', 'Diarreia', 'Vômitos', 'Tontura', 'Trombocitopenia (rara)'],
      'es': ['Náuseas', 'Cefalea', 'Diarrea', 'Vómitos', 'Mareo', 'Trombocitopenia (rara)'],
    },
  ),

  DrugModel(
    id: 'ceftolozano_taz',
    group: 'Antibióticos',
    name: 'Ceftolozano/Tazobactam (Zerbaxa)',
    className: {'pt': 'Cefalosporina de 5ª geração + inibidor de β-lactamase', 'es': 'Cefalosporina 5ª gen + inhibidor β-lactamasa'},
    category: {'pt': 'Antibióticos Gram-negativos MDR', 'es': 'Antibióticos Gram-negativos MDR'},
    route: 'IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Infecções intra-abdominais: 1,5 g IV a cada 8h por 4–14 dias. Pneumonia nosocomial/associada à VM: 3 g a cada 8h por 8–14 dias.',
      'es': 'IIA: 1,5 g IV cada 8h por 4–14 días. NAV/NAH: 3 g cada 8h por 8–14 días.',
    },
    renalAlert: {
      'pt': 'ClCr 30–50 mL/min: 750 mg a cada 8h. ClCr 15–29 mL/min: 375 mg a cada 8h. HDVVC: 1,5 g bolus + 900 mg a cada 8h.',
      'es': 'ClCr 30–50: 750 mg/8h. ClCr 15–29: 375 mg/8h. HDVVC: 1,5 g bolus + 900 mg/8h.',
    },
    elderlyAlert: {
      'pt': 'Ajuste baseado no ClCr. Monitorar função renal durante tratamento.',
      'es': 'Ajustar según ClCr. Monitorizar función renal.',
    },
    mechanism: {
      'pt': 'Ceftolozano liga-se a PBPs com alta afinidade em Pseudomonas aeruginosa MDR; tazobactam inibe β-lactamases de espectro estendido (ESBL), proteindo ceftolozano da degradação.',
      'es': 'Ceftolozano se une a PBPs con alta afinidad en P. aeruginosa MDR; tazobactam inhibe ESBL.',
    },
    warning: {
      'pt': 'Ativo contra P. aeruginosa MDR e produtor de ESBL. NÃO cobre carbapenemases (KPC, MBL). Reservar para patógenos confirmados resistentes.',
      'es': 'Activo contra P. aeruginosa MDR y ESBL. NO cubre carbapenemasas. Reservar para patógenos resistentes confirmados.',
    },
    adverse: {
      'pt': ['Náuseas', 'Diarreia', 'Cefaleia', 'Febre', 'Elevação de transaminases', 'Hipocalemia'],
      'es': ['Náuseas', 'Diarrea', 'Cefalea', 'Fiebre', 'Elevación transaminasas', 'Hipopotasemia'],
    },
  ),

  DrugModel(
    id: 'cefiderocol',
    group: 'Antibióticos',
    name: 'Cefiderocol (Fetcroja)',
    className: {'pt': 'Cefalosporina siderófora (siderophore cephalosporin)', 'es': 'Cefalosporina siderófora'},
    category: {'pt': 'Antibióticos Gram-negativos XDR/PDR', 'es': 'Antibióticos Gram-negativos XDR/PDR'},
    route: 'IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': '2 g IV a cada 8h em infusão de 3 horas (infusão prolongada). Ajustar conforme função renal.',
      'es': '2 g IV cada 8h en infusión de 3 horas (infusión prolongada).',
    },
    renalAlert: {
      'pt': 'ClCr 60–89: 2 g/6h. ClCr 30–59: 1,5 g/8h. ClCr 15–29: 1 g/8h. ClCr <15: 0,75 g/12h. HD: 0,75 g/12h + dose extra pós-HD.',
      'es': 'ClCr 60–89: 2g/6h. ClCr 30–59: 1,5g/8h. ClCr 15–29: 1g/8h. ClCr <15: 0,75g/12h.',
    },
    elderlyAlert: {
      'pt': 'Ajuste rigoroso conforme ClCr. Monitorar função renal a cada 48–72h em UCI.',
      'es': 'Ajuste estricto por ClCr. Monitorizar función renal cada 48–72h en UCI.',
    },
    mechanism: {
      'pt': 'Usa o sistema de transporte de sideróforos (captação de ferro) da bactéria para penetrar na célula, superando mecanismos de resistência clássicos. Liga-se a PBPs → lise bacteriana. Ativo contra carbapenemases (KPC, MBL, OXA).',
      'es': 'Usa el sistema de sideróforos para penetrar la bacteria, superando resistencias clásicas. Activo contra carbapenemasas (KPC, MBL, OXA).',
    },
    warning: {
      'pt': 'Reservar exclusivamente para infecções por organismos XDR/PDR (Acinetobacter baumannii, Pseudomonas aeruginosa, Enterobacteriaceae com carbapenemases). Uso sob supervisão de infectologista.',
      'es': 'Reservar exclusivamente para XDR/PDR. Uso bajo supervisión de infectólogo.',
    },
    adverse: {
      'pt': ['Diarreia', 'Constipação', 'Náuseas', 'Infecção por C. difficile', 'Elevação de transaminases', 'Hipocalemia'],
      'es': ['Diarrea', 'Estreñimiento', 'Náuseas', 'Infección por C. difficile', 'Elevación transaminasas', 'Hipopotasemia'],
    },
  ),

  DrugModel(
    id: 'sulfametoxazol_tmp_iv',
    group: 'Antibióticos',
    name: 'Sulfametoxazol/Trimetoprima IV (Bactrim IV)',
    className: {'pt': 'Sulfonamida + inibidor da dihidrofolato redutase', 'es': 'Sulfonamida + inhibidor dihidrofolato reductasa'},
    category: {'pt': 'Antibióticos Gram-negativos / Pneumocystis', 'es': 'Antibióticos Gram-negativos / Pneumocystis'},
    route: 'IV',
    doseType: 'weight',
    mgKg: 15.0,
    fixedDose: {
      'pt': 'Pneumocistose (PCP): 15–20 mg/kg/dia de TMP IV dividido a cada 6–8h por 21 dias. ITU complicada: 8–10 mg/kg/dia de TMP IV em 3–4 doses.',
      'es': 'PCP: 15–20 mg/kg/día TMP IV dividido cada 6–8h por 21 días. ITU complicada: 8–10 mg/kg/día TMP IV.',
    },
    renalAlert: {
      'pt': 'ClCr 15–30 mL/min: reduzir 50% da dose. ClCr <15 mL/min: contraindicado (exceto para PCP sem alternativa). Monitorar creatinina e K⁺.',
      'es': 'ClCr 15–30: reducir 50%. ClCr <15: contraindicado (excepto PCP sin alternativa).',
    },
    elderlyAlert: {
      'pt': 'Alto risco de hipercalemia e nefrotoxicidade. Monitorar eletrólitos e função renal a cada 48–72h.',
      'es': 'Alto riesgo hipercalemia y nefrotoxicidad. Monitorizar electrólitos y función renal cada 48–72h.',
    },
    mechanism: {
      'pt': 'Trimetoprima inibe a dihidrofolato redutase; sulfametoxazol inibe a dihidropteroato sintase → inibição sequencial e sinérgica da síntese de ácido fólico bacteriano.',
      'es': 'Trimetoprima inhibe dihidrofolato reductasa; sulfametoxazol inhibe dihidropteroato sintasa → inhibición sinérgica síntesis folato bacteriano.',
    },
    warning: {
      'pt': 'Hipercalemia (trimetoprima bloqueia canais de Na⁺ renais como amilorida). Nefrotoxicidade. Mielossupressão em uso prolongado. Monitorar K⁺ diariamente na dose PCP.',
      'es': 'Hipercalemia (TMP bloquea canales Na⁺ renales). Nefrotoxicidad. Mielosupresión. Monitorizar K⁺ diariamente.',
    },
    adverse: {
      'pt': ['Hipercalemia', 'Nefrotoxicidade', 'Náuseas/vômitos', 'Rash (incluindo Stevens-Johnson)', 'Mielossupressão', 'Fototoxicidade'],
      'es': ['Hipercalemia', 'Nefrotoxicidad', 'Náuseas/vómitos', 'Rash (incluyendo Stevens-Johnson)', 'Mielosupresión', 'Fototoxicidad'],
    },
  ),

  // ── NEUROLOGIA / PSIQUIATRIA ──────────────────────────────────────────────

  DrugModel(
    id: 'perampanel',
    group: 'Neurología y Psiquiatría',
    name: 'Perampanel (Fycompa)',
    className: {'pt': 'Antagonista seletivo não competitivo do receptor AMPA', 'es': 'Antagonista selectivo no competitivo del receptor AMPA'},
    category: {'pt': 'Antiepilépticos', 'es': 'Antiepilépticos'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Iniciar 2 mg/dia ao deitar; aumentar 2 mg/semana. Dose alvo: 4–12 mg/dia. Máximo 12 mg/dia.',
      'es': 'Iniciar 2 mg/día al acostarse; aumentar 2 mg/semana. Dosis objetivo: 4–12 mg/día.',
    },
    renalAlert: {
      'pt': 'Sem ajuste em DRC leve-moderada. Cautela em DRC grave (dados limitados).',
      'es': 'Sin ajuste en ERC leve-moderada. Precaución en ERC grave.',
    },
    elderlyAlert: {
      'pt': 'Iniciar com dose mínima. Alto risco de tontura, quedas e confusão mental.',
      'es': 'Iniciar con dosis mínima. Alto riesgo de mareo, caídas y confusión.',
    },
    mechanism: {
      'pt': 'Bloqueia seletivamente os receptores AMPA (ácido α-amino-3-hidroxi-5-metil-4-isoxazolpropiônico) de glutamato → redução da excitabilidade neuronal.',
      'es': 'Bloquea selectivamente receptores AMPA de glutamato → reducción excitabilidad neuronal.',
    },
    warning: {
      'pt': 'Distúrbios psiquiátricos dose-dependentes (agressividade, hostilidade, ideação suicida). Sonolência importante especialmente no início. Interações com indutores enzimáticos (carbamazepina, fenitoína).',
      'es': 'Trastornos psiquiátricos dosis-dependientes (agresividad, ideación suicida). Somnolencia. Interacciones con inductores enzimáticos.',
    },
    adverse: {
      'pt': ['Tontura', 'Sonolência', 'Ataxia', 'Irritabilidade/agressividade', 'Cefaleia', 'Náuseas', 'Ganho de peso'],
      'es': ['Mareo', 'Somnolencia', 'Ataxia', 'Irritabilidad/agresividad', 'Cefalea', 'Náuseas', 'Aumento de peso'],
    },
  ),

  DrugModel(
    id: 'brivaracetam',
    group: 'Neurología y Psiquiatría',
    name: 'Brivaracetam (Briviact)',
    className: {'pt': 'Antiepiléptico – ligante da SV2A (análogo do levetiracetam)', 'es': 'Antiepiléptico – ligante SV2A (análogo levetiracetam)'},
    category: {'pt': 'Antiepilépticos', 'es': 'Antiepilépticos'},
    route: 'VO / IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Iniciar 50 mg 2x/dia; pode ajustar para 25–100 mg 2x/dia. IV: mesma dose, administrar em ≥15 min.',
      'es': 'Iniciar 50 mg 2v/día; ajustar 25–100 mg 2v/día. IV: misma dosis en ≥15 min.',
    },
    renalAlert: {
      'pt': 'Sem ajuste de dose em DRC (metabolismo hepático predominante).',
      'es': 'Sin ajuste en ERC (metabolismo hepático predominante).',
    },
    elderlyAlert: {
      'pt': 'Monitorar sintomas psiquiátricos. Iniciar com dose menor (25 mg 2x/dia).',
      'es': 'Monitorizar síntomas psiquiátricos. Iniciar con dosis menor.',
    },
    mechanism: {
      'pt': 'Liga-se à proteína de vesícula sináptica 2A (SV2A) com afinidade 15–30× maior que levetiracetam → maior eficácia anticonvulsivante com menor dose.',
      'es': 'Se une a SV2A con afinidad 15–30× mayor que levetiracetam → mayor eficacia anticonvulsivante.',
    },
    warning: {
      'pt': 'Menor incidência de distúrbios comportamentais que levetiracetam. Reduzir 50% da dose com rifampicina (indutor potente). Não requer titulação lenta — pode iniciar na dose terapêutica.',
      'es': 'Menor incidencia trastornos conductuales que levetiracetam. Reducir 50% con rifampicina. No requiere titulación lenta.',
    },
    adverse: {
      'pt': ['Sonolência', 'Tontura', 'Fadiga', 'Náuseas', 'Distúrbios comportamentais (menos que LEV)', 'Convulsões (raramente piora)'],
      'es': ['Somnolencia', 'Mareo', 'Fatiga', 'Náuseas', 'Trastornos conductuales (menos que LEV)'],
    },
  ),

  DrugModel(
    id: 'aripiprazol',
    group: 'Neurología y Psiquiatría',
    name: 'Aripiprazol (Abilify)',
    className: {'pt': 'Antipsicótico atípico – agonista parcial D2/D3 e 5-HT1A', 'es': 'Antipsicótico atípico – agonista parcial D2/D3 y 5-HT1A'},
    category: {'pt': 'Antipsicóticos', 'es': 'Antipsicóticos'},
    route: 'VO / IM',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Esquizofrenia: 10–30 mg/dia VO (iniciar 10–15 mg/dia). Mania bipolar: 15–30 mg/dia. Agitação IM: 9,75 mg (máx. 29,25 mg/dia IM).',
      'es': 'Esquizofrenia: 10–30 mg/día VO. Manía bipolar: 15–30 mg/día. Agitación IM: 9,75 mg.',
    },
    renalAlert: {
      'pt': 'Sem ajuste de dose necessário.',
      'es': 'Sin ajuste de dosis.',
    },
    elderlyAlert: {
      'pt': 'Demência com psicose: risco aumentado de AVC e morte. Iniciar com doses mínimas. Monitorar PA ortostática.',
      'es': 'Demencia con psicosis: riesgo aumentado ACV y muerte. Iniciar con dosis mínimas.',
    },
    mechanism: {
      'pt': 'Agonismo parcial em receptores D2 e D3 (não bloqueia totalmente → menos efeitos extrapiramidais); agonismo parcial em 5-HT1A; antagonismo em 5-HT2A.',
      'es': 'Agonismo parcial D2/D3 (menos EPS); agonismo parcial 5-HT1A; antagonismo 5-HT2A.',
    },
    warning: {
      'pt': 'Menor risco de síndrome metabólica e ganho de peso que olanzapina/quetiapina. Menor risco de prolongamento QT. Síndrome de jogo compulsivo (rare mas descrito — alerta FDA).',
      'es': 'Menor riesgo síndrome metabólico y ganancia de peso. Menor prolongación QT. Juego compulsivo (raro — alerta FDA).',
    },
    adverse: {
      'pt': ['Acatisia (frequente)', 'Insônia', 'Cefaleia', 'Náuseas', 'Ganho de peso (menor que outros)', 'Agitação'],
      'es': ['Acatisia (frecuente)', 'Insomnio', 'Cefalea', 'Náuseas', 'Aumento de peso (menor)', 'Agitación'],
    },
  ),

  DrugModel(
    id: 'bupropiona',
    group: 'Neurología y Psiquiatría',
    name: 'Bupropiona (Wellbutrin / Zyban)',
    className: {'pt': 'Inibidor da recaptação de dopamina e noradrenalina (NDRI)', 'es': 'Inhibidor recaptación dopamina y noradrenalina (NDRI)'},
    category: {'pt': 'Antidepressivos / Cessação tabágica', 'es': 'Antidepresivos / Cesación tabáquica'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Depressão: 150 mg/dia (liberação prolongada) por 3 dias; aumentar para 300 mg/dia (1 comprimido pela manhã). Tabagismo: 150 mg/dia por 3 dias; aumentar para 150 mg 2x/dia por 7–12 semanas.',
      'es': 'Depresión: 150 mg/día LP por 3 días; aumentar 300 mg/día. Tabaquismo: 150 mg/día 3 días; 150 mg 2v/día por 7–12 semanas.',
    },
    renalAlert: {
      'pt': 'DRC grave/DRET: reduzir frequência e/ou dose. Monitorar toxicidade do SNC.',
      'es': 'ERC grave/DRET: reducir frecuencia/dosis. Monitorizar toxicidad SNC.',
    },
    elderlyAlert: {
      'pt': 'Pode elevar PA levemente. Monitorar pressão arterial. Não provoca sedação — vantagem sobre TCAs.',
      'es': 'Puede elevar PA levemente. Monitorizar PA. Sin sedación — ventaja sobre ADTs.',
    },
    mechanism: {
      'pt': 'Inibe a recaptação de dopamina e noradrenalina nos terminais pré-sinápticos → aumento de DA e NE na fenda sináptica. Fraco bloqueio nicotínico (contribui para cessação tabágica).',
      'es': 'Inhibe recaptación de DA y NE → aumento en sinapsis. Bloqueo nicotínico débil (contribuye a cesación tabáquica).',
    },
    warning: {
      'pt': 'Reduz o limiar convulsivo — CONTRAINDICADO em epilepsia, bulimia, anorexia, uso de IMAOs. Risco de convulsão aumenta com doses >300 mg em dose única. Não provoca disfunção sexual (vantagem sobre SSRIs).',
      'es': 'CONTRAINDICADO en epilepsia, bulimia, anorexia, IMAOs. Riesgo convulsión aumenta >300 mg en dosis única. Sin disfunción sexual.',
    },
    adverse: {
      'pt': ['Convulsões (dose-dependente)', 'Insônia', 'Boca seca', 'Cefaleia', 'Agitação/ansiedade', 'Elevação de PA', 'Náuseas'],
      'es': ['Convulsiones (dosis-dependiente)', 'Insomnio', 'Boca seca', 'Cefalea', 'Agitación/ansiedad', 'Elevación PA', 'Náuseas'],
    },
  ),

  DrugModel(
    id: 'lisdexanfetamina',
    group: 'Neurología y Psiquiatría',
    name: 'Lisdexanfetamina (Vyvanse)',
    className: {'pt': 'Pró-fármaco da d-anfetamina – estimulante do SNC', 'es': 'Profármaco d-anfetamina – estimulante SNC'},
    category: {'pt': 'Estimulantes / TDAH', 'es': 'Estimulantes / TDAH'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'TDAH adultos: iniciar 30 mg/dia de manhã; aumentar 20 mg/semana. Dose alvo: 30–70 mg/dia. Máximo: 70 mg/dia.',
      'es': 'TDAH adultos: iniciar 30 mg/día mañana; aumentar 20 mg/semana. Objetivo: 30–70 mg/día.',
    },
    renalAlert: {
      'pt': 'ClCr 15–<30 mL/min: máximo 50 mg/dia. DRET: máximo 30 mg/dia.',
      'es': 'ClCr 15–<30: máximo 50 mg/día. DRET: máximo 30 mg/día.',
    },
    elderlyAlert: {
      'pt': 'Não indicado rotineiramente em idosos. Risco cardiovascular aumentado.',
      'es': 'No indicado rutinariamente en ancianos. Riesgo cardiovascular aumentado.',
    },
    mechanism: {
      'pt': 'Pró-fármaco: a lisina é clivada por aminopeptidases no intestino/sangue → libera d-anfetamina → inibe recaptação e promove liberação de DA e NE nos terminais pré-sinápticos.',
      'es': 'Profármaco: la lisina es escindida → libera d-anfetamina → inhibe recaptación y promueve liberación DA/NE.',
    },
    warning: {
      'pt': 'Substância controlada (psicotrópico lista A2). Risco de abuso/dependência (menor que anfetaminas de liberação imediata pelo perfil farmacocinético). Monitorar PA, FC e peso.',
      'es': 'Sustancia controlada. Riesgo abuso/dependencia. Monitorizar PA, FC y peso.',
    },
    adverse: {
      'pt': ['Insônia', 'Anorexia/perda de peso', 'Taquicardia', 'Hipertensão', 'Boca seca', 'Irritabilidade', 'Cefaleia'],
      'es': ['Insomnio', 'Anorexia/pérdida de peso', 'Taquicardia', 'Hipertensión', 'Boca seca', 'Irritabilidad', 'Cefalea'],
    },
  ),

  // ── ENDOCRINOLOGIA / METABOLISMO ──────────────────────────────────────────

  DrugModel(
    id: 'semaglutida',
    group: 'Endocrinología y Metabolismo',
    name: 'Semaglutida (Ozempic / Wegovy / Rybelsus)',
    className: {'pt': 'Agonista do receptor GLP-1 (arGLP-1)', 'es': 'Agonista del receptor GLP-1 (arGLP-1)'},
    category: {'pt': 'Hipoglicemiantes / Obesidade', 'es': 'Hipoglicemiantes / Obesidad'},
    route: 'SC / VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'SC (Ozempic – DM2): 0,25 mg/semana por 4 semanas → 0,5 mg/semana → 1 mg/semana. SC (Wegovy – obesidade): 0,25→0,5→1→1,7→2,4 mg/semana (escalonamento mensal). VO (Rybelsus): 3→7→14 mg/dia.',
      'es': 'SC (DM2): 0,25 mg/sem × 4 sem → 0,5 → 1 mg/sem. SC (obesidad): 0,25→0,5→1→1,7→2,4 mg/sem. VO: 3→7→14 mg/día.',
    },
    renalAlert: {
      'pt': 'Sem ajuste de dose em DRC. Monitorar hidratação (náuseas/vômitos podem causar desidratação e IRA pré-renal).',
      'es': 'Sin ajuste en ERC. Monitorizar hidratación (náuseas/vómitos pueden causar IRA prerrenal).',
    },
    elderlyAlert: {
      'pt': 'Cuidado com desidratação pelo efeito gastrintestinal. Eficácia e segurança semelhantes a adultos mais jovens.',
      'es': 'Cuidado con deshidratación. Eficacia y seguridad similares a adultos jóvenes.',
    },
    mechanism: {
      'pt': 'Análogo do GLP-1 com meia-vida de ~1 semana → estimula insulinosecreção glicose-dependente, inibe glucagon, retarda esvaziamento gástrico, reduz apetite (efeito hipotalâmico). Efeito cardiovascular e renal diretos.',
      'es': 'Análogo GLP-1 vida media ~1 semana → secreción insulina glucosa-dependiente, inhibe glucagón, retarda vaciamiento gástrico, reduce apetito. Efectos cardiovascular y renal directos.',
    },
    warning: {
      'pt': 'Risco de pancreatite aguda (suspender se dor abdominal severa). Histórico pessoal/familiar de carcinoma medular de tireoide ou NEM2: CONTRAINDICADO. Pode agravar retinopatia diabética. Monitorar hipoglicemia se associado a insulina/sulfonilureia.',
      'es': 'Riesgo de pancreatitis. Carcinoma medular tiroideo/NEM2: CONTRAINDICADO. Puede agravar retinopatía. Monitorizar hipoglucemia si asociado a insulina/sulfonilurea.',
    },
    adverse: {
      'pt': ['Náuseas (muito frequente)', 'Vômitos', 'Diarreia', 'Constipação', 'Pancreatite (raro)', 'Agravamento de retinopatia', 'Neoplasia tireoidiana (raro em humanos)', 'Dor abdominal'],
      'es': ['Náuseas (muy frecuente)', 'Vómitos', 'Diarrea', 'Estreñimiento', 'Pancreatitis (raro)', 'Agravamiento retinopatía', 'Dolor abdominal'],
    },
  ),

  DrugModel(
    id: 'tirzepatida',
    group: 'Endocrinología y Metabolismo',
    name: 'Tirzepatida (Mounjaro / Zepbound)',
    className: {'pt': 'Agonista duplo GIP/GLP-1 (twincretin)', 'es': 'Agonista dual GIP/GLP-1 (twincretin)'},
    category: {'pt': 'Hipoglicemiantes / Obesidade', 'es': 'Hipoglicemiantes / Obesidad'},
    route: 'SC',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'DM2: iniciar 2,5 mg/semana × 4 semanas → 5 mg → (7,5 → 10 → 12,5 → 15 mg conforme tolerância, a cada 4 semanas). Obesidade: mesma escada, máximo 15 mg/semana.',
      'es': 'DM2: iniciar 2,5 mg/sem × 4 sem → 5 mg → (7,5→10→12,5→15 mg cada 4 sem). Obesidad: misma escala, máx 15 mg/sem.',
    },
    renalAlert: {
      'pt': 'Sem ajuste de dose em DRC. Monitorar hidratação (risco de IRA pré-renal por vômitos/diarreia).',
      'es': 'Sin ajuste en ERC. Monitorizar hidratación.',
    },
    elderlyAlert: {
      'pt': 'Menor velocidade de titulação em idosos. Hidratação oral adequada essencial.',
      'es': 'Titulación más lenta en ancianos. Hidratación oral adecuada esencial.',
    },
    mechanism: {
      'pt': 'Ativação simultânea de receptores GIP e GLP-1 → potenciação sinérgica da insulinosecreção, redução do glucagon, esvaziamento gástrico lento e saciedade. Redução de peso corporal superior ao GLP-1 isolado.',
      'es': 'Activación simultánea receptores GIP y GLP-1 → potenciación sinérgica insulinosecreción, reducción glucagón, saciedad. Mayor pérdida de peso que GLP-1 solo.',
    },
    warning: {
      'pt': 'Não usar em carcinoma medular de tireoide ou NEM2. Risco de pancreatite. Pode causar hipoglicemia quando associado a insulina ou sulfonilureia. Retardar titulação se intolerância GI.',
      'es': 'No usar en carcinoma medular tiroideo/NEM2. Riesgo pancreatitis. Hipoglucemia con insulina/sulfonilurea.',
    },
    adverse: {
      'pt': ['Náuseas (muito frequente)', 'Diarreia', 'Vômitos', 'Constipação', 'Dor abdominal', 'Pancreatite (raro)', 'Colecistite (raro)', 'Reação no local de injeção'],
      'es': ['Náuseas', 'Diarrea', 'Vómitos', 'Estreñimiento', 'Dolor abdominal', 'Pancreatitis (raro)', 'Colecistitis (raro)'],
    },
  ),

  DrugModel(
    id: 'finerenona',
    group: 'Endocrinología y Metabolismo',
    name: 'Finerenona (Kerendia)',
    className: {'pt': 'Antagonista não esteroidal dos receptores de mineralocorticoides (nsARM)', 'es': 'Antagonista no esteroidal mineralocorticoides (nsARM)'},
    category: {'pt': 'Nefroproteção em DRC/DM2', 'es': 'Nefroprotección ERC/DM2'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'K⁺ ≤4,8 mEq/L e TFG ≥60: iniciar 20 mg/dia. TFG 25–59: iniciar 10 mg/dia; aumentar para 20 mg/dia se K⁺ ≤4,8 mEq/L após 4 semanas.',
      'es': 'K⁺ ≤4,8 y TFG ≥60: iniciar 20 mg/día. TFG 25–59: iniciar 10 mg/día; aumentar a 20 mg si K⁺ ≤4,8 tras 4 sem.',
    },
    renalAlert: {
      'pt': 'Contraindicado em TFG <25 mL/min/1,73m². Monitorar K⁺ na semana 4 e a cada 3–4 meses após. Suspender se K⁺ >5,5 mEq/L.',
      'es': 'Contraindicado TFG <25. Monitorizar K⁺ semana 4 y cada 3–4 meses. Suspender si K⁺ >5,5.',
    },
    elderlyAlert: {
      'pt': 'Monitorar K⁺ e função renal com maior frequência. Risco aumentado de hipercalemia.',
      'es': 'Monitorizar K⁺ y función renal con mayor frecuencia.',
    },
    mechanism: {
      'pt': 'Bloqueia receptores de mineralocorticoides (aldosterona) de forma não esteroidal e seletiva → reduz fibrose renal e cardíaca mediada pela ativação excessiva de aldosterona na DRC diabética.',
      'es': 'Bloquea receptores mineralocorticoides de forma no esteroidal → reduce fibrosis renal y cardíaca mediada por aldosterona en ERC diabética.',
    },
    warning: {
      'pt': 'Hipercalemia é o principal risco. Contraindicado com inibidores potentes do CYP3A4 (claritromicina, cetoconazol) e com outros ARM (espironolactona, eplerenona). Verificar K⁺ antes de cada ajuste de dose.',
      'es': 'Hipercalemia es el principal riesgo. Contraindicado con inhibidores CYP3A4 potentes y otros ARM. Verificar K⁺ antes de cada ajuste.',
    },
    adverse: {
      'pt': ['Hipercalemia', 'Hipotensão', 'Tontura', 'Cefaleia', 'Diarreia'],
      'es': ['Hipercalemia', 'Hipotensión', 'Mareo', 'Cefalea', 'Diarrea'],
    },
  ),

  DrugModel(
    id: 'canagliflozina',
    group: 'Endocrinología y Metabolismo',
    name: 'Canagliflozina (Invokana)',
    className: {'pt': 'Inibidor do SGLT2 (iSGLT2)', 'es': 'Inhibidor SGLT2 (iSGLT2)'},
    category: {'pt': 'Hipoglicemiantes', 'es': 'Hipoglicemiantes'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'DM2: 100 mg/dia antes da primeira refeição; pode aumentar para 300 mg/dia. Nefroproteção em DRC: 100 mg/dia (TFG 45–<60) ou 300 mg/dia (TFG ≥60).',
      'es': 'DM2: 100 mg/día antes primera comida; aumentar a 300 mg/día. Nefroprotección ERC: 100–300 mg/día.',
    },
    renalAlert: {
      'pt': 'TFG <45 mL/min: NÃO iniciar para DM2 (benefício glicêmico mínimo). Para nefroproteção pode usar TFG ≥30. TFG <30: contraindicado. Monitorar TFG periodicamente.',
      'es': 'TFG <45: NO iniciar para DM2. Para nefroprotección TFG ≥30. TFG <30: contraindicado.',
    },
    elderlyAlert: {
      'pt': 'Maior risco de depleção de volume e IRA. Hidratação adequada. Monitorar PA e K⁺.',
      'es': 'Mayor riesgo depleción de volumen e IRA. Hidratación adecuada.',
    },
    mechanism: {
      'pt': 'Inibe o cotransportador SGLT2 no túbulo proximal renal → glicosúria, natriurese, redução da glicemia, pressão intraglomerular e peso corporal. Efeitos cardiorrenal e metabólico independentes do controle glicêmico.',
      'es': 'Inhibe SGLT2 tubular → glucosuria, natriuresis, reducción glicemia, presión intraglomerular y peso. Efectos cardiorrenales independientes del control glucémico.',
    },
    warning: {
      'pt': 'Cetoacidose diabética euglicêmica (rara mas grave — glicemia pode ser normal!). Infecções genitais fúngicas frequentes. Amputações de membros inferiores (risco aumentado vs outros iSGLT2 — alerta FDA). Fraturas ósseas (menor DMO).',
      'es': 'Cetoacidosis euglucémica (glucemia puede ser normal). Infecciones genitales fúngicas. Amputaciones MMII (mayor riesgo vs otros iSGLT2 — alerta FDA). Fracturas óseas.',
    },
    adverse: {
      'pt': ['Infecções genitais fúngicas', 'ITU', 'Poliúria', 'Hipotensão ortostática', 'Cetoacidose euglicêmica', 'Amputação (risco aumentado)', 'Fraturas', 'Hipercalemia (com IECA/ARA-II)'],
      'es': ['Infecciones genitales fúngicas', 'ITU', 'Poliuria', 'Hipotensión ortostática', 'Cetoacidosis euglucémica', 'Amputación (riesgo aumentado)', 'Fracturas'],
    },
  ),

  DrugModel(
    id: 'dulaglutida',
    group: 'Endocrinología y Metabolismo',
    name: 'Dulaglutida (Trulicity)',
    className: {'pt': 'Agonista do receptor GLP-1 (arGLP-1) semanal', 'es': 'Agonista receptor GLP-1 (arGLP-1) semanal'},
    category: {'pt': 'Hipoglicemiantes', 'es': 'Hipoglicemiantes'},
    route: 'SC',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Iniciar 0,75 mg SC 1x/semana; pode aumentar para 1,5 mg → 3 mg → 4,5 mg 1x/semana (escalonamento a cada 4 semanas). Dose máxima: 4,5 mg/semana.',
      'es': 'Iniciar 0,75 mg SC 1v/sem; aumentar 1,5→3→4,5 mg/sem (cada 4 sem). Máx: 4,5 mg/sem.',
    },
    renalAlert: {
      'pt': 'Sem ajuste de dose em DRC. Monitorar hidratação.',
      'es': 'Sin ajuste en ERC. Monitorizar hidratación.',
    },
    elderlyAlert: {
      'pt': 'Eficácia e tolerabilidade similares a adultos mais jovens. Monitorar hidratação e peso.',
      'es': 'Eficacia y tolerabilidad similares. Monitorizar hidratación y peso.',
    },
    mechanism: {
      'pt': 'Análogo do GLP-1 de ação prolongada (fusão com IgG4-Fc) → estímulo glicose-dependente da secreção de insulina, inibição do glucagon, lentificação do esvaziamento gástrico e redução do apetite.',
      'es': 'Análogo GLP-1 larga acción → secreción insulina glucosa-dependiente, inhibición glucagón, lentificación vaciamiento gástrico, reducción apetito.',
    },
    warning: {
      'pt': 'Contraindicada em histórico pessoal/familiar de carcinoma medular de tireoide ou NEM tipo 2. Suspender se pancreatite. Pode causar hipoglicemia quando associado a insulina.',
      'es': 'Contraindicada en carcinoma medular tiroideo/NEM2. Suspender en pancreatitis. Hipoglucemia con insulina.',
    },
    adverse: {
      'pt': ['Náuseas', 'Diarreia', 'Vômitos', 'Constipação', 'Dor abdominal', 'Diminuição do apetite', 'Pancreatite (rara)', 'Bradicardia'],
      'es': ['Náuseas', 'Diarrea', 'Vómitos', 'Estreñimiento', 'Dolor abdominal', 'Disminución apetito', 'Pancreatitis (rara)'],
    },
  ),

  DrugModel(
    id: 'denosumabe',
    group: 'Endocrinología y Metabolismo',
    name: 'Denosumabe (Prolia / Xgeva)',
    className: {'pt': 'Anticorpo monoclonal anti-RANKL (inibidor da osteoclastogênese)', 'es': 'Anticuerpo monoclonal anti-RANKL'},
    category: {'pt': 'Osteoporose / Oncologia óssea', 'es': 'Osteoporosis / Oncología ósea'},
    route: 'SC',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Osteoporose (Prolia): 60 mg SC a cada 6 meses. Metástases ósseas (Xgeva): 120 mg SC a cada 4 semanas (+ dose extra D1, D8 no início para tumores sólidos de alto risco).',
      'es': 'Osteoporosis (Prolia): 60 mg SC cada 6 meses. Metástasis óseas (Xgeva): 120 mg SC cada 4 sem.',
    },
    renalAlert: {
      'pt': 'Sem ajuste de dose (não é eliminado pelo rim). ATENÇÃO: hipocalcemia grave em DRC avançada — repor cálcio e vitamina D antes e durante o tratamento.',
      'es': 'Sin ajuste (no eliminado por riñón). ATENCIÓN: hipocalcemia grave en ERC avanzada — reponer calcio y vitamina D.',
    },
    elderlyAlert: {
      'pt': 'Monitorar cálcio sérico. Suprir vitamina D e cálcio adequadamente. Risco de osteonecrose mandibular (avaliar saúde dental antes de iniciar).',
      'es': 'Monitorizar calcio sérico. Suplementar vitamina D y calcio. Riesgo osteonecrosis mandibular (evaluar salud dental antes de iniciar).',
    },
    mechanism: {
      'pt': 'Anticorpo IgG2 que se liga ao RANKL (receptor activator of nuclear factor kappa-B ligand), impedindo a maturação e ativação dos osteoclastos → redução da reabsorção óssea.',
      'es': 'Anticuerpo IgG2 que se une a RANKL → impide maduración y activación osteoclastos → reduce resorción ósea.',
    },
    warning: {
      'pt': 'EFEITO REBOTE após suspensão: risco de múltiplas fraturas vertebrais nas semanas-meses seguintes. Fazer transição para bisfosfonato ao descontinuar. Hipocalcemia grave (monitorar Ca²⁺ antes de cada dose). Osteonecrose de mandíbula.',
      'es': 'EFECTO REBOTE tras suspensión: riesgo múltiples fracturas vertebrales. Transicionar a bisfosfonato al discontinuar. Hipocalcemia grave. Osteonecrosis mandibular.',
    },
    adverse: {
      'pt': ['Hipocalcemia', 'Osteonecrose de mandíbula', 'Infecções graves (celulite, erisipela)', 'Dor osteomuscular', 'Dermatite/eczema', 'Hipofosfatemia'],
      'es': ['Hipocalcemia', 'Osteonecrosis mandibular', 'Infecciones graves (celulitis)', 'Dolor osteoarticular', 'Dermatitis/eccema', 'Hipofosfatemia'],
    },
  ),

  // ── GASTROENTEROLOGIA ─────────────────────────────────────────────────────

  DrugModel(
    id: 'vedolizumabe',
    group: 'Gastroenterología',
    name: 'Vedolizumabe (Entyvio)',
    className: {'pt': 'Anticorpo monoclonal anti-integrina α4β7 (seletividade intestinal)', 'es': 'Anticuerpo monoclonal anti-integrina α4β7'},
    category: {'pt': 'Doença inflamatória intestinal', 'es': 'Enfermedad inflamatoria intestinal'},
    route: 'IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Indução: 300 mg IV em 30 min nas semanas 0, 2 e 6. Manutenção: 300 mg IV a cada 8 semanas. Forma SC disponível (108 mg/2 semanas) após indução IV.',
      'es': 'Inducción: 300 mg IV 30 min semanas 0, 2 y 6. Mantenimiento: 300 mg IV cada 8 sem. SC: 108 mg/2 sem tras inducción IV.',
    },
    renalAlert: {
      'pt': 'Sem ajuste de dose em DRC.',
      'es': 'Sin ajuste en ERC.',
    },
    elderlyAlert: {
      'pt': 'Sem ajuste necessário. Monitorar infecções.',
      'es': 'Sin ajuste. Monitorizar infecciones.',
    },
    mechanism: {
      'pt': 'Liga-se seletivamente à integrina α4β7 no intestino → impede a migração de linfócitos T para a mucosa intestinal → efeito anti-inflamatório local com mínimos efeitos sistêmicos (seletividade GI).',
      'es': 'Se une selectivamente a integrina α4β7 → impide migración linfocitos T a mucosa intestinal → efecto antiinflamatorio local con mínimos efectos sistémicos.',
    },
    warning: {
      'pt': 'Menor risco de infecções oportunistas sistêmicas que anti-TNF (ação intestino-seletiva). Raras reações de hipersensibilidade durante infusão. Excluir tuberculose ativa antes de iniciar.',
      'es': 'Menor riesgo infecciones oportunistas sistémicas vs anti-TNF. Raras reacciones hipersensibilidad durante infusión. Excluir tuberculosis activa.',
    },
    adverse: {
      'pt': ['Nasofaringite', 'Cefaleia', 'Artralgia', 'Náuseas', 'Febre', 'Infecção do trato respiratório superior', 'Reação de infusão'],
      'es': ['Nasofaringitis', 'Cefalea', 'Artralgia', 'Náuseas', 'Fiebre', 'Infección respiratoria alta', 'Reacción infusión'],
    },
  ),

  DrugModel(
    id: 'tofacitinibe',
    group: 'Gastroenterología',
    name: 'Tofacitinibe (Xeljanz)',
    className: {'pt': 'Inibidor de JAK1/JAK3 (JAKi)', 'es': 'Inhibidor JAK1/JAK3'},
    category: {'pt': 'DII / Artrite Reumatoide', 'es': 'EII / Artritis Reumatoide'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Colite ulcerativa: indução 10 mg 2x/dia por 8 semanas; manutenção 5 mg 2x/dia (ou 10 mg 2x/dia se refratário). AR: 5 mg 2x/dia.',
      'es': 'CU: inducción 10 mg 2v/día × 8 sem; mantenimiento 5 mg 2v/día. AR: 5 mg 2v/día.',
    },
    renalAlert: {
      'pt': 'ClCr <50 mL/min: reduzir para 5 mg 1x/dia. Hemodiálise: 5 mg 1x/dia.',
      'es': 'ClCr <50: reducir a 5 mg 1v/día. Hemodiálisis: 5 mg 1v/día.',
    },
    elderlyAlert: {
      'pt': '>65 anos: usar apenas se não houver alternativa (risco aumentado de eventos cardiovasculares, neoplasias e infecções). Alerta FDA/EMA.',
      'es': '>65 años: usar solo si no hay alternativa. Riesgo aumentado eventos cardiovasculares, neoplasias e infecciones — alerta FDA/EMA.',
    },
    mechanism: {
      'pt': 'Inibe JAK1 e JAK3 → bloqueia a sinalização de citocinas pró-inflamatórias (IL-2, IL-4, IL-6, IL-7, IL-15, interferons) → imunomodulação.',
      'es': 'Inhibe JAK1/JAK3 → bloquea señalización citocinas proinflamatorias → inmunomodulación.',
    },
    warning: {
      'pt': 'Maior risco de eventos adversos graves em pacientes >65 anos, fumantes ou com fatores de risco cardiovascular (MACE, TEV, neoplasias). Rastreio de tuberculose e hepatite B antes de iniciar. Não combinar com imunossupressores biológicos.',
      'es': 'Mayor riesgo MACE, TEV y neoplasias en >65 años, fumadores o con factores CV. Cribado TBC y hepatitis B. No combinar con biológicos.',
    },
    adverse: {
      'pt': ['Infecções (zona zoster, pneumonia)', 'Herpes zoster (vacinar antes de iniciar)', 'Dislipidemia', 'Tromboembolismo venoso', 'Neoplasias', 'Anemia', 'Neutropenia'],
      'es': ['Infecciones (herpes zoster, neumonía)', 'Herpes zoster (vacunar antes)', 'Dislipidemia', 'Tromboembolismo venoso', 'Neoplasias', 'Anemia', 'Neutropenia'],
    },
  ),

  DrugModel(
    id: 'rifaximina',
    group: 'Gastroenterología',
    name: 'Rifaximina (Xifaxan)',
    className: {'pt': 'Rifamicina de uso enteral (não absorvível)', 'es': 'Rifamicina enteral no absorbible'},
    category: {'pt': 'Antibióticos intestinais', 'es': 'Antibióticos intestinales'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Encefalopatia hepática: 550 mg 2x/dia (uso crônico). Diarreia do viajante: 200 mg 3x/dia por 3 dias. SII-D: 550 mg 3x/dia por 14 dias.',
      'es': 'Encefalopatía hepática: 550 mg 2v/día (crónico). Diarrea viajero: 200 mg 3v/día × 3 días. SII-D: 550 mg 3v/día × 14 días.',
    },
    renalAlert: {
      'pt': 'Sem ajuste (absorção sistêmica <1%).',
      'es': 'Sin ajuste (absorción sistémica <1%).',
    },
    elderlyAlert: {
      'pt': 'Sem ajuste necessário. Boa tolerabilidade.',
      'es': 'Sin ajuste. Buena tolerabilidad.',
    },
    mechanism: {
      'pt': 'Inibe a subunidade β da RNA polimerase bacteriana dependente de DNA → bactericida de amplo espectro. Ação local no TGI (absorção <1%) → sem efeitos sistêmicos e baixo potencial de interações.',
      'es': 'Inhibe ARN polimerasa bacteriana → bactericida amplio espectro. Acción local TGI → sin efectos sistémicos.',
    },
    warning: {
      'pt': 'NÃO usar para infecções com comprometimento sistêmico ou diarreia com sangue/febre (considerar bacteremia). Em SII, a recorrência após curso de 14 dias é comum (repetir ciclos conforme necessário).',
      'es': 'NO usar para infecciones sistémicas o diarrea con sangre/fiebre. En SII, la recurrencia es común.',
    },
    adverse: {
      'pt': ['Flatulência', 'Náuseas', 'Cefaleia', 'Dor abdominal', 'Infecção por C. difficile (rara)', 'Edema periférico (em hepatopatas)'],
      'es': ['Flatulencia', 'Náuseas', 'Cefalea', 'Dolor abdominal', 'C. difficile (raro)', 'Edema periférico (en hepatópatas)'],
    },
  ),

  // ── RESPIRATÓRIO ──────────────────────────────────────────────────────────

  DrugModel(
    id: 'dupilumabe',
    group: 'Respiratorio',
    name: 'Dupilumabe (Dupixent)',
    className: {'pt': 'Anticorpo monoclonal anti-IL-4Rα (bloqueio IL-4 e IL-13)', 'es': 'Anticuerpo monoclonal anti-IL-4Rα'},
    category: {'pt': 'Biológico – Asma / Dermatite atópica / Rinossinusite', 'es': 'Biológico – Asma / Dermatitis atópica / Rinosinusitis'},
    route: 'SC',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Asma grave eosinofílica: 200 ou 300 mg SC a cada 2 semanas. Dermatite atópica: 600 mg SC (dose de ataque) → 300 mg a cada 2 semanas. Rinossinusite com pólipo: 300 mg a cada 2 semanas.',
      'es': 'Asma grave: 200–300 mg SC cada 2 sem. Dermatitis atópica: 600 mg SC (inicio) → 300 mg cada 2 sem. Rinosinusitis: 300 mg cada 2 sem.',
    },
    renalAlert: {
      'pt': 'Sem ajuste em DRC.',
      'es': 'Sin ajuste en ERC.',
    },
    elderlyAlert: {
      'pt': 'Sem ajuste. Eficácia e segurança similares a adultos mais jovens.',
      'es': 'Sin ajuste. Eficacia y seguridad similares.',
    },
    mechanism: {
      'pt': 'Liga-se ao receptor compartilhado de IL-4 e IL-13 (IL-4Rα) → bloqueia simultaneamente a sinalização de IL-4 e IL-13, citocinas-chave do inflamação tipo 2 (Th2) → redução de eosinófilos, IgE e inflamação mucosa.',
      'es': 'Se une a IL-4Rα → bloquea simultáneamente IL-4 e IL-13 → reducción eosinófilos, IgE e inflamación tipo 2.',
    },
    warning: {
      'pt': 'Não é um broncodilatador de resgate — não usar em crise aguda. Conjuntivite eosinofílica frequente (efeito de classe). Herpes ocular: uso com cautela.',
      'es': 'No es broncodilatador de rescate. Conjuntivitis eosinofílica frecuente (efecto de clase). Herpes ocular: precaución.',
    },
    adverse: {
      'pt': ['Conjuntivite/blefarite', 'Reação no local de injeção', 'Herpes oral/ocular', 'Eosinofilia transitória', 'Artralgia', 'Nasofaringite'],
      'es': ['Conjuntivitis/blefaritis', 'Reacción local inyección', 'Herpes oral/ocular', 'Eosinofilia transitoria', 'Artralgia', 'Nasofaringitis'],
    },
  ),

  DrugModel(
    id: 'mepolizumabe',
    group: 'Respiratorio',
    name: 'Mepolizumabe (Nucala)',
    className: {'pt': 'Anticorpo monoclonal anti-IL-5', 'es': 'Anticuerpo monoclonal anti-IL-5'},
    category: {'pt': 'Biológico – Asma eosinofílica grave', 'es': 'Biológico – Asma eosinofílica grave'},
    route: 'SC / IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Asma eosinofílica grave: 100 mg SC a cada 4 semanas. EGPA (síndrome de Churg-Strauss): 300 mg SC (3 injeções de 100 mg) a cada 4 semanas.',
      'es': 'Asma eosinofílica grave: 100 mg SC cada 4 sem. EGPA: 300 mg SC (3 inyecciones) cada 4 sem.',
    },
    renalAlert: {
      'pt': 'Sem ajuste em DRC.',
      'es': 'Sin ajuste en ERC.',
    },
    elderlyAlert: {
      'pt': 'Sem ajuste necessário. Eficácia demonstrada em idosos com asma eosinofílica.',
      'es': 'Sin ajuste. Eficacia demostrada en ancianos.',
    },
    mechanism: {
      'pt': 'Liga-se seletivamente à IL-5, citocina responsável pela maturação, ativação e sobrevivência dos eosinófilos → redução dramática de eosinófilos no sangue e tecidos.',
      'es': 'Se une selectivamente a IL-5 → reducción drástica eosinófilos en sangre y tejidos.',
    },
    warning: {
      'pt': 'Não é broncodilatador de resgate. Pode reduzir gradualmente corticosteroides sistêmicos (desmame lento para evitar insuficiência adrenal). Confirmar contagem de eosinófilos ≥150/µL antes de iniciar.',
      'es': 'No es broncodilatador de rescate. Puede reducir corticosteroides sistémicos gradualmente. Confirmar eosinófilos ≥150/µL antes de iniciar.',
    },
    adverse: {
      'pt': ['Cefaleia', 'Reação no local de injeção', 'Dor lombar', 'Fadiga', 'Infecção do trato respiratório inferior', 'Herpes zoster (raro)'],
      'es': ['Cefalea', 'Reacción local inyección', 'Lumbalgia', 'Fatiga', 'Infección respiratoria baja', 'Herpes zoster (raro)'],
    },
  ),

  DrugModel(
    id: 'nintedanibe',
    group: 'Respiratorio',
    name: 'Nintedanibe (Ofev)',
    className: {'pt': 'Inibidor de tirosina quinase (anti-fibrótico)', 'es': 'Inhibidor tirosina quinasa (antifibrótico)'},
    category: {'pt': 'Fibrose Pulmonar Idiopática', 'es': 'Fibrosis Pulmonar Idiopática'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': '150 mg 2x/dia com as refeições (para reduzir toxicidade GI). Reduzir para 100 mg 2x/dia em caso de toxicidade não tolerada.',
      'es': '150 mg 2v/día con comidas. Reducir a 100 mg 2v/día en caso de toxicidad GI.',
    },
    renalAlert: {
      'pt': 'Sem ajuste em DRC leve-moderada. Dados limitados em DRC grave.',
      'es': 'Sin ajuste en ERC leve-moderada. Datos limitados en ERC grave.',
    },
    elderlyAlert: {
      'pt': 'Monitorar função hepática e toxicidade GI. Frequência aumentada de diarreia em idosos.',
      'es': 'Monitorizar función hepática y toxicidad GI. Mayor frecuencia diarrea en ancianos.',
    },
    mechanism: {
      'pt': 'Inibe receptores de tirosina quinase (FGFR, VEGFR, PDGFR) → bloqueio de vias de sinalização pró-fibróticas e pró-angiogênicas envolvidas na FPI. Reduz a taxa de declínio da CVF.',
      'es': 'Inhibe FGFR, VEGFR, PDGFR → bloquea vías profibróticas y proangiogénicas en FPI. Reduce tasa de declive CVF.',
    },
    warning: {
      'pt': 'Teratogênico (contracepção obrigatória). Hepatotoxicidade (monitorar TGO/TGP mensalmente nos primeiros 3 meses). Diarreia em ~60% dos pacientes (antidiarreicos e hidratação precoces). Risco de perfuração GI.',
      'es': 'Teratogénico (anticoncepción obligatoria). Hepatotoxicidad (TGO/TGP mensual primeros 3 meses). Diarrea en ~60%. Riesgo perforación GI.',
    },
    adverse: {
      'pt': ['Diarreia (frequente)', 'Náuseas', 'Dor abdominal', 'Hepatotoxicidade', 'Vômitos', 'Perda de peso', 'Hipertensão', 'Sangramentos menores'],
      'es': ['Diarrea (frecuente)', 'Náuseas', 'Dolor abdominal', 'Hepatotoxicidad', 'Vómitos', 'Pérdida de peso', 'Hipertensión', 'Sangrados menores'],
    },
  ),

  // ── HEMATOLOGIA ───────────────────────────────────────────────────────────

  DrugModel(
    id: 'ruxolitinibe',
    group: 'Hematología y Vitaminas',
    name: 'Ruxolitinibe (Jakafi / Jakavi)',
    className: {'pt': 'Inibidor de JAK1/JAK2', 'es': 'Inhibidor JAK1/JAK2'},
    category: {'pt': 'Mielofibrose / Policitemia vera', 'es': 'Mielofibrosis / Policitemia vera'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Mielofibrose: 20 mg 2x/dia (plaquetas >200.000) ou 15 mg 2x/dia (plaquetas 100.000–200.000). Policitemia vera: 10 mg 2x/dia. DECH: 10 mg 2x/dia.',
      'es': 'Mielofibrosis: 20 mg 2v/día (plaquetas >200.000) o 15 mg 2v/día (100.000–200.000). PV: 10 mg 2v/día. EICH: 10 mg 2v/día.',
    },
    renalAlert: {
      'pt': 'ClCr <30 mL/min ou DRET: ajustar dose com base em plaquetometria. HD: dose pós-diálise, não adicional.',
      'es': 'ClCr <30 o DRET: ajustar según plaquetometría. HD: dosis post-diálisis.',
    },
    elderlyAlert: {
      'pt': 'Monitorar infecções oportunistas (herpes zoster frequente — considerar profilaxia). Anemia e trombocitopenia são frequentes.',
      'es': 'Monitorizar infecciones oportunistas (herpes zoster frecuente — considerar profilaxis). Anemia y trombocitopenia frecuentes.',
    },
    mechanism: {
      'pt': 'Inibe JAK1 e JAK2 → bloqueio da sinalização de citocinas pró-inflamatórias e da via JAK-STAT → redução de esplenomegalia, sintomas sistêmicos e progressão da fibrose na mielofibrose.',
      'es': 'Inhibe JAK1/JAK2 → bloquea señalización citocinas y vía JAK-STAT → reducción esplenomegalia y síntomas sistémicos.',
    },
    warning: {
      'pt': 'Imunossupressor potente — maior risco de infecções oportunistas (TB, fungos, herpes zoster, PCP). Reativar hepatite B. Não suspender abruptamente (crise citocínica de rebote). Monitorar hemograma com frequência.',
      'es': 'Inmunosupresor potente. Riesgo infecciones oportunistas (TB, hongos, VZV, PCP). Reactivar hepatitis B. No suspender abruptamente. Monitorizar hemograma.',
    },
    adverse: {
      'pt': ['Anemia', 'Trombocitopenia', 'Neutropenia', 'Infecções (herpes zoster, PCP, TB)', 'Dislipidemia', 'Elevação de transaminases', 'Cefaleia', 'Tontura'],
      'es': ['Anemia', 'Trombocitopenia', 'Neutropenia', 'Infecciones (herpes, PCP, TB)', 'Dislipidemia', 'Elevación transaminasas', 'Cefalea', 'Mareo'],
    },
  ),

  DrugModel(
    id: 'eltrombopague',
    group: 'Hematología y Vitaminas',
    name: 'Eltrombopague (Revolade)',
    className: {'pt': 'Agonista do receptor de trombopoietina (TPO-RA)', 'es': 'Agonista receptor trombopoyetina (TPO-RA)'},
    category: {'pt': 'PTI / Aplasia / Hepatite C', 'es': 'PTI / Aplasia / Hepatitis C'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'PTI: iniciar 50 mg/dia; ajustar 25 mg/semana até plaquetas 50.000–200.000/µL (máx. 75 mg/dia). Aplasia medular grave: 150 mg/dia.',
      'es': 'PTI: iniciar 50 mg/día; ajustar 25 mg/sem hasta plaquetas 50.000–200.000/µL (máx. 75 mg/día). Aplasia: 150 mg/día.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário. Monitorar função hepática e eletrólitos.',
      'es': 'Sin ajuste. Monitorizar función hepática y electrólitos.',
    },
    elderlyAlert: {
      'pt': 'Maior risco de tromboembolismo. Monitorar contagem plaquetária rigorosamente para evitar superdosagem.',
      'es': 'Mayor riesgo tromboembolismo. Monitorizar recuento plaquetario estrictamente.',
    },
    mechanism: {
      'pt': 'Liga-se ao domínio transmembrana do receptor de trombopoietina (cMpl) → estimula a proliferação e diferenciação de megacariócitos → aumento da produção plaquetária.',
      'es': 'Se une al dominio transmembrana del receptor TPO (cMpl) → estimula proliferación megacariocitos → aumento producción plaquetaria.',
    },
    warning: {
      'pt': 'Administrar em jejum (refeições ricas em cálcio reduzem absorção em até 70%). Hepatotoxicidade (monitorar TGO/TGP a cada 2 semanas no início). Risco de TEV se plaquetas >400.000/µL. Cautela em populações de ascendência asiática (maior exposição plasmática).',
      'es': 'Administrar en ayunas (calcio reduce absorción hasta 70%). Hepatotoxicidad (TGO/TGP cada 2 sem). Riesgo TEV si plaquetas >400.000. Precaución en asiáticos (mayor exposición).',
    },
    adverse: {
      'pt': ['Cefaleia', 'Náuseas', 'Hepatotoxicidade', 'Tromboembolismo (se plaquetas elevadas)', 'Cataratas', 'Anemia por rebote (suspensão)', 'Fibrose medular (uso prolongado)'],
      'es': ['Cefalea', 'Náuseas', 'Hepatotoxicidad', 'Tromboembolismo', 'Cataratas', 'Anemia por rebote', 'Fibrosis medular (uso prolongado)'],
    },
  ),

  // ── INFECTOLOGIA ─────────────────────────────────────────────────────────

  DrugModel(
    id: 'nirmatrelvir_ritonavir',
    group: 'Infectología (Antifúngicos / Antivirales / TBC)',
    name: 'Nirmatrelvir/Ritonavir (Paxlovid)',
    className: {'pt': 'Inibidor da protease do SARS-CoV-2 + booster farmacocinético', 'es': 'Inhibidor proteasa SARS-CoV-2 + potenciador farmacocinético'},
    category: {'pt': 'Antivirais – COVID-19', 'es': 'Antivirales – COVID-19'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': '300 mg nirmatrelvir + 100 mg ritonavir 2x/dia por 5 dias. Iniciar em até 5 dias do início dos sintomas.',
      'es': '300 mg nirmatrelvir + 100 mg ritonavir 2v/día por 5 días. Iniciar en ≤5 días del inicio síntomas.',
    },
    renalAlert: {
      'pt': 'ClCr 30–59 mL/min: 150 mg nirmatrelvir + 100 mg ritonavir 2x/dia. ClCr <30 mL/min: CONTRAINDICADO.',
      'es': 'ClCr 30–59: 150 mg nirmatrelvir + 100 mg ritonavir 2v/día. ClCr <30: CONTRAINDICADO.',
    },
    elderlyAlert: {
      'pt': 'Alta prevalência de DRC nos idosos — avaliar ClCr antes de prescrever. MUITAS interações medicamentosas pelo ritonavir (inibidor potente CYP3A4).',
      'es': 'Alta prevalencia ERC en ancianos — evaluar ClCr. MUCHAS interacciones medicamentosas por ritonavir (inhibidor potente CYP3A4).',
    },
    mechanism: {
      'pt': 'Nirmatrelvir inibe a protease principal (Mpro/3CL) do SARS-CoV-2, bloqueando a clivagem das poliproteínas virais → impede a replicação viral. Ritonavir inibe o CYP3A4 → aumenta a meia-vida plasmática do nirmatrelvir.',
      'es': 'Nirmatrelvir inhibe la proteasa principal (Mpro) de SARS-CoV-2 → bloquea replicación viral. Ritonavir inhibe CYP3A4 → aumenta vida media del nirmatrelvir.',
    },
    warning: {
      'pt': 'INTERAÇÕES MEDICAMENTOSAS CRÍTICAS por ritonavir: contraindicado com estatinas metabolizadas por CYP3A4 (sinvastatina, lovastatina), midazolam, triazolam, ergotamina, amiodarona, ranolazina, salmeterol. Verificar TODAS as medicações antes de prescrever (consultar ferramenta de interações). Síndrome de rebote COVID-19 relatada em 2–8% após o curso.',
      'es': 'INTERACCIONES CRÍTICAS por ritonavir: contraindicado con estatinas CYP3A4 (simvastatina), midazolam, triazolam, amiodarona, ranolazina. Verificar TODOS los medicamentos antes de prescribir. Síndrome de rebote COVID-19 en 2–8%.',
    },
    adverse: {
      'pt': ['Disgeusia (gosto metálico)', 'Diarreia', 'Hipertensão', 'Mialgia', 'Náuseas', 'Rebote viral pós-término (2–8%)', 'Interações medicamentosas graves (ritonavir)'],
      'es': ['Disgeusia (sabor metálico)', 'Diarrea', 'Hipertensión', 'Mialgia', 'Náuseas', 'Rebote viral post-tratamiento (2–8%)', 'Interacciones medicamentosas graves'],
    },
  ),

  DrugModel(
    id: 'molnupiravir',
    group: 'Infectología (Antifúngicos / Antivirales / TBC)',
    name: 'Molnupiravir (Lagevrio)',
    className: {'pt': 'Análogo de nucleosídeo – mutagênico viral', 'es': 'Análogo de nucleósido – mutagénico viral'},
    category: {'pt': 'Antivirais – COVID-19', 'es': 'Antivirales – COVID-19'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': '800 mg 2x/dia por 5 dias. Iniciar em até 5 dias do início dos sintomas em adultos com fatores de risco para COVID-19 grave.',
      'es': '800 mg 2v/día por 5 días. Iniciar en ≤5 días del inicio síntomas en adultos con factores de riesgo.',
    },
    renalAlert: {
      'pt': 'Sem ajuste de dose em DRC (incluindo DRET). Sem dados robustos em HD.',
      'es': 'Sin ajuste en ERC (incluido DRET).',
    },
    elderlyAlert: {
      'pt': 'Sem ajuste. Eficácia menor que Paxlovid (redução de ~30% hospitalizações vs ~90% de Paxlovid).',
      'es': 'Sin ajuste. Eficacia menor que Paxlovid (~30% vs ~90% reducción hospitalización).',
    },
    mechanism: {
      'pt': 'Pró-fármaco do nucleosídeo β-D-N4-hidroxicitidina (NHC/EIDD-1931) → incorporado ao RNA viral durante replicação → causa acúmulo de erros de cópia (mutagênese letal) → inibe replicação do SARS-CoV-2.',
      'es': 'Profármaco de NHC → incorporado al ARN viral → acumula errores de copia (mutagénesis letal) → inhibe replicación SARS-CoV-2.',
    },
    warning: {
      'pt': 'CONTRAINDICADO na gestação (potencial mutagênico/teratogênico). Contraindicado em <18 anos (risco teórico de alteração do crescimento ósseo). Menor eficácia que nirmatrelvir/ritonavir — usar Paxlovid preferencialmente se disponível.',
      'es': 'CONTRAINDICADO en embarazo (mutagénico/teratogénico). Contraindicado <18 años. Menor eficacia que Paxlovid — preferir Paxlovid si disponible.',
    },
    adverse: {
      'pt': ['Diarreia', 'Náuseas', 'Tontura', 'Cefaleia', 'Aumento de ALT (transitório)'],
      'es': ['Diarrea', 'Náuseas', 'Mareo', 'Cefalea', 'Elevación ALT (transitoria)'],
    },
  ),

  DrugModel(
    id: 'isavuconazol',
    group: 'Infectología (Antifúngicos / Antivirales / TBC)',
    name: 'Isavuconazol (Cresemba)',
    className: {'pt': 'Triazol de 2ª geração (anti-Aspergillus, anti-Mucor)', 'es': 'Triazol 2ª generación (anti-Aspergillus, anti-Mucor)'},
    category: {'pt': 'Antifúngicos azólicos', 'es': 'Antifúngicos azólicos'},
    route: 'VO / IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Dose de ataque: 200 mg (372 mg de isavuconazonium sulfato) a cada 8h por 6 doses (48h). Manutenção: 200 mg 1x/dia. VO = IV (biodisponibilidade ~98%).',
      'es': 'Carga: 200 mg cada 8h × 6 dosis (48h). Mantenimiento: 200 mg 1v/día. VO = IV (biodisponibilidad ~98%).',
    },
    renalAlert: {
      'pt': 'Sem ajuste de dose em DRC ou diálise.',
      'es': 'Sin ajuste en ERC o diálisis.',
    },
    elderlyAlert: {
      'pt': 'Sem ajuste. Perfil de segurança favorável em relação ao voriconazol (menos fototoxicidade, alucinações e hepatotoxicidade).',
      'es': 'Sin ajuste. Mejor perfil de seguridad vs voriconazol (menos fototoxicidad, alucinaciones y hepatotoxicidad).',
    },
    mechanism: {
      'pt': 'Inibe a lanosterol 14α-desmetilase (CYP51) fúngica → bloqueio da síntese de ergosterol → disrupção da membrana fúngica. Amplo espectro: Aspergillus, Mucor/Rhizopus, Candida (exceto C. krusei).',
      'es': 'Inhibe lanosterol 14α-desmetilasa fúngica → bloqueo síntesis ergosterol. Amplio espectro: Aspergillus, Mucor, Candida.',
    },
    warning: {
      'pt': 'Encurta o intervalo QTc (ao contrário de outros azóis) — pode ser preferido em pacientes com QTc longo. Inibidor moderado de CYP3A4. Contraindicado com rifampicina (indução potente que reduz níveis de isavuconazol).',
      'es': 'Acorta QTc (al contrario de otros azoles). Inhibidor moderado CYP3A4. Contraindicado con rifampicina.',
    },
    adverse: {
      'pt': ['Náuseas', 'Vômitos', 'Cefaleia', 'Hipocalemia', 'Elevação de transaminases', 'Encurtamento QTc', 'Dispneia', 'Dor nas costas'],
      'es': ['Náuseas', 'Vómitos', 'Cefalea', 'Hipopotasemia', 'Elevación transaminasas', 'Acortamiento QTc', 'Disnea', 'Dolor lumbar'],
    },
  ),

  // ── VÁRIOS / ANTÍDOTOS / REUMATOLOGIA ─────────────────────────────────────

  DrugModel(
    id: 'tocilizumabe',
    group: 'Varios / Antídotos / Otros',
    name: 'Tocilizumabe (Actemra)',
    className: {'pt': 'Anticorpo monoclonal anti-receptor de IL-6 (anti-IL-6R)', 'es': 'Anticuerpo monoclonal anti-receptor IL-6'},
    category: {'pt': 'Biológico – AR / Síndrome de liberação de citocinas', 'es': 'Biológico – AR / Síndrome liberación citocinas'},
    route: 'IV / SC',
    doseType: 'weight',
    mgKg: 8.0,
    fixedDose: {
      'pt': 'AR: 4–8 mg/kg IV a cada 4 semanas (máx. 800 mg/dose) ou 162 mg SC semanal/quinzenal. SLC/COVID-19 grave: 8 mg/kg IV (máx. 800 mg); pode repetir 1 dose após 8–24h. AOSD: 8 mg/kg IV a cada 2 semanas.',
      'es': 'AR: 4–8 mg/kg IV cada 4 sem (máx. 800 mg) o 162 mg SC semanal/quincenal. SLC/COVID-19 grave: 8 mg/kg IV (máx. 800 mg); repetir 1 dosis 8–24h si necesario.',
    },
    renalAlert: {
      'pt': 'Sem ajuste de dose em DRC leve-moderada. Monitorar infecções.',
      'es': 'Sin ajuste en ERC leve-moderada. Monitorizar infecciones.',
    },
    elderlyAlert: {
      'pt': '>75 anos: maior risco de infecções graves. Monitorar rigorosamente. Suspender se infecção ativa.',
      'es': '>75 años: mayor riesgo infecciones graves. Monitorizar. Suspender si infección activa.',
    },
    mechanism: {
      'pt': 'Liga-se ao receptor de IL-6 solúvel e de membrana (IL-6R) → bloqueia a sinalização da IL-6, citocina central na resposta inflamatória → redução de marcadores inflamatórios (PCR, ferritina, IL-6).',
      'es': 'Se une al receptor de IL-6 (soluble y de membrana) → bloquea señalización IL-6 → reducción marcadores inflamatorios.',
    },
    warning: {
      'pt': 'Risco de infecções graves (TB, fungos, bactérias). Rastreio de TB antes de iniciar. Pode mascarar febre e PCR (use outras ferramentas diagnósticas). Perfuração GI em pacientes com diverticulite. Monitorar neutrófilos, plaquetas e transaminases.',
      'es': 'Riesgo infecciones graves. Cribado TB antes de iniciar. Puede enmascarar fiebre y PCR. Perforación GI. Monitorizar neutrófilos, plaquetas y transaminasas.',
    },
    adverse: {
      'pt': ['Infecções respiratórias superiores', 'Elevação de transaminases', 'Neutropenia', 'Trombocitopenia', 'Hipertensão', 'Hiperlipidemia', 'Cefaleia', 'Reação de infusão'],
      'es': ['Infecciones respiratorias altas', 'Elevación transaminasas', 'Neutropenia', 'Trombocitopenia', 'Hipertensión', 'Hiperlipidemia', 'Cefalea', 'Reacción infusión'],
    },
  ),

  DrugModel(
    id: 'baricitinibe',
    group: 'Varios / Antídotos / Otros',
    name: 'Baricitinibe (Olumiant)',
    className: {'pt': 'Inibidor seletivo de JAK1/JAK2', 'es': 'Inhibidor selectivo JAK1/JAK2'},
    category: {'pt': 'AR / COVID-19 grave / Alopecia areata', 'es': 'AR / COVID-19 grave / Alopecia areata'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'AR: 2–4 mg/dia. COVID-19 grave (internado, O₂ suplementar): 4 mg/dia por até 14 dias. Alopecia areata: 2–4 mg/dia.',
      'es': 'AR: 2–4 mg/día. COVID-19 grave: 4 mg/día hasta 14 días. Alopecia areata: 2–4 mg/día.',
    },
    renalAlert: {
      'pt': 'ClCr 30–60 mL/min: 2 mg/dia. ClCr 15–30 mL/min: 1 mg/dia. ClCr <15: contraindicado.',
      'es': 'ClCr 30–60: 2 mg/día. ClCr 15–30: 1 mg/día. ClCr <15: contraindicado.',
    },
    elderlyAlert: {
      'pt': '>65 anos: maior risco de infecções, TEV e eventos cardiovasculares — usar apenas se não houver alternativa (alerta FDA/EMA).',
      'es': '>65 años: mayor riesgo infecciones, TEV y eventos CV — solo si no hay alternativa (alerta FDA/EMA).',
    },
    mechanism: {
      'pt': 'Inibe JAK1 e JAK2 → bloqueio de vias de sinalização de citocinas inflamatórias (IL-6, IL-12, IL-23, IFN-γ) via STAT → imunomodulação potente.',
      'es': 'Inhibe JAK1/JAK2 → bloquea señalización citocinas inflamatorias → inmunomodulación potente.',
    },
    warning: {
      'pt': 'Rastreio de TB, herpes zoster, hepatite B e C antes de iniciar. Não combinar com biológicos imunossupressores. Vacinação contra herpes zoster recomendada antes de iniciar. TEV documentado (monitorar D-dímero e sintomas).',
      'es': 'Cribado TB, VZV, hepatitis B/C antes. No combinar con biológicos. Vacunación VZV antes de iniciar. TEV documentado.',
    },
    adverse: {
      'pt': ['Infecções do trato respiratório superior', 'Herpes zoster', 'Tromboembolismo venoso', 'Elevação de CPK e transaminases', 'Dislipidemia', 'Neutropenia', 'Anemia'],
      'es': ['Infecciones respiratorias altas', 'Herpes zoster', 'Tromboembolismo venoso', 'Elevación CPK y transaminasas', 'Dislipidemia', 'Neutropenia', 'Anemia'],
    },
  ),

  DrugModel(
    id: 'belimumabe',
    group: 'Varios / Antídotos / Otros',
    name: 'Belimumabe (Benlysta)',
    className: {'pt': 'Anticorpo monoclonal anti-BLyS/BAFF (anti-linfócito B)', 'es': 'Anticuerpo monoclonal anti-BLyS/BAFF'},
    category: {'pt': 'Lúpus eritematoso sistêmico', 'es': 'Lupus eritematoso sistémico'},
    route: 'IV / SC',
    doseType: 'weight',
    mgKg: 10.0,
    fixedDose: {
      'pt': 'IV: 10 mg/kg nas semanas 0, 2 e 4; depois a cada 4 semanas. SC: 200 mg SC 1x/semana (autoadministração).',
      'es': 'IV: 10 mg/kg semanas 0, 2 y 4; luego cada 4 sem. SC: 200 mg SC 1v/sem.',
    },
    renalAlert: {
      'pt': 'Sem ajuste formal em DRC. Nefrite lúpica proliferativa grave ativa: eficácia limitada isolado — combinar com imunossupressor.',
      'es': 'Sin ajuste formal en ERC. Nefritis lúpica grave activa: eficacia limitada solo — combinar con inmunosupresor.',
    },
    elderlyAlert: {
      'pt': 'Dados limitados em >65 anos. Monitorar infecções.',
      'es': 'Datos limitados >65 años. Monitorizar infecciones.',
    },
    mechanism: {
      'pt': 'Liga-se ao BLyS (B-lymphocyte stimulator / BAFF) solúvel → bloqueia a sobrevivência e maturação de linfócitos B autorreativos → redução de autoanticorpos (anti-dsDNA, anti-Sm) e atividade do lúpus.',
      'es': 'Se une a BLyS soluble → bloquea supervivencia y maduración linfocitos B autorreactivos → reducción autoanticuerpos y actividad lúpica.',
    },
    warning: {
      'pt': 'Risco aumentado de depressão e ideação suicida (monitorar saúde mental). Infecções graves (pneumonia, celulite). Hipersensibilidade/reação de infusão. Não usar em infecção ativa grave ou HIV. Rastreio de TB antes de iniciar.',
      'es': 'Riesgo aumentado depresión e ideación suicida. Infecciones graves. Hipersensibilidad/reacción infusión. No usar con infección activa grave. Cribado TB.',
    },
    adverse: {
      'pt': ['Infecções do trato respiratório superior', 'Náuseas', 'Diarreia', 'Reação de infusão', 'Depressão/ansiedade', 'Insônia', 'Dor de membros', 'Leucopenia'],
      'es': ['Infecciones respiratorias altas', 'Náuseas', 'Diarrea', 'Reacción infusión', 'Depresión/ansiedad', 'Insomnio', 'Dolor extremidades', 'Leucopenia'],
    },
  ),

  // ── LOTE 3 — 50 fármacos adicionais ─────────────────────────────────────

  DrugModel(
    id: 'sinvastatina',
    group: 'Cardiovascular y HTA',
    name: 'Sinvastatina',
    className: {'pt': 'Inibidor da HMG-CoA redutase (Estatina)', 'es': 'Inhibidor de la HMG-CoA reductasa (Estatina)'},
    category: {'pt': 'Hipolipemiantes', 'es': 'Hipolipemiantes'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': '10–40 mg VO à noite. Máx. 40 mg/dia (dose de 80 mg restrita pelo FDA devido a miopatia).',
      'es': '10–40 mg VO por la noche. Máx. 40 mg/día.',
    },
    renalAlert: {
      'pt': 'ClCr < 30 mL/min: iniciar com 5 mg/dia.',
      'es': 'ClCr < 30: iniciar con 5 mg/día.',
    },
    elderlyAlert: {
      'pt': 'Monitorar mialgia. Interação com múltiplos fármacos aumenta risco de rabdomiólise.',
      'es': 'Monitorear mialgia. Riesgo de rabdomiólisis elevado.',
    },
    mechanism: {
      'pt': 'Inibe a HMG-CoA redutase; reduz síntese de colesterol e aumenta receptores de LDL no fígado.',
      'es': 'Inhibe la HMG-CoA reductasa; reduce el colesterol.',
    },
    warning: {
      'pt': 'Contraindicado com inibidores potentes do CYP3A4 (Claritromicina, Itraconazol).',
      'es': 'Contraindicado con inhibidores potentes de CYP3A4.',
    },
    adverse: {
      'pt': ['Mialgia', 'Cefaleia', 'Aumento de transaminases', 'Rabdomiólise (raro)'],
      'es': ['Mialgia', 'Cefalea', 'Aumento de transaminasas'],
    },
  ),

  DrugModel(
    id: 'gabapentina',
    group: 'Neurología y Psiquiatría',
    name: 'Gabapentina',
    className: {'pt': 'Anticonvulsivante / Gabapentinoide', 'es': 'Anticonvulsivante / Gabapentinoide'},
    category: {'pt': 'Analgésicos Adjuvantes', 'es': 'Analgésicos Adyuvantes'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Dor neuropática: Início 300 mg 1x/dia, titular até 900–3600 mg/dia (3x/dia).',
      'es': 'Dolor neuropático: Inicio 300 mg/día, hasta 3600 mg/día.',
    },
    renalAlert: {
      'pt': 'Ajuste obrigatório pelo ClCr. Excreção exclusivamente renal.',
      'es': 'Ajuste obligatorio según función renal.',
    },
    elderlyAlert: {
      'pt': 'Risco de sonolência, edema periférico e quedas. Iniciar com doses baixas.',
      'es': 'Riesgo de caídas, sedación y edema.',
    },
    mechanism: {
      'pt': 'Liga-se à subunidade alfa-2-delta de canais de Cálcio voltagem-dependentes, reduzindo neurotransmissores excitatórios.',
      'es': 'Bloquea canales de calcio presinápticos.',
    },
    warning: {
      'pt': 'Não interromper abruptamente. Risco de ideação suicida.',
      'es': 'No suspender bruscamente.',
    },
    adverse: {
      'pt': ['Tontura', 'Sonolência', 'Edema periférico', 'Fadiga', 'Ataxia'],
      'es': ['Mareo', 'Somnolencia', 'Edema periférico'],
    },
  ),

  DrugModel(
    id: 'clortalidona',
    group: 'Cardiovascular y HTA',
    name: 'Clortalidona',
    className: {'pt': 'Diurético Tiazídico-símile', 'es': 'Diurético Tiazida-like'},
    category: {'pt': 'Anti-hipertensivos', 'es': 'Antihipertensivos'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': '12.5–25 mg 1x/dia (máx 50 mg). Longa duração (>48h).',
      'es': '12.5–25 mg 1x/día (máx 50 mg).',
    },
    renalAlert: {
      'pt': 'Ineficaz se ClCr < 30 mL/min.',
      'es': 'Ineficaz si ClCr < 30.',
    },
    elderlyAlert: {
      'pt': 'Alto risco de hiponatremia, hipopotassemia e quedas.',
      'es': 'Riesgo de hiponatremia y caídas.',
    },
    mechanism: {
      'pt': 'Inibe o cotransporte de Na-Cl no túbulo contorcido distal.',
      'es': 'Inhibe el cotransportador Na-Cl en el túbulo distal.',
    },
    warning: {
      'pt': 'Pode causar hiperuricemia (precipitar gota) e intolerância à glicose.',
      'es': 'Riesgo de gota y aumento de glucemia.',
    },
    adverse: {
      'pt': ['Hipocalemia', 'Hiponatremia', 'Hiperuricemia', 'Câimbras'],
      'es': ['Hipopotasemia', 'Hiponatremia', 'Hiperuricemia'],
    },
  ),

  DrugModel(
    id: 'clonidina',
    group: 'Cardiovascular y HTA',
    name: 'Clonidina',
    className: {'pt': 'Agonista Alfa-2 adrenérgico central', 'es': 'Agonista Alfa-2 adrenérgico central'},
    category: {'pt': 'Anti-hipertensivos / Emergência', 'es': 'Antihipertensivos / Emergencia'},
    route: 'VO / IV / Transdérmico',
    doseType: 'fixed',
    fixedDose: {
      'pt': '0.100–0.200 mg 2-3x/dia. Urgência hipertensiva: 0.1–0.2 mg VO.',
      'es': '0.100–0.200 mg 2-3x/día.',
    },
    renalAlert: {
      'pt': 'Reduzir dose em insuficiência renal grave.',
      'es': 'Reducir dosis en falla renal.',
    },
    elderlyAlert: {
      'pt': 'Evitar (Beers criteria): causa bradicardia, sedação intensa e hipotensão ortostática.',
      'es': 'Evitar en ancianos por sedación y bradicardia.',
    },
    mechanism: {
      'pt': 'Estimula receptores alfa-2 centrais, diminuindo o efluxo simpático do SNC.',
      'es': 'Disminuye el flujo simpático central.',
    },
    warning: {
      'pt': 'NUNCA suspender abruptamente (risco de hipertensão de rebote severa).',
      'es': 'Riesgo de hipertensión de rebote al suspender.',
    },
    adverse: {
      'pt': ['Boca seca', 'Sedação', 'Hipotensão postural', 'Constipação', 'Bradicardia'],
      'es': ['Boca seca', 'Sedación', 'Hipotensión'],
    },
  ),

  DrugModel(
    id: 'fluconazol',
    group: 'Infectología (Antifúngicos / Antivirales / TBC)',
    name: 'Fluconazol',
    className: {'pt': 'Antifúngico Triazólico', 'es': 'Antifúngico Triazol'},
    category: {'pt': 'Antifúngicos', 'es': 'Antifúngicos'},
    route: 'VO / IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': '150–400 mg/dia. Candidíase vaginal: 150 mg dose única.',
      'es': '150–400 mg/día.',
    },
    renalAlert: {
      'pt': 'ClCr < 50 mL/min: reduzir dose em 50%.',
      'es': 'Reducir dosis 50% si ClCr < 50.',
    },
    elderlyAlert: {
      'pt': 'Monitorar função renal e intervalo QT.',
      'es': 'Monitorear función renal y QT.',
    },
    mechanism: {
      'pt': 'Inibe a síntese de ergosterol na membrana fúngica via inibição do CYP450 fúngico.',
      'es': 'Inhibe la síntesis de ergosterol.',
    },
    warning: {
      'pt': 'Inibidor do CYP2C9 e CYP3A4. Interage com Varfarina e Fenitoína.',
      'es': 'Múltiples interacciones citocromales.',
    },
    adverse: {
      'pt': ['Náuseas', 'Elevação de transaminases', 'Cefaleia', 'Prolongamento QT'],
      'es': ['Náuseas', 'Elevación de transaminasas'],
    },
  ),

  DrugModel(
    id: 'lidocaina',
    group: 'UCI – Críticos y Sedoanalgesia',
    name: 'Lidocaína',
    className: {'pt': 'Anestésico Local / Antiarrítmico Classe IB', 'es': 'Anestésico Local / Antiarrítmico Clase IB'},
    category: {'pt': 'Emergência / Anestesia', 'es': 'Emergencia / Anestesia'},
    route: 'IV / Tópica / SC',
    doseType: 'weight',
    mgKg: 1.0,
    fixedDose: {
      'pt': 'Antiarrítmico: 1–1.5 mg/kg bolus IV. Manutenção: 1–4 mg/min.',
      'es': 'Antiarrítmico: 1–1.5 mg/kg bolo IV.',
    },
    renalAlert: {
      'pt': 'Acúmulo de metabólitos ativos em IRC prolongada.',
      'es': 'Precaución en falla renal prolongada.',
    },
    elderlyAlert: {
      'pt': 'Reduzir dose de manutenção em 50%. Risco de toxicidade no SNC (convulsões).',
      'es': 'Reducir dosis; riesgo de toxicidad SNC.',
    },
    mechanism: {
      'pt': 'Bloqueia canais de sódio rápidos, inibindo a despolarização.',
      'es': 'Bloqueo de canales de sodio.',
    },
    warning: {
      'pt': 'Toxicidade: tinido, gosto metálico, parestesia perioral e convulsões.',
      'es': 'Signos de toxicidad sistémica.',
    },
    adverse: {
      'pt': ['Hipotensão', 'Bradicardia', 'Convulsão', 'Gosto metálico', 'Confusão'],
      'es': ['Hipotensión', 'Bradicardia', 'Convulsiones'],
    },
  ),

  DrugModel(
    id: 'nitroprussiato',
    group: 'UCI – Críticos y Sedoanalgesia',
    name: 'Nitroprussiato de Sódio',
    className: {'pt': 'Vasodilatador potente (Doador de NO)', 'es': 'Vasodilatador potente (Donador de NO)'},
    category: {'pt': 'Emergência / Cardiovascular', 'es': 'Emergencia / Cardiovascular'},
    route: 'IV (Infusão)',
    doseType: 'mcg_kg_min',
    mcgKgMinStart: 0.3,
    mcgKgMinMax: 10.0,
    fixedDose: {
      'pt': 'Iniciar 0.3 mcg/kg/min. Manter PAM alvo. Fotossensível.',
      'es': 'Inicio 0.3 mcg/kg/min. Fotosensible.',
    },
    renalAlert: {
      'pt': 'Risco de toxicidade por Tiocianato em IRC.',
      'es': 'Riesgo de toxicidad por tiocianato.',
    },
    elderlyAlert: {
      'pt': 'Monitorar queda brusca de pressão arterial e perfusão cerebral.',
      'es': 'Monitorear presión arterial estrechamente.',
    },
    mechanism: {
      'pt': 'Vasodilatação arterial e venosa direta via liberação de óxido nítrico.',
      'es': 'Vasodilatador mixto (arterial y venoso).',
    },
    warning: {
      'pt': 'Uso > 48h aumenta risco de intoxicação por cianeto. Proteger da luz.',
      'es': 'Riesgo de intoxicación por cianuro.',
    },
    adverse: {
      'pt': ['Hipotensão severa', 'Acidose metabólica (cianeto)', 'Cefaleia', 'Náuseas'],
      'es': ['Hipotensión', 'Acidosis metabólica', 'Cefalea'],
    },
  ),

  DrugModel(
    id: 'levosulpirida',
    group: 'Gastroenterología',
    name: 'Levosulpirida',
    className: {'pt': 'Procinético / Neuroléptico funcional', 'es': 'Procinético / Neuroléptico funcional'},
    category: {'pt': 'Gastrointestinais', 'es': 'Gastrointestinales'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': '25 mg 3x/dia, antes das refeições.',
      'es': '25 mg 3x/día antes de comidas.',
    },
    renalAlert: {
      'pt': 'Reduzir dose se ClCr < 30 mL/min.',
      'es': 'Reducir dosis en falla renal.',
    },
    elderlyAlert: {
      'pt': 'Risco de tremor e sintomas extrapiramidais. Monitorar mamas.',
      'es': 'Riesgo de parkinsonismo y galactorrea.',
    },
    mechanism: {
      'pt': 'Antagonista seletivo do receptor D2 central e periférico.',
      'es': 'Antagonista D2 selectivo.',
    },
    warning: {
      'pt': 'Pode causar hiperprolactinemia. Evitar em pacientes com histórico de convulsão.',
      'es': 'Riesgo de hiperprolactinemia.',
    },
    adverse: {
      'pt': ['Galactorreia', 'Amenorreia', 'Sonolência', 'Tensionamento mamário'],
      'es': ['Galactorrea', 'Ginecomastia', 'Somnolencia'],
    },
  ),

  DrugModel(
    id: 'clonazepam',
    group: 'Neurología y Psiquiatría',
    name: 'Clonazepam',
    className: {'pt': 'Benzodiazepínico de longa ação', 'es': 'Benzodiazepina de larga acción'},
    category: {'pt': 'Ansiolíticos / Anticonvulsivantes', 'es': 'Ansiolíticos / Anticonvulsivantes'},
    route: 'VO / SL',
    doseType: 'fixed',
    fixedDose: {
      'pt': '0.5–6 mg/dia. Iniciar com 0.25–0.5 mg.',
      'es': '0.5–6 mg/día.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário; metabólitos inativos.',
      'es': 'Sin ajuste habitual.',
    },
    elderlyAlert: {
      'pt': 'EVITAR (Beers). Meia-vida muito longa aumenta risco de quedas, fraturas e demência.',
      'es': 'Riesgo extremo de caídas y confusión.',
    },
    mechanism: {
      'pt': 'Potencializa a inibição GABAérgica mediada pelo receptor GABA-A.',
      'es': 'Agonista alostérico GABA-A.',
    },
    warning: {
      'pt': 'Pode causar depressão respiratória. Tolerância e dependência física.',
      'es': 'Alto potencial de dependencia.',
    },
    adverse: {
      'pt': ['Sedação', 'Ataxia', 'Amnésia anterógrada', 'Irritabilidade', 'Depressão'],
      'es': ['Sedación', 'Ataxia', 'Amnesia'],
    },
  ),

  DrugModel(
    id: 'atorvastatina',
    group: 'Cardiovascular y HTA',
    name: 'Atorvastatina',
    className: {'pt': 'Inibidor da HMG-CoA redutase', 'es': 'Inhibidor de la HMG-CoA reductasa'},
    category: {'pt': 'Hipolipemiantes', 'es': 'Hipolipemiantes'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': '10–80 mg/dia. Alta potência.',
      'es': '10–80 mg/día.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário.',
      'es': 'Sin ajuste.',
    },
    elderlyAlert: {
      'pt': 'Monitorar mialgia. Interage com Claritromicina (↑ risco miopatia).',
      'es': 'Monitorear mialgia.',
    },
    mechanism: {
      'pt': 'Inibe a produção hepática de colesterol.',
      'es': 'Inhibe la HMG-CoA reductasa.',
    },
    warning: {
      'pt': 'Risco de hepatotoxicidade e miopatia dose-dependente.',
      'es': 'Riesgo de hepatotoxicidad.',
    },
    adverse: {
      'pt': ['Mialgia', 'Nasofaringite', 'Elevação de TGP/TGO', 'Artralgia'],
      'es': ['Mialgia', 'Elevación de transaminasas'],
    },
  ),

  DrugModel(
    id: 'sertralina',
    group: 'Neurología y Psiquiatría',
    name: 'Sertralina',
    className: {'pt': 'ISRS', 'es': 'ISRS'},
    category: {'pt': 'Antidepressivos', 'es': 'Antidepresivos'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': '50–200 mg/dia. Dose inicial habitual: 50 mg.',
      'es': '50–200 mg/día.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário.',
      'es': 'Sin ajuste.',
    },
    elderlyAlert: {
      'pt': 'ISRS de escolha em idosos. Risco de SIADH/hiponatremia.',
      'es': 'Seguro; riesgo de hiponatremia.',
    },
    mechanism: {
      'pt': 'Inibição potente da recaptação de serotonina.',
      'es': 'Inhibe recaptación de serotonina.',
    },
    warning: {
      'pt': 'Monitorar sódio sérico. Risco de sangramento GI aumentado.',
      'es': 'Riesgo de hiponatremia.',
    },
    adverse: {
      'pt': ['Náuseas', 'Diarreia', 'Disfunção sexual', 'Insônia', 'Tremor'],
      'es': ['Diarrea', 'Náuseas', 'Disfunción sexual'],
    },
  ),

  DrugModel(
    id: 'fenobarbital',
    group: 'Neurología y Psiquiatría',
    name: 'Fenobarbital',
    className: {'pt': 'Barbitúrico', 'es': 'Barbitúrico'},
    category: {'pt': 'Anticonvulsivantes / Sedativos', 'es': 'Anticonvulsivantes / Sedantes'},
    route: 'VO / IV / IM',
    doseType: 'weight',
    mgKg: 15.0,
    fixedDose: {
      'pt': 'Adulto: 100–300 mg/dia. Status epilepticus: 15–20 mg/kg IV.',
      'es': 'Adulto: 100–300 mg/día.',
    },
    renalAlert: {
      'pt': 'TFG < 10 mL/min: dose a cada 12-16h.',
      'es': 'Ajustar en falla renal severa.',
    },
    elderlyAlert: {
      'pt': 'EVITAR (Beers). Causa depressão cognitiva, quedas e osteomalácia.',
      'es': 'Riesgo de deterioro cognitivo y caídas.',
    },
    mechanism: {
      'pt': 'Aumenta o tempo de abertura dos canais de Cloro mediado pelo GABA.',
      'es': 'Modulador del receptor GABA-A.',
    },
    warning: {
      'pt': 'Potente INDUTOR enzimático. Reduz efeito de Varfarina, DOACs e Contraceptivos.',
      'es': 'Inductor enzimático potente.',
    },
    adverse: {
      'pt': ['Sedação', 'Nistagmo', 'Ataxia', 'Rash cutâneo', 'Osteoporose'],
      'es': ['Sedación', 'Ataxia', 'Rash'],
    },
  ),

  DrugModel(
    id: 'hidroclorotiazida',
    group: 'Cardiovascular y HTA',
    name: 'Hidroclorotiazida',
    className: {'pt': 'Diurético Tiazídico', 'es': 'Diurético Tiazida'},
    category: {'pt': 'Anti-hipertensivos', 'es': 'Antihipertensivos'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': '12.5–50 mg 1x/dia.',
      'es': '12.5–50 mg 1x/día.',
    },
    renalAlert: {
      'pt': 'Ineficaz se ClCr < 30 mL/min.',
      'es': 'Ineficaz si ClCr < 30.',
    },
    elderlyAlert: {
      'pt': 'Risco de hiponatremia grave, tontura e fotossensibilidade.',
      'es': 'Riesgo de hiponatremia.',
    },
    mechanism: {
      'pt': 'Inibe reabsorção de Na+ no túbulo distal.',
      'es': 'Inhibe el cotransportador Na-Cl.',
    },
    warning: {
      'pt': 'Aumenta níveis de Lítio. Pode elevar o Ácido Úrico.',
      'es': 'Interacción con Lítio.',
    },
    adverse: {
      'pt': ['Hipocalemia', 'Hiponatremia', 'Hiperuricemia', 'Hiperglicemia'],
      'es': ['Hipopotasemia', 'Hiponatremia'],
    },
  ),

  DrugModel(
    id: 'naloxona',
    group: 'UCI – Críticos y Sedoanalgesia',
    name: 'Naloxona',
    className: {'pt': 'Antagonista Opioide', 'es': 'Antagonista Opioide'},
    category: {'pt': 'Antídotos / Emergência', 'es': 'Antídotos / Emergencia'},
    route: 'IV / IM / SC / Intranasal',
    doseType: 'fixed',
    fixedDose: {
      'pt': '0.4–2 mg IV cada 2-3 min até resposta. Máx 10 mg.',
      'es': '0.4–2 mg IV cada 2-3 min.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário.',
      'es': 'Sin ajuste.',
    },
    elderlyAlert: {
      'pt': 'Cuidado com abstinência aguda; pode causar edema agudo de pulmão.',
      'es': 'Riesgo de síndrome de abstinencia súbito.',
    },
    mechanism: {
      'pt': 'Antagonista competitivo puro dos receptores opioides mu, kappa e delta.',
      'es': 'Antagonista competitivo de receptores opioides.',
    },
    warning: {
      'pt': 'Duração curta (30-60 min). Risco de renarcotização se o opioide for de longa ação.',
      'es': 'Vida media corta; vigilar renarcotización.',
    },
    adverse: {
      'pt': ['Abstinência súbita', 'Taquicardia', 'Hipertensão', 'Edema pulmonar (raro)'],
      'es': ['Síndrome de abstinencia', 'Taquicardia'],
    },
  ),

  DrugModel(
    id: 'glibenclamida',
    group: 'Endocrinología y Metabolismo',
    name: 'Glibenclamida',
    className: {'pt': 'Sulfonilureia de 2ª geração', 'es': 'Sulfonilurea de 2ª generación'},
    category: {'pt': 'Antidiabéticos Orais', 'es': 'Antidiabéticos Orales'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': '2.5–20 mg/dia. Administrar 30 min antes da refeição.',
      'es': '2.5–20 mg/día.',
    },
    renalAlert: {
      'pt': 'Evitar se ClCr < 30 mL/min (acúmulo de metabólitos → hipoglicemia).',
      'es': 'Evitar en insuficiencia renal severa.',
    },
    elderlyAlert: {
      'pt': 'ALTO RISCO (Beers). Risco severo de hipoglicemia prolongada e quedas.',
      'es': 'Evitar en ancianos por hipoglucemia prolongada.',
    },
    mechanism: {
      'pt': 'Estimula a secreção de insulina pelas células beta (secretagogo).',
      'es': 'Estimula la secreción de insulina.',
    },
    warning: {
      'pt': 'Hipoglicemia pode durar dias devido à longa meia-vida dos metabólitos.',
      'es': 'Riesgo de hipoglucemia severa.',
    },
    adverse: {
      'pt': ['Hipoglicemia', 'Ganho de peso', 'Icterícia colestática', 'Náuseas'],
      'es': ['Hipoglucemia', 'Aumento de peso'],
    },
  ),

  DrugModel(
    id: 'propofol',
    group: 'UCI – Críticos y Sedoanalgesia',
    name: 'Propofol',
    className: {'pt': 'Anestésico Geral Intravenoso', 'es': 'Anestésico General Intravenoso'},
    category: {'pt': 'Sedação / Anestesia', 'es': 'Sedación / Anestesia'},
    route: 'IV',
    doseType: 'mcg_kg_min',
    mcgKgMinStart: 5.0,
    mcgKgMinMax: 50.0,
    fixedDose: {
      'pt': 'Indução: 1.5–2.5 mg/kg. Manutenção Sedação: 5–50 mcg/kg/min.',
      'es': 'Inducción: 1.5–2.5 mg/kg.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário.',
      'es': 'Sin ajuste.',
    },
    elderlyAlert: {
      'pt': 'Risco de hipotensão severa e apneia. Reduzir dose em idosos.',
      'es': 'Reducir dosis; riesgo de hipotensión.',
    },
    mechanism: {
      'pt': 'Agonista dos receptores GABA-A; hipnótico de início rápido e curta duração.',
      'es': 'Modulador del receptor GABA-A.',
    },
    warning: {
      'pt': 'Risco de PRIS (Síndrome da Infusão de Propofol) em altas doses por tempo prolongado.',
      'es': 'Riesgo de síndrome de infusión de propofol.',
    },
    adverse: {
      'pt': ['Hipotensão', 'Apneia', 'Bradicardia', 'Dor à injeção', 'Hipertrigliceridemia'],
      'es': ['Hipotensión', 'Apnea', 'Hipertrigliceridemia'],
    },
  ),

  DrugModel(
    id: 'fentanil',
    group: 'UCI – Críticos y Sedoanalgesia',
    name: 'Fentanil',
    className: {'pt': 'Analgésico Opioide Sintético', 'es': 'Analgésico Opioide Sintético'},
    category: {'pt': 'Anestesiologia / Emergência', 'es': 'Anestesiología / Emergencia'},
    route: 'IV / IM / Transdérmico',
    doseType: 'mcg_kg',
    fixedDose: {
      'pt': 'Analgesia aguda: 1–2 mcg/kg IV. Infusão: 0.5–3 mcg/kg/h.',
      'es': 'Analgesia aguda: 1–2 mcg/kg IV.',
    },
    renalAlert: {
      'pt': 'Mais seguro que morfina em IRC; não possui metabólitos ativos.',
      'es': 'Seguro en falla renal.',
    },
    elderlyAlert: {
      'pt': 'Risco de rigidez torácica em bolus rápido e depressão respiratória.',
      'es': 'Riesgo de depresión respiratoria.',
    },
    mechanism: {
      'pt': 'Agonista seletivo de receptores opioides mu; 100x mais potente que morfina.',
      'es': 'Agonista de receptores mu.',
    },
    warning: {
      'pt': 'Antídoto: Naloxona. Monitorar SpO2 e capnografia.',
      'es': 'Riesgo de tórax en tabla (rigidez).',
    },
    adverse: {
      'pt': ['Depressão respiratória', 'Rigidez torácica', 'Náuseas', 'Bradicardia', 'Prurido'],
      'es': ['Depresión respiratoria', 'Rigidez torácica'],
    },
  ),

  DrugModel(
    id: 'isossorbida',
    group: 'Cardiovascular y HTA',
    name: 'Isossorbida (Mononitrato)',
    className: {'pt': 'Nitrato de ação prolongada', 'es': 'Nitrato de acción prolongada'},
    category: {'pt': 'Cardiovascular / Antianginosos', 'es': 'Cardiovascular / Antianginosos'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': '20–40 mg 2x/dia (dar com intervalo de 7-8h para evitar tolerância).',
      'es': '20–40 mg 2x/día.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário.',
      'es': 'Sin ajuste.',
    },
    elderlyAlert: {
      'pt': 'Alto risco de síncope e hipotensão postural.',
      'es': 'Riesgo de hipotensión postural.',
    },
    mechanism: {
      'pt': 'Vasodilatador venoso e arterial via óxido nítrico; reduz pré-carga.',
      'es': 'Vasodilatador por liberación de NO.',
    },
    warning: {
      'pt': 'CONTRAINDICADO com Inibidores da PDE5 (Sildenafil). Requer período livre de nitrato.',
      'es': '¡PROHIBIDO con Sildenafilo!',
    },
    adverse: {
      'pt': ['Cefaleia (muito comum)', 'Tontura', 'Hipotensão', 'Rubor facial'],
      'es': ['Cefalea intensa', 'Hipotensión'],
    },
  ),

  DrugModel(
    id: 'verapamil',
    group: 'Cardiovascular y HTA',
    name: 'Verapamil',
    className: {'pt': 'Bloqueador de Canal de Cálcio Não-Di-hidropiridina', 'es': 'Bloqueador de Canal de Calcio No-Dihidropiridina'},
    category: {'pt': 'Anti-hipertensivos / Antiarrítmicos', 'es': 'Antihipertensivos / Antiarrítmicos'},
    route: 'VO / IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': '80–120 mg 3x/dia. Taquiarritmia aguda: 5–10 mg IV lento.',
      'es': '80–120 mg 3x/día.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário.',
      'es': 'Sin ajuste.',
    },
    elderlyAlert: {
      'pt': 'Pode causar constipação severa e bradicardia em idosos.',
      'es': 'Riesgo de estreñimiento y bradicardia.',
    },
    mechanism: {
      'pt': 'Inibe canais de cálcio no coração; cronotrópico e inotrópico negativo.',
      'es': 'Bloquea canales de calcio en corazón y vasos.',
    },
    warning: {
      'pt': 'Não usar em Insuficiência Cardíaca com Fração de Ejeção Reduzida.',
      'es': 'Contraindicado en IC con FE reducida.',
    },
    adverse: {
      'pt': ['Constipação', 'Bradicardia', 'Bloqueio AV', 'Edema periférico'],
      'es': ['Estreñimiento', 'Bradicardia'],
    },
  ),

  DrugModel(
    id: 'diltiazem',
    group: 'Cardiovascular y HTA',
    name: 'Diltiazem',
    className: {'pt': 'Bloqueador de Canal de Cálcio Não-Di-hidropiridina', 'es': 'Bloqueador de Canal de Calcio No-Dihidropiridina'},
    category: {'pt': 'Cardiovascular', 'es': 'Cardiovascular'},
    route: 'VO / IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': '30–90 mg 3-4x/dia (ou retard 120–240 mg/dia).',
      'es': '30–90 mg 3-4x/día.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário.',
      'es': 'Sin ajuste.',
    },
    elderlyAlert: {
      'pt': 'Monitorar FC. Risco de bradiarritmias aumentado.',
      'es': 'Vigilar frecuencia cardíaca.',
    },
    mechanism: {
      'pt': 'Bloqueia canais de cálcio cardíacos e vasculares; menos constipante que verapamil.',
      'es': 'Bloqueo de canales de calcio.',
    },
    warning: {
      'pt': 'Cuidado com associação com Betabloqueadores (risco de bloqueio cardíaco).',
      'es': 'Cautela con betabloqueantes.',
    },
    adverse: {
      'pt': ['Bradicardia', 'Edema maleolar', 'Cefaleia', 'Bloqueio AV'],
      'es': ['Bradicardia', 'Edema'],
    },
  ),

  DrugModel(
    id: 'fenitoina',
    group: 'Neurología y Psiquiatría',
    name: 'Fenitoína',
    className: {'pt': 'Anticonvulsivante / Hidantoína', 'es': 'Anticonvulsivante / Hidantoína'},
    category: {'pt': 'Antiepilépticos', 'es': 'Antiepilépticos'},
    route: 'VO / IV',
    doseType: 'weight',
    mgKg: 15.0,
    fixedDose: {
      'pt': 'Ataque: 15–20 mg/kg IV (máx 50 mg/min). Manutenção: 300 mg/dia.',
      'es': 'Carga: 15–20 mg/kg IV.',
    },
    renalAlert: {
      'pt': 'Monitorar fração livre de fenitoína em uremia.',
      'es': 'Vigilar niveles en falla renal.',
    },
    elderlyAlert: {
      'pt': 'Risco de ataxia, nistagmo e osteopenia. Muitas interações.',
      'es': 'Riesgo de caídas y ataxia.',
    },
    mechanism: {
      'pt': 'Bloqueia canais de sódio voltagem-dependentes, inibindo disparos de alta frequência.',
      'es': 'Bloqueo de canales de sodio.',
    },
    warning: {
      'pt': 'Cinética de eliminação não-linear (pequenos aumentos de dose podem causar toxicidade grave).',
      'es': 'Cinética saturable; riesgo de toxicidad.',
    },
    adverse: {
      'pt': ['Hiperplasia gengival', 'Hirsutismo', 'Nistagmo', 'Síndrome da Luva Roxa (IV)', 'Ataxia'],
      'es': ['Hiperplasia gingival', 'Ataxia', 'Nistagmo'],
    },
  ),

  DrugModel(
    id: 'lamotrigina',
    group: 'Neurología y Psiquiatría',
    name: 'Lamotrigina',
    className: {'pt': 'Anticonvulsivante / Estabilizador de Humor', 'es': 'Anticonvulsivante / Estabilizador del ánimo'},
    category: {'pt': 'Antiepilépticos / Psiquiatria', 'es': 'Antiepilépticos / Psiquiatría'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': '25–400 mg/dia. TITULAÇÃO LENTA obrigatória (iniciar com 25 mg/dia).',
      'es': '25–400 mg/día. Escalar lentamente.',
    },
    renalAlert: {
      'pt': 'Reduzir dose em insuficiência renal grave.',
      'es': 'Reducir dosis en falla renal.',
    },
    elderlyAlert: {
      'pt': 'Melhor tolerada que carbamazepina; monitorar rash cutâneo.',
      'es': 'Vigilar aparición de rash.',
    },
    mechanism: {
      'pt': 'Bloqueia canais de sódio e inibe a liberação de glutamato.',
      'es': 'Bloqueo de canales de sodio y glutamato.',
    },
    warning: {
      'pt': 'Risco severo de Síndrome de Stevens-Johnson se a titulação for rápida.',
      'es': 'Riesgo de Stevens-Johnson.',
    },
    adverse: {
      'pt': ['Rash cutâneo (alerta crítico)', 'Cefaleia', 'Tontura', 'Insônia', 'Diplopia'],
      'es': ['Rash (riesgo de SJS)', 'Mareo', 'Diplopía'],
    },
  ),

  DrugModel(
    id: 'topiramato',
    group: 'Neurología y Psiquiatría',
    name: 'Topiramato',
    className: {'pt': 'Anticonvulsivante Multimodal', 'es': 'Anticonvulsivante Multimodal'},
    category: {'pt': 'Antiepilépticos / Profilaxia Enxaqueca', 'es': 'Antiepilépticos / Migraña'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Epilepsia: 200–400 mg/dia. Enxaqueca: 50–100 mg/dia.',
      'es': '25–400 mg/día.',
    },
    renalAlert: {
      'pt': 'Reduzir dose em 50% se ClCr < 70 mL/min.',
      'es': 'Ajustar en insuficiencia renal.',
    },
    elderlyAlert: {
      'pt': 'Risco de lentificação cognitiva, cálculos renais e perda de peso.',
      'es': 'Deterioro cognitivo y riesgo de litiasis.',
    },
    mechanism: {
      'pt': 'Bloqueia canais de Na+, potencializa GABA, antagoniza Glutamato e inibe anidrase carbônica.',
      'es': 'Mecanismo de acción múltiple.',
    },
    warning: {
      'pt': 'Pode causar Glaucoma Agudo de Ângulo Fechado e acidose metabólica.',
      'es': 'Riesgo de glaucoma agudo.',
    },
    adverse: {
      'pt': ['Parestesia', 'Perda de peso', 'Dificuldade de concentração', 'Nefrolitíase'],
      'es': ['Parestesias', 'Pérdida de peso', 'Déficit cognitivo'],
    },
  ),

  DrugModel(
    id: 'olanzapina',
    group: 'Neurología y Psiquiatría',
    name: 'Olanzapina',
    className: {'pt': 'Antipsicótico Atípico', 'es': 'Antipsicótico Atípico'},
    category: {'pt': 'Antipsicóticos / Emergência', 'es': 'Antipsicóticos / Emergencia'},
    route: 'VO / IM / SL',
    doseType: 'fixed',
    fixedDose: {
      'pt': '5–20 mg/dia. IM aguda: 10 mg.',
      'es': '5–20 mg/día.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário.',
      'es': 'Sin ajuste.',
    },
    elderlyAlert: {
      'pt': 'Black Box: mortalidade aumentada em demência. Alto risco de Síndrome Metabólica.',
      'es': 'Riesgo metabólico y de caídas.',
    },
    mechanism: {
      'pt': 'Antagonista 5-HT2A e D2 com alta afinidade por receptores H1 e muscarínicos.',
      'es': 'Antagonista multicentrico (D2, 5HT2A, H1).',
    },
    warning: {
      'pt': 'Monitorar peso, circunferência abdominal e glicemia mensalmente.',
      'es': 'Monitorear aumento de peso y glucosa.',
    },
    adverse: {
      'pt': ['Ganho de peso intenso', 'Sonolência', 'Hiperlipidemia', 'Boca seca'],
      'es': ['Aumento de peso', 'Somnolencia', 'Dislipidemia'],
    },
  ),

  DrugModel(
    id: 'mirtazapina',
    group: 'Neurología y Psiquiatría',
    name: 'Mirtazapina',
    className: {'pt': 'Antidepressivo NaSSA', 'es': 'Antidepresivo NaSSA'},
    category: {'pt': 'Antidepressivos', 'es': 'Antidepresivos'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': '15–45 mg/dia (noite). Paradoxalmente mais sedativa em 15 mg.',
      'es': '15–45 mg/día (noche).',
    },
    renalAlert: {
      'pt': 'Reduzir dose em insuficiência renal moderada/grave.',
      'es': 'Ajustar en falla renal.',
    },
    elderlyAlert: {
      'pt': 'Útil em idosos com insônia e perda de peso. Risco de edema.',
      'es': 'Útil en ancianos con insomnio y bajo peso.',
    },
    mechanism: {
      'pt': 'Antagonista alfa-2 pré-sináptico, aumentando noradrenalina e serotonina.',
      'es': 'Aumenta noradrenalina y serotonina.',
    },
    warning: {
      'pt': 'Aumenta significativamente o apetite e peso.',
      'es': 'Aumento de peso y apetito.',
    },
    adverse: {
      'pt': ['Ganho de peso', 'Sonolência', 'Aumento do colesterol', 'Xerostomia'],
      'es': ['Somnolencia', 'Aumento de peso'],
    },
  ),

  DrugModel(
    id: 'zolpidem',
    group: 'Neurología y Psiquiatría',
    name: 'Zolpidem',
    className: {'pt': 'Hipnótico Não-benzodiazepínico', 'es': 'Hipnótico No-benzodiazepina'},
    category: {'pt': 'Indutores de Sono', 'es': 'Inductores de Sueño'},
    route: 'VO / SL',
    doseType: 'fixed',
    fixedDose: {
      'pt': '5–10 mg ao deitar. Mulheres/Idosos: 5 mg.',
      'es': '5–10 mg al acostarse.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário.',
      'es': 'Sin ajuste.',
    },
    elderlyAlert: {
      'pt': 'EVITAR (Beers). Risco de sonambulismo, quedas e fraturas.',
      'es': 'Riesgo de conductas complejas del sueño.',
    },
    mechanism: {
      'pt': 'Agonista seletivo da subunidade alfa-1 do receptor GABA-A.',
      'es': 'Agonista selectivo GABA-A.',
    },
    warning: {
      'pt': 'Pode causar comportamentos complexos no sono (ex: dirigir dormindo).',
      'es': 'Conductas peligrosas durante el sueño.',
    },
    adverse: {
      'pt': ['Amnésia retrógrada', 'Alucinações', 'Tontura', 'Sonolência diurna'],
      'es': ['Alucinaciones', 'Sonambulismo', 'Mareo'],
    },
  ),

  DrugModel(
    id: 'etamsilato',
    group: 'Hematología y Vitaminas',
    name: 'Etamsilato',
    className: {'pt': 'Hemostático / Vasoprotetor', 'es': 'Hemostático / Vasoprotector'},
    category: {'pt': 'Hematologia', 'es': 'Hematología'},
    route: 'VO / IV / IM',
    doseType: 'fixed',
    fixedDose: {
      'pt': '500 mg cada 6-8h.',
      'es': '500 mg cada 6-8h.',
    },
    renalAlert: {
      'pt': 'Usar com cautela em insuficiência renal grave.',
      'es': 'Cautela en falla renal.',
    },
    elderlyAlert: {
      'pt': 'Geralmente seguro.',
      'es': 'Seguro.',
    },
    mechanism: {
      'pt': 'Aumenta a adesividade plaquetária e a resistência capilar; não altera fatores de coagulação.',
      'es': 'Mejora adhesividad plaquetaria.',
    },
    warning: {
      'pt': 'Não substitui fatores de coagulação em deficiências genéticas.',
      'es': 'No reemplaza factores de coagulación.',
    },
    adverse: {
      'pt': ['Náuseas', 'Cefaleia', 'Hipotensão (se IV rápido)', 'Rash'],
      'es': ['Cefalea', 'Náuseas'],
    },
  ),

  DrugModel(
    id: 'racecadotril',
    group: 'Gastroenterología',
    name: 'Racecadotril',
    className: {'pt': 'Inibidor da Encefalinase (Antidiarreico)', 'es': 'Inhibidor de la Encefalidasa (Antidiarreico)'},
    category: {'pt': 'Gastrointestinais', 'es': 'Gastrointestinales'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': '100 mg 3x/dia. Máx 7 dias.',
      'es': '100 mg 3x/día.',
    },
    renalAlert: {
      'pt': 'Usar com cautela por falta de dados.',
      'es': 'Usar con precaución.',
    },
    elderlyAlert: {
      'pt': 'Antidiarreico seguro, não causa íleo paralítico como a loperamida.',
      'es': 'Más seguro que loperamida en ancianos.',
    },
    mechanism: {
      'pt': 'Reduz a hipersecreção de água e eletrólitos no lúmen intestinal.',
      'es': 'Antisecretor intestinal puro.',
    },
    warning: {
      'pt': 'Não deve ser usado em diarreias infecciosas graves com sangue (disenteria).',
      'es': 'No usar en disentería.',
    },
    adverse: {
      'pt': ['Cefaleia', 'Vômitos', 'Prurido'],
      'es': ['Cefalea', 'Rash'],
    },
  ),

  DrugModel(
    id: 'fosfomicina',
    group: 'Infectología (Antifúngicos / Antivirales / TBC)',
    name: 'Fosfomicina Trometamol',
    className: {'pt': 'Antibiótico derivado do ácido fosfônico', 'es': 'Antibiótico derivado del ácido fosfónico'},
    category: {'pt': 'Antibióticos', 'es': 'Antibióticos'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': '3 g dose única (dissolver em água).',
      'es': '3 g dosis única.',
    },
    renalAlert: {
      'pt': 'ClCr < 10 mL/min: evitar.',
      'es': 'Evitar en falla renal severa.',
    },
    elderlyAlert: {
      'pt': 'Excelente opção para cistite simples em idosas por ser dose única.',
      'es': 'Útil por su dosificación única.',
    },
    mechanism: {
      'pt': 'Inibe a síntese da parede celular bacteriana bloqueando a enolpiruvil transferase.',
      'es': 'Inhibe la síntesis de pared bacteriana.',
    },
    warning: {
      'pt': 'Não usar em pielonefrite ou infecções sistêmicas.',
      'es': 'Solo para cistitis no complicada.',
    },
    adverse: {
      'pt': ['Diarreia', 'Náuseas', 'Vaginite', 'Cefaleia'],
      'es': ['Diarrea', 'Náuseas'],
    },
  ),

  DrugModel(
    id: 'acetazolamida',
    group: 'UCI – Críticos y Sedoanalgesia',
    name: 'Acetazolamida',
    className: {'pt': 'Inibidor da Anidrase Carbônica', 'es': 'Inhibidor de la Anidrasa Carbónica'},
    category: {'pt': 'Diuréticos / Neurológicos', 'es': 'Diuréticos / Neurológicos'},
    route: 'VO / IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': '250 mg 2-4x/dia.',
      'es': '250 mg 2-4x/día.',
    },
    renalAlert: {
      'pt': 'ClCr < 10 mL/min: evitar.',
      'es': 'Contraindicado en ClCr < 10.',
    },
    elderlyAlert: {
      'pt': 'Pode causar fadiga, confusão e acidose metabólica.',
      'es': 'Riesgo de acidosis y fatiga.',
    },
    mechanism: {
      'pt': 'Inibe a enzima anidrase carbônica, bloqueando a reabsorção de Bicarbonato.',
      'es': 'Inhibe la anhidrasa carbónica.',
    },
    warning: {
      'pt': 'Risco de hipocalemia severa. Contraindicado em alergia a sulfas.',
      'es': 'Alerta en alérgicos a sulfas.',
    },
    adverse: {
      'pt': ['Parestesia', 'Acidose metabólica', 'Hipocalemia', 'Poliúria'],
      'es': ['Parestesias', 'Acidosis'],
    },
  ),

  DrugModel(
    id: 'kayexalate',
    group: 'Endocrinología y Metabolismo',
    name: 'Poliestirenossulfonato de Cálcio / Sódio',
    className: {'pt': 'Resina de Troca Catiônica', 'es': 'Resina de Intercambio Catiónico'},
    category: {'pt': 'Eletrólitos / Emergência', 'es': 'Electrolitos / Emergencia'},
    route: 'VO / Retal',
    doseType: 'fixed',
    fixedDose: {
      'pt': '15–30 g cada 6-8h.',
      'es': '15–30 g cada 6-8h.',
    },
    renalAlert: {
      'pt': 'Fármaco chave no manejo da hipercalemia em IRC.',
      'es': 'Uso clave en hiperpotasemia renal.',
    },
    elderlyAlert: {
      'pt': 'Risco elevado de necrose intestinal e constipação grave. Monitorar ruídos hidroaéreos.',
      'es': 'Riesgo de necrosis colónica.',
    },
    mechanism: {
      'pt': 'Troca íons cálcio ou sódio por potássio no intestino grosso para excreção fecal.',
      'es': 'Intercambia Ca/Na por K en el colon.',
    },
    warning: {
      'pt': 'Ação lenta (2-12h). Não usar como única medida em hipercalemia grave.',
      'es': 'Inicio de acción lento.',
    },
    adverse: {
      'pt': ['Constipação', 'Náuseas', 'Hipocalemia excessiva', 'Necrose intestinal (raro)'],
      'es': ['Estreñimiento', 'Náuseas', 'Hipopotasemia'],
    },
  ),

  DrugModel(
    id: 'rocuronio',
    group: 'UCI – Críticos y Sedoanalgesia',
    name: 'Rocurônio',
    className: {'pt': 'Bloqueador Neuromuscular Não-despolarizante', 'es': 'Bloqueante Neuromuscular No-despolarizante'},
    category: {'pt': 'Emergência / Anestesia', 'es': 'Emergencia / Anestesia'},
    route: 'IV',
    doseType: 'weight',
    mgKg: 0.6,
    fixedDose: {
      'pt': 'Sequência Rápida: 0.6–1.2 mg/kg IV.',
      'es': 'Inducción (SRI): 0.6–1.2 mg/kg IV.',
    },
    renalAlert: {
      'pt': 'Duração do bloqueio pode ser prolongada em ClCr < 30 mL/min.',
      'es': 'Duración prolongada en falla renal.',
    },
    elderlyAlert: {
      'pt': 'Risco de bloqueio residual. Necessário monitoramento com TOF.',
      'es': 'Riesgo de parálisis residual.',
    },
    mechanism: {
      'pt': 'Antagonista competitivo da acetilcolina nos receptores nicotínicos da placa motora.',
      'es': 'Antagonista nicotínico competitivo.',
    },
    warning: {
      'pt': 'NÃO possui efeito sedativo ou analgésico. Antídoto: Sugamadex.',
      'es': '¡Sin efecto sedante! Antídoto: Sugamadex.',
    },
    adverse: {
      'pt': ['Hipotensão', 'Hipertensão transitória', 'Reação anafilática (raro)'],
      'es': ['Hipotensión', 'Anafilaxia'],
    },
  ),

  DrugModel(
    id: 'dexmedetomidina',
    group: 'UCI – Críticos y Sedoanalgesia',
    name: 'Dexmedetomidina',
    className: {'pt': 'Agonista Alfa-2 adrenérgico altamente seletivo', 'es': 'Agonista Alfa-2 adrenérgico selectivo'},
    category: {'pt': 'Sedação / UTI', 'es': 'Sedación / UCI'},
    route: 'IV (Infusão)',
    doseType: 'mcg_kg_h',
    mcgKgMinStart: 0.2,
    mcgKgMinMax: 1.5,
    fixedDose: {
      'pt': 'Manutenção: 0.2–0.7 mcg/kg/h. Sedação consciente.',
      'es': 'Mantenimiento: 0.2–0.7 mcg/kg/h.',
    },
    renalAlert: {
      'pt': 'Metabólitos podem se acumular em IRC grave.',
      'es': 'Sin ajuste habitual.',
    },
    elderlyAlert: {
      'pt': 'Alto risco de bradicardia e hipotensão. Titular cautelosamente.',
      'es': 'Riesgo elevado de bradicardia.',
    },
    mechanism: {
      'pt': 'Agonista alfa-2 no locus coeruleus; produz sedação "fisiológica" (desperta fácil).',
      'es': 'Sedación sin depresión respiratoria.',
    },
    warning: {
      'pt': 'Não causa depressão respiratória significativa.',
      'es': 'Seguro respiratoriamente.',
    },
    adverse: {
      'pt': ['Bradicardia', 'Hipotensão', 'Boca seca', 'Hipertensão paradoxal (bolus)'],
      'es': ['Bradicardia', 'Hipotensión'],
    },
  ),

  DrugModel(
    id: 'amikacina',
    group: 'Infectología (Antifúngicos / Antivirales / TBC)',
    name: 'Amicacina',
    className: {'pt': 'Aminoglicosídeo', 'es': 'Aminoglucósido'},
    category: {'pt': 'Antibióticos', 'es': 'Antibióticos'},
    route: 'IV / IM',
    doseType: 'weight',
    mgKg: 15.0,
    fixedDose: {
      'pt': '15–20 mg/kg 1x/dia.',
      'es': '15–20 mg/kg 1x/día.',
    },
    renalAlert: {
      'pt': 'Altamente NEFROTÓXICO. Ajuste obrigatório conforme ClCr.',
      'es': 'Ajuste obligatorio; nefrotóxico.',
    },
    elderlyAlert: {
      'pt': 'Risco de surdez irreversível (ototoxicidade) e insuficiência renal.',
      'es': 'Riesgo de ototoxicidad y falla renal.',
    },
    mechanism: {
      'pt': 'Inibe a síntese proteica bacteriana ligando-se à subunidade 30S do ribossomo.',
      'es': 'Inhibe síntesis proteica (30S).',
    },
    warning: {
      'pt': 'Monitorar níveis séricos e creatinina diariamente.',
      'es': 'Monitorear niveles séricos.',
    },
    adverse: {
      'pt': ['Nefrotoxicidade', 'Ototoxicidade (surdez)', 'Vertigem', 'Bloqueio neuromuscular'],
      'es': ['Nefrotoxicidad', 'Ototoxicidad'],
    },
  ),

  DrugModel(
    id: 'fexofenadina',
    group: 'Varios / Antídotos / Otros',
    name: 'Fexofenadina',
    className: {'pt': 'Anti-histamínico H1 de 2ª geração', 'es': 'Antihistamínico H1 de 2ª generación'},
    category: {'pt': 'Antialérgicos', 'es': 'Antialérgicos'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': '60 mg 2x/dia ou 120–180 mg 1x/dia.',
      'es': '120–180 mg 1x/día.',
    },
    renalAlert: {
      'pt': 'Reduzir dose em insuficiência renal moderada/grave.',
      'es': 'Ajustar en falla renal.',
    },
    elderlyAlert: {
      'pt': 'Opção segura em idosos; não causa sedação nem efeitos anticolinérgicos.',
      'es': 'Seguro en ancianos; no sedante.',
    },
    mechanism: {
      'pt': 'Antagonista seletivo do receptor H1 periférico; não atravessa a BHE.',
      'es': 'Antagonista H1 periférico.',
    },
    warning: {
      'pt': 'Não ingerir com sucos de frutas (reduz absorção em 40%).',
      'es': 'Evitar jugos de fruta.',
    },
    adverse: {
      'pt': ['Cefaleia', 'Sonolência (raro)', 'Náuseas', 'Tontura'],
      'es': ['Cefalea', 'Mareo'],
    },
  ),

  DrugModel(
    id: 'tigeciclina',
    group: 'Infectología (Antifúngicos / Antivirales / TBC)',
    name: 'Tigeciclina',
    className: {'pt': 'Glicilciclina', 'es': 'Glicilciclina'},
    category: {'pt': 'Antibióticos', 'es': 'Antibióticos'},
    route: 'IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Ataque: 100 mg. Manutenção: 50 mg cada 12h.',
      'es': 'Carga 100 mg → 50 mg cada 12h.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário.',
      'es': 'Sin ajuste.',
    },
    elderlyAlert: {
      'pt': 'Geralmente bem tolerada.',
      'es': 'Bien tolerado.',
    },
    mechanism: {
      'pt': 'Inibe a síntese proteica (30S). Amplo espectro contra bactérias resistentes (KPC, MRSA, VRE).',
      'es': 'Inhibe síntesis proteica.',
    },
    warning: {
      'pt': 'Aumenta mortalidade por todas as causas. Não usar em ITU ou sepse primária.',
      'es': 'Aumento de mortalidad; solo uso de reserva.',
    },
    adverse: {
      'pt': ['Náusea intensa', 'Vômitos', 'Diarreia', 'Pancreatite'],
      'es': ['Náuseas intensas', 'Vómitos'],
    },
  ),

  DrugModel(
    id: 'levosimendan',
    group: 'Cardiovascular y HTA',
    name: 'Levosimendan',
    className: {'pt': 'Sensibilizador de Cálcio (Inodilatador)', 'es': 'Sensibilizador de calcio (Inodilatador)'},
    category: {'pt': 'Vasoativos / IC', 'es': 'Vasoactivos / IC'},
    route: 'IV (Infusão)',
    doseType: 'mcg_kg_min',
    mcgKgMinStart: 0.1,
    mcgKgMinMax: 0.2,
    fixedDose: {
      'pt': '0.1–0.2 mcg/kg/min por 24h. Dose de ataque opcional.',
      'es': '0.1–0.2 mcg/kg/min por 24h.',
    },
    renalAlert: {
      'pt': 'Contraindicado em insuficiência renal grave (ClCr < 30).',
      'es': 'Contraindicado en ClCr < 30.',
    },
    elderlyAlert: {
      'pt': 'Risco de hipotensão severa e taquiarritmias. Monitorar eletrólitos.',
      'es': 'Riesgo de arritmias y hipotensión.',
    },
    mechanism: {
      'pt': 'Aumenta a força de contração sensibilizando a Troponina C ao cálcio; abre canais de K+ (vasodilatação).',
      'es': 'Inotrópico y vasodilatador.',
    },
    warning: {
      'pt': 'Efeito inotrópico dura até 7 dias após o término da infusão (metabólitos de meia-vida longa).',
      'es': 'Efecto prolongado (7 días).',
    },
    adverse: {
      'pt': ['Hipotensão', 'Cefaleia', 'Hipocalemia', 'Fibrilação atrial'],
      'es': ['Hipotensión', 'Hipopotasemia', 'Arritmias'],
    },
  ),

  DrugModel(
    id: 'valaciclovir',
    group: 'Infectología (Antifúngicos / Antivirales / TBC)',
    name: 'Valaciclovir',
    className: {'pt': 'Antiviral', 'es': 'Antiviral'},
    category: {'pt': 'Antivirais / Herpes', 'es': 'Antivirales / Herpes'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Herpes Zoster: 1 g 3x/dia por 7 dias. Herpes simples: 500 mg 2x/dia.',
      'es': '1 g 3x/día (Zóster).',
    },
    renalAlert: {
      'pt': 'Ajuste obrigatório se ClCr < 50 mL/min.',
      'es': 'Ajuste en falla renal.',
    },
    elderlyAlert: {
      'pt': 'Risco de neurotoxicidade (confusão, agitação) se função renal reduzida.',
      'es': 'Riesgo de neurotoxicidad.',
    },
    mechanism: {
      'pt': 'Pró-fármaco do aciclovir; inibe a DNA polimerase viral.',
      'es': 'Inhibidor de DNA polimerasa.',
    },
    warning: {
      'pt': 'Manter hidratação vigorosa para evitar cristalúria.',
      'es': 'Hidratación necesaria.',
    },
    adverse: {
      'pt': ['Cefaleia', 'Náuseas', 'Dor abdominal', 'Confusão mental'],
      'es': ['Cefalea', 'Náuseas'],
    },
  ),

  DrugModel(
    id: 'rifaximina',
    group: 'Gastroenterología',
    name: 'Rifaximina',
    className: {'pt': 'Antibiótico não absorvível', 'es': 'Antibiótico no absorbible'},
    category: {'pt': 'Gastrointestinais', 'es': 'Gastrointestinales'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Encefalopatia hepática: 550 mg 2x/dia. Diarreia do viajante: 200 mg 3x/dia.',
      'es': '550 mg 2x/día.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário (ação local).',
      'es': 'Sin ajuste.',
    },
    elderlyAlert: {
      'pt': 'Geralmente seguro devido à baixa absorção sistêmica.',
      'es': 'Bien tolerado.',
    },
    mechanism: {
      'pt': 'Inibe a síntese de RNA bacteriano ligando-se à RNA polimerase no lúmen intestinal.',
      'es': 'Acción local en el lúmen.',
    },
    warning: {
      'pt': 'Reduz a recorrência de episódios de encefalopatia hepática.',
      'es': 'Reduce riesgo de encefalopatía.',
    },
    adverse: {
      'pt': ['Flatulência', 'Náuseas', 'Urgência fecal', 'Cefaleia'],
      'es': ['Flatulencia', 'Náuseas'],
    },
  ),

  DrugModel(
    id: 'clonixinato_lisina',
    group: 'Analgésicos y Antipiréticos',
    name: 'Clonixinato de Lisina',
    className: {'pt': 'AINE potente', 'es': 'AINE potente'},
    category: {'pt': 'Analgésicos', 'es': 'Analgésicos'},
    route: 'VO / IV / IM',
    doseType: 'fixed',
    fixedDose: {
      'pt': '125–250 mg cada 6-8h.',
      'es': '125–250 mg cada 6-8h.',
    },
    renalAlert: {
      'pt': 'Contraindicado em insuficiência renal grave.',
      'es': 'Contraindicado en falla renal grave.',
    },
    elderlyAlert: {
      'pt': 'Risco elevado de sangramento gastrointestinal e nefrotoxicidade.',
      'es': 'Riesgo de sangrado GI.',
    },
    mechanism: {
      'pt': 'Inibe a síntese de prostaglandinas periféricas e centrais.',
      'es': 'Inhibidor de ciclooxigenasa.',
    },
    warning: {
      'pt': 'Fármaco extremamente comum em protocolos na Argentina (Dorixina).',
      'es': 'Muy común en Argentina.',
    },
    adverse: {
      'pt': ['Náuseas', 'Sonolência', 'Gastrite', 'Tontura'],
      'es': ['Náuseas', 'Gastritis'],
    },
  ),

  DrugModel(
    id: 'simeticona',
    group: 'Gastroenterología',
    name: 'Simeticona',
    className: {'pt': 'Antiflatulento', 'es': 'Antiflatulento'},
    category: {'pt': 'Gastrointestinais', 'es': 'Gastrointestinales'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': '40–125 mg cada 6h após as refeições.',
      'es': '40–125 mg cada 6h.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário.',
      'es': 'Sin ajuste.',
    },
    elderlyAlert: {
      'pt': 'Seguro.',
      'es': 'Seguro.',
    },
    mechanism: {
      'pt': 'Altera a tensão superficial das bolhas de gás, facilitando a eructação ou flatulência.',
      'es': 'Eliminación de gases.',
    },
    warning: {
      'pt': 'Não absorvido sistemicamente.',
      'es': 'No se absorbe.',
    },
    adverse: {
      'pt': ['Fezes amolecidas', 'Náuseas'],
      'es': ['Náuseas'],
    },
  ),

  DrugModel(
    id: 'tiamina',
    group: 'Hematología y Vitaminas',
    name: 'Tiamina (Vitamina B1)',
    className: {'pt': 'Vitamina', 'es': 'Vitamina'},
    category: {'pt': 'Vitaminas', 'es': 'Vitaminas'},
    route: 'VO / IV / IM',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Encefalopatia de Wernicke: 500 mg IV 3x/dia por 2-3 dias.',
      'es': 'Wernicke: 500 mg IV 3x/día.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário.',
      'es': 'Sin ajuste.',
    },
    elderlyAlert: {
      'pt': 'Crucial na profilaxia em idosos desnutridos ou etilistas.',
      'es': 'Vital en desnutrición.',
    },
    mechanism: {
      'pt': 'Cofator essencial no metabolismo dos carboidratos.',
      'es': 'Cofactor metabólico.',
    },
    warning: {
      'pt': 'Deve ser administrada ANTES da glicose IV em pacientes etilistas.',
      'es': 'Administrar ANTES que la glucosa.',
    },
    adverse: {
      'pt': ['Hipersensibilidade', 'Calor', 'Prurido'],
      'es': ['Rash'],
    },
  ),

  DrugModel(
    id: 'piridoxina',
    group: 'Hematología y Vitaminas',
    name: 'Piridoxina (Vitamina B6)',
    className: {'pt': 'Vitamina', 'es': 'Vitamina'},
    category: {'pt': 'Vitaminas', 'es': 'Vitaminas'},
    route: 'VO / IV / IM',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Suplementação: 25–50 mg/dia. Intoxicação INH: 1 g para cada g de isoniazida.',
      'es': '25–50 mg/día.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário.',
      'es': 'Sin ajuste.',
    },
    elderlyAlert: {
      'pt': 'Monitorar neuropatia sensorial com doses altas prolongadas.',
      'es': 'Vigilar neuropatía.',
    },
    mechanism: {
      'pt': 'Cofator para enzimas de metabolismo de aminoácidos e neurotransmissores.',
      'es': 'Cofactor enzimático.',
    },
    warning: {
      'pt': 'Doses > 200 mg/dia por longo prazo causam neuropatia periférica.',
      'es': 'Riesgo de neuropatía en altas dosis.',
    },
    adverse: {
      'pt': ['Neuropatia (doses altas)', 'Náuseas', 'Dor abdominal'],
      'es': ['Neuropatía'],
    },
  ),

  DrugModel(
    id: 'sulfadiazina_prata',
    group: 'Varios / Antídotos / Otros',
    name: 'Sulfadiazina de Prata',
    className: {'pt': 'Antibacteriano Tópico', 'es': 'Antibacteriano Tópico'},
    category: {'pt': 'Dermatologia', 'es': 'Dermatología'},
    route: 'Tópica',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Creme 1%. Aplicar 1-2x/dia na lesão limpa.',
      'es': 'Crema 1%.',
    },
    renalAlert: {
      'pt': 'Cautela em grandes queimaduras; absorção sistêmica da sulfa.',
      'es': 'Vigilar en quemaduras extensas.',
    },
    elderlyAlert: {
      'pt': 'Monitorar leucopenia em uso em áreas extensas.',
      'es': 'Riesgo de leucopenia.',
    },
    mechanism: {
      'pt': 'Liberação de íons prata e sulfa; danifica membrana e parede bacteriana.',
      'es': 'Bactericida tópico.',
    },
    warning: {
      'pt': 'Não usar em gestantes a termo ou neonatos.',
      'es': 'Contraindicado en neonatos.',
    },
    adverse: {
      'pt': ['Leucopenia transitória', 'Ardor local', 'Escurecimento da pele'],
      'es': ['Leucopenia', 'Ardor'],
    },
  ),

  DrugModel(
    id: 'mupirocina',
    group: 'Varios / Antídotos / Otros',
    name: 'Mupirocina',
    className: {'pt': 'Antibiótico Tópico', 'es': 'Antibiótico Tópico'},
    category: {'pt': 'Dermatologia', 'es': 'Dermatología'},
    route: 'Tópica',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Pomada 2%. Aplicar 3x/dia por 5-10 dias.',
      'es': 'Pomada 2%.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário.',
      'es': 'Sin ajuste.',
    },
    elderlyAlert: {
      'pt': 'Seguro.',
      'es': 'Seguro.',
    },
    mechanism: {
      'pt': 'Inibe a isoleucil-tRNA sintetase, bloqueando a síntese proteica.',
      'es': 'Inhibe síntesis proteica tópica.',
    },
    warning: {
      'pt': 'Excelente para erradicação nasal de S. aureus (MRSA).',
      'es': 'Uso en impétigo y MRSA.',
    },
    adverse: {
      'pt': ['Ardência local', 'Prurido', 'Eritema'],
      'es': ['Irritación local'],
    },
  ),

  DrugModel(
    id: 'permetrina',
    group: 'Varios / Antídotos / Otros',
    name: 'Permetrina',
    className: {'pt': 'Antiparasitário / Escabicida', 'es': 'Antiparasitario / Escabicida'},
    category: {'pt': 'Dermatologia', 'es': 'Dermatología'},
    route: 'Tópica',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Creme 5%. Aplicar por 8-14h e lavar. Repetir em 1 semana.',
      'es': 'Crema 5%.',
    },
    renalAlert: {
      'pt': 'Sem ajuste.',
      'es': 'Sin ajuste.',
    },
    elderlyAlert: {
      'pt': 'Seguro.',
      'es': 'Seguro.',
    },
    mechanism: {
      'pt': 'Bloqueia os canais de sódio nos artrópodes, causando paralisia.',
      'es': 'Parálisis del parásito.',
    },
    warning: {
      'pt': 'Aplicar do pescoço para baixo na sarna.',
      'es': 'Uso externo.',
    },
    adverse: {
      'pt': ['Prurido', 'Eritema', 'Parestesia local'],
      'es': ['Picazón', 'Ardor'],
    },
  ),

  DrugModel(
    id: 'clobetasol',
    group: 'Varios / Antídotos / Otros',
    name: 'Clobetasol',
    className: {'pt': 'Corticosteroide Tópico de Alta Potência', 'es': 'Corticoide Tópico Potente'},
    category: {'pt': 'Dermatologia', 'es': 'Dermatología'},
    route: 'Tópica',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Creme/Pomada 0.05%. Aplicar 1-2x/dia.',
      'es': '0.05% 1-2x/día.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário.',
      'es': 'Sin ajuste.',
    },
    elderlyAlert: {
      'pt': 'Risco elevado de atrofia cutânea e púrpuras. Não usar por tempo longo.',
      'es': 'Mayor riesgo de atrofia cutánea.',
    },
    mechanism: {
      'pt': 'Modula a resposta inflamatória local e causa vasoconstrição.',
      'es': 'Antiinflamatorio tópico.',
    },
    warning: {
      'pt': 'Classe 1 (Mais potente). Máximo 2 semanas seguidas.',
      'es': 'Uso limitado a 2 semanas.',
    },
    adverse: {
      'pt': ['Atrofia cutânea', 'Estrias', 'Foliculite', 'Telangiectasias'],
      'es': ['Atrofia', 'Estrías'],
    },
  ),

  DrugModel(
    id: 'ambroxol',
    group: 'Respiratorio',
    name: 'Ambroxol',
    className: {'pt': 'Mucolítico', 'es': 'Mucolítico'},
    category: {'pt': 'Expectorantes', 'es': 'Expectorantes'},
    route: 'VO / Inalatório',
    doseType: 'fixed',
    fixedDose: {
      'pt': '30–60 mg 2-3x/dia.',
      'es': '30–60 mg 2-3x/día.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário.',
      'es': 'Sin ajuste.',
    },
    elderlyAlert: {
      'pt': 'Bem tolerado.',
      'es': 'Seguro.',
    },
    mechanism: {
      'pt': 'Estimula a síntese de surfactante e diminui a viscosidade do muco.',
      'es': 'Disminuye viscosidad del moco.',
    },
    warning: {
      'pt': 'Beber água ajuda na ação expectorante.',
      'es': 'Hidratación necesaria.',
    },
    adverse: {
      'pt': ['Náuseas', 'Pirose', 'Dispepsia'],
      'es': ['Náuseas'],
    },
  ),

  DrugModel(
    id: 'acebrofilina',
    group: 'Respiratorio',
    name: 'Acebrofilina',
    className: {'pt': 'Xantina / Mucolítico', 'es': 'Xantina / Mucolítico'},
    category: {'pt': 'Expectorantes / Broncodilatadores', 'es': 'Expectorantes'},
    route: 'VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': '100 mg 2x/dia.',
      'es': '100 mg 2x/día.',
    },
    renalAlert: {
      'pt': 'Usar com cautela em insuficiência renal.',
      'es': 'Cautela en falla renal.',
    },
    elderlyAlert: {
      'pt': 'Risco de taquicardia e insônia em idosos sensíveis.',
      'es': 'Vigilar frecuencia cardíaca.',
    },
    mechanism: {
      'pt': 'Combina efeito broncodilatador (xantina) com mucolítico.',
      'es': 'Broncodilatador y mucolítico.',
    },
    warning: {
      'pt': 'Monitorar pacientes com histórico de arritmias.',
      'es': 'Precaución en arritmias.',
    },
    adverse: {
      'pt': ['Taquicardia', 'Náuseas', 'Tremor', 'Insônia'],
      'es': ['Taquicardia', 'Náuseas'],
    },
  ),

  DrugModel(
    id: 'salbutamol_gotas',
    group: 'Respiratorio',
    name: 'Salbutamol (Gotas para Nebulização)',
    className: {'pt': 'SABA (Beta-2 agonista curta ação)', 'es': 'Beta-2 agonista acción corta'},
    category: {'pt': 'Emergência / Respiratório', 'es': 'Emergencia / Respiratorio'},
    route: 'Inalatório (Nebulização)',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'Adulto: 10–20 gotas (2.5–5 mg) cada 4-6h.',
      'es': 'Adulto: 10–20 gotas cada 4-6h.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário.',
      'es': 'Sin ajuste.',
    },
    elderlyAlert: {
      'pt': 'Alto risco de taquicardia e tremor em cardiopatas idosos.',
      'es': 'Riesgo de arritmias y temblor.',
    },
    mechanism: {
      'pt': 'Estimula receptores Beta-2 pulmonares, causando broncodilatação rápida.',
      'es': 'Broncodilatador rápido.',
    },
    warning: {
      'pt': 'Monitorar Potássio (risco de hipocalemia em doses altas).',
      'es': 'Monitorear K+.',
    },
    adverse: {
      'pt': ['Taquicardia', 'Tremores finos', 'Cefaleia', 'Palpitações', 'Hipocalemia'],
      'es': ['Taquicardia', 'Temblor', 'Hipopotasemia'],
    },
  ),

  DrugModel(
    id: 'ceftolozana_tazobactam',
    group: 'Infectología (Antifúngicos / Antivirales / TBC)',
    name: 'Ceftolozana + Tazobactam',
    className: {'pt': 'Cefalosporina + Inibidor de Beta-lactamase', 'es': 'Cefalosporina + Inhibidor de Beta-lactamasa'},
    category: {'pt': 'Antibióticos Hospitalares', 'es': 'Antibióticos Hospitalarios'},
    route: 'IV',
    doseType: 'fixed',
    fixedDose: {
      'pt': '1.5 g cada 8h. Reservado para Pseudomonas multirresistente.',
      'es': '1.5 g cada 8h.',
    },
    renalAlert: {
      'pt': 'Ajuste obrigatório conforme ClCr.',
      'es': 'Ajuste obligatorio en falla renal.',
    },
    elderlyAlert: {
      'pt': 'Monitorar função renal estreitamente.',
      'es': 'Vigilar función renal.',
    },
    mechanism: {
      'pt': 'Inibe síntese de parede bacteriana e inibe beta-lactamases.',
      'es': 'Antibiótico de amplio espectro.',
    },
    warning: {
      'pt': 'Uso restrito para evitar resistência.',
      'es': 'Uso restringido.',
    },
    adverse: {
      'pt': ['Diarreia', 'Cefaleia', 'Náuseas', 'Febre'],
      'es': ['Diarrea', 'Cefalea'],
    },
  ),

  DrugModel(
    id: 'esmolol',
    group: 'UCI – Críticos y Sedoanalgesia',
    name: 'Esmolol',
    className: {'pt': 'Betabloqueador de ação ultracurta', 'es': 'Beta-bloqueador acción ultracorta'},
    category: {'pt': 'Cardiovascular / Emergência', 'es': 'Cardiovascular / Emergencia'},
    route: 'IV (Bomba)',
    doseType: 'mcg_kg_min',
    mcgKgMinStart: 50.0,
    mcgKgMinMax: 200.0,
    fixedDose: {
      'pt': 'Ataque: 500 mcg/kg em 1 min. Manutenção: 50–200 mcg/kg/min.',
      'es': 'Dosis titulable según FC.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário.',
      'es': 'Sin ajuste.',
    },
    elderlyAlert: {
      'pt': 'Risco de hipotensão severa imediata.',
      'es': 'Monitorear presión arterial.',
    },
    mechanism: {
      'pt': 'Antagonista Beta-1 seletivo com meia-vida de 9 minutos.',
      'es': 'Beta-bloqueador ultrarrápido.',
    },
    warning: {
      'pt': 'Ideal para controle de FC em Dissecção Aórtica e Tempestade Tireoidiana.',
      'es': 'Uso en disección aórtica.',
    },
    adverse: {
      'pt': ['Hipotensão', 'Bradicardia', 'Sudorese', 'Inflamação no local da infusão'],
      'es': ['Hipotensión', 'Bradicardia'],
    },
  ),

  DrugModel(
    id: 'milrinona',
    group: 'UCI – Críticos y Sedoanalgesia',
    name: 'Milrinona',
    className: {'pt': 'Inodilatador (Inibidor da PDE-3)', 'es': 'Inodilatador (Inhibidor PDE-3)'},
    category: {'pt': 'Vasoativos / IC', 'es': 'Vasoactivos / IC'},
    route: 'IV (Bomba)',
    doseType: 'mcg_kg_min',
    mcgKgMinStart: 0.375,
    mcgKgMinMax: 0.75,
    fixedDose: {
      'pt': 'Ataque: 50 mcg/kg em 10 min. Manutenção: 0.375–0.75 mcg/kg/min.',
      'es': 'Inotrópico positivo.',
    },
    renalAlert: {
      'pt': 'Ajuste obrigatório. Excreção renal predominante.',
      'es': 'Ajuste obligatorio.',
    },
    elderlyAlert: {
      'pt': 'Alto risco de hipotensão e arritmias ventriculares.',
      'es': 'Riesgo de arritmias ventriculares.',
    },
    mechanism: {
      'pt': 'Inibe a fosfodiesterase III, aumentando AMPc no coração e vasos (inotropismo + e vasodilatação).',
      'es': 'Aumenta AMPc intracelular.',
    },
    warning: {
      'pt': 'Pode causar hipotensão severa se houver hipovolemia.',
      'es': 'Riesgo de hipotensión.',
    },
    adverse: {
      'pt': ['Arritmias ventriculares', 'Hipotensão', 'Cefaleia', 'Trombocitopenia'],
      'es': ['Arritmias', 'Hipotensión'],
    },
  ),

  DrugModel(
    id: 'labetalol',
    group: 'UCI – Críticos y Sedoanalgesia',
    name: 'Labetalol',
    className: {'pt': 'Alfa e Betabloqueador', 'es': 'Alfa y Beta-bloqueador'},
    category: {'pt': 'Emergência Hipertensiva', 'es': 'Emergencia Hipertensiva'},
    route: 'IV / VO',
    doseType: 'fixed',
    fixedDose: {
      'pt': 'IV: 20 mg bolus, seguido de 40-80 mg a cada 10 min (máx 300 mg) ou infusão 2 mg/min.',
      'es': 'IV: 20 mg bolo inicial.',
    },
    renalAlert: {
      'pt': 'Sem ajuste necessário.',
      'es': 'Sin ajuste.',
    },
    elderlyAlert: {
      'pt': 'Risco de hipotensão postural grave e bradicardia.',
      'es': 'Vigilar hipotensión.',
    },
    mechanism: {
      'pt': 'Bloqueio não seletivo Beta e seletivo Alfa-1. Proporção 7:1 (Beta:Alfa) no uso IV.',
      'es': 'Bloqueo mixto Beta y Alfa-1.',
    },
    warning: {
      'pt': 'Contraindicado em Asma, DPOC e Bloqueios cardíacos de 2º/3º grau.',
      'es': 'Contraindicado en asma y bradicardia.',
    },
    adverse: {
      'pt': ['Bradicardia', 'Hipotensão', 'Broncoespasmo', 'Congestão nasal'],
      'es': ['Bradicardia', 'Broncoespasmo'],
    },
  ),

];
