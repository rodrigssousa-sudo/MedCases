// ══════════════════════════════════════════════════════════════════════════════
// gemini_cache_service.dart — Context Caching para Gemini API v1beta
//
// PROBLEMA RESOLVIDO:
//   O systemPrompt fixo do MedCases Pro atingiu ~26.000 chars (~6.500 tokens).
//   Enviar esse payload em CADA request causa:
//     • 503 Service Unavailable por sobrecarga de throughput
//     • Latência elevada (o modelo processa 6.500 tokens extras por turno)
//     • Custo desnecessário em tokens de entrada
//
// SOLUÇÃO — Context Caching nativo da Gemini API v1beta:
//   1. Na primeira chamada (ou quando o cache expirou): faz upload do
//      systemPrompt para o servidor do Google com TTL de 1 hora.
//      → Google retorna um `cachedContent.name` (ex: "cachedContents/xyz123")
//   2. Nas chamadas subsequentes: referencia o cache pelo ID, enviando
//      apenas a nova mensagem do usuário e o histórico recente.
//      → Redução de throughput: de ~6.500 → ~100 tokens de entrada por turno.
//
// LIMITAÇÕES DA API:
//   • TTL mínimo: 1 hora (600 segundos mínimo no endpoint, mas Google recomenda 3600s)
//   • Tamanho mínimo do conteúdo cacheado: 1024 tokens (sistemas grandes OK)
//   • Cache NÃO é compartilhado entre chaves de API diferentes
//   • O ID do cache deve ser renovado antes da expiração
//   • Context Caching NÃO é compatível com Google Search Grounding ativo
//     (grounding gera tool_call parts — incompatível com cachedContents fixo)
//   • Modelos compatíveis: gemini-2.5-flash-lite e superiores
//
// ARQUITETURA:
//   GeminiCacheService (this file)
//     ↑ usado por
//   AiGatewayService.sendStream()
//     → ao montar finalSystemPrompt, verifica cache ativo
//     → se cache ativo: usa cachedContent.name no payload em vez de system_instruction
//     → se sem cache: faz upload e armazena ID
//
// PERSISTÊNCIA DO CACHE ID:
//   SharedPreferences (chave: 'gemini_cache_name_v1')
//   Expiração: timestamp salvo em 'gemini_cache_expires_v1'
//   Fingerprint do prompt: 'gemini_cache_fp_v1' (detecta mudança de sistema)
//
// LOGS ESTRUTURADOS:
//   [GEMINI_CACHE] action=create|hit|miss|expired|error status= name= ttlSecs=
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GeminiCacheEntry — estado do cache em memória
// ─────────────────────────────────────────────────────────────────────────────
class GeminiCacheEntry {
  /// ID canônico do cache (ex: "cachedContents/abc123xyz").
  /// Incluído no payload como `cachedContent` em vez de `system_instruction`.
  final String name;

  /// Timestamp de expiração (UTC). Renovar antes deste momento.
  final DateTime expiresAt;

  /// Fingerprint (hash simples) do systemPrompt que gerou este cache.
  /// Invalida o cache se o prompt mudou (deploy com novo sistem prompt).
  final int promptFingerprint;

  const GeminiCacheEntry({
    required this.name,
    required this.expiresAt,
    required this.promptFingerprint,
  });

  /// true → cache ainda válido (não expirou E não vai expirar em 5min).
  /// Margem de 5min para renovar antes da expiração.
  bool get isValid =>
      DateTime.now().toUtc().isBefore(expiresAt.subtract(const Duration(minutes: 5)));

  @override
  String toString() =>
      'GeminiCacheEntry(name=$name, expiresAt=$expiresAt, valid=$isValid)';
}

// ─────────────────────────────────────────────────────────────────────────────
// GeminiCacheService — serviço estático de Context Caching
// ─────────────────────────────────────────────────────────────────────────────
class GeminiCacheService {
  GeminiCacheService._(); // utilitário 100% estático — sem instâncias

  // ══ ENDPOINTS ══════════════════════════════════════════════════════════════

  /// Endpoint de gerenciamento de caches (v1beta).
  static const _cacheBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/cachedContents';

  /// Modelo compatível com Context Caching.
  /// BUILD 334: sincronizado com GeminiServiceV2._modelId → gemini-2.5-flash.
  static const _cacheModel = 'models/gemini-2.5-flash';

  // ══ CONFIGURAÇÃO ═══════════════════════════════════════════════════════════

  /// TTL do cache em segundos. 3600s = 1 hora (mínimo recomendado pelo Google).
  static const _cacheTtlSeconds = 3600;

  /// Tamanho mínimo do prompt (chars) para acionar o caching.
  /// Prompts menores que isso não justificam o overhead de criação de cache.
  /// ~4000 chars ≈ 1000 tokens → abaixo do mínimo obrigatório da API (1024 tokens).
  static const _minPromptCharsForCaching = 4000;

  // ══ CHAVES DE PERSISTÊNCIA ════════════════════════════════════════════════

  static const _kCacheName    = 'gemini_cache_name_v1';
  static const _kCacheExpires = 'gemini_cache_expires_v1';
  static const _kCacheFp      = 'gemini_cache_fp_v1';

  // ══ ESTADO EM MEMÓRIA ═════════════════════════════════════════════════════

  /// Cache ativo em memória (null = sem cache ou expirado).
  static GeminiCacheEntry? _activeCache;

  /// Lock para evitar criação paralela de múltiplos caches simultâneos.
  static Future<GeminiCacheEntry?>? _createInFlight;

  // ══ FINGERPRINT ═══════════════════════════════════════════════════════════

  /// Hash simples mas rápido do prompt — detecta mudanças de deploy.
  /// Usa o comprimento + checksum dos primeiros/últimos 500 chars.
  static int _fingerprint(String prompt) {
    if (prompt.isEmpty) return 0;
    final head = prompt.substring(0, prompt.length.clamp(0, 500));
    final tail = prompt.substring((prompt.length - 500).clamp(0, prompt.length));
    int h = 17 * prompt.length;
    for (final c in '$head$tail'.codeUnits) {
      h = h * 31 + c;
      h &= 0x7FFFFFFF; // mantém positivo (dart int 64-bit → simula hash 31-bit)
    }
    return h;
  }

  // ══ API PÚBLICA ════════════════════════════════════════════════════════════

  /// Verifica se há um cache válido para o [apiKey] e [systemPrompt] atuais.
  ///
  /// Fluxo:
  ///   1. Memória → se _activeCache válido e fingerprint bate → HIT
  ///   2. SharedPrefs → restaura cache salvo e valida
  ///   3. Miss → retorna null (caller deve chamar [createOrRefresh])
  static Future<GeminiCacheEntry?> getActiveCache({
    required String apiKey,
    required String systemPrompt,
  }) async {
    if (apiKey.isEmpty || systemPrompt.length < _minPromptCharsForCaching) {
      return null; // cache não aplicável para prompts pequenos
    }

    final fp = _fingerprint(systemPrompt);

    // ── 1. HIT em memória ────────────────────────────────────────────────────
    if (_activeCache != null &&
        _activeCache!.isValid &&
        _activeCache!.promptFingerprint == fp) {
      _log('[GEMINI_CACHE] action=hit name=${_activeCache!.name} '
          'expiresAt=${_activeCache!.expiresAt.toIso8601String()}');
      return _activeCache;
    }

    // ── 2. Restaura do SharedPrefs ─────────────────────────────────────────
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName    = prefs.getString(_kCacheName) ?? '';
      final savedExpires = prefs.getString(_kCacheExpires) ?? '';
      final savedFp      = prefs.getInt(_kCacheFp) ?? 0;

      if (savedName.isNotEmpty && savedExpires.isNotEmpty && savedFp == fp) {
        final expiresAt = DateTime.tryParse(savedExpires);
        if (expiresAt != null) {
          final entry = GeminiCacheEntry(
            name:              savedName,
            expiresAt:         expiresAt,
            promptFingerprint: fp,
          );
          if (entry.isValid) {
            _activeCache = entry;
            _log('[GEMINI_CACHE] action=restored name=$savedName '
                'expiresAt=${expiresAt.toIso8601String()}');
            return _activeCache;
          } else {
            _log('[GEMINI_CACHE] action=expired name=$savedName '
                'expiresAt=${expiresAt.toIso8601String()}');
          }
        }
      }
    } catch (e) {
      _log('[GEMINI_CACHE] action=prefs_error error=$e');
    }

    _log('[GEMINI_CACHE] action=miss promptLen=${systemPrompt.length} fp=$fp');
    return null;
  }

  /// Cria um novo cache (ou aguarda a criação em voo se já há uma em andamento).
  ///
  /// Thread-safe: usa [_createInFlight] para evitar múltiplas criações paralelas.
  /// Em caso de erro de API: retorna null silenciosamente (não bloqueia o usuário).
  ///
  /// IMPORTANTE: Context Caching é INCOMPATÍVEL com Google Search Grounding.
  /// Se useGrounding=true, o cache NÃO deve ser usado no payload — use o
  /// system_instruction normal. Esta função ainda cria o cache para reuso futuro
  /// em chamadas sem grounding.
  static Future<GeminiCacheEntry?> createOrRefresh({
    required String apiKey,
    required String systemPrompt,
  }) async {
    if (apiKey.isEmpty || systemPrompt.length < _minPromptCharsForCaching) {
      return null;
    }

    // ── Lock de voo único ────────────────────────────────────────────────────
    final inFlight = _createInFlight;
    if (inFlight != null) {
      _log('[GEMINI_CACHE] action=wait_in_flight');
      return inFlight;
    }

    final completer = Completer<GeminiCacheEntry?>();
    _createInFlight = completer.future;

    try {
      final entry = await _doCreate(apiKey: apiKey, systemPrompt: systemPrompt);
      completer.complete(entry);
      return entry;
    } catch (e) {
      _log('[GEMINI_CACHE] action=create_error error=$e');
      completer.complete(null);
      return null;
    } finally {
      _createInFlight = null;
    }
  }

  /// Invalida o cache em memória e no SharedPrefs (ex: após troca de API key).
  static Future<void> invalidate() async {
    _activeCache    = null;
    _createInFlight = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kCacheName);
      await prefs.remove(_kCacheExpires);
      await prefs.remove(_kCacheFp);
    } catch (_) {}
    _log('[GEMINI_CACHE] action=invalidated');
  }

  /// Retorna true se há um cache válido em memória (sem I/O).
  static bool get hasValidCacheInMemory =>
      _activeCache != null && _activeCache!.isValid;

  // ══ IMPLEMENTAÇÃO INTERNA ═════════════════════════════════════════════════

  /// Faz o POST para criar o cachedContent no servidor Google.
  static Future<GeminiCacheEntry?> _doCreate({
    required String apiKey,
    required String systemPrompt,
  }) async {
    final fp = _fingerprint(systemPrompt);

    // Verifica novamente se em memória já temos cache válido (pode ter sido
    // criado por outra chamada enquanto aguardávamos o lock).
    if (_activeCache != null &&
        _activeCache!.isValid &&
        _activeCache!.promptFingerprint == fp) {
      return _activeCache;
    }

    _log('[GEMINI_CACHE] action=create promptLen=${systemPrompt.length} '
        'model=$_cacheModel ttl=${_cacheTtlSeconds}s');

    final url = Uri.parse('$_cacheBaseUrl?key=$apiKey');

    // Payload conforme spec da Gemini API v1beta cachedContents:
    //   https://ai.google.dev/api/caching#v1beta.CachedContent
    final body = jsonEncode({
      'model': _cacheModel,
      'system_instruction': {
        'parts': [
          {'text': systemPrompt}
        ],
      },
      // ttl: formato Duration string conforme proto3 Duration ("3600s")
      'ttl': '${_cacheTtlSeconds}s',
    });

    http.Response response;
    try {
      response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      _log('[GEMINI_CACHE] action=create_timeout');
      return null;
    } catch (e) {
      _log('[GEMINI_CACHE] action=create_network_error error=$e');
      return null;
    }

    if (response.statusCode != 200) {
      // 400: prompt muito pequeno (< 1024 tokens) ou payload inválido
      // 403: chave sem permissão para caching (conta gratuita pode não ter)
      // 429: rate limit de criação de caches
      final bodySnippet = response.body.length > 300
          ? response.body.substring(0, 300)
          : response.body;
      _log('[GEMINI_CACHE] action=create_http_error '
          'status=${response.statusCode} body=$bodySnippet');
      return null;
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      _log('[GEMINI_CACHE] action=create_parse_error error=$e');
      return null;
    }

    // Extrai o name e a expiração da resposta
    final name       = data['name']?.toString() ?? '';
    final expireTime = data['expireTime']?.toString() ?? ''; // RFC3339

    if (name.isEmpty) {
      _log('[GEMINI_CACHE] action=create_no_name response=${response.body.substring(0, (response.body.length).clamp(0, 200))}');
      return null;
    }

    // Parse da expiração (Google retorna RFC3339, ex: "2025-01-01T12:00:00Z")
    DateTime expiresAt;
    if (expireTime.isNotEmpty) {
      expiresAt = DateTime.tryParse(expireTime)?.toUtc() ??
          DateTime.now().toUtc().add(const Duration(seconds: _cacheTtlSeconds));
    } else {
      // Fallback: usa TTL local se a API não retornou expireTime
      expiresAt = DateTime.now().toUtc().add(const Duration(seconds: _cacheTtlSeconds));
    }

    final entry = GeminiCacheEntry(
      name:              name,
      expiresAt:         expiresAt,
      promptFingerprint: fp,
    );

    // Persiste em memória e SharedPrefs
    _activeCache = entry;
    _persistToPrefs(entry);

    _log('[GEMINI_CACHE] action=created name=$name '
        'expiresAt=${expiresAt.toIso8601String()} fp=$fp');

    return entry;
  }

  /// Persiste o cache em SharedPrefs (background — não bloqueia).
  static void _persistToPrefs(GeminiCacheEntry entry) {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_kCacheName,    entry.name);
      prefs.setString(_kCacheExpires, entry.expiresAt.toIso8601String());
      prefs.setInt(_kCacheFp,         entry.promptFingerprint);
    }).catchError((e) {
      _log('[GEMINI_CACHE] action=prefs_write_error error=$e');
    });
  }

  /// Log condicional — silenciado em release para privacidade clínica.
  static void _log(String message) {
    if (kDebugMode) debugPrint(message);
  }
}
