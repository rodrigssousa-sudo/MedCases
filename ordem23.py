import sys

# ── FILE 1: ai_service.dart ──────────────────────────────────────────────────
path_svc = '/home/user/webapp/lib/services/ai_service.dart'
with open(path_svc, 'r', encoding='utf-8') as f:
    src = f.read()

orig = len(src)
cuts = []

# ────────────────────────────────────────────────────────────────────────────
# CUT 1-ES: ptStreamFormat REGRAS SOBERANAS — remove teto 800/15 (ES)
# Mantém os outros 2 bullets (dupla quebra + emoji único)
# ────────────────────────────────────────────────────────────────────────────
old1es = (
    "            '• TECHO ESTRICTO: MAX 15 LINEAS y MAX 800 CHARS. Si alcanzas el techo → cerrar con 📌.\\n'\n"
)
new1es = (
    "            '• COMPLETAR SEMPRE: conclua TODAS as secoes iniciadas. Sem corte abrupto.\\n'\n"
)
if old1es in src:
    src = src.replace(old1es, new1es, 1)
    cuts.append(('1-ES', 'ptStreamFormat teto 800/15 ES'))
else:
    print('  ✗ CUT 1-ES NOT FOUND')

# ────────────────────────────────────────────────────────────────────────────
# CUT 1-PT: ptStreamFormat REGRAS SOBERANAS — remove teto 800/15 (PT)
# ────────────────────────────────────────────────────────────────────────────
old1pt = (
    "            '• TETO ESTRITO: MAX 15 LINHAS e MAX 800 CHARS. Se atingir o teto → encerrar com 📌.\\n'\n"
)
new1pt = (
    "            '• COMPLETAR SEMPRE: conclua TODAS as secoes iniciadas. Sem corte abrupto.\\n'\n"
)
if old1pt in src:
    src = src.replace(old1pt, new1pt, 1)
    cuts.append(('1-PT', 'ptStreamFormat teto 800/15 PT'))
else:
    print('  ✗ CUT 1-PT NOT FOUND')

# ────────────────────────────────────────────────────────────────────────────
# CUT 2-ES: _responseFormatEs — item 7 "MÁXIMO 15 LINHAS"
# ────────────────────────────────────────────────────────────────────────────
old2es = "7. MÁXIMO 15 LINHAS no total — contar todas as linhas incluindo cabeçalho 🟥.\n"
new2es = "7. COMPLETAR O TEMPLATE INTEGRALMENTE — nunca cortar a resposta no meio.\n"
if old2es in src:
    src = src.replace(old2es, new2es, 1)
    cuts.append(('2-ES', '_responseFormatEs item7 15-linhas'))
else:
    print('  ✗ CUT 2-ES NOT FOUND')

# ────────────────────────────────────────────────────────────────────────────
# CUT 2-PT: _responseFormatPt — item 7 "MÁXIMO 15 LINHAS"
# Há duas ocorrências (ES e PT), replace segunda instância
# ────────────────────────────────────────────────────────────────────────────
# Count occurrences
count_15 = src.count("7. MÁXIMO 15 LINHAS no total — contar todas as linhas incluindo cabeçalho 🟥.\n")
if count_15 >= 1:
    # Replace remaining occurrence (ES already replaced above if it existed)
    src = src.replace(
        "7. MÁXIMO 15 LINHAS no total — contar todas as linhas incluindo cabeçalho 🟥.\n",
        "7. COMPLETAR O TEMPLATE INTEGRALMENTE — nunca cortar a resposta no meio.\n",
    )
    cuts.append(('2-PT', f'_responseFormatPt item7 15-linhas (remaining {count_15} instances)'))
else:
    print('  ✗ CUT 2-PT: no remaining instances')

# ────────────────────────────────────────────────────────────────────────────
# Also patch the ES template's own line (slightly different phrasing)
# ────────────────────────────────────────────────────────────────────────────
old2es_b = "7. MÁXIMO 15 LINHAS no total — contar todas as linhas incluindo cabeçalho 🟥.\n"
# already replaced above (covers both)

# ────────────────────────────────────────────────────────────────────────────
# CUT 3: _responseFormatEs/Pt "Máximo 15 linhas" header line
# ────────────────────────────────────────────────────────────────────────────
old3 = "Máximo 15 linhas no total. O PRIMEIRO CARACTERE da resposta DEVE SER \"🟥\". SEM EXCEÇÕES.\n"
new3 = "O PRIMEIRO CARACTERE da resposta DEVE SER \"🟥\". SEM EXCEÇÕES.\n"
if old3 in src:
    src = src.replace(old3, new3, 1)
    cuts.append(('3', '_responseFormatPt header Maximo15linhas'))
else:
    print('  ✗ CUT 3 NOT FOUND')

# Also ES version of header
old3es = "Máximo 15 linhas no total. O PRIMEIRO CARACTERE"
if old3es in src:
    # Already covered above
    pass

# ────────────────────────────────────────────────────────────────────────────
# CUT 4: debugPrint label — update COMPACT_800CHARS_15LINES_ACTIVE label
# ────────────────────────────────────────────────────────────────────────────
old4 = "          'COMPACT_800CHARS_15LINES_ACTIVE. BOLD_NAME_ONLY_ACTIVE. '\n"
new4 = "          'TETO_REMOVIDO_ORDEM23. BOLD_NAME_ONLY_ACTIVE. '\n"
if old4 in src:
    src = src.replace(old4, new4, 1)
    cuts.append(('4', 'debugPrint label COMPACT_800CHARS'))
else:
    print('  ✗ CUT 4 NOT FOUND')

with open(path_svc, 'w', encoding='utf-8') as f:
    f.write(src)

print(f'\n[ai_service.dart] Cuts: {len(cuts)} | {orig} → {len(src)} chars')
for c in cuts:
    print(f'  ✓ {c[0]}: {c[1]}')

# ── FILE 2: app_provider.dart ─────────────────────────────────────────────
path_prov = '/home/user/webapp/lib/providers/app_provider.dart'
with open(path_prov, 'r', encoding='utf-8') as f:
    src2 = f.read()

orig2 = len(src2)
prov_cuts = []

# maxOutputTokens: 1600 → 3200 (Plantão path)
old_tok = "maxOutputTokens: longResponse ? 2048 : 1600,  // BUILD 271: Plantão=800→1600 (elimina truncamento de matrizes completas), Estudo=2048"
new_tok = "maxOutputTokens: longResponse ? 2048 : 3200,  // ORDEM 23: Plantão 1600→3200 — elimina corte abrupto de streaming (teto de prompt também removido)"

count_tok = src2.count(old_tok)
if count_tok > 0:
    src2 = src2.replace(old_tok, new_tok)
    prov_cuts.append(f'maxOutputTokens 1600→3200 ({count_tok} occurrences)')
else:
    print('  ✗ maxOutputTokens pattern NOT FOUND')

with open(path_prov, 'w', encoding='utf-8') as f:
    f.write(src2)

print(f'\n[app_provider.dart] Cuts: {len(prov_cuts)} | {orig2} → {len(src2)} chars')
for c in prov_cuts:
    print(f'  ✓ {c}')

print('\nDone — ORDEM 23 applied.')
