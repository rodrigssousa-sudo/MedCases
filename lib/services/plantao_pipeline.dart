// ══════════════════════════════════════════════════════════════════════════════
// plantao_pipeline.dart — Plantão Pipeline v1.0 (Build 193)
//
// RESPONSABILIDADES:
//   • PlantaoResponse  — data class estruturada com 6 campos clínicos
//   • PlantaoParser    — extrai PlantaoResponse de texto validado via emoji-anchors
//   • PlantaoValidator — valida estrutura mínima (🟥 primeira, 💊+📌 presentes, ordem)
//   • PlantaoRepair    — reorganiza blocos, elimina duplicatas, normaliza espaços
//                        (NUNCA inventa conteúdo clínico)
//
// PIPELINE COMPLETO (Build 193):
//   LLM output
//     → sanitizeResponse()       [ai_smart_router.dart — meta leak filter]
//     → PlantaoRepair.repair()   [reorganiza blocos, deduplication]
//     → PlantaoValidator.isValid() [valida estrutura mínima]
//     → PlantaoParser.parse()    [constrói objeto estruturado]
//     → _PlantaoRenderer         [renderiza layout determinístico na UI]
//
// EMOJIS ÂNCORA (ordem canônica):
//   🟥  → conduta (OBRIGATÓRIO — primeira linha)
//   💊  → primeiraLinha (OBRIGATÓRIO)
//   🔄  → alternativa (opcional)
//   ⛔  → evitar (opcional)
//   📌  → monitorar (OBRIGATÓRIO)
//   ⚠️  → alerta (opcional)
//
// SEGURANÇA:
//   • Linhas iniciando com '[' são silenciosamente ignoradas
//   • Frases de CoT / meta-instrução são removidas
//   • Campos opcionais ausentes → campo null (não renderizado)
//   • Streaming: pipeline só é aplicado no chunk.isDone
//
// LOG ESTRUTURADO:
//   [PLANTAO_VALIDATOR] valid=true repaired=false removedLines=2
//                       hiddenFields=1 orderFixed=true
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart' show debugPrint;

// ─────────────────────────────────────────────────────────────────────────────
// PlantaoResponse — objeto estruturado com campos clínicos
//
// Campos:
//   conduta      (🟥) — OBRIGATÓRIO — cabeçalho/título da conduta imediata
//   primeiraLinha(💊) — OBRIGATÓRIO — fármaco principal + dose + via
//   alternativa  (🔄) — opcional — segunda opção terapêutica
//   evitar       (⛔) — opcional — contraindicação quando houver
//   monitorar    (📌) — OBRIGATÓRIO — parâmetro de segurança / próximo passo
//   alerta       (⚠️) — opcional — risco crítico quando houver
// ─────────────────────────────────────────────────────────────────────────────
class PlantaoResponse {
  /// 🟥 Conduta clínica imediata — texto do cabeçalho (sem o emoji)
  final String conduta;

  /// 💊 Primeira linha terapêutica — fármaco + dose + via + frequência
  final String primeiraLinha;

  /// 🔄 Alternativa terapêutica — segunda opção (null se não houver)
  final String? alternativa;

  /// ⛔ Evitar — contraindicação (null se não houver)
  final String? evitar;

  /// 📌 Monitorar — parâmetro principal de segurança / próximo passo
  final String monitorar;

  /// ⚠️ Alerta — risco crítico (null se não houver)
  final String? alerta;

  const PlantaoResponse({
    required this.conduta,
    required this.primeiraLinha,
    required this.monitorar,
    this.alternativa,
    this.evitar,
    this.alerta,
  });

  /// Número de campos opcionais ausentes (para log hiddenFields)
  int get hiddenFields {
    int count = 0;
    if (alternativa == null || alternativa!.isEmpty) count++;
    if (evitar == null || evitar!.isEmpty) count++;
    if (alerta == null || alerta!.isEmpty) count++;
    return count;
  }

  /// Retorna true se todos os campos obrigatórios têm conteúdo
  bool get isComplete =>
      conduta.trim().isNotEmpty &&
      primeiraLinha.trim().isNotEmpty &&
      monitorar.trim().isNotEmpty;

  @override
  String toString() =>
      'PlantaoResponse(conduta: "$conduta", primeiraLinha: "$primeiraLinha", '
      'alternativa: "$alternativa", evitar: "$evitar", '
      'monitorar: "$monitorar", alerta: "$alerta")';
}

// ─────────────────────────────────────────────────────────────────────────────
// _EmojiBlock — representação interna de um bloco emoji durante parsing
// ─────────────────────────────────────────────────────────────────────────────
class _EmojiBlock {
  final String emoji;       // âncora: '🟥', '💊', '🔄', '⛔', '📌', '⚠️'
  final List<String> lines; // linhas de conteúdo deste bloco

  _EmojiBlock({required this.emoji, required this.lines});

  /// Texto consolidado do bloco (sem o emoji âncora da primeira linha)
  String get text => lines.join('\n').trim();
}

// ─────────────────────────────────────────────────────────────────────────────
// PlantaoParser — extrai PlantaoResponse de texto via emoji-anchors
//
// Estratégia:
//   1. Divide texto em linhas
//   2. Ignora linhas iniciando com '[' (segurança)
//   3. Detecta âncoras emoji para delimitar blocos
//   4. Consolida blocos em campos de PlantaoResponse
//   5. Aplica fallback se campos obrigatórios estiverem vazios
// ─────────────────────────────────────────────────────────────────────────────
class PlantaoParser {
  PlantaoParser._(); // 100% estático

  // Âncoras na ordem canônica
  static const _kConduta      = '🟥';
  static const _kPrimeira     = '💊';
  static const _kAlternativa  = '🔄';
  static const _kEvitar       = '⛔';
  static const _kMonitorar    = '📌';
  static const _kAlerta       = '⚠️';

  static const _kAllAnchors = [
    _kConduta, _kPrimeira, _kAlternativa,
    _kEvitar, _kMonitorar, _kAlerta,
  ];

  /// Detecta qual âncora está no início da linha (null se nenhuma)
  static String? _detectAnchor(String line) {
    final t = line.trim();
    for (final anchor in _kAllAnchors) {
      if (t.startsWith(anchor)) return anchor;
    }
    return null;
  }

  /// Extrai o texto de conteúdo de uma linha de cabeçalho (remove a âncora emoji)
  static String _extractContent(String line, String anchor) {
    final t = line.trim();
    if (t.startsWith(anchor)) {
      return t.substring(anchor.length).trim();
    }
    return t;
  }

  /// Verifica se a linha deve ser ignorada por segurança
  static bool _shouldSkip(String line) {
    final t = line.trim();
    if (t.isEmpty) return false;
    // Segurança: nunca renderizar linhas com marcadores técnicos
    if (t.startsWith('[')) return true;
    return false;
  }

  /// Parse principal: texto → PlantaoResponse
  ///
  /// Retorna null se os campos obrigatórios não puderem ser extraídos.
  static PlantaoResponse? parse(String rawText) {
    if (rawText.trim().isEmpty) return null;

    final lines = rawText.split('\n');

    // ── Passo 1: agrupa linhas em blocos por âncora emoji ─────────────────
    final Map<String, _EmojiBlock> blocks = {};
    String? currentAnchor;
    final List<String> currentLines = [];

    void flushBlock() {
      if (currentAnchor == null || currentLines.isEmpty) return;
      // Consolida: primeira linha tem a âncora, demais são continuação
      blocks[currentAnchor!] = _EmojiBlock(
        emoji: currentAnchor!,
        lines: List.from(currentLines),
      );
      currentLines.clear();
      currentAnchor = null;
    }

    for (final line in lines) {
      if (_shouldSkip(line)) continue;

      final anchor = _detectAnchor(line);

      if (anchor != null) {
        // Nova âncora detectada — flush bloco anterior
        flushBlock();
        currentAnchor = anchor;
        final content = _extractContent(line, anchor);
        currentLines.add(content);
      } else if (currentAnchor != null) {
        // Continuação do bloco atual
        final t = line.trim();
        if (t.isNotEmpty) {
          currentLines.add(t);
        }
      }
      // Linhas antes de qualquer âncora são ignoradas
    }
    flushBlock(); // flush do último bloco

    // ── Passo 2: extrai campos ─────────────────────────────────────────────
    final condutaBlock    = blocks[_kConduta];
    final primeiraBlock   = blocks[_kPrimeira];
    final alternativaBlock = blocks[_kAlternativa];
    final evitarBlock     = blocks[_kEvitar];
    final monitorarBlock  = blocks[_kMonitorar];
    final alertaBlock     = blocks[_kAlerta];

    // Campos obrigatórios: conduta, primeiraLinha, monitorar
    final condutaText    = condutaBlock?.text ?? '';
    final primeiraText   = primeiraBlock?.text ?? '';
    final monitorarText  = monitorarBlock?.text ?? '';

    // Se campos obrigatórios estiverem vazios, não podemos construir o objeto
    if (condutaText.isEmpty || primeiraText.isEmpty || monitorarText.isEmpty) {
      debugPrint('[PLANTAO_PARSER] parse falhou: campos obrigatórios ausentes '
          '(conduta=${condutaText.isNotEmpty} primLinha=${primeiraText.isNotEmpty} '
          'monitorar=${monitorarText.isNotEmpty})');
      return null;
    }

    // Campos opcionais: null se vazios
    final alternativaText = alternativaBlock?.text;
    final evitarText      = evitarBlock?.text;
    final alertaText      = alertaBlock?.text;

    return PlantaoResponse(
      conduta:      condutaText,
      primeiraLinha: primeiraText,
      alternativa:  (alternativaText?.isNotEmpty == true) ? alternativaText : null,
      evitar:       (evitarText?.isNotEmpty == true) ? evitarText : null,
      monitorar:    monitorarText,
      alerta:       (alertaText?.isNotEmpty == true) ? alertaText : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PlantaoValidator — valida estrutura mínima da resposta Plantão
//
// Regras:
//   1. Primeira linha não-vazia deve iniciar com 🟥
//   2. Deve conter bloco 💊
//   3. Deve conter bloco 📌
//   4. Mínimo de 4 linhas de conteúdo real
//   5. Máximo de 14 linhas de conteúdo real
//   6. Ordem dos blocos: 🟥 antes de 💊, 💊 antes de 📌
// ─────────────────────────────────────────────────────────────────────────────
class PlantaoValidator {
  PlantaoValidator._(); // 100% estático

  /// Valida a resposta textual bruta (pós-sanitize, pré-parse)
  /// Retorna true se a estrutura mínima estiver correta
  static bool isValid(String text) {
    if (text.trim().isEmpty) return false;

    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) return false;

    // ── Regra 1: primeira linha inicia com 🟥 ─────────────────────────────
    if (!lines.first.startsWith('🟥')) return false;

    // ── Regras 2-3: blocos obrigatórios presentes ─────────────────────────
    final hasConduta  = lines.any((l) => l.startsWith('🟥'));
    final hasPrimeira = lines.any((l) => l.startsWith('💊'));
    final hasMonitorar = lines.any((l) => l.startsWith('📌'));

    if (!hasConduta || !hasPrimeira || !hasMonitorar) return false;

    // ── Regra 4-5: limites de linhas ──────────────────────────────────────
    final contentLineCount = lines.length;
    if (contentLineCount < 4) return false;
    if (contentLineCount > 14) return false;

    // ── Regra 6: ordem dos blocos ─────────────────────────────────────────
    final idxConduta  = lines.indexWhere((l) => l.startsWith('🟥'));
    final idxPrimeira = lines.indexWhere((l) => l.startsWith('💊'));
    final idxMonitorar = lines.indexWhere((l) => l.startsWith('📌'));

    // 🟥 deve vir antes de 💊, e 💊 deve vir antes de 📌
    if (idxConduta >= idxPrimeira) return false;
    if (idxPrimeira >= idxMonitorar) return false;

    return true;
  }

  /// Valida um PlantaoResponse já parseado
  static bool isValidResponse(PlantaoResponse r) {
    return r.conduta.trim().isNotEmpty &&
        r.primeiraLinha.trim().isNotEmpty &&
        r.monitorar.trim().isNotEmpty;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PlantaoRepair — reorganiza blocos para a ordem canônica
//
// IMPORTANTE: NUNCA inventa conteúdo clínico.
// Apenas:
//   • reorganiza blocos existentes para a ordem correta
//   • remove linhas vazias excessivas
//   • elimina blocos âncora duplicados (mantém o primeiro de cada)
//   • normaliza espaçamentos
//   • remove linhas iniciando com '[' (segurança)
//
// Ordem canônica de saída:
//   🟥 → 💊 → 🔄 → ⛔ → 📌 → ⚠️
// ─────────────────────────────────────────────────────────────────────────────
class PlantaoRepair {
  PlantaoRepair._(); // 100% estático

  static const _kCanonicalOrder = ['🟥', '💊', '🔄', '⛔', '📌', '⚠️'];

  /// Aplica reparo estrutural na resposta textual
  ///
  /// Retorna (repairedText, wasRepaired, removedLines, orderFixed)
  static ({String text, bool repaired, int removedLines, bool orderFixed})
      repair(String rawText) {
    if (rawText.trim().isEmpty) {
      return (text: rawText, repaired: false, removedLines: 0, orderFixed: false);
    }

    final originalLines = rawText.split('\n');
    int removedLines = 0;

    // ── Passo 1: limpa linhas inseguras e vazias excessivas ───────────────
    final filteredLines = <String>[];
    int consecutiveEmpty = 0;

    for (final line in originalLines) {
      final t = line.trim();

      // Segurança: remove linhas iniciando com '['
      if (t.startsWith('[')) {
        removedLines++;
        continue;
      }

      // Remove linhas excessivamente vazias (máx 1 consecutiva)
      if (t.isEmpty) {
        consecutiveEmpty++;
        if (consecutiveEmpty <= 1) {
          filteredLines.add('');
        } else {
          removedLines++;
        }
        continue;
      }

      consecutiveEmpty = 0;
      filteredLines.add(line);
    }

    // ── Passo 2: agrupa linhas em blocos por âncora emoji ─────────────────
    // Mesmo algoritmo do PlantaoParser mas mantemos o texto original das linhas
    final Map<String, List<String>> blockLines = {};
    final List<String> preAnchorLines = []; // linhas antes de qualquer âncora
    String? currentAnchor;
    final List<String> currentContent = [];

    void flushCurrentBlock() {
      if (currentAnchor == null) return;
      if (!blockLines.containsKey(currentAnchor!)) {
        // Só mantém a primeira ocorrência de cada âncora (deduplication)
        blockLines[currentAnchor!] = List.from(currentContent);
      } else {
        // Bloco duplicado: descarta silenciosamente, conta como removed
        removedLines += currentContent.length;
      }
      currentContent.clear();
      currentAnchor = null;
    }

    bool foundFirstAnchor = false;

    for (final line in filteredLines) {
      final t = line.trim();
      if (t.isEmpty) {
        if (currentAnchor != null) {
          // Linhas vazias dentro de um bloco são ignoradas
        }
        continue;
      }

      String? anchor;
      for (final a in _kCanonicalOrder) {
        if (t.startsWith(a)) {
          anchor = a;
          break;
        }
      }

      if (anchor != null) {
        flushCurrentBlock();
        foundFirstAnchor = true;
        currentAnchor = anchor;
        currentContent.add(line);
      } else if (currentAnchor != null) {
        currentContent.add(line);
      } else if (!foundFirstAnchor) {
        preAnchorLines.add(line);
      }
      // Linhas fora de qualquer bloco após a primeira âncora são descartadas
    }
    flushCurrentBlock();

    // ── Passo 3: detecta se a ordem original estava errada ────────────────
    bool orderFixed = false;
    final originalOrder = <String>[];
    for (final line in filteredLines) {
      final t = line.trim();
      for (final a in _kCanonicalOrder) {
        if (t.startsWith(a)) {
          originalOrder.add(a);
          break;
        }
      }
    }

    final canonicalPresent = _kCanonicalOrder
        .where((a) => blockLines.containsKey(a))
        .toList();

    // Filtra originalOrder para só os que existem
    final originalPresent = originalOrder
        .where((a) => blockLines.containsKey(a))
        .toList();

    // Verifica se a ordem original difere da canônica
    if (originalPresent.length == canonicalPresent.length) {
      for (int i = 0; i < originalPresent.length; i++) {
        if (originalPresent[i] != canonicalPresent[i]) {
          orderFixed = true;
          break;
        }
      }
    }

    // ── Passo 4: reconstrói na ordem canônica ─────────────────────────────
    final output = StringBuffer();

    for (final anchor in _kCanonicalOrder) {
      final block = blockLines[anchor];
      if (block == null || block.isEmpty) continue;
      for (final line in block) {
        output.writeln(line);
      }
    }

    final repairedText = output.toString().trimRight();

    // ── Passo 5: detecta se houve reparo real ─────────────────────────────
    final originalClean = filteredLines
        .where((l) => l.trim().isNotEmpty)
        .join('\n');
    final repairedClean = repairedText
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .join('\n');

    final wasRepaired = (removedLines > 0) ||
        orderFixed ||
        (originalClean != repairedClean);

    return (
      text: repairedText,
      repaired: wasRepaired,
      removedLines: removedLines,
      orderFixed: orderFixed,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PlantatoPipeline — orquestra o pipeline completo (Build 193)
//
// Entrada:  texto bruto pós-sanitizeResponse()
// Saída:    PlantaoPipelineResult com objeto estruturado + métricas de log
//
// Deve ser chamado APENAS em chunk.isDone (nunca durante streaming).
// ─────────────────────────────────────────────────────────────────────────────
class PlantatoPipelineResult {
  final PlantaoResponse? response; // null se o pipeline falhou
  final bool valid;
  final bool repaired;
  final int removedLines;
  final int hiddenFields;
  final bool orderFixed;
  final String fallbackText; // texto original para fallback se response == null

  const PlantatoPipelineResult({
    required this.response,
    required this.valid,
    required this.repaired,
    required this.removedLines,
    required this.hiddenFields,
    required this.orderFixed,
    required this.fallbackText,
  });
}

class PlantatoPipeline {
  PlantatoPipeline._(); // 100% estático

  /// Executa o pipeline completo: repair → validate → parse
  ///
  /// Retorna PlantatoPipelineResult.
  /// Se o pipeline falhar (texto não estruturado), response será null
  /// e fallbackText conterá o texto original para renderização de fallback.
  static PlantatoPipelineResult run(String sanitizedText) {
    if (sanitizedText.trim().isEmpty) {
      return PlantatoPipelineResult(
        response: null,
        valid: false,
        repaired: false,
        removedLines: 0,
        hiddenFields: 0,
        orderFixed: false,
        fallbackText: sanitizedText,
      );
    }

    // ── Camada 1: PlantaoRepair ────────────────────────────────────────────
    final repairResult = PlantaoRepair.repair(sanitizedText);
    final repairedText = repairResult.text;

    // ── Camada 2: PlantaoValidator ─────────────────────────────────────────
    final isValid = PlantaoValidator.isValid(repairedText);

    // ── Camada 3: PlantaoParser ────────────────────────────────────────────
    PlantaoResponse? response;
    int hiddenFields = 0;

    if (isValid || repairedText.contains('🟥')) {
      // Tenta parsear mesmo se a validação falhou (resposta parcialmente válida)
      response = PlantaoParser.parse(repairedText);
      hiddenFields = response?.hiddenFields ?? 0;
    }

    // ── Log [PLANTAO_VALIDATOR] ────────────────────────────────────────────
    debugPrint('[PLANTAO_VALIDATOR] '
        'valid=$isValid '
        'repaired=${repairResult.repaired} '
        'removedLines=${repairResult.removedLines} '
        'hiddenFields=$hiddenFields '
        'orderFixed=${repairResult.orderFixed}');

    if (response != null) {
      debugPrint('[PLANTAO_VALIDATOR] parse=ok '
          'conduta="${response.conduta.length > 40 ? response.conduta.substring(0, 40) : response.conduta}…"');
    } else {
      debugPrint('[PLANTAO_VALIDATOR] parse=null — fallback para renderização de texto');
    }

    return PlantatoPipelineResult(
      response: response,
      valid: isValid,
      repaired: repairResult.repaired,
      removedLines: repairResult.removedLines,
      hiddenFields: hiddenFields,
      orderFixed: repairResult.orderFixed,
      fallbackText: sanitizedText,
    );
  }
}
