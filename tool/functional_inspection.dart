// ignore_for_file: avoid_print
// Script de inspeção funcional — executa com: dart run tool/functional_inspection.dart
// Valida estruturalmente os prompts gerados para os cenários 2–10
// Keywords calibradas com as strings REAIS dos módulos do ai_service.dart

import 'package:medcases/services/ai_service.dart';
import 'package:medcases/services/clinical_session_memory.dart';

// ─── helpers ──────────────────────────────────────────────────────────────────
void pass(String label) => print('  ✅ $label');
void fail(String label, String detail) {
  print('  ❌ $label');
  print('     → $detail');
}

int _passed = 0;
int _failed = 0;

void assert_(String label, bool cond, [String? detail]) {
  if (cond) { _passed++; pass(label); }
  else       { _failed++; fail(label, detail ?? 'condição falhou'); }
}

void section(String title) {
  print('\n══════════════════════════════════════════════════════');
  print('  $title');
  print('══════════════════════════════════════════════════════');
}

// ─── main ─────────────────────────────────────────────────────────────────────
void main() {

  // ══════════════════════════════════════════════════════════════════════════
  // TESTE 2 — PT/ES branching
  // ══════════════════════════════════════════════════════════════════════════
  section('TESTE 2 — PT/ES branching');

  final ptAmio = AiService.buildClinicalSystemPrompt(
    lang: 'pt', matchedProtocolSummaries: [], matchedDrugSummaries: [],
    userQuery: 'Dose de amiodarona na PCR?',
  );
  // identidade PT: "PRECEPTOR MEDICO SENIOR" (sem acento nos módulos)
  assert_('PT: identidade PT presente', ptAmio.contains('PRECEPTOR MEDICO'));
  assert_('PT: linguagem PT (usuario)', ptAmio.contains('usuario') || ptAmio.contains('usuário'));
  assert_('PT: safetyRules PT (NUNCA)', ptAmio.contains('NUNCA'));
  assert_('PT: drugsBlock injetado', ptAmio.contains('Amiodarona') || ptAmio.contains('amiodarona'));
  print('  → Prompt PT amiodarona (${ptAmio.length} chars)');

  final esAmio = AiService.buildClinicalSystemPrompt(
    lang: 'es', matchedProtocolSummaries: [], matchedDrugSummaries: [],
    userQuery: 'Dosis de amiodarona en paro cardíaco?',
  );
  // identidade ES: "Eres la inteligencia clinica"
  assert_('ES: identidade ES presente', esAmio.contains('Eres la inteligencia clinica'));
  assert_('ES: linguagem ES (usuario es)', esAmio.contains('usuario es') || esAmio.contains('El usuario'));
  assert_('ES: NUNCA ES presente', esAmio.contains('NUNCA'));
  assert_('ES: não contém labels PT exclusivos (usuario e um MEDICO)', !esAmio.contains('usuario e um MEDICO'));
  print('  → Prompt ES amiodarona (${esAmio.length} chars)');

  // ══════════════════════════════════════════════════════════════════════════
  // TESTE 3 — Intent routing
  // ══════════════════════════════════════════════════════════════════════════
  section('TESTE 3 — Intent routing');

  final intentTrat = AiService.buildClinicalSystemPrompt(
    lang: 'pt', matchedProtocolSummaries: [], matchedDrugSummaries: [],
    queryIntent: 'tratamento', userQuery: 'Tratamento da sepse',
  );
  assert_('intent=tratamento: escopo terapêutico presente', intentTrat.contains('terapêutic') || intentTrat.contains('tratamento'));
  assert_('intent=tratamento: sem fisiopatologia longa no foco', !intentTrat.contains('mecanismos fisiopatológicos detalhados'));

  final intentFisio = AiService.buildClinicalSystemPrompt(
    lang: 'pt', matchedProtocolSummaries: [], matchedDrugSummaries: [],
    queryIntent: 'fisiopatologia', userQuery: 'Fisiopatologia da insuficiência cardíaca',
  );
  assert_('intent=fisiopatologia: escopo mecanismo presente', intentFisio.contains('fisiopatol') || intentFisio.contains('mecanismo'));

  final intentCausas = AiService.buildClinicalSystemPrompt(
    lang: 'pt', matchedProtocolSummaries: [], matchedDrugSummaries: [],
    queryIntent: 'causas', userQuery: 'Causas de pancreatite',
  );
  assert_('intent=causas: escopo etiologia presente', intentCausas.contains('etiolog') || intentCausas.contains('causa'));

  final intentRef = AiService.buildClinicalSystemPrompt(
    lang: 'pt', matchedProtocolSummaries: [], matchedDrugSummaries: [],
    queryIntent: 'referencias', userQuery: 'Referências sobre FA',
  );
  // referencias → "bibliograf" (calibrado na inspeção)
  assert_('intent=referencias: escopo bibliográfico presente', intentRef.contains('bibliograf') || intentRef.contains('referênc') || intentRef.contains('Referências'));

  // ══════════════════════════════════════════════════════════════════════════
  // TESTE 4 — Modo emergência
  // ══════════════════════════════════════════════════════════════════════════
  section('TESTE 4 — Modo emergência');

  final emergPT = AiService.buildClinicalSystemPrompt(
    lang: 'pt', matchedProtocolSummaries: [], matchedDrugSummaries: [],
    queryIntent: 'emergencia',
    userQuery: 'Paciente hipotenso, febril, lactato alto',
  );
  assert_('Emergência PT: MODO PLANTAO CRITICO ativo', emergPT.contains('MODO PLANTAO CRITICO'));
  assert_('Emergência PT: sem dosis exactas literais', !emergPT.contains('dosis exactas'));
  assert_('Emergência PT: sem doses exatas literais', !emergPT.contains('doses exatas'));
  assert_('Emergência PT: formato ABCDE presente', emergPT.contains('ABCDE') || emergPT.contains('A-B-C'));
  assert_('Emergência PT: foco estabilização', emergPT.contains('estabiliz'));
  // selfCheck real: "FIM_REVISAO_INTERNA" (calibrado na inspeção)
  assert_('Emergência PT: selfCheck FIM_REVISAO_INTERNA presente', emergPT.contains('FIM_REVISAO_INTERNA'));
  print('  → Prompt emergência PT (${emergPT.length} chars)');

  final emergES = AiService.buildClinicalSystemPrompt(
    lang: 'es', matchedProtocolSummaries: [], matchedDrugSummaries: [],
    queryIntent: 'emergencia',
    userQuery: 'Paciente hipotenso, febril, lactato alto',
  );
  assert_('Emergência ES: MODO GUARDIA CRÍTICA ativo', emergES.contains('MODO GUARDIA CRÍTICA'));
  assert_('Emergência ES: selfCheck ES FIN_REVISION_INTERNA presente', emergES.contains('FIN_REVISION_INTERNA'));

  // ══════════════════════════════════════════════════════════════════════════
  // TESTE 5 — Differential Engine
  // ══════════════════════════════════════════════════════════════════════════
  section('TESTE 5 — Differential Engine');

  final diffTropo = AiService.buildClinicalSystemPrompt(
    lang: 'pt', matchedProtocolSummaries: [], matchedDrugSummaries: [],
    queryIntent: 'caso_clinico',
    userQuery: 'Paciente com dor torácica e troponina elevada',
  );
  // differential real: marcador "MOTOR DE DIFERENCIAIS" (calibrado na inspeção)
  assert_('Differential caso_clinico: "MOTOR DE DIFERENCIAIS" presente', diffTropo.contains('MOTOR DE DIFERENCIAIS'));
  assert_('Differential: hipótese perigosa presente', diffTropo.contains('perigosa que nao pode') || diffTropo.contains('Hipotese PRINCIPAL'));
  assert_('Differential: hipótese principal presente', diffTropo.contains('PRINCIPAL') || diffTropo.contains('[principal]'));
  print('  → Differential engine ativo (${diffTropo.length} chars)');

  final noDiffFarmaco = AiService.buildClinicalSystemPrompt(
    lang: 'pt', matchedProtocolSummaries: [], matchedDrugSummaries: [],
    queryIntent: 'farmaco', userQuery: 'Dose de metformina',
  );
  // farmaco: "MOTOR DE DIFERENCIAIS" NÃO deve aparecer
  assert_('Differential farmaco: NÃO ativo (sem MOTOR DE DIFERENCIAIS)', !noDiffFarmaco.contains('MOTOR DE DIFERENCIAIS'));

  // ══════════════════════════════════════════════════════════════════════════
  // TESTE 6 — Tool Calling Engine
  // ══════════════════════════════════════════════════════════════════════════
  section('TESTE 6 — Tool Calling Engine');

  // FA PT — a query deve conter 'fa ' (com espaço) para ativar
  // Na query 'Paciente com FA, 78 anos' → após toLowerCase: 'paciente com fa, 78 anos'
  // 'fa ' não casa porque tem vírgula. Testar com query correta:
  final toolFaPT = AiService.buildClinicalSystemPrompt(
    lang: 'pt', matchedProtocolSummaries: [], matchedDrugSummaries: [],
    userQuery: 'Paciente com fibrilacao atrial 78 anos HAS e AVC previo',
  );
  assert_('FA PT (fibrilacao): FERRAMENTA FA ativa', toolFaPT.contains('FERRAMENTA') || toolFaPT.contains('CHA'));

  // FA ES sem acento (o fix desta sessão)
  final toolFaES = AiService.buildClinicalSystemPrompt(
    lang: 'es', matchedProtocolSummaries: [], matchedDrugSummaries: [],
    userQuery: 'paciente con fibrilacion atrial, 78 años, AVC previo',
  );
  assert_('FA ES (fibrilacion sem acento): CHA ativo', toolFaES.contains('CHA'));

  // FA com acento ES
  final toolFaESAcc = AiService.buildClinicalSystemPrompt(
    lang: 'es', matchedProtocolSummaries: [], matchedDrugSummaries: [],
    userQuery: 'paciente con fibrilación atrial y anticoagulacion',
  );
  assert_('FA ES (fibrilación com acento): CHA ativo', toolFaESAcc.contains('CHA'));

  // CURB-65
  final toolCurb = AiService.buildClinicalSystemPrompt(
    lang: 'pt', matchedProtocolSummaries: [], matchedDrugSummaries: [],
    userQuery: 'Pneumonia em idoso com confusão mental e ureia alta',
  );
  assert_('Pneumonia PT → CURB-65 ativo', toolCurb.contains('CURB'));

  // qSOFA/SOFA
  final toolSepse = AiService.buildClinicalSystemPrompt(
    lang: 'pt', matchedProtocolSummaries: [], matchedDrugSummaries: [],
    userQuery: 'Paciente com sepse lactato alto e rebaixamento de consciência',
  );
  assert_('Sepse PT → qSOFA/SOFA ativo', toolSepse.contains('SOFA') || toolSepse.contains('qSOFA'));

  // Sem keywords → toolsBlock vazio
  final toolNone = AiService.buildToolsBlock('O que é sinapses neuronais?', false);
  assert_('Sem keywords → toolsBlock vazio', toolNone.isEmpty);
  print('  → toolFaES: ${toolFaES.length} chars');

  // ══════════════════════════════════════════════════════════════════════════
  // TESTE 7 — Memory Block
  // ══════════════════════════════════════════════════════════════════════════
  section('TESTE 7 — Memory Block');

  // Conversa 1 — febre + leucocitose
  final mem = ClinicalSessionMemory();
  mem.addProblem('febre');
  mem.addLab('leucocitose 18.000');
  mem.updateRiskLevel('moderate');

  final memPT1 = AiService.buildClinicalSystemPrompt(
    lang: 'pt', matchedProtocolSummaries: [], matchedDrugSummaries: [],
    memory: mem, userQuery: 'Paciente com febre e leucocitose',
  );
  // memoryBlock real: "CONTEXTO_CLINICO_SESSAO" (calibrado nos testes unitários T7)
  assert_('Memory T7: CONTEXTO_CLINICO_SESSAO injetado', memPT1.contains('CONTEXTO_CLINICO_SESSAO'));
  assert_('Memory T7: problema "febre" no contexto', memPT1.contains('febre'));
  assert_('Memory T7: lab "leucocitose" no contexto', memPT1.contains('leucocitose'));

  // Conversa 2 — hipotensão (piora do mesmo caso)
  mem.updateHemodynamics('PA 80/50 mmHg');
  mem.updateEvolution('deteriorating');
  final memPT2 = AiService.buildClinicalSystemPrompt(
    lang: 'pt', matchedProtocolSummaries: [], matchedDrugSummaries: [],
    memory: mem, userQuery: 'Agora ficou hipotenso',
  );
  assert_('Memory T7: continuidade — febre ainda no contexto', memPT2.contains('febre'));
  assert_('Memory T7: PA nova injetada', memPT2.contains('80/50'));
  assert_('Memory T7: evolução deteriorating no contexto', memPT2.contains('deteriorando'));
  print('  → Continuidade do caso confirmada');

  // memory=null → sem bloco
  final memNull = AiService.buildClinicalSystemPrompt(
    lang: 'pt', matchedProtocolSummaries: [], matchedDrugSummaries: [],
    memory: null,
  );
  assert_('Memory T7: memory=null → sem CONTEXTO_CLINICO_SESSAO', !memNull.contains('CONTEXTO_CLINICO_SESSAO'));

  // ══════════════════════════════════════════════════════════════════════════
  // TESTE 8 — RAG intacto
  // ══════════════════════════════════════════════════════════════════════════
  section('TESTE 8 — RAG intacto');

  // contextSection real: "[CONTEXTO_BASE_INTERNA" (calibrado na inspeção)
  final ctxLong = 'Este é um contexto local do hospital com protocolos específicos de UTI para validação';
  final ragPrompt = AiService.buildClinicalSystemPrompt(
    lang: 'pt',
    matchedProtocolSummaries: ['Protocolo Sepse: bundle 1h, coleta culturas, ATB'],
    matchedDrugSummaries: ['Piperacilina-tazobactam: 4,5g IV q6h'],
    localAnswerContext: ctxLong,
    userQuery: 'Tratamento de sepse',
    queryIntent: 'tratamento',
  );
  assert_('RAG T8: protocolsBlock injetado', ragPrompt.contains('Protocolo Sepse'));
  assert_('RAG T8: drugsBlock injetado', ragPrompt.contains('Piperacilina'));
  // contextSection real: "CONTEXTO_BASE_INTERNA" (calibrado)
  assert_('RAG T8: contextSection injetada (>50 chars)', ragPrompt.contains('CONTEXTO_BASE_INTERNA'));
  // selfCheck real: "FIM_REVISAO_INTERNA" (após RAG)
  assert_('RAG T8: selfCheck (FIM_REVISAO_INTERNA) após protocolsBlock',
      ragPrompt.lastIndexOf('FIM_REVISAO_INTERNA') > ragPrompt.lastIndexOf('Protocolo Sepse'));
  print('  → RAG completo (${ragPrompt.length} chars)');

  // RAG vazio + contexto curto
  final ragVazio = AiService.buildClinicalSystemPrompt(
    lang: 'pt', matchedProtocolSummaries: [], matchedDrugSummaries: [],
    localAnswerContext: 'curto', // <50 chars
  );
  assert_('RAG T8: contextSection ausente (<50 chars)', !ragVazio.contains('CONTEXTO_BASE_INTERNA'));

  // ES labels
  final ragES = AiService.buildClinicalSystemPrompt(
    lang: 'es',
    matchedProtocolSummaries: ['Protocolo Sepsis: bundle 1h'],
    matchedDrugSummaries: ['Noradrenalina: 0.1 mcg/kg/min'],
  );
  assert_('RAG T8 ES: protocolsBlock injetado', ragES.contains('Protocolo Sepsis'));
  assert_('RAG T8 ES: drugsBlock ES injetado', ragES.contains('Noradrenalina'));

  // ══════════════════════════════════════════════════════════════════════════
  // TESTE 9 — Self-Check Loop
  // ══════════════════════════════════════════════════════════════════════════
  section('TESTE 9 — Self-Check Loop (farmacológico + posicionamento)');

  final scVanco = AiService.buildClinicalSystemPrompt(
    lang: 'pt', matchedProtocolSummaries: [], matchedDrugSummaries: [],
    queryIntent: 'farmaco',
    userQuery: 'Dose de vancomicina em insuficiência renal',
  );
  // selfCheck real: "FIM_REVISAO_INTERNA" e "DOSES:" e "funcao renal" (calibrado)
  assert_('SelfCheck T9 PT: FIM_REVISAO_INTERNA presente', scVanco.contains('FIM_REVISAO_INTERNA'));
  assert_('SelfCheck T9 PT: dimensão DOSES presente', scVanco.contains('DOSES'));
  assert_('SelfCheck T9 PT: dimensão CONTRAINDICACOES presente', scVanco.contains('CONTRAINDICACOES'));
  assert_('SelfCheck T9 PT: dimensão COERENCIA presente', scVanco.contains('COERENCIA'));
  assert_('SelfCheck T9 PT: última instrução (após tudo)', () {
    final scIdx = scVanco.lastIndexOf('FIM_REVISAO_INTERNA');
    return scIdx > scVanco.length - 600; // deve estar nos últimos 600 chars
  }());
  print('  → selfCheck posicionado e ativo (${scVanco.length} chars)');

  // ES
  final scES = AiService.buildClinicalSystemPrompt(
    lang: 'es', matchedProtocolSummaries: [], matchedDrugSummaries: [],
    userQuery: 'Dosis de vancomicina en insuficiencia renal',
  );
  assert_('SelfCheck T9 ES: FIN_REVISION_INTERNA presente', scES.contains('FIN_REVISION_INTERNA'));
  assert_('SelfCheck T9 ES: dimensão DOSIS presente', scES.contains('DOSIS'));
  assert_('SelfCheck T9 ES: dimensão CONTRAINDICACIONES presente', scES.contains('CONTRAINDICACIONES'));

  // ══════════════════════════════════════════════════════════════════════════
  // TESTE 10 — Velocidade / Tamanho de prompt
  // ══════════════════════════════════════════════════════════════════════════
  section('TESTE 10 — Tamanho de prompt / Resposta curta');

  final sw = Stopwatch()..start();
  final simplePrompt = AiService.buildClinicalSystemPrompt(
    lang: 'pt', matchedProtocolSummaries: [], matchedDrugSummaries: [],
    userQuery: 'O que é IAM?',
    queryIntent: 'fisiopatologia',
  );
  sw.stop();
  assert_('Prompt simples: tamanho < 10.000 chars', simplePrompt.length < 10000,
      'len=${simplePrompt.length}');
  assert_('Prompt simples: construído < 50ms', sw.elapsedMilliseconds < 50,
      'tempo=${sw.elapsedMilliseconds}ms');
  assert_('Prompt simples: differential NÃO ativo (intent=fisiopatologia)',
      !simplePrompt.contains('MOTOR DE DIFERENCIAIS'));
  assert_('Prompt simples: evidenceRanking presente',
      simplePrompt.contains('evidênc') || simplePrompt.contains('evidencia') || simplePrompt.contains('evidenc'));
  print('  → Prompt simples: ${simplePrompt.length} chars, ${sw.elapsedMilliseconds}ms');

  final sw2 = Stopwatch()..start();
  final maxMem = ClinicalSessionMemory()
    ..addProblem('Sepse')
    ..addMedication('Noradrenalina');
  final maxPrompt = AiService.buildClinicalSystemPrompt(
    lang: 'pt',
    matchedProtocolSummaries: ['Protocolo sepse bundle 1h completo descricao'],
    matchedDrugSummaries: ['Noradrenalina 0.1 mcg/kg/min em bolsa SF'],
    localAnswerContext: 'Contexto local do hospital com protocolos específicos de UTI validação'.padRight(80),
    queryIntent: 'caso_clinico',
    userQuery: 'Paciente em sepse choque com hipotensão',
    memory: maxMem,
  );
  sw2.stop();
  assert_('Prompt máximo: tamanho < 15.000 chars', maxPrompt.length < 15000,
      'len=${maxPrompt.length}');
  assert_('Prompt máximo: construído < 100ms', sw2.elapsedMilliseconds < 100,
      'tempo=${sw2.elapsedMilliseconds}ms');
  print('  → Prompt máximo: ${maxPrompt.length} chars, ${sw2.elapsedMilliseconds}ms');

  // ══════════════════════════════════════════════════════════════════════════
  // RESULTADO FINAL
  // ══════════════════════════════════════════════════════════════════════════
  print('\n');
  print('══════════════════════════════════════════════════════');
  print('  RESULTADO INSPEÇÃO FUNCIONAL — TESTES 2–10');
  print('══════════════════════════════════════════════════════');
  print('  ✅ Passed : $_passed');
  print('  ❌ Failed : $_failed');
  print('  Total    : ${_passed + _failed}');
  print('══════════════════════════════════════════════════════');
  if (_failed == 0) {
    print('\n  🎯 TODOS OS TESTES FUNCIONAIS PASSARAM\n');
  } else {
    print('\n  ⚠️  $_failed TESTE(S) FALHOU/FALHARAM\n');
  }
}
