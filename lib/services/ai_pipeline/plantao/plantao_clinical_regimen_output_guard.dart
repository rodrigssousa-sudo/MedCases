import 'contracts/plantao_clinical_regimen_contract.dart';

final class PlantaoClinicalRegimenOutputGuardResult {
  final String text;
  final bool modified;
  final int replacementCount;
  final PlantaoClinicalRegimenScenario? scenario;
  final bool numericClopidogrelDeferred;

  const PlantaoClinicalRegimenOutputGuardResult({
    required this.text,
    required this.modified,
    required this.replacementCount,
    required this.scenario,
    required this.numericClopidogrelDeferred,
  });
}

abstract final class PlantaoClinicalRegimenOutputGuard {
  static PlantaoClinicalRegimenOutputGuardResult enforce({
    required String userInput,
    required String assistantOutput,
    required String languageCode,
    String? patientAge,
  }) {
    if (assistantOutput.isEmpty) {
      return const PlantaoClinicalRegimenOutputGuardResult(
        text: '',
        modified: false,
        replacementCount: 0,
        scenario: null,
        numericClopidogrelDeferred: false,
      );
    }
    final contract = PlantaoClinicalRegimenResolver.resolve(
      query: userInput,
      patientAge: patientAge,
    );
    if (contract == null) {
      return PlantaoClinicalRegimenOutputGuardResult(
        text: assistantOutput,
        modified: false,
        replacementCount: 0,
        scenario: null,
        numericClopidogrelDeferred: false,
      );
    }
    var guarded = assistantOutput;
    var replacements = 0;
    if (contract.scenario == PlantaoClinicalRegimenScenario.acsUnspecified &&
        contract.exposeClopidogrelDecisionSupport &&
        _isBareGenericAcs(userInput)) {
      final next = _materializeGenericSection(guarded, contract, languageCode);
      if (next != guarded) {
        guarded = next;
        replacements++;
      }
    }
    guarded = _normalizeClopidogrel(
      guarded,
      contract,
      languageCode,
      () => replacements++,
    );
    return PlantaoClinicalRegimenOutputGuardResult(
      text: guarded,
      modified: guarded != assistantOutput,
      replacementCount: replacements,
      scenario: contract.scenario,
      numericClopidogrelDeferred: contract.deferNumericClopidogrel,
    );
  }

  static String _materializeGenericSection(
    String text,
    PlantaoClinicalRegimenContract contract,
    String languageCode,
  ) {
    final isEs = languageCode == 'es';
    final lines = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n');
    final canonical = <String>[
      isEs ? 'Tratamiento farmacológico:' : 'Tratamento farmacológico:',
      ...contract.medications.map((m) => '• ${m.line(isEs: isEs)}'),
      '• ${_decisionLine(languageCode)}',
    ];

    final start = _headingIndex(lines, const <String>[
      'tratamento farmacologico',
      'tratamiento farmacologico',
      'tratamento',
      'tratamiento',
    ]);

    if (start >= 0) {
      final end = _nextSection(lines, start + 1);
      final current = lines
          .sublist(start, end)
          .map(_fold)
          .where((x) => x.isNotEmpty)
          .toList();
      final wanted = canonical.map(_fold).where((x) => x.isNotEmpty).toList();
      final prefix = _dropGenericCoreTreatmentLines(lines.sublist(0, start));
      final prefixUnchanged = prefix.length == start;
      if (_same(current, wanted) && prefixUnchanged) {
        return text;
      }
      return _join(<String>[...prefix, ...canonical, ...lines.sublist(end)]);
    }

    final insert = _headingIndex(lines, const <String>[
      'pontos chave',
      'puntos clave',
      'red flags',
      'sinais de alerta',
      'senales de alerta',
      'alerta clinico',
      'proximo',
      'proximo paso',
      'siguiente paso',
      'fechamento',
      'cierre',
    ]);
    final boundary = insert < 0 ? lines.length : insert;
    final prefix = _dropGenericCoreTreatmentLines(lines.sublist(0, boundary));
    return _join(<String>[
      ...prefix,
      ...canonical,
      if (boundary < lines.length) '',
      ...lines.sublist(boundary),
    ]);
  }

  static List<String> _dropGenericCoreTreatmentLines(List<String> lines) {
    return lines
        .where((line) => !_isGenericCoreTreatmentLine(line))
        .toList(growable: false);
  }

  static bool _isGenericCoreTreatmentLine(String line) {
    final q = _fold(line);
    if (q.isEmpty) {
      return false;
    }
    final has300 = RegExp(r'\b300\s*mg\b').hasMatch(q);
    final has600 = RegExp(r'\b600\s*mg\b').hasMatch(q);
    final has80 = RegExp(r'\b80\s*mg\b').hasMatch(q);
    final has75 = RegExp(r'\b75\s*mg\b').hasMatch(q);
    final aspirin =
        q.contains('aas') || q.contains('aspirina') || q.contains('aspirin');
    if (aspirin && has300) {
      return true;
    }
    final atorvastatin =
        q.contains('atorvastatina') || q.contains('atorvastatin');
    if (atorvastatin && has80) {
      return true;
    }
    if (q.contains('clopidogrel') &&
        (q.contains('p2y12') ||
            has300 ||
            has600 ||
            (has75 && _hasLoadingContext(line)))) {
      return true;
    }
    return false;
  }

  static String _normalizeClopidogrel(
    String text,
    PlantaoClinicalRegimenContract contract,
    String languageCode,
    void Function() onReplacement,
  ) {
    if (contract.exposeClopidogrelDecisionSupport) {
      final replacement = _decisionLine(languageCode);
      return text
          .split('\n')
          .map((line) {
            if (!line.toLowerCase().contains('clopidogrel') ||
                _isDecisionLine(line)) {
              return line;
            }
            return _replaceGenericDoseOnce(line, replacement, onReplacement);
          })
          .join('\n');
    }
    if (contract.deferNumericClopidogrel) {
      final replacement = languageCode == 'es'
          ? 'Clopidogrel — carga numérica a definir según la estrategia de reperfusión'
          : 'Clopidogrel — carga numérica a definir conforme estratégia de reperfusão';
      return text
          .split('\n')
          .map((line) {
            if (!line.toLowerCase().contains('clopidogrel')) {
              return line;
            }
            var current = _replaceLocallyCoupledDose(
              line,
              replacement: replacement,
              allowedDoses: const <String>{'300', '600'},
              requireLoadingContext: false,
              onReplacement: onReplacement,
            );
            if (_hasLoadingContext(current)) {
              current = _replaceLocallyCoupledDose(
                current,
                replacement: replacement,
                allowedDoses: const <String>{'75'},
                requireLoadingContext: true,
                onReplacement: onReplacement,
              );
            }
            return current;
          })
          .join('\n');
    }
    PlantaoClinicalRegimenMedication? target;
    for (final item in contract.medications) {
      if (item.drugId == 'clopidogrel') {
        target = item;
        break;
      }
    }
    if (target == null) {
      return text;
    }
    final desired = target.dose.toString();
    final replacement = target.line(isEs: languageCode == 'es');
    return text
        .split('\n')
        .map((line) {
          if (!line.toLowerCase().contains('clopidogrel')) {
            return line;
          }
          if (RegExp(
                '\\b$desired\\s*mg\\b',
                caseSensitive: false,
              ).hasMatch(line) &&
              (desired != '75' || _hasNoLoadContext(line))) {
            return line;
          }
          var current = line;
          final wrong = <String>{'300', '600'}..remove(desired);
          if (wrong.isNotEmpty) {
            current = _replaceLocallyCoupledDose(
              current,
              replacement: replacement,
              allowedDoses: wrong,
              requireLoadingContext: false,
              onReplacement: onReplacement,
            );
          }
          if (desired != '75' && _hasLoadingContext(current)) {
            current = _replaceLocallyCoupledDose(
              current,
              replacement: replacement,
              allowedDoses: const <String>{'75'},
              requireLoadingContext: true,
              onReplacement: onReplacement,
            );
          }
          if (desired == '75' &&
              RegExp(r'\b75\s*mg\b', caseSensitive: false).hasMatch(current) &&
              !_hasNoLoadContext(current)) {
            current = _replaceWholeClopidogrelLine(current, replacement);
            onReplacement();
          }
          return current;
        })
        .join('\n');
  }

  static String _replaceGenericDoseOnce(
    String line,
    String replacement,
    void Function() onReplacement,
  ) {
    final clop = RegExp(
      r'\bclopidogrel\b',
      caseSensitive: false,
    ).firstMatch(line);
    if (clop == null) {
      return line;
    }
    final doses = RegExp(
      r'\b(75|300|600)\s*mg\b(?:\s*(?:VO|oral))?',
      caseSensitive: false,
    ).allMatches(line).toList();
    Match? selected;
    var best = 1 << 30;
    for (final dose in doses) {
      final value = dose.group(1);
      final eligible =
          value == '300' ||
          value == '600' ||
          (value == '75' && _hasLoadingContext(line));
      if (!eligible) {
        continue;
      }
      final center = (dose.start + dose.end) ~/ 2;
      final distance = (((clop.start + clop.end) ~/ 2) - center).abs();
      if (distance < best) {
        best = distance;
        selected = dose;
      }
    }
    if (selected == null || best > 52) {
      return line;
    }
    final start = clop.start < selected.start ? clop.start : selected.start;
    final end = clop.end > selected.end ? clop.end : selected.end;
    onReplacement();
    return line.replaceRange(start, end, replacement);
  }

  static String _replaceWholeClopidogrelLine(String line, String replacement) {
    final m = RegExp(r'\bclopidogrel\b', caseSensitive: false).firstMatch(line);
    if (m == null) {
      return line;
    }
    return '${line.substring(0, m.start)}$replacement';
  }

  static String _decisionLine(String languageCode) => languageCode == 'es'
      ? 'Clopidogrel — si es el P2Y12 elegido: sin fibrinólisis, carga de 300 o 600 mg por vía oral según la estrategia; con fibrinólisis, 300 mg si edad ≤75 años y 75 mg inicial sin carga si >75 años'
      : 'Clopidogrel — se for o P2Y12 escolhido: sem fibrinólise, carga de 300 ou 600 mg por via oral conforme a estratégia; com fibrinólise, 300 mg se idade ≤75 anos e 75 mg inicial sem carga se >75 anos';

  static bool _isDecisionLine(String line) {
    final q = _fold(line);
    return q.contains('clopidogrel') &&
        q.contains('p2y12') &&
        q.contains('300') &&
        q.contains('600') &&
        q.contains('fibrinol');
  }

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

  static int _headingIndex(List<String> lines, List<String> headings) {
    for (var i = 0; i < lines.length; i++) {
      if (headings.contains(_headingFold(lines[i]))) {
        return i;
      }
    }
    return -1;
  }

  static String _headingFold(String value) {
    final folded = _fold(value);
    return folded.replaceFirst(RegExp(r'^[^a-z0-9]+'), '').trim();
  }

  static int _nextSection(List<String> lines, int start) {
    const headings = <String>{
      'conduta imediata',
      'conducta inmediata',
      'tratamento farmacologico',
      'tratamiento farmacologico',
      'tratamento',
      'tratamiento',
      'pontos chave',
      'puntos clave',
      'red flags',
      'sinais de alerta',
      'senales de alerta',
      'alerta clinico',
      'proximo',
      'proximo paso',
      'siguiente paso',
      'fechamento',
      'cierre',
    };
    for (var i = start; i < lines.length; i++) {
      if (headings.contains(_headingFold(lines[i]))) {
        return i;
      }
    }
    return lines.length;
  }

  static bool _same(List<String> a, List<String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  static String _join(List<String> lines) {
    final out = <String>[];
    for (final line in lines) {
      if (line.trim().isEmpty && (out.isEmpty || out.last.trim().isEmpty)) {
        continue;
      }
      out.add(line);
    }
    while (out.isNotEmpty && out.last.trim().isEmpty) {
      out.removeLast();
    }
    return out.join('\n');
  }

  static bool _hasNoLoadContext(String line) {
    final q = _fold(line);
    return q.contains('sem carga') || q.contains('sin carga');
  }

  static String _fold(String value) => value
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('à', 'a')
      .replaceAll('ã', 'a')
      .replaceAll('â', 'a')
      .replaceAll('é', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ô', 'o')
      .replaceAll('õ', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ç', 'c')
      .replaceAll('≤', '<=')
      .replaceAll(RegExp(r'[*_`#•\-–—:;,.()\[\]]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String _replaceLocallyCoupledDose(
    String line, {
    required String replacement,
    required Set<String> allowedDoses,
    required bool requireLoadingContext,
    required void Function() onReplacement,
  }) {
    if (requireLoadingContext && !_hasLoadingContext(line)) return line;

    var current = line;

    for (var safety = 0; safety < 6; safety++) {
      final doseMatches = RegExp(
        r'\b(75|300|600)\s*mg\b(?:\s*(?:VO|oral))?',
        caseSensitive: false,
      ).allMatches(current).toList();

      if (doseMatches.isEmpty) break;

      Match? selected;
      for (final match in doseMatches) {
        final dose = match.group(1);
        if (dose == null || !allowedDoses.contains(dose)) continue;

        final doseCenter = (match.start + match.end) ~/ 2;
        final clopidogrelDistance = _nearestTokenDistance(
          current,
          doseCenter,
          const <String>['clopidogrel'],
        );
        final competitorDistance = _nearestTokenDistance(
          current,
          doseCenter,
          const <String>[
            ' aas ',
            'aspirin',
            'aspirina',
            'ticagrelor',
            'prasugrel',
          ],
        );

        if (clopidogrelDistance == null) continue;

        if (clopidogrelDistance <= 44 &&
            (competitorDistance == null ||
                clopidogrelDistance < competitorDistance)) {
          selected = match;
          break;
        }
      }

      if (selected == null) break;

      final clopidogrelMatches = RegExp(
        r'\bclopidogrel\b',
        caseSensitive: false,
      ).allMatches(current).toList();

      if (clopidogrelMatches.isEmpty) break;

      Match nearestClopidogrel = clopidogrelMatches.first;
      var bestDistance = 1 << 30;
      final doseCenter = (selected.start + selected.end) ~/ 2;

      for (final match in clopidogrelMatches) {
        final center = (match.start + match.end) ~/ 2;
        final distance = (center - doseCenter).abs();
        if (distance < bestDistance) {
          bestDistance = distance;
          nearestClopidogrel = match;
        }
      }

      final start = nearestClopidogrel.start < selected.start
          ? nearestClopidogrel.start
          : selected.start;
      final end = nearestClopidogrel.end > selected.end
          ? nearestClopidogrel.end
          : selected.end;

      final segment = current.substring(start, end);
      if (!segment.toLowerCase().contains('clopidogrel')) break;

      current = current.replaceRange(start, end, replacement);
      onReplacement();
    }

    return current;
  }

  static int? _nearestTokenDistance(
    String line,
    int position,
    List<String> tokens,
  ) {
    final lower = ' ${line.toLowerCase()} ';
    int? best;

    for (final token in tokens) {
      var start = 0;
      while (true) {
        final index = lower.indexOf(token.toLowerCase(), start);
        if (index < 0) break;

        final center = index + token.length ~/ 2;
        final distance = (center - (position + 1)).abs();

        if (best == null || distance < best) best = distance;
        start = index + 1;
      }
    }

    return best;
  }

  static bool _hasLoadingContext(String line) {
    final q = line.toLowerCase();
    return q.contains('carga') ||
        q.contains('loading') ||
        q.contains('inicial') ||
        q.contains('initial') ||
        q.contains('sem carga') ||
        q.contains('sin carga') ||
        q.contains('fibrinol');
  }
}
