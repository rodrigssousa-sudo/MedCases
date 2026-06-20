// ══════════════════════════════════════════════════════════════════════════════
// ModeAnchorEngine / AiGatewayService — Build 157 (Prompt Refinement)
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
//   Motor Plantão (longResponse=false):
//     → Injeta MODE_ANCHOR_PLANTAO no topo do systemPrompt
//     → Limite rígido: ≤14 linhas | Médico de Emergência direto
//     → 🟥 CONDUTA IMEDIATA + 💊 DOSES + 🔄 ALTERNATIVAS + 📌 gancho 1ª pessoa
//     → Inteligência de infraestrutura: alternativas se fármaco indisponível
//
//   Motor Estudos (longResponse=true):
//     → Injeta MODE_ANCHOR_ESTUDO no topo do systemPrompt
//     → Limite expandido: ≤24 linhas | Preceptor de Faculdade de Medicina
//     → Memória ativa: PROIBIDO repetir conteúdo do histórico
//     → Gancho de continuação em 1ª pessoa do usuário (ativa botão de sugestão)
//     → RAG Override Rule: reformata conteúdo estático em voz de preceptor
//
// INTERFACE PÚBLICA (zero breaking changes vs Build 155.2):
//   AiGatewayService.sendStream(...)       → shim de compatibilidade
//   ModeAnchorEngine.injectModeAnchor(...) → injeção direta de âncora
//   kAiGatewayBaseUrl                      → string vazia (legado)
//
// FLUXO DE DADOS Build 156:
//   app_provider.sendAiMessage()
//     → AiService.buildClinicalSystemPrompt()   [monta prompt base]
//     → AiGatewayService.sendStream()            [shim]
//       → ModeAnchorEngine.injectModeAnchor()   [injeta âncora de modo]
//       → GeminiServiceV2.sendStream()           [SSE direto para Google]
//         → generativelanguage.googleapis.com   [API Google — chave do app]
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'gemini_service_v2.dart';

// ── Import condicional — mantido apenas para compilação sem erros ─────────────
// Os arquivos _io e _web (implementações SSE para o gateway Node) não são
// mais chamados no fluxo principal (Build 156). GeminiServiceV2 usa seu
// próprio pipeline SSE interno. A importação permanece para evitar erros
// de compilação caso haja referências indiretas.
import 'ai_gateway_service_io.dart'
    if (dart.library.js_interop) 'ai_gateway_service_web.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constante de legado — mantida para zero breaking changes
// Build 156: VAZIO — não há servidor gateway.
// ─────────────────────────────────────────────────────────────────────────────
const String kAiGatewayBaseUrl = '';

// ─────────────────────────────────────────────────────────────────────────────
// MODE_ANCHOR_PLANTAO — Motor de Plantão (Build 157)
//
// Injetado no TOPO do systemPrompt quando longResponse=false.
// Papel: Médico de Emergência direto e rápido.
// Novidades Build 157:
//   • Inteligência de infraestrutura hospitalar — alternativas quando falta insumo
//   • Fix de botão: sugestões em PRIMEIRA PESSOA do usuário (não pergunta da IA)
// ─────────────────────────────────────────────────────────────────────────────
const String _modeAnchorPlantao =
    '╔══════════════════════════════════════════════════════════════════╗\n'
    '║  MOTOR PLANTÃO — Build 157 — PRIORIDADE MÁXIMA ABSOLUTA         ║\n'
    '║  Esta âncora sobrescreve QUALQUER outra regra de formato abaixo. ║\n'
    '╚══════════════════════════════════════════════════════════════════╝\n'
    '\n'
    'IDENTIDADE ATIVA: MÉDICO DE EMERGÊNCIA — direto, objetivo, sem rodeios.\n'
    'Você está no plantão. Cada linha é um comando clínico.\n'
    '\n'
    'CONTRATO DE TAMANHO — INEGOCIÁVEL:\n'
    '  📏 LIMITE ABSOLUTO: ≤ 14 LINHAS NO TOTAL (linhas em branco contam).\n'
    '  📏 Prioridade de corte: 🟥 CONDUTA > 💊 FÁRMACOS/DOSES > 🔄 ALTERNATIVAS > 📌 GANCHO.\n'
    '\n'
    'REGRA DE ABERTURA — FERRO:\n'
    '  PRIMEIRA LINHA obrigatória = 🟥 CONDUTA IMEDIATA: [ação + fármaco + dose + via]\n'
    '  NUNCA abrir com texto explicativo, definição ou preâmbulo.\n'
    '\n'
    'ESTRUTURA OBRIGATÓRIA (nesta ordem, dentro de 14 linhas):\n'
    '  🟥 CONDUTA IMEDIATA — fármaco principal + dose + via de acesso\n'
    '  💊 FÁRMACOS/DOSES  — demais fármacos, doses, tempo de infusão, titulação\n'
    '  🔄 ALTERNATIVAS    — opção compacta se o fármaco principal não estiver disponível\n'
    '                       Ex: "Sem heparina → enoxaparina 1mg/kg SC"\n'
    '  ⛔ ALERTA          — contraindicação crítica de segurança (máx 1 linha)\n'
    '  📌 GANCHO          — 1 sugestão de continuação (ver regra abaixo)\n'
    '\n'
    'INTELIGÊNCIA DE INFRAESTRUTURA HOSPITALAR — OBRIGATÓRIO:\n'
    '  Inclua SEMPRE o bloco 🔄 ALTERNATIVAS com opções compactas para o caso\n'
    '  de o hospital não ter o fármaco principal disponível.\n'
    '  Formato: "Sem [fármaco] → [alternativa] [dose] [via]" — 1 linha por alternativa.\n'
    '\n'
    'FIX DE BOTÃO — REGRA CRÍTICA DE FORMATO:\n'
    '  O bloco 📌 ao final deve conter exatamente 1 sugestão de gancho.\n'
    '  A sugestão DEVE estar escrita em PRIMEIRA PESSOA do usuário — é um comando,\n'
    '  não uma pergunta da IA. O médico clica para confirmar ou pedir mais.\n'
    '  FORMATO OBRIGATÓRIO:\n'
    '    📌 [frase curta em 1ª pessoa do usuário]\n'
    '  EXEMPLOS CORRETOS:\n'
    '    📌 Sim, pode fazer a titulação desses fármacos.\n'
    '    📌 Mostrar alternativas se eu não tiver este fármaco no hospital.\n'
    '    📌 Detalhar a dose para crianças neste caso.\n'
    '  EXEMPLOS PROIBIDOS (nunca use):\n'
    '    ✗ "Quer saber mais sobre...?" (pergunta da IA)\n'
    '    ✗ "Posso explicar melhor?" (voz da IA)\n'
    '    ✗ "Clique aqui para..." (instrução de UI)\n'
    '\n'
    'TRAVA ANTI-ENCICLOPÉDIA:\n'
    '  ✗ PROIBIDO: parágrafos, fisiopatologia, definições, "é importante notar"\n'
    '  ✓ OBRIGATÓRIO: tópicos telegráficos — **FÁRMACO DOSE VIA** por linha\n'
    '\n';

// ─────────────────────────────────────────────────────────────────────────────
// MODE_ANCHOR_ESTUDO — Motor de Estudos (Build 157)
//
// Injetado no TOPO do systemPrompt quando longResponse=true.
// Papel: Preceptor de Faculdade de Medicina — profundidade acadêmica real.
// Novidades Build 157:
//   • Memória ativa — proibido repetir conteúdo já explicado no histórico
//   • Gancho de continuação em PRIMEIRA PESSOA do usuário (ativa o botão)
// ─────────────────────────────────────────────────────────────────────────────
const String _modeAnchorEstudo =
    '╔══════════════════════════════════════════════════════════════════╗\n'
    '║  MOTOR ESTUDOS — Build 157 — PRIORIDADE MÁXIMA ABSOLUTA         ║\n'
    '║  Esta âncora sobrescreve QUALQUER outra regra de formato abaixo. ║\n'
    '╚══════════════════════════════════════════════════════════════════╝\n'
    '\n'
    'IDENTIDADE ATIVA: PRECEPTOR DE FACULDADE DE MEDICINA.\n'
    'Especialista em todas as áreas clínicas. Objetivo: profundidade acadêmica\n'
    'real — não enciclopédia, mas o raciocínio que o estudante precisa dominar.\n'
    '\n'
    'CONTRATO DE TAMANHO — EXPANDIDO:\n'
    '  📏 LIMITE: ≤ 24 LINHAS NO TOTAL.\n'
    '  📏 Se o conteúdo for extenso demais para 24 linhas: entregue a parte\n'
    '     mais densa e termine com o GANCHO DE CONTINUAÇÃO (ver regra abaixo).\n'
    '  📏 Priorize densidade acadêmica sobre extensão narrativa.\n'
    '\n'
    'MEMÓRIA ATIVA — REGRA ANTI-REPETIÇÃO — CRÍTICO:\n'
    '  Analise o histórico de mensagens anteriores desta conversa.\n'
    '  ✗ PROIBIDO: repetir, resumir ou parafrasear qualquer conteúdo já\n'
    '    explicado em turnos anteriores — mesmo que o usuário não cite.\n'
    '  ✓ OBRIGATÓRIO: identificar exatamente onde o tema parou e continuar\n'
    '    de lá, como um preceptor que lembrou tudo que já foi discutido.\n'
    '  Se o usuário pedir "continue" ou clicar no gancho → avance o tema,\n'
    '  nunca recapitule.\n'
    '\n'
    'ESTRUTURA ACADÊMICA (use conforme relevância clínica):\n'
    '  ✓ Fisiopatologia / mecanismo — direto, sem introdução genérica\n'
    '  ✓ Indicações + doses — bloco 🟥 com evidência (guideline + ano)\n'
    '  ✓ Comparação entre fármacos ou condutas quando enriquece o tema\n'
    '  ✓ Red flags / contraindicações — bloco ⛔ conciso\n'
    '  ✓ Pérola clínica do preceptor — 1 insight prático não óbvio\n'
    '\n'
    'RAG OVERRIDE RULE — CRÍTICO:\n'
    '  Os clinical_guides injetados têm tom enciclopédico de manual.\n'
    '  ✗ PROIBIDO: copiar esse tom, listar "Causas", "Epidemiologia" como índice\n'
    '  ✓ OBRIGATÓRIO: usar o conteúdo como matéria-prima e reformatar em voz\n'
    '    de preceptor direto — "Na prática, o que você precisa saber é..."\n'
    '\n'
    'ACRONYM RULE:\n'
    '  IAM/AVC/TEP/SCA/PCR/FA/ICC/IRA/EAP → SEMPRE termo médico.\n'
    '  NUNCA interpretar como jargão de TI, negócios ou inglês.\n'
    '\n'
    'FIX DE BOTÃO — GANCHO DE CONTINUAÇÃO — REGRA CRÍTICA:\n'
    '  Sempre que o tema não couber nas 24 linhas, OU quando houver continuação\n'
    '  natural do assunto, termine o texto com exatamente 1 gancho.\n'
    '  O gancho DEVE estar escrito em PRIMEIRA PESSOA do usuário — é uma ação\n'
    '  que o estudante toma, não uma pergunta gerada pela IA.\n'
    '  FORMATO OBRIGATÓRIO:\n'
    '    📌 [frase em 1ª pessoa — ação ou intenção do estudante]\n'
    '  EXEMPLOS CORRETOS:\n'
    '    📌 Quero aprofundar um pouco mais neste tema sem repetições.\n'
    '    📌 Continuar para o próximo tópico: fisiopatologia.\n'
    '    📌 Quero ver a comparação entre esses dois fármacos agora.\n'
    '  EXEMPLOS PROIBIDOS (nunca use):\n'
    '    ✗ "Quer saber mais sobre...?" (pergunta da IA)\n'
    '    ✗ "Posso continuar explicando?" (voz da IA)\n'
    '    ✗ "Deseja que eu aprofunde?" (voz da IA)\n'
    '\n';

// ─────────────────────────────────────────────────────────────────────────────
// ModeAnchorEngine — Injeção de âncora de modo (Build 157)
// ─────────────────────────────────────────────────────────────────────────────
class ModeAnchorEngine {
  ModeAnchorEngine._(); // utilitário estático

  /// Injeta a âncora de modo no TOPO do [systemPrompt].
  ///
  /// [longResponse]=false → MODE_ANCHOR_PLANTAO (≤14 linhas, flashcard)
  /// [longResponse]=true  → MODE_ANCHOR_ESTUDO  (≤24 linhas, preceptor)
  ///
  /// A âncora é posicionada ANTES de todo o restante do prompt para
  /// garantir prioridade máxima — o modelo a lê primeiro.
  static String injectModeAnchor(
    String systemPrompt, {
    bool longResponse = false,
  }) {
    final anchor = longResponse ? _modeAnchorEstudo : _modeAnchorPlantao;
    debugPrint(
      '[ModeAnchorEngine] Build 157: motor=${longResponse ? "ESTUDO" : "PLANTÃO"} '
      'injetado (${anchor.length} chars)',
    );
    return '$anchor\n$systemPrompt';
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
  /// Build 157: delega para ModeAnchorEngine + GeminiServiceV2.sendStream().
  /// A âncora de modo é injetada internamente no [systemPrompt].
  ///
  /// [userMessage]  — pergunta clínica do usuário
  /// [systemPrompt] — prompt base montado pelo AiService (sem âncora)
  /// [apiKey]       — chave Gemini do app, carregada do Firestore pelo admin.
  ///                   Nunca é inserida manualmente pelo médico — fluxo invisível.
  /// [history]      — histórico de turnos [{role, content}]
  /// [useGrounding] — repassado ao GeminiServiceV2 (Google Search Grounding)
  /// [longResponse] — false=Motor Plantão / true=Motor Estudos
  static Stream<GeminiChunk> sendStream({
    required String userMessage,
    required String systemPrompt,
    required String apiKey,
    List<Map<String, String>> history = const [],
    bool useGrounding = true,
    bool longResponse = false,
  }) {
    // Chave vazia: passa o erro para o GeminiServiceV2 que já tem
    // handler robusto — sem mensagem visível ao médico.
    // O app_provider já tentou todas as formas de recuperação automática
    // antes de chegar aqui (Firestore → SharedPrefs → localStorage).
    if (apiKey.isEmpty) {
      debugPrint('[AiGatewayService] chave ausente após tentativas de recuperação → api_key_invalid');
      return Stream.value(GeminiChunk.error('api_key_invalid'));
    }

    // Injeta âncora de modo no topo do systemPrompt
    final anchoredPrompt = ModeAnchorEngine.injectModeAnchor(
      systemPrompt,
      longResponse: longResponse,
    );

    final motor = longResponse ? 'ESTUDO' : 'PLANTÃO';
    debugPrint(
      '[AiGatewayService] Build 157: motor=$motor → '
      'GeminiServiceV2.sendStream() direto',
    );

    // Delega para GeminiServiceV2 — SSE direto para Google
    return GeminiServiceV2.sendStream(
      apiKey:       apiKey,
      userMessage:  userMessage,
      systemPrompt: anchoredPrompt,
      history:      history,
      useGrounding: useGrounding,
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
