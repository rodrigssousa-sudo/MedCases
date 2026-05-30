// ── lib/services/lab_normalizer.dart ─────────────────────────────────────────
// Serviço de normalização de chaves e unidades de exames laboratoriais.
//
// Responsabilidades:
//   1. Dicionário trilíngue PT/ES/EN de sinônimos → chave canônica em inglês
//   2. Conversão automática de unidades (mmol/L, µmol/L)
//   3. Dedução cruzada Ureia ↔ BUN
//   4. Deduplicação por maior confidence score
// ─────────────────────────────────────────────────────────────────────────────

import '../models/lab_result_model.dart';

class LabNormalizer {
  // ── Dicionário de sinônimos trilíngue (PT / ES / EN) ─────────────────────
  // Chave → lista de sinônimos aceitos (normalizados para lowercase+trim)
  static const Map<String, List<String>> synonyms = {

    // ── Eletrólitos ──────────────────────────────────────────────────────
    'sodium': [
      'na', 'na+', 'sodium', 'sodio', 'sódio', 'natremia',
      'natremio', 'sodio sérico', 'sódio sérico',
    ],
    'potassium': [
      'k', 'k+', 'potassium', 'potasio', 'potássio', 'kalemia',
      'potasemia', 'kaliemia', 'potassio',
    ],
    'chloride': [
      'cl', 'cl-', 'chloride', 'cloruro', 'cloro', 'cloreto',
      'cloreto sérico', 'cloruro sérico',
    ],
    'bicarbonate': [
      'hco3', 'hco₃', 'hco3-', 'bic', 'bicarbonato',
      'co2 total', 'co2t', 'co2', 'bicarbonate',
      'bicarbonato sérico', 'bicarbonate serum',
    ],
    'calcium': [
      'ca', 'ca2+', 'ca total', 'calcio', 'cálcio', 'calcium',
      'cálcio total', 'calcio total', 'cálcio sérico',
    ],
    'magnesium': [
      'mg', 'mg2+', 'magnesium', 'magnesio', 'magnésio',
      'magnésio sérico', 'magnesio sérico',
    ],
    'phosphorus': [
      'p', 'po4', 'phosphate', 'phosphorus', 'fosfato',
      'fósforo', 'fosforo', 'fósforo sérico', 'phosphate serum',
    ],

    // ── Função renal ─────────────────────────────────────────────────────
    'urea': [
      'urea', 'uréia', 'ureia', 'uréia sérica', 'urea sérica',
      'urea plasmática',
    ],
    'bun': [
      'bun', 'blood urea nitrogen', 'nitrogeno ureico',
      'nitrogênio ureico', 'nitrogen urea', 'n-urea',
    ],
    'creatinine': [
      'cr', 'crea', 'creatinine', 'creatinina',
      'creatinina sérica', 'serum creatinine',
    ],
    'uric_acid': [
      'uric acid', 'acido urico', 'ácido úrico', 'urate',
    ],

    // ── Função hepática ──────────────────────────────────────────────────
    'albumin': [
      'alb', 'albumin', 'albúmina', 'albumina',
      'albumina sérica', 'albumin serum',
    ],
    'total_protein': [
      'tp', 'total protein', 'proteína total', 'proteinas totais',
      'proteínas totales',
    ],
    'ast': [
      'ast', 'tgo', 'aspartate aminotransferase',
      'transaminasa oxalacetica', 'aspartato aminotransferase',
    ],
    'alt': [
      'alt', 'tgp', 'alanine aminotransferase',
      'transaminasa piruvica', 'alanina aminotransferase',
    ],
    'ggt': [
      'ggt', 'gamma gt', 'gamaglutamiltransferase',
      'gamma-glutamyl transferase', 'gamagt',
    ],
    'bilirubin_total': [
      'bt', 'bilirrubina total', 'bilirubin total', 'total bilirubin',
    ],
    'bilirubin_direct': [
      'bd', 'bilirrubina direta', 'bilirubin direct', 'bilirubin conjugated',
      'bilirrubina directa',
    ],
    'bilirubin_indirect': [
      'bi', 'bilirrubina indireta', 'bilirubin indirect',
      'bilirrubina indirecta',
    ],
    'alkaline_phosphatase': [
      'fa', 'alp', 'alkaline phosphatase', 'fosfatase alcalina',
      'fosfatasa alcalina',
    ],

    // ── Hemograma ────────────────────────────────────────────────────────
    'hemoglobin': [
      'hb', 'hgb', 'hemoglobin', 'hemoglobina',
      'hemoglobina total',
    ],
    'hematocrit': [
      'ht', 'hct', 'hematocrit', 'hematocrito', 'hematócrito',
    ],
    'rbc': [
      'rbc', 'eritrocitos', 'eritrócitos', 'red blood cells',
      'hemacias', 'hemácias', 'glóbulos rojos',
    ],
    'mcv': [
      'vcm', 'mcv', 'mean corpuscular volume',
      'volumen corpuscular medio', 'volume corpuscular médio',
    ],
    'mch': [
      'hcm', 'mch', 'mean corpuscular hemoglobin',
      'hemoglobina corpuscular media', 'hemoglobina corpuscular média',
    ],
    'mchc': [
      'chcm', 'mchc', 'mean corpuscular hemoglobin concentration',
      'concentración media de hemoglobina corpuscular',
    ],
    'rdw': [
      'rdw', 'amplitude de distribuição dos eritrócitos',
      'ancho de distribucion eritrocitaria',
    ],
    'wbc': [
      'wbc', 'gb', 'leucocitos', 'leucócitos', 'white blood cells',
      'glóbulos blancos', 'glóbulos brancos', 'leukocytes',
    ],
    'neutrophils': [
      'neut', 'neutrophils', 'neutrófilos', 'neutrofilos', 'pnn',
    ],
    'lymphocytes': [
      'linf', 'lymphocytes', 'linfócitos', 'linfocitos',
    ],
    'monocytes': [
      'mono', 'monocytes', 'monócitos', 'monocitos',
    ],
    'eosinophils': [
      'eos', 'eosinophils', 'eosinófilos', 'eosinofilos',
    ],
    'basophils': [
      'baso', 'basophils', 'basófilos', 'basofilos',
    ],
    'platelets': [
      'plt', 'plaquetas', 'platelets', 'thrombocytes',
      'plaquetas totais', 'recuento plaquetario',
    ],

    // ── Gasometria arterial ──────────────────────────────────────────────
    'ph': ['ph', 'ph arterial', 'ph arteriol'],
    'paco2': [
      'paco2', 'pco2', 'pco₂', 'pressão parcial co2',
      'presión parcial co2', 'partial pressure co2',
    ],
    'pao2': [
      'pao2', 'po2', 'po₂', 'pressão parcial o2',
      'presión parcial o2', 'partial pressure o2',
    ],
    'sao2': [
      'sao2', 'satO2', 'sat o2', 'saturação o2',
      'saturación o2', 'oxygen saturation',
    ],
    'base_excess': [
      'be', 'base excess', 'exceso de base', 'excesso de base',
      'exceso base', 'be arterial',
    ],
    'hco3_gas': [
      'hco3 gasometria', 'hco3 gas', 'bicarbonate gas',
      'bicarbonato gasometria',
    ],

    // ── Metabólicos / outros ─────────────────────────────────────────────
    'glucose': [
      'glic', 'glicemia', 'glucose', 'glucosa', 'glicose',
      'blood glucose', 'glicemia de jejum', 'glucemia en ayunas',
    ],
    'lactate': [
      'lact', 'lactate', 'lactato', 'láctico', 'lactico',
      'ácido lático', 'acido lactico',
    ],
    'tsh': [
      'tsh', 'thyroid stimulating hormone',
      'hormona estimulante tiroides', 'hormônio estimulante tireoide',
    ],
    'bnp': [
      'bnp', 'nt-probnp', 'pro-bnp', 'brain natriuretic peptide',
      'péptido natriurético cerebral',
    ],
    'troponin': [
      'trop', 'troponin', 'troponina', 'troponin i', 'troponin t',
      'troponina i', 'troponina t', 'high sensitivity troponin',
    ],
    'crp': [
      'pcr', 'crp', 'c-reactive protein', 'proteina c reactiva',
      'proteína c reativa', 'pcr ultrasensível',
    ],
    'procalcitonin': [
      'pct', 'procalcitonin', 'procalcitonina',
    ],
    'ferritin': [
      'ferrit', 'ferritin', 'ferritina',
    ],
    'inr': [
      'inr', 'rni', 'international normalized ratio',
      'razão normalizada internacional',
    ],
    'pt': [
      'tp', 'pt', 'prothrombin time', 'tempo de protrombina',
      'tiempo de protrombina',
    ],
    'aptt': [
      'ttpa', 'aptt', 'ptt', 'activated partial thromboplastin time',
      'tiempo de tromboplastina parcial activado',
      'tempo de tromboplastina parcial ativada',
    ],
    'd_dimer': [
      'd-dimer', 'd dímero', 'd-dímero', 'dimero d',
      'fibrin degradation product', 'fdp',
    ],
    'fibrinogen': [
      'fib', 'fibrinogen', 'fibrinogênio', 'fibrinogeno',
    ],
    'lipase': [
      'lip', 'lipase', 'lipase sérica', 'lipasa',
    ],
    'amylase': [
      'amy', 'amylase', 'amilase', 'amilasa',
    ],
    'ldh': [
      'ldh', 'lactate dehydrogenase', 'desidrogenase lática',
      'deshidrogenasa láctica',
    ],
    'cpk': [
      'ck', 'cpk', 'creatine kinase', 'creatina quinase',
      'creatin quinasa', 'ck total',
    ],
  };

  // ── API pública ───────────────────────────────────────────────────────────

  /// Normaliza uma chave de exame para a forma canônica inglesa snake_case.
  /// Se não encontrar match no dicionário, retorna o próprio input limpo.
  static String normalizeKey(String input) {
    final clean = _clean(input);
    for (final entry in synonyms.entries) {
      for (final synonym in entry.value) {
        if (clean == _clean(synonym)) return entry.key;
      }
    }
    return clean; // fallback: retorna a chave limpa sem tradução
  }

  /// Normaliza e deduplicaum lista de LabResult:
  ///   1. Resolve chave canônica
  ///   2. Converte unidades
  ///   3. Mantém apenas o resultado de maior confidence por chave
  ///   4. Deriva BUN/Ureia quando só um dos dois está presente
  static List<LabResult> normalizeResults(
    List<LabResult> results,
    String locale,
  ) {
    final Map<String, LabResult> uniqueMap = {};

    for (final r in results) {
      // Resolve chave canônica (tenta examKey primeiro, depois examName)
      final rawKey = r.examKey.isNotEmpty ? r.examKey : r.examName;
      final key = normalizeKey(rawKey);
      final normalized = _convertUnits(r.copyWith(examKey: key));

      // Mantém o de maior confidence em caso de duplicata
      final existing = uniqueMap[key];
      if (existing == null || normalized.confidence > existing.confidence) {
        uniqueMap[key] = normalized;
      }
    }

    return _addDerivedUreaBun(uniqueMap.values.toList(), locale);
  }

  // ── Conversão de unidades ─────────────────────────────────────────────────

  static LabResult _convertUnits(LabResult r) {
    final unit  = r.unit.toLowerCase().trim();
    double val  = r.value;
    String newU = r.unit;

    switch (r.examKey) {
      case 'glucose':
        // mmol/L → mg/dL  (fator: × 18.016)
        if (unit.contains('mmol')) {
          val  = double.parse((val * 18.016).toStringAsFixed(1));
          newU = 'mg/dL';
        }
        break;

      case 'creatinine':
        // µmol/L → mg/dL  (fator: ÷ 88.4)
        if (unit.contains('µmol') || unit.contains('umol') ||
            unit.contains('μmol')) {
          val  = double.parse((val / 88.4).toStringAsFixed(3));
          newU = 'mg/dL';
        }
        break;

      case 'urea':
        // µmol/L → mg/dL  (fator: ÷ 166.6)
        if (unit.contains('µmol') || unit.contains('umol') ||
            unit.contains('μmol')) {
          val  = double.parse((val / 166.6).toStringAsFixed(1));
          newU = 'mg/dL';
        }
        break;

      case 'calcium':
        // mmol/L → mg/dL  (fator: × 4.008)
        if (unit.contains('mmol')) {
          val  = double.parse((val * 4.008).toStringAsFixed(2));
          newU = 'mg/dL';
        }
        break;

      case 'hemoglobin':
        // mmol/L → g/dL  (fator: × 1.6113)
        if (unit.contains('mmol')) {
          val  = double.parse((val * 1.6113).toStringAsFixed(1));
          newU = 'g/dL';
        }
        break;

      case 'sodium':
      case 'potassium':
      case 'chloride':
      case 'bicarbonate':
        // mmol/L = mEq/L para eletrólitos 1:1 — apenas normaliza a label
        if (unit.contains('mmol')) {
          newU = 'mEq/L';
        }
        break;
    }

    // Substituição de vírgula por ponto (valores que passaram como string)
    if (val != r.value || newU != r.unit) {
      return r.copyWith(value: val, unit: newU);
    }
    return r;
  }

  // ── Derivação cruzada Ureia ↔ BUN ─────────────────────────────────────────
  // Relação: BUN (mg/dL) = Ureia (mg/dL) / 2.14
  //           Ureia (mg/dL) = BUN (mg/dL) × 2.14

  static List<LabResult> _addDerivedUreaBun(
    List<LabResult> results,
    String locale,
  ) {
    final hasUrea = results.any((r) => r.examKey == 'urea');
    final hasBun  = results.any((r) => r.examKey == 'bun');
    final isEs    = locale.toLowerCase() == 'es';
    final updated = [...results];

    if (hasUrea && !hasBun) {
      final urea = results.firstWhere((r) => r.examKey == 'urea');
      updated.add(LabResult(
        examKey:      'bun',
        examName:     isEs ? 'BUN (estimado)' : 'BUN (estimado)',
        value:        double.parse((urea.value / 2.14).toStringAsFixed(2)),
        unit:         'mg/dL',
        referenceRange: '7–20',
        status:       LabStatus.normal,
        confidence:   urea.confidence,
        originalText: isEs
            ? 'Calculado a partir de la urea (÷ 2.14)'
            : 'Calculado a partir da ureia (÷ 2,14)',
      ));
    }

    if (hasBun && !hasUrea) {
      final bun = results.firstWhere((r) => r.examKey == 'bun');
      updated.add(LabResult(
        examKey:      'urea',
        examName:     isEs ? 'Urea (estimada)' : 'Ureia (estimada)',
        value:        double.parse((bun.value * 2.14).toStringAsFixed(1)),
        unit:         'mg/dL',
        referenceRange: '15–40',
        status:       LabStatus.normal,
        confidence:   bun.confidence,
        originalText: isEs
            ? 'Calculada a partir del BUN (× 2.14)'
            : 'Calculada a partir do BUN (× 2,14)',
      ));
    }

    return updated;
  }

  // ── Utilitário interno ────────────────────────────────────────────────────

  /// Normaliza string para comparação: lowercase, sem espaços extras,
  /// vírgula → ponto, remove acentos básicos para aumentar tolerância.
  static String _clean(String text) {
    return text
        .toLowerCase()
        .trim()
        .replaceAll(',', '.')
        .replaceAll(RegExp(r'\s+'), ' ')
        // Remove diacríticos comuns PT/ES para match mais robusto
        .replaceAll('á', 'a').replaceAll('â', 'a').replaceAll('ã', 'a')
        .replaceAll('é', 'e').replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o').replaceAll('ô', 'o').replaceAll('õ', 'o')
        .replaceAll('ú', 'u').replaceAll('ü', 'u')
        .replaceAll('ç', 'c').replaceAll('ñ', 'n');
  }
}
