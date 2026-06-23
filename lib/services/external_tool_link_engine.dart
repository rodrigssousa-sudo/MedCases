// ══════════════════════════════════════════════════════════════════════════════
// external_tool_link_engine.dart — Deep Link Router v1 (Build 185)
//
// MOTOR 100% LOCAL — DETERMINÍSTICO — SEM IA — SEM REDE — SEM RAG
//
// Responsabilidade exclusiva:
//   • Detectar termo técnico clínico em lastUserMessage + lastAiResponse.
//   • Mapear para uma das 10 abas de medcasescalcu.com.
//   • Gerar URL limpa com query param técnico (NUNCA dados do paciente).
//   • Retornar label localizado (PT-BR / ES) para o botão _ExternalToolButton.
//
// Segurança absoluta:
//   • Apenas termos técnicos isolados (nome do fármaco, score, calculadora).
//   • NUNCA inclui: nome do paciente, idade, dados vitais, diagnóstico completo.
//   • URL máxima: base + tab + 1-2 query params de máx 40 chars cada.
//
// Rotas disponíveis em medcasescalcu.com:
//   ?tab=farmacos&q=<nome>
//   ?tab=interacoes&drug1=<d1>&drug2=<d2>
//   ?tab=scores&q=<nome>
//   ?tab=calculadoras&q=<nome>
//   ?tab=eletrolitos&q=<nome>
//   ?tab=infusao&q=<nome>
//   ?tab=hemodinamica&q=<nome>
//   ?tab=fluidos
//   ?tab=pediatria
//   ?tab=gestante
// ══════════════════════════════════════════════════════════════════════════════

const String _kBase = 'https://medcasescalcu.com/';

// ─────────────────────────────────────────────────────────────────────────────
// Output model
// ─────────────────────────────────────────────────────────────────────────────
class ExternalToolLink {
  final String label; // PT/ES button label shown to user
  final String url;   // full https://medcasescalcu.com/?tab=...&q=...

  const ExternalToolLink({required this.label, required this.url});
}

// ─────────────────────────────────────────────────────────────────────────────
// Engine — all static, zero-state, zero-network
// ─────────────────────────────────────────────────────────────────────────────
class ExternalToolLinkEngine {
  ExternalToolLinkEngine._();

  /// Returns an [ExternalToolLink] if a relevant external tool is detected,
  /// or null if no match found.
  static ExternalToolLink? build({
    required String lastUserMessage,
    required String lastAiResponse,
    required bool isPlantaoMode,
    required String currentLanguage,
  }) {
    final bool isEs = currentLanguage.toLowerCase().startsWith('es');

    // Combine user + AI text for detection (lowercase, no diacritics normalization)
    final String combined =
        '${lastUserMessage.toLowerCase()} ${lastAiResponse.toLowerCase()}';

    // ── 1. Interações medicamentosas (dois fármacos detectados) ────────────
    final interacao = _detectDrugInteraction(combined);
    if (interacao != null) {
      final label = isEs
          ? '💊 Verificar interacción'
          : '💊 Verificar interação';
      return ExternalToolLink(
        label: label,
        url: '${_kBase}?tab=interacoes&drug1=${_enc(interacao.$1)}&drug2=${_enc(interacao.$2)}',
      );
    }

    // ── 2. Scores / Escalas clínicas ──────────────────────────────────────
    final score = _detectScore(combined);
    if (score != null) {
      final label = isEs
          ? '📊 Abrir ${score.display}'
          : '📊 Abrir ${score.display}';
      return ExternalToolLink(
        label: label,
        url: '${_kBase}?tab=scores&q=${_enc(score.param)}',
      );
    }

    // ── 3. Calculadoras clínicas ───────────────────────────────────────────
    final calcu = _detectCalculadora(combined);
    if (calcu != null) {
      final label = isEs
          ? '🧮 Calcular ${calcu.display}'
          : '🧮 Calcular ${calcu.display}';
      return ExternalToolLink(
        label: label,
        url: '${_kBase}?tab=calculadoras&q=${_enc(calcu.param)}',
      );
    }

    // ── 4. Eletrólitos ────────────────────────────────────────────────────
    final eletro = _detectEletrolito(combined);
    if (eletro != null) {
      final label = isEs
          ? '⚗️ Abrir electrolitos'
          : '⚗️ Abrir eletrólitos';
      return ExternalToolLink(
        label: label,
        url: '${_kBase}?tab=eletrolitos&q=${_enc(eletro.param)}',
      );
    }

    // ── 5. Infusão / Drogas vasoativas ────────────────────────────────────
    final infusao = _detectInfusao(combined);
    if (infusao != null) {
      final label = isEs
          ? '💉 Abrir infusión'
          : '💉 Abrir infusão';
      return ExternalToolLink(
        label: label,
        url: '${_kBase}?tab=infusao&q=${_enc(infusao.param)}',
      );
    }

    // ── 6. Hemodinâmica ───────────────────────────────────────────────────
    final hemodi = _detectHemodinamica(combined);
    if (hemodi != null) {
      final label = isEs
          ? '❤️ Abrir hemodinámica'
          : '❤️ Abrir hemodinâmica';
      return ExternalToolLink(
        label: label,
        url: '${_kBase}?tab=hemodinamica&q=${_enc(hemodi.param)}',
      );
    }

    // ── 7. Fluidos / Reposição volêmica ───────────────────────────────────
    if (_detectFluidos(combined)) {
      final label = isEs ? '🩺 Fluidos y volumen' : '🩺 Fluidos e volume';
      return ExternalToolLink(
        label: label,
        url: '${_kBase}?tab=fluidos',
      );
    }

    // ── 8. Pediatria ─────────────────────────────────────────────────────
    if (_detectPediatria(combined)) {
      final label = isEs ? '👶 Módulo pediatría' : '👶 Módulo pediatria';
      return ExternalToolLink(
        label: label,
        url: '${_kBase}?tab=pediatria',
      );
    }

    // ── 9. Gestante / Obstetrícia ─────────────────────────────────────────
    if (_detectGestante(combined)) {
      final label = isEs ? '🤰 Módulo gestante' : '🤰 Módulo gestante';
      return ExternalToolLink(
        label: label,
        url: '${_kBase}?tab=gestante',
      );
    }

    // ── 10. Fármaco isolado (último pois menos específico) ────────────────
    final drug = _detectSingleDrug(combined);
    if (drug != null) {
      final label = isEs
          ? '💊 Abrir ${drug.display} en la base'
          : '💊 Abrir ${drug.display} na base';
      return ExternalToolLink(
        label: label,
        url: '${_kBase}?tab=farmacos&q=${_enc(drug.param)}',
      );
    }

    return null;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // URL encoding helper — only technical term, max 40 chars, lowercase
  // ───────────────────────────────────────────────────────────────────────────
  static String _enc(String term) {
    final safe = term.trim().toLowerCase().replaceAll(' ', '-');
    final capped = safe.length > 40 ? safe.substring(0, 40) : safe;
    return Uri.encodeQueryComponent(capped);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // _TermMatch — lightweight named pair for (param, display)
  // ───────────────────────────────────────────────────────────────────────────
  static _TermMatch? _matchFirst(String text, List<_TermMatch> table) {
    for (final entry in table) {
      for (final kw in entry.keywords) {
        if (text.contains(kw)) return entry;
      }
    }
    return null;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // DRUG INTERACTION — detects 2 drugs from combined text
  // Returns (drug1_param, drug2_param) or null
  // ───────────────────────────────────────────────────────────────────────────
  static (String, String)? _detectDrugInteraction(String text) {
    final List<_TermMatch> drugs = _kDrugs;
    final List<_TermMatch> found = [];
    for (final d in drugs) {
      for (final kw in d.keywords) {
        if (text.contains(kw)) {
          if (!found.any((f) => f.param == d.param)) found.add(d);
          break;
        }
      }
      if (found.length >= 2) break;
    }
    if (found.length >= 2) return (found[0].param, found[1].param);
    return null;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SINGLE DRUG
  // ───────────────────────────────────────────────────────────────────────────
  static _TermMatch? _detectSingleDrug(String text) =>
      _matchFirst(text, _kDrugs);

  // ───────────────────────────────────────────────────────────────────────────
  // SCORES
  // ───────────────────────────────────────────────────────────────────────────
  static _TermMatch? _detectScore(String text) =>
      _matchFirst(text, _kScores);

  // ───────────────────────────────────────────────────────────────────────────
  // CALCULADORAS
  // ───────────────────────────────────────────────────────────────────────────
  static _TermMatch? _detectCalculadora(String text) =>
      _matchFirst(text, _kCalculadoras);

  // ───────────────────────────────────────────────────────────────────────────
  // ELETRÓLITOS
  // ───────────────────────────────────────────────────────────────────────────
  static _TermMatch? _detectEletrolito(String text) =>
      _matchFirst(text, _kEletrolitos);

  // ───────────────────────────────────────────────────────────────────────────
  // INFUSÃO
  // ───────────────────────────────────────────────────────────────────────────
  static _TermMatch? _detectInfusao(String text) =>
      _matchFirst(text, _kInfusao);

  // ───────────────────────────────────────────────────────────────────────────
  // HEMODINÂMICA
  // ───────────────────────────────────────────────────────────────────────────
  static _TermMatch? _detectHemodinamica(String text) =>
      _matchFirst(text, _kHemodinamica);

  // ───────────────────────────────────────────────────────────────────────────
  // FLUIDOS — keywords genéricos de reposição volêmica
  // ───────────────────────────────────────────────────────────────────────────
  static bool _detectFluidos(String text) {
    const kws = [
      'cristaloide', 'coloide', 'soro fisiol', 'solução salina',
      'reposição vol', 'reposição hídrica', 'expansão vol',
      'ringer lactato', 'albumina 4%', 'albumina 20%',
      'fluidoterapia', 'hidratação venosa', 'fluidoterapy',
      'bolus de soro', 'ressuscitação vol', 'resucitación vol',
      'balance hídrico', 'balanço hídrico', 'balanço hídrico',
    ];
    for (final kw in kws) {
      if (text.contains(kw)) return true;
    }
    return false;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // PEDIATRIA
  // ───────────────────────────────────────────────────────────────────────────
  static bool _detectPediatria(String text) {
    const kws = [
      'pediatri', 'neonato', 'neonat', 'recém-nascido', 'recien nacido',
      'lactente', 'criança', 'niño', 'pediátric', 'pediatric',
      'bronquiolit', 'croup', 'laringite', 'garrotillo',
      'kg/m²', 'dose pediátrica', 'dose pediatrica',
    ];
    for (final kw in kws) {
      if (text.contains(kw)) return true;
    }
    return false;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // GESTANTE / OBSTETRÍCIA
  // ───────────────────────────────────────────────────────────────────────────
  static bool _detectGestante(String text) {
    const kws = [
      'gestante', 'gestação', 'gravidez', 'grávida',
      'embarazo', 'embarazada', 'gestación',
      'pré-eclâmpsia', 'preeclampsia', 'eclâmpsia', 'eclampsia',
      'hellp', 'pprom', 'rotura prematura', 'trabalho de parto',
      'parto prematuro', 'parto pretérmino', 'obstetri',
      'sulfato de magnésio', 'sulfato de magnesio',
      'betametasona gestante', 'corticoide fetal',
    ];
    for (final kw in kws) {
      if (text.contains(kw)) return true;
    }
    return false;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TermMatch — internal data class
// ─────────────────────────────────────────────────────────────────────────────
class _TermMatch {
  final String param;    // URL query value (lowercase, no accent)
  final String display;  // Human-readable button label segment
  final List<String> keywords; // All trigger substrings (lowercase)

  const _TermMatch({
    required this.param,
    required this.display,
    required this.keywords,
  });
}

// ═════════════════════════════════════════════════════════════════════════════
// KNOWLEDGE TABLES — curated, exhaustive, deterministic
// ═════════════════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────────────────────
// DRUGS — ordered by clinical frequency in ER/ICU/Ward
// Each entry: param (URL slug) · display (label) · keywords (trigger list)
// ─────────────────────────────────────────────────────────────────────────────
const List<_TermMatch> _kDrugs = [
  // Antibióticos
  _TermMatch(param: 'ceftriaxona', display: 'Ceftriaxona',
      keywords: ['ceftriaxona', 'ceftriaxone', 'rocefin']),
  _TermMatch(param: 'piperacilina-tazobactam', display: 'Pip-Tazo',
      keywords: ['piperacilina', 'piperacillin', 'tazobactam', 'pip-tazo', 'tazocin']),
  _TermMatch(param: 'meropenem', display: 'Meropenem',
      keywords: ['meropenem', 'meronem']),
  _TermMatch(param: 'vancomicina', display: 'Vancomicina',
      keywords: ['vancomicina', 'vancomycin', 'vancocin']),
  _TermMatch(param: 'ciprofloxacino', display: 'Ciprofloxacino',
      keywords: ['ciprofloxacino', 'ciprofloxacin', 'cipro']),
  _TermMatch(param: 'amoxicilina-clavulanato', display: 'Amoxicilina-Clavulanato',
      keywords: ['amoxicilina-clavulan', 'amoxicillin-clav', 'clavulanato', 'augmentin']),
  _TermMatch(param: 'azitromicina', display: 'Azitromicina',
      keywords: ['azitromicina', 'azithromycin', 'zitromax']),
  _TermMatch(param: 'metronidazol', display: 'Metronidazol',
      keywords: ['metronidazol', 'metronidazole', 'flagyl']),
  _TermMatch(param: 'doxiciclina', display: 'Doxiciclina',
      keywords: ['doxiciclina', 'doxycycline']),
  _TermMatch(param: 'cefazolina', display: 'Cefazolina',
      keywords: ['cefazolina', 'cefazolin']),
  _TermMatch(param: 'fluconazol', display: 'Fluconazol',
      keywords: ['fluconazol', 'fluconazole', 'diflucan']),
  _TermMatch(param: 'anfotericina', display: 'Anfotericina',
      keywords: ['anfotericina', 'amphotericin']),
  _TermMatch(param: 'linezolida', display: 'Linezolida',
      keywords: ['linezolida', 'linezolid', 'zyvox']),
  _TermMatch(param: 'colistina', display: 'Colistina',
      keywords: ['colistina', 'colistin', 'polimixina']),
  _TermMatch(param: 'levofloxacino', display: 'Levofloxacino',
      keywords: ['levofloxacino', 'levofloxacin', 'tavanic']),
  _TermMatch(param: 'ertapenem', display: 'Ertapenem',
      keywords: ['ertapenem', 'invanz']),
  _TermMatch(param: 'imipenem', display: 'Imipenem',
      keywords: ['imipenem', 'cilastatin']),
  _TermMatch(param: 'rifampicina', display: 'Rifampicina',
      keywords: ['rifampicina', 'rifampin', 'rifampicin']),
  _TermMatch(param: 'ceftazidima', display: 'Ceftazidima',
      keywords: ['ceftazidima', 'ceftazidime', 'fortaz']),

  // Cardiovasculares / Vasoativos (sem ser infusão dedicada)
  _TermMatch(param: 'amiodarona', display: 'Amiodarona',
      keywords: ['amiodarona', 'amiodarone', 'cordarone']),
  _TermMatch(param: 'adenosina', display: 'Adenosina',
      keywords: ['adenosina', 'adenosine']),
  _TermMatch(param: 'atropina', display: 'Atropina',
      keywords: ['atropina', 'atropine']),
  _TermMatch(param: 'lidocaina', display: 'Lidocaína',
      keywords: ['lidocaína', 'lidocaina', 'lidocaine', 'xilocaína']),
  _TermMatch(param: 'metoprolol', display: 'Metoprolol',
      keywords: ['metoprolol', 'seloken']),
  _TermMatch(param: 'carvedilol', display: 'Carvedilol',
      keywords: ['carvedilol']),
  _TermMatch(param: 'atenolol', display: 'Atenolol',
      keywords: ['atenolol']),
  _TermMatch(param: 'enalapril', display: 'Enalapril',
      keywords: ['enalapril', 'vasotec']),
  _TermMatch(param: 'ramipril', display: 'Ramipril',
      keywords: ['ramipril', 'triatec']),
  _TermMatch(param: 'losartana', display: 'Losartana',
      keywords: ['losartana', 'losartan', 'cozaar']),
  _TermMatch(param: 'anlodipino', display: 'Anlodipino',
      keywords: ['anlodipino', 'amlodipine', 'amlodipino', 'norvasc']),
  _TermMatch(param: 'digoxina', display: 'Digoxina',
      keywords: ['digoxina', 'digoxin', 'lanoxin']),
  _TermMatch(param: 'furosemida', display: 'Furosemida',
      keywords: ['furosemida', 'furosemide', 'lasix']),
  _TermMatch(param: 'espironolactona', display: 'Espironolactona',
      keywords: ['espironolactona', 'spironolactone', 'aldactone']),
  _TermMatch(param: 'nitroprussiato', display: 'Nitroprussiato',
      keywords: ['nitroprussiato', 'nitroprusside', 'nipride']),
  _TermMatch(param: 'nitroglicerina', display: 'Nitroglicerina',
      keywords: ['nitroglicerina', 'nitroglycerin', 'tridil']),
  _TermMatch(param: 'captopril', display: 'Captopril',
      keywords: ['captopril', 'capoten']),

  // Anticoagulantes / Antiagregantes
  _TermMatch(param: 'heparina', display: 'Heparina',
      keywords: ['heparina', 'heparin', 'hbpm', 'enoxaparina', 'enoxaparin']),
  _TermMatch(param: 'rivaroxabana', display: 'Rivaroxabana',
      keywords: ['rivaroxabana', 'rivaroxaban', 'xarelto']),
  _TermMatch(param: 'apixabana', display: 'Apixabana',
      keywords: ['apixabana', 'apixaban', 'eliquis']),
  _TermMatch(param: 'dabigatrana', display: 'Dabigatrana',
      keywords: ['dabigatrana', 'dabigatran', 'pradaxa']),
  _TermMatch(param: 'warfarina', display: 'Warfarina',
      keywords: ['warfarina', 'warfarin', 'coumadin']),
  _TermMatch(param: 'ticagrelor', display: 'Ticagrelor',
      keywords: ['ticagrelor', 'brilinta']),
  _TermMatch(param: 'clopidogrel', display: 'Clopidogrel',
      keywords: ['clopidogrel', 'plavix']),
  _TermMatch(param: 'aas', display: 'AAS',
      keywords: ['ácido acetilsalicílico', 'aspirina', ' aas ', 'aspirin']),

  // Neurologia / Psiquiatria
  _TermMatch(param: 'fenitoina', display: 'Fenitoína',
      keywords: ['fenitoína', 'fenitoina', 'phenytoin', 'dilantin']),
  _TermMatch(param: 'valproato', display: 'Valproato',
      keywords: ['valproato', 'valproic', 'depakene', 'depakote']),
  _TermMatch(param: 'levetiracetam', display: 'Levetiracetam',
      keywords: ['levetiracetam', 'keppra']),
  _TermMatch(param: 'midazolam', display: 'Midazolam',
      keywords: ['midazolam', 'dormicum', 'versed']),
  _TermMatch(param: 'diazepam', display: 'Diazepam',
      keywords: ['diazepam', 'valium']),
  _TermMatch(param: 'lorazepam', display: 'Lorazepam',
      keywords: ['lorazepam', 'ativan']),
  _TermMatch(param: 'haloperidol', display: 'Haloperidol',
      keywords: ['haloperidol', 'haldol']),
  _TermMatch(param: 'quetiapina', display: 'Quetiapina',
      keywords: ['quetiapina', 'quetiapine', 'seroquel']),

  // Analgesia / Sedação
  _TermMatch(param: 'morfina', display: 'Morfina',
      keywords: ['morfina', 'morphine']),
  _TermMatch(param: 'fentanil', display: 'Fentanil',
      keywords: ['fentanil', 'fentanyl', 'duragesic']),
  _TermMatch(param: 'ketamina', display: 'Ketamina',
      keywords: ['ketamina', 'ketamine', 'cetamina']),
  _TermMatch(param: 'propofol', display: 'Propofol',
      keywords: ['propofol', 'diprivan']),
  _TermMatch(param: 'dexmedetomidina', display: 'Dexmedetomidina',
      keywords: ['dexmedetomidina', 'dexmedetomidine', 'precedex']),
  _TermMatch(param: 'tramadol', display: 'Tramadol',
      keywords: ['tramadol', 'tramal', 'ultram']),

  // Endócrino / Metabólico
  _TermMatch(param: 'insulina', display: 'Insulina',
      keywords: ['insulina', 'insulin']),
  _TermMatch(param: 'metformina', display: 'Metformina',
      keywords: ['metformina', 'metformin', 'glifage']),
  _TermMatch(param: 'hidrocortisona', display: 'Hidrocortisona',
      keywords: ['hidrocortisona', 'hydrocortisone', 'solu-cortef']),
  _TermMatch(param: 'dexametasona', display: 'Dexametasona',
      keywords: ['dexametasona', 'dexamethasone', 'decadron']),
  _TermMatch(param: 'metilprednisolona', display: 'Metilprednisolona',
      keywords: ['metilprednisolona', 'methylprednisolone', 'solu-medrol']),
  _TermMatch(param: 'levotiroxina', display: 'Levotiroxina',
      keywords: ['levotiroxina', 'levothyroxine', 'synthroid']),

  // Respiratório / Broncodilatadores
  _TermMatch(param: 'salbutamol', display: 'Salbutamol',
      keywords: ['salbutamol', 'albuterol', 'ventolin', 'fenoterol']),
  _TermMatch(param: 'ipratropio', display: 'Ipratrópio',
      keywords: ['ipratropio', 'ipratropium', 'atrovent']),
  _TermMatch(param: 'aminofilina', display: 'Aminofilina',
      keywords: ['aminofilina', 'aminophylline']),
  _TermMatch(param: 'adrenalina', display: 'Adrenalina',
      keywords: ['adrenalina', 'epinefrina', 'epinephrine', 'adrenaline']),

  // Outros frequentes
  _TermMatch(param: 'ranitidina', display: 'Ranitidina',
      keywords: ['ranitidina', 'ranitidine', 'zantac']),
  _TermMatch(param: 'omeprazol', display: 'Omeprazol',
      keywords: ['omeprazol', 'omeprazole', 'prilosec']),
  _TermMatch(param: 'pantoprazol', display: 'Pantoprazol',
      keywords: ['pantoprazol', 'pantoprazole', 'protonix']),
  _TermMatch(param: 'ondansetrona', display: 'Ondansetrona',
      keywords: ['ondansetrona', 'ondansetron', 'zofran']),
  _TermMatch(param: 'metoclopramida', display: 'Metoclopramida',
      keywords: ['metoclopramida', 'metoclopramide', 'plasil']),
  _TermMatch(param: 'dipirona', display: 'Dipirona',
      keywords: ['dipirona', 'metamizol', 'novalgina']),
  _TermMatch(param: 'paracetamol', display: 'Paracetamol',
      keywords: ['paracetamol', 'acetaminophen', 'tylenol']),
  _TermMatch(param: 'ibuprofeno', display: 'Ibuprofeno',
      keywords: ['ibuprofeno', 'ibuprofen', 'advil']),
  _TermMatch(param: 'diclofenaco', display: 'Diclofenaco',
      keywords: ['diclofenaco', 'diclofenac', 'cataflam']),
  _TermMatch(param: 'n-acetilcisteina', display: 'N-Acetilcisteína',
      keywords: ['n-acetilcisteína', 'acetilcisteína', 'acetylcysteine', 'nac antídoto']),
];

// ─────────────────────────────────────────────────────────────────────────────
// SCORES clínicos
// ─────────────────────────────────────────────────────────────────────────────
const List<_TermMatch> _kScores = [
  _TermMatch(param: 'sofa', display: 'SOFA',
      keywords: ['sofa score', 'escore sofa', 'sequential organ', 'sofa:']),
  _TermMatch(param: 'qsofa', display: 'qSOFA',
      keywords: ['qsofa', 'quick sofa']),
  _TermMatch(param: 'apache', display: 'APACHE II',
      keywords: ['apache ii', 'apache 2', 'apache score']),
  _TermMatch(param: 'saps', display: 'SAPS',
      keywords: ['saps ii', 'saps iii', 'saps score']),
  _TermMatch(param: 'wells-tep', display: 'Wells TEP',
      keywords: ['wells tep', 'wells tromboembolism', 'wells pulmonar', 'escore de wells', 'score de wells']),
  _TermMatch(param: 'wells-tvp', display: 'Wells TVP',
      keywords: ['wells tvp', 'wells tvd', 'wells trombose venosa']),
  _TermMatch(param: 'grace', display: 'GRACE',
      keywords: ['grace score', 'escore grace', 'grace acs']),
  _TermMatch(param: 'timi', display: 'TIMI',
      keywords: ['timi score', 'escore timi', 'timi risk']),
  _TermMatch(param: 'heart', display: 'HEART Score',
      keywords: ['heart score', 'escore heart']),
  _TermMatch(param: 'glasgow', display: 'Glasgow',
      keywords: ['glasgow', 'gcs ', 'gcs score', 'escala de glasgow', 'escala glasgow']),
  _TermMatch(param: 'nihss', display: 'NIHSS',
      keywords: ['nihss', 'nih stroke scale', 'escore nihss']),
  _TermMatch(param: 'rankin', display: 'Rankin',
      keywords: ['rankin', 'modified rankin', 'escala rankin']),
  _TermMatch(param: 'hunt-hess', display: 'Hunt-Hess',
      keywords: ['hunt-hess', 'hunt e hess', 'hunt hess']),
  _TermMatch(param: 'curb-65', display: 'CURB-65',
      keywords: ['curb-65', 'curb65', 'escore curb']),
  _TermMatch(param: 'psi-port', display: 'PSI/PORT',
      keywords: ['psi score', 'port score', 'pneumonia severity']),
  _TermMatch(param: 'ranson', display: 'Ranson',
      keywords: ['ranson', 'criterios de ranson', 'critérios de ranson']),
  _TermMatch(param: 'bisap', display: 'BISAP',
      keywords: ['bisap']),
  _TermMatch(param: 'meld', display: 'MELD',
      keywords: ['meld', 'meld score', 'meld-na']),
  _TermMatch(param: 'child-pugh', display: 'Child-Pugh',
      keywords: ['child-pugh', 'child pugh', 'child turcotte']),
  _TermMatch(param: 'chads2-vasc', display: 'CHA₂DS₂-VASc',
      keywords: ['chads2', 'cha2ds2', 'chadsvasc', 'escore de chads']),
  _TermMatch(param: 'has-bled', display: 'HAS-BLED',
      keywords: ['has-bled', 'hasbled', 'escore has-bled']),
  _TermMatch(param: 'trauma-score', display: 'Trauma Score',
      keywords: ['revised trauma score', 'iss score', 'injury severity']),
  _TermMatch(param: 'abcd2', display: 'ABCD²',
      keywords: ['abcd2', 'escore abcd']),
  _TermMatch(param: 'pecarn', display: 'PECARN',
      keywords: ['pecarn']),
  _TermMatch(param: 'sepsis-3', display: 'Sepsis-3',
      keywords: ['sepsis-3', 'sepse-3', 'critérios sepsis 3']),
];

// ─────────────────────────────────────────────────────────────────────────────
// CALCULADORAS clínicas
// ─────────────────────────────────────────────────────────────────────────────
const List<_TermMatch> _kCalculadoras = [
  _TermMatch(param: 'clcr', display: 'ClCr (Cockcroft-Gault)',
      keywords: ['clcr', 'clearance de creatinina', 'cockcroft', 'creatinine clearance',
                 'depuração de creatinina', 'depuracion creatinina']),
  _TermMatch(param: 'tfg', display: 'TFG (CKD-EPI)',
      keywords: ['tfg', 'taxa de filtração glomerular', 'ckd-epi', 'egfr', 'filtrado glomerular']),
  _TermMatch(param: 'imc', display: 'IMC',
      keywords: ['imc', 'índice de massa corporal', 'índice de masa corporal', 'bmi']),
  _TermMatch(param: 'peso-ideal', display: 'Peso Ideal',
      keywords: ['peso ideal', 'peso magro', 'peso corrigido', 'ideal body weight']),
  _TermMatch(param: 'dose-renal', display: 'Ajuste Renal',
      keywords: ['ajuste renal', 'ajuste de dose renal', 'insuficiência renal dose',
                 'dose em insuficiência renal']),
  _TermMatch(param: 'osmolaridade', display: 'Osmolaridade',
      keywords: ['osmolaridade', 'osmolalidade', 'osmolarity', 'gap osmolar']),
  _TermMatch(param: 'anion-gap', display: 'Ânion Gap',
      keywords: ['ânion gap', 'anion gap', 'gap aniônico', 'delta ratio']),
  _TermMatch(param: 'be', display: 'Base Excess',
      keywords: ['base excess', 'excesso de base', 'déficit de base']),
  _TermMatch(param: 'bicarbonato', display: 'Bicarbonato',
      keywords: ['repor bicarbonato', 'reposição de bicarbonato', 'bicarbonate deficit']),
  _TermMatch(param: 'sodio-corrigido', display: 'Na⁺ Corrigido',
      keywords: ['sódio corrigido', 'sodio corregido', 'na+ corrigido', 'natremia corrigida']),
  _TermMatch(param: 'calcio-corrigido', display: 'Ca²⁺ Corrigido',
      keywords: ['cálcio corrigido', 'calcio corregido', 'ca2+ corrigido']),
  _TermMatch(param: 'regra-de-22', display: 'Regra de 22',
      keywords: ['regra de 22', 'regra dos 22', 'compensação respiratória']),
  _TermMatch(param: 'water-deficit', display: 'Déficit Hídrico',
      keywords: ['déficit hídrico', 'water deficit', 'deficit de agua libre']),
];

// ─────────────────────────────────────────────────────────────────────────────
// ELETRÓLITOS
// ─────────────────────────────────────────────────────────────────────────────
const List<_TermMatch> _kEletrolitos = [
  _TermMatch(param: 'potassio', display: 'Potássio',
      keywords: ['hipocalemia', 'hipercalemia', 'hypokale', 'hyperkale',
                 'potássio', 'potasio', 'kalemia', 'k+', 'reposição de potássio']),
  _TermMatch(param: 'sodio', display: 'Sódio',
      keywords: ['hiponatremia', 'hipernatremia', 'hyponatremia', 'hypernatremia',
                 'sódio', 'sodio', 'natremia', 'disnatremia', 'correção de sódio']),
  _TermMatch(param: 'calcio', display: 'Cálcio',
      keywords: ['hipocalcemia', 'hipercalcemia', 'hypocalcemia', 'hypercalcemia',
                 'cálcio', 'calcio', 'calciemia']),
  _TermMatch(param: 'magnesio', display: 'Magnésio',
      keywords: ['hipomagnesemia', 'hipermagnesemia', 'hypomagnesemia',
                 'magnésio', 'magnesio', 'magnesemia', 'mg2+']),
  _TermMatch(param: 'fosforo', display: 'Fósforo',
      keywords: ['hipofosfatemia', 'hiperfosfatemia', 'hypophosphatemia',
                 'fósforo', 'fosforo', 'fosfatemia']),
  _TermMatch(param: 'cloro', display: 'Cloro',
      keywords: ['hipocloremia', 'hipercloremia', 'cloro', 'cloremia', 'cloreto']),
];

// ─────────────────────────────────────────────────────────────────────────────
// INFUSÃO contínua / Drogas vasoativas e sedação
// ─────────────────────────────────────────────────────────────────────────────
const List<_TermMatch> _kInfusao = [
  _TermMatch(param: 'norepinefrina', display: 'Norepinefrina',
      keywords: ['norepinefrina', 'noradrenalin', 'norepinephrine', 'noradrenalina', 'levophed']),
  _TermMatch(param: 'dopamina', display: 'Dopamina',
      keywords: ['dopamina', 'dopamine']),
  _TermMatch(param: 'dobutamina', display: 'Dobutamina',
      keywords: ['dobutamina', 'dobutamine', 'dobutrex']),
  _TermMatch(param: 'vasopressina', display: 'Vasopressina',
      keywords: ['vasopressina', 'vasopressin', 'pitressin']),
  _TermMatch(param: 'epinefrina-infusao', display: 'Epinefrina (infusão)',
      keywords: ['epinefrina infusão', 'adrenalina infusão', 'epinephrine infusion']),
  _TermMatch(param: 'midazolam-infusao', display: 'Midazolam (infusão)',
      keywords: ['midazolam infusão', 'midazolam contínuo', 'midazolam drip']),
  _TermMatch(param: 'propofol-infusao', display: 'Propofol (infusão)',
      keywords: ['propofol infusão', 'propofol contínuo', 'propofol drip']),
  _TermMatch(param: 'fentanil-infusao', display: 'Fentanil (infusão)',
      keywords: ['fentanil infusão', 'fentanil contínuo', 'fentanyl drip']),
  _TermMatch(param: 'amiodarona-infusao', display: 'Amiodarona (infusão)',
      keywords: ['amiodarona infusão', 'amiodarone infusion', 'amiodarona ev contínuo']),
  _TermMatch(param: 'heparina-infusao', display: 'Heparina (infusão)',
      keywords: ['heparina infusão', 'heparina contínua', 'heparin infusion', 'heparina ev']),
  _TermMatch(param: 'insulina-infusao', display: 'Insulina (infusão)',
      keywords: ['insulina infusão', 'insulina contínua', 'insulin drip', 'protocolo insulina']),
  _TermMatch(param: 'nitroprussiato-infusao', display: 'Nitroprussiato (infusão)',
      keywords: ['nitroprussiato infusão', 'nitroprussiato ev', 'nitroprusside infusion']),
  _TermMatch(param: 'nitroglicerina-infusao', display: 'Nitroglicerina (infusão)',
      keywords: ['nitroglicerina infusão', 'nitroglicerina ev', 'nitroglycerin drip']),
  _TermMatch(param: 'ketamina-infusao', display: 'Ketamina (infusão)',
      keywords: ['ketamina infusão', 'ketamina contínua', 'ketamine drip']),
  _TermMatch(param: 'dexmedetomidina-infusao', display: 'Dexmedetomidina (infusão)',
      keywords: ['dexmedetomidina infusão', 'precedex infusão', 'dexmedetomidine infusion']),
];

// ─────────────────────────────────────────────────────────────────────────────
// HEMODINÂMICA
// ─────────────────────────────────────────────────────────────────────────────
const List<_TermMatch> _kHemodinamica = [
  _TermMatch(param: 'pam', display: 'PAM',
      keywords: ['pressão arterial média', 'pam ', 'mean arterial pressure', 'map ']),
  _TermMatch(param: 'fc', display: 'Frequência Cardíaca',
      keywords: ['frequência cardíaca', 'frecuencia cardiaca', 'heart rate', 'fc ']),
  _TermMatch(param: 'dc', display: 'Débito Cardíaco',
      keywords: ['débito cardíaco', 'gasto cardíaco', 'cardiac output', 'dc ']),
  _TermMatch(param: 'svr', display: 'RVS',
      keywords: ['resistência vascular sistêmica', 'rvs', 'svr', 'systemic vascular resistance']),
  _TermMatch(param: 'pvr', display: 'RVP',
      keywords: ['resistência vascular pulmonar', 'rvp', 'pvr', 'pulmonary vascular resistance']),
  _TermMatch(param: 'vpp', display: 'VPP',
      keywords: ['variação de pressão de pulso', 'vpp ', 'pulse pressure variation', 'ppv']),
  _TermMatch(param: 'pvci', display: 'VCI / PVC',
      keywords: ['veia cava inferior', 'pressão venosa central', 'pvc ', 'cvp ', 'vci ', 'ivc ']),
  _TermMatch(param: 'shock-index', display: 'Índice de Choque',
      keywords: ['índice de choque', 'shock index', 'indice de choque']),
  _TermMatch(param: 'svo2', display: 'SvO₂',
      keywords: ['svo2', 'saturação venosa', 'satvenosa', 'mixed venous']),
  _TermMatch(param: 'lactato', display: 'Lactato',
      keywords: ['lactato', 'lactat', 'lactatemia', 'lactic acid']),
];
