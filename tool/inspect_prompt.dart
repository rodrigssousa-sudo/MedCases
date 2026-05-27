// ignore_for_file: avoid_print
import 'package:flutter_app/services/ai_service.dart';

void main() {
  final pt = AiService.buildClinicalSystemPrompt(
    lang: 'pt', matchedProtocolSummaries: [], matchedDrugSummaries: [],
    userQuery: 'Dose de amiodarona?',
  );

  print('=== IDENTIDADE PT (primeiros 400 chars) ===');
  print(pt.substring(0, 400));
  print('');

  print('=== POSIÇÃO selfCheck ===');
  print('REVISÃO_FINAL: ${pt.indexOf('REVISÃO_FINAL')}');
  print('REVISION_FINAL: ${pt.indexOf('REVISION_FINAL')}');
  print('auto-revisão: ${pt.indexOf('auto-revisão')}');
  print('auto-revision: ${pt.indexOf('auto-revision')}');
  print('self-check: ${pt.indexOf('self-check')}');
  print('SELF_CHECK: ${pt.indexOf('SELF_CHECK')}');
  print('revisão: ${pt.indexOf('revisão')}');
  print('INSTRUÇÃO FINAL: ${pt.indexOf('INSTRUÇÃO FINAL')}');

  print('');
  print('=== ÚLTIMOS 500 chars PT ===');
  print(pt.substring(pt.length - 500));
  print('');

  final es = AiService.buildClinicalSystemPrompt(
    lang: 'es', matchedProtocolSummaries: [], matchedDrugSummaries: [],
    userQuery: 'Dosis de amiodarona?',
  );
  print('=== IDENTIDADE ES (primeiros 400 chars) ===');
  print(es.substring(0, 400));
  print('');
  print('=== ÚLTIMOS 500 chars ES ===');
  print(es.substring(es.length - 500));
  print('');

  // contextSection
  final withCtx = AiService.buildClinicalSystemPrompt(
    lang: 'pt',
    matchedProtocolSummaries: [],
    matchedDrugSummaries: [],
    localAnswerContext: 'Este é um contexto local do hospital com protocolos específicos de UTI que é longo o suficiente',
  );
  print('=== contextSection labels (busca RESPOSTA_LOCAL / local / contexto) ===');
  print('RESPOSTA_LOCAL: ${withCtx.indexOf('RESPOSTA_LOCAL')}');
  print('CONTEXTO_LOCAL: ${withCtx.indexOf('CONTEXTO_LOCAL')}');
  print('LOCAL_ANSWER: ${withCtx.indexOf('LOCAL_ANSWER')}');
  // encontra o trecho com o contexto
  final idx = withCtx.indexOf('Este é um contexto');
  if (idx > 0) {
    print('Contexto encontrado em $idx, chars antes: ${withCtx.substring(idx - 60, idx)}');
  }

  // FA PT sem query intent — testar tool
  final fapt = AiService.buildClinicalSystemPrompt(
    lang: 'pt', matchedProtocolSummaries: [], matchedDrugSummaries: [],
    userQuery: 'Paciente com FA, 78 anos, HAS e AVC prévio',
  );
  print('');
  print('=== FA PT — tool ===');
  print('CHA: ${fapt.indexOf('CHA')}');
  print('HAS-BLED: ${fapt.indexOf('HAS-BLED')}');
  print('HERRAMIENTA: ${fapt.indexOf('HERRAMIENTA')}');
  print('FERRAMENTA: ${fapt.indexOf('FERRAMENTA')}');

  // referencias
  final refPT = AiService.buildClinicalSystemPrompt(
    lang: 'pt', matchedProtocolSummaries: [], matchedDrugSummaries: [],
    queryIntent: 'referencias',
  );
  print('');
  print('=== referencias PT — focus ===');
  final rIdx = refPT.indexOf('referênc');
  final rIdx2 = refPT.indexOf('bibliograf');
  final rIdx3 = refPT.indexOf('REFERENCIAS');
  final rIdx4 = refPT.indexOf('Referências');
  print('referênc: $rIdx');
  print('bibliograf: $rIdx2');
  print('REFERENCIAS: $rIdx3');
  print('Referências: $rIdx4');
  if (rIdx > 0) print(refPT.substring(rIdx, rIdx + 200));

  // differential
  final diffPT = AiService.buildClinicalSystemPrompt(
    lang: 'pt', matchedProtocolSummaries: [], matchedDrugSummaries: [],
    queryIntent: 'caso_clinico',
    userQuery: 'Paciente com dor torácica e troponina elevada',
  );
  print('');
  print('=== differential caso_clinico PT ===');
  print('DIFFERENTIAL_ENGINE: ${diffPT.indexOf('DIFFERENTIAL_ENGINE')}');
  print('DIAGNÓSTICO_DIFERENCIAL: ${diffPT.indexOf('DIAGNÓSTICO_DIFERENCIAL')}');
  print('diagnóstico diferencial: ${diffPT.indexOf('diagnóstico diferencial')}');
  print('diferenciais: ${diffPT.indexOf('diferenciais')}');
  final dIdx = diffPT.indexOf('perigo');
  if (dIdx > 0) print('perigo encontrado em $dIdx: ${diffPT.substring(dIdx - 30, dIdx + 100)}');
}
