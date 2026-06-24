// ══════════════════════════════════════════════════════════════════════════════
// plantao_pipeline.dart — Plantão Pipeline v2.0 (Build 224)
//
// RESPONSABILIDADES:
//   • PlantaoIntentClassifier — classifica intenção clínica do usuário (Build 224)
//   • PlantaoResponse  — data class estruturada com campos clínicos dinâmicos
//   • PlantaoParser    — extrai PlantaoResponse de texto validado via emoji-anchors
//   • PlantaoValidator — valida estrutura mínima por template de intenção
//   • PlantaoRepair    — reorganiza blocos, elimina duplicatas, normaliza espaços
//                        (NUNCA inventa conteúdo clínico)
//
// PIPELINE COMPLETO (Build 224):
//   lastUserMessage
//     → PlantaoIntentClassifier.classify()  [detecta intenção: conduta/dose/monitorização/...]
//     → intentMandate injetado no system_instruction (gateway)
//   LLM output
//     → sanitizeResponse()       [ai_smart_router.dart — meta leak filter]
//     → PlantaoRepair.repair()   [reorganiza blocos, deduplication]
//     → PlantaoValidator.isValid() [valida estrutura por template]
//     → PlantaoParser.parse()    [constrói objeto estruturado]
//     → _PlantaoRenderer         [renderiza layout canônico com emojis do template]
//
// EMOJIS ÂNCORA — TEMPLATE CONDUTA (ordem canônica):
//   🟥  → título/conduta (OBRIGATÓRIO — primeira linha)
//   💊  → primeiraLinha (OBRIGATÓRIO)
//   🔄  → alternativa (opcional)
//   ⛔  → evitar (opcional)
//   📌  → monitorar (OBRIGATÓRIO)
//   ⚠️  → alerta (opcional)
//
// EMOJIS ÂNCORA — TEMPLATES ALTERNATIVOS (Build 224):
//   🟥  → sempre o título (OBRIGATÓRIO)
//   📌  → bloco de monitorização / observar
//   📈  → valores esperados / metas
//   ✅  → próximo passo
//   ❌  → evitar / contraindicação (alternativa a ⛔)
//   🔎  → suspeitar se (diagnóstico)
//   🧪  → confirmar com / diluição / preparo
//   🧮  → cálculo / velocidade
//   📖  → significado / interpretação
//
// SEGURANÇA:
//   • Linhas iniciando com '[' são silenciosamente ignoradas
//   • Campos opcionais ausentes → campo null (não renderizado)
//   • Streaming: pipeline só é aplicado no chunk.isDone
//
// LOG ESTRUTURADO:
//   [PLANTAO_VALIDATOR] valid=true repaired=false removedLines=2
//                       hiddenFields=1 orderFixed=true
//   [PLANTAO_INTENT] intent=monitoramento score=3 keywords=[ecg, potassio, monitorar]
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart' show debugPrint;

// ─────────────────────────────────────────────────────────────────────────────
// PlantaoIntent — enum de intenção clínica (Build 224)
//
// Classificado pelo PlantaoIntentClassifier a partir de lastUserMessage.
// Controla: qual template de emojis usar + qual mandato enviar para o LLM.
// ─────────────────────────────────────────────────────────────────────────────
enum PlantaoIntent {
  conduta,          // conduta terapêutica geral / tratamento
  dose,             // dose de fármaco específico
  infusao,          // cálculo de infusão EV / mcg/kg/min → mL/h
  diluicao,         // preparo de ampola / diluição / gotejamento
  monitorizacao,    // parâmetros de monitorização / metas / valores
  contraindicacao,  // contraindicações / quando não usar
  diagnostico,      // como diagnosticar / suspeitar / confirmar
  interpretacao,    // interpretar resultado / exame / parâmetro
  eletrolitos,      // distúrbio eletrolítico / reposição iônica
  glicemia,         // glicose / CAD / hipoglicemia / protocolo insulina
  ventilacao,       // ventilação mecânica / parâmetros ventilatórios
  pcr,              // PCR / ressuscitação cardiopulmonar / ACLS
  choque,           // choque / vasopressores / ressuscitação hemodinâmica
  sepse,            // sepse / infecção grave / antibioticoterapia empírica
  arritmia,         // arritmias / cardioversão / antiarrítmicos
  via_aerea,        // intubação / via aérea / IOT / RSI
  calculo,          // cálculo clínico / Cockcroft-Gault / score / fórmula
  interacao,        // interação medicamentosa
  procedimento,     // procedimento / técnica / dreno / punção
  geral,            // intenção genérica / não classificada
}

// ─────────────────────────────────────────────────────────────────────────────
// PlantaoIntentClassifier — classificador local determinístico (Build 224)
//
// 100% LOCAL — ZERO IA — ZERO REDE — ZERO RAG
// Classifica a intenção clínica do usuário por correspondência de keywords.
// A intenção controla o template de resposta, não apenas o conteúdo.
// ─────────────────────────────────────────────────────────────────────────────
class PlantaoIntentClassifier {
  PlantaoIntentClassifier._(); // 100% estático

  // ── Tabelas de keywords por intenção (ordem de prioridade decrescente) ────

  static const _kGotejamento = [
    'gota', 'gotejo', 'gotejamento', 'gotejar', 'macrogotas', 'microgotas',
    'equipo de soro', 'equipo de infusão',
  ];

  static const _kDiluicao = [
    'dilui', 'diluição', 'preparo', 'preparar', 'ampola', 'ampolas',
    'como preparar', 'como dilui', 'prepara', 'reconstituir',
  ];

  static const _kInfusao = [
    'infusão', 'infusao', 'velocidade', 'ml/h', 'mcg/kg', 'mcg/min',
    'drip', 'bic', 'bomba infusora', 'titulação', 'titular',
    'calcular infusão', 'como calcular a infusão', 'calcular velocidade',
  ];

  static const _kDose = [
    'dose', 'dosagem', 'quanto', 'mg/kg', 'posologia', 'dosis',
    'qual a dose', 'dose de', 'dose do', 'dose da', 'dosis de',
    'quantos mg', 'quantos mcg',
  ];

  static const _kMonitorizacao = [
    'monitorar', 'monitorizar', 'monitoring', 'monitorização', 'monitoreo',
    'o que observar', 'o que monitorar', 'parâmetros', 'parametros',
    'metas', 'meta terapêutica', 'meta terapeutica', 'valores esperados',
    'alvo', 'alvos', 'target', 'frequência', 'frequencia',
    'quando preocupar', 'sinal de gravidade', 'sinais de gravidade',
    'ecg', 'eletro', 'monitorar ecg', 'monitorar potassio',
  ];

  static const _kContraindicacao = [
    'contraindicação', 'contraindicaçoes', 'contraindicado', 'contra-indicação',
    'contraindicaciones', 'quando não usar', 'quando não dar', 'quando evitar',
    'quem não pode', 'proibido', 'não pode usar', 'evitar em',
    'contraindicado em', 'contraindicada',
  ];

  static const _kDiagnostico = [
    'diagnóstico', 'diagnosticar', 'como diagnosticar', 'suspeitar',
    'como suspeitar', 'criterios', 'critérios', 'confirmar',
    'diferencial', 'diagnóstico diferencial', 'como identificar',
    'sinais', 'sintomas', 'apresentação', 'quadro clínico',
    'como reconhecer', 'diagnose',
  ];

  static const _kInterpretacao = [
    'interpretar', 'interpretação', 'o que significa', 'o que quer dizer',
    'interpretar resultado', 'valor alto', 'valor baixo', 'resultado de',
    'resultado do', 'laudo', 'exame alterado', 'analisar',
    'o que fazer com', 'como interpretar', 'analizar',
  ];

  static const _kEletrolitos = [
    'hipocalemia', 'hipercalemia', 'hypokale', 'hyperkale',
    'hiponatremia', 'hipernatremia', 'hyponatremia',
    'hipocalcemia', 'hipercalcemia', 'hypocalcemia',
    'hipomagnesemia', 'hipofosfatemia', 'hipoglicemia',
    'potássio', 'potassio', 'sódio', 'sodio', 'cálcio', 'calcio',
    'magnésio', 'magnesio', 'fósforo', 'fosforo', 'cloro', 'cloreto',
    'eletrólito', 'eletrolito', 'distúrbio eletrolítico', 'reposição de',
    'reposição ev', 'repor potássio', 'repor sódio',
  ];

  static const _kGlicemia = [
    'cad', 'cetoacidose', 'cetoacidose diabética', 'dka', 'ehh',
    'estado hiperosmolar', 'insulina ev', 'insulina endovenosa',
    'protocolo insulina', 'glicemia', 'hipoglicemia', 'hiperglicemia',
    'glicose ev', 'controle glicêmico', 'glicemia capilar',
    'insulinoterapia',
  ];

  static const _kVentilacao = [
    'ventilação mecânica', 'ventilação', 'vm', 'ventilador',
    'intubação', 'intubar', 'iot', 'rsi', 'ira',
    'peep', 'pressão plateau', 'volume corrente', 'fio2',
    'modo ventilatório', 'pressão suporte', 'vc', 'fr ventilatória',
    'desmame', 'extubação', 'via aérea difícil',
  ];

  static const _kPcr = [
    'pcr', 'parada cardíaca', 'parada cardiaca', 'parada cardiorrespiratória',
    'rcp', 'ressuscitação', 'acls', 'bls', 'bls/acls',
    'reanimação', 'desfibrilação', 'cardioversão',
    'adrenalina pcr', 'amiodarona pcr', 'ritmo de pcr',
    'fv', 'fibrilação ventricular', 'tvscp', 'atividade elétrica sem pulso',
    'aesp', 'assistolia',
  ];

  static const _kChoque = [
    'choque', 'shock', 'choque séptico', 'choque cardiogênico',
    'choque distributivo', 'choque hipovolêmico',
    'noradrenalina', 'norepinefrina', 'vasopressina', 'vasopressor',
    'hipotensão refratária', 'pac', 'pressão arterial baixa',
    'pam < 65', 'pam baixa', 'ressuscitação hemodinâmica',
  ];

  static const _kSepse = [
    'sepse', 'sepsis', 'septicemia', 'choque séptico',
    'antibioticoterapia empírica', 'cobertura empírica',
    'bundle sepse', 'hora 1', 'lactato', 'foco infeccioso',
    'infecção grave', 'sbcs', 'sofa', 'qsofa',
  ];

  static const _kArritmia = [
    'arritmia', 'taquicardia', 'fibrilação atrial', 'fa',
    'flutter atrial', 'tsvp', 'taqui supra', 'taqui ventricular',
    'bradiarritmia', 'bloqueio av', 'bav', 'wcpw',
    'cardioversão elétrica', 'cardioversão química',
    'amiodarona arritmia', 'adenosina', 'metoprolol ev',
    'digoxina', 'marcapasso',
  ];

  static const _kViaAerea = [
    'intubação', 'intubar', 'iot', 'via aérea', 'rsi', 'sri',
    'sequência rápida', 'laringoscopia', 'videolaringoscopia',
    'ketamina indutor', 'etomidato', 'succinilcolina', 'rocurônio',
    'cricotireoidostomia', 'via aérea difícil', 'cormack',
    'mnemônico para', 'mallampati',
  ];

  static const _kCalculo = [
    'calcular', 'cálculo', 'fórmula', 'calculo', 'formula',
    'clcr', 'cockcroft', 'tfg', 'ckd-epi', 'egfr',
    'clearance de creatinina', 'ajuste renal',
    'ânion gap', 'anion gap', 'be', 'base excess',
    'osmolaridade', 'água livre', 'déficit de sódio',
    'peso ideal', 'imc', 'bmi', 'score',
  ];

  static const _kInteracao = [
    'interação', 'interaçao', 'interação medicamentosa',
    'pode usar com', 'pode dar com', 'combinar', 'associar',
    'risco de interação', 'incompatível', 'incompatibilidade',
    'junto com', 'associação de', 'combinar com',
  ];

  static const _kProcedimento = [
    'procedimento', 'técnica', 'como fazer', 'como realizar',
    'punção', 'dreno', 'toracocentese', 'paracentese', 'artrocentese',
    'acesso venoso central', 'cateter', 'linha arterial',
    'dissecção venosa', 'cricotireoidostomia', 'pericardiocentese',
    'cardioversão elétrica', 'marca-passo', 'drenagem',
    'biópsia', 'punção lombar',
  ];

  static const _kConduta = [
    'conduta', 'tratar', 'tratamento', 'como tratar', 'manejo',
    'protocolo de', 'o que fazer', 'primeira linha',
    'abordagem', 'manejo de', 'conduta em', 'tratar com',
  ];

  /// Classifica a intenção clínica a partir do texto da mensagem do usuário.
  ///
  /// Retorna PlantaoIntentResult com a intenção classificada, score e keywords
  /// que dispararam a classificação (para log).
  static PlantaoIntentResult classify(String userMessage) {
    final msg = userMessage.toLowerCase().trim();
    if (msg.isEmpty) {
      return PlantaoIntentResult(
        intent: PlantaoIntent.geral,
        score: 0,
        matchedKeywords: [],
      );
    }

    // Avalia cada intenção em ordem de prioridade
    final checks = <_IntentCheck>[
      // Cálculos de gotejamento — maior prioridade (muito específico)
      _IntentCheck(PlantaoIntent.diluicao, _kGotejamento),
      // Diluição / preparo de ampola
      _IntentCheck(PlantaoIntent.diluicao, _kDiluicao),
      // Infusão contínua
      _IntentCheck(PlantaoIntent.infusao, _kInfusao),
      // PCR — emergência máxima
      _IntentCheck(PlantaoIntent.pcr, _kPcr),
      // Via aérea
      _IntentCheck(PlantaoIntent.via_aerea, _kViaAerea),
      // Monitorização
      _IntentCheck(PlantaoIntent.monitorizacao, _kMonitorizacao),
      // Contraindicação
      _IntentCheck(PlantaoIntent.contraindicacao, _kContraindicacao),
      // Diagnóstico
      _IntentCheck(PlantaoIntent.diagnostico, _kDiagnostico),
      // Interpretação de resultado
      _IntentCheck(PlantaoIntent.interpretacao, _kInterpretacao),
      // Eletrólitos
      _IntentCheck(PlantaoIntent.eletrolitos, _kEletrolitos),
      // Glicemia / CAD
      _IntentCheck(PlantaoIntent.glicemia, _kGlicemia),
      // Ventilação mecânica
      _IntentCheck(PlantaoIntent.ventilacao, _kVentilacao),
      // Choque / vasopressores
      _IntentCheck(PlantaoIntent.choque, _kChoque),
      // Sepse
      _IntentCheck(PlantaoIntent.sepse, _kSepse),
      // Arritmias
      _IntentCheck(PlantaoIntent.arritmia, _kArritmia),
      // Cálculo clínico
      _IntentCheck(PlantaoIntent.calculo, _kCalculo),
      // Interação medicamentosa
      _IntentCheck(PlantaoIntent.interacao, _kInteracao),
      // Procedimento
      _IntentCheck(PlantaoIntent.procedimento, _kProcedimento),
      // Dose de fármaco
      _IntentCheck(PlantaoIntent.dose, _kDose),
      // Conduta geral
      _IntentCheck(PlantaoIntent.conduta, _kConduta),
    ];

    // Retorna a primeira intenção com score ≥ 1
    for (final check in checks) {
      final matched = check.keywords
          .where((kw) => msg.contains(kw))
          .toList();
      if (matched.isNotEmpty) {
        final result = PlantaoIntentResult(
          intent: check.intent,
          score: matched.length,
          matchedKeywords: matched,
        );
        debugPrint('[PLANTAO_INTENT] intent=${result.intent.name} '
            'score=${result.score} '
            'keywords=${result.matchedKeywords}');
        return result;
      }
    }

    // Fallback: conduta geral
    return PlantaoIntentResult(
      intent: PlantaoIntent.geral,
      score: 0,
      matchedKeywords: [],
    );
  }

  /// Retorna o mandato de intenção para injetar no system_instruction.
  ///
  /// Este texto instrui o LLM a usar o template correto para a intenção
  /// classificada. É compacto, sem texto que possa vazar na resposta.
  static String buildIntentMandate(PlantaoIntentResult result, String lang) {
    final isEs = lang == 'es';
    switch (result.intent) {
      case PlantaoIntent.diluicao:
        return isEs
            ? 'TEMPLATE DILUCIÓN:\n'
                '🟥 [FÁRMACO — DILUCIÓN/PREPARACIÓN]\n'
                '🧪 Volumen: Aspire X mL (Y ampollas)\n'
                '🧪 Dilución: Diluya en X mL SF/SG\n'
                '🧪 Infusión: Administrar a X mL/h por Y horas\n'
                '📌 Monitorizar: [parámetro]\n'
                '⚠️ Alerta: [riesgo si aplica]'
            : 'TEMPLATE DILUIÇÃO:\n'
                '🟥 [FÁRMACO — DILUIÇÃO/PREPARO]\n'
                '🧪 Volume: Aspire X mL (Y ampolas)\n'
                '🧪 Diluição: Dilua em X mL SF/SG\n'
                '🧪 Infusão: Correr a X mL/h por Y horas\n'
                '📌 Monitorar: [parâmetro]\n'
                '⚠️ Alerta: [risco se houver]';

      case PlantaoIntent.infusao:
        return isEs
            ? 'TEMPLATE INFUSIÓN:\n'
                '🟥 [FÁRMACO — INFUSIÓN EV]\n'
                '💊 Dosis alvo: [X mcg/kg/min]\n'
                '🧮 Velocidade: **[X mL/h]**\n'
                '🔄 Titulación: [como ajustar]\n'
                '📌 Monitorizar: [PAM/FC/parámetros]\n'
                '⚠️ Alerta: [riesgo crítico]'
            : 'TEMPLATE INFUSÃO:\n'
                '🟥 [FÁRMACO — INFUSÃO EV]\n'
                '💊 Dose alvo: [X mcg/kg/min]\n'
                '🧮 Velocidade: **[X mL/h]**\n'
                '🔄 Titulação: [como ajustar]\n'
                '📌 Monitorar: [PAM/FC/parâmetros]\n'
                '⚠️ Alerta: [risco crítico]';

      case PlantaoIntent.monitorizacao:
        return isEs
            ? 'TEMPLATE MONITORIZACIÓN:\n'
                '🟥 MONITORIZACIÓN — [PARÁMETRO]\n'
                '📌 Observar: [qué vigilar + parámetros objetivos]\n'
                '📈 Metas: [valores esperados / objetivos]\n'
                '⚠️ Gravedad: [signos de alarma]\n'
                '❌ Evitar: [errores comunes]\n'
                '✅ Próximo paso: [acción si meta no alcanzada]'
            : 'TEMPLATE MONITORIZAÇÃO:\n'
                '🟥 MONITORIZAÇÃO — [PARÂMETRO]\n'
                '📌 Observar: [o que vigiar + parâmetros objetivos]\n'
                '📈 Metas: [valores esperados / alvos]\n'
                '⚠️ Gravidade: [sinais de alarme]\n'
                '❌ Evitar: [erros comuns]\n'
                '✅ Próximo passo: [ação se meta não atingida]';

      case PlantaoIntent.contraindicacao:
        return isEs
            ? 'TEMPLATE CONTRAINDICACIONES:\n'
                '🟥 [FÁRMACO/PROCEDIMIENTO — CONTRAINDICACIONES]\n'
                '❌ Contraindicado en: [condiciones absolutas]\n'
                '⛔ Usar con cautela: [relativas]\n'
                '💊 Alternativa: [qué usar en su lugar]\n'
                '📌 Monitorizar si se decide usar: [parámetro]\n'
                '⚠️ Alerta: [riesgo crítico]'
            : 'TEMPLATE CONTRAINDICAÇÕES:\n'
                '🟥 [FÁRMACO/PROCEDIMENTO — CONTRAINDICAÇÕES]\n'
                '❌ Contraindicado em: [condições absolutas]\n'
                '⛔ Usar com cautela: [relativas]\n'
                '💊 Alternativa: [o que usar no lugar]\n'
                '📌 Monitorar se decidir usar: [parâmetro]\n'
                '⚠️ Alerta: [risco crítico]';

      case PlantaoIntent.diagnostico:
        return isEs
            ? 'TEMPLATE DIAGNÓSTICO:\n'
                '🟥 [ENFERMEDAD/SÍNDROME]\n'
                '🔎 Sospechar si: [criterios clínicos]\n'
                '🧪 Confirmar con: [examen/criterio diagnóstico]\n'
                '⚠️ Gravedad: [señales de alarma]\n'
                '✅ Próximo paso: [conducta inicial]'
            : 'TEMPLATE DIAGNÓSTICO:\n'
                '🟥 [DOENÇA/SÍNDROME]\n'
                '🔎 Suspeitar se: [critérios clínicos]\n'
                '🧪 Confirmar com: [exame/critério diagnóstico]\n'
                '⚠️ Gravidade: [sinais de alarme]\n'
                '✅ Próximo passo: [conduta inicial]';

      case PlantaoIntent.interpretacao:
        return isEs
            ? 'TEMPLATE INTERPRETACIÓN:\n'
                '🟥 INTERPRETACIÓN — [PARÁMETRO/EXAMEN]\n'
                '📖 Significado: [qué indica este resultado]\n'
                '📌 Hallazgos importantes: [valores de alerta]\n'
                '⚠️ Implicaciones clínicas: [qué riesgo representa]\n'
                '✅ Conducta sugerida: [próxima acción]'
            : 'TEMPLATE INTERPRETAÇÃO:\n'
                '🟥 INTERPRETAÇÃO — [PARÂMETRO/EXAME]\n'
                '📖 Significado: [o que indica este resultado]\n'
                '📌 Achados importantes: [valores de alerta]\n'
                '⚠️ Implicações clínicas: [qual risco representa]\n'
                '✅ Conduta sugerida: [próxima ação]';

      case PlantaoIntent.eletrolitos:
        return isEs
            ? 'TEMPLATE ELECTROLITOS:\n'
                '🟥 [TRASTORNO ELECTROLÍTICO — SEVERIDAD]\n'
                '💊 Corrección: [fármaco + dosis + vía + velocidad]\n'
                '📈 Meta terapéutica: [valor objetivo]\n'
                '❌ Evitar: [error clínico / velocidad excesiva]\n'
                '📌 Monitorizar: [ECG + ión sérico + frecuencia]\n'
                '⚠️ Alerta: [riesgo si refractario / complicación]'
            : 'TEMPLATE ELETRÓLITOS:\n'
                '🟥 [DISTÚRBIO ELETROLÍTICO — GRAVIDADE]\n'
                '💊 Correção: [fármaco + dose + via + velocidade]\n'
                '📈 Meta terapêutica: [valor alvo]\n'
                '❌ Evitar: [erro clínico / velocidade excessiva]\n'
                '📌 Monitorar: [ECG + íon sérico + frequência]\n'
                '⚠️ Alerta: [risco se refratário / complicação]';

      case PlantaoIntent.dose:
        return isEs
            ? 'TEMPLATE DOSIS:\n'
                '🟥 [FÁRMACO — CLASE FARMACOLÓGICA]\n'
                '💊 Dosis inicial: [X mg/kg o dose flat]\n'
                '🔄 Ajuste / Titulación: [cómo titular]\n'
                '⛔ Contraindicaciones: [absolutas]\n'
                '📌 Monitorización: [parámetro de seguridad]\n'
                '⚠️ Alerta: [riesgo / interacción crítica]'
            : 'TEMPLATE DOSE:\n'
                '🟥 [FÁRMACO — CLASSE FARMACOLÓGICA]\n'
                '💊 Dose inicial: [X mg/kg ou dose flat]\n'
                '🔄 Ajuste / Titulação: [como titular]\n'
                '⛔ Contraindicações: [absolutas]\n'
                '📌 Monitorização: [parâmetro de segurança]\n'
                '⚠️ Alerta: [risco / interação crítica]';

      case PlantaoIntent.glicemia:
        return isEs
            ? 'TEMPLATE GLUCOSA/CAD:\n'
                '🟥 [TRASTORNO GLICÉMICO — SEVERIDAD]\n'
                '💊 Corrección: [insulina + hidratación + electrolitos]\n'
                '📈 Meta: [glucosa objetivo / bicarbonato]\n'
                '❌ Evitar: [error común / hipoglicemia]\n'
                '📌 Monitorizar: [glucemia + K+ + gasometría + frecuencia]\n'
                '⚠️ Alerta: [riesgo de hipoglicemia / hipocalemia]'
            : 'TEMPLATE GLICEMIA/CAD:\n'
                '🟥 [DISTÚRBIO GLICÊMICO — GRAVIDADE]\n'
                '💊 Correção: [insulina + hidratação + eletrólitos]\n'
                '📈 Meta: [glicemia alvo / bicarbonato]\n'
                '❌ Evitar: [erro comum / hipoglicemia]\n'
                '📌 Monitorar: [glicemia + K+ + gasometria + frequência]\n'
                '⚠️ Alerta: [risco de hipoglicemia / hipocalemia]';

      case PlantaoIntent.ventilacao:
        return isEs
            ? 'TEMPLATE VENTILACIÓN MECÁNICA:\n'
                '🟥 [MODO/INDICACIÓN — VENTILACIÓN]\n'
                '💊 Parámetros iniciales: [VC + FR + PEEP + FiO2]\n'
                '📈 Metas: [SpO2 + pPlat + pH + pO2/FiO2]\n'
                '🔄 Ajuste: [cómo titular parámetros]\n'
                '📌 Monitorizar: [presión plateau + driving pressure]\n'
                '⚠️ Alerta: [barotrauma / hipercapnia permisiva]'
            : 'TEMPLATE VENTILAÇÃO MECÂNICA:\n'
                '🟥 [MODO/INDICAÇÃO — VENTILAÇÃO]\n'
                '💊 Parâmetros iniciais: [VC + FR + PEEP + FiO2]\n'
                '📈 Metas: [SpO2 + pPlat + pH + pO2/FiO2]\n'
                '🔄 Ajuste: [como titular parâmetros]\n'
                '📌 Monitorar: [pressão plateau + driving pressure]\n'
                '⚠️ Alerta: [barotrauma / hipercapnia permissiva]';

      case PlantaoIntent.pcr:
        return isEs
            ? 'TEMPLATE RCP/PCR:\n'
                '🟥 PCR — RITMO: [FV/TVSP/AESP/ASISTOLIA]\n'
                '💊 1ª linha: [RCP 30:2 / choque se desfibrilável + adrenalina]\n'
                '🔄 Alternativa: [amiodarona / atropina conforme ritmo]\n'
                '⛔ Evitar: [interrupciones > 10s / hiperventilación]\n'
                '📌 Monitorizar: [ritmo + causas reversibles: 5H5T]\n'
                '⚠️ Alerta: [causa reversible no tratada]'
            : 'TEMPLATE PCR/RCP:\n'
                '🟥 PCR — RITMO: [FV/TVSP/AESP/ASSISTOLIA]\n'
                '💊 1ª linha: [RCP 30:2 / choque se desfibrilável + adrenalina]\n'
                '🔄 Alternativa: [amiodarona / atropina conforme ritmo]\n'
                '⛔ Evitar: [interrupções > 10s / hiperventilaçâo]\n'
                '📌 Monitorar: [ritmo + causas reversíveis: 5H5T]\n'
                '⚠️ Alerta: [causa reversível não tratada]';

      case PlantaoIntent.choque:
        return isEs
            ? 'TEMPLATE SHOCK:\n'
                '🟥 [TIPO DE SHOCK — SEVERIDAD]\n'
                '💊 Vasopressor/reanimación: [fármaco + dosis + velocidad]\n'
                '🔄 Alternativa: [segundo vasopressor se necesario]\n'
                '📈 Metas: [PAM ≥ 65 + diuresis + lactato]\n'
                '📌 Monitorizar: [PAM + FC + diuresis + lactato seriado]\n'
                '⚠️ Alerta: [shock refractário / causa no tratada]'
            : 'TEMPLATE CHOQUE:\n'
                '🟥 [TIPO DE CHOQUE — GRAVIDADE]\n'
                '💊 Vasopressor/ressuscitação: [fármaco + dose + velocidade]\n'
                '🔄 Alternativa: [segundo vasopressor se necessário]\n'
                '📈 Metas: [PAM ≥ 65 + diurese + lactato]\n'
                '📌 Monitorar: [PAM + FC + diurese + lactato seriado]\n'
                '⚠️ Alerta: [choque refratário / causa não tratada]';

      case PlantaoIntent.sepse:
        return isEs
            ? 'TEMPLATE SEPSIS:\n'
                '🟥 [SEPSIS/SHOCK SÉPTICO — FOCO]\n'
                '💊 Antibiótico: [esquema empírico + dosis + vía]\n'
                '🔄 Alternativa: [si alergia/resistencia]\n'
                '⛔ Evitar: [retrasar antibiótico / foco no drenado]\n'
                '📌 Monitorizar: [lactato + hemocultivos + diuresis + SOFA]\n'
                '⚠️ Alerta: [shock refractario / foco oculto]'
            : 'TEMPLATE SEPSE:\n'
                '🟥 [SEPSE/CHOQUE SÉPTICO — FOCO]\n'
                '💊 Antibiótico: [esquema empírico + dose + via]\n'
                '🔄 Alternativa: [se alergia/resistência]\n'
                '⛔ Evitar: [atrasar antibiótico / foco não drenado]\n'
                '📌 Monitorar: [lactato + hemoculturas + diurese + SOFA]\n'
                '⚠️ Alerta: [choque refratário / foco oculto]';

      case PlantaoIntent.arritmia:
        return isEs
            ? 'TEMPLATE ARRITMIA:\n'
                '🟥 [ARRITMIA — ESTABILIDAD HEMODINÁMICA]\n'
                '💊 1ª línea: [fármaco + dosis OU cardioversión]\n'
                '🔄 Alternativa: [segunda opción]\n'
                '⛔ Contraindicado: [fármaco peligroso en esta arritmia]\n'
                '📌 Monitorizar: [ECG continuo + PA + FC]\n'
                '⚠️ Alerta: [deterioro hemodinámico → cardioversión eléctrica]'
            : 'TEMPLATE ARRITMIA:\n'
                '🟥 [ARRITMIA — ESTABILIDADE HEMODINÂMICA]\n'
                '💊 1ª linha: [fármaco + dose OU cardioversão]\n'
                '🔄 Alternativa: [segunda opção]\n'
                '⛔ Contraindicado: [fármaco perigoso nesta arritmia]\n'
                '📌 Monitorar: [ECG contínuo + PA + FC]\n'
                '⚠️ Alerta: [deterioração hemodinâmica → cardioversão elétrica]';

      case PlantaoIntent.via_aerea:
        return isEs
            ? 'TEMPLATE VÍA AÉREA:\n'
                '🟥 [INDICACIÓN IOT / SECUENCIA RÁPIDA]\n'
                '💊 Inductor: [ketamina/etomidato + dosis] + bloq: [succinilcolina/rocurônio]\n'
                '🔄 Alternativa: [si contraindicación al inductor]\n'
                '⛔ Evitar: [en vía aérea difícil / estómago lleno]\n'
                '📌 Monitorizar: [SpO2 + EtCO2 + PA post-IOT]\n'
                '⚠️ Alerta: [vía aérea difícil → tener plan B/C]'
            : 'TEMPLATE VIA AÉREA:\n'
                '🟥 [INDICAÇÃO IOT / SEQUÊNCIA RÁPIDA]\n'
                '💊 Indutor: [ketamina/etomidato + dose] + bloq: [succinilcolina/rocurônio]\n'
                '🔄 Alternativa: [se contraindicação ao indutor]\n'
                '⛔ Evitar: [em via aérea difícil / estômago cheio]\n'
                '📌 Monitorar: [SpO2 + EtCO2 + PA pós-IOT]\n'
                '⚠️ Alerta: [via aérea difícil → ter plano B/C]';

      case PlantaoIntent.calculo:
        return isEs
            ? 'TEMPLATE CÁLCULO:\n'
                '🟥 [CÁLCULO CLÍNICO — PARÁMETRO]\n'
                '🧮 Fórmula: [fórmula utilizada]\n'
                '🧮 Resultado: **[valor calculado + unidad]**\n'
                '📌 Interpretación: [qué significa ese valor]\n'
                '⚠️ Alerta: [si valor crítico, acción inmediata]'
            : 'TEMPLATE CÁLCULO:\n'
                '🟥 [CÁLCULO CLÍNICO — PARÂMETRO]\n'
                '🧮 Fórmula: [fórmula utilizada]\n'
                '🧮 Resultado: **[valor calculado + unidade]**\n'
                '📌 Interpretação: [o que significa esse valor]\n'
                '⚠️ Alerta: [se valor crítico, ação imediata]';

      case PlantaoIntent.interacao:
        return isEs
            ? 'TEMPLATE INTERACCIÓN MEDICAMENTOSA:\n'
                '🟥 INTERACCIÓN: [FÁRMACO A] + [FÁRMACO B]\n'
                '⚠️ Riesgo: [mecanismo + gravedad]\n'
                '❌ Evitar: [la combinación si riesgo absoluto]\n'
                '🔄 Alternativa: [qué usar en su lugar]\n'
                '📌 Monitorizar si se mantiene: [parámetro]'
            : 'TEMPLATE INTERAÇÃO MEDICAMENTOSA:\n'
                '🟥 INTERAÇÃO: [FÁRMACO A] + [FÁRMACO B]\n'
                '⚠️ Risco: [mecanismo + gravidade]\n'
                '❌ Evitar: [a combinação se risco absoluto]\n'
                '🔄 Alternativa: [o que usar no lugar]\n'
                '📌 Monitorar se mantiver: [parâmetro]';

      case PlantaoIntent.procedimento:
        return isEs
            ? 'TEMPLATE PROCEDIMIENTO:\n'
                '🟥 [PROCEDIMIENTO — INDICACIÓN]\n'
                '💊 Técnica: [pasos clave]\n'
                '🔄 Alternativa: [si no es posible la 1ª opción]\n'
                '⛔ Contraindicado: [cuándo no realizar]\n'
                '📌 Monitorizar: [post-procedimiento]\n'
                '⚠️ Alerta: [complicación principal]'
            : 'TEMPLATE PROCEDIMENTO:\n'
                '🟥 [PROCEDIMENTO — INDICAÇÃO]\n'
                '💊 Técnica: [passos chave]\n'
                '🔄 Alternativa: [se 1ª opção não for possível]\n'
                '⛔ Contraindicado: [quando não realizar]\n'
                '📌 Monitorar: [pós-procedimento]\n'
                '⚠️ Alerta: [complicação principal]';

      // Conduta explícita, sepse, choque, arritmia e geral → template de conduta padrão
      case PlantaoIntent.conduta:
      case PlantaoIntent.geral:
      default:
        return isEs
            ? 'TEMPLATE CONDUCTA ESTÁNDAR:\n'
                '🟥 [DIAGNÓSTICO — CONDUCTA INMEDIATA]\n'
                '💊 1ª línea: [fármaco + dosis + vía]\n'
                '🔄 Alternativa: [si 1ª contraindicada]\n'
                '⛔ Evitar: [contraindicación — omitir si no hay]\n'
                '📌 Monitorizar: [parámetro de seguridad]\n'
                '⚠️ Alerta: [riesgo crítico — omitir si no hay]'
            : 'TEMPLATE CONDUTA PADRÃO:\n'
                '🟥 [DIAGNÓSTICO — CONDUTA IMEDIATA]\n'
                '💊 1ª linha: [fármaco + dose + via]\n'
                '🔄 Alternativa: [se 1ª contraindicada]\n'
                '⛔ Evitar: [contraindicação — omitir se não houver]\n'
                '📌 Monitorar: [parâmetro de segurança]\n'
                '⚠️ Alerta: [risco crítico — omitir se não houver]';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PlantaoIntentResult — resultado da classificação de intenção (Build 224)
// ─────────────────────────────────────────────────────────────────────────────
class PlantaoIntentResult {
  final PlantaoIntent intent;
  final int score;
  final List<String> matchedKeywords;

  const PlantaoIntentResult({
    required this.intent,
    required this.score,
    required this.matchedKeywords,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// _IntentCheck — par interno (intenção, keywords) para o classificador
// ─────────────────────────────────────────────────────────────────────────────
class _IntentCheck {
  final PlantaoIntent intent;
  final List<String> keywords;
  const _IntentCheck(this.intent, this.keywords);
}

// ─────────────────────────────────────────────────────────────────────────────
// PlantaoResponse — objeto estruturado com campos clínicos
//
// Campos:
//   conduta      (🟥) — OBRIGATÓRIO — cabeçalho/título da conduta imediata
//   primeiraLinha(💊) — OBRIGATÓRIO — fármaco principal + dose + via
//   alternativa  (🔄) — opcional — segunda opção terapêutica
//   evitar       (⛔) — opcional — contraindicação quando houver
//   monitorar    (📌) — OBRIGATÓRIO — parâmetro de segurança / próximo passo
//   alerta       (⚠️) — opcional — risco crítico quando houver
// ─────────────────────────────────────────────────────────────────────────────
class PlantaoResponse {
  // ── Campos obrigatórios (invariáveis) ──────────────────────────────────────
  /// 🟥 Título dinâmico — nome da doença/fármaco/síndrome (sem o emoji)
  final String conduta;

  /// 📌 Monitorar / observar — parâmetro principal de segurança / metas
  final String monitorar;

  // ── Campos template CONDUTA (opcionais) ────────────────────────────────────
  /// 💊 Primeira linha terapêutica — fármaco + dose + via + frequência
  final String? primeiraLinha;

  /// 🔄 Alternativa terapêutica — segunda opção terapêutica
  final String? alternativa;

  /// ⛔ Evitar — contraindicação absoluta
  final String? evitar;

  /// ⚠️ Alerta — risco crítico
  final String? alerta;

  // ── Campos templates alternativos (Build 224) ───────────────────────────────
  /// 📈 Metas / valores esperados — alvos terapêuticos
  final String? metas;

  /// ✅ Próximo passo — ação após atingir/não atingir meta
  final String? proxPasso;

  /// ❌ Evitar (alternativo a ⛔) — erro clínico / proibição
  final String? evitarAlt;

  /// 🔎 Suspeitar se — critérios diagnósticos
  final String? suspeitar;

  /// 🧪 Confirmar com / diluição — exame diagnóstico ou preparo de ampola
  final String? confirmar;

  /// 🧮 Cálculo / velocidade — resultado final em negrito
  final String? calculo;

  /// 📖 Significado — interpretação de resultado
  final String? significado;

  const PlantaoResponse({
    required this.conduta,
    required this.monitorar,
    // Conduta
    this.primeiraLinha,
    this.alternativa,
    this.evitar,
    this.alerta,
    // Templates alternativos
    this.metas,
    this.proxPasso,
    this.evitarAlt,
    this.suspeitar,
    this.confirmar,
    this.calculo,
    this.significado,
  });

  /// Número de campos opcionais ausentes (para log hiddenFields)
  int get hiddenFields {
    int count = 0;
    if (primeiraLinha == null || primeiraLinha!.isEmpty) count++;
    if (alternativa == null || alternativa!.isEmpty) count++;
    if (evitar == null || evitar!.isEmpty) count++;
    if (alerta == null || alerta!.isEmpty) count++;
    if (metas == null || metas!.isEmpty) count++;
    if (proxPasso == null || proxPasso!.isEmpty) count++;
    if (evitarAlt == null || evitarAlt!.isEmpty) count++;
    if (suspeitar == null || suspeitar!.isEmpty) count++;
    if (confirmar == null || confirmar!.isEmpty) count++;
    if (calculo == null || calculo!.isEmpty) count++;
    if (significado == null || significado!.isEmpty) count++;
    return count;
  }

  /// Retorna true se todos os campos obrigatórios têm conteúdo
  bool get isComplete =>
      conduta.trim().isNotEmpty &&
      monitorar.trim().isNotEmpty;

  @override
  String toString() =>
      'PlantaoResponse(conduta: "$conduta", primeiraLinha: "$primeiraLinha", '
      'alternativa: "$alternativa", evitar: "$evitar", '
      'monitorar: "$monitorar", alerta: "$alerta")';
}

// ─────────────────────────────────────────────────────────────────────────────
// _EmojiBlock — representação interna de um bloco emoji durante parsing
// ─────────────────────────────────────────────────────────────────────────────
class _EmojiBlock {
  final String emoji;       // âncora: '🟥', '💊', '🔄', '⛔', '📌', '⚠️'
  final List<String> lines; // linhas de conteúdo deste bloco

  _EmojiBlock({required this.emoji, required this.lines});

  /// Texto consolidado do bloco (sem o emoji âncora da primeira linha)
  String get text => lines.join('\n').trim();
}

// ─────────────────────────────────────────────────────────────────────────────
// PlantaoParser — extrai PlantaoResponse de texto via emoji-anchors
//
// Estratégia:
//   1. Divide texto em linhas
//   2. Ignora linhas iniciando com '[' (segurança)
//   3. Detecta âncoras emoji para delimitar blocos
//   4. Consolida blocos em campos de PlantaoResponse
//   5. Aplica fallback se campos obrigatórios estiverem vazios
// ─────────────────────────────────────────────────────────────────────────────
class PlantaoParser {
  PlantaoParser._(); // 100% estático

  // Âncoras — template conduta (ordem canônica original)
  static const _kConduta      = '🟥';
  static const _kPrimeira     = '💊';
  static const _kAlternativa  = '🔄';
  static const _kEvitar       = '⛔';
  static const _kMonitorar    = '📌';
  static const _kAlerta       = '⚠️';

  // Âncoras — templates alternativos (Build 224)
  static const _kMetas        = '📈'; // valores esperados / metas
  static const _kProxPasso    = '✅'; // próximo passo
  static const _kEvitarAlt    = '❌'; // alternativa a ⛔
  static const _kSuspeitar    = '🔎'; // suspeitar se / diagnóstico
  static const _kConfirmar    = '🧪'; // confirmar com / diluição
  static const _kCalculo      = '🧮'; // cálculo / velocidade
  static const _kSignificado  = '📖'; // significado / interpretação

  // Todas as âncoras válidas (Build 224 — ordem de prioridade de matching)
  static const _kAllAnchors = [
    _kConduta, _kPrimeira, _kAlternativa, _kEvitar,
    _kMonitorar, _kAlerta,
    // Templates alternativos
    _kMetas, _kProxPasso, _kEvitarAlt, _kSuspeitar,
    _kConfirmar, _kCalculo, _kSignificado,
  ];

  /// Detecta qual âncora está no início da linha (null se nenhuma)
  static String? _detectAnchor(String line) {
    final t = line.trim();
    for (final anchor in _kAllAnchors) {
      if (t.startsWith(anchor)) return anchor;
    }
    return null;
  }

  /// Extrai o texto de conteúdo de uma linha de cabeçalho (remove a âncora emoji)
  static String _extractContent(String line, String anchor) {
    final t = line.trim();
    if (t.startsWith(anchor)) {
      return t.substring(anchor.length).trim();
    }
    return t;
  }

  /// Verifica se a linha deve ser ignorada por segurança
  static bool _shouldSkip(String line) {
    final t = line.trim();
    if (t.isEmpty) return false;
    // Segurança: nunca renderizar linhas com marcadores técnicos
    if (t.startsWith('[')) return true;
    return false;
  }

  /// Parse principal: texto → PlantaoResponse
  ///
  /// Retorna null se os campos obrigatórios não puderem ser extraídos.
  static PlantaoResponse? parse(String rawText) {
    if (rawText.trim().isEmpty) return null;

    final lines = rawText.split('\n');

    // ── Passo 1: agrupa linhas em blocos por âncora emoji ─────────────────
    final Map<String, _EmojiBlock> blocks = {};
    String? currentAnchor;
    final List<String> currentLines = [];

    void flushBlock() {
      if (currentAnchor == null || currentLines.isEmpty) return;
      // Consolida: primeira linha tem a âncora, demais são continuação
      blocks[currentAnchor!] = _EmojiBlock(
        emoji: currentAnchor!,
        lines: List.from(currentLines),
      );
      currentLines.clear();
      currentAnchor = null;
    }

    for (final line in lines) {
      if (_shouldSkip(line)) continue;

      final anchor = _detectAnchor(line);

      if (anchor != null) {
        // Nova âncora detectada — flush bloco anterior
        flushBlock();
        currentAnchor = anchor;
        final content = _extractContent(line, anchor);
        currentLines.add(content);
      } else if (currentAnchor != null) {
        // Continuação do bloco atual
        final t = line.trim();
        if (t.isNotEmpty) {
          currentLines.add(t);
        }
      }
      // Linhas antes de qualquer âncora são ignoradas
    }
    flushBlock(); // flush do último bloco

    // ── Passo 2: extrai campos (Build 224: template-agnóstico) ───────────────
    final condutaBlock     = blocks[_kConduta];
    final primeiraBlock    = blocks[_kPrimeira];
    final alternativaBlock = blocks[_kAlternativa];
    final evitarBlock      = blocks[_kEvitar];
    final monitorarBlock   = blocks[_kMonitorar];
    final alertaBlock      = blocks[_kAlerta];
    // Templates alternativos
    final metasBlock       = blocks[_kMetas];
    final proxPassoBlock   = blocks[_kProxPasso];
    final evitarAltBlock   = blocks[_kEvitarAlt];
    final suspeitarBlock   = blocks[_kSuspeitar];
    final confirmarBlock   = blocks[_kConfirmar];
    final calculoBlock     = blocks[_kCalculo];
    final significadoBlock = blocks[_kSignificado];

    // Campos obrigatórios: conduta (🟥) sempre, monitorar (📌) sempre
    final condutaText   = condutaBlock?.text ?? '';
    // 📌 pode ser substituído por 📈 ou ✅ em alguns templates
    final monitorarText = monitorarBlock?.text
        ?? metasBlock?.text
        ?? proxPassoBlock?.text
        ?? '';

    // Se campos obrigatórios estiverem vazios, não podemos construir o objeto
    if (condutaText.isEmpty || monitorarText.isEmpty) {
      debugPrint('[PLANTAO_PARSER] parse falhou: campos obrigatórios ausentes '
          '(conduta=${condutaText.isNotEmpty} '
          'monitorar/metas=${monitorarText.isNotEmpty})');
      return null;
    }

    // Helper inline
    String? _opt(String? t) => (t?.isNotEmpty == true) ? t : null;

    return PlantaoResponse(
      conduta:       condutaText,
      monitorar:     monitorarText,
      // Template conduta
      primeiraLinha: _opt(primeiraBlock?.text),
      alternativa:   _opt(alternativaBlock?.text),
      evitar:        _opt(evitarBlock?.text),
      alerta:        _opt(alertaBlock?.text),
      // Templates alternativos
      metas:         _opt(metasBlock?.text),
      proxPasso:     _opt(proxPassoBlock?.text),
      evitarAlt:     _opt(evitarAltBlock?.text),
      suspeitar:     _opt(suspeitarBlock?.text),
      confirmar:     _opt(confirmarBlock?.text),
      calculo:       _opt(calculoBlock?.text),
      significado:   _opt(significadoBlock?.text),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PlantaoValidator — valida estrutura mínima da resposta Plantão (Build 224)
//
// Build 224: validação expandida para templates dinâmicos.
// Regras base (invariáveis):
//   1. Primeira linha não-vazia deve iniciar com 🟥
//   2. Mínimo de 3 linhas de conteúdo real (templates mais curtos permitidos)
//   3. Máximo de 18 linhas de conteúdo real (templates mais ricos)
//
// Regras dinâmicas por template:
//   - Template conduta/dose: exige 💊 E 📌
//   - Outros templates: exige ao menos 2 emojis âncora válidos (além de 🟥)
// ─────────────────────────────────────────────────────────────────────────────
class PlantaoValidator {
  PlantaoValidator._(); // 100% estático

  // Emojis âncora válidos em todos os templates (Build 224)
  static const _kAllValidAnchors = [
    '🟥', '💊', '🔄', '⛔', '📌', '⚠️',
    '📈', '✅', '❌', '🔎', '🧪', '🧮', '📖',
  ];

  /// Valida a resposta textual bruta (pós-sanitize, pré-parse)
  /// Retorna true se a estrutura mínima estiver correta.
  ///
  /// Build 224: modo relaxado — aceita templates dinâmicos além do conduta.
  static bool isValid(String text) {
    if (text.trim().isEmpty) return false;

    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) return false;

    // ── Regra 1: primeira linha inicia com 🟥 (invariável) ────────────────
    if (!lines.first.startsWith('🟥')) return false;

    // ── Regra 2-3: limites de linhas (expandidos no Build 224) ───────────
    final contentLineCount = lines.length;
    if (contentLineCount < 3) return false;
    if (contentLineCount > 18) return false;

    // ── Regra 4: tem ao menos 2 emojis âncora válidos (incluindo 🟥) ─────
    final anchorCount = lines
        .where((l) => _kAllValidAnchors.any((a) => l.startsWith(a)))
        .length;
    if (anchorCount < 2) return false;

    return true;
  }

  /// Valida um PlantaoResponse já parseado
  static bool isValidResponse(PlantaoResponse r) {
    return r.conduta.trim().isNotEmpty &&
        r.monitorar.trim().isNotEmpty;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PlantaoRepair — reorganiza blocos para a ordem canônica
//
// IMPORTANTE: NUNCA inventa conteúdo clínico.
// Apenas:
//   • reorganiza blocos existentes para a ordem correta
//   • remove linhas vazias excessivas
//   • elimina blocos âncora duplicados (mantém o primeiro de cada)
//   • normaliza espaçamentos
//   • remove linhas iniciando com '[' (segurança)
//
// Ordem canônica de saída:
//   🟥 → 💊 → 🔄 → ⛔ → 📌 → ⚠️
// ─────────────────────────────────────────────────────────────────────────────
class PlantaoRepair {
  PlantaoRepair._(); // 100% estático

  // Build 224: ordem canônica expandida com todos os emojis de template
  static const _kCanonicalOrder = [
    '🟥',  // título — sempre primeiro
    '💊',  // 1ª linha / dose / correção
    '🔄',  // alternativa / titulação
    '⛔',  // evitar / contraindicação
    '🔎',  // suspeitar se (diagnóstico)
    '🧪',  // confirmar com / diluição
    '🧮',  // cálculo / velocidade
    '📖',  // significado / interpretação
    '📈',  // metas / valores esperados
    '❌',  // evitar (alternativo)
    '📌',  // monitorar / observar — sempre penúltimo
    '✅',  // próximo passo
    '⚠️', // alerta — sempre último
  ];

  /// Aplica reparo estrutural na resposta textual
  ///
  /// Retorna (repairedText, wasRepaired, removedLines, orderFixed)
  static ({String text, bool repaired, int removedLines, bool orderFixed})
      repair(String rawText) {
    if (rawText.trim().isEmpty) {
      return (text: rawText, repaired: false, removedLines: 0, orderFixed: false);
    }

    final originalLines = rawText.split('\n');
    int removedLines = 0;

    // ── Passo 1: limpa linhas inseguras e vazias excessivas ───────────────
    final filteredLines = <String>[];
    int consecutiveEmpty = 0;

    for (final line in originalLines) {
      final t = line.trim();

      // Segurança: remove linhas iniciando com '['
      if (t.startsWith('[')) {
        removedLines++;
        continue;
      }

      // Remove linhas excessivamente vazias (máx 1 consecutiva)
      if (t.isEmpty) {
        consecutiveEmpty++;
        if (consecutiveEmpty <= 1) {
          filteredLines.add('');
        } else {
          removedLines++;
        }
        continue;
      }

      consecutiveEmpty = 0;
      filteredLines.add(line);
    }

    // ── Passo 2: agrupa linhas em blocos por âncora emoji ─────────────────
    // Mesmo algoritmo do PlantaoParser mas mantemos o texto original das linhas
    final Map<String, List<String>> blockLines = {};
    final List<String> preAnchorLines = []; // linhas antes de qualquer âncora
    String? currentAnchor;
    final List<String> currentContent = [];

    void flushCurrentBlock() {
      if (currentAnchor == null) return;
      if (!blockLines.containsKey(currentAnchor!)) {
        // Só mantém a primeira ocorrência de cada âncora (deduplication)
        blockLines[currentAnchor!] = List.from(currentContent);
      } else {
        // Bloco duplicado: descarta silenciosamente, conta como removed
        removedLines += currentContent.length;
      }
      currentContent.clear();
      currentAnchor = null;
    }

    bool foundFirstAnchor = false;

    for (final line in filteredLines) {
      final t = line.trim();
      if (t.isEmpty) {
        if (currentAnchor != null) {
          // Linhas vazias dentro de um bloco são ignoradas
        }
        continue;
      }

      String? anchor;
      for (final a in _kCanonicalOrder) {
        if (t.startsWith(a)) {
          anchor = a;
          break;
        }
      }

      if (anchor != null) {
        flushCurrentBlock();
        foundFirstAnchor = true;
        currentAnchor = anchor;
        currentContent.add(line);
      } else if (currentAnchor != null) {
        currentContent.add(line);
      } else if (!foundFirstAnchor) {
        preAnchorLines.add(line);
      }
      // Linhas fora de qualquer bloco após a primeira âncora são descartadas
    }
    flushCurrentBlock();

    // ── Passo 3: detecta se a ordem original estava errada ────────────────
    bool orderFixed = false;
    final originalOrder = <String>[];
    for (final line in filteredLines) {
      final t = line.trim();
      for (final a in _kCanonicalOrder) {
        if (t.startsWith(a)) {
          originalOrder.add(a);
          break;
        }
      }
    }

    final canonicalPresent = _kCanonicalOrder
        .where((a) => blockLines.containsKey(a))
        .toList();

    // Filtra originalOrder para só os que existem
    final originalPresent = originalOrder
        .where((a) => blockLines.containsKey(a))
        .toList();

    // Verifica se a ordem original difere da canônica
    if (originalPresent.length == canonicalPresent.length) {
      for (int i = 0; i < originalPresent.length; i++) {
        if (originalPresent[i] != canonicalPresent[i]) {
          orderFixed = true;
          break;
        }
      }
    }

    // ── Passo 4: reconstrói na ordem canônica ─────────────────────────────
    final output = StringBuffer();

    for (final anchor in _kCanonicalOrder) {
      final block = blockLines[anchor];
      if (block == null || block.isEmpty) continue;
      for (final line in block) {
        output.writeln(line);
      }
    }

    final repairedText = output.toString().trimRight();

    // ── Passo 5: detecta se houve reparo real ─────────────────────────────
    final originalClean = filteredLines
        .where((l) => l.trim().isNotEmpty)
        .join('\n');
    final repairedClean = repairedText
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .join('\n');

    final wasRepaired = (removedLines > 0) ||
        orderFixed ||
        (originalClean != repairedClean);

    return (
      text: repairedText,
      repaired: wasRepaired,
      removedLines: removedLines,
      orderFixed: orderFixed,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PlantatoPipeline — orquestra o pipeline completo (Build 193)
//
// Entrada:  texto bruto pós-sanitizeResponse()
// Saída:    PlantaoPipelineResult com objeto estruturado + métricas de log
//
// Deve ser chamado APENAS em chunk.isDone (nunca durante streaming).
// ─────────────────────────────────────────────────────────────────────────────
class PlantatoPipelineResult {
  final PlantaoResponse? response; // null se o pipeline falhou
  final bool valid;
  final bool repaired;
  final int removedLines;
  final int hiddenFields;
  final bool orderFixed;
  final String fallbackText; // texto original para fallback se response == null

  const PlantatoPipelineResult({
    required this.response,
    required this.valid,
    required this.repaired,
    required this.removedLines,
    required this.hiddenFields,
    required this.orderFixed,
    required this.fallbackText,
  });
}

class PlantatoPipeline {
  PlantatoPipeline._(); // 100% estático

  /// Executa o pipeline completo: repair → validate → parse
  ///
  /// Retorna PlantatoPipelineResult.
  /// Se o pipeline falhar (texto não estruturado), response será null
  /// e fallbackText conterá o texto original para renderização de fallback.
  static PlantatoPipelineResult run(String sanitizedText) {
    if (sanitizedText.trim().isEmpty) {
      return PlantatoPipelineResult(
        response: null,
        valid: false,
        repaired: false,
        removedLines: 0,
        hiddenFields: 0,
        orderFixed: false,
        fallbackText: sanitizedText,
      );
    }

    // ── Camada 1: PlantaoRepair ────────────────────────────────────────────
    final repairResult = PlantaoRepair.repair(sanitizedText);
    final repairedText = repairResult.text;

    // ── Camada 2: PlantaoValidator ─────────────────────────────────────────
    final isValid = PlantaoValidator.isValid(repairedText);

    // ── Camada 3: PlantaoParser ────────────────────────────────────────────
    PlantaoResponse? response;
    int hiddenFields = 0;

    if (isValid || repairedText.contains('🟥')) {
      // Tenta parsear mesmo se a validação falhou (resposta parcialmente válida)
      response = PlantaoParser.parse(repairedText);
      hiddenFields = response?.hiddenFields ?? 0;
    }

    // ── Log [PLANTAO_VALIDATOR] ────────────────────────────────────────────
    debugPrint('[PLANTAO_VALIDATOR] '
        'valid=$isValid '
        'repaired=${repairResult.repaired} '
        'removedLines=${repairResult.removedLines} '
        'hiddenFields=$hiddenFields '
        'orderFixed=${repairResult.orderFixed}');

    if (response != null) {
      debugPrint('[PLANTAO_VALIDATOR] parse=ok '
          'conduta="${response.conduta.length > 40 ? response.conduta.substring(0, 40) : response.conduta}…"');
    } else {
      debugPrint('[PLANTAO_VALIDATOR] parse=null — fallback para renderização de texto');
    }

    return PlantatoPipelineResult(
      response: response,
      valid: isValid,
      repaired: repairResult.repaired,
      removedLines: repairResult.removedLines,
      hiddenFields: hiddenFields,
      orderFixed: repairResult.orderFixed,
      fallbackText: sanitizedText,
    );
  }
}
