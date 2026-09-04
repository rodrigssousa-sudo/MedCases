/// Deterministic semantic core for a bare generic ACS/AMI request in Plantão.
///
/// Scope is intentionally narrow: only bare aliases such as `IAM`, `SCA`,
/// `infarto` and their exact PT/ES/EN equivalents. Modifier-rich or suspected
/// cases remain model-driven and are not rewritten here.
///
/// Pharmacology is deliberately NOT owned here. This materializer emits only
/// the pharmacology section heading; PlantaoClinicalRegimenOutputGuard remains
/// the frozen numeric/therapeutic authority that fills that section afterwards.
abstract final class PlantaoGenericAcsWholeResponseSemanticCore {
  static String materialize({
    required String userInput,
    required String assistantOutput,
    required String languageCode,
  }) {
    if (assistantOutput.isEmpty || !_isBareGenericAcs(userInput)) {
      return assistantOutput;
    }

    return languageCode.toLowerCase() == 'es' ? _es : _pt;
  }

  static const String _pt = '''🟥 INFARTO AGUDO DO MIOCÁRDIO
🚨 Conduta imediata:
• Monitorização contínua e avaliação da estabilidade hemodinâmica
• Realizar ECG de 12 derivações e definir a estratégia de reperfusão conforme o traçado e o contexto clínico
💊 Tratamento farmacológico:
🔑 Pontos-chave:
• Considerar contraindicações e risco hemorrágico antes da terapia antitrombótica
• Reavaliar sinais vitais, isquemia recorrente e complicações mecânicas ou elétricas
🚩 RED FLAGS:
• Instabilidade hemodinâmica ou choque
• Arritmias graves
• Sangramento ativo ou contraindicação relevante à terapia antitrombótica
📌 Realizar ECG e troponina de alta sensibilidade; se houver indicação de reperfusão urgente, não atrasá-la aguardando biomarcadores''';

  static const String _es = '''🟥 INFARTO AGUDO DE MIOCARDIO
🚨 Conducta inmediata:
• Monitorización continua y evaluación de la estabilidad hemodinámica
• Realizar ECG de 12 derivaciones y definir la estrategia de reperfusión según el trazado y el contexto clínico
💊 Tratamiento farmacológico:
🔑 Puntos clave:
• Considerar contraindicaciones y riesgo hemorrágico antes de la terapia antitrombótica
• Reevaluar signos vitales, isquemia recurrente y complicaciones mecánicas o eléctricas
🚩 RED FLAGS:
• Inestabilidad hemodinámica o shock
• Arritmias graves
• Sangrado activo o contraindicación relevante para la terapia antitrombótica
📌 Realizar ECG y troponina de alta sensibilidad; si existe indicación de reperfusión urgente, no retrasarla esperando biomarcadores''';

  static bool _isBareGenericAcs(String value) => const <String>{
    'iam',
    'sca',
    'infarto',
    'infarto agudo do miocardio',
    'infarto agudo de miocardio',
    'infarto de miocardio',
    'sindrome coronariana aguda',
    'sindrome coronaria aguda',
    'acute coronary syndrome',
    'myocardial infarction',
  }.contains(_fold(value));

  static String _fold(String value) => value
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('à', 'a')
      .replaceAll('ã', 'a')
      .replaceAll('â', 'a')
      .replaceAll('ä', 'a')
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('ë', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ì', 'i')
      .replaceAll('î', 'i')
      .replaceAll('ï', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ò', 'o')
      .replaceAll('ô', 'o')
      .replaceAll('õ', 'o')
      .replaceAll('ö', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ù', 'u')
      .replaceAll('û', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ç', 'c')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
