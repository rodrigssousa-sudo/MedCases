// clinical_cases_database.dart — banco de casos clínicos educacionais
import '../models/clinical_case_model.dart';

const List<ClinicalCaseModel> kClinicalCasesDB = [

  // ══════════════════════════════════════════════════════════════════
  // INFECTOLOGIA / UROLOGIA
  // ══════════════════════════════════════════════════════════════════

  ClinicalCaseModel(
    id: 'itu_cistitis_aguda_001',
    title: 'Cistite Aguda Não Complicada',
    patientAge: '32',
    patientSex: 'Feminino',
    patientWeight: '64',
    category: 'Infectologia / Urologia',
    history: '''
[Queixa Principal]: Disúria e polaciúria.
[HDA]: Paciente previamente hígida com início há 48h de ardência miccional intensa, tenesmo vesical e dor suprapúbica. Nega febre, náuseas ou dor lombar.
[Exame Físico]: Hemodinamicamente estável. Dor à palpação profunda em hipogástrio. Manobra de Giordano (punho-percussão lombar) negativa bilateral.
[Laboratório]: Sedimento urinário com leucocitúria (>10 por campo), presença de nitritos e bacteriúria moderada. Sem hematúria macroscópica.
    ''',
    diagnosis: 'Cistite aguda não complicada em mulher jovem.',
    plan: '''
1. Nitrofurantoína 100 mg VO 12/12h por 5 dias (primeira escolha).
2. Fenazopiridina 200 mg VO 8/8h por 2 dias (analgésico urinário sintomático).
3. Aumentar ingesta hídrica (>2L/dia).
4. Sinais de alarme: se febre ou dor lombar, retornar por suspeita de pielonefrite.
    ''',
    notes: 'Evitar Nitrofurantoína se suspeita de pielonefrite (nula penetração no tecido renal). Não requer urocultura de controle se sintomas resolverem.',
    drugIds: ['nitrofurantoina', 'fenazopiridina'],
  ),

  ClinicalCaseModel(
    id: 'itu_repeticion_002',
    title: 'Infecção Urinária Recorrente',
    patientAge: '58',
    patientSex: 'Feminino',
    patientWeight: '70',
    category: 'Infectologia / Urologia',
    history: '''
[Antecedentes]: Menopausa há 6 anos sem terapia de reposição hormonal. Apresenta 4 episódios de ITU documentados no último ano.
[HDA]: Atualmente assintomática, solicita manejo preventivo. Refere ressecamento vaginal e dispareunia.
[Exame Físico]: Atrofia vulvovaginal severa (mucosa pálida, perda de pregueamento).
[Urocultura prévia]: E. coli multissensível nos últimos 2 eventos.
    ''',
    diagnosis: 'ITU recorrente associada à síndrome geniturinária da menopausa.',
    plan: '''
1. Medidas comportamentais: micção pós-coital, higiene da frente para trás.
2. Estrogênio tópico (creme de estradiol) 2x/semana (fundamental para restaurar flora de Döderlein).
3. Profilaxia não antibiótica: Cranberry concentrado ou D-Manose 2g/dia.
4. Se falha das medidas anteriores: profilaxia antibiótica com Trimetoprima-Sulfametoxazol (80/400) dose baixa noturna.
    ''',
    notes: 'A causa principal em pós-menopáusicas é o déficit estrogênico; tratar a mucosa vaginal reduz drasticamente as recorrências.',
    drugIds: ['estriol_topico', 'trimetoprima_sulfametoxazol'],
  ),

  // ══════════════════════════════════════════════════════════════════
  // NEUROLOGIA
  // ══════════════════════════════════════════════════════════════════

  ClinicalCaseModel(
    id: 'cefalea_migrana_aguda_003',
    title: 'Crise de Enxaqueca Moderada-Severa',
    patientAge: '25',
    patientSex: 'Feminino',
    patientWeight: '58',
    category: 'Neurologia',
    history: '''
[HDA]: Cefaleia hemicraniana direita, caráter pulsátil, intensidade 9/10 (EVA).
[Sintomas associados]: Fotofobia, fonofobia e dois episódios de vômito. Relata "ver luzes cintilantes" (escotomas) 20 minutos antes do início da dor.
[Exame Físico]: Paciente em decúbito, prefere escuridão. Sem sinais meníngeos. Fundo de olho normal (sem papiledema). Força e sensibilidade preservadas.
[Antecedentes]: Mãe enxaquecosa. Episódios mensais desde os 18 anos.
    ''',
    diagnosis: 'Crise de Enxaqueca com Aura. Afastar cefaleia secundária.',
    plan: '''
1. Resgate agudo: Sumatriptano 6 mg SC ou 50 mg VO (se sem contraindicação vascular).
2. Antiemético: Metoclopramida 10 mg EV (melhora absorção e trata a náusea).
3. AINE: Naproxeno 500 mg VO.
4. Repouso em ambiente silencioso e escuro.
5. Sinais de alarme: cefaleia "em trovoada", início súbito pós-esforço ou mudança de padrão → TC de crânio urgente.
    ''',
    notes: 'Red Flags: cefaleia em trovoada, início súbito após esforço físico ou mudança no padrão habitual de crises exigem investigação imediata.',
    drugIds: ['sumatriptano', 'metoclopramida', 'naproxeno'],
  ),

  ClinicalCaseModel(
    id: 'avc_isquemico_agudo_005',
    title: 'AVC Isquêmico Agudo — Janela Trombolítica',
    patientAge: '67',
    patientSex: 'Masculino',
    patientWeight: '78',
    category: 'Neurologia',
    history: '''
[HDA]: Início súbito há 1h20 de hemiplegia direita e afasia. Familiar presenciou o início dos sintomas.
[Exame Neurológico]: NIHSS 14. Paresia facial central direita, plegia de MMSD, afasia global. Sem rebaixamento de consciência.
[Antecedentes]: HAS em uso de AAS e Losartana. Tabagista (20 maços-ano).
[TC Crânio]: Sem hemorragia. Hipodensidade incipiente em território de ACM esquerda.
    ''',
    diagnosis: 'AVC Isquêmico Agudo em território de ACM esquerda. Candidato a trombólise.',
    plan: '''
1. Alteplase 0,9 mg/kg EV (máx. 90 mg): 10% em bolo + 90% em 60 min — INICIAR IMEDIATAMENTE.
2. Monitorização contínua: PA, SatO2, glicemia, temperatura.
3. Manter PA < 185/110 mmHg antes e durante trombólise.
4. Nada por via oral — avaliar disfagia antes de qualquer medicação VO.
5. Solicitar angioTC para avaliar trombectomia mecânica se tronco ocluído.
    ''',
    notes: 'Tempo é neurônio: cada 1 min de atraso = 1,9 milhão de neurônios perdidos. Meta door-to-needle < 60 min.',
    drugIds: ['alteplase'],
  ),

  ClinicalCaseModel(
    id: 'status_epilepticus_006',
    title: 'Estado de Mal Epiléptico Convulsivo',
    patientAge: '34',
    patientSex: 'Masculino',
    patientWeight: '72',
    category: 'Neurologia',
    history: '''
[HDA]: Convulsão tônico-clônica generalizada há 12 minutos sem pausa. Testemunhas não relatam trauma ou ingesta de substâncias.
[Antecedentes]: Epilepsia focal desde a infância, em uso irregular de Carbamazepina.
[Exame]: Glasgow 8. Cianose peribucal. SatO2 84% em ar ambiente. Glicemia capilar 92 mg/dL.
    ''',
    diagnosis: 'Estado de mal epiléptico convulsivo (>5 min). Causa provável: não aderência ao tratamento.',
    plan: '''
1. Via aérea + O2 (máscara com reservatório, 15L/min).
2. Acesso venoso → Diazepam 10 mg EV em 2 min (ou Midazolam 10 mg IM se sem acesso).
3. Se persistir após 5 min: Fenitoína 20 mg/kg EV em 20 min (ou Levetiracetam 60 mg/kg).
4. Se refratário (>30 min): UTI + Propofol ou Midazolam em infusão contínua.
5. Investigação etiológica: eletrólitos, toxicológico, neuroimagem, líquor se indicado.
    ''',
    notes: 'Guideline 2022: Benzodiazepínico é a 1ª linha absoluta. Levetiracetam preferível à Fenitoína em gestantes e cardiopatas.',
    drugIds: ['diazepam', 'fenitoina', 'levetiracetam', 'midazolam'],
  ),

  // ══════════════════════════════════════════════════════════════════
  // MEDICINA INTERNA / EMERGÊNCIA
  // ══════════════════════════════════════════════════════════════════

  ClinicalCaseModel(
    id: 'malestar_general_sepsis_004',
    title: 'Mau Estado Geral — Sepse a Esclarecer',
    patientAge: '75',
    patientSex: 'Masculino',
    patientWeight: '82',
    category: 'Medicina Interna',
    history: '''
[HDA]: Familiares relatam astenia marcada, adinamia e desorientação flutuante nas últimas 12h.
[Exame Físico]: Desidratação mucocutânea. PA 90/60 mmHg, FC 112 bpm, FR 24 irpm, Tax 38,5°C.
[qSOFA]: 2 pontos (taquipneia + alteração do sensório).
[Abdomen]: Flácido, mas com desconforto difuso à palpação.
    ''',
    diagnosis: 'Síndrome febril / Choque distributivo (Sepse provável). Foco a determinar.',
    plan: '''
1. Hidratação agressiva: Ringer Lactato 30 ml/kg em bolo inicial.
2. Coleta de culturas: Hemoculturas (2 pares) e Urocultura antes do antibiótico.
3. Antibioticoterapia empírica precoce: Ceftriaxona 2g EV.
4. Laboratório urgente: Lactato sérico, Procalcitonina, função renal, hemograma.
5. Reavaliação em 1h: se PA não responde → noradrenalina + UTI.
    ''',
    notes: 'Em idosos, mau estado geral e confusão podem ser a única manifestação de infecções graves. Lactato >2 mmol/L = critério de sepse grave.',
    drugIds: ['ceftriaxona', 'ringer_lactato', 'noradrenalina'],
  ),

  ClinicalCaseModel(
    id: 'cad_cetoacidose_007',
    title: 'Cetoacidose Diabética (CAD)',
    patientAge: '22',
    patientSex: 'Masculino',
    patientWeight: '68',
    category: 'Endocrinologia',
    history: '''
[HDA]: DM1 desde os 15 anos. Interrompeu insulina há 3 dias por conta própria. Vômitos repetidos, dor abdominal difusa e hálito cetônico há 8h.
[Exame]: Desidratado +++, taquicárdico (FC 118), FR 28 irpm (respiração de Kussmaul). Glasgow 14.
[Laboratório]: Glicemia 485 mg/dL, pH 7,18, HCO3 8 mEq/L, K+ 3,2 mEq/L, cetonúria +++.
    ''',
    diagnosis: 'Cetoacidose Diabética grave. Hipocalemia associada.',
    plan: '''
1. Hidratação: SF 0,9% 1L na 1ª hora, depois ajuste conforme Na corrigido.
2. Insulina regular EV: 0,1 UI/kg/h (somente após K+ > 3,5 mEq/L).
3. Reposição de K+: 20-40 mEq/h EV enquanto K+ < 3,5.
4. Monitorização horária: glicemia, K+, pH, diurese.
5. Investigar fator precipitante: infecção, abandono de insulina, IAM.
    ''',
    notes: 'NUNCA iniciar insulina com K+ < 3,5 — risco de parada cardíaca. A insulina desloca K+ para dentro da célula agravando a hipocalemia.',
    drugIds: ['insulina_regular', 'cloreto_potassio'],
  ),

  ClinicalCaseModel(
    id: 'iam_stemi_008',
    title: 'IAM com Supradesnivelamento de ST (STEMI)',
    patientAge: '55',
    patientSex: 'Masculino',
    patientWeight: '88',
    category: 'Cardiologia',
    history: '''
[HDA]: Dor torácica retroesternal em aperto, irradiação para MSE e mandíbula, início há 40 min. Diaforese profusa e náuseas.
[Exame]: PA 145/90, FC 98 bpm, FR 18 irpm. Bulhas rítmicas sem sopros. Sem sinais de IC.
[ECG]: Supradesnivelamento de ST ≥2 mm em V1-V4 (padrão de oclusão de DA proximal).
[Troponina]: Pendente.
    ''',
    diagnosis: 'STEMI anterior extenso. Candidato à reperfusão de emergência.',
    plan: '''
1. AAS 300 mg VO (mastigar) + Ticagrelor 180 mg VO imediatamente.
2. Heparina não fracionada 60 UI/kg EV em bolo (máx 4.000 UI).
3. Morfina 2-4 mg EV se dor intensa (com cautela — pode mascarar deterioração).
4. O2 suplementar se SatO2 < 90%.
5. ANGIOPLASTIA PRIMÁRIA: ativar hemodinâmica — meta door-to-balloon < 90 min.
    ''',
    notes: 'Se hemodinâmica indisponível em <120 min: trombolítico (Tenecteplase peso-ajustado). Monitorizar arritmias de reperfusão pós-ICP.',
    drugIds: ['aas', 'ticagrelor', 'heparina', 'morfina'],
  ),

  ClinicalCaseModel(
    id: 'anafilaxia_009',
    title: 'Anafilaxia Grave',
    patientAge: '28',
    patientSex: 'Feminino',
    patientWeight: '60',
    category: 'Emergência / Alergologia',
    history: '''
[HDA]: 15 min após 1ª dose de Amoxicilina, paciente desenvolve urticária generalizada, edema de lábios, rouquidão progressiva e hipotensão.
[Exame]: PA 75/40 mmHg, FC 128 bpm, SatO2 91%. Angioedema de língua e úvula. Estridor inspiratório.
[Critérios de anafilaxia]: 3/3 (pele + respiratório + cardiovascular).
    ''',
    diagnosis: 'Anafilaxia grave por hipersensibilidade à Penicilina.',
    plan: '''
1. ADRENALINA 0,3-0,5 mg IM (lateral da coxa) — IMEDIATO, sem atrasos.
2. Decúbito dorsal + MMII elevados (se hipotensão).
3. O2 alto fluxo (15L/min). Preparar IOT se estridor progredir.
4. SF 0,9%: 1-2L em bolo rápido.
5. Difenidramina 50 mg EV + Metilprednisolona 125 mg EV (adjuvantes, não substituem adrenalina).
6. Observação mínima 6h (risco de reação bifásica).
    ''',
    notes: 'Adrenalina IM é o único tratamento que salva vida na anafilaxia. Anti-histamínicos e corticoides são ADJUVANTES — nunca primeira linha.',
    drugIds: ['adrenalina', 'difenidramina', 'metilprednisolona'],
  ),

  ClinicalCaseModel(
    id: 'pneumonia_grave_010',
    title: 'Pneumonia Adquirida na Comunidade Grave (PAC)',
    patientAge: '70',
    patientSex: 'Masculino',
    patientWeight: '74',
    category: 'Pneumologia / Infectologia',
    history: '''
[HDA]: Febre há 4 dias (Tax 39,2°C), tosse produtiva com expectoração amarelada e dispneia progressiva. Piora nas últimas 24h.
[Exame]: PA 110/70, FC 105, FR 28, SatO2 88% em ar ambiente. MV diminuído em base direita com crepitações.
[PSI/PORT]: Classe V (alto risco). CURB-65: 3 pontos.
[RX Tórax]: Condensação lobar em lobo inferior direito.
    ''',
    diagnosis: 'PAC grave (CURB-65 ≥3). Internação em UTI/semi-intensiva.',
    plan: '''
1. O2 suplementar: alvo SatO2 92-96%. Preparar VNI se SatO2 não melhorar.
2. Antibioticoterapia: Ampicilina-Sulbactam 3g EV 6/6h + Azitromicina 500 mg EV/VO 1x/dia.
3. Hidratação criteriosa (evitar sobrecarga).
4. Culturas (hemocultura + escarro) antes do antibiótico.
5. Reavaliação em 48-72h para ajuste de antibiótico conforme cultura.
    ''',
    notes: 'PAC grave CURB-65 ≥3 = mortalidade 17-22%. Cobertura de atípicos (Legionella, Mycoplasma) é obrigatória.',
    drugIds: ['ampicilina_sulbactam', 'azitromicina'],
  ),

  ClinicalCaseModel(
    id: 'tvp_tep_011',
    title: 'Tromboembolismo Pulmonar (TEP) de Alto Risco',
    patientAge: '48',
    patientSex: 'Feminino',
    patientWeight: '66',
    category: 'Cardiologia / Pneumologia',
    history: '''
[HDA]: Dispneia súbita intensa após voo de 11h. Dor pleurítica direita. Retornou de viagem internacional há 6h.
[Exame]: PA 88/55, FC 122 bpm, FR 26, SatO2 85%. Turgência jugular. MMID com edema e empastamento.
[ECG]: Padrão S1Q3T3. Taquicardia sinusal.
[AngioTC]: Trombos em artéria pulmonar principal direita e lobar esquerda.
    ''',
    diagnosis: 'TEP de alto risco (instabilidade hemodinâmica). Candidata à trombólise sistêmica.',
    plan: '''
1. Alteplase 100 mg EV em 2h — IMEDIATO (TEP com choque = trombólise sem demora).
2. Heparina não fracionada: suspender durante trombólise, retomar após.
3. O2 alto fluxo. Preparar UTI e suporte ventilatório.
4. Evitar hipotensão: SF em bolo cuidadoso (VD sobrecarregado).
5. Se contraindicação à trombólise: embolectomia cirúrgica ou cateter-directed therapy.
    ''',
    notes: 'TEP alto risco = mortalidade 30-65%. Trombólise reduz mortalidade se instabilidade hemodinâmica presente. PESI score para estratificação.',
    drugIds: ['alteplase', 'heparina'],
  ),

  ClinicalCaseModel(
    id: 'icc_descompensada_012',
    title: 'Insuficiência Cardíaca Descompensada',
    patientAge: '72',
    patientSex: 'Feminino',
    patientWeight: '80',
    category: 'Cardiologia',
    history: '''
[HDA]: ICC com FE reduzida (FE 30%), internação por descompensação pela 3ª vez em 1 ano. Ganho de 4 kg em 1 semana. Ortopneia e dispneia paroxística noturna.
[Exame]: PA 155/95, FC 95, FR 24, SatO2 91% em repouso. Estase jugular a 45°. Crepitações bibasais. Edema MMII +++.
[BNP]: 1850 pg/mL. RX: congestão pulmonar bilateral.
    ''',
    diagnosis: 'IC Descompensada — perfil "Quente e Úmido" (congesto + perfundido).',
    plan: '''
1. Furosemida 40-80 mg EV em bolo (dobrar dose oral habitual).
2. Elevação do decúbito + O2 suplementar (alvo SatO2 >94%).
3. VNI (CPAP/BiPAP) se SatO2 <90% após O2.
4. Monitorização: diurese horária, eletrólitos 12/12h, balanço hídrico.
5. Manter IECA/BRA e betabloqueador SE hemodinamicamente estável.
    ''',
    notes: 'Meta: débito urinário 100-200 mL/h nas primeiras 6h. Reduzir o betabloqueador (não suspender abruptamente) se FC <50 ou hipotensão.',
    drugIds: ['furosemida'],
  ),

  // ══════════════════════════════════════════════════════════════════
  // GASTROENTEROLOGIA
  // ══════════════════════════════════════════════════════════════════

  ClinicalCaseModel(
    id: 'hda_varicosa_013',
    title: 'Hemorragia Digestiva Alta — Varizes Esofágicas',
    patientAge: '52',
    patientSex: 'Masculino',
    patientWeight: '71',
    category: 'Gastroenterologia',
    history: '''
[HDA]: Cirrose hepática por álcool (Child-Pugh B). Hematêmese volumosa há 1h (>500 mL estimado). Lipotimia ao sentar.
[Exame]: PA 85/50 mmHg, FC 130 bpm, Hb 7,1 g/dL. Abdomen com ascite moderada. Eritema palmar, aranhas vasculares.
[Endoscopia prévia há 6 meses]: Varizes esofágicas grau III sem ligadura realizada.
    ''',
    diagnosis: 'HDA varicosa em cirrótico. Alto risco de ressangramento (Child B + varizes III).',
    plan: '''
1. Acesso venoso calibroso (2x) + expansão com cristaloide (não exagerar — risco de hipertensão portal).
2. Terlipressina 2 mg EV 4/4h (vasoconstritor esplâncnico) — INICIAR ANTES DA ENDOSCOPIA.
3. Ceftriaxona 1g EV/dia por 7 dias (profilaxia de PBE pós-sangramento).
4. Endoscopia de urgência (<12h): ligadura elástica das varizes.
5. Transfusão se Hb <7 g/dL (alvo conservador 7-8 g/dL em cirróticos).
    ''',
    notes: 'Evitar hiperexpansão volêmica — piora a hipertensão portal. Não usar AINE/AAS em cirróticos. Transição para Nadolol após estabilização.',
    drugIds: ['terlipressina', 'ceftriaxona', 'nadolol'],
  ),
];
