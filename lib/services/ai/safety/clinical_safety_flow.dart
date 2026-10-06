import 'clinical_sections.dart';
import 'clinical_dose_scope.dart';
import '../../ai_pipeline/ai_request_contract.dart';
import 'clinical_request_safety.dart';
import '../../well_formed_utf16.dart';
import 'ai_stream_trace.dart';

/// Productive boundary used by AppProvider for previews and final presentation.
/// It contains no provider implementation and cannot change patient facts.
class ClinicalSafetyFlow {
  const ClinicalSafetyFlow(this.context, {this.onStudyRemoval});
  final void Function(String reason, String fragment)? onStudyRemoval;
  final ClinicalRequestContext context;

  ClinicalSafetyResult terminal(String text,
          {AiRequestMode? mode,
          Iterable<String> structuredClaims = const []}) =>
      ClinicalSafetyPass.evaluate(
          context: context,
          output: text,
          outputMode: mode ?? context.mode,
          structuredClaims: structuredClaims);

  /// Preview only complete fragments after mode-specific safety checks.
  /// Patient-specific operational requests remain buffered for verification.
  String? preview(String accumulated) {
    if (context.mode == AiRequestMode.plantao) {
      if (context.isOperationalRequest || !context.mayGenerate ||
          context.ownsRequest?.call() == false) {
        return null;
      }
      // A completed sentence is sufficient; a double newline is not required.
      // Never expose a trailing, unfinished instruction or dose.
      final boundaries = RegExp(r'[.!?](?=\s|$)|\n').allMatches(accumulated);
      if (boundaries.isEmpty) return null;
      final safe = present(accumulated.substring(0, boundaries.last.end));
      return safe == context.safeMessage || safe.trim().isEmpty ? null : safe;
    }
    if (context.mode != AiRequestMode.estudo ||
        context.isOperationalRequest ||
        !context.mayGenerate) {
      return null;
    }
    final boundary = accumulated.lastIndexOf('\n\n');
    if (boundary < 0) return null;
    final text = accumulated.substring(0, boundary).trimRight();
    if (text.isEmpty || !RegExp(r'[.!?]$').hasMatch(text) ||
        context.ownsRequest?.call() == false) return null;
    final safe = _studyPresentation(text, preview: true);
    return safe.isEmpty ? null : safe;
  }

  String present(String text, {AiRequestMode? mode}) {
    AiStreamTrace.content('PRE_SAFETY', text);
    final result = ClinicalSections.withoutEmptyHeadings(_present(text, mode: mode));
    AiStreamTrace.stage('SAFETY_BOUNDARY', text, result);
    AiStreamTrace.content('POST_SAFETY', result);
    AiStreamTrace.mark('SAFETY_TEMPLATE_SELECTED', result == context.safeMessage ? 1 : 0);
    return result;
  }

  String _present(String text, {AiRequestMode? mode}) {
    if (context.mode == AiRequestMode.estudo) {
      return _studyPresentation(text, mode: mode);
    }
    if (context.mode == AiRequestMode.plantao) {
      text = ClinicalDoseScope.labelReferenceSections(text, context.language);
    }
    if (terminal(text, mode: mode).allowed) {
      AiStreamTrace.mark('SAFETY_BRANCH_TERMINAL_ALLOWED', 1);
      AiStreamTrace.mark('SAFETY_REMOVED_FRAGMENT_COUNT', 0);
      return context.mode == AiRequestMode.plantao ? qualityLint(text) : text;
    }
    // Presentation-only degradation for explanatory Plantão turns. The
    // validator and prescription authorization stay unchanged.
    if (context.mode != AiRequestMode.plantao ||
        (mode != null && mode != context.mode) ||
        !context.mayGenerate ||
        context.ownsRequest?.call() == false) {
      return context.safeMessage;
    }

    var diagnosticRemoved = 0;
    void removal(ClinicalSafetyResult result, String fragment) {
      AiStreamTrace.mark('SAFETY_REMOVED_CHARS', fragment.length);
      AiStreamTrace.markers('SAFETY_REMOVED', fragment);
      for (final key in ClinicalFacts.fromUserText(fragment).values.keys) {
        AiStreamTrace.mark('SAFETY_REMOVED_FACT_${key.toUpperCase()}',1);
      }
      AiStreamTrace.mark('SAFETY_REMOVED_CONDITIONAL', RegExp(r'\b(?:si|se|cuando|quando|en caso|em caso)\b|[<>≤≥]',caseSensitive:false).hasMatch(fragment)?1:0);
      AiStreamTrace.mark('SAFETY_REMOVED_PATIENT_SPECIFIC', ClinicalDoseScope.patientSpecificFragment(fragment) ? 1 : 0);
      for (final marker in <String,String>{
        'ROUTE': r'oral|intraven|intramus|subcut|\b(?:IV|VO|IM|SC)\b',
        'FREQUENCY': r'cada|veces|vezes|horas|daily',
        'THRESHOLD': r'[<>≤≥]|mmol|mEq|mmHg|SpO2|saturaci|saturaç',
        'PERCENT': r'%',
        'UNITS': r'\b(?:U|IU|unidades)\b',
        'DIAGNOSTIC': r'ECG|electro|eletro|diagn[oó]st|examen|exame',
        'CALCULATION': r'calculad|individualiz|\s=\s',
      }.entries) {
        AiStreamTrace.mark('SAFETY_REMOVED_HAS_${marker.key}', RegExp(marker.value, caseSensitive:false).hasMatch(fragment)?1:0);
      }
      diagnosticRemoved++;
      for (final entry in result.gates.entries) {
        if (entry.value == SafetyVerdict.failClosed) {
          AiStreamTrace.mark('SAFETY_REASON_${entry.key.name.toUpperCase()}', 1);
        }
      }
    }
    final kept = <String>[];
    var prescriptionSection = false;
    // Markdown lists and sections frequently use a single newline. Keeping
    // them as one fragment lets a single unsupported instruction erase the
    // preceding explanation. Each complete line retains its own validation;
    // prescription section state still spans subsequent lines.
    for (final paragraph in text.split('\n')) {
      if (paragraph.trim().isEmpty) { kept.add(''); continue; }
      final heading = paragraph.replaceAll(RegExp(r'[*#_]'), '').trim().toLowerCase();
      if (RegExp(r'^(prescri[çc][aã]o|prescripci[oó]n|posologia|doses|dosis)\s*:?$').hasMatch(heading)) {
        diagnosticRemoved++;
        AiStreamTrace.mark('SAFETY_REASON_PRESCRIPTION_HEADING', 1);
        prescriptionSection = true;
        continue;
      }
      if (paragraph.trimLeft().startsWith('#')) prescriptionSection = false;
      if (_isStandardReferenceDose(paragraph, mode: mode)) {
        kept.add(paragraph);
        continue;
      }
      if (prescriptionSection) {
        final diagnosticVerdict = terminal('## Prescrição\n$paragraph', mode: mode);
        if (diagnosticVerdict.allowed) { kept.add(paragraph); }
        else { removal(diagnosticVerdict, paragraph); }
        continue;
      }
      // Specialized operational validation retains authority over each complete
      // sentence. General educational prose is not rejected by a global verdict.
      final fragments = paragraph.split(RegExp(r'(?<=[.!?;])\s+(?=[A-ZÁÉÍÓÚÀÂÊÔÇÑ¿])'));
      final retained = <String>[];
      for (final fragment in fragments) {
        if (fragment.trim().isEmpty) continue;
        if (ClinicalSafetyPass.operational(fragment, laboratoryMeasurements: true) &&
            !terminal(fragment, mode: mode).allowed &&
            !_isGeneralEducationalFragment(fragment, mode: mode) &&
            !_isStandardReferenceDose(fragment, mode: mode)) {
          removal(terminal(fragment, mode: mode), fragment);
          continue;
        }
        retained.add(fragment);
      }
      if (retained.isNotEmpty) kept.add(retained.join(' '));
    }
    AiStreamTrace.mark('SAFETY_REMOVED_FRAGMENT_COUNT', diagnosticRemoved);
    final safe = qualityLint(kept.join('\n'));
    if (safe.isEmpty) return context.safeMessage;
    if (context.unknownCriticalFacts.isNotEmpty && !safe.contains(context.safeMessage)) {
      return '$safe\n\n${context.safeMessage}';
    }
    return safe;
  }

  /// Study has no whole-answer evidence/catalog requirement. Strict terminal
  /// prescription authority remains available separately; educational fragments
  /// are evaluated independently, without Plantão compression or added labels.
  String _studyPresentation(String text, {AiRequestMode? mode, bool preview = false}) {
    if ((mode != null && mode != context.mode) ||
        !context.mayGenerate || context.ownsRequest?.call() == false) {
      return preview ? '' : context.safeMessage;
    }
    if (context.verifiesStudyReferences) text = context.studyReferences.present(text);
    var removed = 0;
    var prescriptionSection = false;
    var retainedBody = false;
    final kept = <String>[];
    for (final line in text.split('\n')) {
      if (line.trim().isEmpty) { kept.add(line); continue; }
      // This exact app-owned notice is already the result of limiting a mixed
      // request. Do not split and reclassify its explanation as a prescription.
      if (context.isStudyMixedRequest &&
          context.unknownCriticalFacts.isNotEmpty &&
          line.trim() == context.safeMessage) {
        if (!kept.contains(context.safeMessage)) kept.add(context.safeMessage);
        continue;
      }
      final heading = RegExp(r'^\s*#{1,6}\s').hasMatch(line);
      if (heading && !ClinicalSafetyPass.operational(line) &&
          ClinicalFacts.fromUserText(line).values.isEmpty) {
        prescriptionSection = RegExp(
            r'prescri[çc][aã]o|prescripci[oó]n|posologia|doses|dosis|tratamento farmacol[oó]gico|tratamiento farmacol[oó]gico',
            caseSensitive: false).hasMatch(line);
        kept.add(line);
        continue;
      }
      final fragments = line.split(RegExp(r'(?<=[.!?;])\s+(?=[A-ZÁÉÍÓÚÀÂÊÔÇÑ¿])'));
      final retained = <String>[];
      for (final fragment in fragments) {
        final clinicalFragment = fragment.replaceFirst(RegExp(r'^\s*#{1,6}\s+'), '');
        final scoped = prescriptionSection ? '## Prescrição\n$clinicalFragment' : clinicalFragment;
        final verdict = terminal(scoped, mode: mode);
        final reasons = <String>[];
        if (ClinicalArithmetic.validateClinicalEquations(fragment, context.knownFacts) == false) {
          reasons.add('INVALID_ARITHMETIC');
        }
        final unresolved = RegExp(
            r'\b(?:medicamento|f[aá]rmaco|subst[aâ]ncia|sustancia|drug)\s+(?:desconhecid\w*|desconocid\w*|unknown|inventad\w*|fict[ií]ci\w*)\b',
            caseSensitive: false).hasMatch(fragment);
        if (unresolved) reasons.add('UNRESOLVED_MEDICATION');
        if (reasons.isEmpty && (verdict.allowed ||
            _isStandardReferenceDose(clinicalFragment, mode: mode) ||
            _isGeneralEducationalFragment(clinicalFragment, mode: mode) ||
            _isStudyEducationalExplanation(clinicalFragment))) {
          retained.add(fragment);
          retainedBody = true;
          continue;
        }
        removed++;
        final exclusion = _studyEducationalExclusion(clinicalFragment);
        final specificReasons = {...reasons, if (exclusion != null) exclusion};
        for (final reason in specificReasons) {
          onStudyRemoval?.call(reason, fragment);
          AiStreamTrace.mark('STUDY_FRAGMENT_REASON_$reason', 1);
        }
        AiStreamTrace.mark('STUDY_SAFETY_REMOVED_CHARS', fragment.length);
        AiStreamTrace.markers('STUDY_SAFETY_REMOVED', fragment);
        for (final gate in verdict.gates.entries) {
          if (gate.value == SafetyVerdict.failClosed) reasons.add(gate.key.name.toUpperCase());
        }
        for (final reason in reasons.toSet()) {
          AiStreamTrace.mark('STUDY_SAFETY_REASON_$reason', 1);
        }
      }
      if (retained.isNotEmpty) kept.add(retained.join(' '));
    }
    AiStreamTrace.mark('STUDY_SAFETY_REMOVED_FRAGMENT_COUNT', removed);
    // Headings alone are not safe educational content. Do not fabricate the
    // missing provider answer or call it a successful clinical explanation.
    if (!retainedBody) {
      AiStreamTrace.mark('STUDY_SAFE_CONTENT_EMPTY', 1);
      return preview ? '' : studyNoSafeContentMessage;
    }
    AiStreamTrace.mark(removed == 0 ? 'STUDY_SAFETY_PASS' : 'STUDY_SAFETY_PASS_WITH_FRAGMENT_REMOVAL', 1);
    var answer = qualityLint(kept.join('\n'));
    if (!preview && context.isStudyMixedRequest && context.unknownCriticalFacts.isNotEmpty &&
        !answer.contains(context.safeMessage)) {
      answer = '$answer\n\n${context.safeMessage}';
    }
    return preview || !context.verifiesStudyReferences
        ? answer : context.studyReferences.appendTo(answer, context.language);
  }

  String get studyNoSafeContentMessage => context.language.startsWith('es')
      ? 'No se pudo completar la explicación. Puedes pedir los conceptos, mecanismos, diagnóstico o tratamiento general del tema. Para calcular una dosis individual hacen falta los datos pertinentes del paciente y del medicamento.'
      : 'Não foi possível concluir a explicação. Você pode pedir os conceitos, mecanismos, diagnóstico ou tratamento geral do tema. Para calcular uma dose individual são necessários os dados pertinentes do paciente e do medicamento.';

  /// Persistence may accept an educational answer without granting exact
  /// prescription authority. Reapplying the fragment boundary must be stable.
  bool acceptsStudyPresentation(String text) =>
      context.mode == AiRequestMode.estudo && context.mayGenerate &&
      context.ownsRequest?.call() != false &&
      _studyPresentation(text) == qualityLint(text);

  bool _isStudyEducationalExplanation(String fragment) =>
      _studyEducationalExclusion(fragment) == null;

  String? _studyEducationalExclusion(String fragment) {
    if (!context.isGeneralEducationalQuery && !context.isStudyMixedRequest) return 'INDIVIDUAL_REQUEST';
    if (ClinicalArithmetic.validateClinicalEquations(fragment, context.knownFacts) == false) return 'INVALID_ARITHMETIC';
    if (ClinicalDoseScope.hasInvalidReferenceValue(fragment)) return 'INVALID_REFERENCE_VALUE';
    if (context.isStudyMixedRequest && ClinicalSafetyPass.medicationOperation(fragment) &&
        !ClinicalDoseScope.referenceLabel(fragment)) return 'MIXED_REQUEST_INDIVIDUAL_OPERATION';
    if (RegExp(r'\b(?:dose|dosis|pauta|regime)\s+(?:calculad[ao]|individualizad[ao])\b',
        caseSensitive: false).hasMatch(fragment)) return 'INDIVIDUAL_CALCULATION';
    if (RegExp(r'\b(?:este|esse|meu|mi|seu|tu)\s+paciente\b',
        caseSensitive: false).hasMatch(fragment)) return 'INDIVIDUAL_PATIENT';
    if (RegExp(r'^\s*[-*]?\s*(?:peso|pesa|idade|edad|egfr|clcr|tfg)\s*[:=]?\s*\d',
        caseSensitive: false).hasMatch(fragment)) return 'ASSERTED_PATIENT_FACT';
    if (RegExp(r'^\s*[-*]?\s*(?:administrar|administre|tomar|tome|usar|use)\s+\d',
        caseSensitive: false).hasMatch(fragment)) return 'UNNAMED_ADMINISTRATION';
    return null;
  }

  bool _isStandardReferenceDose(String fragment, {AiRequestMode? mode}) {
    // General reference scope comes from the request, not a mandatory label
    // in each provider line. Existing fragment and arithmetic guards remain.
    final unresolvedMedication = RegExp(
        r'\b(?:medicamento|f[aá]rmaco|drug)\s+(?:desconhecid\w*|desconocid\w*|unknown)\b|'
        r'^\s*[-*]?\s*(?:administrar|administre|tomar|tome|usar|use)\s+\d',
        caseSensitive: false).hasMatch(fragment);
    final generalReference = context.isGeneralEducationalQuery &&
        !unresolvedMedication;
    final scopedFragment = generalReference
        ? 'Dose padrão de referência: $fragment' : fragment;
    if ((context.isOperationalRequest && !ClinicalDoseScope.referenceLabel(context.userQuery)) ||
        !ClinicalDoseScope.referenceFragment(scopedFragment,
            generalEducational: context.isGeneralEducationalQuery)) {
      return false;
    }
    // Catalog absence cannot validate or invalidate a reference dose. Retain
    // non-catalog gates, including dimensional arithmetic and contradictions.
    if (ClinicalArithmetic.validateClinicalEquations(fragment, context.knownFacts) == false) return false;
    final result = terminal(fragment, mode: mode);
    const coverageGates = {SafetyGate.medicationEvidence,
      SafetyGate.evidenceBinding, SafetyGate.unsupportedCriticalClaims,
      SafetyGate.numericValidation, SafetyGate.criticalDataComplete};
    return context.mayGenerate && result.gates.entries.every((e) =>
      e.value != SafetyVerdict.failClosed || coverageGates.contains(e.key));
  }

  // Only an impersonal educational recommendation may lack a catalog binding.
  // Numeric regimens, prescription imperatives and patient-specific requests
  // still require the existing specialized validation.
  bool _isGeneralEducationalFragment(String fragment, {AiRequestMode? mode}) {
    final generalThreshold = context.isGeneralEducationalQuery &&
        !ClinicalDoseScope.patientSpecificFragment(fragment) &&
        RegExp(r'[<>≤≥]|mmol|mEq|mmHg|SpO2|saturaci|saturaç',caseSensitive:false).hasMatch(fragment) &&
        !RegExp(r'\d+(?:[.,]\d+)?\s*(?:mg|mcg|µg|g|ml|ui|iu|u|unidades)\b',caseSensitive:false).hasMatch(fragment) &&
        ClinicalArithmetic.validateClinicalEquations(fragment, context.knownFacts) != false;
    if (context.isOperationalRequest ||
        (!generalThreshold && RegExp(r'\d|\b(?:dose|dosis|posologia|posología|prescri\w*|administr\w*|tomar|tome|injete|injetar|diluir|dilua|infundir|receber|receba|usar|use|utilize|titular|iv|im|sc|vo)\b',
            caseSensitive: false).hasMatch(fragment))) { return false; }
    final result = terminal(fragment, mode: mode);
    const coverageOnly = {
      SafetyGate.medicationEvidence,
      SafetyGate.unsupportedCriticalClaims,
      SafetyGate.evidenceBinding,
    };
    return result.gates.entries.every((entry) =>
        entry.value != SafetyVerdict.failClosed || coverageOnly.contains(entry.key) ||
        (generalThreshold && entry.key == SafetyGate.numericValidation));
  }

  /// Text-only final boundary: no disease, treatment, evidence or dose policy.
  static String qualityLint(String text) => WellFormedUtf16.normalize(text)
      .replaceAll('\r\n', '\n')
      .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}
