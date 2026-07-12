// ══════════════════════════════════════════════════════════════════════════════
// tools_state_provider.dart — BUILD 445-CROSS-CALC-STATE
//
// ARQUITETURA:
//   Provider centralizado que gerencia todos os campos clínicos COMPARTILHADOS
//   entre as quatro abas de Ferramentas (Nefrologia, Cardio, Eletrólitos, Hepatologia).
//
// CAMPOS COMPARTILHADOS (TextEditingControllers vivos):
//   Demográficos : idade, peso, altura
//   Bioquímica   : sódio (Na), creatinina (Cr), albumina, bilirrubina,
//                  INR, pH, pCO2, HCO3, cloro, glicose, cálcio, BUN,
//                  AST, ALT, plaquetas, PAS, colesterol, QT(ms), FC
//   Flag         : isFemale (sexo biológico)
//
// CAMPOS ESPECÍFICOS (permanecem privados em cada tela):
//   Nefrologia  : Na urina, creat urina (ratio FeNa)
//   Cardio      : booleans de fatores de risco (HAS, DM, etc.)
//   Eletrólitos : BE (base excess), pCO2 (também compartilhado via gasCtrl)
//   Hepatologia : nódulos, metástase, macroinfiltração, ascite, encefalopatia
//
// FILOSOFIA DE BINDING:
//   • Cada tela usa os controllers via `tp.xxxCtrl` (onde tp = ToolsStateProvider).
//   • Cada TextFormField usa `controller: tp.xxxCtrl` — nunca cria controller local.
//   • Campos com binding automático: ao digitar Na em Eletrólitos, Hepatologia
//     e Nefrologia já vêem o mesmo valor sem nenhum rebuild extra.
//   • 0 loops de renderização: controllers são objetos externos ao widget tree;
//     onChanged do TextEditingController não chama setState().
//
// PERSISTÊNCIA INTER-SESSÃO:
//   • _hasPendingData: true enquanto qualquer campo clínico relevante tiver texto
//   • clearAll(): limpa todos os controllers + isFemale
//   • applyFromCache(Map<String,String>): popula controllers do AppProvider cache
//   • exportToCache(): exporta para Map<String,String> para AppProvider.saveToolsCache
//
// DIALOG DE RETORNO (PASSO 3):
//   • _hasPendingData é checado em ToolsScreen._onReturn()
//   • Se true → exibe showReturnDialog() antes de renderizar os formulários
//
// KEEP-ALIVE (PASSO 2):
//   • NephrologyToolsScreen, CardioToolsScreen, ElectrolytesToolsScreen,
//     HepatologyToolsScreen implementam AutomaticKeepAliveClientMixin.
//   • Os formulários nunca são destruídos ao mudar de aba — apenas ocultados.
//   • Os controllers do ToolsStateProvider NÃO são recriados no rebuild.
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

// ═════════════════════════════════════════════════════════════════════════════
// ToolsStateProvider — ChangeNotifier singleton de estado clínico
// ═════════════════════════════════════════════════════════════════════════════
class ToolsStateProvider extends ChangeNotifier {

  // ── Demográficos ─────────────────────────────────────────────────────────
  final TextEditingController ageCtrl    = TextEditingController();
  final TextEditingController weightCtrl = TextEditingController();
  final TextEditingController heightCtrl = TextEditingController();

  // ── Sexo (booleano — partilhado entre Nefrologia e Cardio) ───────────────
  bool _isFemale = false;
  bool get isFemale => _isFemale;
  void setFemale(bool v) {
    if (_isFemale == v) return;
    _isFemale = v;
    notifyListeners();
  }

  // ── Eletrólitos / Nefrologia ─────────────────────────────────────────────
  final TextEditingController naCtrl     = TextEditingController(); // Sódio sérico
  final TextEditingController crCtrl     = TextEditingController(); // Creatinina sérica
  final TextEditingController clCtrl     = TextEditingController(); // Cloro
  final TextEditingController hco3Ctrl   = TextEditingController(); // HCO3 / bicarbonato
  final TextEditingController glucCtrl   = TextEditingController(); // Glicose
  final TextEditingController caCtrl     = TextEditingController(); // Cálcio
  final TextEditingController bunCtrl    = TextEditingController(); // BUN / Ureia

  // ── Gasometria ────────────────────────────────────────────────────────────
  final TextEditingController phCtrl     = TextEditingController();
  final TextEditingController pco2Ctrl   = TextEditingController();
  final TextEditingController beCtrl     = TextEditingController(); // Base Excess

  // ── Hepatologia / Nefrologia compartilhados ───────────────────────────────
  final TextEditingController albCtrl    = TextEditingController(); // Albumina
  final TextEditingController biliCtrl   = TextEditingController(); // Bilirrubina total
  final TextEditingController inrCtrl    = TextEditingController(); // INR

  // ── Enzimas hepáticas ────────────────────────────────────────────────────
  final TextEditingController astCtrl    = TextEditingController();
  final TextEditingController altCtrl    = TextEditingController();
  final TextEditingController platCtrl   = TextEditingController(); // Plaquetas

  // ── Cardio ────────────────────────────────────────────────────────────────
  final TextEditingController pasCtrl    = TextEditingController(); // PAS mmHg
  final TextEditingController colCtrl    = TextEditingController(); // Colesterol total
  final TextEditingController qtCtrl     = TextEditingController(); // QT em ms
  final TextEditingController fcCtrl     = TextEditingController(); // FC bpm

  // ── Guard de dados pendentes ─────────────────────────────────────────────
  // true quando pelo menos um campo clínico relevante está preenchido.
  // Usado pelo dialog de retorno (PASSO 3) para decidir se exibe o popup.
  bool _hasPendingData = false;
  bool get hasPendingData => _hasPendingData;

  // Controladores "primários" verificados para hasPendingData
  late final List<TextEditingController> _primaryCtrls = [
    ageCtrl, weightCtrl,
    naCtrl, crCtrl, hco3Ctrl,
    albCtrl, biliCtrl, inrCtrl,
    phCtrl, pco2Ctrl,
    pasCtrl, colCtrl,
  ];

  /// Recalcula _hasPendingData e notifica se mudou.
  /// Chamado pelas telas após cada cálculo ou ao sair da seção.
  void refreshPendingFlag() {
    final has = _primaryCtrls.any((c) => c.text.trim().isNotEmpty) || _isFemale;
    if (has == _hasPendingData) return;
    _hasPendingData = has;
    notifyListeners();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // clearAll — PASSO 3: acionado pelo botão "Limpar Tudo" do dialog de retorno
  // ──────────────────────────────────────────────────────────────────────────
  void clearAll() {
    for (final c in [
      ageCtrl, weightCtrl, heightCtrl,
      naCtrl, crCtrl, clCtrl, hco3Ctrl, glucCtrl, caCtrl, bunCtrl,
      phCtrl, pco2Ctrl, beCtrl,
      albCtrl, biliCtrl, inrCtrl,
      astCtrl, altCtrl, platCtrl,
      pasCtrl, colCtrl, qtCtrl, fcCtrl,
    ]) {
      c.clear();
    }
    _isFemale = false;
    _hasPendingData = false;
    notifyListeners();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // applyFromCache — popula controllers a partir do AppProvider.toolsInputCache
  // Mapeamento canônico: chave do cache → controller
  // ──────────────────────────────────────────────────────────────────────────
  void applyFromCache(Map<String, String> cache) {
    void _set(TextEditingController ctrl, String key) {
      final v = cache[key] ?? '';
      if (v.isNotEmpty && ctrl.text != v) ctrl.text = v;
    }
    _set(ageCtrl,    'edad');
    _set(weightCtrl, 'peso');
    _set(naCtrl,     'sodio');
    _set(crCtrl,     'creatinina');
    _set(clCtrl,     'cloro');
    _set(hco3Ctrl,   'hco3');
    _set(glucCtrl,   'glicose');
    _set(caCtrl,     'calcio');
    _set(bunCtrl,    'bun');
    _set(albCtrl,    'albumina');
    _set(biliCtrl,   'bilirrubina');
    _set(inrCtrl,    'inr');
    _set(astCtrl,    'ast');
    _set(altCtrl,    'alt');
    _set(platCtrl,   'plaquetas');
    _set(pasCtrl,    'pas');
    _set(colCtrl,    'colesterol');
    _set(qtCtrl,     'qtms');
    _set(fcCtrl,     'fc');
    final sexo = cache['sexo'] ?? '';
    _isFemale = sexo == 'F';
    refreshPendingFlag();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // exportToCache — exporta estado atual para Map<String,String>
  // Compatível com AppProvider.saveToolsCache()
  // ──────────────────────────────────────────────────────────────────────────
  Map<String, String> exportToCache() => {
    'edad':        ageCtrl.text,
    'peso':        weightCtrl.text,
    'sodio':       naCtrl.text,
    'creatinina':  crCtrl.text,
    'cloro':       clCtrl.text,
    'hco3':        hco3Ctrl.text,
    'glicose':     glucCtrl.text,
    'calcio':      caCtrl.text,
    'bun':         bunCtrl.text,
    'albumina':    albCtrl.text,
    'bilirrubina': biliCtrl.text,
    'inr':         inrCtrl.text,
    'ast':         astCtrl.text,
    'alt':         altCtrl.text,
    'plaquetas':   platCtrl.text,
    'pas':         pasCtrl.text,
    'colesterol':  colCtrl.text,
    'qtms':        qtCtrl.text,
    'fc':          fcCtrl.text,
    'sexo':        _isFemale ? 'F' : 'M',
  };

  // ──────────────────────────────────────────────────────────────────────────
  // applyFromPatient — autofill a partir de dados demográficos da H. Clínica
  // ──────────────────────────────────────────────────────────────────────────
  void applyFromPatient({required int? age, required bool? female}) {
    if (age != null && ageCtrl.text.isEmpty) {
      ageCtrl.text = age.toString();
    }
    if (female != null) {
      _isFemale = female;
    }
    refreshPendingFlag();
    notifyListeners();
  }

  @override
  void dispose() {
    for (final c in [
      ageCtrl, weightCtrl, heightCtrl,
      naCtrl, crCtrl, clCtrl, hco3Ctrl, glucCtrl, caCtrl, bunCtrl,
      phCtrl, pco2Ctrl, beCtrl,
      albCtrl, biliCtrl, inrCtrl,
      astCtrl, altCtrl, platCtrl,
      pasCtrl, colCtrl, qtCtrl, fcCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }
}
