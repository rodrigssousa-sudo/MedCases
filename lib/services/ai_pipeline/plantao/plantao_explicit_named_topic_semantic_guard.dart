/// Narrow post-model guard for explicitly named pathology/syndrome requests.
///
/// This owner never invents a medication, dose, diagnosis, laboratory result,
/// procedure or recommendation. It only removes accidental differential
/// presentation when the user already supplied the clinical entity.
///
/// Symptom/open-diagnostic queries and explicit differential requests are
/// preserved byte-for-byte.
class PlantaoExplicitNamedTopicSemanticGuard {
  const PlantaoExplicitNamedTopicSemanticGuard._();

  static String materialize({
    required String userInput,
    required String assistantOutput,
    required String languageCode,
  }) {
    if (assistantOutput.trim().isEmpty) return assistantOutput;

    final hygienicOutput = _applyOutputHygiene(
      userInput: userInput,
      assistantOutput: assistantOutput,
      languageCode: languageCode,
    );

    if (!_isExplicitNamedTopic(userInput)) return hygienicOutput;
    if (_requestsDifferential(userInput)) return hygienicOutput;
    if (!_hasDifferentialPresentation(hygienicOutput)) {
      return hygienicOutput;
    }

    final title = _displayTopic(userInput);
    final isEs = languageCode.toLowerCase().startsWith('es');
    final out = <String>[];
    var titleWritten = false;

    for (final raw in hygienicOutput.split('\n')) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;
      final folded = _fold(trimmed);

      if (!titleWritten && trimmed.startsWith('🟥')) {
        out.add('🟥 ${title.toUpperCase()}');
        titleWritten = true;
        continue;
      }

      if (_isDifferentialCandidateLine(folded)) continue;

      if (folded.contains('diferenciales prioritarios') ||
          folded.contains('diferenciais prioritarios')) {
        continue;
      }

      if (isEs &&
          (folded == '🚨 evaluacion inicial:' ||
              folded == 'evaluacion inicial:')) {
        out.add('🚨 Conducta inmediata:');
        continue;
      }

      if (!isEs &&
          (folded == '🚨 avaliacao inicial:' ||
              folded == 'avaliacao inicial:')) {
        out.add('🚨 Conduta imediata:');
        continue;
      }

      out.add(trimmed);
    }

    if (!titleWritten) {
      out.insert(0, '🟥 ${title.toUpperCase()}');
    }

    _removeEmptyKeySection(out);

    if (out.length < 2) return hygienicOutput;
    return out.join('\n');
  }

  static String _applyOutputHygiene({
    required String userInput,
    required String assistantOutput,
    required String languageCode,
  }) {
    final isEs = languageCode.toLowerCase().startsWith('es');
    final pleuralContext = _isPleuralContext(userInput, assistantOutput);
    final source = assistantOutput.split('\n');
    final out = <String>[];
    var changed = false;

    for (final raw in source) {
      final folded = _fold(raw);

      if (_containsUnresolvedDoseRoutePlaceholder(folded)) {
        changed = true;
        continue;
      }

      var next = raw;
      if (pleuralContext) {
        final replacement = isEs ? 'toracocentesis' : 'toracocentese';
        next = next.replaceAll(
          RegExp(r'\bparacentesis\b', caseSensitive: false),
          replacement,
        );
        next = next.replaceAll(
          RegExp(r'\bparacentese\b', caseSensitive: false),
          replacement,
        );
      }

      if (next != raw) changed = true;
      out.add(next);
    }

    if (!changed) return assistantOutput;

    _removeEmptyMedicationSection(out);
    return out.join('\n');
  }

  static bool _isPleuralContext(String userInput, String assistantOutput) {
    final value = _fold('$userInput $assistantOutput');
    const markers = <String>[
      'derrame pleural',
      'pleural effusion',
      'efusao pleural',
      'infeccion pleural',
      'infeccao pleural',
      'pleural infection',
      'empiema',
      'empyema',
      'derrame parapneumonico',
      'parapneumonic effusion',
      'liquido pleural',
      'espacio pleural',
      'espaco pleural',
    ];
    return markers.any(value.contains);
  }

  static bool _containsUnresolvedDoseRoutePlaceholder(String folded) {
    const placeholders = <String>[
      '+ dosis segun cuadro clinico + via',
      '+ dosis segun cuadro + via',
      '+ dosis + via',
      '+ dose conforme quadro clinico + via',
      '+ dose segundo quadro clinico + via',
      '+ dose conforme quadro + via',
      '+ dose + via',
    ];
    return placeholders.any(folded.contains);
  }

  static void _removeEmptyMedicationSection(List<String> lines) {
    for (var i = lines.length - 1; i >= 0; i--) {
      final folded = _fold(lines[i]);
      final isMedicationHeader = folded == '💊 tratamiento farmacologico:' ||
          folded == 'tratamiento farmacologico:' ||
          folded == '💊 tratamento farmacologico:' ||
          folded == 'tratamento farmacologico:';
      if (!isMedicationHeader) continue;

      var hasContent = false;
      for (var j = i + 1; j < lines.length; j++) {
        final next = lines[j].trim();
        if (_isSectionHeader(next)) break;
        if (next.isNotEmpty) {
          hasContent = true;
          break;
        }
      }

      if (!hasContent) {
        lines.removeAt(i);
        while (i < lines.length && lines[i].trim().isEmpty) {
          lines.removeAt(i);
        }
      }
    }
  }

  static bool _requestsDifferential(String input) {
    final value = _fold(input);
    const markers = <String>[
      'diagnostico diferencial',
      'diferenciales',
      'diferenciais',
      'posibilidades',
      'possibilidades',
      'hipotesis',
      'hipoteses',
      'que puede ser',
      'o que pode ser',
      'causas de ',
      'causas posibles',
      'causas possiveis',
    ];
    return markers.any(value.contains);
  }

  static bool _hasDifferentialPresentation(String output) {
    final value = _fold(output);
    if (value.contains('diferenciales prioritarios') ||
        value.contains('diferenciais prioritarios')) {
      return true;
    }
    for (final line in output.split('\n')) {
      if (_isDifferentialCandidateLine(_fold(line))) return true;
    }
    return false;
  }

  static bool _isDifferentialCandidateLine(String folded) {
    final value = folded.replaceFirst(RegExp(r'^[*•\-]\s*'), '').trimLeft();

    return RegExp(r'^(posibilidad|possibilidade)\s+[1-9]\s*:')
            .hasMatch(value) ||
        value.startsWith('hipotesis principal:') ||
        value.startsWith('hipotese principal:') ||
        value.startsWith('diferenciales prioritarios:') ||
        value.startsWith('diferenciais prioritarios:') ||
        value.startsWith('no perder:') ||
        value.startsWith('nao perder:') ||
        value.startsWith('otros:') ||
        value.startsWith('outros:');
  }

  static bool _isExplicitNamedTopic(String input) {
    if (_requestsDifferential(input)) return false;

    final value = _stripTaskPrefix(_fold(input));
    if (value.isEmpty) return false;

    final tokens =
        value.split(RegExp(r'\s+')).where((token) => token.isNotEmpty).toList();
    if (tokens.isEmpty || tokens.length > 8) return false;

    const exactAliases = <String>{
      'iam',
      'sca',
      'stemi',
      'nstemi',
      'tep',
      'epoc',
      'dpoc',
      'avc',
      'drc',
      'pcr',
      'cad',
      'dka',
      'hhs',
    };
    if (exactAliases.contains(value)) return true;

    const symptomSignals = <String>[
      'dolor toracico',
      'dolor abdominal',
      'dor toracica',
      'dor abdominal',
      'dispneia',
      'disnea',
      'fiebre',
      'febre',
      'cefalea',
      'tontura',
      'mareo',
      'nausea',
      'vomito',
      'tos',
      'palpitaciones',
      'palpitacoes',
      'sincope',
    ];
    if (symptomSignals.any(value.contains)) return false;

    const pathologySignals = <String>[
      'sindrome',
      'litiasis',
      'litiase',
      'itiase',
      'itis',
      'osis',
      'emia',
      'patia',
      'infarto',
      'cancer',
      'carcinoma',
      'neumotorax',
      'pneumotorax',
      'hemotorax',
      'sepsis',
      'shock',
      'choque',
      'asma',
      'diabetes',
      'hipertens',
      'insuficien',
      'enfermedad',
      'doenca',
      'tromb',
      'embolia',
      'aneurisma',
      'diseccion',
      'disseccao',
      'cirrosis',
      'cirrose',
      'fibrilacion',
      'fibrilacao',
      'taquicardia',
      'bradicardia',
      'meningit',
      'pneumonia',
      'neumonia',
      'fractura',
      'fratura',
      'ulcera',
      'hepatit',
      'pancreat',
      'colecist',
      'coledoc',
    ];

    return pathologySignals.any(value.contains);
  }

  static String _displayTopic(String input) {
    var value = input.trim();
    value = value.replaceFirst(
      RegExp(
        r'^(manejo|tratamiento|tratamento|conduta|conducta|protocolo|'
        r'diagnostico|diagnóstico|orientacion|orientación|orientacao|orientação)'
        r'\s*(de|do|da|del|en|em|sobre)?\s*',
        caseSensitive: false,
      ),
      '',
    );
    value = value.replaceAll(RegExp(r'^[¿¡\s]+'), '');
    value = value.replaceAll(RegExp(r'[\s?!.,;:]+$'), '');
    return value.trim().isEmpty ? input.trim() : value.trim();
  }

  static String _stripTaskPrefix(String value) {
    return value
        .replaceFirst(
          RegExp(
            r'^(manejo|tratamiento|tratamento|conduta|conducta|protocolo|'
            r'diagnostico|orientacion|orientacao)\s*'
            r'(de|do|da|del|en|em|sobre)?\s*',
          ),
          '',
        )
        .trim();
  }

  static void _removeEmptyKeySection(List<String> lines) {
    for (var i = lines.length - 1; i >= 0; i--) {
      final folded = _fold(lines[i]);
      final isKeyHeader = folded == '🔑 puntos clave:' ||
          folded == 'puntos clave:' ||
          folded == '🔑 pontos-chave:' ||
          folded == 'pontos-chave:';
      if (!isKeyHeader) continue;

      var hasContent = false;
      for (var j = i + 1; j < lines.length; j++) {
        final next = lines[j].trim();
        if (_isSectionHeader(next)) break;
        if (next.isNotEmpty) {
          hasContent = true;
          break;
        }
      }
      if (!hasContent) lines.removeAt(i);
    }
  }

  static bool _isSectionHeader(String line) {
    final folded = _fold(line);
    return folded.startsWith('🚨 ') ||
        folded.startsWith('💊 ') ||
        folded.startsWith('🔑 ') ||
        folded.startsWith('🚩 ') ||
        folded.startsWith('📌 ');
  }

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
