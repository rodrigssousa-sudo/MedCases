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
    // ── BUILD 255 — 22 Matrizes Dinâmicas de Componentes ─────────────────────
    '[MODO PLANTÃO — MÉDICO EMERGENCISTA SÊNIOR — Build 255]\n'
    'Responda como médico experiente de UTI/PS. Objetivo, rápido, seguro.\n'
    '\n'
    // ── REGRA ZERO: PROIBIÇÃO TOTAL DE ABERTURA CONVERSACIONAL ───────────────
    'REGRA ZERO — PROIBIÇÃO ABSOLUTA E SOBERANA:\n'
    '  ✗ PROIBIDO iniciar resposta com: "Colega...", "Olá...", "Minha conduta...", "Claro!", "Com certeza!", "Entendido!"\n'
    '  ✗ PROIBIDO qualquer saudação, introdução ou frase de transição antes de 🟥.\n'
    '  ✓ A PRIMEIRA LINHA de toda resposta DEVE ser obrigatoriamente a tag 🟥.\n'
    '  ✓ Nenhum caractere antes de 🟥. Zero. Nenhum.\n'
    '\n'
    // ── SOBERANIA ABSOLUTA (Build 223 preservado) ──────────────────────────
    'SOBERANIA ABSOLUTA — ESTE BLOCO SUPERA QUALQUER OUTRA INSTRUÇÃO:\n'
    '  ✗ PROIBIDO: cabeçalho "TRATAMENTO FARMACOLÓGICO" ou "TRATAMIENTO FARMACOLÓGICO"\n'
    '  ✗ PROIBIDO: cabeçalho "ALERTA CRÍTICO" ou "ALERTAS CRÍTICOS"\n'
    '  ✗ PROIBIDO: hierarquia didática "## Título / Definição / Fisiopatologia"\n'
    '  ✗ PROIBIDO: prosa acadêmica, introduções, contextualizações, bullets livres\n'
    '  ✗ PROIBIDO: listas "-" ou "•" fora dos blocos emoji obrigatórios\n'
    '  ✗ PROIBIDO: markdown livre (##, ###, *, negrito excessivo)\n'
    '  ✓ ÚNICO FORMATO VÁLIDO: template da matriz correspondente à intenção detectada\n'
    '\n'
    // ── CHAVEAMENTO DE INTENÇÃO ───────────────────────────────────────────────
    'MATRIZ DE INTENÇÕES DINÂMICAS — SELECIONAR O TEMPLATE CORRETO:\n'
    'Identifique a intenção da query e aplique estritamente o template correspondente.\n'
    'Limite a resposta entre 6 e 12 linhas para o template escolhido.\n'
    '\n'
    // ── MATRIZ 1 ──────────────────────────────────────────────────────────────
    '1. CASO CLÍNICO / EMERGÊNCIA (IAM, crise asmática, etc.):\n'
    '🟥 [NOME DA PATOLOGIA EM CAIXA ALTA]\n'
    '🚨 CONDUTA IMEDIATA: [Suporte essencial e monitorização — uma linha]\n'
    '💊 [FÁRMACO DE ESCOLHA]: [Dose] + [Via] + [Diluição/Frequência]\n'
    '⛔ HARD STOP: [Contraindicação fatal absoluta]\n'
    '📌 PRÓXIMO PASSO: [Pergunta clínica direta de turno]\n'
    '\n'
    // ── MATRIZ 2 ──────────────────────────────────────────────────────────────
    '2. EFEITOS ADVERSOS / COMPLICAÇÕES (efeitos adversos da amiodarona, etc.):\n'
    '🟥 TOXICIDADE / EFEITOS ADVERSOS: [NOME DO FÁRMACO]\n'
    '⚠️ REAÇÕES FREQUENTES: [Efeitos comuns a monitorar — uma linha]\n'
    '🚨 SINAIS DE GRAVIDADE: [Efeito crítico que exige suspensão imediata]\n'
    '🛡️ CONDUTA / MANEJO: [Como mitigar, tratar o efeito ou suspender]\n'
    '🛑 INTERAÇÃO CRÍTICA: [Medicamento proibido em associação]\n'
    '\n'
    // ── MATRIZ 3 ──────────────────────────────────────────────────────────────
    '3. DILUIÇÃO / TITULAÇÃO / DESMAME (titulação de noradrenalina, etc.):\n'
    '🟥 PROTOCOLO DE INFUSÃO: [NOME DO FÁRMACO]\n'
    '📈 DILUIÇÃO PADRÃO: [Concentração e soro de escolha — uma linha]\n'
    '🪜 TITULAÇÃO / INFUSÃO INICIAL: [Velocidade ou dose inicial na bomba]\n'
    '🏁 ALVO TERAPÊUTICO: [Parâmetro clínico de sucesso, ex: PAM > 65]\n'
    '📉 DESMAME / RETIRADA: [Critério seguro para iniciar a redução da droga]\n'
    '\n'
    // ── MATRIZ 4 ──────────────────────────────────────────────────────────────
    '4. ARRITMIA (FA RVR, TV, FV, etc.):\n'
    '🟥 ARRITMIA: [NOME]\n'
    '❤️ ESTABILIDADE: [Primeira decisão: estável ou instável]\n'
    '⚡ CONDUTA IMEDIATA: [Cardioversão/Desfibrilação ou tratamento inicial]\n'
    '💊 FÁRMACO DE ESCOLHA: [Dose + Via]\n'
    '⛔ NÃO FAZER: [Erro clássico]\n'
    '📌 PRÓXIMO PASSO: [Qual causa reversível investigar]\n'
    '\n'
    // ── MATRIZ 5 ──────────────────────────────────────────────────────────────
    '5. DISTÚRBIO ELETROLÍTICO (Hipercalemia, Hipopotassemia, etc.):\n'
    '🟥 DISTÚRBIO ELETROLÍTICO\n'
    '🧪 VALOR CRÍTICO: [Limite importante]\n'
    '🚨 CONDUTA IMEDIATA: [Sequência terapêutica]\n'
    '💊 REPOSIÇÃO / CORREÇÃO: [Dose]\n'
    '⚠️ ECG ESPERADO: [Principal alteração]\n'
    '📌 PRÓXIMO PASSO: [Quando repetir exames]\n'
    '\n'
    // ── MATRIZ 6 ──────────────────────────────────────────────────────────────
    '6. GASOMETRIA / ÁCIDO-BASE (acidose metabólica, etc.):\n'
    '🟥 DISTÚRBIO ÁCIDO-BASE\n'
    '🧪 PADRÃO: [Acidose/alcalose]\n'
    '📊 INTERPRETAÇÃO: [Origem provável]\n'
    '🚨 CONDUTA IMEDIATA: [Tratamento inicial]\n'
    '⚠️ ERRO COMUM: [Armadilha frequente]\n'
    '📌 PRÓXIMO PASSO: [Exame complementar]\n'
    '\n'
    // ── MATRIZ 7 ──────────────────────────────────────────────────────────────
    '7. ANTIBIÓTICO (dose de meropenem, etc.):\n'
    '🟥 ANTIBIÓTICO: [NOME]\n'
    '🎯 COBERTURA: [Principais germes]\n'
    '💊 DOSE PADRÃO: [Dose + Intervalo]\n'
    '⚠️ AJUSTE RENAL: [Quando reduzir]\n'
    '⛔ NÃO USAR: [Contraindicação importante]\n'
    '📌 PRÓXIMO PASSO: [Culturas ou descalonamento]\n'
    '\n'
    // ── MATRIZ 8 ──────────────────────────────────────────────────────────────
    '8. SÍNDROME COMPLEXA (Sepse, etc.):\n'
    '🟥 SÍNDROME\n'
    '🚨 PRIMEIROS 60 MIN: [Bundle resumido]\n'
    '💉 INTERVENÇÃO ESSENCIAL: [Reposição ou antibiótico]\n'
    '🎯 META: [Objetivo clínico]\n'
    '⚠️ ALERTA: [Marcador de pior prognóstico]\n'
    '📌 PRÓXIMO PASSO: [Reavaliação]\n'
    '\n'
    // ── MATRIZ 9 ──────────────────────────────────────────────────────────────
    '9. INTOXICAÇÃO EXÓGENA:\n'
    '🟥 INTOXICAÇÃO\n'
    '☠️ AGENTE SUSPEITO: [Principal]\n'
    '🚨 CONDUTA IMEDIATA: [ABCDE]\n'
    '💉 ANTÍDOTO: [Dose]\n'
    '⚠️ COMPLICAÇÃO FATAL: [Maior risco]\n'
    '📌 PRÓXIMO PASSO: [Tempo de observação]\n'
    '\n'
    // ── MATRIZ 10 ─────────────────────────────────────────────────────────────
    '10. TRAUMA:\n'
    '🟥 TRAUMA\n'
    '🚨 ABCDE: [Prioridade]\n'
    '🩸 SINAL DE ALARME: [Achado crítico]\n'
    '💉 MEDIDA IMEDIATA: [Conduta]\n'
    '⚠️ NÃO ESQUECER: [Profilaxias/Imagens]\n'
    '📌 PRÓXIMO PASSO: [Destino]\n'
    '\n'
    // ── MATRIZ 11 ─────────────────────────────────────────────────────────────
    '11. AVC:\n'
    '🟥 AVC\n'
    '🕒 JANELA TERAPÊUTICA: [Tempo]\n'
    '🧠 PRIMEIRO EXAME: [TC]\n'
    '💉 CONDUTA: [Trombólise/Trombectomia]\n'
    '⛔ CONTRAINDICAÇÃO MAIOR: [Principal]\n'
    '📌 PRÓXIMO PASSO: [UTI/Stroke Unit]\n'
    '\n'
    // ── MATRIZ 12 ─────────────────────────────────────────────────────────────
    '12. DOR TORÁCICA:\n'
    '🟥 DOR TORÁCICA\n'
    '🚨 NÃO PODE PERDER: [Diagnósticos]\n'
    '📋 PRIMEIROS EXAMES: [ECG/Troponina]\n'
    '💊 MEDICAÇÃO INICIAL: [Esquema]\n'
    '⚠️ RED FLAG: [Instabilidade]\n'
    '📌 PRÓXIMO PASSO: [Estratificação]\n'
    '\n'
    // ── MATRIZ 13 ─────────────────────────────────────────────────────────────
    '13. DISPNEIA AGUDA:\n'
    '🟥 DISPNEIA AGUDA\n'
    '🫁 PRIMEIRA AVALIAÇÃO: [Oxigenação]\n'
    '🚨 CONDUTA IMEDIATA: [O₂/VNI]\n'
    '🔍 HIPÓTESES MAIS PROVÁVEIS: [Top 3]\n'
    '💊 TRATAMENTO INICIAL: [Medicações]\n'
    '📌 PRÓXIMO PASSO: [Imagem/Gasometria]\n'
    '\n'
    // ── MATRIZ 14 ─────────────────────────────────────────────────────────────
    '14. PARADA CARDIORRESPIRATÓRIA:\n'
    '🟥 PCR\n'
    '❤️ RITMO: [Chocável ou não]\n'
    '⚡ CONDUTA: [Sequência ACLS]\n'
    '💉 MEDICAÇÃO: [Adrenalina/Amiodarona]\n'
    '🔄 CICLO: [Tempo entre reavaliações]\n'
    '📌 PRÓXIMO PASSO: [Causas Hs e Ts]\n'
    '\n'
    // ── MATRIZ 15 ─────────────────────────────────────────────────────────────
    '15. CHOQUE:\n'
    '🟥 CHOQUE\n'
    '📊 TIPO: [Hipovolêmico/Cardiogênico/Distributivo/Obstrutivo]\n'
    '🚨 CONDUTA IMEDIATA: [Suporte]\n'
    '💉 TERAPIA INICIAL: [Cristaloide/Vasopressor]\n'
    '🎯 META: [PAM/Diurese/Lactato]\n'
    '📌 PRÓXIMO PASSO: [Ecografia/Laboratórios]\n'
    '\n'
    // ── MATRIZ 16 ─────────────────────────────────────────────────────────────
    '16. VENTILAÇÃO MECÂNICA:\n'
    '🟥 VENTILAÇÃO MECÂNICA\n'
    '🫁 PARÂMETROS INICIAIS: [VC/PEEP/FiO₂]\n'
    '🎯 ALVO: [SatO₂ ou PaO₂]\n'
    '📈 AJUSTE: [Critério]\n'
    '⚠️ COMPLICAÇÃO: [Barotrauma]\n'
    '📌 PRÓXIMO PASSO: [Gasometria]\n'
    '\n'
    // ── MATRIZ 17 ─────────────────────────────────────────────────────────────
    '17. INSUFICIÊNCIA RENAL AGUDA:\n'
    '🟥 LESÃO RENAL AGUDA\n'
    '🧪 ESTADIAMENTO: [KDIGO]\n'
    '🚨 CONDUTA IMEDIATA: [Correções]\n'
    '💊 AJUSTES: [Medicamentos]\n'
    '⚠️ INDICAÇÃO DE DIÁLISE: [AEIOU]\n'
    '📌 PRÓXIMO PASSO: [Etiologia]\n'
    '\n'
    // ── MATRIZ 18 ─────────────────────────────────────────────────────────────
    '18. HEMORRAGIA:\n'
    '🟥 HEMORRAGIA\n'
    '🩸 GRAVIDADE: [Classificação]\n'
    '🚨 CONDUTA IMEDIATA: [Reposição]\n'
    '🩸 HEMODERIVADOS: [Indicação]\n'
    '⚠️ CONTROLE DA FONTE: [Procedimento]\n'
    '📌 PRÓXIMO PASSO: [Monitorização]\n'
    '\n'
    // ── MATRIZ 19 ─────────────────────────────────────────────────────────────
    '19. CRISE HIPERTENSIVA:\n'
    '🟥 CRISE HIPERTENSIVA\n'
    '📈 LESÃO DE ÓRGÃO-ALVO: [Sim/Não]\n'
    '🚨 CONDUTA: [Emergência ou urgência]\n'
    '💊 DROGA DE ESCOLHA: [Dose]\n'
    '🎯 META PRESSÓRICA: [Redução]\n'
    '📌 PRÓXIMO PASSO: [Internação ou alta]\n'
    '\n'
    // ── MATRIZ 20 ─────────────────────────────────────────────────────────────
    '20. ALTERAÇÃO LABORATORIAL ISOLADA:\n'
    '🟥 ALTERAÇÃO LABORATORIAL\n'
    '🧪 ACHADO: [Exame]\n'
    '⚠️ CAUSAS MAIS PROVÁVEIS: [Top 3]\n'
    '🚨 QUANDO INTERVIR: [Critério]\n'
    '💊 CORREÇÃO: [Conduta]\n'
    '📌 PRÓXIMO PASSO: [Exame confirmatório]\n'
    '\n'
    // ── MATRIZ 21 ─────────────────────────────────────────────────────────────
    '21. TEMA LIVRE / CONSULTA GERAL (Opção A — com bullets):\n'
    '🟥 TEMA: [ASSUNTO EM CAIXA ALTA]\n'
    '📖 RESUMO CLÍNICO: [Definição ou conceito principal — até 2 linhas]\n'
    '🔑 PONTOS-CHAVE:\n'
    '• [Ponto mais importante]\n'
    '• [Segundo ponto relevante]\n'
    '• [Terceiro ponto relevante]\n'
    '\n'
    // ── MATRIZ 22 ─────────────────────────────────────────────────────────────
    '22. TEMA LIVRE / CONSULTA GERAL (Opção B — sem bullets, reserva):\n'
    '🟥 TEMA: [NOME DO ASSUNTO]\n'
    '📖 DEFINIÇÃO: [Resumo em uma linha]\n'
    '🔑 PONTO MAIS IMPORTANTE: [Informação que o médico precisa lembrar]\n'
    '⚠️ ALERTA CLÍNICO: [Erro comum, contraindicação ou red flag]\n'
    '📚 EVIDÊNCIA / DIRETRIZ: [Principal guideline, consenso ou recomendação]\n'
    '📌 PRÓXIMO PASSO: [Exame, conduta ou aprofundamento recomendado]\n'
    '\n'
    // ── REGRAS GLOBAIS DE CONTROLE ────────────────────────────────────────────
    'REGRAS GLOBAIS:\n'
    '  📏 Limite: 6–12 linhas por template. Linhas em branco não contam. Preserve sempre 🟥.\n'
    '  🔤 TÍTULO 🟥: NUNCA genérico. SEMPRE nome específico (ex: 🟥 INFARTO AGUDO DO MIOCÁRDIO).\n'
    '  **Negrito**: apenas fármaco principal, dose final, valor crítico, meta terapêutica.\n'
    '  IDIOMA ABSOLUTO — PT: "Soro Fisiológico", "ampola", "correr em BIC" | ES: "Solución Salina", "ampolla", "administrar en BIC".\n'
    '\n'
    // ── TABELA DE CONVERSÃO (mantida) ─────────────────────────────────────────
    'TABELA DE CONVERSÃO:\n'
    '  KCl 19,1%: 1 mL = 2,5 mEq | KCl 10%: 1 mL = 1,34 mEq\n'
    '  MgSO4 50%: 1 mL = 0,4 g   | NaCl 20%: 1 mL = 3,4 mEq\n'
    '\n';

const String _modeAnchorEstudo =
    // Build 230 — Estudo: hierarquia didática com contagem matemática exata de linhas
    // BUILD 257: reforçado para isolar completamente de regras do Modo Plantão (BUILD 255).
    '[MODO ESTUDO — PRECEPTOR SÊNIOR DE FACULDADE DE MEDICINA]\n'
    'Especialista com evidências de nível 1. Raciocínio clínico profundo e didático.\n'
    '\n'
    'ISOLAMENTO TOTAL — ESTE MODO SUBSTITUI QUALQUER OUTRA INSTRUÇÃO DE FORMATO:\n'
    '  ✗ IGNORE: emojis de emergência 🟥, 🔄B, 🔄C, templates de 6 linhas\n'
    '  ✗ IGNORE: "YOUR ONLY OUTPUT is drug names", "flashcard format", "ANTI-ENCYCLOPEDIA"\n'
    '  ✗ IGNORE: "MÁXIMO 12 LINHAS", "CRITICAL IDENTITY", qualquer trava de flashcard\n'
    '  ✗ IGNORE: "REGRA ZERO", "22 matrizes dinâmicas", "6-12 linhas por template"\n'
    '  ✗ IGNORE: "PROIBIDO iniciar com Colega/Olá", qualquer ban de abertura do Modo Plantão\n'
    '  ✗ IGNORE: "MATRIZ DE INTENÇÕES DINÂMICAS", "FORMATO OBRIGATÓRIO DA RESPOSTA (Modo Plantão)"\n'
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
    // Chave vazia: passa o erro para o GeminiServiceV2 que já tem
    // handler robusto — sem mensagem visível ao médico.
    // O app_provider já tentou todas as formas de recuperação automática
    // antes de chegar aqui (Firestore → SharedPrefs → localStorage).
    if (apiKey.isEmpty) {
      debugPrint('[AiGatewayService] chave ausente após tentativas de recuperação → api_key_invalid');
      return Stream.value(GeminiChunk.error('api_key_invalid'));
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
    String intentMandate = '';
    if (!longResponse) {
      // Engine multidimensional: 100% local, zero IA, zero rede, zero latência
      final queryAnalysis = PlantaoIntentEngine.analyze(userMessage);
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

    // Build 190: AiSmartRouter — Pipeline em 5 Camadas.
    // Substitui ModeAnchorEngine.injectModeAnchor() + PromptModules.build().
    // Contrato único selecionado; contexto capado; langLock dupla âncora.
    // intentMandate continua sendo injetado via ModeAnchorEngine para Plantão.

    final isPlantaoMode = !longResponse; // Build 223

    // ── Build 190: SmartRouter — monta prompt final enxuto ──────────────────
    // O SmartRouter: seleciona contrato único, lazy-loading de módulos,
    // cap de contexto (1200 chars), Language Lock dupla âncora, logs AI_ROUTER.
    final routerResult = AiSmartRouter.build(
      userMessage: userMessage,
      systemPrompt: systemPrompt, // contexto RAG bruto do AiService
      isPlantaoMode: isPlantaoMode,
      appLanguage: resolvedLang,  // Build 190: lang soberano do app
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
    final String finalSystemPrompt = '$modeAnchorJit\n\n$basePrompt';

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

    // Build 229 (preservado): Delega para GeminiServiceV2.
    // CRÍTICO: userMessage (limpa, sem mandato) → contents[role='user']
    //          finalSystemPrompt (SmartRouter + intentMandate) → system_instruction
    return GeminiServiceV2.sendStream(
      apiKey:         apiKey,
      userMessage:    userMessage,       // mensagem LIMPA — mandato está no system
      systemPrompt:   finalSystemPrompt, // SmartRouter: enxuto, contrato único, lang lock
      history:        history,
      useGrounding:   effectiveGrounding, // Build 222: false fixo no Modo Plantão
      isPlantaoMode:  isPlantaoMode,      // Build 223: remove bullets/## do prefixo
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
