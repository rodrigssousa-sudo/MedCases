#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
SUPER ORDEM MASTER 47 — Google Auth Lock (Soberana) + Cognitive Tier Fix
Targets:
  M1 → lib/screens/ai_screen.dart
  M2 → lib/services/provider_router_service.dart
"""

import sys

def patch(path: str, old: str, new: str, label: str) -> bool:
    with open(path, 'r', encoding='utf-8') as f:
        src = f.read()
    if old not in src:
        print(f'  ✗ NOT FOUND: {label}')
        print(f'    [first 120 chars of old]: {repr(old[:120])}')
        return False
    count = src.count(old)
    patched = src.replace(old, new, 1)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(patched)
    print(f'  ✓ PATCHED (found {count}x): {label}')
    return True


AI   = 'lib/screens/ai_screen.dart'
ROUTER = 'lib/services/provider_router_service.dart'

errors = []

# ==============================================================================
# MANDATO 1 — ai_screen.dart
# Barreira de autenticação SOBERANA baseada exclusivamente em forceDisconnectedLabel
# ==============================================================================

# ── M1-A: Remover condição !_messages.any(role==user) do Stack auth barrier ──
# ANTES: if (forceDisconnectedLabel && !_messages.any((m) => m.role == 'user'))
# DEPOIS: if (forceDisconnectedLabel)
# A barreira agora é incondicional ao status de login — não depende do histórico.
print('\n[M1-A] Auth barrier condition: remove !_messages.any() gate')
ok = patch(
    AI,
    old=(
        '            // SUPER ORDEM 42 M4 / ORDEM 44 M3: Google Auth Barrier — card proeminente\n'
        '            // quando usuário não-autenticado tenta usar a IA.\n'
        '            // ORDEM 44: condição pareia com toggle — desaparece no 1º envio do médico.\n'
        '            if (forceDisconnectedLabel &&\n'
        '                !_messages.any((m) => m.role == \'user\'))\n'
        '              _GoogleAuthBarrierCard(\n'
        '                dark: dark,\n'
        '                lang: p.lang,\n'
        '                onConnect: _openAiSettings,\n'
        '              )\n'
        '            // Card \"IA Desconectada\" — sobreposto quando IA não está conectada\n'
        '            // e o médico ainda não enviou nenhuma mensagem (usuário privilegiado)\n'
        '            else if (showDisconnectCard)\n'
        '              _EmptyChat(\n'
        '                dark: dark,\n'
        '                lang: p.lang,\n'
        '                isConnected: false,\n'
        '                onConnectApi: _openAiSettings,\n'
        '              ),'
    ),
    new=(
        '            // ORDEM 47 M1: Auth barrier SOBERANA — baseada EXCLUSIVAMENTE em\n'
        '            // forceDisconnectedLabel (= !isPrivilegedUser && !isConnected).\n'
        '            // Não depende mais de _messages.any(). O overlay cobre TODA a timeline\n'
        '            // independente de haver mensagens — proteção financeira de API absoluta.\n'
        '            if (forceDisconnectedLabel)\n'
        '              _GoogleAuthBarrierCard(\n'
        '                dark: dark,\n'
        '                lang: p.lang,\n'
        '                onConnect: _openAiSettings,\n'
        '              )\n'
        '            // Card \"IA Desconectada\" — sobreposto quando IA não está conectada\n'
        '            // e o médico ainda não enviou nenhuma mensagem (usuário privilegiado)\n'
        '            else if (showDisconnectCard)\n'
        '              _EmptyChat(\n'
        '                dark: dark,\n'
        '                lang: p.lang,\n'
        '                isConnected: false,\n'
        '                onConnectApi: _openAiSettings,\n'
        '              ),'
    ),
    label='Stack barrier forceDisconnectedLabel — remove !any(role==user) gate',
)
if not ok:
    errors.append('M1-A')

# ── M1-B: Aplicar blur à chatList quando forceDisconnectedLabel ───────────────
# Antes: Widget chatList = ListView.builder(
# Agora: Constroí o chatList normalmente mas ao montar no Stack,
#        quando forceDisconnectedLabel, envolve em ImageFilter.blur.
# Approach: substituir `Widget chatList = ListView.builder(` pela construção
# que depois é condicionalmente wrappada. Usamos a wrapagem no ponto de uso
# (dentro do Stack) em vez de na definição.
#
# O ponto de uso é: `chatList,` como primeiro child do Stack children: [].
# Substituímos por: um widget condicional que aplica blur se forceDisconnectedLabel.
print('\n[M1-B] Blur chatList overlay when forceDisconnectedLabel')
ok = patch(
    AI,
    old=(
        '        child: Stack(\n'
        '          children: [\n'
        '            chatList,\n'
        '            // ORDEM 47 M1: Auth barrier SOBERANA'
    ),
    new=(
        '        child: Stack(\n'
        '          children: [\n'
        '            // ORDEM 47 M1: blur da timeline quando usuário não autenticado.\n'
        '            // ImageFilter.blur oculta o conteúdo da timeline visualmente,\n'
        '            // reforçando que a IA está bloqueada até a conexão Google ser feita.\n'
        '            if (forceDisconnectedLabel)\n'
        '              ImageFiltered(\n'
        '                imageFilter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),\n'
        '                child: IgnorePointer(child: chatList),\n'
        '              )\n'
        '            else\n'
        '              chatList,\n'
        '            // ORDEM 47 M1: Auth barrier SOBERANA'
    ),
    label='Stack children[0]: chatList → conditional blur wrapper',
)
if not ok:
    errors.append('M1-B')

# ── M1-C: Adicionar import 'dart:ui' se não presente ─────────────────────────
# ImageFilter está em dart:ui — verificar se já importado
print('\n[M1-C] Ensure dart:ui imported for ImageFilter')
with open(AI, 'r', encoding='utf-8') as f:
    ai_src = f.read()

if "import 'dart:ui'" in ai_src:
    print("  ✓ dart:ui already imported — skipping")
else:
    ok = patch(
        AI,
        old="import 'dart:async';",
        new="import 'dart:async';\nimport 'dart:ui' as ui;",
        label="Add 'dart:ui' import for ImageFilter",
    )
    if not ok:
        errors.append('M1-C')

# ── M1-D: Remover condição !_messages.any() do _ResponseModeToggle ─────────
# ORDEM 44 colocou: if (!forceDisconnectedLabel && !_messages.any((m) => m.role == 'user'))
# Agora: quando forceDisconnectedLabel=true o toggle já não aparece (covered by barrier).
# Mas quando forceDisconnectedLabel=false (usuário autenticado), remover a condição
# !_messages.any() para que o toggle continue visível mesmo após mensagens.
# NOTA: manter o comportamento de apenas esconder quando há mensagens do usuário
#       (ORDEM 44 M1) porque isso ainda é válido para fluxo normal.
# A única mudança: o toggle não precisa mais ser oculto por !_messages.any()
# porque isso era para parear com a barreira — que agora é soberana.
# Decisão: MANTER toggle como está (esconde quando há msgs do user) — não muda.
# A barreira soberana já garante que toggle não conflita com a barreira.
print('\n[M1-D] Toggle condition: KEPT AS-IS (correct per O44 M1 semantics)')
print('  ✓ No change needed — toggle still hides on first user message (correct UX)')

# ── M1-E: Update _DisconnectedInputLock hint text com 🔒 ──────────────────────
# Mandate: hintText = '🔒 Conecte o Google para usar a IA...'
# Atual: 'Conecte sua conta para usar a IA…' (sem emoji, sem pt-br uniform)
print('\n[M1-E] _DisconnectedInputLock: update hint text with 🔒 emoji')
ok = patch(
    AI,
    old=(
        '                  isEs ? \'Conecta tu cuenta para usar la IA…\'\n'
        '                       : \'Conecte sua conta para usar a IA…\','
    ),
    new=(
        '                  // ORDEM 47 M1: 🔒 prefix reforça o bloqueio visualmente\n'
        '                  isEs ? \'\U0001F512 Conecta Google para usar la IA...\'\n'
        '                       : \'\U0001F512 Conecte o Google para usar a IA...\','
    ),
    label='_DisconnectedInputLock hint text → 🔒 emoji prefix',
)
if not ok:
    errors.append('M1-E')

# ==============================================================================
# MANDATO 2 — provider_router_service.dart
# Adicionar 'tier' cognitivo ao payload + ajuste maxOutputTokens Estudo
# ==============================================================================

# ── M2-A: Adicionar 'tier' ao payload JSON (terceira chave de desvio de rota) ─
# ANTES: 'temperature':     _activeTemp,       // temperatura por modo
# DEPOIS: + 'tier': cognitivo/speed como tag de bypass físico no servidor
print('\n[M2-A] payload: add tier key (cognitive/speed)')
ok = patch(
    ROUTER,
    old=(
        "      'model':           _activeModel,      // override direto de modelo\n"
        "      'model_tier':      _activeModelTier,  // tag de tier ('speed'|'pro')\n"
        "      'temperature':     _activeTemp,       // temperatura por modo\n"
    ),
    new=(
        "      'model':           _activeModel,      // override direto de modelo\n"
        "      'model_tier':      _activeModelTier,  // tag de tier ('speed'|'pro')\n"
        "      'temperature':     _activeTemp,       // temperatura por modo\n"
        "      // ORDEM 47 M2: 'tier' como terceira tag de bypass físico no servidor.\n"
        "      // 'cognitive' = Gemini 2.5 Pro (Estudo) | 'speed' = Flash (Plantão).\n"
        "      // Tripla sinalização: model + model_tier + tier → desvio garantido.\n"
        "      'tier':            isPlantao ? 'speed' : 'cognitive',\n"
    ),
    label="payload: 'tier' cognitive/speed key added",
)
if not ok:
    errors.append('M2-A')

# ── M2-B: Atualizar log de diagnóstico para incluir tier ─────────────────────
print('\n[M2-B] ORDEM42_PAYLOAD debug log: include tier')
ok = patch(
    ROUTER,
    old=(
        "      debugPrint('[ORDEM42_PAYLOAD] mode=$mode '\n"
        "          'model=$_activeModel '\n"
        "          'model_tier=$_activeModelTier '\n"
        "          'temperature=$_activeTemp '\n"
        "          'maxOutputTokens=$maxOutputTokens');"
    ),
    new=(
        "      debugPrint('[ORDEM47_PAYLOAD] mode=$mode '\n"
        "          'model=$_activeModel '\n"
        "          'model_tier=$_activeModelTier '\n"
        "          'tier=${isPlantao ? \"speed\" : \"cognitive\"} '\n"
        "          'temperature=$_activeTemp '\n"
        "          'maxOutputTokens=$maxOutputTokens');"
    ),
    label='PAYLOAD debug log updated: tier field added',
)
if not ok:
    errors.append('M2-B')

# ── M2-C: Estudo maxOutputTokens padrão 2048→2500 no callPaidProxy default ───
# O default do parâmetro maxOutputTokens no callPaidProxy é 800.
# Em app_provider.dart, as chamadas passam longResponse ? 2048 : 3200.
# O mandato diz max_tokens: 2500 para Estudo — alinhar o call site principal.
# NOTA: callPaidProxy signature default é 800 (para Plantão direto/test).
# Os call sites em app_provider passam explicitamente 2048 para Estudo.
# Atualizamos para 2500 como mandatado.
print('\n[M2-C] app_provider.dart: Estudo maxOutputTokens 2048→2500 em ambos call sites')

APP = 'lib/providers/app_provider.dart'
with open(APP, 'r', encoding='utf-8') as f:
    app_src = f.read()

old_tokens = "        maxOutputTokens: longResponse ? 2048 : 3200,  // ORDEM 23: Plantão 1600→3200 — elimina corte abrupto de streaming (teto de prompt também removido)"
new_tokens = "        maxOutputTokens: longResponse ? 2500 : 3200,  // ORDEM 47 M2: Estudo 2048→2500 (lock cognitivo — garante output completo no Pro)"

count_old = app_src.count(old_tokens)
if count_old == 0:
    print(f'  ✗ NOT FOUND: Estudo maxOutputTokens 2048 line (found {count_old}x)')
    errors.append('M2-C')
else:
    app_src = app_src.replace(old_tokens, new_tokens)
    with open(APP, 'w', encoding='utf-8') as f:
        f.write(app_src)
    print(f'  ✓ PATCHED ({count_old}x replaced): maxOutputTokens Estudo 2048→2500')

# ==============================================================================
print()
if errors:
    print(f'❌ FALHOU: {len(errors)} mandato(s) — {errors}')
    sys.exit(1)
else:
    print('✅ SUPER ORDEM 47 — TODOS OS PATCHES APLICADOS COM SUCESSO')
    print('   ai_screen.dart:               M1-A barrier soberana, M1-B blur, M1-E hint')
    print('   provider_router_service.dart: M2-A tier key, M2-B log')
    print('   app_provider.dart:            M2-C Estudo maxOutputTokens 2048→2500')
