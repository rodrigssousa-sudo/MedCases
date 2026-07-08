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
// ============================================================

import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firestore_service.dart';

class UiProvider extends ChangeNotifier {
  // ── Estado ────────────────────────────────────────────────────────────────
  String _lang       = _systemLang();
  bool   _darkMode   = true;   // DARK-FIRST: padrão escuro
  bool   _hapticEnabled = true;

  // ── UID do usuário atual (para persistência Firestore) ────────────────────
  String? _uid;

  // ── Idioma padrão baseado no locale do sistema ────────────────────────────
  static String _systemLang() {
    final locale = ui.PlatformDispatcher.instance.locale;
    return locale.languageCode == 'pt' ? 'pt' : 'es';
  }

  // ── Getters públicos ──────────────────────────────────────────────────────
  String get lang          => _lang;
  bool   get darkMode      => _darkMode;
  bool   get hapticEnabled => _hapticEnabled;

  // ── Inicialização — lê SharedPreferences ─────────────────────────────────
  Future<void> loadPrefs({String? uid}) async {
    _uid = uid;
    try {
      final prefs = await SharedPreferences.getInstance();
      // BUILD 310 DIRETRIZ 0: cold-start sem idioma salvo → 'es'.
      final savedLang = prefs.getString('lang');
      if (savedLang == null) {
        _lang = 'es';
        await prefs.setString('lang', 'es');
      } else {
        _lang = savedLang;
      }
      _darkMode      = prefs.getBool('darkMode')      ?? true;
      _hapticEnabled = prefs.getBool('hapticEnabled') ?? true;
    } catch (_) {}
    notifyListeners();
  }

  // ── Sincroniza UID quando usuário faz login ───────────────────────────────
  void setUid(String? uid) => _uid = uid;

  // ── Mutations ─────────────────────────────────────────────────────────────

  /// Troca o idioma ativo (pt / es).
  /// Persiste em SharedPreferences + Firestore (se logado).
  Future<void> setLang(String l, {String? sessionLockedLangReset}) async {
    if (_lang == l) return;
    _lang = l;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lang', l);
    } catch (_) {}
    if (_uid != null) {
      FirestoreService.updateUserProfile(_uid!, lang: l);
    }
  }

  /// Alterna dark/light mode.
  Future<void> toggleDarkMode() async {
    _darkMode = !_darkMode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('darkMode', _darkMode);
    } catch (_) {}
    if (_uid != null) {
      FirestoreService.updateUserProfile(_uid!, darkMode: _darkMode);
    }
  }

  /// Alterna feedback háptico.
  Future<void> toggleHaptic() async {
    _hapticEnabled = !_hapticEnabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hapticEnabled', _hapticEnabled);
    } catch (_) {}
  }

  /// Sync direto de valores vindo do Firestore/Prefs (chamado por AppProvider
  /// após sync remoto — evita segunda leitura de SharedPreferences).
  void syncValues({
    required String lang,
    required bool darkMode,
    required bool hapticEnabled,
  }) {
    bool changed = false;
    if (_lang       != lang)          { _lang          = lang;         changed = true; }
    if (_darkMode   != darkMode)      { _darkMode      = darkMode;     changed = true; }
    if (_hapticEnabled != hapticEnabled) { _hapticEnabled = hapticEnabled; changed = true; }
    if (changed) notifyListeners();
  }
}
