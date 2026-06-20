// ─────────────────────────────────────────────────────────────────────────────
// DrugInteractionService — Build 164 — Motor DDI (Drug-Drug Interaction)
//
// Pipeline completo:
//   1. Fetch HTTP do JS da base real (github raw)
//   2. Parsing via RegExp: extrai DRUG_ALIASES, DRUG_CLASSES e INTERACOES_DB
//   3. Cache local no SharedPreferences (TTL 24h) — suporte offline
//   4. Normalizador de texto: remove sais, dosagens, vias, acentos
//   5. Two-Step Lookup: normaliza → alias → canônico
//   6. Class expansion: droga → todas as $classes que a contêm
//   7. Cruzamento combinatório n×n bidirecional
//   8. Retorna List<DdiAlert> com gravidade, scoreClinico, descrição bilíngue
//
// Estrutura do arquivo JS:
//   DRUG_ALIASES   = { "alias": "canonico" }
//   DRUG_CLASSES   = { "$classe_x": ["droga1", ...] }
//   INTERACOES_DB  = { "droga|$classe": { "droga|$classe": { gravidade, ... } } }
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ── Modelo de alerta DDI ──────────────────────────────────────────────────────
class DdiAlert {
  /// Par original de chips que colide (texto como digitado pelo médico)
  final String drugA;
  final String drugB;

  /// Chaves canônicas usadas no lookup
  final String canonicalA;
  final String canonicalB;

  /// Nível de gravidade: 'contraindicada' | 'alta' | 'moderada' | 'leve'
  final String gravidade;

  /// Relevância clínica 1-5 (5 = risco de vida imediato)
  final int scoreClinico;

  /// Descrição clínica bilíngue
  final String descricaoPt;
  final String descricaoEs;

  /// Conduta clínica bilíngue
  final String condutaPt;
  final String condutaEs;

  const DdiAlert({
    required this.drugA,
    required this.drugB,
    required this.canonicalA,
    required this.canonicalB,
    required this.gravidade,
    required this.scoreClinico,
    required this.descricaoPt,
    required this.descricaoEs,
    required this.condutaPt,
    required this.condutaEs,
  });

  /// Cor de fundo do banner baseada na gravidade
  /// Retorna: [background, border, text] como strings hex
  List<String> get uiColors {
    switch (gravidade) {
      case 'contraindicada':
        return ['#FEE2E2', '#FCA5A5', '#991B1B'];
      case 'alta':
        return ['#FEF3C7', '#FCD34D', '#92400E'];
      case 'moderada':
        return ['#FEF9C3', '#FDE047', '#713F12'];
      default: // 'leve'
        return ['#DBEAFE', '#93C5FD', '#1E40AF'];
    }
  }

  /// Emoji de risco
  String get emoji {
    switch (gravidade) {
      case 'contraindicada': return '🚫';
      case 'alta':           return '⚠️';
      case 'moderada':       return '⚡';
      default:               return 'ℹ️';
    }
  }

  /// Texto do título do banner
  String titleEs() {
    switch (gravidade) {
      case 'contraindicada': return 'Interacción Contraindicada';
      case 'alta':           return 'Interacción de Riesgo Alto';
      case 'moderada':       return 'Interacción Moderada';
      default:               return 'Interacción Leve';
    }
  }

  String titlePt() {
    switch (gravidade) {
      case 'contraindicada': return 'Interação Contraindicada';
      case 'alta':           return 'Interação de Risco Alto';
      case 'moderada':       return 'Interação Moderada';
      default:               return 'Interação Leve';
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// DrugInteractionService — singleton
// ═════════════════════════════════════════════════════════════════════════════
class DrugInteractionService {
  DrugInteractionService._();
  static final DrugInteractionService instance = DrugInteractionService._();

  // ── Fonte de dados ────────────────────────────────────────────────────────
  static const _jsUrl =
      'https://raw.githubusercontent.com/rodrigssousa-sudo/'
      'medcases-calculadora/main/database/interacoes.js';

  static const _cacheKey       = 'ddi_js_cache_v1';
  static const _cacheTsKey     = 'ddi_js_cache_ts_v1';
  static const _cacheTtl       = Duration(hours: 24);

  // ── Estado interno ────────────────────────────────────────────────────────
  bool _loaded  = false;
  bool _loading = false;

  // Tabelas parseadas
  Map<String, String>              _aliases  = {};  // alias → canônico
  Map<String, List<String>>        _classes  = {};  // $classe_x → [drogas]
  Map<String, Map<String, _Entry>> _db       = {};  // canonico → {canonico → Entry}

  // ─────────────────────────────────────────────────────────────────────────
  // API pública
  // ─────────────────────────────────────────────────────────────────────────

  bool get isLoaded => _loaded;

  /// Inicializa o serviço: carrega cache ou faz fetch.
  /// Seguro chamar múltiplas vezes (idempotente).
  Future<void> init() async {
    if (_loaded || _loading) return;
    _loading = true;
    try {
      await _loadOrFetch();
    } catch (e, s) {
      debugPrint('💊 [DDI] init error: $e\n$s');
    } finally {
      _loading = false;
    }
  }

  /// Verifica interações entre [drugLabels] (textos dos chips como digitados).
  /// Retorna lista de alertas ordenados por scoreClinico desc.
  List<DdiAlert> check(List<String> drugLabels) {
    if (!_loaded || drugLabels.length < 2) return [];

    // 1. Normaliza + resolve aliases para cada chip
    final resolved = <_ResolvedDrug>[];
    for (final label in drugLabels) {
      final norm      = _normalize(label);
      final canonical = _resolveAlias(norm);
      resolved.add(_ResolvedDrug(
        original:  label,
        canonical: canonical,
      ));
    }

    // 2. Cruzamento combinatório n×n (cada par uma vez)
    final alerts = <DdiAlert>[];
    for (var i = 0; i < resolved.length; i++) {
      for (var j = i + 1; j < resolved.length; j++) {
        final a = resolved[i];
        final b = resolved[j];
        final entry = _findInteraction(a.canonical, b.canonical);
        if (entry != null) {
          alerts.add(DdiAlert(
            drugA:       a.original,
            drugB:       b.original,
            canonicalA:  a.canonical,
            canonicalB:  b.canonical,
            gravidade:   entry.gravidade,
            scoreClinico: entry.scoreClinico,
            descricaoPt: entry.descricaoPt,
            descricaoEs: entry.descricaoEs,
            condutaPt:   entry.condutaPt,
            condutaEs:   entry.condutaEs,
          ));
        }
      }
    }

    // Ordena por scoreClinico desc, depois gravidade
    alerts.sort((a, b) {
      final sc = b.scoreClinico.compareTo(a.scoreClinico);
      if (sc != 0) return sc;
      return _gravOrd(b.gravidade).compareTo(_gravOrd(a.gravidade));
    });
    return alerts;
  }

  /// Retorna os nomes originais dos chips que participam de algum alerta.
  Set<String> flaggedDrugs(List<DdiAlert> alerts) {
    final s = <String>{};
    for (final a in alerts) {
      s.add(a.drugA);
      s.add(a.drugB);
    }
    return s;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Internos — carregamento e cache
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _loadOrFetch() async {
    final prefs = await SharedPreferences.getInstance();

    // Verifica TTL do cache
    final tsRaw = prefs.getInt(_cacheTsKey) ?? 0;
    final ts    = DateTime.fromMillisecondsSinceEpoch(tsRaw);
    final age   = DateTime.now().difference(ts);
    final cached = prefs.getString(_cacheKey);

    if (cached != null && age < _cacheTtl) {
      // ── Carrega do cache ──────────────────────────────────────────────────
      debugPrint('💊 [DDI] carregando do cache (idade: ${age.inMinutes}min)');
      _parseJs(cached);
      _loaded = true;
      return;
    }

    // ── Fetch remoto ──────────────────────────────────────────────────────
    debugPrint('💊 [DDI] fetchando base de interações do GitHub...');
    try {
      final response = await http
          .get(Uri.parse(_jsUrl))
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final body = response.body;
        _parseJs(body);
        _loaded = true;
        // Salva no cache
        await prefs.setString(_cacheKey, body);
        await prefs.setInt(_cacheTsKey,
            DateTime.now().millisecondsSinceEpoch);
        debugPrint('💊 [DDI] base carregada e cacheada: '
            '${_aliases.length} aliases, ${_classes.length} classes, '
            '${_db.length} drogas no DB');
      } else {
        debugPrint('💊 [DDI] fetch falhou: HTTP ${response.statusCode}');
        // Tenta usar cache expirado como fallback
        if (cached != null) {
          debugPrint('💊 [DDI] usando cache expirado como fallback');
          _parseJs(cached);
          _loaded = true;
        }
      }
    } catch (e) {
      debugPrint('💊 [DDI] erro de rede: $e');
      // Fallback: cache expirado
      if (cached != null) {
        _parseJs(cached);
        _loaded = true;
        debugPrint('💊 [DDI] fallback offline ativo');
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Internos — parsing do JS
  // ─────────────────────────────────────────────────────────────────────────

  void _parseJs(String src) {
    try {
      _parseAliases(src);
    } catch (e, s) {
      debugPrint('💊 [DDI] ERRO parseAliases: $e\n$s');
    }
    try {
      _parseClasses(src);
    } catch (e, s) {
      debugPrint('💊 [DDI] ERRO parseClasses: $e\n$s');
    }
    try {
      _parseDb(src);
    } catch (e, s) {
      debugPrint('💊 [DDI] ERRO parseDb: $e\n$s');
    }
  }

  // ── 1. DRUG_ALIASES ───────────────────────────────────────────────────────
  void _parseAliases(String src) {
    // Extrai o bloco completo de DRUG_ALIASES = { ... };
    final match = RegExp(
      r'const\s+DRUG_ALIASES\s*=\s*\{(.*?)\};',
      dotAll: true,
    ).firstMatch(src);
    if (match == null) {
      debugPrint('💊 [DDI] DRUG_ALIASES não encontrado');
      return;
    }
    final body = match.group(1)!;
    // Extrai pares "chave": "valor"
    final pairs = RegExp(r'"([^"]+)"\s*:\s*"([^"]+)"').allMatches(body);
    final map   = <String, String>{};
    for (final p in pairs) {
      final key = p.group(1)!.trim();
      final val = p.group(2)!.trim();
      map[key] = val;
    }
    _aliases = map;
    debugPrint('💊 [DDI] aliases: ${_aliases.length}');
  }

  // ── 2. DRUG_CLASSES ───────────────────────────────────────────────────────
  void _parseClasses(String src) {
    // Localiza o bloco de DRUG_CLASSES = { ... };
    // Termina no "};" seguido de comentário /* ═══ INTERACOES
    final match = RegExp(
      r'const\s+DRUG_CLASSES\s*=\s*\{(.*?)\};\s*/\*',
      dotAll: true,
    ).firstMatch(src);
    if (match == null) {
      debugPrint('💊 [DDI] DRUG_CLASSES não encontrado');
      return;
    }
    final body = match.group(1)!;

    // Extrai cada "$classe_X": [ "droga1", "droga2", ... ]
    final classRe = RegExp(
      r'"\s*(\$classe_[^"]+)"\s*:\s*\[(.*?)\]',
      dotAll: true,
    );
    final map = <String, List<String>>{};
    for (final cm in classRe.allMatches(body)) {
      final className = cm.group(1)!.trim();
      final items     = cm.group(2)!;
      final drugs = RegExp(r'"([^"$]+)"')
          .allMatches(items)
          .map((m) => m.group(1)!.trim())
          .where((d) => d.isNotEmpty)
          .toList();
      // Merge para classe duplicada (arquivo repete algumas)
      if (map.containsKey(className)) {
        final existing = map[className]!;
        for (final d in drugs) {
          if (!existing.contains(d)) existing.add(d);
        }
      } else {
        map[className] = drugs;
      }
    }
    _classes = map;
    debugPrint('💊 [DDI] classes: ${_classes.length}');
  }

  // ── 3. INTERACOES_DB ──────────────────────────────────────────────────────
  // Faz parsing linha a linha em vez de regex aninhado (mais robusto para
  // arquivo de 580KB com objetos profundamente aninhados).
  void _parseDb(String src) {
    // Localiza o bloco entre "const INTERACOES_DB = {" e "}; /* fim INTERACOES_DB */"
    final startIdx = src.indexOf('const INTERACOES_DB = {');
    final endMarker = '}; /* fim INTERACOES_DB */';
    final endIdx = src.indexOf(endMarker);
    if (startIdx == -1 || endIdx == -1) {
      debugPrint('💊 [DDI] INTERACOES_DB delimitadores não encontrados');
      return;
    }

    final dbBlock = src.substring(startIdx, endIdx + endMarker.length);

    // Parser linha a linha com máquina de estados
    final lines = LineSplitter.split(dbBlock).toList();

    // Resolve referências a INTERACOES_MODELOS antes de parsear
    final modelos = _parseModelos(src);

    final db = <String, Map<String, _Entry>>{};
    String? topKey;     // droga ou $classe de nível superior
    String? innerKey;   // droga ou $classe de nível interno
    int depth = 0;

    // Buffer para acumular campos de uma interação
    String? curGravidade;
    int     curScore = 3;
    String  curDescPt = '';
    String  curDescEs = '';
    String  curCondPt = '';
    String  curCondEs = '';
    bool    inDescPt = false, inDescEs = false;

    void flushEntry() {
      if (topKey != null && innerKey != null && curGravidade != null) {
        db.putIfAbsent(topKey, () => {})[innerKey] = _Entry(
          gravidade:   curGravidade!,
          scoreClinico: curScore,
          descricaoPt: curDescPt,
          descricaoEs: curDescEs,
          condutaPt:   curCondPt,
          condutaEs:   curCondEs,
        );
      }
      curGravidade = null;
      curScore     = 3;
      curDescPt    = '';
      curDescEs    = '';
      curCondPt    = '';
      curCondEs    = '';
      inDescPt = inDescEs = false;
    }

    final topKeyRe    = RegExp(r'^\s{2}"([^"]+)"\s*:\s*\{');
    final innerKeyRe  = RegExp(r'^\s{4}"([^"]+)"\s*:\s*(?:INTERACOES_MODELOS\.(\w+)|\{)');
    final gravRe      = RegExp(r'gravidade\s*:\s*"([^"]+)"');
    final scoreRe     = RegExp(r'scoreClinico\s*:\s*(\d+)');
    final descPtRe    = RegExp(r'pt\s*:\s*"(.+)"');
    final descEsRe    = RegExp(r'es\s*:\s*"(.+)"');

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      // Conta profundidade pelas chaves
      final opens  = '{'.allMatches(line).length;
      final closes = '}'.allMatches(line).length;

      // ── Chave de nível 1 (2 espaços) ──────────────────────────────────
      if (depth == 1) {
        final m = topKeyRe.firstMatch(line);
        if (m != null) {
          topKey   = m.group(1)!;
          innerKey = null;
          flushEntry();
        }
      }

      // ── Chave de nível 2 (4 espaços) ──────────────────────────────────
      if (depth == 2) {
        final m = innerKeyRe.firstMatch(line);
        if (m != null) {
          flushEntry();
          innerKey = m.group(1)!;
          // Referência a INTERACOES_MODELOS?
          final modeloRef = m.group(2);
          if (modeloRef != null && modelos.containsKey(modeloRef)) {
            final entry = modelos[modeloRef]!;
            if (topKey != null) db.putIfAbsent(topKey, () => {})[innerKey] = entry;
            innerKey = null; // já registrado, não acumular
          }
        }
      }

      // ── Campos dentro da interação (depth ≥ 3) ────────────────────────
      if (depth >= 2 && innerKey != null) {
        // gravidade
        final gm = gravRe.firstMatch(trimmed);
        if (gm != null) curGravidade = gm.group(1);

        // scoreClinico
        final sm = scoreRe.firstMatch(trimmed);
        if (sm != null) curScore = int.tryParse(sm.group(1)!) ?? 3;

        // Descrição pt / es
        if (trimmed.startsWith('pt:') || trimmed.startsWith('"pt"')) {
          final dm = descPtRe.firstMatch(trimmed);
          if (dm != null) {
            curDescPt = _unescapeJs(dm.group(1)!);
            inDescPt = false;
          } else if (trimmed.contains('pt:')) {
            inDescPt = true;
          }
        } else if (inDescPt && trimmed.isNotEmpty && !trimmed.startsWith('es:') && !trimmed.startsWith('"es"')) {
          curDescPt += ' ${_stripJs(trimmed)}';
          if (trimmed.endsWith('"') || trimmed.endsWith('",')) inDescPt = false;
        }

        if (trimmed.startsWith('es:') || trimmed.startsWith('"es"')) {
          final dm = descEsRe.firstMatch(trimmed);
          if (dm != null) {
            curDescEs = _unescapeJs(dm.group(1)!);
            inDescEs = false;
          } else if (trimmed.contains('es:')) {
            inDescEs = true;
          }
        } else if (inDescEs && trimmed.isNotEmpty) {
          curDescEs += ' ${_stripJs(trimmed)}';
          if (trimmed.endsWith('"') || trimmed.endsWith('",')) inDescEs = false;
        }

        // Conduta pt / es (mesma lógica mas dentro de 'conduta')
        if (trimmed.startsWith('conduta') || trimmed.startsWith('"conduta"')) {
          // próximas linhas são pt/es de conduta
        }
        // Heurística: depois de detectar "conduta" seguido de pt/es
        // Reutilizamos as flags: a segunda ocorrência de pt/es no mesmo bloco = conduta
        if (curDescPt.isNotEmpty && curDescEs.isNotEmpty) {
          // segunda ocorrência de pt: → conduta
          final cpm = descPtRe.firstMatch(trimmed);
          if (cpm != null && cpm.group(1) != curDescPt) {
            final candidate = _unescapeJs(cpm.group(1)!);
            if (candidate != curDescPt && curCondPt.isEmpty) {
              curCondPt = candidate;
            }
          }
          final cem = descEsRe.firstMatch(trimmed);
          if (cem != null && cem.group(1) != curDescEs) {
            final candidate = _unescapeJs(cem.group(1)!);
            if (candidate != curDescEs && curCondEs.isEmpty) {
              curCondEs = candidate;
            }
          }
        }
      }

      // Atualiza profundidade APÓS processar a linha
      depth += opens - closes;
      if (depth < 0) depth = 0;
    }

    _db = db;
    // Conta pares de interação
    int total = 0;
    for (final v in db.values) { total += v.length; }
    debugPrint('💊 [DDI] DB: ${db.length} drogas top-level, $total pares de interação');
  }

  // ── Parser de INTERACOES_MODELOS (templates reutilizáveis) ───────────────
  Map<String, _Entry> _parseModelos(String src) {
    final map   = <String, _Entry>{};
    final match = RegExp(
      r'const\s+INTERACOES_MODELOS\s*=\s*\{(.*?)\};',
      dotAll: true,
    ).firstMatch(src);
    if (match == null) return map;

    final body = match.group(1)!;
    // Cada modelo: "nome": { gravidade, scoreClinico, descricao: {pt, es}, conduta: {pt, es} }
    final modelRe = RegExp(
      r'"?(\w+)"?\s*:\s*\{.*?gravidade\s*:\s*"([^"]+)".*?scoreClinico\s*:\s*(\d+).*?'
      r'pt\s*:\s*"([^"]+)".*?es\s*:\s*"([^"]+)".*?'
      r'pt\s*:\s*"([^"]+)".*?es\s*:\s*"([^"]+)"',
      dotAll: true,
    );
    for (final m in modelRe.allMatches(body)) {
      final name = m.group(1)!;
      map[name] = _Entry(
        gravidade:    m.group(2)!,
        scoreClinico: int.tryParse(m.group(3)!) ?? 3,
        descricaoPt:  _unescapeJs(m.group(4)!),
        descricaoEs:  _unescapeJs(m.group(5)!),
        condutaPt:    _unescapeJs(m.group(6)!),
        condutaEs:    _unescapeJs(m.group(7)!),
      );
    }
    debugPrint('💊 [DDI] modelos: ${map.length}');
    return map;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Internos — normalização e lookup
  // ─────────────────────────────────────────────────────────────────────────

  /// Normaliza o texto do chip para a chave canônica usada no DB:
  ///   "Cloridrato de Ciprofloxacina 400mg IV" → "ciprofloxacina"
  String _normalize(String text) {
    var s = text;

    // Remove padrões de frequência: 8/8h, 12/12h, 6x/dia
    s = s.replaceAll(RegExp(r'\d+/\d+h\b', caseSensitive: false), ' ');
    s = s.replaceAll(RegExp(r'\b\d+\s*x/\w+\b', caseSensitive: false), ' ');

    // Remove doses com unidades
    s = s.replaceAll(
      RegExp(r'\d+[\.,]?\d*\s*(mg|mcg|g|ml|ui|meg|meq|mmol|µg|ug)\b',
          caseSensitive: false),
      ' ',
    );

    // Remove números restantes
    s = s.replaceAll(RegExp(r'\b\d+\b'), ' ');

    // Remove vias de administração
    s = s.replaceAll(
      RegExp(r'\b(iv|im|sc|vo|sl|ev|id|inalatorio|inalatoria|oral|'
          r'intravenoso|intramuscular|subcutaneo|subcutâneo|endovenoso|'
          r'retal|topico|topical|nasal|oftalmico|auditivo)\b',
          caseSensitive: false),
      ' ',
    );

    // Remove sais farmacêuticos e palavras acessórias
    s = s.replaceAll(
      RegExp(
          r'\b(cloridrato|dicloridrato|sulfato|fosfato|tartarato|maleato|'
          r'fumarato|citrato|benzoato|mesilato|tosilato|lactato|acetato|'
          r'gluconato|de|do|da|dos|das|para|com|sem|em|'
          r'comprimido|capsula|ampola|frasco|solucao|suspensao|'
          r'injetavel|revestido|liberacao|prolongada|retardada|'
          r'modificada|simples|generico)\b',
          caseSensitive: false),
      ' ',
    );

    // Remove pontuação exceto hífens e letras acentuadas
    s = s.replaceAll(RegExp(r'[^a-zA-ZÀ-ÿ\s\-]'), ' ');

    // Troca hífen por espaço
    s = s.replaceAll('-', ' ');

    // Remove acentos (fold ASCII)
    final normalized = s.runes.map((r) {
      // Mapeamento manual dos caracteres acentuados mais comuns
      const map = {
        'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
        'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
        'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
        'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
        'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
        'ç': 'c', 'ñ': 'n',
        'Á': 'a', 'À': 'a', 'Â': 'a', 'Ã': 'a',
        'É': 'e', 'Ê': 'e',
        'Í': 'i', 'Î': 'i',
        'Ó': 'o', 'Ô': 'o', 'Õ': 'o',
        'Ú': 'u', 'Û': 'u',
        'Ç': 'c', 'Ñ': 'n',
      };
      final ch = String.fromCharCode(r);
      return map[ch] ?? ch;
    }).join();

    // Lowercase, múltiplos espaços → underscore
    final token = normalized
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');

    return token;
  }

  /// Aplica alias lookup (step 2):
  ///   "ciprofloxacino" → "levofloxacino" (via DRUG_ALIASES)
  String _resolveAlias(String normalized) {
    return _aliases[normalized] ?? normalized;
  }

  /// Retorna todas as $classes a que um fármaco pertence.
  List<String> _classesOf(String canonical) {
    return _classes.entries
        .where((e) => e.value.contains(canonical))
        .map((e) => e.key)
        .toList();
  }

  /// Busca a interação entre dois canônicos (bidirecional + class expansion).
  _Entry? _findInteraction(String a, String b) {
    // Coleta todos os "endereços" de busca para A e B:
    //   droga direta + todas as suas $classes
    final keysA = [a, ..._classesOf(a)];
    final keysB = [b, ..._classesOf(b)];

    for (final ka in keysA) {
      for (final kb in keysB) {
        // A→B
        final entry = _db[ka]?[kb] ?? _db[kb]?[ka];
        if (entry != null) return entry;
      }
    }
    return null;
  }

  int _gravOrd(String g) {
    const order = {
      'contraindicada': 4,
      'alta': 3,
      'moderada': 2,
      'leve': 1,
    };
    return order[g] ?? 0;
  }

  // ── Helpers de limpeza de strings JS ─────────────────────────────────────
  static String _unescapeJs(String s) =>
      s.replaceAll(r'\"', '"').replaceAll(r"\'", "'").replaceAll(r'\\', r'\');

  static String _stripJs(String s) {
    var r = s;
    // Remove aspas envoltórias e vírgulas finais
    // Nota: não usar \' em character class de raw string — separar em dois replaceAll
    r = r.replaceAll(RegExp(r'^["]+ | ["]+ ,?\s*$'), '');
    r = r.replaceAll(RegExp("^[']+|[']+,?\\s*\$"), '');
    return r.trim();
  }
}

// ── Modelos internos (não expostos) ──────────────────────────────────────────
class _Entry {
  final String gravidade;
  final int    scoreClinico;
  final String descricaoPt;
  final String descricaoEs;
  final String condutaPt;
  final String condutaEs;

  const _Entry({
    required this.gravidade,
    required this.scoreClinico,
    required this.descricaoPt,
    required this.descricaoEs,
    required this.condutaPt,
    required this.condutaEs,
  });
}

class _ResolvedDrug {
  final String original;
  final String canonical;
  const _ResolvedDrug({required this.original, required this.canonical});
}
