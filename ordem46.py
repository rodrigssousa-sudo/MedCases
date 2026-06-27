#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
SUPER ORDEM MASTER 46 — Hotfix UTF-8 Encoding + Token Overflow
Target: lib/services/provider_router_service.dart
"""

import sys

def patch(path: str, old: str, new: str, label: str) -> bool:
    with open(path, 'r', encoding='utf-8') as f:
        src = f.read()
    if old not in src:
        print(f'  ✗ NOT FOUND: {label}')
        return False
    count = src.count(old)
    patched = src.replace(old, new, 1)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(patched)
    print(f'  ✓ PATCHED ({count}x found, replaced first): {label}')
    return True

def patch_all(path: str, old: str, new: str, label: str) -> bool:
    with open(path, 'r', encoding='utf-8') as f:
        src = f.read()
    if old not in src:
        print(f'  ✗ NOT FOUND: {label}')
        return False
    count = src.count(old)
    patched = src.replace(old, new)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(patched)
    print(f'  ✓ PATCHED ({count}x found, all replaced): {label}')
    return True

# ══════════════════════════════════════════════════════════════════════════════
# TARGET: provider_router_service.dart
# ══════════════════════════════════════════════════════════════════════════════
ROUTER = 'lib/services/provider_router_service.dart'

errors = []

# ──────────────────────────────────────────────────────────────────────────────
# M1-A: UTF-8 decode fix — error path (line ~294)
# Replace: final body = jsonDecode(response.body) as Map<String, dynamic>;
#          (inside the statusCode != 200 error block)
# With: explicit utf8.decode(response.bodyBytes) before jsonDecode
# ──────────────────────────────────────────────────────────────────────────────
print('\n[M1-A] UTF-8 fix — error response body (statusCode != 200 block)')
ok = patch(
    ROUTER,
    old=(
        '      try {\n'
        '        final body = jsonDecode(response.body) as Map<String, dynamic>;\n'
        '        errorCode = body[\'error\']?.toString() ?? errorCode;\n'
        '      } catch (_) {}'
    ),
    new=(
        '      try {\n'
        '        final decodedErr = utf8.decode(response.bodyBytes);\n'
        '        final body = jsonDecode(decodedErr) as Map<String, dynamic>;\n'
        '        errorCode = body[\'error\']?.toString() ?? errorCode;\n'
        '      } catch (_) {}'
    ),
    label='error block utf8.decode(response.bodyBytes)',
)
if not ok:
    errors.append('M1-A')

# ──────────────────────────────────────────────────────────────────────────────
# M1-B: UTF-8 decode fix — success path (line ~304)
# Replace: body = jsonDecode(response.body) as Map<String, dynamic>;
#          (inside the statusCode == 200 success block)
# With: explicit utf8.decode(response.bodyBytes) before jsonDecode
# ──────────────────────────────────────────────────────────────────────────────
print('\n[M1-B] UTF-8 fix — success response body (statusCode == 200 block)')
ok = patch(
    ROUTER,
    old=(
        '    Map<String, dynamic> body;\n'
        '    try {\n'
        '      body = jsonDecode(response.body) as Map<String, dynamic>;\n'
        '    } catch (e) {\n'
        '      debugPrint(\'[PAID_PROXY] requestId=$requestId success=false status=parse_error\');\n'
        '      return PaidProxyResult.failure(\'parse_error\');\n'
        '    }'
    ),
    new=(
        '    Map<String, dynamic> body;\n'
        '    try {\n'
        '      // ORDEM 46 M1: utf8.decode(bodyBytes) garante suporte correto a acentos\n'
        '      // (á, é, í, ó, ú, ñ) — evita mismatch ISO-8859-1 que corrompia output Plantão.\n'
        '      final decodedBody = utf8.decode(response.bodyBytes);\n'
        '      body = jsonDecode(decodedBody) as Map<String, dynamic>;\n'
        '    } catch (e) {\n'
        '      debugPrint(\'[PAID_PROXY] requestId=$requestId success=false status=parse_error\');\n'
        '      return PaidProxyResult.failure(\'parse_error\');\n'
        '    }'
    ),
    label='success block utf8.decode(response.bodyBytes)',
)
if not ok:
    errors.append('M1-B')

# ══════════════════════════════════════════════════════════════════════════════
print()
if errors:
    print(f'❌ FALHOU: {len(errors)} mandato(s) — {errors}')
    sys.exit(1)
else:
    print('✅ SUPER ORDEM 46 M1 — TODOS OS PATCHES APLICADOS COM SUCESSO')
    print('   provider_router_service.dart: utf8.decode(bodyBytes) injetado em 2 locais')
