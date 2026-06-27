#!/usr/bin/env python3
# ordem45.py — ORDEM MASTER 45: PROTOCOLO MOSAICO INDUSTRIAL
# Targets: lib/screens/home_screen.dart
#
# Changes:
#   1. Vertical gaps between card blocks: 8/12 → 4px (esmagamento soberano)
#   2. Horizontal gap inside twin-card rows: 12 → 4px
#   3. Border radii on all dashboard cards: 16/18/20 → 8px (mosaico industrial)

TARGET = 'lib/screens/home_screen.dart'

with open(TARGET, 'r', encoding='utf-8') as f:
    src = f.read()

original = src

# ─────────────────────────────────────────────────────────────────────────────
# 1a. Gap after _HomeInlineChat (IA chat card): height 8 → 4
# ─────────────────────────────────────────────────────────────────────────────
OLD_1A = '''          _HomeInlineChat(
            dark: dark,
            isEs: isEs,
            onNavigateToAi: widget.onTabChange,
          ),
          const SizedBox(height: 8),  // ORDEM 12: compactado

          // ── LINHA 1: CALCULADORA E FÁRMACOS — card unificado full-width ─────'''

NEW_1A = '''          _HomeInlineChat(
            dark: dark,
            isEs: isEs,
            onNavigateToAi: widget.onTabChange,
          ),
          const SizedBox(height: 4),  // ORDEM 45: esmagamento soberano 8→4

          // ── LINHA 1: CALCULADORA E FÁRMACOS — card unificado full-width ─────'''

assert OLD_1A in src, "1A anchor (gap after InlineChat) NOT FOUND"
src = src.replace(OLD_1A, NEW_1A, 1)
print("[1A] Gap after InlineChat: 8→4 ✓")

# ─────────────────────────────────────────────────────────────────────────────
# 1b. Gap after _HomeCalculadoraFarmacosCard: height 12 → 4
# ─────────────────────────────────────────────────────────────────────────────
OLD_1B = '''          // ── LINHA 1: CALCULADORA E FÁRMACOS — card unificado full-width ─────
          _HomeCalculadoraFarmacosCard(dark: dark, isEs: isEs),
          const SizedBox(height: 12),  // ORDEM 43: 8→12 gap vertical premium

          // ── LINHA 2: ADULTO + PEDIATRÍA — dois cards paralelos ──────────────'''

NEW_1B = '''          // ── LINHA 1: CALCULADORA E FÁRMACOS — card unificado full-width ─────
          _HomeCalculadoraFarmacosCard(dark: dark, isEs: isEs),
          const SizedBox(height: 4),  // ORDEM 45: mosaico 12→4

          // ── LINHA 2: ADULTO + PEDIATRÍA — dois cards paralelos ──────────────'''

assert OLD_1B in src, "1B anchor (gap after Calculadora card) NOT FOUND"
src = src.replace(OLD_1B, NEW_1B, 1)
print("[1B] Gap after CalculadoraFarmacos: 12→4 ✓")

# ─────────────────────────────────────────────────────────────────────────────
# 1c. Gap after _HomeAdultoPediatriaRow: height 12 → 4
# ─────────────────────────────────────────────────────────────────────────────
OLD_1C = '''          const SizedBox(height: 12),  // ORDEM 43: 8→12 gap vertical premium

          // ── LINHA 3: BIBLIOTECA + H. CLÍNICA — dois cards paralelos ─────────'''

NEW_1C = '''          const SizedBox(height: 4),  // ORDEM 45: mosaico 12→4

          // ── LINHA 3: BIBLIOTECA + H. CLÍNICA — dois cards paralelos ─────────'''

assert OLD_1C in src, "1C anchor (gap after AdultoPediatria row) NOT FOUND"
src = src.replace(OLD_1C, NEW_1C, 1)
print("[1C] Gap after AdultoPediatria row: 12→4 ✓")

# ─────────────────────────────────────────────────────────────────────────────
# 1d. Gap after _HomeBibliotecaHClinicaRow: height 12 → 4
# ─────────────────────────────────────────────────────────────────────────────
OLD_1D = '''          const SizedBox(height: 12),  // ORDEM 43: 8→12 gap vertical premium

          // ── QUICK ACCESS BAR — BUSCAR | NOTAS | RECIENTES | FAVORITOS | EVAL ─'''

NEW_1D = '''          const SizedBox(height: 4),  // ORDEM 45: mosaico 12→4

          // ── QUICK ACCESS BAR — BUSCAR | NOTAS | RECIENTES | FAVORITOS | EVAL ─'''

assert OLD_1D in src, "1D anchor (gap after BibliotecaHClinica row) NOT FOUND"
src = src.replace(OLD_1D, NEW_1D, 1)
print("[1D] Gap after BibliotecaHClinica row: 12→4 ✓")

# ─────────────────────────────────────────────────────────────────────────────
# 2a. _HomeAdultoPediatriaRow horizontal gap: width 12 → 4
# ─────────────────────────────────────────────────────────────────────────────
OLD_2A = '''      const SizedBox(width: 12),  // ORDEM 43: 10→12 gap horizontal cards
      // B144: Azul Petróleo — dark teal elegante, nunca chega ao ciano
      Expanded(child: _AgeCard(
        icon: Icons.child_care_rounded,
        label: isEs ? 'PEDIATRÍA' : 'PEDIATRIA','''

NEW_2A = '''      const SizedBox(width: 4),  // ORDEM 45: mosaico 12→4 gap horizontal
      // B144: Azul Petróleo — dark teal elegante, nunca chega ao ciano
      Expanded(child: _AgeCard(
        icon: Icons.child_care_rounded,
        label: isEs ? 'PEDIATRÍA' : 'PEDIATRIA','''

assert OLD_2A in src, "2A anchor (AdultoPediatria horizontal gap) NOT FOUND"
src = src.replace(OLD_2A, NEW_2A, 1)
print("[2A] AdultoPediatria row horizontal gap: 12→4 ✓")

# ─────────────────────────────────────────────────────────────────────────────
# 2b. _HomeBibliotecaHClinicaRow horizontal gap: width 12 → 4
# ─────────────────────────────────────────────────────────────────────────────
OLD_2B = '''      const SizedBox(width: 12),  // ORDEM 43: 10→12 gap horizontal cards
      // ── H. CLÍNICA — B141: Orange Vibrant #ea580c → #fb923c ─────────────'''

NEW_2B = '''      const SizedBox(width: 4),  // ORDEM 45: mosaico 12→4 gap horizontal
      // ── H. CLÍNICA — B141: Orange Vibrant #ea580c → #fb923c ─────────────'''

assert OLD_2B in src, "2B anchor (BibliotecaHClinica horizontal gap) NOT FOUND"
src = src.replace(OLD_2B, NEW_2B, 1)
print("[2B] BibliotecaHClinica row horizontal gap: 12→4 ✓")

# ─────────────────────────────────────────────────────────────────────────────
# 3a. _AgeCard (4 grid cards — PACIENTE/PEDIATRIA/BIBLIOTECA/H.CLÍNICA)
#     borderRadius: circular(16) → circular(8)
# ─────────────────────────────────────────────────────────────────────────────
OLD_3A = '''          height: 92,  // ORDEM 43: +10% altura premium (84×1.10=92.4→92)
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: g,
            ),
            borderRadius: BorderRadius.circular(16),  // ORDEM 12: radius slim (era 18)'''

NEW_3A = '''          height: 92,  // ORDEM 43: +10% altura premium (84×1.10=92.4→92)
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: g,
            ),
            borderRadius: BorderRadius.circular(8),  // ORDEM 45: mosaico industrial'''

assert OLD_3A in src, "3A anchor (_AgeCard borderRadius 16) NOT FOUND"
src = src.replace(OLD_3A, NEW_3A, 1)
print("[3A] _AgeCard borderRadius: 16→8 ✓")

# ─────────────────────────────────────────────────────────────────────────────
# 3b. _HomeCalculadoraFarmacosCard (mobile purple card)
#     borderRadius: circular(16) → circular(8)
# ─────────────────────────────────────────────────────────────────────────────
OLD_3B = '''          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),  // ORDEM 43: 14→16 (+14% impacto visual ≈ 108%)
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end:   Alignment.bottomRight,
              colors: gradientColors,
            ),
            borderRadius: BorderRadius.circular(16),  // ORDEM 12: radius slim'''

NEW_3B = '''          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),  // ORDEM 43: 14→16 (+14% impacto visual ≈ 108%)
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end:   Alignment.bottomRight,
              colors: gradientColors,
            ),
            borderRadius: BorderRadius.circular(8),  // ORDEM 45: mosaico industrial'''

assert OLD_3B in src, "3B anchor (_HomeCalculadoraFarmacosCard borderRadius 16) NOT FOUND"
src = src.replace(OLD_3B, NEW_3B, 1)
print("[3B] _HomeCalculadoraFarmacosCard borderRadius: 16→8 ✓")

# ─────────────────────────────────────────────────────────────────────────────
# 3c. _HomeInlineChat main container
#     BorderRadius.all(Radius.circular(20)) → circular(8)
# ─────────────────────────────────────────────────────────────────────────────
OLD_3C = '''    // SUPER ORDEM 11: Dark Graphite imersivo — paridade total com AiScreen
    return Container(
      decoration: const BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.all(Radius.circular(20)),'''

NEW_3C = '''    // SUPER ORDEM 11: Dark Graphite imersivo — paridade total com AiScreen
    return Container(
      decoration: const BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.all(Radius.circular(8)),  // ORDEM 45: mosaico'''

assert OLD_3C in src, "3C anchor (_HomeInlineChat borderRadius all(20)) NOT FOUND"
src = src.replace(OLD_3C, NEW_3C, 1)
print("[3C] _HomeInlineChat borderRadius: all(20)→all(8) ✓")

# ─────────────────────────────────────────────────────────────────────────────
# 3d. _HomeCard (desktop grid) borderRadius: circular(18) → circular(8)
# ─────────────────────────────────────────────────────────────────────────────
OLD_3D = '''          height: 101,  // ORDEM 43: 92→101 (+10% proporção premium)
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),'''

NEW_3D = '''          height: 101,  // ORDEM 43: 92→101 (+10% proporção premium)
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),  // ORDEM 45: mosaico industrial'''

assert OLD_3D in src, "3D anchor (_HomeCard desktop borderRadius 18) NOT FOUND"
src = src.replace(OLD_3D, NEW_3D, 1)
print("[3D] _HomeCard (desktop) borderRadius: 18→8 ✓")

# ─────────────────────────────────────────────────────────────────────────────
# 3e. _HomeCalculadoraCard (desktop old purple card) borderRadius: circular(18) → circular(8)
# ─────────────────────────────────────────────────────────────────────────────
OLD_3E = '''          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end:   Alignment.bottomRight,
              colors: gradientColors,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: gradientColors.last.withValues(alpha: 0.40),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(children: [
            // ── Ícone ──────────────────────────────────────────────────────
            Container(
              width: 52, height: 52,'''

NEW_3E = '''          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end:   Alignment.bottomRight,
              colors: gradientColors,
            ),
            borderRadius: BorderRadius.circular(8),  // ORDEM 45: mosaico industrial
            boxShadow: [
              BoxShadow(
                color: gradientColors.last.withValues(alpha: 0.40),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(children: [
            // ── Ícone ──────────────────────────────────────────────────────
            Container(
              width: 52, height: 52,'''

assert OLD_3E in src, "3E anchor (_HomeCalculadoraCard desktop borderRadius 18) NOT FOUND"
src = src.replace(OLD_3E, NEW_3E, 1)
print("[3E] _HomeCalculadoraCard (desktop) borderRadius: 18→8 ✓")

# ─────────────────────────────────────────────────────────────────────────────
# Write output
# ─────────────────────────────────────────────────────────────────────────────
with open(TARGET, 'w', encoding='utf-8') as f:
    f.write(src)

changed = sum(1 for a, b in zip(original.splitlines(), src.splitlines()) if a != b)
print(f"\n[ORDEM45] Patch complete — {len(src)} chars, ~{changed} lines changed.")
print("Mandates applied:")
print("  ✓ 1A: Gap after InlineChat: 8→4")
print("  ✓ 1B: Gap after Calculadora card: 12→4")
print("  ✓ 1C: Gap after AdultoPediatria row: 12→4")
print("  ✓ 1D: Gap after BibliotecaHClinica row: 12→4")
print("  ✓ 2A: AdultoPediatria horizontal gap: 12→4")
print("  ✓ 2B: BibliotecaHClinica horizontal gap: 12→4")
print("  ✓ 3A: _AgeCard borderRadius: 16→8")
print("  ✓ 3B: _HomeCalculadoraFarmacosCard borderRadius: 16→8")
print("  ✓ 3C: _HomeInlineChat borderRadius: all(20)→all(8)")
print("  ✓ 3D: _HomeCard (desktop) borderRadius: 18→8")
print("  ✓ 3E: _HomeCalculadoraCard (desktop) borderRadius: 18→8")
