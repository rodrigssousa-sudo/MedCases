// lib/services/ai/clinical_dosage_presets.dart
// MICRO-BUILD 462E-A.5.3.7.3.2.2 — PILLAR 3: Clinical Numeric Determinism Gate
//
// Institutional reference presets for high-risk continuous infusions
// (vasopressors, inotropes, sedatives). These presets are AUTHORITATIVE —
// when intent==infusion and a matching drug is detected, the LLM output is
// validated against these bounds and replaced with the institutional fallback
// if the numeric values deviate.
//
// DESIGN INVARIANTS:
//   • All presets are const-constructible and immutable.
//   • doseMin and doseMax are INCLUSIVE clinical bounds per literature.
//   • sourceId references the authoritative guideline (e.g., Surviving Sepsis).
//   • ClinicalNumericValidator performs regex-based extraction + bound checking.
//   • On bound violation: output is intercepted and replaced with
//     institutionalFallback (never left for the LLM to self-correct).
//   • Locale is NOT a validator concern — locale lock is handled by the prompt.
//
// Supported drugs (initial registry):
//   norepinephrine_iv — Norepinefrina/Noradrenalina IV (Surviving Sepsis 2021)
//   dopamine_iv       — Dopamina IV (ACC/AHA 2022 cardiogenic shock)
//   dobutamine_iv     — Dobutamina IV (ACC/AHA 2022)
//   epinephrine_iv    — Adrenalina/Epinefrina IV (AHA ACLS 2020)
//   vasopressin_iv    — Vasopressina IV (Surviving Sepsis 2021)
//   insulin_iv        — Insulina Regular IV (ADA 2024 inpatient protocol)
//   midazolam_iv      — Midazolam IV sedation (SCCM PAD-ICU guidelines)
//   propofol_iv       — Propofol IV sedation (SCCM PAD-ICU guidelines)
//   morphine_iv       — Morfina IV (WHO analgesic ladder, ICU adaptation)

// ── ClinicalDosagePreset ──────────────────────────────────────────────────────

/// Immutable institutional reference for a single drug+route combination.
///
/// MICRO-BUILD 462E-A.5.3.7.3.2.2 [PILLAR 3]:
///   • const-constructible for compile-time registry safety.
///   • doseMin/doseMax are INCLUSIVE clinical bounds (literature-validated).
///   • sourceId is the canonical reference (guideline year).
///   • institutionalFallback is the safe replacement text when the LLM
///     output deviates from the preset bounds.
final class ClinicalDosagePreset {
  final String drugId;
  final String route;
  final String doseUnit;
  final double doseMin;
  final double doseMax;
  final String sourceId;
  final String institutionalFallback;

  const ClinicalDosagePreset({
    required this.drugId,
    required this.route,
    required this.doseUnit,
    required this.doseMin,
    required this.doseMax,
    required this.sourceId,
    required this.institutionalFallback,
  });

  /// Returns true when [value] is within the inclusive clinical bounds.
  bool isWithinBounds(double value) => value >= doseMin && value <= doseMax;
}

// ── Preset Registry ───────────────────────────────────────────────────────────

/// Immutable, compile-time registry of authoritative clinical presets.
///
/// Lookup by [drugId]. Returns null when no preset exists (non-regulated drug).
const Map<String, ClinicalDosagePreset> kClinicalDosagePresets = {
  // ── Vasopressors ────────────────────────────────────────────────────────────
  'norepinephrine_iv': ClinicalDosagePreset(
    drugId:               'norepinephrine_iv',
    route:                'iv_continuous',
    doseUnit:             'mcg/kg/min',
    doseMin:              0.01,
    doseMax:              3.0,
    sourceId:             'Surviving_Sepsis_2021',
    institutionalFallback:
        'Noradrenalina IV: dose inicial 0,05–0,1 mcg/kg/min; titular até '
        'PAM ≥65 mmHg; dose máxima habitual 3 mcg/kg/min. '
        '(Referência: Surviving Sepsis Campaign 2021)',
  ),
  'dopamine_iv': ClinicalDosagePreset(
    drugId:               'dopamine_iv',
    route:                'iv_continuous',
    doseUnit:             'mcg/kg/min',
    doseMin:              1.0,
    doseMax:              20.0,
    sourceId:             'ACC_AHA_2022_cardiogenic_shock',
    institutionalFallback:
        'Dopamina IV: dose inotrópica 2–10 mcg/kg/min; vasopressora '
        '10–20 mcg/kg/min. Preferir noradrenalina em choque séptico. '
        '(Referência: ACC/AHA 2022)',
  ),
  'dobutamine_iv': ClinicalDosagePreset(
    drugId:               'dobutamine_iv',
    route:                'iv_continuous',
    doseUnit:             'mcg/kg/min',
    doseMin:              2.0,
    doseMax:              20.0,
    sourceId:             'ACC_AHA_2022_cardiogenic_shock',
    institutionalFallback:
        'Dobutamina IV: 2–20 mcg/kg/min; dose usual 5–10 mcg/kg/min. '
        'Indicada em choque cardiogênico com IC reduzido. '
        '(Referência: ACC/AHA 2022)',
  ),
  'epinephrine_iv': ClinicalDosagePreset(
    drugId:               'epinephrine_iv',
    route:                'iv_continuous',
    doseUnit:             'mcg/kg/min',
    doseMin:              0.01,
    doseMax:              1.0,
    sourceId:             'AHA_ACLS_2020',
    institutionalFallback:
        'Adrenalina IV (infusão): 0,01–1 mcg/kg/min; titular por resposta '
        'hemodinâmica. Em PCR: 1 mg IV a cada 3–5 min (bolus). '
        '(Referência: AHA ACLS 2020)',
  ),
  'vasopressin_iv': ClinicalDosagePreset(
    drugId:               'vasopressin_iv',
    route:                'iv_continuous',
    doseUnit:             'U/min',
    doseMin:              0.01,
    doseMax:              0.03,
    sourceId:             'Surviving_Sepsis_2021',
    institutionalFallback:
        'Vasopressina IV: 0,01–0,03 U/min (dose fixa, sem titulação). '
        'Associada à noradrenalina para poupança de catecolamina. '
        '(Referência: Surviving Sepsis Campaign 2021)',
  ),

  // ── Insulin ─────────────────────────────────────────────────────────────────
  'insulin_iv': ClinicalDosagePreset(
    drugId:               'insulin_iv',
    route:                'iv_continuous',
    doseUnit:             'U/h',
    doseMin:              0.5,
    doseMax:              10.0,
    sourceId:             'ADA_2024_inpatient',
    institutionalFallback:
        'Insulina Regular IV: protocolo variável 0,5–10 U/h; meta glicêmica '
        '140–180 mg/dL em UTI. Monitorar glicemia 1–2h. '
        '(Referência: ADA Standards of Care 2024)',
  ),

  // ── Sedation / Analgesia ────────────────────────────────────────────────────
  'midazolam_iv': ClinicalDosagePreset(
    drugId:               'midazolam_iv',
    route:                'iv_continuous',
    doseUnit:             'mcg/kg/min',
    doseMin:              0.02,
    doseMax:              0.1,
    sourceId:             'SCCM_PAD_ICU_2018',
    institutionalFallback:
        'Midazolam IV sedação: 0,02–0,10 mcg/kg/min; titular para RASS –2 a 0. '
        'Evitar uso prolongado (>48h) — risco de acúmulo e delírio. '
        '(Referência: SCCM PAD-ICU Guidelines 2018)',
  ),
  'propofol_iv': ClinicalDosagePreset(
    drugId:               'propofol_iv',
    route:                'iv_continuous',
    doseUnit:             'mcg/kg/min',
    doseMin:              5.0,
    doseMax:              80.0,
    sourceId:             'SCCM_PAD_ICU_2018',
    institutionalFallback:
        'Propofol IV sedação: 5–80 mcg/kg/min (0,3–4,8 mg/kg/h); titular '
        'para RASS alvo. Monitorar triglicerídeos e síndrome por infusão. '
        '(Referência: SCCM PAD-ICU Guidelines 2018)',
  ),
  'morphine_iv': ClinicalDosagePreset(
    drugId:               'morphine_iv',
    route:                'iv_continuous',
    doseUnit:             'mg/h',
    doseMin:              1.0,
    doseMax:              10.0,
    sourceId:             'SCCM_PAD_ICU_2018',
    institutionalFallback:
        'Morfina IV (infusão): 1–10 mg/h; avaliar NRS/CPOT; ajustar conforme '
        'função renal (metabólito ativo acumula em IR). '
        '(Referência: SCCM PAD-ICU Guidelines 2018)',
  ),
};

// ── Drug alias map (input detection → preset key) ────────────────────────────

/// Maps user-input drug name fragments (lowercased) to canonical preset keys.
/// Used by [ClinicalNumericValidator] to identify which preset applies.
const Map<String, String> kDrugAliasToPresetKey = {
  // Norepinephrine
  'norepinefrina':      'norepinephrine_iv',
  'noradrenalin':       'norepinephrine_iv',
  'norepinephrine':     'norepinephrine_iv',
  'noradrenalina':      'norepinephrine_iv',
  'levophed':           'norepinephrine_iv',

  // Dopamine
  'dopamina':           'dopamine_iv',
  'dopamine':           'dopamine_iv',

  // Dobutamine
  'dobutamina':         'dobutamine_iv',
  'dobutamine':         'dobutamine_iv',
  'dobutrex':           'dobutamine_iv',

  // Epinephrine
  'adrenalina':         'epinephrine_iv',
  'epinefrina':         'epinephrine_iv',
  'epinephrine':        'epinephrine_iv',
  'adrenaline':         'epinephrine_iv',

  // Vasopressin
  'vasopressina':       'vasopressin_iv',
  'vasopressin':        'vasopressin_iv',
  'pitressin':          'vasopressin_iv',

  // Insulin
  'insulina':           'insulin_iv',
  'insulin':            'insulin_iv',
  'insulina regular':   'insulin_iv',

  // Midazolam
  'midazolam':          'midazolam_iv',
  'dormicum':           'midazolam_iv',

  // Propofol
  'propofol':           'propofol_iv',
  'diprivan':           'propofol_iv',

  // Morphine
  'morfina':            'morphine_iv',
  'morphine':           'morphine_iv',
};

// ── ClinicalNumericValidator ──────────────────────────────────────────────────

/// MICRO-BUILD 462E-A.5.3.7.3.2.2 [PILLAR 3]: Clinical Numeric Determinism Gate.
///
/// Validates that numeric dose values in LLM output are within the authoritative
/// preset bounds for high-risk infusion drugs. When a violation is detected,
/// returns the preset's [institutionalFallback] — never the raw LLM text.
///
/// Usage:
/// ```dart
/// final result = ClinicalNumericValidator.validate(
///   llmOutput:  qaFinalText,
///   userInput:  input,
///   presetKey:  'norepinephrine_iv',  // resolved from intent+drug
/// );
/// final safeText = result.isValid ? llmOutput : result.fallback!;
/// ```
///
/// Invariants:
///   • ZERO network calls — purely deterministic, synchronous.
///   • When no preset matches (presetKey==null), [isValid] is always true.
///   • When bounds are satisfied, [isValid] is true and [fallback] is null.
///   • When bounds are violated, [isValid] is false and [fallback] is the preset's
///     institutionalFallback string (never empty).
///   • The validator does NOT modify LLM output — it only approves or rejects it.
class ClinicalNumericValidator {
  ClinicalNumericValidator._();

  // ── MICRO-BUILD 462E-A.5.3.7.3.2.3 [PILLAR 4]: Unit-coupled extraction ────
  //
  // DESIGN INVARIANT: A numeric value is extracted for bounds checking ONLY
  // when it is directly coupled to a recognised clinical dose unit in the text.
  //
  // BYPASSED (NOT extracted):
  //   • Standalone integers or decimals without an adjacent dose unit
  //   • List ordinals: "1. Verificar...", "2. Administrar..."
  //   • Patient weight: "80 kg", "70 kg"
  //   • Volumes without dose context: "dilua em 5 mL", "100 mL SF"
  //   • Blood pressure: "PAM 65 mmHg", "PAS 120 mmHg"
  //   • Rates/counts not in dose format: "3–5 dias", "a cada 6h"
  //
  // EXTRACTED (unit-anchored):
  //   • Single unit-coupled value: "0.05 mcg/kg/min", "2 U/h", "5 mg/h"
  //   • Range where the SECOND value is unit-coupled: "0.05–0.3 mcg/kg/min"
  //     → both 0.05 AND 0.3 are captured as dose values.
  //   • pt_BR comma decimal: "0,05 mcg/kg/min" parsed as 0.05.
  //
  // CLINICAL DOSE UNIT VOCABULARY (case-insensitive):
  //   mcg/kg/min  — vasopressors (norepinephrine, dopamine, dobutamine, epinephrine)
  //   mcg/kg/h    — weight-based infusions (fentanyl, dexmedetomidine)
  //   mcg/min     — absolute vasopressor rates
  //   mg/h        — continuous infusions (morphine, midazolam mg/h form)
  //   mg/kg/h     — weight-based continuous infusions
  //   u/min | u/h | ui/h — vasopressin, insulin (U = Unit, UI = Unidade Internacional)
  //   mcg/kg      — bolus weight-based doses (not continuous; included for completeness)

  /// Combined unit-anchored pattern.
  ///
  /// Group layout for a single-unit match:
  ///   Group 1: numeric value (with optional decimal comma/dot)
  ///   Group 2: the coupled dose unit string
  ///
  /// For range-unit match:
  ///   Group 3: first endpoint of the range
  ///   Group 4: second endpoint of the range (immediately before the unit)
  ///   Group 5: the coupled dose unit string
  ///
  /// Standalone numbers WITHOUT a recognised unit are never captured.
  static final _unitAnchoredPattern = RegExp(
    r'(?:'
    // Branch A — range followed immediately by unit:
    // e.g. "0.05–0.3 mcg/kg/min" | "0,05-0,1 mg/h"
    r'(\d+[.,]\d+|\d+)\s*(?:–|-|a|to|até)\s*(\d+[.,]\d+|\d+)\s*'
    r'(mcg\/kg\/(?:min|h)|mcg\/min|mg\/(?:kg\/h|h)|u[i]?\/(?:min|h)|mcg\/kg)'
    r'|'
    // Branch B — single value followed immediately by unit:
    // e.g. "0.05 mcg/kg/min" | "5 mg/h" | "0,03 U/min"
    r'(\d+[.,]\d+|\d+)\s*'
    r'(mcg\/kg\/(?:min|h)|mcg\/min|mg\/(?:kg\/h|h)|u[i]?\/(?:min|h)|mcg\/kg)'
    r')',
    caseSensitive: false,
  );

  /// Resolves the canonical preset key from [userInput] by matching drug aliases.
  /// Returns null when no high-risk infusion drug is detected.
  static String? resolvePresetKey(String userInput) {
    final lower = userInput.toLowerCase();
    // Longest match first (e.g. 'insulina regular' before 'insulina')
    final sortedKeys = kDrugAliasToPresetKey.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final alias in sortedKeys) {
      if (lower.contains(alias)) {
        return kDrugAliasToPresetKey[alias];
      }
    }
    return null;
  }

  /// Validates [llmOutput] against the preset identified by [presetKey].
  ///
  /// Returns [ClinicalValidationResult.valid()] when:
  ///   • presetKey is null (no regulated drug detected)
  ///   • no unit-coupled dose values are found in the output
  ///   • all detected unit-coupled values are within preset bounds
  ///
  /// Returns [ClinicalValidationResult.violated(fallback)] when:
  ///   • a unit-coupled value is found AND it falls outside preset bounds
  ///
  /// BYPASS: standalone numbers (weight, volume, pressure, ordinals) are never
  /// evaluated — only values directly adjacent to a clinical dose unit.
  static ClinicalValidationResult validate({
    required String llmOutput,
    required String userInput,
    String? presetKey,
  }) {
    // Resolve preset key from user input if not explicitly provided.
    final key = presetKey ?? resolvePresetKey(userInput);
    if (key == null) return const ClinicalValidationResult.valid();

    final preset = kClinicalDosagePresets[key];
    if (preset == null) return const ClinicalValidationResult.valid();

    // Extract ONLY unit-coupled dose values from the LLM output.
    final extracted = _extractUnitCoupledDoseValues(llmOutput);
    if (extracted.isEmpty) return const ClinicalValidationResult.valid();

    // Check each unit-coupled value against the preset bounds.
    for (final value in extracted) {
      if (!preset.isWithinBounds(value)) {
        // ignore: avoid_print
        print('[CLINICAL_NUMERIC_GATE][VIOLATION] '
            'drugId=${preset.drugId} '
            'doseUnit=${preset.doseUnit} '
            'extractedValue=$value '
            'bounds=${preset.doseMin}–${preset.doseMax} '
            'action=intercept_and_replace '
            'source=${preset.sourceId}');
        return ClinicalValidationResult.violated(preset.institutionalFallback);
      }
    }

    // ignore: avoid_print
    print('[CLINICAL_NUMERIC_GATE][PASS] '
        'drugId=${preset.drugId} '
        'doseUnit=${preset.doseUnit} '
        'extractedValues=${extracted.join(",")} '
        'bounds=${preset.doseMin}–${preset.doseMax}');

    return const ClinicalValidationResult.valid();
  }

  /// Extracts ONLY unit-coupled dose values from [text].
  ///
  /// A value is considered unit-coupled if it appears immediately before
  /// a recognised clinical dose unit (with optional whitespace separator).
  ///
  /// Standalone numbers — list ordinals ("1."), weights ("80 kg"), volumes
  /// ("5 mL"), pressures ("65 mmHg"), time intervals ("6h") — are BYPASSED.
  ///
  /// Handles pt_BR comma decimal notation ("0,05" → 0.05).
  static List<double> _extractUnitCoupledDoseValues(String text) {
    final values = <double>[];

    for (final match in _unitAnchoredPattern.allMatches(text)) {
      if (match.group(1) != null && match.group(2) != null) {
        // Branch A — range: both endpoints are dose values.
        final v1 = _parseLocaleDouble(match.group(1)!);
        final v2 = _parseLocaleDouble(match.group(2)!);
        if (v1 != null && !values.contains(v1)) values.add(v1);
        if (v2 != null && !values.contains(v2)) values.add(v2);
      } else if (match.group(4) != null) {
        // Branch B — single value.
        final v = _parseLocaleDouble(match.group(4)!);
        if (v != null && !values.contains(v)) values.add(v);
      }
    }

    return values;
  }

  /// Parses a locale-aware decimal string (comma or dot separator).
  static double? _parseLocaleDouble(String s) {
    if (s.isEmpty) return null;
    // Normalise decimal comma to dot.
    return double.tryParse(s.replaceAll(',', '.'));
  }
}

// ── ClinicalValidationResult ──────────────────────────────────────────────────

/// Result of a [ClinicalNumericValidator.validate()] call.
///
/// Immutable, const-constructible.
///   • [isValid] == true  → LLM output is within bounds; no replacement needed.
///   • [isValid] == false → bounds violated; [fallback] holds the safe text.
final class ClinicalValidationResult {
  final bool isValid;
  final String? fallback;

  const ClinicalValidationResult.valid()
      : isValid = true,
        fallback = null;

  const ClinicalValidationResult.violated(String institutionalFallback)
      : isValid = false,
        fallback = institutionalFallback;
}
