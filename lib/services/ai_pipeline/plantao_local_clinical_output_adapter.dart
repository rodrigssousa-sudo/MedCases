import '../../models/clinical_structured_output.dart';
import '../plantao_pipeline.dart';
import 'clinical_treatment_presentation_adapter.dart';

enum _GuardiaSection {
  none,
  immediate,
  firstLine,
  secondLine,
  keyPoints,
  hardStop,
  other,
}

/// Converte somente conteúdo literal de um texto Guardia já validado.
///
/// Não calcula dose, não escolhe tratamento e não infere prioridade pela ordem.
/// Primeira e segunda linha só são preenchidas com rótulos explícitos.
abstract final class PlantaoLocalClinicalOutputAdapter {
  static final RegExp _dosePattern = RegExp(
    r'\b\d+(?:[.,]\d+)?'
    r'(?:\s*(?:-|–|a|até|hasta)\s*\d+(?:[.,]\d+)?)?'
    r'\s*(?:mcg|µg|ug|mg|g|mL|ml|L|l|U|u|UI|ui|'
    r'unidades?|units?|ampollas?|ampolas?|comprimidos?|tabletas?|gotas?)'
    r'(?:\s*/\s*(?:kg|h|min|dia|d|mL|ml|L|l))*'
    r'(?:\s+(?:IV|EV|VO|SC|IM|SL|IN|IO))?'
    r'(?:\s+(?:bolo|bolus))?',
    caseSensitive: false,
  );

  static final RegExp _routePattern = RegExp(
    r'(^|\s)(?:IV|EV|VO|SC|IM|SL|IN|IO)(?=\s|[.,;:]|$)',
    caseSensitive: false,
  );

  // Match complete emoji tokens. A UTF-16 character class can consume only
  // one surrogate from a supplementary-plane emoji (for example 🚩), leaving
  // malformed text in the structured DTO.
  static final RegExp _leadingVisualPrefixPattern = RegExp(
    r'^(?:(?:📖|🔑|📌|⚠️|⚠|🟥|🔴|💊|🔄|⛔|🚨|🚩)|[-*•\s])+',
    unicode: true,
  );

  static final RegExp _leadingActionPattern = RegExp(
    r'^(?:administrar|administre|iniciar|inicie|usar|use|aplicar|'
    r'aplique|prescribir|prescreva|dar|ofrecer|oferecer|considerar|'
    r'considere|titular|ajustar|mantener|manter|'
    r'infusi[oó]n|infus[aã]o|bolo|bolus|carga)'
    r'(?:\s+de)?\s+',
    caseSensitive: false,
  );

  static ClinicalStructuredOutput? fromValidatedText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    final parsed = PlantaoParser.parse(trimmed);
    if (parsed == null) return null;

    final prescriptions = <ClinicalPrescriptionItem>[];
    final firstLine = <ClinicalPrescriptionItem>[];
    final secondLine = <ClinicalPrescriptionItem>[];
    final immediateItems = <String>[];
    final keyPoints = <String>[];
    final hardStops = <String>[];
    final seen = <String>{};
    var section = _GuardiaSection.none;

    for (final rawLine in _lines(trimmed)) {
      final inline = _inlineSectionFor(rawLine);

      if (inline != null) {
        section = inline.section;

        if (inline.section == _GuardiaSection.hardStop &&
            inline.content.isNotEmpty) {
          _addUnique(hardStops, inline.content);
        }

        continue;
      }

      final headingSection = _sectionFor(rawLine);

      if (headingSection != null) {
        section = headingSection;
        continue;
      }

      final cleaned = _cleanLine(rawLine);
      if (cleaned.isEmpty) continue;

      final prescription = _prescriptionFrom(
        rawLine: rawLine,
        cleaned: cleaned,
      );

      if (prescription != null) {
        final identity = '${_normalize(prescription.farmaco)}|'
            '${_normalize(prescription.posologia)}';

        if (seen.add(identity)) {
          prescriptions.add(prescription);

          if (section == _GuardiaSection.firstLine) {
            firstLine.add(prescription);
          } else if (section == _GuardiaSection.secondLine) {
            secondLine.add(prescription);
          }
        }
        continue;
      }

      final normalized = _normalize(cleaned);

      if (_isHeading(normalized) ||
          (section != _GuardiaSection.immediate &&
              _isExcludedClinicalLine(normalized))) {
        continue;
      }

      switch (section) {
        case _GuardiaSection.immediate:
          _addUnique(immediateItems, cleaned);
          break;
        case _GuardiaSection.keyPoints:
          _addUnique(keyPoints, cleaned);
          break;
        case _GuardiaSection.hardStop:
          _addUnique(hardStops, cleaned);
          break;
        case _GuardiaSection.none:
        case _GuardiaSection.firstLine:
        case _GuardiaSection.secondLine:
        case _GuardiaSection.other:
          break;
      }
    }

    if (prescriptions.isEmpty) return null;

    final markedDiagnosis = _markedDiagnosis(trimmed);

    if (_isDifferentialPresentation(markedDiagnosis)) {
      return null;
    }

    if (_isActionLikeDiagnosis(markedDiagnosis)) {
      _addUnique(immediateItems, markedDiagnosis);
    }

    final diagnosis = _resolveDiagnosis(
      text: trimmed,
      parserDiagnosis: parsed.conduta,
    );
    if (diagnosis.isEmpty) return null;

    final firstPrescription = prescriptions.first;
    final immediateConduct =
        '${firstPrescription.farmaco} ${firstPrescription.posologia}'.trim();

    /// PHASE3I-J2F4: conservative productive local adapter binding.
    /// Only explicit PT/ES relation headings are transported.
    final treatmentPresentation =
        ClinicalTreatmentPresentationAdapter.fromExplicitText(trimmed);

    return ClinicalStructuredOutput(
      diagnosticoHeuristico: diagnosis,
      condutaImediata: immediateConduct,
      prescricao: prescriptions,
      condutaImediataItens: immediateItems,
      primeiraLinha: firstLine,
      segundaLinha: secondLine,
      pontosChave: keyPoints,
      hardStops: hardStops,
      treatmentPresentation: treatmentPresentation,
    );
  }

  static ClinicalPrescriptionItem? _prescriptionFrom({
    required String rawLine,
    required String cleaned,
  }) {
    if (!_hasMedicationContext(rawLine, cleaned)) return null;

    final doseMatch = _dosePattern.firstMatch(cleaned);
    if (doseMatch == null) return null;

    var drug = cleaned.substring(0, doseMatch.start).trim();
    var dose = cleaned.substring(doseMatch.start).trim();

    drug = drug
        .replaceFirst(_leadingActionPattern, '')
        .replaceFirst(
          RegExp(
            r'^(?:de|del|da|do)\s+',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'[:\-–]\s*$'), '')
        .trim();

    dose = dose
        .replaceAll(RegExp(r'^[\s:;\-–]+'), '')
        .replaceAll(RegExp(r'[\s.;,]+$'), '')
        .trim();

    if (drug.isEmpty || dose.isEmpty) return null;

    return ClinicalPrescriptionItem(
      farmaco: _capitalize(drug),
      posologia: dose,
    );
  }

  static ({_GuardiaSection section, String content})? _inlineSectionFor(
    String rawLine,
  ) {
    if (rawLine.trimLeft().startsWith('📌')) {
      return (
        section: _GuardiaSection.other,
        content: '',
      );
    }

    final prepared = rawLine
        .trim()
        .replaceAll(RegExp(r'[*_`#]+'), '')
        .replaceFirst(
          _leadingVisualPrefixPattern,
          '',
        )
        .trim();

    final match = RegExp(
      r'^(alerta(?:\s+cl[ií]nico)?|hard\s+stop|red\s+flags?|'
      r'pr[oó]ximo(?:\s+(?:paso|passo))?|siguiente\s+paso)'
      r'\s*:\s*(.*)$',
      caseSensitive: false,
    ).firstMatch(prepared);

    if (match == null) return null;

    final heading = _normalize(
      match.group(1) ?? '',
    );
    final content = _cleanLine(
      match.group(2) ?? '',
    );

    if (heading == 'hard stop' ||
        heading == 'red flag' ||
        heading == 'red flags') {
      return (
        section: _GuardiaSection.hardStop,
        content: content,
      );
    }

    return (
      section: _GuardiaSection.other,
      content: '',
    );
  }

  static _GuardiaSection? _sectionFor(String rawLine) {
    final value = _normalize(_cleanHeading(rawLine));

    if (value.isEmpty) return null;

    if (value == 'conduta' ||
        value == 'conducta' ||
        value == 'conduta imediata' ||
        value == 'conducta inmediata' ||
        value == 'conduta clinica imediata' ||
        value == 'conducta clinica inmediata' ||
        value == 'avaliacao inicial' ||
        value == 'evaluacion inicial') {
      return _GuardiaSection.immediate;
    }

    if (value == '1 linea' ||
        value == '1a linea' ||
        value == '1er linea' ||
        value == 'primera linea' ||
        value == '1 linha' ||
        value == '1a linha' ||
        value == 'primeira linha') {
      return _GuardiaSection.firstLine;
    }

    if (value == '2 linea' ||
        value == '2a linea' ||
        value == 'segunda linea' ||
        value == '2 linha' ||
        value == '2a linha' ||
        value == 'segunda linha') {
      return _GuardiaSection.secondLine;
    }

    if (value == 'puntos clave' ||
        value == 'pontos chave' ||
        value == 'pontos chaves' ||
        value == 'meta' ||
        value == 'metas' ||
        value == 'objetivo' ||
        value == 'objetivos') {
      return _GuardiaSection.keyPoints;
    }

    if (value == 'hard stop' ||
        value == 'hard stops' ||
        value == 'red flag' ||
        value == 'red flags') {
      return _GuardiaSection.hardStop;
    }

    if (value.startsWith('resumo') ||
        value.startsWith('resumen') ||
        value == 'tratamiento' ||
        value == 'tratamento' ||
        value == 'tratamiento farmacologico' ||
        value == 'tratamento farmacologico' ||
        value == 'droga de eleccion' ||
        value == 'droga de escolha' ||
        value == 'alerta clinico' ||
        value == 'proximo' ||
        value == 'proximo paso' ||
        value == 'proximo passo' ||
        value == 'siguiente paso') {
      return _GuardiaSection.other;
    }

    return null;
  }

  static Iterable<String> _lines(String text) sync* {
    for (final rawLine
        in text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n')) {
      yield rawLine;
    }
  }

  static String _cleanHeading(String rawLine) {
    return rawLine
        .trim()
        .replaceAll(RegExp(r'[*_`]+'), '')
        .replaceFirst(
          _leadingVisualPrefixPattern,
          '',
        )
        .replaceAll(RegExp(r'[:\s]+$'), '')
        .trim();
  }

  static String _cleanLine(String rawLine) {
    var line = rawLine.trim();

    line = line
        .replaceAll(RegExp(r'[*_`]+'), '')
        .replaceFirst(
          _leadingVisualPrefixPattern,
          '',
        )
        .trim();

    line = line.replaceFirst(
      RegExp(
        r'^(?:resumo|resumen|pontos-chave|pontos chave|'
        r'puntos clave|alerta cl[ií]nico|pr[oó]ximo|'
        r'siguiente paso)\s*:\s*',
        caseSensitive: false,
      ),
      '',
    );

    return line.replaceFirst(RegExp(r'^[\-\*•\s]+'), '').trim();
  }

  static bool _hasMedicationContext(
    String rawLine,
    String cleaned,
  ) {
    final normalized = _normalize(cleaned);

    if (rawLine.contains('**')) return true;
    if (_routePattern.hasMatch(cleaned)) return true;
    if (normalized.contains('/kg') ||
        normalized.contains('/h') ||
        normalized.contains('/min')) {
      return true;
    }

    return _leadingActionPattern.hasMatch(cleaned);
  }

  static bool _isHeading(String value) {
    return value == 'consulta clinica' ||
        value == 'conduta clinica' ||
        value == 'resumo' ||
        value == 'resumen' ||
        value == 'pontos chave' ||
        value == 'puntos clave';
  }

  static bool _isExcludedClinicalLine(String value) {
    return value.startsWith('alerta clinico') ||
        value.startsWith('proximo') ||
        value.startsWith('siguiente paso') ||
        value.startsWith('monitorar') ||
        value.startsWith('monitorizar') ||
        value.startsWith('monitorear') ||
        value.startsWith('avaliar') ||
        value.startsWith('evaluar') ||
        value.startsWith('controlar') ||
        value.startsWith('glucosa capilar') ||
        value.startsWith('glicemia capilar') ||
        value.startsWith('electrolitos') ||
        value.startsWith('eletrolitos');
  }

  static bool _isDifferentialPresentation(String markedDiagnosis) {
    final normalized = _normalize(markedDiagnosis);
    if (normalized.isEmpty) return false;

    return normalized.contains('diferenciais prioritarios') ||
        normalized.contains('diferenciales prioritarios') ||
        normalized.contains('orientacao clinica') ||
        normalized.contains('orientacion clinica');
  }

  static String _resolveDiagnosis({
    required String text,
    required String parserDiagnosis,
  }) {
    final markedCandidate = _validatedDiagnosisCandidate(
      _markedDiagnosis(text),
    );

    if (markedCandidate.isNotEmpty) {
      return markedCandidate;
    }

    final parserCandidate = _validatedDiagnosisCandidate(
      parserDiagnosis,
    );

    if (parserCandidate.isNotEmpty) {
      return parserCandidate;
    }

    for (final rawLine in _lines(text)) {
      final cleaned = _cleanLine(rawLine);

      final managementMatch = RegExp(
        r'^(?:manejo|tratamiento|tratamento)\s+'
        r'(?:de|del|da|do)\s+(.+)$',
        caseSensitive: false,
      ).firstMatch(cleaned);

      if (managementMatch == null) continue;

      final candidate = _validatedDiagnosisCandidate(
        managementMatch.group(1) ?? '',
      );

      if (candidate.isNotEmpty) {
        return candidate;
      }
    }

    for (final rawLine in _lines(text)) {
      if (_sectionFor(rawLine) != null) {
        break;
      }

      final trimmed = rawLine.trim();

      if (trimmed.startsWith('🟥') || trimmed.startsWith('🔴')) {
        continue;
      }

      final candidate = _validatedDiagnosisCandidate(
        _cleanLine(rawLine),
      );

      if (candidate.isNotEmpty) {
        return candidate;
      }
    }

    return '';
  }

  static String _validatedDiagnosisCandidate(
    String value,
  ) {
    final candidate = _trimTerminalPunctuation(
      value.trim(),
    );
    final normalized = _normalize(candidate);

    if (candidate.isEmpty ||
        _isGenericDiagnosis(normalized) ||
        _isExcludedClinicalLine(normalized) ||
        _dosePattern.hasMatch(candidate) ||
        _isActionLikeDiagnosis(candidate)) {
      return '';
    }

    return _capitalize(candidate);
  }

  static String _markedDiagnosis(String text) {
    for (final rawLine in _lines(text)) {
      final trimmed = rawLine.trim();

      if (trimmed.startsWith('🟥') || trimmed.startsWith('🔴')) {
        return _cleanLine(trimmed);
      }
    }

    return '';
  }

  static bool _isActionLikeDiagnosis(String value) {
    final normalized = _normalize(value);

    if (normalized.isEmpty) return false;

    if (RegExp(r'^(?:si|se)\b').hasMatch(normalized)) {
      return true;
    }

    if (RegExp(
      r'^(?:(?:no|nao)\s+)?'
      r'(?:administrar|avaliar|evaluar|monitorar|monitorizar|'
      r'confirmar|investigar|iniciar|realizar|solicitar|'
      r'descartar|buscar|tratar|reduzir|reducir|controlar|'
      r'hidratar|suspender|usar|evitar|repetir|ajustar|'
      r'considerar)\b',
    ).hasMatch(normalized)) {
      return true;
    }

    final hasRoute = RegExp(
      r'\b(?:iv|ev|vo|sl|sc|im|io)\b',
    ).hasMatch(normalized);

    return hasRoute && _dosePattern.hasMatch(value);
  }

  static bool _isGenericDiagnosis(String value) {
    return value == 'consulta clinica' ||
        value == 'conduta clinica' ||
        value == 'manejo clinico' ||
        value == 'orientacao clinica';
  }

  static void _addUnique(List<String> target, String value) {
    final normalized = _normalize(value);
    if (normalized.isEmpty) return;

    final alreadyExists = target.any(
      (item) => _normalize(item) == normalized,
    );

    if (!alreadyExists) {
      target.add(_trimTerminalPunctuation(value));
    }
  }

  static String _trimTerminalPunctuation(String value) {
    return value.trim().replaceAll(RegExp(r'[\s.:;,]+$'), '').trim();
  }

  static String _capitalize(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;

    return '${trimmed.substring(0, 1).toUpperCase()}'
        '${trimmed.substring(1)}';
  }

  static String _normalize(String value) {
    return value
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
        .replaceAll('ª', '')
        .replaceAll('º', '')
        .replaceAll(RegExp(r'[*_`]+'), '')
        .replaceAll(RegExp(r'[^a-z0-9/]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
