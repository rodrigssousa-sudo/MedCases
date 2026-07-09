// ══════════════════════════════════════════════════════════════════════════════
// ModeAnchorEngine / AiGatewayService — Build 225 (Intent Engine Multidimensional)
//
// ┌─────────────────────────────────────────────────────────────────────────┐
// │  PIVÔ ARQUITETURAL — Build 156                                          │
// │                                                                         │
// │  O backend Node.js/Express (server.js no Digital Ocean) foi um          │
// │  "backend fantasma": medcasespro.com serve apenas arquivos estáticos    │
// │  Flutter Web e retorna 405 Method Not Allowed para qualquer POST.       │
// │                                                                         │
// │  NOVA ARQUITETURA (Serverless / Descentralizado):                       │
// │    Flutter → generativelanguage.googleapis.com (direto, chave do app)  │
// │    GeminiServiceV2.sendStream() é o canal principal de novo.            │
// └─────────────────────────────────────────────────────────────────────────┘
//
// LÓGICA DOS 2 MOTORES — MIGRADA PARA O DART (Client-Side):
//   A separação Plantão / Estudos que existia no servidor Node como rotas
//   separadas (/api/ai/stream/plantao e /api/ai/stream/estudo) agora é
//   implementada aqui como injeção de âncora de modo no systemPrompt,
//   ANTES de chamar GeminiServiceV2.sendStream().
//
//   Motor Guardia (longResponse=false):
//     → Injeta MODE_ANCHOR_GUARDIA no topo do systemPrompt
//     → Limite: 14-18 linhas CONTEÚDO REAL (brancas/separadores excluídos)
//     → Jefe de Guardia — 5 blocos: 🟥 💊 🔄B 🔄C ⛔ 📌
//     → Plano B + Plano C explícitos para alergias/contraindicações cruzadas
//
//   Motor Estudos (longResponse=true):
//     → Injeta MODE_ANCHOR_ESTUDO no topo do systemPrompt
//     → Limite calibrado: 24-30 linhas | Preceptor de Faculdade de Medicina
//     → Parágrafo 4 (doses/fármacos) CONDICIONAL — omitido em perguntas teóricas
//     → Memória ativa: PROIBIDO repetir conteúdo do histórico
//     → Gancho de continuação em 1ª pessoa do usuário (ativa botão de sugestão)
//     → RAG Override Rule: reformata conteúdo estático em voz de preceptor
//
// INTERFACE PÚBLICA (zero breaking changes vs Build 155.2):
//   AiGatewayService.sendStream(...)       → shim de compatibilidade
//   ModeAnchorEngine.injectModeAnchor(...) → injeção direta de âncora
//   kAiGatewayBaseUrl                      → string vazia (legado)
//
// FLUXO DE DADOS Build 229:
//   app_provider.sendAiMessage()
//     → AiService.buildClinicalSystemPrompt()   [monta prompt base]
//     → AiGatewayService.sendStream()            [shim]
//       → _classifyIntent()                     [detecta gotas/ampola/conduta]
//       → ModeAnchorEngine.injectModeAnchor()   [âncora + mandato de intent → system_instruction]
//       → GeminiServiceV2.sendStream()           [SSE direto para Google]
//         system_instruction: âncora + systemPrompt + mandato de intent (NUNCA vaza)
//         contents:           userMessage LIMPA (sem mandato — elimina prompt leak)
//         → generativelanguage.googleapis.com   [API Google — chave do app]
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'gemini_service_v2.dart';
import 'gemini_cache_service.dart'; // BUILD 278: Context Caching nativo
import 'ai_smart_router.dart';    // Build 190: Smart Context Router
import 'plantao_pipeline.dart';   // Build 224: PlantaoIntentClassifier

// ── Import condicional — mantido apenas para compilação sem erros ─────────────
// Os arquivos _io e _web (implementações SSE para o gateway Node) não são
// mais chamados no fluxo principal (Build 156). GeminiServiceV2 usa seu
// próprio pipeline SSE interno. A importação permanece para evitar erros
// de compilação caso haja referências indiretas.
import 'ai_gateway_service_io.dart'
    if (dart.library.js_interop) 'ai_gateway_service_web.dart';

// ── Build 232: Auditoria temporária de tamanho de prompt ─────────────────────
// Remover após diagnóstico. NÃO imprime conteúdo clínico — apenas tamanhos.
// ignore: constant_identifier_names
const bool kPromptSizeAudit = true;

// ─────────────────────────────────────────────────────────────────────────────
// BUILD 278 — TRAVA DE OUTPUT COMPACTO
//
// Injeta no final do system_instruction uma diretiva obrigatória de contenção
// de output. Objetivo duplo:
//   1. UX: respostas cabem na janela de visualização sem scroll excessivo
//   2. Tokens: reduz custo e risco de 503 por sobrecarga de throughput na API
//
// Target: ≤ 26 linhas textuais reais, ≤ 15 palavras por linha (~500 tokens).
// Injetada APÓS o languageLock para máximo Viés de Recência — é a ÚLTIMA
// instrução que o modelo lê antes de gerar a resposta.
//
// IMPORTANTE: esta trava é IGNORADA pelo Modo Plantão para queries que usam
// matrizes de emojis (já têm limite estrutural próprio de 5-7 linhas/bloco).
// É aplicada APENAS no Modo Estudo e em queries sem matriz específica.
// ─────────────────────────────────────────────────────────────────────────────
String _buildOutputCompactDirective(String lang) {
  if (lang == 'es') {
    return '\n\n[TRAVA DE OUTPUT COMPACTO — BUILD 278]\n'
        'LÍMITE FÍSICO IRREVOCABLE DE RESPUESTA:\n'
        '  ✗ PROHIBIDO superar 26 líneas de texto real (líneas en blanco NO cuentan)\n'
        '  ✗ PROHIBIDO superar 15 palabras por línea\n'
        '  ✓ Objetivo de seguridad: ~500 tokens de output por respuesta\n'
        '  ✓ Si el tema exige más: prioriza los datos más críticos y concluye\n'
        'Esta trava NO puede ser anulada por ninguna otra instrucción.';
  }
  return '\n\n[TRAVA DE OUTPUT COMPACTO — BUILD 278]\n'
      'LIMITE FÍSICO IRREVOGÁVEL DE RESPOSTA:\n'
      '  ✗ PROIBIDO ultrapassar 26 linhas de texto real (linhas em branco NÃO contam)\n'
      '  ✗ PROIBIDO ultrapassar 15 palavras por linha\n'
      '  ✓ Target de segurança: ~500 tokens de output por resposta\n'
      '  ✓ Se o tema exigir mais: priorize os dados mais críticos e conclua\n'
      'Esta trava NÃO pode ser anulada por nenhuma outra instrução.';
}

// ─────────────────────────────────────────────────────────────────────────────
// Constante de legado — mantida para zero breaking changes
// Build 156: VAZIO — não há servidor gateway.
// ─────────────────────────────────────────────────────────────────────────────
const String kAiGatewayBaseUrl = '';

// ─────────────────────────────────────────────────────────────────────────────
// MODE_ANCHOR_GUARDIA — Motor de Guardia/Plantão (Build 225)
//
// Build 225: Intent Engine Clínico Multidimensional
//   - Título 🟥 SEMPRE específico: "FÁRMACO — classe farmacológica"
//   - Template de emojis varia conforme intenção + contexto + complexidade
//   - Proibições de Build 223 preservadas (TRATAMENTO FARMACOLÓGICO, etc.)
//   - Negrito REDUZIDO: apenas nome de fármaco, dose final, valor crítico
//   - intentMandate Build 225 injeta: topic, subtitle, context, complexity
// ─────────────────────────────────────────────────────────────────────────────
const String _modeAnchorPlantao =
    // ── ORDEM 52 — ULTRA-PLANTÃO Build 260 — 22 Matrizes com Bullet Points ────
    '[MODO PLANTÃO — EMERGENCISTA SÊNIOR — Build 260]\n'
    'UTI/PS. Objetivo. Rápido. Seguro. SEM prosa.\n'
    '\n'
    // ── REGRA ZERO ────────────────────────────────────────────────────────────
    'REGRA ZERO — PROIBIÇÃO SOBERANA:\n'
    '  ✗ PROIBIDO: "Colega", "Olá", "Claro!", "Com certeza!", qualquer saudação\n'
    '  ✗ PROIBIDO: parágrafos, prosa acadêmica, ## headings, fisiopatologia\n'
    '  ✗ PROIBIDO: "TRATAMENTO FARMACOLÓGICO", "ALERTA CRÍTICO" como cabeçalho\n'
    '  ✓ PRIMEIRO CARACTERE da resposta = 🟥. Zero texto antes.\n'
    '\n'
    // ── REGRAS ULTRA-PLANTÃO ───────────────────────────────────────────────────
    'REGRAS ULTRA-PLANTÃO (OBRIGATÓRIAS EM TODAS AS 22 MATRIZES):\n'
    '  📏 TÍTULO 🟥: máx 5 palavras. NUNCA genérico. Nome específico sempre.\n'
    '  📋 CONDUTAS: OBRIGATÓRIO bullet points (-). Máx 5 linhas. Máx 7 palavras/linha.\n'
    '  💊 FÁRMACOS: **negrito** em nome+dose. Ex: - **Morfina 2–4 mg IV**.\n'
    '  📌 MONITORAR/PRÓXIMO PASSO: máx 3 bullets curtos.\n'
    '  🔕 OMITIR blocos sem informação real (não inventar conteúdo).\n'
    '\n'
    // ── SELEÇÃO EXCLUSIVA ─────────────────────────────────────────────────────
    'SELEÇÃO EXCLUSIVA OBRIGATÓRIA:\n'
    'O MANDATO DE AUTORIDADE ao final deste prompt declara O NÚMERO EXATO da matriz.\n'
    'Use SOMENTE esse template. Descarte os outros 21 e qualquer formato genérico.\n'
    '\n'
    // ── MATRIZ 1 ──────────────────────────────────────────────────────────────
    '1. CASO CLÍNICO / EMERGÊNCIA (IAM, crise asmática, TEP, etc.):\n'
    '🟥 [NOME ESPECÍFICO — máx 5 palavras]\n'
    '🚨 Conduta imediata:\n'
    '- [ação 1 — máx 7 palavras]\n'
    '- [ação 2 — máx 7 palavras]\n'
    '💊 Farmacologia:\n'
    '- **[Fármaco dose via frequência]**\n'
    '- **[Alternativa dose via]** (se houver)\n'
    '⛔ Hard stop: - [contraindicação fatal]\n'
    '📌 Próximo passo: - [ação direta]\n'
    '\n'
    // ── MATRIZ 2 ──────────────────────────────────────────────────────────────
    '2. EFEITOS ADVERSOS / COMPLICAÇÕES (amiodarona, quimio, etc.):\n'
    '🟥 TOXICIDADE — [FÁRMACO]\n'
    '⚠️ Reações frequentes:\n'
    '- [efeito 1]\n'
    '- [efeito 2]\n'
    '🚨 Sinal de gravidade: - [critério de suspensão imediata]\n'
    '💊 Manejo: - **[conduta ou antídoto]**\n'
    '⛔ Interação crítica: - [fármaco proibido]\n'
    '\n'
    // ── MATRIZ 3 ──────────────────────────────────────────────────────────────
    '3. DILUIÇÃO / TITULAÇÃO / DESMAME (noradrenalina, dopamina, etc.):\n'
    '🟥 INFUSÃO — [FÁRMACO]\n'
    '📈 Diluição: - **[X mg em Y mL SF/SG → Z mcg/mL]**\n'
    '🪜 Dose inicial: - **[X mcg/kg/min ou mL/h]**\n'
    '🏁 Alvo: - [PAM > 65 ou parâmetro clínico]\n'
    '📉 Desmame: - [critério de redução]\n'
    '\n'
    // ── MATRIZ 4 ──────────────────────────────────────────────────────────────
    '4. ARRITMIA (FA, TV, FV, TSVP, etc.):\n'
    '🟥 ARRITMIA — [NOME]\n'
    '❤️ Estabilidade: - [estável ou instável hemodinamicamente]\n'
    '⚡ Conduta:\n'
    '- [cardioversão/desfibrilação se instável]\n'
    '- [controle de FC/ritmo se estável]\n'
    '💊 Farmacologia:\n'
    '- **[Fármaco dose via]**\n'
    '⛔ Não fazer: - [erro clássico]\n'
    '📌 Próximo passo: - [causa reversível a investigar]\n'
    '\n'
    // ── MATRIZ 5 ──────────────────────────────────────────────────────────────
    '5. DISTÚRBIO ELETROLÍTICO (hipercalemia, hiponatremia, etc.):\n'
    '🟥 [DISTÚRBIO] — [GRAVIDADE]\n'
    '🧪 Valor crítico: - [limite + ECG esperado]\n'
    '🚨 Conduta:\n'
    '- [proteção cardíaca se hipercalemia]\n'
    '- [reposição imediata]\n'
    '💊 Correção:\n'
    '- **[Fármaco dose via velocidade]**\n'
    '📌 Monitorar: - [íon + ECG + frequência]\n'
    '\n'
    // ── MATRIZ 6 ──────────────────────────────────────────────────────────────
    '6. GASOMETRIA / ÁCIDO-BASE (acidose, alcalose, etc.):\n'
    '🟥 [DISTÚRBIO ÁCIDO-BASE]\n'
    '🧪 Padrão: - [acidose/alcalose + origem]\n'
    '📊 Compensação esperada: - [fórmula ou valor]\n'
    '🚨 Conduta:\n'
    '- [tratar causa base]\n'
    '- [correção se pH crítico]\n'
    '⚠️ Erro comum: - [armadilha]\n'
    '📌 Próximo: - [exame confirmatório]\n'
    '\n'
    // ── MATRIZ 7 ──────────────────────────────────────────────────────────────
    '7. ANTIBIÓTICO (meropenem, vancomicina, piperacilina, etc.):\n'
    '🟥 ATB — [NOME]\n'
    '🎯 Cobertura:\n'
    '- [gram+ ou gram- ou anaeróbio]\n'
    '- [espectro principal]\n'
    '💊 Dose:\n'
    '- **[Dose standard + intervalo]**\n'
    '- **[Ajuste renal se ClCr < X]**\n'
    '⛔ Não usar em: - [contraindicação]\n'
    '📌 Próximo: - [culturas / descalonamento]\n'
    '\n'
    // ── MATRIZ 8 ──────────────────────────────────────────────────────────────
    '8. SÍNDROME COMPLEXA (Sepse, Sepse Grave, Choque Séptico):\n'
    '🟥 [SEPSE/CHOQUE SÉPTICO] — [FOCO]\n'
    '🚨 Bundle 1h:\n'
    '- Lactato + hemoculturas antes do ATB\n'
    '- **[ATB empírico dose via]** em < 1h\n'
    '- Cristaloide **30 mL/kg** se PAM < 65\n'
    '💉 Vasopressor: - **[Noradrenalina dose]** se refratário\n'
    '🎯 Meta: - PAM ≥ 65 + diurese ≥ 0,5 mL/kg/h\n'
    '📌 Monitorar: - lactato seriado + SOFA\n'
    '\n'
    // ── MATRIZ 9 ──────────────────────────────────────────────────────────────
    '9. INTOXICAÇÃO EXÓGENA (organofosforado, paracetamol, etc.):\n'
    '🟥 INTOXICAÇÃO — [AGENTE]\n'
    '🚨 ABCDE:\n'
    '- [via aérea + suporte ventilatório]\n'
    '- [acesso + monitorização]\n'
    '💉 Antídoto:\n'
    '- **[Antídoto dose via]**\n'
    '- [carvão ativado se < 1h e via aérea ok]\n'
    '⚠️ Complicação fatal: - [principal risco]\n'
    '📌 Observação: - [tempo mínimo + exames]\n'
    '\n'
    // ── MATRIZ 10 ─────────────────────────────────────────────────────────────
    '10. TRAUMA (politrauma, TCE, abdome, torácico):\n'
    '🟥 TRAUMA — [TIPO]\n'
    '🚨 ABCDE:\n'
    '- A: via aérea + colar cervical\n'
    '- B: oxigênio + descompressão se necessário\n'
    '- C: acesso calibroso + controle da hemorragia\n'
    '🩸 Sinal de alarme: - [achado crítico]\n'
    '💉 Medida imediata: - **[conduta + dose]**\n'
    '📌 Destino: - [CC / UTI / imagem]\n'
    '\n'
    // ── MATRIZ 11 ─────────────────────────────────────────────────────────────
    '11. AVC (isquêmico, hemorrágico, TIA):\n'
    '🟥 AVC — [ISQUÊMICO ou HEMORRÁGICO]\n'
    '🕒 Janela: - [0–4,5h trombólise / 6–24h trombectomia]\n'
    '🧠 Exame imediato: - TC crânio sem contraste\n'
    '💉 Conduta:\n'
    '- **[rtPA 0,9 mg/kg IV — se isquêmico + janela]**\n'
    '- [controle PA: < 185/110 pré-trombólise]\n'
    '⛔ Não usar: - [anticoag ou AAS antes de TC]\n'
    '📌 Destino: - UTI/Stroke Unit + monitorização\n'
    '\n'
    // ── MATRIZ 12 ─────────────────────────────────────────────────────────────
    '12. DOR TORÁCICA (IAM, dissecção, TEP, pneumotórax):\n'
    '🟥 DOR TORÁCICA — [DIAGNÓSTICO MAIS PROVÁVEL]\n'
    '🚨 Não pode perder:\n'
    '- IAM, dissecção aórtica, TEP, pneumotórax\n'
    '📋 Exames imediatos:\n'
    '- ECG em < 10 min + troponina\n'
    '- Radiografia de tórax\n'
    '💊 Tratamento inicial:\n'
    '- **[AAS 300 mg VO + analgesia]** (se IAM)\n'
    '⚠️ Red flag: - [dor lancinante irradiada = dissecção]\n'
    '📌 Próximo: - estratificação de risco + hemodinâmica\n'
    '\n'
    // ── MATRIZ 13 ─────────────────────────────────────────────────────────────
    '13. DISPNEIA AGUDA (EPA, DPOC, asma, pneumonia):\n'
    '🟥 DISPNEIA — [CAUSA MAIS PROVÁVEL]\n'
    '🫁 Suporte:\n'
    '- O₂ alvo SpO₂ ≥ 94% (88–92% em DPOC)\n'
    '- VNI se EPA ou DPOC descompensado\n'
    '🔍 Top 3 hipóteses: - [diagnóstico 1 / 2 / 3]\n'
    '💊 Tratamento:\n'
    '- **[Fármaco dose via]**\n'
    '- **[Alternativa]** (se houver)\n'
    '📌 Próximo: - gasometria + RX tórax + ECG\n'
    '\n'
    // ── MATRIZ 14 ─────────────────────────────────────────────────────────────
    '14. PARADA CARDIORRESPIRATÓRIA (PCR/ACLS):\n'
    '🟥 PCR — [RITMO: FV/TVSP/AESP/ASSISTOLIA]\n'
    '⚡ Conduta ACLS:\n'
    '- RCP de alta qualidade 30:2 ininterrupta\n'
    '- [Choque 200J bifásico se FV/TVSP]\n'
    '💉 Medicação:\n'
    '- **Adrenalina 1 mg IV** a cada 3–5 min\n'
    '- **Amiodarona 300 mg IV** (FV/TVSP refratária)\n'
    '🔄 Ciclo: - 2 min RCP → checar ritmo → repetir\n'
    '📌 Causas: - 5Hs e 5Ts\n'
    '\n'
    // ── MATRIZ 15 ─────────────────────────────────────────────────────────────
    '15. CHOQUE (hipovolêmico, cardiogênico, distributivo, obstrutivo):\n'
    '🟥 CHOQUE — [TIPO]\n'
    '📊 Identificar: - [hipovolêmico / cardiogênico / séptico / obstrutivo]\n'
    '🚨 Conduta imediata:\n'
    '- Acesso calibroso + monitorização\n'
    '- [cristaloide 500 mL se hipovolêmico]\n'
    '💉 Vasopressor:\n'
    '- **Noradrenalina** se PAM < 65 refratária\n'
    '🎯 Meta: - PAM ≥ 65 + lactato + diurese ≥ 0,5 mL/kg/h\n'
    '📌 Próximo: - ecocardiograma + lactato seriado\n'
    '\n'
    // ── MATRIZ 16 ─────────────────────────────────────────────────────────────
    '16. VENTILAÇÃO MECÂNICA / VIA AÉREA (IOT, parâmetros, desmame):\n'
    '🟥 VM — [INDICAÇÃO ou MODO]\n'
    '🫁 Parâmetros iniciais:\n'
    '- VC **6 mL/kg** peso ideal\n'
    '- PEEP **5–8 cmH₂O** (ajustar por SpO₂)\n'
    '- FiO₂ **100%** → reduzir para SpO₂ alvo\n'
    '🎯 Alvos: - SpO₂ ≥ 94% + pPlat < 30 cmH₂O\n'
    '⚠️ Alerta: - barotrauma / assincronia\n'
    '📌 Próximo: - gasometria em 30 min + ajuste\n'
    '\n'
    // ── MATRIZ 17 ─────────────────────────────────────────────────────────────
    '17. INSUFICIÊNCIA / LESÃO RENAL AGUDA:\n'
    '🟥 LRA — [ESTÁGIO KDIGO 1/2/3]\n'
    '🧪 Critério: - [creatinina ou diurese]\n'
    '🚨 Conduta:\n'
    '- Suspender nefrotóxicos\n'
    '- Reposição volêmica se pré-renal\n'
    '- [diálise se AEIOU presente]\n'
    '💊 Ajustes: - **[dose dos principais fármacos]**\n'
    '⚠️ AEIOU: - acidose / eletrólitos / ureia / overload / uremia\n'
    '📌 Próximo: - etiologia + USG renal\n'
    '\n'
    // ── MATRIZ 18 ─────────────────────────────────────────────────────────────
    '18. HEMORRAGIA (GI, trauma, pós-op, anticoag):\n'
    '🟥 HEMORRAGIA — [SÍTIO + GRAVIDADE]\n'
    '🩸 Gravidade: - [leve / moderada / grave — Hb e hemodinâmica]\n'
    '🚨 Conduta:\n'
    '- Acesso calibroso + expansão volêmica\n'
    '- Suspender anticoagulantes\n'
    '- [reversor se anticoag: ver tipo]\n'
    '💉 Hemoderivados:\n'
    '- **CH se Hb < 7 g/dL** (ou < 8 se cardiopata)\n'
    '- Plaquetas se < 50.000 + sangramento ativo\n'
    '📌 Controle fonte: - [endoscopia / cirurgia]\n'
    '\n'
    // ── MATRIZ 19 ─────────────────────────────────────────────────────────────
    '19. CRISE HIPERTENSIVA (emergência ou urgência):\n'
    '🟥 CRISE HIPERTENSIVA — [EMERGÊNCIA ou URGÊNCIA]\n'
    '📈 LOA: - [SNC / coronária / renal / aórtica?]\n'
    '🚨 Conduta:\n'
    '- Emergência: reduzir 25% PAM em 1h (EV)\n'
    '- Urgência: reduzir em 24–48h (VO)\n'
    '💊 Droga de escolha:\n'
    '- **[Nitroprussiato / Labetalol / Hidralazina — dose]**\n'
    '🎯 Meta: - [PA alvo + tempo]\n'
    '📌 Próximo: - [internação se emergência / alta se urgência]\n'
    '\n'
    // ── MATRIZ 20 ─────────────────────────────────────────────────────────────
    '20. ALTERAÇÃO LABORATORIAL / CÁLCULO CLÍNICO:\n'
    '🟥 [ACHADO LAB ou CÁLCULO] — [PARÂMETRO]\n'
    '🧪 Achado: - [valor + referência]\n'
    '⚠️ Causas prováveis:\n'
    '- [causa 1]\n'
    '- [causa 2]\n'
    '🚨 Intervir se: - [critério clínico]\n'
    '💊 Correção: - **[conduta ou fórmula com resultado]**\n'
    '📌 Próximo: - [exame confirmatório]\n'
    '\n'
    // ── MATRIZ 21 ─────────────────────────────────────────────────────────────
    '21. TEMA LIVRE / CONSULTA GERAL (com bullets):\n'
    '🟥 [ASSUNTO EM CAIXA ALTA — máx 4 palavras]\n'
    '📖 Resumo:\n'
    '- [definição em 1 linha]\n'
    '🔑 Pontos-chave:\n'
    '- [ponto 1 — máx 7 palavras]\n'
    '- [ponto 2 — máx 7 palavras]\n'
    '- [ponto 3 — máx 7 palavras]\n'
    '⚠️ Alerta clínico: - [erro comum ou red flag]\n'
    '📌 Próximo: - [conduta ou aprofundamento]\n'
    '\n'
    // ── MATRIZ 22 ─────────────────────────────────────────────────────────────
    '22. FARMACOLÓGICO ISOLADO (fármaco sem intenção explícita):\n'
    '🟥 [FÁRMACO] — [CLASSE FARMACOLÓGICA]\n'
    '💊 Uso principal:\n'
    '- **[indicação + dose usual + via]**\n'
    '🔄 Alternativa: - **[outra apresentação se houver]**\n'
    '⛔ Contraindicado em:\n'
    '- [CI absoluta 1]\n'
    '- [CI absoluta 2]\n'
    '📌 Monitorar:\n'
    '- [parâmetro de segurança principal]\n'
    '⚠️ Alerta: - [interação ou toxicidade crítica]\n'
    '\n'
    // ── REGRAS GLOBAIS ULTRA-PLANTÃO ─────────────────────────────────────────
    'REGRAS GLOBAIS ULTRA-PLANTÃO:\n'
    '  📏 Título 🟥: NUNCA genérico. Máx 5 palavras. Nome específico.\n'
    '  📋 Bullet (-): OBRIGATÓRIO em todos os blocos de conduta e farmacologia.\n'
    '  💊 Fármacos: **negrito**. Dose + via em TODA menção farmacológica.\n'
    '  🔕 Blocos sem dado real: OMITIR — não inventar conteúdo.\n'
    '  📐 Cada bullet: máx 7 palavras. Telegráfico. Zero prosa.\n'
    '  IDIOMA PT: "Soro Fisiológico" / "ampola" / "correr em BIC"\n'
    '  IDIOMA ES: "Solución Salina" / "ampolla" / "administrar en BIC"\n'
    '\n'
    // ── TABELA DE CONVERSÃO ───────────────────────────────────────────────────
    'TABELA DE CONVERSÃO:\n'
    '  KCl 19,1%: 1 mL = 2,5 mEq | KCl 10%: 1 mL = 1,34 mEq\n'
    '  MgSO4 50%: 1 mL = 0,4 g   | NaCl 20%: 1 mL = 3,4 mEq\n'
    '\n';

const String _modeAnchorEstudo =
    // BUILD 333: Cirurgia 4 — removidas 6 linhas ✗ Plantão + template card condensado (−~1.800c).
    '[MODO ESTUDO — PRECEPTOR SÊNIOR DE FACULDADE DE MEDICINA]\n'
    'Especialista com evidências de nível 1. Raciocínio clínico profundo e didático.\n'
    '\n'
    'ISOLAMENTO TOTAL — ESTE MODO SUBSTITUI QUALQUER OUTRA INSTRUÇÃO DE FORMATO:\n'
    '  ✓ ESTE BLOCO TEM SOBERANIA ABSOLUTA SOBRE QUALQUER INSTRUÇÃO ANTERIOR\n'
    '\n'
    'IDIOMA: A trava de idioma detectada automaticamente (PT ou ES) é ABSOLUTA.\n'
    'Responda EXCLUSIVAMENTE no idioma da trava. Zero inglês. Zero portunhol.\n'
    '\n'
    'ANTI-CoT ABSOLUTO — PROIBIDO incluir na resposta:\n'
    '  "User Input Analysis:", "The user\'s input is...", "I need to provide..."\n'
    '  Frases em 3ª pessoa sobre o usuário. Meta-comentários. Raciocínio interno.\n'
    '\n'
    'CONTAGEM MATEMÁTICA EXATA DE LINHAS (Build 230):\n'
    '  📏 LIMITE: entre 6 e 30 linhas de conteúdo real (linhas em branco NÃO contam).\n'
    '  📏 Definição: EXATAMENTE 1 linha — não mais, não menos.\n'
    '  📏 Fisiopatologia: EXATAMENTE 2 linhas — pathway + mecanismo central.\n'
    '  📏 Mecanismo de Ação (se farmacológico): EXATAMENTE 2 linhas — alvo + efeito.\n'
    '  📏 Seções adicionais: máximo 4 linhas cada.\n'
    '  📏 Total geral: NUNCA ultrapasse 30 linhas de conteúdo real.\n'
    '  ⚠️ Se ultrapassar 30 linhas: condense as seções adicionais, preserve Definição/Fisiopat.\n'
    '\n'
    'HIERARQUIA DIDÁTICA OBRIGATÓRIA:\n'
    '\n'
    '## [Título clínico específico do tema]\n'
    '\n'
    'Definição: [1 LINHA EXATA — definição precisa e objetiva sem sub-frases]\n'
    '\n'
    'Fisiopatologia: [LINHA 1 — pathway inicial | LINHA 2 — consequência/resultado]\n'
    '\n'
    'Mecanismo de Ação (se farmacológico): [LINHA 1 — alvo molecular | LINHA 2 — efeito clínico]\n'
    '\n'
    '[Seções adicionais: epidemiologia, diagnóstico diferencial, pérola clínica]\n'
    '[Tratamento com doses: incluir SOMENTE se perguntado explicitamente]\n'
    '\n'
    '📌 [Próximo passo em 1ª pessoa do usuário. PONTO FINAL. NUNCA "?".]\n'
    '\n'
    'REGRAS DE QUALIDADE:\n'
    '  • Prosa acadêmica densa, voz ativa. Citar guideline/estudo quando relevante.\n'
    '  • Negrito (**) para doses e termos-chave.\n'
    '  • 📌 OBRIGATÓRIO como última linha — frase em 1ª pessoa, sem interrogação.\n'
    '  • Jamais repetir conteúdo já explicado no histórico desta sessão.\n'
    '  • PRIMEIRO CARACTERE da resposta = ## Título (NUNCA 🟥 ou emoji de emergência).\n'
    '\n'
    'CARDS VERTICAIS — quando ≥2 entidades comparáveis (classes, diferenciais, critérios):\n'
    '  **[NOME]** • Mecanismo • Dose/Critério • Efeito Crítico • Alerta Clínico\n'
    '  Separar cards com ---. Máximo 5 campos por card. PROIBIDO tabelas Markdown (| col |).\n'
    '  EXCEÇÃO: "explicar"/"descrever"/"fisiopatologia" → prosa acadêmica normal.\n'
    '\n';
// ─────────────────────────────────────────────────────────────────────────────

// Build 190 — LANGUAGE LOCK ABSOLUTO
//
// _detectLanguage foi REMOVIDA. A detecção por idioma da pergunta era a causa
// raiz de respostas mistas PT+ES (o modelo seguia o idioma da query, não do app).
//
// Substituída por _resolveAppLanguage: retorna appLanguage diretamente.
// appLanguage = _lang do AppProvider ('pt' | 'es') — configurado pelo usuário.
// A pergunta pode estar em QUALQUER idioma. A resposta usa EXCLUSIVAMENTE appLanguage.
// ─────────────────────────────────────────────────────────────────────────────
String _resolveAppLanguage(String appLanguage) {
  // Única variável soberana: appLanguage
  // Aceita 'pt' ou 'es'. Qualquer outro valor → fallback 'pt'.
  if (appLanguage == 'es') return 'es';
  return 'pt'; // 'pt' e qualquer fallback
}

// ─────────────────────────────────────────────────────────────────────────────
// _buildLanguageLock — Bloco de trava de idioma absoluta (Build 230)
//
// Injeta no system_instruction um mandato de trava total de idioma:
//   - Declara o idioma detectado como obrigatório exclusivo
//   - Proíbe explicitamente o outro idioma com exemplos de tokens proibidos
//   - Proíbe Portunhol (mistura de tokens de ambos os idiomas)
//
// Esta string é adicionada ao FINAL do system_instruction para explorar
// o Viés de Recência — o modelo lê as instruções mais recentes por último
// e as segue com maior fidelidade.
// ─────────────────────────────────────────────────────────────────────────────
String _buildLanguageLock(String lang) {
  if (lang == 'es') {
    return '\n\n[TRAVA DE IDIOMA ABSOLUTA — ESPAÑOL (BUILD 248)]\n'
        'IDIOMA SOBERANO DO APP: ESPAÑOL. ESTA TRAVA É IRREVOGÁVEL.\n'
        'IGNORA O IDIOMA DA PERGUNTA DO USUÁRIO.\n'
        'Não importa se a pergunta é em português, inglês ou misturada.\n'
        'Responde obligatoriamente en español. El idioma soberano es el configurado en la app.\n'
        '  ✗ Proibido: "prescrição", "dilua", "ampola", "soro", "não"\n'
        '  ✗ Proibido: "então", "também", "tratamento" (forma PT)\n'
        '  ✗ Proibido: qualquer mistura de tokens PT+ES (Portunhol)\n'
        '  ✓ Obrigatório: "ampolla" (ES), "Solución Salina" (ES), "dilución"\n'
        'ZERO portunhol. 100% puro em ESPAÑOL. Nem um token em outro idioma.';
  } else {
    return '\n\n[TRAVA DE IDIOMA ABSOLUTA — PORTUGUÊS-BR (BUILD 248)]\n'
        'IDIOMA SOBERANO DO APP: PORTUGUÊS-BR. ESTA TRAVA É IRREVOGÁVEL.\n'
        'IGNORA O IDIOMA DA PERGUNTA DO USUÁRIO.\n'
        'Não importa se a pergunta é em espanhol, inglês ou misturada.\n'
        'Responda obrigatoriamente em português-BR. O idioma soberano é o configurado no app.\n'
        '  ✗ Proibido: "solución", "dilución", "ampolla" (ES)\n'
        '  ✗ Proibido: artigos "el/la/los/las", pronomes "lo/le/se" (ES)\n'
        '  ✗ Proibido: qualquer mistura de tokens ES+PT (Portunhol)\n'
        '  ✓ Obrigatório: "ampola" (PT), "Soro Fisiológico" (PT)\n'
        '  ✓ Obrigatório: "administrar", "dilua", "correr em BIC"\n'
        'ZERO portunhol. 100% puro em PORTUGUÊS-BR. Nem um token em outro idioma.';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ModeAnchorEngine — Injeção de âncora de modo (Build 157)
// ─────────────────────────────────────────────────────────────────────────────
class ModeAnchorEngine {
  ModeAnchorEngine._(); // utilitário estático

  /// Retorna a âncora de modo correspondente ao motor selecionado.
  ///
  /// Build 157.1: NÃO mais concatena com systemPrompt — a âncora é
  /// passada como PART SEPARADO (modeAnchor) para GeminiServiceV2,
  /// onde será a PRIMEIRA parte de system_instruction.parts[] e terá
  /// PRIORIDADE ABSOLUTA sobre o _systemPromptPrefix.
  ///
  /// [longResponse]=false → _modeAnchorPlantao (14-18 linhas conteúdo real, Jefe de Guardia)
  /// [longResponse]=true  → _modeAnchorEstudo  (24-30 linhas, preceptor, Parágrafo 4 condicional)
  static String getModeAnchor({bool longResponse = false}) {
    final anchor = longResponse ? _modeAnchorEstudo : _modeAnchorPlantao;
    debugPrint(
      '[ModeAnchorEngine] Build 229: motor=${longResponse ? "ESTUDO" : "GUARDIA"} '
      'âncora obtida (${anchor.length} chars) — isolada em system_instruction',
    );
    return anchor;
  }

  /// Build 230: Arquitetura Sanduíche com Isolamento Total de Mandato + Language Lock.
  /// - Topo: âncora (contrato de formato + idioma)
  /// - Meio: systemPrompt do AiService (contexto RAG clínico)
  /// - Final: reforço mandatório + mandato de intent + trava de idioma absoluta
  ///
  /// CRÍTICO — Prompt Leak Fix (Build 226→229):
  ///   [intentMandate] é injetado AQUI (em system_instruction), NÃO na
  ///   user message. Isso garante que o mandato nunca apareça em contents[]
  ///   e portanto NUNCA pode ser ecoado pelo modelo na resposta.
  ///
  /// Build 230 — Language Lock:
  ///   [languageLock] é o bloco de trava de idioma PT/ES construído por
  ///   _buildLanguageLock(). Injetado como ÚLTIMA instrução do system_instruction
  ///   para maximizar o Viés de Recência — o modelo o lê por último.
  ///
  /// Modo Estudo: âncora + systemPrompt + language lock.
  static String injectModeAnchor(
    String systemPrompt, {
    bool longResponse = false,
    String intentMandate = '',  // Build 229: mandato de intent isolado no system
    String languageLock  = '',  // Build 230: trava de idioma absoluta PT/ES
  }) {
    final anchor = getModeAnchor(longResponse: longResponse);
    final langSuffix = languageLock.isNotEmpty ? languageLock : '';

    // Modo Estudo: âncora + systemPrompt + language lock final.
    if (longResponse) {
      return '$anchor\n\n$systemPrompt$langSuffix';
    }

    // Modo Plantão: Sanduíche — reforço final explora Viés de Recência.
    // Build 224: cláusula anti-History-Style-Bleeding.
    // Build 229: intentMandate anexado ao final do system_instruction —
    //   garante que o mandato de gotas/ampola/conduta seja lido como
    //   instrução de sistema e NUNCA como turno de conversa do usuário.
    // Build 230: languageLock como ÚLTIMA instrução (Viés de Recência máximo).
    final intentSuffix = intentMandate.isNotEmpty
        ? '\n\n[MANDATO DE INTENT PARA ESTE TURNO]\n$intentMandate'
        : '';

    return '$anchor\n\n'
        '[INÍCIO DO CONTEXTO CLÍNICO DO APLICATIVO]\n'
        '$systemPrompt\n\n'
        '[REFORÇO MANDATÓRIO DE FORMATO DE SAÍDA - LEIA ISTO POR ÚLTIMO]\n'
        'Você está TERMINANTEMENTE PROIBIDO de seguir o estilo de prosa ou tamanho '
        'das respostas dadas nos turnos anteriores deste chat. IGNORE o histórico '
        'visual e responda este turno de forma isolada:\n'
        '- SE A PERGUNTA ATUAL FOR CÁLCULO DE GOTAS: Escreva apenas as duas linhas '
        '(Fórmula e Resultado em negrito usando **).\n'
        '- SE A PERGUNTA ATUAL FOR PREPARO/AMPOLAS: Escreva apenas o tripé rígido '
        '(Volume, Diluição e Infusão) em até 5 linhas.\n'
        '- SE FOR CONDUTA GERAL: Siga o template rígido de 6 emojis.'
        '$intentSuffix'
        '$langSuffix';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AiGatewayService — Shim de compatibilidade reversa (Build 157)
//
// Mantém a interface pública exata do Build 155.2 para zero breaking changes
// em app_provider.dart e qualquer outro arquivo que referencie esta classe.
//
// Internamente, delega TUDO para ModeAnchorEngine + GeminiServiceV2.sendStream().
// Nenhuma chamada de rede para medcasespro.com ou qualquer servidor externo.
// ─────────────────────────────────────────────────────────────────────────────
class AiGatewayService {
  AiGatewayService._(); // classe estática — sem instâncias

  // ── Propriedades de legado ─────────────────────────────────────────────────

  /// Build 157: sempre false — gateway Node.js desativado.
  static bool get forceGateway => false;
  // ignore: avoid_setters_without_getters
  static set forceGateway(bool _) {} // no-op

  /// Build 157: isConfigured é sempre true — sem pré-requisito de servidor.
  /// A chave é validada no momento da chamada via GeminiServiceV2.
  static bool get isConfigured => true;

  /// Build 157: configure() é no-op — URL de gateway não existe mais.
  static void configure({required String baseUrl}) {
    debugPrint(
      '[AiGatewayService] Build 157: configure() ignorado — '
      'gateway desativado. Flutter fala direto com Google.',
    );
  }

  // ── sendStream — Interface principal ──────────────────────────────────────

  /// Envia mensagem ao Gemini com motor selecionado.
  ///
  /// Build 225: PlantaoIntentEngine multidimensional — PROMPT LEAK FIX preservado.
  /// O mandato rico (topic+subtitle+context+complexity+template) vai EXCLUSIVAMENTE
  /// para system_instruction. A user message enviada nos contents[] é SEMPRE a
  /// mensagem limpa original — elimina eco do mandato pelo modelo.
  /// Modo Plantão: grounding=false.
  ///
  /// [userMessage]  — pergunta clínica do usuário
  /// [systemPrompt] — prompt base montado pelo AiService (sem âncora)
  /// [apiKey]       — chave Gemini do app, carregada do Firestore pelo admin.
  ///                   Nunca é inserida manualmente pelo médico — fluxo invisível.
  /// [history]      — histórico de turnos [{role, content}]
  /// [useGrounding] — repassado ao GeminiServiceV2 (Google Search Grounding)
  /// [longResponse]  — false=Motor Plantão / true=Motor Estudos
  /// [appLanguage]   — Build 190: idioma soberano do app ('pt'|'es'). NUNCA detectado da query.
  static Stream<GeminiChunk> sendStream({
    required String userMessage,
    required String systemPrompt,
    required String apiKey,
    List<Map<String, String>> history = const [],
    bool useGrounding = true,
    bool longResponse = false,
    String appLanguage = 'pt', // Build 190: Language Lock Absoluto
  }) {
    // BUILD 278: wraps _sendStreamAsync (async*) para manter a assinatura
    // Stream<GeminiChunk> síncrona exigida pelos callers existentes.
    // O gerador assíncrono permite await (getActiveCache) sem mudar a API.
    return _sendStreamAsync(
      userMessage:  userMessage,
      systemPrompt: systemPrompt,
      apiKey:       apiKey,
      history:      history,
      useGrounding: useGrounding,
      longResponse: longResponse,
      appLanguage:  appLanguage,
    );
  }

  static Stream<GeminiChunk> _sendStreamAsync({
    required String userMessage,
    required String systemPrompt,
    required String apiKey,
    List<Map<String, String>> history = const [],
    bool useGrounding = true,
    bool longResponse = false,
    String appLanguage = 'pt',
  }) async* {
    // Chave vazia: passa o erro para o GeminiServiceV2 que já tem
    // handler robusto — sem mensagem visível ao médico.
    // O app_provider já tentou todas as formas de recuperação automática
    // antes de chegar aqui (Firestore → SharedPrefs → localStorage).
    if (apiKey.isEmpty) {
      debugPrint('[AiGatewayService] chave ausente após tentativas de recuperação → api_key_invalid');
      yield GeminiChunk.error('api_key_invalid');
      return;
    }

    // Build 222: Modo Plantão força useGrounding=false obrigatoriamente.
    final effectiveGrounding = longResponse ? useGrounding : false;

    // Build 190: Language Lock Absoluto — usa appLanguage diretamente.
    // Movido antes do IntentClassifier (Build 224) para resolvedLang estar disponível.
    // A detecção por idioma da pergunta foi removida (causa raiz de PT+ES misturado).
    // appLanguage vem do AppProvider._lang — configurado pelo usuário, imutável por turno.
    final resolvedLang = _resolveAppLanguage(appLanguage);
    final languageLock = _buildLanguageLock(resolvedLang);

    if (kDebugMode) {
      // BUILD 248: [LANG_LOCK] — log soberano único por requisição
      debugPrint('[LANG_LOCK] appLanguage=$resolvedLang inputIgnored=true responseLanguage=$resolvedLang');
      debugPrint('[AI_ROUTER] Build190: appLanguage=$appLanguage → resolvedLang=$resolvedLang (Language Lock Absoluto)');
      debugPrint('[AI_ROUTER] languageLock=${languageLock.length} chars → system_instruction');
    }

    // Build 225: PlantaoIntentEngine — engine multidimensional (tema+contexto+intenção+complexidade).
    //
    // REGRA DE OURO: o mandato vai EXCLUSIVAMENTE para system_instruction.
    // A userMessage enviada nos contents[] é SEMPRE a mensagem limpa do médico.
    // O mandato NUNCA deve conter texto que o modelo possa ecoar na resposta.
    //
    // Substitui PlantaoIntentClassifier.classify() (Build 224) com engine multidimensional.
    // PlantaoIntentClassifier permanece no pipeline como shim de retrocompatibilidade.
    //
    // ORDEM 54 M1: a cláusula de supremacia (AUTORIDADE MÁXIMA / USE EXCLUSIVAMENTE
    // A MATRIZ N) só é injetada no 1º turno (history vazio). Em turnos de follow-up
    // (history.isNotEmpty), substituímos por instrução de liberdade conversacional
    // para que a IA responda de forma direta e pontual sem re-enunciar a Matriz inteira.
    String intentMandate = '';
    final bool isFollowUpTurn = history.isNotEmpty; // ORDEM 54 M1: turno de acompanhamento
    if (!longResponse) {
      // Engine multidimensional: 100% local, zero IA, zero rede, zero latência
      final queryAnalysis = PlantaoIntentEngine.analyze(userMessage);

      if (isFollowUpTurn) {
        // ORDEM 54 M1: turno de follow-up — libera a IA das amarras da Matriz.
        // A IA JÁ conhece o contexto clínico pelo histórico; exigir re-enunciação
        // da Matriz inteira gera resposta engessada e verbosa.
        intentMandate = resolvedLang == 'es'
            ? 'TURNO DE SEGUIMIENTO:\n'
                'El médico está continuando la misma consulta clínica.\n'
                'ESTÁS COMPLETAMENTE LIBERADO de las estructuras fijas de las 22 Matrices de Emojis.\n'
                'Responde la duda puntual del médico de forma directa, breve y precisa.\n'
                'Usa texto clínico limpio, sin 🟥/💊/⛔/📌 salvo que el contexto los exija naturalmente.\n'
                'Prioridad: velocidad, precisión, concisión. Sin repetir diagnóstico anterior.'
            : 'TURNO DE ACOMPANHAMENTO:\n'
                'O médico está continuando a mesma consulta clínica.\n'
                'VOCÊ ESTÁ COMPLETAMENTE LIBERADO das amarras e estruturas fixas das 22 Matrizes de Emojis.\n'
                'Responda a dúvida pontual do médico de forma direta, curta e precisa.\n'
                'Use texto clínico limpo, sem 🟥/💊/⛔/📌 salvo se o contexto exigir naturalmente.\n'
                'Prioridade: velocidade, precisão, concisão. Sem re-enunciar diagnóstico anterior.';

        if (kDebugMode) {
          debugPrint('[AI_ROUTER][O54_M1] follow-up turn → liberty mandate injected '
              'historyLen=${history.length}');
        }
      } else {
        // 1º turno (history vazio) — injeta mandato de matriz com supremacia
        intentMandate = PlantaoIntentEngine.buildIntentMandateV2(queryAnalysis, resolvedLang);

        if (kDebugMode) {
          debugPrint('[AI_ROUTER][Build225] '
              'topic=${queryAnalysis.clinicalTopic} '
              'subtitle="${queryAnalysis.clinicalSubtitle}" '
              'primaryIntent=${queryAnalysis.primaryIntent.name} '
              'secondaryIntent=${queryAnalysis.secondaryIntent?.name ?? "none"} '
              'context=${queryAnalysis.clinicalContext.name} '
              'complexity=${queryAnalysis.complexity.name} '
              'confidence=${queryAnalysis.confidence.toStringAsFixed(2)} '
              '| intentMandate=${intentMandate.length} chars → system_instruction only');
        }
      }
    }

    // Build 190: AiSmartRouter — Pipeline em 5 Camadas.
    // Substitui ModeAnchorEngine.injectModeAnchor() + PromptModules.build().
    // Contrato único selecionado; contexto capado; langLock dupla âncora.
    // intentMandate continua sendo injetado via ModeAnchorEngine para Plantão.

    final isPlantaoMode = !longResponse; // Build 223

    // ── Build 190: SmartRouter — monta prompt final enxuto ──────────────────
    // O SmartRouter: seleciona contrato único, lazy-loading de módulos,
    // cap de contexto (1200 chars), Language Lock dupla âncora, logs AI_ROUTER.
    // ORDEM 52 M1: hasSpecificContext=true quando IntentEngine produziu mandato
    // específico de matriz (intent != geral OU topic != 'CONSULTA CLÍNICA').
    // Sinaliza ao SmartRouter para suprimir _contractPlantao genérico e usar
    // apenas _contractPlantaoRef (regras visuais sem template estrutural).
    final bool hasSpecificMatrizContext = isPlantaoMode &&
        intentMandate.isNotEmpty &&
        !intentMandate.contains('CONSULTA CLÍNICA');

    final routerResult = AiSmartRouter.build(
      userMessage: userMessage,
      systemPrompt: systemPrompt, // contexto RAG bruto do AiService
      isPlantaoMode: isPlantaoMode,
      appLanguage: resolvedLang,  // Build 190: lang soberano do app
      hasSpecificContext: hasSpecificMatrizContext, // ORDEM 52 M1
    );

    // ── intentMandate: injetado no final do prompt do SmartRouter ────────────
    // Build 191: sem tag [MANDATO TURNO] — era a causa raiz do vazamento.
    // Mandato compacto, sem texto verboso que o modelo possa ecoar.
    final String basePrompt = intentMandate.isNotEmpty
        ? '${routerResult.finalPrompt}\n\n$intentMandate'
        : routerResult.finalPrompt;

    // ── ORDEM 49 M1: Injeção JIT da ModeAnchor no topo do systemPrompt ───────
    // CAUSA RAIZ DO FANTASMA DE ESTADO (Build 229→):
    //   Build 221 removeu o modeAnchor como Part 0 separado do system_instruction,
    //   assumindo que AiSmartRouter.build() já o incluía. Porém, o SmartRouter
    //   injeta apenas _contractPlantao/_contractEstudo (texto curto de formato),
    //   enquanto _modeAnchorPlantao/_modeAnchorEstudo (âncoras longas com
    //   SOBERANIA ABSOLUTA e ISOLAMENTO TOTAL) ficaram inertes.
    //
    // CORREÇÃO: reintroduz a âncora de modo como PRIMEIRA instrução do
    //   finalSystemPrompt — antes do SmartRouter — para garantir que o modelo
    //   leia o contrato de modo com Viés de Primazia absoluto em todo primeiro
    //   turno e evite aplicar template do modo anterior ao chat novo.
    //
    // Âncora Estudo: bloco '[MODO ESTUDO]' com ISOLAMENTO TOTAL de emojis
    //   de Plantão (🟥/🔄/⛔) e override de qualquer instrução anterior.
    // Âncora Plantão: bloco '[MODO PLANTÃO]' com REGRA ZERO de abertura.
    // NUNCA concatenado na userMessage — permanece 100% em system_instruction.
    final String modeAnchorJit = ModeAnchorEngine.getModeAnchor(longResponse: longResponse);

    // ── BUILD 278 (1): Trava de Output Compacto ──────────────────────────────
    // RETIFICAÇÃO BUILD 278: aplica-se EXCLUSIVAMENTE ao Motor Estudo.
    // O Modo Plantão já possui volumetria validada e perfeita — NÃO alterar.
    // longResponse==true  → Motor Estudo → injeta trava de 26 linhas × 15 palavras
    // longResponse==false → Motor Plantão → string vazia, zero impacto
    final String outputCompact = longResponse
        ? _buildOutputCompactDirective(resolvedLang)
        : ''; // Plantão: sem alteração nas instruções de output

    final String finalSystemPrompt =
        '$modeAnchorJit\n\n$basePrompt$outputCompact';

    final motor = longResponse ? 'ESTUDO' : 'GUARDIA';
    debugPrint(
      '[AI_ROUTER] Build190: motor=$motor | '
      'lang=$resolvedLang | contract=${routerResult.contractName} | '
      'task=${routerResult.taskLabel} | '
      'anchor=${modeAnchorJit.length}c | '
      'final=${finalSystemPrompt.length} chars | '
      'contextSaved=${routerResult.contextSaved} chars | '
      'modules=${routerResult.modulesLoaded}loaded/${routerResult.modulesSkipped}skipped | '
      'grounding=$effectiveGrounding',
    );

    // ── BUILD 278 (2): Context Caching — resolução assíncrona ───────────────
    // Verifica se há um cache ativo para o systemPrompt atual.
    // O cache reduz o payload de ~6.500 → ~100 tokens por turno,
    // eliminando a causa raiz dos erros 503 por sobrecarga de throughput.
    //
    // RESTRIÇÃO: Context Caching é INCOMPATÍVEL com Google Search Grounding.
    // Se effectiveGrounding=true: não usa cache no payload desta chamada,
    // mas dispara a criação do cache em background para reutilização futura
    // em chamadas sem grounding (Modo Plantão).
    //
    // Build 229 (preservado): Delega para GeminiServiceV2.
    // CRÍTICO: userMessage (limpa, sem mandato) → contents[role='user']
    //          finalSystemPrompt (SmartRouter + intentMandate) → system_instruction
    //          cacheEntry?.name → cachedContent (substitui system_instruction quando ativo)
    String? activeCacheName;

    if (!effectiveGrounding) {
      // Modo Plantão (grounding=false): pode usar cache diretamente.
      // Verifica memória primeiro (síncrono, zero I/O).
      if (GeminiCacheService.hasValidCacheInMemory) {
        final cached = await GeminiCacheService.getActiveCache(
          apiKey:       apiKey,
          systemPrompt: finalSystemPrompt,
        );
        activeCacheName = cached?.name;
      }

      // Se ainda sem cache: cria em background (não bloqueia o stream).
      // A próxima chamada já vai encontrar o cache pronto.
      if (activeCacheName == null) {
        // Dispara criação assíncrona — NÃO usa await (zero latência para o usuário).
        // O cache ficará pronto para a PRÓXIMA mensagem nesta sessão.
        unawaited(
          GeminiCacheService.createOrRefresh(
            apiKey:       apiKey,
            systemPrompt: finalSystemPrompt,
          ).then((entry) {
            if (entry != null) {
              debugPrint('[AI_ROUTER] BUILD278: cache criado em background name=${entry.name} '
                  'expiresAt=${entry.expiresAt.toIso8601String()}');
            }
          }).catchError((Object e) {
            debugPrint('[AI_ROUTER] BUILD278: cache_create_error=$e');
          }),
        );
      }
    } else {
      // Modo Estudo com grounding ativo: não usa cache no payload.
      // Dispara criação de cache para uso futuro em turnos sem grounding.
      // (O cache do prompt base pode ser reutilizado no Modo Plantão.)
      unawaited(
        GeminiCacheService.createOrRefresh(
          apiKey:       apiKey,
          systemPrompt: finalSystemPrompt,
        ).catchError((Object _) => null as GeminiCacheEntry?),
      );
    }

    if (kDebugMode) {
      debugPrint('[AI_ROUTER] BUILD278: '
          'cacheActive=${activeCacheName != null} '
          'cacheName=${activeCacheName ?? "none"} '
          'grounding=$effectiveGrounding '
          'outputCompact=${outputCompact.length}c');
    }

    yield* GeminiServiceV2.sendStream(
      apiKey:          apiKey,
      userMessage:     userMessage,        // mensagem LIMPA — mandato está no system
      systemPrompt:    finalSystemPrompt,  // SmartRouter: enxuto, contrato único, lang lock
      history:         history,
      useGrounding:    effectiveGrounding, // Build 222: false fixo no Modo Plantão
      isPlantaoMode:   isPlantaoMode,      // Build 223: remove bullets/## do prefixo
      cachedContentName: activeCacheName, // BUILD 278: ID do cache (null = sem cache)
    );
  }

  // ── classifyContext — delega para GeminiServiceV2 ─────────────────────────

  /// Classificação de contexto via Gemini síncrono.
  /// Build 156: requer [apiKey] — parâmetro adicionado.
  /// Para compatibilidade reversa sem apiKey, retorna 'MÉDICO' (conservador).
  static Future<String> classifyContext(
    String prompt, {
    int maxTokens = 20,
    String apiKey = '',
  }) async {
    if (apiKey.isEmpty) return 'MÉDICO';
    // Reutiliza o endpoint síncrono interno do GeminiServiceV2
    // chamando sendStream com prompt de classificação e lendo o primeiro chunk
    try {
      final chunks = <String>[];
      await GeminiServiceV2.sendStream(
        apiKey: apiKey,
        userMessage: prompt,
        systemPrompt: 'Responda APENAS com uma palavra: MÉDICO ou NOVO.',
        history: const [],
        useGrounding: false,
      ).forEach((chunk) {
        if (chunk.text.isNotEmpty) chunks.add(chunk.text);
      });
      final result = chunks.join().trim().toUpperCase();
      return result.contains('NOV') ? 'NOVO' : 'MÉDICO';
    } catch (_) {
      return 'MÉDICO';
    }
  }

  // ── checkHealth ────────────────────────────────────────────────────────────

  /// Build 156: health = true se apiKey não está vazia.
  /// Passa a chave opcionalmente para validação real.
  static Future<bool> checkHealth({String apiKey = ''}) async {
    return apiKey.isNotEmpty;
  }
}
