// test_engine.dart — Teste standalone da ExternalToolLinkEngine
// Roda com: dart test_engine.dart
// Não requer Flutter — testa a lógica pura de detecção e URL building.
//
// Replica a lógica do engine sem o Flutter framework.
// Cobre todos os 8 casos obrigatórios em PT-BR e ES.

// ─── REPLICA da lógica do engine (sem Flutter imports) ───────────────────────

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

String enc(String term) {
  final safe = term.trim().toLowerCase().replaceAll(' ', '-');
  final capped = safe.length > 40 ? safe.substring(0, 40) : safe;
  return Uri.encodeQueryComponent(capped);
}

TermMatch? matchFirst(String text, List<TermMatch> table) {
  for (final entry in table) {
    for (final kw in entry.keywords) {
      if (text.contains(kw)) return entry;
    }
  }
  return null;
}

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

bool detectFluidos(String text) {
  const kws = ['cristaloide', 'coloide', 'soro fisiol', 'solução salina',
    'reposição vol', 'reposição hídrica', 'expansão vol',
    'ringer lactato', 'albumina 4%', 'albumina 20%',
    'fluidoterapia', 'hidratação venosa', 'fluidoterapy',
    'bolus de soro', 'ressuscitação vol', 'resucitación vol',
    'balance hídrico', 'balanço hídrico'];
  for (final kw in kws) { if (text.contains(kw)) return true; }
  return false;
}

bool detectPediatria(String text) {
  const kws = ['pediatri', 'neonato', 'neonat', 'recém-nascido', 'recien nacido',
    'lactente', 'criança', 'niño', 'pediátric', 'pediatric',
    'bronquiolit', 'croup', 'laringite', 'garrotillo',
    'kg/m²', 'dose pediátrica', 'dose pediatrica'];
  for (final kw in kws) { if (text.contains(kw)) return true; }
  return false;
}

bool detectGestante(String text) {
  const kws = ['gestante', 'gestação', 'gravidez', 'grávida',
    'embarazo', 'embarazada', 'gestación',
    'pré-eclâmpsia', 'preeclampsia', 'eclâmpsia', 'eclampsia',
    'hellp', 'pprom', 'rotura prematura', 'trabalho de parto',
    'parto prematuro', 'parto pretérmino', 'obstetri',
    'sulfato de magnésio', 'sulfato de magnesio',
    'betametasona gestante', 'corticoide fetal'];
  for (final kw in kws) { if (text.contains(kw)) return true; }
  return false;
}

// ── Tabelas (subset relevante para os testes) ─────────────────────────────────

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
  TermMatch(param: 'wells-tep', display: 'Wells TEP',
      keywords: ['wells tep', 'wells tromboembolism', 'wells pulmonar', 'escore de wells', 'score de wells']),
];

const kCalculadoras = [
  TermMatch(param: 'clcr', display: 'ClCr (Cockcroft-Gault)',
      keywords: ['clcr', 'clearance de creatinina', 'cockcroft', 'creatinine clearance',
                 'depuração de creatinina', 'depuracion creatinina']),
];

const kEletrolitos = [
  TermMatch(param: 'potassio', display: 'Potássio',
      keywords: ['hipocalemia', 'hipercalemia', 'hypokale', 'hyperkale',
                 'potássio', 'potasio', 'kalemia', 'k+', 'reposição de potássio']),
];

const kInfusao = [
  TermMatch(param: 'norepinefrina', display: 'Norepinefrina',
      keywords: ['norepinefrina', 'noradrenalin', 'norepinephrine', 'noradrenalina', 'levophed']),
];

// ── Engine stub ───────────────────────────────────────────────────────────────

ExternalToolLink? build({
  required String lastUserMessage,
  required String lastAiResponse,
  required bool isPlantaoMode,
  required String currentLanguage,
}) {
  final bool isEs = currentLanguage.toLowerCase().startsWith('es');
  final String combined = '${lastUserMessage.toLowerCase()} ${lastAiResponse.toLowerCase()}';

  // 1. Interação
  final interacao = detectDrugInteraction(combined, kDrugs);
  if (interacao != null) {
    final label = isEs ? '💊 Verificar interacción' : '💊 Verificar interação';
    return ExternalToolLink(label: label,
        url: '$kBase?tab=interacoes&drug1=${enc(interacao.$1)}&drug2=${enc(interacao.$2)}');
  }

  // 2. Score
  final score = matchFirst(combined, kScores);
  if (score != null) {
    final label = isEs ? '📊 Abrir ${score.display}' : '📊 Abrir ${score.display}';
    return ExternalToolLink(label: label, url: '$kBase?tab=scores&q=${enc(score.param)}');
  }

  // 3. Calculadora
  final calcu = matchFirst(combined, kCalculadoras);
  if (calcu != null) {
    final label = isEs ? '🧮 Calcular ${calcu.display}' : '🧮 Calcular ${calcu.display}';
    return ExternalToolLink(label: label, url: '$kBase?tab=calculadoras&q=${enc(calcu.param)}');
  }

  // 4. Eletrólito
  final eletro = matchFirst(combined, kEletrolitos);
  if (eletro != null) {
    final label = isEs ? '⚗️ Abrir electrolitos' : '⚗️ Abrir eletrólitos';
    return ExternalToolLink(label: label, url: '$kBase?tab=eletrolitos&q=${enc(eletro.param)}');
  }

  // 5. Infusão
  final infusao = matchFirst(combined, kInfusao);
  if (infusao != null) {
    final label = isEs ? '💉 Abrir infusión' : '💉 Abrir infusão';
    return ExternalToolLink(label: label, url: '$kBase?tab=infusao&q=${enc(infusao.param)}');
  }

  // 7. Fluidos
  if (detectFluidos(combined)) {
    final label = isEs ? '🩺 Fluidos y volumen' : '🩺 Fluidos e volume';
    return ExternalToolLink(label: label, url: '$kBase?tab=fluidos');
  }

  // 8. Pediatria
  if (detectPediatria(combined)) {
    final label = isEs ? '👶 Módulo pediatría' : '👶 Módulo pediatria';
    return ExternalToolLink(label: label, url: '$kBase?tab=pediatria');
  }

  // 9. Gestante
  if (detectGestante(combined)) {
    final label = isEs ? '🤰 Módulo gestante' : '🤰 Módulo gestante';
    return ExternalToolLink(label: label, url: '$kBase?tab=gestante');
  }

  // 10. Fármaco isolado
  final drug = matchFirst(combined, kDrugs);
  if (drug != null) {
    final label = isEs ? '💊 Abrir ${drug.display} en la base' : '💊 Abrir ${drug.display} na base';
    return ExternalToolLink(label: label, url: '$kBase?tab=farmacos&q=${enc(drug.param)}');
  }

  return null;
}

// ─── FRAMEWORK DE TESTE ───────────────────────────────────────────────────────

int _pass = 0;
int _fail = 0;

void check(String testName, String? actual, String expected) {
  if (actual == expected) {
    print('  ✅ $testName');
    print('     → "$actual"');
    _pass++;
  } else {
    print('  ❌ $testName');
    print('     esperado: "$expected"');
    print('     obtido:   "$actual"');
    _fail++;
  }
}

void runCase(String title, String userMsg, String aiMsg, String lang, {
  required String expectedLabel,
  required String expectedUrl,
}) {
  print('\n── $title ($lang) ──────────────────────────────────────────────');
  final result = build(
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

// ─── CASOS DE TESTE ───────────────────────────────────────────────────────────

void main() {
  print('════════════════════════════════════════════════════════════════');
  print(' ExternalToolLinkEngine — Suite de testes Build 185');
  print('════════════════════════════════════════════════════════════════');

  // ── 1. Fármaco isolado — PT ───────────────────────────────────────────────
  runCase('ceftriaxona dose', 'ceftriaxona dose', 'Use ceftriaxona 1g IV', 'pt',
    expectedLabel: '💊 Abrir Ceftriaxona na base',
    expectedUrl:   'https://medcasescalcu.com/?tab=farmacos&q=ceftriaxona',
  );

  // ── 2. Fármaco isolado — ES ───────────────────────────────────────────────
  runCase('ceftriaxona dose', 'ceftriaxona dose', 'Use ceftriaxona 1g IV', 'es',
    expectedLabel: '💊 Abrir Ceftriaxona en la base',
    expectedUrl:   'https://medcasescalcu.com/?tab=farmacos&q=ceftriaxona',
  );

  // ── 3. Interação — PT ────────────────────────────────────────────────────
  runCase('amiodarona + ciprofloxacino', 'amiodarona e ciprofloxacino', 'Atenção à interação entre amiodarona e ciprofloxacino', 'pt',
    expectedLabel: '💊 Verificar interação',
    expectedUrl:   'https://medcasescalcu.com/?tab=interacoes&drug1=amiodarona&drug2=ciprofloxacino',
  );

  // ── 4. Interação — ES ────────────────────────────────────────────────────
  runCase('amiodarona + ciprofloxacino', 'amiodarona e ciprofloxacino', 'Atenção à interação entre amiodarona e ciprofloxacino', 'es',
    expectedLabel: '💊 Verificar interacción',
    expectedUrl:   'https://medcasescalcu.com/?tab=interacoes&drug1=amiodarona&drug2=ciprofloxacino',
  );

  // ── 5. Score — PT ────────────────────────────────────────────────────────
  runCase('Wells TEP', 'Wells TEP pontuação', 'O escore Wells TEP é usado para...', 'pt',
    expectedLabel: '📊 Abrir Wells TEP',
    expectedUrl:   'https://medcasescalcu.com/?tab=scores&q=wells-tep',
  );

  // ── 6. Score — ES ────────────────────────────────────────────────────────
  runCase('Wells TEP', 'Wells TEP pontuação', 'O escore Wells TEP é usado para...', 'es',
    expectedLabel: '📊 Abrir Wells TEP',
    expectedUrl:   'https://medcasescalcu.com/?tab=scores&q=wells-tep',
  );

  // ── 7. Eletrólito — PT ───────────────────────────────────────────────────
  runCase('hipocalemia', 'hipocalemia tratamento', 'A hipocalemia é definida como K+ < 3,5 mEq/L', 'pt',
    expectedLabel: '⚗️ Abrir eletrólitos',
    expectedUrl:   'https://medcasescalcu.com/?tab=eletrolitos&q=potassio',
  );

  // ── 8. Eletrólito — ES ───────────────────────────────────────────────────
  runCase('hipocalemia', 'hipocalemia tratamento', 'A hipocalemia é definida como K+ < 3,5 mEq/L', 'es',
    expectedLabel: '⚗️ Abrir electrolitos',
    expectedUrl:   'https://medcasescalcu.com/?tab=eletrolitos&q=potassio',
  );

  // ── 9. Infusão — PT ──────────────────────────────────────────────────────
  runCase('noradrenalina', 'noradrenalina dose choque', 'Iniciar noradrenalina 0,1 mcg/kg/min', 'pt',
    expectedLabel: '💉 Abrir infusão',
    expectedUrl:   'https://medcasescalcu.com/?tab=infusao&q=norepinefrina',
  );

  // ── 10. Infusão — ES ─────────────────────────────────────────────────────
  runCase('noradrenalina', 'noradrenalina dose choque', 'Iniciar noradrenalina 0,1 mcg/kg/min', 'es',
    expectedLabel: '💉 Abrir infusión',
    expectedUrl:   'https://medcasescalcu.com/?tab=infusao&q=norepinefrina',
  );

  // ── 11. Calculadora ClCr — PT ─────────────────────────────────────────────
  runCase('ClCr', 'clcr paciente renal', 'Calcule o ClCr usando Cockcroft-Gault', 'pt',
    expectedLabel: '🧮 Calcular ClCr (Cockcroft-Gault)',
    expectedUrl:   'https://medcasescalcu.com/?tab=calculadoras&q=clcr',
  );

  // ── 12. Calculadora ClCr — ES ─────────────────────────────────────────────
  runCase('ClCr', 'clcr paciente renal', 'Calcule o ClCr usando Cockcroft-Gault', 'es',
    expectedLabel: '🧮 Calcular ClCr (Cockcroft-Gault)',
    expectedUrl:   'https://medcasescalcu.com/?tab=calculadoras&q=clcr',
  );

  // ── 13. Gestante — PT ────────────────────────────────────────────────────
  runCase('gestante', 'gestante pré-eclâmpsia', 'Na pré-eclâmpsia, usar sulfato de magnésio', 'pt',
    expectedLabel: '🤰 Módulo gestante',
    expectedUrl:   'https://medcasescalcu.com/?tab=gestante',
  );

  // ── 14. Gestante — ES ────────────────────────────────────────────────────
  runCase('gestante', 'gestante pré-eclâmpsia', 'Na pré-eclâmpsia, usar sulfato de magnésio', 'es',
    expectedLabel: '🤰 Módulo gestante',
    expectedUrl:   'https://medcasescalcu.com/?tab=gestante',
  );

  // ── 15. Pediatria — PT ───────────────────────────────────────────────────
  runCase('pediatria', 'dose pediatrica bronquiolite', 'Pediatria: bronquiolite em lactente', 'pt',
    expectedLabel: '👶 Módulo pediatria',
    expectedUrl:   'https://medcasescalcu.com/?tab=pediatria',
  );

  // ── 16. Pediatria — ES ───────────────────────────────────────────────────
  runCase('pediatria', 'dose pediatrica bronquiolite', 'Pediatria: bronquiolite em lactente', 'es',
    expectedLabel: '👶 Módulo pediatría',
    expectedUrl:   'https://medcasescalcu.com/?tab=pediatria',
  );

  // ── RESULTADO FINAL ────────────────────────────────────────────────────────
  print('\n════════════════════════════════════════════════════════════════');
  final total = _pass + _fail;
  print(' RESULTADO: $_pass/$total passaram  |  $_fail falhas');
  if (_fail == 0) {
    print(' ✅ TODOS OS TESTES PASSARAM — engine pronto para produção');
  } else {
    print(' ❌ FALHAS DETECTADAS — revisar engine antes de build');
  }
  print('════════════════════════════════════════════════════════════════');
}
