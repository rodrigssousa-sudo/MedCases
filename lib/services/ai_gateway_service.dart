// ══════════════════════════════════════════════════════════════════════════════
// ModeAnchorEngine / AiGatewayService — Build 156 (Client-Side Intelligence)
//
// ┌─────────────────────────────────────────────────────────────────────────┐
// │  PIVÔ ARQUITETURAL — Build 156                                          │
// │                                                                         │
// │  O backend Node.js/Express (server.js no Digital Ocean) foi um          │
// │  "backend fantasma": medcasespro.com serve apenas arquivos estáticos    │
// │  Flutter Web e retorna 405 Method Not Allowed para qualquer POST.       │
// │                                                                         │
// │  NOVA ARQUITETURA (Serverless / Descentralizado):                       │
// │    Flutter → generativelanguage.googleapis.com (direto, com BYOA key)  │
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
//     → Limite rígido: ≤14 linhas, flashcard cirúrgico, zero enciclopédia
//     → HARD: primeira linha = 🟥 CONDUTA IMEDIATA
//
//   Motor Estudos (longResponse=true):
//     → Injeta MODE_ANCHOR_ESTUDO no topo do systemPrompt
//     → Limite expandido: ≤24 linhas, preceptor clínico, ACRONYM RULE
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
//         → generativelanguage.googleapis.com   [API Google — BYOA]
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
// MODE_ANCHOR_PLANTAO — Motor de Plantão (Build 156)
//
// Injetado no TOPO do systemPrompt quando longResponse=false.
// Equivalente ao PROMPT_MODO_PLANTAO + MODE_ANCHOR_PLANTAO do servidor Node.
// Prioridade máxima — sobrescreve qualquer outra regra de formato.
// ─────────────────────────────────────────────────────────────────────────────
const String _modeAnchorPlantao =
    '╔══════════════════════════════════════════════════════════════════╗\n'
    '║  MOTOR PLANTÃO — Build 156 — PRIORIDADE MÁXIMA ABSOLUTA         ║\n'
    '║  Esta âncora sobrescreve QUALQUER outra regra de formato abaixo. ║\n'
    '╚══════════════════════════════════════════════════════════════════╝\n'
    '\n'
    'IDENTIDADE ATIVA: FLASHCARD DE EMERGÊNCIA MÉDICA.\n'
    'Output permitido: fármacos + doses + vias. Nada além disso.\n'
    '\n'
    'CONTRATO DE TAMANHO — INEGOCIÁVEL:\n'
    '  📏 LIMITE ABSOLUTO: ≤ 14 LINHAS NO TOTAL (linhas em branco contam).\n'
    '  📏 Cada bloco (🟥 ⛔ 📌) = máximo 4 linhas.\n'
    '  📏 Se ultrapassar 14 linhas → CORTE. Prioridade: 🟥 > ⛔ > 📌.\n'
    '\n'
    'REGRA DE ABERTURA — FERRO:\n'
    '  PRIMEIRA LINHA de toda resposta = 🟥 CONDUTA IMEDIATA (PT)\n'
    '                               ou = 🟥 CONDUCTA INMEDIATA (ES)\n'
    '  NUNCA começar com texto explicativo, definição ou preâmbulo.\n'
    '\n'
    'TRAVA ANTI-ENCICLOPÉDIA:\n'
    '  ✗ PROIBIDO: parágrafos, fisiopatologia, definições, "é importante..."\n'
    '  ✓ OBRIGATÓRIO: **FÁRMACO DOSE VIA** — uma linha telegráfica\n'
    '\n';

// ─────────────────────────────────────────────────────────────────────────────
// MODE_ANCHOR_ESTUDO — Motor de Estudos (Build 156)
//
// Injetado no TOPO do systemPrompt quando longResponse=true.
// Equivalente ao PROMPT_MODO_ESTUDO + MODE_ANCHOR_ESTUDO do servidor Node.
// ─────────────────────────────────────────────────────────────────────────────
const String _modeAnchorEstudo =
    '╔══════════════════════════════════════════════════════════════════╗\n'
    '║  MOTOR ESTUDOS — Build 156 — PRIORIDADE MÁXIMA ABSOLUTA         ║\n'
    '║  Esta âncora sobrescreve QUALQUER outra regra de formato abaixo. ║\n'
    '╚══════════════════════════════════════════════════════════════════╝\n'
    '\n'
    'IDENTIDADE ATIVA: PRECEPTOR CLÍNICO DE ELITE em modo de revisão técnica.\n'
    'Objetivo: profundidade clínica sem prolixidade acadêmica.\n'
    '\n'
    'CONTRATO DE TAMANHO — EXPANDIDO:\n'
    '  📏 LIMITE: ≤ 24 LINHAS NO TOTAL.\n'
    '  📏 Cada seção temática = máximo 6 linhas.\n'
    '  📏 Priorize densidade clínica sobre extensão narrativa.\n'
    '\n'
    'ESTRUTURA PERMITIDA NESTE MOTOR:\n'
    '  ✓ Mecanismo de ação (2-3 linhas)\n'
    '  ✓ Indicações + doses (bloco 🟥 expandido — até 6 linhas)\n'
    '  ✓ Comparação entre fármacos quando relevante\n'
    '  ✓ Evidência clínica em 1 linha (guideline + ano)\n'
    '  ✓ Red flags / contraindicações (bloco ⛔ — até 4 linhas)\n'
    '\n'
    'RAG OVERRIDE RULE — CRÍTICO:\n'
    '  Os clinical_guides injetados no contexto têm tom enciclopédico.\n'
    '  ✗ PROIBIDO: copiar esse tom ou listar "Causas", "Epidemiologia"\n'
    '  ✓ OBRIGATÓRIO: usar o conteúdo como matéria-prima, reformatar\n'
    '    em linguagem de preceptor direto — como colega sênior, não manual\n'
    '\n'
    'ACRONYM RULE:\n'
    '  IAM/AVC/TEP/SCA/PCR/FA/ICC/IRA/EAP → SEMPRE termo médico.\n'
    '  NUNCA interpretar como jargão de TI, negócios ou inglês.\n'
    '\n';

// ─────────────────────────────────────────────────────────────────────────────
// ModeAnchorEngine — Injeção de âncora de modo (Build 156)
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
      '[ModeAnchorEngine] motor=${longResponse ? "ESTUDO" : "PLANTÃO"} '
      'injetado (${anchor.length} chars)',
    );
    return '$anchor\n$systemPrompt';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AiGatewayService — Shim de compatibilidade reversa (Build 156)
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

  /// Build 156: sempre false — gateway Node.js desativado.
  static bool get forceGateway => false;
  // ignore: avoid_setters_without_getters
  static set forceGateway(bool _) {} // no-op

  /// Build 156: isConfigured é sempre true — sem pré-requisito de servidor.
  /// A chave BYOA é validada no momento da chamada via GeminiServiceV2.
  static bool get isConfigured => true;

  /// Build 156: configure() é no-op — URL de gateway não existe mais.
  static void configure({required String baseUrl}) {
    debugPrint(
      '[AiGatewayService] Build 156: configure() ignorado — '
      'gateway desativado. Flutter fala direto com Google.',
    );
  }

  // ── sendStream — Interface principal ──────────────────────────────────────

  /// Envia mensagem ao Gemini com motor selecionado.
  ///
  /// Build 156: delega para ModeAnchorEngine + GeminiServiceV2.sendStream().
  /// A âncora de modo é injetada internamente no [systemPrompt].
  ///
  /// [userMessage]  — pergunta clínica do usuário
  /// [systemPrompt] — prompt base montado pelo AiService (sem âncora)
  /// [apiKey]       — chave Gemini BYOA do usuário (NOVO parâmetro Build 156)
  /// [history]      — histórico de turnos [{role, content}]
  /// [useGrounding] — repassado ao GeminiServiceV2 (Google Search Grounding)
  /// [longResponse] — false=Motor Plantão / true=Motor Estudos
  static Stream<GeminiChunk> sendStream({
    required String userMessage,
    required String systemPrompt,
    required String apiKey,                // ← NOVO em Build 156 (era server-side)
    List<Map<String, String>> history = const [],
    bool useGrounding = true,
    bool longResponse = false,
  }) {
    if (apiKey.isEmpty) {
      debugPrint('[AiGatewayService] Build 156: apiKey vazia → erro');
      return Stream.value(GeminiChunk.error('api_key_invalid'));
    }

    // Injeta âncora de modo no topo do systemPrompt
    final anchoredPrompt = ModeAnchorEngine.injectModeAnchor(
      systemPrompt,
      longResponse: longResponse,
    );

    final motor = longResponse ? 'ESTUDO' : 'PLANTÃO';
    debugPrint(
      '[AiGatewayService] Build 156: motor=$motor → '
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
