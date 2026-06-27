// ══════════════════════════════════════════════════════════════════════════════
// provider_router_service.dart — Build 226 (Gemini Paid Failover Router)
//
// RESPONSABILIDADE:
//   Roteador de provedor de IA: decide entre Gemini Free (primário) e
//   Gemini Paid via proxy seguro (fallback) — invisível para o usuário.
//
// ARQUITETURA:
//   AiGatewayService.sendStream()
//     → GeminiServiceV2 (Gemini Free — primário)
//     → se falhar (503/RESOURCE_EXHAUSTED/truncado/etc.)
//     → ProviderRouterService.callPaidProxy()
//     → Firebase Function geminiPaidProxy (server-side)
//     → Gemini Paid (gemini-2.5-flash)
//
// SEGURANÇA:
//   • GEMINI_PAID_API_KEY: NUNCA no cliente — lida server-side na Cloud Function
//   • O cliente só recebe o texto da resposta
//   • A chave nunca aparece em logs, bundle web, assets ou respostas de API
//
// ERROS QUE ACIONAM FALLBACK PAGO:
//   • http_503, RESOURCE_EXHAUSTED, UNAVAILABLE, DEADLINE_EXCEEDED
//   • timeout, network, stream_error
//   • resposta vazia
//   • PlantaoParser inválido (parserValid=false) após truncation guard
//
// ERROS QUE NÃO ACIONAM FALLBACK PAGO:
//   • api_key_invalid (chave Free errada — não adianta Paid)
//   • payload inválido local
//   • usuário sem permissão
//
// LOGS:
//   [PROVIDER_ROUTER] requestId= mode= primary= fallback= attempt= reason=
//                     usedProvider= status= inputTokensApprox= outputTokensApprox=
//                     paidFallbackCountToday= estimatedPaidCost=
//   [PAID_PROXY] requestId= success= status= model= tokensApprox= durationMs=
//   [BUDGET_GUARD] allowed= reason= paidFallbackCountToday= paidFallbackMaxPerDay=
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, kIsWeb;
import 'package:http/http.dart' as http;
import 'auth_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PaidProxyResult — resultado da chamada ao proxy pago
// ─────────────────────────────────────────────────────────────────────────────
class PaidProxyResult {
  final String text;
  final bool success;
  final String? errorCode;
  final String model;
  final int inputTokensApprox;
  final int outputTokensApprox;
  final int durationMs;

  const PaidProxyResult({
    required this.text,
    required this.success,
    this.errorCode,
    this.model = '',
    this.inputTokensApprox = 0,
    this.outputTokensApprox = 0,
    this.durationMs = 0,
  });

  factory PaidProxyResult.failure(String code) => PaidProxyResult(
        text: '',
        success: false,
        errorCode: code,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// ProviderRouterService
// ─────────────────────────────────────────────────────────────────────────────
class ProviderRouterService {
  ProviderRouterService._(); // estático — sem instâncias

  // ── URL da Cloud Function (Build 226) ─────────────────────────────────────
  // Substitua pela URL real após o deploy:
  //   firebase deploy --only functions
  //   → https://us-central1-medcases-pro.cloudfunctions.net/geminiPaidProxy
  static const String _proxyUrl =
      'https://us-central1-medcases-pro.cloudfunctions.net/geminiPaidProxy';

  // ── Erros do Gemini Free que acionam fallback pago ────────────────────────
  static const _fallbackTriggerCodes = {
    'http_503',
    'timeout',
    'network',
    'stream_error',
  };

  // Códigos que NÃO devem acionar paid fallback
  static const _noFallbackCodes = {
    'api_key_invalid',
    'safety',
    'content_filter',
  };

  /// Verifica se um errorCode deve acionar o fallback pago.
  static bool shouldTriggerPaidFallback(String? errorCode) {
    if (errorCode == null) return false;
    if (_noFallbackCodes.contains(errorCode)) return false;
    return _fallbackTriggerCodes.contains(errorCode);
  }

  /// BUILD 267: shouldTriggerFallbackForInvalidContent — NEUTRALIZADO.
  /// Princípio: TEXTO RECEBIDO = TEXTO RENDERIZADO.
  /// Nunca descarta resposta médica por contagem de linhas ou estrutura.
  /// Único caso de descarte: texto vazio (nada a exibir).
  static bool shouldTriggerFallbackForInvalidContent(String text) {
    return text.trim().isEmpty; // BUILD 267: apenas vazio é inválido
  }

  // ── callPaidProxy — chama Firebase Function geminiPaidProxy ──────────────
  /// Envia o payload clínico para o proxy seguro.
  /// Obtém ID Token do usuário atual para autenticação.
  /// Retorna [PaidProxyResult] com o texto da resposta.
  static Future<PaidProxyResult> callPaidProxy({
    required String userMessage,
    required String systemPrompt,
    List<Map<String, String>> history = const [],
    String mode = 'plantao',
    String lang = 'pt',
    String requestId = '',
    // BUILD 265: maxOutputTokens 450→800 (liberdade clínica guiada Plantão).
    // Plantão: 800 tok (liberdade de estrutura — até ~600 words).
    // Estudo: 2048 tok (resposta acadêmica completa).
    int maxOutputTokens = 800,
  }) async {
    final startMs = DateTime.now().millisecondsSinceEpoch;

    // ── Obtém ID Token do usuário autenticado ─────────────────────────────
    // Web: FirebaseAuth.instance.currentUser é sempre null (login via REST
    // Identity Toolkit não injeta token no Firebase Auth SDK).
    // Usamos AuthService.getAdminToken() como fonte única de token no Web.
    // Nativo: Firebase Auth SDK — currentUser populado pelo signIn*.
    String idToken;
    if (kIsWeb) {
      try {
        idToken = await AuthService.getAdminToken();
        debugPrint('[WEB_AUTH] source=REST token=${idToken.isNotEmpty} endpoint=geminiPaidProxy');
      } catch (e) {
        debugPrint('[PAID_PROXY] requestId=$requestId token_error=$e');
        return PaidProxyResult.failure('token_error');
      }
      if (idToken.isEmpty) {
        debugPrint('[PAID_PROXY] requestId=$requestId error=unauthenticated (token REST vazio)');
        return PaidProxyResult.failure('unauthenticated');
      }
    } else {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      debugPrint('[NATIVE_AUTH] source=FirebaseSDK uid=${firebaseUser?.uid ?? 'null'} endpoint=geminiPaidProxy');
      if (firebaseUser == null) {
        debugPrint('[PAID_PROXY] requestId=$requestId error=unauthenticated (nativo)');
        return PaidProxyResult.failure('unauthenticated');
      }
      try {
        // BUILD 267: getIdToken() sem force-refresh — evita 2s de latência de rede desnecessária.
        // O token é renovado automaticamente pelo Firebase SDK quando necessario.
        idToken = await firebaseUser.getIdToken() ?? '';
      } catch (e) {
        debugPrint('[PAID_PROXY] requestId=$requestId token_error=$e');
        return PaidProxyResult.failure('token_error');
      }
      if (idToken.isEmpty) {
        debugPrint('[PAID_PROXY] requestId=$requestId error=empty_token');
        return PaidProxyResult.failure('empty_token');
      }
    }

    // ── Monta payload (sem a chave — chave está server-side) ──────────────
    // BUILD 261: Plantão history cap reduzido de 8→4 entries para reduzir tokens.
    // Estudo mantém 8 entries (resposta acadêmica precisa de mais contexto).
    // Cada entry de histórico = ~500-1500 chars → 4 entries ≈ 2000-6000 chars.
    final isPlantao = mode == 'plantao';
    final histCap = isPlantao ? 4 : 8;  // BUILD 261: 4 para Plantão, 8 para Estudo
    final recentHistory = history.length > histCap ? history.sublist(history.length - histCap) : history;

    // ORDEM 42: chaves de engine explícitas no payload para forçar o desvio
    // correto de modelo no geminiPaidProxy.
    //
    // CAUSA RAIZ DETECTADA: o Cloud Function ignorava a chave 'mode' do cliente
    // e forçava execução em gemini-2.5-flash independente do modo solicitado.
    // O Flash aplicava o anticorpo da Ordem 32 (template Plantão) mesmo no
    // Modo Estudo — matando o output acadêmico de 2500 tokens.
    //
    // SOLUÇÃO: três chaves redundantes de override para máxima robustez:
    //   'model'      → nome canônico do modelo (lido diretamente pelo proxy)
    //   'model_tier' → tag de segurança ('speed'|'pro') como bypass de tier
    //   'temperature'→ temperatura correta por modo (0.2 Plantão / 0.4 Estudo)
    //
    // O servidor lê 'model' como override prioritário antes de aplicar seu
    // mapeamento interno de mode→model. Se 'model' estiver presente e válido,
    // o proxy deve usá-lo diretamente. 'model_tier' e 'temperature' são sinais
    // secundários de confirmação para proxies que não lêem 'model' diretamente.
    final _activeModel      = isPlantao ? 'gemini-2.5-flash' : 'gemini-2.5-pro';
    final _activeModelTier  = isPlantao ? 'speed' : 'pro';
    final _activeTemp       = isPlantao ? 0.2 : 0.4;

    final payload = {
      'userMessage':     userMessage,
      'systemPrompt':    systemPrompt,
      'history':         recentHistory,
      'mode':            mode,
      'lang':            lang,
      'requestId':       requestId,
      'maxOutputTokens': maxOutputTokens,  // BUILD 261: forwarded to Cloud Function
      // ORDEM 42: engine override keys — forçam o modelo correto server-side
      'model':           _activeModel,      // override direto de modelo
      'model_tier':      _activeModelTier,  // tag de tier ('speed'|'pro')
      'temperature':     _activeTemp,       // temperatura por modo
      // ORDEM 47 M2: 'tier' como terceira tag de bypass físico no servidor.
      // 'cognitive' = Gemini 2.5 Pro (Estudo) | 'speed' = Flash (Plantão).
      // Tripla sinalização: model + model_tier + tier → desvio garantido.
      'tier':            isPlantao ? 'speed' : 'cognitive',
    };

    if (kDebugMode) {
      debugPrint('[ORDEM47_PAYLOAD] mode=$mode '
          'model=$_activeModel '
          'model_tier=$_activeModelTier '
          'tier=${isPlantao ? "speed" : "cognitive"} '
          'temperature=$_activeTemp '
          'maxOutputTokens=$maxOutputTokens');
    }

    final inputTokensApprox = (jsonEncode(payload).length / 4).ceil();

    // BUILD 252: print diagnóstico do payload — expõe tamanho real do contexto.
    // Sempre visível (não apenas kDebugMode) para diagnóstico de truncamento.
    // ignore: avoid_print
    print('[PAYLOAD_AUDIT] requestId=$requestId mode=$mode '
        'historyEntries=${recentHistory.length} '
        'userMsgLen=${userMessage.length} '
        'systemPromptLen=${systemPrompt.length} '
        'inputTokensApprox=$inputTokensApprox');
    if (inputTokensApprox > 5000) {
      // ignore: avoid_print
      print('[PAYLOAD_AUDIT] ⚠️  ALERTA: payload acima de 5000 tokens '
          '(inputTokensApprox=$inputTokensApprox) — risco de truncamento no proxy. '
          'historyEntries=${recentHistory.length} requestId=$requestId');
    }

    if (kDebugMode) {
      debugPrint('[PROVIDER_ROUTER] '
          'requestId=$requestId '
          'mode=$mode '
          'primary=gemini_free '
          'fallback=gemini_paid '
          'attempt=paid '
          'inputTokensApprox=$inputTokensApprox');
    }

    // ── HTTP POST para a Cloud Function ───────────────────────────────────
    http.Response response;
    try {
      response = await http.post(
        Uri.parse(_proxyUrl),
        headers: {
          'Content-Type':  'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 60)); // BUILD 266: 55s→60s (RAG reativado)
    } on TimeoutException {
      final durationMs = DateTime.now().millisecondsSinceEpoch - startMs;
      debugPrint('[PAID_PROXY] requestId=$requestId success=false status=timeout durationMs=$durationMs');
      return PaidProxyResult.failure('proxy_timeout');
    } catch (e) {
      final durationMs = DateTime.now().millisecondsSinceEpoch - startMs;
      debugPrint('[PAID_PROXY] requestId=$requestId success=false status=network_error durationMs=$durationMs error=$e');
      return PaidProxyResult.failure('proxy_network_error');
    }

    final durationMs = DateTime.now().millisecondsSinceEpoch - startMs;

    // ── Parse da resposta ─────────────────────────────────────────────────
    if (response.statusCode == 429) {
      debugPrint('[BUDGET_GUARD] '
          'allowed=false '
          'reason=paid_budget_guard_triggered '
          'requestId=$requestId');
      return PaidProxyResult.failure('paid_budget_guard_triggered');
    }

    if (response.statusCode == 503) {
      debugPrint('[PAID_PROXY] requestId=$requestId success=false status=paid_fallback_disabled');
      return PaidProxyResult.failure('paid_fallback_disabled');
    }

    if (response.statusCode != 200) {
      String errorCode = 'proxy_error_${response.statusCode}';
      try {
        // ORDEM 50 M2: allowMalformed:true tolera bytes órfãos na borda do
        // stream (emojis truncados por timeout) sem travar o canvas de fontes.
        final decodedErr = utf8.decode(response.bodyBytes, allowMalformed: true);
        final body = jsonDecode(decodedErr) as Map<String, dynamic>;
        errorCode = body['error']?.toString() ?? errorCode;
      } catch (_) {}
      debugPrint('[PAID_PROXY] requestId=$requestId success=false status=${response.statusCode} '
          'error=$errorCode durationMs=$durationMs');
      return PaidProxyResult.failure(errorCode);
    }

    Map<String, dynamic> body;
    try {
      // ORDEM 46 M1: utf8.decode(bodyBytes) garante suporte correto a acentos
      // (á, é, í, ó, ú, ñ) — evita mismatch ISO-8859-1 que corrompia output Plantão.
      // ORDEM 50 M2: allowMalformed:true — tolera bytes órfãos (�) na borda do chunk
      // sem lançar FormatException que travava o canvas de fontes do Flutter.
      final decodedBody = utf8.decode(response.bodyBytes, allowMalformed: true);
      body = jsonDecode(decodedBody) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[PAID_PROXY] requestId=$requestId success=false status=parse_error');
      return PaidProxyResult.failure('parse_error');
    }

    final text              = body['text']?.toString() ?? '';
    final model             = body['model']?.toString() ?? '';
    final outputTokensApprox = (body['outputTokensApprox'] as num?)?.toInt() ?? (text.length / 4).ceil();

    if (text.isEmpty) {
      debugPrint('[PAID_PROXY] requestId=$requestId success=false status=empty_response');
      return PaidProxyResult.failure('empty_response');
    }

    debugPrint('[PAID_PROXY] '
        'requestId=$requestId '
        'success=true '
        'status=200 '
        'model=$model '
        'inputTokensApprox=$inputTokensApprox '
        'outputTokensApprox=$outputTokensApprox '
        'durationMs=$durationMs');

    debugPrint('[PROVIDER_ROUTER] '
        'requestId=$requestId '
        'mode=$mode '
        'primary=gemini_free '
        'fallback=gemini_paid '
        'usedProvider=gemini_paid '
        'status=success '
        'inputTokensApprox=$inputTokensApprox '
        'outputTokensApprox=$outputTokensApprox '
        'durationMs=$durationMs');

    return PaidProxyResult(
      text:               text,
      success:            true,
      model:              model,
      inputTokensApprox:  inputTokensApprox,
      outputTokensApprox: outputTokensApprox,
      durationMs:         durationMs,
    );
  }

  // ── testPaidProxy — testa a conectividade com a Cloud Function ───────────
  /// Usado pelo Painel Admin para testar se a chave paga está configurada.
  /// Envia um payload mínimo e verifica se a resposta é válida.
  static Future<({bool online, String detail})> testPaidProxy() async {
    try {
      final result = await callPaidProxy(
        userMessage:  'Teste de conectividade MedCases Pro. Responda apenas: OK',
        systemPrompt: 'Responda em uma palavra.',
        mode:         'test',
        requestId:    'admin_test_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (result.success && result.text.isNotEmpty) {
        debugPrint('[ADMIN_AI_KEY] test=true status=online model=${result.model}');
        return (online: true, detail: 'gemini_paid online • ${result.model} • ${result.durationMs}ms');
      }
      debugPrint('[ADMIN_AI_KEY] test=true status=offline error=${result.errorCode}');
      return (online: false, detail: result.errorCode ?? 'unknown_error');
    } catch (e) {
      debugPrint('[ADMIN_AI_KEY] test=true status=offline error=$e');
      return (online: false, detail: e.toString());
    }
  }

  // ── Gera requestId único por turno ────────────────────────────────────────
  static String generateRequestId() {
    final now = DateTime.now();
    return 'req_${now.millisecondsSinceEpoch}';
  }
}
