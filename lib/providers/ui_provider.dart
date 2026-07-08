// ============================================================
// UiProvider — BUILD 326: Provider especializado em estado de UI
// ============================================================
// Responsabilidade ÚNICA: tema (dark/light) + idioma ativo.
//
// ESTRATÉGIA DE FACHADA:
//   • AppProvider.lang / AppProvider.darkMode / AppProvider.hapticEnabled
//     continuam funcionando — agora são proxies para UiProvider.
//   • Zero mudanças nos call sites legados.
//
// GANHO DE PERFORMANCE:
//   • toggleDarkMode() / setLang() → apenas UiProvider.notifyListeners()
//   • Telas de IA, Histórico, Protocolos etc. NÃO reconstroem.
//   • Apenas os widgets que fazem context.watch<UiProvider>() ou
//     context.select<UiProvider, T>() são afetados.
//
// ARQUITETURA (BUILD 326.1):
//   • ÚNICO ponto de mutação externo: syncValues() — chamado por AppProvider
//     após cada mudança de prefs/Firestore. AppProvider detém a lógica de
//     persistência e delega o notify cirúrgico ao UiProvider.
//   • Não expõe setLang/toggleDarkMode/toggleHaptic ao exterior — AppProvider
//     é o único orchestrador; chamá-los diretamente causaria duplicidade.
// ============================================================

import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';

class UiProvider extends ChangeNotifier {
  // ── Estado ────────────────────────────────────────────────────────────────
  String _lang       = _systemLang();
  bool   _darkMode   = true;   // DARK-FIRST: padrão escuro
  bool   _hapticEnabled = true;

  // ── Idioma padrão baseado no locale do sistema ────────────────────────────
  static String _systemLang() {
    final locale = ui.PlatformDispatcher.instance.locale;
    return locale.languageCode == 'pt' ? 'pt' : 'es';
  }

  // ── Getters públicos ──────────────────────────────────────────────────────
  String get lang          => _lang;
  bool   get darkMode      => _darkMode;
  bool   get hapticEnabled => _hapticEnabled;

  /// Sync direto de valores vindo do Firestore/Prefs (chamado por AppProvider
  /// após sync remoto — evita segunda leitura de SharedPreferences).
  ///
  /// DESIGN INTENCIONAL: este é o ÚNICO método público de mutação.
  /// AppProvider centraliza toda a lógica de persistência e chama syncValues()
  /// com o estado canônico após cada operação de leitura/escrita.
  /// Isso garante que o UiProvider nunca diverge do AppProvider.
  void syncValues({
    required String lang,
    required bool darkMode,
    required bool hapticEnabled,
  }) {
    bool changed = false;
    if (_lang          != lang)         { _lang          = lang;          changed = true; }
    if (_darkMode      != darkMode)     { _darkMode      = darkMode;      changed = true; }
    if (_hapticEnabled != hapticEnabled){ _hapticEnabled = hapticEnabled; changed = true; }
    if (changed) notifyListeners();
  }
}
