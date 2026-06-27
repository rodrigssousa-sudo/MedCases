path = '/home/user/webapp/lib/services/ai_service.dart'
with open(path, 'r', encoding='utf-8') as f:
    src = f.read()

orig_len = len(src)
cuts = []

# ══════════════════════════════════════════════════════════════════════════════
# CUT D-PT — ptStreamFormat PT (exact content extracted via repr)
# ══════════════════════════════════════════════════════════════════════════════
old_d_pt = (
    "          : '════ REGRA CRITICA Nº1 — COLUNA ZERO ABSOLUTA (BUILD 275-FIX) ════\\n'\n"
    "            'FALHA FATAL DETECTADA: o modelo Gemini insere espacos invisiveis antes dos bullets '\n"
    "            '(ex: \" * **AAS**\" ou \"  * texto\") e o Flutter Markdown os renderiza como bloco de codigo '\n"
    "            '<pre> — o usuario ve asteriscos crus e texto azul monoespacado em vez de formatacao.\\n'\n"
    "            'PROIBICAO NIVEL BINARIO: o PRIMEIRO caractere de CADA linha do corpo da resposta '\n"
    "            'DEVE ser um de: *, 🟥, 🚨, 💊, ⛔, 📌, ou letra/numero. '\n"
    "            'JAMAIS um espaco (ASCII 32), tabulacao (ASCII 9), tracinho precedido de espaco, nem recuo de nenhum tipo.\\n'\n"
    "            'EXEMPLO DE SAIDA CORRETA (copie exatamente esta estrutura):\\n'\n"
    "            '🟥 **IAM com SDST — Conduta Imediata**\\n\\n'\n"
    "            '🚨 Reperfusao: **angioplastia primaria** < 90 min (preferida).\\n\\n'\n"
    "            '💊 **AAS**: 300 mg VO (mastigar).\\n\\n'\n"
    "            '💊 **Clopidogrel**: 300 mg VO.\\n\\n'\n"
    "            '💊 **Heparina**: 5000 UI IV bolus.\\n\\n'\n"
    "            '⛔ Contraindicacao **trombólise**: sangramento ativo, AVC < 3 meses.\\n\\n'\n"
    "            '📌 Iniciar **trombólise** ou aguardar **angioplastia** disponivel?\\n'\n"
    "            'INCORRETO (JAMAIS faca isso): \"  * **AAS**: 300 mg\" — esse espaco inicial quebra o render.\\n'\n"
    "            '════ FIM REGRA Nº1 ════\\n'\n"
    "            'REGRAS SOBERANAS ADICIONAIS DE FORMATO E COMPACTACAO (BUILD 275):\\n'\n"
    "            '• DUPLA QUEBRA OBRIGATORIA: entre cada linha ou bloco, insira \\\\n\\\\n — NUNCA \\\\n isolado.\\n'\n"
    "            '• EMOJI 🟥 UNICO: aparece EXATAMENTE UMA VEZ na primeira linha. PROIBIDO repeti-lo.\\n'\n"
    "            '• TETO ESTRITO: MAXIMO 15 LINHAS e MAXIMO 800 CARACTERES TOTAIS. '\n"
    "            'Se atingir o teto, corte e encerre com o gancho 📌.\\n'\n"
    "            '• EXTERMINIO VERBAL: PROIBIDO \"Cautela com fluidos\", \"Em casos selecionados\", '\n"
    "            '\"Considerar ajuste\", \"Monitorizar de perto\". Cada linha = ordem executiva curta.\\n'\n"
    "            '• NEGRITOS SO NO NOME DO FARMACO: \"* **Norepinefrina**: 0,05 mcg/kg/min IV (PAM > 65).\" '\n"
    "            'PROIBIDO negritar frases inteiras, metas numericas ou titulos de bloco.\\n';\n"
)
new_d_pt = (
    "          : '════ REGRA Nº1 — COLUNA ZERO ABSOLUTA ════\\n'\n"
    "            'PROIBICAO NIVEL BINARIO: o 1º char de CADA linha DEVE ser: *, 🟥, 🚨, 💊, ⛔, 📌, letra/numero. '\n"
    "            'JAMAIS espaco (ASCII 32) ou tabulacao (ASCII 9) — Flutter renderiza como bloco <pre>.\\n'\n"
    "            'EXEMPLO CORRETO: \"🟥 **IAM com SDST**\" | INCORRETO: \"  * **AAS**\" (espaco quebra render).\\n'\n"
    "            '════ FIM REGRA Nº1 ════\\n'\n"
    "            'REGRAS SOBERANAS:\\n'\n"
    "            '• DUPLA QUEBRA OBRIGATORIA: entre cada linha/bloco → \\\\n\\\\n, NUNCA \\\\n isolado.\\n'\n"
    "            '• EMOJI 🟥 UNICO: aparece EXATAMENTE UMA VEZ na primeira linha.\\n'\n"
    "            '• TETO ESTRITO: MAX 15 LINHAS e MAX 800 CHARS. Se atingir o teto → encerrar com 📌.\\n';\n"
)

if old_d_pt in src:
    src = src.replace(old_d_pt, new_d_pt, 1)
    cuts.append(('D-PT', 'ptStreamFormat PT', len(old_d_pt) - len(new_d_pt)))
else:
    print('  ✗ D-PT NOT FOUND')
    # debug: look for first 60 chars
    needle = "          : '════ REGRA CRITICA N"
    idx = src.find(needle)
    print(f'  Needle idx={idx}')
    if idx > 0:
        print(repr(src[idx:idx+120]))

# ══════════════════════════════════════════════════════════════════════════════
# CUT E-PT — ptUxFlowDoctrine PT (extract exact)
# ══════════════════════════════════════════════════════════════════════════════
old_e_pt = (
    "          : 'DOUTRINA DE FLUXO UX MEDCASES PRO (BUILD 275-ADENDO — MAXIMA PRIORIDADE):\\n'\n"
    "            '• RESPOSTA = GATILHO DE IMPACTO INICIAL SOMENTE: '\n"
    "            'Sua resposta e EXCLUSIVAMENTE a Conduta Direta Seca — o gatilho inicial de acao. '\n"
    "            'O seguimento do caso (monitorizacao, ramificacoes Sim/Nao, criterios de reperfusao, '\n"
    "            'escalada terapeutica) sera conduzido pelos BOTOES DE ACAO DINAMICOS do front-end. '\n"
    "            'JAMAIS gaste caracteres explicando o que vem depois nem descrevendo o fluxo de seguimento.\\n'\n"
    "            '• ELIMINE LISTAS GENERICAS DE ESTABILIZACAO: '\n"
    "            'Se a query ja contiver dados clinicos explicitos (peso, PA, FC, saturacao, diagnostico), '\n"
    "            'SUPRIMA COMPLETAMENTE as listas de estabilizacao generalistas '\n"
    "            '(ex: \"Monitorizacao cardiaca continua\", \"Dois acessos calibrosos\", \"Oxigenacao suplementar\"). '\n"
    "            'Essas listas sao RUIDO — o medico ja sabe. Foque 100% na farmacologia imediata, '\n"
    "            'alertas fatais especificos do caso e no gancho de decisao.\\n'\n"
    "            '• GANCHO 📌 = PERGUNTA FECHADA DE DECISAO CLINICA: '\n"
    "            'A ultima linha SEMPRE termina com 📌 seguido de uma pergunta fechada de bifurcacao '\n"
    "            'de decisao que o medico pode responder com um botao (Sim/Nao, A/B, Confirmar/Ajustar). '\n"
    "            'Exemplos corretos: '\n"
    "            '\"📌 Iniciar **trombólise** ou continuar apenas com **heparina**?\" — '\n"
    "            '\"📌 Dobrar dose de **norepinefrina** ou adicionar **vasopressina**?\" — '\n"
    "            '\"📌 Avaliar criterios de IOT ou continuar **VNI**?\"\\n'\n"
    "            'Exemplo PROIBIDO: \"📌 Ver protocolo completo.\" (nao e pergunta de decisao).\\n';\n"
)
new_e_pt = (
    "          : 'DOUTRINA UX MEDCASES:\\n'\n"
    "            '• RESPOSTA = GATILHO INICIAL: so Conduta Direta Seca. Seguimento = botoes dinamicos do front-end. '\n"
    "            'JAMAIS descreva fluxo de seguimento ou repita monitorização generica.\\n'\n"
    "            '• SUPRIMA listas genericas se query ja tem dados clinicos (peso, PA, FC, sato2, diagnostico).\\n'\n"
    "            '• GANCHO 📌 OBRIGATORIO na ultima linha: pergunta fechada de decisao clinica (Sim/Nao, A/B). '\n"
    "            'Ex: \"📌 Iniciar **trombólise** ou manter **heparina**?\" '\n"
    "            'PROIBIDO: \"📌 Ver protocolo completo.\"\\n';\n"
)

if old_e_pt in src:
    src = src.replace(old_e_pt, new_e_pt, 1)
    cuts.append(('E-PT', 'ptUxFlowDoctrine PT', len(old_e_pt) - len(new_e_pt)))
else:
    print('  ✗ E-PT NOT FOUND')
    needle = "          : 'DOUTRINA DE FLUXO UX"
    idx = src.find(needle)
    print(f'  Needle idx={idx}')
    if idx > 0:
        print(repr(src[idx:idx+120]))

# ══════════════════════════════════════════════════════════════════════════════
# CUT F-PT — ptAntiParroting PT (exact)
# ══════════════════════════════════════════════════════════════════════════════
old_f_pt = (
    "          : 'DIRETRIZ DE SEGURANCA CONTRA ENVENENAMENTO DE HISTORICO: '\n"
    "            'Voce pode receber no historico de mensagens strings de erro do sistema como '\n"
    "            '\"REVISANDO RESPOSTA\", \"dados inconsistentes e foi bloqueada por seguranca\", '\n"
    "            '\"Reformule a pergunta\", qualquer texto com '\n"
    "            '\"bloqueada por seguranca\" ou \"Reformule a pergunta\" ou que comece com 🟥 REVISANDO. '\n"
    "            'VOCE ESTA ABSOLUTAMENTE PROIBIDO DE REPETIR, ECOAR, COPIAR OU SE BASEAR '\n"
    "            'NESSAS STRINGS DE ERRO TECNICO. Elas sao lixo de sistema legado. Ignore-as completamente. '\n"
    "            'Trate cada turno de mensagem como uma oportunidade pura de fornecer conduta medica real. '\n"
    "            'Nunca simule uma mensagem de erro do aplicativo.\\n';\n"
)
new_f_pt = (
    "          : 'ANTI-HISTORICO: ignore strings como \"REVISANDO RESPOSTA\"/\"bloqueada por seguranca\" — lixo legado. Responda conduta medica pura.\\n';\n"
)

if old_f_pt in src:
    src = src.replace(old_f_pt, new_f_pt, 1)
    cuts.append(('F-PT', 'ptAntiParroting PT', len(old_f_pt) - len(new_f_pt)))
else:
    print('  ✗ F-PT NOT FOUND')
    needle = "          : 'DIRETRIZ DE SEGURANCA"
    idx = src.find(needle)
    print(f'  Needle idx={idx}')
    if idx > 0:
        print(repr(src[idx:idx+200]))

# Write
if cuts:
    with open(path, 'w', encoding='utf-8') as f:
        f.write(src)
    total_saved = sum(c[2] for c in cuts)
    print(f'\nCuts applied: {len(cuts)}')
    for c in cuts:
        print(f'  ✓ {c[0]}: {c[1]} (~{c[2]}c saved)')
    print(f'Source chars removed: {total_saved}')
    print(f'File: {orig_len} → {len(src)} chars')
else:
    print('No cuts applied.')
