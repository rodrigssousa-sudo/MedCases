// ============================================================
// AiChatProvider — BUILD 326: Provider especializado em estado de IA/Chat
// ============================================================
// Responsabilidade ÚNICA: estado observável do chat de IA.
//
// PROBLEMA RESOLVIDO:
//   Antes do BUILD 326, cada chunk de streaming disparava
//   AppProvider.notifyListeners() → rebuild em cascata nas 17
//   telas que fazem context.watch<AppProvider>().
//
// SOLUÇÃO:
//   AiChatProvider é um ChangeNotifier leve. Apenas widgets
//   que fazem context.watch<AiChatProvider>() ou
//   context.select<AiChatProvider, T>() sofrem rebuild durante
//   o streaming. O restante do app fica intacto.
//
// ESTRATÉGIA DE FACHADA:
//   • AppProvider.aiStreaming / hasAnyAi / hasAiKey / geminiConnected
//     etc. continuam funcionando — são proxies para AiChatProvider.
//   • Zero mudanças nos call sites legados.
//   • AppProvider passa a instância via construtor ou após boot.
//
// CAMPOS EXPOSTOS (lidos pela ai_screen via context.select):
//   • aiStreaming  — true enquanto streaming SSE ativo
//   • hasAnyAi    — true quando qualquer IA disponível
//   • geminiConnected / geminiLoading / geminiEmail
//   • hasAiKey / aiKeyLoading / openAiKey
// ============================================================

import 'package:flutter/foundation.dart';

class AiChatProvider extends ChangeNotifier {
  // ── Estado de streaming ───────────────────────────────────────────────────

  /// true enquanto há streaming SSE ativo (sendAiMessage em voo).
  /// A ai_screen usa context.select<AiChatProvider, bool>(p => p.aiStreaming)
  /// para observar APENAS esta flag sem reconstituir o widget inteiro.
  bool _aiStreaming = false;
  bool get aiStreaming => _aiStreaming;

  // ── Estado da chave de IA ─────────────────────────────────────────────────
  String _openAiKey   = '';
  bool   _aiKeyLoading = false;

  String get openAiKey    => _openAiKey;
  bool   get aiKeyLoading => _aiKeyLoading;

  // ── Estado Gemini OAuth ───────────────────────────────────────────────────
  bool   _geminiConnected = false;
  bool   _geminiLoading   = false;
  String _geminiEmail     = '';

  bool   get geminiConnected => _geminiConnected;
  bool   get geminiLoading   => _geminiLoading;
  String get geminiEmail     => _geminiEmail;

  // ── Computed ──────────────────────────────────────────────────────────────
  // Importado inline para evitar dependência circular com GeminiService.
  // AppProvider chama syncFromAppProvider() para manter sincronizados.

  /// true quando qualquer IA real está disponível.
  bool _hasAnyAi = false;
  bool get hasAnyAi => _hasAnyAi;

  /// true quando chave Gemini do app OU OpenAI legada disponível.
  bool _hasAiKey = false;
  bool get hasAiKey => _hasAiKey;

  // ── Sync vindo do AppProvider ─────────────────────────────────────────────
  // AppProvider chama este método sempre que muda estado de IA.
  // Evita duplicação de lógica de cálculo.

  /// Sincroniza todos os campos de IA a partir do AppProvider.
  /// Dispara notifyListeners() apenas se algo mudou.
  void syncFromAppProvider({
    required bool aiStreaming,
    required bool hasAnyAi,
    required bool hasAiKey,
    required bool geminiConnected,
    required bool geminiLoading,
    required String geminiEmail,
    required String openAiKey,
    required bool aiKeyLoading,
  }) {
    bool changed = false;
    if (_aiStreaming     != aiStreaming)     { _aiStreaming     = aiStreaming;     changed = true; }
    if (_hasAnyAi        != hasAnyAi)       { _hasAnyAi        = hasAnyAi;       changed = true; }
    if (_hasAiKey        != hasAiKey)       { _hasAiKey        = hasAiKey;       changed = true; }
    if (_geminiConnected != geminiConnected){ _geminiConnected = geminiConnected; changed = true; }
    if (_geminiLoading   != geminiLoading)  { _geminiLoading   = geminiLoading;  changed = true; }
    if (_geminiEmail     != geminiEmail)    { _geminiEmail     = geminiEmail;     changed = true; }
    if (_openAiKey       != openAiKey)      { _openAiKey       = openAiKey;      changed = true; }
    if (_aiKeyLoading    != aiKeyLoading)   { _aiKeyLoading    = aiKeyLoading;   changed = true; }
    if (changed) notifyListeners();
  }

  // ── Mutações diretas (chamadas pelo AppProvider) ──────────────────────────

  /// Marca streaming ativo/inativo. Chamado pelo AppProvider.
  /// Dispara notifyListeners() apenas se mudou — zero custo se já está no estado correto.
  void setStreaming(bool value) {
    if (_aiStreaming == value) return;
    _aiStreaming = value;
    notifyListeners();
  }

  /// Marca geminiLoading. Chamado pelo AppProvider durante signIn/signOut.
  void setGeminiLoading(bool value) {
    if (_geminiLoading == value) return;
    _geminiLoading = value;
    notifyListeners();
  }

  /// Atualiza estado Gemini OAuth completo após signIn.
  void setGeminiConnected({
    required bool connected,
    required String email,
    required bool hasAnyAi,
    required bool hasAiKey,
  }) {
    bool changed = false;
    if (_geminiConnected != connected) { _geminiConnected = connected; changed = true; }
    if (_geminiEmail     != email)     { _geminiEmail     = email;     changed = true; }
    if (_hasAnyAi        != hasAnyAi)  { _hasAnyAi        = hasAnyAi; changed = true; }
    if (_hasAiKey        != hasAiKey)  { _hasAiKey        = hasAiKey; changed = true; }
    if (changed) notifyListeners();
  }

  /// Atualiza chave OpenAI.
  void setOpenAiKey(String key, {required bool hasAnyAi, required bool hasAiKey}) {
    bool changed = false;
    if (_openAiKey != key)          { _openAiKey = key;         changed = true; }
    if (_hasAnyAi  != hasAnyAi)     { _hasAnyAi  = hasAnyAi;   changed = true; }
    if (_hasAiKey  != hasAiKey)     { _hasAiKey  = hasAiKey;   changed = true; }
    if (changed) notifyListeners();
  }

  /// Atualiza flag de loading da chave.
  void setAiKeyLoading(bool value) {
    if (_aiKeyLoading == value) return;
    _aiKeyLoading = value;
    notifyListeners();
  }

  /// Reset completo no logout.
  void clearOnLogout() {
    final changed = _geminiConnected || _geminiEmail.isNotEmpty ||
                    _hasAnyAi || _hasAiKey ||
                    _openAiKey.isNotEmpty || _aiStreaming;
    _geminiConnected = false;
    _geminiLoading   = false;
    _geminiEmail     = '';
    _openAiKey       = '';
    _aiKeyLoading    = false;
    _aiStreaming      = false;
    _hasAnyAi        = false;
    _hasAiKey        = false;
    if (changed) notifyListeners();
  }
}
