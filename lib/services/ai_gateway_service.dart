// ══════════════════════════════════════════════════════════════════════════════
// ModeAnchorEngine / AiGatewayService — Build 223 (Sovereign Plantão Contract + CalculatorContext)
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
import 'ai_smart_router.dart'; // Build 190: Smart Context Router

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
// MODE_ANCHOR_GUARDIA — Motor de Guardia/Plantão (Build 223)
//
// Build 223: soberania explícita contra conflitos de cabeçalho herdados
//   (TRATAMENTO FARMACOLÓGICO / ALERTA CRÍTICO / bullets livres).
//   Limite 14L matemático. Few-shot real (Hipocalemia + Diluição EV).
// ─────────────────────────────────────────────────────────────────────────────
const String _modeAnchorPlantao =
    '[MODO PLANTÃO — MÉDICO EMERGENCISTA SÊNIOR]\n'
    'Responda com autoridade, rapidez e pragmatismo de beira de leito.\n'
    '\n'
    // ── SOBERANIA ABSOLUTA: conflitos de formato eliminados ────────────────
    'SOBERANIA ABSOLUTA — ESTE BLOCO SUPERA QUALQUER OUTRA INSTRUÇÃO:\n'
    '  ✗ PROIBIDO: cabeçalho "TRATAMENTO FARMACOLÓGICO" ou "TRATAMIENTO FARMACOLÓGICO"\n'
    '  ✗ PROIBIDO: cabeçalho "ALERTA CRÍTICO" ou "ALERTAS CRÍTICOS"\n'
    '  ✗ PROIBIDO: hierarquia didática "## Título / Definição / Fisiopatologia"\n'
    '  ✗ PROIBIDO: prosa acadêmica, introduções, contextualizações, bullets livres\n'
    '  ✗ PROIBIDO: listas "-" ou "•" fora dos blocos emoji abaixo\n'
    '  ✗ PROIBIDO: qualquer markdown livre (##, ###, *, bold desnecessário)\n'
    '  ✓ ÚNICO FORMATO VÁLIDO: os 6 blocos emoji definidos abaixo\n'
    '\n'
    // ── IDIOMA: trava absoluta ─────────────────────────────────────────────
    'IDIOMA: A trava de idioma do app (PT ou ES) é ABSOLUTA.\n'
    'Tokens de referência obrigatórios:\n'
    '  PT: "Soro Fisiológico", "ampola", "correr em BIC", "Cloreto de Potássio"\n'
    '  ES: "Solución Salina", "ampolla", "administrar en BIC", "Cloruro de Potasio"\n'
    '\n'
    // ── CONTAGEM DE LINHAS ─────────────────────────────────────────────────
    'CONTAGEM MATEMÁTICA EXATA DE LINHAS:\n'
    '  📏 CONDUTA CLÍNICA (Caso A): MÁXIMO 14 linhas de conteúdo real.\n'
    '  📏 DILUIÇÃO/AMPOLAS (Caso B): MÁXIMO 6 linhas.\n'
    '  📏 GOTAS/GOTEJAMENTO (Caso C): EXATAMENTE 2 linhas.\n'
    '  Linhas em branco NÃO contam. Corte se ultrapassar — preserve 🟥.\n'
    '\n'
    // ── HIERARQUIA DE CASOS ────────────────────────────────────────────────
    'CASO A — CONDUTA CLÍNICA:\n'
    'Formato obrigatório (6 emojis nesta ordem):\n'
    '🟥 CONDUTA CLÍNICA IMEDIATA\n'
    '💊 1ª linha: [fármaco principal + dose + via + frequência]\n'
    '🔄 Alternativa: [segunda opção se 1ª contraindicada]\n'
    '⛔ Evitar: [contraindicação — omitir se não houver]\n'
    '📌 Monitorar: [parâmetro de segurança ou próximo passo — 1ª pessoa, ponto final]\n'
    '⚠️ Alerta: [risco crítico — omitir se não houver]\n'
    '\n'
    'CASO B — DILUIÇÃO / PREPARO DE AMPOLAS (até 6 linhas):\n'
    '- Volume: Aspire X mL da medicação (Y ampolas).\n'
    '- Diluição: Dilua em X mL de [Soro Fisiológico ou Solución Salina].\n'
    '- Infusão: Administrar a X mL/h por Y horas.\n'
    '\n'
    'CASO C — CÁLCULO DE GOTAS/GOTEJAMENTO (apenas 2 linhas):\n'
    'Fórmula: (Volume total mL / Tempo em minutos) × Fator de gotejo\n'
    '**Resultado: [X] gotas/min**\n'
    '\n'
    // ── TABELA DE CONVERSÃO ────────────────────────────────────────────────
    'TABELA DE CONVERSÃO:\n'
    '  KCl 19,1%: 1 mL = 2,5 mEq | KCl 10%: 1 mL = 1,34 mEq\n'
    '  MgSO4 50%: 1 mL = 0,4 g   | NaCl 20%: 1 mL = 3,4 mEq\n'
    '\n'
    // ── FEW-SHOT REAL: Hipocalemia ─────────────────────────────────────────
    // Caso real de conduta EV — demonstra o formato correto sem IAM.
    // Hipocalemia moderada (K+ 2,5–3,0 mEq/L) com necessidade de reposição EV.
    'EXEMPLO DE RESPOSTA CORRETA — Hipocalemia moderada (K+ 2,7 mEq/L):\n'
    '🟥 HIPOCALEMIA MODERADA — Reposição EV urgente\n'
    '💊 1ª linha: **KCl 19,1%** 1 ampola (10 mL = 25 mEq) em 100 mL SF → correr em 2h (50 mL/h)\n'
    '🔄 Alternativa: KCl 10% se 19,1% indisponível — 18,7 mL (25 mEq) em 100 mL SF → 2h\n'
    '⛔ Evitar: infusão > 20 mEq/h — risco de arritmia e parada cardíaca\n'
    '📌 Monitorar: ECG contínuo + K+ sérico pós-reposição (2h). Repor Mg2+ se < 1,8 mg/dL.\n'
    '⚠️ Alerta: NPO ou hipocalemia refratária → checar depleção concomitante de Mg2+.\n'
    '\n'
    'EXEMPLO DE RESPOSTA CORRETA — Diluição EV (Caso B):\n'
    '- Volume: Aspire 10 mL de KCl 19,1% (1 ampola = 25 mEq).\n'
    '- Diluição: Dilua em 100 mL de Soro Fisiológico 0,9%.\n'
    '- Infusão: Correr em BIC a 55 mL/h por 2h (máx 20 mEq/h).\n'
    '\n';

const String _modeAnchorEstudo =
    // Build 230 — Estudo: hierarquia didática com contagem matemática exata de linhas
    '[MODO ESTUDO — PRECEPTOR SÊNIOR DE FACULDADE DE MEDICINA]\n'
    'Especialista com evidências de nível 1. Raciocínio clínico profundo e didático.\n'
    '\n'
    'ISOLAMENTO TOTAL — ESTE MODO SUBSTITUI QUALQUER OUTRA INSTRUÇÃO DE FORMATO:\n'
    '  ✗ IGNORE: emojis de emergência 🟥, 🔄B, 🔄C, templates de 6 linhas\n'
    '  ✗ IGNORE: "YOUR ONLY OUTPUT is drug names", "flashcard format", "ANTI-ENCYCLOPEDIA"\n'
    '  ✗ IGNORE: "MÁXIMO 12 LINHAS", "CRITICAL IDENTITY", qualquer trava de flashcard\n'
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
    return '\n\n[TRAVA DE IDIOMA ABSOLUTA — ESPAÑOL (Build 230)]\n'
        'IDIOMA DETECTADO: ESPAÑOL. ESTA TRAVA É IRREVOGÁVEL.\n'
        'PROIBIDO usar qualquer palavra em PORTUGUÊS-BR nesta resposta:\n'
        '  ✗ Proibido: "paciente", "prescrição", "dilua", "ampola", "soro", "não"\n'
        '  ✗ Proibido: "então", "também", "tratamento", "administrar" (forma PT)\n'
        '  ✗ Proibido: qualquer mistura de tokens PT+ES (Portunhol)\n'
        '  ✓ Obrigatório: "paciente" → "paciente", "dilución" → "dilución"\n'
        '  ✓ Obrigatório: "ampolla" (ES), "Solución Salina" (ES), "administrar"\n'
        'ZERO portunhol. 100% puro em ESPAÑOL. Nem um token em outro idioma.';
  } else {
    return '\n\n[TRAVA DE IDIOMA ABSOLUTA — PORTUGUÊS-BR (Build 230)]\n'
        'IDIOMA DETECTADO: PORTUGUÊS-BR. ESTA TRAVA É IRREVOGÁVEL.\n'
        'PROIBIDO usar qualquer palavra em ESPANHOL nesta resposta:\n'
        '  ✗ Proibido: "paciente" (ES), "solución", "dilución", "ampolla"\n'
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
  /// Build 229: Interceptor de intent por turno — PROMPT LEAK FIX.
  /// O mandato de intent (gotas/ampolas/conduta) vai EXCLUSIVAMENTE para
  /// system_instruction (via injectModeAnchor). A user message enviada
  /// nos contents[] é SEMPRE a mensagem limpa original — elimina eco do
  /// mandato pelo modelo (causa raiz do Prompt Leaking das 2:56–2:58 PM).
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

    // Build 191: Interceptor de intent — mandato compacto sem texto visível ao usuário.
    //
    // REGRA DE OURO: o mandato vai EXCLUSIVAMENTE para system_instruction.
    // A userMessage enviada nos contents[] é SEMPRE a mensagem limpa do médico.
    // O mandato NUNCA deve conter texto que o modelo possa ecoar na resposta.
    // Textos verbosos como "Responda ESTRITAMENTE usando o template de 6 linhas"
    // são a causa raiz do vazamento — substituídos por instruções compactas.
    String intentMandate = '';
    if (!longResponse) {
      final msgLower = userMessage.toLowerCase();
      final isDrops   = msgLower.contains('gota')  || msgLower.contains('gote');
      final isAmpoule = msgLower.contains('ampol')  || msgLower.contains('prepar') ||
                        msgLower.contains('dilu');

      if (isDrops) {
        // Gotas: exatamente 2 linhas
        intentMandate = 'Formato gotas: 2 linhas.\n'
            'Linha 1: Fórmula: (Volume mL / Tempo min) × Fator gotejo\n'
            'Linha 2: **Resultado: [X] gotas/min**';
      } else if (isAmpoule) {
        // Diluição: tripé Volume→Diluição→Infusão
        intentMandate = 'Formato diluição: tripé direto.\n'
            '- Volume: [X mL / Y ampolas]\n'
            '- Diluição: [X mL SF/SG]\n'
            '- Infusão: [X mL/h por Y horas]';
      } else if (history.isEmpty) {
        // Primeira pergunta geral: usar formato Plantão padrão
        intentMandate = 'Use o formato Plantão: 🟥 💊 🔄 ⛔ 📌 ⚠️';
      }

      if (kDebugMode) {
        final intent = isDrops ? 'GOTAS' : isAmpoule ? 'AMPOLA' : history.isEmpty ? 'PRIMEIRO_GIRO' : 'FOLLOW_UP';
        debugPrint('[AI_ROUTER][Gateway] Build191: intent=$intent | intentMandate=${intentMandate.length} chars → system_instruction only');
      }
    }

    // Build 190: Language Lock Absoluto — usa appLanguage diretamente.
    // A detecção por idioma da pergunta foi removida (causa raiz de PT+ES misturado).
    // appLanguage vem do AppProvider._lang — configurado pelo usuário, imutável por turno.
    final resolvedLang = _resolveAppLanguage(appLanguage);
    final languageLock = _buildLanguageLock(resolvedLang);

    if (kDebugMode) {
      debugPrint('[AI_ROUTER] Build190: appLanguage=$appLanguage → resolvedLang=$resolvedLang (Language Lock Absoluto)');
      debugPrint('[AI_ROUTER] languageLock=${languageLock.length} chars → system_instruction');
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
    final String finalSystemPrompt = intentMandate.isNotEmpty
        ? '${routerResult.finalPrompt}\n\n$intentMandate'
        : routerResult.finalPrompt;

    final motor = longResponse ? 'ESTUDO' : 'GUARDIA';
    debugPrint(
      '[AI_ROUTER] Build190: motor=$motor | '
      'lang=$resolvedLang | contract=${routerResult.contractName} | '
      'task=${routerResult.taskLabel} | '
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
