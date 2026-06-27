#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ORDEM MASTER 48 — Higienização Tipográfica (Remoção de All-Caps Forçado)
Target: lib/screens/ai_screen.dart

BUG CHAIN:
  _PlantaoFallbackCard: headerText = firstLine.toUpperCase()
    → Quando firstLine = "🚨 Faça Agora: Estabilização hemodinâmica...",
      o BODY COMPLETO da conduta fica em ALL CAPS.
    → Fix: só converter para caps se a linha for um título 🟥 (síndrome).
      Se for linha de conduta clínica com 🚨/💊/⛔/📌, preservar sentence case.

  _PlantaoRenderer._buildContent(isHeader=true): text.toUpperCase()
    → isHeader=true SOMENTE para response.conduta (🟥 título da síndrome)
    → Per M2: título 🟥 PODE ficar em caps — KEEP

  _AiBlockBubble 🟥 header (line 5816): label.toUpperCase()
    → Aplicado ao título de síndrome (🟥) em Modo Estudo/histórico legado
    → Per M2: título 🟥 PODE ficar em caps — KEEP

MANDATO 1 — Cirúrgico: erradicar toUpperCase() do corpo/label dos blocos clínicos.
MANDATO 2 — Preservar: manter toUpperCase() SOMENTE no header 🟥 (síndrome).
"""

import sys

def patch(path: str, old: str, new: str, label: str) -> bool:
    with open(path, 'r', encoding='utf-8') as f:
        src = f.read()
    if old not in src:
        print(f'  ✗ NOT FOUND: {label}')
        print(f'    [first 100 chars]: {repr(old[:100])}')
        return False
    count = src.count(old)
    patched = src.replace(old, new, 1)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(patched)
    print(f'  ✓ PATCHED ({count}x found, replaced first): {label}')
    return True


AI = 'lib/screens/ai_screen.dart'
errors = []

# ==============================================================================
# MANDATO 1 — CIRÚRGICO: erradicar toUpperCase() indevido
# ==============================================================================

# ── M1-A: _PlantaoFallbackCard — headerText.toUpperCase() ────────────────────
#
# ANÁLISE:
#   headerText é a PRIMEIRA LINHA do texto bruto. Pode ser:
#     a) "🚨 Faça Agora: Estabilização hemodinâmica..." → NÃO deve ser caps
#     b) "TROMBOEMBOLISMO PULMONAR (TEP)" → síndrome, PODE ser caps
#     c) "🟥 Infarto Agudo do Miocárdio" → 🟥 já stripped, síndrome → caps OK
#
# FIX: substituir .toUpperCase() por lógica condicional:
#   - Se headerRaw começa com 🚨/💊/⛔/📌/⚠️ → sentence case (sem caps)
#   - Caso contrário (síndrome pura ou 🟥 stripped) → toUpperCase() (caps OK)
#
# Isso preserva o ALL CAPS para títulos de síndrome pura (M2) e remove
# o ALL CAPS indevido do corpo da conduta clínica (M1).
print('\n[M1-A] _PlantaoFallbackCard: headerText — conditional caps (síndrome only)')
ok = patch(
    AI,
    old=(
        '    // Extract first line as header, rest as body\n'
        '    final allLines = text.trim().split(\'\\n\');\n'
        '    final headerRaw = allLines.isNotEmpty ? allLines.first.trim() : \'\';\n'
        '    final headerText = headerRaw\n'
        '        .replaceFirst(RegExp(r\'^🟥\\\\s*\'), \'\')\n'
        '        .replaceFirst(RegExp(r\'^#{1,3}\\\\s*\'), \'\')\n'
        '        .replaceFirst(RegExp(r\'^[🔵📋🏥💡⚕️]\\\\s*\'), \'\')\n'
        '        .trim()\n'
        '        .toUpperCase();'
    ),
    new=(
        '    // Extract first line as header, rest as body\n'
        '    final allLines = text.trim().split(\'\\n\');\n'
        '    final headerRaw = allLines.isNotEmpty ? allLines.first.trim() : \'\';\n'
        '    // ORDEM 48 M1: headerText capitalização condicional.\n'
        '    // Síndrome pura (🟥 stripped ou texto direto) → toUpperCase() [M2: permitido].\n'
        '    // Blocos de conduta clínica (🚨/💊/⛔/📌/⚠️) → preservar sentence case da IA.\n'
        '    final _headerIsCondutaBlock = headerRaw.startsWith(\'🚨\') ||\n'
        '        headerRaw.startsWith(\'💊\') ||\n'
        '        headerRaw.startsWith(\'⛔\') ||\n'
        '        headerRaw.startsWith(\'📌\') ||\n'
        '        headerRaw.startsWith(\'⚠️\');\n'
        '    final headerText = _headerIsCondutaBlock\n'
        '        ? headerRaw  // preserva sentence case da IA — NUNCA toUpperCase() em conduta clínica\n'
        '        : headerRaw\n'
        '            .replaceFirst(RegExp(r\'^🟥\\\\s*\'), \'\')\n'
        '            .replaceFirst(RegExp(r\'^#{1,3}\\\\s*\'), \'\')\n'
        '            .replaceFirst(RegExp(r\'^[🔵📋🏥💡⚕️]\\\\s*\'), \'\')\n'
        '            .trim()\n'
        '            .toUpperCase(); // síndrome pura — caps OK per M2'
    ),
    label='_PlantaoFallbackCard headerText: conditional caps (conduta block → no caps)',
)
if not ok:
    errors.append('M1-A')

# ── M1-B: _PlantaoRenderer._buildContent(isHeader=true) — text.toUpperCase() ─
#
# ANÁLISE:
#   isHeader=true SOMENTE para response.conduta (🟥 título da síndrome).
#   Ex: "INFARTO AGUDO DO MIOCÁRDIO" ou "Tromboembolismo Pulmonar (TEP)".
#   Per M2: título 🟥 PODE ficar em caps → KEEP toUpperCase().
#
# MAS: a screenshot mostra "🚨 Faça Agora" em caps. Isso ocorre quando:
#   1. O AI usa 🚨 como PRIMEIRA linha (antes de 🟥)
#   2. PlantaoParser atribui essa linha ao campo conduta (se 🟥 não existe)
#   3. _PlantaoRenderer renderiza com isHeader=true → toUpperCase()
#
# FIX: aplicar a mesma lógica condicional — se o texto começa com um emoji
# de bloco clínico (🚨/💊/⛔/📌), NÃO aplicar toUpperCase().
print('\n[M1-B] _PlantaoRenderer._buildContent isHeader=true: conditional caps')
ok = patch(
    AI,
    old=(
        '    if (isHeader) {\n'
        '      // ORDEM 17 — contraste dinâmico: ciano no dark, grafite denso no light\n'
        '      // Emoji conserva a cor semântica (emojiColor) para manter a hierarquia visual.\n'
        '      final kHeaderTextColor = dark\n'
        '          ? const Color(0xFF00E5FF)   // ciano médico — contraste 12:1 sobre fundo escuro\n'
        '          : const Color(0xFF1A1A1A);  // grafite denso — contraste 18:1 sobre fundo claro\n'
        '      return RichText(\n'
        '        text: TextSpan(\n'
        '          children: [\n'
        '            TextSpan(\n'
        '              text: \'$emoji \',\n'
        '              style: TextStyle(\n'
        '                fontSize: 15,\n'
        '                fontWeight: FontWeight.w800,\n'
        '                color: emojiColor,\n'
        '                height: 1.4,\n'
        '              ),\n'
        '            ),\n'
        '            TextSpan(\n'
        '              text: text.toUpperCase(),\n'
        '              style: TextStyle(\n'
        '                fontSize: 13.5,\n'
        '                fontWeight: FontWeight.w800,\n'
        '                color: kHeaderTextColor,\n'
        '                height: 1.4,\n'
        '                letterSpacing: 0.5,\n'
        '              ),\n'
        '            ),\n'
        '          ],\n'
        '        ),\n'
        '      );\n'
        '    }'
    ),
    new=(
        '    if (isHeader) {\n'
        '      // ORDEM 17 — contraste dinâmico: ciano no dark, grafite denso no light\n'
        '      // Emoji conserva a cor semântica (emojiColor) para manter a hierarquia visual.\n'
        '      final kHeaderTextColor = dark\n'
        '          ? const Color(0xFF00E5FF)   // ciano médico — contraste 12:1 sobre fundo escuro\n'
        '          : const Color(0xFF1A1A1A);  // grafite denso — contraste 18:1 sobre fundo claro\n'
        '      // ORDEM 48 M1: toUpperCase() condicional no header do PlantaoRenderer.\n'
        '      // Síndrome pura (🟥) → caps para hierarquia visual (M2: permitido).\n'
        '      // Blocos de conduta (🚨/💊/⛔/📌) → sentence case da IA preservado.\n'
        '      final _isCondutaEmoji = text.startsWith(\'🚨\') ||\n'
        '          text.startsWith(\'💊\') ||\n'
        '          text.startsWith(\'⛔\') ||\n'
        '          text.startsWith(\'📌\');\n'
        '      final headerDisplayText = _isCondutaEmoji ? text : text.toUpperCase();\n'
        '      return RichText(\n'
        '        text: TextSpan(\n'
        '          children: [\n'
        '            TextSpan(\n'
        '              text: \'$emoji \',\n'
        '              style: TextStyle(\n'
        '                fontSize: 15,\n'
        '                fontWeight: FontWeight.w800,\n'
        '                color: emojiColor,\n'
        '                height: 1.4,\n'
        '              ),\n'
        '            ),\n'
        '            TextSpan(\n'
        '              text: headerDisplayText,\n'
        '              style: TextStyle(\n'
        '                fontSize: 13.5,\n'
        '                fontWeight: FontWeight.w800,\n'
        '                color: kHeaderTextColor,\n'
        '                height: 1.4,\n'
        '                letterSpacing: 0.5,\n'
        '              ),\n'
        '            ),\n'
        '          ],\n'
        '        ),\n'
        '      );\n'
        '    }'
    ),
    label='_PlantaoRenderer._buildContent isHeader=true: conditional caps',
)
if not ok:
    errors.append('M1-B')

# ── M1-C: _AiBlockBubble 🟥 header (line 5816) — label.toUpperCase() ─────────
#
# ANÁLISE:
#   Este bloco renderiza linhas que começam com 🟥 no Modo Estudo / histórico.
#   A "label" é o texto após "🟥 " → tipicamente o nome da síndrome.
#   Per M2: título 🟥 PODE ficar em caps.
#   PORÉM: na tela de captura, se um bloco 🟥 do Modo Estudo contiver
#   o corpo da conduta (ex: "🟥 Faça Agora: Estabilize..."), isso também
#   fica em caps incorretamente.
#
# FIX: aplicar a mesma lógica condicional — se o label começa com 🚨 ou
# outro emoji de sub-bloco clínico, preservar sentence case.
# Na prática: 🟥 → "TROMBOEMBOLISMO PULMONAR" (caps OK) vs
#              🟥 → "Faça Agora: Estabilize" (se existir, não caps).
# A condição é: se o LABEL começa com um emoji de bloco → não caps.
print('\n[M1-C] _AiBlockBubble 🟥 header: conditional caps (preserve síndrome)')
ok = patch(
    AI,
    old=(
        '                      Expanded(child: Text(\n'
        '                        (label.isEmpty ? trimmed : label).toUpperCase(),\n'
        '                        style: TextStyle(\n'
        '                          fontSize: 13.5,\n'
        '                          fontWeight: FontWeight.w800,\n'
        '                          color: dark\n'
        '                              ? const Color(0xFF00E5FF)   // ciano médico — contraste 12:1 sobre fundo escuro\n'
        '                              : const Color(0xFF1A1A1A),  // grafite denso — contraste 18:1 sobre fundo claro\n'
        '                          height: 1.3,\n'
        '                          letterSpacing: 0.5,\n'
        '                        ),\n'
        '                      )),'
    ),
    new=(
        '                      Expanded(child: Text(\n'
        '                        // ORDEM 48 M1: caps condicional — síndrome pura → caps; conduta clínica → sentence case.\n'
        '                        () {\n'
        '                          final raw = label.isEmpty ? trimmed : label;\n'
        '                          // Se o texto começa com emoji de bloco clínico → sentence case da IA\n'
        '                          final startsWithClinic = raw.startsWith(\'🚨\') ||\n'
        '                              raw.startsWith(\'💊\') ||\n'
        '                              raw.startsWith(\'⛔\') ||\n'
        '                              raw.startsWith(\'📌\') ||\n'
        '                              raw.startsWith(\'⚠️\');\n'
        '                          return startsWithClinic ? raw : raw.toUpperCase();\n'
        '                        }(),\n'
        '                        style: TextStyle(\n'
        '                          fontSize: 13.5,\n'
        '                          fontWeight: FontWeight.w800,\n'
        '                          color: dark\n'
        '                              ? const Color(0xFF00E5FF)   // ciano médico — contraste 12:1 sobre fundo escuro\n'
        '                              : const Color(0xFF1A1A1A),  // grafite denso — contraste 18:1 sobre fundo claro\n'
        '                          height: 1.3,\n'
        '                          letterSpacing: 0.5,\n'
        '                        ),\n'
        '                      )),'
    ),
    label='_AiBlockBubble 🟥 header: label.toUpperCase() → conditional caps',
)
if not ok:
    errors.append('M1-C')

# ==============================================================================
print()
if errors:
    print(f'❌ FALHOU: {len(errors)} mandato(s) — {errors}')
    sys.exit(1)
else:
    print('✅ ORDEM 48 — TODOS OS PATCHES APLICADOS COM SUCESSO')
    print('   M1-A: _PlantaoFallbackCard headerText — 🚨/💊/⛔/📌 → sentence case')
    print('   M1-B: _PlantaoRenderer._buildContent isHeader — conduta emoji → sentence case')
    print('   M1-C: _AiBlockBubble 🟥 header — conduta emoji → sentence case')
    print('   M2 PRESERVADO: toUpperCase() mantido para síndrome pura (🟥 título)')
