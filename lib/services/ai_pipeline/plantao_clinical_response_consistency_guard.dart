abstract final class PlantaoClinicalResponseConsistencyGuard {
  static final RegExp _rankHeading = RegExp(
    r'^\s*(?:[-*•]\s*)?(?:\*\*)?'
    r'(?:1ª|1a|1\.|primeira|primera|1er|2ª|2a|2\.|segunda)'
    r'\s+(?:linha|linea|línea)'
    r'(?:\*\*)?\s*:\s*(.*)$',
    caseSensitive: false,
  );

  static String enforce({
    required String userInput,
    required String assistantOutput,
    String? languageCode,
  }) {
    if (assistantOutput.trim().isEmpty) return assistantOutput;

    var result = _neutralizeLegacyRankHeadings(assistantOutput);

    if (_isExplicitNonElevationAcs(userInput)) {
      result = _correctContradictoryAcsDiagnosis(result);
    }

    if (_isExplicitAcuteUncomplicatedDiverticulitis(userInput)) {
      result = _correctAcuteDiverticulitisAuthorityDrift(
        userInput: userInput,
        assistantOutput: result,
        languageCode: languageCode,
      );
    }

    return result;
  }

  static String _neutralizeLegacyRankHeadings(String text) {
    final output = <String>[];

    for (final line
        in text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n')) {
      final match = _rankHeading.firstMatch(line);

      if (match == null) {
        output.add(line);
        continue;
      }

      final inlineContent = (match.group(1) ?? '').trim();

      if (inlineContent.isNotEmpty) {
        output.add('• $inlineContent');
      }
    }

    return output.join('\n');
  }

  static bool _isExplicitAcuteUncomplicatedDiverticulitis(String input) {
    final value = _fold(input);

    final explicitAcute = <String>[
      'diverticulitis aguda',
      'diverticulite aguda',
      'acute diverticulitis',
      'diverticulitis no complicada',
      'diverticulite nao complicada',
      'uncomplicated diverticulitis',
    ].any(value.contains);

    if (!explicitAcute) return false;

    const complicatedSignals = <String>[
      'diverticulitis complicada',
      'diverticulite complicada',
      'complicated diverticulitis',
      'absceso',
      'abscesso',
      'abscess',
      'flegmon',
      'flegmao',
      'phlegmon',
      'perfor',
      'periton',
      'fistul',
      'estenosis',
      'estenose',
      'stricture',
      'obstruccion',
      'obstrucao',
      'obstruction',
      'sepsis',
      'sepse',
      'shock',
      'choque',
    ];

    return !complicatedSignals.any(value.contains);
  }

  static String _correctAcuteDiverticulitisAuthorityDrift({
    required String userInput,
    required String assistantOutput,
    String? languageCode,
  }) {
    final isEs = _isSpanishDiverticulitisContext(
      userInput: userInput,
      assistantOutput: assistantOutput,
      languageCode: languageCode,
    );

    var changed = false;
    var selectiveAntibioticLineMaterialized = assistantOutput
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .any(
          (line) =>
              _fold(line).contains('antibiot') &&
              !_isUnderspecifiedDiverticulitisAntibioticLine(line),
        );
    final out = <String>[];

    for (final line
        in assistantOutput
            .replaceAll('\r\n', '\n')
            .replaceAll('\r', '\n')
            .split('\n')) {
      if (_isUnconditionalDiverticulitisCtDirective(line)) {
        out.add(
          _withOriginalBulletPrefix(
            line,
            isEs
                ? 'TC de abdomen/pelvis: indicada en la primera presentación; también si el diagnóstico es incierto o existe sospecha de complicación. En recurrencia típica ya documentada, no es automática si no hay duda ni signos de complicación.'
                : 'TC de abdome/pelve: indicada na primeira apresentação; também se o diagnóstico for incerto ou houver suspeita de complicação. Em recorrência típica já documentada, não é automática se não houver dúvida nem sinais de complicação.',
          ),
        );
        changed = true;
        continue;
      }

      if (_isFixedUncomplicatedDiverticulitisAntibioticRegimenLine(line)) {
        if (!selectiveAntibioticLineMaterialized) {
          out.add(
            _withOriginalBulletPrefix(
              line,
              isEs
                  ? 'Antibióticos selectivos, no automáticos en toda diverticulitis no complicada: indicarlos si hay inmunocompromiso, fragilidad/complejidad médica, intolerancia oral, empeoramiento clínico, marcadores inflamatorios muy elevados, imagen de mayor riesgo o seguimiento/apoyo no fiable.'
                  : 'Antibióticos seletivos, não automáticos em toda diverticulite não complicada: indicar se houver imunocomprometimento, fragilidade/complexidade clínica, intolerância oral, piora clínica, marcadores inflamatórios muito elevados, imagem de maior risco ou seguimento/apoio não confiável.',
            ),
          );
          selectiveAntibioticLineMaterialized = true;
        }
        changed = true;
        continue;
      }

      if (_isUnderspecifiedDiverticulitisAntibioticLine(line)) {
        out.add(
          _withOriginalBulletPrefix(
            line,
            isEs
                ? 'Antibióticos selectivos, no automáticos en toda diverticulitis no complicada: indicarlos si hay inmunocompromiso, fragilidad/complejidad médica, intolerancia oral, empeoramiento clínico, marcadores inflamatorios muy elevados, imagen de mayor riesgo o seguimiento/apoyo no fiable.'
                : 'Antibióticos seletivos, não automáticos em toda diverticulite não complicada: indicar se houver imunocomprometimento, fragilidade/complexidade clínica, intolerância oral, piora clínica, marcadores inflamatórios muito elevados, imagem de maior risco ou seguimento/apoio não confiável.',
          ),
        );
        selectiveAntibioticLineMaterialized = true;
        changed = true;
        continue;
      }

      out.add(line);
    }

    if (!changed) return assistantOutput;
    return out.join('\n');
  }

  static bool _isUnconditionalDiverticulitisCtDirective(String line) {
    final value = _fold(line);
    if (value.isEmpty) return false;

    final mentionsCt =
        value.contains('tc abdomen') ||
        value.contains('tc de abdomen') ||
        value.contains('tc abdome') ||
        value.contains('tc de abdome') ||
        value.contains('tomografia');
    if (!mentionsCt) return false;

    final explicitDirective = <String>[
      'solicitar tc',
      'solicitar una tc',
      'pedir tc',
      'pedir una tc',
      'realizar tc',
      'realizar una tc',
      'obter tc',
      'fazer tc',
      'solicitar tomografia',
      'pedir tomografia',
      'realizar tomografia',
      'obter tomografia',
      'fazer tomografia',
    ].any(value.contains);

    final implicitConfirmLocalizeDirective =
        value.contains('para confirmar') ||
        value.contains('para localizar') ||
        value.contains('confirmar/localizar') ||
        value.contains('confirmar y localizar') ||
        value.contains('confirmar e localizar');

    final directive = explicitDirective || implicitConfirmLocalizeDirective;
    if (!directive) return false;

    final alreadyConditional = <String>[
      'primera presentacion',
      'primeira apresentacao',
      'first presentation',
      'si el diagnostico',
      'se o diagnostico',
      'if the diagnosis',
      'sospecha de complicacion',
      'suspeita de complicacao',
      'suspected complication',
      'recurrencia',
      'recorrencia',
      'recurrence',
      'si hay duda',
      'se houver duvida',
      'if uncertain',
    ].any(value.contains);

    return !alreadyConditional;
  }

  static bool _isFixedUncomplicatedDiverticulitisAntibioticRegimenLine(
    String line,
  ) {
    final value = _fold(line);

    const antibioticAgents = <String>[
      'metronidazol',
      'metronidazole',
      'ciprofloxacino',
      'ciprofloxacin',
      'levofloxacino',
      'levofloxacin',
      'moxifloxacino',
      'moxifloxacin',
      'amoxicilina-clavulanato',
      'amoxicilina clavulanato',
      'amoxicillin-clavulanate',
      'trimetoprim-sulfametoxazol',
      'trimethoprim-sulfamethoxazole',
    ];

    final mentionsAntibioticAgent = antibioticAgents.any(value.contains);
    if (!mentionsAntibioticAgent) return false;

    return RegExp(
      r'\b\d+(?:[.,]\d+)?\s*(?:mg|g)\b',
      caseSensitive: false,
    ).hasMatch(value);
  }

  static bool _isUnderspecifiedDiverticulitisAntibioticLine(String line) {
    final value = _fold(line);
    if (!value.contains('antibiot')) return false;

    final riskCoverage = <bool>[
      value.contains('inmunocom') || value.contains('imunocom'),
      value.contains('fragil') || value.contains('complex'),
      value.contains('intolerancia oral') ||
          value.contains('nao tolera via oral') ||
          value.contains('no tolera via oral'),
      value.contains('empeor') || value.contains('piora'),
      value.contains('marcador') || value.contains('inflamator'),
      value.contains('imagen') || value.contains('imagem'),
      value.contains('seguimiento') ||
          value.contains('seguimento') ||
          value.contains('follow-up') ||
          value.contains('follow up'),
    ].where((present) => present).length;

    final restrictiveWording = <String>[
      'solo si',
      'solo en',
      'solamente si',
      'apenas se',
      'somente se',
      'so se',
    ].any(value.contains);

    return restrictiveWording || riskCoverage < 5;
  }

  static bool _isSpanishDiverticulitisContext({
    required String userInput,
    required String assistantOutput,
    String? languageCode,
  }) {
    final normalizedLanguage = (languageCode ?? '').trim().toLowerCase();
    if (normalizedLanguage.startsWith('es')) return true;
    if (normalizedLanguage.startsWith('pt')) return false;

    final input = _fold(userInput);
    if (input.contains('diverticulitis')) return true;
    if (input.contains('diverticulite')) return false;

    final output = _fold(assistantOutput);
    return output.contains('conducta inmediata') ||
        output.contains('puntos clave') ||
        output.contains('seguimiento') ||
        output.contains('empeoramiento');
  }

  static String _withOriginalBulletPrefix(String source, String replacement) {
    final match = RegExp(r'^(\s*[-*•]\s*)').firstMatch(source);
    if (match == null) return replacement;
    return '${match.group(1)}$replacement';
  }

  static bool _isExplicitNonElevationAcs(String input) {
    final value = _fold(input);

    final deniesElevation = <String>[
      'sem supradesnivelamento',
      'sem supra de st',
      'sem supra do st',
      'ausencia de supradesnivelamento',
      'nao apresenta supradesnivelamento',
      'sin supradesnivel',
      'sin elevacion del st',
      'no presenta elevacion del st',
      'ausencia de elevacion del st',
    ].any(value.contains);

    final hasDepression = <String>[
      'infradesnivelamento',
      'infra de st',
      'infra do st',
      'depressao do st',
      'depresion del st',
      'descenso del st',
    ].any(value.contains);

    return deniesElevation && hasDepression;
  }

  static String _correctContradictoryAcsDiagnosis(String text) {
    return text.split('\n').map(_correctContradictoryAcsLine).join('\n');
  }

  static String _correctContradictoryAcsLine(String line) {
    final folded = _fold(line);
    final mentionsContradictoryDiagnosis =
        folded.contains('scacest') || folded.contains('stemi');

    if (!mentionsContradictoryDiagnosis) return line;
    if (!_isAffirmativeDiagnosisLine(line, folded)) return line;

    var corrected = line;

    corrected = corrected.replaceAllMapped(
      RegExp(r'\bSCACEST\b', caseSensitive: false),
      (_) => 'SCASEST',
    );
    corrected = corrected.replaceAllMapped(
      RegExp(r'\bSTEMI\b', caseSensitive: false),
      (_) => 'NSTEMI',
    );
    corrected = corrected.replaceAllMapped(
      RegExp(
        r'\bCOM\s+ELEVAÇÃO\s+DO\s+(?:SEGMENTO\s+)?ST\b',
        caseSensitive: false,
      ),
      (_) => 'SEM ELEVAÇÃO DO ST',
    );
    corrected = corrected.replaceAllMapped(
      RegExp(
        r'\bCOM\s+ELEVACAO\s+DO\s+(?:SEGMENTO\s+)?ST\b',
        caseSensitive: false,
      ),
      (_) => 'SEM ELEVAÇÃO DO ST',
    );
    corrected = corrected.replaceAllMapped(
      RegExp(
        r'\bCON\s+ELEVACIÓN\s+DEL\s+(?:SEGMENTO\s+)?ST\b',
        caseSensitive: false,
      ),
      (_) => 'SIN ELEVACIÓN DEL ST',
    );
    corrected = corrected.replaceAllMapped(
      RegExp(
        r'\bCON\s+ELEVACION\s+DEL\s+(?:SEGMENTO\s+)?ST\b',
        caseSensitive: false,
      ),
      (_) => 'SIN ELEVACIÓN DEL ST',
    );

    return corrected;
  }

  static bool _isAffirmativeDiagnosisLine(String line, String folded) {
    final trimmed = line.trimLeft();
    final headingLike =
        trimmed.startsWith('🟥') ||
        trimmed.startsWith('🔴') ||
        trimmed.startsWith('#') ||
        trimmed.startsWith('**') ||
        folded.startsWith('scacest') ||
        folded.startsWith('stemi') ||
        folded.contains('diagnostico') ||
        folded.contains('diagnostico principal');

    if (!headingLike) return false;

    final negated = <String>[
      'nao e scacest',
      'nao sugere scacest',
      'sem criterios para scacest',
      'descartar scacest',
      'excluir scacest',
      'no es scacest',
      'sin criterios para scacest',
      'descartar stemi',
      'rule out stemi',
    ].any(folded.contains);

    return !negated;
  }

  static String _fold(String value) {
    return value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ã', 'a')
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
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
