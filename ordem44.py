#!/usr/bin/env python3
# ordem44.py — ORDEM MASTER 44: Toggle, TopBar, Auth Lock, JIT Pipeline
# Targets: lib/screens/ai_screen.dart
#
# M1: Toggle condition: _messages.isEmpty → !hasUserMessages
# M2: TopBar title fontSize: 18 → 15.5 (−14.4% ≈ −15%)
# M3: Auth barrier condition: _messages.isEmpty → !hasUserMessages (parity with M1)
# M4: JIT pipeline — extend trigger to cover ALL 🟥 historical AI bubbles

TARGET = 'lib/screens/ai_screen.dart'

with open(TARGET, 'r', encoding='utf-8') as f:
    src = f.read()

original = src

# ─────────────────────────────────────────────────────────────────────────────
# M1: _ResponseModeToggle visibility gate
# Change: if (!forceDisconnectedLabel && _messages.isEmpty)
# To:     if (!forceDisconnectedLabel && !hasUserMessages)
# With:   final bool hasUserMessages = _messages.any((m) => m.role == 'user');
#         declared just before the toggle condition.
# ─────────────────────────────────────────────────────────────────────────────

OLD_M1 = '''      // ── ORDEM 36: Seletor de modo flutuante — fixo acima do InputBar ────────
      // 25px acima da barra de digitação. Visível apenas com chat vazio.
      // SUPER ORDEM 42 M3: some no milissegundo em que chega a primeira mensagem.
      if (!forceDisconnectedLabel && _messages.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 0),
          child: _ResponseModeToggle('''

NEW_M1 = '''      // ── ORDEM 36: Seletor de modo flutuante — fixo acima do InputBar ────────
      // ORDEM 44 M1: visível enquanto NÃO há mensagens do médico na sessão.
      // Aparece mesmo com greeting de boas-vindas — desaparece no 1º envio.
      // hasUserMessages = qualquer msg com role=='user' (exclui greeting AI).
      if (!forceDisconnectedLabel &&
          !_messages.any((m) => m.role == 'user'))
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 0),
          child: _ResponseModeToggle('''

assert OLD_M1 in src, "M1 anchor (_ResponseModeToggle condition) NOT FOUND"
src = src.replace(OLD_M1, NEW_M1, 1)
print("[M1] Toggle condition: _messages.isEmpty → !any(role==user) ✓")

# ─────────────────────────────────────────────────────────────────────────────
# M2: TopBar title fontSize 18 → 15.5 (−15%)
# Both TextSpans in the RichText ("MEDCASES" and " IA") use fontSize: 18
# ─────────────────────────────────────────────────────────────────────────────

OLD_M2 = '''                RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(
                        text: 'MEDCASES',
                        style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700,
                          color: Colors.white, letterSpacing: -0.2,
                        ),
                      ),
                      TextSpan(
                        text: ' IA',
                        style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700,
                          color: Color(0xFFD4AF37), letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),'''

NEW_M2 = '''                RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(
                        text: 'MEDCASES',
                        style: TextStyle(
                          // ORDEM 44 M2: 18→15.5 (−15%) — elegância minimalista
                          fontSize: 15.5, fontWeight: FontWeight.w700,
                          color: Colors.white, letterSpacing: -0.2,
                        ),
                      ),
                      TextSpan(
                        text: ' IA',
                        style: TextStyle(
                          fontSize: 15.5, fontWeight: FontWeight.w700,
                          color: Color(0xFFD4AF37), letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),'''

assert OLD_M2 in src, "M2 anchor (TopBar RichText fontSize:18) NOT FOUND"
src = src.replace(OLD_M2, NEW_M2, 1)
print("[M2] TopBar title fontSize 18→15.5 (−15%) ✓")

# ─────────────────────────────────────────────────────────────────────────────
# M3: Auth barrier condition parity with M1
# Change: if (forceDisconnectedLabel && _messages.isEmpty)
# To:     if (forceDisconnectedLabel && !_messages.any((m) => m.role == 'user'))
# ─────────────────────────────────────────────────────────────────────────────

OLD_M3 = '''            // SUPER ORDEM 42 M4: Google Auth Barrier — card proeminente quando
            // usuário não-autenticado tenta usar a IA (chat vazio + desconectado).
            // Substitui o WiFi-off _EmptyChat para não-privilegiados sem conta.
            if (forceDisconnectedLabel && _messages.isEmpty)
              _GoogleAuthBarrierCard('''

NEW_M3 = '''            // SUPER ORDEM 42 M4 / ORDEM 44 M3: Google Auth Barrier — card proeminente
            // quando usuário não-autenticado tenta usar a IA.
            // ORDEM 44: condição pareia com toggle — desaparece no 1º envio do médico.
            if (forceDisconnectedLabel &&
                !_messages.any((m) => m.role == 'user'))
              _GoogleAuthBarrierCard('''

assert OLD_M3 in src, "M3 anchor (Auth barrier condition) NOT FOUND"
src = src.replace(OLD_M3, NEW_M3, 1)
print("[M3] Auth barrier condition: _messages.isEmpty → !any(role==user) ✓")

# ─────────────────────────────────────────────────────────────────────────────
# M4: JIT Pipeline — extend trigger to ALL 🟥 historical Plantão bubbles
#
# Current isPlantaoFinalBubble: requires i == _lastAiIndex (only last bubble).
# Problem: historical bubbles with 🟥 rendered via _AiBubble on restore.
# Fix: add `looksLikePlantaoBubble` sentinel that fires for ANY AI bubble
#      containing 🟥 in Plantão mode (!_longResponse), even if not the last.
#      This piggybacks on the existing cache+JIT block below without changing
#      the structural renderer gate (still requires final bubble or bula guard).
#
# The architectural fix is:
#   1. Add `looksLikePlantaoBubble` = !_longResponse && !_isStreaming &&
#      !_isSafeCard && msg.text.contains('🟥') AND i != _lastAiIndex
#      (historical bubbles only — last bubble already handled by isPlantaoFinalBubble)
#   2. When looksLikePlantaoBubble: run JIT pipeline + cache (same block)
#      but render via _PlantaoRenderer if pipeline succeeds (historical bubbles
#      also deserve structured rendering in Plantão mode).
#   3. Merge looksLikePlantaoBubble into the existing OR conditions for the
#      pipeline block — zero duplication.
# ─────────────────────────────────────────────────────────────────────────────

OLD_M4_GATE = '''              final bool isPlantaoFinalBubble =
                  !_longResponse &&          // Modo Plantão ativo
                  i == _lastAiIndex &&       // última bolha AI
                  !_isStreaming &&            // stream finalizado
                  !_isSafeCard;             // BUILD 244B: safe-card → bypass renderer'''

NEW_M4_GATE = '''              final bool isPlantaoFinalBubble =
                  !_longResponse &&          // Modo Plantão ativo
                  i == _lastAiIndex &&       // última bolha AI
                  !_isStreaming &&            // stream finalizado
                  !_isSafeCard;             // BUILD 244B: safe-card → bypass renderer

              // ── ORDEM 44 M4: looksLikePlantaoBubble — JIT retroativo ─────────
              // Dispara para TODAS as bolhas históricas do Plantão que contêm 🟥
              // mas NÃO são a última bolha (já coberta por isPlantaoFinalBubble).
              // Garante paridade visual pós-background: mesmo layout que o stream ativo.
              // Pipeline JIT síncrono no itemBuilder — resultado cacheado imediatamente.
              final bool looksLikePlantaoBubble =
                  !_longResponse &&          // Modo Plantão ativo
                  i != _lastAiIndex &&       // bolha histórica (não a última)
                  !_isStreaming &&            // fora de stream ativo
                  !_isSafeCard &&            // não é safe-card de fallback
                  msg.text.contains('\U0001F7E5'); // contém 🟥 — estrutura Plantão confirmada'''

assert OLD_M4_GATE in src, "M4 anchor (isPlantaoFinalBubble definition) NOT FOUND"
src = src.replace(OLD_M4_GATE, NEW_M4_GATE, 1)
print("[M4a] looksLikePlantaoBubble sentinel added ✓")

# Now extend the pipeline trigger to include looksLikePlantaoBubble
OLD_M4_PIPE = '''              PlantatoPipelineResult? plantaoPipelineResult;
              if (isPlantaoFinalBubble || looksLikePharmaBula) {'''

NEW_M4_PIPE = '''              PlantatoPipelineResult? plantaoPipelineResult;
              // ORDEM 44 M4: looksLikePlantaoBubble added to JIT pipeline trigger
              if (isPlantaoFinalBubble || looksLikePharmaBula || looksLikePlantaoBubble) {'''

assert OLD_M4_PIPE in src, "M4 anchor (pipeline trigger OR condition) NOT FOUND"
src = src.replace(OLD_M4_PIPE, NEW_M4_PIPE, 1)
print("[M4b] JIT pipeline trigger extended to looksLikePlantaoBubble ✓")

# Extend the useStructuredRenderer gate to include looksLikePlantaoBubble
OLD_M4_RENDER = '''              final bool useStructuredRenderer =
                  (isPlantaoFinalBubble || looksLikePharmaBula) &&
                  plantaoPipelineResult?.response != null;'''

NEW_M4_RENDER = '''              // ORDEM 44 M4: historical Plantão bubbles also use structured renderer
              final bool useStructuredRenderer =
                  (isPlantaoFinalBubble || looksLikePharmaBula || looksLikePlantaoBubble) &&
                  plantaoPipelineResult?.response != null;'''

assert OLD_M4_RENDER in src, "M4 anchor (useStructuredRenderer gate) NOT FOUND"
src = src.replace(OLD_M4_RENDER, NEW_M4_RENDER, 1)
print("[M4c] useStructuredRenderer gate extended to looksLikePlantaoBubble ✓")

# Also extend the PlantaoFallbackCard gate for looksLikePlantaoBubble
OLD_M4_FALLBACK = '''                    else if (isPlantaoFinalBubble || looksLikePharmaBula)
                      _PlantaoFallbackCard('''

NEW_M4_FALLBACK = '''                    // ORDEM 44 M4: historical Plantão bubbles also degrade gracefully
                    else if (isPlantaoFinalBubble || looksLikePharmaBula || looksLikePlantaoBubble)
                      _PlantaoFallbackCard('''

assert OLD_M4_FALLBACK in src, "M4 anchor (PlantaoFallbackCard gate) NOT FOUND"
src = src.replace(OLD_M4_FALLBACK, NEW_M4_FALLBACK, 1)
print("[M4d] PlantaoFallbackCard gate extended to looksLikePlantaoBubble ✓")

# ─────────────────────────────────────────────────────────────────────────────
# Write output
# ─────────────────────────────────────────────────────────────────────────────
with open(TARGET, 'w', encoding='utf-8') as f:
    f.write(src)

changed = sum(1 for a, b in zip(original.splitlines(), src.splitlines()) if a != b)
print(f"\n[ORDEM44] Patch complete — {len(src)} chars, ~{changed} lines changed.")
print("Mandates applied:")
print("  ✓ M1: Toggle: _messages.isEmpty → !any(role==user) — shows with AI greeting")
print("  ✓ M2: TopBar fontSize 18→15.5 (−15% elegância minimalista)")
print("  ✓ M3: Auth barrier parity: same hasUserMessages gate as toggle")
print("  ✓ M4: JIT pipeline: looksLikePlantaoBubble covers ALL 🟥 historical bubbles")
