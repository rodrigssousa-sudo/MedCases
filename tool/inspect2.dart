// ignore_for_file: avoid_print
import 'package:flutter_app/services/ai_service.dart';

void main() {
  // 1) farmaco — onde aparece "perigosa"?
  final farmaco = AiService.buildClinicalSystemPrompt(
    lang: 'pt', matchedProtocolSummaries: [], matchedDrugSummaries: [],
    queryIntent: 'farmaco', userQuery: 'Dose de metformina',
  );
  final pidx = farmaco.indexOf('perigosa');
  print('=== farmaco: "perigosa" em idx $pidx ===');
  if (pidx > 0) {
    print(farmaco.substring(pidx - 80, pidx + 120));
  }
  print('');

  // 2) fisiopatologia
  final fisio = AiService.buildClinicalSystemPrompt(
    lang: 'pt', matchedProtocolSummaries: [], matchedDrugSummaries: [],
    queryIntent: 'fisiopatologia', userQuery: 'O que é IAM?',
  );
  final fidx = fisio.indexOf('perigosa');
  print('=== fisiopatologia: "perigosa" em idx $fidx ===');
  if (fidx > 0) {
    print(fisio.substring(fidx - 80, fidx + 120));
  }
  print('');

  // 3) caso_clinico — confirmar que perigosa aparece no bloco diferencial
  final caso = AiService.buildClinicalSystemPrompt(
    lang: 'pt', matchedProtocolSummaries: [], matchedDrugSummaries: [],
    queryIntent: 'caso_clinico', userQuery: 'Dor torácica troponina elevada',
  );
  final cidx = caso.indexOf('perigosa');
  print('=== caso_clinico: "perigosa" em idx $cidx ===');
  if (cidx > 0) {
    print(caso.substring(cidx - 80, cidx + 120));
  }

  // 4) Verificar qual módulo contém "perigosa" — grep nos módulos
  print('\n=== Onde "perigosa" está nos módulos ===');
  // clinicalReasoning contém "perigosa"? (módulo 2 — sempre presente)
  final alwaysOn = AiService.buildClinicalSystemPrompt(
    lang: 'pt', matchedProtocolSummaries: [], matchedDrugSummaries: [],
    queryIntent: 'farmaco',
  );
  print('farmaco "perigosa": idx=${alwaysOn.indexOf('perigosa')}');
  print('farmaco length: ${alwaysOn.length}');
}
