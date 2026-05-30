// ── lib/services/lab_interpreter.dart ────────────────────────────────────────
// Motor de cálculos clínicos derivados e geração de resumo educacional.
//
// Cálculos implementados:
//   1. Gap Aniônico (Anion Gap)
//   2. Gap Aniônico corrigido por Albumina
//   3. Sódio corrigido por Glicose (Katz)
//   4. Cálcio corrigido por Albumina
//   5. Osmolaridade Plasmática Calculada
//
// Resumo educacional:
//   • Gasometria (pH, pCO₂, HCO₃⁻)
//   • Hemograma (Hb, VCM, Leucócitos, Plaquetas)
//   • Função Renal (Creatinina, Ureia)
//   • Eletrólitos críticos
//   • Aviso obrigatório de segurança médico-legal
//
// Linguagem: neutro, educacional, evita diagnósticos fechados.
// Termos: "sugere", "compatível com", "avaliar", "correlacionar".
// ─────────────────────────────────────────────────────────────────────────────

import '../models/lab_result_model.dart';

// ── Modelo de resultado calculado ─────────────────────────────────────────────

class LabCalculatedResult {
  /// Título do parâmetro calculado (no idioma do usuário).
  final String title;

  /// Valor numérico calculado.
  final double value;

  /// Unidade de medida.
  final String unit;

  /// Interpretação educacional textual.
  final String interpretation;

  /// Classificação clínica do resultado calculado.
  final LabStatus status;

  const LabCalculatedResult({
    required this.title,
    required this.value,
    required this.unit,
    required this.interpretation,
    required this.status,
  });
}

// ── Motor de interpretação ─────────────────────────────────────────────────────

class LabInterpreter {
  // ── Cálculos derivados ──────────────────────────────────────────────────

  /// Calcula todos os parâmetros derivados possíveis dado o conjunto de exames.
  /// Retorna lista vazia se os dados necessários não estiverem presentes.
  static List<LabCalculatedResult> calculate(
    List<LabResult> labs,
    String locale,
  ) {
    final map   = {for (final lab in labs) lab.examKey: lab.value};
    final isEs  = locale.toLowerCase() == 'es';
    final out   = <LabCalculatedResult>[];

    final na      = map['sodium'];
    final cl      = map['chloride'];
    final hco3    = map['bicarbonate'];
    final albumin = map['albumin'];
    final glucose = map['glucose'];
    final calcium = map['calcium'];
    final bun     = map['bun'];

    // ── 1. Gap Aniônico (AG = Na − (Cl + HCO₃)) ─────────────────────────
    if (na != null && cl != null && hco3 != null) {
      final ag = na - (cl + hco3);
      final agHigh = ag > 12;
      out.add(LabCalculatedResult(
        title: isEs ? 'Brecha Aniónica' : 'Gap Aniônico',
        value: _round2(ag),
        unit: 'mEq/L',
        status: agHigh ? LabStatus.high : LabStatus.normal,
        interpretation: isEs
            ? (agHigh
                ? 'Brecha aniónica elevada (>12 mEq/L). Sugiere acumulación de '
                  'ácidos no medidos. Considerar diagnósticos diferenciales: '
                  'acidosis láctica, cetoacidosis, intoxicaciones (MUDPILES). '
                  'Correlacionar con pH y lactato.'
                : 'Brecha aniónica dentro del rango habitual (8–12 mEq/L).')
            : (agHigh
                ? 'Gap aniônico elevado (>12 mEq/L). Sugere acúmulo de ácidos '
                  'não mensurados. Considerar diagnósticos diferenciais: '
                  'acidose lática, cetoacidose, intoxicações (MUDPILES). '
                  'Correlacionar com pH e lactato.'
                : 'Gap aniônico dentro da faixa habitual (8–12 mEq/L).'),
      ));

      // ── 2. AG corrigido por Albumina (Corrected AG = AG + 2.5 × (4.0 − Alb)) ─
      if (albumin != null) {
        final correction  = 2.5 * (4.0 - albumin);
        final corrAg      = ag + correction;
        final corrAgHigh  = corrAg > 12;
        out.add(LabCalculatedResult(
          title: isEs
              ? 'Brecha Aniónica Corregida (Albumina)'
              : 'Gap Aniônico Corrigido (Albumina)',
          value: _round2(corrAg),
          unit: 'mEq/L',
          status: corrAgHigh ? LabStatus.high : LabStatus.normal,
          interpretation: isEs
              ? 'Ajuste aplicado por hipoalbuminemia '
                '(albumina = ${albumin.toStringAsFixed(1)} g/dL). '
                'Evita enmascarar una brecha aniónica elevada en pacientes '
                'desnutridos o con síndrome nefrótico.'
              : 'Ajuste aplicado por hipoalbuminemia '
                '(albumina = ${albumin.toStringAsFixed(1)} g/dL). '
                'Evita falso negativo de gap elevado em pacientes desnutridos '
                'ou com síndrome nefrótico.',
        ));
      }
    }

    // ── 3. Sódio corrigido pela Glicose (Katz: Na_corr = Na + 0.016 × (Glic − 100)) ─
    if (na != null && glucose != null && glucose > 100) {
      final corrNa     = na + 0.016 * (glucose - 100);
      final naAbnormal = corrNa < 135 || corrNa > 145;
      out.add(LabCalculatedResult(
        title: isEs ? 'Sodio Corregido (Glucosa)' : 'Sódio Corrigido (Glicose)',
        value: _round2(corrNa),
        unit: 'mEq/L',
        status: naAbnormal ? LabStatus.high : LabStatus.normal,
        interpretation: isEs
            ? 'Corrección de Katz aplicada (glucosa = ${glucose.toStringAsFixed(0)} mg/dL). '
              'Refleja el sodio verdadero al descontar el desplazamiento osmótico '
              'inducido por la hiperglucemia.'
            : 'Correção de Katz aplicada (glicose = ${glucose.toStringAsFixed(0)} mg/dL). '
              'Reflete o sódio verdadeiro ao descontar o deslocamento osmótico '
              'induzido pela hiperglicemia.',
      ));
    }

    // ── 4. Cálcio corrigido por Albumina (Ca_corr = Ca + 0.8 × (4.0 − Alb)) ──
    if (calcium != null && albumin != null) {
      final corrCa     = calcium + 0.8 * (4.0 - albumin);
      final caAbnormal = corrCa < 8.5 || corrCa > 10.5;
      out.add(LabCalculatedResult(
        title: isEs ? 'Calcio Corregido (Albumina)' : 'Cálcio Corrigido (Albumina)',
        value: _round2(corrCa),
        unit: 'mg/dL',
        status: caAbnormal
            ? (corrCa > 13 || corrCa < 6.5 ? LabStatus.critical : LabStatus.high)
            : LabStatus.normal,
        interpretation: isEs
            ? 'Corrección por albumina sérica '
              '(albumina = ${albumin.toStringAsFixed(1)} g/dL). '
              'Recomendada para evaluación en hipoalbuminemia. '
              '(Faja de referencia corregida: 8.5–10.5 mg/dL)'
            : 'Correção pela albumina sérica '
              '(albumina = ${albumin.toStringAsFixed(1)} g/dL). '
              'Recomendada na avaliação em hipoalbuminemia. '
              '(Faixa de referência corrigida: 8,5–10,5 mg/dL)',
      ));
    }

    // ── 5. Osmolaridade Plasmática Calculada (2×Na + Glic/18 + BUN/2.8) ──
    if (na != null && glucose != null && bun != null) {
      final osm      = (2 * na) + (glucose / 18) + (bun / 2.8);
      final osmHigh  = osm > 295;
      final osmCrit  = osm > 320;
      out.add(LabCalculatedResult(
        title: isEs
            ? 'Osmolaridad Plasmática Calculada'
            : 'Osmolaridade Plasmática Calculada',
        value: _round2(osm),
        unit: 'mOsm/kg',
        status: osmCrit
            ? LabStatus.critical
            : (osmHigh ? LabStatus.high : LabStatus.normal),
        interpretation: isEs
            ? (osmCrit
                ? 'Hiperosmolaridad grave (>320 mOsm/kg). Compatible con estado '
                  'hiperosmolar hiperglucémico u otras causas de hiperosmolaridad. '
                  'Requiere evaluación urgente y reposición hídrica guiada.'
                : osmHigh
                    ? 'Osmolaridad levemente elevada (>295 mOsm/kg). '
                      'Evaluar estado de hidratación, ingesta de solutos y '
                      'posibles causas subyacentes.'
                    : 'Osmolaridad dentro del rango de referencia (275–295 mOsm/kg).')
            : (osmCrit
                ? 'Hiperosmolaridade grave (>320 mOsm/kg). Compatível com estado '
                  'hiperosmolar hiperglicêmico ou outras causas de hiperosmolaridade. '
                  'Requer avaliação urgente e reposição hídrica orientada.'
                : osmHigh
                    ? 'Osmolaridade levemente elevada (>295 mOsm/kg). '
                      'Avaliar estado de hidratação, ingestão de solutos e '
                      'possíveis causas subjacentes.'
                    : 'Osmolaridade dentro da faixa de referência (275–295 mOsm/kg).'),
      ));
    }

    return out;
  }

  // ── Resumo educacional ─────────────────────────────────────────────────────

  /// Gera um resumo textual estruturado dos achados laboratoriais.
  ///
  /// Linguagem deliberadamente neutral (sugere / compatível com / avaliar),
  /// sem diagnósticos fechados, terminado sempre com aviso de segurança.
  static String buildEducationalSummary(
    List<LabResult> labs,
    List<LabCalculatedResult> calculated,
    String locale,
  ) {
    final map  = {for (final lab in labs) lab.examKey: lab.value};
    final isEs = locale.toLowerCase() == 'es';
    final sb   = StringBuffer();

    // ── Cabeçalho ─────────────────────────────────────────────────────────
    sb.writeln(isEs
        ? 'Examen importado por OCR — ${labs.length} parámetro(s) identificado(s).'
        : 'Exame importado por OCR — ${labs.length} parâmetro(s) identificado(s).');

    // ── Gasometria ────────────────────────────────────────────────────────
    final ph    = map['ph'];
    final paco2 = map['paco2'];
    final hco3  = map['bicarbonate'];
    if (ph != null || paco2 != null || hco3 != null) {
      sb.write(isEs ? '\n• Gasometría: ' : '\n• Gasometria: ');

      final phV    = ph    ?? 7.40;
      final paco2V = paco2 ?? 40.0;
      final hco3V  = hco3  ?? 24.0;

      if (phV < 7.35) {
        sb.write(isEs
            ? 'Sugiere propensión a acidemia (pH ${phV.toStringAsFixed(2)}). '
            : 'Sugere propensão à acidemia (pH ${phV.toStringAsFixed(2)}). ');
      } else if (phV > 7.45) {
        sb.write(isEs
            ? 'Sugiere propensión a alcalemia (pH ${phV.toStringAsFixed(2)}). '
            : 'Sugere propensão à alcalemia (pH ${phV.toStringAsFixed(2)}). ');
      } else {
        sb.write(isEs ? 'pH dentro del rango normal. ' : 'pH dentro da faixa normal. ');
      }

      if (paco2V > 45 || paco2V < 35) {
        sb.write(isEs
            ? 'pCO₂ ${paco2V > 45 ? "elevado" : "disminuido"} '
              '(${paco2V.toStringAsFixed(0)} mmHg) — '
              'compatible con componente ${paco2V > 45 ? "respiratorio acidótico" : "respiratorio alcalótico"} '
              'o compensación metabólica en desarrollo. '
            : 'pCO₂ ${paco2V > 45 ? "elevado" : "reduzido"} '
              '(${paco2V.toStringAsFixed(0)} mmHg) — '
              'compatível com componente ${paco2V > 45 ? "respiratório acidótico" : "respiratório alcalótico"} '
              'ou compensação metabólica em andamento. ');
      }

      if (hco3V < 22 || hco3V > 26) {
        sb.write(isEs
            ? 'HCO₃⁻ ${hco3V < 22 ? "reducido" : "elevado"} '
              '(${hco3V.toStringAsFixed(1)} mEq/L). '
            : 'HCO₃⁻ ${hco3V < 22 ? "reduzido" : "elevado"} '
              '(${hco3V.toStringAsFixed(1)} mEq/L). ');
      }
    }

    // ── Hemograma ─────────────────────────────────────────────────────────
    final hb  = map['hemoglobin'];
    final mcv = map['mcv'];
    final wbc = map['wbc'];
    final plt = map['platelets'];
    if (hb != null || wbc != null || plt != null) {
      sb.write(isEs ? '\n• Hemograma: ' : '\n• Hemograma: ');

      if (hb != null) {
        if (hb < 7.0) {
          sb.write(isEs
              ? 'Anemia grave (Hb ${hb.toStringAsFixed(1)} g/dL) — '
                'riesgo aumentado de descompensación hemodinámica. '
              : 'Anemia grave (Hb ${hb.toStringAsFixed(1)} g/dL) — '
                'risco elevado de descompensação hemodinâmica. ');
        } else if (hb < 10.0) {
          sb.write(isEs
              ? 'Evolución compatible con anemia moderada (Hb ${hb.toStringAsFixed(1)} g/dL). '
              : 'Evolução compatível com anemia moderada (Hb ${hb.toStringAsFixed(1)} g/dL). ');
        } else if (hb < 12.0) {
          sb.write(isEs
              ? 'Hemoglobina levemente reducida (${hb.toStringAsFixed(1)} g/dL). '
              : 'Hemoglobina levemente reduzida (${hb.toStringAsFixed(1)} g/dL). ');
        }

        if (hb < 12.0 && mcv != null) {
          if (mcv < 80) {
            sb.write(isEs ? 'Perfil microcítico (VCM < 80 fL). ' : 'Perfil microcítico (VCM < 80 fL). ');
          } else if (mcv > 100) {
            sb.write(isEs ? 'Perfil macrocítico (VCM > 100 fL). ' : 'Perfil macrocítico (VCM > 100 fL). ');
          } else {
            sb.write(isEs ? 'Perfil normocítico. ' : 'Perfil normocítico. ');
          }
        }
      }

      if (wbc != null) {
        if (wbc > 11000) {
          sb.write(isEs
              ? 'Leucocitosis (${(wbc / 1000).toStringAsFixed(1)}×10³/µL) — '
                'avaliar infección, inflamación u otras causas. '
              : 'Leucocitose (${(wbc / 1000).toStringAsFixed(1)}×10³/µL) — '
                'avaliar infecção, inflamação ou outras causas. ');
        } else if (wbc < 4000) {
          sb.write(isEs
              ? 'Leucopenia (${(wbc / 1000).toStringAsFixed(1)}×10³/µL) — '
                'correlacionar con cuadro clínico. '
              : 'Leucopenia (${(wbc / 1000).toStringAsFixed(1)}×10³/µL) — '
                'correlacionar com o quadro clínico. ');
        }
      }

      if (plt != null) {
        if (plt < 20000) {
          sb.write(isEs
              ? 'Trombocitopenia grave (<20.000/µL) — riesgo hemorrágico crítico. '
              : 'Trombocitopenia grave (<20.000/µL) — risco hemorrágico crítico. ');
        } else if (plt < 50000) {
          sb.write(isEs
              ? 'Trombocitopenia moderada (${(plt / 1000).toStringAsFixed(0)}×10³/µL). '
              : 'Trombocitopenia moderada (${(plt / 1000).toStringAsFixed(0)}×10³/µL). ');
        } else if (plt < 150000) {
          sb.write(isEs
              ? 'Plaquetas levemente reducidas (${(plt / 1000).toStringAsFixed(0)}×10³/µL). '
              : 'Plaquetas levemente reduzidas (${(plt / 1000).toStringAsFixed(0)}×10³/µL). ');
        }
      }
    }

    // ── Função renal ──────────────────────────────────────────────────────
    final cr   = map['creatinine'];
    final urea = map['urea'];
    if (cr != null || urea != null) {
      sb.write(isEs ? '\n• Función Renal: ' : '\n• Função Renal: ');

      if (cr != null) {
        if (cr > 3.0) {
          sb.write(isEs
              ? 'Creatinina gravemente elevada (${cr.toStringAsFixed(2)} mg/dL) — '
                'compatible con injuria renal aguda grave o enfermedad renal crónica avanzada. '
              : 'Creatinina gravemente elevada (${cr.toStringAsFixed(2)} mg/dL) — '
                'compatível com injúria renal aguda grave ou doença renal crônica avançada. ');
        } else if (cr > 1.2) {
          sb.write(isEs
              ? 'Creatinina elevada (${cr.toStringAsFixed(2)} mg/dL) — '
                'alerta para posible lesión o disfunción renal. '
              : 'Creatinina elevada (${cr.toStringAsFixed(2)} mg/dL) — '
                'alerta para possível lesão ou disfunção renal. ');
        } else {
          sb.write(isEs
              ? 'Creatinina dentro del rango habitual. '
              : 'Creatinina dentro da faixa habitual. ');
        }
      }

      if (urea != null && urea > 40) {
        sb.write(isEs
            ? 'Urea elevada (${urea.toStringAsFixed(0)} mg/dL) — '
              'avaliar función renal y estado de hidratación. '
            : 'Ureia elevada (${urea.toStringAsFixed(0)} mg/dL) — '
              'avaliar função renal e estado de hidratação. ');
      }
    }

    // ── Eletrólitos críticos ───────────────────────────────────────────────
    final na    = map['sodium'];
    final k     = map['potassium'];
    final lactate = map['lactate'];
    if (na != null || k != null || lactate != null) {
      sb.write(isEs ? '\n• Electrolitos / Metabólicos: ' : '\n• Eletrólitos / Metabólicos: ');

      if (na != null) {
        if (na < 130) {
          sb.write(isEs
              ? 'Hiponatremia (Na⁺ ${na.toStringAsFixed(0)} mEq/L). '
              : 'Hiponatremia (Na⁺ ${na.toStringAsFixed(0)} mEq/L). ');
        } else if (na > 150) {
          sb.write(isEs
              ? 'Hipernatremia (Na⁺ ${na.toStringAsFixed(0)} mEq/L). '
              : 'Hipernatremia (Na⁺ ${na.toStringAsFixed(0)} mEq/L). ');
        }
      }

      if (k != null) {
        if (k < 3.0) {
          sb.write(isEs
              ? 'Hipopotasemia (K⁺ ${k.toStringAsFixed(1)} mEq/L). '
              : 'Hipopotassemia (K⁺ ${k.toStringAsFixed(1)} mEq/L). ');
        } else if (k > 5.5) {
          sb.write(isEs
              ? 'Hiperpotasemia (K⁺ ${k.toStringAsFixed(1)} mEq/L). '
              : 'Hiperpotassemia (K⁺ ${k.toStringAsFixed(1)} mEq/L). ');
        }
      }

      if (lactate != null && lactate >= 2.0) {
        sb.write(isEs
            ? 'Lactato elevado (${lactate.toStringAsFixed(1)} mmol/L) — '
              '${lactate >= 4 ? "hiperlactatemia grave, correlacionar con perfusión tisular" : "hiperlactatemia moderada, monitorizar"}. '
            : 'Lactato elevado (${lactate.toStringAsFixed(1)} mmol/L) — '
              '${lactate >= 4 ? "hiperlactatemia grave, correlacionar com perfusão tecidual" : "hiperlactatemia moderada, monitorizar"}. ');
      }
    }

    // ── Parâmetros calculados no sumário ──────────────────────────────────
    if (calculated.isNotEmpty) {
      sb.write(isEs
          ? '\n• Parámetros calculados: '
          : '\n• Parâmetros calculados: ');
      for (final c in calculated) {
        sb.write('${c.title} = ${c.value.toStringAsFixed(2)} ${c.unit}');
        if (c.status == LabStatus.high || c.status == LabStatus.critical) {
          sb.write(isEs ? ' ⚠️ (alterado)' : ' ⚠️ (alterado)');
        }
        sb.write('. ');
      }
    }

    // ── Aviso legal obrigatório ───────────────────────────────────────────
    sb.writeln();
    sb.writeln(isEs
        ? '\n⚠️ Resultado extraído automáticamente. Cotejar con el examen original '
          'antes de cualquier decisión clínica. Requiere correlación directa con '
          'el cuadro clínico y el historial del paciente.'
        : '\n⚠️ Resultado extraído automaticamente. Conferir com o exame original '
          'antes de qualquer decisão clínica. Requer correlação direta com o '
          'quadro clínico e o histórico do paciente.');

    return sb.toString();
  }

  // ── Helper ────────────────────────────────────────────────────────────────

  static double _round2(double v) =>
      double.parse(v.toStringAsFixed(2));
}
