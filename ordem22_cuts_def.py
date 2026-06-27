import re, sys

path = '/home/user/webapp/lib/services/ai_service.dart'
with open(path, 'r', encoding='utf-8') as f:
    src = f.read()

orig_len = len(src)
cuts = []

# ══════════════════════════════════════════════════════════════════════════════
# CUT D — ptStreamFormat: trim 7-line BAD/GOOD example → 2 lines,
#          REGRAS SOBERANAS 5 bullets → 3 (drop EXTERMINIO VERBAL + NEGRITAS)
# ══════════════════════════════════════════════════════════════════════════════

# --- ES version ---
old_es_stream = (
    "          ? '════ REGLA CRITICA Nº1 — COLUMNA CERO ABSOLUTA (BUILD 275-FIX) ════\\n'\n"
    "            'FALLA FATAL DETECTADA: el modelo Gemini inserta espacios invisibles antes de los bullets '\n"
    "            '(ej: \" * **AAS**\" o \"  * texto\") y Flutter Markdown los renderiza como bloque de codigo '\n"
    "            '<pre> — el usuario ve asteriscos crudos y texto azul monoespaciado en lugar de formato.\\n'\n"
    "            'PROHIBICION NIVEL BINARIO: el PRIMER caracter de CADA linea del cuerpo de la respuesta '\n"
    "            'DEBE ser uno de: *, 🟥, 🚨, 💊, ⛔, 📌, o letra/numero. '\n"
    "            'JAMAS un espacio (ASCII 32), tabulacion (ASCII 9), guion precedido de espacio, ni sangria de ningun tipo.\\n'\n"
    "            'EJEMPLO DE SALIDA CORRECTA (copia exactamente esta estructura):\\n'\n"
    "            '🟥 **IAM con SDST — Conducta Inmediata**\\n\\n'\n"
    "            '🚨 Reperfusion: **angioplastia primaria** < 90 min (preferida).\\n\\n'\n"
    "            '💊 **AAS**: 300 mg VO (mastigar).\\n\\n'\n"
    "            '💊 **Clopidogrel**: 300 mg VO.\\n\\n'\n"
    "            '💊 **Heparina**: 5000 UI IV bolo.\\n\\n'\n"
    "            '⛔ Contraindicacion **trombolisis**: sangrado activo, ACV < 3 meses.\\n\\n'\n"
    "            '📌 ¿Iniciar **trombólisis** o esperar **angioplastia** disponible?\\n'\n"
    "            'INCORRECTO (JAMAS hagas esto): \"  * **AAS**: 300 mg\" — ese espacio inicial rompe el render.\\n'\n"
    "            '════ FIN REGLA Nº1 ════\\n'\n"
    "            'REGLAS SOBERANAS ADICIONALES DE FORMATO Y COMPACTACION (BUILD 275):\\n'\n"
    "            '• DOBLE SALTO OBLIGATORIO: entre cada linea o bloque, inserta \\\\n\\\\n — NUNCA \\\\n solo.\\n'\n"
    "            '• EMOJI 🟥 UNICO: aparece EXACTAMENTE UNA VEZ en la primera linea. PROHIBIDO repetirlo.\\n'\n"
    "            '• TECHO ESTRICTO: MAXIMO 15 LINEAS y MAXIMO 800 CARACTERES TOTALES. '\n"
    "            'Si alcanzas el techo, corta y cierra con el gancho 📌.\\n'\n"
    "            '• EXTERMINIO VERBAL: PROHIBIDO \"Precaucion con fluidos\", \"En casos seleccionados\", '\n"
    "            '\"Considerar ajuste\", \"Monitorizar de cerca\". Cada linea = orden ejecutiva corta.\\n'\n"
    "            '• NEGRITAS SOLO EN NOMBRE DEL FARMACO: \"* **Norepinefrina**: 0,05 mcg/kg/min IV (PAM > 65).\" '\n"
    "            'PROHIBIDO negritar frases enteras, metas numericas o titulos de bloque.\\n'\n"
)
new_es_stream = (
    "          ? '════ REGLA Nº1 — COLUMNA CERO ABSOLUTA ════\\n'\n"
    "            'PROHIBICION NIVEL BINARIO: el 1er char de CADA linea DEBE ser: *, 🟥, 🚨, 💊, ⛔, 📌, letra/numero. '\n"
    "            'JAMAS espacio (ASCII 32) o tabulacion (ASCII 9) — Flutter renderiza como bloque <pre>.\\n'\n"
    "            'EJEMPLO CORRECTO: \"🟥 **IAM con SDST**\" | INCORRECTO: \"  * **AAS**\" (espacio rompe render).\\n'\n"
    "            '════ FIN REGLA Nº1 ════\\n'\n"
    "            'REGLAS SOBERANAS:\\n'\n"
    "            '• DOBLE SALTO OBLIGATORIO: entre cada linea/bloque → \\\\n\\\\n, NUNCA \\\\n solo.\\n'\n"
    "            '• EMOJI 🟥 UNICO: aparece EXACTAMENTE UNA VEZ en la primera linea.\\n'\n"
    "            '• TECHO ESTRICTO: MAX 15 LINEAS y MAX 800 CHARS. Si alcanzas el techo → cerrar con 📌.\\n'\n"
)

# --- PT version ---
old_pt_stream = (
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
    "            'PROIBIDO negritar frases inteiras, metas numericas ou titulos de bloco.\\n'\n"
)
new_pt_stream = (
    "          : '════ REGRA Nº1 — COLUNA ZERO ABSOLUTA ════\\n'\n"
    "            'PROIBICAO NIVEL BINARIO: o 1º char de CADA linha DEVE ser: *, 🟥, 🚨, 💊, ⛔, 📌, letra/numero. '\n"
    "            'JAMAIS espaco (ASCII 32) ou tabulacao (ASCII 9) — Flutter renderiza como bloco <pre>.\\n'\n"
    "            'EXEMPLO CORRETO: \"🟥 **IAM com SDST**\" | INCORRETO: \"  * **AAS**\" (espaco quebra render).\\n'\n"
    "            '════ FIM REGRA Nº1 ════\\n'\n"
    "            'REGRAS SOBERANAS:\\n'\n"
    "            '• DUPLA QUEBRA OBRIGATORIA: entre cada linha/bloco → \\\\n\\\\n, NUNCA \\\\n isolado.\\n'\n"
    "            '• EMOJI 🟥 UNICO: aparece EXATAMENTE UMA VEZ na primeira linha.\\n'\n"
    "            '• TETO ESTRITO: MAX 15 LINHAS e MAX 800 CHARS. Se atingir o teto → encerrar com 📌.\\n'\n"
)

if old_es_stream in src:
    src = src.replace(old_es_stream, new_es_stream, 1)
    cuts.append(('D-ES', 'ptStreamFormat ES', len(old_es_stream) - len(new_es_stream)))
else:
    print('  ✗ CUT D-ES: NOT FOUND — manual check required')

if old_pt_stream in src:
    src = src.replace(old_pt_stream, new_pt_stream, 1)
    cuts.append(('D-PT', 'ptStreamFormat PT', len(old_pt_stream) - len(new_pt_stream)))
else:
    print('  ✗ CUT D-PT: NOT FOUND — manual check required')

# ══════════════════════════════════════════════════════════════════════════════
# CUT E — ptUxFlowDoctrine: condense bullet 2 + 3 examples → 1
# ══════════════════════════════════════════════════════════════════════════════

old_es_ux = (
    "          ? 'DOCTRINA DE FLUJO UX MEDCASES PRO (BUILD 275-ADENDO — MAXIMA PRIORIDAD):\\n'\n"
    "            '• RESPUESTA = DISPARO DE IMPACTO INICIAL SOLAMENTE: '\n"
    "            'Tu respuesta es EXCLUSIVAMENTE la Conducta Directa Seca — el disparo inicial de accion. '\n"
    "            'El seguimiento del caso (monitorizacion, ramificaciones Si/No, criterios de reperfusion, '\n"
    "            'escalada terapeutica) sera conducido por los BOTONES DE ACCION DINAMICOS del front-end. '\n"
    "            'JAMAS gastes caracteres explicando lo que viene despues ni describiendo el flujo de seguimiento.\\n'\n"
    "            '• ELIMINA LISTAS GENERICAS DE ESTABILIZACION: '\n"
    "            'Si la query ya contiene datos clinicos explicitos (peso, PA, FC, saturacion, diagnóstico), '\n"
    "            'SUPRIME COMPLETAMENTE las listas de estabilizacion generalistas '\n"
    "            '(ej: \"Monitoreo cardiaco continuo\", \"Dos accesos calibrosos\", \"Oxigenacion suplementaria\"). '\n"
    "            'Esas listas son RUIDO — el medico ya sabe. Foca 100% en farmacologia inmediata, '\n"
    "            'alertas fatales especificos del caso y en el gancho de decision.\\n'\n"
    "            '• GANCHO 📌 = PREGUNTA CERRADA DE DECISION CLINICA: '\n"
    "            'La ultima linea SIEMPRE termina con 📌 seguido de una pregunta cerrada de bifurcacion '\n"
    "            'de decision que el medico puede responder con un boton (Si/No, A/B, Confirmar/Ajustar). '\n"
    "            'Ejemplos correctos: '\n"
    "            '\"📌 ¿Iniciar **trombólisis** o seguir con **heparina** solamente?\" — '\n"
    "            '\"📌 ¿Doblar dosis de **norepinefrina** o agregar **vasopresina**?\" — '\n"
    "            '\"📌 ¿Evaluar criterios de IOT o continuar **VNI**?\"\\n'\n"
    "            'Ejemplo PROHIBIDO: \"📌 Ver protocolo completo.\" (no es pregunta de decision).\\n'\n"
)
new_es_ux = (
    "          ? 'DOUTRINA UX MEDCASES:\\n'\n"
    "            '• RESPOSTA = GATILHO INICIAL: so Conduta Direta Seca. Seguimento = botoes dinamicos do front-end. '\n"
    "            'JAMAIS descreva fluxo de seguimento ou repita monitorização generica.\\n'\n"
    "            '• SUPRIMA listas genericas se query ja tem dados clinicos (peso, PA, FC, sato2, diagnostico).\\n'\n"
    "            '• GANCHO 📌 OBRIGATORIO na ultima linha: pergunta fechada de decisao clinica (Sim/Nao, A/B). '\n"
    "            'Ex: \"📌 Iniciar **trombólise** ou manter **heparina**?\" '\n"
    "            'PROIBIDO: \"📌 Ver protocolo completo.\"\\n'\n"
)

old_pt_ux = (
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
    "            'Exemplo PROIBIDO: \"📌 Ver protocolo completo.\" (nao e pergunta de decisao).\\n'\n"
)
new_pt_ux = (
    "          : 'DOUTRINA UX MEDCASES:\\n'\n"
    "            '• RESPOSTA = GATILHO INICIAL: so Conduta Direta Seca. Seguimento = botoes dinamicos do front-end. '\n"
    "            'JAMAIS descreva fluxo de seguimento ou repita monitorização generica.\\n'\n"
    "            '• SUPRIMA listas genericas se query ja tem dados clinicos (peso, PA, FC, sato2, diagnostico).\\n'\n"
    "            '• GANCHO 📌 OBRIGATORIO na ultima linha: pergunta fechada de decisao clinica (Sim/Nao, A/B). '\n"
    "            'Ex: \"📌 Iniciar **trombólise** ou manter **heparina**?\" '\n"
    "            'PROIBIDO: \"📌 Ver protocolo completo.\"\\n'\n"
)

if old_es_ux in src:
    src = src.replace(old_es_ux, new_es_ux, 1)
    cuts.append(('E-ES', 'ptUxFlowDoctrine ES', len(old_es_ux) - len(new_es_ux)))
else:
    print('  ✗ CUT E-ES: NOT FOUND')

if old_pt_ux in src:
    src = src.replace(old_pt_ux, new_pt_ux, 1)
    cuts.append(('E-PT', 'ptUxFlowDoctrine PT', len(old_pt_ux) - len(new_pt_ux)))
else:
    print('  ✗ CUT E-PT: NOT FOUND')

# ══════════════════════════════════════════════════════════════════════════════
# CUT F — ptAntiParroting: collapse to 1 tight sentence
# ══════════════════════════════════════════════════════════════════════════════

old_es_ap = (
    "          ? 'DIRECTRIZ DE SEGURIDAD CONTRA ENVENENAMIENTO DE HISTORIAL: '\n"
    "            'Puedes recibir en el historial de mensajes strings de error del sistema como '\n"
    "            '\"REVISANDO RESPOSTA\", \"datos inconsistentes y fue bloqueada por seguridad\", '\n"
    "            '\"Reformule la pregunta\", \"REVISANDO RESPUESTA\", cualquier texto con '\n"
    "            '\"bloqueada por seguridad\" o \"Reformule\" o que empiece con 🟥 REVISANDO. '\n"
    "            'ESTAS ABSOLUTAMENTE PROHIBIDO DE REPETIR, ECOAR, COPIAR O BASARTE EN ESAS '\n"
    "            'STRINGS DE ERROR TECNICO. Son basura de sistema legada. Ignoralas completamente. '\n"
    "            'Trata cada turno de mensaje como una oportunidad pura de proporcionar conduta medica real. '\n"
    "            'Nunca simules un mensaje de error de la aplicacion.\\n'\n"
)
new_es_ap = (
    "          ? 'ANTI-HISTORIAL: ignora strings como \"REVISANDO RESPOSTA\"/\"bloqueada por seguridad\" — lixo legado. Responde conduta medica pura.\\n'\n"
)

old_pt_ap = (
    "          : 'DIRETRIZ DE SEGURANCA CONTRA ENVENENAMENTO DE HISTORICO: '\n"
    "            'Voce pode receber no historico de mensagens strings de erro do sistema como '\n"
    "            '\"REVISANDO RESPOSTA\", \"dados inconsistentes e foi bloqueada por seguranca\", '\n"
    "            '\"Reformule a pergunta\", qualquer texto com '\n"
    "            '\"bloqueada por seguranca\" ou \"Reformule a pergunta\" ou que comece com 🟥 REVISANDO. '\n"
    "            'VOCE ESTA ABSOLUTAMENTE PROIBIDO DE REPETIR, ECOAR, COPIAR OU SE BASEAR '\n"
    "            'NESSAS STRINGS DE ERRO TECNICO. Elas sao lixo de sistema legado. Ignore-as completamente. '\n"
    "            'Trate cada turno de mensagem como uma oportunidade pura de fornecer conduta medica real. '\n"
    "            'Nunca simule uma mensagem de erro do aplicativo.\\n'\n"
)
new_pt_ap = (
    "          : 'ANTI-HISTORICO: ignore strings como \"REVISANDO RESPOSTA\"/\"bloqueada por seguranca\" — lixo legado. Responda conduta medica pura.\\n'\n"
)

if old_es_ap in src:
    src = src.replace(old_es_ap, new_es_ap, 1)
    cuts.append(('F-ES', 'ptAntiParroting ES', len(old_es_ap) - len(new_es_ap)))
else:
    print('  ✗ CUT F-ES: NOT FOUND')

if old_pt_ap in src:
    src = src.replace(old_pt_ap, new_pt_ap, 1)
    cuts.append(('F-PT', 'ptAntiParroting PT', len(old_pt_ap) - len(new_pt_ap)))
else:
    print('  ✗ CUT F-PT: NOT FOUND')

# ══════════════════════════════════════════════════════════════════════════════
# CUT G — _specialtyAdaptationPlantao: remove cardio/UTI/infecto taxonomy lines
#          Keep only: Pediatria (mg/kg) + Farmaco (TFG/hepatic)
# ══════════════════════════════════════════════════════════════════════════════

old_es_spec = (
    "  static const _specialtyAdaptationPlantaoEs =\n"
    "      'ESPECIALIDAD — adapta tecnica y terminologia al tema detectado:\\n'\n"
    "      'Cardio: jerarquia BB/IECA/ARNI/iSGLT2, ECG, reperfusion. Base: AHA/ESC.\\n'\n"
    "      'UTI/Emerg: MOV/ABCDE, vasopresores+PAM, sepsis bundle-1h, VM 6ml/kg.\\n'\n"
    "      'Infecto: empirico primero, desescalamiento por culturas. Base: IDSA.\\n'\n"
    "      'Pediatria: dosis mg/kg SIEMPRE, no extrapolar adulto.\\n'\n"
    "      'Farmaco: mecanismo, ajuste TFG/hepatico, interacciones nivel MAYOR.\\n';\n"
)
new_es_spec = (
    "  static const _specialtyAdaptationPlantaoEs =\n"
    "      'Pediatria: dosis mg/kg SIEMPRE, no extrapolar adulto.\\n'\n"
    "      'Farmaco: ajuste TFG/hepatico, interacciones nivel MAYOR.\\n';\n"
)

old_pt_spec = (
    "  static const _specialtyAdaptationPlantaoPt =\n"
    "      'ESPECIALIDADE — adapta tecnica e terminologia ao tema detectado:\\n'\n"
    "      'Cardio: hierarquia BB/IECA/ARNI/iSGLT2, ECG, reperfusao. Base: AHA/ESC.\\n'\n"
    "      'UTI/Emerg: MOV/ABCDE, vasopressores+PAM, sepse bundle-1h, VM 6ml/kg.\\n'\n"
    "      'Infecto: empirico primeiro, desescalonamento por culturas. Base: IDSA.\\n'\n"
    "      'Pediatria: doses mg/kg SEMPRE, nao extrapolar adulto.\\n'\n"
    "      'Farmaco: mecanismo, ajuste TFG/hepatico, interacoes nivel MAIOR.\\n';\n"
)
new_pt_spec = (
    "  static const _specialtyAdaptationPlantaoPt =\n"
    "      'Pediatria: doses mg/kg SEMPRE, nao extrapolar adulto.\\n'\n"
    "      'Farmaco: ajuste TFG/hepatico, interacoes nivel MAIOR.\\n';\n"
)

if old_es_spec in src:
    src = src.replace(old_es_spec, new_es_spec, 1)
    cuts.append(('G-ES', '_specialtyAdaptationPlantaoEs', len(old_es_spec) - len(new_es_spec)))
else:
    print('  ✗ CUT G-ES: NOT FOUND')

if old_pt_spec in src:
    src = src.replace(old_pt_spec, new_pt_spec, 1)
    cuts.append(('G-PT', '_specialtyAdaptationPlantaoPt', len(old_pt_spec) - len(new_pt_spec)))
else:
    print('  ✗ CUT G-PT: NOT FOUND')

# ══════════════════════════════════════════════════════════════════════════════
# Write result
# ══════════════════════════════════════════════════════════════════════════════
if cuts:
    with open(path, 'w', encoding='utf-8') as f:
        f.write(src)
    total_saved = sum(c[2] for c in cuts)
    print(f'\nCuts applied: {len(cuts)}')
    for c in cuts:
        print(f'  ✓ {c[0]}: {c[1]} (~{c[2]}c saved)')
    print(f'\nSource chars removed from ai_service.dart: {total_saved}')
    print(f'File size: {orig_len} → {len(src)} chars')
else:
    print('No cuts applied.')
