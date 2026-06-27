#!/usr/bin/env python3
# SUPER ORDEM MASTER 41 — Pipeline patch for ai_screen.dart
# Atomic: all three mandates applied in sequence; file written ONLY at the end.

import re

FILE = 'lib/screens/ai_screen.dart'

with open(FILE, encoding='utf-8') as f:
    src = f.read()

original_len = len(src)

# ══════════════════════════════════════════════════════════════════════════════
# MANDATO 1 — POST-STREAM LOCK
# Inserts PlantatoPipeline.run() call BEFORE the "BUILD 276: resolve which msgId"
# block, keying the result into _plantaoPipelineCache using the streaming msg's
# id and safeFinalText.hashCode — so the first ListView.builder frame after
# setState already finds a cache hit.
# ══════════════════════════════════════════════════════════════════════════════

M1_ANCHOR = (
    "            // Descarta notifier ANTES do setState — sem listener pendurado no rebuild.\n"
    "            _streamingTextNotifier?.dispose();\n"
    "            _streamingTextNotifier = null;\n"
    "\n"
    "            // BUILD 276: resolve which msgId will be the new AI bubble so we\n"
    "            // can attach the fade-in to it in ListView.builder.\n"
    "            String? newBubbleMsgId;\n"
    "            if (streamingMsgIdx >= 0 && streamingMsgIdx < _messages.length) {\n"
    "              newBubbleMsgId = _messages[streamingMsgIdx].id;\n"
    "            }\n"
)

M1_REPLACEMENT = (
    "            // Descarta notifier ANTES do setState — sem listener pendurado no rebuild.\n"
    "            _streamingTextNotifier?.dispose();\n"
    "            _streamingTextNotifier = null;\n"
    "\n"
    "            // ── SUPER ORDEM 41 M1: POST-STREAM PIPELINE LOCK ────────────────\n"
    "            // Executa PlantatoPipeline.run() sincronamente no fecho do stream —\n"
    "            // ANTES do setState. Grava resultado no _plantaoPipelineCache com\n"
    "            // chave (msgId:textHash). O ListView.builder encontra hit=true\n"
    "            // na primeira renderização pós-onDone → zero frames de latência.\n"
    "            if (!_longResponse && streamingMsgIdx >= 0 &&\n"
    "                streamingMsgIdx < _messages.length) {\n"
    "              final _streamMsg  = _messages[streamingMsgIdx];\n"
    "              final _cacheKey41 = '${_streamMsg.id}:${safeFinalText.hashCode}';\n"
    "              if (!_plantaoPipelineCache.containsKey(_cacheKey41)) {\n"
    "                final _pipelineResult41 = PlantatoPipeline.run(safeFinalText);\n"
    "                _plantaoPipelineCache[_cacheKey41] = _pipelineResult41;\n"
    "                if (kDebugMode) {\n"
    "                  debugPrint('[POST_STREAM_LOCK] pipeline cached BEFORE setState '\n"
    "                      'msgId=${_streamMsg.id} '\n"
    "                      'textHash=${safeFinalText.hashCode} '\n"
    "                      'parsedOk=${_pipelineResult41.response != null} '\n"
    "                      'repaired=${_pipelineResult41.repaired} '\n"
    "                      'chars=${safeFinalText.length}');\n"
    "                }\n"
    "              }\n"
    "            }\n"
    "\n"
    "            // BUILD 276: resolve which msgId will be the new AI bubble so we\n"
    "            // can attach the fade-in to it in ListView.builder.\n"
    "            String? newBubbleMsgId;\n"
    "            if (streamingMsgIdx >= 0 && streamingMsgIdx < _messages.length) {\n"
    "              newBubbleMsgId = _messages[streamingMsgIdx].id;\n"
    "            }\n"
)

assert M1_ANCHOR in src, "ERRO M1: anchor not found!"
assert src.count(M1_ANCHOR) == 1, f"ERRO M1: anchor appears {src.count(M1_ANCHOR)} times (expected 1)"
src = src.replace(M1_ANCHOR, M1_REPLACEMENT, 1)
print(f"[M1] Post-stream lock inserted ✓  (src now {len(src)} bytes)")

# ══════════════════════════════════════════════════════════════════════════════
# MANDATO 3 — AESTHETIC GUARD (insert call after bullet-strip, before M1 block)
# Inserted BEFORE M1 block which now exists in src.
# The anchor is the bullet-strip ending + the blank line BEFORE M1's comment.
# ══════════════════════════════════════════════════════════════════════════════

M3_ANCHOR = (
    "                .join('\\n');\n"
    "\n"
    "            // ── BUILD 254: SINCRONIZAÇÃO IMEDIATA DO TÉRMINO DO STREAM ────────\n"
)

M3_REPLACEMENT = (
    "                .join('\\n');\n"
    "\n"
    "            // ── SUPER ORDEM 41 M3: AESTHETIC GUARD ───────────────────────────\n"
    "            // Higienização estética exclusiva do Modo Plantão (após todos os\n"
    "            // guards de segurança): remove **bold** residuais, normaliza ALLCAPS\n"
    "            // de labels → Title Case, aplica teto de 12 linhas não-vazias.\n"
    "            // Executado ANTES do pipeline lock para que o texto cacheado já seja\n"
    "            // o texto esteticamente finalizado.\n"
    "            if (!_longResponse) {\n"
    "              safeFinalText = _applyPlantaoAestheticGuard(safeFinalText);\n"
    "            }\n"
    "\n"
    "            // ── BUILD 254: SINCRONIZAÇÃO IMEDIATA DO TÉRMINO DO STREAM ────────\n"
)

# The bullet-strip .join('\n'); line appears multiple times in the file.
# We anchor with the unique BUILD 254 comment that follows the bullet-strip block.
assert M3_ANCHOR in src, "ERRO M3: anchor not found after M1 insertion!"
assert src.count(M3_ANCHOR) == 1, f"ERRO M3: anchor appears {src.count(M3_ANCHOR)} times (expected 1)"
src = src.replace(M3_ANCHOR, M3_REPLACEMENT, 1)
print(f"[M3] Aesthetic guard call inserted ✓  (src now {len(src)} bytes)")

# ══════════════════════════════════════════════════════════════════════════════
# MANDATO 3b — Add helper function _applyPlantaoAestheticGuard()
# Inserted just before _plantaoTruncationGuard's doc-comment block.
# ══════════════════════════════════════════════════════════════════════════════

M3B_ANCHOR = (
    "// ─────────────────────────────────────────────────────────────────────────────\n"
    "// BUILD 248B — _plantaoTruncationGuard (ARQUITETURA CONSOLIDADA + REFORMATTER)\n"
)

M3B_REPLACEMENT = (
    "// ─────────────────────────────────────────────────────────────────────────────\n"
    "// SUPER ORDEM 41 M3 — _applyPlantaoAestheticGuard\n"
    "//\n"
    "// Higienização estética do texto final do Modo Plantão:\n"
    "//   1. Remove marcadores **bold** residuais (Gemini às vezes emite '**Label:**')\n"
    "//      → extrai apenas o conteúdo interno (emojis âncora já presentes).\n"
    "//   2. Normaliza ALLCAPS de labels de matriz (DOSE:, ALERTA:, etc.)\n"
    "//      → Title Case canônico para consistência visual nativa iOS/Android.\n"
    "//   3. Aplica teto de 12 linhas não-vazias (resposta executiva Plantão).\n"
    "//\n"
    "// NUNCA inventa conteúdo clínico. Apenas normaliza forma visual.\n"
    "// Executado APÓS todos os guards de segurança e ANTES do POST-STREAM LOCK.\n"
    "// ─────────────────────────────────────────────────────────────────────────────\n"
    "String _applyPlantaoAestheticGuard(String text) {\n"
    "  if (text.trim().isEmpty) return text;\n"
    "\n"
    "  // ── 1. Strip **bold** markers (preserve content between **) ─────────────\n"
    "  // Regex strips **anything** → anything throughout the text.\n"
    "  // Safe: only strips the ** wrappers, never the content.\n"
    "  var lines = text\n"
    "      .split('\\n')\n"
    "      .map((line) => line.replaceAllMapped(\n"
    "            RegExp(r'\\*\\*([^*]+)\\*\\*'),\n"
    "            (m) => m.group(1) ?? '',\n"
    "          ))\n"
    "      .toList();\n"
    "\n"
    "  // ── 2. ALLCAPS label → Title Case ────────────────────────────────────────\n"
    "  // Only matches standalone label tokens (WORD:) in all-caps.\n"
    "  // Preserves clinical acronyms (IAM, PCR, mg/kg…) that are mid-sentence.\n"
    "  const _kLabels = [\n"
    "    'DOSE', 'DOSAGEM', 'ALERTA', 'ALERTAS', 'ALTERNATIVA',\n"
    "    'CONDUTA', 'EVITAR', 'MONITORAR', 'MONITORAMENTO',\n"
    "    'CONTRAINDICACAO', 'CONTRAINDICAÇÕES', 'CONTRAINDICACION',\n"
    "    'DILUICAO', 'DILUIÇÃO', 'PREPARO', 'INFUSAO', 'INFUSÃO',\n"
    "    'TITULACAO', 'TITULAÇÃO', 'VELOCIDADE', 'CALCULO', 'CÁLCULO',\n"
    "    'INTERPRETACAO', 'INTERPRETAÇÃO', 'PROXIMO', 'PRÓXIMO',\n"
    "    'OBSERVAR', 'OBSERVACAO', 'OBSERVAÇÃO', 'VIGILAR',\n"
    "  ];\n"
    "  lines = lines.map((line) {\n"
    "    for (final label in _kLabels) {\n"
    "      if (line.contains('$label:')) {\n"
    "        final titled = label[0].toUpperCase() +\n"
    "            label.substring(1).toLowerCase();\n"
    "        line = line.replaceAll('$label:', '$titled:');\n"
    "      }\n"
    "    }\n"
    "    return line;\n"
    "  }).toList();\n"
    "\n"
    "  // ── 3. Teto de 12 linhas não-vazias ──────────────────────────────────────\n"
    "  const _kMaxLines = 12;\n"
    "  final nonEmpty = lines.where((l) => l.trim().isNotEmpty).length;\n"
    "  if (nonEmpty > _kMaxLines) {\n"
    "    int counted = 0;\n"
    "    final capped = <String>[];\n"
    "    for (final line in lines) {\n"
    "      capped.add(line);\n"
    "      if (line.trim().isNotEmpty) {\n"
    "        counted++;\n"
    "        if (counted >= _kMaxLines) break;\n"
    "      }\n"
    "    }\n"
    "    if (kDebugMode) {\n"
    "      debugPrint('[AESTHETIC_GUARD] line_cap: $nonEmpty → $_kMaxLines non-empty lines');\n"
    "    }\n"
    "    return capped.join('\\n').trimRight();\n"
    "  }\n"
    "\n"
    "  return lines.join('\\n');\n"
    "}\n"
    "\n"
    "// ─────────────────────────────────────────────────────────────────────────────\n"
    "// BUILD 248B — _plantaoTruncationGuard (ARQUITETURA CONSOLIDADA + REFORMATTER)\n"
)

assert M3B_ANCHOR in src, "ERRO M3b: helper anchor not found!"
assert src.count(M3B_ANCHOR) == 1, f"ERRO M3b: anchor appears {src.count(M3B_ANCHOR)} times (expected 1)"
src = src.replace(M3B_ANCHOR, M3B_REPLACEMENT, 1)
print(f"[M3b] _applyPlantaoAestheticGuard() helper inserted ✓  (src now {len(src)} bytes)")

# ══════════════════════════════════════════════════════════════════════════════
# MANDATO 2 — BACKGROUND RESTORE PARITY
# Pre-populates _plantaoPipelineCache for every AI message that looks like
# Plantão (contains 🟥) when a session is restored from history/background.
# Inserted after rebuildAiHistoryFromMessages call, before _scrollDown.
# ══════════════════════════════════════════════════════════════════════════════

M2_ANCHOR = (
    "    // Build 110 FIX: reconstrói _aiHistory a partir das mensagens restauradas.\n"
    "    // clearAiHistory() limpava o histórico sem repopular — a próxima mensagem\n"
    "    // enviada após restaurar uma sessão chegava ao Gemini sem nenhum contexto.\n"
    "    p.rebuildAiHistoryFromMessages(session.messages\n"
    "        .where((m) => m.role == 'user' || m.role == 'ai')\n"
    "        .map((m) => {\n"
    "              'role':    m.role == 'ai' ? 'assistant' : 'user',\n"
    "              'content': m.text,\n"
    "            })\n"
    "        .toList());\n"
    "    _scrollDown(force: true);\n"
    "  }\n"
)

M2_REPLACEMENT = (
    "    // Build 110 FIX: reconstrói _aiHistory a partir das mensagens restauradas.\n"
    "    // clearAiHistory() limpava o histórico sem repopular — a próxima mensagem\n"
    "    // enviada após restaurar uma sessão chegava ao Gemini sem nenhum contexto.\n"
    "    p.rebuildAiHistoryFromMessages(session.messages\n"
    "        .where((m) => m.role == 'user' || m.role == 'ai')\n"
    "        .map((m) => {\n"
    "              'role':    m.role == 'ai' ? 'assistant' : 'user',\n"
    "              'content': m.text,\n"
    "            })\n"
    "        .toList());\n"
    "\n"
    "    // ── SUPER ORDEM 41 M2: PARIDADE DE CACHE NA RESTAURAÇÃO ─────────────────\n"
    "    // Pré-popula _plantaoPipelineCache para cada mensagem AI no formato Plantão\n"
    "    // (âncora \U0001F7E5) antes do primeiro build() pós-restore. Garante paridade\n"
    "    // visual absoluta com o estado ao vivo: layout restaurado == layout do stream.\n"
    "    // Limpa cache da sessão anterior para evitar colisão de chaves stale.\n"
    "    _plantaoPipelineCache.clear();\n"
    "    for (final _rm in session.messages) {\n"
    "      if (_rm.role != 'ai') continue;\n"
    "      if (!_rm.text.contains('\U0001F7E5')) continue; // somente respostas Plantão\n"
    "      final _rk = '${_rm.id}:${_rm.text.hashCode}';\n"
    "      if (_plantaoPipelineCache.containsKey(_rk)) continue;\n"
    "      final _rr = PlantatoPipeline.run(_rm.text);\n"
    "      _plantaoPipelineCache[_rk] = _rr;\n"
    "      if (kDebugMode) {\n"
    "        debugPrint('[RESTORE_CACHE_PRIME] msgId=${_rm.id} '\n"
    "            'parsedOk=${_rr.response != null} '\n"
    "            'repaired=${_rr.repaired} '\n"
    "            'chars=${_rm.text.length}');\n"
    "      }\n"
    "    }\n"
    "\n"
    "    _scrollDown(force: true);\n"
    "  }\n"
)

assert M2_ANCHOR in src, "ERRO M2: anchor not found!"
assert src.count(M2_ANCHOR) == 1, f"ERRO M2: anchor appears {src.count(M2_ANCHOR)} times (expected 1)"
src = src.replace(M2_ANCHOR, M2_REPLACEMENT, 1)
print(f"[M2] Background restore cache prime inserted ✓  (src now {len(src)} bytes)")

# ── Final verification ─────────────────────────────────────────────────────────
# Count exact occurrences after all patches:
#   POST_STREAM_LOCK  → 1x in debugPrint string (the label inside the string)
#   RESTORE_CACHE_PRIME → 1x in debugPrint string
#   _applyPlantaoAestheticGuard → 3x: function def, call in if, comment header
#   AESTHETIC_GUARD → 1x in debugPrint label, 1x in comment header = 2 in helper + 1 in call section = 3
verifications = [
    ('POST_STREAM_LOCK',            1, 'M1 debugPrint label'),
    ('RESTORE_CACHE_PRIME',         1, 'M2 debugPrint label'),
    ('_applyPlantaoAestheticGuard', 3, 'M3 def+call+comment'),
    ('AESTHETIC_GUARD',             1, 'M3 debugPrint label'),
]
all_ok = True
for token, expected, label in verifications:
    count = src.count(token)
    ok = count == expected
    status = '✓' if ok else f'✗ EXPECTED {expected}'
    print(f"[VERIFY] {token}: {count} ({label}) {status}")
    if not ok:
        all_ok = False

if not all_ok:
    print("ERROR: verification failed — file NOT written")
    raise SystemExit(1)

with open(FILE, 'w', encoding='utf-8') as f:
    f.write(src)

added = len(src) - original_len
print(f"\n[DONE] {FILE} written. {len(src)} bytes (+{added}). All mandates applied. ✓")
