// ══════════════════════════════════════════════════════════════════════════════
// plantao_pipeline.dart — Plantão Pipeline v3.0 (Build 225)
//
// RESPONSABILIDADES:
//   • PlantaoIntentEngine    — engine multidimensional Build 225 (tema+contexto+intenção+complexidade)
//   • PlantaoIntentClassifier — shim Build 224 (retrocompatibilidade — não remover)
//   • PlantaoResponse  — data class estruturada com campos clínicos dinâmicos
//   • PlantaoParser    — extrai PlantaoResponse de texto validado via emoji-anchors
//   • PlantaoValidator — valida estrutura mínima por template de intenção
//   • PlantaoRepair    — reorganiza blocos, elimina duplicatas, normaliza espaços
//                        (NUNCA inventa conteúdo clínico)
//
// PIPELINE COMPLETO (Build 225):
//   lastUserMessage
//     → PlantaoIntentEngine.analyze()       [multidimensional: tema+ctx+intent+complexity]
//       → matchers paralelos: DoseMatcher, InfusionMatcher, MonitoringMatcher, ...
//       → DrugMatcher (entidade/tema) + ContextMatcher (cenário clínico)
//       → ComplexityResolver → PlantaoQueryAnalysis
//     → buildIntentMandateV2()              [mandato rico com topic+subtitle+context+complexity]
//     → intentMandate injetado no system_instruction (gateway — anti-leak)
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
//   [PLANTAO_ANALYSIS] topic=Amiodarona subtitle=Antiarrítmico classe III
//                      primaryIntent=dose secondaryIntent=contraindicacao
//                      context=pcr complexity=critica confidence=0.92
//                      matched=[dose, amiodarona, pcr]
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart' show debugPrint;

// ══════════════════════════════════════════════════════════════════════════════
// BUILD 225 — INTENT ENGINE CLÍNICO MULTIDIMENSIONAL
//
// Modelo mental:
//   userMessage → tema + contexto + intenção + complexidade → mandato rico
//
// Princípio de resolução de conflitos:
//   1. Intenção explícita do usuário (palavras de ação: dose, monitorar, dilui)
//   2. Entidade clínica / fármaco (amiodarona, noradrenalina, vancomicina)
//   3. Contexto clínico grave (pcr, choque, sepse, via aérea)
//   4. Complexidade derivada do contexto e sinais de gravidade
// ══════════════════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────────────────────
// PlantaoContext — contexto clínico do cenário (Build 225)
// ─────────────────────────────────────────────────────────────────────────────
enum PlantaoContext {
  pcr,            // parada cardiorrespiratória / RCP / ACLS
  arritmia,       // arritmias / cardioversão / antiarrítmicos
  choque,         // choque (qualquer tipo) / vasopressores
  sepse,          // sepse / infecção grave / bundle
  viaAerea,       // intubação / IOT / RSI / via aérea difícil
  ventilacao,     // ventilação mecânica / parâmetros
  eletrolitos,    // distúrbios eletrolíticos / reposição iônica
  glicemia,       // glicemia / CAD / DKA / hipoglicemia
  renal,          // injúria renal / ajuste de dose / ClCr
  cardiovascular, // IAM / TEP / IC / SCA / crise hipertensiva
  neurologia,     // AVC / convulsão / meningite / rebaixamento
  toxicologia,    // intoxicação / antídoto / overdose
  trauma,         // trauma / cirurgia / hemorragia
  farmacologia,   // farmacologia clínica geral / interação / CI
  geral,          // contexto não especificado
}

// ─────────────────────────────────────────────────────────────────────────────
// PlantaoComplexity — complexidade clínica da pergunta (Build 225)
// ─────────────────────────────────────────────────────────────────────────────
enum PlantaoComplexity {
  simples,        // pergunta curta geral / definição / dose isolada sem gravidade
  intermediaria,  // monitorização / ajuste / contraindicações / eletrólitos estáveis
  critica,        // PCR / choque / sepse / via aérea / instabilidade hemodinâmica
}

// ─────────────────────────────────────────────────────────────────────────────
// PlantaoQueryAnalysis — resultado multidimensional do IntentEngine (Build 225)
//
// Produto final de PlantaoIntentEngine.analyze().
// Contém todos os eixos de análise: tema, subtítulo, intenção primária/secundária,
// contexto clínico, complexidade, confiança e keywords para auditoria.
//
// Compatibilidade: PlantaoIntentResult (Build 224) permanece funcional.
// PlantaoQueryAnalysis é a evolução que o ai_gateway_service.dart usa a partir
// da Build 225 para montar o mandato rico.
// ─────────────────────────────────────────────────────────────────────────────
class PlantaoQueryAnalysis {
  /// Tema principal — nome do fármaco/doença/síndrome identificado.
  /// Ex: 'Amiodarona', 'Hipocalemia', 'Noradrenalina', 'PCR'
  final String clinicalTopic;

  /// Subtítulo clínico — classe/categoria farmacológica ou contexto breve.
  /// Ex: 'Antiarrítmico classe III', 'Distúrbio eletrolítico', 'Vasopressor α1'
  final String clinicalSubtitle;

  /// Intenção primária — ação clínica dominante identificada pelo engine.
  final PlantaoIntent primaryIntent;

  /// Intenção secundária — ação clínica de suporte (pode ser null).
  final PlantaoIntent? secondaryIntent;

  /// Contexto clínico — cenário em que a pergunta se insere.
  final PlantaoContext clinicalContext;

  /// Complexidade clínica — derivada de contexto + sinais de gravidade.
  final PlantaoComplexity complexity;

  /// Keywords que dispararam a classificação (para auditoria/log).
  final List<String> matchedKeywords;

  /// Confiança do engine (0.0–1.0) — baseada em score total normalizado.
  final double confidence;

  const PlantaoQueryAnalysis({
    required this.clinicalTopic,
    required this.clinicalSubtitle,
    required this.primaryIntent,
    this.secondaryIntent,
    required this.clinicalContext,
    required this.complexity,
    required this.matchedKeywords,
    required this.confidence,
  });

  /// Converte para PlantaoIntentResult (retrocompatibilidade com Build 224).
  PlantaoIntentResult toIntentResult() => PlantaoIntentResult(
        intent: primaryIntent,
        score: matchedKeywords.length,
        matchedKeywords: matchedKeywords,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// _MatcherResult — resultado interno de cada matcher modular (Build 225)
// ─────────────────────────────────────────────────────────────────────────────
class _MatcherResult {
  final PlantaoIntent? intent;
  final PlantaoContext? context;
  final String topic;
  final String subtitle;
  final int score;
  final List<String> matched;

  const _MatcherResult({
    this.intent,
    this.context,
    this.topic = '',
    this.subtitle = '',
    required this.score,
    required this.matched,
  });

  bool get hasMatch => score > 0;
}

// ─────────────────────────────────────────────────────────────────────────────
// _IntentMatcher — base de todos os matchers modulares (Build 225)
//
// Cada matcher especializado define _keywords e opcionalmente sobrescreve
// _contextKeywords, topic e subtitle. O método match() executa a contagem
// e retorna _MatcherResult.
// ─────────────────────────────────────────────────────────────────────────────
abstract class _IntentMatcher {
  PlantaoIntent get intent;
  List<String> get keywords;
  PlantaoContext get defaultContext => PlantaoContext.farmacologia;
  String get defaultTopic => '';
  String get defaultSubtitle => '';

  _MatcherResult match(String msg) {
    final matched = keywords.where((kw) => msg.contains(kw)).toList();
    return _MatcherResult(
      intent: intent,
      context: defaultContext,
      topic: defaultTopic,
      subtitle: defaultSubtitle,
      score: matched.length,
      matched: matched,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Matchers de INTENÇÃO (o que o usuário quer saber)
// ─────────────────────────────────────────────────────────────────────────────

class DoseMatcher extends _IntentMatcher {
  @override PlantaoIntent get intent => PlantaoIntent.dose;
  @override PlantaoContext get defaultContext => PlantaoContext.farmacologia;
  @override List<String> get keywords => const [
    'dose', 'dosagem', 'quanto', 'mg/kg', 'posologia', 'dosis',
    'qual a dose', 'dose de', 'dose do', 'dose da', 'dosis de',
    'quantos mg', 'quantos mcg', 'qual dose', 'dose máxima',
    'dose mínima', 'dose de ataque', 'dose de manutenção',
    'dose em', 'dose para', 'dose na',
  ];
}

class InfusionMatcher extends _IntentMatcher {
  @override PlantaoIntent get intent => PlantaoIntent.infusao;
  @override PlantaoContext get defaultContext => PlantaoContext.farmacologia;
  @override List<String> get keywords => const [
    'infusão', 'infusao', 'velocidade', 'ml/h', 'mcg/kg/min', 'mcg/min',
    'drip', 'bic', 'bomba infusora', 'titulação', 'titular',
    'calcular infusão', 'como calcular a infusão', 'calcular velocidade',
    'taxa de infusão', 'mL por hora',
  ];
}

class DiluitionMatcher extends _IntentMatcher {
  @override PlantaoIntent get intent => PlantaoIntent.diluicao;
  @override PlantaoContext get defaultContext => PlantaoContext.farmacologia;
  @override List<String> get keywords => const [
    'dilui', 'diluição', 'preparo', 'preparar', 'ampola', 'ampolas',
    'como preparar', 'como dilui', 'prepara', 'reconstituir',
    'gota', 'gotejo', 'gotejamento', 'gotejar', 'macrogotas', 'microgotas',
    'equipo de soro', 'equipo de infusão',
  ];
}

class MonitoringMatcher extends _IntentMatcher {
  @override PlantaoIntent get intent => PlantaoIntent.monitorizacao;
  @override PlantaoContext get defaultContext => PlantaoContext.farmacologia;
  @override List<String> get keywords => const [
    'monitorar', 'monitorizar', 'monitorização', 'monitoreo',
    'o que observar', 'o que monitorar', 'parâmetros', 'parametros',
    'metas', 'meta terapêutica', 'valores esperados',
    'alvo', 'alvos', 'target', 'frequência de monitorar',
    'quando preocupar', 'sinal de gravidade', 'sinais de gravidade',
    'monitorar ecg', 'monitorar potassio', 'vigiar',
  ];
}

class ContraindicationMatcher extends _IntentMatcher {
  @override PlantaoIntent get intent => PlantaoIntent.contraindicacao;
  @override PlantaoContext get defaultContext => PlantaoContext.farmacologia;
  @override List<String> get keywords => const [
    // Variantes PT com e sem acentuação (substring matching seguro)
    'contraindicaç', 'contraindicado', 'contra-indica',
    'contraindicaciones', 'quando não usar', 'quando não dar', 'quando evitar',
    'quem não pode', 'não pode usar', 'evitar em',
    'contraindicado em', 'contraindicada', 'proibido em',
    'não indicado', 'não recomendado',
  ];
}

class DiagnosisMatcher extends _IntentMatcher {
  @override PlantaoIntent get intent => PlantaoIntent.diagnostico;
  @override PlantaoContext get defaultContext => PlantaoContext.geral;
  @override List<String> get keywords => const [
    'diagnóstico', 'diagnosticar', 'como diagnosticar', 'suspeitar',
    'como suspeitar', 'criterios', 'critérios',
    'diferencial', 'diagnóstico diferencial', 'como identificar',
    'sinais', 'sintomas', 'apresentação', 'quadro clínico',
    'como reconhecer', 'diagnose', 'suspeita de', 'pensar em',
  ];
}

class InterpretationMatcher extends _IntentMatcher {
  @override PlantaoIntent get intent => PlantaoIntent.interpretacao;
  @override PlantaoContext get defaultContext => PlantaoContext.geral;
  @override List<String> get keywords => const [
    'interpretar', 'interpretação', 'o que significa', 'o que quer dizer',
    'interpretar resultado', 'valor alto', 'valor baixo', 'resultado de',
    'resultado do', 'laudo', 'exame alterado', 'analisar',
    'o que fazer com', 'como interpretar', 'analizar',
  ];
}

class InteractionMatcher extends _IntentMatcher {
  @override PlantaoIntent get intent => PlantaoIntent.interacao;
  @override PlantaoContext get defaultContext => PlantaoContext.farmacologia;
  @override List<String> get keywords => const [
    'interação', 'interaçao', 'interação medicamentosa',
    'pode usar com', 'pode dar com', 'combinar', 'associar',
    'risco de interação', 'incompatível', 'incompatibilidade',
    'junto com', 'associação de', 'combinar com',
  ];
}

class CalculationMatcher extends _IntentMatcher {
  @override PlantaoIntent get intent => PlantaoIntent.calculo;
  @override PlantaoContext get defaultContext => PlantaoContext.geral;
  @override List<String> get keywords => const [
    'calcular', 'cálculo', 'fórmula', 'calculo', 'formula',
    'clcr', 'cockcroft', 'tfg', 'ckd-epi', 'egfr',
    'clearance de creatinina', 'ajuste renal',
    'ânion gap', 'anion gap', 'be', 'base excess',
    'osmolaridade', 'água livre', 'déficit de sódio',
    'peso ideal', 'imc', 'bmi', 'score',
  ];
}

class ProcedureMatcher extends _IntentMatcher {
  @override PlantaoIntent get intent => PlantaoIntent.procedimento;
  @override PlantaoContext get defaultContext => PlantaoContext.trauma;
  @override List<String> get keywords => const [
    'procedimento', 'técnica', 'como fazer', 'como realizar',
    'punção', 'dreno', 'toracocentese', 'paracentese', 'artrocentese',
    'acesso venoso central', 'cateter', 'linha arterial',
    'dissecção venosa', 'cricotireoidostomia', 'pericardiocentese',
    'marca-passo', 'drenagem', 'biópsia', 'punção lombar',
  ];
}

class ConductMatcher extends _IntentMatcher {
  @override PlantaoIntent get intent => PlantaoIntent.conduta;
  @override PlantaoContext get defaultContext => PlantaoContext.geral;
  @override List<String> get keywords => const [
    'conduta', 'tratar', 'tratamento', 'como tratar', 'manejo',
    'protocolo de', 'o que fazer', 'primeira linha',
    'abordagem', 'manejo de', 'conduta em', 'tratar com',
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Matchers de CONTEXTO CLÍNICO (cenário/setting — entidade separada da intenção)
// ─────────────────────────────────────────────────────────────────────────────

class ElectrolyteMatcher extends _IntentMatcher {
  @override PlantaoIntent get intent => PlantaoIntent.eletrolitos;
  @override PlantaoContext get defaultContext => PlantaoContext.eletrolitos;
  @override List<String> get keywords => const [
    'hipocalemia', 'hipercalemia', 'hypokale', 'hyperkale',
    'hiponatremia', 'hipernatremia', 'hyponatremia',
    'hipocalcemia', 'hipercalcemia', 'hypocalcemia',
    'hipomagnesemia', 'hipofosfatemia',
    'potássio', 'potassio', 'sódio', 'sodio', 'cálcio', 'calcio',
    'magnésio', 'magnesio', 'fósforo', 'fosforo', 'cloro', 'cloreto',
    'eletrólito', 'eletrolito', 'distúrbio eletrolítico',
    'reposição de', 'reposição ev', 'repor potássio', 'repor sódio',
    'kcl', 'k+', 'na+', 'ca2+', 'mg2+',
  ];
}

class GlycemiaMatcher extends _IntentMatcher {
  @override PlantaoIntent get intent => PlantaoIntent.glicemia;
  @override PlantaoContext get defaultContext => PlantaoContext.glicemia;
  @override List<String> get keywords => const [
    'cad', 'cetoacidose', 'cetoacidose diabética', 'dka', 'ehh',
    'estado hiperosmolar', 'insulina ev', 'insulina endovenosa',
    'protocolo insulina', 'glicemia', 'hiperglicemia',
    'glicose ev', 'controle glicêmico', 'glicemia capilar',
    'insulinoterapia',
  ];
}

class VentilationMatcher extends _IntentMatcher {
  @override PlantaoIntent get intent => PlantaoIntent.ventilacao;
  @override PlantaoContext get defaultContext => PlantaoContext.ventilacao;
  @override List<String> get keywords => const [
    'ventilação mecânica', 'vm', 'ventilador',
    'peep', 'pressão plateau', 'volume corrente', 'fio2',
    'modo ventilatório', 'pressão suporte', 'fr ventilatória',
    'desmame', 'extubação', 'driving pressure', 'plateau',
    'modo controlado', 'modo assistido', 'ciclado',
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// _DrugMatcher — reconhece entidades farmacológicas (tema/subtítulo)
//
// NÃO define intenção — apenas extrai o tema clínico (drug name) e o
// subtítulo (classe farmacológica). O engine usa esses dados para
// construir o título 🟥 específico.
// ─────────────────────────────────────────────────────────────────────────────
class _DrugEntry {
  final String name;          // Nome canônico para o título 🟥
  final String subtitle;      // Classe farmacológica / descrição breve
  final List<String> keys;    // Keywords que identificam este fármaco
  final PlantaoContext ctx;   // Contexto padrão quando não há override
  const _DrugEntry(this.name, this.subtitle, this.keys, this.ctx);
}

class _DrugMatcher {
  _DrugMatcher._();

  static const _kDrugs = <_DrugEntry>[
    // Antiarrítmicos
    _DrugEntry('AMIODARONA', 'Antiarrítmico classe III',
        ['amiodarona', 'amiodarone'], PlantaoContext.arritmia),
    _DrugEntry('ADENOSINA', 'Antiarrítmico — bloqueador AV',
        ['adenosina', 'adenosine'], PlantaoContext.arritmia),
    _DrugEntry('LIDOCAÍNA', 'Antiarrítmico classe IB',
        ['lidocaína', 'lidocaina', 'xilocaína'], PlantaoContext.arritmia),
    _DrugEntry('METOPROLOL', 'Betabloqueador seletivo β1',
        ['metoprolol'], PlantaoContext.arritmia),
    _DrugEntry('DIGOXINA', 'Glicosídeo cardíaco',
        ['digoxina', 'digoxin'], PlantaoContext.arritmia),
    _DrugEntry('ATROPINA', 'Anticolinérgico / Cronotrópico positivo',
        ['atropina', 'atropine'], PlantaoContext.arritmia),

    // Vasopressores / Inotrópicos
    _DrugEntry('NORADRENALINA', 'Vasopressor α1 predominante',
        ['noradrenalina', 'norepinefrina', 'norepinephrine', 'nora'], PlantaoContext.choque),
    _DrugEntry('ADRENALINA', 'Catecolamina endógena — α1 + β1 + β2',
        ['adrenalina', 'epinefrina', 'epinephrine', 'adrenalina ev'], PlantaoContext.choque),
    _DrugEntry('DOPAMINA', 'Catecolamina — dopaminérgico + β1 + α1',
        ['dopamina', 'dopamine'], PlantaoContext.choque),
    _DrugEntry('DOBUTAMINA', 'Inotrópico β1 seletivo',
        ['dobutamina', 'dobutamine'], PlantaoContext.choque),
    _DrugEntry('VASOPRESSINA', 'Vasopressor não-adrenérgico (V1)',
        ['vasopressina', 'vasopressin'], PlantaoContext.choque),
    _DrugEntry('LEVOSIMENDANA', 'Sensibilizador de cálcio — inotrópico',
        ['levosimendana', 'levosimendan'], PlantaoContext.choque),

    // Sedação / Analgesia / Indutores
    _DrugEntry('KETAMINA', 'Anestésico dissociativo — NMDA antagonista',
        ['ketamina', 'ketamine'], PlantaoContext.viaAerea),
    _DrugEntry('ETOMIDATO', 'Indutor anestésico — GABA agonista',
        ['etomidato', 'etomidate'], PlantaoContext.viaAerea),
    _DrugEntry('MIDAZOLAM', 'Benzodiazepínico sedativo',
        ['midazolam', 'dormicum'], PlantaoContext.farmacologia),
    _DrugEntry('PROPOFOL', 'Anestésico geral / Sedativo EV',
        ['propofol', 'diprivan'], PlantaoContext.farmacologia),
    _DrugEntry('FENTANIL', 'Opioide sintético — analgesia EV',
        ['fentanil', 'fentanyl'], PlantaoContext.farmacologia),
    _DrugEntry('MORFINA', 'Opioide — analgesia / broncodilatação',
        ['morfina', 'morphine'], PlantaoContext.farmacologia),
    _DrugEntry('SUCCINILCOLINA', 'Bloqueador neuromuscular despolarizante',
        ['succinilcolina', 'succinylcholine', 'suxametônio'], PlantaoContext.viaAerea),
    _DrugEntry('ROCURÔNIO', 'Bloqueador neuromuscular não-despolarizante',
        ['rocurônio', 'rocuronio', 'rocuronium'], PlantaoContext.viaAerea),

    // Anticoagulantes / Hemostáticos
    _DrugEntry('HEPARINA NÃO FRACIONADA', 'Anticoagulante — inibidor da trombina',
        ['heparina não fracionada', 'hnf', 'heparina ev', 'heparin'], PlantaoContext.cardiovascular),
    _DrugEntry('ENOXAPARINA', 'HBPM — anticoagulante subcutâneo',
        ['enoxaparina', 'clexane', 'enoxaparin'], PlantaoContext.cardiovascular),
    _DrugEntry('VARFARINA', 'Anticoagulante oral — inibidor de vitamina K',
        ['varfarina', 'warfarina', 'warfarin', 'coumadin'], PlantaoContext.cardiovascular),
    _DrugEntry('RIVAROXABANA', 'DOAC — inibidor direto do fator Xa',
        ['rivaroxabana', 'xarelto', 'rivaroxaban'], PlantaoContext.cardiovascular),
    _DrugEntry('DABIGATRANA', 'DOAC — inibidor direto da trombina',
        ['dabigatrana', 'pradaxa', 'dabigatran'], PlantaoContext.cardiovascular),

    // Antibióticos
    _DrugEntry('VANCOMICINA', 'Glicopeptídeo — antibiótico anti-MRSA',
        ['vancomicina', 'vancomycin'], PlantaoContext.sepse),
    _DrugEntry('PIPERACILINA-TAZOBACTAM', 'Penicilina + inibidor de β-lactamase',
        ['piperacilina', 'tazobactam', 'pip-tazo', 'tazocin'], PlantaoContext.sepse),
    _DrugEntry('MEROPENEM', 'Carbapenem — amplo espectro',
        ['meropenem', 'meronem'], PlantaoContext.sepse),
    _DrugEntry('IMIPENEM', 'Carbapenem — amplo espectro',
        ['imipenem', 'tienam'], PlantaoContext.sepse),
    _DrugEntry('CEFTRIAXONA', 'Cefalosporina 3ª geração',
        ['ceftriaxona', 'rocefin', 'ceftriaxone'], PlantaoContext.sepse),
    _DrugEntry('AZITROMICINA', 'Macrolídeo — atípicos',
        ['azitromicina', 'zithromax', 'azithromycin'], PlantaoContext.sepse),
    _DrugEntry('CIPROFLOXACINO', 'Fluoroquinolona — amplo espectro',
        ['ciprofloxacino', 'ciprofloxacin', 'cipro'], PlantaoContext.sepse),
    _DrugEntry('METRONIDAZOL', 'Nitroimidazol — anaeróbios / protozoários',
        ['metronidazol', 'metronidazole', 'flagyl'], PlantaoContext.sepse),

    // Eletrolíticos / Correção
    _DrugEntry('CLORETO DE POTÁSSIO', 'Reposição de potássio EV',
        ['kcl', 'cloreto de potássio', 'cloreto de potassio', 'kci 19,1%', 'kcl 19,1', 'potássio ev'], PlantaoContext.eletrolitos),
    _DrugEntry('SULFATO DE MAGNÉSIO', 'Reposição de magnésio EV',
        ['sulfato de magnésio', 'mgso4', 'magnésio ev', 'magnesio ev'], PlantaoContext.eletrolitos),
    _DrugEntry('GLUCONATO DE CÁLCIO', 'Protetor de membrana / reposição de Ca2+',
        ['gluconato de cálcio', 'gluconato de calcio', 'cálcio ev', 'calcio ev'], PlantaoContext.eletrolitos),
    _DrugEntry('BICARBONATO DE SÓDIO', 'Tampão / correção de acidose',
        ['bicarbonato', 'nahco3', 'bicarbonato de sódio', 'bicarbonato de sodio'], PlantaoContext.eletrolitos),
    _DrugEntry('INSULINA REGULAR', 'Insulina de ação rápida — controle glicêmico',
        ['insulina regular', 'insulina ev', 'insulina endovenosa', 'insulinoterapia ev'], PlantaoContext.glicemia),
    _DrugEntry('GLICOSE 50%', 'Correção de hipoglicemia EV',
        ['glicose 50%', 'glicose a 50', 'soro glicosado 50', 'sg50%'], PlantaoContext.glicemia),

    // Cardiovasculares
    _DrugEntry('NITROPRUSSIATO', 'Vasodilatador arteriovenoso — crise hipertensiva',
        ['nitroprussiato', 'nipride', 'nitroprusside'], PlantaoContext.cardiovascular),
    _DrugEntry('NITROGLICERINA', 'Nitrato — vasodilatador coronário',
        ['nitroglicerina', 'nitroglicerin', 'ntg', 'isordil ev'], PlantaoContext.cardiovascular),
    _DrugEntry('FUROSEMIDA', 'Diurético de alça — IC / congestão',
        ['furosemida', 'lasix', 'furosemide'], PlantaoContext.cardiovascular),
    _DrugEntry('LABETALOL', 'Alfabetabloqueador — crise hipertensiva',
        ['labetalol', 'trandate'], PlantaoContext.cardiovascular),

    // Neurologia
    _DrugEntry('DIAZEPAM', 'Benzodiazepínico — anticonvulsivante',
        ['diazepam', 'valium'], PlantaoContext.neurologia),
    _DrugEntry('FENITOÍNA', 'Antiepiléptico — estabilizador de membrana',
        ['fenitoína', 'fenitoina', 'phenytoin', 'hidantal'], PlantaoContext.neurologia),
    _DrugEntry('FENOBARBITAL', 'Barbitúrico antiepiléptico',
        ['fenobarbital', 'phenobarbital', 'gardenal'], PlantaoContext.neurologia),
    _DrugEntry('LEVETIRACETAM', 'Antiepiléptico de nova geração',
        ['levetiracetam', 'keppra'], PlantaoContext.neurologia),
    _DrugEntry('ALTEPLASE', 'Trombolítico — rt-PA — AVC isquêmico / TEP',
        ['alteplase', 'rtpa', 'rt-pa', 'actilyse', 'tenecteplase'], PlantaoContext.neurologia),
    _DrugEntry('MANITOL', 'Diurético osmótico — hipertensão intracraniana',
        ['manitol', 'mannitol'], PlantaoContext.neurologia),

    // Broncodilatadores / Respiratórios
    _DrugEntry('SALBUTAMOL', 'Broncodilatador β2 — broncoespasmo',
        ['salbutamol', 'ventolin', 'albuterol'], PlantaoContext.ventilacao),
    _DrugEntry('ADRENALINA NEBULIZADA', 'Vasoconstritora / broncodilatadora inalatória',
        ['adrenalina nebulizada', 'adrenalina inalada'], PlantaoContext.ventilacao),
    _DrugEntry('IPRATRÓPIO', 'Anticolinérgico broncodilatador',
        ['ipratrópio', 'atrovent', 'ipratropium'], PlantaoContext.ventilacao),
    _DrugEntry('AMINOFILINA', 'Xantina — broncodilatador',
        ['aminofilina', 'aminophylline'], PlantaoContext.ventilacao),
  ];

  static _MatcherResult match(String msg) {
    for (final drug in _kDrugs) {
      final matched = drug.keys.where((k) => msg.contains(k)).toList();
      if (matched.isNotEmpty) {
        return _MatcherResult(
          intent: null, // DrugMatcher nunca define intenção
          context: drug.ctx,
          topic: drug.name,
          subtitle: drug.subtitle,
          score: matched.length * 3, // peso maior: entidade é o tema
          matched: matched,
        );
      }
    }
    return const _MatcherResult(score: 0, matched: []);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ContextMatcher — reconhece contextos clínicos graves (Build 225)
//
// Contextos graves elevam a complexidade para `critica`.
// ─────────────────────────────────────────────────────────────────────────────
class _ContextEntry {
  final PlantaoContext context;
  final String topicOverride;       // Override de tema se não houver drug match
  final String subtitleOverride;    // Override de subtítulo
  final List<String> keys;
  final bool isCritical;            // true → eleva complexidade para critica
  const _ContextEntry(
      this.context, this.topicOverride, this.subtitleOverride, this.keys,
      {this.isCritical = false});
}

class _ContextMatcher {
  _ContextMatcher._();

  static const _kContexts = <_ContextEntry>[
    _ContextEntry(PlantaoContext.pcr, 'PCR', 'Parada cardiorrespiratória', [
      'pcr', 'parada cardíaca', 'parada cardiaca', 'parada cardiorrespiratória',
      'rcp', 'ressuscitação', 'acls', 'bls', 'reanimação',
      'fv', 'fibrilação ventricular', 'tvsp', 'aesp', 'assistolia',
      'sem pulso', 'choque elétrico',
    ], isCritical: true),
    _ContextEntry(PlantaoContext.viaAerea, 'VIA AÉREA', 'Manejo da via aérea', [
      'iot', 'intubar', 'intubação', 'sequência rápida', 'sri', 'rsi',
      'laringoscopia', 'videolaringoscopia', 'via aérea difícil',
      'cricotireoidostomia', 'cormack', 'mallampati',
    ], isCritical: true),
    _ContextEntry(PlantaoContext.choque, 'CHOQUE', 'Choque circulatório', [
      'choque', 'shock', 'hipotensão refratária',
      'pam < 65', 'pam baixa', 'ressuscitação hemodinâmica',
      'instabilidade hemodinâmica',
    ], isCritical: true),
    _ContextEntry(PlantaoContext.sepse, 'SEPSE', 'Infecção grave / Sepse', [
      'sepse', 'sepsis', 'septicemia', 'choque séptico',
      'bundle sepse', 'hora 1', 'foco infeccioso',
      'infecção grave', 'sofa', 'qsofa',
    ], isCritical: true),
    _ContextEntry(PlantaoContext.viaAerea, 'VIA AÉREA', 'Suporte ventilatório', [
      'saturação baixa', 'sato2', 'sat o2', 'spO2', 'spO2 < 90',
      'hipóxia', 'hipoxia', 'hipoxemia',
    ], isCritical: true),
    _ContextEntry(PlantaoContext.ventilacao, 'VENTILAÇÃO MECÂNICA', 'Suporte ventilatório invasivo', [
      'ventilação mecânica', 'vm', 'ventilador', 'peep', 'fio2',
      'volume corrente', 'pressão plateau', 'driving pressure',
    ], isCritical: false),
    _ContextEntry(PlantaoContext.arritmia, 'ARRITMIA', 'Distúrbio do ritmo cardíaco', [
      'arritmia', 'taquicardia', 'fibrilação atrial', ' fa ',
      'flutter atrial', 'tsvp', 'taqui supra', 'taqui ventricular',
      'bradiarritmia', 'bloqueio av', 'bav',
    ], isCritical: false),
    _ContextEntry(PlantaoContext.cardiovascular, 'IAM', 'Síndrome coronariana aguda', [
      'iam', 'infarto', 'sca', 'stemi', 'nstemi',
      'dor torácica', 'sindrome coronariana', 'elevação de st',
    ], isCritical: true),
    _ContextEntry(PlantaoContext.cardiovascular, 'TEP', 'Tromboembolismo pulmonar', [
      'tep', 'embolia pulmonar', 'tromboembolismo',
    ], isCritical: true),
    _ContextEntry(PlantaoContext.cardiovascular, 'CRISE HIPERTENSIVA', 'Emergência hipertensiva', [
      'crise hipertensiva', 'emergência hipertensiva', 'encefalopatia hipertensiva',
      'pa 220', 'pa 210', 'pa 200', 'pas ≥ 180', 'hipertensão grave',
    ], isCritical: true),
    _ContextEntry(PlantaoContext.eletrolitos, 'DISTÚRBIO ELETROLÍTICO', 'Desequilíbrio iônico', [
      'hipocalemia grave', 'hipercalemia grave', 'k+ 6', 'k+ 7', 'k+ < 2',
      'hiponatremia grave', 'hipernatremia grave', 'hipocalcemia grave',
      'ecg alterado', 'ondas t apiculadas', 'alargamento de qrs',
    ], isCritical: true),
    _ContextEntry(PlantaoContext.eletrolitos, 'DISTÚRBIO ELETROLÍTICO', 'Desequilíbrio iônico', [
      'hipocalemia', 'hipercalemia', 'hiponatremia', 'hipernatremia',
      'hipocalcemia', 'hipercalcemia', 'hipomagnesemia',
    ], isCritical: false),
    _ContextEntry(PlantaoContext.glicemia, 'CETOACIDOSE DIABÉTICA', 'Emergência metabólica', [
      'cad', 'cetoacidose', 'cetoacidose diabética', 'dka', 'ehh', 'estado hiperosmolar',
    ], isCritical: true),
    _ContextEntry(PlantaoContext.glicemia, 'DISTÚRBIO GLICÊMICO', 'Controle glicêmico', [
      'hipoglicemia', 'hiperglicemia', 'glicemia',
    ], isCritical: false),
    _ContextEntry(PlantaoContext.neurologia, 'AVC ISQUÊMICO', 'Acidente vascular cerebral', [
      'avc', 'acidente vascular', 'avc isquêmico', 'stroke', 'nihss',
    ], isCritical: true),
    _ContextEntry(PlantaoContext.neurologia, 'STATUS EPILÉPTICO', 'Estado de mal epiléptico', [
      'status epiléptico', 'estado de mal epiléptico', 'convulsão', 'convulsão prolongada',
      'convulsão há', 'crise convulsiva',
    ], isCritical: true),
    _ContextEntry(PlantaoContext.neurologia, 'MENINGITE', 'Infecção do SNC', [
      'meningite', 'meningismo', 'rigidez de nuca', 'kernig', 'brudzinski',
    ], isCritical: true),
    _ContextEntry(PlantaoContext.renal, 'INJÚRIA RENAL AGUDA', 'IRA / ajuste de dose renal', [
      'ira', 'injúria renal', 'lesão renal aguda', 'clcr', 'clearance', 'creatinina elevada',
      'ajuste renal', 'dose em insuficiência renal', 'nefrotoxicidade',
    ], isCritical: false),
    _ContextEntry(PlantaoContext.toxicologia, 'INTOXICAÇÃO', 'Toxicologia clínica', [
      'intoxicação', 'overdose', 'antídoto', 'envenenamento', 'toxicidade',
    ], isCritical: true),
  ];

  static ({PlantaoContext ctx, String topic, String subtitle, bool isCritical, List<String> matched})
      match(String msg) {
    for (final entry in _kContexts) {
      final matched = entry.keys.where((k) => msg.contains(k)).toList();
      if (matched.isNotEmpty) {
        return (
          ctx: entry.context,
          topic: entry.topicOverride,
          subtitle: entry.subtitleOverride,
          isCritical: entry.isCritical,
          matched: matched,
        );
      }
    }
    return (
      ctx: PlantaoContext.geral,
      topic: '',
      subtitle: '',
      isCritical: false,
      matched: <String>[],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ComplexityResolver — determina complexidade clínica (Build 225)
//
// Ordem de precedência:
//   1. Sinais explícitos de gravidade na mensagem → critica
//   2. Contexto crítico detectado pelo _ContextMatcher → critica
//   3. Intenção de alto risco (pcr, via_aerea, choque, sepse, ventilacao) → critica
//   4. Distúrbios eletrolíticos / glicemia / monitorização → intermediaria
//   5. Resto → simples
// ─────────────────────────────────────────────────────────────────────────────
class _ComplexityResolver {
  _ComplexityResolver._();

  // Sinais de gravidade que elevam qualquer cenário para `critica`
  static const _kCriticalSignals = [
    'instabilidade', 'instável', 'sem pulso', 'apneia', 'glasgow < 8',
    'glasgow 3', 'glasgow 4', 'glasgow 5', 'glasgow 6',
    'rebaixamento', 'inconsciente', 'sem resposta', 'parada',
    'pam < 65', 'pam baixa', 'pa 80', 'pa 70', 'pa 60',
    'sat 80', 'sat 85', 'spo2 80', 'spo2 85', 'spo2 88',
    'spo2 < 90', 'sat < 90', 'hipóxia grave', 'cianose',
    'k+ 7', 'k+ 6,5', 'k+ 8', 'k+ < 2', 'k+ 1,',
    'hemorragia grave', 'choque hemorrágico', 'exsanguinação',
  ];

  // Intenções que por natureza são críticas
  static const _kCriticalIntents = {
    PlantaoIntent.pcr,
    PlantaoIntent.via_aerea,
    PlantaoIntent.ventilacao,
    PlantaoIntent.choque,
    PlantaoIntent.sepse,
  };

  // Contextos que por natureza são críticos
  static const _kCriticalContexts = {
    PlantaoContext.pcr,
    PlantaoContext.viaAerea,
  };

  // Intenções de complexidade intermediária
  static const _kIntermediateIntents = {
    PlantaoIntent.monitorizacao,
    PlantaoIntent.contraindicacao,
    PlantaoIntent.interpretacao,
    PlantaoIntent.interacao,
    PlantaoIntent.diagnostico,
    PlantaoIntent.eletrolitos,
    PlantaoIntent.glicemia,
    PlantaoIntent.arritmia,
    PlantaoIntent.calculo,
  };

  static PlantaoComplexity resolve({
    required String msg,
    required PlantaoIntent primaryIntent,
    required PlantaoContext context,
    required bool contextIsCritical,
  }) {
    // Passo 1: sinais de gravidade explícitos na mensagem
    if (_kCriticalSignals.any((s) => msg.contains(s))) {
      return PlantaoComplexity.critica;
    }

    // Passo 2: contexto marcado como crítico pelo _ContextMatcher
    if (contextIsCritical) return PlantaoComplexity.critica;

    // Passo 3: intenções intrinsecamente críticas
    if (_kCriticalIntents.contains(primaryIntent)) return PlantaoComplexity.critica;
    if (_kCriticalContexts.contains(context)) return PlantaoComplexity.critica;

    // Passo 4: intenções intermediárias
    if (_kIntermediateIntents.contains(primaryIntent)) return PlantaoComplexity.intermediaria;
    if (context == PlantaoContext.eletrolitos ||
        context == PlantaoContext.glicemia ||
        context == PlantaoContext.renal ||
        context == PlantaoContext.arritmia) {
      return PlantaoComplexity.intermediaria;
    }

    // Passo 5: padrão — simples
    return PlantaoComplexity.simples;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PlantaoIntentEngine — engine multidimensional principal (Build 225)
//
// 100% LOCAL — ZERO IA — ZERO REDE — ZERO LATÊNCIA
//
// Executa todos os matchers em paralelo (Dart síncrono — sem async),
// resolve conflitos por regras de prioridade e retorna PlantaoQueryAnalysis.
//
// REGRA DE RESOLUÇÃO DE CONFLITOS:
//   1. Palavras de ação (dose, monitorar, dilui) → intenção primária
//   2. Entidade clínica/fármaco (amiodarona, noradrenalina) → tema + subtítulo
//   3. Contexto clínico grave (pcr, choque, sepse) → contexto + complexidade
//   4. Contexto eletrólito/glicemia/renal → contexto + complexidade intermediária
// ─────────────────────────────────────────────────────────────────────────────
class PlantaoIntentEngine {
  PlantaoIntentEngine._(); // 100% estático

  // Matchers de intenção — instâncias singleton (const não é possível com herança)
  static final _intentMatchers = <_IntentMatcher>[
    DiluitionMatcher(),   // prioridade máxima (gotejamento/preparo)
    InfusionMatcher(),
    MonitoringMatcher(),
    ContraindicationMatcher(),
    DiagnosisMatcher(),
    InterpretationMatcher(),
    InteractionMatcher(),
    CalculationMatcher(),
    ProcedureMatcher(),
    DoseMatcher(),        // dose após os mais específicos
    ConductMatcher(),     // conduta como fallback de intenção
    ElectrolyteMatcher(), // contexto eletrolítico (eleva Intent + Context)
    GlycemiaMatcher(),    // contexto glicêmico
    VentilationMatcher(), // contexto ventilatório
  ];

  /// Analisa a mensagem do usuário em 4 dimensões: tema, contexto, intenção, complexidade.
  ///
  /// Retorna PlantaoQueryAnalysis — produto principal da Build 225.
  static PlantaoQueryAnalysis analyze(String userMessage) {
    final msg = userMessage.toLowerCase().trim();

    if (msg.isEmpty) {
      return const PlantaoQueryAnalysis(
        clinicalTopic: 'CONSULTA CLÍNICA',
        clinicalSubtitle: '',
        primaryIntent: PlantaoIntent.geral,
        clinicalContext: PlantaoContext.geral,
        complexity: PlantaoComplexity.simples,
        matchedKeywords: [],
        confidence: 0.0,
      );
    }

    // ── Passo 1: Drug/Entity Matcher — identifica o TEMA ─────────────────────
    final drugResult = _DrugMatcher.match(msg);

    // ── Passo 2: Context Matcher — identifica o CONTEXTO CLÍNICO ─────────────
    final ctxResult = _ContextMatcher.match(msg);

    // ── Passo 3: Intent Matchers — identifica a INTENÇÃO do usuário ──────────
    // Executa todos; coleta scores de todos para encontrar primária + secundária
    final intentScores = <(PlantaoIntent, int, List<String>)>[];
    for (final matcher in _intentMatchers) {
      final r = matcher.match(msg);
      if (r.hasMatch) {
        intentScores.add((r.intent!, r.score, r.matched));
      }
    }

    // Ordena por score descendente
    intentScores.sort((a, b) => b.$2.compareTo(a.$2));

    // Intenção primária: maior score; secundária: segunda (se diferente)
    PlantaoIntent primaryIntent;
    PlantaoIntent? secondaryIntent;
    final List<String> intentKeywords = [];

    if (intentScores.isEmpty) {
      primaryIntent = PlantaoIntent.geral;
    } else {
      primaryIntent = intentScores.first.$1;
      intentKeywords.addAll(intentScores.first.$3);
      if (intentScores.length > 1 &&
          intentScores[1].$1 != primaryIntent) {
        secondaryIntent = intentScores[1].$1;
      }
    }

    // ── Passo 4: Resolução de Contexto Final ──────────────────────────────────
    // Regra de prioridade:
    //   1. Contexto clínico EXPLÍCITO na mensagem (ctxResult) — supera contexto do fármaco
    //      quando o ctxResult não é genérico (ex: "clcr" → renal prevalece sobre Vancomicina→sepse)
    //   2. Contexto padrão do fármaco (drugResult.context) — quando não há contexto explícito
    //   3. Farmacologia geral como fallback
    final PlantaoContext finalContext;
    if (ctxResult.ctx != PlantaoContext.geral) {
      // Contexto explícito tem prioridade — ex: "clcr" define renal mesmo com vancomicina
      finalContext = ctxResult.ctx;
    } else if (drugResult.hasMatch) {
      // Sem contexto explícito → usa contexto padrão do fármaco
      finalContext = drugResult.context!;
    } else {
      finalContext = PlantaoContext.farmacologia;
    }

    // ── Passo 5: Resolução de Tema + Subtítulo ────────────────────────────────
    // Prioridade: drug (entidade) > contexto clínico grave > genérico
    final String finalTopic = drugResult.hasMatch && drugResult.topic.isNotEmpty
        ? drugResult.topic
        : (ctxResult.topic.isNotEmpty ? ctxResult.topic : 'CONSULTA CLÍNICA');
    final String finalSubtitle = drugResult.hasMatch && drugResult.subtitle.isNotEmpty
        ? drugResult.subtitle
        : ctxResult.subtitle;

    // ── Passo 6: Complexidade ─────────────────────────────────────────────────
    final complexity = _ComplexityResolver.resolve(
      msg: msg,
      primaryIntent: primaryIntent,
      context: finalContext,
      contextIsCritical: ctxResult.isCritical,
    );

    // ── Passo 7: Confiança ────────────────────────────────────────────────────
    // Score total normalizado (0–1): drug(peso 3) + intent + context
    final totalScore = (drugResult.score) +
        (intentScores.isNotEmpty ? intentScores.first.$2 : 0) +
        ctxResult.matched.length;
    final confidence = (totalScore / 10.0).clamp(0.0, 1.0);

    // ── Passo 8: Keywords consolidadas ───────────────────────────────────────
    final allKeywords = <String>[
      ...drugResult.matched,
      ...intentKeywords,
      ...ctxResult.matched,
    ];

    final analysis = PlantaoQueryAnalysis(
      clinicalTopic: finalTopic,
      clinicalSubtitle: finalSubtitle,
      primaryIntent: primaryIntent,
      secondaryIntent: secondaryIntent,
      clinicalContext: finalContext,
      complexity: complexity,
      matchedKeywords: allKeywords,
      confidence: confidence,
    );

    // ── Log [PLANTAO_ANALYSIS] ────────────────────────────────────────────────
    debugPrint('[PLANTAO_ANALYSIS] '
        'topic=${analysis.clinicalTopic} '
        'subtitle="${analysis.clinicalSubtitle}" '
        'primaryIntent=${analysis.primaryIntent.name} '
        'secondaryIntent=${analysis.secondaryIntent?.name ?? "none"} '
        'context=${analysis.clinicalContext.name} '
        'complexity=${analysis.complexity.name} '
        'confidence=${analysis.confidence.toStringAsFixed(2)} '
        'matched=${analysis.matchedKeywords}');

    return analysis;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // buildIntentMandateV2 — mandato rico para system_instruction (Build 225)
  //
  // Injeta: topic, subtitle, context, complexity, template de emojis.
  // Vai EXCLUSIVAMENTE para system_instruction — NUNCA para contents[].
  // ─────────────────────────────────────────────────────────────────────────
  static String buildIntentMandateV2(PlantaoQueryAnalysis qa, String lang) {
    final isEs = lang == 'es';

    // ── Bloco de identidade do turno ──────────────────────────────────────────
    final topicLine = isEs
        ? 'TEMA DESTE TURNO: ${qa.clinicalTopic}'
        : 'TEMA DESTE TURNO: ${qa.clinicalTopic}';
    final subtitleLine = qa.clinicalSubtitle.isNotEmpty
        ? (isEs
            ? 'CATEGORÍA: ${qa.clinicalSubtitle}'
            : 'CATEGORIA: ${qa.clinicalSubtitle}')
        : '';
    final contextLine = isEs
        ? 'CONTEXTO CLÍNICO: ${_contextLabel(qa.clinicalContext, isEs)}'
        : 'CONTEXTO CLÍNICO: ${_contextLabel(qa.clinicalContext, false)}';
    final complexityLine = isEs
        ? 'COMPLEJIDAD: ${_complexityLabel(qa.complexity, isEs)}'
        : 'COMPLEXIDADE: ${_complexityLabel(qa.complexity, false)}';

    // ── Construção do título 🟥 específico ────────────────────────────────────
    final titleInstruction = _buildTitleInstruction(qa, isEs);

    // ── Template de emojis baseado em primaryIntent ───────────────────────────
    // Build 226 Fix B: fármaco isolado sem intenção explícita → template farmacológico
    // Critério: primaryIntent=geral + topic não é genérico (drug foi detectado pelo _DrugMatcher)
    // Isso evita que o LLM tente preencher "💊 1ª linha:" incompleta para nomes de fármacos isolados
    final bool isFarmacoIsolado = qa.primaryIntent == PlantaoIntent.geral &&
        qa.clinicalTopic != 'CONSULTA CLÍNICA' &&
        qa.clinicalTopic.isNotEmpty;

    final String template;
    if (isFarmacoIsolado) {
      template = _buildFarmacoResumoTemplate(qa, isEs);
    } else {
      template = PlantaoIntentClassifier.buildIntentMandate(
        qa.toIntentResult(),
        lang,
      );
    }

    // ── Adaptação de complexidade ─────────────────────────────────────────────
    final complexityAdaptation = _buildComplexityAdaptation(qa.complexity, isEs);

    // ── Montagem final ────────────────────────────────────────────────────────
    final lines = <String>[
      topicLine,
      if (subtitleLine.isNotEmpty) subtitleLine,
      contextLine,
      complexityLine,
      titleInstruction,
      template,
      if (complexityAdaptation.isNotEmpty) complexityAdaptation,
    ];

    return lines.join('\n');
  }

  // ── Helpers privados ───────────────────────────────────────────────────────

  static String _contextLabel(PlantaoContext ctx, bool isEs) {
    switch (ctx) {
      case PlantaoContext.pcr:         return isEs ? 'PCR / Reanimación' : 'PCR / Reanimação';
      case PlantaoContext.arritmia:    return isEs ? 'Arritmia' : 'Arritmia';
      case PlantaoContext.choque:      return isEs ? 'Shock circulatorio' : 'Choque circulatório';
      case PlantaoContext.sepse:       return isEs ? 'Sepsis / Infección grave' : 'Sepse / Infecção grave';
      case PlantaoContext.viaAerea:    return isEs ? 'Vía aérea / IOT' : 'Via aérea / IOT';
      case PlantaoContext.ventilacao:  return isEs ? 'Ventilación mecánica' : 'Ventilação mecânica';
      case PlantaoContext.eletrolitos: return isEs ? 'Trastorno electrolítico' : 'Distúrbio eletrolítico';
      case PlantaoContext.glicemia:    return isEs ? 'Trastorno glucémico' : 'Distúrbio glicêmico';
      case PlantaoContext.renal:       return isEs ? 'Injuria renal / Ajuste de dosis' : 'Injúria renal / Ajuste de dose';
      case PlantaoContext.cardiovascular: return isEs ? 'Cardiovascular' : 'Cardiovascular';
      case PlantaoContext.neurologia:  return isEs ? 'Neurología crítica' : 'Neurologia crítica';
      case PlantaoContext.toxicologia: return isEs ? 'Toxicología' : 'Toxicologia';
      case PlantaoContext.trauma:      return isEs ? 'Trauma / Cirugía' : 'Trauma / Cirurgia';
      case PlantaoContext.farmacologia:return isEs ? 'Farmacología clínica' : 'Farmacologia clínica';
      case PlantaoContext.geral:       return isEs ? 'General' : 'Geral';
    }
  }

  static String _complexityLabel(PlantaoComplexity c, bool isEs) {
    switch (c) {
      case PlantaoComplexity.simples:       return isEs ? 'SIMPLE' : 'SIMPLES';
      case PlantaoComplexity.intermediaria: return isEs ? 'INTERMEDIA' : 'INTERMEDIÁRIA';
      case PlantaoComplexity.critica:       return isEs ? 'CRÍTICA — tom de urgência máxima' : 'CRÍTICA — tom de urgência máxima';
    }
  }

  static String _buildTitleInstruction(PlantaoQueryAnalysis qa, bool isEs) {
    final topic = qa.clinicalTopic;
    final subtitle = qa.clinicalSubtitle;

    // Título específico com subtítulo inline (estilo Build 225)
    if (subtitle.isNotEmpty) {
      return isEs
          ? 'TÍTULO 🟥 OBRIGATÓRIO: "$topic — $subtitle"\n'
              '  (Nunca usar título genérico. Nunca escrever apenas o nome do fármaco sem classe.)'
          : 'TÍTULO 🟥 OBRIGATÓRIO: "$topic — $subtitle"\n'
              '  (Nunca usar título genérico. Nunca escrever apenas o nome do fármaco sem classe.)';
    }

    return isEs
        ? 'TÍTULO 🟥 OBRIGATÓRIO: "$topic"\n'
            '  (Nunca usar "CONDUCTA CLÍNICA INMEDIATA" como título genérico.)'
        : 'TÍTULO 🟥 OBRIGATÓRIO: "$topic"\n'
            '  (Nunca usar "CONDUTA CLÍNICA IMEDIATA" como título genérico.)';
  }

  static String _buildComplexityAdaptation(PlantaoComplexity c, bool isEs) {
    switch (c) {
      case PlantaoComplexity.critica:
        return isEs
            ? 'URGENCIA MÁXIMA: Incluir ⚠️ Alerta siempre. Incluir bloque de monitorización. '
                'Usar numeración explícita si hay secuencia de pasos críticos.'
            : 'URGÊNCIA MÁXIMA: Incluir ⚠️ Alerta sempre. Incluir bloco de monitorização. '
                'Usar numeração explícita se houver sequência de passos críticos.';
      case PlantaoComplexity.intermediaria:
        return isEs
            ? 'COMPLEJIDAD INTERMEDIA: ⚠️ Alerta solo si hay riesgo real. '
                'Priorizar precisión sobre exhaustividad.'
            : 'COMPLEXIDADE INTERMEDIÁRIA: ⚠️ Alerta somente se houver risco real. '
                'Priorizar precisão sobre completude.';
      case PlantaoComplexity.simples:
        return ''; // Sem instrução extra para respostas simples
    }
  }

  // ── Build 226 Fix B — template farmacológico para fármaco isolado ─────────
  // Usado quando primaryIntent=geral e clinicalTopic é um fármaco reconhecido.
  // Substitui o template conduta genérico (que gerava "💊 1ª linha:" truncado)
  // por um template de RESUMO FARMACOLÓGICO completo e auto-suficiente.
  //
  // Estrutura (6 blocos):
  //   🟥 NOME — CLASSE FARMACOLÓGICA        (linha título — gerada pelo titleInstruction)
  //   💊 Uso principal: indicação + dose
  //   🔄 Dose alternativa: outra apresentação (se houver)
  //   ⛔ Contraindicações: absolutas principais
  //   📌 Monitorar: parâmetros de segurança
  //   ⚠️ Alerta: risco crítico principal
  // ─────────────────────────────────────────────────────────────────────────
  static String _buildFarmacoResumoTemplate(PlantaoQueryAnalysis qa, bool isEs) {
    final topic = qa.clinicalTopic;
    final subtitle = qa.clinicalSubtitle;
    final classeFarm = subtitle.isNotEmpty ? subtitle : 'fármaco de uso clínico';

    if (isEs) {
      return 'TEMPLATE FARMACOLÓGICO (fármaco aislado sin intención explícita):\n'
          '🟥 $topic — $classeFarm\n'
          '💊 Uso principal: [indicación principal + dosis habitual + vía]\n'
          '🔄 Dosis alternativa: [otra presentación o esquema si aplica]\n'
          '⛔ Contraindicado: [contraindicaciones absolutas principales]\n'
          '📌 Monitorar: [parámetros de seguridad — ECG, PA, función renal, etc.]\n'
          '⚠️ Alerta: [riesgo crítico principal — interacción, toxicidad, etc.]\n'
          '\n'
          'REGLA: Completar TODOS los 6 blocos con información clínica real y precisa. '
          'Nunca dejar bloco vacío o con "[...]" literal. '
          'Si no hay alternativa relevante, omitir el bloco 🔄 en vez de inventar. '
          'Nunca truncar la respuesta — completar siempre los blocos 📌 y ⚠️.';
    }
    return 'TEMPLATE FARMACOLÓGICO (fármaco isolado sem intenção explícita):\n'
        '🟥 $topic — $classeFarm\n'
        '💊 Uso principal: [indicação principal + dose usual + via]\n'
        '🔄 Dose alternativa: [outra apresentação ou esquema se houver]\n'
        '⛔ Contraindicado: [contraindicações absolutas principais]\n'
        '📌 Monitorar: [parâmetros de segurança — ECG, PA, função renal, etc.]\n'
        '⚠️ Alerta: [risco crítico principal — interação, toxicidade, etc.]\n'
        '\n'
        'REGRA: Preencher TODOS os 6 blocos com informação clínica real e precisa. '
        'Nunca deixar bloco vazio ou com "[...]" literal. '
        'Se não houver alternativa relevante, omitir o bloco 🔄 em vez de inventar. '
        'Nunca truncar a resposta — completar sempre os blocos 📌 e ⚠️.';
  }
}

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
    'contraindicaç', 'contraindicado', 'contra-indica',
    'contraindicaciones', 'quando não usar', 'quando não dar', 'quando evitar',
    'quem não pode', 'proibido', 'não pode usar', 'evitar em',
    'contraindicado em', 'contraindicada', 'não indicado',
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
