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
  // buildQueryStringForSpecialty — BUILD 447-URL-PAYLOAD
  //
  // Serializa apenas os campos pertinentes de cada especialidade como Query
  // Parameters para injeção dinâmica na URL da WebView.
  //
  // Regras:
  //   • Chaves com valor vazio são OMITIDAS (URL limpa, sem "?na=&cr=").
  //   • Sexo biológico: "sex=M" ou "sex=F".
  //   • Retorna "" (string vazia) quando NENHUM campo está preenchido.
  //   • Retorna "?key=val&key2=val2" quando há ao menos 1 campo.
  //
  // Especialidades suportadas:
  //   'eletrolitos' → ph, pco2, hco3, be, na, cl, gluc, ca, bun, alb, weight
  //   'nefro'       → age, sex, weight, height, cr, na
  //   'cardio'      → age, sex, pas, col, qt, fc
  //   'hepato'      → age, sex, na, bili, inr, alb, ast, alt, plat
  // ──────────────────────────────────────────────────────────────────────────
  String buildQueryStringForSpecialty(String specialty) {
    // Helper: só adiciona à map se o valor não estiver vazio.
    final Map<String, String> params = {};

    void _add(String key, String value) {
      final v = value.trim();
      if (v.isNotEmpty) params[key] = v;
    }

    void _addSex() => params['sex'] = _isFemale ? 'F' : 'M';

    switch (specialty) {
      case 'eletrolitos':
        _add('ph',     phCtrl.text);
        _add('pco2',   pco2Ctrl.text);
        _add('hco3',   hco3Ctrl.text);
        _add('be',     beCtrl.text);
        _add('na',     naCtrl.text);
        _add('cl',     clCtrl.text);
        _add('gluc',   glucCtrl.text);
        _add('ca',     caCtrl.text);
        _add('bun',    bunCtrl.text);
        _add('alb',    albCtrl.text);
        _add('weight', weightCtrl.text);

      case 'nefro':
        _add('age',    ageCtrl.text);
        _addSex();
        _add('weight', weightCtrl.text);
        _add('height', heightCtrl.text);
        _add('cr',     crCtrl.text);
        _add('na',     naCtrl.text);

      case 'cardio':
        _add('age',    ageCtrl.text);
        _addSex();
        _add('pas',    pasCtrl.text);
        _add('col',    colCtrl.text);
        _add('qt',     qtCtrl.text);
        _add('fc',     fcCtrl.text);

      case 'hepato':
        _add('age',    ageCtrl.text);
        _addSex();
        _add('na',     naCtrl.text);
        _add('bili',   biliCtrl.text);
        _add('inr',    inrCtrl.text);
        _add('alb',    albCtrl.text);
        _add('ast',    astCtrl.text);
        _add('alt',    altCtrl.text);
        _add('plat',   platCtrl.text);

      default:
        // Especialidade desconhecida — retorna sem parâmetros
        return '';
    }

    if (params.isEmpty) return '';

    // Para 'nefro' e 'cardio', sex=M/F é sempre incluído (mesmo sem dados)
    // mas só queremos incluir sex se havia ao menos 1 dado clínico real.
    // Verificação: se params contém APENAS 'sex', omite sex sozinho.
    if (params.length == 1 && params.containsKey('sex')) return '';

    final query = params.entries
        .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return '?$query';
  }

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
