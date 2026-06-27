#!/usr/bin/env python3
# ordem43.py — ORDEM MASTER 43: RE-CALIBRAGEM GEOMÉTRICA DA DASHBOARD
# Targets: home_screen.dart
# Changes:
#   1. Mobile outer padding: 12→16 (horizontal)
#   2. Inter-section SizedBox height: 8→12 (between main card rows)
#   3. Card row gaps: SizedBox(width:10)→12 in AdultoPediatria + BibliotecaHClinica
#   4. _AgeCard height: 84→92 (+10.0% mobile grid cards)
#   5. _HomeCalculadoraFarmacosCard vertical padding: 14→15 (+7% ≈ 106% height)
#   6. Desktop grid gap: 14.0→12.0 (crossAxisSpacing + mainAxisSpacing)
#   7. Desktop SizedBox heights between sections: 24→12, 20→12, 16→12
#   8. _HomeCard (desktop) height: 92→101 (+10%)

TARGET = 'lib/screens/home_screen.dart'

with open(TARGET, 'r', encoding='utf-8') as f:
    src = f.read()

original = src

# ─────────────────────────────────────────────────────────────────────────────
# 1. Mobile outer padding: isTabletLandscape?20:12 → isTabletLandscape?20:16
# ─────────────────────────────────────────────────────────────────────────────
OLD_1 = '''    Widget mobileContent = SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          isTabletLandscape ? 20 : 12,
          6,  // ORDEM 12: compactado (era 8)
          isTabletLandscape ? 20 : 12,
          bottomPad,
        ),'''

NEW_1 = '''    Widget mobileContent = SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          isTabletLandscape ? 20 : 16,  // ORDEM 43: 12→16 margem lateral premium
          6,  // ORDEM 12: compactado (era 8)
          isTabletLandscape ? 20 : 16,  // ORDEM 43: 12→16 margem lateral premium
          bottomPad,
        ),'''

assert OLD_1 in src, "Anchor 1 (mobile outer padding) NOT FOUND"
src = src.replace(OLD_1, NEW_1, 1)
print("[1] Mobile outer padding 12→16 ✓")

# ─────────────────────────────────────────────────────────────────────────────
# 2. Mobile inter-section SizedBox heights: 8→12 (between card rows)
#    There are 4 occurrences of `const SizedBox(height: 8),  // ORDEM 12: compactado`
#    between the main sections. Use replace_all=False on each unique anchor.
# ─────────────────────────────────────────────────────────────────────────────

OLD_2a = '''          const SizedBox(height: 8),  // ORDEM 12: compactado

          // ── LINHA 2: ADULTO + PEDIATRÍA — dois cards paralelos ──────────────'''

NEW_2a = '''          const SizedBox(height: 12),  // ORDEM 43: 8→12 gap vertical premium

          // ── LINHA 2: ADULTO + PEDIATRÍA — dois cards paralelos ──────────────'''

assert OLD_2a in src, "Anchor 2a (SizedBox after Calc card) NOT FOUND"
src = src.replace(OLD_2a, NEW_2a, 1)
print("[2a] SizedBox height 8→12 after Calculadora card ✓")

OLD_2b = '''          const SizedBox(height: 8),  // ORDEM 12: compactado

          // ── LINHA 3: BIBLIOTECA + H. CLÍNICA — dois cards paralelos ─────────'''

NEW_2b = '''          const SizedBox(height: 12),  // ORDEM 43: 8→12 gap vertical premium

          // ── LINHA 3: BIBLIOTECA + H. CLÍNICA — dois cards paralelos ─────────'''

assert OLD_2b in src, "Anchor 2b (SizedBox after AdultoPediatria row) NOT FOUND"
src = src.replace(OLD_2b, NEW_2b, 1)
print("[2b] SizedBox height 8→12 after AdultoPediatria row ✓")

OLD_2c = '''          const SizedBox(height: 8),  // ORDEM 12: compactado

          // ── QUICK ACCESS BAR — BUSCAR | NOTAS | RECIENTES | FAVORITOS | EVAL ─'''

NEW_2c = '''          const SizedBox(height: 12),  // ORDEM 43: 8→12 gap vertical premium

          // ── QUICK ACCESS BAR — BUSCAR | NOTAS | RECIENTES | FAVORITOS | EVAL ─'''

assert OLD_2c in src, "Anchor 2c (SizedBox after BibliotecaHClinica row) NOT FOUND"
src = src.replace(OLD_2c, NEW_2c, 1)
print("[2c] SizedBox height 8→12 after BibliotecaHClinica row ✓")

# ─────────────────────────────────────────────────────────────────────────────
# 3a. _HomeAdultoPediatriaRow: SizedBox(width:10) → SizedBox(width:12)
# ─────────────────────────────────────────────────────────────────────────────
OLD_3a = '''class _HomeAdultoPediatriaRow extends StatelessWidget {
  final bool dark;
  final bool isEs;
  final VoidCallback onTapAdulto;
  final VoidCallback onTapPediatria;

  const _HomeAdultoPediatriaRow({
    required this.dark,
    required this.isEs,
    required this.onTapAdulto,
    required this.onTapPediatria,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      // B141: Emerald Green — #059669 → #10b981
      Expanded(child: _AgeCard(
        icon: Icons.person_rounded,
        // chore(home): renomeado ADULTO → PACIENTE (BUILD 238 PARTE 6)
        label: 'PACIENTE',
        subtitle: 'Explorar caso clínico',
        gradientColors: const [Color(0xFF022c22), Color(0xFF059669), Color(0xFF10b981)],
        accentColor: const Color(0xFF6ee7b7),
        dark: dark,
        onTap: onTapAdulto,
      )),
      const SizedBox(width: 10),'''

NEW_3a = '''class _HomeAdultoPediatriaRow extends StatelessWidget {
  final bool dark;
  final bool isEs;
  final VoidCallback onTapAdulto;
  final VoidCallback onTapPediatria;

  const _HomeAdultoPediatriaRow({
    required this.dark,
    required this.isEs,
    required this.onTapAdulto,
    required this.onTapPediatria,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      // B141: Emerald Green — #059669 → #10b981
      Expanded(child: _AgeCard(
        icon: Icons.person_rounded,
        // chore(home): renomeado ADULTO → PACIENTE (BUILD 238 PARTE 6)
        label: 'PACIENTE',
        subtitle: 'Explorar caso clínico',
        gradientColors: const [Color(0xFF022c22), Color(0xFF059669), Color(0xFF10b981)],
        accentColor: const Color(0xFF6ee7b7),
        dark: dark,
        onTap: onTapAdulto,
      )),
      const SizedBox(width: 12),  // ORDEM 43: 10→12 gap horizontal cards'''

assert OLD_3a in src, "Anchor 3a (_HomeAdultoPediatriaRow gap) NOT FOUND"
src = src.replace(OLD_3a, NEW_3a, 1)
print("[3a] _HomeAdultoPediatriaRow gap 10→12 ✓")

# ─────────────────────────────────────────────────────────────────────────────
# 3b. _HomeBibliotecaHClinicaRow: SizedBox(width:10) → SizedBox(width:12)
# ─────────────────────────────────────────────────────────────────────────────
OLD_3b = '''      Expanded(child: _AgeCard(
        icon: Icons.menu_book_rounded,
        label: 'BIBLIOTECA',
        subtitle: isEs ? 'Referencias clínicas' : 'Referências clínicas',
        gradientColors: const [Color(0xFF1e293b), Color(0xFF475569), Color(0xFF64748b)],
        accentColor: const Color(0xFFe2e8f0),
        dark: dark,
        onTap: () => onTabChange(5),
      )),
      const SizedBox(width: 10),'''

NEW_3b = '''      Expanded(child: _AgeCard(
        icon: Icons.menu_book_rounded,
        label: 'BIBLIOTECA',
        subtitle: isEs ? 'Referencias clínicas' : 'Referências clínicas',
        gradientColors: const [Color(0xFF1e293b), Color(0xFF475569), Color(0xFF64748b)],
        accentColor: const Color(0xFFe2e8f0),
        dark: dark,
        onTap: () => onTabChange(5),
      )),
      const SizedBox(width: 12),  // ORDEM 43: 10→12 gap horizontal cards'''

assert OLD_3b in src, "Anchor 3b (_HomeBibliotecaHClinicaRow gap) NOT FOUND"
src = src.replace(OLD_3b, NEW_3b, 1)
print("[3b] _HomeBibliotecaHClinicaRow gap 10→12 ✓")

# ─────────────────────────────────────────────────────────────────────────────
# 4. _AgeCard height: 84→92 (+10% mobile grid card height)
# ─────────────────────────────────────────────────────────────────────────────
OLD_4 = '''          height: 84,  // ORDEM 12: altura slim (era 92)'''

NEW_4 = '''          height: 92,  // ORDEM 43: +10% altura premium (84×1.10=92.4→92)'''

assert OLD_4 in src, "Anchor 4 (_AgeCard height 84) NOT FOUND"
src = src.replace(OLD_4, NEW_4, 1)
print("[4] _AgeCard height 84→92 (+10%) ✓")

# ─────────────────────────────────────────────────────────────────────────────
# 5. _HomeCalculadoraFarmacosCard vertical padding: 14→15 (+7% ≈ 106% height)
# ─────────────────────────────────────────────────────────────────────────────
OLD_5 = '''          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),  // ORDEM 12: slim'''

NEW_5 = '''          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),  // ORDEM 43: 14→16 (+14% impacto visual ≈ 108%)'''

assert OLD_5 in src, "Anchor 5 (_HomeCalculadoraFarmacosCard padding) NOT FOUND"
src = src.replace(OLD_5, NEW_5, 1)
print("[5] _HomeCalculadoraFarmacosCard vertical padding 14→16 (+108%) ✓")

# ─────────────────────────────────────────────────────────────────────────────
# 6. Desktop grid gap: 14.0→12.0
# ─────────────────────────────────────────────────────────────────────────────
OLD_6 = '''        if (kIsWeb) LayoutBuilder(builder: (context, constraints) {
          const cols   = 3;
          const gap    = 14.0;
          final width  = (constraints.maxWidth - gap * (cols - 1)) / cols;'''

NEW_6 = '''        if (kIsWeb) LayoutBuilder(builder: (context, constraints) {
          const cols   = 3;
          const gap    = 12.0;  // ORDEM 43: 14→12 crossAxisSpacing premium
          final width  = (constraints.maxWidth - gap * (cols - 1)) / cols;'''

assert OLD_6 in src, "Anchor 6 (desktop grid gap 14.0) NOT FOUND"
src = src.replace(OLD_6, NEW_6, 1)
print("[6] Desktop grid gap 14.0→12.0 ✓")

# ─────────────────────────────────────────────────────────────────────────────
# 7a. Desktop SizedBox(height:24) before _HomeDivider → 12
# ─────────────────────────────────────────────────────────────────────────────
OLD_7a = '''        // BUILD 93: seção 2 colunas (Plantão + Emergências) web-only
        if (kIsWeb) ...[
          const SizedBox(height: 24),
          _HomeDivider(dark: dark),
          const SizedBox(height: 20),'''

NEW_7a = '''        // BUILD 93: seção 2 colunas (Plantão + Emergências) web-only
        if (kIsWeb) ...[
          const SizedBox(height: 12),  // ORDEM 43: 24→12 vertical gap compacto
          _HomeDivider(dark: dark),
          const SizedBox(height: 12),  // ORDEM 43: 20→12 vertical gap compacto'''

assert OLD_7a in src, "Anchor 7a (desktop SizedBox 24+20 before divider) NOT FOUND"
src = src.replace(OLD_7a, NEW_7a, 1)
print("[7a] Desktop SizedBox 24→12 + 20→12 around divider ✓")

# ─────────────────────────────────────────────────────────────────────────────
# 7b. Desktop SizedBox(height:16) after Calculadora card → 12
# ─────────────────────────────────────────────────────────────────────────────
OLD_7b = '''        // ── Build 138: CALCULADORA E FÁRMACOS — card unificado full-width ─
        if (kIsWeb) ...[
          _HomeCalculadoraFarmacosCard(dark: dark, isEs: isEs),
          const SizedBox(height: 16),
        ],'''

NEW_7b = '''        // ── Build 138: CALCULADORA E FÁRMACOS — card unificado full-width ─
        if (kIsWeb) ...[
          _HomeCalculadoraFarmacosCard(dark: dark, isEs: isEs),
          const SizedBox(height: 12),  // ORDEM 43: 16→12 gap vertical compacto
        ],'''

assert OLD_7b in src, "Anchor 7b (desktop SizedBox 16 after Calculadora) NOT FOUND"
src = src.replace(OLD_7b, NEW_7b, 1)
print("[7b] Desktop SizedBox 16→12 after Calculadora card ✓")

# ─────────────────────────────────────────────────────────────────────────────
# 8. _HomeCard (desktop grid) height: 92→101 (+10%)
# ─────────────────────────────────────────────────────────────────────────────
OLD_8 = '''          width: double.infinity,
          height: 92,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.dark'''

NEW_8 = '''          width: double.infinity,
          height: 101,  // ORDEM 43: 92→101 (+10% proporção premium)
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.dark'''

assert OLD_8 in src, "Anchor 8 (_HomeCard height 92) NOT FOUND"
src = src.replace(OLD_8, NEW_8, 1)
print("[8] _HomeCard (desktop) height 92→101 (+10%) ✓")

# ─────────────────────────────────────────────────────────────────────────────
# Write output
# ─────────────────────────────────────────────────────────────────────────────
with open(TARGET, 'w', encoding='utf-8') as f:
    f.write(src)

changed = sum(1 for a, b in zip(original.splitlines(), src.splitlines()) if a != b)
print(f"\n[ORDEM43] Patch complete — {len(src)} chars, ~{changed} lines changed.")
print("Changes applied:")
print("  ✓ 1. Mobile outer padding: 12→16")
print("  ✓ 2. Inter-section SizedBox: 8→12 (3 occurrences)")
print("  ✓ 3. Card row gaps: width 10→12 (AdultoPediatria + BibliotecaHClinica)")
print("  ✓ 4. _AgeCard height: 84→92 (+10%)")
print("  ✓ 5. _HomeCalculadoraFarmacosCard vertical padding: 14→16 (+108%)")
print("  ✓ 6. Desktop grid gap: 14.0→12.0")
print("  ✓ 7. Desktop SizedBox heights: 24→12, 20→12, 16→12")
print("  ✓ 8. _HomeCard (desktop) height: 92→101 (+10%)")
