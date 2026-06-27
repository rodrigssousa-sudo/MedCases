#!/usr/bin/env python3
# ordem42.py — SUPER ORDEM MASTER 42: UI Facelift Pipeline
# Five mandates: M1 TopBar, M2 Bubble Geometry, M3 Toggle Lifecycle,
#                M4 Google Auth Barrier, M5 handled separately (flutter commands)

import sys

TARGET = 'lib/screens/ai_screen.dart'

with open(TARGET, 'r', encoding='utf-8') as f:
    src = f.read()

original = src  # keep for diff count

# ─────────────────────────────────────────────────────────────────────────────
# M1: TopBar Facelift
# Remove "MEDCASES PRO" subtitle (SizedBox(height:1) + RichText block)
# Add Positioned(left:14) with M+ gold text logo
# ─────────────────────────────────────────────────────────────────────────────

OLD_M1_SUBTITLE = '''                const SizedBox(height: 1),
                RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(
                        text: 'MEDCASES',
                        style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.bold,
                          color: Colors.white, letterSpacing: 1.2,
                        ),
                      ),
                      TextSpan(
                        text: ' PRO',
                        style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.bold,
                          color: Color(0xFFD4AF37), letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),'''

NEW_M1_SUBTITLE = ''  # Remove completely

assert OLD_M1_SUBTITLE in src, "M1 anchor (subtitle block) NOT FOUND"
src = src.replace(OLD_M1_SUBTITLE, NEW_M1_SUBTITLE, 1)
print("[M1a] Removed 'MEDCASES PRO' subtitle block ✓")

# Add M+ Positioned(left:14) BEFORE the trailing Positioned(right:14)
OLD_M1_TRAILING = '''          // ── Trailing: dark container com history + add ──────────────────
          Positioned(
            right: 14,'''

NEW_M1_TRAILING = '''          // ── Leading: M+ logo dourado — assinatura premium ───────────────
          Positioned(
            left: 14,
            child: Text(
              'M+',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFFD4AF37).withValues(alpha: 0.72),
                letterSpacing: -0.5,
              ),
            ),
          ),

          // ── Trailing: dark container com history + add ──────────────────
          Positioned(
            right: 14,'''

assert OLD_M1_TRAILING in src, "M1 anchor (trailing Positioned) NOT FOUND"
src = src.replace(OLD_M1_TRAILING, NEW_M1_TRAILING, 1)
print("[M1b] Added M+ gold Positioned(left:14) logo ✓")

# ─────────────────────────────────────────────────────────────────────────────
# M2: Bubble Geometry
# USER BUBBLE outer padding: only(bottom:6, left:52) → symmetric(horizontal:12)
# USER BUBBLE inner container padding: symmetric(horizontal:13,vertical:9) → all(8)
# AI BUBBLE (_AiBlockBubble) outer Padding: only(bottom: isLast?8:4, right:16) → symmetric(horizontal:12) + bottom
# ─────────────────────────────────────────────────────────────────────────────

# M2a: _UserBubble outer wrapper padding
OLD_M2_USER_OUTER = '''    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 52),
      child: Align(
        alignment: Alignment.centerRight,'''

NEW_M2_USER_OUTER = '''    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Align(
        alignment: Alignment.centerRight,'''

assert OLD_M2_USER_OUTER in src, "M2a anchor (_UserBubble outer padding) NOT FOUND"
src = src.replace(OLD_M2_USER_OUTER, NEW_M2_USER_OUTER, 1)
print("[M2a] _UserBubble outer padding → horizontal:12 ✓")

# M2b: _UserBubble inner bubble container padding (normal mode, the teal bubble)
OLD_M2_USER_INNER = '''                  child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                      decoration: const BoxDecoration(
                        borderRadius: borderRadius,
                        color: Color(0xFF008CA4),
                      ),'''

NEW_M2_USER_INNER = '''                  child: Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: const BoxDecoration(
                        borderRadius: borderRadius,
                        color: Color(0xFF008CA4),
                      ),'''

assert OLD_M2_USER_INNER in src, "M2b anchor (_UserBubble inner padding) NOT FOUND"
src = src.replace(OLD_M2_USER_INNER, NEW_M2_USER_INNER, 1)
print("[M2b] _UserBubble inner bubble padding → all(8.0) ✓")

# M2c: _AiBlockBubble outer Padding (the return Padding at top of build)
OLD_M2_AI_OUTER = '''    return Padding(
      padding: EdgeInsets.only(
        bottom: isLast ? 8 : 4,
        right: 16,
      ),
      child: Align(
        alignment: Alignment.centerLeft,'''

NEW_M2_AI_OUTER = '''    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.0).copyWith(
        bottom: isLast ? 8 : 4,
      ),
      child: Align(
        alignment: Alignment.centerLeft,'''

assert OLD_M2_AI_OUTER in src, "M2c anchor (_AiBlockBubble outer padding) NOT FOUND"
src = src.replace(OLD_M2_AI_OUTER, NEW_M2_AI_OUTER, 1)
print("[M2c] _AiBlockBubble outer padding → horizontal:12 + bottom ✓")

# ─────────────────────────────────────────────────────────────────────────────
# M3: Toggle Lifecycle Dismiss
# Change: if (!forceDisconnectedLabel)
# To:     if (!forceDisconnectedLabel && _messages.isEmpty)
# ─────────────────────────────────────────────────────────────────────────────

OLD_M3 = '''      // ── ORDEM 36: Seletor de modo flutuante — fixo acima do InputBar ────────
      // 25px acima da barra de digitação. Visível com ou sem mensagens.
      // Oculto apenas quando forceDisconnectedLabel=true.
      if (!forceDisconnectedLabel)'''

NEW_M3 = '''      // ── ORDEM 36: Seletor de modo flutuante — fixo acima do InputBar ────────
      // 25px acima da barra de digitação. Visível apenas com chat vazio.
      // SUPER ORDEM 42 M3: some no milissegundo em que chega a primeira mensagem.
      if (!forceDisconnectedLabel && _messages.isEmpty)'''

assert OLD_M3 in src, "M3 anchor (toggle condition) NOT FOUND"
src = src.replace(OLD_M3, NEW_M3, 1)
print("[M3] _ResponseModeToggle now gated by _messages.isEmpty ✓")

# ─────────────────────────────────────────────────────────────────────────────
# M4: Google Auth Barrier Card
# When forceDisconnectedLabel && _messages.isEmpty, show prominent Google auth
# card instead of / on top of the WiFi-off _EmptyChat overlay.
# Implementation: replace the existing `if (showDisconnectCard) _EmptyChat(...)`
# with a conditional that:
#   - if forceDisconnectedLabel && empty → _GoogleAuthBarrierCard
#   - elif showDisconnectCard → _EmptyChat (unchanged)
#
# Then add _GoogleAuthBarrierCard class before _SuggestionCarousel
# ─────────────────────────────────────────────────────────────────────────────

OLD_M4_STACK = '''            // Card "IA Desconectada" — sobreposto quando IA não está conectada
            // e o médico ainda não enviou nenhuma mensagem
            if (showDisconnectCard)
              _EmptyChat(
                dark: dark,
                lang: p.lang,
                isConnected: false,
                onConnectApi: _openAiSettings,
              ),'''

NEW_M4_STACK = '''            // SUPER ORDEM 42 M4: Google Auth Barrier — card proeminente quando
            // usuário não-autenticado tenta usar a IA (chat vazio + desconectado).
            // Substitui o WiFi-off _EmptyChat para não-privilegiados sem conta.
            if (forceDisconnectedLabel && _messages.isEmpty)
              _GoogleAuthBarrierCard(
                dark: dark,
                lang: p.lang,
                onConnect: _openAiSettings,
              )
            // Card "IA Desconectada" — sobreposto quando IA não está conectada
            // e o médico ainda não enviou nenhuma mensagem (usuário privilegiado)
            else if (showDisconnectCard)
              _EmptyChat(
                dark: dark,
                lang: p.lang,
                isConnected: false,
                onConnectApi: _openAiSettings,
              ),'''

assert OLD_M4_STACK in src, "M4 anchor (stack disconnect card) NOT FOUND"
src = src.replace(OLD_M4_STACK, NEW_M4_STACK, 1)
print("[M4a] Stack: Google Auth Barrier card injected ✓")

# Add _GoogleAuthBarrierCard class before _SuggestionCarousel
OLD_M4_CLASS_ANCHOR = '''// ─────────────────────────────────────────────────────────────────────────────
// Carrossel horizontal de sugestões
// ─────────────────────────────────────────────────────────────────────────────
class _SuggestionCarousel extends StatelessWidget {'''

NEW_M4_CLASS_ANCHOR = '''// ─────────────────────────────────────────────────────────────────────────────
// _GoogleAuthBarrierCard — SUPER ORDEM 42 M4
// Card proeminente centralizado para usuários não autenticados.
// Exibido quando forceDisconnectedLabel=true && _messages.isEmpty.
// Substitui o WiFi-off overlay com CTA de Google Sign-In.
// ─────────────────────────────────────────────────────────────────────────────
class _GoogleAuthBarrierCard extends StatelessWidget {
  final bool dark;
  final String lang;
  final VoidCallback? onConnect;
  const _GoogleAuthBarrierCard({
    required this.dark,
    required this.lang,
    this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    final isEs = lang == 'es';
    final cardBg = dark
        ? const Color(0xFF1E2128)
        : Colors.white;
    final borderColor = dark
        ? const Color(0xFF2D3340)
        : const Color(0xFFE5E0D8);
    final titleColor = dark ? Colors.white : const Color(0xFF1A1D23);
    final subtitleColor = dark
        ? Colors.white.withValues(alpha: 0.55)
        : Colors.black.withValues(alpha: 0.45);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28.0),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.40 : 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Google logo icon ─────────────────────────────────────────
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dark
                      ? const Color(0xFF252930)
                      : const Color(0xFFF5F3EE),
                  border: Border.all(
                    color: borderColor,
                    width: 1.0,
                  ),
                ),
                child: const Center(
                  child: Text(
                    'G',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4285F4), // Google blue
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Headline ─────────────────────────────────────────────────
              Text(
                isEs
                    ? 'Conecta tu cuenta Google'
                    : 'Conecte sua conta Google',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: titleColor,
                  letterSpacing: -0.3,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),

              // ── Subtitle / value prop ─────────────────────────────────────
              Text(
                isEs
                    ? 'para activar la Inteligencia Artificial Gratuita'
                    : 'para ativar a Inteligência Artificial Gratuita',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: subtitleColor,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),

              // ── CTA Button ───────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onConnect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4285F4),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '\U0001F511',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isEs
                            ? 'Conectar con Google'
                            : 'Conectar com o Google',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Carrossel horizontal de sugestões
// ─────────────────────────────────────────────────────────────────────────────
class _SuggestionCarousel extends StatelessWidget {'''

assert OLD_M4_CLASS_ANCHOR in src, "M4 class anchor (before _SuggestionCarousel) NOT FOUND"
src = src.replace(OLD_M4_CLASS_ANCHOR, NEW_M4_CLASS_ANCHOR, 1)
print("[M4b] _GoogleAuthBarrierCard class injected before _SuggestionCarousel ✓")

# ─────────────────────────────────────────────────────────────────────────────
# Write patched file
# ─────────────────────────────────────────────────────────────────────────────

with open(TARGET, 'w', encoding='utf-8') as f:
    f.write(src)

changed = sum(1 for a, b in zip(original.splitlines(), src.splitlines()) if a != b)
print(f"\n[ORDEM42] Patch complete — {len(src)} chars written, ~{changed} lines changed.")
print("Mandates applied:")
print("  ✓ M1: TopBar facelift (PRO subtitle removed, M+ gold logo added)")
print("  ✓ M2: Bubble geometry (horizontal:12 outer, all(8) inner)")
print("  ✓ M3: Toggle lifecycle (gated by _messages.isEmpty)")
print("  ✓ M4: Google Auth Barrier card (_GoogleAuthBarrierCard class)")
