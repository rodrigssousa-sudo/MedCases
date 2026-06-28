// ignore_for_file: avoid_print
// Descobrir a string de marcação real do differentialEngine
import 'package:medcases/services/ai_service.dart';

void main() {
  // Com differential ativo (caso_clinico)
  final com = AiService.buildClinicalSystemPrompt(
    lang: 'pt', matchedProtocolSummaries: [], matchedDrugSummaries: [],
    queryIntent: 'caso_clinico',
  );

  // Sem differential (farmaco)
  final sem = AiService.buildClinicalSystemPrompt(
    lang: 'pt', matchedProtocolSummaries: [], matchedDrugSummaries: [],
    queryIntent: 'farmaco',
  );

  print('Comprimento COM differential: ${com.length}');
  print('Comprimento SEM differential: ${sem.length}');
  print('Diferença: ${com.length - sem.length} chars');
  print('');

  // Encontrar o trecho que está em "com" mas não em "sem"
  // Pegar a parte extra (após ~sem.length)
  // Na verdade o differential é inserido no meio, então vamos buscar strings
  // que existem em "com" mas não em "sem"

  final candidates = [
    'DIFFERENTIAL_ENGINE',
    'DIAGNOSTICO_DIFERENCIAL',
    'diagnostico diferencial',
    'Motor de Diagnóstico',
    'MOTOR_DIFERENCIAL',
    'diferencial_engine',
    'Engine',
    'INSTRUCAO_DIFERENCIAL',
    'DIAG_DIFF',
    'PASSO_DIFERENCIAL',
  ];

  for (final c in candidates) {
    final inCom = com.contains(c);
    final inSem = sem.contains(c);
    if (inCom != inSem) {
      print('DIFERENÇA ENCONTRADA: "$c" → com=$inCom, sem=$inSem');
    }
  }

  // Encontrar substring única em com vs sem
  // Imprimir trecho do prompt "com" que não existe em "sem"
  // Estratégia: pegar chunks de 50 chars e verificar
  print('\n=== Trecho extra no prompt caso_clinico ===');
  for (int i = 0; i < com.length - 50; i += 10) {
    final chunk = com.substring(i, i + 50);
    if (!sem.contains(chunk)) {
      print('Trecho único em caso_clinico (idx $i): $chunk');
      print('--- contexto: ${com.substring(i > 20 ? i - 20 : 0, i + 150)}');
      print('');
      break; // só o primeiro
    }
  }

  // Também verificar o módulo diretamente no arquivo
  print('=== Contagem de diferenciais no arquivo ===');
  print('"diferenciais" em caso_clinico: ${_countOccurrences(com, 'diferenciais')}');
  print('"diferenciais" em farmaco:      ${_countOccurrences(sem, 'diferenciais')}');
}

int _countOccurrences(String str, String sub) {
  int count = 0;
  int idx = 0;
  while (true) {
    idx = str.indexOf(sub, idx);
    if (idx == -1) break;
    count++;
    idx++;
  }
  return count;
}
