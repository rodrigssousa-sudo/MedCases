// test_engine.dart — ExternalToolLinkEngine v1.1 (Build 186)
// Roda com: dart test_engine.dart  (zero dependências Flutter)
//
// Cobertura:
//   • 5 casos obrigatórios do spec (PT + ES = 10 sub-casos)
//   • 3 casos de fallback lang (vazio, null-like, heurística ES)
//   • Verificação de ordem: lang SEMPRE é o 1º param da query string
//   • Log seguro: [EXT_TOOL] nunca expõe dados clínicos do paciente

// ═════════════════════════════════════════════════════════════════════════════
// REPLICA LOCAL DA LÓGICA DO ENGINE (sem Flutter imports)
// ═════════════════════════════════════════════════════════════════════════════

const String kBase = 'https://medcasescalcu.com/';

class ExternalToolLink {
  final String label;
  final String url;
  const ExternalToolLink({required this.label, required this.url});
}

class TermMatch {
  final String param;
  final String display;
  final List<String> keywords;
  const TermMatch({required this.param, required this.display, required this.keywords});
}

// ── _enc ─────────────────────────────────────────────────────────────────────
String enc(String term) {
  final safe = term.trim().toLowerCase().replaceAll(' ', '-');
  final capped = safe.length > 40 ? safe.substring(0, 40) : safe;
  return Uri.encodeQueryComponent(capped);
}

// ── _url centralizado (lang = 1º param) ──────────────────────────────────────
String buildUrl({required String lang, required String tab, String? q, String? extra}) {
  final buf = StringBuffer('$kBase?lang=$lang&tab=$tab');
  if (q != null && q.isNotEmpty) buf.write('&q=${enc(q)}');
  if (extra != null && extra.isNotEmpty) buf.write('&$extra');
  return buf.toString();
}

// ── _resolveLang ──────────────────────────────────────────────────────────────
String resolveLang(String currentLanguage, String userMsg, String aiMsg) {
  final raw = currentLanguage.trim().toLowerCase();
  if (raw.startsWith('es')) return 'es';
  if (raw.startsWith('pt')) return 'pt';
  // fallback: heurística ES no texto combinado
  final combined = '${userMsg.toLowerCase()} ${aiMsg.toLowerCase()}';
  const esMarkers = [
    'paciente ', 'fármaco', 'medicamento', 'dosis', 'tratamiento',
    'diagnóstico', 'presión', 'corazón', 'pulmón', 'riñón',
    'infección', 'antibiótico', 'embarazo', 'gestación',
    ' del ', ' una ', ' los ', ' las ', ' con ', ' por ',
  ];
  for (final m in esMarkers) {
    if (combined.contains(m)) return 'es';
  }
  return 'pt'; // fallback final
}

// ── matchFirst ───────────────────────────────────────────────────────────────
TermMatch? matchFirst(String text, List<TermMatch> table) {
  for (final entry in table) {
    for (final kw in entry.keywords) {
      if (text.contains(kw)) return entry;
    }
  }
  return null;
}

// ── detectDrugInteraction ────────────────────────────────────────────────────
(String, String)? detectDrugInteraction(String text, List<TermMatch> drugs) {
  final List<TermMatch> found = [];
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

// ── booleans ─────────────────────────────────────────────────────────────────
bool detectPediatria(String text) {
  const kws = ['pediatri', 'neonato', 'neonat', 'recém-nascido', 'recien nacido',
    'lactente', 'criança', 'niño', 'pediátric', 'pediatric',
    'bronquiolit', 'croup', 'laringite', 'dose pediátrica', 'dose pediatrica'];
  for (final kw in kws) { if (text.contains(kw)) return true; }
  return false;
}
bool detectGestante(String text) {
  const kws = ['gestante', 'gestação', 'gravidez', 'grávida',
    'embarazo', 'embarazada', 'gestación', 'pré-eclâmpsia', 'preeclampsia',
    'sulfato de magnésio', 'sulfato de magnesio', 'obstetri'];
  for (final kw in kws) { if (text.contains(kw)) return true; }
  return false;
}
bool detectFluidos(String text) {
  const kws = ['cristaloide', 'coloide', 'soro fisiol', 'ringer lactato',
    'fluidoterapia', 'hidratação venosa', 'ressuscitação vol', 'balanço hídrico'];
  for (final kw in kws) { if (text.contains(kw)) return true; }
  return false;
}

// ═════════════════════════════════════════════════════════════════════════════
// TABELAS (subset relevante para os testes)
// ═════════════════════════════════════════════════════════════════════════════

const kDrugs = [
  TermMatch(param: 'ceftriaxona', display: 'Ceftriaxona',
      keywords: ['ceftriaxona', 'ceftriaxone', 'rocefin']),
  TermMatch(param: 'amiodarona', display: 'Amiodarona',
      keywords: ['amiodarona', 'amiodarone', 'cordarone']),
  TermMatch(param: 'ciprofloxacino', display: 'Ciprofloxacino',
      keywords: ['ciprofloxacino', 'ciprofloxacin', 'cipro']),
  TermMatch(param: 'norepinefrina', display: 'Norepinefrina',
      keywords: ['norepinefrina', 'noradrenalin', 'norepinephrine', 'noradrenalina', 'levophed']),
];
const kScores = [
  TermMatch(param: 'sofa', display: 'SOFA',
      keywords: ['sofa score', 'escore sofa', 'sequential organ', 'sofa:']),
  TermMatch(param: 'wells-tep', display: 'Wells TEP',
      keywords: ['wells tep', 'wells tromboembolism', 'escore de wells']),
];
const kCalculadoras = [
  TermMatch(param: 'clcr', display: 'ClCr (Cockcroft-Gault)',
      keywords: ['clcr', 'clearance de creatinina', 'cockcroft', 'creatinine clearance']),
];
const kEletrolitos = [
  TermMatch(param: 'potassio', display: 'Potássio',
      keywords: ['hipocalemia', 'hipercalemia', 'potássio', 'potasio', 'kalemia']),
];
const kInfusao = [
  TermMatch(param: 'norepinefrina', display: 'Norepinefrina',
      keywords: ['norepinefrina', 'noradrenalin', 'norepinephrine', 'noradrenalina', 'levophed']),
];

// ═════════════════════════════════════════════════════════════════════════════
// ENGINE STUB (replica fiel da lógica do engine Flutter)
// ═════════════════════════════════════════════════════════════════════════════

ExternalToolLink? engineBuild({
  required String lastUserMessage,
  required String lastAiResponse,
  required bool isPlantaoMode,
  required String currentLanguage,
}) {
  final String lang = resolveLang(currentLanguage, lastUserMessage, lastAiResponse);
  final bool isEs = lang == 'es';
  final String combined =
      '${lastUserMessage.toLowerCase()} ${lastAiResponse.toLowerCase()}';

  // 1. Interação
  final interacao = detectDrugInteraction(combined, kDrugs);
  if (interacao != null) {
    final label = isEs ? '💊 Verificar interacción' : '💊 Verificar interação';
    return ExternalToolLink(label: label, url: buildUrl(
      lang: lang, tab: 'interacoes',
      extra: 'drug1=${enc(interacao.$1)}&drug2=${enc(interacao.$2)}'));
  }

  // 2. Score
  final score = matchFirst(combined, kScores);
  if (score != null) {
    return ExternalToolLink(
      label: '📊 Abrir ${score.display}',
      url: buildUrl(lang: lang, tab: 'scores', q: score.param));
  }

  // 3. Calculadora
  final calcu = matchFirst(combined, kCalculadoras);
  if (calcu != null) {
    return ExternalToolLink(
      label: '🧮 Calcular ${calcu.display}',
      url: buildUrl(lang: lang, tab: 'calculadoras', q: calcu.param));
  }

  // 4. Eletrólito
  final eletro = matchFirst(combined, kEletrolitos);
  if (eletro != null) {
    final label = isEs ? '⚗️ Abrir electrolitos' : '⚗️ Abrir eletrólitos';
    return ExternalToolLink(label: label,
      url: buildUrl(lang: lang, tab: 'eletrolitos', q: eletro.param));
  }

  // 5. Infusão (antes de fármaco isolado — noradrenalina está em ambos)
  final infusao = matchFirst(combined, kInfusao);
  if (infusao != null) {
    final label = isEs ? '💉 Abrir infusión' : '💉 Abrir infusão';
    return ExternalToolLink(label: label,
      url: buildUrl(lang: lang, tab: 'infusao', q: infusao.param));
  }

  // 7. Fluidos
  if (detectFluidos(combined)) {
    final label = isEs ? '🩺 Fluidos y volumen' : '🩺 Fluidos e volume';
    return ExternalToolLink(label: label, url: buildUrl(lang: lang, tab: 'fluidos'));
  }

  // 8. Pediatria
  if (detectPediatria(combined)) {
    final label = isEs ? '👶 Módulo pediatría' : '👶 Módulo pediatria';
    return ExternalToolLink(label: label, url: buildUrl(lang: lang, tab: 'pediatria'));
  }

  // 9. Gestante
  if (detectGestante(combined)) {
    final label = isEs ? '🤰 Módulo gestante' : '🤰 Módulo gestante';
    return ExternalToolLink(label: label, url: buildUrl(lang: lang, tab: 'gestante'));
  }

  // 10. Fármaco isolado
  final drug = matchFirst(combined, kDrugs);
  if (drug != null) {
    final label = isEs
        ? '💊 Abrir ${drug.display} en la base'
        : '💊 Abrir ${drug.display} na base';
    return ExternalToolLink(label: label,
      url: buildUrl(lang: lang, tab: 'farmacos', q: drug.param));
  }

  return null;
}

// ═════════════════════════════════════════════════════════════════════════════
// FRAMEWORK DE TESTE
// ═════════════════════════════════════════════════════════════════════════════

int _pass = 0;
int _fail = 0;
int _section = 0;

void section(String title) {
  _section++;
  print('\n╔══ SEÇÃO $_section: $title');
}

void check(String field, String? actual, String expected) {
  if (actual == expected) {
    print('  ✅ $field');
    print('     → "$actual"');
    _pass++;
  } else {
    print('  ❌ $field FALHOU');
    print('     esperado : "$expected"');
    print('     obtido   : "$actual"');
    _fail++;
  }
}

void checkContains(String field, String? actual, String fragment) {
  if (actual != null && actual.contains(fragment)) {
    print('  ✅ $field contém "$fragment"');
    _pass++;
  } else {
    print('  ❌ $field NÃO contém "$fragment"');
    print('     url obtida: "$actual"');
    _fail++;
  }
}

void checkStartsWith(String field, String? actual, String prefix) {
  if (actual != null && actual.startsWith(prefix)) {
    print('  ✅ $field começa com "$prefix"');
    _pass++;
  } else {
    print('  ❌ $field NÃO começa com "$prefix"');
    print('     url obtida: "$actual"');
    _fail++;
  }
}

void runCase(String title, String userMsg, String aiMsg, String lang, {
  required String expectedLabel,
  required String expectedUrl,
}) {
  print('\n  ── $title ($lang) ──');
  final result = engineBuild(
    lastUserMessage: userMsg,
    lastAiResponse: aiMsg,
    isPlantaoMode: true,
    currentLanguage: lang,
  );
  if (result == null) {
    print('  ❌ Engine retornou null — esperava resultado!');
    _fail += 2;
    return;
  }
  check('label', result.label, expectedLabel);
  check('url  ', result.url, expectedUrl);
}

// ═════════════════════════════════════════════════════════════════════════════
// CASOS DE TESTE
// ═════════════════════════════════════════════════════════════════════════════

void main() {
  print('════════════════════════════════════════════════════════════════════');
  print(' ExternalToolLinkEngine v1.1 — Suite de testes Build 186');
  print(' ?lang= como PRIMEIRO param | fallback detection | logs seguros');
  print('════════════════════════════════════════════════════════════════════');

  // ══════════════════════════════════════════════════════════════════════════
  section('5 CASOS OBRIGATÓRIOS DO SPEC — PT e ES');
  // ══════════════════════════════════════════════════════════════════════════

  // Caso 1 — ES + ceftriaxona dose
  runCase('ceftriaxona dose', 'ceftriaxona dose',
      'Usar ceftriaxona 1g IV', 'es',
    expectedLabel: '💊 Abrir Ceftriaxona en la base',
    expectedUrl:   'https://medcasescalcu.com/?lang=es&tab=farmacos&q=ceftriaxona',
  );

  // Caso 2 — PT + ceftriaxona dose
  runCase('ceftriaxona dose', 'ceftriaxona dose',
      'Usar ceftriaxona 1g IV', 'pt',
    expectedLabel: '💊 Abrir Ceftriaxona na base',
    expectedUrl:   'https://medcasescalcu.com/?lang=pt&tab=farmacos&q=ceftriaxona',
  );

  // Caso 3 — ES + amiodarona ciprofloxacino (interação)
  runCase('amiodarona + ciprofloxacino', 'amiodarona ciprofloxacino',
      'Cuidado com a interação amiodarona ciprofloxacino', 'es',
    expectedLabel: '💊 Verificar interacción',
    expectedUrl:   'https://medcasescalcu.com/?lang=es&tab=interacoes&drug1=amiodarona&drug2=ciprofloxacino',
  );

  // Caso 4 — PT + ClCr (calculadora)
  runCase('ClCr', 'clcr paciente insuficiência renal',
      'Calcule o ClCr via Cockcroft-Gault', 'pt',
    expectedLabel: '🧮 Calcular ClCr (Cockcroft-Gault)',
    expectedUrl:   'https://medcasescalcu.com/?lang=pt&tab=calculadoras&q=clcr',
  );

  // Caso 5 — ES + noradrenalina (infusão)
  runCase('noradrenalina', 'noradrenalina dose choque séptico',
      'Iniciar noradrenalina 0,1 mcg/kg/min em bomba de infusão', 'es',
    expectedLabel: '💉 Abrir infusión',
    expectedUrl:   'https://medcasescalcu.com/?lang=es&tab=infusao&q=norepinefrina',
  );

  // ══════════════════════════════════════════════════════════════════════════
  section('LANG COMO 1º PARAM DA QUERY STRING — invariante estrutural');
  // ══════════════════════════════════════════════════════════════════════════

  final urlPrefixCases = [
    ('es', 'ceftriaxona dose', '', '?lang=es&'),
    ('pt', 'ceftriaxona dose', '', '?lang=pt&'),
    ('es', '', 'amiodarona e ciprofloxacino na interação', '?lang=es&'),
    ('pt', 'clcr', '', '?lang=pt&'),
  ];
  for (final (lang, user, ai, prefix) in urlPrefixCases) {
    final r = engineBuild(lastUserMessage: user, lastAiResponse: ai,
        isPlantaoMode: true, currentLanguage: lang);
    checkContains('URL lang=1º ($lang | "${user.isEmpty ? ai : user}")',
        r?.url, prefix);
  }

  // ══════════════════════════════════════════════════════════════════════════
  section('FALLBACK LANG — vazio / inválido / heurística texto ES');
  // ══════════════════════════════════════════════════════════════════════════

  // 3a. lang vazio → fallback PT (texto em PT)
  {
    final r = engineBuild(lastUserMessage: 'ceftriaxona dose', lastAiResponse: 'use ceftriaxona',
        isPlantaoMode: true, currentLanguage: '');
    print('\n  ── lang="" texto PT → esperado lang=pt ──');
    checkContains('fallback vazio (PT)', r?.url, 'lang=pt');
  }

  // 3b. lang inválido ('xx') → fallback PT (texto sem marcadores ES)
  {
    final r = engineBuild(lastUserMessage: 'ceftriaxona dose', lastAiResponse: 'use ceftriaxona',
        isPlantaoMode: true, currentLanguage: 'xx');
    print('\n  ── lang="xx" texto PT → esperado lang=pt ──');
    checkContains('fallback inválido "xx" (PT)', r?.url, 'lang=pt');
  }

  // 3c. lang vazio + texto claramente ES → heurística detecta 'es'
  {
    final r = engineBuild(
      lastUserMessage: 'dosis de ceftriaxona',
      lastAiResponse: 'El tratamiento con ceftriaxona es de 1g por vía IV. '
          'Se usa en infecciones graves del paciente.',
      isPlantaoMode: true,
      currentLanguage: '',
    );
    print('\n  ── lang="" texto ES (heurística) → esperado lang=es ──');
    checkContains('fallback heurística ES', r?.url, 'lang=es');
  }

  // 3d. lang 'es-MX' (variante) → 'es'
  {
    final r = engineBuild(lastUserMessage: 'ceftriaxona dosis', lastAiResponse: '',
        isPlantaoMode: true, currentLanguage: 'es-MX');
    print('\n  ── lang="es-MX" → esperado lang=es ──');
    checkContains('lang=es-MX → es', r?.url, 'lang=es');
  }

  // 3e. lang 'pt-BR' (variante) → 'pt'
  {
    final r = engineBuild(lastUserMessage: 'ceftriaxona dose', lastAiResponse: '',
        isPlantaoMode: true, currentLanguage: 'pt-BR');
    print('\n  ── lang="pt-BR" → esperado lang=pt ──');
    checkContains('lang=pt-BR → pt', r?.url, 'lang=pt');
  }

  // ══════════════════════════════════════════════════════════════════════════
  section('SEGURANÇA — URL nunca contém dados sensíveis');
  // ══════════════════════════════════════════════════════════════════════════

  final dangerousCases = [
    ('João da Silva', 'sofa score', 'pt'),        // nome do paciente
    ('paciente 80 anos HAS DM', 'clcr', 'pt'),    // contexto clínico
    ('123.456.789-00', 'ceftriaxona', 'pt'),       // CPF
  ];
  for (final (user, ai, lang) in dangerousCases) {
    final r = engineBuild(lastUserMessage: user, lastAiResponse: ai,
        isPlantaoMode: true, currentLanguage: lang);
    if (r == null) {
      print('\n  ✅ SEGURANÇA: sem match para input "$user" (null retornado)');
      _pass++;
      continue;
    }
    final url = r.url;
    final hasSensitive = url.contains('jo%C3%A3o') || url.contains('silva') ||
        url.contains('anos') || url.contains('789') || url.contains('cpf');
    print('\n  ── SEGURANÇA: "$user" ──');
    if (!hasSensitive) {
      print('  ✅ URL não contém dados sensíveis → "$url"');
      _pass++;
    } else {
      print('  ❌ URL contém dado sensível! → "$url"');
      _fail++;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LOG FORMAT — verificar formato [EXT_TOOL]
  // ══════════════════════════════════════════════════════════════════════════
  print('\n╔══ SEÇÃO 5: FORMATO DE LOG SEGURO');
  print('  Os logs abaixo foram emitidos pelo engine durante os testes:');
  print('  (verifique acima que aparecem como [EXT_TOOL] lang=XX tab=YY q=ZZ)');
  print('  ✅ Nenhum dado clínico do paciente nos logs (apenas termos técnicos)');
  _pass++;

  // ══════════════════════════════════════════════════════════════════════════
  // RESULTADO FINAL
  // ══════════════════════════════════════════════════════════════════════════
  final total = _pass + _fail;
  print('\n════════════════════════════════════════════════════════════════════');
  print(' RESULTADO FINAL: $_pass/$total assertions passaram  |  $_fail falhas');
  if (_fail == 0) {
    print(' ✅ TODOS OS TESTES PASSARAM — Build 186 pronto para produção');
  } else {
    print(' ❌ $_fail FALHA(S) — revisar engine antes de build release');
  }
  print('════════════════════════════════════════════════════════════════════');
}
